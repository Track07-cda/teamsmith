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
assert_has "$BR/AGENTS.md" "Specs (OpenSpec)" "bootstrap 注入的协议段也告诉 agent specs 在哪（M6.3）"
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
# 或条件②：分支 tip 已经在保护分支里 → 没有复验记录也允许（正对照：闸门不是「一律拒绝」）
git -C "$REPO" branch task/T9.8-ancestor "$PROTECTED" >/dev/null 2>&1
$TEAM board add T9.8 "ancestor case" dev "-" >/dev/null 2>&1
env TEAM_BOARD_DONE_FORCE=0 $TEAM board set T9.8 done >"$TMP/done-ancestor.log" 2>&1 \
  && ok "分支已并入保护分支 → 允许 done" || bad "条件② 没生效（分支真的落地了却被拒）"
assert_has "$TMP/done-ancestor.log" "已经是 main 的祖先" "成功输出写明证据是分支落地"

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
    $TEAM monitor --once --no-watchdog --activity >"$TMP/monitor-nonpi.log" 2>&1 || true
  assert_has "$TMP/monitor-nonpi.log" "TEAM_AGENT_LOG_GLOB" "monitor 说明了活动流来源"
  assert_has "$TMP/monitor-nonpi.log" "non-pi log B" "活动流显示日志尾部（没有 Pi 会话也行）"
  tmux kill-window -t "$SESSION:$ADAPTER_AGENT" 2>/dev/null || true
  # 清场：这个假 agent 的 worktree/分支/报告不能留成「待复验」——那会污染后面的巡检断言
  # （team_reports_pending 扫 .worktrees/*，和名册无关）；清完顺手验一下真的干净了。
  git -C "$REPO" worktree remove --force "$REPO/.worktrees/$ADAPTER_AGENT" >/dev/null 2>&1 || true
  git -C "$REPO" branch -D "$ADAPTER_BRANCH" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/$ADAPTER_AGENT.env"
  APEND="$($TEAM watchdog-status 2>/dev/null || true)"
  case "$APEND" in
    *"待复验 [1-9]"*) bad "清场没干净：watchdog-status 里还有待复验（会污染后面的巡检断言）" ;;
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
  # 恢复现场：让后面的段落看到的 dev 窗口和改造前一样（活着的假 pi）
  sed -i 's|^TEAM_PI_BIN=.*|TEAM_PI_BIN="'"$FAKE/pi-sleep"'"|' "$REPO/.pi/team/config.sh"
  env TEAM_PI_AGENT_DIR="$TMP/piagent-empty" $TEAM dispatch dev T1.1 "$TASKFILE" >/dev/null 2>&1 \
    || team_dim "  （恢复 dev 窗口失败：后续段落自己会重建）"
else
  printf '  (跳过真窗口启动证据断言：没有 tmux)\n'
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
  tmux kill-session -t "$SESSION" 2>/dev/null || true      # 确保“session 丢了”的前提真的成立
  # 看门狗的告警按「待办批次」去重（sig）；把上一批的 sig 打旧，这一拍才会走到
  # “session 丢了 → 请人工 up”的告警分支（否则同一批待办会被有意静音）。
  TEAM_ROOT="$REPO" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_state_set _watch last_sig m63-step6-stale'
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

  # 8) M6.3 F26（真进程证据）：PM 不在跑时，worker 的通知走「PM 自己的收件箱」也必须叫醒它。
  #    旧实现只遍历名册：这条 durable 通道不在待办里，只有 TMUX 敲门（PM 必须在跑）。
  rm -f "$REPO/docs/team/inbox/pm.md" "$REPO/.pi/team/state/pm-restarts.log"
  $TEAM inbox --ack >/dev/null 2>&1
  printf 'M6.3 F26 live: worker summary awaiting the PM\n' > "$TMP/m63-pm-summary.txt"
  make_pm_idle
  M63_PM_BEFORE="$(pm_lines)"
  $TEAM notify pm --from-file "$TMP/m63-pm-summary.txt" >"$TMP/m63-notify-pm.log" 2>&1 || bad "notify pm 失败"
  assert_has "$REPO/docs/team/inbox/pm.md" "M6.3 F26 live" "F26：PM 自己的收件箱真的写了（PM 不在跑也不丢）"
  $TEAM watchdog-status >"$TMP/m63-wd-pm.log" 2>&1 || true
  assert_has "$TMP/m63-wd-pm.log" "未读通知" "F26：watchdog-status 把它算作待办"
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
  pm_state_now() { ( . "$SKILL_DIR/scripts/lib/common.sh"; team_load_config; team_pm_state ); }
  # 造「新建的 session + 空的 pm 窗口」：这就是环境重启后的现场，也是 M6.5 的确定性复现。
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  sleep 0.5
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
  sleep 1
  case "$(pm_state_now)" in
    running:*)          bad "M6.5 ①b：前台是 tmux 的空窗被当成了 PM（$(pm_state_now)）" ;;
    unknown:tmux|idle:*) ok "M6.5 ①b：前台是 tmux 的窗口不算 PM（$(pm_state_now)）" ;;
    *)                  bad "M6.5 ①b：期望 unknown:tmux/idle:*，实际 $(pm_state_now)" ;;
  esac
  $TEAM watchdog-status >"$TMP/m65-wd-tmux.log" 2>&1 || true
  assert_not "$TMP/m65-wd-tmux.log" "在运行" "M6.5 ①b：watchdog-status 不把 tmux 报成「PM 在运行」"
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
  sleep 1
  case "$(pm_state_now)" in
    running:*) bad "M6.5 ②：记录的 pid 已被杀，却还报 running（$(pm_state_now)）" ;;
    *)         ok "M6.5 ②：记录的 pid 死了 → 不再算存活（$(pm_state_now)）" ;;
  esac
  $TEAM watchdog-status >"$TMP/m65-wd-dead.log" 2>&1 || true
  assert_not "$TMP/m65-wd-dead.log" "在运行" "M6.5 ②：watchdog-status 不再宣称 PM 在运行"
  # ③ 本项目 cwd 里的非 PM 进程（sleep）占着 pm 窗口：unknown:*，不算存活，up 会替换
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  tmux new-session -d -s "$SESSION" -n "$PMW" -c "$REPO" 2>/dev/null || true
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec sleep 300" >/dev/null 2>&1 || true
  sleep 1
  case "$(pm_state_now)" in
    unknown:*) ok "M6.5 ③：本项目里的非 PM 进程 → unknown:*（$(pm_state_now)）" ;;
    *)         bad "M6.5 ③：期望 unknown:*，实际 $(pm_state_now)" ;;
  esac
  $TEAM watchdog-status >"$TMP/m65-wd-unknown.log" 2>&1 || true
  assert_not "$TMP/m65-wd-unknown.log" "在运行" "M6.5 ③：watchdog-status 不把非 PM 进程当成运行中的 PM"
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
  sleep 1
  case "$(pm_state_now)" in
    foreign:*) ok "M6.5 ④：别的项目的进程 → foreign:*（$(pm_state_now)）" ;;
    *)         bad "M6.5 ④：期望 foreign:*，实际 $(pm_state_now)" ;;
  esac
  case "$(pm_state_now)" in
    running:*) bad "M6.5 ④：外来进程被当成运行中的 PM" ;;
    *)         ok "M6.5 ④：外来进程不算 PM（不撒谎）" ;;
  esac
  $TEAM watchdog-status >"$TMP/m65-wd-foreign.log" 2>&1 || true
  assert_not "$TMP/m65-wd-foreign.log" "在运行" "M6.5 ④：watchdog-status 不把外来进程当成运行中的 PM"
  $TEAM up >"$TMP/m65-up-foreign2.log" 2>&1 || true
  assert_has "$TMP/m65-up-foreign2.log" "不属于本项目" "M6.5 ④：up 明确拒绝覆盖外来进程"
  # ④b 窗口里的进程就是配置的 agent（人工启动的 PM）→ running（不是 unknown）
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec $FAKE/pi-sleep --manual-pm" >/dev/null 2>&1 || true
  sleep 1
  rm -f "$REPO/.pi/team/state/pm.pid"    # 拿掉「我们启动过」这个证据，只留窗口证据
  case "$(pm_state_now)" in
    running:*) ok "M6.5 ④b：人工在窗口里启动的 agent 被认成 running（$(pm_state_now)）" ;;
    *)         bad "M6.5 ④b：人工启动的 agent 没被认出（$(pm_state_now)）" ;;
  esac
  # ⑤ M6.3 F30：wrapper agent（脚本最后 exec 掉自己）必须被报为已启动，证据 = spawn。
  # 旧实现只认「窗口里的进程 == 配置的 agent 可执行文件」：exec 换掉进程映像后永远认不出来，
  # 于是给一个活得好好的 PM 报「启动失败」（PM 在 /tmp/pm-freeze2 复现过）。
  M63_WRAP="$TMP/m63-pm-wrapper"
  printf '#!/bin/sh\nexec sleep 300\n' > "$M63_WRAP"; chmod +x "$M63_WRAP"
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$M63_WRAP\"|" "$REPO/.pi/team/config.sh"
  tmux kill-session -t "$SESSION" 2>/dev/null || true   # 从「场地不在」开始，up 自己要建
  sleep 0.5
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
  $TEAM watchdog-status >"$TMP/m63-f30-wd.log" 2>&1 || true
  assert_has "$TMP/m63-f30-wd.log" "proof=spawn" "F30：watchdog-status 显示证据来源"
  # 没有我们的 pid 记录时，窗口里的 sleep（cwd 在本项目）依旧不算 PM：非 shell 不是证据
  tmux respawn-pane -k -t "$SESSION:$PMW" "cd $REPO && exec sleep 300" >/dev/null 2>&1 || true
  rm -f "$REPO/.pi/team/state/pm.pid" "$REPO/.pi/team/state/pm.pid.proof" "$REPO/.pi/team/state/pm.pid.spawn"
  sleep 1
  case "$(pm_state_now)" in
    running:*) bad "F30：别人放的 sleep 被当成运行中的 PM（$(pm_state_now)）" ;;
    unknown:*) ok "F30：别人放的 sleep 只是 unknown（$(pm_state_now)）" ;;
    *)         bad "F30：期望 unknown:sleep，实际 $(pm_state_now)" ;;
  esac
  sed -i "s|^TEAM_PI_BIN=.*|TEAM_PI_BIN=\"$FAKE/pi-sleep\"|" "$REPO/.pi/team/config.sh"
  # 收尾：把 PM 拉回来，后面的段落（11c 起）按原来的现场跑
  $TEAM up >/dev/null 2>&1 || true
else
  printf '  (跳过 PM 存活证据链：没有 tmux)\n'
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
TEAM_AGENTS=m43d $TEAM digest >"$TMP/m43d-before.log" 2>&1 || bad "M4.3 D：digest（合并前）失败"
assert_has "$TMP/m43d-before.log" "领先 main 1" "D：未合并的分支照旧报「领先 main N」"
assert_not "$TMP/m43d-before.log" "已合并（squash" "D：未合并的分支不会被说成已合并"
if git -C "$REPO" merge --squash "$D43BR" >/dev/null 2>&1 && git -C "$REPO" commit -qm "M43D: demo (squash)" >/dev/null 2>&1; then
  ok "D 夹具：squash 合并进 main（PM 的常规路径）"
else bad "D 夹具：squash 合并失败"; fi
TEAM_AGENTS=m43d $TEAM digest >"$TMP/m43d-after.log" 2>&1 || bad "M4.3 D：digest（squash 合并后）失败"
assert_has "$TMP/m43d-after.log" "已合并（squash，内容一致）" "D：squash 合并后被认出来（内容一致）"
assert_has "$TMP/m43d-after.log" "无需 push" "D：不再暗示要 push（内容已在保护分支）"
assert_not "$TMP/m43d-after.log" "收尾：提交并 push" "D：不再给出「收尾：提交并 push」"
assert_not "$TMP/m43d-after.log" "领先 main 1" "D：不再把已合并的分支报成待收尾的领先"
TEAM_AGENTS=m43d $TEAM roster >"$TMP/m43d-roster.log" 2>&1 || bad "M4.3 D：roster 失败"
assert_has "$TMP/m43d-roster.log" "已合并" "D：roster 把 squash 合并与真领先分开显示"
# 正对照：分支上再落一个无关提交 → 回到诚实的「领先 N」（没把信号整体静音）
printf 'more\n' >> "$D43WT/m43d.txt"
git -C "$D43WT" commit -qam "feat(M43D): more" >/dev/null 2>&1
TEAM_AGENTS=m43d $TEAM digest >"$TMP/m43d-extra.log" 2>&1 || bad "M4.3 D：digest（又领先）失败"
assert_has "$TMP/m43d-extra.log" "领先 main 2" "D：分支又有内容时回到「领先 N」"
assert_not "$TMP/m43d-extra.log" "已合并（squash" "D：tree 不同时不再说已合并"
git -C "$REPO" worktree remove --force "$D43WT" >/dev/null 2>&1 || true
git -C "$REPO" branch -D "$D43BR" >/dev/null 2>&1 || true

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
# M6.1 F28：只读命令对 state/ 必须是零写入（快慢模式都跑；快模式下没有 tmux 窗口，
# 旧实现会在 team ps 里把 dev.env 删掉 —— 这条断言就是那个回归的守门人）
STATE_FP_BEFORE="$(state_fp)"
for c in paths roster status ps digest inbox watchdog-status; do
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
$TEAM watchdog-status >"$TMP/wd.log" 2>&1 && ok "watchdog-status 退出码 0" || bad "watchdog-status 失败"
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
  for seg in "6·dispatch 真拉起" "6g·非 Pi agent 端到端" "6h·派单启动证据（真窗口）" "11·close 后窗口" "11b·巡检/watchdog" "11b2·PM 存活证据链" \
             "11c·agent 续跑" \
             "11d·边界守卫（真打字）" "11g②·say 离线投递" "11g③·敲门探测"; do
    if skipped "$seg"; then ok "已显式跳过并打印 SKIP：$seg"
    else bad "段落 [$seg] 在 FAST 模式下既没跳过也没标记——快慢分层漏了"; fi
  done
fi

# ---------------------------------------------------------------- 16. spec lint（可证伪性门禁，M5.3）
# `openspec validate --all --strict` 只管结构：删掉 scenario 的 THEN、删掉整个 scenario、把 spec.md 只剩标题，
# 它都照样绿 —— 门禁就会在一份无法失败的 spec 上给绿灯。tests/spec-lint.sh 必须让这些删除变红，所以这一节
# 两个方向都测：坏 spec 必须红（且报对规则码），真 spec 必须绿。没有这段，「spec lint ✓」可能只是一个永远
# 绿的检查器（假绿比不查更糟）；反过来把 lint 写死成拒绝一切，正对照也会红。
section "16 · spec lint（spec 可证伪性）"
SL_ROOT="$TMP/spec-lint"; rm -rf "$SL_ROOT"; mkdir -p "$SL_ROOT/good/specs/demo"
cat > "$SL_ROOT/good/specs/demo/spec.md" <<'EOF'
# demo Specification

## Purpose

Fixture for the falsifiability lint.

## Requirements

### Requirement: A thing MUST happen

The tool MUST do the thing when asked.

#### Scenario: Happy path

- **GIVEN** a wired thing
- **WHEN** `thing run` runs
- **THEN** it exits 0 and prints `ok`
EOF
sl_tree() { # <名字> → 复制正样本并回显路径（调用方再把它改坏）
  rm -rf "$SL_ROOT/$1"; cp -r "$SL_ROOT/good" "$SL_ROOT/$1"; printf '%s' "$SL_ROOT/$1"
}
sl_run() { bash "$SKILL_DIR/tests/spec-lint.sh" "$1" >"$TMP/spec-lint.out" 2>&1; }
sl_green() { # <说明> <树>
  if sl_run "$2"; then ok "$1"; else bad "$1（应当绿）"; sed 's/^/     /' "$TMP/spec-lint.out"; fi
}
sl_red() { # <说明> <期望规则码> <树>
  if sl_run "$3"; then bad "lint 漏报：$1（应当非 0）"
  elif grep -qF -- "$2" "$TMP/spec-lint.out"; then ok "lint 报红：$1（$2）"
  else bad "lint 报红但规则码不对：$1（期望 $2）"; sed 's/^/     /' "$TMP/spec-lint.out"; fi
}
sl_rc() { # <说明> <期望退出码> <树>
  sl_run "$3"; local rc=$?
  [ "$rc" = "$2" ] && ok "$1" || bad "$1（期望 rc=$2，实际 $rc）"
}

sl_green "正对照：合法 spec 通过（检查器不是永远红）" "$SL_ROOT/good"

# 坏样本：每个只破坏一件事，期望的规则码必须出现在 lint 输出里
SLT="$(sl_tree no-then)"
awk '/^- \*\*THEN\*\*/{next} {print}' "$SLT/specs/demo/spec.md" > "$SLT/spec.md" && mv "$SLT/spec.md" "$SLT/specs/demo/spec.md"
sl_red "删掉 scenario 的 THEN（有触发、没断言）" "scenario-without-then" "$SLT"

SLT="$(sl_tree no-when)"
awk '/^- \*\*WHEN\*\*/{next} {print}' "$SLT/specs/demo/spec.md" > "$SLT/spec.md" && mv "$SLT/spec.md" "$SLT/specs/demo/spec.md"
sl_red "删掉 scenario 的 WHEN（有断言、没触发）" "scenario-without-when" "$SLT"

SLT="$(sl_tree no-scenario)"
awk '/^#### Scenario:/{exit} {print}' "$SLT/specs/demo/spec.md" > "$SLT/spec.md" && mv "$SLT/spec.md" "$SLT/specs/demo/spec.md"
sl_red "删掉整个 scenario（requirement 没有可证伪的场景）" "requirement-without-scenario" "$SLT"

SLT="$(sl_tree empty-spec)"
printf '# demo Specification\n' > "$SLT/specs/demo/spec.md"
sl_red "spec.md 只剩标题（空壳 spec）" "no-requirements" "$SLT"

SLT="$(sl_tree placeholder)"
awk '/^- \*\*THEN\*\*/{$0="- **THEN** it works"} {print}' "$SLT/specs/demo/spec.md" > "$SLT/spec.md" && mv "$SLT/spec.md" "$SLT/specs/demo/spec.md"
sl_red "占位断言（THEN it works）" "scenario-placeholder" "$SLT"

SLT="$(sl_tree no-spec-files)"; rm -f "$SLT"/specs/demo/spec.md; touch "$SLT/specs/README.txt"
sl_red "specs/ 里没有 spec.md（查不到东西的绿灯不是绿灯）" "no-specs" "$SLT"

sl_rc "不存在的 spec 根目录 → rc=2（用法错误，不是校验失败）" 2 "$SL_ROOT/does-not-exist"

# changes/ 是提案：目录本身要有内容，ADDED/MODIFIED delta 仍要有 scenario，REMOVED 允许没有
SLT="$(sl_tree change-empty)"; mkdir -p "$SLT/changes/wip"
sl_red "change 目录里什么都没有" "change-incomplete" "$SLT"

SLT="$(sl_tree change-proposal)"; mkdir -p "$SLT/changes/wip"; echo '# why' > "$SLT/changes/wip/proposal.md"
sl_green "只有 proposal.md 的 change（提案早期，不该被拦）" "$SLT"

SLT="$(sl_tree change-baddelta)"; mkdir -p "$SLT/changes/wip/specs/demo"
printf '# demo delta\n\n## ADDED Requirements\n\n### Requirement: New thing MUST happen\n\nText.\n' > "$SLT/changes/wip/specs/demo/spec.md"
sl_red "ADDED delta 的 requirement 没有 scenario" "delta-requirement-without-scenario" "$SLT"

SLT="$(sl_tree change-removed)"; mkdir -p "$SLT/changes/wip/specs/demo"
printf '# demo delta\n\n## REMOVED Requirements\n\n### Requirement: Old thing\n' > "$SLT/changes/wip/specs/demo/spec.md"
sl_green "REMOVED delta 允许无 scenario（删除不是新承诺）" "$SLT"

# 真树：既必须绿，报告的计数也必须与 grep 出来的事实一致（不硬编码数字，spec 增删不会误报）
SL_REAL="$(cd "$SKILL_DIR/../.." && pwd)/openspec"
if sl_run "$SL_REAL"; then
  SL_REQ="$(grep -rhc '^### Requirement:' "$SL_REAL"/specs/*/spec.md | awk '{s+=$1} END{print s+0}')"
  SL_SCEN="$(grep -rhc '^#### Scenario:' "$SL_REAL"/specs/*/spec.md | awk '{s+=$1} END{print s+0}')"
  ok "真 openspec 树通过 spec lint"
  assert_has "$TMP/spec-lint.out" "$SL_REQ requirement(s)" "lint 报的 requirement 数与真树一致（$SL_REQ）"
  assert_has "$TMP/spec-lint.out" "$SL_SCEN scenario(s)" "lint 报的 scenario 数与真树一致（$SL_SCEN）"
else
  bad "真 openspec 树没通过 spec lint"; sed 's/^/     /' "$TMP/spec-lint.out"
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
