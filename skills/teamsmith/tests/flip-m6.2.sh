#!/usr/bin/env bash
# M6.2 控制实验：同一组用例分别跑在「修复前」和「修复后」两份 skill 上。
#
#   bash skills/teamsmith/tests/flip-m6.2.sh                 # 自动找 M6.2 修复前那一版（分支历史还在时）
#   BASE=<sha> bash skills/teamsmith/tests/flip-m6.2.sh      # squash 合并后用显式钉住的 revision
#
# 为什么存在：smoke 只证明「现在的实现全绿」，证明不了「如果没有这些守卫，测试会红」。
# 这个脚本把 V4.0 报告里的 9 个 finding 写成可执行断言，对两份 skill 各跑一遍：
#   BUG-REPRODUCED → 修复前的缺陷还在（red 侧必须全部是这一种）
#   BUG-GONE       → 现在的可观测行为已经是 M6.2 要求的（green 侧必须全部是这一种）
# 一切都在 /tmp 的临时仓库里，绝不碰当前项目；red 那版从 `git archive <BASE>` 取出，
# 与工作区无关。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf '不在 git 仓库里：%s\n' "$SKILL_DIR" >&2; exit 2; }

BASE="${BASE:-}"
if [ -z "$BASE" ]; then
  # 修复的那一版 = 第一个引入记录读取函数（team_review_record_verdict）的提交
  FIRST_FIX="$(git -C "$REPO_ROOT" log --reverse --format=%H -S'team_review_record_verdict' \
                 -- skills/teamsmith/scripts/lib/cmd-review.sh 2>/dev/null | head -1 || true)"
  [ -n "$FIRST_FIX" ] && BASE="$(git -C "$REPO_ROOT" rev-parse --verify --quiet "${FIRST_FIX}^" || true)"
fi
if [ -z "$BASE" ] || ! git -C "$REPO_ROOT" rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null 2>&1; then
  printf '找不到「修复前」的 revision：用 BASE=<sha> 指定（例如 BASE=914c334）\n' >&2
  exit 2
fi

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
WORK="$(tmp_root_create flip-m6.2)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmp_root_reap_all
}
trap cleanup EXIT
RED_ROOT="$WORK/red"
mkdir -p "$RED_ROOT"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$RED_ROOT"
printf '修复前 (red):  %s  ← skills/teamsmith @ %s\n' "$RED_ROOT/skills/teamsmith" "$(git -C "$REPO_ROOT" rev-parse --short "$BASE")"
printf '修复后 (green): %s\n' "$SKILL_DIR"

PASS=0; BUG=0
case_line() { # <finding> <label> <bug|fixed> <detail>
  if [ "$3" = "bug" ]; then BUG=$((BUG+1)); printf '  %-5s %-6s BUG-REPRODUCED  %s\n' "$1" "$2" "$4"
  else PASS=$((PASS+1)); printf '  %-5s %-6s BUG-GONE        %s\n' "$1" "$2" "$4"; fi
}

mkproj() { # <name> [gates] → repo path（一个全新的一次性项目）
  local r="$WORK/$1"
  mkdir -p "$r"
  git -C "$r" init -q -b main
  git -C "$r" config user.email flip@m62; git -C "$r" config user.name flip
  printf '# %s\n' "$1" > "$r/README.md"
  git -C "$r" add -A && git -C "$r" commit -qm init
  ( cd "$r" && bash "$CUR_SKILL/scripts/team" init --session "m62flip-$$" --agents dev --gates "${2:-true}" ) >/dev/null 2>&1
  git -C "$r" add -A && git -C "$r" commit -qm "chore: teamsmith init"
  printf '%s\n' "$r"
}

mktask() { # <repo> <id>：任务书 + BOARD 行 + 分支/worktree + 报告
  local r="$1" id="$2" wt="$1/.worktrees/dev"
  ( cd "$r" && bash "$CUR_SKILL/scripts/team" task "$id" --title "flip $id" --agent dev ) >/dev/null 2>&1
  git -C "$r" worktree add -q -b "task/$id-smoke" "$wt" main
  mkdir -p "$wt/docs/team/reports"
  printf '# %s · report\n\nagent: dev   状态: DONE\n' "$id" > "$wt/docs/team/reports/$id-dev.md"
  printf 'code\n' > "$wt/code.txt"
  git -C "$wt" add -A && git -C "$wt" commit -qm "feat($id): code + report"
}

review() { # <repo> <args...> → stdout+stderr；退出码在 $?（调用方自己接）
  local r="$1"; shift
  ( cd "$r" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR bash "$CUR_SKILL/scripts/team" review "$@" ) 2>&1
}

verdict_of() { sed -n 's/.*判定: \*\*\([A-Z]*\)\*\*.*/\1/p' "$1/docs/team/reviews/$2.md" 2>/dev/null | head -1; }

run_all() { # <label> <skill dir>
  local LABEL="$1" OUT
  CUR_SKILL="$2"

  # F7 —— --branch 解析不到：记录会不会盖章到一个不存在的 revision
  local R D
  R="$(mkproj f7-$LABEL)"; mktask "$R" P1
  D="$WORK/f7-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  OUT="$(review "$R" P1 --dir "$D" --branch no-such-branch)"; local rc=$?
  if [ "$rc" = "0" ]; then case_line F7 "$LABEL" bug "rc=0：不存在的 --branch 也盖章（记录抬头写 no-such-branch）"
  else case_line F7 "$LABEL" fixed "rc=$rc：$(printf '%s' "$OUT" | grep -m1 -o '分支解析不到.*' || echo '被拒')"; fi

  # F8 —— ALLOW_DIRTY 覆盖下记录/输出还说不说“干净”
  R="$(mkproj f8-$LABEL)"; mktask "$R" P1
  D="$WORK/f8-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  printf 'dirty\n' >> "$D/code.txt"
  OUT="$(cd "$R" && env TEAM_REVIEW_ALLOW_DIRTY=1 bash "$CUR_SKILL/scripts/team" review P1 --dir "$D" 2>&1)"
  if grep -q '干净' <(printf '%s\n%s' "$OUT" "$(cat "$R/docs/team/reviews/P1.md" 2>/dev/null)"); then
    case_line F8 "$LABEL" bug "ALLOW_DIRTY 覆盖下仍打印/记录「干净」（记录里没有 dirty 字段）"
  else
    case_line F8 "$LABEL" fixed "$(grep -m1 -o 'checkout dirty: [0-9]* files (override[^)]*)' "$R/docs/team/reviews/P1.md" 2>/dev/null || echo '记录标注了脏树')"
  fi

  # F9 —— 被 .gitignore 忽略的产物（不在提交里）能不能让门禁 PASS
  R="$(mkproj f9-$LABEL 'test -f build/marker')"; mktask "$R" P1
  printf 'build/\n' > "$R/.worktrees/dev/.gitignore"
  git -C "$R/.worktrees/dev" add -A && git -C "$R/.worktrees/dev" commit -qm "chore(P1): ignore build/"
  D="$WORK/f9-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  mkdir -p "$D/build" && printf 'not in the commit\n' > "$D/build/marker"
  OUT="$(review "$R" P1 --dir "$D")"; local rc9=$?
  if [ "$rc9" = "0" ]; then case_line F9 "$LABEL" bug "ignored 产物（status --porcelain 为空）让门禁 PASS 并盖章：$(verdict_of "$R" P1)"
  else case_line F9 "$LABEL" fixed "rc=$rc9：$(printf '%s' "$OUT" | grep -m1 -o 'ignored[^）]*' || echo 'ignored 产物被拒')"; fi

  # F10 —— 真挂死：记 TIMEOUT 还是 FAIL
  R="$(mkproj "f10-$LABEL" 'echo start; sleep 30')"; mktask "$R" P1
  D="$WORK/f10-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  (cd "$R" && env TEAM_REVIEW_TIMEOUT=1 bash "$CUR_SKILL/scripts/team" review P1 --dir "$D") >/dev/null 2>&1
  local v10; v10="$(verdict_of "$R" P1)"
  if [ "$v10" = "TIMEOUT" ]; then case_line F10 "$LABEL" fixed "挂死门禁 → TIMEOUT（记录含「硬超时终止」×$(grep -c '硬超时终止' "$R/docs/team/reviews/P1.md" 2>/dev/null)）"
  else case_line F10 "$LABEL" bug "挂死门禁被记成 $v10（GNU timeout 默认不打字，grep 不到）"; fi

  # F11 —— 门禁只是打印 'timeout' 字样 + 普通失败
  R="$(mkproj "f11-$LABEL" 'echo "info: using timeout 5 for the probe"; exit 3')"; mktask "$R" P1
  D="$WORK/f11-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  (cd "$R" && bash "$CUR_SKILL/scripts/team" review P1 --dir "$D") >/dev/null 2>&1
  local v11; v11="$(verdict_of "$R" P1)"
  if [ "$v11" = "TIMEOUT" ]; then case_line F11 "$LABEL" bug "普通失败（日志里有 timeout 字样）被记成 TIMEOUT"
  else case_line F11 "$LABEL" fixed "普通失败（2 秒）记成 $v11（只认 timeout 包装器退出码）"; fi

  # F12 —— --no-gates 的记录与 PASS 是否可区分
  R="$(mkproj f12-$LABEL)"; mktask "$R" P1
  D="$WORK/f12-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  (cd "$R" && bash "$CUR_SKILL/scripts/team" review P1 --dir "$D" --no-gates) >/dev/null 2>&1
  local DIG STA
  DIG="$(cd "$R" && bash "$CUR_SKILL/scripts/team" digest 2>&1)"
  STA="$(cd "$R" && bash "$CUR_SKILL/scripts/team" status P1 2>&1)"
  if grep -q 'gates: none' <<<"$DIG" && grep -q '判定: SKIPPED' <<<"$STA"; then
    case_line F12 "$LABEL" fixed "digest 仍列为待复验（gates: none）｜status 打印判定"
  else
    case_line F12 "$LABEL" bug "SKIPPED 与 PASS 不可区分（digest 里的待复验条目=$(grep -c 'P1-dev' <<<"$DIG")，status 里的判定=$(grep -c '判定' <<<"$STA")）"
  fi

  # F13/F14 —— --strong 的证据判定
  printf '# P1 · keyword only\n\nThere is no 翻转 evidence here and no 独立验证包: the words appear only in this sentence.\n' > "$WORK/f13-body.md"
  printf '# P1 · genuine\n\n## Flip evidence\n\nRed before -> green after: I broke the implementation on purpose and the guard test failed, then I restored it.\n\nThe reproduction lives in an independent verification package (docs/team/reports/P1/pkg) written from scratch; it does not reuse the implementation fixtures.\n' > "$WORK/f14-body.md"
  local name
  for name in f13 f14; do
    R="$(mkproj "s$name-$LABEL")"; mktask "$R" P1
    cp "$WORK/$name-body.md" "$R/.worktrees/dev/docs/team/reports/P1-dev.md"
    git -C "$R/.worktrees/dev" add -A && git -C "$R/.worktrees/dev" commit -qm "docs(P1): $name"
    D="$WORK/s$name-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
    (cd "$R" && bash "$CUR_SKILL/scripts/team" review P1 --dir "$D" --strong) >/dev/null 2>&1
    local v; v="$(grep -m1 -oE '满足强复验|不满足（不阻塞合并' "$R/docs/team/reviews/P1.md" 2>/dev/null || echo '?')"
    if [ "$name" = "f13" ]; then
      if [ "$v" = "满足强复验" ]; then case_line F13 "$LABEL" bug "只字面提到关键词 → 判成「$v」"
      else case_line F13 "$LABEL" fixed "关键词蒙不过去 → 「$v」"; fi
    else
      if [ "$v" = "满足强复验" ]; then case_line F14 "$LABEL" fixed "英文-first 的真证据 → 「$v」"
      else case_line F14 "$LABEL" bug "真证据被判成「$v」"; fi
    fi
  done

  # F14b —— 报告不在 checkout 里（只在主工作树/agent worktree）：PM 退回 M6.2 时复现的现场
  R="$(mkproj f14b-$LABEL)"; mktask "$R" P1
  git -C "$R/.worktrees/dev" rm -q "$R/.worktrees/dev/docs/team/reports/P1-dev.md"
  git -C "$R/.worktrees/dev" commit -qm "chore(P1): report lives outside the checkout"
  mkdir -p "$R/docs/team/reports/P1-dev/pkg"
  { printf '# P1 · report\n\n## Flip evidence\nRed before: guard test failed (see pkg/flip)\nGreen after: guard test passed\n\n'
    printf '## Independent verification package\npkg/run.sh (written for this task, does not reuse the implementation fixtures)\n'; } > "$R/docs/team/reports/P1-dev.md"
  printf '#!/usr/bin/env bash\necho red; echo green\n' > "$R/docs/team/reports/P1-dev/pkg/run.sh"
  D="$WORK/f14b-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  (cd "$R" && bash "$CUR_SKILL/scripts/team" review P1 --dir "$D" --strong --no-gates) >/dev/null 2>&1
  local v14b; v14b="$(grep -m1 -oE '满足强复验|不满足（不阻塞合并' "$R/docs/team/reviews/P1.md" 2>/dev/null || echo '?')"
  if [ "$v14b" = "满足强复验" ]; then case_line F14b "$LABEL" fixed "报告不在 checkout 里也认（采用主工作树那份，并注明不在 checkout）"
  else case_line F14b "$LABEL" bug "报告不在 checkout 里 → 判成「$v14b」（只扫 checkout 的老毛病）"; fi

  # F3 —— 记录绑定 revision：验完再交付一格，待复验信号回不回来
  R="$(mkproj f3-$LABEL)"; mktask "$R" P1
  D="$WORK/f3-$LABEL-dir"; git -C "$R" worktree add -q --detach "$D" task/P1-smoke
  (cd "$R" && bash "$CUR_SKILL/scripts/team" review P1 --dir "$D") >/dev/null 2>&1
  local A; A="$(sed -n 's/.*HEAD: `\([0-9a-f]*\)`.*/\1/p' "$R/docs/team/reviews/P1.md" | head -1)"
  git -C "$R/.worktrees/dev" commit -q --allow-empty -m "feat(P1): delivered after verification"
  DIG="$(cd "$R" && bash "$CUR_SKILL/scripts/team" digest 2>&1)"
  if grep -q 'stale: verified' <<<"$DIG"; then
    case_line F3 "$LABEL" fixed "digest 重新列出：$(grep -m1 -o 'stale: verified [0-9a-f]*, branch now [0-9a-f]*' <<<"$DIG")（记录 HEAD $A）"
  else
    case_line F3 "$LABEL" bug "记录 HEAD $A 之后分支又动了，digest 的待复验仍为空（记录永久压制待办）"
  fi
}

printf '\n== red（修复前）==\n'
run_all RED "$RED_ROOT/skills/teamsmith"
RED_BUGS=$BUG; RED_FIXED=$PASS
PASS=0; BUG=0
printf '\n== green（修复后）==\n'
run_all GREEN "$SKILL_DIR"
GREEN_BUGS=$BUG; GREEN_FIXED=$PASS

printf '\n== 结果 ==\n  red  : BUG-REPRODUCED=%d  BUG-GONE=%d  （10 个 finding/子用例全部必须复现）\n' "$RED_BUGS" "$RED_FIXED"
printf '  green: BUG-GONE=%d  BUG-REPRODUCED=%d  （必须全部已修复）\n' "$GREEN_FIXED" "$GREEN_BUGS"
if [ "$RED_BUGS" = "10" ] && [ "$GREEN_BUGS" = "0" ]; then
  printf '  ✓ 翻转成立：red 全复现 → green 全消失\n'; exit 0
fi
printf '  ✗ 翻转不成立（看上面的逐条输出）\n'; exit 1
