#!/usr/bin/env bash
# ledger-claim.sh — P239 · 「写/改账本文本」的改动必须选中账本禁令段（§60）
#
#   bash skills/teamsmith/tests/ledger-claim.sh          # 全部用例
#   bash skills/teamsmith/tests/ledger-claim.sh --keep   # 保留临时根（诊断）
#
# 归属的唯一声明处是 tests/section-paths.tsv：表头 `# ledger-scan: <key>` 指定哪一行负责团队账本，
# 该行的 patterns 里声明 `docs/team/**`。这个夹具证明三件事，每件都带红侧：
#   ① 归属在：`--paths docs/team/<任何账本文本>` → decision=RUN 且选中账本扫描段（不再是 NONE）；
#      且运行集只多这一段（前导 + 它），没有把整套门禁拖进来；非账本的 docs 路径仍然 NONE。
#   ② 归属承重（红侧二）：把归属从表**副本**里去掉 → 同一路径回到 NONE；--check 同时点名
#      「账本扫描行没有声明 …」（去掉归属 = 账本改动不再选中任何段，这条必须红）。
#   ③ 该段开火（红侧一）：报告里植入一个家目录字面量 → 扫描红并点名 file:line；植入前绿。
#      外加红侧三的假绿对照：同一份报告**不在**另一棵树里时 → hits=0 —— 这就是「在主检出跑
#      同一检查」的机制（那棵树没有本分支的新文件，0 不是「本分支干净」的证据），
#      也正是固定验收行要求「在自己的 worktree / 自己的分支树上跑」的原因。
#
# 纯逻辑：只读真树；写入只落在自己的临时根（lib/tmp-root.sh）。不起 tmux/pi/门禁进程。
# 注意：植入用的家目录字面量在**运行时拼出来**（源码里不留 /home/<名> 形状）——本文件是被
#       publish-public.sh 扫描的产品面，夹具自己不能带一家目录字面量。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || { printf 'ledger-claim: 找不到 git 仓库（需要真检出）\n' >&2; exit 2; }
SEL="$SKILL_DIR/tests/section-select.sh"
BAN="$SKILL_DIR/tests/ledger-ban.sh"
TABLE="$SKILL_DIR/tests/section-paths.tsv"
for f in "$SEL" "$BAN" "$TABLE"; do
  [ -f "$f" ] || { printf 'ledger-claim: 缺 %s\n' "$f" >&2; exit 2; }
done

KEEP=0
case "${1:-}" in
  --keep) KEEP=1 ;;
  "") ;;
  *) printf 'ledger-claim: 未知参数 %s（--keep）\n' "$1" >&2; exit 2 ;;
esac
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create ledger-claim)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

OKN=0; BADN=0
case_ok()  { OKN=$((OKN + 1)); printf '  ✓ %s\n' "$*"; }
case_bad() { BADN=$((BADN + 1)); printf '  ✗ %s\n' "$*"; }
one_line() { printf '%s' "$1" | tr '\n' '|' | cut -c1-220; }

# ── 归属声明：表头 ledger-scan 行 + 它的 patterns ─────────────────────────────────────────
BAN_HEAD="$(awk -F'\t' '/^# ledger-scan:/{ v = $0; sub(/^# ledger-scan:[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v); print v; exit }' "$TABLE")"
BAN_KEY="${BAN_HEAD%% *}"        # 载荷首词 = 归属的段 key；其余 = 归属模式（P239 起表头带模式）
BAN_PAT="${BAN_HEAD#"$BAN_KEY"}"; BAN_PAT="${BAN_PAT# }"
PROLOGUE="$(awk -F'\t' '/^# prologue:/{ v = $0; sub(/^# prologue:[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v); print v; exit }' "$TABLE")"
if [ -n "$BAN_KEY" ] && [ -n "$BAN_PAT" ]; then
  case_ok "归属声明在位：表头 ledger-scan: $BAN_KEY 模式 $BAN_PAT（前导 $PROLOGUE）"
else
  case_bad "映射表缺 ledger-scan 头（或它的归属模式）—— 账本路径的归属没有声明处"
fi

# ── ① 归属在：账本路径 → RUN 且选中账本扫描段（只多这一段） ───────────────────────────────
if [ -n "$BAN_KEY" ]; then
  OUT="$(bash "$SEL" --paths docs/team/reports/P239-dev3.md docs/team/reviews/V9.md docs/team/tasks/T9.md docs/team/threads/dev.md 2>&1)"; RC=$?
  if [ "$RC" = "0" ] && printf '%s\n' "$OUT" | grep -qx 'decision=RUN' \
     && printf '%s\n' "$OUT" | grep -qF "reason=$BAN_KEY ← docs/team/reports/P239-dev3.md"; then
    KEYS="$(printf '%s\n' "$OUT" | awk -F'\t' 'NF == 2 { printf "%s ", $1 }')"
    EXTRA=""
    for k in $KEYS; do
      case " $PROLOGUE $BAN_KEY " in *" $k "*) ;; *) EXTRA="$EXTRA $k" ;; esac
    done
    if [ -z "$EXTRA" ]; then
      case_ok "① 报告 / 复验 / 任务书 / 线程路径 → RUN，只选中前导 + 账本扫描段（$KEYS）"
    else
      case_bad "① 报告路径把运行集扩大了（多出：$EXTRA）"
    fi
  else
    case_bad "① 账本路径没有选中账本扫描段（rc=$RC）：$(one_line "$OUT")"
  fi
  # 非账本的 docs 路径仍是豁免类（NONE）——豁免类没有被整体拆掉
  OUT3="$(bash "$SEL" --paths docs/NOTES.md 2>&1)"
  if printf '%s\n' "$OUT3" | grep -qx 'decision=NONE' \
     && printf '%s\n' "$OUT3" | grep -qF '没有段落需要运行'; then
    case_ok "① 非账本 docs 路径仍豁免（decision=NONE）"
  else
    case_bad "① 非账本 docs 路径不再豁免：$(one_line "$OUT3")"
  fi
fi

# ── ② 归属承重（红侧二）：把归属从表里去掉 → 回到 NONE；--check 点名；收窄 → 没盖到的回落 ──
if [ -n "$BAN_KEY" ]; then
  # ②a 表头整行删掉：账本路径回到豁免类（NONE），--check 点「缺头」
  grep -v '^# ledger-scan:' "$TABLE" >"$TMP/table-no-head.tsv"
  if grep -q '^# ledger-scan:' "$TMP/table-no-head.tsv"; then
    case_bad "②a 表副本没有删掉 ledger-scan 头（夹具失效）"
  else
    case_ok "②a 表副本已删掉 ledger-scan 头"
    OUT="$(bash "$SEL" --table "$TMP/table-no-head.tsv" --paths docs/team/reports/P239-dev3.md 2>&1)"; RC=$?
    if [ "$RC" = "0" ] && printf '%s\n' "$OUT" | grep -qx 'decision=NONE' \
       && printf '%s\n' "$OUT" | grep -qF '没有段落需要运行'; then
      case_ok "②a 去掉归属后同一路径回到 NONE（归属确实来自表头那一行）"
    else
      case_bad "②a 去掉归属后没有回到 NONE（rc=$RC）：$(one_line "$OUT")"
    fi
    bash "$SEL" --check --table "$TMP/table-no-head.tsv" >"$TMP/check-no-head.log" 2>&1; RC=$?
    if [ "$RC" != "0" ] && grep -qF '映射表缺 ledger-scan 头' "$TMP/check-no-head.log"; then
      case_ok "②a --check 对「归属被删」红并点名（缺的是整行 header）"
    else
      case_bad "②a --check 没抓住缺头（rc=$RC）：$(one_line "$(tail -2 "$TMP/check-no-head.log")")"
    fi
  fi
  # ②b 归属模式收窄（只盖任务书）：它没盖到的账本面（复验）回到 NONE
  awk -v key="$BAN_KEY" '/^# ledger-scan:/{ print "# ledger-scan: " key " docs/team/task*"; next } { print }' \
    "$TABLE" >"$TMP/table-narrow.tsv"
  if grep -q '^# ledger-scan: .* docs/team/task\*$' "$TMP/table-narrow.tsv"; then
    OUT="$(bash "$SEL" --table "$TMP/table-narrow.tsv" --paths docs/team/reviews/V9.md 2>&1)"; RC=$?
    if [ "$RC" = "0" ] && printf '%s\n' "$OUT" | grep -qx 'decision=NONE' \
       && printf '%s\n' "$OUT" | grep -qF '没有段落需要运行'; then
      case_ok "②b 归属模式收窄后，它没盖到的复验路径回到 NONE（归属是逐路径判的）"
    else
      case_bad "②b 收窄后的落网行为不符（rc=$RC）：$(one_line "$OUT")"
    fi
  else
    case_bad "②b 表副本的归属模式没有改成 docs/team/task*（夹具失效）"
  fi
fi

# ── ③ 该段开火（红侧一 + 红侧三）：植入 → 红并点名 file:line；不在树里的报告 → hits=0 ─────
BRANCH="$TMP/branch-tree"; mkdir -p "$BRANCH/docs/team/reports" "$BRANCH/.pi/team"
printf '# 他项目名单（夹具）\nfixture-peer\n' >"$BRANCH/.pi/team/forbidden-names.txt"
printf '# 报告（夹具）\n\n干净：家目录占位 <home>/work/example\n' >"$BRANCH/docs/team/reports/leak-report.md"
LEAK_DIR="/home"; LEAK_NAME="leakprobe"

OUT="$(bash "$BAN" --all --root "$BRANCH" --names-file "$BRANCH/.pi/team/forbidden-names.txt" 2>&1)"; RC=$?
if [ "$RC" = "0" ] && printf '%s\n' "$OUT" | grep -qF 'hits=0' && ! printf '%s\n' "$OUT" | grep -qF ': [home]'; then
  case_ok "③ 干净报告（只有占位符 <home>）→ rc=0 hits=0"
else
  case_bad "③ 干净报告没有绿（rc=$RC）：$(one_line "$OUT")"
fi

printf '# 报告（夹具）\n\n干净：家目录占位 <home>/work/example\n泄漏：%s/%s/work/secret\n' \
  "$LEAK_DIR" "$LEAK_NAME" >"$BRANCH/docs/team/reports/planted-report.md"

OUT="$(bash "$BAN" --all --root "$BRANCH" --names-file "$BRANCH/.pi/team/forbidden-names.txt" 2>&1)"; RC=$?
if [ "$RC" = "1" ] && printf '%s\n' "$OUT" | grep -qF 'docs/team/reports/planted-report.md:4: [home]' \
   && printf '%s\n' "$OUT" | grep -qF 'hits=1' && ! printf '%s\n' "$OUT" | grep -qF "$LEAK_NAME"; then
  case_ok "③ 植入家目录字面量 → 红并点名 docs/team/reports/planted-report.md:4（原文被遮蔽）"
else
  case_bad "③ 植入后没有红 / 没点名 file:line（rc=$RC）：$(one_line "$OUT")"
fi

# 红侧三：同一份报告**不在**那棵树里 → hits=0。这就是「在主检出跑同一检查」的形状：
# 主检出的树没有本分支的新报告文件，0 只说明那棵树里没有它。
MAINLIKE="$TMP/mainlike-tree"; mkdir -p "$MAINLIKE/docs/team/reports" "$MAINLIKE/.pi/team"
cp "$BRANCH/.pi/team/forbidden-names.txt" "$MAINLIKE/.pi/team/forbidden-names.txt"
printf '# 主检出样的账本（没有本分支的新报告文件）\n' >"$MAINLIKE/docs/team/reports/existing-report.md"
OUT_B="$(bash "$BAN" --all --root "$BRANCH" --names-file "$BRANCH/.pi/team/forbidden-names.txt" 2>&1)"
OUT_M="$(bash "$BAN" --all --root "$MAINLIKE" --names-file "$MAINLIKE/.pi/team/forbidden-names.txt" 2>&1)"
if printf '%s\n' "$OUT_B" | grep -qF 'hits=1' && printf '%s\n' "$OUT_M" | grep -qF 'hits=0'; then
  case_ok "③ 假绿对照：同一份报告——本分支树 hits=1 / 不含它的树 hits=0（所以在主检出跑扫不到本分支新文件）"
  printf '      对照行：%s\n' "$(printf '%s\n' "$OUT_M" | grep -a '^ledger-ban: root=' | tail -1)"
else
  case_bad "③ 假绿对照没成立：branch=[$(printf '%s' "$OUT_B" | grep -a 'hits=' | tail -1)] mainlike=[$(printf '%s' "$OUT_M" | grep -a 'hits=' | tail -1)]"
fi

printf '== ledger-claim == ✓ %d ✗ %d\n' "$OKN" "$BADN"
[ "$BADN" -eq 0 ]
