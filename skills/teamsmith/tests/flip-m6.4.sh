#!/usr/bin/env bash
# M6.4 · 独立验证包：V4.0 F4/F6/F19/F21/F23 的 red → green 复现
#
#   bash skills/teamsmith/tests/flip-m6.4.sh                 # 红树 = 与保护分支的分叉点，绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m6.4.sh
#
# 为什么需要：M6.4 修的是「信号与承诺的诚实」——每一条都是「旧版真的会发错信号」。
# 这个包**不复用 smoke 的夹具**：自己建仓库/自带 upstream 的 worktree/会议目录，对同一份现场
# 分别跑「修复前」和「修复后」两棵 skill 树，断言旧版会红、新版会绿：
#
#   F4  已 push（@{upstream}..HEAD=0）但领先 main 的分支：旧版 digest 喊「收尾：提交并 push」，新版不喊
#   F6  id 带 '-' 的任务（API-2）：旧版把 reports/API-2-dev.md 当 id=API → 「忽略的非任务报告」，新版待复验
#   F19 会议 TTL：旧版 --ttl 0 接受、TTL_HOURS=abc 的历史会议永生，新版拒绝/按默认值判定过期
#   F21 落后会话的 version --check：旧版退出码 141（SIGPIPE），新版 0
#   F23 team reload：旧版承诺「watchdog 看到 marker 会重启 PM 会话」，新版删掉承诺、只说实的
#
# 只写 /tmp 下的临时目录，不碰调用者所在的任何仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m6.4: 找不到 git 仓库（需要 git archive 取修复前的树）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
if [ -z "$BASE" ]; then
  BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
fi
[ -n "$BASE" ] || { printf 'flip-m6.4: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m6.4.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ---- 红树（修复前） / 绿树（修复后） -----------------------------------------
mkdir -p "$TMP/red"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_SKILL="$TMP/red/skills/teamsmith"
GREEN_SKILL="$SKILL_DIR"
# 守卫：传进来的 base 必须真的还是「修复前」，否则这个包会报出一个假的「翻转」
for probe in 'team_git_upstream_ahead:scripts/lib/cmd-status.sh' \
             'team_report_task_id:scripts/lib/common.sh' \
             'team_meeting_ttl_hours:scripts/lib/cmd-meeting.sh' \
             '没有任何组件会因为 marker 重启会话:scripts/lib/cmd-update.sh'; do
  f="${probe#*:}"; needle="${probe%%:*}"
  if grep -qF "$needle" "$RED_SKILL/$f" 2>/dev/null; then
    printf 'flip-m6.4: $BASE 已经包含 M6.4 的修复（%s 里已有 %s）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' "$f" "$needle" >&2
    exit 2
  fi
done

# ---- 夹具仓库（同一个现场，两棵树各跑一遍） ----------------------------------
REPO="$TMP/repo"; mkdir -p "$REPO"
export TEAM_MEETINGS_DIR="$TMP/meetings"
(
  cd "$REPO" || exit 1
  git init -q -b main .
  git config user.email flip@teamsmith
  git config user.name flip
  echo "# flip fixture" > README.md
  git add -A && git commit -qm "chore: init"
  bash "$GREEN_SKILL/scripts/team" init --session flip-m64 --agents dev --vcs local --gates true --docs docs/team >/dev/null 2>&1
  mkdir -p docs/team/reports
) || { printf 'flip-m6.4: 夹具仓库初始化失败\n' >&2; exit 2; }

FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

team() { # <skill-dir> <log> <args...>（不覆盖名册）
  local sk="$1" log="$2"; shift 2
  ( cd "$REPO" && bash "$sk/scripts/team" "$@" ) >"$log" 2>&1
  TEAM_RC=$?
}
team_agents() { # <名册> <skill-dir> <log> <args...>（临时覆盖名册：环境变量优先于 config）
  local agents="$1" sk="$2" log="$3"; shift 3
  ( cd "$REPO" && TEAM_AGENTS="$agents" bash "$sk/scripts/team" "$@" ) >"$log" 2>&1
  TEAM_RC=$?
}
tailof() { grep -F -- "$2" "$1" | head -3; }

printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n夹具仓库:     %s\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$GREEN_SKILL" "$REPO"

# ---------------------------------------------------------------- F4
printf '\n=== F4 · push 状态必须相对 @{upstream} ===\n'
F4WT="$REPO/.worktrees/f4"
git -C "$REPO" init -q --bare "$TMP/origin.git"
git -C "$REPO" worktree add -q -b task/F4 "$F4WT" main >/dev/null 2>&1 || true
printf 'one\n' > "$F4WT/f4.txt"
git -C "$F4WT" add -A >/dev/null 2>&1 && git -C "$F4WT" commit -qm "feat: demo" >/dev/null 2>&1
git -C "$REPO" remote add origin "$TMP/origin.git" >/dev/null 2>&1 || true
git -C "$F4WT" push -q -u origin task/F4 >/dev/null 2>&1
printf '现场：@{upstream}..HEAD=%s（真的没东西可 push）   main..HEAD=%s（旧版拿这个当下面的「未 push」）\n' \
  "$(git -C "$F4WT" rev-list --count '@{upstream}..HEAD')" "$(git -C "$F4WT" rev-list --count main..HEAD)"

team_agents f4 "$RED_SKILL" "$TMP/f4-red.log" digest
team_agents f4 "$GREEN_SKILL" "$TMP/f4-green.log" digest
printf '[红] digest §[4] 相关行：\n'; tailof "$TMP/f4-red.log" "收尾：提交并 push" | sed 's/^/      /'
printf '[绿] digest §[4] 相关行：\n'; tailof "$TMP/f4-green.log" "未 push" | sed 's/^/      /'
if grep -qF '收尾：提交并 push' "$TMP/f4-red.log"; then
  ok "修复前：已 push 的分支被喊「收尾：提交并 push」（这就是 F4 的假信号）"
else bad "修复前：夹具没造出假信号（旧版竟然没喊 push）"; fi
if grep -qF '收尾：提交并 push' "$TMP/f4-green.log"; then
  bad "修复后：已 push 的分支仍然被喊 push"
else ok "修复后：@{upstream}..HEAD=0 → 不再被当成未收尾"; fi
if grep -qF '领先 1' "$TMP/f4-red.log" && ! grep -qF '领先 1' "$TMP/f4-green.log"; then
  ok "修复后：相对 main 的领先数不再冒充「未 push」（绿树 §[4] 里没有它）"
else bad "修复后：关于「领先 main」的表达没有变（红有/绿无 这个差分不成立）"; fi

# ---------------------------------------------------------------- F6
printf '\n=== F6 · id 带 "-" 的任务报告（API-2） ===\n'
team "$GREEN_SKILL" "$TMP/f6-task.log" task API-2 --title "api-2 endpoint" --agent dev
printf '%s\n' '# API-2 · api-2 endpoint' '' 'agent: dev   status: DONE' > "$REPO/docs/team/reports/API-2-dev.md"
team "$RED_SKILL" "$TMP/f6-red.log" digest
team "$GREEN_SKILL" "$TMP/f6-green.log" digest
printf '[红] 忽略清单/待复验：\n'; { tailof "$TMP/f6-red.log" "忽略的非任务报告" | sed 's/^/      /'; tailof "$TMP/f6-red.log" "review API" | sed 's/^/      /'; }
printf '[绿] 忽略清单/待复验：\n'; { tailof "$TMP/f6-green.log" "忽略的非任务报告" | sed 's/^/      /'; tailof "$TMP/f6-green.log" "review API" | sed 's/^/      /'; }
if grep -qF '忽略的非任务报告：API-2-dev.md' "$TMP/f6-red.log" && ! grep -qF 'review API-2' "$TMP/f6-red.log"; then
  ok "修复前：正式任务 API-2 的报告落进「忽略的非任务报告」，也不在待复验里（F6）"
else bad "修复前：夹具没造出误判（旧版没有把 API-2-dev.md 忽略）"; fi
if grep -qF 'review API-2' "$TMP/f6-green.log" && ! grep -qF '忽略的非任务报告：API-2-dev.md' "$TMP/f6-green.log"; then
  ok "修复后：API-2 的报告进入待复验，且带完整 id"
else bad "修复后：API-2 的报告仍然被判成非任务报告"; fi

# ---------------------------------------------------------------- F19
printf '\n=== F19 · 会议 TTL 不能是垃圾值/永生 ===\n'
team "$RED_SKILL"  "$TMP/f19-red.log"  meeting open ttl-zero --with other --topic "ttl 0" --ttl 0 --yes
RED_TTL_RC="$TEAM_RC"
team "$GREEN_SKILL" "$TMP/f19-green.log" meeting open ttl-zero --with other --topic "ttl 0" --ttl 0 --yes
GREEN_TTL_RC="$TEAM_RC"
printf '[红] rc=%s  登记值：%s\n' "$RED_TTL_RC" "$(grep -s '^TTL_HOURS=' "$TMP/meetings/ttl-zero/state.env" 2>/dev/null || echo '（没有 state.env）')"
printf '[绿] rc=%s  %s\n' "$GREEN_TTL_RC" "$(grep -sF '正整数小时' "$TMP/f19-green.log" | head -1)"
if [ "$RED_TTL_RC" = "0" ]; then ok "修复前：--ttl 0 被接受（会议成了永生）"
else bad "修复前：夹具没造出「永生」格（--ttl 0 竟然被拒）"; fi
if [ "$GREEN_TTL_RC" != "0" ]; then ok "修复后：--ttl 0 非 0 退出（被拒绝）"
else bad "修复后：--ttl 0 仍然被接受"; fi

# 历史遗留的非法登记值：旧版永生，新版按默认值判定过期
team "$GREEN_SKILL" "$TMP/f19-legacy-open.log" meeting open ttl-legacy --with other --topic "legacy" --yes
sed -i 's/^TTL_HOURS=.*/TTL_HOURS=abc/' "$TMP/meetings/ttl-legacy/state.env"
sed -i 's/^OPENED_EPOCH=.*/OPENED_EPOCH=1000/' "$TMP/meetings/ttl-legacy/state.env"
team "$RED_SKILL" "$TMP/f19-legacy-red.log" meeting read ttl-legacy --peek
team "$GREEN_SKILL" "$TMP/f19-legacy-green.log" meeting read ttl-legacy --peek
team "$RED_SKILL" "$TMP/f19-say-red.log" meeting say ttl-legacy --intent info "54 年后还能说吗"
RED_SAY_RC="$TEAM_RC"
team "$GREEN_SKILL" "$TMP/f19-say-green.log" meeting say ttl-legacy --intent info "54 年后还能说吗"
GREEN_SAY_RC="$TEAM_RC"
printf '[红] read：%s  ｜ say rc=%s\n' "$(grep -sF 'TTL' "$TMP/f19-legacy-red.log" | head -1 | sed 's/^[[:space:]]*//')" "$RED_SAY_RC"
printf '[绿] read：%s  ｜ say rc=%s\n' "$(grep -sF 'TTL' "$TMP/f19-legacy-green.log" | head -1 | sed 's/^[[:space:]]*//')" "$GREEN_SAY_RC"
if [ "$RED_SAY_RC" = "0" ]; then ok "修复前：TTL_HOURS=abc 的老会议 54 年后仍然能发言（F19 的永生）"
else bad "修复前：夹具没造出永生（旧版竟然拒绝了 say）"; fi
if [ "$GREEN_SAY_RC" != "0" ]; then ok "修复后：非法 TTL 按默认值判过期（say 被拒）"
else bad "修复后：非法 TTL 的老会议仍然能发言"; fi
if grep -qF 'TTL abch' "$TMP/f19-legacy-red.log"; then ok "修复前：read 把登记值原样印成 \"TTL abch\""
else bad "修复前：read 没有印出 \"TTL abch\"（夹具或文案变了）"; fi
if grep -qF 'TTL 72h' "$TMP/f19-legacy-green.log"; then ok "修复后：read 印有效 TTL（TTL 72h）"
else bad "修复后：read 没有印有效 TTL"; fi

# ---------------------------------------------------------------- F21
printf '\n=== F21 · 落后会话的 version --check 退出码 ===\n'
team "$RED_SKILL" "$TMP/f21-mark-red.log" mark-loaded --version 0.0.1
team "$RED_SKILL" "$TMP/f21-red.log" version --check
RED_V_RC="$TEAM_RC"
team "$GREEN_SKILL" "$TMP/f21-mark-green.log" mark-loaded --version 0.0.1
team "$GREEN_SKILL" "$TMP/f21-green.log" version --check
GREEN_V_RC="$TEAM_RC"
printf '[红] rc=%s  %s\n' "$RED_V_RC" "$(grep -sF '本会话是旧的' "$TMP/f21-red.log" | head -1 | sed 's/^[[:space:]]*//')"
printf '[绿] rc=%s  %s\n' "$GREEN_V_RC" "$(grep -sF '本会话是旧的' "$TMP/f21-green.log" | head -1 | sed 's/^[[:space:]]*//')"
if [ "$RED_V_RC" = "141" ]; then ok "修复前：退出码 141（SIGPIPE，head 提前退出 + pipefail）"
else bad "修复前：退出码是 $RED_V_RC（没复现 141）"; fi
if grep -qF '本会话是旧的' "$TMP/f21-red.log"; then ok "修复前：文案本身是对的（所以调用方会把 141 当崩溃）"
else bad "修复前：连「本会话是旧的」都没打印（夹具不对）"; fi
if [ "$GREEN_V_RC" = "0" ]; then ok "修复后：退出码 0（stale 不再是崩溃）"
else bad "修复后：退出码是 $GREEN_V_RC"; fi
if grep -qF '本会话是旧的' "$TMP/f21-green.log" && grep -qF '最新变更' "$TMP/f21-green.log"; then
  ok "修复后：既报「旧的」也仍然打印 CHANGELOG 摘要"
else bad "修复后：CHANGELOG 摘要被吃掉了"; fi
team "$GREEN_SKILL" "$TMP/f21-restore.log" mark-loaded >/dev/null 2>&1

# ---------------------------------------------------------------- F23
printf '\n=== F23 · team reload 的承诺 ===\n'
team "$RED_SKILL" "$TMP/f23-red.log" reload
team "$GREEN_SKILL" "$TMP/f23-green.log" reload
printf '[红] %s\n' "$(grep -sF 'watchdog' "$TMP/f23-red.log" | head -1 | sed 's/^[[:space:]]*//')"
printf '[绿] %s\n' "$(grep -sF 'marker' "$TMP/f23-green.log" | head -1 | sed 's/^[[:space:]]*//')"
if grep -qF 'watchdog' "$TMP/f23-red.log" && grep -qF '重启 PM 会话' "$TMP/f23-red.log"; then
  ok "修复前：promises the watchdog will restart the PM session when it sees the marker"
else bad "修复前：没有那句假承诺（文案变了？）"; fi
if ! grep -qF '重启 PM 会话' "$TMP/f23-green.log" && grep -qF '没有任何组件会因为 marker 重启会话' "$TMP/f23-green.log"; then
  ok "修复后：删掉承诺，只说 marker 的真实作用（含「没有任何组件重启会话」）"
else bad "修复后：承诺还在或没有说清实际行为"; fi
GREEN_READERS="$(grep -rl 'reload-requested' "$GREEN_SKILL/scripts" 2>/dev/null | grep -v 'cmd-update.sh' || true)"
if [ -z "$GREEN_READERS" ]; then ok "修复后：scripts/ 里除 cmd-update.sh 外确实没有组件读 marker"
else bad "还有组件读 marker：$GREEN_READERS"; fi
if grep -qF 'rmSync(marker, { force: true })' "$GREEN_SKILL/extension/team-notify.ts" 2>/dev/null; then
  ok "修复后：扩展侧只在 /reload 后清掉 marker（与文案一致）"
else bad "扩展侧不再清理 marker（文案就又不准了）"; fi
team "$GREEN_SKILL" "$TMP/f23-done.log" reload --done >/dev/null 2>&1

# ---------------------------------------------------------------- 变异自检：把实现改坏 → 守卫必须红
# 上面的红树是「整个修复前版本」；这里再单独把每一处修复改坏（其余都是修好的代码），
# 确认守卫断言真的是针对这几行实现，而不是靠整个版本差异。
printf '\n=== 变异自检（破坏实现 → 守卫断言必须变红） ===\n'
MUT="$TMP/mutant"
rm -rf "$MUT"; cp -r "$GREEN_SKILL" "$MUT"
mutate() { # <文件> <原文字面量> <替换>（整行子串替换，避免 sed 的转义地狱）
  local f="$1" old="$2" new="$3"
  awk -v old="$old" -v new="$new" '{ p=index($0, old); if (p>0) { $0 = substr($0,1,p-1) new substr($0,p+length(old)) }; print }' "$f" > "$f.mut" && mv "$f.mut" "$f"
}
mutate "$MUT/scripts/lib/cmd-status.sh" '"$(team_git_upstream_ahead "$wt")"' '"$ahead"'
mutate "$MUT/scripts/lib/common.sh" 'id="$(team_report_task_id "$glob")"' 'id="${base%%-*}"'
mutate "$MUT/scripts/lib/cmd-status.sh" 'id="$(team_report_task_id "$glob")"' 'id="${base%%-*}"'
mutate "$MUT/scripts/lib/cmd-meeting.sh" '[ "$ttl" -gt 0 ] 2>/dev/null || team_usage_die' '[ "$ttl" -gt 0 ] 2>/dev/null || team_warn'
f21_old="$(grep -F 'BEGIN{n=0} /^## /' "$MUT/scripts/lib/cmd-update.sh" | head -1)"
[ -n "$f21_old" ] && mutate "$MUT/scripts/lib/cmd-update.sh" "$f21_old" '    sed -n '\''/^## /,$p'\'' "$(team_skill_changelog)" | head -14 | sed '\''s/^/    /'\'''
mutate "$MUT/scripts/lib/cmd-update.sh" 'marker（.pi/team/state/reload-requested）仅用于记账' '若你有 watchdog：它看到 marker 后会重启 PM 会话（pi -c 保留历史。marker 记账'
MUTATIONS="$(diff -rq "$GREEN_SKILL/scripts" "$MUT/scripts" 2>/dev/null | wc -l | tr -d ' ')"
printf '已注入变异：%s 个文件不同（期望 4：cmd-status/cmd-meeting/cmd-update/common）\n' "$MUTATIONS"

# 边界：变异树必须只作用在夹具仓库上（第一次写这个包时就踩过：CLI 用调用者的 cwd，
# 结果把真实项目当成了受测对象）。每条命令都在夹具仓库里跑，并且先证明 paths 认的是夹具。
mut() { # <log> <env 名册或 -> <args...>：在夹具仓库里跑变异树
  local log="$1" agents="$2"; shift 2
  ( cd "$REPO" && [ "$agents" = "-" ] && bash "$MUT/scripts/team" "$@" || TEAM_AGENTS="$agents" bash "$MUT/scripts/team" "$@" ) >"$log" 2>&1
  MUT_RC=$?
}
MUT_ROOT="$( cd "$REPO" && bash "$MUT/scripts/team" paths 2>/dev/null | sed -n 's/.*"main_root": "\([^"]*\)".*/\1/p' )"
if [ "$MUT_ROOT" = "$REPO" ]; then ok "变异自检在夹具仓库里跑（main_root=$REPO）"
else bad "变异自检没有认到夹具仓库（main_root=$MUT_ROOT）——拒绝继续"; printf '\n'; exit 2; fi

# 守卫 1（F4）：改了 push 状态的口径 → digest 必须重新喊 push
mut "$TMP/mut-f4.log" f4 digest
if grep -qF '收尾：提交并 push' "$TMP/mut-f4.log"; then ok "变异 F4：把 upstream 量法改回保护分支 → 守卫（不许喊 push）变红"
else bad "变异 F4：改回旧口径后 digest 竟然仍然不喊 push（守卫没在防这条实现）"; fi
# 守卫 2（F6）：两个调用点（common/report 扫描 + cmd-status 待复验覆盖）都得改回「第一个 '-'」
mut "$TMP/mut-f6.log" - digest
if grep -qF '忽略的非任务报告：API-2-dev.md' "$TMP/mut-f6.log" && ! grep -qF 'review API-2' "$TMP/mut-f6.log"; then
  ok "变异 F6：改回首个 '-' 切 id → 守卫（API-2 必须在待复验）变红"
else bad "变异 F6：改回旧解析后 API-2 仍然在待复验（守卫没在防这条实现）"; fi
# 守卫 3（F19）：去掉「必须正数」这一半 → --ttl 0 必须又能被接受
mut "$TMP/mut-f19.log" - meeting open mut-ttl --with other --topic "mutant" --ttl 0 --yes
if [ "$MUT_RC" = "0" ]; then ok "变异 F19：去掉正数校验 → 守卫（--ttl 0 必须被拒）变红"
else bad "变异 F19：去掉校验后 --ttl 0 仍然被拒（守卫没在防这条实现）"; fi
# 守卫 4（F21）：改回 sed|head 管道 → 退出码必须又变 141
mut "$TMP/mut-f21-mark.log" - mark-loaded --version 0.0.1
mut "$TMP/mut-f21.log" - version --check
if [ "$MUT_RC" = "141" ]; then ok "变异 F21：改回 sed|head 管道 → 守卫（退出码必须 0）变红"
else bad "变异 F21：改回管道后退出码是 $MUT_RC（守卫没在防这条实现）"; fi
( cd "$REPO" && bash "$GREEN_SKILL/scripts/team" mark-loaded ) >/dev/null 2>&1
# 守卫 5（F23）：把假承诺放回去 → 守卫（不许出现「重启 PM 会话」）必须变红
mut "$TMP/mut-f23.log" - reload
if grep -qF '重启 PM 会话' "$TMP/mut-f23.log"; then ok "变异 F23：把假承诺放回文案 → 守卫（不许承诺重启）变红"
else bad "变异 F23：放回假承诺后守卫没抓到（守卫没在防这条文案）"; fi
mut "$TMP/mut-f23-done.log" - reload --done

# ---------------------------------------------------------------- 汇总
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '\033[32mflip-m6.4：五个 finding 的翻转全部复现（红 → 绿）\033[0m\n'
  exit 0
fi
printf '\033[31mflip-m6.4：有 %d 条翻转断言失败（见上）\033[0m\n' "$FAIL"
exit 1
