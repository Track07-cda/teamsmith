#!/usr/bin/env bash
# flip-p287-name.sh — P287「命名面」的翻转夹具（change: gate-lock-external-deletion）
#
#   bash skills/teamsmith/tests/flip-p287-name.sh [--keep]
#   bash skills/teamsmith/tests/flip-p287-name.sh --break=<stage>   # 只为红侧证据把判定换回旧形状（见下）
#
# 四条腿：
#   leg0 green   ：私有临时根下跑一套夹具运行（真入口），把它**为自己**直接创建的条目逐条点名：
#                  每个都点开头或带**运行自己写下的 ns**（发布锁路径是唯一的例外 —— 「兼容声明」那条
#                  要求管它，断言里显式排除并点名）；契约点名的那条平铺形状（`teamsmith-smoke.*`，
#                  事故命令的射程）对这些条目零命中。
#   leg1 shadow  ：同一条腿换成被测树自己的翻转开关 `TMP_ROOT_BREAK=flat-name`（根回到平铺名）
#                  → 契约那条形状必须被命中，且那条目不满足命名规则 → leg0 那两条断言必红
#                  （证明它判的是命名规则，不是某一条具体命令）。
#   leg2 lint    ：`--lint` 的两份副本 —— ①写死 `/tmp`；②家族前缀在、但丢了本项目的 ns —— 各必须
#                  红且点名 file:line；还原成合式后必须绿。
#   leg3 shape   ：命名判据的三条定名臂（正/反/反）：①契约那条平铺旧名必须判平铺；②③带 ns 的合法名
#                  必须判合法 —— 两条臂只差项目名里的 `_`，②（项目名不含 `_`）正是 V53-F1 的现场。
#
# 判据来自命名规则本身（V53-F1）：**平铺 ⇔ 不是点开头、也不带运行自己的 ns**；不猜「家族正则」——
# ns 是 `<slug>-<hash8>`，slug 允许 `-`/`_`/字母数字，一条「中间段随便吃」的正则必然把 `<kind>-<ns>`
# 也吃进去：改动前那条 `^(teamsmith|review)-[a-z0-9-]*\.[A-Za-z0-9]{6}$` 在项目名不含 `_` 时把**合法根**
# `teamsmith-smoke-cand-<hash8>.<rand>` 判成平铺名（同一个交付物里 34c 段用的却是契约那条
# `teamsmith-smoke.*`；`--break=flat-regex` 把那条旧正则装回来，红侧就是它）。
# 「运行自己的 ns」取自**运行自己写的台账头**（`… ns=<ns>`），并与本夹具算的 ns 对照：两者必须同源 ——
# smoke.sh 自己 unset TEAM_PROJECT（第 58 行），运行的 ns 一律由检出路径推出，所以本夹具算 ns 时也不认
# 调用者环境里的 TEAM_PROJECT（否则父进程一个 ns、子运行另一个 ns，判定就没有参照了）。
#
# 红侧（`--break=`，只作用于本夹具的判定：不改被测树，也不改任何产品行为）：
#   never-flat —— 平铺判定永不成立：leg1 与 leg3① 必须因此变红（那两条臂有牙）。
#   flat-regex —— 平铺判定换回改动前那条过宽的家族正则：leg3② 必须因此变红（F1 的现场）。
#
# 判绿规则：leg0 全绿、leg1/leg2/leg3 各按预期。全绿 exit 0；任何一条没按预期 → exit 1。
# 只写自己的临时根（`${TMPDIR:-/tmp}` 下，点开头或带 ns），只碰自己的私有锁与私有临时根；
# 绝不碰机器锁（`TEAM_SMOKE_LOCK` 一律显式指向私有路径）。
set -uo pipefail

FLIP_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP=0; FLIP_BREAK=""
# 参数：`--self-test`（= 跑全部腿；任务书的验收行）/ `--keep`（留现场）/ `--break=<stage>` /
#       `<树>`（指定被测树）
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) shift ;;
    --keep)      KEEP=1; shift ;;
    --break=*)   FLIP_BREAK="${1#--break=}"; shift ;;
    "")          shift ;;
    *)           FLIP_SKILL="$(cd "$1" 2>/dev/null && pwd)" \
                   || { printf 'flip-p287-name: 树不存在：%s\n' "$1" >&2; exit 2; }
                 shift ;;
  esac
done
case "$FLIP_BREAK" in
  ""|never-flat|flat-regex) ;;
  *) printf 'flip-p287-name: 未知的 --break=%s（只认 never-flat / flat-regex）\n' "$FLIP_BREAK" >&2; exit 2 ;;
esac

# ns 的唯一实现在被测树的 scripts/lib/common.sh（本文件也要给自己起带 ns 的名字）
if ! declare -F team_project_ns >/dev/null 2>&1; then
  # shellcheck source=../scripts/lib/common.sh
  . "$FLIP_SKILL/scripts/lib/common.sh" 2>/dev/null \
    || { printf 'flip-p287-name: 找不到 %s/scripts/lib/common.sh（skill 树不全）\n' "$FLIP_SKILL" >&2; exit 2; }
fi
# 本夹具算的 ns 必须与**嵌套运行实际用的那个**同源：`TEAM_PROJECT=`（空）让 team_project_ns 走
# 「检出路径」那条路 —— smoke.sh 自己 unset TEAM_PROJECT，运行的 ns 也一律由检出路径推出。
p287n_ns_path() { TEAM_PROJECT= team_project_ns 2>/dev/null || printf 'nosig-00000000'; }
# 同一个实现、指定项目名（leg3 的 ②③ 两臂用：只换 slug，不复制 ns 的形状假设）
p287n_ns_slug() { TEAM_PROJECT="$1" team_project_ns 2>/dev/null || printf 'nosig-00000000'; }
NS="$(p287n_ns_path)"
BASE="$(team_tmp_root)"
OUT="$(mktemp -d "$BASE/.teamsmith-p287flip-name-$NS.XXXXXX")" || exit 2
FLIP_RC=0
note()      { printf '%s\n' "$*"; }
line_ok()   { note "  ✓ $*"; }
line_bad()  { note "  ✗ $*"; FLIP_RC=1; }

# 唯一被排除的条目：发布锁路径（它的丢失只印不停，由 P287 的另一条要求管）
PUB_LOCK="teamsmith-smoke.lock"
# 契约点名的那条平铺形状（事故命令的射程）：前缀 + 点 —— 带 ns 的名字里点前面还有 `-<ns>`，够不着。
# 这条 glob 是承重的：它与 34c 段「平铺家族模式（teamsmith-smoke.*）零命中」同口径；但它**不**承担
# 「判平铺」的全部语义（那由命名规则负责，见 p287n_is_flat），只负责钉住事故那条射程。
p287n_contract_hit() { # <条目名> → 0 = 落在事故那条射程里
  case "$1" in teamsmith-smoke.*) return 0 ;; *) return 1 ;; esac
}
# 平铺判定 = 命名规则本身：不是点开头、也不带参照 ns。`--break=` 只把这条换回旧形状（红侧证据）。
p287n_is_flat() { # <条目名> <参照 ns> → 0 = 平铺旧形状
  local name="$1" ns="${2:-$NS}"
  case "$FLIP_BREAK" in
    never-flat) return 1 ;;   # 红侧：判定永不判平铺（腿得有牙才看得出）
    flat-regex)               # 红侧：改动前那条过宽的家族正则 —— 项目名不含 `_` 时吃掉整个 ns 段
      case "$name" in .*) return 1 ;; esac
      [[ "$name" =~ ^(teamsmith|review)-[a-z0-9-]*\.[A-Za-z0-9]{6}$ ]] && return 0
      return 1 ;;
  esac
  case "$name" in .*) return 1 ;; esac
  [ -n "$ns" ] || return 0    # 没有参照 ns：fail-closed（判平铺），绝不当成「合规」
  case "$name" in *"$ns"*) return 1 ;; esac
  return 0
}

# 一套夹具运行：私有 TMPDIR + 私有锁；边跑边把临时根里的条目收进 watch 文件
p287n_run() { # <tmpdir> <日志> [<break 值>]
  local td="$1" log="$2" brk="${3:-}" b=() watch ledger leg
  # 注意：同一个 local 语句里后面的变量不能引用前面刚赋的（left-to-right 求值时还没赋值）
  leg="$(basename "${log%.log}")"
  watch="$OUT/watch-$leg.txt"; ledger="$OUT/ledger-$leg.txt"
  [ -n "$brk" ] && b=(TMP_ROOT_BREAK="$brk")
  : > "$watch"
  ( cd "$td" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SMOKE_LOCK \
      -u TEAM_SMOKE_LOCK_WAIT -u TEAM_SMOKE_BREAK -u TEAM_SMOKE_FAST -u TEAM_SMOKE_NO_LOCK \
      -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED -u SMOKE_LOCK_MARKER -u SMOKE_LOCK \
      -u TMP_ROOT_BREAK -u TMP_ROOT_NS \
      TMPDIR="$td" TEAM_SMOKE_LOCK="$td/$PUB_LOCK" TEAM_SMOKE_FIXTURE=1 ${b[@]+"${b[@]}"} \
      bash "$FLIP_SKILL/tests/smoke.sh" --select 0b,0c ) >"$log" 2>&1 &
  local pid=$! i
  for i in $(seq 1 600); do
    kill -0 "$pid" 2>/dev/null || break
    for e in "$td"/* "$td"/.[!.]*; do
      [ -e "$e" ] || continue
      printf '%s\n' "${e##*/}" >>"$watch"
      # 运行自己写的台账头（带 ns=）在**主人活着时**抓一次：干净收尾会把它们一起收走
      case "${e##*/}" in
        .teamsmith-tmp-ledger.*) [ -s "$ledger" ] || head -1 "$e" >"$ledger" 2>/dev/null || true ;;
      esac
    done
    sleep 0.05
  done
  wait "$pid"
}
p287n_entries() { sort -u "$1" | grep -v '^$' || true; }
# 该腿运行**自己写下**的 ns（台账头 `# teamsmith temp ledger run=… repo=… ns=<ns>`）；读不到 → 非 0
p287n_leg_ns() { # <腿名>
  local f="$OUT/ledger-$1.txt"
  [ -s "$f" ] || return 1
  sed -n 's/.* ns=//p' "$f" | head -1
}
# 条目判定（leg0/leg1 的唯一实现）：点开头或带参照 ns = 合规；否则就是平铺旧形状。打印 BAD 条数。
p287n_classify() { # <watch 文件> <参照 ns> <审计文件>
  local w="$1" ns="$2" out="$3" name bad=0
  : > "$out"
  # 去重后再判：watch 文件是**轮询**攒的，同一个条目会出现很多次（display 用的 p287n_entries 也一样）
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$name" = "$PUB_LOCK" ]; then
      printf 'EXCLUDE %s（发布锁路径：兼容声明，由另一条要求管）\n' "$name" >>"$out"
      continue
    fi
    if p287n_is_flat "$name" "$ns"; then
      printf 'BAD %s ← 既不点开头、也不带 ns %s（平铺旧形状）\n' "$name" "$ns" >>"$out"
      bad=$((bad + 1))
    else
      printf 'OK  %s\n' "$name" >>"$out"
    fi
  done < <(p287n_entries "$w")
  printf '%s\n' "$bad"
}

note "== leg0 green：私有临时根里，每个条目点开头或带 ns =="
TD0="$BASE/.teamsmith-p287n0-$$"; rm -rf "$TD0"; mkdir -p "$TD0"
p287n_run "$TD0" "$OUT/leg0.log"
ENTRIES="$(p287n_entries "$OUT/watch-leg0.txt")"
[ -n "$ENTRIES" ] && line_ok "收到临时根里的条目：$(printf '%s' "$ENTRIES" | tr '\n' ' ')" \
  || line_bad "临时根里一个条目都没收到（夹具没跑起来？）"
# 参照 ns = 运行自己写的那个；读不到或不一致都算红（判绿不许建立在假设的 ns 上）
NS0="$(p287n_leg_ns leg0)" || NS0=""
if [ -z "$NS0" ]; then
  line_bad "leg0：读不到运行自己写的 ns（台账头 $OUT/ledger-leg0.txt）—— 判定没有参照"
elif [ "$NS0" != "$NS" ]; then
  line_bad "leg0：运行自己写的 ns（$NS0）与本夹具算的（$NS）不同源 —— 参照必须是运行自己写的那个"
else
  line_ok "leg0：运行自己写的 ns 与本夹具算的一致（$NS0）"
fi
BAD0="$(p287n_classify "$OUT/watch-leg0.txt" "$NS0" "$OUT/leg0.txt")"
if [ "${BAD0:-x}" != "0" ]; then
  line_bad "leg0：有条目不合规（${BAD0:-?} 条）—— 见 $OUT/leg0.txt"
  sed 's/^/      /' "$OUT/leg0.txt" | grep '^      BAD' | head -5
else
  line_ok "leg0：全部条目点开头或带 ns（$(grep -c '^OK ' "$OUT/leg0.txt") 条）"
fi
# 契约那条形状（事故命令的射程）零命中 —— 与 34c 段同一条断言口径（发布锁路径是显式例外）
FLAT0="$(printf '%s\n' "$ENTRIES" | grep -vxF -- "$PUB_LOCK" | grep -E '^teamsmith-smoke\.' || true)"
[ -z "$FLAT0" ] && line_ok "leg0：契约那条平铺形状（teamsmith-smoke.*）零命中" \
  || line_bad "leg0：契约平铺形状命中：$(printf '%s' "$FLAT0" | tr '\n' ' ')"
if [ -n "$NS0" ] && grep -q "^OK .*teamsmith-.*$NS0\..*" "$OUT/leg0.txt"; then
  line_ok "leg0：至少一个条目是带 ns 的 owned 根（名字里有 -$NS0.）"
else
  line_bad "leg0：没有收到带 ns 的根（名字里找不到 -$NS0.）"
fi

note "== leg1 shadow：TMP_ROOT_BREAK=flat-name（根回到平铺名）→ 契约那条形状必须命中 =="
TD1="$BASE/.teamsmith-p287n1-$$"; rm -rf "$TD1"; mkdir -p "$TD1"
p287n_run "$TD1" "$OUT/leg1.log" flat-name
ENTRIES1="$(p287n_entries "$OUT/watch-leg1.txt")"
NS1="$(p287n_leg_ns leg1)" || NS1=""
[ -n "$NS1" ] && [ "$NS1" = "$NS" ] \
  || line_bad "leg1：运行自己写的 ns 读不到或不一致（[$NS1] vs [$NS]）"
BAD1="$(p287n_classify "$OUT/watch-leg1.txt" "$NS1" "$OUT/leg1.txt")"
# 契约那条形状里的条目（发布锁路径是显式例外，与 leg0 同口径）
CONTRACT1="$(printf '%s\n' "$ENTRIES1" | grep -vxF -- "$PUB_LOCK" | grep -E '^teamsmith-smoke\.' || true)"
if [ -n "$CONTRACT1" ] && [ "${BAD1:-0}" != "0" ]; then
  line_ok "leg1：shadow 下 $(printf '%s' "$CONTRACT1" | tr '\n' ' ') 命中契约形状，且它不满足命名规则（判的是命名规则）"
else
  line_bad "leg1：shadow 下契约形状零命中 / 没有不合规条目（contract=[$CONTRACT1] bad=${BAD1:-?}）—— 那条断言判不出「根回到平铺名」"
fi

note "== leg2 lint：写死 /tmp 与「家族前缀在、ns 丢了」两份副本各必须红，合式必须绿 =="
# 红侧素材放在 fixtures/p287/*.sh.in（不是 .sh，所以它们不在扫描面里）：本夹具把它们**拷进副本树**再扫
# —— 这样「坏模板」只存在于临时副本里，不会让 `--lint` 对被测树自己报警，也不削弱那条规则。
for shape in hardcoded no-ns good; do
  C="$OUT/lint-$shape"; mkdir -p "$C/lib"
  IN="$FLIP_SKILL/tests/fixtures/p287/lint-$shape.sh.in"
  if [ ! -f "$IN" ]; then printf 'flip-p287-name: 缺红侧素材 %s\n' "$IN" >&2; FLIP_RC=1; continue; fi
  case "$shape" in
    good) sed "s/@NS@/$NS/" "$IN" > "$C/lib/a.sh" ;;
    *)    cp "$IN" "$C/lib/a.sh" ;;
  esac
  rc=0
  # `env -u TEAM_PROJECT`：`--lint` 的参照 ns 与运行的 ns 同源（检出路径），调用者环境不许漂移它
  env -u TEAM_PROJECT bash "$FLIP_SKILL/tests/tmp-hygiene.sh" --lint --dir "$C" >"$OUT/lint-$shape.log" 2>&1 || rc=$?
  printf '%s\n' "$rc" >"$OUT/lint-$shape.rc"
done
if [ "$(cat "$OUT/lint-hardcoded.rc")" != "0" ] && grep -qE 'a\.sh:[0-9]+' "$OUT/lint-hardcoded.log"; then
  line_ok "leg2①：写死 /tmp 的副本红且点名 file:line（$(grep -E -m1 'a\.sh:[0-9]+' "$OUT/lint-hardcoded.log" | sed 's/^ *//')）"
else
  line_bad "leg2①：写死 /tmp 的副本没有红 / 没点名（rc=$(cat "$OUT/lint-hardcoded.rc")）"
fi
if [ "$(cat "$OUT/lint-no-ns.rc")" != "0" ] && grep -q '命名空间' "$OUT/lint-no-ns.log"; then
  line_ok "leg2②：家族前缀在、丢了 ns 的副本红并点名命名空间（$(grep -E -m1 'a\.sh:[0-9]+' "$OUT/lint-no-ns.log" | sed 's/^ *//')）"
else
  line_bad "leg2②：丢了 ns 的副本没有红 / 没点名命名空间（rc=$(cat "$OUT/lint-no-ns.rc")）"
fi
if [ "$(cat "$OUT/lint-good.rc")" = "0" ]; then
  line_ok "leg2③：合式（点开头/带 ns）绿"
else
  line_bad "leg2③：合式副本被误判红（见 $OUT/lint-good.log）"
fi

note "== leg3 shape：①契约平铺旧名必须判平铺；②③带 ns 的合法名（项目名不含/含 \`_\`）必须判合法 =="
# 两条臂的 ns 都由**同一个** team_project_ns 生成，只换项目名（slug）—— 不复制它的形状假设。
NS_A="$(p287n_ns_slug cand)"    # 项目名不含 `_`：②是 V53-F1 的现场
NS_B="$(p287n_ns_slug can_d)"   # 项目名含 `_`：③是改动前恰好绿的那个方向
case "$NS_A" in
  *_*) line_bad "leg3：臂②的项目名没有兑现「不含 \`_\`」（ns=$NS_A）—— 那条臂就不算 F1 的现场了" ;;
  *)   line_ok  "leg3：臂②的 ns 里没有 \`_\`（ns=$NS_A，项目名不含 \`_\`）" ;;
esac
case "$NS_B" in
  *_*) line_ok  "leg3：臂③的 ns 里有 \`_\`（ns=$NS_B，项目名含 \`_\`）" ;;
  *)   line_bad "leg3：臂③的项目名没有兑现「含 \`_\`」（ns=$NS_B）—— 那个方向没被覆盖" ;;
esac
p287n_arm() { # <臂说明> <条目名> <期望 flat|named> <参照 ns>
  local what="$1" name="$2" want="$3" ns="$4" got
  if p287n_is_flat "$name" "$ns"; then got=flat; else got=named; fi
  if [ "$got" = "$want" ]; then
    line_ok "$what：$name → 判「$( [ "$want" = flat ] && printf '平铺' || printf '合法' )」（期望）"
  else
    line_bad "$what：$name → 期望 $want、实得 $got（判据与命名规则不一致）"
  fi
}
p287n_arm "leg3①：契约那条平铺旧名" "teamsmith-smoke.Ab3xY9" flat "$NS"
p287n_arm "leg3②：带 ns 的合法名（项目名不含 \`_\`）" "teamsmith-smoke-$NS_A.Ab3xY9" named "$NS_A"
p287n_arm "leg3③：带 ns 的合法名（项目名含 \`_\`）" "teamsmith-smoke-$NS_B.Ab3xY9" named "$NS_B"
# 契约那条 glob 与命名判定必须一致：命中事故射程的只有①（②③是带 ns 的合法名，够不着那条 glob）
p287n_contract_hit "teamsmith-smoke.Ab3xY9" \
  && line_ok "leg3：①落在契约那条形状的射程里（teamsmith-smoke.*）" \
  || line_bad "leg3：①不在契约那条形状的射程里 —— 臂本身选错了"
if p287n_contract_hit "teamsmith-smoke-$NS_A.Ab3xY9" || p287n_contract_hit "teamsmith-smoke-$NS_B.Ab3xY9"; then
  line_bad "leg3：②/③这种带 ns 的合法名命中了契约那条形状的射程 —— 两套判据互相矛盾"
else
  line_ok "leg3：②/③都够不着契约那条形状的射程"
fi

note ""
if [ "$FLIP_RC" = "0" ]; then
  note "FLIP 全绿：leg0 全绿 + shadow/lint/shape 三条腿各按预期（证据：$OUT）"
else
  note "FLIP 有未达预期的腿（证据：$OUT）"
fi
[ "$KEEP" = "1" ] || { rm -rf "$TD0" "$TD1" 2>/dev/null || true; }
exit "$FLIP_RC"
