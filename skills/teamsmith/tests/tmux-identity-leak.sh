#!/usr/bin/env bash
# P274 · tmux 身份作用域（change: tmux-identity-scope · apply-1）—— 写侧 / 会话作用域 / 不许削弱 / 审计
#
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --all
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select write-side,session-scope,kill-identity,audit
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select write-side   --break=strip   # 红侧 1
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select audit        --break=log     # 红侧 2
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select kill-identity --break=kill   # 红侧 3
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select session-scope --break=e      # 红侧 4
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --all --break=path     # 红侧 5（现场在门禁镜像里）
#
# 证明什么（每条对着 design §1/§3 与任务书的红侧清单）：
#   ① 写侧：私有 socket 上没有 server 时，带**身份 + 闸门钉桩**的 shell 跑 `team up` → server 的**全局
#      环境**里零个本项目 TEAM_*；同一 server 上**项目 B** 新开 session 的 pane 里也没有。同一判据的负
#      对照（身份直接起 server 的旧形状）必须**看得见**泄漏 —— 否则「绿」只是测量坏了。摘命名空间的集合
#      只取**可能启动 server** 的那族动词（`new*`/`split*`/`respawn*`/`start*`）：只读动词留着身份是
#      §31c ⑪/⑫ 的既有契约（CLI 的 tmux 子进程看得见身份），而它们不可能启动 server —— ①f 钉住这条
#      事实（没有 server 时只读动词不留 socket）。
#   ② B（会话作用域）：`new-session -e` 把四个身份变量写进**会话**作用域 → 本项目会话里**人手新开**的
#      窗口环境里恰有那 4 个（值 = 本项目），而 server 全局环境仍然干净。
#   ③ 不许削弱：窗口里走产品的破坏性路径（`team teardown`）→ 闸门记 `act=allowed-owned`（默认 socket
#      形状；真身是 stub，真 server 一根手指都没碰），并且被 exec 的真身**看得见** TEAM_SESSION
#      （kill 类保留身份）。§31c/§6i 是这条的权威断言，本段是「身份来自会话作用域」形态的独立实例。
#   ④ C/A1（审计）：pin 缺席时，从项目目录过闸门的一次调用 → 该项目 `state/tmux-calls.log` **恰好 +1 行**；
#      从非项目目录（向上没有 .pi/team）→ 哪里都不写（可见的例外，不是静默丢）。
#
# 红侧（`--break=`）一律用**产品源码的副本**改写，绝不改本树；每条只让对应的规则失效：
#   strip  摘身份的规则失效（strip 变空操作）→ ① 红（全局环境与 B 的 pane 都拿到身份）
#   log    去掉 A1 的日志目标 fallback       → ④ 红（+1 行不成立）；③ 的 allowed-owned 记录也不落盘
#   kill   连 kill 类也摘身份                → ③ 红（闸门失去身份 → refused；真身看不见身份）
#   e      去掉会话作用域的 -e               → ② 红（人手窗口里 0 个身份）
#   path   把「真 tmux 的位置按调用环境解析」退回写死 /usr/bin:/bin → ⓪ 红（门禁镜像里 tmux 在
#          /usr/local/bin；宿主上 tmux 就在 /usr/bin，所以宿主上它照样绿 —— 证据必须在门禁环境里取）
#
# 纪律：先做身份隔离（清掉继承的 TEAM_*/TMUX*），一切产物落 tmp_root_create 的私有根；**私有 socket**，
# 真 server 只用 stub 替身接触（TEAM_TMUX_REAL）；反向守卫只看「有没有带本夹具 cwd 的行写进真项目的
# state」（活着的 PM 每拍都在写别的车道，那不是夹具的事）。
# 环境的布局**不许假设**（P274 返修轮次 1，V48）：真 tmux 的位置在文件头用 `command -v tmux` 解析，解析
# 到的**目录**接进三处 PATH（shim 目录仍按场景显式加）；解析不到 → **具名跳过（exit 77，不是通过）**；
# 解析到但不可用（`tmux -V` 失败）→ 逐段可见跳过 + 收口行写明跳过（同样 rc=77 —— 跳过不是通过）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

SELECT=""; BREAK=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)      SELECT="write-side,session-scope,kill-identity,audit"; shift ;;
    --select)   [ $# -ge 2 ] || { printf 'tmux-identity-leak: --select 需要键\n' >&2; exit 2; }; SELECT="$2"; shift 2 ;;
    --select=*) SELECT="${1#*=}"; shift ;;
    --break=*)  BREAK="${1#*=}"; shift ;;
    --keep)     KEEP=1; shift ;;
    -h|--help)  awk 'NR > 1 && /^set -uo pipefail/ { exit } NR > 1' "$0"; exit 0 ;;
    *) printf 'tmux-identity-leak: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$SELECT" ] || { printf 'tmux-identity-leak: 需要 --all 或 --select <keys>\n' >&2; exit 2; }
case "$BREAK" in
  ''|strip|log|kill|e|path) ;;
  *) printf 'tmux-identity-leak: --break 只认 strip|log|kill|e|path（收到 %s）\n' "$BREAK" >&2; exit 2 ;;
esac
case ",$SELECT," in
  *,write-side,*|*,session-scope,*|*,kill-identity,*|*,audit,*) ;;
  *) printf 'tmux-identity-leak: --select 只认 write-side|session-scope|kill-identity|audit（收到 %s）\n' "$SELECT" >&2; exit 2 ;;
esac
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

# ── 身份隔离：绝不继承调用者的团队/tmux 身份（同 signal-gate 的口径）────────────────────────────
for _v in $(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p'); do
  case "$_v" in TEAM_TMP_KEEP|TEAM_TMP_RUN_ID|TEAM_TMP_LEDGER) ;; *) unset "$_v" ;; esac
done
unset TMUX TMUX_PANE TMUX_TMPDIR 2>/dev/null || true
# PATH 里的闸门目录也属于「调用者身份」：夹具本身必须解析到**真** tmux，shim 只按场景显式加进去。
# （P274 实测：两个 shim 目录同时在 PATH 上时，闸门把另一个 shim 当真 tmux 反复自 exec —— 那是调用者
# 环境的形状问题，不是产品缺陷；夹具因此自己保证「同一时刻只有一个 shim 目录」。）
_p=""; _ifs="$IFS"; IFS=:
for _d in $PATH; do case "$_d" in */scripts/shim) ;; *) _p="${_p:+$_p:}$_d" ;; esac; done
IFS="$_ifs"; PATH="$_p"; export PATH; unset _p _ifs _d

# ── 真 tmux 的位置：**解析**出来，不假设 PATH 布局（宿主 /usr/bin；门禁镜像 /usr/local/bin）────────────
# V48 的返修点：写死 /usr/bin:/bin 的版本在门禁镜像里解析不到 tmux → 闸门 exit 127 → 之后所有身份读数都
# 取自一个坏掉的 harness。这里解析到的**目录**接进下面三处 PATH；解析不到 → 具名跳过（rc=77）。
REAL_TMUX="$(command -v tmux 2>/dev/null || true)"
TMUX_DIR=""
[ -n "$REAL_TMUX" ] && TMUX_DIR="$(cd -P "$(dirname "$REAL_TMUX")" 2>/dev/null && pwd)"
case "${TMUX_DIR:-}" in
  ''|/usr/bin|/bin) BASE_PATH="/usr/bin:/bin" ;;        # 真身在系统目录里：基线保持原样，不写重复项
  *)                BASE_PATH="$TMUX_DIR:/usr/bin:/bin" ;;
esac
if [ -z "$REAL_TMUX" ]; then
  printf '== tmux-identity-leak 跳过 ==  PATH 里解析不到 tmux（PATH=%s）—— 具名跳过，不是通过（rc=77）\n' "$PATH" >&2
  exit 77
fi

TMP="$(tmp_root_create tmux-identity-leak)" || exit 3
PASS=0; FAIL=0; FAILED=""
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); FAILED="${FAILED:+$FAILED, }$1"; }
hdr() { printf '\n== %s ==\n' "$1"; }
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { grep -qF -- "$3" "$2" 2>/dev/null && ok "$1" || bad "$1（$2 里找不到 [$3]）"; }
assert_not() { grep -qF -- "$3" "$2" 2>/dev/null && bad "$1（不该出现 [$3]）" || ok "$1"; }
selects() { case ",$SELECT," in *",$1,"*) return 0 ;; esac; return 1; }

# ── 反向守卫（只看夹具 cwd）：真项目 state 里不许出现带本夹具根的日志行 ─────────────────────────
REAL_LOG="$REPO_ROOT/.pi/team/state/tmux-calls.log"

# ── 产品源码副本（只有 --break 时才存在；红侧绝不改本树）─────────────────────────────────────
PROD="$SKILL_DIR"
if [ -n "$BREAK" ]; then
  PROD="$TMP/prod"
  cp -a "$SKILL_DIR" "$PROD" || { printf 'tmux-identity-leak: 复制产品源码失败\n' >&2; exit 3; }
  case "$BREAK" in
    # 后定义覆盖先定义（common.sh 整份 source 完才用），所以每处红侧都只是**追加**或定点改写一行。
    strip) printf '\nteam_tmux_strip_identity() { :; }\n' >> "$PROD/scripts/lib/common.sh" ;;
    kill)  printf '\nteam_tmux() { ( team_tmux_strip_identity; command tmux "$@" ); }\n' >> "$PROD/scripts/lib/common.sh" ;;
    e)     cat >> "$PROD/scripts/lib/common.sh" <<'BREAKEOF'

team_tmux_ensure_session() {
  team_assert_own_session "建 tmux session" || return 1
  team_tmux_has_session "$TEAM_SESSION" && return 0
  team_tmux new-session -d -s "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" 2>/dev/null || true
}
BREAKEOF
      ;;
    log)   sed -i 's|^  TEAM_TMUX_CALLS_LOG="\$(_shim_resolve_log.*|  :|' "$PROD/scripts/shim/tmux" ;;
  esac
fi
# --break=path（红侧 5）：把返修点退回写死 /usr/bin:/bin —— 宿主上 tmux 就在 /usr/bin（照样绿），门禁
# 镜像里 tmux 在 /usr/local/bin（⓪ 红并点名）。红侧的现场必须在门禁环境里取（V48）。
[ "$BREAK" = "path" ] && BASE_PATH="/usr/bin:/bin"
SHIM_PATH="$PROD/scripts/shim:$BASE_PATH"

# ── 夹具骨架：A/B 两个 git 项目、一个没有 .pi/team 的目录、私有 socket 岛、stub 真身 ─────────────
A="$TMP/leakA"; B="$TMP/leakB"; NOTPROJ="$TMP/notproj"
ISL="$TMP/island"; ISL_REF="$TMP/island-ref"; ISL_RO="$TMP/island-ro"
mkdir -p "$A" "$B" "$NOTPROJ" "$ISL" "$ISL_REF" "$ISL_RO"
for d in "$A" "$B"; do
  ( cd "$d" && git init -q -b main . && git config user.email fixture@example.invalid && git config user.name fixture \
      && printf 'fixture\n' > README.md && git add -A && git commit -qm init ) || { printf 'tmux-identity-leak: 建夹具项目失败\n' >&2; exit 3; }
done
SESS="leak-$BASHPID"
STUB="$TMP/stub-tmux"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
# 闸门「真身」替身：记调用 + 记下自己被 exec 时看见的身份；绝不碰真 tmux/server。
{ printf 'argv=%s\n' "$*"; printf 'cwd=%s\n' "$PWD"; env | grep '^TEAM_' | sort | sed 's/^/env /'; printf -- '--\n'; } \
  >> "${STUB_LOG:-/dev/null}" 2>/dev/null
case "${1:-}" in
  list-windows) [ -n "${STUB_WINDOWS:-}" ] && printf '%s\n' "$STUB_WINDOWS" ;;
esac
exit 0
STUBEOF
chmod +x "$STUB"
# 真身的**第二条路**（不靠 TEAM_TMUX_REAL）：闸门取 PATH 里第一个「不是我自己」的 tmux。窗口里
# 产品的只读调用会被包装摘掉 TEAM_TMUX_REAL，所以 fixture 把 stub 摆成 PATH 上的第二个 tmux，
# 让**所有**动词（含包装摘身份的只读词）都落到 stub —— 真 tmux / 真 server 一次都不碰。
FAKEBIN="$TMP/fakebin"; mkdir -p "$FAKEBIN"; cp "$STUB" "$FAKEBIN/tmux"; chmod +x "$FAKEBIN/tmux"
KILL_PATH="$PROD/scripts/shim:$FAKEBIN:$BASE_PATH"
# 真 tmux 只在**私有 socket 岛**上被夹具直接调用（从不带身份启动：夹具环境里没有 TEAM_*）
# 真 tmux 走**变量**（M41 规则：变更命令不许写字面绝对路径 —— 闸门是 PATH 里的一格，绝对路径绕过它）。
# 真身（$REAL_TMUX）与 $BASE_PATH 都在文件头解析；PATH 里的 shim 目录也在那里剥掉了，所以解析到的就是
# 真身（不在这里解析第二遍 —— 免得两处漂移出「一处按环境、一处写死」）。
lt()  { timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL"     "$REAL_TMUX" "$@" 2>/dev/null; }
ltr() { timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL_REF" "$REAL_TMUX" "$@" 2>/dev/null; }
pane_env_count() { # <socket-invoker> <session> → pane 里 TEAM_* 条数（读不到 → -1）
  local pid; pid="$($1 list-panes -t "$2" -F '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$pid" ] || { printf '%s' "-1"; return 0; }
  tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -c '^TEAM_'
}
team() { ( cd "$1" && shift && env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL" PATH="$SHIM_PATH" \
    TEAM_TMUX_REAL="$REAL_TMUX" TEAM_ROOT="$A" TEAM_MAIN_ROOT="$A" TEAM_PROJECT=leakA TEAM_SESSION="$SESS" \
    TEAM_TMUX_CALLS_LOG="$A/.pi/team/state/tmux-calls.log" \
    TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD="$TMP/stub-pm.sh" TEAM_PM_BIN="$TMP/stub-pm.sh" \
    timeout 90 bash "$PROD/scripts/team" "$@" ); }
HAVE_TMUX=0
if timeout 5 "$REAL_TMUX" -V >/dev/null 2>&1; then HAVE_TMUX=1; fi
SKIP_N=0
cond_skip() { SKIP_N=$((SKIP_N + 1)); printf '  \033[2m·\033[0m %s（%s）\n' "$1" "$2"; }

# ── ⓪ 前提（返修点的判据）：夹具交给闸门的 PATH 必须让**闸门自己**解析到真 tmux ─────────────────────
# 闸门（shim）取 PATH 里第一个「不是我自己」的 tmux 当真身；夹具的 PATH 若假设了布局（写死 /usr/bin:/bin），
# 门禁镜像里闸门就 `exit 127`（V48 实测），之后所有身份读数都取自一个坏掉的 harness。这条**前置**让那种局
# 面被点名，而不是塌成一堆「没有 session」的下游红。
if [ "$HAVE_TMUX" = "1" ]; then
  shim_probe_rc=0
  shim_probe_out="$( cd "$TMP" && timeout 10 env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR PATH="$SHIM_PATH" \
                      "$PROD/scripts/shim/tmux" -V 2>&1 )" || shim_probe_rc=$?
  if [ "$shim_probe_rc" -eq 0 ]; then
    ok "⓪ 夹具给的 PATH 让闸门解析到真 tmux（$REAL_TMUX）并执行成功 —— $(printf '%s' "$shim_probe_out" | head -1)"
  else
    bad "⓪ 夹具给的 PATH 让闸门解析不到真 tmux（rc=$shim_probe_rc）—— 后面身份读数的 harness 是坏的：$(printf '%s' "$shim_probe_out" | head -1)"
  fi
else
  cond_skip "⓪ 闸门 PATH 前提" "tmux 解析到了但不可用（$REAL_TMUX -V 失败）"
fi

# 舞台只有**一份**构造路径：夹具项目 init + 私有 socket 上的 session/window。任何一段被单独
# `--select` 时都自己把舞台搭起来，不依赖别的段先跑过（否则 `--select kill-identity` 会假红）。
STAGE_READY=0
ensure_stage() { # → 1 = 没有 tmux；2 = init 失败
  [ "$HAVE_TMUX" = "1" ] || return 1
  [ "$STAGE_READY" = "1" ] && return 0
  cat > "$TMP/stub-pm.sh" <<'PMEOF'
#!/usr/bin/env bash
printf 'stub-pm pid=%s\n' "$BASHPID"; sleep 600
PMEOF
  chmod +x "$TMP/stub-pm.sh"
  ( cd "$A" && env PATH="$SHIM_PATH" bash "$PROD/scripts/team" init --session "$SESS" --agents "dev verify" \
      --vcs local --gates "true" --docs docs/team \
      --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
      --pm-model 'deepseek/deepseek-flash' >"$TMP/init.log" 2>&1 ) || return 2
  # 「泄漏形状」：调用者环境里带身份四件套 + 闸门钉桩（真实窗口/套件里就是这个形状）
  team "$A" up >"$TMP/up.log" 2>&1
  printf '%s' "$?" > "$TMP/up.rc"
  STAGE_READY=1
  return 0
}

# ── ① 写侧 ────────────────────────────────────────────────────────────────────────────────────
if selects write-side; then
  hdr "① 写侧：建对象调用不许把 TEAM_* 写进 server 全局环境"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "① 写侧" "没有 tmux"
  else
    ensure_stage; stage_rc=$?
    assert_eq "①a 夹具项目 init 成功" "$stage_rc" "0"
    assert_eq "①b 泄漏形状下 team up 跑完" "$(cat "$TMP/up.rc" 2>/dev/null)" "0"
    global_n="$(lt show-environment -g 2>/dev/null | grep -c '^TEAM_')"
    assert_eq "①c server 全局环境里本项目 TEAM_* 条数" "$global_n" "0"
    lt show-environment -g 2>/dev/null | grep '^TEAM_' | sed 's/^/       ↑ 泄漏：/'
    ( cd "$B" && timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL" "$REAL_TMUX" new-session -d -s leakB 'sleep 300' )
    assert_eq "①d 同一 server 上项目 B 的 pane 里 TEAM_* 条数" "$(pane_env_count lt leakB)" "0"
    # 负对照：旧形状（身份留在环境里直接起 server）—— 判据必须看得见它
    ( cd "$A" && timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL_REF" \
        TEAM_ROOT="$A" TEAM_MAIN_ROOT="$A" TEAM_PROJECT=leakA TEAM_SESSION="$SESS" \
        "$REAL_TMUX" new-session -d -s refA 'sleep 300' )
    ( cd "$B" && timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL_REF" "$REAL_TMUX" new-session -d -s refB 'sleep 300' )
    ref_n="$(pane_env_count ltr refB)"
    if [ "$ref_n" -gt 0 ] 2>/dev/null; then
      ok "①e 负对照：身份直接起 server 时项目 B 的 pane 确实拿到 $ref_n 个 TEAM_*（判据看得见泄漏）"
    else
      bad "①e 负对照没看见泄漏（refB pane TEAM_*=$ref_n）—— 判据坏了，①c/①d 的绿不算数"
    fi
    # ①f：「只给可能启动 server 的动词摘身份」这条规则的依据 —— 空 socket 上只读动词不留 socket。
    ro_rc=0
    ( cd "$A" && timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL_RO" "$REAL_TMUX" list-windows -t nobody ) >/dev/null 2>&1 || ro_rc=$?
    ro_sock="$ISL_RO/tmux-$(id -u)/default"
    if [ "$ro_rc" -ne 0 ] && [ ! -e "$ro_sock" ]; then
      ok "①f 只读动词在空 socket 上失败且**不留 socket**（没有 server 就没有可泄漏的全局环境）"
    else
      bad "①f 只读动词在空 socket 上留下了 server（rc=$ro_rc，socket=$([ -e "$ro_sock" ] && echo 在 || echo 无)）——「只读动词保留身份」的依据不成立"
    fi
  fi
fi

# ── ② 会话作用域（裁定点 B）────────────────────────────────────────────────────────────────────
if selects session-scope; then
  hdr "② 会话作用域：new-session -e 让本项目会话里的人手窗口带身份，而全局环境仍然干净"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "② 会话作用域" "没有 tmux"
  else
    ensure_stage || bad "② 舞台没搭起来（init 失败）"
    sess_n="$(lt show-environment -t "$SESS" 2>/dev/null | grep -c '^TEAM_')"
    assert_eq "②a 本项目会话作用域里的 TEAM_* 条数" "$sess_n" "4"
    for k in TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION; do
      v="$(lt show-environment -t "$SESS" 2>/dev/null | sed -n "s/^$k=//p")"
      case "$k" in
        TEAM_ROOT|TEAM_MAIN_ROOT) assert_eq "②a $k 写在会话作用域里" "$v" "$A" ;;
        TEAM_PROJECT)             assert_eq "②a $k 写在会话作用域里" "$v" "leakA" ;;
        TEAM_SESSION)             assert_eq "②a $k 写在会话作用域里" "$v" "$SESS" ;;
      esac
    done
    cat > "$TMP/win-env.sh" <<'WINEOF'
#!/usr/bin/env bash
{ printf 'cwd=%s\n' "$PWD"; printf 'PATH_head=%s\n' "$(printf '%s' "$PATH" | cut -d: -f1)"; \
  printf 'count=%s\n' "$(env | grep -c '^TEAM_')"; env | grep '^TEAM_' | sort; } > "$WINLOG" 2>&1
printf 'done\n' > "$WINLOG.done"
WINEOF
    chmod +x "$TMP/win-env.sh"
    rm -f "$TMP/win-env.log" "$TMP/win-env.log.done"
    # 人手新开窗口 = 由 **server** 起进程（不是夹具自己 fork）——身份只能来自会话作用域
    lt new-window -t "$SESS" -n hand -- env PATH="$BASE_PATH" WINLOG="$TMP/win-env.log" bash "$TMP/win-env.sh"
    _i=0; while [ "$_i" -lt 80 ] && [ ! -f "$TMP/win-env.log.done" ]; do sleep 0.1; _i=$((_i + 1)); done
    if [ -f "$TMP/win-env.log" ]; then
      hand_n="$(sed -n 's/^count=//p' "$TMP/win-env.log")"
      assert_eq "②b 本项目会话里人手新开的窗口拿到的 TEAM_* 条数" "$hand_n" "4"
      assert_has "②b 该窗口拿到的是本项目的会话身份" "$TMP/win-env.log" "TEAM_SESSION=$SESS"
      sed 's/^/       /' "$TMP/win-env.log"
    else
      bad "②b 人手窗口的 env 没落盘（窗口没起来）"
    fi
    assert_eq "②c 人手窗口起来之后 server 全局环境仍然干净（TEAM_* 条数）" \
      "$(lt show-environment -g 2>/dev/null | grep -c '^TEAM_')" "0"
  fi
fi

# ── ③ 不许削弱：kill 类保留身份（闸门 allowed-owned）──────────────────────────────────────────
if selects kill-identity; then
  hdr "③ 不许削弱：窗口里走产品破坏性路径 → act=allowed-owned，且被 exec 的真身看得见身份"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "③ 不许削弱" "没有 tmux"
  else
    ensure_stage || bad "③ 舞台没搭起来（init 失败）"
    printf 'window=ghost\n' > "$A/.pi/team/state/ghost.env"
    : > "$TMP/stub-kill.log"
    GATELOG="$A/.pi/team/state/tmux-calls.log"
    before="$( [ -f "$GATELOG" ] && wc -l < "$GATELOG" || printf '0')"
    cat > "$TMP/win-kill.sh" <<WINEOF
#!/usr/bin/env bash
cd "$A" || exit 1
STUB_LOG="$TMP/stub-kill.log" STUB_WINDOWS=ghost \\
  env -u TMUX -u TMUX_PANE -u TMUX_TMPDIR PATH="$KILL_PATH" \\
  bash "$PROD/scripts/team" teardown --agent ghost --yes >"$TMP/win-kill.out" 2>&1
printf 'rc=%s\n' "\$?" >> "$TMP/win-kill.out"
printf 'done\n' > "$TMP/win-kill.done"
WINEOF
    chmod +x "$TMP/win-kill.sh"
    rm -f "$TMP/win-kill.out" "$TMP/win-kill.done"
    lt new-window -t "$SESS" -n killprobe -- bash "$TMP/win-kill.sh"
    # 等**完成标记**，不等输出文件：重定向目标由 shell 立即创建，等它就等于没等
    # （P274 实测：夹具提前 kill-server，把还在跑的 payload 连同它的现场一起干掉，三条断言假红）。
    _i=0; while [ "$_i" -lt 120 ] && [ ! -f "$TMP/win-kill.done" ]; do sleep 0.1; _i=$((_i + 1)); done
    # 闸门判定：这是**默认 socket 形状**（payload 里 -u TMUX_TMPDIR），但真身是 stub → 真 server 没碰
    if grep -qF "argv=kill-window -t $SESS:ghost" "$GATELOG" 2>/dev/null; then
      if grep -F "argv=kill-window -t $SESS:ghost" "$GATELOG" | grep -qF 'act=allowed-owned'; then
        ok "③a 窗口里产品自己的 kill-window 记成 act=allowed-owned（身份从会话作用域来）"
      else
        bad "③a 闸门没放行本项目自己的 kill-window（$(grep -F "argv=kill-window -t $SESS:ghost" "$GATELOG" | tail -1)）"
      fi
    else
      bad "③a 闸门日志里没有 kill-window 记录（kill 类被摘了身份，或 window 没跑到）"
      tail -3 "$TMP/win-kill.out" 2>/dev/null | sed 's/^/       /'
    fi
    assert_not "③b 闸门没有把它判成拒绝（refused 不出现在这条调用上）" \
      <(grep -F "argv=kill-window -t $SESS:ghost" "$GATELOG" 2>/dev/null) 'act=refused'
    if [ -f "$TMP/stub-kill.log" ]; then
      assert_has "③c 被 exec 的真身（stub）看得见 TEAM_SESSION —— kill 类保留身份" "$TMP/stub-kill.log" "env TEAM_SESSION=$SESS"
      assert_has "③d 被 exec 的真身看得见 TEAM_ROOT（身份完整，不是只留一个名字）" "$TMP/stub-kill.log" "env TEAM_ROOT=$A"
    else
      bad "③c 真身 stub 没被调用（破坏性路径没走过闸门）"
    fi
    after="$( [ -f "$GATELOG" ] && wc -l < "$GATELOG" || printf '0')"
    [ "$after" -gt "$before" ] && ok "③e 这次调用在闸门日志里留了痕（$before → $after 行）" \
      || bad "③e 这次调用没在闸门日志里留痕（$before → $after 行）"
    # ③f：既有契约（§31c ⑫）的独立实例 —— CLI 的**只读** tmux 子进程也看得见身份。
    # 摘身份的集合如果收了只读动词，这条就红（P274 第一版就是这样把 §31c ⑪/⑫ 四条弄红的）。
    if [ -f "$TMP/stub-kill.log" ]; then
      assert_has "③f 只读调用（list-windows）的真身也看得见 TEAM_SESSION（⑫ 的契约）" \
        <(sed -n '/^argv=list-windows/,/^--$/p' "$TMP/stub-kill.log") "env TEAM_SESSION=$SESS"
      assert_has "③f 也只读调用那一次（同一个真身看得到的还有 TEAM_ROOT）" \
        <(sed -n '/^argv=list-windows/,/^--$/p' "$TMP/stub-kill.log") "env TEAM_ROOT=$A"
    fi
  fi
fi

# ── ④ C/A1 审计：pin 缺席时的日志目标 ────────────────────────────────────────────────────────
if selects audit; then
  hdr "④ C/A1：pin 缺席时日志目标 = cwd 所属项目；非项目目录哪里都不写"
  GATELOG="$A/.pi/team/state/tmux-calls.log"
  mkdir -p "$(dirname "$GATELOG")"
  before="$( [ -f "$GATELOG" ] && wc -l < "$GATELOG" || printf '0')"
  ( cd "$A" && timeout 15 env -u TMUX -u TMUX_PANE -u TEAM_TMUX_CALLS_LOG -u TMUX_TMPDIR \
      PATH="$SHIM_PATH" TEAM_TMUX_REAL="$STUB" STUB_LOG="$TMP/stub-audit.log" \
      tmux list-windows -t audit-probe ) >/dev/null 2>&1
  after="$( [ -f "$GATELOG" ] && wc -l < "$GATELOG" || printf '0')"
  assert_eq "④a 项目目录里的一次过闸门调用：本项目日志恰好 +1 行" "$((after - before))" "1"
  if [ "$after" -gt "$before" ]; then
    assert_has "④a 新增的那一行按 cwd 归到本项目" "$GATELOG" "cwd=$A"
    assert_has "④a 新增的那一行确实是这次调用" "$GATELOG" "argv=list-windows -t audit-probe"
  fi
  before2="$after"
  ( cd "$NOTPROJ" && timeout 15 env -u TMUX -u TMUX_PANE -u TEAM_TMUX_CALLS_LOG -u TMUX_TMPDIR \
      PATH="$SHIM_PATH" TEAM_TMUX_REAL="$STUB" STUB_LOG="$TMP/stub-audit2.log" \
      tmux list-windows -t audit-probe ) >/dev/null 2>&1
  after2="$( [ -f "$GATELOG" ] && wc -l < "$GATELOG" || printf '0')"
  assert_eq "④b 非项目目录里的同一次调用：不写进本项目日志" "$((after2 - before2))" "0"
  assert_eq "④b 也不在非项目目录里凭空建 .pi（可见的例外）" "$( [ -e "$NOTPROJ/.pi" ] && echo yes || echo no)" "no"
  assert_has "④c 真身照旧被调用（不写日志不等于不执行）" "$TMP/stub-audit2.log" "argv=list-windows -t audit-probe"
fi

# ── 反向守卫 + 收尾 ──────────────────────────────────────────────────────────────────────────
if [ -n "$FAILED" ]; then printf '\n  失败项：%s\n' "$FAILED"; fi
if [ -f "$REAL_LOG" ] && grep -qF "cwd=$TMP" "$REAL_LOG" 2>/dev/null; then
  bad "反向守卫：真项目的闸门日志里出现了带本夹具 cwd 的行（夹具漏钉了日志目标）"
  grep -F "cwd=$TMP" "$REAL_LOG" | tail -2 | sed 's/^/       /'
elif [ -f "$REAL_LOG" ]; then
  ok "反向守卫：真项目闸门日志里没有带本夹具 cwd 的行"
fi
if [ "$HAVE_TMUX" = "1" ]; then
  lt kill-server 2>/dev/null || true
  ltr kill-server 2>/dev/null || true
  timeout 15 env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$ISL_RO" "$REAL_TMUX" kill-server 2>/dev/null || true
fi
tmp_root_reap_all 2>/dev/null || true

printf '\n\033[1m== tmux-identity-leak 结果 ==\033[0m  ✓ %d  ✗ %d' "$PASS" "$FAIL"
[ "$SKIP_N" -gt 0 ] && printf ' · 跳过 %d 段' "$SKIP_N"
printf '\n'
if [ "$PASS" -eq 0 ] && [ "$FAIL" -eq 0 ]; then
  printf '\033[33m跳过不是通过\033[0m：tmux 解析到了但不可用（%s -V 失败），本机没有可测的现场（rc=77）\n' "$REAL_TMUX"
  exit 77
fi
[ "$FAIL" -eq 0 ] && exit 0
exit 1
