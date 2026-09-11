#!/usr/bin/env bash
# pi-team 冒烟自测：在 /tmp 的临时 git 仓库里端到端跑一遍全流程，绝不碰当前项目。
#
#   bash tests/smoke.sh [--keep]      # --keep 保留临时目录用于排查
#
# 覆盖：doctor 负例 → init → 模板渲染 → task/board → add-agent → dispatch(假 pi) →
#      say/notify/inbox/digest → worktree 内提交与报告 → review(PASS/FAIL 两条路径) →
#      merge(squash) → close → roster/ps/status → notify 扩展(Node 直跑，含去重) → teardown
set -uo pipefail

SKILL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAM="bash $SKILL_DIR/scripts/team"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

PASS=0; FAIL=0
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_file()  { [ -f "$1" ] && ok "$2" || bad "$2（缺 $1）"; }
assert_dir()   { [ -d "$1" ] && ok "$2" || bad "$2（缺目录 $1）"; }
assert_has()   { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 中找不到 [$2]）"; }
assert_not()   { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_eq()    { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }

TMP="$(mktemp -d /tmp/pi-team-smoke.XXXXXX)"
SESSION="pi-team-smoke-$$"
REPO="$TMP/repo"
FAKE="$TMP/fake-bin"
mkdir -p "$REPO" "$FAKE"

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  if [ "$KEEP" = "1" ]; then
    printf '\n保留临时目录：%s（tmux session 已清理）\n' "$TMP"
  else
    rm -rf "$TMP"
  fi
}
trap cleanup EXIT

command -v tmux >/dev/null 2>&1 && HAVE_TMUX=1 || HAVE_TMUX=0
# 能直接跑 .ts 的运行时：node（需启用类型剥离）/ bun / tsx
TS_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  TS_RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  TS_RUNNER="bun"
elif command -v tsx >/dev/null 2>&1; then
  TS_RUNNER="tsx"
fi
# 只要能跑 ESM 的运行时就能做 skill 加载验证
JS_RUNNER=""
command -v node >/dev/null 2>&1 && JS_RUNNER="node"
[ -z "$JS_RUNNER" ] && command -v bun >/dev/null 2>&1 && JS_RUNNER="bun"

# 假 pi：只记录参数，验证 dispatch 命令行是否正确（不真的起模型）
cat > "$FAKE/pi" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "$TMP/pi-args.log"
printf 'fake pi: %s\n' "\$*"
exit 0
EOF
chmod +x "$FAKE/pi"

printf 'pi-team smoke · skill=%s · tmp=%s\n' "$SKILL_DIR" "$TMP"

# ---------------------------------------------------------------- 0. 仓库
section "0 · 临时仓库"
cd "$REPO" || exit 1
git init -q -b main
git config user.email smoke@pi-team
git config user.name smoke
echo "# smoke" > README.md
git add -A && git commit -qm "chore: init"
assert_dir "$REPO/.git" "git 仓库就绪"

# ---------------------------------------------------------------- 0b. skill 合法性（pi 自己的解析器）
section "0b · skill 可被 pi 解析器加载"
if [ -n "$JS_RUNNER" ]; then
  if $JS_RUNNER "$SKILL_DIR/tests/skill-load.mjs" "$SKILL_DIR" >"$TMP/skill-load.log" 2>&1; then
    ok "$(head -1 "$TMP/skill-load.log")"
  else
    bad "skill-load 失败"; cat "$TMP/skill-load.log"
  fi
else
  printf '  (跳过：没有可用的 JS 运行时)\n'
fi

# ---------------------------------------------------------------- 1. doctor 负例
section "1 · doctor（未初始化应失败）"
if $TEAM doctor >"$TMP/doctor-pre.log" 2>&1; then bad "未初始化时 doctor 应失败"; else ok "未初始化时 doctor 正确报错"; fi
assert_has "$TMP/doctor-pre.log" "config" "doctor 报告了 config 项"

# ---------------------------------------------------------------- 2. init
section "2 · init"
$TEAM init --session "$SESSION" --agents "dev verify" --vcs local --gates "true" --docs docs/team >"$TMP/init.log" 2>&1 \
  && ok "init 退出码 0" || bad "init 失败（见 $TMP/init.log）"
assert_file "$REPO/.pi/team/config.sh" "写入配置"
assert_file "$REPO/docs/team/BOARD.md" "写入 BOARD"
assert_file "$REPO/docs/team/OWNERSHIP.md" "写入 OWNERSHIP"
assert_file "$REPO/docs/team/DECISIONS.md" "写入 DECISIONS"
assert_file "$REPO/docs/team/PROTOCOL.md" "写入 PROTOCOL"
assert_file "$REPO/docs/team/threads/README.md" "写入 threads/README"
assert_has "$REPO/AGENTS.md" "<!-- pi-team:begin -->" "AGENTS.md 注入协议段"
assert_has "$REPO/.gitignore" ".worktrees/" ".gitignore 忽略 worktree"
assert_has "$REPO/.gitignore" "docs/team/inbox/" ".gitignore 忽略收件箱"
assert_has "$REPO/.gitignore" ".pi/team/state/" ".gitignore 忽略运行时状态"
# 模板渲染不能有残留占位符
if grep -rqF '{{' "$REPO/docs/team" "$REPO/.pi/team/config.sh" "$REPO/AGENTS.md" 2>/dev/null; then
  bad "模板有未渲染的占位符 {{...}}"; grep -rnF '{{' "$REPO/docs/team" "$REPO/AGENTS.md" | head -3
else ok "模板全部渲染（无 {{ 残留）"; fi
# 幂等：再 init 一次不应重复追加协议段
$TEAM init --session "$SESSION" --agents "dev verify" --vcs local --gates "true" --docs docs/team >/dev/null 2>&1
assert_eq "AGENTS.md 协议段幂等（只出现一次）" "$(grep -cF '<!-- pi-team:begin -->' "$REPO/AGENTS.md")" "1"

git add -A && git commit -qm "chore: pi-team init" && ok "提交 init 产物（PM 的文档要入库）"

section "3 · doctor（初始化后）"
if $TEAM doctor >"$TMP/doctor.log" 2>&1; then ok "doctor 通过"; else bad "doctor 失败"; cat "$TMP/doctor.log"; fi
assert_has "$TMP/doctor.log" "notify 扩展" "doctor 检查了 notify 扩展"

# ---------------------------------------------------------------- 4. task / board
section "4 · task + board"
$TEAM task T1.1 --title "Smoke task" --agent dev --deps "-" >"$TMP/task.log" 2>&1 || bad "task 失败"
TASKFILE="$(ls "$REPO"/docs/team/tasks/T1.1-*.md 2>/dev/null | head -1)"
assert_file "$TASKFILE" "生成任务书"
assert_has "$TASKFILE" "agent:  dev" "任务书含 agent 字段"
assert_has "$TASKFILE" "true" "任务书写入门禁命令"
assert_eq "BOARD 建行（todo）" "$($TEAM board row T1.1 2>/dev/null | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$(NF-1)); print $(NF-1)}' || true)" "todo"

# ---------------------------------------------------------------- 5. add-agent
section "5 · add-agent"
$TEAM add-agent dev --no-install >"$TMP/add.log" 2>&1 || bad "add-agent 失败"
assert_dir "$REPO/.worktrees/dev" "创建 agent worktree"
assert_eq "worktree 分支" "$(git -C "$REPO/.worktrees/dev" rev-parse --abbrev-ref HEAD)" "agent/dev"
assert_file "$REPO/.worktrees/dev/README.md" "worktree 内容就绪"

# ---------------------------------------------------------------- 6. dispatch
section "6 · dispatch"
$TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print.log" 2>&1 || bad "dispatch --print 失败"
assert_has "$TMP/print.log" "--session-id $SESSION-dev" "命令含正确的 session-id"
assert_has "$TMP/print.log" "team-notify.ts" "命令显式加载 notify 扩展（worktree 不会自动发现）"
assert_has "$TMP/print.log" "agent:dev" "提示词声明了 agent 身份"
assert_has "$TMP/print.log" "不要在半途停下来征求确认" "提示词包含「不半途停」纪律"
assert_has "$TMP/print.log" "reports/T1.1-dev.md" "提示词指明报告路径"
assert_has "$TMP/print.log" "git commit" "提示词要求小步提交"

if [ "$HAVE_TMUX" = "1" ]; then
  # 让 worker 用假 pi 跑
  printf '\nTEAM_PI_BIN="%s"\n' "$FAKE/pi" >> "$REPO/.pi/team/config.sh"
  $TEAM dispatch dev T1.1 "$TASKFILE" >"$TMP/dispatch.log" 2>&1 || bad "dispatch 失败"
  sleep 2.5
  if tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qx dev; then ok "tmux 窗口 $SESSION:dev 已创建"; else bad "tmux 窗口未创建"; fi
  assert_file "$TMP/pi-args.log" "假 pi 被拉起（记录了参数）"
  assert_has "$TMP/pi-args.log" "-e" "pi 收到 -e（扩展）"
  assert_has "$TMP/pi-args.log" "--skill" "pi 收到 --skill（团队协议）"
  assert_eq "state 记录了任务" "$(cat "$REPO/.pi/team/state/dev.env" | grep -c '^task=T1.1$')" "1"
  $TEAM say dev "ping" >/dev/null 2>&1 && ok "say 能向 agent 窗口发消息" || bad "say 失败"
else
  printf '  (跳过 tmux 相关断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 7. 通知 / 收件箱 / digest
section "7 · notify / inbox / digest"
$TEAM notify dev "blocked: 缺 dependency X" >/dev/null 2>&1 && ok "notify 退出码 0" || bad "notify 失败"
assert_file "$REPO/docs/team/inbox/dev.md" "收件箱写入主工作树"
assert_has "$REPO/docs/team/inbox/dev.md" "blocked: 缺 dependency X" "收件箱内容正确"
$TEAM digest >"$TMP/digest.log" 2>&1 && ok "digest 退出码 0" || bad "digest 失败"
assert_has "$TMP/digest.log" "待处理通知" "digest 含待处理通知段"
assert_has "$TMP/digest.log" "blocked: 缺 dependency X" "digest 引用了新通知"
$TEAM inbox --ack >/dev/null 2>&1
$TEAM digest >"$TMP/digest2.log" 2>&1
assert_not "$TMP/digest2.log" "blocked: 缺 dependency X" "ack 后不再重复出现"

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
       > docs/team/reports/T1.1-dev.md \
  && git add -A && git commit -qm "feat(T1.1): add feature" ) >/dev/null 2>&1 \
  && ok "worktree 内提交成功" || bad "worktree 内提交失败"
assert_eq "分支有 1 个提交" "$(git -C "$REPO/.worktrees/dev" rev-list --count main..HEAD)" "1"

# ---------------------------------------------------------------- 10. review
section "10 · review（独立 worktree + 门禁）"
$TEAM review T1.1 >"$TMP/review.log" 2>&1 && ok "review 门禁 PASS 退出码 0" || bad "review 失败"
assert_file "$REPO/docs/team/reviews/T1.1.md" "写复验记录"
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **PASS**" "复验判定 PASS"
assert_has "$REPO/docs/team/reviews/T1.1.md" "feature.txt" "复验记录含变更文件"
assert_has "$REPO/docs/team/reviews/T1.1.md" "agent 报告原文" "复验记录摘录了 agent 报告（不需向主工作树拷文件）"
assert_has "$REPO/docs/team/reviews/T1.1.md" "状态: DONE" "摘录的是报告内容本体"
assert_dir "$REPO/.worktrees/review-T1.1" "复验用独立 worktree"
assert_eq "复验不会把主工作树弄脏（仅允许 docs/team、.pi/team 下的变动）" \
  "$(git -C "$REPO" status --porcelain | grep -vE '^(\?\?| ?M|M |MM|A | ?D) (\.pi/team/|docs/team/)' | grep -c . || true)" "0"

# 门禁失败路径
sed -i 's/^TEAM_GATES="true"/TEAM_GATES="false"/' "$REPO/.pi/team/config.sh"
if $TEAM review T1.1 >"$TMP/review-fail.log" 2>&1; then bad "门禁失败时 review 应返回非 0"; else ok "门禁失败时 review 返回非 0"; fi
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **FAIL**" "复验记录标记 FAIL"
sed -i 's/^TEAM_GATES="false"/TEAM_GATES="true"/' "$REPO/.pi/team/config.sh"
$TEAM review T1.1 >/dev/null 2>&1
assert_has "$REPO/docs/team/reviews/T1.1.md" "判定: **PASS**" "恢复门禁后复验 PASS"

# ---------------------------------------------------------------- 11. merge / close
section "11 · merge + close"
if $TEAM merge T1.1 >/dev/null 2>&1; then bad "merge 无 --yes 应被拒绝"; else ok "merge 无 --yes 正确拒绝（写操作授权）"; fi
# 特意在 agent worktree 里调用 merge：验证内部一律锚定主工作树（不是当前 cwd）
( cd "$REPO/.worktrees/dev" && $TEAM merge T1.1 --yes ) >"$TMP/merge.log" 2>&1 \
  && ok "merge --yes 成功（在 worktree 内调用也正确锚定主工作树）" || { bad "merge 失败"; cat "$TMP/merge.log"; }
assert_eq "main 上是 squash 提交" "$(git -C "$REPO" log --oneline -1 | grep -c 'T1.1: Smoke task')" "1"
assert_eq "merge 后 BOARD → done" "$($TEAM board row T1.1 | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$(NF-1)); print $(NF-1)}')" "done"
$TEAM close T1.1 >/dev/null 2>&1 && ok "close 退出码 0" || bad "close 失败"
[ "$HAVE_TMUX" = "1" ] && assert_eq "close 后窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx dev || true)" "0"

# ---------------------------------------------------------------- 12. 观察类命令
section "12 · roster / status / ps"
for c in roster status ps; do
  $TEAM "$c" >"$TMP/$c.log" 2>&1 && ok "$c 退出码 0" || bad "$c 失败"
  [ -s "$TMP/$c.log" ] && ok "$c 有输出" || bad "$c 无输出"
done

# ---------------------------------------------------------------- 13. notify 扩展（Node 直跑）
section "13 · notify 扩展（去重 + 只在 worktree 触发）"
if [ -n "$TS_RUNNER" ]; then
  cat > "$TMP/ext-test.mjs" <<'EOF'
import { readFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
const [, , ext, root, wt] = process.argv
delete process.env.TMUX_PANE
delete process.env.TMUX
const mod = await import(ext)
let handler = null
mod.default({ on: (name, fn) => { if (name === 'agent_settled') handler = fn } })
if (!handler) { console.error('FAIL: 没有注册 agent_settled'); process.exit(3) }
const inbox = join(root, 'docs/team/inbox/dev.md')
rmSync(inbox, { force: true })
const ctx = {
  cwd: wt,
  sessionManager: { getEntries: () => [{ message: { role: 'assistant', content: [{ text: 'ALLDONE feature implemented' }] } }] },
}
await handler({}, ctx)
await handler({}, ctx)              // 去重窗口内，第二次必须被抑制
let lines = readFileSync(inbox, 'utf8').trim().split('\n')
if (lines.length !== 1) { console.error(`FAIL: 期望 1 行（去重），实际 ${lines.length}`); process.exit(4) }
if (!lines[0].includes('ALLDONE feature implemented')) { console.error('FAIL: 没有带上 agent 末条消息'); process.exit(5) }
if (!lines[0].includes('agent:dev')) { console.error('FAIL: agent 名推断错误'); process.exit(6) }
const before = readFileSync(inbox, 'utf8')
await handler({}, { cwd: root, sessionManager: { getEntries: () => [] } })   // 主工作树不该触发
if (readFileSync(inbox, 'utf8') !== before) { console.error('FAIL: 非 worktree 路径也写了收件箱'); process.exit(7) }
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

# ---------------------------------------------------------------- 14. teardown
section "14 · teardown"
$TEAM teardown --agent dev --purge >"$TMP/teardown.log" 2>&1 && ok "teardown 退出码 0" || bad "teardown 失败"
[ -d "$REPO/.worktrees/dev" ] && bad "worktree 应被 --purge 删除" || ok "worktree 已删除"
assert_not "$REPO/.pi/team/state/dev.env" "task=T1.1" "state 已清理"

# ---------------------------------------------------------------- 15. 结束
section "15 · 完成"
printf '   （全流程已在 0–14 节覆盖）\n'
printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32msmoke 全绿\033[0m\n'; exit 0; }
printf '\033[31msmoke 有失败项（--keep 保留现场）\033[0m\n'
exit 1
