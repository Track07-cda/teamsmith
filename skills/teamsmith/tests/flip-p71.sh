#!/usr/bin/env bash
# P81 · 翻转包：wake-delivery-idempotence（写前日志 / 至多一次 / fail-closed / 源行点名）的
# red → green 证据。
#
#   bash skills/teamsmith/tests/flip-p71.sh
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-p71.sh   # 覆盖「修复前」的 revision
#
# 事故（2026-09-22）：一条 nudge 让 PM 在一个多小时里被「同一条」叫醒三次；durable 文件回答不了
# 「到底投过没有」。根因是 `wake()` 把去重记忆与账本写在 `pi.sendMessage` **之前**、并把发送失败
# 吞掉，读者位置只在进程内存里 ——「投过但没记下」「记了但没发出」都是文件可到达的状态。
#
# 本包用**同一个 harness**（tests/team-inbox-watch-harness.mjs；S25a/b/d/e 是 P81 加的用例）对五种树
# 各跑一遍（夹具不变，只换被测扩展；用例用轮询，不依赖 watcher 前提）：
#   ① 红树（TEAM_FLIP_BASE / merge-base HEAD main 的 P81 之前扩展）→ S25a/b/d/e 必须 FAIL（复现）
#   ② 绿树（本 worktree）→ 目标用例全 PASS
#   ③ 变异 A（绿树 + 丢掉发送后的终态记录）→ S25a 必须 FAIL（重启后第二次恢复唤醒）
#   ④ 变异 B（绿树 + 把 intent 读成「还没开始」）→ S25b 必须 FAIL（结果未知的行被重投）
#   ⑤ 变异 C（绿树 + 唤醒文本里拿掉身份与源时间）→ S25d 必须 FAIL（两条相同文本不可区分）
#   ⑥ 变异 D（绿树 + 去掉淘汰下限规则）→ S25e 必须 FAIL（被淘汰的身份被重新唤醒）
#
# 退出码：0 = 六个预期全部成立；1 = 有任何一个不成立；2 = 环境/前置不满足（不算绿也不算红）。
# 隔离：harness 自身就是隔离夹具（清 TEAM_*/TMUX 身份、临时仓库、真实仓库 state/ 前后快照反守卫），
# 本脚本只写 /tmp 临时目录，不调用 tmux。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p71: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

# 能直接跑 .ts 的运行时（与 smoke.sh / flip-m43.sh 同口径）
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  TS_RUNNER="$HOME/.bun/bin/bun"
fi
[ -n "$TS_RUNNER" ] || { printf 'flip-p71: 需要 node（类型剥离）或 bun 来跑 TS 扩展\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-p71: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p71)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0        # 管道/命令替换的子 shell 不要重复清场
  tmp_root_reap_all
}
trap cleanup EXIT

# 子串判定：用 case（不起管道）——`printf ... | grep -q` 在 `set -o pipefail` 下会被 grep 的提前退出
# 变成 SIGPIPE（141）而假红。
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

fail() { printf '\033[31m✗\033[0m %s\n' "$*"; }
pass() { printf '\033[32m✓\033[0m %s\n' "$*"; }

GREEN_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"
ONLY="S25a,S25b,S25d,S25e"

# ---- 目标用例（每个变异点名的那一条 red）---------------------------------------------------
# 红树（P81 之前）里能可靠复现的四条：没有写前日志、没有恢复、没有身份、没有下限
RED_TREE_A='TEAM-IW-CASE FAIL S25a a later rewrite of the same bytes produces no second wake'
RED_TREE_B='TEAM-IW-CASE FAIL S25b the child left a complete read+intent and no sent/failed'
RED_TREE_D='TEAM-IW-CASE FAIL S25d the two rows differ by source time and identity'
RED_TREE_E='TEAM-IW-CASE FAIL S25e an identity below the eviction floor is unprovable, never woken'
# 变异树里每条定点破坏必须打中的那一条
S25A_RED='TEAM-IW-CASE FAIL S25a a later rewrite of the same bytes produces no second wake'
S25B_RED='TEAM-IW-CASE FAIL S25b the restart sends no wake at all'
S25D_RED='TEAM-IW-CASE FAIL S25d the two rows differ by source time and identity'
S25E_RED='TEAM-IW-CASE FAIL S25e an identity below the eviction floor is unprovable, never woken'

# ---- 红树（修复前）--------------------------------------------------------------------------
mkdir -p "$TMP/red-skill"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_EXT="$TMP/red-skill/skills/teamsmith/extension/team-inbox-watch.ts"

# 前置守卫：红树必须真的还没有投递日志，绿树必须真的带着（否则这个包报的是假翻转）
grep -q '\.deliver' "$RED_EXT" 2>/dev/null && {
  printf 'flip-p71: $BASE 已经包含 P81 的投递日志（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2; exit 2; }
grep -q 'deliver blocked' "$GREEN_EXT" || { printf 'flip-p71: 本树扩展里没有 deliver blocked（P81 的修复不在？）\n' >&2; exit 2; }

# ---- 变异树（绿树 + 一处定点破坏）------------------------------------------------------------
for m in mut-a mut-b mut-c mut-d; do mkdir -p "$TMP/$m/extension"; done

cat > "$TMP/mutate.mjs" <<'MUTEOF'
import { readFileSync, writeFileSync } from 'node:fs'
const [file, oldText, newText] = process.argv.slice(2)
const s = readFileSync(file, 'utf8')
if (!s.includes(oldText)) { console.error('anchor missing:', oldText); process.exit(3) }
writeFileSync(file, s.split(oldText).join(newText))
MUTEOF
mutate() { # <file> <old> <new>
  "$TS_RUNNER" "$TMP/mutate.mjs" "$1" "$2" "$3" || { printf 'flip-p71: 变异打不上（锚点不在？）\n' >&2; exit 2; }
}

# 变异 A：**恢复唤醒跳过写前记录**（read/intent 都不写）—— 重启后同一行会被再恢复一次，
# 也就是「一条门铃响两次」。它是「写前顺序」的定点破坏（恢复是唯一允许补发的路径）。
cp "$GREEN_EXT" "$TMP/mut-a/extension/team-inbox-watch.ts"
mutate "$TMP/mut-a/extension/team-inbox-watch.ts" \
  'for (const l of lines) if (!journalAppend(readRecord(l))) return blocked()' \
  'for (const l of lines) if (!(meta.recovery === true) && !journalAppend(readRecord(l))) return blocked()'
mutate "$TMP/mut-a/extension/team-inbox-watch.ts" \
  'if (!journalAppend(`intent seq=${seq}`)) return blocked()' \
  'if (!(meta.recovery === true) && !journalAppend(`intent seq=${seq}`)) return blocked()'

# 变异 B：把 intent（结果未知）读成「还没开始」—— 会重投一条可能已经进过会话的行
cp "$GREEN_EXT" "$TMP/mut-b/extension/team-inbox-watch.ts"
mutate "$TMP/mut-b/extension/team-inbox-watch.ts" \
  "if (entry.state === 'read') entry.state = 'intent'" "if (entry.state === 'read') entry.state = 'read'"

# 变异 C：唤醒文本里拿掉源时间与身份 —— 两条逐字相同的 payload 再也分不开
cp "$GREEN_EXT" "$TMP/mut-c/extension/team-inbox-watch.ts"
mutate "$TMP/mut-c/extension/team-inbox-watch.ts" \
  '${preview}  (src ${src} · id ${l.identity})' '${preview}'

# 变异 D：去掉淘汰下限规则 —— 被压缩淘汰的身份会被重新唤醒（fail-open）
cp "$GREEN_EXT" "$TMP/mut-d/extension/team-inbox-watch.ts"
mutate "$TMP/mut-d/extension/team-inbox-watch.ts" \
  'if (l.src > 0 && floorTs !== null && l.src < floorTs) { out.unprovable++; continue }' \
  'if (false) { out.unprovable++; continue } // MUT-D'

run_harness() { # <extension> → stdout
  TEAM_IW_ONLY="$ONLY" "$TS_RUNNER" "$HARNESS" "$1" 2>&1
}

RC=0

# ---- ① 红树：S25a/b/d/e 必须逐条 FAIL（复现）-------------------------------------------------
RED_LOG="$(run_harness "$RED_EXT")"; RED_RC=$?
if [ "$RED_RC" -ne 0 ] && has "$RED_TREE_A" "$RED_LOG" && has "$RED_TREE_B" "$RED_LOG" \
  && has "$RED_TREE_D" "$RED_LOG" && has "$RED_TREE_E" "$RED_LOG"; then
  pass "红树（$BASE）复现成功：S25a/b/d/e 全红（没有投递日志/至多一次/源行点名）"
else
  fail "红树没有复现（rc=$RED_RC；预期 S25a/b/d/e 的定点断言 FAIL）"
  printf '%s\n' "$RED_LOG" | grep 'TEAM-IW-CASE FAIL S25' | sed 's/^/     /'
  RC=1
fi
printf '%s\n' "$RED_LOG" | grep 'TEAM-IW-CASE FAIL S25' | sed 's/^/  red: /'

# ---- ② 绿树：目标用例全 PASS ---------------------------------------------------------------
GREEN_LOG="$(run_harness "$GREEN_EXT")"; GREEN_RC=$?
if [ "$GREEN_RC" -eq 0 ] && has 'TEAM-IW-HARNESS OK' "$GREEN_LOG" \
  && has 'TEAM-IW-CASE PASS S25a exactly one recovery wake is sent' "$GREEN_LOG" \
  && has 'TEAM-IW-CASE PASS S25b the ledger records exactly one inflight assumed n=1' "$GREEN_LOG" \
  && has 'TEAM-IW-CASE PASS S25d the wake names each line' "$GREEN_LOG" \
  && has 'TEAM-IW-CASE PASS S25e compaction keeps the journal under the bound' "$GREEN_LOG"; then
  pass "绿树（本 worktree）目标用例全绿（S25a/b/d/e）"
else
  fail "绿树目标用例没有全绿（rc=$GREEN_RC）"
  printf '%s\n' "$GREEN_LOG" | grep -E 'TEAM-IW-CASE FAIL|TEAM-IW-HARNESS' | sed 's/^/     /'
  RC=1
fi

# ---- ③–⑥ 四个变异：各自点名的 red 必须出现 --------------------------------------------------
check_mutation() { # <名字> <扩展> <预期 red 子串> <说明>
  local name="$1" ext="$2" want="$3" what="$4" log rc
  log="$(run_harness "$ext")"; rc=$?
  if [ "$rc" -ne 0 ] && has "$want" "$log"; then
    pass "变异 $name：$what —— 命名断言红，rc=$rc"
  else
    fail "变异 $name 没有红（rc=$rc；预期「$want」）"
    printf '%s\n' "$log" | grep 'TEAM-IW-CASE FAIL S25' | sed 's/^/     /'
    RC=1
  fi
  printf '%s\n' "$log" | grep 'TEAM-IW-CASE FAIL S25' | sed "s/^/  $name: /"
}

check_mutation A "$TMP/mut-a/extension/team-inbox-watch.ts" "$S25A_RED" "恢复唤醒跳过写前记录（read/intent）→ 重启后重复恢复唤醒"
check_mutation B "$TMP/mut-b/extension/team-inbox-watch.ts" "$S25B_RED" "把 intent 读成「还没开始」→ 结果未知的行被重投"
check_mutation C "$TMP/mut-c/extension/team-inbox-watch.ts" "$S25D_RED" "唤醒文本拿掉身份 → 两条相同文本不可区分"
check_mutation D "$TMP/mut-d/extension/team-inbox-watch.ts" "$S25E_RED" "去掉淘汰下限规则 → 被淘汰的身份 fail-open 重唤醒"

[ "$RC" -eq 0 ] && printf 'flip-p71: 全部预期成立（red / green / 四个变异）\n'
exit "$RC"
