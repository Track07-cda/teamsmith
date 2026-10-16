#!/usr/bin/env bash
# flip-p287-lock.sh — P287「身份面」的翻转夹具（change: gate-lock-external-deletion）
#
#   bash skills/teamsmith/tests/flip-p287-lock.sh [--keep]
#   TEAM_FLIP_PRE287=<rev> bash skills/teamsmith/tests/flip-p287-lock.sh   # 直接指定「改动前」的 revision
#   TEAM_FLIP_PRE287_LANDED=<rev> …   # 改「记录在案的落地提交」（默认 6f1ed69d = P288 的落地提交）
#   TEAM_FLIP_BREAK=pipefail-probe|main-baseline bash … --self-test    # leg2 的两条红侧（见下）
#
# 三条腿（全部用**私有 `TEAM_SMOKE_LOCK` + 私有 `TMPDIR` + TEAM_SMOKE_FIXTURE=1`**，绝不碰机器锁）：
#   leg0 green ：持有者（真入口）在跑，从外面 `rm` 伴生锁 → 有界时间内**一行**点名「已不在」+ 证据文件
#                里记着期望/实测身份 + 安全点停跑（退出码 2）+ **没有**结果行。
#   leg1 shadow：同一条腿换成被测树自己的翻转开关 `TEAM_SMOKE_BREAK=no-lock-guard`（只在
#                TEAM_SMOKE_FIXTURE=1 下生效）→ 同一场景**不点名、不停跑**（有结果行、退出码 0）
#                —— 这正是「改动前形状」，证明 leg0 的绿不是橡皮章。
#   leg2 pre   ：改动前的树（从**记录在案的落地提交** 6f1ed69d 往回找第一个没有 `gate_lock_companion_path`
#                的提交 —— 不是从 `main` 的移动 tip）上做同一件事 → 同样不点名、不停跑（那时互斥在
#                发布路径上，删伴生锁无从谈起）。选中之后还要断言那棵树**确实**是改动前。
#   leg2 红侧：① `TEAM_FLIP_BREAK=old-probe` —— 旧写法（`git show … | grep -q` 在 `set -o pipefail` 下
#                命中即退 → git 吃 SIGPIPE → 管道非 0 ⇒ 被当成「不含伴生锁」）的**判定**：把第一个候选
#                当成改动前。这条红侧同时**测量**旧写法那一步的管道 rc（它是竞态：见下面的说明）；
#                ② `TEAM_FLIP_BREAK=main-baseline` —— 基线指回 `main` 的 tip 直接当结论（旧形状不回溯；
#                合并前它恰好「真空通过」）。两条都必须让这条腿红。
#
# 判绿规则：三条腿都按预期。全绿 exit 0；任何一条没按预期 → exit 1。只写自己的临时根。
set -uo pipefail

FLIP_SKILL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(git -C "$FLIP_SKILL" rev-parse --show-toplevel 2>/dev/null || true)"
KEEP=0
# 参数：`--self-test`（= 跑全部腿；任务书的验收行）/ `--keep`（留现场）/ `<树>`（指定被测树）
case "${1:-}" in
  --self-test) shift ;;
  --keep)      KEEP=1; shift ;;
  "")          ;;
  *)           FLIP_SKILL="$(cd "$1" && pwd)"; shift ;;
esac
[ "${1:-}" = "--keep" ] && KEEP=1

if ! declare -F team_project_ns >/dev/null 2>&1; then
  # shellcheck source=../scripts/lib/common.sh
  . "$FLIP_SKILL/scripts/lib/common.sh" 2>/dev/null \
    || { printf 'flip-p287-lock: 找不到 %s/scripts/lib/common.sh（skill 树不全）\n' "$FLIP_SKILL" >&2; exit 2; }
fi
NS="$(team_project_ns 2>/dev/null || printf 'nosig-00000000')"
# 场景函数要用 gate_lock_companion_path（伴生锁路径的唯一实现）—— 与本文件其余部分同一份库
# shellcheck source=../scripts/lib/gate-lock.sh
. "$FLIP_SKILL/scripts/lib/gate-lock.sh" 2>/dev/null \
  || { printf 'flip-p287-lock: 找不到 %s/scripts/lib/gate-lock.sh\n' "$FLIP_SKILL" >&2; exit 2; }
BASE="${TMPDIR:-/tmp}"
ROOT="$(mktemp -d "$BASE/.teamsmith-p287flip-lock-$NS.XXXXXX")" || exit 2
FLIP_RC=0
note()     { printf '%s\n' "$*"; }
line_ok()  { note "  ✓ $*"; }
line_bad() { note "  ✗ $*"; FLIP_RC=1; }

WAIT_SECS=5   # 「有界」的上限：守卫节奏 0.2s + 安全点；夹具轮询到上限再判红（不固定 sleep）
# 场景目录（也就是嵌套运行的 $TMPDIR）放**临时根顶层**的短名字：tmux 私有 socket 有 AF_UNIX 上限，
# 套在证据目录（$ROOT）里会超 —— 那时 0c 的隔离前置会拒绝执行（exit 2），红的是环境不是产品。
p287l_scene() { printf '%s/.teamsmith-p287l-%s-%s' "${TMPDIR:-/tmp}" "$1" "$$"; }

# 一套夹具运行：私有 TMPDIR + 私有锁；可选删除伴生锁 / 翻转开关
p287l_run() { # <技能树> <场景目录> <日志> <rm|none> <break 值> <退出码文件>
  local skill="$1" td="$2" log="$3" action="$4" brk="${5:-}" rcf="$6"
  local b=() rc=0
  [ -n "$brk" ] && b=(TEAM_SMOKE_BREAK="$brk")
  rm -rf "$td"; mkdir -p "$td"
  ( cd "$td" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SMOKE_LOCK \
      -u TEAM_SMOKE_LOCK_WAIT -u TEAM_SMOKE_FAST -u TEAM_SMOKE_NO_LOCK -u SMOKE_LOCK_WRAPPED \
      -u SMOKE_LOCK_QUEUED -u SMOKE_LOCK_MARKER -u SMOKE_LOCK \
      TMPDIR="$td" TEAM_SMOKE_LOCK="$td/teamsmith-smoke.lock" TEAM_SMOKE_FIXTURE=1 ${b[@]+"${b[@]}"} \
      bash "$skill/tests/smoke.sh" --select 3 ) >"$log" 2>&1 &
  local pid=$! i comp="$td/.teamsmith-smoke.lock.machine"
  # 等持有者真起来（伴生锁记录出现 = 两把锁都拿到了）+ 段落 #3 开跑（现场是「运行中」）
  for i in $(seq 1 200); do
    if [ -s "$comp.holder" ] && grep -aq '== #3' "$log" 2>/dev/null; then break; fi
    sleep 0.05
  done
  # 夹具自检：这一套必须用**私有锁**（落到机器锁上就正是这条变更要消灭的失败模式）
  if grep -aq "$td/teamsmith-smoke.lock" "$log" 2>/dev/null || grep -aq "持有 $td/teamsmith-smoke.lock" "$log" 2>/dev/null; then
    printf 'private-lock=ok\n' >"$rcf.lockcheck"
  else
    printf 'private-lock=MISSING（它用了机器锁？日志：%s）\n' "$(grep -am1 '全量门禁互斥' "$log" 2>/dev/null | sed 's/^ *//')" >"$rcf.lockcheck"
  fi
  if [ "$action" = "rm" ]; then rm -f "$comp"; fi
  wait "$pid" || rc=$?
  printf '%s\n' "$rc" >"$rcf"
}
p287l_wait_line() { # <文件> <模式> [<秒>]
  local f="$1" pat="$2" lim="${3:-$WAIT_SECS}" n i
  n=$(( lim * 20 ))
  for i in $(seq 1 "$n"); do
    grep -aqE "$pat" "$f" 2>/dev/null && return 0
    sleep 0.05
  done
  return 1
}

# 一套「review 的门禁跑着的时候锁被删掉」场景：<场景目录> <记录目录> <日志> [<技能树>]
#   退出 0 = review 判 PASS（无复核的形状）；非 0 = review 判 FAIL（有复核的形状）。
p287l_review_scenario() {
  local td="$1" out="$2" log="$3" skill="${4:-$FLIP_SKILL}"
  local lock="$td/lock" cmp; cmp="$(gate_lock_companion_path "$lock")"
  rm -rf "$td" "$out"; mkdir -p "$td/repo" "$out"
  ( cd "$td/repo" && git init -q -b main && git config user.email flip@teamsmith && git config user.name flip \
    && echo "# flip" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
  local run_review
  run_review() { ( cd "$td/repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_GATES -u TEAM_SMOKE_LOCK -u TEAM_SMOKE_LOCK_WAIT -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED \
      -u SMOKE_LOCK_MARKER -u SMOKE_LOCK -u SMOKE_LOCK_CLAIMER_PID -u SMOKE_LOCK_CLAIMER_IDENTITY \
      -u SMOKE_LOCK_CLAIMER_DEV_INO "$@" ); }
  run_review bash "$skill/scripts/team" init --session "flip-p287l-$$" --agents "dev verify" --vcs local \
    --gates "true" --docs docs/team \
    --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
    --pm-model 'deepseek/deepseek-flash' >"$out/init.log" 2>&1 || return 9
  mkdir -p "$td/repo/docs/team/reports" "$td/repo/docs/team/reviews"
  printf '# T7 · 夹具报告\n\nagent: dev\n' > "$td/repo/docs/team/reports/T7-dev.md"
  run_review TEAM_SMOKE_LOCK="$lock" TEAM_SMOKE_LOCK_WAIT=5 TEAM_GATES='sleep 10' TEAM_REVIEW_TIMEOUT=60 \
    TEAM_REVIEW_ALLOW_DIRTY=1 TEAM_REVIEW_ALLOW_IGNORED=1 \
    bash "$skill/scripts/team" review T7 --dir "$td/repo" --branch main >"$log" 2>&1 &
  local pid=$! i
  for i in $(seq 1 600); do [ -s "$cmp.holder" ] && break; sleep 0.1; done
  [ -s "$cmp.holder" ] || { wait "$pid" 2>/dev/null; return 8; }   # 没拿到锁：场景不成立
  sleep 0.5
  rm -f "$cmp"
  wait "$pid"
  return $?
}
# 判 PASS 的三种证据合一（场景异常时明确说「场景不成立」，不把它读成 FAIL）
p287l_scenario_says_pass() { # <场景目录> <记录目录> <rc> <输出前缀>
  local td="$1" out="$2" rc="$3" tag="$4"
  case "$rc" in 0|1) ;; *) line_bad "$tag：场景不成立（场景函数返回 $rc：没拿到锁 / init 失败）"; return 1 ;; esac
  local rec="$td/repo/docs/team/reviews/T7.md"
  if [ ! -f "$rec" ]; then line_bad "$tag：没有复验记录 $rec"; return 1; fi
  if [ "$rc" = "0" ] && grep -aq '判定: \*\*PASS\*\*' "$rec"; then
    line_ok "$tag：判 PASS（rc=0）—— 该形状下没有东西拦它"
    return 0
  fi
  line_bad "$tag：判的不是 PASS（rc=$rc；记录：$(grep -am1 '判定:' "$rec" | cut -c1-80)）"
  return 1
}

note "== leg0 green：运行中从外面 rm 伴生锁 → 有界时间内一行点名 + 证据 + 停跑（exit 2）=="
p287l_run "$FLIP_SKILL" "$(p287l_scene 0)" "$ROOT/leg0.log" rm "" "$ROOT/leg0.rc"
RC0="$(cat "$ROOT/leg0.rc")"
if [ "$(cat "$ROOT/leg0.rc.lockcheck" 2>/dev/null)" = "private-lock=ok" ]; then
  line_ok "leg0：这一套用的是私有锁（不是机器锁）—— 夹具自身安全的前提"
else
  line_bad "leg0：$(cat "$ROOT/leg0.rc.lockcheck" 2>/dev/null)"
fi
if p287l_wait_line "$ROOT/leg0.log" '伴生锁（运行互斥）已不在'; then
  line_ok "leg0：点名行出现（「伴生锁（运行互斥）已不在」）"
else
  line_bad "leg0：有界时间内没有点名行 —— 守卫没接上或没生效"
fi
assert_grep() { # <文件> <模式> <说明>
  if grep -aqE "$2" "$1" 2>/dev/null; then line_ok "$3"; else line_bad "$3 —— 没找到 [$2]"; fi
}
assert_grep "$ROOT/leg0.log" '互斥是这套运行的.*依据' "leg0：点名行说清了「互斥是全部依据」"
assert_grep "$ROOT/leg0.log" '停跑（exit 2）' "leg0：明说安全点停跑与退出码 2"
assert_grep "$ROOT/leg0.log" '这不是断言失败，也不是对代码的判定' "leg0：明说不是对代码的判定"
assert_grep "$ROOT/leg0.log" '删 TMP 也带不走' "leg0：点名证据文件在 \$TMP 之外"
if grep -aq '== 选段结果 ==' "$ROOT/leg0.log"; then
  line_bad "leg0：还出了结果行 —— 停跑没生效（下游会把它当判定）"
else
  line_ok "leg0：没有结果行（停在安全点）"
fi
if [ "$RC0" = "2" ]; then line_ok "leg0：退出码 2"; else line_bad "leg0：退出码是 $RC0（期望 2）"; fi
# 证据文件落在场景目录（$TMPDIR）里、**运行自己的临时根之外**（删 TMP 带不走的就是它）
DIAG="$(ls -t "$(p287l_scene 0)"/.teamsmith-smoke-diag.*.log 2>/dev/null | head -1 || true)"
if [ -n "$DIAG" ]; then
  line_ok "leg0：证据文件在 \$TMP 之外（${DIAG##*/}）"
  assert_grep "$DIAG" '发布路径（兼容声明）：.*' "leg0：证据里有一节发布路径（兼容声明）"
  assert_grep "$DIAG" '期望身份：lock_identity=fd' "leg0：证据里记着身份的种类（fd）"
  assert_grep "$DIAG" '期望身份：lock_identity=' "leg0：证据里记着期望身份"
  assert_grep "$DIAG" '最后经过的段落：' "leg0：证据里记着最后经过的段落"
else
  line_bad "leg0：找不到证据文件（$ROOT/.teamsmith-smoke-diag.*）"
fi

note "== leg1 shadow：--break=no-lock-guard（关掉守卫）→ 同一场景不点名、不停跑 =="
p287l_run "$FLIP_SKILL" "$(p287l_scene 1)" "$ROOT/leg1.log" rm no-lock-guard "$ROOT/leg1.rc"
RC1="$(cat "$ROOT/leg1.rc")"
if grep -aq '伴生锁（运行互斥）已不在' "$ROOT/leg1.log"; then
  line_bad "leg1：shadow 下还点名了 —— 说明点名不是那条开关管的（绿侧就没有说服力）"
else
  line_ok "leg1：shadow 下不点名（这把开关确实管着那条判据）"
fi
if grep -aq '== 选段结果 ==' "$ROOT/leg1.log"; then
  line_ok "leg1：shadow 下继续跑完（有结果行）—— 这正是「改动前」的形状"
else
  line_bad "leg1：shadow 下没有结果行（它不是「不点名」而是别的原因停的？）"
fi
if [ "$RC1" = "0" ]; then line_ok "leg1：shadow 退出码 0"; else line_bad "leg1：shadow 退出码 $RC1（期望 0）"; fi
assert_grep "$ROOT/leg1.log" '夹具红侧.*no-lock-guard' "leg1：大声说明守卫被关掉（夹具开关不静默）"

note "== leg2 pre：改动前的树上做同一件事（那时没有伴生锁）→ 同样不点名、不停跑 =="
# 探针（P303 的 F1）：**绝不**写成 `git show … | grep -q` —— 本脚本 `set -o pipefail`，grep 命中即退
# → git 吃 SIGPIPE（141）→ 管道整体非 0 → `!` 取反后把**含**变更的树当成「不含」。同族的坑写在
# flip-m33.sh:106；这里的写法是先把 blob 落盘、再 grep 文件（读完整流，不早退）。
p287l_blob_of() { # <rev> → 打印落到 $ROOT 里的 blob 路径；1 = 取不到；2 = 那棵树里没这个文件
  local rev="$1" blob="$ROOT/.leg2-probe.blob"
  [ -n "$REPO_ROOT" ] || return 1
  git -C "$REPO_ROOT" rev-parse --verify -q "$rev" >/dev/null 2>&1 || return 1
  git -C "$REPO_ROOT" cat-file -e "$rev:skills/teamsmith/scripts/lib/gate-lock.sh" 2>/dev/null || return 2
  git -C "$REPO_ROOT" show "$rev:skills/teamsmith/scripts/lib/gate-lock.sh" >"$blob" 2>/dev/null || return 1
  printf '%s\n' "$blob"
}
p287l_has_companion() { # <rev> → 0 = 那棵树**有**伴生锁实现
  local b; b="$(p287l_blob_of "$1")" || return 1
  grep -q 'gate_lock_companion_path' "$b"
}
p287l_lacks_companion() { # <rev> → 0 = 那棵树没有伴生锁实现（文件根本不存在也算）
  local b; b="$(p287l_blob_of "$1")" || { [ "$?" = 2 ] && return 0; return 1; }
  if grep -q 'gate_lock_companion_path' "$b"; then return 1; fi
  return 0
}
p287l_old_shape_rc() { # <rev> → 旧写法那一步的管道 rc（`git show … | grep -q`，本脚本 set -o pipefail）
  local rev="$1" rc=0
  git -C "$REPO_ROOT" show "$rev:skills/teamsmith/scripts/lib/gate-lock.sh" 2>/dev/null | grep -q 'gate_lock_companion_path'; rc=$?
  printf '%s\n' "$rc"
}
# 红侧①：旧写法的**判定**。旧代码把管道非 0 一律当成「不含伴生锁」；而早退的管道在**命中**时也会
# 因为 SIGPIPE 非 0 —— 于是它常常在**第一个候选**上就停住（P303 的 F1）。那一步是竞态（同一个表达式
# 独立测量 60/60 次非 0，而在夹具里跑的那一次是 0：谁先被调度决定 git 有没有把 blob 写完），所以这条
# 红侧复刻的是**判定语义**（非 0 ⇒ 当成改动前 ⇒ 取第一个候选），并把实测到的 rc 打出来当证据。
p287l_old_shape_verdict() { # <rev>
  P287L_OLD_RC="$(p287l_old_shape_rc "$1")"
  return 0
}
PRE="${TEAM_FLIP_PRE287:-}"
# 改动前的落点不是「main 的移动 tip」，而是一个**记录在案**的基线：本 change 的落地提交（P288 = 6f1ed69d，
# tasks.md §0.1 与 P303 报告都记着它）。从它逐级往回，第一个不含伴生锁实现的树就是改动前 —— 合并前
# 「main 恰好不含变更」那种真空通过不再可能：合并后 main 的 tip 含变更，只有真的回溯才能找到那棵树。
P287L_LANDED="${TEAM_FLIP_PRE287_LANDED:-6f1ed69d}"
if [ -z "$PRE" ] && [ -n "$REPO_ROOT" ]; then
  base=""; use_probe=p287l_lacks_companion; no_walk=0
  if git -C "$REPO_ROOT" rev-parse --verify -q "$P287L_LANDED" >/dev/null 2>&1; then
    base="$P287L_LANDED"
  elif git -C "$REPO_ROOT" rev-parse --verify -q main >/dev/null 2>&1; then
    base="main"
    note "  · leg2：落地提交 $P287L_LANDED 不在这个仓库里（历史改写/浅克隆？）→ 退回从 main 往回找"
  fi
  case "${TEAM_FLIP_BREAK:-}" in
    old-probe)
      use_probe=p287l_old_shape_verdict
      P287L_RACE_N=0
      for _t in $(seq 1 20); do [ "$(p287l_old_shape_rc "$base")" != "0" ] && P287L_RACE_N=$((P287L_RACE_N + 1)); done
      note "  · leg2 红侧①：旧写法（git show … | grep -q + pipefail）的判定 = 管道非 0 ⇒ 当成改动前；量 20 次，$P287L_RACE_N 次非 0（竞态：SIGPIPE）" ;;
    main-baseline)
      base="main"; no_walk=1
      note "  · leg2 红侧②：基线指回 main（旧形状：起点 tip 直接当结论，不回溯）" ;;
  esac
  if [ -n "$base" ]; then
    if [ "$no_walk" = "1" ]; then
      PRE="$base"
    else
      for i in $(seq 0 40); do
        rev="$base$( [ "$i" = 0 ] || printf '~%s' "$i" )"
        "$use_probe" "$rev" || continue   # 红侧①恒真：非 0 的判定 ⇒ 第一个候选即结论
        PRE="$rev"
        [ "$use_probe" = "p287l_old_shape_verdict" ] && note "  · leg2 红侧①：旧写法那一步在 $rev 上的管道 rc=${P287L_OLD_RC:-?}（非 0 ⇒ 旧写法把它当成改动前）"
        break
      done
    fi
  fi
fi
# 选中的那棵树必须**确实**是改动前（这条断言就是上面两条红侧能变红的原因）
if [ -n "$PRE" ] && p287l_has_companion "$PRE"; then
  line_bad "leg2：选中的树 $PRE 里**有**伴生锁实现 —— 它不是改动前的树（基线/探测指错了）"
  PRE=""
fi
if [ -z "$PRE" ]; then
  note "  · leg2 停止（没有可用的「改动前」revision —— 用 TEAM_FLIP_PRE287=<rev> 指定；上面若有红，就是它）"
else
  PRESKILL="$ROOT/pre-tree"
  mkdir -p "$PRESKILL"
  if git -C "$REPO_ROOT" archive "$PRE" skills/teamsmith | tar -x -C "$PRESKILL" 2>/dev/null; then
    line_ok "leg2：改动前的树取自 $PRE（$(git -C "$REPO_ROOT" log -1 --format=%h' '%s "$PRE" | cut -c1-60)）"
    if ! p287l_has_companion "$PRE"; then
      line_ok "leg2：那棵树（$PRE）里确实没有 gate_lock_companion_path —— 记录在案的落地提交是 $P287L_LANDED"
    else
      line_bad "leg2：选中树的后置核对失败（$PRE 含伴生锁实现）"
    fi
    if grep -q 'gate_lock_companion_path' "$PRESKILL/skills/teamsmith/scripts/lib/gate-lock.sh" 2>/dev/null; then
      line_bad "leg2：取出的树里**有**伴生锁实现 —— 取错了树（$PRESKILL）"
    else
      line_ok "leg2：取出的树的 gate-lock.sh 里没有伴生锁实现（改动前的形状）"
    fi
    p287l_run "$PRESKILL/skills/teamsmith" "$(p287l_scene 2)" "$ROOT/leg2.log" rm "" "$ROOT/leg2.rc"
    RC2="$(cat "$ROOT/leg2.rc")"
    if grep -aq '伴生锁（运行互斥）' "$ROOT/leg2.log"; then
      line_bad "leg2：改动前的树上也点名了（那时没有伴生锁，应当是静默的）"
    else
      line_ok "leg2：改动前的树不点名（删伴生锁无从谈起）"
    fi
    if grep -aq '== 选段结果 ==' "$ROOT/leg2.log"; then
      line_ok "leg2：改动前的树继续跑完（与 leg1 同形）"
    else
      line_bad "leg2：改动前的树没有结果行（$ROOT/leg2.log）"
    fi
  else
    line_bad "leg2：取不出改动前的树（git archive $PRE skills/teamsmith 失败）"
  fi
fi

note "== leg3 review：调用者侧的复核被拆掉 → 同一现场变 PASS（合同：A review whose gate loses its lock…）=="
# 与 smoke §34d⑦ 同场景、不同树：这里把 `team review` 跑完后的**身份复核**拆掉（`if false`），
# 门禁照样跑、锁照样被外部删掉 —— 没有复核就该判 PASS（红侧），有复核才判 FAIL（绿侧）。
if [ -z "$REPO_ROOT" ]; then
  line_bad "leg3：不在 git 检出里，取不出可复制的最小树"
else
  MT="$ROOT/mutant-tree"; rm -rf "$MT"; mkdir -p "$MT"
  if cp -a "$FLIP_SKILL" "$MT/teamsmith" 2>/dev/null; then
    sed -i 's/if \[ "$queue_state" = "queued" \] && \[ -n "$lock_dev_ino" \]; then/if false; then   # leg3 mutation/' \
      "$MT/teamsmith/scripts/lib/cmd-review.sh"
    if grep -q 'leg3 mutation' "$MT/teamsmith/scripts/lib/cmd-review.sh"; then
      line_ok "leg3：变异树就位（门禁跑完的身份复核被拆掉）"
      RC3=0
      p287l_review_scenario "$(p287l_scene 3)" "$ROOT/leg3-review" "$ROOT/leg3.log" "$MT/teamsmith" || RC3=$?
      p287l_scenario_says_pass "$(p287l_scene 3)" "$ROOT/leg3-review" "$RC3" "leg3（复核被拆掉）" \
        || line_bad "leg3：红侧不成立（同一现场、只因复核没了，应当判 PASS）"
      if grep -aq '互斥在运行期间被破坏' "$(p287l_scene 3)/repo/docs/team/reviews/T7.md" 2>/dev/null; then
        line_bad "leg3：变异树上仍写了「互斥被破坏」——红线不在这条判据上"
      else
        line_ok "leg3：变异树上一字未提互斥（同一现场，只因为复核没了）"
      fi
    else
      line_bad "leg3：变异没生效（sed 没改到复核那一行）"
    fi
  else
    line_bad "leg3：复制不出被测树（$FLIP_SKILL）"
  fi
fi

note ""
if [ "$FLIP_RC" = "0" ]; then
  note "FLIP 全绿：绿侧按预期点名并停跑，两条对照腿各按预期静默（证据：$ROOT）"
else
  note "FLIP 有未达预期的腿（证据：$ROOT）"
fi
[ "$KEEP" = "1" ] || rm -rf "$(p287l_scene 0)" "$(p287l_scene 1)" "$(p287l_scene 2)" 2>/dev/null || true
exit "$FLIP_RC"
