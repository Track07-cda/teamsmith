#!/usr/bin/env bash
# teamsmith 冒烟自测：在 /tmp 的临时 git 仓库里端到端跑一遍全流程，绝不碰当前项目。
#
#   bash tests/smoke.sh [--keep]      # --keep 保留临时目录用于排查
#   TEAM_SMOKE_FAST=1 bash tests/smoke.sh   # 快模式：只跑纯逻辑段落（目标 < 60s）
#
# 覆盖：doctor 负例 → init → 模板渲染 → task/board → add-agent → dispatch(假 pi) →
#      say/notify/inbox/digest → worktree 内提交与报告 → review(PASS/FAIL 两条路径) →
#      merge(squash) → close → roster/ps/status → notify 扩展(Node 直跑，含去重) → teardown
#
# 快慢分层（TEAM_SMOKE_FAST=1）：只跑不依赖「真实 tmux 场地 / 真实 pi 进程」的段落，
#   被跳过的段落一律显式打印 `SKIP（FAST 模式）`（不静默少跑），结尾 14c 再自检
#   「真进程段落一次都没跑 + 预期段落都确实被跳过」。默认（不设该变量）行为与改造前完全一致：
#   断言一条不少、顺序不变、退出码语义不变（有失败→非 0，全绿→0）。
#   注：身份隔离自检（第 2 节）与文档一致性自检（14b）都是纯逻辑，快模式**照跑不跳过**。
set -uo pipefail

SKILL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# P98 · 选段：过滤副本落在临时目录（不在本树），子进程按 BASH_SOURCE 推不出本树 —— 只有「本脚本自己
# spawn 的选段子进程」（SMOKE_SEL_CHILD=1 且指向一棵含 tests/smoke.sh 的树）才认外部指定的树。
# 捕获后**立刻 unset**：这四个变量是给**这一个进程**的标记，绝不能被它的子孙继承 —— 段内夹具（36 段
# 的嵌套 smoke / `--select no-such-section` 负例）若继承标记，会把自己当成选段子进程并**静默跑全套**
# （P98 实测过：过滤副本 → 36 段 → 负例 → 全套 → 36 段 → … 指数发散）。子进程自己的锁重入用命令行
# 前缀显式带回去，不回写环境。
# 注意：上面那行 `^SKILL_DIR=` 的形状是 flip-m12 / flip-m12-26c / flip-m44 用 sed 依赖的，别改成块。
SMOKE_SEL_IS_CHILD=0; SMOKE_SEL_CHILD_DIR=""; SMOKE_SEL_CHILD_DECISION=""; SMOKE_SEL_COPY_PATH=""
if [ "${SMOKE_SEL_CHILD:-0}" = "1" ] && [ -n "${SMOKE_SEL_SKILL_DIR:-}" ] \
   && [ -f "${SMOKE_SEL_SKILL_DIR}/tests/smoke.sh" ]; then
  SKILL_DIR="$SMOKE_SEL_SKILL_DIR"
  SMOKE_SEL_IS_CHILD=1; SMOKE_SEL_CHILD_DIR="$SKILL_DIR"
  SMOKE_SEL_CHILD_DECISION="${SMOKE_SEL_DECISION:-RUN}"
  SMOKE_SEL_COPY_PATH="${SMOKE_SEL_COPY:-}"
  unset SMOKE_SEL_CHILD SMOKE_SEL_SKILL_DIR SMOKE_SEL_DECISION SMOKE_SEL_COPY 2>/dev/null || true
fi
# P16：初始化指引是兄弟 skill（本仓库 skills/teamsmith-init；安装后 ~/.agents/skills/ 里并排的两条软链）。
SKILL_INIT_DIR="$(cd -P "$SKILL_DIR/.." && pwd)/teamsmith-init"
TEAM="bash $SKILL_DIR/scripts/team"

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ────────────────────────────
# 事故背景（v1.11.3 实测）：smoke 从 worker 的 Pi 会话里被调用时继承了 TEAM_ROOT，
# 于是 `team` 读到的是**真实项目**的配置（session/agents/gates 全是真实的），
# 测试里的 tmux/watchdog 段落因此作用到真实 session 上 —— 把 PM 自己的窗口全打掉了。
# 教训：测试必须显式声明「我只服务自己的临时仓库和自己的 session」。
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT \
      TEAM_SESSION TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR \
      TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE TEAM_ALLOW_FOREIGN_SESSION \
      TEAM_PULSE_WINDOW TEAM_PULSE_INTERVAL TEAM_PULSE_NUDGE_GAP TEAM_PULSE_REBUILD_TMUX TEAM_PULSE_MAX_RESTARTS TEAM_PULSE_PENDING_BOARD \
      TEAM_WATCH_WINDOW TEAM_WATCH_INTERVAL TEAM_WATCH_NUDGE_GAP TEAM_WATCH_REBUILD_TMUX TEAM_WATCH_MAX_RESTARTS TEAM_WATCH_PENDING_BOARD 2>/dev/null || true
# ── M36 闸门旋钮也属于「调用者身份」（M67 后另有含义）─────────────────────────────────────
# TEAM_ALLOW_DESTRUCTIVE_TMUX 自 M67 起**零授权**（网关按目标判定，不读它）——但这里仍然 unset：
# ① 它是「调用者环境」的一部分，夹具要证明漏进来的值对判定毫无影响（31c ①e 用显式赋值正面钉住）；
# ② TEAM_TMUX_CALLS_LOG/TEAM_TMUX_REAL 漏进来会把夹具的 tmux 调用写进真项目的 forensics 日志 /
#    把 shim 指到错误真身（M7.2 同族污染）。
unset TEAM_ALLOW_DESTRUCTIVE_TMUX TEAM_TMUX_CALLS_LOG TEAM_TMUX_REAL 2>/dev/null || true
# ── M36 闸门在 PATH 里的那一格也属于「调用者身份」────────────────────────────────────────
# 调用方是 PM/worker 会话（M36 起 PATH 最前是 scripts/shim）时，夹具里 `command -v tmux` 会解析到
# shim 而不是真 tmux：M8.1 的逐字节参考值与 m36 段的 TEAM_TMUX_REAL 断言都会跟着漂（v1.42.0 发布
# 门禁实测 2 红：M8.1 默认渲染 + worker 窗口 env 的真 tmux 路径）。与上面的 TEAM_* unset 同理剥掉。
_m36p=""; _m36ifs="$IFS"; IFS=:
for _m36d in $PATH; do case "$_m36d" in */scripts/shim) ;; *) _m36p="${_m36p:+$_m36p:}$_m36d" ;; esac; done
IFS="$_m36ifs"; [ -n "$_m36p" ] && PATH="$_m36p"; export PATH; unset _m36p _m36ifs _m36d
# ── 复验覆盖项（M25）：TEAM_REVIEW_* 是 review 的旋钮，不是门禁/夹具的输入 ──────────────────
# 事故背景（V16 复验首次 FAIL）：PM 用 `TEAM_REVIEW_ANY_DIR=1 team review …` 时变量继承进夹具，
# 于是「拿错 checkout 必须拒绝」的负向用例**自己把自己放行**（假绿反过来变成假红）。
# 这里逐个清掉环境里实际存在的 TEAM_REVIEW_*（不写死名单）；10c 段会**显式**设置它们来证明
# 「review 子进程读得到、门禁子进程读不到」。
while IFS='=' read -r _m25v _; do
  [ -n "$_m25v" ] && unset "$_m25v" 2>/dev/null || true
done < <(env | sed -n 's/^\(TEAM_REVIEW_[A-Za-z0-9_]*\)=.*$/\1/p')
unset _m25v
# ── P53 临时根纪律（change: test-tmp-hygiene）：本轮 = 一个 run ─────────────────────────
# 自己定 run id（用非 TEAM_ 名：嵌套夹具按身份纪律清 TEAM_* 时清不掉它，台账里才看得见本轮
# **所有**夹具创建的根）；继承的 TEAM_TMP_RUN_ID/TEAM_TMP_LEDGER 属于别人的 run，先清掉。
unset TEAM_TMP_RUN_ID TEAM_TMP_LEDGER 2>/dev/null || true
[ -n "${SMOKE_TMP_RUN_ID:-}" ] || export SMOKE_TMP_RUN_ID="smoke-$$-$(date +%s)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SKILL_DIR/tests/lib/tmp-root.sh"
# P70（change: gate-section-accounting）：每段自述 + 硬预算 + 现场。
# shellcheck source=tests/lib/section-guard.sh
. "$SKILL_DIR/tests/lib/section-guard.sh"
# tmux 的窗口身份也属于「调用者的身份」（M23）：不清掉的话，调用者 pane 里的 $TMUX 会让夹具的
# tmux 调用落到**调用者的 server** 上。清了之后 tmux 按 TMUX_TMPDIR 自己算（见下面的私有 socket）。
# 调用者是不是在 tmux 里：只在第一趟算，并 export 出去 —— 全量模式会经 `flock` **重新跑一遍自己**
# （flock 的子进程，P66 起不是 exec），第二趟时 TMUX 已经被清掉了，再算就会把「调用者在 tmux 里」
# 这件事丢掉（实测：probe 的两套各少跑 12 条依赖它的断言）。
if [ -z "${SMOKE_CALLER_HAD_TMUX:-}" ]; then
  SMOKE_CALLER_HAD_TMUX=0; [ -n "${TMUX:-}" ] && SMOKE_CALLER_HAD_TMUX=1
fi
export SMOKE_CALLER_HAD_TMUX
unset TMUX TMUX_PANE 2>/dev/null || true
SMOKE_CALLER_TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp}"   # 调用者原本的 socket 目录（自检里当「默认 server」用）
KEEP="${TEAM_SMOKE_KEEP:-0}"
# P98：参数 = --keep / --paths <路径>… / --select <key>[,<key>…]；不认识的参数**拒绝**（不静默忽略：
# 「以为传了选段、其实跑了全套或什么都没跑」是同一种危险）。选择决定在拿机器锁之前算（见下）。
SELECT_MODE_REQ=""
SELECT_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --paths)
      [ -z "$SELECT_MODE_REQ" ] || [ "$SELECT_MODE_REQ" = "paths" ] \
        || { printf 'smoke: --paths 与 --%s 不同用\n' "$SELECT_MODE_REQ" >&2; exit 2; }
      SELECT_MODE_REQ="paths"; shift
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do SELECT_ARGS+=("$1"); shift; done
      [ "${#SELECT_ARGS[@]}" -gt 0 ] || { printf 'smoke: --paths 需要至少一条路径\n' >&2; exit 2; } ;;
    --select)
      [ -z "$SELECT_MODE_REQ" ] || [ "$SELECT_MODE_REQ" = "select" ] \
        || { printf 'smoke: --select 与 --%s 不同用\n' "$SELECT_MODE_REQ" >&2; exit 2; }
      SELECT_MODE_REQ="select"; shift
      [ $# -gt 0 ] || { printf 'smoke: --select 需要 key\n' >&2; exit 2; }
      SELECT_ARGS+=("$1"); shift ;;
    *) printf 'smoke: 未知参数 %s（用法：smoke.sh [--keep] [--paths <路径>… | --select <key>[,<key>…]]）\n' "$1" >&2; exit 2 ;;
  esac
done

# 快模式开关（TEAM_SMOKE_FAST=1）：只跑纯逻辑段落，跳过需要真进程的段落（tmux/真实 pi）。
#   FAST_REQ = 用户是不是要了快模式（原始诉求）：快模式自检与结果行用它——就算有人把内部开关
#              FAST 改成 0（就等于“照跑全量”），自检仍然会跑并在 LIVE_RAN>0 时报红。
#   FAST     = 各段落据此分类的内部开关（必须 = FAST_REQ）
# 不认识的值直接报错（不要静默掉回全量：那样“以为跑了快模式，其实在慢慢跑”）。
FAST_REQ=0
case "${TEAM_SMOKE_FAST:-0}" in
  0|""|no|NO|false|FALSE|off|OFF) FAST_REQ=0 ;;
  1|y|Y|yes|YES|true|TRUE|on|ON) FAST_REQ=1 ;;
  *) printf 'TEAM_SMOKE_FAST=%s 不认识（用 1=快模式 / 0=全量）\n' "${TEAM_SMOKE_FAST}" >&2; exit 2 ;;
esac
FAST=$FAST_REQ
LIVE_RAN=0     # 真进程段落实际执行了几次（FAST 模式下必须保持 0）
SKIP_SEGS=""   # FAST 显式跳过的段落标记（末尾自检用）
SKIP_N=0

# ── P98 · 选段（change: gate-runtime-budget · verification#A changed-path list selects…）──
# 决定在**拿机器锁之前**算：NONE 不排队、不建临时根、一段都不跑；FULL 打印兜底原因后照旧跑全套；
# RUN 把「前导 + 选中段 + needs 闭包」过滤成一份副本（整段保留/整段丢弃，段正文逐字节原样），在子进程里
# 跑（子进程照旧遵守 M23 排队、自己建临时根），父进程收尾时打印「这次没跑的段」。三种模式的结果行都
# 不叫 `== 结果 ==`（D7）：选段运行不许被误当全套门禁。
SELECT_MODE=0; SELECT_DECISION=""; SELECT_TOTAL=""; SELECT_RUN_KEYS=""; SELECT_UNSELECTED=""
smoke_words() { local n=0 w; for w in $1; do n=$((n + 1)); done; printf '%s' "$n"; }
smoke_select_header() {
  printf '\n\033[1m== 选段 ==\033[0m decision=%s · 运行 %s/%s 段 · 未跑 %s 段\n' \
    "$SELECT_DECISION" "$(smoke_words "$SELECT_RUN_KEYS")" "${SELECT_TOTAL:-?}" "$(smoke_words "$SELECT_UNSELECTED")"
  if [ -n "$SELECT_UNSELECTED" ]; then
    printf '  这次不跑的键：%s\n' "$SELECT_UNSELECTED"
  else
    printf '  这次不跑的键：（无 —— 全套都在跑）\n'
  fi
  [ "$SELECT_DECISION" = "RUN" ] && printf '  选段不是全套门禁：交付 / 复验 / 归档仍跑整套（references/protocol.md §9b-2）\n'
  return 0
}
smoke_select_tail() {
  printf '\n\033[1m== 选段：这次没跑的段 ==\033[0m %s 个键\n' "$(smoke_words "$SELECT_UNSELECTED")"
  [ -n "$SELECT_UNSELECTED" ] && printf '%s\n' "$SELECT_UNSELECTED"
  printf '  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段\n'
  return 0
}
if [ "$SMOKE_SEL_IS_CHILD" = "1" ]; then
  # 选段子进程：过滤已由父进程做过（段正文没动），这里只声明「这是选段运行」
  SELECT_MODE=1; SELECT_DECISION="${SMOKE_SEL_CHILD_DECISION:-RUN}"
elif [ -n "$SELECT_MODE_REQ" ]; then
  SELECT_BIN="$SKILL_DIR/tests/section-select.sh"
  [ -f "$SELECT_BIN" ] || { printf 'smoke: 选段需要 %s（缺它就不能用 --paths/--select）\n' "$SELECT_BIN" >&2; exit 2; }
  # 过滤副本由选择器一次生成（唯一剪贴实现）：它写进 --out 前先 bash -n 校验，不能解析就在
  # **跑任何段之前**拒绝并点名（段 key + 源码行）——smoke 不再自己剪文本（P117/V1）。
  SELECT_COPY="${TMPDIR:-/tmp}/teamsmith-select.$$.sh"
  rm -f "$SELECT_COPY"
  if ! SELECT_OUT="$(bash "$SELECT_BIN" --"$SELECT_MODE_REQ" "${SELECT_ARGS[@]}" --out "$SELECT_COPY" </dev/null 2>&1)"; then
    printf '%s\n' "$SELECT_OUT" >&2
    printf 'smoke: 选段被拒（副本不能解析 / 表或源码结构问题）—— 什么都没跑\n' >&2
    exit 2
  fi
  SELECT_DECISION="$(printf '%s\n' "$SELECT_OUT" | sed -n 's/^decision=//p' | head -1)"
  SELECT_TOTAL="$(printf '%s\n' "$SELECT_OUT" | sed -n 's/^sections=//p' | head -1)"
  SELECT_RUN_KEYS="$(printf '%s\n' "$SELECT_OUT" | awk -F'\t' 'NF==2{printf "%s ", $1}')"
  SELECT_RUN_KEYS="${SELECT_RUN_KEYS% }"
  case "$SELECT_DECISION" in
    FULL|NONE|RUN) ;;
    *) printf 'smoke: 选段输出没有 decision=FULL|NONE|RUN：\n%s\n' "$SELECT_OUT" >&2; exit 2 ;;
  esac
  if [ "$SELECT_DECISION" = "NONE" ]; then
    printf '\n\033[1m== 选段 ==\033[0m decision=NONE —— 没有段落需要运行（no section needs to run）\n'
    printf '%s\n' "$SELECT_OUT" | sed -n 's/^reason=/  /p'
    printf '  选段运行：一段都没跑、没有结果行、不是门禁证据（交付 / 复验 / 归档仍跑整套）\n'
    exit 0
  fi
  SELECT_ALL_KEYS="$(bash "$SELECT_BIN" --list | awk -F'\t' '{printf "%s ", $1}')"
  # FULL 兜底：接下来跑的是**全套**，所以「运行」的就是全部段（否则运行头会把整套说成「一段都不跑」
  # —— 与套件现有几段无关；段数从表里数，不由这里硬编码）
  [ "$SELECT_DECISION" = "FULL" ] && SELECT_RUN_KEYS="$SELECT_ALL_KEYS"
  SELECT_UNSELECTED=""
  for _k in $SELECT_ALL_KEYS; do
    case " $SELECT_RUN_KEYS " in *" $_k "*) ;; *) SELECT_UNSELECTED="${SELECT_UNSELECTED}${SELECT_UNSELECTED:+ }$_k" ;; esac
  done
  unset _k
  smoke_select_header
  if [ "$SELECT_DECISION" = "RUN" ]; then
    # 副本已经在上面由选择器生成并 bash -n 校验过（段正文逐字节原样；前导与收尾原样保留）
    if [ ! -s "$SELECT_COPY" ]; then
      printf 'smoke: 选段副本没有生成（%s）—— 什么都没跑\n' "$SELECT_COPY" >&2; exit 2
    fi
    SMOKE_SEL_CHILD=1 SMOKE_SEL_SKILL_DIR="$SKILL_DIR" SMOKE_SEL_DECISION=RUN SMOKE_SEL_COPY="$SELECT_COPY" \
      bash "$SELECT_COPY"
    SELECT_RC=$?
    rm -f "$SELECT_COPY"
    smoke_select_tail
    exit "$SELECT_RC"
  fi
  # FULL：本进程照旧跑全套，只把收尾换成选段口径（结果行换 token、不喊 smoke 全绿）
  printf '%s\n' "$SELECT_OUT" | sed -n 's/^reason=/  /p'
  SELECT_MODE=1
fi

# ── P98 · 分段账本（change: gate-runtime-budget；只记录，不判定）─────────────────────────
# 每段收口**一行**（与 P70 的段自述合并成同一条）：
#   `#N id · 用时 Ns · ✓P ✗F SKIPk · ticks T`
#   * 用时/ticks 来自 P70 的看门狗记账（**唯一时钟**：收口行与 sections.tsv 同源，账本不再各量一次）；
#   * ✓/✗/SKIP 是这段的增量（账本侧在关段前经 SG_CLOSE_COUNTS 注入，行由 guard 打）；
#   * 行**不**缩进、**不**携带门禁红标 `  \033[31m✗\033[0m`（flip-m33 数的是那个字节序列），
#     也不把时长与任何阈值比较 —— 账本是报告不是判定：不改退出码、不抑制后续段落、不判慢段红。
SMOKE_SEC_N=0; SMOKE_SEC_OPEN_KEY=""; SMOKE_SEC_OPEN_ID=""
SMOKE_SEC_P0=0; SMOKE_SEC_F0=0; SMOKE_SEC_S0=0
SMOKE_SEC_SUM_P=0; SMOKE_SEC_SUM_F=0; SMOKE_SEC_SUM_S=0; SMOKE_SEC_CLOSES=0
SMOKE_SEC_ROWS=""
# 门禁红标的字节序列（flip-m33 / 本文件 36 段用它辨认「真的红行」；账本行不许带它）
SMOKE_RED_MARK="$(printf '  \033[31m✗\033[0m')"
smoke_section_close() { # 收口已开始的段落（没收口就不做事）：P70 的用时/ticks × P98 的增量，一条行
  [ -n "$SMOKE_SEC_OPEN_KEY" ] || return 0
  local p f s sec tk
  p=$((PASS - SMOKE_SEC_P0)); f=$((FAIL - SMOKE_SEC_F0)); s=$((SKIP_N - SMOKE_SEC_S0))
  SG_CLOSE_COUNTS="✓$p ✗$f SKIP$s"
  section_guard_close                      # 唯一收口行：stdout + sections.log + sections.tsv（同源）
  sec="$SG_ELAPSED"; tk="$SG_TICKS"        # guard 留下的本段用时/ticks（账本读回，不再自己计时）
  SMOKE_SEC_ROWS="${SMOKE_SEC_ROWS}${SMOKE_SEC_N}|${SMOKE_SEC_OPEN_ID}|${sec}|${p}|${f}|${s}|${tk}"$'\n'
  SMOKE_SEC_SUM_P=$((SMOKE_SEC_SUM_P + p)); SMOKE_SEC_SUM_F=$((SMOKE_SEC_SUM_F + f)); SMOKE_SEC_SUM_S=$((SMOKE_SEC_SUM_S + s))
  SMOKE_SEC_CLOSES=$((SMOKE_SEC_CLOSES + 1))
  SMOKE_SEC_OPEN_KEY=""
  return 0
}
smoke_slowest_summary() { # 最慢 N 段（默认 5；SMOKE_SLOWEST_N 只在夹具开关下生效）
  # 汇总行**缩进两格**：与收口行（`^#N `）字节上可区分——否则夹具按 `^#N ` 数收口行会把汇总行
  # 重复计数（P98 实测：4 段跑出 8 条、增量之和翻倍）。行内字段与收口行同形（含用时/ticks）。
  local n=5 v="${SMOKE_SLOWEST_N:-}"
  if [ -n "$v" ]; then
    if [ "${TEAM_SMOKE_FIXTURE:-0}" = "1" ]; then n="$v"
    else printf '\033[33m注意\033[0m：忽略 SMOKE_SLOWEST_N=%s（夹具旋钮只在 TEAM_SMOKE_FIXTURE=1 时生效）\n' "$v"; fi
  fi
  case "$n" in ''|*[!0-9]*) n=5 ;; esac
  [ "$n" -ge 1 ] || return 0
  printf '\n\033[1m== 最慢 %s 段 ==\033[0m\n' "$n"
  printf '%s\n' "$SMOKE_SEC_ROWS" | sed '/^$/d' | sort -t'|' -k3,3gr | head -n "$n" | \
  while IFS='|' read -r idx id sec p f s tk; do
    printf '  \033[2m#%s\033[0m %s · 用时 %ss · ✓%s ✗%s SKIP%s · ticks %s\n' "$idx" "$id" "$sec" "$p" "$f" "$s" "$tk"
  done
  return 0
}
smoke_ledger_selfcheck() { # 段落增量之和 vs 结果行总数：不一致只打印一行（不改退出码）
  local same=1
  [ "$SMOKE_SEC_SUM_P" -eq "$PASS" ] || same=0
  [ "$SMOKE_SEC_SUM_F" -eq "$FAIL" ] || same=0
  # 冒号要留在颜色序列**里面**：assert_has 搜的是连续字节 `账本自查：`（P98 实测）。
  printf '\033[2m账本自查：\033[0m %s 段收口 · 增量 ✓%d ✗%d SKIP%d ｜ 结果行 ✓%d ✗%d —— %s\n' \
    "$SMOKE_SEC_CLOSES" "$SMOKE_SEC_SUM_P" "$SMOKE_SEC_SUM_F" "$SMOKE_SEC_SUM_S" "$PASS" "$FAIL" \
    "$([ "$same" = "1" ] && printf '一致' || printf '不一致（账本有 bug；账本是报告不是判定，退出码不受影响）')"
  return 0
}

# ── 全量门禁互斥（M23）────────────────────────────────────────────────────────────
# 事故（2026-09-17）：`team review` 的两轮门禁（M21、V16）与另一套 smoke 并发时，两次都在 6i 段
# 卡到 1800s 硬超时（TERM 被忽略、KILL 才杀掉）；同一棵树在无人并发时 ~200s 就跑完。两套**全量**
# smoke 会真起 tmux 夹具与真进程，争的是同一台机器（同一个 tmux server、同一批 node/bun/登录 shell）。
# 这里不去猜是哪一个资源先卡住：**全量**默认串行，第二套在门口排队并打印持有者；FAST 模式不排队
# （不起真进程，秒级，不参与这场争用）。
#   TEAM_SMOKE_NO_LOCK=1        不排队（自担并发风险；对照实验用）
#   TEAM_SMOKE_LOCK_WAIT=<秒>   排队上限，默认 1800（超时大声失败：点名持有者 + exit 2，不静默降级 ——
#                               原来的 `exec flock -w` 形态做不到这一点，见下面 P66 那段）
#   TEAM_SMOKE_LOCK=<path>      锁文件，默认 ${TMPDIR:-/tmp}/teamsmith-smoke.lock
SMOKE_LOCK_HELD=0
if [ "$FAST" = "0" ] && [ "${TEAM_SMOKE_NO_LOCK:-0}" != "1" ] && [ "${SMOKE_LOCK_WRAPPED:-0}" != "1" ]; then
  if command -v flock >/dev/null 2>&1; then
    SMOKE_LOCK="${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}"
    SMOKE_LOCK_WAIT="${TEAM_SMOKE_LOCK_WAIT:-1800}"
    case "$SMOKE_LOCK_WAIT" in ''|*[!0-9]*) SMOKE_LOCK_WAIT=1800 ;; esac
    mkdir -p "$(dirname "$SMOKE_LOCK")" 2>/dev/null || true
    if ! : >>"$SMOKE_LOCK" 2>/dev/null; then
      printf '注意：锁文件 %s 建不了 → 不做排队（同机并发两套时可能互相干扰；见 M23）\n' "$SMOKE_LOCK"
    else
      SMOKE_LOCK_PROBE=0
      flock -n "$SMOKE_LOCK" true 2>/dev/null || SMOKE_LOCK_PROBE=$?
      if [ "$SMOKE_LOCK_PROBE" -eq 1 ]; then
        printf '另一套全量 smoke 正在跑（%s）；本套排队，最多等 %ss（TEAM_SMOKE_NO_LOCK=1 可跳过排队）\n' \
          "$(cat "$SMOKE_LOCK.holder" 2>/dev/null || printf '持有者未知')" "$SMOKE_LOCK_WAIT"
        SMOKE_LOCK_QUEUED=1
      elif [ "$SMOKE_LOCK_PROBE" -gt 1 ]; then
        printf '注意：flock 探锁失败（rc=%s）→ 仍按排队路径走（拿不到锁时会报排队超限）\n' "$SMOKE_LOCK_PROBE"
      fi
      # 用 `flock --close` 把**整个脚本**包起来（重新跑一遍自己）：锁挂在 flock 那个父进程上，
      # 脚本与它的子孙都不持有这个 fd。第一版是 `exec 9>>file` + `flock -n 9`，实测**会漏锁**：
      # smoke 的夹具会留下后台子进程（这次是夹具仓库里的占位 `sleep 3600`），它继承了 fd 9 ——
      # 脚本退出后锁还挂着，后续每一套门禁都在门口排队（M23 自测复现，见报告）。
      # `--close` 让被执行的命令拿不到那个 fd，于是「漏锁」这一类被构造性关掉。
      #
      # P66（2026-09-22 PM 归档前实测）：这里**不再用 `exec`**。`flock -w` 超时只返回 1，而 `exec`
      # 之后的那行永远执行不到 → 排队超上限时**静默 exit 1**（既没有点名持有者的一行，也没有约定
      # 的 exit 2），看日志的人只会以为门禁自己红了；更糟的是 smoke 自己失败**也是** 1，只看返回码
      # 会把「门禁真红」误报成「排队超限」。所以：
      #   * marker 文件是「真的拿到锁、本套真的跑起来了」的唯一证据（与 cmd-review.sh 的 queue_marker 同形）；
      #   * 没 marker + rc=1 → 排队超限：一行点名 `<lock>.holder` 里的持有者 + 等了多少秒 → exit 2；
      #   * 有 marker         → 本套跑过了：子进程的退出码原样透传（含它自己的 1）。
      SMOKE_LOCK_MARKER="$(mktemp "${TMPDIR:-/tmp}/teamsmith-smoke-queue.XXXXXX" 2>/dev/null \
        || printf '%s' "$SMOKE_LOCK.queued.$$")"
      export SMOKE_LOCK_WRAPPED=1
      [ "${SMOKE_LOCK_QUEUED:-0}" = "1" ] && export SMOKE_LOCK_QUEUED=1
      SMOKE_LOCK_T0="$(date +%s)"
      SMOKE_LOCK_RC=0
      # P98：选段子进程跑的是过滤副本（$SMOKE_SEL_COPY_PATH）——排队后要跑的还是**同一份**脚本，
      # 否则排队一圈回来就变成“标记说选段、内容却是全套”。标记用命令行前缀带回去（不回写环境，
      # 否则又会被它的子孙继承）；没标记时（正常的全量门禁）与 P66 的解法一模一样。
      if [ "$SMOKE_SEL_IS_CHILD" = "1" ] && [ -n "$SMOKE_SEL_COPY_PATH" ]; then
        # 用 `env` 把标记作为**命令行前缀**带进去：`exec` 自己不认 `VAR=value` 前缀（实测 rc=127，
        # `exec: SMOKE_SEL_CHILD=1: not found`）——这正是 §36 覆盖不到的组合（嵌套跑带 NO_LOCK）。
        flock --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK" bash -c \
          'marker="$1"; shift; date +%s > "$marker"; exec "$@"' _ "$SMOKE_LOCK_MARKER" \
          env SMOKE_SEL_CHILD=1 SMOKE_SEL_SKILL_DIR="$SMOKE_SEL_CHILD_DIR" \
          SMOKE_SEL_DECISION="$SMOKE_SEL_CHILD_DECISION" SMOKE_SEL_COPY="$SMOKE_SEL_COPY_PATH" \
          bash "$SMOKE_SEL_COPY_PATH" "$@" || SMOKE_LOCK_RC=$?
      else
        flock --close -w "$SMOKE_LOCK_WAIT" "$SMOKE_LOCK" bash -c \
          'marker="$1"; shift; date +%s > "$marker"; exec "$@"' _ "$SMOKE_LOCK_MARKER" \
          bash "$SKILL_DIR/tests/smoke.sh" "$@" || SMOKE_LOCK_RC=$?
      fi
      if [ ! -s "$SMOKE_LOCK_MARKER" ]; then
        rm -f "$SMOKE_LOCK_MARKER" 2>/dev/null || true
        if [ "$SMOKE_LOCK_RC" -eq 1 ]; then
          printf '排队超限：等满 %ss 仍拿不到门禁锁 %s（持锁者：%s）→ 本套**没有运行**（这不是对代码的判定；等持锁者结束，或抬高 TEAM_SMOKE_LOCK_WAIT 后重跑；TEAM_SMOKE_NO_LOCK=1 可跳过排队）\n' \
            "$(( $(date +%s) - SMOKE_LOCK_T0 ))" "$SMOKE_LOCK" \
            "$(cat "$SMOKE_LOCK.holder" 2>/dev/null || printf '持有者未知')" >&2
        else
          printf '排队/加锁失败：flock 没能把本套跑起来（%s，rc=%s；既不是排队超限，也没有脚本自己的退出码）\n' \
            "$SMOKE_LOCK" "$SMOKE_LOCK_RC" >&2
        fi
        exit 2
      fi
      rm -f "$SMOKE_LOCK_MARKER" 2>/dev/null || true
      exit "$SMOKE_LOCK_RC"
    fi
  else
    printf '注意：本机没有 flock → 全量 smoke 不做排队（同机并发两套时可能互相干扰；见 M23）\n'
  fi
fi
if [ "${SMOKE_LOCK_WRAPPED:-0}" = "1" ]; then
  SMOKE_LOCK_HELD=1
  SMOKE_LOCK="${SMOKE_LOCK:-${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}}"
  [ "${SMOKE_LOCK_QUEUED:-0}" = "1" ] && printf '轮到本套了（排过队）\n'
  printf '%s pid=%s cmd=smoke.sh\n' "$(date -Is)" "$$" > "$SMOKE_LOCK.holder" 2>/dev/null || true
  # P66 自检出口：排队守卫的自检需要一个**真的排到队、然后按给定退出码结束**的子进程 —— 否则它
  # 只能跑完整套门禁（递归，而且每次门禁多跑几分钟）。只在已经是队列子进程（wrapped）且显式给了
  # 非负整数时生效，而且**大声打印**：正常运行（环境里没有这个变量）的语义一个字不变。
  case "${SMOKE_LOCK_SELFTEST_CHILD:-}" in
    ''|*[!0-9]*) ;;
    *)
      if [ "${TEAM_SMOKE_FIXTURE:-0}" = "1" ]; then
        printf '自检出口：本进程作为队列子进程到此为止（SMOKE_LOCK_SELFTEST_CHILD=%s）\n' "$SMOKE_LOCK_SELFTEST_CHILD"
        exit "$SMOKE_LOCK_SELFTEST_CHILD"
      fi
      printf '注意：SMOKE_LOCK_SELFTEST_CHILD=%s 只给 §34b 的排队守卫自检用；非夹具路径忽略它（照常跑完整套件）\n' \
        "$SMOKE_LOCK_SELFTEST_CHILD"
      ;;
  esac
fi
# ── P26/G1（1.4）：套件自己的子树上，绝不再去争**机器锁** ────────────────────────────────────
# 背景：M49 的假 TIMEOUT 就是「门禁命令自己会在机器锁上排队」——修在 cmd-review.sh（排队是 review
# 自己的阶段），但夹具侧也要封住：一个嵌在门禁里的 `team review` 绝不能替**套件**去碰机器锁。
#   * 全量模式：本套**已经**持有机器锁（SMOKE_LOCK_WRAPPED=1）→ 嵌套 review 走 held 路径，不排队；
#   * FAST 模式：本套不持锁（秒级、不起真进程），若不管，一个夹具里的 review 就会和别人正在跑的
#     全量门禁抢机器锁、白等 1800s（甚至与夹具自己的锁自锁）—— 所以这里给子树一个**私有**锁路径
#     与 wrapped 标记（夹具自己还会再指一层私有锁，见 tests/smoke.sh 的新段落）。
# 真实门禁路径（不带 TEAM_SMOKE_FAST）不受影响：全量依旧持真锁，没有锁的人依旧排队。
if [ "$FAST" = "1" ]; then
  if [ -z "${TEAM_SMOKE_LOCK:-}" ]; then
    TEAM_SMOKE_LOCK="${TMPDIR:-/tmp}/teamsmith-smoke-fast-$$.lock"
    export TEAM_SMOKE_LOCK
  fi
  export SMOKE_LOCK_WRAPPED=1
fi
live_mark() { LIVE_RAN=$((LIVE_RAN + 1)); }
fast_skip() { # <段落标记> <原因>：FAST 模式跳过真进程段落时唯一的出口（必须打印）
  section_guard_check
  SKIP_N=$((SKIP_N + 1))
  SKIP_SEGS="${SKIP_SEGS}|$1"
  printf '  \033[33mSKIP（FAST 模式）\033[0m %s —— %s\n' "$1" "$2"
}
skipped() { case "|$SKIP_SEGS|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac; }   # 首尾补 | ，最后一段也能匹配

cond_skip() { # <段落标记> [<原因>]：条件不满足时的跳过出口（V7-F6：skip 是约定不是 FAIL，必须打印）
  section_guard_check
  SKIP_N=$((SKIP_N + 1))
  SKIP_SEGS="${SKIP_SEGS}|$1"
  printf '  \033[33mSKIP（条件不满足）\033[0m %s\n' "$1${2:+ —— $2}"
}

PASS=0; FAIL=0
section() {
  [ -z "${SMOKE_TMP_CANARY:-}" ] || smoke_tmp_guard "段落 $1 开始时"
  smoke_section_close            # P98 账本 × P70 看门狗：上一段在这里收口（一条统一收口行）
  SMOKE_SEC_N=$((SMOKE_SEC_N + 1))
  SMOKE_SEC_OPEN_KEY="${1%% · *}"; SMOKE_SEC_OPEN_ID="$1"
  SMOKE_SEC_P0=$PASS; SMOKE_SEC_F0=$FAIL; SMOKE_SEC_S0=$SKIP_N
  SMOKE_LAST_SECTION="$1"
  section_guard_begin "$1"       # P70：开这一段（打印唯一的开跑行：== #N id == ISO · 预算 Ns）
}
ok()  { section_guard_check; printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() {
  # M33 哨兵：亮红之前先问一句「是不是 $TMP 中途没了」——是的话由哨兵**一条**点名并立刻停跑
  # （否则一个外部删除会级联出几十条下游假红，尾部还会因为 mkdir -p 把目录建回来而假绿）。
  if [ -n "${SMOKE_TMP_CANARY:-}" ] && ! tmp_alive; then smoke_tmp_fire "断言失败：$1"; fi
  section_guard_check
  printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1))
}
assert_file()  { [ -f "$1" ] && ok "$2" || bad "$2（缺 $1）"; }
assert_dir()   { [ -d "$1" ] && ok "$2" || bad "$2（缺目录 $1）"; }
assert_not_file() { [ ! -e "$1" ] && ok "$2" || bad "$2（$1 不该存在）"; }
assert_has()   { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 中找不到 [$2]）"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 中没有匹配 [$2]）"; }
assert_not()   { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
# 断言「字符串 $1 里含子串 $2」（assert_has 是查文件；旧模板那条用的是字符串）
assert_has_echo() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3（[$1] 里找不到 [$2]）" ;; esac; }
assert_not_echo() { case "$1" in *"$2"*) bad "$3（不该出现 [$2]）" ;; *) ok "$3" ;; esac; }
assert_eq()    { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
# M6.1：state/ 的字节指纹 —— 只读命令不许改运行时状态（F28 的守门断言）
state_fp() {
  ( cd "$REPO/.pi/team/state" 2>/dev/null || return 0
    find . -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" | cut -d' ' -f1; done ) \
    | md5sum | awk '{print $1}'
}
board_status() { $TEAM board row "$1" 2>/dev/null | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$(NF-1)); print $(NF-1)}'; }
# M6.3 F16：dispatch 会拿工作树的分支与「本任务的规范分支」对照（team_branch_for_agent）。
# 夹具必须真的建在规范分支上；这里用实现自己的函数算，避免测试再猜一次名字。
canon_branch() { # <agent> <ID>
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_branch_for_agent "'"$1"'" "'"$2"'"' )
}

# 调用方项目（跑 smoke 的那个仓库）：新夹具必须证明自己没有写它的 inbox/state（M7.2 教训）
SMOKE_INVOKE_ROOT="$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname || true)"
SMOKE_INVOKE_MAIN="$SMOKE_INVOKE_ROOT"
if [ -n "$SMOKE_INVOKE_ROOT" ]; then
  SMOKE_INVOKE_MAIN="$(git -C "$SMOKE_INVOKE_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname || true)"
  [ -n "$SMOKE_INVOKE_MAIN" ] || SMOKE_INVOKE_MAIN="$SMOKE_INVOKE_ROOT"
fi

# 「真实账本」的夹具痕迹扫描（M7.2 纪律）——所有隔离断言共用同一口径：
#   扫 <root>/docs/team/inbox 与 <root>/.pi/team/state，恰排**两条流量记录**（都按确切路径）。
# 排除之一：.pi/team/state/bg/**（M30 实测）——team_bg_run 把后台作业的 stdout 存进 state/bg/<id>.log，
# 门禁自己的 stdout（含各段夹具的名字）就在里面 —— 不排它，下一次门禁的 M16/M98 隔离断言会把「按提示词
# 把门禁放后台跑」判成夹具泄漏（假红：同一棵树、同一套断言，只因上一次的作业日志还在）。
# state/bg 是作业日志，不是账本。
# 排除之二：.pi/team/state/tmux-calls.log（P77）——闸门代调用者写的**调用记录**（内容是调用者自己的
# argv/socket；契约见 boundary#The gate's actions are logged…）。夹具名字出现在那里正是这份日志的本职，
# 把它算成「夹具写进了项目的账本状态」是把证据倒置。
# P87（P83-F1）：**两条排除都是确切路径**，不是目录名/文件名的 glob。老实现用 `--exclude-dir=bg`，会把
# `docs/team/inbox/bg/` 与 `.pi/team/state/nested/bg/` 也静默掉 —— 那两处是真账本，必须被点名。
# 同名兄弟（tmux-calls.log.1）、子目录里的同名文件、任何别处的 bg/ 目录都仍是真泄漏（12b-j / M16 钉住）。
real_ledger_hits() { # <grep -E 模式> <root> → 命中的文件（排序去重）
  local pats="$1" root="${2%/}" d
  { for d in "$root/docs/team/inbox" "$root/.pi/team/state"; do
      [ -d "$d" ] || continue
      grep -rlE "$pats" "$d" 2>/dev/null || true
    done; } \
    | awk -v audit="$root/.pi/team/state/tmux-calls.log" \
          -v jobs="$root/.pi/team/state/bg/" \
          '$0 != audit && index($0, jobs) != 1' \
    | sort -u || true
}

# P53 · 本轮临时根用量：起手一行、结束一行（结束行在 EXIT 里兜底，失败/早退也打）
smoke_human_kb() {
  local kb="${1:-0}"
  case "$kb" in ''|*[!0-9]*) kb=0 ;; esac
  if [ "$kb" -ge 1048576 ]; then awk -v k="$kb" 'BEGIN{printf "%.1f GB", k/1048576}'
  elif [ "$kb" -ge 1024 ]; then awk -v k="$kb" 'BEGIN{printf "%.1f MB", k/1024}'
  else printf '%s KB' "$kb"; fi
}
SMOKE_TMP_USAGE_ENDED=0
smoke_tmp_usage() { # start|end
  local kb files
  kb="$(du -sk "$TMP" 2>/dev/null | awk '{print $1}')"
  files="$(find "$TMP" 2>/dev/null | wc -l | tr -d ' ')"
  printf '  \033[2m·\033[0m 临时根%s：%s（%s · %s 文件）\n' \
    "$([ "${1:-start}" = "end" ] && printf '（结束）' || true)" "$TMP" "$(smoke_human_kb "${kb:-0}")" "${files:-0}"
  [ "${1:-start}" = "end" ] && SMOKE_TMP_USAGE_ENDED=1
  return 0
}

# KEEP 映射到助手的保留旋钮（TEAM_SMOKE_KEEP / --keep 语义不变）
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create smoke)" || { printf 'smoke: 建不出临时根（TMPDIR=%s）\n' "${TMPDIR:-/tmp}" >&2; exit 3; }
smoke_tmp_usage start
SESSION="teamsmith-smoke-$$"
PROTECTED="main"   # 与 TEAM_PROTECTED_BRANCH 默认值一致
REPO="$TMP/repo"
FAKE="$TMP/fake-bin"
mkdir -p "$REPO" "$FAKE"
# P70：阈值表在 skill 树里（只读）；计时记录 sections.tsv / 开跑行 sections.log 在 $TMP。
section_guard_init "$TMP" --budgets "$SKILL_DIR/tests/section-budgets.tsv"

# M36：本轮自己的 shim 调用日志落在 $TMP（调用者窗口若已装闸门，smoke 的夹具 tmux 调用会被它记录 ——
# 记到这里而不是真项目的 state/tmux-calls.log，真账本零污染）。31c 自己按需逐条覆盖这个变量。
TEAM_TMUX_CALLS_LOG="$TMP/tmux-calls-caller.log"; export TEAM_TMUX_CALLS_LOG

# ── tmux 私有 socket（M23）────────────────────────────────────────────────────────
# 对照组早已存在：V15/V16 的对抗探针包用私有 socket（`-L v16pkg-$$` + PATH shim），两套并发从来不
# 互相干扰（见 docs/team/reports/V16-verify/pkg/lib.sh）。smoke 以前走**默认 server**，于是两套并发
# 共用同一个 session 命名空间 —— 实测（docs/team/reports/M23-dev2/pkg/namespace-demo.sh）另一套能把
# 本套的夹具 session 列出来、一行 `kill-session` 删掉；`tmux wait-for` 的 channel 名也是 server 全局的。
#
# 机制选 tmux 自己的开关 `TMUX_TMPDIR`：socket 目录从 `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/` 来，于是本轮
# 可以拥有**自己的 server**（名字仍叫 `default`）。为什么不用 PATH shim（先做了、实测否决）：窗口
# harness 是 `bash -lc`，登录 profile（Debian /etc/profile + distrobox_profile.sh）会把 PATH 重建成
# 系统默认值 —— shim 在里层消失，产品在窗口里的 tmux 调用会回落到默认 server（实测：M6.5/6 的
# PM 拉起断言整段变红）。`TMUX_TMPDIR` 是环境变量，会随 tmux server 传进每个 pane，里层同样有效。
#   TEAM_SMOKE_NO_PRIVATE_TMUX=1  关掉（回到调用者的默认 server；对照实验用）
REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
SMOKE_PRIVATE_TMUX=0
if [ -n "$REAL_TMUX" ] && [ "${TEAM_SMOKE_NO_PRIVATE_TMUX:-0}" != "1" ]; then
  SMOKE_TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$SMOKE_TMUX_TMPDIR"
  TMUX_TMPDIR="$SMOKE_TMUX_TMPDIR"; export TMUX_TMPDIR
  SMOKE_TMUX_SOCK="${SMOKE_TMUX_TMPDIR}/tmux-$(id -u)/default"
  SMOKE_PRIVATE_TMUX=1
  # 调用者本来就在 tmux 里 → 给本轮一个**私有** server 上的等价身份（anchor session + TMUX/TMUX_PANE）：
  # ① 「在 tmux 里」是某些断言的判定前提（探测守卫：不认别的项目的 session），不能因为整理环境而静默降级；
  # ② $TMUX 会被 tmux server 传进每个 pane —— 窗口 harness 的登录 shell 把 PATH 重建掉也照样有效。
  # 调用者不在 tmux 里（CI / nohup）→ TMUX 保持未设，语义与改动前完全一致。
  if [ "${SMOKE_CALLER_HAD_TMUX:-0}" = "1" ]; then
    SMOKE_TMUX_ANCHOR="teamsmith-smoke-anchor-$$"
    tmux new-session -d -s "$SMOKE_TMUX_ANCHOR" -n anchor "sleep 100000" 2>/dev/null || true
    _srv_pid="$(tmux display-message -p -t "$SMOKE_TMUX_ANCHOR:anchor" '#{pid}' 2>/dev/null || true)"
    _sess_id="$(tmux display-message -p -t "$SMOKE_TMUX_ANCHOR:anchor" '#{session_id}' 2>/dev/null || true)"
    _pane_id="$(tmux display-message -p -t "$SMOKE_TMUX_ANCHOR:anchor" '#{pane_id}' 2>/dev/null || true)"
    if [ -n "$_srv_pid" ] && [ -n "$_sess_id" ]; then
      TMUX="$SMOKE_TMUX_SOCK,$_srv_pid,$_sess_id"; export TMUX
      if [ -n "$_pane_id" ]; then TMUX_PANE="$_pane_id"; export TMUX_PANE; fi
    else
      printf '  \033[33mℹ\033[0m %s\n' "锚点 session 没建起来：本轮 \$TMUX 保持未设（探测守卫那条会打印跳过）"
    fi
  fi
fi

# 环境兜底：PATH 里没有 pi 时把下面的假 pi 放进 PATH（见"假 pi"那段），
# 这样缺 pi 只是少跑真进程相关的断言，而不是级联 14 条红（V1.1 实测）。
NEED_PI_STUB=0
command -v pi >/dev/null 2>&1 || NEED_PI_STUB=1

# ── $TMP 存活性哨兵（M33）────────────────────────────────────────────────────────────────────
# 事故（2026-09-18，review bg6 的门禁）：跑到 26-j 时 `/tmp/teamsmith-smoke.EloKhO` **在运行途中消失**，
# 于是对 $TMP 的重定向报 ENOENT（`p10-noqueue.json: No such file or directory`）、find/wc 读空 → 26-j 一片红
# （50 条），而某处的 `mkdir -p` 随后又把目录建回来（新 inode）→ 26-k 之后的段落照旧全绿。半红半绿的门禁里，
# **没有一条红说得清发生了什么**（同 tip 串行复跑不复现）。
# 内部路径已排除（M33 静态审计）：smoke 里删 $TMP 本体的只有 cleanup()（EXIT trap；主 shell 一路活到结尾、
# 结果行都打出来了 → 它没跑过）；bash 的 EXIT trap 在 subshell/命令替换里不触发（实测）；产品代码
# （scripts/**）只 rm -f 文件、不删目录。→ 是**别的进程**干的（同机并发 / 外部清理），谁不知道。
# 防线（三道，证据都落在 $TMP 之外）：
#   ① 金丝雀 `$TMP/.smoke-alive`：判据是「这个文件还在」而不是「$TMP 还在」——「删了又被 mkdir -p 建回来」
#      的形状（bg6）照样抓到（新目录里没有它）。判据只用 bash 内建，轮询不 fork。
#   ② 后台哨兵（0.2s 轮询）：第一次发现消失就把**现场证据**（时刻、新旧 inode、cwd 还指着它的进程、
#      ps 快照）写进 $TMP 之外的诊断文件，并在 stdout 上点名一行。
#   ③ 段落边界与每一条红都过一遍哨兵：红了就**一条点名红 + 立刻停跑**（exit 2，保留现场），不让下游假红
#      （以及目录被重建后的假绿）把「谁删了什么」淹掉。
SMOKE_TMP_PATH="$TMP"
SMOKE_TMP_CANARY="$TMP/.smoke-alive"
# 诊断与标记放在 $TMP **之外**，且以点开头：删 TMP 的人若用的是 `rm -rf /tmp/teamsmith-smoke*` 这种
# 前缀 glob，诊断不会被顺手带走（点开头不匹配）。
SMOKE_TMP_DIAG="${TEAM_SMOKE_DIAG:-${TMPDIR:-/tmp}/.teamsmith-smoke-diag.$$.log}"
SMOKE_TMP_FLAG="${SMOKE_TMP_DIAG%.log}.named"      # 只由 smoke_tmp_fire 写：保证「一条点名红」只印一次
SMOKE_TMP_SEEN="${SMOKE_TMP_DIAG%.log}.seen-at"    # 后台哨兵第一次发现的时刻（fire 把它写进点名行）
SMOKE_TMP_STOP="${SMOKE_TMP_DIAG%.log}.stop"       # 收哨兵的停止位
SMOKE_TMP_ACK="${SMOKE_TMP_DIAG%.log}.stop-ack"    # 哨兵退出的握手（文件握手，不走作业表）
SMOKE_TMP_PIDFILE="${SMOKE_TMP_DIAG%.log}.tripwire.pid"
SMOKE_LAST_SECTION="（还没进段落）"
SMOKE_OWNER_PID="$$"
: > "$SMOKE_TMP_CANARY" 2>/dev/null || true

tmp_alive() { # 0=金丝雀还在（= $TMP 没被删/没被换成另一个目录）｜1=不见了
  [ -n "${SMOKE_TMP_CANARY:-}" ] || return 0    # 哨兵还没装上（极早期）→ 不算失联
  [ -e "$SMOKE_TMP_CANARY" ]
}
smoke_tmp_state() { # 一行现场描述（诊断用）
  printf 'exists=%s dev:ino=%s' \
    "$([ -d "$SMOKE_TMP_PATH" ] && echo yes || echo no)" \
    "$(stat -c '%d:%i' "$SMOKE_TMP_PATH" 2>/dev/null || echo -)"
}
smoke_tmp_diag() { # <来源>：把现场证据写进 $TMP 之外的诊断文件（$TMP 没了也带不走）
  local where="$1" p c
  [ -n "$SMOKE_TMP_DIAG" ] || return 0
  {
    printf '== %s · $TMP 中途消失 · %s ==\n' "$(date -Is)" "$where"
    printf '期望：%s（判据文件 %s）\n' "$SMOKE_TMP_PATH" "$SMOKE_TMP_CANARY"
    printf '现在：%s\n' "$(smoke_tmp_state)"
    printf 'smoke：pid=%s · 最后经过的段落：%s · 哨兵 pid=%s\n' "$$" "$SMOKE_LAST_SECTION" "$(cat "$SMOKE_TMP_PIDFILE" 2>/dev/null || echo -)"
    printf 'M23 锁：%s（holder=%s）\n' "${SMOKE_LOCK:-（无）}" "$(cat "${SMOKE_LOCK:-/nonexistent}.holder" 2>/dev/null || true)"
    printf -- '-- cwd 还指着它的进程（正在里面干活的 / 刚删完还没走远的）--\n'
    for p in /proc/[0-9]*; do
      c="$(readlink "$p/cwd" 2>/dev/null || true)"
      case "$c" in
        "$SMOKE_TMP_PATH"|"$SMOKE_TMP_PATH"/*)
          printf 'pid=%s cwd=%s cmd=%s\n' "${p#/proc/}" "$c" \
            "$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null | head -c 200)" ;;
      esac
    done
    printf -- '-- ps 快照（按启动时间；最后 40 行 = 最近起来的）--\n'
    ps -eo pid,ppid,user,lstart,etime,args --sort=start_time 2>/dev/null | tail -40
    printf -- '-- 诊断结束 --\n'
  } >>"$SMOKE_TMP_DIAG" 2>/dev/null || true
}
smoke_tmp_fire() { # <位置>：一条点名红 + 现场证据 + 立刻停跑（exit 2）；只点名一次
  local where="$1" first=0
  smoke_tmp_diag "$where"
  if [ -n "$SMOKE_TMP_FLAG" ] && [ ! -e "$SMOKE_TMP_FLAG" ]; then
    : > "$SMOKE_TMP_FLAG" 2>/dev/null || true
    first=1
  fi
  KEEP=1    # 现场已经没了：能留的都留下（诊断 + 还没被删光的临时内容）
  if [ "$first" = "1" ]; then
    FAIL=$((FAIL + 1))
    printf '\n  \033[31m✗\033[0m 哨兵：$TMP 在运行途中消失 —— %s%s\n' "$where" \
      "$([ -s "$SMOKE_TMP_SEEN" ] && printf '（后台哨兵 %s 第一次发现）' "$(cat "$SMOKE_TMP_SEEN" 2>/dev/null)")"
    printf '       判据 %s 不见了（或 $TMP 已被换成另一个目录）；现在 %s\n' "$SMOKE_TMP_CANARY" "$(smoke_tmp_state)"
    printf '       这不是断言失败：现场没了，后面的结论都不可信（bg6 形状：删了一阵子又被 mkdir -p 建回来 → 尾部假绿）\n'
    printf '       证据（在 $TMP 之外，删 TMP 也带不走）：%s\n' "$SMOKE_TMP_DIAG"
    printf '       停跑（exit 2）：不让下游假红把「谁删了什么」淹掉\n'
  else
    printf '  \033[2m（哨兵：已在上面点名过；这里停跑）\033[0m\n'
  fi
  exit 2
}
smoke_tmp_guard() { # <位置>：段落边界/结果行前的检查；活着时静默
  tmp_alive || smoke_tmp_fire "$1"
}
assert_tmp_alive() { # <说明>：显式哨兵断言（活着时印 ✓，让「这一拍真的检查过」进证据）
  if tmp_alive; then ok "$1（$SMOKE_TMP_PATH）"; else smoke_tmp_fire "断言「$1」"; fi
}
smoke_tmp_tripwire() { # 后台哨兵本体：0.2s 轮询；发现即写证据 + 点名，然后自己退出
  # 记自己的 pid（$BASHPID：子 shell 里的 $$ 还是主 shell 的 pid），诊断里可以点名它
  printf '%s\n' "$BASHPID" > "$SMOKE_TMP_PIDFILE" 2>/dev/null || true
  while [ ! -e "$SMOKE_TMP_STOP" ]; do
    kill -0 "$SMOKE_OWNER_PID" 2>/dev/null || break      # 主 shell 没了（没走 cleanup）→ 不留孤儿
    if ! tmp_alive; then
      smoke_tmp_diag "后台哨兵（0.2s 轮询）第一次发现"
      date -Is > "$SMOKE_TMP_SEEN" 2>/dev/null || true    # 只记时刻；点名红由主 shell 的 fire 印（一条）
      printf '\n  \033[31m!\033[0m 哨兵：$TMP 在 %s 消失（后台 0.2s 轮询第一次发现；最后经过的段落：%s；证据 %s）\n' \
        "$(date -Is)" "$SMOKE_LAST_SECTION" "$SMOKE_TMP_DIAG"
      break
    fi
    sleep 0.2
  done
  : > "$SMOKE_TMP_ACK" 2>/dev/null || true
}
smoke_tmp_tripwire_stop() { # 收哨兵：置停止位再等它自己退（≤1s；文件握手，不用作业表）
  : > "$SMOKE_TMP_STOP" 2>/dev/null || true
  local i
  for i in $(seq 1 20); do [ -e "$SMOKE_TMP_ACK" ] && break; sleep 0.05; done
  return 0
}
smoke_tmp_sweep() { # 收尾：**干净跑**（没出过事）就把哨兵的兄弟文件收掉，别在 /tmp 里攺一堆
  # 出过事（诊断文件在）就全部留着：那是现场证据，KEEP=1 也留。
  [ -f "$SMOKE_TMP_DIAG" ] && return 0
  rm -f "$SMOKE_TMP_STOP" "$SMOKE_TMP_ACK" "$SMOKE_TMP_PIDFILE" "$SMOKE_TMP_FLAG" "$SMOKE_TMP_SEEN" 2>/dev/null || true
  return 0
}
# 双重 fork：哨兵**不进主 shell 的作业表**。否则门禁里任何裸 `wait` 都会等它等到天荒地老
# （实测风险：12b-i 的并发排水夹具就是裸 `wait`）——那本是一个真 bug，这一层让它不再能咬人。
( smoke_tmp_tripwire & )

cleanup() {
  smoke_tmp_tripwire_stop    # 先收哨兵：下面的临时根回收是**合法**删除，不许被当成事故
  section_guard_stop_watchdog  # P70：收看门狗（trip 现场在 $TMP 之外，回收带不走）
  section_guard_sweep
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  # 私有 socket：连本轮的 server 一起收掉（调用者的默认 server 原样不动）
  [ "${SMOKE_PRIVATE_TMUX:-0}" = "1" ] && tmux kill-server 2>/dev/null || true
  [ "${SMOKE_LOCK_HELD:-0}" = "1" ] && rm -f "${SMOKE_LOCK:-/nonexistent}.holder" 2>/dev/null || true
  # P53：结束用量行（早退也打）→ 助手回收（KEEP 时打印保留路径）→ 诊断文件收尾
  if [ -n "${TMP:-}" ]; then
    [ "${SMOKE_TMP_USAGE_ENDED:-0}" = "1" ] || smoke_tmp_usage end
    tmp_root_reap_all
  fi
  smoke_tmp_sweep
}
trap cleanup EXIT
# P53：INT 要装陷阱（非交互 shell 默认不因 SIGINT 而死）；TERM **不装** —— 未捕获的致命 TERM 会立即
# 杀掉 shell 并跑 EXIT trap（cleanup 先收哨兵再回收根），装陷阱反而被「等前台命令结束」推迟。
trap 'smoke_tmp_tripwire_stop; exit 130' INT

[ -n "${REAL_TMUX:-}" ] && HAVE_TMUX=1 || HAVE_TMUX=0
# 能直接跑 .ts 的运行时：node（需启用类型剥离）/ bun / tsx
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  # bun 装在家目录但不在 PATH（这台机器的实际情况）——不探测它，扩展段落会被静默跳过
  TS_RUNNER="$HOME/.bun/bin/bun"
elif command -v tsx >/dev/null 2>&1; then
  TS_RUNNER="tsx"
fi
# 只要能跑 ESM 的运行时就能做 skill 加载验证
JS_RUNNER=""
command -v node >/dev/null 2>&1 && JS_RUNNER="node"
[ -z "$JS_RUNNER" ] && command -v bun >/dev/null 2>&1 && JS_RUNNER="bun"

# 假 pi：记录参数（验证 dispatch 命令行）+ 对 --version/--help 给出"像样"的回答
# （doctor 会检查 `pi --help` 里有没有 --session-id；没有真 pi 时也要能跑完，不要级联成红）
cat > "$FAKE/pi" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$TMP/pi-args.log"
case "\${1:-}" in
  --version|-v) printf 'pi 0.0.0 (smoke-fake)\n' ;;
  --help|-h)    printf 'usage: pi [--session-id <id>] [-e <ext>] [--skill <dir>]\n' ;;
  *)            printf 'fake pi: %s\n' "\$*" ;;
esac
exit 0
EOF
chmod +x "$FAKE/pi"
if [ "$NEED_PI_STUB" = "1" ]; then
  export PATH="$FAKE:$PATH"
  printf '  \033[2m·\033[0m %s\n' "PATH 里没有 pi → 用假 pi 顶替（真进程相关断言本来就走假 pi）"
fi

printf 'teamsmith smoke · skill=%s · tmp=%s\n' "$SKILL_DIR" "$TMP"
[ "${SMOKE_PRIVATE_TMUX:-0}" = "1" ] && printf '  \033[2m·\033[0m %s\n' \
  "tmux 私有 socket：$SMOKE_TMUX_SOCK（夹具与产品调用都走它；调用者的默认 server 不参与）"
[ "${SMOKE_LOCK_HELD:-0}" = "1" ] && printf '  \033[2m·\033[0m %s\n' \
  "全量门禁互斥：持有 $SMOKE_LOCK（同机第二套会排队；TEAM_SMOKE_NO_LOCK=1 可跳过）"

# 假 meminfo：让内存/swap 守卫可测（Linux /proc/meminfo 格式）
mkfile_meminfo() { # <name> <avail_mb> <swap_free_mb> [swap_total_mb]
  printf 'MemTotal:       32768000 kB\nMemFree:        1024000 kB\nMemAvailable:   %d kB\nSwapTotal:      %d kB\nSwapFree:       %d kB\n' \
    "$(( $2 * 1024 ))" "$(( ${4:-16384} * 1024 ))" "$(( $3 * 1024 ))" > "$TMP/meminfo-$1"
}
mkfile_meminfo plenty  8000 8000
mkfile_meminfo lowswap 8000  300
mkfile_meminfo lowram   600 8000
mkfile_meminfo doomed   100  100

# ---------------------------------------------------------------- 0. 仓库
# P70：从第 0 段起每段自述 + 硬预算（看门狗双重 fork，不在作业表里；trip 现场在 $TMP 之外）。
SG_LOCK_NOTE="${SMOKE_LOCK:-}"
SG_FAST="$FAST"
section_guard_arm
section "0 · 临时仓库"
cd "$REPO" || exit 1
git init -q -b main
git config user.email smoke@teamsmith
git config user.name smoke
echo "# smoke" > README.md
git add -A && git commit -qm "chore: init"
assert_dir "$REPO/.git" "git 仓库就绪"
# M36 调用者 PATH 卫生自检：剥完 shim 后 PATH 里不得再有 */scripts/shim（翻转：删掉顶部那段 PATH 清理 → 红）
case ":$PATH:" in *:*/scripts/shim:*) bad "M36 调用者 PATH 卫生：剥完 shim 后 PATH 仍含 scripts/shim" ;; *) ok "M36 调用者 PATH 卫生：PATH 里没有 scripts/shim（shim 不再漏进夹具）" ;; esac
# M33 哨兵自检：后台哨兵必须**活着但不在作业表里**。它在作业表里的话，门禁里任何裸 `wait`
# （12b-i 的并发排水夹具就有一处）都会被它卡住 —— 双重 fork 就是为了这一条。
# 翻转：把启动行改回 `smoke_tmp_tripwire &`（或删掉那句双重 fork）→ 这条红。
assert_eq "M33 哨兵：后台哨兵活着，但不在作业表里（裸 wait 不会被它卡死）" \
  "$(jobs -p | wc -l | tr -d ' ')|$(kill -0 "$(cat "$SMOKE_TMP_PIDFILE" 2>/dev/null)" 2>/dev/null && echo alive || echo dead)" \
  "0|alive"

# ---------------------------------------------------------------- 0b. skill 合法性（pi 自己的解析器）
section "0b · skill 可被 pi 解析器加载"
if [ -n "$JS_RUNNER" ]; then
  # P16：两个 skill 都必须是合法可加载的（解析器期望的 name = 目录名）。
  for P16_SD in "$SKILL_DIR" "$SKILL_INIT_DIR"; do
    P16_SL="$TMP/skill-load-$(basename "$P16_SD").log"
    $JS_RUNNER "$SKILL_DIR/tests/skill-load.mjs" "$P16_SD" >"$P16_SL" 2>&1
    P16_RC=$?
    if [ "$P16_RC" = "0" ]; then
      ok "skill-load $(basename "$P16_SD")：$(head -1 "$P16_SL")"
    elif [ "$P16_RC" = "2" ]; then
      # 退出码 2 = **本机没有 pi 的解析器**（skill-load.mjs 自己打印 SKIP 行），不是 skill 不合法。
      # M47：这是环境缺失，必须是可见 skip 而不是假红（runner 上没有 pi；装了 pi 的机器照旧跑）。
      cond_skip "skill-load $(basename "$P16_SD")" "$(head -1 "$P16_SL")"
    else
      bad "skill-load 失败（$(basename "$P16_SD")）"; cat "$P16_SL"
    fi
  done
else
  printf '  (跳过：没有可用的 JS 运行时)\n'
fi

# ---------------------------------------------------------------- 0c. 静态检查：set -e 陷阱
# 函数最后一条命令若是可能失败的 && 链，调用方（team 主脚本是 set -euo pipefail）会在
# 函数返回非 0 时直接退出，导致“中间命令成功、整个命令静默失败”这种极难查的 bug。
section "0c · 静态检查（函数结尾的 set -e 陷阱）"
trap_hits="$(awk '
  /^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/ { fn=$1; last=""; next }
  /^}/ && fn!="" { if (last ~ /^[[:space:]]*(\[|test)[^;]*\&\&/ && last !~ /\|\|/) print fn": "last; fn=""; next }
  fn!="" { if ($0 !~ /^[[:space:]]*$/) last=$0 }
' "$SKILL_DIR"/scripts/lib/*.sh)"
if [ -z "$trap_hits" ]; then
  ok "没有「函数结尾 && 链」陷阱"
else
  bad "发现可能让调用方在 set -e 下静默退出的函数："; printf '%s\n' "$trap_hits" | sed 's/^/     /'
fi
# 每个用到的 assert_* 都必须有定义：M5.1 遗留了一个没定义的 assert_has_echo，
# 于是那条断言静默空跑了很久（测试自己「谎报覆盖」）——这里把它钉死。
UNDEF_ASSERTS="$(grep -oE '\bassert_[a-z_]+' "$SKILL_DIR/tests/smoke.sh" | sort -u | while IFS= read -r fn; do
  grep -qE "^$fn\\(\\)" "$SKILL_DIR/tests/smoke.sh" || printf '%s\n' "$fn"
done)"
if [ -n "$UNDEF_ASSERTS" ]; then
  bad "smoke 用了没定义的断言函数（会静默空跑）：$(printf '%s' "$UNDEF_ASSERTS" | tr '\n' ' ')"
else
  ok "smoke 里的 assert_* 都有定义（没有静默空跑的断言）"
fi
# team_watch_pid_alive 这类故意返回 1 的判定函数只允许出现在条件里
assert_has "$SKILL_DIR/scripts/team" "set -euo pipefail" "CLI 主脚本仍启用严格模式"
if [ -x "$SKILL_DIR/scripts/team" ]; then ok "scripts/team 可执行（systemd ExecStart / 直接调用需要）"
else bad "scripts/team 没有 +x：systemd 服务会因 Permission denied 启动失败"; fi
if [ -x "$SKILL_DIR/tests/smoke.sh" ]; then ok "tests/smoke.sh 可执行"
else bad "tests/smoke.sh 没有 +x"; fi

# tmux 隔离自检（M23）：本轮必须落在自己的 server 上，且绝不能出现在调用者的默认 server 上。
# 负对照：TEAM_SMOKE_NO_PRIVATE_TMUX=1 时这条会红（隔离真的没了）。
if [ "${HAVE_TMUX:-0}" = "1" ]; then
  if [ "${SMOKE_PRIVATE_TMUX:-0}" = "1" ]; then
    SMOKE_SOCK_PROBE="teamsmith-smoke-socketprobe-$$"
    tmux new-session -d -s "$SMOKE_SOCK_PROBE" sleep 30 2>/dev/null || true
    if [ -S "$SMOKE_TMUX_SOCK" ] \
       && [ "${TMUX_TMPDIR:-}" = "$SMOKE_TMUX_TMPDIR" ] \
       && tmux has-session -t "$SMOKE_SOCK_PROBE" 2>/dev/null; then
      ok "tmux 隔离：本轮 server 的 socket 在私有目录（$SMOKE_TMUX_SOCK）"
    else
      bad "tmux 隔离：私有 socket 没生效（期望 $SMOKE_TMUX_SOCK，TMUX_TMPDIR=${TMUX_TMPDIR:-未设}）"
    fi
    SMOKE_DEFAULT_SOCK="${SMOKE_CALLER_TMUX_TMPDIR}/tmux-$(id -u)/default"
    if [ -S "$SMOKE_DEFAULT_SOCK" ] \
       && "$REAL_TMUX" -S "$SMOKE_DEFAULT_SOCK" has-session -t "$SMOKE_SOCK_PROBE" 2>/dev/null; then
      bad "tmux 隔离：本轮 session 出现在**默认 server** 上（隔离失效）"
    else
      ok "tmux 隔离：默认 server（$SMOKE_DEFAULT_SOCK）上没有本轮的 session（没污染调用者的场地）"
    fi
    tmux kill-session -t "$SMOKE_SOCK_PROBE" 2>/dev/null || true
  else
    printf '  \033[2m·\033[0m %s\n' "（TEAM_SMOKE_NO_PRIVATE_TMUX=1：显式用调用者的默认 server，对照实验用）"
  fi
else
  printf '  \033[2m·\033[0m %s\n' "（无 tmux：跳过私有 socket 自检）"
fi

# ---------------------------------------------------------------- 0d. 冲突标记守卫（M44）
# 事故（2026-09-19，PM 自伤）：把 M43 合进 main 时 `git merge --squash` 报了冲突，PM 用
# `git add -A && git commit` 一把提交 —— 三件套跟着进了被保护分支，是 PM 事后自查
# （`grep -rln '^<<<<<<<'`）才发现的：当时的门禁**没有任何一条断言**能拦下它。
# 判据（M44）：`git grep` 只扫**已跟踪**文件（未跟踪的临时文件里有标记不算问题；`.git` 不在索引里，
# 天然扫不到）；排除 `.worktrees/**`（别的 agent 的工作树不是这棵树的一部分）与二进制（`-I`）。
# 命中就红，并把 `文件:行号` 逐条打出来。翻转：tests/flip-m44.sh（真事故形状 → 红且点名）。
section "0d · 冲突标记守卫（受版本控制的文件里不许有冲突标记）"
# 行首三件套：带标签的（`<<<<<<< HEAD`）与裸的都算；`=` 一行允许任意长度（conflict-marker-size /
# merge.conflictStyle=diff3 会改长度）。判据只认**行首**：git 写冲突标记永远在第 0 列，所以文档里
# 缩进或用反引号引用的例子天然不受影响。这与 `git status` 的 UU/AA 是两件事：这里只认文本残留。
CM_RE='^(<<<<<<<( |$)|={7,}$|>>>>>>>( |$))'
# 两处都要扫（并集去重）：
#   ① 工作树（默认行为，路径来自索引）—— 冲突刚发生、还没 add 也没提交的残留就在这里；
#   ② 索引（--cached）—— 「先 add 了带标记的版本、又把工作树改回干净」时工作树侧看不见，
#      而下一次提交会把标记写进历史（M44 对抗复验实测到的漏报形状）。冲突进行中索引没有 stage 0，
#      --cached 什么都不报（也不报错），这时靠 ① 兜住；两条路径的排除与 -I 完全相同。
cm_hits() { # <仓库根> → 命中的 `文件:行号:内容`（并集去重；无命中 = 空输出）
  { git -C "$1" -c core.quotepath=false grep -n -I -E "$CM_RE" -- . \
        ':(exclude).worktrees/**' ':(exclude)**/.worktrees/**'
    git -C "$1" -c core.quotepath=false grep -n -I --cached -E "$CM_RE" -- . \
        ':(exclude).worktrees/**' ':(exclude)**/.worktrees/**'
  } 2>/dev/null | sort -u || true
}
CM_ROOT="${TEAM_SMOKE_MARKER_ROOT:-}"
[ -n "$CM_ROOT" ] || CM_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$CM_ROOT" ] || ! git -C "$CM_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  bad "冲突标记守卫：找不到受检的 git 工作树（$SKILL_DIR 不在仓库里？TEAM_SMOKE_MARKER_ROOT=<root> 可显式指定）"
else
  CM_HITS="$(cm_hits "$CM_ROOT")"
  if [ -n "$CM_HITS" ]; then
    bad "受版本控制的文件里有冲突标记（合并/解冲突后残留）—— 解掉再重跑门禁：$CM_ROOT"
    printf '%s\n' "$CM_HITS" | sed 's/^/     /'
  else
    ok "受版本控制的文件里没有冲突标记（$CM_ROOT：$(git -C "$CM_ROOT" ls-files | wc -l | tr -d ' ') 个已跟踪文件）"
  fi
fi
# 翻转自测（M44 的「夹具必须可证伪」）：在 $TMP 里起一个临时仓库，把三件套**造出来**再看判据认不认，
# 同时钉住三条边界（未跟踪不算 / .worktrees 不算 / 二进制不算）。没有这一段，「真树全绿 ✓」就可能
# 只是判据太弱 —— 14b 的教训：检查器空跑时也是绿的。三件套只以变量形式出现（本文件自己也要干净）。
CM_SB="$TMP/conflict-marker-sandbox"
rm -rf "$CM_SB"; mkdir -p "$CM_SB"
git -C "$CM_SB" init -q -b main
git -C "$CM_SB" config user.email smoke@teamsmith
git -C "$CM_SB" config user.name smoke
printf 'clean\n' > "$CM_SB/tracked.txt"
git -C "$CM_SB" add -A && git -C "$CM_SB" commit -qm "chore: init"
CM_LT='<<<<<<<'; CM_EQ='======='; CM_GT='>>>>>>>'
cm_sb_write() { printf 'clean-before\n%s HEAD\nours\n%s\ntheirs\n%s feature\n' "$CM_LT" "$CM_EQ" "$CM_GT" > "$1"; }
if [ -z "$(cm_hits "$CM_SB")" ]; then
  ok "翻转自测：干净副本无命中（正对照）"
else
  bad "翻转自测：干净副本被误报：$(cm_hits "$CM_SB" | head -1)"
fi
cm_sb_write "$CM_SB/tracked.txt"
if cm_hits "$CM_SB" | grep -q '^tracked\.txt:2:'; then
  ok "翻转自测：已跟踪文件里的三件套被抓到并点名 tracked.txt:2（还没提交也算）"
else
  bad "翻转自测：判据漏报已跟踪文件里的冲突标记（输出：$(cm_hits "$CM_SB" | head -1)）"
fi
git -C "$CM_SB" add -A && git -C "$CM_SB" commit -qm "accident: git add -A && git commit"
if [ -n "$(cm_hits "$CM_SB")" ]; then
  ok "翻转自测：标记进提交之后仍然红（事故形状）"
else
  bad "翻转自测：标记提交之后判据变绿（漏报）"
fi
printf 'clean\n' > "$CM_SB/tracked.txt"
git -C "$CM_SB" add -A && git -C "$CM_SB" commit -qm "fix: resolve the conflict for real"
if [ -z "$(cm_hits "$CM_SB")" ]; then
  ok "翻转自测：清干净后回到绿（同一判据红→绿都成立）"
else
  bad "翻转自测：清干净后仍然红：$(cm_hits "$CM_SB" | head -1)"
fi
# 索引侧（M44 对抗复验加严的形状）：先 `git add` 带标记的版本，再把工作树改回干净 —— 工作树侧看不见，
# 但下一次提交会把标记写进历史。判据必须仍然红（没有 --cached 这条路就漏；翻转自测直接钉住它）。
cm_sb_write "$CM_SB/notes2.txt"
git -C "$CM_SB" add notes2.txt
printf 'clean-after-add\n' > "$CM_SB/notes2.txt"
if cm_hits "$CM_SB" | grep -q '^notes2\.txt:2:'; then
  ok "翻转自测：索引里有标记（工作树已改回干净）仍然红并点名 notes2.txt:2"
else
  bad "翻转自测：暂存侧的标记被漏报（工作树干净就放行 —— 下次提交会把它写进历史）"
fi
git -C "$CM_SB" rm -q --cached notes2.txt 2>/dev/null; rm -f "$CM_SB/notes2.txt"   # 收回这一步，后面继续用干净索引
cm_sb_write "$CM_SB/untracked.txt"     # 边界①：未跟踪文件里有标记不算问题
if cm_hits "$CM_SB" | grep -q 'untracked\.txt'; then
  bad "翻转自测：未跟踪文件被误算（判据扫到了索引之外的工作树文件）"
else
  ok "翻转自测：未跟踪文件里的标记不算问题（只扫已跟踪）"
fi
mkdir -p "$CM_SB/.worktrees/other"      # 边界②：.worktrees/** 排除 —— 用 add -f 强制跟踪证明不是靠 .gitignore 侥幸
cm_sb_write "$CM_SB/.worktrees/other/wt.txt"
git -C "$CM_SB" add -f .worktrees/other/wt.txt 2>/dev/null && git -C "$CM_SB" commit -qm "wt" 2>/dev/null
if git -C "$CM_SB" ls-files --error-unmatch .worktrees/other/wt.txt >/dev/null 2>&1; then
  if cm_hits "$CM_SB" | grep -q '\.worktrees/'; then
    bad "翻转自测：.worktrees/** 没被排除（别的 agent 的工作树会被误伤）"
  else
    ok "翻转自测：.worktrees/** 里的标记被排除（强制跟踪也不误伤）"
  fi
else
  bad "翻转自测：.worktrees 夹具没建成（add -f 失败）—— 这条边界没被证到"
fi
printf 'x\0\n%s HEAD\n' "$CM_LT" > "$CM_SB/bin.dat"   # 边界③：二进制（含 NUL）被 -I 跳过
git -C "$CM_SB" add -A && git -C "$CM_SB" commit -qm "bin"
if cm_hits "$CM_SB" | grep -q 'bin\.dat'; then
  bad "翻转自测：二进制文件被当文本扫（-I 没生效）"
else
  ok "翻转自测：二进制文件被 -I 跳过（NUL 字节 + 标记也不误报）"
fi

# ---------------------------------------------------------------- 0e. P70 段落自述（change: gate-section-accounting）
# 每段自述/硬预算/现场的守门断言（纯逻辑 + 模块自检，不碰 tmux、不碰真项目）。
section "0e · 段落自述：看门狗 / 预算表 / 循环清单（P70）"
# ① 看门狗在岗、但不在作业表里（M33 哨兵同形：12b-i 的裸 wait 不能被它卡住）
P70_WD_PID="$(awk -F'\t' 'NR==1{print $1}' "$SG_WATCHDOG_PIDFILE" 2>/dev/null || true)"
assert_eq "P70 看门狗：活着但不在作业表里（双重 fork）" \
  "$(jobs -p | wc -l | tr -d ' ')|$(_sg_pid_alive "$P70_WD_PID" && printf alive || printf dead)" "0|alive"
assert_eq "P70 看门狗：心跳指向当前段落（#${SG_SEC_NO}）" \
  "$(awk -F'|' '{print $1}' "$SG_HEARTBEAT" 2>/dev/null)" "$SG_SEC_NO"
# ② 模块自检：五形状（挂住的子进程 / 忽略 TERM 的子进程 / 纯内建自旋 / 自旋且关掉 TERM / 干净）
if TMPDIR="$TMP" bash "$SKILL_DIR/tests/lib/section-guard.sh" --self-test >"$TMP/p70-sg-self.log" 2>&1; then
  ok "P70 模块自检五形状全绿（$(grep -ac '✓' "$TMP/p70-sg-self.log" || true) 条断言）"
else
  bad "P70 模块自检有失败"; grep -a '✗' "$TMP/p70-sg-self.log" | head -8 | sed 's/^/      /'
fi

# ③b 破环翻转：把安全点的 marker 检查砸掉（scratch 副本）→ 挂住的段不再被停，自检必红
P70_BRK="$TMP/p70-break"; rm -rf "$P70_BRK"; mkdir -p "$P70_BRK"
cp "$SKILL_DIR/tests/lib/section-guard.sh" "$P70_BRK/section-guard.sh"
sed -i '/^_sg_check_trip() {/,/^}/ s/    _sg_exit_trip/    : # break-it（安全点不再停跑）/' "$P70_BRK/section-guard.sh"
if grep -q 'break-it' "$P70_BRK/section-guard.sh"; then
  TMPDIR="$TMP" bash "$P70_BRK/section-guard.sh" --self-test >"$TMP/p70-sg-break.log" 2>&1; P70_RC=$?
  if [ "$P70_RC" -ne 0 ]; then
    ok "P70 破环翻转：砸掉安全点的 marker 检查 → 模块自检红（$(grep -ac '✗' "$TMP/p70-sg-break.log" || true) 条）"
  else
    bad "P70 破环翻转：marker 检查没了自检还绿（守卫没被证到）"
  fi
else
  bad "P70 破环翻转：sed 没改到 _sg_check_trip（夹具失效）"
fi

# ③ 预算表 + 循环清单：干净树绿 + 三个翻转红（全在 scratch 副本里动，真实树不碰）
P70_CK="$TMP/p70-check"; rm -rf "$P70_CK"; mkdir -p "$P70_CK/lib"
cp "$SKILL_DIR/tests/section-guard.sh" "$SKILL_DIR/tests/smoke.sh" \
   "$SKILL_DIR/tests/section-budgets.tsv" "$SKILL_DIR/tests/loop-inventory.tsv" "$P70_CK/"
cp "$SKILL_DIR"/tests/lib/*.sh "$SKILL_DIR"/tests/lib/loop-scan.awk "$P70_CK/lib/"
bash "$P70_CK/section-guard.sh" --budget-check >"$TMP/p70-budget-green.log" 2>&1; P70_RC=$?
assert_eq "P70 预算检查：干净树绿（$(sed -n 's/^ok: 预算表覆盖 \(.*\) 个 section.*/\1/p' "$TMP/p70-budget-green.log") 个 section）" "$P70_RC" "0"
bash "$P70_CK/section-guard.sh" --loop-check >"$TMP/p70-loop-green.log" 2>&1; P70_RC=$?
assert_eq "P70 循环清单：干净树绿（$(sed -n 's/^ok: 扫描 \(.*\)$/\1/p' "$TMP/p70-loop-green.log")）" "$P70_RC" "0"
# 翻转①：把一条预算降到「实测带×系数」以下 → 必须点名该段并红
P70_LOW_ID="$(awk -F'\t' '!/^#/ && $4 ~ /^[0-9.]+$/ && ($4+0) >= 20 { print $1; exit }' "$P70_CK/section-budgets.tsv")"
if [ -n "$P70_LOW_ID" ]; then
  awk -F'\t' -v id="$P70_LOW_ID" 'BEGIN{FS="\t"; OFS="\t"} /^#/ { print; next } $1 == id { $3 = 1 } { print }' \
    "$P70_CK/section-budgets.tsv" > "$P70_CK/b.new" && mv "$P70_CK/b.new" "$P70_CK/section-budgets.tsv"
  bash "$P70_CK/section-guard.sh" --budget-check >"$TMP/p70-budget-low.log" 2>&1; P70_RC=$?
  assert_eq "P70 翻转（预算）：降到带以下 → 红" "$P70_RC" "1"
  assert_has "$TMP/p70-budget-low.log" "$P70_LOW_ID" "P70 翻转（预算）：点名被降的段落"
  cp "$SKILL_DIR/tests/section-budgets.tsv" "$P70_CK/section-budgets.tsv"
  bash "$P70_CK/section-guard.sh" --budget-check >/dev/null 2>&1; P70_RC=$?
  assert_eq "P70 翻转（预算）还原：绿" "$P70_RC" "0"
else
  bad "P70 翻转（预算）：找不到有实测带的段落（表坏了？）"
fi
# 翻转②：删掉一条 section 行（未登记的段落不得默默无界）→ 必须点名并红
P70_MISS_ID="$(awk -F'\t' '!/^#/ && NF { print $1; exit }' "$P70_CK/section-budgets.tsv")"
awk -F'\t' -v id="$P70_MISS_ID" 'BEGIN{FS="\t"} /^#/ { print; next } $1 == id { next } { print }' \
  "$P70_CK/section-budgets.tsv" > "$P70_CK/b.new" && mv "$P70_CK/b.new" "$P70_CK/section-budgets.tsv"
bash "$P70_CK/section-guard.sh" --budget-check >"$TMP/p70-budget-miss.log" 2>&1; P70_RC=$?
assert_eq "P70 翻转（缺行）：删掉段落行 → 红" "$P70_RC" "1"
assert_has "$TMP/p70-budget-miss.log" "$P70_MISS_ID" "P70 翻转（缺行）：点名缺行的段落"
cp "$SKILL_DIR/tests/section-budgets.tsv" "$P70_CK/section-budgets.tsv"
# 翻转③：加一个未登记的 while+sleep → 循环清单必须点名 file:line
printf '#!/usr/bin/env bash\nx=0\nwhile :; do sleep 1; x=$((x+1)); done\n' > "$P70_CK/evil-fixture.sh"
bash "$P70_CK/section-guard.sh" --loop-check >"$TMP/p70-loop-evil.log" 2>&1; P70_RC=$?
assert_eq "P70 翻转（循环）：新 while+sleep → 红" "$P70_RC" "1"
assert_has "$TMP/p70-loop-evil.log" "evil-fixture.sh:3" "P70 翻转（循环）：点名 file:line"
rm -f "$P70_CK/evil-fixture.sh"
bash "$P70_CK/section-guard.sh" --loop-check >/dev/null 2>&1; P70_RC=$?
assert_eq "P70 翻转（循环）还原：绿" "$P70_RC" "0"

# ④ gate-guard 的第四向：时长比较只许在段落守卫里（D33 的边界；翻了必须红）
#   夹具自己要把两个“标记字面量”（测量套件的点名、时长比较）写进 scratch smoke.sh —— 拼开写，
#   否则守卫会先抓到夹具自己（自指假红，M58 之后的老坑）。
P70_PF="per"; P70_PF="${P70_PF}f.sh"
P70_GG="$TMP/p70-gg"; rm -rf "$P70_GG"; mkdir -p "$P70_GG/lib"
cp "$SKILL_DIR/tests/gate-guard.sh" "$SKILL_DIR/tests/smoke.sh" "$SKILL_DIR/tests/panel-knobs.sh" \
   "$SKILL_DIR/tests/$P70_PF" "$P70_GG/"
cp "$SKILL_DIR/tests/lib/section-guard.sh" "$P70_GG/lib/"
bash "$P70_GG/gate-guard.sh" >"$TMP/p70-gg-green.log" 2>&1; P70_RC=$?
assert_eq "P70 gate-guard 第四向：干净副本绿" "$P70_RC" "0"
printf '\nif [ "$elapsed" -'"g"'t 5 ]; then :; fi\n' >> "$P70_GG/smoke.sh"
bash "$P70_GG/gate-guard.sh" >"$TMP/p70-gg-flip.log" 2>&1; P70_RC=$?
assert_eq "P70 gate-guard 第四向翻转：smoke.sh 塞回时长比较 → 红" "$P70_RC" "1"
assert_has "$TMP/p70-gg-flip.log" "时长阈值比较" "P70 gate-guard 第四向翻转：点名原因"
cp "$SKILL_DIR/tests/smoke.sh" "$P70_GG/smoke.sh"
bash "$P70_GG/gate-guard.sh" >/dev/null 2>&1; P70_RC=$?
assert_eq "P70 gate-guard 第四向还原：绿" "$P70_RC" "0"

# ⑤ 夹具旋钮只在 TEAM_SMOKE_FIXTURE=1 下生效；否则打印忽略行（环境不能悄悄拆掉边界）
mkdir -p "$TMP/p70-knob-off" "$TMP/p70-knob-on"
p70_knob_probe() { # <输出文件> <run tmp> <env 前置...>：用模块自己的 init 读旋钮（不跑套件）
  local out="$1" dir="$2"; shift 2
  env "$@" bash -c '
    . "$1/tests/lib/section-guard.sh"
    section_guard_init "$2" --budgets "$1/tests/section-budgets.tsv"
    printf "override=[%s]\n" "$SG_BUDGET_OVERRIDE"
    section_guard_budget_for "0c · 静态检查（函数结尾的 set -e 陷阱）"
    printf "stuck-budget=%s source=%s\n" "$SG_BUDGET" "$SG_BUDGET_SOURCE"
    section_guard_budget_for "1 · doctor（未初始化应失败）"
    printf "other-budget=%s source=%s\n" "$SG_BUDGET" "$SG_BUDGET_SOURCE"
  ' _ "$SKILL_DIR" "$dir" >"$out" 2>&1
}
p70_knob_probe "$TMP/p70-knob-off.log" "$TMP/p70-knob-off" -u TEAM_SMOKE_FIXTURE TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_BUDGET=3
assert_has "$TMP/p70-knob-off.log" "忽略它" "P70 旋钮（夹具关）：打印忽略行"
assert_has "$TMP/p70-knob-off.log" "override=[]" "P70 旋钮（夹具关）：不生效"
assert_has "$TMP/p70-knob-off.log" "source=table" "P70 旋钮（夹具关）：预算来自表"
p70_knob_probe "$TMP/p70-knob-on.log" "$TMP/p70-knob-on" TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_BUDGET=3
assert_has "$TMP/p70-knob-on.log" "stuck-budget=3 source=fixture" "P70 旋钮（夹具开）：被点名的段用注入预算"
assert_has "$TMP/p70-knob-on.log" "other-budget=$(awk -F'\t' '$1=="1 · doctor（未初始化应失败）"{print $3}' "$SKILL_DIR/tests/section-budgets.tsv") source=table" \
  "P70 旋钮（夹具开）：别的段照旧用表"

# ---------------------------------------------------------------- 0f. P70 超时段落：点名 + 停跑 + 现场
# 嵌套 smoke 用 FAST + 自己的 TMPDIR（不排队、不碰真项目）；stuck knob 在 0c 段注入一个忽略 TERM 的
# 子进程，预算覆盖成 3s —— 看门狗必须点名 #3、写现场、套件 exit 2（安全点路径）。
section "0f · 超时段落：点名 + 停跑 + 现场（P70）"
if [ "${P70_NESTED:-0}" = "1" ]; then
  printf '  (嵌套运行：跳过 P70 自述夹具，避免递归)\n'
else
  P70_STUCK_ROOT="$TMP/p70-stuck"; rm -rf "$P70_STUCK_ROOT"; mkdir -p "$P70_STUCK_ROOT"
  ( cd "$SKILL_DIR" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_DOCS_DIR -u TEAM_TMP_KEEP -u TEAM_SMOKE_KEEP -u SMOKE_LOCK_WRAPPED -u TEAM_SMOKE_LOCK \
      P70_NESTED=1 TMPDIR="$P70_STUCK_ROOT" TEAM_SMOKE_FAST=1 TEAM_SMOKE_FIXTURE=1 \
      TEAM_SMOKE_STUCK_SECTION=0c TEAM_SMOKE_SECTION_BUDGET=3 TEAM_SMOKE_PROGRESS_INTERVAL=1 \
      TEAM_SMOKE_GUARD_POLL=0.2 bash "$SKILL_DIR/tests/smoke.sh" </dev/null ) >"$TMP/p70-stuck.log" 2>&1
  P70_STUCK_RC=$?
  assert_eq "P70 超时：嵌套套件 exit 2（安全点路径）" "$P70_STUCK_RC" "2"
  assert_eq "P70 超时：输出里恰好一条点名超时的行" \
    "$(grep -ac '段落 #3（0c · 静态检查（函数结尾的 set -e 陷阱））超时' "$TMP/p70-stuck.log" || true)" "1"
  assert_has "$TMP/p70-stuck.log" "预算 3s" "P70 超时：点名行带预算"
  if tail -25 "$TMP/p70-stuck.log" | grep -q '段落 #3'; then
    ok "P70 超时：点名行在 tail -25 里（复验记录能看到）"
  else
    bad "P70 超时：点名行不在 tail -25 里"
  fi
  assert_not "$TMP/p70-stuck.log" "== 结果 ==" "P70 超时：没有结果行"
  assert_not "$TMP/p70-stuck.log" "== #4 " "P70 超时：后面没有别的段落开跑"
  if grep -qE 'SKIP.*(0c|#3)' "$TMP/p70-stuck.log"; then
    bad "P70 超时：超时被报成 SKIP"
  else
    ok "P70 超时：超时不是 SKIP（不是把机器判绿）"
  fi
  if grep -aq '已运行' "$TMP/p70-stuck.log"; then
    ok "P70 超时：超时前有进度自述（$(grep -ac '已运行' "$TMP/p70-stuck.log" || true) 行）"
  else
    bad "P70 超时：没有进度自述"
  fi
  P70_STUCK_SCENE="$(ls -d "$P70_STUCK_ROOT"/.teamsmith-smoke-scene.* 2>/dev/null | head -1 || true)"
  if [ -n "$P70_STUCK_SCENE" ] && [ -s "$P70_STUCK_SCENE/summary.txt" ]; then
    ok "P70 超时：现场存在（${P70_STUCK_SCENE#$TMP/}）"
    case "$P70_STUCK_SCENE" in
      "$P70_STUCK_ROOT"/.teamsmith-smoke-scene.*) ok "P70 现场：TMPDIR 相对 + 点开头" ;;
      *) bad "P70 现场：路径不在 TMPDIR 下或不是点开头（$P70_STUCK_SCENE）" ;;
    esac
    case "$P70_STUCK_SCENE" in
      "$P70_STUCK_ROOT"/teamsmith-smoke.*/*) bad "P70 现场：落在 run 自己的临时根里" ;;
      *) ok "P70 现场：在 run 自己的临时根之外（清理带不走）" ;;
    esac
    assert_has "$P70_STUCK_SCENE/summary.txt" "id: 0c · 静态检查" "P70 现场：点名段落 id"
    assert_has "$P70_STUCK_SCENE/summary.txt" "budget: 3s" "P70 现场：点名预算"
    assert_match "$P70_STUCK_SCENE/summary.txt" "last progress: [0-9]+s" "P70 现场：带最后一次进度读数"
    assert_has "$P70_STUCK_SCENE/summary.txt" "sleep 0.2" "P70 现场：子孙树里有挂住的子进程"
    assert_has "$P70_STUCK_SCENE/summary.txt" "escalation" "P70 现场：记录了 KILL 升级（子进程忽略 TERM）"
    assert_has "$P70_STUCK_SCENE/logs/tails.txt" "fixture-stuck" "P70 现场：带本段的夹具日志尾巴"
    assert_eq "P70 现场：部分计时记录有前两段的行" \
      "$(awk 'NR>1' "$P70_STUCK_SCENE/sections.tsv.partial" 2>/dev/null | wc -l | tr -d ' ')" "2"
  else
    bad "P70 超时：没有现场目录"
  fi
  assert_eq "P70 超时：嵌套 run 的临时根已回收（只剩现场）" \
    "$(ls -d "$P70_STUCK_ROOT"/teamsmith-smoke.* 2>/dev/null | wc -l | tr -d ' ')" "0"
fi

# ---------------------------------------------------------------- 0g. P70 等待有界：到顶归因 + ticks
section "0g · 等待有界：到顶归因 + ticks（P70）"
p70_wait_reader() { printf 'reader-%s' "${1:-?}"; }
IFS='|' read -r _ _ _ _ P70_TICKS0 _ < "$SG_HEARTBEAT"
section_guard_wait "p70-never" 3 0.1 "一个永远不来的状态" p70_wait_reader false >"$TMP/p70-wait.log" 2>&1
P70_WAIT_RC=$?
IFS='|' read -r _ _ _ _ P70_TICKS1 _ < "$SG_HEARTBEAT"
assert_eq "P70 等待到顶：返回非 0（不是悄悄通过）" "$P70_WAIT_RC" "1"
assert_has "$TMP/p70-wait.log" "3/3" "P70 等待到顶：归因行带 3/3"
assert_has "$TMP/p70-wait.log" "等待到顶" "P70 等待到顶：归因行点名等待"
assert_has "$TMP/p70-wait.log" "最后一次读数：reader-3" "P70 等待到顶：归因行带最后一次读数"
assert_eq "P70 等待到顶：每轮都刷新了进度 ticks（心跳）" "$((P70_TICKS1 - P70_TICKS0))" "3"
P70_WAIT_HEAD="$(head -1 "$TMP/p70-wait.log")"
assert_has_echo "$P70_WAIT_HEAD" "等待到顶" "P70 等待到顶：第一行就是归因（不被别的输出淹没）"

# ---------------------------------------------------------------- 1. doctor 负例
section "1 · doctor（未初始化应失败）"
if $TEAM doctor >"$TMP/doctor-pre.log" 2>&1; then bad "未初始化时 doctor 应失败"; else ok "未初始化时 doctor 正确报错"; fi
assert_has "$TMP/doctor-pre.log" "config" "doctor 报告了 config 项"

# ---------------------------------------------------------------- 1b. bootstrap（一次性临时仓库）
section "1b · bootstrap（一条命令初始化）"
BR="$TMP/bootrepo"; mkdir -p "$BR"; cd "$BR"
git init -q -b main; git config user.email smoke@teamsmith; git config user.name smoke
echo "# boot" > README.md; git add -A; git commit -qm init
BSESS="teamsmith-smoke-boot-$$"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog --print >"$TMP/boot-print.log" 2>&1 \
  && ok "bootstrap --print 退出码 0（--no-watchdog 旧旗标别名期仍被接受）" || bad "bootstrap --print 失败"
assert_has "$TMP/boot-print.log" "计划步骤" "打印了计划步骤"
assert_has "$TMP/boot-print.log" "add-agent dev" "计划里含建 worktree"
assert_has "$TMP/boot-print.log" "pulse up" "计划里含起巡检窗口（pulse）"
[ -f "$BR/.pi/team/config.sh" ] && bad "--print 不该改任何东西" || ok "--print 确实没改东西"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-pulse >"$TMP/boot.log" 2>&1 \
  && ok "bootstrap 退出码 0" || { bad "bootstrap 失败"; cat "$TMP/boot.log"; }
assert_file "$BR/.pi/team/config.sh" "bootstrap 写了配置"
assert_has "$BR/.pi/team/config.sh" "TEAM_SESSION=\"$BSESS\"" "把探测/指定的 session 写进配置"
assert_has "$BR/.pi/team/config.sh" "TEAM_PULSE_INTERVAL=900" "生成的配置写 TEAM_PULSE_*（v1.36.0 新名）"
grep -qE '^TEAM_WATCH_INTERVAL=' "$BR/.pi/team/config.sh" && bad "生成的配置不该再写旧变量名" || ok "旧变量名只出现在配置注释里"
assert_dir "$BR/docs/team/tasks" "建了文档骨架"
assert_has "$TMP/boot.log" "worktree add -b agent/dev" "bootstrap 只打印 worktree 命令（git 归 PM）"
assert_not_file "$BR/.worktrees/dev" "默认不代建 dev worktree"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-pulse --create-worktrees >"$TMP/boot2.log" 2>&1 || true
assert_dir "$BR/.worktrees/dev" "--create-worktrees 才代建 dev worktree"
assert_dir "$BR/.worktrees/verify" "--create-worktrees 才代建 verify worktree"
assert_has "$BR/AGENTS.md" "<!-- teamsmith:begin -->" "注入了协议段"
assert_has "$BR/AGENTS.md" "Specs (OpenSpec)" "bootstrap 注入的协议段也告诉 agent specs 在哪（M6.3）"
assert_has "$TMP/boot.log" "下一步" "打印了下一步清单"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-pulse >"$TMP/boot2.log" 2>&1
assert_eq "bootstrap 幂等（协议段只一份）" "$(grep -cF '<!-- teamsmith:begin -->' "$BR/AGENTS.md")" "1"
# 必需依赖预检（D10）：配置写完后就要体检；缺了不阻塞，但每条都要给出修复/降级办法
env TEAM_PI_SETTINGS_FILE="$TMP/mc-none/settings.json" TEAM_OPENSPEC_BIN=/nonexistent \
  $TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-pulse >"$TMP/boot-deps.log" 2>&1 \
  && ok "缺依赖时 bootstrap 仍然退出码 0（不阻塞初始化）" || { bad "缺依赖不该让 bootstrap 失败"; tail -5 "$TMP/boot-deps.log"; }
assert_has "$TMP/boot-deps.log" "必需依赖还没就绪" "bootstrap 提示必需依赖"
assert_has "$TMP/boot-deps.log" "@cortexkit/pi-magic-context" "bootstrap 给出 magic-context 的修复办法"
assert_has "$TMP/boot-deps.log" "openspec init --tools none" "bootstrap 给出 spec 目录的确切修复命令"
assert_has "$TMP/boot-deps.log" "TEAM_OPENSPEC_BIN" "bootstrap 给出 CLI 解析的降级/指定办法"

# ---------------------------------------------------------------- 1c. bootstrap 的 PM 窗口名（M11）
section "1c · bootstrap 的 PM 窗口名：约定不是现场（M11）"
# 事故（本项目实测）：配置里 TEAM_PM_WINDOW="pi" —— bootstrap 把「当前窗口碰巧叫的名字」当成了约定
# （旧写法 ${pmwin:-${det_win:-$TEAM_PM_WINDOW}}）。窗口后来一改名，配置和现场就互相撒谎：面板报
# 「PM 窗口缺失」而 PM 明明活着，照着提示 up 还会另开一个窗口（两个 PM）。
# 这一节钉死两件事：写进配置的永远是约定（pm），当前窗口顺手对到约定上；医生要能把漂移说成人话。
#
# 假 tmux：回答「当前窗口叫什么 / session 里有哪些窗口 / 哪个 pane 里跑着谁」，并把每次调用记进日志。
# 真 tmux 会碰调用者自己的现场，而这里要证明的是「工具下了什么命令」，所以用 shim
# （与 §2 的空目标 send_text 夹具同族；rename 真的落地由本节 ⑥ 的真沙盒窗口证明）。
M11_SHIM="$TMP/m11-shim"; mkdir -p "$M11_SHIM"
cat > "$M11_SHIM/tmux" <<'M11SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${M11_SHIM_LOG:-/dev/null}"
case "${1:-}" in
  display-message)
    case "$*" in
      *pane_pid*)
        case "$*" in
          *":${M11_SHIM_PANE_WIN:-pm}"*) printf '%s\n' "${M11_SHIM_PANE_PID:-1}" ;;
          *) printf '1\n' ;;
        esac ;;
      *window_name*)       printf '%s\n' "${M11_SHIM_WIN:-pm}" ;;
      *session_name*)      printf '%s\n' "${M11_SHIM_SESSION:-m11-shim}" ;;
      *pane_current_path*) printf '%s\n' "${M11_SHIM_CWD:-/tmp}" ;;
      *)                   printf '\n' ;;
    esac ;;
  list-windows) printf '%s\n' ${M11_SHIM_WINDOWS:-pm} ;;
  # M37：共享的 pane 进程树扫描改用 list-panes（display-message 找不到窗口时会静默回退到当前窗口，
  # 不能当证据）。shim 必须回答工具真正问的查询，否则「工具下了什么命令」就无从证明。
  list-panes)
    case "$*" in
      *":${M11_SHIM_PANE_WIN:-pm}"*) printf '1 %s\n' "${M11_SHIM_PANE_PID:-1}" ;;
      *) printf '1 1\n' ;;
    esac ;;
  has-session)  [ "${M11_SHIM_HAS_SESSION:-1}" = "1" ] || exit 1 ;;
esac
exit 0
M11SHIM
chmod +x "$M11_SHIM/tmux"
m11_repo() { # <目录>：一个新的 git 仓库（bootstrap 要能写配置）
  rm -rf "$1"; mkdir -p "$1"
  ( cd "$1" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
      && echo "# $1" > README.md && git add -A && git commit -qm init )
}
m11_boot() { # <仓库> <session> <当前窗口名> <标记> [额外参数...]
  local repo="$1" sess="$2" win="$3" tag="$4"; shift 4
  : > "$TMP/m11-calls-$tag.log"
  ( cd "$repo" && PATH="$M11_SHIM:$PATH" TMUX=/m11-fake TMUX_PANE=%1 \
      M11_SHIM_LOG="$TMP/m11-calls-$tag.log" M11_SHIM_WIN="$win" M11_SHIM_SESSION="$sess" \
      M11_SHIM_CWD="$repo" M11_SHIM_WINDOWS="$win" \
      $TEAM bootstrap --agents dev --session "$sess" --no-pulse "$@" ) >"$TMP/m11-boot-$tag.log" 2>&1
}

# ① --print 只看计划：不改名、不改文件，计划里的 PM 窗口名已经是约定 pm
M11A="$TMP/m11-print-repo"; m11_repo "$M11A"
m11_boot "$M11A" m11-print-sess pi print --print \
  && ok "M11 ①：--print 退出码 0" || { bad "M11 ①：--print 失败"; tail -5 "$TMP/m11-boot-print.log"; }
assert_has "$TMP/m11-boot-print.log" "--pm-window pm" "M11 ①：计划里的 PM 窗口名是约定 pm"
assert_has "$TMP/m11-boot-print.log" "rename-window -t m11-print-sess:pi pm" "M11 ①：--print 给出确切的改名命令"
assert_not "$TMP/m11-calls-print.log" "rename-window" "M11 ①：--print 一个键都没按"
assert_not_file "$M11A/.pi/team/config.sh" "M11 ①：--print 没写配置"

# ② 当前窗口叫 pi：配置必须写 pm，并把当前窗口改名成 pm（约定 > 现场）
M11B="$TMP/m11-conv-repo"; m11_repo "$M11B"
m11_boot "$M11B" m11-conv-sess pi conv \
  && ok "M11 ②：bootstrap 退出码 0" || { bad "M11 ②：bootstrap 失败"; tail -5 "$TMP/m11-boot-conv.log"; }
assert_has "$M11B/.pi/team/config.sh" 'TEAM_PM_WINDOW="pm"' "M11 ②：配置写的是约定 pm，不是当前窗口 pi"
assert_has "$TMP/m11-calls-conv.log" "rename-window -t m11-conv-sess:pi pm" "M11 ②：下了确切的改名命令"
assert_has "$TMP/m11-boot-conv.log" "当前窗口 pi → pm" "M11 ②：输出里说明改了名"

# ③ 窗口已经叫 pm：什么都不用动（幂等、不乱按键）
M11C="$TMP/m11-same-repo"; m11_repo "$M11C"
m11_boot "$M11C" m11-same-sess pm same
assert_has "$M11C/.pi/team/config.sh" 'TEAM_PM_WINDOW="pm"' "M11 ③：本来就一致时也写 pm"
assert_not "$TMP/m11-calls-same.log" "rename-window" "M11 ③：一致时不改任何名字"

# ④ --pm-window 是人给的约定：写配置照给，但**不**替人搬窗口（只打印命令）
M11D="$TMP/m11-explicit-repo"; m11_repo "$M11D"
m11_boot "$M11D" m11-exp-sess pi explicit --pm-window tool
assert_has "$M11D/.pi/team/config.sh" 'TEAM_PM_WINDOW="tool"' "M11 ④：显式 --pm-window 照给"
assert_not "$TMP/m11-calls-explicit.log" "rename-window" "M11 ④：只有 pm 这个约定才代改名，别的名字只打印命令"
assert_has "$TMP/m11-boot-explicit.log" "改名：tmux rename-window -t m11-exp-sess:pi tool" "M11 ④：打印出确切的改名命令"

# ⑤ doctor：配置说 pi、现场窗口 pm 里跑着配置的 PM CLI → 说人话报警（并且不劝人直接 up）
M11E="$TMP/m11-drift-repo"; m11_repo "$M11E"
mkdir -p "$M11E/.pi/team" "$M11E/docs/team"
printf 'TEAM_PROJECT="m11-drift"\nTEAM_SESSION="m11-drift-sess"\nTEAM_PM_WINDOW="pi"\nTEAM_AGENTS="dev"\nTEAM_DOCS_DIR="docs/team"\nTEAM_PI_BIN="sleep"\n' \
  > "$M11E/.pi/team/config.sh"
( cd "$M11E" && exec sleep 300 ) & M11_PID=$!   # 真进程顶替 PM CLI：argv（sleep）与 cwd（本项目）都是真的
sleep 0.3
m11_drift_doctor() { # <配置里的 PM 窗口名> <日志文件>
  sed -i "s|^TEAM_PM_WINDOW=.*|TEAM_PM_WINDOW=\"$1\"|" "$M11E/.pi/team/config.sh"
  ( cd "$M11E" && PATH="$M11_SHIM:$PATH" M11_SHIM_LOG="$TMP/m11-doctor-calls.log" \
      M11_SHIM_WIN=pm M11_SHIM_SESSION=m11-drift-sess M11_SHIM_WINDOWS="pm bash" \
      M11_SHIM_PANE_WIN=pm M11_SHIM_PANE_PID="$M11_PID" $TEAM doctor ) >"$2" 2>&1 || true
}
m11_drift_doctor pi "$TMP/m11-doctor-drift.log"
assert_has "$TMP/m11-doctor-drift.log" "PM 窗口名" "M11 ⑤：doctor 有「PM 窗口名」这一条"
assert_has "$TMP/m11-doctor-drift.log" "改名漂移" "M11 ⑤：点明是改名漂移（不是笼统的「窗口缺失」）"
assert_has "$TMP/m11-doctor-drift.log" "在跑 PM 的窗口叫 'pm'" "M11 ⑤：点名现场窗口"
assert_has "$TMP/m11-doctor-drift.log" "rename-window -t m11-drift-sess:pm pi" "M11 ⑤：给出对齐名字的确切命令"
assert_has "$TMP/m11-doctor-drift.log" "两个 PM" "M11 ⑤：点明直接 up 的后果（会开出第二个 PM）"
m11_drift_doctor pm "$TMP/m11-doctor-ok.log"
assert_not "$TMP/m11-doctor-ok.log" "改名漂移" "M11 ⑤（负对照）：配置与现场一致时不刷漂移行"
kill "$M11_PID" 2>/dev/null || true

# ⑥ 真沙盒：窗口碰巧叫 pi 的 session 里跑 bootstrap —— 配置写 pm，窗口真的被 rename-window 改掉。
# ⑤ 用的是假 tmux（证明命令），这里用真 tmux（证明落地）：两条一起才叫「顺手改了名」。
if [ "$FAST" = "1" ]; then
  fast_skip "1c·M11 真沙盒窗口" "要真实 tmux 窗口（假 tmux 证明不了 rename-window 真的落地）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  M11L="$TMP/m11-live-repo"; m11_repo "$M11L"
  M11_SESS="teamsmith-smoke-m11-$$"
  tmux kill-session -t "$M11_SESS" 2>/dev/null || true
  tmux new-session -d -s "$M11_SESS" -n pi -c "$M11L" 2>/dev/null || true
  tmux set-window-option -t "$M11_SESS:pi" automatic-rename off 2>/dev/null || true
  tmux respawn-pane -k -t "$M11_SESS:pi" \
    "cd '$M11L' && bash '$SKILL_DIR/scripts/team' bootstrap --agents dev --session $M11_SESS --no-pulse >'$TMP/m11-live.log' 2>&1; echo \$? >'$TMP/m11-live.rc'; exec sleep 300"
  for i in $(seq 1 80); do [ -s "$TMP/m11-live.rc" ] && break; sleep 0.25; done
  assert_eq "M11 ⑥（真沙盒）：bootstrap 退出码 0" "$(tr -dc 0-9 < "$TMP/m11-live.rc" 2>/dev/null)" "0"
  assert_has "$M11L/.pi/team/config.sh" 'TEAM_PM_WINDOW="pm"' "M11 ⑥（真沙盒）：配置写约定 pm（不是窗口碰巧的名字）"
  assert_eq "M11 ⑥（真沙盒）：窗口真的被改名成 pm" \
    "$(tmux list-windows -t "$M11_SESS" -F '#{window_name}' 2>/dev/null | tr '\n' ' ')" "pm "
  assert_has "$TMP/m11-live.log" "当前窗口 pi → pm" "M11 ⑥（真沙盒）：输出里说了改名"
  tmux kill-session -t "$M11_SESS" 2>/dev/null || true
else
  printf '  \033[2m·\033[0m %s\n' "（无 tmux：跳过 M11 真沙盒夹具）"
fi
cd "$REPO"

# ---------------------------------------------------------------- 2. init
section "2 · init"
$TEAM init --session "$SESSION" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$TMP/init.log" 2>&1 \
  && ok "init 退出码 0" || bad "init 失败（见 $TMP/init.log）"
assert_file "$REPO/.pi/team/config.sh" "写入配置"
assert_file "$REPO/docs/team/BOARD.md" "写入 BOARD"
assert_file "$REPO/docs/team/OWNERSHIP.md" "写入 OWNERSHIP"
assert_file "$REPO/docs/team/DECISIONS.md" "写入 DECISIONS"
assert_file "$REPO/docs/team/PROTOCOL.md" "写入 PROTOCOL"
# M6.3：agent 读的第一份文件（AGENTS 协议段 + PROTOCOL）必须告诉它 specs 在哪。
# OpenSpec 是必需依赖，但以前只写在 SKILL.md/references 里 —— 新项目从来不会知道。
assert_has "$REPO/AGENTS.md" "Specs (OpenSpec)" "AGENTS.md 协议段指向 openspec/"
assert_has "$REPO/AGENTS.md" "openspec init --tools none" "AGENTS.md 给出建 spec 目录的命令"
assert_has "$REPO/AGENTS.md" "openspec validate --all --strict" "AGENTS.md 写明 OpenSpec 校验是门禁的一部分"
assert_has "$REPO/AGENTS.md" "parallel spec system" "AGENTS.md 禁止另建一套 spec 系统"
assert_has "$REPO/docs/team/PROTOCOL.md" "openspec change show" "PROTOCOL.md 给出日常 OpenSpec 命令"
assert_has "$REPO/docs/team/PROTOCOL.md" "openspec archive -y" "PROTOCOL.md 说明归档命令"
assert_has "$REPO/docs/team/PROTOCOL.md" "references/openspec.md" "PROTOCOL.md 指向 references/openspec.md"
assert_file "$REPO/docs/team/threads/README.md" "写入 threads/README"
assert_has "$REPO/AGENTS.md" "<!-- teamsmith:begin -->" "AGENTS.md 注入协议段"
assert_has "$REPO/.gitignore" ".worktrees/" ".gitignore 忽略 worktree"
# P40：init 的安装步 —— 两条软链装进项目 .pi/skills/，.gitignore 跟着忽略它
# （本仓已跟踪的 .pi/skills/openspec-* 不受影响：忽略行不会 untrack 已跟踪文件）
assert_eq "P40 init 装了项目 skill：.pi/skills/teamsmith → 运行树" \
  "$(readlink -f "$REPO/.pi/skills/teamsmith" 2>/dev/null || echo missing)" "$SKILL_DIR"
assert_eq "P40 init 装了兄弟条目 teamsmith-init" \
  "$(readlink -f "$REPO/.pi/skills/teamsmith-init" 2>/dev/null || echo missing)" "$SKILL_INIT_DIR"
assert_has "$REPO/.gitignore" ".pi/skills/" "P40 .gitignore 忽略项目 skill 安装目录"
assert_eq "P40 .pi/skills/ 里恰好两条" "$(ls -1A "$REPO/.pi/skills" | wc -l)" "2"

# 隔离自检（关键）：team 必须把自己当成临时仓库 + 本测试 session
ISOLATE="$($TEAM paths 2>/dev/null || true)"
if printf '%s' "$ISOLATE" | grep -qF "\"main_root\": \"$REPO\"" \
   && printf '%s' "$ISOLATE" | grep -qF "\"session\": \"$SESSION\""; then
  ok "身份隔离：team 认的是临时仓库 + 本测试 session"
else
  bad "身份隔离失败（team 认错项目/session）：$ISOLATE"
  printf '\n=== 中止：为避免误伤真实项目/session，不再继续跑 ===\n' >&2
  exit 1
fi

# ③ 安全守卫：继承的环境不能改变「根 / 配置 / session」；空目标必须被拒
FAKE_ROOT="$TMP/foreign"; mkdir -p "$FAKE_ROOT/.pi/team"   # 造一个"别的项目"（真 git 仓库，最贴近现实）
( cd "$FAKE_ROOT" && git init -q -b main && git commit -q --allow-empty -m x )
printf 'TEAM_PROJECT="foreign"\nTEAM_SESSION="foreign-session"\nTEAM_AGENTS="intruder"\n' > "$FAKE_ROOT/.pi/team/config.sh"
( cd "$REPO" && TEAM_ROOT="$FAKE_ROOT" $TEAM paths ) >"$TMP/paths-inherit.log" 2>&1 || true
assert_has "$TMP/paths-inherit.log" "\"main_root\": \"$REPO\"" "继承的 TEAM_ROOT 不生效：根仍取 cwd 的仓库"
( cd "$REPO" && TEAM_ROOT="$FAKE_ROOT" $TEAM up ) >"$TMP/guard-foreign-up.log" 2>&1; RC3=$?
assert_eq "在别的项目里做破坏性操作（up）被拒" "$([ "$RC3" -ne 0 ] && echo yes || echo no)" "yes"
assert_has "$TMP/guard-foreign-up.log" "被拒" "拒绝时说明了原因（并给授权方式）"
assert_not "$TMP/paths-inherit.log" "intruder" "名册不会从继承的别的项目里读"
tmux kill-session -t foreign-session 2>/dev/null || true   # 万一被建出来，清理掉（测试不该留下东西）
# 空目标 = 当前窗口/会话（tmux 的 `-t ""` 语义），必须拒绝
( . "$SKILL_DIR/scripts/lib/common.sh"; team_tmux_kill_window "" ) >"$TMP/guard-empty.log" 2>&1; RC=$?
assert_eq "空目标的 kill-window 被拒（退出码 1）" "$RC" "1"
assert_has "$TMP/guard-empty.log" "目标为空" "空目标拒绝有明确说明"
( . "$SKILL_DIR/scripts/lib/common.sh"; team_tmux_respawn_pane "" true ) >"$TMP/guard-empty2.log" 2>&1; RC2=$?
assert_eq "空目标的 respawn-pane 被拒（退出码 1）" "$RC2" "1"
# M6.3 F27：send_text（say/notify/nudge 的打字通道）过去是这一族里的例外。
# 这里用「记录调用的 tmux shim」证明拒绝发生在调用 tmux **之前** —— 探针永远不可能落地，
# 而且不需要真 tmux（快模式照跑）。`-t ""` 的语义是「当前 pane」，所以这条断言不许用真 tmux。
mkdir -p "$TMP/tmux-shim"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit 0\n' "$TMP/tmux-shim.log" > "$TMP/tmux-shim/tmux"
chmod +x "$TMP/tmux-shim/tmux"
( PATH="$TMP/tmux-shim:$PATH"; . "$SKILL_DIR/scripts/lib/common.sh"; team_tmux_send_text "" "EMPTY-TARGET-PROBE" ) >"$TMP/guard-empty-send.log" 2>&1; RCE=$?
assert_eq "空目标的 send_text 被拒（退出码 1）" "$RCE" "1"
assert_has "$TMP/guard-empty-send.log" "目标为空" "send_text 空目标拒绝有明确说明"
assert_not_file "$TMP/tmux-shim.log" "空目标探针没有到达 tmux（拒绝在调用之前）"
( PATH="$TMP/tmux-shim:$PATH"; . "$SKILL_DIR/scripts/lib/common.sh"; team_tmux_send_text "   " "WS-TARGET-PROBE" ) >"$TMP/guard-ws-send.log" 2>&1; RCW=$?
assert_eq "纯空白目标的 send_text 被拒（退出码 1）" "$RCW" "1"
assert_has "$TMP/guard-ws-send.log" "空白" "纯空白目标拒绝有明确说明"
assert_not_file "$TMP/tmux-shim.log" "纯空白目标的探针也没有到达 tmux"
# 探测守卫：在「别的项目」的 tmux pane 里 bootstrap，不许把对方的 session 当成自己的
PROBE="$TMP/probe-repo"; mkdir -p "$PROBE"; ( cd "$PROBE" && git init -q -b main && git commit -q --allow-empty -m x )
( cd "$PROBE" && $TEAM bootstrap --agents dev --no-watchdog --print ) >"$TMP/boot-probe.log" 2>&1 || true
if [ "${HAVE_TMUX:-0}" = "1" ] && [ -n "${TMUX:-}" ]; then
  assert_has "$TMP/boot-probe.log" "不属于本项目" "探测守卫：不认别的项目的 tmux session"
else
  if [ "${HAVE_TMUX:-0}" = "1" ]; then
    printf '  \033[2m·\033[0m %s\n' "（本机有 tmux，但调用者不在 tmux 会话里：跳过探测守卫断言）"
  else
    printf '  \033[2m·\033[0m %s\n' "（无 tmux：跳过探测守卫断言）"
  fi
fi
assert_has "$REPO/.gitignore" "docs/team/inbox/" ".gitignore 忽略收件箱"
assert_has "$REPO/.gitignore" ".pi/team/state/" ".gitignore 忽略运行时状态"
# 模板渲染不能有残留占位符
if grep -rqF '{{' "$REPO/docs/team" "$REPO/.pi/team/config.sh" "$REPO/AGENTS.md" 2>/dev/null; then
  bad "模板有未渲染的占位符 {{...}}"; grep -rnF '{{' "$REPO/docs/team" "$REPO/AGENTS.md" | head -3
else ok "模板全部渲染（无 {{ 残留）"; fi
# 幂等：再 init 一次不应重复追加协议段
$TEAM init --session "$SESSION" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$TMP/init-again.log" 2>&1
assert_eq "AGENTS.md 协议段幂等（只出现一次）" "$(grep -cF '<!-- teamsmith:begin -->' "$REPO/AGENTS.md")" "1"
# P40：第二次 init 不重装、不覆盖 —— 两个 skill 都报 skip（逐 skill 一行）
assert_eq "P40 第二次 init 对两个 skill 都报 skip" \
  "$(grep -cE '^  skip  .*/\.pi/skills/(teamsmith|teamsmith-init)（' "$TMP/init-again.log" || true)" "2"
assert_eq "P40 第二次 init 后 .pi/skills/ 仍然只有两条" "$(ls -1A "$REPO/.pi/skills" | wc -l)" "2"

# 必需依赖（D10）的确定性夹具：magic-context 用假 settings + 假包，OpenSpec 用假 CLI + 假 spec 目录。
# 都在 $TMP 下、用绝对路径 —— 本机装没装都不影响断言。
M51_AGENT="$TMP/m51-agent"; mkdir -p "$M51_AGENT/npm/node_modules/@cortexkit/pi-magic-context"
printf '{"packages":["npm:@cortexkit/pi-magic-context"]}\n' > "$M51_AGENT/settings.json"
printf '{"name":"@cortexkit/pi-magic-context","version":"9.9.9"}\n' > "$M51_AGENT/npm/node_modules/@cortexkit/pi-magic-context/package.json"
M51_SPEC="$TMP/m51-spec"; mkdir -p "$M51_SPEC"
cat > "$FAKE/openspec" <<'OPSEOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && printf 'openspec 9.9.9 (smoke-fake)\n'
exit 0
OPSEOF
chmod +x "$FAKE/openspec"
{
  printf 'TEAM_PI_SETTINGS_FILE="%s"\n' "$M51_AGENT/settings.json"
  printf 'TEAM_OPENSPEC_BIN="%s"\n' "$FAKE/openspec"
  printf 'TEAM_SPEC_DIR="%s"\n' "$M51_SPEC"
} >> "$REPO/.pi/team/config.sh"

git add -A && git commit -qm "chore: teamsmith init" && ok "提交 init 产物（PM 的文档要入库）"

section "3 · doctor（初始化后）"
if $TEAM doctor >"$TMP/doctor.log" 2>&1; then ok "doctor 通过"; else bad "doctor 失败"; cat "$TMP/doctor.log"; fi
assert_has "$TMP/doctor.log" "notify 扩展" "doctor 检查了 notify 扩展"
assert_has "$TMP/doctor.log" "PM 记忆 magic-context" "doctor 检查 PM 记忆（必需依赖）"
assert_match "$TMP/doctor.log" "magic-context [0-9]" "装了 → 报版本"
assert_has "$TMP/doctor.log" "OpenSpec CLI" "doctor 检查 OpenSpec CLI"
assert_has "$TMP/doctor.log" "OpenSpec 规格目录" "doctor 检查 spec 目录"

# M38/M39：0.76.0–0.79.0 的 pi 把 `--help` 写到 stderr —— 探针必须看两个流，否则把够用的版本
# 假报成「版本过旧」。夹具：一个 --help 只写 stderr 的 pi 桩，doctor 不得出现「版本过旧」。
FAKE_PI2="$TMP/fake-pi-stderr"; mkdir -p "$FAKE_PI2"
cat > "$FAKE_PI2/pi" <<'EOS'
#!/usr/bin/env bash
case "${1:-}" in
  --help|-h) printf 'usage: pi [--session-id <id>] [-e <ext>]\n' >&2 ;;
  --version|-v) printf 'pi 0.76.0\n' ;;
esac
exit 0
EOS
chmod +x "$FAKE_PI2/pi"
PATH="$FAKE_PI2:$PATH" $TEAM doctor >"$TMP/doctor-help-stderr.log" 2>&1 || true
assert_not "$TMP/doctor-help-stderr.log" "版本过旧" "M39：--help 走 stderr 的 pi 不再被误报「版本过旧」（探针看两流）"

# ---------------------------------------------------------------- 4. task / board
section "4 · task + board"
$TEAM task T1.1 --title "Smoke task" --agent dev --deps "-" >"$TMP/task.log" 2>&1 || bad "task 失败"
TASKFILE="$(ls "$REPO"/docs/team/tasks/T1.1-*.md 2>/dev/null | head -1)"
# P24（B3）：派单守卫要求「没有 change 的任务书必须声明锚」。模板渲染的 `anchor: -` 是待填空，
# 夹具在这里补上 infra 锚 —— 否则本节要测的（分支身份/脏树/容量/提示词/adapter）根本走不到守卫之后。
sed -i 's|^anchor: -.*$|anchor: none (infra) — smoke fixture (test scaffolding, no product requirement)|' "$TASKFILE"
assert_file "$TASKFILE" "生成任务书"
assert_has "$TASKFILE" "agent:  dev" "任务书含 agent 字段"
assert_has "$TASKFILE" "true" "任务书写入门禁命令"
assert_eq "BOARD 建行（todo）" "$($TEAM board row T1.1 2>/dev/null | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$(NF-1)); print $(NF-1)}' || true)" "todo"

# ---------------------------------------------------------------- 4b. 状态诚实（M6.1 F29/F1）
section "4b · 状态诚实：未知 id 不假装写入 + done 要证据（M6.1 F29/F1）"
BOARD_BEFORE="$(md5sum "$REPO/docs/team/BOARD.md" | cut -d' ' -f1)"
if $TEAM board set NOSUCH done >"$TMP/board-nosuch.log" 2>&1; then bad "未知 id 写 BOARD 应当失败"; else ok "未知 id 写 BOARD 被拒（非 0）"; fi
assert_has "$TMP/board-nosuch.log" "BOARD 里没有 NOSUCH" "报错点明是未知 id"
assert_has "$TMP/board-nosuch.log" "board add" "给出新增行的办法"
assert_not "$TMP/board-nosuch.log" "✓ board NOSUCH" "没有打印成功行"
assert_eq "未知 id 的写入真的没碰文件" "$(md5sum "$REPO/docs/team/BOARD.md" | cut -d' ' -f1)" "$BOARD_BEFORE"
# done 的闸门：既没有复验记录、分支也没落地 → 拒绝
if env TEAM_BOARD_DONE_FORCE=0 $TEAM board set T1.1 done >"$TMP/done-nogate.log" 2>&1; then bad "没有证据也允许 done"; else ok "没有证据时 done 被拒（非 0）"; fi
assert_has "$TMP/done-nogate.log" "复验记录" "说明检查了复验记录"
assert_has "$TMP/done-nogate.log" "分支是否已并入" "说明检查了分支是否落地"
assert_has "$TMP/done-nogate.log" "TEAM_BOARD_DONE_FORCE" "给出 PM 覆盖方式"
assert_eq "被拒的 done 没有改状态" "$(board_status T1.1)" "todo"
# 判定 FAIL 的复验记录不算证据
mkdir -p "$REPO/docs/team/reviews"
printf '# T1.1 · PM 独立复验\n\n时间: 2026-01-01T00:00:00Z · 判定: **FAIL**\n' > "$REPO/docs/team/reviews/T1.1.md"
if env TEAM_BOARD_DONE_FORCE=0 $TEAM board set T1.1 done >"$TMP/done-fail.log" 2>&1; then bad "FAIL 的复验记录被当成证据"; else ok "FAIL 的复验记录不算证据"; fi
assert_has "$TMP/done-fail.log" "FAIL" "报错点名判定的问题"
rm -f "$REPO/docs/team/reviews/T1.1.md"
# 覆盖必须给理由；给了才允许，而且落盘审计
if env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="" $TEAM board set T1.1 done >"$TMP/done-noreason.log" 2>&1; then bad "覆盖没给理由也允许"; else ok "覆盖没给理由被拒"; fi
assert_has "$TMP/done-noreason.log" "TEAM_BOARD_DONE_REASON" "报错要求写理由"
env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="smoke: 手工确认" $TEAM board set T1.1 done >"$TMP/done-force.log" 2>&1 \
  && ok "给了理由的覆盖 → 允许 done" || bad "给了理由的覆盖仍被拒"
assert_eq "覆盖后状态是 done" "$(board_status T1.1)" "done"
assert_file "$REPO/docs/team/reviews/T1.1-done.md" "done 写审计文件"
assert_has "$REPO/docs/team/reviews/T1.1-done.md" "FORCED" "覆盖记成 FORCED"
assert_has "$REPO/docs/team/reviews/T1.1-done.md" "smoke: 手工确认" "覆盖理由落盘"
$TEAM board set T1.1 todo >/dev/null 2>&1
# 或条件②：分支 tip 已经在保护分支里（**且分支的提交里有一份报告**，M9.6）→ 没有复验记录也允许
# （正对照：闸门不是「一律拒绝」；零提交的空分支是 M9.6 的反面夹具，见第 24 节）
git -C "$REPO" branch task/T9.8-ancestor "$PROTECTED" >/dev/null 2>&1
$TEAM board add T9.8 "ancestor case" dev "-" >/dev/null 2>&1
# 夹具：分支上真的干过活（一份提交进 git 的报告），再 fast-forward 进保护分支
m96_anc_wt="$TMP/done-ancestor-wt"
git -C "$REPO" worktree remove --force "$m96_anc_wt" >/dev/null 2>&1 || true
git -C "$REPO" worktree add -q "$m96_anc_wt" task/T9.8-ancestor
mkdir -p "$m96_anc_wt/docs/team/reports"
printf '# T9.8 · smoke\n\nreport (M9.6 fixture)\n' > "$m96_anc_wt/docs/team/reports/T9.8-dev.md"
git -C "$m96_anc_wt" add -- docs/team/reports/T9.8-dev.md >/dev/null 2>&1
git -C "$m96_anc_wt" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "docs(T9.8): report (M9.6 fixture)" >/dev/null 2>&1
git -C "$REPO" worktree remove --force "$m96_anc_wt" >/dev/null 2>&1 || true
if git -C "$REPO" merge -q --ff-only task/T9.8-ancestor >/dev/null 2>&1; then :; else bad "夹具：T9.8 的分支没能 fast-forward 进 $PROTECTED"; fi
env TEAM_BOARD_DONE_FORCE=0 $TEAM board set T9.8 done >"$TMP/done-ancestor.log" 2>&1 \
  && ok "分支已并入保护分支 → 允许 done" || bad "条件② 没生效（分支真的落地了却被拒）"
assert_has "$TMP/done-ancestor.log" "已经是 main 的祖先" "成功输出写明证据是分支落地"
assert_has "$TMP/done-ancestor.log" "T9.8-dev.md" "成功输出点名分支里那份已提交的报告（M9.6）"

# ---------------------------------------------------------------- 4c. 看板重复 ID（M48）
section "4c · 看板重复 ID（M48）：add 拒绝 / --allow-dup / 三处可见"
M48_BOARD="$REPO/docs/team/BOARD.md"
M48_BAK="$TMP/m48-board.bak"
cp "$M48_BOARD" "$M48_BAK"
M48_BEFORE="$(md5sum "$M48_BOARD" | cut -d' ' -f1)"
# 拒绝路径：T1.1 已在表里 → 再 add 一个同 ID 必须非 0、点名状态与标题、给出两条出路，且一个字节都不写
if $TEAM board add T1.1 "重复的一条" dev - >"$TMP/m48-dup.log" 2>&1; then bad "M48：重复 ID 的 board add 应当被拒"; else ok "M48：重复 ID 被拒（非 0）"; fi
assert_has "$TMP/m48-dup.log" "BOARD 里已经有 T1.1" "M48：报错点名已存在的 ID"
assert_has "$TMP/m48-dup.log" "Smoke task" "M48：报错点名已存在那一行的标题"
assert_has "$TMP/m48-dup.log" "状态 todo" "M48：报错点名已存在那一行的状态"
assert_has "$TMP/m48-dup.log" "改 ID" "M48：给出第一条出路（改 ID 里程碑编号）"
assert_has "$TMP/m48-dup.log" "--allow-dup" "M48：给出第二条出路（显式旗标）"
assert_has "$TMP/m48-dup.log" "watchdog.log" "M48：说明旗标会留审计"
assert_has "$TMP/m48-dup.log" "board assign" "M48：拒绝时给出「指派 agent」的正确入口（不许逼人用 add 撞）"
assert_not "$TMP/m48-dup.log" "✓ board add" "M48：被拒时不打印成功行"
assert_eq "M48：被拒时 BOARD 逐字节未变" "$(md5sum "$M48_BOARD" | cut -d' ' -f1)" "$M48_BEFORE"
assert_eq "M48：被拒时没有多出同 ID 行" "$(grep -c '^| T1\.1 ' "$M48_BOARD")" "1"
# 未知旗标照旧拒绝（别借新旗标把参数校验放松了）
if $TEAM board add T1.2 "未知旗标" dev - --nope >"$TMP/m48-badflag.log" 2>&1; then bad "M48：未知旗标应当被拒"; else ok "M48：未知旗标被拒（非 0）"; fi
assert_has "$TMP/m48-badflag.log" "未知参数 --nope" "M48：报错点名未知旗标"
assert_eq "M48：未知旗标时 BOARD 也没变" "$(md5sum "$M48_BOARD" | cut -d' ' -f1)" "$M48_BEFORE"
# 显式旗标：允许写，并往 state/watchdog.log 落一条审计
$TEAM board add T1.1 "重复的一条" dev - --allow-dup >"$TMP/m48-allow.log" 2>&1 \
  && ok "M48：--allow-dup 显式允许写入" || bad "M48：--allow-dup 应当允许写入"
assert_has "$TMP/m48-allow.log" "--allow-dup" "M48：成功输出点明是显式允许"
assert_eq "M48：旗标之后 T1.1 真的有两行" "$(grep -c '^| T1\.1 ' "$M48_BOARD")" "2"
assert_has "$REPO/.pi/team/state/watchdog.log" "T1.1" "M48：审计落在 state/watchdog.log"
assert_has "$REPO/.pi/team/state/watchdog.log" "allow-dup" "M48：审计写明是 --allow-dup"
# 指派 agent 的正门（PM 追加）：给已有行指派 → 只改 agent 列、行数不变，而不是再写一行
M48_ROWS_BEFORE="$(grep -c '^| ' "$M48_BOARD")"
M48_T11_BEFORE="$(grep '^| T1\.1 ' "$M48_BOARD")"
if $TEAM board assign T1.1 reviewer >"$TMP/m48-assign.log" 2>&1; then ok "M48：board assign 给已有行指派成功"; else bad "M48：board assign 应当成功"; tail -3 "$TMP/m48-assign.log"; fi
assert_has "$TMP/m48-assign.log" "board assign T1.1 → reviewer" "M48：成功输出点名 ID 与 agent"
assert_eq "M48：assign 后行数不变（不是又加一行）" "$(grep -c '^| ' "$M48_BOARD")" "$M48_ROWS_BEFORE"
assert_eq "M48：assign 后 T1.1 仍是两行（没有顺手改历史数据）" "$(grep -c '^| T1\.1 ' "$M48_BOARD")" "2"
M48_T11_AFTER="$(grep '^| T1\.1 ' "$M48_BOARD")"
assert_eq "M48：assign 后 agent 列 = reviewer" "$(printf '%s\n' "$M48_T11_AFTER" | awk -F'|' '{v=$4; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}' | paste -sd,)" "reviewer,reviewer"
assert_eq "M48：assign 只改 agent 列（两行其余列逐字节未变）" \
  "$(printf '%s\n' "$M48_T11_AFTER" | awk -F'|' -v OFS='|' '{gsub(/^[ \t]+|[ \t]+$/,"",$4); $4=" agent "; print}')" \
  "$(printf '%s\n' "$M48_T11_BEFORE" | awk -F'|' -v OFS='|' '{gsub(/^[ \t]+|[ \t]+$/,"",$4); $4=" agent "; print}')"
# 与 board set 同语义：两者都按 ID 寻址，同 ID 的多行一起改（新增重复在门口就被拒，历史数据不动）
$TEAM board set T1.1 blocked >"$TMP/m48-set-dup.log" 2>&1 || bad "M48：同 ID 多行时 board set 应当可用"
assert_eq "M48：board set 也是 ID 寻址（同 ID 的两行状态一起变）" \
  "$(grep '^| T1\.1 ' "$M48_BOARD" | awk -F'|' '{v=$7; gsub(/^[ \t]+|[ \t]+$/,"",v); print v}' | paste -sd,)" "blocked,blocked"
# 未知 id / 参数不全：拒绝且一个字节都不落盘（与 board set 同风格）
M48_ASSIGN_SNAP="$(md5sum "$M48_BOARD" | cut -d' ' -f1)"
if $TEAM board assign NOSUCH dev >"$TMP/m48-assign-unknown.log" 2>&1; then bad "M48：未知 id 的 assign 应当被拒"; else ok "M48：未知 id 的 assign 被拒（非 0）"; fi
assert_has "$TMP/m48-assign-unknown.log" "BOARD 里没有 NOSUCH" "M48：assign 报错点名未知 id"
assert_eq "M48：未知 id 的 assign 不落盘" "$(md5sum "$M48_BOARD" | cut -d' ' -f1)" "$M48_ASSIGN_SNAP"
if $TEAM board assign T1.1 >"$TMP/m48-assign-noarg.log" 2>&1; then bad "M48：board assign 缺 agent 应当被拒"; else ok "M48：board assign 缺 agent 被拒（非 0）"; fi
assert_eq "M48：参数不全时也不落盘" "$(md5sum "$M48_BOARD" | cut -d' ' -f1)" "$M48_ASSIGN_SNAP"
# 可见性：board ls / digest / doctor 三处都说（面板/状态/报告按 ID 指行，重复不能只靠肉眼）
$TEAM board ls >"$TMP/m48-ls.log" 2>&1 || true
assert_has "$TMP/m48-ls.log" "BOARD 有重复 ID：T1.1 ×2" "M48：board ls 报告重复 ID 与行数"
$TEAM digest >"$TMP/m48-digest.log" 2>&1 || true
assert_has "$TMP/m48-digest.log" "BOARD 有重复 ID：T1.1 ×2" "M48：digest 报告重复 ID"
$TEAM doctor >"$TMP/m48-doctor.log" 2>&1 || true
assert_has "$TMP/m48-doctor.log" "BOARD 重复 ID" "M48：doctor 有「BOARD 重复 ID」这一条"
assert_has "$TMP/m48-doctor.log" "T1.1 ×2" "M48：doctor 列出重复的 ID 与行数"
# 负对照：把重复行去掉 → 三处都不再报（判据不是「总是红」）
awk '!(/^\| T1\.1 / && seen++)' "$M48_BOARD" > "$TMP/m48-clean.md" && mv "$TMP/m48-clean.md" "$M48_BOARD"
assert_eq "M48：夹具自检——去重后 T1.1 只剩一行" "$(grep -c '^| T1\.1 ' "$M48_BOARD")" "1"
$TEAM board ls >"$TMP/m48-ls2.log" 2>&1 || true
assert_not "$TMP/m48-ls2.log" "BOARD 有重复 ID" "M48（负对照）：没有重复时 board ls 不刷重复行"
$TEAM doctor >"$TMP/m48-doctor2.log" 2>&1 || true
assert_not "$TMP/m48-doctor2.log" "BOARD 重复 ID          !" "M48（负对照）：没有重复时 doctor 这一条是 ✓"
assert_has "$TMP/m48-doctor2.log" "BOARD 重复 ID" "M48（负对照）：doctor 仍然检查这一条"
# 模板里的占位行与风险表共用第 2 列，不能被误报成重复（init 出来的空看板必须干净）
M48_TMPREPO="$TMP/m48-tmpl"
mkdir -p "$M48_TMPREPO"
( cd "$M48_TMPREPO" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo '# m48' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
( cd "$M48_TMPREPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
    $TEAM init --session m48-tmpl --agents "dev" --vcs local --gates "true" --docs docs/team ) >"$TMP/m48-tmpl-init.log" 2>&1 \
  && ok "M48：空模板库 init 成功" || { bad "M48：空模板库 init 失败"; tail -3 "$TMP/m48-tmpl-init.log"; }
( cd "$M48_TMPREPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR \
    $TEAM board ls ) >"$TMP/m48-tmpl-ls.log" 2>&1 || true
assert_not "$TMP/m48-tmpl-ls.log" "BOARD 有重复 ID" "M48：空看板的占位行/风险表不算重复"
# 收尾：把看板恢复成夹具前的那一份（后面的段落读同一份 BOARD.md）
cp "$M48_BAK" "$M48_BOARD"
assert_eq "M48：段落结束把 BOARD.md 还原" "$(md5sum "$M48_BOARD" | cut -d' ' -f1)" "$M48_BEFORE"

# ---------------------------------------------------------------- 5. add-agent
section "5 · add-agent"
$TEAM add-agent dev --create --no-install >"$TMP/add.log" 2>&1 || bad "add-agent 失败"
assert_dir "$REPO/.worktrees/dev" "创建 agent worktree"
assert_eq "worktree 处于 detached（task 模式）" "$(git -C "$REPO/.worktrees/dev" rev-parse --abbrev-ref HEAD)" "HEAD"
assert_file "$REPO/.worktrees/dev/README.md" "worktree 内容就绪"

# ---------------------------------------------------------------- 6. dispatch
section "3b · git 归 PM（skill 不执行、也不过度包装 git）"
# add-agent 默认只打印 git 命令（不代建 worktree）
AG2="$TMP/gitfree-repo"; mkdir -p "$AG2"; ( cd "$AG2" && git init -q -b main && git config user.email a@b && git config user.name a && echo x > a && git add -A && git commit -qm init )
( cd "$AG2" && bash "$SKILL_DIR/scripts/team" init --session "teamsmith-smoke-gitfree-$$" --agents nobody >/dev/null 2>&1 ) || true
( cd "$AG2" && bash "$SKILL_DIR/scripts/team" add-agent nobody >"$TMP/addagent-print.log" 2>&1 ) || true
assert_has "$TMP/addagent-print.log" "worktree add -b agent/nobody" "add-agent 只打印 git worktree 命令"
assert_not_file "$AG2/.worktrees/nobody" "默认不代建 worktree"
( cd "$AG2" && bash "$SKILL_DIR/scripts/team" add-agent nobody --create --no-install >/dev/null 2>&1 ) || true
assert_dir "$AG2/.worktrees/nobody" "--create 才代建 worktree"
# merge / pr 已从 CLI 移除（不再包装 git/forge）
if $TEAM merge T1.1 >"$TMP/merge-gone.log" 2>&1; then bad "merge 应该已移除"; else ok "merge 命令已移除（git 由 PM 直接做）"; fi
assert_has "$TMP/merge-gone.log" "merge --squash" "merge 已移除时给替代做法"
assert_has "$TMP/merge-gone.log" "board set" "提示 BOARD 收尾前提"
if $TEAM pr T1.1 >/dev/null 2>&1; then bad "pr 应该已移除"; else ok "pr 命令已移除"; fi
if $TEAM gh pr list >"$TMP/gh-gone.log" 2>&1; then bad "team gh 应该已移除"; else ok "team gh 透传已移除"; fi
assert_has "$TMP/gh-gone.log" "直接用真实 gh" "gh 已移除时说明替代"

# 会话版本落后时，已移除的命令要顺带提示 /reload
$TEAM mark-loaded --version 1.0.0 >/dev/null 2>&1
$TEAM merge T1.1 >"$TMP/merge-gone-old.log" 2>&1 || true
assert_has "$TMP/merge-gone-old.log" "/reload" "版本落后时提示 /reload"
$TEAM mark-loaded >/dev/null 2>&1
assert_has "$SKILL_DIR/references/workflows.md" "git -C" "文档里给出 PM 直接跑的 git 步骤"

$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md --print >/dev/null 2>&1 || true
if $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md >"$TMP/dispatch-nobranch.log" 2>&1; then
  bad "工作树不在任务分支时 dispatch 应当拒绝"
else ok "工作树不在任务分支时 dispatch 拒绝"; fi
assert_match "$TMP/dispatch-nobranch.log" "switch -c task/|switch -c agent/" "给出了 PM 该跑的分支创建命令"
# 规范分支由实现计算（BOARD 标题 "Smoke task" → task/T1.1-smoke-task）
T1_BRANCH="$(canon_branch dev T1.1)"
git -C "$REPO/.worktrees/dev" switch -c "$T1_BRANCH" "$PROTECTED" >/dev/null 2>&1 || git -C "$REPO/.worktrees/dev" switch "$T1_BRANCH" >/dev/null 2>&1
$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md --print >"$TMP/print-branch.log" 2>&1 && ok "PM 建好分支后 dispatch 可用" || bad "建好分支后 dispatch 仍失败"
echo dirty > "$REPO/.worktrees/dev/dirty.txt"
if $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md >"$TMP/dispatch-dirty.log" 2>&1; then bad "脏工作树应当拒绝派单"; else ok "脏工作树拒绝派单"; fi
assert_has "$TMP/dispatch-dirty.log" "git 归 PM" "说明 git 归 PM"
rm -f "$REPO/.worktrees/dev/dirty.txt"
# M6.3 F16：停在**别的任务**的分支上必须拒绝，点名两个分支，并给出确切的切换命令。
# （旧实现只查脏/保护分支/detached，干净工作树停在 task/T8.8-other 时会直接派单，
#   并把那个分支记成 T1.1 的复验目标。）
OTHER_BRANCH="task/T8.8-other"
git -C "$REPO/.worktrees/dev" switch -c "$OTHER_BRANCH" "$PROTECTED" >/dev/null 2>&1 || git -C "$REPO/.worktrees/dev" switch "$OTHER_BRANCH" >/dev/null 2>&1
if $TEAM dispatch dev T1.1 "$TASKFILE" >"$TMP/dispatch-wrongbranch.log" 2>&1; then
  bad "F16：工作树停在别的任务的分支上时 dispatch 应当拒绝"
else ok "F16：工作树停在别的任务的分支上 → dispatch 拒绝"; fi
assert_has "$TMP/dispatch-wrongbranch.log" "$OTHER_BRANCH" "F16：报错点名了工作树当前的分支"
assert_has "$TMP/dispatch-wrongbranch.log" "$T1_BRANCH" "F16：报错点名了本任务的规范分支"
assert_match "$TMP/dispatch-wrongbranch.log" "git -C .* switch" "F16：给出 PM 该跑的 git switch 命令"
assert_not "$TMP/dispatch-wrongbranch.log" "dispatched" "F16：没有真的派单"
# 例外：**续跑同一个任务**时允许旧 slug 的分支（标题改过 → 分支名漂移），
# 因为 state 里的 task 已经证明这条分支就是这个任务的；但不能借这个口子换任务。
git -C "$REPO/.worktrees/dev" switch "$T1_BRANCH" >/dev/null 2>&1 || true
git -C "$REPO/.worktrees/dev" switch -c "task/T1.1-legacy" "$PROTECTED" >/dev/null 2>&1 || git -C "$REPO/.worktrees/dev" switch "task/T1.1-legacy" >/dev/null 2>&1
( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_state_set dev task T1.1' )
if $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/dispatch-resume.log" 2>&1; then
  ok "F16：续跑同一个任务时允许旧 slug 的分支"
else bad "F16：续跑被误拒（见 $TMP/dispatch-resume.log）"; fi
assert_has "$TMP/dispatch-resume.log" "续跑" "F16：说明这是续跑（不是新派单）"
git -C "$REPO/.worktrees/dev" switch "$T1_BRANCH" >/dev/null 2>&1 || true
git -C "$REPO/.worktrees/dev" branch -D "task/T1.1-legacy" >/dev/null 2>&1 || true
# F3（P4 裁决）：base 场景原来说 `team status` 会显示 worktree —— 实测不显示（那个视图不存在）。场景已按现实
# 改写（本 change 的 MODIFIED 块），这里钉住现实的两半：roster 的行 = 工作树当时的分支 + 记录下来的任务；
# `team status <ID>` 打印同一行，外加该任务的看板行与报告行。
$TEAM roster >"$TMP/roster-branch.log" 2>&1 && ok "F3：roster 退出码 0" || bad "F3：roster 失败"
DEV_ROW="$(awk '$1=="dev"{print; exit}' "$TMP/roster-branch.log")"
case "$DEV_ROW" in
  *"$T1_BRANCH"*) ok "F3：roster 的 dev 行显示工作树当前的分支（$T1_BRANCH）" ;;
  *) bad "F3：roster 的 dev 行里没有 $T1_BRANCH（行=[$DEV_ROW]）" ;;
esac
case "$DEV_ROW" in
  *T1.1*) ok "F3：roster 的 dev 行显示记录下来的任务（state 里的 T1.1）" ;;
  *) bad "F3：roster 的 dev 行里没有 T1.1（行=[$DEV_ROW]）" ;;
esac
$TEAM status T1.1 >"$TMP/status-branch.log" 2>&1 || true
assert_eq "F3：team status 打印的是同一份 roster 行" \
  "$(awk '$1=="dev"{print; exit}' "$TMP/status-branch.log")" "$DEV_ROW"
assert_has "$TMP/status-branch.log" "任务 T1.1：" "F3：team status 打印该任务的标题行"
assert_has "$TMP/status-branch.log" "报告" "F3：team status 打印该任务的报告行"
[ -f "$REPO/.pi/team/state/dev.env" ] && sed -i '/^task=T1.1$/d' "$REPO/.pi/team/state/dev.env" || true
# M6.3 F15：项目外的任务书必须被拒。旧行为：--print 成功，还把 /tmp/x.md 标成 "repo-relative
# path"；而同一份提示词命令 worker "work only inside <project>" —— 自相矛盾。
OUTSIDE_BRIEF="$TMP/outside-brief.md"
printf '# X1 · outside\n\n```\ntask: X1\nagent: dev\n```\n' > "$OUTSIDE_BRIEF"
if $TEAM dispatch dev T1.1 "$OUTSIDE_BRIEF" --print >"$TMP/dispatch-outside.log" 2>&1; then
  bad "F15：项目外任务书应当被拒"
else ok "F15：项目外任务书被拒（--print 也不放行）"; fi
assert_has "$TMP/dispatch-outside.log" "不在本项目里" "F15：报错说明任务书在项目外"
assert_has "$TMP/dispatch-outside.log" "$REPO" "F15：报错点名项目主工作树"
assert_not "$TMP/dispatch-outside.log" "repo-relative" "F15：不再把项目外路径称作 repo-relative"
# F2（P4 裁决）：同一个拒绝必须发生在**开窗之前** —— 用一个只会记账的 tmux shim 证明它一次都没被要求建窗口，
# 而不是靠「大概不会走到那一步」。
F15_SHIM="$TMP/f15-tmux-shim"; mkdir -p "$F15_SHIM"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "\$*" >> "%s"\nexit 0\n' "$TMP/f15-tmux-calls.log" > "$F15_SHIM/tmux"
chmod +x "$F15_SHIM/tmux"
: > "$TMP/f15-tmux-calls.log"
if env PATH="$F15_SHIM:$PATH" $TEAM dispatch dev T1.1 "$OUTSIDE_BRIEF" >"$TMP/dispatch-outside-noprint.log" 2>&1; then
  bad "F15：项目外任务书不带 --print 也应当被拒"
else ok "F15：项目外任务书被拒（不带 --print 同样拒绝）"; fi
assert_has "$TMP/dispatch-outside-noprint.log" "不在本项目里" "F15：不带 --print 的报错同样说明任务书在项目外"
assert_eq "F15：拒绝发生在开窗之前（tmux 一次都没被要求建窗口）" \
  "$(grep -cE 'new-window|respawn-pane|new-session' "$TMP/f15-tmux-calls.log" 2>/dev/null || true)" "0"
assert_not "$TMP/dispatch-outside-noprint.log" "含启动校验" "F15：不带 --print 也没有真的派单"

section "6 · dispatch"
$TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print.log" 2>&1 || bad "dispatch --print 失败"
assert_has "$TMP/print.log" "--session-id $SESSION-dev" "命令含正确的 session-id"
assert_has "$TMP/print.log" "team-notify.ts" "命令显式加载 notify 扩展（worktree 不会自动发现）"
assert_has "$TMP/print.log" "agent:dev" "提示词声明了 agent 身份"
assert_has "$TMP/print.log" "Never stop mid-task to ask for confirmation" "dispatch prompt states the no-mid-task-stop rule"
assert_has "$TMP/print.log" "reports/T1.1-dev.md" "提示词指明报告路径"
assert_has "$TMP/print.log" "git commit" "提示词要求小步提交"

if [ "$FAST" = "1" ]; then
  fast_skip "6·dispatch 真拉起" "要真实 tmux 窗口 + 假 pi 进程（pi-sleep，sleep 600）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  # 让 worker 用假 pi 跑（pi-sleep：模拟“pi 正在跑”的窗口，便于验证 say/存活判定）
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/pi-args.log" > "$FAKE/pi-sleep"
  chmod +x "$FAKE/pi-sleep"
  printf '\nTEAM_PI_BIN="%s"\n' "$FAKE/pi-sleep" >> "$REPO/.pi/team/config.sh"
  $TEAM dispatch dev T1.1 "$TASKFILE" >"$TMP/dispatch.log" 2>&1 || bad "dispatch 失败"
  # M7.5：不再固定 sleep 2.5 赌假 pi 起没起来（那是在赌机器速度）—— 有界轮询它的参数日志
  # （最多 10s）；超时后面的断言照样报红，只是失败信息里已经有足够现场。
  S6_WAIT=0
  while [ "$S6_WAIT" -lt 100 ] && [ ! -s "$TMP/pi-args.log" ]; do sleep 0.1; S6_WAIT=$((S6_WAIT + 1)); done
  [ "$S6_WAIT" -ge 100 ] && printf '    现场（有界轮询 10s 内没等到假 pi 的参数日志）：窗口=[%s] dispatch 尾=[%s]\n' \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | tr '\n' ',')" "$(tail -2 "$TMP/dispatch.log" 2>/dev/null | tr '\n' '|')"
  if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx dev; then ok "tmux 窗口 $SESSION:dev 已创建"; else bad "tmux 窗口未创建"; fi
  assert_file "$TMP/pi-args.log" "假 pi 被拉起（记录了参数）"
  assert_has "$TMP/pi-args.log" "-e" "pi 收到 -e（扩展）"
  assert_has "$TMP/pi-args.log" "--skill" "pi 收到 --skill（团队协议）"
  assert_eq "state 记录了任务" "$(cat "$REPO/.pi/team/state/dev.env" | grep -c '^task=T1.1$')" "1"
  $TEAM roster >"$TMP/roster-live.log" 2>&1
  assert_has "$TMP/roster-live.log" "pi 在跑" "roster 看到 agent 的 pi 在跑"
  $TEAM say dev "ping" >/dev/null 2>&1 && ok "say 能向在跑的 agent 发消息" || bad "say 失败"
else
  printf '  (跳过 tmux 相关断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 6b. 容量守卫矩阵（D2：zram 不当额度）
section "6b · 容量守卫矩阵（zram / 磁盘 swap 分账）"
MEMENV="TEAM_MEMINFO_FILE=$TMP/meminfo"
# 造 /proc/swaps 替身：zram0 近乎打满 + /var/swapfile 充足
cat > "$TMP/swaps" <<'SWAPS'
Filename				Type		Size		Used		Priority
/var/swapfile                           file		67108860	1048576		-1
/dev/zram0                              partition	15245728	14000000	100
SWAPS
SWAPENV="TEAM_SWAPFILE_PATH=$TMP/swaps"

if env "$MEMENV-plenty" "$SWAPENV" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/mem-plenty.log" 2>&1; then
  ok "内存充足 → 允许派单"
else bad "内存充足时不应拒绝"; cat "$TMP/mem-plenty.log"; fi
env "$MEMENV-plenty" "$SWAPENV" $TEAM ps >"$TMP/ps-cap.log" 2>&1 || true
assert_has "$TMP/ps-cap.log" "zram 用" "容量读数区分 zram 与磁盘 swap"
assert_has "$TMP/ps-cap.log" "磁盘 swap 空闲" "容量读数给出磁盘 swap 空闲"

# zram 打满但 RAM 充足：只警告（zram 只是卡顿来源，安全网是磁盘 swap）
if env "$MEMENV-zramfull" "$SWAPENV" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/mem-zram.log" 2>&1; then
  ok "zram 打满但 RAM/磁盘 swap 充足 → 仍允许（只警告）"
else bad "zram 占用不应直接拒绝"; cat "$TMP/mem-zram.log"; fi
assert_has "$TMP/mem-zram.log" "zram 已用" "给出了 zram 警告"

# RAM 见底：硬线（CEP 的 OOM 就是 RAM+zram 同时见底）
if env "$MEMENV-lowram" "$SWAPENV" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/mem-lowram.log" 2>&1; then
  bad "MemAvailable 见底时应当拒绝"
else ok "MemAvailable < 底线 → 拒绝派单"; fi
assert_has "$TMP/mem-lowram.log" "MemAvailable 只剩" "拒绝理由指向 MemAvailable"

# 磁盘 swap 见底（zram 还有很多）：硬线 —— 因为 zram 占的就是 RAM，不算安全网
cat > "$TMP/swaps-low" <<'SWAPS'
Filename				Type		Size		Used		Priority
/var/swapfile                           file		67108860	67000000	-1
/dev/zram0                              partition	15245728	1048576		100
SWAPS
if env "$MEMENV-zramok" "TEAM_SWAPFILE_PATH=$TMP/swaps-low" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/mem-lowswap.log" 2>&1; then
  bad "磁盘 swap 见底时应当拒绝"
else ok "磁盘 swap 见底（不计 zram）→ 拒绝派单"; fi
assert_has "$TMP/mem-lowswap.log" "磁盘 swap 只剩" "拒绝理由指向磁盘 swap"

if env "$MEMENV-doomed" "$SWAPENV" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/mem-doomed.log" 2>&1; then
  bad "RAM+swap 都见底时应当拒绝"
else ok "RAM+swap 双低 → 拒绝派单"; fi

# 模型限额通配（D8）
section "6c · 模型并发限额（含通配）"
assert_eq "openai-codex/* 通配上限生效" "$(TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_model_limit openai-codex/gpt-5.4-codex')" "1"
assert_eq "kimi-coding/k3 精确上限生效" "$(TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_model_limit kimi-coding/k3')" "2"

# ---------------------------------------------------------------- 6d. CEP 实测反馈 ①②③④
section "6d · CEP 实测反馈（board 额外列 / merge 冲突列表 / 待复验启发式 / 翻转证据）"

# ② board 手工加了 Issue 列后仍要能正确解析（标题不再被当成 "—"）
python3 - <<'PYB'
import pathlib
p = pathlib.Path("docs/team/BOARD.md"); lines = p.read_text().split("\n"); out = []
for l in lines:
    if l.startswith("| ID |"):
        out.append("| ID | Issue | 任务 | Agent | 分支 | 依赖 | 状态 |")
    elif l.startswith("|") and set(l) <= set("|-"):
        out.append("|---|---|---|---|---|---|---|")
    elif l.startswith("|") and l.count("|") >= 6:
        c = [x for x in l.split("|")[1:-1]]
        out.append("| " + " | ".join([c[0].strip(), "-"] + [x.strip() for x in c[1:]]) + " |")
    else:
        out.append(l)
p.write_text("\n".join(out))
PYB
assert_eq "额外列：列映射按表头名定位" \
  "$(TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_board_cols')" "2 4 5 6 7 8"
assert_eq "额外列：任务标题仍解析正确" \
  "$(TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_board_field "$(team_board_row T1.1)" task')" "Smoke task"
$TEAM board set T1.1 wip >/dev/null 2>&1 || true
assert_has "$REPO/docs/team/BOARD.md" "| wip |" "额外列布局下状态写进状态列"
$TEAM board ls >"$TMP/board-ls.log" 2>&1 || true
assert_has "$TMP/board-ls.log" "非标准列布局" "board ls 提示列布局非标准（但不报错）"
$TEAM task T2.6 --title "third task" --agent dev >/dev/null 2>&1 || true
assert_has "$REPO/docs/team/BOARD.md" "| T2.6 |" "新行按现有列数对齐写入"

# ③ 里程碑/结项报告不算待复验
mkdir -p "$REPO/docs/team/reports"
printf '# P2 · 里程碑结项\n\n不是任务报告。\n' > "$REPO/docs/team/reports/P2-closure.md"
printf '# T2.6 · 真实任务报告\n\nagent: dev\n状态: DONE\n' > "$REPO/docs/team/reports/T2.6-dev.md"
$TEAM digest >"$TMP/digest-heur.log" 2>&1 || true
assert_has "$TMP/digest-heur.log" "T2.6-dev" "真任务报告算待复验"
assert_has "$TMP/digest-heur.log" "忽略的非任务报告" "结项报告被显式忽略而不是一直提示"
assert_not "$TMP/digest-heur.log" "team review P2 " "结项报告不再出现在待复验行动项里"
assert_has "$TMP/digest-heur.log" "P2-closure.md" "忽略清单点名了那份结项报告"
rm -f "$REPO/docs/team/reports/P2-closure.md" "$REPO/docs/team/reports/T2.6-dev.md"

# ① merge/pr 已从 CLI 移除：git 与 forge 由 PM 直接用真实工具
if $TEAM merge T1.1 >/dev/null 2>&1; then bad "merge 应已移除"; else ok "merge 已移除（不再包装 git）"; fi
if $TEAM pr T1.1 >/dev/null 2>&1; then bad "pr 应已移除"; else ok "pr 已移除"; fi
assert_has "$SKILL_DIR/references/workflows.md" "git -C" "workflows 文档给出 PM 直接跑的 git 步骤"
assert_has "$SKILL_DIR/references/protocol.md" "does not perform" "protocol 写明 skill 不执行 git/forge 写操作"

# ④ 翻转证据进模板与派单提示词
assert_has "$SKILL_DIR/templates/task.md.tmpl" "Flip evidence" "task template requires flip evidence"
assert_has "$SKILL_DIR/templates/report.md.tmpl" "Flip evidence" "report template has the flip-evidence section"
assert_has "$TMP/print.log" "flip evidence" "dispatch prompt requires flip evidence"

# ---------------------------------------------------------------- 6e. erp 实测反馈（4 条）
section "6e · erp 实测反馈（render & / GitLab 头 / pi PATH / 非任务报告）"

# ③ 模板渲染不能吃掉 &&（bash 5.2+ 的 patsub_replacement 会把 & 变成“命中文本”）
BRENDER="$TMP/renderer-repo"; mkdir -p "$BRENDER"; ( cd "$BRENDER" && git init -q -b main && git config user.email a@b && git config user.name a && echo x > a && git add -A && git commit -qm init )
( cd "$BRENDER" && bash "$SKILL_DIR/scripts/team" init --session "teamsmith-smoke-render-$$" --agents dev --gates "pnpm test && pnpm lint" >/dev/null 2>&1 ) || true
assert_has "$BRENDER/.pi/team/config.sh" 'TEAM_GATES="pnpm test && pnpm lint"' "init 原样写入含 && 的 TEAM_GATES"
assert_eq "渲染后没有占位符残留" "$(grep -c '{{GATES}}' "$BRENDER/.pi/team/config.sh" || true)" "0"
assert_eq "渲染结果可安全 source（值与入参一致）" \
  "$(env TEAM_ROOT=$BRENDER SK="$SKILL_DIR" bash -c '. "$SK/scripts/lib/common.sh"; team_load_config; printf "%s" "$TEAM_GATES"')" "pnpm test && pnpm lint"
assert_eq "含 shell 特殊字符也不会被当代码执行" \
  "$(cd "$BRENDER" && bash "$SKILL_DIR/scripts/team" init --force --session "teamsmith-smoke-render-$$" --agents dev --gates 'a && echo PWNED `id` $HOME' >/dev/null 2>&1; env TEAM_ROOT=$BRENDER SK="$SKILL_DIR" bash -c '. "$SK/scripts/lib/common.sh"; team_load_config; printf "%s" "$TEAM_GATES"')" 'a && echo PWNED `id` $HOME'

# ① forge 透传/包装已移除（token 只作为项目配置，PM 直接用真实工具）
assert_has "$SKILL_DIR/references/protocol.md" "real tools" "protocol 说明写操作用真实工具"
assert_not_file "$SKILL_DIR/scripts/lib/forge.sh" "不再有 forge 包装模块"

# ② pi 可执行文件：绝对路径 + 找不到就明确报错（不要再出现窗口里 command not found）
if TEAM_PI_BIN="definitely-not-a-pi-binary" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/pi-missing.log" 2>&1; then
  bad "TEAM_PI_BIN 不存在时应当报错"
else ok "TEAM_PI_BIN 不存在时拒绝派单"; fi
assert_has "$TMP/pi-missing.log" "找不到 pi 可执行文件" "报错说明了 pi 找不到"
assert_has "$TMP/pi-missing.log" "绝对路径" "给出了「设成绝对路径」的建议"
assert_match "$TMP/print.log" "^cd .* && (export [^;]*; )*/| pi_bin" "派单命令里用的是解析后的路径（M36 起 && 后先带闸门 exports 前缀，再到绝对路径；见下方 dispatch 断言）"

# ④ 非任务交付物不算待复验（erp: requirements-gap-2026-09-11.md）
printf '# 需求差距报告\n\n非任务交付物。\n' > "$REPO/docs/team/reports/requirements-gap-2026-09-11.md"
$TEAM digest >"$TMP/digest-nontask.log" 2>&1 || true
assert_not "$TMP/digest-nontask.log" "team review requirements" "非任务交付物不再被当成待复验任务"
assert_has "$TMP/digest-nontask.log" "requirements-gap-2026-09-11.md" "但它会出现在「忽略的非任务报告」里"
rm -f "$REPO/docs/team/reports/requirements-gap-2026-09-11.md"

# 次要项：team resume 支持位置参数
$TEAM resume dev --dry-run >"$TMP/resume-pos.log" 2>&1 && ok "resume <agent> 位置参数可用" || bad "resume 位置参数不可用"

# ---------------------------------------------------------------- 6f. agent adapter（任意 TUI agent）
section "6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级"

adapter_launch_support() { # → 引擎支持的 launch 占位符（空格分隔）
  TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_agent_placeholders launch' | tr '\n' ' '
}
adapter_doc_tokens() { # <doc> → 文档表格第一列里出现的占位符（每行一个）
  grep -oE '^\| *`\{[A-Za-z_][A-Za-z0-9_]*\}`' "$1" | grep -oE '\{[A-Za-z_][A-Za-z0-9_]*\}' | sort -u
}
adapter_doc_unsupported() { # <doc> → 文档里列了、但引擎不认识的占位符（每行一个）
  local t support=" $(adapter_launch_support) "
  for t in $(adapter_doc_tokens "$1"); do
    case "$support" in *" $t "*) ;; *) printf '%s\n' "$t" ;; esac
  done
}
ADOC="$SKILL_DIR/references/agent-adapters.md"

# ① 默认不变：还是内置 Pi 命令
assert_has "$TMP/print.log" 'adapter: built-in (Pi)' "默认仍是内置 Pi adapter（--print 标明）"
assert_not "$TMP/print.log" 'adapter: custom:' "没配 TEAM_AGENT_CMD 时不会变成 custom"
assert_has "$TMP/print.log" "--session-id $SESSION-dev" "默认命令仍带 --session-id（Pi 路径不变）"
assert_has "$TMP/print.log" "--skill" "默认命令仍带 --skill（Pi 路径不变）"

# ② 自定义模板：渲染成可读的单行命令，不留占位符
APLACE='myagent run --model {model} --prov {provider} --dir {cwd} --sid {session_id} --prompt {prompt} --file {prompt_file} --skill {skill_dir} {extra_args}'
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-custom.log" 2>&1 \
  || { bad "自定义 adapter 的 dispatch --print 失败"; cat "$TMP/print-custom.log"; }
grep -m1 '^cd ' "$TMP/print-custom.log" > "$TMP/cmdline-custom.log" || true
assert_file "$TMP/cmdline-custom.log" "--print 给出了完整命令（cd … && <cmd>）"
assert_has "$TMP/cmdline-custom.log" "myagent run --model deepseek-flash" "{model} 渲染成模型名"
assert_has "$TMP/cmdline-custom.log" "--prov deepseek" "{provider} 渲染成 provider"
assert_has "$TMP/cmdline-custom.log" "--dir $REPO/.worktrees/dev" "{cwd} 渲染成 agent worktree"
assert_has "$TMP/cmdline-custom.log" "--sid $SESSION-dev" "{session_id} 渲染成 teamsmith session id"
assert_has "$TMP/cmdline-custom.log" "--skill $SKILL_DIR" "{skill_dir} 渲染成 skill 目录"
assert_has "$TMP/cmdline-custom.log" "$REPO/.pi/team/state/prompt-dev-T1.1.md" "{prompt_file} 指向落盘的提示词"
assert_has "$TMP/cmdline-custom.log" '--prompt "$0"' "{prompt} 展开成窗口 harness 的 argv[0]（提示词不进命令行）"
assert_not "$TMP/cmdline-custom.log" "{" "渲染后的命令没有残留占位符"
assert_has "$TMP/print-custom.log" 'adapter: custom: myagent run' "--print 标明自定义 adapter"
assert_file "$REPO/.pi/team/state/prompt-dev-T1.1.md" "派单把提示词落盘（{prompt_file} 的内容）"
assert_has "$REPO/.pi/team/state/prompt-dev-T1.1.md" "agent:dev" "落盘的确实是本次派单提示词"

# ③ notify：摘要是数据（F1）—— worker 写文件、跑固定命令；提示词里没有任何 worker 文本
ANOTIFY='bash {skill_dir}/scripts/team notify pm "{summary}"'
M32_PF="$REPO/.pi/team/state/prompt-dev-T1.1.md"
M32_SF="$REPO/.pi/team/state/summary-dev-T1.1.md"
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash TEAM_AGENT_NOTIFY_CMD="$ANOTIFY" \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-notify.log" 2>&1 || true
assert_has "$TMP/print-notify.log" "Notify the PM when your turn ends" "有 notify 模板时提示词含通知段落"
assert_has "$TMP/print-notify.log" "$M32_SF" "--print 给出 worker 要写的摘要文件"
assert_has "$M32_PF" "Notify the PM when your turn ends" "落盘提示词含通知段落"
assert_has "$M32_PF" "not Pi" "自定义 CLI → 明说不是 Pi（没有自动通知）"
assert_has "$M32_PF" "$M32_SF" "提示词给出摘要文件路径（teamsmith 生成的）"
assert_has "$M32_PF" "no substitutions, no extra arguments and no quotes" "让 worker 原样跑固定命令"
assert_not "$M32_PF" "{summary}" "提示词里没有字面 {summary}（弱模型会原样执行）"
assert_not "$M32_PF" "<one-line summary>" "提示词里没有要 worker 自己替换的示例文本"
M32_NCMD="$(grep -E 'notify pm' "$M32_PF" | tail -1 | sed 's/^[[:space:]]*//')"
assert_has_echo "$M32_NCMD" "cat $M32_SF" "旧模板的 {summary} 渲染成「读摘要文件」的引用（不做文本插值）"
assert_not "$M32_NCMD" "{summary}" "渲染出的命令里没有残留占位符"

# ③b 敌意摘要矩阵：写进文件 → 跑提示词那条命令 → 不执行 + 逐字节送达
M32_DET="$TMP/m32-det"; mkdir -p "$M32_DET"
m32_deliver() { # <名字> <摘要原文> [<期望送达文本>]
  local name="$1" text="$2" want="${3:-$2}" got rc
  rm -f "$M32_DET/mark"; : > "$REPO/docs/team/inbox/pm.md"
  printf '%s' "$text" > "$M32_SF"
  ( cd "$REPO" && bash -c "$M32_NCMD" ) >"$TMP/m32-$name.out" 2>&1; rc=$?
  got="$(tail -1 "$REPO/docs/team/inbox/pm.md" 2>/dev/null | sed 's/.*· //')"
  assert_eq "敌意摘要[$name] 不执行任何东西" "$([ -e "$M32_DET/mark" ] && echo EXEC || echo noexec)" "noexec"
  assert_eq "敌意摘要[$name] 逐字节送达 PM 收件箱" "$got" "$want"
  assert_eq "敌意摘要[$name] 通知命令退出码 0" "$rc" "0"
}
m32_deliver control 'shipped the parser'
m32_deliver dquote 'fixed the "no session" hint'
m32_deliver subst "\$(touch $M32_DET/mark)"
m32_deliver breakout "x\"; touch $M32_DET/mark; echo \""
m32_deliver backtick "\`touch $M32_DET/mark\`"
m32_deliver apostrophe "it's fixed"
m32_deliver braces 'see {agent} and {summary_file} and {cwd}'
m32_deliver newline "$(printf 'first line\nsecond line')" 'first line second line'
# 缺文件 / 空文件：真失败（非 0 + 不写收件箱），不会假报「已通知」
rm -f "$M32_SF"; : > "$REPO/docs/team/inbox/pm.md"
( cd "$REPO" && bash -c "$M32_NCMD" ) >"$TMP/m32-nofile.out" 2>&1 \
  && bad "摘要文件不存在时 notify 不该成功" || ok "摘要文件不存在 → notify 非 0（不会假报已通知）"
assert_eq "缺文件时不写收件箱" "$(wc -l < "$REPO/docs/team/inbox/pm.md" | tr -d ' ')" "0"
: > "$M32_SF"
( cd "$REPO" && bash -c "$M32_NCMD" ) >"$TMP/m32-empty.out" 2>&1 \
  && bad "摘要文件为空时 notify 不该成功" || ok "摘要文件为空 → notify 非 0"
# ③c 推荐形态：{summary_file} + --from-file（命令里连 $(cat …) 都没有）
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash \
  TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm --from-file {summary_file}' \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-notify-file.log" 2>&1 || true
assert_has "$M32_PF" "notify pm --from-file $M32_SF" "{summary_file} 渲染成路径（推荐形态，shell 里不读文件）"
# ③d F7：内置 Pi（TEAM_AGENT_CMD 空）+ notify 键 → 不能说「不是 Pi、没有自动通知」
env TEAM_AGENT_BIN=bash TEAM_AGENT_NOTIFY_CMD="$ANOTIFY" \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-notify-pi.log" 2>&1 || true
# F7：内置 Pi 有自己的通知扩展 → 不把「回合结束跑这条」塞给 worker（也不谎称「不是 Pi」）
assert_not "$M32_PF" "Notify the PM when your turn ends" "Pi 路径不给 worker 塞额外通知段（F7）"
assert_not "$M32_PF" "not Pi, so there is no automatic notification" "Pi 路径下没有「不是 Pi」的谎话（F7）"
assert_has "$TMP/print-notify-pi.log" "TEAM_AGENT_CMD 为空" "并解释这段配置在 Pi 路径下不生效（F7）"
# ③e F8：坏 notify 模板 → 只警告 + 提示词整段换成「写进报告」
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash TEAM_AGENT_NOTIFY_CMD='bash {skill_dir}/scripts/team notify pm {bogus}' \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-notify-bad.log" 2>&1 \
  && ok "notify 模板不可用时不阻断派单（只警告）" || bad "坏 notify 模板不应让 dispatch 失败"
assert_has "$TMP/print-notify-bad.log" "TEAM_AGENT_NOTIFY_CMD 看起来不可用" "警告点名了坏模板"
assert_has "$M32_PF" "is unusable" "坏模板 → 提示词通知段改成「配置不可用」（F8）"
assert_has "$M32_PF" "into the report" "并告诉 worker 把摘要写进报告（F8）"
assert_not "$M32_PF" "scripts/team notify pm" "坏模板下不给半截 notify 命令（F8）"
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash TEAM_AGENT_NOTIFY_CMD='nosuchcli notify {summary}' \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print-notify-nocli.log" 2>&1 \
  && ok "notify 模板首词不可执行时不阻断派单（只警告）" || bad "首词不可执行的 notify 模板不应让 dispatch 失败"
assert_has "$TMP/print-notify-nocli.log" "TEAM_AGENT_NOTIFY_CMD 看起来不可用" "警告点名了首词问题"

# ④ 未知占位符 → 明确失败（列出支持集）
if env TEAM_AGENT_CMD='myagent {sessionid} {prompt}' $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/adapter-bogus.log" 2>&1; then
  bad "未知占位符应当让派单失败"
else ok "未知占位符 → 派单直接失败（不静默）"; fi
assert_has "$TMP/adapter-bogus.log" "{sessionid}" "报错点名了写错的占位符"
assert_has "$TMP/adapter-bogus.log" "{cwd}" "报错列出支持的占位符"
assert_has "$TMP/adapter-bogus.log" "TEAM_AGENT_CMD" "报错指明了是哪个配置键"

# ⑤ 文档 ↔ 代码契约（翻转自测：文档里混进未支持的占位符必须被抓到）
assert_file "$ADOC" "新文档 references/agent-adapters.md 在"
DOC_UNSUPPORTED="$(adapter_doc_unsupported "$ADOC" | tr '\n' ' ')"
assert_eq "文档占位符表里的 token 都被引擎支持" "${DOC_UNSUPPORTED:-无}" "无"
DOC_MISSING=""
for _t in $(adapter_launch_support); do
  grep -qF "$_t" "$ADOC" || DOC_MISSING="$DOC_MISSING $_t"
done
assert_eq "每个 launch 占位符都在文档里出现过" "${DOC_MISSING:-无}" "无"
AFLIP="$TMP/agent-adapters-flip.md"
cp "$ADOC" "$AFLIP"
printf '| `{bogus_placeholder}` | 注入的坏占位符（翻转自测） |\n' >> "$AFLIP"
FLIP_HITS="$(adapter_doc_unsupported "$AFLIP" | tr '\n' ' ')"
assert_eq "翻转自测：文档里混进未支持的占位符会被抓到" "${FLIP_HITS% }" "{bogus_placeholder}"

# ⑥ paths / doctor 报适配器；只有「配了但解析不到」才 fail
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash $TEAM paths >"$TMP/paths-adapter.log" 2>&1 || true
assert_has "$TMP/paths-adapter.log" '"agent_adapter": "custom: myagent run' "paths 报告当前 adapter"
assert_has "$TMP/paths-adapter.log" '"agent_bin":' "paths 报告解析到的可执行文件"
env TEAM_AGENT_CMD="$APLACE" TEAM_AGENT_BIN=bash $TEAM doctor >"$TMP/doctor-adapter.log" 2>&1 || true
assert_has "$TMP/doctor-adapter.log" "agent adapter" "doctor 新增 adapter 项"
assert_match "$TMP/doctor-adapter.log" "custom: myagent run" "doctor 显示自定义 adapter"
assert_has "$TMP/doctor-adapter.log" "不需要 pi" "自定义 adapter 下不再要求 pi"
env TEAM_AGENT_CMD='nosuchcli {prompt}' $TEAM doctor >"$TMP/doctor-badadapter.log" 2>&1 \
  && bad "配了不可解析的 adapter 时 doctor 应当失败" || ok "adapter 可执行文件解析不到 → doctor 失败"
assert_has "$TMP/doctor-badadapter.log" "解析不到" "失败原因说明是解析不到"
# 内置路径 + 根本没有 pi → doctor 仍然失败（今天的行为不能变）
# 影子 PATH：把现有 PATH 里的可执行文件全部软链过来，**除了 pi**
NOPI="$TMP/no-pi-bin"; mkdir -p "$NOPI"
for _d in ${PATH//:/ }; do [ -d "$_d" ] && ln -sf "$_d"/* "$NOPI/" 2>/dev/null; done
rm -f "$NOPI/pi"
assert_eq "影子 PATH 里确实没有 pi" "$(env PATH="$NOPI" bash -c 'command -v pi || echo MISSING')" "MISSING"
env PATH="$NOPI" $TEAM doctor >"$TMP/doctor-nopi.log" 2>&1 \
  && bad "内置路径缺 pi 时 doctor 应当失败" || ok "内置路径缺 pi → doctor 失败（行为不变）"
assert_has "$TMP/doctor-nopi.log" "缺 pi" "失败原因仍是缺 pi"

# ⑦ monitor 活动流：TEAM_AGENT_LOG_GLOB 显示日志尾部；没会话/没命中则优雅降级（纯逻辑，不需 tmux）
#    （+ ⑦b M3.3 加固：只读尾窗 / 控制序列净化 / 不可读降级 + 原因）
if [ -n "$JS_RUNNER" ]; then
  printf 'agent log line 1\nagent log line 2\n' > "$TMP/agentlog-dev.log"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 2 \
    --log-glob "$TMP/agentlog-{agent}.log" --json >"$TMP/monlog-json.log" 2>&1 || bad "monitor --log-glob 失败"
  assert_has "$TMP/monlog-json.log" '"source": "log"' "--log-glob 命中 → source=log"
  assert_has "$TMP/monlog-json.log" "agent log line 2" "显示的是最新匹配文件的尾部"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --json >"$TMP/monlog-none.log" 2>&1 \
    || bad "monitor 在无 Pi 会话时失败"
  assert_has "$TMP/monlog-none.log" '"source": "none"' "没有 Pi 会话也不炸（source=none）"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
    --log-glob "$TMP/definitely-missing/*.log" >"$TMP/monlog-miss.log" 2>&1 || bad "monitor glob 未命中时失败"
  assert_has "$TMP/monlog-miss.log" "无会话" "glob 未命中 → 退回「无会话」"
  assert_has "$TMP/monlog-miss.log" "未匹配到文件" "并说明是 glob 没匹配到"

  # ⑦b 加固（M3.3 / F2·F3）：只读尾窗、控制序列净化、不可读降级。纯逻辑、不建大文件、不测 RSS
  # （RSS 与「256MiB 日志」的实测在 docs/team/reports/M3.3-dev2/pkg/ 里；这里只钉住行为）
  AWK_MAKE_BIG='BEGIN{for(i=0;i<30000;i++) printf "smoke log line %06d padding padding padding\n", i}'
  awk "$AWK_MAKE_BIG" > "$TMP/agentlog-big.log"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 2 \
    --log-glob "$TMP/agentlog-big.log" --log-tail-bytes 2048 --json >"$TMP/mon-bound.json" 2>&1 \
    || bad "monitor --log-tail-bytes 失败"
  assert_has "$TMP/mon-bound.json" '"tail_limit": 2048' "F2 显式窗口（--log-tail-bytes）生效"
  assert_has "$TMP/mon-bound.json" '"truncated": true' "F2 大文件标成「只读了尾部」"
  assert_match "$TMP/mon-bound.json" '"count": [0-9]{1,3},' "F2 窗口里只有几十行（不整读）"
  assert_has "$TMP/mon-bound.json" 'smoke log line 029999' "F2 尾部内容仍然正确"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
    --log-glob "$TMP/agentlog-big.log" --log-tail-bytes 99999999 --json >"$TMP/mon-cap.json" 2>&1 \
    || bad "monitor 超限窗口失败"
  assert_has "$TMP/mon-cap.json" '"tail_limit": 1048576' "F2 超限窗口被夹到 1MiB 硬上限"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
    --log-glob "$TMP/agentlog-big.log" --log-tail-bytes abc --json >"$TMP/mon-badwin.json" 2>"$TMP/mon-badwin.err" \
    || bad "monitor 坏窗口值失败"
  assert_has "$TMP/mon-badwin.json" '"tail_limit": 65536' "F2 坏窗口值回落到默认 64KiB"
  assert_has "$TMP/mon-badwin.err" "tail" "F2 坏窗口值有 stderr 警告（不静默）"

  printf 'smoke tail A\nsmoke tail B\n' > "$TMP/agentlog-tail.log"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 2 \
    --log-glob "$TMP/agentlog-tail.log" --json >"$TMP/mon-tail.json" 2>&1 || bad "monitor 小文件失败"
  assert_has "$TMP/mon-tail.json" '"available": true' "F2 小文件 available=true（回归）"
  assert_has "$TMP/mon-tail.json" '"truncated": false' "F2 小文件 truncated=false（回归）"
  assert_has "$TMP/mon-tail.json" 'smoke tail B' "F2 小文件尾部正确（回归）"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 2 \
    --log-glob "$TMP/agentlog-tail.log" >"$TMP/mon-tail.txt" 2>&1 || bad "monitor 小文件文本模式失败"
  assert_has "$TMP/mon-tail.txt" "日志尾部" "F2 文本模式文案没变（CLI 契约）"

  printf '\033]0;SMOKE-PWN\007\033]52;c;U01PS0UtQ0xJUA==\007\033[2J\033[31mred-marker\033[0m\rCARRIAGE\nplain smoke line\n' \
    > "$TMP/agentlog-hostile.log"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 8 \
    --log-glob "$TMP/agentlog-hostile.log" >"$TMP/mon-hostile.txt" 2>&1 || bad "monitor 敌意日志失败"
  assert_eq "F3 文本输出里 0 个 ESC" "$(tr -cd '\033' < "$TMP/mon-hostile.txt" | wc -c | tr -d ' ')" "0"
  assert_not "$TMP/mon-hostile.txt" "SMOKE-PWN" "F3 OSC 窗口标题没被回显"
  assert_not "$TMP/mon-hostile.txt" "U01PS0UtQ0xJUA==" "F3 OSC 52 剪贴板载荷没被回显"
  assert_has "$TMP/mon-hostile.txt" "red-marker" "F3 可见文本保留"
  "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev --events 8 \
    --log-glob "$TMP/agentlog-hostile.log" --json >"$TMP/mon-hostile.json" 2>&1 || bad "monitor 敌意日志 --json 失败"
  assert_not "$TMP/mon-hostile.json" "SMOKE-PWN" "F3 --json 里也没有 OSC 标题"
  assert_eq "F3 --json 输出里 0 个 ESC" "$(tr -cd '\033' < "$TMP/mon-hostile.json" | wc -c | tr -d ' ')" "0"

  printf 'secret\n' > "$TMP/agentlog-noperm.log"; chmod 000 "$TMP/agentlog-noperm.log"
  if [ "$(id -u)" = "0" ]; then
    printf '  \033[33m-\033[0m SKIP 以 root 运行，chmod 000 依然可读\n'
  else
    "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
      --log-glob "$TMP/agentlog-noperm.log" --json >"$TMP/mon-noperm.json" 2>&1 || bad "monitor 无权限文件失败"
    assert_has "$TMP/mon-noperm.json" '"available": false' "F2 无权限 → available=false（不是静默空块）"
    assert_has "$TMP/mon-noperm.json" '权限' "F2 无权限 → 说明原因"
    "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
      --log-glob "$TMP/agentlog-noperm.log" >"$TMP/mon-noperm.txt" 2>&1 || bad "monitor 无权限文件文本模式失败"
    assert_has "$TMP/mon-noperm.txt" "不可读" "F2 无权限 → 文本模式明确写「不可读」"
    chmod 644 "$TMP/agentlog-noperm.log"
  fi
  if command -v mkfifo >/dev/null 2>&1; then
    rm -f "$TMP/agentlog-fifo.log"; mkfifo "$TMP/agentlog-fifo.log"
    timeout 20 "$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$REPO" --only dev \
      --log-glob "$TMP/agentlog-fifo.log" --json >"$TMP/mon-fifo.json" 2>&1
    assert_eq "F2 FIFO 不挂死（20s 内返回）" "$?" "0"
    assert_has "$TMP/mon-fifo.json" '"available": false' "F2 FIFO → available=false"
    assert_has "$TMP/mon-fifo.json" '普通文件' "F2 FIFO → 说明「不是普通文件」"
    rm -f "$TMP/agentlog-fifo.log"
  fi
else
  printf '  (跳过活动流断言：本机没有 node/bun 可直接跑 monitor.mjs)\n'
fi

# ⑧ 模板校验：畸形占位符 / 空白 / 多行都必须让派单失败（F4/F5/F6）+ 两条 nit
M32_MARK="$TMP/m32-second-line-ran"
rm -f "$M32_MARK"
m32_expect_fail() { # <名字> <模板> <日志> <期望报错里的片段>
  local name="$1" tpl="$2" log="$3" want="$4"
  if env TEAM_AGENT_CMD="$tpl" TEAM_AGENT_BIN=bash $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$log" 2>&1; then
    bad "$name 竟然被接受（会静默生成坏窗口/坏命令）"
  else ok "$name → 派单直接失败"; fi
  assert_has "$log" "$want" "$name 的报错说明原因"
}
m32_expect_fail "F4 占位符 { cwd }"    'myagent { cwd } {prompt}'  "$TMP/m32-bad-sp.log"  "{ cwd }"
m32_expect_fail "F4 占位符 {cwd }"     'myagent {cwd } {prompt}'   "$TMP/m32-bad-sp2.log" "{cwd }"
m32_expect_fail "F4 占位符 {{cwd}}"    'myagent {{cwd}} {prompt}'  "$TMP/m32-bad-dbl.log" "{{cwd}"
m32_expect_fail "F4 占位符 {cwd'}'"    "myagent {cwd'}' {prompt}" "$TMP/m32-bad-q.log"   "{cwd'}"
m32_expect_fail "F5 纯空白模板"        '   '                      "$TMP/m32-blank.log"   "只有空白"
m32_expect_fail "F6 多行模板"          "myagent {prompt}"$'\n'"touch $M32_MARK" "$TMP/m32-nl.log" "含换行"
assert_not_file "$M32_MARK" "F6：多行模板的第二行没有机会被窗口 shell 执行"
assert_has "$TMP/m32-bad-sp.log" "TEAM_AGENT_CMD" "F4 的报错点名配置键"
assert_has "$TMP/m32-bad-sp.log" "{cwd}" "F4 的报错列出支持的占位符"
# 合法写法不能被误伤：JSON body / awk 程序 / ${HOME} / 两个占位符相邻
if env TEAM_AGENT_CMD='myagent {prompt} -d {"a":1}' TEAM_AGENT_BIN=bash $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m32-json.log" 2>&1; then
  ok "JSON body 里的花括号不被当成占位符"
else bad "JSON body 被误判成畸形占位符"; cat "$TMP/m32-json.log"; fi
if env TEAM_AGENT_CMD='myagent {prompt} ${HOME} {cwd}{prompt_file}' TEAM_AGENT_BIN=bash $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m32-env.log" 2>&1; then
  ok "\${HOME} 与相邻占位符都能通过校验"
else bad "合法的 \${HOME}/相邻占位符被误判"; cat "$TMP/m32-env.log"; fi
# nit：{extra_args} 的值只插一次，不会被当模板再扫一遍
env TEAM_EXTRA_PI_ARGS='--x {cwd}' TEAM_AGENT_CMD='myagent {prompt} {extra_args}' TEAM_AGENT_BIN=bash \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m32-extra.log" 2>&1 || true
grep -m1 '^cd ' "$TMP/m32-extra.log" > "$TMP/m32-extra-cmd.log" || true
assert_has "$TMP/m32-extra-cmd.log" '--x {cwd}' "nit：{extra_args} 里的 {cwd} 没有被二次展开"
# nit：分支提示里的路径是 %q 引用过的（带空格的路径也能安全复制粘贴）
M32_SP="m32 dir with space"
git -C "$REPO" worktree add --detach "$REPO/$M32_SP/dev" "$PROTECTED" >/dev/null 2>&1 || true
( cd "$REPO" && env TEAM_WORKTREES_DIR="$M32_SP" TEAM_AGENTS=dev TEAM_AGENT_BIN=bash \
    $TEAM dispatch dev T1.1 "$TASKFILE" ) >"$TMP/m32-hint.log" 2>&1 || true
assert_has "$TMP/m32-hint.log" "switch -c" "工作树不在任务分支时仍给出分支提示"
assert_has "$TMP/m32-hint.log" 'm32\ dir\ with\ space' "nit：提示里的路径带空格时被 %q 转义（可安全复制）"
assert_not "$TMP/m32-hint.log" "$M32_SP/dev switch" "（提示里不是未转义的裸路径）"
git -C "$REPO" worktree remove --force "$REPO/$M32_SP/dev" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 6g. 非 Pi agent 端到端（真窗口）
section "6g · 非 Pi agent 端到端（假 agent，完全没有 Pi）"
if [ "$FAST" = "1" ]; then
  fast_skip "6g·非 Pi agent 端到端" "要真实 tmux 窗口 + 假 agent 进程 + 等待它跑完"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  # 假「非 Pi」agent：写文件 + 提交 + 写报告 + 通知 PM（全部靠自己，不依赖 Pi/扩展）
  ADAPTER_AGENT="adapter"
  ADAPTER_ID="T1.2"
  ADAPTER_MARK="$TMP/fake-agent.mark"
  ADAPTER_DONE="$TMP/fake-agent.done"
  cat > "$FAKE/fake-agent.sh" <<EOF
#!/usr/bin/env bash
# 假的「非 Pi」agent：证明 adapter 在完全没有 Pi 的环境里能跑完一条完整回路
set -uo pipefail
wt="\$1"; sid="\$2"; pf="\$3"; skill="\$4"
printf 'cwd=%s sid=%s prompt=%s\n' "\$wt" "\$sid" "\$pf" > "$ADAPTER_MARK"
cd "\$wt" || exit 1
echo hello-from-non-pi-agent > agent-artifact.txt
git add agent-artifact.txt && git commit -qm "feat($ADAPTER_ID): 非 Pi agent 产物"
mkdir -p docs/team/reports
printf '# $ADAPTER_ID · 非 Pi adapter 冒烟\n\n' > docs/team/reports/$ADAPTER_ID-$ADAPTER_AGENT.md
printf -- '- agent-artifact.txt\n' >> docs/team/reports/$ADAPTER_ID-$ADAPTER_AGENT.md
git add docs/team/reports/$ADAPTER_ID-$ADAPTER_AGENT.md
git commit -qm "docs($ADAPTER_ID): 非 Pi adapter 报告"
bash "\$skill/scripts/team" notify pm "$ADAPTER_ID 完成：非 Pi adapter 跑通"
printf 'done\n' > "$ADAPTER_DONE"
EOF
  chmod +x "$FAKE/fake-agent.sh"
  ACMD="$FAKE/fake-agent.sh {cwd} {session_id} {prompt_file} {skill_dir}"
  # 任务书必须在项目内（M6.3 F15 的守卫）；放 state/ 而不是 docs/team/tasks/，
  # 这样 T1.2 的报告仍然按「非任务报告」被忽略 —— 不改变本节之外的 pending 计数。
  mkdir -p "$REPO/.pi/team/state"
  ATASK="$REPO/.pi/team/state/$ADAPTER_ID-nonpi-brief.md"
  # P24（B3）：change-less 的任务书要有锚，否则派单守卫先拒（本节测的是非 Pi 路径）
  printf '# %s · 非 Pi adapter 冒烟\n\ntask: %s\nagent: %s\nanchor: none (infra) — smoke fixture\n' \
    "$ADAPTER_ID" "$ADAPTER_ID" "$ADAPTER_AGENT" > "$ATASK"
  # 第二个 worker（agent 模式名册里新增一个），自己的 worktree/分支：不动 dev 的账
  ADAPTER_BRANCH="$(canon_branch "$ADAPTER_AGENT" "$ADAPTER_ID")"
  git -C "$REPO" worktree add -b "$ADAPTER_BRANCH" "$REPO/.worktrees/$ADAPTER_AGENT" "$PROTECTED" >/dev/null 2>&1 || true
  AENV="TEAM_AGENTS=dev verify $ADAPTER_AGENT"
  env TEAM_AGENTS="dev verify $ADAPTER_AGENT" TEAM_AGENT_CMD="$ACMD" TEAM_AGENT_BIN="$FAKE/fake-agent.sh" \
    TEAM_AGENT_NOTIFY_CMD="bash {skill_dir}/scripts/team notify pm \"{summary}\"" \
    $TEAM dispatch "$ADAPTER_AGENT" "$ADAPTER_ID" "$ATASK" --print >"$TMP/print-nonpi.log" 2>&1 || true
  grep -m1 '^cd ' "$TMP/print-nonpi.log" > "$TMP/cmdline-nonpi.log" || true
  assert_has "$TMP/cmdline-nonpi.log" "$FAKE/fake-agent.sh" "非 Pi 命令用的是配置的假 agent"
  assert_has "$TMP/cmdline-nonpi.log" "$REPO/.worktrees/$ADAPTER_AGENT" "{cwd} 指向它自己的 worktree"
  assert_has "$TMP/cmdline-nonpi.log" "$SESSION-$ADAPTER_AGENT" "{session_id} 是 teamsmith 的 session"
  assert_not "$TMP/cmdline-nonpi.log" "{" "非 Pi 命令里没有残留占位符"
  env TEAM_AGENTS="dev verify $ADAPTER_AGENT" TEAM_AGENT_CMD="$ACMD" TEAM_AGENT_BIN="$FAKE/fake-agent.sh" \
    TEAM_AGENT_NOTIFY_CMD="bash {skill_dir}/scripts/team notify pm \"{summary}\"" \
    $TEAM dispatch "$ADAPTER_AGENT" "$ADAPTER_ID" "$ATASK" >"$TMP/dispatch-nonpi.log" 2>&1 \
    || { bad "非 Pi dispatch 失败"; cat "$TMP/dispatch-nonpi.log"; }
  assert_not "$TMP/dispatch-nonpi.log" "找不到 pi" "非 Pi 路径不会因为「没有 pi」而报错"
  _i=0; while [ "$_i" -lt 60 ] && [ ! -f "$ADAPTER_DONE" ]; do sleep 0.5; _i=$((_i + 1)); done
  assert_file "$ADAPTER_DONE" "非 Pi agent 跑完整条回路（写文件 → 提交 → 报告 → 通知）"
  assert_file "$ADAPTER_MARK" "非 Pi agent 真的在窗口里跑起来了"
  assert_has "$ADAPTER_MARK" "sid=$SESSION-$ADAPTER_AGENT" "它拿到了 teamsmith 的 session id"
  assert_has "$ADAPTER_MARK" "prompt=$REPO/.pi/team/state/prompt-$ADAPTER_AGENT-$ADAPTER_ID.md" "{prompt_file} 也是真的"
  assert_eq "窗口在（agent:$ADAPTER_AGENT）" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx "$ADAPTER_AGENT" || true)" "1"
  assert_eq "非 Pi agent 的提交落在它自己的分支上" "$(git -C "$REPO/.worktrees/$ADAPTER_AGENT" rev-list --count "$PROTECTED"..HEAD)" "2"
  assert_file "$REPO/.worktrees/$ADAPTER_AGENT/docs/team/reports/$ADAPTER_ID-$ADAPTER_AGENT.md" "它写了自己的报告"
  assert_has "$REPO/.worktrees/$ADAPTER_AGENT/docs/team/reports/$ADAPTER_ID-$ADAPTER_AGENT.md" "agent-artifact.txt" "报告内容来自它自己"
  assert_has "$REPO/docs/team/inbox/pm.md" "$ADAPTER_ID 完成：非 Pi adapter 跑通" "PM 收到了它的通知（走 TEAM_AGENT_NOTIFY_CMD）"
  assert_eq "dev 的账没被搅动" "$(git -C "$REPO/.worktrees/dev" rev-list --count "$PROTECTED"..HEAD)" "0"
  # 活动流：配了 TEAM_AGENT_LOG_GLOB 就显示这个 agent 的日志尾部
  printf 'non-pi log A\nnon-pi log B\n' > "$TMP/agentlog-$ADAPTER_AGENT.log"
  env TEAM_AGENTS="dev verify $ADAPTER_AGENT" TEAM_AGENT_LOG_GLOB="$TMP/agentlog-{agent}.log" \
    $TEAM monitor --once --no-pulse --activity >"$TMP/monitor-nonpi.log" 2>&1 || true
  assert_has "$TMP/monitor-nonpi.log" "agentlog-{agent}.log" "monitor 说明了活动流来源（新面板把源写在活动列标题里）"
  assert_has "$TMP/monitor-nonpi.log" "non-pi log B" "活动流显示日志尾部（没有 Pi 会话也行）"
  tmux kill-window -t "$SESSION:$ADAPTER_AGENT" 2>/dev/null || true
  # 清场：这个假 agent 的 worktree/分支/报告不能留成「待复验」——那会污染后面的巡检断言
  # （team_reports_pending 扫 .worktrees/*，和名册无关）；清完顺手验一下真的干净了。
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/$ADAPTER_AGENT" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$ADAPTER_BRANCH" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/$ADAPTER_AGENT.env"
  APEND="$($TEAM pulse status 2>/dev/null || true)"
  case "$APEND" in
    *"待复验 [1-9]"*) bad "清场没干净：pulse status 里还有待复验（会污染后面的巡检断言）" ;;
    *) ok "清场后不再有待复验报告（不影响后面的巡检断言）" ;;
  esac
else
  printf '  (跳过非 Pi 端到端断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 6h. 派单：会话规模 + 启动证据（M4.3 A/B）
section "6h · 派单：会话规模 vs 模型窗口（M4.3 A）+ 启动证据（M4.3 B）"

# 夹具：Pi 的 agent 目录（模型目录：sub2api/gpt-5.6-sol = 272k，big/wide = 1000k）
#      + 一个 1.6MB 的 dev 会话（≈400k tok —— 现场 D9 事件 A 的 361k 同一个数量级）
M43_AGENT_DIR="$TMP/piagent-m43"
M43_SESS_DIR="$M43_AGENT_DIR/sessions/--$(printf '%s' "$REPO/.worktrees/dev" | sed -e 's|^/||' -e 's|[/\\:]|-|g')--"
mkdir -p "$M43_SESS_DIR"
cat > "$M43_AGENT_DIR/models.json" <<'JSON'
{
  "providers": {
    "sub2api": {
      "name": "sub2api",
      "models": [
        { "id": "gpt-5.6-sol", "name": "GPT-5.6 Sol", "contextWindow": 272000 }
      ]
    },
    "big": {
      "name": "big",
      "models": [
        { "id": "wide", "name": "Wide", "contextWindow": 1000000 }
      ]
    }
  }
}
JSON
head -c 1600000 /dev/zero | tr '\0' 'x' > "$M43_SESS_DIR/2026-01-01T00-00-00-000Z_$SESSION-dev.jsonl"
M43_MODEL="$(sed -n 's/^model=//p' "$REPO/.pi/team/state/dev.env" 2>/dev/null | head -1)"
[ -n "$M43_MODEL" ] || M43_MODEL="$(sed -n 's/^TEAM_DEFAULT_MODEL="\([^"]*\)".*/\1/p' "$REPO/.pi/team/config.sh" 2>/dev/null | head -1)"
m43() { env TEAM_PI_AGENT_DIR="$M43_AGENT_DIR" "$@"; }

# A1：小窗口模型 + 大会话 → 默认拒绝（旧行为：欣然派出去，然后 agent 陷在 Context full 循环里）
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol >"$TMP/m43-a1.log" 2>&1; then
  bad "M4.3 A1：大会话 + 小窗口模型应当被拒"
else ok "M4.3 A1：大会话 + 小窗口模型被拒（不再派出去等 wedge）"; fi
assert_has "$TMP/m43-a1.log" "拒绝复用这个会话" "A1：拒绝理由说清楚是「复用会话」"
assert_has "$TMP/m43-a1.log" "272000" "A1：报出选中模型的窗口（来自 Pi 模型目录，不是猜的）"
assert_has "$TMP/m43-a1.log" "÷ 4" "A1：说清 token 是粗糙估算（JSONL 字节 ÷ 4）"
assert_has "$TMP/m43-a1.log" "--fresh" "A1：给出 --fresh 出路"
assert_has "$TMP/m43-a1.log" "--allow-overflow" "A1：给出显式放行的出路"
assert_not "$TMP/m43-a1.log" "含启动校验" "A1：没有真的派单"

# A2：--print 也走守卫（不生成一份注定 wedge 的计划）
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol --print >"$TMP/m43-a2.log" 2>&1; then
  bad "M4.3 A2：--print 也应被守卫拦住"
else ok "M4.3 A2：--print 也被拒（不会先打印一份注定 wedge 的计划）"; fi

# A3：窗口更大的模型 → 允许复用同一个会话
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model big/wide --print >"$TMP/m43-a3.log" 2>&1; then
  ok "M4.3 A3：大窗口模型可以复用同一会话"
else bad "M4.3 A3：大窗口模型被误拒"; cat "$TMP/m43-a3.log"; fi
assert_match "$TMP/m43-a3.log" "--session-id $SESSION-dev[ '\"]" "A3：复用的是同一个 session id"

# A4：--allow-overflow 是显式且醒目的（不是静默放行）
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol --allow-overflow --print >"$TMP/m43-a4.log" 2>&1; then
  ok "M4.3 A4：--allow-overflow 显式放行"
else bad "M4.3 A4：--allow-overflow 仍被拒"; fi
assert_has "$TMP/m43-a4.log" "你显式放行了偏大的会话" "A4：放行是醒目的警告（不是静默）"

# A5：--fresh = 新会话，不看历史
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol --fresh --print >"$TMP/m43-a5.log" 2>&1; then
  ok "M4.3 A5：--fresh 不受历史会话大小影响"
else bad "M4.3 A5：--fresh 被误拒"; fi
assert_match "$TMP/m43-a5.log" "--session-id $SESSION-dev-[0-9]+" "A5：--fresh 用带时间戳的新 session id"

# A6：窗口解析不到 → 保守阈值，并且明说「我不知道」
if m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model nope/unknown >"$TMP/m43-a6.log" 2>&1; then
  bad "M4.3 A6：未知窗口 + 大会话应当被拒"
else ok "M4.3 A6：未知窗口按保守阈值拒绝"; fi
assert_has "$TMP/m43-a6.log" "解析不到 nope/unknown 的窗口" "A6：明说窗口解析不到"
assert_has "$TMP/m43-a6.log" "保守阈值 ${TEAM_SESSION_WARN_TOKENS:-200000}" "A6：报出用的是保守阈值（不小于 200k）"

# A7：TEAM_MODEL_WINDOWS 显式覆盖 → 以项目配置为准
if m43 TEAM_MODEL_WINDOWS="sub2api/gpt-5.6-sol=1000000" $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol --print >"$TMP/m43-a7.log" 2>&1; then
  ok "M4.3 A7：TEAM_MODEL_WINDOWS 可显式覆盖窗口"
else bad "M4.3 A7：显式窗口覆盖没生效"; cat "$TMP/m43-a7.log"; fi

# A8（子发现 A′）：--model 必须在**第一次派单**就真的生效。旧实现回读 state（state 在启动后才写）→
#    派单日志印 sub2api，实际拉起的是 state 里的旧/默认模型 —— 而 A 的守卫正是按那个模型在判。
m43 $TEAM dispatch dev T1.1 "$TASKFILE" --model sub2api/gpt-5.6-sol --allow-overflow --print >"$TMP/m43-a8.log" 2>&1 || true
assert_has "$TMP/m43-a8.log" "--provider sub2api --model gpt-5.6-sol" "A8：启动命令用的是本次 --model（不是 state 里的旧模型）"

# A9：roster / ps 把「会话大小 vs 模型窗口」放在模型旁边
m43 TEAM_MODEL_WINDOWS="$M43_MODEL=272000" $TEAM roster >"$TMP/m43-roster.log" 2>&1 && ok "M4.3 A9：roster 退出码 0" || bad "M4.3 A9：roster 失败"
assert_has "$TMP/m43-roster.log" "$M43_MODEL" "A9：roster 显示 agent 的模型"
assert_has "$TMP/m43-roster.log" "400k/272k ⚠" "A9：roster 显示已用/窗口并标出超窗"
assert_has "$TMP/m43-roster.log" "会话=估算 tok/模型窗口" "A9：roster 说明会话数字的口径"
m43 TEAM_MODEL_WINDOWS="$M43_MODEL=272000" $TEAM ps >"$TMP/m43-ps.log" 2>&1 || true
assert_has "$TMP/m43-ps.log" "agent 会话（估算 tok / 模型窗口）" "A9：ps 有会话大小区块"
assert_has "$TMP/m43-ps.log" "400k/272k" "A9：ps 显示 dev 的会话大小"

# B1（楔死现场，D9 事件 B）：new-window 声称成功，命令却被卡死的进程吞掉 —— 什么都不跑。
# shim 语义：new-window「建成」窗口（state 文件在）但从不跑我们的命令；kill-window 能清掉它。
mkdir -p "$TMP/m43-wedge"
: > "$TMP/m43-wedge.log"
: > "$TMP/m43-wedge-pids.log"
M43_WEDGE_WIN="$TMP/m43-wedge-window"
rm -f "$M43_WEDGE_WIN"
cat > "$TMP/m43-wedge/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/m43-wedge.log"
case " \$* " in
  *" list-windows "*)
      [ -f "$M43_WEDGE_WIN" ] && printf 'dev\n'
      exit 0 ;;
  *" new-window "*)
      : > "$M43_WEDGE_WIN"
      sleep 300 >/dev/null 2>&1 &
      printf '%s\n' "\$!" >> "$TMP/m43-wedge-pids.log"
      exit 0 ;;
  *" kill-window "*)
      rm -f "$M43_WEDGE_WIN"
      exit 0 ;;
esac
exit 0
EOF
chmod +x "$TMP/m43-wedge/tmux"
if env PATH="$TMP/m43-wedge:$PATH" TEAM_PI_AGENT_DIR="$M43_AGENT_DIR" TEAM_DISPATCH_VERIFY_SEC=1 TEAM_DISPATCH_ALIVE_SEC=0 \
     $TEAM dispatch dev T1.1 "$TASKFILE" --fresh >"$TMP/m43-b1.log" 2>&1; then
  bad "M4.3 B1：楔死的窗口不该报成功"
else ok "M4.3 B1：派单进楔死窗口 → 如实报失败"; fi
assert_has "$TMP/m43-b1.log" "派单已发出但未能确认启动" "B1：标题就是「未能确认启动」（不是成功）"
assert_has "$TMP/m43-b1.log" "启动证据" "B1：说清缺的是什么证据"
assert_has "$TMP/m43-b1.log" "已重试 1 次" "B1：按约定重试了一次"
assert_has "$TMP/m43-b1.log" "杀掉" "B1：说明窗口被清掉（不留半启动现场）"
assert_not "$TMP/m43-b1.log" "含启动校验" "B1：没有假成功"
assert_eq "B1：new-window 试了两次（首发 + 重试）" "$(grep -c -- 'new-window' "$TMP/m43-wedge.log" 2>/dev/null | tr -d ' ')" "2"
assert_eq "B1：残留窗口被显式 kill-window（失败路径也是真做，不是只在文案里说）" "$(grep -c -- 'kill-window' "$TMP/m43-wedge.log" 2>/dev/null | tr -d ' ')" "2"
assert_eq "B1：失败后的窗口终态 = 不存在" "$(env PATH="$TMP/m43-wedge:$PATH" tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | tr -d ' \n')" ""
while IFS= read -r m43_wp; do case "$m43_wp" in ''|*[!0-9]*) ;; *) kill "$m43_wp" 2>/dev/null || true ;; esac; done < "$TMP/m43-wedge-pids.log"

# M7.5：退出通知的证据链是**事件**（窗口 harness 在 agent 返回后写下的 (nonce, 退出码)），
# 不是「睡一会儿再看一眼 pane 忙不忙」的采样 —— 采样点会落进「窗口回 shell」那段非确定性过程
# （本容器：交互 bash 读 ~/.bashrc → exec zsh -l → 登录 zsh 启动 churn），把已经退出的 agent
# 谎报成还在跑（同一提交 904/2 与 906/0 交替）。下面先做纯逻辑部分（快模式照跑）：
#   nonce 对不上（上一轮/上一个 agent 留的旧记录）→ 不算证据；本轮 nonce → 返回真实退出码。
m75_exit_probe() { # <在夹具仓库里执行的一小段（已加载配置）>
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$1" )
}
mkdir -p "$REPO/.pi/team/state"
printf 'stale-nonce 3\n' > "$REPO/.pi/team/state/dispatch-dev.exit"
assert_eq "M7.5 B4a：旧 nonce 的退出记录不算本轮证据（不谎报已退出）" \
  "$(m75_exit_probe 'team_wait_agent_exit dev fresh-nonce 1 >/dev/null && echo matched || echo none')" "none"
printf 'fresh-nonce 7\n' > "$REPO/.pi/team/state/dispatch-dev.exit"
assert_eq "M7.5 B4a：本轮 nonce → 报出真实退出码" \
  "$(m75_exit_probe 'team_wait_agent_exit dev fresh-nonce 1')" "7"
rm -f "$REPO/.pi/team/state/dispatch-dev.exit"

# B2（真窗口 + 真启动证据）：只在有 tmux 时跑
if [ "$FAST" = "1" ]; then
  fast_skip "6h·派单启动证据（真窗口）" "要真实 tmux 窗口 + 假 pi 进程（现场看窗口 harness 写下的证据）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  printf '#!/usr/bin/env bash\nsleep 120\n' > "$FAKE/pi-m43-live"
  chmod +x "$FAKE/pi-m43-live"
  if env TEAM_PI_BIN="$FAKE/pi-m43-live" TEAM_PI_AGENT_DIR="$M43_AGENT_DIR" TEAM_DISPATCH_VERIFY_SEC=6 TEAM_DISPATCH_ALIVE_SEC=2 \
       $TEAM dispatch dev T1.1 "$TASKFILE" --fresh >"$TMP/m43-b2.log" 2>&1; then
    ok "M4.3 B2：真窗口派单成功"
  else bad "M4.3 B2：真窗口派单失败"; cat "$TMP/m43-b2.log"; fi
  assert_has "$TMP/m43-b2.log" "含启动校验" "B2：成功报告写明含启动校验"
  assert_match "$TMP/m43-b2.log" "proof=spawn pid=[0-9]+" "B2：成功报告带非空启动证据"
  assert_file "$REPO/.pi/team/state/dispatch-dev.spawn" "B2：启动证据落盘（state/dispatch-dev.spawn）"
  # M7.5：反方向也要守 —— 还在跑的 agent 不能被说成「已经退出」（否则通知只是噪声）
  assert_not "$TMP/m43-b2.log" "已经退出" "B2：还在跑的 agent 不会被误报成已退出"
  assert_has "$TMP/m43-b2.log" "还在跑" "B2：观察结论明说 agent 还在跑（沉默不是结论）"
  # B3：agent 秒退（内置 Pi 路径）→ 启动证据仍成立（harness 跑了），所以不谎报失败；
  # 但必须明确说出来「窗口里的 agent 已经退出」，否则 PM 会以为它在干活。
  printf '#!/usr/bin/env bash\nexit 3\n' > "$FAKE/pi-m43-dead"
  chmod +x "$FAKE/pi-m43-dead"
  if env TEAM_PI_BIN="$FAKE/pi-m43-dead" TEAM_PI_AGENT_DIR="$M43_AGENT_DIR" TEAM_DISPATCH_VERIFY_SEC=4 TEAM_DISPATCH_ALIVE_SEC=1 \
       $TEAM dispatch dev T1.1 "$TASKFILE" --fresh >"$TMP/m43-b3.log" 2>&1; then
    ok "M4.3 B3：有启动证据 → 派单成立（不因 agent 秒退而谎报失败）"
  else bad "M4.3 B3：有启动证据时不该报失败"; cat "$TMP/m43-b3.log"; fi
  assert_has "$TMP/m43-b3.log" "含启动校验" "B3：成功报告写明含启动校验"
  assert_has "$TMP/m43-b3.log" "已经退出" "B3：agent 秒退被明确说出来（不假装一切正常）"
  assert_has "$TMP/m43-b3.log" "resume" "B3：给出续跑办法"
  assert_has "$REPO/.pi/team/state/dev.env" "task=T1.1" "B3：派单成立时仍写下任务记录（否则 PM 无法续跑）"
  # M7.5：通知里的退出码 + 证据文件必须来自**本轮窗口 harness**（nonce 与启动证据同源）。
  assert_file "$REPO/.pi/team/state/dispatch-dev.exit" "B3：退出证据落盘（state/dispatch-dev.exit）"
  assert_has "$TMP/m43-b3.log" "exit code 3" "B3：通知报出的是真实退出码（不是「大概退了」）"
  assert_eq "B3：退出证据与本轮启动证据同一个 nonce（同一轮，不是上一轮留的）" \
    "$(cut -d' ' -f1 "$REPO/.pi/team/state/dispatch-dev.exit" 2>/dev/null | tr -d ' ')" \
    "$(cut -d' ' -f1 "$REPO/.pi/team/state/dispatch-dev.spawn" 2>/dev/null | tr -d ' ')"
  assert_eq "B3：退出证据里的码来自 agent 自己的退出状态" \
    "$(cut -d' ' -f2 "$REPO/.pi/team/state/dispatch-dev.exit" 2>/dev/null | tr -d ' ')" "3"
  # 措辞守门：不得再声称「窗口已经回到 shell」—— 这不是我们在那一刻观察到的事实（M7.5 的教训）
  assert_not "$TMP/m43-b3.log" "回到 shell" "B3：不再声称「窗口已回到 shell」（未观察到的状态不许写进结论）"
  # M7.5 B4：同一场景重复 5 次 —— 「已经退出 + 退出码 + 续跑办法」必须是每次都拿到的结论，
  # 不能靠「睡一会儿再采样一次」撞运气（旧实现正是那样，现场 904/2 与 906/0 交替）。
  printf '#!/usr/bin/env bash\nexit 7\n' > "$FAKE/pi-m43-exit7"
  chmod +x "$FAKE/pi-m43-exit7"
  B4_ROUND=1
  while [ "$B4_ROUND" -le 5 ]; do
    # 先清掉证据：「文件写进来了」才能证明是本轮窗口 harness 写的（不是上一轮留的）
    rm -f "$REPO/.pi/team/state/dispatch-dev.exit"
    env TEAM_PI_BIN="$FAKE/pi-m43-exit7" TEAM_PI_AGENT_DIR="$M43_AGENT_DIR" TEAM_DISPATCH_VERIFY_SEC=4 TEAM_DISPATCH_ALIVE_SEC=1 \
      $TEAM dispatch dev T1.1 "$TASKFILE" --fresh >"$TMP/m43-b4-$B4_ROUND.log" 2>&1 || true
    # 有界轮询（不固定 sleep）：等 dispatch 把该写的写完（一条同步命令，这里确认落盘）
    B4_WAIT=0
    while [ "$B4_WAIT" -lt 40 ] && ! grep -qF "exit code 7" "$TMP/m43-b4-$B4_ROUND.log"; do sleep 0.05; B4_WAIT=$((B4_WAIT + 1)); done
    if grep -qF "exit code 7" "$TMP/m43-b4-$B4_ROUND.log" && grep -qF "resume" "$TMP/m43-b4-$B4_ROUND.log" \
       && grep -qE '^[^ ]+ 7$' "$REPO/.pi/team/state/dispatch-dev.exit" 2>/dev/null; then
      ok "M7.5 B4：第 $B4_ROUND/5 次秒退仍报出退出码 7 + 续跑办法（事件证据，不靠采样）"
    else
      # 失败诊断：有界轮询窗口回到 shell（最多 2s），把**最终观察到的**现场写进失败信息
      B4_PANE=""; B4_WAIT=0
      while [ "$B4_WAIT" -lt 40 ]; do
        B4_PANE="$(tmux display-message -p -t "$SESSION:dev" '#{pane_id} #{pane_pid} #{pane_current_command}' 2>/dev/null | tr -d '\n')"
        case "${B4_PANE##* }" in bash|zsh|sh|fish|dash|ash|ksh) break ;; esac
        sleep 0.05; B4_WAIT=$((B4_WAIT + 1))
      done
      bad "M7.5 B4：第 $B4_ROUND/5 次秒退没报出来（观察到的现场：pane=[${B4_PANE:-none}]（等了 $((B4_WAIT * 50))ms 等它回 shell） exit-record=[$(head -1 "$REPO/.pi/team/state/dispatch-dev.exit" 2>/dev/null || printf missing)] 日志尾=$(tail -3 "$TMP/m43-b4-$B4_ROUND.log" 2>/dev/null | tr '\n' '|')）"
    fi
    B4_ROUND=$((B4_ROUND + 1))
  done
  # 恢复现场：让后面的段落看到的 dev 窗口和改造前一样（活着的假 pi）
  sed -i 's|^TEAM_PI_BIN=.*|TEAM_PI_BIN="'"$FAKE/pi-sleep"'"|' "$REPO/.pi/team/config.sh"
  env TEAM_PI_AGENT_DIR="$TMP/piagent-empty" $TEAM dispatch dev T1.1 "$TASKFILE" >/dev/null 2>&1 \
    || team_dim "  （恢复 dev 窗口失败：后续段落自己会重建）"
else
  printf '  (跳过真窗口启动证据断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 6i. PM adapter（PM 也能跑在任意 TUI agent 上）
# M8.1：产品承诺是「PM 可以跑在任何 TUI agent CLI 上」。worker 侧早就可配（TEAM_AGENT_CMD），
# PM 侧以前写死 Pi：启动命令是 pi -c + @prompt-file，存活身份按 **worker 的 adapter** 解析可执行文件，
# 文案也写死叫用户去跑 pi。这里钉住三件事：
#   ① 三个新键全空时渲染出的 PM 命令与历史**逐字节一致**（同 M3.0 对 worker 的 invariance 证法）；
#   ② 模板复用同一个占位符引擎（畸形/未知占位符照样响亮失败），提示词仍落盘 state/pm-prompt.md，
#      {prompt} 走窗口 harness 的 argv[0]（提示词不进命令行）；
#   ③ 存活身份按 **PM 的** CLI 解析（不叫 pi 也算、wrapper 也算），真窗口端到端：拉起/崩溃重启/watchdog 拉起。
section "6i · PM adapter（任意 TUI agent 当 PM）：默认不变 / 模板 / 存活 / 真窗口"

# 在夹具仓库里跑一段 bash（新进程）：TEAM_* 赋值在 source/team_load_config **之前** export，
# 所以既不污染 smoke 自己的环境，又能覆盖夹具配置（环境变量优先于 config.sh）。
pm_bash() { # <bash 片段> [VAR=VALUE …]
  local body="$1"; shift
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c 'for _a in "$@"; do export "$_a"; done; . "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; '"$body" _ "$@" )
}
pm_probe() { pm_bash "$@"; }
# 渲染 PM 启动命令（默认/模板都走同一个 team_pm_launch_cmd）
pm_render() { # <prompt_file> [<spawn_file>] [VAR=VALUE …]
  local pf="$1" sp="${2:-/tmp/never.spawn}"; shift 2 2>/dev/null || shift "$#"
  pm_bash 'team_pm_launch_cmd "'"$pf"'" "'"$sp"'"' "$@"
}
PM_PF="$REPO/.pi/team/state/pm-prompt.md"
PM_SPAWN="$REPO/.pi/team/state/pm.pid.spawn"
PM_SUPPORT="$(pm_probe 'team_agent_placeholders pm' "TEAM_PI_BIN=$FAKE/pi" | tr '\n' ' ')"
PM_SUPPORT="${PM_SUPPORT% }"

# ① 默认不变（M3.0 的 invariance 证法）：三个键全空 → 与历史的那条 printf 逐字节一致
#    历史渲染式（改动前 team_pm_start 里的那行）与历史参数都**字面写死**在测试里 —— 参考值不调实现，
#    否则函数内部一改（比如把默认的 -c 删了）两边会一起动，assert_eq 就白写了。
#      printf 'cd %q && printf "%%s\\n" $$ > %q && exec %q %s @%q' <root> <spawn> <pi> "$(team_pm_pi_args)" <prompt>
#      （team_pm_pi_args 每个参数 %q 后带一个空格 → 最后是 `-c` + 一个空格，格式里 @ 前又有一个空格）
#    M27 起默认参数多了 `-e <skill>/extension/team-bg.ts`（PM 的后台门禁）、M30 起再多了
#    `-e <skill>/extension/team-inbox-watch.ts`（PM 的投递换道）：参考值同步加这两项，
#    它仍是**字面写死**的，不调实现。
#    M36 起整条命令再带一个**闸门前缀**（tmux 运行时闸门：PATH 最前 = scripts/shim、state/tmux-calls.log、
#    真 tmux 路径三段 export）——前缀同样字面写死；前缀以外的历史部分保持逐字节一致。
M36_REF_PREFIX="export PATH=$(printf '%q' "$SKILL_DIR/scripts/shim"):\"\$PATH\"; export TEAM_TMUX_CALLS_LOG=$(printf '%q' "$REPO/.pi/team/state/tmux-calls.log"); "
[ -n "$REAL_TMUX" ] && M36_REF_PREFIX="${M36_REF_PREFIX}export TEAM_TMUX_REAL=$(printf '%q' "$REAL_TMUX"); "
# M40 起再带一段**身份环境前缀**（继承的 TEAM_* 身份先清掉，只写本命令现场推导出的身份）：
# 前缀同样字面写死（值只取夹具已知量），前缀以外的历史部分保持逐字节一致。
m40sq() { printf "'%s'" "${1//\'/\'\\\'\'}"; }
M40_REF_PREFIX="unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_CONFIG_FILE TEAM_IDENTITY_LOCKED TEAM_IDENTITY_ROOT TEAM_IDENTITY_MAIN_ROOT TEAM_IDENTITY_PROJECT TEAM_IDENTITY_INHERIT_ROOT TEAM_IDENTITY_INHERIT_MAIN_ROOT TEAM_IDENTITY_INHERIT_PROJECT TEAM_IDENTITY_INHERIT_SESSION; export TEAM_ROOT=$(m40sq "$REPO"); export TEAM_MAIN_ROOT=$(m40sq "$REPO"); export TEAM_PROJECT=$(m40sq "$(basename "$REPO")"); export TEAM_SESSION=$(m40sq "$SESSION"); "
LEGACY_REF="${M40_REF_PREFIX}${M36_REF_PREFIX}cd $(printf '%q' "$REPO") && printf \"%s\\n\" \$\$ > $(printf '%q' "$PM_SPAWN") && exec $(printf '%q' "$FAKE/pi") --provider deepseek --model deepseek-flash -e $(printf '%q' "$SKILL_DIR/extension/team-bg.ts") -e $(printf '%q' "$SKILL_DIR/extension/team-inbox-watch.ts") --skill $(printf '%q' "$SKILL_DIR") -c  @$(printf '%q' "$PM_PF")"
DEFAULT_CMD="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi")"
assert_eq "M8.1 默认渲染与历史逐字节一致（TEAM_PM_CMD/BIN/RESUME_ARGS 全空；M27 起含 -e bg、M30 起再含 -e inbox-watch、M36 起带闸门 exports 前缀、M40 起带身份环境前缀）" "$DEFAULT_CMD" "$LEGACY_REF"
assert_has_echo "$DEFAULT_CMD" "extension/team-bg.ts" "M27：PM 默认命令加载 team-bg（后台门禁）"
assert_has_echo "$DEFAULT_CMD" "extension/team-inbox-watch.ts" "M30：PM 默认命令加载 inbox-watch（投递换道）"
assert_has_echo "$DEFAULT_CMD" " -c  @$PM_PF" "默认仍是 pi -c + @prompt-file（历史行为）"
# 显式配了续跑键就在内置 Pi 路径生效（同一套键也服务于自定义 CLI）
SID_CMD="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_SESSION_ID=pm-fixed')"
assert_has_echo "$SID_CMD" "--session-id pm-fixed" "TEAM_PM_SESSION_ID 仍走 --session-id"
case "$SID_CMD" in *' -c '*) bad "配了 SESSION_ID 还带 -c（重复续跑）";; *) ok "配了 SESSION_ID 就不再带 -c";; esac
RESUME_CMD="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_RESUME_ARGS=--continue')"
assert_has_echo "$RESUME_CMD" " --continue " "显式 TEAM_PM_RESUME_ARGS 替换掉默认的 -c"
case "$RESUME_CMD" in *' -c '*) bad "显式 resume 参数下仍带 -c";; *) ok "显式 resume 参数下没有多余的 -c";; esac

# ② 模板：同一个占位符引擎（PM 专有 {resume_args}），提示词仍走文件 + argv[0]
PM_TPL='mycli run --model {model} --prov {provider} --dir {cwd} --pf {prompt_file} --ask {prompt} --skill {skill_dir} {resume_args} {extra_args}'
TPL_CMD="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_CMD=$PM_TPL" 'TEAM_PM_BIN=bash' 'TEAM_PM_MODEL=demo/demo-model' \
  'TEAM_PM_RESUME_ARGS=--continue' 'TEAM_PM_EXTRA_PI_ARGS=--verbose' 'TEAM_EXTRA_PI_ARGS=--worker-only')"
assert_has_echo "$TPL_CMD" "mycli run" "模板被展开成一条命令"
assert_has_echo "$TPL_CMD" "--model demo-model" "{model} 渲染成模型名"
assert_has_echo "$TPL_CMD" "--prov demo" "{provider} 渲染成 provider"
assert_has_echo "$TPL_CMD" "--dir $REPO" "{cwd} 是主工作树（PM 的 cwd）"
assert_has_echo "$TPL_CMD" "--pf $PM_PF" "{prompt_file} 指向落盘的 PM 提示词"
assert_has_echo "$TPL_CMD" '--ask "$0"' "{prompt} 展开成窗口 harness 的 argv[0]（提示词不进命令行）"
assert_has_echo "$TPL_CMD" "--skill $SKILL_DIR" "{skill_dir} 渲染成 skill 目录"
assert_has_echo "$TPL_CMD" " --continue " "{resume_args} 渲染成 TEAM_PM_RESUME_ARGS"
assert_has_echo "$TPL_CMD" " --verbose" "{extra_args} 在 PM 模板里取 TEAM_PM_EXTRA_PI_ARGS"
case "$TPL_CMD" in *--worker-only*) bad "PM 模板的 {extra_args} 误用了 worker 的 TEAM_EXTRA_PI_ARGS";; *) ok "PM 的 {extra_args} 与 worker 的互不串线";; esac
# M8.1：判据不能再是「整串里有没有 `{`」—— harness 自己合法地含 ${TMUX_PANE:-} / $(date +%s)。
# 占位符的形状是 {名字}（`${…}` 是 shell 语法，不是模板占位符）。
if printf '%s' "$TPL_CMD" | grep -Eq '\{[A-Za-z_][A-Za-z0-9_]*\}'; then
  bad "渲染后的命令还有残留占位符：$TPL_CMD"
else ok "渲染后的命令没有残留占位符"; fi
assert_has_echo "$TPL_CMD" "exec bash -lc" "模板路径走窗口 harness（argv[0] = 提示词）"
CATP="\$(cat '$PM_PF')"
assert_has_echo "$TPL_CMD" "\"$CATP\"" "提示词以 \"\$(cat <prompt_file>)\" 作为 \$0 交给模板"
assert_has_echo "$TPL_CMD" 'printf "%s\n" "$BASHPID" >' "spawn 证据（F30）是子 shell 的 pid（它 exec 成 CLI；不是还没 exec 的 harness）"
assert_has_echo "$TPL_CMD" "pm.pid.spawn" "上面那行写的就是 state/pm.pid.spawn（启动证据的路径）"
assert_has_echo "$TPL_CMD" 'exec bash' "CLI 退出后窗口留在提示符（诊断不随窗口消失，退回点 2）"
assert_has_echo "$TPL_CMD" "pm-launch.exit" "harness 把 CLI 的退出码写进 state/pm-launch.exit"
# ②d 尾屏归一化（M8.1 实测的第二只虫子）：capture-pane 抓的是整屏 —— 「报错在最上面几行 + 后面几十行
#     空行」是**常态**，而以前诊断对这份文件取 `tail -30`：唯一的信号会被空行挤掉，看起来像「窗口没输出」。
NORM_IN="$(printf 'boom: cannot start\n'; printf '\n%.0s' $(seq 1 60))"
assert_eq "尾屏归一化：一堆空行不掩盖唯一的一行报错" "$(printf '%s' "$NORM_IN" | pm_bash 'team_pane_tail_normalize')" "boom: cannot start"
assert_eq "尾屏归一化：全空屏 → 空（不编造内容）" "$(printf '\n\n\n' | pm_bash 'team_pane_tail_normalize')" ""
assert_eq "尾屏归一化：空行不参与输出（前导空行也不许留下）" \
  "$( (printf '\n\n\n'; printf 'boom: cannot start\n'; printf '\n%.0s' $(seq 1 30)) | pm_bash 'team_pane_tail_normalize')" "boom: cannot start"
assert_has_echo "$(seq 1 40 | sed 's/^/line /' | pm_bash 'team_pane_tail_normalize')" "共 40 行非空输出，只留了前 30 行" "超过 30 行非空输出时说明截断"

# ②c 裸名字（M8.1 退回点 1）：模板首词在**调用者 PATH** 里、但**不在登录 bash PATH** 里时，
#     渲染出的命令必须是那个绝对路径 —— 否则窗口里 `exec 裸名字` 会 command not found。
BARE_DIR="$TMP/m81-bare-bin"; mkdir -p "$BARE_DIR"
printf '#!/bin/sh\nsleep 300\n' > "$BARE_DIR/pm-bare"; chmod +x "$BARE_DIR/pm-bare"
# M25：登录 shell 探针一律 </dev/null —— 后台进程组里读 tty 会吃 SIGTTIN 被停住（0% CPU 像挂死），
# 登录 profile（distrobox 的 host-spawn）就会碰 tty。门禁不该依赖调用者的 tty。
# M47：探针也不能赌「本机 profile 会重设 PATH」——distrobox 会，runner/普通容器的 /etc/profile 不会，
# 同一句断言在两台机器上语义不同（CI 实测假红）。夹具改成构造性的：给登录 shell 一个受控 HOME，
# 里面的 .bash_profile 明确把 PATH 重置成系统默认值。翻转：删掉这里的 HOME 注入 → 探针恢复成「看本机脸色」。
login_shell_hides() { # <目录> <名字> → 它打印的 command -v 结果（看不到 → MISSING）
  local dir="$1" name="$2" home
  home="$(mktemp -d "$TMP/login-home.XXXXXX")"
  printf 'PATH=/usr/bin:/bin\nexport PATH\n' > "$home/.bash_profile"
  env HOME="$home" PATH="$dir:$PATH" bash -lc "command -v $name || echo MISSING" </dev/null
}

# M47：`#{bracket_paste_flag}` 是 tmux **3.7 起**才有的格式（同族的旧 tmux 上产品保守地走「多行落文件
# + 一行指针」，那不是缺陷，是无从探测）。自建一个微 session 问一句，不赌调用者有没有 server。
tmux_has_bracket_paste_format() {
  local s="bpf-$$" v
  tmux new-session -d -s "$s" -x 80 -y 24 'sleep 5' 2>/dev/null || return 1
  v="$(tmux display-message -p -t "$s" '#{bracket_paste_flag}' 2>/dev/null)"
  tmux kill-session -t "$s" 2>/dev/null || true
  [ -n "$v" ]
}
assert_eq "夹具有效：登录 bash 看不到 $BARE_DIR（否则下面那条是假绿；受控 HOME profile，不赌本机 profile）" \
  "$(login_shell_hides "$BARE_DIR" pm-bare)" "MISSING"
assert_eq "夹具有效：调用者 PATH 看得到它" \
  "$(env PATH="$BARE_DIR:$PATH" bash -c 'command -v pm-bare || echo MISSING')" "$BARE_DIR/pm-bare"
BARE_RENDER="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi" "PATH=$BARE_DIR:$PATH" \
  'TEAM_PM_CMD=pm-bare --pf {prompt_file} --ask {prompt}')"
assert_has_echo "$BARE_RENDER" "exec $BARE_DIR/pm-bare " "裸名字被换成调用者 PATH 解析出的绝对路径（登录 bash 里没有它）"
case "$BARE_RENDER" in *'exec pm-bare '*) bad "渲染出的命令还在用裸名字（窗口里必然 command not found）";; *) ok "渲染出的命令不再出现裸名字";; esac
# 解析不到的裸名字才该报错（文案要指向真正的病根：PATH）
pm_expect_fail_bin() { # <模板> <期望片段>
  local tpl="$1" want="$2" log
  log="$TMP/pm-adapter-bin-$(printf '%s' "$tpl" | tr -c 'a-z0-9' _).log"
  if pm_probe 'team_pm_check_bin' "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_CMD=$tpl" >"$log" 2>&1; then
    bad "解析不到的 PM CLI「$tpl」竟然通过了预检"
  else ok "解析不到的 PM CLI → 预检就失败"; fi
  assert_has "$log" "$want" "预检报错指向病根（$tpl）"
}
pm_expect_fail_bin 'nosuchcli {prompt}' "它不在你的 PATH 里"

# ②b 校验复用 worker 引擎：畸形/未知/空白/多行照样响亮失败（PM 键名进报错）
pm_expect_fail() { # <名字> <模板> <期望片段>
  local name="$1" tpl="$2" want="$3" log="$TMP/pm-adapter-$1.log"
  if pm_probe 'team_pm_check_launch' "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_CMD=$tpl" >"$log" 2>&1; then
    bad "$name：坏的 PM 模板竟然被接受"
  else ok "$name：坏 PM 模板 → 直接失败"; fi
  assert_has "$log" "$want" "$name：报错说明原因"
}
pm_expect_fail bogus     'mycli {sessionid} {prompt}'      "{sessionid}"
pm_expect_fail malformed 'mycli { cwd } {prompt}'          "{ cwd }"
pm_expect_fail blank     '   '                            "只有空白"
PM_MARK="$TMP/pm-adapter-second-line-ran"; rm -f "$PM_MARK"
pm_expect_fail multiline "mycli {prompt}"$'\n'"touch $PM_MARK" "含换行"
assert_not_file "$PM_MARK" "多行 PM 模板的第二行没有机会被执行"
# PM 没有 notify 扩展 / 没有 worker 的摘要通道：这些占位符在 PM 模板里必须是未知的
pm_expect_fail noext   'mycli {notify_ext} {prompt}'       "{notify_ext}"
pm_expect_fail nosum   'mycli {summary} {prompt}'          "{summary}"
assert_has "$TMP/pm-adapter-bogus.log" "TEAM_PM_CMD" "报错点名了配置键"
assert_has "$TMP/pm-adapter-bogus.log" "{resume_args}" "报错列出支持的占位符（含 PM 专有键）"
# 反向：worker 模板里写 {resume_args} 依旧报未知（不改 worker 语义）
if env TEAM_AGENT_CMD='workercli {resume_args} {prompt}' TEAM_AGENT_BIN=bash \
     $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/pm-adapter-worker-resume.log" 2>&1; then
  bad "worker 模板里的 {resume_args} 不该被接受"
else ok "worker 模板里的 {resume_args} → 派单照旧失败（worker 语义没变）"; fi
assert_has "$TMP/pm-adapter-worker-resume.log" "{resume_args}" "worker 侧报错点名了那个占位符"
assert_has "$TMP/pm-adapter-worker-resume.log" "TEAM_AGENT_CMD" "worker 侧报错点名的是它自己的键"

# ③ 可执行文件解析 + 存活身份（不叫 pi 也算）
assert_eq "TEAM_PM_BIN 优先" "$(pm_probe 'team_pm_bin_path' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_BIN=bash')" "$(command -v bash | head -1)"
assert_eq "没配 BIN 时取模板首词" "$(pm_probe 'team_pm_bin_path' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=mycli {prompt}')" "mycli"
assert_eq "两个新键都空 → 还是 TEAM_PI_BIN" "$(pm_probe 'team_pm_bin_path' "TEAM_PI_BIN=$FAKE/pi")" "$FAKE/pi"
assert_eq "PM CLI 名（文案用）" "$(pm_probe 'team_pm_cli_name' "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_BIN=$FAKE/fake-pm-name")" "fake-pm-name"
assert_eq "默认 CLI 名仍是 pi" "$(pm_probe 'team_pm_cli_name' "TEAM_PI_BIN=$FAKE/pi")" "pi"
printf '#!/bin/sh\nsleep 300\n' > "$FAKE/fake-pm-name"; chmod +x "$FAKE/fake-pm-name"
"$FAKE/fake-pm-name" --manual-pm & PM_IDP=$!
sleep 0.5
assert_eq "身份：命令行里有配置的 PM CLI 就算（哪怕不叫 pi）" \
  "$(pm_probe "team_proc_is_pm_bin $PM_IDP && echo yes || echo no" 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_BIN=$FAKE/fake-pm-name")" "yes"
assert_eq "身份：没配这个 CLI 就不算（同一个 pid）" \
  "$(pm_probe "team_proc_is_pm_bin $PM_IDP && echo yes || echo no" 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_BIN=$FAKE/pi")" "no"
kill "$PM_IDP" 2>/dev/null || true
# 配了不可解析的 PM CLI：启动前就说清楚（不是拉一个空窗口再说“看不到 agent 进程”）
if pm_probe 'team_pm_check_bin' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=nosuchcli {prompt}' >"$TMP/pm-adapter-nobin.log" 2>&1; then
  bad "不可解析的 PM CLI 应当在启动前被拒"
else ok "不可解析的 PM CLI → 启动前失败"; fi
assert_has "$TMP/pm-adapter-nobin.log" "找不到 PM 可执行文件" "报错说明了是哪个可执行文件"
assert_has "$TMP/pm-adapter-nobin.log" "TEAM_PM_BIN" "报错指向 TEAM_PM_BIN"

# ③b 续跑语义：Pi 默认延续；自定义 CLI 没配 resume 参数就说清楚「历史不延续」
assert_eq "Pi 路径：默认 -c（延续）" "$(pm_probe 'team_pm_continuity' "TEAM_PI_BIN=$FAKE/pi")" "continued:pi -c（本目录上一个会话）"
case "$(pm_probe 'team_pm_continuity' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=mycli {prompt}' 'TEAM_PM_BIN=bash')" in
  lost:*) ok "自定义 CLI + 空 resume 参数 → 明确报「不延续」";; *) bad "自定义 CLI 空 resume 参数没有被报成 lost";; esac
assert_eq "自定义 CLI + resume + 模板带 {resume_args}" \
  "$(pm_probe 'team_pm_continuity' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=mycli {resume_args} {prompt}' 'TEAM_PM_RESUME_ARGS=--continue' 'TEAM_PM_BIN=bash')" \
  "continued:--continue（模板里的 {resume_args}）"
case "$(pm_probe 'team_pm_continuity' "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=mycli {prompt}' 'TEAM_PM_RESUME_ARGS=--continue' 'TEAM_PM_BIN=bash')" in
  *lost:*'{resume_args}'*) ok "配了 resume 但模板没写 {resume_args} → 报 lost 并点名原因";; *) bad "resume 参数没被模板引用时没有被发现";; esac

# ③c 文档 ↔ 代码契约（PM 段用显式标记划界；worker 段的表格仍由 6f 的扫描器管）
PM_DOC="$SKILL_DIR/references/agent-adapters.md"
pm_doc_bad_tokens() { # <doc> → PM 段里列了、但引擎不认识的占位符（每行一个）
  local t
  for t in $(awk '/<!-- pm-side:begin -->/{f=1;next} /<!-- pm-side:end -->/{f=0} f' "$1" \
               | grep -oE '\{[A-Za-z_][A-Za-z0-9_]*\}' | sort -u); do
    case " $PM_SUPPORT " in *" $t "*) ;; *) printf '%s\n' "$t" ;; esac
  done
}
assert_file "$PM_DOC" "PM 侧契约文档在"
assert_eq "文档 PM 段里的占位符都被引擎支持" "$(pm_doc_bad_tokens "$PM_DOC" | tr '\n' ' ')" ""
PM_DOC_MISSING=""
for _t in $PM_SUPPORT; do grep -qF "$_t" "$PM_DOC" || PM_DOC_MISSING="$PM_DOC_MISSING $_t"; done
assert_eq "每个 PM 占位符都在文档里出现过" "${PM_DOC_MISSING:-无}" "无"
PM_DOC_FLIP="$TMP/agent-adapters-pm-flip.md"
awk '/<!-- pm-side:end -->/{if(!done){print "| `{bogus_pm_placeholder}` | 注入的坏占位符（翻转自测） |"; done=1}} {print}' "$PM_DOC" > "$PM_DOC_FLIP"
assert_eq "翻转自测：PM 段里混进未支持的占位符会被抓到" "$(pm_doc_bad_tokens "$PM_DOC_FLIP" | tr '\n' ' ')" "{bogus_pm_placeholder} "

# ④ 真窗口端到端：非 Pi PM 被拉起 / 提示词真的交给它 / 崩溃重启（明说历史不延续）/ watchdog 拉起
if [ "$FAST" = "1" ]; then
  fast_skip "6i·非 Pi PM 端到端" "要真实 tmux 窗口 + 假 PM 进程（拉起/崩溃重启/watchdog 拉起）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  PMW="$($TEAM paths | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"; [ -n "$PMW" ] || PMW=pm
  PM_LOG="$TMP/pm-adapter-args.log"; : > "$PM_LOG"
  PM_SEEN="$TMP/pm-adapter-seen.txt"; rm -f "$PM_SEEN"
  # 假「非 Pi」PM CLI：把 argv/cwd/拿到的提示词落盘，然后按提示词的意思跑 team 命令（真 PM 的第一件事）
  cat > "$FAKE/fake-pm.sh" <<EOF
#!/usr/bin/env bash
# 假的非 Pi PM CLI：证明 teamsmith 在没有 Pi 的情况下也能启动 PM、把提示词交给它、让它在团队里干活
printf 'cwd=%s\n' "\$PWD" >> "$PM_LOG"
i=0; for a in "\$@"; do i=\$((i+1)); printf 'arg%d=%s\n' "\$i" "\$a" >> "$PM_LOG"; done
pf=""; ask=""
while [ \$# -gt 0 ]; do case "\$1" in --pf) pf="\$2"; shift 2 ;; --ask) ask="\$2"; shift 2 ;; *) shift ;; esac; done
{ printf 'prompt_file=%s\n' "\$pf"
  printf 'prompt_file_md5=%s\n' "\$(md5sum "\$pf" 2>/dev/null | cut -d' ' -f1)"
  printf 'argv_prompt_md5=%s\n' "\$(printf '%s' "\$ask" | md5sum | cut -d' ' -f1)"
  printf 'first_line=%s\n' "\$(head -1 "\$pf" 2>/dev/null)"
} > "$PM_SEEN"
printf -- '--- fake-pm: team digest ---\n' >> "$PM_LOG"
bash "$SKILL_DIR/scripts/team" digest >> "$PM_LOG" 2>&1 || true
printf -- '--- fake-pm: team board ls ---\n' >> "$PM_LOG"
bash "$SKILL_DIR/scripts/team" board ls >> "$PM_LOG" 2>&1 || true
printf -- '--- fake-pm: team dispatch --print ---\n' >> "$PM_LOG"
bash "$SKILL_DIR/scripts/team" dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md --print >> "$PM_LOG" 2>&1 || true
printf 'PM_FAKE_READY\n' >> "$PM_LOG"
sleep 600
EOF
  chmod +x "$FAKE/fake-pm.sh"
  PMCMD="$FAKE/fake-pm.sh --pf {prompt_file} --ask {prompt}"
  # TEAM_PI_BIN 指向不存在的东西：这一段证明 PM 侧真的不再需要 Pi
  pm_env() { env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$PMCMD" TEAM_PM_BIN="$FAKE/fake-pm.sh" "$@"; }
  pm_seen_field() { sed -n "s/^$1=//p" "$PM_SEEN" 2>/dev/null | head -1; }
  pm_lines() { wc -l < "$PM_LOG" 2>/dev/null | tr -d ' ' || echo 0; }
  # ── M12：夹具产物的有界等待（M9.7 纪律：轮询**实际条件**，不赌固定 sleep）──────────────
  # 事故形状（V9-E1 的同类残余）：`up` 的承诺只是「PM 进程起来了」（proof=spawn/argv），**不是**
  # 「CLI 已经写出第 N 行」；夹具（假 PM）落盘晚于 up 返回是**合法**时序。测试以前用固定 sleep /
  # 立刻采样来「同步」，负载下就随机读到半截或空文件 → 与产品行为无关的假红（门禁可信度被腐蚀）。
  # 等待**不是**把红等成绿：带 deadline，超时由下面每条断言照旧报红，并把最后看到的现场打出来。
  pm_wait() { # <秒> <判据…> → 0=判据成立（每 0.1s 轮询一次）
    local secs="${1:-5}"; shift
    local i=0 ticks=$(( ${secs:-5} * 10 ))
    while [ "$i" -lt "$ticks" ]; do "$@" && return 0; sleep 0.1; i=$((i + 1)); done
    return 1
  }
  pm_grew() { [ "$(pm_lines)" -gt "${1:-0}" ]; }                    # 夹具的 argv 日志比基线长了
  pm_dead() { ! pm_probe 'team_pm_pid_live' >/dev/null 2>&1; }      # 上一条 PM 不再算「活着的本项目 PM」
  pm_file() { [ -s "$1" ]; }                                        # 夹具产物已落盘且非空
  pm_ran_manual() { grep -qF -- 'arg1=--manual' "$PM_LOG" 2>/dev/null; }
  pm_wait_delta() { # <秒> <起始行数> <正则>：等 PM_LOG 的新增行里出现模式
    local secs="$1" from="$2" pat="$3" i=0 ticks=$(( ${1:-5} * 10 ))
    while [ "$i" -lt "$ticks" ]; do
      sed -n "$((from + 1)),\$p" "$PM_LOG" 2>/dev/null | grep -qE -- "$pat" && return 0
      sleep 0.1; i=$((i + 1))
    done
    return 1
  }
  pm_pane_has() { # <标记>：PM 窗口尾屏里有这个标记（pty → tmux 屏幕是异步的）
    case "$(pm_probe 'team_pm_pane_tail 3' 2>/dev/null || true)" in *"$1"*) return 0 ;; *) return 1 ;; esac
  }
  pm_scene() { # <说明>：有界等待超时时的现场（失败行自带证据，不必再考古）
    printf '    现场（%s）：argv 日志=%s 行，尾=[%s]\n' "$1" "$(pm_lines)" "$(tail -2 "$PM_LOG" 2>/dev/null | tr '\n' '|')"
  }
  # 夹具写 PM_SEEN 是逐字段追加：等**完整记录**（最后一个字段 first_line 出现）——只等「文件非空」
  # 会在负载下读到半截（argv_prompt_md5 可能还没写）。
  pm_wait_seen() { pm_wait 30 grep -q '^first_line=' "$PM_SEEN" 2>/dev/null; }
  # V9-E1：假 PM 把「看到的东西」写在开头，而 digest → board ls → dispatch --print 这条链
  # 要跑完才写 PM_FAKE_READY。只等 PM_SEEN 就断言会在负载高时提前读到半截日志（实测抖出
  # 3 条假红）。所以先等 READY（有界 30s），再断言——真死掉的 adapter 仍然会被下面抓到。
  pm_wait_ready() { pm_wait 30 grep -q "PM_FAKE_READY" "$PM_LOG" 2>/dev/null; }
  # 关窗口后等**上一条 PM 真的死了**再返回：进程没死透时 up 会把它当 running → 不启动新 PM
  # （旧实现的固定 sleep 0.3 正是在负载下把这条变成随机的）。
  pm_close_windows() {
    tmux kill-window -t "$SESSION:$PMW" 2>/dev/null || true
    pm_wait 5 pm_dead
  }

  # 1) team up 拉起非 Pi 的 PM（窗口/进程都没有 Pi）
  pm_close_windows
  pm_env $TEAM up >"$TMP/pm-adapter-up1.log" 2>&1 || { bad "非 Pi PM：up 失败"; cat "$TMP/pm-adapter-up1.log"; }
  assert_has "$TMP/pm-adapter-up1.log" "PM 已启动" "非 Pi PM 被拉起"
  assert_has "$TMP/pm-adapter-up1.log" "cli=fake-pm.sh" "启动文案报的是配置的 PM CLI（不是 pi）"
  assert_has "$TMP/pm-adapter-up1.log" "不延续" "resume 参数为空 → 明说历史上下文不延续"
  assert_has "$TMP/pm-adapter-up1.log" "team digest" "并给出接手方式（正式记录 + digest）"
  if pm_wait_seen; then ok "假 PM 在窗口里真的跑起来了（写下了自己看到的东西）"; else bad "假 PM 没跑起来（$PM_SEEN 空）"; fi
  pm_wait_ready || true   # 等它把 digest → board ls → dispatch --print 跑完整段再断言（V9-E1）
  assert_eq "提示词文件的内容真的交给它了（argv[0] 与文件同源）" "$(pm_seen_field argv_prompt_md5)" "$(printf '%s' "$(cat "$PM_PF" 2>/dev/null)" | md5sum | cut -d' ' -f1)"
  assert_has "$PM_SEEN" "prompt_file=$PM_PF" "模板里的 {prompt_file} 是落盘的 PM 提示词"
  PM_FIRST="$(head -1 "$PM_PF" 2>/dev/null)"
  assert_eq "argv 里拿到的提示词首行 == 提示词文件首行" "$(pm_seen_field first_line)" "$PM_FIRST"
  assert_has "$PM_LOG" "cwd=$REPO" "PM 的 cwd 是项目主工作树"
  assert_has "$PM_LOG" "--- fake-pm: team digest ---" "它拿到提示词后第一件事是 team digest"
  assert_has "$PM_LOG" "--- fake-pm: team board ls ---" "它也能用 team board ls"
  assert_has "$PM_LOG" "--- fake-pm: team dispatch --print ---" "它也能用 team dispatch --print"
  assert_has "$PM_LOG" "PM_FAKE_READY" "它跑完了整段（不是半死在那里）"
  assert_not "$PM_LOG" "pi-args.log" "PM 侧没有碰 Pi（TEAM_PI_BIN 指向不存在的东西）"
  pm_env $TEAM ps >"$TMP/pm-adapter-wd1.log" 2>&1 || true
  assert_match "$TMP/pm-adapter-wd1.log" "PM（$PMW）在运行" "team ps 看到 PM 在跑"
  pm_env $TEAM pulse status >"$TMP/pm-adapter-wd1b.log" 2>&1 || true
  assert_match "$TMP/pm-adapter-wd1b.log" "PM +在运行" "pulse status 也看到 PM 在跑"
  assert_has "$TMP/pm-adapter-wd1b.log" "proof=" "并显示启动证据（proof=）"
  PM_PID1="$(tr -dc '0-9' < "$REPO/.pi/team/state/pm.pid" 2>/dev/null || true)"
  if [ -n "$PM_PID1" ] && kill -0 "$PM_PID1" 2>/dev/null; then ok "state/pm.pid 记录的是活着的非 Pi PM"; else bad "state/pm.pid 无效（[$PM_PID1]）"; fi
  # M8.1：记下的必须是 **CLI 进程**，而不是「CLI 退出后还活着」的 harness 壳 ——
  # 后者（EOF 后 exec bash）会让 PM 永远被判成在跑（假存活）。
  PM_ARGS1="$(ps -o args= -p "$PM_PID1" 2>/dev/null | head -1)"
  case "$PM_ARGS1" in
    *"-lc"*|*pm.pid.spawn*) bad "state/pm.pid 记的是 harness 壳（$PM_ARGS1）：CLI 死了它还活着 → 假存活" ;;
    *fake-pm.sh*)            ok "state/pm.pid 记的是 CLI 进程本身（不是 harness 壳）" ;;
    *)                       bad "state/pm.pid 指向意外进程：$PM_ARGS1" ;;
  esac

  # 2) 崩溃 → 重新 up：PM 回来；resume 参数为空时工具必须明说历史不延续
  LINES1="$(pm_lines)"; rm -f "$PM_SEEN"
  pm_close_windows
  pm_env $TEAM up >"$TMP/pm-adapter-up2.log" 2>&1 || true
  assert_has "$TMP/pm-adapter-up2.log" "PM 已启动" "崩溃后重新 up 能把它拉回来"
  assert_has "$TMP/pm-adapter-up2.log" "不延续" "并再次明说历史不延续（resume 参数为空）"
  assert_has "$TMP/pm-adapter-up2.log" "inbox" "给出接手指引（inbox / docs/team/**）"
  # M12：up 返回 ≠ 夹具已落盘 —— 等它真的长起来再断言（超时由下面那条报红，现场留在 pm_scene）
  pm_wait 5 pm_grew "$LINES1" || pm_scene "有界轮询 5s 内 argv 日志没长过基线（$LINES1 行）"
  assert_eq "这一轮确实是新的 PM 进程（argv 日志增长）" "$([ "$(pm_lines)" -gt "$LINES1" ] && echo grew || echo same)" "grew"

  # 2b) 对照：配上 resume 参数（模板里用 {resume_args}）→ 文案变成「续跑」，参数真的进了 argv
  PMCMD_R="$FAKE/fake-pm.sh {resume_args} --pf {prompt_file} --ask {prompt}"
  LINES2="$(pm_lines)"; rm -f "$PM_SEEN"
  pm_close_windows
  env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$PMCMD_R" TEAM_PM_BIN="$FAKE/fake-pm.sh" \
    TEAM_PM_RESUME_ARGS='--continue' $TEAM up >"$TMP/pm-adapter-up3.log" 2>&1 || true
  assert_has "$TMP/pm-adapter-up3.log" "续跑：--continue" "配了 {resume_args} → 文案说明怎么延续"
  assert_not "$TMP/pm-adapter-up3.log" "不延续" "不再说「历史不延续」"
  pm_wait_delta 5 "$LINES2" '^arg1=--continue$' \
    || pm_scene "有界轮询 5s 内新增行里没有 arg1=--continue（基线 $LINES2 行）"
  sed -n "$((LINES2 + 1)),\$p" "$PM_LOG" > "$TMP/pm-adapter-delta3.log" 2>/dev/null || true
  assert_has "$TMP/pm-adapter-delta3.log" "arg1=--continue" "resume 参数真的进了这一轮的 argv"

  # 3) watchdog：有待办 + PM 不在 → 同一套启动路径把它拉起来（非 Pi 也一样）
  $TEAM notify pm "M8.1 巡检：有待办" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/nudges.log" "$REPO/.pi/team/state/pm-restarts.log"
  LINES3="$(pm_lines)"; rm -f "$PM_SEEN"
  pm_close_windows
  tmux new-window -t "$SESSION" -n "$PMW" -d -c "$REPO" >/dev/null 2>&1 || true   # 窗口在、里面是空提示符
  PM_TICKS=0
  while [ "$PM_TICKS" -lt 3 ]; do
    pm_env $TEAM watch --once >"$TMP/pm-adapter-tick.log" 2>&1 || true
    grep -q '已拉起' "$TMP/pm-adapter-tick.log" && break
    PM_TICKS=$((PM_TICKS + 1)); sleep 1
  done
  assert_match "$TMP/pm-adapter-tick.log" "已拉起" "watchdog 在有待办时用同一个 helper 拉起非 Pi PM"
  assert_has "$REPO/.pi/team/state/watchdog.log" "已拉起" "watchdog 日志记录了这次拉起"
  assert_eq "重启配额只记了一次真实重启" "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ')" "1"
  pm_wait 5 pm_grew "$LINES3" || pm_scene "有界轮询 5s 内 argv 日志没长过基线（$LINES3 行）"
  assert_eq "这一轮真的拉起了新的 PM 进程" "$([ "$(pm_lines)" -gt "$LINES3" ] && echo grew || echo same)" "grew"
  assert_has "$TMP/pm-adapter-tick.log" "不延续" "watchdog 的拉起文案同样说清延续与否"

  # 4) wrapper PM：脚本 exec 掉自己之后进程映像换了名字 —— spawn 证据必须接住（F30 的非 Pi 版）
  printf '#!/bin/sh\nexec "%s" --wrapped "$@"\n' "$FAKE/fake-pm.sh" > "$FAKE/pm-wrapper"
  chmod +x "$FAKE/pm-wrapper"
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  pm_close_windows; rm -f "$PM_SEEN"
  env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$FAKE/pm-wrapper --pf {prompt_file} --ask {prompt}" TEAM_PM_BIN="$FAKE/pm-wrapper" \
    $TEAM up >"$TMP/pm-adapter-wrap.log" 2>&1 || true
  assert_has "$TMP/pm-adapter-wrap.log" "PM 已启动" "wrapper PM 被报为已启动"
  assert_has "$TMP/pm-adapter-wrap.log" "proof=spawn" "wrapper exec 掉自己 → 证据是 spawn（不是 argv）"
  if pm_wait_seen; then ok "wrapper 也真的把 CLI 跑起来了"; else bad "wrapper PM 没跑起来"; fi
  assert_has "$PM_LOG" "arg1=--wrapped" "wrapper 的额外参数原样传给了真 CLI"
  env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$FAKE/pm-wrapper --pf {prompt_file} --ask {prompt}" TEAM_PM_BIN="$FAKE/pm-wrapper" \
    $TEAM ps >"$TMP/pm-adapter-wrap-wd.log" 2>&1 || true
  assert_match "$TMP/pm-adapter-wrap-wd.log" "PM（$PMW）在运行" "wrapper PM 之后仍被判为在运行"
  # 4b) 人工在窗口里启动一个「不叫 pi」的 PM：没有 spawn 记录也要认得出来（身份按 PM 的 CLI 解析）
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec $FAKE/fake-pm.sh --manual" >/dev/null 2>&1 || true
  pm_wait 5 pm_ran_manual || pm_scene "有界轮询 5s 内人工启动的 CLI 没写下 argv"
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  pm_env $TEAM ps >"$TMP/pm-adapter-manual.log" 2>&1 || true
  assert_match "$TMP/pm-adapter-manual.log" "PM（$PMW）在运行" "人工启动的非 Pi PM 被认出（身份不认名字 pi）"
  case "$(pm_probe 'team_pm_state' 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_CMD=$PMCMD" "TEAM_PM_BIN=$FAKE/fake-pm.sh")" in
    running:*) ok "身份判定就是配置的 PM CLI（状态 $(pm_probe 'team_pm_state' 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_CMD=$PMCMD" "TEAM_PM_BIN=$FAKE/fake-pm.sh")）" ;;
    *) bad "人工启动的非 Pi PM 没被身份判定认出（$(pm_probe 'team_pm_state' 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_CMD=$PMCMD" "TEAM_PM_BIN=$FAKE/fake-pm.sh")）" ;;
  esac
  case "$(pm_probe 'team_pm_state' 'TEAM_PI_BIN=/definitely-not-pi' "TEAM_PM_CMD=$PMCMD" "TEAM_PM_BIN=$FAKE/pi")" in
    running:*) bad "没配这个 CLI 却仍被判成 running（身份判定没按 TEAM_PM_BIN 走）" ;;
    *) ok "同一个窗口：换成不匹配的 TEAM_PM_BIN 就不再算 PM" ;;
  esac

  # 5) 裸名字（退回点 1）：CLI 只在调用者 PATH 里、登录 bash 看不到 —— 必须仍然启动成功
  BARE_DIR="$TMP/m81-bare-bin"; mkdir -p "$BARE_DIR"
  printf '#!/usr/bin/env bash\nprintf "bare-pm-ran %%s\\n" "$*" >> "%s"\nsleep 600\n' "$TMP/pm-bare.log" > "$BARE_DIR/pm-bare"
  chmod +x "$BARE_DIR/pm-bare"
  pm_close_windows; rm -f "$TMP/pm-bare.log"
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  env PATH="$BARE_DIR:$PATH" TEAM_PI_BIN=/definitely-not-pi \
    TEAM_PM_CMD='pm-bare --pf {prompt_file} --ask {prompt}' TEAM_PM_BIN= \
    $TEAM up >"$TMP/pm-adapter-bare.log" 2>&1 || true
  assert_has "$TMP/pm-adapter-bare.log" "PM 已启动" "裸名字（只在调用者 PATH 里）也能启动 PM"
  assert_has "$TMP/pm-adapter-bare.log" "cli=pm-bare" "启动文案报的是这个名字"
  assert_has "$TMP/pm-adapter-bare.log" "proof=" "并给出启动证据"
  pm_wait 5 pm_file "$TMP/pm-bare.log" || pm_scene "有界轮询 5s 内裸名字 CLI 没落盘"
  if [ -s "$TMP/pm-bare.log" ]; then ok "裸名字的 CLI 真的在窗口里跑起来了（登录 bash 里没有这个目录）"; else bad "裸名字的 CLI 没跑起来（$TMP/pm-bare.log 空）"; fi
  env PATH="$BARE_DIR:$PATH" TEAM_PI_BIN=/definitely-not-pi \
    TEAM_PM_CMD='pm-bare --pf {prompt_file} --ask {prompt}' TEAM_PM_BIN= \
    $TEAM ps >"$TMP/pm-adapter-bare-ps.log" 2>&1 || true
  assert_match "$TMP/pm-adapter-bare-ps.log" "PM（$PMW）在运行" "裸名字启动后的 PM 也算在运行"

  # 5b) 重抹窗口输出也不能丢最上面的报错行（M8.1 实测的第二只虫子）
  #     capture-pane 抓到的是整屏：CLI 的报错在最上面几行，后面跟着几十行空行。以前这里对整屏取 tail -30，
  #     信号被空行挤掉 —— 诊断看起来像「窗口没输出」。夹具里真的把报错写在最上面、后面垫 40 行空行。
  tmux respawn-pane -k -t "$SESSION:$PMW" \
    "printf 'PANE-MARKER-1\\n'; printf '\\n%.0s' \$(seq 1 40); printf 'PANE-MARKER-2\\n'; sleep 30" >/dev/null 2>&1 || true
  pm_wait 5 pm_pane_has "PANE-MARKER-2" \
    || printf '    现场（有界轮询 5s 内窗口没渲染出标记）：尾屏=[%s]\n' "$(pm_probe 'team_pm_pane_tail 3' 2>/dev/null | tr '\n' '|')"
  PN_FROM_PANE="$(pm_probe 'team_pm_pane_tail 3')"
  assert_has_echo "$PN_FROM_PANE" "PANE-MARKER-1" "重抹窗口输出保留最上面的报错行（不再被空行挤掉）"
  assert_has_echo "$PN_FROM_PANE" "PANE-MARKER-2" "空行之后的内容也还在"

  # 6) 启动失败必须留下诊断（退回点 2）：窗口最后几行 + 渲染出的命令 + CLI 退出码
  cat > "$FAKE/fake-pm-fail.sh" <<EOF
#!/usr/bin/env bash
echo "FAKE-PM-FAIL: cannot start (intentional)" >&2
exit 7
EOF
  chmod +x "$FAKE/fake-pm-fail.sh"
  pm_close_windows
  rm -f "$REPO/.pi/team/state/pm-launch-failed.log" "$REPO/.pi/team/state/pm-launch.exit"
  if env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$FAKE/fake-pm-fail.sh {prompt}" TEAM_PM_BIN="$FAKE/fake-pm-fail.sh" \
       TEAM_PM_START_WAIT=2 $TEAM up >"$TMP/pm-adapter-upfail.log" 2>&1; then
    bad "启动失败的 up 不该退出 0"
  else ok "启动失败 → up 非 0（不假报成功）"; fi
  assert_has "$TMP/pm-adapter-upfail.log" "pm-launch-failed.log" "错误信息给出诊断文件路径"
  # 断言读的是**复制到 $TMP 的那份**：6i 收尾会把 state/ 里的现场清掉（后面的段落要看到改造前的现场），
  # 而失败现场值得留档（排查时不用重跑整个 smoke）。
  cp "$REPO/.pi/team/state/pm-launch-failed.log" "$TMP/pm-adapter-upfail-diag.log" 2>/dev/null || true
  assert_has "$TMP/pm-adapter-upfail-diag.log" "FAKE-PM-FAIL" "诊断里有窗口最后几行（CLI 自己的报错）"
  assert_has "$TMP/pm-adapter-upfail-diag.log" "exit   : 7" "诊断里有 harness 记下的 CLI 退出码"
  assert_has "$TMP/pm-adapter-upfail-diag.log" "render : exec bash -lc" "诊断里有渲染出的命令（可手工复现）"
  assert_match "$TMP/pm-adapter-upfail-diag.log" "^pane   : .*（[0-9]+ 字节）" "诊断记下了尾屏抓取落盘的大小（0 字节也看得见）"
  # 归一化那块也得钉住：capture-pane 抓的是整屏（报错在最上面几行 + 后面几十行空行），
  # 以前诊断用 `tail -30` 取，只留下空行、看起来像「窗口没输出」（M8.1 实测的第二只虫子）。
  assert_has "$REPO/.pi/team/state/pm-launch-tail.txt" "FAKE-PM-FAIL" "尾屏文件里既有报错行也有后续空行（夹具与真实形态一致）"
  assert_match "$TMP/pm-adapter-upfail-diag.log" "^--- pane（CLI 退出那一刻，harness 自抓）---$" "诊断用的是 harness 自抓的那份（不必事后重抓）"
  tmux capture-pane -p -t "$SESSION:$PMW" -S -50 >"$TMP/pm-adapter-failpane.txt" 2>/dev/null || true
  assert_has "$TMP/pm-adapter-failpane.txt" "FAKE-PM-FAIL" "窗口没被连诊断一起杀掉（报错还在 pane 里）"

  # 收尾：后面的段落要看到和改造前一样的现场（dev 窗口还在、PM 侧清理干净）
  pm_close_windows
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn" \
        "$REPO/.pi/team/state/pm.pid.starting" "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/nudges.log" \
        "$REPO/.pi/team/state/pm-launch.exit" "$REPO/.pi/team/state/pm-launch-failed.log"
  $TEAM inbox --ack >/dev/null 2>&1 || true
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
else
  printf '  (跳过非 Pi PM 端到端断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 6j. worker adapter：裸名字 + 启动证据（M8.2）
# M8.1 修了 PM 侧的同一只虫子（6i ②c），并按 brief 的边界只**测量**了 worker 侧；M8.2 收口两件事：
#   ① 模板首词是裸名字、只存在于**调用者 PATH** 里 → 渲染成解析到的绝对路径（窗口 harness 是 bash -lc）；
#   ② 「harness 起来了」≠「agent 跑起来了」：adapter 立刻非 0 退出 = 派单失败 + 诊断文件，不再 ✓。
section "6j · worker adapter：裸名字解析 + agent 没跑起来必须响亮失败（M8.2）"

# ① 纯逻辑（快模式照跑）：渲染与守卫
M82_BARE_DIR="$TMP/m82-bare-bin"; mkdir -p "$M82_BARE_DIR"
printf '#!/bin/sh\nsleep 300\n' > "$M82_BARE_DIR/worker-bare"; chmod +x "$M82_BARE_DIR/worker-bare"
assert_eq "M8.2 夹具有效：登录 bash 看不到 $M82_BARE_DIR（否则下面那条是假绿）" \
  "$(login_shell_hides "$M82_BARE_DIR" worker-bare)" "MISSING"   # M47：受控 HOME profile（同 6i ②c）
assert_eq "M8.2 夹具有效：调用者 PATH 看得到它" \
  "$(env PATH="$M82_BARE_DIR:$PATH" bash -c 'command -v worker-bare || echo MISSING')" "$M82_BARE_DIR/worker-bare"
env PATH="$M82_BARE_DIR:$PATH" TEAM_AGENT_CMD='worker-bare --pf {prompt_file} --ask {prompt}' \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m82-print-bare.log" 2>&1 \
  || { bad "M8.2：裸名字的 dispatch --print 失败"; cat "$TMP/m82-print-bare.log"; }
grep -m1 '^cd ' "$TMP/m82-print-bare.log" > "$TMP/m82-cmdline-bare.log" || true
assert_has "$TMP/m82-cmdline-bare.log" "$M82_BARE_DIR/worker-bare --pf" "M8.2：裸名字被换成调用者 PATH 解析出的绝对路径"
assert_not "$TMP/m82-cmdline-bare.log" "&& worker-bare " "M8.2：渲染出的命令不再出现裸名字"
# 已经是绝对路径的首词原样保留（重复替换/加引号都是回归）
env TEAM_AGENT_CMD="$M82_BARE_DIR/worker-bare --pf {prompt_file}" TEAM_AGENT_BIN="$M82_BARE_DIR/worker-bare" \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m82-print-abs.log" 2>&1 || true
grep -m1 '^cd ' "$TMP/m82-print-abs.log" > "$TMP/m82-cmdline-abs.log" || true
assert_has "$TMP/m82-cmdline-abs.log" "$M82_BARE_DIR/worker-bare --pf" "M8.2：已经是绝对路径的首词原样保留"
# 显式 TEAM_AGENT_BIN 指向**另一个**名字时不改模板（与 PM 侧同一守卫；6f ② 的 myagent+bash 同样守着它）
env TEAM_AGENT_CMD='myagent run --ask {prompt}' TEAM_AGENT_BIN=bash \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/m82-print-otherbin.log" 2>&1 || true
grep -m1 '^cd ' "$TMP/m82-print-otherbin.log" > "$TMP/m82-cmdline-otherbin.log" || true
assert_has "$TMP/m82-cmdline-otherbin.log" "myagent run --ask" "M8.2：TEAM_AGENT_BIN 指向别的名字时不改模板首词"
# 文档契约（一两行就够，但必须和行为同一句话）
M82_TROUBLE="$SKILL_DIR/references/troubleshooting.md"
assert_has "$ADOC" 'resolved on the **caller' "M8.2 文档：worker 侧首词按调用者 PATH 解析"
assert_has "$ADOC" "dispatch-<agent>-launch-failed.log" "M8.2 文档：启动失败写出诊断文件"
assert_has "$M82_TROUBLE" 'state/dispatch-<agent>.exit' "M8.2 文档：退出事件是独立证据（harness ≠ agent）"
assert_has "$M82_TROUBLE" "exit=127" "M8.2 文档：exit=127 的含义（窗口里 command not found）"

# V9 返工 4 · 文档诚实性钉（C1/C2/C4/D2 + B6）：防止「去掉一句不实话」再长回来。
# spec 的位置随 OpenSpec 生命周期变（活动 change → archive → 主 spec），所以按序解析第一个存在的。
V94_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
V94_SPEC=""
for _cand in "$V94_ROOT/openspec/changes/deferred-delivery-and-draft-entry/specs/delivery-guard/spec.md" \
             "$V94_ROOT"/openspec/changes/archive/*deferred-delivery-and-draft-entry*/specs/delivery-guard/spec.md \
             "$V94_ROOT/openspec/specs/delivery-guard/spec.md"; do
  [ -f "$_cand" ] && { V94_SPEC="$_cand"; break; }
done
assert_has "$M82_TROUBLE" "not the only one" "V9-C4：whitespace 条目是同类洞枚举，不是「唯一已知漏判」"
assert_has "$M82_TROUBLE" "stall-timeout" "V9-B6：troubleshooting 写明 stall-timeout 可恢复"
assert_has "$M82_TROUBLE" "braille" "V9-D2：0.85.1 工作行按实测形状（braille + 文字）写"
if grep -q "Nothing else in the detector has this hole" "$M82_TROUBLE"; then
  bad "V9-C4：绝对句「检测器没有别的洞」又回来了"
else ok "V9-C4：绝对句不在（同类洞逐条列出）"; fi
if [ -n "$V94_SPEC" ]; then
  assert_has "$V94_SPEC" "stall-timeout" "V9-B6：spec 写明 stall-timeout 与 resume 语义"
  assert_has "$V94_SPEC" "the ones deliberately still open" "V9-C4：spec 把同类漏判当成一列表（含仍开的）"
else
  printf '  (跳过 V9 spec 钉：找不到 delivery-guard spec)\n'
fi

# ② 真窗口：裸名字的 CLI 真的被拉起；秒退非 0 的 adapter 必须失败 + 留诊断
if [ "$FAST" = "1" ]; then
  fast_skip "6j·worker adapter 启动证据（真窗口）" "要真实 tmux 窗口 + 假 adapter CLI（启动 / 秒退两条路径）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  M82_AGENT="adapter2"
  M82_ID="T1.3"
  M82_BRANCH="$(canon_branch "$M82_AGENT" "$M82_ID")"
  git -C "$REPO" worktree add -b "$M82_BRANCH" "$REPO/.worktrees/$M82_AGENT" "$PROTECTED" >/dev/null 2>&1 || true
  # 任务书放 state/（像 6g 那样）：T1.3 不进 BOARD，本节不改动「待复验」计数
  mkdir -p "$REPO/.pi/team/state"
  M82_TASK="$REPO/.pi/team/state/$M82_ID-m82-brief.md"
  # P24（B3）：change-less 的任务书要有锚（本节测的是启动证据，不是锚规则）
  printf '# %s · M8.2 adapter 启动证据\n\ntask: %s\nagent: %s\nanchor: none (infra) — smoke fixture\n' \
    "$M82_ID" "$M82_ID" "$M82_AGENT" > "$M82_TASK"
  M82_DIAG="$REPO/.pi/team/state/dispatch-$M82_AGENT-launch-failed.log"
  # (a) 裸名字：CLI 只存在于调用者 PATH（登录 bash 看不到，① 已证）
  cat > "$M82_BARE_DIR/worker-live" <<EOF
#!/usr/bin/env bash
printf 'worker-live-ran %s\n' "\$*" > "$TMP/m82-bare-ran.log"
sleep 120
EOF
  chmod +x "$M82_BARE_DIR/worker-live"
  env TEAM_AGENTS="dev verify $M82_AGENT" PATH="$M82_BARE_DIR:$PATH" \
    TEAM_AGENT_CMD='worker-live --pf {prompt_file} --ask {prompt}' \
    $TEAM dispatch "$M82_AGENT" "$M82_ID" "$M82_TASK" --fresh >"$TMP/m82-bare-dispatch.log" 2>&1 \
    || { bad "M8.2：裸名字 adapter 派单失败"; cat "$TMP/m82-bare-dispatch.log"; }
  assert_has "$TMP/m82-bare-dispatch.log" "含启动校验" "M8.2：裸名字 adapter 派单成立（有启动证据）"
  assert_match "$TMP/m82-bare-dispatch.log" "proof=spawn pid=[0-9]+" "M8.2：成功行仍带非空启动证据"
  M82_WAIT=0
  while [ "$M82_WAIT" -lt 60 ] && [ ! -s "$TMP/m82-bare-ran.log" ]; do sleep 0.25; M82_WAIT=$((M82_WAIT + 1)); done
  assert_file "$TMP/m82-bare-ran.log" "M8.2：裸名字的 CLI 真的在窗口里跑起来了（它自己的日志）"
  assert_has "$TMP/m82-bare-ran.log" "--pf $REPO/.pi/team/state/prompt-$M82_AGENT-$M82_ID.md" "M8.2：它拿到的是落盘的提示词"
  assert_has "$TMP/m82-bare-dispatch.log" "还在跑" "M8.2：还活着的 adapter 被如实报成「还在跑」"
  # (b) adapter 立刻以非 0 退出：派单必须失败，并留下可复查的诊断
  cat > "$FAKE/worker-die" <<'M82EOF'
#!/usr/bin/env bash
echo "M82-WORKER-DIE: cannot start (intentional)" >&2
exit 7
M82EOF
  chmod +x "$FAKE/worker-die"
  rm -f "$REPO/.pi/team/state/$M82_AGENT.env" "$M82_DIAG" "$REPO/.pi/team/state/dispatch-$M82_AGENT-tail.txt"
  if env TEAM_AGENTS="dev verify $M82_AGENT" TEAM_AGENT_CMD="$FAKE/worker-die --ask {prompt}" TEAM_AGENT_BIN="$FAKE/worker-die" \
       $TEAM dispatch "$M82_AGENT" "$M82_ID" "$M82_TASK" --fresh >"$TMP/m82-die.log" 2>&1; then
    bad "M8.2：agent 秒退非 0 时派单不该报成功"
  else ok "M8.2：agent 秒退非 0 → 派单失败（不再假成功）"; fi
  assert_not "$TMP/m82-die.log" "含启动校验" "M8.2：失败路径没有假成功行"
  assert_has "$TMP/m82-die.log" "exit=7" "M8.2：失败文案报出真实退出码（exit=7）"
  assert_has "$TMP/m82-die.log" "dispatch-$M82_AGENT-launch-failed.log" "M8.2：失败文案给出诊断文件路径"
  assert_not_file "$REPO/.pi/team/state/$M82_AGENT.env" "M8.2：失败的派单不写任务记录（roster 不会说它接过这个任务）"
  # 读**复制到 $TMP 的那份**：收尾会清现场，而失败现场值得留档（像 6i 对 pm-launch-failed.log 那样）
  cp "$M82_DIAG" "$TMP/m82-die-diag.log" 2>/dev/null || true
  assert_has "$TMP/m82-die-diag.log" "M82-WORKER-DIE: cannot start (intentional)" "M8.2：诊断里有 CLI 自己的报错（harness 自抓的尾屏）"
  assert_has "$TMP/m82-die-diag.log" "exit   : 7" "M8.2：诊断里有 harness 记下的退出码"
  assert_has "$TMP/m82-die-diag.log" "render : export PATH=$SKILL_DIR/scripts/shim:" "M8.2：诊断里有渲染出的命令（M36 起带闸门 exports 前缀，可手工复现）"
  assert_has "$TMP/m82-die-diag.log" "$FAKE/worker-die --ask" "M8.2：渲染命令里 worker 本体还在"
  assert_has "$TMP/m82-die-diag.log" "bin    : $FAKE/worker-die" "M8.2：诊断里有解析到的可执行文件"
  assert_match "$TMP/m82-die-diag.log" '^pane   : .*（[0-9]+ 字节）' "M8.2：诊断记下尾屏抓取落盘的大小"
  assert_match "$TMP/m82-die-diag.log" '^--- pane（agent 退出那一刻，harness 自抓）---$' "M8.2：诊断用的是 harness 自抓的那份（CLI 退出后 shell 可能清屏）"
  tmux capture-pane -p -t "$SESSION:$M82_AGENT" -S -50 >"$TMP/m82-die-pane.txt" 2>/dev/null || true
  assert_has "$TMP/m82-die-pane.txt" "M82-WORKER-DIE" "M8.2：窗口没被连诊断一起杀掉（报错还在 pane 里）"
  # (c) 正常 adapter 不受影响：6g 的假 agent（绝对路径、跑完退出 0）就是这条路径，这里再钉一次
  #     「以非 0 秒退才算失败」的另一半——退出码 0 的秒退只如实报告，不算失败。
  cat > "$FAKE/worker-done" <<'M82EOF'
#!/usr/bin/env bash
echo done
M82EOF
  chmod +x "$FAKE/worker-done"
  if env TEAM_AGENTS="dev verify $M82_AGENT" TEAM_AGENT_CMD="$FAKE/worker-done --ask {prompt}" TEAM_AGENT_BIN="$FAKE/worker-done" \
       $TEAM dispatch "$M82_AGENT" "$M82_ID" "$M82_TASK" --fresh >"$TMP/m82-done.log" 2>&1; then
    ok "M8.2：秒退但 exit 0 的 adapter 不算失败（脚本型 CLI 干完活就退）"
  else bad "M8.2：exit 0 的 adapter 被误判成失败"; cat "$TMP/m82-done.log"; fi
  assert_has "$TMP/m82-done.log" "含启动校验" "M8.2：exit 0 的 adapter 仍报派单成立"
  assert_has "$TMP/m82-done.log" "exit code 0" "M8.2：并如实说出「已退出（exit code 0）」（不假装它还在跑）"
  # 收尾：这一节不留窗口/worktree/分支/state（后面的段落要看到和改造前一样的现场）
  tmux kill-window -t "$SESSION:$M82_AGENT" 2>/dev/null || true
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/$M82_AGENT" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$M82_BRANCH" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/$M82_AGENT.env" "$REPO/.pi/team/state/dispatch-$M82_AGENT.exit" \
        "$REPO/.pi/team/state/dispatch-$M82_AGENT.spawn" "$REPO/.pi/team/state/dispatch-$M82_AGENT-tail.txt" "$M82_DIAG"
  M82_PEND="$($TEAM pulse status 2>/dev/null || true)"
  case "$M82_PEND" in
    *"待复验 [1-9]"*) bad "M8.2 清场没干净：pulse status 里还有待复验（会污染后面的巡检断言）" ;;
    *) ok "M8.2 清场后不再有待复验报告（不影响后面的巡检断言）" ;;
  esac
else
  printf '  (跳过 worker adapter 启动证据断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 6k. worker 存活判据（M37）
# 事故（2026-09-19 实测两次假告警）：worker 窗口的 pane_current_command 报 `bash`，真在干活的是它的子
# 进程 pi（pane_pid=bash └─ pi）。旧判据 team_pane_busy（pane_current_command + 前台进程组）把正在
# 干活的 dev / dev2 说成「停了」（pulse 的「停了的 agent」两次误报）。
# M37 起判据与 M6.5 的 PM 存活同源：pane_pid **本身或它的直接子进程**命令行命中配置的 agent 可执行
# 文件且 cwd 在本项目内（common.sh · team_agent_alive_in_pane）；pane_current_command 只作旁证。
# 本段的三种夹具：① 字面形状 bash -c '<agent> …'｜② 事故形状（交互 bash + set +m：旧判据在这里说
# 停）｜③ 对照（bash 里没有 agent 子进程 → 必须判停，不能靠 pane 忙不忙猜）。
section "6k · worker 存活：看 pane 进程树，不看 pane_current_command（M37）"
if [ "$FAST" = "1" ]; then
  fast_skip "6k·worker 存活判据（M37）" "要真实 tmux 窗口 + pane 进程树现场（bash 是 pane_pid、agent 是子进程）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  M37_AGENT="m37w"                          # 名册里的夹具 agent（默认窗口名 = 它自己）
  M37_STUB="$FAKE/m37-agent"
  printf '#!/usr/bin/env bash\nsleep 600\n' > "$M37_STUB"
  chmod +x "$M37_STUB"
  mkdir -p "$REPO/.pi/team/state"
  # 有任务但（判活时）窗口在跑 agent：进「停了的 agent」计数的那个形状
  printf 'task=T1.1\nwindow=%s\n' "$M37_AGENT" > "$REPO/.pi/team/state/$M37_AGENT.env"

  # 按 CLI 的方式加载夹具仓库的库（agent 可执行文件与名册用环境覆盖；不改 config.sh）。
  # 片段经 M37_BODY 传入、在加载完库之后 eval —— 避免在函数体里做多层引号拼接（M37 实测踩过：
  # 拼接错一处就会把整段片段当成一条命令名，断言全空跑）。
  m37_bash() { # <bash 片段> [参数…]
    local body="$1"; shift
    ( cd "$REPO" || return 1
      # 名册故意只留夹具 agent：待办计数不得受前面段落留下的别的 agent 记录影响（6k 只验自己的夹具）
      env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
        TEAM_PI_BIN="$M37_STUB" TEAM_AGENTS="$M37_AGENT" M37_BODY="$body" \
        bash -c '. '"'"$SKILL_DIR"'"'/scripts/lib/common.sh
                 for _f in '"'"$SKILL_DIR"'"'/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
                 team_load_config >/dev/null 2>&1
                 eval "$M37_BODY"' _ "$@" )
  }
  m37_verdict() { # <session:window> → alive/stopped（直接问 M37 的判据，不经文案）
    m37_bash 'if team_agent_alive_in_pane "$1"; then printf "alive\n"; else printf "stopped\n"; fi' "$1"
  }
  m37_child_of() { # <session:window> → 命中夹具 agent 的直接子进程 pid（没有 → 空）
    local p; p="$(tmux display-message -p -t "$1" '#{pane_pid}' 2>/dev/null | head -1)"
    [ -n "$p" ] || return 0
    ps -o pid=,args= --ppid "$p" 2>/dev/null | grep -F -- "$M37_STUB" | awk '{print $1; exit}'
  }
  m37_wait_child() { # <session:window> [十分之一秒数]：有界等它起来（M7.5：不赌固定 sleep）
    local i=0; while [ "$i" -lt "${2:-50}" ]; do [ -n "$(m37_child_of "$1")" ] && return 0; sleep 0.1; i=$((i + 1)); done
    return 1
  }
  m37_shape() { tmux display-message -p -t "$1" 'pane_pid=#{pane_pid} cmd=#{pane_current_command}' 2>/dev/null | tr -d '\n'; }
  m37_stopped_count() { # → 待办里第 7 个字段（停了的 agent）
    m37_bash 'team_pending_counts' | awk '{print $7}'
  }
  # M39：建窗后 pane_pid 先是**还没 exec 完的壳**（命令行 = tmux server 的 argv）。判据
  # team_proc_is_agent_bin 在一次判定里读**两次**命令行（先查 dispatch-*.spawn 排除，再逐词比对 agent
  # 可执行文件）；exec 正好落在两次读之间时，第一次读到「壳」（排除不生效）、第二次读到已经 exec 完的
  # bash（agent 路径已可见）→ 判成 alive。实测（docs/team/reports/M39-verify.md 有 R1/R2 现场）：修前
  # M34 / main 两棵树都是 ~10–15% 每次断言假红（同一份代码，与 M34 的改动无关）。
  # 所以断言前必须有界等「窗口成型」，条件要具体：目标窗口 pane_pid 可读 **且** 它的命令行里出现本段的
  # 夹具标记（标记写在命令行的尾巴上，看见它就等于 exec 完了 —— 之后两次读都看到完整命令行，排除稳定
  # 生效）。命令行用 -ww 读全：这里问的是「exec 完了吗」，不该被 ps 的输出宽度（COLUMNS）截断干扰
  # （宽度截断会让 dispatch-*.spawn 排除静默失效，见报告的「发现」。）
  m37_pane_args() { # <session:window> → pane_pid 的完整命令行（窗口/进程不在 → 空）
    local p; p="$(tmux list-panes -t "$1" -F '#{pane_pid}' 2>/dev/null | head -1)"
    [ -n "$p" ] || return 0
    ps -o args= -ww -p "$p" 2>/dev/null | head -1
  }
  m37_wait_shape() { # <session:window> <命令行里必须出现的标记> [十分之一秒数] → 0=已成型
    local i=0 args
    while [ "$i" -lt "${3:-50}" ]; do
      args="$(m37_pane_args "$1")"
      case "$args" in *"$2"*) return 0 ;; esac
      sleep 0.1; i=$((i + 1))
    done
    return 1
  }
  # M39：断言变红时**自己带现场** —— pane_pid / pane 命令行 / 判据命中的 pid 与它的命令行 / 那个 pid 的
  # is_agent_bin 判定 / 判据用的 agent 可执行文件 / 同 server 的窗口。一次红就能定位，不必再打补丁重跑。
  m37_diag() { # <session:window>
    local t="$1" pane
    pane="$(tmux list-panes -t "$t" -F '#{pane_pid}' 2>/dev/null | head -1)"
    printf '      · 现场 target=%s pane_pid=%s\n' "$t" "${pane:-（窗口/pane 不存在）}"
    printf '      · 同 server：%s\n' "$(tmux list-panes -a -F '#{session_name}:#{window_name}(active=#{pane_active},pid=#{pane_pid})' 2>/dev/null | tr '\n' ' ')"
    if [ -n "$pane" ]; then
      printf '      · pane 命令行：%s\n' "$(ps -o args= -ww -p "$pane" 2>/dev/null | head -1)"
      printf '      · 直接子进程：%s\n' "$(ps -o pid=,args= -ww --ppid "$pane" 2>/dev/null | tr '\n' ';')"
    fi
    m37_bash 'p="$(team_pane_agent_pid "$1" 2>/dev/null || true)"
              printf "      · agent 可执行文件（判据用的）：%s\n" "$(team_agent_bin_path)"
              if [ -z "$p" ]; then
                printf "      · team_pane_agent_pid=（没命中任何 pid）\n"
              else
                printf "      · team_pane_agent_pid=%s cwd=%s is_agent_bin=%s args=[%s]\n" "$p" \
                  "$(team_proc_cwd "$p" 2>/dev/null || echo "?")" \
                  "$(team_proc_is_agent_bin "$p" && echo yes || echo no)" \
                  "$(ps -o args= -ww -p "$p" 2>/dev/null | head -1)"
              fi' "$t"
  }
  m37_assert_verdict() { # <断言文案> <session:window> <期望>：断言 + 变红时自带现场
    local got; got="$(m37_verdict "$2")"
    assert_eq "$1" "$got" "$3"
    [ "$got" = "$3" ] || m37_diag "$2"
  }

  # ① 简报里的字面形状：bash -c '<agent> …'（bash 是 pane_pid、agent 是子进程）
  M37_W_LIT="m37-lit"
  m37_bash_target="$SESSION:$M37_W_LIT"
  tmux new-window -t "$SESSION" -n "$M37_W_LIT" -d -c "$REPO" -- \
    bash -c "\"$M37_STUB\" --m37 & wait; sleep 600" 2>/dev/null || bad "6k 夹具：字面形状窗口没建起来"
  if m37_wait_child "$m37_bash_target"; then
    ok "6k ① 夹具现场：$(m37_shape "$m37_bash_target")（agent 子进程 $(m37_child_of "$m37_bash_target")）"
  else
    bad "6k ① 夹具：5s 内没看到 agent 子进程（$(m37_shape "$m37_bash_target")）"
  fi
  m37_assert_verdict "6k ① 字面形状（bash 父 + agent 子）判活" "$m37_bash_target" "alive"

  # ② 事故形状：交互 bash（argv 只有选项）里 `set +m` 跑 agent —— job control 关掉后子进程不再
  #    单独占前台进程组，pane_current_command 又只是 bash，旧判据在这里判「停了」。
  M37_W_AGENT="$M37_AGENT"
  M37_W_AGENT_T="$SESSION:$M37_W_AGENT"
  tmux new-window -t "$SESSION" -n "$M37_W_AGENT" -d -c "$REPO" -- bash --noprofile --norc 2>/dev/null \
    || bad "6k 夹具：事故形状窗口没建起来"
  tmux send-keys -t "$M37_W_AGENT_T" 'set +m' Enter 2>/dev/null || true
  tmux send-keys -t "$M37_W_AGENT_T" "\"$M37_STUB\" --m37" Enter 2>/dev/null || true
  if m37_wait_child "$M37_W_AGENT_T"; then
    ok "6k ② 夹具现场（事故形状）：$(m37_shape "$M37_W_AGENT_T")（agent 子进程 $(m37_child_of "$M37_W_AGENT_T")）"
  else
    bad "6k ② 夹具：5s 内没看到 agent 子进程（$(m37_shape "$M37_W_AGENT_T")）"
  fi
  m37_assert_verdict "6k ② 事故形状（交互 bash + set +m）判活" "$M37_W_AGENT_T" "alive"
  # CLI 表面（digest / pulse 的「停了的 agent」）读的是同一份判据
  assert_eq "6k ② 待办：有任务但在跑的 agent 不算「停了的 agent」" "$(m37_stopped_count)" "0"

  # ④ 启动中的派单 harness（M4.3 B 的形状）：命令行里有 agent 路径 + dispatch-*.spawn，但还没 exec 出
  #    agent —— 不算证据（不把「正在启动」说成「在跑」；PM 侧的对应物是 pm.pid.spawn 排除）。
  M37_W_START="m37-start"
  M37_W_START_T="$SESSION:$M37_W_START"
  M37_START_MARK="dispatch-$M37_AGENT.spawn"   # 标记写在命令行尾巴上 → 看见它 = 这条命令行已经成型
  tmux new-window -t "$SESSION" -n "$M37_W_START" -d -c "$REPO" -- \
    bash -c "sleep 600 && true  # 派单 harness 形状：$M37_STUB … $M37_START_MARK" 2>/dev/null || true
  if m37_wait_shape "$M37_W_START_T" "$M37_START_MARK"; then
    ok "6k ④ 夹具现场：$(m37_shape "$M37_W_START_T")（命令行已成型，含 $M37_START_MARK）"
  else
    bad "6k ④ 夹具：5s 内没等到窗口成型（命令行里没出现 $M37_START_MARK；现场 args=[$(m37_pane_args "$M37_W_START_T")]）"
  fi
  m37_assert_verdict "6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停" "$M37_W_START_T" "stopped"
  # ⑤ 窗口名写错/窗口消失时必须判停 —— tmux 的 display-message 会静默回退到**当前窗口**，
  #    用它的输出当证据会把别的窗口的进程当成这个 agent（失败必须关闭，不许回声）。
  m37_assert_verdict "6k ⑤ 不存在的窗口（display-message 回退陷阱）判停" "$SESSION:no-such-window-m37" "stopped"

  # ③ 对照：同一个窗口换成「bash 里没有 agent 子进程」→ 必须判停（旧判据在这里反而说 alive）
  tmux kill-window -t "$M37_W_AGENT_T" 2>/dev/null || true
  # 尾巴上的注释只是本段的成型标记（不影响「bash 里没有 agent 子进程」这个形状）：不等到它出现，
  # 断言就可能落在「还没 exec 完」的现场上 —— 那种现场同样判停，会把 ③ 变成一次空跑。
  M37_PLAIN_MARK="6k③对照形状"
  tmux new-window -t "$SESSION" -n "$M37_W_AGENT" -d -c "$REPO" -- \
    bash -c "sleep 600 && true  # $M37_PLAIN_MARK" 2>/dev/null || true
  if m37_wait_shape "$M37_W_AGENT_T" "$M37_PLAIN_MARK"; then
    ok "6k ③ 夹具现场：$(m37_shape "$M37_W_AGENT_T")（bash 里没有 agent 子进程，命令行已成型）"
  else
    bad "6k ③ 夹具：5s 内没等到窗口成型（命令行里没出现 $M37_PLAIN_MARK；现场 args=[$(m37_pane_args "$M37_W_AGENT_T")]）"
  fi
  m37_assert_verdict "6k ③ 对照（bash 里没有 agent 子进程）判停" "$M37_W_AGENT_T" "stopped"
  assert_eq "6k ③ 对照：待办把它算成「停了的 agent 1」" "$(m37_stopped_count)" "1"

  # 清场：窗口 + 夹具 agent 的 state 不能留给后面的段落（尤其 12/14c 的零写入与真进程自检）
  for _w in "$M37_W_LIT" "$M37_W_AGENT" "$M37_W_START"; do tmux kill-window -t "$SESSION:$_w" 2>/dev/null || true; done
  rm -f "$REPO/.pi/team/state/$M37_AGENT.env"
else
  printf '  (跳过 worker 存活断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 7. 通知 / 收件箱 / digest
section "7 · notify / inbox / digest"
$TEAM notify dev "blocked: 缺 dependency X" >/dev/null 2>&1 && ok "notify 退出码 0" || bad "notify 失败"
assert_file "$REPO/docs/team/inbox/dev.md" "收件箱写入主工作树"
assert_has "$REPO/docs/team/inbox/dev.md" "blocked: 缺 dependency X" "收件箱内容正确"
$TEAM digest >"$TMP/digest.log" 2>&1 && ok "digest 退出码 0" || bad "digest 失败"
assert_has "$TMP/digest.log" "待处理通知" "digest 含待处理通知段"
assert_has "$TMP/digest.log" "blocked: 缺 dependency X" "digest 引用了新通知"
# M18：P8 改名（watchdog → pulse）的漏网回归。旧名字已经全仓库无定义，digest 里只留下
# `line 463: team_watchdog_state_text: command not found`，把「｜ watchdog 」后面的状态字段变空 ——
# 这两条断言必须同时看得见「shell 报错」和「字段没内容」，否则空字段会被当成正常输出放过。
assert_not "$TMP/digest.log" "command not found" "M18：digest 里没有 command not found（P8 改名漏网）"
assert_not "$TMP/digest.log" "team_watchdog_state_text" "M18：digest 里没引到已删除的旧函数名"
assert_match "$TMP/digest.log" '｜ pulse [^[:space:]]' "M18：digest 的 pulse 状态字段非空"
$TEAM inbox --ack >/dev/null 2>&1
$TEAM digest >"$TMP/digest2.log" 2>&1
assert_not "$TMP/digest2.log" "blocked: 缺 dependency X" "ack 后不再重复出现"
# M6.3 F26：PM 自己的收件箱（worker 走 notify pm --from-file，agent-adapters.md 推荐的通道）
# 必须与名册成员一样被看见/计数 —— 旧实现只遍历名册，PM 不在跑时这条通知等于消失。
printf 'worker summary awaiting the PM\n' > "$TMP/m63-pm-summary.txt"
$TEAM notify pm --from-file "$TMP/m63-pm-summary.txt" >/dev/null 2>&1 && ok "notify pm 退出码 0" || bad "notify pm 失败"
assert_has "$REPO/docs/team/inbox/pm.md" "worker summary awaiting the PM" "PM 自己的收件箱写入"
$TEAM digest >"$TMP/digest-pm.log" 2>&1 || true
assert_has "$TMP/digest-pm.log" "PM 自己的收件箱" "F26：digest [2] 标注 PM 自己的收件箱"
assert_has "$TMP/digest-pm.log" "worker summary awaiting the PM" "F26：digest 引用了这条通知"
assert_has "$TMP/digest-pm.log" "未读通知" "F26：digest 的待办里算上它"
$TEAM inbox >"$TMP/inbox-pm.log" 2>&1 || true
assert_has "$TMP/inbox-pm.log" "PM 自己的收件箱" "F26：team inbox 显示 PM 自己的收件箱"
# 非名册收件人（打错的名字）也有文件即收件人：不会变成没人读的死信
printf '%s\n' '- x [manual] agent:devv · stray' >> "$REPO/docs/team/inbox/devv.md"
$TEAM digest >"$TMP/digest-stray.log" 2>&1 || true
assert_has "$TMP/digest-stray.log" "devv" "F26：非名册收件人在 digest [2] 可见"
$TEAM standby status >"$TMP/standby-pm.log" 2>&1 || true
assert_has "$TMP/standby-pm.log" "未读通知 2" "F26：待办计数（watchdog 的输入）把 pm + devv 都算上"
$TEAM inbox --ack >/dev/null 2>&1
$TEAM digest >"$TMP/digest-pm2.log" 2>&1 || true
assert_not "$TMP/digest-pm2.log" "worker summary awaiting the PM" "F26：ack 之后不再重复"
# ack 基线失效要能自愈：文件被清掉重建到比 ack 时更短（比如清了现场），新的一行不能永远看不见
printf '%s\n' '- x [manual] agent:dev · rebuilt inbox line 1' '- x [manual] agent:dev · rebuilt inbox line 2' > "$REPO/docs/team/inbox/dev.md"
$TEAM inbox --ack >/dev/null 2>&1                       # acked=2
printf '%s\n' '- x [manual] agent:dev · rebuilt inbox after shrink' > "$REPO/docs/team/inbox/dev.md"
$TEAM digest >"$TMP/digest-rebuilt.log" 2>&1 || true
assert_has "$TMP/digest-rebuilt.log" "rebuilt inbox after shrink" "F26：收件箱被重建到更短后新消息仍然可见（旧 ack 计数不会把它藏起来）"
$TEAM inbox --ack >/dev/null 2>&1
rm -f "$REPO/docs/team/inbox/devv.md"
# M6.3 F18：打错的收件人不能静默吞消息（写进没人读的收件箱 = 死信）
if $TEAM say devv "typo?" >"$TMP/say-unknown.log" 2>&1; then bad "say 未知收件人应当非 0 退出"; else ok "say 未知收件人非 0 退出"; fi
assert_has "$TMP/say-unknown.log" "不在名册里" "报错说明收件人不在名册里"
assert_has "$TMP/say-unknown.log" "dev" "报错点名名册成员"
assert_has "$TMP/say-unknown.log" "--any" "给出 --any 强制投递的出路"
assert_not_file "$REPO/docs/team/inbox/devv.md" "未知收件人没有写出死信收件箱"
$TEAM say devv --any "forced for a non-roster name" >"$TMP/say-any.log" 2>&1 && ok "say --any 强制投递成功" || bad "say --any 失败"
assert_has "$REPO/docs/team/inbox/devv.md" "forced for a non-roster name" "--any 的消息真的落盘"
assert_has "$REPO/.pi/team/state/inbox-unknown.log" "devv" "--any 的越权投递留痕（state/inbox-unknown.log）"
if $TEAM notify devv "typo?" >"$TMP/notify-unknown.log" 2>&1; then bad "notify 未知收件人也应当非 0"; else ok "notify 未知收件人非 0 退出"; fi
assert_has "$TMP/notify-unknown.log" "--any" "notify 的报错也给出 --any"
$TEAM notify pm "pm 是合法收件人" >/dev/null 2>&1 && ok "notify pm 仍然合法（PM 自己的收件箱）" || bad "notify pm 被误拒"
rm -f "$REPO/docs/team/inbox/devv.md"
$TEAM inbox --ack >/dev/null 2>&1

# ----------------------------------------- 7b. digest 警告未入账的复验/报告记录（M31）
section "7b · digest 警告未入账的复验/报告记录（M31）"
# 专用夹具仓库（M16/M14 同款纪律）：这里的「干净」是真干净。主夹具仓库在 4b 留下了
# untracked 的 reviews/T1.1-done.md（后续小节还要用它）——在那里做「干净树不报警」会假红。
M31R="$TMP/m31repo"; rm -rf "$M31R"; mkdir -p "$M31R"
( cd "$M31R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m31' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
M31SES="teamsmith-smoke-m31-$$"
( cd "$M31R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$M31SES" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/m31-init.log" 2>&1 \
  && ok "M31 夹具仓库 init 成功" || bad "M31 夹具仓库 init 失败（见 $TMP/m31-init.log）"
# 身份隔离（M7.2 纪律）：写盘之前先证明 team 认的是这个临时仓库 + 这个临时 session
( cd "$M31R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/m31-paths.json" 2>&1 || true
assert_eq "M31 隔离：team paths 的 main_root 就是 M31 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m31-paths.json")" "$M31R"
m31() { ( cd "$M31R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
# init 的脚手架（reviews|reports 的 .gitkeep/.gitignore）先入账：“干净树”才成立
if git -C "$M31R" add -A >/dev/null 2>&1 && git -C "$M31R" commit -qm "chore: init scaffold" >/dev/null 2>&1; then
  ok "M31 夹具：init 脚手架已入账"
else
  bad "M31 夹具：init 脚手架提交失败"
fi
m31 $TEAM digest >"$TMP/m31-clean.log" 2>&1 || bad "M31：干净树 digest 失败"
assert_not "$TMP/m31-clean.log" "记录未入账" "M31：干净树不打警告"
# 负对照：records/ 之外的 untracked 文件（比如一份任务书）不触发警告
printf 'not a record\n' > "$M31R/docs/team/M31-not-a-record.md"
m31 $TEAM digest >"$TMP/m31-decoy.log" 2>&1 || bad "M31：decoy digest 失败"
assert_not "$TMP/m31-decoy.log" "记录未入账" "M31：records/ 之外的 untracked 文件不触发警告"
rm -f "$M31R/docs/team/M31-not-a-record.md"
# 造未跟踪记录：复验记录 + 交付报告 + 报告包里的文件（--untracked-files=all 必须看到包里的文件）
M31_REV="docs/team/reviews/M31-flip.md"
M31_REP="docs/team/reports/M31-flip-dev.md"
M31_PKG="docs/team/reports/M31-flip-dev/pkg/run.sh"
mkdir -p "$M31R/docs/team/reports/M31-flip-dev/pkg"
printf '# M31-flip · 复验记录\n' > "$M31R/$M31_REV"
printf '# M31-flip-dev · 交付报告\n\nagent: dev\n' > "$M31R/$M31_REP"
printf 'echo fixture\n' > "$M31R/$M31_PKG"
m31 $TEAM digest >"$TMP/m31-untracked.log" 2>&1 || bad "M31：未跟踪时 digest 失败"
assert_has "$TMP/m31-untracked.log" "记录未入账" "M31：未跟踪的复验/报告记录触发警告行"
assert_has "$TMP/m31-untracked.log" "$M31_REV" "M31：警告点名未跟踪的复验记录"
assert_has "$TMP/m31-untracked.log" "$M31_REP" "M31：警告点名未跟踪的报告"
assert_has "$TMP/m31-untracked.log" "$M31_PKG" "M31：报告包里的文件也被点名（不是只报一个目录）"
# M16 口径：警告行里带代号 → 同一行必须带名字（这里用一个看板上有名字的任务做正对照）
m31 $TEAM board add M31A "夹具：未入账也要带名字" dev - >/dev/null 2>&1 || true
mkdir -p "$M31R/docs/team/reviews"
printf '# M31A · 复验记录（夹具）\n' > "$M31R/docs/team/reviews/M31A.md"
m31 $TEAM digest >"$TMP/m31-named.log" 2>&1 || bad "M31：带名字的 digest 失败"
assert_has "$TMP/m31-named.log" "reviews/M31A.md（夹具：未入账也要带名字）" "M31：警告行带代号时必须随身带名字（M16 口径）"
# 翻转：提交后警告消失（入账才算数）
if git -C "$M31R" add "$M31_REV" "$M31_REP" "$M31_PKG" docs/team/reviews/M31A.md >/dev/null 2>&1 \
   && git -C "$M31R" commit -qm "docs(team): M31 fixture records" >/dev/null 2>&1; then
  ok "M31 翻转夹具：记录已提交"
else
  bad "M31 翻转夹具：提交失败（后续断言无意义）"
fi
m31 $TEAM digest >"$TMP/m31-committed.log" 2>&1 || bad "M31：提交后 digest 失败"
assert_not "$TMP/m31-committed.log" "记录未入账" "M31：提交后警告消失（翻转）"
# 反向翻转：记录退回未入账状态 → 警告必须回来（证明它盯的是 git 状态，不是巧合）
git -C "$M31R" reset -q --mixed HEAD~1 >/dev/null 2>&1
m31 $TEAM digest >"$TMP/m31-unstaged.log" 2>&1 || bad "M31：反翻转 digest 失败"
assert_has "$TMP/m31-unstaged.log" "记录未入账" "M31：记录退回未入账状态 → 警告回来（翻转双向）"

# ── P47/R2：工作树里的记录也要点名（P36 的形状）─────────────────────────────────────────────────
# agent 的报告与报告包写在自己的工作树里，PM 的 squash 合并只带分支内容 —— 它们与主检出的记录同样
# 悬置。[4] 逐工作树跑同一条 `git status --porcelain --untracked-files=all -- <docs>/reviews
# <docs>/reports`：命中按「<agent>: <工作树内相对路径>」逐文件点名（包内文件也是），**两条记录路径
# 之外**的脏文件/构建目录静默，退出码不变（提醒，不拦路）。
git -C "$M31R" add "$M31_REV" "$M31_REP" "$M31_PKG" docs/team/reviews/M31A.md >/dev/null 2>&1 \
  && git -C "$M31R" commit -qm "docs(team): M31 fixture records (worktree baseline)" >/dev/null 2>&1
mkdir -p "$M31R/.worktrees"
M31WT="$M31R/.worktrees/dev"
git -C "$M31R" worktree add -q -b task/m31-wt "$M31WT" main >/dev/null 2>&1
if [ -e "$M31WT/.git" ]; then ok "M31-WT 夹具：工作树就位（.worktrees/dev）"; else bad "M31-WT 夹具：工作树起不来（后续断言无意义）"; fi
M31_WREV="docs/team/reviews/T9.md"
M31_WREP="docs/team/reports/T9-dev.md"
M31_WPKG="docs/team/reports/T9-dev/run.sh"
mkdir -p "$M31WT/docs/team/reviews" "$M31WT/docs/team/reports/T9-dev" "$M31WT/build"
printf 'not a record\n' > "$M31WT/junk.txt"                      # 记录路径之外 → 静默
printf 'scratch\n' > "$M31WT/build/scratch.tmp"                   # 构建 scratch 目录 → 静默
# 先钉「只有非记录脏文件时一条都不报」：这正是两个记录路径的过滤在把关。
m31 $TEAM digest >"$TMP/m31-wt-decoy.log" 2>&1 || bad "M31-WT：只有 decoy 时 digest 失败"
assert_not "$TMP/m31-wt-decoy.log" "记录未入账" "M31-WT：工作树里的非记录脏文件不触发警告（无记录时不打）"
assert_not "$TMP/m31-wt-decoy.log" "junk.txt" "M31-WT：junk.txt 一条都不点名"
assert_not "$TMP/m31-wt-decoy.log" "scratch.tmp" "M31-WT：构建 scratch 目录一条都不点名"
printf '# T9 · 复验记录（工作树夹具）\n' > "$M31WT/$M31_WREV"
printf '# T9-dev · 交付报告（工作树夹具）\n\nagent: dev\n' > "$M31WT/$M31_WREP"
printf 'echo fixture\n' > "$M31WT/$M31_WPKG"
m31 $TEAM digest >"$TMP/m31-wt.log" 2>&1; M31W_RC=$?
assert_eq "M31-WT：digest 退出码 0（未入账提醒不拦路）" "$M31W_RC" "0"
assert_has "$TMP/m31-wt.log" "记录未入账" "M31-WT：工作树记录触发警告行"
assert_has "$TMP/m31-wt.log" "dev: $M31_WREV" "M31-WT：工作树里的复验记录被点名（<agent>: <路径>）"
assert_has "$TMP/m31-wt.log" "dev: $M31_WREP" "M31-WT：工作树里的报告被点名"
assert_has "$TMP/m31-wt.log" "dev: $M31_WPKG" "M31-WT：报告包内的文件也逐文件点名（不是只报目录）"
assert_not "$TMP/m31-wt.log" "junk.txt" "M31-WT：有记录时 junk.txt 仍然静默"
assert_eq "M31-WT：未入账清单恰好三份（主检出记录已入账）" \
  "$(grep -c '^    · dev: ' "$TMP/m31-wt.log")" "3"
# 查不到名字的记录：只印裸路径，不编名字（M16 口径；`ZZZ` 不在 BOARD/任务书里，首行故意不是 H1 标题
# → 连报告 H1 兜底也给不出名字）。
printf '（没有 H1 标题的记录：名字查不到）\n' > "$M31WT/docs/team/reports/ZZZ-dev.md"
m31 $TEAM digest >"$TMP/m31-wt-unknown.log" 2>&1 || bad "M31-WT：未知名记录时 digest 失败"
assert_eq "M31-WT：查不到名字的记录退回裸路径（不带编出来的名字括号）" \
  "$(grep -c '^    · dev: docs/team/reports/ZZZ-dev.md$' "$TMP/m31-wt-unknown.log")" "1"
rm -f "$M31WT/docs/team/reports/ZZZ-dev.md"
# 数据面翻转：把工作树记录提交进它的分支 → 警告消失（盯的是那份工作树的字节状态）
( cd "$M31WT" && git add -A && git commit -qm "docs(team): M31-WT fixture records" ) >/dev/null 2>&1
m31 $TEAM digest >"$TMP/m31-wt-committed.log" 2>&1 || bad "M31-WT：提交后 digest 失败"
assert_not "$TMP/m31-wt-committed.log" "记录未入账" "M31-WT 翻转：记录进了工作树分支 → 警告消失"
( cd "$M31WT" && git reset -q --mixed HEAD~1 ) >/dev/null 2>&1
m31 $TEAM digest >"$TMP/m31-wt-back.log" 2>&1 || bad "M31-WT：反翻转 digest 失败"
assert_has "$TMP/m31-wt-back.log" "dev: $M31_WREV" "M31-WT 反翻转：记录退回未入账 → 警告回来（双向）"
# 实现面翻转（scratch 树）：把工作树腿摘掉 → 同一份夹具上 `dev: ` 行一条不剩，而主检出记录照旧点名。
# 这条钉住本段的红线就是「工作树腿」这块代码（不是空断言），也证明 mutant 不是整体坏掉。
if command -v python3 >/dev/null 2>&1; then
  M31_MUT="$TMP/m31-mut-skill"; rm -rf "$M31_MUT"; mkdir -p "$M31_MUT"
  cp -a "$SKILL_DIR/scripts" "$SKILL_DIR/templates" "$SKILL_DIR/references" "$SKILL_DIR/SKILL.md" "$M31_MUT/" >/dev/null 2>&1
  python3 - "$SKILL_DIR/scripts/lib/cmd-status.sh" "$M31_MUT/scripts/lib/cmd-status.sh" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
old = 'for dir in "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/; do'
assert s.count(old) == 1, 'worktree loop not found exactly once'
open(dst, 'w', encoding='utf-8').write(s.replace(old, 'for dir in ; do', 1))
PY
  if [ -f "$M31_MUT/scripts/lib/cmd-status.sh" ] && ! cmp -s "$SKILL_DIR/scripts/lib/cmd-status.sh" "$M31_MUT/scripts/lib/cmd-status.sh"; then
    ok "M31-WT 突变夹具：worktree 循环已摘除（mutant 生成，与原件不同）"
  else
    bad "M31-WT 突变夹具：注入没打中（mutant 与原件相同或不存在）"
  fi
  printf '# T9main · 主检出记录（突变对照）\n' > "$M31R/docs/team/reviews/T9main.md"
  ( cd "$M31R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash "$M31_MUT/scripts/team" digest ) >"$TMP/m31-wt-mut.log" 2>&1
  assert_has "$TMP/m31-wt-mut.log" "docs/team/reviews/T9main.md" "M31-WT 突变：主检出记录照旧点名（mutant 只摘了工作树腿）"
  assert_eq "M31-WT 突变：工作树腿摘掉后 `dev: ` 行一条不剩（本段的红线就在这条腿上）" \
    "$(grep -c '^    · dev: ' "$TMP/m31-wt-mut.log")" "0"
  rm -f "$M31R/docs/team/reviews/T9main.md"
else
  bad "M31-WT 突变夹具：没有 python3（无法生成 mutant）"
fi

# ---------------------------------------------------------------- 8. 从 worktree 里也能用
section "8 · 从 agent worktree 调用 CLI"
( cd "$REPO/.worktrees/dev" && $TEAM roster >"$TMP/roster-wt.log" 2>&1 ) && ok "worktree 内 roster 退出码 0" || bad "worktree 内 roster 失败"
assert_has "$TMP/roster-wt.log" "dev" "roster 列出 dev"

# ---------------------------------------------------------------- 9. agent 干活（模拟）
section "9 · agent 提交 + 报告"
( cd "$REPO/.worktrees/dev" \
  && echo "feature" > feature.txt \
  && mkdir -p docs/team/reports \
  && printf '%s\n' \
       '# T1.1 · Smoke task' \
       'agent: dev   状态: DONE' \
       '' \
       '## 交付物' \
       '- feature.txt' \
       '' \
       '## 验证证据' \
       '```' \
       '$ true' \
       '```' \
       '' \
       '## 翻转证据（control experiment）' \
       '- 破坏实验：把实现改坏 → 守门测试退出码 1（red）' \
       '- 恢复实现：守门测试退出码 0，全部通过（green）' \
       '- 独立验证包（不复用被测夹具）：docs/team/reports/T1.1/verify.sh' \
       '```' \
       '$ bash docs/team/reports/T1.1/verify.sh' \
       '```' \
       > docs/team/reports/T1.1-dev.md \
  && mkdir -p docs/team/reports/T1.1 \
  && printf '#!/usr/bin/env bash\necho "flip package"\n' > docs/team/reports/T1.1/verify.sh \
  && for i in $(seq 1 300); do printf 'padding line %s\n' "$i"; done >> docs/team/reports/T1.1-dev.md \
  && git add -A && git commit -qm "feat(T1.1): add feature" ) >/dev/null 2>&1 \
  && ok "worktree 内提交成功" || bad "worktree 内提交失败"
assert_eq "分支有 1 个提交" "$(git -C "$REPO/.worktrees/dev" rev-list --count main..HEAD)" "1"

# ---------------------------------------------------------------- 10. review
section "10 · review（独立 worktree + 门禁）"
REV_WT="$TMP/review-checkout"
git -C "$REPO" worktree add --detach "$REV_WT" "$T1_BRANCH" >/dev/null 2>&1 || true
$TEAM review T1.1 --dir "$REV_WT" >"$TMP/review.log" 2>&1 && ok "review 门禁 PASS 退出码 0" || { bad "review 失败"; cat "$TMP/review.log"; }
if $TEAM review T1.1 >"$TMP/review-nodir.log" 2>&1; then bad "review 缺 --dir 应报错"; else ok "review 缺 --dir 明确报错（skill 不碰 git）"; fi
assert_has "$TMP/review-nodir.log" "PM 自己准备独立 checkout" "报错里给出 git 命令"
assert_file "$REPO/docs/team/reviews/T1.1.md" "写复验记录"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **PASS**" "复验判定 PASS"
assert_not "$REPO/docs/team/reviews/T1.1.md" "team merge" "复验清单不再教已删命令（改为 git 步骤）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "feature.txt" "复验记录含变更文件"
assert_has "$REPO/docs/team/reviews/T1.1.md" "agent 报告原文" "复验记录摘录了 agent 报告（不需向主工作树拷文件）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "状态: DONE" "摘录的是报告内容本体"
assert_dir "$REV_WT" "复验用 PM 提供的独立 checkout"
assert_eq "复验不会把主工作树弄脏（仅允许 docs/team、.pi/team 下的变动）" \
  "$(git -C "$REPO" status --porcelain | grep -vE '^(\?\?| ?M|M |MM|A | ?D) (\.pi/team/|docs/team/)' | grep -c . || true)" "0"

# 判定可信度（V1.1 实测的误判面）：拿错 checkout 不许给 PASS
WRONG_WT="$TMP/review-wrong"
git -C "$REPO" worktree add --detach "$WRONG_WT" "$PROTECTED" >/dev/null 2>&1 || true
if $TEAM review T1.1 --dir "$WRONG_WT" >"$TMP/review-wrong.log" 2>&1; then
  bad "拿 main 的 checkout 复验竟然 PASS（会验错东西还盖章）"
else
  ok "checkout 与任务分支不一致 → 拒绝复验"
fi
assert_has "$TMP/review-wrong.log" "不一致" "拒绝时说明是 checkout 与分支不一致"
assert_has "$TMP/review-wrong.log" "worktree add --detach" "给出重新准备 checkout 的命令"
# 子目录不算 checkout（git 对子目录也会说 is-inside-work-tree）
mkdir -p "$REV_WT/sub"; if $TEAM review T1.1 --dir "$REV_WT/sub" >"$TMP/review-sub.log" 2>&1; then
  bad "子目录竟然被当成 checkout"
else
  ok "子目录被拒（必须是 checkout 根目录）"
fi
assert_has "$TMP/review-sub.log" "根目录" "说明了必须传根目录"

# 强复验判定：长报告（300+ 行、证据在结尾）必须被结构化认出来
# （F13/F14：不靠关键词蒙；英文-first 写法也不能漏；记录要能解释自己）
$TEAM review T1.1 --dir "$REV_WT" --strong >"$TMP/review-strong.log" 2>&1 || true
assert_has "$REPO/docs/team/reviews/T1.1.md" "| **判定** | **满足强复验** |" "长报告里的翻转/独立包证据被结构化识别"
assert_match "$REPO/docs/team/reviews/T1.1.md" '\| 翻转结果 red（失败侧） \| 有 \|' "强复验清单逐条列出 red 侧证据"
assert_match "$REPO/docs/team/reviews/T1.1.md" '\| 翻转结果 green（通过侧） \| 有 \|' "强复验清单逐条列出 green 侧证据"
assert_match "$REPO/docs/team/reviews/T1.1.md" 'checkout 里存在（文件：docs/team/reports/T1\.1/verify\.sh）' "强复验清单检查了包路径真的在 checkout 里"

# 脏 checkout 也不许盖章（fixture PM 的实测 finding：只钉 HEAD 身份、不钉内容）
printf 'dirty\n' >> "$REV_WT/feature.txt"
if $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-dirty.log" 2>&1; then
  bad "脏 checkout 竟然还能盖章（复验证据不可复现）"
else
  ok "脏 checkout 被拒（复验必须干净）"
fi
assert_has "$TMP/review-dirty.log" "未提交" "拒绝时说明是「未提交改动」"
assert_has "$TMP/review-dirty.log" "TEAM_REVIEW_ALLOW_DIRTY" "给了显式覆盖开关"
git -C "$REV_WT" checkout -- . >/dev/null 2>&1 || true

# 门禁失败路径
sed -i 's/^TEAM_GATES="true"/TEAM_GATES="false"/' "$REPO/.pi/team/config.sh"
if $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-fail.log" 2>&1; then bad "门禁失败时 review 应返回非 0"; else ok "门禁失败时 review 返回非 0"; fi
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **FAIL**" "复验记录标记 FAIL"
sed -i 's/^TEAM_GATES="false"/TEAM_GATES="true"/' "$REPO/.pi/team/config.sh"
$TEAM review T1.1 --dir "$REV_WT" >/dev/null 2>&1
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **PASS**" "恢复门禁后复验 PASS"

# ---------------------------------------------------------------- 10b. 复验证据完整性（M6.2 / V4.0 F7–F14 · F3）
section "10b · 复验证据完整性（记录必须描述真的验过什么）"

# 备份一份正常的 PASS 记录；下面的破坏性用例跑完再重建现场
cp "$REPO/docs/team/reviews/T1.1.md" "$TMP/record-ok.md"
rec_reset() { rm -f "$REPO/docs/team/reviews/T1.1.md" "$REPO/docs/team/reviews/T1.1-verify.log"; }
rev_refresh() { git -C "$REPO" worktree remove --force "$REV_WT" >/dev/null 2>&1; git -C "$REPO" worktree add -q --detach "$REV_WT" "$T1_BRANCH" >/dev/null 2>&1; }
rec_reset   # 先清掉 10 节留下的记录，后面的断言才是在看“本次到底写没写”

# F7：--branch 解析不到 → 默认拒绝（不许跳过 checkout 一致性守卫、把记录盖到不存在的 revision 上）
if $TEAM review T1.1 --dir "$REV_WT" --branch no-such-branch >"$TMP/review-f7.log" 2>&1; then
  bad "F7 --branch 解析不到时 review 仍 PASS（守卫被跳过）"
else
  ok "F7 --branch 解析不到 → 默认拒绝（fail closed）"
fi
assert_has "$TMP/review-f7.log" "分支解析不到" "F7 拒绝理由写明是分支解析不到"
assert_has "$TMP/review-f7.log" "期望：" "F7 说明期望解析什么 ref"
assert_has "$TMP/review-f7.log" "$T1_BRANCH" "F7 列出找到的候选分支"
assert_has "$TMP/review-f7.log" "allow-unresolved-branch" "F7 给出显式覆盖开关"
assert_not_file "$REPO/docs/team/reviews/T1.1.md" "F7 被拒时不写复验记录"
$TEAM review T1.1 --dir "$REV_WT" --branch no-such-branch --allow-unresolved-branch >"$TMP/review-f7b.log" 2>&1 \
  && ok "F7 --allow-unresolved-branch 是唯一的覆盖路径" || bad "F7 显式覆盖没生效"
assert_has "$REPO/docs/team/reviews/T1.1.md" "分支未解析" "F7 覆盖时记录里标注了分支未解析"
rec_reset

# F8：TEAM_REVIEW_ALLOW_DIRTY=1 的覆盖必须写进记录，不许再说“干净”
printf 'dirty-line\n' >> "$REV_WT/feature.txt"
env TEAM_REVIEW_ALLOW_DIRTY=1 $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f8.log" 2>&1 \
  && ok "F8 ALLOW_DIRTY 覆盖仍可用（只走显式开关）" || bad "F8 ALLOW_DIRTY 覆盖失效"
assert_not "$TMP/review-f8.log" "干净" "F8 覆盖时 CLI 不再谎称“干净”"
assert_has "$REPO/docs/team/reviews/T1.1.md" "checkout dirty: 1 files (override TEAM_REVIEW_ALLOW_DIRTY=1)" "F8 记录写明 dirty N files（override）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "feature.txt" "F8 记录列出脏文件（路径头部）"
git -C "$REV_WT" checkout -q -- feature.txt
rec_reset

# F9：被 .gitignore 忽略的产物（status --porcelain 看不见）默认拒绝；覆盖时记进记录
mkdir -p "$REV_WT/.pi/team/state" && printf 'probe\n' > "$REV_WT/.pi/team/state/probe.txt"
assert_eq "F9 现场：ignored 产物对 status --porcelain 不可见" "$(git -C "$REV_WT" status --porcelain | grep -c . || true)" "0"
if env TEAM_GATES='test -f .pi/team/state/probe.txt' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f9.log" 2>&1; then
  bad "F9 门禁读到 ignored 产物（不在提交里）时仍然 PASS"
else
  ok "F9 ignored 产物默认拒绝（不再静默信任 status --porcelain）"
fi
assert_has "$TMP/review-f9.log" "忽略" "F9 拒绝时说明是 ignored 产物"
assert_has "$TMP/review-f9.log" "TEAM_REVIEW_ALLOW_IGNORED" "F9 给出显式覆盖开关"
env TEAM_REVIEW_ALLOW_IGNORED=1 TEAM_GATES='test -f .pi/team/state/probe.txt' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f9b.log" 2>&1 \
  && ok "F9 ALLOW_IGNORED 覆盖生效" || bad "F9 覆盖没生效"
assert_has "$REPO/docs/team/reviews/T1.1.md" "ignored artifacts: 1" "F9 记录写明 ignored N"
assert_has "$REPO/docs/team/reviews/T1.1.md" "probe.txt" "F9 记录列出被忽略的路径"
rm -rf "$REV_WT/.pi/team/state"
rec_reset

# F10：真挂死 → TIMEOUT（只认 timeout 包装器退出码 124/137，不 grep 门禁日志）
env TEAM_REVIEW_TIMEOUT=1 TEAM_GATES='echo start; sleep 30' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f10.log" 2>&1 \
  && bad "F10 挂死的门禁不该 PASS" || ok "F10 挂死的门禁被硬超时终止且返回非 0"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **TIMEOUT**" "F10 记录判定 TIMEOUT（与 FAIL 区分）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "硬超时终止" "F10 记录里有“被硬超时终止”那句"
rec_reset

# F11：门禁只是打印 'timeout' 字样 + 普通失败 → FAIL（不许因为日志字样记成 TIMEOUT）
env TEAM_GATES='echo "using timeout 5 for the probe"; exit 3' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f11.log" 2>&1 \
  && bad "F11 失败门禁不该 PASS" || ok "F11 普通失败返回非 0"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **FAIL**" "F11 打印 timeout 字样的普通失败记为 FAIL"
assert_not "$REPO/docs/team/reviews/T1.1.md" "判定: **TIMEOUT**" "F11 不因日志字样被误判成 TIMEOUT"
rec_reset

# F15（M6.5 finding 2）：门禁**自己** exit 124 ≠ 超时。旧实现只看包装器退出码，把这条记成
# 「被 deadline 杀死」（实测：同一次 smoke 一次记 TIMEOUT、一次记 FAIL）。
env TEAM_REVIEW_TIMEOUT=60 TEAM_GATES='echo "self-inflicted 124"; exit 124' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f15.log" 2>&1 \
  && bad "F15 门禁自己 exit 124 不该 PASS" || ok "F15 门禁自己 exit 124 返回非 0"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **FAIL**" "F15 门禁自己的 124 → FAIL（不是 TIMEOUT）"
assert_not "$REPO/docs/team/reviews/T1.1.md" "判定: **TIMEOUT**" "F15 不把门禁自己的 124 记成「被 deadline 杀死」"
assert_has "$REPO/docs/team/reviews/T1.1.md" "实际用时" "F15 记录写明实际用时（判定必须能解释自己）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "不是被 deadline 杀死的" "F15 记录解释了为什么不是超时"
rec_reset

# F16（M6.5 finding 2）：被信号终止 ≠ 超时 —— 信号名要写进记录，不拿「超时」顶替「被杀」
env TEAM_REVIEW_TIMEOUT=60 TEAM_GATES='kill -TERM $$; sleep 5' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f16.log" 2>&1 \
  && bad "F16 被 SIGTERM 终止的门禁不该 PASS" || ok "F16 被信号终止返回非 0"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **FAIL**" "F16 被信号终止 → FAIL（不是 TIMEOUT）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "gate killed: SIGTERM" "F16 抬头写明是哪个信号杀的"
assert_not "$REPO/docs/team/reviews/T1.1.md" "判定: **TIMEOUT**" "F16 不把「被杀」记成「超时」"
rec_reset

# F17（M6.5 finding 2）：真超时仍然 TIMEOUT，且记录写明实际用时（与 F10 配对：一条钉 deadline，一条钉用时）
env TEAM_REVIEW_TIMEOUT=2 TEAM_GATES='echo start; sleep 30' $TEAM review T1.1 --dir "$REV_WT" >"$TMP/review-f17.log" 2>&1 \
  && bad "F17 真挂死的门禁不该 PASS" || ok "F17 睡过 deadline 的门禁被硬超时终止"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **TIMEOUT**" "F17 用时贴住 deadline → TIMEOUT"
assert_has "$REPO/docs/team/reviews/T1.1.md" "实际用时" "F17 记录写明实际用时"
rec_reset

# F12：--no-gates 不是证据：digest 继续列为待复验（带 gates: none），status 打印判定
$TEAM review T1.1 --dir "$REV_WT" --no-gates >"$TMP/review-f12.log" 2>&1 && ok "F12 --no-gates 正常写记录" || bad "F12 --no-gates 失败"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **SKIPPED** · gates: none" "F12 记录抬头标注 gates: none"
$TEAM digest >"$TMP/digest-f12.log" 2>&1 || true
assert_has "$TMP/digest-f12.log" "T1.1-dev [gates: none]" "F12 digest 继续列为待复验并标 gates: none"
$TEAM status T1.1 >"$TMP/status-f12.log" 2>&1 || true
assert_has "$TMP/status-f12.log" "判定: SKIPPED · HEAD " "F12 status 在记录路径旁打印判定"

# F13：只“提到”关键词的报告不算证据（旧实现会判成“满足强复验”）
{ printf '# T1.1 · keyword-only\n\n'
  printf 'There is no 翻转 evidence in this report and no 独立验证包: those two words appear only as a sentence\n'
  printf 'about what is missing. Nothing was broken on purpose.\n'; } > "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev.md"
git -C "$REPO/.worktrees/dev" add -A && git -C "$REPO/.worktrees/dev" commit -qm "docs(T1.1): report that only mentions the keywords"
rev_refresh; rec_reset
$TEAM review T1.1 --dir "$REV_WT" --strong >"$TMP/review-f13.log" 2>&1 || true
assert_has "$REPO/docs/team/reviews/T1.1.md" "不满足（不阻塞合并" "F13 只提关键词的报告 → 不满足强复验"
assert_has "$REPO/docs/team/reviews/T1.1.md" "翻转小节 | 缺" "F13 记录说明缺的是「翻转小节」"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定规则" "F13 记录解释判定规则（看了什么）"
assert_has "$TMP/review-f13.log" "强复验证据不完整" "F13 缺证据时 CLI 明确告警"

# F14：真正的英文写法（flip 小节 + red→green + 独立包路径）必须被认出来
{ printf '# T1.1 · genuine english report\n\n'
  printf '## Flip evidence\n\n'
  printf 'Red before -> green after: I broke the implementation on purpose and the guard test failed, then I restored it.\n\n'
  printf 'The reproduction lives in an independent verification package (docs/team/reports/T1.1/pkg) written from\n'
  printf 'scratch; it does not reuse the implementation fixtures. Red/green logs are in the same directory.\n'; } > "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev.md"
git -C "$REPO/.worktrees/dev" add -A && git -C "$REPO/.worktrees/dev" commit -qm "docs(T1.1): genuine english flip evidence"
rev_refresh; rec_reset
$TEAM review T1.1 --dir "$REV_WT" --strong >"$TMP/review-f14.log" 2>&1 || true
assert_has "$REPO/docs/team/reviews/T1.1.md" "| **判定** | **满足强复验** |" "F14 English-first 的翻转+独立包证据被认出"
assert_has "$REPO/docs/team/reviews/T1.1.md" "Flip evidence" "F14 记录给出命中的小节标题"
assert_has "$REPO/docs/team/reviews/T1.1.md" "checkout 里没有这个路径" "F14 老实记下包路径未随分支提交（提示项，不阻塞）"

# F14b（PM 退回的复现）：报告措辞直接取自我们自己的模板 —— 检查器不能只认自己的正则，
# 否则「检查器 ↔ 模板」会漂移（模板改写后真报告又被判“缺证据”）
TMPL_FLIP_HEAD="$(grep -m1 -E '^#{2,3}[[:space:]].*[Ff]lip' "$SKILL_DIR/templates/report.md.tmpl" | sed 's/[[:space:]]*$//')"
[ -n "$TMPL_FLIP_HEAD" ] || TMPL_FLIP_HEAD='## Flip evidence'
{ printf '# T1.1 · template shaped report\n\n'
  printf '%s\n\n' "$TMPL_FLIP_HEAD"
  printf '```\n$ bash docs/team/reports/T1.1-dev/pkg/run.sh --flip\n'
  printf 'before the fix: guard test failed (red)\n'
  printf 'after the fix:  guard test passed (green)\n```\n\n'
  printf 'The reproduction lives in docs/team/reports/T1.1-dev/pkg (independent package, does not reuse the implementation fixtures).\n'; } > "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev.md"
mkdir -p "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev/pkg"
printf '#!/usr/bin/env bash\necho "red before"; echo "green after"\n' > "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev/pkg/run.sh"
git -C "$REPO/.worktrees/dev" add -A && git -C "$REPO/.worktrees/dev" commit -qm "docs(T1.1): report shaped like our template"
rev_refresh; rec_reset
$TEAM review T1.1 --dir "$REV_WT" --strong >"$TMP/review-f14b.log" 2>&1 || true
assert_has "$REPO/docs/team/reviews/T1.1.md" "| **判定** | **满足强复验** |" "F14b 模板措辞的真报告 → 满足（检查器与模板对齐）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "$TMPL_FLIP_HEAD" "F14b 记录引用的就是模板里的真实小节标题"
assert_match "$REPO/docs/team/reviews/T1.1.md" 'checkout 里存在（(文件|目录)：docs/team/reports/T1.1-dev/pkg' "F14b 真实存在的 pkg 路径被认出"

# F14c（PM 复现报的形状）：Red before / Green after + `pkg/run.sh`（相对报告目录解析）
{ printf '# T1.1 · PM shaped report\n\n'
  printf '## Flip evidence\nRed before: guard test failed (see pkg/flip red log)\nGreen after: guard test passes\n\n'
  printf '## Independent verification package\npkg/run.sh (written for this task, does not reuse the implementation fixtures)\n'; } > "$REPO/.worktrees/dev/docs/team/reports/T1.1-dev.md"
git -C "$REPO/.worktrees/dev" add -A && git -C "$REPO/.worktrees/dev" commit -qm "docs(T1.1): PM shaped report"
rev_refresh; rec_reset
$TEAM review T1.1 --dir "$REV_WT" --strong >"$TMP/review-f14c.log" 2>&1 || true
assert_has "$REPO/docs/team/reviews/T1.1.md" "| **判定** | **满足强复验** |" "F14c PM 复现的形状（Red before/Green after + pkg/run.sh）→ 满足"
assert_has "$REPO/docs/team/reviews/T1.1.md" "独立性声明（提示项） | 有" "F14c 独立性声明被记录（提示项）"
assert_not "$TMP/review-f14c.log" "强复验证据不完整" "F14c 满足时不误报“证据不完整”（SIGPIPE 假告警）"

# F14d：报告不在被验 checkout 里（只在主工作树/agent worktree）——只看 checkout 会把真报告判成“缺证据”
RF="$TMP/review-fallback-repo"; mkdir -p "$RF"
( cd "$RF" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo x > README.md && git add -A && git commit -qm init \
  && bash "$SKILL_DIR/scripts/team" init --session "teamsmith-smoke-fb-$$" --agents dev --gates true >/dev/null 2>&1 ) \
  && ok "F14d 现场：第二个临时项目就绪" || bad "F14d 现场初始化失败"
git -C "$RF" add -A && git -C "$RF" commit -qm "chore: teamsmith init"
( cd "$RF" && bash "$SKILL_DIR/scripts/team" task T7.7 --title "fallback" --agent dev >/dev/null 2>&1 )
mkdir -p "$RF/docs/team/reports/T7.7-dev/pkg"
{ printf '# T7.7 · fallback report\n\n'
  printf '## Flip evidence\nRed before: guard test failed (see pkg/flip)\nGreen after: guard test passed\n\n'
  printf '## Independent verification package\npkg/run.sh (written for this task, does not reuse the implementation fixtures)\n'; } > "$RF/docs/team/reports/T7.7-dev.md"
printf '#!/usr/bin/env bash\necho red; echo green\n' > "$RF/docs/team/reports/T7.7-dev/pkg/run.sh"
git -C "$RF" worktree add -q -b task/T7.7-smoke "$RF/.worktrees/dev" main
printf 'code\n' > "$RF/.worktrees/dev/code.txt"
git -C "$RF/.worktrees/dev" add -A && git -C "$RF/.worktrees/dev" commit -qm "feat(T7.7): code (no report on the branch)"
git -C "$RF" worktree add -q --detach "$TMP/review-fb-checkout" task/T7.7-smoke
( cd "$RF" && bash "$SKILL_DIR/scripts/team" review T7.7 --dir "$TMP/review-fb-checkout" --strong --no-gates ) >"$TMP/review-f14d.log" 2>&1 || true
assert_has "$RF/docs/team/reviews/T7.7.md" "| **判定** | **满足强复验** |" "F14d 报告不在 checkout 里时不再误判“缺证据”"
assert_has "$RF/docs/team/reviews/T7.7.md" "不在 checkout 里" "F14d 记录写明采用的是 checkout 外的那份报告"

# F3：记录只对它验过的 revision 负责 —— 分支再动一格，待复验信号必须回来
git -C "$REPO/.worktrees/dev" commit -q --allow-empty -m "feat(T1.1): another commit after verification"
$TEAM digest >"$TMP/digest-f3.log" 2>&1 || true
assert_match "$TMP/digest-f3.log" 'T1\.1-dev \[stale: verified [0-9a-f]+, branch now [0-9a-f]+\]' "F3 分支又动了 → digest 重新列为待复验（带 stale 标记）"
$TEAM status T1.1 >"$TMP/status-f3.log" 2>&1 || true
assert_match "$TMP/status-f3.log" 'stale: verified [0-9a-f]+, branch now [0-9a-f]+' "F3 status 也标出记录已过期"
assert_eq "F3 分支已被合并删除（解析不到）→ 不算过期（否则合并后任务永远待办）" \
  "$(TEAM_ROOT=$REPO bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; . "'$SKILL_DIR'/scripts/lib/cmd-review.sh"; team_load_config; team_resolve_branch() { printf "no-such-branch\\n"; }; team_review_branch_tip T1.1')" ""

# 10b 收尾：重建一条正常的 PASS 记录，后续小节的现场与改造前一致
rev_refresh; rec_reset
$TEAM review T1.1 --dir "$REV_WT" >/dev/null 2>&1
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **PASS**" "10b 收尾：恢复干净 checkout 上的 PASS 记录"
$TEAM digest >"$TMP/digest-10b-end.log" 2>&1 || true
assert_not "$TMP/digest-10b-end.log" "T1.1-dev" "10b 收尾：记录有效后不再列为待复验"

# ---------------------------------------------------------------- 10c. M25 复验基建（环境不泄漏 + 后台进程组/tty 不打滑）
section "10c · M25 复验基建：门禁不继承 TEAM_REVIEW_* + 后台进程组里读 tty 的病"

# ① 环境泄漏（现场：TEAM_REVIEW_ANY_DIR=1 把「拿错 checkout 必须拒绝」的用例放行成绿）
#    判定点是**门禁子进程**看到的环境，所以夹具门禁直接把自己的环境打出来。
M25_GATE_ENV="$TMP/m25-gate-env.sh"
cat > "$M25_GATE_ENV" <<'EOS'
#!/usr/bin/env bash
printf 'leak_count=%s\n' "$(env | sed -n 's/^\(TEAM_REVIEW_[A-Za-z0-9_]*\)=.*$/\1/p' | wc -l | tr -d ' ')"
printf 'leak_names=%s\n' "$(env | sed -n 's/^\(TEAM_REVIEW_[A-Za-z0-9_]*\)=.*$/\1/p' | sort | tr '\n' ',')"
printf 'any_dir=%s allow_dirty=%s timeout=%s\n' \
  "${TEAM_REVIEW_ANY_DIR:-unset}" "${TEAM_REVIEW_ALLOW_DIRTY:-unset}" "${TEAM_REVIEW_TIMEOUT:-unset}"
printf 'stdin=%s\n' "$(readlink /proc/$$/fd/0 2>/dev/null || echo '?')"
exit 0
EOS
env TEAM_REVIEW_ANY_DIR=1 TEAM_REVIEW_ALLOW_DIRTY=1 TEAM_REVIEW_IGNORED_X=1 TEAM_REVIEW_TIMEOUT=77 \
  TEAM_GATES="bash $M25_GATE_ENV" $TEAM review T1.1 --dir "$REV_WT" >"$TMP/m25-leak.log" 2>&1 \
  && ok "M25-① 夹具门禁跑完（review 命令本身正常）" || { bad "M25-① 夹具门禁没跑起来"; cat "$TMP/m25-leak.log"; }
M25_GATE_LOG="$REPO/docs/team/reviews/T1.1-verify.log"
assert_file "$M25_GATE_LOG" "M25-① 门禁输出写进复验日志（夹具能看到门禁视角）"
assert_has "$M25_GATE_LOG" "leak_count=0" "M25-① 门禁子进程里一个 TEAM_REVIEW_* 都没有（泄漏已堵）"
assert_has "$M25_GATE_LOG" "any_dir=unset allow_dirty=unset timeout=unset" "M25-① 覆盖项逐个消失（不是只清 ANY_DIR）"
assert_not "$M25_GATE_LOG" "TEAM_REVIEW_" "M25-① 门禁日志里也不出现任何 TEAM_REVIEW_ 变量名"
assert_has "$TMP/m25-leak.log" "硬超时 77s" "M25-① 判定力不降：review 自己照旧读 TEAM_REVIEW_TIMEOUT（77s 生效）"
assert_has "$M25_GATE_LOG" "stdin=/dev/null" "M25-② 门禁的 stdin 是 /dev/null（不接调用者的 tty）"

# ② 后台进程组 + tty = 读 stdin 的子进程被 SIGTTIN **停住**（STAT=TN、0% CPU，看着像挂死）。
#    实测根因（见报告）：smoke 里的登录 shell 探针、以及登录 profile 里的 host-spawn 都会碰 tty。
#    这里用「门禁读一行 stdin」把机制钉住：门禁必须在后台进程组里也能跑完。
if [ "$FAST" = "1" ]; then
  fast_skip "10c-②·后台进程组里的门禁（M25）" "要真 tmux pane（私有 socket）造出「后台进程组 + tty」"
elif [ "$HAVE_TMUX" != "1" ]; then
  printf '  (跳过 10c-②：本机没有 tmux)\n'
else
  M25_SOCK="$TMP/m25-tty-sock"; mkdir -p "$M25_SOCK"
  m25_tm() { env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$M25_SOCK" tmux "$@"; }
  M25_SESS="teamsmith-m25-$$"
  m25_tm new-session -d -s "$M25_SESS" -x 100 -y 24 -c "$REPO" 2>/dev/null || true
  M25_PANE="$(m25_tm list-panes -t "$M25_SESS" -F '#{pane_id}' 2>/dev/null | head -1)"
  if [ -z "$M25_PANE" ]; then
    bad "M25-② 建不出私有 socket 的 pane（跳过会掩盖问题，所以按失败算）"
  else
    cat > "$TMP/m25-gate-tty.sh" <<'EOS'
#!/usr/bin/env bash
printf 'gate_stdin=%s\n' "$(readlink /proc/$$/fd/0 2>/dev/null || echo '?')"
IFS= read -r line || true          # 后台进程组里读 tty = SIGTTIN 停住；stdin=/dev/null 时立刻 EOF
printf 'gate_read_done=yes\n'
EOS
    # 夹具有效性（不许假绿）：裸 read 在后台进程组 + tty 下**必须**被停住
    cat > "$TMP/m25-control-read.sh" <<'EOS'
#!/usr/bin/env bash
IFS= read -r line || true
printf 'control_done=yes\n'
EOS
    # 另一条 ID（T2.2）→ 独占一份复验记录/日志，不去踩 T1.1 那份
    ( cd "$REPO" && $TEAM task T2.2 --title "M25 后台进程组" --agent dev ) >/dev/null 2>&1 || true
    M25_GATE_LOG="$REPO/docs/team/reviews/T2.2-verify.log"
    # 关键：命令**带 & 敲进交互式 shell** —— 只有交互式 shell 的 & 才给后台作业新建进程组。
    # （脚本内部的 & 不建进程组，读 tty 不会被停住 —— 那样这里就会假绿。）
    # 对照组的进程现场：pid + STAT（没起来 = 空）。**不许**用 `ps -eo args | grep -q "<脚本名>"`：
    # grep 自己的命令行里就带那个字符串（20/20 次实测自匹配），循环第一次就 break，等于没等。
    # 用 awk 匹配整行（`$0`）+ 模式里带 `[.]`：awk 自己的 args 里是 `m25-control-read[.]sh`，
    # 字面量不是 `m25-control-read.sh`，所以不会自匹配（pkg 的 10 节有 20/20 对照）。
    # 注意不能只看 `$3`（args 的第一词）：`bash <script>` 这个进程的 `$3` 是 `bash`，不是脚本名
    # （M35 实测：写成 `$3 ~ /m25-control-read[.]sh/` 永远匹配不到 → 30s 超时假红）。
    m25_ctl_stat() { ps -eo pid=,stat=,args= 2>/dev/null | awk '$0 ~ /m25-control-read[.]sh/ {print $1, $2; exit}'; }
    m25_tm send-keys -t "$M25_PANE" "cd $REPO && bash $TMP/m25-control-read.sh > $TMP/m25-control.out 2>&1 &" \
      && m25_tm send-keys -t "$M25_PANE" Enter
    # 夹具有效性（不许假绿）：轮询**实际条件** —— 对照组真的出现在 ps 里、且 STAT 是 T（被 SIGTTIN 停住）。
    # 事故（M34 复验 17:58 的假红）：旧写法是自匹配的 ps|grep（第一次就 break）+ 单次 assert_file，
    # 负载高时 pane 里的交互 shell 还没 exec 出脚本 → 「m25-control.out 找不到」红，而几秒后文件其实出现了；
    # 同一处自匹配还让下一行「对照组没有被停住」**假绿**（ps 命中 grep 自己，文件不存在反而满足条件）。
    M25_CWAIT=0; M25_CSTATE=""; M25_CDIAG="ps 里 30s 都没看到对照组（pane 里的 shell 没起来？）"
    while [ "$M25_CWAIT" -lt 60 ]; do
      M25_CSTATE="$(m25_ctl_stat)"
      if [ -n "$M25_CSTATE" ]; then
        M25_CDIAG="ps 里最后是 [$M25_CSTATE]"
        case "$M25_CSTATE" in *" T"*) M25_CDIAG=""; break ;; esac
      fi
      sleep 0.5; M25_CWAIT=$((M25_CWAIT + 1))
    done
    assert_file "$TMP/m25-control.out" "M25-② 夹具有效性：对照组脚本起来了"
    if [ -z "$M25_CDIAG" ]; then
      ok "M25-② 夹具有效性：裸 read 在后台进程组 + tty 下确实被停住（这就是「挂死」的形状）"
    else
      grep -q "control_done=yes" "$TMP/m25-control.out" 2>/dev/null \
        && M25_CDIAG="对照组把 read 跑完了（control_done=yes）——本环境读 tty 没被停住"
      bad "M25-② 夹具有效性：对照组没有被停住（$M25_CDIAG）—— 本环境测不出这个机制，断言会假绿"
    fi
    # 对照组已确认停住，现在才把门禁敲进**同一个** pane（原来靠 sleep 1.5 赌它起没起来）
    m25_tm send-keys -t "$M25_PANE" "cd $REPO && env TEAM_REVIEW_ANY_DIR=1 TEAM_REVIEW_ALLOW_DIRTY=1 TEAM_REVIEW_ALLOW_IGNORED=1 TEAM_GATES='bash $TMP/m25-gate-tty.sh' $TEAM review T2.2 --dir $REV_WT --branch $T1_BRANCH > $TMP/m25-tty-review.log 2>&1 &" \
      && m25_tm send-keys -t "$M25_PANE" Enter
    # 等门禁把最后一行写出来（最多 60s；被停住时它永远写不出来）；高负载下给足余量
    M25_WAIT=0
    while [ "$M25_WAIT" -lt 120 ]; do
      grep -q "gate_read_done=yes" "$M25_GATE_LOG" 2>/dev/null && break
      sleep 0.5; M25_WAIT=$((M25_WAIT + 1))
    done
    if [ ! -f "$M25_GATE_LOG" ] || ! grep -q "gate_read_done=yes" "$M25_GATE_LOG" 2>/dev/null; then
      # 失败时把现场留下（smoke --keep 会保留 $TMP）：review 自己的输出 + pane 尾巴
      m25_tm capture-pane -p -t "$M25_PANE" > "$TMP/m25-tty-pane.log" 2>/dev/null || true
      printf '  review 自己说了什么（%s）：\n' "$TMP/m25-tty-review.log"
      sed 's/^/    | /' "$TMP/m25-tty-review.log" 2>/dev/null | head -8
      printf '  pane 尾巴：\n'; tail -5 "$TMP/m25-tty-pane.log" 2>/dev/null | sed 's/^/    | /'
    fi
    # 对照组是被停住的进程：显式收掉，别留给后面小节（kill 只针对本夹具的脚本名；
    # 被 SIGTTIN 停住的进程收不到 TERM，得先 -CONT 让它跑起来）
    pkill -CONT -f "m25-control-read.sh" 2>/dev/null || true
    pkill -TERM -f "m25-control-read.sh" 2>/dev/null || true
    assert_has "$M25_GATE_LOG" "gate_read_done=yes" "M25-② 门禁在后台进程组里读到 EOF 并跑完（stdin=/dev/null，没被 SIGTTIN 停住）"
    assert_has "$M25_GATE_LOG" "gate_stdin=/dev/null" "M25-② 门禁 stdin 确实是 /dev/null"
    m25_tm kill-server 2>/dev/null || true
  fi
fi
m25_cleanup() { rm -f "$REPO/docs/team/reviews/T2.2.md" "$REPO/docs/team/reviews/T2.2-verify.log"; }
m25_cleanup

# ---------------------------------------------------------------- 11. merge / close
section "11 · 收尾（merge 已移除，close 保留）"
if $TEAM merge T1.1 >/dev/null 2>&1; then bad "merge 应已移除"; else ok "merge 已移除（PM 用 git）"; fi
$TEAM board set T1.1 done >"$TMP/board-done.log" 2>&1 && ok "有 PASS 复验记录时 done 允许" || { bad "有复验记录却被拒"; cat "$TMP/board-done.log"; }
assert_has "$TMP/board-done.log" "判定 PASS" "done 成功输出写明核对到的证据"
assert_eq "BOARD 可由 PM 直接收尾" "$(board_status T1.1)" "done"
assert_has "$REPO/docs/team/reviews/T1.1-done.md" "判定 PASS" "done 审计记下当时核对的证据"
# close：未知 id 不假装关闭；有复验记录时给出真实路径（F2）；复位命令是打印而不是执行（F5）
if $TEAM close NOSUCH >"$TMP/close-nosuch.log" 2>&1; then bad "close 未知 id 应被拒"; else ok "close 未知 id 被拒（不假装关闭）"; fi
assert_has "$TMP/close-nosuch.log" "没有可关闭的东西" "说清楚没有可关的东西"
$TEAM close T1.1 >"$TMP/close.log" 2>&1 && ok "close 退出码 0" || bad "close 失败"
assert_has "$TMP/close.log" "复验记录 docs/team/reviews/T1.1.md 保留" "close 报的是真实存在的复验记录"
assert_has "$SKILL_DIR/scripts/lib/cmd-review.sh" "TEAM_TASK_BRANCH_RESET" "close 真的读了这个配置键（F5 不再是死配置）"
assert_not "$SKILL_DIR/references/workflows.md" "goes back to" "workflows.md 不再宣称 close 自动复位"
# 没有证据的 done（close 的默认状态）也被拒；--force --reason 才允许，而且说谎要留痕
$TEAM board add T9.9 "No review yet" dev - >/dev/null 2>&1
assert_eq "T9.9 是表里的一行（下面两条 close 的前置）" "$(board_status T9.9)" "todo"
if $TEAM close T9.9 >"$TMP/close-norev.log" 2>&1; then bad "close 没有证据也应被拒"; else ok "close 没有 done 证据被拒"; fi
$TEAM close T9.9 --force --reason "smoke: 直接收尾" >"$TMP/close-t99.log" 2>&1 \
  && ok "close --force --reason 允许收尾" || { bad "close --force 失败"; cat "$TMP/close-t99.log"; }
assert_has "$TMP/close-t99.log" "没有复验记录" "close 明说没有复验记录"
assert_not "$TMP/close-t99.log" "复验记录 docs/team/reviews/T9.9.md 保留" "不宣称保留一个不存在的文件"
assert_has "$REPO/docs/team/reviews/T9.9-done.md" "FORCED" "close 的覆盖也落盘"
if [ "$FAST" = "1" ]; then
  fast_skip "11·close 后窗口" "窗口断言要有 tmux 场地（快模式不建场地）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  assert_eq "close 后窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx dev || true)" "0"
  assert_has "$TMP/close.log" "switch --detach main" "close 打印确切的复位命令"
  assert_eq "close 没替 PM 切分支（worktree 仍在任务分支上）" "$(git -C "$REPO/.worktrees/dev" rev-parse --abbrev-ref HEAD 2>/dev/null)" "$T1_BRANCH"
  # TEAM_TASK_BRANCH_RESET=0：复位提示可以关掉（配置键真的有作用）
  $TEAM dispatch dev T1.1 "$TASKFILE" >/dev/null 2>&1 || true
  TEAM_TASK_BRANCH_RESET=0 $TEAM close T1.1 >"$TMP/close-reset0.log" 2>&1 || true
  assert_not "$TMP/close-reset0.log" "switch --detach" "TEAM_TASK_BRANCH_RESET=0 时不打复位命令"
fi

section "11b · 定时巡检：有待办才叫醒 PM（默认 15 分钟）"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/pm-args.log" > "$FAKE/pi-sleep"
chmod +x "$FAKE/pi-sleep"

if [ "$FAST" = "1" ]; then
  fast_skip "11b·巡检/pulse" "要真实 tmux + 假 pi 进程（up/watch/standby/monitor，含多处 sleep）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
  PMW="$($TEAM paths | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"
  [ -n "$PMW" ] || PMW=pm
  # M9.7：这一段的 fixture 以前是「动作 + 固定 sleep + 采样一次状态」——采样撞上过渡态就假红
  # （实测：§11b3 ⑤ 的 attempts 行记成 state=unknown 而不是 state=idle；注入 1.2s 的窗口过渡
  # 1/1 次可复现，见 docs/team/reports/M9.7-dev2/）。改成有界轮询**实际条件**（状态真的变成我们要的
  # 样子），超时把「最后看到的状态」原样报出来。等待**不是**「把红等成绿」：它带 deadline，超时由
  # 调用方报红（持续回归只是晚 10s 红），超时信息里带最后看到的状态，下一次发生不必再考古。
  pm_state_now() { ( . "$SKILL_DIR/scripts/lib/common.sh"; team_load_config; team_pm_state ); }
  pm_state_until() { # <case 模式…> [最多等秒] → 0=等到了；最后状态留在 PM_STATE_LAST
    # 多个模式是「或」关系（每个模式单独做 case 匹配：模式里的 | 在变量展开后不会被当成分隔符，
    # 所以 `pm_state_until 'unknown:tmux' 'idle:*' 10` 而不是 'unknown:tmux|idle:*'）。
    local secs="${!#:-10}" i=0 ticks p
    ticks=$(( secs * 4 ))
    PM_STATE_LAST=""
    while [ "$i" -lt "$ticks" ]; do
      PM_STATE_LAST="$(pm_state_now 2>/dev/null || true)"
      for p in "${@:1:$#-1}"; do
        case "$PM_STATE_LAST" in $p) return 0 ;; esac
      done
      sleep 0.25
      i=$((i + 1))
    done
    return 1
  }
  pm_state_until_not() { # <case 模式> [最多等秒] → 0=状态不再是该模式
    local avoid="$1" secs="${2:-10}" i=0 ticks
    ticks=$(( secs * 4 ))
    PM_STATE_LAST=""
    while [ "$i" -lt "$ticks" ]; do
      PM_STATE_LAST="$(pm_state_now 2>/dev/null || true)"
      case "$PM_STATE_LAST" in $avoid) ;; *) return 0 ;; esac
      sleep 0.25
      i=$((i + 1))
    done
    return 1
  }
  wait_session_gone() { # <session> [最多等秒]
    local s="${1:-}" secs="${2:-5}" i=0 ticks
    ticks=$(( secs * 20 ))
    while [ "$i" -lt "$ticks" ]; do
      tmux has-session -t "$s" 2>/dev/null || return 0
      sleep 0.05
      i=$((i + 1))
    done
    return 1
  }
  wait_window_gone() { # <窗口名> [最多等秒]（沿用本段的 $SESSION）
    local n="${1:-}" secs="${2:-5}" i=0 ticks
    ticks=$(( secs * 20 ))
    while [ "$i" -lt "$ticks" ]; do
      tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$n" || return 0
      sleep 0.05
      i=$((i + 1))
    done
    return 1
  }

  # 制造“PM 窗口在、里面是空提示符”的现场（pi 退出后的样子），并用占位窗口保住 session
  make_pm_idle() {   # 让 PM 窗口回到**确定性**的空 shell（等 team_pm_state 真的报 idle:*，不是赌一次 sleep）
    tmux new-window -t "$SESSION" -n keep -d -c "$REPO" >/dev/null 2>&1 || true
    tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null \
      | awk -v n="$PMW" '$2==n {print $1}' \
      | while read -r wid; do [ -n "$wid" ] && tmux kill-window -t "$wid" 2>/dev/null || true; done
    # 窗口里跑**不带 rc 的 bash**（M35）——不是任何 profile 跑完后的登录 zsh。
    # 实测（M35 注入实验）：登录 zsh 的 profile（/etc/zsh/zprofile → distrobox 的 host-spawn）
    # 在“提示符已出现”之后仍会间歇性起前台子进程；make_pm_idle 的两次采样可以落在空档里，而紧接着的
    # 那一拍（§11b3 ⑤ 的 watch）撞上子进程，于是 attempts 行如实记成 state=unknown、断言 state=idle
    # 假红（P18 B2、M34 复验两条实测）。`bash --noprofile --norc` 让“空提示符”变成**构造性**的：
    # 没有 rc、没有异步子进程、cwd 由 tmux 的 -c 钉在 $REPO。
    tmux new-window -t "$SESSION" -n "$PMW" -d -c "$REPO" bash --noprofile --norc >/dev/null 2>&1 || true
    # 旧实现轮询 pane_current_command + sleep 0.5；只采样一次 team_pm_state 也不够：
    # 窗口刚建好的一瞬间 pane 还没 exec 出前台命令，team_pm_state 会**假**报 idle（空 cmd），
    # 紧接着启动命令就把它变成 unknown:*（§11b3 ⑤ 的 attempts 行正是这么记错的；注入 1.2s 的
    # 启动命令后，在负载下这次假 idle 稳定复现）。判据：连续三次采样（间隔 0.5s，覆盖 ≥1s）都是
    # idle:*，且每次都看到前台命令是真正的 shell。
    local i=0 st="" cmd="" n=0
    while [ "$i" -lt 40 ]; do
      st="$(pm_state_now 2>/dev/null || true)"
      cmd="$(tmux display-message -p -t "$SESSION:$PMW" '#{pane_current_command}' 2>/dev/null || true)"
      case "$st" in idle:*)
        case "$cmd" in
          zsh|bash|sh|dash|ash|ksh|fish)
            n=$((n + 1))
            [ "$n" -ge 3 ] && { PM_STATE_LAST="$st"; return 0; } ;;
          *) n=0 ;;
        esac ;;
      *) n=0 ;;
      esac
      sleep 0.5
      i=$((i + 1))
    done
    PM_STATE_LAST="$st"
    bad "make_pm_idle：等了 20s 窗口也没稳定在空提示符（最后状态 ${st:-?}，前台命令 [${cmd:-}]）"
  }

  start_fake_pm() { # 直接模拟“PM 正在跑”，避免依赖 up 的时序
    local p; p="$(tmux list-panes -t "$SESSION:$PMW" -F '#{pane_id}' 2>/dev/null | head -1)"
    # 空目标 = 当前 pane（会把调用者自己打掉）——这正是 v1.11.3 事故的直接原因
    [ -n "$p" ] || { bad "start_fake_pm：拿不到 pane（$SESSION:$PMW 不存在），跳过以免误伤"; return 1; }
    tmux respawn-pane -k -t "$p" "exec $FAKE/pi-sleep --pm" >/dev/null 2>&1 || true
    pm_state_until 'running:*' 10 || bad "start_fake_pm：等了 10s 假 PM 也没被认成 running:*（最后看到：${PM_STATE_LAST:-?}）"
  }
  kill_all_windows() {
    tmux list-windows -t "$SESSION" -F '#{window_id}' 2>/dev/null \
      | while read -r wid; do [ -n "$wid" ] && tmux kill-window -t "$wid" 2>/dev/null || true; done
    # 不等固定 0.5s：窗口列表真的空了才算关完（调用方随后可能删 session）
    local i=0
    while [ "$i" -lt 100 ]; do
      [ -z "$(tmux list-windows -t "$SESSION" -F '#{window_id}' 2>/dev/null)" ] && return 0
      sleep 0.05
      i=$((i + 1))
    done
    bad "kill_all_windows：5s 内 $SESSION 还有窗口（$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | tr '\n' ',')）"
  }
  pm_lines() { wc -l < "$TMP/pm-args.log" 2>/dev/null | tr -d ' ' || echo 0; }

  # 看门狗是周期性的：单拍可能撞在 pane 状态切换的瞬间 —— 允许最多再跑两拍（测试稳定性）
  watch_until_restart() { # <日志文件> [最多拍数]
    local log="$1" tries="${2:-3}" i=0
    while [ "$i" -lt "$tries" ]; do
      $TEAM watch --once >"$log" 2>&1 || true
      grep -qE '已拉起|已提醒|已在运行' "$log" && return 0
      sleep 1; i=$((i + 1))
    done
    return 1
  }
  wait_for() { # <文件> [秒]
    local f="$1" i=0 max="${2:-10}"
    while [ "$i" -lt "$max" ]; do [ -f "$f" ] && [ -s "$f" ] && return 0; sleep 1; i=$((i+1)); done
    return 1
  }

  # 1) team up 把 PM 拉起来（含 session 被删后重建）
  tmux kill-window -t "$SESSION:$PMW" 2>/dev/null || true
  tmux kill-window -t "$SESSION:keep" 2>/dev/null || true
  $TEAM up >"$TMP/up1.log" 2>&1 && ok "up 退出码 0（含 session 被删后重建）" || { bad "up 失败"; cat "$TMP/up1.log"; }
  assert_has "$TMP/up1.log" "PM 已启动" "up 报告了 PM 启动"
  if ! wait_for "$TMP/pm-args.log" 10; then
    team_dbg="$(tmux capture-pane -p -t "$SESSION:$PMW" 2>/dev/null | tail -5 | tr '\n' ' ')"
    bad "PM 的 pi 真的被拉起（参数已记录）（窗口内容：$team_dbg）"
  else ok "PM 的 pi 真的被拉起（参数已记录）"; fi
  assert_has "$TMP/pm-args.log" "-c" "PM 用 -c 延续会话（不丢历史）"
  assert_has "$TMP/pm-args.log" "pm-prompt.md" "PM 用 @文件 传开场提示词（避免 TTY 行长限制）"
  assert_has "$REPO/.pi/team/state/pm-prompt.md" "team digest" "提示词文件要求先跑 digest"
  assert_eq "pm 窗口被重建" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx "$PMW" || true)" "1"
  $TEAM pulse status >"$TMP/wdstatus.log" 2>&1
  assert_match "$TMP/wdstatus.log" "在运行|视为存活" "pulse status 看到 PM 在跑"
  assert_has "$TMP/wdstatus.log" "900s" "巡检周期默认 15 分钟（可配 5~60 分钟）"
  $TEAM up >"$TMP/up2.log" 2>&1
  assert_match "$TMP/up2.log" "PM 在运行|视为存活" "up 不会重复启动已跑的 PM"

  # 2) 没待办：不叫醒、不启动（不要求 PM 一直运行）
  $TEAM inbox --ack >/dev/null 2>&1
  $TEAM pulse status >"$TMP/wd-idle.log" 2>&1
  assert_match "$TMP/wd-idle.log" "待办 *无" "尚无待办：watchdog 不会打扰"
  make_pm_idle
  QUIET_BEFORE="$(pm_lines)"
  $TEAM watch --once >"$TMP/watch-quiet.log" 2>&1 || bad "watch --once 失败"
  assert_file "$REPO/.pi/team/state/capacity.log" "写了容量趋势日志"
  assert_file "$REPO/.pi/team/state/watchdog.last" "写了巡检时间戳"
  assert_match "$TMP/watch-quiet.log" "无待办" "明确说了“无待办”"
  assert_not "$TMP/watch-quiet.log" "已拉起" "没待办时不会拉起 PM"
  assert_eq "没待办时 PM 没被启动" "$(pm_lines)" "$QUIET_BEFORE"

  # 3) 有待办 + PM 在跑 → 只提醒，不重启；同批待办不重复叫
  $TEAM notify dev "T2 的依赖审好了，等 PM 派单" >/dev/null 2>&1
  start_fake_pm
  rm -f "$REPO/.pi/team/state/nudges.log"
  NUDGE_BEFORE="$(pm_lines)"
  $TEAM watch --once >"$TMP/watch-nudge.log" 2>&1 || bad "watch --once（有待办）失败"
  assert_match "$TMP/watch-nudge.log" "已提醒 PM" "有待办时叫醒 PM"
  assert_has "$REPO/.pi/team/state/nudges.log" "未读通知" "提醒内容写进 nudges.log"
  assert_eq "提醒不会重启 PM" "$(pm_lines)" "$NUDGE_BEFORE"
  N1="$(wc -l < "$REPO/.pi/team/state/nudges.log" | tr -d ' ')"
  $TEAM watch --once >/dev/null 2>&1
  assert_eq "同一批待办不会反复叫" "$(wc -l < "$REPO/.pi/team/state/nudges.log" | tr -d ' ')" "$N1"

  # 3b) PM 归属校验：窗口被「不属于本项目」的进程占着时，不算 PM、也不许覆盖
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd /tmp && exec bash -lc 'sleep 300'" >/dev/null 2>&1 || true
  if pm_state_until 'foreign:*' 10; then
    ok "别的项目的进程占着 PM 窗口 → 判定为 foreign（不算 PM）（$PM_STATE_LAST）"
  else
    bad "别的项目的进程占着 PM 窗口：等了 10s 也没判成 foreign:*（最后看到：${PM_STATE_LAST:-?}）"
  fi
  MAINROOT_STATE="$(. "$SKILL_DIR/scripts/lib/common.sh"; team_load_config; team_cwd_in_project /tmp && echo yes || echo no)"
  assert_eq "cwd 归属判定：/tmp 不属于本项目" "$MAINROOT_STATE" "no"
  $TEAM up >"$TMP/up-foreign.log" 2>&1 || true
  assert_has "$TMP/up-foreign.log" "不属于本项目" "team up 明确拒绝覆盖外来进程"
  assert_eq "拒绝后没有新开第二个 PM 窗口" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$PMW" || true)" "1"
  TEAM_REPLACE_FOREIGN_PM=1 $TEAM up >"$TMP/up-force.log" 2>&1 || true
  assert_match "$TMP/up-force.log" "PM 已启动|已在运行" "显式 TEAM_REPLACE_FOREIGN_PM=1 才允许覆盖"

  # 4) 有待办 + PM 不在跑 → 拉起（记 inbox + 计数）
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/docs/team/inbox/pm.md"
  make_pm_idle
  DEAD_BEFORE="$(pm_lines)"
  watch_until_restart "$TMP/watch2.log" 3 || true
  assert_match "$TMP/watch2.log" "已拉起" "watchdog 在有待办时把 PM 拉起来"
  assert_has "$REPO/.pi/team/state/watchdog.log" "→ 已拉起" "日志记录拉起动作"
  assert_has "$REPO/docs/team/inbox/pm.md" "pulse" "给 PM 留了收件箱消息（[pulse] 待办）"
  assert_eq "拉起计数已记录" "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ')" "1"
  if [ "$(pm_lines)" -gt "$DEAD_BEFORE" ]; then ok "PM 参数已写入（$DEAD_BEFORE → $(pm_lines)）"
  elif tmux list-panes -t "$SESSION:$PMW" -F '#{pane_pid}' | head -1 | xargs -r ps -o args= -p 2>/dev/null | grep -q pi-sleep; then
    ok "PM 已被拉起（窗口里跑着 pi，日志尚未落盘）"
  else bad "PM 没有被拉起（$DEAD_BEFORE → $(pm_lines)）"; fi

  # 4b) pulse：**只有一个后端**（同 session 的窗口里跑 monitor）
  $TEAM monitor --once >"$TMP/monitor.log" 2>&1 && ok "monitor --once 退出码 0" || bad "monitor --once 失败"
  assert_has "$TMP/monitor.log" "teamsmith pulse" "monitor 打印了标题（pulse 面板）"
  assert_has "$TMP/monitor.log" "巡检" "monitor 打印了巡检周期"
  assert_has "$TMP/monitor.log" "活动（仅本 session 在跑的窗口" "活动列默认打开（契约变更）"
  assert_has "$TMP/monitor.log" "仅本 session 在跑的窗口" "说明了活动列的服务范围"
  $TEAM monitor --once --no-activity >"$TMP/monitor-noact.log" 2>&1 || bad "monitor --no-activity 失败"
  assert_not "$TMP/monitor-noact.log" "活动（仅本 session" "--no-activity 关掉活动列"
  $TEAM monitor --once --activity >"$TMP/monitor-act.log" 2>&1 || bad "monitor --activity 失败"
  assert_has "$TMP/monitor-act.log" "活动（仅本 session 在跑的窗口" "--activity 显式打开活动流"
  assert_has "$TMP/monitor-act.log" "仅本 session 在跑的窗口" "活动流只覆盖本 session 的窗口"
  $TEAM pulse up >"$TMP/wd-up.log" 2>&1 && ok "pulse up（tmux 后端）退出码 0" || { bad "pulse up 失败"; cat "$TMP/wd-up.log"; }
  assert_eq "pulse 窗口已建" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx pulse || true)" "1"
  $TEAM pulse status >"$TMP/wd-status.log" 2>&1
  assert_has "$TMP/wd-status.log" "tmux 窗口 $SESSION:pulse 在跑" "status 看到窗口在跑"
  $TEAM pulse logs >"$TMP/wd-logs.log" 2>&1 && ok "pulse logs（pane 快照）退出码 0" || bad "pulse logs 失败"
  # M35：面板首帧是**异步**的 —— node/Ink 起来到画出第一屏之间 pane 是空的（pulse up 自己的 1.5s
  # 只保证进程在跑：team_pulse_window_state = team_pane_busy）。实测 M34 复验第二轮：这句读到 0 字节的
  # 快照而同一个 pane 稍后就有画面，断言假红（现场 wd-logs.log 大小 = 0）。判据不变（快照里必须出现
  # 面板标题），换的是等待方式：有界轮询实际条件，超时把最后一次快照原样打出来。
  WD_LOGS_WAIT=0
  while [ "$WD_LOGS_WAIT" -lt 40 ]; do
    grep -qF "teamsmith pulse" "$TMP/wd-logs.log" 2>/dev/null && break
    sleep 0.5
    $TEAM pulse logs >"$TMP/wd-logs.log" 2>&1 || true
    WD_LOGS_WAIT=$((WD_LOGS_WAIT + 1))
  done
  if ! grep -qF "teamsmith pulse" "$TMP/wd-logs.log" 2>/dev/null; then
    printf '  \033[33mℹ\033[0m pulse 窗口最后快照（%s 字节）：\n' \
      "$(wc -c < "$TMP/wd-logs.log" 2>/dev/null | tr -d ' ')"
    sed 's/^/    | /' "$TMP/wd-logs.log" 2>/dev/null | head -5
  fi
  assert_has "$TMP/wd-logs.log" "teamsmith pulse" "logs 显示面板画面"
  $TEAM pulse up >"$TMP/wd-up2.log" 2>&1
  assert_has "$TMP/wd-up2.log" "已在跑" "up 幂等（不重复起窗口）"
  $TEAM pulse down >"$TMP/wd-down.log" 2>&1 && ok "pulse down 退出码 0" || bad "pulse down 失败"
  assert_eq "pulse 窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx pulse || true)" "0"
  $TEAM pulse up --print >"$TMP/wd-print.log" 2>&1 && ok "pulse up --print 退出码 0" || bad "pulse --print 失败"
  assert_has "$TMP/wd-print.log" "$SESSION:pulse" "--print 指明它要起的窗口"
  assert_has "$TMP/wd-print.log" "巡检周期" "--print 说明巡检周期"
  # 容器后端已移除（v1.12.0）：必须明确拒绝，而不是静默忽略
  if $TEAM pulse up --container >"$TMP/wd-cont.log" 2>&1; then
    bad "pulse up --container 应被明确拒绝（容器后端已移除）"
  else
    ok "pulse up --container 被明确拒绝"
  fi
  assert_has "$TMP/wd-cont.log" "容器后端已移除" "拒绝时说明原因（并指向 pulse up）"

  # 5) standby：PM 主动停工，有待办也不叫
  $TEAM standby on --reason "等用户授权合并" >"$TMP/standby-on.log" 2>&1
  assert_has "$TMP/standby-on.log" "已进入待命" "standby on 生效"
  make_pm_idle
  SB_BEFORE="$(pm_lines)"
  $TEAM watch --once >"$TMP/watch-sb.log" 2>&1 || true
  assert_eq "待命期间不叫醒、不拉起" "$(pm_lines)" "$SB_BEFORE"
  assert_has "$REPO/.pi/team/state/watchdog.log" "standby 中" "日志记录“待命所以不叫醒”"
  $TEAM standby off >/dev/null 2>&1
  watch_until_restart "$TMP/watch-sb2.log" 3 || true
  assert_match "$TMP/watch-sb2.log" "已拉起" "standby off 后有待办就继续拉起"

  # 6) 不管 tmux：session 丢了只告警；开关打开才重建
  $TEAM notify dev "新待办：T3 计划待确认" >/dev/null 2>&1   # 待办变化 → 告警会重新出现（同批不重复）
  kill_all_windows
  tmux kill-session -t "$SESSION" 2>/dev/null || true      # 确保“session 丢了”的前提真的成立
  # 看门狗的告警按「待办批次」去重（sig）；把上一批的 sig 打旧，这一拍才会走到
  # “session 丢了 → 请人工 up”的告警分支（否则同一批待办会被有意静音）。
  TEAM_ROOT="$REPO" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_state_set _watch last_sig m63-step6-stale'
  $TEAM watch --once >"$TMP/watch4.log" 2>&1 || true
  if tmux has-session -t "$SESSION" 2>/dev/null; then bad "pulse 不该重建 tmux session（默认不管 tmux）"; else ok "session 丢了 pulse 不重建（默认不管 tmux）"; fi
  assert_match "$TMP/watch4.log" "不管 tmux|人工" "给出了“需要人工 up”的提示"
  TEAM_PULSE_REBUILD_TMUX=1 $TEAM watch --once >"$TMP/watch5.log" 2>&1 || true
  assert_eq "开关打开后才重建 pm 窗口" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$PMW" || true)" "1"
  assert_match "$TMP/watch5.log" "已拉起" "重建后把 PM 拉起来了"

  # 7) 自动拉起配额：防崩溃循环
  make_pm_idle
  for _ in 1 2 3 4 5; do date +%s >> "$REPO/.pi/team/state/pm-restarts.log"; done
  # 配额只在「有待办」时才会被检查（没待办直接 ③a 返回「不叫醒」）。
  # 前面几拍可能已经把待办清空 → 这条断言曾偶发假红（实测 2 红 1 绿）；
  # 显式造一个未读通知，让这一拍一定走到配额分支。
  $TEAM notify pm "配额自检：有待办" >/dev/null 2>&1 || true
  $TEAM watch --once >"$TMP/watch3.log" 2>&1 || true
  assert_has "$TMP/watch3.log" "已被重启" "超过配额时拒绝继续拉起（告警）"
  # 收尾：清配额/占位窗口，把 PM 拉回来
  rm -f "$REPO/.pi/team/state/pm-restarts.log"
  tmux kill-window -t "$SESSION:keep" 2>/dev/null || true
  $TEAM inbox --ack >/dev/null 2>&1
  $TEAM up >/dev/null 2>&1 || true

  # 8) M6.3 F26（真进程证据）：PM 不在跑时，worker 的通知走「PM 自己的收件箱」也必须叫醒它。
  #    旧实现只遍历名册：这条 durable 通道不在待办里，只有 TMUX 敲门（PM 必须在跑）。
  rm -f "$REPO/docs/team/inbox/pm.md" "$REPO/.pi/team/state/pm-restarts.log"
  $TEAM inbox --ack >/dev/null 2>&1
  printf 'M6.3 F26 live: worker summary awaiting the PM\n' > "$TMP/m63-pm-summary.txt"
  make_pm_idle
  M63_PM_BEFORE="$(pm_lines)"
  $TEAM notify pm --from-file "$TMP/m63-pm-summary.txt" >"$TMP/m63-notify-pm.log" 2>&1 || bad "notify pm 失败"
  assert_has "$REPO/docs/team/inbox/pm.md" "M6.3 F26 live" "F26：PM 自己的收件箱真的写了（PM 不在跑也不丢）"
  $TEAM pulse status >"$TMP/m63-wd-pm.log" 2>&1 || true
  assert_has "$TMP/m63-wd-pm.log" "未读通知" "F26：pulse status 把它算作待办"
  watch_until_restart "$TMP/m63-watch-pm.log" 3 || true
  assert_match "$TMP/m63-watch-pm.log" "已拉起" "F26：watchdog 因为 PM 自己的收件箱把 PM 拉起来"
  assert_eq "F26：PM 真的被拉起（argv 落盘）" "$([ "$(pm_lines)" -gt "$M63_PM_BEFORE" ] && echo grew || echo same)" "grew"
  $TEAM inbox --ack >/dev/null 2>&1   # 收尾：把待办清回基线（后面的段落按“无待办”跑）
else
  printf '  (跳过巡检断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11b2. PM 存活的证据链（M6.5）
# 事故：新建的、**空的** session 窗口被报成「PM 在运行（tmux）」—— `team up` 什么也没启动却说成功，
# watchdog-status / ps / digest 照抄这个谎，环境重启后 7 条 smoke 断言变红。
# 这里钉住新规则：存活必须是「证明」（state/pm.pid 活着且 cwd 在本项目，或窗口里就是配置的 agent），
# 其它一律不算 PM，也**不得**压制启动。
section "11b2 · PM 存活必须被证明（M6.5：空窗 ≠ PM 在运行）"
if [ "$FAST" = "1" ]; then
  fast_skip "11b2·PM 存活证据链" "要真实 tmux 窗口 + 假 pi 进程（空 session / 非 PM 占用 / 杀 pid / 外来进程）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  # 注意：teamsmith 自己就是被这个 smoke 拉起来的，所以断言必须通过 `team` CLI 与 state/ 读，
  # 不依赖调用者的 shell、也不读开发者自己的 session。
  # （pm_state_now 的定义在 §11b 的 helpers 里——M9.7 把它上移，供有界轮询复用。）
  # 造「新建的 session + 空的 pm 窗口」：这就是环境重启后的现场，也是 M6.5 的确定性复现。
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  wait_session_gone "$SESSION" 5 || bad "M6.5 ① 夹具：5s 内 session $SESSION 还在（「session 完全不在」的前提没成立）"
  $TEAM up >"$TMP/m65-up-fresh.log" 2>&1 && ok "M6.5 ①：session 完全不在时 up 退出码 0" || { bad "M6.5 ①：up 失败"; cat "$TMP/m65-up-fresh.log"; }
  assert_has "$TMP/m65-up-fresh.log" "PM 已启动" "M6.5 ①：空 session 里 up 真的启动了 PM（旧实现说「PM 在运行（tmux）」却什么也没跑）"
  assert_not "$TMP/m65-up-fresh.log" "PM 在运行（tmux）" "M6.5 ①：不再把 tmux 自己报成运行中的 PM"
  FRESH_AFTER="$(pm_lines)"
  assert_eq "M6.5 ①：假 agent 真的被拉起（argv 落盘）" "$([ "$FRESH_AFTER" -gt 0 ] && echo yes || echo no)" "yes"
  case "$(pm_state_now)" in
    running:*) ok "M6.5 ①：启动后状态是 running（$(pm_state_now)）" ;;
    *) bad "M6.5 ①：启动后状态不是 running（$(pm_state_now)）" ;;
  esac
  M65_PID="$(cat "$REPO/.pi/team/state/pm.pid" 2>/dev/null | tr -dc '0-9')"
  if [ -n "$M65_PID" ] && kill -0 "$M65_PID" 2>/dev/null; then ok "M6.5 ①：state/pm.pid 记录了活着的 PM pid"; else bad "M6.5 ①：state/pm.pid 缺失或指向死进程（[$M65_PID]）"; fi
  # ①b 复现 PM 报告的确切格子（thread 第 2/3 条）：cwd 在项目内 + 前台进程名是 `tmux`。
  # 老规则（窗口在 + 前台不是 shell）在这里就会输出 `running:tmux`；新规则必须报 unknown/idle
  # 且 up 真的把 PM 拉起来（argv 日志里出现 -c 与 @pm-prompt.md）。
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec tmux wait-for teamsmith-m65-never" >/dev/null 2>&1 || true
  if pm_state_until 'unknown:tmux' 'idle:*' 10; then
    ok "M6.5 ①b：前台是 tmux 的窗口不算 PM（$PM_STATE_LAST）"
  else
    bad "M6.5 ①b：期望 unknown:tmux/idle:*，等了 10s 最后看到 ${PM_STATE_LAST:-?}"
  fi
  $TEAM pulse status >"$TMP/m65-wd-tmux.log" 2>&1 || true
  assert_not "$TMP/m65-wd-tmux.log" "在运行" "M6.5 ①b：pulse status 不把 tmux 报成「PM 在运行」"
  BEFORE_TMUX="$(pm_lines)"
  $TEAM up >"$TMP/m65-up-tmux.log" 2>&1 || true
  assert_has "$TMP/m65-up-tmux.log" "PM 已启动" "M6.5 ①b：前台是 tmux 也不压制启动（PM 报告的原症状）"
  assert_eq "M6.5 ①b：假 agent 的 argv 落盘" "$([ "$(pm_lines)" -gt "$BEFORE_TMUX" ] && echo grew || echo same)" "grew"
  tail -n +"$((BEFORE_TMUX + 1))" "$TMP/pm-args.log" > "$TMP/m65-pm-args-delta-tmux.log" 2>/dev/null || true
  assert_has "$TMP/m65-pm-args-delta-tmux.log" "-c" "M6.5 ①b：这一轮真的用 -c 拉起 PM（不丢历史）"
  assert_has "$TMP/m65-pm-args-delta-tmux.log" "pm-prompt.md" "M6.5 ①b：这一轮真的用 @ 提示词文件拉起 PM"
  M65_PID="$(cat "$REPO/.pi/team/state/pm.pid" 2>/dev/null | tr -dc '0-9')"
  # ② 记录的 pid 是证据本身：杀掉它 → 必须立刻不再算存活
  kill -9 "$M65_PID" 2>/dev/null || true
  if pm_state_until_not 'running:*' 10; then
    ok "M6.5 ②：记录的 pid 死了 → 不再算存活（$PM_STATE_LAST）"
  else
    bad "M6.5 ②：记录的 pid 已被杀，等了 10s 仍报 $PM_STATE_LAST"
  fi
  $TEAM pulse status >"$TMP/m65-wd-dead.log" 2>&1 || true
  assert_not "$TMP/m65-wd-dead.log" "在运行" "M6.5 ②：pulse status 不再宣称 PM 在运行"
  # ③ 本项目 cwd 里的非 PM 进程（sleep）占着 pm 窗口：unknown:*，不算存活，up 会替换
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -n "$PMW" -c "$REPO" 2>/dev/null || true
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec sleep 300" >/dev/null 2>&1 || true
  if pm_state_until 'unknown:*' 10; then
    ok "M6.5 ③：本项目里的非 PM 进程 → unknown:*（$PM_STATE_LAST）"
  else
    bad "M6.5 ③：期望 unknown:*，等了 10s 最后看到 ${PM_STATE_LAST:-?}"
  fi
  $TEAM pulse status >"$TMP/m65-wd-unknown.log" 2>&1 || true
  assert_not "$TMP/m65-wd-unknown.log" "在运行" "M6.5 ③：pulse status 不把非 PM 进程当成运行中的 PM"
  BEFORE_UNKNOWN="$(pm_lines)"
  $TEAM up >"$TMP/m65-up-unknown.log" 2>&1 || true
  assert_has "$TMP/m65-up-unknown.log" "PM 已启动" "M6.5 ③：非 PM 占用不压制启动（up 真的拉起 PM）"
  assert_eq "M6.5 ③：假 agent 的 argv 又落盘了" "$([ "$(pm_lines)" -gt "$BEFORE_UNKNOWN" ] && echo grew || echo same)" "grew"
  # 只看这一轮新增的 argv：证明拉起的是真 PM 命令（-c 延续会话 + @pm-prompt.md），不是旧日志在充数
  tail -n +"$((BEFORE_UNKNOWN + 1))" "$TMP/pm-args.log" > "$TMP/m65-pm-args-delta.log" 2>/dev/null || true
  assert_has "$TMP/m65-pm-args-delta.log" "-c" "M6.5 ③：这一轮真的用 -c 拉起 PM（不丢历史）"
  assert_has "$TMP/m65-pm-args-delta.log" "pm-prompt.md" "M6.5 ③：这一轮真的用 @ 提示词文件拉起 PM"
  # ④ 外来进程（cwd 不在本项目）占着 pm 窗口：foreign:*，不算存活，up 默认拒绝覆盖
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd /tmp && exec sleep 300" >/dev/null 2>&1 || true
  if pm_state_until 'foreign:*' 10; then
    ok "M6.5 ④：别的项目的进程 → foreign:*（$PM_STATE_LAST）"
  else
    bad "M6.5 ④：期望 foreign:*，等了 10s 最后看到 ${PM_STATE_LAST:-?}"
  fi
  case "$(pm_state_now)" in
    running:*) bad "M6.5 ④：外来进程被当成运行中的 PM" ;;
    *)         ok "M6.5 ④：外来进程不算 PM（不撒谎）" ;;
  esac
  $TEAM pulse status >"$TMP/m65-wd-foreign.log" 2>&1 || true
  assert_not "$TMP/m65-wd-foreign.log" "在运行" "M6.5 ④：pulse status 不把外来进程当成运行中的 PM"
  $TEAM up >"$TMP/m65-up-foreign2.log" 2>&1 || true
  assert_has "$TMP/m65-up-foreign2.log" "不属于本项目" "M6.5 ④：up 明确拒绝覆盖外来进程"
  # ④b 窗口里的进程就是配置的 agent（人工启动的 PM）→ running（不是 unknown）
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec $FAKE/pi-sleep --manual-pm" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/pm.pid"    # 拿掉「我们启动过」这个证据，只留窗口证据
  if pm_state_until 'running:*' 10; then
    ok "M6.5 ④b：人工在窗口里启动的 agent 被认成 running（$PM_STATE_LAST）"
  else
    bad "M6.5 ④b：人工启动的 agent 没被认出（等了 10s 最后看到 ${PM_STATE_LAST:-?}）"
  fi
  # ⑤ M6.3 F30：wrapper agent（脚本最后 exec 掉自己）必须被报为已启动，证据 = spawn。
  # 旧实现只认「窗口里的进程 == 配置的 agent 可执行文件」：exec 换掉进程映像后永远认不出来，
  # 于是给一个活得好好的 PM 报「启动失败」（PM 在 /tmp/pm-freeze2 复现过）。
  M63_WRAP="$TMP/m63-pm-wrapper"
  printf '#!/bin/sh\nexec sleep 300\n' > "$M63_WRAP"; chmod +x "$M63_WRAP"
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$M63_WRAP\"|" "$REPO/.pi/team/config.sh"
  tmux kill-session -t "$SESSION" 2>/dev/null || true   # 从「场地不在」开始，up 自己要建
  wait_session_gone "$SESSION" 5 || bad "F30 夹具：5s 内 session $SESSION 还在（「场地不在」的前提没成立）"
  rm -f "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  $TEAM up >"$TMP/m63-f30-up.log" 2>&1 || true
  assert_has "$TMP/m63-f30-up.log" "PM 已启动" "F30：wrapper agent 被报为已启动（不再误报「看不到 agent 进程」）"
  assert_has "$TMP/m63-f30-up.log" "proof=spawn" "F30：启动证据就是 spawn（argv 认不出 exec 之后的进程）"
  assert_eq "F30：state/pm.pid.proof 记录了证据" "$(cat "$REPO/.pi/team/state/pm.pid.proof" 2>/dev/null)" "spawn"
  M63_SPID="$(tr -dc '0-9' < "$REPO/.pi/team/state/pm.pid" 2>/dev/null || true)"
  if [ -n "$M63_SPID" ] && kill -0 "$M63_SPID" 2>/dev/null; then ok "F30：pm.pid 记录的是我们 spawn 的活 pid"; else bad "F30：pm.pid 无效（[$M63_SPID]）"; fi
  case "$(pm_state_now)" in
    running:*) ok "F30：wrapper PM 之后仍是 running（$(pm_state_now)）" ;;
    *)         bad "F30：启动后状态不是 running（$(pm_state_now)）" ;;
  esac
  $TEAM pulse status >"$TMP/m63-f30-wd.log" 2>&1 || true
  assert_has "$TMP/m63-f30-wd.log" "proof=spawn" "F30：pulse status 显示证据来源"
  # 没有我们的 pid 记录时，窗口里的 sleep（cwd 在本项目）依旧不算 PM：非 shell 不是证据
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec sleep 300" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  if pm_state_until 'unknown:*' 10; then
    ok "F30：别人放的 sleep 只是 unknown（$PM_STATE_LAST）"
  else
    bad "F30：期望 unknown:sleep（非 shell 不是证据），等了 10s 最后看到 ${PM_STATE_LAST:-?}"
  fi
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
  # 收尾：把 PM 拉回来，后面的段落（11c 起）按原来的现场跑
  $TEAM up >/dev/null 2>&1 || true
else
  printf '  (跳过 PM 存活证据链：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11b3. 启动在飞行中（M7.2）
# 根因（逐拍采样见 tests/flip-m7.2.sh）：从 respawn 到「拿到启动证据」之间，PM 窗口里是一个正在跑
# 启动命令的 shell —— 项目内、非 agent，team_pm_state 只能报 unknown。没有「正在启动」这个状态时，
# **另一拍**会把它当成「没有 PM」再拉起一次：respawn-pane **杀掉刚起来的 PM**，配额把一次启动
# 记成两次（实测：1 个活 PM、2 行 pm-restarts.log、24 行 agent argv = 第一个 PM 被写了一半就杀了）。
# 这里钉住新规则：启动在飞行中 = 一个状态（不重复拉起、不计数），且同一拍里的说法必须自洽。
section "11b3 · 启动中的 PM：一拍只拉起一次（M7.2）"
if [ "$FAST" = "1" ]; then
  fast_skip "11b3·启动中的 PM（M7.2）" "要真实 tmux 窗口 + 并发两拍巡检（真进程）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  start_count() { local n; n="$(grep -c 'pm-prompt.md' "$TMP/pm-args.log" 2>/dev/null || true)"; printf '%s\n' "${n:-0}"; }
  pm_pane_pid() { tmux display-message -p -t "$SESSION:$PMW" '#{pane_pid}' 2>/dev/null || true; }
  mark_file() { printf '%s\n' "$REPO/.pi/team/state/pm.pid.starting"; }
  # 沙箱（M7.2 教训）：这一段会写盘（notify + 多拍巡检），先证明身份真的在夹具仓库里，
  # 再给本轮取一个唯一签名 —— 跑完拿它去真实账本里搜：搜到就是夹具把幻影待办喂进了真账本。
  M72_SIG="M7.2 $SESSION：启动中的 PM 也有待办"
  $TEAM paths >"$TMP/m72-paths.json" 2>&1 || true
  assert_eq "沙箱断言：team paths 的 main_root 就是夹具仓库" \
    "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m72-paths.json")" "$REPO"
  assert_has "$TMP/m72-paths.json" "\"session\": \"$SESSION\"" "沙箱断言：身份用的就是本轮临时 session"
  m72_real_main() { # 真实团队的主工作树（skill 仓库的 git-common-dir 父目录）
    local common d
    common="$(git -C "$SKILL_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || { printf '%s' "$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null)"; return 0; }
    d="$(dirname "$common")"; (cd "$d" 2>/dev/null && pwd -P) || printf '%s' "$d"
  }
  m72_ledger_fp() { # <root>：inbox+state 的文件指纹（路径 + md5）
    local root="$1" dir f
    for dir in "$root/docs/team/inbox" "$root/.pi/team/state"; do
      [ -d "$dir" ] || continue
      find "$dir" -type f 2>/dev/null | sort | while IFS= read -r f; do
        printf '%s %s\n' "$f" "$(md5sum "$f" 2>/dev/null | cut -d' ' -f1)"
      done
    done | md5sum | awk '{print $1}'
  }
  M72_REAL_MAIN="$(m72_real_main)"
  M72_LEDGER_BEFORE="$(m72_ledger_fp "$M72_REAL_MAIN")"

  # ① 真正的一场比赛：第一拍在后台拉起 PM；pane 一换进程（= respawn 已发生）就立刻打第二拍。
  #    注意：**真实**启动的「正在启动」窗口有多宽取决于 spawn 文件何时落盘（可能只几十 ms），
  #    所以这里只钉与时间无关的结果（不重复拉起/不计数/不动 pane/只起一个）；
  #    「starting 这个状态本身」由下面 ③ 用确定性的标记现场钉死（真实路径的窗口见 tests/flip-m7.2.sh）。
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log" \
        "$TMP/m72-tick1.log" "$TMP/m72-tick2.log"
  make_pm_idle
  PRE_PANE="$(pm_pane_pid)"
  $TEAM notify dev "$M72_SIG" >/dev/null 2>&1 || true
  STARTS_BEFORE="$(start_count)"
  $TEAM watch --once >"$TMP/m72-tick1.log" 2>&1 &
  TICK1=$!
  i=0
  while [ "$i" -lt 60 ]; do
    [ "$(pm_pane_pid)" != "$PRE_PANE" ] && break
    sleep 0.05; i=$((i + 1))
  done
  MID_PANE="$(pm_pane_pid)"
  assert_eq "第一拍已经把 pane 换成新进程（respawn 真的发生了）" \
    "$([ -n "$MID_PANE" ] && [ "$MID_PANE" != "$PRE_PANE" ] && echo yes || echo no)" "yes"
  $TEAM watch --once >"$TMP/m72-tick2.log" 2>&1 || true
  assert_not "$TMP/m72-tick2.log" "已拉起" "第二拍没有重复拉起"
  assert_not "$TMP/m72-tick2.log" "已被重启" "第二拍没有配额告警（启动中的一拍不计数）"
  wait "$TICK1" 2>/dev/null || true
  assert_eq "第一拍真的拉起了 PM" "$(grep -c 已拉起 "$TMP/m72-tick1.log" 2>/dev/null || true)" "1"
  assert_eq "重启配额只记 1 次（一次启动一行）" \
    "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" 2>/dev/null | tr -d ' ')" "1"
  assert_eq "配额那行带证据（state=… evidence=…）" \
    "$(grep -c 'state=.*evidence=' "$REPO/.pi/team/state/pm-restarts.log" 2>/dev/null || true)" "1"
  assert_eq "PM 只被启动了一次（argv 里只有一个 @pm-prompt.md）" \
    "$(( $(start_count) - STARTS_BEFORE ))" "1"
  assert_eq "第二拍没有杀掉刚起来的 PM（pane 没换）" "$(pm_pane_pid)" "$MID_PANE"
  assert_eq "启动标记用完就撤" "$([ -f "$(mark_file)" ] && echo present || echo gone)" "gone"
  case "$(pm_state_now)" in
    running:*) ok "启动完成后状态是 running（$(pm_state_now)）" ;;
    *)         bad "启动完成后不是 running（$(pm_state_now)）" ;;
  esac
  # 第三拍（PM 已在跑）：只提醒、不再拉起 —— 连续几拍都不得出现配额告警
  $TEAM watch --once >"$TMP/m72-tick3.log" 2>&1 || true
  assert_not "$TMP/m72-tick3.log" "已被重启" "第三拍没有配额告警"
  assert_not "$TMP/m72-tick3.log" "已拉起" "第三拍不再拉起（PM 已在跑）"
  assert_eq "第三拍之后配额仍是 1 行" \
    "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" 2>/dev/null | tr -d ' ')" "1"

  # ② 代理进程退出：下一拍必须恰好看到一次「停了的 PM」（一次启动、一行配额）
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  STARTS_BEFORE="$(start_count)"
  M72_PID="$(tr -dc '0-9' < "$REPO/.pi/team/state/pm.pid" 2>/dev/null || true)"
  if [ -n "$M72_PID" ]; then kill -9 "$M72_PID" 2>/dev/null || true; fi
  if pm_state_until_not 'running:*' 10; then
    ok "代理进程退出后不再是 running（$PM_STATE_LAST）"
  else
    bad "代理进程被杀后，等了 10s 仍报 running（$PM_STATE_LAST）"
  fi
  TEAM_PULSE_REBUILD_TMUX=1 $TEAM watch --once >"$TMP/m72-tick4.log" 2>&1 || true
  assert_match "$TMP/m72-tick4.log" "已拉起" "代理退出后下一拍把它拉起来"
  assert_eq "代理退出后恰好记 1 行重启" \
    "$(cat "$REPO/.pi/team/state/pm-restarts.log" 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_eq "代理退出后只启动一次" "$(( $(start_count) - STARTS_BEFORE ))" "1"
  assert_eq "停了的 PM 只被看见一次（再打一拍不再拉起）" \
    "$(TEAM_PULSE_REBUILD_TMUX=1 $TEAM watch --once 2>&1 | grep -c 已拉起 || true)" "0"
  # 日志要说清楚「凭什么」启动（证据；M7.2 的诚实性要求）
  assert_match "$REPO/.pi/team/state/watchdog.log" "证据：.*(pm.pid|窗口)" "watchdog.log 记录了拉起决策的证据"

  # ③ 确定性（不靠时序）：标记在，就必须是一个状态 —— 不重复拉起、不计数，且各视图说法一致
  make_pm_idle
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  STARTS_BEFORE="$(start_count)"
  ( . "$SKILL_DIR/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_pm_starting_begin "$SESSION:$PMW" )
  case "$(pm_state_now)" in
    starting:*) ok "手动落下的启动标记 → team_pm_state 报 starting:*（$(pm_state_now)）" ;;
    *)          bad "有启动标记却报 $(pm_state_now)（应为 starting:*）" ;;
  esac
  $TEAM pulse status >"$TMP/m72-wd.log" 2>&1 || true
  assert_has "$TMP/m72-wd.log" "正在启动" "pulse status：启动中如实说「正在启动」"
  assert_not "$TMP/m72-wd.log" "在运行" "pulse status：不把启动中说成「在运行」"
  assert_not "$TMP/m72-wd.log" "会拉起" "pulse status：启动中不再说「会拉起」（同一拍自相矛盾）"
  $TEAM digest >"$TMP/m72-digest.log" 2>&1 || true
  assert_has "$TMP/m72-digest.log" "正在启动" "digest：启动中如实说「正在启动」"
  assert_not "$TMP/m72-digest.log" "在运行" "digest：不把启动中说成「在运行」"
  assert_not "$TMP/m72-digest.log" "会拉起" "digest：启动中不再说「会拉起」"
  $TEAM up >"$TMP/m72-up2.log" 2>&1 || true
  assert_has "$TMP/m72-up2.log" "正在启动" "up 也认这个状态（不重复拉起）"
  assert_not "$TMP/m72-up2.log" "PM 已启动" "up 在启动进行中不启动第二个 PM"
  $TEAM watch --once >"$TMP/m72-tick8.log" 2>&1 || true
  assert_has "$TMP/m72-tick8.log" "不重复拉起" "启动中的一拍明确说「不重复拉起」"
  assert_not "$TMP/m72-tick8.log" "已拉起" "启动中的一拍没有拉起"
  assert_not "$TMP/m72-tick8.log" "已被重启" "启动中的一拍不发配额告警"
  assert_eq "启动中的一拍不吃配额" \
    "$([ -f "$REPO/.pi/team/state/pm-restarts.log" ] && wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ' || echo 0)" "0"
  assert_eq "启动中的一拍不启动 PM" "$(( $(start_count) - STARTS_BEFORE ))" "0"

  # ④ 陈旧标记不是锁：启动器崩了留下的标记过期后，下一拍照样能拉起
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  sed -i "s/^[0-9][0-9]* /$(( $(date +%s) - 600 )) /" "$(mark_file)"
  case "$(pm_state_now)" in
    starting:*) bad "陈旧的启动标记仍然被当成 starting:*（锁死了）" ;;
    *)          ok "陈旧标记过期后不再报 starting:*（$(pm_state_now)）" ;;
  esac
  $TEAM watch --once >"$TMP/m72-tick5.log" 2>&1 || true
  assert_match "$TMP/m72-tick5.log" "已拉起" "陈旧标记不阻塞拉起"
  assert_eq "陈旧标记之后配额 +1（上一拍没计过）" \
    "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" 2>/dev/null | tr -d ' ')" "1"
  assert_eq "陈旧标记之后只启动一次" "$(( $(start_count) - STARTS_BEFORE ))" "1"

  # ⑤ 失败/超时的拉起尝试不吃配额：记账发生在真的拉起之后（M7.2 的另一半诚实性）
  make_pm_idle
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  STARTS_BEFORE="$(start_count)"
  TEAM_PM_START_WAIT=0 $TEAM watch --once >"$TMP/m72-tick6.log" 2>&1 || true
  assert_match "$TMP/m72-tick6.log" "拉起失败" "TEAM_PM_START_WAIT=0：这一拍如实报「拉起失败」"
  assert_not "$TMP/m72-tick6.log" "已拉起" "失败的一拍不报「已拉起」"
  assert_eq "失败的拉起尝试不吃配额（0 行）" \
    "$([ -f "$REPO/.pi/team/state/pm-restarts.log" ] && wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ' || echo 0)" "0"
  assert_has "$REPO/.pi/team/state/watchdog.log" "未计入配额" "日志写明失败的尝试不计数"
  assert_eq "失败的尝试记进了 attempts 日志（决策 + 证据）" \
    "$(cat "$REPO/.pi/team/state/pm-start-attempts.log" 2>/dev/null | wc -l | tr -d ' ')" "1"
  # ④ M35：断言红时把 attempts 实际记的那行原样打出来 —— 否则只知道「找不到 state=idle」，
  # 不知道 watch 到底看见了什么（P18 B2 / M34 两次假红的排查都卡在这里）。
  if ! grep -qF "state=idle" "$REPO/.pi/team/state/pm-start-attempts.log" 2>/dev/null; then
    printf '  \033[33mℹ\033[0m attempts 实际记的是：[%s]（期望 state=idle；PM 窗口此刻 cmd=[%s]）\n' \
      "$(tail -n 1 "$REPO/.pi/team/state/pm-start-attempts.log" 2>/dev/null || true)" \
      "$(tmux display-message -p -t "$SESSION:$PMW" '#{pane_current_command}' 2>/dev/null || true)"
  fi
  assert_has "$REPO/.pi/team/state/pm-start-attempts.log" "state=idle" "attempts 行带决策证据（state=…）"
  assert_eq "失败路径也撤掉了启动标记" "$([ -f "$(mark_file)" ] && echo present || echo gone)" "gone"
  # 那次尝试其实已经把进程起来了（respawn 在「等证据」之前），只是来不及写下 pm.pid ——
  # 下一拍必须靠**窗口证据**认出它，而不是再拉一次（没有记录 ≠ 没有 PM；再拉一次就是重复启动）
  i=0
  while [ "$i" -lt 30 ] && [ "$(( $(start_count) - STARTS_BEFORE ))" -lt 1 ]; do sleep 0.1; i=$((i + 1)); done
  assert_eq "失败的一拍确实已经把进程起来了（argv 落盘）" "$(( $(start_count) - STARTS_BEFORE ))" "1"
  $TEAM watch --once >"$TMP/m72-tick7.log" 2>&1 || true
  assert_not "$TMP/m72-tick7.log" "已拉起" "窗口里已有 PM → 下一拍不再拉起（即使没有 pm.pid 证据）"
  assert_not "$TMP/m72-tick7.log" "已被重启" "也不再发配额告警"
  assert_eq "配额仍然 0 行（失败的尝试一次都没记）" \
    "$([ -f "$REPO/.pi/team/state/pm-restarts.log" ] && wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ' || echo 0)" "0"
  assert_eq "只起过一个 PM（没有重复启动）" "$(( $(start_count) - STARTS_BEFORE ))" "1"
  case "$(pm_state_now)" in
    running:*) ok "状态是 running（靠窗口证据，而不是 pm.pid）：$(pm_state_now)" ;;
    *)         bad "期望 running:*（窗口里的进程就是配置的 agent），实际 $(pm_state_now)" ;;
  esac

  # ⑥ 限流也认「尝试」：拉起反复失败（每次都留一行 attempts）也必须被拦住 ——
  # respawn 已经把进程拉起来了，不然失败循环就没有上限（规范：1 小时内最多 TEAM_WATCH_MAX_RESTARTS 次）
  make_pm_idle
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  STARTS_BEFORE="$(start_count)"
  for _ in 1 2 3 4 5; do date +%s >> "$REPO/.pi/team/state/pm-start-attempts.log"; done
  $TEAM watch --once >"$TMP/m72-tick9.log" 2>&1 || true
  assert_has "$TMP/m72-tick9.log" "已尝试拉起" "拉起反复失败也受限流（attempts 计数）"
  assert_not "$TMP/m72-tick9.log" "已拉起" "被 attempts 限流的那一拍没有拉起"
  assert_eq "被 attempts 限流时也没有启动进程" "$(( $(start_count) - STARTS_BEFORE ))" "0"
  rm -f "$REPO/.pi/team/state/pm-start-attempts.log"

  # 收尾（+反向守卫）：清配额/待办与标记，让后面的段落（11c 起）回到干净现场，
  # 并证明这一段没有把幻影待办写进真实账本（M7.2 现场教训：夹具曾在调用者 cwd 里跑 team）。
  M72_REAL_LEAK="$(grep -rlF "$M72_SIG" "$M72_REAL_MAIN/docs/team/inbox" "$M72_REAL_MAIN/.pi/team/state" 2>/dev/null | head -3 || true)"
  assert_eq "反向守卫：真实账本（$M72_REAL_MAIN）里没有本夹具的签名" "${M72_REAL_LEAK:-none}" "none"
  M72_LEDGER_AFTER="$(m72_ledger_fp "$M72_REAL_MAIN")"
  if [ "$M72_LEDGER_BEFORE" = "$M72_LEDGER_AFTER" ]; then
    ok "反向守卫：真实账本 inbox+state 一个字节没变（指纹 ${M72_LEDGER_AFTER}）"
  else
    printf '  \033[33mℹ\033[0m 反向守卫：真实账本在本段里有别的写入（%s → %s；上面已证明其中没有夹具签名）\n' \
      "$M72_LEDGER_BEFORE" "$M72_LEDGER_AFTER"
  fi
  rm -f "$(mark_file)" "$REPO/.pi/team/state/pm-restarts.log" "$REPO/.pi/team/state/pm-start-attempts.log"
  $TEAM inbox --ack >/dev/null 2>&1 || true
else
  printf '  (跳过启动中的 PM 断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11b4. PM 交接：--fresh-pm + 同 cwd 活会话提示（P36）
# A：`team up --fresh-pm` = 这一次启动新开会话（不 -c；`--print` 里会话判定与完整命令都可见、可断言）；
# C：启动前只读探测同 cwd 还有活着的 PM CLI 会话 → 只提示（不阻断；不碰 M6.5 的判活/替换语义）。
section "11b4 · PM 交接：--fresh-pm 与同 cwd 活会话提示（P36）"
# ① --print（纯逻辑：不建场地、不写状态）—— 快慢模式都跑
$TEAM up --print >"$TMP/p36-print-cont.log" 2>&1 && ok "P36 ①：up --print 退出码 0" || { bad "P36 ①：up --print 失败"; cat "$TMP/p36-print-cont.log"; }
assert_has "$TMP/p36-print-cont.log" "会话判定：continued:pi -c" "P36 ①：默认明说这一次续用 -c"
grep '^完整命令：' "$TMP/p36-print-cont.log" > "$TMP/p36-cmd-cont.log" 2>/dev/null || true
assert_has "$TMP/p36-cmd-cont.log" " -c " "P36 ①：默认渲染出的命令带 -c"
$TEAM up --print --fresh-pm >"$TMP/p36-print-fresh.log" 2>&1 && ok "P36 ①：up --print --fresh-pm 退出码 0" || bad "P36 ①：up --print --fresh-pm 失败"
assert_has "$TMP/p36-print-fresh.log" "会话判定：fresh:--fresh-pm" "P36 ①：--fresh-pm 的判定是 fresh:"
assert_not "$TMP/p36-print-fresh.log" "会话判定：continued" "P36 ①：fresh 时不再说续跑"
grep '^完整命令：' "$TMP/p36-print-fresh.log" > "$TMP/p36-cmd-fresh.log" 2>/dev/null || true
assert_not "$TMP/p36-cmd-fresh.log" " -c " "P36 ①：fresh 渲染出的命令不带 -c"
assert_has "$TMP/p36-cmd-fresh.log" "pm-prompt.md" "P36 ①：fresh 仍带 @提示词文件（只是不续会话）"
# 优先级裁断（写进 `team help` 的 up 行）：--fresh-pm 这一次最优先，两个续跑配置键都不生效
env TEAM_PM_SESSION_ID=pm-fixed TEAM_PM_RESUME_ARGS=--continue $TEAM up --print --fresh-pm >"$TMP/p36-print-prio.log" 2>&1 \
  || bad "P36 ①：带续跑配置键的 up --print --fresh-pm 失败"
grep '^完整命令：' "$TMP/p36-print-prio.log" > "$TMP/p36-cmd-prio.log" 2>/dev/null || true
assert_not "$TMP/p36-cmd-prio.log" "--session-id" "P36 ①：--fresh-pm 压过 TEAM_PM_SESSION_ID"
assert_not "$TMP/p36-print-prio.log" "--continue" "P36 ①：--fresh-pm 压过 TEAM_PM_RESUME_ARGS"
# 模板路径同一条口径（{resume_args} 这一次渲染为空）——用与 §6i 同形的渲染探针，目标固定在夹具仓库
p36_render() { # [VAR=…]… → 渲染 PM 启动命令
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c 'for _a in "$@"; do export "$_a"; done; . "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_pm_launch_cmd "$TEAM_STATE_DIR/pm-prompt.md" "$TEAM_STATE_DIR/pm.pid.spawn"' _ "$@" )
}
P36_TPL_CMD='mycli run {resume_args} {prompt}'
P36_TPL_CONT="$(p36_render "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_CMD=$P36_TPL_CMD" 'TEAM_PM_BIN=bash' 'TEAM_PM_RESUME_ARGS=--continue')"
assert_has_echo "$P36_TPL_CONT" "--continue" "P36 ①：模板路径默认把 {resume_args} 渲染出来"
P36_TPL_FRESH="$(p36_render "TEAM_PI_BIN=$FAKE/pi" "TEAM_PM_CMD=$P36_TPL_CMD" 'TEAM_PM_BIN=bash' 'TEAM_PM_RESUME_ARGS=--continue' 'TEAM_PM_FRESH_LAUNCH=1')"
assert_not_echo "$P36_TPL_FRESH" "--continue" "P36 ①：--fresh-pm 下模板路径的 {resume_args} 渲染为空"

if [ "$FAST" = "1" ]; then
  fast_skip "11b4·PM 交接（P36）" "要真实 tmux 窗口 + 假 pi 进程（--fresh-pm 真跑 / 同 cwd 活会话探测）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  # 本段专用夹具（不碰 §11b 的 pm-args.log/pi-sleep）：参数逐行落盘 + 睡着的假 PM；
  # 另一个同名不同目录的脚本只用来当「同 cwd 的另一个会话」（不写日志）。
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/p36-pm-args.log" > "$FAKE/pi-p36"
  chmod +x "$FAKE/pi-p36"
  mkdir -p "$TMP/p36-peer-bin"
  printf '#!/usr/bin/env bash\nsleep 600\n' > "$TMP/p36-peer-bin/pi-p36"
  chmod +x "$TMP/p36-peer-bin/pi-p36"
  : > "$TMP/p36-pm-args.log"
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-p36\"|" "$REPO/.pi/team/config.sh"
  P36_ROOT="$(cd "$REPO" && pwd -P)"
  p36_lines() { wc -l < "$TMP/p36-pm-args.log" 2>/dev/null | tr -d ' ' || echo 0; }
  p36_wait_args() { # <基线行数> [秒]
    local base="$1" secs="${2:-10}" i=0 ticks; ticks=$(( secs * 10 ))
    while [ "$i" -lt "$ticks" ]; do [ "$(p36_lines)" -gt "$base" ] && return 0; sleep 0.1; i=$((i + 1)); done
    return 1
  }
  p36_same_cwd_pids() { # 同 cwd 的 PM CLI pid（直接调只读探测助手；与产品同源）
    ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR bash -c \
        '. "$1/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_pm_other_sessions_in_dir "$TEAM_MAIN_ROOT"' _ "$SKILL_DIR" )
  }
  p36_quiet() { # [秒]：等到同 cwd 没有 PM CLI 进程（⑤ 反向前提）
    local secs="${1:-10}" i=0 ticks; ticks=$(( secs * 5 ))
    while [ "$i" -lt "$ticks" ]; do [ -z "$(p36_same_cwd_pids)" ] && return 0; sleep 0.2; i=$((i + 1)); done
    return 1
  }
  p36_kill_fixture() { # 只杀本段夹具（argv 里的 basename 是 pi-p36），不碰别的 pi
    ps -eo pid=,args= 2>/dev/null | awk '/pi-p36([ \t]|$)/ {print $1}' \
      | while read -r _p; do kill "$_p" 2>/dev/null || true; done
  }
  p36_log_has_flag() { grep -qxF -- "$2" "$1" 2>/dev/null; }   # 参数日志按「恰好一行」判

  # ② 真跑：--fresh-pm 这一轮的命令行没有 -c
  make_pm_idle
  P36_BASE="$(p36_lines)"
  $TEAM up --fresh-pm >"$TMP/p36-up-fresh.log" 2>&1 && ok "P36 ②：team up --fresh-pm 退出码 0" || { bad "P36 ②：team up --fresh-pm 失败"; cat "$TMP/p36-up-fresh.log"; }
  assert_has "$TMP/p36-up-fresh.log" "PM 已启动" "P36 ②：--fresh-pm 真的把 PM 拉起来了"
  assert_has "$TMP/p36-up-fresh.log" "新会话：--fresh-pm" "P36 ②：成功文案说这是新开会话"
  if p36_wait_args "$P36_BASE" 10; then ok "P36 ②：假 PM 把这一轮的参数落盘了"; else bad "P36 ②：假 PM 没把参数落盘（基线 $P36_BASE → $(p36_lines)）"; fi
  tail -n +"$((P36_BASE + 1))" "$TMP/p36-pm-args.log" > "$TMP/p36-args-fresh.log" 2>/dev/null || true
  if p36_log_has_flag "$TMP/p36-args-fresh.log" "-c"; then bad "P36 ②：--fresh-pm 的命令行里出现了 -c"; else ok "P36 ②：--fresh-pm 的命令行没有 -c"; fi
  assert_has "$TMP/p36-args-fresh.log" "pm-prompt.md" "P36 ②：提示词照旧走 @文件"
  case "$(pm_state_now)" in
    running:*) ok "P36 ②：--fresh-pm 起出的 PM 判定为 running（$(pm_state_now)）" ;;
    *)         bad "P36 ②：--fresh-pm 起出的 PM 不是 running（$(pm_state_now)）" ;;
  esac
  # ③ 对照组：不带旗标的那一轮仍然 -c（证明 ② 的「没有 -c」来自旗标，不是启动路径本来就变了）
  make_pm_idle
  P36_BASE="$(p36_lines)"
  $TEAM up >"$TMP/p36-up-cont.log" 2>&1 && ok "P36 ③：team up（默认）退出码 0" || bad "P36 ③：team up（默认）失败"
  assert_has "$TMP/p36-up-cont.log" "续跑：pi -c" "P36 ③：默认成功文案说续用 -c"
  if p36_wait_args "$P36_BASE" 10; then ok "P36 ③：假 PM 把这一轮的参数落盘了"; else bad "P36 ③：假 PM 没把参数落盘"; fi
  tail -n +"$((P36_BASE + 1))" "$TMP/p36-pm-args.log" > "$TMP/p36-args-cont.log" 2>/dev/null || true
  if p36_log_has_flag "$TMP/p36-args-cont.log" "-c"; then ok "P36 ③：默认那一轮真的带 -c（②的对照）"; else bad "P36 ③：默认那一轮没有 -c（对照失败）"; fi
  # ④ C：同 cwd 还有一个活着的 PM CLI 会话 → 提示（点名 pid + 给出 --fresh-pm 出路），但不阻断
  make_pm_idle
  ( cd "$REPO" && exec "$TMP/p36-peer-bin/pi-p36" --p36-peer ) >/dev/null 2>&1 &
  P36_PEER=$!
  P36_RDY=0
  for _i in $(seq 1 50); do
    if [ "$(readlink -f "/proc/$P36_PEER/cwd" 2>/dev/null || true)" = "$P36_ROOT" ]; then P36_RDY=1; break; fi
    sleep 0.1
  done
  assert_eq "P36 ④：夹具进程的 cwd 真的在项目根（探测的前提）" "$P36_RDY" "1"
  $TEAM up >"$TMP/p36-up-peer.log" 2>&1 && ok "P36 ④：有同 cwd 活会话时 up 退出码 0（提示不阻断）" || bad "P36 ④：有同 cwd 活会话时 up 失败"
  assert_has "$TMP/p36-up-peer.log" "检测到同目录" "P36 ④：同 cwd 有活 PM CLI 会话 → 打提示"
  assert_has "$TMP/p36-up-peer.log" "pid $P36_PEER" "P36 ④：提示点名了那个 pid"
  assert_has "$TMP/p36-up-peer.log" "--fresh-pm" "P36 ④：提示给出出路（--fresh-pm）"
  assert_has "$TMP/p36-up-peer.log" "PM 已启动" "P36 ④：提示不阻断（PM 照常启动）"
  kill "$P36_PEER" 2>/dev/null || true
  wait "$P36_PEER" 2>/dev/null || true
  # ⑤ 反向：没有同 cwd 活会话 → 不打提示（先把现场真的清干净，再断言）
  make_pm_idle
  p36_kill_fixture
  if p36_quiet 10; then ok "P36 ⑤ 前提：同 cwd 已经没有 PM CLI 进程"; else bad "P36 ⑤ 前提：同 cwd 仍有 PM CLI 进程（$(p36_same_cwd_pids | tr '\n' ' ')）"; fi
  $TEAM up >"$TMP/p36-up-nopeer.log" 2>&1 && ok "P36 ⑤：反向用例 up 退出码 0" || bad "P36 ⑤：反向用例 up 失败"
  assert_not "$TMP/p36-up-nopeer.log" "检测到同目录" "P36 ⑤：没有同 cwd 活会话时不打提示"
  assert_has "$TMP/p36-up-nopeer.log" "PM 已启动" "P36 ⑤：反向用例里 PM 照常启动"
  # 收尾：把现场还原成本段之前的样子（PM 空窗 + TEAM_PI_BIN=pi-sleep；§11c 自己还会再钉一次）
  make_pm_idle
  p36_kill_fixture
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
else
  printf '  (跳过 PM 交接的真窗口断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11c. 恢复：resume / pulse 续跑
section "11c · agent 续跑是 PM 的事（pulse 不碰）"
if [ "$FAST" = "1" ]; then
  fast_skip "11c·agent 续跑" "要真实 tmux 窗口 + 真实窗口现场（roster 区分「窗口在但 pi 已退出」）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi\"|" "$REPO/.pi/team/config.sh"
  # 让 dev 处于“有任务但 pi 已退出”的状态
  $TEAM dispatch dev T1.1 "$TASKFILE" >/dev/null 2>&1
  # M7.5：不再固定 sleep 1.5 赌 roster 已经看准 —— agent 退出后「窗口回 shell」不是瞬时事件
  # （本容器：交互 bash → ~/.bashrc 的 exec /usr/bin/zsh -l → 登录 zsh 启动 churn），
  # 而 roster 的存活判定是采样式的。有界轮询 roster 本身（最多 5s），超时就把最后看到的现场打出来。
  R_WAIT=0
  R_T0="$(date +%s)"
  while [ "$R_WAIT" -lt 20 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
  [ "$R_WAIT" -ge 20 ] && printf '    现场（有界轮询 %ss 内 roster 没看到「pi 已退出」）：窗口=[%s] pane=[%s]\n' \
    "$(( $(date +%s) - R_T0 ))" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | tr '\n' ',')" \
    "$(tmux display-message -p -t "$SESSION:dev" '#{pane_current_command}' 2>/dev/null)"
  $TEAM roster >"$TMP/roster-dead.log" 2>&1
  assert_has "$TMP/roster-dead.log" "pi 已退出" "roster 能区分「窗口在但 pi 已退出」（有界轮询，不是赌一次 sleep）"
  if $TEAM say dev "ping" >"$TMP/say-idle.log" 2>&1; then ok "agent 没在跑时 say 落收件箱并返回 0"; else bad "say 不应硬失败（应落收件箱）"; fi
  assert_has "$TMP/say-idle.log" "收件箱" "说明消息进了收件箱（而不是打进 shell）"

  # pulse 不该替 PM 做决定：跑一轮巡检，dev 仍未被续跑
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  wait_window_gone dev 5 || bad "§11c 夹具：5s 内 dev 窗口还在（「窗口仍不在」的前提没成立）"
  # F28：只读命令不许毁掉崩溃 agent 的持久记录（否则 resume 会「没东西可续」）
  EQ_STATE_BEFORE="$(state_fp)"
  $TEAM ps >"$TMP/ps-crash.log" 2>&1 || true
  $TEAM digest >"$TMP/digest-crash.log" 2>&1 || true
  $TEAM roster >/dev/null 2>&1 || true
  $TEAM paths >/dev/null 2>&1 || true
  assert_eq "读命令之后 state/ 一个字节没变（F28）" "$(state_fp)" "$EQ_STATE_BEFORE"
  assert_has "$REPO/.pi/team/state/dev.env" "task=T1.1" "崩溃 agent 的任务记录还在"
  assert_match "$TMP/digest-crash.log" "停了的 agent [0-9]" "digest 仍把崩溃 agent 算成待办"
  EQ_MODEL="$(sed -n 's/^model=//p' "$REPO/.pi/team/state/dev.env" | head -1)"
  assert_eq "死窗口释放模型槽位（RUNNING=0）" \
    "$(grep -E "^$EQ_MODEL[[:space:]]" "$TMP/ps-crash.log" | head -1 | awk '{print $2}')" "0"
  $TEAM watch --once >"$TMP/watch4.log" 2>&1 || bad "watch --once 失败"
  assert_eq "pulse 不续跑 agent（窗口仍不在）" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx dev || true)" "0"
  assert_not "$TMP/watch4.log" "续跑" "pulse 输出里没有 agent 续跑动作"

  # PM 的工具仍然可用
  $TEAM resume --dry-run >"$TMP/resume-dry.log" 2>&1
  assert_has "$TMP/resume-dry.log" "可续跑：T1.1" "resume --dry-run 能识别待续跑任务"
  $TEAM resume >"$TMP/resume.log" 2>&1 && ok "resume（PM 工具）退出码 0" || bad "resume 失败"
  assert_has "$TMP/resume.log" "续跑 dev" "resume 重新派单"
  assert_eq "resume 后 dev 窗口回来了" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx dev || true)" "1"

  # 人工一条命令也能顺手把 agent 带上（up --agents）。
  # 注：本段的假 pi（$FAKE/pi）写完参数就 exit 0，PM 根本起不来 —— `team up` 现在会如实退非 0
  # （状态就是承诺：以前它报完“启动失败”还会退 0）。这里验的是 --agents 那段把 agent 续起来。
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  $TEAM up --agents >"$TMP/up-agents.log" 2>&1 || true
  assert_has "$TMP/up-agents.log" "续跑 dev" "up --agents 才会续跑 agent"
  assert_has "$TMP/up-agents.log" "PM 启动失败" "（假 pi 秒退：up 同时也如实报了 PM 没起来）"
else
  printf '  (跳过恢复断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11d. 边界守卫（跨 session 不许打字）
section "11d · 边界守卫（跨项目/跨 session 通信必须经用户）"
if [ "$FAST" = "1" ]; then
  fast_skip "11d·边界守卫（真打字）" "要在真实 tmux 里建外部 session 并验证「拒绝打字」"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  FOREIGN="teamsmith-foreign-$$"
  tmux new-session -d -s "$FOREIGN" -n other >/dev/null 2>&1
  tmux send-keys -t "$FOREIGN:other" -l "print -r -- SENTINEL-" >/dev/null 2>&1 || true
  # 通过库函数调用（say/notify 最终都走这里）
  if TEAM_ROOT="$REPO" bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_tmux_send_text "'$FOREIGN':other" "PWNED-CROSS-PROJECT"' >"$TMP/guard.log" 2>&1; then
    bad "跨 session 打字应当被拒绝"
  else ok "跨 session 打字被拒绝"; fi
  assert_has "$TMP/guard.log" "拒绝跨 session 操作" "报错说明了拒绝原因"
  assert_has "$TMP/guard.log" "team meeting" "给出了正确的升级路径（走 meeting，PM 对 PM）"
  if tmux capture-pane -p -t "$FOREIGN:other" 2>/dev/null | grep -q "PWNED-CROSS-PROJECT"; then
    bad "文本竟然打进了别的 session"
  else ok "别的 session 里没有被打进任何东西"; fi
  # 本 session 内照常工作
  if TEAM_ROOT="$REPO" bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_tmux_send_text "'$SESSION':keep" "ok-own-session"' >/dev/null 2>&1; then
    ok "本 session 内打字不受影响"
  else team_dim "（keep 窗口不存在时跳过本 session 断言）"; fi
  # 显式关掉守卫（TEAM_GUARD_FOREIGN_TARGET=0）才允许
  if TEAM_ROOT="$REPO" TEAM_GUARD_FOREIGN_TARGET=0 bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_foreign_target_ok "'$FOREIGN':other"' >/dev/null 2>&1; then
    ok "守卫可显式关闭（TEAM_GUARD_FOREIGN_TARGET=0）"
  else bad "守卫关闭后仍被拒绝"; fi
  tmux kill-session -t "$FOREIGN" >/dev/null 2>&1 || true
else
  printf '  (跳过边界断言：没有 tmux)\n'
fi
# 派单提示词里要写明跨项目边界
assert_has "$TMP/print.log" "Cross-project boundary" "dispatch prompt states the cross-project boundary"
assert_has "$TMP/print.log" "meeting" "提示词指明了跨项目沟通走 meeting"
assert_has "$TMP/print.log" "workers do not attend" "dispatch prompt says workers do not attend meetings"

# ---------------------------------------------------------------- 11e. 跨项目会议（peer 交流，不是指令通道）
section "11e · 跨项目会议（meeting mode）"
export TEAM_MEETINGS_DIR="$TMP/meetings"
MEET_PROJ="other-$$"

if $TEAM meeting open order-api --with "$MEET_PROJ" --topic "订单接口对接" >"$TMP/mtg-noyes.log" 2>&1; then
  bad "meeting open 需要显式授权"
else ok "meeting open 无 --yes 被拒绝（写共享状态要授权）"; fi
$TEAM meeting open order-api --with "$MEET_PROJ:$SESSION" --topic "订单接口对接" --yes >"$TMP/mtg-open.log" 2>&1 \
  && ok "meeting open 成功" || { bad "meeting open 失败"; cat "$TMP/mtg-open.log"; }
assert_file "$TMP/meetings/order-api/state.env" "共享区 state.env 已写"
assert_file "$TMP/meetings/order-api/agenda.md" "共享区 agenda.md 已写"
assert_has "$TMP/meetings/order-api/agenda.md" "不产出对另一方的命令" "agenda 写明边界"

# intent 白名单：机制里没有“下令”
if $TEAM meeting say order-api --intent command "你们必须今天改完" >"$TMP/mtg-cmd.log" 2>&1; then
  bad "intent=command 应被拒绝"
else ok "intent=command 被拒绝（会议不提供下令）"; fi
assert_has "$TMP/mtg-cmd.log" "不能指挥别的 PM" "拒绝理由说明了原因"
if $TEAM meeting say order-api --intent info "[指令] 照做" >"$TMP/mtg-order.log" 2>&1; then
  bad "带 [指令] 标记的消息应被拒绝"
else ok "带 [指令]/[命令] 标记被拒绝"; fi

# 正常发言：先落盘
$TEAM meeting say order-api --intent proposal "建议 POST /orders 增加 idempotency_key（UUID，必填）" >"$TMP/mtg-say.log" 2>&1 \
  && ok "proposal 发言成功" || bad "meeting say 失败"
assert_file "$TMP/meetings/order-api/transcript/0001_$(basename "$REPO")_proposal.md" "发言写进共享区 transcript"
assert_has "$TMP/meetings/order-api/transcript/0001_"*"_proposal.md" "from: $(basename "$REPO")/pm@" "消息带身份戳（项目/PM@session）"
assert_has "$TMP/mtg-say.log" "默认关" "默认不敲门（只落盘）"

# agent 不能冒充人类下令。
# M32：探针本体单独落盘（`$M32T_PROBE`），`</dev/null` 是**探针自己的纪律** —— 断言不许依赖调用者
#   的 fd 形状。事故（2026-09-18）：PM 在 tmux 窗口里直接跑全量门禁（自然姿势 `> log 2>&1`，stdin
#   还是 pane pty）→ cmd-meeting.sh 的 `[ ! -t 0 ] && [ ! -t 1 ]` 判据看到 stdin 是 tty，改走
#   `TEAM_MEETING_ALLOW_USER_ID` 那条分支，拒绝理由里没有「冒充」→ 这里假红。
#   11e 与紧随其后的 11e2 跑的是**同一份字节**（谁把 `</dev/null` 拿掉，11e2 就红）。
#   同类自查（本仓库总共两处看 tty fd）：另一处是 common.sh:9 的配色 `[ -t 1 ]`，它只决定 ANSI 码，
#   而断言一律 grep 重定向后的文件（`team` 子进程的 stdout 是文件 → 配色本来就关），与外部形状无关；
#   其余探针不看 fd，无需 detach。
M32T_PROBE="$TMP/m32tty-as-user-probe.sh"
cat > "$M32T_PROBE" <<EOS
#!/usr/bin/env bash
# M32 探针本体：模拟「没有 tty 的 agent 进程」。形状记录写进 \$M32T_SHAPE_LOG（未设时 /dev/null），
# 11e2 用它证明夹具真的造出了「stdin=tty / stdout=文件」的外框（造不出来就红，不会假绿）。
printf 'probe_stdin_tty=%s probe_stdout_tty=%s probe_stdin=%s\n' \\
  "\$([ -t 0 ] && echo yes || echo no)" "\$([ -t 1 ] && echo yes || echo no)" \\
  "\$(readlink /proc/\$\$/fd/0 2>/dev/null || echo '?')" >> "\${M32T_SHAPE_LOG:-/dev/null}"
cd "$REPO" || exit 1
$TEAM meeting say order-api --intent info --as-user "我以用户名义下令" </dev/null
EOS
if bash "$M32T_PROBE" >"$TMP/mtg-user.log" 2>&1; then
  bad "--as-user 在 agent 里应被拒绝"
else ok "--as-user 被拒绝（agent 不得冒充用户）"; fi
assert_has "$TMP/mtg-user.log" "冒充" "拒绝理由说明了冒充"

# ---------------------------------------------------------------- 11e2. M32：探针与调用者的 fd 形状解耦
section "11e2 · M32：--as-user 探针自 detach stdin（外部 stdin=pty 也必须绿）"
# 造出与事故**逐 fd 等价**的外部形状：stdin 是真 pty（script 给的），stdout 是文件。
# 不引入 tmux（`script -qc` 就够；tmux 窗口的 stdin 也只是 pane pty）—— 所以本段快慢都跑。
# 跑的是 11e 那个探针文件本体；「形状真的成立」由探针自己记的 probe_stdin_tty/probe_stdout_tty
# 证明：夹具退化（拿不到 tty）时先红在夹具有效性上，不会让真断言假绿。
if ! command -v script >/dev/null 2>&1; then
  cond_skip "11e2·M32 tty 外框回归" "本机没有 script（util-linux），造不出 stdin=tty 的外部形状"
else
  M32T_SHAPE="$TMP/m32tty-shape.log"; M32T_TTYLOG="$TMP/m32tty-probe-tty.log"
  rm -f "$M32T_SHAPE" "$M32T_TTYLOG"
  # 外框脚本用 **quoted** heredoc + 环境传参：unquoted heredoc 会把内容里的反引号/$( ) 当真命令
  # 替换执行（M32 实测踩过：注释里写了个反引号包住的命令，冒烟自己把它跑了一遍）。
  cat > "$TMP/m32tty-outer.sh" <<'EOS'
#!/usr/bin/env bash
# 外部形状 = PM 在 tmux 窗口里跑门禁（stdin = pty，stdout = 文件；等价于 bash smoke.sh > log）。
printf 'outer_stdin_tty=%s\n' "$([ -t 0 ] && echo yes || echo no)" > "${M32T_SHAPE:?}"
M32T_SHAPE_LOG="${M32T_SHAPE:?}" bash "${M32T_PROBE:?}" >"${M32T_TTYLOG:?}" 2>&1
printf 'probe_rc=%s\n' "$?" >> "${M32T_SHAPE:?}"
EOS
  env M32T_SHAPE="$M32T_SHAPE" M32T_PROBE="$M32T_PROBE" M32T_TTYLOG="$M32T_TTYLOG" \
    script -qc "bash $TMP/m32tty-outer.sh" /dev/null >/dev/null 2>&1
  assert_has "$M32T_SHAPE" "outer_stdin_tty=yes" "M32 夹具有效性：外框的 stdin 确实是 tty（script 真给了 pty）"
  assert_has "$M32T_SHAPE" "probe_stdin_tty=yes" "M32 夹具有效性：探针继承到的 stdin 是 tty（事故形状成立）"
  assert_has "$M32T_SHAPE" "probe_stdout_tty=no" "M32 夹具有效性：探针的 stdout 是文件（与事故形状一致）"
  assert_not "$M32T_SHAPE" "probe_rc=0" "M32：tty 外框下探针仍被拒绝（外部 tty 不会把它放行）"
  assert_has "$M32T_TTYLOG" "冒充" "M32：拒绝理由仍是「冒充」版（探针自己 </dev/null，与外部 fd 解耦）"
  assert_not "$M32T_TTYLOG" "TEAM_MEETING_ALLOW_USER_ID" "M32：没有滑到「需要 TEAM_MEETING_ALLOW_USER_ID」那条分支"
fi

# 未登记的跨 session 打字仍然禁止；会议登记后才允许敲门
if TEAM_ROOT="$REPO" bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_foreign_target_ok "'$SESSION':keep"' >/dev/null 2>&1; then
  ok "本 session 目标允许"
else bad "本 session 目标不该被拒绝"; fi
if TEAM_ROOT="$REPO" bash -c '. "'$SKILL_DIR'/scripts/common.sh' >/dev/null 2>&1; then :; fi
if TEAM_ROOT="$REPO" TEAM_MEETINGS_DIR="$TMP/meetings" bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_foreign_target_ok "unregistered-session:pm"' >"$TMP/mtg-foreign.log" 2>&1; then
  bad "未登记的跨 session 目标应被拒绝"
else ok "未登记的跨 session 目标被拒绝"; fi
assert_has "$TMP/mtg-foreign.log" "拒绝跨 session" "拒绝理由明确"

# 读 / inbox / 标记已读
$TEAM meeting read order-api --peek >"$TMP/mtg-read.log" 2>&1 && ok "meeting read 成功" || bad "meeting read 失败"
assert_has "$TMP/mtg-read.log" "idempotency_key" "读到对方/自己的发言"
assert_has "$TMP/mtg-read.log" "intent: proposal" "读到 intent"
$TEAM meeting list >"$TMP/mtg-list.log" 2>&1
assert_has "$TMP/mtg-list.log" "order-api" "list 列出会议"
$TEAM meeting inbox >"$TMP/mtg-inbox.log" 2>&1
assert_has "$TMP/mtg-inbox.log" "没有待回应" "自己发的不算待我回应"

# 共识：提议 → 对方同意才生效
$TEAM meeting propose order-api "接口契约 v1：字段/错误码/超时" --sides "我方:api 侧 / 对方:订单侧" >"$TMP/mtg-prop.log" 2>&1 \
  && ok "propose 成功" || bad "propose 失败"
if $TEAM meeting agree order-api A1 >/dev/null 2>&1; then bad "不能确认自己提的共识"; else ok "自己提的共识不能自己确认"; fi
assert_eq "确认前状态 proposed" "$({ grep -c '^agreed-by:' "$TMP/meetings/order-api/agreements/A1.md" 2>/dev/null || true; } | head -1)" "0"
TEAM_PROJECT="$MEET_PROJ" TEAM_ROOT="$REPO" TEAM_MEETINGS_DIR="$TMP/meetings" \
  bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; . "'$SKILL_DIR'/scripts/lib/cmd-meeting.sh"; team_load_config; team_meeting_agree order-api A1 --note "对方落地：T5.1"' \
  >"$TMP/mtg-agree.log" 2>&1 && ok "对方（另一项目身份）确认成功" || { bad "对方确认失败"; cat "$TMP/mtg-agree.log"; }
assert_has "$TMP/meetings/order-api/agreements/A1.md" "agreed-by: $MEET_PROJ" "共识记录了对方的确认"
assert_has "$TMP/mtg-agree.log" "各自在自己项目内完成" "确认时说明落地归属"

# 轮次预算（防两个 PM 互相刷额度）
TEAM_MEETING_MAX_TURNS=1 $TEAM meeting say order-api --intent info "第二条" >"$TMP/mtg-turn.log" 2>&1 \
  && bad "超过轮次上限应被拒绝" || ok "超过轮次上限被拒绝"
assert_has "$TMP/mtg-turn.log" "发言已达上限" "轮次上限提示明确"

# close 后冻结
$TEAM meeting close order-api --summary "契约已定，双方各自落地" >"$TMP/mtg-close.log" 2>&1 \
  && ok "close 成功" || bad "close 失败"
$TEAM meeting say order-api --intent info "关了还能说吗" >"$TMP/mtg-after.log" 2>&1 \
  && bad "close 后不应允许发言" || ok "close 后 transcript 冻结（发言被拒）"
$TEAM meeting read order-api >/dev/null 2>&1 && ok "close 后仍可读（只读）" || bad "close 后应可读"
unset TEAM_MEETINGS_DIR

# ---------------------------------------------------------------- 11f. 更新分发与版本自检
section "11f · 更新与版本自检（mark-loaded / version --check / changelog）"
assert_file "$SKILL_DIR/CHANGELOG.md" "skill 带 CHANGELOG"
CODE_V="$(grep -m1 '^TEAM_VERSION=' "$SKILL_DIR/scripts/lib/common.sh" | cut -d'"' -f2)"
DOC_V="$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$SKILL_DIR/SKILL.md" | head -1)"
# P16：拆分后版本仍是单一来源（common.sh），两个 SKILL.md 都跟随；init skill 没有自己的 CHANGELOG。
INIT_V="$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$SKILL_INIT_DIR/SKILL.md" | head -1)"
LOG_V="$(sed -n 's/^##[[:space:]]*\[*v\?\([0-9.]*\)\]*.*/\1/p' "$SKILL_DIR/CHANGELOG.md" | head -1)"
# M38：根 package.json（pi 清单）也是版本落点之一——发行时的第五处。
PKG_V="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$(dirname "$SKILL_DIR")/../package.json" 2>/dev/null | head -1)"
assert_eq "版本号五处一致（common/两个 SKILL/CHANGELOG/package.json）" "$CODE_V|$DOC_V|$INIT_V|$LOG_V|$PKG_V" "$CODE_V|$CODE_V|$CODE_V|$CODE_V|$CODE_V"
# P35：README 安装示例的 pin 是第六个版本落点 —— 机制防过期，不是"发版时记得改"的承诺。
# README 里任何形式的 teamsmith@v<X.Y.Z>（git:/ssh://HTTPS 简写都在内）都必须等于 package.json 的 version；
# 不等 → 红并点名两处（README 行号 + package.json）。一处都找不到也算红（检查不许空转）。
README_MD="$(dirname "$SKILL_DIR")/../README.md"
README_PINS="$(grep -n -o 'teamsmith@v[0-9][0-9.]*' "$README_MD" 2>/dev/null || true)"
README_PIN_BAD=""
while IFS= read -r _p35; do
  [ -n "$_p35" ] || continue
  [ "${_p35##*@v}" = "$PKG_V" ] || README_PIN_BAD="$README_PIN_BAD README.md:${_p35%%:*}=@v${_p35##*@v}"
done <<< "$README_PINS"
if [ -z "$README_PINS" ]; then
  bad "README 安装 pin：$README_MD 里找不到 teamsmith@v<X.Y.Z> 示例（检查本身不许空转）"
elif [ -n "$README_PIN_BAD" ]; then
  bad "README 安装 pin 与 package.json（version=$PKG_V）不一致：$README_PIN_BAD —— 同步 README.md 这些行（发版清单见 docs/team/PUBLISH.md §2）"
else
  ok "README 安装 pin 与 package.json 一致（$(printf '%s\n' "$README_PINS" | grep -c .) 处 @v$PKG_V）"
fi
unset _p35 README_MD README_PINS README_PIN_BAD
assert_not_file "$SKILL_INIT_DIR/CHANGELOG.md" "init skill 没有 CHANGELOG（变更史只有一份）"

$TEAM mark-loaded >"$TMP/mark.log" 2>&1 && ok "mark-loaded 退出码 0" || bad "mark-loaded 失败"
assert_has "$TMP/mark.log" "$CODE_V" "mark-loaded 记录了当前版本"
assert_file "$REPO/.pi/team/state/pm-loaded.env" "版本记录写进 state"
assert_has "$REPO/.pi/team/state/pm-loaded.env" "HASH=" "记录里含内容指纹"

$TEAM version --check >"$TMP/vcheck.log" 2>&1 && ok "version --check 退出码 0" || bad "version --check 失败"
assert_has "$TMP/vcheck.log" "一致" "本会话与磁盘一致时给出「一致」"
assert_has "$TMP/vcheck.log" "CHANGELOG" "打印了 CHANGELOG 版本"

# 模拟“本会话是旧的”：提示要给出 /reload 与三条生效路径
$TEAM mark-loaded --version 1.7.0 >/dev/null 2>&1
$TEAM version --check >"$TMP/vcheck-old.log" 2>&1 || true
assert_has "$TMP/vcheck-old.log" "本会话是旧的" "旧版本会话被识别"
assert_has "$TMP/vcheck-old.log" "/reload" "提示了 /reload 生效方式"
assert_has "$TMP/vcheck-old.log" "scripts/**" "说明了 scripts 不需要刷新"
$TEAM mark-loaded >/dev/null 2>&1

$TEAM changelog >"$TMP/changelog.log" 2>&1 && assert_has "$TMP/changelog.log" "$CODE_V" "changelog 打印当前版本" || bad "changelog 失败"
$TEAM reload >"$TMP/reload-req.log" 2>&1 && assert_file "$REPO/.pi/team/state/reload-requested" "reload 写了请求标记" || bad "reload 失败"
$TEAM reload --done >/dev/null 2>&1
assert_not_file "$REPO/.pi/team/state/reload-requested" "reload --done 清掉标记"

# digest / doctor 要带版本行
$TEAM digest >"$TMP/digest-skill.log" 2>&1 || true
assert_has "$TMP/digest-skill.log" "skill " "digest 显示 skill 版本行"
$TEAM doctor >"$TMP/doctor-skill.log" 2>&1 || true
assert_match "$TMP/doctor-skill.log" "skill|teamsmith" "doctor 里能看到 skill 信息"

# ---------------------------------------------------------------- 11g. CEP 三条实测反馈
section "11g · CEP 反馈（forge-first / say 投递校验 / knock 诊断）"
# ① forge 相关的包装全部移除；git/forge 由 PM 直接用真实工具
if $TEAM gh pr list >/dev/null 2>&1; then bad "team gh 应已移除"; else ok "team gh 透传已移除"; fi
if $TEAM gl GET /projects >/dev/null 2>&1; then bad "team gl 应已移除"; else ok "team gl 透传已移除"; fi
assert_not_file "$SKILL_DIR/scripts/lib/forge.sh" "forge 包装模块已删除"

# ② say：agent 没在跑 → 落收件箱 + 明确提示（不再硬失败）
if [ "$FAST" = "1" ]; then
  fast_skip "11g②·say 离线投递" "要 tmux 窗口状态（窗口不在 → 落收件箱）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  tmux kill-window -t "$SESSION:dev" >/dev/null 2>&1 || true
  $TEAM say dev "收尾：提交这 2 个文件并 push" >"$TMP/say-offline.log" 2>&1 && ok "say 在 agent 没跑时返回 0（落收件箱）" \
    || bad "say 在 agent 没跑时不应硬失败"
  assert_has "$TMP/say-offline.log" "收件箱" "提示消息已落收件箱"
  assert_has "$REPO/docs/team/inbox/dev.md" "收尾：提交这 2 个文件并 push" "消息确实写进收件箱"
  assert_has "$TMP/say-offline.log" "resume" "推荐用 resume 让人回来读"
fi

# ③ knock 诊断 + meeting peer / knock 命令
export TEAM_MEETINGS_DIR="$TMP/meetings"
$TEAM meeting open knock-test --with "other-$$" --topic "敲门测试" --yes >/dev/null 2>&1 || true
$TEAM meeting peer knock-test "other-$$:$SESSION" >"$TMP/peer.log" 2>&1 && ok "meeting peer 登记 session" || { bad "meeting peer 失败"; cat "$TMP/peer.log"; }
assert_has "$TMP/peer.log" "已登记" "登记有回显"
$TEAM meeting say knock-test --intent info "敲门测试消息" >/dev/null 2>&1 || true
TEAM_MEETING_KNOCK=0 $TEAM meeting knock knock-test >"$TMP/knock-off.log" 2>&1 || true
assert_has "$TMP/knock-off.log" "TEAM_MEETING_KNOCK=0" "敲门被全局开关拦住时说明原因"
if [ "$FAST" = "1" ]; then
  fast_skip "11g③·敲门探测" "开门路径要用 tmux 二进制探测对方 session/pane"
else
  TEAM_MEETING_KNOCK=1 $TEAM meeting knock knock-test >"$TMP/knock-on.log" 2>&1 || true
  assert_match "$TMP/knock-on.log" "敲门排查|只落盘|已敲门" "开门时给出结论或排查清单"
fi
$TEAM meeting knock no-such-meeting >"$TMP/knock-bad.log" 2>&1 || true
assert_has "$TMP/knock-bad.log" "会议不存在" "不存在的会议给出明确报错"
unset TEAM_MEETINGS_DIR

# ---------------------------------------------------------------- 11h. 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23）
section "11h · 信号与承诺的诚实（V4.0 F4/F6/F19/F21/F23）"

# F4：push 状态必须相对 @{upstream} 量，不是相对保护分支。旧实现拿保护分支当代理：
# 分支 push 过、又被 squash 合并后，相对保护分支永远「领先 N」→ digest 永远喊「提交并 push」。
# 夹具：一个真的有 upstream 的 agent worktree（远端是本地 bare 仓，不碰网络）。
F4WT="$REPO/.worktrees/f4"
git -C "$REPO" init -q --bare "$TMP/f4-origin.git"
if git -C "$REPO" worktree add -q -b task/F4-demo "$F4WT" main >/dev/null 2>&1; then ok "F4 夹具：建一个带 upstream 的 worktree"
else bad "F4 夹具 worktree 建不起来"; fi
printf 'f4\n' > "$F4WT/f4.txt"
git -C "$F4WT" add -A >/dev/null 2>&1 && git -C "$F4WT" commit -qm "feat(F4): demo commit" >/dev/null 2>&1
git -C "$REPO" remote add f4origin "$TMP/f4-origin.git" >/dev/null 2>&1 || true
git -C "$F4WT" push -q -u f4origin task/F4-demo >/dev/null 2>&1 && ok "F4 夹具：分支已 push（@{upstream}..HEAD = 0）" || bad "F4 夹具 push 失败"
assert_eq "F4 夹具：相对 upstream 确实没有未 push 的提交" "$(git -C "$F4WT" rev-list --count '@{upstream}..HEAD' 2>/dev/null)" "0"
assert_eq "F4 夹具：相对 main 仍领先 1（旧实现正是把这个数当成未 push）" "$(git -C "$F4WT" rev-list --count main..HEAD)" "1"

# 名册只有 f4（环境变量临时覆盖名册；digest 只读，不需要 tmux）
TEAM_AGENTS=f4 $TEAM digest >"$TMP/f4-pushed.log" 2>&1 || bad "F4：digest（名册 f4）失败"
assert_not "$TMP/f4-pushed.log" "收尾：提交并 push" "F4：已 push 的分支不再被当成未收尾（旧实现会喊 push）"
assert_not "$TMP/f4-pushed.log" "未 push 1" "F4：已 push 的分支没有假的未 push 计数"
assert_has "$TMP/f4-pushed.log" "相对 upstream" "F4：digest [4] 说明自己量的是相对 upstream 的未 push"
TEAM_AGENTS=f4 $TEAM roster >"$TMP/f4-roster.log" 2>&1 || bad "F4：roster（名册 f4）失败"
assert_has "$TMP/f4-roster.log" "未push=相对 @{upstream}" "F4：roster 说明未push 相对 @{upstream}"
assert_has "$TMP/f4-roster.log" "领先=相对 main" "F4：roster 把「领先 main」与「未 push」分开说明"

# 正对照：真的多出一个没 push 的提交时必须报警（不是把信号整体静音）
printf 'more\n' >> "$F4WT/f4.txt"
git -C "$F4WT" commit -qam "feat(F4): unpushed commit" >/dev/null 2>&1
TEAM_AGENTS=f4 $TEAM digest >"$TMP/f4-unpushed.log" 2>&1 || bad "F4：digest（未 push 场景）失败"
assert_has "$TMP/f4-unpushed.log" "未 push 1（相对 @{upstream}）" "F4：真的未 push 的提交仍被列出"
assert_has "$TMP/f4-unpushed.log" "收尾：提交并 push" "F4：真的未 push 时仍给出 push 建议"
assert_has "$TMP/f4-unpushed.log" "领先 main 2" "F4：领先保护分支单独成标签（不再冒充未 push）"

# 没有 upstream 时：push 状态无法判定，不许冒充「未 push N」
git -C "$F4WT" branch --unset-upstream >/dev/null 2>&1
TEAM_AGENTS=f4 $TEAM digest >"$TMP/f4-noup.log" 2>&1 || bad "F4：digest（无 upstream 场景）失败"
assert_has "$TMP/f4-noup.log" "无 upstream（未 push 无法判定）" "F4：没有 upstream 时明说无法判定"
assert_not "$TMP/f4-noup.log" "未 push 2" "F4：没有 upstream 时不给假的未 push 计数"
assert_has "$TMP/f4-noup.log" "领先 main 2" "F4：没有 upstream 时仍能看到领先 main 多少"
git -C "$REPO" worktree remove --force "$F4WT" >/dev/null 2>&1 || true

# F6：任务 id 里可以带 '-'（API-2）。老实现用「第一个 '-' 前」当 id，于是 reports/API-2-dev.md 被
# 当成 id=API 的报告（标题对不上）→ 掉进「忽略的非任务报告」，永远不变成「待复验」。
$TEAM task API-2 --title "add the api-2 endpoint" --agent dev >"$TMP/f6-task.log" 2>&1 \
  && ok "F6 夹具：team task API-2（id 自带 '-'）" || bad "F6 夹具 team task 失败"
mkdir -p "$REPO/docs/team/reports/API-2-dev"
printf '%s\n' '# API-2 · add the api-2 endpoint' '' 'agent: dev   status: DONE' '' '## Deliverables' '' '- endpoint' \
  > "$REPO/docs/team/reports/API-2-dev.md"
printf '#!/usr/bin/env bash\necho flip\n' > "$REPO/docs/team/reports/API-2-dev/run.sh"
# 第二个夹具：文件名里有**两处** '-'（agent 名也带 '-'）——仍然属于 API-2
printf '%s\n' '# API-2 · add the api-2 endpoint' '' 'agent: dev-2   status: DONE' \
  > "$REPO/docs/team/reports/API-2-dev-2.md"
# 非任务报告的回退行为不变（P2 不在 BOARD 里 → 仍按旧启发式得到 P2，再由标题/文件名规则忽略）
printf '%s\n' '# P2 · closure' '' 'agent: pm' > "$REPO/docs/team/reports/P2-closure.md"

f6_id_of() { # <报告路径> → 实现派生出的 id（直调被验代码，不猜）
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_report_task_id "$1"' _ "$1" )
}
assert_eq "F6：API-2-dev.md 的 id 是 API-2（不是 API）" "$(f6_id_of "$REPO/docs/team/reports/API-2-dev.md")" "API-2"
assert_eq "F6：API-2-dev-2.md（stem 里两处 '-'）也是 API-2" "$(f6_id_of "$REPO/docs/team/reports/API-2-dev-2.md")" "API-2"
assert_eq "F6：非任务报告（P2-closure）仍退回旧启发式 P2" "$(f6_id_of "$REPO/docs/team/reports/P2-closure.md")" "P2"

$TEAM digest >"$TMP/f6-digest.log" 2>&1 || bad "F6：digest 失败"
assert_has "$TMP/f6-digest.log" "review API-2" "F6：待复验给出完整 id（不是 API）"
assert_eq "F6：没有残缺 id 的复验命令（review API）" "$(grep -cE 'review API$' "$TMP/f6-digest.log" || true)" "0"
assert_not "$TMP/f6-digest.log" "忽略的非任务报告：API-2-dev.md" "F6：id 带 '-' 的报告不再被判成非任务报告"
assert_not "$TMP/f6-digest.log" "忽略的非任务报告：API-2-dev-2.md" "F6：两处 '-' 的报告也不再被判成非任务报告"
assert_has "$TMP/f6-digest.log" "忽略的非任务报告：P2-closure.md" "F6：真正非任务的报告仍然被忽略（但可见）"

# F21：只读的版本自检不能因为 SIGPIPE 以 141 收尾。旧实现用 `sed … | head -14 | sed …` 打 CHANGELOG
# 摘要，head 一退出就把上游 sed 打成 141，pipefail 把它传给了调用方（`version --check && …` 把「你是旧的」当崩溃）。
$TEAM mark-loaded --version 0.0.1 >/dev/null 2>&1
$TEAM version --check >"$TMP/f21-stale.log" 2>&1; F21_RC=$?
assert_eq "F21：旧会话的 version --check 退出码 0（不是 141/SIGPIPE）" "$F21_RC" "0"
assert_has "$TMP/f21-stale.log" "本会话是旧的" "F21：仍然打印「本会话是旧的」"
assert_has "$TMP/f21-stale.log" "最新变更" "F21：旧会话仍然打印 CHANGELOG 摘要（没被半路打断）"
$TEAM mark-loaded >/dev/null 2>&1
$TEAM version --check >"$TMP/f21-fresh.log" 2>&1; F21_RC2=$?
assert_eq "F21：一致时退出码 0" "$F21_RC2" "0"

# F23：team reload 不能承诺一个不存在的 watchdog 行为。marker 的唯一消费者是 notify 扩展
# （/reload 完成后把它删掉）；脚本侧没有任何组件读它，所以「watchdog 看到 marker 会重启 PM 会话」是假承诺。
$TEAM reload >"$TMP/f23-reload.log" 2>&1 || bad "F23：team reload 失败"
assert_file "$REPO/.pi/team/state/reload-requested" "F23：reload 仍然写 marker（请求仍然留痕）"
assert_not "$TMP/f23-reload.log" "重启 PM 会话" "F23：不再承诺 watchdog 会重启 PM 会话"
assert_has "$TMP/f23-reload.log" "没有任何组件会因为 marker 重启会话" "F23：明说 marker 不会重启任何东西"
assert_has "$TMP/f23-reload.log" "/reload" "F23：给出真正生效的方式（会话内 /reload）"
F23_READERS="$(grep -rl 'reload-requested' "$SKILL_DIR/scripts" 2>/dev/null | grep -v 'cmd-update.sh' || true)"
assert_eq "F23：scripts/ 里除 cmd-update.sh 外没有组件读 marker" "${F23_READERS:-无}" "无"
assert_has "$SKILL_DIR/extension/team-notify.ts" "rmSync(marker, { force: true })" "F23：扩展侧确实只在 /reload 后清掉 marker（文案与实现一致）"
$TEAM reload --done >/dev/null 2>&1
assert_not_file "$REPO/.pi/team/state/reload-requested" "F23：reload --done 仍然能清掉 marker"

# F19：会议 TTL。旧实现：open 不校验（--ttl 0/-5/abc 原样写进 state.env），is_expired 把
# 0/负数/非数字当成「永不过期」，read 印 "/ TTL abch" —— 一次 --ttl 0 就得到永生会议。
export TEAM_MEETINGS_DIR="$TMP/meetings-f19"
F19_PEER="other-$$"
if $TEAM meeting open ttl-zero --with "$F19_PEER" --topic "ttl 0" --ttl 0 --yes >"$TMP/f19-zero.log" 2>&1; then
  bad "F19：--ttl 0 应被拒绝"
else ok "F19：--ttl 0 被拒绝（不再变成永生会议）"; fi
assert_has "$TMP/f19-zero.log" "正整数小时" "F19：拒绝理由说明必须正整数小时"
assert_not_file "$TMP/meetings-f19/ttl-zero/state.env" "F19：被拒的 ttl 没有留下会议记录"
if $TEAM meeting open ttl-neg --with "$F19_PEER" --topic "ttl -5" --ttl -5 --yes >"$TMP/f19-neg.log" 2>&1; then bad "F19：--ttl -5 应被拒绝"; else ok "F19：--ttl -5 被拒绝"; fi
if $TEAM meeting open ttl-abc --with "$F19_PEER" --topic "ttl abc" --ttl abc --yes >"$TMP/f19-abc.log" 2>&1; then bad "F19：--ttl abc 应被拒绝"; else ok "F19：--ttl abc 被拒绝"; fi
$TEAM meeting open ttl-ok --with "$F19_PEER" --topic "ttl 24" --ttl 24 --yes >"$TMP/f19-ok.log" 2>&1 && ok "F19：--ttl 24 正常开会" || bad "F19：--ttl 24 开会失败"
assert_has "$TMP/meetings-f19/ttl-ok/state.env" "TTL_HOURS=24" "F19：合法 ttl 原样登记"
$TEAM meeting read ttl-ok --peek >"$TMP/f19-read.log" 2>&1 || bad "F19：meeting read 失败"
assert_has "$TMP/f19-read.log" "TTL 24h" "F19：read 打印登记的 TTL"
$TEAM meeting open ttl-high --with "$F19_PEER" --topic "ttl high" --ttl 999999 --yes >"$TMP/f19-high.log" 2>&1 || true
assert_has "$TMP/meetings-f19/ttl-high/state.env" "TTL_HOURS=8760" "F19：过大的 ttl 被夹到一年（8760h）"
assert_has "$TMP/f19-high.log" "8760" "F19：夹住时给出告警"
# 历史遗留（手改/旧版本写的）非法登记值：不能永生，read 要打印有效值并说明
$TEAM meeting open ttl-legacy --with "$F19_PEER" --topic "legacy" --yes >/dev/null 2>&1
sed -i 's/^TTL_HOURS=.*/TTL_HOURS=abc/' "$TMP/meetings-f19/ttl-legacy/state.env"
sed -i 's/^OPENED_EPOCH=.*/OPENED_EPOCH=1000/' "$TMP/meetings-f19/ttl-legacy/state.env"
if $TEAM meeting say ttl-legacy --intent info "54 年后还能说吗" >"$TMP/f19-say.log" 2>&1; then
  bad "F19：非法 TTL 的历史会议不该永生（say 竟然成功）"
else ok "F19：非法 TTL 按默认值判定过期（say 被拒）"; fi
assert_has "$TMP/f19-say.log" "已过期" "F19：拒绝理由说明会议已过期"
$TEAM meeting read ttl-legacy --peek >"$TMP/f19-legacy-read.log" 2>&1 || true
assert_has "$TMP/f19-legacy-read.log" "TTL 72h" "F19：read 对非法登记值打印有效 TTL（72）"
assert_has "$TMP/f19-legacy-read.log" "已过期" "F19：read 同时标注已过期"
assert_has "$TMP/f19-legacy-read.log" "不会永生" "F19：read 说明登记值不可用、按默认算"
unset TEAM_MEETINGS_DIR

# ---------------------------------------------------------------- 11i. 信号诚实：草稿 vs squash 合并（M4.3 C/D）
section "11i · 信号诚实：报告草稿不指 review、squash 合并不喊 push（M4.3 C/D）"

# C 夹具（D9 事件 C 的形状）：报告只存在于 agent 工作区（未提交）—— `team review` 从分支 checkout
# 里摘录报告，所以那个信号「早于可操作」。
C43WT="$REPO/.worktrees/m43c"
C43BR="task/M43C-demo"
$TEAM task M43C --title "report draft demo" --agent dev >/dev/null 2>&1 || true
git -C "$REPO" worktree add -q -b "$C43BR" "$C43WT" main >/dev/null 2>&1 || true
mkdir -p "$C43WT/docs/team/reports"
printf '# M43C · report draft demo\n\nagent: dev   status: DONE\n\n## Deliverables\n- draft\n' > "$C43WT/docs/team/reports/M43C-dev.md"
$TEAM digest >"$TMP/m43c-draft.log" 2>&1 || bad "M4.3 C：digest（草稿）失败"
assert_has "$TMP/m43c-draft.log" "report 未提交：先等 agent 交付" "C：未提交的草稿被明确标出"
assert_not "$TMP/m43c-draft.log" "review M43C" "C：草稿不指向复验（checkout 里摘不到它）"
assert_has "$TMP/m43c-draft.log" "M43C-dev" "C：草稿仍然被列出来（不静默丢）"
git -C "$C43WT" add -A >/dev/null 2>&1 && git -C "$C43WT" commit -qm "docs(M43C): report" >/dev/null 2>&1
$TEAM digest >"$TMP/m43c-committed.log" 2>&1 || bad "M4.3 C：digest（已提交）失败"
assert_has "$TMP/m43c-committed.log" "review M43C" "C：提交后恢复指向复验（可操作）"
assert_not "$TMP/m43c-committed.log" "report 未提交" "C：已提交的报告不再标草稿"
# 清场：报告已提交会被算成「待复验」——别污染后面的巡检/看板断言
git -C "$REPO" worktree remove --force "$C43WT" >/dev/null 2>&1 || true
git -C "$REPO" branch -D "$C43BR" >/dev/null 2>&1 || true
$TEAM board set M43C dropped >/dev/null 2>&1 || true

# D 夹具（D9 事件 D）：PM 用 squash 把任务分支合进保护分支（local 模式的常规路径）——
# 分支还带着原提交，于是「领先 N」与「收尾：提交并 push」会永久留着噪音。
D43WT="$REPO/.worktrees/m43d"
D43BR="task/M43D-demo"
git -C "$REPO" worktree add -q -b "$D43BR" "$D43WT" main >/dev/null 2>&1 || true
printf 'd43\n' > "$D43WT/m43d.txt"
git -C "$D43WT" add -A >/dev/null 2>&1 && git -C "$D43WT" commit -qm "feat(M43D): demo" >/dev/null 2>&1
# M9.7：不再「跑一次 digest 就断言」——实测（V3：约 1/8 次全量）出现过一次瞬时失败：D 夹具成功合并，
# digest 仍走「领先 main 1」分支，重跑即绿。等的是**digest 认出来**这个条件（输出里出现期望行），
# 有界轮询；超过 deadline 打印决定性证据，再由下面的断言报红（瞬时失败不再假红，真失败仍红且带证据）。
d43_digest_until() { # <期望子串> <日志> [最多等秒] → 0=出现了；尝试次数在 D43_TRIES
  local needle="$1" log="$2" secs="${3:-10}" i=0 ticks
  ticks=$(( secs * 4 ))
  D43_TRIES=0
  while [ "$i" -lt "$ticks" ]; do
    TEAM_AGENTS=m43d $TEAM digest >"$log" 2>&1 || bad "M4.3 D：digest 失败"
    D43_TRIES=$((D43_TRIES + 1))
    grep -qF "$needle" "$log" && return 0
    sleep 0.25
    i=$((i + 1))
  done
  return 1
}
d43_digest_until "领先 main 1" "$TMP/m43d-before.log" \
  || bad "D：合并前的 digest 没报「领先 main 1」（跑了 $D43_TRIES 次；看 $TMP/m43d-before.log）"
assert_has "$TMP/m43d-before.log" "领先 main 1" "D：未合并的分支照旧报「领先 main N」"
assert_not "$TMP/m43d-before.log" "已合并（squash" "D：未合并的分支不会被说成已合并"
if git -C "$REPO" merge --squash "$D43BR" >/dev/null 2>&1 && git -C "$REPO" commit -qm "M43D: demo (squash)" >/dev/null 2>&1; then
  ok "D 夹具：squash 合并进 main（PM 的常规路径）"
else bad "D 夹具：squash 合并失败"; fi
if d43_digest_until "已合并（squash，内容一致）" "$TMP/m43d-after.log"; then
  [ "$D43_TRIES" -gt 1 ] && printf '  \033[33mℹ\033[0m M4.3 D：digest 第 %s 次才认出 squash 合并（前 %s 次的输出不含该行；最后一次见 %s）\n' \
    "$D43_TRIES" "$((D43_TRIES - 1))" "$TMP/m43d-after.log"
else
  printf '  \033[33mℹ\033[0m M4.3 D：%s 次 digest、10s 内始终没认出 squash 合并。决定性证据：\n' "$D43_TRIES"
  printf '      分支 tip tree = %s\n' "$(git -C "$D43WT" rev-parse 'HEAD^{tree}' 2>&1 | tr '\n' ' ')"
  printf '      main 最近 3 个 tree = %s\n' "$(git -C "$D43WT" log --format=%T --max-count=3 main 2>&1 | tr '\n' ' ')"
  printf '      分支 dirty = [%s]；main=%s；digest 里的 m43d 行：\n' \
    "$(git -C "$D43WT" status --porcelain 2>&1 | tr '\n' ' ')" \
    "$(git -C "$D43WT" rev-parse --short main 2>&1)"
  grep -aF 'm43d' "$TMP/m43d-after.log" | sed 's/^/      /' || true
fi
assert_has "$TMP/m43d-after.log" "已合并（squash，内容一致）" "D：squash 合并后被认出来（内容一致）"
assert_has "$TMP/m43d-after.log" "无需 push" "D：不再暗示要 push（内容已在保护分支）"
assert_not "$TMP/m43d-after.log" "收尾：提交并 push" "D：不再给出「收尾：提交并 push」"
assert_not "$TMP/m43d-after.log" "领先 main 1" "D：不再把已合并的分支报成待收尾的领先"
TEAM_AGENTS=m43d $TEAM roster >"$TMP/m43d-roster.log" 2>&1 || bad "M4.3 D：roster 失败"
# M9.7：旧断言是 assert_has "已合并" —— 而 roster 的**说明行**（「已合并=squash 后的内容已在 main 里」）
# 永远含这三个字，等于恒真（V3 复验时正是这个假守卫让 digest 的失败看起来自相矛盾）。改成认 m43d 那一行。
assert_match "$TMP/m43d-roster.log" "^m43d.*已合并" "D：roster 把 squash 合并与真领先分开显示"
# 正对照：分支上再落一个无关提交 → 回到诚实的「领先 N」（没把信号整体静音）
printf 'more\n' >> "$D43WT/m43d.txt"
git -C "$D43WT" commit -qam "feat(M43D): more" >/dev/null 2>&1
d43_digest_until "领先 main 2" "$TMP/m43d-extra.log" \
  || bad "D：分支又领先时 digest 没回到「领先 main 2」（跑了 $D43_TRIES 次；看 $TMP/m43d-extra.log）"
assert_has "$TMP/m43d-extra.log" "领先 main 2" "D：分支又有内容时回到「领先 N」"
assert_not "$TMP/m43d-extra.log" "已合并（squash" "D：tree 不同时不再说已合并"
git -C "$REPO" worktree remove --force "$D43WT" >/dev/null 2>&1 || true
git -C "$REPO" branch -D "$D43BR" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 14b. 文档一致性（防回退）
# ---------------------------------------------------------------- 11j · pulse 改名（D22）：别名期兼容
section "11j · pulse 改名与别名期兼容（D22）"
# 改名期的唯一硬规则：绝不能让两个巡检并存（state 文件名为此保持不动，见 P7 design §3.4）。
# 本段钉死：① 旧命令名是别名（stdout 首行弃用提示 + 其余输出 = pulse 实现）；
#           ② TEAM_PULSE_* ＞ TEAM_WATCH_* ＞ 默认 的单点优先级，旧变量生效必被点名；
#           ③ 迁移夹具（旧配置 / 旧窗口名）升级后新旧两条路都工作；④ state 文件名不动。
P8_DEP='[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）'

# help：主表面是 pulse，旧名带弃用标注
$TEAM help >"$TMP/p8-help.log" 2>&1 || bad "team help 失败"
assert_has "$TMP/p8-help.log" "pulse up|down|restart|status|logs" "help 的主表面是 pulse"
assert_has "$TMP/p8-help.log" "弃用" "help 标注旧命令名已弃用"

# ① 别名：首行弃用提示；pulse 自身不印；其余输出 = pulse 实现
$TEAM pulse status >"$TMP/p8-new-status.log" 2>&1 && ok "pulse status 退出码 0" || bad "pulse status 失败"
head -1 "$TMP/p8-new-status.log" | grep -qF "$P8_DEP" \
  && bad "pulse status 不该印弃用行" || ok "pulse status 不印弃用行（内部路径直达实现）"
for p8alias in watchdog-status "watchdog status" "watchdog"; do
  $TEAM $p8alias >"$TMP/p8-alias.log" 2>&1 && ok "\`$p8alias\` 退出码 0" || bad "\`$p8alias\` 失败"
  assert_eq "\`$p8alias\` stdout 首行是弃用提示" "$(head -1 "$TMP/p8-alias.log")" "$P8_DEP"
  # 其余输出 = pulse status 的输出（容量行是活体内存读数，比对前抹掉）
  if diff <(tail -n +2 "$TMP/p8-alias.log" | grep -v 'RAM 可用') \
          <(grep -v 'RAM 可用' "$TMP/p8-new-status.log") >/dev/null 2>&1; then
    ok "\`$p8alias\` 其余输出与 pulse status 一致"
  else
    bad "\`$p8alias\` 与 pulse status 输出不一致：$(diff <(tail -n +2 "$TMP/p8-alias.log" | grep -v 'RAM 可用') <(grep -v 'RAM 可用' "$TMP/p8-new-status.log") | head -4 | tr '\n' ' ')"
  fi
done
for p8alias in install-watchdog uninstall-watchdog; do
  $TEAM $p8alias --print >"$TMP/p8-alias.log" 2>&1 && ok "\`$p8alias --print\` 退出码 0" || bad "\`$p8alias --print\` 失败"
  assert_eq "\`$p8alias --print\` stdout 首行是弃用提示" "$(head -1 "$TMP/p8-alias.log")" "$P8_DEP"
done

# ② 优先级夹具：配置里 TEAM_PULSE_INTERVAL 未设（= spec 场景的前提），env 控制新旧变量
P8E="$TMP/p8-env-repo"; mkdir -p "$P8E"
( cd "$P8E" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && git commit -q --allow-empty -m init ) >/dev/null 2>&1
( cd "$P8E" && $TEAM init --session "p8-env-$$" --agents dev ) >"$TMP/p8-env-init.log" 2>&1 \
  || bad "P8 env 夹具 init 失败（见 $TMP/p8-env-init.log）"
sed -i '/^TEAM_PULSE_INTERVAL=/d' "$P8E/.pi/team/config.sh"
( cd "$P8E" && TEAM_WATCH_INTERVAL=17 $TEAM pulse status ) >"$TMP/p8-e1.log" 2>&1 || true
assert_has "$TMP/p8-e1.log" "17s" "TEAM_PULSE 未设时 TEAM_WATCH_INTERVAL=17 生效"
assert_has "$TMP/p8-e1.log" "TEAM_WATCH_INTERVAL" "并点名旧变量"
( cd "$P8E" && TEAM_WATCH_INTERVAL=17 $TEAM pulse up --print ) >"$TMP/p8-e1p.log" 2>&1 || true
assert_has "$TMP/p8-e1p.log" "17s" "--print 同样尊重旧变量兜底"
assert_has "$TMP/p8-e1p.log" "TEAM_WATCH_INTERVAL" "--print 说明实际来源"
( cd "$P8E" && TEAM_PULSE_INTERVAL=11 TEAM_WATCH_INTERVAL=17 $TEAM pulse status ) >"$TMP/p8-e2.log" 2>&1 || true
assert_has "$TMP/p8-e2.log" "11s" "TEAM_PULSE_INTERVAL 赢过 TEAM_WATCH_INTERVAL"
assert_not "$TMP/p8-e2.log" "TEAM_WATCH_INTERVAL" "新变量生效时不点名旧变量"
# doctor：后端叫 pulse，且点名生效中的旧变量
( cd "$P8E" && TEAM_WATCH_INTERVAL=17 $TEAM doctor ) >"$TMP/p8-doctor.log" 2>&1 || true
assert_has "$TMP/p8-doctor.log" "巡检（pulse）" "doctor 的后端名叫 pulse"
assert_has "$TMP/p8-doctor.log" "TEAM_WATCH_INTERVAL=17" "doctor 点名生效中的旧变量"
# paths：暴露解析后的窗口名与巡检周期
$TEAM paths >"$TMP/p8-paths.log" 2>&1 || bad "paths 失败"
assert_has "$TMP/p8-paths.log" '"pulse_window"' "paths 有 pulse_window 键"
assert_has "$TMP/p8-paths.log" '"pulse_interval"' "paths 有 pulse_interval 键"
assert_has "$TMP/p8-paths.log" '"pulse_window": "pulse"' "paths 解析出新窗口名"
( cd "$P8E" && TEAM_WATCH_INTERVAL=17 $TEAM paths ) >"$TMP/p8-paths2.log" 2>&1 || true
assert_has "$TMP/p8-paths2.log" '"pulse_interval": "17"' "paths 的 pulse_interval 走同一优先级"

# ④ state 文件名别名期不动（两个巡检并存是改名期唯一不能发生的事）
( cd "$P8E" && $TEAM watch --once ) >"$TMP/p8-once.log" 2>&1 || true
assert_file "$P8E/.pi/team/state/watchdog.last" "别名期仍写 state/watchdog.last"
assert_file "$P8E/.pi/team/state/capacity.log" "巡检仍写 state/capacity.log"
assert_eq "别名期不产生任何 state/pulse.*" \
  "$(find "$P8E/.pi/team/state" -maxdepth 1 -name 'pulse.*' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ⑤ [real] 迁移夹具：旧窗口名还在跑 → 绝不双开；restart 换名后恰好一个 pulse 窗口
if [ "$FAST" = "1" ]; then
  if fast_skip "11j·pulse 迁移夹具" "要真 tmux 窗口（旧窗口名迁移 + watch 循环锁）"; then :; fi
elif [ "${HAVE_TMUX:-0}" = "1" ]; then
  live_mark
  # 同一把锁（state/watchdog.pid）：两个 watch 循环必须拒开第二个
  # （exec 让 $! 就是巡检进程本身；等锁就位再派第二个——加载慢的机器上睡定长是竞态；
  #   timeout 兜底：锁若回潮，红的是断言而不是整条冒烟挂死）
  ( cd "$P8E" && exec $TEAM watch --interval 3600 ) >"$TMP/p8-loop1.log" 2>&1 &
  P8_LOOP1=$!
  P8_LOCKPID=""
  for _ in $(seq 1 40); do
    P8_LOCKPID="$(cat "$P8E/.pi/team/state/watchdog.pid" 2>/dev/null || true)"
    [ -n "$P8_LOCKPID" ] && kill -0 "$P8_LOCKPID" 2>/dev/null && break
    kill -0 "$P8_LOOP1" 2>/dev/null || break
    sleep 0.25
  done
  if ! { [ -n "$P8_LOCKPID" ] && kill -0 "$P8_LOCKPID" 2>/dev/null; }; then
    bad "P8 锁测试：第一个 watch 循环 10s 内没握住锁（见 $TMP/p8-loop1.log）"
  fi
  ( cd "$P8E" && timeout 30 $TEAM watch --interval 3600 ) >"$TMP/p8-loop2.log" 2>&1
  P8_RC2=$?
  kill "$P8_LOOP1" 2>/dev/null || true
  for _ in $(seq 1 20); do kill -0 "$P8_LOOP1" 2>/dev/null || break; sleep 0.25; done
  kill -9 "$P8_LOOP1" 2>/dev/null || true; wait "$P8_LOOP1" 2>/dev/null || true
  if kill -0 "$P8_LOOP1" 2>/dev/null; then bad "P8 锁测试：watch 循环 TERM+5s 后仍未退出"; else ok "watch 循环被 TERM 收掉（trap 不再吞信号）"; fi
  assert_eq "第二个 watch 循环被拒（同一把 watchdog.pid 锁）" "$P8_RC2" "1"
  assert_has "$TMP/p8-loop2.log" "巡检已在运行" "拒绝说明点名已在运行的 pid"

  # 形状 A：旧配置（窗口解析名仍是 watchdog）—— 命令照旧打在旧窗口上
  P8A="$TMP/p8-migA-repo"; mkdir -p "$P8A"
  ( cd "$P8A" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && git commit -q --allow-empty -m init ) >/dev/null 2>&1
  ( cd "$P8A" && $TEAM init --session "p8-migA-$$" --agents dev ) >"$TMP/p8-migA-init.log" 2>&1 \
    || bad "P8 迁移夹具 A init 失败（见 $TMP/p8-migA-init.log）"
  sed -i 's/^TEAM_PULSE_WINDOW="pulse"/TEAM_WATCH_WINDOW="watchdog"/' "$P8A/.pi/team/config.sh"
  ( cd "$P8A" && $TEAM pulse up ) >"$TMP/p8-a-up.log" 2>&1 || { bad "夹具 A pulse up 失败"; cat "$TMP/p8-a-up.log"; }
  assert_eq "夹具 A：旧配置的项目窗口名保持 watchdog" \
    "$(tmux list-windows -t "p8-migA-$$" -F '#{window_name}' 2>/dev/null | grep -cx watchdog || true)" "1"
  ( cd "$P8A" && $TEAM watchdog status ) >"$TMP/p8-a-alias.log" 2>&1
  assert_eq "夹具 A：旧命令名 stdout 首行是弃用提示" "$(head -1 "$TMP/p8-a-alias.log")" "$P8_DEP"
  assert_has "$TMP/p8-a-alias.log" "tmux 窗口 p8-migA-$$:watchdog 在跑" "夹具 A：旧命令名看到旧窗口后端"
  ( cd "$P8A" && $TEAM pulse down ) >/dev/null 2>&1 || true
  assert_eq "夹具 A：pulse down 关掉旧名窗口" \
    "$(tmux list-windows -t "p8-migA-$$" -F '#{window_name}' 2>/dev/null | grep -cx watchdog || true)" "0"
  tmux kill-session -t "p8-migA-$$" 2>/dev/null || true

  # 形状 B：窗口解析名已是 pulse，但旧名窗口还在跑（升级前的进程）
  P8B="$TMP/p8-migB-repo"; mkdir -p "$P8B"
  ( cd "$P8B" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && git commit -q --allow-empty -m init ) >/dev/null 2>&1
  ( cd "$P8B" && $TEAM init --session "p8-migB-$$" --agents dev ) >"$TMP/p8-migB-init.log" 2>&1 \
    || bad "P8 迁移夹具 B init 失败（见 $TMP/p8-migB-init.log）"
  tmux new-session -d -s "p8-migB-$$" -n pm -x 200 -y 50
  tmux new-window -t "p8-migB-$$" -n watchdog -d -- bash -c 'while :; do sleep 5; done'
  sleep 0.3
  ( cd "$P8B" && $TEAM pulse status ) >"$TMP/p8-b-status.log" 2>&1
  assert_has "$TMP/p8-b-status.log" "旧窗口 p8-migB-$$:watchdog 仍在跑" "夹具 B：status 认出旧窗口后端"
  assert_has "$TMP/p8-b-status.log" "team pulse restart" "夹具 B：status 指 restart 迁移"
  ( cd "$P8B" && $TEAM pulse up ) >"$TMP/p8-b-up.log" 2>&1
  assert_has "$TMP/p8-b-up.log" "team pulse restart" "夹具 B：up 指 restart（不另起窗口）"
  assert_eq "夹具 B：up 绝不开第二个巡检（没有 pulse 窗口）" \
    "$(tmux list-windows -t "p8-migB-$$" -F '#{window_name}' 2>/dev/null | grep -cx pulse || true)" "0"
  ( cd "$P8B" && $TEAM pulse logs ) >"$TMP/p8-b-logs.log" 2>&1 \
    && ok "夹具 B：pulse logs 对旧名窗口也能看（迁移前它也是后端）" || bad "夹具 B：pulse logs 失败"
  ( cd "$P8B" && $TEAM pulse restart ) >"$TMP/p8-b-restart.log" 2>&1 || { bad "夹具 B pulse restart 失败"; cat "$TMP/p8-b-restart.log"; }
  sleep 1
  P8B_WINS="$(tmux list-windows -t "p8-migB-$$" -F '#{window_name}' 2>/dev/null)"
  assert_eq "夹具 B：restart 后恰好一个巡检窗口" "$(printf '%s\n' "$P8B_WINS" | grep -cxc pulse || true)" "1"
  assert_eq "夹具 B：旧名窗口已收" "$(printf '%s\n' "$P8B_WINS" | grep -cxc watchdog || true)" "0"
  ( cd "$P8B" && $TEAM watchdog down ) >"$TMP/p8-b-down.log" 2>&1
  assert_eq "夹具 B：旧命令 down 首行弃用提示" "$(head -1 "$TMP/p8-b-down.log")" "$P8_DEP"
  assert_eq "夹具 B：旧命令 down 两个名字都收（pulse 窗口也没了）" \
    "$(tmux list-windows -t "p8-migB-$$" -F '#{window_name}' 2>/dev/null | grep -Ec '^(pulse|watchdog)$' || true)" "0"
  tmux kill-session -t "p8-migB-$$" 2>/dev/null || true
else
  printf '  \033[2m·\033[0m %s\n' "（无 tmux：跳过 pulse 迁移夹具与 watch 循环锁）"
fi

section "14b · 文档一致性：已删命令不得回潮（词边界 + 扫描范围 + 翻转自测）"

# 扫描范围：读者会照着敲的地方（SKILL.md / references / templates / README / scripts）。
# 故意不扫：tests（断言字符串）、CHANGELOG（历史记录）、docs/**（历史决策与回复）。
# 判据用**词边界**（不是尾随空格）：team  merge / team(TAB)merge / `team gh` 都要抓到。
doc_stale_hits() { # <skill 目录>
  local d="$1" out="" extra
  for extra in "$d/SKILL.md" "$d/references" "$d/templates" "$d/scripts" "$d/README.md" "$d/../README.md" "$d/../../README.md"; do
    [ -e "$extra" ] || continue
    out="$out$(grep -rEn --include='*.md' --include='*.tmpl' --include='*.sh' --include='team' \
        '(^|[^[:alnum:]_-])team[[:space:]]+(merge|pr|gh|gl)([^[:alnum:]_-]|$)' "$extra" 2>/dev/null || true)
"
  done
  # 说明句豁免要**精确**：同一行里既有删除词、命令又用反引号包着（例如 "`team merge` 已删"）。
  # 不做整行豁免 —— 否则同行里的真残留会被一起吞掉（V1.1 实测的第 7 类漏报）。
  # M7.1 补上英文删除词：references/** 自 v1.16.0 起 English-first，迁移指南必须能**如实记载删了什么**
  #   （否则英文文档为了过这条检查只能用中文豁免词，豁免就成了特例）。判据不变：同行还要有反引号；
  #   双向翻转自测在本段末尾（inject_expect_clean 正向 / inject_and_expect 反向），防止豁免变成整行豁免。
  printf '%s\n' "$out" | grep -v '^$' | while IFS= read -r line; do
    case "$line" in
      *已删*|*已移除*|*不再*|*废弃*|*历史*|*removed*|*removal*|*deleted*|*renamed*|*legacy*|*"no longer"*)
        case "$line" in *'`'*) continue ;; *) printf '%s\n' "$line" ;; esac ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
}

# P16：扫描范围是两个 skill 的读者面（拆分前只有日常 skill）。
REAL_HITS="$(doc_stale_hits "$SKILL_DIR"; doc_stale_hits "$SKILL_INIT_DIR")"
if [ -n "$REAL_HITS" ]; then
  bad "真树里有已删命令的用法：$(printf '%s' "$REAL_HITS" | head -1)"
else
  ok "真树无残留（词边界口径：team merge|pr|gh|gl）"
fi

# 翻转自测（关键）：往 skill 的沙箱副本里注入变体，检查器**必须**报红。
# 没有这一步，"无残留 ✓" 可能只是检查器太弱（V1.1 实测：旧口径漏掉 8 类写法，真树假绿）。
SANDBOX="$TMP/docsandbox"; rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"
cp -r "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references "$SKILL_DIR"/templates "$SKILL_DIR"/scripts "$SANDBOX/" 2>/dev/null || true
# P16：init skill 的扫描面单独一个沙箱（目录形状不同：没有 scripts/），用它证明 init 侧扫描非空跑。
SANDBOX_INIT="$TMP/docsandbox-init"; rm -rf "$SANDBOX_INIT"; mkdir -p "$SANDBOX_INIT"
cp -r "$SKILL_INIT_DIR"/SKILL.md "$SKILL_INIT_DIR"/references "$SKILL_INIT_DIR"/templates "$SANDBOX_INIT/" 2>/dev/null || true
printf '# README\n' > "$TMP/README.md"
inject_and_expect() { # <说明> <相对文件> <追加内容>
  local what="$1" file="$2" text="$3" got
  rm -rf "$SANDBOX-x"; cp -r "$SANDBOX" "$SANDBOX-x"
  printf '%s\n' "$text" >> "$SANDBOX-x/$file"
  got="$(doc_stale_hits "$SANDBOX-x")"
  [ -n "$got" ] && ok "翻转自测：$what 会被抓到" || bad "翻转自测：$what 竟然漏报（检查器太弱）"
}
inject_and_expect "双空格（team  merge）" "references/protocol.md" '用 team  merge 合并'
inject_and_expect "制表符（team⇥pr）" "references/protocol.md" "$(printf '用 team\tpr 开 MR')"
inject_and_expect "反引号紧贴（\`team gh\`）" "templates/PROTOCOL.md.tmpl" '用 `team gh` 开 PR'
inject_and_expect "行尾裸命令（$ team pr）" "references/workflows.md" '$ team pr'
inject_and_expect "同行既有删除词又有真用法" "SKILL.md" '已删的写法里还有 team gl GET /projects'
rm -rf "$SANDBOX-x"

# M7.1：英文说明句豁免必须**双向**成立 —— 正向：英文迁移说明（删除词 + 反引号）不得误报；
#   反向：把已删命令当用法教（没有删除词 / 有删除词但没反引号）必须报红。
#   没有正向这一条，"真树无残留 ✓" 可能在英文文档上只是靠中文豁免词侥幸；
#   没有反向这一条，豁免就可能退化成"整行豁免"（V1.1 第 7 类漏报）。
inject_expect_clean() { # <说明> <相对文件> <追加内容>：断言**不**报红
  local what="$1" file="$2" text="$3" got
  rm -rf "$SANDBOX-x"; cp -r "$SANDBOX" "$SANDBOX-x"
  printf '%s\n' "$text" >> "$SANDBOX-x/$file"
  got="$(doc_stale_hits "$SANDBOX-x")"
  [ -z "$got" ] && ok "翻转自测：$what 不误报（说明句豁免有效）" || bad "翻转自测：$what 被误报：$(printf '%s' "$got" | head -1)"
}
inject_expect_clean "英文迁移说明（removed + 反引号）" "references/migration.md" \
  '- `team merge` was removed in v1.11.0; the PM runs git directly instead.'
inject_and_expect "英文里把已删命令当用法教（没有删除词）" "references/migration.md" \
  'Then reopen it with `team gh` pr view 12.'
inject_and_expect "英文删除词但没有反引号（不许整行豁免）" "references/migration.md" \
  'We removed team gl in v1.11.0; call glab yourself.'
rm -rf "$SANDBOX-x"
CLEAN_HITS="$(doc_stale_hits "$SANDBOX")"
[ -z "$CLEAN_HITS" ] && ok "翻转自测：干净副本不误报（正对照）" || bad "干净副本被误报：$(printf '%s' "$CLEAN_HITS" | head -1)"
# P16：init skill 侧的扫描也必须非空跑 —— 往它的副本里注入一条已删命令的真用法，必须报红。
P16_SB_INIT="$SANDBOX_INIT-x"; rm -rf "$P16_SB_INIT"; cp -r "$SANDBOX_INIT" "$P16_SB_INIT"
printf '%s\n' 'Then open the MR with `team gh` pr view 12.' >> "$P16_SB_INIT/references/bootstrap.md"
P16_INIT_HITS="$(doc_stale_hits "$P16_SB_INIT")"
[ -n "$P16_INIT_HITS" ] && ok "翻转自测：init skill 副本里的已删命令会被抓到" \
  || bad "翻转自测：init skill 的扫描漏报（范围扩了但没人证明它工作）"
[ -z "$(doc_stale_hits "$SANDBOX_INIT")" ] && ok "翻转自测：init skill 干净副本不误报" \
  || bad "init skill 干净副本被误报：$(doc_stale_hits "$SANDBOX_INIT" | head -1)"
rm -rf "$P16_SB_INIT"

# 依赖收窄不变量（v1.12.0）：文档/模板里不得再把容器后端或 forge CLI 当依赖。
# M28 细化：这条不变量管的是「**产品**不得以容器为后端」，而 tmux 接触型**测试**在容器里跑是用户
# 拍板的纪律（tests/container-tmux.sh）。所以把「提到测试 harness」的行从豁免里单独放行，
# 同时用双向夹具钉住它：讲产品依赖容器要报红，讲测试 harness 不报（否则文档只能绕着 podman 写）。
# M58 同理：**性能套件**（`tests/` 里那个，前门 `team perf`）的参考环境就是钉死门禁镜像 ——
# 它是测试 harness，不是产品后端；命中 perf 套件的行同样按 harness 放行（豁免仍然**逐行**，
# 产品语境里的 podman/--container 照旧报红，双向夹具在下面）。
dep_scope_hits() { # <skill 目录> <init 目录>
  grep -rniE 'podman|\-\-container|看门狗容器|Containerfile' "$1/SKILL.md" "$1/references" "$1/templates" \
      "$2/SKILL.md" "$2/references" "$2/templates" 2>/dev/null \
    | grep -vE '不再需要|不再有|已移除|v1\.12' \
    | grep -vE 'container-tmux\.sh|team perf|perf[.]sh|TEAM_PERF|性能套件' || true
}
DEP_HITS="$(dep_scope_hits "$SKILL_DIR" "$SKILL_INIT_DIR")"
if [ -n "$DEP_HITS" ]; then bad "文档还在把容器当依赖：$(printf '%s' "$DEP_HITS" | head -1)"; else ok "文档不再把容器当前提（只有一个后端）"; fi
# 双向夹具（M28）：① 讲产品依赖容器 → 必红；② 讲测试 harness 的容器跑法 → 不报。
if [ -d "$SANDBOX" ]; then
  DEP_SB="$SANDBOX-dep"; rm -rf "$DEP_SB"; cp -r "$SANDBOX" "$DEP_SB"
  printf '%s\n' 'The pulse daemon now runs inside a podman container on every host.' >> "$DEP_SB/references/philosophy.md"
  [ -n "$(dep_scope_hits "$DEP_SB" "$SKILL_INIT_DIR")" ] && ok "翻转自测：文档讲「产品跑在容器里」会被抓到" \
    || bad "翻转自测：产品依赖容器的表述竟然漏报（检查器太弱）"
  rm -rf "$DEP_SB"; cp -r "$SANDBOX" "$DEP_SB"
  printf '%s\n' 'The tmux-touching tests run inside a container through tests/container-tmux.sh (podman runtime, optional).' \
    >> "$DEP_SB/references/troubleshooting.md"
  [ -z "$(dep_scope_hits "$DEP_SB" "$SKILL_INIT_DIR")" ] && ok "翻转自测：文档讲「测试 harness 用容器」不误报（M28 新纪律不被旧不变量拦住）" \
    || bad "翻转自测：测试 harness 的容器说明被误报：$(dep_scope_hits "$DEP_SB" "$SKILL_INIT_DIR" | head -1)"
  # M58 双向：① 讲**性能套件**在参考镜像里跑 → 放行（它也是测试 harness）；
  #          ② 同一个词写在**产品**语境（不带 perf 标记）→ 照旧报红（豁免逐行，不整文件放行）。
  rm -rf "$DEP_SB"; cp -r "$SANDBOX" "$DEP_SB"
  printf '%s\n' 'Run team perf --container to judge the panel red lines inside the pinned image.' >> "$DEP_SB/references/workflows.md"
  printf '%s\n' 'The console backend runs in a podman container on every host.' >> "$DEP_SB/references/workflows.md"
  DEP_SB_HITS="$(dep_scope_hits "$DEP_SB" "$SKILL_INIT_DIR")"
  if printf '%s' "$DEP_SB_HITS" | grep -q 'console backend' && ! printf '%s' "$DEP_SB_HITS" | grep -q 'team perf'; then
    ok "翻转自测：M58 — 性能套件的参考镜像说明放行、产品语境的 podman 照旧报红（豁免逐行）"
  else
    bad "翻转自测：M58 豁免双向夹具不成立（$(printf '%s' "$DEP_SB_HITS" | head -2 | tr '\n' ';')）"
  fi
  rm -rf "$DEP_SB"
fi
FORGE_HITS="$(grep -rniE '缺 (gh|glab)|TEAM_VCS=github 但|gh wrapper' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" "$SKILL_DIR/scripts" "$SKILL_INIT_DIR/SKILL.md" "$SKILL_INIT_DIR/references" "$SKILL_INIT_DIR/templates" 2>/dev/null || true)"
if [ -n "$FORGE_HITS" ]; then bad "还有把 forge CLI 当依赖的表述：$(printf '%s' "$FORGE_HITS" | head -1)"; else ok "forge 完全解耦（不探测/不调用/不读 token）"; fi
# 派单提示词不得再教已删命令（v1.11 的团队 pr 曾残留在这里）
$TEAM dispatch dev T1.1 "$REPO/docs/team/tasks/T1.1-smoke.md" --print >"$TMP/prompt-forge.log" 2>&1 || true
if grep -qE 'team pr |\$cli pr ' "$TMP/prompt-forge.log" 2>/dev/null; then
  bad "派单提示词还在教已删的 team pr"
else
  ok "派单交付步骤与 forge 无关（不出现 team pr）"
fi
# 名字一致性不变量（v1.13.0 改名后）：文档/脚本里不得再出现旧名
# 扫描范围**不含 tests/**（测试文件里有检查器自己的模式与豁免清单）；
# 豁免：CHANGELOG（历史）、显式兼容说明（同行含 兼容/旧名/迁移/别名/v1.13）
_OLD="pi""-team"
OLDNAME_HITS="$(grep -rIn "$_OLD" "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" "$SKILL_DIR/scripts" \
    "$SKILL_DIR/extension" "$SKILL_DIR/../README.md" "$SKILL_INIT_DIR/SKILL.md" "$SKILL_INIT_DIR/references" "$SKILL_INIT_DIR/templates" 2>/dev/null \
  | grep -vE '兼容|旧名|迁移|别名|v1\.13|begin|end|reload|smoke|compatibility|former name|renamed|alias|removed|旧路径|M22|legacy' || true)"
if [ -n "$OLDNAME_HITS" ]; then bad "还有旧名 pi-team 的残留：$(printf '%s' "$OLDNAME_HITS" | head -1)"; else ok "名字一致性：除兼容说明外无旧名残留"; fi
# M22（用户拍板提前结束别名期）：兼容软链必须**不在**了 —— 老项目改路径的指引在
# references/migration.md §2；翻转证据：把软链临时建回来，这条必须红。
if [ -e "$SKILL_DIR/../pi-team" ] || [ -L "$SKILL_DIR/../pi-team" ]; then
  bad "skills/pi-team 还在（M22 已移除兼容软链：老项目改绝对路径，而不是靠别名）"
else
  ok "旧路径 skills/pi-team 已移除（M22）"
fi
# 翻转自测：往沙箱副本注入旧名，必须被抓到
if [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ]; then
  rm -rf "$SANDBOX-oldname"; cp -r "$SANDBOX" "$SANDBOX-oldname"
  printf '\n# 用 pi-team 初始化（旧写法）\n' >> "$SANDBOX-oldname/references/protocol.md"
  HITS="$(grep -rIn 'pi-team' "$SANDBOX-oldname/SKILL.md" "$SANDBOX-oldname/references" "$SANDBOX-oldname/templates" 2>/dev/null | grep -vE '兼容|旧名|迁移|别名|v1\.13|pi-team:begin|pi-team:end|pi-team-reload' || true)"
  [ -n "$HITS" ] && ok "翻转自测：注入的旧名会被抓到" || bad "翻转自测：旧名注入竟然漏报"
  rm -rf "$SANDBOX-oldname"
fi

# 哲学与记忆：信条要有落盘位置，PM 提示词要带 credo
assert_file "$SKILL_DIR/references/philosophy.md" "信条文档存在"
assert_has "$SKILL_DIR/references/philosophy.md" "Status is a promise" "creed content present (status is a promise)"
assert_has "$SKILL_DIR/templates/pm-prompt.md.tmpl" "Your creed" "PM prompt carries the creed at the top"
assert_has "$SKILL_DIR/SKILL.md" "references/philosophy.md" "SKILL 指向信条文档"
assert_file "$SKILL_DIR/templates/memory-seed.md.tmpl" "项目记忆种子模板存在"
# 必需依赖矩阵（D10）：全部用 $TMP 夹具，不读本机真实状态
section "15b · 必需依赖：doctor 三态 + paths + dispatch 预检"
printf '{"packages":[]}\n' > "$TMP/mc-no.json"      # 有 settings 文件但没装这个包

# ⓪ 默认值本身就是「要求」（空 env + 无配置）：破坏默认值这条断言会红
M51_BARE="$TMP/m51-bare"; mkdir -p "$M51_BARE"; ( cd "$M51_BARE" && git init -q -b main )
M51_DEFAULTS="$( cd "$M51_BARE" && env -i PATH="$PATH" HOME="$HOME" TEAM_ROOT="$M51_BARE" bash -c \
  '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1 || true; printf "%s|%s|%s|%s" "$TEAM_REQUIRE_MAGIC_CONTEXT" "$TEAM_REQUIRE_OPENSPEC" "$TEAM_OPENSPEC_BIN" "$TEAM_SPEC_DIR"' )"
assert_eq "默认值：两个依赖都要求、CLI=openspec、spec 目录=openspec" "$M51_DEFAULTS" "1|1|openspec|openspec"

# ① magic-context 缺 + 默认（要求）→ 失败，且失败行给出安装与降级办法
if env TEAM_PI_SETTINGS_FILE="$TMP/mc-no.json" TEAM_OPENSPEC_BIN="$FAKE/openspec" TEAM_SPEC_DIR="$M51_SPEC" \
   $TEAM doctor >"$TMP/mc-req.log" 2>&1; then bad "缺 magic-context（默认要求）时 doctor 应失败"; else ok "缺 magic-context → doctor 失败"; fi
assert_has "$TMP/mc-req.log" "PM 记忆 magic-context" "失败行点名这一项"
assert_has "$TMP/mc-req.log" "@cortexkit/pi-magic-context" "失败行给出要装的包"
assert_has "$TMP/mc-req.log" "TEAM_PI_SETTINGS_FILE" "失败行说明 settings 位置可覆盖"
assert_has "$TMP/mc-req.log" "TEAM_REQUIRE_MAGIC_CONTEXT=0" "失败行给出降级开关"
# ② magic-context 缺 + 显式降级 → 只警告、退出码 0
if env TEAM_PI_SETTINGS_FILE="$TMP/mc-no.json" TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0 \
   $TEAM doctor >"$TMP/mc-warn.log" 2>&1; then ok "TEAM_REQUIRE_MAGIC_CONTEXT=0 → 只警告（exit 0）"; else bad "降级后 doctor 不该失败"; cat "$TMP/mc-warn.log"; fi
assert_has "$TMP/mc-warn.log" "已降级" "降级时说明是配置降级"
# ③ OpenSpec CLI 找不到 → 失败；spec 目录缺失 → 失败（并给出确切修复命令）
if env TEAM_OPENSPEC_BIN=/nonexistent TEAM_SPEC_DIR="$M51_SPEC" $TEAM doctor >"$TMP/os-nobin.log" 2>&1; then bad "OpenSpec CLI 找不到时 doctor 应失败"; else ok "OpenSpec CLI 找不到 → doctor 失败"; fi
assert_has "$TMP/os-nobin.log" "OpenSpec CLI" "失败行点名 OpenSpec CLI"
assert_has "$TMP/os-nobin.log" "TEAM_OPENSPEC_BIN" "失败行给出解析开关"
if env TEAM_OPENSPEC_BIN="$FAKE/openspec" TEAM_SPEC_DIR="$TMP/m51-no-such-spec" $TEAM doctor >"$TMP/os-nodir.log" 2>&1; then bad "spec 目录缺失时 doctor 应失败"; else ok "spec 目录缺失 → doctor 失败"; fi
assert_has "$TMP/os-nodir.log" "openspec init --tools none" "失败行给出确切的修复命令"
# ④ 显式降级 OpenSpec → 只警告、退出码 0
if env TEAM_OPENSPEC_BIN=/nonexistent TEAM_REQUIRE_OPENSPEC=0 $TEAM doctor >"$TMP/os-warn.log" 2>&1; then ok "TEAM_REQUIRE_OPENSPEC=0 → 只警告（exit 0）"; else bad "OpenSpec 降级后 doctor 不该失败"; cat "$TMP/os-warn.log"; fi
# ⑤ paths 暴露解析结果（PM/脚本不用猜）
$TEAM paths >"$TMP/paths-deps.log" 2>&1 || true
assert_has "$TMP/paths-deps.log" '"openspec_bin": "' "paths 暴露 openspec_bin"
assert_has "$TMP/paths-deps.log" '"spec_dir": "' "paths 暴露 spec_dir"
assert_has "$TMP/paths-deps.log" '"require_magic_context": "1"' "paths 暴露 require_magic_context（默认 1）"
assert_has "$TMP/paths-deps.log" '"require_openspec": "1"' "paths 暴露 require_openspec（默认 1）"
env TEAM_SPEC_DIR=openspec $TEAM paths >"$TMP/paths-spec-rel.log" 2>&1 || true
assert_has "$TMP/paths-spec-rel.log" "\"spec_dir\": \"$REPO/openspec\"" "相对 spec 目录按主工作树解析"
# ⑥ dispatch：缺依赖 → 告警一行、不阻塞派单
RC=0
env TEAM_PI_SETTINGS_FILE="$TMP/mc-no.json" TEAM_OPENSPEC_BIN=/nonexistent TEAM_AGENT_BIN=bash \
  $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/dispatch-deps.log" 2>&1 || RC=$?
assert_eq "缺依赖不阻塞派单（--print 退出码 0）" "$RC" "0"
assert_has "$TMP/dispatch-deps.log" "依赖缺失（不阻塞派单）" "dispatch 告警依赖缺失"
assert_has "$TMP/dispatch-deps.log" "magic-context" "告警点名 magic-context"
assert_has "$TMP/dispatch-deps.log" "OpenSpec" "告警点名 OpenSpec"
assert_eq "告警每次派单只一行" "$(grep -c '依赖缺失（不阻塞派单）' "$TMP/dispatch-deps.log")" "1"
# ⑦ 齐备时不告警（夹具齐全 → dispatch 输出里没有这句）
env TEAM_AGENT_BIN=bash $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/dispatch-deps-ok.log" 2>&1 || true
assert_not "$TMP/dispatch-deps-ok.log" "依赖缺失" "依赖齐备时 dispatch 不告警"

# 用法级不变量（verify 建议）：文档里出现 `team review <ID>` 就必须带 --dir（v1.11 起签名变了）
USAGE_HITS="$(grep -rEn 'team review[[:space:]]+[A-Za-z0-9]' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" "$SKILL_DIR/../README.md" 2>/dev/null | grep -v -- '--dir' | grep -vE '不再|已删|旧签名|v1\.11' || true)"
if [ -n "$USAGE_HITS" ]; then bad "文档在教「没有 --dir 的 review」：$(printf '%s' "$USAGE_HITS" | head -1)"; else ok "review 用法都带 --dir"; fi

# ---------------------------------------------------------------- 15c. harness 与插件清单（M26 建、M29 改写）
# 用户拍板（M29）：doctor 只**告知已装插件**，永不推荐第三方功能包；名册为空是 warn 不是 fail（PM-only 开局合法）。
# 本段钉三件事：① 全树再无「推第三方功能包安装」的字样（含翻转自测）；② 插件清单按级别列出且**不 spawn harness**
# （doctor 在巡检面板 health 块的等待路径上，spawn 会在不响应的 TEAM_PI_BIN 上白等满超时 —— M26 实测踩过）；
# ③ 名册为空 → warn、doctor 仍退 0。全部纯逻辑（假 pi / 假 omp / 影子 PATH），快慢都跑。
section "15c · harness 与插件清单：只告知、不推荐（M29）"

M29_FX="$TMP/m29"; rm -rf "$M29_FX"; mkdir -p "$M29_FX/pi-bin" "$M29_FX/omp-bin" "$M29_FX/proj/openspec" "$M29_FX/proj/docs/team"
( cd "$M29_FX/proj" && git init -q -b main && git config user.email m29@x && git config user.name m29 \
    && echo x > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
# 用户级设置：一个用户级插件 + 一个与项目级同名的（用来验去重）
printf '{"packages":["npm:user-tool","npm:shared-tool"]}\n' > "$M29_FX/user-settings.json"
printf '{"packages":[]}\n' > "$TMP/m29-empty.json"
printf '#!/usr/bin/env bash\nprintf "omp 0.0\\n"\n' > "$M29_FX/omp-bin/omp"
chmod +x "$M29_FX/omp-bin/omp"
# 假 pi：--version/--help 给像样回答；`list` 只留一个标记文件（证明「插件探测不 spawn harness」）
cat > "$M29_FX/pi-bin/pi" <<'M29PI'
#!/usr/bin/env bash
case "${1:-}" in
  --version|-v) printf 'pi 0.0.0 (m29-fake)\n'; exit 0 ;;
  --help|-h)    printf 'usage: pi [--session-id <id>] [-e <ext>] [--skill <dir>]\n'; exit 0 ;;
esac
if [ "${1:-}" = "list" ]; then printf 'list\n' >> "$(dirname "$0")/pi-list-calls.log"; exit 0; fi
exit 0
M29PI
chmod +x "$M29_FX/pi-bin/pi"
# 影子 PATH：把现成 PATH 的条目软链过来，除了 pi 和 omp（宿主装了 omp 也能得到确定结果）
M29_SHADOW="$TMP/m29-shadow"; mkdir -p "$M29_SHADOW"
for _d in ${PATH//:/ }; do [ -d "$_d" ] && ln -sf "$_d"/* "$M29_SHADOW/" 2>/dev/null; done
rm -f "$M29_SHADOW/pi" "$M29_SHADOW/omp"
m29_doctor() { # <PATH 前缀> <TEAM_PI_BIN> [额外 env…]
  local path="$1" bin="$2"; shift 2
  ( cd "$M29_FX/proj" && env TEAM_ROOT="$M29_FX/proj" TEAM_MAIN_ROOT="$M29_FX/proj" \
      TEAM_PI_SETTINGS_FILE="$M29_FX/user-settings.json" TEAM_PI_BIN="$bin" TEAM_AGENTS="${M29_AGENTS-dev}" \
      TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0 TEAM_REQUIRE_JS=0 "$@" \
      PATH="$path:$M29_SHADOW" bash "$SKILL_DIR/scripts/team" doctor ) 2>&1
}
M29_PI="$M29_FX/pi-bin/pi"; M29_OMP="$M29_FX/omp-bin/omp"; M29_MARK="$M29_FX/pi-bin/pi-list-calls.log"

# ① 政策不变量：全树不再推第三方功能包安装（唯一允许的是必需依赖 magic-context）+ 翻转自测
m29_install_hits() { # <文件/目录…> → 推第三方功能包的字样（空 = 干净）
  grep -rnE 'pi install [a-zA-Z@]|pi-processes|pi-background-tasks|Anthropic attribution' "$@" 2>/dev/null \
    | grep -v 'pi-magic-context' || true
}
M29_HITS="$(m29_install_hits "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" \
  "$SKILL_DIR/scripts/lib" "$SKILL_INIT_DIR")"
[ -z "$M29_HITS" ] && ok "全树没有第三方功能包的推荐/安装字样（magic-context 是必需依赖，除外）" \
  || bad "还在推第三方包：$(printf '%s' "$M29_HITS" | head -1)"
M29_SB="$TMP/m29-sandbox"; rm -rf "$M29_SB"; mkdir -p "$M29_SB"
cp -r "$SKILL_DIR/references" "$M29_SB/references"
printf '\n装它：`pi install npm:some-bg-plugin -l`\n' >> "$M29_SB/references/troubleshooting.md"
[ -n "$(m29_install_hits "$M29_SB/references")" ] && ok "翻转自测：把安装推荐塞回文档会被抓到" \
  || bad "翻转自测：塞回去的推荐竟然漏报（策略断言是空跑）"
rm -rf "$M29_SB"

# ② 插件清单：按级别列出（项目级在前、同名去重）；不 spawn harness；没有任何安装推荐
mkdir -p "$M29_FX/proj/.pi"
printf '{"packages":["npm:pi-demo-tool","npm:shared-tool"]}\n' > "$M29_FX/proj/.pi/settings.json"
rm -f "$M29_MARK"
m29_doctor "$M29_FX/pi-bin" "$M29_PI" >"$TMP/m29-plugins.log" 2>&1 || true
assert_has "$TMP/m29-plugins.log" "已装插件 packages" "doctor 有「已装插件」行"
assert_has "$TMP/m29-plugins.log" "npm:pi-demo-tool（项目级）" "项目级插件：包名 + 级别"
assert_has "$TMP/m29-plugins.log" "npm:user-tool（用户级）" "用户级插件也列出（读用户设置文件）"
assert_eq "同名包只出现一次（项目级胜出）" "$(grep -c 'npm:shared-tool' "$TMP/m29-plugins.log" || true)" "1"
assert_has "$TMP/m29-plugins.log" "npm:shared-tool（项目级）" "去重后保留的是项目级那一份"
assert_not_file "$M29_MARK" "插件探测不 spawn harness（pi list 一次都没跑）"
assert_not "$TMP/m29-plugins.log" "pi install" "doctor 输出里没有任何安装推荐"
assert_not "$TMP/m29-plugins.log" "pi-processes" "不再点名第三方包（一）"
assert_not "$TMP/m29-plugins.log" "pi-background-tasks" "不再点名第三方包（二）"
assert_not "$TMP/m29-plugins.log" "attribution" "不再有 attribution 副作用警告"
assert_not_file "$M29_FX/proj/.pi/settings.json.bak" "（夹具自检：没有留下备份文件）"
rm -f "$M29_FX/proj/.pi/settings.json"
# 项目与用户都没有插件 → 一条信息行（不是推荐、也不是失败）
rm -f "$M29_MARK"
m29_doctor "$M29_FX/pi-bin" "$M29_PI" TEAM_PI_SETTINGS_FILE="$TMP/m29-empty.json" >"$TMP/m29-noplug.log" 2>&1 || true
assert_has "$TMP/m29-noplug.log" "未检测到插件（teamsmith 不依赖第三方插件；团队会话的后台任务由自带 team-bg 覆盖）" \
  "无插件时是一条信息行（含 team-bg 覆盖的说明）"
assert_not_file "$M29_MARK" "没有插件时也不 spawn harness"

# ③ harness 行（M29 保留 M26 的判定次序，文案里不再出现行名指路）
m29_doctor "$M29_FX/pi-bin" "$M29_PI" TEAM_PI_SETTINGS_FILE="$TMP/m29-empty.json" >"$TMP/m29-h-pi.log" 2>&1 || true
assert_has "$TMP/m29-h-pi.log" "pi（内置无后台 bash：团队会话的长任务由自带的 team-bg 覆盖）" \
  "pi 形态：harness 行说明谁覆盖长任务"
m29_doctor "$M29_FX/omp-bin:$M29_FX/pi-bin" "$M29_OMP" TEAM_PI_SETTINGS_FILE="$TMP/m29-empty.json" >"$TMP/m29-h-omp.log" 2>&1 || true
assert_has "$TMP/m29-h-omp.log" "omp 自带后台任务（bash 后台派发 / hub wait·cancel / /jobs）" "omp 形态：明说自带后台"
assert_not "$TMP/m29-h-omp.log" "pi install" "omp 形态没有任何安装推荐"
m29_doctor "$M29_FX/omp-bin:$M29_FX/pi-bin" "$M29_PI" TEAM_PI_SETTINGS_FILE="$TMP/m29-empty.json" >"$TMP/m29-h-both.log" 2>&1 || true
assert_has "$TMP/m29-h-both.log" "PATH 里有 omp" "omp 只是装着 → 说明白"
assert_has "$TMP/m29-h-both.log" "本项目配的是 pi" "并点名本项目实际配的是谁"
m29_doctor "$M29_FX/pi-bin" "$M29_PI" TEAM_AGENT_CMD='myagent run {prompt}' >"$TMP/m29-h-adapt.log" 2>&1 || true
assert_has "$TMP/m29-h-adapt.log" "取决于该 harness，无法探测" "自定义 adapter → 如实说无法探测"

# ④ 名册为空 → warn（PM-only 开局合法），doctor 仍退 0；拦人的是 dispatch
M29_RC=0
m29_doctor "$M29_FX/pi-bin" "$M29_PI" TEAM_PI_SETTINGS_FILE="$TMP/m29-empty.json" TEAM_AGENTS="" \
  >"$TMP/m29-noroster.log" 2>&1 || M29_RC=$?
assert_eq "名册为空时 doctor 仍退 0（不再 fail）" "$M29_RC" "0"
assert_match "$TMP/m29-noroster.log" '^ *名册 TEAM_AGENTS +! 名册为空：可以 PM-only 开局；要派单先 ' \
  "名册为空是一条 warn，并给出下一步"
M29_ROSTER_FAIL="$(grep -c '✗.*名册为空' "$TMP/m29-noroster.log" || true)"
assert_eq "名册为空不再以 ✗ 出现" "$M29_ROSTER_FAIL" "0"

# ⑤ 交付物 2/3 的措辞落盘（init 清单 + 长任务文档）
assert_has "$SKILL_INIT_DIR/SKILL.md" "minimal starting roster" "init 名册条目改成最小起点措辞"
assert_has "$SKILL_INIT_DIR/SKILL.md" "team add-agent <name> --register" "init 名册条目点名 --register（flagless 增长是假的，P99）"
assert_has "$SKILL_INIT_DIR/SKILL.md" "teardown --agent <name> --register" "并给出对称的移除入口"
assert_has "$SKILL_INIT_DIR/SKILL.md" "information only" "插件条目说明是告知、不是推荐"
assert_has "$SKILL_INIT_DIR/SKILL.md" "team-bg" "并说明团队会话的后台由自带 team-bg 覆盖"
assert_has "$SKILL_DIR/references/troubleshooting.md" "## 17. A long task" "长任务两种车道仍在 troubleshooting §17"
assert_has "$SKILL_DIR/references/troubleshooting.md" "team-bg" "Lane A 已改成团队自带的 team-bg"
assert_has "$SKILL_DIR/references/workflows.md" "troubleshooting.md) §17" "workflows §E 仍指到那一节"

section "12 · roster / status / ps"
for c in roster status ps; do
  $TEAM "$c" >"$TMP/$c.log" 2>&1 && ok "$c 退出码 0" || bad "$c 失败"
  [ -s "$TMP/$c.log" ] && ok "$c 有输出" || bad "$c 无输出"
done
# M6.1 F28：只读命令对 state/ 必须是零写入（快慢模式都跑；快模式下没有 tmux 窗口，
# 旧实现会在 team ps 里把 dev.env 删掉 —— 这条断言就是那个回归的守门人）
STATE_FP_BEFORE="$(state_fp)"
for c in paths roster status ps digest inbox pulse watchdog-status; do
  $TEAM "$c" >/dev/null 2>&1 || true
done
assert_eq "只读命令零写入 state/（F28）" "$(state_fp)" "$STATE_FP_BEFORE"
# F28 的最小现场（快模式也能验）：状态里写一条「还在跑某个模型、但窗口不在」的记录 —— 这就是崩溃 agent 的样子。
# 旧实现（team_model_running 对死窗口调 team_state_clear）会把整份文件删掉，下一行断言就会红。
if [ -f "$REPO/.pi/team/state/dev.env" ]; then cp "$REPO/.pi/team/state/dev.env" "$TMP/dev.env.f28bak"; F28_HAD=1; else F28_HAD=0; fi
F28_MODEL="$(sed -n 's/^model=//p' "$REPO/.pi/team/state/dev.env" 2>/dev/null | head -1)"
[ -n "$F28_MODEL" ] || F28_MODEL="$(sed -n 's/^TEAM_DEFAULT_MODEL="\([^"]*\)".*/\1/p' "$REPO/.pi/team/config.sh" | head -1)"
printf 'model=%s\nwindow=no-such-window-f28\ntask=R98.1\nbranch=task/R98.1-ghost\ntaskfile=%s\nworktree=%s\n' \
  "$F28_MODEL" "$TASKFILE" "$REPO/.worktrees/dev" > "$REPO/.pi/team/state/dev.env"
GRD_BEFORE="$(cat "$REPO/.pi/team/state/dev.env")"
$TEAM ps >/dev/null 2>&1 || true
$TEAM digest >/dev/null 2>&1 || true
$TEAM roster >/dev/null 2>&1 || true
$TEAM paths >/dev/null 2>&1 || true
assert_eq "读命令没删掉崩溃 agent 的状态文件（F28）" "$(cat "$REPO/.pi/team/state/dev.env" 2>/dev/null)" "$GRD_BEFORE"
assert_has "$REPO/.pi/team/state/dev.env" "task=R98.1" "崩溃 agent 的 task 记录还在"
assert_has "$REPO/.pi/team/state/dev.env" "branch=task/R98.1-ghost" "崩溃 agent 的 branch 记录还在"
[ "$F28_HAD" = "1" ] && cp "$TMP/dev.env.f28bak" "$REPO/.pi/team/state/dev.env" || rm -f "$REPO/.pi/team/state/dev.env"
$TEAM pulse status >"$TMP/wd.log" 2>&1 && ok "pulse status 退出码 0" || bad "pulse status 失败"
$TEAM paths >"$TMP/paths.log" 2>&1 && assert_has "$TMP/paths.log" "main_root" "paths 输出主工作树" || bad "paths 失败"
$TEAM up --print >"$TMP/pmprompt.log" 2>&1 && assert_has "$TMP/pmprompt.log" "team digest" "up --print 输出 PM 开场提示词" || bad "up --print 失败"

# ---------------------------------------------------------------- 13. notify 扩展（Node 直跑）
section "13 · notify 扩展（去重 + 只在 worktree 触发）"
# 注意：夹具里的 assistant 消息都带 stopReason（M4.3 E 起，“完成”）—— Pi 持久化的消息本来就带
# （docs/session-format.md），旧夹具省了它；不带 stopReason 的消息不再算完成回合（见 13b）。
if [ -n "$TS_RUNNER" ]; then
  cat > "$TMP/ext-test.mjs" <<'EOF'
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
const [, , ext, root, wt] = process.argv
delete process.env.TMUX_PANE
delete process.env.TMUX
const mod = await import(ext)
let handler = null
let sessionStart = null
const sent = []
const registered = { commands: [], tools: [] }
mod.default({
  on: (name, fn) => {
    if (name === 'agent_settled') handler = fn
    if (name === 'session_start') sessionStart = fn
  },
  registerCommand: (name) => { registered.commands.push(name) },
  registerTool: (def) => { registered.tools.push(def?.name) },
  sendMessage: (msg, opts) => { sent.push({ msg, opts }) },
})
if (!handler) { console.error('FAIL: 没有注册 agent_settled'); process.exit(3) }
const inbox = join(root, 'docs/team/inbox/dev.md')
rmSync(inbox, { force: true })
const ctx = {
  cwd: wt,
  sessionManager: { getEntries: () => [{ message: { role: 'assistant', stopReason: 'stop', content: [{ text: 'ALLDONE feature implemented' }] } }] },
}
await handler({}, ctx)
await handler({}, ctx)              // 去重窗口内，第二次必须被抑制
let lines = readFileSync(inbox, 'utf8').trim().split('\n')
if (lines.length !== 1) { console.error(`FAIL: 期望 1 行（去重），实际 ${lines.length}`); process.exit(4) }
if (!lines[0].includes('ALLDONE feature implemented')) { console.error('FAIL: 没有带上 agent 末条消息'); process.exit(5) }
if (!lines[0].includes('agent:dev')) { console.error('FAIL: agent 名推断错误'); process.exit(6) }
// M6.3 F17：去重键必须能区分「开头 60 字符相同、后半不同」的简报（旧键只取前缀 → 会吞掉）
{
  rmSync(inbox, { force: true })
  rmSync(join(root, '.pi/team/state/notify-dedup'), { force: true })
  const prefix = 'All gates are green. I delivered the parser fix; the remaining work on this branch is'
  const ctxN = (text) => ({ cwd: wt, sessionManager: { getEntries: () => [{ message: { role: 'assistant', stopReason: 'stop', content: [{ text }] } }] } })
  for (const tail of [' the retry path.', ' the cache warm-up.', ' error mapping.']) await handler({}, ctxN(prefix + tail))
  const n = readFileSync(inbox, 'utf8').trim().split('\n').length
  if (n !== 3) { console.error(`FAIL: F17 三条不同简报被去重吞掉（期望 3 行，实际 ${n}）`); process.exit(20) }
  await handler({}, ctxN(prefix + ' the retry path.'))     // 字节相同的一条：仍然要抑制
  const n2 = readFileSync(inbox, 'utf8').trim().split('\n').length
  if (n2 !== 3) { console.error(`FAIL: F17 重复的同一条没有被去重（${n2} 行）`); process.exit(21) }
}
// M40：继承来的 TEAM_ROOT 指到**工作树**（agent 工作树里有 config.sh 副本）也不许改变账本落点：回合通知
// 必须照旧写主工作树的收件箱。旧实现 env 优先 → cwd 被判成「不在 worktrees 之下」→ 整个通知静默不发
// （M40 实测：主工作树收件箱 0 行）。这条既是扩展自己的守卫，也是「dispatch 窗口身份 = 目标目录」的对照。
{
  const prevEnv = process.env.TEAM_ROOT
  // 真实形状：agent 工作树里有 .pi/team/config.sh 的**副本**（没有它，旧实现也不会信任指向工作树的 env）。
  // 收尾时必须把工作树恢复原样（文件 + 我们自己建的目录）—— 14 段的 teardown --purge 看到
  // `git status --porcelain` 非空就会保留工作树（也提醒我们：夹具不许在别人的工作树里留痕迹）。
  const wtTeamDir = join(wt, '.pi/team')
  const hadTeamDir = existsSync(wtTeamDir)
  const wtCfg = join(wtTeamDir, 'config.sh')
  const cfgBefore = existsSync(wtCfg) ? readFileSync(wtCfg, 'utf8') : null
  mkdirSync(wtTeamDir, { recursive: true })
  writeFileSync(wtCfg, readFileSync(join(root, '.pi/team/config.sh'), 'utf8'))
  process.env.TEAM_ROOT = wt
  rmSync(inbox, { force: true })
  rmSync(join(wt, 'docs/team/inbox/dev.md'), { force: true })
  rmSync(join(root, '.pi/team/state/notify-dedup'), { force: true })
  await handler({}, { cwd: wt, sessionManager: { getEntries: () => [{ message: { role: 'assistant', stopReason: 'stop', content: [{ text: 'M40 worktree-root identity' }] } }] } })
  const n40 = readFileSync(inbox, 'utf8').trim().split('\n').length
  if (n40 !== 1) { console.error(`FAIL: M40 TEAM_ROOT=worktree 时通知被静默跳过（主工作树收件箱 ${n40} 行）`); process.exit(30) }
  if (existsSync(join(wt, 'docs/team/inbox/dev.md'))) { console.error('FAIL: M40 通知写进了工作树的收件箱（账本落错地方）'); process.exit(31) }
  if (cfgBefore === null) rmSync(wtCfg, { force: true })   // 是我们建的 → 收掉
  else writeFileSync(wtCfg, cfgBefore)                    // 本来就有的副本（可能是**跟踪**文件）→ 逐字节写回
  if (!hadTeamDir) rmSync(wtTeamDir, { recursive: true, force: true })   // 连空目录一起收掉（是我们建的）
  if (prevEnv === undefined) delete process.env.TEAM_ROOT; else process.env.TEAM_ROOT = prevEnv
}
const before = readFileSync(inbox, 'utf8')
await handler({}, { cwd: root, sessionManager: { getEntries: () => [] } })   // 主工作树不该触发
if (readFileSync(inbox, 'utf8') !== before) { console.error('FAIL: 非 worktree 路径也写了收件箱'); process.exit(7) }
// /reload：必须提醒重新 read SKILL.md（历史里的旧文本不会被改写）
if (!sessionStart) { console.error('FAIL: 没注册 session_start'); process.exit(10) }
await sessionStart({ reason: 'startup' }, { cwd: wt })
if (sent.length !== 0) { console.error('FAIL: startup 不该发消息'); process.exit(11) }
await sessionStart({ reason: 'reload' }, { cwd: wt })
const reloadMsg = sent[sent.length - 1]
if (!reloadMsg) { console.error('FAIL: reload 没有提醒重读 skill'); process.exit(12) }
if (!String(reloadMsg.msg?.content ?? '').includes('SKILL.md')) { console.error('FAIL: reload 提示没让重读 SKILL.md'); process.exit(13) }
if (reloadMsg.opts?.triggerTurn !== true) { console.error('FAIL: reload 提示应当触发一轮'); process.exit(14) }
// 主工作树（非 worktree）也要提示：skill 重载与 agent 位置无关
if (!String(reloadMsg.msg?.content ?? '').includes('已重载')) { console.error('FAIL: reload 提示文案不对'); process.exit(15) }
if (!registered.commands.includes('teamsmith-reload')) { console.error('FAIL: 没注册 /teamsmith-reload 命令'); process.exit(8) }
if (!registered.tools.includes('reload_skills')) { console.error('FAIL: 没注册 reload_skills 工具'); process.exit(9) }
console.log('ext-ok')
EOF
  if $TS_RUNNER "$TMP/ext-test.mjs" "$SKILL_DIR/extension/team-notify.ts" "$REPO" "$REPO/.worktrees/dev" >"$TMP/ext.log" 2>&1; then
    ok "扩展：写入 + 去重 + 非 worktree 不触发（runner=$TS_RUNNER）"
  else
    bad "扩展测试失败（runner=$TS_RUNNER）"; cat "$TMP/ext.log"
  fi
else
  printf '  (跳过扩展测试：node 未启用类型剥离，且没有 bun/tsx)\n'
fi

# ---------------------------------------------------------------- 13b. 通知的语义（M4.3 E）
# 现场（D9 事件 E）：dev 的一个长回合里发生内部生命周期事件（压缩/会话重启）→ settle 触发简报，
# 而“最后消息”取到了**本轮开头**那句（"I'll start by reading the required files in order."），
# PM 于是花一个周期诊断一个正在干活的 agent。通知只能意味着一件事：**回合结束、在等 PM**。
section "13b · 通知只代表「回合结束」（M4.3 E：内部生命周期不得被广播成交付）"
if [ -n "$TS_RUNNER" ]; then
  # 假 tmux：只在 PATH 里，用来抓「敲 PM 窗口」的调用（E2 是必须敲的对照组，E1/E4 必须一次都不敲）
  mkdir -p "$TMP/ext-shim"
  cat > "$TMP/ext-shim/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/ext-tmux.log"
case "\$*" in
  *pane_current_command*) printf 'pi\n' ;;
  *window_name*) printf 'dev\n' ;;
  *session_name*) printf '$SESSION\n' ;;
esac
exit 0
EOF
  chmod +x "$TMP/ext-shim/tmux"
  : > "$TMP/ext-tmux.log"
  cat > "$TMP/ext-e-test.mjs" <<'EOF'
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
const [, , ext, root, wt] = process.argv
process.env.TMUX_PANE = 'smoke-fake-pane'        // 有 pane 才会走“敲门”那条路
const mod = await import(ext)
const handlers = {}
mod.default({
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerCommand: () => {},
  registerTool: () => {},
  sendMessage: () => {},
})
const emit = async (name, ...args) => { for (const fn of handlers[name] ?? []) await fn(...args) }
const inbox = join(root, 'docs/team/inbox/dev.md')
const dedup = join(root, '.pi/team/state/notify-dedup')
const knockLog = process.env.EXT_TMUX_LOG
const reset = () => { rmSync(inbox, { force: true }); rmSync(dedup, { force: true }); writeFileSync(knockLog, '') }
const cx = (list) => ({ cwd: wt, sessionManager: { getEntries: () => list.map(m => ({ message: m })) } })
const lines = () => existsSync(inbox) ? readFileSync(inbox, 'utf8').trim().split('\n').filter(Boolean) : []
const knocks = () => readFileSync(knockLog, 'utf8').split('\n').filter(l => l.includes('send-keys')).length
const fail = (msg) => { console.error(`FAIL: ${msg}`); process.exit(40) }
const midTurn = { role: 'assistant', stopReason: 'toolUse', content: [{ text: "I'll start by reading the required files in order." }] }
const earlier = { role: 'assistant', stopReason: 'stop', content: [{ text: 'EARLIER-DELIVERED-TEXT' }] }
const finalAns = { role: 'assistant', stopReason: 'stop', content: [{ text: 'M43-DONE genuine turn end' }] }

// E1：回合内压缩（内部生命周期）+ 回合未完成 → 不发简报、不敲门
reset()
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx([]))
await emit('session_compact', { type: 'session_compact', reason: 'threshold' }, cx([]))
await emit('agent_settled', {}, cx([earlier, midTurn]))
if (lines().length !== 0) fail('E1：内部生命周期中的 settle 仍写了收件箱')
if (knocks() !== 0) fail('E1：内部生命周期中的 settle 仍在敲 PM 窗口')
console.log('E1 回合内重启/压缩：没有收件箱行、没有敲门')

// E2（对照组）：同一回合里压缩过，但回合真的完成 → 照常一行 + 敲门（不许过度抑制）
reset()
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx([]))
await emit('session_compact', { type: 'session_compact', reason: 'threshold' }, cx([]))
await emit('agent_settled', {}, cx([midTurn, finalAns]))
let ls = lines()
if (ls.length !== 1) fail(`E2：完成的回合应当只有一行（实际 ${ls.length}）`)
if (!ls[0].includes('[auto]')) fail('E2：完成的回合应带 [auto] 标签')
if (!ls[0].includes('M43-DONE genuine turn end')) fail('E2：完成的回合应带它的最终文本')
if (knocks() < 1) fail('E2：完成的回合应敲 PM 窗口（对照组）')
console.log('E2 压缩过但已完成：一行 + 敲门（对照组）')

// E3：被中断（Esc/错误）且没有生命周期事件 → 仍然告诉 PM，但绝不带摘要文本
reset()
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx([]))
await emit('agent_settled', {}, cx([earlier, midTurn]))
ls = lines()
if (ls.length !== 1) fail(`E3：被中断的回合仍应告诉 PM（期望 1 行，实际 ${ls.length}）`)
if (!ls[0].includes('[auto·interrupted]')) fail('E3：被中断的回合必须显式标记，不能冒充交付')
if (ls[0].includes('EARLIER-DELIVERED-TEXT') || ls[0].includes("I'll start by reading")) fail('E3：不许拿未完成回合的文本当摘要')
console.log('E3 被中断：一行、显式标记、没有编造的摘要')

// E4：session_start(reload) 也算内部生命周期 → 未完成的 settle 同样不发
reset()
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx([]))
await emit('session_start', { type: 'session_start', reason: 'reload' }, cx([]))
await emit('agent_settled', {}, cx([midTurn]))
if (lines().length !== 0) fail('E4：reload 之后的未完成 settle 仍写了收件箱')
console.log('E4 reload 打断的回合：没有收件箱行')
console.log('ext-e-ok')
EOF
  if env PATH="$TMP/ext-shim:$PATH" EXT_TMUX_LOG="$TMP/ext-tmux.log" \
      $TS_RUNNER "$TMP/ext-e-test.mjs" "$SKILL_DIR/extension/team-notify.ts" "$REPO" "$REPO/.worktrees/dev" >"$TMP/ext-e.log" 2>&1; then
    ok "扩展 E：内部生命周期不被广播成交付（runner=$TS_RUNNER）"
  else
    bad "M4.3 E 扩展测试失败（runner=$TS_RUNNER）"; cat "$TMP/ext-e.log"
  fi
  assert_has "$TMP/ext-e.log" "E1 回合内重启/压缩：没有收件箱行、没有敲门" "E1：存在压缩的未完成回合不发简报、不敲门"
  assert_has "$TMP/ext-e.log" "E2 压缩过但已完成：一行 + 敲门（对照组）" "E2：同回合压缩但已完成 → 照常通知（不过度抑制）"
  assert_has "$TMP/ext-e.log" "E3 被中断：一行、显式标记、没有编造的摘要" "E3：被中断的回合显式标记且不编造摘要"
  assert_has "$TMP/ext-e.log" "E4 reload 打断的回合：没有收件箱行" "E4：reload 打断的回合不发简报"
else
  printf '  (跳过扩展 E 测试：node 未启用类型剥离，且没有 bun/tsx)\n'
fi

# ---------------------------------------------------------------- 13c. 团队后台车道（M27 / M30 根解析）
# 长门禁/长构建不能占住回合：team-bg 扩展把作业放进 **detached** 子进程，回合可以结束再被叫回来。
# 判据全部来自**真扩展代码 + 真子进程 + 真日志/账本**，只把 pi 宿主换成假宿主（sendMessage 记账）。
# 为什么不用真模型：那会把判据换成「模型有没有照着做」；真实的「唤醒一个空闲 pi 会话」已由 E8 的
# RPC 探针实证（docs/team/reports/E8-verify/probes + 报告 §2.2/§2.3）。夹具是纯逻辑+短子进程，快模式也跑。
# M30 追加：产物是**会话本地**的 —— worktree 会话的日志/账本必须落在自己的 worktree（S11 四重证据）。
section "13c · 团队后台车道（M27/M30）：拉起链注入 / 收割契约 / 账本 / worktree 侧"
assert_file "$SKILL_DIR/extension/team-bg.ts" "team-bg 扩展在"
# ① 两条内置 Pi 启动链都挂上：worker 与 notify 并列；PM 只有 bg（它就是收件人，不是通知者）
assert_has "$TMP/print.log" "team-bg.ts" "worker 启动命令显式加载 team-bg（worktree 不会自动发现扩展）"
assert_has_echo "$DEFAULT_CMD" "extension/team-bg.ts" "PM 启动命令也加载 team-bg（PM 的后台门禁）"
assert_has "$TMP/print.log" "-e $SKILL_DIR/extension/team-bg.ts" "worker 命令里是 -e 挂上 bg 扩展（与 notify 并列）"
# ② {bg_ext} 是两条模板集里的一等占位符，文档与引擎不漂移
assert_has_echo "$(adapter_launch_support)" "{bg_ext}" "worker launch 模板支持 {bg_ext}"
assert_has_echo " $PM_SUPPORT " " {bg_ext} " "PM 模板支持 {bg_ext}"
assert_eq "文档里没有引擎不认识的占位符（worker 表格）" "$(adapter_doc_unsupported "$ADOC" | tr '\n' ' ')" ""
# ③ 真扩展跑确定性夹具：未收割→唤醒 / 已收割→静默 / 多条合并 / 账本行 / 日志有界 / 会话级清理
if [ -n "$TS_RUNNER" ]; then
  if $TS_RUNNER "$SKILL_DIR/tests/team-bg-harness.mjs" "$SKILL_DIR/extension/team-bg.ts" >"$TMP/bg-harness.log" 2>&1; then
    ok "扩展夹具全绿（runner=$TS_RUNNER，$(grep -c 'TEAM-BG-CASE PASS' "$TMP/bg-harness.log") 条用例）"
  else
    bad "team-bg 夹具失败（runner=$TS_RUNNER）"; grep 'TEAM-BG-CASE FAIL' "$TMP/bg-harness.log" | sed 's/^/     /'
  fi
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S1 unharvested job wakes the idle agent exactly once" "未收割的作业唤醒空闲会话（且只一次）"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S2 harvested job never wakes the agent" "收割过的作业完成时静默（#689 第 1 条）"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S3 two jobs finishing together produce exactly one message" "同拍完成的多条合并成一条（#689 第 2 条）"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S5 settled lines report the unharvested count" "账本有 settled-with-unharvested=<n> 行"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S6 log stays under the cap" "日志有界（截断留尾段）"
  # M30：worktree 会话的产物必须落在**自己的 worktree**（返回路径 / 真实文件 / 账本 / 唤醒行四重证据）
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S11 a worktree session writes its job log inside the worktree" "M30：worktree 会话的作业日志落在 worktree 侧（不用 git-common-dir）"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S11 the shared root does not receive that job log" "M30：共享根（主工作树）没有收到这份作业日志"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S11 the wake names the worktree-side log" "M30：唤醒消息点名的也是 worktree 侧日志"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS S11 the session ledger line lands in the worktree" "M30：会话账本行也在 worktree 侧"
  assert_has "$TMP/bg-harness.log" "TEAM-BG-CASE PASS reverse guard" "反向守卫：真实仓库 state/ 未被触碰"
else
  printf '  (跳过 team-bg 夹具：node 未启用类型剥离，且没有 bun/tsx)\n'
fi

# ---------------------------------------------------------------- 12b. 延后投递与草稿入口（delivery-guard）
# 事故背景（D20）：自动化消息 send-keys 到「人正在写草稿」的输入框，草稿被粘走、一起被提交。
# 这一节把守卫/队列/排水/草稿入口按规格逐条钉住：先用**假 tmux**（headless，快模式也跑）打**
# 判定与格式**，再用**真 pane（假 TUI）**打端到端形状（多行 = 一次提交、清空后只投一次、等等）。
#
# 隔离（M7.2 教训 / 规格 tasks 7.2）：夹具全部跑在临时仓库里，继承的 TEAM_* 已经在开头清掉；
# 每个夹具写之前先断言 `team paths` 指向临时根；结尾比对**调用方项目**的 inbox/state 指纹。
section "12b · 延后投递与草稿入口（delivery-guard：守卫 / 队列 / 排水 / 草稿）"

ob_hash_real() { # 调用方项目（+ 它的主工作树）的 docs/team/inbox 与 .pi/team/state 指纹
  { for r in "$SMOKE_INVOKE_ROOT" "$SMOKE_INVOKE_MAIN"; do
      [ -n "$r" ] || continue
      for d in "$r/docs/team/inbox" "$r/.pi/team/state"; do
        if [ -d "$d" ]; then
          ( cd "$d" && find . -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" 2>/dev/null | cut -d' ' -f1; done )
        else
          printf 'missing %s\n' "$d"
        fi
      done
    done; } | md5sum | awk '{print $1}'
}
# 真项目的 state/inbox **本来就在被真团队写**（capacity.log/nudges.log 每一拍都动），所以「整目录哈希不变」
# 在真项目活着时必然为假。承重的判据因此是「**夹具的痕迹**有没有出现在真项目里」：夹具的 payload 与 target
# 都带得出自己的名字（沙盒 session 名 + 夹具专用串），一条都搜不到才算没污染。
ob_leak_scan() { # → 命中行（空 = 没有污染）
  local pats="$SESSION|半句草稿 half a sentence|never lands|held body|race claim|OB-EXT-KNOCK|ob-nudge-new-work|alpha line one|interrupted once|deliver as today|flush now|vis1|dropme|M30-PI-CHANNEL|M30-PI-KNOCK|M30-PI-DRAFT|M30-PI-FORCED|M30-PI-STALE|M30-PI-FOREIGN"
  { [ -n "$SMOKE_INVOKE_ROOT" ] && real_ledger_hits "$pats" "$SMOKE_INVOKE_ROOT"
    [ -n "$SMOKE_INVOKE_MAIN" ] && real_ledger_hits "$pats" "$SMOKE_INVOKE_MAIN"
    :; } | sort -u
}
ob_paths_ok() { # 写之前必须证明 team paths 指向临时根（不是真项目）
  local p; p="$( $TEAM paths 2>/dev/null )"
  case "$p" in *"\"main_root\": \"$REPO\""*) return 0 ;; *) return 1 ;; esac
}

REAL_FP_BEFORE="$(ob_hash_real)"
if ob_paths_ok; then ok "12b 隔离：team paths 指向临时根（$REPO）"; else bad "12b 隔离：team paths 不是临时根"; fi

# 夹具 pane 的形状（E3 §1.1(a)/(b)）：上边框 / 3 行内容 / 提示行 / 下边框，光标落在第 2 行内容行
ob_box_empty_txt() { printf '%s\n' "$(printf '%.0s─' $(seq 1 80))" "" "" "" " k3  Kimi Coding  max" "$(printf '%.0s─' $(seq 1 80))" "footer"; }
ob_box_draft_txt() { printf '%s\n' "$(printf '%.0s─' $(seq 1 80))" "" "半句草稿 half a sentence" "" " k3  Kimi Coding  max" "$(printf '%.0s─' $(seq 1 80))" "footer"; }

# 假 tmux：只服务 headless 夹具。capture-pane 的输出由 OB_BOX 决定；OB_SWITCH_AFTER=N 表示
# 「第 N 次之后的 capture-pane 换成 OB_BOX2」（用来造「检查与粘贴之间状态变了」的世界）。
OB_SHIM="$TMP/ob-shim"; mkdir -p "$OB_SHIM"
cat > "$OB_SHIM/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\$OB_LOG"
case "\$*" in
  *cursor_y*) printf '%s\n' "\${OB_CURSOR_Y:-2}" ; exit 0 ;;
esac
case "\$*" in
  *capture-pane*)
    n=0
    [ -f "\$OB_COUNT" ] && n="\$(cat "\$OB_COUNT")"
    n=\$((n + 1))
    printf '%s' "\$n" > "\$OB_COUNT"
    # OB_ECHO=1：模拟真实 TUI 的气泡区——凡是在最后一次 Enter 之前用 send-keys -l 打进去的
    # 文本，都作为对话区行回显在输入框**上方**（V9-B5：生产代码的送达确认要看提交证据）。
    if [ "\${OB_ECHO:-}" = "1" ]; then
      e=\$(awk '/Enter/{n=NR} END{print n+0}' "\$OB_LOG" 2>/dev/null)
      [ "\$e" -gt 0 ] && awk -v e="\$e" 'index(\$0," -l ")>0 && NR<e { sub(/.* -l /,""); print }' "\$OB_LOG"
    fi
    if [ -n "\${OB_SWITCH_AFTER:-}" ] && [ "\$n" -gt "\$OB_SWITCH_AFTER" ] && [ -n "\${OB_BOX2:-}" ]; then
      cat "\$OB_BOX2"
    else
      cat "\$OB_BOX"
    fi
    exit 0 ;;
esac
case "\$*" in
  *pane_current_command*) printf 'pi\n' ;;
  *pane_id*)              printf '%%1\n' ;;
  *pane_pid*)             printf '%s\n' "\$OB_PANE_PID" ;;
  *bracket_paste_flag*)   printf '1\n' ;;
  *window_name*)          printf '%s\n' "\${OB_WINDOW:-dev}" ;;
  *session_name*)         printf '%s\n' "$SESSION" ;;
  *list-windows*)         printf '%s\n' "\${OB_WINDOW:-dev}" ;;
  *has-session*)          exit 0 ;;
esac
exit 0
EOF
chmod +x "$OB_SHIM/tmux"
ob_box_empty_txt > "$TMP/ob-box-empty"
ob_box_draft_txt > "$TMP/ob-box-draft"
OB_BOX="$TMP/ob-box-empty"
OB_ENV=(env "PATH=$OB_SHIM:$PATH" "OB_LOG=$TMP/ob-calls.log" "OB_COUNT=$TMP/ob-count"
        "OB_CURSOR_Y=2" "OB_PANE_PID=$$" "OB_WINDOW=dev")
ob_run()  { "${OB_ENV[@]}" "$@"; }           # headless：tmux 全部走假 shim
ob_live() { "$@"; }                          # 真 pane 段落：必须用真 tmux（不能带 shim）
ob_box()  { OB_BOX="$1"; }                   # 夹具当前要假 tmux 报出的输入框内容
ob_reset() { : > "$TMP/ob-calls.log"; printf '0' > "$TMP/ob-count"; rm -rf "$REPO/.pi/team/state/outbox"; }

# ---------------------------------------------------------------- 12b-a. 守卫状态矩阵（E3 §1.5）
if bash "$SKILL_DIR/tests/guard-matrix.sh" >"$TMP/ob-guard.log" 2>&1; then
  ok "12b-a 守卫矩阵：E3 §1.5 + V7-F1 的 13 个实测状态全部与真值一致（含唯一允许的盲区：纯空白草稿）"
else
  bad "12b-a 守卫矩阵失败"; cat "$TMP/ob-guard.log"
fi
assert_has "$TMP/ob-guard.log" "guard matrix 全绿" "12b-a 矩阵自报全绿（不是只看退出码）"

# ---------------------------------------------------------------- 12b-b. 队列文件即契约（规格 requirement 2）
ob_reset
printf 'echo $(touch %s) `backtick` 多行第二行\n' "$TMP/ob-sentinel" > "$TMP/ob-payload"
ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --from pm --from-file "$TMP/ob-payload" >"$TMP/ob-enq.log" 2>&1
ENTRY="$(head -1 "$TMP/ob-enq.log")"
assert_file "$ENTRY" "12b-b enqueue 写出条目（stdout 给路径）"
assert_has "$ENTRY" "kind: say" "12b-b 头字段 kind"
assert_has "$ENTRY" "target: $SESSION:dev" "12b-b 头字段 target"
assert_has "$ENTRY" "from: pm" "12b-b 头字段 from"
assert_has "$ENTRY" "created: " "12b-b 头字段 created"
assert_has "$ENTRY" "dedup: -" "12b-b 头字段 dedup（没有键时是 -）"
assert_match "$ENTRY" "^---$" "12b-b 头与 payload 之间是 ---（字面量）"
assert_eq "12b-b payload 逐字节原样" "$(LC_ALL=C awk 'seen{print} $0=="---"{seen=1}' "$ENTRY")" "$(cat "$TMP/ob-payload")"
assert_not_file "$TMP/ob-sentinel" "12b-b payload 里的 \$(touch …) 没有被执行"
assert_eq "12b-b 没有留下 *.tmp" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.tmp' 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-b 入队不写任何键"

# FIFO：三条按 enqueue 顺序排队，list 的编号也是这个顺序
ob_reset; OB_BOX="$TMP/ob-box-draft"
for m in one two three; do ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --from pm --payload "$m" >/dev/null 2>&1; done
ob_run env OB_BOX="$OB_BOX" $TEAM outbox list >"$TMP/ob-list.log" 2>&1
assert_has "$TMP/ob-list.log" "队列 3 条" "12b-b list 数到 3 条"
assert_match "$TMP/ob-list.log" "#1  \[queued\] [0-9]+-0001-" "12b-b #1 是最早的条目（FIFO）"
assert_eq "12b-b list #1 = 名字最小的条目（FIFO 头）" \
  "$(awk '/^  #1  / {print $3}' "$TMP/ob-list.log")" \
  "$(ls -1 "$REPO/.pi/team/state/outbox"/*.msg 2>/dev/null | xargs -r -n1 basename | LC_ALL=C sort | head -1)"
assert_eq "12b-b list #3 = 名字最大的条目（FIFO 尾）" \
  "$(awk '/^  #3  / {print $3}' "$TMP/ob-list.log")" \
  "$(ls -1 "$REPO/.pi/team/state/outbox"/*.msg 2>/dev/null | xargs -r -n1 basename | LC_ALL=C sort | tail -1)"

# TEAM_STATE_DIR 搬走整个队列（规格 scenario：TEAM_STATE_DIR moves the queue）
ob_reset; OB_BOX="$TMP/ob-box-draft"
rm -rf "$TMP/ob-altstate"
ob_run env OB_BOX="$OB_BOX" TEAM_STATE_DIR="$TMP/ob-altstate" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "alt state" >/dev/null 2>&1
assert_eq "12b-b TEAM_STATE_DIR 搬家：条目落在 <temp>/outbox/" "$(find "$TMP/ob-altstate/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_eq "12b-b 搬家时仓库里不留下这份条目" "$(grep -rl "alt state" "$REPO/.pi/team/state/outbox" 2>/dev/null 2>/dev/null | wc -l | tr -d ' ')" "0"

# flush --now：排水的逃生门 —— 跳过守卫直投（旧行为）+ forced.log 记下条目
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --from pm --payload "flush now" >/dev/null 2>&1
ob_run env OB_BOX="$OB_BOX" $TEAM outbox flush --now >"$TMP/ob-flushnow.log" 2>&1 || true
assert_has "$TMP/ob-calls.log" "send-keys" "12b-b flush --now 真的打字"
assert_has "$REPO/.pi/team/state/outbox/forced.log" "entry=" "12b-b flush --now 的审计行点名条目"
assert_eq "12b-b flush --now 之后队列空了" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ---------------------------------------------------------------- 12b-c. 忙框：queued 不是 delivered（规格 requirement 4）
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM say dev "check the failing test" >"$TMP/ob-say-dirty.log" 2>&1 && ok "12b-c 脏输入框：say 退出码 0" || bad "12b-c 脏输入框：say 不该失败"
assert_has "$TMP/ob-say-dirty.log" "queued" "12b-c 输出含 queued"
assert_not "$TMP/ob-say-dirty.log" "已确认送达" "12b-c 排队时绝不说「已确认送达」"
assert_eq "12b-c 队列里恰好一条 dev 条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name "*dev*.msg" 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-c 一个键都没发"
assert_has "$REPO/docs/team/inbox/dev.md" "check the failing test" "12b-c durable 兜底：消息同时进了收件箱"

# --now：跳过守卫（旧行为）+ 审计
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM say dev "forced message" --now >"$TMP/ob-say-now.log" 2>&1 || true
assert_has "$TMP/ob-calls.log" "send-keys" "12b-c --now 真的打字（跳过守卫）"
assert_has "$REPO/.pi/team/state/outbox/forced.log" "kind=say" "12b-c --now 写 forced.log"
assert_has "$REPO/.pi/team/state/outbox/forced.log" "$SESSION:dev" "12b-c forced.log 点名目标"
assert_eq "12b-c --now 不入队" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# UNKNOWN pane（找不到输入框形状，例如非 Pi TUI）：按今天的行为投递 + 一行警告 + queue 不留条目
ob_reset
printf 'working…\nworking…\nworking…\n' > "$TMP/ob-box-unknown"
ob_run env OB_BOX="$TMP/ob-box-unknown" $TEAM say dev "deliver as today" >"$TMP/ob-unknown.log" 2>&1 || true
assert_has "$TMP/ob-unknown.log" "输入框形状无法识别" "12b-c 形状未知：给一行警告（不静默）"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-c 形状未知：按今天的行为投递（真的打字）"
assert_eq "12b-c 形状未知：不留队列条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ---------------------------------------------------------------- 12b-d. 去重 / TTL / 上限（规格 requirement 5、6）
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind knock --target "$SESSION:dev" --dedup 'dev|[auto]|abc' --payload 'same notice' >/dev/null 2>&1
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind knock --target "$SESSION:dev" --dedup 'dev|[auto]|abc' --payload 'same notice' >"$TMP/ob-dup.log" 2>&1 || true
assert_has "$TMP/ob-dup.log" "duplicate" "12b-d 同一个 dedup 键第二次被拒（输出 duplicate）"
assert_eq "12b-d 重复通知只有一个条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind knock --target "$SESSION:dev" --dedup 'dev|[auto]|abc' --payload 'different body' >"$TMP/ob-dup2.log" 2>&1 || true
assert_has "$TMP/ob-dup2.log" "duplicate" "12b-d 同键不同正文也算重复（键是契约，不是正文）"

# TTL：脏框 + TEAM_DEFER_TTL=1 → 排水时转 held，一个键都不打
ob_reset; OB_BOX="$TMP/ob-box-draft"
printf 'held body\n' > "$TMP/ob-held.txt"
ob_run env OB_BOX="$OB_BOX" $TEAM notify pm --from-file "$TMP/ob-held.txt" >/dev/null 2>&1 || true   # PM 没在跑：只落收件箱
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind notify --target "$SESSION:pm" --from dev --payload 'held body' >/dev/null 2>&1
sleep 2
ob_run env OB_BOX="$OB_BOX" TEAM_DEFER_TTL=1 $TEAM outbox flush >"$TMP/ob-ttl.log" 2>&1 || true
assert_eq "12b-d TTL 到了 → 条目进 held/" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=expired-ttl" "12b-d HOLDING.log 记下原因"
assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "held-since=" "12b-d HOLDING.log 记下 hold 时刻"
assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "attempts=" "12b-d HOLDING.log 记下尝试次数"
assert_has "$REPO/docs/team/inbox/pm.md" "held body" "12b-d 过期前 payload 已经是 durable 的（收件箱里有）"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-d 过期不投递（不写一个键）"

# 上限：MAX=2 时第三条把最老的挤进 held/（cap 事件可见）
ob_reset; OB_BOX="$TMP/ob-box-draft"
for m in m1 m2 m3; do ob_run env OB_BOX="$OB_BOX" TEAM_OUTBOX_MAX=2 $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "$m" >/dev/null 2>&1; done
assert_eq "12b-d 活动条目不超过 TEAM_OUTBOX_MAX" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "2"
assert_eq "12b-d 最老的那条被升级到 held/" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=cap" "12b-d cap 事件写进 HOLDING.log"

# drop：人显式丢弃
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "dropme" >/dev/null 2>&1
ob_run env OB_BOX="$OB_BOX" $TEAM outbox drop 1 >"$TMP/ob-drop.log" 2>&1 && ok "12b-d drop 退出码 0" || bad "12b-d drop 失败"
assert_has "$TMP/ob-drop.log" "已丢弃" "12b-d drop 打印丢了什么"
assert_eq "12b-d drop 之后队列空了" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# 第二份草稿：第一条条目不变，两条按 FIFO 顺序投出去（规格 scenario）
ob_reset; OB_BOX="$TMP/ob-box-draft"
printf 'first draft body\n' > "$TMP/ob-d1.txt"
printf 'second draft body\n' > "$TMP/ob-d2.txt"
ob_run env OB_BOX="$OB_BOX" $TEAM draft send "$TMP/ob-d1.txt" --target "$SESSION:dev" >/dev/null 2>&1 || true
FIRST_ENTRY="$(ls -1 "$REPO/.pi/team/state/outbox"/*.msg 2>/dev/null | head -1)"
ob_run env OB_BOX="$OB_BOX" $TEAM draft send "$TMP/ob-d2.txt" --target "$SESSION:dev" >/dev/null 2>&1 || true
assert_eq "12b-d 两份草稿 = 两条条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "2"
assert_eq "12b-d 第一条条目的 payload 没有被改写" "$(LC_ALL=C awk 'seen{print} $0=="---"{seen=1}' "$FIRST_ENTRY")" "first draft body"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 TEAM_DEFER_TTL=1 $TEAM outbox flush >"$TMP/ob-dflush.log" 2>&1 || true
ob_first_ln="$(grep -n 'send-keys .*-l first draft body' "$TMP/ob-calls.log" | head -1 | cut -d: -f1)"
ob_second_ln="$(grep -n 'send-keys .*-l second draft body' "$TMP/ob-calls.log" | head -1 | cut -d: -f1)"
assert_eq "12b-d 两条都打了字，且第一条在前（FIFO）" \
  "$([ -n "$ob_first_ln" ] && [ -n "$ob_second_ln" ] && [ "$ob_first_ln" -lt "$ob_second_ln" ] && echo yes || echo no)" "yes"

# ---------------------------------------------------------------- 12b-e. 排水的 claim 与「确认不了就 held，绝不重复粘贴」
# 「payload 卡在框里一直不消失」的 pane：V7-F4 把判据改成「payload 离开输入框」，所以这个夹具
# 必须是「打完字后框里一直显示 payload」—— OB_SWITCH_AFTER=6：前 6 次 capture（两轮守卫检查各 2 次 /
# 指纹快照 / Enter 前复检）看空框，第 7 次起换成 payload 卡在框里的样子 → 补一次 Enter 也没用 → held。旧的
# 「指纹永远不变」夹具在新判据下不成立：框从 EMPTY 变成 BUSY 本身就 readable，投递成立。
ob_reset; OB_BOX="$TMP/ob-box-empty"
printf '%s\n' "$(printf '%.0s─' $(seq 1 80))" "never lands" "" "" " k3  Kimi Coding  max" "$(printf '%.0s─' $(seq 1 80))" "footer" > "$TMP/ob-box-stuck"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --inbox-defer dev --payload "never lands" >/dev/null 2>&1
assert_not "$REPO/docs/team/inbox/dev.md" "never lands" "12b-e F5：--inbox-defer 入队时不写收件箱（还不是 durable 待办）"
# V8-F4b：held 必须**立即**发生（补 Enter 后框仍非空的那一刻），不许等 TTL——TTL=300 下依然 held 才算
ob_run env OB_BOX="$TMP/ob-box-empty" OB_SWITCH_AFTER=6 OB_BOX2="$TMP/ob-box-stuck" TEAM_DEFER_TTL=300 $TEAM outbox flush >"$TMP/ob-unconfirmed.log" 2>&1 || true
assert_eq "12b-e 未确认的条目立即进 held/（F4b：不等 TTL）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=unconfirmed" "12b-e held 原因 = unconfirmed"
assert_eq "12b-e 没有第二条副本（绝不重复粘贴）" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "12b-e payload 只打了一次" "$(grep -c "send-keys.*never lands" "$TMP/ob-calls.log" || true)" "1"
assert_eq "12b-e Enter = 1 次原始 + 至多 1 次补发" "$(grep -c "Enter" "$TMP/ob-calls.log" || true)" "2"
assert_has "$REPO/docs/team/inbox/dev.md" "never lands" "12b-e F5：进 held/ 那一刻 durable 行落进收件箱"
# V8-F4c：unconfirmed 是终态——之后的排水（含 flush --now）绝不重贴（人自己的 Enter 可能已把卡在框里的
# payload 提交过一次，再贴就是第二遍）
ob_run env OB_BOX="$TMP/ob-box-empty" $TEAM outbox flush >/dev/null 2>&1 || true
assert_eq "12b-e unconfirmed 终态：第二次 flush 不重贴" "$(grep -c "send-keys.*never lands" "$TMP/ob-calls.log" || true)" "1"
ob_run env OB_BOX="$TMP/ob-box-empty" $TEAM outbox flush --now >/dev/null 2>&1 || true
assert_eq "12b-e unconfirmed 终态：flush --now 也不重贴" "$(grep -c "send-keys.*never lands" "$TMP/ob-calls.log" || true)" "1"
assert_eq "12b-e unconfirmed 终态：没有 forced.log（--now 一个键都没发）" "$(wc -l < "$REPO/.pi/team/state/outbox/forced.log" 2>/dev/null | tr -d ' ' || echo 0)" "0"
assert_eq "12b-e unconfirmed 终态：条目留在 held/（可见、可 drop）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"

# claim：两个排水并发时一个条目只投一次
ob_reset; OB_BOX="$TMP/ob-box-empty"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "race claim" >/dev/null 2>&1
( ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 TEAM_DEFER_TTL=0 $TEAM outbox flush >"$TMP/ob-race-a.log" 2>&1 || true ) &
OB_RACE_A=$!
( ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 TEAM_DEFER_TTL=0 $TEAM outbox flush >"$TMP/ob-race-b.log" 2>&1 || true ) &
OB_RACE_B=$!
# 只等这两个：裸 `wait` 会连未来任何后台作业一起等（M33 的 $TMP 哨兵就是这么被卡死过一次）
wait "$OB_RACE_A" "$OB_RACE_B"
assert_eq "12b-e 并发排水：payload 只打了一次" "$(grep -c "send-keys.*race claim" "$TMP/ob-calls.log" || true)" "1"
assert_eq "12b-e 并发排水：条目只投一次且队列清空（V7-F4：空框回读=已投递，不再是旧指纹判据的 unconfirmed+held）" "$(find "$REPO/.pi/team/state/outbox" "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# 巡检的一拍也排水，但**不变成投递 daemon**：不新建窗口、不留后台进程（规格 requirement 3 scenario）
# 真跑一拍 `watch --once` 会写 capacity.log / watchdog.last（真实的巡检留痕）——FAST 模式有
# 「capacity.log 不得存在」的全局不变量，所以这一段只在完整门禁跑；FAST 里显式 SKIP。
if [ "${TEAM_SMOKE_FAST:-0}" = "1" ]; then
  fast_skip "12b-e·巡检一拍排水" "真跑一拍会写 capacity.log（FAST 的全局不变量不许）——完整门禁覆盖"
else
ob_reset; OB_BOX="$TMP/ob-box-draft"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "tick holds" >/dev/null 2>&1
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$OB_BOX" $TEAM watch --once >"$TMP/ob-tick.log" 2>&1 || true
assert_not "$TMP/ob-calls.log" "new-window" "12b-e 巡检一拍没有新建 tmux 窗口"
assert_not "$TMP/ob-calls.log" "new-session" "12b-e 巡检一拍没有新建 tmux session"
assert_not "$TMP/ob-calls.log" "split-window" "12b-e 巡检一拍没有开新 pane"
assert_not "$TMP/ob-calls.log" "run-shell" "12b-e 巡检一拍没有起后台 shell"
# 「不留后台进程」：只看**我们夹具的**进程（别的项目/别的会话的进程不归这里管），失败时把现场打出来
ob_ling="$(ps -eo args= 2>/dev/null | grep -F 'outbox flush' | grep -F "$REPO" || true)"
assert_eq "12b-e 巡检一拍之后没有残留的夹具进程" "$([ -z "$ob_ling" ] && echo none || printf '%s' "$ob_ling" | head -1 | cut -c1-100)" "none"
assert_eq "12b-e 巡检一拍没有留下 claim 残迹" "$(find "$REPO/.pi/team/state/outbox" -name '*.claim' 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "12b-e 脏框下巡检一拍把条目留在队列里" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
fi

# ---------------------------------------------------------------- 12b-f. 竞态：检查与打字之间出现草稿（规格 requirement 1 第 4 条）
# 第 1 次 capture-pane 看到空框（判定 EMPTY），第 2 次（打字前的复检）看到草稿 → 一个键都不该写
ob_reset; OB_BOX="$TMP/ob-box-empty"
ob_run env OB_BOX="$OB_BOX" OB_SWITCH_AFTER=1 OB_BOX2="$TMP/ob-box-draft" $TEAM say dev "must not type" >"$TMP/ob-race-say.log" 2>&1 || true
assert_has "$TMP/ob-race-say.log" "queued" "12b-f 复检发现草稿 → 报 queued"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-f 一个键都没发（连 Enter 都没有）"
assert_eq "12b-f 消息进了队列" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"

# ---------------------------------------------------------------- 12b-g. 可见性（规格 requirement 8）
ob_reset
for i in 1 2; do ob_run env OB_BOX="$OB_BOX" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "vis$i" >/dev/null 2>&1; done
mkdir -p "$REPO/.pi/team/state/outbox/held"
for f in "$REPO/.pi/team/state/outbox"/*.msg; do mv "$f" "$REPO/.pi/team/state/outbox/held/" 2>/dev/null || true; done
ob_run env OB_BOX="$OB_BOX" $TEAM status >"$TMP/ob-status.log" 2>&1 || true
ob_run env OB_BOX="$OB_BOX" $TEAM digest >"$TMP/ob-digest.log" 2>&1 || true
assert_has "$TMP/ob-status.log" "outbox 2 条待投递" "12b-g status 打印 outbox 行（含条数）"
assert_has "$TMP/ob-digest.log" "outbox 2 条待投递" "12b-g digest 打印同一个 outbox 行"
ob_reset
ob_run env OB_BOX="$OB_BOX" $TEAM status >"$TMP/ob-status-empty.log" 2>&1 || true
assert_not "$TMP/ob-status-empty.log" "outbox" "12b-g 空队列时 status 一行都不加"
: > "$REPO/.pi/team/state/outbox/forced.log"
ob_run env OB_BOX="$OB_BOX" $TEAM status >"$TMP/ob-status-empty2.log" 2>&1 || true
assert_not "$TMP/ob-status-empty2.log" "outbox" "12b-g 空队列（只剩 forced.log）时也不加行"

# M17：held 条目按「框里有没有残留」分档。HOLDING.log 的 reason 是格式契约，digest / status /
# outbox list / 面板队列块都从它读 —— 这里用两份手工落盘的 held 条目把四个出口全钉住。
ob_reset
OB_RES_SEQ=0
mk_residue_entry() { # <payload> <reason> → 打印条目名
  local pl="$1" why="$2" name
  OB_RES_SEQ=$((OB_RES_SEQ + 1))
  mkdir -p "$REPO/.pi/team/state/outbox/held"
  name="$(date +%s)000-$(printf '%04d' "$OB_RES_SEQ")-residue.msg"
  { printf 'kind: say\ntarget: %s:dev\nfrom: pm\ncreated: x\ndedup: -\n---\n' "$SESSION"; printf '%s\n' "$pl"; } \
    > "$REPO/.pi/team/state/outbox/held/$name"
  printf '%s name=%s reason=%s held-since=x attempts=1 target=%s:dev\n' \
    "$(date -u +%FT%TZ)" "$name" "$why" "$SESSION" >> "$REPO/.pi/team/state/outbox/HOLDING.log"
  printf '%s\n' "$name"
}
mk_residue_entry 'residue retracted' draft-raced-retracted >/dev/null
mk_residue_entry 'residue left' draft-raced-left >/dev/null
ob_run env OB_BOX="$OB_BOX" $TEAM status >"$TMP/ob-residue-status.log" 2>&1 || true
ob_run env OB_BOX="$OB_BOX" $TEAM digest >"$TMP/ob-residue-digest.log" 2>&1 || true
assert_has "$TMP/ob-residue-status.log" "已收回 1 · 留在框里 1" "12b-g M17：status 的 outbox 行带「已收回/留在框里」分档"
assert_has "$TMP/ob-residue-digest.log" "已收回 1 · 留在框里 1" "12b-g M17：digest 同一行也带分档"
ob_run env OB_BOX="$OB_BOX" $TEAM outbox list >"$TMP/ob-residue-list.log" 2>&1 || true
assert_has "$TMP/ob-residue-list.log" "held-reason=draft-raced-retracted" "12b-g M17：outbox list 逐条给出「已收回」状态"
assert_has "$TMP/ob-residue-list.log" "held-reason=draft-raced-left" "12b-g M17：outbox list 逐条给出「留在框里」状态"
# 面板的数据路径：队列块（team __panel-data --block outbox_list）把 reason 原样交给面板队列页
if ob_run env OB_BOX="$OB_BOX" $TEAM --root "$REPO" __panel-data --block outbox_list >"$TMP/ob-residue-panel.json" 2>&1; then
  assert_has "$TMP/ob-residue-panel.json" "draft-raced-retracted" "12b-g M17：面板队列块带「已收回」的原因"
  assert_has "$TMP/ob-residue-panel.json" "draft-raced-left" "12b-g M17：面板队列块带「留在框里」的原因"
else
  bad "12b-g M17：__panel-data --block outbox_list 跑不起来（面板可见性无法证明）"; cat "$TMP/ob-residue-panel.json"
fi
ob_reset   # 手工造的残留条目只服务本节断言，不留给 12b-h 的端到端场景

# ---------------------------------------------------------------- 12b-h0. M24 折叠占位符判据（纯函数，快模式照跑）
section "12b-h0 · M24 输入框判据：真实 pi 的两条折叠路径"
# 背景：真实 pi 0.85.1 有两种折叠（都实测过，见 tests/pm-box-real.sh 与 docs/team/reports/M24-dev2.md）：
#   * 行数多 → `[paste #N +K lines]`（M17 已处理）；
#   * 行数少、**字符**多 → `[paste #N <chars> chars]`（字符 = 码点，不是字节）。
# 旧代码只认第一种 → 现场事故里我们自己的粘贴被当成「混了别人的字」→ 不按 Enter（rc 3）。
# 这五条是判据本身（不需要真 tmux / 真 pi），端到端在 12b-h ⑱d/⑲。
ob_boxonly() { # <框文本> <payload> → yes/no
  ( cd "$REPO" && bash -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/outbox.sh"; team_load_config >/dev/null 2>&1 || true; team_box_text_holds_only "$2" "$3" && printf yes || printf no' _ "$SKILL_DIR" "$1" "$2" )
}
ob_cjk="$(printf '%s' '中文行中文行中文行中文行')"   # 12 个字符 / 36 个字节
assert_eq "12b-h0 M24：char 折叠（行数少、字符多）被认成我们的" \
  "$(ob_boxonly '[paste #1 304 chars]' "$(printf 'x%.0s' $(seq 1 304))")" "yes"
assert_eq "12b-h0 M24：字符数对不上 → 不是我们的（判定力不降）" \
  "$(ob_boxonly '[paste #1 305 chars]' "$(printf 'x%.0s' $(seq 1 304))")" "no"
assert_eq "12b-h0 M24：chars 数的是**字符**不是字节（中文 12 字 = 36 字节）" \
  "$(ob_boxonly '[paste #1 12 chars]' "$ob_cjk")" "yes"
assert_eq "12b-h0 M24：按字节数报的占位符不是我们的（真实 pi 从不用字节）" \
  "$(ob_boxonly '[paste #1 36 chars]' "$ob_cjk")" "no"
assert_eq "12b-h0 M24：行数折叠（老形状）仍然认" \
  "$(ob_boxonly '[paste #1 +3 lines]' "$(printf 'a\nb\nc')")" "yes"

# ---------------------------------------------------------------- 12b-h0b. M45 更新横幅判据（纯函数，快模式照跑）
section "12b-h0b · M45 输入框判据：pi 的更新横幅（整行 ─ 与框边框同形等宽）"
# 现场（真实现场，不是夹具抖动）：pi 0.86.0 发布后，pi 的 TUI 在输入框**上方**画
# 「Update Available / Package Updates Available」横幅 —— chat 区的 DynamicBorder 与输入框
# 边框都是**整行 ─、等宽**。老判据（几何「取最高」）把横幅的上界当成框的上边框 → 框被算大
# → 空框里读到横幅文字 + 框自己的上边框 → BUSY / RETRACT=failed（main 上 M28 段两次红）。
# 这一节全是纯函数（不开 tmux、不碰真账本）：真帧 + 合成帧喂 _team_box_rows_of_frame；
# 端到端（真 pane + 假 TUI 画横幅）在 12b-h（非 FAST）。
M45_FRAME_DIR="$SKILL_DIR/tests/frames"
M45_FRAME_REAL="$M45_FRAME_DIR/pi-0.85.1-update-banner.txt"
M45_CY_REAL=26        # 真帧实拍时的光标行（1-based；框内第一个内容行）
assert_file "$M45_FRAME_REAL" "M45：真实现场帧（真 pi 0.85.1 实拍）在 tests/frames/"

# 纯帧探针：与生产同一条实现（source 后直接调纯函数），不开 tmux。
#   M45_NO_STRIP=1 → 把 _team_box_banner_rows 变成空实现（**破坏实现**）：
#     同一份帧必须回到「框算大 → 读出横幅文字」的老形状 —— 这是本节的翻转闸门。
M45_PROBE="$TMP/m45-frame-probe.sh"
cat > "$M45_PROBE" <<'EOS'
#!/usr/bin/env bash
# <帧文件> <cy> → banner_rows / geometry / box_nows / holds_only（stdout，一行一项）
set -u
SKILL_DIR="$1"; FR="$2"; CY="$3"
cd "${M45_REPO:-$PWD}"
. "$SKILL_DIR/scripts/lib/common.sh"; . "$SKILL_DIR/scripts/lib/outbox.sh"
team_load_config >/dev/null 2>&1 || true
[ "${M45_NO_STRIP:-0}" = "1" ] && _team_box_banner_rows() { :; }   # 破坏实现（翻转用）
printf 'banner_rows=[%s]\n' "$(_team_box_banner_rows "$CY" < "$FR")"
printf 'geometry=[%s]\n' "$(_team_box_geometry "$CY" < "$FR")"
text="$(_team_box_text_of_frame "$CY" < "$FR")"   # P67：与生产提取同一实现（不再自带排除）
printf 'box_nows=[%s]\n' "$(printf '%s' "$text" | tr -d '[:space:]')"
if [ -n "${M45_PAYLOAD:-}" ]; then
  team_box_text_holds_only "$text" "$M45_PAYLOAD" && printf 'holds_only=yes\n' || printf 'holds_only=no\n'
fi
EOS
chmod +x "$M45_PROBE"
m45_probe() { # <帧文件> <cy> [payload] → 打印探针输出
  ( cd "$REPO" && env TEAM_NOOP=1 M45_PAYLOAD="${3:-}" bash "$M45_PROBE" "$SKILL_DIR" "$1" "$2" 2>&1 )
}
m45_probe_red() { # 同上，但破坏实现（_team_box_banner_rows 变空）
  ( cd "$REPO" && env M45_NO_STRIP=1 M45_PAYLOAD="${3:-}" bash "$M45_PROBE" "$SKILL_DIR" "$1" "$2" 2>&1 )
}
m45_rule() { printf '─%.0s' $(seq 1 "${1:-40}"); printf '\n'; }
M45_F="$TMP/m45-frames"; rm -rf "$M45_F"; mkdir -p "$M45_F"

# ── 帧 A：真帧（120 列，版本 + 扩展包两个横幅，空闲空框）──────────────────────────
M45_A="$(m45_probe "$M45_FRAME_REAL" "$M45_CY_REAL")"
assert_has_echo "$M45_A" "geometry=[24 29]" "M45 真帧：几何落在真正的输入框上（24 29，不是横幅上界 11）"
assert_has_echo "$M45_A" "box_nows=[]" "M45 真帧：空闲空框读成空（横幅文字不是框内容）"
assert_has_echo "$M45_A" "banner_rows=[11 12 13 14 15 16 18 19 20 21 22 ]" "M45 真帧：两个横幅块的行都被认出来（11–16 包横幅 / 18–22 版本横幅）"
M45_A_RED="$(m45_probe_red "$M45_FRAME_REAL" "$M45_CY_REAL")"
assert_has_echo "$M45_A_RED" "geometry=[11 29]" "M45 真帧翻转（破坏实现）：几何退回横幅上界（11）—— 证明这个形状确实是老判据的错误来源"
assert_has_echo "$M45_A_RED" "UpdateAvailable" \
  "M45 真帧翻转（破坏实现）：空框读出横幅文字（老判据的真实现场）"

# ── 帧 B/C：合成帧（40 列）——「横幅 + 空框」与「横幅 + 真草稿」────────────────────
# 行号：1 开界 / 2–4 头与尾 / 5 闭界 / 6 空 / 7 框上边框 / 8–9 内容 / 10 提示行 / 11 框下边框 / 12 页脚
# P67：提示行拼写改成**实测形状**（` fake-pi  Fake Pi  max`）——旧的 ` fake-pi 1.0` 不匹配
# 状态行形状，在新判据下就是内容（空框夹具会变红，理由不对）。所有合成帧同一处改动。
m45_frame() { # <帧文件> <第 8 行内容> [第二内容行]
  { m45_rule 40; printf ' Update Available\n'; printf ' New version 0.86.0 is available. Run pi update\n'
    printf ' Changelog: https://pi.dev/changelog\n'; m45_rule 40; printf '\n'; m45_rule 40
    printf ' %s\n' "$2"; [ $# -ge 3 ] && printf ' %s\n' "$3" || printf '\n'
    printf ' fake-pi  Fake Pi  max\n'; m45_rule 40; printf ' footer\n'; } > "$1"
}
m45_frame "$M45_F/banner-empty.txt" ""
M45_B="$(m45_probe "$M45_F/banner-empty.txt" 8)"
assert_has_echo "$M45_B" "geometry=[7 11]" "M45 合成帧：横幅在上、框在下的形状里几何仍然找对框"
assert_has_echo "$M45_B" "box_nows=[]" "M45 合成帧：带横幅的空框 → 空"
assert_has_echo "$M45_B" "banner_rows=[1 2 3 4 5 ]" "M45 合成帧：横幅块被认出（1–5）"
m45_frame "$M45_F/banner-draft.txt" "半句草稿 half a sentence"
M45_C="$(m45_probe "$M45_F/banner-draft.txt" 8 "半句草稿 half a sentence")"
assert_has_echo "$M45_C" "box_nows=[半句草稿halfasentence]" "M45 合成帧：横幅 + 真草稿 → 读出的仍然是**真草稿**（不是横幅）"
assert_has_echo "$M45_C" "holds_only=yes" "M45 合成帧：带横幅的真草稿仍然是「框里只有它」"
assert_has_echo "$M45_C" "geometry=[7 11]" "M45 合成帧：有草稿时几何不受横幅影响"

# ── 帧 D/E：对抗形状 —— 草稿自己长得像横幅块（绝不许变成「框读不出来」）────────────
# D：草稿块（整行 ─ + 两行头 + Changelog + 整行 ─）画在框内、开界不是框边框。
{ m45_rule 40; m45_rule 40; printf ' Update Available\n'; printf ' New version 1.0.0 is available. Run pi update\n'
  printf ' Changelog: https://x\n'; m45_rule 40; printf ' fake-pi  Fake Pi  max\n'; m45_rule 40; printf ' footer\n'; } \
  > "$M45_F/draft-like-block.txt"
M45_D="$(m45_probe "$M45_F/draft-like-block.txt" 4)"
assert_has_echo "$M45_D" "UpdateAvailable" \
  "M45 对抗帧①：草稿自己像横幅块 → 仍然是框内容（BUSY，不粘连）"
assert_not_echo "$M45_D" "box_nows=[]" \
  "M45 对抗帧①：框文本非空（没被「排除横幅」吞干净 → 不会判 EMPTY 去白打字）"
assert_has_echo "$M45_D" "geometry=[1 8]" "M45 对抗帧①：几何仍然找得出框（没退化成 NONE）"
# E：最难的一种 —— 被误标的块把框的上边框也包了进去（跳过横幅就一个框都找不出来）。
{ m45_rule 40; printf ' Update Available\n'; printf ' New version 1.0.0 is available. Run pi update\n'
  printf ' Changelog: https://x\n'; m45_rule 40; printf ' fake-pi  Fake Pi  max\n'; m45_rule 40; printf ' footer\n'; } \
  > "$M45_F/draft-top.txt"
M45_E="$(m45_probe "$M45_F/draft-top.txt" 3)"
assert_not_echo "$M45_E" "geometry=[]" "M45 对抗帧②：跳过横幅后一个框都找不出来时退回保守行为（绝不退成 NONE → 守卫失效）"
assert_has_echo "$M45_E" "box_nows=[UpdateAvailableNewversion1.0.0isavailable.RunpiupdateChangelog:https://x────────────────────────────────────────]" \
  "M45 对抗帧②：内容仍然读作框内容（BUSY）——被误标的块喂退了保守分支，没有白打字；P67 起边框邻行\n     （` Changelog: https://x`，非状态行形状）也是内容，所以期望串按帧的真实内容加长了这一段；P80：下边框改取最低合格候选后几何 [1 5]→[1 7]，框自带的上边框那一行（40 个 ─）现在也落在框内算内容，期望串据此再加这一段（更强，不是放宽）"
# 对照：没有横幅的普通框 —— 判据一个字都没变
{ m45_rule 40; printf '\n'; printf ' half sentence\n'; printf ' fake-pi  Fake Pi  max\n'; m45_rule 40; printf ' footer\n'; } > "$M45_F/no-banner.txt"
M45_F0="$(m45_probe "$M45_F/no-banner.txt" 2)"
assert_has_echo "$M45_F0" "geometry=[1 5]" "M45 对照：没有横幅时几何与行为不变"
assert_has_echo "$M45_F0" "box_nows=[halfsentence]" "M45 对照：普通草稿照旧读得出来"
assert_has_echo "$M45_F0" "banner_rows=[]" "M45 对照：没有横幅时一行都不标"

# ---------------------------------------------------------------- 12b-h0d. P80 下边框候选（纯帧，快模式照跑）
section "12b-h0d · P80 下边框判据：最低的合格规则行（草稿自己的框线留在框内）"
# 现场（P74 的 F1；V9-A4/A5/A8/A10 缺陷类的另一端）：判据只钉了**上**边框取「最高的」候选
# （V9-A4/A5/A8/A10），下边框一直是「最近优先」—— 草稿自己在光标下方画一条等宽框线（粘贴的
# Markdown 分隔线/表格边框，裁切型 TUI 可达）就成了下边框：框被定位得**太小**，框线以下的草稿
# 落在框外 → 脏框判空 → 就绪门放行、payload 打进人的草稿（D20 损害；与 P67 是同一类缺陷的两头）。
# P80：下边框 = 光标下方**最低的**合格整行规则行（上边框 HIGHEST 的镜像）。方向单调：相对
# 「最近优先」框只会变大，判定只可能从 EMPTY 移向 BUSY，绝不反向（本段逐帧断言两个方向）。
# 这一节是**纯帧**（不开 tmux、不跑 pi，FAST 照跑）：八份合成帧（tests/frames/p78-*.txt，
# README 里明说是「裁切型 TUI」的合成模型，不是真 pi 实拍）+ 五份已存真帧；每帧先按生产判据打
# geometry / box_nows / verdict，再把候选顺序影子成升序（= 旧的最近优先）跑第二遍（**红侧**，
# 可证伪）：红侧每一次翻转都证明这条判据真的咬在实现上，每一次不变都钉住控制帧。
P80_FD="$SKILL_DIR/tests/frames"
P80_PROBE="$TMP/p80-frame-probe.sh"
cat > "$P80_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <帧文件> <光标行> [shadow] [payload] → geometry / box_nows / verdict=… rc=… [holds_only=…]
# shadow=1：把下边框候选的**顺序**影子成升序（= 旧的「最近优先」）—— 红侧，不是产品开关。
set -u
SKILL_DIR="$1"; FR="$2"; CY="$3"; SHADOW="${4:-0}"; PAYLOAD="${5:-}"
. "$SKILL_DIR/scripts/lib/common.sh"; . "$SKILL_DIR/scripts/lib/outbox.sh"
. "$SKILL_DIR/tests/lib/box-judge.sh"
[ "$SHADOW" = "1" ] && _team_box_bottom_candidate_order() { cat; }
printf 'geometry=[%s]\n' "$(_team_box_geometry "$CY" < "$FR")"
text="$(_team_box_text_of_frame "$CY" < "$FR" 2>/dev/null || true)"
printf 'box_nows=[%s]\n' "$(printf '%s' "$text" | tr -d '[:space:]')"
if v="$(team_box_frame_verdict "$CY" < "$FR" 2>/dev/null)"; then printf 'verdict=%s rc=0\n' "$v"
else printf 'verdict=%s rc=1\n' "$v"; fi
if [ -n "$PAYLOAD" ]; then
  if team_box_text_holds_only "$text" "$PAYLOAD"; then printf 'holds_only=only-ours\n'; else printf 'holds_only=extra-text\n'; fi
fi
EOS
chmod +x "$P80_PROBE"
p80_probe() { # <帧> <光标行> [shadow] [payload]
  ( cd "$REPO" && bash "$P80_PROBE" "$SKILL_DIR" "$1" "$2" "${3:-0}" "${4:-}" 2>&1 )
}
P80_FM() { bash "$SKILL_DIR/tests/pm-box-real.sh" --frame "$1" --cursor "$2" 2>&1; }
P80_R40="$(printf '─%.0s' $(seq 1 40))"
P80_F1="$P80_FD/p78-draft-rule-below-cursor.txt"
P80_F2="$P80_FD/p78-draft-rule-only.txt"
P80_F3="$P80_FD/p78-wider-rule-below-cursor.txt"
P80_F4="$P80_FD/p78-spinner-row-below-cursor.txt"
P80_F5="$P80_FD/p78-cursor-mid-draft.txt"
P80_F6="$P80_FD/p78-conversation-rule-below-box.txt"
P80_F7="$P80_FD/p78-draft-rule-below-cursor-line.txt"
P80_F8="$P80_FD/p78-draft-rule-blank-region.txt"
for _p80f in "$P80_F1" "$P80_F2" "$P80_F3" "$P80_F4" "$P80_F5" "$P80_F6" "$P80_F7" "$P80_F8"; do
  assert_file "$_p80f" "P80：合成帧 $(basename "$_p80f") 在 tests/frames/（裁切型 TUI 模型，README 明说合成）"
done

# ── 绿侧：草稿自己在光标下方画的框线是内容（框扩到最低候选）────────────────────
P80_G1="$(p80_probe "$P80_F1" 2)"
assert_has_echo "$P80_G1" "geometry=[1 5]" "P80 绿侧①：草稿框线下方还有草稿 → 框取最低候选 [1 5]（不是最近的 [1 3]）"
assert_has_echo "$P80_G1" "box_nows=[$P80_R40" "P80 绿侧①：草稿自己的框线行落在框**内**算内容"
assert_has_echo "$P80_G1" "drafttextbelowmyownrule]" "P80 绿侧①：框线下面的草稿文字也在框内"
assert_has_echo "$P80_G1" "verdict=idle-read=NOT-EMPTY rc=1" "P80 绿侧①：判忙 —— P74 的红形状不再放行"
P80_G2="$(p80_probe "$P80_F2" 2)"
assert_has_echo "$P80_G2" "geometry=[1 4]" "P80 绿侧①b：草稿只有一条框线 → [1 4]"
assert_has_echo "$P80_G2" "verdict=idle-read=NOT-EMPTY rc=1" "P80 绿侧①b：判忙（保守读法，绝不放行）"
P80_G7="$(p80_probe "$P80_F7" 2 0 'half a sentence')"
assert_has_echo "$P80_G7" "moredraft]" "P80 绿侧⑦：框线以下的 ` more draft` 也在框里（holds_only 看得见整个框）"
assert_has_echo "$P80_G7" "holds_only=extra-text" "P80 绿侧⑦：payload 只等于框线上半段 → extra-text（P80 前是 only-ours）"
P80_G8="$(p80_probe "$P80_F8" 2)"
assert_has_echo "$P80_G8" "geometry=[1 5]" "P80 绿侧⑧：框线与真下边框之间只有空行时仍然扩框（备选规则在这里会读回 EMPTY）"
assert_has_echo "$P80_G8" "verdict=idle-read=NOT-EMPTY rc=1" "P80 绿侧⑧：空区域不影响规则 → NOT-EMPTY"

# ── 控制帧：两个方向逐字相同（更宽的 rule / spinner 行 / 光标在草稿中间）────────
P80_G3="$(p80_probe "$P80_F3" 2)"; P80_R3="$(p80_probe "$P80_F3" 2 1)"
assert_eq "P80 对照②：更宽的草稿 rule（不配对）两个方向逐字相同" "$P80_R3" "$P80_G3"
assert_has_echo "$P80_G3" "geometry=[1 5]" "P80 对照②：宽行不能当边框 → 几何不变 [1 5]"
assert_has_echo "$P80_G3" "verdict=idle-read=NOT-EMPTY rc=1" "P80 对照②：判定不变（本来就读作内容）"
P80_G4="$(p80_probe "$P80_F4" 2)"; P80_R4="$(p80_probe "$P80_F4" 2 1)"
assert_eq "P80 对照③：spinner 形状行两个方向逐字相同" "$P80_R4" "$P80_G4"
assert_has_echo "$P80_G4" "geometry=[1 5]" "P80 对照③：下边框候选只认整行 ─ → spinner 行留在框内"
assert_has_echo "$P80_G4" "Blanching" "P80 对照③：spinner 行是框内容（不是边框）"
P80_G5="$(p80_probe "$P80_F5" 3)"; P80_R5="$(p80_probe "$P80_F5" 3 1)"
assert_eq "P80 对照⑤：光标在三行草稿中间两个方向逐字相同" "$P80_R5" "$P80_G5"
assert_has_echo "$P80_G5" "box_nows=[draftline1draftline2draftline3]" "P80 对照⑤：三行草稿全部读出"

# ── 代价形状（记录在案，不是回归）：框下方的整行 rule 把框撑大 → 判忙 ──────────
P80_G6="$(p80_probe "$P80_F6" 2)"
assert_has_echo "$P80_G6" "geometry=[1 4]" "P80 代价⑥：空框正下方紧贴一条 rule → 框扩到 [1 4]（troubleshooting §3 写明）"
assert_has_echo "$P80_G6" "verdict=idle-read=NOT-EMPTY rc=1" "P80 代价⑥：保守方向（判忙、投递等待），绝不粘连"

# ── 红侧（可证伪）：把唯一的顺序决策影子成升序（= 旧的「最近优先」）──────────────
# 影子只覆盖那一个函数：候选集合、配对规则、横幅排除、两遍回退全部照旧。
P80_R1="$(p80_probe "$P80_F1" 2 1)"
assert_has_echo "$P80_R1" "geometry=[1 3]" "P80 红侧①：影子后同帧退回最近的 [1 3]"
assert_has_echo "$P80_R1" "box_nows=[]" "P80 红侧①：框被定位得太小 → 框文本读空（P74 的 F1 原样复现）"
assert_has_echo "$P80_R1" "verdict=idle-read=EMPTY rc=0" "P80 红侧①：判定退回 EMPTY —— 就绪门会在 Draft 上放行"
P80_R2="$(p80_probe "$P80_F2" 2 1)"
assert_has_echo "$P80_R2" "geometry=[1 3]" "P80 红侧①b：影子后 [1 3]"
assert_has_echo "$P80_R2" "verdict=idle-read=EMPTY rc=0" "P80 红侧①b：判定退回 EMPTY"
P80_R6="$(p80_probe "$P80_F6" 2 1)"
assert_has_echo "$P80_R6" "geometry=[1 3]" "P80 红侧⑥：代价形状在旧顺序下退回 [1 3]"
assert_has_echo "$P80_R6" "verdict=idle-read=EMPTY rc=0" "P80 红侧⑥：代价与缺陷是同一枚硬币的两面（旧顺序把框读空）"
P80_R7="$(p80_probe "$P80_F7" 2 1 'half a sentence')"
assert_has_echo "$P80_R7" "box_nows=[halfasentence]" "P80 红侧⑦：影子后框被截断（只看得到框线上半段）"
assert_has_echo "$P80_R7" "holds_only=only-ours" "P80 红侧⑦：截断的框正好等于 payload → 误判「只有我们」（P80 前的事故形状）"
P80_R8="$(p80_probe "$P80_F8" 2 1)"
assert_has_echo "$P80_R8" "geometry=[1 3]" "P80 红侧⑧：被证伪的备选规则形状在旧顺序下也是 [1 3]"
assert_has_echo "$P80_R8" "verdict=idle-read=EMPTY rc=0" "P80 红侧⑧：退回 EMPTY（说明「区域非空才扩框」不能替代本规则）"

# ── 真帧：P80 前后逐字不变（两个方向都比），且两份布局的最低整行 rule 是框自己的下边框 ──
P80_REAL="$P80_FD/pi-0.87.0-one-line-draft.txt:$P80_FD/pi-0.87.0-draft-half-sentence.txt:$P80_FD/pi-0.87.0-empty-box.txt:$P80_FD/pi-0.85.1-update-banner.txt:$P80_FD/pi-0.87.0-project-trust-prompt.txt"
IFS=':' read -r -a P80_REAL_ARR <<< "$P80_REAL"
for _p80r in "${P80_REAL_ARR[@]}"; do
  _p80cy=26; case "$(basename "$_p80r")" in pi-0.87.0-project-trust-prompt.txt) _p80cy=16 ;; esac
  P80_RG="$(p80_probe "$_p80r" "$_p80cy")"; P80_RR="$(p80_probe "$_p80r" "$_p80cy" 1)"
  assert_eq "P80 真帧 $(basename "$_p80r")：两个方向逐字相同（判定不回退）" "$P80_RR" "$P80_RG"
done
P80_REAL_ONE="$(p80_probe "$P80_FD/pi-0.87.0-one-line-draft.txt" 26)"
assert_has_echo "$P80_REAL_ONE" "geometry=[25 27]" "P80 真帧①：0.87.0 单行草稿几何不变（[25 27]）"
assert_has_echo "$P80_REAL_ONE" "verdict=idle-read=NOT-EMPTY rc=1" "P80 真帧①：0.87.0 单行草稿判定不变（NOT-EMPTY）"
P80_REAL_EMPTY="$(p80_probe "$P80_FD/pi-0.87.0-empty-box.txt" 26)"
assert_has_echo "$P80_REAL_EMPTY" "geometry=[25 27]" "P80 真帧②：0.87.0 空框几何不变（[25 27]）"
assert_has_echo "$P80_REAL_EMPTY" "verdict=idle-read=EMPTY rc=0" "P80 真帧②：0.87.0 空框仍 EMPTY"
P80_REAL_BANNER="$(p80_probe "$P80_FD/pi-0.85.1-update-banner.txt" 26)"
assert_has_echo "$P80_REAL_BANNER" "geometry=[24 29]" "P80 真帧③：0.85.1 横幅帧几何不变（[24 29]）"
assert_has_echo "$P80_REAL_BANNER" "verdict=idle-read=EMPTY rc=0" "P80 真帧③：0.85.1 横幅帧仍 EMPTY"
P80_REAL_TRUST="$(p80_probe "$P80_FD/pi-0.87.0-project-trust-prompt.txt" 16)"
assert_has_echo "$P80_REAL_TRUST" "verdict=overlay=trust-prompt rc=0" "P80 真帧④：信任弹窗仍是覆盖层（overlay 优先权未变）"
# 结构：两份真实布局里，pane 最低的整行 rule 就是框自己的下边框 —— 镜像代价在已测布局上不可达
P80_STRUCT="$(for _p80r in "${P80_REAL_ARR[@]}"; do
  LC_ALL=C awk -v name="$(basename "$_p80r")" '{ L[NR]=$0 } END {
    last=0; for (i=1;i<=NR;i++) if (L[i] ~ /^(\xe2\x94\x80)+$/) last=i
    below=0; for (i=last+1;i<=NR;i++) if (L[i] ~ /^(\xe2\x94\x80)+$/) below++
    printf "%s below=%d\n", name, below }' < "$_p80r"
done)"
assert_not_echo "$P80_STRUCT" "below=1" "P80 结构：五份真帧里，最低整行 rule 之下都没有第二条整行 rule（代价不可达）"

# 单调性（requirement 的方向承诺）：相对旧的最近优先，框只会变大，所以**任何**帧都不许从
# BUSY（NOT-EMPTY）翻成 EMPTY。这里对全部 13 份已存帧逐帧对比红/绿两侧的判定。
P80_MONO_BAD=""; P80_MONO_N=0
for _p80r in "${P80_REAL_ARR[@]}" "$P80_F1" "$P80_F2" "$P80_F3" "$P80_F4" "$P80_F5" "$P80_F6" "$P80_F7" "$P80_F8"; do
  _p80cy=2
  case "$(basename "$_p80r")" in
    pi-0.87.0-project-trust-prompt.txt) _p80cy=16 ;;
    pi-0.8*) _p80cy=26 ;;
    p78-cursor-mid-draft.txt) _p80cy=3 ;;
  esac
  P80_MONO_N=$((P80_MONO_N + 1))
  P80_MG="$(p80_probe "$_p80r" "$_p80cy")"; P80_MR="$(p80_probe "$_p80r" "$_p80cy" 1)"
  case "$P80_MR/$P80_MG" in
    *"verdict=idle-read=NOT-EMPTY"*"verdict=idle-read=EMPTY"*) P80_MONO_BAD="$P80_MONO_BAD $(basename "$_p80r")" ;;
  esac
done
assert_eq "P80 单调性：全部 13 份已存帧都逐个对比了红/绿两侧" "$P80_MONO_N" "13"
assert_eq "P80 单调性：红侧判忙的帧在绿侧没有一个翻成 EMPTY（框只变大）" "${P80_MONO_BAD:-none}" "none"

# ── 一处实现：生产提取、夹具判定、门禁探针共用同一份判据 ─────────────────────────
# 注：模式里的 `[(][)]`/`[(]` 是为了不让本行自己匹配到自己（字符类进了 grep 模式就变回 `()`/`(`）。
P80_REDEF="$(grep -rln '_team_box_geometry[(][)]\|for [(]k=' "$SKILL_DIR/tests" 2>/dev/null | sed "s|^$SKILL_DIR/||" | tr '\n' ' ')"
assert_eq "P80 一处实现：tests/** 里没有第二份几何/候选循环实现（影子只覆盖那一个顺序函数）" "${P80_REDEF:-none}" "none"
assert_eq "P80 一处实现：候选顺序决策在 outbox.sh 里定义恰一处" \
  "$(grep -c '^_team_box_bottom_candidate_order() {' "$SKILL_DIR/scripts/lib/outbox.sh")" "1"
assert_eq "P80 一处实现：几何里向它要顺序的调用恰一处" \
  "$(grep -c 'ordered="\$(_team_box_bottom_candidate_order' "$SKILL_DIR/scripts/lib/outbox.sh")" "1"
# 同源：纯探针（生产提取）与 pm-box-real.sh --frame（共享判据）在**每一份**已存帧上逐字一致
for _p80r in "${P80_REAL_ARR[@]}" "$P80_F1" "$P80_F2" "$P80_F3" "$P80_F4" "$P80_F5" "$P80_F6" "$P80_F7" "$P80_F8"; do
  _p80cy=2
  case "$(basename "$_p80r")" in
    pi-0.87.0-project-trust-prompt.txt) _p80cy=16 ;;
    pi-0.8*) _p80cy=26 ;;
    p78-cursor-mid-draft.txt) _p80cy=3 ;;
  esac
  P80_P="$(p80_probe "$_p80r" "$_p80cy")"
  P80_M="$(P80_FM "$_p80r" "$_p80cy")"; P80_M_RC=$?
  P80_BP="$(printf '%s\n' "$P80_P" | sed -n 's/^box_nows=\[\(.*\)\]$/\1/p')"
  P80_BM="$(printf '%s\n' "$P80_M" | sed -n 's/^box_text=\[\(.*\)\]$/\1/p' | tr -d '[:space:]|')"
  P80_VP="$(printf '%s\n' "$P80_P" | sed -n 's/^verdict=\(.*\) rc=[0-9]*$/\1/p')"
  P80_VM="$(printf '%s\n' "$P80_M" | sed -n '2p')"
  P80_RP="${P80_P##*rc=}"
  assert_eq "P80 同源 $(basename "$_p80r")：框文本在两条路径上逐字一致" "$P80_BP" "$P80_BM"
  assert_eq "P80 同源 $(basename "$_p80r")：判定与 rc 在两条路径上一致" "$P80_VP/$P80_RP" "$P80_VM/$P80_M_RC"
done

# ---------------------------------------------------------------- 12b-h0c. P59 覆盖层判据（纯帧，快模式照跑）
section "12b-h0c · P59 输入框判据：覆盖层（Pi 的项目信任弹窗）≠ 非空输入框"
# 现场（P54 的 F2 / M28 §31b2 红）：项目由 team init 装了 .pi/skills/ 之后，第一次交互运行的 pi 会画
# 「信任此项目吗」弹窗 —— 一个整屏覆盖层，弹窗里**一个字都没有**。老判据的两条误判路径都写进 requirement：
# 光标在弹窗下边界上 → 找不到框（UNKNOWN）；光标落进弹窗 → 把弹窗自己那两条整行 ─ 配成「框」、
# 把问题与选项读成框内容（BUSY）。两条都打成 `idle-read=NOT-EMPTY`，夹具然后对着弹窗跑投递。
# 这一节是**纯帧**（不开 tmux、不跑 pi，FAST 照跑）：真帧 + 合成帧钉住判定与红/绿两侧。
M59_FB="$SKILL_DIR/tests/pm-box-real.sh"
M59_FRAME="$SKILL_DIR/tests/frames/pi-0.87.0-project-trust-prompt.txt"
M59_CY=16        # 真帧实拍时的光标行（1-based）：弹窗自己的下边界那条整行 ─
assert_file "$M59_FRAME" "P59：真实信任弹窗帧（真 pi 0.87.0 实拍）在 tests/frames/"
assert_eq "P59 对照：真帧里就有两条整行 ─（老等待「第一条整行 ─」会在这帧上放行 → 更严的就绪门是必需的）" \
  "$(grep -cE '^(─)+$' "$M59_FRAME" || true)" "2"
# 同一份共享判据（pm-box-real.sh --frame）：覆盖层谓词开 → overlay；关（M24_OVERLAY_DETECT=0）→ 老判定
M59_OUT="$(bash "$M59_FB" --frame "$M59_FRAME" --cursor "$M59_CY" 2>&1)"; M59_RC=$?
assert_eq "P59 绿侧：真帧被判成覆盖层（rc=0）" "$M59_RC" "0"
assert_has_echo "$M59_OUT" "overlay=trust-prompt" "P59 绿侧：真帧点名 overlay=trust-prompt"
assert_not_echo "$M59_OUT" "idle-read=NOT-EMPTY" "P59 绿侧：覆盖层**不许**被报成非空输入框"
M59_OUT_RED="$(M24_OVERLAY_DETECT=0 bash "$M59_FB" --frame "$M59_FRAME" --cursor "$M59_CY" 2>&1)"; M59_RC_RED=$?
assert_eq "P59 红侧：关掉覆盖层判据 → 同一份帧退回非空（rc≠0）" "$M59_RC_RED" "1"
assert_has_echo "$M59_OUT_RED" "idle-read=NOT-EMPTY" "P59 红侧：谓词关掉后同一帧被判成草稿（可证伪，不是空转）"
assert_not_echo "$M59_OUT_RED" "overlay=trust-prompt" "P59 红侧：谓词关掉后不再点名覆盖层"

# 合成帧：像弹窗一样的 chrome（两条整行 ─ 夹着问题/选项/提示）但没有真输入框 → 就绪门绝不放行
M59_F="$TMP/p59-frames"; rm -rf "$M59_F"; mkdir -p "$M59_F"
m59_rule() { printf '─%.0s' $(seq 1 "${1:-40}"); printf '\n'; }
{ m59_rule 60; printf '\n'; printf '  Pick a widget\n'; printf '  /tmp/x\n'; printf '\n'; printf '  Something something\n'; printf '\n'; printf '  → Alpha\n'; printf '    Beta\n'; printf '\n'; printf '  up/down move  enter pick\n'; printf '\n'; m59_rule 60; printf ' footer\n'; } > "$M59_F/chrome-no-box.txt"
M59_OUT_NB="$(bash "$M59_FB" --frame "$M59_F/chrome-no-box.txt" --cursor 8 2>&1)"; M59_RC_NB=$?
assert_eq "P59：像弹窗的 chrome（两条整行 ─、没有真输入框）不许让就绪门放行（rc≠0）" "$M59_RC_NB" "1"
assert_has_echo "$M59_OUT_NB" "idle-read=NOT-EMPTY" "P59：合成帧没有可定位的空框 → 判定非空（就绪永远不放行）"
assert_not_echo "$M59_OUT_NB" "idle-read=EMPTY" "P59：合成帧绝不许被判成空框"
# 对照：真的空输入框要能放行（否则绿侧可能只是「永远红」）
{ m59_rule 60; printf '\n'; printf ' fake-pi  Fake Pi  max\n'; m59_rule 60; printf ' footer\n'; } > "$M59_F/empty-box.txt"
M59_OUT_E="$(bash "$M59_FB" --frame "$M59_F/empty-box.txt" --cursor 2 2>&1)"; M59_RC_E=$?
assert_eq "P59 对照：真输入框且为空 → rc=0（就绪门确实会放行）" "$M59_RC_E" "0"
assert_has_echo "$M59_OUT_E" "idle-read=EMPTY" "P59 对照：空框判成 EMPTY"
# 对照：框里有草稿 → 非空（覆盖层规则没有把判定力削掉）
{ m59_rule 60; printf '\n'; printf ' half sentence\n'; printf ' fake-pi  Fake Pi  max\n'; m59_rule 60; printf ' footer\n'; } > "$M59_F/draft-box.txt"
M59_OUT_D="$(bash "$M59_FB" --frame "$M59_F/draft-box.txt" --cursor 2 2>&1)"; M59_RC_D=$?
assert_eq "P59 对照：框里有草稿 → 非空（判定力不降）" "$M59_RC_D" "1"
assert_has_echo "$M59_OUT_D" "idle-read=NOT-EMPTY" "P59 对照：草稿照旧被判成非空"

# ---------------------------------------------------------------- 12b-h1. M24 真实 pi 窗格体检（显式开）
# tests/pm-box-real.sh 用**真实 pi**起一个窗格，把守卫看到的原始帧与判定打出来（真实现场形状）。
# 默认不跑：它要用使用者的 pi 配置（`--no-session --session-dir <tmp>`，不写会话文件，但会加载扩展）。
# 需要真实现场证据时：TEAM_SMOKE_REAL_PI=1 bash tests/smoke.sh
if [ "${TEAM_SMOKE_REAL_PI:-0}" = "1" ] && [ "$FAST" = "1" ]; then
  # FAST 的契约是「不跑真进程段落」（14c 自检会核对）——真 pi 是货真价实的真进程，
  # 所以这里只提示、不跑（要真实现场证据请不带 TEAM_SMOKE_FAST）。
  printf '  \033[2m·\033[0m %s\n' "（TEAM_SMOKE_REAL_PI=1 在 FAST 下不跑：真 pi 属真进程段落；完整门禁会跑）"
elif [ "${TEAM_SMOKE_REAL_PI:-0}" = "1" ] && [ "$HAVE_TMUX" = "1" ] && [ -x "$SKILL_DIR/tests/pm-box-real.sh" ]; then
  live_mark
  if bash "$SKILL_DIR/tests/pm-box-real.sh" --idle-secs 4 >"$TMP/m24-realbox.log" 2>&1; then
    if grep -q '^SKIP' "$TMP/m24-realbox.log"; then
      printf '  \033[2m·\033[0m %s\n' "（真 pi 不存在，跳过体检）"
    else
      ok "M24 真实 pi 窗格：体检跑完（空闲/粘贴/收回，见 $TMP/m24-realbox.log）"
      assert_has "$TMP/m24-realbox.log" "RETRACT=ok" "M24 真实 pi 窗格：收回在真实 pi 上成功"
      assert_not "$TMP/m24-realbox.log" "RETRACT=failed" "M24 真实 pi 窗格：没有收回失败"
    fi
  else
    bad "M24 真实 pi 窗格体检失败（$TMP/m24-realbox.log）"; tail -12 "$TMP/m24-realbox.log"
  fi
else
  printf '  \033[2m·\033[0m %s\n' "（跳过真实 pi 窗格体检：TEAM_SMOKE_REAL_PI=1 可开；脚本 tests/pm-box-real.sh）"
fi

# ---------------------------------------------------------------- 12b-h. 真 pane 端到端（假 TUI）
if [ "$FAST" = "1" ]; then
  fast_skip "12b-h·真 pane 端到端（守卫/排水/草稿窗口）" "要真 tmux pane + python3 夹具 TUI（清空输入框、多行粘贴、draft 窗口）"
elif [ "$HAVE_TMUX" != "1" ] || ! command -v python3 >/dev/null 2>&1; then
  printf '  (跳过 12b-h：本机没有 tmux 或 python3)\n'
elif ! tmux_has_bracket_paste_format; then
  # M47：多行投递的整段判据（一次 bracketed paste = 一次提交 / 竞态留框 / 收回）建立在
  # 「能问出目标有没有开 DECSET 2004」上，而那个格式 tmux ≥3.7 才有。旧 tmux 上产品走指针文件的
  # 保守降级，这些断言测不了 —— 可见 skip + 点名版本（容器门禁钉 tmux 3.7b，照跑全套）。
  cond_skip "12b-h·真 pane 端到端（守卫/排水/草稿窗口）" "$(tmux -V)：没有 #{bracket_paste_flag} 格式（tmux ≥3.7 才有）→ 多行粘贴判据无法测"
else
  live_mark
  FTUI="$SKILL_DIR/tests/fake-tui.py"
  OB_SUBMIT="$TMP/ob-submit.log"; : > "$OB_SUBMIT"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -n pm -x 120 -y 30 -c "$REPO" 2>/dev/null || true
  # 假 PM 可执行文件：argv 里留着 fake-pm-bin 这个名字，PM 存活判据才认它（M6.5）
  printf '#!/usr/bin/env bash\npython3 %q\n' "$FTUI" > "$TMP/fake-pm-bin"
  chmod +x "$TMP/fake-pm-bin"
  ob_pm_state() {
    ( cd "$REPO" && env TEAM_PM_BIN="$TMP/fake-pm-bin" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_pm_state' )
  }
  ob_pm_wait() { # 等假 PM 被认作 running（M6.5 的存活判据要看到 argv 里的 fake-pm-bin）
    local i st=""
    for i in 1 2 3 4 5 6 7 8 9 10; do
      st="$(ob_pm_state)"
      case "$st" in running:*) return 0 ;; esac
      sleep 0.4
    done
    printf '  \033[2m·\033[0m PM 状态持续为 [%s]\n' "$st"
    return 1
  }
  ob_tui() { # <窗口> <草稿> [额外 env...]
    # pm 窗口跑假 PM 可执行文件（不是裸 python3）：M6.5 的存活判据要看到 argv 里的可执行名
    local win="$1" draft="$2" cmd; shift 2
    if [ "$win" = "pm" ]; then
      cmd="$(printf 'FAKE_TUI_DRAFT=%q FAKE_TUI_COLS=100 FAKE_TUI_SUBMIT_LOG=%q %s %q' "$draft" "$OB_SUBMIT" "$*" "$TMP/fake-pm-bin")"
    else
      cmd="$(printf 'FAKE_TUI_DRAFT=%q FAKE_TUI_COLS=100 FAKE_TUI_SUBMIT_LOG=%q %s python3 %q' "$draft" "$OB_SUBMIT" "$*" "$FTUI")"
    fi
    tmux kill-window -t "$SESSION:$win" 2>/dev/null || true
    tmux new-window -d -t "$SESSION" -n "$win" -c "$REPO" "$cmd" 2>/dev/null || true
    sleep 0.9
  }
  ob_submits() { grep -c '^SUBMIT:' "$OB_SUBMIT" 2>/dev/null || true; }
  # 守卫眼里的框内容（去空白）——用来断言「读出来的是真草稿，不是横幅」
  ob_target_box_nows() { # <target>
    ( cd "$REPO" && env OB_T="$1" bash -c '. "$1/scripts/lib/common.sh"; . "$1/scripts/lib/outbox.sh"; team_load_config >/dev/null 2>&1 || true; team_input_box_text "$OB_T" 2>/dev/null | tr -d "[:space:]"' _ "$SKILL_DIR" )
  }

  # 前面段落（11b2/11b3）可能留下 PM 状态残迹：先清掉，否则「假 PM 在跑」判不出来
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" \
        "$REPO/.pi/team/state/pm.pid.spawn" "$REPO/.pi/team/state/pm.pid.starting"

  # ① 脏框：say 排队、草稿不动、没有提交
  : > "$OB_SUBMIT"
  ob_tui dev '半句草稿 half a sentence'
  ob_live env $TEAM say dev "check the failing test" >"$TMP/ob-h-say.log" 2>&1 || true
  assert_has "$TMP/ob-h-say.log" "queued" "12b-h ① 真 pane：脏框 → queued"
  assert_eq "12b-h ① 真 pane：没有发生提交（草稿没被粘走）" "$(ob_submits)" "0"
  tmux capture-pane -p -t "$SESSION:dev" | grep -qF '半句草稿 half a sentence' \
    && ok "12b-h ① 真 pane：草稿还在输入框里" || bad "12b-h ① 真 pane：草稿不见了"

  # ② 清空后 flush：只投一次，队列清空
  tmux send-keys -t "$SESSION:dev" C-u; sleep 0.4
  ob_live env $TEAM outbox flush >"$TMP/ob-h-flush.log" 2>&1 || true
  assert_has "$TMP/ob-h-flush.log" "已投递" "12b-h ② 清空后 flush 报已投递"
  assert_eq "12b-h ② 只投一次" "$(ob_submits)" "1"
  assert_has "$OB_SUBMIT" "check the failing test" "12b-h ② 投递内容正确"
  assert_eq "12b-h ② 队列清空" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  # ③ 三行草稿 = 一次提交（bracketed paste），顺序保持
  : > "$OB_SUBMIT"
  printf 'alpha line one\nbeta line two\ngamma line three\n' > "$TMP/ob-three.txt"
  ob_live env $TEAM draft send "$TMP/ob-three.txt" --target "$SESSION:dev" >"$TMP/ob-h-draft.log" 2>&1 || true
  assert_eq "12b-h ③ 三行 = 一次提交" "$(ob_submits)" "1"
  assert_eq "12b-h ③ 三行顺序保持" "$(sed -n 's/^SUBMIT://p' "$OB_SUBMIT")" 'alpha line one\nbeta line two\ngamma line three'

  # ④ 不支持 bracketed paste 的目标：多行落成文件 + 一行指针（旧规矩）
  : > "$OB_SUBMIT"
  ob_tui nobrk '' 'FAKE_TUI_NO_BRACKETED_PASTE=1'
  ob_live env $TEAM draft send "$TMP/ob-three.txt" --target "$SESSION:nobrk" >"$TMP/ob-h-nobrk.log" 2>&1 || true
  assert_eq "12b-h ④ 不支持 bracketed paste → 只提交一行指针" "$(ob_submits)" "1"
  assert_has "$OB_SUBMIT" "多行消息已存到" "12b-h ④ 指针消息点名文件"
  ob_saved="$(grep -rl 'alpha line one' "$REPO/.pi/team/state/draft" 2>/dev/null | head -1)"
  assert_file "$ob_saved" "12b-h ④ 多行内容真的落成文件"
  assert_has "$ob_saved" "gamma line three" "12b-h ④ 落下的文件是完整三行（不是被截断的指针）"

  # ⑤⑥ 敲门/巡检只在 tmux 里有意义：没有 TMUX 就明确 SKIP（V7-F6：skip 是约定，不是 FAIL）
  # PM 窗口本身两种模式都建（⑦ draft pm 依赖它）；只把敲门/巡检断言放进条件分支。
  ob_tui pm 'PM 的半句草稿'
  if [ -z "${TMUX:-}" ]; then
    cond_skip "12b-h ⑤ 假 PM 敲门（收件箱路径要求 TMUX 内运行）"
    cond_skip "12b-h ⑥ watchdog 敲门 + 排水（收件箱路径要求 TMUX 内运行）"
  else
  # ⑤ PM 窗口的敲门：脏 PM 框 → 入队、草稿不动
  : > "$OB_SUBMIT"
  if ob_pm_wait; then ok "12b-h ⑤ 假 PM 被认作 running（argv 命中 fake-pm-bin）"
  else bad "12b-h ⑤ 假 PM 没有被认作 running —— 后面的敲门/巡检断言都会失真"; fi
  printf 'worker turn summary\n' > "$TMP/ob-sum.txt"
  ob_live env TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM notify pm --from-file "$TMP/ob-sum.txt" >"$TMP/ob-h-notify.log" 2>&1 || true
  assert_has "$TMP/ob-h-notify.log" "敲门入队" "12b-h ⑤ 脏 PM 框：敲门报入队"
  assert_eq "12b-h ⑤ 脏 PM 框：敲门没有提交" "$(ob_submits)" "0"
  assert_eq "12b-h ⑤ 敲门入队一条" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*pm*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_has "$REPO/docs/team/inbox/pm.md" "worker turn summary" "12b-h ⑤ 收件箱照写"

  # ⑥ watchdog：一拍排水 + nudge 走守卫
  tmux send-keys -t "$SESSION:pm" C-u; sleep 0.4
  ob_live env TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM watch --once >"$TMP/ob-h-watch.log" 2>&1 || true
  assert_has "$OB_SUBMIT" "worker turn summary" "12b-h ⑥ tick 把排队的敲门投出去了"
  assert_eq "12b-h ⑥ tick 之后队列空了" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
  : > "$OB_SUBMIT"
  tmux send-keys -t "$SESSION:pm" -l 'PM 又开始写草稿'; sleep 0.4
  printf '%s\n' '- 2026-01-01T00:00:00Z [manual] agent:dev · ob-nudge-new-work' >> "$REPO/docs/team/inbox/pm.md"
  ob_live env TEAM_PM_BIN="$TMP/fake-pm-bin" TEAM_WATCH_NUDGE_GAP=0 $TEAM watch --once >"$TMP/ob-h-watch2.log" 2>&1 || true
  assert_has "$TMP/ob-h-watch2.log" "已入队" "12b-h ⑥ 脏 PM 框：叫醒语入队而不是粘字"
  assert_eq "12b-h ⑥ 脏 PM 框：nudge 没有提交" "$(ob_submits)" "0"
  assert_has "$REPO/.pi/team/state/nudges.log" "未读通知" "12b-h ⑥ nudges.log 仍然照写（durable 记录不丢：队列只延后投递，不替代记录）"
  assert_eq "12b-h ⑥ 队列里恰好一条叫醒语条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  fi

  # ⑦ 草稿窗口：回执 + 重填 + 永不被投递
  tmux send-keys -t "$SESSION:pm" C-u; sleep 0.3
  rm -f "$REPO/.pi/team/state/draft-pm.md"
  printf '#!/usr/bin/env bash\nprintf "interrupted once\\n" > "$1"\n' > "$TMP/fake-editor"; chmod +x "$TMP/fake-editor"
  ob_live env EDITOR="$TMP/fake-editor" TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM draft pm >"$TMP/ob-h-draftwin.log" 2>&1 || true
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    grep -qF 'interrupted once' "$OB_SUBMIT" 2>/dev/null && break
    sleep 0.5
  done
  tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -qx draft \
    && ok "12b-h ⑦ draft 窗口已建（不抢焦点）" || bad "12b-h ⑦ draft 窗口没建起来"
  assert_has "$OB_SUBMIT" "interrupted once" "12b-h ⑦ 编辑器保存的内容被投递"
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(wc -c < "$REPO/.pi/team/state/draft-pm.md" 2>/dev/null | tr -d ' ')" = "0" ] && break
    sleep 0.5
  done
  assert_eq "12b-h ⑦ 草稿文件被重填成空种子" "$(wc -c < "$REPO/.pi/team/state/draft-pm.md" | tr -d ' ')" "0"
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    tmux display-message -p -t "$SESSION:draft" '#{pane_dead}' 2>/dev/null | grep -qx 1 && break
    sleep 0.4
  done
  tmux capture-pane -p -t "$SESSION:draft" > "$TMP/ob-h-draftpane.log" 2>/dev/null || true
  assert_match "$TMP/ob-h-draftpane.log" "回执|已确认送达|queued" "12b-h ⑦ 回执打印在 draft 窗口里"
  # ⑦b draft 窗口永远不是投递目标：say/notify/tick 之后 pane 逐字节不变
  draft_before="$(md5sum < "$TMP/ob-h-draftpane.log")"
  ob_live env $TEAM say pm --any "do not touch the draft window" >/dev/null 2>&1 || true
  ob_live env TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM notify pm --from-file "$TMP/ob-sum.txt" >/dev/null 2>&1 || true
  ob_live env TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM watch --once >/dev/null 2>&1 || true
  tmux capture-pane -p -t "$SESSION:draft" > "$TMP/ob-h-draftpane2.log" 2>/dev/null || true
  assert_eq "12b-h ⑦b draft 窗口的 pane 逐字节不变" "$(md5sum < "$TMP/ob-h-draftpane2.log")" "$draft_before"

  # ⑨（M17 形状②）粘贴期间有草稿介入：框里混了人的字 → **一个键都不碰**（宁留不删），
  #    消息进 held/（终态）。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race '' 'FAKE_TUI_DRAFT_ON_PASTE=HUMAN_DRAFT_'
  ob_live $TEAM draft send "$TMP/ob-three.txt" --target "$SESSION:race" >"$TMP/ob-h-race.log" 2>&1 || true
  assert_eq "12b-h ⑨ 打字期间有草稿介入 → 没有提交" "$(ob_submits)" "0"
  assert_has "$TMP/ob-h-race.log" "框里已有人的内容，未动" "12b-h ⑨ M17：日志写明「框里已有人的内容，未动」"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=draft-raced-left" "12b-h ⑨ M17：held 原因 = draft-raced-left（留在框里）"
  tmux capture-pane -p -t "$SESSION:race" > "$TMP/ob-h-race-box.log" 2>/dev/null || true
  assert_has "$TMP/ob-h-race-box.log" "HUMAN_DRAFT_alpha line one" "12b-h ⑨ 人的草稿 + 我们的 payload 原样留在框里"
  assert_has "$TMP/ob-h-race-box.log" "gamma line three" "12b-h ⑨ M17：整段都没被碰（收回键序一个都没发）"
  ob_live $TEAM digest >"$TMP/ob-h-race-digest.log" 2>&1 || true
  assert_has "$TMP/ob-h-race-digest.log" "留在框里 1" "12b-h ⑨ M17：digest 的 outbox 行报「留在框里 1」"
  # V7-F3：draft-raced 是终态 —— payload 已经进过人的框一次（可能随人的提交到了 agent），
  # 任何自动路径（含 flush --now）都不许再投；留在 held/ 可见，durable 副本在收件箱。
  ob_live $TEAM outbox flush >"$TMP/ob-h-race-flush.log" 2>&1 || true
  assert_eq "12b-h ⑨b draft-raced 终态：再 flush 仍然 0 提交" "$(ob_submits)" "0"
  assert_eq "12b-h ⑨b draft-raced 终态：条目留在 held/（可见、可 drop）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_has "$TMP/ob-h-race-flush.log" "draft-raced" "12b-h ⑨b 排水报告点名终态原因（不是静默跳过）"
  ob_live $TEAM outbox flush --now >"$TMP/ob-h-race-flushnow.log" 2>&1 || true
  assert_eq "12b-h ⑨b flush --now 也不重投 draft-raced（它不属于 forced.log 管辖）" "$(ob_submits)" "0"
  assert_not "$REPO/.pi/team/state/outbox/forced.log" "alpha line one" "12b-h ⑨b draft-raced 不进 forced.log（没有 forced 投递发生）"

  # ⑩ held 的条目在框清空后仍然投递（规格 requirement 5 的 scenario）
  ob_reset
  tmux send-keys -t "$SESSION:dev" C-u; sleep 0.3
  : > "$OB_SUBMIT"
  tmux send-keys -t "$SESSION:dev" -l '人的草稿'; sleep 0.4          # 真 pane：直接把框弄脏
  ob_live $TEAM say dev "held one" >/dev/null 2>&1 || true
  ob_live env TEAM_OUTBOX_MAX=1 $TEAM say dev "held two" >/dev/null 2>&1 || true
  assert_eq "12b-h ⑩ 上限触发：最老的进 held/" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  tmux send-keys -t "$SESSION:dev" C-u; sleep 0.3
  ob_live $TEAM outbox flush >"$TMP/ob-h-held.log" 2>&1 || true
  assert_eq "12b-h ⑩ held 的条目也投了（两条都到）" "$(ob_submits)" "2"
  assert_eq "12b-h ⑩ held/ 清空" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  # ⑧ TEAM_NOTIFY_TMUX=0：只写收件箱，不排队
  ob_reset
  ob_live env TEAM_NOTIFY_TMUX=0 TEAM_PM_BIN="$TMP/fake-pm-bin" $TEAM notify pm --from-file "$TMP/ob-sum.txt" >/dev/null 2>&1 || true
  assert_eq "12b-h ⑧ TEAM_NOTIFY_TMUX=0：不建队列条目" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  # ⑪ V7-F1 真实形状：光标停在空白行、草稿文字在光标行下方（leading newline + Up）。
  #    v2 光标相对判定在这里判 EMPTY → D20 原样重演；整框扫描必须 BUSY → 排队、零提交、草稿不动。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev $'\nBODY-1\nBODY-2' 'FAKE_TUI_CURSOR_TOP=1'
  ob_live $TEAM say dev "cursor-top probe" >"$TMP/ob-h-f1.log" 2>&1 || true
  assert_has "$TMP/ob-h-f1.log" "queued" "12b-h ⑪ V7-F1：光标行下方的草稿 → queued"
  assert_eq "12b-h ⑪ V7-F1：没有发生提交（D20 不再重演）" "$(ob_submits)" "0"
  tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -qF 'BODY-2' \
    && ok "12b-h ⑪ V7-F1：草稿原样还在框里" || bad "12b-h ⑪ V7-F1：草稿不见了"

  # ⑫ V7-F2 真实形状：大粘贴被 TUI 折叠成 [paste #1 +K lines]，竞态期间人开始打字。
  #    长度启发式在这里必然放行（可见字符 << payload）；指纹判据必须拦住 → 不按 Enter → held。
  ob_reset; : > "$OB_SUBMIT"
  printf 'line-%s\n' $(seq -w 1 14) > "$TMP/ob-big.txt"
  ob_tui race2 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_DRAFT_ON_PASTE=HI-'
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race2" >"$TMP/ob-h-f2.log" 2>&1 || true
  assert_eq "12b-h ⑫ V7-F2：折叠粘贴 + 竞态打字 → 没有提交（草稿没被粘走）" "$(ob_submits)" "0"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "draft-raced" "12b-h ⑫ V7-F2：条目进 held/（draft-raced）"
  tmux capture-pane -p -t "$SESSION:race2" 2>/dev/null | grep -qE 'HI-\[paste #1 \+[0-9]+ lines\]' \
    && ok "12b-h ⑫ V7-F2：框里正是真实 Pi 的折叠形状 + 人的字" || bad "12b-h ⑫ V7-F2：折叠形状不对"
  # 同一形状、没人打字时必须放行（阴性对照：占位符本身不是 BUSY 的理由）
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race2 '' 'FAKE_TUI_MARKER=10'
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race2" >"$TMP/ob-h-f2b.log" 2>&1 || true
  assert_eq "12b-h ⑫b 干净的折叠粘贴 → 正常投递（折叠≠脏框）" "$(ob_submits)" "1"

  # ⑬ V9-B5（取代 V7-F4 旧语义）：静态页脚 TUI 不回显提交气泡（draw 不画 conversation）。
  #    投递确认按「出框 + 对话区出现提交证据」：这类 pane 给不出证据 → 诚实降级为「未确认」——
  #    恰好一次提交（Enter 确实生效了，但工具无法证明）、立即进 held/（终态，绝不重贴）、
  #    收件箱留 durable 副本（人可以核实后 drop）。这不是造假待办：held 就是真实待办。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev '' 'FAKE_TUI_STATIC_FOOTER=1'
  ob_live $TEAM say dev "static footer probe" >"$TMP/ob-h-f4.log" 2>&1 || true
  assert_not "$TMP/ob-h-f4.log" "已确认送达" "12b-h ⑬ V9-B5：静态页脚 pane 拿不出提交证据 → 绝不报已确认送达"
  assert_eq "12b-h ⑬ V9-B5：恰好一次提交（Enter 生效过一次，只是工具证明不了）" "$(ob_submits)" "1"
  assert_eq "12b-h ⑬ V9-B5：立即进 held/（未确认 = 终态，不是删除）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_eq "12b-h ⑬ V9-B5：队列清空（不留 active 等下一拍重投）" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
  ob_live $TEAM outbox flush >"$TMP/ob-h-f4b.log" 2>&1 || true
  assert_eq "12b-h ⑬ V9-B5：再 flush 不重投（绝不重复粘贴）" "$(ob_submits)" "1"
  assert_has "$REPO/docs/team/inbox/dev.md" "static footer probe" "12b-h ⑬ V9-B5/F5：held 的 durable 副本落收件箱（人可以核实后 drop）"

  # ⑮ V9-B5 核心事故形状：TUI 吞掉 Enter（清空未提交）。框空了、对话区永远没有这条消息 →
  #    不许报「已送达」、条目不许删：立即 held（终态，永不重贴），durable 副本落收件箱，零提交。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev '' 'FAKE_TUI_EAT_ENTER=1'
  ob_live $TEAM say dev "eaten enter probe" >"$TMP/ob-h-b5.log" 2>&1 || true
  assert_eq "12b-h ⑮ V9-B5：清空未提交 → 零提交" "$(ob_submits)" "0"
  assert_not "$TMP/ob-h-b5.log" "已确认送达" "12b-h ⑮ V9-B5：绝不把「清空未提交」报成已送达"
  assert_eq "12b-h ⑮ V9-B5：条目立即进 held/（不是被删除）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=unconfirmed" "12b-h ⑮ V9-B5：held 原因 = unconfirmed"
  assert_has "$REPO/docs/team/inbox/dev.md" "eaten enter probe" "12b-h ⑮ V9-B5：durable 副本落收件箱（消息不静默丢）"
  ob_live $TEAM outbox flush >/dev/null 2>&1 || true
  ob_live $TEAM outbox flush --now >/dev/null 2>&1 || true
  assert_eq "12b-h ⑮ V9-B5：终态——flush / flush --now 后仍然零提交（永不重贴）" "$(ob_submits)" "0"
  assert_eq "12b-h ⑮ V9-B5：终态——条目还在 held/（可见、可 drop）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"

  # ⑭ V8-N3：折叠占位符的中间帧（`[paste #1 +1` 半成品，700ms 后才补全）。旧静止判定在半成品帧上
  #    「连续两次相同」→ 提前跳出 → 指纹判据撞上半成品 → 误判竞态 → 干净消息被终态扣在 held/。
  #    修复后：中间帧不算停下来也不算别人的字 → 等渲染完成 → 恰好一次投递、不入 held。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race2 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=700'
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race2" >"$TMP/ob-h-n3.log" 2>&1 || true
  assert_eq "12b-h ⑭ V8-N3：半成品占位符帧 → 等渲染完成后恰好投递一次（不判竞态）" "$(ob_submits)" "1"
  assert_eq "12b-h ⑭ V8-N3：干净消息没有进 held/" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
  assert_not "$REPO/.pi/team/state/outbox/HOLDING.log" "draft-raced" "12b-h ⑭ V8-N3：半成品帧没有被误判成 draft-raced"

  # ⑯ V9-B1/B2 的双向回归：payload 正文自带折叠标记字样时，既不能被误判成渲染中间帧（B1），
  #    也不能被占位符路径压住（B2）。两个方向都用会回显的真夹具端到端钉住。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev ''
  ob_live $TEAM say dev 'the guard waits while the TUI draws [paste #1 +1 frames' >"$TMP/ob-h-b1a.log" 2>&1 || true
  assert_eq "12b-h ⑯a V9-B1：正文含半成品字样 → 恰好一次提交" "$(ob_submits)" "1"
  assert_has "$TMP/ob-h-b1a.log" "已确认送达" "12b-h ⑯a V9-B1：没被中间帧判据永远扣住（确认送达）"
  assert_eq "12b-h ⑯a V9-B1：队列清空、不入 held/" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev ''
  ob_live $TEAM say dev 'see [paste #1 +3 lines] and more text' >"$TMP/ob-h-b2.log" 2>&1 || true
  assert_eq "12b-h ⑯b V9-B2：正文含完整占位符字样 → 恰好一次提交（不被压住）" "$(ob_submits)" "1"
  assert_has "$TMP/ob-h-b2.log" "已确认送达" "12b-h ⑯b V9-B2：正常送达（占位符字样不触发折叠路径）"

  # ⑰（M17 形状①，取代 V9-B6 的「留在框里等下一拍补 Enter」）：折叠占位符的渲染停顿超过
  #    等待上限（≈1.6s）时，复检始终看不到「框里只有我们」→ **收回**：把打进去的半成品清掉，
  #    条目以 draft-raced-retracted 终态进 held/（框里无残留 = 用户实测的那个形状被消灭）。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race3 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=2500'
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race3" >"$TMP/ob-h-b6.log" 2>&1 || true
  assert_eq "12b-h ⑰a M17：停顿超过等待上限 → 第一拍不提交（保守）" "$(ob_submits)" "0"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=draft-raced-retracted" "12b-h ⑰a M17：held 原因 = draft-raced-retracted（已收回）"
  assert_eq "12b-h ⑰a M17：条目在 held/（终态，人核实后 drop/重发）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  tmux capture-pane -p -t "$SESSION:race3" > "$TMP/ob-h-b6-box.log" 2>/dev/null || true
  assert_not "$TMP/ob-h-b6-box.log" "paste #" "12b-h ⑰a M17：收回后半成品不在框里"
  assert_not "$TMP/ob-h-b6-box.log" "line-01" "12b-h ⑰a M17：收回后 payload 正文不在框里（没有残留）"
  sleep 2.6   # 让夹具把（已被删掉的）半成品补全计划跑完：不许自己长回来
  tmux capture-pane -p -t "$SESSION:race3" > "$TMP/ob-h-b6-box2.log" 2>/dev/null || true
  assert_not "$TMP/ob-h-b6-box2.log" "paste #" "12b-h ⑰a M17：渲染补齐之后框里仍然没有残留"
  ob_live $TEAM outbox flush >"$TMP/ob-h-b6b.log" 2>&1 || true
  assert_eq "12b-h ⑰b M17：之后的任何排水都不重贴（终态）" "$(ob_submits)" "0"
  assert_has "$TMP/ob-h-b6b.log" "draft-raced-retracted" "12b-h ⑰b M17：排水报告点名终态原因"
  assert_eq "12b-h ⑰b M17：条目留在 held/（可见、可 drop）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  ob_live $TEAM digest >"$TMP/ob-h-b6-digest.log" 2>&1 || true
  assert_has "$TMP/ob-h-b6-digest.log" "已收回 1" "12b-h ⑰c M17：digest 的 outbox 行报「已收回 1」"

  # ⑰d（升级兼容）：老版本留下的 stall-timeout 条目（框里还立着完整的折叠占位符）必须仍能被
  #     下一拍补上 Enter —— M17 起新条目不再产生这种状态，但已经躺在 held/ 里的不能被丢掉。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race4 ''
  ob_legacy_k="$(printf '%s' "$(cat "$TMP/ob-big.txt")" | grep -c '')"
  tmux send-keys -t "$SESSION:race4" -l "[paste #1 +${ob_legacy_k} lines]"
  sleep 0.4
  ob_legacy_name="1758000000000-0001-legacy.msg"
  mkdir -p "$REPO/.pi/team/state/outbox/held"
  { printf 'kind: draft\ntarget: %s:race4\nfrom: human\ncreated: x\ndedup: -\n---\n' "$SESSION"; cat "$TMP/ob-big.txt"; } > "$REPO/.pi/team/state/outbox/held/$ob_legacy_name"
  printf '%s name=%s reason=stall-timeout held-since=x attempts=1 target=%s:race4\n' \
    "$(date -u +%FT%TZ)" "$ob_legacy_name" "$SESSION" >> "$REPO/.pi/team/state/outbox/HOLDING.log"
  ob_live $TEAM outbox flush >"$TMP/ob-h-b6d.log" 2>&1 || true
  assert_eq "12b-h ⑰d 升级兼容：老 stall-timeout 条目恰好补出一次提交" "$(ob_submits)" "1"
  assert_has "$TMP/ob-h-b6d.log" "已投递" "12b-h ⑰d 升级兼容：重试完成投递（已确认送达）"
  assert_eq "12b-h ⑰d 升级兼容：held/ 清空、不留活动条目" "$(find "$REPO/.pi/team/state/outbox" "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  # 端到端：char 折叠形状必须真的投出去（不是扣在 held/）
  ob_reset; : > "$OB_SUBMIT"
  perl -e 'print "x" x 60, "\n" for 1..6' > "$TMP/ob-chars.txt"   # 366 字符 > 200 → char 折叠
  ob_tui dev '' 'FAKE_TUI_CHARS_MARKER=200'
  ob_live $TEAM draft send "$TMP/ob-chars.txt" --target "$SESSION:dev" >"$TMP/ob-h-c1.log" 2>&1 || true
  assert_eq "12b-h ⑱d M24：char 折叠形状恰好提交一次（旧代码在这里 rc 3）" "$(ob_submits)" "1"
  assert_has "$TMP/ob-h-c1.log" "已确认送达" "12b-h ⑱d M24：确认送达（没被判成混了别人的字）"
  assert_not "$REPO/.pi/team/state/outbox/HOLDING.log" "draft-raced-left" "12b-h ⑱d M24：没有 draft-raced-left 残留分档"
  assert_eq "12b-h ⑱d M24：held/ 空" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

  # ⑲（M24）：收回键序必须真的清掉「展开的多行粘贴」。真实 pi 0.85.1 上 C-a/C-k **不清框**
  #      （实测 3 行展开的粘贴只掉最后一行）——夹具现在按实测建模（C-a/C-k 是空操作、C-u 逐行删），
  #      所以旧实现会在这里留下残留、新实现（C-u + 每步回读）必须清干净。
  ob_reset; : > "$OB_SUBMIT"
  OB_KEYLOG="$TMP/ob-keys.log"; : > "$OB_KEYLOG"
  ob_tui race5 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=2500' "FAKE_TUI_KEY_LOG=$OB_KEYLOG"
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race5" >"$TMP/ob-h-c2.log" 2>&1 || true
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=draft-raced-retracted" "12b-h ⑲a M24：收回成功 → draft-raced-retracted（M17 之后第一次真的有「已收回」）"
  tmux capture-pane -p -t "$SESSION:race5" > "$TMP/ob-h-c2-box.log" 2>/dev/null || true
  assert_not "$TMP/ob-h-c2-box.log" "paste #" "12b-h ⑲a M24：收回后框里没有占位符残留"
  assert_not "$TMP/ob-h-c2-box.log" "line-01" "12b-h ⑲a M24：收回后框里没有 payload 正文残留"
  assert_has "$OB_KEYLOG" "C-u" "12b-h ⑲b M24：收口用的是 C-u（真实 pi 上确实有效的逐行清框键）"
  assert_not "$OB_KEYLOG" "C-c" "12b-h ⑲b M24：C-u 有效时不补 C-c（空框上按 C-c 会退出 pi）"
  # ⑲c 升级路径：C-u 清不动（键位变了）时，才在**框非空**的前提下补一记 C-c，且只补一次
  ob_reset; : > "$OB_SUBMIT"
  : > "$OB_KEYLOG"
  ob_tui race6 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=2500 FAKE_TUI_BREAK_CTRL_U=1' "FAKE_TUI_KEY_LOG=$OB_KEYLOG"
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race6" >"$TMP/ob-h-c3.log" 2>&1 || true
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=draft-raced-retracted" "12b-h ⑲c M24：C-u 不动 → 升级清理后仍算「已收回」"
  assert_eq "12b-h ⑲c M24：C-c 全程只补一记（不许对空框连发）" "$(grep -c '^C-c$' "$OB_KEYLOG" 2>/dev/null || echo 0)" "1"
  tmux capture-pane -p -t "$SESSION:race6" > "$TMP/ob-h-c3-box.log" 2>/dev/null || true
  assert_not "$TMP/ob-h-c3-box.log" "line-01" "12b-h ⑲c M24：升级清理后没有 payload 残留"

  # ⑳（M45）pi 的更新横幅画在框上方：整行 ─ 的 DynamicBorder 与框边框**同形等宽**。
  # 真现场：pi 0.86.0 发布后，空闲框被判 BUSY → 投递守卫把「空闲」读成「有草稿」→ 通知被 held。
  # 这里用假 TUI 按真实现场帧画横幅（真帧/翻转在 12b-h0b，真 pi 在 tests/pm-box-real.sh）。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui banner1 '' 'FAKE_TUI_BANNER=both'
  ob_live env $TEAM draft send "$TMP/ob-three.txt" --target "$SESSION:banner1" >"$TMP/ob-h-banner1.log" 2>&1 || true
  assert_eq "12b-h ⑳ M45：带横幅的空框照样投递（没把横幅读成框内容 → 没有误判 BUSY）" "$(ob_submits)" "1"
  assert_has "$OB_SUBMIT" "alpha line one" "12b-h ⑳ M45：投出去的内容是 payload 本身"
  tmux capture-pane -p -t "$SESSION:banner1" > "$TMP/ob-h-banner1-box.log" 2>/dev/null || true
  assert_has "$TMP/ob-h-banner1-box.log" "Update Available" "12b-h ⑳ M45：这轮帧里真的有横幅（断言不是空转）"
  # 横幅 + 真草稿：读出来的必须是**真草稿**（一个键都不发）
  ob_reset; : > "$OB_SUBMIT"
  ob_tui dev '半句草稿 half a sentence' 'FAKE_TUI_BANNER=both'
  ob_live env $TEAM say dev "check the failing test" >"$TMP/ob-h-banner2.log" 2>&1 || true
  assert_has "$TMP/ob-h-banner2.log" "queued" "12b-h ⑳ M45：横幅 + 真草稿 → 排队（没有粘字）"
  assert_eq "12b-h ⑳ M45：横幅 + 真草稿 → 零提交" "$(ob_submits)" "0"
  tmux capture-pane -p -t "$SESSION:dev" > "$TMP/ob-h-banner2-box.log" 2>/dev/null || true
  assert_has "$TMP/ob-h-banner2-box.log" "Update Available" "12b-h ⑳ M45：这一帧里真有横幅（断言不是空转）"
  assert_has "$TMP/ob-h-banner2-box.log" "半句草稿 half a sentence" "12b-h ⑳ M45：真草稿还在框里（没被粘走）"
  assert_eq "12b-h ⑳ M45：守卫读到的框内容就是**真草稿**（横幅没被当成草稿、草稿也没被横幅吞掉）" \
    "$(ob_target_box_nows "$SESSION:dev")" "半句草稿halfasentence"
fi

# ---------------------------------------------------------------- 12b-i. 扩展：入队而不是打字（规格 requirement 6 第 2 条）
if [ -z "$TS_RUNNER" ]; then
  printf '  (跳过 12b-i：没有能跑 .ts 的运行时)\n'
else
  mkdir -p "$TMP/ob-ext-shim" "$REPO/.worktrees/dev"
  rm -rf "$REPO/.pi/team/state/outbox"
  cat > "$TMP/ob-ext-shim/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/ob-ext-tmux.log"
case "\$*" in
  *window_name*)          printf 'dev\n' ;;
  *session_name*)         printf '%s\n' "$SESSION" ;;
  *pane_current_command*) printf 'pi\n' ;;
  *cursor_y*)             printf '2\n' ;;
  *pane_id*)              printf '%%1\n' ;;
  *bracket_paste_flag*)   printf '1\n' ;;
  *pane_pid*)             printf '%s\n' "\$\$" ;;
  *capture-pane*)         cat "$TMP/ob-box-draft" ;;
  *list-windows*)         printf 'pm\n' ;;
  *has-session*)          exit 0 ;;
esac
exit 0
EOF
  chmod +x "$TMP/ob-ext-shim/tmux"
  : > "$TMP/ob-ext-tmux.log"
  cat > "$TMP/ob-ext.mjs" <<'OBEXT'
import { existsSync, readFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
const [, , ext, root, wt] = process.argv
process.env.TMUX_PANE = 'ob-fake-pane'          // 有 pane 才走敲门那条路
const mod = await import(ext)
const handlers = {}
mod.default({ on: (n, f) => { (handlers[n] ||= []).push(f) }, registerCommand: () => {}, registerTool: () => {}, sendMessage: () => {} })
const emit = async (n, ...a) => { for (const f of handlers[n] ?? []) await f(...a) }
const inbox = join(root, 'docs/team/inbox/dev.md')
rmSync(inbox, { force: true })
rmSync(join(root, '.pi/team/state/notify-dedup'), { force: true })
const cx = (l) => ({ cwd: wt, sessionManager: { getEntries: () => l.map(m => ({ message: m })) } })
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx([]))
await emit('agent_settled', {}, cx([{ role: 'assistant', stopReason: 'stop', content: [{ text: 'OB-EXT-KNOCK' }] }]))
const n = existsSync(inbox) ? readFileSync(inbox, 'utf8').trim().split('\n').filter(Boolean).length : 0
if (n !== 1) { console.error(`FAIL: 期望 1 行收件箱，实际 ${n}`); process.exit(40) }
console.log('ob-ext-ok')
OBEXT
  if env PATH="$TMP/ob-ext-shim:$PATH" $TS_RUNNER "$TMP/ob-ext.mjs" "$SKILL_DIR/extension/team-notify.ts" "$REPO" "$REPO/.worktrees/dev" >"$TMP/ob-ext.log" 2>&1; then
    ok "12b-i 扩展：脏 PM 框下照常写收件箱（runner=$TS_RUNNER）"
  else
    bad "12b-i 扩展运行失败（runner=$TS_RUNNER）"; cat "$TMP/ob-ext.log"
  fi
  assert_eq "12b-i 扩展自己不敲键盘（零 send-keys / paste-buffer）" "$(grep -c 'send-keys\|paste-buffer' "$TMP/ob-ext-tmux.log" || true)" "0"
  assert_eq "12b-i 扩展把敲门入队一条" "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*pm*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_has "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*pm*.msg' | head -1)" "dedup: dev|[auto]|" "12b-i 扩展把自己的去重键带进条目"
fi

# ---------------------------------------------------------------- 12b-pi. M30 投递换道：pi 通道零粘贴（收件箱监视唤醒）
# 用户拍板：不再修「人的草稿 vs 我们刚贴进去的 payload」那套框检测（五次 draft-race 事故的结论）。
# 目标是装了 inbox-watch 扩展的 pi 会话时（证据 = state/inbox-watch/<key>.reg 里 pid 活着 + cwd 在本项目），
# 投递 = durable 收件箱 + spool 一行指针，由会话里的扩展唤醒 —— 一个键都不碰。
# 非 pi target 与显式逃生门（--now / flush --now）的老路（守卫 / 收回 / held）原样保留。
section "12b-pi · M30 投递换道：pi 通道零 tmux 粘贴（收件箱监视唤醒）"
PIW="$REPO/.pi/team/state/inbox-watch"
piw_reg() { # <key> <target> <inbox> [pid] [cwd]
  mkdir -p "$PIW"
  printf 'version=1\ntarget=%s\ninbox=%s\npid=%s\ncwd=%s\nstarted=x\nheartbeat=%s\n' \
    "$2" "$3" "${4:-$$}" "${5:-$REPO}" "$(date +%s)" > "$PIW/$1.reg"
}
piw_reset() { rm -rf "$PIW"; }

# ① pi 通道 + 脏框：一个键都不发（脏框在这条通道上根本没有被问过）
ob_reset; piw_reset
piw_reg pi-dev "$SESSION:dev" dev
ob_box "$TMP/ob-box-draft"
: > "$TMP/ob-calls.log"
if ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM say dev "M30-PI-CHANNEL message" >"$TMP/pi-say.log" 2>&1; then
  ok "12b-pi say：退出码 0"
else
  bad "12b-pi say 失败"; cat "$TMP/pi-say.log"
fi
assert_has "$TMP/pi-say.log" "pi 监视通道" "12b-pi 报的是「pi 监视通道」"
assert_not "$TMP/pi-say.log" "已确认送达" "12b-pi 不冒称「已确认送达」（没打字就没有粘贴确认）"
assert_eq "12b-pi 脏框下 tmux 一次都没被调用（零粘贴、零 capture）" \
  "$(wc -l < "$TMP/ob-calls.log" 2>/dev/null | tr -d ' ')" "0"
assert_has "$REPO/docs/team/inbox/dev.md" "[say] agent:dev · M30-PI-CHANNEL message" \
  "12b-pi durable 收件箱行（tag=kind；收件人名字来自监视器的注册）"
assert_has "$PIW/pi-dev.wake" "$(printf 'say\tpm\tdev\tM30-PI-CHANNEL message')" \
  "12b-pi spool 一行指针（ts/kind/from/durable/预览）"
assert_eq "12b-pi 条目已投递、队列不残留" \
  "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_has "$REPO/.pi/team/state/outbox/delivered.log" "$(printf '\twatch')" "12b-pi delivered.log 记的是 watch 通道"

# ② 没有注册 → 老路原样（空框立刻投递，真的打字）
ob_reset; piw_reset
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM say dev "M30-NONPI-PASTE" >"$TMP/pi-nonpi.log" 2>&1 || true
assert_has "$TMP/pi-nonpi.log" "已确认送达" "12b-pi 无注册（非 pi / 未装扩展）→ 仍是粘贴路径"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi 无注册时真的打字（换道没有误伤老路）"

# ③ 过期的注册（pid 已死）不算活监视器：陈旧注册不能把消息骗进一条没人读的 spool
ob_reset; piw_reset
( sleep 0.05 ) & PIW_DEAD_PID=$!; wait "$PIW_DEAD_PID" 2>/dev/null || true
piw_reg pi-dev "$SESSION:dev" dev "$PIW_DEAD_PID"
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM say dev "M30-PI-STALE" >"$TMP/pi-stale.log" 2>&1 || true
assert_not "$TMP/pi-stale.log" "pi 监视通道" "12b-pi 死掉的 pid 不算活监视器"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi 陈旧注册 → 老路照旧打字"
assert_not_file "$PIW/pi-dev.wake" "12b-pi 陈旧注册不写 spool"

# ④ 注册里的 cwd 不在本项目 → 不认（跨项目的注册不能接管本项目的投递）
ob_reset; piw_reset
piw_reg pi-foreign "$SESSION:dev" dev "$$" "/tmp"
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM say dev "M30-PI-FOREIGN" >"$TMP/pi-foreign.log" 2>&1 || true
assert_not "$TMP/pi-foreign.log" "pi 监视通道" "12b-pi cwd 不在本项目的注册不算（守卫按证据判定）"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi 外来注册 → 老路照旧打字"

# ④b 注册没写 cwd（写不进去/老版本）→ 退回心跳：新鲜心跳认，陈旧心跳不认（扩展的定时器停了就不叫活）
ob_reset; piw_reset; mkdir -p "$PIW"
printf 'version=1\ntarget=%s\ninbox=dev\npid=%s\nstarted=x\nheartbeat=%s\n' \
  "$SESSION:dev" "$$" "$(date +%s)" > "$PIW/pi-nocwd.reg"
ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM say dev "M30-PI-NOCWD" >"$TMP/pi-nocwd.log" 2>&1 || true
assert_has "$TMP/pi-nocwd.log" "pi 监视通道" "12b-pi 没有 cwd + 新鲜心跳 → 仍然认（有界回退，不是静默）"
ob_reset; piw_reset; mkdir -p "$PIW"
printf 'version=1\ntarget=%s\ninbox=dev\npid=%s\nstarted=x\nheartbeat=%s\n' \
  "$SESSION:dev" "$$" "$(( $(date +%s) - 4000 ))" > "$PIW/pi-stalehb.reg"
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM say dev "M30-PI-STALEHB" >"$TMP/pi-stalehb.log" 2>&1 || true
assert_not "$TMP/pi-stalehb.log" "pi 监视通道" "12b-pi 没有 cwd + 陈旧心跳 → 不算活监视器"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi 陈旧心跳 → 老路照旧打字"

# ⑤ 真路径 notify：durable 行由发送方写（--inbox-written），通道不许再写第二行；也不需要 tmux/存活启发式
ob_reset; piw_reset
piw_reg pi-pm "$SESSION:pm" pm
printf 'M30-PI-KNOCK summary\n' > "$TMP/pi-knock.txt"
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM notify pm --from-file "$TMP/pi-knock.txt" >"$TMP/pi-knock.log" 2>&1 || true
assert_has "$TMP/pi-knock.log" "pi 监视通道" "12b-pi notify：走 pi 通道"
assert_not "$TMP/pi-knock.log" "不在 tmux 会话里" "12b-pi notify：pi 通道不吃「不在 tmux 里」那条门（它不需要 tmux）"
assert_not "$TMP/pi-knock.log" "PM 不在运行" "12b-pi notify：注册（pid+cwd）本身就是 PM 活着的证据"
assert_eq "12b-pi notify：tmux 零调用" "$(wc -l < "$TMP/ob-calls.log" 2>/dev/null | tr -d ' ')" "0"
assert_eq "12b-pi notify：durable 行只写一次（--inbox-written 防重）" \
  "$(grep -c 'M30-PI-KNOCK summary' "$REPO/docs/team/inbox/pm.md" 2>/dev/null || true)" "1"
assert_has "$PIW/pi-pm.wake" "$(printf 'knock\tpm\tpm\t')" "12b-pi notify：spool 行记 durable=pm（收件箱里确实有这一条）"
assert_eq "12b-pi notify：条目已投递、队列清空" \
  "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ⑥ 人的草稿（draft）：pi 通道上默认落进目标收件箱（正文绝不只活在指针里）
ob_reset; piw_reset
piw_reg pi-dev "$SESSION:dev" dev
printf 'M30-PI-DRAFT body line\n' > "$TMP/pi-draft.txt"
ob_run env OB_BOX="$TMP/ob-box-draft" OB_ECHO=1 $TEAM draft send "$TMP/pi-draft.txt" --target "$SESSION:dev" >"$TMP/pi-draft.log" 2>&1 || true
assert_has "$TMP/pi-draft.log" "pi 监视通道" "12b-pi draft：走 pi 通道（人的草稿也换道）"
assert_has "$REPO/docs/team/inbox/dev.md" "[draft] agent:dev · M30-PI-DRAFT body line" \
  "12b-pi draft：durable 收件箱行（默认目标收件箱）"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-pi draft：一个键都没发"

# ⑦ --now 是显式逃生门：pi target 也照旧打字（并留审计、不写 spool）
ob_reset; piw_reset
piw_reg pi-dev "$SESSION:dev" dev
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM say dev "M30-PI-FORCED" --now >"$TMP/pi-now.log" 2>&1 || true
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi --now 仍然打字（人的显式逃生门）"
assert_has "$REPO/.pi/team/state/outbox/forced.log" "kind=say" "12b-pi --now 写 forced.log（跳过守卫有审计）"
assert_not_file "$PIW/pi-dev.wake" "12b-pi --now 不走 pi 通道（不写 spool）"

# ⑧ 两条内建启动链都挂上了扩展（worker 与 PM）
assert_has "$TMP/print.log" "-e $SKILL_DIR/extension/team-inbox-watch.ts" "12b-pi worker 启动命令 -e 挂 inbox-watch"
assert_has_echo "$DEFAULT_CMD" "extension/team-inbox-watch.ts" "12b-pi PM 启动命令也挂 inbox-watch"

# ⑩ P28/B6：预览按**字符**边界裁 —— 多字节字符恰好跨 700 字节边界时，spool 行仍是合法 UTF-8
#    （红：`cut -c1-700` 按字节裁会把一个字符截半 → 读者侧曾因此把 offset 推过文件末尾）
ob_reset; piw_reset
piw_reg b6-dev "$SESSION:dev" dev
B6_PAYLOAD="xy$(printf '红%.0s' $(seq 1 300))"
# 夹具有效性对照：同样的 payload 用旧的字节裁法确实写出非法 UTF-8（不是空转断言）
if printf '%s' "$B6_PAYLOAD" | LC_ALL=C cut -c1-700 | LC_ALL=C iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
  bad "12b-pi ⑩ B6：夹具前提不成立（旧的 cut -c1-700 居然也是合法 UTF-8）"
else
  ok "12b-pi ⑩ B6：夹具前提成立（旧的字节裁法会把 700 字节边界上的字符截半）"
fi
ob_run $TEAM say dev "$B6_PAYLOAD" >"$TMP/b6-say.log" 2>&1 || true
assert_has "$TMP/b6-say.log" "pi 监视通道" "12b-pi ⑩ B6：走 pi 通道（spool 行就是写入者的产物）"
if [ -f "$PIW/b6-dev.wake" ]; then
  if LC_ALL=C iconv -f UTF-8 -t UTF-8 < "$PIW/b6-dev.wake" >/dev/null 2>&1; then
    ok "12b-pi ⑩ B6：spool 行是合法 UTF-8"
  else
    bad "12b-pi ⑩ B6：spool 行不是合法 UTF-8（预览被截半）"; od -An -tx1 "$PIW/b6-dev.wake" | tail -2
  fi
  assert_eq "12b-pi ⑩ B6：预览里没有 U+FFFD 替换符" "$(grep -c $'\xef\xbf\xbd' "$PIW/b6-dev.wake" || true)" "0"
  assert_eq "12b-pi ⑩ B6：预览裁在完整字符上（698 = 2 + 3×232 字节，不是 700 的字节截断）" \
    "$(LC_ALL=C awk -F'\t' 'NR==1 {print length($5)}' "$PIW/b6-dev.wake")" "698"
  assert_has "$REPO/docs/team/inbox/dev.md" "$B6_PAYLOAD" "12b-pi ⑩ B6：durable 收件箱仍是全文（只有 spool 预览被裁）"
else
  bad "12b-pi ⑩ B6：spool 行没写出来"; cat "$TMP/b6-say.log"
fi
piw_reset

# ⑨ 真扩展夹具（假 Pi 宿主 + 真 CLI 端到端）：注册 / 监视唤醒 / 合并 / 基线 / 清场 / 账本
# M53/B4：夹具现在先量前提（一次真 fs.watch）——前提不可用时**只**把 watcher 用例标成可见 SKIP，
# 轮询兜底与 CLI 侧的用例照跑照判。所以这一段的具名断言按前提分两支，且分成两类：
#   * 与 watcher 无关的（S1/S7/M46/S18–S20/reverse guard）：两种前提下都必须成立；
#   * 只靠 watcher 的（S2/S4/S10–S13/S21）：可用 → 逐条 PASS；不可用 → 逐条 SKIP（可见，不静默少跑）。
if [ -z "$TS_RUNNER" ]; then
  printf '  (跳过 12b-pi 扩展夹具：node 未启用类型剥离，且没有 bun/tsx)\n'
else
  M53_HARNESS="$SKILL_DIR/tests/team-inbox-watch-harness.mjs"
  M53_EXT="$SKILL_DIR/extension/team-inbox-watch.ts"
  $TS_RUNNER "$M53_HARNESS" "$M53_EXT" >"$TMP/piw-harness.log" 2>&1
  M53_IW_RC=$?
  M53_IW_PRE="$(grep -m1 '^TEAM-IW-PREREQ' "$TMP/piw-harness.log" 2>/dev/null || true)"
  M53_IW_OK=0
  case "$M53_IW_PRE" in *watch=ok*) M53_IW_OK=1 ;; esac
  if [ "$M53_IW_RC" -eq 0 ]; then
    if [ "$M53_IW_OK" = "1" ]; then
      ok "12b-pi 扩展夹具全绿（runner=$TS_RUNNER，$(grep -c 'TEAM-IW-CASE PASS' "$TMP/piw-harness.log") 条用例）"
    else
      ok "12b-pi 扩展夹具：watcher 前提不可用（$(grep -m1 '^TEAM-IW-PREREQ' "$TMP/piw-harness.log")）——watcher 用例可见 SKIP，兜底/CLI 用例照跑（rc=0）"
    fi
  else
    bad "12b-pi 扩展夹具失败（runner=$TS_RUNNER，rc=$M53_IW_RC）"; grep 'TEAM-IW-CASE FAIL' "$TMP/piw-harness.log" | sed 's/^/     /'
  fi
  assert_has "$TMP/piw-harness.log" "TEAM-IW-PREREQ" "12b-pi/M53 夹具打印前提行（环境与代码可分辨）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S1 session_start creates exactly one .reg" "12b-pi 扩展写就绪注册（发送方的判据）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S7 shutdown removes the registry file" "12b-pi 会话结束删注册（不骗发送方）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS reverse guard" "12b-pi 反向守卫：真实仓库 state/ 未被触碰"
  # M46：跳过留痕 / 注册清痕 / 继承的 TEAM_STATE_DIR 不许指向别的项目（harness M46-S14–S16；
  # 翻转证据见 tests/flip-m46.sh）
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS M46-S14 a session-name mismatch leaves exactly one .skip record" \
    "12b-pi M46：会话名不符时跳过也要在**本项目**留痕（<key>.skip）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS M46-S14 the real CLI reports the delivery degradation in \`team status\`" \
    "12b-pi M46：真 CLI 的 status 能读到这条痕迹并报降级"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS M46-S15 a successful registration clears the stale .skip for its target" \
    "12b-pi M46：注册成功会删掉旧痕迹（不再骗人）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS M46-S16 an inherited TEAM_STATE_DIR pointing at another project is refused" \
    "12b-pi M46：继承的 TEAM_STATE_DIR 指向别的项目 → 拒绝（M40 的 state 面）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS M46-S17 an inherited TEAM_CONFIG_FILE pointing at another project is ignored" \
    "12b-pi M46：继承的 TEAM_CONFIG_FILE 指向别的项目 → 忽略（会话名来自本项目配置）"
  # P28：字节真值的 offset / 证据化的缩容与收敛 / 过期门槛 / 账本契约（harness S18–S21；翻转见 tests/flip-p25.sh）
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S18 the baseline is the spool byte size" \
    "12b-pi P28：字节裁切的 spool 行不再把 offset 推过文件末尾（baseline = 文件字节数）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S18 idle ticks after a byte-clipped line add no spool shrink" \
    "12b-pi P28：非法 UTF-8 的 spool 不再每拍伪造一次缩容"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S19a a one-byte regression with an unchanged head is repaired with one offset clamp" \
    "12b-pi P28：头部不变的小回退是一次修复（offset clamp），不是重扫"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S19a the read that starts inside the clamped line resyncs" \
    "12b-pi P28：clamp 落在行中时碎片被 resync 跳过（半行绝不投递）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S19b a rewrite with a changed head is rescanned exactly once" \
    "12b-pi P28：头部变了才是真重写（一次有界重扫，下一拍收敛）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S19c the same (size, head) is recorded as a repeat and clamped" \
    "12b-pi P28：同一 (size, head) 不重扫第二次（shrink repeat + clamp）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S20a an hour-old unseen line is rescan-counted, never woken about" \
    "12b-pi P28：一小时前的未投递行只计数、不唤醒（durable 副本与 spool 字节都还在）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S20c a line whose timestamp is not a number is delivered" \
    "12b-pi P28：时间戳不可解析的行照投并计数（不静默吞）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S21a a dedup-only rescan reads deliver=0 with a non-zero dup" \
    "12b-pi P28：账本把新流量与恢复分开（去重重扫 deliver=0、total 不动）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S21b a stale-only rescan reads deliver=0 with stale=" \
    "12b-pi P28：只含过期行的重扫 deliver=0 + stale=<n>"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S21c the wake line reads n=2 and total grows by exactly two" \
    "12b-pi P28：真投递的 wake n=2、total +2"
  # P81（wake-delivery-idempotence）：写前日志 / 至多一次 / fail-closed / 源行点名（harness S25*/S26；
  # 翻转证据见 tests/flip-p71.sh）。这一组用轮询（不依赖 watcher 前提），两种前提下都必须逐条 PASS。
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25j the journal is start → read → intent → sent" \
    "12b-pi P81：投递日志按 start → read → intent → sent 的顺序落盘（一行一条记录）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25j a stale line writes no journal record" \
    "12b-pi P81：过期行不写日志记录、不唤醒、只计数"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25g startup accounting names the swallowed lines" \
    "12b-pi P81：启动核算（baseline swallowed n=）且基线契约不变"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25r a recovered line past the horizon is counted stale" \
    "12b-pi P81：已过期的恢复只计数（stale=1）不唤醒（不是 recovery=）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25z the abort knob without TEAM_SMOKE_FIXTURE=1 is printed as ignored" \
    "12b-pi P81：崩溃注入旋钮是夹具专属，裸设无效且留痕"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25a the child is a real separate process killed at the injection point" \
    "12b-pi P81：崩溃用例真的在另一个进程里 SIGKILL（不是内存里重启）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25a exactly one recovery wake is sent for the crashed line" \
    "12b-pi P81：read 后被杀 → 重启恰好一次 recovery（不是两次）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25b the restart sends no wake at all" \
    "12b-pi P81：intent 后被杀 → 重启零重投（结果未知）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25b the ledger records exactly one inflight assumed n=1" \
    "12b-pi P81：inflight assumed 恰好记一次（且不重投）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25c a raising message API is recorded as wake failed once per attempt" \
    "12b-pi P81：会话 API 拒绝 → 每次尝试一条 wake failed，下一拍重试"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25c nothing is sent while the journal is unwritable" \
    "12b-pi P81：日志写不进去 → 一条都不发（fail-closed）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25c the line is delivered exactly once when the journal becomes writable again" \
    "12b-pi P81：日志恢复可写后恰好投一次"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25c a failed wake is not retried past the freshness horizon" \
    "12b-pi P81：failed 的重试不越过新鲜度地平线"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25d the two rows differ by source time and identity" \
    "12b-pi P81：逐字相同的两条 payload 靠身份与源时间区分"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25e the first start imports <key>.seen once and records it" \
    "12b-pi P81：老 .seen 只被一次性导入（之后日志是唯一记忆）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25e a torn tail is treated as inflight assumed" \
    "12b-pi P81：撕裂尾=结果未知，绝不重投"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25e compaction keeps the journal under the bound" \
    "12b-pi P81：日志越界即压到界内并写 floor="
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25e an identity below the eviction floor is unprovable, never woken" \
    "12b-pi P81：淘汰下限以下的身份 unprovable，永不唤醒"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25f the recorded truncation reads deliver=0 (the incident shape)" \
    "12b-pi P81：事故重放（原始字节）第一拍 rescan deliver=0"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S25f a one-shot truncate+rewrite is rescanned, classified and silent" \
    "12b-pi P81：事故重放零唤醒（dup=11 + stale=1，逐条分类）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S26 every listed line names its own absolute source time and identity" \
    "12b-pi P81：唤醒文本点名每条源行的绝对时间与身份"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S26 the wake names the delivery journal the identities were recorded in" \
    "12b-pi P81：唤醒文本给出投递日志路径（收件方可自证）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S10 the printed identity resolves to exactly one delivered.log record" \
    "12b-pi P81：唤醒文本的 id 能在 delivered.log 里一一定位（端到端）"
  if [ "$M53_IW_OK" = "1" ]; then
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S1 session_start creates exactly one .reg" "12b-pi 扩展写就绪注册（发送方的判据）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S2 wake is a custom team-inbox message with triggerTurn+followUp" "12b-pi 唤醒用的是 sendMessage(followUp+triggerTurn)"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S4 long payload is truncated in the wake (no payload dump)" "12b-pi 唤醒只带截断预览（不带 payload 全文）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S7 shutdown removes the registry file" "12b-pi 会话结束删注册（不骗发送方）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S10 the running extension wakes the session (zero model calls)" \
    "12b-pi 端到端：真 CLI 投递 → 监视扩展唤醒（零模型调用）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS reverse guard" "12b-pi 反向守卫：真实仓库 state/ 未被触碰"
  # M43：外部截断/重写 spool 的重放保真（harness S11–S13；翻转证据见 tests/flip-m43.sh）
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S11 external truncate+rewrite does not redeliver" \
    "12b-pi M43：外部截断+重写不再重放已投递行"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S11 total is not inflated" \
    "12b-pi M43：total 只随真实新增增长（不被重放灌水）"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S12 ledger records the rescan counts" \
    "12b-pi M43：shrink 后的 rescan 有界（只投最近 N 条真新）且计数进账本"
  assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE PASS S13 after a restart" \
    "12b-pi M43：去重记忆跨会话重启（<key>.deliver 投递日志持久化）"
  else
    # 前提不可用：watcher 用例必须**逐条可见 SKIP**（带测得的 errno），一个字都不许静默少跑
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S2 " "12b-pi/M53 不可用前提：S2（只靠 watcher）可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S4 " "12b-pi/M53 不可用前提：S4 可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S10 " "12b-pi/M53 不可用前提：S10（端到端唤醒）可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S11 " "12b-pi/M53 不可用前提：S11 可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S12 " "12b-pi/M53 不可用前提：S12 可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S13 " "12b-pi/M53 不可用前提：S13 可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-CASE SKIP S21 " "12b-pi/M53 不可用前提：S21 可见 SKIP"
    assert_has "$TMP/piw-harness.log" "TEAM-IW-HARNESS OK (skipped=" "12b-pi/M53 不可用前提：总结行报出可见跳过数（不静默）"
    assert_eq "12b-pi/M53 不可用前提：没有一条 FAIL（跳过不是失败，但也不是绿）" \
      "$(grep -c 'TEAM-IW-CASE FAIL' "$TMP/piw-harness.log" || true)" "0"
  fi

  # M53/B4 · 前提机制每次门禁都自证：强制不可用 + 只看 S2,S22,S23 → S2 SKIP、S22/S23 PASS、rc 0
  if TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC TEAM_IW_ONLY=S2,S22,S23 $TS_RUNNER "$M53_HARNESS" "$M53_EXT" >"$TMP/piw-force.log" 2>&1; then
    ok "12b-pi/M53 强制不可用前提：S2 可见 SKIP、轮询兜底 S22/S23 照跑，退出码 0"
  else
    bad "12b-pi/M53 强制不可用前提：夹具非 0 退出"; grep 'TEAM-IW-CASE' "$TMP/piw-force.log" | tail -8 | sed 's/^/     /'
  fi
  assert_has "$TMP/piw-force.log" "TEAM-IW-PREREQ watch=errno=ENOSPC" "12b-pi/M53 前提行点名 errno"
  assert_has "$TMP/piw-force.log" "forced=1" "12b-pi/M53 前提行标明 forced（测试事故不是真事故）"
  assert_has "$TMP/piw-force.log" "TEAM-IW-CASE SKIP S2 " "12b-pi/M53 不可用前提：只靠 watcher 的 S2 可见 SKIP"
  assert_has "$TMP/piw-force.log" "TEAM-IW-CASE PASS S22 the failure line names errno" "12b-pi/M53 不可用前提：S22 真跑真判"
  assert_has "$TMP/piw-force.log" "TEAM-IW-CASE PASS S23 a forced-failure session still wakes" "12b-pi/M53 不可用前提：S23 兜底投递真跑真判"
  assert_has "$TMP/piw-force.log" "TEAM-IW-HARNESS OK (skipped=" "12b-pi/M53 夹具自报可见跳过数（不是静默少跑）"
  # M53/B4 · 严格模式拒绝同一个不可用前提：S2 必须 FAIL 且非 0（SKIP 不是无条件绿）
  if TEAM_INBOX_WATCH_FORCE_FAIL=ENOSPC TEAM_IW_REQUIRE_WATCH=1 TEAM_IW_ONLY=S2 $TS_RUNNER "$M53_HARNESS" "$M53_EXT" >"$TMP/piw-strict.log" 2>&1; then
    bad "12b-pi/M53 严格模式：同一个不可用前提居然判绿"
  else
    ok "12b-pi/M53 严格模式：同一个不可用前提判红（非 0）"
  fi
  assert_has "$TMP/piw-strict.log" "TEAM-IW-CASE FAIL S2 " "12b-pi/M53 严格模式点名 S2"
  assert_has "$TMP/piw-strict.log" "TEAM-IW-HARNESS FAIL" "12b-pi/M53 严格模式的总结行是 FAIL"
fi

# 不留注册：后面的段落（teardown / panel / …）不许被这条通道接管
piw_reset

# ---------------------------------------------------------------- 12b-pi2. M46 投递降级可见 + 慢路径自愈
# 事故（2026-09-20，用户报「ai_interview 又没自动发消息」）：PM 进程加载的是旧扩展 → 按继承的
# TEAM_* 解到 pm-skills → 会话名不符 → 每 2s 一次 `skip setup` 而痕迹全写进**别人的** state；
# 投递静默退回输入框粘贴路径 → 一次 draft-raced-left + 两条消息滞留。M46 的三条契约在这里钉住：
#   ① 跳过要在**本项目**留痕，doctor/status/面板看得见（活注册在 / 死 pid 旧痕时不报）；
#   ② 没有 watcher 时慢路径仍能投完（串行重试，不永久滞留）；
#   ③ 残留（payload 已不在框里）与目标已消失的 held 条目要被点名，清理只能由人显式做。
section "12b-pi2 · M46 投递降级可见（skip 留痕）与慢路径自愈（残留/目标消失）"

# ① 会话名不符的**活**痕迹 → status / doctor / 面板都报降级；活注册在则一个字都不加
ob_reset; piw_reset; mkdir -p "$PIW"
printf 'version=1\ntarget=ai-interview:pm\nkey=ai-interview_pm-00000000\nsession=ai-interview\nwindow=pm\nexpect=%s\ninbox=pm\nreason=session-mismatch\ndetail=session ai-interview != %s\npid=%s\ncwd=%s\nts=2026-09-20T16:11:45.129Z\nheartbeat=%s\n' \
  "$SESSION" "$SESSION" "$$" "$REPO" "$(date +%s)" > "$PIW/ai-interview_pm-00000000.skip"
ob_run $TEAM status >"$TMP/m46-status.log" 2>&1 || true
assert_has "$TMP/m46-status.log" "投递通道降级" "12b-pi2 ① status 报投递通道降级（不再静默退回慢路径）"
assert_has "$TMP/m46-status.log" "会话名不符" "12b-pi2 ① status 说出原因（会话名不符）"
assert_has "$TMP/m46-status.log" "$SESSION:pm" "12b-pi2 ① status 点名本项目的 PM target"
assert_has "$TMP/m46-status.log" "重启进程" "12b-pi2 ① 告警给出出路（扩展在进程启动时加载）"
ob_run $TEAM doctor >"$TMP/m46-doctor.log" 2>&1 || true
assert_has "$TMP/m46-doctor.log" "投递通道 inbox-watch" "12b-pi2 ① doctor 有「投递通道 inbox-watch」一条"
assert_has "$TMP/m46-doctor.log" "会话名不符" "12b-pi2 ① doctor 报同一条降级与原因"
ob_run $TEAM __panel-data --block pm >"$TMP/m46-pm.json" 2>&1 || true
assert_has "$TMP/m46-pm.json" '"delivery_warning": "会话名不符' "12b-pi2 ① 面板 pm 块带 delivery_warning（pulse 看得见）"
# 负对照（翻转的另一半）：活注册在 → 告警消失、面板字段为空
piw_reset; piw_reg m46-pm "$SESSION:pm" pm
ob_run $TEAM status >"$TMP/m46-status-ok.log" 2>&1 || true
assert_not "$TMP/m46-status-ok.log" "投递通道降级" "12b-pi2 ①（负对照）活注册在时不报降级"
ob_run $TEAM __panel-data --block pm >"$TMP/m46-pm-ok.json" 2>&1 || true
assert_has "$TMP/m46-pm-ok.json" '"delivery_warning": ""' "12b-pi2 ①（负对照）活注册在时面板提示为空"
# 负对照：死 pid 的旧痕迹不是证据（不制造假警报）
piw_reset; mkdir -p "$PIW"
( sleep 0.05 ) & M46_DEAD=$!; wait "$M46_DEAD" 2>/dev/null || true
printf 'version=1\ntarget=ai-interview:pm\nkey=ai-interview_pm-00000000\nsession=ai-interview\nwindow=pm\nexpect=%s\ninbox=pm\nreason=session-mismatch\ndetail=x\npid=%s\ncwd=%s\nheartbeat=%s\n' \
  "$SESSION" "$M46_DEAD" "$REPO" "$(date +%s)" > "$PIW/ai-interview_pm-00000000.skip"
ob_run $TEAM status >"$TMP/m46-status-stale.log" 2>&1 || true
assert_not "$TMP/m46-status-stale.log" "投递通道降级" "12b-pi2 ①（负对照）死 pid 的旧痕迹不报降级"
piw_reset

# ② 没有 watcher（粘贴慢路径）：脏框先排队，框空后的下一拍投完，队列不残留
ob_reset; piw_reset
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-draft" $TEAM say dev "M46-QUEUED-THEN-DELIVERED" >"$TMP/m46-queued.log" 2>&1 || true
assert_has "$TMP/m46-queued.log" "queued for" "12b-pi2 ② 无 watcher + 脏框 → 报 queued（不粘字）"
assert_not "$TMP/ob-calls.log" "send-keys" "12b-pi2 ② 排队时一个键都没发"
assert_eq "12b-pi2 ② 条目留在活动队列（可重试）" \
  "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM outbox flush >"$TMP/m46-flush.log" 2>&1 || true
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi2 ② 框空后的下一拍真的投递（串行重试）"
assert_eq "12b-pi2 ② 投完队列不残留（不永久滞留）" \
  "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"

# ③ 残留巡检（只读）：payload 已不在框里 → 记账本 + 状态行不再说谎；排队的消息同拍投出去
ob_reset; piw_reset
M46_S="$REPO/.pi/team/state"; mkdir -p "$M46_S/outbox/held"
M46_HELD="1700000000000-0001-$SESSION:dev.msg"
printf 'kind: say\ntarget: %s:dev\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-RESIDUE-GONE\n' "$SESSION" > "$M46_S/outbox/held/$M46_HELD"
printf '2026-09-20T02:26:59Z name=%s reason=draft-raced-left held-since=2026-09-20T02:26:59Z attempts=1 target=%s:dev\n' \
  "$M46_HELD" "$SESSION" > "$M46_S/outbox/HOLDING.log"
ob_run env OB_BOX="$TMP/ob-box-empty" $TEAM outbox enqueue --kind say --target "$SESSION:dev" --payload "M46-QUEUED-AFTER-RESIDUE" >/dev/null 2>&1
: > "$TMP/ob-calls.log"
ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 $TEAM outbox flush >"$TMP/m46-sweep.log" 2>&1 || true
assert_has "$M46_S/outbox/HOLDING.log" "residue-clear" "12b-pi2 ③ 残留已不在框里 → 记账本（residue-clear）"
assert_has "$M46_S/outbox/HOLDING.log" "why=box-clear" "12b-pi2 ③ 账本说明判据（框里已无残留）"
assert_has "$TMP/ob-calls.log" "send-keys" "12b-pi2 ③ 同一拍把排队的消息投出去（残留不再堵队列）"
assert_eq "12b-pi2 ③ 投完只剩那条终态 held" \
  "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
ob_run $TEAM status >"$TMP/m46-status-residue.log" 2>&1 || true
assert_not "$TMP/m46-status-residue.log" "留在框里" "12b-pi2 ③ 状态行不再报「留在框里」（残留已清）"
# 负对照：payload 还在框里 → 不记账本、状态行照旧报「留在框里」
M46_S="$REPO/.pi/team/state"
M46_HELD2="1700000000001-0002-$SESSION:dev.msg"
printf 'kind: say\ntarget: %s:dev\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-RESIDUE-STUCK\n' "$SESSION" > "$M46_S/outbox/held/$M46_HELD2"
printf '2026-09-20T02:27:00Z name=%s reason=draft-raced-left held-since=x attempts=1 target=%s:dev\n' \
  "$M46_HELD2" "$SESSION" >> "$M46_S/outbox/HOLDING.log"
printf '%s\n' "$(printf '%.0s─' $(seq 1 80))" "" "M46-RESIDUE-STUCK" "" " k3  Kimi Coding  max" "$(printf '%.0s─' $(seq 1 80))" "footer" > "$TMP/m46-box-stuck"
ob_run env OB_BOX="$TMP/m46-box-stuck" $TEAM outbox flush >"$TMP/m46-sweep2.log" 2>&1 || true
assert_eq "12b-pi2 ③（负对照）残留还在框里时不记 residue-clear" \
  "$(grep -c "residue-clear entry=$M46_HELD2" "$M46_S/outbox/HOLDING.log" || true)" "0"
ob_run env OB_BOX="$TMP/m46-box-stuck" $TEAM status >"$TMP/m46-status-stuck.log" 2>&1 || true
assert_has "$TMP/m46-status-stuck.log" "留在框里 1" "12b-pi2 ③（负对照）残留真的在框里时照旧报「留在框里」"

# ④ 目标已消失的 held 条目：被点名、可清理；活目标的条目不许被 gone 误伤
ob_reset; piw_reset
M46_S="$REPO/.pi/team/state"; mkdir -p "$M46_S/outbox/held"
M46_DEADHELD="1700000000002-0003-old-session:pi.msg"
M46_LIVEHELD="1700000000003-0004-$SESSION:dev.msg"
printf 'kind: say\ntarget: old-session:pi\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-DEAD-TARGET\n' > "$M46_S/outbox/held/$M46_DEADHELD"
printf 'kind: say\ntarget: %s:dev\nfrom: pm\ncreated: x\ndedup: -\n---\nM46-LIVE-TARGET\n' "$SESSION" > "$M46_S/outbox/held/$M46_LIVEHELD"
printf '2026-09-20T02:28:00Z name=%s reason=expired-nopane held-since=x attempts=1 target=old-session:pi\n' "$M46_DEADHELD" > "$M46_S/outbox/HOLDING.log"
printf '2026-09-20T02:28:01Z name=%s reason=expired-ttl held-since=x attempts=1 target=%s:dev\n' "$M46_LIVEHELD" "$SESSION" >> "$M46_S/outbox/HOLDING.log"
M46_SHIM="$TMP/m46-shim"; mkdir -p "$M46_SHIM"
cat > "$M46_SHIM/tmux" <<'M46SHIM'
#!/usr/bin/env bash
case "$1" in
  has-session) [ "${3:-}" = "${M46_LIVE_SESSION:-}" ] && exit 0 || exit 1 ;;
  display-message) case " $* " in *" ${M46_LIVE_TARGET:-} "*) printf '%%1\n'; exit 0 ;; esac; exit 1 ;;
  list-windows) printf 'dev\n'; exit 0 ;;
esac
exit 1
M46SHIM
chmod +x "$M46_SHIM/tmux"
env PATH="$M46_SHIM:$PATH" M46_LIVE_SESSION="$SESSION" M46_LIVE_TARGET="$SESSION:dev" \
  $TEAM outbox list >"$TMP/m46-list.log" 2>&1 || true
assert_has "$TMP/m46-list.log" "target=gone" "12b-pi2 ④ list 把目标已消失的 held 标成 target=gone"
assert_has "$TMP/m46-list.log" "outbox drop gone" "12b-pi2 ④ list 给出清理出口（drop gone）"
assert_eq "12b-pi2 ④ 只有死目标那条被标 gone" "$(grep -c 'target=gone' "$TMP/m46-list.log")" "1"
env PATH="$M46_SHIM:$PATH" M46_LIVE_SESSION="$SESSION" M46_LIVE_TARGET="$SESSION:dev" \
  $TEAM status >"$TMP/m46-status-gone.log" 2>&1 || true
assert_has "$TMP/m46-status-gone.log" "目标已消失" "12b-pi2 ④ status 的队列行报出「目标已消失」"
env PATH="$M46_SHIM:$PATH" M46_LIVE_SESSION="$SESSION" M46_LIVE_TARGET="$SESSION:dev" \
  $TEAM outbox drop gone >"$TMP/m46-dropgone.log" 2>&1 || true
assert_has "$TMP/m46-dropgone.log" "$M46_DEADHELD" "12b-pi2 ④ drop gone 点名丢弃的文件（不静默清场）"
assert_not_file "$M46_S/outbox/held/$M46_DEADHELD" "12b-pi2 ④ 死目标的 held 条目已被清理"
assert_file "$M46_S/outbox/held/$M46_LIVEHELD" "12b-pi2 ④ 活目标的 held 条目没被 gone 误伤"
ob_run $TEAM outbox drop all >/dev/null 2>&1 || true
piw_reset

# ---------------------------------------------------------------- 12b-pi3. M53 降级通道可见（watch-degraded）
# 事故（2026-09-21）：宿主 inotify 配额耗尽 → `fs.watch` 直接 ENOSPC，会话只剩轮询兜底，而 `.reg` 还在 →
# doctor/status 仍报「PM 会话已注册（快路径）」。M53 的可见性契约在这里用**手写夹具**钉住：
#   ① 活的 `.degraded` 记录 → doctor/status/面板都报降级（errno / watches <used>/<max> / 轮询 / 修法），
#      不能说「没有 inbox-watch 注册」，更不能说「退回输入框粘贴」；
#   ② 陈旧记录（pid 已死 / cwd 在外）不是证据；健康通道保持安静（不刷屏）；
#   ③ `.skip` 那条「没有注册」的措辞逐字不变（M46 反向夹具）；
#   ④ doctor 的 inotify 余量行：额度 + 可证明的占用 + 一次性注册探针，四种形状。
section "12b-pi3 · M53 降级通道可见（watch-degraded：doctor/status/面板 + inotify 余量）"

m53_degraded() { # <文件名> <target> <pid> <cwd> <errno> <watches>
  mkdir -p "$PIW"
  printf 'version=1\ntarget=%s\nkey=%s\nreason=watch-unavailable\nerrno=%s\nwatches=%s\npoll_ms=5000\nforced=0\nsince=2026-09-21T00:00:00.000Z\npid=%s\ncwd=%s\nheartbeat=%s\n' \
    "$2" "${1%.degraded}" "$5" "$6" "$3" "$4" "$(date +%s)" > "$PIW/$1"
}

# ① 活的降级记录：doctor / status / 面板三处都必须报，且都不许走「没有注册 / 粘贴慢路径」的措辞
ob_reset; piw_reset
m53_degraded m53-pm.degraded "$SESSION:pm" "$$" "$REPO" ENOSPC 65312/65536
ob_run $TEAM doctor >"$TMP/m53-doctor.log" 2>&1 || true
assert_has "$TMP/m53-doctor.log" "投递通道降级" "12b-pi3 ① doctor 报投递通道降级（不再假绿「已注册」）"
assert_has "$TMP/m53-doctor.log" "errno=ENOSPC" "12b-pi3 ① doctor 点名 errno"
assert_has "$TMP/m53-doctor.log" "watches 65312/65536" "12b-pi3 ① doctor 给出配额占用"
assert_has "$TMP/m53-doctor.log" "轮询" "12b-pi3 ① doctor 说明唤醒退化为轮询"
assert_has "$TMP/m53-doctor.log" "fs.inotify.max_user_watches=524288" "12b-pi3 ① doctor 给修法（抬高额度）"
assert_has "$TMP/m53-doctor.log" "inotify 额度" "12b-pi3 ① doctor 有 inotify 余量一条"
assert_not "$TMP/m53-doctor.log" "没有 inbox-watch 注册" "12b-pi3 ① doctor 不说「没有注册」（注册是活的）"
assert_not "$TMP/m53-doctor.log" "PM 会话已注册" "12b-pi3 ① doctor 不报假绿「已注册」"
ob_run $TEAM status >"$TMP/m53-status.log" 2>&1 || true
assert_has "$TMP/m53-status.log" "投递通道降级" "12b-pi3 ① status 报投递通道降级"
assert_has "$TMP/m53-status.log" "errno=ENOSPC" "12b-pi3 ① status 点名 errno"
assert_has "$TMP/m53-status.log" "watches 65312/65536" "12b-pi3 ① status 给出配额占用"
assert_has "$TMP/m53-status.log" "fs.inotify.max_user_watches=524288" "12b-pi3 ① status 给修法"
assert_not "$TMP/m53-status.log" "退回输入框粘贴" "12b-pi3 ① status 不说退回粘贴路径"
ob_run $TEAM __panel-data --block pm >"$TMP/m53-pm.json" 2>&1 || true
assert_has "$TMP/m53-pm.json" '"delivery_warning": "watcher 注册失败' "12b-pi3 ① 面板 pm 块带降级字段（同一份读者措辞）"
assert_has "$TMP/m53-pm.json" "唤醒退化为轮询" "12b-pi3 ① 面板字段说明「只慢不丢」"
assert_not "$TMP/m53-pm.json" "退回输入框粘贴" "12b-pi3 ① 面板字段不说退回粘贴路径"
if [ -n "$JS_RUNNER" ]; then
  ob_run $TEAM monitor --print >"$TMP/m53-monitor.log" 2>&1 || true
  assert_has "$TMP/m53-monitor.log" "投递降级：watcher 注册失败（errno=ENOSPC" "12b-pi3 ① 面板帧带降级行（带文字记号，不只是颜色）"
  assert_not "$TMP/m53-monitor.log" "退回输入框粘贴" "12b-pi3 ① 面板帧不说退回粘贴路径"
else
  cond_skip "12b-pi3 ① 面板帧" "本机没有 node/bun：面板渲染不了（26 节会单独说明）"
fi

# ②（负对照）陈旧记录不是证据：pid 已死 / cwd 在外 → 一个字都不报
( sleep 0.05 ) & M53_DEAD_PID=$!; wait "$M53_DEAD_PID" 2>/dev/null || true
piw_reset; m53_degraded m53-pm.degraded "$SESSION:pm" "$M53_DEAD_PID" "$REPO" ENOSPC 65312/65536
ob_run $TEAM status >"$TMP/m53-status-stale.log" 2>&1 || true
assert_not "$TMP/m53-status-stale.log" "投递通道降级" "12b-pi3 ②（负对照）死 pid 的降级记录不报"
piw_reset; m53_degraded m53-pm.degraded "$SESSION:pm" "$$" "/tmp" ENOSPC 65312/65536
ob_run $TEAM status >"$TMP/m53-status-foreign.log" 2>&1 || true
assert_not "$TMP/m53-status-foreign.log" "投递通道降级" "12b-pi3 ②（负对照）cwd 在外面的降级记录不报"

# ③ 健康通道保持安静：活注册 + 无记录 → 无降级行、面板字段为空
piw_reset; piw_reg m53-pm "$SESSION:pm" pm
ob_run $TEAM status >"$TMP/m53-status-ok.log" 2>&1 || true
assert_not "$TMP/m53-status-ok.log" "投递通道降级" "12b-pi3 ③（负对照）健康通道不刷降级行"
ob_run $TEAM __panel-data --block pm >"$TMP/m53-pm-ok.json" 2>&1 || true
assert_has "$TMP/m53-pm-ok.json" '"delivery_warning": ""' "12b-pi3 ③（负对照）健康通道面板字段为空"
if [ -n "$JS_RUNNER" ]; then
  ob_run $TEAM monitor --print >"$TMP/m53-monitor-ok.log" 2>&1 || true
  assert_not "$TMP/m53-monitor-ok.log" "投递降级" "12b-pi3 ③（负对照）健康通道面板帧没有警告行"
fi
piw_reset

# ④ M46 的「没有注册」类措辞逐字不变（反向夹具：降级类不许把这类措辞吃掉）
piw_reset; mkdir -p "$PIW"
printf 'version=1\ntarget=ai-interview:pm\nkey=ai-interview_pm-00000000\nsession=ai-interview\nwindow=pm\nexpect=%s\ninbox=pm\nreason=session-mismatch\ndetail=session ai-interview != %s\npid=%s\ncwd=%s\nts=2026-09-20T16:11:45.129Z\nheartbeat=%s\n' \
  "$SESSION" "$SESSION" "$$" "$REPO" "$(date +%s)" > "$PIW/ai-interview_pm-00000000.skip"
ob_run $TEAM status >"$TMP/m53-status-skip.log" 2>&1 || true
assert_has "$TMP/m53-status-skip.log" "会话名不符" "12b-pi3 ④ .skip 类降级照旧报会话名不符"
assert_has "$TMP/m53-status-skip.log" "退回输入框粘贴慢路径" "12b-pi3 ④ .skip 类照旧给粘贴慢路径的出路"
assert_has "$TMP/m53-status-skip.log" "重启进程" "12b-pi3 ④ .skip 类照旧劝重启进程"
piw_reset

# ⑤ doctor 的 inotify 余量：默认形状 / 阈值 / 探针 errno / 无运行时
ob_run $TEAM doctor >"$TMP/m53-ino-def.log" 2>&1; M53_RC_DEF=$?
assert_has "$TMP/m53-ino-def.log" "inotify 额度" "12b-pi3 ⑤ doctor 有 inotify 额度一条"
assert_has "$TMP/m53-ino-def.log" "max_user_watches" "12b-pi3 ⑤ 默认形状点名 max_user_watches"
if grep -qE "inotify 额度 +! .*注册探针 ok" "$TMP/m53-ino-def.log"; then
  bad "12b-pi3 ⑤ 默认形状：探针 ok 时不该是警告行"
elif grep -qE "inotify 额度 +✓ .*注册探针 ok" "$TMP/m53-ino-def.log"; then
  ok "12b-pi3 ⑤ 默认形状：探针 ok → ✓ 且点名 max_user_watches"
else
  cond_skip "12b-pi3 ⑤ 探针 ok" "本机 fs.watch 此刻注册失败（行内可见结论，不是静默跳过）"
fi
ob_run env TEAM_INOTIFY_MIN_FREE=999999999 $TEAM doctor >"$TMP/m53-ino-thr.log" 2>&1; M53_RC_THR=$?
assert_has "$TMP/m53-ino-thr.log" "fs.inotify.max_user_watches=524288" "12b-pi3 ⑤ 阈值警告给修法"
assert_has "$TMP/m53-ino-thr.log" "Syncthing" "12b-pi3 ⑤ 修法点名常见占用者 Syncthing"
assert_has "$TMP/m53-ino-thr.log" "VSCode" "12b-pi3 ⑤ 修法点名常见占用者 VSCode"
assert_eq "12b-pi3 ⑤ 余量警告不让 doctor 变红（rc 与默认一致）" "$M53_RC_THR" "$M53_RC_DEF"
M53_JS_STUB="$TMP/m53-js-stub"
printf '#!/usr/bin/env bash\ncase "$1" in --version) echo v20.0.0; exit 0 ;; esac\necho "errno=ENOSPC"\n' > "$M53_JS_STUB"
chmod +x "$M53_JS_STUB"
ob_run env TEAM_JS_BIN="$M53_JS_STUB" $TEAM doctor >"$TMP/m53-ino-stub.log" 2>&1 || true
assert_has "$TMP/m53-ino-stub.log" "注册探针 errno=ENOSPC" "12b-pi3 ⑤ 探针注册失败本身是可见警告"
assert_not "$TMP/m53-ino-stub.log" "注册探针 ok" "12b-pi3 ⑤ 探针失败绝不报 ok"
ob_run env TEAM_JS_BIN="$TMP/m53-no-such-js" TEAM_REQUIRE_JS=0 $TEAM doctor >"$TMP/m53-ino-none.log" 2>&1 || true
assert_has "$TMP/m53-ino-none.log" "注册探针 unavailable" "12b-pi3 ⑤ 没有运行时 → 探针 unavailable"
assert_not "$TMP/m53-ino-none.log" "注册探针 ok" "12b-pi3 ⑤ 没有运行时不冒称额度健康"

# ---------------------------------------------------------------- 12b-j. 隔离收尾
ob_leaks="$(ob_leak_scan)"
assert_eq "12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹" "$([ -z "$ob_leaks" ] && echo none || printf '%s' "$ob_leaks" | head -3 | tr '\n' '|')" "none"

# 负对照（tasks 7.2）：泄漏扫描本身必须**能红**——否则它是个永远报绿的假守卫。
# 把夹具痕迹（沙盒 session 名）栽进一个假「真项目」目录，同一个扫描函数必须把它揪出来。
# P77：作用域恰有两条**流量记录**排除——审计日志 tmux-calls.log（闸门代写的调用行，内容是调用者
# 自己的 argv）与 state/bg/**（后台作业 stdout）；同名兄弟（.log.1）、子目录同名文件与别处的 bg/ 目录
# 仍是真泄漏。P87（F1）：两条排除都按**确切路径**（bg 不是 `--exclude-dir=bg` 的目录名 glob）。
OB_NEG="$TMP/ob-negroot"; rm -rf "$OB_NEG"
mkdir -p "$OB_NEG/.pi/team/state/bg" "$OB_NEG/.pi/team/state/nested" "$OB_NEG/.pi/team/state/nested/bg" \
         "$OB_NEG/docs/team/inbox/bg"
ob_neg_scan() { SMOKE_INVOKE_ROOT="$OB_NEG" SMOKE_INVOKE_MAIN="" ob_leak_scan; }
ob_neg_has() { ob_neg_scan | grep -qxF "$OB_NEG/$1"; }
# ① 两条流量记录腿：审计日志（夹具的 session 名 + argv 原样在行里）与 state/bg —— 都必须静默
printf '%s · act=pass · sock=/tmp/tmux-1000/private · TMUX=- · TMUX_TMPDIR=- · argv=new-window -t %s:dev · pid=1 ppid=1 cwd=/tmp\n' \
  "2026-09-22T17:00:00+00:00" "$SESSION" > "$OB_NEG/.pi/team/state/tmux-calls.log"
printf 'job stdout: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/bg/gate.log"
assert_eq "12b-j 负对照：审计日志是调用记录，不算账本痕迹（M7.2 红侧的成因）" "$(ob_neg_scan | wc -l | tr -d ' ')" "0"
assert_eq "12b-j 负对照：state/bg/ 的作业日志也不算账本痕迹（M30 口径）" "$(ob_neg_scan | wc -l | tr -d ' ')" "0"
# ② 六条真泄漏腿（逐条栽、逐条点名；后四条钉住「确切路径，不是 basename / 目录名」）
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/docs/team/inbox/leak.md"
assert_eq "12b-j 负对照：inbox 里的痕迹必须被点名" "$(ob_neg_has docs/team/inbox/leak.md && echo yes || echo no)" "yes"
assert_eq "12b-j 负对照：inbox 腿之外没有多余命中" "$(ob_neg_scan | wc -l | tr -d ' ')" "1"
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/phantom.log"
assert_eq "12b-j 负对照：其它 state 文件里的痕迹必须被点名" "$(ob_neg_has .pi/team/state/phantom.log && echo yes || echo no)" "yes"
assert_eq "12b-j 负对照：两条真泄漏腿恰两条命中" "$(ob_neg_scan | wc -l | tr -d ' ')" "2"
# P87（P83-F1）：bg 的排除是**确切路径**，不是目录名 —— inbox 下的 bg/ 仍是账本
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/docs/team/inbox/bg/leak.md"
assert_eq "12b-j 负对照：inbox/bg/ 里的痕迹必须被点名（bg 排除是确切路径，不是目录名）" \
  "$(ob_neg_has docs/team/inbox/bg/leak.md && echo yes || echo no)" "yes"
assert_eq "12b-j 负对照：inbox/bg/ 腿之后恰三条命中" "$(ob_neg_scan | wc -l | tr -d ' ')" "3"
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/nested/bg/leak.md"
assert_eq "12b-j 负对照：state 下嵌套的 bg/ 里的痕迹也必须被点名" \
  "$(ob_neg_has .pi/team/state/nested/bg/leak.md && echo yes || echo no)" "yes"
assert_eq "12b-j 负对照：state/bg/ 自家的作业日志仍静默（bg 的排除是确切路径）" \
  "$(ob_neg_has .pi/team/state/bg/gate.log && echo yes || echo no)" "no"
assert_eq "12b-j 负对照：四条真泄漏腿恰四条命中" "$(ob_neg_scan | wc -l | tr -d ' ')" "4"
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/tmux-calls.log.1"
assert_eq "12b-j 负对照：同名兄弟 tmux-calls.log.1 必须被点名（排除是确切路径，不是 basename）" \
  "$(ob_neg_has .pi/team/state/tmux-calls.log.1 && echo yes || echo no)" "yes"
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/nested/tmux-calls.log"
assert_eq "12b-j 负对照：子目录里的同名文件必须被点名" \
  "$(ob_neg_has .pi/team/state/nested/tmux-calls.log && echo yes || echo no)" "yes"
assert_eq "12b-j 负对照：六条真泄漏腿逐条点名（审计日志与 state/bg/ 仍不在清单里）" "$(ob_neg_scan | wc -l | tr -d ' ')" "6"
rm -rf "$OB_NEG"

if [ "$(ob_hash_real)" = "$REAL_FP_BEFORE" ]; then
  ok "12b-j 隔离：调用方项目 inbox/state 的指纹也没变（整段夹具期间真团队没有活动）"
else
  printf '  \033[2m·\033[0m %s\n' "12b-j 提示：真项目 state 在夹具期间有自己的活动（真团队在跑）——指纹变了，但夹具痕迹扫描为零"
fi
rm -rf "$TMP/ob-altstate"

# ---------------------------------------------------------------- 14. teardown
section "14 · teardown"
$TEAM teardown --agent dev --purge >"$TMP/teardown.log" 2>&1 && ok "teardown 退出码 0" || bad "teardown 失败"
[ -d "$REPO/.worktrees/dev" ] && bad "worktree 应被 --purge 删除" || ok "worktree 已删除"
assert_not "$REPO/.pi/team/state/dev.env" "task=T1.1" "state 已清理"

# ---------------------------------------------------------------- 14c. 快模式自检
# 「快」不能靠静默少跑换来：FAST 模式下必须①一次真进程段落都没执行；②预期段落都确实跳过了
# （跳过会显式打印 SKIP）。真把分层改坏（例如 FAST 仍跑 tmux 段、或跳过被改成静默 continue）
# 时，这一节会红——这是本次改动的守门断言。
# 编号说明：14b 是「文档一致性」自检（纯逻辑，快慢都跑）；本节的 14c 只在快模式跑。
if [ "$FAST_REQ" = "1" ]; then
  section "14c · 快模式自检（跳过必须是显式的、且没有偷偷跑真进程）"
  assert_eq "FAST 没有执行任何真进程段落" "$LIVE_RAN" "0"
  # 注：不能拿 pi-args.log / $FAKE/pi-sleep 文件当信号 ——
  #   ①v1.11.5 起纯逻辑段落也会调 PATH 里的「假 pi」（NEED_PI_STUB，对 --help 给像样回答）；
  #   ②假 pi-sleep 脚本本身就是段外准备好的（写文件无副作用）。
  # 真正只属于真进程段落的信号是：假 PM 的参数文件 / 巡检容量日志 / **有没有 pi-sleep 进程在跑**。
  if command -v pgrep >/dev/null 2>&1; then
    assert_eq "FAST 没有在跑的假 pi 进程（pi-sleep）" "$(pgrep -fc "$FAKE/pi-sleep" 2>/dev/null || true)" "0"
  else
    printf '  (未装 pgrep：跳过「无 pi-sleep 进程」这一条检查)\n'
  fi
  assert_not_file "$TMP/pm-args.log" "FAST 没有拉起假 PM（巡检段被跳过）"
  assert_not_file "$REPO/.pi/team/state/capacity.log" "FAST 没有真巡检写容量日志（watch --once 段被跳过）"
  if [ "$SELECT_MODE" = "1" ]; then
    # 这张表是**全套**门禁的自检：它要求「没跑的段都打印过 SKIP」。选段运行里没被选中的段既没跑也
    # 没跳过（未跑清单在收尾里），这条断言对它不成立 —— 显式跳过并说明，不红（P98/2.4）。
    printf '  \033[2m（选段运行：跳过「预期段落都被跳过」这条全套自检；未跑清单见收尾）\033[0m\n'
  else
  for seg in "6·dispatch 真拉起" "6g·非 Pi agent 端到端" "6h·派单启动证据（真窗口）" "6i·非 Pi PM 端到端" "6j·worker adapter 启动证据（真窗口）" "6k·worker 存活判据（M37）" "11·close 后窗口" "11b·巡检/pulse" "11b2·PM 存活证据链" \
             "11b3·启动中的 PM（M7.2）" "11b4·PM 交接（P36）" "11c·agent 续跑" \
             "11d·边界守卫（真打字）" "11g②·say 离线投递" "11g③·敲门探测" "11j·pulse 迁移夹具" \
             "1c·M11 真沙盒窗口"; do
    # 注：本表只能列**14c 之前**跳过的段落。31b（容器 tmux 自检）在本节之后，它由
    # 「FAST 没有执行任何真进程段落」（LIVE_RAN==0）间接盯住，不列在这里。
    if skipped "$seg"; then ok "已显式跳过并打印 SKIP：$seg"
    else bad "段落 [$seg] 在 FAST 模式下既没跳过也没标记——快慢分层漏了"; fi
  done
  fi
fi

# ---------------------------------------------------------------- 17. 迁移指南（M7.1）
# 一个用旧版本（或旧名）建起来的项目，必须能在一个地方查到「要改什么」。指南本身是文档，但两件可机器验证
# 的事在这里钉死：
#   ① doctor 只在真的需要迁移时打**一行**指引（旧标记 / 本会话版本比磁盘旧），而且不因此变红；
#   ② init 必须把旧标记就地改写（幂等、单块），改完之后指引消失。
# 纯逻辑（不建 tmux、不起 pi 进程），所以快慢模式都跑。
# 夹具复用 15b 造的假 settings/openspec/spec 目录，否则 doctor 会因为缺必需依赖而失败，
# 那样「指引消失」就可能是被别的失败淹没了——所以下面还断言干净夹具 doctor rc=0。
section "17 · 迁移指南与 doctor 指引（M7.1）"

MDOC="$SKILL_DIR/references/migration.md"
M71="$TMP/m71-repo"; rm -rf "$M71"; mkdir -p "$M71"
( cd "$M71" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && git commit -q --allow-empty -m init )
( cd "$M71" && $TEAM init --session m71-fixture --agents "dev verify" --vcs local --gates "true" --docs docs/team ) >"$TMP/m71-init.log" 2>&1 \
  || bad "夹具 init 失败（见 $TMP/m71-init.log）"
{
  printf 'TEAM_PI_SETTINGS_FILE="%s"\n' "$M51_AGENT/settings.json"
  printf 'TEAM_OPENSPEC_BIN="%s"\n' "$FAKE/openspec"
  printf 'TEAM_SPEC_DIR="%s"\n' "$M51_SPEC"
} >> "$M71/.pi/team/config.sh"
assert_eq "夹具 init 后是 teamsmith 标记" "$(grep -cF '<!-- teamsmith:begin -->' "$M71/AGENTS.md")" "1"
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-clean.log" 2>&1; M71RC=$?
assert_eq "干净夹具 doctor 退出码 0（指引的消失不是因为别的东西挂了）" "$M71RC" "0"
assert_not "$TMP/m71-doctor-clean.log" "references/migration.md" "无需迁移时不打指引"

# ① 旧名标记 → doctor 打一行指引；rc 仍为 0（提示不等于失败）
sed -i 's|<!-- teamsmith:begin -->|<!-- pi-team:begin -->|; s|<!-- teamsmith:end -->|<!-- pi-team:end -->|' "$M71/AGENTS.md"
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-legacy.log" 2>&1; M71RC=$?
assert_eq "旧标记时 doctor 仍然退出码 0（只是提示）" "$M71RC" "0"
assert_has "$TMP/m71-doctor-legacy.log" "references/migration.md" "旧标记 → doctor 指向迁移指南"
assert_has "$TMP/m71-doctor-legacy.log" "旧名标记" "指引说明的是标记这一条判据（不是蹭版本那条）"
assert_eq "指引只打一行" "$(grep -c 'references/migration.md' "$TMP/m71-doctor-legacy.log")" "1"

# ② init 就地改写旧标记（幂等、单块），指引随之消失
( cd "$M71" && $TEAM init --session m71-fixture --agents "dev verify" --vcs local --gates "true" --docs docs/team ) >/dev/null 2>&1
assert_eq "init 改掉了旧标记" "$(grep -cF '<!-- pi-team:begin -->' "$M71/AGENTS.md")" "0"
assert_eq "改写后协议段只有一块" "$(grep -cF '<!-- teamsmith:begin -->' "$M71/AGENTS.md")" "1"
( cd "$M71" && $TEAM init --session m71-fixture --agents "dev verify" --vcs local --gates "true" --docs docs/team ) >/dev/null 2>&1
assert_eq "再 init 一次仍然只有一块（幂等）" "$(grep -cF '<!-- teamsmith:begin -->' "$M71/AGENTS.md")" "1"
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-after.log" 2>&1
assert_not "$TMP/m71-doctor-after.log" "references/migration.md" "标记迁移后指引消失"

# ③ 第二条判据：本会话加载的版本比磁盘旧 → 指引出现；mark-loaded 之后消失
mkdir -p "$M71/.pi/team/state"
printf 'VERSION=0.0.1\nHASH=stale\n' > "$M71/.pi/team/state/pm-loaded.env"
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-stale.log" 2>&1
assert_has "$TMP/m71-doctor-stale.log" "references/migration.md" "旧会话版本 → doctor 指向迁移指南"
assert_has "$TMP/m71-doctor-stale.log" "本会话加载 0.0.1" "指引说明的是版本这一条判据"
( cd "$M71" && $TEAM mark-loaded ) >/dev/null 2>&1
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-current.log" 2>&1
assert_not "$TMP/m71-doctor-current.log" "references/migration.md" "版本一致后指引消失"

# ④ 两条判据同时成立也只打一行（不重复刷屏）
sed -i 's|<!-- teamsmith:begin -->|<!-- pi-team:begin -->|; s|<!-- teamsmith:end -->|<!-- pi-team:end -->|' "$M71/AGENTS.md"
printf 'VERSION=0.0.1\nHASH=stale\n' > "$M71/.pi/team/state/pm-loaded.env"
( cd "$M71" && $TEAM doctor ) >"$TMP/m71-doctor-both.log" 2>&1
assert_eq "两条判据同时成立仍然只打一行" "$(grep -c 'references/migration.md' "$TMP/m71-doctor-both.log")" "1"

# ⑤ 指南本身：八节都在、关键命令/开关在、篇幅不是占位符
for m71sec in "What is stable" "The rename" "Removed commands" "New required dependencies" \
              "Behaviour changes" "Upgrade recipe" "Rolling back" "not supported"; do
  assert_has "$MDOC" "$m71sec" "migration.md 有这一节：$m71sec"
done
assert_has "$MDOC" "pi install npm:@cortexkit/pi-magic-context" "指南给出 magic-context 的安装命令"
assert_has "$MDOC" "openspec init --tools none" "指南给出 spec 根目录的初始化命令"
assert_has "$MDOC" "TEAM_REQUIRE_OPENSPEC=0" "指南给出必需依赖的降级开关"
assert_has "$MDOC" "TEAM_SESSION" "指南提醒 session 名必须与巡检窗口（pulse）的一致"
assert_has "$MDOC" "--fresh" "指南提到长会话换小窗口模型要用 --fresh"
[ "$(wc -l < "$MDOC")" -ge 120 ] && ok "指南篇幅 ≥ 120 行（不是占位符）" \
  || bad "指南只有 $(wc -l < "$MDOC") 行：太短"
# 读者入口：SKILL.md 阅读表 + bootstrap/config 各一行（不新增子命令）
assert_has "$SKILL_DIR/SKILL.md" "references/migration.md" "SKILL.md 阅读表指向迁移指南"
assert_has "$SKILL_INIT_DIR/references/bootstrap.md" "teamsmith/references/migration.md" \
  "init skill 的 bootstrap.md 指向迁移指南（跨 skill 相对路径）"
assert_has "$SKILL_DIR/references/migration.md" "teamsmith-init/references/bootstrap.md" \
  "migration.md 指回 init skill 的 bootstrap.md（跨 skill 相对路径）"
assert_has "$SKILL_DIR/references/config.md" "migration.md" "config.md 指向迁移指南"
# 英文文档不变量（M4.1 的口径）：这里只覆盖本任务交付/改过的三份 references 文档。
# 为什么不是整个 references/**：protocol.md 里还有 2 行**引用中文 CLI 输出串**（review 的翻转证据关键词），
#   那是 M6.2 引入的、属于 PM 的文件（不在本任务边界内）——已作为 finding 交回，不在测试里给它开口子。
#   复现：grep -rnP '[\x{4e00}-\x{9fff}]' skills/teamsmith/references
if printf '中\n' | grep -qP '[\x{4e00}-\x{9fff}]' 2>/dev/null; then
  M71_CJK="$(grep -lP '[\x{4e00}-\x{9fff}]' "$MDOC" "$SKILL_DIR/references/config.md" \
    "$SKILL_INIT_DIR/references/bootstrap.md" 2>/dev/null || true)"
  [ -z "$M71_CJK" ] && ok "本任务交付的 references 文档全英文（无 CJK）" \
    || bad "references 里有中文：$(printf '%s' "$M71_CJK" | head -2 | tr '\n' ' ')"
else
  printf '  \033[2m·\033[0m %s\n' "（grep -P 不可用：跳过「references 无中文」这条检查）"
fi

# ---------------------------------------------------------------- 18. 英文正文不变量 + 安装器入口（M7.3）
# 两个「声明过但没人守」的保证，M7.3 起由本段守门：
#   ① 英文不变量：`references/**` 与 `SCOPE.md` 的**正文**必须全英文；**行内代码**（`…`）与
#      **围栏代码块**（``` 或 ~~~）里的中文是**故意**的 —— 那是在引用真实的中文 CLI 输出串
#      （D8：CLI 面保持中文）。这条规则以前只写在任务书里，一个版本就烂了（M6.2 加了两行中文引用
#      没人拦），所以这里落成检查器 + 双向翻转自测（正文必须报红 / 只在代码里必须不报红）。
#   ② install.sh 只装规范目录：`skills/pi-team` 是指向 teamsmith 的**兼容软链**，不是第二个 skill
#      （M7.1 报告 Finding 2：装进去会在目标目录造出两个同名 skill 的发现入口）。
# 纯逻辑（临时目录 + 两次安装，不碰 tmux / 真 pi 进程），快慢模式都跑。
section "18 · 英文正文不变量与安装器唯一入口（M7.3）"

SRC_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
assert_dir "$SRC_ROOT/skills/teamsmith/references" "扫描根存在（references/**）"
assert_file "$SRC_ROOT/SCOPE.md" "扫描根存在（SCOPE.md）"
# 测试卫生（实测的坑）：本段只允许写临时目录，**不许往真树里写**。夹具里 `ln -s … <dest>` 的 dest
# 若已存在且是「指向目录的软链」，ln 会**钻进去**在真仓库里建文件（pre-fix 安装器 + 卸载夹具就踩过：
# 目标里的 pi-team 指向真 skills/teamsmith，于是 ln 在真树里建出 skills/teamsmith/teamsmith）。
# 所以：夹具先 rm -rf 再建链，并且段末对比真树清单 —— 污染了就报红，别让它悄悄留在仓库里。
M73_TREE_BEFORE="$(cd "$SRC_ROOT" && find skills -mindepth 1 -maxdepth 3 | sort)"

if ! command -v perl >/dev/null 2>&1; then
  # 这条规则不能静默跳过（跳过就等于没有守门：M7.1 的教训）——缺依赖就如实报红。
  bad "没有 perl：英文正文不变量无法检查（装上 perl 才能跑这条门禁）"
else
  # 口径 = 实现：剥掉围栏代码块（``` / ~~~ 成对）与**同行**行内 span（`…`；本项目不用多行 span），
  # 再匹配 CJK 表意文字（U+3400–4DBF 扩展 A / U+4E00–9FFF / U+F900–FAFF 兼容表意），
  # 命中打 `相对路径:行号: 原文`（路径相对扫描根，读者能直接 grep 到）。
  # 全角标点（U+FF00–FFEF）**不在**口径内：config.md / workflows.md 用 `｜`（U+FF5C）当表格与样例输出
  # 里的竖线（避开 Markdown 表格分隔符），那是刻意的排版，不等于「文档变回了中文」。
  doc_cjk_hits() { # <扫描根> [raw]：默认剥代码；raw=1 原样扫（用来证明豁免的正是代码 span）
    local root="$1" mode="${2:-}" files
    [ -d "$root/skills/teamsmith/references" ] || return 0
    # P16：init skill 的 references 也在口径内（bootstrap.md 搬过去了）。
    files="$( cd "$root" && find skills/teamsmith/references skills/teamsmith-init/references -type f 2>/dev/null | sort )"
    [ -f "$root/SCOPE.md" ] && files="$files SCOPE.md"
    [ -n "$files" ] || return 0
    ( cd "$root" || return 0
      if [ "$mode" = "raw" ]; then DOC_CJK_RAW=1; else unset DOC_CJK_RAW; fi
      export DOC_CJK_RAW
      # shellcheck disable=SC2086
      perl -CSD -e '
        my $raw = $ENV{DOC_CJK_RAW} ? 1 : 0;
        my $fence = 0;
        while (my $line = <>) {
          if ($raw) {
            # 原样：连围栏块/行内 span 里的中文一起算命中
          } elsif ($fence) {
            $fence = 0 if $line =~ /^[ \t]*(?:```|~~~)/;
            next;
          } elsif ($line =~ /^[ \t]*(?:```|~~~)/) {
            $fence = 1;
            next;
          } else {
            $line =~ s/`[^`\n]*`//g;   # 行内代码：里面是引用的中文 CLI 输出串，故意豁免
          }
          next unless $line =~ /[\x{3400}-\x{4dbf}\x{4e00}-\x{9fff}\x{f900}-\x{faff}]/;
          chomp $line;
          print "$ARGV:$.: $line\n";
        } continue { close ARGV if eof }
      ' $files
    )
  }

  # 真树：正文必须全英文。原始扫描同时留作证据（命中应当**只**在代码 span 里；写进报告用）。
  M73_RAW="$(doc_cjk_hits "$SRC_ROOT" raw || true)"
  M73_PROSE="$(doc_cjk_hits "$SRC_ROOT" || true)"
  if [ -n "$M73_PROSE" ]; then
    bad "英文正文不变量被破坏（references/** 或 SCOPE.md 的正文里有 CJK）："
    printf '%s\n' "$M73_PROSE" | head -5 | sed 's/^/     /'
  else
    ok "references/** 与 SCOPE.md 的正文全英文（CJK 只出现在代码 span / 围栏块里）"
  fi
  [ -n "$M73_RAW" ] && ok "正对照：真树原始扫到 $(printf '%s\n' "$M73_RAW" | grep -c .) 行 CJK，全部在代码里被豁免" \
    || ok "正对照：真树原始扫描没有 CJK（引用已被改写）——由翻转自测保证检查器不瞎"

  # 翻转自测（关键）：检查器必须**两个方向**都对。往 references 的沙箱副本里注入。
  #   红：正文里的中文必须被报出来（含「同行还有代码 span」的那类，防「有反引号就整行豁免」）；
  #   净：只在行内代码 / 只在围栏块里的中文不得误报（否则 protocol.md 的中文引用只能被删掉）。
  CJK_SB="$TMP/m73-cjk"; rm -rf "$CJK_SB"; mkdir -p "$CJK_SB/skills/teamsmith" "$CJK_SB/skills/teamsmith-init"
  cp -r "$SKILL_DIR/references" "$CJK_SB/skills/teamsmith/references"
  cp -r "$SKILL_INIT_DIR/references" "$CJK_SB/skills/teamsmith-init/references"
  cp "$SRC_ROOT/SCOPE.md" "$CJK_SB/SCOPE.md" 2>/dev/null || true
  : > "$TMP/m73-cjk-red.log"
  cjk_flip() { # <red|clean> <说明> <相对文件> <追加内容>
    local want="$1" what="$2" file="$3" text="$4" got
    rm -rf "$CJK_SB-x"; cp -r "$CJK_SB" "$CJK_SB-x"
    printf '%s\n' "$text" >> "$CJK_SB-x/$file"
    got="$(doc_cjk_hits "$CJK_SB-x" || true)"
    if [ "$want" = "red" ]; then
      printf '%s\n' "$got" >> "$TMP/m73-cjk-red.log"
      [ -n "$got" ] && ok "翻转自测（红）：$what 会被抓到" \
        || bad "翻转自测（红）：$what 竟然漏报（检查器太弱）"
    else
      [ -z "$got" ] && ok "翻转自测（净）：$what 不误报（代码豁免有效）" \
        || bad "翻转自测（净）：$what 被误报：$(printf '%s' "$got" | head -1)"
    fi
  }
  cjk_flip "red"   "正文里的中文" "skills/teamsmith/references/protocol.md" \
    'The record says 不满足 and warns.'
  cjk_flip "red"   "同行既有代码 span 又有正文中文" "skills/teamsmith/references/protocol.md" \
    'See `team review` and 不满足 here.'
  cjk_flip "clean" "只有行内代码里有中文" "skills/teamsmith/references/protocol.md" \
    'The record says `不满足` and warns.'
  cjk_flip "clean" "只有围栏代码块里有中文" "skills/teamsmith/references/protocol.md" \
    $'```\n$ team review 1 --strong\n不满足（不阻塞合并，但里程碑收口前应补齐）\n```'
  cjk_flip "red"   "SCOPE.md 正文里的中文" "SCOPE.md" 'Boundary: 不要越界。'
  cjk_flip "red"   "init skill 正文里的中文（新家也在口径内）" "skills/teamsmith-init/references/bootstrap.md" \
    'The record says 不满足 and warns.'
  rm -rf "$CJK_SB-x"
  # 报告形态：必须 `相对路径:行号: 原文`（读者能照着 grep / 定位）
  assert_match "$TMP/m73-cjk-red.log" \
    '^skills/teamsmith/references/protocol\.md:[0-9]+: The record says 不满足 and warns\.$' \
    "命中格式是 file:line: <原文>（含真实行号）"
  assert_match "$TMP/m73-cjk-red.log" '^SCOPE\.md:[0-9]+: Boundary: 不要越界。$' \
    "SCOPE.md 命中也带 file:line 前缀"
  # 正对照：干净副本（注入前的沙箱）不得报红 —— 排除「检查器见了沙箱就报」
  [ -z "$(doc_cjk_hits "$CJK_SB" || true)" ] && ok "翻转自测：干净副本不误报（正对照）" \
    || bad "干净副本被误报"
fi

# ── ② 安装器：软链别名不得变成第二个 skill 发现入口 ──────────────────────────
INSTALL_SH="$SRC_ROOT/install.sh"
assert_file "$INSTALL_SH" "仓库根有 install.sh"
inst_entries() { # <目标目录>：会被 pi 发现成 skill 的条目（跟随软链），每行是 SKILL.md 里的 name
  local t="$1" d
  for d in "$t"/*; do
    [ -e "$d" ] || continue
    if [ -f "$d/SKILL.md" ]; then
      grep -m1 '^name:' "$d/SKILL.md" | sed 's/^name:[[:space:]]*//'
    else
      basename "$d"
    fi
  done | sort
}
real_skill_count() { # 仓库里**真实**（非软链）的 skill 目录数 —— 安装器应该恰好装出这么多个入口
  local d n=0
  for d in "$SRC_ROOT"/skills/*/; do
    [ -f "$d/SKILL.md" ] && [ ! -L "${d%/}" ] && n=$((n + 1))
  done
  printf '%s' "$n"
}
assert_eq "仓库里真实（非软链）的 skill 目录数 = 2（teamsmith + teamsmith-init）" "$(real_skill_count)" "2"
# M22：仓库不再自带软链别名（`skills/pi-team` 已 git rm）—— 安装器「跳过软链」的守卫改用
# 段末的 M22 夹具继续守，这里只钉住「仓库里没有旧入口」这个事实。
if [ -e "$SRC_ROOT/skills/pi-team" ] || [ -L "$SRC_ROOT/skills/pi-team" ]; then
  bad "仓库里又出现了 skills/pi-team（M22 已移除：老项目改路径，不靠别名）"
else
  ok "仓库里没有 skills/pi-team 这个入口（M22 已移除）"
fi
for m73mode in link copy; do
  m73t="$TMP/m73-install-$m73mode"; rm -rf "$m73t"
  m73flag=""; [ "$m73mode" = "copy" ] && m73flag="--copy"
  if bash "$INSTALL_SH" $m73flag --target "$m73t" >"$TMP/m73-install-$m73mode.log" 2>&1; then
    ok "install.sh $m73mode 模式跑通（临时目标 $m73t）"
  else
    bad "install.sh $m73mode 模式失败"; sed 's/^/     /' "$TMP/m73-install-$m73mode.log"
  fi
  assert_eq "$m73mode 模式：目标条目数 == 仓库里真实 skill 目录数（软链别名不算一个 skill）" \
    "$(inst_entries "$m73t" | wc -l | tr -d ' ')" "$(real_skill_count)"
  assert_eq "$m73mode 模式：teamsmith 只被发现一次" \
    "$(inst_entries "$m73t" | grep -c '^teamsmith$')" "1"
  assert_eq "$m73mode 模式：没有重名的发现入口（同一 skill 不得出现两次）" \
    "$(inst_entries "$m73t" | sort | uniq -d | wc -l | tr -d ' ')" "0"
  if [ -e "$m73t/pi-team" ] || [ -L "$m73t/pi-team" ]; then
    bad "$m73mode 模式：目标里还有 pi-team —— 兼容软链被当成第二个 skill 装进来了"
  else
    ok "$m73mode 模式：没有 pi-team 第二入口"
  fi
  if [ "$m73mode" = "copy" ]; then
    if [ -x "$m73t/teamsmith/scripts/team" ] && [ -x "$m73t/teamsmith/tests/smoke.sh" ]; then
      ok "copy 模式：可执行位保留（scripts/team、tests/smoke.sh）"
    else
      bad "copy 模式：可执行位丢了"
    fi
  fi
done
# M22：仓库自带的兼容软链删掉以后，install.sh 的「跳过 skills/ 下的软链」守卫不再有仓库自带
# 样本 —— 用一个只含「两个真 skill + 一个软链别名」的夹具源树继续守它（否则这条守卫就变成
# 没人跑的死代码，而下一次有人往 skills/ 里加软链时不会有人拦）。
M22_SRC="$TMP/m22-install-src"; M22_DEST="$TMP/m22-install-dest"
rm -rf "$M22_SRC" "$M22_DEST"; mkdir -p "$M22_SRC/skills"
cp -r "$SRC_ROOT/skills/teamsmith" "$M22_SRC/skills/teamsmith"
cp -r "$SRC_ROOT/skills/teamsmith-init" "$M22_SRC/skills/teamsmith-init"
ln -s teamsmith "$M22_SRC/skills/alias-to-teamsmith"
cp "$SRC_ROOT/install.sh" "$M22_SRC/install.sh"
if bash "$M22_SRC/install.sh" --target "$M22_DEST" >"$TMP/m22-install.log" 2>&1; then
  ok "M22 夹具：源树里有软链别名时 install.sh 退 0"
else
  bad "M22 夹具：install.sh 失败"; sed 's/^/     /' "$TMP/m22-install.log"
fi
assert_has "$TMP/m22-install.log" "跳过 alias-to-teamsmith" \
  "install.sh 说明了为什么跳过 skills/ 下的软链（M22 后由这个夹具守着）"
assert_has "$TMP/m22-install.log" "兼容软链" "install.sh 的跳过理由里点名「兼容软链」"
if [ -e "$M22_DEST/alias-to-teamsmith" ] || [ -L "$M22_DEST/alias-to-teamsmith" ]; then
  bad "M22 夹具：软链别名被当成第二个入口装进来了"
else
  ok "M22 夹具：目标里没有软链别名入口"
fi
assert_eq "M22 夹具：两个真 skill 各装一个入口" "$(ls -1 "$M22_DEST" | wc -l | tr -d ' ')" "2"
rm -rf "$M22_SRC" "$M22_DEST"
# 卸载要能顺手清掉旧版本装出来的 pi-team 入口（否则旧副本永远留在磁盘上，发现入口又变两个）。
# 夹具手工搭（不要拿安装器刚产出的目标当输入 —— 那条路径在**坏实现**下会把软链变成真树里的文件）。
M73_UNINST="$TMP/m73-install-legacy"; rm -rf "$M73_UNINST"; mkdir -p "$M73_UNINST"
ln -s "$SRC_ROOT/skills/teamsmith" "$M73_UNINST/teamsmith"
ln -s teamsmith "$M73_UNINST/pi-team"
if bash "$INSTALL_SH" --uninstall --target "$M73_UNINST" >"$TMP/m73-uninstall.log" 2>&1; then
  ok "install.sh --uninstall 跑通"
else
  bad "install.sh --uninstall 失败"; sed 's/^/     /' "$TMP/m73-uninstall.log"
fi
if [ -e "$M73_UNINST/pi-team" ] || [ -L "$M73_UNINST/pi-team" ]; then
  bad "卸载后 pi-team 入口还在（旧版装出来的副本没人清）"
else
  ok "卸载顺手清掉旧版的 pi-team 入口"
fi
if [ -e "$M73_UNINST/teamsmith" ] || [ -L "$M73_UNINST/teamsmith" ]; then
  bad "卸载后 teamsmith 还在"
else
  ok "卸载后目标目录干净"
fi

# 段末：真树的文件清单必须和入段时一致（上面那些夹具一个字节都不许写进仓库）
M73_TREE_AFTER="$(cd "$SRC_ROOT" && find skills -mindepth 1 -maxdepth 3 | sort)"
if [ "$M73_TREE_BEFORE" = "$M73_TREE_AFTER" ]; then
  ok "本段的翻转夹具没有污染真树（skills/ 清单前后一致）"
else
  bad "本段往真树里写了东西（skills/ 清单变了）："
  diff <(printf '%s\n' "$M73_TREE_BEFORE") <(printf '%s\n' "$M73_TREE_AFTER") | sed 's/^/     /'
fi

# ---------------------------------------------------------------- 19. OpenSpec 五阶段流水线（M9.1）
# 契约：五阶段必须「可照着做」—— 每个阶段一行（阶段命令 + 所有者 + 门禁），两条硬规则
#   （独立复验；归档要用户确认），propose→apply 之间的**记录式**提案审查（十条清单），
#   以及「不重复抄 OpenSpec 手册」（指南只留指针，不得再长出 requirement/scenario 语法样板）。
# 纯逻辑（只读文件），快慢模式都跑。
# 判据在 os_pipeline_hits 里，违规行格式固定为 `<相对文件>: <REASON>[ <detail>]`；
#   末尾的翻转夹具按 REASON 断言 —— **不是**「能报红就算过」，而是「删掉哪一条，就点名哪一条」。
# ---------------------------------------------------------------- 18b. 拆分不变量（P16 / capability init-skill）
# 两个 skill 共存必须守住的不变量：description 路由干净、init 侧无代码、版本/指纹单一来源、存量项目零改动。
# 全部纯逻辑（读文件 + 一次 dispatch --print + 一次指纹计算），快慢都跑；每条自带「注入变体必须报红」的
# 翻转自测 —— 拆分最容易的失败方式是扫描口径悄悄漏掉一个新目录（绿得毫无意义）。
section "18b · 拆分不变量（P16）：description 路由 / init 无代码 / 指纹范围 / 零改动"

p16_desc_of() { sed -n 's/^description:[[:space:]]*//p' "$1" | head -1; }
P16_INIT_PHRASES=('organize multiple agents into a team' 'set up an agent collaboration protocol' 'bootstrap this skill into a new project')
P16_DAY_PHRASES=('dispatch tasks to worker agents' 'run the patrol' "review an agent's work independently")
p16_desc_pollution() { # <日常 SKILL.md> <init SKILL.md>：命中描述（空 = 干净）
  local d i out="" ph
  d="$(p16_desc_of "$1")"; i="$(p16_desc_of "$2")"
  for ph in "${P16_INIT_PHRASES[@]}"; do case "$d" in *"$ph"*) out="$out daily-[$ph]";; esac; done
  for ph in "${P16_DAY_PHRASES[@]}"; do case "$i" in *"$ph"*) out="$out init-[$ph]";; esac; done
  printf '%s' "$out"
}
P16_DAILY_DESC="$(p16_desc_of "$SKILL_DIR/SKILL.md")"
P16_INIT_DESC="$(p16_desc_of "$SKILL_INIT_DIR/SKILL.md")"
P16_POLL="$(p16_desc_pollution "$SKILL_DIR/SKILL.md" "$SKILL_INIT_DIR/SKILL.md")"
[ -z "$P16_POLL" ] && ok "两条 description 路由干净（init 短语只在 init 侧，日常短语只在日常侧）" \
  || bad "description 交叉污染：$P16_POLL"
case "$P16_DAILY_DESC" in *teamsmith-init*) ok "日常 description 点名 teamsmith-init（新项目指路）";;
  *) bad "日常 description 没有指路 teamsmith-init";; esac
[ "${#P16_DAILY_DESC}" -le 1024 ] && [ "${#P16_INIT_DESC}" -le 1024 ] \
  && ok "两条 description 都在 1024 上限内（日常 ${#P16_DAILY_DESC} / init ${#P16_INIT_DESC} 字符）" \
  || bad "description 超长（日常 ${#P16_DAILY_DESC} / init ${#P16_INIT_DESC}）"
# 翻转自测：注入变体必须被抓到；干净副本不得误报（正对照）
P16_SB_DESC="$TMP/p16-desc"; rm -rf "$P16_SB_DESC"; mkdir -p "$P16_SB_DESC"
cp "$SKILL_DIR/SKILL.md" "$P16_SB_DESC/daily.md"; cp "$SKILL_INIT_DIR/SKILL.md" "$P16_SB_DESC/init.md"
[ -z "$(p16_desc_pollution "$P16_SB_DESC/daily.md" "$P16_SB_DESC/init.md")" ] \
  && ok "翻转自测：干净副本不误报（正对照）" || bad "翻转自测：干净副本被误报"
sed -i 's/^description:.*/& organize multiple agents into a team./' "$P16_SB_DESC/daily.md"
[ -n "$(p16_desc_pollution "$P16_SB_DESC/daily.md" "$P16_SB_DESC/init.md")" ] \
  && ok "翻转自测：把 init 短语塞回日常 description 会被抓到" || bad "翻转自测：init 短语回流竟然漏报"
sed -i 's/^description:.*/& dispatch tasks to worker agents./' "$P16_SB_DESC/init.md"
[ -n "$(p16_desc_pollution "$P16_SB_DESC/daily.md" "$P16_SB_DESC/init.md")" ] \
  && ok "翻转自测：init description 染上日常短语会被抓到" || bad "翻转自测：日常短语入侵 init 竟然漏报"
rm -rf "$P16_SB_DESC"

# R4：init skill 只带指引（没有代码目录），工具面也从不引用它
P16_SUBDIRS="$(find "$SKILL_INIT_DIR" -maxdepth 1 -type d | sed 's|.*/||' | grep -E '^(scripts|extension|tests)$' || true)"
[ -z "$P16_SUBDIRS" ] && ok "init skill 无 scripts/extension/tests（只有 SKILL.md + references/ + templates/）" \
  || bad "init skill 里出现了代码目录：$(printf '%s' "$P16_SUBDIRS" | tr '\n' ' ')"
# P16 的原文：工具面从不引用 init skill（模板搬走后不再有死路径）。P40 给这条诺言开了一个**规格授权的例外**：
# 安装步（scripts/lib/cmd-init.sh）要按名把兄弟 skill 装进项目的 .pi/skills/，所以只有它允许出现
# `teamsmith-init`；其余 scripts/ extension/ templates/ 一律照旧。自查探针（p16-probe.sh）不在此列。
P16_TOOL_HITS="$(grep -rn 'teamsmith-init' "$SKILL_DIR/scripts" "$SKILL_DIR/extension" "$SKILL_DIR/templates" 2>/dev/null \
  | grep -v "/scripts/lib/cmd-init.sh:" || true)"
[ -z "$P16_TOOL_HITS" ] && ok "工具面只在 P40 安装步（cmd-init.sh）引用 teamsmith-init，其余不再引用" \
  || bad "工具面引用了 init skill：$(printf '%s' "$P16_TOOL_HITS" | head -1)"
P16_BP_HITS="$(grep -rn 'bootstrap-prompt' "$SKILL_DIR/scripts" 2>/dev/null || true)"
[ -z "$P16_BP_HITS" ] && ok "scripts/ 不再引用 bootstrap-prompt（模板搬走后没有死路径）" \
  || bad "scripts/ 还引用 bootstrap-prompt：$(printf '%s' "$P16_BP_HITS" | head -1)"
P16_SB_TOOL="$TMP/p16-tool"; rm -rf "$P16_SB_TOOL"; mkdir -p "$P16_SB_TOOL/scripts" "$P16_SB_TOOL/templates"
printf '# probe: teamsmith-init\n' > "$P16_SB_TOOL/scripts/p16-probe.sh"
printf '# probe: bootstrap-prompt.md.tmpl\n' > "$P16_SB_TOOL/scripts/p16-probe2.sh"
[ -n "$(grep -rn 'teamsmith-init' "$P16_SB_TOOL/scripts" "$P16_SB_TOOL/extension" "$P16_SB_TOOL/templates" 2>/dev/null || true)" ] \
  && ok "翻转自测：注入的工具引用会被抓到" || bad "翻转自测：工具面的注入竟然漏报"
[ -n "$(grep -rn 'bootstrap-prompt' "$P16_SB_TOOL/scripts" 2>/dev/null || true)" ] \
  && ok "翻转自测：注入的 bootstrap-prompt 引用会被抓到" || bad "翻转自测：bootstrap-prompt 的注入竟然漏报"
rm -rf "$P16_SB_TOOL"

# R5：指纹范围不变 —— team_skill_hash 只吃日常 SKILL.md + extension；init 文本变化不得改变指纹，
# 日常文本变化必须改变指纹（后半句是证明这条断言非空跑的正对照）。
P16_FIX="$TMP/p16-hash"; rm -rf "$P16_FIX"
mkdir -p "$P16_FIX/skills/teamsmith/extension" "$P16_FIX/skills/teamsmith-init"
cp "$SKILL_DIR/SKILL.md" "$P16_FIX/skills/teamsmith/"
cp "$SKILL_DIR/extension/team-notify.ts" "$P16_FIX/skills/teamsmith/extension/"
cp "$SKILL_INIT_DIR/SKILL.md" "$P16_FIX/skills/teamsmith-init/"
p16_hash() { TEAM_SKILL_DIR="$P16_FIX/skills/teamsmith" bash -c \
  '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; . "'"$SKILL_DIR"'/scripts/lib/cmd-update.sh"; team_skill_hash'; }
P16_H0="$(p16_hash)"
printf '\n<!-- P16 flip: init skill text changes -->\n' >> "$P16_FIX/skills/teamsmith-init/SKILL.md"
P16_H1="$(p16_hash)"
assert_eq "改 init SKILL.md：会话指纹不变（init 文本不吵醒在跑的 PM）" "$P16_H1" "$P16_H0"
printf '\n<!-- P16 flip: daily skill text changes -->\n' >> "$P16_FIX/skills/teamsmith/SKILL.md"
P16_H2="$(p16_hash)"
if [ -n "$P16_H0" ] && [ "$P16_H2" != "$P16_H0" ]; then
  ok "改日常 SKILL.md：指纹确实变（证明上面那条不是空跑）"
else
  bad "指纹口径坏了：改日常 SKILL.md 指纹没变（基线 [$P16_H0] / 现在 [$P16_H2]）"
fi
rm -rf "$P16_FIX"

# R6：存量项目零改动 —— 三个启动/协议模板不带 init skill，dispatch --print 渲染出的命令照旧
# 只挂日常 skill 目录（--skill），不含 teamsmith-init。
P16_TPL_HITS="$(grep -rn 'teamsmith-init' "$SKILL_DIR/templates/config.sh.tmpl" \
  "$SKILL_DIR/templates/AGENTS.section.md.tmpl" "$SKILL_DIR/templates/pm-prompt.md.tmpl" 2>/dev/null || true)"
[ -z "$P16_TPL_HITS" ] && ok "config/协议段/PM 三个模板不含 teamsmith-init（存量项目没有新键）" \
  || bad "模板里出现 teamsmith-init：$(printf '%s' "$P16_TPL_HITS" | head -1)"
# 自建夹具（不借 7 节的 $REPO：到这一段它的状态在 FAST 模式下不保证）：init -> task -> worktree ->
# 规范分支（用实现自己的函数算，测试不猜名字）-> dispatch --print 渲染真实的启动命令。
P16_R="$TMP/p16-repo"; rm -rf "$P16_R"; mkdir -p "$P16_R"
( cd "$P16_R" && git init -q -b main && git config user.email p16@x && git config user.name p16 \
  && printf '# p16 zero-change fixture\n' > README.md && git add -A && git commit -qm init )
( cd "$P16_R" && $TEAM init --session "teamsmith-p16-$$" --agents dev --vcs local --gates "true" --docs docs/team ) \
  >"$TMP/p16-init.log" 2>&1 || bad "P16 夹具 init 失败（见 $TMP/p16-init.log）"
( cd "$P16_R" && $TEAM task T1.1 --title "p16 zero change" --agent dev ) >"$TMP/p16-task.log" 2>&1 || true
# P24（B3）：change-less 的任务书要有锚（本节测的是 init skill 的零改动）
( cd "$P16_R" && sed -i 's|^anchor: -.*$|anchor: none (infra) — smoke fixture|' docs/team/tasks/T1.1-*.md ) 2>/dev/null || true
( cd "$P16_R" && $TEAM add-agent dev --create --no-install ) >"$TMP/p16-add.log" 2>&1 || true
p16_canon_branch() { # <agent> <ID>：用实现自己的函数算规范分支
  ( cd "$P16_R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_branch_for_agent "'"$1"'" "'"$2"'"' )
}
P16_BR="$(p16_canon_branch dev T1.1)"
git -C "$P16_R/.worktrees/dev" switch -c "$P16_BR" main >/dev/null 2>&1 \
  || git -C "$P16_R/.worktrees/dev" switch "$P16_BR" >/dev/null 2>&1
( cd "$P16_R" && TEAM_PI_BIN=/bin/true $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md --print ) \
  >"$TMP/p16-dispatch-print.log" 2>&1 || true
assert_has "$TMP/p16-dispatch-print.log" "--skill $SKILL_DIR" "渲染的启动命令仍挂日常 skill 目录（--skill）"
assert_not "$TMP/p16-dispatch-print.log" "teamsmith-init" "渲染的启动命令不含 teamsmith-init"

section "19 · OpenSpec 五阶段流水线：每阶段有所有者与门禁（M9.1）"

OS_PHASES="explore propose apply verify archive"
OS_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"

os_pipeline_hits() { # <skill 目录> → 违规行（空 = 通过）
  local d="$1" f="$1/references/openspec.md" p t n
  if [ ! -f "$f" ]; then printf 'references/openspec.md: GUIDE-MISSING\n'; return 0; fi
  # ① 五个阶段各一行：第 3 列是 `opsx-<phase>`，第 4 列（所有者）与第 7 列（门禁）必须非空
  for p in $OS_PHASES; do
    awk -F'|' -v p="$p" '
      $3 ~ ("`opsx-" p "`") {
        row = 1
        owner = $4; gate = $7
        gsub(/[[:space:]]/, "", owner); gsub(/[[:space:]]/, "", gate)
        if (owner == "") print "OWNER-EMPTY " p
        if (gate == "") print "GATE-EMPTY " p
      }
      END { if (!row) print "ROW-MISSING " p }
    ' "$f" | sed 's|^|references/openspec.md: |'
  done
  # ② 两条硬规则：没人复验自己的工作；归档要用户确认
  grep -qi 'verifies its own work' "$f" || printf 'references/openspec.md: RULE-INDEPENDENT-MISSING\n'
  grep -qEi 'user[^|]*confirm|confirm[^|]*user' "$f" || printf 'references/openspec.md: RULE-USER-CONFIRM-MISSING\n'
  # ③ propose→apply 的记录式门：记录路径 + 判定词 + 「未 ACCEPTED 不得派 apply」
  grep -q 'reviews/<change>-proposal.md' "$f" || printf 'references/openspec.md: PROPOSAL-RECORD-MISSING\n'
  grep -q 'ACCEPTED' "$f" || printf 'references/openspec.md: PROPOSAL-VERDICT-MISSING\n'
  grep -qi 'no apply brief' "$f" || printf 'references/openspec.md: APPLY-GATE-MISSING\n'
  # ④ 十条审查清单逐条可照做：数量写死 10（P24/B7 把清单从八条长到十条），砍掉一条就报红
  n="$(awk '/^### The PM/ {on=1; next} /^## / {on=0} on && /^[0-9]+\./ {c++} END {print c+0}' "$f")"
  [ "$n" = "10" ] || printf 'references/openspec.md: CHECKLIST-COUNT %s\n' "$n"
  # ⑤ 指向 OpenSpec 自己的文档（而不是抄一遍），并写明阶段命令从哪来
  grep -q 'openspec instructions' "$f" || printf 'references/openspec.md: DOCS-POINTER-MISSING\n'
  grep -q 'openspec init --tools pi' "$f" || printf 'references/openspec.md: PRECONDITION-MISSING\n'
  grep -qE '^### Requirement:' "$f" && printf 'references/openspec.md: ARTIFACT-SYNTAX-COPIED\n'
  # ⑥ 这条门必须写进 agent/PM 真正读的文件 —— 只活在指南里 = 没人会照做
  for t in templates/AGENTS.section.md.tmpl templates/PROTOCOL.md.tmpl SKILL.md references/workflows.md; do
    if [ ! -f "$d/$t" ]; then printf '%s: FILE-MISSING\n' "$t"; continue; fi
    grep -q 'opsx-apply' "$d/$t" || printf '%s: PHASE-NAMES-MISSING\n' "$t"
    grep -q 'ACCEPTED' "$d/$t" || printf '%s: APPLY-GATE-MISSING\n' "$t"
    grep -qi 'independent' "$d/$t" || printf '%s: INDEPENDENT-VERIFY-MISSING\n' "$t"
  done
  # ⑥b 任务书模板：`phase:` 头 + 五阶段枚举 + apply 门（这一份是 PM 抄着写简报的底稿）
  t=templates/task.md.tmpl
  if [ ! -f "$d/$t" ]; then printf '%s: FILE-MISSING\n' "$t"; else
    grep -qE '^phase:' "$d/$t" || printf '%s: PHASE-FIELD-MISSING\n' "$t"
    grep -q 'explore|propose|apply|verify|archive' "$d/$t" || printf '%s: PHASE-ENUM-MISSING\n' "$t"
    grep -q 'ACCEPTED' "$d/$t" || printf '%s: APPLY-GATE-MISSING\n' "$t"
  fi
  for t in templates/AGENTS.section.md.tmpl templates/PROTOCOL.md.tmpl SKILL.md references/workflows.md references/openspec.md; do
    grep -qEi 'user[^|]*confirm|confirm[^|]*user' "$d/$t" || printf '%s: USER-CONFIRM-MISSING\n' "$t"
  done
  return 0
}

OS_HITS="$(os_pipeline_hits "$SKILL_DIR")"
if [ -z "$OS_HITS" ]; then
  ok "五阶段各有所有者与门禁；两条硬规则、记录式提案审查与十条清单都在（指南 + 模板 + SKILL + runbook）"
else
  bad "五阶段契约被破坏："
  printf '%s\n' "$OS_HITS" | head -5 | sed 's/^/     /'
fi
# 阶段命令必须真的存在（否则「跑 opsx-propose」只是名字，不是能敲的命令）
for p in $OS_PHASES; do
  assert_file "$OS_ROOT/.pi/prompts/opsx-$p.md" "本仓库为 Pi 生成了相位命令 opsx-$p"
done
for p in explore:openspec-explore propose:openspec-propose apply:openspec-apply-change verify:openspec-verify-change archive:openspec-archive-change; do
  assert_file "$OS_ROOT/.pi/skills/${p#*:}/SKILL.md" "相位 skill ${p#*:} 在位（${p%%:*} 阶段）"
done

# 翻转夹具：沙箱副本里逐项破坏契约，检查器必须**点名**报红。
#   红 = 破坏哪一条就报哪一条；净 = 干净副本不误报（正对照，排除「见了沙箱就报」）。
OS_SB="$TMP/m91-sandbox"; rm -rf "$OS_SB"; mkdir -p "$OS_SB"
cp -r "$SKILL_DIR"/references "$SKILL_DIR"/templates "$OS_SB/" 2>/dev/null || true
cp "$SKILL_DIR/SKILL.md" "$OS_SB/" 2>/dev/null || true

os_flip_red() { # <说明> <期望 REASON> <相对文件> <sed 参数...>
  local what="$1" reason="$2" file="$3"; shift 3
  local got
  rm -rf "$OS_SB-x"; cp -r "$OS_SB" "$OS_SB-x"
  sed -i "$@" "$OS_SB-x/$file"
  got="$(os_pipeline_hits "$OS_SB-x")"
  if printf '%s\n' "$got" | grep -q -- "$reason"; then
    ok "翻转自测：$what → 点名 $reason"
  else
    bad "翻转自测：$what 漏报（期望 $reason，实际 [$(printf '%s' "$got" | head -1)]）"
  fi
  rm -rf "$OS_SB-x"
}
OS_CLEAN_HITS="$(os_pipeline_hits "$OS_SB")"
[ -z "$OS_CLEAN_HITS" ] && ok "翻转自测：干净副本不误报（正对照）" \
  || bad "翻转自测：干净副本被误报：$(printf '%s' "$OS_CLEAN_HITS" | head -1)"

os_flip_red "指南里删掉 apply 那一行" "ROW-MISSING apply" "references/openspec.md" '/^| 3 | /d'
os_flip_red "掏空 verify 行的所有者单元格" "OWNER-EMPTY verify" "references/openspec.md" \
  's/^| 4 | `opsx-verify` |[^|]*|/| 4 | `opsx-verify` |  |/'
os_flip_red "掏空 propose 行的门禁单元格" "GATE-EMPTY propose" "references/openspec.md" \
  's/\(^| 2 | .*`opsx-propose`.*\)|[^|]*|$/\1|  |/'
os_flip_red "删掉「未 ACCEPTED 不得派 apply」" "APPLY-GATE-MISSING" "references/openspec.md" '/No apply brief may be dispatched/d'
os_flip_red "删掉「没人复验自己的工作」" "RULE-INDEPENDENT-MISSING" "references/openspec.md" '/verifies its own work/d'
os_flip_red "抹掉「归档要用户确认」" "RULE-USER-CONFIRM-MISSING" "references/openspec.md" \
  -E 's/user[^|]*confirm[^|]*/ACCOUNTABILITY-REMOVED/g'
os_flip_red "删掉提案审查记录路径" "PROPOSAL-RECORD-MISSING" "references/openspec.md" '/reviews\/<change>-proposal/d'
os_flip_red "把十条清单砍掉一条" "CHECKLIST-COUNT 9" "references/openspec.md" '/^8\. \*\*Granularity\*\*/d'
os_flip_red "删掉阶段命令的启用前提" "PRECONDITION-MISSING" "references/openspec.md" '/openspec init --tools pi/d'
os_flip_red "指南把 requirement 语法样板抄回来" "ARTIFACT-SYNTAX-COPIED" "references/openspec.md" '$a ### Requirement: Copied syntax'
os_flip_red "任务书模板不再提 apply 门" "APPLY-GATE-MISSING" "templates/task.md.tmpl" '/ACCEPTED/d'
os_flip_red "AGENTS 协议段不再提用户确认" "USER-CONFIRM-MISSING" "templates/AGENTS.section.md.tmpl" \
  -E 's/user[^|]*confirm[^|]*/ACCOUNTABILITY-REMOVED/g'
os_flip_red "任务书模板删掉 phase: 头" "PHASE-FIELD-MISSING" "templates/task.md.tmpl" '/^phase:/d'
os_flip_red "runbook 里的 verify 不再写独立" "INDEPENDENT-VERIFY-MISSING" "references/workflows.md" '/independent/d'

# ---------------------------------------------------------------- 20. done 证据的阶段感知（M9.2）
# 契约：任务书声明 `phase:` 时，done **额外**接受该阶段的交付证据（OpenSpec 五阶段各一条路线，
#   见 references/openspec.md §1/§5）；没有 phase / 值是 `-` / 值不认识 → 旧规则一字不改。
#   最后两条夹具是**控制组**：把阶段专属证据全部摆到桌面上，未声明 phase / 未知 phase 的任务
#   照样被拒 —— 证明这次改动没有把守卫放宽成「随便就能 done」。
# 纯逻辑（只读文件 + 只写夹具自己的 docs/team），快慢模式都跑。
section "20 · done 证据的阶段感知（M9.2）"
cd "$REPO" || exit 1

m92_brief() { # <ID> <phase|-> <change|->：写一份最小任务书（头块字段与 PM 的模板同形）
  local id="$1" phase="$2" change="$3"
  mkdir -p "$REPO/docs/team/tasks"
  {
    printf '# %s · smoke phase fixture\n\n```\ntask:   %s\nagent:  dev\n' "$id" "$id"
    [ "$phase" = "-" ] || printf 'phase:  %s\n' "$phase"
    printf 'change: %s\ndeps:   -\nstatus: todo\n```\n' "$change"
  } > "$REPO/docs/team/tasks/$id-smoke.md"
}
m92_add() { # <ID> <phase|-> <change|->：BOARD 建行 + 任务书
  $TEAM board add "$1" "phase fixture ($2)" dev "-" >/dev/null 2>&1 || true
  m92_brief "$1" "$2" "$3"
}
m92_done() { # <ID> → 打印 done 的退出码（0=过闸），日志留在 $TMP/m92-<ID>.log
  # TEAM_SPEC_DIR 显式钉成 openspec：本文件更早的 doctor 夹具往夹具仓库的 config.sh 里追加过
  # 绝对路径的 spec 目录（第 15b 节），不钉住的话这里测的就不是「归档证据」而是那份残留配置。
  if env TEAM_BOARD_DONE_FORCE=0 TEAM_SPEC_DIR=openspec $TEAM board set "$1" done >"$TMP/m92-$1.log" 2>&1; then
    printf '0\n'
  else
    printf '1\n'
  fi
}

# ① explore：交付 = PM 的接受记录（DECISIONS.md 里一个**标题条目**点名任务 id，或一份复验记录）
m92_add X9.1 explore -
assert_eq "explore：没有任何接受记录 → 拒绝" "$(m92_done X9.1)" "1"
assert_has "$TMP/m92-X9.1.log" "DECISIONS.md" "explore 拒绝信息点名 DECISIONS.md"
assert_has "$TMP/m92-X9.1.log" "reviews/X9.1.md" "explore 拒绝信息点名复验记录"
assert_has "$TMP/m92-X9.1.log" "阶段 explore 的交付" "explore 拒绝信息给出阶段路线"
assert_eq "explore：被拒后 BOARD 没动" "$(board_status X9.1)" "todo"
assert_not_file "$REPO/docs/team/reviews/X9.1-done.md" "被拒时不写 done 审计"
# 正文提及 ≠ 接受条目：旧条目的正文经常提到别的任务 id，那会变成「提过就算接受」——把守卫放宽
printf '\n- **备注**：X9.1 的探索结论值得再读一遍（正文提及，不是接受条目）。\n' >> "$REPO/docs/team/DECISIONS.md"
assert_eq "explore：只有正文提及、没有标题条目 → 仍然拒绝" "$(m92_done X9.1)" "1"
printf '\n## D92 · smoke — accept X9.1 exploration\n\n- **决策**：接受 X9.1 的探索结论。\n' >> "$REPO/docs/team/DECISIONS.md"
assert_eq "explore：DECISIONS.md 标题条目点名任务 → 允许 done" "$(m92_done X9.1)" "0"
assert_has "$TMP/m92-X9.1.log" "PM 接受记录" "成功输出说明找到的是 DECISIONS.md 的记录"
assert_has "$TMP/m92-X9.1.log" "DECISIONS.md" "成功输出给出记录路径"
assert_has "$REPO/docs/team/reviews/X9.1-done.md" "阶段 explore 的交付证据" "审计写下当时核对了什么（阶段证据）"
m92_add X9.2 explore -
printf '# X9.2 · smoke\n\n判定: **PASS**\n' > "$REPO/docs/team/reviews/X9.2.md"
assert_eq "explore：复验记录同样算接受 → 允许 done" "$(m92_done X9.2)" "0"
assert_has "$TMP/m92-X9.2.log" "复验记录" "成功输出说明找到的是复验记录"
m92_add X9.3 explore -
printf '# X9.3 · smoke\n\n判定: **FAIL**\n' > "$REPO/docs/team/reviews/X9.3.md"
assert_eq "explore：判定 FAIL 的记录不是「接受」→ 拒绝" "$(m92_done X9.3)" "1"
assert_has "$TMP/m92-X9.3.log" "FAIL" "explore 拒绝信息点名 FAIL"

# ② propose：交付 = PM 提案审查记录 reviews/<change>-proposal.md，判定 ACCEPTED
m92_add X9.4 propose demo-change-a
assert_eq "propose：没有提案审查记录 → 拒绝" "$(m92_done X9.4)" "1"
assert_has "$TMP/m92-X9.4.log" "demo-change-a-proposal.md" "propose 拒绝信息按 change id 点名记录"
printf '# demo-change-a · PM proposal review\n\ntime: 2026-09-15T00:00:00Z · verdict: **NEEDS-CHANGES**\n' \
  > "$REPO/docs/team/reviews/demo-change-a-proposal.md"
assert_eq "propose：NEEDS-CHANGES → 拒绝" "$(m92_done X9.4)" "1"
assert_has "$TMP/m92-X9.4.log" "NEEDS-CHANGES" "propose 拒绝信息点名 NEEDS-CHANGES"
printf '# demo-change-a · PM proposal review\n\ntime: 2026-09-15T00:00:00Z · verdict: **ACCEPTED**\n' \
  > "$REPO/docs/team/reviews/demo-change-a-proposal.md"
assert_eq "propose：ACCEPTED → 允许 done" "$(m92_done X9.4)" "0"
assert_has "$TMP/m92-X9.4.log" "判定 ACCEPTED" "成功输出说明判定是 ACCEPTED"
m92_add X9.4b propose demo-change-a2
printf '# demo-change-a2 · PM proposal review\n\n判定: **ACCEPTED**\n' \
  > "$REPO/docs/team/reviews/demo-change-a2-proposal.md"
assert_eq "propose：中文抬头 判定: **ACCEPTED** 同样认" "$(m92_done X9.4b)" "0"
m92_add X9.4c propose -
assert_eq "propose：任务书没有 change: 行 → 拒绝（不猜对哪一份提案）" "$(m92_done X9.4c)" "1"
assert_has "$TMP/m92-X9.4c.log" "change:" "propose 拒绝信息说明缺 change: 行"

# ③ apply：与代码任务同规则（今天的规则不变）
m92_add X9.5 apply -
assert_eq "apply：没有证据 → 拒绝（规则不变）" "$(m92_done X9.5)" "1"
assert_has "$TMP/m92-X9.5.log" "① 复验记录" "apply 仍走 ① 复验记录"
printf '# X9.5 · smoke\n\n判定: **PASS**\n' > "$REPO/docs/team/reviews/X9.5.md"
assert_eq "apply：判定 PASS 的复验记录 → 允许 done" "$(m92_done X9.5)" "0"

# ④ verify：交付 = 该任务的复验记录
m92_add X9.6 verify -
assert_eq "verify：没有复验记录 → 拒绝" "$(m92_done X9.6)" "1"
assert_has "$TMP/m92-X9.6.log" "阶段 verify 的交付" "verify 拒绝信息给出阶段路线"
printf '# X9.6 · smoke\n\n判定: **PASS**\n' > "$REPO/docs/team/reviews/X9.6.md"
assert_eq "verify：复验记录 → 允许 done" "$(m92_done X9.6)" "0"

# ⑤ archive：交付 = change id 出现在 openspec/changes/archive/ 下（目录匹配即可）
m92_add X9.7 archive demo-change-b
assert_eq "archive：change 还没归档 → 拒绝" "$(m92_done X9.7)" "1"
assert_has "$TMP/m92-X9.7.log" "demo-change-b" "archive 拒绝信息点名 change id"
assert_has "$TMP/m92-X9.7.log" "changes/archive" "archive 拒绝信息给出归档目录"
mkdir -p "$REPO/openspec/changes/archive/2026-09-15-demo-change-b"
assert_eq "archive：归档目录出现 → 允许 done" "$(m92_done X9.7)" "0"
assert_has "$TMP/m92-X9.7.log" "2026-09-15-demo-change-b" "成功输出给出实际归档目录"
m92_add X9.8 archive demo-change-c
assert_eq "archive：别的 change 归档了不算它归档 → 拒绝" "$(m92_done X9.8)" "1"

# ⑥ 解析：PM 常在模板上直接改，值后面还挂着 `# ...` 同行注释 —— 注释不能把 phase/change 弄坏
$TEAM board add X9.11 "template-shaped fixture" dev "-" >/dev/null 2>&1 || true
printf '# X9.11 · template-shaped fixture\n\n```\ntask:   X9.11\nagent:  dev\nissue:  -\nchange: demo-change-f            # OpenSpec change id this brief implements\nspecs:  -            # requirements/scenarios it must satisfy\nphase:  propose       # OpenSpec pipeline phase this brief runs\ndeps:   -\nstatus: todo\n```\n' \
  > "$REPO/docs/team/tasks/X9.11-tmpl.md"
printf '# demo-change-f · PM proposal review\n\nverdict: **ACCEPTED**\n' \
  > "$REPO/docs/team/reviews/demo-change-f-proposal.md"
assert_eq "解析：模板头块的同行注释不影响 phase/change" "$(m92_done X9.11)" "0"
assert_has "$TMP/m92-X9.11.log" "demo-change-f-proposal.md" "解析出的 change id 就是注释前面的那个"

# ⑦ 控制组：阶段专属证据全部摆上桌，但任务书没有 phase（或 phase 值不认识）→ 旧规则照样拒绝
m92_add X9.9 - demo-change-d
printf '\n## D93 · smoke — accept X9.9\n' >> "$REPO/docs/team/DECISIONS.md"
mkdir -p "$REPO/openspec/changes/archive/2026-09-15-demo-change-d"
printf '# demo-change-d · PM proposal review\n\nverdict: **ACCEPTED**\n' \
  > "$REPO/docs/team/reviews/demo-change-d-proposal.md"
assert_eq "控制：未声明 phase 的任务，阶段证据一律不算（守卫不得放宽）" "$(m92_done X9.9)" "1"
assert_not "$TMP/m92-X9.9.log" "阶段" "未声明 phase 时拒绝信息不提阶段路线"
assert_eq "控制：被拒后 BOARD 状态仍 todo" "$(board_status X9.9)" "todo"
m92_add X9.10 banana demo-change-d
printf '\n## D94 · smoke — accept X9.10\n' >> "$REPO/docs/team/DECISIONS.md"
assert_eq "控制：未知 phase 值不解释（= 没有 phase）→ 拒绝" "$(m92_done X9.10)" "1"
assert_not "$TMP/m92-X9.10.log" "阶段" "未知 phase 的拒绝信息也不提阶段路线"

# ---------------------------------------------------------------- 21. 待复验清单不得越过看板决定（M9.4）
# 契约（真实假信号：P1 已 REVIEW+done 还每拍被列为待复验）：
#   ① 看板已裁决（done/closed）的任务**永远不列**在待复验里 —— 证据是在看板转变那一刻核对的
#      （M9.2），清单不得反过来质疑看板；
#   ② 还挂在 todo/wip 的任务保持 M6.2 的旧规则（控制组：跳过只能来自看板，不能来自文件名）；
#   ③ 声明了 phase 的任务给的是**阶段**的下一步 —— explore/propose/archive 的交付不在代码分支上，
#      那句通用的 `team review <ID>` 会让 PM 去验错东西；
#   ④ 叠分支（apply 建在 propose 上，D16）带来的报告副本不能抢走正本，也不能被说成「在别人的分支上」；
#   ⑤ 跳过的报告不静默丢：digest 用一行点名，team status <ID> 也说明为什么。
# 纯逻辑（只写夹具自己的 docs/team + 夹具工作树），快慢模式都跑。
section "21 · 待复验清单不得越过看板决定（M9.4）"
cd "$REPO" || exit 1

m94_brief() { # <ID> <phase|-> <change|->：与 PM 的模板同形的最小任务书
  local id="$1" phase="$2" change="$3"
  mkdir -p "$REPO/docs/team/tasks"
  {
    printf '# %s · smoke M9.4 fixture\n\n```\ntask:   %s\nagent:  dev\n' "$id" "$id"
    [ "$phase" = "-" ] || printf 'phase:  %s\n' "$phase"
    printf 'change: %s\ndeps:   -\nstatus: todo\n```\n' "$change"
  } > "$REPO/docs/team/tasks/$id-smoke.md"
}
m94_add() { # <ID> <agent> <phase|-> <change|->：BOARD 建行 + 任务书
  $TEAM board add "$1" "pending fixture" "$2" "-" >/dev/null 2>&1 || true
  m94_brief "$1" "$3" "$4"
}
m94_report() { # <ID> <agent> [目录]：写一份任务报告（标题与文件名都要让 team_report_is_task 认得）
  local dir="${3:-$REPO/docs/team/reports}"
  mkdir -p "$dir"
  printf '# %s · smoke M9.4 fixture\n\nagent: %s   状态: DONE\n\n## 交付物\n- fixture（本用例只关心它出现在待复验清单里的方式）\n' \
    "$1" "$2" > "$dir/$1-$2.md"
}
m94_review() { # <change> <判定>：写一份提案审查记录
  mkdir -p "$REPO/docs/team/reviews"
  printf '# %s · PM proposal review\n\nverdict: **%s**\n' "$1" "$2" > "$REPO/docs/team/reviews/$1-proposal.md"
}
m94_pending() { # → 待复验清单（与 CLI 同一个函数：每行 "<id>\t<显示名>\t<路径>"）
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_reports_pending_list' )
}

# ① phase=propose + 提案审查记录 ACCEPTED + 看板 done → **不列**
#    （done 的证据是 M9.2 核对的提案记录，不是 reviews/<任务ID>.md）
m94_add M94A dev propose m94-change-a
m94_report M94A dev
m94_review m94-change-a ACCEPTED
env TEAM_BOARD_DONE_FORCE=0 $TEAM board set M94A done >"$TMP/m94-a-done.log" 2>&1 || true
assert_eq "M9.4-①：propose 任务的阶段证据（ACCEPTED）允许看板 done" "$(board_status M94A)" "done"
m94_pending >"$TMP/m94-a-pending.log"
assert_not "$TMP/m94-a-pending.log" "M94A" "看板 done 的 phase 任务不再列为待复验"
$TEAM digest >"$TMP/m94-a-digest.log" 2>&1 || true
assert_not "$TMP/m94-a-digest.log" "team review M94A" "digest 不再给 done 的 phase 任务派 review 待办"
assert_has "$TMP/m94-a-digest.log" "已按看板跳过" "digest 用一行说明它为什么没被列（不静默跳过）"
assert_has "$TMP/m94-a-digest.log" "M94A-dev" "跳过行点名了那份报告"

# ② 控制组：同一个夹具只把看板换成 wip → **仍然在清单里**（跳过只能来自看板，不能来自文件名）
m94_add M94B dev propose m94-change-b
m94_report M94B dev
m94_review m94-change-b ACCEPTED
$TEAM board set M94B wip >/dev/null 2>&1 || true
m94_pending >"$TMP/m94-b-pending.log"
assert_has "$TMP/m94-b-pending.log" "M94B" "看板还没裁决时，propose 任务的报告仍然列出来（控制组）"
$TEAM digest >"$TMP/m94-b-digest.log" 2>&1 || true
assert_has "$TMP/m94-b-digest.log" "阶段证据已就绪" "wip 的 phase 任务给的是阶段下一步（M9.2 的证据）"
assert_has "$TMP/m94-b-digest.log" "m94-change-b-proposal.md" "阶段下一步点名了提案审查记录"
assert_not "$TMP/m94-b-digest.log" "team review M94B" "不再给 phase 任务一句通用的 team review"

# ③ 普通代码任务 + 看板 done（无复验记录，照搬 P1 现场的 FORCED）→ **不列**，但 digest 必须说出来
m94_add M94C dev - -
m94_report M94C dev
env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="smoke M9.4: 看板裁决先于复验记录（真实 P1 现场）" \
  $TEAM board set M94C done >"$TMP/m94-c-done.log" 2>&1 || true
assert_eq "M9.4-③：没有记录时 done 要靠 PM 显式覆盖（与 P1 现场一致）" "$(board_status M94C)" "done"
m94_pending >"$TMP/m94-c-pending.log"
assert_not "$TMP/m94-c-pending.log" "M94C" "看板 done 的代码任务不再列为待复验（哪怕没有复验记录）"
$TEAM digest >"$TMP/m94-c-digest.log" 2>&1 || true
assert_has "$TMP/m94-c-digest.log" "已按看板跳过" "digest 点名说明了为什么没列"
assert_has "$TMP/m94-c-digest.log" "M94C-dev" "跳过行点名了那份报告"
assert_not "$TMP/m94-c-digest.log" "team review M94C" "跳过之后 digest 不再给 review 待办"
$TEAM status M94C >"$TMP/m94-c-status.log" 2>&1 || true
assert_has "$TMP/m94-c-status.log" "不列" "team status <ID> 也说明这份报告为什么不列"

# ④ 控制组：没有 phase、看板 wip 的报告 → 行与行动照旧（行为不变）
m94_add M94D dev - -
m94_report M94D dev
$TEAM board set M94D wip >/dev/null 2>&1 || true
m94_pending >"$TMP/m94-d-pending.log"
assert_has "$TMP/m94-d-pending.log" "M94D" "控制组：没有 phase 的报告照旧列为待复验"
$TEAM digest >"$TMP/m94-d-digest.log" 2>&1 || true
assert_has "$TMP/m94-d-digest.log" "team review M94D" "代码任务照旧给 team review 待办"

# ⑤ 叠分支（D16）：apply 分支建在 propose 分支上 → 同一份报告出现在两份工作树里。
#    工作树名字故意让**副本**排在字母前面（m94a < m94z）：只按 glob 顺序挑副本的实现会把这份报告
#    说成「在 m94a 的分支上」（归错任务），也把正本（m94z）挤掉。
M94_Z="$REPO/.worktrees/m94z"    # propose：报告的正本（作者 == 工作树名）
M94_A="$REPO/.worktrees/m94a"    # apply：基于 propose，继承同一份报告（字母序在前）
git -C "$REPO" worktree remove --force "$M94_Z" >/dev/null 2>&1 || true
git -C "$REPO" worktree remove --force "$M94_A" >/dev/null 2>&1 || true
git -C "$REPO" branch -D task/M94E-propose task/M94P-apply >/dev/null 2>&1 || true
m94_add M94E m94z propose m94-change-e
m94_review m94-change-e ACCEPTED
git -C "$REPO" worktree add -q -b task/M94E-propose "$M94_Z" main
m94_report M94E m94z "$M94_Z/docs/team/reports"
git -C "$M94_Z" add -A
git -C "$M94_Z" -c user.email=smoke@local -c user.name=smoke commit -qm "docs(M94E): propose report"
git -C "$REPO" worktree add -q -b task/M94P-apply "$M94_A" task/M94E-propose
assert_file "$M94_A/docs/team/reports/M94E-m94z.md" "叠分支夹具：副本确实出现在 apply 工作树里"
$TEAM board set M94E wip >/dev/null 2>&1 || true
m94_pending >"$TMP/m94-e-pending.log"
assert_eq "M9.4-④：同一个任务只列一行（副本不重复计数）" "$(grep -c '^M94E' "$TMP/m94-e-pending.log" || true)" "1"
assert_match "$TMP/m94-e-pending.log" 'm94z/docs/team/reports/M94E-m94z\.md$' \
  "留下的是归属副本（m94z 自己的分支），字母序不再说了算"
$TEAM digest >"$TMP/m94-e-digest.log" 2>&1 || true
assert_has "$TMP/m94-e-digest.log" "M94E-m94z（在 m94z 分支上）" "digest 把报告归到它自己的工作树"
assert_not "$TMP/m94-e-digest.log" "在 m94a 分支上" "不会把副本说成「在 m94a 分支上」（归错任务）"
# 正本的工作树不在了（任务收尾、agent 换了分支）：只剩副本时必须说出来是副本 —— 不静默丢，也不乱归属
git -C "$REPO" worktree remove --force "$M94_Z" >/dev/null 2>&1 || true
m94_pending >"$TMP/m94-e2-pending.log"
assert_match "$TMP/m94-e2-pending.log" '/m94a/' "正本不在本地时仍然列出这份报告（不静默丢）"
$TEAM digest >"$TMP/m94-e2-digest.log" 2>&1 || true
assert_has "$TMP/m94-e2-digest.log" "副本：在 m94a 的工作树里" "digest 明说这是副本，不把归属算到 m94a 头上"

# ---------------------------------------------------------------- 22. 派单不许叠任务（M9.3 / D16）
# 契约（真实事故 D16 #1：M9.2 还在 dev 手上，PM 把 P2 派给同一个 agent —— 新派单接管了它的窗口与 state，
# M9.2 只好临时换人交接。工具当时就知道那个 agent 的任务/分支：state/<agent>.env、BOARD、工作树）：
#   ① agent 记着一个**没结束**的任务 X（没有复验记录 / 没并进保护分支 / 看板不是 done·closed·dropped），
#      而这次要派的是另一个 ID → 默认拒绝：点名 X、它的看板状态、分支，以及两条出路（resume / --force）。
#   ② `--force` 是显式覆盖，并且**打印出来**（不许静默接管）；覆盖只针对「叠任务」这一条守卫 ——
#      工作树的分支身份（M6.3 F16）照旧独立生效。
#   ③ 派的就是 X 自己 → 一律不拦（resume / 断点续跑是「继续」，不是「叠」）。
#   ④ X 已经结束（复验记录 / 已并入保护分支 / 看板裁决）→ 输出与以前逐字一样。
#   ⑤ state 判不出来（没有 state / task= 为空 / 找不到工作树 / 读不到分支）→ 不猜：照旧派单，但说清缺哪个信号。
#   ⑥ 同一个 ID 有多份任务书 → 拒绝并列出全部（旧实现按 glob 第一份算 slug：撞分支名 / 拿错 scope）。
# 纯逻辑（夹具自己的 state + `--print`），快慢模式都跑；真拉起仍由 6 / 6h / 11c 覆盖。
section "22 · 派单不许叠任务（M9.3 / D16）"
cd "$REPO" || exit 1

M93_AGENTS="dev verify m93a m93b m93c"
m93_run() { env TEAM_AGENTS="$M93_AGENTS" $TEAM "$@"; }   # 三个夹具 agent 只在本节的名册里
m93_brief() { # <ID> <agent>：最小任务书（头块与 PM 的模板同形）
  mkdir -p "$REPO/docs/team/tasks"
  # P24（B3）：change-less 的任务书要有锚 —— 本节测的是叠任务守卫，得先过锚守卫
  printf '# %s · M9.3 smoke fixture\n\ntask:   %s\nagent:  %s\nanchor: none (infra) — smoke fixture\ndeps:   -\nstatus: todo\n' \
    "$1" "$1" "$2" > "$REPO/docs/team/tasks/$1-m93-smoke.md"
}
m93_add() { # <ID> <agent>：BOARD 行 + 任务书
  $TEAM board add "$1" "M9.3 fixture $1" "$2" - >/dev/null 2>&1 || true
  m93_brief "$1" "$2"
}
m93_wt() { # <agent> <ID> → 把它的工作树切到该 ID 的规范分支（分支身份守卫要求工作树停在本次任务的分支上）
  local a="$1" id="$2" wt="$REPO/.worktrees/$1" br
  br="$(canon_branch "$a" "$id")"
  git -C "$REPO" worktree remove --force "$wt" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$br" >/dev/null 2>&1 || true
  git -C "$REPO" worktree add -q -b "$br" "$wt" "$PROTECTED"
  printf '%s\n' "$br"
}
_git_add_commit() { # <工作树> <提交信息>：夹具提交（作者固定，不碰仓库/全局 git 配置）
  git -C "$1" add -A >/dev/null 2>&1 || true
  git -C "$1" -c user.email=smoke@local -c user.name=smoke commit -qm "$2" >/dev/null 2>&1 || true
}
m93_state() { # <agent> <task> <taskfile> <branch>：夹具 state（键与 dispatch 写下的同形）
  mkdir -p "$REPO/.pi/team/state"
  { printf 'model=deepseek/deepseek-flash\nwindow=%s\nworktree=%s\n' "$1" "$REPO/.worktrees/$1"
    printf 'task=%s\ntaskfile=%s\nbranch=%s\nstarted=2026-09-15T00:00:00Z\n' "$2" "$3" "$4"
  } > "$REPO/.pi/team/state/$1.env"
}

# ① 叠任务的形状（D16 #1）：state 记着 M93A1（分支上真的有未交付的提交），工作树已被准备好接 M93A2
m93_add M93A1 m93a
m93_add M93A2 m93a
$TEAM board set M93A1 wip >/dev/null 2>&1 || true
M93A1_BR="$(m93_wt m93a M93A1)"
printf 'wip(M93A1)\n' > "$REPO/.worktrees/m93a/wip.txt"   # 夹具：M93A1 有还没并进 main 的提交
_git_add_commit "$REPO/.worktrees/m93a" "wip(M93A1): fixture"
m93_state m93a M93A1 "$REPO/docs/team/tasks/M93A1-m93-smoke.md" "$M93A1_BR"
M93A2_BR="$(m93_wt m93a M93A2)"
M93A2_BRIEF="$REPO/docs/team/tasks/M93A2-m93-smoke.md"
if m93_run dispatch m93a M93A2 "$M93A2_BRIEF" --print >"$TMP/m93-a-refuse.log" 2>&1; then
  bad "M9.3-①：M93A1 没结束就派 M93A2 —— 应当拒绝"
else ok "M9.3-①：另一个没结束的任务压着这个 agent → 默认拒绝"; fi
assert_has "$TMP/m93-a-refuse.log" "M93A1" "拒绝信息点名它手上那个任务"
assert_has "$TMP/m93-a-refuse.log" "wip" "拒绝信息带上看板状态"
assert_has "$TMP/m93-a-refuse.log" "$M93A2_BR" "拒绝信息带上工作树现在停的分支"
assert_has "$TMP/m93-a-refuse.log" "resume" "出路一：先收尾（resume）"
assert_has "$TMP/m93-a-refuse.log" "--force" "出路二：显式覆盖 --force"
assert_not "$TMP/m93-a-refuse.log" "=== agent 命令" "被拒时没有派单计划（不留半启动）"
assert_has "$REPO/.pi/team/state/m93a.env" "task=M93A1" "被拒时 state 没被改写"
if m93_run dispatch m93a M93A2 "$M93A2_BRIEF" --print --force >"$TMP/m93-a-force.log" 2>&1; then
  ok "M9.3-①：--force 是显式覆盖 → 放行"
else bad "M9.3-①：--force 应当放行（见 $TMP/m93-a-force.log）"; fi
assert_has "$TMP/m93-a-force.log" "显式覆盖" "--force 的输出里写明这是覆盖（不静默接管）"
assert_has "$TMP/m93-a-force.log" "M93A1" "覆盖输出点名被压住的任务"
assert_has "$TMP/m93-a-force.log" "=== agent 命令" "覆盖后真的走到派单计划"
assert_has "$REPO/.pi/team/state/m93a.env" "task=M93A1" "（--print 无副作用：state 仍记着 M93A1）"

# ①b 另一种形状：工作树还停在旧任务的分支上。--force 只覆盖「叠任务」这一条，分支身份守卫照旧生效
git -C "$REPO/.worktrees/m93a" switch -q "$M93A1_BR"
if m93_run dispatch m93a M93A2 "$M93A2_BRIEF" --print >"$TMP/m93-b-refuse.log" 2>&1; then
  bad "M9.3-①b：工作树还在 M93A1 的分支上 → 应当拒绝"
else ok "M9.3-①b：工作树仍停在没结束的任务分支上 → 拒绝"; fi
assert_has "$TMP/m93-b-refuse.log" "M93A1" "拒绝信息点名它手上那个任务"
if m93_run dispatch m93a M93A2 "$M93A2_BRIEF" --print --force >"$TMP/m93-b-force.log" 2>&1; then
  bad "M9.3-①b：分支不属于 M93A2 时 --force 不该放行（分支身份是另一条独立的守卫）"
else ok "M9.3-①b：--force 只覆盖叠任务；停错分支仍被分支守卫拒绝"; fi
assert_has "$TMP/m93-b-force.log" "停在不属于本任务" "拒绝来自分支身份守卫（M6.3 F16）"
assert_not "$TMP/m93-b-force.log" "=== agent 命令" "仍然没有派单计划"

# ② 上一个任务已经结束（复验记录 PASS）→ 输出与以前逐字一样
git -C "$REPO/.worktrees/m93a" switch -q "$M93A2_BR"
mkdir -p "$REPO/docs/team/reviews"
printf '# M93A1 · smoke\n\n判定: **PASS**\n' > "$REPO/docs/team/reviews/M93A1.md"
if m93_run dispatch m93a M93A2 "$M93A2_BRIEF" --print >"$TMP/m93-c-finished.log" 2>&1; then
  ok "M9.3-②：上一个任务有复验记录 → 照旧派单"
else bad "M9.3-②：已结束的任务不该拦（见 $TMP/m93-c-finished.log）"; fi
assert_not "$TMP/m93-c-finished.log" "拒绝派单" "已结束时输出里没有拒绝"
assert_not "$TMP/m93-c-finished.log" "显式覆盖" "已结束时不需要覆盖"
assert_has "$TMP/m93-c-finished.log" "=== agent 命令" "照旧打印派单计划"
# 看板裁决（done）同样算结束：不靠复验记录也放行（M9.4 的同一原则：清单不得反过来质疑看板）
m93_add M93B1 m93b
M93B1_BR="$(m93_wt m93b M93B1)"
m93_state m93b M93B1 "$REPO/docs/team/tasks/M93B1-m93-smoke.md" "$M93B1_BR"
env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="smoke M9.3: 看板裁决先于复验记录" \
  $TEAM board set M93B1 done >/dev/null 2>&1 || true
assert_eq "M9.3-②：夹具的看板状态是 done" "$(board_status M93B1)" "done"
if m93_run dispatch m93b M93B1 "$REPO/docs/team/tasks/M93B1-m93-smoke.md" --print >"$TMP/m93-c-boarddone.log" 2>&1; then
  ok "M9.3-②：看板 done（裁决过了）→ 照旧派单"
else bad "M9.3-②：看板 done 时不该拦"; fi
assert_not "$TMP/m93-c-boarddone.log" "拒绝派单" "看板 done 时没有拒绝"
assert_has "$TMP/m93-c-boarddone.log" "=== agent 命令" "照旧打印派单计划"

# ③ 重新派同一个任务（resume 的形状）→ 一律不拦
m93_add M93C1 m93c
M93C1_BR="$(m93_wt m93c M93C1)"
M93C1_BRIEF="$REPO/docs/team/tasks/M93C1-m93-smoke.md"
m93_state m93c M93C1 "$M93C1_BRIEF" "$M93C1_BR"
if m93_run dispatch m93c M93C1 "$M93C1_BRIEF" --print >"$TMP/m93-d-same.log" 2>&1; then
  ok "M9.3-③：同一个任务的断点续跑 → 不拦（resume 的路径）"
else bad "M9.3-③：续跑被叠任务守卫误拦"; fi
assert_not "$TMP/m93-d-same.log" "拒绝派单" "续跑的输出里没有拒绝"
assert_has "$TMP/m93-d-same.log" "=== agent 命令" "续跑照旧打印派单计划"
# 第二扇门（resume）也只派它自己记着的任务 → 同一任务 = 继续，不该被拦
m93_run resume --agent m93c --dry-run >"$TMP/m93-d-resume.log" 2>&1 || true
assert_has "$TMP/m93-d-resume.log" "可续跑：M93C1" "resume --dry-run 仍把 M93C1 当成可续跑"
assert_not "$TMP/m93-d-resume.log" "拒绝" "resume 不被叠任务守卫拦（同一任务 = 继续）"

# ④ 状态判不出来 → 不猜：照旧派单，但说清缺哪个信号
rm -f "$REPO/.pi/team/state/m93c.env"
if m93_run dispatch m93c M93C1 "$M93C1_BRIEF" --print >"$TMP/m93-e-nostate.log" 2>&1; then
  ok "M9.3-④：没有 state 文件 → 不猜，照旧派单（第一次派单不该被拦死）"
else bad "M9.3-④：没有 state 时不该拒绝（见 $TMP/m93-e-nostate.log）"; fi
assert_has "$TMP/m93-e-nostate.log" "task=" "说明缺的信号是 state 里的 task="
assert_has "$TMP/m93-e-nostate.log" "m93c.env" "点名是哪个 state 文件"
assert_has "$TMP/m93-e-nostate.log" "=== agent 命令" "照旧打印派单计划"
# state 在、但 task= 是空的（close 之后的正常状态，team close 就是这么清的）：同样不猜
m93_state m93c "" "$M93C1_BRIEF" ""
if m93_run dispatch m93c M93C1 "$M93C1_BRIEF" --print >"$TMP/m93-e-emptytask.log" 2>&1; then
  ok "M9.3-④：state 里 task= 为空 → 同样照旧派单"
else bad "M9.3-④：task= 为空时不该拒绝"; fi
assert_has "$TMP/m93-e-emptytask.log" "task=" "空 task= 也说清缺的是哪个信号"
assert_has "$TMP/m93-e-emptytask.log" "=== agent 命令" "照旧打印派单计划"

# ⑤ 同一个 ID 有多份任务书 → 拒绝并列出全部（旧实现按 glob 第一份算 slug：撞分支名 / 拿错 scope）
$TEAM board add M93E "M9.3 fixture M93E" m93c - >/dev/null 2>&1 || true
M93E_BR="$(m93_wt m93c M93E)"
assert_eq "M9.3-⑤ 夹具有效：m93c 的工作树停在 M93E 的规范分支上" \
  "$(git -C "$REPO/.worktrees/m93c" rev-parse --abbrev-ref HEAD)" "$M93E_BR"
printf '# M93E · 旧的那份\n\ntask: M93E\nagent: m93c\nanchor: none (infra) — smoke fixture\n' > "$REPO/docs/team/tasks/M93E-legacy.md"
printf '# M93E · 新的那份\n\ntask: M93E\nagent: m93c\nanchor: none (infra) — smoke fixture\n' > "$REPO/docs/team/tasks/M93E-reverify.md"
M93E_BRIEF="$REPO/docs/team/tasks/M93E-reverify.md"
if m93_run dispatch m93c M93E "$M93E_BRIEF" --print >"$TMP/m93-f-ambiguous.log" 2>&1; then
  bad "M9.3-⑤：两份任务书时不该猜哪一份是这次的 scope"
else ok "M9.3-⑤：ID 有歧义 → 拒绝（不猜）"; fi
assert_has "$TMP/m93-f-ambiguous.log" "M93E-legacy.md" "拒绝信息列出第一份候选"
assert_has "$TMP/m93-f-ambiguous.log" "M93E-reverify.md" "拒绝信息列出第二份候选"
assert_not "$TMP/m93-f-ambiguous.log" "=== agent 命令" "歧义时没有派单计划"
if m93_run dispatch m93c M93E "$M93E_BRIEF" --print --force >"$TMP/m93-f-force.log" 2>&1; then
  bad "M9.3-⑤：歧义不该被 --force 放过（认错 scope 不是「你说了算」的事）"
else ok "M9.3-⑤：--force 也不放过歧义（先收拾任务书，确定性优先）"; fi
assert_not "$TMP/m93-f-force.log" "=== agent 命令" "歧义时 --force 同样没有派单计划"
# 控制组：前缀相同的另一个 ID（M93E9-…）不属于 M93E，不该被算成歧义
mv "$REPO/docs/team/tasks/M93E-legacy.md" "$REPO/docs/team/tasks/M93E9-other.md"
if m93_run dispatch m93c M93E "$M93E_BRIEF" --print >"$TMP/m93-f-single.log" 2>&1; then
  ok "M9.3-⑤：只剩一份任务书 → 照旧派单（前缀相同的另一个 ID 不算歧义）"
else bad "M9.3-⑤：只剩一份任务书仍被拒（见 $TMP/m93-f-single.log）"; fi
assert_has "$TMP/m93-f-single.log" "=== agent 命令" "控制组真的走到派单计划"
assert_has "$TMP/m93-f-single.log" "prompt-m93c-M93E.md" "控制组派的就是 M93E 这一次的 scope"

# ---------------------------------------------------------------- 23. verify 的待复验判据 = 记录绑定的 revision（M9.5）
# 契约（真实假信号：V2 的 PASS 记录绑着 P2.1 的 398716887，digest 却按复验者自己的 task/V2-… 分支把它标成
# stale「verified 398716887, branch now 44788f09b」）：
#   ① verify 任务：记录只对它验过的 revision 负责 —— 被判对象是记录抬头里的 `分支:`（被验分支），
#      复验者自己随后在报告分支上落的提交**不算**过期；
#   ② 真信号不许被吞掉：被验分支在记录之后又前进一格 → 仍然列为待复验，并点名两个 revision；
#   ③ 控制组：未声明 phase 的任务照旧「记录 vs 任务分支当前 tip」（M6.2/F3 行为逐字不变）。
# 纯逻辑（夹具自己的任务书/报告/分支/记录 + 与 digest 同一批函数），快慢模式都跑。
section "23 · verify 任务的待复验判据 = 记录绑定的 revision（M9.5）"
cd "$REPO" || exit 1

m95_brief() { # <ID> <phase|->：最小任务书（头块与 PM 的模板同形）
  mkdir -p "$REPO/docs/team/tasks"
  { printf '# %s · smoke M9.5 fixture\n\ntask:   %s\nagent:  dev\n' "$1" "$1"
    [ "$2" = "-" ] || printf 'phase:  %s\n' "$2"
    printf 'change: -\ndeps:   -\nstatus: todo\n'; } > "$REPO/docs/team/tasks/$1-m95-smoke.md"
}
m95_add() { # <ID> <phase|->：BOARD 行 + 任务书（看板保持 wip：M9.4 的「已裁决不列」不会插进来）
  $TEAM board add "$1" "M9.5 fixture $1" dev - >/dev/null 2>&1 || true
  m95_brief "$1" "$2"
  $TEAM board set "$1" wip >/dev/null 2>&1 || true
}
m95_report() { # <ID>：任务报告（主工作树；标题让 team_report_is_task 认得）
  mkdir -p "$REPO/docs/team/reports"
  printf '# %s · smoke M9.5 fixture\n\nagent:  dev   状态: DONE\n\n## 交付物\n- fixture（只关心待复验清单怎么判它）\n' \
    "$1" > "$REPO/docs/team/reports/$1-dev.md"
}
m95_lib() { # <函数> [参数…]：在夹具仓库里按 CLI 的方式加载库后调用（digest 用的是同一批函数）
  local fn="$1"; shift
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$fn"' "$@"' _ "$@" )
}
m95_head()        { m95_lib team_review_record_head   "$1"; }   # 记录绑定的 revision（9 位）
m95_note()        { m95_lib team_review_record_note   "$1"; }   # digest 读的 staleness 标记
m95_old_subject() { m95_lib team_review_branch_tip "$1"; }      # 旧判据 = 任务分支当前 tip（M6.2）
m95_pending()     { m95_lib team_reports_pending_list; }
m95_commit() { # <工作树> <提交信息>：夹具提交（作者固定，不碰仓库/全局 git 配置）
  git -C "$1" add -A >/dev/null 2>&1 || true
  git -C "$1" -c user.email=smoke@local -c user.name=smoke commit -qm "$2" >/dev/null 2>&1 || true
}
m95_wt_remove() { git -C "$REPO" worktree remove --force "$1" >/dev/null 2>&1 || true; }

# ① verify：记录绑定被验分支 X，复验者自己的分支 Y（它把报告提交在这里）≠ X → 不算过期
V95X_BR="task/P95A-reviewed"        # 被验分支（记录抬头 `分支:`）
V95Y_BR="task/V95A-verify-report"   # 复验者自己的分支（旧判据会命中它）
V95X_WT="$TMP/m95-x-wt"; V95Y_WT="$TMP/m95-y-wt"; V95X_CO="$TMP/m95-x-checkout"
m95_wt_remove "$V95X_WT"; m95_wt_remove "$V95Y_WT"; m95_wt_remove "$V95X_CO"
git -C "$REPO" branch -D "$V95X_BR" "$V95Y_BR" >/dev/null 2>&1 || true
m95_add V95A verify
m95_report V95A
git -C "$REPO" worktree add -q -b "$V95X_BR" "$V95X_WT" "$PROTECTED" \
  && ok "M9.5-①现场：被验分支 X 就绪" || bad "M9.5-①现场：建不出被验分支 X"
printf 'the revision that was reviewed\n' > "$V95X_WT/impl.txt"
m95_commit "$V95X_WT" "feat(P95A): the reviewed revision"
git -C "$REPO" worktree add -q -b "$V95Y_BR" "$V95Y_WT" "$V95X_BR"
printf 'verifier own-branch note (report commit)\n' > "$V95Y_WT/own-branch.txt"
m95_commit "$V95Y_WT" "docs(V95A): the verifier's own commit on its branch"
git -C "$REPO" worktree add -q --detach "$V95X_CO" "$V95X_BR"
( cd "$REPO" && $TEAM review V95A --dir "$V95X_CO" --branch "$V95X_BR" ) >"$TMP/m95-a-review.log" 2>&1 \
  && ok "M9.5-①现场：被验分支上写出一条 PASS 记录" || bad "M9.5-①现场：review 失败（见 $TMP/m95-a-review.log）"
assert_has "$REPO/docs/team/reviews/V95A.md" "判定: **PASS**" "M9.5-①记录判定 PASS（staleness 判定会继续往下走）"
V95A_REC="$(m95_head V95A)"; V95A_X="$(git -C "$REPO" rev-parse --short=9 "$V95X_BR")"; V95A_Y="$(git -C "$REPO" rev-parse --short=9 "$V95Y_BR")"
assert_eq "M9.5-①夹具有效：记录绑定的就是被验分支 X 的 revision" "$V95A_REC" "$V95A_X"
assert_eq "M9.5-①夹具有效：旧判据命中的是复验者自己的分支 Y" "$(m95_old_subject V95A | cut -c1-9)" "$V95A_Y"
assert_eq "M9.5-①夹具有效：Y ≠ X（旧实现一定会判 stale，测得到这次回归）" "$([ "$V95A_Y" != "$V95A_X" ] && echo yes || echo no)" "yes"
assert_eq "M9.5-①：verify 记录绑定 X、自己的分支 Y 又动了 → 不算过期" "$(m95_note V95A)" ""
m95_pending >"$TMP/m95-a-pending.log"
assert_not "$TMP/m95-a-pending.log" "V95A" "M9.5-①：不再列为待复验"
$TEAM digest >"$TMP/m95-a-digest.log" 2>&1 || true
assert_not "$TMP/m95-a-digest.log" "team review V95A" "M9.5-①：digest 也不给它 review 待办"

# ② 真信号：被验分支在记录之后又前进一格 → 仍然过期（点名两个 revision，行动照旧 team review）
printf 'a commit after the record\n' > "$V95X_WT/impl2.txt"
m95_commit "$V95X_WT" "fix(P95A): a commit after the verification record"
V95A_X2="$(git -C "$REPO" rev-parse --short=9 "$V95X_BR")"
assert_eq "M9.5-②夹具有效：被验分支确实又动了（X 新 tip ≠ 记录 HEAD）" "$([ "$V95A_X2" != "$V95A_REC" ] && echo yes || echo no)" "yes"
assert_eq "M9.5-②：被验 revision 之后又落了提交 → stale（两个 revision 都点名）" \
  "$(m95_note V95A)" "stale: verified $V95A_REC, branch now $V95A_X2"
m95_pending >"$TMP/m95-b-pending.log"
assert_has "$TMP/m95-b-pending.log" "V95A-dev [stale: verified $V95A_REC, branch now $V95A_X2]" \
  "M9.5-②：清单里点名两个 revision（真信号没被吞掉）"
$TEAM digest >"$TMP/m95-b-digest.log" 2>&1 || true
assert_has "$TMP/m95-b-digest.log" "V95A-dev [stale: verified $V95A_REC, branch now $V95A_X2]" "M9.5-②：digest 同样标出过期"
assert_has "$TMP/m95-b-digest.log" "team review V95A" "M9.5-②：digest 给出下一步"

# ②c 被验分支已合并删除（记录里的分支解析不到）→ 无法判定「又动了」，记录仍然有效
#    （与 M6.2 对已删分支的既有规则一致：解析不到不等于过期，否则合并后的任务会永远待办）
m95_wt_remove "$V95X_WT"; m95_wt_remove "$V95X_CO"
git -C "$REPO" branch -D "$V95X_BR" >/dev/null 2>&1 || true
assert_eq "M9.5-②c：被验分支已删除（解析不到）→ 不算过期" "$(m95_note V95A)" ""
m95_pending >"$TMP/m95-b2-pending.log"
assert_not "$TMP/m95-b2-pending.log" "V95A" "M9.5-②c：已删被验分支的 verify 记录不再列为待复验"

# ③ 控制组：没有 phase 的任务照旧「记录 vs 任务分支当前 tip」（M6.2/F3，行为逐字不变）
V95C_BR="task/V95C-impl"; V95C_WT="$TMP/m95-c-wt"; V95C_CO="$TMP/m95-c-checkout"
m95_wt_remove "$V95C_WT"; m95_wt_remove "$V95C_CO"
git -C "$REPO" branch -D "$V95C_BR" >/dev/null 2>&1 || true
m95_add V95C -
m95_report V95C
git -C "$REPO" worktree add -q -b "$V95C_BR" "$V95C_WT" "$PROTECTED"
printf 'code under review\n' > "$V95C_WT/code.txt"
m95_commit "$V95C_WT" "feat(V95C): the reviewed code"
git -C "$REPO" worktree add -q --detach "$V95C_CO" "$V95C_BR"
( cd "$REPO" && $TEAM review V95C --dir "$V95C_CO" --branch "$V95C_BR" ) >"$TMP/m95-c-review.log" 2>&1 \
  && ok "M9.5-③现场：代码任务写出一条 PASS 记录" || bad "M9.5-③现场：review 失败（见 $TMP/m95-c-review.log）"
V95C_REC="$(m95_head V95C)"
assert_eq "M9.5-③控制组：刚写完的记录不算过期（与改动前一致）" "$(m95_note V95C)" ""
printf 'a commit after the record\n' > "$V95C_WT/code2.txt"
m95_commit "$V95C_WT" "feat(V95C): a commit after the verification record"
V95C_TIP="$(git -C "$REPO" rev-parse --short=9 "$V95C_BR")"
assert_eq "M9.5-③控制组：任务分支又动了 → 照旧 stale（消息形状不变）" \
  "$(m95_note V95C)" "stale: verified $V95C_REC, branch now $V95C_TIP"
m95_pending >"$TMP/m95-c-pending.log"
assert_has "$TMP/m95-c-pending.log" "V95C-dev [stale: verified $V95C_REC, branch now $V95C_TIP]" "M9.5-③控制组照旧列为待复验"
# ---------------------------------------------------------------- 24. done 证据：零提交的分支不能冒充「代码落地」（M9.6）
# 契约：没声明 phase 的代码任务仍是老两条路线，但 ② 加了**报告**要求 —— 任务分支的**提交树里**要有
#   <docs>/reports/<ID>-*.md（M4.3-C：草稿不算）。根因：刚建出来、一个提交都没有的分支，tip 同样是
#   保护分支的祖先（`main..tip` 对「合并了」和「没动过」都是 0），git 分不出这两者；提交进分支的
#   报告才是「这个分支真的干过活」的形状。下面的夹具按任务书列的五个形状：空分支拒绝（点名报告）/
#   有报告未合并拒绝（点名合并）/ 草稿不算 / 报告+复验记录通过 / 已合并+报告通过（控制组），
#   外加 phase 任务不变（控制组）。纯逻辑（只读文件 + 只写夹具自己的 docs/team），快慢模式都跑。
section "24 · done 证据：② 要求分支里已提交的报告（M9.6）"
cd "$REPO" || exit 1
assert_eq "M9.6 夹具前置：主工作树停在 $PROTECTED（下面要建分支 + ff 合并）" \
  "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)" "$PROTECTED"

m96_brief() { # <ID> [phase]：最小任务书（头块字段与 PM 的模板同形）
  local id="$1" phase="${2:-}"
  mkdir -p "$REPO/docs/team/tasks"
  {
    printf '# %s · smoke M9.6 fixture\n\n```\ntask:   %s\nagent:  dev\n' "$id" "$id"
    [ -n "$phase" ] && printf 'phase:  %s\n' "$phase"
    printf 'change: -\ndeps:   -\nstatus: todo\n```\n'
  } > "$REPO/docs/team/tasks/$id-smoke.md"
}
m96_add() { # <ID> [phase]：BOARD 行 + 任务书
  $TEAM board add "$1" "M9.6 fixture $1" dev "-" >/dev/null 2>&1 || true
  m96_brief "$1" "${2:-}"
}
m96_done() { # <ID> → 打印 done 的退出码（0=过闸），日志留在 $TMP/m96-<ID>.log
  # TEAM_SPEC_DIR 显式钉成 openspec：本文件更早的第 15b 节往夹具仓库的 config.sh 里追加过绝对路径的
  # spec 目录；不钉住的话下面那条 phase 控制组测的就不是「阶段证据」而是那份残留配置。
  if env TEAM_BOARD_DONE_FORCE=0 TEAM_SPEC_DIR=openspec $TEAM board set "$1" done >"$TMP/m96-$1.log" 2>&1; then
    printf '0\n'
  else
    printf '1\n'
  fi
}
m96_branch() { # <branch> <ID> [--merge]：建分支并在分支上**提交**一份报告；--merge 再 ff 进保护分支
  local br="$1" id="$2" merge="${3:-}" wt="$TMP/m96-wt-$2"
  git -C "$REPO" worktree remove --force "$wt" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$br" >/dev/null 2>&1 || true
  git -C "$REPO" worktree add -q -b "$br" "$wt" "$PROTECTED"
  mkdir -p "$wt/docs/team/reports"
  printf '# %s · smoke M9.6 report\n\nreport fixture\n' "$id" > "$wt/docs/team/reports/$id-dev.md"
  git -C "$wt" add -- "docs/team/reports/$id-dev.md" >/dev/null 2>&1
  git -C "$wt" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "docs($id): report (M9.6 fixture)" >/dev/null 2>&1
  git -C "$REPO" worktree remove --force "$wt" >/dev/null 2>&1 || true
  if [ "$merge" = "--merge" ]; then
    git -C "$REPO" merge -q --ff-only "$br" >/dev/null 2>&1 \
      && ok "M9.6 夹具：$br 已 fast-forward 进 $PROTECTED（合并控制组的前置）" \
      || bad "M9.6 夹具：$br 没能 fast-forward 进 $PROTECTED"
  fi
}

# ① 形状一：刚建出来的空分支（零提交，旧实现的假绿：自称「代码真的落地了」）
m96_add M96A
git -C "$REPO" branch task/M96A-fresh "$PROTECTED" >/dev/null 2>&1
assert_eq "M9.6-①：零提交的空分支 → 拒绝" "$(m96_done M96A)" "1"
assert_has "$TMP/m96-M96A.log" "reports/M96A-*.md" "拒绝信息点名缺的是那份报告"
assert_has "$TMP/m96-M96A.log" "一个提交都没有的分支" "拒绝信息解释零提交分支的形状"
assert_not "$TMP/m96-M96A.log" "代码真的落地了" "空分支不再被说成「代码真的落地了」"
assert_eq "M9.6-①：被拒后 BOARD 没动" "$(board_status M96A)" "todo"
assert_not_file "$REPO/docs/team/reviews/M96A-done.md" "M9.6-①：被拒时不写 done 审计"

# ② 形状二：分支上**提交了**报告，但还没并进保护分支 → 拒绝（缺的是合并这一层，不是报告）
m96_add M96B
m96_branch task/M96B-unmerged M96B
assert_eq "M9.6-②：报告已提交、但分支还没合并 → 拒绝" "$(m96_done M96B)" "1"
assert_has "$TMP/m96-M96B.log" "提交还不在里面" "拒绝信息点名缺的是「并入保护分支」"
assert_not "$TMP/m96-M96B.log" "但它的提交里没有报告" "报告没问题时不再喊缺报告（三个层次分得开）"

# ③ 形状三：报告只躺在工作区（草稿，未提交）→ 拒绝：git 里只有提交算交付（M4.3-C 的规则）
m96_add M96C
mkdir -p "$REPO/docs/team/reports"
printf '# M96C · smoke draft\n' > "$REPO/docs/team/reports/M96C-dev.md"
git -C "$REPO" branch task/M96C-draft "$PROTECTED" >/dev/null 2>&1
assert_eq "M9.6-③：报告只是工作区草稿（未提交）→ 拒绝" "$(m96_done M96C)" "1"
assert_has "$TMP/m96-M96C.log" "工作区里的草稿不算" "拒绝信息解释草稿为什么不算"
assert_has "$TMP/m96-M96C.log" "reports/M96C-*.md" "草稿不算的同时仍然点名要找的那份报告"
rm -f "$REPO/docs/team/reports/M96C-dev.md"

# ④ 形状四：报告已提交 + 复验记录（判定 PASS，分支没合并）→ 允许（① 路线不因 ② 的新要求变难）
m96_add M96D
m96_branch task/M96D-review M96D
mkdir -p "$REPO/docs/team/reviews"
printf '# M96D · smoke review\n\n时间: 2026-09-15T00:00:00Z · 判定: **PASS**\n' > "$REPO/docs/team/reviews/M96D.md"
assert_eq "M9.6-④：报告 + PASS 复验记录（分支未合并）→ 允许 done" "$(m96_done M96D)" "0"
assert_has "$TMP/m96-M96D.log" "判定 PASS" "成功输出说明用的是复验记录"

# ⑤ 形状五（控制组）：报告已提交 + 分支已并入保护分支 → 允许 done（正对照，扫旧分支不误伤真交付）
m96_add M96E
m96_branch task/M96E-merged M96E --merge
assert_eq "M9.6-⑤（控制组）：已合并的分支 + 报告 → 允许 done" "$(m96_done M96E)" "0"
assert_has "$TMP/m96-M96E.log" "已经是 main 的祖先" "成功输出写明合并这一层"
assert_has "$TMP/m96-M96E.log" "M96E-dev.md" "成功输出点名分支里那份已提交的报告"
assert_has "$REPO/docs/team/reviews/M96E-done.md" "M96E-dev.md" "done 审计记下当时核对到的那份报告"

# ⑥ 控制组：声明了 phase 的任务规则不变 —— 阶段证据（explore 的 DECISIONS 标题条目）照样解锁，
#    哪怕它的分支是零提交的空分支（报告要求只加在代码任务的 ② 上，不得施加到阶段路线）
m96_add M96F explore
git -C "$REPO" branch task/M96F-phase "$PROTECTED" >/dev/null 2>&1
assert_eq "M9.6-⑥（控制组）：phase=explore 还没有接受记录 → 仍然拒绝" "$(m96_done M96F)" "1"
assert_has "$TMP/m96-M96F.log" "阶段 explore 的交付" "phase 任务的拒绝信息仍给阶段路线"
printf '\n## D96 · smoke — accept M96F exploration\n\n- **决策**：接受 M96F 的探索结论。\n' >> "$REPO/docs/team/DECISIONS.md"
assert_eq "M9.6-⑥（控制组）：阶段证据到位 → 允许 done（报告要求不施加在阶段任务上）" "$(m96_done M96F)" "0"
assert_has "$TMP/m96-M96F.log" "PM 接受记录" "成功输出说明用的是阶段证据（不是代码路线）"

# ---------------------------------------------------------------- 25. 唤醒计数 = digest 的可行动列表（M9.8）
# 契约（真实假信号：watchdog 的唤醒理由「待复验 6」，而同一时刻 digest [3] 的清单是空的）：
#   ① 「待复验 N」就是 digest [3] **可行动**列表的行数 —— 同一个函数、同一套过滤
#      （看板 done/closed 跳过、草稿标注但不计数、verify 按绑定 revision 判）；
#   ② 草稿（agent 工作树里没提交的报告）仍然列在 digest [3]（标注「未提交」）但**不**叫醒 PM ——
#      PM 现在动不了它；
#   ③ 真有 1 份待复验 / 有未读通知 / 有 blocked 行 / 有任务但 agent 停了 → 照旧叫醒（对照）；
#   ④ 长命巡检进程的代码快照过期时，判定必须切到磁盘上的代码：现场是 watchdog 窗口里跑着前一天
#      14:12 起来的 v1.19.0（内存里还是旧规则），而 digest 是新进程。
# 全部在自己的临时仓库里跑（先证明身份），快慢模式都跑。
section "25 · 唤醒计数 = digest 的可行动列表（M9.8）"

M98="$TMP/m98repo"; rm -rf "$M98"; mkdir -p "$M98"
( cd "$M98" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m98' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
M98SES="teamsmith-smoke-m98-$$"
( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$M98SES" --agents dev --vcs local --gates "true" --docs docs/team ) >"$TMP/m98-init.log" 2>&1 \
  && ok "M9.8 夹具仓库 init 成功" || bad "M9.8 夹具仓库 init 失败（见 $TMP/m98-init.log）"
( cd "$M98" && git add -A && git commit -qm "chore: m98 init" ) >/dev/null 2>&1

# 身份隔离（M7.2 纪律）：**写盘之前**先证明 team 认的是这个临时仓库 + 这个临时 session
( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/m98-paths.json" 2>&1 || true
assert_eq "M9.8 隔离：team paths 的 main_root 就是 M9.8 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m98-paths.json")" "$M98"
assert_has "$TMP/m98-paths.json" "\"session\": \"$M98SES\"" "M9.8 隔离：身份用的是本轮临时 session"

m98() { ( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
m98_lib() { # <函数> [参数…]：按 CLI 的方式加载库后调用（digest 与唤醒读的是同一批函数）
  local fn="$1"; shift
  ( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$fn"' "$@"' _ "$@" )
}
m98_brief() { # <ID>：最小任务书（头块与 PM 的模板同形）
  mkdir -p "$M98/docs/team/tasks"
  printf '# %s · smoke M9.8 fixture\n\ntask:   %s\nagent:  dev\ndeps:   -\nstatus: todo\n' "$1" "$1" \
    > "$M98/docs/team/tasks/$1-m98-smoke.md"
}
m98_report() { # <ID> [目录]
  local dir="${2:-$M98/docs/team/reports}"
  mkdir -p "$dir"
  printf '# %s · smoke M9.8 fixture\n\nagent:  dev   状态: DONE\n\n## 交付物\n- fixture（只关心它在待复验清单/唤醒计数里的样子）\n' \
    "$1" > "$dir/$1-dev.md"
}
m98_add() { # <ID>：BOARD 行 + 任务书 + 已提交报告（主工作树里）
  m98 $TEAM board add "$1" "M9.8 fixture $1" dev - >/dev/null 2>&1 || true
  m98_brief "$1"; m98_report "$1"
}
m98_done() { # <ID>：看板标 done（没有复验记录 → 用 PM 的显式覆盖，形状与 P1 现场一致）
  m98 env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="smoke M9.8 fixture" $TEAM board set "$1" done >/dev/null 2>&1 || true
}
m98_count()      { m98_lib team_reports_pending; }                     # 唤醒理由里的「待复验 N」
m98_wake()       { m98_lib team_pending_text; }                        # team_watch_once 的唤醒输入（空 = 不叫醒）
m98_actionable() { m98_lib team_reports_pending_list --actionable; }   # 可行动清单（计数的那一份）
m98_list_all()   { m98_lib team_reports_pending_list; }                # digest [3] 的那一份（含草稿）
m98_wait_log() { # <文件> <模式> [秒]：有界轮询（M9.7：不赌固定 sleep 采样过渡态）
  local f="$1" pat="$2" i=0 max="$(( ${3:-20} * 10 ))"
  while [ "$i" -lt "$max" ]; do grep -q -- "$pat" "$f" 2>/dev/null && return 0; sleep 0.1; i=$((i + 1)); done
  return 1
}

# ① 5 份「看板已 done」的报告 + 0 未读 → **不叫醒**
for i in A B C D E; do m98_add "M98$i"; m98_done "M98$i"; done
M98_DONE_OK=0
for i in A B C D E; do [ "$(m98_lib team_board_status "M98$i")" = "done" ] && M98_DONE_OK=$((M98_DONE_OK + 1)); done
assert_eq "M9.8-①夹具有效：5 份报告 + 看板 done" "$M98_DONE_OK" "5"
assert_eq "M9.8-①：看板已裁决的 5 份不计入唤醒（待复验 0）" "$(m98_count)" "0"
assert_eq "M9.8-①：唤醒理由为空 → 不叫醒 PM" "$(m98_wake)" ""
assert_eq "M9.8-①：可行动清单也是空（计数与清单同源）" "$(m98_actionable | wc -l | tr -d ' ')" "0"
m98 $TEAM watch --once >"$TMP/m98-a-watch.log" 2>&1 || bad "M9.8-①：watch --once 失败（见 $TMP/m98-a-watch.log）"
assert_has "$TMP/m98-a-watch.log" "无待办" "M9.8-①：这一拍明确说「无待办：不叫醒 PM」"
assert_not "$TMP/m98-a-watch.log" "有待办" "M9.8-①：没有把看板 done 的报告当成待办"
m98 $TEAM digest >"$TMP/m98-a-digest.log" 2>&1 || true
assert_has "$TMP/m98-a-digest.log" "已按看板跳过 5 份报告" "M9.8-①：digest 点名它们为什么没被列（不静默丢）"

# ② 1 份真待复验 → 叫醒（计数 = digest [3] 可行动清单的行数）
m98_add M98F
assert_eq "M9.8-②：1 份真待复验 → 待复验 1" "$(m98_count)" "1"
assert_eq "M9.8-②：唤醒理由点名「待复验 1」" "$(m98_wake)" "待复验 1"
assert_eq "M9.8-②：计数 = 可行动清单行数（同一套过滤的硬断言）" "$(m98_count)" "$(m98_actionable | wc -l | tr -d ' ')"
m98 $TEAM watch --once >"$TMP/m98-b-watch.log" 2>&1 || true
assert_has "$TMP/m98-b-watch.log" "待复验 1" "M9.8-②：这一拍按「待复验 1」判成有待办"
assert_not "$TMP/m98-b-watch.log" "无待办" "M9.8-②：真的有待办时不会说不叫醒"
m98 $TEAM digest >"$TMP/m98-b-digest.log" 2>&1 || true
assert_has "$TMP/m98-b-digest.log" "M98F-dev" "M9.8-②：digest [3] 列的就是这一份"

# ③ 未读通知 → 叫醒（对照）；唤醒理由与 digest [2] 同源
m98 $TEAM notify dev "M9.8 fixture: unread" >/dev/null 2>&1 || true
assert_eq "M9.8-③对照：未读通知进入唤醒理由" "$(m98_wake)" "未读通知 1 · 待复验 1"
m98 $TEAM digest >"$TMP/m98-c-digest.log" 2>&1 || true
assert_has "$TMP/m98-c-digest.log" "1 条新" "M9.8-③：digest [2] 与唤醒理由同源（同一个未读通知）"
m98 $TEAM watch --once >"$TMP/m98-c-watch.log" 2>&1 || true
assert_has "$TMP/m98-c-watch.log" "未读通知 1" "M9.8-③：未读通知照旧叫醒（对照）"

# ④ 草稿（agent 工作树里的未提交报告）：digest 标注但不计数 —— 标注与不计数只有一份判据
git -C "$M98" worktree add -q -b task/M98G-m98 "$M98/.worktrees/dev" "$PROTECTED" 2>/dev/null || true
m98_add M98G
mv "$M98/docs/team/reports/M98G-dev.md" "$M98/.worktrees/dev/docs/team/reports/M98G-dev.md"
assert_file "$M98/.worktrees/dev/docs/team/reports/M98G-dev.md" "M9.8-④夹具：报告只存在于 agent 工作树（草稿）"
assert_eq "M9.8-④：草稿仍列在清单里（不静默丢）" "$(m98_list_all | grep -c '^M98G' || true)" "1"
assert_eq "M9.8-④：草稿不计入唤醒（标注但不计数）" "$(m98_count)" "1"
assert_eq "M9.8-④：唤醒理由没有因草稿变多" "$(m98_wake)" "未读通知 1 · 待复验 1"
assert_eq "M9.8-④：可行动清单 = 唤醒计数的同一套过滤" "$(m98_actionable | wc -l | tr -d ' ')" "$(m98_count)"
m98 $TEAM digest >"$TMP/m98-d-digest.log" 2>&1 || true
assert_has "$TMP/m98-d-digest.log" "M98G-dev" "M9.8-④：digest [3] 仍然列出草稿"
assert_has "$TMP/m98-d-digest.log" "report 未提交" "M9.8-④：digest [3] 把草稿标注成「未提交」"
assert_not "$TMP/m98-d-digest.log" "team review M98G" "M9.8-④：草稿不给 review 待办（还没交付）"

# ⑤ 其它唤醒理由与 digest 的口径同源：blocked 行 / 有任务但 agent 停了（[5] 任务板与建议）
m98 $TEAM board set M98F blocked >/dev/null 2>&1 || true
assert_eq "M9.8-⑤：blocked 看板行进唤醒理由" "$(m98_wake)" "未读通知 1 · 待复验 1 · blocked 1 · 需 PM 处理"
m98_lib team_state_set dev task M98F >/dev/null 2>&1 || true
assert_eq "M9.8-⑤：有任务但窗口不在的 agent 也进唤醒理由" "$(m98_wake)" "未读通知 1 · 待复验 1 · blocked 1 · 需 PM 处理 · 停了的 agent 1（dev=unknown）"
m98 $TEAM digest >"$TMP/m98-e-digest.log" 2>&1 || true
assert_has "$TMP/m98-e-digest.log" "blocked=1" "M9.8-⑤：digest [5] 的看板计数与唤醒理由同源（blocked）"
assert_has "$TMP/m98-e-digest.log" "M98F" "M9.8-⑤：digest [5] 里能看到那行 blocked"
assert_has "$TMP/m98-e-digest.log" "未在跑但仍有任务 M98F" "M9.8-⑤：digest [5] 建议与「停了的 agent」同源"

# ⑥ 长命巡检进程的代码快照：磁盘代码变了 → 用自己的新代码重启（现场：窗口里跑前一天的 v1.19.0）
#    判据钉的是**决策**而不是「第二个版本标记」：基线是「无待办」（5 份看板 done + 0 未读），随后把
#    **能改变决策的**新规则写进磁盘（可行动清单永远有 1 行）。进程若会重读磁盘代码 → 下一拍必然出现
#    「待复验 1」；进程若按内存旧快照跑 → 永远停在「无待办」。用第二个夹具仓库（$M98B）：上一段的
#    $M98 到这里已经有 blocked/草稿/未读，「待复验 1」会撞字符串、决策变化就测不出来。
#    先等日志行再写第二个标记的那种写法有个 M9.7 式竞态（日志行先于 exec 落盘），这里不赌它。
M98B="$TMP/m98repo2"; rm -rf "$M98B"; mkdir -p "$M98B"
( cd "$M98B" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m98b' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
( cd "$M98B" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "teamsmith-smoke-m98b-$$" --agents dev --vcs local --gates "true" --docs docs/team ) >"$TMP/m98b-init.log" 2>&1
( cd "$M98B" && git add -A && git commit -qm "chore: m98b init" ) >/dev/null 2>&1
m98b() { ( cd "$M98B" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
for i in A B C D E; do
  m98b $TEAM board add "M98$i" "M9.8 fixture" dev - >/dev/null 2>&1 || true
  mkdir -p "$M98B/docs/team/tasks" "$M98B/docs/team/reports"
  printf '# %s · smoke M9.8 fixture\n\ntask:   %s\nagent:  dev\ndeps:   -\nstatus: todo\n' "M98$i" "M98$i" \
    > "$M98B/docs/team/tasks/M98$i-m98.md"
  printf '# %s · smoke M9.8 fixture\n\nagent:  dev   状态: DONE\n' "M98$i" > "$M98B/docs/team/reports/M98$i-dev.md"
  m98b env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON=fx $TEAM board set "M98$i" done >/dev/null 2>&1 || true
done
M98COPY="$TMP/m98-skill"; rm -rf "$M98COPY"; cp -r "$SKILL_DIR" "$M98COPY"
M98B_WDLOG="$M98B/.pi/team/state/watchdog.log"
( cd "$M98B" && exec env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    TEAM_PULSE_INTERVAL=1 bash "$M98COPY/scripts/team" monitor --interval 1 ) >"$TMP/m98-monitor.log" 2>&1 &
M98MON=$!
# P10 起面板是 Ink 进程（panel.js），tick 是它每次派生的 `team watch --once` 子进程：
# 所以「磁盘代码变了」这件事由**新起的 tick 进程**自动生效，不需要（也不应该）重启面板循环。
if m98_wait_log "$TMP/m98-monitor.log" "teamsmith pulse" 20; then ok "M9.8-⑥：夹具面板进程起来了（已渲染）"
else bad "M9.8-⑥：夹具面板进程没起来"; fi
if m98_wait_log "$M98B_WDLOG" "无待办" 20; then ok "M9.8-⑥：第一拍 5 份看板 done → 无待办（不叫醒）"
else bad "M9.8-⑥：第一拍没有写出「无待办」（基线不对：$(tail -1 "$M98B_WDLOG" 2>/dev/null)）"; fi
assert_not "$M98B_WDLOG" "代码快照过期" "M9.8-⑥控制组：代码没变时不重启面板循环"
printf '\nteam_reports_pending_list() { printf "DRIFT\tDRIFT\t/tmp/drift.md\n"; }\n' >> "$M98COPY/scripts/lib/cmd-status.sh"
if m98_wait_log "$M98B_WDLOG" "待复验 1" 25; then
  ok "M9.8-⑥：磁盘代码变了 → 下一拍 tick 用**磁盘上的代码**重判（日志里出现「待复验 1」）"
else bad "M9.8-⑥：磁盘代码变了 25s 仍按旧代码判定（「待复验 1」没出现）—— 唤醒理由会比 digest 旧"; fi
assert_not "$M98B_WDLOG" "代码快照过期" "M9.8-⑥：判定每次 tick 都是新进程（面板循环不必为自己重启）"
kill -0 "$M98MON" 2>/dev/null && ok "M9.8-⑥：巡检循环还在跑（窗口不被拆掉）" || bad "M9.8-⑥：巡检进程没了"
kill "$M98MON" 2>/dev/null || true
wait "$M98MON" 2>/dev/null || true

# ⑦ exec 重启不换 PID → 锁必须认自己（否则重启后的 watchdog 会拒绝启动、巡检整条死掉）
m98_lock_rc() { # <self|pid>：把锁文件写成自己/给定的 pid，调用 team_watch_lock，输出退出码
  ( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1
               case "${1:-}" in self) printf "%s\n" "$$" ;; *) printf "%s\n" "$1" ;; esac > "$TEAM_STATE_DIR/watchdog.pid"
               if team_watch_lock >/dev/null 2>&1; then echo 0; else echo 1; fi' _ "$1" )
}
assert_eq "M9.8-⑦：锁认自己（exec 重启后 PID 不变 → 不能拒绝启动）" "$(m98_lock_rc self)" "0"
# 对照片用的是**本轮 smoke 自己的 PID**（一定活着且我们有权发信号）：pid 1 不能当夹具 ——
# 非 root 对它 kill -0 会因 EPERM 失败，于是「活着的进程」会被误看成陈旧 pid（老实现的同一个坑）。
assert_eq "M9.8-⑦对照：别人（活着的进程）持锁仍然拒绝" "$(m98_lock_rc $$)" "1"
assert_eq "M9.8-⑦对照：陈旧的 pid 文件不阻塞（旧行为不变）" "$(m98_lock_rc 99999999)" "0"

# ---- ⑧ P109（--actionable 的第二条「PM 动不了」判据）：看板 todo|wip 且**归属席位在跑**的报告
#      = 作者还在写（2026-09-28 现场：同一形状每 TEAM_PULSE_NUDGE_GAP 把 PM 叫醒一次，而 PM 无事可做）。
#      计入口径（--actionable）不数它；digest [3] 的全量清单照旧列（显示口径不动）。席位停跑 /
#      判不出归属 → 照旧计数（那才是真待办：PM 要 team resume）。这里没有真 tmux（FAST 也要跑）：
#      存活用夹具显式名单替换 team_agent_live —— 真判据由 §6k（M37）独立钉住；本节钉的是新过滤的接线。
P109_LIVE=""; P109_MUT=""
p109_lib() { # <函数> [参数…]：同 m98_lib 的加载；存活 = P109_LIVE 名单；P109_MUT 非空 = 源变体库
  local fn="$1"; shift
  ( cd "$M98" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      P109_LIVE="$P109_LIVE" P109_MUT="$P109_MUT" \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"
        for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do
          if [ -n "${P109_MUT:-}" ] && [ "${_f##*/}" = "cmd-status.sh" ]; then . "$P109_MUT"; continue; fi
          . "$_f" 2>/dev/null || true
        done
        team_load_config >/dev/null 2>&1
        team_agent_live() { case " ${P109_LIVE:-} " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
        '"$fn"' "$@"' _ "$@" )
}
p109_act() { p109_lib team_reports_pending_list --actionable; }   # 唤醒计数/可行动清单的那一份
p109_all() { p109_lib team_reports_pending_list; }                # digest [3] 的全量那一份
p109_n()   { awk -F'\t' -v id="$1" '$1==id{n++} END{print n+0}' <<< "${2:-}"; }

# 夹具：M98G1 = 现场形状（dev 工作树正本（已提交）+ 看板 wip + state task=dev）；
#       M98G2 = 对照（同为 wip，但归属是名册外的 dev2 —— 有别的席位活着不算，得是**归属**席位）。
m98_add M98G1
mv "$M98/docs/team/reports/M98G1-dev.md" "$M98/.worktrees/dev/docs/team/reports/M98G1-dev.md"
git -C "$M98/.worktrees/dev" add -- docs/team/reports/M98G1-dev.md >/dev/null 2>&1 \
  && git -C "$M98/.worktrees/dev" commit -qm "docs(M98G1): P109 fixture report" >/dev/null 2>&1
m98 $TEAM board set M98G1 wip >/dev/null 2>&1 || true
m98 $TEAM board add M98G2 "P109 fixture（非归属席位）" dev2 - >/dev/null 2>&1 || true
m98_brief M98G2
printf '# M98G2 · smoke P109 fixture\n\nagent: dev2   状态: DONE\n' > "$M98/docs/team/reports/M98G2-dev2.md"
m98 $TEAM board set M98G2 wip >/dev/null 2>&1 || true
m98_lib team_state_set dev task M98G1 >/dev/null 2>&1 || true

# 绿：归属席位（dev）在跑 → M98G1 不进可行动清单；非归属的 M98G2 照旧计入（对照）
P109_LIVE="dev"
P109_ACT_LIVE="$(p109_act)"
assert_eq "P109 ⑧：wip + 归属席位在跑 → 不计数（可行动清单里没有它）" "$(p109_n M98G1 "$P109_ACT_LIVE")" "0"
assert_eq "P109 ⑧对照：活着的席位不是它的归属 → 该报告照旧计数" "$(p109_n M98G2 "$P109_ACT_LIVE")" "1"
P109_N_LIVE="$(printf '%s\n' "$P109_ACT_LIVE" | grep -c .)"
assert_eq "P109 ⑧：可行动计数与清单行数同源" "$(p109_lib team_reports_pending)" "$P109_N_LIVE"

# 反例（必须保留）：同一份报告、席位停跑 → 回到可行动清单/计数（真待办：PM 要 team resume）
P109_LIVE=""
P109_ACT_STOP="$(p109_act)"
assert_eq "P109 ⑧：席位停跑 → 同一份报告回到可行动清单（不静默）" "$(p109_n M98G1 "$P109_ACT_STOP")" "1"
P109_N_STOP="$(printf '%s\n' "$P109_ACT_STOP" | grep -c .)"
assert_eq "P109 ⑧：绿档比停跑档少这一条（Δ=1）" "$((P109_N_STOP - P109_N_LIVE))" "1"
P109_REAL="$(m98_count)"   # 真 team_agent_live：夹具里 dev 没有真窗口 → 应停在「停跑」这一侧
assert_eq "P109 ⑧：真判据（无窗口）与夹具停跑档同值（新判据没有改变「席位没跑」的行为）" "$P109_REAL" "$P109_N_STOP"
printf '  \033[2m·\033[0m P109 原始计数（--actionable）：可行动行数 归属在跑=%s ｜ 停跑=%s（真 CLI 同值）\n' "$P109_N_LIVE" "$P109_N_STOP"

# 显示口径不动：digest [3] 的全量清单照旧列出在飞报告；草稿/done 行为不变
P109_LIVE="dev"
P109_ALL="$(p109_all)"
assert_eq "P109 ⑧：digest 全量清单照旧列出在飞报告（显示口径不动）" "$(p109_n M98G1 "$P109_ALL")" "1"
assert_eq "P109 ⑧：草稿（M98G）全量清单照旧列出" "$(p109_n M98G "$P109_ALL")" "1"
assert_eq "P109 ⑧：草稿（M98G）可行动清单照旧不数（行为不变）" "$(p109_n M98G "$P109_ACT_LIVE")" "0"
assert_eq "P109 ⑧：看板 done 的报告不在全量清单里（行为不变）" "$(p109_n M98A "$P109_ALL")" "0"
m98 $TEAM digest >"$TMP/p109-digest.log" 2>&1 || true
assert_has "$TMP/p109-digest.log" "M98G1-dev" "P109 ⑧：digest [3] 仍然列出这份在飞报告（只是不叫醒）"
assert_has "$TMP/p109-digest.log" "team review M98G1" "P109 ⑧：digest [3] 仍然给出 review 待办（显示口径不变）"

# 红侧：把**交付的** cmd-status.sh 复制一份、在末尾追加「新判据影子掉」的定义 —— 同一套加载、同一个夹具：
# wip+在跑 的那份报告必须重新进入计数（证明上面的绿断言咬的正是这条新判据，不是别的东西在挡）。
P109_MUT_FILE="$TMP/p109-cmd-status-shadow.sh"
{ cat "$SKILL_DIR/scripts/lib/cmd-status.sh"
  printf '\n# P109 red-side：把新判据影子掉（永远说「归属席位没在跑」）\nteam_report_seat_live() { return 1; }\n'
} > "$P109_MUT_FILE"
P109_LIVE="dev"; P109_MUT="$P109_MUT_FILE"
P109_MUT_ACT="$(p109_act)"
P109_MUT_TOTAL="$(p109_lib team_reports_pending)"
assert_eq "P109 ⑧红侧：影子掉新判据 → wip+在跑 又计数（绿断言咬的就是这条）" "$(p109_n M98G1 "$P109_MUT_ACT")" "1"
assert_eq "P109 ⑧红侧：可行动计数回到停跑档（影子后新判据不再生效）" "$P109_MUT_TOTAL" "$P109_N_STOP"
printf '  \033[2m·\033[0m P109 红侧原始计数：影子后 M98G1 回到清单=%s ｜ 可行动行数=%s（= 停跑档）\n' \
  "$(p109_n M98G1 "$P109_MUT_ACT")" "$P109_MUT_TOTAL"
P109_MUT=""

# 隔离证据（M7.2 纪律）：夹具的痕迹不得出现在真实账本里。用**内容签名**判定，不做前后 hash 对比 ——
# 真实 watchdog 每 15 分钟自己就会写 state/**，hash 对比会把它的正常写入误判成夹具泄漏。
M98_REAL_MAIN="$(dirname "$(git -C "$SKILL_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$SKILL_DIR" rev-parse --show-toplevel)")"
M98_PHANTOM="$(real_ledger_hits "M98[.A-G]|$M98SES" "$M98_REAL_MAIN")"
if [ -n "$M98_PHANTOM" ]; then bad "M9.8 隔离：夹具的痕迹出现在真实账本里：$(printf '%s' "$M98_PHANTOM" | tr '\n' ' ')"
else ok "M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹"; fi

# ---------------------------------------------------------------- 15. 结束
# ---------------------------------------------------------------- 26. 面板（pulse-tui-panel，P10）
# 契约来源：openspec/changes/pulse-tui-panel/specs/panel/spec.md（12 需求 / 33 场景）。
# 分段：26-a bundle / 26-b 观察者不写 state / 26-c 纯文本契约 / 26-d JSON 形状 /
#      26-e 布局与降级 / 26-f 状态带字段 / 26-g agent 表字段 / 26-h 活动列 / 26-i 显示安全 /
#      26-j 队列只读 / 26-k 运行时失败 / 26-l 隔离 / 26-n tick（headless）/ 26-m 真 pane（HAVE_TMUX 且非 FAST）。
section "26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离）"

P10R="$TMP/p10-repo"
P10SESS="teamsmith-smoke-p10-$$"
P10_HOME="$TMP/p10-home"
mkdir -p "$P10R"
( cd "$P10R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo "# p10" > README.md && git add -A && git commit -qm init )
p10() { ( cd "$P10R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
            -u TEAM_PULSE_WINDOW -u TEAM_WATCH_WINDOW -u TEAM_STATE_DIR -u TEAM_JS_BIN -u TEAM_REQUIRE_JS "$@" ); }
p10 $TEAM init --session "$P10SESS" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$TMP/p10-init.log" 2>&1 \
  && ok "26 夹具：沙盒 init 退出码 0" || { bad "26 夹具：init 失败"; tail -3 "$TMP/p10-init.log"; }
mkdir -p "$P10R/openspec"

# 面板字段夹具：待办 1/2/1/4（未读 1 · 待复验 2 · blocked 1）、40 条容量采样、8 行动作日志
P10STATE="$P10R/.pi/team/state"
mkdir -p "$P10STATE" "$P10R/docs/team/reports" "$P10R/docs/team/tasks" "$P10R/docs/team/inbox"
for i in $(seq 1 40); do
  printf '2026-01-01T00:00:%02dZ RAM 可用 %sMB ｜ 磁盘 swap 空闲 31306MB，zram 用 50%%/物理 6145MB ｜ 估算可再加 5 个 agent\n' \
    "$i" "$((4000 + i))" >> "$P10STATE/capacity.log"
done
for i in $(seq 1 8); do printf '2026-01-01T00:00:%02dZ 第 %s 行动作\n' "$i" "$i" >> "$P10STATE/watchdog.log"; done
printf 'P10 未读通知一行\n' > "$P10R/docs/team/inbox/dev.md"
p10 $TEAM board add P10X "P10 夹具报告" dev - >/dev/null 2>&1 || true
p10 $TEAM board add P10Y "P10 夹具报告" dev - >/dev/null 2>&1 || true
p10 $TEAM board add P10B "P10 夹具阻塞行" dev - >/dev/null 2>&1 || true
printf '# P10X · 夹具\n\nagent: dev\n' > "$P10R/docs/team/reports/P10X-dev.md"
printf '# P10Y · 夹具\n\nagent: dev\n' > "$P10R/docs/team/reports/P10Y-dev.md"
p10 $TEAM board set P10B blocked >/dev/null 2>&1 || true
# dev 的 worktree：任务分支 + 1 个未提交文件 + 3 个提交（领先保护分支）
( cd "$P10R" && git worktree add -q -b task/P10X-fix .worktrees/dev main ) >/dev/null 2>&1 || true
P10WT="$P10R/.worktrees/dev"
if [ -d "$P10WT" ]; then
  ( cd "$P10WT" && for i in 1 2 3; do echo "c$i" >> "$P10WT/f$i.txt"; git add -A; git commit -qm "P10 夹具提交 $i"; done )
  echo "dirty" > "$P10WT/uncommitted.txt"
fi

# agent 会话夹具：Pi 的会话目录（bash 的 token 估算与 monitor.mjs 看到同一份）
P10_SAFE="$(printf '%s' "$P10WT" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
P10_SESSDIR="$P10_HOME/.pi/agent/sessions/--$P10_SAFE--"
mkdir -p "$P10_SESSDIR"
P10_START="$(date -u -d '-1 hour 5 minutes' +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%S.000Z)"
{
  printf '{"type":"session","cwd":"%s","timestamp":"%s"}\n' "$P10WT" "$P10_START"
  printf '{"type":"message","timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"wrote the report"}]}}\n' "$P10_START"
} > "$P10_SESSDIR/2026-01-01T00-00-00-000Z_$P10SESS-dev.jsonl"
P10_AGENTLOG="$TMP/p10-agentlog-dev.log"
printf 'first line\nwrote the report\n' > "$P10_AGENTLOG"

# 假 tmux：pulse 会话里只有 dev 窗口（没有 pm 窗口 → PM absent）；只服务 headless 夹具
P10_SHIM="$TMP/p10-shim"; mkdir -p "$P10_SHIM"
cat > "$P10_SHIM/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\$P10_TMUX_LOG"
case "\$*" in
  *list-windows*) printf '%s\n' "\${P10_WINDOWS:-dev}" ;;
  *window_name*)  printf '%s\n' "\${P10_WINDOW:-dev}" ;;
  *has-session*)  exit 0 ;;
  *pane_current_command*) printf 'pi\n' ;;
esac
exit 0
EOF
chmod +x "$P10_SHIM/tmux"
# env 的选项必须在 NAME=VALUE 之前（GNU env 看到第一个赋值就停止解析选项）
p10clean=(-u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR
          -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_AGENT_LOG_GLOB -u TEAM_MONITOR_ACTIVITY -u TEAM_MONITOR_UI)
p10m() { ( cd "$P10R" && env "${p10clean[@]}" "PATH=$P10_SHIM:$PATH" "P10_TMUX_LOG=$TMP/p10-tmux.log" "P10_WINDOWS=dev" "P10_WINDOW=dev" \
             "HOME=$P10_HOME" "TEAM_PI_AGENT_DIR=$P10_HOME/.pi/agent" "TEAM_AGENT_LOG_GLOB=$P10_AGENTLOG" "$@" ); }
p10ms() { ( cd "$P10R" && env "${p10clean[@]}" "PATH=$P10_SHIM:$PATH" "P10_TMUX_LOG=$TMP/p10-tmux.log" "P10_WINDOWS=dev" "P10_WINDOW=dev" \
             "HOME=$P10_HOME" "TEAM_PI_AGENT_DIR=$P10_HOME/.pi/agent" "$@" ); }

p10_py() { # <json 文件> <python 表达式>（d=整个对象，p=d["panel"]）
  python3 - "$1" "$2" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
p = d["panel"]
sys.exit(0 if eval(sys.argv[2]) else 1)
PY
}
p10_check() { # <json 文件> <表达式> <说明>
  if p10_py "$1" "$2" 2>"$TMP/p10-py.err"; then ok "$3"
  else bad "$3（python: $(tail -1 "$TMP/p10-py.err" 2>/dev/null | head -c 160)）"; fi
}
p10_esc() { tr -cd '\033' < "$1" | wc -c | tr -d ' '; }
# 帧必须非空：否则后面那些「不该出现」的断言会在空文件上假绿
p10_frame_ok() { # <文件> <说明>
  if grep -q 'teamsmith pulse' "$1" 2>/dev/null; then ok "$2"
  else bad "$2（$1 是空文件，「不该出现」类断言会空跑）"; fi
}

# 隔离（M7.2）：写之前先证明 team paths 指向沙盒
if printf '%s' "$(p10 $TEAM paths 2>/dev/null || true)" | grep -qF "\"main_root\": \"$P10R\""; then
  ok "26-l 隔离：team paths 指向沙盒（$P10R）"
else
  bad "26-l 隔离：team paths 不是沙盒"
fi
P10_LEAK_SCAN() { # <根…> → 命中行
  local pats="P10 夹具阻塞行|P10Z|wrote the report|$P10SESS"
  local r
  for r in "$@"; do
    [ -n "$r" ] && [ -d "$r" ] || continue
    real_ledger_hits "$pats" "$r"
  done
}
P10_LEAK_BEFORE="$(P10_LEAK_SCAN "$SMOKE_INVOKE_ROOT" "$SMOKE_INVOKE_MAIN" | sort -u)"
# 负对照：故意造一个「真项目」，里面放夹具串 —— 扫描必须抓到（否则这条隔离断言是空的）
P10_NEG="$TMP/p10-neg"; mkdir -p "$P10_NEG/docs/team/inbox"
printf 'P10 夹具阻塞行\n' > "$P10_NEG/docs/team/inbox/leak.md"
if [ -n "$(P10_LEAK_SCAN "$P10_NEG")" ]; then ok "26-l 隔离守卫自检：故意泄漏会被抓到（负对照）"
else bad "26-l 隔离守卫自检：故意泄漏没被抓到（这条隔离断言是空的）"; fi

# ---------------------------------------------------------------- 26-a. bundle（单文件 + 无安装）
P10_COPY="$TMP/p10-copy"
mkdir -p "$P10_COPY"
cp -r "$SKILL_DIR/scripts" "$P10_COPY/scripts" 2>/dev/null || true
rm -rf "$P10_COPY/scripts/panel/node_modules"
if [ -e "$P10_COPY/scripts/panel/node_modules" ]; then
  bad "26-a bundle：拷贝里还有 node_modules（夹具没清干净）"
else
  ok "26-a bundle：夹具 checkout 里没有 node_modules"
fi
P10_NODE="$(command -v node || true)"
if [ -n "$P10_NODE" ]; then
  ( cd "$TMP" && env -u NODE_PATH "$P10_NODE" "$P10_COPY/scripts/panel/panel.js" --once --print --root "$P10R" ) \
    >"$TMP/p10-bundle.log" 2>&1
  P10_BRC=$?
  if [ "$P10_BRC" = "0" ] && grep -q 'teamsmith pulse' "$TMP/p10-bundle.log"; then
    ok "26-a bundle：仓库外 / 空 NODE_PATH / 没有 node_modules 也能跑出第一带"
  else
    bad "26-a bundle：拷贝里的 bundle 跑不起来（rc=$P10_BRC）"; tail -3 "$TMP/p10-bundle.log"
  fi
else
  cond_skip "26-a bundle 直跑" "本机没有 node（panel.js 的运行由 26-k 的 TEAM_JS_BIN 覆盖）"
fi
P10_PIN_INK="$(sed -n 's/.*"ink": *"\([^"]*\)".*/\1/p' "$SKILL_DIR/scripts/panel/package.json")"
P10_PIN_REACT="$(sed -n 's/.*"react": *"\([^"]*\)".*/\1/p' "$SKILL_DIR/scripts/panel/package.json")"
assert_has "$SKILL_DIR/scripts/panel/panel.js" "ink $P10_PIN_INK" "26-a bundle：头部点名 ink 钉住的版本"
assert_has "$SKILL_DIR/scripts/panel/panel.js" "react $P10_PIN_REACT" "26-a bundle：头部点名 react 钉住的版本"
assert_has "$SKILL_DIR/scripts/panel/panel.js" "build.sh" "26-a bundle：头部点名构建命令"
if [ -n "$JS_RUNNER" ]; then
  if "$JS_RUNNER" "$SKILL_DIR/scripts/panel/panel.js" --version 2>/dev/null | grep -q "$P10_PIN_INK"; then
    ok "26-a bundle：--version 与 package.json 的 pin 一致"
  else
    bad "26-a bundle：--version 没有报出 pin"
  fi
fi
# 可复现构建（同锁文件 + 同源 → 同字节）：在**沙盒副本**里重建，不碰工作树（smoke 不改跟踪文件）；
# 依赖装不上（无网络/无 bun）就显式跳过 —— 绝不因为「构建失败所以文件没变」而假绿。
P10_BUN=""
for c in bun "$HOME/.bun/bin/bun"; do command -v "$c" >/dev/null 2>&1 && { P10_BUN="$c"; break; }; done
if [ -n "$P10_BUN" ]; then
  P10_BLD="$TMP/p10-panel-build"; rm -rf "$P10_BLD"; mkdir -p "$P10_BLD"
  cp -r "$SKILL_DIR/scripts/panel" "$P10_BLD/panel"
  rm -rf "$P10_BLD/panel/node_modules"
  { echo "\$ $P10_BUN install --frozen-lockfile"; ( cd "$P10_BLD/panel" && "$P10_BUN" install --frozen-lockfile 2>&1 | tail -3 ); \
    echo "\$ bash build.sh"; ( cd "$P10_BLD/panel" && BUN="$P10_BUN" bash build.sh 2>&1 ); } >"$TMP/p10-build.log" 2>&1
  if grep -q 'panel.js written' "$TMP/p10-build.log"; then
    if cmp -s "$P10_BLD/panel/panel.js" "$SKILL_DIR/scripts/panel/panel.js"; then
      ok "26-a bundle：沙盒里重建逐字节一致（$(wc -c < "$SKILL_DIR/scripts/panel/panel.js" | tr -d ' ') 字节）"
    else
      bad "26-a bundle：重建后与提交的 bundle 不一致（源与产物漂了）"; tail -3 "$TMP/p10-build.log"
    fi
  else
    cond_skip "26-a bundle 重建" "本机 bun 装不上钉住的依赖（无网络/锁文件不符）：$(tail -2 "$TMP/p10-build.log" | tr '\n' ' ' | head -c 100)"
  fi
else
  cond_skip "26-a bundle 重建" "本机没有 bun（重建是 release-time 检查，报告 rebuild.log 里有网络重建日志）"
fi

# ---------------------------------------------------------------- 26-b. 观察者不写 patrol state
P10_OBS_STATE="$TMP/p10-observe-state"; mkdir -p "$P10_OBS_STATE"
printf 'seed\n' > "$P10_OBS_STATE/pm-restarts.log"      # 观察者连已有文件都不许动
printf 'seed\n' > "$P10_OBS_STATE/standby"
P10_OBS_BEFORE="$(cd "$P10_OBS_STATE" && find . -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" | cut -d' ' -f1; done | md5sum)"
p10m env TEAM_STATE_DIR="$P10_OBS_STATE" $TEAM monitor --print >"$TMP/p10-observe-print.log" 2>&1 || true
p10m env TEAM_STATE_DIR="$P10_OBS_STATE" $TEAM monitor --json >"$TMP/p10-observe-json.log" 2>&1 || true
P10_OBS_AFTER="$(cd "$P10_OBS_STATE" && find . -type f | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" | cut -d' ' -f1; done | md5sum)"
if [ ! -e "$P10_OBS_STATE/capacity.log" ] && [ ! -e "$P10_OBS_STATE/watchdog.tick.log" ]; then
  ok "26-b 观察者：--print/--json 没有写 capacity.log/watchdog.tick.log"
else
  bad "26-b 观察者：--print/--json 写了 patrol state（$(ls "$P10_OBS_STATE" | tr '\n' ' ')）"
fi
assert_eq "26-b 观察者：临时 state 目录逐字节不变（含已有文件与新增文件）" "$P10_OBS_AFTER" "$P10_OBS_BEFORE"

# ---------------------------------------------------------------- 26-c. 纯文本契约（--print / 重定向 / UI=text）
# M12 追加：下面两条断言把两次**实时执行**逐字对比 ⇒ 容量数据源必须钉住：默认读 /proc/meminfo 与
# /proc/swaps，数值天然会动（实测 MemAvailable ±100MB/s；「可再加 N 个」= (avail+disk_free−512)/6144，
# 在边界附近两次采样就能差 1 —— PM 复验就在这里红过，而报错把原因说成了 ESC）。
# 只钉 TEAM_MEMINFO_FILE 不够：面板的 swap 列与「可再加」还走 team_swap_breakdown(/proc/swaps)，
# 所以连 6b 造的 swaps 夹具一起钉。
p10cap=(TEAM_MEMINFO_FILE="$TMP/meminfo-plenty" TEAM_SWAPFILE_PATH="$TMP/swaps")
p10c() { p10m env "${p10cap[@]}" "$@"; }                 # 26-c 里所有真跑：带容量夹具
p10_norm() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/' "${1:-/dev/null}"; }
p10_diff1() { diff <(p10_norm "$1") <(p10_norm "$2") 2>/dev/null | head -4 | tr '\n' ' '; }  # 失败信息里的首个差异

p10c $TEAM monitor --print >"$TMP/p10-print.txt" 2>"$TMP/p10-print.err"
P10_RC=$?
if [ "$P10_RC" = "0" ] && [ "$(p10_esc "$TMP/p10-print.txt")" = "0" ]; then
  ok "26-c 纯文本：--print 退出 0 且 0 个 ESC 字节"
else
  bad "26-c 纯文本：--print rc=$P10_RC ESC=$(p10_esc "$TMP/p10-print.txt")"; tail -2 "$TMP/p10-print.err"
fi
assert_has "$TMP/p10-print.txt" "· $(basename "$P10R")" "26-c 纯文本：第一行点名项目"
assert_has "$TMP/p10-print.txt" "巡检 900s" "26-c 纯文本：第一行点名巡检周期"
# 失败信息分开报：① ESC（=控制字节）与 ② 内容 diff 是两回事，后者要带首个差异（否则又要考古）
p10c $TEAM monitor --once --no-pulse >"$TMP/p10-once-redirect.txt" 2>/dev/null
P10_ONCE_ESC="$(p10_esc "$TMP/p10-once-redirect.txt")"
if [ "$P10_ONCE_ESC" != "0" ]; then
  bad "26-c 纯文本：重定向的 --once 里有 ESC 控制字节（ESC=$P10_ONCE_ESC）：纯文本路径没走到"
elif ! diff <(p10_norm "$TMP/p10-print.txt") <(p10_norm "$TMP/p10-once-redirect.txt") >/dev/null; then
  bad "26-c 纯文本：重定向的 --once 与 --print 内容不一致（ESC=0，时间戳已归一）：$(p10_diff1 "$TMP/p10-print.txt" "$TMP/p10-once-redirect.txt")"
else
  ok "26-c 纯文本：重定向的 --once 与 --print 只差时间戳（且 0 ESC）"
fi
p10c env TEAM_MONITOR_UI=text $TEAM monitor --once --no-pulse >"$TMP/p10-ui-text.txt" 2>/dev/null
P10_UITEXT_ESC="$(p10_esc "$TMP/p10-ui-text.txt")"
if [ "$P10_UITEXT_ESC" != "0" ]; then
  bad "26-c 纯文本：TEAM_MONITOR_UI=text 渲染出了 ESC 控制字节（ESC=$P10_UITEXT_ESC）：没走纯文本路径"
elif ! diff <(p10_norm "$TMP/p10-print.txt") <(p10_norm "$TMP/p10-ui-text.txt") >/dev/null; then
  bad "26-c 纯文本：TEAM_MONITOR_UI=text 与 --print 内容不一致（ESC=0，时间戳已归一）：$(p10_diff1 "$TMP/p10-print.txt" "$TMP/p10-ui-text.txt")"
else
  ok "26-c 纯文本：TEAM_MONITOR_UI=text 走同一渲染（与 --print 只差时间戳）"
fi
# Ink 在 stdout 不是 TTY 时**不写控制序列**（实测）：所以「tui 强制走 TUI 路径」在这条路上只能观察到
# 「仍然渲染出一帧、退出 0、不报未知参数」。渲染器本身由真 pane 段落（26-m 的 capture + 0 ESC）钉住。
p10c env TEAM_MONITOR_UI=tui $TEAM monitor --once --no-pulse >"$TMP/p10-ui-tui.txt" 2>"$TMP/p10-ui-tui.err"
if [ $? -eq 0 ] && grep -q 'teamsmith pulse' "$TMP/p10-ui-tui.txt" && ! grep -q '未知参数' "$TMP/p10-ui-tui.err"; then
  ok "26-c 纯文本：TEAM_MONITOR_UI=tui 被接受并渲染一帧（重定向下 Ink 不写控制字节，由 26-m 钉渲染器）"
else
  bad "26-c 纯文本：TEAM_MONITOR_UI=tui 没有渲染"; head -2 "$TMP/p10-ui-tui.err"
fi

# ---------------------------------------------------------------- 26-d. --json 形状
p10m $TEAM monitor --json >"$TMP/p10-json.json" 2>"$TMP/p10-json.err"
if p10_py "$TMP/p10-json.json" 'isinstance(d, dict) and "panel" in d and "activity" in d' 2>/dev/null; then
  ok "26-d JSON：一个对象，含 panel 与 activity"
else
  bad "26-d JSON：形状不对"; tail -2 "$TMP/p10-json.err"
fi
p10_check "$TMP/p10-json.json" 'len(p["agents"]) == 2 and all("name" in a and "state" in a for a in p["agents"])' \
  "26-d JSON：每个名册 agent 一个对象（name/state）"
p10_check "$TMP/p10-json.json" 'bool(d["activity"]) and all(k in d["activity"][0] for k in ("source","available","truncated","tail_limit","count","events"))' \
  "26-d JSON：activity 条目带数据层的 source/available/truncated/tail_limit/count/events"
P10_MON_JSON="$TMP/p10-mon-json.json"
"$JS_RUNNER" "$SKILL_DIR/scripts/monitor.mjs" --root "$P10R" --only dev --events 4 --log-glob "$P10_AGENTLOG" --json \
  >"$P10_MON_JSON" 2>/dev/null
if python3 - "$TMP/p10-json.json" "$P10_MON_JSON" <<'PY'
import json, sys
a = json.load(open(sys.argv[1]))["activity"]
b = json.load(open(sys.argv[2]))
sys.exit(0 if a and [sorted(e.keys()) for e in a] == [sorted(e.keys()) for e in b] else 1)
PY
then
  ok "26-d JSON：activity 的键与同一夹具下 monitor.mjs --json 的键一致"
else
  bad "26-d JSON：activity 的键与 monitor.mjs --json 不一致"
fi

# ---------------------------------------------------------------- 26-e. 布局：四档宽度 + 高度上限
# B3 起布局合同换成「几何纯函数 + 四档宽度」（spec：The layout is a pure function of geometry with
# four width tiers）；旧的「四带顺序 / 高度降级」断言随 REMOVED 需求一起退休。这里钉四件事：
#   * ≥160 双列（agent 表头与右栏标题同一行）、<100 单列（两者不同行）；
#   * PM 行在 agent 行之前，键位行永远是最后一行；
#   * 高度是硬上限；
#   * 60x8 的极小 pane 不越界（显示宽度 ≤ 60；强版本在 tests/panel-snapshots.sh）。
p10m $TEAM monitor --print --width 160 --height 29 >"$TMP/p10-w160.txt" 2>/dev/null
p10m $TEAM monitor --print --width 99 --height 29 >"$TMP/p10-w99.txt" 2>/dev/null
p10m $TEAM monitor --print --width 59 --height 29 >"$TMP/p10-w59.txt" 2>/dev/null
p10m $TEAM monitor --print --width 60 --height 8 >"$TMP/p10-tiny.txt" 2>/dev/null
for _f in w160 w99 w59 tiny; do
  if grep -q 'teamsmith pulse' "$TMP/p10-$_f.txt"; then ok "26-e 夹具：$_f 的帧非空"
  else bad "26-e 夹具：$_f 没有输出（后面的断言会空跑）"; fi
done
if grep -qE '代理.*活动（仅本 session' "$TMP/p10-w160.txt"; then ok "26-e 档位：160 列是双列（表头与右栏标题同一行）"
else bad "26-e 档位：160 列没有双列"; fi
if grep -qE '代理.*活动（仅本 session' "$TMP/p10-w99.txt"; then bad "26-e 档位：99 列不该是双列"
else ok "26-e 档位：99 列单列（表头与右栏标题不同行）"; fi
P10_PM_LINE="$(grep -n 'PM ' "$TMP/p10-w160.txt" | head -1 | cut -d: -f1)"
P10_AGENT_LINE="$(grep -n '代理' "$TMP/p10-w160.txt" | head -1 | cut -d: -f1)"
P10_KEY_LINE="$(grep -n 'q 收起' "$TMP/p10-w160.txt" | tail -1 | cut -d: -f1)"
if [ -n "$P10_PM_LINE" ] && [ -n "$P10_AGENT_LINE" ] && [ "$P10_PM_LINE" -lt "$P10_AGENT_LINE" ] && [ -n "$P10_KEY_LINE" ]; then
  ok "26-e 布局：PM/待办行在 agent 行之前，键位行存在（160x29）"
else
  bad "26-e 布局：行序不对（PM=$P10_PM_LINE AGENT=$P10_AGENT_LINE 键位=$P10_KEY_LINE）"
fi
assert_eq "26-e 布局：键位行是最后一行" "$(grep -n . "$TMP/p10-w160.txt" | tail -1 | cut -d: -f1)" "$P10_KEY_LINE"
if [ "$(grep -c . "$TMP/p10-w160.txt")" -le 29 ]; then ok "26-e 布局：160x29 的帧 ≤ 29 行"
else bad "26-e 布局：160x29 输出超过高度（$(grep -c . "$TMP/p10-w160.txt") 行）"; fi
if [ "$(grep -c . "$TMP/p10-tiny.txt")" -le 8 ]; then ok "26-e 极小 pane：60x8 的帧 ≤ 8 行"
else bad "26-e 极小 pane：60x8 输出超过 8 行"; fi
if [ "$(wc -L < "$TMP/p10-tiny.txt" | tr -d ' ')" -le 60 ]; then ok "26-e 极小 pane：最长行 ≤ 60 字符（显示宽度由 panel-snapshots 钉）"
else bad "26-e 极小 pane：有行超过 60 列"; fi

# ---------------------------------------------------------------- 26-f. 状态带（band A）
p10_check "$TMP/p10-json.json" 'p["pm"]["state"] == "absent"' "26-f 状态带：无 PM 窗口 → panel.pm.state=absent"
p10_check "$TMP/p10-json.json" '(p["pending"]["inbox"], p["pending"]["reports"], p["pending"]["blocked"], p["pending"]["total"]) == (1, 2, 1, 4)' \
  "26-f 状态带：待办 1/2/1 与总数 4（未读/待复验/blocked）"
p10_check "$TMP/p10-json.json" 'p["capacity"]["ram_avail_mb"] == 4040 and len(p["capacity"]["spark"]) >= 2' \
  "26-f 状态带：RAM 采样 = 最后一条、spark ≥ 2 个值"
p10_check "$TMP/p10-json.json" '"zram_phys" not in p["capacity"]' "26-f 状态带：panel.capacity 里没有 zram 物理 MB"
if grep -qi zram "$TMP/p10-print.txt"; then bad "26-f 状态带：打印帧里出现了 zram"; else ok "26-f 状态带：打印帧不带 zram"; fi
assert_has "$TMP/p10-print.txt" "absent" "26-f 状态带：打印帧带 PM 状态词（闭集 token）"
assert_match "$TMP/p10-print.txt" "延后投递 [0-9]+" "26-f 状态带：打印帧带延后投递计数"

# ---------------------------------------------------------------- 26-g. agent 表（band B）
# verify：窗口不在但任务还在（停了的 agent 也要点名任务）。放在 26-f 之后：
# 有 task= 且没在跑会进 pending.stopped，26-f 的 1/2/1/4 是另一个 GIVEN。
printf 'task=P10Z\n' > "$P10STATE/verify.env"
p10ms $TEAM monitor --json >"$TMP/p10-agents.json" 2>"$TMP/p10-agents.err"
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="dev"][0]["branch"].startswith("task/P10X")' \
  "26-g agent 表：分支列是真实分支名"
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="dev"][0]["dirty"] == True' "26-g agent 表：dirty=true"
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="dev"][0]["ahead"] == 3' "26-g agent 表：ahead=3"
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="dev"][0]["session_tokens"] > 0' \
  "26-g agent 表：session_tokens 非空（真实会话文件）"
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="dev"][0].get("elapsed")' \
  "26-g agent 表：elapsed 保留在 JSON 里"
P10_ELAPSED="$(python3 -c 'import json,sys; print([a for a in json.load(open(sys.argv[1]))["panel"]["agents"] if a["name"]=="dev"][0].get("elapsed") or "")' "$TMP/p10-agents.json" 2>/dev/null)"
p10ms $TEAM monitor --print >"$TMP/p10-agents.txt" 2>/dev/null
if [ -n "$P10_ELAPSED" ] && grep -qF "$P10_ELAPSED" "$TMP/p10-agents.txt"; then
  bad "26-g agent 表：打印帧不该出现 uptime（$P10_ELAPSED）"
else
  ok "26-g agent 表：uptime 只在 JSON（打印帧没有 $P10_ELAPSED）"
fi
p10_check "$TMP/p10-agents.json" '[a for a in p["agents"] if a["name"]=="verify"][0]["state"] == "absent" and [a for a in p["agents"] if a["name"]=="verify"][0]["task"] == "P10Z"' \
  "26-g agent 表：停了的 agent 仍报 absent 且点名任务"
assert_eq "26-g agent 表：打印帧的 verify 行点名 P10Z" "$(grep -c 'P10Z' "$TMP/p10-agents.txt")" "1"

# ---------------------------------------------------------------- 26-h. 活动列（默认开 / 可关 / 有界）
p10m $TEAM monitor --print >"$TMP/p10-act.txt" 2>/dev/null
p10m $TEAM monitor --print --no-activity >"$TMP/p10-act-off.txt" 2>/dev/null
p10m $TEAM monitor --json --no-activity >"$TMP/p10-act-off.json" 2>/dev/null
p10_frame_ok "$TMP/p10-act-off.txt" "26-h 夹具：--no-activity 帧非空"
assert_has "$TMP/p10-act.txt" "wrote the report" "26-h 活动列：默认就有（夹具事件出现在帧里）"
assert_has "$TMP/p10-act.txt" "活动（仅本 session 在跑的窗口" "26-h 活动列：默认带活动列标题"
assert_not "$TMP/p10-act-off.txt" "wrote the report" "26-h 活动列：--no-activity 去掉事件"
assert_not "$TMP/p10-act-off.txt" "活动（仅本 session" "26-h 活动列：--no-activity 去掉标题"
p10_check "$TMP/p10-act-off.json" 'd["activity"] == []' "26-h 活动列：--no-activity 的 --json activity 为空"
p10m env TEAM_MONITOR_ACTIVITY=0 $TEAM monitor --print >"$TMP/p10-act-env0.txt" 2>/dev/null
p10_frame_ok "$TMP/p10-act-env0.txt" "26-h 夹具：TEAM_MONITOR_ACTIVITY=0 帧非空"
assert_not "$TMP/p10-act-env0.txt" "wrote the report" "26-h 活动列：TEAM_MONITOR_ACTIVITY=0 恢复旧布局"
p10m env TEAM_MONITOR_ACTIVITY=0 $TEAM monitor --print --activity >"$TMP/p10-act-env0-flag.txt" 2>/dev/null
assert_has "$TMP/p10-act-env0-flag.txt" "wrote the report" "26-h 活动列：--activity 反向覆盖 key"
# 一帧只读一次数据（不是忙轮询）：运行时换成会记日志的包装器 → 一帧至多两行（面板 + 一次数据读）
P10_JSWRAP="$TMP/p10-js-wrap"; mkdir -p "$P10_JSWRAP"
P10_REAL_NODE="$(command -v node || echo /usr/bin/node)"
cat > "$P10_JSWRAP/js" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/p10-js-calls.log"
exec "$P10_REAL_NODE" "\$@"
EOF
chmod +x "$P10_JSWRAP/js"
rm -f "$TMP/p10-js-calls.log"
p10m env TEAM_JS_BIN="$P10_JSWRAP/js" $TEAM monitor --once --no-pulse >"$TMP/p10-js-one.txt" 2>/dev/null
# 两条计数分开：`--version` 探针（启动时一次）不算「一帧的读」，面板与数据读各数各的
P10_PANEL_CALLS="$(grep -c 'panel/panel.js' "$TMP/p10-js-calls.log" 2>/dev/null || echo 0)"
P10_DATA_CALLS="$(grep -c 'monitor.mjs' "$TMP/p10-js-calls.log" 2>/dev/null || echo 0)"
if grep -q 'teamsmith pulse' "$TMP/p10-js-one.txt" && [ "${P10_PANEL_CALLS:-0}" = "1" ] && [ "${P10_DATA_CALLS:-9}" -le 1 ]; then
  ok "26-h 一帧一次数据读：--once 起 1 次面板进程 + ${P10_DATA_CALLS} 次数据读（不是忙轮询）"
else
  bad "26-h 一帧一次数据读：面板 $P10_PANEL_CALLS 次 / 数据读 $P10_DATA_CALLS 次（帧 $(grep -c 'teamsmith pulse' "$TMP/p10-js-one.txt" 2>/dev/null) 行）"
fi
# 有界读：12 MiB 日志 → truncated + tail_limit=65536
P10_BIGLOG="$TMP/p10-big.log"
head -c 12582912 /dev/zero | tr '\0' 'y' > "$P10_BIGLOG"; printf '\nBIGTAIL\n' >> "$P10_BIGLOG"
p10m env TEAM_AGENT_LOG_GLOB="$P10_BIGLOG" $TEAM monitor --json >"$TMP/p10-big.json" 2>/dev/null
p10_check "$TMP/p10-big.json" 'bool(d["activity"]) and d["activity"][0]["truncated"] == True and d["activity"][0]["tail_limit"] == 65536' \
  "26-h 有界读：12MiB 日志报 truncated=true / tail_limit=65536"
p10m env TEAM_AGENT_LOG_GLOB="$P10_BIGLOG" $TEAM monitor --print >"$TMP/p10-big.txt" 2>/dev/null
assert_eq "26-h 最近动作：打印帧里最多 6 行动作" "$(grep -c '行动作' "$TMP/p10-big.txt")" "6"
assert_has "$TMP/p10-big.txt" "第 8 行动作" "26-h 最近动作：显示的是最后几行"
assert_not "$TMP/p10-big.txt" "第 2 行动作" "26-h 最近动作：没有把 8 行全铺出来"

# 待命（单独一段：standby on/off 自己会往 watchdog.log 写两行，会污染上面「最近 6 行」的口径）
p10 $TEAM standby on --reason "waiting for the user" >/dev/null 2>&1
p10m $TEAM monitor --json >"$TMP/p10-standby.json" 2>/dev/null
p10m $TEAM monitor --print >"$TMP/p10-standby.txt" 2>/dev/null
p10_check "$TMP/p10-standby.json" 'p["standby"]["on"] == True and p["standby"]["reason"] == "waiting for the user"' \
  "26-f 待命：--json 报 on 与原因"
assert_has "$TMP/p10-standby.txt" "waiting for the user" "26-f 待命：打印帧在标题/PM 行显示原因"
p10 $TEAM standby off >/dev/null 2>&1

# ---------------------------------------------------------------- 26-i. 显示安全（净化不截断）
P10_HOSTILE="$TMP/p10-hostile.log"
printf 'safe \033]52;c;aGVsbG8=\007 MORE \033[2J END\n' > "$P10_HOSTILE"
p10m env TEAM_AGENT_LOG_GLOB="$P10_HOSTILE" $TEAM monitor --print >"$TMP/p10-hostile.txt" 2>/dev/null
p10m env TEAM_AGENT_LOG_GLOB="$P10_HOSTILE" $TEAM monitor --json >"$TMP/p10-hostile.json" 2>/dev/null
assert_eq "26-i 净化：敌意日志的打印帧 0 个 ESC 字节" "$(p10_esc "$TMP/p10-hostile.txt")" "0"
assert_eq "26-i 净化：敌意日志的 --json 0 个 ESC 字节" "$(p10_esc "$TMP/p10-hostile.json")" "0"
if grep -q 'safe' "$TMP/p10-hostile.txt" && grep -q 'MORE' "$TMP/p10-hostile.txt" && grep -q 'END' "$TMP/p10-hostile.txt"; then
  ok "26-i 净化：控制序列被剥掉、可见文本 safe/MORE/END 都保留（没有在控制字符处截断）"
else
  bad "26-i 净化：可见文本丢了"
fi
# 状态文件里的敌意任务 id（面板**自己**读的字符串，不经过 monitor.mjs）：
# 裸 ESC 由 bash 的传输层剥掉；C1（U+009B CSI）与双向/零宽字符在 UTF-8 里不是控制**字节**，
# 会穿过传输层，只有面板自己的净化（sanitizeDeep）能拦住 —— 这条断言因此钉住的是 JS 层。
printf 'task=evil\033[2Jtask\n' > "$P10STATE/verify.env"
p10m $TEAM monitor --print >"$TMP/p10-taskid.txt" 2>/dev/null
p10_frame_ok "$TMP/p10-taskid.txt" "26-i 夹具：敌意任务 id 帧非空"
assert_eq "26-i 净化：敌意任务 id 的打印帧 0 个 ESC 字节" "$(p10_esc "$TMP/p10-taskid.txt")" "0"
if grep -q 'eviltask\|evil' "$TMP/p10-taskid.txt"; then ok "26-i 净化：敌意任务 id 的可见字符仍在"
else bad "26-i 净化：敌意任务 id 的可见字符丢了"; fi
printf 'task=evil\302\233 2 J bidi\342\200\256mark zwsp\342\200\213end\n' > "$P10STATE/verify.env"
p10m $TEAM monitor --print >"$TMP/p10-c1.txt" 2>/dev/null
p10_frame_ok "$TMP/p10-c1.txt" "26-i 夹具：C1 帧非空"
if grep -qP '[\x{0080}-\x{009F}]' "$TMP/p10-c1.txt"; then
  bad "26-i 净化：C1 控制字符（U+009B）漏进了打印帧（面板自己的净化没生效）"
else
  ok "26-i 净化：C1 控制字符被剥掉（只有面板自己的那一层能拦，传输层拦不住）"
fi
if grep -qP '[\x{200B}\x{202A}-\x{202E}\x{2060}\x{2066}-\x{2069}\x{FEFF}]' "$TMP/p10-c1.txt"; then
  bad "26-i 净化：双向/零宽控制字符漏进了打印帧"
else
  ok "26-i 净化：双向/零宽控制字符被剥掉"
fi
# 表格列宽会截断任务 id（布局的事），所以「可见文本没丢」看 --json 里的原始字段
p10m $TEAM monitor --json >"$TMP/p10-c1.json" 2>/dev/null
if python3 - "$TMP/p10-c1.json" <<'PYC1'
import json, sys, re
task = [a for a in json.load(open(sys.argv[1]))["panel"]["agents"] if a["name"] == "verify"][0]["task"]
clean = re.sub(r"[^0-9A-Za-z]+", " ", task)
sys.exit(0 if all(w in clean for w in ("evil", "bidi", "mark", "zwsp", "end")) else 1)
PYC1
then
  ok "26-i 净化：C1 两边的可见文本都保留（没有在控制字符处截断）"
else
  bad "26-i 净化：C1 夹具的可见文本丢了"
fi
printf 'task=P10Z\n' > "$P10STATE/verify.env"
# 分支名里的敌意序列：真 git 拒绝控制字符的 ref（check-ref-format），所以用只回这一条探针的 git shim
P10_GITSHIM="$TMP/p10-gitshim"; mkdir -p "$P10_GITSHIM"
P10_REAL_GIT="$(command -v git)"
cat > "$P10_GITSHIM/git" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "-C" ] && [ "\${3:-}" = "rev-parse" ] && [ "\${4:-}" = "--abbrev-ref" ]; then
  printf 'evil\033[2Jbranch\n'; exit 0
fi
# M50：分支读径进了「worktree list --porcelain 一个纪元一次」的进程内缓存（rev-parse 不再是热径）——
# 探针跟到同一条读径上注：真实输出照跑，只把 branch 行改写成敌意名（worktree 路径映射原样保留，
# 净化层吃到的字符串与旧探针完全同源；唯一消费者是 common.sh 的 _team_wt_cache_load）。
if [ "\${1:-}" = "-C" ] && [ "\${3:-}" = "worktree" ] && [ "\${4:-}" = "list" ]; then
  "$P10_REAL_GIT" "\$@" | sed "s|^branch refs/heads/.*|branch refs/heads/evil\$(printf '\033')[2Jbranch|"
  exit 0
fi
exec "$P10_REAL_GIT" "\$@"
EOF
chmod +x "$P10_GITSHIM/git"
p10m env PATH="$P10_GITSHIM:$PATH" $TEAM monitor --print >"$TMP/p10-branch.txt" 2>/dev/null
assert_eq "26-i 净化：敌意分支名的打印帧 0 个 ESC 字节" "$(p10_esc "$TMP/p10-branch.txt")" "0"
if grep -q 'evilbranch\|evil' "$TMP/p10-branch.txt"; then ok "26-i 净化：敌意分支名的可见字符仍在"
else bad "26-i 净化：敌意分支名的可见字符丢了"; fi

# ---------------------------------------------------------------- 26-j. 队列字段（只读）
# M33 哨兵（本段就是 bg6 出事的地方）：开头/结尾各点名一次「$TMP 还是不是同一个目录」。
assert_tmp_alive "26-j 哨兵：队列夹具之前临时目录还在"
P10_OBOX="$P10STATE/outbox"
P10_NOW_MS="$(date +%s%3N)"
P10_OLD_MS="$((P10_NOW_MS - 3000))"
mkdir -p "$P10_OBOX/held"
printf 'kind: notify\ntarget: pm\n---\nbody 001\n' > "$P10_OBOX/$P10_OLD_MS-001-pm.msg"
for s in 002 003; do printf 'kind: notify\ntarget: pm\n---\nbody %s\n' "$s" > "$P10_OBOX/$P10_NOW_MS-$s-pm.msg"; done
printf 'kind: notify\ntarget: pm\n---\nheld body\n' > "$P10_OBOX/held/$P10_OLD_MS-001-pm.msg"
printf 'forced line\n' > "$P10_OBOX/forced.log"
printf 'holding line\n' > "$P10_OBOX/HOLDING.log"
p10m $TEAM monitor --json >"$TMP/p10-queue.json" 2>/dev/null
p10_check "$TMP/p10-queue.json" 'p["outbox"]["queued"] == 3 and p["outbox"]["held"] == 1' "26-j 队列：queued=3 / held=1"
p10_check "$TMP/p10-queue.json" '1 <= p["outbox"]["oldest_age_s"] <= 5' "26-j 队列：oldest_age_s 与最老条目的 epoch 一致（±2s）"
P10_QHASH1="$(find "$P10_OBOX" -type f | sort | xargs -r md5sum | md5sum)"
p10m $TEAM monitor --print >/dev/null 2>&1
p10m $TEAM monitor --json >/dev/null 2>&1
p10m $TEAM monitor --once --no-pulse >/dev/null 2>&1
P10_QHASH2="$(find "$P10_OBOX" -type f | sort | xargs -r md5sum | md5sum)"
assert_eq "26-j 队列：三种模式跑完条目逐字节不变（只读）" "$P10_QHASH2" "$P10_QHASH1"
assert_eq "26-j 队列：跑完没有新增文件" "$(find "$P10_OBOX" -type f | wc -l | tr -d ' ')" "6"
assert_eq "26-j 队列：forced.log 没长" "$(wc -l < "$P10_OBOX/forced.log" | tr -d ' ')" "1"
assert_eq "26-j 队列：HOLDING.log 没长" "$(wc -l < "$P10_OBOX/HOLDING.log" | tr -d ' ')" "1"
rm -rf "$P10_OBOX"
p10m $TEAM monitor --json >"$TMP/p10-noqueue.json" 2>/dev/null
p10_check "$TMP/p10-noqueue.json" 'p["outbox"]["queued"] == 0' "26-j 队列：没有 outbox/ 时报 0"
if [ -e "$P10_OBOX" ]; then bad "26-j 队列：面板把 outbox/ 建出来了"; else ok "26-j 队列：面板没有创建 outbox/"; fi
assert_tmp_alive "26-j 哨兵：队列夹具跑完临时目录仍在（中途没被删）"

# ---------------------------------------------------------------- 26-k. 运行时失败（响亮、不假绿）
P10_NOJS="$TMP/p10-nojs-bin"; mkdir -p "$P10_NOJS"
for _d in ${PATH//:/ }; do [ -d "$_d" ] && ln -sf "$_d"/* "$P10_NOJS/" 2>/dev/null; done
rm -f "$P10_NOJS/node" "$P10_NOJS/nodejs" "$P10_NOJS/bun" "$P10_NOJS/bunx" "$P10_NOJS/tsx" "$P10_NOJS/npx" "$P10_NOJS/corepack" "$P10_NOJS/deno"
ln -sf "$FAKE/openspec" "$P10_NOJS/openspec"
assert_eq "26-k 夹具：影子 PATH 里没有 node" "$(env PATH="$P10_NOJS" bash -c 'command -v node || echo MISSING')" "MISSING"
p10nojs() { ( cd "$P10R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
               -u TEAM_JS_BIN -u TEAM_REQUIRE_JS "PATH=$P10_NOJS" "TEAM_AGENT_CMD=true {prompt}" "TEAM_AGENT_BIN=true" \
               "TEAM_OPENSPEC_BIN=$FAKE/openspec" "TEAM_SPEC_DIR=openspec" "TEAM_REQUIRE_MAGIC_CONTEXT=0" \
               "HOME=$P10_HOME" "TEAM_PI_AGENT_DIR=$P10_HOME/.pi/agent" "$@" ); }
if p10nojs $TEAM doctor >"$TMP/p10-doctor-nojs.log" 2>&1; then
  bad "26-k 运行时：没有 node/bun/tsx 时 doctor 应失败"
else
  ok "26-k 运行时：没有 node/bun/tsx → doctor 失败"
fi
assert_has "$TMP/p10-doctor-nojs.log" "JS 运行时" "26-k 运行时：失败行点名 JS 运行时这一项"
assert_has "$TMP/p10-doctor-nojs.log" "node" "26-k 运行时：失败行点名 node"
assert_has "$TMP/p10-doctor-nojs.log" "bun" "26-k 运行时：失败行点名 bun"
assert_has "$TMP/p10-doctor-nojs.log" "TEAM_JS_BIN" "26-k 运行时：失败行给出 TEAM_JS_BIN 的修法"
assert_has "$TMP/p10-doctor-nojs.log" "TEAM_REQUIRE_JS=0" "26-k 运行时：失败行给出降级开关"
if p10nojs env TEAM_REQUIRE_JS=0 $TEAM doctor >"$TMP/p10-doctor-nojs-warn.log" 2>&1; then
  ok "26-k 运行时：TEAM_REQUIRE_JS=0 → doctor 只警告（exit 0）"
else
  bad "26-k 运行时：降级后 doctor 不该失败"; tail -3 "$TMP/p10-doctor-nojs-warn.log"
fi
assert_has "$TMP/p10-doctor-nojs-warn.log" "已降级" "26-k 运行时：降级时说明是配置降级"
p10nojs $TEAM monitor --once >"$TMP/p10-mon-nojs.log" 2>&1
P10_RC_ONCE=$?
p10nojs $TEAM monitor --print >"$TMP/p10-mon-nojs-print.log" 2>&1
P10_RC_PRINT=$?
if [ "$P10_RC_ONCE" != "0" ] && [ "$P10_RC_PRINT" != "0" ] \
   && ! grep -q 'teamsmith pulse' "$TMP/p10-mon-nojs.log" && ! grep -q 'teamsmith pulse' "$TMP/p10-mon-nojs-print.log"; then
  ok "26-k 运行时：没有运行时 → monitor 每个模式都非 0 且不打印面板标题"
else
  bad "26-k 运行时：monitor 在无运行时下没响亮失败（rc=$P10_RC_ONCE/$P10_RC_PRINT）"
fi
if p10nojs env TEAM_REQUIRE_JS=0 $TEAM monitor --print >"$TMP/p10-mon-nojs-esc.log" 2>&1; then
  bad "26-k 运行时：TEAM_REQUIRE_JS=0 不该让面板复活"
else
  ok "26-k 运行时：TEAM_REQUIRE_JS=0 不影响面板（仍然非 0）"
fi
if p10nojs env TEAM_JS_BIN=/nonexistent $TEAM doctor >"$TMP/p10-doctor-badbin.log" 2>&1; then
  bad "26-k 运行时：TEAM_JS_BIN 不可用时 doctor 应失败"
else
  ok "26-k 运行时：TEAM_JS_BIN 指向不存在的东西 → doctor 失败"
fi
assert_has "$TMP/p10-doctor-badbin.log" "/nonexistent" "26-k 运行时：失败行点名那个路径"
P10_V18="$TMP/p10-v18-shim"; mkdir -p "$P10_V18"
printf '#!/usr/bin/env bash\nif [ "${1:-}" = "--version" ]; then printf "v18.0.0\\n"; fi\n' > "$P10_V18/my-node"
chmod +x "$P10_V18/my-node"
if p10nojs env TEAM_JS_BIN="$P10_V18/my-node" $TEAM doctor >"$TMP/p10-doctor-old.log" 2>&1; then
  bad "26-k 运行时：版本低于底线时 doctor 应失败"
else
  ok "26-k 运行时：v18 的 shim → doctor 失败"
fi
assert_has "$TMP/p10-doctor-old.log" "18" "26-k 运行时：失败行点名解析到的版本"
assert_has "$TMP/p10-doctor-old.log" "20" "26-k 运行时：失败行点名最低版本"
p10m $TEAM paths >"$TMP/p10-paths.log" 2>&1
assert_match "$TMP/p10-paths.log" '"js_runner": "/' "26-k paths：报出解析到的运行时绝对路径"
assert_has "$TMP/p10-paths.log" '"require_js": "1"' "26-k paths：报出 require_js 默认 1"
# M47：不能写死 /usr/bin/node —— runner 的 node 在 hostedtoolcache 里、容器里在 /usr/local/bin，
# 写死路径会把「TEAM_JS_BIN 优先」测成环境探测。用**本机实际解析到的那份**绝对路径当夹具，
# 判据不变（报出的就是传进去的那份），在任何装了 node/bun 的机器上都有意义。
P10_JS_FIXTURE="$(command -v node || command -v bun || true)"
if [ -n "$P10_JS_FIXTURE" ]; then
  p10m env TEAM_JS_BIN="$P10_JS_FIXTURE" $TEAM paths >"$TMP/p10-paths-jsbin.log" 2>&1
  assert_has "$TMP/p10-paths-jsbin.log" "\"js_runner\": \"$P10_JS_FIXTURE\"" "26-k paths：TEAM_JS_BIN 优先（点名传进去的绝对路径）"
else
  cond_skip "26-k paths：TEAM_JS_BIN 优先" "本机没有 node/bun（运行时解析整段都由 26-k 的负例覆盖）"
fi
p10m env TEAM_REQUIRE_JS=0 $TEAM paths >"$TMP/p10-paths-reqjs.log" 2>&1
assert_has "$TMP/p10-paths-reqjs.log" '"require_js": "0"' "26-k paths：TEAM_REQUIRE_JS=0 反映在 paths 里"

# ---------------------------------------------------------------- 26-l. 文档契约 + 隔离（真项目零污染）
# R11-S2 的另一半：活动列的新默认值是**写在文档里**的契约变更，不是悄悄改的
P10_CFG="$SKILL_DIR/references/config.md"
assert_has "$P10_CFG" "TEAM_MONITOR_ACTIVITY" "26-l 文档：config.md 写了 TEAM_MONITOR_ACTIVITY"
assert_match "$P10_CFG" '\| `TEAM_MONITOR_ACTIVITY` \| `1` \|' "26-l 文档：config.md 的活动列默认值已改成 1"
assert_has "$P10_CFG" "TEAM_MONITOR_UI" "26-l 文档：config.md 写了 TEAM_MONITOR_UI"
assert_has "$P10_CFG" "TEAM_JS_BIN" "26-l 文档：config.md 写了 TEAM_JS_BIN"
assert_has "$P10_CFG" "TEAM_REQUIRE_JS" "26-l 文档：config.md 写了 TEAM_REQUIRE_JS"
assert_has "$P10_CFG" "--print" "26-l 文档：config.md 写了 --print/--json/--width/--height 旗标"
assert_has "$SKILL_DIR/references/troubleshooting.md" "TEAM_MONITOR_UI=text" "26-l 文档：troubleshooting 写了纯文本兜底"
assert_has "$SKILL_DIR/references/troubleshooting.md" "build.sh" "26-l 文档：troubleshooting 写了维护者重建路径"
P10_LEAK_AFTER="$(P10_LEAK_SCAN "$SMOKE_INVOKE_ROOT" "$SMOKE_INVOKE_MAIN" | sort -u)"
if [ "$P10_LEAK_AFTER" = "$P10_LEAK_BEFORE" ]; then
  ok "26-l 隔离：调用方项目的 inbox/state 里没有出现夹具痕迹"
else
  bad "26-l 隔离：夹具痕迹出现在真项目里：$(printf '%s' "$P10_LEAK_AFTER" | head -2 | tr '\n' ' ')"
fi

# ---------------------------------------------------------------- 26-n. tick 语义（headless）
# 观察者绝不 tick、--once 按期 tick（今天的语义）：跑在**干净的沙盒**里，避免污染上面那份夹具。
P10_TICKR="$TMP/p10-tick-repo"
mkdir -p "$P10_TICKR"
( cd "$P10_TICKR" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo "# tick" > README.md && git add -A && git commit -qm init )
( cd "$P10_TICKR" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "teamsmith-smoke-p10t-$$" --agents dev --vcs local --gates "true" --docs docs/team ) >/dev/null 2>&1
p10t() { ( cd "$P10_TICKR" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
            -u TEAM_STATE_DIR -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_MONITOR_ACTIVITY -u TEAM_MONITOR_UI \
            -u TEAM_AGENT_LOG_GLOB "$@" ); }
p10t $TEAM monitor --print >"$TMP/p10-tick-print.txt" 2>/dev/null
if [ ! -e "$P10_TICKR/.pi/team/state/capacity.log" ]; then
  ok "26-n tick：--print 是观察者，没有写 capacity.log"
else
  bad "26-n tick：--print 写了 capacity.log"
fi
p10t $TEAM monitor --json >/dev/null 2>&1
if [ ! -e "$P10_TICKR/.pi/team/state/capacity.log" ]; then
  ok "26-n tick：--json 是观察者，没有写 capacity.log"
else
  bad "26-n tick：--json 写了 capacity.log"
fi
p10t $TEAM monitor --once >"$TMP/p10-tick-once.txt" 2>/dev/null
P10_TICK1="$(wc -l < "$P10_TICKR/.pi/team/state/capacity.log" 2>/dev/null | tr -d ' ' || echo 0)"
p10t $TEAM monitor --once --no-pulse >"$TMP/p10-tick-once-nopulse.txt" 2>/dev/null
P10_TICK2="$(wc -l < "$P10_TICKR/.pi/team/state/capacity.log" 2>/dev/null | tr -d ' ' || echo 0)"
if [ "${P10_TICK1:-0}" = "1" ]; then ok "26-n tick：--once 到期跑一拍（capacity.log 1 行）"
else bad "26-n tick：--once 没有跑出恰好一拍（$P10_TICK1 行）"; fi
if [ "${P10_TICK2:-0}" = "${P10_TICK1:-0}" ]; then ok "26-n tick：--no-pulse 的 --once 不 tick（仍是 $P10_TICK2 行）"
else bad "26-n tick：--no-pulse 仍然 tick（$P10_TICK1 → $P10_TICK2）"; fi
p10_stable() { # 归一化帧里随时间/内存变化的量（时钟与实时容量），其余逐字节比
  sed -E -e 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/g' -e 's/RAM [0-9.]+[MG]/RAM X/' -e 's/swap [0-9.]+[MG]/swap X/' \
      -e 's/可再加 [0-9?]+ 个/可再加 N 个/' -e 's/[▁▂▃▄▅▆▇█]+/SPARK/' "$1"
}
if diff <(p10_stable "$TMP/p10-tick-print.txt") <(p10_stable "$TMP/p10-tick-once.txt") >/dev/null; then
  ok "26-n tick：--once 的帧与 --print 一致（只差时间戳与实时容量；tick 在渲染之后）"
else
  bad "26-n tick：--once 的帧与 --print 不一致"; diff <(p10_stable "$TMP/p10-tick-print.txt") <(p10_stable "$TMP/p10-tick-once.txt") | head -3
fi
assert_file "$P10_TICKR/.pi/team/state/watchdog.tick.log" "26-n tick：tick 的输出进了 watchdog.tick.log"

# ---------------------------------------------------------------- 26-m. 真 pane（HAVE_TMUX 且非 FAST）
# 夹具用**自己的 session**（尺寸一次到位，避免动 smoke 的 session）：面板的 tmux 探针也跟着这些
# session（项目配置里的 TEAM_SESSION 就是我建的那个），另建一个「别的 session」放 verify 窗口，
# 用来钉「只监视本 session 的窗口」。收尾一律 kill，不留副作用。
if [ "$FAST" = "1" ]; then
  fast_skip "26-m·真 pane" "要真实 tmux 窗口（120x29 / 60x8 / 重绘周期 / tick 节奏 / pulse up 不建窗）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  P10_TRUE_STATE="$TMP/p10-true-state"; mkdir -p "$P10_TRUE_STATE"
  P10_LEFT_LOG="$TMP/p10-left-{agent}.log"
  printf 'LEFT-MARKER\n' > "$TMP/p10-left-dev.log"
  printf 'FOREIGN-MARKER\n' > "$TMP/p10-left-verify.log"
  P10_W1="p10-tui-$$"
  P10_W2="p10-tiny-$$"
  P10_W3="p10-tick-$$"
  P10_SCOPE="$P10SESS"
  P10_OTHER="${SESSION}-other-$$"
  P10_SMOKE_WINDOWS_BEFORE="$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | wc -l | tr -d ' ')"
  p10_panel_cmd() { # <log-glob|-> <interval> [extra-env…]  → 窗口里跑的面板命令
    local p10_glob="" p10_extra="${3:+$3 }"
    [ "$1" != "-" ] && p10_glob="TEAM_AGENT_LOG_GLOB='$1' "
    printf "cd '%s' && HOME='%s' TEAM_PI_AGENT_DIR='%s/.pi/agent' TEAM_STATE_DIR='%s' %s%s bash '%s/scripts/team' monitor --no-pulse --interval %s" \
      "$P10R" "$P10_HOME" "$P10_HOME" "$P10_TRUE_STATE" "$p10_glob" "$p10_extra" "$SKILL_DIR" "$2"
  }
  # M20（同族复查）：26-m 的「首帧 / 重绘 / 动作回响 / 节拍 / tick 节奏」都是**实现速度**断言，
  # 不是契约超时 —— 负载下单次固定 sleep 会假红（F-V16-10 的同族形状；26-m 回响实测红过一次：
  # 标题带停在 `待命 off`）。统一改成**有界轮询**：等的是条件（标题带 / 回显 / 帧 / 心跳），
  # 不是「1.5s 内必须完成」；超时仍然红，并把最后一帧原样打出来。
  # 预算 10s 的来历（V16 实测）：一帧典型 1.24–1.6s（安静）/ 4.1s（loadavg 7–8），动作回响还要再
  # 加一个 `team standby` 子进程 —— 10s ≈ 最坏观测的 2.4 倍。TEAM_SMOKE_PANEL_POLL_SECS 只给翻转
  # 演练用（把预算调小 → 这些断言必须红，证明轮询不是「永远绿」）。
  P10_POLL_SECS="${TEAM_SMOKE_PANEL_POLL_SECS:-10}"
  case "$P10_POLL_SECS" in ''|*[!0-9]*) P10_POLL_SECS=10 ;; esac
  # 轮询实际等了多久：写在文件里而不是变量里 —— helper 被 `$(…)` 调用（子 shell），
  # 在里面赋值不会传回父 shell（M20 第一版就在 `set -u` 下把整轮门禁打停在 26-m）。
  P10_WAIT_MS_FILE="$TMP/p10-wait-ms"
  p10_wait_ms() { cat "$P10_WAIT_MS_FILE" 2>/dev/null || printf '?' ; }
  p10_wait_pane() { # <pane> <needle> [秒] → 打印最后一帧；0=出现了；实际等待毫秒落 P10_WAIT_MS_FILE
    local pane="$1" needle="$2" secs="${3:-$P10_POLL_SECS}" i=0 ticks cap="" t0
    t0="$(date +%s%3N)"
    ticks=$((secs * 4))
    while [ "$i" -lt "$ticks" ]; do
      cap="$(tmux capture-pane -p -t "$pane" 2>/dev/null)"
      case "$cap" in *"$needle"*) printf '%s' "$(( $(date +%s%3N) - t0 ))" > "$P10_WAIT_MS_FILE"; printf '%s' "$cap"; return 0 ;; esac
      sleep 0.25
      i=$((i + 1))
    done
    printf '%s' "$(( $(date +%s%3N) - t0 ))" > "$P10_WAIT_MS_FILE"
    printf '%s' "$cap"
    return 1
  }
  p10_wait_title() { # <pane> <needle> [秒] → 打印最后一行的标题带；0=出现了；实际等待毫秒落 P10_WAIT_MS_FILE
    local pane="$1" needle="$2" secs="${3:-$P10_POLL_SECS}" i=0 ticks line="" t0
    t0="$(date +%s%3N)"
    ticks=$((secs * 4))
    while [ "$i" -lt "$ticks" ]; do
      line="$(tmux capture-pane -p -t "$pane" 2>/dev/null | head -1)"
      case "$line" in *"$needle"*) printf '%s' "$(( $(date +%s%3N) - t0 ))" > "$P10_WAIT_MS_FILE"; printf '%s' "$line"; return 0 ;; esac
      sleep 0.25
      i=$((i + 1))
    done
    printf '%s' "$(( $(date +%s%3N) - t0 ))" > "$P10_WAIT_MS_FILE"
    printf '%s' "$line"
    return 1
  }
  # ① 会话范围 + 重绘周期：本项目 session 里 dev 窗口在跑；verify 的窗口在**另一个 session**
  tmux kill-session -t "$P10_SCOPE" 2>/dev/null || true
  tmux kill-session -t "$P10_OTHER" 2>/dev/null || true
  tmux new-session -d -s "$P10_SCOPE" -x 120 -y 29 -c "$P10R" -n dev "sleep 300" 2>/dev/null
  tmux new-session -d -s "$P10_OTHER" -x 120 -y 29 -c "$P10R" -n verify "sleep 300" 2>/dev/null
  tmux new-window -d -t "$P10_SCOPE" -n "$P10_W1" -c "$P10R" "$(p10_panel_cmd "$P10_LEFT_LOG" 1)" 2>/dev/null \
    || bad "26-m 真 pane：起面板窗口失败"
  tmux resize-window -t "$P10_SCOPE:$P10_W1" -x 120 -y 29 2>/dev/null || true
  # M20：等首帧（有界轮询）——原来 sleep 4 + resize + sleep 3 是固定等待，负载下还没画完就 capture。
  if P10_CAP="$(p10_wait_pane "$P10_SCOPE:$P10_W1" '巡检' 20)"; then
    ok "26-m 真 pane（120x29）：首帧渲染出标题带（项目/巡检周期，有界轮询 ≤20s，实际 $(p10_wait_ms)ms）"
  else
    bad "26-m 真 pane：20s 内没渲染出标题带（pane=$(tmux capture-pane -p -t "$P10_SCOPE:$P10_W1" 2>/dev/null | wc -c) 字节）"
  fi
  assert_eq "26-m 真 pane：capture 里 0 个 ESC 字节" "$(printf '%s' "$P10_CAP" | tr -cd '\033' | wc -c | tr -d ' ')" "0"
  # M47 翻转证据：Ink 7 的 `is-in-ci` 启发式把任何 CI 环境当**非交互**，而非交互模式只写 <Static>
  # —— 面板一帧都不写，pane 只剩标题带上那个绕过 React 的时钟（CI 上 26-m / wd-logs / 32⑧b 全红）。
  # 夹具在 pane 的 env 里显式放 CI=1（GitHub Actions 的真实形状，TMUX/TTY 都不变），面板必须照常渲染。
  # 翻转：把 main.tsx 的 `interactive: Boolean(process.stdout.isTTY)` 删掉 → 这条（以及下面三条）红。
  P10_CI_SESS="p10-ci-$$"
  tmux kill-session -t "$P10_CI_SESS" 2>/dev/null || true
  tmux new-session -d -s "$P10_CI_SESS" -x 120 -y 29 -c "$P10R" -n panel \
    "$(p10_panel_cmd "$P10_LEFT_LOG" 1 "CI=1")" 2>/dev/null || true
  if P10_CI_CAP="$(p10_wait_pane "$P10_CI_SESS:panel" 'teamsmith pulse' 20)"; then
    ok "26-m CI=1：TTY 里的面板照常渲染（Ink 的 CI 启发式不会吃掉整帧；有界轮询 $(p10_wait_ms)ms）"
  else
    bad "26-m CI=1：20s 内没渲染出面板标题（pane=$(tmux capture-pane -p -t "$P10_CI_SESS:panel" 2>/dev/null | wc -c) 字节）"
  fi
  tmux kill-session -t "$P10_CI_SESS" 2>/dev/null || true
  if printf '%s' "$P10_CAP" | grep -qF 'LEFT-MARKER'; then
    ok "26-m 会话范围：本 session 的 dev 窗口出现在活动列"
  else
    bad "26-m 会话范围：本 session 的 dev 活动没出现"
    # 失败必须带现场（否则只能靠猜）：面板块、窗口尺寸与活动块的原样输出。
    printf '     pane=%sx%s 窗口尺寸
' "$(tmux display -p -t "$P10_SCOPE:$P10_W1" '#{pane_width}' 2>/dev/null)" "$(tmux display -p -t "$P10_SCOPE:$P10_W1" '#{pane_height}' 2>/dev/null)"
    printf '%s\n' "$P10_CAP" | head -14 | sed 's/^/     /'
    ( cd "$P10R" && TEAM_AGENT_LOG_GLOB="$P10_LEFT_LOG" bash "$SKILL_DIR/scripts/team" __panel-data --block activity 2>&1 | head -c 300 | sed 's/^/     activity: /' ) || true
  fi
  if printf '%s' "$P10_CAP" | grep -qF 'FOREIGN-MARKER'; then
    bad "26-m 会话范围：另一个 session 的窗口被显示出来了"
  else
    ok "26-m 会话范围：另一个 session 的窗口不出现（只监视本 session）"
  fi
  # M20：等**时钟自己走**（有界轮询），不再 sleep 1.5 后单次比较 —— 负载下一拍可能还没画出来。
  P10_TS1="$(printf '%s' "$P10_CAP" | head -1 | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}')"
  P10_TS2="$P10_TS1"
  P10_CAP2="$P10_CAP"
  for _p10i in $(seq 1 $((P10_POLL_SECS * 4))); do
    P10_CAP2="$(tmux capture-pane -p -t "$P10_SCOPE:$P10_W1" 2>/dev/null)"
    P10_TS2="$(printf '%s' "$P10_CAP2" | head -1 | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}')"
    [ -n "$P10_TS1" ] && [ -n "$P10_TS2" ] && [ "$P10_TS1" != "$P10_TS2" ] && break
    sleep 0.25
  done
  if [ -n "$P10_TS1" ] && [ -n "$P10_TS2" ] && [ "$P10_TS1" != "$P10_TS2" ]; then
    ok "26-m 重绘：TEAM_MONITOR_REFRESH=1 下时钟自己走了（$P10_TS1 → $P10_TS2，有界轮询 ≤${P10_POLL_SECS}s）"
  else
    bad "26-m 重绘：等满 ${P10_POLL_SECS}s 时间戳都没变（$P10_TS1 / $P10_TS2）"
  fi
  # 轮询失败路径的自检（不假绿）：一个不可能出现的 needle 必须在 1s 内超时。
  # 这条不需要任何环境旋钮：把「轮询其实永远返回 0」这种坏样子钉在门禁里。
  if p10_wait_pane "$P10_SCOPE:$P10_W1" 'M20-NEVER-APPEARS' 1 >/dev/null; then
    bad "26-m 轮询自检：不可能出现的 needle 竟然出现了（轮询是假的）"
  else
    ok "26-m 轮询自检：不可能出现的 needle 在 1s 内超时（失败路径真实，不是永远绿）"
  fi
  # 标题带的时间戳由活时钟给（每秒自走），所以还要两条**数据**证据，把「动作即时回响」与
  # 「节拍重建缓存」分开钉住（V14/F1：动作不能等到 TTL 到期才上屏）：
  # ① 面板里的动作：按 s → 输入理由 → Enter。M20：全程有界轮询（等 compose 打开 → 等回显 →
  #   等标题带），不再用 0.7/0.3/1.5 秒三段固定 sleep —— 负载下「按键被拖到下一拍」不该判红，
  #   但「一直不回响」仍然是红（超时把最后一帧打出来）。
  tmux send-keys -t "$P10_SCOPE:$P10_W1" s 2>/dev/null || true
  if p10_wait_pane "$P10_SCOPE:$P10_W1" 'Enter 进入待命' >/dev/null; then
    tmux send-keys -l -t "$P10_SCOPE:$P10_W1" "action-proof" 2>/dev/null || true
    p10_wait_pane "$P10_SCOPE:$P10_W1" 'action-proof' >/dev/null || true   # 等回显：确认字符进了草稿
    tmux send-keys -t "$P10_SCOPE:$P10_W1" Enter 2>/dev/null || true
    if P10_TITLE_ACT="$(p10_wait_title "$P10_SCOPE:$P10_W1" '待命 on（原因：action-proof）')"; then
      ok "26-m 回响：面板里按 s 进待命，原因在有界轮询内落到标题带（动作后强制失效缓存 + 立即重绘；实际 $(p10_wait_ms)ms）"
    else
      bad "26-m 回响：等满 ${P10_POLL_SECS}s 标题带也没出现待命原因（现在的标题行：$P10_TITLE_ACT）"
    fi
  else
    P10_TITLE_ACT="$(tmux capture-pane -p -t "$P10_SCOPE:$P10_W1" 2>/dev/null | head -1)"
    bad "26-m 回响：按 s 后 ${P10_POLL_SECS}s 内面板没打开待命理由输入（现在的标题行：$P10_TITLE_ACT）"
  fi
  # ② 面板外的改动：只能靠节拍（frame 块 TTL 0.5s < 1s 节拍）。M20：同样等条件（有界轮询）。
  ( cd "$P10R" && TEAM_STATE_DIR="$P10_TRUE_STATE" bash "$SKILL_DIR/scripts/team" --root "$P10R" standby off ) >/dev/null 2>&1 || true
  if P10_TITLE_EXT="$(p10_wait_title "$P10_SCOPE:$P10_W1" '待命 off')"; then
    ok "26-m 节拍：面板外的 standby off 在有界轮询内落到标题带（每拍重建一次缓存；实际 $(p10_wait_ms)ms）"
  else
    P10_TITLE_EXT="$(tmux capture-pane -p -t "$P10_SCOPE:$P10_W1" 2>/dev/null | head -1)"
    bad "26-m 节拍：等满 ${P10_POLL_SECS}s 面板外的改动也没落到标题带（现在的标题行：$P10_TITLE_EXT）"
  fi
  tmux kill-window -t "$P10_SCOPE:$P10_W1" 2>/dev/null || true
  # ② 60x8：不超过窗格
  tmux kill-session -t "$P10_W2" 2>/dev/null || true
  tmux new-session -d -s "$P10_W2" -x 60 -y 8 -c "$P10R" -n panel "$(p10_panel_cmd - 2)" 2>/dev/null || true
  # M20：等首帧（有界轮询）——原来 sleep 4 后 capture，负载下可能一行都没画完。
  if P10_TINY="$(p10_wait_pane "$P10_W2:panel" 'teamsmith' 20)"; then
    ok "26-m 真 pane（60x8）：首帧渲染出来了（有界轮询 ≤20s，实际 $(p10_wait_ms)ms）"
  else
    bad "26-m 真 pane（60x8）：20s 内没渲染出首帧（先不测宽度）"
  fi
  P10_TINY_ROWS="$(printf '%s\n' "$P10_TINY" | grep -c .)"
  P10_TINY_W="$(printf '%s\n' "$P10_TINY" | python3 -c 'import sys,unicodedata
m=0
for l in sys.stdin.read().split("\n"):
    m=max(m, sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in l))
print(m)' 2>/dev/null || echo 999)"
  if [ "$P10_TINY_ROWS" -ge 1 ] && [ "$P10_TINY_ROWS" -le 8 ] && [ "$P10_TINY_W" -le 60 ]; then
    ok "26-m 真 pane（60x8）：$P10_TINY_ROWS 行 / 最宽 $P10_TINY_W 列（不超过窗格）"
  else
    bad "26-m 真 pane（60x8）：$P10_TINY_ROWS 行 / 最宽 $P10_TINY_W 列（超过窗格或没渲染）"
  fi
  tmux kill-session -t "$P10_W2" 2>/dev/null || true
  # ③ tick 节奏：--no-pulse 不写 capacity；默认按周期写；窗口数只多面板自己
  P10_TICK_STATE="$TMP/p10-tick-state"; mkdir -p "$P10_TICK_STATE"
  tmux kill-session -t "$P10_W3" 2>/dev/null || true
  tmux new-session -d -s "$P10_W3" -x 120 -y 29 -c "$P10R" -n panel \
    "cd '$P10R' && HOME='$P10_HOME' TEAM_PI_AGENT_DIR='$P10_HOME/.pi/agent' TEAM_STATE_DIR='$P10_TICK_STATE' TEAM_PULSE_INTERVAL=2 bash '$SKILL_DIR/scripts/team' monitor --no-pulse --interval 1" 2>/dev/null || true
  # M20：先证明面板出了帧（有界轮询），再断言「没写 capacity.log」——否则「没写」可能只是因为
  # 面板根本没起来（假绿）。
  if P10_TICK_LIVE="$(p10_wait_pane "$P10_W3:panel" '巡检' 20)"; then
    if [ -e "$P10_TICK_STATE/capacity.log" ]; then bad "26-m tick：--no-pulse 仍然写了 capacity.log"; else ok "26-m tick：--no-pulse 不写 capacity.log（面板还活着：$(printf '%s' "$P10_TICK_LIVE" | grep -c .) 行，有界轮询 $(p10_wait_ms)ms）"; fi
  else
    if [ -e "$P10_TICK_STATE/capacity.log" ]; then bad "26-m tick：--no-pulse 写了 capacity.log，且面板 20s 内没出帧"; else bad "26-m tick：面板 20s 内没出帧 → 「--no-pulse 没写 capacity.log」无法判定（不算绿）"; fi
  fi
  tmux kill-session -t "$P10_W3" 2>/dev/null || true
  rm -rf "$P10_TICK_STATE"; mkdir -p "$P10_TICK_STATE"
  tmux kill-session -t "$P10_W3" 2>/dev/null || true
  tmux new-session -d -s "$P10_W3" -x 120 -y 29 -c "$P10R" -n panel \
    "cd '$P10R' && HOME='$P10_HOME' TEAM_PI_AGENT_DIR='$P10_HOME/.pi/agent' TEAM_STATE_DIR='$P10_TICK_STATE' TEAM_PULSE_INTERVAL=2 bash '$SKILL_DIR/scripts/team' monitor --interval 1" 2>/dev/null || true
  # M20：等节拍自己走够 2 行（有界轮询）。这一条是**协议等待**（`TEAM_PULSE_INTERVAL=2` 的节拍跑够
  # ≥2 次 = 语义上至少要 2×2s），所以协议时间一点没缩短，仍然要看到 ≥2 行 capacity 才算过；
  # 轮询只是不再把「面板进程启动/首拍」的时间算进固定预算（原来 sleep 6：4s 协议 + 2s 启动余量）。
  P10_TICK_LINES=0
  for _p10i in $(seq 1 $((P10_POLL_SECS * 4))); do
    P10_TICK_LINES="$(wc -l < "$P10_TICK_STATE/capacity.log" 2>/dev/null | tr -d ' ' || echo 0)"
    [ "${P10_TICK_LINES:-0}" -ge 2 ] && break
    sleep 0.25
  done
  if [ "${P10_TICK_LINES:-0}" -ge 2 ]; then
    ok "26-m tick：默认运行按周期留下 capacity 行（$P10_TICK_LINES 行；协议等待 TEAM_PULSE_INTERVAL=2 的 ≥2 拍，有界轮询 ≤${P10_POLL_SECS}s）"
  else
    bad "26-m tick：等满 ${P10_POLL_SECS}s 也没按周期 tick（capacity 行=$P10_TICK_LINES）"
  fi
  assert_eq "26-m tick：tick 日志被裁剪在 200 行以内" \
    "$([ "$(wc -l < "$P10_TICK_STATE/watchdog.tick.log" 2>/dev/null | tr -d ' ' || echo 0)" -le 200 ] && echo ok)" "ok"
  tmux kill-session -t "$P10_W3" 2>/dev/null || true
  tmux kill-session -t "$P10_SCOPE" 2>/dev/null || true
  tmux kill-session -t "$P10_OTHER" 2>/dev/null || true
  assert_eq "26-m 无第二个窗口：smoke session 的窗口数不变" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | wc -l | tr -d ' ')" "$P10_SMOKE_WINDOWS_BEFORE"
  assert_eq "26-m 无第二个窗口：夹具 session 已收干净" \
    "$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -c "^$P10_SCOPE$\|^$P10_OTHER$\|^$P10_W2$\|^$P10_W3$\|^$P10_CI_SESS$" || true)" "0"
  # ④ 没有运行时时 pulse up 拒绝建窗口
  # M40 迁移：这里以前传 TEAM_SESSION="$SESSION"（smoke 自己的 session），而 --root 是 $P10R（它的
  # 配置声明 $P10SESS）——即「env 与目录故意不同」的夹具。M40 起身份以目录为准，那种形状会先被身份
  # 闸门拒掉（拒也拒了，但就不再是「运行时缺失」那条路了）。改成项目自己的 session，并**点名拒绝
  # 理由**：拒绝必须来自运行时检查，不能靠别的门「差不多绿」。
  if env "PATH=$P10_NOJS" "TEAM_AGENT_CMD=true {prompt}" TEAM_AGENT_BIN=true "TEAM_OPENSPEC_BIN=$FAKE/openspec" \
        TEAM_SPEC_DIR=openspec TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_SESSION="$P10SESS" \
        bash "$SKILL_DIR/scripts/team" --root "$P10R" pulse up >"$TMP/p10-up-nojs.log" 2>&1; then
    bad "26-m 运行时：没有运行时时 pulse up 应拒绝"
  else
    ok "26-m 运行时：没有运行时时 pulse up 拒绝（exit 非 0）"
    assert_has "$TMP/p10-up-nojs.log" "缺少 JS 运行时" "26-m 运行时：拒绝理由就是缺少 JS 运行时（不是别的门顺带的）"
  fi
  assert_eq "26-m 运行时：pulse up 没有留下 pulse 窗口" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx pulse || true)" "0"
  # 规格场景写的是旧名（别名期）：`team watchdog up` 走同一条拒绝路径
  if env "PATH=$P10_NOJS" "TEAM_AGENT_CMD=true {prompt}" TEAM_AGENT_BIN=true "TEAM_OPENSPEC_BIN=$FAKE/openspec" \
        TEAM_SPEC_DIR=openspec TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_SESSION="$P10SESS" \
        bash "$SKILL_DIR/scripts/team" --root "$P10R" watchdog up >"$TMP/p10-up-legacy.log" 2>&1; then
    bad "26-m 运行时：没有运行时时 team watchdog up（旧名）也应拒绝"
  else
    ok "26-m 运行时：旧名 team watchdog up 同样拒绝（别名走同一条路径）"
    assert_has "$TMP/p10-up-legacy.log" "缺少 JS 运行时" "26-m 运行时：旧名的拒绝理由同样是缺少 JS 运行时"
  fi

else
  cond_skip "26-m·真 pane" "本机没有 tmux"
fi

# ---------------------------------------------------------------- 27. 面板异步数据层（pulse-console B1，P12）
# 契约来源：openspec/changes/pulse-console/specs/panel/spec.md「Frame assembly is asynchronous,
# cached and never blocks input」+ tasks.md B1（0.1/1.1–1.6）。
# 分段：27-a 块协议（一帧多块、坏块只坏自己）/ 27-b 源坏 → 只降级那一块 / 27-c 快速读者与旧读者同值 /
#      27-d 装配红线 + 渲染路径无同步 spawn。真进程部分（按键失真、60s CPU）是
#      tests/panel-keyprobe.sh 与性能套件里的面板测量（报告里贴日志），smoke 只钉可判定的。
section "27 · 面板异步数据层（pulse-console B1：块协议 / 块隔离 / 快速读者等价 / 装配时间）"

P27R="$TMP/p27-repo"
P27SESS="teamsmith-smoke-p27-$$"
mkdir -p "$P27R"
( cd "$P27R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo "# p27" > README.md && git add -A && git commit -qm init )
p27() { ( cd "$P27R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
            -u TEAM_STATE_DIR -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_MONITOR_ACTIVITY -u TEAM_MONITOR_UI \
            -u TEAM_AGENT_LOG_GLOB "$@" ); }
p27 $TEAM init --session "$P27SESS" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$TMP/p27-init.log" 2>&1 \
  && ok "27 夹具：沙盒 init 退出码 0" || { bad "27 夹具：init 失败"; tail -3 "$TMP/p27-init.log"; }
mkdir -p "$P27R/openspec" "$P27R/.pi/team/state" "$P27R/docs/team/reports" "$P27R/docs/team/reviews"
printf '2026-01-01T00:00:01Z RAM 可用 4000MB ｜ 磁盘 swap 空闲 3000MB ｜ 估算可再加 5 个 agent\n' \
  > "$P27R/.pi/team/state/capacity.log"

# 报告夹具：todo 行（真待复验）、done 行（看板已裁决）、未知 id、closure 名字、草稿、继承副本、
# 带 '-' 的任务 id（最长前缀解析）、主工作树与工作树副本（rank 1/2）
p27 $TEAM board add P27A "P27 夹具报告" dev - >/dev/null 2>&1 || true
p27 $TEAM board add P27B "P27 夹具报告" dev - >/dev/null 2>&1 || true
p27 $TEAM board add P27-2 "P27 夹具报告" dev - >/dev/null 2>&1 || true
p27 $TEAM board set P27B done >/dev/null 2>&1 || true
printf '# P27A · 夹具报告\n\nagent: dev\n' > "$P27R/docs/team/reports/P27A-dev.md"
printf '# P27B · 夹具报告\n\nagent: dev\n' > "$P27R/docs/team/reports/P27B-dev.md"
printf '# P27-2 · 夹具报告\n\nagent: dev\n' > "$P27R/docs/team/reports/P27-2-dev.md"
printf '# P27C · 结项\n' > "$P27R/docs/team/reports/P27C-closure.md"
printf '# 未知任务 · 不是报告\n' > "$P27R/docs/team/reports/P27D-dev.md"
printf '# P27A · 复验\n' > "$P27R/docs/team/reviews/P27A.md"
( cd "$P27R" && git worktree add -q -b task/P27E-x .worktrees/dev main ) >/dev/null 2>&1 || true
P27WT="$P27R/.worktrees/dev"
printf 'task=P27G\n' > "$P27R/.pi/team/state/dev.env"
if [ -d "$P27WT" ]; then
  mkdir -p "$P27WT/docs/team/reports"
  printf '# P27E · 工作树正本\n' > "$P27WT/docs/team/reports/P27E-dev.md"     # rank 1：文件名归属
  printf '# P27B · 继承副本\n' > "$P27WT/docs/team/reports/P27B-verify.md"   # rank 2：别人的旧拷贝
  printf '# P27H · 继承副本（本树没有正本）\n' > "$P27WT/docs/team/reports/P27H-verify.md"  # rank 2，主树无副本
  p27 $TEAM board add P27E "P27 夹具报告" dev - >/dev/null 2>&1 || true
  p27 $TEAM board add P27G "P27 夹具报告" dev - >/dev/null 2>&1 || true
  p27 $TEAM board add P27H "P27 夹具报告" dev - >/dev/null 2>&1 || true
  ( cd "$P27WT" && git add -A && git commit -qm "P27 夹具：工作树报告" ) >/dev/null 2>&1 || true
  printf '# P27G · 还没提交的草稿\n' > "$P27WT/docs/team/reports/P27G-dev.md"   # 草稿：未提交
fi

# ---- 27-a 块协议：一帧拆成块，块名是闭集，每块自己一份 JSON
p27 $TEAM __panel-data --block frame >"$TMP/p27-frame.json" 2>"$TMP/p27-frame.err"
if [ $? -eq 0 ] && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert "project" in d and "standby" in d' "$TMP/p27-frame.json" 2>/dev/null; then
  ok "27-a 块协议：--block frame 一份合法 JSON（project/standby）"
else
  bad "27-a 块协议：--block frame 失败"; tail -2 "$TMP/p27-frame.err"
fi
P27_BLOCK_BAD=0
# B3 起 __panel-data 服务的块是这 16 个（B1 的 8 个 + 控制台三页要的 8 个）：每个都必须 rc=0 + 合法 JSON。
# （第 17 个是详情块 `detail`，它要 `--id`：在 § 28-i 里单独钉，不放进这个无参循环。）
for _b in frame pm pending outbox capacity agents recent activity \
          board changes specs decisions outbox_list inbox patrol health; do
  p27 $TEAM __panel-data --block "$_b" >"$TMP/p27-block-$_b.json" 2>/dev/null || P27_BLOCK_BAD=$((P27_BLOCK_BAD + 1))
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$TMP/p27-block-$_b.json" 2>/dev/null || P27_BLOCK_BAD=$((P27_BLOCK_BAD + 1))
done
assert_eq "27-a 块协议：16 个块名都是 rc=0 + 合法 JSON" "$P27_BLOCK_BAD" "0"
# P18/B3 的详情块（`--id` 是它唯一的额外参数）：同一个协议，另一个入口
p27 $TEAM __panel-data --block detail --id P27A >"$TMP/p27-block-detail.json" 2>/dev/null || P27_BLOCK_BAD=$((P27_BLOCK_BAD + 1))
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["id"] == "P27A" and len(d["files"]) >= 1' "$TMP/p27-block-detail.json" 2>/dev/null || P27_BLOCK_BAD=$((P27_BLOCK_BAD + 1))
assert_eq "27-a 块协议：detail 块（--id）也是 rc=0 + 合法 JSON" "$P27_BLOCK_BAD" "0"
if p27 $TEAM __panel-data --block nope >/dev/null 2>&1; then
  bad "27-a 块协议：未知块名应非 0"
else
  ok "27-a 块协议：未知块名非 0（闭集）"
fi
assert_has "$SKILL_DIR/scripts/panel/src/data.ts" "--block" "27-a 块协议：data.ts 用的是块协议"
if grep -n 'spawnSync' "$SKILL_DIR/scripts/panel/src/data.ts" >"$TMP/p27-spawnsync.log" 2>&1; then
  bad "27-a 无同步 spawn：data.ts 里还有 spawnSync（$(head -1 "$TMP/p27-spawnsync.log")）"
else
  ok "27-a 无同步 spawn：data.ts 里没有 spawnSync（渲染路径不再阻塞事件循环）"
fi

# ---- 27-b 源坏了只降级那一块：BOARD.md 不可读 + 没有 capacity.log
chmod 000 "$P27R/docs/team/BOARD.md"
rm -f "$P27R/.pi/team/state/capacity.log"
p27 $TEAM monitor --print --width 120 --height 29 >"$TMP/p27-degraded.txt" 2>"$TMP/p27-degraded.err"
P27_DEG_RC=$?
assert_eq "27-b 块隔离：--print 在坏源下退出 0" "$P27_DEG_RC" "0"
assert_has "$TMP/p27-degraded.txt" "待办 —" "27-b 块隔离：读不了的 BOARD 让待办块渲染 —"
assert_has "$TMP/p27-degraded.txt" "容量" "27-b 块隔离：没有 capacity.log 让容量块渲染标题"
assert_has "$TMP/p27-degraded.txt" "代理" "27-b 块隔离：其余块照常渲染（agent 表）"
assert_has "$TMP/p27-degraded.txt" "PM " "27-b 块隔离：其余块照常渲染（PM 行）"
assert_not "$TMP/p27-degraded.txt" "延后投递 —" "27-b 块隔离：队列块没有被牵连"
p27 $TEAM __panel-data --block pending >/dev/null 2>&1
assert_eq "27-b 块隔离：--block pending 对坏源返回非 0" "$?" "1"
p27 $TEAM __panel-data --block capacity >/dev/null 2>&1
assert_eq "27-b 块隔离：--block capacity 对坏源返回非 0" "$?" "1"
p27 $TEAM __panel-data --block pm >/dev/null 2>&1
assert_eq "27-b 块隔离：--block pm 不受影响（rc=0）" "$?" "0"
chmod 644 "$P27R/docs/team/BOARD.md"
printf '2026-01-01T00:00:02Z RAM 可用 4001MB ｜ 磁盘 swap 空闲 3000MB ｜ 估算可再加 5 个 agent\n' \
  > "$P27R/.pi/team/state/capacity.log"

# ---- 27-c 快速读者与旧读者同值（同一份夹具、逐行对照）
cat > "$TMP/p27-cmp.sh" <<'EOS'
set -uo pipefail
export TEAM_ROOT="$1" TEAM_CONFIG_FILE="" TEAM_ASSUME_YES=0 TEAM_SKILL_DIR_OVERRIDE=""
D="$2/scripts"
TEAM_SKILL_DIR="$2"
# shellcheck disable=SC1090
. "$D/lib/common.sh"
TEAM_SKILL_DIR="$(team_skill_dir)"
for f in "$D"/lib/cmd-*.sh; do
  # shellcheck disable=SC1090
  . "$f"
done
team_load_config
team_require_docs
team_report_primary_candidates > "$3"
team_panel_report_primary_candidates_fast > "$4"
printf 'canonical_reports=%s\n' "$(team_reports_pending)"
printf 'fast_reports=%s\n' "$(team_panel_reports_pending_fast)"
printf 'canonical_counts=%s\n' "$(team_pending_counts)"
printf 'fast_counts=%s\n' "$(team_panel_pending_counts_fast)"
EOS
# TEAM_SKILL_DIR 由 team_skill_dir 从脚本位置解析，夹具里没有第二个 skill；显式传给子 shell。
(cd "$P27R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
  bash "$TMP/p27-cmp.sh" "$P27R" "$SKILL_DIR" "$TMP/p27-cand-canonical.txt" "$TMP/p27-cand-fast.txt" \
  > "$TMP/p27-cmp.out" 2>"$TMP/p27-cmp.err")
if [ -s "$TMP/p27-cand-canonical.txt" ] && cmp -s "$TMP/p27-cand-canonical.txt" "$TMP/p27-cand-fast.txt"; then
  ok "27-c 快速读者：候选清单与 canonical 逐行一致（$(wc -l < "$TMP/p27-cand-canonical.txt" | tr -d ' ') 行）"
else
  bad "27-c 快速读者：候选清单与 canonical 不一致"; diff "$TMP/p27-cand-canonical.txt" "$TMP/p27-cand-fast.txt" | head -4
fi
P27_CANON_REPORTS="$(sed -n 's/^canonical_reports=//p' "$TMP/p27-cmp.out")"
P27_FAST_REPORTS="$(sed -n 's/^fast_reports=//p' "$TMP/p27-cmp.out")"
P27_CANON_COUNTS="$(sed -n 's/^canonical_counts=//p' "$TMP/p27-cmp.out")"
P27_FAST_COUNTS="$(sed -n 's/^fast_counts=//p' "$TMP/p27-cmp.out")"
assert_eq "27-c 快速读者：待复验数与 canonical 同值" "$P27_FAST_REPORTS" "$P27_CANON_REPORTS"
assert_eq "27-c 快速读者：整条待办计数与 canonical 同值" "$P27_FAST_COUNTS" "$P27_CANON_COUNTS"
if [ -z "$P27_CANON_REPORTS" ]; then
  bad "27-c 夹具自检：等价断言跑空了（canonical 没给出数）"
else
  ok "27-c 夹具自检：等价断言真的在比一个数（reports=$P27_CANON_REPORTS）"
fi

# ---- 27-d 渲染路径无同步 spawn + JSON 形状
# 装配时间红线（帧预算 / 前提 / 中位）已**搬进性能套件**（M58 · perf-suite-split）：正确性门禁不判任何
# 墙钟时长；双向守卫 tests/gate-guard.sh 盯着「门禁里没有判定标记 / 性能套件带着标记」。
p27 $TEAM monitor --json >"$TMP/p27-json.json" 2>/dev/null
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); p=d["panel"]; assert set(["project","timestamp","interval","standby","pm","pending","outbox","capacity","agents","recent"]).issubset(p)' "$TMP/p27-json.json" 2>/dev/null; then
  ok "27-d JSON 形状：健康夹具下 panel 的块字段一个不少（只增不减）"
else
  bad "27-d JSON 形状：health 夹具下 panel 缺块字段"
fi

section "28 · 控制台表面（pulse-console B3：i18n 键集合 / 调色板对比度 / 四档快照 / refresh_s / panel.conf 边界）"
# 这四条断言是任务书 6.1 / 5.3 / 7.2 的「进门禁」出口；每条都有翻转（删一个键 / 坏一组对比度）。
P28_TESTS="$SKILL_DIR/tests"
P28_PANEL="$SKILL_DIR/scripts/panel/panel.js"

# ---- 28-a 字符串表：键集合 + 占位符 + 表外无 CJK 正文；翻转 = 删掉 en 的一个键
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$SRC_ROOT" >"$TMP/p28-strings.log" 2>&1
if [ $? -eq 0 ] && grep -q 'panel-strings: ok' "$TMP/p28-strings.log"; then
  ok "28-a i18n：zh/en 键集合、占位符、表外无 CJK 全部通过"
else
  bad "28-a i18n：字符串表断言失败"; tail -3 "$TMP/p28-strings.log"
fi
P28_TREE="$TMP/p28-tree"; rm -rf "$P28_TREE"
mkdir -p "$P28_TREE/skills/teamsmith/scripts/panel"
cp -r "$SKILL_DIR/scripts/panel/src" "$P28_TREE/skills/teamsmith/scripts/panel/src"
sed -i '/^  keyCompose:/d' "$P28_TREE/skills/teamsmith/scripts/panel/src/strings/en.ts"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P28_TREE" >"$TMP/p28-strings-flip.log" 2>&1
P28_SRC_RC=$?
if [ "$P28_SRC_RC" -ne 0 ] && grep -q 'keyCompose' "$TMP/p28-strings-flip.log"; then
  ok "28-a 翻转：删掉 en.keyCompose 后断言非 0 且点名 keyCompose"
else
  bad "28-a 翻转：删掉 en 的键没被抓住（rc=$P28_SRC_RC）"; tail -3 "$TMP/p28-strings-flip.log"
fi

# ---- 28-a2 契约键标签（M49）：`lib/cmd-config.sh` 的 schema 每个键在 zh/en 两张表里都有非空
# 标签，且没有表里的标签指着一个 schema 已不存在的键（两个方向都查）。翻转有两条：① 从**两张表**
# 各删一条标签（键集合仍一致 → 只有这条断言能抓住）；② 从 schema 删一行（标签变成陈旧 → 反向断言抓住）。
P28_LBL="$TMP/p28-labels"; rm -rf "$P28_LBL"
mkdir -p "$P28_LBL/skills/teamsmith/scripts/panel" "$P28_LBL/skills/teamsmith/scripts/lib"
cp -r "$SKILL_DIR/scripts/panel/src" "$P28_LBL/skills/teamsmith/scripts/panel/src"
cp "$SKILL_DIR/scripts/lib/cmd-config.sh" "$P28_LBL/skills/teamsmith/scripts/lib/"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P28_LBL" >"$TMP/p28-labels.log" 2>&1
P28_LBL_RC=$?
if [ "$P28_LBL_RC" -eq 0 ] && grep -q 'contract-key labels' "$TMP/p28-labels.log"; then
  ok "28-a2 契约键标签：schema 的每个键在 zh/en 两张表里都有标签（$(grep -oE '[0-9]+ schema keys' "$TMP/p28-labels.log" | head -1)）"
else
  bad "28-a2 契约键标签：断言失败"; tail -3 "$TMP/p28-labels.log"
fi
sed -i '/^  label_TEAM_PULSE_INTERVAL:/d' \
  "$P28_LBL/skills/teamsmith/scripts/panel/src/strings/zh.ts" \
  "$P28_LBL/skills/teamsmith/scripts/panel/src/strings/en.ts"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P28_LBL" >"$TMP/p28-labels-flip.log" 2>&1
P28_LBL_FLIP_RC=$?
if [ "$P28_LBL_FLIP_RC" -ne 0 ] && grep -q 'TEAM_PULSE_INTERVAL' "$TMP/p28-labels-flip.log"; then
  ok "28-a2 翻转①：两张表都删掉 label_TEAM_PULSE_INTERVAL 后断言非 0 且点名该键"
else
  bad "28-a2 翻转①：删掉的标签没被抓住（rc=$P28_LBL_FLIP_RC）"; tail -3 "$TMP/p28-labels-flip.log"
fi
rm -rf "$P28_LBL/skills/teamsmith/scripts/panel/src"
cp -r "$SKILL_DIR/scripts/panel/src" "$P28_LBL/skills/teamsmith/scripts/panel/src"
sed -i '/^TEAM_MEETING_KNOCK|/d' "$P28_LBL/skills/teamsmith/scripts/lib/cmd-config.sh"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P28_LBL" >"$TMP/p28-labels-stale.log" 2>&1
P28_LBL_STALE_RC=$?
if [ "$P28_LBL_STALE_RC" -ne 0 ] && grep -q 'TEAM_MEETING_KNOCK' "$TMP/p28-labels-stale.log"; then
  ok "28-a2 翻转②：schema 删掉一行后，留下的标签被抓住（点名 TEAM_MEETING_KNOCK）"
else
  bad "28-a2 翻转②：陈旧的标签没被抓住（rc=$P28_LBL_STALE_RC）"; tail -3 "$TMP/p28-labels-stale.log"
fi

# ---- 28-b 调色板对比度 ≥ 4.5:1；翻转 = 把 dark.text 压到与背景同色
"$JS_RUNNER" "$P28_TESTS/panel-contrast.mjs" "$P28_PANEL" >"$TMP/p28-contrast.log" 2>&1
if [ $? -eq 0 ] && grep -q 'panel-contrast: ok' "$TMP/p28-contrast.log"; then
  ok "28-b 调色板：深浅两套主题的每一组声明配对 ≥ 4.5:1"
else
  bad "28-b 调色板：对比度断言失败"; tail -3 "$TMP/p28-contrast.log"
fi
"$JS_RUNNER" "$P28_PANEL" --palette >"$TMP/p28-palette.json" 2>/dev/null
python3 - "$TMP/p28-palette.json" "$TMP/p28-palette-bad.json" <<'PYB'
import json, sys
d = json.load(open(sys.argv[1]))
d["palettes"]["dark"]["tones"]["text"] = d["palettes"]["dark"]["bg"]
json.dump(d, open(sys.argv[2], "w"))
PYB
"$JS_RUNNER" "$P28_TESTS/panel-contrast.mjs" --palette-file "$TMP/p28-palette-bad.json" >"$TMP/p28-contrast-flip.log" 2>&1
P28_CON_RC=$?
if [ "$P28_CON_RC" -ne 0 ] && grep -q 'dark.text' "$TMP/p28-contrast-flip.log"; then
  ok "28-b 翻转：把 dark.text 压到背景色后断言非 0 且点名 dark.text"
else
  bad "28-b 翻转：坏调色板没被抓住（rc=$P28_CON_RC）"; tail -3 "$TMP/p28-contrast-flip.log"
fi

# ---- 28-c 四档宽度 × 深浅两套主题的快照逐字节一致（tests/snapshots/ 里钉住）
TEAM_SNAPSHOTS_JS="$JS_RUNNER" bash "$P28_TESTS/panel-snapshots.sh" >"$TMP/p28-snapshots.log" 2>&1
if [ $? -eq 0 ] && grep -q 'panel-snapshots 全绿' "$TMP/p28-snapshots.log"; then
  ok "28-c 快照：4 档宽度 × 2 主题 + 60x8 极小 pane 全部逐字节一致"
else
  bad "28-c 快照：快照套件失败"; tail -6 "$TMP/p28-snapshots.log"
fi

# ---- 28-d TEAM_MONITOR_REFRESH 默认 3s 且出现在 --json；config.md 点明新默认
# 规格场景的前提是「TEAM_MONITOR_REFRESH 未设」。夹具是用 `team init` 建的，而脚手架模板
# （templates/config.sh.tmpl，PM 所有）今天还写着 TEAM_MONITOR_REFRESH=5 —— 所以先把那一行删掉，
# 让前提真的成立（PM 把模板默认改成 3 之后这段依旧正确）。见报告的 PM 待办项。
sed -i '/^TEAM_MONITOR_REFRESH=/d' "$P27R/.pi/team/config.sh"
p27 env -u TEAM_MONITOR_REFRESH "${p28cap[@]}" $TEAM monitor --json >"$TMP/p28-refresh-default.json" 2>/dev/null
p27 env TEAM_MONITOR_REFRESH=7 "${p28cap[@]}" $TEAM monitor --json >"$TMP/p28-refresh-7.json" 2>/dev/null
if p10_py "$TMP/p28-refresh-default.json" 'p["refresh_s"] == 3' 2>/dev/null \
   && p10_py "$TMP/p28-refresh-7.json" 'p["refresh_s"] == 7' 2>/dev/null; then
  ok "28-d refresh_s：未设时 3、设 7 时 7（且是 --json 的只增字段）"
else
  bad "28-d refresh_s：--json 里的值不对（$(p10_py "$TMP/p28-refresh-default.json" 'print(p.get("refresh_s"))' 2>/dev/null) / $(p10_py "$TMP/p28-refresh-7.json" 'print(p.get("refresh_s"))' 2>/dev/null)）"
fi
assert_match "$SKILL_DIR/references/config.md" '^\| `TEAM_MONITOR_REFRESH` \| `3`' "28-d config.md：TEAM_MONITOR_REFRESH 的默认写成 3"

# ---- 28-e panel.conf 是运行时偏好：机读出口 --print/--json 完全不读它
p28cap=(TEAM_MEMINFO_FILE="$TMP/meminfo-plenty" TEAM_SWAPFILE_PATH="$TMP/swaps")
printf 'lang=en\npage=3\nactivity=0\nmouse=0\ndensity=compact\ntheme=light\n' >"$P27R/.pi/team/state/panel.conf"
p27 env "${p28cap[@]}" $TEAM monitor --json >"$TMP/p28-conf-a.json" 2>/dev/null
p27 env "${p28cap[@]}" $TEAM monitor --print >"$TMP/p28-conf-a.txt" 2>/dev/null
printf 'lang=zh\npage=1\nactivity=1\nmouse=1\ndensity=comfortable\ntheme=dark\n' >"$P27R/.pi/team/state/panel.conf"
p27 env "${p28cap[@]}" $TEAM monitor --json >"$TMP/p28-conf-b.json" 2>/dev/null
p27 env "${p28cap[@]}" $TEAM monitor --print >"$TMP/p28-conf-b.txt" 2>/dev/null
rm -f "$P27R/.pi/team/state/panel.conf"
P28_NORM() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/' "$1"; }
# 逐字段对比并跳过时间戳：失败时说清是哪个字段变了，而不是丢两行 2000 字符的 JSON。
P28_JSON_DIFF="$(python3 - "$TMP/p28-conf-a.json" "$TMP/p28-conf-b.json" <<'PYJ'
import json, sys

a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))

def walk(x, y, path=""):
    if isinstance(x, dict) and isinstance(y, dict):
        for k in sorted(set(x) | set(y)):
            yield from walk(x.get(k), y.get(k), f"{path}.{k}")
    elif isinstance(x, list) and isinstance(y, list):
        if len(x) != len(y):
            yield f"{path}: list len {len(x)} != {len(y)}"
        else:
            for i, (p, q) in enumerate(zip(x, y)):
                yield from walk(p, q, f"{path}[{i}]")
    elif x != y:
        yield f"{path}: {x!r} != {y!r}"

for line in walk(a, b):
    if line.endswith(".panel.timestamp" + f": {a['panel']['timestamp']!r} != {b['panel']['timestamp']!r}"):
        continue
    print(line)
PYJ
)"
if [ -z "$P28_JSON_DIFF" ]; then
  ok "28-e panel.conf：两种偏好的 --json 只差时间戳（机读出口不读偏好）"
else
  bad "28-e panel.conf：偏好改变了 --json：$(printf '%s' "$P28_JSON_DIFF" | head -2 | tr '\n' ' ')"
fi
if diff <(P28_NORM "$TMP/p28-conf-a.txt") <(P28_NORM "$TMP/p28-conf-b.txt") >/dev/null; then
  ok "28-e panel.conf：两种偏好的 --print 只差时间戳"
else
  bad "28-e panel.conf：偏好改变了 --print"; diff <(P28_NORM "$TMP/p28-conf-a.txt") <(P28_NORM "$TMP/p28-conf-b.txt") | head -3
fi
if grep -q '▸' "$TMP/p28-conf-a.txt"; then
  bad "28-e --print 里出现了页签标记（页是 TUI 概念）"
else
  ok "28-e --print 没有页签标记（页是 TUI 概念）"
fi
if grep -q '"blocks"' "$TMP/p28-conf-a.json"; then
  bad "28-e --json 里混进了控制台专用块"
else
  ok "28-e --json 只有原契约的字段（控制台专用块不进机读出口）"
fi

# ---- 28-f 每个文档化按键都有点击目标（键位行 + 页签 + 队列行）
p28_targets() { # <page>
  "$JS_RUNNER" "$P28_PANEL" --snapshot --targets --root "$TMP" --state-dir "$TMP/p28-state" \
    --team-cli "$P28_TESTS/panel-b3-stub.sh" --width 160 --height 32 --page "$1" 2>/dev/null
}
p28_kinds() { # <file>
  python3 - "$1" <<'PYT'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:  # pytest-style: a broken output is a failed assertion, not a crash
    print(f"<unreadable: {e}>")
else:
    print(",".join(sorted({t["action"]["kind"] for t in data})))
PYT
}
p28_targets 1 >"$TMP/p28-targets-p1.json" 2>/dev/null
P28_KINDS1="$(p28_kinds "$TMP/p28-targets-p1.json")"
for _k in compose flush standby settings page-cycle scroll quit page; do
  case ",$P28_KINDS1," in
    *",$_k,"*) ok "28-f 点击目标：$_k 有目标" ;;
    *) bad "28-f 点击目标：$_k 没有目标（$P28_KINDS1）" ;;
  esac
done
p28_targets 3 >"$TMP/p28-targets-p3.json" 2>/dev/null
P28_KINDS3="$(p28_kinds "$TMP/p28-targets-p3.json")"
case ",$P28_KINDS3," in
  *",view-entry,"*) ok "28-f 点击目标：队列行可点开全文（view-entry）" ;;
  *) bad "28-f 点击目标：队列行没有 view-entry 目标（$P28_KINDS3）" ;;
esac


# ---- 28-g 有界帧（P18/B1，用户亲口要的红线）：帧高恰好等于给定高度、页脚在最后一行
# 回归守门：layout() 以前只按自然内容高度出帧、App 在下面补白，页脚浮在帧中间（PM 截图实测）。
# 夹具要「自然内容 ~30 行」才测得出：stub 的 B3_STUB_AGENTS / B3_STUB_RECENT 两个确定性旋钮撑到 30 行。
# 还有一条不变式：未封顶的 --print 不许长高（把有界帧里页脚前的连续空行剔掉后，两者逐行一致）。
P28G_FX="$TMP/p28g"; rm -rf "$P28G_FX"; mkdir -p "$P28G_FX/state"
p28g_frame() { # <width> <height>：固定夹具的一帧（--print 无转义、不 tick）
  ( cd "$P27R" && env B3_STUB_AGENTS=18 B3_STUB_RECENT=14 \
      "$JS_RUNNER" "$P28_PANEL" --print --root "$P28G_FX" --state-dir "$P28G_FX/state" \
      --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --events 14 \
      --width "$1" --height "$2" 2>/dev/null )
}
p28g_frame_uncapped() {
  ( cd "$P27R" && env B3_STUB_AGENTS=18 B3_STUB_RECENT=14 \
      "$JS_RUNNER" "$P28_PANEL" --print --root "$P28G_FX" --state-dir "$P28G_FX/state" \
      --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --events 14 \
      --width 120 2>/dev/null )
}
for p28g_spec in "120 40" "99 50" "59 12"; do
  set -- $p28g_spec
  p28g_frame "$1" "$2" >"$TMP/p28g-$1x$2.txt"
  assert_eq "28-g 有界帧 $1x$2：恰好 $2 行（帧不再低于给定高度）" \
    "$(wc -l < "$TMP/p28g-$1x$2.txt" | tr -d ' ')" "$2"
  if tail -1 "$TMP/p28g-$1x$2.txt" | grep -q '写信'; then
    ok "28-g 有界帧 $1x$2：末行是键位带（页脚钉底）"
  else
    bad "28-g 有界帧 $1x$2：末行不是键位带（$(tail -1 "$TMP/p28g-$1x$2.txt" | cut -c1-40)）"
  fi
done
p28g_frame_uncapped >"$TMP/p28g-uncapped.txt"
P28G_UNCAPPED="$(python3 - "$TMP/p28g-120x40.txt" "$TMP/p28g-uncapped.txt" <<'PYG'
import re, sys


def norm(lines):
    return [re.sub(r"[0-9]{2}:[0-9]{2}:[0-9]{2}", "TIME", l.rstrip("\n")) for l in lines]


bounded = norm(open(sys.argv[1], encoding="utf-8").read().splitlines(True))
uncapped = norm(open(sys.argv[2], encoding="utf-8").read().splitlines(True))
# Drop the maximal run of empty rows directly above the footer: that run is exactly the filler the
# bounded frame adds, and it must be the *only* difference to the uncapped frame.
body = bounded[:-1]
while body and body[-1].strip() == "":
    body.pop()
body.append(bounded[-1])
print("ok" if body == uncapped else f"bounded-minus-filler({len(body)}) != uncapped({len(uncapped)})")
PYG
)"
assert_eq "28-g 未封顶 --print 不涨：有界帧剔掉填充空行后与它逐行一致" "$P28G_UNCAPPED" "ok"
assert_has "$TMP/p28g-uncapped.txt" "写信" "28-g 未封顶帧仍以键位带收尾（没有填充行）"


# ---- 28-h 看板页（P18/B2）：六车道 / 降级档 / 焦点 / 目标 / panel-page 与 defaultPage
# 契约：openspec/specs + change console-board-page 的「composes four pages」「board page is a kanban」
# 「Every key affordance is also a mouse target」。真 pty 部分在 tests/panel-b3.sh board（焦点重排、
# 滚动、鼠标），这里钉可判定的：帧内容、降级档、目标表、以及 panel.conf 的第四页。
P28H_FX="$TMP/p28h"; rm -rf "$P28H_FX"; mkdir -p "$P28H_FX/state"
p28h_frame() { # <width> <height> [额外 args…]
  local w="$1" h="$2"; shift 2
  ( cd "$P27R" && "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28H_FX" --state-dir "$P28H_FX/state" \
      --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width "$w" --height "$h" --page 4 "$@" 2>/dev/null )
}
p28h_frame 160 40 >"$TMP/p28h-160.txt"
assert_eq "28-h 看板页 160x40：帧高恰好 40（有界帧）" "$(wc -l < "$TMP/p28h-160.txt" | tr -d ' ')" "40"
for lane in 待办 进行 待复验 完成 阻塞 已放弃; do
  assert_has "$TMP/p28h-160.txt" "$lane" "28-h 六车道之一渲染：$lane"
done
assert_has "$TMP/p28h-160.txt" "P14" "28-h 看板页有 P14 卡片"
assert_has "$TMP/p28h-160.txt" "apply" "28-h 卡片带任务书 phase（P14=apply）"
P28H_CURSORS="$(grep -o '›' "$TMP/p28h-160.txt" | wc -l | tr -d ' ')"
assert_eq "28-h 焦点光标恰好一个（首条非空车道的首卡）" "$P28H_CURSORS" "1"
assert_has "$TMP/p28h-160.txt" "Tab/1-4" "28-h 键位带说明翻页键到 4"
assert_has "$TMP/p28h-160.txt" "←/→ 车道" "28-h 看板页键位带给出车道键"
assert_has "$TMP/p28h-160.txt" "Enter 打开" "28-h 看板页键位带给出打开键"
assert_has "$TMP/p28h-160.txt" "[看板]" "28-h 页签高亮在第四页"

# 降级档：<100 单列分组；<60 卡片一行（没有 agent 列）
p28h_frame 99 40 >"$TMP/p28h-99.txt"
p28h_frame 59 40 >"$TMP/p28h-59.txt"
P28H_59_AGENT="$(grep -c ' verify\| dev ' "$TMP/p28h-59.txt" || true)"
assert_eq "28-h 59 列：卡片缩成一行，没有 agent 字段" "$P28H_59_AGENT" "0"
assert_has "$TMP/p28h-59.txt" "独立复验" "28-h 59 列的卡片仍带标题"

# 目标表：卡片可点（focus），焦点卡上是 open；键位 chip 也在表里；`r` 永远不在（V16 F-V16-5）
p28_targets 4 >"$TMP/p28h-targets-p4.json" 2>/dev/null
P28H_KINDS="$(p28_kinds "$TMP/p28h-targets-p4.json")"
case ",$P28H_KINDS," in
  *",focus,"*) ok "28-h 目标表：卡片有 focus 目标" ;;
  *) bad "28-h 目标表：没有 focus 目标（$P28H_KINDS）" ;;
esac
case ",$P28H_KINDS," in
  *",open-focused,"*) ok "28-h 目标表：焦点卡有 open 目标" ;;
  *) bad "28-h 目标表：没有 open-focused 目标（$P28H_KINDS）" ;;
esac
case ",$P28H_KINDS," in
  *",lane-move,"*|*",card-move,"*) ok "28-h 目标表：车道/卡片键有目标" ;;
  *) bad "28-h 目标表：车道/卡片键没有目标（$P28H_KINDS）" ;;
esac
case ",$P28H_KINDS," in
  *",refresh,"*) bad "28-h 目标表里不该有刷新目标（r 是键盘专用）" ;;
  *) ok "28-h 目标表里没有刷新目标（r 键盘专用）" ;;
esac
# 只有焦点卡带 open：open-focused 目标恰好一个
# The key band's own `Enter 打开` chip is an open target too — count the ones in the card region
# (everything above the last row, which is the key band).
P28H_OPEN="$(python3 - "$TMP/p28h-targets-p4.json" <<'PYO'
import json, sys
data = json.load(open(sys.argv[1]))
last = max((t["row"] for t in data), default=-1)
print(sum(1 for t in data if t["action"]["kind"] == "open-focused" and t["row"] != last))
PYO
)"
assert_eq "28-h open 目标只存在于焦点卡上（卡片区恰好一个）" "$P28H_OPEN" "1"

# panel.conf 的第四页：机读入口不读它，但 TUI 会用 defaultPage —— 用 --snapshot 走 settings.defaultPage
mkdir -p "$TMP/p28h/state"
printf 'lang=zh\npage=4\nactivity=1\nmouse=1\ndensity=comfortable\ntheme=dark\n' >"$TMP/p28h/state/panel.conf"
( cd "$P27R" && "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28H_FX" --state-dir "$P28H_FX/state" \
    --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 30 2>/dev/null ) >"$TMP/p28h-conf4.txt"
assert_has "$TMP/p28h-conf4.txt" "已放弃" "28-h panel.conf page=4：无 --page 时按第四页起（defaultPage 覆盖四页）"
rm -f "$TMP/p28h/state/panel.conf"

# ---- 28-h2 工作页的看板行（P20/B5）：行可聚焦、行键有目标；降级/空看板没有死项
# 契约：change panel-ergonomics 的「The work page's board rows are focusable and open the same
# detail view」与「Every key affordance is also a mouse target」（pageUp/pageDown 是第二条键盘
# 专用例外）。真 pty 部分在 tests/panel-b3.sh workdetail（焦点行走、详情原地返回、点击、降级）。
p28_targets 2 >"$TMP/p28hd-targets-p2.json" 2>/dev/null
P28HD_KINDS="$(p28_kinds "$TMP/p28hd-targets-p2.json")"
case ",$P28HD_KINDS," in
  *",focus,"*) ok "28-h2 工作页目标表：看板行可聚焦（focus）" ;;
  *) bad "28-h2 工作页目标表：没有 focus 目标（$P28HD_KINDS）" ;;
esac
case ",$P28HD_KINDS," in
  *",open-focused,"*) ok "28-h2 工作页目标表：焦点行可打开（open-focused）" ;;
  *) bad "28-h2 工作页目标表：没有 open-focused 目标（$P28HD_KINDS）" ;;
esac
case ",$P28HD_KINDS," in
  *",card-move,"*) ok "28-h2 工作页目标表：行键有目标（card-move）" ;;
  *) bad "28-h2 工作页目标表：行键没有目标（$P28HD_KINDS）" ;;
esac
case ",$P28HD_KINDS," in
  *",lane-move,"*) bad "28-h2 工作页目标表不该有车道键（lane-move 属看板页）" ;;
  *) ok "28-h2 工作页目标表没有车道键（车道逻辑只在看板页）" ;;
esac
if grep -aqi 'pageup\|pagedown' "$TMP/p28hd-targets-p2.json"; then
  bad "28-h2 pageUp/pageDown 混进了目标表"
else
  ok "28-h2 pageUp/pageDown 不在目标表里（第二条键盘专用例外）"
fi
# 降级（60x10）：块塌陷成一行 → 没有行、没有行键、没有行目标
"$JS_RUNNER" "$P28_PANEL" --snapshot --targets --root "$TMP" --state-dir "$TMP/p28-state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 60 --height 10 --page 2 \
  >"$TMP/p28hd-degraded.json" 2>/dev/null
P28HD_DEG="$(p28_kinds "$TMP/p28hd-degraded.json")"
case ",$P28HD_DEG," in
  *",focus,"*|*",open-focused,"*) bad "28-h2 60x10 降级的工作页还有行目标（$P28HD_DEG）" ;;
  *) ok "28-h2 60x10 降级的工作页没有行目标（$P28HD_DEG）" ;;
esac
# 空看板：没有行、没有行目标（无死项）
printf '{"rows": [], "counts": {}, "total": 0, "deliveries": []}\n' >"$TMP/p28hd-empty.json"
B3_STUB_BOARD_FILE="$TMP/p28hd-empty.json" "$JS_RUNNER" "$P28_PANEL" --snapshot --targets --root "$TMP" \
  --state-dir "$TMP/p28-state" --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark \
  --width 120 --height 32 --page 2 >"$TMP/p28hd-empty-targets.json" 2>/dev/null
P28HD_EMPTY="$(p28_kinds "$TMP/p28hd-empty-targets.json")"
case ",$P28HD_EMPTY," in
  *",focus,"*|*",open-focused,"*) bad "28-h2 空看板的工作页还有行目标（$P28HD_EMPTY）" ;;
  *) ok "28-h2 空看板的工作页没有行目标（$P28HD_EMPTY）" ;;
esac


# ---------------------------------------------------------------- 29. 派单模型解析：配置压过名册旧记录（M14）
# 契约（真实事故：TEAM_AGENT_MODELS 已配 dev=kimi-coding/k3-256k，dispatch 仍按名册 state 里的
# deepseek 旧记录启动 —— 旧实现 model="${model:-$(state_get model (config))}" 让旧记录赢了配置）：
#   ① 解析顺序 = --model 显式 ＞ 配置（TEAM_AGENT_MODELS per-agent ＞ TEAM_DEFAULT_MODEL）；
#      名册 state 的 model 只是「上次用了什么」的展示记录，不再参与解析；
#   ② 配置改了，下一次派单立即生效（不需要先清 state）；
#   ③ roster/ps 的模型列标注来源（配置/显式/历史记录），旧记录不再冒充当前配置。
# 全程在自己的临时仓库里跑（写盘前先证明身份），dispatch 只走 --print（纯逻辑，快慢模式都跑）。
# ---- 28-i markdown 详情（P18/B3）：读者（发现 / id 边界 / 路径拒绝 / 128KiB 上限）+ 渲染子集 + 目标 + 空载成本
# 契约：change console-board-page 的「A focused card opens a read-only markdown detail view」与
#「Every key affordance is also a mouse target」（详情打开时看板卡片不留目标）。真 pty 部分在
# panel-b3.sh detail（打开/返回、tab、滚动、只读证明、首帧计时），这里钉可判定的读者与渲染。
P28I_FX="$TMP/p28i"; rm -rf "$P28I_FX"; mkdir -p "$P28I_FX/state"
P28I_TASKS="$P27R/docs/team/tasks"
mkdir -p "$P28I_TASKS" "$P27R/docs/team/reports/P1-dev/pkg"
printf '# P1 · 夹具任务书\n\nphase: apply\n' > "$P28I_TASKS/P1-a.md"
printf '# P17 · 诱饵\n' > "$P28I_TASKS/P17-b.md"
printf '# P1 · 交付报告\n' > "$P27R/docs/team/reports/P1-dev.md"
printf '# P1 · 复验\n' > "$P27R/docs/team/reviews/P1.md"
printf '# P1 · 复验（完成）\n' > "$P27R/docs/team/reviews/P1-done.md"
printf '# 包目录里的文件（不是报告）\n' > "$P27R/docs/team/reports/P1-dev/pkg/note.md"
p27 $TEAM __panel-data --block detail --id P1 >"$TMP/p28i-detail.json" 2>"$TMP/p28i-detail.err"
P28I_RC=$?
assert_eq "28-i 读者：--block detail --id P1 退出 0" "$P28I_RC" "0"
P28I_CHK="$(python3 - "$TMP/p28i-detail.json" <<'PYI'
import json, sys

try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:  # a broken output is a failed assertion, not a crash
    print(f"无法解析：{e}")
else:
    tabs = [f["tab"] for f in d["files"]]
    paths = [f["path"] for f in d["files"]]
    problems = []
    if tabs != ["brief", "report:dev", "review", "review:done"]:
        problems.append(f"tab 次序不对：{tabs}")
    if any("P17" in p for p in paths):
        problems.append("P17 诱饵混进来了")
    if any("/pkg/" in p for p in paths):
        problems.append("报告包目录被当成了文件")
    if d.get("file") != "docs/team/tasks/P1-a.md":
        problems.append(f"默认服务的文件是 {d.get('file')}")
    print("ok" if not problems else "；".join(problems))
PYI
)"
assert_eq "28-i 读者：恰好四个关联文件、id 边界成立、包目录不算文件" "$P28I_CHK" "ok"
# 7.2：--file 只服务发现集里的路径，其余一律非 0 且不打印正文
p27 $TEAM __panel-data --block detail --id P1 --file '../../BOARD.md' >"$TMP/p28i-escape.out" 2>"$TMP/p28i-escape.err"
P28I_ESC_RC=$?
p27 $TEAM __panel-data --block detail --id P1 --file docs/team/tasks/P17-b.md >"$TMP/p28i-decoy.out" 2>"$TMP/p28i-decoy.err"
P28I_DECOY_RC=$?
assert_eq "28-i 读者：--file ../../BOARD.md 非 0（路径穿越被拒）" "$P28I_ESC_RC" "1"
assert_eq "28-i 读者：--file 另一个 id 的文件非 0" "$P28I_DECOY_RC" "1"
if [ ! -s "$TMP/p28i-escape.out" ] && [ ! -s "$TMP/p28i-decoy.out" ]; then
  ok "28-i 读者：被拒的 --file 一个字节正文都没打印"
else
  bad "28-i 读者：被拒的 --file 仍然打印了内容"
fi
p27 $TEAM __panel-data --block detail --id P1 --file docs/team/reviews/P1-done.md >"$TMP/p28i-ok.json" 2>/dev/null
P28I_OK_RC=$?
P28I_OK_FILE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["file"])' "$TMP/p28i-ok.json" 2>/dev/null)"
assert_eq "28-i 读者：合法的 --file 退出 0" "$P28I_OK_RC" "0"
assert_eq "28-i 读者：合法的 --file 服务的就是那个文件" "$P28I_OK_FILE" "docs/team/reviews/P1-done.md"
# 7.3：200 KiB 的报告被截断、退出 0、一秒内
python3 - "$P27R/docs/team/reports/P2-dev.md" <<'PYB'
import sys

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    for i in range(4200):
        fh.write(f"line {i:04d} " + "x" * 40 + "\n")
PYB
P28I_T0="$(date +%s.%N)"
p27 $TEAM __panel-data --block detail --id P2 >"$TMP/p28i-big.json" 2>/dev/null
P28I_BIG_RC=$?
P28I_T1="$(date +%s.%N)"
P28I_BIG_CHK="$(python3 - "$TMP/p28i-big.json" <<'PYC'
import json, sys

d = json.load(open(sys.argv[1], encoding="utf-8"))
problems = []
if not d.get("truncated"):
    problems.append("truncated 不为真")
if len(d.get("text", "")) != 131072:
    problems.append(f"正文长度 {len(d.get('text', ''))} != 131072")
if not d.get("files") or not d["files"][0].get("truncated"):
    problems.append("文件条目没带 truncated 标记")
print("ok" if not problems else "；".join(problems))
PYC
)"
assert_eq "28-i 读者：200 KiB 报告退出 0" "$P28I_BIG_RC" "0"
assert_eq "28-i 读者：200 KiB 报告截断到 128 KiB 并带 truncated 标记" "$P28I_BIG_CHK" "ok"
P28I_SECS="$(awk -v a="$P28I_T0" -v b="$P28I_T1" 'BEGIN { printf "%.3f", b - a }')"
if awk -v s="$P28I_SECS" 'BEGIN { exit !(s < 1.0) }'; then
  ok "28-i 读者：200 KiB 报告在一秒内返回（${P28I_SECS}s）"
else
  bad "28-i 读者：200 KiB 报告用了 ${P28I_SECS}s（>1s）"
fi

# 8.1：渲染子集——标题去标记、围栏原样、表格按显示宽度对齐、子集外的构造原样保留
python3 - "$TMP/p28i-render.json" <<'PYR'
import json, sys

border = "\u001b[2J"
doc = "\n".join([
    "# X1 · 渲染夹具",
    "",
    "段落带 **粗体**、`代码` 和 [链接](https://example.invalid/x)。",
    "",
    "- 列表一",
    "- 列表二",
    "",
    "> 引用一行",
    "",
    "```sh",
    'echo "围栏原样"',
    "```",
    "",
    "| id | state | note |",
    "|:---|:------:|-----:|",
    "| P1 | wip | 短 |",
    "| P22 | done | 更长的说明 |",
    "",
    "<div>子集外的一行</div>",
    "",
    "---",
    "",
    "尾段。",
])
json.dump({"id": "X1", "count": 1, "file": "docs/team/tasks/X1-a.md", "text": doc, "truncated": False,
           "files": [{"tab": "brief", "name": "X1-a.md", "path": "docs/team/tasks/X1-a.md", "size": len(doc), "truncated": False}]},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PYR
B3_STUB_DETAIL_FILE="$TMP/p28i-render.json" "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28I_FX" --state-dir "$P28I_FX/state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 40 --page 4 --detail X1 \
  >"$TMP/p28i-render.txt" 2>"$TMP/p28i-render.err"
P28I_RENDER_RC=$?
assert_eq "28-i 渲染：子集夹具退出 0（没有构造会抛错）" "$P28I_RENDER_RC" "0"
P28I_RENDER_CHK="$(python3 - "$TMP/p28i-render.txt" <<'PYE'
import re, sys

rows = [re.sub(r"\x1b\[[0-9;]*m", "", l.rstrip("\n")) for l in open(sys.argv[1], encoding="utf-8")]
joined = "\n".join(rows)
problems = []
if re.search(r"^\s*#\s", joined, re.M) or "# X1" in joined:
    problems.append("ATX 标题还带着 # 标记")
if 'echo "围栏原样"' not in joined:
    problems.append("围栏正文没有原样渲染")
if "<div>子集外的一行</div>" not in joined:
    problems.append("子集外的构造被丢掉了（应原样保留）")
header = next((r for r in rows if "id" in r and "state" in r and "note" in r), "")
sep = next((r for r in rows if "┼" in r), "")
body = next((r for r in rows if "P22" in r), "")
if not (header and sep and body):
    problems.append("管道表格没有渲染")
else:
    def marks(row, chars):
        return [i for i, ch in enumerate(row) if ch in chars]
    hx, sx, bx = marks(header, "│")[1:-1], marks(sep, "┼"), marks(body, "│")[1:-1]
    if not (hx == sx == bx) or len(hx) != 2:
        problems.append(f"表格列没有按显示宽度对齐：{hx} / {sx} / {bx}")
print("ok" if not problems else "；".join(problems))
PYE
)"
assert_eq "28-i 渲染：标题去标记 / 围栏原样 / 表格列对齐 / 子集外原样" "$P28I_RENDER_CHK" "ok"
# 8.2 半：读者端先去掉裸 ESC（面板的 sanitizeDeep 是第二道）
python3 - "$P27R/docs/team/tasks/P3-a.md" <<'PYH'
import sys

with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("```\nBEFORE\u001b[2JAFTER\n```\n")
PYH
p27 $TEAM __panel-data --block detail --id P3 >"$TMP/p28i-hostile.json" 2>/dev/null
P28I_HOSTILE_RC=$?
P28I_ESC_BYTES="$(python3 -c 'import sys; print(open(sys.argv[1], "rb").read().count(b"\x1b"))' "$TMP/p28i-hostile.json")"
P28I_VISIBLE="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("ok" if "BEFORE" in d["text"] and "AFTER" in d["text"] and "[2J" in d["text"] else "no")' "$TMP/p28i-hostile.json" 2>/dev/null)"
assert_eq "28-i 敌意字节：含 ESC[2J 的夹具读者退出 0" "$P28I_HOSTILE_RC" "0"
assert_eq "28-i 敌意字节：读者输出里 0 个 0x1b 字节" "$P28I_ESC_BYTES" "0"
assert_eq "28-i 敌意字节：可见文本（BEFORE/AFTER/[2J）仍在" "$P28I_VISIBLE" "ok"
# 截断标记上屏：视图带 truncated 标记（渲染层）
python3 - "$TMP/p28i-trunc.json" <<'PYT'
import json, sys

json.dump({"id": "X2", "count": 1, "file": "docs/team/reports/X2-dev.md", "text": "# X2\n\n前 128 KiB", "truncated": True,
           "files": [{"tab": "report:dev", "name": "X2-dev.md", "path": "docs/team/reports/X2-dev.md", "size": 200000, "truncated": True}]},
          open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False)
PYT
B3_STUB_DETAIL_FILE="$TMP/p28i-trunc.json" "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28I_FX" --state-dir "$P28I_FX/state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 20 --page 4 --detail X2 \
  >"$TMP/p28i-trunc.txt" 2>/dev/null
assert_has "$TMP/p28i-trunc.txt" "已截断" "28-i 截断标记：视图渲染了 truncated 标记"

# 9.2 兄弟断言：详情帧的目标表只有 tab / 返回 / 滚动 / 翻页 / 页签与全局 chip，卡片目标为空
B3_STUB_DETAIL_FILE="$TMP/p28i-render.json" "$JS_RUNNER" "$P28_PANEL" --snapshot --targets --root "$P28I_FX" --state-dir "$P28I_FX/state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 40 --page 4 --detail X1 \
  >"$TMP/p28i-targets.json" 2>/dev/null
P28I_TARGETS="$(p28_kinds "$TMP/p28i-targets.json")"
case ",$P28I_TARGETS," in
  *",detail-tab,"*) ok "28-i 目标表：tab 有点击目标" ;;
  *) bad "28-i 目标表：没有 detail-tab 目标（$P28I_TARGETS）" ;;
esac
case ",$P28I_TARGETS," in
  *",detail-close,"*|*",detail-tab-move,"*|*",detail-scroll,"*) ok "28-i 目标表：返回/tab 移动/滚动 chip 有目标" ;;
  *) bad "28-i 目标表：详情导航 chip 没有目标（$P28I_TARGETS）" ;;
esac
case ",$P28I_TARGETS," in
  *",focus,"*|*",open-focused,"*) bad "28-i 目标表：详情打开时替换掉的看板卡片仍有目标（$P28I_TARGETS）" ;;
  *) ok "28-i 目标表：替换掉的看板块不留卡片目标（V16 F-V16-4 的规则）" ;;
esac

# 9.4 空载成本：详情块只在视图打开时进 wanted 集（停在看板页时一个 detail 子进程都不该有）
P28I_SPAWN="$TMP/p28i-spawn.log"; : > "$P28I_SPAWN"
B3_STUB_SPAWN_LOG="$P28I_SPAWN" "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28I_FX" --state-dir "$P28I_FX/state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 30 --page 4 >/dev/null 2>&1
P28I_PARKED="$(grep -c '^detail$' "$P28I_SPAWN" || true)"
assert_eq "28-i 空载：停在看板页时不 spawn detail 块" "$P28I_PARKED" "0"
: > "$P28I_SPAWN"
B3_STUB_SPAWN_LOG="$P28I_SPAWN" B3_STUB_DETAIL_FILE="$TMP/p28i-render.json" "$JS_RUNNER" "$P28_PANEL" --snapshot --root "$P28I_FX" --state-dir "$P28I_FX/state" \
  --team-cli "$P28_TESTS/panel-b3-stub.sh" --lang zh --theme dark --width 120 --height 30 --page 4 --detail X1 >/dev/null 2>&1
P28I_OPEN_SPAWNS="$(grep -c '^detail$' "$P28I_SPAWN" || true)"
assert_eq "28-i 空载：打开详情时恰好 spawn 一次 detail 块" "$P28I_OPEN_SPAWNS" "1"

section "29 · 派单模型解析：配置压过名册旧记录（M14）"

M14R="$TMP/m14repo"; rm -rf "$M14R"; mkdir -p "$M14R"
( cd "$M14R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m14' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
M14SES="teamsmith-smoke-m14-$$"
( cd "$M14R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$M14SES" --agents dev --vcs local --gates "true" --docs docs/team ) >"$TMP/m14-init.log" 2>&1 \
  && ok "M14 夹具仓库 init 成功" || bad "M14 夹具仓库 init 失败（见 $TMP/m14-init.log）"
( cd "$M14R" && git add -A && git commit -qm "chore: m14 init" ) >/dev/null 2>&1

# 身份隔离（M7.2 纪律）：**写盘之前**先证明 team 认的是这个临时仓库 + 这个临时 session
( cd "$M14R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/m14-paths.json" 2>&1 || true
assert_eq "M14 隔离：team paths 的 main_root 就是 M14 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m14-paths.json")" "$M14R"
assert_has "$TMP/m14-paths.json" "\"session\": \"$M14SES\"" "M14 隔离：身份用的是本轮临时 session"

m14() { ( cd "$M14R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
m14_lib() { # <函数> [参数…]：按 CLI 的方式加载库后调用（展示列与派单读的是同一批函数）
  local fn="$1"; shift
  ( cd "$M14R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$fn"' "$@"' _ "$@" )
}

# 任务 + 工作树（dispatch --print 的最低现场）
m14 $TEAM task M14X --title "M14 fixture" --agent dev --deps "-" >"$TMP/m14-task.log" 2>&1 \
  && ok "M14 夹具：task 建好" || bad "M14 夹具：task 失败（见 $TMP/m14-task.log）"
M14TASK="$(ls "$M14R"/docs/team/tasks/M14X-*.md 2>/dev/null | head -1)"
# P24（B3）：change-less 的任务书要有锚（本节测的是模型的解析优先级）
[ -n "$M14TASK" ] && sed -i 's|^anchor: -.*$|anchor: none (infra) — smoke fixture|' "$M14TASK"
m14 $TEAM add-agent dev --create --no-install >"$TMP/m14-add.log" 2>&1 \
  && ok "M14 夹具：worktree 建好" || bad "M14 夹具：add-agent 失败（见 $TMP/m14-add.log）"
M14WT="$M14R/.worktrees/dev"
M14BR="$(m14_lib team_branch_for_agent dev M14X)"
git -C "$M14WT" switch -c "$M14BR" main >/dev/null 2>&1 || git -C "$M14WT" switch "$M14BR" >/dev/null 2>&1
assert_eq "M14 夹具：工作树停在任务分支上" "$(git -C "$M14WT" rev-parse --abbrev-ref HEAD)" "$M14BR"

# 主现场：名册 state 里躺着一条旧记录（换配置之前派的），配置已经指向新模型
printf 'model=vendor-legacy/model-old\nwindow=dev\nworktree=%s\n' "$M14WT" > "$M14R/.pi/team/state/dev.env"
sed -i 's|^TEAM_AGENT_MODELS=.*|TEAM_AGENT_MODELS="dev=vendor-a/model-a"|' "$M14R/.pi/team/config.sh"

# ① 配置 dev=A → 渲染出 A；名册旧记录不参与
m14 $TEAM dispatch dev M14X "$M14TASK" --print >"$TMP/m14-a.log" 2>&1 \
  && ok "M14-①：配置 dev=vendor-a 时 dispatch --print 退出码 0" || bad "M14-①：dispatch --print 失败（见 $TMP/m14-a.log）"
assert_has "$TMP/m14-a.log" "--provider vendor-a --model model-a" "M14-①：渲染出配置给的模型 A"
assert_not "$TMP/m14-a.log" "model-old" "M14-①：名册里的旧记录没有参与解析"

# ② 配置改成 dev=B → 下一次渲染立即出 B（state 原封不动，不需要先清）
sed -i 's|^TEAM_AGENT_MODELS=.*|TEAM_AGENT_MODELS="dev=vendor-b/model-b"|' "$M14R/.pi/team/config.sh"
m14 $TEAM dispatch dev M14X "$M14TASK" --print >"$TMP/m14-b.log" 2>&1 || bad "M14-②：dispatch --print 失败"
assert_has "$TMP/m14-b.log" "--provider vendor-b --model model-b" "M14-②：配置改动立即影响下一次派单"
assert_not "$TMP/m14-b.log" "model-old" "M14-②：旧记录仍没有参与"
assert_not "$TMP/m14-b.log" "model-a" "M14-②：上一个配置值也没有残留"

# ③ --model C 显式传参压过配置与旧记录
m14 $TEAM dispatch dev M14X "$M14TASK" --print --model vendor-c/model-c >"$TMP/m14-c.log" 2>&1 || bad "M14-③：dispatch --print 失败"
assert_has "$TMP/m14-c.log" "--provider vendor-c --model model-c" "M14-③：--model 显式传参压过配置"
assert_not "$TMP/m14-c.log" "model-b" "M14-③：配置值没有赢过显式参数"

# ④ 配置没有 dev 条目 → 落到 TEAM_DEFAULT_MODEL（同样不是名册旧记录）
sed -i 's|^TEAM_AGENT_MODELS=.*|TEAM_AGENT_MODELS=""|' "$M14R/.pi/team/config.sh"
M14DEF="$(sed -n 's/^TEAM_DEFAULT_MODEL="\([^"]*\)".*/\1/p' "$M14R/.pi/team/config.sh" | head -1)"
m14 $TEAM dispatch dev M14X "$M14TASK" --print >"$TMP/m14-def.log" 2>&1 || bad "M14-④：dispatch --print 失败"
assert_has "$TMP/m14-def.log" "--provider ${M14DEF%%/*} --model ${M14DEF##*/}" "M14-④：无 per-agent 条目时落到 TEAM_DEFAULT_MODEL"
assert_not "$TMP/m14-def.log" "model-old" "M14-④：旧记录仍没有参与"

# ⑤ 展示列的来源标注（名册照写、但要说清是哪来的；此刻 state=vendor-legacy/model-old，配置=默认）
assert_eq "M14-⑤：旧记录 ≠ 当前配置 → 标「历史记录」" "$(m14_lib team_agent_model_src dev)" "历史记录"
m14 $TEAM roster >"$TMP/m14-roster-hist.log" 2>&1 && ok "M14-⑤：roster 退出码 0" || bad "M14-⑤：roster 失败"
assert_has "$TMP/m14-roster-hist.log" "vendor-legacy/model-old·历史记录" "M14-⑤：roster 把旧记录标成「历史记录」（不再冒充当前配置）"
assert_has "$TMP/m14-roster-hist.log" "下次派单用新配置" "M14-⑤：图例说明「历史记录」的含义"
# ps 侧同一列（给它一个假会话文件，agent 会话行才会打印；TEAM_PI_AGENT_DIR 钉在 $TMP，绝不碰真 HOME）
M14PADIR="$TMP/m14-piagent"
M14SESSDIR="$M14PADIR/sessions/--$(printf '%s' "$M14WT" | sed -e 's|^/||' -e 's|[/\\:]|-|g')--"
mkdir -p "$M14SESSDIR"
head -c 4000 /dev/zero | tr '\0' 'x' > "$M14SESSDIR/2026-01-01T00-00-00-000Z_$M14SES-dev.jsonl"
m14 env TEAM_PI_AGENT_DIR="$M14PADIR" $TEAM ps >"$TMP/m14-ps-hist.log" 2>&1 && ok "M14-⑤：ps 退出码 0" || bad "M14-⑤：ps 失败"
assert_has "$TMP/m14-ps-hist.log" "vendor-legacy/model-old·历史记录" "M14-⑤：ps 的会话行同样标「历史记录」"
# 记录与当前配置一致 → 「配置」（老记录没有 model_src 字段也判得对）
printf 'model=%s\nwindow=dev\nworktree=%s\n' "$M14DEF" "$M14WT" > "$M14R/.pi/team/state/dev.env"
assert_eq "M14-⑤：记录 == 当前配置 → 标「配置」" "$(m14_lib team_agent_model_src dev)" "配置"
m14 $TEAM roster >"$TMP/m14-roster-cfg.log" 2>&1
assert_has "$TMP/m14-roster-cfg.log" "$M14DEF·配置" "M14-⑤：roster 把一致的记录标成「配置」"
# 上次是 --model 显式派的 → 「显式」（哪怕它与配置不同，来源也要如实说）
printf 'model=vendor-x/model-x\nmodel_src=explicit\nwindow=dev\nworktree=%s\n' "$M14WT" > "$M14R/.pi/team/state/dev.env"
assert_eq "M14-⑤：上次 --model 显式 → 标「显式」" "$(m14_lib team_agent_model_src dev)" "显式"
m14 $TEAM roster >"$TMP/m14-roster-exp.log" 2>&1
assert_has "$TMP/m14-roster-exp.log" "vendor-x/model-x·显式" "M14-⑤：roster 把显式记录标成「显式」"
# 没有任何记录 → 展示的就是配置解析 → 「配置」
rm -f "$M14R/.pi/team/state/dev.env"
assert_eq "M14-⑤：无记录 → 标「配置」" "$(m14_lib team_agent_model_src dev)" "配置"
m14 $TEAM roster >"$TMP/m14-roster-none.log" 2>&1
assert_has "$TMP/m14-roster-none.log" "$M14DEF·配置" "M14-⑤：无记录时 roster 直接展示配置解析并标「配置」"

# ---------------------------------------------------------------- 30. 代号必须带名字（M16）
# 契约（用户反馈 2026-09-17：“PM 喜欢只用代号（M2、T1.2）指代事务，但用户不一定记得这些编号”）：
#   ① 面向人的输出里代号不许单独出现：**同一行必须带它的短名字**（digest [3] 待复验 / [3] 跳过行 /
#      [4] 待收尾 / [5] 建议，team status 抬头，roster 任务列）；
#   ② 长列表里每一行自成阅读单元：代号在同一行重复出现（例如 `… → team review M16A`）不算合格 ——
#      扫描是「凡含代号的行都必须含名字」，空转扫描（一行都没扫到）单独报红；
#   ③ 名字来源按可信度：BOARD 任务列 → 任务书 H1 → 报告 H1；查不到名字就只印代号
#      （绝不编名字、也绝不因为没名字就不印代号 —— 代号丢了比名字缺了更糟）。
# 全程在自己的临时仓库里跑（写盘前先证明身份），纯逻辑，快慢模式都跑。
section "30 · 代号必须带名字（M16）"

M16R="$TMP/m16repo"; rm -rf "$M16R"; mkdir -p "$M16R"
( cd "$M16R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m16' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
M16SES="teamsmith-smoke-m16-$$"
( cd "$M16R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$M16SES" --agents "dev verify" --vcs local --gates "true" --docs docs/team ) >"$TMP/m16-init.log" 2>&1 \
  && ok "M16 夹具仓库 init 成功" || bad "M16 夹具仓库 init 失败（见 $TMP/m16-init.log）"

# 身份隔离（M7.2 纪律）：**写盘之前**先证明 team 认的是这个临时仓库 + 这个临时 session
( cd "$M16R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/m16-paths.json" 2>&1 || true
assert_eq "M16 隔离：team paths 的 main_root 就是 M16 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m16-paths.json")" "$M16R"
assert_has "$TMP/m16-paths.json" "\"session\": \"$M16SES\"" "M16 隔离：身份用的是本轮临时 session"

m16() { ( cd "$M16R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
m16_lib() { # <函数> [参数…]：按 CLI 的方式加载库后调用（digest 与这些展示函数读的是同一批代码）
  local fn="$1"; shift
  ( cd "$M16R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$fn"' "$@"' _ "$@" )
}
m16_brief() { # <ID> [名字行]：最小任务书；不给名字行 = 任务书自己也没有名字（测报告兜底）
  mkdir -p "$M16R/docs/team/tasks"
  if [ -n "${2:-}" ]; then printf '# %s · %s\n' "$1" "$2"; else printf '# %s\n' "$1"; fi > "$M16R/docs/team/tasks/$1-m16.md"
  printf '\ntask:   %s\nagent:  dev\ndeps:   -\nstatus: todo\n' "$1" >> "$M16R/docs/team/tasks/$1-m16.md"
}
m16_report() { # <ID> [标题行]：任务报告（标题与文件名都要让 team_report_is_task 认得）
  mkdir -p "$M16R/docs/team/reports"
  if [ -n "${2:-}" ]; then printf '# %s · %s\n' "$1" "$2"; else printf '# %s\n' "$1"; fi > "$M16R/docs/team/reports/$1-dev.md"
  printf '\nagent: dev  状态: DONE\n\n## 交付物\n- fixture\n' >> "$M16R/docs/team/reports/$1-dev.md"
}
# 反向守卫：夹具代号出现过的**每一行**都必须带它的名字；代号一次都没出现也报红（否则扫描是空转的假绿）
m16_sweep() { # <日志> <代号> <名字> <说明>
  local log="$1" id="$2" name="$3" what="$4" line n=0 miss=0
  while IFS= read -r line; do
    case "$line" in *"$id"*) n=$((n + 1)) ;; *) continue ;; esac
    case "$line" in *"$name"*) ;; *) miss=$((miss + 1)); printf '      缺名字的行：[%s]\n' "$line" ;; esac
  done < "$log"
  if [ "$n" -eq 0 ]; then bad "$what：输出里根本没有 $id（扫描空转 = 假绿）"
  elif [ "$miss" -eq 0 ]; then ok "$what：$id 出现的 $n 行都带名字「$name」"
  else bad "$what：$id 有 $miss 行没带名字"; fi
}

# ① BOARD 任务列（主来源）：报告与任务书都同名
m16 $TEAM board add M16A "夹具甲：代号必须带名字" dev - >/dev/null 2>&1 || true
m16_brief M16A "夹具甲：代号必须带名字"
m16_report M16A "夹具甲：代号必须带名字"
# ② 任务名只存在于任务书 H1（BOARD 还没这一行）：查名字的兜底之一
m16 $TEAM board add M16B "夹具乙：收尾行也要带名字" dev - >/dev/null 2>&1 || true
m16_brief M16B "夹具乙：收尾行也要带名字"
# ③ 看板没有这一行、任务书也没名字，只有报告 H1 有 → 报告兜底
#    （不建 BOARD 行：否则 [5] 任务板的看板回显会只印代号，而那行忠实反映看板本身没有名字）
m16_brief M16C
m16_report M16C "报告里的短名"
# ④ 哪里都没有名字：只印代号（负对照：不编名字、不藏代号）
m16 $TEAM board add M16D "—" dev - >/dev/null 2>&1 || true
m16_report M16D
# ⑤ 看板已裁决的报告：跳过行也必须带名字
m16 $TEAM board add M16E "夹具戊：跳过行也要带名字" dev - >/dev/null 2>&1 || true
m16_report M16E "夹具戊：跳过行也要带名字"
m16 env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="smoke M16 fixture" \
  $TEAM board set M16E done >/dev/null 2>&1 || true
assert_eq "M16 夹具：M16E 已按看板裁决" "$(m16_lib team_board_status M16E)" "done"
# ⑥ 待收尾 + [5] 建议：agent 手上有个任务，工作树脏（快慢模式都不需要真窗口）
M16WT="$M16R/.worktrees/dev"
git -C "$M16R" worktree add -q -b task/M16B-fixture "$M16WT" main >/dev/null 2>&1 || true
printf 'dirty\n' >> "$M16WT/README.md"
m16_lib team_state_set dev task M16B >/dev/null 2>&1 || true

m16 $TEAM digest >"$TMP/m16-digest.log" 2>&1 && ok "M16：digest 退出码 0" || bad "M16：digest 失败（见 $TMP/m16-digest.log）"

# ① 泛扫（本段的核心断言）：四个有名字的夹具代号，凡出现过的行都必须带名字
m16_sweep "$TMP/m16-digest.log" M16A "夹具甲：代号必须带名字" "M16-① 待复验行"
m16_sweep "$TMP/m16-digest.log" M16B "夹具乙：收尾行也要带名字" "M16-① 待收尾/建议行"
m16_sweep "$TMP/m16-digest.log" M16C "报告里的短名" "M16-① 报告 H1 兜底"
m16_sweep "$TMP/m16-digest.log" M16E "夹具戊：跳过行也要带名字" "M16-① 看板跳过行"
# 具体形状也钉住（泛扫可能被“名字恰好出现在别处”骗过）
assert_has "$TMP/m16-digest.log" "M16A-dev（夹具甲：代号必须带名字）" "M16-①：待复验行是「代号（名字）」形状"
assert_has "$TMP/m16-digest.log" "M16C-dev（报告里的短名）" "M16-①：名字从报告 H1 兜底取得"
assert_has "$TMP/m16-digest.log" "M16E-dev（夹具戊：跳过行也要带名字）" "M16-①：跳过行也带名字"
assert_has "$TMP/m16-digest.log" "M16B（夹具乙：收尾行也要带名字）" "M16-①：待收尾/建议行带名字"
assert_has "$TMP/m16-digest.log" "未在跑但仍有任务 M16B（夹具乙：收尾行也要带名字）" "M16-①：[5] 建议行带名字"
assert_has "$TMP/m16-digest.log" "已按看板跳过 1 份报告" "M16-①：跳过行仍然说明了为什么没列"
# 负对照：哪里都没名字 → 代号照旧单独印出来（不编名字）
assert_match "$TMP/m16-digest.log" 'M16D-dev  →  team review M16D' "M16-②：查不到名字时照旧只印代号（不编名字、不藏代号）"
assert_eq "M16-②：M16D 所在的行没有凭空造出名字" \
  "$(grep -F 'M16D-dev' "$TMP/m16-digest.log" | grep -cF '（' || true)" "0"

# ② 同源的另两个出口：status 抬头行 + roster 任务列（digest 之外，用户也会看的输出）
m16 $TEAM status M16B >"$TMP/m16-status.log" 2>&1 || true
assert_has "$TMP/m16-status.log" "任务 M16B：夹具乙：收尾行也要带名字" "M16-③：team status 抬头行带名字"
m16 $TEAM roster >"$TMP/m16-roster.log" 2>&1 || true
assert_has "$TMP/m16-roster.log" "M16B（夹具乙：收尾行也要带名字）" "M16-③：roster 任务列带名字"

# 隔离（M7.2 纪律）：夹具痕迹不得落进调用方项目（本段只写 /tmp 下的临时仓库）
M16_REAL_MAIN="$(dirname "$(git -C "$SKILL_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$SKILL_DIR" rev-parse --show-toplevel)")"
M16_PHANTOM="$(real_ledger_hits "M16[.A-E]|$M16SES" "$M16_REAL_MAIN")"
if [ -n "$M16_PHANTOM" ]; then bad "M16 隔离：夹具的痕迹出现在真实账本里：$(printf '%s' "$M16_PHANTOM" | tr '\n' ' ')"
else ok "M16 隔离：真实账本的 inbox/state 里没有夹具的痕迹"; fi
# 双向对照（M30 加固）：同一个扫描器①必须抓到 state/ 里的痕迹（守卫不是永远绿），
# ②必须忽略 state/bg/ 里的门禁作业日志（否则「把门禁放后台跑」自身会被判成泄漏）。
M16_NEG="$TMP/m16-negroot"; rm -rf "$M16_NEG"; mkdir -p "$M16_NEG/.pi/team/state/bg" "$M16_NEG/docs/team/inbox/bg"
printf 'M16A phantom\n' > "$M16_NEG/.pi/team/state/bg/gate.log"
assert_eq "M16 隔离对照：state/bg/ 里的门禁作业日志不算账本痕迹" \
  "$(real_ledger_hits 'M16[.A-E]|nomatch-ses' "$M16_NEG" | wc -l | tr -d ' ')" "0"
# P77：审计日志（闸门代写的调用行，内容是调用者自己的 argv）也是流量记录，不算账本
printf '2026-09-22T17:00:00+00:00 · act=pass · argv=new-window -t M16A:dev · cwd=/tmp\n' > "$M16_NEG/.pi/team/state/tmux-calls.log"
assert_eq "M16 隔离对照：审计日志 tmux-calls.log 是调用记录，不算账本痕迹" \
  "$(real_ledger_hits 'M16[.A-E]|nomatch-ses' "$M16_NEG" | wc -l | tr -d ' ')" "0"
printf 'M16A phantom\n' > "$M16_NEG/.pi/team/state/phantom.log"
assert_eq "M16 隔离对照：真正写进 state/ 的痕迹必须被同一个扫描抓到" \
  "$(real_ledger_hits 'M16[.A-E]|nomatch-ses' "$M16_NEG" | wc -l | tr -d ' ')" "1"
# P87（P83-F1）：bg 的排除是确切路径，不是目录名 —— 别处的 bg/ 目录仍是账本，必须被同一个扫描抓到
printf 'M16A phantom\n' > "$M16_NEG/docs/team/inbox/bg/leak.md"
assert_eq "M16 隔离对照：inbox/bg/ 里的痕迹必须被抓到（bg 排除是确切路径，不是目录名）" \
  "$(real_ledger_hits 'M16[.A-E]|nomatch-ses' "$M16_NEG" | grep -c 'inbox/bg/leak.md')" "1"
assert_eq "M16 隔离对照：两条真痕迹腿恰两条命中（state/bg/ 与审计日志仍不在清单里）" \
  "$(real_ledger_hits 'M16[.A-E]|nomatch-ses' "$M16_NEG" | wc -l | tr -d ' ')" "2"
rm -rf "$M16_NEG"
# ---------------------------------------------------------------- 31. tmux 接触面（M28）
# 五次 tmux server 全灭事故 → 两条护栏在这里钉死：
#   31a 裸 tmux 调用 lint（纯逻辑，FAST 也跑）：tests/** 与 docs/team/reports/*/pkg/** 里凡会改变
#       tmux 状态的命令（kill-server/kill-session/…）必须带隔离证据（-L <非 default> / env -u TMUX +
#       私有 TMUX_TMPDIR / 同目录隔离包装 / 顶层白名单）。判定器是 tests/tmux-lint.pl（真 shell 词法器，
#       不是按行 grep）；M28 之前的证据包按 sha256 冻结在 tmux-lint-legacy.txt 里（逐条打印、--no-legacy 可全红）。
#   31b 容器跑法自检（真进程，只跑完整门禁）：容器里裸 tmux 生死正常 + 宿主 server 指纹逐字节不变；
#       再在容器里跑一遍最危险的「真 pi 输入框体检」。没有 podman / 仓库路径不在宿主共享目录 → 显式 SKIP。
section "31 · tmux 接触面：隔离 lint + 容器跑法（M28）"
M28_LINT="$SKILL_DIR/tests/tmux-lint.pl"
M28_CTR="$SKILL_DIR/tests/container-tmux.sh"
M28_LOG="$TMP/m28-lint.log"

if ! command -v perl >/dev/null 2>&1; then
  # 与第 18 节同一条纪律：守门器跑不了就如实报红，不许静默跳过。
  bad "没有 perl：tmux 隔离 lint 跑不了（装上 perl 才能跑这条门禁）"
else
  assert_file "$M28_LINT" "M28：tmux 隔离 lint 存在"
  if perl "$M28_LINT" >"$M28_LOG" 2>&1; then
    ok "M28 真树：变更类 tmux 调用全部有隔离证据（另有 $(grep -c '^  LEGACY' "$M28_LOG" 2>/dev/null || printf 0) 个历史豁免文件，逐条打印在 $M28_LOG）"
  else
    bad "M28 真树有未隔离的 tmux 变更命令（见 $M28_LOG）"
    grep '^  RED' "$M28_LOG" 2>/dev/null | head -3 | sed 's/^/       /'
  fi
  # 判定器自带双向夹具：该红的红、该净的净（含 bash -c 串、裸调用、-L default、PATH shim 不够、豁免机制三条）
  if perl "$M28_LINT" --selftest --quiet >>"$M28_LOG" 2>&1; then
    ok "M28 lint --selftest：双向夹具全部符合预期（检查器这两方向都可信）"
  else
    bad "M28 lint --selftest 有夹具不符合预期（见 $M28_LOG）"
    grep 'BAD' "$M28_LOG" 2>/dev/null | head -3 | sed 's/^/       /'
  fi
  # 门禁级翻转三步：干净文件不红 → 塞一条裸调用必须红 → 换成 -L 私有名又变净
  M28_SB="$TMP/m28-lint-flip"; rm -rf "$M28_SB"; mkdir -p "$M28_SB"
  printf '#!/usr/bin/env bash\ntrue\n' > "$M28_SB/x.sh"
  if perl "$M28_LINT" --root "$M28_SB" --quiet >/dev/null 2>&1; then
    ok "M28 翻转①：干净文件（没有 tmux 调用）不报红"
  else
    bad "M28 翻转①：干净文件被误报"
  fi
  printf 'tmux kill-server\n' >> "$M28_SB/x.sh"
  if perl "$M28_LINT" --root "$M28_SB" --quiet >/dev/null 2>&1; then
    bad "M28 翻转②：塞进去的裸 tmux kill-server 没被抓到（检查器太弱）"
  else
    ok "M28 翻转②：塞一条裸 tmux kill-server → 红"
  fi
  printf '#!/usr/bin/env bash\ntmux -L m28-flip-private kill-server\n' > "$M28_SB/x.sh"
  if perl "$M28_LINT" --root "$M28_SB" --quiet >/dev/null 2>&1; then
    ok "M28 翻转③：同一个 kill-server 带私有 -L → 不报红（不是见 kill-server 就红）"
  else
    bad "M28 翻转③：带 -L 私有 socket 的调用被误报"
  fi
  # M41 翻转：字面绝对路径 = 绕过 PATH 闸门 —— 带私有 -L 也要红；变量形式（REAL_TMUX 解析类）照旧
  printf '#!/usr/bin/env bash\n/usr/bin/tmux -L m28-flip-private kill-server\n' > "$M28_SB/x.sh"
  if perl "$M28_LINT" --root "$M28_SB" --quiet >/dev/null 2>&1; then
    bad "M41 翻转④：绝对路径 + 私有 -L 的 kill-server 没被抓到（绕过闸门的形状）"
  else
    ok "M41 翻转④：字面绝对路径 kill-server（即使带私有 -L）→ 红（网关看不到它）"
  fi
  printf '#!/usr/bin/env bash\n"$REAL_TMUX" -L m28-flip-private kill-server\n' > "$M28_SB/x.sh"
  if perl "$M28_LINT" --root "$M28_SB" --quiet >/dev/null 2>&1; then
    ok "M41 翻转⑤：变量形式（\"\$REAL_TMUX\" + 私有 -L）照旧不红（REAL_TMUX 解析类例外）"
  else
    bad "M41 翻转⑤：REAL_TMUX 变量形式被误报（例外没生效）"
  fi
  rm -rf "$M28_SB"
fi

# ── 31b. 容器跑法（真进程）──────────────────────────────────────────────────────────────────────
M28_CTR_SEG="31b·容器 tmux 自检（podman）"
if [ "$FAST" = "1" ]; then
  fast_skip "$M28_CTR_SEG" "要拉起 podman 容器做 tmux 生死实验（真进程），快模式不跑"
elif [ ! -f "$M28_CTR" ]; then
  cond_skip "$M28_CTR_SEG" "缺 $M28_CTR"
else
  live_mark
  bash "$M28_CTR" --selftest >"$TMP/m28-ctr-selftest.log" 2>&1
  M28_CTR_RC=$?
  case "$M28_CTR_RC" in
    0)  ok "M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变" ;;
    77) cond_skip "$M28_CTR_SEG" "$(grep -m1 '^SKIP' "$TMP/m28-ctr-selftest.log" 2>/dev/null | sed 's/^SKIP: //')" ;;
    *)  bad "M28 容器自检失败（rc=$M28_CTR_RC，见 $TMP/m28-ctr-selftest.log）"
        tail -4 "$TMP/m28-ctr-selftest.log" 2>/dev/null | sed 's/^/       /' ;;
  esac
  # 容器里跑一遍最危险的 tmux 接触型夹具（真 pi 输入框体检）：pi 只挂包目录、不挂 $HOME
  # （容器里拿不到 provider 配置/密钥），走的还是容器自己的 socket。
  if [ "$M28_CTR_RC" = "0" ] && [ -f "$SKILL_DIR/tests/pm-box-real.sh" ]; then
    live_mark
    bash "$M28_CTR" --with-pi --cmd "bash $SKILL_DIR/tests/pm-box-real.sh --idle-secs 3" \
      >"$TMP/m28-ctr-pmbox.log" 2>&1
    M28_PB_RC=$?
    if [ "$M28_PB_RC" = "77" ]; then
      cond_skip "31b2·容器里跑真 pi 体检" "$(grep -m1 '^SKIP' "$TMP/m28-ctr-pmbox.log" 2>/dev/null | sed 's/^SKIP: //')"
    elif [ "$M28_PB_RC" -ne 0 ]; then
      bad "M28 容器里跑真 pi 体检失败（rc=$M28_PB_RC，见 $TMP/m28-ctr-pmbox.log）"
      tail -4 "$TMP/m28-ctr-pmbox.log" 2>/dev/null | sed 's/^/       /'
    elif grep -q '^SKIP' "$TMP/m28-ctr-pmbox.log" 2>/dev/null; then
      cond_skip "31b2·容器里跑真 pi 体检" "夹具说：$(grep -m1 '^SKIP' "$TMP/m28-ctr-pmbox.log" | sed 's/^SKIP//')"
    else
      assert_has "$TMP/m28-ctr-pmbox.log" "RETRACT=ok" "M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立"
      assert_has "$TMP/m28-ctr-pmbox.log" "verdict=EMPTY" "M28 容器里跑真 pi 体检：空闲空框被判 EMPTY（没被误判成忙）"
      # M45：顺便报这轮的横幅状态。横幅在场时，上面那条 EMPTY 断言就是判据层在**真横幅**上的现场考试；
      # 不在场（今天没新版本/网络不通）也不报红 —— 横幅形状由 12b-h0b / 12b-h ⑳ 的夹具与翻转包常驻覆盖，
      # 这里不把门禁绑到「今天的发布节奏」上。
      if grep -q 'banner=present' "$TMP/m28-ctr-pmbox.log" 2>/dev/null; then
        ok "M45 容器体检这轮有更新横幅：EMPTY/RETRACT 是在真横幅现场上成立的"
      else
        printf '  \033[2m·\033[0m %s\n' "（M45：这轮容器体检没有横幅（今天无新版本/网络不通）；横幅现场另有合成帧与真 pane 夹具常驻覆盖）"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------- 31c. tmux 运行时闸门（M36 建，M67 按目标判定）
# M28 的 lint（31a）管**仓库脚本**的静态隔离；这一段管**运行时**：PM/worker 窗口 PATH 最前的
# scripts/shim/tmux 包装 —— 每次调用记 state/tmux-calls.log（时间/socket/TMUX/TMUX_TMPDIR/参数/
# pid/ppid/cwd/动作，上限 2000 行）。M67 起判定**按目标**（环境变量零授权）：
#   · 解析到共享默认 socket（/tmp/tmux-<uid>/default）的 kill-server / kill-session -a 一律拒绝（exit 64）；
#   · kill-session/kill-window/kill-pane 只在有效 -t 的 session 段字面等于**绑定到调用者**的 TEAM_SESSION
#     时放行（act=allowed-owned）；其余（无 -t / 空目标 / %N / @N / :win / 相对目标 / 别的会话 / 身份缺失
#     或未绑定 / 假隔离）一律拒绝（act=refused）；
#   · 私有 socket → act=pass；假隔离（TMUX_TMPDIR 不可用）→ 拒绝（M41 原样保留）；
#   · 唯一的带内放行 = 调用者 argv 里的 --teamsmith-allow-destructive（全局参数位；剥掉、记 act=explicit-flag）；
#   · TEAM_ALLOW_DESTRUCTIVE_TMUX 退役：在任何环境里（含 server 全局环境）都不改变判定。
# 这一段自己的安全纪律（与 #1250 同族，宁可繁琐不可碰默认 server）：
#   · 默认 socket 的探针（放行/拒绝/只读）把 TEAM_TMUX_REAL **钉到 argv 记录桩**（只记 argv 的假命令）——
#     就算闸门逻辑整个坏掉，被执行的也只是桩，结构上碰不到真默认 server；
#   · 「真杀」只在 $TMP 内的私有 server 上做（TMUX_TMPDIR=<私有>，M23 同一机制）；
#   · 段首/段尾各探一次默认 server（只读 ls）：它若死在本段运行期间，本段就是第一现场，如实报红。
section "31c · tmux 运行时闸门：按目标判定 + argv token + 注入（M36/M67）"

M36_SHIM_DIR="$SKILL_DIR/scripts/shim"
M36_D="$TMP/m36"; mkdir -p "$M36_D"
M36_LOG="$M36_D/tmux-calls.log"
M36_STUB="$M36_D/stub"; mkdir -p "$M36_STUB"
M36_STUB_CALLS="$M36_D/stub-calls"
M36_STUB_ENV="$M36_D/stub-env"
M36_UID="$(id -u)"
M36_SESS="teamx"
M36_OWN="$M36_SESS:dev"
# 桩 tmux：记 argc/argv（逐字节）+ 记自己的环境（证明 token 不进被执行进程的环境）；list-windows 可
# 按 M36_STUB_WINDOWS 假装有窗口（CLI 的 teardown 会先查窗口存不存在）。
cat > "$M36_STUB/tmux" <<EOF
#!/usr/bin/env bash
printf 'STUB argc=%s argv=%s\n' "\$#" "\$*" >> "$M36_STUB_CALLS"
env | sort > "$M36_STUB_ENV"
case "\$*" in
  *list-windows*) [ -n "\${M36_STUB_WINDOWS:-}" ] && printf '%s\n' "\$M36_STUB_WINDOWS" ;;
esac
exit 0
EOF
chmod +x "$M36_STUB/tmux"

assert_file "$M36_SHIM_DIR/tmux" "闸门 shim 文件在（scripts/shim/tmux）"
if [ -x "$M36_SHIM_DIR/tmux" ]; then ok "shim 可执行"; else bad "shim 不可执行"; fi

# 闸门探针（默认 socket 类）：sanitized env（无 TMUX/TMUX_PANE/TMUX_TMPDIR/团队身份）、cwd 可控、
# 桩同时放在 PATH 里并**显式钉进 TEAM_TMUX_REAL**。拒绝路径**不执行任何东西**（桩收到 = 判定错了）。
M36_PATH="$M36_SHIM_DIR:$M36_STUB:/usr/bin:/bin"
m36_probe_in() { # <cwd> [VAR=val …] <tmux argv…>
  local d="$1"; shift
  ( cd "$d" || exit 90
    env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ALLOW_DESTRUCTIVE_TMUX -u TEAM_TMUX_REAL \
        -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SESSION -u TEAM_PROJECT \
        PATH="$M36_PATH" TEAM_TMUX_REAL="$M36_STUB/tmux" TEAM_TMUX_CALLS_LOG="$M36_LOG" "$@" )
}
m36_probe() { m36_probe_in "$REPO" "$@"; }
# 绑定身份探针：TEAM_ROOT=TEAM_MAIN_ROOT=$REPO（cwd 的祖先），TEAM_SESSION=teamx
m36_bound() { m36_probe TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION="$M36_SESS" "$@"; }

# 判定断言器：拒绝 / 放行各一条（每次清日志与桩记录，逐条可定位）
m36_refuse() { # <标签> <探针命令…>：期望 exit 64 + act=refused + 桩没被叫
  local label="$1"; shift
  : > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = 64 ] && grep -q 'act=refused' "$M36_LOG" 2>/dev/null && [ ! -e "$M36_STUB_CALLS" ]; then
    ok "$label：exit 64 + act=refused + 桩没被叫"
  else
    bad "$label：rc=$rc act=$(grep -o 'act=[a-z-]*' "$M36_LOG" 2>/dev/null | head -1) 桩=$([ -e "$M36_STUB_CALLS" ] && echo 被执行 || echo 未叫)"
  fi
}
m36_allow() { # <标签> <期望 act> <探针命令…>：期望 exit 0 + 记期望动作 + 桩收到
  local label="$1" want="$2"; shift 2
  : > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
  "$@" >/dev/null 2>&1; local rc=$?
  assert_eq "$label：exit 0" "$rc" "0"
  assert_has "$M36_LOG" "act=$want" "$label：记 act=$want"
  assert_file "$M36_STUB_CALLS" "$label：调用落到了下游（桩收到）"
}

# ── 段首探活：默认 server 现状（只读 ls，不改任何状态）────────────────────────────
M36_DEF_SOCK="/tmp/tmux-$M36_UID/default"     # 探针固定靶（unset TMUX_TMPDIR 后的共享默认 socket）
m36_default_alive() { [ -S "$M36_DEF_SOCK" ] && env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR tmux -S "$M36_DEF_SOCK" ls >/dev/null 2>&1; }
if m36_default_alive; then M36_DEF_WAS=alive; else M36_DEF_WAS=not-alive; fi

# ── ⓪ 探针钉真身（helper 层证据）：默认 socket 类探针的真身 = 桩；真杀类探针只用私有 socket ────────
printf '  \033[2m·\033[0m 31c 真身解析：默认 socket 探针 → %s（argv 记录桩，TEAM_TMUX_REAL 钉死）；真杀探针 → %s（只打私有 socket）\n' \
  "$M36_STUB/tmux" "${REAL_TMUX:-<无 tmux>}"
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
m36_bound tmux -V >/dev/null 2>&1
assert_has "$M36_STUB_CALLS" "STUB argc=1 argv=-V" "⓪ 默认 socket 探针的真身就是桩（-V 直通到桩，不是真 tmux）"

# ── ①a 自己的命名对象 → allowed-owned（有效 -t；-t x 与 -tx；最后一个 -t 胜出）──────────────
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS" "$M36_STUB_ENV"
M36_RCS=""
for args in "kill-window -t $M36_OWN" "kill-pane -t $M36_OWN.0" "kill-session -t $M36_SESS"; do
  m36_bound tmux $args >/dev/null 2>&1; M36_RCS="$M36_RCS $?"
done
assert_eq "①a 自己的命名目标（window/pane/session）放行（exit 0 ×3）" "$M36_RCS" " 0 0 0"
assert_eq "①a 三次都记 act=allowed-owned" "$(grep -c 'act=allowed-owned' "$M36_LOG" 2>/dev/null | head -1)" "3"
assert_eq "①a 三次都记共享默认 socket" "$(grep -c "sock=$M36_DEF_SOCK" "$M36_LOG" 2>/dev/null | head -1)" "3"
assert_has "$M36_STUB_CALLS" "STUB argc=3 argv=kill-window -t $M36_OWN" "①a 桩收到 kill-window（argv 逐字节）"
assert_has "$M36_STUB_CALLS" "STUB argc=3 argv=kill-pane -t $M36_OWN.0" "①a 桩收到 kill-pane"
assert_has "$M36_STUB_CALLS" "STUB argc=3 argv=kill-session -t $M36_SESS" "①a 桩收到 kill-session"
m36_allow "①a -t<值> 连写（-tteamx:dev）" allowed-owned m36_bound tmux kill-window -t"$M36_OWN"
assert_has "$M36_STUB_CALLS" "STUB argc=2 argv=kill-window -t$M36_OWN" "①a -t 连写形式逐字节透传"
m36_allow "①a 最后一个 -t 胜出（自己的在最后）" allowed-owned m36_bound tmux kill-window -t otherproj:pm -t "$M36_OWN"
m36_allow "①a kill-window -a 仍受目标约束（-a 在 window 上不是加宽）" allowed-owned m36_bound tmux kill-window -a -t "$M36_OWN"

# ── ①b 目标矩阵：不可证明 / 不是自己的命名对象 → refused ─────────────────────────────────────
m36_refuse "①b 别的项目会话 otherproj:pm"          m36_bound tmux kill-window -t otherproj:pm
m36_refuse "①b 别的会话（裸 session 名）"           m36_bound tmux kill-session -t otherproj
m36_refuse "①b pane id %1"                        m36_bound tmux kill-window -t %1
m36_refuse "①b window id @1"                      m36_bound tmux kill-pane -t @1
m36_refuse "①b 无 session 段的窗口名 dev"          m36_bound tmux kill-window -t dev
m36_refuse "①b 空 session 段 :dev"                m36_bound tmux kill-window -t :dev
m36_refuse "①b 空目标 -t ''"                      m36_bound tmux kill-window -t ""
m36_refuse "①b 完全没有 -t"                       m36_bound tmux kill-session
m36_refuse "①b 相对目标 ."                        m36_bound tmux kill-window -t .
m36_refuse "①b 相对目标 +"                        m36_bound tmux kill-window -t +
m36_refuse "①b 相对目标 -"                        m36_bound tmux kill-window -t -
m36_refuse "①b 最后一个 -t 胜出（别的在最后）"      m36_bound tmux kill-window -t "$M36_OWN" -t otherproj:pm

# ── ①c server / 加宽 / 前缀歧义 → refused ────────────────────────────────────────────────────
m36_refuse "①c kill-server（对象是整台 server）"    m36_bound tmux kill-server
m36_refuse "①c kill-ser（前缀写法）"               m36_bound tmux kill-ser
m36_refuse "①c kill-s（前缀有歧义）"               m36_bound tmux kill-s
m36_refuse "①c kill-session -a -t teamx（加宽）"   m36_bound tmux kill-session -a -t "$M36_SESS"
m36_refuse "①c kill-session -at teamx（组合旗标）"  m36_bound tmux kill-session -at "$M36_SESS"
m36_refuse "①c kill-session -a（无目标）"          m36_bound tmux kill-session -a
# 拒绝文案要点名：子命令、解析出的 socket、原因、argv token、私有 socket 路线（R1 的措辞承诺）
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
M36_OUT="$(m36_bound tmux kill-window -t otherproj:pm 2>&1)"; M36_RC=$?
assert_eq "①c 拒绝文案：exit 64" "$M36_RC" "64"
assert_has_echo "$M36_OUT" "已拒绝 kill-window" "①c 文案点名子命令"
assert_has_echo "$M36_OUT" "$M36_DEF_SOCK" "①c 文案点名解析出的 socket"
assert_has_echo "$M36_OUT" "TEAM_SESSION='$M36_SESS'" "①c 文案点名身份不符的原因"
assert_has_echo "$M36_OUT" "--teamsmith-allow-destructive" "①c 文案给出 argv token 路线"
assert_has_echo "$M36_OUT" "TMUX_TMPDIR=" "①c 文案给出私有 socket 路线"
M36_OUT="$(m36_bound tmux kill-server 2>&1)"
assert_has_echo "$M36_OUT" "整台 server" "①c kill-server 文案点明对象是整台 server"
M36_OUT="$(m36_bound tmux kill-session -a -t "$M36_SESS" 2>&1)"
assert_has_echo "$M36_OUT" "波及" "①c 加宽文案点明影响面"

# ── ①d 身份绑定（M40 契约的闸门读法）→ refused；唯一例外是「根是 cwd 的祖先」──────────────
m36_refuse "①d 未绑定：cwd 在 TEAM_ROOT 之外、环境带着 TEAM_SESSION" \
  m36_probe_in "$TMP" TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION="$M36_SESS" tmux kill-window -t "$M36_OWN"
m36_refuse "①d TEAM_SESSION 缺失"    m36_probe TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" tmux kill-window -t "$M36_OWN"
m36_refuse "①d TEAM_SESSION 为空"    m36_probe TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION= tmux kill-window -t "$M36_OWN"
m36_refuse "①d 两个根都缺"           m36_probe TEAM_SESSION="$M36_SESS" tmux kill-window -t "$M36_OWN"
m36_refuse "①d TEAM_ROOT 指向别处（不是 cwd 的祖先）" \
  m36_probe TEAM_ROOT="$M36_D" TEAM_MAIN_ROOT="$M36_D" TEAM_SESSION="$M36_SESS" tmux kill-window -t "$M36_OWN"
m36_allow "①d TEAM_MAIN_ROOT 是 cwd 的祖先即可绑定（worker 窗口形状）" allowed-owned \
  m36_probe TEAM_ROOT="$M36_D/nowhere" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION="$M36_SESS" tmux kill-window -t "$M36_OWN"
: > "$M36_LOG"
m36_probe_in "$TMP" TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION="$M36_SESS" tmux kill-window -t "$M36_OWN" >"$M36_D/unbound.out" 2>&1 || true
assert_has "$M36_D/unbound.out" "没有绑定到调用者" "①d 未绑定文案点明「继承来的身份不算授权」"

# ── ①e 继承环境零授权：TEAM_ALLOW_DESTRUCTIVE_TMUX=1 对判定零影响，且没有任何 act=override ────
m36_refuse "①e 退役键=1 + kill-server"        m36_bound TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-server
m36_refuse "①e 退役键=1 + 别的会话"           m36_bound TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-window -t otherproj:pm
m36_refuse "①e 退役键=1 + 空目标"             m36_bound TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-window -t ""
assert_not "$M36_LOG" "act=override" "①e 退役键在场时也没有任何 act=override（该词汇退役）"
if grep -rq 'act=override' "$M36_SHIM_DIR/tmux" 2>/dev/null; then bad "①e shim 源码里仍有 act=override"; else ok "①e shim 源码里没有 act=override"; fi
if grep -q 'TEAM_ALLOW_DESTRUCTIVE_TMUX' "$M36_SHIM_DIR/tmux" && grep -qE '\$\{TEAM_ALLOW_DESTRUCTIVE_TMUX' "$M36_SHIM_DIR/tmux"; then
  bad "①e shim 仍在读退役键（\${TEAM_ALLOW_DESTRUCTIVE_TMUX}）"
else
  ok "①e shim 不读退役键（只在注释里提到）"
fi

# ── ② argv token：执行 + 剥掉 + 不进被执行进程的环境；子命令之后是数据；=1 不识别 ─────────────
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS" "$M36_STUB_ENV"
M36_OUT="$(m36_bound tmux --teamsmith-allow-destructive kill-server 2>&1)"; M36_RC=$?
assert_eq "② token + kill-server（默认 socket）：执行（exit 0）" "$M36_RC" "0"
assert_has "$M36_LOG" "act=explicit-flag" "② 记 act=explicit-flag"
assert_has "$M36_LOG" "sock=$M36_DEF_SOCK" "② 日志记下解析出的默认 socket"
assert_eq "② 桩收到的 argv = 调用者 argv 剥掉 token" \
  "$(sed -n 's/^STUB argc=[0-9]* argv=//p' "$M36_STUB_CALLS" 2>/dev/null)" "kill-server"
assert_not "$M36_STUB_ENV" "teamsmith-allow-destructive" "② token 不进被执行进程的环境"
assert_not "$M36_STUB_ENV" "TEAM_ALLOW_DESTRUCTIVE_TMUX=" "② 执行进程的环境里没有退役键（本探针没设它）"
m36_allow "② token + 别的会话的目标（调用者的显式授权对任何 socket 都算）" explicit-flag \
  m36_bound tmux --teamsmith-allow-destructive kill-window -t otherproj:pm
assert_has "$M36_STUB_CALLS" "STUB argc=3 argv=kill-window -t otherproj:pm" "② 目标原样到达下游（闸门不改写调用）"
m36_allow "② 两个 token 都消费" explicit-flag m36_bound tmux --teamsmith-allow-destructive --teamsmith-allow-destructive kill-server
assert_eq "② 两个 token 都被剥掉" "$(sed -n 's/^STUB argc=[0-9]* argv=//p' "$M36_STUB_CALLS" 2>/dev/null)" "kill-server"
# =1 形式不识别：透传给真 tmux 报错 = fail closed（仍被拒）
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
m36_bound tmux --teamsmith-allow-destructive=1 kill-server >/dev/null 2>&1; M36_RC=$?
assert_eq "② token=1 形式不识别（fail closed：仍 exit 64）" "$M36_RC" "64"
assert_not_file "$M36_STUB_CALLS" "② token=1 没有落桩"
# 子命令之后的同名词是数据：原样透传，不授权
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
m36_bound tmux send-keys -t "$M36_OWN" --teamsmith-allow-destructive >/dev/null 2>&1; M36_RC=$?
assert_eq "② 子命令之后的同名词是数据：只读调用照常执行（exit 0）" "$M36_RC" "0"
assert_has "$M36_LOG" "act=pass" "② 载荷里的同名词不产生 explicit-flag"
assert_has "$M36_STUB_CALLS" "STUB argc=4 argv=send-keys -t $M36_OWN --teamsmith-allow-destructive" "② 载荷里的 token 原样到达下游"
m36_refuse "② kill-server 之后的同名词是数据（不授权）" m36_bound tmux kill-server --teamsmith-allow-destructive

# ── ③ 私有 socket 放行 / 假隔离拒绝（M41 原样保留） / 只读不拦 ──────────────────────────────
mkdir -p "$M36_D/priv"
m36_allow "③ TMUX_TMPDIR=<私有> 的 kill-server 放行" pass m36_probe TMUX_TMPDIR="$M36_D/priv" tmux kill-server
assert_has "$M36_LOG" "sock=$M36_D/priv/tmux-$M36_UID/default" "③ 日志记下私有 socket 路径"
m36_allow "③ -L <非 default> 的 kill-server 放行" pass m36_probe tmux -L m36priv kill-server
assert_has "$M36_LOG" "sock=/tmp/tmux-$M36_UID/m36priv" "③ -L 的 socket 名解析对了"
m36_allow "③ TMUX 指私有 socket 的 kill-server 放行" pass m36_probe TMUX="$M36_D/privsock,1,0" tmux kill-server
# 假隔离（TMUX_TMPDIR 指向不可用的目录）：真 tmux 会静默回退默认 socket → 破坏性调用必须拒
M36_MISS="$M36_D/miss"; rm -rf "$M36_MISS"; mkdir -p "$M36_MISS"   # 只建父目录：$M36_MISS/sock 故意不存在
m36_refuse "③ 假隔离（TMUX_TMPDIR=<不存在的目录>）的 kill-server" m36_bound TMUX_TMPDIR="$M36_MISS/sock" tmux kill-server
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
M36_OUT="$(m36_bound TMUX_TMPDIR="$M36_MISS/sock" tmux kill-server 2>&1)"; M36_RC=$?
assert_eq "③ 假隔离拒绝：exit 64" "$M36_RC" "64"
assert_has_echo "$M36_OUT" "这是**假隔离**" "③ 文案点明这是假隔离（不是普通默认 socket）"
assert_has_echo "$M36_OUT" "TMUX_TMPDIR=$M36_MISS/sock 指向不存在的目录，真 tmux 会静默回退默认 socket" "③ 文案点明回退原因（M41 要求的措辞）"
assert_has "$M36_LOG" "sock=$M36_DEF_SOCK" "③ 日志记的 sock 是**默认**路径（不是那个不存在的私有目录）"
assert_not_file "$M36_STUB_CALLS" "③ 假隔离拒绝没执行任何东西（桩没被叫）"
# 假隔离 + 「看着是自己」的目标也拒：命中的同名会话可能是共享 server 上别人的
m36_refuse "③ 假隔离 + 自己的目标名也拒" m36_bound TMUX_TMPDIR="$M36_MISS/sock" tmux kill-window -t "$M36_OWN"
# 同形状的只读调用：放行（只读从不拦），但 sock 判定仍必须是默认路径
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
m36_probe TMUX_TMPDIR="$M36_MISS/sock" tmux ls >/dev/null 2>&1; M36_RC=$?
assert_eq "③ 假隔离的只读调用（ls）放行" "$M36_RC" "0"
assert_has "$M36_LOG" "act=pass" "③ 假隔离的 ls 记 act=pass"
assert_has "$M36_LOG" "sock=$M36_DEF_SOCK" "③ 假隔离的 ls：日志里的 sock 也是默认路径"
assert_has "$M36_STUB_CALLS" "STUB argc=1 argv=ls" "③ 假隔离的 ls 递到了下游"
# 存在的**普通文件**：真 tmux 直接报错（不会回退）；闸门保守地按「不可用 → 默认」判
: > "$M36_D/afile"
m36_refuse "③ TMUX_TMPDIR=<普通文件> 的 kill-session" m36_bound TMUX_TMPDIR="$M36_D/afile" tmux kill-session -t "$M36_SESS"
M36_OUT="$(m36_bound TMUX_TMPDIR="$M36_D/afile" tmux kill-server 2>&1)"
assert_has_echo "$M36_OUT" "不是目录" "③ 文件形态：文案点明「不是目录」（与不存在形态分开说）"
# 真私有目录（mkdir -p 过的）照旧放行 —— 与 ③ 的断言同源，这里先钉住「新检查没有过度拒绝」
rm -rf "$M36_D/priv2"; mkdir -p "$M36_D/priv2"
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
m36_probe TMUX_TMPDIR="$M36_D/priv2" tmux kill-server >/dev/null 2>&1
assert_eq "③ 已建私有目录的 kill-server 照常放行（新检查不过度拒绝）" "$?" "0"
assert_has "$M36_LOG" "sock=$M36_D/priv2/tmux-$M36_UID/default" "③ 已建私有目录仍记私有 sock"
# 只读命令不拦（即使解析到默认 socket）：ls/list-*/display-message/capture-pane/send-keys 全直通
: > "$M36_LOG"; rm -f "$M36_STUB_CALLS"
M36_RO_BAD=""
for c in "ls" "list-sessions" "display-message -p hi" "capture-pane -p -t x" "send-keys -t x y"; do
  m36_bound tmux $c >/dev/null 2>&1 || M36_RO_BAD="$M36_RO_BAD [$c]"
done
assert_eq "③ 只读命令（含 send-keys）一律放行" "${M36_RO_BAD:-无}" "无"
assert_eq "③ 五个只读调用都落到了下游（桩各记一笔）" "$(wc -l < "$M36_STUB_CALLS" 2>/dev/null | tr -d ' ')" "5"
if grep -qE 'act=(refused|allowed-owned|explicit-flag)' "$M36_LOG" 2>/dev/null; then
  bad "③ 只读命令里出现了 refused/allowed-owned/explicit-flag"
else ok "③ 只读调用全是 act=pass（没有误拦、也不假记授权）"; fi

# ── ④ 日志格式：时间/socket/TMUX/TMUX_TMPDIR/参数/pid/ppid/cwd 一个不少（默认 server 死后靠它倒查）──
assert_match "$M36_LOG" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:' "④ 日志行首是 ISO 时间"
assert_match "$M36_LOG" 'pid=[0-9]+ ppid=[0-9]+' "④ 日志带 pid/ppid"
assert_match "$M36_LOG" 'cwd=/' "④ 日志带 cwd"
assert_has "$M36_LOG" "TMUX=" "④ 日志带 TMUX 字段"
assert_has "$M36_LOG" "TMUX_TMPDIR=" "④ 日志带 TMUX_TMPDIR 字段"

# ── ⑤ 截断：超 2000 条调用行留最新 1000 条；被裁掉的历史由首行 marker 自述（P77）────────────
assert_not "$M36_LOG" " · rotation · dropped=" "⑤ 未越界：日志里没有轮转标记"
seq 1 2100 | sed 's/^/seed /' > "$M36_LOG"
m36_bound tmux ls >/dev/null 2>&1
assert_eq "⑤ 轮转：1 标记 + 1000 行" "$(wc -l < "$M36_LOG" | tr -d ' ')" "1001"
head -n 1 "$M36_LOG" > "$TMP/m36-rot-first.log"
assert_match "$TMP/m36-rot-first.log" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[^ ]* · rotation · dropped=1101$' "⑤ 首行是轮转标记（ISO 时间 · rotation · dropped=1101）"
assert_not "$TMP/m36-rot-first.log" "act=" "⑤ 标记不是调用行（不带 act=）"
assert_eq "⑤ 标记恰一条" "$(grep -c ' · rotation · dropped=' "$M36_LOG" | tr -d ' ')" "1"
assert_eq "⑤ 标记之后恰 1000 行（999 seed + 1 真调用）" "$(tail -n +2 "$M36_LOG" | wc -l | tr -d ' ')" "1000"
assert_eq "⑤ 真调用行恰一条（其余是 seed；marker 不带 act=）" "$(grep -c 'act=' "$M36_LOG" | tr -d ' ')" "1"
assert_has_echo "$(tail -1 "$M36_LOG")" 'argv=ls' "⑤ 轮转后最新一行还在（在末尾）"
assert_has_echo "$(sed -n '2p' "$M36_LOG")" 'seed 1102' "⑤ 留下的最老一行是 seed 1102（丢了 1101 条）"
if grep -q '^seed 1$' "$M36_LOG"; then bad "⑤ 截断留的是最旧的行（方向反了）"; else ok "⑤ 截断丢掉的是最旧的行"; fi
# 第二次轮转：累计计数（前一个 marker 的 N + 本轮裁掉的调用行数）。delta scenario 的算术是
# 「轮转时在场 2100 条调用行、裁掉 1100」；逐发走会在 2001 条处先轮转，所以按其批形续 1099 条
# 调用行 + 一发真调用 = 再走 1100 条（钉的是累计解析，不是轮转触发频率）。
seq 1 1099 | sed 's/^/more /' >> "$M36_LOG"
m36_bound tmux ls >/dev/null 2>&1
assert_eq "⑤ 第二次轮转：仍是 1 标记 + 1000 行" "$(wc -l < "$M36_LOG" | tr -d ' ')" "1001"
head -n 1 "$M36_LOG" > "$TMP/m36-rot-first2.log"
assert_match "$TMP/m36-rot-first2.log" ' · rotation · dropped=2201$' "⑤ 第二次轮转：dropped 累计（1101+1100=2201）"
assert_has_echo "$(sed -n '2p' "$M36_LOG")" 'more 101' "⑤ 第二次轮转：最老的保留行是 more 101"
assert_has_echo "$(tail -1 "$M36_LOG")" 'argv=ls' "⑤ 第二次轮转：最新一行还在（在末尾）"
# P87（P83-F2）：首行 marker 的 N **读不出**时，累计口径是「从 0 起点按可读部分重算」——marker 不是调用行
# （不计入上限、也不保留）。红侧（改动前）会把旧的读不出 marker 当成调用行，写出 dropped=1102 并把
# 「恰 2000 条调用行」误判为越界。
{ printf '%s · rotation · dropped=abc\n' "2026-09-22T22:00:00+00:00"
  seq 1 2100 | sed 's/^/badseed /'; } > "$M36_LOG"
m36_bound tmux ls >/dev/null 2>&1
assert_eq "⑤ 读不出 N 的 marker：1 标记 + 1000 行" "$(wc -l < "$M36_LOG" | tr -d ' ')" "1001"
head -n 1 "$M36_LOG" > "$TMP/m36-rot-bad.log"
assert_match "$TMP/m36-rot-bad.log" ' · rotation · dropped=1101$' "⑤ 读不出 N 的 marker：累计从 0 重启（2101 条调用行裁 1101，不编造数）"
assert_not "$M36_LOG" "dropped=abc" "⑤ 读不出的旧 marker 被顶替（它不是调用行）"
assert_eq "⑤ 读不出 N 的 marker：标记之后恰 1000 行" "$(tail -n +2 "$M36_LOG" | wc -l | tr -d ' ')" "1000"
assert_has_echo "$(sed -n '2p' "$M36_LOG")" 'badseed 1102' "⑤ 读不出 N 的 marker：留下的最老一行是 badseed 1102"
assert_has_echo "$(tail -1 "$M36_LOG")" 'argv=ls' "⑤ 读不出 N 的 marker：最新一行还在末尾"
# 边界：读不出 N 的 marker + 恰 2000 条调用行 → marker 不计入调用行数，不轮转（红侧会误轮转）
{ printf '%s · rotation · dropped=abc\n' "2026-09-22T22:00:00+00:00"
  seq 1 1999 | sed 's/^/edge /'; } > "$M36_LOG"
m36_bound tmux ls >/dev/null 2>&1
assert_eq "⑤ 恰 2000 条调用行：不轮转（marker 不计入调用行数）" "$(wc -l < "$M36_LOG" | tr -d ' ')" "2001"
assert_has "$M36_LOG" "dropped=abc" "⑤ 未越界：读不出的旧 marker 原样留着（不重写）"
assert_eq "⑤ 未越界：不写新 marker" "$(grep -c ' · rotation · dropped=' "$M36_LOG" | tr -d ' ')" "1"
# 超大字面量：bash 算术会**静默回绕**，写回一个不是原数的假值 → 按「读不出」处理（从 0 重算）
{ printf '%s · rotation · dropped=99999999999999999999\n' "2026-09-22T22:00:00+00:00"
  seq 1 2093 | sed 's/^/big /'; } > "$M36_LOG"
m36_bound tmux ls >/dev/null 2>&1
assert_eq "⑤ 超大 N：1 标记 + 1000 行" "$(wc -l < "$M36_LOG" | tr -d ' ')" "1001"
head -n 1 "$M36_LOG" > "$TMP/m36-rot-big.log"
assert_match "$TMP/m36-rot-big.log" ' · rotation · dropped=1094$' "⑤ 超大 N：从 0 重算（2094 条调用行裁 1094，不是回绕假数）"
assert_not "$M36_LOG" "99999999999999999999" "⑤ 超大的旧 marker 被顶替（不保留）"
assert_has_echo "$(sed -n '2p' "$M36_LOG")" 'big 1095' "⑤ 超大 N：留下的最老一行是 big 1095"

# ── ⑥ 边界不挂 + 透传保真（M36 返工必修：无子命令 / 缺值参数 / -V 全部透传或明确退出，绝不能挂住；
#     保真钉桩收到的**完整 argv 与参数个数** —— 不含 token 的调用逐字节原样，含空格/连写也不许被吃。
#     每条套 10s 超时当绊线：挂死回归 → rc=124 直接红）────────────────────────────────────────
m36_edge() { # <期望 argc> <期望 argv> <tmux args…>
  local want_c="$1" want="$2" rc; shift 2
  : > "$M36_STUB_CALLS"
  m36_probe timeout 10 tmux "$@" >/dev/null 2>&1; rc=$?
  assert_eq "边界[$*]：10s 内返回（124=挂死回归）" "$([ "$rc" = 124 ] && echo HANG || echo ok)" "ok"
  assert_eq "边界[$*]：argv 逐字节透传到下游" "$(sed -n 's/^STUB argc=[0-9]* argv=//p' "$M36_STUB_CALLS" 2>/dev/null)" "$want"
  assert_eq "边界[$*]：参数个数" "$(sed -n 's/^STUB argc=\([0-9]*\) argv=.*/\1/p' "$M36_STUB_CALLS" 2>/dev/null)" "$want_c"
}
m36_edge 1 "-L" -L
m36_edge 1 "-S" -S
m36_edge 1 "-c" -c
m36_edge 1 "-f" -f
m36_edge 1 "-T" -T
m36_edge 1 "-V" -V
m36_edge 3 "-2 -v ls" -2 -v ls
m36_edge 3 "-L m36priv kill-server" -L m36priv kill-server
assert_has "$M36_LOG" 'argv=-L m36priv kill-server' "⑥ 日志记原始完整 argv（全局旗标不丢）"
m36_edge 3 "-S $M36_D/privsock ls" -S "$M36_D/privsock" ls
m36_edge 5 "send-keys -t $M36_OWN hello world two  spaces" send-keys -t "$M36_OWN" "hello world" "two  spaces"
: > "$M36_STUB_CALLS"
m36_probe timeout 10 tmux >/dev/null 2>&1; M36_RC=$?
assert_eq "边界[无参数]：10s 内返回（124=挂死回归）" "$([ "$M36_RC" = 124 ] && echo HANG || echo ok)" "ok"
assert_eq "边界[无参数]：也透传到下游（桩被叫到）" "$([ -s "$M36_STUB_CALLS" ] && echo yes || echo no)" "yes"
# FIFO 日志目标：直接跳过记录、不阻塞调用（日志是账本不是命门）
mkfifo "$M36_D/f"; : > "$M36_STUB_CALLS"
timeout 10 env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ALLOW_DESTRUCTIVE_TMUX -u TEAM_TMUX_REAL \
  TEAM_TMUX_CALLS_LOG="$M36_D/f" PATH="$M36_PATH" tmux ls >/dev/null 2>&1; M36_RC=$?
assert_eq "⑥ 日志目标是 FIFO：不阻塞（10s 内返回）" "$([ "$M36_RC" = 124 ] && echo HANG || echo ok)" "ok"
assert_eq "⑥ FIFO 时调用照常透传" "$(sed -n 's/^STUB argc=[0-9]* argv=//p' "$M36_STUB_CALLS")" "ls"
rm -f "$M36_D/f"

# ── ⑦ M41 翻转：把 shim 的目录可用性检查摘掉（mutant）→ 同一发假隔离探针必须不再被拒、直接落桩。
#     这证明 ③ 钉的是「目录可用性检查」这条逻辑本身（去掉 shim 整体的翻转由 ⑩ 覆盖）。
M36_MUT="$M36_D/mut"; rm -rf "$M36_MUT"; mkdir -p "$M36_MUT"
sed 's#_tmpdir="$(_real_dir "${TMUX_TMPDIR:-}")" || _tmpdir_fell_back=1#_tmpdir="${TMUX_TMPDIR:-}"#' \
  "$M36_SHIM_DIR/tmux" > "$M36_MUT/tmux"
chmod +x "$M36_MUT/tmux"
if cmp -s "$M36_SHIM_DIR/tmux" "$M36_MUT/tmux"; then
  bad "⑦ M41 翻转夹具：sed 没打中（mutant 与原件逐字节相同）—— 翻转断言无意义"
else
  ok "⑦ M41 翻转夹具：mutant 已生成（存在性/目录检查被摘掉，其余逐字节相同）"
fi
m36_mut_probe() { env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ALLOW_DESTRUCTIVE_TMUX -u TEAM_TMUX_REAL \
  -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SESSION \
  PATH="$M36_MUT:$M36_STUB:/usr/bin:/bin" TEAM_TMUX_REAL="$M36_STUB/tmux" TEAM_TMUX_CALLS_LOG="$M36_D/mut.log" \
  TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_SESSION="$M36_SESS" "$@"; }
: > "$M36_D/mut.log"; rm -f "$M36_STUB_CALLS"
M36_OUT="$(m36_mut_probe TMUX_TMPDIR="$M36_MISS/sock" tmux kill-server 2>&1)"; M36_RC=$?
assert_eq "⑦ 翻转：摘掉检查后同一发假隔离 kill-server 不再被拒（rc=0，落桩）" "$M36_RC" "0"
assert_has "$M36_D/mut.log" "sock=$M36_MISS/sock/tmux-$M36_UID/default" "⑦ 翻转：mutant 把不存在的目录当成私有 socket（正是事故形状）"
assert_has "$M36_STUB_CALLS" "STUB argc=1 argv=kill-server" "⑦ 翻转：mutant 把 kill-server 真的递到了下游"
: > "$M36_D/mut.log"; rm -f "$M36_STUB_CALLS"
m36_mut_probe TMUX_TMPDIR="$M36_D/afile" tmux kill-server >/dev/null 2>&1
assert_eq "⑦ 翻转：文件形态同样被 mutant 放过（两个维度都由同一条检查把关）" "$?" "0"
assert_has "$M36_STUB_CALLS" "STUB argc=1 argv=kill-server" "⑦ 翻转：文件形态的 kill-server 也落到了下游"

# ── ⑧ 注入渲染（纯逻辑）：PM 与 worker、内置与模板四条路径都带闸门前缀，且**不写任何破坏性授权** ──
m36_lib() { # <bash 片段> [VAR=VALUE …]（source 全部 lib；与 canon_branch 同一形状）
  local body="$1"; shift
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c 'for _a in "$@"; do export "$_a"; done; . "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; '"$body" _ "$@" )
}
M36_INJ_PM="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi")"
assert_has_echo "$M36_INJ_PM" "export PATH=$M36_SHIM_DIR:" "⑧ PM 内置路径：启动命令把 shim 放 PATH 最前"
assert_has_echo "$M36_INJ_PM" "export TEAM_TMUX_CALLS_LOG=$REPO/.pi/team/state/tmux-calls.log" "⑧ PM 内置路径：日志指向本项目的 state/"
assert_has_echo "$M36_INJ_PM" "export TEAM_TMUX_REAL=" "⑧ PM 内置路径：把真 tmux 路径写死（窗口登录 PATH 再怪也不递归）"
assert_not_echo "$M36_INJ_PM" "TEAM_ALLOW_DESTRUCTIVE_TMUX" "⑧ PM 启动命令不写任何破坏性授权（M67 R2）"
M36_INJ_PMT="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi" 'TEAM_PM_CMD=mycli run {prompt}' 'TEAM_PM_BIN=mycli')"
assert_has_echo "$M36_INJ_PMT" "export PATH=$M36_SHIM_DIR:" "⑧ PM 模板路径：harness 里带 shim 前缀"
assert_has_echo "$M36_INJ_PMT" "exec bash -lc" "⑧ PM 模板路径：其余启动语义不变"
assert_not_echo "$M36_INJ_PMT" "TEAM_ALLOW_DESTRUCTIVE_TMUX" "⑧ PM 模板启动命令不写任何破坏性授权"
M36_INJ_AG="$(m36_lib 'team_agent_launch_cmd dev s1 /tmp/wt /tmp/pf.md deepseek/deepseek-flash' "TEAM_PI_BIN=$FAKE/pi")"
assert_has_echo "$M36_INJ_AG" "export PATH=$M36_SHIM_DIR:" "⑧ worker 内置路径：启动命令把 shim 放 PATH 最前"
assert_has_echo "$M36_INJ_AG" "--session-id s1" "⑧ worker 内置路径：命令本体还在"
assert_not_echo "$M36_INJ_AG" "TEAM_ALLOW_DESTRUCTIVE_TMUX" "⑧ worker 启动命令不写任何破坏性授权（M67 R2）"
M36_INJ_AGT="$(m36_lib 'team_agent_launch_cmd dev s1 /tmp/wt /tmp/pf.md demo/m' 'TEAM_AGENT_CMD=mycli run {prompt}' 'TEAM_AGENT_BIN=mycli')"
assert_has_echo "$M36_INJ_AGT" "export PATH=$M36_SHIM_DIR:" "⑧ worker 模板路径：模板展开前有 shim 前缀"
assert_has_echo "$M36_INJ_AGT" "mycli run" "⑧ worker 模板路径：模板本体还在"

# ── ⑨ 翻转控制：同一条探针、PATH 里拿掉 shim → kill-server 直通桩（rc=0）。
#     这证明 ① 钉的是 shim 本身（不是 tmux 的什么自带行为）；shim 文件被删时 ① 同样会红 ──────────
rm -f "$M36_STUB_CALLS"
M36_OUT="$(env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ALLOW_DESTRUCTIVE_TMUX -u TEAM_TMUX_REAL \
    PATH="$M36_STUB:/usr/bin:/bin" TEAM_TMUX_CALLS_LOG="$M36_LOG" tmux kill-server 2>&1)"; M36_RC=$?
assert_eq "⑨ 翻转控制：PATH 没有 shim 时同一条 kill-server 直通（rc≠64）" "$M36_RC" "0"
assert_has "$M36_STUB_CALLS" "STUB argc=1 argv=kill-server" "⑨ 翻转控制：没有 shim 时调用真的落了地"
case "$M36_OUT" in *已拒绝*) bad "⑨ 翻转控制：没有 shim 却出现拒绝文案（断言钉错了对象）";; *) ok "⑨ 翻转控制：没有 shim 就没有拒绝文案";; esac

# ── ⑫ CLI 身份导出（B1.4 的闸门配套）：M40 的身份锁在 CLI 进程里 unset 继承的 TEAM_*；CLI 自己的
#    tmux 子进程（PATH 最前的 shim）就看不到身份，判定会掉进 no-identity 而拒绝 teardown/close/pulse
#    的窗口清理。CLI 载入配置后必须把**目录/配置推导出来的**身份导出给子进程；这里用桩收 env 正面钉住
#    （⑪ 的窗口端到端是它的真实现场）。──────────────────────────────────────────────────────
: > "$M36_STUB_ENV"
( cd "$REPO" && env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR -u TEAM_ALLOW_DESTRUCTIVE_TMUX -u TEAM_TMUX_REAL \
    -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SESSION -u TEAM_PROJECT \
    PATH="$M36_SHIM_DIR:$M36_STUB:/usr/bin:/bin" TEAM_TMUX_REAL="$M36_STUB/tmux" TEAM_TMUX_CALLS_LOG="$M36_LOG" \
    bash "$SKILL_DIR/scripts/team" teardown --agent m36ghost ) >/dev/null 2>&1
assert_match "$M36_STUB_ENV" "^TEAM_SESSION=$SESSION\$" "⑫ CLI 的 tmux 子进程看得到 TEAM_SESSION（身份导出；否则窗口清理退化成 no-identity）"
assert_match "$M36_STUB_ENV" "^TEAM_ROOT=$REPO\$" "⑫ CLI 的 tmux 子进程看得到 TEAM_ROOT（目录推导值）"

# ── 段尾探活：默认 server 若死在本段运行期间，本段就是第一现场（如实报红）────────────
case "$M36_DEF_WAS" in
  alive) if m36_default_alive; then ok "默认 server 前后都活着（本段没碰它）"
         else bad "默认 server 在 31c 运行期间死了（socket=$M36_DEF_SOCK）——本段就是第一现场"; fi ;;
  *) printf '  (调用者机器上没有活着的默认 server：探活跳过)\n' ;;
esac

# ── ⑩ 真私有 server 生死（真进程）：私有 socket 的 kill-server 真的把私有 server 收掉；
#    退役键=1 在私有 socket 上也不改变动作（照样 pass）；token 在私有 socket 上照记 explicit-flag ──
if [ "$FAST" = "1" ]; then
  fast_skip "31c·真私有 server 生死" "要真的起/杀私有 tmux server（真进程），快模式不跑"
elif [ "$HAVE_TMUX" != "1" ]; then
  cond_skip "31c·真私有 server 生死" "没有 tmux"
else
  live_mark
  M36_PRIV="$M36_D/priv-tmpdir"; mkdir -p "$M36_PRIV"
  M36_LIVE_PATH="$M36_SHIM_DIR:$(dirname "$REAL_TMUX"):/usr/bin:/bin"
  m36_priv() { # [VAR=val …] <tmux argv…>：私有 TMPDIR + shim 在最前（下游是真 tmux）
    env -u TMUX -u TMUX_PANE -u TEAM_TMUX_REAL TMUX_TMPDIR="$M36_PRIV" \
        PATH="$M36_LIVE_PATH" TEAM_TMUX_CALLS_LOG="$M36_LOG" "$@"
  }
  : > "$M36_LOG"
  m36_priv tmux new-session -d -s m36victim >/dev/null 2>&1
  if env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$M36_PRIV" "$REAL_TMUX" ls 2>/dev/null | grep -q '^m36victim'; then
    ok "私有 server 起起来了（m36victim 在）"
  else bad "私有 server 没起起来"; fi
  m36_priv tmux kill-server >/dev/null 2>&1; M36_RC=$?
  assert_eq "私有 socket 的 kill-server 放行（exit 0）" "$M36_RC" "0"
  if env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$M36_PRIV" "$REAL_TMUX" ls >/dev/null 2>&1; then
    bad "私有 server 没被收掉（还在）"
  else ok "私有 server 真的被收掉了"; fi
  assert_has "$M36_LOG" "act=pass" "私有 server 的 kill 记 act=pass"
  assert_has "$M36_LOG" "sock=$M36_PRIV/tmux-$M36_UID/default" "私有 socket 路径进了日志"
  # 退役键在私有 socket 上也不改变动作（照样 pass；不许出现 override）
  m36_priv tmux new-session -d -s m36victim2 >/dev/null 2>&1
  m36_priv TEAM_ALLOW_DESTRUCTIVE_TMUX=1 tmux kill-server >/dev/null 2>&1; M36_RC=$?
  assert_eq "退役键=1 + 私有 server：照常放行（exit 0，退役键零影响）" "$M36_RC" "0"
  if env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$M36_PRIV" "$REAL_TMUX" ls >/dev/null 2>&1; then
    bad "第二个私有 server 没被收掉（还在）"
  else ok "第二个私有 server 也被收掉了"; fi
  assert_not "$M36_LOG" "act=override" "私有 socket 的 ledger 里没有 act=override"
  # token 在私有 socket 上照记 explicit-flag（token 是调用者的授权，任何 socket 都执行）
  m36_priv tmux new-session -d -s m36victim3 >/dev/null 2>&1
  m36_priv tmux --teamsmith-allow-destructive kill-server >/dev/null 2>&1; M36_RC=$?
  assert_eq "token + 私有 server：执行（exit 0）" "$M36_RC" "0"
  assert_has "$M36_LOG" "act=explicit-flag" "token 在私有 socket 上记 act=explicit-flag"
  if env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$M36_PRIV" "$REAL_TMUX" ls >/dev/null 2>&1; then
    bad "第三个私有 server 没被收掉（还在）"
  else ok "第三个私有 server 也被收掉了"; fi
  # 段尾再探一次默认 server（真杀之后）
  case "$M36_DEF_WAS" in
    alive) if m36_default_alive; then ok "真杀私有 server 之后，默认 server 仍活着"; else bad "默认 server 死在真杀私有 server 之后——本段就是第一现场"; fi ;;
  esac
fi

# ── ⑩b 指纹前提（M34/D34）：静态钉形状（FAST 也跑）+ 四腿夹具 --fingerprint-check（慢段）──────
# 自检的宿主前提必须只由「真实主机变化才会动的」事实构成：旧版 whole-ps 快照会被客户端风暴与
# 别的项目的私有 server 推动（D34 的假红）。静态钉子不依赖 tmux：直接读函数体（无 ps 快照 +
# 逐 socket 取事实），并用「插回 ps 快照 → 钉子必红」双向钉住它不是个空断言。
m31c_fp_shape() { # <container-tmux.sh> → 0 形状对；否则打印原因并返回 1
  local f="$1" body
  body="$(sed -n '/^host_tmux_fingerprint()/,/^}/p' "$f")"
  [ -n "$body" ] || { printf '找不到 host_tmux_fingerprint()\n'; return 1; }
  if printf '%s\n' "$body" | grep -qE '(^|[^[:alnum:]_/-])ps([[:space:]]|$)'; then
    printf '函数体里仍有 ps 调用（whole-ps 快照 = 客户端风暴的假红入口）\n'; return 1
  fi
  printf '%s\n' "$body" | grep -q 'stat -c' || { printf '函数体没有读 socket 的磁盘身份（stat -c）\n'; return 1; }
  printf '%s\n' "$body" | grep -q 'display-message' || { printf '函数体没有 per-socket 的 server pid 查询（display-message）\n'; return 1; }
  printf '%s\n' "$body" | grep -q -- '-S "\$s"' || { printf '查询没有逐 socket 限定（缺 -S "$s"）\n'; return 1; }
  printf '%s\n' "$body" | grep -q 'caller_socket' || { printf '函数体没有范围里的调用者 socket\n'; return 1; }
  return 0
}
if m31c_fp_shape "$M28_CTR"; then
  ok "M28 指纹形状：无 ps 快照、逐 socket 取 stat + 会话表 + server pid"
else
  bad "M28 指纹形状不对：$(m31c_fp_shape "$M28_CTR" | head -1)"
fi
# 翻转：把旧版的 whole-ps 快照插回函数体 → 同一个钉子必须红（证明它盯的是那块代码，不是空断言）
M28_FPFLIP="$TMP/m28-fp-shape-flip.sh"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$M28_CTR" "$M28_FPFLIP" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
i = s.index('host_tmux_fingerprint() {')
j = s.index('\n}\n', i)
# 旧版形状：整个进程表的快照（就是 D34 假红的入口）
inject = '\n  out="$out|procs|$(ps -eo pid=,args= 2>/dev/null | grep -E \'(^|/)tmux( |$)\' | sort)"'
open(dst, 'w', encoding='utf-8').write(s[:j] + inject + s[j:])
PY
  if [ -f "$M28_FPFLIP" ] && cmp -s "$M28_FPFLIP" "$M28_CTR"; then
    bad "M28 指纹翻转夹具：mutant 与原件逐字节相同（注入没打中）"
  elif m31c_fp_shape "$M28_FPFLIP" >/dev/null 2>&1; then
    bad "M28 指纹翻转：插回 whole-ps 快照后形状钉子还是绿的（钉子失效）"
  else
    ok "M28 指纹翻转：插回 whole-ps 快照 → 形状钉子红（$([ -f "$M28_FPFLIP" ] && printf 已注入 || printf 注入失败)）"
  fi
else
  bad "M28 指纹翻转夹具：没有 python3（无法生成 mutant）"
fi

# 四腿夹具（真进程：私有 default server 上的风暴/杀 server/真会话变化/无 server 只读）
if [ "$FAST" = "1" ]; then
  fast_skip "31c·指纹翻转（--fingerprint-check）" "要真起/杀私有 tmux server（四腿夹具），快模式不跑"
elif [ ! -f "$M28_CTR" ]; then
  cond_skip "31c·指纹翻转（--fingerprint-check）" "缺 $M28_CTR"
elif [ "$HAVE_TMUX" != "1" ]; then
  cond_skip "31c·指纹翻转（--fingerprint-check）" "没有 tmux"
else
  live_mark
  bash "$M28_CTR" --fingerprint-check >"$TMP/m28-fpcheck.log" 2>&1
  M28_FP_RC=$?
  if [ "$M28_FP_RC" = "0" ]; then
    ok "M28 指纹四腿：客户端风暴不移动 / 杀 server 与真会话变化移动 / 无 server 只读"
    grep -E '^  (ok|BAD)' "$TMP/m28-fpcheck.log" 2>/dev/null | sed 's/^/       /'
  elif [ "$M28_FP_RC" = "77" ]; then
    cond_skip "31c·指纹翻转（--fingerprint-check）" "$(grep -m1 '^SKIP' "$TMP/m28-fpcheck.log" 2>/dev/null | sed 's/^SKIP: //')"
  else
    bad "M28 指纹四腿失败（rc=$M28_FP_RC，见 $TMP/m28-fpcheck.log）"
    tail -5 "$TMP/m28-fpcheck.log" 2>/dev/null | sed 's/^/       /'
  fi
fi

# ── ⑪ 窗口注入端到端（真进程）：真派一个 worker / 真起一个 PM，env 里必须看到闸门前缀，
#     **没有任何破坏性授权**（派单 shell 故意带 TEAM_ALLOW_DESTRUCTIVE_TMUX=1）；并且 CLI 自己在
#     窗口里发出的破坏性调用（teardown 的 kill-window）记 act=allowed-owned（真身钉桩、默认 socket）──
if [ "$FAST" = "1" ]; then
  fast_skip "31c·窗口注入端到端" "要真实 tmux 窗口（派单 + team up），快模式不跑"
elif [ "$HAVE_TMUX" != "1" ]; then
  cond_skip "31c·窗口注入端到端" "没有 tmux"
else
  live_mark
  # ── worker：gateprobe 夹具（env dump + 一次 shimmed tmux 调用 + CLI 自己的破坏性调用后退出）
  cat > "$FAKE/gate-probe.sh" <<EOF
#!/usr/bin/env bash
env | sort > "$M36_D/env-worker.log"
tmux ls >> "$M36_D/env-worker.log" 2>&1 || true
# M67 R2：CLI 自己的破坏性调用 = 本项目自己的命名对象（\$TEAM_SESSION:gatevictim），在默认 socket
# 上应记 act=allowed-owned。真身钉桩（默认 socket 探针纪律），TMUX 清掉才会解析到默认 socket。
M36_STUB_WINDOWS=gatevictim TEAM_TMUX_REAL="$M36_STUB/tmux" \\
  env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR bash "$SKILL_DIR/scripts/team" teardown --agent gatevictim >> "$M36_D/env-worker.log" 2>&1 || true
printf 'done\\n' > "$M36_D/env-worker.done"
exit 0
EOF
  chmod +x "$FAKE/gate-probe.sh"
  GP_BRANCH="$(canon_branch gateprobe M36W)"
  # P24（B3）：change-less 的任务书要有锚（本节测的是 tmux 运行时闸门）
  printf '# M36W 夹具 brief\n\nanchor: none (infra) — smoke fixture\n' > "$REPO/.pi/team/state/M36W-brief.md"
  git -C "$REPO" worktree add -b "$GP_BRANCH" "$REPO/.worktrees/gateprobe" "$PROTECTED" >/dev/null 2>&1
  # CLI 破坏性调用的目标：一个真窗口 + 一条 state 记录（stub 的 list-windows 也让 CLI 看得见它）
  tmux new-window -t "$SESSION" -n gatevictim -d -- sleep 60
  printf 'window=gatevictim\n' > "$REPO/.pi/team/state/gatevictim.env"
  : > "$REPO/.pi/team/state/tmux-calls.log"
  rm -f "$M36_D/env-worker.log" "$M36_D/env-worker.done"
  env TEAM_AGENTS="dev verify gateprobe" TEAM_AGENT_CMD="$FAKE/gate-probe.sh" TEAM_AGENT_BIN="$FAKE/gate-probe.sh" \
      TEAM_ALLOW_DESTRUCTIVE_TMUX=1 \
      $TEAM dispatch gateprobe M36W .pi/team/state/M36W-brief.md >"$TMP/m36-dispatch.log" 2>&1 \
    && ok "gateprobe 派单成功（派单 shell 带着退役键=1）" || { bad "gateprobe 派单失败"; tail -5 "$TMP/m36-dispatch.log"; }
  M36_W=0
  while [ "$M36_W" -lt 100 ] && [ ! -f "$M36_D/env-worker.done" ]; do sleep 0.2; M36_W=$((M36_W + 1)); done
  if [ -f "$M36_D/env-worker.log" ]; then
    assert_match "$M36_D/env-worker.log" "^PATH=$M36_SHIM_DIR:" "⑪ worker 窗口 env：PATH 最前是 shim 目录"
    assert_match "$M36_D/env-worker.log" "^TEAM_TMUX_CALLS_LOG=$REPO/.pi/team/state/tmux-calls.log\$" "⑪ worker 窗口 env：日志指向本 fixture 的 state/"
    assert_match "$M36_D/env-worker.log" "^TEAM_TMUX_REAL=$REAL_TMUX\$" "⑪ worker 窗口 env：真 tmux 路径也进了 env"
    assert_not "$M36_D/env-worker.log" "TEAM_ALLOW_DESTRUCTIVE_TMUX=" "⑪ worker 窗口 env：没有退役键（派单 shell 带着它也没用）"
    assert_not "$M36_D/env-worker.log" "DESTRUCTIVE" "⑪ worker 窗口 env：没有任何破坏性授权键"
  else bad "worker 窗口的 env 没落盘（gateprobe 没跑起来）"; fi
  # 夹具自己在窗口里打的 tmux ls 应被 shim 记进 fixture 的 state 日志（有界轮询，不赌固定 sleep）
  M36_W=0
  while [ "$M36_W" -lt 25 ]; do grep -q 'argv=ls' "$REPO/.pi/team/state/tmux-calls.log" 2>/dev/null && break; sleep 0.2; M36_W=$((M36_W + 1)); done
  assert_has "$REPO/.pi/team/state/tmux-calls.log" "argv=ls" "⑪ worker 窗口里的 ad-hoc tmux 调用被记进 state/tmux-calls.log"
  assert_has "$REPO/.pi/team/state/tmux-calls.log" "act=" "⑪ 窗口日志带动作字段"
  # CLI 自己的破坏性调用：allowed-owned（不是 explicit-flag、更不是 override）
  M36_W=0
  while [ "$M36_W" -lt 25 ]; do grep -q 'act=allowed-owned' "$REPO/.pi/team/state/tmux-calls.log" 2>/dev/null && break; sleep 0.2; M36_W=$((M36_W + 1)); done
  assert_has "$REPO/.pi/team/state/tmux-calls.log" "act=allowed-owned" "⑪ CLI 自己的破坏性调用记 act=allowed-owned（M67 R2）"
  assert_has "$REPO/.pi/team/state/tmux-calls.log" "argv=kill-window -t $SESSION:gatevictim" "⑪ 记下的目标就是 CLI 自己的命名对象"
  assert_not "$REPO/.pi/team/state/tmux-calls.log" "act=explicit-flag" "⑪ CLI 自己不带 token（never explicit-flag）"
  assert_not "$REPO/.pi/team/state/tmux-calls.log" "act=override" "⑪ 窗口 ledger 里没有 act=override"
  # 收尾（6g 同款）：窗口、worktree、分支、state env 都清掉
  tmux kill-window -t "$SESSION:gateprobe" 2>/dev/null || true
  tmux kill-window -t "$SESSION:gatevictim" 2>/dev/null || true
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/gateprobe" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$GP_BRANCH" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/gateprobe.env" "$REPO/.pi/team/state/gatevictim.env"

  # ── PM：team up 真起一个假 PM，env 里必须看到闸门前缀（验 respawn-pane 的 sh -c 路径）
  PMW="$($TEAM paths | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"; [ -n "$PMW" ] || PMW=pm
  cat > "$FAKE/gate-pm.sh" <<EOF
#!/usr/bin/env bash
env | sort > "$M36_D/env-pm.log"
printf 'done\\n' > "$M36_D/env-pm.done"
sleep 300
EOF
  chmod +x "$FAKE/gate-pm.sh"
  tmux kill-window -t "$SESSION:$PMW" 2>/dev/null || true
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn" "$M36_D/env-pm.log" "$M36_D/env-pm.done"
  env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$FAKE/gate-pm.sh" TEAM_PM_BIN="$FAKE/gate-pm.sh" \
      TEAM_ALLOW_DESTRUCTIVE_TMUX=1 \
      $TEAM up >"$TMP/m36-pm-up.log" 2>&1 && ok "gate-pm up 成功（派单 shell 带着退役键=1）" || { bad "gate-pm up 失败"; tail -5 "$TMP/m36-pm-up.log"; }
  M36_W=0
  while [ "$M36_W" -lt 100 ] && [ ! -f "$M36_D/env-pm.done" ]; do sleep 0.2; M36_W=$((M36_W + 1)); done
  if [ -f "$M36_D/env-pm.log" ]; then
    assert_match "$M36_D/env-pm.log" "^PATH=$M36_SHIM_DIR:" "⑪ PM 窗口 env：PATH 最前是 shim 目录"
    assert_match "$M36_D/env-pm.log" "^TEAM_TMUX_CALLS_LOG=$REPO/.pi/team/state/tmux-calls.log\$" "⑪ PM 窗口 env：日志指向本 fixture 的 state/"
    assert_not "$M36_D/env-pm.log" "TEAM_ALLOW_DESTRUCTIVE_TMUX=" "⑪ PM 窗口 env：没有退役键"
  else bad "PM 窗口的 env 没落盘（gate-pm 没跑起来）"; fi
  # 收尾：PM 窗口 + pm.pid 系列清掉（与 6i 收尾同口径，后面没有依赖它们的段落了）
  tmux kill-window -t "$SESSION:$PMW" 2>/dev/null || true
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn" \
        "$REPO/.pi/team/state/pm.pid.starting" "$REPO/.pi/team/state/pm-launch.exit" "$REPO/.pi/team/state/pm-launch-failed.log"
fi


# ---------------------------------------------------------------- 32. 身份 = 运行时目录（M40）
# 两起同族实测事故（2026-09-19，用户拍板的设计方向）：shell 继承了别的项目的身份四件套
# （TEAM_ROOT / TEAM_MAIN_ROOT / TEAM_PROJECT / TEAM_SESSION），而解析顺序是「env 优先于 cwd」：
#   ① 在 ai_interview 目录里跑 `team up` 被解析成 pm-skills（护栏拦住了，方向对，但用户被迫清环境）；
#   ② 在 ai_interview 目录里起的 pulse，面板渲染出 pm-skills 的看板（没有护栏，静默读错项目）。
# 规格：身份默认从**运行时目录**推导，继承的 TEAM_* 绝不许静默赢过 cwd。这一段钉住四件事：
#   a) 冲突时观察形式（paths/--print）按 cwd 解析 + 大声告警；env 与目录一致时不吵；
#   b) 会改共享状态的命令在冲突时被拒，而且真的没落盘；显式授权后按 cwd 动手并落审计；
#   c) 「同一项目的兄弟工作树」不是冲突（worker 窗口的形状：env 指主工作树、cwd 在 agent 工作树里）；
#   d) spawn 清洗：pulse / dispatch 起的长驻窗口里，身份是**目标目录**推导出来的（真窗口，FAST 跳过）。
section "32 · 身份 = 运行时目录（M40：继承的 TEAM_* 不许静默赢过 cwd）"
cd "$REPO" || exit 1
M40_D="$TMP/m40"; mkdir -p "$M40_D"
M40_A="$M40_D/foreign"                       # 「另一个项目」（身份的来源）：真 git 仓库 + 自己的配置
mkdir -p "$M40_A/.pi/team" "$M40_A/openspec"
( cd "$M40_A" && git init -q -b main && git commit -q --allow-empty -m x )
printf 'TEAM_PROJECT="m40-foreign"\nTEAM_SESSION="m40-foreign-session"\nTEAM_AGENTS="rogue"\n' > "$M40_A/.pi/team/config.sh"
M40_B="$(basename "$REPO")"                  # 运行时目录所属项目
# 身份家族整体清干净再注入（不继承调用者的任何身份家族变量：面板/子进程/嵌套调用的前缀全靠这条）
m40_env() { env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SESSION_FROM \
    -u TEAM_CONFIG_FILE -u TEAM_ALLOW_FOREIGN_IDENTITY -u TEAM_IDENTITY_LOCKED -u TEAM_IDENTITY_ROOT \
    -u TEAM_IDENTITY_MAIN_ROOT -u TEAM_IDENTITY_PROJECT -u TEAM_IDENTITY_INHERIT_ROOT \
    -u TEAM_IDENTITY_INHERIT_MAIN_ROOT -u TEAM_IDENTITY_INHERIT_PROJECT -u TEAM_IDENTITY_INHERIT_SESSION "$@"; }
# 外来身份（四件套全指向 A）与一致身份（四件套全指向 $REPO）
m40_foreign() { m40_env TEAM_ROOT="$M40_A" TEAM_MAIN_ROOT="$M40_A" TEAM_PROJECT=m40-foreign TEAM_SESSION=m40-foreign-session "$@"; }
m40_own() { m40_env TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_PROJECT="$M40_B" TEAM_SESSION="$SESSION" "$@"; }

# ① 外来身份 + cwd=$REPO：观察形式（paths）按 cwd 解析并打不一致警告（事故②里缺的那道门）
m40_foreign $TEAM paths >"$M40_D/1-paths.log" 2>&1; M40_RC=$?
assert_eq "32① 外来身份 + team paths 退出码 0（只看不改：按目录解析）" "$M40_RC" "0"
assert_has "$M40_D/1-paths.log" "TEAM_IDENTITY_CONFLICT" "32① 冲突被大声告警（TEAM_IDENTITY_CONFLICT）"
assert_has "$M40_D/1-paths.log" "TEAM_ROOT=$M40_A（继承） ≠ $REPO（按目录推导）" "32① 告警逐条点出被忽略的继承值"
assert_has "$M40_D/1-paths.log" "env -u TEAM_ROOT" "32① 告警给出「清掉继承变量」的出路"
# 解析结果本身（JSON 那一行）里不许出现继承项目的任何值
m40_json() { grep '^{ ' "$1" > "${1%.log}.json" 2>/dev/null || true; }   # 只看 JSON 行（告警行就该印继承值）
m40_json "$M40_D/1-paths.log"
assert_has "$M40_D/1-paths.json" "\"project\": \"$M40_B\"" "32① 项目按 cwd 解析（$M40_B）"
assert_has "$M40_D/1-paths.json" "\"main_root\": \"$REPO\"" "32① 主工作树按 cwd 解析"
assert_has "$M40_D/1-paths.json" "\"worktree\": \"$REPO\"" "32① 工作树按 cwd 解析"
assert_has "$M40_D/1-paths.json" "\"session\": \"$SESSION\"" "32① 会话按 cwd 项目的配置（不是继承的 m40-foreign-session）"
assert_not "$M40_D/1-paths.json" "m40-foreign" "32① 解析结果里没有继承项目的名字"
assert_not "$M40_D/1-paths.json" "rogue" "32① 名册不读继承项目的（rogue 不出现）"
assert_not "$M40_D/1-paths.json" "$M40_A" "32① 解析结果里没有继承项目的路径"
# 机读出口的卫生：告警不许掺进 stdout（面板/脚本就是按行解析 stdout 的 JSON/帧）
m40_foreign $TEAM __panel-data --block frame --events 1 >"$M40_D/1b-panel-data.json" 2>"$M40_D/1b-panel-data.err"; M40_RC=$?
assert_eq "32① 机读出口（__panel-data）在冲突时仍退出码 0" "$M40_RC" "0"
assert_eq "32① 机读出口的 stdout 是纯 JSON（首字节就是 {）" "$(head -c1 "$M40_D/1b-panel-data.json")" "{"
assert_has "$M40_D/1b-panel-data.err" "TEAM_IDENTITY_CONFLICT" "32① 机读出口的告警走 stderr（不弄坏 stdout）"
assert_has "$M40_D/1b-panel-data.json" "\"project\": \"$M40_B\"" "32① 机读出口的数据是 cwd 项目的"

# ② env 与目录一致：照常、不吵（测试逃生门：夹具的常规用法「env 设到 fixture + cwd 也在 fixture」）
m40_own $TEAM paths >"$M40_D/2-paths-ok.log" 2>&1; M40_RC=$?
assert_eq "32② env 与目录一致：退出码 0" "$M40_RC" "0"
assert_has "$M40_D/2-paths-ok.log" "\"main_root\": \"$REPO\"" "32② 一致时照常解析"
assert_not "$M40_D/2-paths-ok.log" "TEAM_IDENTITY_CONFLICT" "32② 一致时不吵（没有冲突告警）"

# ③ 会改共享状态的命令在冲突时被拒；拒绝是真的（看板没被写）
m40_foreign $TEAM board add M40X "外来身份夹具" dev - >"$M40_D/3-refuse.log" 2>&1; M40_RC=$?
assert_eq "32③ 外来身份下 board add 被拒（退出码 1）" "$M40_RC" "1"
assert_has "$M40_D/3-refuse.log" "身份冲突被拒" "32③ 拒绝文案点名身份冲突"
assert_has "$M40_D/3-refuse.log" "当前目录属于 '$M40_B'" "32③ 拒绝文案说清「当前目录属于谁」"
assert_has "$M40_D/3-refuse.log" "env -u TEAM_ROOT" "32③ 拒绝文案给出「清掉继承变量」的出路"
assert_has "$M40_D/3-refuse.log" "只看不改：team paths" "32③ 拒绝文案指向只读的排障形式"
assert_has "$M40_D/3-refuse.log" "TEAM_ALLOW_FOREIGN_IDENTITY=1" "32③ 拒绝文案给出显式授权的逃生门"
if [ -n "$($TEAM board row M40X 2>/dev/null)" ]; then
  bad "32③ 被拒的命令竟然留下了看板行（拒绝只是嘴上说说）"
else
  ok "32③ 被拒的命令没有落盘（M40X 不在看板里）"
fi

# ④ 显式授权：按 cwd 动手 + 照旧告警 + 落审计（不是静默放行）
m40_foreign TEAM_ALLOW_FOREIGN_IDENTITY=1 $TEAM board add M40X "授权夹具" dev - >"$M40_D/4-allow.log" 2>&1; M40_RC=$?
assert_eq "32④ 显式授权后按 cwd 动手（退出码 0）" "$M40_RC" "0"
assert_has "$M40_D/4-allow.log" "TEAM_IDENTITY_CONFLICT" "32④ 授权不是静默：照旧打告警"
assert_has "$M40_D/4-allow.log" "board add M40X" "32④ 动的是 cwd 项目的看板"
assert_has "$REPO/.pi/team/state/watchdog.log" "TEAM_IDENTITY_ALLOW" "32④ 授权落审计（state/watchdog.log）"
assert_has "$REPO/.pi/team/state/watchdog.log" "忽略的继承值" "32④ 审计里带被忽略的继承值（事后可倒查）"
if [ -n "$($TEAM board row M40X 2>/dev/null)" ]; then
  ok "32④ 授权后看板行真的写进 $M40_B"
else
  bad "32④ 授权后看板行没写进去（授权没生效）"
fi

# ⑤ 同一项目的兄弟工作树不是冲突：worker 窗口的形状（env 指主工作树、cwd 在 agent 工作树里）。
#    按路径比会把每个 worker 的每条命令都拒掉，所以判据是「它的主工作树 == 我们的主工作树」。
M40_WT="$REPO/.worktrees/m40probe"
git -C "$REPO" worktree add -b m40-probe-wt "$M40_WT" "$PROTECTED" >/dev/null 2>&1
( cd "$M40_WT" && m40_env TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_PROJECT="$M40_B" TEAM_SESSION="$SESSION" \
    $TEAM paths ) >"$M40_D/5-worktree.log" 2>&1; M40_RC=$?
assert_eq "32⑤ 兄弟工作树：team paths 退出码 0" "$M40_RC" "0"
assert_not "$M40_D/5-worktree.log" "TEAM_IDENTITY_CONFLICT" "32⑤ 「env 指主工作树、cwd 在 agent 工作树」不算冲突"
assert_has "$M40_D/5-worktree.log" "\"worktree\": \"$M40_WT\"" "32⑤ 工作树按 cwd 解析"
assert_has "$M40_D/5-worktree.log" "\"main_root\": \"$REPO\"" "32⑤ 主工作树照旧是项目的主工作树"
assert_has "$M40_D/5-worktree.log" "\"session\": \"$SESSION\"" "32⑤ 会话照旧"
# 改状态的命令也不该被身份闸门误拒（board set 用未知 id：拒绝原因必须是「未知 id」而不是身份冲突）
( cd "$M40_WT" && m40_env TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_PROJECT="$M40_B" TEAM_SESSION="$SESSION" \
    $TEAM board set M40NOPE done ) >"$M40_D/5-mutate.log" 2>&1
assert_not "$M40_D/5-mutate.log" "身份冲突被拒" "32⑤ 工作树里的改状态命令不被身份闸门误拒（worker 每条命令都走这里）"
assert_has "$M40_D/5-mutate.log" "BOARD.md 更新失败" "32⑤ 它被拒是因为别的原因（未知 id），不是身份"
git -C "$REPO" worktree remove --force "$M40_WT" >/dev/null 2>&1 || true
git -C "$REPO" branch -D m40-probe-wt >/dev/null 2>&1 || true

# ⑥ pulse --print（dry-run 形式）：窗口命令里写死的是 cwd 项目的身份，不是继承的 A
m40_foreign $TEAM pulse up --print >"$M40_D/6-pulse-print.log" 2>&1; M40_RC=$?
assert_eq "32⑥ 外来身份 + pulse up --print 退出码 0（dry-run 不改任何东西）" "$M40_RC" "0"
assert_has "$M40_D/6-pulse-print.log" "TEAM_IDENTITY_CONFLICT" "32⑥ dry-run 同样告警"
assert_has "$M40_D/6-pulse-print.log" "tmux 窗口：$SESSION:" "32⑥ 窗口落在 cwd 项目的 session（不是 m40-foreign-session）"
assert_has "$M40_D/6-pulse-print.log" "export TEAM_ROOT='$REPO'" "32⑥ 窗口命令写死 cwd 项目的身份"
assert_has "$M40_D/6-pulse-print.log" "export TEAM_SESSION='$SESSION'" "32⑥ 窗口命令写死 cwd 项目的会话"
assert_not "$M40_D/6-pulse-print.log" "export TEAM_ROOT='$M40_A'" "32⑥ 继承的 A 身份没进窗口命令"
assert_not "$M40_D/6-pulse-print.log" "export TEAM_SESSION='m40-foreign-session'" "32⑥ 继承的会话没进窗口命令"

# ⑦ 面板：不静默渲染别的项目 —— 继承身份与 --root/cwd 不一致时按 cwd 渲染 + 留一行（stderr + state/panel.log）
if [ -n "$JS_RUNNER" ]; then
  M40_PD="$M40_D/panelstate"
  m40_env TEAM_ROOT="$M40_A" "$JS_RUNNER" "$SKILL_DIR/scripts/panel/panel.js" --print \
    --root "$REPO" --state-dir "$M40_PD" --team-cli "$SKILL_DIR/scripts/team" \
    >"$M40_D/7-panel.out" 2>"$M40_D/7-panel.err"; M40_RC=$?
  assert_eq "32⑦ 面板 --print（继承 A）退出码 0" "$M40_RC" "0"
  assert_has "$M40_D/7-panel.err" "TEAM_IDENTITY_CONFLICT (panel)" "32⑦ 面板对继承身份留一行（stderr）"
  assert_has "$M40_D/7-panel.out" "teamsmith pulse · $M40_B" "32⑦ 面板渲染的是 --root/cwd 项目（$M40_B），不是继承的 A"
  assert_not "$M40_D/7-panel.out" "m40-foreign" "32⑦ 渲染结果里没有继承项目"
  assert_has "$M40_PD/panel.log" "ignoring inherited TEAM_ROOT" "32⑦ 同一行也落进本项目的 state/panel.log"
  M40_PD2="$M40_D/panelstate-ok"
  m40_own "$JS_RUNNER" "$SKILL_DIR/scripts/panel/panel.js" --print \
    --root "$REPO" --state-dir "$M40_PD2" --team-cli "$SKILL_DIR/scripts/team" \
    >"$M40_D/7-panel-ok.out" 2>"$M40_D/7-panel-ok.err"; M40_RC=$?
  assert_eq "32⑦ 对照：env 与 root 一致时面板退出码 0" "$M40_RC" "0"
  assert_eq "32⑦ 对照：一致时不吵（stderr 0 行冲突）" "$(grep -cF 'TEAM_IDENTITY_CONFLICT' "$M40_D/7-panel-ok.err" || true)" "0"
  assert_not_file "$M40_PD2/panel.log" "32⑦ 对照：没有冲突就不写 panel.log"
  # 面板派出去的**子进程**也拿不到继承身份：tick 子进程（watch --once，会改状态）必须跑完成，
  # 而不是被身份闸门拒（data.ts 的 cleanIdentityEnv；去掉它，这条就红）
  m40_env TEAM_ROOT="$M40_A" "$JS_RUNNER" "$SKILL_DIR/scripts/panel/panel.js" --once \
    --root "$REPO" --state-dir "$M40_PD" --tick-log "$M40_PD/tick.log" --tick-every 900 \
    --team-cli "$SKILL_DIR/scripts/team" >"$M40_D/7-panel-once.out" 2>"$M40_D/7-panel-once.err"
  assert_has "$M40_PD/tick.log" "watch --once 完成" "32⑦ 面板的 tick 子进程拿不到继承身份（tick 跑完了，不是被拒）"
  assert_not "$M40_PD/tick.log" "身份冲突被拒" "32⑦ tick 没有被身份闸门拒（子进程的 env 是洗过的）"
else
  cond_skip "32⑦·面板冲突告警" "没有 JS 运行时（panel.js 跑不了）"
fi

# ⑧ 真窗口：spawn 清洗 —— pulse / dispatch 起的长驻进程，身份是目标目录推导出来的（真进程）
if [ "$FAST" = "1" ]; then
  fast_skip "32⑧·spawn 清洗（真窗口）" "要真实 tmux 窗口（pulse up + dispatch），快模式不跑"
elif [ "$HAVE_TMUX" != "1" ]; then
  cond_skip "32⑧·spawn 清洗（真窗口）" "没有 tmux"
else
  live_mark
  # 本段自己先占住 pulse 窗口（上一段可能留着别的东西）：拒绝路径要证明的是「没有新窗口」
  $TEAM pulse down >/dev/null 2>&1 || true
  tmux kill-window -t "$SESSION:pulse" 2>/dev/null || true
  # ── ⑧a 未授权：拒绝发生在起窗口之前（现场不留窗口、更不留别的 session）
  m40_foreign $TEAM pulse up >"$M40_D/8a-refuse.log" 2>&1; M40_RC=$?
  assert_eq "32⑧a 外来身份下 pulse up（未授权）被拒" "$M40_RC" "1"
  assert_has "$M40_D/8a-refuse.log" "身份冲突被拒" "32⑧a 拒绝理由：身份冲突"
  assert_eq "32⑧a 拒绝后没有 pulse 窗口" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx pulse || true)" "0"
  if tmux has-session -t m40-foreign-session 2>/dev/null; then
    bad "32⑧a 继承的 session 被建了出来（窗口落错项目）"
    tmux kill-session -t m40-foreign-session 2>/dev/null || true
  else
    ok "32⑧a 继承项目的 session 没被碰（m40-foreign-session 不存在）"
  fi

  # ── ⑧b 授权后：真起 pulse，窗口里的面板进程带的是本项目身份（事故②的形状，反过来钉住）
  m40_foreign TEAM_ALLOW_FOREIGN_IDENTITY=1 $TEAM pulse up >"$M40_D/8b-up.log" 2>&1; M40_RC=$?
  assert_eq "32⑧b 授权后 pulse up 退出码 0" "$M40_RC" "0"
  assert_has "$M40_D/8b-up.log" "TEAM_IDENTITY_CONFLICT" "32⑧b 授权后照旧告警（不是静默）"
  assert_eq "32⑧b 窗口建在本项目 session" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx pulse || true)" "1"
  # 等 pane 里的进程 exec 成面板（pane_pid 的命令行出现 panel.js），再读它真实的 environ
  M40_W=0; M40_PID=""; M40_PCMD=""
  while [ "$M40_W" -lt 60 ]; do
    M40_PID="$(tmux list-panes -t "$SESSION:pulse" -F '#{pane_pid}' 2>/dev/null | head -1)"
    M40_PCMD="$(tr '\0' ' ' < "/proc/${M40_PID:-0}/cmdline" 2>/dev/null || true)"
    case "$M40_PCMD" in *panel.js*) break ;; esac
    sleep 0.25; M40_W=$((M40_W + 1))
  done
  if [ -n "$M40_PID" ] && [ -r "/proc/$M40_PID/environ" ]; then
    tr '\0' '\n' < "/proc/$M40_PID/environ" > "$M40_D/8b-pane-env.log"
    assert_has "$M40_D/8b-pane-env.log" "TEAM_ROOT=$REPO" "32⑧b 窗口进程 TEAM_ROOT = cwd 项目（面板进程实测 environ）"
    assert_has "$M40_D/8b-pane-env.log" "TEAM_MAIN_ROOT=$REPO" "32⑧b 窗口进程 TEAM_MAIN_ROOT = cwd 项目"
    assert_has "$M40_D/8b-pane-env.log" "TEAM_SESSION=$SESSION" "32⑧b 窗口进程 TEAM_SESSION = cwd 项目的会话"
    assert_not "$M40_D/8b-pane-env.log" "$M40_A" "32⑧b 继承的 A 身份一个字节都没进窗口进程的 environ"
  else
    bad "32⑧b 等不到面板进程（pane_pid=${M40_PID:-?} cmd=[$M40_PCMD]）—— 无法证明窗口进程的身份"
  fi
  # 面板渲染的是本项目（标题带带项目名）：事故②「渲染出 pm-skills 看板」的反面
  M40_LOGS_WAIT=0
  $TEAM pulse logs >"$M40_D/8b-logs.log" 2>&1 || true
  while [ "$M40_LOGS_WAIT" -lt 40 ]; do
    grep -qF "teamsmith pulse · $M40_B" "$M40_D/8b-logs.log" 2>/dev/null && break
    sleep 0.5; $TEAM pulse logs >"$M40_D/8b-logs.log" 2>&1 || true
    M40_LOGS_WAIT=$((M40_LOGS_WAIT + 1))
  done
  assert_has "$M40_D/8b-logs.log" "teamsmith pulse · $M40_B" "32⑧b 面板画面是 cwd 项目（$M40_B）"
  assert_not "$M40_D/8b-logs.log" "m40-foreign" "32⑧b 面板画面里没有继承项目"
  $TEAM pulse down >/dev/null 2>&1 || tmux kill-window -t "$SESSION:pulse" 2>/dev/null || true

  # ── ⑧c dispatch：worker 窗口带的是**它的工作树**身份（不是继承的 A，也不是 PM 的目录关系）
  GPW_BRANCH="$(canon_branch m40w M40W)"
  cat > "$FAKE/m40-probe.sh" <<EOF
#!/usr/bin/env bash
env | sort > "$M40_D/8c-worker-env.log"
printf 'done\n' > "$M40_D/8c-worker.done"
exit 0
EOF
  chmod +x "$FAKE/m40-probe.sh"
  # P24（B3）：change-less 的任务书要有锚（本节测的是身份推导）
  printf '# M40W 夹具 brief\n\nanchor: none (infra) — smoke fixture\n' > "$REPO/.pi/team/state/M40W-brief.md"
  git -C "$REPO" worktree add -b "$GPW_BRANCH" "$REPO/.worktrees/m40w" "$PROTECTED" >/dev/null 2>&1
  rm -f "$M40_D/8c-worker-env.log" "$M40_D/8c-worker.done"
  m40_foreign TEAM_ALLOW_FOREIGN_IDENTITY=1 TEAM_AGENTS="dev m40w" \
      TEAM_AGENT_CMD="$FAKE/m40-probe.sh" TEAM_AGENT_BIN="$FAKE/m40-probe.sh" \
      $TEAM dispatch m40w M40W .pi/team/state/M40W-brief.md >"$M40_D/8c-dispatch.log" 2>&1 \
    && ok "32⑧c 授权后派单成功" || { bad "32⑧c 派单失败"; tail -3 "$M40_D/8c-dispatch.log"; }
  M40_W=0
  while [ "$M40_W" -lt 100 ] && [ ! -f "$M40_D/8c-worker.done" ]; do sleep 0.2; M40_W=$((M40_W + 1)); done
  if [ -f "$M40_D/8c-worker-env.log" ]; then
    assert_match "$M40_D/8c-worker-env.log" "^TEAM_ROOT=$REPO/.worktrees/m40w\$" "32⑧c worker 窗口 TEAM_ROOT = 它的工作树（目标目录推导）"
    assert_match "$M40_D/8c-worker-env.log" "^TEAM_MAIN_ROOT=$REPO\$" "32⑧c worker 窗口 TEAM_MAIN_ROOT = 项目主工作树"
    assert_not "$M40_D/8c-worker-env.log" "$M40_A" "32⑧c 继承的 A 身份一个字节都没进 worker 窗口"
  else
    bad "32⑧c worker 窗口的 env 没落盘（探针没跑起来）"
  fi
  tmux kill-window -t "$SESSION:m40w" 2>/dev/null || true
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/m40w" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$GPW_BRANCH" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/m40w.env" "$REPO/.pi/team/state/M40W-brief.md"
  assert_eq "32⑧c 收尾：夹具窗口清干净" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx m40w || true)" "0"
fi

section "33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema）"
# P22/B1：headless 夹具（tests/config-cli.sh）——不依赖 tmux/真进程，FAST 模式照跑。
if [ -f "$SKILL_DIR/tests/config-cli.sh" ]; then
  if bash "$SKILL_DIR/tests/config-cli.sh" >"$TMP/config-cli.log" 2>&1; then
    ok "33 config-cli.sh 全绿（$(grep -ac '✓' "$TMP/config-cli.log" || true) 条断言）"
    tail -2 "$TMP/config-cli.log" | sed 's/^/      /'
  else
    bad "33 config-cli.sh 有失败"
    grep -a '✗' "$TMP/config-cli.log" | head -10 | sed 's/^/      /'
    tail -3 "$TMP/config-cli.log" | sed 's/^/      /'
  fi
else
  bad "33 缺 tests/config-cli.sh"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 12e–12j · change 为中心的纪律（P24 apply：B1 / B3 / B4 / B5 / B6）
#
# 夹具是**自己的 scratch 项目**（$TMP/p24/<名字>）：team init + 任务书 + 一个只记账的 tmux shim。
# 不碰 $REPO、不起真进程（[real] 子段除外，那里 live_mark 并真起 tmux 场地）。
# 判据编号对应 openspec/changes/change-centric-discipline/tasks.md；B2（digest/面板归组）本任务不做。
# ═════════════════════════════════════════════════════════════════════════════
P24_ROOT="$TMP/p24"
P24_SHIM="$P24_ROOT/shim"
P24_SHIM_LOG="$P24_ROOT/shim-calls.log"
mkdir -p "$P24_SHIM"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit 0\n' "$P24_SHIM_LOG" > "$P24_SHIM/tmux"
chmod +x "$P24_SHIM/tmux"

p24_project() { # <名字> [<agents>] → 打印项目路径（git + team init + openspec/specs + change alpha 目录）
  local name="$1" agents="${2:-dev verify dev2}" p
  p="$P24_ROOT/$name"
  rm -rf "$p"; mkdir -p "$p"
  ( cd "$p" && git init -q -b main && git config user.email p24@smoke && git config user.name p24 \
      && git commit -q --allow-empty -m "chore: init" ) >/dev/null 2>&1
  ( cd "$p" && $TEAM init --session "p24-$name" --agents "$agents" --vcs local --gates "true" --docs docs/team ) >"$p/.init.log" 2>&1
  printf 'TEAM_PI_BIN="/bin/true"\n' >> "$p/.pi/team/config.sh"
  mkdir -p "$p/openspec/specs/panel" "$p/openspec/specs/dispatch"
  printf '### Requirement: The board page is a kanban over the board\x27s states\n' > "$p/openspec/specs/panel/spec.md"
  printf '### Requirement: A brief is self-contained and names its evidence\n' > "$p/openspec/specs/dispatch/spec.md"
  p24_change "$p" alpha
  printf '%s\n' "$p"
}
p24_change() { # <项目> <change id> → 建一个带 panel delta 的 change 目录
  local p="$1" c="$2"
  mkdir -p "$p/openspec/changes/$c/specs/panel"
  printf '## MODIFIED Requirements\n\n### Requirement: %s delta fixture\n' "$c" > "$p/openspec/changes/$c/specs/panel/spec.md"
}
p24_brief() { # <项目> <ID> <agent> <phase> <change> <deltas|@absent> [<anchor>] [<specs>]
  local p="$1" id="$2" agent="$3" phase="$4" change="$5" deltas="$6" anchor="${7:-}" specs="${8:--}"
  mkdir -p "$p/docs/team/tasks"
  {
    printf '# %s · fixture\n\n```\n' "$id"
    printf 'task:   %s\nagent:  %s\nissue:  -\n' "$id" "$agent"
    printf 'change: %s\nspecs:  %s\nphase:  %s\ndeps:   -\nstatus: todo\nbudget: -\n' "$change" "$specs" "$phase"
    [ -n "$anchor" ] && printf 'anchor: %s\n' "$anchor"
    [ "$deltas" = "@absent" ] || printf 'deltas: %s\n' "$deltas"
    printf '```\n\nbody\n'
  } > "$p/docs/team/tasks/$id-fixture.md"
  return 0
}
p24_add() { # <项目> <ID> [<agent>]
  local p="$1" id="$2" agent="${3:-dev}"
  ( cd "$p" && $TEAM board add "$id" "$id fixture" "$agent" - - ) >/dev/null 2>&1
  return 0
}
p24_team() { # <项目> <args...> → team CLI（stdout+stderr 合并）
  local p="$1"; shift
  ( cd "$p" && $TEAM "$@" ) 2>&1
}
p24_dispatch() { # <项目> <agent> <ID> <brief> [args...] → 记录式 shim 下的 dispatch（stdout+stderr）
  local p="$1" agent="$2" id="$3" brief="$4"; shift 4
  : > "$P24_SHIM_LOG"
  ( cd "$p" && env PATH="$P24_SHIM:$PATH" TEAM_DISPATCH_VERIFY_SEC=1 TEAM_DISPATCH_ALIVE_SEC=0 \
      $TEAM dispatch "$agent" "$id" "$brief" "$@" ) 2>&1
}
p24_shim_windows() { grep -cE 'new-window|new-session|respawn-pane' "$P24_SHIM_LOG" 2>/dev/null || true; }
p24_branch() { # <项目> <agent> <ID> → 规范任务分支（canon_branch 绑死在 $REPO，这里自己算）
  ( cd "$1" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_branch_for_agent "'"$2"'" "'"$3"'"' )
}
p24_wt() { # <项目> <agent> <ID> → 把该 agent 的 worktree 停在 <ID> 的规范分支上（可重复调用）
  local p="$1" a="$2" id="$3" br
  git -C "$p" worktree remove --force "$p/.worktrees/$a" >/dev/null 2>&1 || true
  git -C "$p" worktree prune >/dev/null 2>&1 || true
  br="$(p24_branch "$p" "$a" "$id")"
  [ -n "$br" ] || return 1
  git -C "$p" branch -D "$br" >/dev/null 2>&1 || true
  git -C "$p" worktree add -b "$br" "$p/.worktrees/$a" main >/dev/null 2>&1 || return 1
  rm -f "$p/.pi/team/state/$a.env"
  return 0
}
p24_pass() { # <项目> <id> → review 记录 PASS
  local p="$1" id="$2"
  mkdir -p "$p/docs/team/reviews"
  printf -- '- 2026-09-20T00:00:00Z · `team review %s` · 判定: **PASS**\n' "$id" > "$p/docs/team/reviews/$id.md"
}
p24_board_row() { p24_team "$1" board row "$2" 2>/dev/null | tail -1; }
p24_unchanged() { # <项目> <ID> <原行> <说明>
  assert_eq "$4：看的板行没被改动" "$(p24_board_row "$1" "$2")" "$3"
}
p24_json_ok() { # <文本> → 0=是合法 JSON（没有解析器时退化成形状检查）
  local t="$1"
  if command -v python3 >/dev/null 2>&1; then printf '%s' "$t" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; return $?; fi
  if [ -n "$JS_RUNNER" ]; then printf '%s' "$t" | "$JS_RUNNER" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s))' >/dev/null 2>&1; return $?; fi
  case "$t" in '{"id":'*'}') return 0 ;; esac
  return 1
}
p24_read() { # <项目> <函数名> <brief> → 在项目上下文里直接驱动读取器（stdout+stderr 原样）
  ( cd "$1" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; for _f in "'"$SKILL_DIR"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; "$@"' _ "$2" "$3" ) 2>&1
}

# ---------------------------------------------------------------- 12e · change 视图（B1）
section "12e · change 视图（P24/B1：严格头部读取 + 就绪判据）"
if bash "$SKILL_DIR/tests/task-header-model.sh" >"$TMP/p24-header.log" 2>&1; then
  ok "头部严格读取夹具全绿（$(grep -ac '✓' "$TMP/p24-header.log" 2>/dev/null || echo 0) 条断言）"
else
  bad "头部严格读取夹具有失败"
  grep -a '✗' "$TMP/p24-header.log" | head -5 | sed 's/^/      /'
fi

P24E_R="$(p24_project 12e-ready)"
p24_brief "$P24E_R" M1 dev apply alpha -
p24_brief "$P24E_R" V1 verify verify alpha -
p24_add "$P24E_R" M1 dev; p24_add "$P24E_R" V1 verify
p24_pass "$P24E_R" M1; p24_pass "$P24E_R" V1
p24_team "$P24E_R" board set M1 done >/dev/null 2>&1
p24_team "$P24E_R" board set V1 done >/dev/null 2>&1
E_READY="$(p24_team "$P24E_R" change status alpha)"; E_READY_RC=$?
assert_eq "12e 全结束 → 退出 0" "$E_READY_RC" "0"
assert_has_echo "$E_READY" "change alpha · ready" "12e 就绪行说明 ready"
assert_has_echo "$E_READY" "docs/team/M1.md: PASS" "12e 任务行带复验判定"
assert_has_echo "$E_READY" "docs/team/V1.md: PASS" "12e verify 任务的证据也在一行里"
assert_has_echo "$E_READY" "delta files (openspec/changes/alpha/specs/)" "12e 列出 delta 文件段"

P24E_N="$(p24_project 12e-notready)"
p24_brief "$P24E_N" M1 dev apply alpha -
p24_brief "$P24E_N" M2 dev2 apply alpha -
p24_brief "$P24E_N" V1 dev verify alpha -
p24_add "$P24E_N" M1 dev; p24_add "$P24E_N" M2 dev2; p24_add "$P24E_N" V1 dev
p24_pass "$P24E_N" M1
p24_team "$P24E_N" board set M1 done >/dev/null 2>&1
p24_team "$P24E_N" board set M2 wip >/dev/null 2>&1
E_NR="$(p24_team "$P24E_N" change status alpha)"; E_NR_RC=$?
assert_eq "12e 有未结束兄弟 → 退出 1" "$E_NR_RC" "1"
assert_has_echo "$E_NR" "change alpha · not ready" "12e 就绪行说明 not ready"
assert_has_echo "$E_NR" "M2 · apply · wip ·" "12e blocker 点名 M2/阶段/看板状态"
assert_has_echo "$E_NR" "review" "12e 缺失证据说明去哪找（复验记录）"
assert_has_echo "$E_NR" "self-verify: dev（作者任务 M1）" "12e verify 的 agent 是 apply 作者 → self-verify 标记"
assert_not_echo "$E_NR" "self-verify: dev2" "12e 没写过 apply 的 agent 不带标记"
# 只读证据：命令不动工作区、不动看板
E_BEFORE="$(cd "$P24E_N" && git status --porcelain; md5sum docs/team/BOARD.md | cut -d' ' -f1)"
p24_team "$P24E_N" change status alpha >/dev/null 2>&1 || true
E_AFTER="$(cd "$P24E_N" && git status --porcelain; md5sum docs/team/BOARD.md | cut -d' ' -f1)"
assert_eq "12e change status 只读（工作区 + BOARD 字节不变）" "$E_AFTER" "$E_BEFORE"
# --json 与人类视图同源
E_JSON="$(p24_team "$P24E_N" change status alpha --json)"; E_JSON_RC=$?
assert_eq "12e --json 未就绪退出 1" "$E_JSON_RC" "1"
if p24_json_ok "$E_JSON"; then ok "12e --json 是合法 JSON"; else bad "12e --json 解析失败（$E_JSON）"; fi
assert_has_echo "$E_JSON" '"id":"alpha"' "12e --json 带 id"
assert_has_echo "$E_JSON" '"ready":false' "12e --json 带 ready=false"
assert_has_echo "$E_JSON" '"tasks":[{"id":"M1"' "12e --json 每个映射任务一条"
assert_has_echo "$E_JSON" '"deltas":[{"file":"panel/spec.md"' "12e --json 带 delta 文件视图"
assert_has_echo "$E_JSON" '"blockers":[' "12e --json 带 blockers"
assert_has_echo "$E_JSON" 'M2 · apply · wip ·' "12e --json 的 blocker 就是未结束的那个任务"
E_UNK="$(p24_team "$P24E_N" change status no-such-change)"; E_UNK_RC=$?
assert_eq "12e 未知 id → 非 0" "$([ "$E_UNK_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$E_UNK" "没有任务指向它" "12e 未知 id 说清「没有任务」"
assert_has_echo "$E_UNK" "openspec/changes/no-such-change/ 目录" "12e 未知 id 说清「没有 change 目录」"

# ---------------------------------------------------------------- 12f · change 归组（P45/B2）
# P45/B2：digest 的 [6] 段 + 面板的 token 行。夹具仍是 p24_project 的 scratch 项目（不碰 $REPO、
# 不起真进程）。面板布局一节用**真读者**的输出（team __panel-data --block changes）渲染页 2 的帧：
# reader 与 layout 的键名一旦漂移，这一节就红；其余块的确定性来自 tests/panel-b3-stub.sh。
section "12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token）"

P45F="$(p24_project 12f)"
p24_change "$P45F" nodir
p24_change "$P45F" notask
p24_change "$P45F" gamma
rm -rf "$P45F/openspec/changes/nodir"
p24_brief "$P45F" M1 dev apply alpha -
p24_brief "$P45F" M2 dev2 apply alpha -
p24_brief "$P45F" N1 dev apply nodir -
p24_brief "$P45F" X1 dev apply - -            # change: - → 不归任何 change
for _i in 01 02 03 04 05 06 07 08 09 10; do p24_brief "$P45F" "G$_i" dev apply gamma -; done
for _id in M1 M2 N1 X1 G01 G02 G03 G04 G05 G06 G07 G08 G09 G10; do p24_add "$P45F" "$_id" dev; done
p24_pass "$P45F" M1
p24_team "$P45F" board set M1 done >/dev/null 2>&1
p24_team "$P45F" board set M2 wip >/dev/null 2>&1
p24_team "$P45F" board set N1 wip >/dev/null 2>&1

F_DG="$(p24_team "$P45F" digest)"
F6="$(printf '%s\n' "$F_DG" | sed -n '/^\[6\] change 归组/,$p')"
assert_has_echo "$F6" "change alpha · not ready → M1 done · M2 wip" "12f [6]：alpha 的 token 与 not-ready 标记"
assert_has_echo "$F6" "change nodir · not ready（change 目录不存在）→ N1 wip" "12f [6]：任务指向不存在的目录 → 标记点名"
assert_has_echo "$F6" "change notask · （没有任务指向它）" "12f [6]：目录没有任务指向 → 标记"
assert_not_echo "$F6" "X1" "12f [6]：change: - 的任务不归任何 change"
assert_has_echo "$F6" "G08 todo · +2" "12f [6]：token 上限 8 + 「+N」尾巴"
assert_not_echo "$F6" "G09 todo" "12f [6]：第 9 个任务不打印（token 有界）"
# [1]–[5] 的段头逐字节不变（钉住的字面量），新段是 [6]
F_HDRS="$(printf '%s\n' "$F_DG" | grep -E '^\[[0-9]+\]')"
F_HDRS_EXPECTED="$(cat <<'EOH'
[1] 容量与存活
[2] 待处理通知
[3] 待复验（真任务报告：记录缺失 / 记录已过期（分支又动了）/ 没跑过门禁；草稿另标；看板已 done/closed 的不列）
[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 main 另计；squash 已合并单独标注）
[5] 任务板
[5] 建议
[6] change 归组
EOH
)"
assert_eq "12f [1]–[5] 段头逐字节不变、新段是 [6]" "$F_HDRS" "$F_HDRS_EXPECTED"
# token 与 `team change status alpha` 同一个账本（同一批 ID + 看板状态）
F_CS="$(p24_team "$P45F" change status alpha)"
F_TOK_DG="$(printf '%s\n' "$F6" | sed -n 's/^  change alpha · not ready → //p')"
F_TOK_CS="$(printf '%s\n' "$F_CS" | awk '/^  tasks$/{t=1;next} /^  delta files/{t=0} t && /^    / {printf "%s%s %s", (n++ ? " · " : ""), $1, $4}')"
assert_eq "12f [6] 的 token 与 team change status alpha 一致" "$F_TOK_DG" "$F_TOK_CS"
# 段本身有界：8 行 + 「+N」尾巴（单独一个夹具，避免挤掉上面的断言）
P45M="$(p24_project 12f-many)"
for _i in 1 2 3 4 5 6 7 8 9; do p24_change "$P45M" "many$_i"; done
M6="$(p24_team "$P45M" digest | sed -n '/^\[6\] change 归组/,$p')"
assert_has_echo "$M6" "… +2（另有 2 个未归档 change）" "12f [6]：change 列表有界（8 行 + 「+N」尾巴）"
# 无事时一条 dim 空行（连 change 目录也没有）
P45E="$(p24_project 12f-none)"
rm -rf "$P45E/openspec/changes/alpha"
E6="$(p24_team "$P45E" digest | sed -n '/^\[6\] change 归组/,$p' | sed 's/\x1b\[[0-9;]*m//g' | sed -n '2p')"
assert_eq "12f [6]：无事时一条 dim 空行" "$E6" "  （无）"

# ---- 面板：__panel-data 的 tokens（--print/--json 是机器出口，见下）
P45_PJ="$TMP/p45f-changes.json"
p24_team "$P45F" __panel-data --block changes >"$P45_PJ" 2>&1
if p24_json_ok "$(cat "$P45_PJ")"; then ok "12f 面板：__panel-data --block changes 是合法 JSON"; else bad "12f 面板：changes 块解析失败（$(head -c 200 "$P45_PJ")）"; fi
p45_check() { # <python 表达式> <说明>（d = 整个 changes 块，by = 按 id 索引）
  if python3 - "$P45_PJ" "$1" <<'P45Y' >/dev/null 2>&1
import json, sys
d = json.load(open(sys.argv[1]))
by = {c["id"]: c for c in d["changes"]}
sys.exit(0 if eval(sys.argv[2]) else 1)
P45Y
  then ok "$2"; else bad "$2"; fi
}
p45_check 'by["alpha"]["tasks"] == [{"id": "M1", "phase": "apply", "board": "done", "verdict": "PASS"}, {"id": "M2", "phase": "apply", "board": "wip", "verdict": "missing"}]' \
  "12f 面板：alpha 的每个 token 带 id/phase/board/verdict（M1 PASS）"
p45_check 'len(by["gamma"]["tasks"]) == 8 and by["gamma"]["tasks_more"] == 2' \
  "12f 面板：token 数组有界（8 个 + tasks_more=2）"
# 面板的 change 行来自目录列表 / `openspec list`；「任务指向不存在的目录」这种异常没有可挂靠的行，
# 它在 digest 的 [6] 段里点名（design §7 的两个标记属于 digest 段；面板只负责已有 change 的归组）。

# ---- 机器出口：--print/--json 与 change 数据面无关（console-only 块）
p45_mem=(TEAM_MEMINFO_FILE="$TMP/meminfo-plenty" TEAM_SWAPFILE_PATH="$TMP/swaps")
p45_mon() { ( cd "$P45F" && env "${p45_mem[@]}" $TEAM "$@" ) 2>&1; }
p45_norm() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/g' "$1"; }
if [ -z "$JS_RUNNER" ]; then
  cond_skip "12f·机器出口" "没有 node/bun：面板渲染不了"
else
  p45_mon monitor --print >"$TMP/p45f-print1.txt"
  p45_mon monitor --json >"$TMP/p45f-json1.json"
  assert_has "$TMP/p45f-print1.txt" "teamsmith pulse" "12f 机器出口：--print 渲染出了帧（后面的「不该出现」断言不是空跑）"
  assert_not "$TMP/p45f-print1.txt" "M1 done" "12f 机器出口：--print 不带 change 的 token（console-only）"
  assert_not "$TMP/p45f-json1.json" '"tasks":' "12f 机器出口：--json 的 panel 里没有 tasks 字段（console-only）"
  # 只在 change 的**任务映射**上制造变化：给 alpha 加一条任务书（不建看板行、不建目录）——
  # 面板的 token 会多一个，而机器出口读的那些面（看板计数、变更数、报告面）一个都不动。
  p24_brief "$P45F" L1 dev apply alpha -
  p24_team "$P45F" __panel-data --block changes >"$TMP/p45f-changes2.json" 2>&1
  assert_has "$TMP/p45f-changes2.json" '"id": "L1"' "12f 机器出口：变化真的落在面板块里（字节不变的对照成立）"
  p45_mon monitor --print >"$TMP/p45f-print2.txt"
  p45_mon monitor --json >"$TMP/p45f-json2.json"
  if diff <(p45_norm "$TMP/p45f-print1.txt") <(p45_norm "$TMP/p45f-print2.txt") >"$TMP/p45f-print.diff" 2>&1; then
    ok "12f 机器出口：change 数据面变化前后 --print 逐字节一致（滤时间戳）"
  else
    bad "12f 机器出口：--print 被 change 数据面影响了"; head -4 "$TMP/p45f-print.diff" | sed 's/^/      /'
  fi
  if diff <(p45_norm "$TMP/p45f-json1.json") <(p45_norm "$TMP/p45f-json2.json") >"$TMP/p45f-json.diff" 2>&1; then
    ok "12f 机器出口：change 数据面变化前后 --json 逐字节一致（滤时间戳）"
  else
    bad "12f 机器出口：--json 被 change 数据面影响了"; head -4 "$TMP/p45f-json.diff" | sed 's/^/      /'
  fi
fi

# ---- 面板布局：token 行「宽度不够 → 整行丢弃（不重排）」
P45_STUB="$TMP/p45-panel-stub"
cat >"$P45_STUB" <<'EOS'
#!/usr/bin/env bash
blk=""; prev=""
for a in "$@"; do [ "$prev" = "--block" ] && blk="$a"; prev="$a"; done
if [ "${blk:-}" = "changes" ]; then printf '%s\n' "$P45_CHANGES_JSON"; exit 0; fi
exec bash "$P45_B3_STUB" "$@"
EOS
chmod +x "$P45_STUB"
if [ -z "$JS_RUNNER" ]; then
  cond_skip "12f·面板布局" "没有 node/bun：面板渲染不了"
else
  P45_PANEL="$SKILL_DIR/scripts/panel/panel.js"
  # gamma 的 8 个 token（约 95 列）在 160 列档的右栏（70）里放不下；alpha 的 2 个 token 放得下。
  python3 - "$TMP/p45f-changes.json" "$TMP/p45f-changes-nogamma.json" <<'P45J'
import json, sys
d = json.load(open(sys.argv[1]))
for c in d["changes"]:
    if c["id"] == "gamma":
        c["tasks"] = []
        c["tasks_more"] = 0
json.dump(d, open(sys.argv[2], "w"))
P45J
  p45_frame() { # <changes json> <width> <out>
    env P45_CHANGES_JSON="$(cat "$1")" P45_B3_STUB="$SKILL_DIR/tests/panel-b3-stub.sh" \
      "$JS_RUNNER" "$P45_PANEL" --snapshot --root "$TMP" --state-dir "$TMP/p45-panel-state" \
      --team-cli "$P45_STUB" --width "$2" --height 32 --theme dark --lang zh --page 2 >"$3" 2>"$3.err"
  }
  mkdir -p "$TMP/p45-panel-state"
  p45_frame "$P45_PJ" 160 "$TMP/p45f-frame-160.txt"
  p45_frame "$TMP/p45f-changes-nogamma.json" 160 "$TMP/p45f-frame-160-nogamma.txt"
  p45_frame "$P45_PJ" 270 "$TMP/p45f-frame-270.txt"
  p45_strip() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
  if [ -s "$TMP/p45f-frame-160.txt" ]; then ok "12f 布局：160 列帧渲染出来了"; else bad "12f 布局：160 列帧是空的（$(tail -2 "$TMP/p45f-frame-160.txt.err")"; fi
  assert_has_echo "$(p45_strip "$TMP/p45f-frame-160.txt")" "M1 done · M2 wip" "12f 布局：放得下的 token 行照常渲染"
  assert_not_echo "$(p45_strip "$TMP/p45f-frame-160.txt")" "G01 todo" "12f 布局：放不下的 token 行整行丢弃（不截断、不折行）"
  if cmp -s "$TMP/p45f-frame-160.txt" "$TMP/p45f-frame-160-nogamma.txt"; then
    ok "12f 布局：丢弃那一行后与「本来就没有这些 token」逐字节一致（不重排布局）"
  else
    bad "12f 布局：丢弃 token 行改变了别的行（重排了）"; diff <(p45_strip "$TMP/p45f-frame-160.txt") <(p45_strip "$TMP/p45f-frame-160-nogamma.txt") | head -4 | sed 's/^/      /'
  fi
  assert_has_echo "$(p45_strip "$TMP/p45f-frame-270.txt")" "G01 todo · G02 todo" "12f 布局：宽度够（270 列）时 token 行渲染出来"
  # 行宽按**显示列**算（CJK 是 2 列；字节数会把中文行算成两倍）
  P45_WIDE_MAX="$(p45_strip "$TMP/p45f-frame-270.txt" | python3 -c '
import sys, unicodedata
def w(s): return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
print(max((w(l.rstrip("\n")) for l in sys.stdin), default=0))
')"
  [ "$P45_WIDE_MAX" -le 270 ] && ok "12f 布局：270 列的帧没有行溢出（最长 $P45_WIDE_MAX 列）" || bad "12f 布局：270 列帧有行溢出（最长 $P45_WIDE_MAX 列）"
fi

# ---- 读成本：digest 的 git 调用数仍在 M50 预算（≤ 50）内
P45_GITSHIM="$TMP/p45-gitshim"; P45_GCALLS="$TMP/p45-git-calls.log"
mkdir -p "$P45_GITSHIM"; : >"$P45_GCALLS"
P45_REAL_GIT="$(command -v git)"
cat >"$P45_GITSHIM/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$P45_GCALLS" 2>/dev/null || true
exec "$P45_REAL_GIT" "\$@"
EOF
chmod +x "$P45_GITSHIM/git"
( cd "$P45F" && env PATH="$P45_GITSHIM:$PATH" $TEAM digest ) >"$TMP/p45f-digest-counted.out" 2>&1 || true
P45_GN="$(wc -l < "$P45_GCALLS" | tr -d ' ')"
if [ "$P45_GN" -le 50 ]; then ok "12f 读成本：digest 的 git 调用数 ≤ 50（实测 $P45_GN）"; else bad "12f 读成本：digest 的 git 调用数 $P45_GN > 50"; sort "$P45_GCALLS" | uniq -c | sort -rn | head -5 | sed 's/^/      /'; fi
assert_has "$TMP/p45f-digest-counted.out" "change alpha · not ready" "12f 读成本：计数那一跑真的渲染了 [6] 段（不是空转）"


# ---------------------------------------------------------------- 12g · 派单锚点（B3）
section "12g · 派单锚点（P24/B3：一个 change id + change-less 的锚）"
P24G="$(p24_project 12g)"
# 拒绝夹具（不需要 worktree：守卫在开窗之前）
p24_brief "$P24G" G1 dev apply "alpha, beta" -
p24_brief "$P24G" G2 dev apply "alpha beta" -
{
  printf '# G3 · fixture\n\n```\ntask:   G3\nagent:  dev\nchange: alpha\nchange: beta\nphase:  apply\ndeltas: -\n```\n'
} > "$P24G/docs/team/tasks/G3-fixture.md"
p24_brief "$P24G" N1 dev apply - - "" -
p24_brief "$P24G" N2 dev apply - - "none (infra) —"
p24_brief "$P24G" N3 dev apply - - "" "no-such-capability#x"
p24_brief "$P24G" N4 dev apply - - "" "panel#Not A Requirement"
for _id in G1 G2 G3 N1 N2 N3 N4; do p24_add "$P24G" "$_id" dev; done
G1_ROW="$(p24_board_row "$P24G" G1)"
for _case in "G1:change: 的值是 \`alpha, beta\`" "G2:change: 的值是 \`alpha beta\`" "G3:change: 有 2 行"; do
  _id="${_case%%:*}"; _frag="${_case#*:}"
  _out="$(p24_dispatch "$P24G" dev "$_id" "docs/team/tasks/$_id-fixture.md" --print)"; _rc=$?
  assert_eq "12g $_id 多 change → 拒绝（--print 也一样）" "$([ "$_rc" -ne 0 ] && echo yes || echo no)" "yes"
  assert_has_echo "$_out" "拒绝派单：$_id" "12g $_id 的拒绝来自规则 1（不是后面的失败）"
  assert_has_echo "$_out" "$_frag" "12g $_id 拒绝点名出错的那一行"
  assert_has_echo "$_out" "接受的形式" "12g $_id 拒绝列出接受的形式"
  assert_not_echo "$_out" "=== 提示词" "12g $_id --print 不打印提示词"
  assert_eq "12g $_id 拒绝发生在开窗之前" "$(p24_shim_windows)" "0"
done
p24_unchanged "$P24G" G1 "$G1_ROW" "12g 派单被拒"
for _case in "N1:specs: 是空的" "N2:少了理由" "N3:openspec/specs/no-such-capability/spec.md" "N4:### Requirement: Not A Requirement"; do
  _id="${_case%%:*}"; _frag="${_case#*:}"
  N_ROW="$(p24_board_row "$P24G" "$_id")"
  _out="$(p24_dispatch "$P24G" dev "$_id" "docs/team/tasks/$_id-fixture.md")"; _rc=$?
  assert_eq "12g $_id 锚缺失/不解析 → 拒绝" "$([ "$_rc" -ne 0 ] && echo yes || echo no)" "yes"
  assert_has_echo "$_out" "拒绝派单：$_id" "12g $_id 的拒绝来自锚守卫（不是后面的失败）"
  assert_has_echo "$_out" "$_frag" "12g $_id 拒绝说明具体缺什么"
  assert_has_echo "$_out" "specs: <capability>#<requirement>" "12g $_id 列出两种接受形式（specs 式）"
  assert_has_echo "$_out" "anchor: none (infra) — <非空理由>" "12g $_id 列出两种接受形式（infra 式）"
  assert_eq "12g $_id 拒绝发生在开窗之前" "$(p24_shim_windows)" "0"
  p24_unchanged "$P24G" "$_id" "$N_ROW" "12g $_id 被拒"
done
# 允许形态：一个 id；specs 解析；infra 带理由（都要 worktree 才能走到 --print 输出）
p24_brief "$P24G" A1 dev apply alpha -
p24_add "$P24G" A1 dev
p24_brief "$P24G" A2 verify apply - - "" "panel#The board page is a kanban over the board's states"
p24_add "$P24G" A2 verify
p24_brief "$P24G" A3 dev2 apply - - "none (infra) — CI runner environment and test portability"
p24_add "$P24G" A3 dev2
for _case in "A1:dev" "A2:verify" "A3:dev2"; do
  _id="${_case%%:*}"; _agent="${_case#*:}"
  p24_wt "$P24G" "$_agent" "$_id" || bad "12g $_id worktree 建不出来"
  _out="$(p24_dispatch "$P24G" "$_agent" "$_id" "docs/team/tasks/$_id-fixture.md" --print)"; _rc=$?
  assert_eq "12g $_id 合法锚 → 放行" "$_rc" "0"
  assert_has_echo "$_out" "=== 提示词" "12g $_id 打印了提示词（不是被拒）"
  assert_not_echo "$_out" "拒绝派单" "12g $_id 没有拒绝文案"
  assert_not_echo "$_out" "锚缺失" "12g $_id 没有锚警告"
done
# --force：锚缺失照派（真实落盘在成功后；headless 这里证明守卫放行且请求了窗口）
p24_wt "$P24G" dev N1
G_FORCE="$(p24_dispatch "$P24G" dev N1 docs/team/tasks/N1-fixture.md --force)"
assert_has_echo "$G_FORCE" "显式覆盖（--force）：N1 没有 change:" "12g --force 打印锚缺失覆盖警告"
assert_eq "12g --force 确实越过了守卫（走到了建窗口）" "$([ "$(p24_shim_windows)" -ge 1 ] && echo yes || echo no)" "yes"
assert_eq "12g 规则 1 没有 --force 逃生门" "$(p24_dispatch "$P24G" dev G1 docs/team/tasks/G1-fixture.md --print --force | grep -c '拒绝派单' || true)" "1"
# 3.6 [real]：没有 shim 的真实拒绝 —— 连 session 都不该被建出来
if [ "$FAST" = "1" ]; then
  fast_skip "12g·真实拒绝路径" "要真实 tmux 场地（无 shim）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  _out="$( ( cd "$P24G" && $TEAM dispatch dev G1 docs/team/tasks/G1-fixture.md ) 2>&1 )"; _rc=$?
  assert_eq "12g [real] 拒绝退出非 0" "$([ "$_rc" -ne 0 ] && echo yes || echo no)" "yes"
  if tmux has-session -t p24-12g 2>/dev/null; then bad "12g [real] 拒绝却建出了 session p24-12g"; else ok "12g [real] 拒绝没建 session（一扇窗都没有）"; fi
  _out="$( ( cd "$P24G" && $TEAM dispatch dev G1 docs/team/tasks/G1-fixture.md --print ) 2>&1 )"
  assert_not_echo "$_out" "=== 提示词" "12g [real] --print 拒绝时不打印提示词"
else
  printf '  (跳过 12g 真实拒绝路径：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 12h · delta 单写者（B4）
section "12h · delta 单写者（P24/B4）"
P24H="$(p24_project 12h)"
p24_change "$P24H" delta
p24_change "$P24H" beta
p24_change "$P24H" gamma
p24_brief "$P24H" M1 dev apply alpha panel        # 未结束的兄弟（board wip）
p24_brief "$P24H" M2 dev2 apply alpha panel       # 与 M1 共享 panel → 拒绝
p24_brief "$P24H" M3 dev apply alpha -            # 不写 delta → 放行
p24_brief "$P24H" N1 verify apply delta @absent   # deltas: 行缺失 → 读作全量
p24_brief "$P24H" N2 dev2 apply delta panel       # 与 N1 冲突 → 拒绝
p24_brief "$P24H" B1 verify apply beta panel      # 另一个 change（alpha 的兄弟不该拦它）
p24_brief "$P24H" G1 dev apply gamma panel        # 已结束的兄弟 → 不拦
p24_brief "$P24H" G2 dev2 apply gamma panel
for _id in M1 M2 M3 N1 N2 B1 G1 G2; do p24_add "$P24H" "$_id" dev; done
p24_team "$P24H" board set M1 wip >/dev/null 2>&1
p24_team "$P24H" board set N1 wip >/dev/null 2>&1
p24_pass "$P24H" G1
p24_team "$P24H" board set G1 done >/dev/null 2>&1
M1_ROW="$(p24_board_row "$P24H" M1)"
p24_wt "$P24H" dev2 M2
H_OUT="$(p24_dispatch "$P24H" dev2 M2 docs/team/tasks/M2-fixture.md)"; H_RC=$?
assert_eq "12h 同声明兄弟 → 拒绝" "$([ "$H_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$H_OUT" "拒绝派单：change alpha" "12h 拒绝来自 delta 单写者守卫"
assert_has_echo "$H_OUT" "兄弟任务：M1" "12h 拒绝点名兄弟任务"
assert_has_echo "$H_OUT" "看板 wip" "12h 拒绝带兄弟的看板状态"
assert_has_echo "$H_OUT" "共享文件：openspec/changes/alpha/specs/panel/spec.md" "12h 拒绝点名共享文件"
assert_has_echo "$H_OUT" "它的声明：deltas: panel" "12h 拒绝带兄弟的声明"
assert_has_echo "$H_OUT" "本次声明：deltas: panel" "12h 拒绝带本次声明"
assert_eq "12h 拒绝发生在开窗之前" "$(p24_shim_windows)" "0"
p24_unchanged "$P24H" M1 "$M1_ROW" "12h 派单被拒"
p24_wt "$P24H" dev M3
H_OK="$(p24_dispatch "$P24H" dev M3 docs/team/tasks/M3-fixture.md --print)"; H_OK_RC=$?
assert_eq "12h 不写 delta 的任务放行" "$H_OK_RC" "0"
assert_has_echo "$H_OK" "delta 单写者检查" "12h 放行时说明做了单写者检查"
assert_has_echo "$H_OK" "本次 deltas: -（不写 delta）" "12h 放行时说明本次声明是空集"
p24_wt "$P24H" dev2 N2
H_N="$(p24_dispatch "$P24H" dev2 N2 docs/team/tasks/N2-fixture.md)"; H_N_RC=$?
assert_eq "12h 兄弟缺 deltas 行 + 新声明 → 拒绝" "$([ "$H_N_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$H_N" "没有 deltas: 行 → 读作整个 change 的 delta 集" "12h 说明缺行被读作全量"
p24_wt "$P24H" verify B1
H_B="$(p24_dispatch "$P24H" verify B1 docs/team/tasks/B1-fixture.md --print)"; H_B_RC=$?
assert_eq "12h alpha 的未结束兄弟不会拦别的 change" "$H_B_RC" "0"
p24_wt "$P24H" dev2 G2
H_G="$(p24_dispatch "$P24H" dev2 G2 docs/team/tasks/G2-fixture.md --print)"; H_G_RC=$?
assert_eq "12h 已结束的兄弟不拦" "$H_G_RC" "0"
p24_pass "$P24H" M1
p24_team "$P24H" board set M1 done >/dev/null 2>&1
p24_wt "$P24H" dev2 M2
H_DONE="$(p24_dispatch "$P24H" dev2 M2 docs/team/tasks/M2-fixture.md --print)"; H_DONE_RC=$?
assert_eq "12h 兄弟 done（且有证据）→ 不拦" "$H_DONE_RC" "0"
p24_team "$P24H" board set M1 wip >/dev/null 2>&1
p24_brief "$P24H" M4 dev apply alpha panel        # 无证据的 alpha 兄弟（--force 用例）
p24_add "$P24H" M4 dev
H_F="$(p24_dispatch "$P24H" dev2 M2 docs/team/tasks/M2-fixture.md --force)"
assert_has_echo "$H_F" "显式覆盖（--force）：change alpha 的 delta 单写者冲突" "12h --force 打印冲突覆盖警告"
assert_has_echo "$H_F" "M4（看板 todo）与 M2 都会写 openspec/changes/alpha/specs/panel/spec.md" "12h --force 警告点名两个任务与文件"
assert_eq "12h --force 越过守卫（走到建窗口）" "$([ "$(p24_shim_windows)" -ge 1 ] && echo yes || echo no)" "yes"
assert_eq "12h --force 只写一行审计" "$(p24_dispatch "$P24H" dev2 M2 docs/team/tasks/M2-fixture.md --force | grep -c '显式覆盖（--force）' || true)" "1"
# 4.5 [real]：--force 的审计真的落进 state/watchdog.log，monitor 的事件列看得到
if [ "$FAST" = "1" ]; then
  fast_skip "12h·--force 审计落盘" "要真实 tmux 场地（真派单成功才写审计）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 5\n' "$TMP/p24-pi-args.log" > "$FAKE/pi-p24"
  chmod +x "$FAKE/pi-p24"
  printf 'TEAM_PI_BIN="%s"\n' "$FAKE/pi-p24" >> "$P24H/.pi/team/config.sh"
  p24_wt "$P24H" dev2 M2
  : > "$P24H/.pi/team/state/watchdog.log"
  H_REAL="$( ( cd "$P24H" && $TEAM dispatch dev2 M2 docs/team/tasks/M2-fixture.md --force ) 2>&1 )"; H_REAL_RC=$?
  assert_eq "12h [real] --force 派单成功" "$H_REAL_RC" "0"
  assert_eq "12h [real] 审计恰好一行" "$(grep -c 'delta 单写者' "$P24H/.pi/team/state/watchdog.log" 2>/dev/null || true)" "1"
  assert_has "$P24H/.pi/team/state/watchdog.log" "M4 与 M2 共享" "12h [real] 审计行点名两个任务与文件"
  H_MON="$( ( cd "$P24H" && $TEAM monitor --once --no-pulse --print --events 8 --width 200 ) 2>&1 )" || true
  assert_has_echo "$H_MON" "delta 单写者" "12h [real] monitor 的事件列看得到这条审计"
  tmux kill-window -t p24-12h:dev2 2>/dev/null || true
else
  printf '  (跳过 12h --force 审计落盘：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 12i · 按 change 判独立性（B5）
section "12i · 按 change 判独立性（P24/B5）"
P24I="$(p24_project 12i)"
p24_brief "$P24I" M1 dev apply alpha -
p24_brief "$P24I" V1 dev verify alpha -
p24_brief "$P24I" V2 verify verify alpha -
p24_brief "$P24I" M2 dev2 apply alpha -
{ printf '# M3 · fixture\n\n```\ntask:   M3\nagent:  -\nchange: alpha\nspecs:  -\nphase:  apply\ndeltas: -\n```\n'; } > "$P24I/docs/team/tasks/M3-fixture.md"
for _id in M1 V1 V2 M2 M3; do p24_add "$P24I" "$_id" dev; done
p24_team "$P24I" board set M1 wip >/dev/null 2>&1
p24_team "$P24I" board set M3 wip >/dev/null 2>&1
p24_wt "$P24I" dev V1
I_OUT="$(p24_dispatch "$P24I" dev V1 docs/team/tasks/V1-fixture.md)"; I_RC=$?
assert_eq "12i 作者自验 → 拒绝" "$([ "$I_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$I_OUT" "拒绝派单：verification 不独立" "12i 拒绝来自作者守卫"
assert_has_echo "$I_OUT" "verification 不独立" "12i 拒绝说明按 change 判独立性"
assert_has_echo "$I_OUT" "change：alpha ｜ agent：dev" "12i 拒绝点名 change 与 agent"
assert_has_echo "$I_OUT" "不能自己验自己" "12i 拒绝说明「不能自己验自己」"
assert_has_echo "$I_OUT" "M1" "12i 拒绝点名写过的 apply 任务"
assert_eq "12i 拒绝发生在开窗之前" "$(p24_shim_windows)" "0"
assert_eq "12i 视图同意守卫：self-verify 标记" "$(p24_team "$P24I" change status alpha | grep -c 'self-verify: dev' || true)" "1"
p24_wt "$P24I" verify V2
I_OK="$(p24_dispatch "$P24I" verify V2 docs/team/tasks/V2-fixture.md --print)"; I_OK_RC=$?
assert_eq "12i 换一个 agent → 放行" "$I_OK_RC" "0"
p24_team "$P24I" board set M1 dropped >/dev/null 2>&1
I_DROP="$(p24_dispatch "$P24I" dev V1 docs/team/tasks/V1-fixture.md --print)"; I_DROP_RC=$?
assert_eq "12i 作者任务 dropped → 放行" "$I_DROP_RC" "0"
assert_has_echo "$I_DROP" "已排除（看板 dropped）：M1" "12i dropped 的任务被点名排除"
p24_team "$P24I" change status alpha | grep -c 'self-verify: dev' >/dev/null 2>&1 && bad "12i dropped 后视图还标 self-verify" || ok "12i dropped 后视图不再标 self-verify"
I_MISS="$(p24_dispatch "$P24I" dev V1 docs/team/tasks/V1-fixture.md --print)"; I_MISS_RC=$?
assert_eq "12i 作者信号缺失（无 agent:）→ 放行" "$I_MISS_RC" "0"
assert_has_echo "$I_MISS" "作者信号缺失" "12i 缺信号很吵（不冒充干净）"
p24_team "$P24I" board set M1 wip >/dev/null 2>&1
p24_wt "$P24I" dev V1
I_FORCE="$(p24_dispatch "$P24I" dev V1 docs/team/tasks/V1-fixture.md --force)"
assert_has_echo "$I_FORCE" "显式覆盖（--force）：verification 不再独立" "12i --force 打印自验覆盖警告"
assert_has_echo "$I_FORCE" "verification 不再独立" "12i --force 仍说清损失（verification 不再独立）"
assert_eq "12i --force 越过守卫" "$([ "$(p24_shim_windows)" -ge 1 ] && echo yes || echo no)" "yes"

# ---------------------------------------------------------------- 12j · 归档前提（B6）
section "12j · 归档前提（P24/B6）"
P24J="$(p24_project 12j)"
mkdir -p "$P24J/openspec/changes/archive/2026-09-20-alpha"
p24_brief "$P24J" A1 pm archive alpha -
p24_brief "$P24J" M1 dev apply alpha -
p24_brief "$P24J" C1 pm archive - -
p24_add "$P24J" A1 pm; p24_add "$P24J" M1 dev; p24_add "$P24J" C1 pm
p24_team "$P24J" board set M1 wip >/dev/null 2>&1
A1_ROW="$(p24_board_row "$P24J" A1)"
J_OUT="$(p24_team "$P24J" board set A1 done)"; J_RC=$?
assert_eq "12j 未结束兄弟 → done 被拒" "$([ "$J_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$J_OUT" "M1" "12j 拒绝点名未结束的兄弟"
assert_has_echo "$J_OUT" "看板状态 wip" "12j 拒绝带兄弟的看板状态"
assert_has_echo "$J_OUT" "还没就绪" "12j 拒绝说明归档前提是整个 change"
p24_unchanged "$P24J" A1 "$A1_ROW" "12j 归档任务 done 被拒"
# 同一份判据：视图与闸门点名同一个 blocker
J_VIEW="$(p24_team "$P24J" change status alpha)"; J_VIEW_RC=$?
assert_eq "12j 视图未就绪（退出 1）" "$J_VIEW_RC" "1"
assert_has_echo "$J_VIEW" "M1 · apply · wip ·" "12j 视图与闸门点同一个 blocker"
# 兄弟拿到证据 → 归档闸门放行 → 视图跟着 ready
p24_pass "$P24J" M1
p24_team "$P24J" board set M1 done >/dev/null 2>&1
J_OK="$(p24_team "$P24J" board set A1 done)"; J_OK_RC=$?
assert_eq "12j 兄弟结束后归档任务可以 done" "$J_OK_RC" "0"
assert_file "$P24J/docs/team/reviews/A1-done.md" "12j done 证据落盘"
assert_has "$P24J/docs/team/reviews/A1-done.md" "归档目录" "12j 证据行就是归档目录那条"
p24_team "$P24J" change status alpha >/dev/null 2>&1 && J_READY_RC=0 || J_READY_RC=$?
assert_eq "12j 归档任务 done 后视图翻 ready" "$J_READY_RC" "0"
# 显式覆盖仍然工作（FORCED + 理由 + 审计）：先抽掉 M1 的证据，让它真的「未结束」
p24_team "$P24J" board set M1 wip >/dev/null 2>&1
rm -f "$P24J/docs/team/reviews/M1.md"
p24_team "$P24J" board set A1 todo >/dev/null 2>&1
J_FORCED="$(cd "$P24J" && env TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON="sibling accepted by the user" $TEAM board set A1 done 2>&1)"; J_FORCED_RC=$?
assert_eq "12j 覆盖 → 成功" "$J_FORCED_RC" "0"
assert_has_echo "$J_FORCED" "FORCED" "12j 覆盖记录 FORCED"
J_DONE_REC="$(head -c 4000 "$P24J/docs/team/reviews/A1-done.md" 2>/dev/null || true)"
assert_has_echo "$J_DONE_REC" "理由：sibling accepted by the user" "12j 覆盖理由落进审计"
# change-less 的归档任务：旧行为逐字不变（还是那句「没有 change: 行」）
C1_OUT="$(p24_team "$P24J" board set C1 done)"; C1_RC=$?
assert_eq "12j change: - 的归档任务行为不变" "$([ "$C1_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$C1_OUT" "任务书没有 change: 行" "12j change: - 走旧的拒绝文案"
assert_not_echo "$C1_OUT" "还没就绪" "12j change: - 不会被新判据接管"

# ---------------------------------------------------------------- 12k · 模板与文档（B7）
section "12k · 模板与文档（P24/B7）"
P24K="$(p24_project 12k)"
p24_team "$P24K" task T9.9 --title "probe" --agent dev >/dev/null 2>&1
TK="$P24K/docs/team/tasks/T9.9-probe.md"
assert_file "$TK" "12k 模板渲染出任务书"
for _k in change specs anchor phase deltas; do
  assert_match "$TK" "^$_k:" "12k 模板含 $_k: 行"
done
# 严格读取器接受渲染出的 `-` 占位值；锚行是待填空（change-less 时规则 B 会要求它）
K_CHG="$(p24_read "$P24K" team_task_change_value "$TK")"; K_CHG_RC=$?
assert_eq "12k change: - 读成「无 change」" "$([ "$K_CHG_RC" -eq 0 ] && printf '%s' "$K_CHG" || printf 'rc=%s' "$K_CHG_RC")" "-"
K_DEL="$(p24_read "$P24K" team_task_deltas "$TK")"; K_DEL_RC=$?
assert_eq "12k deltas: - 可读（rc 0）" "$K_DEL_RC" "0"
assert_eq "12k deltas: - 读成空集" "$K_DEL" ""
K_ANC="$(p24_read "$P24K" team_task_anchor "$TK")"; K_ANC_RC=$?
assert_eq "12k anchor: - 是待填空（规则 B 会拒绝）" "$([ "$K_ANC_RC" -ne 0 ] && echo yes || echo no)" "yes"
assert_has_echo "$K_ANC" "specs: <capability>#<requirement>" "12k 拒绝时给出两种接受形式"
sed -i 's|^anchor: -.*$|anchor: none (infra) — CI runner environment and test portability|' "$TK"
K_ANC2="$(p24_read "$P24K" team_task_anchor "$TK")"; K_ANC2_RC=$?
assert_eq "12k 填了 infra 锚 → 接受" "$K_ANC2_RC" "0"
assert_has_echo "$K_ANC2" "CI runner environment and test portability" "12k infra 理由原样读出"
sed -i 's|^change: -.*$|change: alpha|' "$TK"
assert_eq "12k 填了 change → 读出 id" "$(p24_read "$P24K" team_task_change_value "$TK")" "alpha"
# 7.2 文档：清单加点 9/10、归档行带 readiness 命令、原八点不动
OPENSPEC_MD="$SKILL_DIR/references/openspec.md"
assert_has "$OPENSPEC_MD" "One change per task" "7.2 checklist gains point 9"
assert_has "$OPENSPEC_MD" "The anchor exists" "7.2 checklist gains point 10"
assert_has "$OPENSPEC_MD" "team change status" "7.2 archive row carries the readiness command"
assert_has "$OPENSPEC_MD" "1. **Matches the approved exploration**" "7.2 existing point 1 unchanged"
assert_has "$OPENSPEC_MD" "8. **Granularity**" "7.2 existing point 8 unchanged"
assert_eq "7.2 checklist now has exactly ten points" "$(grep -cE '^[0-9]+\. \*\*' "$OPENSPEC_MD" || true)" "10"
assert_has "$OPENSPEC_MD" "1 change : N tasks" "7.2 §2 states the model"
# 7.3 help / SKILL / protocol：四条拒绝类
assert_has_echo "$($TEAM help 2>&1)" "change status" "7.3 team help lists change status"
assert_has "$SKILL_DIR/SKILL.md" "team change status <id> [--json]" "7.3 SKILL command table carries it"
for _frag in "One change id" "declares its anchor" "One delta file, one writer" "The verifier is not an author"; do
  assert_has "$SKILL_DIR/references/protocol.md" "$_frag" "7.3 protocol names the refusal class: $_frag"
done
assert_has "$SKILL_DIR/references/protocol.md" "self-verify: <agent>" "7.3 protocol names the self-verify mark"
# 7.4 渲染出的 AGENTS/PROTOCOL 含新段；仓库 AGENTS.md 与模板逐字一致（模板是源）
assert_has "$P24K/AGENTS.md" "The change is the assignment unit" "7.4 rendered AGENTS carries the paragraph"
assert_has "$P24K/docs/team/PROTOCOL.md" "The change is the assignment unit" "7.4 rendered PROTOCOL carries it"
_para_tmpl="$(awk '/\*\*The change is the assignment unit\*\*/,/while a sibling is unfinished\./' "$SKILL_DIR/templates/AGENTS.section.md.tmpl")"
_para_repo="$(awk '/\*\*The change is the assignment unit\*\*/,/while a sibling is unfinished\./' "$SKILL_DIR/../../AGENTS.md")"
assert_eq "7.4 repo AGENTS.md 与模板逐字一致（模板是源）" "$_para_repo" "$_para_tmpl"
assert_has "$SKILL_DIR/templates/PROTOCOL.md.tmpl" "The change is the assignment unit" "7.4 PROTOCOL 模板也带这段"

section "34 · 门禁锁：排队/运行分开记账（P26/G1：verification#The hard timeout covers the gate run, not the queue）"
# 事故（M49，2026-09-20）：`team review` 的硬超时把**排队**也算进去了 —— 门禁命令自己在机器锁上排了
# 930s、跑了 870s，就被记成 TIMEOUT，而同一个 HEAD 在机器安静后是 PASS 的。本段钉住修复后的形状：
#   ① 排队不消耗运行预算（排队 + 运行 > 上限 仍判 PASS）；② 排队超上限 = FAIL 并点名持锁者（不是 TIMEOUT）；
#   ③ 真跑超限仍是 TIMEOUT 且带 ran=Ns；④ 祖先持锁不再二次排队；⑤ 没有 flock 就打印降级；
#   ⑥ 三种结局下 `team_review_verdict` 仍解析出正确的 token（记录词汇是闭集，且记账写在粗体 token 之外）。
# 安全：本段所有的锁都是**私有路径**（$TMP/p34-lock）—— 绝不碰机器锁 ${TMPDIR:-/tmp}/teamsmith-smoke.lock；
# 持锁助手随方案退出即释放；身份隔离（-u TEAM_*/SMOKE_*）与 §27 的夹具同形。
P34D="$TMP/p34"; P34R="$P34D/repo"; P34_LOCK="$P34D/lock"; P34_SHIM="$P34D/shim"
P34_TMUX_LOG="$P34D/tmux-calls.log"; P34_HOLDER=""; : > "$P34_TMUX_LOG"
rm -rf "$P34D"; mkdir -p "$P34R" "$P34_SHIM"
( cd "$P34R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
  && echo "# p34" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
p34() { ( cd "$P34R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
            -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_STATE_DIR -u TEAM_DOCS_DIR -u TEAM_CONFIG_FILE \
            -u TEAM_GATES -u TEAM_VCS -u TEAM_WORKTREES_DIR -u TEAM_SKILL_DIR -u TEAM_ALLOW_FOREIGN_IDENTITY \
            "$@" ); }
p34 $TEAM init --session "smoke-p34-$$" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$P34D/init.log" 2>&1 \
  && ok "34 夹具：沙盒 init 退出码 0" || { bad "34 夹具：init 失败"; tail -3 "$P34D/init.log"; }
mkdir -p "$P34R/docs/team/reports" "$P34R/docs/team/reviews"
printf '# T1.1 · 夹具报告\n\nagent: dev\n' > "$P34R/docs/team/reports/T1.1-dev.md"
# 持锁助手：flock -x 持住私有锁，随方案退出即释放；同时写 <lock>.holder（review 读它点名持锁者）。
p34_hold() { # <秒>
  : >>"$P34_LOCK"; rm -f "$P34_LOCK.holder"
  flock -x "$P34_LOCK" sleep "$1" &
  P34_HOLDER=$!
  sleep 0.4
  printf '%s pid=%s cmd=p34-holder\n' "$(date -Is)" "$P34_HOLDER" > "$P34_LOCK.holder"
}
p34_release() { [ -n "$P34_HOLDER" ] && { kill "$P34_HOLDER" 2>/dev/null; wait "$P34_HOLDER" 2>/dev/null; }; P34_HOLDER=""; }
# 身份干净 + 私有锁 + 沙盒脏树覆盖（夹具仓的 docs/team 本来就是 init 出来的未提交内容）
p34_review() { # <out> <timeout> <lock_wait> <gates> [extra env assignments…]
  local out="$1" tlim="$2" cap="$3" gates="$4"; shift 4
  ( cd "$P34R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
      -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_STATE_DIR -u TEAM_DOCS_DIR -u TEAM_CONFIG_FILE \
      -u TEAM_GATES -u TEAM_VCS -u TEAM_WORKTREES_DIR -u TEAM_SKILL_DIR -u TEAM_ALLOW_FOREIGN_IDENTITY \
      -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED \
      TEAM_SMOKE_LOCK="$P34_LOCK" TEAM_SMOKE_LOCK_WAIT="$cap" TEAM_GATES="$gates" \
      TEAM_REVIEW_TIMEOUT="$tlim" TEAM_REVIEW_ALLOW_DIRTY=1 TEAM_REVIEW_ALLOW_IGNORED=1 "$@" \
      $TEAM review T1.1 --dir "$P34R" --branch main ) >"$out" 2>&1
}
p34_record() { printf '%s' "$P34R/docs/team/reviews/T1.1.md"; }
p34_verdict() { # 用 CLI 自己的解析器（common.sh 的 team_review_verdict），不是本段自己写正则
  ( cd "$P34R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      TEAM_DOCS_ABS="$P34R/docs/team" bash -c "source '$SKILL_DIR/scripts/lib/common.sh' >/dev/null 2>&1; team_review_verdict T1.1" ) 2>/dev/null
}
p34_field() { sed -n "s/$1/\\1/p" "$(p34_record)" 2>/dev/null | head -1; }

# ① 长排队不消耗运行预算（M49 的形状：**门禁命令自己也会去排队** —— 真实门禁命令里 smoke.sh 就是
#    这样，它会认 SMOKE_LOCK_WRAPPED 这个「祖先已持有」的标记；夹具门禁照抄这个契约）
p34_hold 7
P34_RC=0; p34_review "$P34D/a.log" 5 60 '[ "${SMOKE_LOCK_WRAPPED:-0}" = "1" ] || flock -w 60 "$TEAM_SMOKE_LOCK" true; sleep 3' || P34_RC=$?
p34_release
P34_Q="$(p34_field '.*queued=\([0-9]*\)s.*')"; P34_R="$(p34_field '.*ran=\([0-9]*\)s.*')"
assert_eq "34① 排队 + 运行 > 上限 仍判 PASS（rc）" "$P34_RC" "0"
if [ -n "$P34_Q" ] && [ -n "$P34_R" ] && [ "$((P34_Q + P34_R))" -gt 5 ]; then
  ok "34① 排队不计入硬超时：queued ${P34_Q}s + ran ${P34_R}s > limit 5s，判定仍 PASS"
else
  bad "34① 记账不对（queued=${P34_Q:-无} ran=${P34_R:-无}）—— 记录：$(p34_field '闸门计时.*')"
fi
[ "${P34_R:-0}" -ge 2 ] && [ "${P34_R:-0}" -le 5 ] && ok "34① ran 是门禁实际运行秒数（${P34_R}s，3s 门禁 + 启动）" \
  || bad "34① ran 不对（${P34_R:-无}s）"
# 门禁没有在锁上白等：它自己也知道锁已被祖先持有（否则就是自己和自己排队 → M49 的 TIMEOUT）
grep -aq 'SMOKE_LOCK_WRAPPED' "$P34D/a.log" && ok "34① review 把 wrapped 标记交给了门禁（子套件不再二次排队）" \
  || bad "34① 门禁没有收到 wrapped 标记（嵌套时会自锁）"
assert_has "$(p34_record)" "limit=5s queued=" "34① 记录带机器可读的三个区间"
assert_eq "34① team_review_verdict 仍解析出 PASS" "$(p34_verdict)" "PASS"

# ② 排队超上限：FAIL + 点名持锁者 + 「门禁没有运行」（不是 TIMEOUT）
p34_hold 20
P34_RC=0; p34_review "$P34D/b.log" 30 2 'sleep 1' || P34_RC=$?
p34_release
assert_eq "34② 排队超上限 → 非 0" "$P34_RC" "1"
assert_has "$(p34_record)" '判定: **FAIL**' "34② 判定是 FAIL"
assert_has "$(p34_record)" '门禁没有运行' "34② 记录写明门禁没有运行"
assert_has "$(p34_record)" 'cmd=p34-holder' "34② 记录点名持锁者（夹具的 holder 记录）"
assert_eq "34② 排队超限不产生 TIMEOUT 判定" "$(grep -c '判定: \*\*TIMEOUT\*\*' "$(p34_record)" || true)" "0"
assert_eq "34② team_review_verdict 仍解析出 FAIL" "$(p34_verdict)" "FAIL"

# ③ 真跑超限仍是 TIMEOUT（语义不变）+ ran 记账
P34_RC=0; p34_review "$P34D/c.log" 2 60 'sleep 60' || P34_RC=$?
assert_eq "34③ 真跑超上限 → 非 0" "$P34_RC" "1"
assert_has "$(p34_record)" '判定: **TIMEOUT**' "34③ 判定是 TIMEOUT（语义不变）"
assert_match "$(p34_record)" 'ran=[0-9]+s' "34③ TIMEOUT 记录带 ran=Ns"
assert_eq "34③ team_review_verdict 仍解析出 TIMEOUT" "$(p34_verdict)" "TIMEOUT"

# ④ 祖先已持锁：不再二次排队（queued=0s，且不等满）
p34_hold 10
P34_T0=$(date +%s)
P34_RC=0; p34_review "$P34D/d.log" 20 60 'sleep 1' SMOKE_LOCK_WRAPPED=1 || P34_RC=$?
P34_T1=$(date +%s)
p34_release
assert_eq "34④ 祖先持锁 → rc=0" "$P34_RC" "0"
assert_has "$(p34_record)" '已由祖先持有' "34④ 记录写明已由祖先持有（不二次排队）"
assert_eq "34④ 不排队：锁被占的 10s 内就返回（实测 $((P34_T1 - P34_T0))s）" "$([ $((P34_T1 - P34_T0)) -lt 8 ] && echo yes || echo no)" "yes"
assert_eq "34④ team_review_verdict 仍解析出 PASS" "$(p34_verdict)" "PASS"

# ⑤ 没有 flock：打印降级（不是静默）+ 照跑门禁
P34_NOFL="$P34D/noflock"; rm -rf "$P34_NOFL"; mkdir -p "$P34_NOFL"
while IFS= read -r p34t; do
  [ "$p34t" = "flock" ] && continue
  p34p="$(command -v "$p34t" 2>/dev/null)" || continue
  [ -n "$p34p" ] && ln -sf "$p34p" "$P34_NOFL/$p34t" 2>/dev/null || true
done < <(compgen -c 2>/dev/null | sort -u)
if [ ! -x "$P34_NOFL/bash" ] || [ -e "$P34_NOFL/flock" ]; then
  bad "34⑤ 无 flock 夹具没搭好（bash=$([ -x "$P34_NOFL/bash" ] && echo yes || echo no) flock=$([ -e "$P34_NOFL/flock" ] && echo yes || echo no)）"
else
  P34_RC=0; p34_review "$P34D/e.log" 30 60 'sleep 1' PATH="$P34_NOFL" || P34_RC=$?
  assert_eq "34⑤ 没有 flock 也照跑（rc=0，不是静默跳过）" "$P34_RC" "0"
  assert_match "$P34D/e.log" '门禁排队未启用' "34⑤ 打印了「排队未启用」的降级说明"
  assert_has "$(p34_record)" '排队未启用' "34⑤ 记录里也写明排队未启用"
fi

# ⑥ 排队阶段不碰 tmux、不改看板（用 shim 证明：真调用会被记下且失败）
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s"\nexit 1\n' "$P34_TMUX_LOG" > "$P34_SHIM/tmux"; chmod +x "$P34_SHIM/tmux"
P34_BOARD_BEFORE="$(md5sum "$P34R/docs/team/BOARD.md" 2>/dev/null | cut -d' ' -f1)"
p34_hold 4
P34_RC=0; p34_review "$P34D/f.log" 20 60 'sleep 1' PATH="$P34_SHIM:$PATH" || P34_RC=$?
p34_release
assert_eq "34⑥ tmux 被 shim 顶掉也照样跑通（rc=0）" "$P34_RC" "0"
assert_eq "34⑥ 排队阶段一次 tmux 都没调（shim 日志为空）" "$(grep -c . "$P34_TMUX_LOG" 2>/dev/null || printf 0)" "0"
assert_eq "34⑥ 看板一个字节没动" "$(md5sum "$P34R/docs/team/BOARD.md" 2>/dev/null | cut -d' ' -f1)" "$P34_BOARD_BEFORE"
p34_release

section "34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66）"
# 事故（2026-09-22 PM 归档前门禁实测）：排队路径原来是 `exec flock --close -w … bash smoke.sh` ——
# `flock -w` 超时只返回 1，而 `exec` 之后那行永远执行不到 → **静默 exit 1、一句点名的话都没有**，
# 与「排队超上限大声失败（exit 2）」的承诺正相反（看日志的人只会以为门禁自己红了）。
# 本段钉住修复后的形状（四条 + 一条 premise；只碰私有锁与私有临时目录，绝不碰机器锁）：
#   ① 红侧（锁被持有 + WAIT=1）→ 一行点名 `<lock>.holder` 里的持有者 + 等了多少秒 + **exit 2**
#      （不是 1、不静默），而且子套件一次都没跑（holder 还是持锁者的、输出里没有段落头）；
#   ② 绿侧（空闲锁）→ 真的轮到本套：子进程跑起来、holder 换成自己、退出码原样透传；
#   ③ 有竞争但排到了 → 既有行为照旧（排队行 + 「轮到本套了（排过队）」）；
#   ④ 反例：子进程自己 exit 1（真红的门禁）绝不能被报成排队超限 —— 这就是 marker 存在的理由；
#   ⑤ premise：旧形状（`exec flock -w`）超限 = rc 1 + 零输出（所以只看返回码不可能区分两者）。
# 内层 smoke 是**真入口**（同一条排队守卫），但用 SMOKE_LOCK_SELFTEST_CHILD 在拿到锁后立刻退出：
# 本段绝不递归跑整套门禁。身份清洗与 §34 同形。
P66D="$TMP/p66"; P66_LOCK="$P66D/lock"; P66_RSH=""
rm -rf "$P66D"; mkdir -p "$P66D"
# 持锁助手：`--close` 让**只有** flock 持有 fd —— kill 掉它就立刻释放（§34 那版不带 --close，
# 被 kill 的 flock 的子进程还捏着 fd，锁要到 sleep 自己走完才放，夹具会白等）。
p66_hold() { # <秒>
  : >>"$P66_LOCK"
  flock --close -x "$P66_LOCK" sleep "$1" & P66_RSH=$!
  sleep 0.4
  printf '%s pid=%s cmd=p66-holder\n' "$(date -Is)" "$P66_RSH" > "$P66_LOCK.holder"
}
p66_release() { [ -n "$P66_RSH" ] && { kill "$P66_RSH" 2>/dev/null; wait "$P66_RSH" 2>/dev/null; }; P66_RSH=""; }
p66_run() { # <out> <wait> <child-rc>：真入口 + 私有锁 / 私有 TMPDIR（marker 也不落 /tmp）
  local out="$1" w="$2" crc="$3"
  ( cd "$TMP" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
      -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_STATE_DIR -u TEAM_DOCS_DIR -u TEAM_CONFIG_FILE \
      -u TEAM_GATES -u TEAM_VCS -u TEAM_WORKTREES_DIR -u TEAM_SKILL_DIR -u TEAM_ALLOW_FOREIGN_IDENTITY \
      -u TEAM_SMOKE_FAST -u TEAM_SMOKE_NO_LOCK -u TEAM_SMOKE_LOCK -u TEAM_SMOKE_LOCK_WAIT \
      -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED -u SMOKE_LOCK_SELFTEST_CHILD \
      TEAM_SMOKE_LOCK="$P66_LOCK" TEAM_SMOKE_LOCK_WAIT="$w" TMPDIR="$P66D" \
      TEAM_SMOKE_FIXTURE=1 SMOKE_LOCK_SELFTEST_CHILD="$crc" \
      bash "$SKILL_DIR/tests/smoke.sh" ) >"$out" 2>&1
}

# ① 红侧：锁被持有 + WAIT=1 → 点名持锁者 + exit 2 + 子套件没跑
p66_hold 20
P66_RC=0; p66_run "$P66D/red.log" 1 0 || P66_RC=$?
P66_HOLDER_FP="$(md5sum "$P66_LOCK.holder" 2>/dev/null | cut -d' ' -f1)"
p66_release
assert_eq "34b① 排队超上限 → exit 2（约定的那个：不是 1，也不是静默）" "$P66_RC" "2"
assert_match "$P66D/red.log" '排队超限：等满 [0-9]+s' "34b① 一行说明是排队超限，并报出等了多久"
assert_match "$P66D/red.log" "排队超限.*cmd=p66-holder" "34b① 那一行点名 <lock>.holder 里的持有者"
assert_has "$P66D/red.log" "没有运行" "34b① 那一行说明本套没有运行（不是对代码的判定）"
assert_has "$P66D/red.log" "另一套全量 smoke 正在跑" "34b①（既有行为）排队前也打印持有者"
assert_not "$P66D/red.log" "0 · 临时仓库" "34b① 子套件一次都没跑（输出里没有段落头）"
assert_not "$P66D/red.log" "轮到本套了" "34b① 也没有「轮到本套了（排过队）」"
assert_eq "34b① holder 还写着持锁者（子进程没跑，没被改写）" \
  "$(md5sum "$P66_LOCK.holder" 2>/dev/null | cut -d' ' -f1)" "$P66_HOLDER_FP"

# ② 绿侧：空闲锁 → 照常轮到本套（子进程真的跑起来，退出码原样透传）
rm -f "$P66_LOCK.holder"
P66_RC=0; p66_run "$P66D/green.log" 5 0 || P66_RC=$?
assert_eq "34b② 无竞争 → 子进程的退出码原样透传（0）" "$P66_RC" "0"
assert_has "$P66D/green.log" "自检出口" "34b② 子进程真的作为队列子进程跑起来了"
assert_has "$P66_LOCK.holder" "cmd=smoke.sh" "34b② 它把 holder 写成了自己（真的拿到了锁）"
assert_not "$P66D/green.log" "排队超限" "34b② 无竞争时没有排队失败的噪音"
assert_not "$P66D/green.log" "另一套全量 smoke 正在跑" "34b② 空闲锁不进排队路径"

# ③ 有竞争但排到了：既有行为照旧（排队行 + 「轮到本套了（排过队）」）
rm -f "$P66_LOCK.holder"
p66_hold 2
P66_RC=0; p66_run "$P66D/queued.log" 20 0 || P66_RC=$?
p66_release
assert_eq "34b③ 排到了 → 子进程的退出码（0）" "$P66_RC" "0"
assert_has "$P66D/queued.log" "另一套全量 smoke 正在跑" "34b③ 排队时打印持有者"
assert_has "$P66D/queued.log" "轮到本套了（排过队）" "34b③ 轮到时照旧打印「轮到本套了（排过队）」"
assert_not "$P66D/queued.log" "排队超限" "34b③ 排到了就不是超限"
assert_has "$P66_LOCK.holder" "cmd=smoke.sh" "34b③ 拿到锁后 holder 换成自己"

# ④ 反例：子进程自己 exit 1（真红的门禁）→ 原样透传，不许报成排队超限
rm -f "$P66_LOCK.holder"
P66_RC=0; p66_run "$P66D/redgate.log" 10 1 || P66_RC=$?
assert_eq "34b④ 子进程自己的 exit 1 → 原样透传（不被当成排队超限）" "$P66_RC" "1"
assert_not "$P66D/redgate.log" "排队超限" "34b④ 真红不误报为排队超限"
assert_not "$P66D/redgate.log" "排队/加锁失败" "34b④ 也不是加锁失败"
assert_has "$P66D/redgate.log" "自检出口" "34b④ 子进程确实跑到了（marker 有内容）"

# ⑤ premise：旧形状超限 = rc 1 + 零输出（修复前现场的真实形状）
p66_hold 5
( exec flock --close -w 1 "$P66_LOCK" bash -c 'printf legacy-ran' ) >"$P66D/legacy.log" 2>&1; P66_LEGACY_RC=$?
p66_release
assert_eq "34b⑤ premise：旧形状超限 → rc 1（只看返回码无法区分排队与真红）" "$P66_LEGACY_RC" "1"
assert_eq "34b⑤ premise：旧形状超限时一个字都不打印（现场就是这样静默的）" \
  "$(wc -c < "$P66D/legacy.log" | tr -d ' ')" "0"

# ⑥ 队列 marker 不许在这台机器上留下残留
assert_eq "34b⑥ 队列 marker 没有残留" \
  "$(find "$P66D" -maxdepth 1 -name 'teamsmith-smoke-queue.*' 2>/dev/null | wc -l | tr -d ' ')" "0"
rm -f "$P66_LOCK.holder" 2>/dev/null || true

section "35 · 门禁只判正确性：性能判定守卫 + 旋钮完整性（M58 · perf-suite-split）"
# 用户决定 D33：性能判定与正确性门禁分开（规格：openspec/changes/perf-suite-split）。本段是**纯逻辑**，
# FAST 与全量都跑，不起 tmux / node / 任何测量：
#   ① 双向机械守卫（tests/gate-guard.sh）：门禁本体里不得残留任何性能判定标记（帧预算/份额常量、旧判定
#      函数、注入旋钮、时长比较）或测量夹具的点名；性能套件必须带着那组命名单源标记（「偷懒式搬迁」：
#      从门禁删了但没落地 → 红）；旋钮完整性助手必须在岗且走 premise-only 模式。
#   ② 旋钮完整性（tests/panel-knobs.sh，时间无关的 d-realpath）：三个面板旋钮在夹具开关关着时被忽略
#      并打印，premise 行只反映真读数；不判任何时长。
# 翻转（apply 报告里真跑过）：把判定塞回本文件 → 守卫红；从性能套件移除标记 → 守卫红；还原 → 绿。
if [ -f "$SKILL_DIR/tests/gate-guard.sh" ]; then
  if bash "$SKILL_DIR/tests/gate-guard.sh" >"$TMP/p35-guard.log" 2>&1; then
    ok "35 守卫：门禁无性能判定标记、无测量夹具点名；旋钮助手与性能套件标记两侧都在"
  else
    bad "35 守卫：$(sed -n 's/^bad: //p' "$TMP/p35-guard.log" | head -1)"
    sed -n 's/^bad: /      /p' "$TMP/p35-guard.log" | head -6
  fi
else
  bad "35 守卫：缺 tests/gate-guard.sh（门禁的性能判定守卫没了）"
fi
if [ -f "$SKILL_DIR/tests/panel-knobs.sh" ]; then
  if bash "$SKILL_DIR/tests/panel-knobs.sh" >"$TMP/p35-knobs.log" 2>&1; then
    ok "35 旋钮完整性（时间无关）：$(sed -n 's/^== 结果 == //p' "$TMP/p35-knobs.log" | tail -1)"
  else
    bad "35 旋钮完整性：$(sed -n 's/^== 结果 == //p' "$TMP/p35-knobs.log" | tail -1)"
    grep -a '✗' "$TMP/p35-knobs.log" | head -4 | sed 's/^/      /'
  fi
else
  bad "35 旋钮完整性：缺 tests/panel-knobs.sh（旋钮不得漏进真路径的检查没了）"
fi
# ---------------------------------------------------------------- 36. 选段与分段账本自检（P98 · gate-runtime-budget）
# 纯逻辑（不起 tmux / 不跑真进程），FAST 与全量都跑。钉四件事：
#   ① `section-select.sh --check` 绿；四种腐烂（缺行 / 模式变窄 / 未知 needs / 声明豁免类）都红且点名；
#   ② 三个决定形状（NONE / RUN / FULL）与两种硬错误（未知 key / 路径出界）逐条对照验收表；
#   ③ 账本：嵌套跑一次小选段，核对「跑了的段数 == 选择器给的 key 数 + 每段一条收口行 + 增量之和 == 结果行
#      总数 + 最慢段汇总」；用一棵注入 sleep 的变体树证明「慢段照旧绿、秒数真实」；
#   ④ 选段运行自述 + 「选段只对跑了的段负责」：注入一条必红断言到未选中的段不影响退出码，选中它非 0。
# 全套自检（14c 的跳过清单）在选段模式下会显式跳过，见那里的说明。
section "36 · 选段与分段账本自检（P98 · gate-runtime-budget）"
SEL36="$SKILL_DIR/tests/section-select.sh"
P98_NEST_TMP="$TMP/p98-nest-tmp"; rm -rf "$P98_NEST_TMP"; mkdir -p "$P98_NEST_TMP"
# 嵌套跑门禁：私有 TMPDIR / 清掉继承身份 / FAST / 不排队（不起真进程，本段全程纯逻辑）
p98_nest() { # <树> <日志> <参数…>；额外 env 由调用方放在 P98_NEST_ENV 里
  # P115：P98_NEST_TMPDIR 可覆盖嵌套 run 的 TMPDIR（两向夹具把 socket 路径压深/保持浅用）
  local tree="$1" log="$2" extra="${P98_NEST_ENV:-}" nest_tmp="${P98_NEST_TMPDIR:-$P98_NEST_TMP}"; shift 2
  env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_AGENT_MODEL \
      -u SMOKE_TMP_RUN_ID -u SMOKE_TMP_LEDGER -u TEAM_SMOKE_KEEP -u TEAM_TMP_KEEP \
      -u SMOKE_SEL_CHILD -u SMOKE_SEL_SKILL_DIR -u SMOKE_SEL_DECISION -u SMOKE_SEL_COPY \
      TMPDIR="$nest_tmp" TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 $extra \
      bash "$tree/tests/smoke.sh" "$@" >"$log" 2>&1
}
# P115 · 嵌套跑的判定看**状态**，不看墙钟：rc 非零时不问「它该跑完了吗」，而是读子进程留下的日志
# ——红的是哪一行、能不能归因到**环境前置**。现场（P111 的 FAST ✓2996 ✗5，5 条全在 §36）：调用者
# 的 TMPDIR 深 → 嵌套 run 自己的私有 tmux socket 路径 116–119 字节 > AF_UNIX 上限 107（bind 实测
# 107 OK / 108 ENAMETOOLONG）→ tmux server 绑不上 socket → 0c 的隔离自检报「私有 socket 没生效」
# → 嵌套 rc=1，五条「嵌套跑退出 0」全假红（选段器一点问题都没有）。判定分三类：
#   green  rc=0；
#   env    rc≠0 但日志里**全部**红行都是可归因的环境前置（私有 socket 绑不上），或一条红行都没有的
#          锁排队（exit 2，点名 holder）→ 可见 SKIP + 归因（不判产品红）；
#   red    其它任何形状（有非环境红行；或 rc≠0 却没有任何可归因的红行）→ 照旧红（真红保留）。
p98_nest_state() { # <日志> <rc> → 打印 "<green|env|red>\t<归因或证据（一行）>"
  local log="$1" rc="$2" plain reds nr env_reds ne first
  plain="$(sed 's/\x1b\[[0-9;]*m//g' "$log" 2>/dev/null || true)"
  if [ "$rc" = "0" ]; then printf 'green\t退出码 0\n'; return 0; fi
  reds="$(printf '%s\n' "$plain" | grep '^  ✗ ' || true)"
  if [ -n "$reds" ]; then
    nr="$(printf '%s\n' "$reds" | grep -c . || true)"
    env_reds="$(printf '%s\n' "$reds" | grep -E '私有 socket 没生效' || true)"
    ne=0; [ -n "$env_reds" ] && ne="$(printf '%s\n' "$env_reds" | grep -c . || true)"
    if [ "$ne" -gt 0 ] && [ "$ne" -eq "$nr" ]; then
      first="$(printf '%s\n' "$env_reds" | head -1 | sed 's/^  ✗ //' | cut -c1-220)"
      printf 'env\t%s\n' "$first"; return 0
    fi
    first="$(printf '%s\n' "$reds" | grep -v -E '私有 socket 没生效' | head -1 | sed 's/^  ✗ //' | cut -c1-200)"
    printf 'red\t%s\n' "$first"; return 0
  fi
  # 一条 ✗ 都没有：锁排队（exit 2）点名 holder 的是**环境**；其它形状没有可归因的红 → 照旧红。
  if printf '%s\n' "$plain" | grep -q '^排队超限：'; then
    first="$(printf '%s\n' "$plain" | grep -m1 '^排队超限：' | cut -c1-220)"
    printf 'env\t%s\n' "$first"; return 0
  fi
  printf 'red\trc=%s 但日志里一条 ✗ 行都没有（没有环境前置可以解释它）\n' "$rc"; return 0
}
p98_nest_sock_len() { # <日志> → 嵌套 run 私有 socket 路径的字节数（取日志里那行；缺则空）
  local p
  p="$(sed 's/\x1b\[[0-9;]*m//g' "$1" 2>/dev/null \
       | sed -n 's/^  · tmux 私有 socket：\(.*\)（夹具与产品调用都走它.*$/\1/p' | head -1)"
  [ -n "$p" ] && printf '%s' "$p" | wc -c | tr -d ' ' || true
}
p98_nest_verdict() { # <期望 0 的断言标题> <rc> <嵌套日志> → ok / 可见 SKIP + 归因 / bad
  local title="$1" rc="$2" log="$3" out st ev sl
  out="$(p98_nest_state "$log" "$rc")"
  st="${out%%$'\t'*}"; ev="${out#*$'\t'}"
  case "$st" in
    green) ok "$title" ;;
    env)
      sl="$(p98_nest_sock_len "$log" || true)"
      if [ -n "$sl" ] && [ "$sl" -gt 107 ] 2>/dev/null; then
        ev="$ev ｜ 私有 socket 路径 ${sl} 字节 > AF_UNIX 上限 107"
      fi
      cond_skip "$title" "嵌套 run 的前置环境起不来（rc=$rc）：$ev" ;;
    *) bad "$title（期望 [0]，实际 [$rc]；嵌套 run 里的红不是环境前置：$ev）" ;;
  esac
  return 0
}
# <日志> → P98_CLOSE_N / P98_SUM_P / P98_SUM_F / P98_SUM_S / P98_RES_P / P98_RES_F
p98_ledger() {
  local out
  out="$(sed 's/\x1b\[[0-9;]*m//g' "$1" | awk '
    /^#[0-9]+ / && /· 用时 [0-9]+s · ✓[0-9]+ ✗[0-9]+ SKIP[0-9]+ · ticks [0-9]+$/ {
      p = ""; f = ""; k = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^✓[0-9]+$/) p = $i
        else if ($i ~ /^✗[0-9]+$/) f = $i
        else if ($i ~ /^SKIP[0-9]+$/) k = $i
      }
      gsub(/[^0-9]/, "", p); gsub(/[^0-9]/, "", f); gsub(/[^0-9]/, "", k)
      n++; sp += p; sf += f; sk += k; next
    }
    /== .*结果 ==/ { rp = ""; rf = ""; for (i = 1; i <= NF; i++) { if ($i == "✓") rp = $(i + 1); if ($i == "✗") rf = $(i + 1) }
      gsub(/[^0-9]/, "", rp); gsub(/[^0-9]/, "", rf); resp = rp + 0; resf = rf + 0 }
    END { printf "%d %d %d %d %d %d", n+0, sp+0, sf+0, sk+0, resp+0, resf+0 }
  ')"
  read -r P98_CLOSE_N P98_SUM_P P98_SUM_F P98_SUM_S P98_RES_P P98_RES_F <<<"$out"
  return 0
}
# 映射表副本（--check 的四个方向都在副本上翻，改完即弃；分析对象仍是真树）
p98_table() { # <名字> [<awk-脚本>] → 打印副本路径
  local d="$TMP/p98-table-$1"
  rm -rf "$d"; mkdir -p "$d"
  if [ $# -ge 2 ]; then
    awk -F'\t' -v OFS='\t' "$2" "$SKILL_DIR/tests/section-paths.tsv" > "$d/table.tsv"
  else
    cp "$SKILL_DIR/tests/section-paths.tsv" "$d/table.tsv"
  fi
  printf '%s' "$d/table.tsv"
}
# 变体树：产品面软链到真树，tests/ 是真副本（只有小文件），可改 smoke.sh 造现场
p98_variant() { # <名字> → 打印变体 skill 树路径（仓库根按真树软链；tests/ 是真副本，可改 smoke.sh / 换表造现场）
  local base="$TMP/p98-tree-$1" d="$TMP/p98-tree-$1/skills/teamsmith" r x b
  r="$(cd -P "$(dirname "$(dirname "$SKILL_DIR")")" && pwd)"
  rm -rf "$base"; mkdir -p "$d/tests" "$base/skills"
  for x in "$r"/*; do
    b="$(basename "$x")"; [ "$b" = "skills" ] && continue
    ln -s "$x" "$base/$b"
  done
  for x in "$r"/.[!.]*; do
    b="$(basename "$x")"; [ "$b" = ".git" ] && continue
    ln -s "$x" "$base/$b"
  done
  for x in "$r"/skills/*; do
    b="$(basename "$x")"; [ "$b" = "teamsmith" ] && continue
    ln -s "$x" "$base/skills/$b"
  done
  for x in "$SKILL_DIR"/*; do
    b="$(basename "$x")"; [ "$b" = "tests" ] && continue
    ln -s "$x" "$d/$b"
  done
  for x in "$SKILL_DIR"/tests/*; do
    b="$(basename "$x")"
    ln -s "$x" "$d/tests/$b"
  done
  rm -f "$d/tests/smoke.sh" "$d/tests/section-paths.tsv"
  cp "$SKILL_DIR/tests/smoke.sh" "$d/tests/smoke.sh"
  cp "$SKILL_DIR/tests/section-paths.tsv" "$d/tests/section-paths.tsv"
  printf '%s' "$d"
}

# ── ① --check：真树绿 + 四个方向各自红且点名 ───────────────────────────────────────────
if bash "$SEL36" --check >"$TMP/p98-check.log" 2>&1; then
  ok "36① --check 绿：$(sed -n 's/^== 选段自检 ==  //p' "$TMP/p98-check.log" | tail -1)"
else
  bad "36① --check 红：$(grep -m1 '^bad:' "$TMP/p98-check.log" 2>/dev/null | cut -c1-160)"
fi
P98_T0="$(p98_table clean)"
if bash "$SEL36" --check --table "$P98_T0" >/dev/null 2>&1; then ok "36① 副本表（未改）也绿（负面夹具的基准）"; else bad "36① 副本表未改就红（夹具本身有问题）"; fi
p98_flip() { # <名字> <期望命中的字样> <awk-脚本>
  local t log
  t="$(p98_table "$1" "$3")"
  log="$TMP/p98-check-$1.log"
  if bash "$SEL36" --check --table "$t" >"$log" 2>&1; then
    bad "36① 腐烂 [$1] 没有被 --check 抓住（期望红）"
  elif grep -qF -- "$2" "$log"; then
    ok "36① 腐烂 [$1] 变红且点名（$2）"
  else
    bad "36① 腐烂 [$1] 红了但没点名 [$2]：$(grep -m1 '^bad:' "$log" | cut -c1-160)"
  fi
}
p98_flip row-missing '源码里有段没有行：17' '$1!="17"'
p98_flip pattern-narrow 'token skills/teamsmith/tests/section-select.sh' 'BEGIN{OFS="\t"} $1=="36"{$3="-"} {print}'
p98_flip needs-unknown 'needs 指向未知段：no-such-seg' 'BEGIN{OFS="\t"} $1=="17"{$4="no-such-seg"} {print}'
p98_flip exempt-claimed '声明了豁免类路径' 'BEGIN{OFS="\t"} $1=="17"{$3=$3" docs/team/*"} {print}'
p98_flip literal-missing '字面模式在工作树里不存在：skills/teamsmith/tests/p98-no-such-literal.md' \
  'BEGIN{OFS="\t"} $1=="0"{$3=$3" skills/teamsmith/tests/p98-no-such-literal.md"} {print}'
# 段正文里塞一个没声明的路径 token（scratch 变体树）→ 红且点名 token 与源码行
P98_TK="$(p98_variant token)"
P98_TK_ROOT="$(cd -P "$P98_TK/../.." && pwd)"
if bash "$SEL36" --check --root "$P98_TK_ROOT" >"$TMP/p98-check-token-clean.log" 2>&1; then
  ok "36① 变体树注入前是绿的（token 夹具的负面对照）"
else
  bad "36① 变体树注入前就红了（夹具本身有问题）：$(grep -m1 '^bad:' "$TMP/p98-check-token-clean.log" | cut -c1-160)"
fi
perl -0pi -e 's/(section "1 · doctor（未初始化应失败）"\n)/$1: P98 夹具 token skills\/teamsmith\/tests\/section-select.sh\n/' \
  "$P98_TK/tests/smoke.sh"
grep -qF 'P98 夹具 token skills/teamsmith/tests/section-select.sh' "$P98_TK/tests/smoke.sh" \
  || bad "36① 未声明 token 注入没打上（1 段的形状变了？）"
if bash "$SEL36" --check --root "$P98_TK_ROOT" >"$TMP/p98-check-token.log" 2>&1; then
  bad "36① 段正文塞了未声明 token：[--check] 没抓住（期望红）"
elif grep -qF 'token skills/teamsmith/tests/section-select.sh' "$TMP/p98-check-token.log" \
     && grep -q '源码行 [0-9]' "$TMP/p98-check-token.log"; then
  P98_TKLINE="$(sed -n 's/.*源码行 \([0-9]*\)）.*/\1/p' "$TMP/p98-check-token.log" | head -1)"
  ok "36① 未声明 token → 红且点名 token（skills/teamsmith/tests/section-select.sh）与源码行（$P98_TKLINE）"
else
  bad "36① 未声明 token 红了但没点名 token 与行号：$(grep -m1 '^bad:' "$TMP/p98-check-token.log" | cut -c1-160)"
fi

# ── ② 决定形状与硬错误（纯逻辑，直接问选择器） ────────────────────────────────────────
P98_DOCS="$(bash "$SEL36" --paths docs/team/BOARD.md docs/team/reports/P97-dev3.md 2>&1)"
assert_has_echo "$P98_DOCS" "decision=NONE" "36② docs 路径 → NONE"
assert_has_echo "$P98_DOCS" "没有段落需要运行" "36② NONE 明说没有段需要跑"
P98_RUN="$(bash "$SEL36" --paths skills/teamsmith/scripts/lib/outbox.sh 2>&1)"
assert_has_echo "$P98_RUN" "decision=RUN" "36② 产品路径 → RUN"
P98_RUN_KEYS="$(printf '%s\n' "$P98_RUN" | awk -F'\t' 'NF==2{printf "%s ", $1}')"
P98_MISS=""
for _k in 12b 12b-h0 12b-h0b 12b-h0c 12b-h0d 12b-pi 12b-pi2 12b-pi3 26 27 42 44 46 47; do
  case " $P98_RUN_KEYS " in *" $_k "*) ;; *) P98_MISS="$P98_MISS $_k" ;; esac
done
unset _k
if [ -z "$P98_MISS" ]; then ok "36② outbox 路径选出的 key 覆盖 14 个投递段（含前导与 needs 闭包）"; else bad "36② outbox 选段漏了：$P98_MISS"; fi
P98_FULL="$(bash "$SEL36" --paths ci/some-new-thing 2>&1)"
assert_has_echo "$P98_FULL" "decision=FULL" "36② 没有任何行声明的路径 → FULL 兜底"
assert_has_echo "$P98_FULL" "ci/some-new-thing" "36② FULL 点名那条未被声明的路径"
P98_RC=0; bash "$SEL36" --select no-such-section >"$TMP/p98-unknown.log" 2>&1 || P98_RC=$?
assert_eq "36② 未知 key → 非零" "$P98_RC" "2"
assert_has "$TMP/p98-unknown.log" "no-such-section" "36② 未知 key 被点名"
P98_RC=0; bash "$SEL36" --paths /etc/passwd >"$TMP/p98-outside.log" 2>&1 || P98_RC=$?
assert_eq "36② 仓库外路径 → 非零" "$P98_RC" "2"
assert_has "$TMP/p98-outside.log" "路径出界" "36② 路径出界给理由"
P98_RC=0; bash "$SKILL_DIR/tests/smoke.sh" --select no-such-section >"$TMP/p98-unknown-suite.log" 2>&1 || P98_RC=$?
assert_eq "36② 门禁 --select 未知 key → 非零（且什么都没跑）" "$P98_RC" "2"
assert_not "$TMP/p98-unknown-suite.log" "0 · 临时仓库" "36② 被拒时一个段头都没打"

# ── ③ 账本：嵌套跑一次 --paths 选段（前导 + 0b），核对收口行/增量之和/最慢段 ─────────────
# 嵌套用 --select 0b（不用 --paths：那条路径若被 36 行声明，嵌套跑会再选中 36 段 → 自递归）
P98_SEL_N="$(bash "$SEL36" --select 0b 2>/dev/null | awk -F'\t' 'NF==2{n++} END{print n+0}')"
P98_NEST_ENV="" p98_nest "$SKILL_DIR" "$TMP/p98-nest-run.log" --select 0b
P98_NEST_RC=$?
p98_nest_verdict "36③ 选段嵌套跑退出 0" "$P98_NEST_RC" "$TMP/p98-nest-run.log"
assert_has "$TMP/p98-nest-run.log" "decision=RUN" "36③ 运行头点名 decision=RUN"
assert_has "$TMP/p98-nest-run.log" "== 选段结果 ==" "36③ 结果行用 == 选段结果 =="
assert_not "$TMP/p98-nest-run.log" "smoke 全绿" "36③ 选段运行不喊 smoke 全绿"
assert_not "$TMP/p98-nest-run.log" "== 结果 ==" "36③ 选段运行没有 == 结果 =="
assert_not "$TMP/p98-nest-run.log" "26 · 面板" "36③ 没选的段没有跑（26 段头不在）"
assert_eq "36③ 跑了的段数 == 选择器给的 key 数" "$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep -cE '^#[0-9]+ ')" "$P98_SEL_N"
p98_ledger "$TMP/p98-nest-run.log"
assert_eq "36③ 段落增量之和 == 结果行总数（✓）" "$P98_SUM_P" "$P98_RES_P"
assert_eq "36③ 段落增量之和 == 结果行总数（✗）" "$P98_SUM_F" "$P98_RES_F"
assert_has "$TMP/p98-nest-run.log" "== 最慢 5 段 ==" "36③ 最慢 5 段汇总在结果行之前"
assert_eq "36③ 最慢段汇总行数 == min(5, 跑了的段数)" \
  "$(sed -n '/== 最慢 5 段 ==/,$p' "$TMP/p98-nest-run.log" | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '^  #[0-9]+ ')" \
  "$(awk -v n="$P98_SEL_N" 'BEGIN{print (n>5)?5:n}')"
assert_has "$TMP/p98-nest-run.log" "账本自查：" "36③ 账本自查行在（报告不是判定）"
if tail -25 "$TMP/p98-nest-run.log" | grep -qF '这次没跑的段'; then ok "36③ 未跑清单在尾部 25 行里（team review 记的就是尾部）"; else bad "36③ 未跑清单不在尾部 25 行里"; fi
if sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep -E '^#[0-9]+ ' | grep -qF "$SMOKE_RED_MARK"; then
  bad "36③ 收口行带了门禁红标（会污染 flip-m33 的红标计数）"
else
  ok "36③ 收口行不带门禁红标（flip-m33 数的就是那串）"
fi
# 最后一段的收口行必须在结果行之前，且账本自查行自我声明「一致」
P98_LAST_CLOSE_L="$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep -nE '^#[0-9]+ ' | tail -1 | cut -d: -f1)"
P98_RESULT_L="$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep -n '== 选段结果 ==' | tail -1 | cut -d: -f1)"
if [ -n "$P98_LAST_CLOSE_L" ] && [ -n "$P98_RESULT_L" ] && [ "$P98_LAST_CLOSE_L" -lt "$P98_RESULT_L" ]; then
  ok "36③ 最后一段的收口行在结果行之前（行 $P98_LAST_CLOSE_L < $P98_RESULT_L）"
else
  bad "36③ 最后一段的收口行不在结果行之前（收口 [$P98_LAST_CLOSE_L] / 结果 [$P98_RESULT_L]）"
fi
if sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep '账本自查' | grep -q '—— 一致'; then
  ok "36③ 账本自查行说「一致」"
else
  bad "36③ 账本自查行没说一致：$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-nest-run.log" | grep '账本自查' | head -1)"
fi
# 变体树不在 git 仓库里（p98_variant 故意不软链 .git），0d 的冲突标记守卫要显式喂真仓库根。
# 不能只信 SMOKE_INVOKE_ROOT：flip-m33 从 /tmp 沙盒里跑门禁（cwd 不是仓库）时它是空的，那时必须
# 从 $SKILL_DIR 自己算——否则变体前导段的 0d 必红（flip-m33 实测：3 条红全来自这里）。
P98_MARKER_ROOT="${SMOKE_INVOKE_ROOT:-$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)}"
# 只是慢的段必须保持绿：变体树给 0c 段注入 1 秒 sleep（断言一条不改），秒数要反映出来
P98_SLOW="$(p98_variant slow)"
perl -0pi -e 's/(section "0c · 静态检查（函数结尾的 set -e 陷阱）"\n)/$1sleep 1\n/' "$P98_SLOW/tests/smoke.sh"
grep -q '^sleep 1$' "$P98_SLOW/tests/smoke.sh" || bad "36③ 慢段变体没打上（注入点形状变了）"
P98_NEST_ENV="TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT" p98_nest "$P98_SLOW" "$TMP/p98-slow.log" --select 0c
P98_SLOW_RC=$?
p98_nest_verdict "36③ 故意变慢的段照旧绿（退出码 0）" "$P98_SLOW_RC" "$TMP/p98-slow.log"
P98_SLOW_SEC="$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/p98-slow.log" | awk '/^#[0-9]+ 0c / { for (i = 1; i < NF; i++) if ($i == "用时" && $(i+1) ~ /^[0-9]+s$/) { s = $(i+1); sub(/s$/, "", s); print s; exit } }')"
if awk -v s="$P98_SLOW_SEC" 'BEGIN { exit (s + 0 >= 0.9) ? 0 : 1 }'; then
  ok "36③ 慢段的收口行报出真实秒数（${P98_SLOW_SEC}s ≥ 0.9s）"
else
  bad "36③ 慢段的收口行没反映睡眠（读到 [${P98_SLOW_SEC}]）"
fi
# 夹具旋钮：SMOKE_SLOWEST_N 只在 TEAM_SMOKE_FIXTURE=1 下生效，裸设必须打印忽略
P98_NEST_ENV="SMOKE_SLOWEST_N=2" p98_nest "$SKILL_DIR" "$TMP/p98-knob-off.log" --select 0b
assert_has "$TMP/p98-knob-off.log" "忽略 SMOKE_SLOWEST_N=2" "36③ 裸设 SMOKE_SLOWEST_N 被忽略并打印"
assert_has "$TMP/p98-knob-off.log" "== 最慢 5 段 ==" "36③ 忽略了旋钮就还是默认 N=5"
P98_NEST_ENV="TEAM_SMOKE_FIXTURE=1 SMOKE_SLOWEST_N=2" p98_nest "$SKILL_DIR" "$TMP/p98-knob-on.log" --select 0b
assert_has "$TMP/p98-knob-on.log" "== 最慢 2 段 ==" "36③ 夹具开关打开时 N 被采信（2）"

# ── ④ 选段只对「跑了的段」负责 + NONE 什么都不跑 ────────────────────────────────────────
P98_NONE_RC=0
P98_NEST_ENV="" p98_nest "$SKILL_DIR" "$TMP/p98-none.log" --paths docs/team/BOARD.md || P98_NONE_RC=$?
assert_eq "36④ --paths docs-only 退出 0" "$P98_NONE_RC" "0"
assert_has "$TMP/p98-none.log" "没有段落需要运行" "36④ NONE 明说没有段需要跑"
assert_not "$TMP/p98-none.log" "== 结果 ==" "36④ NONE 没有结果行"
assert_not "$TMP/p98-none.log" "smoke 全绿" "36④ NONE 不喊全绿"
assert_not "$TMP/p98-none.log" "0 · 临时仓库" "36④ NONE 一个段都没起"
# 选段标记只属于**一个进程**：选段子进程里再起的嵌套 smoke 必须照自己的参数走，不许继承标记静默跑整套
# （P98 实测过指数发散：过滤副本 → 36 段 → 负例 → 全套 → 36 段 → …）。现场 = 变体树的 1 段正文里
# 注入一行，调夹具脚本再起一个 --select no-such-section；标记若泄漏，那次调用会跑整套（timeout 兜住）。
P98_LK="$(p98_variant leak)"
P98_LK_NEG="$TMP/p98-leak-neg.sh"
cat > "$P98_LK_NEG" <<'EOS'
if timeout 120 bash "$SKILL_DIR/tests/smoke.sh" --select no-such-section >"$TMP/p98-leak-neg.log" 2>&1; then
  printf '  ✗ P98 夹具：嵌套的 --select no-such-section 没被拒（选段标记泄漏给子孙）\n'
else
  rc=$?
  if [ "$rc" = "2" ]; then
    printf '  ✓ P98 夹具：嵌套的 --select no-such-section 仍被拒（rc=2，标记没泄漏）\n'
  else
    printf '  ✗ P98 夹具：嵌套的负例 rc=%s（期望 2）\n' "$rc"
  fi
fi
EOS
perl -0pi -e 's/(section "1 · doctor（未初始化应失败）"\n)/$1TMP="\$TMP" SKILL_DIR="\$SKILL_DIR" bash "\$P98_LK_NEG"\n/' "$P98_LK/tests/smoke.sh"
grep -qxF 'TMP="$TMP" SKILL_DIR="$SKILL_DIR" bash "$P98_LK_NEG"' "$P98_LK/tests/smoke.sh" \
  || bad "36④ 泄漏夹具注入没打上（1 段的形状变了？）"
P98_LK_RC=0
P98_LK_ENV="P98_LK_NEG=$P98_LK_NEG"
[ -n "$P98_MARKER_ROOT" ] && P98_LK_ENV="$P98_LK_ENV TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT"
P98_NEST_ENV="$P98_LK_ENV" p98_nest "$P98_LK" "$TMP/p98-leak.log" --select 1 || P98_LK_RC=$?
p98_nest_verdict "36④ 选段子进程里的嵌套 smoke 照自己的参数走（负例仍被拒）" "$P98_LK_RC" "$TMP/p98-leak.log"
assert_has "$TMP/p98-leak.log" "P98 夹具：嵌套的 --select no-such-section 仍被拒（rc=2，标记没泄漏）" "36④ 嵌套负例在选段子进程里仍被拒"
assert_not "$TMP/p98-leak.log" "嵌套的 --select no-such-section 没被拒" "36④ 没有「标记泄漏 → 静默跑全套」的现场"
P98_FT="$(p98_variant fail)"
perl -0pi -e 's/(section "1 · doctor（未初始化应失败）"\n)/$1bad "P98 夹具：注入的必红断言（选段只对跑了的段负责）"\n/' "$P98_FT/tests/smoke.sh"
grep -q 'P98 夹具：注入的必红断言' "$P98_FT/tests/smoke.sh" || bad "36④ 必红注入没打上（1 段的形状变了？）"
P98_FT_ENV=""
[ -n "$P98_MARKER_ROOT" ] && P98_FT_ENV="TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT"
P98_RC_A=0
P98_NEST_ENV="$P98_FT_ENV" p98_nest "$P98_FT" "$TMP/p98-failA.log" --select 0,0b || P98_RC_A=$?
p98_nest_verdict "36④ 注入的必红段没被选中 → 选段仍退出 0" "$P98_RC_A" "$TMP/p98-failA.log"
assert_not "$TMP/p98-failA.log" "P98 夹具：注入的必红断言" "36④ 没被选中的段确实没跑"
P98_RC_B=0
P98_NEST_ENV="$P98_FT_ENV" p98_nest "$P98_FT" "$TMP/p98-failB.log" --select 1 || P98_RC_B=$?
if [ "$P98_RC_B" -ne 0 ]; then ok "36④ 选中必红段 → 非零退出（$P98_RC_B）"; else bad "36④ 选中必红段却退出了 0（选段把失败吞了）"; fi
assert_has "$TMP/p98-failB.log" "P98 夹具：注入的必红断言" "36④ 选中的必红段真的跑了并红了"
assert_has "$TMP/p98-failB.log" "== 选段结果 ==" "36④ 红的选段仍用选段结果 token"

# FULL 兜底：真树里嵌套跑一遍 = 整套递归，所以这里钉的是**运行头/收尾的记账**：变体树的 smoke.sh
# 只留段声明（选择器仍数得到全部段）、去掉全部段正文（没有段会真的动文件），收尾保留真收尾
# （同一组函数、同一组 token），于是 `--paths <未声明路径>` 的 FULL 分支可以几秒内完整走一遍。
# 不真跑全套也是安全性：变体树的文档面是**软链**，14b/18 那类「注入→还原」的夹具会穿过软链写回真树。
P98_FB="$(p98_variant fullfb)"
awk '
  /^# __SMOKE_TAIL__/ { tail = 1 }
  tail { print; next }
  /^[[:space:]]*section[[:space:]]+"/ { print; seen = 1; next }
  seen { next }
  { print }
' "$P98_FB/tests/smoke.sh" > "$P98_FB/tests/smoke.sh.stub"
mv "$P98_FB/tests/smoke.sh.stub" "$P98_FB/tests/smoke.sh"
P98_FB_RC=0
P98_NEST_ENV="" p98_nest "$P98_FB" "$TMP/p98-fullfb.log" --paths ci/some-new-thing || P98_FB_RC=$?
assert_eq "36④ FULL 兜底（空壳变体）退出 0" "$P98_FB_RC" "0"
assert_has "$TMP/p98-fullfb.log" "decision=FULL" "36④ FULL 兜底运行头点名 decision=FULL"
P98_FB_N="$(awk -F'\t' '!/^#/ && NF { n++ } END { print n + 0 }' "$SKILL_DIR/tests/section-paths.tsv")"
assert_has "$TMP/p98-fullfb.log" "运行 ${P98_FB_N}/${P98_FB_N} 段" \
  "36④ FULL 兜底：运行头说全套都在跑（不是「0/${P98_FB_N} · 没跑 ${P98_FB_N}」）"
assert_has "$TMP/p98-fullfb.log" "未跑 0 段" "36④ FULL 兜底：运行的段数与未跑数自洽"
assert_has "$TMP/p98-fullfb.log" "这次不跑的键：（无 —— 全套都在跑）" "36④ FULL 兜底：未跑清单为空"
assert_has "$TMP/p98-fullfb.log" "ci/some-new-thing ← 没有任何行声明它（也不在豁免类）" "36④ FULL 兜底点名那条没声明的路径"
assert_has "$TMP/p98-fullfb.log" "== 选段结果 ==" "36④ FULL 兜底用选段结果 token"
assert_not "$TMP/p98-fullfb.log" "smoke 全绿" "36④ FULL 兜底不喊 smoke 全绿"
assert_not "$TMP/p98-fullfb.log" "== 结果 ==" "36④ FULL 兜底没有 == 结果 =="

# ── ⑤ 锁 × 选段（P98 × P66 的组合：合并 main 时这里真的碎过一次）───────────────────────────
# 全量模式下选段子进程要排队：`flock` 拿到锁后必须把**过滤副本**重新跑起来，四个选段标记只能以
# 命令行前缀（env）带回去 —— export 会被它的子孙继承，`exec VAR=value …` 又不成立（实测 rc=127、
# `exec: SMOKE_SEL_CHILD=1: not found`）。§36 其他嵌套跑都带 NO_LOCK，覆盖不到这条组合，所以这里
# 两个方向都钉：绿侧（锁空闲）真的跑过滤副本；红侧（锁被持有 + WAIT=1）排队超限点名 holder + exit 2。
# 私有锁 / 私有 TMPDIR，不碰机器锁。
P98_LS="$TMP/p98-locksel"; rm -rf "$P98_LS"; mkdir -p "$P98_LS/tmp"
p98_locksel() { # <日志> <wait 秒>
  ( cd "$P98_LS" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_AGENT_MODEL -u TEAM_SKILL_DIR -u TEAM_DOCS_DIR -u TEAM_AGENT \
      -u SMOKE_TMP_RUN_ID -u SMOKE_TMP_LEDGER -u TEAM_SMOKE_KEEP -u TEAM_TMP_KEEP \
      -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED -u TEAM_SMOKE_NO_LOCK -u TEAM_SMOKE_FAST \
      -u SMOKE_SEL_CHILD -u SMOKE_SEL_SKILL_DIR -u SMOKE_SEL_DECISION -u SMOKE_SEL_COPY \
      TEAM_SMOKE_LOCK="$P98_LS/lock" TEAM_SMOKE_LOCK_WAIT="$2" TMPDIR="$P98_LS/tmp" \
      bash "$SKILL_DIR/tests/smoke.sh" --select 0b ) >"$1" 2>&1
}
: >>"$P98_LS/lock"
P98_LS_RC=0; p98_locksel "$TMP/p98-locksel-green.log" 10 || P98_LS_RC=$?
p98_nest_verdict "36⑤ 锁空闲：--select 0b 的排队路径仍然跑过滤副本（退出 0）" "$P98_LS_RC" "$TMP/p98-locksel-green.log"
assert_has "$TMP/p98-locksel-green.log" "全量门禁互斥：持有" "36⑤ 过滤副本作为持锁子进程跑了（标记以 env 前缀带回）"
assert_not "$TMP/p98-locksel-green.log" "26 · 面板" "36⑤ 没被丢成整套（没选的段没跑）"
assert_has "$TMP/p98-locksel-green.log" "== 选段结果 ==" "36⑤ 选段结果 token 在"
flock --close -x "$P98_LS/lock" sleep 20 & P98_LS_HOLD=$!
# P115/D33/P62：等锁**真的被拿住**再看状态（flock -n 探锁失败 = 被持有），不拿 0.4s 墙钟赌它起来了。
P98_LS_HELD=0
for _i in $(seq 1 50); do
  if ! flock -n "$P98_LS/lock" true 2>/dev/null; then P98_LS_HELD=1; break; fi
  kill -0 "$P98_LS_HOLD" 2>/dev/null || break
  sleep 0.1
done
unset _i
[ "$P98_LS_HELD" = "1" ] || bad "36⑤ 夹具：持锁者 5s 内没拿住锁（后面的排队断言不成立）"
printf '%s pid=%s cmd=p98-locksel-holder\n' "$(date -Is)" "$P98_LS_HOLD" > "$P98_LS/lock.holder"
P98_LS_RC2=0; p98_locksel "$TMP/p98-locksel-red.log" 1 || P98_LS_RC2=$?
kill "$P98_LS_HOLD" 2>/dev/null; wait "$P98_LS_HOLD" 2>/dev/null || true
assert_eq "36⑤ 锁被持有 + WAIT=1 → exit 2（不是 1、不静默）" "$P98_LS_RC2" "2"
assert_match "$TMP/p98-locksel-red.log" "排队超限.*cmd=p98-locksel-holder" "36⑤ 排队超限点名 <lock>.holder 里的持有者"
assert_not "$TMP/p98-locksel-red.log" "0b · skill 可被 pi 解析器加载" "36⑤ 排队超限时一段都没跑"

# ── ⑥ 嵌套跑判定的两向夹具（P115）：环境前置 → 可见 SKIP + 归因；真红 → 照旧红 ───────────────
# 判定逻辑在 p98_nest_state/p98_nest_verdict（见段首）。这里把两向都钉成可复跑的夹具：环境侧真的
# 把嵌套 socket 路径压过 107 字节；真红侧给三条受保护断言的配置各喂一个真的失败断言。断言出口在
# 子 shell 里取输出，夹具自己的红不记进门禁计数。
p98_state_has() { # <日志> <rc> <期望判类> <期望归因字样（- = 不查）> <断言前缀>
  local log="$1" rc="$2" want="$3" evwant="$4" pre="$5" out st ev
  out="$(p98_nest_state "$log" "$rc")"
  st="${out%%$'\t'*}"; ev="${out#*$'\t'}"
  assert_eq "$pre 判类" "$st" "$want"
  [ "$evwant" = "-" ] || assert_has_echo "$ev" "$evwant" "$pre 归因点名 [$evwant]"
}
# 环境侧（不假红）：嵌套 TMPDIR 足够深 → 嵌套 socket 路径必定超 AF_UNIX 上限 107 字节 → 判 env。
P98_DEEP_TMP="$TMP/p115-deep/aaaaaaaa/bbbbbbbb/cccccccc/dddddddd"
mkdir -p "$P98_DEEP_TMP"
P98_NEST_TMPDIR="$P98_DEEP_TMP" P98_NEST_ENV="" p98_nest "$SKILL_DIR" "$TMP/p115-env.log" --select 0b
P98_ENV_RC=$?
p98_state_has "$TMP/p115-env.log" "$P98_ENV_RC" "env" "私有 socket 没生效" "36⑥ 环境侧（深 TMPDIR）"
P98_ENV_SL="$(p98_nest_sock_len "$TMP/p115-env.log" || true)"
if [ -n "$P98_ENV_SL" ] && [ "$P98_ENV_SL" -gt 107 ] 2>/dev/null; then
  ok "36⑥ 环境侧夹具有效：嵌套私有 socket 路径 ${P98_ENV_SL} 字节 > AF_UNIX 上限 107"
else
  bad "36⑥ 环境侧夹具没造出超限 socket 路径（读到 [${P98_ENV_SL:-空}] 字节）"
fi
P98_VOUT="$( ( p98_nest_verdict "36⑥ 环境侧判定出口" "$P98_ENV_RC" "$TMP/p115-env.log" ) 2>&1 || true )"
assert_has_echo "$P98_VOUT" "SKIP（条件不满足）" "36⑥ 环境侧经断言出口是可见 SKIP（不判红）"
assert_not_echo "$P98_VOUT" "✗" "36⑥ 环境侧经断言出口没有红标"
# 锁排队（exit 2、没有 ✗ 行）也必须归 env：合成日志直接钉判定，并把 holder 名字带出来。
printf '排队超限：等满 1s 仍拿不到门禁锁 /x/teamsmith-smoke.lock（持锁者：pid=999 cmd=p115-holder）→ 本套没有运行\n' > "$TMP/p115-queue.log"
p98_state_has "$TMP/p115-queue.log" "2" "env" "cmd=p115-holder" "36⑥ 锁排队（exit 2）"
# 混合形状（环境红 + 真红同时出现）→ 真红优先：判 red 并点名真红（环境归因不许吞真红）。
printf '  ✗ tmux 隔离：私有 socket 没生效（期望 /x/tmux/tmux-1000/default，TMUX_TMPDIR=/x/tmux）\n  ✗ P115 夹具：真红（混合形状）\n' > "$TMP/p115-mixed.log"
p98_state_has "$TMP/p115-mixed.log" "1" "red" "P115 夹具：真红（混合形状）" "36⑥ 混合（环境红+真红）"
# 不可归因（rc 非零、一条 ✗ 都没有、也不是锁排队）→ 照旧红，不得被当成环境跳过。
printf 'smoke: 未知错误\n' > "$TMP/p115-opaque.log"
p98_state_has "$TMP/p115-opaque.log" "1" "red" "没有环境前置" "36⑥ 不可归因（无红行）"
# 真红侧（照旧红）：三条受保护断言的配置各注入一个真的失败断言 → 判类必须 red、出口必须发红标。
P98_RED_ENV=""
[ -n "$P98_MARKER_ROOT" ] && P98_RED_ENV="TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT"
P98_RED0B="$(p98_variant p115-red0b)"
perl -0pi -e 's/(section "0b · skill 可被 pi 解析器加载"\n)/$1bad "P115 夹具：0b 里的真红（红侧）"\n/' "$P98_RED0B/tests/smoke.sh"
grep -q 'P115 夹具：0b 里的真红' "$P98_RED0B/tests/smoke.sh" || bad "36⑥ 红侧 §0b 注入没打上（段形状变了？）"
P98_NEST_ENV="$P98_RED_ENV" p98_nest "$P98_RED0B" "$TMP/p115-red0b.log" --select 0b; P98_RB_RC=$?
p98_state_has "$TMP/p115-red0b.log" "$P98_RB_RC" "red" "P115 夹具：0b 里的真红" "36⑥ 真红侧（--select 0b）"
P98_VOUT="$( ( p98_nest_verdict "36⑥ 真红侧判定出口" "$P98_RB_RC" "$TMP/p115-red0b.log" ) 2>&1 || true )"
assert_has_echo "$P98_VOUT" "✗" "36⑥ 真红侧经断言出口照旧红（环境跳过没有吞掉真红）"
P98_RED0C="$(p98_variant p115-red0c)"
perl -0pi -e 's/(section "0c · 静态检查（函数结尾的 set -e 陷阱）"\n)/$1bad "P115 夹具：0c 里的真红（红侧）"\n/' "$P98_RED0C/tests/smoke.sh"
grep -q 'P115 夹具：0c 里的真红' "$P98_RED0C/tests/smoke.sh" || bad "36⑥ 红侧 §0c 注入没打上（段形状变了？）"
P98_NEST_ENV="$P98_RED_ENV" p98_nest "$P98_RED0C" "$TMP/p115-red0c.log" --select 0c; P98_RC_RC=$?
p98_state_has "$TMP/p115-red0c.log" "$P98_RC_RC" "red" "P115 夹具：0c 里的真红" "36⑥ 真红侧（--select 0c，慢段配置）"
P98_RED1="$(p98_variant p115-red1)"
perl -0pi -e 's/(section "1 · doctor（未初始化应失败）"\n)/$1bad "P115 夹具：1 段里的真红（红侧）"\n/' "$P98_RED1/tests/smoke.sh"
grep -q 'P115 夹具：1 段里的真红' "$P98_RED1/tests/smoke.sh" || bad "36⑥ 红侧 §1 注入没打上（段形状变了？）"
P98_NEST_ENV="$P98_RED_ENV" p98_nest "$P98_RED1" "$TMP/p115-red1.log" --select 1; P98_R1_RC=$?
p98_state_has "$TMP/p115-red1.log" "$P98_R1_RC" "red" "P115 夹具：1 段里的真红" "36⑥ 真红侧（--select 1，泄漏配置）"

# ── ⑦ 副本必须永远可解析（P117/V1）+ needs 闭包自足（P117/V2） ────────────────────────────
# V1（P112 §5.1）：剪贴器把任何缩进的段头都当边界；14c 的段头坐在 14 段的 FAST 守卫里，
# 于是「保留 14、丢弃 14c」的副本会剪掉那个 fi —— 跑完全部选中段之后才在 EOF 上 exit 2，
# 没有结果行。判据：① 全键副本 bash -n 扫描必须 ok 全部 / bad 0；② 把裁判砸掉（还原
# 「按段头一刀切」）→ 同一个扫描必须红，且坏副本必须在**跑任何段之前**被拒（rc=2、点名、零段头）。
# V2（P112 §5.2）：夹具前提段补进 needs 后，夹具依赖键（3b/6）的选集必须全绿；删掉一条
# needs → 该键的选集必须红。全键逐键审计是 tests/section-needs-audit.sh（验收时整跑；
# 默认门禁里钉的是采样 + 两个红侧，是时间预算与覆盖面的折中）。
P117_N="$(awk -F'\t' '!/^#/ && NF { n++ } END { print n + 0 }' "$SKILL_DIR/tests/section-paths.tsv")"
P117_SWEEP_RC=0
bash "$SEL36" --verify-copies >"$TMP/p117-sweep.log" 2>&1 || P117_SWEEP_RC=$?
if [ "$P117_SWEEP_RC" -eq 0 ] && grep -qF "== 段副本 bash -n 扫描 == ok ${P117_N} bad 0" "$TMP/p117-sweep.log"; then
  ok "36⑦ 全键副本 bash -n 扫描：ok ${P117_N} / bad 0"
else
  bad "36⑦ 全键副本 bash -n 扫描有红（rc=$P117_SWEEP_RC）：$(grep -E '^(bad|== 段副本)' "$TMP/p117-sweep.log" | head -5 | tr '\n' ' ')"
fi
P117_SHADOW="$(p98_variant p117shadow)"
rm -f "$P117_SHADOW/tests/section-select.sh"
cp "$SKILL_DIR/tests/section-select.sh" "$P117_SHADOW/tests/section-select.sh"
perl -0pi -e 's/(span_parses\(\) \{ # [^\n]*\n)/$1  return 0  # P117 红侧：还原旧剪贴器\n/' "$P117_SHADOW/tests/section-select.sh"
if grep -q 'P117 红侧：还原旧剪贴器' "$P117_SHADOW/tests/section-select.sh"; then
  P117_SHADOW_RC=0
  bash "$P117_SHADOW/tests/section-select.sh" --verify-copies >"$TMP/p117-shadow.log" 2>&1 || P117_SHADOW_RC=$?
  if [ "$P117_SHADOW_RC" -ne 0 ] \
     && grep -qF 'bad: 14 ' "$TMP/p117-shadow.log" && grep -qF 'bad: 14c ' "$TMP/p117-shadow.log"; then
    ok "36⑦ 红侧（旧剪贴器=按段头一刀切）：全键扫描红了并点名 14/14c"
  else
    bad "36⑦ 红侧（旧剪贴器）：扫描没红到点（rc=$P117_SHADOW_RC）：$(grep -E '^(bad|== 段副本)' "$TMP/p117-shadow.log" | head -5 | tr '\n' ' ')"
  fi
  P98_NEST_ENV="TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT" p98_nest "$P117_SHADOW" "$TMP/p117-early.log" --select 14
  P117_EARLY_RC=$?
  if [ "$P117_EARLY_RC" -eq 2 ] \
     && grep -qF '副本不能解析' "$TMP/p117-early.log" \
     && grep -qF '什么都没跑' "$TMP/p117-early.log" \
     && ! sed 's/\x1b\[[0-9;]*m//g' "$TMP/p117-early.log" | grep -q '^== #'; then
    ok "36⑦ 坏副本在跑任何段之前被拒（rc=2、点名、零段头）"
  else
    bad "36⑦ 坏副本没有早拒（rc=$P117_EARLY_RC）：$(tail -3 "$TMP/p117-early.log" | tr '\n' ' ')"
  fi
else
  bad "36⑦ 红侧夹具没打上（选择器的 span_parses 形状变了？）"
fi
p117_own_line() { sed 's/\x1b\[[0-9;]*m//g' "$1" | awk -v k="$2" '$1 ~ /^#[0-9]+$/ && $2 == k && /用时/ { print; exit }'; }
for P117_K in 3b 6; do
  P98_NEST_ENV="" p98_nest "$SKILL_DIR" "$TMP/p117-green-$P117_K.log" --select "$P117_K"
  P117_GRC=$?; P117_LINE="$(p117_own_line "$TMP/p117-green-$P117_K.log" "$P117_K")"
  if [ "$P117_GRC" -eq 0 ] && [ -n "$P117_LINE" ] && printf '%s' "$P117_LINE" | grep -q '✗0 '; then
    ok "36⑦ 夹具依赖键 --select $P117_K 的选集全绿（$P117_LINE）"
  else
    bad "36⑦ 夹具依赖键 --select $P117_K 的选集有红（rc=$P117_GRC；own=[$P117_LINE]）"
  fi
done
unset P117_K
p117_red_side() { # <名字> <key> <awk 变异> <说明>
  local name="$1" key="$2" mut="$3" desc="$4" V rc line
  V="$(p98_variant "$name")" || { bad "36⑦ 红侧 $name：建不出变体树"; return 0; }
  awk -F'\t' -v OFS='\t' "$mut" "$SKILL_DIR/tests/section-paths.tsv" > "$V/tests/section-paths.tsv" \
    || { bad "36⑦ 红侧 $name：表变异失败"; return 0; }
  P98_NEST_ENV="TEAM_SMOKE_MARKER_ROOT=$P98_MARKER_ROOT" p98_nest "$V" "$TMP/p117-red-$name.log" --select "$key"
  rc=$?; line="$(p117_own_line "$TMP/p117-red-$name.log" "$key")"
  if [ "$rc" -ne 0 ] && [ -n "$line" ] && ! printf '%s' "$line" | grep -q '✗0 '; then
    ok "36⑦ 红侧：$desc → --select $key 在该键上红了（rc=$rc；$line）"
  else
    bad "36⑦ 红侧：$desc 没让 --select $key 红（rc=$rc；own=[$line]）"
  fi
}
p117_red_side p117red3b 3b '$1 == "3b" { $4 = "4" } 1' '3b 去掉 needs:5'
p117_red_side p117red6 6 '$1 == "6" { $4 = "4,5" } 1' '6 去掉 needs:3b'

# ---------------------------------------------------------------- 37. 读路径：根一次解析 + 单进程扫描（M50）
# 实测现场（M50 任务书，PM 在 main 上量的）：BOARD.md 只有 141 行，`team digest` 却要 89 秒 ——
# 每次辅助调用都重新解析仓库根（~5 次 rev-parse），每份报告/复验记录各问一轮 git
#（digest 一拍 1620 次 git 调用，其中 1523 次 rev-parse、80 次 for-each-ref）。修复：
#   ① 仓库根一次 rev-parse 同时取 --show-toplevel 与 --git-common-dir，并按目录 memo 在进程内
#     （team_load_config 在身份已锁定时不再重问 team_is_git_repo）；
#   ② digest / status / __panel-data 在**单个进程**内完成扫描：看板/工作树/refs/复验抬头/state
#     一个「扫描纪元」只读一次（team_scan_warm 预热，$(…) 子 shell 经 fork 继承热缓存），
#     写路径当场 team_scan_invalidate；TEAM_SCAN_CACHE=0 整层关掉、全部落回直读实现 ——
#     它就是等价性对照开关。
# 判定语义一行不改，下面用「缓存开/关输出逐字节一致」钉等价性，用 git 调用计数钉性能：
#   · `team board row <ID>` ≤ 1 次 git（旧实现同一调用 3–5 次 rev-parse）；
#   · `team digest` ≤ 50 次 git（任务书判据；旧实现实测 1620）；
#   · 夹具非空转：同一夹具上 cache-off（= 旧的逐文件问法）> 50 次 —— 这扇门确实能抓住旧形状。
# 全部在自己的临时仓库里跑（先证明身份），快慢模式都跑。
section "37 · 读路径性能：根一次解析 + 单进程扫描（M50）"

unset TEAM_SCAN_CACHE 2>/dev/null || true   # 调用者若带着对照开关，本节自己显式管
M50R="$TMP/m50repo"; rm -rf "$M50R"; mkdir -p "$M50R"
( cd "$M50R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# m50' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
M50SES="teamsmith-smoke-m50-$$"
( cd "$M50R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$M50SES" --agents "dev bob carol" --vcs local --gates "true" --docs docs/team ) >"$TMP/m50-init.log" 2>&1 \
  && ok "M50 夹具仓库 init 成功" || bad "M50 夹具仓库 init 失败（见 $TMP/m50-init.log）"
( cd "$M50R" && git add -A && git commit -qm "chore: m50 init" ) >/dev/null 2>&1

# 身份隔离（M7.2 纪律）：**写盘之前**先证明 team 认的是这个临时仓库 + 这个临时 session
( cd "$M50R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/m50-paths.json" 2>&1 || true
assert_eq "M50 隔离：team paths 的 main_root 就是 M50 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/m50-paths.json")" "$M50R"
assert_has "$TMP/m50-paths.json" "\"session\": \"$M50SES\"" "M50 隔离：身份用的是本轮临时 session"

m50() { ( cd "$M50R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }

# git 调用计数 shim：PATH 最前的 `git` 包装，整行 argv 追加进 M50SHIM_LOG 后透传真 git。
# 只包 team 的调用（夹具搭建不经过它），日志一次一清，计数 = wc -l。
M50SHIM="$TMP/m50shim"; mkdir -p "$M50SHIM"
M50_REAL_GIT="$(command -v git)"
cat > "$M50SHIM/git" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "\${M50SHIM_LOG:-$TMP/m50shim-calls.log}" 2>/dev/null || true
exec $M50_REAL_GIT "\$@"
EOF
chmod +x "$M50SHIM/git"
m50_counted() { # <cwd> <log> <cmd…>：带 shim 跑一次（git 调用逐行进 log）
  local cw="$1" log="$2"; shift 2
  : > "$log"
  ( cd "$cw" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      PATH="$M50SHIM:$PATH" M50SHIM_LOG="$log" "$@" )
}

# ── 夹具语料：主工作树 12 个任务（看板行+任务书+已提交报告）+ bob/carol 工作树各 12 份
#    「只在工作树里」的报告（digest 的逐文件判定全走它们）+ 3 条复验记录（PASS/FAIL/SKIPPED ——
#    SKIPPED 带 [gates: none] 标记留在待复验清单里，另外两条是「记录有效不列」的对照）。
m50_seed_task() { # <ID> <agent>：看板行 + 任务书
  m50 $TEAM board add "$1" "M50 fixture $1" "$2" - >/dev/null 2>&1 || true
  printf '# %s · smoke M50 fixture\n\ntask:   %s\nagent:  %s\ndeps:   -\nstatus: todo\n' "$1" "$1" "$2" \
    > "$M50R/docs/team/tasks/$1-m50-smoke.md"
}
m50_report() { # <ID> <agent> <目录>
  printf '# %s · smoke M50 fixture\n\nagent:  %s   状态: DONE\n\n## 交付物\n- fixture\n' "$1" "$2" > "$3/$1-$2.md"
}
for i in $(seq 1 12); do m50_seed_task "M50P$i" dev; m50_report "M50P$i" dev "$M50R/docs/team/reports"; done
printf '# M50P1 复验\n\n判定: **PASS**\nHEAD: `123456789`\n时间: 2026-09-20 · 分支: `task/M50P1-x`\n' > "$M50R/docs/team/reviews/M50P1.md"
printf '# M50P2 复验\n\n判定: **FAIL**\nHEAD: `123456789`\n时间: 2026-09-20 · 分支: `task/M50P2-x`\n' > "$M50R/docs/team/reviews/M50P2.md"
printf '# M50P3 复验\n\n判定: **SKIPPED**\n' > "$M50R/docs/team/reviews/M50P3.md"
( cd "$M50R" && git add -A && git commit -qm "seed: main tasks" ) >/dev/null 2>&1
git -C "$M50R" worktree add -b task/m50-bob "$M50R/.worktrees/bob" main >/dev/null 2>&1
git -C "$M50R" worktree add -b task/m50-carol "$M50R/.worktrees/carol" main >/dev/null 2>&1
for i in $(seq 1 12); do m50_seed_task "M50W$i" bob; done
for i in $(seq 1 12); do m50_seed_task "M50C$i" carol; done
mkdir -p "$M50R/.worktrees/bob/docs/team/reports" "$M50R/.worktrees/carol/docs/team/reports"
for i in $(seq 1 12); do m50_report "M50W$i" bob "$M50R/.worktrees/bob/docs/team/reports"; done
for i in $(seq 1 12); do m50_report "M50C$i" carol "$M50R/.worktrees/carol/docs/team/reports"; done
( cd "$M50R/.worktrees/bob" && git add -A && git commit -qm "bob reports" ) >/dev/null 2>&1
( cd "$M50R/.worktrees/carol" && git add -A && git commit -qm "carol reports" ) >/dev/null 2>&1
( cd "$M50R" && git add -A && git commit -qm "seed: worktree tasks" ) >/dev/null 2>&1
# 60 = 主仓 12 + bob 24（自己的 12 + 随分支带过去的主仓副本 12）+ carol 24。文件数含副本；
# digest 扫的是去重后的**主候选**（每个 id 一份，36）—— 两个数都钉住，夹具有效性才算数。
assert_eq "M50 夹具有效：60 份报告文件（含工作树副本）+ 3 条复验记录就位" \
  "$(ls "$M50R"/docs/team/reports/*.md "$M50R"/.worktrees/*/docs/team/reports/*.md 2>/dev/null | wc -l | tr -d ' '):$(ls "$M50R"/docs/team/reviews/*.md 2>/dev/null | wc -l | tr -d ' ')" "60:3"
cat > "$TMP/m50-cands.sh" <<'EOS'
set -uo pipefail
export TEAM_ROOT="$1" TEAM_CONFIG_FILE="" TEAM_ASSUME_YES=0 TEAM_SKILL_DIR_OVERRIDE=""
D="$2/scripts"
TEAM_SKILL_DIR="$2"
# shellcheck disable=SC1090
. "$D/lib/common.sh"
for f in "$D"/lib/cmd-*.sh; do
  # shellcheck disable=SC1090
  . "$f"
done
team_load_config
printf 'cands=%s\n' "$(team_report_primary_candidates | wc -l | tr -d ' ')"
EOS
(cd "$M50R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
  bash "$TMP/m50-cands.sh" "$M50R" "$SKILL_DIR" > "$TMP/m50-cands.out" 2>&1)
assert_eq "M50 夹具有效：去重后的主候选 36（主仓 12 + bob 12 + carol 12）" \
  "$(sed -n 's/^cands=//p' "$TMP/m50-cands.out")" "36"

# P47/R3：工作树里的**未入账**记录 —— 计数夹具（spec 的 GIVEN 写明「one untracked record inside one of
# the worktrees」）现在就要它：per-worktree 的 `git status` 也进这份预算，[4] 必须点名它。首行故意不写成
# `# <ID> · …`（那不是任务报告），所以它只进 [4] 的字节扫描，不改变 [3] 的 34 行与上面的 36 个候选。
M50W_REC="docs/team/reports/M50WT-bob.md"
printf '# smoke M50 fixture（工作树未入账记录，不是任务报告）\n' > "$M50R/.worktrees/bob/$M50W_REC"
assert_eq "M50 夹具新增：bob 工作树里的一份未入账记录就位（只进 [4] 扫描）" \
  "$(git -C "$M50R/.worktrees/bob" status --porcelain --untracked-files=all -- docs/team/reports | grep -c '^?? docs/team/reports/M50WT-bob.md$')" "1"

# ── ① 仓库根一次解析：`team board row <ID>` 整个调用 ≤ 1 次 git（旧实现同一条命令 3–5 次 rev-parse）
m50_counted "$M50R" "$TMP/m50-row.log" $TEAM board row M50P1 >"$TMP/m50-row.out" 2>&1
M50_N="$(wc -l < "$TMP/m50-row.log" | tr -d ' ')"
[ "$M50_N" -le 1 ] && ok "M50-① board row 的 git 调用数 ≤ 1（实测 $M50_N）" || { bad "M50-① board row 的 git 调用数 $M50_N > 1"; sed 's/^/      /' "$TMP/m50-row.log"; }
assert_has "$TMP/m50-row.out" "M50P1" "M50-① board row 真的读到了那一行（不是空输出蒙混）"
# 从子目录调用也一样（identity 从 cwd 上溯，同一条一次解析路径）
m50_counted "$M50R/docs/team" "$TMP/m50-row-sub.log" $TEAM board row M50P1 >"$TMP/m50-row-sub.out" 2>&1
M50_N="$(wc -l < "$TMP/m50-row-sub.log" | tr -d ' ')"
[ "$M50_N" -le 1 ] && ok "M50-①b 子目录里 board row 的 git 调用数 ≤ 1（实测 $M50_N）" || bad "M50-①b 子目录 board row 的 git 调用数 $M50_N > 1"
# 对照开关不改变输出（cache-off = 逐字同一行）
m50 env TEAM_SCAN_CACHE=0 $TEAM board row M50P1 >"$TMP/m50-row-off.out" 2>&1
assert_eq "M50-①c cache 开/关 board row 输出逐字节一致" "$(cat "$TMP/m50-row-off.out")" "$(cat "$TMP/m50-row.out")"

# ── ② 单进程扫描：`team digest` ≤ 50 次 git（任务书判据；旧实现实测 1620）
m50_counted "$M50R" "$TMP/m50-dg-on.log" $TEAM digest >"$TMP/m50-dg-on.out" 2>&1 || bad "M50-② digest 本身失败（见输出）"
M50_ON="$(wc -l < "$TMP/m50-dg-on.log" | tr -d ' ')"
[ "$M50_ON" -le 50 ] && ok "M50-② digest 的 git 调用数 ≤ 50（实测 $M50_ON）" || { bad "M50-② digest 的 git 调用数 $M50_ON > 50"; sort "$TMP/m50-dg-on.log" | uniq -c | sort -rn | head -5 | sed 's/^/      /'; }
assert_has "$TMP/m50-dg-on.out" "M50W1-bob" "M50-② digest 真的扫到了工作树里的报告（不是空扫描蒙混）"
assert_has "$TMP/m50-dg-on.out" "bob: $M50W_REC" "M50-②b 工作树里未入账的记录被点名（bob: <路径>；P47/R3 的扫描进同一预算）"
assert_has "$TMP/m50-dg-on.out" "gates: none" "M50-② SKIPPED 记录照旧带标记列出（判定语义没动）"
# [3] 必须列全 34 行（36 - PASS 记录有效 - FAIL 记录有效）。这条钉的是 M50 修过的一颗真雷：
# wip 里 team__review_subject_tip 裸调 team__resolve_branch 拿 rc —— set -e 下 rc=1 直接杀死
# 进程替换的**生产者**，[3] 只打出前 3 行（恰好断在第一条带复验记录的报告之后）。
assert_eq "M50-②c [3] 待复验列全 34 行（生产者不在带记录的报告上死掉）" \
  "$(sed -n '/^\[3\] 待复验/,/^\[4\]/p' "$TMP/m50-dg-on.out" | grep -c '^  M50')" "34"
# 夹具非空转：同一夹具上 cache-off（每份报告/记录各问一轮 git 的旧形状）必须 > 50 ——
# 若哪天这条挂了，说明夹具瘦到抓不住旧形状，①②的阈值断言也跟着失去意义。
m50_counted "$M50R" "$TMP/m50-dg-off.log" env TEAM_SCAN_CACHE=0 $TEAM digest >"$TMP/m50-dg-off.out" 2>&1
M50_OFF="$(wc -l < "$TMP/m50-dg-off.log" | tr -d ' ')"
[ "$M50_OFF" -gt 50 ] && ok "M50-②b 夹具非空转：cache-off 同口径 $M50_OFF 次 git > 50（旧形状会被这扇门抓住）" || bad "M50-②b cache-off 只有 $M50_OFF 次 git —— 夹具太瘦，≤50 断言空转"
# 等价性：cache 开/关的 digest 除「头行时间戳 + 实时容量行」逐字节一致
m50_dg_norm() { grep -v 'RAM 可用' "$1" | tail -n +2; }
if diff <(m50_dg_norm "$TMP/m50-dg-on.out") <(m50_dg_norm "$TMP/m50-dg-off.out") >"$TMP/m50-dg.diff" 2>&1; then
  ok "M50-②c digest cache 开/关输出逐字节一致（滤时间戳与容量行）"
else
  bad "M50-②c digest cache 开/关输出不一致"; head -10 "$TMP/m50-dg.diff" | sed 's/^/      /'
fi

# ── ③ status / __panel-data 同一层缓存：开/关输出一致（滤实时字段）
m50 $TEAM status >"$TMP/m50-st-on.out" 2>&1
m50 env TEAM_SCAN_CACHE=0 $TEAM status >"$TMP/m50-st-off.out" 2>&1
if diff <(grep -v 'RAM 可用' "$TMP/m50-st-on.out") <(grep -v 'RAM 可用' "$TMP/m50-st-off.out") >"$TMP/m50-st.diff" 2>&1; then
  ok "M50-③ status cache 开/关输出逐字节一致（滤容量行）"
else
  bad "M50-③ status cache 开/关输出不一致"; head -10 "$TMP/m50-st.diff" | sed 's/^/      /'
fi
m50 $TEAM __panel-data --no-activity >"$TMP/m50-pd-on.out" 2>&1
m50 env TEAM_SCAN_CACHE=0 $TEAM __panel-data --no-activity >"$TMP/m50-pd-off.out" 2>&1
m50_pd_norm() { sed -e 's/"timestamp": "[^"]*"/"timestamp":"T"/' -e 's/"capacity": {[^}]*}/"capacity":"C"/' "$1"; }
if diff <(m50_pd_norm "$TMP/m50-pd-on.out") <(m50_pd_norm "$TMP/m50-pd-off.out") >"$TMP/m50-pd.diff" 2>&1; then
  ok "M50-③b __panel-data cache 开/关逐字段一致（掩 timestamp 与 capacity 块）"
else
  bad "M50-③b __panel-data cache 开/关输出不一致"; head -6 "$TMP/m50-pd.diff" | cut -c1-200 | sed 's/^/      /'
fi

section "38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具）"
# 38-a headless：tests/panel-choices.sh —— choices 逐 kind（R1）/ 模型词表是本项目数据（R2）/
# **读给出的值 = 校验器接受的值** 的走查闸门 + F-A/F-D 翻转。不依赖 tmux，FAST 模式照跑（~2.5 分钟，
# 其中走查是 86 次 `team config set … --dry-run`：它就是这条闸门的全部价值，不能省）。
if [ -f "$SKILL_DIR/tests/panel-choices.sh" ]; then
  if bash "$SKILL_DIR/tests/panel-choices.sh" >"$TMP/panel-choices.log" 2>&1; then
    ok "38-a panel-choices.sh 全绿（$(grep -a '== 结果 ==' "$TMP/panel-choices.log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/.*== 结果 == //' | tr -s ' ')；含一致性走查与 F-A/F-D 翻转）"
    tail -2 "$TMP/panel-choices.log" | sed 's/^/      /'
  else
    bad "38-a panel-choices.sh 有失败"
    grep -a '✗' "$TMP/panel-choices.log" | head -10 | sed 's/^/      /'
    tail -3 "$TMP/panel-choices.log" | sed 's/^/      /'
  fi
else
  bad "38-a 缺 tests/panel-choices.sh"
fi
# 38-b/38-f 的判定表（P48）：夹具的退出码就是机器前提的出口。
#   0 → 全绿（照旧）｜ 1 → 断言失败（照旧）｜ 3 → 搭建失败（照旧）
#   4 → 夹具可见 SKIP（机器超前提）：打印夹具自己的 SKIP 行（含原因与读数）与结果行，门禁退出码不变
#        —— 跳过的场景**绝不能**被印成全绿。
p38_verdict() { # <tag> <log> <rc> <what>
  local tag="$1" log="$2" rc="$3" what="$4" summary line
  summary="$(grep -a '== 结果 ==' "$log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/.*== 结果 == //' | tr -s ' ')"
  case "$rc" in
    0)
      ok "$tag $what 全绿（$summary）"
      tail -1 "$log" | sed 's/^/      /' ;;
    4)
      line="$(grep -a 'SKIP' "$log" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^ *//')"
      cond_skip "$tag $what" "${line:-夹具报告了跳过（rc=4）但日志里没有 SKIP 行}"
      tail -1 "$log" | sed 's/^/      /' ;;
    1)
      bad "$tag $what 有失败"
      grep -a '✗' "$log" | head -8 | sed 's/^/      /'
      tail -2 "$log" | sed 's/^/      /' ;;
    3)
      bad "$tag $what 搭建失败（exit 3）"
      tail -3 "$log" | sed 's/^/      /' ;;
    *)
      bad "$tag $what 意外退出码 $rc"
      tail -3 "$log" | sed 's/^/      /' ;;
  esac
}
# 38-b pty 夹具：panel-p21.sh choices（真 bundle + 私有 tmux server + argv 记录的 wrapper）——FAST 显式跳过。
# P48：退出码 4 = 机器超前提的可见 SKIP（夹具自己的 SKIP 行带原因与读数），门禁不因此变红。
if [ -f "$SKILL_DIR/tests/panel-p21.sh" ]; then
  if [ "$FAST" = "1" ]; then
    fast_skip "38-b·panel-p21-choices" "panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）"
  else
    live_mark
    bash "$SKILL_DIR/tests/panel-p21.sh" choices >"$TMP/panel-p21-choices.log" 2>&1
    p38rc=$?
    p38_verdict "38-b" "$TMP/panel-p21-choices.log" "$p38rc" "panel-p21.sh choices"
  fi
else
  bad "38-b 缺 tests/panel-p21.sh"
fi
# 38-c lib 自检：tests/lib/pty-wait.sh --self-test —— 用假 pane 注入 M55 第一次复验的中间帧
# （标题先到、条目隔一拍才到），证明「只看标题」的旧逻辑会放行（假红入口）而「条目标记 +
# 稳定帧」的新逻辑不放行；清理守卫在「选择器早已关闭」的现场一个键都不发；故意超时的等待
# 自带现场（哪条等待/等了多久/缺什么/pane 末行/再 capture/孤立还是级联）。不依赖 tmux 或真
# bundle，FAST 照跑；--break=<stage> 是夹具自检专用的翻转开关（复验报告里给红面）。
if [ -f "$SKILL_DIR/tests/lib/pty-wait.sh" ]; then
  if bash "$SKILL_DIR/tests/lib/pty-wait.sh" --self-test >"$TMP/pty-wait-selftest.log" 2>&1; then
    ok "38-c pty-wait 自检全绿（$(grep -a '== 结果 ==' "$TMP/pty-wait-selftest.log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/.*== 结果 == //' | tr -s ' ')；中间帧注入 + 清理守卫 + 失败现场）"
    tail -2 "$TMP/pty-wait-selftest.log" | sed 's/^/      /'
  else
    bad "38-c pty-wait 自检有失败"
    grep -a '✗' "$TMP/pty-wait-selftest.log" | head -10 | sed 's/^/      /'
    tail -3 "$TMP/pty-wait-selftest.log" | sed 's/^/      /'
  fi
else
  bad "38-c 缺 tests/lib/pty-wait.sh"
fi

# 38-d 静默回归钉（M65/D11，FAST 照跑）：交互路径不许再出现「打开前先读一次」的 awaited API，
# 且唯一带读取窗口判据的行为夹具还在。38-b（真 pty）只在完整门禁跑；这两条便宜钉保证有人把
# 「开行前先读一次」加回来、或把读取窗口断言删掉时 FAST 也会红。行为面的红侧在
# panel-flip-m54.sh 的 W-A（断掉无读取 → choices 变红）。
if [ -f "$SKILL_DIR/scripts/panel/src/App.tsx" ]; then
  if grep -qE '(^|[^A-Za-z])refreshSettings\(' "$SKILL_DIR/scripts/panel/src/App.tsx"; then
    bad "38-d 交互路径又出现 awaited 读取（App.tsx 调了 refreshSettings）"
  else
    ok "38-d 交互路径没有 awaited 读取（App.tsx 只在 settle 后用 refreshSettingsSoon）"
  fi
  assert_has "$SKILL_DIR/scripts/panel/src/App.tsx" "refreshSettingsSoon()" "38-d settle 之后只有后台重读 settings（refreshSettingsSoon）"
else
  bad "38-d 缺 scripts/panel/src/App.tsx"
fi
if [ -f "$SKILL_DIR/tests/panel-p21.sh" ]; then
  assert_has "$SKILL_DIR/tests/panel-p21.sh" "按键→帧之间零读取" "38-d choices 段还带着读取窗口判据（行为面在 38-b / W-A）"
  assert_has "$SKILL_DIR/tests/panel-p21.sh" "argv_reads" "38-d 读取窗口判据用 config list/__panel-data 的 argv 面"
else
  bad "38-d 缺 tests/panel-p21.sh"
fi

# 38-e P30 钉子（FAST 照跑）：pty 行为面（settings / groups / wheel 三个场景）在完整门禁里跑（38-f 就是
# 那个调用点），
# FAST 用三条便宜的**结构钉 + 红侧**保证有人把行为改回去时门禁也会红：
#   ① 字符串表的「schema 行第 10 列 token ⇄ group_<token> 标签」双向相等（删标签 / 加陈旧标签都红）；
#   ② 视图的分组只从**记录**读（layout.ts 没有类分组表、没有键→域表，标题按 token 查表）；
#   ③ 鼠标分支在设置视图里**消费**滚轮（在页面滚动之前 return —— 用户报的「滚轮偷偷滚页面」）。
# 红侧一律在 scratch 副本上翻转（同 28-a2 的模式），工作树一个字节不动。
P38E_LBL="$TMP/p38e-labels"; rm -rf "$P38E_LBL"
mkdir -p "$P38E_LBL/skills/teamsmith/scripts/panel" "$P38E_LBL/skills/teamsmith/scripts/lib"
cp -r "$SKILL_DIR/scripts/panel/src" "$P38E_LBL/skills/teamsmith/scripts/panel/src"
cp "$SKILL_DIR/scripts/lib/cmd-config.sh" "$P38E_LBL/skills/teamsmith/scripts/lib/"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P38E_LBL" >"$TMP/p38e-labels-green.log" 2>&1
if [ $? -eq 0 ] && grep -q 'contract-group labels' "$TMP/p38e-labels-green.log"; then
  ok "38-e 组标签：schema 行的 group token 与 zh/en 的 group_<token> 双向相等（$(grep -oE '[0-9]+ schema group tokens' "$TMP/p38e-labels-green.log" | head -1)）"
else
  bad "38-e 组标签：绿侧就红了"; tail -3 "$TMP/p38e-labels-green.log"
fi
sed -i '/^  group_workflow:/d' \
  "$P38E_LBL/skills/teamsmith/scripts/panel/src/strings/zh.ts" \
  "$P38E_LBL/skills/teamsmith/scripts/panel/src/strings/en.ts"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P38E_LBL" >"$TMP/p38e-labels-red.log" 2>&1
P38E_RC=$?
if [ "$P38E_RC" -ne 0 ] && grep -q 'group_workflow' "$TMP/p38e-labels-red.log"; then
  ok "38-e 翻转①：两张表都删掉 group_workflow → 断言非 0 且点名该 token"
else
  bad "38-e 翻转①：删掉的组标签没被抓住（rc=$P38E_RC）"; tail -3 "$TMP/p38e-labels-red.log"
fi
rm -rf "$P38E_LBL/skills/teamsmith/scripts/panel/src"
cp -r "$SKILL_DIR/scripts/panel/src" "$P38E_LBL/skills/teamsmith/scripts/panel/src"
sed -i "/^  settingsGroupUngrouped:/i\\  group_zzz: 'zzz'," \
  "$P38E_LBL/skills/teamsmith/scripts/panel/src/strings/zh.ts" \
  "$P38E_LBL/skills/teamsmith/scripts/panel/src/strings/en.ts"
"$JS_RUNNER" "$P28_TESTS/panel-strings.mjs" "$P38E_LBL" >"$TMP/p38e-labels-stale.log" 2>&1
P38E_RC=$?
if [ "$P38E_RC" -ne 0 ] && grep -q 'group_zzz' "$TMP/p38e-labels-stale.log"; then
  ok "38-e 翻转②：加一个没有 schema 行使用的 group_zzz → 断言非 0 且点名陈旧标签"
else
  bad "38-e 翻转②：陈旧的组标签没被抓住（rc=$P38E_RC）"; tail -3 "$TMP/p38e-labels-stale.log"
fi
# ② 视图分组只读记录：没有类分组表、没有键→域表，标题按 token 查表。
p38e_group_pin() { # <tree> → 0 = 分组只从记录读
  local f="$1/skills/teamsmith/scripts/panel/src/layout.ts"
  [ -f "$f" ] || return 1
  ! grep -qE 'settingsGroupApply|settingsGroupRestart|settingsGroupRefuse' "$f" &&
    grep -qE 'k\.group' "$f" &&
    grep -qF 'group_${token}' "$f"
}
# ③ 滚轮在设置视图里被消费（分派点必须早于页面滚动的分派点）。
p38e_wheel_pin() { # <tree> → 0 = 设置在页面前面消费滚轮
  local f="$1/skills/teamsmith/scripts/panel/src/App.tsx" a b
  [ -f "$f" ] || return 1
  a="$(grep -n 'scrollSettings(delta)' "$f" | head -1 | cut -d: -f1)"
  b="$(grep -n 'updateScroll((v) => v + delta)' "$f" | head -1 | cut -d: -f1)"
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]
}
P38E_SRC="$TMP/p38e-src"; rm -rf "$P38E_SRC"
mkdir -p "$P38E_SRC/skills/teamsmith/scripts/panel"
cp -r "$SKILL_DIR/scripts/panel/src" "$P38E_SRC/skills/teamsmith/scripts/panel/src"
if p38e_group_pin "$P38E_SRC"; then
  ok "38-e 视图分组：layout.ts 无类分组表、无键→域表（标题按 group_<token> 查，分组只读记录）"
else
  bad "38-e 视图分组：pin 在现树上就红了"
fi
printf '\nconst settingsGroupApply = 1\n' >> "$P38E_SRC/skills/teamsmith/scripts/panel/src/layout.ts"
if p38e_group_pin "$P38E_SRC"; then
  bad "38-e 翻转：把类分组表装回去 pin 居然还绿（钉失效）"
else
  ok "38-e 翻转：layout.ts 里出现 settingsGroupApply → pin 红"
fi
if p38e_wheel_pin "$P38E_SRC"; then
  ok "38-e 滚轮消费：设置视图的分支在页面滚动之前（scrollSettings 先于 updateScroll，不穿透）"
else
  bad "38-e 滚轮消费：pin 在现树上就红了"
fi
sed -i '/scrollSettings(delta)/d' "$P38E_SRC/skills/teamsmith/scripts/panel/src/App.tsx"
if p38e_wheel_pin "$P38E_SRC"; then
  bad "38-e 翻转：去掉滚轮消费 pin 还绿（钉失效）"
else
  ok "38-e 翻转：删掉 scrollSettings(delta) → pin 红（滚轮会落回页面滚动）"
fi

# 38-f P32 的修订面（FAST 下可见 SKIP）：panel-p21.sh 的 groups / settings / wheel 三个场景 ——
# 设置视图的 45/33/30/25 四档行高记账（卡片填满、rows+↑+↓ 对账、45 比 30 多 ≥8 行）、分组标题是
# 分节线且自己承担组间分隔、视图自己的滚轮窗口（一格一行/焦点不动/计数行/不穿透）。38-b 只跑
# choices；这三个场景此前没有任何调用点（P31 的 finding F1：design D7 与 38-e 的注释都宣称它们在
# 完整门禁里跑）。FAST 的跳过是**可见**的（fast_skip），提醒里带原因与耗时；完整门禁里这是硬断言。
if [ -f "$SKILL_DIR/tests/panel-p21.sh" ]; then
  if [ "$FAST" = "1" ]; then
    fast_skip "38-f·panel-p21-settings-groups-wheel" "panel-p21.sh groups/settings/wheel 要真 tmux 场地 + 真 bundle（慢段 ~2 分钟）"
  else
    live_mark
    bash "$SKILL_DIR/tests/panel-p21.sh" groups settings wheel >"$TMP/panel-p21-view.log" 2>&1
    p38rc=$?
    p38_verdict "38-f" "$TMP/panel-p21-view.log" "$p38rc" "panel-p21.sh groups/settings/wheel"
  fi
else
  bad "38-f 缺 tests/panel-p21.sh"
fi

# 38-g P48 的两条便宜钉（纯逻辑/自有子进程，**FAST 照跑**）：
#   ① 负载实验的安全规矩（verification#A load experiment signals only the processes it started）：
#      tests/load-experiment.sh --guard-test —— 自有目标可冻结可释放、TERM/INT 中途被杀不留 T、
#      非自有/模式形状/空/自身目标在发信号前即被拒（exit 2，目标状态不变）、私有临时根与 socket 名
#      互不相同。它只 spawn 自己的 sleep，不碰任何别人的进程。
#   ② 前提旋钮不得漏进真路径（panel#The project-settings pty fixture judges under a machine premise）：
#      panel-p21.sh 的 premise-only 模式（TEAM_P21_PREMISE_ONLY=1）—— 夹具开关关着时注入的读数
#      必须被忽略并打印，前提行必须带真 loadavg/真核数、不得出现注入值，且它不建 tmux、不判时长。
#      前置红面：把夹具里的忽略分支删掉 → ②变红；把 freeze 的归属检查删掉 → ①变红（报告里有）。
if [ -f "$SKILL_DIR/tests/load-experiment.sh" ]; then
  if bash "$SKILL_DIR/tests/load-experiment.sh" --guard-test >"$TMP/p48-load-guard.log" 2>&1; then
    ok "38-g① load-experiment.sh --guard-test 全绿（$(grep -a '== 结果 ==' "$TMP/p48-load-guard.log" | tail -1 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/.*== 结果 == //' | tr -s ' ')；只对自己 spawn 的进程发信号）"
  else
    bad "38-g① load-experiment.sh --guard-test 有失败"
    grep -a '✗' "$TMP/p48-load-guard.log" | head -6 | sed 's/^/      /'
  fi
else
  bad "38-g① 缺 tests/load-experiment.sh"
fi
if [ -f "$SKILL_DIR/tests/panel-p21.sh" ]; then
  P48_REAL_CORES="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || printf 0)"
  P48_REAL_LOAD="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || printf '?')"
  ( cd "$SKILL_DIR/.." && env -u TEAM_SMOKE_FIXTURE \
      TEAM_P21_PREMISE_PROBE_MS=999 TEAM_P21_PREMISE_LOAD_FACTOR=0.01 TEAM_P21_PREMISE_ONLY=1 \
      timeout 30 bash "$SKILL_DIR/tests/panel-p21.sh" choices ) >"$TMP/p48-premise-only.log" 2>&1
  p38po=$?
  if [ "$p38po" = "0" ]; then
    ok "38-g② premise-only 模式退出 0（不建 tmux、不判时长）"
  else
    bad "38-g② premise-only 模式退出 $p38po（期望 0）"
    tail -3 "$TMP/p48-premise-only.log" | sed 's/^/      /'
  fi
  for kv in 'TEAM_P21_PREMISE_PROBE_MS=999' 'TEAM_P21_PREMISE_LOAD_FACTOR=0.01'; do
    if grep -qF "忽略 $kv" "$TMP/p48-premise-only.log"; then
      ok "38-g② 注入的旋钮被忽略并打印：$kv"
    else
      bad "38-g② 没有看到「忽略 $kv」行"
    fi
  done
  if [ "$P48_REAL_CORES" -gt 0 ] && grep -qF "逻辑核 ${P48_REAL_CORES}" "$TMP/p48-premise-only.log" \
     && grep -qF "loadavg_1m ${P48_REAL_LOAD}" "$TMP/p48-premise-only.log"; then
    ok "38-g② 前提行是真读数（loadavg_1m ${P48_REAL_LOAD} · 逻辑核 ${P48_REAL_CORES}）"
  else
    bad "38-g② 前提行不是真读数（期望 loadavg_1m ${P48_REAL_LOAD}、逻辑核 ${P48_REAL_CORES}）"
    grep -a '前提' "$TMP/p48-premise-only.log" | head -2 | sed 's/^/      /'
  fi
  if grep -qF '代码无关探针 999ms' "$TMP/p48-premise-only.log"; then
    bad "38-g② 前提行里出现了注入的探针读数（旋钮漏进了真路径！）"
  else
    ok "38-g② 前提行里没有注入值"
  fi
  if grep -qE 'SKIP|✗' "$TMP/p48-premise-only.log"; then
    bad "38-g② premise-only 模式出现了 SKIP/失败行（它不该判任何东西）"
    grep -aE 'SKIP|✗' "$TMP/p48-premise-only.log" | head -3 | sed 's/^/      /'
  else
    ok "38-g② premise-only 模式没有判任何东西（无 SKIP、无 ✗）"
  fi
else
  bad "38-g② 缺 tests/panel-p21.sh"
fi
section "39 · npm CLI 与项目 skill 安装（P40：包装器 / 冲突表 / doctor 行）"
# headless 夹具（tests/install-shape.sh）——不依赖 tmux/真进程，FAST 照跑：它自己起临时仓库、
# 自己剥 TEAM_*/TMUX 身份，含五组翻转红侧（每组的绿侧用同一份判据在真实树上跑）。
if [ -f "$SKILL_DIR/tests/install-shape.sh" ]; then
  if bash "$SKILL_DIR/tests/install-shape.sh" >"$TMP/install-shape.log" 2>&1; then
    ok "39 install-shape.sh 全绿（$(grep -ac '✓' "$TMP/install-shape.log" || true) 条断言，含翻转绿/红两侧）"
    tail -1 "$TMP/install-shape.log" | sed 's/^/      /'
  else
    bad "39 install-shape.sh 有失败"
    grep -a '✗' "$TMP/install-shape.log" | head -10 | sed 's/^/      /'
    tail -2 "$TMP/install-shape.log" | sed 's/^/      /'
  fi
else
  bad "39 缺 tests/install-shape.sh"
fi

section "40 · 临时根纪律（P53：TMPDIR / owned 家族 / 泄漏断言 / lint）"
# ① lint：临时根必须是 ${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX（助手是唯一创建者）。
#    `TEAM_TMP_HYGIENE_FLIP=lint` 是门禁自己的红侧：把迁移后的 config-cli 夹具改回写死 /tmp
#    的旧模板 → 这一段必须变红、并点名 file:line（证明门禁真的挡得住回归）。
P53_FLIP="${TEAM_TMP_HYGIENE_FLIP:-}"
P53_LINT_DIR="$SKILL_DIR/tests"
mkdir -p "$TMP/lint-flip"
# 诱饵模板拼在变量里：否则 lint 会把自己这个 sed 的字面量当成一条 finding
P53_BAD_TMPL='/tmp/config-cli.XXXXXX'
sed "s|tmp=\"\$(tmp_root_create config-cli)\"|tmp=\"\$(mktemp -d $P53_BAD_TMPL)\"|" \
  "$SKILL_DIR/tests/config-cli.sh" >"$TMP/lint-flip/config-cli.sh"
[ "$P53_FLIP" = "lint" ] && P53_LINT_DIR="$TMP/lint-flip"
bash "$SKILL_DIR/tests/tmp-hygiene.sh" --lint --dir "$P53_LINT_DIR" >"$TMP/tmp-lint.log" 2>&1
P53_LINT_RC=$?
if [ "$P53_LINT_RC" = "0" ]; then
  ok "40 lint 干净：$(grep -a '检查了' "$TMP/tmp-lint.log" | tail -1)"
else
  bad "40 lint 有 finding（rc=$P53_LINT_RC）：$(grep -aE ':[0-9]+:' "$TMP/tmp-lint.log" | head -3 | tr '\n' ' ')"
fi
if [ "$P53_FLIP" != "lint" ]; then
  # 敏感性（不空转）：同一份「写死 /tmp」副本必须被抓到
  bash "$SKILL_DIR/tests/tmp-hygiene.sh" --lint --dir "$TMP/lint-flip" >"$TMP/tmp-lint-flip.log" 2>&1
  P53_FLIP_RC=$?
  if [ "$P53_FLIP_RC" = "1" ] && grep -qE 'config-cli\.sh:[0-9]+:' "$TMP/tmp-lint-flip.log"; then
    ok "40 lint 敏感性：写死 /tmp 的副本被点名 $(grep -oE 'config-cli\.sh:[0-9]+' "$TMP/tmp-lint-flip.log" | head -1)"
  else
    bad "40 lint 敏感性失败：写死 /tmp 的副本没被抓到（rc=$P53_FLIP_RC）"
  fi
fi

# ② 结束用量行 + 泄漏断言：台账里本轮创建的根必须都没了（本进程自己的根除外 —— 它由 EXIT
#    trap 的 cleanup 在断言之后回收，p53 的「一个都不留」正是冲着嵌套夹具泄漏去的）。
smoke_tmp_usage end
if [ "${TEAM_TMP_KEEP:-0}" = "1" ]; then
  ok "40 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏"
else
  P53_SURV=0
  while IFS=$'\t' read -r _p53p _p53pid _p53kind _p53kb _p53files; do
    [ -n "$_p53p" ] || continue
    [ "$_p53pid" = "$$" ] && continue          # 门禁自己的根：cleanup 负责
    P53_SURV=$((P53_SURV + 1))
    bad "40 临时根泄漏：$_p53p（$(smoke_human_kb "${_p53kb:-0}") · ${_p53files:-0} 文件 · kind=${_p53kind:-?} · pid=$_p53pid）"
  done < <(tmp_root_ledger_survivors)
  [ "$P53_SURV" -eq 0 ] && ok "40 泄漏断言：本轮创建的临时根一个都没留下（台账 $(basename "$(tmp_root_ledger)")）"
fi


# ---------------------------------------------------------------- 41. agent pane 留存与死 pane 席位（P55）
# OpenSpec change agent-pane-survivability 的验收夹具（真 tmux 段，FULL only）：
#   创建期：占位持窗 → remain-on-exit 设选项并读回 → respawn（harness 秒退也拿得到选项）；
#   死 pane：遗体留存 + 退出证据 + 画面可读；say 一个键不按、消息落收件箱、画面逐字节不变；
#   复用：dispatch/--fresh/resume 都先抓现场（state/dispatch-<agent>-pane-dead.txt）再替换；
#   四态：roster/status/digest/doctor/机器面（agents 块 pane/pane_exit；state 词表不变）；
#   噪音判据：close --keep-window 的遗体不算异常、不计 stopped；teardown 后恢复「无窗口」。
section "41 · pane 留存：死 pane 是座位状况，不是活座位（P55 / agent-pane-survivability）"

if [ "$FAST" = "1" ]; then
  fast_skip "41·p55-pane-留存" "真实 tmux + 真实派单夹具（占位/respawn/kill -9/遗体画面）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  P55_A="p55w"; P55_ID="T9.55"
  P55_WT="$REPO/.worktrees/$P55_A"
  P55_BRIEF="$REPO/.pi/team/state/$P55_ID-brief.md"
  printf '# %s · pane survivability probe\n\ntask: %s\nagent: %s\nchange: -\nanchor: none (infra) — P55 留存夹具\n' \
    "$P55_ID" "$P55_ID" "$P55_A" > "$P55_BRIEF"
  P55_BR="$(canon_branch "$P55_A" "$P55_ID")"
  git worktree add -b "$P55_BR" "$P55_WT" "$PROTECTED" >/dev/null 2>&1 || bad "§40 夹具：worktree 建不起来"
  cat > "$FAKE/p55-agent" <<'P55AG'
#!/usr/bin/env bash
echo P55-MARK-1; echo P55-MARK-2; echo P55-MARK-3; echo P55-MARK-4; echo P55-MARK-5
sleep 300
P55AG
  chmod +x "$FAKE/p55-agent"
  cat > "$FAKE/p55-agent-fast" <<'P55AG2'
#!/usr/bin/env bash
echo P55-FAST-DONE
sleep 2
exit 0
P55AG2
  chmod +x "$FAKE/p55-agent-fast"
  # 读面环境：四态夹具席位（p55live 在跑 / p55exit 已退出 / p55w 遗体 / p55none 无窗口）
  P55_RENV() { env TEAM_AGENTS="p55live p55exit p55w p55none" TEAM_AGENT_BIN="$FAKE/p55-agent" "$@"; }
  P55_KILL_PANE() { # <窗口名>：SIGKILL 该窗口 pane 的进程组（带 pgid 安全检查），并等 pane_dead=1
    local _w="$1" _pid _pgid _my i=0
    _pid="$(tmux list-panes -t "$SESSION:$_w" -F '#{pane_pid}' 2>/dev/null | head -1)"
    _pgid="$(ps -o pgid= -p "$_pid" 2>/dev/null | tr -d ' ')"
    _my="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"
    if [ -n "$_pgid" ] && [ "$_pgid" != "$_my" ] && [ "$_pgid" != "1" ]; then
      kill -9 -- -"$_pgid" 2>/dev/null || true
    else
      bad "§40 夹具：kill 前的 pgid 安全检查失败（$_w pid=$_pid pgid=$_pgid my=$_my）"
      return 1
    fi
    while [ "$i" -lt 25 ]; do
      [ "$(tmux list-panes -t "$SESSION:$_w" -F '#{pane_dead}' 2>/dev/null | head -1)" = "1" ] && return 0
      sleep 0.2; i=$((i + 1))
    done
    return 1
  }

  # ── ① 创建期：选项先于 harness，读回为证（1.1/1.2）─────────────────────────
  if env TEAM_AGENTS="dev verify $P55_A" TEAM_AGENT_CMD="$FAKE/p55-agent {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent" \
       TEAM_DISPATCH_ALIVE_SEC=0 \
       bash "$SKILL_DIR/scripts/team" dispatch "$P55_A" "$P55_ID" "$P55_BRIEF" >"$TMP/p55-dispatch-1.log" 2>&1
  then ok "P55 ①：派单成功"; else bad "P55 ①：派单失败"; fi
  assert_has "$TMP/p55-dispatch-1.log" "含启动校验" "P55 ①：启动证据（spawn 证明）照常"
  assert_eq "P55 ①：agent 窗口的 remain-on-exit 读回是 on（设了且读回）" \
    "$(tmux show-options -w -v -t "$SESSION:$P55_A" remain-on-exit 2>/dev/null)" "on"
  assert_eq "P55 ①：PM 窗口没有窗口级 remain-on-exit（D2：PM/pulse 窗口绝不设）" \
    "$(tmux show-options -w -v -t "$SESSION:pm" remain-on-exit 2>/dev/null)" ""
  P55_W=0
  while [ "$P55_W" -lt 30 ]; do
    tmux capture-pane -p -S - -t "$SESSION:$P55_A" 2>/dev/null | grep -q 'P55-MARK-5' && break
    sleep 0.3; P55_W=$((P55_W + 1))
  done
  tmux capture-pane -p -S - -t "$SESSION:$P55_A" 2>/dev/null > "$TMP/p55-pane-alive.txt" || true
  assert_has "$TMP/p55-pane-alive.txt" "P55-MARK-5" "P55 ①：agent 画面正常（marker 画上）"
  assert_eq "P55 ①：席位恰好一个窗口" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$P55_A")" "1"

  # ── ② SIGKILL 整个 pane 进程组 → 遗体（1.1 corpse / 3.1 dead）──────────────
  if P55_KILL_PANE "$P55_A"; then ok "P55 ②：SIGKILL 了 pane 进程组"; else bad "P55 ②：kill/等待遗体失败"; fi
  assert_eq "P55 ②：kill 之后窗口还在（pane_dead=1，遗体留存）" \
    "$(tmux list-panes -t "$SESSION:$P55_A" -F '#{pane_dead}' 2>/dev/null | head -1)" "1"
  assert_eq "P55 ②：退出证据 signal=9（不是退出码，是死因）" \
    "$(tmux list-panes -t "$SESSION:$P55_A" -F '#{pane_dead_signal}' 2>/dev/null | head -1)" "9"
  assert_eq "P55 ②：窗口没跟 pane 一起消失" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$P55_A")" "1"
  tmux capture-pane -p -S - -t "$SESSION:$P55_A" 2>/dev/null > "$TMP/p55-corpse.txt" || true
  assert_has "$TMP/p55-corpse.txt" "P55-MARK-5" \
    "P55 ②：遗体画面可读（-S - 含 scrollback；探针 P10：可见屏幕会丢最后一行）"

  # ── ③ say：死 pane 不是投递目标（2.2）──────────────────────────────────────
  P55_BEFORE="$(tmux capture-pane -p -S - -t "$SESSION:$P55_A" 2>/dev/null | cksum)"
  if env TEAM_AGENTS="dev verify $P55_A" bash "$SKILL_DIR/scripts/team" say "$P55_A" "P55 dead-pane probe" \
       >"$TMP/p55-say.log" 2>&1
  then ok "P55 ③：say 对死 pane 返回 0（换道收件箱）"; else bad "P55 ③：say 不应硬失败（应落收件箱）"; fi
  assert_has "$TMP/p55-say.log" "pane 已死（signal=9）" "P55 ③：输出点名座位已死 + 退出证据"
  assert_not "$TMP/p55-say.log" "已确认送达" "P55 ③：绝不报送达"
  assert_not "$TMP/p55-say.log" "said to" "P55 ③：绝不报送达（said to）"
  assert_has "$REPO/docs/team/inbox/$P55_A.md" "P55 dead-pane probe" "P55 ③：消息已写 durable 收件箱"
  assert_eq "P55 ③：遗体画面逐字节不变（一个键都没按 —— 探针 P5）" \
    "$(tmux capture-pane -p -S - -t "$SESSION:$P55_A" 2>/dev/null | cksum)" "$P55_BEFORE"

  # ── ④ 四态夹具 + 读面（3.1/3.2/3.3/3.4/3.5 + pending stopped）────────────────
  tmux new-window -d -c "$REPO" -n p55live -t "$SESSION" "$FAKE/p55-agent" 2>/dev/null || true
  tmux new-window -d -c "$REPO" -n p55exit -t "$SESSION" 2>/dev/null || true
  printf 'window=p55live\ntask=T9.56\n' > "$REPO/.pi/team/state/p55live.env"
  printf 'window=p55exit\n' > "$REPO/.pi/team/state/p55exit.env"
  printf 'window=p55none\n' > "$REPO/.pi/team/state/p55none.env"
  P55_W=0
  while [ "$P55_W" -lt 20 ]; do
    P55_RENV bash "$SKILL_DIR/scripts/team" roster 2>/dev/null | grep -q '在跑' && break
    sleep 0.3; P55_W=$((P55_W + 1))
  done
  P55_RENV bash "$SKILL_DIR/scripts/team" roster >"$TMP/p55-roster.log" 2>&1
  assert_match "$TMP/p55-roster.log" "^p55live +● .*在跑" "P55 ④：roster 四态 ① running（证明成立）"
  assert_match "$TMP/p55-roster.log" "^p55exit +○ .*已退出" "P55 ④：roster 四态 ② exited（窗口/pane 活着，没有 agent）"
  assert_match "$TMP/p55-roster.log" "^p55w +▲ 已死 signal=9" "P55 ④：roster 四态 ③ dead（行内带退出证据）"
  assert_match "$TMP/p55-roster.log" "^p55none +· 无窗口" "P55 ④：roster 四态 ④ absent"
  assert_has "$TMP/p55-roster.log" "▲ pane 已死" "P55 ④：图例说全四态（含死 pane 的含义与现场入口）"
  # 机器面：state 词表不变（running/exited/absent 三态），死 pane 落在 pane/pane_exit 键上
  P55_RENV bash "$SKILL_DIR/scripts/team" __panel-data --block agents >"$TMP/p55-agents.json" 2>/dev/null
  if python3 - "$TMP/p55-agents.json" >"$TMP/p55-agents-check.txt" 2>&1 <<'P55PY'
import json, sys
data = json.load(open(sys.argv[1]))
agents = {a["name"]: a for a in (data["agents"] if isinstance(data, dict) else data)}
def fail(m): print("机器面断言失败：" + m); sys.exit(1)
w = agents.get("p55w") or fail("缺 p55w")
w.get("state") != "running" or fail("尸体以 running 出现（绝不允许）")
w.get("state") == "exited" or fail("遗体 state 不是 exited（词表不变）：%r" % w.get("state"))
w.get("pane") == "dead" or fail("p55w pane≠dead：%r" % w.get("pane"))
w.get("pane_exit") == "signal=9" or fail("p55w pane_exit≠signal=9：%r" % w.get("pane_exit"))
l = agents.get("p55live") or fail("缺 p55live")
(l.get("state") == "running" and l.get("pane") == "live") or fail("p55live 不是 running+live：%r" % l)
e = agents.get("p55exit") or fail("缺 p55exit")
(e.get("state") == "exited" and e.get("pane") == "live") or fail("p55exit 不是 exited+live：%r" % e)
n = agents.get("p55none") or fail("缺 p55none")
n.get("state") == "absent" or fail("p55none 不是 absent")
"pane" in n and fail("p55none 带了 pane 键（无窗口不该有）")
P55PY
  then ok "P55 ④：机器面 agents 块（state 词表不变 + pane/pane_exit；尸体绝不 running）"
  else bad "P55 ④：机器面断言失败"; sed 's/^/    /' "$TMP/p55-agents-check.txt"; fi
  # status <ID>：席位状况 + 退出证据 + 现场块（恰好 N 行）；活席位无记录 → 无现场块
  env TEAM_AGENTS="p55live p55exit p55w p55none" TEAM_AGENT_BIN="$FAKE/p55-agent" TEAM_AGENT_SCENE_LINES=2 \
    bash "$SKILL_DIR/scripts/team" status "$P55_ID" >"$TMP/p55-status.log" 2>&1
  assert_has "$TMP/p55-status.log" "座位 $P55_A" "P55 ④：status 点名该任务登记的席位"
  assert_has "$TMP/p55-status.log" "pane 已死" "P55 ④：status 印席位状况（dead）"
  assert_has "$TMP/p55-status.log" "signal=9" "P55 ④：status 带退出证据"
  assert_has "$TMP/p55-status.log" "来源：" "P55 ④：现场块标注来源"
  assert_has "$TMP/p55-status.log" "记录时间：" "P55 ④：现场块标注记录时间"
  assert_has "$TMP/p55-status.log" "P55-MARK" "P55 ④：现场块含 marker 行"
  assert_eq "P55 ④：TEAM_AGENT_SCENE_LINES=2 → 恰好两行现场" \
    "$(grep -c '^    | ' "$TMP/p55-status.log")" "2"
  env TEAM_AGENTS="p55live p55exit p55w p55none" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" status T9.56 >"$TMP/p55-status-live.log" 2>&1
  assert_has "$TMP/p55-status-live.log" "座位 p55live" "P55 ④：活席位任务的 status 也印席位状况"
  assert_not "$TMP/p55-status-live.log" "现场（来源" "P55 ④：活席位且无任何死亡/退出记录 → 不印现场块"
  # digest / doctor
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" digest >"$TMP/p55-digest.log" 2>&1
  assert_has "$TMP/p55-digest.log" "死 pane 席位" "P55 ④：digest 点名死 pane 席位"
  assert_has "$TMP/p55-digest.log" "! $P55_A pane 已死（signal=9）" "P55 ④：digest 行带退出证据（任务未结束 = 异常）"
  assert_has "$TMP/p55-digest.log" "$P55_ID" "P55 ④：digest 行带登记任务"
  # P79（P69 的 F1）：段号卫生 —— change 归组保留 [6]（12f 的 F_HDRS_EXPECTED 钉着它），
  # 死 pane 段顺延 [7]；全表段号逐行唯一，唯一豁免是历史 [5]×2（[5] 任务板 / [5] 建议：40bbad6a
  # 把任务板从 [4] 改到 [5] 时留下的既有重复，按 P79 裁定不顺手改无关段 —— 见 P79 报告）。
  assert_has "$TMP/p55-digest.log" \
    "[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）" \
    "P79：死 pane 段是 [7]，且只有段号变（正文逐字节同 P55）"
  P79_NUMS="$(grep -oE '^\[[0-9]+\]' "$TMP/p55-digest.log" | tr -d '[]' | paste -sd' ' -)"
  P79_DUPS="$(printf '%s\n' "$P79_NUMS" | tr ' ' '\n' | sort -n | uniq -d | paste -sd' ' -)"
  assert_eq "P79：digest 段号逐行唯一（唯一豁免：历史 [5]×2）" "$P79_DUPS" "5"
  assert_eq "P79：段号按序 [1]–[7]、[5] 历史重复成对" "$P79_NUMS" "1 2 3 4 5 5 6 7"
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" doctor >"$TMP/p55-doctor.log" 2>&1 || true
  assert_has "$TMP/p55-doctor.log" "死 pane 席位 $P55_A" "P55 ④：doctor 一条告警点名死席位"
  assert_has "$TMP/p55-doctor.log" "signal=9" "P55 ④：doctor 告警带退出证据"
  assert_has "$TMP/p55-doctor.log" "status $P55_ID" "P55 ④：doctor 告警给现场入口（team status <ID>）"
  env TEAM_AGENTS="p55live" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" doctor >"$TMP/p55-doctor-alive.log" 2>&1 || true
  assert_not "$TMP/p55-doctor-alive.log" "死 pane 席位" "P55 ④：全都活着时 doctor 不吭声（否则静默=假阴性藏身处）"
  # pending 计数：登记任务未结束 + 死 pane → stopped 算它
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" __panel-data --block pending >"$TMP/p55-pending.json" 2>/dev/null
  P55_STOPPED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["stopped"])' "$TMP/p55-pending.json" 2>/dev/null || echo '?')"
  assert_eq "P55 ④：pending 的 stopped 计入「任务未结束 + 死 pane」的席位" "$P55_STOPPED" "1"
  # 只读纪律（3.5）：这些面不许写 state（内容与时间戳都不许动）
  P55_FP0="$(state_fp)"
  P55_RENV bash "$SKILL_DIR/scripts/team" roster >/dev/null 2>&1
  P55_RENV bash "$SKILL_DIR/scripts/team" __panel-data --block agents >/dev/null 2>&1
  env TEAM_AGENTS="$P55_A" bash "$SKILL_DIR/scripts/team" status "$P55_ID" >/dev/null 2>&1
  env TEAM_AGENTS="$P55_A" bash "$SKILL_DIR/scripts/team" digest >/dev/null 2>&1
  env TEAM_AGENTS="$P55_A" bash "$SKILL_DIR/scripts/team" doctor >/dev/null 2>&1 || true
  P55_FP1="$(state_fp)"
  assert_eq "P55 ④：roster/status/digest/doctor/机器面读取后 state 指纹逐字节不变" "$P55_FP1" "$P55_FP0"

  # ── ⑤ 复用 ×3：dispatch / --fresh / resume 都先抓现场再替换（2.1/2.3）─────────
  P55_REUSE_CHECK() { # <轮名> <日志>：三轮复用共用的断言
    local rn="$1" lg="$2" f="$REPO/.pi/team/state/dispatch-$P55_A-pane-dead.txt"
    assert_has "$lg" "上一个 pane 已死（signal=9）" "P55 ⑤$rn：复用消息点名「上一个 pane 已死」+ 证据"
    assert_not "$lg" "旧回合会被打断" "P55 ⑤$rn：死 pane 的复用不再用「打断」措辞"
    assert_has "$lg" "含启动校验" "P55 ⑤$rn：新一轮的启动证明照常（spawn nonce）"
    assert_eq "P55 ⑤$rn：替换后恰好一个窗口" \
      "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$P55_A")" "1"
    assert_eq "P55 ⑤$rn：新窗口仍带 remain-on-exit on" \
      "$(tmux show-options -w -v -t "$SESSION:$P55_A" remain-on-exit 2>/dev/null)" "on"
    assert_has "$f" "seat: $P55_A" "P55 ⑤$rn：现场文件记了座位"
    assert_has "$f" "exit: signal=9" "P55 ⑤$rn：现场文件记了退出证据"
    assert_match "$f" "^dead_time: .+" "P55 ⑤$rn：现场文件记了死亡时刻"
    assert_has "$f" "P55-MARK-5" "P55 ⑤$rn：现场文件的画面含 marker"
    assert_eq "P55 ⑤$rn：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行" \
      "$(sed -n '/^--- scene ---/,$p' "$f" | tail -n +2 | wc -l | tr -d ' ')" "3"
    if [ -s "$REPO/.pi/team/state/dispatch-$P55_A.exit" ]; then
      bad "P55 ⑤$rn：上一轮的 .exit 残留被当成了这一轮的退出（stale 证据）"
    else
      ok "P55 ⑤$rn：上一轮的 .exit 不冒充这一轮的退出（本轮 agent 在跑、无 .exit）"
    fi
  }
  if env TEAM_AGENTS="dev verify $P55_A" TEAM_AGENT_CMD="$FAKE/p55-agent {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent" \
       TEAM_DISPATCH_ALIVE_SEC=0 TEAM_AGENT_SCENE_LINES=3 \
       bash "$SKILL_DIR/scripts/team" dispatch "$P55_A" "$P55_ID" "$P55_BRIEF" >"$TMP/p55-reuse-1.log" 2>&1
  then ok "P55 ⑤A：复用 dispatch 成功"; else bad "P55 ⑤A：复用 dispatch 失败"; fi
  P55_REUSE_CHECK "A·dispatch" "$TMP/p55-reuse-1.log"
  P55_KILL_PANE "$P55_A" || bad "P55 ⑤B 前置：第二轮 kill 没等到遗体"
  if env TEAM_AGENTS="dev verify $P55_A" TEAM_AGENT_CMD="$FAKE/p55-agent {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent" \
       TEAM_DISPATCH_ALIVE_SEC=0 TEAM_AGENT_SCENE_LINES=3 \
       bash "$SKILL_DIR/scripts/team" dispatch "$P55_A" "$P55_ID" "$P55_BRIEF" --fresh >"$TMP/p55-reuse-2.log" 2>&1
  then ok "P55 ⑤B：--fresh 复用成功"; else bad "P55 ⑤B：--fresh 复用失败"; fi
  P55_REUSE_CHECK "B·--fresh" "$TMP/p55-reuse-2.log"
  P55_KILL_PANE "$P55_A" || bad "P55 ⑤C 前置：第三轮 kill 没等到遗体"
  if env TEAM_AGENTS="dev verify $P55_A" TEAM_AGENT_CMD="$FAKE/p55-agent {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent" \
       TEAM_DISPATCH_ALIVE_SEC=0 TEAM_AGENT_SCENE_LINES=3 \
       bash "$SKILL_DIR/scripts/team" resume --agent "$P55_A" >"$TMP/p55-reuse-3.log" 2>&1
  then ok "P55 ⑤C：resume 复用成功"; else bad "P55 ⑤C：resume 复用失败"; fi
  P55_REUSE_CHECK "C·resume" "$TMP/p55-reuse-3.log"

  # ── ⑥ 正常退出照旧是「已退出」（1.3）：agent 退 0 → pane 活着 → 状态/复用原义 ──
  P55_Z="p55z"; P55_ZID="T9.57"; P55_ZWT="$REPO/.worktrees/$P55_Z"
  P55_ZBRIEF="$REPO/.pi/team/state/$P55_ZID-brief.md"
  printf '# %s · pane survivability fast-exit\n\ntask: %s\nagent: %s\nchange: -\nanchor: none (infra) — P55 留存夹具\n' \
    "$P55_ZID" "$P55_ZID" "$P55_Z" > "$P55_ZBRIEF"
  git worktree add -b "$(canon_branch "$P55_Z" "$P55_ZID")" "$P55_ZWT" "$PROTECTED" >/dev/null 2>&1 \
    || bad "§40 夹具：p55z worktree 建不起来"
  if env TEAM_AGENTS="dev verify $P55_Z" TEAM_AGENT_CMD="$FAKE/p55-agent-fast {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent-fast" \
       TEAM_DISPATCH_ALIVE_SEC=0 \
       bash "$SKILL_DIR/scripts/team" dispatch "$P55_Z" "$P55_ZID" "$P55_ZBRIEF" >"$TMP/p55z-dispatch.log" 2>&1
  then ok "P55 ⑥：短命 agent 派单成功"; else bad "P55 ⑥：短命 agent 派单失败"; fi
  P55_W=0
  while [ "$P55_W" -lt 20 ]; do
    [ -s "$REPO/.pi/team/state/dispatch-$P55_Z.exit" ] && break
    sleep 0.5; P55_W=$((P55_W + 1))
  done
  assert_eq "P55 ⑥：正常退出后 pane 活着（pane_dead=0 —— harness exec 回 shell）" \
    "$(tmux list-panes -t "$SESSION:$P55_Z" -F '#{pane_dead}' 2>/dev/null | head -1)" "0"
  env TEAM_AGENTS="$P55_Z" TEAM_AGENT_BIN="$FAKE/p55-agent-fast" \
    bash "$SKILL_DIR/scripts/team" roster >"$TMP/p55z-roster.log" 2>&1
  assert_has "$TMP/p55z-roster.log" "已退出" "P55 ⑥：正常退出的席位 = 「已退出」（语义原样）"
  grep -E "^$P55_Z " "$TMP/p55z-roster.log" > "$TMP/p55z-row.txt"
  assert_not "$TMP/p55z-row.txt" "▲" "P55 ⑥：正常退出绝不显示成死 pane（限定席位行；图例恒有 ▲）"
  if env TEAM_AGENTS="dev verify $P55_Z" TEAM_AGENT_CMD="$FAKE/p55-agent-fast {cwd}" TEAM_AGENT_BIN="$FAKE/p55-agent-fast" \
       TEAM_DISPATCH_ALIVE_SEC=0 \
       bash "$SKILL_DIR/scripts/team" resume --agent "$P55_Z" >"$TMP/p55z-resume.log" 2>&1
  then ok "P55 ⑥：exited 席位 resume 照常"; else bad "P55 ⑥：exited 席位 resume 失败"; fi
  assert_eq "P55 ⑥：resume 后恰好一个窗口" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$P55_Z")" "1"

  # ── ⑦ 噪音判据（3.6）：close --keep-window 的遗体不算异常、不计 stopped ──────
  P55_KILL_PANE "$P55_A" || bad "P55 ⑦ 前置：kill 没等到遗体"
  printf '| %s | pane survivability probe | %s | - | - | wip |\n' "$P55_ID" "$P55_A" >> "$REPO/docs/team/BOARD.md"
  if env TEAM_AGENTS="dev verify $P55_A" bash "$SKILL_DIR/scripts/team" close "$P55_ID" --status blocked --keep-window \
       >"$TMP/p55-close.log" 2>&1
  then ok "P55 ⑦：close --keep-window 成功（任务收尾、窗口留下）"; else bad "P55 ⑦：close --keep-window 失败"; fi
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" digest >"$TMP/p55-digest-closed.log" 2>&1
  assert_has "$TMP/p55-digest-closed.log" "· $P55_A pane 已死（signal=9）· 无登记任务" \
    "P55 ⑦：digest 仍点名遗体席位，但标明无登记任务（刻意保留）"
  assert_not "$TMP/p55-digest-closed.log" "! $P55_A" "P55 ⑦：已收尾的遗体不作为异常上报警叹号"
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" doctor >"$TMP/p55-doctor-closed.log" 2>&1 || true
  assert_not "$TMP/p55-doctor-closed.log" "死 pane 席位" "P55 ⑦：doctor 对已收尾的遗体不吭声"
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" __panel-data --block pending >"$TMP/p55-pending-closed.json" 2>/dev/null
  P55_STOPPED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["stopped"])' "$TMP/p55-pending-closed.json" 2>/dev/null || echo '?')"
  assert_eq "P55 ⑦：pending 的 stopped 不计已收尾的遗体" "$P55_STOPPED" "0"
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" roster >"$TMP/p55-roster-closed.log" 2>&1
  assert_has "$TMP/p55-roster-closed.log" "▲ 已死 signal=9" "P55 ⑦：roster 仍如实显示遗体（诚实 ≠ 异常）"

  # ── ⑧ teardown：遗体可拆（探针 P6），拆完恢复「无窗口」───────────────────────
  if env TEAM_AGENTS="dev verify $P55_A" bash "$SKILL_DIR/scripts/team" teardown --agent "$P55_A" \
       >"$TMP/p55-teardown.log" 2>&1
  then ok "P55 ⑧：teardown 拆掉遗体窗口"; else bad "P55 ⑧：teardown 失败"; fi
  P55_W=0
  while [ "$P55_W" -lt 25 ]; do
    tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$P55_A" || break
    sleep 0.2; P55_W=$((P55_W + 1))
  done
  assert_eq "P55 ⑧：teardown 后窗口真的没了" \
    "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$P55_A")" "0"
  env TEAM_AGENTS="$P55_A" TEAM_AGENT_BIN="$FAKE/p55-agent" \
    bash "$SKILL_DIR/scripts/team" roster >"$TMP/p55-roster-torn.log" 2>&1
  assert_has "$TMP/p55-roster-torn.log" "无窗口" "P55 ⑧：拆完后席位恢复「无窗口」"
  grep -E "^$P55_A " "$TMP/p55-roster-torn.log" > "$TMP/p55-row-torn.txt"
  assert_not "$TMP/p55-row-torn.txt" "▲" "P55 ⑧：拆完后席位行不再显示死 pane（限定席位行；图例恒有 ▲）"

  # ── 清场：夹具席位与窗口一个不留给后面的段落 ────────────────────────────────
  tmux kill-window -t "$SESSION:p55live" 2>/dev/null || true
  tmux kill-window -t "$SESSION:p55exit" 2>/dev/null || true
  tmux kill-window -t "$SESSION:$P55_Z" 2>/dev/null || true
  rm -f "$REPO/.pi/team/state/p55live.env" "$REPO/.pi/team/state/p55exit.env" "$REPO/.pi/team/state/p55none.env" \
        "$REPO/.pi/team/state/$P55_A.env" "$REPO/.pi/team/state/$P55_Z.env" \
        "$REPO/.pi/team/state/$P55_ID-brief.md" "$REPO/.pi/team/state/$P55_ZID-brief.md" \
        "$REPO/.pi/team/state/dispatch-$P55_A"* "$REPO/.pi/team/state/dispatch-$P55_Z"* 2>/dev/null || true
  git worktree remove --force "$P55_WT" 2>/dev/null || true
  git worktree remove --force "$P55_ZWT" 2>/dev/null || true
  git branch -D "$P55_BR" >/dev/null 2>&1 || true
  sed -i "/^| $P55_ID |/d" "$REPO/docs/team/BOARD.md" 2>/dev/null || true
else
  cond_skip "41·p55-pane-留存" "无 tmux"
fi

# ---------------------------------------------------------------- 42. P67 单行草稿判定（0.87.0 的边框邻行）
section "42 · P67 输入框判据：0.87.0 的边框邻行按内容读（光标锚定 + 状态行形状才排除）"
# 现场（P61 的 F1；提案 = one-line-draft-judgement，design §1–§4）：0.85.1 把框自带状态行画在
# **紧贴下边框那一行**（OFFSET==1），老实现无条件排除它是对的；0.87.0 把状态行移到下边框**下面**，
# 边框邻行成了**单行草稿**所在 —— 老实现把框读成空，就绪门会放行并把 payload 打进人的草稿。
# 新规则：边框邻行是内容，**除非**「光标不在其上」且「文本匹配实测状态行形状」两条同时成立。
# 提取只有一份实现 `_team_box_text_of_frame`（`team_input_box_text`、`box-judge.sh` 的帧判定与本节
# 探针都走它）。红侧不靠产品开关：把 `_team_box_row_is_chrome` 影子成 `return 0`（= 老槽位排除）
# 复现旧判定。本节两个方向都跑：绿 = 真草稿读得出、红 = 影子后翻回 EMPTY。
P67_FRAMES="$SKILL_DIR/tests/frames"
P67_ONE="$P67_FRAMES/pi-0.87.0-one-line-draft.txt"
P67_HALF="$P67_FRAMES/pi-0.87.0-draft-half-sentence.txt"
P67_EMPTY="$P67_FRAMES/pi-0.87.0-empty-box.txt"
P67_0851="$P67_FRAMES/pi-0.85.1-update-banner.txt"
P67_TRUST="$P67_FRAMES/pi-0.87.0-project-trust-prompt.txt"
assert_file "$P67_ONE" "P67：0.87.0 单行草稿真帧（P61 15b 逐字节拷贝）在 tests/frames/"
assert_file "$P67_HALF" "P67：0.87.0 单行草稿真帧（P61 10c）在 tests/frames/"
assert_file "$P67_EMPTY" "P67：0.87.0 空闲空框真帧（P61 10c 对照）在 tests/frames/"

# 纯帧探针：生产提取 + 帧级判定（不开 tmux）；shadow=1 时谓词影子成老槽位排除
P67_PROBE="$TMP/p67-frame-probe.sh"
cat > "$P67_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <帧文件> <光标行> [shadow] → box_text=[...] / box_nows=[...] / verdict=...
set -u
SKILL_DIR="$1"; FR="$2"; CY="$3"; SHADOW="${4:-0}"
. "$SKILL_DIR/scripts/lib/common.sh"; . "$SKILL_DIR/scripts/lib/outbox.sh"
. "$SKILL_DIR/tests/lib/box-judge.sh"   # P67：帧级判定（team_box_frame_verdict）在共享库里
[ "$SHADOW" = "1" ] && _team_box_row_is_chrome() { return 0; }   # 红侧：老的槽位排除
text="$(_team_box_text_of_frame "$CY" < "$FR" 2>/dev/null || true)"
printf 'box_text=[%s]\n' "$text"
printf 'box_nows=[%s]\n' "$(printf '%s' "$text" | tr -d '[:space:]')"
if v="$(team_box_frame_verdict "$CY" < "$FR" 2>/dev/null)"; then printf 'verdict=%s rc=0\n' "$v"
else printf 'verdict=%s rc=1\n' "$v"; fi
EOS
chmod +x "$P67_PROBE"
p67_probe() { ( bash "$P67_PROBE" "$SKILL_DIR" "$1" "$2" "${3:-0}" 2>&1 ); }
p67_frame_mode() { # <帧> <cy> [shadow] → pm-box-real.sh --frame 的输出（同一份共享判据）
  if [ "${3:-0}" = "1" ]; then
    M24_SHADOW_CHROME=1 bash "$SKILL_DIR/tests/pm-box-real.sh" --frame "$1" --cursor "$2" 2>&1
  else
    bash "$SKILL_DIR/tests/pm-box-real.sh" --frame "$1" --cursor "$2" 2>&1
  fi
}
p67_field() { printf '%s\n' "$2" | sed -n "s/^$1=\[\(.*\)\]$/\1/p"; }

# ── 绿侧：0.87.0 单行草稿 = 内容；0.87.0 空框与 0.85.1 状态行帧 = 空 ──────────────────────
P67_ONE_OUT="$(p67_probe "$P67_ONE" 26)"
assert_has_echo "$P67_ONE_OUT" "box_text=[HUMAN-ONE-LINE-DRAFT]" "P67 绿侧：15b 真帧的框文本就是那行草稿"
assert_has_echo "$P67_ONE_OUT" "verdict=idle-read=NOT-EMPTY rc=1" "P67 绿侧：15b 真帧判 NOT-EMPTY（不再是 EMPTY）"
P67_HALF_OUT="$(p67_probe "$P67_HALF" 26)"
assert_has_echo "$P67_HALF_OUT" "box_text=[DRAFT-p61-half-sentence]" "P67 绿侧：10c 单行草稿真帧读得出草稿"
assert_has_echo "$P67_HALF_OUT" "idle-read=NOT-EMPTY" "P67 绿侧：10c 单行草稿真帧判 NOT-EMPTY"
P67_EMPTY_OUT="$(p67_probe "$P67_EMPTY" 26)"
assert_has_echo "$P67_EMPTY_OUT" "box_text=[]" "P67 对照：0.87.0 空闲空框的框文本为空"
assert_has_echo "$P67_EMPTY_OUT" "verdict=idle-read=EMPTY rc=0" "P67 对照：0.87.0 空闲空框仍判 EMPTY"
P67_0851_OUT="$(p67_probe "$P67_0851" 26)"
assert_has_echo "$P67_0851_OUT" "box_text=[]" "P67 回退闸：0.85.1 真帧的状态行仍被排除（框文本空）"
assert_has_echo "$P67_0851_OUT" "verdict=idle-read=EMPTY rc=0" "P67 回退闸：0.85.1 真帧仍判 EMPTY（没有回退到「任何文本都忙」）"

# ── 红侧（可证伪）：谓词影子成「一律 chrome」→ 草稿帧翻回 EMPTY，0.85.1 保持 EMPTY ────────
P67_ONE_RED="$(p67_probe "$P67_ONE" 26 1)"
assert_has_echo "$P67_ONE_RED" "box_text=[]" "P67 红侧：影子后 15b 真帧的框文本又空了（= 老槽位排除）"
assert_has_echo "$P67_ONE_RED" "verdict=idle-read=EMPTY rc=0" "P67 红侧：影子后 15b 真帧翻回 EMPTY（判据确实被这条谓词守着）"
P67_HALF_RED="$(p67_probe "$P67_HALF" 26 1)"
assert_has_echo "$P67_HALF_RED" "verdict=idle-read=EMPTY rc=0" "P67 红侧：10c 单行草稿帧同样翻回 EMPTY"
P67_0851_RED="$(p67_probe "$P67_0851" 26 1)"
assert_has_echo "$P67_0851_RED" "verdict=idle-read=EMPTY rc=0" "P67 红侧：0.85.1 帧在两个方向都 EMPTY（它本来就靠形状排除，影子不改变它）"

# ── 同源：生产提取 vs pm-box-real.sh --frame（绿/红两个方向）text 与 verdict 逐字一致 ──────
P67_MODE_ONE="$(p67_frame_mode "$P67_ONE" 26)"; P67_MODE_ONE_RC=$?
assert_eq "P67 同源①：帧模式对 15b 真帧 rc=1（NOT-EMPTY）" "$P67_MODE_ONE_RC" "1"
assert_eq "P67 同源①：两条路径的框文本逐字一致（15b）" \
  "$(p67_field box_text "$P67_MODE_ONE")" "$(p67_field box_text "$P67_ONE_OUT")"
assert_has_echo "$P67_MODE_ONE" "idle-read=NOT-EMPTY" "P67 同源①：帧模式的判定与生产提取同向（15b）"
P67_MODE_EMPTY="$(p67_frame_mode "$P67_EMPTY" 26)"; P67_MODE_EMPTY_RC=$?
assert_eq "P67 同源②：帧模式对 0.87.0 空框 rc=0" "$P67_MODE_EMPTY_RC" "0"
assert_eq "P67 同源②：两条路径的框文本逐字一致（空框）" \
  "$(p67_field box_text "$P67_MODE_EMPTY")" "$(p67_field box_text "$P67_EMPTY_OUT")"
P67_MODE_0851="$(p67_frame_mode "$P67_0851" 26)"; P67_MODE_0851_RC=$?
assert_eq "P67 同源③：帧模式对 0.85.1 真帧 rc=0" "$P67_MODE_0851_RC" "0"
assert_eq "P67 同源③：两条路径的框文本逐字一致（0.85.1）" \
  "$(p67_field box_text "$P67_MODE_0851")" "$(p67_field box_text "$P67_0851_OUT")"
P67_MODE_ONE_RED="$(p67_frame_mode "$P67_ONE" 26 1)"
assert_has_echo "$P67_MODE_ONE_RED" "idle-read=EMPTY" "P67 同源④（红侧）：pm-box-real.sh --frame 走同一条影子路径，草稿帧也翻回 EMPTY"
assert_eq "P67 同源④（红侧）：影子方向两条路径的框文本一致（都空）" \
  "$(p67_field box_text "$P67_MODE_ONE_RED")" "$(p67_field box_text "$P67_ONE_RED")"
# 覆盖层优先权不许被这条判据动到（design §5：只删排除、不加排除）
P67_MODE_TRUST="$(p67_frame_mode "$P67_TRUST" 16)"; P67_MODE_TRUST_RC=$?
assert_eq "P67 覆盖层：信任弹窗帧照旧判定覆盖层（rc=0）" "$P67_MODE_TRUST_RC" "0"
assert_has_echo "$P67_MODE_TRUST" "overlay=trust-prompt" "P67 覆盖层：overlay 的优先权没变"

# ── 2.5 的三种形状按帧钉住（**合成帧在这里明说是合成的**；P61 的 15c 只记了判定，没存多行帧）──
P67_SYN="$TMP/p67-frames"; rm -rf "$P67_SYN"; mkdir -p "$P67_SYN"
p67_rule() { printf '─%.0s' $(seq 1 "${1:-60}"); printf '\n'; }
# a1（真帧）：把光标移到 0.85.1 的状态行上 → 形状不能覆盖光标，该行读作内容
P67_0851_CUR="$(p67_probe "$P67_0851" 28)"
assert_has_echo "$P67_0851_CUR" "box_nows=[deepseek-flashDeepseekmax]" "P67 场景 a1：0.85.1 真帧光标落在状态行上 → 该行是内容"
assert_has_echo "$P67_0851_CUR" "verdict=idle-read=NOT-EMPTY rc=1" "P67 场景 a1：光标踩在状态行形状行上 → 判忙"
# a2（合成帧）：边框邻行 = ` k3  Kimi Coding  max`（状态行形状）且光标就在其上 → 内容
{ p67_rule 60; printf '\n'; printf ' k3  Kimi Coding  max\n'; p67_rule 60; printf ' footer\n'; } > "$P67_SYN/status-row-cursor.txt"
P67_A2="$(p67_probe "$P67_SYN/status-row-cursor.txt" 3)"
assert_has_echo "$P67_A2" "box_nows=[k3KimiCodingmax]" "P67 场景 a2（合成帧）：光标踩在状态行形状行上 → 该行是内容"
assert_has_echo "$P67_A2" "verdict=idle-read=NOT-EMPTY rc=1" "P67 场景 a2（合成帧）：同上 → 判忙"
# b（合成帧）：0.87.0 的 V7-F1 形状 —— 光标在空白行、唯一文字行在边框邻行（形状不认识它）
{ p67_rule 60; printf '\n'; printf ' foo\n'; p67_rule 60; printf ' footer\n'; } > "$P67_SYN/v7f1-below-cursor.txt"
P67_B="$(p67_probe "$P67_SYN/v7f1-below-cursor.txt" 2)"
assert_has_echo "$P67_B" "box_nows=[foo]" "P67 场景 b（合成帧）：V7-F1 形状（光标上方空白、文字在边框邻行）→ 文字是内容"
assert_has_echo "$P67_B" "verdict=idle-read=NOT-EMPTY rc=1" "P67 场景 b（合成帧）：判忙，草稿不会被盖掉"
# c（合成帧）：0.87.0 三行草稿（光标在最后一行 = 边框邻行）→ 两个方向都忙
{ p67_rule 60; printf ' MULTI-LINE one\n'; printf ' MULTI-LINE two\n'; printf ' MULTI-LINE three\n'; p67_rule 60; printf ' footer\n'; } > "$P67_SYN/multi-line-draft.txt"
P67_C="$(p67_probe "$P67_SYN/multi-line-draft.txt" 4)"
P67_C_RED="$(p67_probe "$P67_SYN/multi-line-draft.txt" 4 1)"
assert_has_echo "$P67_C" "box_nows=[MULTI-LINEoneMULTI-LINEtwoMULTI-LINEthree]" "P67 场景 c（合成帧）：三行草稿全部读出"
assert_has_echo "$P67_C" "verdict=idle-read=NOT-EMPTY rc=1" "P67 场景 c（合成帧）：判忙"
assert_has_echo "$P67_C_RED" "verdict=idle-read=NOT-EMPTY rc=1" "P67 场景 c（红侧影子）：多行草稿在老的槽位排除下照样忙（判定力不只来自边框邻行）"

# ── 真 pane 后果（非 FAST）：就绪门拒绝 + 生产路径只排队 ─────────────────────────────
# 3.1：pm-box-real.sh 的就绪门面对「框里是 0.87.0 单行草稿」的 pane 必须拒绝放行（P61 的 15d 是修前
# 的红侧：rc=0、把 payload 打进了草稿）。B1.3：同一形状上 say / draft send 一个键都不敲、只入队。
if [ "$FAST" = "1" ]; then
  fast_skip "42·P67-真pane" "要真 tmux pane + 帧回放假 pi（真进程段落）"
elif [ "$HAVE_TMUX" != "1" ] || ! command -v python3 >/dev/null 2>&1; then
  cond_skip "42·P67-真pane" "本机没有 tmux 或 python3"
else
  live_mark
  P67_DIR="$TMP/p67-live"; rm -rf "$P67_DIR"; mkdir -p "$P67_DIR"
  # 帧回放假 pi（P61 pkg/fake-pi.py 的单帧简化版）：画一帧后守到被杀；pane 收到的字节抄进 keylog。
  # 帧是**静止的**（不会自己变空），所以判据正确时就绪门永远不放行、一个键都不该被敲 ——
  # keylog 是那条断言的字节级证人（tmux 不直接暴露 pane 输入）。
  cat > "$P67_DIR/frame-replay-pi.py" <<'EOS'
#!/usr/bin/env python3
"""P67 帧回放假 pi：把一份真帧原样画到 pane 上，再把 pane 收到的每个字节抄进 keylog。

环境（夹具的 tmux server 继承）：V67_FRAME / V67_CURSOR / V67_KEYLOG
"""
import os, select, sys, time, tty

frame = os.environ["V67_FRAME"]
cursor = int(os.environ["V67_CURSOR"])
keylog = os.environ["V67_KEYLOG"]


def draw():
    with open(frame, encoding="utf-8") as f:
        rows = f.read().split("\n")
    out = sys.stdout
    out.write("\x1b[2J")
    for i, line in enumerate(rows[:30], start=1):
        out.write("\x1b[%d;1H%s" % (i, line))
    out.write("\x1b[%d;1H" % cursor)
    out.flush()


tty.setraw(0)  # 先 raw：pane 收到的字节立刻可见（不被行规程缓存）
draw()
while True:
    r, _, _ = select.select([0], [], [], 0.2)
    if not r:
        continue
    try:
        data = os.read(0, 4096)
    except OSError:
        data = b""
    if not data:
        break
    with open(keylog, "a", encoding="utf-8") as f:
        f.write("%d %s\n" % (int(time.time() * 1000), data.hex()))
EOS
  chmod +x "$P67_DIR/frame-replay-pi.py"

  # (i) 就绪门：自己的私有 fixture（真 tmux pane，120×30），画的就是那份真帧
  P67_KEYS_REFUSE="$P67_DIR/keys-refuse.log"; rm -f "$P67_KEYS_REFUSE"
  M24_PI_BIN="$P67_DIR/frame-replay-pi.py" M24_READY_TRIES=4 \
    V67_FRAME="$P67_ONE" V67_CURSOR=26 V67_KEYLOG="$P67_KEYS_REFUSE" \
    bash "$SKILL_DIR/tests/pm-box-real.sh" --idle-secs 0 >"$P67_DIR/refuse.log" 2>&1
  P67_REFUSE_RC=$?
  [ "$P67_REFUSE_RC" -ne 0 ] && ok "P67 就绪门：面对 0.87.0 单行草稿的 pane 拒绝放行（rc=$P67_REFUSE_RC≠0）" \
    || bad "P67 就绪门：单行草稿的 pane 上竟放行了（rc=0；P61 的 15d 就是这个红）"
  assert_has "$P67_DIR/refuse.log" "idle-read=NOT-EMPTY" "P67 就绪门：拒绝时最后判定点名 idle-read=NOT-EMPTY"
  assert_has "$P67_DIR/refuse.log" "--- 最后一帧（原样，留给报告）---" "P67 就绪门：拒绝时打印最后一帧"
  assert_has "$P67_DIR/refuse.log" "HUMAN-ONE-LINE-DRAFT" "P67 就绪门：最后一帧就是那行草稿（不是别的失败）"
  assert_not "$P67_DIR/refuse.log" "deliver_text_lines=" "P67 就绪门：拒绝后一步投递都没跑"
  assert_eq "P67 就绪门：keylog 零行（一个键都没敲进人的草稿）" \
    "$( [ -f "$P67_KEYS_REFUSE" ] && wc -l < "$P67_KEYS_REFUSE" || printf 0 )" "0"

  # (ii) 生产路径：复用 12b 的夹具项目/会话（dev 在名册里），把 dev 窗口换成帧回放假 pi
  P67_KEYS_SAY="$P67_DIR/keys-say.log"; rm -f "$P67_KEYS_SAY"
  rm -rf "$REPO/.pi/team/state/outbox"
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  P67_LIVE_CMD="$(printf 'V67_FRAME=%q V67_CURSOR=26 V67_KEYLOG=%q python3 %q' \
    "$P67_ONE" "$P67_KEYS_SAY" "$P67_DIR/frame-replay-pi.py")"
  tmux new-window -d -t "$SESSION" -n dev -c "$REPO" "$P67_LIVE_CMD" 2>/dev/null || true
  tmux resize-window -t "$SESSION:dev" -x 120 -y 30 2>/dev/null || true
  sleep 1
  assert_eq "P67 生产路径：dev 窗口画的正是 0.87.0 单行草稿帧" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'HUMAN-ONE-LINE-DRAFT' || true)" "1"
  p67_guard() { # 从 stdin 读片段；在夹具项目里跑生产守卫，$T = dev 窗口
    ( cd "$REPO" && bash -c '
        set -u
        . "'"$SKILL_DIR"'/scripts/lib/common.sh"
        . "'"$SKILL_DIR"'/scripts/lib/outbox.sh"
        . "'"$SKILL_DIR"'/tests/lib/box-judge.sh"
        T="'"$SESSION"':dev"
        source /dev/stdin
      ' )
  }
  P67_READS="$(p67_guard <<'EOS'
printf 'input_box_state=%s\n' "$(team_input_box_state "$T")"
printf 'delivery_verdict=%s\n' "$(team_delivery_verdict "$T")"
printf 'box_text=[%s]\n' "$(team_input_box_text "$T" 2>/dev/null | tr '\n' '|')"
printf 'holds_own=%s\n' "$(team_box_holds_only "$T" 'HUMAN-ONE-LINE-DRAFT' && printf yes || printf no)"
printf 'holds_foreign=%s\n' "$(team_box_holds_only "$T" 'check the failing test' && printf yes || printf no)"
EOS
)"
  assert_has_echo "$P67_READS" "input_box_state=BUSY" "P67 生产路径：team_input_box_state 报 BUSY"
  assert_has_echo "$P67_READS" "delivery_verdict=BUSY" "P67 生产路径：team_delivery_verdict 不是 EMPTY"
  assert_has_echo "$P67_READS" "box_text=[HUMAN-ONE-LINE-DRAFT|" "P67 生产路径：生产提取读到的就是那行草稿"
  assert_has_echo "$P67_READS" "holds_own=yes" "P67 生产路径：框里只有我们自己的那行 → holds_only=yes"
  assert_has_echo "$P67_READS" "holds_foreign=no" "P67 生产路径：外来 payload → holds_only=no"
  ( cd "$REPO" && $TEAM say dev "check the failing test" ) >"$P67_DIR/say.log" 2>&1 || true
  assert_has "$P67_DIR/say.log" "queued" "P67 生产路径：单行草稿在场 → team say 报 queued（不是已送达）"
  assert_eq "P67 生产路径：say 之后队列里恰好一条" \
    "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_eq "P67 生产路径：say 一个键都没敲（keylog 仍 0 行）" \
    "$( [ -f "$P67_KEYS_SAY" ] && wc -l < "$P67_KEYS_SAY" || printf 0 )" "0"
  assert_eq "P67 生产路径：say 的文字没有出现在 pane 上" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'check the failing test' || true)" "0"
  assert_eq "P67 生产路径：草稿行仍在 pane 上（原样）" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'HUMAN-ONE-LINE-DRAFT' || true)" "1"
  printf 'P67 draft-send payload\n' > "$P67_DIR/payload.txt"
  ( cd "$REPO" && $TEAM draft send "$P67_DIR/payload.txt" --target "$SESSION:dev" ) >"$P67_DIR/draft.log" 2>&1 || true
  assert_has "$P67_DIR/draft.log" "queued" "P67 生产路径：draft send 也只入队（queued）"
  assert_eq "P67 生产路径：draft send 之后队列里两条（say 的 + draft 的）" \
    "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "2"
  assert_eq "P67 生产路径：draft send 一个键都没敲（keylog 仍 0 行）" \
    "$( [ -f "$P67_KEYS_SAY" ] && wc -l < "$P67_KEYS_SAY" || printf 0 )" "0"
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
fi

# ---------------------------------------------------------------- 43. P75 尾部现场的读取器（P65 的 F1）
# 现场：`team status <ID>` 的第三层来源 state/dispatch-<agent>-tail.txt 是 tmux capture 的原样落盘，
# 末尾是 pane 下半屏的成片空行；读取器按字面取「最后 N 行」，TEAM_AGENT_SCENE_LINES=3 时就只剩空行 ——
# 一个有内容的文件被报成「来源在但没有画面内容」。本节钉住读取器侧的三条：尾空行裁剪（声明说清）、
# 只有空行时明说「没有可读内容」、非空行不足 N 时给现有的全部；并钉住第一/第二层语义没被带改。
# 红侧不靠产品开关：把 team_status_tail_scene 影子成旧的字面 tail（原样取最后 N 行），同一份夹具翻红。
section "43 · P75 status 尾部现场：尾空行裁剪（P65 的 F1）"
P75_A="p75w"; P75_ID="T9.75"; P75_ST="$REPO/.pi/team/state"
P75_TAIL="$P75_ST/dispatch-$P75_A-tail.txt"
P75_DEAD="$P75_ST/dispatch-$P75_A-pane-dead.txt"
mkdir -p "$P75_ST"
# 该席位没有窗口（也不会有）：第三层来源是唯一能命中的一层
printf 'window=%s\ntask=%s\n' "$P75_A" "$P75_ID" > "$P75_ST/$P75_A.env"
P75_STATUS() { # <行数> <输出文件>
  env TEAM_AGENTS="$P75_A" TEAM_AGENT_SCENE_LINES="$1" \
    bash "$SKILL_DIR/scripts/team" status "$P75_ID" >"$2" 2>&1
}
P75_STATUS_DEFAULT() { # <输出文件>：不设 TEAM_AGENT_SCENE_LINES（默认 40）
  env TEAM_AGENTS="$P75_A" bash "$SKILL_DIR/scripts/team" status "$P75_ID" >"$1" 2>&1
}
p75_scene() { grep '^    | ' "$1" 2>/dev/null | sed 's/^    | //'; }
p75_blanks() { printf '\n%.0s' $(seq 1 "${1:-5}"); }

# ── ① 绿侧：4 行内容 + 5 行尾空行，SCENE_LINES=3 → 3 行内容（P65 F1 的直接反例）────────
{ printf 'P75-MARK-1\nP75-MARK-2\nP75-MARK-3\nP75-MARK-4\n'; p75_blanks 5; } > "$P75_TAIL"
P75_STATUS 3 "$TMP/p75-tail-3.log"
assert_has "$TMP/p75-tail-3.log" "最后 3 行（去尾空行）" "P75 ①：声明说清这一层读的是「最后 3 行（去尾空行）」"
assert_eq "P75 ①：尾空行裁掉后取最后 3 行 = MARK-2/3/4（逐字节）" \
  "$(p75_scene "$TMP/p75-tail-3.log")" "$(printf 'P75-MARK-2\nP75-MARK-3\nP75-MARK-4')"
assert_not "$TMP/p75-tail-3.log" "P75-MARK-1" "P75 ①：只印最后 N 行，更早的行不出现"
assert_not "$TMP/p75-tail-3.log" "来源在但没有画面内容" "P75 ①：不再报「来源在但没有画面内容」（P65 的 F1）"
assert_eq "P75 ①：画面行数恰好 N=3" "$(grep -c '^    | ' "$TMP/p75-tail-3.log")" "3"

# ── ② 边界②：非空行不足 N → 给现有的全部 ─────────────────────────────────────────────
{ printf 'P75-ONLY-1\nP75-ONLY-2\n'; p75_blanks 3; } > "$P75_TAIL"
P75_STATUS 3 "$TMP/p75-tail-short.log"
assert_eq "P75 ②：非空行不足 N（2 < 3）→ 给现有的全部" \
  "$(p75_scene "$TMP/p75-tail-short.log")" "$(printf 'P75-ONLY-1\nP75-ONLY-2')"

# ── ③ 边界①：只有空行 → 明确说「来源里没有可读内容」（不是静默空块）───────────────────
p75_blanks 5 > "$P75_TAIL"
P75_STATUS 3 "$TMP/p75-tail-blank.log"
assert_has "$TMP/p75-tail-blank.log" "来源里没有可读内容" \
  "P75 ③：只有空行 → 明说「来源里没有可读内容」"
assert_eq "P75 ③：只有空行 → 一行画面都没有（也不是静默空块）" \
  "$(p75_scene "$TMP/p75-tail-blank.log" | wc -l | tr -d ' ')" "0"
assert_not "$TMP/p75-tail-blank.log" "来源在但没有画面内容" "P75 ③：这一句留给「有内容但取窗为空」，空文件不落进来"

# ── ④ 默认 40 行（不设旋钮）：4 行内容一字不少（回归）────────────────────────────────
{ printf 'P75-MARK-1\nP75-MARK-2\nP75-MARK-3\nP75-MARK-4\n'; p75_blanks 5; } > "$P75_TAIL"
P75_STATUS_DEFAULT "$TMP/p75-tail-default.log"
assert_has "$TMP/p75-tail-default.log" "最后 40 行（去尾空行）" "P75 ④：默认 40 行的声明照旧带来源措辞"
assert_eq "P75 ④：默认口径下 4 行内容全在（尾空行不吃内容）" \
  "$(p75_scene "$TMP/p75-tail-default.log")" "$(printf 'P75-MARK-1\nP75-MARK-2\nP75-MARK-3\nP75-MARK-4')"

# ── ⑤ 红侧（可证伪）：影子回旧的字面 tail → 同一份夹具翻回「来源在但没有画面内容」───────
P75_PROBE="$TMP/p75-tail-probe.sh"
cat > "$P75_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <state 目录> [shadow] → team_seat_scene_print 的现场块（shadow=1 = 旧的字面 tail -n N）
set -u
SKILL_DIR="$1"; ST="$2"; SHADOW="${3:-0}"
. "$SKILL_DIR/scripts/lib/common.sh"
for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
team_load_config >/dev/null 2>&1 || true
TEAM_STATE_DIR="$ST"
[ "$SHADOW" = "1" ] && team_status_tail_scene() { tail -n "$2" "$1" 2>/dev/null; }
team_seat_scene_print "${P75_PROBE_AGENT:-p75w}"
EOS
chmod +x "$P75_PROBE"
P75_RED_ST="$TMP/p75-red-state"; mkdir -p "$P75_RED_ST"
{ printf 'P75-MARK-1\nP75-MARK-2\nP75-MARK-3\nP75-MARK-4\n'; p75_blanks 5; } > "$P75_RED_ST/dispatch-$P75_A-tail.txt"
env TEAM_AGENTS="$P75_A" TEAM_AGENT_SCENE_LINES=3 bash "$P75_PROBE" "$SKILL_DIR" "$P75_RED_ST" 1 \
  >"$TMP/p75-red.log" 2>&1
assert_has "$TMP/p75-red.log" "来源在但没有画面内容" \
  "P75 ⑤ 红侧：影子回旧读取器 → 同一份夹具又报「来源在但没有画面内容」（翻转成立）"
assert_eq "P75 ⑤ 红侧：旧读取器一行画面都给不出" \
  "$(p75_scene "$TMP/p75-red.log" | wc -l | tr -d ' ')" "0"
env TEAM_AGENTS="$P75_A" TEAM_AGENT_SCENE_LINES=3 bash "$P75_PROBE" "$SKILL_DIR" "$P75_RED_ST" 0 \
  >"$TMP/p75-green-probe.log" 2>&1
assert_eq "P75 ⑤ 同源：探针（影子关）与生产 status 的现场行逐字节一致" \
  "$(p75_scene "$TMP/p75-green-probe.log")" "$(p75_scene "$TMP/p75-tail-3.log")"

# ── ⑥ 边界③：第二层（dispatch-<agent>-pane-dead.txt）的语义没被带改 ─────────────────
{
  printf 'seat: %s\nwindow: %s\ncaptured: 2026-01-01T00:00:00Z\nexit: signal=9\ndead_time: 2026-01-01 00:00:00 UTC\n' "$P75_A" "$P75_A"
  printf -- '--- scene ---\n'
  printf 'P75-CORPSE-1\nP75-CORPSE-2\nP75-CORPSE-3\nP75-CORPSE-4\n'
} > "$P75_DEAD"
P75_STATUS 3 "$TMP/p75-second-layer.log"
assert_has "$TMP/p75-second-layer.log" "最后 3 行）：" \
  "P75 ⑥：第二层的声明原样（没有「去尾空行」后缀 —— 那不是它的读取规则）"
assert_eq "P75 ⑥：第二层仍按既有语义取最后 3 行" \
  "$(p75_scene "$TMP/p75-second-layer.log")" "$(printf 'P75-CORPSE-2\nP75-CORPSE-3\nP75-CORPSE-4')"
assert_eq "P75 ⑥：第二层赢过第三层（来源里有 pane-dead 文件就不看尾屏）" \
  "$(grep -c 'pane-dead.txt（dispatch 替换遗体前抓的现场）' "$TMP/p75-second-layer.log")" "1"
rm -f "$P75_DEAD" "$P75_TAIL" "$P75_ST/$P75_A.env"

# ---------------------------------------------------------------- 44. P80 下边框框线（真 pane，非 FAST）
section "44 · P80 输入框判据：草稿自己的下边框框线（真 pane 就绪门 + 生产路径只排队）"
# B3 的端到端面：把一个**静止**的假 pi（帧回放，画着 P78 的攻击帧 —— 草稿在光标下方画了自己
# 的等宽框线）放进真 tmux pane，走 pm-box-real.sh 的**就绪门**与生产投递路径：
#   · 判据正确时就绪门永远不放行（帧不会自己变空）：rc≠0、点名 idle-read=NOT-EMPTY、打印最后一帧；
#   · 假 pi 把 pane 收到的每个字节抄进 keylog —— 一个键都不该被敲（tmux 不直接暴露 pane 输入，
#     keylog 是那条断言的字节级证人）；
#   · 生产路径（team say / team draft send）只排队（queued），文字不出现在 pane 上、草稿原样。
# 这**不是**需求的主证据（主证据是 12b-h0d 的逐帧断言，两个方向都在那里）；它的价值是在真
# pane 上同形复现「旧判据放行 → 新判据拒绝」这条链 —— 修复前的树在这里是红的（就绪门放行、
# 帧里出现 deliver_text_lines=、keylog 非空），报告里的 flip 证据用 git archive 的老树复跑同一段。
if [ "$FAST" = "1" ]; then
  fast_skip "44·P80-真pane" "要真 tmux pane + 帧回放假 pi（真进程段落）"
elif [ "$HAVE_TMUX" != "1" ] || ! command -v python3 >/dev/null 2>&1; then
  cond_skip "44·P80-真pane" "本机没有 tmux 或 python3"
else
  live_mark
  P80_DIR="$TMP/p80-live"; rm -rf "$P80_DIR"; mkdir -p "$P80_DIR"
  P80_ATTACK_FRAME="$SKILL_DIR/tests/frames/p78-draft-rule-below-cursor.txt"
  P80_ATTACK_CY=2
  cat > "$P80_DIR/frame-replay-pi.py" <<'EOS'
#!/usr/bin/env python3
"""P80 帧回放假 pi：把一份帧原样画到 pane 上，再把 pane 收到的每个字节抄进 keylog。

环境（夹具的 tmux server 继承）：V80_FRAME / V80_CURSOR / V80_KEYLOG
"""
import os, select, sys, time, tty

frame = os.environ["V80_FRAME"]
cursor = int(os.environ["V80_CURSOR"])
keylog = os.environ["V80_KEYLOG"]


def draw():
    with open(frame, encoding="utf-8") as f:
        rows = f.read().split("\n")
    out = sys.stdout
    out.write("\x1b[2J")
    for i, line in enumerate(rows[:30], start=1):
        out.write("\x1b[%d;1H%s" % (i, line))
    out.write("\x1b[%d;1H" % cursor)
    out.flush()


tty.setraw(0)  # 先 raw：pane 收到的字节立刻可见（不被行规程缓存）
draw()
while True:
    r, _, _ = select.select([0], [], [], 0.2)
    if not r:
        continue
    try:
        data = os.read(0, 4096)
    except OSError:
        data = b""
    if not data:
        break
    with open(keylog, "a", encoding="utf-8") as f:
        f.write("%d %s\n" % (int(time.time() * 1000), data.hex()))
EOS
  chmod +x "$P80_DIR/frame-replay-pi.py"

  # (i) 就绪门：自己的私有 fixture（真 tmux pane 120×30），画的就是那份攻击帧
  P80_KEYS_REFUSE="$P80_DIR/keys-refuse.log"; rm -f "$P80_KEYS_REFUSE"
  M24_PI_BIN="$P80_DIR/frame-replay-pi.py" M24_READY_TRIES=4 \
    V80_FRAME="$P80_ATTACK_FRAME" V80_CURSOR="$P80_ATTACK_CY" V80_KEYLOG="$P80_KEYS_REFUSE" \
    bash "$SKILL_DIR/tests/pm-box-real.sh" --idle-secs 0 >"$P80_DIR/refuse.log" 2>&1
  P80_REFUSE_RC=$?
  [ "$P80_REFUSE_RC" -ne 0 ] && ok "P80 就绪门：面对「草稿自带下边框框线」的 pane 拒绝放行（rc=$P80_REFUSE_RC≠0）" \
    || bad "P80 就绪门：攻击帧的 pane 上竟放行了（rc=0 —— 旧判据的 P74-F1 现场）"
  assert_has "$P80_DIR/refuse.log" "idle-read=NOT-EMPTY" "P80 就绪门：拒绝时最后判定点名 idle-read=NOT-EMPTY"
  assert_has "$P80_DIR/refuse.log" "--- 最后一帧（原样，留给报告）---" "P80 就绪门：拒绝时打印最后一帧"
  assert_has "$P80_DIR/refuse.log" "draft text below my own rule" "P80 就绪门：最后一帧就是那份攻击草稿（不是别的失败）"
  assert_not "$P80_DIR/refuse.log" "deliver_text_lines=" "P80 就绪门：拒绝后一步投递都没跑"
  assert_eq "P80 就绪门：keylog 零行（一个键都没敲进人的草稿）" \
    "$( [ -f "$P80_KEYS_REFUSE" ] && wc -l < "$P80_KEYS_REFUSE" || printf 0 )" "0"

  # (ii) 生产路径：复用 12b 的夹具项目/会话（dev 在名册里），把 dev 窗口换成帧回放假 pi
  P80_KEYS_SAY="$P80_DIR/keys-say.log"; rm -f "$P80_KEYS_SAY"
  rm -rf "$REPO/.pi/team/state/outbox"
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  P80_LIVE_CMD="$(printf 'V80_FRAME=%q V80_CURSOR=%s V80_KEYLOG=%q python3 %q' \
    "$P80_ATTACK_FRAME" "$P80_ATTACK_CY" "$P80_KEYS_SAY" "$P80_DIR/frame-replay-pi.py")"
  tmux new-window -d -t "$SESSION" -n dev -c "$REPO" "$P80_LIVE_CMD" 2>/dev/null || true
  tmux resize-window -t "$SESSION:dev" -x 120 -y 30 2>/dev/null || true
  sleep 1
  assert_eq "P80 生产路径：dev 窗口画的正是攻击帧" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'draft text below my own rule' || true)" "1"
  p80_guard() { # 从 stdin 读片段；在夹具项目里跑生产守卫，$T = dev 窗口
    ( cd "$REPO" && bash -c '
        set -u
        . "'"$SKILL_DIR"'/scripts/lib/common.sh"
        . "'"$SKILL_DIR"'/scripts/lib/outbox.sh"
        . "'"$SKILL_DIR"'/tests/lib/box-judge.sh"
        T="'"$SESSION"':dev"
        source /dev/stdin
      ' )
  }
  P80_READS="$(p80_guard <<'EOS'
printf 'input_box_state=%s\n' "$(team_input_box_state "$T")"
printf 'delivery_verdict=%s\n' "$(team_delivery_verdict "$T")"
printf 'box_nows=[%s]\n' "$(team_input_box_text "$T" 2>/dev/null | tr -d '[:space:]')"
EOS
)"
  assert_has_echo "$P80_READS" "input_box_state=BUSY" "P80 生产路径：team_input_box_state 报 BUSY（不是 EMPTY）"
  assert_has_echo "$P80_READS" "delivery_verdict=BUSY" "P80 生产路径：team_delivery_verdict 不是 EMPTY"
  assert_has_echo "$P80_READS" "drafttextbelowmyownrule]" "P80 生产路径：生产提取读到的就是框线行 + 框线下面的草稿"
  ( cd "$REPO" && $TEAM say dev "P80-DRAFT-ATTACK-SAY" ) >"$P80_DIR/say.log" 2>&1 || true
  assert_has "$P80_DIR/say.log" "queued" "P80 生产路径：攻击草稿在场 → team say 报 queued（不是已送达）"
  assert_eq "P80 生产路径：say 之后队列里恰好一条" \
    "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  assert_eq "P80 生产路径：say 一个键都没敲（keylog 仍 0 行）" \
    "$( [ -f "$P80_KEYS_SAY" ] && wc -l < "$P80_KEYS_SAY" || printf 0 )" "0"
  assert_eq "P80 生产路径：say 的文字没有出现在 pane 上" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'P80-DRAFT-ATTACK-SAY' || true)" "0"
  assert_eq "P80 生产路径：攻击草稿仍在 pane 上（原样）" \
    "$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null | grep -c 'draft text below my own rule' || true)" "1"
  printf 'P80 draft-send payload\n' > "$P80_DIR/payload.txt"
  ( cd "$REPO" && $TEAM draft send "$P80_DIR/payload.txt" --target "$SESSION:dev" ) >"$P80_DIR/draft.log" 2>&1 || true
  assert_has "$P80_DIR/draft.log" "queued" "P80 生产路径：draft send 也只入队（queued）"
  assert_eq "P80 生产路径：draft send 之后队列里两条（say 的 + draft 的）" \
    "$(find "$REPO/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "2"
  assert_eq "P80 生产路径：draft send 一个键都没敲（keylog 仍 0 行）" \
    "$( [ -f "$P80_KEYS_SAY" ] && wc -l < "$P80_KEYS_SAY" || printf 0 )" "0"
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
fi

# ---------------------------------------------------------------- 45. P76 合并前的「未入账记录」检查（D45）
# 事实（D45，2026-09-22）：`git merge --squash` 只带**已提交**内容。worker 常把报告/证据包留在工作树里
# 没提交（`??`），或改了 <docs>/ 记录没提交（` M`）—— 合并不带它们，工作树一被复用/复位就永久丢了
#（当天同一个形状 5 次：P36/P40/P42/P65/P67）。既有 digest 警告（M31/P47）没问题，但**合并流程根本
# 不跑 digest**：`git merge --squash` 是一条纯 git 命令。本节钉住合并步自己的检查：
#   `team review <ID> --pre-merge`：有未入账 → 非零 + 逐条 `<agent>: <path>` + 修法；干净 → 零输出；
#   只查任务分支的工作树、只看 <docs>/ 下的记录；只打印、**不替 agent 提交**；定位不到 → fail closed。
# 反向（可证伪）：影子掉扫描函数 = 「检查被删除」的形状 → 同一份夹具必须静悄悄放过。
section "45 · P76 合并前的未入账记录检查（D45）"

P76R="$TMP/p76repo"; rm -rf "$P76R"; mkdir -p "$P76R"
( cd "$P76R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# p76' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
P76SES="teamsmith-smoke-p76-$$"
( cd "$P76R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$P76SES" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/p76-init.log" 2>&1 \
  && ok "P76 夹具仓库 init 成功" || bad "P76 夹具仓库 init 失败（见 $TMP/p76-init.log）"
( cd "$P76R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/p76-paths.json" 2>&1 || true
assert_eq "P76 隔离：team paths 的 main_root 就是 P76 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/p76-paths.json")" "$P76R"
p76() { ( cd "$P76R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
if git -C "$P76R" add -A >/dev/null 2>&1 && git -C "$P76R" commit -qm "chore: init scaffold" >/dev/null 2>&1; then
  ok "P76 夹具：init 脚手架已入账"
else
  bad "P76 夹具：init 脚手架提交失败"
fi
P76_ID="P76"; P76_BR="task/P76-smoke"; P76_WT="$P76R/.worktrees/dev"
git -C "$P76R" worktree add -q -b "$P76_BR" "$P76_WT" main >/dev/null 2>&1
if [ -e "$P76_WT/.git" ]; then ok "P76 夹具：任务工作树就位（.worktrees/dev @ $P76_BR）"; else bad "P76 夹具：工作树起不来（后续断言无意义）"; fi
mkdir -p "$P76R/.pi/team/state"
printf 'window=dev\ntask=%s\nbranch=%s\n' "$P76_ID" "$P76_BR" > "$P76R/.pi/team/state/dev.env"
P76_REC="$P76R/docs/team/reviews/$P76_ID.md"

# ── ① 未入账：未跟踪（含包内文件）+ 已改未提交 → 非零 + 逐条点名 + 修法 ──────────────────────
mkdir -p "$P76_WT/docs/team/reports/P76-dev/pkg"
printf '# P76-dev · 交付报告\n\nagent: dev\n' > "$P76_WT/docs/team/reports/P76-dev.md"
printf 'echo evidence\n' > "$P76_WT/docs/team/reports/P76-dev/pkg/run.sh"
printf 'a record edit that was never committed\n' >> "$P76_WT/docs/team/DECISIONS.md"
P76_HEAD0="$(git -C "$P76_WT" rev-parse HEAD)"
p76 $TEAM review "$P76_ID" --pre-merge >"$TMP/p76-unlanded.log" 2>&1; P76_RC=$?
assert_eq "P76 ①：有未入账记录 → 非零退出（能当合并门）" "$P76_RC" "1"
assert_has "$TMP/p76-unlanded.log" "3 份记录未入账" "P76 ①：点名未入账份数"
assert_has "$TMP/p76-unlanded.log" "dev: docs/team/reports/P76-dev.md  [?? 未跟踪（新文件，从未提交）]" \
  "P76 ①：未跟踪的报告点名（<agent>: <path> + 状态）"
assert_has "$TMP/p76-unlanded.log" "dev: docs/team/DECISIONS.md  [ M 已改未提交（工作区改动）]" \
  "P76 ①：已改未提交的记录同样点名（M31 的旧检查只看 ??）"
assert_has "$TMP/p76-unlanded.log" "dev: docs/team/reports/P76-dev/pkg/run.sh" \
  "P76 ①：报告包里的文件逐条点名（--untracked-files=all）"
assert_has "$TMP/p76-unlanded.log" "git -C $P76_WT add -A -- docs/team/DECISIONS.md docs/team/reports/P76-dev.md docs/team/reports/P76-dev/pkg/run.sh" \
  "P76 ①：修法是一条可粘贴的 git add（列出全部路径）"
assert_has "$TMP/p76-unlanded.log" "Agent: dev" "P76 ①：修法里的提交带 Agent: trailer（谁提交的要说真话）"
assert_has "$TMP/p76-unlanded.log" "review $P76_ID --pre-merge" "P76 ①：给出提交后重跑的下一步"
assert_not_file "$P76_REC" "P76 ①：--pre-merge 不写复验记录（它不是一次复验）"
assert_eq "P76 ①：不替 agent 提交（HEAD 不动）" "$(git -C "$P76_WT" rev-parse HEAD)" "$P76_HEAD0"
assert_eq "P76 ①：文件仍在未入账状态（命令只打印）" \
  "$(git -C "$P76_WT" status --porcelain -- docs/team/reports/P76-dev.md)" "?? docs/team/reports/P76-dev.md"

# ── ② 入账后 → 退出码 0 且零输出（安静）────────────────────────────────────────────────────
git -C "$P76_WT" add -A >/dev/null 2>&1
git -C "$P76_WT" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "docs(team): P76 fixture records" >/dev/null 2>&1
p76 $TEAM review "$P76_ID" --pre-merge >"$TMP/p76-clean.log" 2>&1; P76_RC2=$?
assert_eq "P76 ②：记录入账后 → 退出码 0" "$P76_RC2" "0"
assert_eq "P76 ②：干净时安静（零输出）" "$(wc -c < "$TMP/p76-clean.log" | tr -d ' ')" "0"

# ── ③ 负对照：state/、构建产物、ignored 的记录都不算（只有它们时零输出）────────────────────
printf 'scratch\n' > "$P76_WT/scratch.txt"
mkdir -p "$P76_WT/build"; printf 'object\n' > "$P76_WT/build/x.o"
mkdir -p "$P76_WT/.pi/team/state"; printf 'runtime\n' > "$P76_WT/.pi/team/state/junk"
mkdir -p "$P76_WT/docs/team/inbox"; printf 'ignored inbox\n' > "$P76_WT/docs/team/inbox/dev.md"
printf 'ignored log\n' > "$P76_WT/docs/team/reviews/local.log"
p76 $TEAM review "$P76_ID" --pre-merge >"$TMP/p76-decoy.log" 2>&1; P76_RC3=$?
assert_eq "P76 ③：只有无关脏文件（state/、build/、ignored）→ 退出码 0" "$P76_RC3" "0"
assert_eq "P76 ③：无关脏文件不产生输出" "$(wc -c < "$TMP/p76-decoy.log" | tr -d ' ')" "0"
git -C "$P76_WT" clean -qfd >/dev/null 2>&1 || true
rm -f "$P76_WT/docs/team/reviews/local.log"

# ── ④ 反向（可证伪）：影子掉扫描 = 「检查被删除」的形状 → 同一份夹具静悄悄放过 ──────────────
P76_PROBE="$TMP/p76-probe.sh"
cat > "$P76_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <repo> <shadow>：shadow=1 = 影子掉「未入账」扫描（检查被删除的形状）
set -u
SKILL_DIR="$1"; REPO="$2"; SHADOW="${3:-0}"
cd "$REPO"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SKILL_DIR
. "$SKILL_DIR/scripts/lib/common.sh"
for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
team_load_config >/dev/null 2>&1 || true
[ "$SHADOW" = "1" ] && team_review_unlanded_records() { :; }
team_cmd_review P76 --pre-merge
EOS
chmod +x "$P76_PROBE"
printf '# P76-dev · 交付报告（翻转夹具）\n\nagent: dev\n' > "$P76_WT/docs/team/reports/P76-dev.md"
bash "$P76_PROBE" "$SKILL_DIR" "$P76R" 0 >"$TMP/p76-probe-green.log" 2>&1; P76_RC4=$?
assert_eq "P76 ④：探针（同源）照旧非零退出" "$P76_RC4" "1"
assert_has "$TMP/p76-probe-green.log" "dev: docs/team/reports/P76-dev.md" "P76 ④：探针照旧点名路径"
bash "$P76_PROBE" "$SKILL_DIR" "$P76R" 1 >"$TMP/p76-probe-shadow.log" 2>&1; P76_RC5=$?
assert_eq "P76 ④ 反向：检查被影子掉 → 退出码 0（同一份夹具被静悄悄放过）" "$P76_RC5" "0"
assert_eq "P76 ④ 反向：检查被影子掉 → 零输出（假绿的形状）" "$(wc -c < "$TMP/p76-probe-shadow.log" | tr -d ' ')" "0"
git -C "$P76_WT" add -A >/dev/null 2>&1
git -C "$P76_WT" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "docs(team): P76 flip fixture record" >/dev/null 2>&1

# ── ⑤ 含混用法拒绝 + 定位不到 fail closed（不把「没检查」报成「没问题」）──────────────────
p76 $TEAM review "$P76_ID" --pre-merge --dir "$TMP/p76-nope" >"$TMP/p76-mixed.log" 2>&1; P76_RC6=$?
assert_eq "P76 ⑤：--pre-merge 与 --dir 同用被拒（它不跑复验）" "$P76_RC6" "2"
assert_has "$TMP/p76-mixed.log" "不与 --dir 同用" "P76 ⑤：拒绝时说明原因"
rm -f "$P76R/.pi/team/state/dev.env"
git -C "$P76R" worktree remove --force "$P76_WT" >/dev/null 2>&1
git -C "$P76R" branch -D "$P76_BR" >/dev/null 2>&1
p76 $TEAM review "$P76_ID" --pre-merge >"$TMP/p76-nolocate.log" 2>&1; P76_RC7=$?
assert_eq "P76 ⑤：定位不到工作树 → 非零（fail closed，不假装检查过）" "$P76_RC7" "2"
assert_has "$TMP/p76-nolocate.log" "定位不到这个任务分支的工作树" "P76 ⑤：拒绝时点名「无法检查」"

# ---------------------------------------------------------------- 46. P86 下边框候选的准入条件（纯帧，快模式照跑）
section "46 · P86 下边框判据：定位出的框必须包含光标行（P84 的 F1 安全回归）"
# 现场（P84 的 F1 —— 本 change 的 apply 引入的安全回归）：规格只钉了「顶边框 = 下边框之上**最高**的合格行」，
# 旧顺序下（下边框紧贴光标下方）这**隐含**了「框含光标」；改成「最低候选」后，配对可以**整个落在光标
# 下方** —— 混宽度帧里下方另有一对自成配对的规则行（5/7 行，宽度与光标框不同）→ 新框 [5 7] 与光标框
# [1 3] **不相交** → 框读空 → 就绪门放行 → payload 打进人的草稿（生产路径同样 EMPTY）。
# P86 的**准入条件**：候选配到的顶边框必须**严格位于光标行之上**（⇒ 定位出的框总是包含光标行）；
# 不满足 → 跳过这个候选、继续在**更近**的候选里找；全都不满足 → 既有的 unknown-shape 路径。配对规则
# （tier1 等宽 / tier2 spinner）、横幅排除、两遍回退、顶边框取最高，全部照旧。本段是**纯帧**（不开 tmux、
# 不跑 pi，FAST 照跑）。
#
# 红侧不靠产品开关，两条影子各自只覆盖**一个**决策函数（M24_SHADOW_CHROME / §12b-h0d 同一模式）：
#   shadow=2（_team_box_top_border_max_row → 极大行号） = **准入条件关掉** = P80（本 change 的 apply）
#   shadow=1（_team_box_bottom_candidate_order → cat） = P80 之前的「最近优先」
# 交付时的红侧实测（当前 HEAD 8e32a04e，修前）：三份 p86-f1-* 帧都是 geometry=[5 7]、box_nows=[]、
# idle-read=EMPTY rc=0；下面断言影子 2 必须**逐字**复现它（同一份帧、同一个判据）。
P86_FD="$SKILL_DIR/tests/frames"
P86_PROBE="$TMP/p86-frame-probe.sh"
cat > "$P86_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <帧文件> <光标行> [shadow: 0=修后,1=最近优先,2=准入关掉（P86 前）] → geometry / box_nows / verdict
set -u
SKILL_DIR="$1"; FR="$2"; CY="$3"; SHADOW="${4:-0}"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION \
      TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR 2>/dev/null || true
. "$SKILL_DIR/scripts/lib/common.sh"; . "$SKILL_DIR/scripts/lib/outbox.sh"
. "$SKILL_DIR/tests/lib/box-judge.sh"
case "$SHADOW" in
  1) _team_box_bottom_candidate_order() { cat; } ;;
  2) _team_box_top_border_max_row() { printf '999999\n'; } ;;
esac
printf 'geometry=[%s]\n' "$(_team_box_geometry "$CY" < "$FR")"
text="$(_team_box_text_of_frame "$CY" < "$FR" 2>/dev/null || true)"
printf 'box_nows=[%s]\n' "$(printf '%s' "$text" | tr -d '[:space:]')"
if v="$(team_box_frame_verdict "$CY" < "$FR" 2>/dev/null)"; then printf 'verdict=%s rc=0\n' "$v"
else printf 'verdict=%s rc=1\n' "$v"; fi
EOS
chmod +x "$P86_PROBE"
p86_probe() { # <帧> <光标行> [shadow]
  ( cd "$REPO" && bash "$P86_PROBE" "$SKILL_DIR" "$1" "$2" "${3:-0}" 2>&1 )
}
p86_geo() { printf '%s\n' "$1" | sed -n 's/^geometry=\[\(.*\)\]$/\1/p'; }

P86_F1="$P86_FD/p86-f1-mixed-width-disjoint-box.txt"
P86_F2="$P86_FD/p86-f1-spinner-top-disjoint-box.txt"
P86_F3="$P86_FD/p86-f1-narrower-width-disjoint-box.txt"
for _p86f in "$P86_F1" "$P86_F2" "$P86_F3"; do
  assert_file "$_p86f" "P86：F1 帧 $(basename "$_p86f") 在 tests/frames/（裁切型 TUI 模型，README 明说合成）"
done
# 帧与 P84 复验时自造的那三份逐字节相同（sha256 也写进 README）：改宽/重排立刻红
declare -A P86_SHA=(
  ["$(basename "$P86_F1")"]="4a59efae747e9b81414eff7f2664d421c8bc418bd57a2afbc2e037c8d7d81ca2"
  ["$(basename "$P86_F2")"]="67c8a6ab321693df1ddfa867af0c7e09e0e329099858c1e6dbccaa59b2546c7e"
  ["$(basename "$P86_F3")"]="a3d9232e6abc422984c67799af6f2b8791921848d7a65c9de8864845ad54c70e"
)
for _p86f in "$P86_F1" "$P86_F2" "$P86_F3"; do
  assert_eq "P86：$(basename "$_p86f") 与 P84 自造的 F1 帧逐字节相同（sha256）" \
    "$(sha256sum "$_p86f" | cut -d' ' -f1)" "${P86_SHA[$(basename "$_p86f")]}"
done

# ── 绿/红/旧顺序三侧：三份 F1 帧（红侧 = 准入关掉，即 P86 前的 P80 行为）─────────────────
for _p86f in "$P86_F1" "$P86_F2" "$P86_F3"; do
  _p86n="$(basename "$_p86f")"
  P86_G="$(p86_probe "$_p86f" 2)"
  assert_has_echo "$P86_G" "geometry=[1 3]" \
    "P86 绿侧 $_p86n：下方的自成一体候选被准入条件拒绝 → 回落最近的合格候选 [1 3]（不是 [5 7]）"
  assert_has_echo "$P86_G" "box_nows=[HUMANDRAFTLINE]" "P86 绿侧 $_p86n：光标行的草稿留在框内（框含光标）"
  assert_has_echo "$P86_G" "verdict=idle-read=NOT-EMPTY rc=1" "P86 绿侧 $_p86n：判忙 —— 就绪门不再放行（P84 的 F1 修掉）"
  P86_R="$(p86_probe "$_p86f" 2 2)"
  assert_eq "P86 红侧 $_p86n（准入关掉 = P80）：退回光标下方的空框 [5 7]" "$(p86_geo "$P86_R")" "5 7"
  assert_has_echo "$P86_R" "box_nows=[]" "P86 红侧 $_p86n：框读空（脏框判空 → 生产路径会放行）"
  assert_has_echo "$P86_R" "verdict=idle-read=EMPTY rc=0" \
    "P86 红侧 $_p86n：idle-read=EMPTY rc=0（可证伪：这条判据真的咬在准入条件上）"
  P86_L="$(p86_probe "$_p86f" 2 1)"
  assert_has_echo "$P86_L" "geometry=[1 3]" "P86 旧顺序 $_p86n（最近优先影子）：同一帧也是 [1 3]"
  assert_has_echo "$P86_L" "verdict=idle-read=NOT-EMPTY rc=1" \
    "P86 旧顺序 $_p86n：判忙 —— 两种顺序都不放行，中间那版 P80 才是 EMPTY"
done
# 同源：夹具侧（pm-box-real.sh --frame，与生产提取共用判据）在 F1 帧上也判忙
P86_M="$(bash "$SKILL_DIR/tests/pm-box-real.sh" --frame "$P86_F1" --cursor 2 2>&1)"; P86_MRC=$?
assert_eq "P86 同源：pm-box-real.sh --frame 在 F1 帧上也判忙（rc=1）" "$P86_MRC" "1"
assert_has_echo "$P86_M" "HUMAN DRAFT LINE" "P86 同源：共享判据读出了光标行的草稿（不是空框）"
assert_not_echo "$P86_M" "idle-read=EMPTY" "P86 同源：共享判据绝不放行"
# 一处实现：准入决策只有一处（影子只覆盖那一个函数）
assert_eq "P86 一处实现：准入决策在 outbox.sh 里定义恰一处" \
  "$(grep -c '^_team_box_top_border_max_row() {' "$SKILL_DIR/scripts/lib/outbox.sh")" "1"
assert_eq "P86 一处实现：几何里向它要上界恰一处" \
  "$(grep -c 'maxrow="\$(_team_box_top_border_max_row' "$SKILL_DIR/scripts/lib/outbox.sh")" "1"

# ── 全部已存帧（发现式：frames/*.txt = 5 真帧 + 8 份 p78 + 3 份 p86 = 16）────────────
# ① 框含光标：定位出的框必须包含光标行（geometry=[t b] ⇒ t < cy < b）；没有框的帧只能是最上面那份
#    信任弹窗（覆盖层先行，几何为空是**既有路径**）。
# ② 单调性（可机读）：对每一帧对比「准入关掉（P86 前）」与修后 —— 不许 ANY 帧 BUSY→EMPTY；反向的
#    EMPTY→BUSY 必须**恰好**是三份 F1 帧（修复的效果，不多不少）。
# ③ 相对「最近优先」的旧顺序同样不许 BUSY→EMPTY（§12b-h0d 的 13 份在此扩到 16 份，同一口径）。
# 帧是**发现**出来的：新增帧没在上面的光标表里声明光标行 → 本段直接红（不静默漏测）。
p86_cursor() { # <帧路径> → 光标行（未知 → 空）
  case "$(basename "$1")" in
    pi-0.87.0-project-trust-prompt.txt) printf '16\n' ;;
    pi-0.8*) printf '26\n' ;;
    p78-cursor-mid-draft.txt) printf '3\n' ;;
    p78-*.txt|p86-f1-*.txt) printf '2\n' ;;
    *) printf '\n' ;;
  esac
}
P86_N=0; P86_UNCOVERED=""; P86_REGRESS=""; P86_NOCURSOR=""; P86_FLIPPED=""; P86_NOBOX=""; P86_LEGACY=""
for _p86r in "$P86_FD"/*.txt; do
  _p86n="$(basename "$_p86r")"; _p86cy="$(p86_cursor "$_p86r")"
  if [ -z "$_p86cy" ]; then P86_UNCOVERED="$P86_UNCOVERED $_p86n"; continue; fi
  P86_N=$((P86_N + 1))
  P86_NEW="$(p86_probe "$_p86r" "$_p86cy")"
  P86_OLD="$(p86_probe "$_p86r" "$_p86cy" 2)"
  P86_LEG="$(p86_probe "$_p86r" "$_p86cy" 1)"
  _p86g="$(p86_geo "$P86_NEW")"
  if [ -z "$_p86g" ]; then
    P86_NOBOX="$P86_NOBOX $_p86n"        # 没有框：只能是最上面那份覆盖层帧（下面单独断言）
  else
    _p86t=""; _p86b=""; _p86extra=""
    read -r _p86t _p86b _p86extra <<< "$_p86g"
    if [ -z "$_p86extra" ] && [ -n "$_p86t" ] && [ -n "$_p86b" ] \
       && [ "$_p86t" -lt "$_p86cy" ] 2>/dev/null && [ "$_p86cy" -lt "$_p86b" ] 2>/dev/null; then :
    else P86_NOCURSOR="$P86_NOCURSOR $_p86n([$_p86g] cy=$_p86cy)"; fi
  fi
  case "$P86_OLD" in *"verdict=idle-read=NOT-EMPTY"*) case "$P86_NEW" in
    *"verdict=idle-read=EMPTY"*) P86_REGRESS="$P86_REGRESS $_p86n" ;; esac ;; esac
  case "$P86_OLD" in *"verdict=idle-read=EMPTY"*) case "$P86_NEW" in
    *"verdict=idle-read=NOT-EMPTY"*) P86_FLIPPED="$P86_FLIPPED $_p86n" ;; esac ;; esac
  case "$P86_LEG" in *"verdict=idle-read=NOT-EMPTY"*) case "$P86_NEW" in
    *"verdict=idle-read=EMPTY"*) P86_LEGACY="$P86_LEGACY $_p86n" ;; esac ;; esac
done
assert_eq "P86 语料口径：全部已存帧都声明了光标行（发现式；新增帧不改表 → 这一段直接红）" "${P86_UNCOVERED:-none}" "none"
assert_eq "P86 语料口径：已存帧 16 份（5 真帧 + 8 份 p78 + 3 份 p86）" "$P86_N" "16"
assert_eq "P86 ① 定位出的框总是包含光标行（top < cy < bottom，全部帧）" "${P86_NOCURSOR:-none}" "none"
assert_eq "P86 ① 没有框的帧只能是覆盖层那份（unknown-shape 是既有路径，不是新行为）" \
  "$P86_NOBOX" " pi-0.87.0-project-trust-prompt.txt"
assert_eq "P86 ② 全部帧：准入前判忙的帧在修后没有一个翻成 EMPTY（没有 BUSY→EMPTY）" "${P86_REGRESS:-none}" "none"
assert_eq "P86 ② 全部帧：修后翻成忙的恰好是三份 F1 帧（修复的效果，不多不少）" \
  "$(printf '%s\n' $P86_FLIPPED | sort | tr '\n' ' ')" \
  "$(printf '%s\n' p86-f1-mixed-width-disjoint-box.txt p86-f1-narrower-width-disjoint-box.txt p86-f1-spinner-top-disjoint-box.txt | sort | tr '\n' ' ')"
assert_eq "P86 ③ 全部帧：相对最近的旧顺序也没有 BUSY→EMPTY" "${P86_LEGACY:-none}" "none"

# ---------------------------------------------------------------- 47. P82 · notify 发送者 = 运行时目录
# change: notify-sender-identity（delta = specs/notify-and-inbox 的 ADDED「A manual notification is
# attributed to its sender, not its recipient」）。事故（P72 提案实测）：worker 在 .worktrees/<name> 里跑
# `team notify pm --from-file <摘要>`，**收件箱行 / knock 文本 / 条目的 from: 三处都写 `agent:pm`** ——
# 收件人冒充发送者，PM 的 durable 收件箱对不上 docs/team/reports/**（假绿比没有更糟：philosophy.md）。
# 本段钉住四条：显式 --from ＞ 运行时目录（主工作树 → pm；.worktrees/<name> → 目录名，含子目录）
# ＞ 未解析 = 拒绝（非 0 + 零收件箱行 + 零 knock，输出点名 --from）；TEAM_AGENT 不许压过目录；
# 收件人仍然只是收件人（文件名 + 敲门目标）。两条路同源（[auto] 由扩展负责）在 3.x 的对手段落里。
section "47 · P82 notify 发送者 = 运行时目录（notify-sender-identity）"

P82R="$TMP/p82repo"; rm -rf "$P82R"; mkdir -p "$P82R"
( cd "$P82R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# p82' > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
P82_SES="teamsmith-smoke-p82-$$"
( cd "$P82R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$P82_SES" --agents "dev dev2" --vcs local --gates true --docs docs/team ) >"$TMP/p82-init.log" 2>&1 \
  && ok "P82 夹具仓库 init 成功" || bad "P82 夹具仓库 init 失败（见 $TMP/p82-init.log）"
( cd "$P82R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/p82-paths.json" 2>&1 || true
assert_eq "P82 隔离：team paths 的 main_root 就是 P82 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/p82-paths.json")" "$P82R"
# 夹具配置：扩展那一半不敲门（[auto] 只验收件箱归属），并把它的日志引到夹具自己能读的位置；
# CLI 的两处由 env 显式控制（env 压过文件）
cat >> "$P82R/.pi/team/config.sh" <<EOS

# P82 夹具
TEAM_NOTIFY_TMUX=0
TEAM_NOTIFY_LOG="$TMP/p82-ext.log"
EOS
if git -C "$P82R" add -A >/dev/null 2>&1 && git -C "$P82R" commit -qm "chore: init scaffold" >/dev/null 2>&1; then
  ok "P82 夹具：init 脚手架已入账"
else
  bad "P82 夹具：init 脚手架提交失败"
fi
P82_WT="$P82R/.worktrees/dev2"
git -C "$P82R" worktree add -q -b task/P82-smoke "$P82_WT" main >/dev/null 2>&1
if [ -e "$P82_WT/.git" ]; then ok "P82 夹具：席位 dev2 的工作树就位（.worktrees/dev2）"; else bad "P82 夹具：dev2 工作树起不来（后续断言无意义）"; fi
P82_OUT="$TMP/p82-elsewhere"
git -C "$P82R" worktree add -q -b task/P82-elsewhere "$P82_OUT" main >/dev/null 2>&1
if [ -e "$P82_OUT/.git" ]; then ok "P82 夹具：项目外的第二棵工作树就位（$P82_OUT）"; else bad "P82 夹具：项目外的第二棵工作树起不来"; fi

printf 'P82-SUMMARY-1\n' > "$TMP/p82-sum.txt"
P82_INBOX="$P82R/docs/team/inbox/pm.md"
p82_ck() { cksum "${1:-$P82_INBOX}" 2>/dev/null | awk '{print $1":"$2}'; }
# 夹具命令：清掉继承身份（M40 纪律）+ 关掉敲门 —— 这一组只看**解析出的发送者**与 durable 行
p82() { ( cd "$1" ; shift; env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_AGENT -u TEAM_SKILL_DIR \
            TEAM_NOTIFY_TMUX=0 $TEAM "$@" ); }
p82_last() { tail -1 "${1:-$P82_INBOX}" 2>/dev/null | sed 's/.*\[manual\] //'; }

# ── 1.2 运行时目录：worker 工作树（根 / 子目录）→ 席位名；主工作树 → pm ──────────────────────
p82 "$P82_WT" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-worker.log" 2>&1 \
  && ok "P82 1.2 worker 工作树里 notify 退出码 0" || bad "P82 1.2 worker 工作树里 notify 失败"
assert_eq "P82 1.2 发送者 = 工作树目录名（不是收件人 pm）" "$(p82_last)" "agent:dev2 · P82-SUMMARY-1"
assert_eq "P82 1.2 这一刻没有任何一行被记成 pm" "$(grep -c 'agent:pm' "$P82_INBOX")" "0"
p82 "$P82_WT/docs" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-sub.log" 2>&1 \
  && ok "P82 1.2 工作树的子目录里 notify 退出码 0" || bad "P82 1.2 工作树的子目录里 notify 失败"
assert_eq "P82 1.2 在 <worktree>/docs 里跑也解析成 dev2（不是 docs）" "$(p82_last)" "agent:dev2 · P82-SUMMARY-1"
p82 "$P82R" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-main.log" 2>&1 \
  && ok "P82 1.2 主工作树里 notify 退出码 0" || bad "P82 1.2 主工作树里 notify 失败"
assert_eq "P82 1.2 主工作树 → pm（PM 自己的通知仍记 pm）" "$(p82_last)" "agent:pm · P82-SUMMARY-1"

# ── 1.3 继承的 TEAM_AGENT 不许压过运行时目录（分歧点名，目录赢）─────────────────────────────
( cd "$P82_WT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SKILL_DIR \
    TEAM_AGENT=pm TEAM_NOTIFY_TMUX=0 $TEAM notify pm --from-file "$TMP/p82-sum.txt" ) >"$TMP/p82-agentenv.log" 2>&1 \
  && ok "P82 1.3 带 TEAM_AGENT=pm 的 worker 环境 notify 退出码 0" || bad "P82 1.3 带 TEAM_AGENT=pm 的 worker 环境 notify 失败"
assert_eq "P82 1.3 发送者仍是运行时目录的 dev2（继承值不许赢）" "$(p82_last)" "agent:dev2 · P82-SUMMARY-1"
assert_has "$TMP/p82-agentenv.log" "TEAM_AGENT=pm" "P82 1.3 stderr 点名被忽略的 TEAM_AGENT 值"

# ── 1.1 显式 --from：原样记录；与运行时目录分歧时点名 ────────────────────────────────────────
p82 "$P82_WT" notify pm --from dev3 --from-file "$TMP/p82-sum.txt" >"$TMP/p82-claim.log" 2>&1 \
  && ok "P82 1.1 worker 里的显式 --from 退出码 0" || bad "P82 1.1 worker 里的显式 --from 失败"
assert_eq "P82 1.1 显式 --from 原样记录（压过运行时目录）" "$(p82_last)" "agent:dev3 · P82-SUMMARY-1"
assert_has "$TMP/p82-claim.log" "不一致" "P82 1.1 --from 与运行时目录的分歧在 stderr 点名"
p82 "$P82R" notify pm --from dev3 --from-file "$TMP/p82-sum.txt" >"$TMP/p82-claim-main.log" 2>&1 \
  && ok "P82 1.1 主工作树里的 --from dev3 退出码 0" || bad "P82 1.1 主工作树里的 --from dev3 失败"
assert_eq "P82 1.1 主工作树里 --from 也原样记录" "$(p82_last)" "agent:dev3 · P82-SUMMARY-1"
assert_has "$TMP/p82-claim-main.log" "'pm'" "P82 1.1 分歧点名运行时目录的座位（pm）"

# ── 1.4 未解析 = 拒绝：非 0 + 零收件箱行 + 零 knock + 输出点名 --from ─────────────────────────
P82_BEFORE="$(p82_ck)"
if p82 "$P82_OUT" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-refuse.log" 2>&1; then
  bad "P82 1.4 项目外的工作树里 notify 应当拒绝（当前退出码 0）"
else
  ok "P82 1.4 项目外的工作树（不在 .worktrees/ 下）→ 非 0 退出"
fi
assert_eq "P82 1.4 拒绝时零写入：收件箱逐字节不变" "$(p82_ck)" "$P82_BEFORE"
assert_eq "P82 1.4 拒绝时零 knock：队列里没有条目" \
  "$(find "$P82R/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_has "$TMP/p82-refuse.log" "发送者无法解析" "P82 1.4 拒绝时说明原因"
assert_has "$TMP/p82-refuse.log" "--from" "P82 1.4 拒绝输出点名 --from（唯一的出路）"
assert_not "$TMP/p82-refuse.log" "agent:pm" "P82 1.4 绝不静默退回 pm（输出里没有 agent:pm 的假声明）"

# ── 1.5（前半）--from 是项目外目录的出路 ─────────────────────────────────────────────────────
p82 "$P82_OUT" notify pm --from dev3 --from-file "$TMP/p82-sum.txt" >"$TMP/p82-out-claim.log" 2>&1 \
  && ok "P82 1.5 项目外的工作树里显式 --from 是出路（退出码 0）" || bad "P82 1.5 项目外的工作树里显式 --from 失败"
assert_eq "P82 1.5 显式声明原样记录" "$(p82_last)" "agent:dev3 · P82-SUMMARY-1"

# ── 1.6 收件人仍然只是收件人：文件名 + 敲门目标；发送者照旧是 worker ──────────────────────────
p82 "$P82_WT" notify dev --from-file "$TMP/p82-sum.txt" >"$TMP/p82-dev.log" 2>&1 \
  && ok "P82 1.6 worker → dev 的 notify 退出码 0" || bad "P82 1.6 worker → dev 的 notify 失败"
assert_eq "P82 1.6 收件人 = 文件名：行落在 inbox/dev.md" "$(p82_last "$P82R/docs/team/inbox/dev.md")" "agent:dev2 · P82-SUMMARY-1"
assert_has "$P82R/docs/team/inbox/dev.md" "agent:dev2" "P82 1.6 dev 的收件箱里发送者仍是 worker（不是 pm）"

# ── 含糊输入：位置摘要与 --from-file 同时给 → 拒绝（摘要只有一个来源，不静默挑一个）─────────
P82_BEFORE2="$(p82_ck)"
if p82 "$P82_WT" notify pm "positional summary" --from-file "$TMP/p82-sum.txt" >"$TMP/p82-mixed.log" 2>&1; then
  bad "P82：位置摘要与 --from-file 同时给应当被拒（当前退出码 0）"
else
  ok "P82：位置摘要与 --from-file 同时给 → 非 0（含糊输入不静默挑一个）"
fi
assert_eq "P82：含糊输入拒绝时零写入" "$(p82_ck)" "$P82_BEFORE2"
assert_has "$TMP/p82-mixed.log" "摘要只有一个来源" "P82：拒绝时说清原因"

# ── 1.5（后半）三处同名：收件箱行 / knock 文本 / 条目的 from:（假 tmux + 脏 PM 输入框）─────────
P82_SHIM="$TMP/p82-shim"; mkdir -p "$P82_SHIM"
P82_BOX="$TMP/p82-box-draft"
printf '%s\n' "$(printf '%.0s─' $(seq 1 80))" "" "半句草稿 half a sentence" "" " k3  Kimi Coding  max" "$(printf '%.0s─' $(seq 1 80))" "footer" > "$P82_BOX"
cp "$(command -v sleep)" "$TMP/p82-pm-bin" 2>/dev/null || cp /bin/sleep "$TMP/p82-pm-bin"
( cd "$P82R" && exec "$TMP/p82-pm-bin" 300 ) & P82_PM_PID=$!
printf '%s\n' "$P82_PM_PID" > "$TMP/p82-pm.pid"
mkdir -p "$P82R/.pi/team/state"; printf '%s\n' "$P82_PM_PID" > "$P82R/.pi/team/state/pm.pid"
cat > "$P82_SHIM/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$TMP/p82-tmux.log"
case "\$*" in
  *cursor_y*) printf '2\n'; exit 0 ;;
  *capture-pane*) cat "$P82_BOX"; exit 0 ;;
  *pane_current_command*) printf 'p82-pm-bin\n'; exit 0 ;;
  *pane_id*) printf '%%1\n'; exit 0 ;;
  *pane_pid*) cat "$TMP/p82-pm.pid"; exit 0 ;;
  *bracket_paste_flag*) printf '1\n'; exit 0 ;;
  *window_name*) printf 'pm\n'; exit 0 ;;
  *session_name*) printf '%s\n' "$P82_SES"; exit 0 ;;
  *list-windows*) printf 'pm\n'; exit 0 ;;
  *has-session*) exit 0 ;;
esac
exit 0
EOF
chmod +x "$P82_SHIM/tmux"
rm -rf "$P82R/.pi/team/state/outbox"
( cd "$P82_WT" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_AGENT -u TEAM_SKILL_DIR \
    PATH="$P82_SHIM:$PATH" TMUX="$P82_SES,0,0" TEAM_NOTIFY_TMUX=1 TEAM_PM_BIN="$TMP/p82-pm-bin" \
    $TEAM notify pm --from-file "$TMP/p82-sum.txt" ) >"$TMP/p82-knock.log" 2>&1 \
  && ok "P82 1.5 脏 PM 框里的 notify 退出码 0" || bad "P82 1.5 脏 PM 框里的 notify 失败"
assert_has "$TMP/p82-knock.log" "敲门入队" "P82 1.5 脏框 → knock 入队（不是打字）"
assert_not "$TMP/p82-tmux.log" "send-keys" "P82 1.5 脏框：一个键都没发"
P82_ENTRY="$(find "$P82R/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | head -1)"
assert_file "$P82_ENTRY" "P82 1.5 队列里有这条 knock 条目"
assert_eq "P82 1.5 队列里恰好一条" "$(find "$P82R/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
assert_has "$P82_ENTRY" "from: dev2" "P82 1.5 条目的 from: 是发送者（不是收件人 pm）"
assert_has "$P82_ENTRY" "[manual] agent:dev2 · P82-SUMMARY-1" "P82 1.5 knock 文本与 from: / 收件箱行同名"
kill "$P82_PM_PID" 2>/dev/null || true

# ── 3.1/3.2 两条路同名：[manual]（CLI）与 [auto]（扩展 settle）同一个运行时上下文 ────────────
# 判据是**提取两行的 `agent:<名字>` token 比较**（不是子串计数）：一行还写 `agent:pm` 就必须红。
# 3.2 把窗口名故意报成 `dev`（cwd 仍是 .worktrees/dev2）：窗口是可改的 UI 状态，两条路都得说 dev2。
if [ -z "$TS_RUNNER" ]; then
  cond_skip "P82 3.1/3.2 两条路同名（需要 node 类型剥离或 bun 跑 TS 扩展）"
else
  P82_WIN_FILE="$TMP/p82-ext-window"
  P82_EXT_LOG="$TMP/p82-ext.log"
  P82_EXT_SHIM="$TMP/p82-ext-shim"; mkdir -p "$P82_EXT_SHIM"
  # 假 tmux：窗口/会话名从**文件**读（bun 的 execFileSync 不把运行期 process.env 改动传给子进程）
  cat > "$P82_EXT_SHIM/tmux" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *window_name*)  cat "$P82_WIN_FILE" 2>/dev/null || printf 'dev\n' ;;
  *session_name*) printf '%s\n' "$P82_SES" ;;
  *pane_current_command*) printf 'pi\n' ;;
esac
exit 0
EOF
  chmod +x "$P82_EXT_SHIM/tmux"
  cat > "$TMP/p82-ext.mjs" <<'EOS'
import { existsSync, readFileSync } from 'node:fs'
const [, , ext, root, wt] = process.argv
const mod = await import(ext)
const handlers = {}
mod.default({ on: (n, f) => { (handlers[n] ||= []).push(f) }, registerCommand: () => {}, registerTool: () => {}, sendMessage: () => {} })
process.env.TMUX_PANE = 'p82-ext-pane'          // 有 pane 才会去问窗口名（3.2 的对抗性就在这里）
const last = { role: 'assistant', stopReason: 'stop', content: [{ text: String(process.env.P82_EXT_TEXT ?? '') }] }
for (const fn of handlers.agent_settled ?? []) await fn({}, { cwd: wt, sessionManager: { getEntries: () => [{ message: last }] } })
EOS
  p82_token() { tail -1 "$1" 2>/dev/null | sed -n 's/.*\(agent:[^ ]*\) ·.*/\1/p'; }
  p82_pair_reset() { # 一个运行时上下文一个回合：清掉上一回合的收件箱/去重/日志
    rm -f "$P82R/docs/team/inbox/pm.md" "$P82R/docs/team/inbox/dev2.md" "$P82R/docs/team/inbox/dev.md"
    rm -f "$P82R/.pi/team/state/notify-dedup"
    : > "$P82_EXT_LOG"
  }
  # 3.1 窗口名与席位一致（dev2）
  printf 'dev2\n' > "$P82_WIN_FILE"
  p82_pair_reset
  printf 'P82-PAIR-A\n' > "$TMP/p82-sum.txt"
  p82 "$P82_WT" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-pair-cli-a.log" 2>&1 || true
  P82_TOKEN_CLI="$(p82_token "$P82_INBOX")"
  P82_EXT_TEXT='P82-PAIR-A' PATH="$P82_EXT_SHIM:$PATH" "$TS_RUNNER" "$TMP/p82-ext.mjs" \
    "$SKILL_DIR/extension/team-notify.ts" "$P82R" "$P82_WT" >"$TMP/p82-ext-a.log" 2>&1 || true
  P82_TOKEN_EXT="$(p82_token "$P82R/docs/team/inbox/dev2.md")"
  assert_eq "P82 3.1 [manual] 这一路的发送者（CLI，窗口 dev2）" "$P82_TOKEN_CLI" "agent:dev2"
  assert_eq "P82 3.1 [auto] 这一路的发送者（扩展，窗口 dev2）" "$P82_TOKEN_EXT" "agent:dev2"
  assert_eq "P82 3.1 两条路的 agent:<名字> token 相同（一个运行时上下文）" "$P82_TOKEN_CLI" "$P82_TOKEN_EXT"
  # 3.2 对抗性窗口：扩展被告知窗口叫 dev，而 cwd 是 .worktrees/dev2
  printf 'dev\n' > "$P82_WIN_FILE"
  p82_pair_reset
  printf 'P82-PAIR-B\n' > "$TMP/p82-sum.txt"
  p82 "$P82_WT" notify pm --from-file "$TMP/p82-sum.txt" >"$TMP/p82-pair-cli-b.log" 2>&1 || true
  P82_TOKEN_CLI_B="$(p82_token "$P82_INBOX")"
  P82_EXT_TEXT='P82-PAIR-B' PATH="$P82_EXT_SHIM:$PATH" "$TS_RUNNER" "$TMP/p82-ext.mjs" \
    "$SKILL_DIR/extension/team-notify.ts" "$P82R" "$P82_WT" >"$TMP/p82-ext-b.log" 2>&1 || true
  P82_TOKEN_EXT_B="$(p82_token "$P82R/docs/team/inbox/dev2.md")"
  assert_eq "P82 3.2 窗口撒谎（报 dev）时 [manual] 这一路仍是 dev2" "$P82_TOKEN_CLI_B" "agent:dev2"
  assert_eq "P82 3.2 窗口撒谎（报 dev）时 [auto] 这一路仍是 dev2（窗口前：dev2）" "$P82_TOKEN_EXT_B" "agent:dev2"
  assert_eq "P82 3.2 两条路在对抗性窗口下仍然同名" "$P82_TOKEN_CLI_B" "$P82_TOKEN_EXT_B"
  assert_not_file "$P82R/docs/team/inbox/dev.md" "P82 3.2 窗口名没有变成发送者（不存在 inbox/dev.md）"
  assert_has "$P82_EXT_LOG" "window dev ignored: the runtime directory names dev2" "P82 3.2 扩展日志点名被忽略的窗口"
fi

section "48 · P91 合并后的「分支又动了」核对（D49 的另一半）"
# 事实（D49，2026-09-22）：P82 被 squash 合并（16 个提交）之后，作者又在分支上提交了两条**只动记录**
# 的提交 → main 的记录停在旧版。P76 的 --pre-merge 看不到（它查合并**前**工作树里未入账的文件）。
# 本节钉住合并后的那半：`team review <ID> --post-merge` 把 `main..task/<分支>` 分成三条线——
#   <docs>/ 有差异 → 「记录有更新：取它」+ 可粘贴的 `git checkout <分支> -- <路径>`（非删除）；退出 0；
#   skills/ 有差异 → 更响「代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁」（非零退出）；
#   两条都有 → 记录照列、代码定退出码。
# 判定的关键不是差异，而是**谁的差异**：main 上别的任务合进来后，`main..<分支>` 会把别人的工作当成
# 「分支删掉了它们」—— 照字面报出来就是假红（还会劝 PM「取别人的记录」，取回来等于删掉别人的记录）。
# 所以逐路径做三路比较（base = merge-base）：分支没动过 = main 一侧；main 没动过 = 分支新增；两边都
# 动过时比 blob 历史（main 的版本在分支历史里 = 分支新增；分支的版本在 main 历史里 = 它只是落后；两边
# 都不在 = 版本对不上，报出来看一眼）。④ 专门钉反假红，⑥ 钉「版本对不上」不静默丢。
P91R="$TMP/p91repo"; rm -rf "$P91R"; mkdir -p "$P91R/skills"
( cd "$P91R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && echo '# p91' > README.md && echo 'v1' > skills/x.sh && git add -A && git commit -qm init ) >/dev/null 2>&1
P91_SES="teamsmith-smoke-p91-$$"
( cd "$P91R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$P91_SES" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/p91-init.log" 2>&1 \
  && ok "P91 夹具仓库 init 成功" || bad "P91 夹具仓库 init 失败（见 $TMP/p91-init.log）"
( cd "$P91R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/p91-paths.json" 2>&1 || true
assert_eq "P91 隔离：team paths 的 main_root 就是 P91 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/p91-paths.json")" "$P91R"
p91() { ( cd "$P91R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
if git -C "$P91R" add -A >/dev/null 2>&1 && git -C "$P91R" commit -qm "chore: init scaffold" >/dev/null 2>&1; then
  ok "P91 夹具：init 脚手架已入账"
else
  bad "P91 夹具：init 脚手架提交失败"
fi
p91_commit() { # <worktree> <message>
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "$2" >/dev/null 2>&1
}
p91_squash() { # <branch> <message>：主工作树里做一次 squash 合并（夹具模拟 PM 的合并步）
  ( cd "$P91R" && git merge -q --squash "$1" && git -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "$2" ) >/dev/null 2>&1
}
P91_BR="task/P91-smoke"; P91_WT="$P91R/.worktrees/dev"
git -C "$P91R" worktree add -q -b "$P91_BR" "$P91_WT" main >/dev/null 2>&1
mkdir -p "$P91R/.pi/team/state"
printf 'window=dev\ntask=P91\nbranch=%s\n' "$P91_BR" > "$P91R/.pi/team/state/dev.env"
[ -e "$P91_WT/.git" ] && ok "P91 夹具：任务工作树就位（.worktrees/dev @ $P91_BR）" || bad "P91 夹具：工作树起不来（后续断言无意义）"

# ── ① 合并后只动了记录 → 「记录有更新：取它」+ 可粘贴修法；退出 0 ────────────────────────────
echo 'v2' > "$P91_WT/skills/x.sh"
echo 'record-v1' > "$P91_WT/docs/team/DECISIONS.md"
p91_commit "$P91_WT" "P91: pre-merge work (code + record)"
p91_squash "$P91_BR" "P91: apply fixture"
# 刚合并完（分支没再动）：两边的树相同 → 「没有合并后新增」，且不报代码红
p91 $TEAM review P91 --post-merge >"$TMP/p91-pristine.log" 2>&1; P91_RC0=$?
assert_eq "P91 ①：刚合并完（分支没再动）→ 退出码 0" "$P91_RC0" "0"
assert_has "$TMP/p91-pristine.log" "两边的树相同" "P91 ①：说清两边一致（没有合并后新增）"
printf 'record-v2-late\n' >> "$P91_WT/docs/team/DECISIONS.md"
mkdir -p "$P91_WT/docs/team/reports"; printf '# P91 late report\n' > "$P91_WT/docs/team/reports/P91-dev.md"
p91_commit "$P91_WT" "docs(P91): late record"
P91_HEAD0="$(git -C "$P91R" rev-parse HEAD)"
p91 $TEAM review P91 --post-merge >"$TMP/p91-records.log" 2>&1; P91_RC1=$?
assert_eq "P91 ①：合并后只动了记录 → 退出码 0（能当收尾核对）" "$P91_RC1" "0"
assert_has "$TMP/p91-records.log" "记录有更新" "P91 ①：说清是记录有更新"
assert_has "$TMP/p91-records.log" "docs/team/reports/P91-dev.md" "P91 ①：点名晚到的报告（新文件）"
assert_has "$TMP/p91-records.log" "docs/team/DECISIONS.md" "P91 ①：点名晚到的记录改动（已跟踪文件）"
assert_has "$TMP/p91-records.log" "git -C $P91R checkout $P91_BR -- docs/team/DECISIONS.md docs/team/reports/P91-dev.md" \
  "P91 ①：修法是一条可粘贴的 git checkout（列出全部路径）"
assert_has "$TMP/p91-records.log" "review P91 --post-merge" "P91 ①：给出取完后再看一次的下一步"
assert_not "$TMP/p91-records.log" "代码有未合并的改动" "P91 ①：不误报代码（合进去的 skills/x.sh 不算新增）"
assert_eq "P91 ①：只读核对不替 PM 取记录（main 的 HEAD 不动）" "$(git -C "$P91R" rev-parse HEAD)" "$P91_HEAD0"

# ── ② 合并后又动了代码 → 更响 + 非零（记录照列）──────────────────────────────────────────────
echo 'v3-late' > "$P91_WT/skills/x.sh"
p91_commit "$P91_WT" "feat(P91): late code"
p91 $TEAM review P91 --post-merge >"$TMP/p91-code.log" 2>&1; P91_RC2=$?
assert_eq "P91 ②：合并后动了代码 → 非零退出（不能只取记录）" "$P91_RC2" "1"
assert_has "$TMP/p91-code.log" "代码有未合并的改动 —— 不能只取记录，必须重新合并并重跑门禁" \
  "P91 ②：更响地点名代码必须重新合并"
assert_has "$TMP/p91-code.log" "skills/x.sh" "P91 ②：点名未合并的代码路径"
assert_has "$TMP/p91-code.log" "重新合并这条分支（squash 或新 PR）+ 重跑门禁" "P91 ②：给出口径（重新合并 + 重跑门禁）"
assert_has "$TMP/p91-code.log" "记录也有更新" "P91 ②：代码红时记录仍然被点名（不丢信息）"

# ── ③ 反向（可证伪）：影子掉「合并后新增」判定 = 「检查被删除」的形状 → ②的夹具被静悄悄放过 ──────
P91_PROBE="$TMP/p91-probe.sh"
cat > "$P91_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <repo> <shadow>：shadow=1 = 影子掉合并后新增判定（检查被删除的形状）
set -u
SKILL_DIR="$1"; REPO="$2"; SHADOW="${3:-0}"
cd "$REPO"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SKILL_DIR
. "$SKILL_DIR/scripts/lib/common.sh"
for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
team_load_config >/dev/null 2>&1 || true
[ "$SHADOW" = "1" ] && team_review_postmerge_paths() { :; }
team_cmd_review P91 --post-merge
EOS
chmod +x "$P91_PROBE"
bash "$P91_PROBE" "$SKILL_DIR" "$P91R" 0 >"$TMP/p91-probe-green.log" 2>&1; P91_RC3=$?
assert_eq "P91 ③：探针（同源）照旧非零退出" "$P91_RC3" "1"
assert_has "$TMP/p91-probe-green.log" "代码有未合并的改动" "P91 ③：探针照旧报代码红"
assert_has "$TMP/p91-probe-green.log" "skills/x.sh" "P91 ③：探针照旧点名未合并的代码路径"
bash "$P91_PROBE" "$SKILL_DIR" "$P91R" 1 >"$TMP/p91-probe-shadow.log" 2>&1; P91_RC4=$?
assert_eq "P91 ③ 反向：检查被影子掉 → 退出码 0（②的夹具被静悄悄放过）" "$P91_RC4" "0"
assert_not "$TMP/p91-probe-shadow.log" "代码有未合并的改动" "P91 ③ 反向：假绿的形状（更响的那句不见了）"

# ── ④ main 上又合了别人的工作（陈旧分支）→ 只点名真正晚到的那条记录，别人的一个都不许进来 ────────
P92_BR="task/P92-forker"; P92_WT="$P91R/.worktrees/dev2"
git -C "$P91R" worktree add -q -b "$P92_BR" "$P92_WT" main >/dev/null 2>&1
echo 'p92-pre' > "$P92_WT/skills/y.sh"
p91_commit "$P92_WT" "P92: pre-merge work"
p91_squash "$P92_BR" "P92: apply fixture"
# 「别人的任务」：main 上再落一份工作（新文件 + 别人的记录 + 与分支同路径 x.sh 的改动）
echo 'other-task' > "$P91R/skills/other.sh"
echo 'v3-other' > "$P91R/skills/x.sh"
printf 'other report\n' > "$P91R/docs/team/reports/OTHER.md"
p91_commit "$P91R" "P99: another task lands on main"
mkdir -p "$P92_WT/docs/team/reports"; printf '# P92 late\n' > "$P92_WT/docs/team/reports/P92-dev.md"
p91_commit "$P92_WT" "docs(P92): late record"
printf 'window=dev\ntask=P92\nbranch=%s\n' "$P92_BR" > "$P91R/.pi/team/state/dev.env"
p91 $TEAM review P92 --post-merge >"$TMP/p91-stale.log" 2>&1; P91_RC5=$?
assert_eq "P91 ④ 陈旧分支：只有记录晚到 → 退出码 0" "$P91_RC5" "0"
assert_has "$TMP/p91-stale.log" "docs/team/reports/P92-dev.md" "P91 ④：点名真正晚到的那条记录"
assert_not "$TMP/p91-stale.log" "skills/other.sh" \
  "P91 ④ 反假红：别人的新代码文件不能被当成「分支删掉了它」"
assert_not "$TMP/p91-stale.log" "docs/team/reports/OTHER.md" \
  "P91 ④ 反假红：别人的记录不能被劝「取它」（取回来会把别人的记录删掉）"
assert_not "$TMP/p91-stale.log" "skills/x.sh" \
  "P91 ④ 反假红：分支没动过的、main 一侧的改动不算它的新增"
assert_not "$TMP/p91-stale.log" "代码有未合并的改动" "P91 ④ 反假红：不该报代码红"

# ── ⑤ 把记录取到 main 后再核对 → 「没有合并后新增」（收敛，不再劝取）────────────────────────────
git -C "$P91R" checkout "$P92_BR" -- docs/team/reports/P92-dev.md >/dev/null 2>&1
p91_commit "$P91R" "docs(team): take P92 late record"
p91 $TEAM review P92 --post-merge >"$TMP/p91-clean.log" 2>&1; P91_RC6=$?
assert_eq "P91 ⑤：取走记录后再核对 → 退出码 0" "$P91_RC6" "0"
assert_has "$TMP/p91-clean.log" "没有合并后新增" "P91 ⑤：明确说没有合并后新增（收敛）"

# ── ⑥ 两边都动过、版本对不上（晚到的改动撞上别人的改动）→ 非零 + 点名，不静默丢 ────────────────
# x.sh：base=v1、分支=v2（已合并）、main=v3-other（别人的 P99）、分支晚到=v4-late；
# main 的 v3-other 不在分支历史里，分支的 v4-late 也不在 main 历史里 → 只能报出来让人看一眼。
echo 'v4-late' > "$P92_WT/skills/x.sh"
p91_commit "$P92_WT" "feat(P92): late code on a path another task moved"
p91 $TEAM review P92 --post-merge >"$TMP/p91-unclear.log" 2>&1; P91_RC7=$?
assert_eq "P91 ⑥：版本对不上 → 非零退出（不静默丢）" "$P91_RC7" "1"
assert_has "$TMP/p91-unclear.log" "版本对不上" "P91 ⑥：点名「版本对不上」"
assert_has "$TMP/p91-unclear.log" "skills/x.sh" "P91 ⑥：点名那条对不上的路径"
assert_has "$TMP/p91-unclear.log" "重新合并这条分支（squash 或新 PR）+ 重跑门禁" "P91 ⑥：给出口径（重新合并 + 重跑门禁）"
assert_not "$TMP/p91-unclear.log" "checkout $P92_BR -- skills/x.sh" "P91 ⑥：不劝「直接取这一版」（会覆盖别人的改动）"

# ── ⑦ 含混用法拒绝（它不是复验，也不是合并前检查）────────────────────────────────────────────
printf 'window=dev\ntask=P91\nbranch=%s\n' "$P91_BR" > "$P91R/.pi/team/state/dev.env"
p91 $TEAM review P91 --post-merge --dir "$TMP/p91-nope" >"$TMP/p91-mixed.log" 2>&1; P91_RC8=$?
assert_eq "P91 ⑦：--post-merge 与 --dir 同用被拒（它不跑复验）" "$P91_RC8" "2"
assert_has "$TMP/p91-mixed.log" "不与 --dir 同用" "P91 ⑦：拒绝时说明原因"
p91 $TEAM review P91 --pre-merge --post-merge >"$TMP/p91-both.log" 2>&1; P91_RC9=$?
assert_eq "P91 ⑦：--pre-merge 与 --post-merge 不同用（一个合并前、一个合并后）" "$P91_RC9" "2"
assert_has "$TMP/p91-both.log" "不同用" "P91 ⑦：拒绝时说明原因（合并前/后）"
# 其余复验旋钮同样不适用（含混用法一律拒绝，不猜）
for P91_FLAG in --no-gates --strong --allow-unresolved-branch; do
  p91 $TEAM review P91 --post-merge "$P91_FLAG" >"$TMP/p91-mixed$P91_FLAG.log" 2>&1; P91_RCF=$?
  assert_eq "P91 ⑦：--post-merge 与 $P91_FLAG 同用被拒" "$P91_RCF" "2"
  assert_has "$TMP/p91-mixed$P91_FLAG.log" "不与 $P91_FLAG 同用" "P91 ⑦：$P91_FLAG 的拒绝点名原因"
done
p91 $TEAM review P91 --post-merge --branch main >"$TMP/p91-mixed-branch.log" 2>&1; P91_RCB=$?
assert_eq "P91 ⑦：--post-merge 与 --branch 同用被拒（分支自动定位）" "$P91_RCB" "2"
assert_has "$TMP/p91-mixed-branch.log" "不与 --branch 同用" "P91 ⑦：--branch 的拒绝点名原因"

# ── ⑧ 定位不到分支 → fail closed（不把「没检查」报成「没问题」）──────────────────────────────
git -C "$P91R" worktree remove --force "$P91_WT" >/dev/null 2>&1
git -C "$P91R" branch -D "$P91_BR" >/dev/null 2>&1
p91 $TEAM review P91 --post-merge >"$TMP/p91-noref.log" 2>&1; P91_RC10=$?
assert_eq "P91 ⑧：分支解析不到 → 非零（fail closed，不假装核对过）" "$P91_RC10" "2"
assert_has "$TMP/p91-noref.log" "解析不到" "P91 ⑧：拒绝时点名「无法核对」"
assert_not "$TMP/p91-noref.log" "没有合并后新增" "P91 ⑧：不把「没检查」报成「没问题」"

# ---------------------------------------------------------------- 49. P94 现场行数为 0（P88 的 F1）
# TEAM_AGENT_SCENE_LINES=0 的语义：**按配置不打印现场块**（一句显式措辞），命令必须正常返回。
# 旧实现把 0 直接交给 `tail -n 0`：tail 立刻退出、什么都不读 → awk 写端吃 SIGPIPE → CLI 的
# `set -o pipefail` 把 rc=141 带出来，status 整体中止、席位段的现场块压根不出现（P88 的 F1，
# 与 P28 的 `printf | grep -q` 同族）。本节钉住：0 = rc=0 + 显式措辞 + 一行画面都不印（三个来源
# 都不读）；1/3/40 与既有断言逐字不变；第二层来源在场时守卫同样先于来源选择。红侧不靠产品开关：
# 把零守卫与读取器换回 P94 之前的形状（mutant 副本，append 覆盖）→ 同一份夹具翻回 rc=141。
section "49 · P94 现场行数为 0：按配置不打印画面（P88 的 F1）"
P94_A="p94w"; P94_ID="T9.94"; P94_ST="$REPO/.pi/team/state"
P94_TAIL="$P94_ST/dispatch-$P94_A-tail.txt"; P94_DEAD="$P94_ST/dispatch-$P94_A-pane-dead.txt"
mkdir -p "$P94_ST"
printf 'window=%s\ntask=%s\n' "$P94_A" "$P94_ID" > "$P94_ST/$P94_A.env"
p94_status() { # <行数|"-"> <输出文件> → 返回 CLI 的 rc（"-" = 不设旋钮，走默认 40）
  local n="$1" out="$2" rc=0
  if [ "$n" = "-" ]; then
    ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
        -u TEAM_AGENT -u TEAM_DOCS_DIR TEAM_AGENTS="$P94_A" \
        bash "$SKILL_DIR/scripts/team" status "$P94_ID" ) >"$out" 2>&1 || rc=$?
  else
    ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
        -u TEAM_AGENT -u TEAM_DOCS_DIR TEAM_AGENTS="$P94_A" TEAM_AGENT_SCENE_LINES="$n" \
        bash "$SKILL_DIR/scripts/team" status "$P94_ID" ) >"$out" 2>&1 || rc=$?
  fi
  return "$rc"
}
p94_scene() { grep '^    | ' "$1" 2>/dev/null | sed 's/^    | //'; }
# 560 KB 的尾屏文件（P88 实测的量级）：旧读取器在 `tail -n 0` 处必吃 SIGPIPE（awk 的输出远超管道缓冲）
{ awk 'BEGIN{for(i=1;i<=8000;i++) printf "P94-PAD-%05d %s\n", i, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}'
  printf 'P94-TAIL-MARK-LAST\n'; } > "$P94_TAIL"

# ── ① 绿侧（本单的红转绿就在这条）：0 = rc=0 + 显式措辞 + 不打印画面 ────────────────────
p94_status 0 "$TMP/p94-zero.log"; P94_RC=$?
assert_eq "P94 ①：TEAM_AGENT_SCENE_LINES=0 → rc=0（旧实现 rc=141 SIGPIPE 中止，P88 的 F1）" "$P94_RC" "0"
assert_has "$TMP/p94-zero.log" "现场：（按 TEAM_AGENT_SCENE_LINES=0：不打印画面）" "P94 ①：显式措辞点名配置"
assert_eq "P94 ①：一行画面都不打印" "$(p94_scene "$TMP/p94-zero.log" | wc -l | tr -d ' ')" "0"
assert_not "$TMP/p94-zero.log" "P94-TAIL-MARK-LAST" "P94 ①：来源里的内容一个字都不出现"
assert_not "$TMP/p94-zero.log" "来源在但没有画面内容" "P94 ①：不是「取最后 0 行」的空块措辞"
assert_not "$TMP/p94-zero.log" "dispatch-$P94_A-tail.txt（agent 退出时 harness 自抓的尾屏）" "P94 ①：连来源行都没印（读取器压根没被走到）"

# ── ② 边界：1/3/40 与既有语义逐字不变（守卫只认 0）────────────────────────────────────
p94_status 1 "$TMP/p94-n1.log"; P94_RC=$?
assert_eq "P94 ②：n=1 仍正常返回" "$P94_RC" "0"
assert_eq "P94 ②：n=1 = 最后 1 行（逐字节）" "$(p94_scene "$TMP/p94-n1.log")" "$(tail -n 1 "$P94_TAIL")"
assert_has "$TMP/p94-n1.log" "最后 1 行（去尾空行）" "P94 ②：n=1 的声明照旧（P75 的措辞不带改）"
p94_status 3 "$TMP/p94-n3.log"; P94_RC=$?
assert_eq "P94 ②：n=3 仍正常返回" "$P94_RC" "0"
assert_eq "P94 ②：n=3 = 最后 3 行（逐字节）" "$(p94_scene "$TMP/p94-n3.log")" "$(tail -n 3 "$P94_TAIL")"
p94_status - "$TMP/p94-default.log"; P94_RC=$?
assert_eq "P94 ②：默认（不设旋钮）仍正常返回" "$P94_RC" "0"
assert_eq "P94 ②：默认 40 行 = 最后 40 行（逐字节）" "$(p94_scene "$TMP/p94-default.log")" "$(tail -n 40 "$P94_TAIL")"
assert_has "$TMP/p94-default.log" "最后 40 行（去尾空行）" "P94 ②：默认声明与 P75 §43④ 逐字一致"

# ── ③ 红侧（可证伪）：零守卫 + 读取器换回 P94 之前的形状 → 同一发命令翻回 rc=141 ──────────
P94_MUT="$TMP/p94-mut-skill"; rm -rf "$P94_MUT"; mkdir -p "$P94_MUT/scripts"
cp -a "$SKILL_DIR/scripts/team" "$SKILL_DIR/scripts/lib" "$P94_MUT/scripts/" >/dev/null 2>&1
cp -a "$SKILL_DIR/templates" "$SKILL_DIR/references" "$SKILL_DIR/SKILL.md" "$P94_MUT/" >/dev/null 2>&1
cat >> "$P94_MUT/scripts/lib/cmd-status.sh" <<'EOS'
# P94 突变（append 覆盖，原件逐字节未改）：P94 之前的形状 —— 读取器把 N 直接交给管道末尾的
# `tail -n N`（没有 N=0 护栏），且没有零守卫（0 照旧走来源选择，第三层立刻吃 SIGPIPE）。
team_status_tail_scene() { awk '{ if (NF) last = NR; line[NR] = $0 } END { for (i = 1; i <= last; i++) print line[i] }' "$1" | tail -n "$2"; }
team_seat_scene_zero_note() { return 1; }
EOS
P94_MUT_ADD="$(diff "$SKILL_DIR/scripts/lib/cmd-status.sh" "$P94_MUT/scripts/lib/cmd-status.sh" 2>/dev/null | grep -c '^> ' || true)"
assert_eq "P94 ③ 突变夹具：只多出 4 行覆盖（append；原件部分逐字节相同）" "$P94_MUT_ADD" "4"
( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    -u TEAM_AGENT -u TEAM_DOCS_DIR TEAM_AGENTS="$P94_A" TEAM_AGENT_SCENE_LINES=0 \
    bash "$P94_MUT/scripts/team" status "$P94_ID" ) >"$TMP/p94-mut.log" 2>&1
P94_MUT_RC=$?
assert_eq "P94 ③ 翻转：旧形状下同一发命令回到 rc=141（tail -n 0 → SIGPIPE 中止）" "$P94_MUT_RC" "141"
assert_not "$TMP/p94-mut.log" "按 TEAM_AGENT_SCENE_LINES=0：不打印画面" "P94 ③ 翻转：显式措辞消失（status 在席位段中止）"
assert_eq "P94 ③ 翻转：mutant 的现场块一行都没有" "$(p94_scene "$TMP/p94-mut.log" | wc -l | tr -d ' ')" "0"

# ── ④ 零守卫在**选来源之前**：第二层（dispatch-<agent>-pane-dead.txt）在场也一个都不读 ──────
rm -f "$P94_TAIL"
{
  printf 'seat: %s\nwindow: %s\ncaptured: 2026-01-01T00:00:00Z\nexit: signal=9\ndead_time: 2026-01-01 00:00:00 UTC\n' "$P94_A" "$P94_A"
  printf -- '--- scene ---\n'
  printf 'P94-CORPSE-1\nP94-CORPSE-2\n'
} > "$P94_DEAD"
p94_status 0 "$TMP/p94-zero-2nd.log"; P94_RC=$?
assert_eq "P94 ④：第二层在场时 n=0 也 rc=0" "$P94_RC" "0"
assert_has "$TMP/p94-zero-2nd.log" "按 TEAM_AGENT_SCENE_LINES=0：不打印画面" "P94 ④：同一句措辞（守卫在来源选择之前）"
assert_not "$TMP/p94-zero-2nd.log" "P94-CORPSE-1" "P94 ④：第二层的内容一个字都不出现"
assert_not "$TMP/p94-zero-2nd.log" "pane-dead.txt（dispatch 替换遗体前抓的现场）" "P94 ④：第二层的来源行也没印"
rm -f "$P94_DEAD" "$P94_ST/$P94_A.env"

# ---------------------------------------------------------------- 50. P95 合并基准 = 该任务的 squash 提交（P91 的精度细化）
# 现场（P91 的复验 + P82 真仓库实测）：`squash 合并 + PM 手工解冲突`之后，被解过冲突的文件必然「两边都动过」——
# 旧口径（vs main 的 tip）把它们报成「版本对不上 → 重新合并」，可那是解冲突，不是「代码没合并」。
# P95：基准换成**该任务的 squash 提交**（在 main 的提交信息里按既有约定定位：subject 以 `<ID>[: ]` 开头，
# 或带 `Agent:` trailer 且 subject 点名这个任务），后来者合进 main 的内容与解冲突那一版都不再计入；
# 分支有而合并提交没有的代码仍然非零；找不到（分支从未合并）→ 明说并回落旧口径；多个候选 → 取最新那个并说清。
# 红侧不靠产品开关：把「合并提交定位」影子掉（`team_review_postmerge_squash() { return 1; }`）= 旧口径，
# 同一份解冲突夹具必须翻回非零 —— 这就是 P95 修掉的那个假红（①组里的探针）。
section "50 · P95 合并基准 = 该任务的 squash 提交（解冲突不再假红）"
P95R="$TMP/p95repo"; rm -rf "$P95R"; mkdir -p "$P95R/skills"
( cd "$P95R" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && printf 'base-code\n' > skills/a.sh && git add -A && git commit -qm init ) >/dev/null 2>&1
P95_SES="teamsmith-smoke-p95-$$"
( cd "$P95R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "$P95_SES" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/p95-init.log" 2>&1 \
  && ok "P95 夹具：init 成功" || bad "P95 夹具：init 失败（见 $TMP/p95-init.log）"
( cd "$P95R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION $TEAM paths ) >"$TMP/p95-paths.json" 2>&1 || true
assert_eq "P95 隔离：team paths 的 main_root 就是 P95 夹具仓库" \
  "$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/p95-paths.json")" "$P95R"
p95() { ( cd "$P95R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
p95_commit() { # <repo|worktree> <message>
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "$2" >/dev/null 2>&1
}
p95_state() { printf 'window=dev\ntask=%s\nbranch=%s\n' "$1" "$2" > "$P95R/.pi/team/state/dev.env"; }
if git -C "$P95R" add -A >/dev/null 2>&1 && git -C "$P95R" commit -qm "chore: init scaffold" >/dev/null 2>&1; then
  ok "P95 夹具：init 脚手架已入账"
else
  bad "P95 夹具：init 脚手架提交失败"
fi
P95_BR="task/P95-confl"; P95_WT="$P95R/.worktrees/dev"
git -C "$P95R" worktree add -q -b "$P95_BR" "$P95_WT" main >/dev/null 2>&1
mkdir -p "$P95R/.pi/team/state"
p95_state P95 "$P95_BR"
[ -e "$P95_WT/.git" ] && ok "P95 夹具：任务工作树就位（.worktrees/dev @ $P95_BR）" || bad "P95 夹具：工作树起不来（后续断言无意义）"

# ── ① 解冲突形状（分支与 main 都动了同一行 / 都新建了同一个记录文件；PM 的 squash 用「两边都留」解掉）──
printf 'branch-code\n' > "$P95_WT/skills/a.sh"
mkdir -p "$P95_WT/docs/team"
printf 'dev-entry\n' > "$P95_WT/docs/team/NOTES.md"
p95_commit "$P95_WT" "P95: pre-merge work"
printf 'main-code\n' > "$P95R/skills/a.sh"
printf 'pm-entry\n' > "$P95R/docs/team/NOTES.md"
p95_commit "$P95R" "P99: another task lands on main"
( cd "$P95R" && git merge -q --squash "$P95_BR" >/dev/null 2>&1 || true
  printf 'main-code\nbranch-code\n' > skills/a.sh
  printf 'pm-entry\ndev-entry\n' > docs/team/NOTES.md
  git add -A >/dev/null 2>&1
  git -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "P95: apply fixture" ) >/dev/null 2>&1
P95_SQUASH="$(git -C "$P95R" rev-parse --short HEAD)"
mkdir -p "$P95_WT/docs/team/reports"; printf '# P95 late report\n' > "$P95_WT/docs/team/reports/P95-dev.md"
p95_commit "$P95_WT" "docs(P95): late record"
p95 $TEAM review P95 --post-merge >"$TMP/p95-confl.log" 2>&1; P95_RC0=$?
assert_eq "P95 ①：解冲突形状 + 晚到的记录 → 退出码 0（修前是假红）" "$P95_RC0" "0"
assert_has "$TMP/p95-confl.log" "基准 = 这个任务的 squash 提交" "P95 ①：抬头写明基准是那个合并提交"
assert_has "$TMP/p95-confl.log" "$P95_SQUASH" "P95 ①：抬头点名那个 squash 提交（短 sha）"
assert_not "$TMP/p95-confl.log" "未找到这个任务的合并提交" "P95 ①：定位到了合并提交（没走回落）"
assert_has "$TMP/p95-confl.log" "解冲突形状" "P95 ①：解冲突形状被单独点出来（不是「代码没合并」）"
assert_has "$TMP/p95-confl.log" "skills/a.sh" "P95 ①：点名被解过冲突的代码路径"
assert_has "$TMP/p95-confl.log" "docs/team/NOTES.md" "P95 ①：点名被解过冲突的记录路径"
assert_has "$TMP/p95-confl.log" "记录有更新" "P95 ①：晚到的记录照旧说清「取它」"
assert_has "$TMP/p95-confl.log" "docs/team/reports/P95-dev.md" "P95 ①：点名晚到的报告（新文件）"
assert_not "$TMP/p95-confl.log" "代码有未合并的改动" "P95 ① 反假红：解冲突的代码路径不报「代码没合并」"
assert_not "$TMP/p95-confl.log" "重新合并这条分支" "P95 ① 反假红：不劝重合并"

# ── ①红侧（可证伪）：同一个夹具、把基准定位影子掉（= 旧口径 vs main 的 tip）→ 假红重现 ─────────
P95_PROBE="$TMP/p95-probe.sh"
cat > "$P95_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <repo> <shadow>：shadow=1 = 影子掉 P95 的「合并提交」定位（退回旧口径 = vs 保护分支的 tip）
set -u
SKILL_DIR="$1"; REPO="$2"; SHADOW="${3:-0}"
cd "$REPO"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SKILL_DIR
. "$SKILL_DIR/scripts/lib/common.sh"
for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
team_load_config >/dev/null 2>&1 || true
[ "$SHADOW" = "1" ] && team_review_postmerge_squash() { return 1; }
team_cmd_review P95 --post-merge
EOS
chmod +x "$P95_PROBE"
bash "$P95_PROBE" "$SKILL_DIR" "$P95R" 0 >"$TMP/p95-probe-green.log" 2>&1; P95_RC1=$?
assert_eq "P95 ① 探针（同源、不影子）：同一夹具照旧 0" "$P95_RC1" "0"
bash "$P95_PROBE" "$SKILL_DIR" "$P95R" 1 >"$TMP/p95-probe-old.log" 2>&1; P95_RC2=$?
assert_eq "P95 ① 翻转红侧：影子掉基准定位（= 旧口径）→ 同一夹具非零（P91 的假红重现）" "$P95_RC2" "1"
assert_has "$TMP/p95-probe-old.log" "版本对不上" "P95 ① 红侧：旧口径确实报「版本对不上」"
assert_has "$TMP/p95-probe-old.log" "重新合并这条分支" "P95 ① 红侧：旧口径确实劝「重新合并」"
assert_not "$TMP/p95-probe-old.log" "解冲突形状" "P95 ① 红侧：旧口径没有「解冲突形状」这个出口"

# ── ①b 收敛：把晚到的记录取到 main 后，不再劝第二次（解冲突形状仍在：那是 main 上不可取的合并版）──
git -C "$P95R" checkout "$P95_BR" -- docs/team/reports/P95-dev.md >/dev/null 2>&1
p95_commit "$P95R" "docs(team): take P95 late record"
p95 $TEAM review P95 --post-merge >"$TMP/p95-converged.log" 2>&1; P95_RC3=$?
assert_eq "P95 ①b：取走晚到的记录后再核对 → 0" "$P95_RC3" "0"
assert_not "$TMP/p95-converged.log" "记录有更新" "P95 ①b：取过的记录不再劝第二次"
assert_has "$TMP/p95-converged.log" "解冲突形状" "P95 ①b：解冲突形状仍在（合并版在 main 上，取不走）"

# ── ② 合并后又提交了代码（合并提交里没有的新文件）→ 仍非零（判定方向不变）──────────────────────
printf 'late\n' > "$P95_WT/skills/late.sh"
p95_commit "$P95_WT" "feat(P95): late code"
p95 $TEAM review P95 --post-merge >"$TMP/p95-latecode.log" 2>&1; P95_RC4=$?
assert_eq "P95 ②：合并后又动了代码 → 非零（这个方向一字不变）" "$P95_RC4" "1"
assert_has "$TMP/p95-latecode.log" "代码有未合并的改动" "P95 ②：点名「代码没合并」"
assert_has "$TMP/p95-latecode.log" "skills/late.sh" "P95 ②：点名那条晚到的代码路径"
assert_has "$TMP/p95-latecode.log" "重新合并这条分支" "P95 ②：给出口径（重新合并 + 重跑门禁）"

# ── ③ 未合并的分支 → 明说「未找到合并提交」+ 回落旧口径（代码差异仍非零）────────────────────
# ── ③ 未合并的分支（这个仓库里没有任何 `<ID>[: ]` / `Agent:` 约定的提交）→ 明说「未找到合并提交」+ 回落 ─
P95R3="$TMP/p95repo-unmerged"; rm -rf "$P95R3"; mkdir -p "$P95R3/skills"
( cd "$P95R3" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && printf 'base\n' > skills/a.sh && git add -A && git commit -qm init ) >/dev/null 2>&1
( cd "$P95R3" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "teamsmith-smoke-p95c-$$" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/p95c-init.log" 2>&1 \
  && ok "P95 夹具 C：init 成功" || bad "P95 夹具 C：init 失败（见 $TMP/p95c-init.log）"
( cd "$P95R3" && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "chore: init scaffold" ) >/dev/null 2>&1
P95C_BR="task/P95-unmerged"; P95C_WT="$P95R3/.worktrees/dev"
git -C "$P95R3" worktree add -q -b "$P95C_BR" "$P95C_WT" main >/dev/null 2>&1
mkdir -p "$P95R3/.pi/team/state"
printf 'window=dev\ntask=P95\nbranch=%s\n' "$P95C_BR" > "$P95R3/.pi/team/state/dev.env"
printf 'never-merged\n' > "$P95C_WT/skills/unmerged.sh"
p95_commit "$P95C_WT" "wip: this branch was never merged (no squash convention)"
( cd "$P95R3" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    bash "$SKILL_DIR/scripts/team" review P95 --post-merge ) >"$TMP/p95-unmerged.log" 2>&1; P95_RC5=$?
assert_eq "P95 ③：未合并的分支 → 回落旧口径，代码差异非零" "$P95_RC5" "1"
assert_has "$TMP/p95-unmerged.log" "未找到这个任务的合并提交" "P95 ③：明说找不到合并提交"
assert_has "$TMP/p95-unmerged.log" "回落" "P95 ③：明说回落与保护分支的 tip 比较"
assert_has "$TMP/p95-unmerged.log" "代码有未合并的改动" "P95 ③：回落后照旧报代码差异"
assert_has "$TMP/p95-unmerged.log" "skills/unmerged.sh" "P95 ③：点名那个未合并的代码路径"

# ── ④ 约定②：subject 不以 `<ID>[: ]` 开头、但带 `Agent:` trailer 且点名任务 → 也能定位基准 ─────
P95R2="$TMP/p95repo-agent"; rm -rf "$P95R2"; mkdir -p "$P95R2/skills"
( cd "$P95R2" && git init -q -b main && git config user.email smoke@teamsmith && git config user.name smoke \
    && printf 'base\n' > skills/a.sh && git add -A && git commit -qm init ) >/dev/null 2>&1
( cd "$P95R2" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
    $TEAM init --session "teamsmith-smoke-p95b-$$" --agents dev --vcs local --gates true --docs docs/team ) >"$TMP/p95b-init.log" 2>&1 \
  && ok "P95 夹具 B：init 成功" || bad "P95 夹具 B：init 失败（见 $TMP/p95b-init.log）"
p95b() { ( cd "$P95R2" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION "$@" ); }
( cd "$P95R2" && git add -A >/dev/null 2>&1 \
    && git -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "chore: init scaffold" ) >/dev/null 2>&1
P95B_BR="task/P95-agent"; P95B_WT="$P95R2/.worktrees/dev"
git -C "$P95R2" worktree add -q -b "$P95B_BR" "$P95B_WT" main >/dev/null 2>&1
mkdir -p "$P95R2/.pi/team/state"
printf 'window=dev\ntask=P95\nbranch=%s\n' "$P95B_BR" > "$P95R2/.pi/team/state/dev.env"
printf 'v2\n' > "$P95B_WT/skills/a.sh"
p95_commit "$P95B_WT" "P95: pre-merge work"
( cd "$P95R2" && git merge -q --squash "$P95B_BR" >/dev/null 2>&1 || true
  git add -A >/dev/null 2>&1
  git -c user.email=smoke@teamsmith -c user.name=smoke commit -qm "apply the P95 agent-path fixture" -m "Agent: dev-bob" ) >/dev/null 2>&1
mkdir -p "$P95B_WT/docs/team/reports"; printf '# P95B late\n' > "$P95B_WT/docs/team/reports/P95-dev.md"
p95_commit "$P95B_WT" "docs(P95): late record"
p95b $TEAM review P95 --post-merge >"$TMP/p95-agent-convention.log" 2>&1; P95_RC6=$?
assert_eq "P95 ④：subject 不按 <ID>[: ] 开头、带 Agent: trailer → 也能定位基准并退出 0" "$P95_RC6" "0"
assert_not "$TMP/p95-agent-convention.log" "未找到这个任务的合并提交" "P95 ④：Agent trailer 约定被认（没走回落）"
assert_has "$TMP/p95-agent-convention.log" "基准 = 这个任务的 squash 提交" "P95 ④：抬头写明基准"
assert_has "$TMP/p95-agent-convention.log" "记录有更新" "P95 ④：晚到的记录照旧「取它」"

# ── ⑤ 多个候选（两个 `<ID>[: ]` 提交）→ 取最新的那个当基准并说清（不静默）────────────────────
printf 'again\n' > "$P95R2/docs/team/AGAIN.md"
p95_commit "$P95R2" "P95: apply fixture again"
printf 'once-more\n' > "$P95R2/docs/team/ONCE-MORE.md"
p95_commit "$P95R2" "P95: apply fixture once more"
P95_AMBIG_NEW="$(git -C "$P95R2" rev-parse --short HEAD)"
p95b $TEAM review P95 --post-merge >"$TMP/p95-ambiguous.log" 2>&1
assert_has "$TMP/p95-ambiguous.log" "个候选合并提交" "P95 ⑤：多个候选被点名"
assert_has "$TMP/p95-ambiguous.log" "取最新的那个" "P95 ⑤：说清取的是最新的那个（不静默）"
assert_has "$TMP/p95-ambiguous.log" "$P95_AMBIG_NEW" "P95 ⑤：抬头点名最新那个候选（线性历史里它包含其余候选的内容）"
assert_not "$TMP/p95-ambiguous.log" "未找到这个任务的合并提交" "P95 ⑤：多候选不当作「未合并」"

# ── ⑥ 修法自带收敛（P96 的 F1，并入 P95）：把打印的那一行**原样**执行，重跑就已经是 0 ────────────────
# 「取记录」只 checkout 不提交的话，记录没进保护分支的树 → 下一次 --post-merge 报同一个非零（P96/F1）。
# 这里不手打等价命令：从输出里摘出**打印的那一行**，原样 bash -c 执行，再重跑。
# 红侧不靠产品开关：把「修法打印器」影子成旧形状（只 checkout、不提交）→ 同一串步骤立刻不收敛（断言里的
# 「旧形状取完再核对 → 仍非零」就是 P96/F1 那个病）。
# ② 在分支上留下的「晚到的代码」先退掉：⑥ 要的是「只有记录晚到」的形状（逐路径判定看的是树，不是历史）
git -C "$P95_WT" rm -q -f -- skills/late.sh >/dev/null 2>&1
p95_commit "$P95_WT" "revert(P95): retire the late code (⑥ needs the records-only shape)"
mkdir -p "$P95_WT/docs/team/reports"; printf '# P95 late report 2\n' > "$P95_WT/docs/team/reports/P95-dev-extra.md"
p95_commit "$P95_WT" "docs(P95): a second late record"
p95 $TEAM review P95 --post-merge >"$TMP/p95-take-cmd.log" 2>&1; P95_RC_T1=$?
assert_eq "P95 ⑥：又有晚到的记录 → 0 并打印修法" "$P95_RC_T1" "0"
P95_FIX="$(sed -n 's/^    \(git -C .*\)$/\1/p' "$TMP/p95-take-cmd.log")"
assert_eq "P95 ⑥：修法恰好一行（可原样粘贴）" "$(printf '%s\n' "$P95_FIX" | grep -c .)" "1"
assert_has_echo "$P95_FIX" "checkout" "P95 ⑥：修法里有 checkout"
assert_has_echo "$P95_FIX" "&& git -C" "P95 ⑥：修法是一条 && 链（不是分开的两条命令）"
assert_has_echo "$P95_FIX" "commit -m" "P95 ⑥：修法自带提交（不是只 checkout —— 收敛靠这一半）"
# 诱饵：main 的工作区里先暂存一处**与记录无关**的改动 —— 打印的命令只该提交它点名的路径
printf 'decoy\n' >> "$P95R/skills/a.sh"
git -C "$P95R" add -- skills/a.sh >/dev/null 2>&1
( cd "$P95R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    bash -c "$P95_FIX" ) >"$TMP/p95-take-run.log" 2>&1; P95_TAKE_RC=$?
assert_eq "P95 ⑥：原样执行打印的修法 → 成功" "$P95_TAKE_RC" "0"
assert_eq "P95 ⑥：取完之后 main 的树里就是分支那一版" \
  "$(git -C "$P95R" show HEAD:docs/team/reports/P95-dev-extra.md 2>/dev/null)" "# P95 late report 2"
assert_eq "P95 ⑥：这次提交只含它点名的路径" \
  "$(git -C "$P95R" diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null)" "docs/team/reports/P95-dev-extra.md"
assert_has_echo "$(git -C "$P95R" status --porcelain -- skills/a.sh)" "M  skills/a.sh" \
  "P95 ⑥：诱饵没被顺手提交（仍在暂存区）"
p95 $TEAM review P95 --post-merge >"$TMP/p95-take-converged.log" 2>&1; P95_RC_T2=$?
assert_eq "P95 ⑥：原样执行后立刻重跑 → 0（收敛）" "$P95_RC_T2" "0"
assert_not "$TMP/p95-take-converged.log" "记录有更新" "P95 ⑥：重跑不再劝取记录"
assert_has "$TMP/p95-take-converged.log" "解冲突形状" "P95 ⑥：解冲突形状仍在（与取记录无关）"
assert_has "$TMP/p95-take-converged.log" "$P95_SQUASH" "P95 ⑥：取记录的提交没混进 squash 候选（基准照旧）"

# ── ⑥红侧（可证伪）：把修法打印器影子成旧形状（只 checkout）→ 同一串步骤不再收敛 ─────────────────
printf '# P95 late report 3\n' > "$P95_WT/docs/team/reports/P95-dev-extra2.md"
p95_commit "$P95_WT" "docs(P95): a third late record"
P95_TAKE_PROBE="$TMP/p95-take-probe.sh"
cat > "$P95_TAKE_PROBE" <<'EOS'
#!/usr/bin/env bash
# <skill-dir> <repo>：把「取记录」的修法打印器影子成 P96/F1 之前的形状（只 checkout，不提交）
set -u
SKILL_DIR="$1"; REPO="$2"
cd "$REPO"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SKILL_DIR
. "$SKILL_DIR/scripts/lib/common.sh"
for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
team_load_config >/dev/null 2>&1 || true
team_review_postmerge_take_cmd() {
  local root="$1" branch="$2" id="$3"; shift 3
  local -a keep=(); local a
  for a in "$@"; do case "$a" in keep:*) keep+=("${a#keep:}") ;; esac; done
  printf '    git -C %s checkout %s --' "$root" "$branch"
  printf ' %q' "${keep[@]}"
  printf '\n'
  : "$id"
}
team_cmd_review P95 --post-merge
EOS
chmod +x "$P95_TAKE_PROBE"
bash "$P95_TAKE_PROBE" "$SKILL_DIR" "$P95R" >"$TMP/p95-take-old.log" 2>&1
P95_FIX_OLD="$(sed -n 's/^    \(git -C .*\)$/\1/p' "$TMP/p95-take-old.log")"
assert_has_echo "$P95_FIX_OLD" "checkout" "P95 ⑥ 红侧：影子出来的确实是修法（有 checkout）"
assert_not_echo "$P95_FIX_OLD" "commit -m" "P95 ⑥ 红侧：旧形状没有 commit（这就是 P96/F1）"
( cd "$P95R" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
    bash -c "$P95_FIX_OLD" ) >"$TMP/p95-take-old-run.log" 2>&1; P95_OLD_RC=$?
assert_eq "P95 ⑥ 红侧：旧形状原样执行也「成功」（git 层面没错，错在没提交）" "$P95_OLD_RC" "0"
p95 $TEAM review P95 --post-merge >"$TMP/p95-take-old-recheck.log" 2>&1; P95_RC_T3=$?
# 这个形状（只有记录晚到）的退出码本来就是 0 —— 病在**每次重跑都还在劝取同一条记录**（原地打转），
# 所以红侧的判据是那句劝告还在，不是退出码（P96 的 F1 原文：照字面执行会原地打转；提交后就收敛）。
assert_has "$TMP/p95-take-old-recheck.log" "记录有更新" "P95 ⑥ 红侧：旧形状取完再跑 → 还在劝取同一条记录（不收敛）"
assert_has "$TMP/p95-take-old-recheck.log" "docs/team/reports/P95-dev-extra2.md" "P95 ⑥ 红侧：劝的还是那个没进树的文件"
assert_eq "P95 ⑥ 红侧：main 的 tip 没动（取完也没入账）" \
  "$(git -C "$P95R" log -1 --format=%s)" "docs(team): take P95's late records from task/P95-confl"
assert_eq "P95 ⑥ 红侧：记录下来在暂存区里（checkout 只动了索引/工作区）" \
  "$(git -C "$P95R" status --porcelain -- docs/team/reports/P95-dev-extra2.md)" \
  "A  docs/team/reports/P95-dev-extra2.md"

# ═════════════════════════════════════════════════════════════════════
# 51 · 用法诚实性（P99 · roster-writer-and-route-truth / R1–R3）
#
# 两件：
#   ① `tests/routes.sh`——Walk A（team help 的每条用法行 ↔ 解析器）、非空洞控制臂（打印旗标的
#      每条路径必须拒未知参数）、Walk B（schema 注释点名的命令 ↔ 承诺探针）与翻转（把树改坏必须
#      红并点名）。FAST 由 TEAM_SMOKE_FAST 透传：它只跳翻转（一行可见 SKIP），前三段照跑。
#   ② 名册夹具的便宜一半（`config-cli.sh list validate roster`）：七个形状的退出码/字节不变性/
#      审计/一条值规则。两件都自带私有临时根，不碰 $REPO。
section "51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99）"
if [ -f "$SKILL_DIR/tests/routes.sh" ]; then
  P99_ROUTES_RC=0
  ( cd "$TMP" && bash "$SKILL_DIR/tests/routes.sh" ) >"$TMP/routes.log" 2>&1 || P99_ROUTES_RC=$?
  if [ "$P99_ROUTES_RC" -eq 0 ]; then
    ok "51 routes.sh 全绿（$(grep -ac '✓' "$TMP/routes.log" || true) 条断言，$(grep -ac 'SKIP' "$TMP/routes.log" || true) 条可见跳过）"
    { grep -aE '== (walk|control|promises|flips) ==' "$TMP/routes.log" || true; } | sed 's/^/      /'
  else
    bad "51 routes.sh 有失败（rc=$P99_ROUTES_RC）——用法行/注释承诺与真实解析器不一致"
    grep -a '✗' "$TMP/routes.log" | head -10 | sed 's/^/      /'
  fi
  # 翻转段的红侧尾巴（完整门禁才有；FAST 里是 SKIP）——留给现场
  { grep -aE '翻转[①②③④⑤⑥⑦]' "$TMP/routes.log" || true; } | head -8 | sed 's/^/      /'
else
  bad "51 缺 tests/routes.sh（P99 的用法诚实性走查）"
fi
if [ -f "$SKILL_DIR/tests/config-cli.sh" ]; then
  P99_ROSTER_RC=0
  bash "$SKILL_DIR/tests/config-cli.sh" list validate roster >"$TMP/p99-roster.log" 2>&1 || P99_ROSTER_RC=$?
  if [ "$P99_ROSTER_RC" -eq 0 ]; then
    ok "51 名册/契约夹具（list+validate+roster）全绿（$(grep -ac '✓' "$TMP/p99-roster.log" || true) 条断言）"
  else
    bad "51 名册/契约夹具有失败（rc=$P99_ROSTER_RC）"
    grep -a '✗' "$TMP/p99-roster.log" | head -8 | sed 's/^/      /'
  fi
else
  bad "51 缺 tests/config-cli.sh"
fi

# ═════════════════════════════════════════════════════════════════════
# 52 · 席位死因（P113 · agent-death-reason / R1–R6）
#
# 夹具本体是 tests/death-cause.sh：①纯逻辑矩阵（闭集五分类、两条反例、403 无额度词 → auth、
# 有界尾、当前启动守卫/重启不继承、身份去重、记录回退、表面、巡检 knock、只读指纹）；②四个
# 红侧（分类器影子 / 重启继承 / 去重去掉 / 干净退出判据退回旧写法）；③真 tmux 遗体那一半
# （没有 tmux 时可见 SKIP）。
# FAST 档跑 ①②（纯逻辑，不起进程）；③只在完整门禁且本机有 tmux 时跑。
section "52 · 席位死因：闭集分类 + 当前一次死亡 + 恰好一次通报（P113）"
if [ -f "$SKILL_DIR/tests/death-cause.sh" ]; then
  P113_PURE_RC=0
  bash "$SKILL_DIR/tests/death-cause.sh" --pure >"$TMP/p113-death-pure.log" 2>&1 || P113_PURE_RC=$?
  if [ "$P113_PURE_RC" -eq 0 ]; then
    ok "52 纯逻辑矩阵全绿（$(grep -ac '✓' "$TMP/p113-death-pure.log" || true) 条断言）"
  else
    bad "52 纯逻辑矩阵有失败（rc=$P113_PURE_RC）"
    grep -a '✗' "$TMP/p113-death-pure.log" | head -10 | sed 's/^/      /'
  fi
  P113_FLIP_RC=0
  bash "$SKILL_DIR/tests/death-cause.sh" --flip >"$TMP/p113-death-flip.log" 2>&1 || P113_FLIP_RC=$?
  if [ "$P113_FLIP_RC" -eq 0 ]; then
    ok "52 四个红侧都成立（分类器影子 / 重启继承 / 去重去掉 / 干净退出判据退回旧写法）"
  else
    bad "52 红侧不成立（rc=$P113_FLIP_RC）"
    grep -a '✗' "$TMP/p113-death-flip.log" | head -10 | sed 's/^/      /'
  fi
  if [ "$FAST" = "1" ]; then
    fast_skip "52·p113-live" "真 tmux 遗体夹具（完整门禁跑）"
  elif [ "$HAVE_TMUX" = "1" ]; then
    live_mark
    P113_LIVE_RC=0
    bash "$SKILL_DIR/tests/death-cause.sh" --live >"$TMP/p113-death-live.log" 2>&1 || P113_LIVE_RC=$?
    if [ "$P113_LIVE_RC" -eq 0 ]; then
      ok "52 真遗体那一半全绿（$(grep -ac '✓' "$TMP/p113-death-live.log" || true) 条断言）"
    else
      bad "52 真遗体那一半有失败（rc=$P113_LIVE_RC）"
      grep -a '✗' "$TMP/p113-death-live.log" | head -10 | sed 's/^/      /'
    fi
  else
    cond_skip "52·p113-live" "没有 tmux：真遗体那一半跳过（纯逻辑与红侧已跑）"
  fi
else
  bad "52 缺 tests/death-cause.sh（P113 的席位死因夹具）"
fi
# ---------------------------------------------------------------- 14d. P70 本套自述对账
# 本段之前每一段都必须：一条开跑行（#N 严格递增、带预算与 ISO 时间）、一条结束行（P98 的统一收口行：
# 用时 + ✓/✗/SKIP 增量 + ticks）、sections.tsv 一行。
section "14d · P70 本套自述对账（段落账目 + 无误判）"
P70_S_STARTS="$(grep -c '^== #[0-9][0-9]* ' "$SG_LOG" 2>/dev/null || true)"
P70_S_SHAPED="$(grep -cE '^== #[0-9]+ .+ == [0-9]{4}-[0-9]{2}-[0-9]{2}T[^ ]+ · 预算 [0-9]+s' "$SG_LOG" 2>/dev/null || true)"
P70_S_CLOSES="$(grep -cE '^#[0-9]+ .* 用时 [0-9]+s · ✓[0-9]+ ✗[0-9]+ SKIP[0-9]+ · ticks [0-9]+$' "$SG_LOG" 2>/dev/null || true)"
P70_S_ROWS="$(awk 'NR>1' "$SG_TIMING" | wc -l | tr -d ' ')"
assert_eq "P70 对账：开跑行都带 #N + ISO 时间 + 预算" "$P70_S_SHAPED" "$P70_S_STARTS"
assert_eq "P70 对账：当前段已开跑、上一段已收（starts = closes + 1）" "$P70_S_STARTS" "$((P70_S_CLOSES + 1))"
assert_eq "P70 对账：sections.tsv 每段一行（rows = closes）" "$P70_S_ROWS" "$P70_S_CLOSES"
assert_eq "P70 对账：#N 从 1 起严格递增无缺口" \
  "$(awk 'BEGIN { want = 1 } match($0, /^== #([0-9]+) /) { n = substr($0, RSTART + 4, RLENGTH - 5) + 0; if (n != want) { print "gap@" n; exit } want++ } END { print want - 1 }' "$SG_LOG")" \
  "$P70_S_STARTS"
assert_not_file "$SG_MARKER" "P70 对账：本套没有触发过超时"
[ -d "$SG_SCENE" ] && bad "P70 对账：干净跑留下了现场" || ok "P70 对账：没有现场目录（干净跑不该建）"
# 进度自述只在超过间隔的段出现（段内跑完却打进度行 = 自述成了判决 → 红）
P70_PROG_BAD=0
while IFS= read -r P70_N; do
  [ -n "$P70_N" ] || continue
  P70_E="$(awk -F'\t' -v n="$P70_N" 'NR>1 && $1 == n { print $4; exit }' "$SG_TIMING")"
  [ -n "$P70_E" ] || continue
  case "$P70_E" in *[!0-9]*) continue ;; esac
  if [ "$P70_E" -lt "$SG_PROGRESS_INTERVAL" ]; then
    bad "P70 对账：段落 #$P70_N 用时 ${P70_E}s < 间隔 ${SG_PROGRESS_INTERVAL}s，却有进度行"
    P70_PROG_BAD=1
  fi
done < <(grep -oE '^… 段落 #[0-9]+' "$SG_LOG" 2>/dev/null | grep -oE '[0-9]+$' | sort -u)
[ "$P70_PROG_BAD" = "0" ] && ok "P70 对账：没有「段内完成却打进度行」的段"

section "15 · 完成"
printf '   （全流程已在 0–14 节覆盖）\n'

# __SMOKE_TAIL__（P98 选段：本行起是收尾；--select 的过滤副本从这里原样保留到底，别再插段）
smoke_tmp_guard "结果行之前（跑完就不再回头检查了）"
smoke_section_close          # 最后一段也必须有收口行（统一行），且在结果行之前
section_guard_finish         # P70：关看门狗（最后一段已收口；干净跑不留哨兵文件）
smoke_slowest_summary        # 最慢 N 段（纯记录：不判定、不改退出码）
smoke_ledger_selfcheck       # 段落增量之和 vs 结果行总数（不一致只打印一行）
if [ "$SELECT_MODE" = "1" ]; then
  printf '\n\033[1m== 选段结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
else
  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
fi
if [ "$FAST_REQ" = "1" ]; then
  printf '\033[33mFAST 模式：跳过 %d 个真进程段落（%s）——完整门禁请不带 TEAM_SMOKE_FAST 重跑\033[0m\n' \
    "$SKIP_N" "${SKIP_SEGS#|}"
fi
# 选段运行：未跑清单就在最后几行里（team review 记录的就是尾部）；不是 RUN 子进程才在这里打（RUN 由
# 父进程在子进程结束后打，保证它落在最后）
if [ "$SELECT_MODE" = "1" ] && [ "$SMOKE_SEL_IS_CHILD" != "1" ]; then smoke_select_tail; fi
if [ "$FAIL" -eq 0 ]; then
  # 选段运行绝不打印 smoke 全绿：它只说明「跑了的段是绿的」，不是全套门禁（D7）
  [ "$SELECT_MODE" = "1" ] && exit 0
  printf '\033[32msmoke 全绿\033[0m\n'; exit 0
fi
printf '\033[31msmoke 有失败项（--keep 保留现场）\033[0m\n'
exit 1
