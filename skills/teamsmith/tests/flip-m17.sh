#!/usr/bin/env bash
# M17 · 独立翻转包：放弃 Enter 时的「收回」红 → 绿 → 变异红
#
#   bash skills/teamsmith/tests/flip-m17.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m17.sh
#
# 为什么需要：M17 的判据是**用户实测的形状**——守卫放弃按 Enter 时，打进去的字不许留在人的
# 输入框里（2026-09-17 实测：一条 [auto] 消息躺在 PM 的框里，用户自己按了 Enter 才发出去）。
# 这条判据在 smoke §12b-h ⑰ 里只对**绿树**成立，回答不了两个问题：「旧树是不是真的会留字」
# 与「守门断言是不是不管实现怎样都报绿」。本包用**同一份真 pane 夹具**（fake-tui.py 的
# 折叠中途停顿 2500ms）对三棵树各跑一遍同一条路径：
#
#   红（分叉点：旧 skill + 旧夹具）——第一拍放弃 Enter 后框里立着半成品，渲染补齐后变成
#        `[paste #1 +K lines]`：**字留在框里**（用户的形状）→ 判据红；
#   绿（本 worktree）——同一路径先收回再 held：框里无残留、零提交、reason=draft-raced-retracted
#        → 判据绿；
#   变异（绿树副本里把 team_box_retract_safe 改成永远返回 1）——收回不发生，框里仍然有字
#        → 同一判据必须红（证明它不是空转扫描）。
#
# 隔离（两条硬纪律）：
#   1) tmux 全部走**私有 socket**：PATH 里放一个 `tmux` shim（exec /usr/bin/tmux -L <本轮 socket>），
#      夹具窗口与生产代码用的是同一个 shim —— 不碰调用者所在的任何 tmux server/session；
#   2) 身份（M7.2 教训）：清掉继承的 TEAM_*，写盘前先断言 `team paths` 的 main_root 就是夹具仓库。
# 只写 /tmp 下的临时目录；退出时收掉本轮 socket 与临时目录。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m17: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m17: 需要 tmux（夹具是一条真 pane 路径）\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-m17: 需要 python3（假 TUI 夹具）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || { printf 'flip-m17: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m17.XXXXXX)"
SOCK="flip-m17-$$"
cleanup() { tmux -L "$SOCK" kill-server 2>/dev/null || true; rm -rf "$TMP"; }
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
if grep -qF 'team_tmux_retract' "$RED_SKILL/scripts/lib/outbox.sh" 2>/dev/null; then
  printf 'flip-m17: $BASE 已经包含 M17 的收回实现（outbox.sh 里已有 team_tmux_retract）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
grep -qF 'team_tmux_retract' "$GREEN_SKILL/scripts/lib/outbox.sh" \
  || { printf 'flip-m17: 绿树（本 worktree）里没有 M17 的收回实现 —— 这个包没什么可翻的\n' >&2; exit 2; }

MUT="$TMP/mut"
cp -r "$GREEN_SKILL" "$MUT"
cat >> "$MUT/scripts/lib/outbox.sh" <<'MUTEOF'

# mutation（flip-m17 专用）：收回永远不成立 —— 用来证明「框里无残留」这条判据确实在守实现。
team_box_retract_safe() { return 1; }
MUTEOF

# ---- 身份隔离 ---------------------------------------------------------------
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION \
      TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES \
      TEAM_VCS TEAM_CONFIG_FILE TEAM_SKILL_DIR 2>/dev/null || true

FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

# ---- 一条路径：折叠占位符停顿 2500ms（> 有界等待 ≈1.6s）→ 放弃 Enter ---------
run_case() { # <skill-dir> <tag>
  local skill="$1" tag="$2"
  local repo="$TMP/$tag-repo" ses="flip17-${tag}-$$" submit="$TMP/$tag-submits.log"
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
    printf 'flip-m17: 身份隔离失败（team paths 的 main_root 不是夹具仓库 %s）\n' "$repo" >&2
    cat "$TMP/$tag-paths.json" >&2
    return 1
  fi
  printf 'line-%s\n' $(seq -w 1 14) > "$TMP/big-$tag.txt"
  tmux -L "$SOCK" new-session -d -s "$ses" -x 120 -y 30 -c "$repo"
  tmux -L "$SOCK" new-window -d -t "$ses" -n race \
    "env FAKE_TUI_COLS=100 FAKE_TUI_SUBMIT_LOG='$submit' FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=2500 python3 '$skill/tests/fake-tui.py'"
  sleep 1
  ( cd "$repo" && env PATH="$TMP/bin:$PATH" bash "$skill/scripts/team" draft send "$TMP/big-$tag.txt" --target "$ses:race" ) \
    > "$TMP/$tag-drain.log" 2>&1 || true
  sleep 3   # 夹具的补全计划跑完（红/变异树会看到框里「长回」完整占位符）
  tmux -L "$SOCK" capture-pane -p -t "$ses:race" > "$TMP/$tag-box.log" 2>/dev/null || true
  ( cd "$repo" && env PATH="$TMP/bin:$PATH" bash "$skill/scripts/team" outbox flush ) \
    > "$TMP/$tag-flush.log" 2>&1 || true
  tmux -L "$SOCK" capture-pane -p -t "$ses:race" > "$TMP/$tag-box2.log" 2>/dev/null || true
  tmux -L "$SOCK" kill-session -t "$ses" 2>/dev/null || true
  cp "$repo/.pi/team/state/outbox/HOLDING.log" "$TMP/$tag-holding.log" 2>/dev/null || : > "$TMP/$tag-holding.log"
  return 0
}

residue_in() { grep -qE '\[paste #|line-0[0-9]' "$1" 2>/dev/null; }
submits_of() { grep -c '^SUBMIT:' "$1" 2>/dev/null || true; }
reason_of()  { sed -n 's/.*reason=\([^ ]*\).*/\1/p' "$1" 2>/dev/null | tail -1; }
box_tail()   { grep -nE '\[paste #|line-0[0-9]' "$1" 2>/dev/null | head -3 | sed 's/^/      /'; }

# 判据（与 smoke §12b-h ⑰ 同义、独立实现，不复用它的夹具与断言）：
#   放弃 Enter 的那一刻：框里没有我们的残留 + 零提交 + held 原因 = draft-raced-retracted。
# （看 box.log = 排水刚返回、夹具补全计划跑完之后的捕获，**flush 之前**——红树的 flush 会走旧
#   resume 路径按 Enter，把 frame 变成对话回显，用它判会混入「提交后的气泡」而不是框里的残留。）
retracted_ok() { # <tag> → 0 = 收回成立
  local tag="$1"
  residue_in "$TMP/$tag-box.log" && return 1
  [ "$(submits_of "$TMP/$tag-submits.log")" = "0" ] || return 1
  [ "$(reason_of "$TMP/$tag-holding.log")" = "draft-raced-retracted" ] || return 1
  return 0
}

report() { # <tag>：把证据打出来
  local tag="$1"
  printf '      reason=%s  submits=%s\n' "$(reason_of "$TMP/$tag-holding.log")" "$(submits_of "$TMP/$tag-submits.log")"
  printf '      flush 之前的框（残留行）：\n'; box_tail "$TMP/$tag-box.log"
  printf '      flush 之后的框（残留行）：\n'; box_tail "$TMP/$tag-box2.log"
}

printf 'flip-m17 · 红树=%s 绿树=%s（真 pane 夹具：折叠停顿 2500ms 后放弃 Enter）\n' "$BASE" "$GREEN_SKILL"

# ---- 红：修复前 --------------------------------------------------------------
if run_case "$RED_SKILL" red; then
  if retracted_ok red; then
    bad "修复前竟然已经收回（这不是修复前的树：检查 TEAM_FLIP_BASE）"
  else
    ok "红（修复前）：放弃 Enter 后字还留在框里（判据会红）"
  fi
  printf '      红树现场：\n'; report red
  residue_in "$TMP/red-box.log" && ok "红树确实是用户实测的形状：flush 之前框里立着我们的 payload/占位符" \
    || bad "红树框里居然没有残留 —— 夹具不对，翻转没有意义"
else
  bad "红树夹具没跑起来（跳过判据）"
fi

# ---- 绿：本树 -----------------------------------------------------------------
if run_case "$GREEN_SKILL" green; then
  if retracted_ok green; then
    ok "绿（本树）：放弃 Enter 后已收回 —— 框里无残留、零提交、reason=draft-raced-retracted"
  else
    bad "绿树没有收回（见 $TMP/green-box2.log / HOLDING.log）"
  fi
  printf '      绿树现场：\n'; report green
  # 绿树还要证明终态：之后的 flush 也不能重贴（红树正是在这里又投了一次）
  if [ "$(submits_of "$TMP/green-submits.log")" = "0" ] && ! residue_in "$TMP/green-box2.log"; then
    ok "绿树：flush 之后仍然零提交、框里仍然没有残留（终态）"
  else
    bad "绿树：flush 之后重贴了或框里长出了字（见 $TMP/green-box2.log）"
  fi
else
  bad "绿树夹具没跑起来"
fi

# ---- 变异：绿树副本里禁止收回 → 判据必须红 -----------------------------------
if run_case "$MUT" mut; then
  if retracted_ok mut; then
    bad "变异树（不收回）竟然还是绿 —— 判据是空的，没有在守实现"
  else
    ok "变异：去掉收回后同一判据变红（守门断言可被证伪）"
  fi
  printf '      变异树现场：\n'; report mut
  [ "$(reason_of "$TMP/mut-holding.log")" = "draft-raced-left" ] \
    && ok "变异树走了「留在框里」分支（reason=draft-raced-left）—— 正是没收该走的路" \
    || bad "变异树的原因不是 draft-raced-left（判据红的原因要能说清楚）"
else
  bad "变异树夹具没跑起来"
fi

printf '\n== 结果 == %s\n' "$([ "$FAIL" -eq 0 ] && echo 'flip 全绿（红→绿→变异红）' || echo "flip 有 $FAIL 项失败")"
[ "$FAIL" -eq 0 ] || exit 1
