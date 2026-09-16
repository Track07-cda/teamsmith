#!/usr/bin/env bash
# M12 · 独立复现 + 翻转夹具：smoke 的 PM 适配器段（6i）「读夹具产物读得太早」的竞态
#
#   bash skills/teamsmith/tests/flip-m12.sh                 # 翻转：同一条延迟注入下「旧测试红 / 新测试绿」
#   bash skills/teamsmith/tests/flip-m12.sh --measure 24    # 只测失败率：当前树 6i 段连跑 24 次
#   bash skills/teamsmith/tests/flip-m12.sh --probe pm      # 只跑一个注入面（诊断用）
#   TEAM_FLIP_BASE=<修复前的 sha> bash …/flip-m12.sh         # 基线（默认 merge-base HEAD main）
#
# 为什么需要：6i 的夹具（假 PM / 裸名字 CLI / 窗口标记 / 人工 respawn）都是**异步**落盘的，而
# `team up` 的承诺只是「PM 进程起来了」（proof=spawn/argv），不是「CLI 已经写出第 N 行」——夹具落盘
# 晚于 up 返回是**合法**时序。旧测试用固定 sleep / 立刻采样来「同步」，负载下就随机读到半截或空
# 文件 → 与产品行为无关的假红（V9-E1 的形状；门禁红一次就要重跑，可信度被腐蚀）。
#
# 本包把「负载抖动」变成**确定性的红/绿**：同一条注入（夹具推迟 2s 第一次落盘）下
#   旧测试（BASE 的 smoke.sh）→ 红：哪几条断言、什么时序，日志里逐条带证据；
#   新测试（当前树）→ 绿：有界轮询等的是**实际条件**，注入 2s 落在 deadline 内。
# 两边跑的都是**当前树的产品代码**：varBase..HEAD 之间除 tests/ 外 skills/teamsmith 无改动（脚本自检），
# 所以翻转的变量只有「测试怎么同步」这一项。
#
# 边界：只读 git（`git show BASE:…smoke.sh`），只写 /tmp 下的临时目录；截出来的 smoke 段在 EXIT 时
# 自己收干净（kill 自己的 session），不碰调用者所在的仓库/session。
set -uo pipefail

INJ="${TEAM_FLIP_INJ:-2}"          # 注入的延迟秒数（> 有界轮询的抖动余量、≪ deadline）
WAIT_SECS="${TEAM_FLIP_WAIT:-150}"  # 单次探针的护栏（截断跑实测 ~47s，注入 +~8s；护栏只是防挂死）
SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m12: 找不到 git 仓库（本脚本要用 git show 取旧测试）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m12: 需要 tmux（复现是 tmux 现场的）\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-m12: 需要 python3（给夹具注入延迟）\n' >&2; exit 2; }

MODE="flip"; MEASURE_N=0; ONLY=""
case "${1:-}" in
  --measure) MODE="measure"; MEASURE_N="${2:-0}" ;;
  --probe)   MODE="probe";   ONLY="${2:-}"
             [ -n "$ONLY" ] || { printf 'flip-m12 --probe <pm|bare|pane|manual>\n' >&2; exit 2; } ;;
  ""|-h|--help)
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then sed -n '2,20p' "$0"; exit 0; fi ;;
  *) printf 'flip-m12: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

TMP="$(mktemp -d /tmp/teamsmith-flip-m12.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

CUR_SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$CUR_SMOKE" ] || { printf 'flip-m12: 找不到 %s\n' "$CUR_SMOKE" >&2; exit 2; }
# 基线 smoke：默认与保护分支的分叉点。守卫：它必须真的还是「修复前」（不含 pm_wait），否则红侧
# 不成立（repo 合并之后 merge-base 会落在修复之后，那时要显式给 TEAM_FLIP_BASE=<修复前的 sha>）。
BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m12: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }
BASE_SMOKE="$TMP/smoke-base.sh"
git -C "$REPO_ROOT" show "$BASE:skills/teamsmith/tests/smoke.sh" > "$BASE_SMOKE" 2>/dev/null \
  || { printf 'flip-m12: %s 里没有 skills/teamsmith/tests/smoke.sh（换个 TEAM_FLIP_BASE）\n' "$BASE" >&2; exit 2; }
if grep -q '^  pm_wait() {' "$BASE_SMOKE"; then
  printf 'flip-m12: BASE（%s）已经含 M12 的有界等待（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' "$BASE" >&2
  exit 2
fi
if ! grep -q '^  pm_wait() {' "$CUR_SMOKE"; then
  printf 'flip-m12: 当前树 %s 没有 M12 的有界等待（这棵树上没有修复）\n' "$CUR_SMOKE" >&2
  exit 2
fi
# 产品代码同源自检：BASE..HEAD 之间 skills/teamsmith 下除 tests/ 外不许有改动
PROD_CHANGED="$(git -C "$REPO_ROOT" diff --name-only "$BASE" HEAD -- skills/teamsmith 2>/dev/null \
  | grep -v '^skills/teamsmith/tests/' || true)"
[ -z "$PROD_CHANGED" ] || {
  printf 'flip-m12: BASE..HEAD 之间产品代码也变了 —— 翻转就不只测「测试怎么同步」了：\n%s\n' "$PROD_CHANGED" >&2
  exit 2
}

# 默认只跑**已知会被旧测试抖红**的三个面。manual（4b 的人工 respawn）不列进来：旧断言在 CLI 真的
# 起来之前就会被满足 —— 窗口里的 wrapper 命令行本身就带着配置的 CLI 名字（身份判定命中 shell 的 argv），
# 所以注 2s 也红不了；那一条在 smoke 里改成「等 CLI 真的落盘」属于加固，不是翻转证据（见报告）。
MODES="pm bare pane"
[ -n "$ONLY" ] && MODES="$ONLY"

# ── 把 smoke 的 0..6i 段截出来（6i 的段前现场、夹具、真窗口一条不少；6j 之后与 6i 无关）──
#    再把夹具的第一次落盘推迟 INJ 秒（只改夹具，不改产品代码）。
build_probe() { # <src-smoke> <out> <mode>
  local src="$1" out="$2" mode="$3"
  awk '/^# -+ 6j\. worker adapter/{exit} {print}' "$src" \
    | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$SKILL_DIR\"|" > "$out"
  python3 - "$out" "$INJ" "$mode" <<'PY' || return 1
import sys
path, inj, mode = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()

def sub(old, new, label):
    global src
    assert src.count(old) == 1, "注入锚点不唯一/找不到：%s" % label
    src = src.replace(old, new, 1)

if mode == "none":
    pass   # --measure：截断但不注入，测自然抖动
elif mode == "pm":
    m = "# 假的非 Pi PM CLI：证明 teamsmith 在没有 Pi 的情况下也能启动 PM、把提示词交给它、让它在团队里干活"
    sub(m, m + "\nsleep " + inj + "   # 注入：推迟夹具第一次落盘", "fake-pm")
elif mode == "bare":
    old = "printf '#!/usr/bin/env bash\\nprintf \"bare-pm-ran %%s\\\\n\" \"$*\" >> \"%s\"\\nsleep 600\\n'"
    sub(old, "printf '#!/usr/bin/env bash\\nsleep " + inj + "\\nprintf \"bare-pm-ran %%s\\\\n\" \"$*\" >> \"%s\"\\nsleep 600\\n'", "pm-bare")
elif mode == "pane":
    old = "\"printf 'PANE-MARKER-1\\\\n'; printf '\\\\n%.0s' \\$(seq 1 40); printf 'PANE-MARKER-2\\\\n'; sleep 30\""
    sub(old, "\"sleep " + inj + "; printf 'PANE-MARKER-1\\\\n'; printf '\\\\n%.0s' \\$(seq 1 40); printf 'PANE-MARKER-2\\\\n'; sleep 30\"", "窗口标记")
elif mode == "manual":
    old = "tmux respawn-pane -k -t \"$SESSION:$PMW\" \"cd $REPO && exec $FAKE/fake-pm.sh --manual\""
    sub(old, "tmux respawn-pane -k -t \"$SESSION:$PMW\" \"sleep " + inj + "; cd $REPO && exec $FAKE/fake-pm.sh --manual\"", "人工 PM")
else:
    raise SystemExit("unknown mode: " + mode)
open(path, "w").write(src)
PY
  cat >> "$out" <<'EOF'
section "15 · 完成（截断探针：0..6i）"
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOF
}

probe_run() { # <src-smoke> <mode> <log> → 退出码 = 探针退出码
  local src="$1" mode="$2" log="$3" p rc
  p="$TMP/probe-$mode-$$.sh"
  build_probe "$src" "$p" "$mode" || { printf 'flip-m12: 组装探针失败（%s / %s）\n' "$src" "$mode" >&2; return 2; }
  timeout "$WAIT_SECS" bash "$p" > "$log" 2>&1; rc=$?
  rm -f "$p"
  return "$rc"
}

reds() { grep -a '✗' "$1" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -v '== 结果 =='; }
result_line() { grep -a '== 结果 ==' "$1" 2>/dev/null | tail -1 | sed 's/\x1b\[[0-9;]*m//g'; }

if [ "$MODE" = "measure" ]; then
  [ "$MEASURE_N" -gt 0 ] || { printf 'flip-m12 --measure <次数>（例如 24）\n' >&2; exit 2; }
  printf 'M12 测量：当前树 6i 段（截断探针、不加注入）连跑 %s 次\n  smoke=%s\n' "$MEASURE_N" "$CUR_SMOKE"
  n=0; bad_n=0
  while [ "$n" -lt "$MEASURE_N" ]; do
    n=$((n + 1))
    if probe_run "$CUR_SMOKE" none "$TMP/measure-$n.log"; then
      printf '  run %-3s 绿  %s\n' "$n" "$(result_line "$TMP/measure-$n.log")"
    else
      bad_n=$((bad_n + 1))
      printf '  run %-3s 红  %s\n' "$n" "$(result_line "$TMP/measure-$n.log")"
      reds "$TMP/measure-$n.log" | sed 's/^/      /'
    fi
  done
  printf '失败率：%s/%s\n' "$bad_n" "$n"
  [ "$bad_n" -eq 0 ] || exit 1
  exit 0
fi

# ── 翻转 / 单面探针 ────────────────────────────────────────────────────────────
printf 'M12 翻转：同一注入（夹具推迟 %ss 落盘）下，旧测试必须红、新测试必须绿\n' "$INJ"
printf '  BASE  smoke=%s（%s）\n  当前  smoke=%s\n  probe=%s\n' "$BASE_SMOKE" "$BASE" "$CUR_SMOKE" "$MODES"
FAILED=0
for m in $MODES; do
  printf '\n== 注入面 %s ==\n' "$m"
  if [ "$MODE" = "probe" ]; then
    probe_run "$CUR_SMOKE" "$m" "$TMP/cur-$m.log"; rc=$?
    printf '  当前树：rc=%s %s\n' "$rc" "$(result_line "$TMP/cur-$m.log")"
    reds "$TMP/cur-$m.log" | sed 's/^/      /'
    [ "$rc" -eq 0 ] || exit 1
    continue
  fi
  probe_run "$BASE_SMOKE" "$m" "$TMP/base-$m.log"; brc=$?
  probe_run "$CUR_SMOKE"  "$m" "$TMP/cur-$m.log";  crc=$?
  printf '  旧测试（BASE）：rc=%s %s\n' "$brc" "$(result_line "$TMP/base-$m.log")"
  reds "$TMP/base-$m.log" | sed 's/^/      /'
  printf '  新测试（当前）：rc=%s %s\n' "$crc" "$(result_line "$TMP/cur-$m.log")"
  if [ "$brc" -eq 0 ]; then
    printf '  ✗ 翻转不成立：注入没能让旧测试红（注入面 %s）\n' "$m"; FAILED=1
  fi
  if [ "$crc" -ne 0 ]; then
    printf '  ✗ 修复不成立：同一个注入让新测试红了（注入面 %s）\n' "$m"
    reds "$TMP/cur-$m.log" | sed 's/^/      /'; FAILED=1
  fi
done
printf '\n'
if [ "$MODE" = "probe" ]; then exit 0; fi
[ "$FAILED" -eq 0 ] && printf '翻转成立：旧测试红、新测试绿（注入面 %s）\n' "$MODES" \
                    || { printf '翻转失败（见上）\n'; exit 1; }
