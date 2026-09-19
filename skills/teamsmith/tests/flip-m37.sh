#!/usr/bin/env bash
# M37 · 独立验证包：worker 存活判据的 red → green 复现 + 判据翻转（红 → 绿 → 破环即红）
#
#   bash skills/teamsmith/tests/flip-m37.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m37.sh   # 覆盖「修复前」的 revision
#
# 事故（2026-09-19 实测两次假告警）：worker 窗口的 pane_pid 是 bash、真在干活的是它的子进程 pi，
# `pane_current_command` 于是报 bash。旧 `team_agent_live` = 窗口在 + `team_pane_busy`
# （pane_current_command + 前台进程组），把这个形状判成「停了」——pulse 的「停了的 agent」两次误报。
#
# 本包对**同一套真 tmux 夹具**跑三种树，入口都是同一个公开函数 `team_agent_live`（不改夹具）：
#   ① 事故形状（交互 bash，argv 只有选项；`set +m` 关掉 job control 后 agent 与 shell 同进程组）：
#      红树（修复前）→ stopped（假告警复现）；绿树（本 worktree）→ alive（修复后）
#   ② 字面形状 `bash -c '<agent> …'`：绿树 alive（简报里的验收形状）
#   ③ 判据翻转：绿树的副本把 worker 判据改回「只看 pane_current_command」→ 同一夹具必须 stopped（红）
#   ④ 对照：bash 里没有 agent 子进程 → 绿树 stopped（旧判据在这里反而说 alive，一并记录）
#
# 只写 /tmp 下的临时目录，只动自己起的 tmux session（结束时清理）；不碰调用者所在的任何仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m37: 找不到 git 仓库（本脚本需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m37: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m37: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m37.XXXXXX)"
SESS="teamsmith-flip-m37-$$"

# M28/#1250：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— 事故形状）。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  tmux kill-session -t "$SESS" 2>/dev/null || true
  rm -rf "$TMP"
}
trap cleanup EXIT

# ---- 三种树：红（修复前） / 绿（本 worktree） / 变异（绿 + 「只看 pane_current_command」）--------
mkdir -p "$TMP/red-skill" "$TMP/fake-bin" "$TMP/repo" "$TMP/mut-skill"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_SKILL="$TMP/red-skill/skills/teamsmith"
# 守卫：传进来的 base 必须真的还是「修复前」（否则这个包会报一个假的翻转）
if grep -q 'team_agent_alive_in_pane' "$RED_SKILL/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-m37: $BASE 已经包含 M37 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
cp -a "$SKILL_DIR/scripts" "$TMP/mut-skill/scripts"
cat >> "$TMP/mut-skill/scripts/lib/common.sh" <<'MUTEOF'

# ---- FLIP M37（只在变异树里）：判据改回「只看 pane_current_command」，不用进程树 ----
team_agent_alive_in_pane() { # <session:window>
  local target="${1:-}" cmd want
  [ -n "$target" ] || return 1
  cmd="$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null | head -1)"
  [ -n "$cmd" ] || return 1
  want="$(basename "$(team_agent_bin_path 2>/dev/null || true)")"
  [ -n "$want" ] && [ "$cmd" = "$want" ]
}
MUTEOF
MUT_SKILL="$TMP/mut-skill"
if grep -q 'FLIP M37' "$MUT_SKILL/scripts/lib/common.sh"; then :; else
  printf 'flip-m37: 变异树没打上补丁（判据翻转会空跑）\n' >&2; exit 2
fi

# ---- 夹具仓库 + 假 agent ----------------------------------------------------
cat > "$TMP/fake-bin/m37-agent" <<'EOF'
#!/usr/bin/env bash
sleep 600
EOF
chmod +x "$TMP/fake-bin/m37-agent"
AGENT="$TMP/fake-bin/m37-agent"

cd "$TMP/repo" || exit 2
git init -q .; git config user.email t@t; git config user.name t
echo hi > README.md; git add -A; git commit -qm init >/dev/null; git branch -m main
bash "$SKILL_DIR/scripts/team" init --session "$SESS" --yes >/dev/null 2>&1
mkdir -p .pi/team/state
# 三个「有任务、窗口名固定」的 agent 记录：team_agent_live 的窗口来自 state
printf 'task=T1.1\nwindow=m37w\n'    > .pi/team/state/m37w.env
printf 'task=T1.1\nwindow=m37-lit\n' > .pi/team/state/m37lit.env
printf 'task=T1.1\nwindow=m37-ctl\n' > .pi/team/state/m37ctl.env
REPO="$TMP/repo"

# ---- 真 tmux 夹具（形状在下面注释里；三棵树共用，绝不重建）------------------
tmux new-session -d -s "$SESS" -n anchor -c "$REPO" "sleep 100000" 2>/dev/null || exit 2
# ① 事故形状：交互 bash（argv 只有 --noprofile --norc），set +m 关掉 job control 后前台跑 agent
tmux new-window -t "$SESS" -n m37w -d -c "$REPO" -- bash --noprofile --norc 2>/dev/null || true
tmux send-keys -t "$SESS:m37w" 'set +m' Enter 2>/dev/null || true
tmux send-keys -t "$SESS:m37w" "\"$AGENT\" --m37" Enter 2>/dev/null || true
# ② 字面形状：bash 是 pane_pid，agent 是它的子进程（bash -c '<agent> …'）
tmux new-window -t "$SESS" -n m37-lit -d -c "$REPO" -- bash -c "\"$AGENT\" --m37 & wait; sleep 600" 2>/dev/null || true
# ④ 对照：bash 里没有 agent 子进程
tmux new-window -t "$SESS" -n m37-ctl -d -c "$REPO" -- bash -c 'sleep 600 && true' 2>/dev/null || true

m37_child_of() { # <session:window> → 命中夹具 agent 的直接子进程 pid（没有 → 空）
  local p; p="$(tmux display-message -p -t "$1" '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$p" ] || return 0
  ps -o pid=,args= --ppid "$p" 2>/dev/null | grep -F -- "$AGENT" | awk '{print $1; exit}'
}
m37_i=0
while [ "$m37_i" -lt 50 ] && { [ -z "$(m37_child_of "$SESS:m37w")" ] || [ -z "$(m37_child_of "$SESS:m37-lit")" ]; }; do
  sleep 0.1; m37_i=$((m37_i + 1))
done
printf '夹具现场：\n'
for _w in m37w m37-lit m37-ctl; do
  printf '  %-8s %s  子进程=%s\n' "$_w" \
    "$(tmux display-message -p -t "$SESS:$_w" 'pane_pid=#{pane_pid} cmd=#{pane_current_command}' 2>/dev/null | tr -d '\n')" \
    "$(m37_child_of "$SESS:$_w" || true)"
done

# ---- 探针：同一入口 team_agent_live，只换树 ----------------------------------
m37_live() { # <skill-dir> <agent> → alive|stopped
  local dir="$1" agent="$2"
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      TEAM_SESSION="$SESS" TEAM_PI_BIN="$AGENT" TEAM_AGENTS="dev verify m37w m37lit m37ctl" \
      bash -c '. "'"$dir"'/scripts/lib/common.sh"
               for _f in "'"$dir"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
               team_load_config >/dev/null 2>&1
               if team_agent_live "$1"; then printf "alive\n"; else printf "stopped\n"; fi' _ "$agent" )
}

printf '\n修复前 revision: %s（%s）\n修复后 skill:  %s\n变异树:        %s（只看 pane_current_command）\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR" "$MUT_SKILL"

RED_INCIDENT="$(m37_live "$RED_SKILL" m37w)"
GREEN_INCIDENT="$(m37_live "$SKILL_DIR" m37w)"
MUT_INCIDENT="$(m37_live "$MUT_SKILL" m37w)"
GREEN_LITERAL="$(m37_live "$SKILL_DIR" m37lit)"
RED_LITERAL="$(m37_live "$RED_SKILL" m37lit)"
MUT_LITERAL="$(m37_live "$MUT_SKILL" m37lit)"
GREEN_CONTROL="$(m37_live "$SKILL_DIR" m37ctl)"
RED_CONTROL="$(m37_live "$RED_SKILL" m37ctl)"
printf '\n同一夹具、三种树的判定（entry=team_agent_live）：\n'
printf '  %-10s 红(修复前)=%-8s 绿(修复后)=%-8s 变异(只看pane_current_command)=%s\n' \
  "① 事故形状" "$RED_INCIDENT" "$GREEN_INCIDENT" "$MUT_INCIDENT"
printf '  %-10s 红(修复前)=%-8s 绿(修复后)=%-8s 变异(只看pane_current_command)=%s\n' \
  "② 字面形状" "$RED_LITERAL" "$GREEN_LITERAL" "$MUT_LITERAL"
printf '  %-10s 红(修复前)=%-8s 绿(修复后)=%-8s 变异(只看pane_current_command)=%s\n' \
  "④ 对照(无子)" "$RED_CONTROL" "$GREEN_CONTROL" "-"

# ---- 断言 ----------------------------------------------------------------
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
printf '\n== 翻转断言 ==\n'
# 夹具有效性：修复前的判据不是「什么都判停」（字面形状它认得出在跑）
if [ "$RED_LITERAL" = "alive" ]; then ok "夹具有效性：修复前的判据认得字面形状（bash -c '<agent> …' → alive）"
else bad "夹具有效性：修复前把字面形状也判成 $RED_LITERAL（夹具或基线不对）"; fi
# 历史翻转：事故形状（正在干活的 agent）修复前判「停了」，修复后判「在跑」
if [ "$RED_INCIDENT" = "stopped" ]; then ok "修复前：事故形状（pane_current_command=bash，agent 是同进程组子进程）被判 $RED_INCIDENT —— 假告警复现"
else bad "修复前：事故形状竟然判 $RED_INCIDENT（没有复现出 M37 的假告警）"; fi
if [ "$GREEN_INCIDENT" = "alive" ]; then ok "修复后：同一事故形状判 alive（pane 进程树命中）"
else bad "修复后：事故形状仍判 $GREEN_INCIDENT（修复没生效）"; fi
if [ "$GREEN_LITERAL" = "alive" ]; then ok "修复后：字面形状（bash 父 + agent 子）判 alive"
else bad "修复后：字面形状判 $GREEN_LITERAL"; fi
# 判据翻转：改回只看 pane_current_command → 同一夹具必须红
if [ "$MUT_INCIDENT" = "stopped" ] && [ "$MUT_LITERAL" = "stopped" ]; then
  ok "判据翻转：只看 pane_current_command 的副本对两种形状都判 stopped（断言会红）"
else bad "判据翻转没红：事故形状=$MUT_INCIDENT 字面形状=$MUT_LITERAL（翻转实验没构造住）"; fi
# 对照：没有 agent 子进程 → 判停（修复后不再把「pane 忙」当身份）
if [ "$GREEN_CONTROL" = "stopped" ]; then ok "对照：bash 里没有 agent 子进程 → 修复后判 stopped"
else bad "对照：没有 agent 子进程却判 $GREEN_CONTROL"; fi
if [ "$RED_CONTROL" = "alive" ]; then ok "对照（旧判据的反面）：修复前把「pane 忙」当身份 → 判 alive（假阳性，一并记录）"
else printf '  \033[33m!\033[0m 说明：对照在修复前判 %s（不是预期的假阳性形状，不影响本次翻转结论）\n' "$RED_CONTROL"; fi

printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-m37：翻转已复现（事故形状红 → 绿；判据改回 pane_current_command 即红）\033[0m\n'; exit 0; }
printf '\033[31mflip-m37：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
