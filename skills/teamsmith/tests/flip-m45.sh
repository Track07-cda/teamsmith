#!/usr/bin/env bash
# M45 · 独立翻转包：pi 的更新横幅把**空闲输入框**读成 BUSY —— 红（修前）→ 绿（本树）→ 变异红#
#   bash skills/teamsmith/tests/flip-m45.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m45.sh
#
# 为什么需要：M45 的现场是「pi 0.86.0 发布后，main 上 M28 段连续两次红」——空闲框被判 BUSY，
# 投递守卫把「空闲」读成「有草稿」→ 通知排队（M17/M24/M30 一路在治的病的同一族）。
# smoke 12b-h0b 只对**绿树**成立，回答不了两个问题：「修前的树是不是真会读成 BUSY」与
# 「守门断言是不是不管实现怎样都报绿」。本包对三棵树各跑同一份证据：
#
#   红（分叉点 skills/teamsmith）：真帧（tests/frames/ 由**本树**提供，判据用**修前**的实现）
#        → 几何落在横幅上界（geometry=[11 29]）、空框读出横幅文字；真 pane 上带横幅时
#        投递被判 BUSY → `queued for …`、零提交（消息进队列而不是框里）。
#   绿（本 worktree）：同一帧 geometry=[24 29]、空框读空；真 pane 上同一发投递
#        → `已确认送达`、恰好一次提交。
#   变异（绿树副本里把 _team_box_banner_rows 改成空实现）：回到红 —— 证明这条判据确实在守实现。
#
# 隔离（与 flip-m17 同一套硬纪律）：
#   1) tmux 全部走**私有 socket**：PATH 里放一个 `tmux` shim（exec /usr/bin/tmux -L <本轮 socket>），
#      夹具窗口与生产代码用的是同一个 shim —— 不碰调用者所在的任何 tmux server/session；
#   2) 身份（M7.2 教训）：清掉继承的 TEAM_*，写盘前先断言 `team paths` 的 main_root 就是夹具仓库。
# 只写 /tmp 下的临时目录；退出时收掉本轮 socket 与临时目录。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$SELF_DIR/lib/tmux-iso.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m45: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m45: 需要 tmux（真 pane 那条路径）\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-m45: 需要 python3（假 TUI 夹具）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || { printf 'flip-m45: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-m45)" || exit 3
SOCK="flip-m45-$$"
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "flip-m45" "收尾：私有 server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$SOCK" \
    && tmux -L "$SOCK" kill-server 2>/dev/null || true
  tmp_root_reap_all
}
trap cleanup EXIT

# ---- tmux 私有 socket shim（夹具窗口与生产代码共用） -------------------------
mkdir -p "$TMP/bin"
cat > "$TMP/bin/tmux" <<EOF
#!/usr/bin/env bash
exec /usr/bin/tmux -L "$SOCK" "\$@"
EOF
chmod +x "$TMP/bin/tmux"

# ---- 三棵树 -----------------------------------------------------------------
mkdir -p "$TMP/red"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_SKILL="$TMP/red/skills/teamsmith"
GREEN_SKILL="$SKILL_DIR"
# 守卫：base 必须真的还是「修复前」，否则这个包会报出一个假的翻转
if grep -qF '_team_box_banner_rows' "$RED_SKILL/scripts/lib/outbox.sh" 2>/dev/null; then
  printf 'flip-m45: $BASE 已经包含 M45 的横幅识别（outbox.sh 里已有 _team_box_banner_rows）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
grep -qF '_team_box_banner_rows' "$GREEN_SKILL/scripts/lib/outbox.sh" \
  || { printf 'flip-m45: 绿树（本 worktree）里没有 M45 的横幅识别 —— 这个包没什么可翻的\n' >&2; exit 2; }

MUT="$TMP/mut"
cp -r "$GREEN_SKILL" "$MUT"
cat >> "$MUT/scripts/lib/outbox.sh" <<'MUTEOF'

# mutation（flip-m45 专用）：横幅识别关掉 —— 用来证明「空闲框读成 EMPTY」这条判据确实在守实现。
_team_box_banner_rows() { return 0; }
MUTEOF

# ---- 帧探针（本包自带，不复用 smoke 的夹具） --------------------------------
FRAME="$GREEN_SKILL/tests/frames/pi-0.85.1-update-banner.txt"   # 真帧（真 pi 0.85.1 实拍）
FRAME_CY=26                                                     # 实拍时的光标行（1-based）
[ -f "$FRAME" ] || { printf 'flip-m45: 缺真帧 %s\n' "$FRAME" >&2; exit 2; }
cat > "$TMP/frame-probe.sh" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <帧文件> <cy> → geometry / 框文本
# 只依赖被测树里的一个东西：_team_box_geometry（M45 改的就是它）。行提取**故意**由本探针自己做
# （一律跳过边框邻行 = P67 之前的老槽位排除，再跳过空行、去空白），这样修前/修后两棵树的输出
# 能逐字对得上 —— 这是 P67「框内容提取只有一份实现」的**唯一文档化例外**：本探针是翻转夹具，
# 不是判定证据（判定的绿侧在 smoke 12b-h0b 与 P67 段，都走生产实现）。
set -u
SKILL_DIR="$1"; FR="$2"; CY="$3"
. "$SKILL_DIR/scripts/lib/common.sh"; . "$SKILL_DIR/scripts/lib/outbox.sh" 2>/dev/null || exit 3
geo="$(_team_box_geometry "$CY" < "$FR")"
printf 'geometry=[%s]\n' "$geo"
if [ -n "$geo" ]; then
  printf 'box_nows=[%s]\n' "$(awk -v t="${geo%% *}" -v b="${geo##* }" '
    NR>t && NR<b { s=$0; sub(/[ \t]+$/, "", s); if (b-NR == 1 || s == "") next; printf "%s", s }' "$FR" | tr -d '[:space:]')"
else
  printf 'box_nows=[<no-box>]\n'
fi
EOS
chmod +x "$TMP/frame-probe.sh"
# 对抗帧（草稿自己长得像横幅块）：修后必须仍然读成框内容，绝不退化成「框读不出来」
ADVERSARIAL="$TMP/adversarial.txt"
{ printf '─%.0s' $(seq 1 40); printf '\n'; printf '─%.0s' $(seq 1 40); printf '\n'
  printf ' Update Available\n'; printf ' New version 1.0.0 is available. Run pi update\n'
  printf ' Changelog: https://x\n'; printf '─%.0s' $(seq 1 40); printf '\n'
  printf ' fake-pi  Fake Pi  max\n'; printf '─%.0s' $(seq 1 40); printf '\n'; printf ' footer\n'; } > "$ADVERSARIAL"

# ---- 身份隔离 ---------------------------------------------------------------
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION \
      TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES \
      TEAM_VCS TEAM_CONFIG_FILE TEAM_SKILL_DIR 2>/dev/null || true

FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# ---- ① 纯帧：修前读成 BUSY，修后读成空 --------------------------------------
frame_case() { # <skill-dir> <tag>
  local skill="$1" tag="$2"
  ( cd "$TMP" && env TEAM_ROOT= bash "$TMP/frame-probe.sh" "$skill" "$FRAME" "$FRAME_CY" ) \
    > "$TMP/$tag-frame.log" 2>&1 || true
  printf '      %s：%s\n' "$tag" "$(tr '\n' ' ' < "$TMP/$tag-frame.log")"
}
# ①a 红：修前的实现 + 本树的真帧 → 框被算大、空框读出横幅文字
frame_case "$RED_SKILL" red
grep -q 'geometry=\[11 29\]' "$TMP/red-frame.log" \
  && ok "红（修前实现）：几何落在横幅上界（geometry=[11 29]）—— 帧是真的、判据是旧的" \
  || bad "红（修前实现）没有出现「框被算大」的形状（见上面 red）"
grep -q 'UpdateAvailable' "$TMP/red-frame.log" \
  && ok "红（修前实现）：空闲空框读出了横幅文字（真实现场 = BUSY）" \
  || bad "红（修前实现）竟然没把横幅读成框内容（夹具不对，翻转没有意义）"
# ①b 绿：本树
frame_case "$GREEN_SKILL" green
grep -q 'geometry=\[24 29\]' "$TMP/green-frame.log" \
  && ok "绿（本树）：几何落在真正的输入框上（geometry=[24 29]）" \
  || bad "绿树几何不是 [24 29]（见上面 green）"
grep -q 'box_nows=\[\]' "$TMP/green-frame.log" \
  && ok "绿（本树）：同一帧的空闲空框读成空（横幅不是框内容）" \
  || bad "绿树仍把横幅读成框内容"
# ①c 变异：绿树副本 + 横幅识别清空 → 必须回到红
frame_case "$MUT" mut
grep -q 'geometry=\[11 29\]' "$TMP/mut-frame.log" && grep -q 'UpdateAvailable' "$TMP/mut-frame.log" \
  && ok "变异（横幅识别清空）：同一帧回到红 —— 守门判据不是空转扫描" \
  || bad "变异树竟然还是绿 —— 这条判据没有在守实现（见上面 mut）"
# ①d 绿树的对抗帧：草稿自己像横幅块时仍然读成内容（不粘连）
( cd "$TMP" && bash "$TMP/frame-probe.sh" "$GREEN_SKILL" "$ADVERSARIAL" 4 ) > "$TMP/green-adversarial.log" 2>&1 || true
{ grep -q 'geometry=\[1 8\]' "$TMP/green-adversarial.log" && grep -q 'UpdateAvailable' "$TMP/green-adversarial.log"; } \
  && ok "绿（本树）：草稿自己长得像横幅块 → 仍然读成框内容（BUSY；不粘连、不退化成 NONE）" \
  || bad "绿树在对抗帧上失手（把用户草稿吞成空？见上面 green-adversarial）"

# ---- ② 真 pane：带横幅的空闲框上投一发 --------------------------------------
run_e2e() { # <skill-dir> <tag>
  local skill="$1" tag="$2"
  local repo="$TMP/$tag-repo" ses="m45flip-$tag-$$" submit="$TMP/$tag-submits.log"
  mkdir -p "$repo"; : > "$submit"
  (
    cd "$repo" || exit 1
    git init -q -b main .
    git config user.email flip@teamsmith
    git config user.name flip
    echo init > README.md
    git add -A && git commit -qm init
    bash "$skill/scripts/team" init --session "$ses" --agents dev --vcs local --gates true --docs docs/team >/dev/null 2>&1
    bash "$skill/scripts/team" paths > "$TMP/$tag-paths.json" 2>&1 || true
  )
  if ! grep -qF "\"main_root\": \"$repo\"" "$TMP/$tag-paths.json" 2>/dev/null; then
    printf 'flip-m45: 身份隔离失败（team paths 的 main_root 不是夹具仓库 %s）\n' "$repo" >&2
    cat "$TMP/$tag-paths.json" >&2
    return 1
  fi
  printf 'flip banner case\n第二行 payload\n' > "$TMP/$tag-msg.txt"
  tmux -L "$SOCK" new-session -d -s "$ses" -x 120 -y 30 -c "$repo"
  # 夹具窗口一律用**本树**的 fake-tui.py（横幅按真实现场帧画）—— 实现是变量，夹具是常量
  tmux -L "$SOCK" new-window -d -t "$ses" -n pane \
    "env FAKE_TUI_COLS=120 FAKE_TUI_BANNER=both FAKE_TUI_SUBMIT_LOG='$submit' python3 '$GREEN_SKILL/tests/fake-tui.py'"
  sleep 1.5
  tmux -L "$SOCK" capture-pane -p -t "$ses:pane" > "$TMP/$tag-frame.log" 2>/dev/null || true
  ( cd "$repo" && env PATH="$TMP/bin:$PATH" bash "$skill/scripts/team" draft send "$TMP/$tag-msg.txt" --target "$ses:pane" ) \
    > "$TMP/$tag-send.log" 2>&1 || true
  sleep 0.5
  tmux -L "$SOCK" display-message -p -t "$ses:pane" '#{cursor_y}' > "$TMP/$tag-cy.txt" 2>/dev/null || true
  tmux -L "$SOCK" capture-pane -p -t "$ses:pane" > "$TMP/$tag-after.log" 2>/dev/null || true
  tmux -L "$SOCK" kill-session -t "$ses" 2>/dev/null || true
  return 0
}
submits_of() { grep -c '^SUBMIT:' "$1" 2>/dev/null || true; }
# 投递之后，框里还剩什么？（用该树的实现读那一帧；cy 是投递后从 pane 取的）
box_after_of() { # <skill-dir> <tag> → box_nows=[…]
  local skill="$1" tag="$2" cy
  cy="$(cat "$TMP/$tag-cy.txt" 2>/dev/null || printf '')"
  case "$cy" in ''|*[!0-9]*) printf 'box_nows=[<no-cursor>]\n'; return 0 ;; esac
  ( cd "$TMP" && bash "$TMP/frame-probe.sh" "$skill" "$TMP/$tag-after.log" "$((cy + 1))" 2>/dev/null | sed -n 's/^box_nows=/box_nows=/p' )
}

for tree in red green mut; do
  case "$tree" in
    red)   e2e_skill="$RED_SKILL" ;;
    green) e2e_skill="$GREEN_SKILL" ;;
    mut)   e2e_skill="$MUT" ;;
  esac
  if ! run_e2e "$e2e_skill" "$tree"; then
    bad "$tree：端到端夹具没跑起来"
    continue
  fi
  # 夹具有效性：这一帧里真有横幅（否则这个用例是空转）
  banner_seen=0
  grep -q 'Update Available' "$TMP/$tree-frame.log" 2>/dev/null && banner_seen=1
  printf '      %s：send=%s submits=%s banner=%s\n' "$tree" \
    "$(sed -n 's/.*\(queued for .*\|draft：已确认送达.*\|draft：输入框形状未知.*\)/\1/p' "$TMP/$tree-send.log" | head -1)" \
    "$(submits_of "$TMP/$tree-submits.log")" "$banner_seen"
  case "$tree" in
    red|mut)
      if [ "$banner_seen" = "1" ] && grep -q 'queued for' "$TMP/$tree-send.log" && [ "$(submits_of "$TMP/$tree-submits.log")" = "0" ]; then
        ok "$tree（真 pane + 横幅）：空闲框被判 BUSY → 消息排队、零提交（修前的真实行为）"
      else
        bad "$tree 端到端没有出现「排队 + 零提交」（夹具有效？见上面 $tree）"
      fi ;;
    green)
      if [ "$banner_seen" = "1" ] && grep -q '已确认送达' "$TMP/$tree-send.log" && [ "$(submits_of "$TMP/$tree-submits.log")" = "1" ]; then
        ok "绿（真 pane + 横幅）：空闲框照样投出去（确认送达 + 恰好一次提交）"
      else
        bad "绿树端到端没投出去（见上面 green）"
      fi
      grep -q 'flip banner case' "$TMP/$tree-submits.log" \
        && ok "绿：提交的正文就是 payload 本身" \
        || bad "绿：提交内容不是 payload（见 $TMP/green-submits.log）"
      # 终态：投递之后框里不该留下任何东西（用本树的实现读投递后那一帧；
      # 不能在整屏上找 payload —— 假 TUI 会把已提交的消息回显到对话区）
      M45_BOX_AFTER="$(box_after_of "$GREEN_SKILL" "$tree")"
      case "$M45_BOX_AFTER" in
        *'box_nows=[]'*) ok "绿：投递后框里没有残留（$M45_BOX_AFTER）" ;;
        *) bad "绿：投递后框里仍有内容（$M45_BOX_AFTER）" ;;
      esac ;;
  esac
done

printf '\n== 结果 == %s\n' "$([ "$FAIL" -eq 0 ] && echo 'flip 全绿（红→绿→变异红）' || echo "flip 有 $FAIL 项失败")"
[ "$FAIL" -eq 0 ] || exit 1
