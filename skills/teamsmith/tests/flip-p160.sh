#!/usr/bin/env bash
# P160 · flip：三条返工的缺陷在**修复前**的树上红、在本树上绿
#
#   bash skills/teamsmith/tests/flip-p160.sh                 # 红树 = git merge-base HEAD main
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-p160.sh
#   --keep 保留两面各自的日志与临时根
#
# 两面跑的是**同一份**门禁副本：从本树的 smoke.sh 里逐字节取出前导段 + 55 段 + 56 段（P139 的纯逻辑与真
# tmux 面），只把 `SKILL_DIR=` 一行指向被测的树（产品代码/夹具库都跟着换）。所以：
#   ① 修复前的树（red）必须红在 P160 的三条上 —— 入队后排水不补 `knocks.log`（F1）、tip 宽度随
#      `core.abbrev` 变（F2）、`agent/<席位>` 编造 `task=`（F3）；
#   ② 本树（green）必须全绿：队列/载荷/账本三处的形状都对，tip 固定 12 位，空闲分支什么都不盖。
# 红面自己会说明它红在哪几行（脚本把 ✗ 行原样打出来）；只统计红/绿的总数是不够的。
#
# 安全性：两面都只是 smoke 探针，探针自带私有 tmux socket（`TMUX_TMPDIR` 指向自己临时根下 mkdir 过的
# 目录并把 `$TMUX` 指到那台 server），调用者的默认 server 不参与；本脚本自己不调用 tmux。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p160: 找不到 git 仓库\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-p160: 需要 tmux（56 段是真的 tmux 夹具）\n' >&2; exit 2; }

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'flip-p160: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p160)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

CUR_SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$CUR_SMOKE" ] || { printf 'flip-p160: 找不到 %s\n' "$CUR_SMOKE" >&2; exit 2; }
BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-p160: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

# 修复前的产品树（只取 skills/teamsmith；探针自己的夹具库也从这里取）
mkdir -p "$TMP/red"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" \
  || { printf 'flip-p160: 取不出 %s 的 skills/teamsmith\n' "$BASE" >&2; exit 2; }
RED_SKILL="$TMP/red/skills/teamsmith"
[ -f "$RED_SKILL/scripts/team" ] || { printf 'flip-p160: 红树里没有 scripts/team（base=%s）\n' "$BASE" >&2; exit 2; }

# 守卫：红树必须真的还是「修复前」，本树必须真的有修复（否则这个包会报一个假的翻转）
red_marker() { grep -q "$2" "$1" 2>/dev/null; }
if red_marker "$RED_SKILL/scripts/lib/cmd-agents.sh" 'team_notify_task_proven' \
   || red_marker "$RED_SKILL/scripts/lib/outbox.sh" 'team_outbox_record_delivery_receipt'; then
  printf 'flip-p160: TEAM_FLIP_BASE=%s 已经含 P160 的修复（红树不是红的）——用更早的 revision\n' "$BASE" >&2
  exit 2
fi
if ! red_marker "$SKILL_DIR/scripts/lib/cmd-agents.sh" 'team_notify_task_proven' \
   || ! red_marker "$SKILL_DIR/scripts/lib/outbox.sh" 'team_outbox_record_delivery_receipt'; then
  printf 'flip-p160: 本树没有 P160 的修复（先做修复，再跑这个包）\n' >&2
  exit 2
fi

printf '修复前 revision: %s\n' "$BASE"
printf '修复前产品树:   %s\n' "$RED_SKILL"
printf '修复后产品树:   %s\n' "$SKILL_DIR"

# 探针 = 当前 smoke.sh 的前导段 + 55/56 段 + 收尾；SKILL_DIR 指向被测的树
build_probe() { # <smoke.sh> <out> <被树>
  local smoke="$1" out="$2" tree="$3"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$smoke"
    printf '\n# —— P160 flip 探针：55 + 56 段 ——\n'
    awk '/^section "55 /{f=1} /^section "57 /{exit} f{print}' "$smoke"
    cat <<'EOS'

# —— P160 flip 探针收尾 ——
smoke_tmp_guard "结果行之前"
smoke_section_close
section_guard_finish
printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$tree\"|" > "$out"
  grep -q "^SKILL_DIR=\"$tree\"$" "$out" || { printf 'flip-p160: 探针的 SKILL_DIR 替换没生效\n' >&2; return 1; }
  grep -q 'section "56 ' "$out" && grep -q 'section "55 ' "$out" \
    || { printf 'flip-p160: 探针里没取到 55/56 段\n' >&2; return 1; }
}

run_probe() { # <探针> <日志> → 0 = 全绿
  # P160 踩过：不能带门禁锁跑。锁那一段把「再跑一遍自己」写成 `bash "$SKILL_DIR/tests/smoke.sh"`
  # （smoke.sh:339），探针会因此变成「该树的全套门禁」——红面就跑了 29 分钟全套，而不是两段夹具。
  # 探针切在 `# ---- 0. 仓库` 之前，所以 section-guard 没 arm：日志里既没有开跑行也没有收口行，
  # 只有断言行 + 结果行。判据因此改成「两段各自的断言标签在、别的段的标签不在」。
  ( cd "$TMP" && env TEAM_SMOKE_NO_LOCK=1 bash "$1" </dev/null ) >"$2" 2>&1
  local rc=$?
  local why=""
  if ! grep -qaF -- '== 结果 ==' "$2" 2>/dev/null; then
    why="日志里没有结果行（探针没跑完？）"
  elif ! grep -qaF -- 'P139 3.5 工作树里 notify 退出码 0' "$2" 2>/dev/null; then
    why="缺少 55 段的断言行"
  elif ! grep -qaF -- 'P139 夹具：m-tmux 会议已开' "$2" 2>/dev/null; then
    why="缺少 56 段的断言行"
  elif grep -qaF -- 'P70 对账：sections.tsv 每段一行' "$2" 2>/dev/null; then
    why="日志里有 14d 段（探针跑成了全套门禁）"
  fi
  if [ -n "$why" ]; then
    printf 'flip-p160: %s 不能当证据：%s\n' "$(basename "$2")" "$why" >&2
    return 3
  fi
  return "$rc"
}

RC=0
build_probe "$CUR_SMOKE" "$TMP/probe-red.sh" "$RED_SKILL" || exit 2
build_probe "$CUR_SMOKE" "$TMP/probe-green.sh" "$SKILL_DIR" || exit 2

printf '\n\033[1m══ ① 修复前的树（期望红在 P160 的三条上）══\033[0m\n'
run_probe "$TMP/probe-red.sh" "$TMP/red.log"; RED_RC=$?
case "$RED_RC" in
  0)
    printf '\033[31m✗ 修复前的树全绿了 —— 这个翻转包没有测到缺陷（BASE 选错了？）\033[0m\n'
    RC=1 ;;
  1)
    printf '%s\n' "修复前的树按预期判红。失败的断言："
    grep -a '✗' "$TMP/red.log" | sed 's/^/    /' | head -20
    RED_F1="$(grep -ac 'P160 F1' "$TMP/red.log" 2>/dev/null || true)"
    RED_F2="$(grep -ac 'P160 F2' "$TMP/red.log" 2>/dev/null || true)"
    RED_F3="$(grep -ac 'P160 F3' "$TMP/red.log" 2>/dev/null || true)"
    grep -a '✗.*P160 F1' "$TMP/red.log" >/dev/null 2>&1 || { printf '\033[31m✗ 红面没有红在 F1（排队敲门账本）上\033[0m\n'; RC=1; }
    grep -a '✗.*P160 F2' "$TMP/red.log" >/dev/null 2>&1 || { printf '\033[31m✗ 红面没有红在 F2（tip 宽度）上\033[0m\n'; RC=1; }
    grep -a '✗.*P160 F3' "$TMP/red.log" >/dev/null 2>&1 || { printf '\033[31m✗ 红面没有红在 F3（空闲分支编造 task）上\033[0m\n'; RC=1; }
    printf '%s\n' "  红面 P160 断言命中：F1=$RED_F1 F2=$RED_F2 F3=$RED_F3（行数，含通过的那些）"
    grep -a '== 结果 ==' "$TMP/red.log" | tail -1 | sed 's/^/    /' ;;
  *)
    printf '\033[31m✗ 红面探针没跑成（rc=%s）——脚本级错误，不是对代码的判定\033[0m\n' "$RED_RC"
    RC=1 ;;
esac

printf '\n\033[1m══ ② 本树（期望全绿）══\033[0m\n'
run_probe "$TMP/probe-green.sh" "$TMP/green.log"; GREEN_RC=$?
case "$GREEN_RC" in
  0)
    grep -a '== 结果 ==' "$TMP/green.log" | tail -1 | sed 's/^/    /'
    printf '%s\n' "本树全绿（55 + 56 段：队列/载荷/账本 + tip 宽度 + 空闲分支）。" ;;
  1)
    printf '\033[31m✗ 本树判红 —— 修复没落地或探针本身坏了\033[0m\n'
    grep -a '✗' "$TMP/green.log" | sed 's/^/    /' | head -20
    RC=1 ;;
  *)
    printf '\033[31m✗ 本树探针没跑成（rc=%s）——脚本级错误，不是对代码的判定\033[0m\n' "$GREEN_RC"
    RC=1 ;;
esac

if [ "$KEEP" = "1" ]; then
  printf '\n保留：临时根 %s（red.log / green.log / 两面的探针与日志都在里面）\n' "$TMP"
else
  printf '\n临时根：%s（--keep 可保留现场）\n' "$TMP"
fi

# 证据副本：给了可写目录（报告 package 挂在容器里时就是它）就把两面的原始日志与探针抄过去
#   TEAM_FLIP_EVIDENCE_DIR=/work/docs/team/reports/P160-dev-bob/pkg
EV="${TEAM_FLIP_EVIDENCE_DIR:-}"
if [ -n "$EV" ] && mkdir -p "$EV" 2>/dev/null; then
  cp -f "$TMP/red.log" "$EV/red.log" 2>/dev/null || true
  cp -f "$TMP/green.log" "$EV/green.log" 2>/dev/null || true
  {
    printf 'P160 flip · %s\n' "$(date -Is)"
    printf '修复前 revision: %s\n' "$BASE"
    printf '本树: %s\n' "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf '?')"
    printf '红面 rc=%s ｜ 绿面 rc=%s ｜ 本包 rc=%s\n' "${RED_RC:-?}" "${GREEN_RC:-?}" "$RC"
    printf '\n红面失败的断言（原样）:\n'
    grep -a '✗' "$TMP/red.log" 2>/dev/null | sed 's/^/  /' | head -20
    printf '\n红面结果行: %s\n' "$(grep -a '== 结果 ==' "$TMP/red.log" 2>/dev/null | tail -1)"
    printf '绿面结果行: %s\n' "$(grep -a '== 结果 ==' "$TMP/green.log" 2>/dev/null | tail -1)"
  } > "$EV/summary.txt" 2>/dev/null || true
  printf '证据副本：%s（red.log / green.log / summary.txt；探针 = smoke.sh 前导段 + 55/56 段，可重现）\n' "$EV"
fi
[ "$RC" -eq 0 ] && printf '\033[32mflip-p160：三条的红→绿都对上了\033[0m\n'
exit "$RC"
