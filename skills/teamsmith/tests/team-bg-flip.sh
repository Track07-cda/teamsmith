#!/usr/bin/env bash
# M27 · team-bg 后台车道的翻转复现（红 → 绿）
#
#   bash skills/teamsmith/tests/team-bg-flip.sh [--keep]
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/team-bg-flip.sh      # 默认 merge-base HEAD main
#
# 红（两种，都要有）：
#   ① 修复前的树（BASE = merge-base HEAD main）按它自己缺什么形状来判：
#      · 没有 team-bg.ts          → 车道根本不存在，夹具必须报 import 失败；
#      · 有 M30 之前的老版（--git-common-dir）→ S11（worktree 会话的产物写进共享根）红；
#      · 有 M30 但缺 P33（结果里没有 `cmd:` 行）→ S12 的显示用例红；
#      · BASE 已经含 P33（没有修复前可对照）→ 可见跳过，并提示用 TEAM_FLIP_BASE 指到修复前的 revision。
#   ② 定点破坏（每个只改一行）：收割静默 / 合并窗口 / 唤醒投递方式 / 账本格式 / 日志上限 / 根解析 /
#      P33 显示（cmd 行 / 单行化 / 码点切 / 收割回执）—— 每个都必须让夹具里**对应用例**变红。
#      破坏没生效（sed 没匹配上）= 假红，直接判失败。
# 绿：当前树的真扩展跑同一套夹具，全绿（TEAM-BG-HARNESS OK）。
#
# 只写 /tmp 下的临时目录；不碰调用者所在的仓库/session/tmux（夹具自己清空 TEAM_* 身份并断言
# 产物落在临时仓库里，另有一条反向守卫对比真实仓库 state/ 的前后快照）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
SKILL_EXT="$SKILL_DIR/extension/team-bg.ts"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'team-bg-flip: 找不到 git 仓库（需要它取修复前的树）\n' >&2; exit 2; }

# 能直接跑 .ts 的运行时（与 smoke 的选择顺序一致；没有就响亮退出，不静默跳过）
RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  RUNNER="$HOME/.bun/bin/bun"
elif command -v tsx >/dev/null 2>&1; then
  RUNNER="tsx"
fi
[ -n "$RUNNER" ] || { printf 'team-bg-flip: 没有能跑 .ts 的运行时（node 开启类型剥离 / bun / tsx）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'team-bg-flip: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1
TMP="$(mktemp -d /tmp/teamsmith-flip-m27.XXXXXX)"
cleanup() { [ "$KEEP" = "1" ] || rm -rf "$TMP"; }
trap cleanup EXIT

FAIL=0
RED1=ran          # ran / skipped：红①是否真的跑出对照（BASE 已含修复时可见跳过）
MUTATIONS=0       # 实际执行过的定点破坏条数（红②的自我描述不再手写数字）
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr() { printf '\n== %s ==\n' "$1"; }

HARNESS="$SKILL_DIR/tests/team-bg-harness.mjs"
[ -f "$HARNESS" ] || { printf 'team-bg-flip: 缺夹具 %s\n' "$HARNESS" >&2; exit 2; }
run_harness() { # <ext.ts> <tag> → 0/1（stdout 落 $TMP/<tag>.log）
  local ext="$1" tag="$2"
  $RUNNER "$HARNESS" "$ext" >"$TMP/$tag.log" 2>&1
}

printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n运行时: %s\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR" "$RUNNER"

# ── ① 修复前的树：按 BASE 缺什么形状判红 ───────────────────────────────────────
hdr "红①：修复前的树里的 team-bg（M30 之前 / P33 之前 / 根本没有这个扩展）"
mkdir -p "$TMP/red/ext"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith/extension 2>/dev/null | tar -x -C "$TMP/red"
RED_EXT="$TMP/red/skills/teamsmith/extension/team-bg.ts"
if [ -f "$RED_EXT" ] && grep -qF 'displayCmd(' "$RED_EXT"; then
  # merge-base 已经落在修复之后的树上（例如 main 已合 P33、分支从那里切）：没有「修复前」可对照。
  # 不静默放水：点名说明，并提醒用 TEAM_FLIP_BASE 指到修复前的 revision；守卫仍由红②的定点破坏承担。
  RED1=skipped
  printf '  (跳过红①：%s 已经含 P33 的 displayCmd —— 没有修复前的树可对照；要跑翻转请用 TEAM_FLIP_BASE=<修复前 sha>)\n' "$BASE"
elif [ -f "$RED_EXT" ]; then
  if grep -qF "'--show-toplevel'" "$RED_EXT"; then
    # M27/M30 都在、只缺 P33：修复前的树里结果文本没有 `cmd:` 行 → 夹具应当红在 S12 的显示用例。
    ok "前提成立：$BASE 里有 M30 之后的 team-bg.ts（P33 之前：结果里还不点命令）"
    if run_harness "$RED_EXT" red-base; then
      bad "修复前：夹具竟然全绿（结果里的 cmd 行没有被守门）"
    elif grep -qF "TEAM-BG-CASE FAIL S12 short command is named in the result text" "$TMP/red-base.log"; then
      ok "修复前：结果里没有命令 → S12 的显示用例红 —— 缺失被夹具复现"
    else
      bad "修复前：红了，但不是 P33 的显示用例：$(grep -m1 'TEAM-BG-CASE FAIL' "$TMP/red-base.log" | sed 's/^TEAM-BG-CASE FAIL //')"
    fi
  else
    # main 已经合了 M27 → 修复前的树里是**旧版 team-bg**（缺 M30 的根解析修正）：夹具应当**跑起来**
    # 并红在 S11（worktree 会话的产物被写进共享根）——这一条红就是泄漏本身。
    ok "前提成立：$BASE 里有 M30 之前的 team-bg.ts（旧根解析）"
    if run_harness "$RED_EXT" red-base; then
      bad "修复前：夹具竟然全绿（根解析泄漏没有被抓到）"
    elif grep -qF "TEAM-BG-CASE FAIL S11 a worktree session writes its job log inside the worktree" "$TMP/red-base.log"; then
      ok "修复前：旧根解析（--git-common-dir）让 S11 红 —— 泄漏被夹具复现"
    else
      bad "修复前：红了，但不是 S11（M30 的泄漏形状）：$(grep -m1 'TEAM-BG-CASE FAIL' "$TMP/red-base.log" | sed 's/^TEAM-BG-CASE FAIL //')"
    fi
  fi
else
  ok "前提成立：$BASE 的 extension/ 里只有 team-notify.ts（M27 之前的树）"
  if run_harness "$RED_EXT" red-base; then
    bad "修复前：夹具竟然全绿（缺失的扩展被当成了通过）"
  else
    ok "修复前：夹具非 0 退出（$(grep -m1 'TEAM-BG-CASE FAIL' "$TMP/red-base.log" | sed 's/^TEAM-BG-CASE FAIL //')）"
  fi
  if grep -q 'TEAM-BG-CASE PASS' "$TMP/red-base.log"; then
    bad "修复前：夹具居然跑出了通过用例（import 都失败了不该有）"
  else
    ok "修复前：一个用例都没有通过（import 阶段就红）"
  fi
fi

# ── ② 定点破坏：每一行都必须让对应用例变红 ───────────────────────────────────
hdr "红②：定点破坏（每个只改一行，各自必须红在对应用例）"
mutate_expect_red() { # <tag> <sed 表达式> <必须出现的 FAIL 用例名>
  local tag="$1" expr="$2" want="$3" dir
  MUTATIONS=$((MUTATIONS + 1))
  dir="$TMP/mut-$tag"
  mkdir -p "$dir"
  cp "$SKILL_EXT" "$dir/team-bg.ts"
  sed -i "$expr" "$dir/team-bg.ts"
  if cmp -s "$SKILL_EXT" "$dir/team-bg.ts"; then
    bad "$tag：定点破坏没生效（sed 表达式没匹配到）——不许把假红当证据"
    return
  fi
  if run_harness "$dir/team-bg.ts" "$tag"; then
    bad "$tag：破坏后夹具仍然全绿（这条性质没有被守门）"
  elif grep -qF "TEAM-BG-CASE FAIL $want" "$TMP/$tag.log"; then
    ok "$tag：红在「$want」"
  else
    bad "$tag：红了，但不是那条用例（期望 $want）：$(grep -m1 'TEAM-BG-CASE FAIL' "$TMP/$tag.log" | sed 's/^TEAM-BG-CASE FAIL //')"
  fi
}

# 收割静默：完成筛选条件里去掉「未收割」这一条 → 已经收割过的作业仍会被唤醒
mutate_expect_red harvest-silent \
  's/\.filter(j => j\.done && !j\.harvested && !j\.notified)/.filter(j => j.done \&\& !j.notified)/' \
  "S2 harvested job never wakes the agent"
# 合并窗口：250ms → 0 → 同一拍完成的作业各发一条（#689 的过量唤醒）
mutate_expect_red merge-window \
  's/const MERGE_WINDOW_MS = 250/const MERGE_WINDOW_MS = 0/' \
  "S3 two jobs finishing together produce exactly one message"
# 唤醒投递方式：followUp+triggerTurn → nextTurn（排队不唤醒）
mutate_expect_red wake-mode \
  "s/{ triggerTurn: true, deliverAs: 'followUp' }/{ deliverAs: 'nextTurn' }/" \
  "S1 wake is a followUp with triggerTurn"
# 账本格式：settled-with-unharvested → 别的名字（PM 复验/digest 的读法失效）
mutate_expect_red ledger-format \
  's/settled-with-unharvested=\${open\.length}/settle-unharvested=\${open.length}/' \
  "S5 settled lines report the unharvested count"
# 日志上限：无视 TEAM_BG_LOG_MAX_BYTES（回到固定 512KB）→ 夹具的小上限不再生效
mutate_expect_red log-cap \
  's/return Number\.isFinite(n) && n >= 256 ? n : DEFAULT_MAX_BYTES/return DEFAULT_MAX_BYTES/' \
  "S6 log stays under the cap"
# 根解析（M30）：worktree 会话的产物必须落在**自己的 worktree** —— 退回 git-common-dir 就是泄漏本身
mutate_expect_red worktree-root \
  "s/'--show-toplevel'/'--git-common-dir'/" \
  "S11 a worktree session writes its job log inside the worktree"
# P33-①：结果文本里去掉 `cmd:` 行 → 用户又看不到自己跑的是什么（短命令那条必须红）
mutate_expect_red cmd-line-drop \
  's|\\n  cmd: \${displayCmd(command)}||' \
  "S12 short command is named in the result text"
# P33-②：文本直接用原命令（跳过单行化/缩略）→ 多行命令的换行跟着进结果（那条必须红）
mutate_expect_red cmd-raw-passthrough \
  's|\${displayCmd(command)}|\${command}|' \
  "S12 multiline command is single-lined in the result text"
# P33-③：按 UTF-16 单元切（one.split("")）而不是按码点 → 代理对会被劈成半个（长命令那条必须红）
mutate_expect_red cmd-unit-slice \
  's|Array\.from(one)|one.split("")|' \
  "S12 long command is truncated at the 100th code point + ellipsis"
# P33-④：收割回执里去掉 `cmd:` 行（sed 无 g 只换第一处 = still running 形状）→ 该形状的用例必须红
mutate_expect_red cmd-wait-drop \
  's|\\n  cmd: \${displayCmd(job\.command)}||' \
  "S12 the harvest receipt (still running) names the command too"

# ── ③ 绿：当前树的真扩展 ─────────────────────────────────────────────────────
hdr "绿：当前树的真扩展（同一套夹具）"
if run_harness "$SKILL_EXT" green; then
  ok "绿：夹具全绿（$(grep -c 'TEAM-BG-CASE PASS' "$TMP/green.log") 条用例，$(grep -m1 'TEAM-BG-HARNESS' "$TMP/green.log")）"
else
  bad "绿：当前树的扩展没过夹具"; grep 'TEAM-BG-CASE FAIL' "$TMP/green.log" | sed 's/^/     /'
fi
if grep -q 'TEAM-BG-CASE FAIL' "$TMP/green.log"; then
  bad "绿：输出里还有 FAIL 用例"
else
  ok "绿：没有 FAIL 用例"
fi
if grep -q 'reverse guard: the real repo state/ is untouched' "$TMP/green.log"; then
  ok "反向守卫：夹具确认真实仓库 state/ 未被触碰"
else
  bad "反向守卫：夹具没有跑到真实仓库 state/ 的快照对比"
fi

# ── ④ 真 pi 的加载链（零模型调用）：两个 -e 并列 + 坏扩展对照 ──────────────
hdr "真 pi 加载链：notify + bg 两个 -e（零模型调用），坏扩展必须让 pi 失败"
PI_BIN=""
if command -v pi >/dev/null 2>&1; then PI_BIN="$(command -v pi)"
elif [ -x "$HOME/.bun/bin/pi" ]; then PI_BIN="$HOME/.bun/bin/pi"; fi
if [ -z "$PI_BIN" ]; then
  printf '  (跳过：PATH 里没有 pi 可执行文件 —— 这条是集成证据，不是门禁)\n'
else
  PI_TIMEOUT="${TEAM_BG_PI_TIMEOUT:-30}"
  # 正：两个真扩展都加载，pi 正常跑完（stdin EOF 就退出；rc=0 且没有 Failed to load）
  ( sleep 2 ) | timeout "$PI_TIMEOUT" "$PI_BIN" --mode rpc --no-session \
    -e "$SKILL_DIR/extension/team-notify.ts" -e "$SKILL_EXT" >"$TMP/rpc-green.log" 2>&1
  if [ "$?" -eq 0 ] && ! grep -qi 'failed to load' "$TMP/rpc-green.log"; then
    ok "真 pi 接受两个 -e（notify + bg）且无加载错误"
  else
    bad "真 pi 加载两个扩展失败：$(grep -i 'failed to load' "$TMP/rpc-green.log" | head -1)"
  fi
  # 反：故意抛错的扩展必须让 pi 非 0 退出（证明上面那条不是「pi 根本不看 -e」）
  printf 'export default function () { throw new Error("team-bg-flip-broken-probe") }\n' > "$TMP/broken-ext.ts"
  ( sleep 2 ) | timeout "$PI_TIMEOUT" "$PI_BIN" --mode rpc --no-session -e "$TMP/broken-ext.ts" >"$TMP/rpc-broken.log" 2>&1
  if [ "$?" -ne 0 ] && grep -q 'team-bg-flip-broken-probe' "$TMP/rpc-broken.log"; then
    ok "坏扩展对照：pi 拒绝加载（rc≠0 且报出被抛的错误）"
  else
    bad "坏扩展对照没红：pi 对加载失败的扩展无反应（上面那条正例就没有证据力）"
  fi
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  if [ "$RED1" = "skipped" ]; then
    printf '\033[32mteam-bg-flip：绿 + 红②×%d 全绿；红① 可见跳过（%s 已含修复，没有修复前的树可对照）\033[0m\n' "$MUTATIONS" "$BASE"
  else
    printf '\033[32mteam-bg-flip：翻转已复现（红① + 红②×%d → 绿）\033[0m\n' "$MUTATIONS"
  fi
  exit 0
fi
printf '\033[31mteam-bg-flip：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
