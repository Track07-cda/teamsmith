#!/usr/bin/env bash
# flip-p410-order2.sh · P410 的红侧：两阶段（一阶每次跑 / 二阶低频跑）里「一段静默消失」的每种形状都
# 必须**按名变红**。四条臂，各自只改 scratch 副本（真树一字不动）：
#
#   ① union-gap      从二阶清单里删掉一段（`# meta-suite: 0e …`）→ 它既不在二阶也没进一阶 →
#                    `section-select.sh --check ⑩` 必须红并点名那段（「从两次运行里一起消失」）。
#   ② product-leg    把一段产品段（7 notify/inbox/digest）写进二阶 → 它本该在 FAST/一阶里跑到 →
#                    `--check` 必须红并点名它（不许为了省时间把产品行为搬出每次的门禁）。
#   ③ no-reason      二阶行不写「为什么它是二阶」→ `--check` 红（声明缺陷），并且运行时 smoke 的那条
#                    「没有一段的跳过行缺理由」也红（跳过行说不出为什么 = 静默）。
#   ④ skip-line      删掉 smoke_meta_begin 里那行 printf（跳过行从输出里消失，但账面照旧）→ 运行时
#                    「输出里的行数 = 跳过段数」必须红：静默消失的那一半由这一条守着。
#
# 用法：bash skills/teamsmith/tests/flip-p410-order2.sh [--keep]
# 退出码：0 = 四条臂都按名变红；1 = 有臂没红（逐条点名并贴现场尾部）；2 = 前提错（缺文件/建不了根）。
# 现场：$TMPDIR 下的私有根，退出时删掉；--keep / TEAM_TMP_KEEP=1 保留并打印路径。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="$(cd -P "$SELF_DIR/../../.." && pwd)"
KEEP=0
case "${1:-}" in
  "") ;;
  --keep) KEEP=1 ;;
  -h|--help) sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) printf 'flip-p410: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac
[ "${TEAM_TMP_KEEP:-0}" = "1" ] && KEEP=1
for f in skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/section-select.sh skills/teamsmith/tests/section-paths.tsv; do
  [ -r "$REAL/$f" ] || { printf 'flip-p410: 缺 %s（--tree 应该在仓库根里跑）\n' "$f" >&2; exit 2; }
done
TMP="$(mktemp -d "${TMPDIR:-/var/tmp}/teamsmith-flip-p410.XXXXXX")" || { printf 'flip-p410: 建不了临时根\n' >&2; exit 2; }
cleanup() {
  if [ "$KEEP" = "1" ]; then printf 'flip-p410：保留现场 %s（--keep）\n' "$TMP"; return 0; fi
  rm -rf "$TMP" || printf 'flip-p410：⚠ 临时根删不掉：%s\n' "$TMP" >&2
}
trap cleanup EXIT

OK=0; BAD=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; OK=$((OK + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; BAD=$((BAD + 1)); }

# ── scratch 树：产品面软链到真树，tests/ 是真目录（每个文件一条软链），smoke.sh 与映射表是真副本 ──────
# 只有那两个文件要被改坏，所以只有它们必须能写；其余一律软链，跑的还是真实现。
vary_tree() { # <名字> → 打印变体仓库根
  local name="$1"
  local base="$TMP/tree-$name" r="$REAL"
  local d="$TMP/tree-$name/skills/teamsmith" x b

  rm -rf "$base"; mkdir -p "$d/tests" "$base/skills"
  for x in "$r"/*; do b="$(basename "$x")"; [ "$b" = "skills" ] && continue; ln -s "$x" "$base/$b"; done
  for x in "$r"/.[!.]*; do b="$(basename "$x")"; [ "$b" = ".git" ] && continue; ln -s "$x" "$base/$b"; done
  for x in "$r"/skills/*; do b="$(basename "$x")"; [ "$b" = "teamsmith" ] && continue; ln -s "$x" "$base/skills/$b"; done
  for x in "$r"/skills/teamsmith/*; do b="$(basename "$x")"; [ "$b" = "tests" ] && continue; ln -s "$x" "$d/$b"; done
  for x in "$r"/skills/teamsmith/tests/*; do b="$(basename "$x")"; ln -s "$x" "$d/tests/$b"; done
  rm -f "$d/tests/smoke.sh" "$d/tests/section-paths.tsv"
  # 变体树要有自己的团队运行面：`$base/.pi` 不能软链到真项目（§14d 会去读元套件记录，读真项目的那份会让
  # 这条红侧依赖别人的现场）。这里造一份**合法**的合成记录，四条臂各自再按需改坏它。
  rm -f "$base/.pi"; mkdir -p "$base/.pi/team/state/meta-suite"
  seed_record "$base"
  cp "$REAL/skills/teamsmith/tests/smoke.sh" "$d/tests/smoke.sh"
  cp "$REAL/skills/teamsmith/tests/section-paths.tsv" "$d/tests/section-paths.tsv"
  printf '%s' "$base"
}

check_log() { # <变体根> <日志> → --check 的 rc（日志落盘）
  ( cd "$1" && bash skills/teamsmith/tests/section-select.sh --check ) >"$2" 2>&1
}

seed_record() { # <变体根> [<ISO 时间>] [<段数>] [<日志里的收口行数>] [<判定>] [<判据 sha>] —— 造一份合法记录
  local base="$1" at="${2:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" secs="${3:-2}" lines="${4:-2}" vd="${5:-GREEN}"
  local dir="$base/.pi/team/state/meta-suite" log="$base/.pi/team/state/meta-suite/run.log" i
  mkdir -p "$dir"
  : > "$log"
  for ((i = 1; i <= lines; i++)); do
    printf '#%d s%d · 合成段 · 参考 用时 1s · ✓1 ✗0 SKIP0 · ticks 1\n' "$i" "$i" >> "$log"
  done
  if [ "${6+set}" = "set" ]; then
    # 显式给了第 6 个参数：空串就是**故意**不写判据列（红侧用），其余照写
    printf '%s\t%s\t%s\t%s\t120\t%s\t%s\n' "$at" "$vd" "$base" "$log" "$secs" "$6" > "$dir/history.tsv"
  else
    printf '%s\t%s\t%s\t%s\t120\t%s\tdeadbeef\n' "$at" "$vd" "$base" "$log" "$secs" > "$dir/history.tsv"
  fi
}
run_p410_selection() { # <变体根> <日志> [<选段键>] —— 在变体树上跑（一阶，纯记账，不起 tmux）
  local vtree="$1" log="$2" keys="${3:-14d}" tmpd="$TMP/select-tmp"
  mkdir -p "$tmpd"
  ( cd "$vtree" && TMPDIR="$tmpd" TEAM_SMOKE_NO_LOCK=1 TEAM_SMOKE_MARKER_ROOT="$REAL" \
      bash skills/teamsmith/tests/smoke.sh --select "$keys" </dev/null ) >"$log" 2>&1
}

# ── ① 并集缺口：删掉 0e 那一行 ────────────────────────────────────────────────────────────────
VT="$(vary_tree union-gap)"
python3 - "$VT/skills/teamsmith/tests/section-paths.tsv" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
out = [l for l in lines if not l.startswith('# meta-suite: 0e ')]
assert len(out) == len(lines) - 1, '0e 那行没被删掉（夹具缺陷）'
open(p, 'w', encoding='utf-8').write('\n'.join(out))
PY
check_log "$VT" "$TMP/union-gap.log"; rc=$?
if [ "$rc" -ne 0 ] && grep -q '既不在 first-order 也不在 meta-suite' "$TMP/union-gap.log" \
   && grep -q '段 0e ' "$TMP/union-gap.log"; then
  ok "① union-gap：删掉二阶清单里的 0e → --check 红并点名 0e（「从两次运行里一起消失」）"
else
  bad "① union-gap 没有按名变红（rc=$rc）：$(grep -m1 -E '✗|bad:' "$TMP/union-gap.log" | cut -c1-160)"
fi

# ── ② 产品段错放进二阶：7 notify/inbox/digest ────────────────────────────────────────────────
VT="$(vary_tree product-leg)"
sed -i 's/^# meta-suite: 0e /# meta-suite: 7 notify\/inbox\/digest 段（故意错放，红侧）\n# meta-suite: 0e /' "$VT/skills/teamsmith/tests/section-paths.tsv"
if ! grep -q '^# meta-suite: 7 ' "$VT/skills/teamsmith/tests/section-paths.tsv"; then
  bad "② product-leg：夹具缺陷 —— 没把 7 加进二阶清单"
else
  check_log "$VT" "$TMP/product-leg.log"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q '产品基线（gate-self-check 没点名它）' "$TMP/product-leg.log" \
     && grep -q '这段在 FAST/一阶里本该跑到' "$TMP/product-leg.log"; then
    ok "② product-leg：把 7 notify/inbox/digest 错放进二阶 → --check 红并指出它本该在一阶/FAST 里跑到"
  else
    bad "② product-leg 没有按名变红（rc=$rc）：$(grep -m1 -E '✗|bad:' "$TMP/product-leg.log" | cut -c1-160)"
  fi
fi

# ── ③ 跳过行的理由缺失 ───────────────────────────────────────────────────────────────────────
VT="$(vary_tree no-reason)"
sed -i 's/^# meta-suite: 0e .*/# meta-suite: 0e/' "$VT/skills/teamsmith/tests/section-paths.tsv"
if ! grep -qx '# meta-suite: 0e' "$VT/skills/teamsmith/tests/section-paths.tsv"; then
  bad "③ no-reason：夹具缺陷 —— 0e 那行的理由没被去掉"
else
  check_log "$VT" "$TMP/no-reason.log"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q '没写理由' "$TMP/no-reason.log" && grep -q '二阶段段 0e' "$TMP/no-reason.log"; then
    ok "③ no-reason：二阶行不写理由 → --check 红并点名 0e（跳过行必须说得出为什么）"
  else
    bad "③ no-reason 没有按名变红（rc=$rc）：$(grep -m1 -E '✗|bad:' "$TMP/no-reason.log" | cut -c1-160)"
  fi
fi

# ── ④ 跳过行从输出里消失（运行时那一半）─────────────────────────────────────────────────────
# 把跳过行的 `| tee -a <落盘副本>` 换成 `>/dev/null`：段照旧不跑、SKIP_N 照旧 +1、静态检查也看不出来 ——
# 只有 §14d 的「输出里的行数 = 跳过段数」能抓住它。这一条证明那行输出是承重的，不是装饰。
VT="$(vary_tree skip-line)"
mut_pipe() { # <原样> <换成> —— 只改 scratch 副本里那一处（两个方向都先证明落地）
  python3 - "$VT/skills/teamsmith/tests/smoke.sh" "$1" "$2" <<'PYMUT'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
assert s.count(old) == 1, '要改的那一处不是唯一（形状变了，夹具要跟着改）：%s' % old
open(p, 'w', encoding='utf-8').write(s.replace(old, new))
PYMUT
}
mut_pipe '| tee -a "$META_SKIP_LOG"' '>/dev/null'
run_p410_selection "$VT" "$TMP/skip-line.log" 0e,14d; rc=$?
if [ "$rc" -ne 0 ] && grep -q '每段按频率跳过都打了一行显式理由' "$TMP/skip-line.log" \
   && grep -q '期望 \[1\]，实际 \[0\]' "$TMP/skip-line.log"; then
  ok "④ skip-line：跳过行不进输出 → 运行时 §14d 红（输出行数 0 ≠ 跳过段数 1）"
else
  bad "④ skip-line 没有按名变红（rc=$rc）：$(grep -m1 '✗' "$TMP/skip-line.log" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-160)"
fi
# 归还：同一棵树上把 pipe 放回去 → 那条断言必须绿（证明那条红是它造成的，不是别的现场）。
mut_pipe '"$META_GREEN_RECORD" >/dev/null' '"$META_GREEN_RECORD" | tee -a "$META_SKIP_LOG"'
run_p410_selection "$VT" "$TMP/skip-line-restored.log" 0e,14d; rc=$?
if [ "$rc" -eq 0 ] && grep -q '每段按频率跳过都打了一行显式理由' "$TMP/skip-line-restored.log"; then
  ok "④ skip-line 对照：pipe 放回去 → 同一棵树、同一条断言绿（那条红确实由它产生）"
else
  bad "④ skip-line 对照没有变绿（rc=$rc）：$(grep -m1 '✗' "$TMP/skip-line-restored.log" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-160)"
fi

# ── ⑤ 元套件绿记录：年龄与内容两个字段都必须判（PM 2026-11-04 追加）──────────────────────────
# 「最近一次绿记录」如果只是一行文字，夜里那条连续失败一周也没人看见。四条臂各改坏一处，§14d 必须点名：
#   ⑤a 超期（8 天 > 7 天）；⑤b 段数与日志对不上；⑤c 总耗时读不出来（0）；⑤d 只有 RED 没有 GREEN。
arm5_case() { # <名字> <期望在日志里看到的片段> <改坏的命令…>
  local name="$1" want="$2"; shift 2
  local vt; vt="$(vary_tree "rec-$name")"
  "$@" "$vt"
  run_p410_selection "$vt" "$TMP/rec-$name.log"; local r=$?
  if [ "$r" -ne 0 ] && grep -q 'P410 元套件记录' "$TMP/rec-$name.log" \
     && grep -q -- "$want" "$TMP/rec-$name.log"; then
    ok "⑤$name：$want → §14d 红并点名（绿记录的两个字段都判）"
  else
    bad "⑤$name 没有按名变红（rc=$r）：$(grep -m1 'P410 元套件记录' "$TMP/rec-$name.log" | sed 's/^ *//' | cut -c1-150)"
  fi
}
seed_stale()          { seed_record "$1" "$(date -u -d '8 days ago' +%Y-%m-%dT%H:%M:%SZ)"; }
seed_lying_sections() { seed_record "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 3 2; }
seed_zero_total()     { seed_record "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2 2; sed -i 's/\t120\t/\t0\t/' "$1/.pi/team/state/meta-suite/history.tsv"; }
seed_red_only()       { seed_record "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2 2 RED; }
seed_no_judge()       { seed_record "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2 2 GREEN ''; }   # 第 7 列空 = 没有出处
arm5_case stale '> 7 天' seed_stale
arm5_case secs '记录与日志不一致' seed_lying_sections
arm5_case total '总耗时读不出来' seed_zero_total
arm5_case redonly '没有本项目的 GREEN 记录' seed_red_only
arm5_case nojudge '判据 sha 读不出来' seed_no_judge
# 对照：合法记录必须绿（证明上面四条红都由那两个字段产生，不是「有记录就红」）。
VT_OK="$(vary_tree rec-ok)"; seed_record "$VT_OK"
run_p410_selection "$VT_OK" "$TMP/rec-ok.log"; rc=$?
if [ "$rc" -eq 0 ] && grep -q 'P410 元套件记录：最近一条 GREEN' "$TMP/rec-ok.log"; then
  ok "⑤对照：合法记录（7 天内、段数与日志一致、总耗时 120s）→ §14d 绿"
else
  bad "⑤对照没有变绿（rc=$rc）：$(grep -m1 'P410 元套件记录' "$TMP/rec-ok.log" | sed 's/^ *//' | cut -c1-150)"
fi

printf '\n== flip-p410 == ok %d bad %d\n' "$OK" "$BAD"
[ "$BAD" -eq 0 ] || exit 1
exit 0
