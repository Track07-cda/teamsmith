#!/usr/bin/env bash
# P158 · flip：树在跑动中被改动 → 「本次运行无效」+ 约定退出码 4；没动 → 与今天逐字节相同
#
#   bash skills/teamsmith/tests/flip-p158.sh                  # 四条：基线 / docs/team 记录 / 未跟踪文件 / HEAD
#   bash skills/teamsmith/tests/flip-p158.sh --base[=<rev>]    # 红侧历史面：<rev>（默认 merge-base HEAD main）
#                                                               的 smoke.sh 建变体 → 跑动中改树**不得**报「无效」
#   bash skills/teamsmith/tests/flip-p158.sh --break=ignore   # 牙齿：把变体里的比较砸成 no-op → 本包必须发现
#   bash skills/teamsmith/tests/flip-p158.sh --break=code     # 牙齿：只把无效退出码改成 0 → 本包也必须发现
#   bash skills/teamsmith/tests/flip-p158.sh --keep           # 保留现场
#
# 被测树 = 本树的一份 scratch 变体（真 .git；产品面软链到真树；skills/teamsmith/tests 是真目录、逐文件
# 软链，只有 smoke.sh / section-paths.tsv 是真副本 —— 与 §36 的变体同形）。改动只落在变体里，真树一个
# 字节都不碰。
# 每条用例：起一次真门禁（`--select 0b`：前导 0/0b/0c/0d 纯逻辑段，私有 TMPDIR）→ 等它把**开跑指纹**写进
# 自己的现场文件（= 树已经被读过一遍，窗口从这一刻起）→ 按用例改变体树 → 收断言：
#   * 基线：rc=0 且**没有**「无效」行（与改动前的可观测行为一致）；
#   * 三条改动：rc=4、「本次运行无效」行在**结果行之前**、结果行照旧打印（红/✓ 不被吞）。
# 牙齿（--break=...）：先把变体里的实现砸掉再跑「未跟踪文件」这一条 —— 本包必须**发现**它不再被判无效，
# 否则说明这套夹具是空跑的（本包此时返回 0；砸完还判无效才返回 1）。
#
# 安全性：只在自己的临时根与变体树里动手；nested 门禁走私有 TMPDIR（`TEAM_SMOKE_FAST=1`，不起真进程
# 夹具、也没有 tmux 破坏性调用）；不对任何非自己 spawn 的进程发信号。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-p158: 找不到 git 仓库（需要真检出）\n' >&2; exit 2; }
SMOKE="$SKILL_DIR/tests/smoke.sh"
[ -f "$SMOKE" ] || { printf 'flip-p158: 找不到 %s\n' "$SMOKE" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'flip-p158: 需要 git\n' >&2; exit 2; }

KEEP=0; BREAK=""; BASE_REQ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    --break=ignore|--break=code) BREAK="${1#--break=}"; shift ;;
    --base) BASE_REQ="auto"; shift ;;
    --base=*) BASE_REQ="${1#--base=}"; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) printf 'flip-p158: 未知参数 %s（--keep / --base[=<rev>] / --break=ignore|code）\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p158)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

FAILED=0
case_ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
case_bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILED=1; }

# ---------------------------------------------------------------- 红侧历史面：拿 <rev> 的 smoke.sh 建变体
# 修复前的门禁没有这段判据（base 树必须真的没有 RF_EXIT_INVALID，否则报脚本级错误，不演一场假翻转）；
# 换 smoke.sh 的同时也换它的段表：base 的源码 + 今天的表会当场自相矛盾（多出一个 0i 段）。
SMOKE_VARIANT="$SMOKE"
PATHS_VARIANT="$SKILL_DIR/tests/section-paths.tsv"
if [ -n "$BASE_REQ" ]; then
  [ "$BASE_REQ" = "auto" ] && BASE_REQ="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
  [ -n "$BASE_REQ" ] || { printf 'flip-p158: 解析不到修复前的 revision，用 --base=<sha> 指定\n' >&2; exit 2; }
  mkdir -p "$TMP/base"
  git -C "$REPO_ROOT" show "$BASE_REQ:skills/teamsmith/tests/smoke.sh" > "$TMP/base/smoke.sh" 2>/dev/null \
    || { printf 'flip-p158: 取不出 %s 的 tests/smoke.sh\n' "$BASE_REQ" >&2; exit 2; }
  chmod +x "$TMP/base/smoke.sh"    # git show 走重定向 → 会丢掉 +x，而 0c 段会因此判红（假红）
  git -C "$REPO_ROOT" show "$BASE_REQ:skills/teamsmith/tests/section-paths.tsv" > "$TMP/base/section-paths.tsv" 2>/dev/null \
    || { printf 'flip-p158: 取不出 %s 的 tests/section-paths.tsv\n' "$BASE_REQ" >&2; exit 2; }
  if grep -q 'RF_EXIT_INVALID' "$TMP/base/smoke.sh"; then
    printf 'flip-p158: base=%s 的 smoke.sh 已经含 P158 的实现（它不是「修复前」）—— 用更早的 revision\n' "$BASE_REQ" >&2
    exit 2
  fi
  SMOKE_VARIANT="$TMP/base/smoke.sh"
  PATHS_VARIANT="$TMP/base/section-paths.tsv"
fi

# ---------------------------------------------------------------- 变体树（真 .git，真树零改动）
VAR="$TMP/tree"
build_variant() {
  local r="$REPO_ROOT" x b
  rm -rf "$VAR"; mkdir -p "$VAR/skills/teamsmith/tests" "$VAR/docs/team"
  for x in "$r"/*; do
    b="$(basename "$x")"
    case "$b" in skills|docs|.git) continue ;; esac
    ln -s "$x" "$VAR/$b"
  done
  for x in "$r"/.[!.]*; do
    b="$(basename "$x")"
    case "$b" in .git|.gitignore) continue ;; esac
    ln -s "$x" "$VAR/$b"
  done
  # .gitignore 必须是真副本（git 按 O_NOFOLLOW 读逐目录忽略文件：软链接会报
  # 「too many levels of symbolic links」并把忽略规则当成不存在）
  cp "$r/.gitignore" "$VAR/.gitignore" 2>/dev/null || true
  for x in "$r"/docs/*; do
    b="$(basename "$x")"
    case "$b" in team) continue ;; esac
    ln -s "$x" "$VAR/docs/$b"
  done
  printf 'P158 flip 的 docs/team 记录（门禁不消费它）：初始一行\n' > "$VAR/docs/team/P158-record.md"
  for x in "$r"/skills/*; do
    b="$(basename "$x")"
    case "$b" in teamsmith) continue ;; esac
    ln -s "$x" "$VAR/skills/$b"
  done
  for x in "$SKILL_DIR"/*; do
    b="$(basename "$x")"
    case "$b" in tests) continue ;; esac
    ln -s "$x" "$VAR/skills/teamsmith/$b"
  done
  for x in "$SKILL_DIR"/tests/*; do
    ln -s "$x" "$VAR/skills/teamsmith/tests/$(basename "$x")"
  done
  rm -f "$VAR/skills/teamsmith/tests/smoke.sh" "$VAR/skills/teamsmith/tests/section-paths.tsv"
  cp "$SMOKE_VARIANT" "$VAR/skills/teamsmith/tests/smoke.sh"
  cp "$PATHS_VARIANT" "$VAR/skills/teamsmith/tests/section-paths.tsv"
  git -C "$VAR" init -q -b main || return 1
  git -C "$VAR" add -A || return 1
  git -C "$VAR" -c user.email=flip@teamsmith -c user.name=flip commit -qm "flip-p158: 变体树基线" || return 1
  # 自检：变体树必须干净 —— 否则「基线」用例会把夹具自己的脏读成「树被改」
  [ -z "$(git -C "$VAR" status --porcelain --untracked-files=all)" ] || return 1
  return 0
}

# ---------------------------------------------------------------- 用例：跑一次真门禁，窗口里改树
CASE_RC=""; CASE_LOG=""; CASE_FP=""; CASE_WHY=""
run_case() { # <名字> <在变体树里执行的变异命令>
  local name="$1" mutate="$2" ctmp pid fp i marker
  ctmp="$TMP/case-$name"; rm -rf "$ctmp"; mkdir -p "$ctmp"
  CASE_LOG="$ctmp/run.log"; CASE_FP=""; CASE_WHY=""; CASE_RC=""
  # 窗口信号：新实现写开跑指纹（= 已经读过一遍树）；--base 的老实现没有它，退到 sections.tsv + 一小段等
  marker="run-fingerprint.txt"
  grep -q 'RF_EXIT_INVALID' "$SMOKE_VARIANT" || marker="sections.tsv"
  ( cd "$VAR" && TMPDIR="$ctmp" TEAM_TMP_KEEP=1 TEAM_SMOKE_FAST=1 \
      bash "$VAR/skills/teamsmith/tests/smoke.sh" --select 0b </dev/null ) >"$CASE_LOG" 2>&1 &
  pid=$!
  fp=""; i=0
  while [ "$i" -lt 500 ] && [ -z "$fp" ]; do
    fp="$(ls "$ctmp"/teamsmith-smoke.*/"$marker" 2>/dev/null | head -1)"
    [ -n "$fp" ] || { sleep 0.02; i=$((i + 1)); }
  done
  [ "$marker" = "sections.tsv" ] && sleep 0.5    # 老实现：再给它一点时间把树真正读过一遍
  if [ -z "$fp" ]; then
    CASE_RC=3; CASE_WHY="没等到开跑指纹（门禁没跑起来？）"
    wait "$pid" 2>/dev/null || true
    return 3
  fi
  if ! kill -0 "$pid" 2>/dev/null; then
    CASE_RC=3; CASE_WHY="门禁在变异之前就结束了（窗口没抓住）"
    wait "$pid" 2>/dev/null || true
    return 3
  fi
  if ! ( cd "$VAR" && eval "$mutate" ); then
    CASE_RC=3; CASE_WHY="变异命令失败"
    wait "$pid" 2>/dev/null || true
    return 3
  fi
  wait "$pid"; CASE_RC=$?
  if [ "$marker" = "run-fingerprint.txt" ]; then CASE_FP="$fp"; cp -f "$fp" "$ctmp/fingerprint.txt" 2>/dev/null || true; fi
  return 0
}
expect_invalid() { # <用例名> <期望出现在「无效」行里的片段…>
  local name="$1"; shift
  if [ "$CASE_RC" != "4" ]; then
    case_bad "$name：退出码 [$CASE_RC]（期望 4）${CASE_WHY:+ —— $CASE_WHY}"; return 1
  fi
  grep -aqF '本次运行无效：树在跑动中被改动' "$CASE_LOG" || { case_bad "$name：日志里没有「本次运行无效」行"; return 1; }
  grep -aqF '== 选段结果 ==' "$CASE_LOG" || { case_bad "$name：结果行被吞了（该打印的 ✓/✗ 没打印）"; return 1; }
  local want
  for want in "$@"; do
    grep -aqF "$want" "$CASE_LOG" || { case_bad "$name：「无效」行里没有 [$want]"; return 1; }
  done
  case_ok "$name：rc=4 · 「无效」行（$*）+ 结果行照旧打印"
  return 0
}
expect_clean() { # <用例名>
  local name="$1"
  if [ "$CASE_RC" != "0" ]; then
    case_bad "$name：退出码 [$CASE_RC]（期望 0）${CASE_WHY:+ —— $CASE_WHY}"; return 1
  fi
  grep -aqF '本次运行无效' "$CASE_LOG" && { case_bad "$name：没动树却报了「无效」"; return 1; }
  grep -aqF '== 选段结果 ==' "$CASE_LOG" || { case_bad "$name：没有结果行"; return 1; }
  case_ok "$name：rc=0 · 没有「无效」行（与改动前的可观测行为一致）"
  return 0
}

# ---------------------------------------------------------------- 牙齿：把变体里的实现砸掉
apply_break() { # <ignore|code> → 非 0 = 注入没打上（脚本级错误）
  local kind="$1" f="$VAR/skills/teamsmith/tests/smoke.sh"
  case "$kind" in
    ignore)
      [ "$(grep -c '^smoke_fingerprint_compare    # P158' "$f" || true)" = "1" ] || return 1
      # 在收尾调用**之前**把比较覆盖成 no-op（bash 按执行顺序取后定义的那个）
      sed -i 's|^smoke_fingerprint_compare    # P158|smoke_fingerprint_compare() { return 0; }   # flip-p158 --break=ignore\nsmoke_fingerprint_compare    # P158|' "$f" || return 1
      grep -qF '^smoke_fingerprint_compare() { return 0; }' "$f" || grep -q 'smoke_fingerprint_compare() { return 0; }' "$f" || return 1
      ;;
    code)
      grep -q '^RF_EXIT_INVALID=4$' "$f" || return 1
      sed -i 's|^RF_EXIT_INVALID=4$|RF_EXIT_INVALID=0|' "$f" || return 1
      grep -q '^RF_EXIT_INVALID=0$' "$f" || return 1
      ;;
    *) return 1 ;;
  esac
  return 0
}

# ---------------------------------------------------------------- 主流程
printf '\033[1m══ P158 flip：树在跑动中被改动 → 本次运行无效（退出码 4）══\033[0m\n'
printf '  真树（产品面软链目标）：%s\n' "$REPO_ROOT"
printf '  变体树（改动只落在这里）：%s\n' "$VAR"
printf '  被测 smoke.sh：%s%s\n' "$SMOKE_VARIANT" "$([ -n "$BASE_REQ" ] && printf '（修复前的 revision %s）' "$BASE_REQ")"
build_variant || { printf 'flip-p158: 建不出干净的变体树\n' >&2; exit 2; }

if [ -n "$BREAK" ]; then
  apply_break "$BREAK" || { printf 'flip-p158: --break=%s 的注入没打上（脚本级错误）\n' "$BREAK" >&2; exit 2; }
  printf '\n\033[1m── 牙齿（--break=%s）：砸掉实现后，本包必须发现这一条不再被判无效 ──\033[0m\n' "$BREAK"
  run_case break-untracked 'printf "mid-run\n" > scratch-mid-run.txt'
  rm -f "$VAR/scratch-mid-run.txt"
  if [ "$CASE_RC" = "4" ] && grep -aqF '本次运行无效' "$CASE_LOG"; then
    case_bad "牙齿（--break=$BREAK）：实现被砸掉之后「跑动中改一个文件」**仍然**被判无效 —— 本包没咬住实现（空跑）"
  elif [ "$CASE_RC" = "3" ]; then
    case_bad "牙齿（--break=$BREAK）：用例没跑成 —— $CASE_WHY"
  elif grep -aqF '本次运行无效' "$CASE_LOG"; then
    case_ok "牙齿（--break=$BREAK）：无效行还在、但退出码被改成 [$CASE_RC] 后本包不再接受 —— 本包确实在读退出码"
  else
    case_ok "牙齿（--break=$BREAK）：实现被砸掉后这一条不再判无效（rc=$CASE_RC，没有「无效」行）—— 本包确实在读实现"
  fi
elif [ -n "$BASE_REQ" ]; then
  # 红侧历史面：修复前的门禁对一棵跑动中变了的树照常出结论（假判决）—— 它不报「无效」
  printf '\n\033[1m── 红侧（base=%s）：跑动中改树 → 修复前的门禁不得报「无效」──\033[0m\n' "$BASE_REQ"
  run_case base-untracked 'printf "mid-run\n" > scratch-mid-run.txt'
  rm -f "$VAR/scratch-mid-run.txt"
  if [ "$CASE_RC" = "3" ]; then
    case_bad "红侧（base=$BASE_REQ）：用例没跑成 —— $CASE_WHY"
  elif [ "$CASE_RC" = "4" ] || grep -aqF '本次运行无效' "$CASE_LOG"; then
    case_bad "红侧（base=$BASE_REQ）：修复前的门禁竟然报了「无效」—— 这个 base 已经含修复？"
  else
    case_ok "红侧（base=$BASE_REQ）：跑动中改树 → 仍是普通结论（rc=$CASE_RC、没有「无效」行）—— 修复前的假判决（D79 形状）"
  fi
else
  printf '\n\033[1m── ① 基线：跑动中不动树 → 与今天逐字节相同（不得出现「无效」行）──\033[0m\n'
  run_case clean 'true'
  expect_clean "① 基线（跑动中不动树）"

  printf '\n\033[1m── ② 跑动中改一条 docs/team/** 记录（门禁不消费它）→ 仍然无效 ──\033[0m\n'
  run_case records 'printf "跑动中追加的一行\n" >> docs/team/P158-record.md'
  expect_invalid "② 跑动中改 docs/team/** 的记录" '脏文件 0→1'
  git -C "$VAR" checkout -q -- docs/team/P158-record.md 2>/dev/null || true

  printf '\n\033[1m── ③ 跑动中新建未跟踪文件（0d 明说不扫未跟踪 → 证得门禁没读它）→ 仍然无效 ──\033[0m\n'
  run_case untracked 'printf "mid-run\n" > scratch-mid-run.txt'
  expect_invalid "③ 跑动中新建未跟踪文件（门禁没读它）" '脏文件 0→1'
  rm -f "$VAR/scratch-mid-run.txt"

  printf '\n\033[1m── ④ 跑动中 HEAD 前进（commit --allow-empty；工作树仍干净）→ 仍然无效 ──\033[0m\n'
  SHA0="$(git -C "$VAR" rev-parse HEAD)"
  run_case head 'git -c user.email=flip@teamsmith -c user.name=flip commit -q --allow-empty -m "mid-run commit"'
  SHA1="$(git -C "$VAR" rev-parse HEAD)"
  expect_invalid "④ 跑动中 HEAD 前进" "HEAD ${SHA0:0:12}→${SHA1:0:12}" '脏文件 0→0'
fi

# ---------------------------------------------------------------- 现场（指纹文件的开跑/收尾两行）
printf '\n\033[1m── 指纹现场（每条用例的 run-fingerprint.txt：开跑 → 收尾 → 判定）──\033[0m\n'
for d in "$TMP"/case-*; do
  [ -f "$d/fingerprint.txt" ] || continue
  printf '  %s:\n' "$(basename "$d")"
  sed -n 's/^\(start\|end\|verdict\): /    \1: /p' "$d/fingerprint.txt"
done
printf '  （完整日志：%s/case-*/run.log）\n' "$TMP"

EV="${TEAM_FLIP_EVIDENCE_DIR:-}"
if [ -n "$EV" ] && mkdir -p "$EV" 2>/dev/null; then
  for d in "$TMP"/case-*; do
    [ -d "$d" ] || continue
    cp -f "$d/run.log" "$EV/$(basename "$d").log" 2>/dev/null || true
    cp -f "$d/fingerprint.txt" "$EV/$(basename "$d").fingerprint.txt" 2>/dev/null || true
  done
  {
    printf 'P158 flip · %s · break=%s\n' "$(date -Is)" "${BREAK:-none}"
    printf '真树 %s · HEAD %s\n' "$REPO_ROOT" "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf '?')"
    printf '变体树 %s\n' "$VAR"
    printf '本包 rc=%s\n' "$FAILED"
  } > "$EV/summary.txt" 2>/dev/null || true
  printf '证据副本：%s（每条用例的 run.log / fingerprint.txt / summary.txt）\n' "$EV"
fi

if [ "$KEEP" = "1" ]; then
  printf '\n保留：临时根 %s（变体树 / 每条用例的日志与指纹都在里面）\n' "$TMP"
else
  printf '\n临时根：%s（--keep 可保留现场）\n' "$TMP"
fi
if [ "$FAILED" = "0" ]; then
  if [ -n "$BREAK" ]; then
    printf '\033[32mflip-p158：牙齿有效（--break=%s —— 砸掉实现后本包确实发现了）\033[0m\n' "$BREAK"
  elif [ -n "$BASE_REQ" ]; then
    printf '\033[32mflip-p158：红侧在场（base=%s 的门禁对跑动中变了的树照常出结论）\033[0m\n' "$BASE_REQ"
  else
    printf '\033[32mflip-p158：四条都对上了（基线不报、三条改动都报「无效」+ rc=4）\033[0m\n'
  fi
  exit 0
fi
exit 1
