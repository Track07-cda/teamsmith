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
TEAM="bash $SKILL_DIR/scripts/team"

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ────────────────────────────
# 事故背景（v1.11.3 实测）：smoke 从 worker 的 Pi 会话里被调用时继承了 TEAM_ROOT，
# 于是 `team` 读到的是**真实项目**的配置（session/agents/gates 全是真实的），
# 测试里的 tmux/watchdog 段落因此作用到真实 session 上 —— 把 PM 自己的窗口全打掉了。
# 教训：测试必须显式声明「我只服务自己的临时仓库和自己的 session」。
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT \
      TEAM_SESSION TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR \
      TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE TEAM_ALLOW_FOREIGN_SESSION 2>/dev/null || true
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

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
live_mark() { LIVE_RAN=$((LIVE_RAN + 1)); }
fast_skip() { # <段落标记> <原因>：FAST 模式跳过真进程段落时唯一的出口（必须打印）
  SKIP_N=$((SKIP_N + 1))
  SKIP_SEGS="${SKIP_SEGS}|$1"
  printf '  \033[33mSKIP（FAST 模式）\033[0m %s —— %s\n' "$1" "$2"
}
skipped() { case "|$SKIP_SEGS|" in *"|$1|"*) return 0 ;; *) return 1 ;; esac; }   # 首尾补 | ，最后一段也能匹配

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

TMP="$(mktemp -d /tmp/teamsmith-smoke.XXXXXX)"
SESSION="teamsmith-smoke-$$"
PROTECTED="main"   # 与 TEAM_PROTECTED_BRANCH 默认值一致
REPO="$TMP/repo"
FAKE="$TMP/fake-bin"
mkdir -p "$REPO" "$FAKE"

# 环境兜底：PATH 里没有 pi 时把下面的假 pi 放进 PATH（见"假 pi"那段），
# 这样缺 pi 只是少跑真进程相关的断言，而不是级联 14 条红（V1.1 实测）。
NEED_PI_STUB=0
command -v pi >/dev/null 2>&1 || NEED_PI_STUB=1

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
git config user.email smoke@teamsmith
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
git init -q -b main; git config user.email smoke@teamsmith; git config user.name smoke
echo "# boot" > README.md; git add -A; git commit -qm init
BSESS="teamsmith-smoke-boot-$$"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog --print >"$TMP/boot-print.log" 2>&1 \
  && ok "bootstrap --print 退出码 0" || bad "bootstrap --print 失败"
assert_has "$TMP/boot-print.log" "计划步骤" "打印了计划步骤"
assert_has "$TMP/boot-print.log" "add-agent dev" "计划里含建 worktree"
assert_has "$TMP/boot-print.log" "watchdog up" "计划里含起看门狗窗口"
[ -f "$BR/.pi/team/config.sh" ] && bad "--print 不该改任何东西" || ok "--print 确实没改东西"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog >"$TMP/boot.log" 2>&1 \
  && ok "bootstrap 退出码 0" || { bad "bootstrap 失败"; cat "$TMP/boot.log"; }
assert_file "$BR/.pi/team/config.sh" "bootstrap 写了配置"
assert_has "$BR/.pi/team/config.sh" "TEAM_SESSION=\"$BSESS\"" "把探测/指定的 session 写进配置"
assert_dir "$BR/docs/team/tasks" "建了文档骨架"
assert_has "$TMP/boot.log" "worktree add -b agent/dev" "bootstrap 只打印 worktree 命令（git 归 PM）"
assert_not_file "$BR/.worktrees/dev" "默认不代建 dev worktree"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog --create-worktrees >"$TMP/boot2.log" 2>&1 || true
assert_dir "$BR/.worktrees/dev" "--create-worktrees 才代建 dev worktree"
assert_dir "$BR/.worktrees/verify" "--create-worktrees 才代建 verify worktree"
assert_has "$BR/AGENTS.md" "<!-- teamsmith:begin -->" "注入了协议段"
assert_has "$TMP/boot.log" "下一步" "打印了下一步清单"
$TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog >"$TMP/boot2.log" 2>&1
assert_eq "bootstrap 幂等（协议段只一份）" "$(grep -cF '<!-- teamsmith:begin -->' "$BR/AGENTS.md")" "1"
# 必需依赖预检（D10）：配置写完后就要体检；缺了不阻塞，但每条都要给出修复/降级办法
env TEAM_PI_SETTINGS_FILE="$TMP/mc-none/settings.json" TEAM_OPENSPEC_BIN=/nonexistent \
  $TEAM bootstrap --agents "dev verify" --session "$BSESS" --no-watchdog >"$TMP/boot-deps.log" 2>&1 \
  && ok "缺依赖时 bootstrap 仍然退出码 0（不阻塞初始化）" || { bad "缺依赖不该让 bootstrap 失败"; tail -5 "$TMP/boot-deps.log"; }
assert_has "$TMP/boot-deps.log" "必需依赖还没就绪" "bootstrap 提示必需依赖"
assert_has "$TMP/boot-deps.log" "@cortexkit/pi-magic-context" "bootstrap 给出 magic-context 的修复办法"
assert_has "$TMP/boot-deps.log" "openspec init --tools none" "bootstrap 给出 spec 目录的确切修复命令"
assert_has "$TMP/boot-deps.log" "TEAM_OPENSPEC_BIN" "bootstrap 给出 CLI 解析的降级/指定办法"
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
assert_has "$REPO/AGENTS.md" "<!-- teamsmith:begin -->" "AGENTS.md 注入协议段"
assert_has "$REPO/.gitignore" ".worktrees/" ".gitignore 忽略 worktree"

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
# 探测守卫：在「别的项目」的 tmux pane 里 bootstrap，不许把对方的 session 当成自己的
PROBE="$TMP/probe-repo"; mkdir -p "$PROBE"; ( cd "$PROBE" && git init -q -b main && git commit -q --allow-empty -m x )
( cd "$PROBE" && $TEAM bootstrap --agents dev --no-watchdog --print ) >"$TMP/boot-probe.log" 2>&1 || true
if [ "${HAVE_TMUX:-0}" = "1" ] && [ -n "${TMUX:-}" ]; then
  assert_has "$TMP/boot-probe.log" "不属于本项目" "探测守卫：不认别的项目的 tmux session"
else
  printf '  \033[2m·\033[0m %s\n' "（无 tmux：跳过探测守卫断言）"
fi
assert_has "$REPO/.gitignore" "docs/team/inbox/" ".gitignore 忽略收件箱"
assert_has "$REPO/.gitignore" ".pi/team/state/" ".gitignore 忽略运行时状态"
# 模板渲染不能有残留占位符
if grep -rqF '{{' "$REPO/docs/team" "$REPO/.pi/team/config.sh" "$REPO/AGENTS.md" 2>/dev/null; then
  bad "模板有未渲染的占位符 {{...}}"; grep -rnF '{{' "$REPO/docs/team" "$REPO/AGENTS.md" | head -3
else ok "模板全部渲染（无 {{ 残留）"; fi
# 幂等：再 init 一次不应重复追加协议段
$TEAM init --session "$SESSION" --agents "dev verify" --vcs local --gates "true" --docs docs/team >/dev/null 2>&1
assert_eq "AGENTS.md 协议段幂等（只出现一次）" "$(grep -cF '<!-- teamsmith:begin -->' "$REPO/AGENTS.md")" "1"

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
git -C "$REPO/.worktrees/dev" switch -c task/T1.1-smoke "$PROTECTED" >/dev/null 2>&1 || git -C "$REPO/.worktrees/dev" switch task/T1.1-smoke >/dev/null 2>&1
$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md --print >"$TMP/print-branch.log" 2>&1 && ok "PM 建好分支后 dispatch 可用" || bad "建好分支后 dispatch 仍失败"
echo dirty > "$REPO/.worktrees/dev/dirty.txt"
if $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-smoke-task.md >"$TMP/dispatch-dirty.log" 2>&1; then bad "脏工作树应当拒绝派单"; else ok "脏工作树拒绝派单"; fi
assert_has "$TMP/dispatch-dirty.log" "git 归 PM" "说明 git 归 PM"
rm -f "$REPO/.worktrees/dev/dirty.txt"

section "6 · dispatch"
$TEAM dispatch dev T1.1 "$TASKFILE" --print >"$TMP/print.log" 2>&1 || bad "dispatch --print 失败"assert_has "$TMP/print.log" "--session-id $SESSION-dev" "命令含正确的 session-id"
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
assert_match "$TMP/print.log" "^cd .* && /| pi_bin" "派单命令里用的是解析后的路径（见下方 dispatch 断言）"

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
  ATASK="$TMP/$ADAPTER_ID-task.md"
  printf '# %s · 非 Pi adapter 冒烟\n\ntask: %s\nagent: %s\n' "$ADAPTER_ID" "$ADAPTER_ID" "$ADAPTER_AGENT" > "$ATASK"
  # 第二个 worker（agent 模式名册里新增一个），自己的 worktree/分支：不动 dev 的账
  git -C "$REPO" worktree add -b "task/$ADAPTER_ID-agent-adapter" "$REPO/.worktrees/$ADAPTER_AGENT" "$PROTECTED" >/dev/null 2>&1 || true
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
    $TEAM monitor --once --no-watchdog --activity >"$TMP/monitor-nonpi.log" 2>&1 || true
  assert_has "$TMP/monitor-nonpi.log" "TEAM_AGENT_LOG_GLOB" "monitor 说明了活动流来源"
  assert_has "$TMP/monitor-nonpi.log" "non-pi log B" "活动流显示日志尾部（没有 Pi 会话也行）"
  tmux kill-window -t "$SESSION:$ADAPTER_AGENT" 2>/dev/null || true
  # 清场：这个假 agent 的 worktree/分支/报告不能留成「待复验」——那会污染后面的巡检断言
  # （team_reports_pending 扫 .worktrees/*，和名册无关）；清完顺手验一下真的干净了。
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/$ADAPTER_AGENT" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "task/$ADAPTER_ID-agent-adapter" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/$ADAPTER_AGENT.env"
  APEND="$($TEAM watchdog-status 2>/dev/null || true)"
  case "$APEND" in
    *"待复验 [1-9]"*) bad "清场没干净：watchdog-status 里还有待复验（会污染后面的巡检断言）" ;;
    *) ok "清场后不再有待复验报告（不影响后面的巡检断言）" ;;
  esac
else
  printf '  (跳过非 Pi 端到端断言：没有 tmux)\n'
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
       '' \
       '## 翻转证据（control experiment）' \
       '- 破坏实现 → 守门测试必须失败；独立验证包见 docs/team/reports/T1.1/verify.sh' \
       > docs/team/reports/T1.1-dev.md \
  && for i in $(seq 1 300); do printf 'padding line %s\n' "$i"; done >> docs/team/reports/T1.1-dev.md \
  && git add -A && git commit -qm "feat(T1.1): add feature" ) >/dev/null 2>&1 \
  && ok "worktree 内提交成功" || bad "worktree 内提交失败"
assert_eq "分支有 1 个提交" "$(git -C "$REPO/.worktrees/dev" rev-list --count main..HEAD)" "1"

# ---------------------------------------------------------------- 10. review
section "10 · review（独立 worktree + 门禁）"
REV_WT="$TMP/review-checkout"
git -C "$REPO" worktree add --detach "$REV_WT" task/T1.1-smoke >/dev/null 2>&1 || true
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

# 强复验判定：长报告（300+ 行、关键词在结尾）里的证据不能被 SIGPIPE 吃掉
if grep -q '破坏性验证证据（故意改坏实现 → 守门测试必须失败）：有' "$REPO/docs/team/reviews/T1.1.md" 2>/dev/null \
   || grep -q '翻转证据' "$REV_WT/docs/team/reports/T1.1-dev.md" 2>/dev/null; then
  ok "长报告里的翻转/独立包证据被正确识别（SIGPIPE 假阴性已修）"
else
  bad "长报告里的证据被判成「缺」（SIGPIPE 假阴性）"
fi

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

# ---------------------------------------------------------------- 11. merge / close
section "11 · 收尾（merge 已移除，close 保留）"
if $TEAM merge T1.1 >/dev/null 2>&1; then bad "merge 应已移除"; else ok "merge 已移除（PM 用 git）"; fi
$TEAM board set T1.1 done >/dev/null 2>&1
assert_eq "BOARD 可由 PM 直接收尾" "$($TEAM board row T1.1 | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$(NF-1)); print $(NF-1)}')" "done"
$TEAM close T1.1 >/dev/null 2>&1 && ok "close 退出码 0" || bad "close 失败"
if [ "$FAST" = "1" ]; then
  fast_skip "11·close 后窗口" "窗口断言要有 tmux 场地（快模式不建场地）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  assert_eq "close 后窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -cx dev || true)" "0"
fi

section "11b · 定时巡检：有待办才叫醒 PM（默认 15 分钟）"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "%s"\nsleep 600\n' "$TMP/pm-args.log" > "$FAKE/pi-sleep"
chmod +x "$FAKE/pi-sleep"

if [ "$FAST" = "1" ]; then
  fast_skip "11b·巡检/watchdog" "要真实 tmux + 假 pi 进程（up/watch/standby/monitor，含多处 sleep）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
  PMW="$($TEAM paths | sed -n 's/.*"pm_window": "\([^"]*\)".*/\1/p')"
  [ -n "$PMW" ] || PMW=pm
  # 制造“PM 窗口在、里面是空提示符”的现场（pi 退出后的样子），并用占位窗口保住 session
  make_pm_idle() {   # 让 PM 窗口回到空 shell（轮询到 pane_current_command 是 shell）
    tmux new-window -t "$SESSION" -n keep -d -c "$REPO" >/dev/null 2>&1 || true
    tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null \
      | awk -v n="$PMW" '$2==n {print $1}' \
      | while read -r wid; do [ -n "$wid" ] && tmux kill-window -t "$wid" 2>/dev/null || true; done
    tmux new-window -t "$SESSION" -n "$PMW" -d -c "$REPO" >/dev/null 2>&1 || true
    local i cmd=""
    for i in $(seq 1 20); do
      cmd="$(tmux display-message -p -t "$SESSION:$PMW" '#{pane_current_command}' 2>/dev/null || true)"
      case "$cmd" in
        zsh|bash|sh|dash|ash|ksh|fish) break ;;
      esac
      sleep 0.3
    done
    sleep 0.5
  }

  start_fake_pm() { # 直接模拟“PM 正在跑”，避免依赖 up 的时序
    local p; p="$(tmux list-panes -t "$SESSION:$PMW" -F '#{pane_id}' 2>/dev/null | head -1)"
    # 空目标 = 当前 pane（会把调用者自己打掉）——这正是 v1.11.3 事故的直接原因
    [ -n "$p" ] || { bad "start_fake_pm：拿不到 pane（$SESSION:$PMW 不存在），跳过以免误伤"; return 1; }
    tmux respawn-pane -k -t "$p" "exec $FAKE/pi-sleep --pm" >/dev/null 2>&1 || true
    sleep 1.5
  }
  kill_all_windows() {
    tmux list-windows -t "$SESSION" -F '#{window_id}' 2>/dev/null \
      | while read -r wid; do [ -n "$wid" ] && tmux kill-window -t "$wid" 2>/dev/null || true; done
    sleep 0.5
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

  # 3b) PM 归属校验：窗口被「不属于本项目」的进程占着时，不算 PM、也不许覆盖
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd /tmp && exec bash -lc 'sleep 300'" >/dev/null 2>&1 || true
  sleep 1
  (. "$SKILL_DIR/scripts/lib/common.sh"; team_load_config; team_pm_state) >"$TMP/pmstate-foreign.log" 2>&1 || true
  assert_match "$TMP/pmstate-foreign.log" "^foreign:" "别的项目的进程占着 PM 窗口 → 判定为 foreign（不算 PM）"
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
  assert_has "$REPO/docs/team/inbox/pm.md" "watchdog" "给 PM 留了收件箱消息"
  assert_eq "拉起计数已记录" "$(wc -l < "$REPO/.pi/team/state/pm-restarts.log" | tr -d ' ')" "1"
  if [ "$(pm_lines)" -gt "$DEAD_BEFORE" ]; then ok "PM 参数已写入（$DEAD_BEFORE → $(pm_lines)）"
  elif tmux list-panes -t "$SESSION:$PMW" -F '#{pane_pid}' | head -1 | xargs -r ps -o args= -p 2>/dev/null | grep -q pi-sleep; then
    ok "PM 已被拉起（窗口里跑着 pi，日志尚未落盘）"
  else bad "PM 没有被拉起（$DEAD_BEFORE → $(pm_lines)）"; fi

  # 4b) 看门狗：**只有一个后端**（同 session 的窗口里跑 monitor）
  $TEAM monitor --once >"$TMP/monitor.log" 2>&1 && ok "monitor --once 退出码 0" || bad "monitor --once 失败"
  assert_has "$TMP/monitor.log" "teamsmith monitor" "monitor 打印了标题"
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
  assert_has "$TMP/wd-logs.log" "teamsmith monitor" "logs 显示监视器画面"
  $TEAM watchdog up >"$TMP/wd-up2.log" 2>&1
  assert_has "$TMP/wd-up2.log" "已在跑" "up 幂等（不重复起窗口）"
  $TEAM watchdog down >"$TMP/wd-down.log" 2>&1 && ok "watchdog down 退出码 0" || bad "watchdog down 失败"
  assert_eq "看门狗窗口已关" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx watchdog || true)" "0"
  $TEAM watchdog up --print >"$TMP/wd-print.log" 2>&1 && ok "watchdog up --print 退出码 0" || bad "watchdog --print 失败"
  assert_has "$TMP/wd-print.log" "$SESSION:watchdog" "--print 指明它要起的窗口"
  assert_has "$TMP/wd-print.log" "巡检周期" "--print 说明巡检周期"
  # 容器后端已移除（v1.12.0）：必须明确拒绝，而不是静默忽略
  if $TEAM watchdog up --container >"$TMP/wd-cont.log" 2>&1; then
    bad "watchdog --container 应被明确拒绝（容器后端已移除）"
  else
    ok "watchdog --container 被明确拒绝"
  fi
  assert_has "$TMP/wd-cont.log" "容器后端已移除" "拒绝时说明原因（并指向 watchdog up）"

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
  $TEAM watch --once >"$TMP/watch4.log" 2>&1 || true
  if tmux has-session -t "$SESSION" 2>/dev/null; then bad "watchdog 不该重建 tmux session（默认不管 tmux）"; else ok "session 丢了 watchdog 不重建（默认不管 tmux）"; fi
  assert_match "$TMP/watch4.log" "不管 tmux|人工" "给出了“需要人工 up”的提示"
  TEAM_WATCH_REBUILD_TMUX=1 $TEAM watch --once >"$TMP/watch5.log" 2>&1 || true
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
else
  printf '  (跳过巡检断言：没有 tmux)\n'
fi

# ---------------------------------------------------------------- 11c. 恢复：resume / watchdog 续跑
section "11c · agent 续跑是 PM 的事（watchdog 不碰）"
if [ "$FAST" = "1" ]; then
  fast_skip "11c·agent 续跑" "要真实 tmux 窗口 + 真实窗口现场（roster 区分「窗口在但 pi 已退出」）"
elif [ "$HAVE_TMUX" = "1" ]; then
  live_mark
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

# ---------------------------------------------------------------- 14b. 文档一致性（防回退）
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
  printf '%s\n' "$out" | grep -v '^$' | while IFS= read -r line; do
    case "$line" in
      *已删*|*已移除*|*不再*|*废弃*|*历史*) case "$line" in *'`'*) continue ;; *) printf '%s\n' "$line" ;; esac ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
}

REAL_HITS="$(doc_stale_hits "$SKILL_DIR")"
if [ -n "$REAL_HITS" ]; then
  bad "真树里有已删命令的用法：$(printf '%s' "$REAL_HITS" | head -1)"
else
  ok "真树无残留（词边界口径：team merge|pr|gh|gl）"
fi

# 翻转自测（关键）：往 skill 的沙箱副本里注入变体，检查器**必须**报红。
# 没有这一步，"无残留 ✓" 可能只是检查器太弱（V1.1 实测：旧口径漏掉 8 类写法，真树假绿）。
SANDBOX="$TMP/docsandbox"; rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"
cp -r "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references "$SKILL_DIR"/templates "$SKILL_DIR"/scripts "$SANDBOX/" 2>/dev/null || true
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
CLEAN_HITS="$(doc_stale_hits "$SANDBOX")"
[ -z "$CLEAN_HITS" ] && ok "翻转自测：干净副本不误报（正对照）" || bad "干净副本被误报：$(printf '%s' "$CLEAN_HITS" | head -1)"

# 依赖收窄不变量（v1.12.0）：文档/模板里不得再把容器后端或 forge CLI 当依赖
DEP_HITS="$(grep -rniE 'podman|\-\-container|看门狗容器|Containerfile' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" 2>/dev/null | grep -vE '不再需要|不再有|已移除|v1\.12' || true)"
if [ -n "$DEP_HITS" ]; then bad "文档还在把容器当依赖：$(printf '%s' "$DEP_HITS" | head -1)"; else ok "文档不再把容器当前提（只有一个后端）"; fi
FORGE_HITS="$(grep -rniE '缺 (gh|glab)|TEAM_VCS=github 但|gh wrapper' "$SKILL_DIR/SKILL.md" "$SKILL_DIR/references" "$SKILL_DIR/templates" "$SKILL_DIR/scripts" 2>/dev/null || true)"
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
    "$SKILL_DIR/extension" "$SKILL_DIR/../README.md" 2>/dev/null \
  | grep -vE '兼容|旧名|迁移|别名|v1\.13|begin|end|reload|smoke|compatibility|former name|renamed|alias' || true)"
if [ -n "$OLDNAME_HITS" ]; then bad "还有旧名 pi-team 的残留：$(printf '%s' "$OLDNAME_HITS" | head -1)"; else ok "名字一致性：除兼容说明外无旧名残留"; fi
# 兼容软链必须存在（老项目配置里的绝对路径靠它活着）
[ -L "$SKILL_DIR/../pi-team" ] && ok "兼容软链 skills/pi-team → teamsmith 在位" || bad "缺兼容软链 skills/pi-team"
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
  for seg in "6·dispatch 真拉起" "6g·非 Pi agent 端到端" "11·close 后窗口" "11b·巡检/watchdog" "11c·agent 续跑" \
             "11d·边界守卫（真打字）" "11g②·say 离线投递" "11g③·敲门探测"; do
    if skipped "$seg"; then ok "已显式跳过并打印 SKIP：$seg"
    else bad "段落 [$seg] 在 FAST 模式下既没跳过也没标记——快慢分层漏了"; fi
  done
fi

# ---------------------------------------------------------------- 15. 结束
section "15 · 完成"
printf '   （全流程已在 0–14 节覆盖）\n'
printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
if [ "$FAST_REQ" = "1" ]; then
  printf '\033[33mFAST 模式：跳过 %d 个真进程段落（%s）——完整门禁请不带 TEAM_SMOKE_FAST 重跑\033[0m\n' \
    "$SKIP_N" "${SKIP_SEGS#|}"
fi
[ "$FAIL" -eq 0 ] && { printf '\033[32msmoke 全绿\033[0m\n'; exit 0; }
printf '\033[31msmoke 有失败项（--keep 保留现场）\033[0m\n'
exit 1
