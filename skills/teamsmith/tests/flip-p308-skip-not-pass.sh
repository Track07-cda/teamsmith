#!/usr/bin/env bash
# flip-p308-skip-not-pass.sh — P308「跳过不是通过」的翻转夹具（change: tmux-identity-scope · F1′）
#
#   bash skills/teamsmith/tests/flip-p308-skip-not-pass.sh [--keep]
#
# 修的是一条**判据**：`tests/tmux-identity-leak.sh` 的收口原来判 `PASS==0 && FAIL==0`，而两条隔离断言
# 在任何现场都给 ✓ —— 于是「tmux 坏了、七段全跳过」的现场拿到 rc=0（V48 的 F1′）。现在按**段数**判。
# 三条腿把「修的是判据」这件事钉住（改的都是现场或临时副本，本树的夹具只在腿 2 里被**复制**再改）：
#
#   red-now           假 tmux（解析得到、`-V` 失败）+ `--all`   → rc=77，并点名「跳过不是通过」
#   legacy-predicate  同一现场 + 收口换回 `PASS==0 && FAIL==0` → **rc=0**（旧判据把同一个现场判成通过）
#   audit-single      同一现场 + `--select audit`              → rc=0（④ 不需要 tmux，合法单跑不许被误判成跳过）
#   green-normal      正常环境 + `--all`                       → rc=0 且没有段被跳过（不许把正常情形判成跳过）
#
# 判绿：四条腿都符合预期 → exit 0；有腿不符 → exit 1；正常环境没有可用的 tmux（green-normal 没法测）
# → 别的腿照判，全对时 exit 77（跳过不是通过 —— 这个脚本自己也守同一条纪律）。
# 只写自己的临时根（点开头 + 项目 ns，tmp-hygiene 的 owned 家族），--keep 才留现场。
set -uo pipefail

FLIP_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP=0
case "${1:-}" in
  --self-test|"") ;;
  --keep)         KEEP=1 ;;
  *) printf 'flip-p308-skip-not-pass: 不认识的参数 %s（只认 --self-test / --keep）\n' "$1" >&2; exit 2 ;;
esac

FIX="$FLIP_SKILL/tests/tmux-identity-leak.sh"
[ -f "$FIX" ] || { printf 'flip-p308-skip-not-pass: 找不到 %s\n' "$FIX" >&2; exit 2; }
grep -qF '# >>> P308 close-out predicate' "$FIX" \
  || { printf 'flip-p308-skip-not-pass: %s 里没有变异标记（夹具被改过？）\n' "$FIX" >&2; exit 2; }
# shellcheck source=../scripts/lib/common.sh
. "$FLIP_SKILL/scripts/lib/common.sh" 2>/dev/null \
  || { printf 'flip-p308-skip-not-pass: 找不到 %s/scripts/lib/common.sh（skill 树不全）\n' "$FLIP_SKILL" >&2; exit 2; }
NS="$(team_project_ns 2>/dev/null || printf 'nosig-00000000')"
BASE="$(team_tmp_root)"
ROOT="$(mktemp -d "$BASE/.teamsmith-p308flip-$NS.XXXXXX")" || exit 2

FLIP_RC=0; SKIPPED=0
note()     { printf '%s\n' "$*"; }
line_ok()  { note "  ✓ $*"; }
line_bad() { note "  ✗ $*"; FLIP_RC=1; }
strip()    { sed -e 's/\x1b\[[0-9;]*m//g' "$1" > "$1.clean" 2>/dev/null || : > "$1.clean"; }

# 假 tmux：**解析得到**（`command -v tmux` 命中）、但 `-V` 失败 —— V48 那个现场的精确形状。
# 它不执行任何 tmux 动词，只是让夹具的可用性探针失败（`exit 1`）。
FAKEBIN="$ROOT/fakebin"
mkdir -p "$FAKEBIN"
printf '#!/usr/bin/env bash\nexit 1\n' > "$FAKEBIN/tmux"
chmod +x "$FAKEBIN/tmux"
FAKE_PATH="$FAKEBIN:/usr/bin:/bin"

# 腿：跑一份夹具，抓 rc / 结果行
leg() { # <名字> <PATH> <夹具路径> <args…> → 打印 "rc=<n>"，日志在 $ROOT/<名字>.log[.clean]
  local name="$1" path="$2" fix="$3"; shift 3
  local rc=0
  ( cd "$FLIP_SKILL" && PATH="$path" bash "$fix" "$@" ) > "$ROOT/$name.log" 2>&1 || rc=$?
  strip "$ROOT/$name.log"
  printf '%s' "$rc"
}
res_line() { grep -a '== tmux-identity-leak 结果 ==' "$ROOT/$1.log.clean" | tail -1; }
leg_has()  { grep -aqF -- "$3" "$ROOT/$2.log.clean" && line_ok "$1：出现「$3」" || line_bad "$1：没有出现「$3」"; }
leg_not()  { grep -aqF -- "$3" "$ROOT/$2.log.clean" && line_bad "$1：不该出现「$3」" || line_ok "$1：没有「$3」"; }
leg_rc()   { if [ "$3" = "$2" ]; then line_ok "$1：rc=$2"; else line_bad "$1：退出码应当 $2，实际 $3"; fi }

note "== flip-p308-skip-not-pass（P308 · 收口按段数判，不按 PASS 判）=="
note "临时根：$ROOT"
note "夹具：$FIX"

# ── 腿 1：现在的现场（假 tmux、全跳过）必须 rc=77 ───────────────────────────────────────────────
rc="$(leg red-now "$FAKE_PATH" "$FIX" --all)"
note "leg red-now：rc=$rc（$([ "$rc" = 77 ] && echo 77 || echo "期望 77")）"
leg_rc red-now 77 "$rc"
leg_has red-now red-now '跳过不是通过'
leg_has red-now red-now '需要 tmux 的 6 段一段都没跑起来'
leg_has red-now red-now '跳过 7 段'

# ── 腿 2：把收口换回旧判据（PASS==0 && FAIL==0）→ 同一个现场必须**再次 rc=0** ──────────────────
# 变异只发生在临时镜像里：夹具复制到 <tmp>/mirror/skills/teamsmith/tests/，lib 与 scripts 用软链指回本树
# （这样 REPO_ROOT/SKILL_DIR 的推导与真身一致，产品代码仍是本树那一份，本树逐字节不动）。
MIRROR="$ROOT/mirror/skills/teamsmith"
mkdir -p "$MIRROR/tests"
ln -s "$FLIP_SKILL/tests/lib" "$MIRROR/tests/lib"
ln -s "$FLIP_SKILL/scripts" "$MIRROR/scripts"
LEGACY_BLOCK="$ROOT/legacy-closeout.sh"
cat > "$LEGACY_BLOCK" <<'LEGACYEOF'
if [ "$PASS" -eq 0 ] && [ "$FAIL" -eq 0 ]; then
  printf '\033[33m跳过不是通过\033[0m：tmux 解析到了但不可用（%s -V 失败），本机没有可测的现场（rc=77）\n' "$REAL_TMUX"
  exit 77
fi
LEGACYEOF
awk -v legacy="$LEGACY_BLOCK" '
  /^# >>> P308 close-out predicate/ { inblock = 1; next }
  /^# <<< P308 close-out predicate/ { inblock = 0; while ((getline l < legacy) > 0) print l; close(legacy); next }
  inblock { next }
  { print }
' "$FIX" > "$MIRROR/tests/tmux-identity-leak.sh"
# 变异必须真的应用了（不然这条腿证不到任何东西）
if grep -qF 'if [ "$PASS" -eq 0 ] && [ "$FAIL" -eq 0 ]; then' "$MIRROR/tests/tmux-identity-leak.sh" \
   && ! grep -qF '# >>> P308 close-out predicate' "$MIRROR/tests/tmux-identity-leak.sh"; then
  line_ok 'legacy-predicate：临时镜像里的收口已换回旧判据（PASS==0 && FAIL==0）'
else
  line_bad 'legacy-predicate：变异没应用（镜像里还是新判据 / 旧判据没写进去）'
fi
rc="$(leg legacy-predicate "$FAKE_PATH" "$MIRROR/tests/tmux-identity-leak.sh" --all)"
note "leg legacy-predicate：rc=$rc（旧判据下同一现场应当 rc=0 —— 这就是 F1′ 的假绿）"
leg_rc legacy-predicate 0 "$rc"
leg_not legacy-predicate legacy-predicate '跳过不是通过'
leg_has legacy-predicate legacy-predicate '跳过 7 段'

# ── 腿 3：④（审计）不需要 tmux —— 合法单跑不许被新判据误判成「全跳过」 ─────────────────────────
rc="$(leg audit-single "$FAKE_PATH" "$FIX" --select audit)"
note "leg audit-single：rc=$rc（④ 只靠 stub，合法单跑应当 rc=0）"
leg_rc audit-single 0 "$rc"
leg_not audit-single audit-single '跳过不是通过'

# ── 腿 4：正常环境：rc=0 且**没有段被跳过**（不许把正常情形判成跳过）────────────────────────────
REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
if [ -z "$REAL_TMUX" ] || ! timeout 5 "$REAL_TMUX" -V >/dev/null 2>&1; then
  note "leg green-normal：· 跳过 —— 本机没有可用的 tmux（${REAL_TMUX:-解析不到}），这一段测不了"
  SKIPPED=1
else
  rc="$(leg green-normal "$PATH" "$FIX" --all)"
  note "leg green-normal：rc=$rc（$(res_line green-normal)）"
  leg_rc green-normal 0 "$rc"
  mg="$(res_line green-normal)"
  case "$mg" in
    *跳过*) line_bad "green-normal：正常环境里仍有段被跳过（$mg）" ;;
    '')     line_bad 'green-normal：没有结果行（夹具没跑到收口）' ;;
    *)      line_ok "green-normal：没有段被跳过（$mg）" ;;
  esac
  grep -aqF '✓ ①c server 全局环境里本项目 TEAM_* 条数' "$ROOT/green-normal.log.clean" \
    && line_ok 'green-normal：①（写侧）真的跑了（不是只剩隔离断言）' \
    || line_bad 'green-normal：① 没跑（正常环境里身份契约没被测）'
fi

# ── 收口 ────────────────────────────────────────────────────────────────────────────────────────
note ""
if [ "$FLIP_RC" != "0" ]; then
  note "FLIP 有未达预期的腿（证据：$ROOT）"
  [ "$KEEP" = "1" ] || rm -rf "$ROOT"
  exit 1
fi
if [ "$SKIPPED" = "1" ]; then
  note "FLIP 的三条腿全中，但正常环境的绿侧测不了（没有可用的 tmux）—— 跳过不是通过（rc=77）"
  [ "$KEEP" = "1" ] || rm -rf "$ROOT"
  exit 77
fi
note "FLIP 全绿：同一现场旧判据 rc=0 / 新判据 rc=77，审计单跑不被误判，正常环境无跳过（证据：$ROOT）"
[ "$KEEP" = "1" ] || rm -rf "$ROOT"
exit 0
