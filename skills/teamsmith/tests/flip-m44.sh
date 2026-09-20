#!/usr/bin/env bash
# M44 · 翻转包：门禁的冲突标记守卫（红 → 绿）
#
#   bash skills/teamsmith/tests/flip-m44.sh
#   bash skills/teamsmith/tests/flip-m44.sh --keep     # 保留临时目录（排查）
#
# 事故（2026-09-19，PM 自伤）：把 M43 合进 main 时 `git merge --squash` 报了冲突，PM 用
# `git add -A && git commit` 一把提交 —— 三件套跟着进了被保护分支。当时的门禁里**没有任何一条断言**
# 能拦下它（PM 事后自查 `grep -rln '^<<<<<<<'` 才发现，随后 amend）。M44 补的就是这条。
#
# 探针 = smoke.sh 的**前导** + §0d（同一份判据，不是抄来的第二份）+ 结果行，对着九个现场各跑一遍：
#   ① 干净临时仓库                        → 绿（判据不误报，也不是「总是红」）
#   ② 真事故现场：`merge --squash` 冲突后 `add -A && commit` → 红，且逐条点名 `<文件>:<行号>`
#   ③ ② 的现场把冲突**真解掉**再提交       → 绿（同一现场、同一判据的红→绿）
#   ④ 干净仓库 + 未跟踪文件里有三件套      → 绿（判据只扫已跟踪）
#   ⑤ 本 worktree 真树                     → 绿
#   ⑥ 索引里有三件套、工作树已改回干净     → 红（暂存侧那条路；没有它，下次提交会把标记写进历史）
#   ⑦ 变异 m1：判据改成永不匹配            → ②的现场不再红 ⇒ ②的红真的咬在判据上
#   ⑧ 变异 m2：`git grep --untracked`      → ④的现场变红 ⇒「只扫已跟踪」这条边界是活的
#   ⑨ 变异 m3：去掉索引侧那条 grep         → ⑥的现场不再红 ⇒ ⑥的红来自 --cached
#
# 退出码：0 = 九条预期全部成立；1 = 有预期不成立（不算绿也不算红以外的结论）；2 = 环境/前置不满足。
# 隔离：只读本仓库（`git rev-parse` + 截取 smoke 段），只写 /tmp 下的临时目录；探针自带 smoke 的前导
#   （清 TEAM_*/TMUX 身份、私有 TMUX_TMPDIR、$TMP 哨兵），EXIT 时自己收干净；本脚本不用 tmux。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
SMOKE="$SKILL_DIR/tests/smoke.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

KEEP=0
case "${1:-}" in
  "") ;;
  --keep) KEEP=1 ;;
  -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
  *) printf 'flip-m44: 未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

die2() { printf 'flip-m44: %s\n' "$*" >&2; exit 2; }
command -v git >/dev/null 2>&1 || die2 "需要 git"
[ -s "$SMOKE" ] || die2 "找不到 $SMOKE"
[ -n "$REPO_ROOT" ] || die2 "$SKILL_DIR 不在 git 工作树里（⑤ 需要一个真树）"

TMP="$(mktemp -d /tmp/teamsmith-flip-m44.XXXXXX)"
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; [ "$KEEP" = "1" ] || rm -rf "$TMP"; return 0; }
trap cleanup EXIT

pass() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$*"; }

# 三件套只以变量形式出现：本文件也是**受版本控制**的文件，自己必须过它检查的那条判据。
CM_LT='<<<<<<<'; CM_EQ='======='; CM_GT='>>>>>>>'
MARKER_RE='^(<<<<<<<( |$)|={7,}$|>>>>>>>( |$))'   # 只给「前置是否真的造出来了」用，不是被测判据

# ── 探针：smoke 前导（helpers/夹具函数/身份清洗）+ §0d + 结果行 ───────────────────────────────
build_probe() { # <输出>：截取当前 smoke.sh；判据就是被测的那一份，不是副本
  local out="$1"
  {
    awk '/^# -+ 0\. 仓库/{exit} {print}' "$SMOKE"
    awk '/^section "0d /{f=1} f&&/^section "/&&!/0d /{exit} f{print}' "$SMOKE"
    cat <<'EOS'
section "PROBE-0D-END"
printf '\n== 结果 ==  ok %d  bad %d\n' "$PASS" "$FAIL"
printf 'PROBE-0D-END\n'
[ "$FAIL" -eq 0 ] && exit 0
exit 1
EOS
  } | sed "s|^SKILL_DIR=.*|SKILL_DIR=\"$SKILL_DIR\"|" > "$out"
  grep -q '^section "0d ' "$out" || die2 "$SMOKE 里没有 0d 段（M44 的守卫不在？）"
  bash -n "$out" || die2 "探针语法不对（截取写坏了）：$out"
  return 0
}

# TEAM_SMOKE_NO_LOCK=1 是必需的：全量门禁的 flock 包装会 `exec … smoke.sh` 把探针换成整份门禁。
# 形状守卫（PROBE-0D-END）再兜一层：拿到的不是聚焦探针就停，不给假结论。
run_probe() { # <探针> <marker 根> <日志> → rc
  TEAM_SMOKE_NO_LOCK=1 TEAM_SMOKE_MARKER_ROOT="$2" bash "$1" > "$3" 2>&1
}
probe_shape() { # <日志>
  grep -q '^PROBE-0D-END$' "$1" || die2 "拿到的不是聚焦探针（$1 里没有 PROBE-0D-END）：$(tail -1 "$1" 2>/dev/null)"
}
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
verdict_line() { plain "$1" | grep -E '^  (✓|✗) 受版本控制的文件' | head -1; }
show_0d() { plain "$1" | grep -A5 '== 0d' | sed 's/^/      /'; }

# ── 现场 ─────────────────────────────────────────────────────────────────────────────────────
mk_clean() { # <dir>：干净仓库（notes.md 无标记）
  rm -rf "$1"; mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.email smoke@teamsmith
  git -C "$1" config user.name smoke
  printf 'one\ntwo\nthree\n' > "$1/notes.md"
  git -C "$1" add -A
  git -C "$1" commit -qm "chore: init"
}
# 复刻事故：两侧改同一行（分叉）→ `git merge --squash` 冲突 → `git add -A && git commit` 一把提交
mk_accident() { # <dir> <证据日志>
  mk_clean "$1"
  git -C "$1" checkout -q -b task
  printf 'one\n2\nthree\n' > "$1/notes.md"; git -C "$1" commit -aqm "task: line 2"
  git -C "$1" checkout -q main
  printf 'one\nTWO\nthree\n' > "$1/notes.md"; git -C "$1" commit -aqm "main: line 2"
  { git -C "$1" merge --squash task
    printf -- '-- git status --porcelain（事故当口）--\n'
    git -C "$1" status --porcelain
  } > "$2" 2>&1
  git -C "$1" add -A
  git -C "$1" commit -qm "M43: squash merge（事故形状：add -A 一把提交）"
}
resolve_conflict() { # <dir>：真解冲突（两条腿都留下），不是删掉标记了事
  printf 'one\nTWO and 2\nthree\n' > "$1/notes.md"
  git -C "$1" add -A
  git -C "$1" commit -qm "resolve: 真解掉冲突"
}
# 索引侧现场（M44 加严的形状）：`git add` 带标记的版本，再把工作树改回干净 —— 工作树侧看不见，
# 但下一次提交会把它写进历史（`--cached` 那条路要拦的就是这个）
mk_staged() { # <dir>
  mk_clean "$1"
  printf 'one\n%s HEAD\nours\n%s\ntheirs\n%s task\nthree\n' "$CM_LT" "$CM_EQ" "$CM_GT" > "$1/notes.md"
  git -C "$1" add notes.md
  printf 'one\nTWO and 2\nthree\n' > "$1/notes.md"
}
head_has_markers() { # <dir> <相对路径>：HEAD 里的该文件是否带三件套（前置检查，不是被测判据）
  git -C "$1" show "HEAD:$2" 2>/dev/null | grep -qE "$MARKER_RE"
}

CLEAN="$TMP/clean"; ACC="$TMP/accident"; UNTRK="$TMP/untracked"; STAGED="$TMP/staged"
PROBE="$TMP/probe.sh"
build_probe "$PROBE"
mk_clean "$CLEAN"
mk_accident "$ACC" "$TMP/accident-merge.log"
head_has_markers "$ACC" notes.md || die2 "事故现场没造出来（HEAD:notes.md 里没有三件套）—— 前置不满足"
mk_clean "$UNTRK"
printf 'one\n%s HEAD\nours\n%s\ntheirs\n%s feature\n' "$CM_LT" "$CM_EQ" "$CM_GT" > "$UNTRK/tmp-leftover.md"
git -C "$UNTRK" status --porcelain | grep -q '^?? tmp-leftover.md' \
  || die2 "未跟踪夹具不成立（tmp-leftover.md 不是未跟踪的）"
mk_staged "$STAGED"
git -C "$STAGED" status --porcelain | grep -q '^MM notes.md' \
  || die2 "索引侧夹具不成立（期望 git status 的 MM notes.md）"

RC=0
printf '\033[1m== flip-m44 · 冲突标记守卫（探针 = smoke 前导 + §0d，%s 行）==\033[0m\n' "$(wc -l < "$PROBE")"
printf '  事故现场原始证据（%s）：\n' "$TMP/accident-merge.log"
sed 's/^/      /' "$TMP/accident-merge.log"

# ── ① 干净仓库 → 绿 ──────────────────────────────────────────────────────────────────────────
run_probe "$PROBE" "$CLEAN" "$TMP/1-clean.log"; rc=$?
probe_shape "$TMP/1-clean.log"
if [ "$rc" -eq 0 ] && printf '%s' "$(verdict_line "$TMP/1-clean.log")" | grep -q '✓'; then
  pass "① 干净仓库：绿（判据不误报，也不是「总是红」）"
else
  fail "① 干净仓库期望绿，实际 rc=$rc / $(verdict_line "$TMP/1-clean.log")"; show_0d "$TMP/1-clean.log"; RC=1
fi

# ── ② 真事故现场 → 红 + 逐条点名 file:line ───────────────────────────────────────────────────
run_probe "$PROBE" "$ACC" "$TMP/2-accident.log"; rc=$?
probe_shape "$TMP/2-accident.log"
missing=""
for want in 'notes.md:2:' 'notes.md:4:' 'notes.md:6:'; do
  plain "$TMP/2-accident.log" | grep -q "     $want" || missing="$missing $want"
done
if [ "$rc" -ne 0 ] && [ -z "$missing" ]; then
  pass "② 事故现场（merge --squash 冲突 + add -A && commit）：红，并逐条点名 notes.md:2 / :4 / :6"
else
  fail "② 事故现场期望「红 + 点名三行」，实际 rc=$rc；漏点名：${missing:-无}"
  show_0d "$TMP/2-accident.log"; RC=1
fi

# ── ③ 同一现场真解掉 → 绿（红→绿） ───────────────────────────────────────────────────────────
resolve_conflict "$ACC"
head_has_markers "$ACC" notes.md && { fail "③ 前置不成立：解冲突后 HEAD:notes.md 仍带三件套"; RC=1; }
run_probe "$PROBE" "$ACC" "$TMP/3-resolved.log"; rc=$?
probe_shape "$TMP/3-resolved.log"
if [ "$rc" -eq 0 ]; then
  pass "③ 解掉冲突后再提交：回到绿（②的现场，同一判据红→绿）"
else
  fail "③ 解冲突后期望绿，实际 rc=$rc"; show_0d "$TMP/3-resolved.log"; RC=1
fi

# ── ④ 未跟踪文件里的三件套 → 绿（只扫已跟踪） ─────────────────────────────────────────────────
run_probe "$PROBE" "$UNTRK" "$TMP/4-untracked.log"; rc=$?
probe_shape "$TMP/4-untracked.log"
if [ "$rc" -eq 0 ]; then
  pass "④ 未跟踪的临时文件里有三件套：绿（判据只扫已跟踪文件）"
else
  fail "④ 未跟踪文件期望绿，实际 rc=$rc"; show_0d "$TMP/4-untracked.log"; RC=1
fi

# ── ⑤ 本 worktree 真树 → 绿 ──────────────────────────────────────────────────────────────────
run_probe "$PROBE" "$REPO_ROOT" "$TMP/5-this-tree.log"; rc=$?
probe_shape "$TMP/5-this-tree.log"
if [ "$rc" -eq 0 ]; then
  pass "⑤ 本 worktree（$REPO_ROOT）：绿"
else
  fail "⑤ 本 worktree 期望绿，实际 rc=$rc"; show_0d "$TMP/5-this-tree.log"; RC=1
fi

# ── ⑥ 索引侧：标记已 add、工作树已改回干净 → 仍要红（--cached 那条路） ─────────────────────────
run_probe "$PROBE" "$STAGED" "$TMP/6-staged.log"; rc=$?
probe_shape "$TMP/6-staged.log"
missing=""
for want in 'notes.md:2:' 'notes.md:4:' 'notes.md:6:'; do
  plain "$TMP/6-staged.log" | grep -q "     $want" || missing="$missing $want"
done
if [ "$rc" -ne 0 ] && [ -z "$missing" ]; then
  pass "⑥ 索引里有三件套、工作树干净：红并点名 notes.md:2/4/6（下一次提交会写进历史，不许放行）"
  printf '       git status 现场：%s\n' "$(git -C "$STAGED" status --porcelain | tr '\n' ' ')"
else
  fail "⑥ 索引侧期望「红 + 点名三行」，实际 rc=$rc；漏点名：${missing:-无}"; show_0d "$TMP/6-staged.log"; RC=1
fi

# ── ⑦ 变异 m1：判据永不匹配 → 事故现场不再红（②的红咬在判据上） ──────────────────────────────
MUT1="$TMP/probe-mut1.sh"; cp "$PROBE" "$MUT1"
sed -i "s|^CM_RE=.*|CM_RE='^ZZZ-NEVER-MATCHES'|" "$MUT1"
grep -qF "CM_RE='^ZZZ-NEVER-MATCHES'" "$MUT1" || die2 "变异 m1 没打上（0d 段的 CM_RE 行形状变了？）"
run_probe "$MUT1" "$ACC" "$TMP/7-mut1.log"
probe_shape "$TMP/7-mut1.log"
m1="$(verdict_line "$TMP/7-mut1.log")"
if printf '%s' "$m1" | grep -q '✓'; then
  pass "⑦ 变异 m1（CM_RE 永不匹配）：同一个事故现场不再红 —— ② 的红来自判据本身"
  printf '       变异探针的其余红（自测段发现判据被改坏）也算证据，此处只判 0d 的判定行：%s\n' "$m1"
else
  fail "⑦ 变异 m1 期望「不再红」，实际仍报红：$m1"; show_0d "$TMP/7-mut1.log"; RC=1
fi

# ── ⑧ 变异 m2：git grep --untracked → ④的现场变红（「只扫已跟踪」是活的边界） ────────────────
MUT2="$TMP/probe-mut2.sh"; cp "$PROBE" "$MUT2"
sed -i 's| -I -E "$CM_RE" -- \.| -I --untracked -E "$CM_RE" -- .|' "$MUT2"
grep -q -- '--untracked' "$MUT2" || die2 "变异 m2 没打上（git grep 那行的形状变了？）"
run_probe "$MUT2" "$UNTRK" "$TMP/8-mut2.log"
probe_shape "$TMP/8-mut2.log"
m2="$(verdict_line "$TMP/8-mut2.log")"
if printf '%s' "$m2" | grep -q '✗'; then
  pass "⑧ 变异 m2（--untracked）：未跟踪文件被误报 —— ④ 的绿不是侥幸"
  printf '       %s\n' "$m2"
  plain "$TMP/8-mut2.log" | grep -E '^     tmp-leftover\.md' | sed 's/^/       /'
else
  fail "⑧ 变异 m2 期望「误报未跟踪文件」，实际未报红：$m2"; show_0d "$TMP/8-mut2.log"; RC=1
fi

# ── ⑨ 变异 m3：去掉索引侧那条 grep → ⑥的现场不再红（加严的那条路真的是它在拦） ──────────────
MUT3="$TMP/probe-mut3.sh"; cp "$PROBE" "$MUT3"
sed -i 's| -I --cached -E "$CM_RE"| -I -E "$CM_RE"|' "$MUT3"
grep -qF -- ' -I --cached -E "$CM_RE"' "$MUT3" && die2 "变异 m3 没打上（索引侧那行的形状变了？）"
run_probe "$MUT3" "$STAGED" "$TMP/9-mut3.log"
probe_shape "$TMP/9-mut3.log"
m3="$(verdict_line "$TMP/9-mut3.log")"
if printf '%s' "$m3" | grep -q '✓'; then
  pass "⑨ 变异 m3（去掉 --cached）：同一个索引侧现场不再红 —— ⑥ 的红来自索引侧那条路"
  printf '       %s\n' "$m3"
else
  fail "⑨ 变异 m3 期望「不再红」，实际仍报红：$m3"; show_0d "$TMP/9-mut3.log"; RC=1
fi

printf '\n== 结果 ==  %s\n' "$([ "$RC" -eq 0 ] && printf '九条预期全部成立（红→绿 + 三条变异）' || printf '有预期不成立')"
[ "$KEEP" = "1" ] && printf '保留临时目录：%s\n' "$TMP"
printf 'exit=%s\n' "$RC"
exit "$RC"
