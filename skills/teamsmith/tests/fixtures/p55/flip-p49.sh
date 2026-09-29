#!/usr/bin/env bash
# flip-p49.sh — P55「agent pane 留存与死 pane 席位」的翻转夹具（变异测试，§40 的可运行翻转）
#
# 四条腿（每条腿建独立夹具：私有 TMUX_TMPDIR + 独立 git 仓库 + 独立会话，跑同一组核心断言）：
#   leg0 green     ：对未改的 skill 跑 → 必须全绿（夹具自身有效）
#   leg1 no-retain ：把建窗点换回旧的一行 new-window（删掉占位+设选项+读回+respawn）
#                    → 期望红锚点 B1（kill 之后 pane_dead=1 / 遗体留存）
#   leg2 say-dead  ：删掉 team say 的死 pane 换道分支（say 对遗体按键）
#                    → 期望红锚点 C2（输出点名「pane 已死 + signal=9」）
#   leg3 roster-run：把 roster 覆盖里的 dead 行改成「● 在跑」（尸体冒充活座位）
#                    → 期望红锚点 E1（roster 死 pane 行带 ▲ + signal=9）
#
# 判绿规则：leg0 全绿；leg1-3 各自的锚点断言红（其余红行原样打印存档）。exit 0 = 四条腿全部如预期。
# 断言 ID 与 smoke §40 的对应：A=① 创建期 B=② 遗体 C=③ say D=⑤ 复用 E=④ 读面 F=⑧ teardown。
set -uo pipefail

FLIP_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # 本脚本所在的 skill 根（被测对象）
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1
[ -n "${1:-}" ] && [ "$1" != "--keep" ] && FLIP_SKILL="$(cd "$1" && pwd)"

ok_n=0; red_n=0
note() { printf '%s\n' "$*"; }
line_ok()  { note "  ✓ $*"; }
line_red() { note "  ✗ $*"; }

# M28 隔离（lint 规则 D 的诚实满足，与 smoke.sh:241 同款）：本文件的全部 tmux 调用都打私有
# socket 目录 —— 顶层 unset TMUX/TMUX_PANE + 顶层把 TMUX_TMPDIR 指到本进程私有目录（已建）；此后不导回 TMUX。
FLIP_SOCK="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip-sock.XXXXXX")"
TMUX_TMPDIR="$FLIP_SOCK"; export TMUX_TMPDIR
unset TMUX TMUX_PANE

# ---------------------------------------------------------------- 单腿：建夹具 + 跑核心断言
# 用法：p55_leg <leg名> <skill_dir>；结果写入 $LEG_RESULTS（"OK|RED <id> <desc>" 一行一条）
p55_leg() { # <leg> <skill_dir>
  local leg="$1" SK="$2"
  LEG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip.XXXXXX")"
  local T="$LEG_ROOT" REPO SESS
  REPO="$T/repo"; SESS="p55flip-$leg-$$"
  # 隔离：私有 socket 目录（已 mkdir；不写 TMUX_TMPDIR 指向不存在的目录 —— 那两个回退陷阱的教训）、
  # 剥掉 shim、清掉 TEAM_* 身份
  (
  set -uo pipefail
  unset TMUX TMUX_PANE TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM \
        TEAM_CONFIG_FILE TEAM_AGENTS TEAM_AGENT_CMD TEAM_AGENT_BIN TEAM_AGENT_NOTIFY_CMD \
        TEAM_AGENT_LOG_GLOB TEAM_DISPATCH_ALIVE_SEC TEAM_AGENT_SCENE_LINES
  _p=""; _ifs="$IFS"; IFS=:
  for d in $PATH; do case "$d" in */scripts/shim) ;; *) _p="${_p:+$_p:}$d" ;; esac; done
  IFS="$_ifs"; PATH="$_p"; export PATH; unset _p _ifs

  TEAM="bash $SK/scripts/team"
  RES="$T/results"; : > "$RES"
  ck() { # <id> <desc> <0|1> [实际值]
    if [ "$3" = "0" ]; then printf 'OK %s %s\n' "$1" "$2" >> "$RES"
    else printf 'RED %s %s（%s）\n' "$1" "$2" "${4:-}" >> "$RES"; fi
  }

  mkdir -p "$REPO"; cd "$REPO" || exit 1
  git init -q -b main; git config user.email f@f; git config user.name f
  echo x > README.md; git add -A; git commit -qm init
  $TEAM init --session "$SESS" --agents "p55w" --vcs local --gates "true" --docs docs/team >/dev/null 2>&1
  mkdir -p "$REPO/.pi/team/state"
  printf '# T9.55 · flip probe\n\ntask: T9.55\nagent: p55w\nchange: -\nanchor: none (infra) — flip\n' > "$REPO/.pi/team/state/T9.55-brief.md"
  BR="$(cd "$REPO" && bash -c '. "'"$SK"'/scripts/lib/common.sh"; for _f in "'"$SK"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_branch_for_agent p55w T9.55')"
  git worktree add -b "$BR" "$REPO/.worktrees/p55w" main >/dev/null 2>&1
  mkdir -p "$T/bin"
  printf '#!/usr/bin/env bash\necho P55-MARK-1\necho P55-MARK-2\necho P55-MARK-3\nsleep 300\n' > "$T/bin/fake-agent"
  chmod +x "$T/bin/fake-agent"
  DENV=(env TEAM_AGENTS="p55w" TEAM_AGENT_CMD="$T/bin/fake-agent {cwd}" TEAM_AGENT_BIN="$T/bin/fake-agent" TEAM_DISPATCH_ALIVE_SEC=0)

  # ── A：创建期 ──
  if "${DENV[@]}" $TEAM dispatch p55w T9.55 "$REPO/.pi/team/state/T9.55-brief.md" >"$T/d1.log" 2>&1; then ck A1-0 "派单成功" 0; else ck A1-0 "派单成功" 1 "$(tail -1 "$T/d1.log")"; fi
  roe="$(tmux show-options -w -v -t "$SESS:p55w" remain-on-exit 2>/dev/null)"
  [ "$roe" = "on" ]; ck A1 "remain-on-exit 读回是 on" "$?" "$roe"
  roe_pm="$(tmux show-options -w -v -t "$SESS:pm" remain-on-exit 2>/dev/null)"
  [ -z "$roe_pm" ]; ck A2 "PM 窗口无该设置" "$?" "$roe_pm"
  i=0; while [ "$i" -lt 30 ]; do { tmux capture-pane -p -S - -t "$SESS:p55w" 2>/dev/null || true; } | grep -q P55-MARK-3 && break; sleep 0.3; i=$((i+1)); done
  { tmux capture-pane -p -S - -t "$SESS:p55w" 2>/dev/null || true; } | grep -q P55-MARK-3; ck A3 "marker 画上" "$?"
  [ "$(tmux list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | grep -cx p55w)" = "1" ]; ck A4 "恰好一个窗口" "$?"

  # ── B：kill → 遗体 ──
  pid="$(tmux list-panes -t "$SESS:p55w" -F '#{pane_pid}' 2>/dev/null | head -1)"
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  my_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"
  if [ -n "$pgid" ] && [ "$pgid" != "$my_pgid" ] && [ "$pgid" != "1" ]; then kill -9 -- -"$pgid" 2>/dev/null || true; fi
  i=0; while [ "$i" -lt 25 ]; do [ "$(tmux list-panes -t "$SESS:p55w" -F '#{pane_dead}' 2>/dev/null | head -1)" = "1" ] && break; sleep 0.2; i=$((i+1)); done
  [ "$(tmux list-panes -t "$SESS:p55w" -F '#{pane_dead}' 2>/dev/null | head -1)" = "1" ]; ck B1 "kill 后 pane_dead=1（遗体留存）" "$?"
  [ "$(tmux list-panes -t "$SESS:p55w" -F '#{pane_dead_signal}' 2>/dev/null | head -1)" = "9" ]; ck B2 "退出证据 signal=9" "$?"
  [ "$(tmux list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | grep -cx p55w)" = "1" ]; ck B3 "窗口没跟 pane 消失" "$?"
  { tmux capture-pane -p -S - -t "$SESS:p55w" 2>/dev/null || true; } | grep -q P55-MARK-3; ck B4 "遗体画面含 marker" "$?"

  # ── C：say 对死 pane ──
  before="$(tmux capture-pane -p -S - -t "$SESS:p55w" 2>/dev/null | cksum)"
  env TEAM_AGENTS="p55w" $TEAM say p55w "P55 flip probe" >"$T/say.log" 2>&1; rc=$?
  [ "$rc" = "0" ]; ck C1 "say rc=0" "$?" "rc=$rc"
  grep -qF "pane 已死（signal=9）" "$T/say.log"; ck C2 "输出点名座位已死+证据" "$?" "$(tail -1 "$T/say.log")"
  ! grep -qF "已确认送达" "$T/say.log"; ck C3 "不报送达" "$?"
  grep -qF "P55 flip probe" "$REPO/docs/team/inbox/p55w.md" 2>/dev/null; ck C4 "消息落收件箱" "$?"
  after="$(tmux capture-pane -p -S - -t "$SESS:p55w" 2>/dev/null | cksum)"
  [ "$after" = "$before" ]; ck C5 "遗体画面逐字节不变" "$?" "$before → $after"

  # ── D：复用抓现场 ──
  if env TEAM_AGENTS="p55w" TEAM_AGENT_CMD="$T/bin/fake-agent {cwd}" TEAM_AGENT_BIN="$T/bin/fake-agent" \
       TEAM_DISPATCH_ALIVE_SEC=0 TEAM_AGENT_SCENE_LINES=3 \
       $TEAM dispatch p55w T9.55 "$REPO/.pi/team/state/T9.55-brief.md" >"$T/d2.log" 2>&1; then ck D1 "复用 dispatch 成功" 0; else ck D1 "复用 dispatch 成功" 1 "$(tail -1 "$T/d2.log")"; fi
  grep -qF "上一个 pane 已死（signal=9）" "$T/d2.log"; ck D2 "复用点名上一个 pane 已死" "$?"
  f="$REPO/.pi/team/state/dispatch-p55w-pane-dead.txt"
  grep -qF "exit: signal=9" "$f" 2>/dev/null; ck D3 "现场文件带退出证据" "$?"
  [ -f "$f" ] && { sed -n '/^--- scene ---/,$p' "$f" | tail -n +2 || true; } | grep -q 'P55-MARK'; ck D4 "现场文件画面含 marker" "$?"
  [ "$(tmux list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | grep -cx p55w)" = "1" ]; ck D5 "替换后恰好一个窗口" "$?"
  [ "$(tmux show-options -w -v -t "$SESS:p55w" remain-on-exit 2>/dev/null)" = "on" ]; ck D6 "新窗口仍 on" "$?"

  # ── E：读面（kill 之后）──
  pid="$(tmux list-panes -t "$SESS:p55w" -F '#{pane_pid}' 2>/dev/null | head -1)"
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  [ -n "$pgid" ] && [ "$pgid" != "$my_pgid" ] && [ "$pgid" != "1" ] && kill -9 -- -"$pgid" 2>/dev/null
  i=0; while [ "$i" -lt 25 ]; do [ "$(tmux list-panes -t "$SESS:p55w" -F '#{pane_dead}' 2>/dev/null | head -1)" = "1" ] && break; sleep 0.2; i=$((i+1)); done
  env TEAM_AGENTS="p55w" TEAM_AGENT_BIN="$T/bin/fake-agent" $TEAM roster >"$T/roster.log" 2>&1
  grep -qE "^p55w +▲ 已死 signal=9" "$T/roster.log"; ck E1 "roster 死 pane 行（▲ + signal=9）" "$?" "$(grep '^p55w' "$T/roster.log")"
  env TEAM_AGENTS="p55w" TEAM_AGENT_BIN="$T/bin/fake-agent" $TEAM __panel-data --block agents >"$T/agents.json" 2>/dev/null
  grep -qF '"pane": "dead"' "$T/agents.json" && grep -qF '"pane_exit": "signal=9"' "$T/agents.json"; ck E2 "机器面 pane=dead/pane_exit=signal=9" "$?"
  ! grep -qF '"state": "running"' "$T/agents.json"; ck E2b "尸体不以 running 出现" "$?"
  env TEAM_AGENTS="p55w" TEAM_AGENT_BIN="$T/bin/fake-agent" TEAM_AGENT_SCENE_LINES=2 $TEAM status T9.55 >"$T/status.log" 2>&1
  grep -qF "座位 p55w" "$T/status.log" && grep -qF "signal=9" "$T/status.log" && grep -qF "P55-MARK" "$T/status.log"; ck E3 "status 席位段+现场" "$?"
  env TEAM_AGENTS="p55w" TEAM_AGENT_BIN="$T/bin/fake-agent" $TEAM digest >"$T/digest.log" 2>&1
  grep -qF "! p55w pane 已死（signal=9）" "$T/digest.log"; ck E4 "digest 点名死席位+任务未结束" "$?"
  env TEAM_AGENTS="p55w" TEAM_AGENT_BIN="$T/bin/fake-agent" $TEAM doctor >"$T/doctor.log" 2>&1
  grep -qF "死 pane 席位 p55w" "$T/doctor.log"; ck E5 "doctor 告警点名死席位" "$?"

  # ── F：teardown ──
  env TEAM_AGENTS="p55w" $TEAM teardown --agent p55w >"$T/teardown.log" 2>&1
  i=0; while [ "$i" -lt 25 ]; do tmux list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | grep -qx p55w || break; sleep 0.2; i=$((i+1)); done
  [ "$(tmux list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | grep -cx p55w)" = "0" ]; ck F1 "teardown 拆掉遗体窗口" "$?"

  tmux kill-session -t "$SESS" 2>/dev/null || true
  ) || true
  LEG_RESULTS="$LEG_ROOT/results"
}

# ---------------------------------------------------------------- 变异（作用于 skill 副本）
mut_no_retain() { # <skill副本>：建窗点换回旧一行（删掉 P55 的占位/设选项/读回/respawn 块）
  python3 - "$1/scripts/lib/cmd-agents.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a = s.index('    # P55（remain-on-exit 的时机是红线）')
b = s.index('    pid="$(team_wait_launch_proof', a)
s = s[:a] + '    tmux new-window -t "$TEAM_SESSION" -n "$agent" -d -- bash -lc "$inner" "$prompt" >/dev/null 2>&1 || true\n' + s[b:]
open(p, 'w').write(s)
PY
}
mut_say_dead() { # <skill副本>：删掉 say 的死 pane 换道分支（注释 + if 块，到「# 安全：空提示符时」前）
  python3 - "$1/scripts/lib/cmd-agents.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a = s.index('    # P55（投递换道）')
b = s.index('    # 安全：空提示符时把消息 send-keys 进去会被 shell 当命令执行', a)
s = s[:a] + s[b:]
open(p, 'w').write(s)
PY
}
mut_roster_run() { # <skill副本>：roster 的 dead 行冒充「在跑」
  python3 - "$1/scripts/lib/cmd-status.sh" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = '      dead*)   state="▲ 已死${cond#dead}" ;;'
assert old in s, "roster dead 行锚点不在"
s = s.replace(old, '      dead*)   state="● $cli 在跑" ;;')
open(p, 'w').write(s)
PY
}

# ---------------------------------------------------------------- 四条腿
OUT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip-out.XXXXXX")"
note "P55 flip-p49（§40 翻转夹具）· 输出目录 $OUT"
note "被测 skill：$FLIP_SKILL"

judge() { # <leg> <锚点id> <结果文件> → 0=如预期（锚点红）；顺带打印全部红行
  local leg="$1" anchor="$2" res="$3"
  if [ ! -s "$res" ]; then note "  ✗ $leg：没有结果文件（夹具没跑起来）"; return 1; fi
  grep '^RED ' "$res" | sed 's/^/    red: /'
  grep -q "^RED $anchor " "$res"
}

flip_rc=0

note "== leg0 green（未改） =="
p55_leg green "$FLIP_SKILL"
green_red="$(grep -c '^RED ' "$LEG_RESULTS" 2>/dev/null || true)"
grep '^RED ' "$LEG_RESULTS" 2>/dev/null | sed 's/^/    red: /'
if [ "$green_red" = "0" ]; then line_ok "leg0：全绿（$(grep -c '^OK ' "$LEG_RESULTS") 条断言）——夹具有效"
else line_red "leg0：未改就有 $green_red 条红 —— 夹具或实现有问题，翻转无意义"; flip_rc=1; fi
cp "$LEG_RESULTS" "$OUT/leg0-green.results"; [ "$KEEP" = "1" ] || rm -rf "$LEG_ROOT"

note "== leg1 变异：删掉留存（建窗回到旧一行）→ 期望 B1 红 =="
MUT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip-mut.XXXXXX")"; cp -a "$FLIP_SKILL" "$MUT/skill"
mut_no_retain "$MUT/skill"
p55_leg no-retain "$MUT/skill"
if judge no-retain B1 "$LEG_RESULTS"; then line_ok "leg1：锚点 B1 如预期转红（kill 后窗口消失，遗体断言抓到）"
else line_red "leg1：锚点 B1 没有红 —— §40 的留存断言拦不住「删掉留存」"; flip_rc=1; fi
cp "$LEG_RESULTS" "$OUT/leg1-no-retain.results"; [ "$KEEP" = "1" ] || { rm -rf "$LEG_ROOT"; rm -rf "$MUT"; }

note "== leg2 变异：say 对死 pane 按键（删掉换道分支）→ 期望 C2 红 =="
MUT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip-mut.XXXXXX")"; cp -a "$FLIP_SKILL" "$MUT/skill"
mut_say_dead "$MUT/skill"
p55_leg say-dead "$MUT/skill"
if judge say-dead C2 "$LEG_RESULTS"; then line_ok "leg2：锚点 C2 如预期转红（输出不再点名座位已死）"
else line_red "leg2：锚点 C2 没有红 —— §40 的投递断言拦不住「say 对遗体按键」"; flip_rc=1; fi
cp "$LEG_RESULTS" "$OUT/leg2-say-dead.results"; [ "$KEEP" = "1" ] || { rm -rf "$LEG_ROOT"; rm -rf "$MUT"; }

note "== leg3 变异：roster 把遗体显示成「在跑」→ 期望 E1 红 =="
MUT="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p55-flip-mut.XXXXXX")"; cp -a "$FLIP_SKILL" "$MUT/skill"
mut_roster_run "$MUT/skill"
p55_leg roster-run "$MUT/skill"
if judge roster-run E1 "$LEG_RESULTS"; then line_ok "leg3：锚点 E1 如预期转红（roster 死 pane 行没了 ▲+证据）"
else line_red "leg3：锚点 E1 没有红 —— §40 的四态断言拦不住「尸体冒充在跑」"; flip_rc=1; fi
cp "$LEG_RESULTS" "$OUT/leg3-roster-run.results"; [ "$KEEP" = "1" ] || { rm -rf "$LEG_ROOT"; rm -rf "$MUT"; }

note ""
if [ "$flip_rc" = "0" ]; then note "FLIP 全绿：green 腿全绿 + 三条变异腿各在锚点转红（$OUT）"
else note "FLIP 有未达预期的腿（$OUT）"; fi
rm -rf "$FLIP_SOCK" 2>/dev/null || true
exit "$flip_rc"
