#!/usr/bin/env bash
# routes.sh — route sincerity (P99 / roster-writer-and-route-truth, R3).
#
# The CLI prints routes (team help's usage lines; the contract schema's notes) that promise a behaviour.
# This walk judges the printed surface against the real one:
#
#   Walk A  every command-block line of `team help` → command path + every --flag it prints → probe
#           (`<path> <flag>` in a fixture). A parser that answers with the tool's unknown-parameter /
#           unknown-subcommand refusal is RED, naming path+flag. A line that cannot be attributed to a
#           command and its flags is RED, naming the line — never skipped.
#   Control non-vacuity: every path that prints at least one flag must REFUSE an unknown flag
#           (`--frobnicate-probe`); a command that swallows unknown arguments reads as "accepted"
#           otherwise, so it is RED naming the command.
#   Walk B  every schema note that names a `team <cmd>`: the command must resolve, and the key must have
#           a declared promise probe that makes the sentence's promise really happen in the fixture
#           (probes assert the EFFECT, never the exit code). The set of keys needing a probe is derived
#           from the schema, so a note added without one is RED naming the key.
#
#   flips   ten mutations that MUST redden their guard (a field defect, a sibling flag, a swallowing
#           parser, an unattributable line, a fake schema route, an unprobed note, a broken promise, a
#           nested run that does not reap, an unclaimed route, a mutated repair), plus a control arm on
#           the last tree that must stay green, plus two red sides of the landing check itself. They are
#           the walk's own proof that it can fail.
#           Every mutation must PROVE IT LANDED (target text 1→0 / new text 0→1, and the copy must
#           differ from the pristine file byte-wise) BEFORE its verdict is judged: a silent no-op patch is
#           reported as `变异没落地（夹具缺陷）`, never as `没有兑现` (M21). And every verdict reads the
#           nested log as a FILE — never `printf … | grep -q`, which under `set -o pipefail` can read a
#           matched log as unmatched (grep -q exits first, printf takes SIGPIPE, the pipeline turns 141).
#
# Usage / knobs:
#   bash skills/teamsmith/tests/routes.sh [walk] [control] [promises] [refusals] [flips]
#   TEAM_ROUTES_TREE=<tree>     tree under test (default: this checkout; flips use scratch copies)
#   TEAM_ROUTES_KEEP=1          keep the fixture root and print it
#   TEAM_ROUTES_TIMEOUT=<s>     per-probe timeout, default 15 (containment, never a verdict: a probe
#                               that times out is recorded as accepted with a visible note)
#   TEAM_ROUTES_FAST=1          (or TEAM_SMOKE_FAST=1) run walk/control/promises, SKIP the flips visibly
#   TEAM_TMP_KEEP=1             inherited from the gate's `--keep`: the flips' nested runs keep their
#                               temp roots on purpose — the tail prints them and does NOT call it a leak
# Exit: 0 every selected section green; 1 at least one finding; 3 setup failure.
#
# Containment (the walk must not touch the caller): one owned temp root via tests/lib/tmp-root.sh
# (`${TMPDIR:-/tmp}/teamsmith-routes.XXXXXX`), every run in a fresh git repo under it, a recording
# `tmux` shim first on PATH that answers session queries as absent and NEVER calls the real tmux,
# TEAM_MEETINGS_DIR/TEAM_PI_AGENT_DIR inside the fixture, stdin from /dev/null, a hard timeout per probe
# and an EXIT trap that reaps every directory (unless TEAM_TMP_KEEP=1 asks to keep it, as the CI gate's
# `--keep` does). Nothing here reads or writes the caller's project.
set -uo pipefail

# ── knobs + identity isolation (must happen first): never inherit the caller's team identity ────────
_tree_arg="${TEAM_ROUTES_TREE:-}"
_keep_arg="${TEAM_ROUTES_KEEP:-0}"
_timeout_arg="${TEAM_ROUTES_TIMEOUT:-}"
_fast_arg="${TEAM_ROUTES_FAST:-}"
_smoke_fast_arg="${TEAM_SMOKE_FAST:-}"
_tmpkeep="${TEAM_TMP_KEEP:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
perf_sh="$skill/tests/perf.sh"
timeout_sec="${_timeout_arg:-15}"
case "$timeout_sec" in ''|*[!0-9]*) timeout_sec=15 ;; esac
keep="$_keep_arg"
case "${_fast_arg:-${_smoke_fast_arg:-0}}" in
  1|y|Y|yes|YES|true|TRUE|on|ON) FAST=1 ;;
  *) FAST=0 ;;
esac
[ -n "$_tmpkeep" ] && export TEAM_TMP_KEEP="$_tmpkeep"

# 嵌套 run 与父 run 共享同一份 run 台账：SMOKE_TMP_RUN_ID 是非 TEAM_ 的传播位（嵌套 run 的身份清理
# 会清掉 TEAM_*，清不掉它）；没有它时自己起一个 —— 收尾的「嵌套根都回收了」据此能看见**每一个**
# 嵌套根（find -newer 只看得到最后一个：任何后续 scratch 树的建删都会刷新 $tmp 的 mtime）。
export SMOKE_TMP_RUN_ID="${SMOKE_TMP_RUN_ID:-routes-$$-$(date +%s 2>/dev/null || printf 0)}"

# shellcheck source=tests/lib/tmp-root.sh
. "$here/lib/tmp-root.sh"
tmp="$(tmp_root_create routes)" || { printf 'routes: 临时根建不起来\n' >&2; exit 3; }
PASS=0
FIND=0
SKIP=0

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0          # subshell-guarded (P50 hygiene)
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()      { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
finding() { printf '  \033[31m✗\033[0m %s\n' "$1"; FIND=$((FIND + 1)); }
skip()    { printf '  \033[33mSKIP\033[0m %s\n' "$1"; SKIP=$((SKIP + 1)); }

[ -f "$team" ] || { printf 'routes: 没有 CLI：%s\n' "$team" >&2; exit 3; }
[ -f "$perf_sh" ] || { printf 'routes: 没有 tests/perf.sh：%s\n' "$perf_sh" >&2; exit 3; }
TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN=timeout

SECTIONS=("$@")
# 段集是**显式**的：给了段名就只跑给的段；不带段名 = 全部四段（FAST 下 flips 按下面的 skip 可见跳过）。
# 旧写法给任何不含 flips 的子集追加 flips —— flips 的每一臂都在 scratch 树上再跑一遍
# `routes.sh walk`，那个嵌套 run 又被追加 flips，于是自己生自己：实测进程链每 ~40 秒长一层、
# 跑 12 分钟不返回（08:08 → 08:20，32 个进程），只能人工杀。子集的边界由调用者给。
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(walk control promises refusals flips)
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(walk control promises refusals)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ── containment: the recording tmux shim (never calls the real tmux) ────────────────────────────────
# P140 扩展：除了记账，它还替窗口 harness 签证 —— 窗口注册表（new-window/kill-window/list-windows）
# 让“窗口存在”这件事自洽；TEAM_ROUTES_FAKE_LAUNCH=1 时，respawn-pane 把 harness 命令里的
# (nonce, marker) 解析出来写下启动/退出证据（假窗口但真证据，不碰真 server）。
SHIM="$tmp/shim"
TMUX_LOG="$tmp/tmux-calls.log"
WINREG="$tmp/windows.reg"
mkdir -p "$SHIM"
cat > "$SHIM/tmux" <<'SHIM'
#!/usr/bin/env bash
# Recording tmux: session queries answer "absent", windows live in a registry file, everything is
# recorded and exits 0. It never invokes the real tmux, so no call this process makes can reach a
# live server.
printf '%s\n' "$*" >> "${TEAM_ROUTES_TMUX_LOG:-/dev/null}" 2>/dev/null || true
win="${TEAM_ROUTES_WINDOWS:-/dev/null}"
sub="" t="" name=""
while [ $# -gt 0 ]; do
  case "$1" in
    -L|-S|-f|-T|-c) shift 2 ;;
    -*) shift ;;
    *) sub="$1"; shift; break ;;
  esac
done
rest=("$@")
_i=0
while [ "$_i" -lt ${#rest[@]} ]; do
  case "${rest[$_i]}" in
    -t) t="${rest[$((_i+1))]:-}"; _i=$((_i+2)) ;;
    -n) name="${rest[$((_i+1))]:-}"; _i=$((_i+2)) ;;
    *) _i=$((_i+1)) ;;
  esac
done
reg() { [ -n "$1" ] || return 0; grep -qxF "$1" "$win" 2>/dev/null || printf '%s\n' "$1" >> "$win"; }
unreg() { [ -n "$1" ] || return 0; [ -f "$win" ] || return 0; grep -vxF "$1" "$win" > "$win.tmp" 2>/dev/null || true; mv "$win.tmp" "$win"; }
case "$sub" in
  has-session) exit 1 ;;
  list-windows)
    [ -f "$win" ] || exit 0
    if [ -n "$t" ]; then awk -F: -v s="$t" '$1==s{print $2}' "$win"; else cat "$win"; fi
    exit 0 ;;
  new-window) reg "${t:-?}:$name"; exit 0 ;;
  kill-window) unreg "${t:-?}"; exit 0 ;;
  respawn-pane)
    # P140：TEAM_ROUTES_FAKE_LAUNCH=1 时替窗口 harness 写下本轮 (nonce, pid) 启动证据与 (nonce, 0)
    # 退出证据 —— 内容从 harness 命令行里解析，不是猜的；默认关着（只有最终拒绝路线真拉起时用）。
    if [ "${TEAM_ROUTES_FAKE_LAUNCH:-0}" = "1" ]; then
      inner="" prev=""
      for a in "${rest[@]}"; do [ "$prev" = "-lc" ] && inner="$a"; prev="$a"; done
      if [ -n "$inner" ]; then
        marker="$(printf '%s' "$inner" | grep -oE "/[^ \"']*dispatch-[A-Za-z0-9_.-]+\.spawn" | head -1)"
        exitf="$(printf '%s' "$inner" | grep -oE "/[^ \"']*dispatch-[A-Za-z0-9_.-]+\.exit" | head -1)"
        nonce="$(printf '%s' "$inner" | sed -n 's/.*printf "%s %s\\n" \([^ ][^ ]*\) \$\$ >.*/\1/p' | head -1)"
        [ -n "$marker" ] && [ -n "$nonce" ] && printf '%s %s\n' "$nonce" 4242 > "$marker"
        [ -n "$exitf" ] && [ -n "$nonce" ] && printf '%s %s\n' "$nonce" 0 > "$exitf"
      fi
    fi
    exit 0 ;;
  list-panes|list-sessions|display-message|set-window-option|capture-pane) exit 0 ;;
  show-options) printf 'on\n'; exit 0 ;;
esac
exit 0
SHIM
chmod +x "$SHIM/tmux"
# `team` 解析器（Walk C 要**粘贴路线本身**并执行：路线里的 `team …` 必须落在被测的那棵树上）
cat > "$SHIM/team" <<EOF
#!/usr/bin/env bash
exec bash $(printf '%q' "$team") "\$@"
EOF
chmod +x "$SHIM/team"
: > "$TMUX_LOG"
: > "$WINREG"

# ── fixtures ───────────────────────────────────────────────────────────────────────────────────────
# new_fixture <name> → a fresh git repo under $tmp, `team init`-ed with a clean identity.
# The tree under test provides the CLI, so a scratch TEAM_ROUTES_TREE flips the tool too.
new_fixture() {
  local name="$1"
  local d="$tmp/$name"
  rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email routes@teamsmith && git config user.name routes \
      && printf '{"name":"%s","scripts":{"verify":"true"}}\n' "$name" > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  if ! ( cd "$d" && env PATH="$SHIM:$PATH" TEAM_PI_BIN=/bin/true TEAM_ROUTES_TMUX_LOG="$TMUX_LOG" \
           TEAM_MEETINGS_DIR="$d/.meetings" TEAM_PI_AGENT_DIR="$d/.pi-agent" \
           bash "$team" init --no-skills --session "routes-$name" --agents "dev verify" --vcs local \
             --gates true --docs docs/team ) >"$tmp/$name-init.log" 2>&1; then
    printf 'routes: 夹具 %s 的 team init 失败：\n' "$name" >&2
    tail -5 "$tmp/$name-init.log" >&2
    return 1
  fi
  printf '%s\n' "$d"
}

# mr_run <fixture> <team args...> → stdout+stderr in MR_OUT, exit code in MR_RC (timeout contained)
mr_run() {
  local d="$1"; shift
  local out rc
  out="$( cd "$d" && env -u TMUX -u TMUX_PANE \
            PATH="$SHIM:$PATH" TEAM_PI_BIN=/bin/true TEAM_ROUTES_TMUX_LOG="$TMUX_LOG" \
            TEAM_MEETINGS_DIR="$d/.meetings" TEAM_PI_AGENT_DIR="$d/.pi-agent" \
            ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} bash "$team" "$@" </dev/null 2>&1 )"
  rc=$?
  MR_OUT="$out"; MR_RC="$rc"
}

first_line() { printf '%s' "$1" | grep -av '^[[:space:]]*$' | head -1 | cut -c1-90; }
sha_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# ── the CLI's command table (derived from the source, not a hand-kept list) ─────────────────────────
# tops: the dispatcher's own case labels in scripts/team (+ the pre-dispatch help/version).
# subs: `parent sub` pairs from every `case "$sub" in` block, attributed to its enclosing team_cmd_<x>.
mr_known_tables() {
  local src="$skill/scripts/team" f
  MRI_TOPS="help"
  MRI_TOPS="$MRI_TOPS $(awk '
    /^case "\$CMD" in/ { inb=1; next }
    inb && /^esac/ { inb=0 }
    inb && /^[[:space:]]+[A-Za-z0-9_'"'"'|.-]+\)/ {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/\).*/,"",line)
      n=split(line,a,"|"); for (i=1;i<=n;i++){ gsub(/[^a-z0-9-]/,"",a[i]); if(a[i]!="") printf "%s ", a[i] }
    }' "$src")"
  MRI_SUBS=""
  for f in "$skill"/scripts/lib/cmd-*.sh; do
    [ -f "$f" ] || continue
    MRI_SUBS="$MRI_SUBS $(awk '
      /^[a-z_]+\(\) *\{/ { fn=$0; sub(/\(\).*/,"",fn); sub(/^team_cmd_/,"",fn) }
      /case "\$sub" in/ { insub=1; depth=0; next }
      insub && /case .* in/ { depth++; next }
      insub && /^[[:space:]]*esac/ { if (depth>0) { depth--; next } insub=0; next }
      insub && /^[[:space:]]+[A-Za-z0-9_'"'"'|.-]+\)/ {
        line=$0; sub(/^[[:space:]]+/,"",line); sub(/\).*/,"",line)
        n=split(line,a,"|"); for (i=1;i<=n;i++){ gsub(/[^a-z0-9-]/,"",a[i]); if(a[i]!="" && fn!="") printf "%s:%s;", fn, a[i] }
      }' "$f")"
  done
  if [ "${ROUTES_DEBUG_TABLES:-0}" = "1" ]; then
    printf 'tops=[%s]\nsubs=[%s]\n' "$MRI_TOPS" "$MRI_SUBS" > "$tmp/debug-tables.txt"
  fi
}

# ── Walk A: parse `team help` (awk), then probe every claim ─────────────────────────────────────────
mr_write_parser() {
cat > "$tmp/walk-a.awk" <<'AWK'
function fail(ln, msg) { printf "FAIL\t%d\t%s\n", ln, msg }
function tokenize(s, arr, offs,   rest, tok, n, pos) {
  n=0; rest=s; pos=1
  while (match(rest, /\[[^]]*\]|[^ \t]+/)) {
    tok=substr(rest, RSTART, RLENGTH)
    n++; arr[n]=tok; offs[n]=pos+RSTART-1
    pos += RSTART-1+RLENGTH; rest=substr(rest, RSTART+RLENGTH)
  }
  return n
}
function isph(t) {
  if (t ~ /^<.*>$/) return 1
  if (t ~ /^".*"$/ || t ~ /^'.*'$/) return 1
  if (t=="..." || t=="…" || t=="ID" || t=="N" || t=="X") return 1
  return 0
}
function addverb(w) { if (!(w in VERBW)) { VERBW[w]=1; NV++; VERBW_LIST[NV]=w } }
function lastwordpos(s, w,   re, off, best) {
  re = "(^|[ \t])" w "([^ \t]|$)"
  off=0; best=0
  while (off < length(s) && match(substr(s, off+1), re)) {
    best = off + RSTART
    off = best + RLENGTH - 2
    if (RLENGTH <= 0) break
  }
  return best
}
function emit(ln, path, flag, key) {
  key = path "\t" flag
  if (key in EMITTED) return
  EMITTED[key]=1
  printf "CLAIM\t%d\t%s\t%s\n", ln, path, flag
}
function one_fragment(frag, ln,   nt, toks, offs, i, t, core, j, k, na, alts, ok, usage_end, rest, base, fl, fpos, bind, best, w, p, nnp, newp, isbr) {
  nt = tokenize(frag, toks, offs)
  # `version / help` (and only that shape): a plain ` / ` splits into fragments when BOTH sides
  # start with a command; `perf … （交互首帧 / 帧装配 / …）` is description text and must not split.
  if (nt >= 1) {
    # handled by the caller (expand_slash)
  }
  t = toks[1]; gsub(/^\[|\]$/, "", t)
  if (!(t in TOP)) { fail(ln, "这一行无法归属到命令（首 token「" t "」不是 CLI 的命令）：" frag); return }
  NP=1; PATHS[1]=t; NV=0; delete VERBW; delete VERBW_LIST; delete EMITTED
  usage_end = offs[1]+length(toks[1])-1
  for (i=2; i<=nt; i++) {
    t=toks[i]
    isbr = (t ~ /^\[.*\]$/)
    core=t; if (isbr) core=substr(t,2,length(t)-2)
    if (isph(core) || core ~ /^-/) { usage_end = offs[i]+length(t)-1; continue }
    if (index(core, "|") > 0) {
      na=split(core, alts, "|"); ok=1
      for (j=1;j<=NP;j++) for (kk=1;kk<=na;kk++) if (!(PATHS[j] " " alts[kk] in SUB)) ok=0
      if (ok) {
        nnp=0
        for (j=1;j<=NP;j++) for (kk=1;kk<=na;kk++) { nnp++; newp[nnp]=PATHS[j] " " alts[kk] }
        NP=nnp; for (j=1;j<=nnp;j++) PATHS[j]=newp[j]
        for (kk=1;kk<=na;kk++) addverb(alts[kk])
        usage_end = offs[i]+length(t)-1
        continue
      }
      # 未解析的组：可选的（[...]）当参数——如 standby [on|off|status]；不带的则是一句「这个命令有这些子命令」
      # 的假活，必须红（不能静默降级成只有主命令）。
      if (isbr) break
      fail(ln, "这一行的命令组无法解析（" core "）：" frag); return
    }
    ok=1
    for (j=1;j<=NP;j++) if (!(PATHS[j] " " core in SUB)) ok=0
    if (ok) {
      for (j=1;j<=NP;j++) PATHS[j]=PATHS[j] " " core
      addverb(core)
      usage_end = offs[i]+length(t)-1
      continue
    }
    break   # 参数/描述文本：命令部分到此为止
  }
  # every --flag on the line, judged at its own offset
  rest=frag; base=0
  while (match(rest, /--[a-z0-9-]+/)) {
    fl=substr(rest, RSTART, RLENGTH)
    fpos=base+RSTART
    base=base+RSTART+RLENGTH-1
    rest=substr(rest, RSTART+RLENGTH)
    if (fpos <= usage_end) {
      for (j=1;j<=NP;j++) emit(ln, PATHS[j], fl)
      continue
    }
    # description flag: the nearest preceding verb token of this fragment's own group, else the
    # fragment's command(s) — `board …（add [--allow-dup] …）` binds to `board add`, `perf …；--host …`
    # to `perf`.
    best=0
    for (kk=1;kk<=NV;kk++) { p=lastwordpos(substr(frag, 1, fpos-1), VERBW_LIST[kk]); if (p>best) best=p }
    bind=0
    if (best > 0) {
      for (kk=1;kk<=NV;kk++) {
        w=VERBW_LIST[kk]
        if (lastwordpos(substr(frag, 1, fpos-1), w) != best) continue
        for (j=1;j<=NP;j++) if (PATHS[j] ~ ("(^| )" w "$")) { emit(ln, PATHS[j], fl); bind=1 }
      }
    }
    if (bind == 0) {
      for (j=1;j<=NP;j++) emit(ln, PATHS[j], fl)
    }
  }
}
function expand_slash(frag, ln,   np, parts, i, first, ok) {
  np = split(frag, parts, / \/ /)
  if (np > 1) {
    ok=1
    for (i=1;i<=np;i++) { first=parts[i]; sub(/^[ \t]+/,"",first); sub(/[ \t].*/,"",first); if (!(first in TOP)) ok=0 }
    if (ok) { for (i=1;i<=np;i++) one_fragment(parts[i], ln); return }
  }
  one_fragment(frag, ln)
}
BEGIN {
  n=split(tops, ta, " "); for (i=1;i<=n;i++) { gsub(/^[ \t]+|[ \t]+$/, "", ta[i]); if (ta[i]!="") TOP[ta[i]]=1 }
  m=split(subs, sa, ";")
  for (i=1;i<=m;i++) {
    if (sa[i]=="") continue
    if (split(sa[i], kv, ":") < 2) continue
    p=kv[1]; gsub(/^[ \t]+|[ \t]+$/, "", p)
    c=split(kv[2], sb, ",")
    for (j=1;j<=c;j++) { gsub(/^[ \t]+|[ \t]+$/, "", sb[j]); if (sb[j]!="") SUB[p " " sb[j]]=1 }
  }
  inblock=0; lastindent=-1
}
{
  line=$0
  if (line ~ /^[ \t]*$/) next
  if (line ~ /^[ \t]*──/) { inblock=1; lastindent=-1; next }
  if (!inblock) next
  m=match(line, /[^ \t]/); ind=m-1; rest=substr(line, m)
  first=rest; sub(/[ \t].*/,"",first)
  isentry = (first in TOP)
  if (ind == 0) {
    # 列 0 的行：命令块的正文一律缩进（对齐的续行更深）。
    #   · 打旗标的 → 无法归属（修复前的 board 形状：列 0 + [--allow-dup]）→ 红；
    #   · 首 token 是命令的 → 未缩进的条目（形状约定是 2 空格）→ 红；
    #   · 其余（help 末尾的 配置：/协议： 页脚，不打印旗标）→ 块到此为止，忽略。
    if (line ~ /--[a-z0-9-]+/) { fail(NR, "命令块里列 0 的行带着旗标（无法归属到任何条目）：" rest) }
    else if (isentry) { fail(NR, "命令块里的命令条目没有缩进（列 0）：" rest) }
    inblock=0; next
  }
  if (lastindent >= 0 && ind > lastindent) { next }   # 缩进更深的行是上一条目的续行（哪怕它首 token 像个命令）
  if (!isentry) {
    fail(NR, "这一行既不是命令条目，也没有比上一条目缩进更深（无法归属）：" rest)
    next
  }
  lastindent=ind
  printf "ENTRY\t%d\n", NR
  # 全角分隔符在 bash 侧先换成 \x1f —— awk（mawk）按字节看字符类，直接写 [｜／] 会在
  # 任何中文 UTF-8 字节上乱切（实测把一行劈成单字碎片）。
  nf = split($0, frags, "\037")
  for (i=1;i<=nf;i++) expand_slash(frags[i], NR)
}
AWK
}

# mr_probe_mode <path> → `run`（默认）或 `source:<file>:<reason>`。
# `source` 只用于「这条命令只是 exec 另一个程序」的路径：跑它来验证一个旗标会真的把那个程序跑起来
# （perf = 性能套件）—— 那时读它自己的参数表。声明必须带文件与理由。
mr_probe_mode() {
  case "$1" in
    perf) printf 'source:%s:%s\n' "$perf_sh" 'perf 只 exec tests/perf.sh；--host 是它的布尔模式，跑了就是跑整套性能测量' ;;
    *)    printf 'run\n' ;;
  esac
}

# mr_probe_claim <fixture> <path> <flag> → 0 accepted / 1 refused（被解析器明确拒绝）
# Refused = the tool's unknown-parameter or unknown-subcommand refusal that names this flag.
mr_probe_claim() {
  local d="$1" path="$2" flag="$3" mode file reason
  mode="$(mr_probe_mode "$path")"
  case "$mode" in
    source:*)
      file="${mode#source:}"; reason="${file#*:}"; file="${file%%:*}"
      if [ -f "$file" ] && grep -qE "(^|[[:space:]|])${flag//-/\\-}\\)" "$file"; then
        MR_OUT="source 模式（$reason）：$file 的参数表里有一整条 $flag 分支"
        MR_RC=0
        return 0
      fi
      MR_OUT="source 模式（$reason）：$file 的参数表里找不到 $flag 分支"
      MR_RC=1
      return 1 ;;
  esac
  mr_run "$d" $path "$flag"
  case "$MR_OUT" in
    *未知参数*|*未知子命令*) case "$MR_OUT" in *"$flag"*) return 1 ;; esac ;;
  esac
  return 0
}

mr_walk_a() {
  section "walk · team help 的每条用法行 ↔ 解析器（打印的每个 --flag 都要被自己的解析器接受）"
  local help_out
  help_out="$( cd "$tmp" && env PATH="$SHIM:$PATH" bash "$team" help 2>&1 )"
  if ! printf '%s\n' "$help_out" | grep -q '用法：'; then
    finding "team help 没有打印用法头部（不可解析）"
    return 1
  fi
  mr_known_tables
  mr_write_parser
  printf '%s\n' "$help_out" > "$tmp/help.txt"
  # 全角 ｜／ → \x1f（bash 的字面替换按字节序列匹配，安全；awk 的字符类不行）。
  local prepped="" hline
  while IFS= read -r hline; do
    hline="${hline//｜/$'\x1f'}"
    prepped="$prepped${hline//／/$'\x1f'}"$'\n'
  done <<< "$help_out"
  printf '%s' "$prepped" | awk -v tops="$MRI_TOPS" -v subs="$MRI_SUBS" -f "$tmp/walk-a.awk" > "$tmp/walk-a.tsv" 2>"$tmp/walk-a.err"
  if [ -s "$tmp/walk-a.err" ]; then
    finding "Walk A 解析器报错：$(head -2 "$tmp/walk-a.err" | tr '\n' ' ')"
    return 1
  fi

  local n_entry n_claim
  n_entry="$(grep -ac '^ENTRY' "$tmp/walk-a.tsv" || true)"
  n_claim="$(grep -ac '^CLAIM' "$tmp/walk-a.tsv" || true)"
  if [ "${n_entry:-0}" -lt 5 ] || [ "${n_claim:-0}" -lt 10 ]; then
    finding "Walk A 解析出的条目/断言太少（entry=$n_entry claim=$n_claim）—— 解析器或 help 形状变了"
    grep -a '^FAIL' "$tmp/walk-a.tsv" | head -5 | sed 's/^/      /'
    return 1
  fi
  local ln line
  while IFS=$'\t' read -r _ ln; do
    line="$(sed -n "${ln}p" "$tmp/help.txt" | sed 's/^[[:space:]]*//' | cut -c1-60)"
    ok "用法行 L$ln：$line"
  done < <(grep -a '^ENTRY' "$tmp/walk-a.tsv")
  local failed=0
  while IFS=$'\t' read -r _ ln rest; do
    finding "L$ln 无法归属（解析器拒绝静默跳过）：$rest"
    failed=1
  done < <(grep -a '^FAIL' "$tmp/walk-a.tsv")
  [ "$failed" = "1" ] && return 1

  local fixture
  fixture="$(new_fixture walk-a)" || return 1
  local path flag note
  while IFS=$'\t' read -r _ ln path flag; do
    if mr_probe_claim "$fixture" "$path" "$flag"; then
      note="$(first_line "$MR_OUT")"
      ok "断言 L$ln：$path $flag → rc=$MR_RC ${note:+｜ $note}"
    else
      finding "断言 L$ln：$path $flag 被自己的解析器拒绝（原文：$(first_line "$MR_OUT")）"
      failed=1
    fi
  done < <(grep -a '^CLAIM' "$tmp/walk-a.tsv")
  [ "$failed" = "1" ] && return 1
  return 0
}

# ── control: an unknown flag must be refused by every flag-printing path ────────────────────────────
mr_control() {
  section "control · 非空洞臂：打印旗标的每条路径都必须拒绝未知参数（--frobnicate-probe）"
  [ -f "$tmp/walk-a.tsv" ] || {
    local help_out prepped hline
    help_out="$( cd "$tmp" && env PATH="$SHIM:$PATH" bash "$team" help 2>&1 )"
    mr_known_tables
    mr_write_parser
    printf '%s\n' "$help_out" > "$tmp/help.txt"
    prepped=""
    while IFS= read -r hline; do
      hline="${hline//｜/$'\x1f'}"
      prepped="$prepped${hline//／/$'\x1f'}"$'\n'
    done <<< "$help_out"
    printf '%s' "$prepped" | awk -v tops="$MRI_TOPS" -v subs="$MRI_SUBS" -f "$tmp/walk-a.awk" > "$tmp/walk-a.tsv" 2>/dev/null
  }
  local fixture; fixture="$(new_fixture control)" || return 1
  local p n=0 bad=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    mr_run "$fixture" $p --frobnicate-probe
    case "$MR_OUT" in
      *未知参数*|*未知子命令*) case "$MR_OUT" in *--frobnicate-probe*)
          ok "控制：$p --frobnicate-probe 被拒（解析器的未知参数消息，rc=$MR_RC）"; continue ;;
        esac ;;
    esac
    # 用法行拒绝也算拒（team_usage_die 的签名行）—— reload 就是这种形状（设计 §1.2 实测）。
    if [ "$MR_RC" != "0" ] && printf '%s' "$MR_OUT" | tail -1 | grep -qE '^run: .* help$'; then
      ok "控制：$p --frobnicate-probe 被拒（用法行，rc=$MR_RC）"
      continue
    fi
    finding "控制：$p 吞掉了未知参数 --frobnicate-probe（rc=$MR_RC）—— 「打印出来就被接受」不可信"
    bad=1
  done < <(awk -F'\t' '$1=="CLAIM" {print $3}' "$tmp/walk-a.tsv" | sort -u)
  [ "$n" -gt 0 ] || { finding "控制臂没有扫到任何路径（上游解析空转）"; return 1; }
  [ "$bad" = "1" ] && return 1
  return 0
}

# ── Walk B: the schema notes' promises ─────────────────────────────────────────────────────────────
# Probe declaration table: key → probe id. The set of keys needing a probe is derived from the schema
# notes themselves; a note that names a team command without an entry here is a finding naming the key.
mr_probe_for() { # <KEY> → probe id（空 = 没有声明）
  case "$1" in
    TEAM_PROJECT|TEAM_SESSION|TEAM_PM_WINDOW) printf 'identity\n' ;;
    TEAM_AGENTS)                              printf 'roster\n' ;;
    TEAM_AGENT_MODELS)                        printf 'seat-model\n' ;;
    TEAM_PM_MODEL)                            printf 'pm-model\n' ;;
    TEAM_PULSE_WINDOW)                        printf 'pulse-window\n' ;;
    TEAM_DEFAULT_MODEL)                       printf 'default-model\n' ;;
    TEAM_BG_STOP_GRACE)                       printf 'bg-stop-grace\n' ;;
    *) printf '\n' ;;
  esac
}

mr_schema_rows() { # → KEY|note（每行一条；note 是 schema 第 8 列）
  env PATH="$SHIM:$PATH" bash -c '
    set -uo pipefail
    . "$1"
    team_config_schema' _ "$skill/scripts/lib/cmd-config.sh" 2>/dev/null \
  | awk -F'|' '!/^#/ && NF>=8 { txt=$7; if (txt=="-") txt=""; if ($8!="") txt = (txt=="" ? $8 : txt " " $8); print $1 "\t" txt }'
}

mr_walk_b() {
  section "promises · schema 注释点名的命令 ↔ 夹具里真的会发生（探针断言效果，不看退出码）"
  local rows="$tmp/schema-notes.tsv"
  mr_schema_rows > "$rows"
  if [ "$(wc -l < "$rows")" -lt 50 ]; then
    finding "schema 读不出足够的行（$(wc -l < "$rows")）—— cmd-config.sh 的 schema 形状变了"
    return 1
  fi
  mr_known_tables
  local top_re=" $MRI_TOPS "
  local bad=0 key note rest cmd probe
  while IFS=$'\t' read -r key note; do
    [ -n "$key" ] || continue
    rest="$note"
    local seen_cmds=""
    while [[ "$rest" =~ team[[:space:]]+([a-z][a-z0-9-]*) ]]; do
      cmd="${BASH_REMATCH[1]}"
      rest="${rest#*"${BASH_REMATCH[0]}"}"
      case "$seen_cmds" in *" $cmd "*) continue ;; esac
      seen_cmds="$seen_cmds$cmd "
      case "$top_re" in
        *" $cmd "*) ;;
        *) finding "promise：$key 的注释点名了 CLI 没有的命令「team $cmd」"; bad=1 ;;
      esac
    done
    [ -n "$seen_cmds" ] || continue
    probe="$(mr_probe_for "$key")"
    if [ -z "$probe" ]; then
      finding "promise：$key 的注释点名了 team 命令（${seen_cmds% }）但没有声明 promise 探针（schema 就是覆盖来源）"
      bad=1
      continue
    fi
    case "$probe" in
      identity)      mr_promise_identity "$key" || bad=1 ;;
      roster)        mr_promise_roster "$key" || bad=1 ;;
      seat-model)    mr_promise_seat_model "$key" || bad=1 ;;
      pm-model)      mr_promise_pm_model "$key" || bad=1 ;;
      pulse-window)  mr_promise_pulse_window "$key" || bad=1 ;;
      default-model) mr_promise_default_model "$key" || bad=1 ;;
      bg-stop-grace) mr_promise_bg_stop_grace "$key" || bad=1 ;;
      *)             finding "promise：$key 的探针 id「$probe」没有实现（覆盖表与实现脱节）"; bad=1 ;;
    esac
  done < "$rows"
  [ "$bad" = "1" ] && return 1
  return 0
}

# -- the promise probes -----------------------------------------------------------------------------
# P159：宽限旋钮的探针。作业是夹具自己 spawn 的**新会话组头**（pgid == pid）且 **trap "" TERM**
# （SIG_IGN 会被 exec 继承，组里那个 sleep 也一样）——于是只有 KILL 能收掉它，"先 TERM、等宽限、
# 再 KILL" 这条承诺真的会发生。两次跑只差 config.sh 里手改的那个值：0 必须**不等待**（< 3s），
# 2 必须**等够**（≥ 2s）。判的是效果（进程死了 + 账本 signal=TERM,KILL + 用时差），不看退出码。
mr_bg_ignore_term_job() { # <fixture> <id> → 起作业、写记录；MR_BG_PID/MR_BG_PGID/MR_BG_START
  local d="$1" id="$2" st rest
  setsid bash -c 'trap "" TERM; sleep 300 & echo $! > "$1"; wait' _ "$d/$id-child.pid" >/dev/null 2>&1 &
  MR_BG_PID=$!
  disown "$MR_BG_PID" 2>/dev/null || true   # 收掉作业时不要打「Killed」噪声（判定只看进程与账本）
  sleep 0.3
  st="$(cat "/proc/$MR_BG_PID/stat" 2>/dev/null)" || return 1
  rest="${st##*)}"
  # shellcheck disable=SC2086
  set -- $rest
  MR_BG_PGID="$3"; MR_BG_START="${20}"
  mkdir -p "$d/.pi/team/state/bg"
  printf 'id=%s\npid=%s\npgid=%s\nstart=%s\ncwd=%s\nlog=%s\ncmd=sleep 300\n' \
    "$id" "$MR_BG_PID" "$MR_BG_PGID" "$MR_BG_START" "$d" "$d/.pi/team/state/bg/$id.log" \
    > "$d/.pi/team/state/bg/$id.job"
  return 0
}

mr_promise_bg_stop_grace() { # <KEY>
  local key="$1" d t0 t1 spent
  d="$(new_fixture promise-bg-stop-grace)" || return 1
  # ① 宽限 0：TERM 之后**不等待**，直接 KILL
  printf 'TEAM_BG_STOP_GRACE=0\n' >> "$d/.pi/team/config.sh"
  mr_bg_ignore_term_job "$d" grace0 || { finding "promise（$key）：作业夹具起不来"; return 1; }
  t0="$(date +%s)"; mr_run "$d" bg stop grace0; t1="$(date +%s)"; spent=$((t1 - t0))
  if kill -0 "$MR_BG_PID" 2>/dev/null; then
    kill -KILL "$MR_BG_PID" 2>/dev/null || true
    finding "promise（$key）：宽限 0 时忽略 TERM 的作业没有被 KILL 收掉（rc=$MR_RC，$(first_line "$MR_OUT")）"
    return 1
  fi
  if [ "$spent" -ge 3 ]; then
    finding "promise（$key）：宽限 0 却等了 ${spent}s（旋钮没生效）"
    return 1
  fi
  if ! grep -q 'stop id=grace0 signal=TERM,KILL result=stopped' "$d/.pi/team/state/bg.log" 2>/dev/null; then
    finding "promise（$key）：账本没有记下 TERM→KILL 的升级（$(first_line "$(cat "$d/.pi/team/state/bg.log" 2>/dev/null)"）)"
    return 1
  fi
  ok "promise（$key）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL，用时 ${spent}s）"
  # ② 宽限 2：同样的作业要等够 2s 才升级 —— 旋钮真的改变等待
  sed -i 's/^TEAM_BG_STOP_GRACE=0$/TEAM_BG_STOP_GRACE=2/' "$d/.pi/team/config.sh"
  mr_bg_ignore_term_job "$d" grace2 || { finding "promise（$key）：第二个作业夹具起不来"; return 1; }
  t0="$(date +%s)"; mr_run "$d" bg stop grace2; t1="$(date +%s)"; spent=$((t1 - t0))
  if kill -0 "$MR_BG_PID" 2>/dev/null; then
    kill -KILL "$MR_BG_PID" 2>/dev/null || true
    finding "promise（$key）：宽限 2 时作业没有被 KILL 收掉（rc=$MR_RC，$(first_line "$MR_OUT")）"
    return 1
  fi
  if [ "$spent" -lt 2 ]; then
    finding "promise（$key）：宽限 2 却只等了 ${spent}s（旋钮没生效）"
    return 1
  fi
  ok "promise（$key）：宽限 2 → 先 TERM、等 ${spent}s 后 KILL（旋钮改变等待）"
  return 0
}

# -- the other promise probes -----------------------------------------------------------------------
mr_promise_identity() { # <KEY>（三个身份键共享一条承诺：手改有效；team init 是 skip；--force 重渲染并回模板值）
  local key="$1" d base
  d="$(new_fixture promise-identity)" || return 1
  base="$(basename "$d")"
  printf 'TEAM_PROJECT="handedited"\n' >> "$d/.pi/team/config.sh"
  sed -i 's/^TEAM_GATES=.*/TEAM_GATES="bash my-gate.sh"/' "$d/.pi/team/config.sh"
  mr_run "$d" paths
  case "$MR_OUT" in
    *'"project": "handedited"'*|*'"project":"handedited"'*)
      ok "promise（$key）：手改 TEAM_PROJECT 后 team paths 报 handedited" ;;
    *) finding "promise（$key）：手改 TEAM_PROJECT 后 team paths 没变（$(first_line "$MR_OUT")）"; return 1 ;;
  esac
  local sha0 sha1 sha2
  sha0="$(sha_file "$d/.pi/team/config.sh")"
  mr_run "$d" init
  sha1="$(sha_file "$d/.pi/team/config.sh")"
  if [ "$sha0" = "$sha1" ]; then ok "promise（$key）：裸 team init 打印 skip，契约逐字节不变"
  else finding "promise（$key）：裸 team init 改了契约（sha $sha0 → $sha1）—— 注释把它当路线就是在骗人"; fi
  mr_run "$d" init --force --yes
  sha2="$(sha_file "$d/.pi/team/config.sh")"
  local now_proj now_gates
  now_proj="$(grep -E '^TEAM_PROJECT=' "$d/.pi/team/config.sh" | head -1)"
  now_gates="$(grep -E '^TEAM_GATES=' "$d/.pi/team/config.sh" | head -1)"
  if [ "$sha2" != "$sha1" ] && [ "$now_proj" = "TEAM_PROJECT=\"$base\"" ] && [ "$now_gates" != 'TEAM_GATES="bash my-gate.sh"' ]; then
    ok "promise（$key）：team init --force 重渲染（sha 变了；TEAM_PROJECT 回模板值，TEAM_GATES 回检测值）"
  else
    finding "promise（$key）：team init --force 没有兑现「重渲染并回模板值」（sha0=$sha1？proj=[$now_proj] gates=[$now_gates]）"
    return 1
  fi
  return 0
}

mr_promise_roster() { # <KEY>
  local key="$1"
  local d a
  d="$(new_fixture promise-roster)" || return 1
  a="$d/.pi/team/state/config.log"
  mr_run "$d" add-agent routescheck --register --no-install
  if [ "$MR_RC" != "0" ] || ! grep -q '^TEAM_AGENTS=.*routescheck' "$d/.pi/team/config.sh"; then
    finding "promise（$key）：team add-agent routescheck --register 没有改 TEAM_AGENTS（rc=$MR_RC；$(first_line "$MR_OUT")）"
    return 1
  fi
  if tail -1 "$a" 2>/dev/null | grep -q 'result=ok actor=cli key=TEAM_AGENTS'; then
    ok "promise（$key）：注册改了名册行并落一行 result=ok actor=cli（TEAM_AGENTS）"
  else
    finding "promise（$key）：注册改了名册行但没有审计行（$(tail -1 "$a" 2>/dev/null)）"
    return 1
  fi
  mr_run "$d" teardown --agent routescheck --register
  if [ "$MR_RC" = "0" ] && ! grep -q 'routescheck' "$d/.pi/team/config.sh"; then
    ok "promise（$key）：teardown --register 从名册移除该席位（同一条写入器）"
  else
    finding "promise（$key）：teardown --register 没有移除席位（rc=$MR_RC；$(first_line "$MR_OUT")）"
    return 1
  fi
  return 0
}

mr_promise_seat_model() { # <KEY>
  local key="$1" d
  d="$(new_fixture promise-seat-model)" || return 1
  mr_run "$d" config set-agent-model dev vendor/m9
  if [ "$MR_RC" != "0" ] || ! grep -q "^TEAM_AGENT_MODELS='dev=vendor/m9'" "$d/.pi/team/config.sh"; then
    finding "promise（$key）：set-agent-model 没写进 TEAM_AGENT_MODELS（rc=$MR_RC；$(first_line "$MR_OUT")）"
    return 1
  fi
  if ! tail -1 "$d/.pi/team/state/config.log" | grep -q 'result=ok .*key=TEAM_AGENT_MODELS'; then
    finding "promise（$key）：set-agent-model 没有审计行"
    return 1
  fi
  mr_run "$d" config list --json
  if printf '%s' "$MR_OUT" | grep -q '"agent":"dev","model":"vendor/m9".*"override":true'; then
    ok "promise（$key）：席位行写入、审计，读侧的 dev 席位带着 vendor/m9 与 override:true"
  else
    finding "promise（$key）：读侧的 dev 席位没有带 vendor/m9/override:true"
    return 1
  fi
  return 0
}

mr_promise_pm_model() { # <KEY>
  local key="$1" d
  d="$(new_fixture promise-pm-model)" || return 1
  mr_run "$d" config set-agent-model pm vendor/pm9
  [ "$MR_RC" = "0" ] || { finding "promise（$key）：set-agent-model pm 失败（$(first_line "$MR_OUT")）"; return 1; }
  mr_run "$d" up --print
  if printf '%s' "$MR_OUT" | grep -q -- '--provider vendor --model pm9'; then
    ok "promise（$key）：team up --print 渲染出的命令带着 --provider vendor --model pm9"
  else
    finding "promise（$key）：team up --print 的命令没带 --provider vendor --model pm9"
    return 1
  fi
  return 0
}

mr_promise_pulse_window() { # <KEY>
  local key="$1" d
  d="$(new_fixture promise-pulse-window)" || return 1
  mr_run "$d" config set TEAM_PULSE_WINDOW pulse9 --yes
  [ "$MR_RC" = "0" ] || { finding "promise（$key）：设置 TEAM_PULSE_WINDOW 失败（$(first_line "$MR_OUT")）"; return 1; }
  : > "$TMUX_LOG"
  mr_run "$d" pulse up
  if grep -qE 'new-window .*-n pulse9( |$)' "$TMUX_LOG"; then
    ok "promise（$key）：pulse up 记下的 new-window 用新窗口名 pulse9（rc=$MR_RC，不看退出码）"
  else
    finding "promise（$key）：pulse up 没有按新窗口名建窗（记录：$(grep -c . "$TMUX_LOG" 2>/dev/null || echo 0) 条 tmux 调用）"
    return 1
  fi
  return 0
}

mr_promise_default_model() { # <KEY>
  local key="$1" d br
  d="$(new_fixture promise-default-model)" || return 1
  mkdir -p "$d/docs/team/tasks" "$d/openspec/specs/routes"
  cat > "$d/docs/team/tasks/T1-anchor.md" <<'BRIEF'
# T1 · fixture

```
task:   T1
agent:  dev
change: -
specs:  routes#The fixture requirement
phase:  apply
deps:   -
status: todo
```

body
BRIEF
  printf '### Requirement: The fixture requirement\n\nfixture\n' > "$d/openspec/specs/routes/spec.md"
  br="$( cd "$d" && env -u TMUX -u TMUX_PANE PATH="$SHIM:$PATH" bash -c '
      . "$0/skills/teamsmith/scripts/lib/common.sh"
      for f in "$0"/skills/teamsmith/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
      team_load_config >/dev/null 2>&1
      TEAM_DOCS_ABS="${TEAM_DOCS_ABS:-$TEAM_MAIN_ROOT/$TEAM_DOCS_DIR}"
      team_branch_for_agent "$1" "$2"' "$tree" dev T1 )"
  [ -n "$br" ] || { finding "promise（$key）：夹具算不出任务分支"; return 1; }
  if ! git -C "$d" worktree add -b "$br" "$d/.worktrees/dev" main >/dev/null 2>&1; then
    finding "promise（$key）：夹具建不出 worktree"; return 1
  fi
  rm -f "$d/.pi/team/state/dev.env"
  mr_run "$d" config set TEAM_DEFAULT_MODEL vendor/dm9 --yes
  [ "$MR_RC" = "0" ] || { finding "promise（$key）：设置 TEAM_DEFAULT_MODEL 失败"; return 1; }
  mr_run "$d" dispatch dev T1 docs/team/tasks/T1-anchor.md --print
  if printf '%s' "$MR_OUT" | grep -q -- '--provider vendor --model dm9'; then
    ok "promise（$key）：dispatch --print 渲染出的启动命令带着 --provider vendor --model dm9"
  else
    finding "promise（$key）：dispatch --print 没带 --provider vendor --model dm9（rc=$MR_RC；$(first_line "$MR_OUT")）"
    return 1
  fi
  return 0
}

# ── Walk C（P140 · dispatch-friction）· 拒绝路线：每条打印出来的 修法/改行 都真的能粘 ──────────────
#
# 两个判定：
#   C1 目录对账：cmd-agents.sh 里每一条 `修法：`/`改行：` 发射必须被下面的 family 表认领（认领片段）；
#      没人认领 = finding —— 新守卫的路线不能绕过走查（"印了一条没人走过"就是缺陷）。
#   C2 逐族走查：每个 family 在一个全新夹具里跑一次拒绝命令 → 期望的阻塞项 + 路线；把**打印出来的**
#      路线原样粘回去（`改行：` 写进任务书头，`修法：` 当命令跑）；重跑要求阻塞项消失（clear）
#      或按覆盖契约兑现（force：警告 + 真拉起时恰好多一行审计）。
#
# 夹具纪律：一律 new_fixture（私有 git 仓库 + 私有身份）、PATH 最前是录制 shim（假窗口但真启动证据）、
# stdin /dev/null、每条命令有硬超时；没有一条命令能碰到调用者的项目或真 tmux。
RC_CLAIMS=(
  'dirty-stash|修法：git -C %q stash push -u -m %q'
  'branch-create|修法：git -C %q switch -c %q'
  'branch-switch|修法：git -C %q switch %q'
  'worktree-add|修法：git -C %q worktree add -b %q'
  'briefs|修法：git -C %q mv %q %q'
  'stack-resume|修法：$TEAM_CLI resume --agent $agent'
  'force|修法：$TEAM_CLI dispatch $agent $id $brief --force'
  'branch-decl|修法：$TEAM_CLI dispatch $agent $id $brief --branch $derived'
  'change-line|改行：change: '
  'deltas-line|改行：deltas: '
  'branch-line|改行：branch: '
  'config-agent-bin|修法：$TEAM_CLI config set TEAM_AGENT_BIN'
  'config-pi-bin|修法：$TEAM_CLI config set TEAM_PI_BIN'
  'session-fresh|修法：$TEAM_CLI dispatch $agent $id $taskfile --fresh'
  'session-overflow|修法：$TEAM_CLI dispatch $agent $id $taskfile --allow-overflow'
  'capacity-override|修法：$(team_dispatch_mem_fix_cmd'
)
RC_EXTRA=()
RC_PI_BIN=""
RC_OMIT_PI_BIN=0
RC_FAKE_LAUNCH=0

# rc_team <dir> <team 参数…> → 组合输出；rc = 被测 CLI 的 rc
rc_team() {
  local d="$1"; shift
  local -a e=(env -u TMUX -u TMUX_PANE "PATH=$SHIM:$PATH" "TEAM_ROUTES_WINDOWS=$WINREG"
              "TEAM_ROUTES_TMUX_LOG=$TMUX_LOG" "TEAM_MEETINGS_DIR=$d/.meetings" "TEAM_PI_AGENT_DIR=$d/.pi-agent")
  [ "$RC_OMIT_PI_BIN" = "1" ] || e+=("TEAM_PI_BIN=${RC_PI_BIN:-/bin/true}")
  [ "$RC_FAKE_LAUNCH" = "1" ] && e+=("TEAM_ROUTES_FAKE_LAUNCH=1" "TEAM_DISPATCH_VERIFY_SEC=2" "TEAM_DISPATCH_ALIVE_SEC=0")
  [ "${#RC_EXTRA[@]}" -gt 0 ] && e+=("${RC_EXTRA[@]}")
  ( cd "$d" && ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} "${e[@]}" bash "$team" "$@" </dev/null 2>&1 )
}

# rc_sh <dir> <命令字符串> → 把打印出来的路线原样当命令跑（fake launch 开着）
rc_sh() {
  local d="$1" cmd="$2"
  local -a e=(env -u TMUX -u TMUX_PANE "PATH=$SHIM:$PATH" "TEAM_ROUTES_WINDOWS=$WINREG"
              "TEAM_ROUTES_TMUX_LOG=$TMUX_LOG" "TEAM_MEETINGS_DIR=$d/.meetings" "TEAM_PI_AGENT_DIR=$d/.pi-agent"
              "TEAM_ROUTES_FAKE_LAUNCH=1" "TEAM_DISPATCH_VERIFY_SEC=2" "TEAM_DISPATCH_ALIVE_SEC=0")
  [ "$RC_OMIT_PI_BIN" = "1" ] || e+=("TEAM_PI_BIN=${RC_PI_BIN:-/bin/true}")
  [ "${#RC_EXTRA[@]}" -gt 0 ] && e+=("${RC_EXTRA[@]}")
  ( cd "$d" && ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} "${e[@]}" bash -c "$cmd" </dev/null 2>&1 )
}

# rc_canon <dir> <ID> [agent] → 被测 CLI 给这个任务推导出的分支名
rc_canon() {
  local d="$1" id="$2" agent="${3:-dev}"
  ( cd "$d" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR -u TEAM_PROJECT -u TEAM_SESSION \
      bash -c '
        . "'"$skill"'/scripts/lib/common.sh"
        for _f in "'"$skill"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done
        team_load_config >/dev/null 2>&1
        team_branch_for_agent "$1" "$2"' _ "$agent" "$id" )
}

# rc_brief <dir> <ID> <change> <anchor> <deltas> [phase] [agent] [branch-line] → 打印任务书路径
rc_brief() {
  local d="$1" id="$2" change="$3" anchor="$4" deltas="$5" phase="${6:-apply}" agent="${7:-dev}" br="${8:-}" f
  f="$d/docs/team/tasks/$id-fixture.md"
  mkdir -p "$d/docs/team/tasks"
  {
    printf '# %s · fixture\n\n```\n' "$id"
    printf 'task:   %s\nagent:  %s\nissue:  -\n' "$id" "$agent"
    [ -n "$br" ] && printf 'branch: %s\n' "$br"
    printf 'change: %s\nspecs:  -\nanchor: %s\nphase:  %s\n' "$change" "$anchor" "$phase"
    printf 'deltas: %s\ndeps:   -\nstatus: todo\nbudget: -\n```\n\nbody\n' "$deltas"
  } > "$f"
  printf '%s\n' "$f"
}

rc_board() { # <dir> <ID> <title> [status]
  local d="$1" id="$2" title="$3" st="${4:-todo}"
  rc_team "$d" board add "$id" "$title" dev - - >/dev/null 2>&1 || true
  [ "$st" = "todo" ] || rc_team "$d" board set "$id" "$st" >/dev/null 2>&1 || true
}

rc_wt() { # <dir> <agent> <branch>
  local d="$1" a="$2" br="$3"
  git -C "$d" worktree add -q -b "$br" "$d/.worktrees/$a" main >/dev/null 2>&1 \
    || git -C "$d" worktree add -q "$d/.worktrees/$a" "$br" >/dev/null 2>&1 || true
}

rc_route() { # <输出> <片段> → 提取打印出来的路线（**原样**：去标记与首尾空白，不剥尾注）
  local out="$1" frag="$2" line txt
  line="$(printf '%s\n' "$out" | grep -aF -- "$frag" | head -1)"
  [ -n "$line" ] || return 1
  case "$line" in
    *修法：*) txt="${line#*修法：}" ;;
    *改行：*) txt="${line#*改行：}" ;;
    *) return 1 ;;
  esac
  # P151（F1/F2）：不再在「（」处截断 —— 打印出来的**整行**就是整条命令（命令与说明分行）。
  # 这一行就是原样粘贴回归的判据：任何还留在路线行上的说明文字都会让下面的粘贴失败。
  printf '%s\n' "$(printf '%s' "$txt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
}

rc_apply_line() { # <任务书> <字段> <确切行>：把该字段的现有行换成这条
  local f="$1" field="$2" line="$3" tmp="$1.p140tmp"
  awk -v field="$field" -v line="$line" '
    index($0, field ":") == 1 { if (!done) { print line; done=1 } ; next }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

rc_audit_lines() { local f="$1/.pi/team/state/watchdog.log"; if [ -f "$f" ]; then wc -l < "$f" | tr -d ' '; else printf '0'; fi; }

# rc_case <family> <期望阻塞项正则> <路线片段> <apply:line:<字段>|apply:cmd> <rerun:same|route> <effect:clear|proceed|force|resume> [<重跑额外断言片段>]
rc_case() {
  local fam="$1" expect="$2" frag="$3" apply="$4" rerun="$5" effect="$6" extra="${7:-}"
  local d="$RC_DIR" b="$RC_BRIEF" out rc route audit0 audit1 out2="" rc2=0
  apply="${apply#apply:}"    # 调用点写 apply:cmd / apply:line:<字段>，这里归一到 cmd / line:<字段>
  out="$(rc_team "$d" "${RC_CMD[@]}")"; rc=$?
  if [ "$rc" -eq 0 ]; then finding "C2/$fam：拒绝命令没有拒绝（rc=0）"; return 1; fi
  if ! printf '%s' "$out" | grep -aqE -- "$expect"; then
    finding "C2/$fam：拒绝输出里没有期望的阻塞项（$expect）：$(first_line "$out")"; return 1
  fi
  route="$(rc_route "$out" "$frag")" || { finding "C2/$fam：拒绝输出里没有路线（片段 $frag）"; return 1; }
  audit0="$(rc_audit_lines "$d")"
  case "$apply" in
    line:*)
      rc_apply_line "$b" "${apply#line:}" "$route"
      out2="$(rc_team "$d" "${RC_CMD[@]}")"; rc2=$?
      ;;
    cmd)
      if [ "$rerun" = "route" ]; then
        out2="$(rc_sh "$d" "$route")"; rc2=$?
      else
        rc_sh "$d" "$route" >/dev/null 2>&1 || true
        out2="$(rc_team "$d" "${RC_CMD[@]}")"; rc2=$?
      fi
      ;;
  esac
  case "$effect" in
    clear)
      if printf '%s' "$out2" | grep -aqE -- "$expect"; then
        finding "C2/$fam：粘了路线后阻塞项还在（$expect）"
      elif [ "$rc2" != "0" ]; then
        finding "C2/$fam：路线清了阻塞项但重跑仍失败（rc=$rc2）：$(first_line "$out2")"
      else
        ok "C2/$fam：$([ "$apply" = "cmd" ] && echo '修法' || echo '改行')路线让阻塞项消失（$(printf '%s' "$route" | cut -c1-72)）"
      fi ;;
    proceed)
      if [ "$rc2" != "0" ]; then
        finding "C2/$fam：路线没有兑现（rc=$rc2）：$(first_line "$out2")"
      elif [ -n "$extra" ] && ! printf '%s' "$out2" | grep -aqF -- "$extra"; then
        finding "C2/$fam：重跑缺少期望的说明（$extra）"
      else
        ok "C2/$fam：打印出来的路线真的能跑（rc=0${extra:+；$extra}）"
      fi ;;
    force)
      audit1="$(rc_audit_lines "$d")"
      if [ "$rc2" != "0" ]; then
        finding "C2/$fam：--force 路线没有兑现（rc=$rc2）：$(first_line "$out2")"
      elif ! printf '%s' "$out2" | grep -aqF '显式覆盖'; then
        finding "C2/$fam：重跑没有打印覆盖警告（不许静默接管）"
      elif [ "$((audit1 - audit0))" != "1" ]; then
        finding "C2/$fam：覆盖后应恰好多一行审计（$audit0 → $audit1）"
      else
        ok "C2/$fam：覆盖路线兑现（警告 + 恰好多一行审计 $audit0 → $audit1）"
      fi ;;
    resume)
      if [ "$rc2" != "0" ] || ! printf '%s' "$out2" | grep -aqF -- "$extra"; then
        finding "C2/$fam：继续旧任务的路线没有兑现（rc=$rc2）：$(first_line "$out2")"
      else
        ok "C2/$fam：路线让旧任务继续（$extra）"
      fi ;;
  esac
}

mr_refusals_catalog() {
  local f="$skill/scripts/lib/cmd-agents.sh" line hit claim n=0 claimed=0
  [ -f "$f" ] || { finding "C1：找不到派单文案目录：$f"; return 0; }
  while IFS= read -r line; do
    case "$line" in
      *修法：*|*改行：*) ;;
      *) continue ;;
    esac
    [[ "$line" =~ ^[[:space:]]*# ]] && continue      # 注释（含缩进注释）里提到标记不算发射
    n=$((n + 1))
    claim=""
    for hit in "${RC_CLAIMS[@]}"; do
      case "$line" in *"${hit#*|}"*) claim="${hit%%|*}"; break ;; esac
    done
    if [ -z "$claim" ]; then
      finding "C1：没人认领的路线发射（family 表里没有条目）：$(printf '%s' "$line" | sed 's/^[[:space:]]*//' | cut -c1-110)"
    else
      claimed=$((claimed + 1))
    fi
  done < "$f"
  if [ "$n" -eq 0 ]; then
    finding "C1：没有扫到任何路线发射（$f 里一条都没有？）"
  elif [ "$n" -eq "$claimed" ]; then
    ok "C1：$n 条路线发射全部被 family 表认领（$(printf '%s\n' "${RC_CLAIMS[@]}" | cut -d'|' -f1 | sort -u | wc -l | tr -d ' ') 个 family）"
  fi
}

mr_refusals() {
  section "refusals · 拒绝路线：每条打印的 修法/改行 都被粘回去并且真的生效（P140）"
  mr_refusals_catalog
  local d b br wt

  # ① 脏工作树（换任务）→ 修法：git -C … stash push
  d="$(new_fixture refuse-dirty)"; RC_DIR="$d"
  rc_board "$d" OLD "OLD fixture" dropped
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  printf 'wip from OLD\n' > "$d/.worktrees/dev/wip.txt"
  mkdir -p "$d/.pi/team/state"
  printf 'task=OLD\nworktree=%s\ntaskfile=%s\nbranch=%s\n' "$d/.worktrees/dev" "$d/docs/team/tasks/OLD-fixture.md" "$br" > "$d/.pi/team/state/dev.env"
  rc_brief "$d" OLD - "none (infra) — fixture" - >/dev/null
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case dirty-stash '有 1 个未提交改动.*属于上一个任务 OLD' '修法：git -C' 'apply:cmd' same clear
  # ② 工作树停在别的任务的分支上 → 修法：git -C … switch（清掉）
  d="$(new_fixture refuse-branch-switch)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  rc_wt "$d" dev task/P9-other
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case branch-switch '停在不属于本任务（P1）的分支上' ' switch ' 'apply:cmd' same clear

  # ③ 工作树 detached → 修法：git -C … switch -c（建好并切过去）
  d="$(new_fixture refuse-branch-create)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  git -C "$d" worktree add -q --detach "$d/.worktrees/dev" main >/dev/null 2>&1 || true
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case branch-create 'detached HEAD' ' switch -c ' 'apply:cmd' same clear

  # ④ 工作树不存在 → 修法：git -C … worktree add -b（PM 该跑的那条命令）
  d="$(new_fixture refuse-worktree-add)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case worktree-add 'worktree 不存在' ' worktree add -b ' 'apply:cmd' same clear

  # ⑤ 同一个 ID 两份任务书 → 修法：git mv 把过期那份改名出 glob
  d="$(new_fixture refuse-briefs)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  rc_brief "$d" P1-stale - "none (infra) — fixture" - >/dev/null
  # 路线是 git mv：真实项目里任务书受版本控制（未跟踪的文件 git mv 会拒）——夹具照现实提交
  git -C "$d" add -A >/dev/null 2>&1 && git -C "$d" -c user.email=routes@teamsmith -c user.name=routes commit -qm briefs >/dev/null 2>&1 || true
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case briefs '有多份任务书' ' mv ' 'apply:cmd' same clear

  # ⑥ change: 行尾随文字 → 改行：change: <第一个合法 id>
  d="$(new_fixture refuse-change-line)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 'panel（说明）' - -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case change-line 'change: 行不合法' '改行：change: ' 'apply:line:change' same clear

  # ⑦ change: 两行 → 改行：change: alpha（把该字段的行全部换成这一条）
  #    R2 的"第一行就带示例与原因"在同一夹具里再纬一次（两行的原因点名）
  d="$(new_fixture refuse-change-line-two)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 alpha - -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  printf 'change: beta\n' >> "$b"
  out="$(rc_team "$d" dispatch dev P1 "$b" --print)" || true
  case "$(printf '%s\n' "$out" | head -1)" in
    *合法示例*change:*) ok "C2/change-line：第二行 change: 时首行带具体原因与合法示例" ;;
    *) finding "C2/change-line：两行 change: 的首行没有示例：$(printf '%s\n' "$out" | head -1 | cut -c1-160)" ;;
  esac
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case change-line 'change: 有 2 行' '改行：change: ' 'apply:line:change' same clear

  # ⑧ deltas: 三种畸形 → 改行：deltas: <建议>；逗号列表本身被接受（控制组）
  d="$(new_fixture refuse-deltas-line)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  b="$(rc_brief "$d" P1 alpha - 'panel · verification')"; RC_BRIEF="$b"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case deltas-line 'deltas: 行不合法' '改行：deltas: ' 'apply:line:deltas' same clear
  for pair in 'panel,|尾部空项' 'panel verification|空白不是分隔符'; do
    val="${pair%%|*}"; why="${pair#*|}"
    b="$(rc_brief "$d" P1 alpha - "$val")"; RC_BRIEF="$b"
    out="$(rc_team "$d" dispatch dev P1 "$b" --print)" || true
    case "$(printf '%s\n' "$out" | head -1)" in
      *合法示例*deltas:*) ok "C2/deltas-line[$val]：首行带具体原因（$why）与合法示例" ;;
      *) finding "C2/deltas-line[$val]：首行没有示例：$(printf '%s\n' "$out" | head -1 | cut -c1-160)" ;;
    esac
    RC_CMD=(dispatch dev P1 "$b" --print)
    rc_case "deltas-line[$val]" 'deltas: 行不合法' '改行：deltas: ' 'apply:line:deltas' same clear
  done
  b="$(rc_brief "$d" P1 alpha - 'panel, verification')"; RC_BRIEF="$b"
  RC_CMD=(dispatch dev P1 "$b" --print)
  if rc_team "$d" "${RC_CMD[@]}" >/dev/null 2>&1; then ok "C2/deltas-line：示例形状 \`panel, verification\` 真的被接受（控制组）"
  else finding "C2/deltas-line：示例形状却没被接受"; fi

  # ⑨ 任务书 branch: 行指到别的任务 → 改行：branch: <本任务分支>
  d="$(new_fixture refuse-branch-line)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" - apply dev task/P9-other)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case branch-line '分支声明不属于本任务' '改行：branch: ' 'apply:line:branch' same clear

  # ⑩ --branch 指到别的任务 → 修法：用本任务的 --branch 重派（路线本身就是重跑命令）
  d="$(new_fixture refuse-branch-decl)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --branch task/P9-other --print)
  rc_case branch-decl '分支声明不属于本任务' '修法：team dispatch' 'apply:cmd' route proceed
  # ⑪ 叠任务 → 修法一 resume（让旧任务继续）/ 修法二 --force（覆盖 + 一行审计）
  d="$(new_fixture refuse-stack)"; RC_DIR="$d"
  rc_board "$d" OLD "OLD fixture" wip
  rc_board "$d" P1 "P1 fixture"
  rc_brief "$d" OLD - "none (infra) — fixture" - >/dev/null
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  mkdir -p "$d/.pi/team/state"
  printf 'task=OLD\nworktree=%s\ntaskfile=%s\nbranch=%s\n' "$d/.worktrees/dev" "$d/docs/team/tasks/OLD-fixture.md" "$br" > "$d/.pi/team/state/dev.env"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case stack-force '还有一个没结束的任务' '修法：team dispatch' 'apply:cmd' route force

  # ⑪b 叠任务 · resume 路线：先收尾旧任务（honored：旧任务的窗口真的被拉起，不是 cleared）
  #     夹具与 ⑪ 不同：工作树停在 OLD 自己的分支上（resume OLD 要被放行）
  d="$(new_fixture refuse-stack-resume)"; RC_DIR="$d"
  rc_board "$d" OLD "OLD fixture" wip
  rc_board "$d" P1 "P1 fixture"
  rc_brief "$d" OLD - "none (infra) — fixture" - >/dev/null
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br_old="$(rc_canon "$d" OLD)"; rc_wt "$d" dev "$br_old"
  mkdir -p "$d/.pi/team/state"
  printf 'task=OLD\nworktree=%s\ntaskfile=%s\nbranch=%s\n' "$d/.worktrees/dev" "$d/docs/team/tasks/OLD-fixture.md" "$br_old" > "$d/.pi/team/state/dev.env"
  RC_CMD=(dispatch dev P1 "$b" --print)
  out="$(rc_team "$d" "${RC_CMD[@]}")" || true
  route="$(rc_route "$out" '修法：team resume') || true"
  if [ -z "$route" ]; then
    finding "C2/stack-resume：叠任务拒绝里没有 resume 路线"
  else
    out2="$(rc_sh "$d" "$route")"; rc2=$?
    if [ "$rc2" != "0" ] || ! printf '%s' "$out2" | grep -aqF 'dispatched OLD'; then
      finding "C2/stack-resume：resume 路线没有把旧任务交回座位（rc=$rc2）：$(first_line "$out2")"
    else
      ok "C2/stack-resume：resume 路线真的让旧任务继续（dispatched OLD，rc=0）"
    fi
  fi

  # ⑫ 没有 change 也没有锚 → 修法：--force（覆盖 + 一行审计）
  d="$(new_fixture refuse-anchor)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - - -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case anchor-force '必须声明它的锚' '修法：team dispatch' 'apply:cmd' route force

  # ⑬ delta 单写者冲突 → 修法：--force
  d="$(new_fixture refuse-delta-writer)"; RC_DIR="$d"
  rc_board "$d" SIB "SIB fixture" wip
  rc_board "$d" P1 "P1 fixture"
  rc_brief "$d" SIB alpha - panel >/dev/null
  b="$(rc_brief "$d" P1 alpha - panel)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case delta-writer-force '单写者规则' '修法：team dispatch' 'apply:cmd' route force

  # ⑭ verify 席位 = apply 作者 → 修法：--force
  d="$(new_fixture refuse-verify-seat)"; RC_DIR="$d"
  rc_board "$d" AP "AP fixture" wip
  rc_board "$d" V1 "V1 fixture"
  rc_brief "$d" AP alpha - panel apply dev >/dev/null
  b="$(rc_brief "$d" V1 alpha - - verify dev)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" V1)"; rc_wt "$d" dev "$br"
  RC_CMD=(dispatch dev V1 "$b" --print)
  rc_case verify-seat-force 'verification 不独立' '修法：team dispatch' 'apply:cmd' route force

  # ⑮ TEAM_PI_BIN 解析不到 → 修法：team config set TEAM_PI_BIN "$(command -v pi)"
  d="$(new_fixture refuse-config-pi)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  sed -i 's|^TEAM_PI_BIN=.*|TEAM_PI_BIN="/nonexistent/pi-fixture"|' "$d/.pi/team/config.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SHIM/pi"; chmod +x "$SHIM/pi"
  RC_OMIT_PI_BIN=1
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case config-pi-bin '找不到 pi 可执行文件' '修法：team config set TEAM_PI_BIN' 'apply:cmd' same clear
  RC_OMIT_PI_BIN=0

  # ⑯ 自定义 adapter 的可执行文件解析不到 → 修法：team config set TEAM_AGENT_BIN
  d="$(new_fixture refuse-config-agent)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  sed -i 's|^TEAM_AGENT_CMD=.*|TEAM_AGENT_CMD="fakeagent --run {prompt_file}"|' "$d/.pi/team/config.sh"
  sed -i 's|^TEAM_AGENT_BIN=.*|TEAM_AGENT_BIN="/nonexistent/fakeagent"|' "$d/.pi/team/config.sh"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SHIM/fakeagent"; chmod +x "$SHIM/fakeagent"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case config-agent-bin '找不到 agent 可执行文件' '修法：team config set TEAM_AGENT_BIN' 'apply:cmd' same clear

  # ⑰ 会话超过窗口 → 修法：--fresh / --allow-overflow
  d="$(new_fixture refuse-session)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  printf 'TEAM_MODEL_WINDOWS="deepseek/deepseek-flash=8"\n' >> "$d/.pi/team/config.sh"
  enc="$(printf '%s' "$d/.worktrees/dev" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
  mkdir -p "$d/.pi-agent/sessions/--$enc--"
  printf '%s\n' "$(head -c 400 /dev/zero | tr '\0' 'x')" > "$d/.pi-agent/sessions/--$enc--/x_routes-refuse-session-dev.jsonl"
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case session-fresh '拒绝复用这个会话' '修法：team dispatch' 'apply:cmd' route proceed
  out="$(rc_team "$d" "${RC_CMD[@]}")" || true
  route="$(printf '%s\n' "$out" | grep -aF '修法：team dispatch' | grep -aF -- '--allow-overflow' | head -1 | sed 's/.*修法：//; s/（.*//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)"
  if [ -z "$route" ]; then
    finding "C2/session-overflow：拒绝输出里没有 --allow-overflow 路线"
  else
    out2="$(rc_sh "$d" "$route")"; rc2=$?
    if [ "$rc2" != "0" ] || ! printf '%s' "$out2" | grep -aqF '显式放行'; then
      finding "C2/session-overflow：路线没有兑现（rc=$rc2）"
    else
      ok "C2/session-overflow：路线按自己的契约兑现（显式放行警告，rc=0）"
    fi
  fi

  # ⑱ 容量底线拒绝 → 修法：显式降低底线重派（覆盖路线：真的放行）；「等一个席位」是建议行，不是路线
  d="$(new_fixture refuse-capacity)"; RC_DIR="$d"
  rc_board "$d" P1 "P1 fixture"
  b="$(rc_brief "$d" P1 - "none (infra) — fixture" -)"; RC_BRIEF="$b"
  br="$(rc_canon "$d" P1)"; rc_wt "$d" dev "$br"
  printf 'MemTotal:       32768000 kB\nMemFree:        1024000 kB\nMemAvailable:    102400 kB\nSwapTotal:     16777216 kB\nSwapFree:       8388608 kB\n' > "$d/meminfo-low"
  printf 'Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority\n/var/swapfile                           file\t\t67108860\t1048576\t\t-1\n' > "$d/swaps-plenty"
  RC_EXTRA=("TEAM_MEMINFO_FILE=$d/meminfo-low" "TEAM_SWAPFILE_PATH=$d/swaps-plenty" "TEAM_MIN_AVAIL_MB=1024")
  RC_CMD=(dispatch dev P1 "$b" --print)
  rc_case capacity-override 'MemAvailable 只剩' '修法：TEAM_MIN_AVAIL_MB=0' 'apply:cmd' route proceed "dispatched P1"
  RC_EXTRA=()
}

# ── flips: scratch trees that MUST redden the walk ──────────────────────────────────────────────────
mr_scratch_tree() { # <name> → 打印 scratch 树（skills/teamsmith + skills/teamsmith-init 的最小副本）
  local name="$1"
  local s="$tmp/$name"
  rm -rf "$s"; mkdir -p "$s/skills/teamsmith"
  cp -a "$skill/scripts" "$skill/references" "$skill/templates" "$s/skills/teamsmith/" 2>/dev/null || true
  # perf.sh 是 source 模式的声明文件（walk 要读它），scratch 树也得有。
  mkdir -p "$s/skills/teamsmith/tests"
  cp -a "$skill/tests/perf.sh" "$s/skills/teamsmith/tests/perf.sh" 2>/dev/null || true
  printf '%s\n' "$s"
}

# mr_flip_run <scratch> <section...> → 在 scratch 树上跑 walk 子集；日志落在 $tmp/flip-run.log
#   （路径记进 MR_FLIP_LOGF：判据读**文件**，不再把日志搬进变量再走管道 —— 见 mr_flip_log_has）
mr_flip_run() {
  local scratch="$1"; shift
  MR_FLIP_LOGF="$tmp/flip-run.log"
  # TEAM_ROUTES_NESTED：flips 在 scratch 树上跑 walk —— 嵌套 run 永不跑 flips（结构上的不递归守卫，
  # 与段集规则双保险：谁给嵌套 run 传 flips 都只会打印一行 skip）。
  env -u TMUX -u TMUX_PANE TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE="$scratch" bash "$here/routes.sh" "$@" >"$MR_FLIP_LOGF" 2>&1
  MR_FLIP_RC=$?
  # TEAM_TMP_KEEP=1 时嵌套 run 的助手会保留自己的根并**打印路径**——收起来给收尾的可见说明用
  # （$tmp/flip-run.log 每次覆盖，只有这里攒得下每一个保留的根）。
  grep -a '^保留临时根：' "$MR_FLIP_LOGF" 2>/dev/null >>"$tmp/kept-roots.log" || true
}

# mr_flip_log_has <literal…> → 0 = 本次嵌套 run 的日志里逐字都在（**直接读文件**，不走管道）
#   P202：旧写法 `printf '%s' "$MR_FLIP_LOG" | grep -q …` 在 set -o pipefail 下会假红 —— grep -q 一命中
#   就退出，仍在写的 printf 收 SIGPIPE(141)，整条管道变非 0，判据于是把「红且点名」读成「没有兑现」
#   （现场：同一段日志既被当证据贴出来、又被判成没兑现）。实测：170KB 日志、命中点在中间 → 3/3 误判。
mr_flip_log_has() {
  local p
  for p in "$@"; do grep -qF -- "$p" "$MR_FLIP_LOGF" || return 1; done
  return 0
}

# mr_flip_evidence → 「没有兑现」时贴的现场：优先前两条**真 finding**（红色 ✗；正文里那个 ✗ 是
#   用法行的标记，不是 finding）；一条都没有时贴日志尾巴（例如嵌套 run 起不来时只有一句 setup 失败）。
mr_flip_evidence() {
  local ev
  ev="$(grep -aF -e $'\033[31m✗' "$MR_FLIP_LOGF" 2>/dev/null | head -2 | tr '\n' ' ')"
  [ -n "$ev" ] || ev="$(grep -a . "$MR_FLIP_LOGF" 2>/dev/null | tail -2 | tr '\n' ' ')"
  printf '%s' "$ev"
}

# mr_flip_cnt <file> <literal> → 含该文本的行数（文件不在/无命中都是 0）
mr_flip_cnt() { grep -cF -- "$2" "$1" 2>/dev/null || true; }

# mr_flip_landed <label> <scratch> <rel-path> <gone|-> <present|-> → 0 = 变异落地；1 = 没落地
#   纯判据（不发 finding，理由写在 MR_FLIP_WHY）：红侧要的就是「没落地」这个判定本身；
#   翻转本身用 mr_flip_require。
#   变异**前**的状态取自真树（副本是它的 cp -a），**后**取自副本：
#     a) 副本必须与真树逐字节不同 —— 「补丁静默 no-op」在这里就断了；
#     b) <gone>（≠ -）：真树 ≥1 → 副本 0（目标文本由 1 变 0；模式陈旧当场露馅）；
#     c) <present>（≠ -）：真树 0 → 副本 ≥1（新文本由 0 变 1；只删不插、只插不删都过不去）。
#   任一不成立 → MR_FLIP_WHY 写成原因并返回 1 —— 这是**夹具缺陷**，不是「没有兑现」；外层的嵌套 run
#   由调用者跳过（既然没改到东西，判它红不红没有信息）。
mr_flip_landed() {
  local label="$1" scratch="$2" rel="$3" gone="$4" present="$5"
  local real="$skill/$rel" copy="$scratch/skills/teamsmith/$rel" g n p
  MR_FLIP_WHY=""
  if [ ! -f "$copy" ]; then
    MR_FLIP_WHY="$rel 在副本里不存在（cp 没落或路径变了）"
  elif cmp -s "$real" "$copy"; then
    MR_FLIP_WHY="$rel 与真树逐字节相同 —— 变异一个字都没改"
  elif [ "$gone" != "-" ]; then
    g="$(mr_flip_cnt "$real" "$gone")"; n="$(mr_flip_cnt "$copy" "$gone")"
    if [ "${g:-0}" -lt 1 ]; then MR_FLIP_WHY="目标文本在真树里就找不到（模式已陈旧）：gone 0→${n:-0}"
    elif [ "${n:-0}" -ne 0 ]; then MR_FLIP_WHY="目标文本还在：gone ${g:-0}→${n:-0}（替换没匹配上）"; fi
  fi
  if [ -z "$MR_FLIP_WHY" ] && [ "$present" != "-" ]; then
    g="$(mr_flip_cnt "$real" "$present")"; p="$(mr_flip_cnt "$copy" "$present")"
    if [ "${g:-0}" -ne 0 ]; then MR_FLIP_WHY="新文本在真树里本来就有（判据不成立）：present ${g:-0}→${p:-0}"
    elif [ "${p:-0}" -lt 1 ]; then MR_FLIP_WHY="新文本没出现：present 0→${p:-0}"; fi
  fi
  [ -z "$MR_FLIP_WHY" ] && return 0
  return 1
}

# mr_flip_require <label> <scratch> <rel-path> <gone|-> <present|-> → 落地则 0；没落地则发 finding 并返回 1
mr_flip_require() {
  mr_flip_landed "$1" "$2" "$3" "$4" "$5" && return 0
  finding "$1：变异没落地（夹具缺陷）—— $MR_FLIP_WHY"
  return 1
}

# 嵌套 run 的根：本轮台账里 kind=routes 且 pid 不是本进程的存活根，加上文件系统里新于本夹具根的
# owned 家族目录（兜住「不用助手、裸 mkdir」的形状）。台账是主来源（父/子共享 run 台账，每个嵌套
# 根都在册，与 mtime 无关）；find 是次要来源（原始形状，保留不放松）。
# <base> 可换：翻转⑧在私有 TMPDIR 里造「不回收」形状，不让刻意的残留落进共享临时目录。
mr_nested_leftovers() { # [<base>]
  local base="${1:-${TMPDIR:-/tmp}}"
  {
    tmp_root_ledger_survivors 2>/dev/null | awk -F'\t' -v me="$$" -v base="$base" \
      '$2 != me && $3 == "routes" && index($1, base "/") == 1 { print $1 }'
    find "$base" -maxdepth 1 -name 'teamsmith-routes.*' -newer "$tmp" 2>/dev/null | grep -v "^$tmp\$" || true
  } | sed '/^$/d' | sort -u
}

mr_flips() {
  section "flips · 把树改坏 → walk 必须红并点名（翻转证据）"
  local s log out ev
  # 判据卫生（P202）：现场那条「没有兑现」贴出来的证据必须是真的 finding。旧写法 `grep '✗'` 会把
  # ✓ 断言正文里那个用法行标记（`｜ ✗ change status <id> [--json]`）当 finding 贴出去 —— 读者于是
  # 分不清「守卫没红」和「变异没落地」（P202 的现场证词就是这种形状）。这条把「只贴真 finding」
  # 钉住：把 mr_flip_evidence 改回宽 grep 就会红。
  MR_FLIP_LOGF="$tmp/flip-evidence-probe.log"
  printf '  \033[32m✓\033[0m 断言 L31：change status --json → rc=2 ｜ ✗ change status <id> [--json]\n  \033[31m✗\033[0m 断言 L38：add-agent --fresh 被自己的解析器拒绝\n' > "$MR_FLIP_LOGF"
  ev="$(mr_flip_evidence)"
  if [ "${ev#*add-agent --fresh}" != "$ev" ] && [ "${ev#*change status <id>}" = "$ev" ]; then
    ok "判据卫生：没有兑现时的现场只贴真 finding（正文里的用法行标记不冒充 finding）"
  else
    finding "判据卫生：证据里混进了正文的用法行标记（$ev）"
  fi
  # ① 场地缺陷：help 打印 add-agent --model，解析器拒绝它
  s="$(mr_scratch_tree flip-model)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-agents.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('--model) model="${2:?--model 需要 <provider/model> 或 -}"; has_model=1; shift 2 ;;',
              '--model) team_usage_die "add-agent: 未知参数 --model" ;;', 1)
s = s.replace('--model=*) model="${1#*=}"; has_model=1; shift ;;', '', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
  # 落地证明（P202）：①改了两处，两处都要真的落到副本里
  if mr_flip_require "翻转①" "$s" scripts/lib/cmd-agents.sh \
       '--model) model="${2:?--model 需要 <provider/model> 或 -}"; has_model=1; shift 2 ;;' \
       '--model) team_usage_die "add-agent: 未知参数 --model" ;;' \
     && mr_flip_require "翻转①" "$s" scripts/lib/cmd-agents.sh '--model=*) model="${1#*=}"; has_model=1; shift ;;' -; then
    mr_flip_run "$s" walk
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'add-agent --model'; then
      ok "翻转①：help 打印 --model 而解析器拒绝 → walk 红并点名 add-agent --model"
    else
      finding "翻转①没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ② 兄弟旗标：--fresh 是 dispatch 的，add-agent 不接受
  s="$(mr_scratch_tree flip-sibling)"
  sed -i 's/add-agent <a> \[--register\]/add-agent <a> [--fresh]/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  if mr_flip_require "翻转②" "$s" scripts/lib/cmd-project.sh 'add-agent <a> [--register]' 'add-agent <a> [--fresh]'; then
    mr_flip_run "$s" walk
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'add-agent --fresh'; then
      ok "翻转②：add-agent 行印上兄弟命令的 --fresh → walk 红并点名 add-agent --fresh"
    else
      finding "翻转②没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # 落地判据自己的红侧（P202：判据不能是橡皮章）。两条都只做文件级检查，不跑嵌套 run：
  #   a) 陈旧模式：sed 的搜索端在文件里根本不存在 → 谁都没改 → 必须报「变异没落地」；
  #   b) 只插不删：新文本出现了、旧文本还在 → 判据的另一侧必须红（证明 gone 一侧承重）。
  s="$(mr_scratch_tree flip-stale-pattern)"
  sed -i 's/add-agent <a> \[--frosh\]/add-agent <a> [--fresh]/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  if mr_flip_landed "落地判据红侧 a" "$s" scripts/lib/cmd-project.sh 'add-agent <a> [--register]' 'add-agent <a> [--fresh]'; then
    finding "落地判据红侧 a：陈旧 sed 什么也没改，判据却放行了（判据是橡皮章）"
  else
    ok "落地判据红侧 a：陈旧 sed（搜索端不存在）→ 判据报「变异没落地」：$MR_FLIP_WHY"
  fi
  s="$(mr_scratch_tree flip-half-landed)"
  sed -i 's/^  add-agent <a> \[--register\]/  add-agent <a> [--register] [--fresh]/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  if mr_flip_landed "落地判据红侧 b" "$s" scripts/lib/cmd-project.sh 'add-agent <a> [--register]' 'add-agent <a> [--fresh]'; then
    finding "落地判据红侧 b：旧文本还在（只插不删），判据却放行了"
  else
    ok "落地判据红侧 b：只插不删 → 判据报「变异没落地」：$MR_FLIP_WHY"
  fi
  # ③ 吞旗标：ps 不再拒绝未知参数（今天 version/meeting list 是实测的两种形状，已在 D6 修掉）
  s="$(mr_scratch_tree flip-swallow)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-status.sh" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index('team_cmd_ps() {')
j = s.index('while [ $# -gt 0 ]; do', i)
k = s.index('case "$1" in', j)
ins = s.index('\n', k) + 1
s = s[:ins] + '      -*) shift ;;\n' + s[ins:]
open(p, 'w', encoding='utf-8').write(s)
PY
  # ps 在 help 里不打印旗标 —— 控制臂按设计只覆盖「打印旗标的路径」；这里把 ps 的用法行改印一个旗标，
  # 让这段翻转的能量落在「吞旗标必须红」上（形状与今天实测的 version/meeting list 同类）。
  sed -i 's/^  ps              容量：/  ps [--frobnicate-probe] 容量：/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  if mr_flip_require "翻转③" "$s" scripts/lib/cmd-status.sh - '-*) shift ;;' \
     && mr_flip_require "翻转③" "$s" scripts/lib/cmd-project.sh '  ps              容量：' '  ps [--frobnicate-probe] 容量：'; then
    mr_flip_run "$s" walk control
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has '控制：ps'; then
      ok "翻转③：ps 吞掉未知旗标 → 控制臂红并点名 ps"
    else
      finding "翻转③没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ④ 无法归属的行：命令块里列 0 的行（修复前的 board 形状）
  s="$(mr_scratch_tree flip-unattributable)"
  sed -i 's/^  board add|assign|set|row|ls/board add|assign|set|row|ls/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  # 落地证明只查 gone 一侧：这步只动行首两个空格，去空格后的行**仍包含**原来那段文本，所以「0→1」
  # 用子串表达不出来；而「带两个空格的形式由 1 变 0」＋ cmp 的字节差就是确证（只有 sed 能改出这个形状）。
  if mr_flip_require "翻转④" "$s" scripts/lib/cmd-project.sh '  board add|assign|set|row|ls' -; then
    mr_flip_run "$s" walk
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has '列 0 的行'; then
      ok "翻转④：命令块里的列 0 行 → walk 红并点名该行（修复前的 board 形状）"
    else
      finding "翻转④没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ⑤ schema 注释点名不存在的命令
  s="$(mr_scratch_tree flip-schema-route)"
  sed -i 's/TEAM_GATES|apply|cmd||plain||-|||workflow/TEAM_GATES|apply|cmd||plain||-|team frob off||workflow/' "$s/skills/teamsmith/scripts/lib/cmd-config.sh"
  if mr_flip_require "翻转⑤" "$s" scripts/lib/cmd-config.sh 'TEAM_GATES|apply|cmd||plain||-|||workflow' 'TEAM_GATES|apply|cmd||plain||-|team frob off||workflow'; then
    mr_flip_run "$s" promises
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'team frob' 'TEAM_GATES'; then
      ok "翻转⑤：TEAM_GATES 的注释点名 team frob → walk 红并点名 TEAM_GATES / team frob"
    else
      finding "翻转⑤没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ⑥ schema 注释点名命令但没有 promise 探针
  s="$(mr_scratch_tree flip-unprobed)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
anchor = "EOF\n}\n"
i = s.index(anchor)
row = "TEAM_ROUTES_UNPROBED|apply|text||plain||-|维护：team config set-agent-model <seat> <model>||workflow\n"
s = s[:i] + row + s[i:]
open(p, 'w', encoding='utf-8').write(s)
PY
  if mr_flip_require "翻转⑥" "$s" scripts/lib/cmd-config.sh - 'TEAM_ROUTES_UNPROBED|apply|text||plain||-|维护：team config set-agent-model <seat> <model>||workflow'; then
    mr_flip_run "$s" promises
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'TEAM_ROUTES_UNPROBED' && ! mr_flip_log_has 'promise：TEAM_GATES'; then
      ok "翻转⑥：新键的注释点名命令却没有探针 → walk 红并只点名该键"
    else
      finding "翻转⑥没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ⑦ 承诺被破坏：注册命令 rc=0 但名册没变
  s="$(mr_scratch_tree flip-broken-promise)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
a = "\n  local why\n  if ! why=\"$(team_config_list_violation \"$new\")\"; then"
b = "\n  if [ \"$op\" = \"add\" ]; then return 0; fi   # flip: 注册命令报成功但不写\n  local why\n  if ! why=\"$(team_config_list_violation \"$new\")\"; then"
assert a in s, 'anchor not found'
s = s.replace(a, b, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
  if mr_flip_require "翻转⑦" "$s" scripts/lib/cmd-config.sh - '# flip: 注册命令报成功但不写'; then
    mr_flip_run "$s" promises
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'promise（TEAM_AGENTS）'; then
      ok "翻转⑦：注册报成功而名册没变 → promise 探针红并点名 TEAM_AGENTS（断言的是效果）"
    else
      finding "翻转⑦没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ⑧ 收尾断言本身必须能被证伪：让嵌套 run 的回收失效（TMP_ROOT_BREAK=noreap，tmp-root.sh 自带的
  #    自检旋钮）跑一次 walk —— 收尾扫描必须看得见那个残留（默认 KEEP 未设时，这就是那条断言的红侧）。
  #    刻意的残留落在私有 TMPDIR 里，随本夹具的根一起被回收，不进共享临时目录。
  s="$(mr_scratch_tree flip-tail-leak)"
  local lkdir="$tmp/flip-tail-leak-tmp"
  mkdir -p "$lkdir"
  #    变异（这个旋钮）的落地证明：helper 里**有**这个分支（在真树里数得着），且这次 run 真的没回收 ——
  #    私有 TMPDIR 里直接看得见一个 teamsmith-routes.* 根。它与收尾扫描互为对照（后者走台账+find）：
  #    根在、扫描看不见 = 扫描瞎了；根不在 = 旋钮没生效。
  s="$(mr_scratch_tree flip-tail-leak)"
  local lkdir="$tmp/flip-tail-leak-tmp"
  mkdir -p "$lkdir"
  local knob left_fs
  knob="$(mr_flip_cnt "$skill/tests/lib/tmp-root.sh" '[ "${TMP_ROOT_BREAK:-}" = "noreap" ] && continue')"
  env -u TMUX -u TMUX_PANE TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE="$s" TMPDIR="$lkdir" TMP_ROOT_BREAK=noreap \
    bash "$here/routes.sh" walk >"$tmp/flip-tail-leak.log" 2>&1 || true
  grep -a '^保留临时根：' "$tmp/flip-tail-leak.log" 2>/dev/null >>"$tmp/kept-roots.log" || true
  left_fs="$(find "$lkdir" -maxdepth 1 -name 'teamsmith-routes.*' -type d 2>/dev/null | head -1)"
  if [ "${knob:-0}" -lt 1 ] || [ -z "$left_fs" ]; then
    finding "翻转⑧：变异没落地（夹具缺陷）—— helper 里的 noreap 分支 ${knob:-0} 处；私有 TMPDIR 里没留下根（旋钮没生效）"
  elif [ -n "$(mr_nested_leftovers "$lkdir")" ]; then
    ok "翻转⑧：嵌套 run 不回收 → 收尾扫描看得见残留（默认 KEEP 未设时判红）"
  else
    finding "翻转⑧没有兑现：嵌套 run 不回收（根还在：$left_fs），收尾扫描却没看见残留"
  fi
  # ⑨ P140：印了一条 family 表里没有条目的路线 → C1 目录对账必须红并点名它（沉默的路线不可接受）
  s="$(mr_scratch_tree flip-unclaimed-route)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-agents.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
anchor = 'team_df_err "  规则 1 没有 --force 逃生门'
assert anchor in s, 'anchor not found'
s = s.replace(anchor, 'team_df_err "  修法：team frob on（没有走查条目的路线）"\n  ' + anchor, 1)
open(p, 'w', encoding='utf-8').write(s)
PY
  if mr_flip_require "翻转⑨" "$s" scripts/lib/cmd-agents.sh - '修法：team frob on（没有走查条目的路线）'; then
    mr_flip_run "$s" refusals
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has '没人认领' 'team frob'; then
      ok "翻转⑨：印了一条 family 表没有的路线 → C1 目录对账红并点名它"
    else
      finding "翻转⑨没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
  fi
  # ⑩ P140：打印的修法修错了目标（switch 到别的任务）→ 逐族走查必须红并点名 family；Walk A/B 同树照旧绿
  s="$(mr_scratch_tree flip-mutated-fix)"
  python3 - "$s/skills/teamsmith/scripts/lib/cmd-agents.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# 只改**别的任务分支**那一支的两条路线（switch / switch -c），别动 detached 支的同形路线
anchor = 'team_df_dim "  （拒绝的理由：复验/交付记录会以工作树的分支为证据，不能张冠李戴）"'
assert anchor in s, 'reason anchor not found'
a = s.index(anchor)
start = s.rindex('  if git -C "$wt" show-ref --verify --quiet "refs/heads/$want"; then', 0, a)
block = s[start:a]
assert block.count('"$want"') >= 2, 'expected both route variants in the block'
s = s[:start] + block.replace('"$want"', '"task/T9-wrong"') + s[a:]
open(p, 'w', encoding='utf-8').write(s)
PY
  if mr_flip_require "翻转⑩" "$s" scripts/lib/cmd-agents.sh - 'task/T9-wrong'; then
    mr_flip_run "$s" refusals
    if [ "$MR_FLIP_RC" != "0" ] && mr_flip_log_has 'C2/branch-switch' '路线'; then
      ok "翻转⑩：打印的 switch 目标修错（task/T9-wrong）→ 逐族走查红并点名 branch-switch"
    else
      finding "翻转⑩没有兑现（rc=$MR_FLIP_RC）：$(mr_flip_evidence)"
    fi
    mr_flip_run "$s" walk control
    if [ "$MR_FLIP_RC" = "0" ]; then
      ok "翻转⑩对照：同一棵修坏的树上 Walk A/控制臂照旧绿（只红拒绝路线那一族）"
    else
      finding "翻转⑩对照：修坏的树上 Walk A/控制臂不该变红（rc=$MR_FLIP_RC）"
    fi
  fi
  # 收尾：flips 自己的 scratch 树与嵌套 run 的根都不留下。
  # TEAM_TMP_KEEP=1（门禁的 --keep 让子进程都继承它）是**刻意的保留**，不是泄漏 —— 与 smoke §40
  # 同口径：打一条可见说明，并把嵌套 run 打印的保留路径逐个列出（静默保留仍是缺陷）。
  # 本夹具自己的根也会被保留：助手在 EXIT 时打印它的路径。
  if [ "${TEAM_TMP_KEEP:-0}" = "1" ]; then
    ok "翻转收尾：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏"
    printf '  \033[2m·\033[0m 保留本夹具的根：%s（助手在 EXIT 时也会打印）\n' "$tmp"
    if [ -s "$tmp/kept-roots.log" ]; then
      sort -u "$tmp/kept-roots.log" | while IFS= read -r line; do
        printf '  \033[2m·\033[0m %s\n' "$line"
      done
    fi
  else
    local leftovers n
    leftovers="$(mr_nested_leftovers)"
    n="$(printf '%s\n' "$leftovers" | grep -c . || true)"
    if [ "${n:-0}" = "0" ]; then
      ok "翻转收尾：嵌套 run 的临时根都回收了"
    else
      finding "翻转收尾：留下 $n 个嵌套临时根：$(printf '%s' "$leftovers" | tr '\n' ' ')"
    fi
  fi
}

# ── 结果 ────────────────────────────────────────────────────────────────────────────────────────────
if want walk; then
  if mr_walk_a; then :; fi
fi
if want control; then
  if mr_control; then :; fi
fi
if want promises; then
  if mr_walk_b; then :; fi
fi
if want refusals; then
  if mr_refusals; then :; fi
fi
if want flips; then
  if [ "${TEAM_ROUTES_NESTED:-0}" = "1" ]; then
    skip "flips（嵌套 run：flips 自己在 scratch 树上跑 walk，不再往下递归）"
  elif [ "$FAST" = "1" ]; then
    skip "flips（FAST 模式：翻转要重跑 walk N 次，独立运行时跑；完整门禁会跑）"
  else
    mr_flips
  fi
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FIND" "$SKIP"
[ "$FIND" -eq 0 ] && exit 0
exit 1
