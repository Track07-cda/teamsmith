#!/usr/bin/env bash
# P210 · 独立验证包：**裸 shell 的 pane 不算在跑**（判据收紧）的 red → green → 判据翻转（影子）
#
#   bash skills/teamsmith/tests/flip-p210.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-p210.sh   # 覆盖「修复前」的 revision
#   KEEP=1 bash skills/teamsmith/tests/flip-p210.sh                # 保留临时根排查
#
# 事故（2026-10-03→04，实测）：dev-bob 的 `pi` 退出后 pane 只剩一个裸 shell（tmux 报
# `pane_current_command=bash`、没有 agent 子进程），而 `team_agent_alive_in_pane` 仍判活 ——
# 它接受的是「pane 的进程树里某个命令行里出现 agent 可执行文件」。遗体 pane（pane_dead=1）的
# `pane_pid` 是**过期的号**：内核会把号回收给别的进程（本机 pid 空间 4M、实测 churn ~2 万/分钟），
# 回收到的那个进程命令行里一旦出现 agent 路径，判据就把一个没有进程的 pane 说成「在跑」。
# 连带后果：pulse 每 15 分钟算一次「无待办」（看板 wip 的 P103 报告 26 小时没人复验），
# `team resume --dry-run` 也报「没有需要续跑的 agent（在跑 N 个）」。
#
# 本包对**同一套真 tmux 夹具**跑三棵树，入口有库函数（team_agent_live）与 CLI（resume --dry-run）两层：
#   ① 裸 shell + argv 里带 agent 路径（没有 agent 子进程）—— 事故读数：红树 alive（假活复现）→ 绿树 stopped
#   ② 真在跑（交互 bash + agent 子进程，M37 事故形状）—— 绿树必须 alive（不许把误杀放回来）
#   ③ 对照（bash 里没有 agent 子进程）—— 两棵树都 stopped
#   ④ 遗体 pane（pane_dead=1，号已过期）—— 绿树 stopped（判据不去读那个号）
#   ⑤ 判据翻转：绿树副本把 P210 的两道判据改回旧行为 → ① 与 ④ 的同段代码路径必须重新判 alive（红）
#
# 只写 /tmp 下的临时目录，只碰自己起的私有 tmux session（结束清理）；离开前证明 socket 是私有的。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$SELF_DIR/lib/tmux-iso.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p210: 找不到 git 仓库（本脚本需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-p210: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-p210: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p210)" || exit 3
SESS="teamsmith-flip-p210-$$"

# M28/#1250：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— 事故形状）。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "flip-p210" "收尾：私有 session" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$TMP" \
    && tmux kill-session -t "$SESS" 2>/dev/null || true
  tmp_root_reap_all
}
trap cleanup EXIT

# ---- 三棵树：红（修复前） / 绿（本 worktree） / 变异（绿 + 把 P210 的两道判据改回去）--------
mkdir -p "$TMP/red-skill" "$TMP/fake-bin" "$TMP/repo" "$TMP/mut-skill"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_SKILL="$TMP/red-skill/skills/teamsmith"
# 守卫：传进来的 base 必须真的还是「修复前」（否则这个包会报一个假的翻转）
if grep -q 'team_pane_facts' "$RED_SKILL/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-p210: $BASE 已经包含 P210 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
cp -a "$SKILL_DIR/scripts" "$TMP/mut-skill/scripts"
if ! grep -q 'team_pane_facts' "$TMP/mut-skill/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-p210: 变异树的底子不是修复后的树（找不到 team_pane_facts）\n' >&2; exit 2
fi
cat >> "$TMP/mut-skill/scripts/lib/common.sh" <<'MUTEOF'

# ---- FLIP P210（只在变异树里）：把 P210 的两道判据改回去 —— 裸 shell / 遗体 pane 都算活 ----
team_agent_alive_in_pane() { # <session:window>
  local target="${1:-}" pid cwd
  [ -n "$target" ] || return 1
  pid="$(team_pane_agent_pid "$target" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  cwd="$(team_proc_cwd "$pid" 2>/dev/null || true)"
  [ -n "$cwd" ] || return 1
  team_cwd_in_project "$cwd"
}
MUTEOF
MUT_SKILL="$TMP/mut-skill"
if grep -q 'FLIP P210' "$MUT_SKILL/scripts/lib/common.sh"; then :; else
  printf 'flip-p210: 变异树没打上补丁（判据翻转会空跑）\n' >&2; exit 2
fi

# ---- 夹具仓库 + 假 agent ----------------------------------------------------
cat > "$TMP/fake-bin/p210-agent" <<'EOF'
#!/usr/bin/env bash
sleep 600
EOF
chmod +x "$TMP/fake-bin/p210-agent"
AGENT="$TMP/fake-bin/p210-agent"

cd "$TMP/repo" || exit 2
git init -q .; git config user.email t@t; git config user.name t
echo hi > README.md; git add -A; git commit -qm init >/dev/null; git branch -m main
bash "$SKILL_DIR/scripts/team" init --session "$SESS" --yes >/dev/null 2>&1
mkdir -p .pi/team/state docs/team/reports
printf '# P210 夹具任务\n' > "$TMP/task.md"
printf 'task=T1.1\ntaskfile=%s\nwindow=p210bare\n' "$TMP/task.md" > .pi/team/state/p210bare.env
printf 'task=T1.1\ntaskfile=%s\nwindow=p210run\n'  "$TMP/task.md" > .pi/team/state/p210run.env
printf 'task=T1.1\ntaskfile=%s\nwindow=p210ctl\n'  "$TMP/task.md" > .pi/team/state/p210ctl.env
printf 'task=T1.1\ntaskfile=%s\nwindow=p210dead\n' "$TMP/task.md" > .pi/team/state/p210dead.env
REPO="$TMP/repo"

# ---- 真 tmux 夹具（四棵树共用，绝不重建）------------------------------------
tmux new-session -d -s "$SESS" -n anchor -c "$REPO" "sleep 100000" 2>/dev/null || exit 2
# 隔离证明：真 tmux 报出来的 socket 就是私有目录里的那个
SOCK="$(tmux list-sessions -F '#{socket_path}' 2>/dev/null | head -1)"
if [ "$SOCK" != "$TMUX_TMPDIR/tmux-$(id -u)/default" ]; then
  printf 'flip-p210: 私有 socket 没生效（报出 %s）——拒绝继续\n' "${SOCK:-?}" >&2; exit 2
fi
# ① 事故读数：裸 shell（comm=bash），argv 里带着 agent 路径，没有 agent 子进程
tmux new-window -t "$SESS" -n p210bare -d -c "$REPO" -- bash --noprofile --norc -s "$AGENT" 2>/dev/null || true
# ② 真在跑：交互 bash + agent 子进程（M37 事故形状）
tmux new-window -t "$SESS" -n p210run -d -c "$REPO" -- bash --noprofile --norc 2>/dev/null || true
tmux send-keys -t "$SESS:p210run" 'set +m' Enter 2>/dev/null || true
tmux send-keys -t "$SESS:p210run" "\"$AGENT\" --p210" Enter 2>/dev/null || true
# ③ 对照：bash 里没有 agent 子进程
tmux new-window -t "$SESS" -n p210ctl -d -c "$REPO" -- bash -c 'sleep 600 && true' 2>/dev/null || true
# ④ 遗体 pane：进程已退出，pane_pid 是过期的号（内核之后会把号回收给别人）
tmux new-window -t "$SESS" -n p210dead -d -c "$REPO" 'sleep 30' 2>/dev/null || true
tmux set-window-option -t "$SESS:p210dead" remain-on-exit on 2>/dev/null || true
tmux respawn-pane -k -t "$SESS:p210dead" 'sleep 0.2' 2>/dev/null || true
p210_i=0
while [ "$p210_i" -lt 50 ] && [ "$(tmux list-panes -t "$SESS:p210dead" -F '#{pane_dead}' 2>/dev/null | head -1)" != "1" ]; do
  sleep 0.1; p210_i=$((p210_i + 1))
done
# ① 的 agent 子进程必须还没起来（否则测的不是「裸 shell」）
p210_j=0
while [ "$p210_j" -lt 20 ]; do
  case "$(ps -o args= --ppid "$(tmux list-panes -t "$SESS:p210bare" -F '#{pane_pid}' 2>/dev/null | head -1)" 2>/dev/null | tr '\n' ';')" in
    *"$AGENT"*) sleep 0.1; p210_j=$((p210_j + 1)) ;;
    *) break ;;
  esac
done

printf '夹具现场（%s）：\n' "$SESS"
tmux list-panes -a -F '  #{window_name}: pane_pid=#{pane_pid} dead=#{pane_dead} cmd=#{pane_current_command}' | grep -v anchor || true
for _w in p210bare p210run p210ctl p210dead; do
  _p="$(tmux list-panes -t "$SESS:$_w" -F '#{pane_pid}' 2>/dev/null | head -1)"
  printf '  %-9s pane 命令行=[%s] 子进程=[%s]\n' "$_w" \
    "$(ps -o args= -ww -p "$_p" 2>/dev/null | head -1)" \
    "$(ps -o args= --ppid "$_p" 2>/dev/null | tr '\n' ';')"
done

# ---- 探针：库函数层（team_agent_live）与 CLI 层（resume --dry-run），只换树 -------------
p210_live() { # <skill-dir> <agent> → alive|stopped
  local dir="$1" agent="$2"
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      TEAM_SESSION="$SESS" TEAM_PI_BIN="$AGENT" TEAM_AGENTS="p210bare p210run p210ctl p210dead" \
      bash -c '. "'"$dir"'/scripts/lib/common.sh"
               for _f in "'"$dir"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
               team_load_config >/dev/null 2>&1
               if team_agent_live "$1"; then printf "alive\n"; else printf "stopped\n"; fi' _ "$agent" )
}
p210_resume() { # <skill-dir> → resume --dry-run 的输出（同一夹具、同一入口）
  local dir="$1"
  ( cd "$REPO" && env TEAM_AGENTS="p210bare p210run p210ctl p210dead" TEAM_PI_BIN="$AGENT" \
      TEAM_SESSION="$SESS" bash "$dir/scripts/team" resume --dry-run 2>&1 || true )
}

printf '\n修复前 revision: %s（%s）\n修复后 skill:  %s\n变异树:        %s（P210 两道判据改回旧行为）\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR" "$MUT_SKILL"

printf '\n同一夹具、三种树的判定（入口 team_agent_live）：\n'
printf '  %-24s %-14s %-14s %-14s\n' "形状" "红(修复前)" "绿(修复后)" "变异(判据改回)"
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
declare -A V
for _w in p210bare p210run p210ctl p210dead; do
  V["red_$_w"]="$(p210_live "$RED_SKILL" "$_w")"
  V["green_$_w"]="$(p210_live "$SKILL_DIR" "$_w")"
  V["mut_$_w"]="$(p210_live "$MUT_SKILL" "$_w")"
  printf '  %-24s %-14s %-14s %-14s\n' "$_w" "${V[red_$_w]}" "${V[green_$_w]}" "${V[mut_$_w]}"
done

printf '\nCLI 层（team resume --dry-run，同一夹具）：\n'
RED_RESUME="$(p210_resume "$RED_SKILL")"
GREEN_RESUME="$(p210_resume "$SKILL_DIR")"
MUT_RESUME="$(p210_resume "$MUT_SKILL")"
printf '  红(修复前)：%s\n' "$(printf '%s' "$RED_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')"
printf '  绿(修复后)：%s\n' "$(printf '%s' "$GREEN_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')"
printf '  变异：      %s\n' "$(printf '%s' "$MUT_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')"

printf '\n== 翻转断言 ==\n'
# 红侧：事故读数（裸 shell 的 argv 里带着 agent 路径）被判 alive —— 修复前就是这个假活
if [ "${V[red_p210bare]}" = "alive" ]; then
  ok "修复前：裸 shell（argv 带 agent 路径、无 agent 子进程）判 alive —— 假活复现（P103 被漏掉一天的那个读数）"
else
  bad "修复前：裸 shell 竟然判 ${V[red_p210bare]}（没有复现出假活，夹具或基线不对）"
fi
# 绿侧：同一夹具判停
if [ "${V[green_p210bare]}" = "stopped" ]; then ok "修复后：同一裸 shell 判 stopped（判据收紧）"
else bad "修复后：裸 shell 仍判 ${V[green_p210bare]}（修复没生效）"; fi
# M37 的承诺不许被误杀放倒：真在跑还是 alive
if [ "${V[green_p210run]}" = "alive" ]; then ok "修复后：真在跑（bash 父 + agent 子）仍判 alive（没有误杀）"
else bad "修复后：真在跑的席位被判 ${V[green_p210run]}（M37 的误杀被放回来了）"; fi
if [ "${V[red_p210run]}" = "alive" ]; then ok "修复前：真在跑的席位也是 alive（夹具对两棵树都成立）"
else bad "修复前：真在跑的席位判 ${V[red_p210run]}（夹具不对）"; fi
# 对照：没有 agent 子进程 → 两棵树都判停
if [ "${V[green_p210ctl]}" = "stopped" ] && [ "${V[red_p210ctl]}" = "stopped" ]; then
  ok "对照：bash 里没有 agent 子进程 → 两棵树都判 stopped"
else bad "对照不成立：红=${V[red_p210ctl]} 绿=${V[green_p210ctl]}"; fi
# 遗体 pane：绿树不去读那个过期的号 → 判停
if [ "${V[green_p210dead]}" = "stopped" ]; then ok "修复后：遗体 pane（pane_dead=1，pane_pid 是过期的号）判 stopped"
else bad "修复后：遗体 pane 判 ${V[green_p210dead]}（pane_dead=1 没被当成不在跑）"; fi
# CLI 层：修复前 resume **不列**该席位（假活把它当「在跑」），修复后列成可续跑；判据改回又不列
if printf '%s' "$RED_RESUME" | grep -q "p210bare 可续跑"; then
  bad "修复前 CLI：resume 竟然把裸 shell 的席位列成可续跑（夹具或基线不对）"
else
  ok "修复前 CLI：resume --dry-run **不列**该席位（假活＝「在跑」，P103 就是这样被藏一天的）"
fi
if printf '%s' "$GREEN_RESUME" | grep -q "p210bare 可续跑"; then
  ok "修复后 CLI：resume --dry-run 把裸 shell 的席位列成可续跑"
else
  bad "修复后 CLI：resume 没有列出该席位（现场：$(printf '%s' "$GREEN_RESUME" | tr '\n' ' ')）"
fi
if printf '%s' "$MUT_RESUME" | grep -q "p210bare 可续跑"; then
  bad "判据翻转没红：变异树的 resume 仍然列出了席位（翻转实验没构造住）"
else
  ok "判据翻转：把 P210 的判据改回旧行为 → CLI 又不列该席位（断言会红）"
fi
# 判据翻转：变异树必须把 ① 判回 alive
if [ "${V[mut_p210bare]}" = "alive" ]; then
  ok "判据翻转：变异树对裸 shell 判 alive（绿树断言咬的就是这两道判据）"
else
  bad "判据翻转没红：变异树对裸 shell 判 ${V[mut_p210bare]}（影子没盖住判据）"
fi

printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-p210：翻转已复现（裸 shell 红 → 绿；判据改回即红）\033[0m\n'; exit 0; }
printf '\033[31mflip-p210：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
