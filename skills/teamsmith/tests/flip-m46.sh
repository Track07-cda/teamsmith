#!/usr/bin/env bash
# M46 · 翻转包：投递通道降级可见 + 慢路径自愈的 red → green 证据
#
#   bash skills/teamsmith/tests/flip-m46.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m46.sh   # 覆盖「修复前」的 revision
#
# 事故（2026-09-20，用户报「other_project 又没自动发消息」）：PM 进程加载的是 M40 之前的
# team-inbox-watch.ts，按继承的 TEAM_* 解到 pm-skills，用 pm-skills 的会话名算出期望 target
# 与真实会话不符 → 每 2s 一次 `skip setup`，而痕迹全写进**别人的** state；投递静默退回输入框
# 粘贴路径 → 一次 draft-raced-left + 两条消息滞留。M46 修的是「降级没被看见 + 慢路径残留/
# 死目标没人管」，本包用四组翻转证明测试真的咬在实现上：
#
#   ① 修复前（$BASE）扩展：harness 的 M46-S14/S15/S16 必须 FAIL（复现：跳过无痕、state 无锚）
#   ② 本树扩展：harness 全绿
#   ③ 变异扩展（writeSkipRecord 变空操作）：M46-S14 必须红
#   ④ 变异 bash 三处（告警行恒假 / target_gone 恒假 / residue sweep 空操作）：同一夹具上
#      三条断言各自变红 —— 去掉实现 → 断言红（不是「实现怎么改都绿」）
#
# 退出码：0 = 预期全部成立；1 = 有翻转不成立；2 = 环境/前置不满足（不算绿也不算红）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m46: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  TS_RUNNER="$HOME/.bun/bin/bun"
fi
[ -n "$TS_RUNNER" ] || { printf 'flip-m46: 需要 node（类型剥离）或 bun 来跑 TS 扩展\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m46: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-m46)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  tmp_root_reap_all
}
trap cleanup EXIT

# 子串判定：用 case（不起管道）——`printf ... | grep -q` 在 `set -o pipefail` 下会被 grep 的提前退出
# 变成 SIGPIPE（141）而假红；日志越大越容易命中（P28 把 harness 日志从 ~14KB 撑到 ~17KB 时实测）。
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

fail() { printf '\033[31m✗\033[0m %s\n' "$*"; }
pass() { printf '\033[32m✓\033[0m %s\n' "$*"; }

# ---- 树：红（修复前）/ 绿（本 worktree）/ 变异（绿 + 单点破坏）-------------------------------
mkdir -p "$TMP/red"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_EXT="$TMP/red/skills/teamsmith/extension/team-inbox-watch.ts"
GREEN="$SKILL_DIR"
GREEN_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"

# 前置守卫：红树必须真的还没有 M46（否则报的是假翻转），绿树必须真的带着修复
if grep -q 'writeSkipRecord' "$RED_EXT" 2>/dev/null; then
  printf 'flip-m46: $BASE 已经包含 M46 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
grep -q 'writeSkipRecord' "$GREEN_EXT" || { printf 'flip-m46: 本树扩展找不到 writeSkipRecord（修复不在？）\n' >&2; exit 2; }

# ③ 变异扩展：writeSkipRecord 变空操作（跳过不再留痕）
MUT_EXT_DIR="$TMP/mut-ext"
cp -a "$SKILL_DIR" "$MUT_EXT_DIR"
python3 - "$MUT_EXT_DIR/extension/team-inbox-watch.ts" <<'PY' || exit 2
import sys
p = sys.argv[1]
s = open(p).read()
old = "}): void {\n  const dir = watchDir(root)"
new = "}): void {\n  if (info.reason) return\n  const dir = watchDir(root)"
if s.count(old) != 1:
    sys.exit("flip-m46: writeSkipRecord 的函数体形状变了（找不到注入点）")
open(p, 'w').write(s.replace(old, new, 1))
PY

# ④ 变异 bash：三处单点破坏，各拷一份完整 skill 树
mk_bash_mut() { # <名字> <python 变异脚本> → 目录
  local name="$1" patch="$2" dir
  dir="$TMP/mut-$name"
  cp -a "$SKILL_DIR" "$dir"
  python3 "$patch" || exit 2
}
cat > "$TMP/patch-warn.py" <<PY
import sys
p = "$TMP/mut-warn/scripts/lib/outbox.sh"
s = open(p).read()
old = "team_inbox_watch_degraded_line() { #"
if s.count(old) != 1: sys.exit("flip-m46: 告警行函数形状变了")
open(p, 'w').write(s.replace(old, "team_inbox_watch_degraded_line() { return 1; #", 1))
PY
cat > "$TMP/patch-gone.py" <<PY
import sys
p = "$TMP/mut-gone/scripts/lib/outbox.sh"
s = open(p).read()
old = "team_outbox_target_gone() {\n"
if s.count(old) != 1: sys.exit("flip-m46: target_gone 函数形状变了")
open(p, 'w').write(s.replace(old, "team_outbox_target_gone() {\n  return 1\n", 1))
PY
cat > "$TMP/patch-sweep.py" <<PY
import sys
p = "$TMP/mut-sweep/scripts/lib/outbox.sh"
s = open(p).read()
old = "team_outbox_sweep_residue() {\n"
if s.count(old) != 1: sys.exit("flip-m46: sweep 函数形状变了")
open(p, 'w').write(s.replace(old, "team_outbox_sweep_residue() {\n  return 0\n", 1))
PY
mk_bash_mut warn "$TMP/patch-warn.py"
mk_bash_mut gone "$TMP/patch-gone.py"
mk_bash_mut sweep "$TMP/patch-sweep.py"

# ---- 聚焦夹具：一个临时项目 = 活 skip 痕迹 + 死目标 held + 框内残留 held + 框外残留 held -----
# 为什么要自己的夹具：烟雾全跑太慢，而这三条断言要能各自对上一处实现。
M46FIX="$TMP/fixture"; mkdir -p "$M46FIX"
FIX_ROOT="$M46FIX/proj"
mkdir -p "$FIX_ROOT/.pi/team/state/outbox/held" "$FIX_ROOT/.pi/team/state/inbox-watch" "$FIX_ROOT/docs/team/inbox"
( cd "$FIX_ROOT" && git init -q -b main . ) >/dev/null 2>&1
printf 'TEAM_PROJECT="m46-flip"\nTEAM_SESSION="live-sess"\nTEAM_PM_WINDOW="pm"\nTEAM_DOCS_DIR="docs/team"\nTEAM_VCS="local"\n' > "$FIX_ROOT/.pi/team/config.sh"
printf 'version=1\ntarget=other-project:pm\nkey=other-project_pm-00000000\nsession=other-project\nwindow=pm\nexpect=live-sess\ninbox=pm\nreason=session-mismatch\ndetail=session other-project != live-sess\npid=%s\ncwd=%s\nheartbeat=%s\n' \
  "$$" "$FIX_ROOT" "$(date +%s)" > "$FIX_ROOT/.pi/team/state/inbox-watch/other-project_pm-00000000.skip"
printf 'kind: say\ntarget: old-session:pi\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-FLIP-DEAD\n' > "$FIX_ROOT/.pi/team/state/outbox/held/1700000000000-0001-old-session:pi.msg"
printf 'kind: say\ntarget: live-sess:pm\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-FLIP-STUCK\n' > "$FIX_ROOT/.pi/team/state/outbox/held/1700000000001-0002-live-sess:pm.msg"
printf 'kind: say\ntarget: live-sess:pm\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-FLIP-BOXCLEAR\n' > "$FIX_ROOT/.pi/team/state/outbox/held/1700000000002-0003-live-sess:pm.msg"
{
  printf '2026-09-20T02:00:00Z name=1700000000000-0001-old-session:pi.msg reason=expired-nopane held-since=x attempts=1 target=old-session:pi\n'
  printf '2026-09-20T02:01:00Z name=1700000000001-0002-live-sess:pm.msg reason=draft-raced-left held-since=x attempts=1 target=live-sess:pm\n'
  printf '2026-09-20T02:02:00Z name=1700000000002-0003-live-sess:pm.msg reason=draft-raced-left held-since=x attempts=1 target=live-sess:pm\n'
} > "$FIX_ROOT/.pi/team/state/outbox/HOLDING.log"

# 假 tmux：live-sess 在；box 里只有 M46-FLIP-STUCK（另一条残留的 payload 已经不在框里）
SHIM="$M46FIX/shim"; mkdir -p "$SHIM"
cat > "$SHIM/tmux" <<'SHIMEOF'
#!/usr/bin/env bash
case "$*" in
  *has-session*) [ "${3:-}" = "live-sess" ] && exit 0 || exit 1 ;;
esac
case "$*" in
  *pane_id*) case " $* " in *" live-sess:"*) printf '%%1\n'; exit 0 ;; esac; exit 1 ;;
  *cursor_y*) printf '2\n'; exit 0 ;;
  *pane_current_command*) printf 'pi\n'; exit 0 ;;
  *bracket_paste_flag*) printf '1\n'; exit 0 ;;
  *list-windows*) printf 'pm\n'; exit 0 ;;
  *capture-pane*) printf 'transcript\n\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\nM46-FLIP-STUCK\n\n\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\xe2\x94\x80\n'; exit 0 ;;
esac
exit 1
SHIMEOF
chmod +x "$SHIM/tmux"

flip_cli() { # <skill 目录> <参数…> → stdout+stderr（身份隔离；fixture 的 shim 在 PATH 最前）
  local skill="$1"; shift
  ( cd "$FIX_ROOT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_STATE_DIR -u TMUX -u TMUX_PANE -u TEAM_INBOX_WATCH_TARGET \
      PATH="$SHIM:$PATH" bash "$skill/scripts/team" "$@" 2>&1 ) || true
}

RC=0

# ---- ① 红树：harness 的 M46 三条必须 FAIL ----
run_harness() { "$TS_RUNNER" "$HARNESS" "$1" 2>&1; }
RED_LOG="$(run_harness "$RED_EXT")"; RED_RC=$?
if [ "$RED_RC" -ne 0 ] \
  && has 'TEAM-IW-CASE FAIL M46-S14' "$RED_LOG" \
  && has 'TEAM-IW-CASE FAIL M46-S15' "$RED_LOG" && has 'TEAM-IW-CASE FAIL M46-S16' "$RED_LOG"; then
  pass "红树（$BASE）复现成功：M46-S14/S15/S16 全红（修复前：跳过无痕、继承的 state 无锚定）"
else
  fail "红树没有复现（rc=$RED_RC；预期 M46-S14/S15/S16 全 FAIL）"
  printf '%s\n' "$RED_LOG" | grep 'TEAM-IW-CASE' | tail -8 | sed 's/^/     /'
  RC=1
fi

# ---- ② 本树：harness 必须全绿 ----
GREEN_LOG="$(run_harness "$GREEN_EXT")"; GREEN_RC=$?
GREEN_N="$(printf '%s\n' "$GREEN_LOG" | grep -c 'TEAM-IW-CASE PASS')"
if [ "$GREEN_RC" -eq 0 ] && has 'TEAM-IW-HARNESS OK' "$GREEN_LOG"; then
  pass "本树：harness 全绿（$GREEN_N 条用例，含 M46-S14/S15/S16）"
else
  fail "本树不是全绿（rc=$GREEN_RC）"
  printf '%s\n' "$GREEN_LOG" | grep 'TEAM-IW-CASE FAIL' | sed 's/^/     /'
  RC=1
fi

# ---- ③ 变异扩展：writeSkipRecord 空操作 → S14 必须红 ----
MUT_LOG="$(run_harness "$MUT_EXT_DIR/extension/team-inbox-watch.ts")"; MUT_RC=$?
if [ "$MUT_RC" -ne 0 ] && has 'TEAM-IW-CASE FAIL M46-S14' "$MUT_LOG"; then
  pass "变异扩展（writeSkipRecord 空操作）：M46-S14 红 —— 守卫测试咬在留痕实现上"
else
  fail "变异扩展没有红（rc=$MUT_RC；预期 M46-S14 FAIL）"
  printf '%s\n' "$MUT_LOG" | grep 'TEAM-IW-CASE' | tail -6 | sed 's/^/     /'
  RC=1
fi

# ---- ④ 变异 bash：三处单点破坏 → 同夹具上的三条断言各自变红 ----
GREEN_STATUS="$(flip_cli "$GREEN" status)"
MUT_STATUS="$(flip_cli "$TMP/mut-warn" status)"
if has '投递通道降级' "$GREEN_STATUS" && ! has '投递通道降级' "$MUT_STATUS"; then
  pass "bash 变异①（告警行恒假）：绿树 status 报降级 / 变异树不报 —— 这条断言真的钉在告警实现上"
else
  fail "bash 变异① 翻转不成立（绿树：$(printf '%s' "$GREEN_STATUS" | grep -c '投递通道降级') 条降级；变异树：$(printf '%s' "$MUT_STATUS" | grep -c '投递通道降级') 条）"
  RC=1
fi
GREEN_LIST="$(flip_cli "$GREEN" outbox list)"
MUT_LIST="$(flip_cli "$TMP/mut-gone" outbox list)"
if has 'target=gone' "$GREEN_LIST" && ! has 'target=gone' "$MUT_LIST"; then
  pass "bash 变异②（target_gone 恒假）：绿树 list 标 target=gone / 变异树不标 —— 断言钉在死目标判定上"
else
  fail "bash 变异② 翻转不成立（绿树：$(printf '%s' "$GREEN_LIST" | grep -c 'target=gone')；变异树：$(printf '%s' "$MUT_LIST" | grep -c 'target=gone')）"
  RC=1
fi
# 残留巡检：先绿树 flush → 记账本；变异树用自己的夹具副本（HOLDING.log 也拷一份）
cp -a "$FIX_ROOT" "$TMP/fixture-mut"
( cd "$TMP/fixture-mut" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    -u TEAM_STATE_DIR -u TMUX -u TMUX_PANE -u TEAM_INBOX_WATCH_TARGET \
    PATH="$SHIM:$PATH" bash "$TMP/mut-sweep/scripts/team" outbox flush ) >/dev/null 2>&1 || true
flip_cli "$GREEN" outbox flush >/dev/null
GREEN_SWEEP="$(grep -c 'residue-clear entry=1700000000002-0003' "$FIX_ROOT/.pi/team/state/outbox/HOLDING.log" || true)"
MUT_SWEEP="$(grep -c 'residue-clear entry=1700000000002-0003' "$TMP/fixture-mut/.pi/team/state/outbox/HOLDING.log" || true)"
if [ "$GREEN_SWEEP" -ge 1 ] && [ "$MUT_SWEEP" -eq 0 ]; then
  pass "bash 变异③（residue sweep 空操作）：绿树记 residue-clear / 变异树不记 —— 断言钉在巡检实现上"
else
  fail "bash 变异③ 翻转不成立（绿树=$GREEN_SWEEP，变异树=$MUT_SWEEP）"
  RC=1
fi

printf 'exit=%s\n' "$RC"
exit "$RC"
