#!/usr/bin/env bash
# P217 · 独立验证包：**pane_pid 自己就在跑那个 agent（argv[1] 就是它）算在跑** 的 red → green → 判据翻转（影子）
#
#   bash skills/teamsmith/tests/flip-p217.sh
#   TEAM_FLIP_PRE217=<sha> bash skills/teamsmith/tests/flip-p217.sh   # 覆盖「P217 之前」的 revision
#   KEEP=1 bash skills/teamsmith/tests/flip-p217.sh                   # 保留临时根排查
#
# 事故（P214 独立诊断的现场，2026-10-04）：P210 的判据在「前台是裸 shell」那一支只认**直接子进程**
# （`team_agent_alive_in_pane` 的 children 扫描），于是把「脚本型 agent 被直接当 pane 命令起」的形状
# （`bash <agent>`，argv[1] 就是它）也一起判成 exited。同一个形状在 §41 的夹具里，读数是两条红：
# `roster 四态 ① running` 与机器面 `state=exited`。代价是**反方向**的假告警：判停 → `team resume` 的
# 下一步 respawn → 杀掉一个正在干活的 agent（比假活更贵）。
#
# 本包对**同一套真 tmux 夹具**跑三棵树（入口有库函数 team_agent_live 与 CLI resume --dry-run 两层）：
#   s1 `bash <agent>`（argv[1] 就是它、没有 agent 子进程）—— P217 修的那个形状：pre 树 stopped → green 树 alive
#   s2 外层 `bash -lc <agent>`（bash 对 -c 的最后一条命令直接 exec → 与 s1 同形）—— 与 s1 同判
#   s3 `bash -lc '<agent> & wait'`（agent 是**直接子进程**）—— M37 的承诺，两棵树都必须 alive
#   s4 `bash -lc '<agent>; :'`（**生产 harness 的形状**：前后都有语句、末尾 exec bash）—— 两棵树都必须 alive
#   s5 `bash --noprofile --norc -s <agent>`（P103 的假活形状：argv[1] 是选项，agent 只是参数）—— green 树必须 stopped
#   s6 `bash -c 'sleep 600 && true'`（对照：命令行里根本没有 agent）—— 两棵树都必须 stopped
# 判据翻转（影子）：绿树副本把 s1 的判据**放宽**成「命令行里提到 agent 就算在跑」（= P103 的旧口径）
#   → s5 必须变 alive（绿树的 stopped 断言会红），s6 必须照旧 stopped（影子不是橡皮章）。
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
[ -n "$REPO_ROOT" ] || { printf 'flip-p217: 找不到 git 仓库（本脚本需要 git archive 取 P217 之前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-p217: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

PRE="${TEAM_FLIP_PRE217:-}"
if [ -z "$PRE" ]; then
  # 默认**自己找**「判据被引入的那一次提交」的前一个（`git log -S` 按字符串出现次数变化找提交；
  # 从古到今取最后一个 = 引入者）—— 这样即使 main 已经吃掉 P217（merge-base 只指到合并点），
  # 这个包在复验 worktree 里也照旧能自己找到参照。找不到再退回 merge-base。
  PRE_INTR="$(git -C "$REPO_ROOT" log --format=%H -S 'team_proc_executing_bin' -- \
      skills/teamsmith/scripts/lib/common.sh 2>/dev/null | tail -1)"
  if [ -n "$PRE_INTR" ]; then
    PRE="$PRE_INTR^"
  else
    PRE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
  fi
fi
[ -n "$PRE" ] || { printf 'flip-p217: 解析不到 P217 之前的 revision，用 TEAM_FLIP_PRE217=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p217)" || exit 3
SESS="teamsmith-flip-p217-$$"

# M28/#1250：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— 事故形状）。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "flip-p217" "收尾：私有 session" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$TMP" \
    && tmux kill-session -t "$SESS" 2>/dev/null || true
  tmp_root_reap_all
}
trap cleanup EXIT

# ---- 三棵树：pre（P217 之前） / green（本 worktree） / mut（green + 判据放宽成 P103 的旧口径）--------
mkdir -p "$TMP/pre-skill" "$TMP/fake-bin" "$TMP/repo" "$TMP/mut-skill"
git -C "$REPO_ROOT" archive "$PRE" skills/teamsmith | tar -x -C "$TMP/pre-skill" || exit 2
PRE_SKILL="$TMP/pre-skill/skills/teamsmith"
# 守卫：传进来的 pre 必须真的还是「P217 之前」（否则这个包会报一个假的翻转）
if grep -q 'team_proc_executing_bin' "$PRE_SKILL/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-p217: $PRE（%s）已经包含 P217 的修复（不是修复前的树）——用 TEAM_FLIP_PRE217=<修复前的 sha> 指定\n' "$PRE" >&2
  exit 2
fi
if ! grep -q 'team_proc_executing_bin' "$SKILL_DIR/scripts/lib/common.sh" 2>/dev/null; then
  printf 'flip-p217: 本 worktree 里找不到 team_proc_executing_bin（P217 的修复不在树上）\n' >&2; exit 2
fi
cp -a "$SKILL_DIR/scripts" "$TMP/mut-skill/scripts"
cat >> "$TMP/mut-skill/scripts/lib/common.sh" <<'MUTEOF'

# ---- FLIP P217（只在变异树里）：把判据**放宽**成「命令行里提到 agent 就算在跑」（P103 的旧口径）----
# 影子咬的就是 P217 的那条分界（argv[1] 逐词相等）：放宽之后 `bash --noprofile --norc -s <agent>`
# 必须重新变 alive —— 绿树针对它的 stopped 断言会为此变红。
team_proc_executing_bin() { # <pid> <可执行文件路径或名字> [已读到的 args（可选）]
  local pid="${1:-}" want="${2:-}" preraw="${3:-}" base args tok
  [ -n "$pid" ] && [ -n "$want" ] || return 1
  case "$want" in
    /*) base="$(basename "$want")" ;;
    *)  base="$want" ;;
  esac
  [ -n "$base" ] || return 1
  args="${preraw:-$(ps -o args= -p "$pid" 2>/dev/null | head -1)}"
  [ -n "$args" ] || return 1
  case "$args" in *pm.pid.spawn*|*dispatch-*.spawn*) return 1 ;; esac
  for tok in $args; do
    case "${tok##*/}" in
      "$base") return 0 ;;
    esac
  done
  return 1
}
MUTEOF
MUT_SKILL="$TMP/mut-skill"
if grep -q 'FLIP P217' "$MUT_SKILL/scripts/lib/common.sh"; then :; else
  printf 'flip-p217: 变异树没打上补丁（判据翻转会空跑）\n' >&2; exit 2
fi

# ---- 夹具仓库 + 假 agent ----------------------------------------------------
cat > "$TMP/fake-bin/p217-agent" <<'EOF'
#!/usr/bin/env bash
echo P217-MARK
sleep 600
EOF
chmod +x "$TMP/fake-bin/p217-agent"
AGENT="$TMP/fake-bin/p217-agent"

cd "$TMP/repo" || exit 2
git init -q .; git config user.email t@t; git config user.name t
echo hi > README.md; git add -A; git commit -qm init >/dev/null; git branch -m main
bash "$SKILL_DIR/scripts/team" init --session "$SESS" --yes >/dev/null 2>&1
mkdir -p .pi/team/state docs/team/reports
printf '# P217 夹具任务\n' > "$TMP/task.md"
for _w in p217s1 p217s2 p217s3 p217s4 p217fake p217ctl; do
  printf 'task=T1.1\ntaskfile=%s\nwindow=%s\n' "$TMP/task.md" "$_w" > ".pi/team/state/$_w.env"
done
REPO="$TMP/repo"

# ---- 真 tmux 夹具（三棵树共用，绝不重建）------------------------------------
tmux new-session -d -s "$SESS" -n anchor -c "$REPO" "sleep 100000" 2>/dev/null || exit 2
# 隔离证明：真 tmux 报出来的 socket 就是私有目录里的那个
SOCK="$(tmux list-sessions -F '#{socket_path}' 2>/dev/null | head -1)"
if [ "$SOCK" != "$TMUX_TMPDIR/tmux-$(id -u)/default" ]; then
  printf 'flip-p217: 私有 socket 没生效（报出 %s）——拒绝继续\n' "${SOCK:-?}" >&2; exit 2
fi
# s1 脚本型 agent 直接当 pane 命令（argv[1] 就是它；shebang 让它以 bash 身份跑）
tmux new-window -t "$SESS" -n p217s1 -d -c "$REPO" -- "$AGENT" 2>/dev/null || true
# s2 外面套一层 `bash -lc <agent>`：bash 对 -c 的最后一条命令直接 exec → 进程形状与 s1 逐项相同
tmux new-window -t "$SESS" -n p217s2 -d -c "$REPO" -- bash -lc "$AGENT" 2>/dev/null || true
# s3/s4 让 agent 当**直接子进程**（M37 / 生产 harness 的形状）
tmux new-window -t "$SESS" -n p217s3 -d -c "$REPO" -- bash -lc "$AGENT & wait" 2>/dev/null || true
tmux new-window -t "$SESS" -n p217s4 -d -c "$REPO" -- bash -lc "$AGENT; :" 2>/dev/null || true
# s5 P103 的假活形状：agent 只是 `-s` 的位置参数（argv[1] 是选项），没有任何东西在执行它
tmux new-window -t "$SESS" -n p217fake -d -c "$REPO" -- bash --noprofile --norc -s "$AGENT" 2>/dev/null || true
# s6 对照：命令行里根本没有 agent
tmux new-window -t "$SESS" -n p217ctl -d -c "$REPO" -- bash -c 'sleep 600 && true' 2>/dev/null || true

# 成型（M39：建窗后 pane_pid 先是还没 exec 完的壳，判据要等命令行长成这个形状再问）
p217_pane_args() { # <session:window> → pane_pid 的完整命令行（窗口/进程不在 → 空）
  local p; p="$(tmux list-panes -t "$1" -F '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$p" ] || return 0
  ps -o args= -ww -p "$p" 2>/dev/null | head -1
}
p217_marker() { # <窗口> → 命令行里必须出现的成型标记
  case "$1" in
    p217s1|p217s2) printf 'bash %s\n' "$AGENT" ;;   # s2 的 exec 完成后 argv 与 s1 相同
    p217s3)        printf '%s\n' "$AGENT & wait" ;;
    p217s4)        printf '%s\n' "$AGENT; :" ;;
    p217fake)      printf '%s\n' "-s $AGENT" ;;
    p217ctl)       printf '%s\n' "sleep 600 && true" ;;
  esac
}
p217_wait_shape() { # <窗口> [十分之一秒数] → 0=成型
  local i=0 args
  while [ "$i" -lt 40 ]; do
    args="$(p217_pane_args "$SESS:$1")"
    case "$args" in *"$(p217_marker "$1")"*) return 0 ;; esac
    sleep 0.1; i=$((i + 1))
  done
  return 1
}
for _w in p217s1 p217s2 p217s3 p217s4 p217fake p217ctl; do
  if p217_wait_shape "$_w"; then
    printf '  夹具 %-8s pane_pid=%s 命令行=[%s] 子进程=[%s]\n' "$_w" \
      "$(tmux list-panes -t "$SESS:$_w" -F '#{pane_pid}' 2>/dev/null | head -1)" \
      "$(p217_pane_args "$SESS:$_w")" \
      "$(ps -o args= --ppid "$(tmux list-panes -t "$SESS:$_w" -F '#{pane_pid}' 2>/dev/null | head -1)" 2>/dev/null | tr '\n' ';')"
  else
    printf '  夹具 %-8s ✗ 4s 内没成型（命令行=[%s]）\n' "$_w" "$(p217_pane_args "$SESS:$_w")"
  fi
done

# ---- 探针：库函数层（team_agent_live）与 CLI 层（resume --dry-run），只换树 -------------
p217_live() { # <skill-dir> <agent-window> → alive|stopped
  local dir="$1" agent="$2"
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      TEAM_SESSION="$SESS" TEAM_PI_BIN="$AGENT" TEAM_AGENTS="p217s1 p217s2 p217s3 p217s4 p217fake p217ctl" \
      bash -c '. "'"$dir"'/scripts/lib/common.sh"
               for _f in "'"$dir"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
               team_load_config >/dev/null 2>&1
               if team_agent_live "$1"; then printf "alive\n"; else printf "stopped\n"; fi' _ "$agent" )
}
p217_resume() { # <skill-dir> → resume --dry-run 的输出（同一夹具、同一入口）
  local dir="$1"
  ( cd "$REPO" && env TEAM_AGENTS="p217s1 p217s2 p217s3 p217s4 p217fake p217ctl" TEAM_PI_BIN="$AGENT" \
      TEAM_SESSION="$SESS" bash "$dir/scripts/team" resume --dry-run 2>&1 || true )
}

printf '\nP217 之前的 revision: %s（%s）\n修复后 skill:  %s\n变异树:        %s（判据放宽成「命令行里提到 agent 就算在跑」）\n' \
  "$PRE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$PRE")" "$SKILL_DIR" "$MUT_SKILL"

printf '\n同一夹具、三种树的判定（入口 team_agent_live）：\n'
printf '  %-24s %-12s %-14s %-14s %-22s\n' "形状" "窗口" "pre(无 P217)" "green(P217)" "mut(放宽成「提到」)"
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
declare -A V
p217_label() { case "$1" in
  p217s1) printf '① pane 命令就是 agent' ;;
  p217s2) printf '② 外层 bash -lc <agent>' ;;
  p217s3) printf '③ <agent> & wait（子进程）' ;;
  p217s4) printf '④ 生产 harness 形状' ;;
  p217fake) printf '⑤ P103 假活（-s <agent>）' ;;
  p217ctl) printf '⑥ 对照（无 agent）' ;;
esac; }
for _w in p217s1 p217s2 p217s3 p217s4 p217fake p217ctl; do
  V["pre_$_w"]="$(p217_live "$PRE_SKILL" "$_w")"
  V["green_$_w"]="$(p217_live "$SKILL_DIR" "$_w")"
  V["mut_$_w"]="$(p217_live "$MUT_SKILL" "$_w")"
  printf '  %-24s %-12s %-14s %-14s %-22s\n' "$(p217_label "$_w")" "$_w" \
    "${V[pre_$_w]}" "${V[green_$_w]}" "${V[mut_$_w]}"
done

printf '\nCLI 层（team resume --dry-run，同一夹具）：\n'
PRE_RESUME="$(p217_resume "$PRE_SKILL")"
GREEN_RESUME="$(p217_resume "$SKILL_DIR")"
printf '  pre  ：%s\n' "$(printf '%s' "$PRE_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')"
printf '  green：%s\n' "$(printf '%s' "$GREEN_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')"

printf '\n== 翻转断言 ==\n'
# ① 红侧：P217 之前的假阴性 —— `bash <agent>`（argv[1] 就是它）被判停
if [ "${V[pre_p217s1]}" = "stopped" ]; then
  ok "修复前：pane 命令就是 agent 自己（bash <agent>，argv[1] 就是它、没有 agent 子进程）判 stopped —— 假阴性复现（P214 的 §41 两条红）"
else
  bad "修复前：pane 命令就是 agent 自己（bash <agent>）竟然判 ${V[pre_p217s1]}（没有复现出假阴性，夹具或基线不对）"
fi
# ① 绿侧：四种形状各一条断言 —— 脚本型 agent 被直接当 pane 命令起，也是「在跑」
if [ "${V[green_p217s1]}" = "alive" ]; then ok "修复后：① bash <agent>（argv[1] 就是它）判 alive"
else bad "修复后：① bash <agent> 仍判 ${V[green_p217s1]}（修复没生效）"; fi
if [ "${V[green_p217s2]}" = "alive" ]; then ok "修复后：② 外层 bash -lc <agent>（exec 后同形）判 alive"
else bad "修复后：② 外层 bash -lc <agent> 判 ${V[green_p217s2]}（与 ① 形状相同，不该分叉）"; fi
if [ "${V[green_p217s3]}" = "alive" ]; then ok "修复后：③ bash -lc 的 '<agent> & wait'（agent 是直接子进程）判 alive"
else bad "修复后：③ 的席位被判 ${V[green_p217s3]}（M37 的承诺被放倒了）"; fi
if [ "${V[green_p217s4]}" = "alive" ]; then ok "修复后：④ 生产 harness 形状（bash -lc 的 '<agent>; :'）判 alive"
else bad "修复后：④ 生产 harness 形状被判 ${V[green_p217s4]}（生产席位的读数会错）"; fi
# ④ 绿侧：假活形状必须照旧判停（P103 的洞不许放回来）
if [ "${V[green_p217fake]}" = "stopped" ]; then ok "修复后：⑤ P103 的假活形状（bash -s <agent>，argv[1] 是选项）照旧判 stopped —— 洞仍然堵着"
else bad "修复后：⑤ 假活形状判 ${V[green_p217fake]}（P103 的洞被 P217 放回来了）"; fi
if [ "${V[green_p217ctl]}" = "stopped" ] && [ "${V[pre_p217ctl]}" = "stopped" ]; then
  ok "对照 ⑥：命令行里没有 agent → 两棵树都判 stopped"
else bad "对照 ⑥ 不成立：pre=${V[pre_p217ctl]} green=${V[green_p217ctl]}"; fi
# ② 改 P217 之前的形状在生产形状上的读数不许变（修的是假阴性，不是放宽整套判据）
if [ "${V[pre_p217s3]}" = "alive" ] && [ "${V[pre_p217s4]}" = "alive" ]; then
  ok "修复前：③④（agent 是子进程）本来就是 alive —— 修的是 ①② 的假阴性，没有动它们"
else bad "修复前：③④ 的读数与 M37/生产口径不符（pre=${V[pre_p217s3]}/${V[pre_p217s4]}）"; fi
# CLI 层：修复前 resume **列出**该席位（判停 = 可续跑），而下一步的 respawn 会杀掉在跑的 agent
if printf '%s' "$PRE_RESUME" | grep -q "p217s1 可续跑"; then
  ok "修复前 CLI：resume --dry-run 把 ① 的席位列成可续跑（判停的下一个动作就是 respawn —— 假阴性会杀掉在跑的 agent）"
else
  bad "修复前 CLI：resume 没把 ① 的席位列成可续跑（现场：$(printf '%s' "$PRE_RESUME" | grep -E '可续跑|没有需要续跑' | tr '\n' ' ')）"
fi
if printf '%s' "$GREEN_RESUME" | grep -q "p217s1 可续跑"; then
  bad "修复后 CLI：resume 仍把 ① 的席位列成可续跑（判活的证据没有传到 CLI 层）"
else
  ok "修复后 CLI：resume --dry-run **不列** ① 的席位（判活 = 不会被 respawn；cli：$(printf '%s' "$GREEN_RESUME" | grep -cE '可续跑' ) 条可续跑）"
fi
# ③ 判据翻转（影子）：把判据放宽成 P103 的旧口径 → ⑤ 必须变 alive，⑥ 必须照旧 stopped
if [ "${V[mut_p217fake]}" = "alive" ]; then
  ok "判据翻转：变异树（放宽成「命令行里提到 agent 就算在跑」）把 ⑤ 判回 alive —— 绿树咬的就是 argv[1] 这条分界"
else
  bad "判据翻转没红：变异树对 ⑤ 判 ${V[mut_p217fake]}（影子没盖住判据）"
fi
if [ "${V[mut_p217ctl]}" = "stopped" ]; then
  ok "判据翻转不是橡皮章：变异树对 ⑥（命令行里没有 agent）照旧判 stopped"
else
  bad "判据翻转的对照不成立：变异树对 ⑥ 判 ${V[mut_p217ctl]}"
fi
if [ "${V[mut_p217s1]}" = "alive" ]; then
  ok "判据翻转：变异树对 ① 也是 alive（放宽不影响这一条）"
else
  bad "判据翻转的现场不对：变异树对 ① 判 ${V[mut_p217s1]}"
fi

printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-p217：翻转已复现（①② 假阴性红 → 绿；判据放宽即 ⑤ 红）\033[0m\n'; exit 0; }
printf '\033[31mflip-p217：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
