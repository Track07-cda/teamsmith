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
#   flips   eight mutations that MUST redden their guard: seven scratch-tree shapes that redden the walk
#           (the field defect, a sibling flag, a swallowing parser, an unattributable line, a fake schema
#           route, an unprobed note, a broken promise) plus a nested run that does not reap, which proves
#           the tail's leftover assertion can fail. They are the walk's own proof that it can fail.
#
# Usage / knobs:
#   bash skills/teamsmith/tests/routes.sh [walk] [control] [promises] [flips]
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
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(walk control promises flips)
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(walk control promises)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ── containment: the recording tmux shim (never calls the real tmux) ────────────────────────────────
SHIM="$tmp/shim"
TMUX_LOG="$tmp/tmux-calls.log"
mkdir -p "$SHIM"
cat > "$SHIM/tmux" <<'SHIM'
#!/usr/bin/env bash
# Recording tmux: session queries answer "absent", everything else is recorded and exits 0.
# It never invokes the real tmux, so no call this process makes can reach a live server.
printf '%s\n' "$*" >> "${TEAM_ROUTES_TMUX_LOG:-/dev/null}" 2>/dev/null || true
sub=""
while [ $# -gt 0 ]; do
  case "$1" in
    -L|-S|-f|-T|-c) [ $# -ge 2 ] || break; shift 2 ;;
    -*) shift ;;
    *) sub="$1"; break ;;
  esac
done
case "$sub" in
  has-session) exit 1 ;;
  list-windows|list-panes|list-sessions|display-message) exit 0 ;;
esac
exit 0
SHIM
chmod +x "$SHIM/tmux"
: > "$TMUX_LOG"

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
      *)             finding "promise：$key 的探针 id「$probe」没有实现（覆盖表与实现脱节）"; bad=1 ;;
    esac
  done < "$rows"
  [ "$bad" = "1" ] && return 1
  return 0
}

# -- the six promise probes -------------------------------------------------------------------------
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

# mr_flip_run <scratch> <section...> → 在 scratch 树上跑 walk 子集；结果落在 $tmp/flip-<name>.log
mr_flip_run() {
  local scratch="$1"; shift
  local logf="$tmp/flip-run.log"
  # TEAM_ROUTES_NESTED：flips 在 scratch 树上跑 walk —— 嵌套 run 永不跑 flips（结构上的不递归守卫，
  # 与段集规则双保险：谁给嵌套 run 传 flips 都只会打印一行 skip）。
  env -u TMUX -u TMUX_PANE TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE="$scratch" bash "$here/routes.sh" "$@" >"$logf" 2>&1
  MR_FLIP_RC=$?
  MR_FLIP_LOG="$(cat "$logf")"
  # TEAM_TMP_KEEP=1 时嵌套 run 的助手会保留自己的根并**打印路径**——收起来给收尾的可见说明用
  # （$tmp/flip-run.log 每次覆盖，只有这里攒得下每一个保留的根）。
  grep -a '^保留临时根：' "$logf" 2>/dev/null >>"$tmp/kept-roots.log" || true
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
  local s log out
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
  mr_flip_run "$s" walk
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'add-agent --model'; then
    ok "翻转①：help 打印 --model 而解析器拒绝 → walk 红并点名 add-agent --model"
  else
    finding "翻转①没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
  fi
  # ② 兄弟旗标：--fresh 是 dispatch 的，add-agent 不接受
  s="$(mr_scratch_tree flip-sibling)"
  sed -i 's/add-agent <a> \[--register\]/add-agent <a> [--fresh]/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  mr_flip_run "$s" walk
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'add-agent --fresh'; then
    ok "翻转②：add-agent 行印上兄弟命令的 --fresh → walk 红并点名 add-agent --fresh"
  else
    finding "翻转②没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
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
  mr_flip_run "$s" walk control
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q '控制：ps'; then
    ok "翻转③：ps 吞掉未知旗标 → 控制臂红并点名 ps"
  else
    finding "翻转③没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
  fi
  # ④ 无法归属的行：命令块里列 0 的行（修复前的 board 形状）
  s="$(mr_scratch_tree flip-unattributable)"
  sed -i 's/^  board add|assign|set|row|ls/board add|assign|set|row|ls/' "$s/skills/teamsmith/scripts/lib/cmd-project.sh"
  mr_flip_run "$s" walk
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q '列 0 的行'; then
    ok "翻转④：命令块里的列 0 行 → walk 红并点名该行（修复前的 board 形状）"
  else
    finding "翻转④没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
  fi
  # ⑤ schema 注释点名不存在的命令
  s="$(mr_scratch_tree flip-schema-route)"
  sed -i 's/TEAM_GATES|apply|cmd||plain||-|||workflow/TEAM_GATES|apply|cmd||plain||-|team frob off||workflow/' "$s/skills/teamsmith/scripts/lib/cmd-config.sh"
  mr_flip_run "$s" promises
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'team frob' && printf '%s' "$MR_FLIP_LOG" | grep -q 'TEAM_GATES'; then
    ok "翻转⑤：TEAM_GATES 的注释点名 team frob → walk 红并点名 TEAM_GATES / team frob"
  else
    finding "翻转⑤没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
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
  mr_flip_run "$s" promises
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'TEAM_ROUTES_UNPROBED' && ! printf '%s' "$MR_FLIP_LOG" | grep -q 'promise：TEAM_GATES'; then
    ok "翻转⑥：新键的注释点名命令却没有探针 → walk 红并只点名该键"
  else
    finding "翻转⑥没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -3 | tr '\n' ' ')"
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
  mr_flip_run "$s" promises
  if [ "$MR_FLIP_RC" != "0" ] && printf '%s' "$MR_FLIP_LOG" | grep -q 'promise（TEAM_AGENTS）'; then
    ok "翻转⑦：注册报成功而名册没变 → promise 探针红并点名 TEAM_AGENTS（断言的是效果）"
  else
    finding "翻转⑦没有兑现（rc=$MR_FLIP_RC）：$(printf '%s' "$MR_FLIP_LOG" | grep -a '✗' | head -2 | tr '\n' ' ')"
  fi
  # ⑧ 收尾断言本身必须能被证伪：让嵌套 run 的回收失效（TMP_ROOT_BREAK=noreap，tmp-root.sh 自带的
  #    自检旋钮）跑一次 walk —— 收尾扫描必须看得见那个残留（默认 KEEP 未设时，这就是那条断言的红侧）。
  #    刻意的残留落在私有 TMPDIR 里，随本夹具的根一起被回收，不进共享临时目录。
  s="$(mr_scratch_tree flip-tail-leak)"
  local lkdir="$tmp/flip-tail-leak-tmp"
  mkdir -p "$lkdir"
  env -u TMUX -u TMUX_PANE TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE="$s" TMPDIR="$lkdir" TMP_ROOT_BREAK=noreap \
    bash "$here/routes.sh" walk >"$tmp/flip-tail-leak.log" 2>&1 || true
  grep -a '^保留临时根：' "$tmp/flip-tail-leak.log" 2>/dev/null >>"$tmp/kept-roots.log" || true
  if [ -n "$(mr_nested_leftovers "$lkdir")" ]; then
    ok "翻转⑧：嵌套 run 不回收 → 收尾扫描看得见残留（默认 KEEP 未设时判红）"
  else
    finding "翻转⑧没有兑现：嵌套 run 不回收，收尾扫描却没看见残留"
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
