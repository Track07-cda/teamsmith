#!/usr/bin/env bash
# M30 · team-inbox-watch 扩展的翻转复现（红 → 绿）
#
#   bash skills/teamsmith/tests/team-inbox-watch-flip.sh [--keep]
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/team-inbox-watch-flip.sh      # 默认 merge-base HEAD main
#
# 红（两种，都要有）：
#   ① 修复前的树（BASE，M30 之前）没有 extension/team-inbox-watch.ts —— 换道根本不存在，夹具必须报 import 失败；
#   ② 七个定点破坏（每个只改一行）：合并成一条 / 唤醒投递方式 / 启动基线 / 注册里的 cwd（发送方的判据）/
#      预览截断 / shutdown 清场（外加 trim 之后的 offset 对账）—— 每个都必须让夹具里**对应用例**变红。
#      破坏没生效（sed 没匹配上）= 假红，直接判失败。
# 绿：当前树的真扩展跑同一套夹具，全绿（TEAM-IW-HARNESS OK）。
#
# 只写 /tmp 下的临时目录；不碰调用者所在的仓库/session/tmux（夹具自己清空 TEAM_* 身份并断言
# 产物落在临时仓库里，另有一条反向守卫对比真实仓库 state/ 的前后快照）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
SKILL_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'team-inbox-watch-flip: 找不到 git 仓库（需要它取修复前的树）\n' >&2; exit 2; }

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
[ -n "$RUNNER" ] || { printf 'team-inbox-watch-flip: 没有能跑 .ts 的运行时（node 开启类型剥离 / bun / tsx）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'team-inbox-watch-flip: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1
TMP="$(mktemp -d /tmp/teamsmith-flip-m30.XXXXXX)"
cleanup() { [ "$KEEP" = "1" ] || rm -rf "$TMP"; }
trap cleanup EXIT

FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr() { printf '\n== %s ==\n' "$1"; }

HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"
[ -f "$HARNESS" ] || { printf 'team-inbox-watch-flip: 缺夹具 %s\n' "$HARNESS" >&2; exit 2; }
run_harness() { # <ext.ts> <tag> → 0/1（stdout 落 $TMP/<tag>.log）
  local ext="$1" tag="$2"
  $RUNNER "$HARNESS" "$ext" >"$TMP/$tag.log" 2>&1
}

printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n运行时: %s\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR" "$RUNNER"

# ── ① 修复前的树：换道不存在 ────────────────────────────────────────────────
hdr "红①：修复前的树没有 team-inbox-watch.ts（投递换道不存在）"
mkdir -p "$TMP/red/ext"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith/extension 2>/dev/null | tar -x -C "$TMP/red"
RED_EXT="$TMP/red/skills/teamsmith/extension/team-inbox-watch.ts"
if [ -f "$RED_EXT" ]; then
  bad "$BASE 已经包含 team-inbox-watch.ts（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定"
else
  ok "前提成立：$BASE 的 extension/ 里没有 team-inbox-watch.ts"
fi
if run_harness "$RED_EXT" red-base; then
  bad "修复前：夹具竟然全绿（缺失的扩展被当成了通过）"
else
  ok "修复前：夹具非 0 退出（$(grep -m1 'TEAM-IW-CASE FAIL' "$TMP/red-base.log" | sed 's/^TEAM-IW-CASE FAIL //')）"
fi
if grep -q 'TEAM-IW-CASE PASS' "$TMP/red-base.log"; then
  bad "修复前：夹具居然跑出了通过用例（import 都失败了不该有）"
else
  ok "修复前：一个用例都没有通过（import 阶段就红）"
fi

# ── ② 定点破坏：每一行都必须让对应用例变红 ───────────────────────────────────
hdr "红②：七个定点破坏（每个只改一行，各自必须红在对应用例）"
mutate_expect_red() { # <tag> <sed 表达式> <必须出现的 FAIL 用例名>
  local tag="$1" expr="$2" want="$3" dir
  dir="$TMP/mut-$tag"
  mkdir -p "$dir"
  cp "$SKILL_EXT" "$dir/team-inbox-watch.ts"
  sed -i "$expr" "$dir/team-inbox-watch.ts"
  if cmp -s "$SKILL_EXT" "$dir/team-inbox-watch.ts"; then
    bad "$tag：定点破坏没生效（sed 表达式没匹配到）——不许把假红当证据"
    return
  fi
  if run_harness "$dir/team-inbox-watch.ts" "$tag"; then
    bad "$tag：破坏后夹具仍然全绿（这条性质没有被守门）"
  elif grep -qF "TEAM-IW-CASE FAIL $want" "$TMP/$tag.log"; then
    ok "$tag：红在「$want」"
  else
    bad "$tag：红了，但不是那条用例（期望 $want）：$(grep -m1 'TEAM-IW-CASE FAIL' "$TMP/$tag.log" | sed 's/^TEAM-IW-CASE FAIL //')"
  fi
}

# 合并成一条：同一拍的多行逐条唤醒（刷屏）
mutate_expect_red merge-one-wake \
  's/if (res\.lines\.length) wake(res\.lines)/for (const _l of res.lines) wake([_l])/' \
  "S3 a burst of three lines produces exactly one wake"
# 唤醒投递方式：followUp+triggerTurn → nextTurn（排队不唤醒）
mutate_expect_red wake-mode \
  "s/{ triggerTurn: true, deliverAs: 'followUp' }/{ deliverAs: 'nextTurn' }/" \
  "S2 wake is a custom team-inbox message with triggerTurn+followUp"
# 启动基线：无基线（offset 从 0 开始）→ 历史行被当成新消息叫一遍
mutate_expect_red startup-baseline \
  's/return readNewLines(file, 0)\.offset/return 0/' \
  "S5 startup baseline equals the current spool size"
# 注册里的 cwd：发送方（team_inbox_watch_route）靠它证明监视器属于本项目 —— 少了它判据就只剩 pid
mutate_expect_red registry-cwd \
  's/^      `cwd=${root}`,$//' \
  "S1 registry carries cwd="
# 预览截断：唤醒消息带上 payload 全文（指针变正文）
mutate_expect_red preview-cap \
  "s/return envNum('TEAM_INBOX_WATCH_PREVIEW', DEFAULT_PREVIEW, 16)/return 100000/" \
  "S4 long payload is truncated in the wake (no payload dump)"
# shutdown 清场：不删注册文件（发送方会一直以为有个活着的监视器）
mutate_expect_red shutdown-cleanup \
  's/rmSync(reg, { force: true })/void reg/' \
  "S7 shutdown removes the registry file"
# 裁剪之后的 offset 对账：不对账 → 「size < offset → 从 0 重读」把刚投过的尾部再叫一次
mutate_expect_red trim-offset \
  's/if (trimmed >= 0) offset = trimmed/void trimmed/' \
  "S6 exactly one new wake after the trim (tail line is not replayed)"

# ── ③ 绿：当前树的真扩展 ─────────────────────────────────────────────────────
hdr "绿：当前树的真扩展（同一套夹具）"
if run_harness "$SKILL_EXT" green; then
  ok "绿：夹具全绿（$(grep -c 'TEAM-IW-CASE PASS' "$TMP/green.log") 条用例，$(grep -m1 'TEAM-IW-HARNESS' "$TMP/green.log")）"
else
  bad "绿：当前树的扩展没过夹具"; grep 'TEAM-IW-CASE FAIL' "$TMP/green.log" | sed 's/^/     /'
fi
if grep -q 'TEAM-IW-CASE FAIL' "$TMP/green.log"; then
  bad "绿：输出里还有 FAIL 用例"
else
  ok "绿：没有 FAIL 用例"
fi
if grep -q 'reverse guard: the real repo state/ is untouched' "$TMP/green.log"; then
  ok "反向守卫：夹具确认真实仓库 state/ 未被触碰"
else
  bad "反向守卫：夹具没有跑到真实仓库 state/ 的快照对比"
fi

# ── ④ 真 pi 的加载链（零模型调用）：三个 -e 并列 + 坏扩展对照 ────────────────
hdr "真 pi 加载链：notify + bg + inbox-watch 三个 -e（零模型调用），坏扩展必须让 pi 失败"
PI_BIN=""
if command -v pi >/dev/null 2>&1; then PI_BIN="$(command -v pi)"
elif [ -x "$HOME/.bun/bin/pi" ]; then PI_BIN="$HOME/.bun/bin/pi"; fi
if [ -z "$PI_BIN" ]; then
  printf '  (跳过：PATH 里没有 pi 可执行文件 —— 这条是集成证据，不是门禁)\n'
else
  PI_TIMEOUT="${TEAM_IW_PI_TIMEOUT:-30}"
  # 正：三个真扩展都加载，pi 正常跑完（stdin EOF 就退出；rc=0 且没有 Failed to load）
  ( sleep 2 ) | timeout "$PI_TIMEOUT" "$PI_BIN" --mode rpc --no-session \
    -e "$SKILL_DIR/extension/team-notify.ts" -e "$SKILL_DIR/extension/team-bg.ts" -e "$SKILL_EXT" >"$TMP/rpc-green.log" 2>&1
  if [ "$?" -eq 0 ] && ! grep -qi 'failed to load' "$TMP/rpc-green.log"; then
    ok "真 pi 接受三个 -e（notify + bg + inbox-watch）且无加载错误"
  else
    bad "真 pi 加载三个扩展失败：$(grep -i 'failed to load' "$TMP/rpc-green.log" | head -1)"
  fi
  # 反：故意抛错的扩展必须让 pi 非 0 退出（证明上面那条不是「pi 根本不看 -e」）
  printf 'export default function () { throw new Error("team-inbox-watch-flip-broken-probe") }\n' > "$TMP/broken-ext.ts"
  ( sleep 2 ) | timeout "$PI_TIMEOUT" "$PI_BIN" --mode rpc --no-session -e "$TMP/broken-ext.ts" >"$TMP/rpc-broken.log" 2>&1
  if [ "$?" -ne 0 ] && grep -q 'team-inbox-watch-flip-broken-probe' "$TMP/rpc-broken.log"; then
    ok "坏扩展对照：pi 拒绝加载（rc≠0 且报出被抛的错误）"
  else
    bad "坏扩展对照没红：pi 对加载失败的扩展无反应（上面那条正例就没有证据力）"
  fi
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mteam-inbox-watch-flip：翻转已复现（红① + 红②×7 → 绿）\033[0m\n'
  exit 0
fi
printf '\033[31mteam-inbox-watch-flip：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
