#!/usr/bin/env bash
# P159 · 信号闸门夹具（safe-signal-discipline · RA1/RA2/RM）
#
#   bash skills/teamsmith/tests/signal-gate.sh [--break=pass] [--keep]
#
# 证明什么（每条断言都对着需求里的 scenario）：
#   · 模式/名字选择的**每一种形态**都被拒：exit 64、真身没被执行、诱饵进程都活着、理由里点名
#     `team bg stop`（RA1）；
#   · `TEAM_ALLOW_PATTERN_KILL=1` 这类继承环境**不授权**（RA1 的「An inherited environment grants
#     nothing」）；
#   · 只读四词（--help/-h/-V/--version）原样递给真身并记 act=pass（RA1 的 pass-through）；
#   · `kill <记录过的 pid>` 这条安全路线照旧通，且闸门不为它记行（闸门不拦 kill，RA1 的 pid-exact）；
#   · 记录：一行一调用、拒绝逐字节进 `.forensics`、轮转标记自述、保留写失败可见但不改判定、
#     pass 不保留、FIFO 目标不挂住（RA2）。
#
# P164（signal-gate-pgrep）加上选择器那半（每条新断言都带 `P164` 前缀，红侧点名它）：
#   · 闸门入口：`pgrep`/`pidof` 是同目录里指向 signal-gate 的软链，PATH 最前时解析到闸门；
#   · 按名字/模式/所有者的选择一律拒（`-f`/`--full`/`-fmarker`/`-x`/裸名/`-u`/`-U`/`-G`、`pidof` 的
#     一切选择形态）：exit 64、stdout 空、点明工具 + 完整 argv + 安全路线、选择器桩零调用；
#   · 放行的只有 `-g N` / `-P N`（N 为显式正整数）与三种「整命令计数」（`-fc P`/`-f -c P`/`-c -f P`）
#     加四个只读信息词：argv/stdout/stderr/退出码逐字节来自**同名**真身（旧 `TEAM_SIGNAL_REAL` pin
#     钉在 pkill 见证桩上也不改道）；`0`/负数/前导 0/多值/额外谓词/长别名/融合拼写一律拒；
#   · 计数用例的两种响应（`0`+exit 1 与 `2`+exit 0）都保留，且 pass 不建 `.forensics`；
#   · 不可用的 pin + 继承的环境 token + 子 shell 都不授权；被拒的替换不给 shell 任何 PID
#     （`kill $(pgrep -f …)` 到**只记 argv** 的 kill 函数时零参数）；
#   · 新选择器的拒绝进同一份取证记录（逐字节 `.forensics`、轮转、保留失败仍 64）；
#   · `ps`/`fuser` 不在这道闸门的管理面内（记录桩收到调用，闸门零日志行）。
#
# 红侧（--break=pass）：把闸门副本的判定从 refused 改成 pass（只改那一行），闸门于是执行真身 ——
# 「stub 没被调用」「诱饵活着」这些断言必须变红（P164 的选择器拒绝断言同理：放行 → exit 不再是 64、
# 桩被调用、stdout 非空）。**真身永远是 argv 记录桩**（pkill/killall 走 TEAM_SIGNAL_REAL，pgrep/pidof
# 走闸门之后的同名桩），夹具里不执行真的 pkill/killall/pgrep/pidof；红侧里 pkill 桩按**夹具记录过的
# 诱饵 pid** 收掉诱饵，于是 decoys-alive 也红。
#
# 纪律：清掉继承的团队身份与 tmux 身份；一切产物落 tmp_root_create 的私有根；诱饵/邻居进程由夹具
# spawn、pid 记录在案，收尾**只按记录的 pid** 发信号；真实仓库 state/ 的反向守卫做成**白名单** ——
# 只看「夹具的产品代码可能写到」的那族路径（当前就是闸门自己的日志族 `signal-calls.log*`，逐条从
# 代码列在下面 FIXTURE_WRITE_WATCH 的注释里）；活着的 PM 运行时每拍都在写别的车道（巡检的
# capacity.log 等），那不是夹具的事，**不进判据**（P171 的现场同源）。跑动中写入的各面红侧在
# tests/flip-p171.sh。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

BREAK=""
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --break=*) BREAK="${1#--break=}"; shift ;;
    --keep)    KEEP=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) printf 'signal-gate: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$BREAK" in ''|pass) ;; *) printf 'signal-gate: --break 只认 pass（收到 %s）\n' "$BREAK" >&2; exit 2 ;; esac
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

# ── 身份隔离：绝不继承调用者的团队/tmux 身份 ─────────────────────────────────────────────────
for _v in $(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p'); do
  case "$_v" in TEAM_TMP_KEEP|TEAM_TMP_RUN_ID|TEAM_TMP_LEDGER) ;; *) unset "$_v" ;; esac
done
unset TMUX TMUX_PANE TMUX_TMPDIR 2>/dev/null || true

TMP="$(tmp_root_create signal-gate)" || exit 3
FAIL=0
PASS=0
FAILED=""
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); FAILED="${FAILED:+$FAILED, }$1"; }
hdr() { printf '\n== %s ==\n' "$1"; }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（[$2] 里没有 [$3]）" ;; esac; }
assert_alive() { kill -0 "$2" 2>/dev/null && ok "$1" || bad "$1（pid $2 不在）"; }
assert_gone() { kill -0 "$2" 2>/dev/null && bad "$1（pid $2 还活着）" || ok "$1"; }

# ── 反向守卫（白名单）：只看真实仓库 state/ 里**夹具的产品代码可能写到**的那族路径 ─────────────
# 为什么不是「整份 state/ 前后逐字节相同」（P171 的现场，2026-10-02 实测）：门禁本来就**要在真实
# 仓库里跑**，而仓库里活着的 PM 运行时每拍都在往自己的车道追加 —— 巡检 `team watch --once` 写
# capacity.log、通知扩展写 nudges.log、后台作业扩展写 bg.log、窗口写 *.env …… 「整份 state/ 不变」
# 这条不变量在活仓库里**不可满足**，红的是运行时不是夹具：P168 把 bg.log 补进排除名单，下一个 tick
# 就轮到 capacity.log（PM 复验原文：合并 P168 后 `--select 58` 仍红 1 条，差异行是 capacity.log）。
# 反过来问「**夹具（及其产品）能写到真实 state 的哪些路径**」才有确定答案 —— 逐条从代码列，不许凭猜：
#   ① signal-calls.log            闸门每次调用追加一行（scripts/shim/signal-gate 的 `_bounded_append`）。
#                                 窗口启动时由 `team_tmux_shim_exports` 把它钉成
#                                 `$TEAM_STATE_DIR/signal-calls.log`（scripts/lib/common.sh:2227），
#                                 而 TEAM_STATE_DIR 默认就是 `<repo>/.pi/team/state`（同文件 927）——
#                                 这就是**夹具漏钉**（某一腿没把 TEAM_SIGNAL_CALLS_LOG 指到自己的私有根）
#                                 时那一行落地的地方。
#   ② signal-calls.log.forensics  同一行的长保留副本（闸门里 `<log>.forensics`，只有拒绝路径写它）。
# 两条归一族（glob `signal-calls.log*`）：闸门轮转时还会写 `<log>.tmp.<pid>` / `<log>.forensics.tmp.<pid>`
# 再 mv（`_bounded_append`），族 glob 把这些瞬态残留也圈进来。
# **除这一族之外，夹具（及其产品）在真实 state/ 里没有别的写入面**：夹具自己的产物全在
# tmp_root_create 的私有根里，每个调用点都显式钉 TEAM_SIGNAL_CALLS_LOG/TEAM_SIGNAL_REAL。
# 判据取**内容哈希**（不是大小/时间戳）：同长度的改写也看得见；目录不在 → 记 absent（连「凭空建出
# state/」也算变化）。覆盖与不覆盖的边界，报告里逐条写；受看面的形状由段尾 watch-shape 探针在合成
# 树上钉住（不许扩成「整个 state/」，也不许缩成空转），跑动中写入的各面在 tests/flip-p171.sh。
FIXTURE_WRITE_WATCH='signal-calls.log*'
REAL_STATE="$REPO_ROOT/.pi/team/state"
# 两个函数都先**跟随软链**把根解成真路径：`find "<软链>"` 默认不走命令行上的软链（只报软链自己，
# 后面统统为空）—— state/ 若是软链，判据会静默瞎掉。解不开（不存在/读不到）就记 absent。
state_snapshot() { # <state-root> → 每个受看文件一行「<sha256>  <相对路径>」；目录不在 → absent
  local root="$1"
  root="$(cd -P "$root" 2>/dev/null && pwd)" || { printf 'absent\n'; return 0; }
  ( cd "$root" 2>/dev/null || exit 0
    find . -maxdepth 1 -type f -name "$FIXTURE_WRITE_WATCH" -print0 2>/dev/null \
      | sort -z | xargs -0 -r sha256sum 2>/dev/null \
      | sed 's|^\([0-9a-f]\{1,\}\)  \./|\1  |' ) | sort
}
REAL_BEFORE="$(state_snapshot "$REAL_STATE")"

# ── 诱饵：夹具 spawn、pid 记录在案（模式串在 argv[0] 里，`-f <marker>` 会命中它们）─────────────
MARKER="p159-signal-marker"
# 注意：**不能**用 `DECOY=$(spawn)` 的形式 —— 命令替换会等 stdout 管道关闭，而 sleep 拿着那个 fd，
# 于是夹具会挂到 sleep 退出（实测：30s 超时）。直接 spawn、$! 就是记录下来的 pid。
bash -c 'exec -a p159-decoy-A sleep 300' >/dev/null 2>&1 &
DECOY1=$!
bash -c 'exec -a p159-decoy-B sleep 300' >/dev/null 2>&1 &
DECOY2=$!
# P164：显式 -g/-P 诊断用的夹具自有进程（pid 记录在案；收尾只按这个 pid 收）
bash -c 'exec sleep 300' >/dev/null 2>&1 &
P164_OWNED=$!
cleanup() {
  [ -n "${DECOY1:-}" ] && kill -TERM "$DECOY1" 2>/dev/null || true
  [ -n "${DECOY2:-}" ] && kill -TERM "$DECOY2" 2>/dev/null || true
  [ -n "${P164_OWNED:-}" ] && kill -TERM "$P164_OWNED" 2>/dev/null || true
  [ "$KEEP" = "1" ] || tmp_root_reap_all
}
trap cleanup EXIT
sleep 0.3
assert_alive "夹具前提：两个诱饵都活着（pid $DECOY1 / $DECOY2）" "$DECOY1"
assert_alive "夹具前提：第二个诱饵也活着" "$DECOY2"
assert_has "夹具前提：诱饵 A 的 argv[0] 里带模式串" "$(tr '\0' ' ' < "/proc/$DECOY1/cmdline" 2>/dev/null)" "p159-decoy-A"
assert_has "夹具前提：诱饵 B 的 argv[0] 里带模式串" "$(tr '\0' ' ' < "/proc/$DECOY2/cmdline" 2>/dev/null)" "p159-decoy-B"

# ── argv 记录桩（真身的唯一替身；绝不执行真 pkill/killall）───────────────────────────────────
STUB="$TMP/stub"
cat > "$STUB" <<'STUB_EOF'
#!/usr/bin/env bash
printf 'STUB argc=%s argv=%s\n' "$#" "$*" >> "${STUB_LOG:?}"
if [ -n "${STUB_KILL_PIDS:-}" ]; then
  for _sp in $STUB_KILL_PIDS; do kill -TERM "$_sp" 2>/dev/null || true; done
fi
exit "${STUB_EXIT:-0}"
STUB_EOF
chmod +x "$STUB"
# 「真身不可解析」那条腿的 PATH 兜底：$REAL_SHIM/pkill → 桩。
# **为什么必须有它**（2026-10-02 见证跑实测）：那一条腿故意给 TEAM_SIGNAL_REAL 一个不存在的路径，
# 闸门于是回落到 PATH 扫描找「第一个不是自己的同名文件」—— 绿侧拒绝在前（不解析），但红侧
# （--break=pass 的副本）会放行，扫到的就是 /usr/bin/pkill。见证桩当场抓到 `REAL-PKILL-EXECUTED -f x`，
# 说明这条腿本身是「夹具可能执行真身」的一个洞（`pkill -f x` 会命中任何命令行里带 x 的进程）。
# 修法：给这条腿的 PATH 里放一个指向桩的同名入口，回落永远落在桩上。
REAL_SHIM="$TMP/real-shim"; mkdir -p "$REAL_SHIM"
for _t in pkill killall; do ln -sf "$STUB" "$REAL_SHIM/$_t"; done

# ── P164 选择器记录桩：**同名**的 pgrep/pidof，紧跟在闸门之后（真身的唯一替身）──────────────────
# 为什么同名：放行的 pgrep/pidof 必须解析到**自己的**真身；旧 pin（TEAM_SIGNAL_REAL，常钉在 pkill
# 上）若被沿用就会落到 pkill 见证桩 —— 那条断言（"pkill 桩零调用"）就是为它写的。
SEL_DIR="$TMP/sel-stub"; mkdir -p "$SEL_DIR"
cat > "$SEL_DIR/selector" <<'SEL_EOF'
#!/usr/bin/env bash
printf '%s argc=%s argv=%s\n' "${0##*/}" "$#" "$*" >> "${SEL_LOG:?}"
[ -n "${SEL_STDOUT:-}" ] && printf '%s\n' "$SEL_STDOUT"
[ -n "${SEL_STDERR:-}" ] && printf '%s\n' "$SEL_STDERR" >&2
exit "${SEL_EXIT:-0}"
SEL_EOF
chmod +x "$SEL_DIR/selector"
for _t in pgrep pidof; do ln -sf selector "$SEL_DIR/$_t"; done
sel_calls() { [ -s "$SEL_LOG" ] && wc -l < "$SEL_LOG" | tr -dc '0-9' || printf '0'; }
p164_gate() { # <tool> <args...>：闸门最前、同名记录桩紧随、旧 pin 仍钉在 pkill 见证桩上
  local _tool="$1"; shift
  env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" \
      TEAM_SIGNAL_CALLS_LOG="${GATE_LOG:-$LOGD/gate.log}" \
      STUB_LOG="${STUB_LOG:-$LOGD/stub.log}" SEL_LOG="${SEL_LOG:-$LOGD/sel.log}" \
      SEL_STDOUT="${SEL_STDOUT-424242}" SEL_STDERR="${SEL_STDERR:-}" SEL_EXIT="${SEL_EXIT:-0}" \
      "$GATE_DIR/$_tool" "$@"
}
p164_refuse() { # <label> <tool> <args...>：exit 64 + 空 stdout + 文案 + 桩零调用 + 恰一行 refused
  local label="$1" tool="$2"; shift 2
  local _before _after _out _err _rc
  _before="$(gate_lines "${GATE_LOG:-$LOGD/gate.log}")"; _before="${_before:-0}"
  _out="$(p164_gate "$tool" "$@" 2>"$TMP/p164-err.txt")"; _rc=$?
  _err="$(cat "$TMP/p164-err.txt" 2>/dev/null)"
  _after="$(gate_lines "${GATE_LOG:-$LOGD/gate.log}")"; _after="${_after:-0}"
  assert_eq "P164 $label：exit 64" "$_rc" "64"
  assert_eq "P164 $label：stdout 为空" "$_out" ""
  assert_has "P164 $label：文案点名工具 $tool" "$_err" "$tool"
  assert_has "P164 $label：文案带完整 argv" "$_err" "$tool${1:+ $*}"
  assert_has "P164 $label：文案给出安全路线 team bg stop <id>" "$_err" "team bg stop <id>"
  assert_eq "P164 $label：选择器桩零调用" "$(sel_calls)" "0"
  assert_eq "P164 $label：拒绝恰加一行日志" "$((_after - _before))" "1"
  assert_has "P164 $label：日志记 act=refused · tool=$tool" "$(tail -n 1 "${GATE_LOG:-$LOGD/gate.log}" 2>/dev/null)" "act=refused · tool=$tool"
}

# ── 闸门目录：默认用真闸门；--break=pass 用一份只改判定行的副本 ────────────────────────────────
GATE_DIR="$SKILL_DIR/scripts/shim"
if [ "$BREAK" = "pass" ]; then
  GATE_DIR="$TMP/shim-break"
  mkdir -p "$GATE_DIR"
  cp -a "$SKILL_DIR/scripts/shim/signal-gate" "$GATE_DIR/signal-gate"
  for _t in pkill killall pgrep pidof; do ln -sf signal-gate "$GATE_DIR/$_t"; done
  sed -i 's/^_act="refused"$/_act="pass"/' "$GATE_DIR/signal-gate"
  if grep -qx '_act="pass"' "$GATE_DIR/signal-gate"; then
    printf '红侧：闸门副本的判定行已改成放行（%s）\n' "$GATE_DIR/signal-gate"
  else
    printf '✗ 红侧不成立：sed 没改到判定行（%s）\n' "$GATE_DIR/signal-gate" >&2; exit 2
  fi
fi
for _t in pkill killall pgrep pidof; do
  [ -x "$GATE_DIR/$_t" ] || { printf '✗ 闸门入口不可执行：%s/%s\n' "$GATE_DIR" "$_t" >&2; exit 2; }
done

LOGD="$TMP/logs"; mkdir -p "$LOGD"
# 红侧：桩按夹具记录过的诱饵 pid 收掉它们（于是 decoys-alive 也红）；真身永远是桩。
if [ "$BREAK" = "pass" ]; then STUB_KILL_PIDS="$DECOY1 $DECOY2"; else STUB_KILL_PIDS=""; fi
# 每次调用都显式钉三样：真身（桩）、日志、PATH 最前是闸门目录（窗口里的形状）
p159_gate() { # <tool> <args...> → 闸门的 stdout/stderr/rc 由调用方接
  local _tool="$1"; shift
  env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="${GATE_LOG:-$LOGD/gate.log}" \
      STUB_LOG="${STUB_LOG:-$LOGD/stub.log}" STUB_EXIT="${STUB_EXIT:-0}" STUB_KILL_PIDS="${STUB_KILL_PIDS:-}" \
      "$GATE_DIR/$_tool" "$@"
}
gate_lines() { wc -l < "$1" 2>/dev/null | tr -dc '0-9'; }

# ══════════════════════════════════════════════════════════════════════════════════════════════
hdr "RA1 · 模式选择一律拒，且两个诱饵都活着"
GATE_LOG="$LOGD/refuse.log"; STUB_LOG="$LOGD/stub-refuse.log"; rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$STUB_LOG"
OUT="$(p159_gate pkill -f "$MARKER" 2>&1)"; RC=$?
assert_eq "pkill -f <marker> 退出 64" "$RC" "64"
assert_has "拒绝文案点名 pkill 与完整 argv" "$OUT" "pkill -f $MARKER"
assert_has "拒绝文案说清「模式不是身份」" "$OUT" "不是身份"
assert_has "拒绝文案给出安全路线 team bg stop <id>" "$OUT" "team bg stop <id>"
assert_has "拒绝文案给出 team bg list" "$OUT" "team bg list"
assert_has "拒绝文案给出 kill <记录过的 pid>" "$OUT" "kill <记录过的 pid>"
assert_eq "桩一个调用都没收到（拒绝不执行真身）" "$(cat "$STUB_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_alive "诱饵 A 还活着" "$DECOY1"
assert_alive "诱饵 B 还活着" "$DECOY2"
assert_has "调用日志记下 act=refused 与 tool=pkill" "$(cat "$GATE_LOG")" "act=refused"
assert_has "调用日志带 argv=" "$(cat "$GATE_LOG")" "argv=-f $MARKER"
assert_has "调用日志带 pid=/ppid=/cwd=" "$(cat "$GATE_LOG")" "ppid="
if cmp -s "$GATE_LOG.forensics" "$GATE_LOG"; then ok "拒绝行逐字节进了 .forensics（cmp）"; else bad "拒绝行与 .forensics 不是逐字节相同"; fi

hdr "RA1 · 每一种选择形态都被拒"
for form in "-x sleep" "-P $DECOY1" "-u $(id -u)"; do
  OUT="$(p159_gate pkill $form 2>&1)"; RC=$?
  assert_eq "pkill $form 退出 64" "$RC" "64"
  assert_has "pkill $form 的理由点名工具" "$OUT" "pkill"
done
OUT="$(p159_gate killall sleep 2>&1)"; RC=$?
assert_eq "killall sleep 退出 64" "$RC" "64"
assert_has "killall 的理由点名 killall" "$OUT" "killall"
assert_eq "四种形态都没有落到桩上" "$(cat "$STUB_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "调用日志：5 次调用 5 行 refused" "$(grep -c 'act=refused' "$GATE_LOG")" "5"

hdr "RA1 · 继承环境不授权"
OUT="$(env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$LOGD/env.log" \
       STUB_LOG="$STUB_LOG" TEAM_ALLOW_PATTERN_KILL=1 "$GATE_DIR/pkill" -f "$MARKER" 2>&1)"; RC=$?
assert_eq "TEAM_ALLOW_PATTERN_KILL=1 时仍退出 64" "$RC" "64"
OUT2="$(env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$LOGD/env.log" \
       STUB_LOG="$STUB_LOG" TEAM_ALLOW_PATTERN_KILL=1 bash -c '"$0/pkill" -f "$1"' "$GATE_DIR" "$MARKER" 2>&1)"; RC2=$?
assert_eq "子 shell 里同样退出 64" "$RC2" "64"
assert_eq "继承环境下桩仍是 0 次" "$(cat "$STUB_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "env.log 里没有 pass/refused 之外的动作" "$(grep -cv 'act=\(pass\|refused\)' "$LOGD/env.log" || true)" "0"

hdr "RA1 · 只读四词原样透传（记 act=pass）"
GATE_LOG="$LOGD/pass.log"; STUB_LOG="$LOGD/stub-pass.log"; rm -f "$GATE_LOG" "$STUB_LOG"
for ro in "--help" "-V"; do
  OUT="$(p159_gate pkill "$ro" 2>&1)"; RC=$?
  assert_eq "pkill $ro 退出码=桩的退出码(0)" "$RC" "0"
  assert_has "桩收到 pkill $ro 的 argv 逐字节" "$(cat "$STUB_LOG")" "STUB argc=1 argv=$ro"
  OUT="$(p159_gate killall "$ro" 2>&1)"; RC=$?
  assert_eq "killall $ro 退出码=0" "$RC" "0"
  assert_has "桩收到 killall $ro 的 argv 逐字节" "$(cat "$STUB_LOG")" "STUB argc=1 argv=$ro"
done
STUB_EXIT=7
OUT="$(p159_gate pkill --version 2>&1)"; RC=$?
STUB_EXIT=""
assert_eq "只读形式的退出码原样来自真身（7）" "$RC" "7"
assert_eq "调用日志：5 行 act=pass（四个只读词 + 一次 --version）" "$(grep -c "act=pass" "$GATE_LOG")" "5"
[ -e "$GATE_LOG.forensics" ] && bad "pass 调用不该建长保留文件" || ok "pass 调用不保留（.forensics 没被建）"
STUB_EXIT=""

hdr "RA1 · pid 精确路线照旧通，且闸门不为 kill 记行"
BEFORE="$(gate_lines "$GATE_LOG")"
env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" STUB_LOG="$STUB_LOG" \
    kill -TERM "$DECOY1" 2>/dev/null || true
sleep 0.2
assert_gone "kill -TERM <记录的 pid> 让诱饵 A 消失" "$DECOY1"
assert_alive "诱饵 B 仍活着（只打了记录的那个 pid）" "$DECOY2"
assert_eq "闸门没有为 kill 记任何行" "$(gate_lines "$GATE_LOG")" "$BEFORE"

hdr "RA1 · 拒绝不依赖真身能否解析"
OUT="$(env PATH="$GATE_DIR:$REAL_SHIM:$PATH" TEAM_SIGNAL_REAL="$TMP/no-such-real" TEAM_SIGNAL_CALLS_LOG="$LOGD/noreal.log" \
       "$GATE_DIR/pkill" -f x 2>&1)"; RC=$?
assert_eq "真身不可解析时 pkill -f 仍退出 64" "$RC" "64"

hdr "RA2 · 一次拒绝 + 一次只读 = 两行日志，拒绝逐字节进 .forensics"
L="$LOGD/two.log"; rm -f "$L" "$L.forensics"; GATE_LOG="$L"; STUB_LOG="$LOGD/stub-two.log"; rm -f "$STUB_LOG"
p159_gate pkill -f x >/dev/null 2>&1
p159_gate pkill --help >/dev/null 2>&1
assert_eq "日志恰好两行" "$(gate_lines "$L")" "2"
assert_has "第一行 act=refused" "$(sed -n 1p "$L")" "act=refused"
assert_has "第二行 act=pass" "$(sed -n 2p "$L")" "act=pass"
assert_eq "长保留文件与拒绝行逐字节相同" "$(cat "$L.forensics")" "$(sed -n 1p "$L")"

hdr "RA2 · 拒绝熬得过主日志轮转"
L="$LOGD/rot.log"; rm -f "$L" "$L.forensics"
printf '2026-01-01T00:00:00+00:00 · act=refused · tool=pkill · argv=-f seeded · pid=1 ppid=1 cwd=/tmp\n' > "$L.forensics"
awk 'BEGIN { for (i = 0; i < 2100; i++) printf "2026-01-01T00:00:00+00:00 · act=pass · tool=pkill · argv=--help · pid=1 ppid=1 cwd=/tmp\n" }' > "$L"
GATE_LOG="$L" p159_gate pkill -f x >/dev/null 2>&1
assert_has "轮转后首行是 rotation 标记" "$(sed -n 1p "$L")" " · rotation · dropped="
assert_has "轮转标记的 dropped 记下被裁掉的 1101 行" "$(sed -n 1p "$L")" "dropped=1101"
assert_eq "标记 + 1000 条调用行" "$(gate_lines "$L")" "1001"
assert_has "长保留里那条被拒绝的行还在（逐字节）" "$(cat "$L.forensics")" "argv=-f seeded"

hdr "RA2 · 保留写失败：可见、不改判定、不挂住"
L="$LOGD/fail.log"; rm -f "$L"; rm -rf "$L.forensics"; mkdir -p "$L.forensics"
OUT="$(GATE_LOG="$L" timeout 10 env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" \
      TEAM_SIGNAL_CALLS_LOG="$L" STUB_LOG="$STUB_LOG" "$GATE_DIR/pkill" -f x 2>&1)"; RC=$?
assert_eq "保留路径是目录时仍退出 64（且有界，没被挂住）" "$RC" "64"
assert_has "诊断点名保留路径（✗）" "$OUT" "✗"
assert_has "诊断点名 .forensics 路径" "$OUT" "$L.forensics"
assert_has "本行带 retention=failed" "$(cat "$L")" "retention=failed"
assert_has "本行仍带 act=refused" "$(cat "$L")" "act=refused"
rm -rf "$L.forensics"

hdr "RA2 · FIFO 目标不挂住"
L="$LOGD/fifo.log"; rm -f "$L"; mkfifo "$L"
RC=0; GATE_LOG="$L" timeout 10 env PATH="$GATE_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$L" \
    STUB_LOG="$STUB_LOG" "$GATE_DIR/pkill" -f x >/dev/null 2>&1 || RC=$?
assert_eq "FIFO 日志目标：拒绝照常退出 64，没有被写端挂住" "$RC" "64"
rm -f "$L"

# ══════════════════════════════════════════════════════════════════════════════════════════════
# P164（signal-gate-pgrep）· 选择器家族。语法表 = openspec/changes/signal-gate-pgrep/specs/boundary/spec.md。
# 纪律不变：真身一律是记录桩；夹具绝不执行真的 pkill/killall/pgrep/pidof；替换用例里的 kill 只记 argv。

hdr "P164 · 闸门入口：pgrep / pidof 是闸门自己的软链"
for _p164t in pgrep pidof; do
  [ -e "$GATE_DIR/$_p164t" ] && ok "P164 闸门入口存在（$_p164t）" || bad "P164 闸门入口缺失（$_p164t）"
  [ -x "$GATE_DIR/$_p164t" ] && ok "P164 闸门入口可执行（$_p164t）" || bad "P164 闸门入口不可执行（$_p164t）"
  assert_eq "P164 $_p164t 是指向 signal-gate 的软链" "$(readlink "$GATE_DIR/$_p164t" 2>/dev/null)" "signal-gate"
done
P164_RESOLVED="$(PATH="$GATE_DIR:$PATH" bash -c 'command -v pgrep; command -v pidof' 2>/dev/null | tr '\n' ' ')"
assert_has "P164 PATH 最前是闸门目录时 pgrep 解析到闸门" "$P164_RESOLVED" "$GATE_DIR/pgrep"
assert_has "P164 PATH 最前是闸门目录时 pidof 解析到闸门" "$P164_RESOLVED" "$GATE_DIR/pidof"

hdr "P164 · 按名字/模式/所有者的选择一律拒（十种形态）"
GATE_LOG="$LOGD/p164-refuse.log"; SEL_LOG="$LOGD/p164-refuse-sel.log"; STUB_LOG="$LOGD/p164-refuse-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
SEL_STDOUT=424242; SEL_EXIT=0; SEL_STDERR=""
p164_refuse "pgrep -f <marker>（模式）"        pgrep -f "$MARKER"
p164_refuse "pgrep --full <marker>（长别名）"  pgrep --full "$MARKER"
p164_refuse "pgrep -f<marker>（融合旗标）"     pgrep -f"$MARKER"
p164_refuse "pgrep -x sleep（精确名字）"       pgrep -x sleep
p164_refuse "pgrep sleep（裸名）"              pgrep sleep
p164_refuse "pgrep -u 1000（真实用户）"        pgrep -u 1000
p164_refuse "pgrep -U 1000（有效用户）"        pgrep -U 1000
p164_refuse "pgrep -G 1000（真实组）"          pgrep -G 1000
p164_refuse "pidof sleep（裸名）"              pidof sleep
p164_refuse "pidof -s sleep（单次选择）"       pidof -s sleep
assert_eq "P164 十种拒绝：选择器桩一个调用都没收到" "$(sel_calls)" "0"
assert_eq "P164 十种拒绝：日志十行 refused" "$(grep -c 'act=refused' "$GATE_LOG")" "10"
assert_eq "P164 十种拒绝：工具名分记对（pgrep 8 / pidof 2）" "$(grep -c 'tool=pgrep' "$GATE_LOG")/$(grep -c 'tool=pidof' "$GATE_LOG")" "8/2"

hdr "P164 · 显式 -g/-P 诊断保留真身语义"
GATE_LOG="$LOGD/p164-diag.log"; SEL_LOG="$LOGD/p164-diag-sel.log"; STUB_LOG="$LOGD/p164-diag-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
P164_GROUP="$(awk '{print $5}' "/proc/$P164_OWNED/stat" 2>/dev/null)"; [ -n "$P164_GROUP" ] || P164_GROUP="$P164_OWNED"
P164_PARENT="$P164_OWNED"
P164_DIAG_OUT="$(printf '%s\n%s' "$P164_OWNED" "$P164_GROUP")"
SEL_STDOUT="$P164_DIAG_OUT"; SEL_STDERR="p164 选择器诊断"; SEL_EXIT=3
_out="$(p164_gate pgrep -g "$P164_GROUP" 2>"$TMP/p164-e.txt")"; _rc=$?
assert_eq "P164 pgrep -g <记录的组 id> 的退出码来自真身（3）" "$_rc" "3"
assert_eq "P164 pgrep -g 的 stdout 逐字节来自真身" "$_out" "$P164_DIAG_OUT"
assert_eq "P164 pgrep -g 的 stderr 逐字节来自真身" "$(cat "$TMP/p164-e.txt")" "p164 选择器诊断"
SEL_EXIT=0; SEL_STDERR=""
_out="$(p164_gate pgrep -P "$P164_PARENT" 2>"$TMP/p164-e.txt")"; _rc=$?
assert_eq "P164 pgrep -P <记录的父 id> 退出 0" "$_rc" "0"
assert_eq "P164 pgrep -P 的 stdout 来自真身" "$_out" "$P164_DIAG_OUT"
assert_has "P164 同名桩收到 -g 的 argv 逐字节" "$(cat "$SEL_LOG")" "pgrep argc=2 argv=-g $P164_GROUP"
assert_has "P164 同名桩收到 -P 的 argv 逐字节" "$(cat "$SEL_LOG")" "pgrep argc=2 argv=-P $P164_PARENT"
assert_eq "P164 两次放行都不落到 pkill 见证桩" "$(cat "$STUB_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "P164 两次放行都记 act=pass · tool=pgrep" "$(grep -c 'act=pass · tool=pgrep' "$GATE_LOG")" "2"
[ -e "$GATE_LOG.forensics" ] && bad "P164 pass 调用不该建 .forensics" || ok "P164 pass 调用不保留（.forensics 没被建）"
assert_alive "P164 两次诊断都没给任何进程发信号（夹具自有进程仍活着）" "$P164_OWNED"

hdr "P164 · FAST 的整命令计数不被拦（三种拼写 × 两种响应）"
GATE_LOG="$LOGD/p164-count.log"; SEL_LOG="$LOGD/p164-count-sel.log"; STUB_LOG="$LOGD/p164-count-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
SEL_STDOUT=0; SEL_EXIT=1; SEL_STDERR=""
for _sp in "-fc" "-f -c" "-c -f"; do
  # shellcheck disable=SC2086
  _out="$(p164_gate pgrep $_sp '/tmp/p164-fixture/pi-sleep' 2>/dev/null)"; _rc=$?
  assert_eq "P164 pgrep $_sp <absent>：stdout 0（无匹配的计数）" "$_out" "0"
  assert_eq "P164 pgrep $_sp <absent>：退出码 1 原样保留" "$_rc" "1"
done
SEL_STDOUT=2; SEL_EXIT=0
for _sp in "-fc" "-f -c" "-c -f"; do
  # shellcheck disable=SC2086
  _out="$(p164_gate pgrep $_sp '/tmp/p164-fixture/pi-sleep' 2>/dev/null)"; _rc=$?
  assert_eq "P164 pgrep $_sp <present>：stdout 2" "$_out" "2"
  assert_eq "P164 pgrep $_sp <present>：退出码 0" "$_rc" "0"
done
assert_eq "P164 六次计数的 argv 逐字节到同名桩" "$(gate_lines "$SEL_LOG")" "6"
assert_eq "P164 六次计数都记 act=pass · tool=pgrep" "$(grep -c 'act=pass · tool=pgrep' "$GATE_LOG")" "6"
[ -e "$GATE_LOG.forensics" ] && bad "P164 计数放行不建 .forensics" || ok "P164 计数放行不保留（.forensics 没被建）"

hdr "P164 · 部分匹配/隐式 ID 不能放大选择（十八种形态）"
GATE_LOG="$LOGD/p164-widen.log"; SEL_LOG="$LOGD/p164-widen-sel.log"; STUB_LOG="$LOGD/p164-widen-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
SEL_STDOUT=424242; SEL_EXIT=0; SEL_STDERR=""
p164_refuse "pgrep -g 0（隐式组）"              pgrep -g 0
p164_refuse "pgrep -P 0（隐式父）"              pgrep -P 0
p164_refuse "pgrep -g 1,2（多值）"              pgrep -g 1,2
p164_refuse "pgrep -P -1（负数）"               pgrep -P -1
p164_refuse "pgrep -g（缺值）"                  pgrep -g
p164_refuse "pgrep -P ''（空值）"               pgrep -P ''
p164_refuse "pgrep -P 12 -v（额外谓词）"        pgrep -P 12 -v
p164_refuse "pgrep -v -g 12（前置谓词）"        pgrep -v -g 12
p164_refuse "pgrep -g 12 sleep（尾随名字）"     pgrep -g 12 sleep
p164_refuse "pgrep -P 12 -u 1000（加所有者）"   pgrep -P 12 -u 1000
p164_refuse "pgrep --parent=12（长别名）"       pgrep --parent=12
p164_refuse "pgrep -fc（缺模式）"               pgrep -fc
p164_refuse "pgrep -fc ''（空模式）"            pgrep -fc ''
p164_refuse "pgrep -fc -sleep（模式以 - 开头）" pgrep -fc -sleep
p164_refuse "pgrep -fc sleep -l（计数加列表）"  pgrep -fc sleep -l
p164_refuse "pgrep -fcl sleep（融合拼写）"      pgrep -fcl sleep
p164_refuse "pgrep --teamsmith-allow-pattern sleep（带内 token）" pgrep --teamsmith-allow-pattern sleep
p164_refuse "pidof --help sleep（两种形态混合）" pidof --help sleep
assert_eq "P164 十八种放大形状：选择器桩零调用" "$(sel_calls)" "0"
assert_eq "P164 十八种放大形状：日志十八行 refused" "$(grep -c 'act=refused' "$GATE_LOG")" "18"

hdr "P164 · 只读信息词用自己的真身（旧 pin 钉在 pkill 上也不改道）"
GATE_LOG="$LOGD/p164-info.log"; SEL_LOG="$LOGD/p164-info-sel.log"; STUB_LOG="$LOGD/p164-info-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
SEL_STDOUT=424242; SEL_EXIT=0; SEL_STDERR=""
for _t in pgrep pidof; do
  for _tok in --help -h -V --version; do
    _out="$(p164_gate "$_t" "$_tok" 2>/dev/null)"; _rc=$?
    assert_eq "P164 $_t $_tok：退出码来自同名真身（0）" "$_rc" "0"
    assert_eq "P164 $_t $_tok：stdout 来自同名真身" "$_out" "424242"
  done
done
SEL_EXIT=7
_out="$(p164_gate pgrep --version 2>/dev/null)"; _rc=$?
assert_eq "P164 只读词的退出码原样来自真身（7）" "$_rc" "7"
SEL_EXIT=0
_out="$(p164_gate pgrep -P 12 2>/dev/null)"; _rc=$?
assert_eq "P164 pgrep -P 12（放行路径）也用自己的真身" "$_rc" "0"
assert_eq "P164 同名桩收到 10 次调用（8 信息词 + 1 复测 + 1 诊断）" "$(gate_lines "$SEL_LOG")" "10"
assert_eq "P164 pkill 见证桩零调用（放行不走旧 pin）" "$(cat "$STUB_LOG" 2>/dev/null | wc -l | tr -d ' ')" "0"
assert_eq "P164 日志按实际工具名记（pgrep 6 / pidof 4）" "$(grep -c 'act=pass · tool=pgrep' "$GATE_LOG")/$(grep -c 'act=pass · tool=pidof' "$GATE_LOG")" "6/4"

hdr "P164 · 拒绝与 pin / 继承环境无关"
GATE_LOG="$LOGD/p164-nopin.log"; SEL_LOG="$LOGD/p164-nopin-sel.log"; STUB_LOG="$LOGD/p164-nopin-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
p164_env_run() { # <direct|child> <cmd> <args...>：不可用的 pin + 继承的 TEAM_ALLOW_PATTERN_KILL
  local _mode="$1"; shift
  if [ "$_mode" = child ]; then
    env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$TMP/no-such-real" TEAM_ALLOW_PATTERN_KILL=1 \
        TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" SEL_LOG="$SEL_LOG" SEL_STDOUT=424242 SEL_EXIT=0 STUB_LOG="$STUB_LOG" \
        bash -c '"$@"' _ "$@"
  else
    env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$TMP/no-such-real" TEAM_ALLOW_PATTERN_KILL=1 \
        TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" SEL_LOG="$SEL_LOG" SEL_STDOUT=424242 SEL_EXIT=0 STUB_LOG="$STUB_LOG" \
        "$@"
  fi
}
for _mode in direct child; do
  _out="$(p164_env_run "$_mode" "$GATE_DIR/pgrep" -f "$MARKER" 2>/dev/null)"; _rc=$?
  assert_eq "P164 $_mode：pgrep -f 在不可用 pin + 继承 token 下 exit 64" "$_rc" "64"
  assert_eq "P164 $_mode：pgrep -f stdout 空" "$_out" ""
  _out="$(p164_env_run "$_mode" "$GATE_DIR/pidof" sleep 2>/dev/null)"; _rc=$?
  assert_eq "P164 $_mode：pidof sleep 在不可用 pin + 继承 token 下 exit 64" "$_rc" "64"
  assert_eq "P164 $_mode：pidof sleep stdout 空" "$_out" ""
done
assert_eq "P164 四次拒绝：同名回落桩零执行" "$(sel_calls)" "0"
assert_eq "P164 四次拒绝：日志四行、全是 refused" "$(grep -c 'act=refused' "$GATE_LOG")/$(grep -cv 'act=refused' "$GATE_LOG" || true)" "4/0"

hdr "P164 · 被拒的替换不给 shell 任何 PID（kill 只记 argv）"
PAT_LOG="$LOGD/p164-kill-argv.log"; : > "$PAT_LOG"
GATE_LOG="$LOGD/p164-subst.log"; SEL_LOG="$LOGD/p164-subst-sel.log"; STUB_LOG="$LOGD/p164-subst-pkill.log"
rm -f "$GATE_LOG" "$GATE_LOG.forensics" "$SEL_LOG" "$STUB_LOG"
cat > "$TMP/p164-subst.sh" <<'SUB_EOF'
#!/usr/bin/env bash
kill() { printf 'kill argv=[%s]\n' "$*" >> "${KILL_LOG:?}"; }
for _case in "pgrep -f p164-subst-marker" "pidof sleep"; do
  _out="$($_case 2>/dev/null)"; _rc=$?
  printf 'selector=[%s] rc=%s stdout=[%s]\n' "$_case" "$_rc" "$_out" >> "$KILL_LOG"
done
kill $(pgrep -f p164-subst-marker)
kill $(pidof sleep)
SUB_EOF
chmod +x "$TMP/p164-subst.sh"
env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" \
    SEL_LOG="$SEL_LOG" SEL_STDOUT=424242 SEL_EXIT=0 SEL_STDERR="" STUB_LOG="$STUB_LOG" KILL_LOG="$PAT_LOG" \
    bash "$TMP/p164-subst.sh" >/dev/null 2>&1 || true
assert_has "P164 替换里的 pgrep -f 退出 64 且 stdout 空" "$(cat "$PAT_LOG")" "selector=[pgrep -f p164-subst-marker] rc=64 stdout=[]"
assert_has "P164 替换里的 pidof sleep 退出 64 且 stdout 空" "$(cat "$PAT_LOG")" "selector=[pidof sleep] rc=64 stdout=[]"
assert_eq "P164 只记 argv 的 kill 两次调用都没有 PID 参数" "$(grep -c '^kill argv=\[\]$' "$PAT_LOG")" "2"
assert_eq "P164 kill 没有记录到任何 PID 参数" "$(grep -c '^kill argv=\[424242\]$' "$PAT_LOG" || true)" "0"
assert_eq "P164 替换用例：选择器桩零调用" "$(sel_calls)" "0"

hdr "P164 · 新选择器的拒绝进同一份取证记录（逐字节 / 轮转 / 保留失败 / FIFO）"
L="$LOGD/p164-forensic.log"; rm -f "$L" "$L.forensics"
GATE_LOG="$L"; SEL_LOG="$LOGD/p164-forensic-sel.log"; STUB_LOG="$LOGD/p164-forensic-pkill.log"
rm -f "$SEL_LOG" "$STUB_LOG"
SEL_STDOUT=424242; SEL_EXIT=0; SEL_STDERR=""
p164_gate pgrep -f "$MARKER" >/dev/null 2>&1
p164_gate pidof sleep >/dev/null 2>&1
assert_eq "P164 两次拒绝两行日志" "$(gate_lines "$L")" "2"
assert_has "P164 第一行 act=refused · tool=pgrep" "$(sed -n 1p "$L")" "act=refused · tool=pgrep"
assert_has "P164 第二行 act=refused · tool=pidof" "$(sed -n 2p "$L")" "act=refused · tool=pidof"
assert_has "P164 拒绝行带完整 argv" "$(sed -n 1p "$L")" "argv=-f $MARKER"
assert_has "P164 拒绝行带 pid= 与 ppid=" "$(sed -n 1p "$L")" "ppid="
assert_has "P164 拒绝行带 cwd=" "$(sed -n 1p "$L")" "cwd="
if cmp -s "$L.forensics" <(sed -n '1,2p' "$L"); then ok "P164 两条拒绝逐字节进了 .forensics（cmp）"; else bad "P164 拒绝行与 .forensics 不是逐字节相同"; fi
awk 'BEGIN { for (i = 0; i < 2100; i++) printf "2026-01-01T00:00:00+00:00 · act=pass · tool=pgrep · argv=--help · pid=1 ppid=1 cwd=/tmp\n" }' > "$L"
p164_gate pgrep --help >/dev/null 2>&1
assert_has "P164 轮转后首行是 rotation 标记" "$(sed -n 1p "$L")" " · rotation · dropped="
assert_eq "P164 标记 + 1000 条调用行" "$(gate_lines "$L")" "1001"
assert_eq "P164 轮转后 .forensics 仍是两条拒绝" "$(gate_lines "$L.forensics")" "2"
assert_has "P164 .forensics 里第一条是被拒的 pgrep" "$(sed -n 1p "$L.forensics")" "act=refused · tool=pgrep"
L2="$LOGD/p164-retfail.log"; rm -f "$L2"; rm -rf "$L2.forensics"; mkdir -p "$L2.forensics"
_out="$(GATE_LOG="$L2" timeout 10 env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" \
      TEAM_SIGNAL_CALLS_LOG="$L2" SEL_LOG="$SEL_LOG" SEL_STDOUT=424242 SEL_EXIT=0 STUB_LOG="$STUB_LOG" \
      "$GATE_DIR/pidof" sleep 2>&1)"; _rc=$?
assert_eq "P164 保留路径是目录时仍退出 64（没被挂住）" "$_rc" "64"
assert_has "P164 诊断点名 .forensics 路径" "$_out" "$L2.forensics"
assert_has "P164 本行带 retention=failed" "$(cat "$L2")" "retention=failed"
assert_has "P164 本行仍带 act=refused · tool=pidof" "$(cat "$L2")" "act=refused · tool=pidof"
rm -rf "$L2.forensics"
L3="$LOGD/p164-fifo.log"; rm -f "$L3"; mkfifo "$L3"
_rc=0
GATE_LOG="$L3" timeout 10 env PATH="$GATE_DIR:$SEL_DIR:$PATH" TEAM_SIGNAL_REAL="$STUB" TEAM_SIGNAL_CALLS_LOG="$L3" \
    SEL_LOG="$SEL_LOG" SEL_STDOUT=424242 SEL_EXIT=0 STUB_LOG="$STUB_LOG" "$GATE_DIR/pgrep" -f x >/dev/null 2>&1 || _rc=$?
assert_eq "P164 FIFO 日志目标：拒绝照常 64，没被写端挂住" "$_rc" "64"
rm -f "$L3"

hdr "P164 · ps / fuser 不在这道闸门的管理面内"
RO_DIR="$TMP/readonly-stub"; mkdir -p "$RO_DIR"
cat > "$RO_DIR/ro-stub" <<'RO_EOF'
#!/usr/bin/env bash
printf '%s argc=%s argv=%s\n' "${0##*/}" "$#" "$*" >> "${RO_LOG:?}"
exit "${RO_EXIT:-0}"
RO_EOF
chmod +x "$RO_DIR/ro-stub"
for _t in ps fuser; do ln -sf ro-stub "$RO_DIR/$_t"; done
RO_LOG="$LOGD/p164-readonly-calls.log"; : > "$RO_LOG"
GATE_LOG="$LOGD/p164-readonly.log"; rm -f "$GATE_LOG"
_rc=0; env PATH="$GATE_DIR:$RO_DIR:$PATH" RO_LOG="$RO_LOG" TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" ps -p 12 >/dev/null 2>&1 || _rc=$?
assert_eq "P164 ps -p 12 的退出码来自自己的真身（0）" "$_rc" "0"
_rc=0; env PATH="$GATE_DIR:$RO_DIR:$PATH" RO_LOG="$RO_LOG" TEAM_SIGNAL_CALLS_LOG="$GATE_LOG" fuser /tmp/p164-file >/dev/null 2>&1 || _rc=$?
assert_eq "P164 fuser /tmp/p164-file 的退出码来自自己的真身（0）" "$_rc" "0"
assert_has "P164 ps 的 argv 逐字节到见证桩" "$(cat "$RO_LOG")" "ps argc=2 argv=-p 12"
assert_has "P164 fuser 的 argv 逐字节到见证桩" "$(cat "$RO_LOG")" "fuser argc=1 argv=/tmp/p164-file"
[ -e "$GATE_LOG" ] && bad "P164 ps/fuser 不该给信号闸门写任何日志（实际建了 $GATE_LOG）" || ok "P164 ps/fuser 没有闸门日志行"

# ══════════════════════════════════════════════════════════════════════════════════════════════
if [ "$BREAK" = "pass" ]; then
  # 红侧：判定被改成放行后，「exit 64 / 桩没被调用 / 诱饵活着」这些断言必须红。
  printf '\n== 红侧（--break=pass）==\n'
  if [ "$FAIL" -gt 0 ]; then
    printf '红侧成立：%d 条断言变红 —— %s\n' "$FAIL" "$FAILED"
    printf '（这就是断侧该有的结果：闸门放行 → 真身被调用、诱饵被收掉、exit 不再是 64）\n'
    exit 1
  fi
  printf '✗ 红侧不成立：把闸门判定改成放行之后，夹具居然还是绿的\n'
  exit 1
fi

hdr "反向守卫：真实仓库 state/ 里夹具的写入面没被碰过（白名单 + 签名）"
# 名单不许和产品源码漂移：闸门前缀把日志名一改，这条断言就地变红，提示把 FIXTURE_WRITE_WATCH
# 一起改（而不是静默失守 —— 受看面写着一个再也不会出现的名字时，段尾 watch-shape 探针也会红）。
assert_has "守卫名单与产品一致：闸门前缀仍把日志钉成 state/signal-calls.log（scripts/lib/common.sh）" \
  "$(grep -h 'TEAM_SIGNAL_CALLS_LOG=' "$SKILL_DIR/scripts/lib/common.sh" 2>/dev/null)" \
  'TEAM_STATE_DIR/signal-calls.log'
REAL_AFTER="$(state_snapshot "$REAL_STATE")"
assert_eq "真实仓库 state/ 受看面（产品日志 signal-calls.log*）前后一致" "$REAL_AFTER" "$REAL_BEFORE"
# 形状探针（P171 的正向对照）：在合成树上钉住白名单的**形状** —— 受看那一族进快照；活运行时的车道
# （capacity.log/panel.log/dev.env/bg/bg.log/inbox-watch/sub 里的文件）一律不进。任何「放宽成整个
# state/」或「受看面写成不存在的名字（空转）」的改动在这里当场变红，不必等一次真跑；跑动中写入的
# 各面（受看面红 / 活车道绿 / 整份快照变异红 / 签名红 / runner 车道绿）在 tests/flip-p171.sh。
WATCH_PROBE="$TMP/watch-shape"; rm -rf "$WATCH_PROBE"
mkdir -p "$WATCH_PROBE/bg" "$WATCH_PROBE/sub" "$WATCH_PROBE/inbox-watch"
: > "$WATCH_PROBE/signal-calls.log"; : > "$WATCH_PROBE/signal-calls.log.forensics"
: > "$WATCH_PROBE/capacity.log"; : > "$WATCH_PROBE/panel.log"; : > "$WATCH_PROBE/dev.env"
: > "$WATCH_PROBE/bg.log"; : > "$WATCH_PROBE/bg/job-1.log"; : > "$WATCH_PROBE/sub/keep.txt"
: > "$WATCH_PROBE/inbox-watch/w0.msg"
WATCH_SHAPE="$(state_snapshot "$WATCH_PROBE")"
WATCH_SHAPE_FLAT="$(printf '%s' "$WATCH_SHAPE" | tr '\n' ' ')"
case "$WATCH_SHAPE" in
  *"signal-calls.log"*) ok "形状：受看面 signal-calls.log 进了快照（判据不是空转）" ;;
  *) bad "形状：受看面 signal-calls.log 没进快照（判据空转：$WATCH_SHAPE_FLAT）" ;;
esac
case "$WATCH_SHAPE" in
  *"signal-calls.log.forensics"*) ok "形状：受看那一族（.forensics）也进了快照" ;;
  *) bad "形状：.forensics 没进快照（$WATCH_SHAPE_FLAT）" ;;
esac
case "$WATCH_SHAPE" in
  *"capacity.log"*|*"panel.log"*|*"dev.env"*|*"bg"*|*"sub/"*|*"inbox-watch"*)
    bad "形状：活运行时的车道混进了快照（判据过宽了：$WATCH_SHAPE_FLAT）" ;;
  *) ok "形状：活运行时的车道（capacity.log/panel.log/dev.env/bg/bg.log/inbox-watch/sub）都不进快照" ;;
esac
# 内容敏感：同长度的改写也要看得见（大小/时间戳那套判据看不出来）。
printf 'AAAA\n' > "$WATCH_PROBE/signal-calls.log"; WATCH_A="$(state_snapshot "$WATCH_PROBE")"
printf 'BBBB\n' > "$WATCH_PROBE/signal-calls.log"; WATCH_B="$(state_snapshot "$WATCH_PROBE")"
if [ -n "$WATCH_A" ] && [ "$WATCH_A" != "$WATCH_B" ]; then
  ok "形状：同长度的内容改写也进快照（判据是内容哈希）"
else bad "形状：同长度的内容改写看不出来（判据太弱）"; fi
# 软链的 state/ 也必须看得见：不做这一步的话 `find "<软链>"` 什么都不报，判据会**静默**瞎掉。
LINK_PROBE="$TMP/watch-shape-link"; rm -rf "$LINK_PROBE"
mkdir -p "$LINK_PROBE/real" && : > "$LINK_PROBE/real/signal-calls.log" && ln -s "$LINK_PROBE/real" "$LINK_PROBE/state-link"
case "$(state_snapshot "$LINK_PROBE/state-link")" in
  *"signal-calls.log"*) ok "形状：state/ 是软链时受看面照样进快照（判据不瞎）" ;;
  *) bad "形状：state/ 是软链时看不到受看面（find 不走命令行软链）" ;;
esac
# 签名断言：夹具的诱饵名不得出现在真实 state 的**普通文件**里 —— 这是「夹具没碰账本」的**主证据**，
# 与上面的白名单**互补**：白名单只管产品那一族日志（连没带签名的写入也看得见），签名扫全树（不管
# 文件名是什么、只要那行字带着夹具自己的记号）。唯一放过的路径是 runner 自己的并发车道（下面
# RUNNER_LANE_EXCLUDE）：用 `team_bg_run` / `team bg` 跑门禁时，runner 把**本夹具自己的 stdout**
# 抄进作业日志，一次失败跑的 bad() 文案里就带着诱饵名 —— 那是夹具的输出被 runner 抄走，不是夹具
# 写了账本（P168 的现场同源：假红来自 runner 写的东西）。扫描只走 `find -type f`（FIFO 之类特殊节点
# 天然跳过，grep 不会挂住）；签名在脚本里分段拼接，任何一跑的**输出**都不含完整串。
RUNNER_LANE_EXCLUDE=(bg bg.log)
state_files_for_signature() { # <state-root> → 除 runner 车道外的普通文件（一条一行）
  local root="$1" rel expr=()
  root="$(cd -P "$root" 2>/dev/null && pwd)" || return 0   # 同 state_snapshot：软链也跟
  for rel in "${RUNNER_LANE_EXCLUDE[@]}"; do expr+=(-path "$root/$rel" -o); done
  if [ "${#expr[@]}" -eq 0 ]; then
    find "$root" -mindepth 1 -type f -print 2>/dev/null | sort
  else
    expr=("${expr[@]:0:${#expr[@]}-1}")
    find "$root" -mindepth 1 \( "${expr[@]}" \) -prune -o -type f -print 2>/dev/null | sort
  fi
}
SIG="p159-""decoy-"
REAL_LEAK="$(state_files_for_signature "$REAL_STATE" | while IFS= read -r _f; do
  grep -lF "$SIG" "$_f" 2>/dev/null || true
done | head -3 | tr '\n' ' ')"
if [ -z "$REAL_LEAK" ]; then ok "真实 state（不含 runner 自己的作业车道 bg/ 与 bg.log）里没有夹具的诱饵名签名"
else bad "真实 state 里出现了夹具的诱饵名签名：$REAL_LEAK"; fi

printf '\n== signal-gate 结果 == ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32msignal-gate 全绿\033[0m\n'; exit 0; }
printf '\033[31msignal-gate 有失败项（--keep 保留现场 %s）\033[0m\n' "$TMP"
exit 1
