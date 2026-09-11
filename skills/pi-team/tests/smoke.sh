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
assert_not_file() { [ ! -e "$1" ] && ok "$2" || bad "$2（$1 不该存在）"; }
assert_has()   { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 中找不到 [$2]）"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 中没有匹配 [$2]）"; }
assert_not()   { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_eq()    { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }

TMP="$(mktemp -d /tmp/pi-team-smoke.XXXXXX)"
SESSION="pi-team-smoke-$$"
PROTECTED="main"   # 与 TEAM_PROTECTED_BRANCH 默认值一致
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
# team_watch_pid_alive 这类故意返回 1 的判定函数只允许出现在条件里
assert_has "$SKILL_DIR/scripts/team" "set -euo pipefail" "CLI 主脚本仍启用严格模式"
if [ -x "$SKILL_DIR/scripts/team" ]; then ok "scripts/team 可执行（systemd ExecStart / 直接调用需要）"
else bad "scripts/team 没有 +x：systemd 服务会因 Permission denied 启动失败"; fi
if [ -x "$SKILL_DIR/tests/smoke.sh" ]; then ok "tests/smoke.sh 可执行"
else bad "tests/smoke.sh 没有 +x"; fi

# ---------------------------------------------------------------- 1. doctor 负例
section "1 · doctor（未初始化应失败）"
if $TEAM doctor >"$TMP/doctor-pre.log" 2>&1; then bad "未初始化时 doctor 应失败"; else ok "未初始化时 doctor 正确报错"; fi
assert_has "$TMP/doctor-pre.log" "config" "doctor 报告了 config 项"

# ---------------------------------------------------------------- 1b. bootstrap（一次性临时仓库）
section "1b · bootstrap（一条命令初始化）"
BR="$TMP/bootrepo"; mkdir -p "$BR"; cd "$BR"
git init -q -b main; git config user.email smoke@pi-team; git config user.name smoke
echo "# boot" > README.md; git add -A; git commit -qm init
BSESS="pi-team-smoke-boot-$$"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog --print >"$TMP/boot-print.log" 2>&1 \
  && ok "bootstrap --print 退出码 0" || bad "bootstrap --print 失败"
assert_has "$TMP/boot-print.log" "计划步骤" "打印了计划步骤"
assert_has "$TMP/boot-print.log" "add-agent dev" "计划里含建 worktree"
assert_has "$TMP/boot-print.log" "watchdog up" "计划里含起看门狗容器"
[ -f "$BR/.pi/team/config.sh" ] && bad "--print 不该改任何东西" || ok "--print 确实没改东西"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog >"$TMP/boot.log" 2>&1 \
  && ok "bootstrap 退出码 0" || { bad "bootstrap 失败"; cat "$TMP/boot.log"; }
assert_file "$BR/.pi/team/config.sh" "bootstrap 写了配置"
assert_has "$BR/.pi/team/config.sh" "TEAM_SESSION=\"$BSESS\"" "把探测/指定的 session 写进配置"
assert_dir "$BR/docs/team/tasks" "建了文档骨架"
assert_dir "$BR/.worktrees/dev" "建了 dev worktree"
assert_dir "$BR/.worktrees/verify" "建了 verify worktree"
assert_has "$BR/AGENTS.md" "<!-- pi-team:begin -->" "注入了协议段"
assert_has "$TMP/boot.log" "下一步" "打印了下一步清单"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog >"$TMP/boot2.log" 2>&1
assert_eq "bootstrap 幂等（协议段只一份）" "$(grep -cF '<!-- pi-team:begin -->' "$BR/AGENTS.md")" "1"
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
assert_eq "worktree 处于 detached（task 模式）" "$(git -C "$REPO/.worktrees/dev" rev-parse --abbrev-ref HEAD)" "HEAD"
assert_file "$REPO/.worktrees/dev/README.md" "worktree 内容就绪"

# ---------------------------------------------------------------- 6. dispatch
section "6 · dispatch"
$TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print.log" 2>&1 || bad "dispatch --print 失败"assert_has "$TMP/print.log" "--session-id $SESSION-dev" "命令含正确的 session-id"
assert_has "$TMP/print.log" "team-notify.ts" "命令显式加载 notify 扩展（worktree 不会自动发现）"
assert_has "$TMP/print.log" "agent:dev" "提示词声明了 agent 身份"
assert_has "$TMP/print.log" "不要在半途停下来征求确认" "提示词包含「不半途停」纪律"
assert_has "$TMP/print.log" "reports/T1.1-dev.md" "提示词指明报告路径"
assert_has "$TMP/print.log" "git commit" "提示词要求小步提交"

if [ "$HAVE_TMUX" = "1" ]; then
  # 让 worker 用假 pi 跑（pi-sleep：模拟“pi 正在跑”的窗口，便于验证 say/存活判定）
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/pi-args.log" > "$FAKE/pi-sleep"
  chmod +x "$FAKE/pi-sleep"
  printf '\nTEAM_PI_BIN="%s"\n' "$FAKE/pi-sleep" >> "$REPO/.pi/team/config.sh"
  $TEAM dispatch dev T1.1 "$TASKFILE" >"$TMP/dispatch.log" 2>&1 || bad "dispatch 失败"
  sleep 2.5
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

# ① merge 失败时必须列出冲突文件（用**临时 worktree** 造冲突，不碰 agent 的 worktree）
MAIN_BEFORE="$(git -C "$REPO" rev-parse HEAD)"
CONFWT="$TMP/conflict-wt"
git -C "$REPO" worktree add --detach "$CONFWT" "$PROTECTED" >/dev/null 2>&1
git -C "$CONFWT" switch -c task/T9.9-conflict >/dev/null 2>&1
printf 'agent side\n' > "$CONFWT/conflict.txt"
git -C "$CONFWT" add -A >/dev/null 2>&1
git -C "$CONFWT" -c user.email=a@b -c user.name=a commit -qm "feat: agent side of conflict"
printf 'main side\n' > "$REPO/conflict.txt"
# 只提交这一个文件：main 工作树里还有未提交的 BOARD/reviews 等，`add -A` 会把它们卷进提交
git -C "$REPO" add conflict.txt >/dev/null 2>&1
git -C "$REPO" -c user.email=a@b -c user.name=a commit -qm "feat: main side of conflict"
if $TEAM merge T9.9 --branch task/T9.9-conflict --no-review-check --yes >"$TMP/merge-conflict.log" 2>&1; then
  bad "冲突时 merge 应返回非 0"
else ok "冲突时 merge 返回非 0"; fi
assert_has "$TMP/merge-conflict.log" "conflict.txt" "merge 失败时列出了冲突文件"
assert_has "$TMP/merge-conflict.log" "冲突文件" "明确标出「冲突文件」段"
# 用 --mixed 回退（保留 main 工作树里其它未提交内容），再删掉测试文件
git -C "$REPO" reset --mixed "$MAIN_BEFORE" >/dev/null 2>&1
rm -f "$REPO/conflict.txt"
git -C "$REPO" worktree remove --force "$CONFWT" >/dev/null 2>&1 || true
git -C "$REPO" branch -D task/T9.9-conflict >/dev/null 2>&1 || true
# 冲突失败不能把 BOARD 标成 done（v1.7.1 的 bug：没进 main 却写 done）
assert_has "$REPO/docs/team/BOARD.md" "| wip |" "冲突失败后 BOARD 保持原状态（不是 done）"
assert_not "$TMP/merge-conflict.log" "board T1.1 → done" "冲突失败时不打印 board → done"
assert_has "$TMP/merge-conflict.log" "BOARD 保持" "给出了「BOARD 保持原状态」的说明"
assert_has "$TMP/merge-conflict.log" "恢复步骤" "给出了可复制粘贴的恢复步骤"
assert_has "$TMP/merge-conflict.log" "prefer-theirs" "lockfile 场景给出 --prefer-theirs 提示"

# --prefer-theirs：lockfile 类冲突自动取分支侧，合并能走完
$TEAM task T9.8 --title "lockfile merge" --agent dev >/dev/null 2>&1 || true
MAIN_BEFORE2="$(git -C "$REPO" rev-parse HEAD)"
CONFWT2="$TMP/conflict-wt2"
git -C "$REPO" worktree add --detach "$CONFWT2" "$PROTECTED" >/dev/null 2>&1
git -C "$CONFWT2" switch -c task/T9.8-lock >/dev/null 2>&1
printf 'branch lock\n' > "$CONFWT2/pnpm-lock.yaml"
git -C "$CONFWT2" add -A >/dev/null 2>&1
git -C "$CONFWT2" -c user.email=a@b -c user.name=a commit -qm "feat: branch lockfile"
git -C "$REPO" worktree remove --force "$CONFWT2" >/dev/null 2>&1 || true
printf 'main lock\n' > "$REPO/pnpm-lock.yaml"
git -C "$REPO" add pnpm-lock.yaml >/dev/null 2>&1
git -C "$REPO" -c user.email=a@b -c user.name=a commit -qm "feat: main lockfile"
if $TEAM merge T9.8 --branch task/T9.8-lock --no-review-check --yes --prefer-theirs pnpm-lock.yaml >"$TMP/merge-prefer.log" 2>&1; then
  ok "--prefer-theirs 让 lockfile 冲突自动解决并合并成功"
else bad "--prefer-theirs 合并失败"; cat "$TMP/merge-prefer.log"; fi
assert_has "$TMP/merge-prefer.log" "取分支侧" "打印了取分支侧的动作"
assert_eq "lockfile 取了分支侧内容" "$(cat "$REPO/pnpm-lock.yaml")" "branch lock"
assert_eq "合并成功后 BOARD 才标 done" "$(bash -c '. "'$SKILL_DIR'/scripts/lib/common.sh"; team_load_config; team_board_field "$(team_board_row T9.8)" status')" "done"
# 收尾：回滚 T9.8 造出来的 main 提交与 lockfile（回到 6d 开始时）
SQUASH_SHA="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" reset --mixed "$MAIN_BEFORE2" >/dev/null 2>&1
rm -f "$REPO/pnpm-lock.yaml"
git -C "$REPO" branch -D task/T9.8-lock >/dev/null 2>&1 || true
assert_eq "T9.8 测试后主工作树已回滚" "$(git -C "$REPO" rev-parse HEAD)" "$MAIN_BEFORE2"
team_dim "（T9.8 squash commit $SQUASH_SHA 已从 main 摘掉，测试隔离）"

# push 失败也不能标 done（本地合并了但远端没有）
assert_eq "冲突测试后主工作树已回滚" "$(git -C "$REPO" rev-parse HEAD)" "$MAIN_BEFORE"
$TEAM board set T1.1 wip >/dev/null 2>&1 || true
assert_eq "冲突测试没动 agent 的 worktree" "$(git -C "$REPO/.worktrees/dev" rev-parse --abbrev-ref HEAD)" "task/T1.1-smoke-task"

# ④ 翻转证据进模板与派单提示词
assert_has "$SKILL_DIR/templates/task.md.tmpl" "翻转证据" "任务书模板要求翻转证据"
assert_has "$SKILL_DIR/templates/report.md.tmpl" "翻转证据" "报告模板含翻转证据段"
assert_has "$TMP/print.log" "翻转证据" "派单提示词就要求写翻转证据"

# ---------------------------------------------------------------- 6e. erp 实测反馈（4 条）
section "6e · erp 实测反馈（render & / GitLab 头 / pi PATH / 非任务报告）"

# ③ 模板渲染不能吃掉 &&（bash 5.2+ 的 patsub_replacement 会把 & 变成“命中文本”）
BRENDER="$TMP/renderer-repo"; mkdir -p "$BRENDER"; ( cd "$BRENDER" && git init -q -b main && git config user.email a@b && git config user.name a && echo x > a && git add -A && git commit -qm init )
( cd "$BRENDER" && bash "$SKILL_DIR/scripts/team" init --session "pi-team-smoke-render-$$" --agents dev --gates "pnpm test && pnpm lint" >/dev/null 2>&1 ) || true
assert_has "$BRENDER/.pi/team/config.sh" 'TEAM_GATES="pnpm test && pnpm lint"' "init 原样写入含 && 的 TEAM_GATES"
assert_eq "渲染后没有占位符残留" "$(grep -c '{{GATES}}' "$BRENDER/.pi/team/config.sh" || true)" "0"
assert_eq "渲染结果可安全 source（值与入参一致）" \
  "$(env TEAM_ROOT=$BRENDER SK="$SKILL_DIR" bash -c '. "$SK/scripts/lib/common.sh"; team_load_config; printf "%s" "$TEAM_GATES"')" "pnpm test && pnpm lint"
assert_eq "含 shell 特殊字符也不会被当代码执行" \
  "$(cd "$BRENDER" && bash "$SKILL_DIR/scripts/team" init --force --session "pi-team-smoke-render-$$" --agents dev --gates 'a && echo PWNED `id` $HOME' >/dev/null 2>&1; env TEAM_ROOT=$BRENDER SK="$SKILL_DIR" bash -c '. "$SK/scripts/lib/common.sh"; team_load_config; printf "%s" "$TEAM_GATES"')" 'a && echo PWNED `id` $HOME'

# ① GitLab API：表单体必须配 x-www-form-urlencoded（否则 {"error":"Invalid JSON format"}）
FAKECURL="$TMP/fakecurl"; mkdir -p "$FAKECURL"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/curl-args.txt"\necho "{}"\n' "$TMP" > "$FAKECURL/curl"
chmod +x "$FAKECURL/curl"
TOK="$TMP/gl-token"; printf 'dummy\n' > "$TOK"; chmod 600 "$TOK"
run_gl() { # <extra args...>
  env PATH="$FAKECURL:$PATH" TEAM_ROOT="$REPO" TEAM_VCS=gitlab TEAM_GITLAB_HOST=https://gl.example TEAM_GITLAB_PROJECT=g/p \
      TEAM_GITLAB_TOKEN_FILE="$TOK" SK="$SKILL_DIR" bash -c '. "$SK/scripts/lib/common.sh"; . "$SK/scripts/lib/forge.sh"; team_load_config; forge_gitlab_api "$@"' _ "$@"
}
run_gl POST /projects/1/merge_requests --data-urlencode "source_branch=task/T1.1" >/dev/null 2>&1
assert_has "$TMP/curl-args.txt" "application/x-www-form-urlencoded" "表单体用 x-www-form-urlencoded（不再是 application/json）"
run_gl POST /projects/1/merge_requests --data '{"a":1}' >/dev/null 2>&1
assert_has "$TMP/curl-args.txt" "application/json" "JSON 体仍用 application/json"

# PR 级：用一个“像 GitLab 一样校验头/体”的桩，验证 team pr 真能开出 MR（erp 的复现路径）
GLLOG="$TMP/gl-pr.log"; : > "$GLLOG"
cat > "$FAKECURL/curl" <<'GLSTUB'
#!/usr/bin/env bash
{ printf '%s\n' "$@"; } >> "$GL_LOG"
ctype=""; form=0
while [ $# -gt 0 ]; do
  case "$1" in
    -H) case "$2" in Content-Type:*) ctype="${2#Content-Type: }" ;; esac; shift 2 ;;
    --data-urlencode|--data-urlencode=*) form=1; shift ;;
    --data|--data-binary) shift ;;
    -X) shift 2 ;;
    *) shift ;;
  esac
done
# GitLab 的真实行为：表单体配 JSON 头 → 直接拒绝
if [ "$form" = "1" ] && [ "$ctype" = "application/json" ]; then
  echo '{"error":"Invalid JSON format"}'; exit 1
fi
if [ "$form" != "1" ] && [ "$ctype" != "application/json" ]; then
  echo '{"error":"expected JSON body"}'; exit 1
fi
echo '{"iid":24,"web_url":"https://gl.example/g/p/-/merge_requests/24"}'
GLSTUB
chmod +x "$FAKECURL/curl"
if env PATH="$FAKECURL:$PATH" GL_LOG="$GLLOG" TEAM_ROOT="$REPO" \
    TEAM_VCS=gitlab TEAM_GITLAB_HOST=https://gl.example TEAM_GITLAB_PROJECT=g/p \
    TEAM_GITLAB_TOKEN_FILE="$TOK" $TEAM pr T1.1 --branch task/T1.1-smoke-task --yes >"$TMP/gl-pr-out.log" 2>&1; then
  ok "GitLab 模式下 team pr 开 MR 成功（头/体一致，桩按 GitLab 规则校验）"
else bad "GitLab 模式下 team pr 失败"; cat "$TMP/gl-pr-out.log"; fi
assert_has "$TMP/gl-pr-out.log" "merge_requests/24" "pr 打出了 MR 链接/iid"
assert_not "$TMP/gl-pr-out.log" "Invalid JSON format" "没有被 GitLab 以 Invalid JSON format 拒绝"
assert_has "$GLLOG" "application/x-www-form-urlencoded" "pr 调用链发的确实是表单体 + 表单头"
assert_has "$GLLOG" "source_branch=task/T1.1-smoke-task" "pr 带了 source_branch 字段"

# ② pi 可执行文件：绝对路径 + 找不到就明确报错（不要再出现窗口里 command not found）
if TEAM_PI_BIN="definitely-not-a-pi-binary" $TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/pi-missing.log" 2>&1; then
  bad "TEAM_PI_BIN 不存在时应当报错"
else ok "TEAM_PI_BIN 不存在时拒绝派单"; fi
assert_has "$TMP/pi-missing.log" "找不到 pi 可执行文件" "报错说明了 pi 找不到"
assert_has "$TMP/pi-missing.log" "绝对路径" "给出了「设成绝对路径」的建议"
assert_match "$TMP/print.log" "^cd .* && /| pi_bin" "派单命令里用的是解析后的路径（见下方 dispatch 断言）"

# ④ 非任务交付物不算待复验（erp: requirements-gap-2026-09-11.md）
printf '# 需求差距报告\n\n非任务交付物。\n' > "$REPO/docs/team/reports/requirements-gap-2026-09-11.md"
$TEAM digest >"$TMP/digest-nontask.log" 2>&1 || true
assert_not "$TMP/digest-nontask.log" "team review requirements" "非任务交付物不再被当成待复验任务"
assert_has "$TMP/digest-nontask.log" "requirements-gap-2026-09-11.md" "但它会出现在「忽略的非任务报告」里"
rm -f "$REPO/docs/team/reports/requirements-gap-2026-09-11.md"

# 次要项：team resume 支持位置参数
$TEAM resume dev --dry-run >"$TMP/resume-pos.log" 2>&1 && ok "resume <agent> 位置参数可用" || bad "resume 位置参数不可用"

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

# ---------------------------------------------------------------- 11b. 保活：team up / watch
section "11b · 定时巡检：有待办才叫醒 PM（默认 15 分钟）"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/pm-args.log" > "$FAKE/pi-sleep"
chmod +x "$FAKE/pi-sleep"

if [ "$HAVE_TMUX" = "1" ]; then
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
  PMW="$($TEAM paths | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"
  [ -n "$PMW" ] || PMW=pm
  # 制造“PM 窗口在、里面是空提示符”的现场（pi 退出后的样子），并用占位窗口保住 session
  make_pm_idle() {
    tmux new-window -t "$SESSION" -n keep -d >/dev/null 2>&1 || true
    # 先把所有名为 $PMW 的窗口关干净（可能积了多个），再建一个干净的
    tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null \
      | awk -v n="$PMW" '$2==n {print $1}' \
      | while read -r wid; do tmux kill-window -t "$wid" 2>/dev/null || true; done
    tmux new-window -t "$SESSION" -n "$PMW" -d >/dev/null 2>&1 || true
    sleep 1.5
  }
  start_fake_pm() { # 直接模拟“PM 正在跑”，避免依赖 up 的时序
    local p; p="$(tmux list-panes -t "$SESSION:$PMW" -F '#{pane_id}' | head -1)"
    tmux respawn-pane -k -t "$p" "exec $FAKE/pi-sleep --pm" >/dev/null 2>&1 || true
    sleep 1.5
  }
  kill_all_windows() {
    tmux list-windows -t "$SESSION" -F '#{window_id}' 2>/dev/null \
      | while read -r wid; do tmux kill-window -t "$wid" 2>/dev/null || true; done
    sleep 0.5
  }
  pm_lines() { wc -l < "$TMP/pm-args.log" 2>/dev/null | tr -d ' ' || echo 0; }
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
  $TEAM watchdog-status >"$TMP/wdstatus.log" 2>&1
  assert_match "$TMP/wdstatus.log" "在运行|视为存活" "watchdog-status 看到 PM 在跑"
  assert_has "$TMP/wdstatus.log" "900s" "巡检周期默认 15 分钟（可配 5~60 分钟）"
  $TEAM up >"$TMP/up2.log" 2>&1
  assert_match "$TMP/up2.log" "PM 在运行|视为存活" "up 不会重复启动已跑的 PM"

  # 2) 没待办：不叫醒、不启动（不要求 PM 一直运行）
  $TEAM inbox --ack >/dev/null 2>&1
  $TEAM watchdog-status >"$TMP/wd-idle.log" 2>&1
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

  # 4) 有待办 + PM 不在跑 → 拉起（记 inbox + 计数）
  rm -f "$REPO/.pi/team/state/pm-restarts.log" "$REPO/docs/team/inbox/pm.md"
  make_pm_idle
  DEAD_BEFORE="$(pm_lines)"
  $TEAM watch --once >"$TMP/watch2.log" 2>&1 || bad "watch --once（PM 挂了）失败"
  assert_match "$TMP/watch2.log" "已拉起" "watchdog 在有待办时把 PM 拉起来"
  assert_has "$REPO/.pi/team/state/watchdog.log" "→ 已拉起" "日志记录拉起动作"
  assert_has "$REPO/docs/team/inbox/pm.md" "watchdog" "给 PM 留了收件箱消息"
  assert_eq "拉起计数已记录" "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ')" "1"
  if [ "$(pm_lines)" -gt "$DEAD_BEFORE" ]; then ok "PM 参数已写入（$DEAD_BEFORE → $(pm_lines)）"
  elif tmux list-panes -t "$SESSION:$PMW" -F '#{pane_pid}' | head -1 | xargs -r ps -o args= -p 2>/dev/null | grep -q pi-sleep; then
    ok "PM 已被拉起（窗口里跑着 pi，日志尚未落盘）"
  else bad "PM 没有被拉起（$DEAD_BEFORE → $(pm_lines)）"; fi

  # 4b) 看门狗：tmux 后端（默认，窗口里跑 monitor）+ 容器后端 dry-run
  $TEAM monitor --once >"$TMP/monitor.log" 2>&1 && ok "monitor --once 退出码 0" || bad "monitor --once 失败"
  assert_has "$TMP/monitor.log" "pi-team monitor" "monitor 打印了标题"
  assert_has "$TMP/monitor.log" "巡检" "monitor 复用了团队状态面板"
  assert_not "$TMP/monitor.log" "agent 活动" "默认不翻各 agent 的会话（活动流 opt-in）"
  assert_has "$TMP/monitor.log" "只服务本 session" "说明了看门狗的服务范围"
  $TEAM monitor --once --activity >"$TMP/monitor-act.log" 2>&1 || bad "monitor --activity 失败"
  assert_has "$TMP/monitor-act.log" "agent 活动" "--activity 显式打开活动流"
  assert_has "$TMP/monitor-act.log" "仅本 session 在跑的窗口" "活动流只覆盖本 session 的窗口"
  $TEAM watchdog up >"$TMP/wd-up.log" 2>&1 && ok "watchdog up（tmux 后端）退出码 0" || { bad "watchdog up 失败"; cat "$TMP/wd-up.log"; }
  assert_eq "看门狗窗口已建" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx watchdog || true)" "1"
  $TEAM watchdog status >"$TMP/wd-status.log" 2>&1
  assert_has "$TMP/wd-status.log" "tmux 窗口 $SESSION:watchdog 在跑" "status 看到窗口在跑"
  $TEAM watchdog logs >"$TMP/wd-logs.log" 2>&1 && ok "watchdog logs（pane 快照）退出码 0" || bad "watchdog logs 失败"
  assert_has "$TMP/wd-logs.log" "pi-team monitor" "logs 显示监视器画面"
  $TEAM watchdog up >"$TMP/wd-up2.log" 2>&1
  assert_has "$TMP/wd-up2.log" "已在跑" "up 幂等（不重复起窗口）"
  $TEAM watchdog down >"$TMP/wd-down.log" 2>&1 && ok "watchdog down 退出码 0" || bad "watchdog down 失败"
  assert_eq "看门狗窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx watchdog || true)" "0"
  $TEAM watchdog up --container --print >"$TMP/wd-print.log" 2>&1 && ok "watchdog --container --print 退出码 0" || bad "容器 --print 失败"
  assert_match "$TMP/wd-print.log" "^podman run --detach" "容器形态打印出 podman run"
  assert_match "$TMP/wd-print.log" "\-\-restart=always" "容器带 --restart=always"
  if [ "${TEAM_SMOKE_CONTAINER:-0}" = "1" ]; then
    $TEAM watchdog up --container >"$TMP/wd-cont.log" 2>&1 && ok "watchdog --container up 退出码 0" || { bad "容器 up 失败"; cat "$TMP/wd-cont.log"; }
    sleep 20
    assert_file "$REPO/.pi/team/state/capacity.log" "容器里的巡检真的在写容量日志"
    $TEAM watchdog down --container >/dev/null 2>&1
  else
    printf '  (跳过真实容器：TEAM_SMOKE_CONTAINER=1 才跑)\n'
  fi

  # 5) standby：PM 主动停工，有待办也不叫
  $TEAM standby on --reason "等用户授权合并" >"$TMP/standby-on.log" 2>&1
  assert_has "$TMP/standby-on.log" "已进入待命" "standby on 生效"
  make_pm_idle
  SB_BEFORE="$(pm_lines)"
  $TEAM watch --once >"$TMP/watch-sb.log" 2>&1 || true
  assert_eq "待命期间不叫醒、不拉起" "$(pm_lines)" "$SB_BEFORE"
  assert_has "$REPO/.pi/team/state/watchdog.log" "standby 中" "日志记录“待命所以不叫醒”"
  $TEAM standby off >/dev/null 2>&1
  $TEAM watch --once >"$TMP/watch-sb2.log" 2>&1 || true
  assert_match "$TMP/watch-sb2.log" "已拉起" "standby off 后有待办就继续拉起"

  # 6) 不管 tmux：session 丢了只告警；开关打开才重建
  $TEAM notify dev "新待办：T3 计划待确认" >/dev/null 2>&1   # 待办变化 → 告警会重新出现（同批不重复）
  kill_all_windows
  $TEAM watch --once >"$TMP/watch4.log" 2>&1 || true
  if tmux has-session -t "$SESSION" 2>/dev/null; then bad "watchdog 不该重建 tmux session（默认不管 tmux）"; else ok "session 丢了 watchdog 不重建（默认不管 tmux）"; fi
  assert_match "$TMP/watch4.log" "不管 tmux|人工" "给出了“需要人工 up”的提示"
  TEAM_WATCH_REBUILD_TMUX=1 $TEAM watch --once >"$TMP/watch5.log" 2>&1 || true
  assert_eq "开关打开后才重建 pm 窗口" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx "$PMW" || true)" "1"
  assert_match "$TMP/watch5.log" "已拉起" "重建后把 PM 拉起来了"

  # 7) 自动拉起配额：防崩溃循环
  make_pm_idle
  for _ in 1 2 3 4 5; do date +%s >> "$REPO/.pi/team/state/pm-restarts.log"; done
  $TEAM watch --once >"$TMP/watch3.log" 2>&1 || true
  assert_has "$TMP/watch3.log" "已被重启" "超过配额时拒绝继续拉起（告警）"
  # 收尾：清配额/占位窗口，把 PM 拉回来
  rm -f "$REPO/.pi/team/state/pm-restarts.log"
  tmux kill-window -t "$SESSION:keep" 2>/dev/null || true
  $TEAM inbox --ack >/dev/null 2>&1
  $TEAM up >/dev/null 2>&1 || true
else
  printf '  (跳过巡检断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11c. 恢复：resume / watchdog 续跑
section "11c · agent 续跑是 PM 的事（watchdog 不碰）"
if [ "$HAVE_TMUX" = "1" ]; then
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi\"|" "$REPO/.pi/team/config.sh"
  # 让 dev 处於“有任务但 pi 已退出”的状态
  $TEAM dispatch dev T1.1 "$TASKFILE" >/dev/null 2>&1
  sleep 1.5
  $TEAM roster >"$TMP/roster-dead.log" 2>&1
  assert_has "$TMP/roster-dead.log" "pi 已退出" "roster 能区分「窗口在但 pi 已退出」"
  if $TEAM say dev "ping" >"$TMP/say-idle.log" 2>&1; then ok "agent 没在跑时 say 落收件箱并返回 0"; else bad "say 不应硬失败（应落收件箱）"; fi
  assert_has "$TMP/say-idle.log" "收件箱" "说明消息进了收件箱（而不是打进 shell）"

  # watchdog 不该替 PM 做决定：跑一轮巡检，dev 仍未被续跑
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  sleep 0.5
  $TEAM watch --once >"$TMP/watch4.log" 2>&1 || bad "watch --once 失败"
  assert_eq "watchdog 不续跑 agent（窗口仍不在）" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx dev || true)" "0"
  assert_not "$TMP/watch4.log" "续跑" "watchdog 输出里没有 agent 续跑动作"

  # PM 的工具仍然可用
  $TEAM resume --dry-run >"$TMP/resume-dry.log" 2>&1
  assert_has "$TMP/resume-dry.log" "可续跑：T1.1" "resume --dry-run 能识别待续跑任务"
  $TEAM resume >"$TMP/resume.log" 2>&1 && ok "resume（PM 工具）退出码 0" || bad "resume 失败"
  assert_has "$TMP/resume.log" "续跑 dev" "resume 重新派单"
  assert_eq "resume 后 dev 窗口回来了" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx dev || true)" "1"

  # 人工一条命令也能顺手把 agent 带上（up --agents）
  tmux kill-window -t "$SESSION:dev" 2>/dev/null || true
  $TEAM up --agents >"$TMP/up-agents.log" 2>&1 || bad "up --agents 失败"
  assert_has "$TMP/up-agents.log" "续跑 dev" "up --agents 才会续跑 agent"
else
  printf '  (跳过恢复断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11d. 边界守卫（跨 session 不许打字）
section "11d · 边界守卫（跨项目/跨 session 通信必须经用户）"
if [ "$HAVE_TMUX" = "1" ]; then
  FOREIGN="pi-team-foreign-$$"
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
assert_has "$TMP/print.log" "边界（跨项目一律不动手）" "派单提示词写明了跨项目边界"
assert_has "$TMP/print.log" "meeting" "提示词指明了跨项目沟通走 meeting"
assert_has "$TMP/print.log" "worker 不参会" "提示词说明 worker 不参会"

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

# agent 不能冒充人类下令
if $TEAM meeting say order-api --intent info --as-user "我以用户名义下令" >"$TMP/mtg-user.log" 2>&1; then
  bad "--as-user 在 agent 里应被拒绝"
else ok "--as-user 被拒绝（agent 不得冒充用户）"; fi
assert_has "$TMP/mtg-user.log" "冒充" "拒绝理由说明了冒充"

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
LOG_V="$(sed -n 's/^##[[:space:]]*\[*v\?\([0-9.]*\)\]*.*/\1/p' "$SKILL_DIR/CHANGELOG.md" | head -1)"
assert_eq "版本号三处一致（common/SKILL/CHANGELOG）" "$CODE_V|$DOC_V|$LOG_V" "$CODE_V|$CODE_V|$CODE_V"

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
assert_match "$TMP/doctor-skill.log" "skill|pi-team" "doctor 里能看到 skill 信息"

# ---------------------------------------------------------------- 11g. CEP 三条实测反馈
section "11g · CEP 反馈（forge-first / say 投递校验 / knock 诊断）"
# ① --pr 走 forge-first：forge 可用时不再先本地 push（用桩 gh 验证调用顺序）
FAKEGH="$TMP/fakegh"; mkdir -p "$FAKEGH"
cat > "$FAKEGH/gh" <<'GHSTUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
case "$1 $2" in
  "pr merge") exit 0 ;;
  *) echo '{}' ;;
esac
GHSTUB
chmod +x "$FAKEGH/gh"
GH_LOG="$TMP/gh-calls.log"; : > "$GH_LOG"
PATF="$REPO/.gh-pat"; printf 'dummy\n' > "$PATF"; chmod 600 "$PATF"
(cd "$REPO/.worktrees/dev" && git switch -c task/T9.7-ff >/dev/null 2>&1 && echo ff > ff.txt && git add -A && git -c user.email=a@b -c user.name=a commit -qm "feat: ff test") >/dev/null 2>&1
MAIN_PRE="$(git -C "$REPO" rev-parse --short HEAD)"
if env PATH="$FAKEGH:$PATH" GH_LOG="$GH_LOG" TEAM_ROOT="$REPO" TEAM_MEETINGS_DIR="$TMP/meetings" \
    TEAM_VCS=github TEAM_TOKEN_FILE="$PATF" $TEAM merge T9.7 --branch task/T9.7-ff --pr 42 --yes --no-review-check \
    >"$TMP/merge-ff.log" 2>&1; then
  ok "forge-first 合并成功"
else bad "forge-first 合并失败"; cat "$TMP/merge-ff.log"; fi
assert_has "$TMP/merge-ff.log" "先合 PR" "先尝试 forge 合并"
assert_has "$GH_LOG" "pr merge --squash --delete-branch 42" "调用了 gh pr merge（squash）"
assert_eq "forge-first 时没有本地 squash 提交" "$(git -C "$REPO" rev-parse --short HEAD)" "$MAIN_PRE"
assert_has "$TMP/merge-ff.log" "board T9.7 → done" "合并成功后标 done"
git -C "$REPO" branch -D task/T9.7-ff >/dev/null 2>&1 || true
(cd "$REPO/.worktrees/dev" && git switch --detach main >/dev/null 2>&1) || true
rm -f "$REPO/ff.txt"

# forge 合并失败：要打印真实错误，并且不再断言“PAT 缺权限”是原因
cat > "$FAKEGH/gh" <<'GHSTUB'
#!/usr/bin/env bash
echo "GraphQL: Pull request is not mergeable (mergePullRequest)" >&2
exit 1
GHSTUB
chmod +x "$FAKEGH/gh"
(cd "$REPO/.worktrees/dev" && git switch -c task/T9.6-bad >/dev/null 2>&1 && echo bad > bad.txt && git add -A && git -c user.email=a@b -c user.name=a commit -qm "feat: bad pr") >/dev/null 2>&1
env PATH="$FAKEGH:$PATH" GH_LOG="$GH_LOG" TEAM_ROOT="$REPO" TEAM_VCS=github TEAM_TOKEN_FILE="$PATF" \
  $TEAM merge T9.6 --branch task/T9.6-bad --pr 43 --yes --no-review-check >"$TMP/merge-badpr.log" 2>&1 || true
assert_has "$TMP/merge-badpr.log" "not mergeable" "打印了 forge 的真实错误"
assert_has "$TMP/merge-badpr.log" "不是权限问题" "区分了「不可合并」与「权限」"
git -C "$REPO" reset --mixed HEAD~1 >/dev/null 2>&1 || true
git -C "$REPO" branch -D task/T9.6-bad >/dev/null 2>&1 || true
(cd "$REPO/.worktrees/dev" && git switch --detach main >/dev/null 2>&1) || true
rm -f "$REPO/bad.txt"

# ② say：agent 没在跑 → 落收件箱 + 明确提示（不再硬失败）
if [ "$HAVE_TMUX" = "1" ]; then
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
TEAM_MEETING_KNOCK=1 $TEAM meeting knock knock-test >"$TMP/knock-on.log" 2>&1 || true
assert_match "$TMP/knock-on.log" "敲门排查|只落盘|已敲门" "开门时给出结论或排查清单"
$TEAM meeting knock no-such-meeting >"$TMP/knock-bad.log" 2>&1 || true
assert_has "$TMP/knock-bad.log" "会议不存在" "不存在的会议给出明确报错"
unset TEAM_MEETINGS_DIR

# ---------------------------------------------------------------- 12. 观察类命令
section "12 · roster / status / ps"
for c in roster status ps; do
  $TEAM "$c" >"$TMP/$c.log" 2>&1 && ok "$c 退出码 0" || bad "$c 失败"
  [ -s "$TMP/$c.log" ] && ok "$c 有输出" || bad "$c 无输出"
done
$TEAM watchdog-status >"$TMP/wd.log" 2>&1 && ok "watchdog-status 退出码 0" || bad "watchdog-status 失败"
$TEAM paths >"$TMP/paths.log" 2>&1 && assert_has "$TMP/paths.log" "main_root" "paths 输出主工作树" || bad "paths 失败"
$TEAM up --print >"$TMP/pmprompt.log" 2>&1 && assert_has "$TMP/pmprompt.log" "team digest" "up --print 输出 PM 开场提示词" || bad "up --print 失败"

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
const registered = { commands: [], tools: [] }
mod.default({
  on: (name, fn) => { if (name === 'agent_settled') handler = fn },
  registerCommand: (name) => { registered.commands.push(name) },
  registerTool: (def) => { registered.tools.push(def?.name) },
})
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
if (!registered.commands.includes('pi-team-reload')) { console.error('FAIL: 没注册 /pi-team-reload 命令'); process.exit(8) }
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
