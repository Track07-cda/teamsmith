#!/usr/bin/env bash
# M6.5 · 独立验证包：假 PM 存活（`team up` 谎报）的 red → green 复现
#
#   bash skills/teamsmith/tests/flip-m6.5.sh            # 红树 = HEAD 的父提交（TEAM_FLIP_BASE 可覆盖），绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m6.5.sh
#
# 为什么需要：M6.5 的失效格是「cwd 在项目内 + 前台不是 shell」——空 session 刚建好时那个进程名在本环境是
# `tmux`，于是老规则判 `running:tmux`，`team up` 打印「PM 在运行」却不启动任何东西。这里把这一格**确定性地**
# 造出来（窗口里跑 `tmux wait-for`，cwd 用夹具仓库），对「修复前 / 修复后」两份 skill 跑同一条命令：
#
#   红：up **不**启动假 agent，且 argv 日志为空（旧输出含「PM 在运行（tmux）」）
#   绿：up 真的启动假 agent，argv 日志里出现 `-c` 与 `@pm-prompt.md`
#
# 只写 /tmp 下的临时目录，只动自己起的 tmux session（结束时清理）；不碰调用者所在的任何仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m6.5: 找不到 git 仓库（本脚本需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m6.5: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  # 默认：与保护分支的分叉点（M6.5 的修复提交都在它之后）
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m6.5: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-m6.5)" || exit 3
SESS="teamsmith-flip-m65-$$"

# M28：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— M23 事故形状）。
# unset TMUX + 私有 TMUX_TMPDIR；工具在私有 server 的窗口里跑，继承同一套环境。口径见 tests/tmux-lint.pl。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
cleanup() { tmux kill-session -t "$SESS" 2>/dev/null || true; tmp_root_reap_all; }
trap cleanup EXIT

# ---- 夹具：临时仓库 + teamsmith init + 记录 argv 的假 agent --------------------
mkdir -p "$TMP/red-skill" "$TMP/fake-bin" "$TMP/repo"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_SKILL="$TMP/red-skill/skills/teamsmith"
# 守卫：传进来的 base 必须真的还是「修复前」（否则这个包会报一个假的「翻转」）
if grep -q 'team_pm_pid_live' "$RED_SKILL/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-m6.5: $BASE 已经包含 M6.5 的修复（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
cat > "$TMP/fake-bin/pi-log" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$TMP/pm-args.log"
sleep 600
EOF
chmod +x "$TMP/fake-bin/pi-log"

cd "$TMP/repo" || exit 2
git init -q .; git config user.email t@t; git config user.name t
echo hi > README.md; git add -A; git commit -qm init >/dev/null; git branch -m main
bash "$SKILL_DIR/scripts/team" init --yes >/dev/null 2>&1
sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$TMP/fake-bin/pi-log\"|" .pi/team/config.sh

# ---- 造「cwd 在项目内 + 前台不是 shell（tmux）」这一格，然后跑某一版 skill 的 up ----
false_liveness_scene() {
  tmux kill-session -t "$SESS" 2>/dev/null || true
  tmux new-session -d -s "$SESS" -n pm -c "$TMP/repo" 2>/dev/null || true
  tmux respawn-pane -k -t "$SESS:pm" "cd $TMP/repo && exec tmux wait-for flip-m65-never" >/dev/null 2>&1 || true
  sleep 1
}
run_up() { # <skill-dir> <tag>
  false_liveness_scene
  rm -f "$TMP/pm-args.log"
  TEAM_SESSION="$SESS" TEAM_ROOT="$TMP/repo" TEAM_PI_BIN="$TMP/fake-bin/pi-log" \
    bash "$1/scripts/team" up > "$TMP/up-$2.log" 2>&1
  printf '\n=== [%s] 现场：%s ===\n' "$2" "$(tmux display-message -p -t "$SESS:pm" 'pane_pid=#{pane_pid} cmd=#{pane_current_command}' 2>/dev/null || echo '?')"
  printf '=== [%s] team up 输出 ===\n' "$2"; cat "$TMP/up-$2.log"
  printf '=== [%s] 假 agent argv 日志 ===\n' "$2"
  if [ -s "$TMP/pm-args.log" ]; then cat "$TMP/pm-args.log"; else printf '(空：没有任何 agent 被启动)\n'; fi
}

printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n' "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR"
run_up "$RED_SKILL" red
RED_UP="$TMP/up-red.log"; RED_ARGS="$TMP/pm-args.log"; cp -f "$RED_ARGS" "$TMP/red-args.snapshot" 2>/dev/null || :
run_up "$SKILL_DIR" green

# ---- 断言 ----------------------------------------------------------------
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
printf '\n== 翻转断言 ==\n'
if grep -qF 'PM 已启动' "$RED_UP"; then bad "修复前：up 竟然启动了 PM（夹具没造出假存活格）"
else ok "修复前：up 没有启动 PM（旧输出：$(grep -F 'PM 在运行' "$RED_UP" | head -1 | sed 's/^[[:space:]]*//' || echo '—')）"; fi
if [ -s "$TMP/red-args.snapshot" ]; then bad "修复前：假 agent 被启动了（argv 日志非空）"; else ok "修复前：假 agent 从未被调用（argv 日志为空）"; fi
if grep -qF 'PM 已启动' "$TMP/up-green.log"; then ok "修复后：up 真的启动了 PM"; else bad "修复后：up 没有启动 PM"; fi
if [ -s "$RED_ARGS" ] && grep -qF -- '-c' "$RED_ARGS" && grep -qF 'pm-prompt.md' "$RED_ARGS"; then
  ok "修复后：假 agent argv 里有 -c 与 @pm-prompt.md"
else bad "修复后：argv 日志缺 -c / pm-prompt.md"; fi

printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-m6.5：翻转已复现（红 → 绿）\033[0m\n'; exit 0; }
printf '\033[31mflip-m6.5：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
