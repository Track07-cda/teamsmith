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
      TEAM_WORKTREES_DIR TEAM_GATES TEAM_VCS TEAM_CONFIG_FILE TEAM_ALLOW_FOREIGN_SESSION \
      TEAM_PULSE_WINDOW TEAM_PULSE_INTERVAL TEAM_PULSE_NUDGE_GAP TEAM_PULSE_REBUILD_TMUX TEAM_PULSE_MAX_RESTARTS TEAM_PULSE_PENDING_BOARD \
      TEAM_WATCH_WINDOW TEAM_WATCH_INTERVAL TEAM_WATCH_NUDGE_GAP TEAM_WATCH_REBUILD_TMUX TEAM_WATCH_MAX_RESTARTS TEAM_WATCH_PENDING_BOARD 2>/dev/null || true
KEEP="${TEAM_SMOKE_KEEP:-0}"
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

cond_skip() { # <段落标记> [<原因>]：条件不满足时的跳过出口（V7-F6：skip 是约定不是 FAIL，必须打印）
  SKIP_N=$((SKIP_N + 1))
  SKIP_SEGS="${SKIP_SEGS}|$1"
  printf '  \033[33mSKIP（条件不满足）\033[0m %s\n' "$1${2:+ —— $2}"
}

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
# 断言「字符串 $1 里含子串 $2」（assert_has 是查文件；旧模板那条用的是字符串）
assert_has_echo() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3（[$1] 里找不到 [$2]）" ;; esac; }
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
  # 任务书必须在项目内（M6.3 F15 的守卫）；放 state/ 而不是 docs/team/tasks/，
  # 这样 T1.2 的报告仍然按「非任务报告」被忽略 —— 不改变本节之外的 pending 计数。
  mkdir -p "$REPO/.pi/team/state"
  ATASK="$REPO/.pi/team/state/$ADAPTER_ID-nonpi-brief.md"
  printf '# %s · 非 Pi adapter 冒烟\n\ntask: %s\nagent: %s\n' "$ADAPTER_ID" "$ADAPTER_ID" "$ADAPTER_AGENT" > "$ATASK"
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
  assert_has "$TMP/monitor-nonpi.log" "TEAM_AGENT_LOG_GLOB" "monitor 说明了活动流来源"
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
LEGACY_REF="cd $(printf '%q' "$REPO") && printf \"%s\\n\" \$\$ > $(printf '%q' "$PM_SPAWN") && exec $(printf '%q' "$FAKE/pi") --provider deepseek --model deepseek-flash --skill $(printf '%q' "$SKILL_DIR") -c  @$(printf '%q' "$PM_PF")"
DEFAULT_CMD="$(pm_render "$PM_PF" "$PM_SPAWN" "TEAM_PI_BIN=$FAKE/pi")"
assert_eq "M8.1 默认渲染与历史逐字节一致（TEAM_PM_CMD/BIN/RESUME_ARGS 全空）" "$DEFAULT_CMD" "$LEGACY_REF"
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
assert_eq "夹具有效：登录 bash 看不到 $BARE_DIR（否则下面那条是假绿）" \
  "$(env PATH="$BARE_DIR:$PATH" bash -lc 'command -v pm-bare || echo MISSING')" "MISSING"
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
  pm_wait_seen() { local i=0; while [ "$i" -lt 60 ]; do [ -s "$PM_SEEN" ] && return 0; sleep 0.5; i=$((i+1)); done; return 1; }
  # V9-E1：假 PM 把「看到的东西」写在开头，而 digest → board ls → dispatch --print 这条链
  # 要跑完才写 PM_FAKE_READY。只等 PM_SEEN 就断言会在负载高时提前读到半截日志（实测抖出
  # 3 条假红）。所以先等 READY（有界 30s），再断言——真死掉的 adapter 仍然会被下面抓到。
  pm_wait_ready() { local i=0; while [ "$i" -lt 60 ]; do grep -q "PM_FAKE_READY" "$PM_LOG" 2>/dev/null && return 0; sleep 0.5; i=$((i+1)); done; return 1; }
  pm_lines() { wc -l < "$PM_LOG" 2>/dev/null | tr -d ' ' || echo 0; }
  pm_close_windows() { tmux kill-window -t "$SESSION:$PMW" 2>/dev/null || true; sleep 0.3; }

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
  assert_eq "这一轮确实是新的 PM 进程（argv 日志增长）" "$([ "$(pm_lines)" -gt "$LINES1" ] && echo grew || echo same)" "grew"

  # 2b) 对照：配上 resume 参数（模板里用 {resume_args}）→ 文案变成「续跑」，参数真的进了 argv
  PMCMD_R="$FAKE/fake-pm.sh {resume_args} --pf {prompt_file} --ask {prompt}"
  LINES2="$(pm_lines)"; rm -f "$PM_SEEN"
  pm_close_windows
  env TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$PMCMD_R" TEAM_PM_BIN="$FAKE/fake-pm.sh" \
    TEAM_PM_RESUME_ARGS='--continue' $TEAM up >"$TMP/pm-adapter-up3.log" 2>&1 || true
  assert_has "$TMP/pm-adapter-up3.log" "续跑：--continue" "配了 {resume_args} → 文案说明怎么延续"
  assert_not "$TMP/pm-adapter-up3.log" "不延续" "不再说「历史不延续」"
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
  sleep 1
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
  sleep 0.6
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
  "$(env PATH="$M82_BARE_DIR:$PATH" bash -lc 'command -v worker-bare || echo MISSING')" "MISSING"
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
  printf '# %s · M8.2 adapter 启动证据\n\ntask: %s\nagent: %s\n' "$M82_ID" "$M82_ID" "$M82_AGENT" > "$M82_TASK"
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
  assert_has "$TMP/m82-die-diag.log" "render : $FAKE/worker-die --ask" "M8.2：诊断里有渲染出的命令（可手工复现）"
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
  make_pm_idle() {   # 让 PM 窗口回到空 shell（等 team_pm_state 真的报 idle:*，不是赌一次 sleep）
    tmux new-window -t "$SESSION" -n keep -d -c "$REPO" >/dev/null 2>&1 || true
    tmux list-windows -t "$SESSION" -F '#{window_id} #{window_name}' 2>/dev/null \
      | awk -v n="$PMW" '$2==n {print $1}' \
      | while read -r wid; do [ -n "$wid" ] && tmux kill-window -t "$wid" 2>/dev/null || true; done
    tmux new-window -t "$SESSION" -n "$PMW" -d -c "$REPO" >/dev/null 2>&1 || true
    # 旧实现轮询 pane_current_command + sleep 0.5；只采样一次 team_pm_state 也不够：
    # 窗口刚建好的一瞬间 pane 还没 exec 出前台命令，team_pm_state 会**假**报 idle（空 cmd），
    # 紧接着启动命令就把它变成 unknown:*（§11b3 ⑤ 的 attempts 行正是这么记错的；注入 1.2s 的
    # 启动命令后，在负载下这次假 idle 稳定复现）。判据：连续两次采样（间隔 0.5s）都是 idle:*，
    # 且两次都看到前台命令是真正的 shell。
    local i=0 st="" cmd="" ok=0
    while [ "$i" -lt 40 ]; do
      st="$(pm_state_now 2>/dev/null || true)"
      cmd="$(tmux display-message -p -t "$SESSION:$PMW" '#{pane_current_command}' 2>/dev/null || true)"
      case "$st" in idle:*)
        case "$cmd" in
          zsh|bash|sh|dash|ash|ksh|fish)
            [ "$ok" = "1" ] && { PM_STATE_LAST="$st"; return 0; }
            ok=1 ;;
          *) ok=0 ;;
        esac ;;
      *) ok=0 ;;
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
  assert_has "$TMP/monitor.log" "teamsmith monitor" "monitor 打印了标题"
  assert_has "$TMP/monitor.log" "巡检" "monitor 复用了团队状态面板"
  assert_not "$TMP/monitor.log" "agent 活动" "默认不翻各 agent 的会话（活动流 opt-in）"
  assert_has "$TMP/monitor.log" "只服务本 session" "说明了 pulse 的服务范围"
  $TEAM monitor --once --activity >"$TMP/monitor-act.log" 2>&1 || bad "monitor --activity 失败"
  assert_has "$TMP/monitor-act.log" "agent 活动" "--activity 显式打开活动流"
  assert_has "$TMP/monitor-act.log" "仅本 session 在跑的窗口" "活动流只覆盖本 session 的窗口"
  $TEAM pulse up >"$TMP/wd-up.log" 2>&1 && ok "pulse up（tmux 后端）退出码 0" || { bad "pulse up 失败"; cat "$TMP/wd-up.log"; }
  assert_eq "pulse 窗口已建" "$(tmux list-windows -t "$SESSION" -F '#{window_name}' | grep -cx pulse || true)" "1"
  $TEAM pulse status >"$TMP/wd-status.log" 2>&1
  assert_has "$TMP/wd-status.log" "tmux 窗口 $SESSION:pulse 在跑" "status 看到窗口在跑"
  $TEAM pulse logs >"$TMP/wd-logs.log" 2>&1 && ok "pulse logs（pane 快照）退出码 0" || bad "pulse logs 失败"
  assert_has "$TMP/wd-logs.log" "teamsmith monitor" "logs 显示监视器画面"
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
  local pats="$SESSION|半句草稿 half a sentence|never lands|held body|race claim|OB-EXT-KNOCK|ob-nudge-new-work|alpha line one|interrupted once|deliver as today|flush now|vis1|dropme"
  { for r in "$SMOKE_INVOKE_ROOT" "$SMOKE_INVOKE_MAIN"; do
      [ -n "$r" ] || continue
      for d in "$r/docs/team/inbox" "$r/.pi/team/state"; do
        [ -d "$d" ] || continue
        grep -rlE "$pats" "$d" 2>/dev/null || true
      done
    done; } | sort -u
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
( ob_run env OB_BOX="$TMP/ob-box-empty" OB_ECHO=1 TEAM_DEFER_TTL=0 $TEAM outbox flush >"$TMP/ob-race-b.log" 2>&1 || true ) &
wait
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

# ---------------------------------------------------------------- 12b-h. 真 pane 端到端（假 TUI）
if [ "$FAST" = "1" ]; then
  fast_skip "12b-h·真 pane 端到端（守卫/排水/草稿窗口）" "要真 tmux pane + python3 夹具 TUI（清空输入框、多行粘贴、draft 窗口）"
elif [ "$HAVE_TMUX" != "1" ] || ! command -v python3 >/dev/null 2>&1; then
  printf '  (跳过 12b-h：本机没有 tmux 或 python3)\n'
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

  # ⑨ 粘贴期间有草稿介入：不按 Enter（消息进 held/），草稿原样留着
  : > "$OB_SUBMIT"
  ob_tui race '' 'FAKE_TUI_DRAFT_ON_PASTE=HUMAN_DRAFT_'
  ob_live $TEAM draft send "$TMP/ob-three.txt" --target "$SESSION:race" >"$TMP/ob-h-race.log" 2>&1 || true
  assert_eq "12b-h ⑨ 打字期间有草稿介入 → 没有提交" "$(ob_submits)" "0"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "draft-raced" "12b-h ⑨ 条目进 held/（原因 draft-raced）"
  tmux capture-pane -p -t "$SESSION:race" 2>/dev/null | grep -qF 'HUMAN_DRAFT_alpha line one' \
    && ok "12b-h ⑨ 人的草稿还在框里（没被粘出去提交）" || bad "12b-h ⑨ 草稿没有留在框里"
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

  # ⑰ V9-B6：折叠渲染的停顿超过等待上限（≈1.6s）——不是竞态、**不是终态**：
  #    held 原因 = stall-timeout；下个排水周期只补 Enter（--resume），绝不重贴。
  ob_reset; : > "$OB_SUBMIT"
  ob_tui race3 '' 'FAKE_TUI_MARKER=10 FAKE_TUI_PASTE_STALL_MS=2500'
  ob_live $TEAM draft send "$TMP/ob-big.txt" --target "$SESSION:race3" >"$TMP/ob-h-b6.log" 2>&1 || true
  assert_eq "12b-h ⑰a V9-B6：停顿超过等待上限 → 第一拍不提交（保守）" "$(ob_submits)" "0"
  assert_has "$REPO/.pi/team/state/outbox/HOLDING.log" "reason=stall-timeout" "12b-h ⑰a V9-B6：held 原因 = stall-timeout（不是 draft-raced 终态）"
  assert_eq "12b-h ⑰a V9-B6：条目在 held/（可恢复）" "$(find "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "1"
  sleep 2.6
  ob_live $TEAM outbox flush >"$TMP/ob-h-b6b.log" 2>&1 || true
  assert_eq "12b-h ⑰b V9-B6：重试只补 Enter（不重贴）→ 恰好一次提交" "$(ob_submits)" "1"
  assert_has "$TMP/ob-h-b6b.log" "已投递" "12b-h ⑰b V9-B6：重试完成投递（已确认送达）"
  assert_eq "12b-h ⑰b V9-B6：held/ 清空、不留活动条目" "$(find "$REPO/.pi/team/state/outbox" "$REPO/.pi/team/state/outbox/held" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l | tr -d ' ')" "0"
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

# ---------------------------------------------------------------- 12b-j. 隔离收尾
ob_leaks="$(ob_leak_scan)"
assert_eq "12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹" "$([ -z "$ob_leaks" ] && echo none || printf '%s' "$ob_leaks" | head -3 | tr '\n' '|')" "none"

# 负对照（tasks 7.2）：泄漏扫描本身必须**能红**——否则它是个永远报绿的假守卫。
# 把夹具痕迹（沙盒 session 名）栽进一个假「真项目」目录，同一个扫描函数必须把它揪出来。
OB_NEG="$TMP/ob-negroot"; mkdir -p "$OB_NEG/.pi/team/state"
printf 'planted: %s\n' "$SESSION" > "$OB_NEG/.pi/team/state/planted.log"
ob_neg_hits="$(SMOKE_INVOKE_ROOT="$OB_NEG" SMOKE_INVOKE_MAIN="" ob_leak_scan)"
assert_eq "12b-j 负对照：栽进去的夹具痕迹必须被同一个扫描揪出来" "$([ -n "$ob_neg_hits" ] && echo caught || echo missed)" "caught"
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
  for seg in "6·dispatch 真拉起" "6g·非 Pi agent 端到端" "6h·派单启动证据（真窗口）" "6i·非 Pi PM 端到端" "6j·worker adapter 启动证据（真窗口）" "11·close 后窗口" "11b·巡检/pulse" "11b2·PM 存活证据链" \
             "11b3·启动中的 PM（M7.2）" "11c·agent 续跑" \
             "11d·边界守卫（真打字）" "11g②·say 离线投递" "11g③·敲门探测" "11j·pulse 迁移夹具"; do
    if skipped "$seg"; then ok "已显式跳过并打印 SKIP：$seg"
    else bad "段落 [$seg] 在 FAST 模式下既没跳过也没标记——快慢分层漏了"; fi
  done
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
assert_has "$SKILL_DIR/references/bootstrap.md" "migration.md" "bootstrap.md 指向迁移指南"
assert_has "$SKILL_DIR/references/config.md" "migration.md" "config.md 指向迁移指南"
# 英文文档不变量（M4.1 的口径）：这里只覆盖本任务交付/改过的三份 references 文档。
# 为什么不是整个 references/**：protocol.md 里还有 2 行**引用中文 CLI 输出串**（review 的翻转证据关键词），
#   那是 M6.2 引入的、属于 PM 的文件（不在本任务边界内）——已作为 finding 交回，不在测试里给它开口子。
#   复现：grep -rnP '[\x{4e00}-\x{9fff}]' skills/teamsmith/references
if printf '中\n' | grep -qP '[\x{4e00}-\x{9fff}]' 2>/dev/null; then
  M71_CJK="$(grep -lP '[\x{4e00}-\x{9fff}]' "$MDOC" "$SKILL_DIR/references/config.md" \
    "$SKILL_DIR/references/bootstrap.md" 2>/dev/null || true)"
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
    files="$( cd "$root" && find skills/teamsmith/references -type f | sort )"
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
  CJK_SB="$TMP/m73-cjk"; rm -rf "$CJK_SB"; mkdir -p "$CJK_SB/skills/teamsmith"
  cp -r "$SKILL_DIR/references" "$CJK_SB/skills/teamsmith/references"
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
assert_eq "skills/pi-team 仍是指向 teamsmith 的兼容软链（老项目的绝对路径靠它活着）" \
  "$(readlink "$SRC_ROOT/skills/pi-team" 2>/dev/null || true)" "teamsmith"
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
# 为什么目标里只有一个条目：安装器必须**明说**跳过的是兼容软链（不然读者会以为漏装了东西）
assert_has "$TMP/m73-install-link.log" "跳过 pi-team" "install.sh 说明了为什么跳过兼容软链"
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
#   （独立复验；归档要用户确认），propose→apply 之间的**记录式**提案审查（八条清单），
#   以及「不重复抄 OpenSpec 手册」（指南只留指针，不得再长出 requirement/scenario 语法样板）。
# 纯逻辑（只读文件），快慢模式都跑。
# 判据在 os_pipeline_hits 里，违规行格式固定为 `<相对文件>: <REASON>[ <detail>]`；
#   末尾的翻转夹具按 REASON 断言 —— **不是**「能报红就算过」，而是「删掉哪一条，就点名哪一条」。
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
  # ④ 八条审查清单逐条可照做：数量写死 8，砍掉一条就报红
  n="$(awk '/^### The PM/ {on=1; next} /^## / {on=0} on && /^[0-9]+\./ {c++} END {print c+0}' "$f")"
  [ "$n" = "8" ] || printf 'references/openspec.md: CHECKLIST-COUNT %s\n' "$n"
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
  ok "五阶段各有所有者与门禁；两条硬规则、记录式提案审查与八条清单都在（指南 + 模板 + SKILL + runbook）"
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
os_flip_red "把八条清单砍成七条" "CHECKLIST-COUNT 7" "references/openspec.md" '/^8\. \*\*Granularity\*\*/d'
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
  printf '# %s · M9.3 smoke fixture\n\ntask:   %s\nagent:  %s\ndeps:   -\nstatus: todo\n' \
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
printf '# M93E · 旧的那份\n\ntask: M93E\nagent: m93c\n' > "$REPO/docs/team/tasks/M93E-legacy.md"
printf '# M93E · 新的那份\n\ntask: M93E\nagent: m93c\n' > "$REPO/docs/team/tasks/M93E-reverify.md"
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
assert_eq "M9.8-⑤：有任务但窗口不在的 agent 也进唤醒理由" "$(m98_wake)" "未读通知 1 · 待复验 1 · blocked 1 · 需 PM 处理 · 停了的 agent 1"
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
if m98_wait_log "$TMP/m98-monitor.log" "teamsmith monitor" 20; then ok "M9.8-⑥：夹具巡检进程起来了（面板已渲染）"
else bad "M9.8-⑥：夹具巡检进程没起来"; fi
if m98_wait_log "$M98B_WDLOG" "无待办" 20; then ok "M9.8-⑥：第一拍 5 份看板 done → 无待办（不叫醒）"
else bad "M9.8-⑥：第一拍没有写出「无待办」（基线不对：$(tail -1 "$M98B_WDLOG" 2>/dev/null)）"; fi
assert_not "$M98B_WDLOG" "代码快照过期" "M9.8-⑥控制组：代码没变时巡检进程不重启"
printf '\nteam_reports_pending_list() { printf "DRIFT\tDRIFT\t/tmp/drift.md\n"; }\n' >> "$M98COPY/scripts/lib/cmd-status.sh"
if m98_wait_log "$M98B_WDLOG" "待复验 1" 25; then
  ok "M9.8-⑥：磁盘代码变了 → 巡检进程用**新代码**重判（日志里出现「待复验 1」）"
else bad "M9.8-⑥：磁盘代码变了 25s 仍按内存旧快照判定（「待复验 1」没出现）—— 唤醒理由会比 digest 旧"; fi
assert_has "$M98B_WDLOG" "代码快照过期" "M9.8-⑥：重启的理由写进了巡检日志（不静默换掉自己）"
assert_match "$M98B_WDLOG" "本进程 v" "M9.8-⑥：重启日志点名了它内存里那份代码（指纹 + 版本）"
kill -0 "$M98MON" 2>/dev/null && ok "M9.8-⑥：重启后巡检循环还在跑（窗口不被拆掉）" || bad "M9.8-⑥：重启后进程没了"
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

# 隔离证据（M7.2 纪律）：夹具的痕迹不得出现在真实账本里。用**内容签名**判定，不做前后 hash 对比 ——
# 真实 watchdog 每 15 分钟自己就会写 state/**，hash 对比会把它的正常写入误判成夹具泄漏。
M98_REAL_MAIN="$(dirname "$(git -C "$SKILL_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || git -C "$SKILL_DIR" rev-parse --show-toplevel)")"
M98_PHANTOM="$(grep -rlE "M98[.A-G]|$M98SES" "$M98_REAL_MAIN/docs/team/inbox" "$M98_REAL_MAIN/.pi/team/state" 2>/dev/null || true)"
if [ -n "$M98_PHANTOM" ]; then bad "M9.8 隔离：夹具的痕迹出现在真实账本里：$(printf '%s' "$M98_PHANTOM" | tr '\n' ' ')"
else ok "M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹"; fi

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
