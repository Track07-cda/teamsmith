#!/usr/bin/env bash
# M16 · 独立验证包：digest / status / roster 的「代号必须带名字」红 → 绿
#
#   bash skills/teamsmith/tests/flip-m16.sh                 # 红树 = 任务分支与保护分支的分叉点，绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m16.sh
#
# 为什么需要：M16 是**用户反馈**（“PM 只用代号指代事务，用户不一定记得这些编号”），它的判据不是一个
# 断言字符串，而是「凡面向人的输出出现代号，同一行必须有它的短名字」。这条判据在本仓库只被 smoke §30
# 守着，而 §30 只在交付后存在 —— 这个包用**同一份夹具**对**两棵 skill 树**各跑一遍 digest，证明：
#
#   红（分叉点）：`M16A-dev` —— 代号单独出现（旧行为，用户看不懂）；
#   绿（本树）  ：`M16A-dev（夹具甲：代号必须带名字）` —— 同一行带名字；
#   变异（绿树副本里把 team_task_name 改成永远返回空）：名字消失 → 同一判据必须**红**（守门断言可被证伪，
#                不是「不管实现怎样都报绿」的空转扫描）。
#
# 只写 /tmp 下的临时目录；不碰调用者所在的任何仓库/session（身份隔离：先证明 team paths 指向夹具仓库）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m16: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || { printf 'flip-m16: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-m16)" || exit 3
cleanup() { tmp_root_reap_all; }
trap cleanup EXIT

# ---- 红树（修复前） / 绿树（修复后） -----------------------------------------
mkdir -p "$TMP/red"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_SKILL="$TMP/red/skills/teamsmith"
GREEN_SKILL="$SKILL_DIR"
# 守卫：传进来的 base 必须真的还是「修复前」，否则这个包会报出一个假的翻转
if grep -qF 'team_task_name' "$RED_SKILL/scripts/lib/cmd-status.sh" 2>/dev/null; then
  printf 'flip-m16: $BASE 已经包含 M16 的实现（cmd-status.sh 里已有 team_task_name）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
grep -qF 'team_task_name' "$GREEN_SKILL/scripts/lib/cmd-status.sh" \
  || { printf 'flip-m16: 绿树（本 worktree）里没有 M16 的实现 —— 这个包没什么可翻的\n' >&2; exit 2; }

# ---- 夹具仓库：一份假 BOARD + 假报告集（三类名字来源 + 一个查不到名字的负对照）-----
# 身份隔离（M7.2 纪律）：绝不继承调用者的 TEAM_*；写完配置先证明 team paths 指向夹具仓库再动账本。
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION \
      TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES \
      TEAM_VCS TEAM_CONFIG_FILE TEAM_SKILL_DIR 2>/dev/null || true
REPO="$TMP/repo"; SES="flip-m16-$$"
mkdir -p "$REPO"
(
  cd "$REPO" || exit 1
  git init -q -b main .
  git config user.email flip@teamsmith
  git config user.name flip
  echo "# flip m16 fixture" > README.md
  git add -A && git commit -qm "chore: init"
  bash "$GREEN_SKILL/scripts/team" init --session "$SES" --agents "dev verify" --vcs local --gates true --docs docs/team >/dev/null 2>&1
  mkdir -p docs/team/tasks docs/team/reports
  {
    printf '| M16A | 夹具甲：代号必须带名字 | dev | - | - | wip |\n'
    printf '| M16D | — | dev | - | - | wip |\n'
  } >> docs/team/BOARD.md
  # ① 看板任务列有名字；② 只有任务书有名字（看板没有这一行）；③ 看板/任务书都没名字 → 报告 H1 兜底；
  # ④ 哪里都没名字（负对照：只印代号，不编名字）
  printf '# M16A · 夹具甲：代号必须带名字\ntask:   M16A\nagent:  dev\n' > docs/team/tasks/M16A-m16.md
  printf '# M16A · 夹具甲：代号必须带名字\nagent: dev  状态: DONE\n' > docs/team/reports/M16A-dev.md
  printf '# M16B · 夹具乙：任务书里的名字\ntask:   M16B\nagent:  dev\n' > docs/team/tasks/M16B-m16.md
  printf '# M16C\ntask:   M16C\nagent:  dev\n' > docs/team/tasks/M16C-m16.md
  printf '# M16C · 报告里的短名\nagent: dev  状态: DONE\n' > docs/team/reports/M16C-dev.md
  printf '# M16D\nagent: dev  状态: DONE\n' > docs/team/reports/M16D-dev.md
  mkdir -p .pi/team/state
  printf 'task=M16B\nwindow=dev\nworktree=%s\n' "$REPO/.worktrees/dev" > .pi/team/state/dev.env
) || { printf 'flip-m16: 夹具仓库初始化失败\n' >&2; exit 2; }

# 夹具身份自检：paths 的 main_root 必须是夹具仓库，session 必须是本轮临时 session
( cd "$REPO" && bash "$GREEN_SKILL/scripts/team" paths ) >"$TMP/paths.json" 2>&1 || true
PATHS_ROOT="$(sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' "$TMP/paths.json")"
[ "$PATHS_ROOT" = "$REPO" ] || { printf 'flip-m16: 身份隔离失败（paths.main_root=%s，期望 %s）\n' "$PATHS_ROOT" "$REPO" >&2; exit 2; }
grep -qF "\"session\": \"$SES\"" "$TMP/paths.json" || { printf 'flip-m16: 身份隔离失败（session 不是本轮临时 session）\n' >&2; exit 2; }

FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
show_names() { # <log>：把待复验/建议里点名夹具代号的行打出来当证据
  grep -E '^  M16[ABCD]|未在跑但仍有任务 M16' "$1" 2>/dev/null | head -6 | sed 's/^/      /'
}
assert_has_str() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3（找不到 [$2]）" ;; esac; }

run_digest() { # <skill-dir> <log>
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      bash "$1/scripts/team" digest ) >"$2" 2>&1
}

# 判据（与 smoke §30 同义、独立实现）：
#   ① 每个夹具代号都必须在输出里出现（否则扫描空转 = 假绿）；
#   ② 凡含代号的行都必须含它的名字（同一行）；
#   ③ 名字从三个来源都能取到（看板 / 任务书 / 报告 H1）；④ 查不到名字时只印代号。
name_check() { # <log> → 0 = 名字都在（实现正确）
  local log="$1" id name line pair
  for pair in 'M16A|夹具甲：代号必须带名字' 'M16B|夹具乙：任务书里的名字' 'M16C|报告里的短名'; do
    id="${pair%%|*}"; name="${pair#*|}"
    grep -qF -- "$id" "$log" || return 1
    while IFS= read -r line; do
      case "$line" in *"$id"*) ;; *) continue ;; esac
      case "$line" in *"$name"*) ;; *) return 1 ;; esac
    done < "$log"
  done
  # ④ 负对照：查不到名字 → 只印代号（不编名字）
  grep -qF -- 'M16D-dev' "$log" || return 1
  if { grep -F -- 'M16D-dev' "$log" || true; } | grep -qF '（'; then return 1; fi
  return 0
}

printf 'flip-m16 · 红树=%s 绿树=%s\n' "$BASE" "$GREEN_SKILL"

# ---- 红：旧行为，代号单独出现 ------------------------------------------------
run_digest "$RED_SKILL" "$TMP/red.log"
if name_check "$TMP/red.log"; then
  bad "修复前竟然已经带名字（这不是修复前的树：检查 TEAM_FLIP_BASE）"
else
  ok "红（修复前）：夹具代号在同一行没有名字（判据会红）"
fi
printf '      红树 [3] 待复验：\n'; show_names "$TMP/red.log"
if grep -qF -- 'M16A-dev' "$TMP/red.log"; then ok "红树确实印了 M16A-dev（代号没丢，只是没有名字）"
else bad "红树里连 M16A-dev 都没有 —— 夹具不对，翻转没有意义"; fi

# ---- 绿：本树，代号带名字 ----------------------------------------------------
run_digest "$GREEN_SKILL" "$TMP/green.log"
if name_check "$TMP/green.log"; then
  ok "绿（本树）：所有夹具代号都在同一行带上名字"
else
  bad "绿树仍有代号没带名字（见 $TMP/green.log）"
fi
GREEN_OUT="$(cat "$TMP/green.log")"
assert_has_str "$GREEN_OUT" 'M16A-dev（夹具甲：代号必须带名字）' "绿树：看板任务列的名字"
assert_has_str "$GREEN_OUT" 'M16B（夹具乙：任务书里的名字）' "绿树：任务书 H1 的名字"
assert_has_str "$GREEN_OUT" 'M16C-dev（报告里的短名）' "绿树：报告 H1 兜底的名字"
assert_has_str "$GREEN_OUT" 'M16D-dev' "绿树：查不到名字时照旧印代号"
printf '      绿树 [3] 待复验：\n'; show_names "$TMP/green.log"

# ---- 变异：绿树副本里把 team_task_name 改成永远返回空 → 判据必须红（可证伪）--------
MUT="$TMP/mut-skill"
rm -rf "$MUT"; cp -r "$GREEN_SKILL" "$MUT"
awk '{ print; if ($0 ~ /^team_task_name\(\) \{/) print "  return 0  # mutation: never resolve a name" }' \
  "$GREEN_SKILL/scripts/lib/cmd-status.sh" > "$MUT/scripts/lib/cmd-status.sh"
if ! grep -qF 'mutation: never resolve a name' "$MUT/scripts/lib/cmd-status.sh"; then
  bad "变异夹具没生效（没找到 team_task_name 定义）"
else
  run_digest "$MUT" "$TMP/mut.log"
  if name_check "$TMP/mut.log"; then
    bad "变异树（不解析名字）竟然还是绿 —— 判据是空的，没有在守实现"
  else
    ok "变异：去掉名字解析后同一判据变红（守门断言可被证伪）"
  fi
  printf '      变异树 [3] 待复验：\n'; show_names "$TMP/mut.log"
fi

printf '\n== 结果 == %s\n' "$([ "$FAIL" -eq 0 ] && echo 'flip 全绿（红→绿→变异红）' || echo "flip 有 $FAIL 项失败")"
[ "$FAIL" -eq 0 ] || exit 1
