#!/usr/bin/env bash
# P274 · tmux 身份作用域（change: tmux-identity-scope · apply-1）—— 写侧 / 会话作用域 / 不许削弱 / 审计
#
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --all
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select write-side,residue,guard-kept,doctor
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select write-side   --break=strip   # 红侧 1
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select audit        --break=log     # 红侧 2
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select kill-identity --break=kill   # 红侧 3
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select session-scope --break=e      # 红侧 4
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --all --break=path     # 红侧 5（现场在门禁镜像里）
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select residue     --break=attrib-any  # 红侧 6（读侧）
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select residue     --break=refuse      # 红侧 7（读侧）
#   bash skills/teamsmith/tests/tmux-identity-leak.sh --select doctor      --break=doctor-write # 红侧 8（只读）
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
#   ⑤ 读侧自愈（P304 · `pm-lifecycle#Identity inherited from the shared server's global environment
#      resolves by the working directory`）：把**运行中 server 的全局环境**污染成 A 的身份（沿用设计里的
#      `set-environment -g` 形状），再在 **B 的目录**里带着**恰好那些继承值**（新 session/pane 从全局环境
#      继承，就是这个形状）跑 `team up` → rc=0、stderr 一行点名「运行中的 tmux server 的全局环境」+ 清除
#      命令、建出的是 **B 的对象**（会话作用域里是 B 的四件套）、A 的会话一个窗口都没变、server 全局环境
#      **逐字节未变**（不清共享状态）、调用的继承环境也原样（不改调用者）。
#   ⑥ 守卫保留：同一判据在**不可归因**的现场必须照旧拒绝 —— 全局环境干净时显式继承的外来环境
#      （§32③/§32⑧a 的形状）rc=1 + `身份冲突被拒` + 什么都不建、什么都不清；**半可归因**（三个变量在全局
#      环境里、第四个不在）同样拒绝；真嵌套（继承身份就是 cwd 项目自己的）不打印说明行、不写全局环境。
#   ⑦ doctor 只读残留行（P304 裁定点 E）：运行中 server 全局环境里本项目身份的残留 → 输出点名变量 +
#      清除命令，随后全局环境逐字节未变、项目 `state/` 里一个文件都没多/没变；全局环境干净、或残留是
#      别的项目的 → 不打这一行（不冒充、不误报）。
#
# 红侧（`--break=`）一律用**产品源码的副本**改写，绝不改本树；每条只让对应的规则失效：
#   strip  摘身份的规则失效（strip 变空操作）→ ① 红（全局环境与 B 的 pane 都拿到身份）
#   log    去掉 A1 的日志目标 fallback       → ④ 红（+1 行不成立）；③ 的 allowed-owned 记录也不落盘
#   kill   连 kill 类也摘身份                → ③ 红（闸门失去身份 → refused；真身看不见身份）
#   e      去掉会话作用域的 -e               → ② 红（人手窗口里 0 个身份）
#   path   把「真 tmux 的位置按调用环境解析」退回写死 /usr/bin:/bin → ⓪ 红（门禁镜像里 tmux 在
#          /usr/local/bin；宿主上 tmux 就在 /usr/bin，所以宿主上它照样绿 —— 证据必须在门禁环境里取）
#   attrib-any   归因不看**来源**（只要存在冲突就放行）→ ⑥ 红（显式外来环境被放行、半可归因也被放行）
#   refuse       可归因路径退回「直接拒绝」→ ⑤ 红（自愈不成立，rc=1）
#   doctor-write doctor 那行不再是只读（写共享 server 全局环境 + 写项目 state）→ ⑦ 红（只读断言）
#
# 纪律：先做身份隔离（清掉继承的 TEAM_*/TMUX*），一切产物落 tmp_root_create 的私有根；**私有 socket**，
# 真 server 只用 stub 替身接触（TEAM_TMUX_REAL）；反向守卫只看「有没有带本夹具 cwd 的行写进真项目的
# state」（活着的 PM 每拍都在写别的车道，那不是夹具的事）。
# 环境的布局**不许假设**（P274 返修轮次 1，V48）：真 tmux 的位置在文件头用 `command -v tmux` 解析，解析
# 到的**目录**接进三处 PATH（shim 目录仍按场景显式加）；解析不到 → **具名跳过（exit 77，不是通过）**；
# 解析到但不可用（`tmux -V` 失败）→ 逐段可见跳过 + 收口行写明跳过（同样 rc=77 —— 跳过不是通过）。
#
# 收口判据（P308 · F1′）：**按段数判，不按 PASS 判** —— 「需要 tmux 的段一段都没跑起来」→ rc=77。
# 隔离断言在任何现场都会给 2 个 ✓，所以 `PASS==0 && FAIL==0` 的旧判据在「tmux 坏了、全跳过」的现场
# 永远是假绿（V48 实测 rc=0）。④（审计，stub 就够）不需要 tmux，它跑过**不代表** tmux 身份契约被测过；
# 反过来 `--select audit` 这种合法单跑也不能被误判成跳过。翻转夹具：
#   bash skills/teamsmith/tests/flip-p308-skip-not-pass.sh
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

SELECT=""; BREAK=""; KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all)      SELECT="write-side,session-scope,kill-identity,audit,residue,guard-kept,doctor"; shift ;;
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
  ''|strip|log|kill|e|path|attrib-any|refuse|doctor-write) ;;
  *) printf 'tmux-identity-leak: --break 只认 strip|log|kill|e|path|attrib-any|refuse|doctor-write（收到 %s）\n' "$BREAK" >&2; exit 2 ;;
esac
case ",$SELECT," in
  *,write-side,*|*,session-scope,*|*,kill-identity,*|*,audit,*|*,residue,*|*,guard-kept,*|*,doctor,*) ;;
  *) printf 'tmux-identity-leak: --select 只认 write-side|session-scope|kill-identity|audit|residue|guard-kept|doctor（收到 %s）\n' "$SELECT" >&2; exit 2 ;;
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
# 全局环境的「逐字节未变」断言：失败时只印差异行数与 TEAM_ 条数（整个 environ 有几十行，
# 直接 assert_eq 会把它整份抖进日志 —— 红侧的证据应该指名到点，不是把屏幕淹掉）。
assert_env_same() { # <标签> <跑之前的 show-environment -g 输出>
  local now; now="$(lt show-environment -g 2>/dev/null)"
  if [ "$now" = "$2" ]; then ok "$1"; return 0; fi
  local nd; nd="$(diff <(printf '%s\n' "$2") <(printf '%s\n' "$now") 2>/dev/null | grep -c '^[<>]' || true)"
  bad "$1（全局环境变了：$nd 行差异，现在 TEAM_ 行 $(printf '%s\n' "$now" | grep -c '^TEAM_' || true) 条）"
}
selects() { case ",$SELECT," in *",$1,"*) return 0 ;; esac; return 1; }

# ── 段数账（P308 · F1′）：收口靠它判「跳过 vs 跑过」，不靠 PASS ─────────────────────────────────
# TMUX_SEL = 本轮**选中**的、需要 tmux 的段数；TMUX_RAN = 其中真正执行了断言的段数。
# ⓪ 是前提探针（不是被测的段），④ 不需要 tmux（stub 就够）—— 两者都不进这两个计数。
TMUX_SEL=0; TMUX_RAN=0
for _k in write-side session-scope kill-identity residue guard-kept doctor; do
  selects "$_k" && TMUX_SEL=$((TMUX_SEL + 1))
done
seg_ran() { TMUX_RAN=$((TMUX_RAN + 1)); }

# ── 反向守卫（只看夹具 cwd）：真项目 state 里不许出现带本夹具根的日志行 ─────────────────────────
REAL_LOG="$REPO_ROOT/.pi/team/state/tmux-calls.log"

# ── 隔离断言（任务书 3.1）：真实仓库的账本面（inbox / state）跑前跑后逐文件 sha256 对比 ──────
# 位置在这一行之前：任何夹具动作都不许在这些面上留痕；泄漏（新建/修改/删除）必红。
# （夹具只在自己的检出里跑 —— 活团队的主检出里 PM/pulse 自己就在写这些文件，那是另一条车道；
#   本 worktree 连 .pi/team/ 都没有时，这条退化成「仍然不存在」，报告里如实写明。）
REAL_INBOX="$REPO_ROOT/docs/team/inbox"; REAL_STATE="$REPO_ROOT/.pi/team/state"
ledger_manifest() { # <目录…> → 每行 "<相对路径>\t<sha256>"；目录不存在 → 无输出
  local d f
  for d in "$@"; do
    [ -d "$d" ] || continue
    while IFS= read -r -d '' f; do
      printf '%s\t%s\n' "${f#"$REPO_ROOT"/}" "$(sha256sum "$f" 2>/dev/null | awk '{print $1}')"
    done < <(find "$d" -type f -print0 2>/dev/null | LC_ALL=C sort -z)
  done
}
LEDGER_BEFORE="$(ledger_manifest "$REAL_INBOX" "$REAL_STATE")"
LEDGER_N=$(printf '%s' "$LEDGER_BEFORE" | grep -c . || true)
ROOTS_BEFORE="$(ls -d "$(tmp_root_base)"/teamsmith-tmux-identity-leak-* 2>/dev/null | wc -l | tr -d ' ')"

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
    # P304 读侧三条红侧：每条只让一条规则失效（产品源码副本上追加覆盖定义，本树不动）。
    attrib-any) printf '\nteam_identity_server_residue() { local p; p="$(team_identity_conflict_pairs)"; [ -n "$p" ]; }\n' >> "$PROD/scripts/lib/common.sh" ;;
    refuse)     printf '\nteam_identity_server_residue() { return 1; }\n' >> "$PROD/scripts/lib/common.sh" ;;
    doctor-write) cat >> "$PROD/scripts/lib/common.sh" <<'BREAKEOF'

team_identity_server_residue_vars() {
  # 红侧 8（翻转）：报告**照旧打印**（读数与正式实现同源），但这一行不再是只读 —— 写盘 + 清共享 server
  # 全局环境。⑦b（全局环境逐字节未变）与 ⑦c（state 里不多文件）必须因此变红。
  local var val out=""
  for var in TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION; do
    val="$(team_identity_server_global_value "$var")" || continue
    team_identity_value_is_ours "$var" "$val" || continue
    out="${out}${out:+$'\n'}$var=$val"
  done
  [ -n "$out" ] && printf '%s\n' "$out"
  mkdir -p "${TEAM_STATE_DIR:-/dev/null}" 2>/dev/null || true
  printf '%s\n' "$(date -Is) residue" >> "${TEAM_STATE_DIR:-/dev/null}/tmux-identity-residue.break" 2>/dev/null || true
  team_tmux set-environment -gu TEAM_ROOT \; set-environment -gu TEAM_MAIN_ROOT \; set-environment -gu TEAM_PROJECT \; set-environment -gu TEAM_SESSION 2>/dev/null || true
  return 0
}
BREAKEOF
      ;;
  esac
fi
# --break=path（红侧 5）：把返修点退回写死 /usr/bin:/bin —— 宿主上 tmux 就在 /usr/bin（照样绿），门禁
# 镜像里 tmux 在 /usr/local/bin（⓪ 红并点名）。红侧的现场必须在门禁环境里取（V48）。
[ "$BREAK" = "path" ] && BASE_PATH="/usr/bin:/bin"
SHIM_PATH="$PROD/scripts/shim:$BASE_PATH"

# ── 夹具骨架：A/B 两个 git 项目、一个没有 .pi/team 的目录、私有 socket 岛、stub 真身 ─────────────
A="$TMP/leakA"; B="$TMP/leakB"; NOTPROJ="$TMP/notproj"
# P309：三条私有岛是 tmux 的 TMUX_TMPDIR（socket = <岛>/tmux-<uid>/<server>）。临时根搬到
# `/var/tmp/teamsmith-<ns>` 后，挂在 $TMP 下的岛会越过 AF_UNIX 的 107 字节 —— 岛的位置改由
# `tmp_root_socket_dir` 给（先试解析出的根、放不下退系统临时目录），仍然是本轮自建、只装本轮 socket。
# 岛**不是**本段的「自有根」判据对象（那是 $TMP）；这里只用它的 socket。
ISL_BASE="$(tmp_root_socket_dir tml-island "tmux-$(id -u)/default")" || ISL_BASE="$TMP"
ISL="$ISL_BASE/island"; ISL_REF="$ISL_BASE/island-ref"; ISL_RO="$ISL_BASE/island-ro"
mkdir -p "$A" "$B" "$NOTPROJ" "$ISL" "$ISL_REF" "$ISL_RO"
for d in "$A" "$B"; do
  ( cd "$d" && git init -q -b main . && git config user.email fixture@example.invalid && git config user.name fixture \
      && printf 'fixture\n' > README.md && git add -A && git commit -qm init ) || { printf 'tmux-identity-leak: 建夹具项目失败\n' >&2; exit 3; }
done
SESS="leak-$BASHPID"
SESS_B="leakB-$BASHPID"
SESS_C="leakC-$BASHPID"
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
HAVE_TMUX=0; TMUX_WHY="没有 tmux"
if timeout 5 "$REAL_TMUX" -V >/dev/null 2>&1; then HAVE_TMUX=1
else TMUX_WHY="tmux 解析到了但不可用（$REAL_TMUX -V 失败）"; fi
# P304 · 环境前提（与产品的 tmux-iso-guard 同一条判据）：私有 socket 岛的路要装得进 AF_UNIX 的
# sun_path（Linux：108 字节含结尾 NUL → 上限 107）。TMPDIR 太深时 tmux 绑不上 socket，各腿会变成一堆
# 看不懂的红 —— 那是环境欠的账，不是缺陷（D192 的口径）：前提不成立就**可见地跳过**并报出长度。
if [ "$HAVE_TMUX" = "1" ]; then
  SOCK_EG="$ISL/tmux-$(id -u)/default"
  SOCK_LEN="$(printf '%s' "$SOCK_EG" | wc -c | tr -d ' ')"
  if [ "$SOCK_LEN" -gt 107 ]; then
    HAVE_TMUX=0
    TMUX_WHY="私有 socket 路 $SOCK_LEN 字节 > AF_UNIX 上限 107（TMPDIR 太深：$ISL）—— 把 TMPDIR 换浅一点再跑"
    printf '  \033[2m·\033[0m %s\n' "$TMUX_WHY"
  else
    printf '  \033[2m·\033[0m 隔离前提：私有 socket 路 $SOCK_LEN 字节 ≤ 107（能绑）\n'
  fi
fi
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

# B 项目（读侧的「受害者」）：只 init（不起窗口），会话名与 A 不同 —— 残留现场要证明「建出来的是 B 的对象」。
STAGE_B_READY=0
ensure_stage_b() { # → 1 = 没有 tmux；2 = init 失败
  [ "$HAVE_TMUX" = "1" ] || return 1
  [ "$STAGE_B_READY" = "1" ] && return 0
  ( cd "$B" && env PATH="$SHIM_PATH" bash "$PROD/scripts/team" init --session "$SESS_B" --agents "dev verify" \
      --vcs local --gates "true" --docs docs/team \
      --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
      --pm-model 'deepseek/deepseek-flash' >"$TMP/initB.log" 2>&1 ) || return 2
  STAGE_B_READY=1
  return 0
}

# 污染模拟（设计 §2「读侧」的红侧形状）：把**运行中 server 的全局环境**设成给定的身份。改的是夹具自己的
# 私有 server（admin 操作，不经过产品）——「本项目的身份当初是怎么进全局环境的」不由本夹具负责。
# 写（set）与清（unset）都是夹具自己的场地操作，不是产品行为。
res_glob_set() { local kv; for kv in "$@"; do lt set-environment -g "${kv%%=*}" "${kv#*=}" >/dev/null 2>&1 || true; done; }
# tmux 的 set-environment 一次只收一个名字（实测 3.7b：多名字 = too many arguments），所以用 `\;` 命令链
# ——产品给用户渲染的清除命令也是这个形状（人能直接粘）。
res_glob_clear() { lt set-environment -gu TEAM_ROOT \; set-environment -gu TEAM_MAIN_ROOT \; set-environment -gu TEAM_PROJECT \; set-environment -gu TEAM_SESSION >/dev/null 2>&1 || true; }

# 两份清单（"<路径> <大小>"）之间变化的路径（只取第一列，去重）。
changed_paths() { # <before> <after>
  diff <(printf '%s\n' "$1") <(printf '%s\n' "$2") 2>/dev/null \
    | sed -n 's/^[<>][[:space:]]*//p' | awk '{print $1}' | sed '/^$/d' | sort -u
}

# 读侧的 payload：写一段脚本，让它在私有 server 的 pane 里跑 —— **新 session/window 的环境恰好来自
# server 的全局环境**（用户报的就是这个形状：别的项目新开的窗口继承了泄漏值）。脚本把「跑之前的继承环境、
# rc、stdout/stderr、跑之后的环境」分开落盘，pane 里的输出与调用者环境互不干扰。
pane_payload() { # <name> <cwd> <跑 team 时的 PATH> <额外的 export 语句（可空）> <team 子命令…>
  local name="$1" dir="$2" tpath="$3" prefix="$4"; shift 4
  {
    printf '#!/usr/bin/env bash\n'
    printf 'cd %q || exit 1\n' "$dir"
    [ -n "$prefix" ] && printf '%s\n' "$prefix"
    printf 'export TEAM_PI_BIN=/definitely-not-pi TEAM_PM_CMD=%q TEAM_PM_BIN=%q\n' "$TMP/stub-pm.sh" "$TMP/stub-pm.sh"
    printf 'env | grep "^TEAM_" | sort > %q\n' "$TMP/$name.inherit"
    printf 'PATH=%q TEAM_TMUX_REAL=%q bash %q' "$tpath" "$REAL_TMUX" "$PROD/scripts/team"
    printf ' %q' "$@"
    printf ' >%q 2>%q\n' "$TMP/$name.out" "$TMP/$name.err"
    printf 'printf "rc=%%s\\n" "$?" > %q\n' "$TMP/$name.rc"
    printf 'env | grep "^TEAM_" | sort > %q\n' "$TMP/$name.env"
    printf 'printf "done\\n" > %q\n' "$TMP/$name.done"
  } > "$TMP/$name.sh"
  chmod +x "$TMP/$name.sh"
}

# 在私有 server 上的一只 pane 里跑 payload：session 不存在就先开一个新 session（先立一个长驻窗口把
# session 撑住 —— payload 结束不把 session 带走，后面的腿才能在同一个 server 上接着跑）。新 session/window
# 的环境都来自 server 的**全局环境**，这就是要证的那个形状。等的是**完成标记**，不等输出文件
# （重定向目标由 shell 立即创建，等它就等于没等—— P274 实测）。
ensure_pane_session() { # <session>：立一个长驻窗口把 payload session 撑住（payload 结束不把 session 带走）
  lt has-session -t "$1" 2>/dev/null && return 0
  lt new-session -d -s "$1" -n hold 'sleep 600' >/dev/null 2>&1
}

pane_run() { # <目标 session> <name> → 0 = 脚本跑完
  local sess="$1" name="$2" i=0
  rm -f "$TMP/$name.done"
  ensure_pane_session "$sess" || return 1
  lt new-window -t "$sess" -n "$name" -- bash "$TMP/$name.sh" >/dev/null 2>&1 || return 1
  while [ "$i" -lt 300 ] && [ ! -f "$TMP/$name.done" ]; do sleep 0.1; i=$((i + 1)); done
  [ -f "$TMP/$name.done" ]
}

# ── ① 写侧 ────────────────────────────────────────────────────────────────────────────────────
if selects write-side; then
  hdr "① 写侧：建对象调用不许把 TEAM_* 写进 server 全局环境"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "① 写侧" "$TMUX_WHY"
  else
    seg_ran
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
    cond_skip "② 会话作用域" "$TMUX_WHY"
  else
    seg_ran
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
    cond_skip "③ 不许削弱" "$TMUX_WHY"
  else
    seg_ran
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

# ── ⑤ 读侧自愈（P304）────────────────────────────────────────────────────────────────────────────────
if selects residue; then
  hdr "⑤ 读侧自愈：运行中 server 全局环境里的身份残留 → 按 cwd 解析 + stderr 一行 + 不清共享状态"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "⑤ 读侧自愈" "$TMUX_WHY"
  else
    seg_ran
    ensure_stage || bad "⑤ 舞台 A 没搭起来（init 失败）"
    _b_rc=0; ensure_stage_b || _b_rc=$?
    assert_eq "⑤a 夹具项目 B init 成功" "$_b_rc" "0"
    if [ "$_b_rc" = "0" ]; then
      # 残留现场：运行中 server 的全局环境 = A 的身份（A 的会话名也在内）
      res_glob_set "TEAM_ROOT=$A" "TEAM_MAIN_ROOT=$A" "TEAM_PROJECT=leakA" "TEAM_SESSION=$SESS"
      g_before="$(lt show-environment -g 2>/dev/null)"
      a_win_before="$(lt list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | sort)"
      b_sess_before="$(lt has-session -t "$SESS_B" 2>/dev/null && echo yes || echo no)"
      pane_payload resup "$B" "$SHIM_PATH" "" up
      if pane_run "$SESS_C" resup; then
        assert_has "⑤b pane 继承的就是全局环境里那几个值（残留形状成立）" "$TMP/resup.inherit" "TEAM_ROOT=$A"
        assert_eq "⑤c 残留形状下 team up 退出码 0（自愈：不再拒绝）" "$(sed -n 's/^rc=//p' "$TMP/resup.rc")" "0"
        if [ "$b_sess_before" = "no" ]; then
          assert_eq "⑤d 建出来的是 B 的对象（B 的会话出现在同一 server 上）" \
            "$(lt has-session -t "$SESS_B" 2>/dev/null && echo yes || echo no)" "yes"
        fi
        assert_eq "⑤d B 的会话作用域里恰好是四个身份变量" \
          "$(lt show-environment -t "$SESS_B" 2>/dev/null | grep -c '^TEAM_')" "4"
        assert_has "⑤d 会话作用域里的身份就是 B 的" <(lt show-environment -t "$SESS_B" 2>/dev/null) "TEAM_ROOT=$B"
        assert_has "⑤e stderr 一行点名来源：运行中的 tmux server 的全局环境" "$TMP/resup.err" "运行中的 tmux server 的全局环境"
        assert_has "⑤e 这一行给出清除命令（不清，只给路）" "$TMP/resup.err" "set-environment -gu TEAM_ROOT"
        assert_not "⑤e 说明行不进 stdout（机读出口不被弄坏）" "$TMP/resup.out" "运行中的 tmux server 的全局环境"
        assert_eq "⑤f A 的会话一个窗口都没变" \
          "$(lt list-windows -t "$SESS" -F '#{window_name}' 2>/dev/null | sort)" "$a_win_before"
        assert_env_same "⑤g server 全局环境逐字节未变（不清共享状态、也不写它）" "$g_before"
        assert_has "⑤h 调用者的继承环境也原样（没被清）" "$TMP/resup.env" "TEAM_ROOT=$A"
      else
        bad "⑤ 残留现场的 payload 没跑完（窗口没起来或被 kill）"
      fi
      res_glob_clear
    fi
  fi
fi

# ── ⑥ 守卫保留（P304 红侧 3）：不可归因的不许被放行 ─────────────────────────────────────────────
if selects guard-kept; then
  hdr "⑥ 守卫保留：显式外来环境 / 半可归因照旧拒绝；真嵌套不误清"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "⑥ 守卫保留" "$TMUX_WHY"
  else
    seg_ran
    ensure_stage || bad "⑥ 舞台 A 没搭起来（init 失败）"
    _b_rc=0; ensure_stage_b || _b_rc=$?
    assert_eq "⑥a 夹具项目 B init 成功" "$_b_rc" "0"
    if [ "$_b_rc" = "0" ]; then
      res_glob_clear
      ensure_pane_session "$SESS_C" || true
      g_clean="$(lt show-environment -g 2>/dev/null)"
      sess_before="$(lt list-sessions -F '#{session_name}' 2>/dev/null | sort)"
      # ⑥a 显式继承的外来环境，而全局环境里没有这些值 —— §32③/§32⑧a 的形状（TMUX 非空也不许归因）
      pane_payload foreign "$B" "$SHIM_PATH" \
        "$(printf 'export TEAM_ROOT=%q TEAM_MAIN_ROOT=%q TEAM_PROJECT=leakA TEAM_SESSION=%q' "$A" "$A" "$SESS")" up
      if pane_run "$SESS_C" foreign; then
        assert_eq "⑥a 显式外来环境仍被拒（rc=1）" "$(sed -n 's/^rc=//p' "$TMP/foreign.rc")" "1"
        assert_has "⑥a 拒绝措辞与今天同一句" "$TMP/foreign.err" "身份冲突被拒"
        assert_not "⑥a 不可归因就不许自愈（没有残留说明行）" "$TMP/foreign.err" "运行中的 tmux server 的全局环境"
        assert_eq "⑥a 什么都没建（server 会话表未变）" "$(lt list-sessions -F '#{session_name}' 2>/dev/null | sort)" "$sess_before"
        assert_env_same "⑥a 什么都没清（全局环境逐字节未变）" "$g_clean"
        assert_has "⑥a 调用者的继承环境也原样" "$TMP/foreign.env" "TEAM_ROOT=$A"
      else
        bad "⑥a payload 没跑完"
      fi
      # ⑥b 半可归因：三个变量在全局环境里、第四个不在 → 仍然拒绝（「每一个都归因才放行」）
      res_glob_set "TEAM_ROOT=$A" "TEAM_MAIN_ROOT=$A" "TEAM_PROJECT=leakA" "TEAM_SESSION=other-$BASHPID"
      g_half="$(lt show-environment -g 2>/dev/null)"
      pane_payload half "$B" "$SHIM_PATH" "$(printf 'export TEAM_SESSION=%q' "$SESS")" up
      if pane_run "$SESS_C" half; then
        assert_eq "⑥b 半可归因仍被拒（rc=1）" "$(sed -n 's/^rc=//p' "$TMP/half.rc")" "1"
        assert_not "⑥b 没有残留说明行" "$TMP/half.err" "运行中的 tmux server 的全局环境"
        assert_env_same "⑥b 全局环境未变（没清）" "$g_half"
      else
        bad "⑥b payload 没跑完"
      fi
      res_glob_clear
      # ⑥c 真嵌套：继承身份就是 cwd 项目自己的 → 没有分歧、不打印说明行、不写全局环境
      g_nest="$(lt show-environment -g 2>/dev/null)"
      pane_payload nest "$A" "$SHIM_PATH" \
        "$(printf 'export TEAM_ROOT=%q TEAM_MAIN_ROOT=%q TEAM_PROJECT=leakA TEAM_SESSION=%q' "$A" "$A" "$SESS")" up
      if pane_run "$SESS_C" nest; then
        assert_eq "⑥c 真嵌套照常跑（rc=0）" "$(sed -n 's/^rc=//p' "$TMP/nest.rc")" "0"
        assert_not "⑥c 没有分歧就没有说明行" "$TMP/nest.err" "运行中的 tmux server 的全局环境"
        assert_env_same "⑥c 也不写全局环境" "$g_nest"
      else
        bad "⑥c payload 没跑完"
      fi
    fi
  fi
fi

# ── ⑦ doctor 只读残留行（P304 裁定点 E）──────────────────────────────────────────────────────
if selects doctor; then
  hdr "⑦ doctor 只读残留行：点名本项目在 server 全局环境里的残留 + 清除命令，不写盘、不改它"
  if [ "$HAVE_TMUX" != "1" ]; then
    cond_skip "⑦ doctor 残留行" "$TMUX_WHY"
  else
    seg_ran
    ensure_stage || bad "⑦ 舞台 A 没搭起来（init 失败）"
    _b_rc=0; ensure_stage_b || _b_rc=$?
    assert_eq "⑦a 夹具项目 B init 成功" "$_b_rc" "0"
    if [ "$_b_rc" = "0" ]; then
      # 夹具项目没有本机的 pi/magic-context/openspec —— 把 doctor 的「硬失败」降成「警告」，
      # 于是 rc 只反映它自己跑得成不成（残留行是 warn，不是 fail），判据不被环境噪声绑架。
      doc_env="export TEAM_AGENT_CMD=/bin/true TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0 TEAM_REQUIRE_JS=0"
      st_dir="$B/.pi/team/state"
      st_manifest() { find "$st_dir" -type f -printf '%P %s\n' 2>/dev/null | sort; }
      # ⑦a-c 本项目的残留：点名 + 清除命令 + 全局环境逐字节不变 + 项目 state 不写盘
      # 先把 state 目录立起来（存在且可写的真实目标）：产品要是写了，断言必须看得见 —— 目录不存在时
      # 写入会直接失败，那样就成了「因为写不进去所以看不到」的假绿。
      mkdir -p "$st_dir"
      res_glob_set "TEAM_ROOT=$B" "TEAM_MAIN_ROOT=$B" "TEAM_PROJECT=leakB" "TEAM_SESSION=$SESS_B"
      g_before="$(lt show-environment -g 2>/dev/null)"
      st_before="$(st_manifest)"
      # 无闸门的 PATH（人的普通终端形状）：这里的「不写盘」是**产品自己的**行为 —— 闸门不在场，
      # 就没有它的审计行混进来（有闸门的形状是下一腿 ⑦c2）。
      pane_payload doc "$B" "$BASE_PATH" "$doc_env" doctor
      if pane_run "$SESS_C" doc; then
        assert_eq "⑦a doctor 跑得成（rc=0）" "$(sed -n 's/^rc=//p' "$TMP/doc.rc")" "0"
        assert_has "⑦b 点名残留变量 TEAM_ROOT" "$TMP/doc.out" "TEAM_ROOT=$B"
        assert_has "⑦b 也点名会话身份" "$TMP/doc.out" "TEAM_SESSION=$SESS_B"
        assert_has "⑦b 清除命令落在这一行里（set-environment -gu）" "$TMP/doc.out" "set-environment -gu TEAM_ROOT"
        assert_env_same "⑦c 跑完全局环境逐字节未变（只读，不代改）" "$g_before"
        assert_eq "⑦c 项目 state 里一个文件都没多/没变（产品自己不写盘）" "$(st_manifest)" "$st_before"
      else
        bad "⑦a payload 没跑完"
      fi
      # ⑦c2 有闸门的 PATH（窗口的真实现场）：全局环境仍然逐字节未变；state 里如果有变化，只容许
      # **闸门自己的审计行**（tmux-calls.log —— 闸门的规格规定每次过闸门的调用恰好一行，那不是 doctor 写的）。
      st_before2="$(st_manifest)"
      pane_payload doc_gate "$B" "$SHIM_PATH" "$doc_env" doctor
      if pane_run "$SESS_C" doc_gate; then
        assert_env_same "⑦c2 有闸门的形状下全局环境仍逐字节未变" "$g_before"
        changed="$(changed_paths "$st_before2" "$(st_manifest)")"
        if [ -z "$changed" ]; then
          ok "⑦c2 有闸门的形状下 state 也没有任何变化"
        elif [ "$(printf '%s\n' "$changed" | grep -cv '^tmux-calls\.log$' || true)" = "0" ]; then
          ok "⑦c2 有闸门的形状下 state 的唯一变化是闸门自己的审计行（tmux-calls.log），不是 doctor 写的"
        else
          bad "⑦c2 有闸门的形状下 state 里出现了不属于闸门审计的变化：$(printf '%s' "$changed" | tr '\n' ' ')"
        fi
      else
        bad "⑦c2 payload 没跑完"
      fi
      # ⑦d 干净时沉默（干净项目不刷行）
      res_glob_clear
      pane_payload doc_clean "$B" "$BASE_PATH" "$doc_env" doctor
      if pane_run "$SESS_C" doc_clean; then
        assert_not "⑦d 全局环境干净时没有残留行" "$TMP/doc_clean.out" "身份残留"
      else
        bad "⑦d payload 没跑完"
      fi
      # ⑦e 残留是**别的项目**的值 → 不是「本项目的身份变量」，不冒充、不误报
      res_glob_set "TEAM_ROOT=$A" "TEAM_MAIN_ROOT=$A" "TEAM_PROJECT=leakA" "TEAM_SESSION=$SESS"
      pane_payload doc_other "$B" "$BASE_PATH" "$doc_env" doctor
      if pane_run "$SESS_C" doc_other; then
        assert_not "⑦e 别的项目的残留不冒充本项目的" "$TMP/doc_other.out" "本项目的身份残留"
      else
        bad "⑦e payload 没跑完"
      fi
      res_glob_clear
    fi
  fi
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

# ── 隔离断言（任务书 3.1）：真实仓库账本面 hash + 本轮临时根 ─────────────────────────────────
LEDGER_AFTER="$(ledger_manifest "$REAL_INBOX" "$REAL_STATE")"
if [ "$LEDGER_BEFORE" = "$LEDGER_AFTER" ]; then
  ok "隔离：真实仓库账本面未被改动（docs/team/inbox + .pi/team/state，$LEDGER_N 个文件逐一 sha256 相同）"
else
  bad "隔离：真实仓库账本面被改动（夹具漏钉了目标？）—— 差异："
  diff <(printf '%s\n' "$LEDGER_BEFORE") <(printf '%s\n' "$LEDGER_AFTER") 2>/dev/null | sed 's/^/       /' || true
fi
ROOTS_AFTER="$(ls -d "$(tmp_root_base)"/teamsmith-tmux-identity-leak-* 2>/dev/null | wc -l | tr -d ' ')"
if [ "${TEAM_TMP_KEEP:-0}" = "1" ]; then
  ok "隔离：TEAM_TMP_KEEP=1 —— 本轮临时根按约定保留（$TMP）"
elif [ ! -e "$TMP" ]; then
  ok "隔离：本轮的临时根已回收（跑前 ${ROOTS_BEFORE} 个同族根 → 跑后 ${ROOTS_AFTER} 个）"
else
  bad "隔离：本轮的临时根还在（$TMP）—— 跑完不留下"
fi

printf '\n\033[1m== tmux-identity-leak 结果 ==\033[0m  ✓ %d  ✗ %d' "$PASS" "$FAIL"
[ "$SKIP_N" -gt 0 ] && printf ' · 跳过 %d 段' "$SKIP_N"
printf '\n'
# >>> P308 close-out predicate（flip-p308-skip-not-pass.sh 按这两个标记把它换回旧判据）>>>
# 判的是「有没有段真跑过」，不是「有没有 ✓」：隔离断言的两条 ✓ 不算测过身份契约。
if [ "$TMUX_RAN" -eq 0 ] && [ "$TMUX_SEL" -gt 0 ]; then
  printf '\033[33m跳过不是通过\033[0m：需要 tmux 的 %d 段一段都没跑起来（跳过 %d 段；%s），本机没有可测的现场（rc=77）\n' \
    "$TMUX_SEL" "$SKIP_N" "$TMUX_WHY"
  exit 77
fi
# <<< P308 close-out predicate <<<
[ "$FAIL" -eq 0 ] && exit 0
exit 1
