#!/usr/bin/env bash
# help-surface.sh — the checks behind the help surface (change: cli-help · specs/help-surface).
#
# The gate checks the help surface's **logic**; wording, typography, page depth and the language
# tables' completeness are design/review questions (user ruling D170, recorded in the change's
# design.md and in the task brief's scope revision). The groups:
#
#   coverage    the manifest ↔ the dispatcher ↔ the three levels: every label has a page, every
#               group page lists its commands, every page prints exactly its manifest row's usage
#               lines, aliases reach their primary (byte-identical)
#   lang        the language *mechanism*: English by default, TEAM_LANG=zh switches, an invalid
#               value prints one visible warning and falls back, a missing key renders a visible
#               marker (never blank, never a crash), and no machine exit moves with the language
#   locale      one tree, one TEAM_LANG and one TEAM_HELP_WIDTH render the same bytes under
#               LC_ALL=C and LC_ALL=C.UTF-8; every run is valid UTF-8; no line exceeds the width the
#               surface wraps to (the fixture's own locale-independent counter, not the renderer's)
#   claims      the declared effect / authorization / reversibility values: closed vocabularies,
#               one probe per value, and each probe run against a real fixture asserting the effect.
#               For `idempotent` the probe turns a *named* recorded-time field into a canary
#               (IDEMPOTENT_TIME_FIELDS) so its verdict cannot depend on the wall clock (P290),
#               requires the second run's exit code to equal the first run's, and exercises the
#               record-without-that-field shape: a missing timestamp is not an error (V46 F1)
#   invariants  command names, flag names and the literals other specs name: unchanged; the
#               pre-change (command, flag) set is still printed; the retired --model is not
#   route       the three levels, byte-identical entries, unknown tokens exit 2 and are named, the
#               help paths need no project, and asking for help executes nothing
#
# Usage:
#   bash skills/teamsmith/tests/help-surface.sh [--all] [--select <group[,group…]>]
#   bash skills/teamsmith/tests/help-surface.sh --flip        # the red sides, in scratch copies
# knobs:
#   TEAM_HELP_SURFACE_TREE=<tree>   tree under test (default: this checkout)
#   TEAM_HELP_SURFACE_KEEP=1        keep the scratch root and print it
#   TEAM_HELP_SURFACE_TIMEOUT=<s>   per-probe timeout, default 60
# Exit: 0 all selected groups green; 1 at least one finding; 3 setup failure.
# Containment: everything runs under one owned temp root with a recording tmux shim first on PATH;
# the caller's project is never read or written.
set -uo pipefail

_tree_arg="${TEAM_HELP_SURFACE_TREE:-}"
_keep_arg="${TEAM_HELP_SURFACE_KEEP:-}"
_timeout_arg="${TEAM_HELP_SURFACE_TIMEOUT:-}"
_only_arg="${TEAM_HELP_SURFACE_ONLY:-}"
_flipdry_arg="${TEAM_HELP_SURFACE_FLIP_DRY:-}"
_fliponly_arg="${TEAM_HELP_SURFACE_FLIP_ONLY:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true
# the surface's own knobs survive the TEAM_* scrub (they are this fixture's, not the project's)
export TEAM_HELP_SURFACE_TREE="$_tree_arg"
export TEAM_HELP_SURFACE_ONLY="$_only_arg"
export TEAM_HELP_SURFACE_FLIP_DRY="$_flipdry_arg"
export TEAM_HELP_SURFACE_FLIP_ONLY="$_fliponly_arg"

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P309：临时根只有一处解析（product 的 team_tmp_root）。这份夹具以前自己写 ${TMPDIR:-/tmp}，
# 现在必须把解析器 source 进来 —— 否则 team_tmp_root 不存在、拼出来的路径是空根（`/.teamsmith-…`）。
. "$here/lib/tmp-root.sh"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
str="$skill/scripts/strings"
timeout_sec="${_timeout_arg:-60}"
case "$timeout_sec" in ''|*[!0-9]*) timeout_sec=60 ;; esac
keep="$_keep_arg"

# render mode: this file re-invokes itself to render one page in parallel with its siblings
if [ "${1:-}" = "--render-one" ]; then
  _lang="$2"; _spec="$3"; _dir="$4"; _loc="${5:-}"; _w="${6:-}"
  _kind="${_spec%%:*}"; _label="${_spec#*:}"
  [ "$_label" = "-" ] && _label="menu"
  case "$_kind" in
    menu)    _argv=() ;;
    group)   _argv=(help "$_label") ;;
    command) _argv=(help "$_label") ;;
    *) exit 3 ;;
  esac
  # _loc / _w are empty for every pre-existing caller: those renders keep inheriting the caller's
  # locale and width exactly as before (the locale group is the only caller that pins them).
  _env=()
  [ -n "$_loc" ] && _env=(LC_ALL="$_loc")
  _rtmp="$(team_tmp_root)/.teamsmith-help-surface-render.$$"
  mkdir -p "$_rtmp" "$_dir"
  ( cd "$_rtmp" && env "${_env[@]}" TEAM_LANG="$_lang" ${_w:+TEAM_HELP_WIDTH="$_w"} \
      bash "$team" "${_argv[@]}" ) > "$_dir/$_kind--$_label.txt" 2>/dev/null
  _rrc=$?
  rm -rf "$_rtmp"
  exit $_rrc
fi

# the selectable groups: a name outside this list used to print "command not found" and still exit 0
# (a misspelled or retired group name was a silent green), so the selector now refuses it by name
KNOWN_SECTIONS="coverage locale lang claims invariants route"

SECTIONS=()
FLIP=0
for a in "$@"; do
  case "$a" in
    --all) SECTIONS=($KNOWN_SECTIONS) ;;
    --flip) FLIP=1 ;;
    --select) : ;;
    --select=*) IFS=',' read -r -a SECTIONS <<< "${a#*=}" ;;
    -*) printf 'help-surface: 未知参数 %s\n' "$a" >&2; exit 2 ;;
    *) IFS=',' read -r -a SECTIONS <<< "$a" ;;
  esac
done
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=($KNOWN_SECTIONS)
_bad_sel=""
for _s in "${SECTIONS[@]}"; do
  case " $KNOWN_SECTIONS " in *" $_s "*) ;; *) _bad_sel="$_bad_sel $_s" ;; esac
done
if [ -n "$_bad_sel" ]; then
  printf 'help-surface: 未知的选段%s（可用：%s）\n' "$_bad_sel" "${KNOWN_SECTIONS// /, }" >&2
  exit 2
fi
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

[ -f "$team" ] || { printf 'help-surface: 没有 CLI：%s\n' "$team" >&2; exit 3; }
[ -f "$str/commands.tsv" ] || { printf 'help-surface: 没有命令清单：%s\n' "$str/commands.tsv" >&2; exit 3; }

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN=timeout
PASS=0; FIND=0; SKIP=0
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()      { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
finding() { printf '  \033[31m✗\033[0m %s\n' "$1"; FIND=$((FIND + 1)); }
skip()    { printf '  \033[33mSKIP\033[0m %s\n' "$1"; SKIP=$((SKIP + 1)); }

# ---------------------------------------------------------------- owned scratch root
tmp="$(team_tmp_root)/.teamsmith-help-surface.$$"
rm -rf "$tmp"; mkdir -p "$tmp/logs" "$tmp/fx"
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  # any pane command the shim really ran is killed with the fixture
  if [ -d "$tmp/pane-pids" ]; then
    local _f
    for _f in "$tmp/pane-pids"/*; do [ -f "$_f" ] || continue; kill "$(cat "$_f")" 2>/dev/null || true; done
  fi
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"; else rm -rf "$tmp"; fi
}
trap cleanup EXIT

# ---------------------------------------------------------------- recording tmux shim + fake agent
SHIM="$tmp/shim"; mkdir -p "$SHIM"
cat > "$SHIM/tmux" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${HS_TMUX_LOG:-/dev/null}" 2>/dev/null || true
win="${HS_WINDOWS:-/dev/null}"
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
  respawn-pane)
    # the dispatch harness runs the pane's command for real (a real tmux would): the launcher's own
    # script writes the launch proof and runs the agent, so the probe sees a genuine launch.
    _j=0
    while [ "$_j" -lt ${#rest[@]} ]; do
      case "${rest[$_j]}" in
        -k|-d) _j=$((_j+1)) ;;
        -t|-c) _j=$((_j+2)) ;;
        *) break ;;
      esac
    done
    if [ "$_j" -lt ${#rest[@]} ]; then
      setsid "${rest[@]:$_j}" </dev/null >/dev/null 2>&1 &
      printf '%s\n' "$!" > "${HS_PANE_PIDS:-/dev/null}.$$" 2>/dev/null || true
    fi
    exit 0 ;;
  kill-window) unreg "${t:-?}"; exit 0 ;;
  list-panes)
    # P292：interrupt 探针把「pane 里的 agent 进程」指到一个**真** stub（私有 pid 文件，见 probe_env_of）。
    # 不设这个变量的探针读到的东西与从前逐字节相同（'0'）。
    if [ -n "${HS_PANE_PID_FILE:-}" ] && [ -r "$HS_PANE_PID_FILE" ]; then
      _p="$(head -1 "$HS_PANE_PID_FILE" 2>/dev/null)"
      case "$_p" in ''|*[!0-9]*) ;; *) printf '1 %s\n' "$_p"; exit 0 ;; esac
    fi
    printf '0\n'; exit 0 ;;
  display-message)
    case "$*" in
      *pane_current_command*) case "$t" in *pulse*) printf 'node\n' ;; esac ;;
    esac
    exit 0 ;;
  list-sessions|set-window-option|capture-pane) exit 0 ;;
  show-options) printf 'on\n'; exit 0 ;;
esac
exit 0
SHIM
chmod +x "$SHIM/tmux"
# the fake agent: records its own invocation and exits at once
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "${HS_LAUNCH_LOG:-/dev/null}"\nexit 0\n' > "$SHIM/fakeagent"
chmod +x "$SHIM/fakeagent"
# P292：interrupt 探针的「席位」——一个**真**的长回合进程（身份写在它自己的 environ 里，argv[0] 的
# basename 命中探针配置的 TEAM_AGENT_BIN）；TERM = 回合结束（退出 0）。它由探针现场起，收尾由 cleanup
# 按 pane-pids 台账兜底。
cat > "$SHIM/interrupt-agent" <<'STUB'
#!/usr/bin/env bash
trap 'exit 0' TERM
while :; do sleep 0.2; done
STUB
chmod +x "$SHIM/interrupt-agent"
printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' "$team" > "$SHIM/team"
chmod +x "$SHIM/team"
: > "$tmp/tmux-calls.log"; : > "$tmp/windows.reg"; : > "$tmp/launch.log"

mkdir -p "$tmp/pane-pids"
export HS_TMUX_LOG="$tmp/tmux-calls.log" HS_WINDOWS="$tmp/windows.reg" HS_LAUNCH_LOG="$tmp/launch.log" HS_PANE_PIDS="$tmp/pane-pids/pane"
export TEAM_MEETINGS_DIR="$tmp/meetings"; mkdir -p "$TEAM_MEETINGS_DIR"

# ---------------------------------------------------------------- reading the manifest
# mg <name> <field> → one field of a command row (field names as in the manifest header)
declare -A MG_NAME=() MG_GROUP=() MG_USAGE=() MG_FLAGS=() MG_SUBS=() MG_ALIASES=() MG_TERMS=() \
  MG_FACES=() MG_EFFECT=() MG_AUTH=() MG_UNDO=() MG_CLAIMS=() MG_PROBE=() MG_EXAMPLE=()
declare -a MG_ORDER=() MG_GROUPS=() MG_BEGIN=()
load_manifest() {
  local line f
  local -a col=()
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS=$'\t' read -r -a col <<< "$line"
    case "${col[0]}" in
      group) MG_GROUPS+=("${col[1]}") ;;
      begin) MG_BEGIN=("${col[@]:1}") ;;
      cmd)
        local n="${col[1]}"
        MG_ORDER+=("$n")
        MG_GROUP[$n]="${col[2]}"; MG_USAGE[$n]="${col[3]}"; MG_FLAGS[$n]="${col[4]}"
        MG_SUBS[$n]="${col[5]}"; MG_ALIASES[$n]="${col[6]}"; MG_TERMS[$n]="${col[7]}"
        MG_FACES[$n]="${col[8]}"; MG_EFFECT[$n]="${col[9]}"; MG_AUTH[$n]="${col[10]}"
        MG_UNDO[$n]="${col[11]}"; MG_CLAIMS[$n]="${col[12]}"; MG_PROBE[$n]="${col[13]}"
        MG_EXAMPLE[$n]="${col[14]}" ;;
    esac
  done < "$1"
}
# mt <file> <key> → the value of one prose key
mt() { awk -F'\t' -v k="$2" '$1==k {print substr($0, index($0,"\t")+1); found=1; exit} END{if(!found) exit 1}' "$1"; }
# prose_keys <file> → the key set
prose_keys() { awk -F'\t' '!/^#/ && NF>0 {print $1}' "$1" | sort; }

# page <language> <argv…> → render a page from the tree under test (never loads a project)
page() {
  local lang="$1"; shift
  ( cd "$tmp" && env -u TMUX -u TMUX_PANE TEAM_LANG="$lang" TEAM_SKILL_DIR="$skill" \
      PATH="$SHIM:$PATH" ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} bash "$team" "$@" </dev/null 2>/dev/null )
}

# cells <text> — display cells (mirrors the renderer's rule; a CJK-wide character counts two)
cells() { printf '%s' "$1" | python3 -c 'import sys,unicodedata; s=sys.stdin.read(); print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s))'; }

# has_cjk <text> → 0 when the text carries a CJK code point. Not `grep '[一-龥]'`: under LC_ALL=C that
# bracket expression is a byte range that matches almost any byte, so the very same menu came out
# "Chinese" in one locale and English in the other. A verdict that moves with the caller's locale is
# the defect this change removes from the surface — the checker must not reintroduce it.
has_cjk() {
  python3 -c '
import sys
data = sys.stdin.buffer.read().decode("utf-8", "replace")
sys.exit(0 if any("\u3400" <= c <= "\u9fff" or "\uf900" <= c <= "\ufaff" for c in data) else 1)
'
}

# the dispatcher's internal labels: the case arms of scripts/team whose name begins with `__`
team_internal_labels() {
  awk '
    /^case "\$CMD" in/ { inb=1; next }
    inb && /^esac/ { inb=0 }
    inb && /^[[:space:]]+__[A-Za-z0-9_'"'"'|.-]*\)/ {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/\).*/,"",line)
      n=split(line,a,"|"); for (i=1;i<=n;i++){ if (a[i] !~ /^__/) continue; gsub(/[^a-z0-9_-]/,"",a[i]); if(a[i]!="") printf "%s\n", a[i] }
    }' "$skill/scripts/team" | sort -u
}

# the dispatcher's own labels (the case arms of scripts/team), minus the internal data path
team_labels() {
  awk '
    /^case "\$CMD" in/ { inb=1; next }
    inb && /^esac/ { inb=0 }
    inb && /^[[:space:]]+[A-Za-z0-9_'"'"'|.-]+\)/ {
      line=$0; sub(/^[[:space:]]+/,"",line); sub(/\).*/,"",line)
      n=split(line,a,"|"); for (i=1;i<=n;i++){ if (a[i] ~ /^__/) continue; gsub(/[^a-z0-9-]/,"",a[i]); if(a[i]!="") printf "%s\n", a[i] }
    }' "$skill/scripts/team" | sort -u
}

# ---------------------------------------------------------------- fixtures for the probes
declare -A FP_NAMES=()
fp_dir() { # <dir> → the tree's shape (type, path, size, symlink target) plus its file contents
  local d="$1"
  [ -e "$d" ] || { printf 'absent\n'; return 0; }
  { find "$d" -mindepth 1 -printf '%y %P %s %l\n' 2>/dev/null | sort
    find "$d" -type f -print0 2>/dev/null | sort -z | xargs -0 -r cat 2>/dev/null
  } | sha256sum | cut -c1-16
}
fp_face() { # <dir> <face> → a fingerprint of that face
  local d="$1" face="$2"
  case "$face" in
    state)    fp_dir "$d/.pi/team/state" ;;
    docs)     fp_dir "$d/docs" ;;
    config)   fp_dir "$d/.pi/team/config.sh" ;;
    worktree)
      # F1（V52 返修轮次 1）：旧指纹只摘**结构**（`worktree list` + 本地分支 ref），看不见「往席位
      # 工作树里写一个文件」这种漂移 —— 而 interrupt 的规格明写工作树逐字节不变，claims 探针却对
      # 它一直瞎。现在取结构 **加内容**，内容取两处并集：
      #   ① `.worktrees/` 约定目录（浅现场里席位工作树就在这里，未必登记进 git）；
      #   ② `git worktree list` 登记的每个**非主检出**工作树（worktree 放到仓外时也看得见）。
      # 主检出本身不整体哈希：它的内容按面拆开（state / docs / config / skills 各有一份指纹），
      # 否则任何命令写任意一个面都会同时把 worktree 点亮，反向判据就分不出是哪个面了。
      {
        git -C "$d" worktree list --porcelain 2>/dev/null
        git -C "$d" for-each-ref --format='%(refname)' refs/heads 2>/dev/null
        fp_dir "$d/.worktrees"
        local _main _wt
        _main="$(cd -P "$d" 2>/dev/null && pwd)"
        while IFS= read -r _wt; do
          case "$_wt" in ''|"$_main") continue ;; esac
          fp_dir "$_wt"
        done < <(git -C "$d" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
      } | sha256sum | cut -c1-16 ;;
    skills)   fp_dir "$d/.pi/skills" ;;
    meetings) fp_dir "${TEAM_MEETINGS_DIR:-$tmp/meetings}" ;;
    *) printf 'unknown\n' ;;
  esac
}
fp_all() { # <dir> → every face's fingerprint
  local f
  for f in state docs config worktree skills meetings; do printf '%s %s\n' "$f" "$(fp_face "$1" "$f")"; done
}

# ---------------------------------------------------------------- recorded-time fields (P290)
# A command whose manifest row declares `idempotent` must leave the state byte-identical after a
# second identical run. One field shape is legitimately *about* time: the record of when the command
# ran (`AT=` in `.pi/team/state/pm-loaded.env`). It is not exempt from the assertion — it is *named* here, and
# the probe turns it into a canary: after the first run the fixture overwrites the named field with a
# sentinel value no clock produces, runs the command again, and requires every byte (sentinel
# included) to survive. Without the sentinel the verdict would depend on the wall clock — a rewrite
# inside the same second is invisible — and that is the host-green/container-red flake this table
# exists to remove (P290). A second run that rewrites a clock field is a defect for *every* command
# that declares `idempotent`, so a field must be named here rather than silently excused; a line
# naming a field the first run did not write is itself a finding, so a stale entry cannot sit here.
# An exclusion-only comparison was rejected on purpose: it would make this probe blind to exactly
# the rewrite the declaration forbids.
declare -A IDEMPOTENT_TIME_FIELDS=(
  [mark-loaded]=".pi/team/state/pm-loaded.env:AT"
)
IDEMPOTENT_SENTINEL="sentinel-not-a-clock"

idem_fields() { # <cmd> → one `relpath:field` per line (nothing when the command declares none)
  case "${IDEMPOTENT_TIME_FIELDS[$1]+x}" in x) printf '%s\n' ${IDEMPOTENT_TIME_FIELDS[$1]} ;; esac
  return 0
}

idem_stamp() { # <cmd> <dir> <outfile> — overwrite each declared recorded-time field with the sentinel
  local cmd="$1" d="$2" out="$3" spec rel field f
  while IFS= read -r spec; do
    [ -n "$spec" ] || continue
    rel="${spec%%:*}"; field="${spec#*:}"
    f="$d/$rel"
    if [ ! -f "$f" ] || ! grep -q "^$field=" "$f" 2>/dev/null; then
      finding "claims: $cmd 声明的记录时间字段 $field 不在 $rel 里（声明过期：不静默通过，见 IDEMPOTENT_TIME_FIELDS）"
      continue
    fi
    if awk -v k="$field" -v v="$IDEMPOTENT_SENTINEL" 'index($0, k"=") == 1 { print k"="v; next } { print }' "$f" > "$f.p290"; then
      mv "$f.p290" "$f"
      printf '%s\n' "$spec" >> "$out"
    else
      rm -f "$f.p290"
      finding "claims: $cmd 声明的记录时间字段 $field 没盖上哨兵（夹具写入失败）"
    fi
  done < <(idem_fields "$cmd")
  return 0
}

idem_names() { # <stamped-file> → ` AT（.pi/team/state/pm-loaded.env）` — names the fields in the result line
  local s out=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    out="$out ${s#*:}（${s%%:*}）"
  done < "$1"
  printf '%s' "$out"
}

new_repo() { # <name> → a fresh git repository
  local d="$tmp/fx/$1"
  rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email hs@teamsmith && git config user.name hs \
      && printf '{"name":"%s","scripts":{"verify":"true"}}\n' "$1" > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  printf '%s\n' "$d"
}

env_run() { # <dir> <argv…> → the CLI in the fixture; HS_OUT / HS_RC
  # HS_ENV carries extra VAR=VAL words for this call, HS_STDIN the stdin source (default /dev/null)
  local d="$1"; shift
  local out rc
  out="$( cd "$d" && env -u TMUX -u TMUX_PANE -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
            PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" \
            TEAM_MEETINGS_DIR="$TEAM_MEETINGS_DIR" TEAM_PI_AGENT_DIR="$tmp/pi-agent" \
            ${HS_ENV:-} \
            ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} bash "$team" "$@" <"${HS_STDIN:-/dev/null}" 2>&1 )"
  rc=$?
  HS_OUT="$out"; HS_RC="$rc"
}

setup_fixture() { # <setup-id> <dir>
  local id="$1" d="$2" sess="$3"
  case "$id" in
    repo) : ;;
    proj|task|wt|live|seat)
      env_run "$d" init --no-skills --session "$sess" --agents "dev verify" --vcs local --gates true \
        --docs docs/team --task-models 'code=provider/model-fast' --pm-model 'provider/model-strong' \
        --pm-window pm > "$tmp/logs/$sess-init.log" 2>&1 || {
        printf 'init failed for %s:\n%s\n' "$sess" "$(tail -3 "$tmp/logs/$sess-init.log")" >&2; return 1; }
      ;;
    *) printf 'unknown setup %s\n' "$id" >&2; return 1 ;;
  esac
  case "$id" in
    seat)
      # P292 · interrupt 探针的浅现场：“一条席位”的派单记录（窗口 / 工作树 / sid）+ 窗口表里的一行 +
      # 一个**真**的 stub agent 进程（argv[0] 命中探针的 TEAM_AGENT_BIN，身份在它自己的 environ 里）。
      # pane 由记录器 shim 回答（HS_PANE_PID_FILE，见 probe_env_of）；进程是真的，所以证明链读到的
      # 是内核里的 /proc（cmdline / environ / stat），不是夹具编的。
      local wt="$d/.worktrees/dev"
      mkdir -p "$wt" "$d/.pi/team/state" "$d/docs/team/threads" "$d/docs/team/inbox" "$d/docs/team/tasks"
      grep -qxF "$sess:dev" "$tmp/windows.reg" 2>/dev/null || printf '%s\n' "$sess:dev" >> "$tmp/windows.reg"
      printf 'assignment_version=1\ntask=T1\ntaskfile=%s\ncategory=code\nbranch=task/T1-first-task\nworktree=%s\nwindow=dev\nseat=dev\nmodel=provider/model-fast\nselected_via=policy\nlaunch_via=policy\nsid=p-interrupt-sid\nlaunch_nonce=probe-nonce\nstarted=2026-01-01T00:00:00Z\nsid_bytes=0\nmode=continued\nidentity_via=provider,model,session_id\n' \
        "$d/docs/team/tasks/T1-first-task.md" "$wt" > "$d/.pi/team/state/dev.env" || {
        printf 'interrupt 现场：写不进派单记录（%s）\n' "$d/.pi/team/state/dev.env" >&2; return 1; }
      setsid env TEAM_MAIN_ROOT="$d" TEAM_ROOT="$wt" "$SHIM/interrupt-agent" </dev/null >/dev/null 2>&1 &
      printf '%s\n' "$!" > "$tmp/pane-pids/interrupt"
      return 0
      ;;
  esac
  case "$id" in
    task|wt|live)
      env_run "$d" task T1 --title "First task" --category code --agent dev > "$tmp/logs/$sess-task.log" 2>&1 || return 1
      # the brief needs a resolvable anchor (the dispatch refuses a bare `-`); rewrite the line
      # the template carries instead of adding a second one (two anchor lines are refused too)
      local brief="$d/docs/team/tasks/T1-first-task.md"
      if [ -f "$brief" ]; then
        awk '{ if ($0 ~ /^anchor:/) { print "anchor: none (infra) — the probe fixture"; next } ; print }' "$brief" > "$brief.tmp" && mv "$brief.tmp" "$brief"
      fi
      ;;
  esac
  case "$id" in
    wt|live)
      git -C "$d" worktree add -q -b task/T1-first-task "$d/.worktrees/dev" main >/dev/null 2>&1 || true
      ;;
  esac
  case "$id" in
    live)
      ( cd "$d/.worktrees/dev" 2>/dev/null || cd "$d" ) || true
      env_run "$d" dispatch dev T1 docs/team/tasks/T1-first-task.md --branch task/T1-first-task > "$tmp/logs/$sess-dispatch.log" 2>&1 || true
      ;;
  esac
  return 0
}

# the probe recipes: one per command — <setup>|<argv>
probe_recipe() {
  case "$1" in
    help)         printf 'repo|help\n' ;;
    bootstrap)    printf 'repo|bootstrap --agents dev --task-models code=provider/model-fast --pm-model provider/model-strong --pm-window pm\n' ;;
    init)         printf 'repo|init --session PROBE --agents dev --vcs local --gates true --docs docs/team --task-models code=provider/model-fast --pm-model provider/model-strong --pm-window pm\n' ;;
    doctor)       printf 'proj|doctor\n' ;;
    roster)       printf 'proj|roster\n' ;;
    status)       printf 'proj|status\n' ;;
    ps)           printf 'proj|ps\n' ;;
    bg)           printf 'proj|bg list\n' ;;
    reap)         printf 'proj|reap --orphans --yes\n' ;;
    interrupt)    printf 'seat|interrupt dev --reason probe --yes\n' ;;
    digest)       printf 'proj|digest\n' ;;
    inbox)        printf 'proj|inbox\n' ;;
    paths)        printf 'proj|paths\n' ;;
    config)       printf 'proj|config set TEAM_PULSE_INTERVAL 600 --yes\n' ;;
    task)         printf 'proj|task T1 --title "First task" --category code --agent dev\n' ;;
    board)        printf 'task|board set T1 wip\n' ;;
    change)       printf 'task|change status T1\n' ;;
    thread)       printf 'proj|thread dev "one line"\n' ;;
    report)       printf 'task|report T1 dev\n' ;;
    add-agent)    printf 'proj|add-agent dev --create\n' ;;
    dispatch)     printf 'wt|dispatch dev T1 docs/team/tasks/T1-first-task.md --branch task/T1-first-task\n' ;;
    say)          printf 'wt|say dev "one line" --now\n' ;;
    notify)       printf 'proj|notify pm "one line"\n' ;;
    draft)        printf 'proj|draft send DRAFT --now\n' ;;
    outbox)       printf 'proj|outbox list\n' ;;
    reply)        printf 'proj|reply post --from pm --title "decision" --stdin\n' ;;
    pulse)        printf 'proj|pulse up\n' ;;
    monitor)      printf 'proj|monitor --print --no-activity --once\n' ;;
    watch)        printf 'proj|watch --once\n' ;;
    standby)      printf 'proj|standby on --reason "probe"\n' ;;
    meeting)      printf 'proj|meeting open probe --with other:other --topic topic --yes\n' ;;
    up)           printf 'proj|up --fresh-pm\n' ;;
    resume)       printf 'live|resume --agent dev\n' ;;
    review)       printf 'wt|review T1 --dir REVIEWDIR --no-gates\n' ;;
    close)        printf 'live|close T1\n' ;;
    teardown)     printf 'wt|teardown --agent dev --purge\n' ;;
    smoke)        printf 'proj|smoke --select 0\n' ;;
    perf)         printf 'proj|perf --host\n' ;;
    merge)        printf 'proj|merge\n' ;;
    pr)           printf 'proj|pr\n' ;;
    gh)           printf 'proj|gh\n' ;;
    gl)           printf 'proj|gl\n' ;;
    mark-loaded)  printf 'proj|mark-loaded --version 0.0.0\n' ;;
    version)      printf 'proj|version\n' ;;
    changelog)    printf 'proj|changelog\n' ;;
    reload)       printf 'proj|reload\n' ;;
    *) return 1 ;;
  esac
}

# probe_prepare <cmd> <dir> <setup> — the per-command extras a recipe needs before it runs
probe_prepare() {
  local cmd="$1" d="$2"
  case "$cmd" in
    draft) printf '# note\n' > "$d/draft.md" ;;
    review) git -C "$d" worktree add -q -b task/P1 "$d/../$cmd-autoreview" main >/dev/null 2>&1 || true ;;
  esac
  return 0
}

# usage_entries <page-file> → one line per usage entry: an indent-2 line starts one, deeper lines
# continue it. This is the same shape tests/routes.sh reads, so both fixtures judge the same thing.
usage_entries() {
  awk '
    { line=$0
      if (line ~ /^[ \t]*$/) next
      n=match(line, /[^ ]/); ind=n-1
      if (ind == 2) { if (cur != "") print cur; cur = substr(line, 3); next }
      if (ind == 4 && cur != "") { cur = cur " " substr(line, 5); next }
      if (cur != "") { print cur; cur = "" }
    }
    END { if (cur != "") print cur }
  ' "$1"
}

# manifest_fragments <command> → the usage fragments the manifest declares, one per line
manifest_fragments() {
  awk -F'\t' -v c="$1" '$1=="cmd" && $2==c {n=split($4,f," ;; "); for(i=1;i<=n;i++) print f[i]}' "$str/commands.tsv"
}

# manifest_group_commands <group> → the commands the manifest puts in that group, in order
manifest_group_commands() {
  awk -F'\t' -v g="$1" '$1=="cmd" && $3==g {print $2}' "$str/commands.tsv"
}

# ---------------------------------------------------------------- pages (rendered once, checked many times)
pages_tsv="$tmp/pages.tsv"; : > "$pages_tsv"
# page_list → the pages this fixture renders: the menu, every group page and every command page
page_list() {
  local g c
  if [ -n "${TEAM_HELP_SURFACE_ONLY:-}" ]; then
    for c in ${TEAM_HELP_SURFACE_ONLY}; do printf 'command\t%s\n' "$c"; done
    return 0
  fi
  printf 'menu\t-\n'
  for g in "${MG_GROUPS[@]}"; do printf 'group\t%s\n' "$g"; done
  for c in "${MG_ORDER[@]}"; do printf 'command\t%s\n' "$c"; done
}

# render_into <dir> <lang> [<locale>] [<width>] — renders the whole page list into <dir>
render_into() {
  local dir="$1" lang="$2" loc="${3:-}" w="${4:-}"
  mkdir -p "$dir"
  page_list | awk -F'\t' '{printf "%s:%s\n", $1, $2}' \
    | xargs -P 6 -I@ bash "$0" --render-one "$lang" @ "$dir" "$loc" "$w" >/dev/null 2>&1
}

render_pages() { # <lang>
  local lang="$1" dir jobs
  dir="$tmp/pages/$lang"; jobs="$tmp/jobs-$lang.txt"
  mkdir -p "$dir"; : > "$jobs"
  page_list > "$jobs"
  awk -F'\t' '{printf "%s:%s\n", $1, $2}' "$jobs" \
    | xargs -P 6 -I@ bash "$0" --render-one "$lang" @ "$dir" >/dev/null 2>&1
  while IFS=$'\t' read -r kind label; do
    [ "$label" = "-" ] && label=menu
    printf '%s\t%s\t%s\t%s/%s--%s.txt\n' "$kind" "$label" "$lang" "$dir" "$kind" "$label" >> "$pages_tsv"
  done < "$jobs"
}

# page_text <lang> <kind> <label> → the rendered page
page_text() { cat "$tmp/pages/$1/$2--$3.txt"; }

# ---------------------------------------------------------------- locale and width
# This group's oracle is the fixture's own locale-independent counter (python3's unicodedata) and
# never the renderer's functions: the point is that an independent reader disagrees with a renderer
# that takes its display widths from the locale.
locale_diff() { # <a> <b> <tag> → one line naming the first differing line
  python3 - "$1" "$2" "$3" <<'PYEOF'
import sys
a = open(sys.argv[1], 'rb').read().split(b'\n')
b = open(sys.argv[2], 'rb').read().split(b'\n')
for i, (x, y) in enumerate(zip(a, b), 1):
    if x != y:
        print("%s: line %d differs" % (sys.argv[3], i))
        break
else:
    if len(a) != len(b):
        print("%s: line count %d vs %d" % (sys.argv[3], len(a), len(b)))
PYEOF
}

locale_violations() { # <width> <tag-prefix> <file…> → one line per over-wide line or invalid byte
  python3 - "$@" <<'PYEOF'
import sys, unicodedata
width = int(sys.argv[1]); prefix = sys.argv[2]
for path in sys.argv[3:]:
    name = path.rsplit('/', 1)[-1][:-4]
    data = open(path, 'rb').read()
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError as exc:
        print("%s%s: not valid UTF-8 (%s)" % (prefix, name, exc))
        continue
    for i, line in enumerate(text.split('\n'), 1):
        w = sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in line)
        if w > width:
            print("%s%s: line %d is %d cells, over %d (%s)" % (prefix, name, i, w, width, line.strip()[:40]))
PYEOF
}

check_locale() {
  section "locale · 同一输入在任何 locale 下同一份字节、每行不超过 TEAM_HELP_WIDTH、输出合法 UTF-8"
  if ! command -v python3 >/dev/null 2>&1; then
    skip "locale: 没有 python3（本组用它自己的 unicodedata 计数，不调用渲染器）"
    return 0
  fi
  local dw=100 aw=64 lang page run w n bad first
  local -a pages=() langs=(en zh)
  while IFS=$'\t' read -r _k _l; do
    [ "$_l" = "-" ] && _l=menu
    pages+=("$_k--$_l")
  done < <(page_list)
  if [ "${#pages[@]}" = "0" ]; then finding "locale: 页面清单是空的"; return 0; fi
  for lang in "${langs[@]}"; do
    render_into "$tmp/locale/$lang/C/$dw"       "$lang" C       "$dw"
    render_into "$tmp/locale/$lang/C.UTF-8/$dw" "$lang" C.UTF-8 "$dw"
    render_into "$tmp/locale/$lang/C.UTF-8/$aw" "$lang" C.UTF-8 "$aw"
  done
  for lang in "${langs[@]}"; do
    # ① one tree, one TEAM_LANG, one TEAM_HELP_WIDTH → the same bytes under LC_ALL=C and C.UTF-8
    n=0; bad=""
    for page in "${pages[@]}"; do
      cmp -s "$tmp/locale/$lang/C/$dw/$page.txt" "$tmp/locale/$lang/C.UTF-8/$dw/$page.txt" && continue
      n=$((n + 1))
      if [ "$n" -le 3 ]; then
        bad="$bad $page[$(locale_diff "$tmp/locale/$lang/C/$dw/$page.txt" \
          "$tmp/locale/$lang/C.UTF-8/$dw/$page.txt" x | sed 's/^x: //')]"
      fi
    done
    if [ "$n" = "0" ]; then ok "locale($lang): ${#pages[@]} 个页面在 LC_ALL=C 与 LC_ALL=C.UTF-8 下逐字节相同"
    else finding "locale($lang): $n 个页面随 locale 变：$bad"; fi
    # ② every run is valid UTF-8 and every line fits the width it was rendered with
    for run in "C/$dw" "C.UTF-8/$dw" "C.UTF-8/$aw"; do
      case "$run" in */"$aw") w="$aw" ;; *) w="$dw" ;; esac
      local -a files=()
      for page in "${pages[@]}"; do files+=("$tmp/locale/$lang/$run/$page.txt"); done
      n=0; bad=""
      while IFS= read -r first; do
        [ -n "$first" ] || continue
        n=$((n + 1))
        [ "$n" -le 3 ] && bad="$bad $first"
      done < <(locale_violations "$w" "" "${files[@]}")
      if [ "$n" = "0" ]; then ok "locale($lang, $run): ${#pages[@]} 个页面都是合法 UTF-8 且每行 ≤ $w 格"
      else finding "locale($lang, $run): $n 个页面越界或不是合法 UTF-8：$bad"; fi
    done
  done
  return 0
}

# ---------------------------------------------------------------- coverage
check_coverage() {
  section "coverage · 清单 ↔ dispatcher ↔ 三级渲染"
  local labels; labels="$( { printf 'help\n'; team_labels; } | sort -u )"
  local missing=0 n
  for n in $labels; do
    if [ -n "${MG_GROUP[$n]+x}" ]; then continue; fi
    local aliased=0 c a
    for c in "${MG_ORDER[@]}"; do
      for a in ${MG_ALIASES[$c]}; do [ "$a" = "$n" ] && aliased=1; done
    done
    if [ "$aliased" = "0" ]; then finding "dispatcher 接受的 $n 在清单里没有记录（也没有别名声明）"; missing=1; fi
  done
  [ "$missing" = "0" ] && ok "dispatcher 的每个标签都有记录或别名声明（$(printf '%s\n' $labels | wc -l) 个标签）"
  local orphan=0
  for c in "${MG_ORDER[@]}"; do
    printf '%s\n' $labels | grep -qx "$c" || { finding "清单里的 $c 不是一个 dispatcher 标签"; orphan=1; }
  done
  [ "$orphan" = "0" ] && ok "清单里每个命令都被 dispatcher 接受"
  # group ids resolve and do not collide with a command name
  local g collide=0
  for g in "${MG_GROUPS[@]}"; do
    [ -n "${MG_GROUP[$g]+x}" ] && { finding "分组 id $g 与命令名冲突"; collide=1; }
    grep -q "^  " "$tmp/pages/en/group--$g.txt" 2>/dev/null || { finding "分组 $g 的组页是空的"; collide=1; }
  done
  [ "$collide" = "0" ] && ok "每个分组 id 都能解析到组页，且不与命令名冲突"
  # every command has a page whose usage block names its own path
  local bad=0
  for c in "${MG_ORDER[@]}"; do
    local pg="$tmp/pages/en/command--$c.txt"
    [ -s "$pg" ] || { finding "命令 $c 没有页"; bad=1; continue; }
    grep -q "^  $c\( \|$\)" "$pg" || { finding "命令 $c 的页没有以它自己开头的用法行"; bad=1; }
  done
  [ "$bad" = "0" ] && ok "每个命令都有页，且用法块里以自己开头（${#MG_ORDER[@]} 个命令）"
  # no page may print a missing-key marker: a marker means the surface is incomplete, and the
  # key-set checks below make a genuinely missing key impossible on a clean tree
  local markers=0
  for c in "${MG_ORDER[@]}"; do
    local pg="$tmp/pages/en/command--$c.txt"
    local hits; hits="$(grep -c 'missing key' "$pg" 2>/dev/null || true)"
    [ "${hits:-0}" -gt 0 ] || continue
    finding "命令 $c 的页打印了缺键标记：$(grep -m1 'missing key' "$pg" | sed 's/^ *//' | cut -c1-60)"
    markers=1
  done
  for g in "${MG_GROUPS[@]}"; do
    local pg="$tmp/pages/en/group--$g.txt"
    local hits; hits="$(grep -c 'missing key' "$pg" 2>/dev/null || true)"
    [ "${hits:-0}" -gt 0 ] || continue
    finding "组页 $g 打印了缺键标记"
    markers=1
  done
  if grep -q 'missing key' "$tmp/pages/en/menu--menu.txt" 2>/dev/null; then
    finding "菜单打印了缺键标记"; markers=1
  fi
  [ "$markers" = "0" ] && ok "没有任何页面打印缺键标记（清单字段与散文键一一对上）"

  # a command with no flags prints no argument row, and one with flags prints exactly one per flag
  local argrow=0
  for c in "${MG_ORDER[@]}"; do
    local pg="$tmp/pages/en/command--$c.txt" rows
    rows="$(awk '
      { line=$0; if (line ~ /^[ \t]*$/) next
        n=match(line, /[^ ]/); ind=n-1
        if (ind == 6) { inargs = (line ~ /^ *Arguments/) }
        if (inargs && ind == 10 && line !~ /^ *$/) print line }
    ' "$pg" | wc -l)"
    local want=0
    [ "${MG_FLAGS[$c]}" = "-" ] || want="$(printf '%s\n' ${MG_FLAGS[$c]} | grep -c . || true)"
    if [ "$rows" != "$want" ]; then
      finding "命令 $c 的 Arguments 有 $rows 行，清单声明 $want 个旗标"
      argrow=1
    fi
  done
  [ "$argrow" = "0" ] && ok "每个命令页的 Arguments 行数与该命令的旗标数相同（${#MG_ORDER[@]} 个命令）"

  # the pages print exactly the usage lines the manifest declares (both directions)
  local drift=0
  for c in "${MG_ORDER[@]}"; do
    local pg="$tmp/pages/en/command--$c.txt" want got
    want="$(manifest_fragments "$c" | sort)"
    got="$(usage_entries "$pg" | sort)"
    if [ "$want" != "$got" ]; then
      finding "命令 $c 的页与清单不一致（$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | head -2 | paste -sd ' ' -)）"
      drift=1
    fi
  done
  [ "$drift" = "0" ] && ok "每个命令页打印的用法行与清单逐条相同（${#MG_ORDER[@]} 个命令 × 全部用法片段）"
  # every group page prints exactly its group's usage lines, in the manifest's order
  local gdrift=0
  for g in "${MG_GROUPS[@]}"; do
    local pg="$tmp/pages/en/group--$g.txt" want got
    want="$(manifest_group_commands "$g" | while read -r c2; do manifest_fragments "$c2" | head -1; done)"
    got="$(usage_entries "$pg")"
    if [ "$want" != "$got" ]; then
      finding "组页 $g 与清单不一致（$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | head -2 | paste -sd ' ' -)）"
      gdrift=1
    fi
  done
  [ "$gdrift" = "0" ] && ok "每个组页打印的用法行与清单逐条相同（${#MG_GROUPS[@]} 个组）"
  # aliases reach their primary with an alias line
  local aw=0
  for c in "${MG_ORDER[@]}"; do
    for a in ${MG_ALIASES[$c]}; do
      [ "$a" = "-" ] && continue
      local out extra
      out="$(page en "$a" --help)"
      extra="$(diff <(page en "$c" --help) <(printf '%s\n' "$out") | grep '^>' | sed 's/^> //')"
      if [ "$(printf '%s\n' "$extra" | grep -c .)" != "1" ]; then
        finding "别名 $a 打印的页比 $c 的页多了 $(printf '%s\n' "$extra" | grep -c .) 行（应只多一条别名行）"; aw=1
      elif ! printf '%s' "$extra" | grep -q "$a" || ! printf '%s' "$extra" | grep -q "$c"; then
        finding "别名 $a 的别名行没有同时点名别名与主命令"; aw=1
      fi
    done
  done
  [ "$aw" = "0" ] && ok "每个别名都打印主命令的页并点名该别名"

  # O2 · the dispatcher's internal entries are a closed set, declared in one place (here)
  local internal="__inbox-write __panel-data"
  local found want nm extra="" miss="" n
  found="$(team_internal_labels)"
  want="$(printf '%s\n' $internal | sort -u)"
  for n in $found; do printf '%s\n' $want | grep -qx "$n" || extra="$extra $n"; done
  for n in $want; do printf '%s\n' $found | grep -qx "$n" || miss="$miss $n"; done
  if [ -n "$extra" ]; then finding "内部入口清单：dispatcher 的 __ 标签$extra 不在声明清单里"; fi
  if [ -n "$miss" ]; then finding "内部入口清单：声明清单里的$miss 已经不是 dispatcher 的 __ 标签"; fi
  if [ -z "$extra" ] && [ -z "$miss" ]; then
    ok "内部入口清单与 dispatcher 的 __ 标签双向相等（$(printf '%s\n' $want | grep -c . ) 个）"
  fi
  local leak=0 d hits
  for d in "$tmp/pages/en" "$tmp/pages/zh"; do
    [ -d "$d" ] || continue
    for n in $internal; do
      hits="$(grep -rl -e "$n" "$d" 2>/dev/null | head -3 | while read -r f; do basename "$f"; done | paste -sd ' ' -)"
      [ -n "$hits" ] && { finding "页面打印了内部入口 $n：$hits"; leak=1; }
    done
  done
  [ "$leak" = "0" ] && ok "没有任何页面打印内部入口的名字（菜单/组页/命令页，两种语言）"
  local pre=0
  for n in "${MG_ORDER[@]}"; do
    case "$n" in __*) finding "清单里的命令名 $n 以 __ 开头（内部入口不许进清单）"; pre=1 ;; esac
  done
  [ "$pre" = "0" ] && ok "清单里没有以 __ 开头的命令名"

  # O6 · reachability is judged from the manifest: the menu names every declared group and no other,
  # and every command is listed by a group page whose group the menu has an entry point for
  local declared named g c unreach rg=0
  declared="$(printf '%s\n' "${MG_GROUPS[@]}" | sort -u)"
  named="$(awk '/^──/{exit} /^  [^ ]/{print $1}' "$tmp/pages/en/menu--menu.txt" 2>/dev/null | sort -u)"
  for g in $declared; do
    printf '%s\n' "$named" | grep -qx "$g" && continue
    unreach="$(manifest_group_commands "$g" | paste -sd ' ' -)"
    finding "分组 $g 在菜单里没有入口，它下面的命令${unreach:-（无）}变成不可达"
    rg=1
  done
  for g in $named; do
    printf '%s\n' "$declared" | grep -qx "$g" || { finding "菜单点名了清单没有声明的分组 $g"; rg=1; }
  done
  [ "$rg" = "0" ] && ok "菜单的分组入口与清单的分组表双向相等（${#MG_GROUPS[@]} 个组）"
  local reach=0
  for c in "${MG_ORDER[@]}"; do
    g="${MG_GROUP[$c]}"
    if ! printf '%s\n' "$declared" | grep -qx "$g"; then
      finding "命令 $c 不可达：它的分组 $g 没有声明，没有组页会列它"; reach=1; continue
    fi
    if ! printf '%s\n' "$named" | grep -qx "$g"; then
      finding "命令 $c 不可达：它的分组 $g 在菜单里没有入口"; reach=1; continue
    fi
    grep -q "^  $c\( \|$\)" "$tmp/pages/en/group--$g.txt" 2>/dev/null \
      || { finding "命令 $c 不可达：组页 $g 没有列出它"; reach=1; }
  done
  [ "$reach" = "0" ] && ok "每个命令都能从菜单经组页在三级内到达（${#MG_ORDER[@]} 个命令）"

  # G4 · an undeclared `{…}` token must fail the render instead of being printed (scratch copy)
  local g4="$tmp/g4-guard"
  rm -rf "$g4"; mkdir -p "$g4/skills"
  cp -a "$skill" "$g4/skills/teamsmith"
  if python3 - "$g4/skills/teamsmith/scripts/strings/help.en.tsv" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
key = "cmd.dispatch.what\t"
i = s.index(key) + len(key)
j = s.index("\n", i)
open(p, "w", encoding="utf-8").write(s[:j] + " {undeclared}" + s[j:])
PYEOF
  then
    local g4out g4rc
    g4out="$( cd "$tmp" && TEAM_LANG=en bash "$g4/skills/teamsmith/scripts/team" help dispatch 2>&1 )"; g4rc=$?
    if [ "$g4rc" = "0" ]; then
      finding "G4：表里出现未声明的 {undeclared} 时渲染仍 exit 0（那一页会把它原样打出来）"
    elif ! printf '%s' "$g4out" | grep -qF '{undeclared}'; then
      finding "G4：渲染非零退出（rc=$g4rc）但没有点名 {undeclared}"
    elif ! printf '%s' "$g4out" | grep -qF 'help.en.tsv'; then
      finding "G4：点名了 token 却没说它来自哪张表（$(printf '%s' "$g4out" | head -1 | cut -c1-60)）"
    elif printf '%s' "$g4out" | grep -q 'Usage'; then
      finding "G4：渲染失败却仍打印了那一页"
    else
      ok "G4：未声明的 {undeclared} 让渲染非零退出（rc=$g4rc）、点名 token 与来源表、且不打印那一页"
    fi
  else
    finding "G4：夹具没能把 {undeclared} 写进 scratch 副本"
  fi
  rm -rf "$g4"
  return 0
}

# ---------------------------------------------------------------- language
check_lang() {
  section "lang · 默认英文、TEAM_LANG 的机制（切中文 / 非法值告警回退 / 缺键可见）、机器出口"
  local en zh
  en="$(page en help)"; zh="$(page zh help)"
  if printf '%s' "$en" | has_cjk; then finding "缺省语言不是英文（菜单里有 CJK 字符）"; else ok "缺省语言是英文"; fi
  if printf '%s' "$zh" | has_cjk; then ok "TEAM_LANG=zh 切到中文"; else finding "TEAM_LANG=zh 没有切到中文"; fi
  # the structure is byte-identical between the languages: the usage lines must be
  local same=1
  for c in "${MG_ORDER[@]}"; do
    diff -q <(page en help "$c" | grep -E '^  [^ ]') <(page zh help "$c" | grep -E '^  [^ ]') >/dev/null 2>&1 || {
      finding "命令 $c 的用法行在两种语言下不相同"; same=1; }
  done
  [ "$same" = "1" ] && ok "命令路径、旗标与用法片段在两种语言下逐字节相同"
  # invalid value: one warning naming it, English surface, status unchanged
  local warn out rc
  out="$( cd "$tmp" && TEAM_LANG=fr bash "$team" help 2>"$tmp/hs-warn.txt" )"; rc=$?
  warn="$(cat "$tmp/hs-warn.txt")"
  if [ "$rc" = "0" ] && printf '%s' "$warn" | grep -q 'TEAM_LANG=fr' && [ "$(printf '%s\n' "$warn" | grep -c .)" = "1" ]; then
    ok "非法 TEAM_LANG 打印一行点名告警、状态不变（rc=0）"
  else
    finding "非法 TEAM_LANG 没有可见告警或状态变了（rc=$rc）：$warn"
  fi
  printf '%s' "$out" | has_cjk && finding "非法 TEAM_LANG 没有回退英文"
  # a missing key is visible: in a scratch copy whose Chinese table lacks one key, the page names
  # that key in a marker and prints the other language's value (never blank, never a crash)
  local mut2="$tmp/mut-lang"; rm -rf "$mut2"; mkdir -p "$mut2"
  cp -a "$skill" "$mut2/teamsmith"
  awk -F'\t' 'BEGIN{OFS="\t"} $1=="cmd.status.what"{next} {print}' \
    "$mut2/teamsmith/scripts/strings/help.zh.tsv" > "$mut2/zh.tmp" \
    && mv "$mut2/zh.tmp" "$mut2/teamsmith/scripts/strings/help.zh.tsv"
  local mo
  mo="$( cd "$tmp" && TEAM_LANG=zh TEAM_SKILL_DIR="$mut2/teamsmith" \
          ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} bash "$mut2/teamsmith/scripts/team" help status 2>&1 )"
  if printf '%s' "$mo" | grep -qE 'missing key: cmd\.status\.what» [A-Za-z]'; then
    ok "缺键渲染可见：标记点名 cmd.status.what，并用英文值兜底（不空白、不崩）"
  else
    finding "缺键没有渲染出可见标记或没有另一语言兜底：$(printf '%s' "$mo" | grep -i 'missing' | head -1 | cut -c1-60)"
  fi

  # machine exits: identical under en, zh and a mutated table
  local mut="$tmp/mut-help"; rm -rf "$mut"; mkdir -p "$mut"
  cp -a "$str" "$mut/strings"
  awk -F'\t' 'BEGIN{OFS="\t"} $1=="cmd.help.what" {$2=$2" MUTATED"} {print}' "$mut/strings/help.en.tsv" > "$mut/strings/help.en.tsv.new" \
    && mv "$mut/strings/help.en.tsv.new" "$mut/strings/help.en.tsv"
  local d; d="$(new_repo lang-machine)"
  setup_fixture proj "$d" lang-machine || return 1
  local a b c3
  a="$( cd "$d" && TEAM_LANG=en PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" bash "$team" paths 2>&1 )"
  b="$( cd "$d" && TEAM_LANG=zh PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" bash "$team" paths 2>&1 )"
  if [ "$a" = "$b" ]; then ok "team paths --json 在两种语言下逐字节相同"; else finding "语言改变了 team paths 的输出"; fi
  # the panel is a human view: it carries a clock and machine numbers, so compare it modulo the
  # volatile fields (a time, a count) — a language-dependent difference must not survive that.
  local m1 m2
  # warm-up: the first panel in a fresh fixture fills its capacity line asynchronously, and that
  # artefact must not be mistaken for a language difference
  ( cd "$d" && TEAM_LANG=en PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" bash "$team" monitor --print --no-activity --once >/dev/null 2>&1 ) || true
  m1="$( cd "$d" && TEAM_LANG=en PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" bash "$team" monitor --print --no-activity --once 2>&1 | volatile_scrub )"
  m2="$( cd "$d" && TEAM_LANG=zh PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" bash "$team" monitor --print --no-activity --once 2>&1 | volatile_scrub )"
  if [ "$m1" = "$m2" ]; then ok "team monitor --print 在两种语言下相同（已抹去时钟与计数这类易变字段）"
  else
    printf '%s\n' "$m1" > "$tmp/monitor-en.txt"; printf '%s\n' "$m2" > "$tmp/monitor-zh.txt"
    finding "语言改变了 team monitor 的输出：$(diff "$tmp/monitor-en.txt" "$tmp/monitor-zh.txt" | head -2 | tr '\n' ' ' | cut -c1-70)（两份输出留在 $tmp）"
  fi
  return 0
}

help_width() { printf '%s\n' "${TEAM_HELP_WIDTH:-100}"; }

# volatile_scrub — the fields a human view carries that change between two runs (a clock, a count)
volatile_scrub() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/TIME/g; s/[0-9]+/N/g'; }

# ---------------------------------------------------------------- claims (declarations + probes)
FACE_VOCAB="state docs config worktree skills meetings"
# mirrors scripts/lib/cmd-help.sh's declaration; the checker compares the two below
TEAM_HELP_AUTH_CONDITIONS="TEAM_CONFIRM_WRITES"
EFFECT_VOCAB="read-only writes-<face> starts-process"
# commands whose real run is a whole suite: the probe judges a bounded window (never a silent skip)
BOUNDED_PROBES="smoke perf"

probe_is_bounded() { case " $BOUNDED_PROBES " in *" $1 "*) return 0 ;; esac; return 1; }

check_vocabulary() {
  local bad=0 c eff face
  for c in "${MG_ORDER[@]}"; do
    eff="${MG_EFFECT[$c]}"
    case "$eff" in
      read-only|starts-process) ;;
      writes-*) face="${eff#writes-}"
        case " $FACE_VOCAB " in *" $face "*) ;; *) finding "claims: $c 的 effect=$eff 用了词表外的面"; bad=1 ;; esac ;;
      *) finding "claims: $c 声明了词表外的 effect=$eff"; bad=1 ;;
    esac
    for face in ${MG_FACES[$c]}; do
      [ "$face" = "-" ] && continue
      case " $FACE_VOCAB " in *" $face "*) ;; *) finding "claims: $c 的触碰面 $face 不在词表里"; bad=1 ;; esac
    done
    case "${MG_AUTH[$c]}" in
      none|needs-yes) ;;
      needs-yes:*) local cond="${MG_AUTH[$c]#needs-yes:}"
        case " $TEAM_HELP_AUTH_CONDITIONS " in *" $cond "*) ;; *) finding "claims: $c 的授权条件 $cond 不在词表里"; bad=1 ;; esac ;;
      *) finding "claims: $c 声明了词表外的 auth=${MG_AUTH[$c]}"; bad=1 ;;
    esac
    case "${MG_UNDO[$c]}" in
      idempotent|undo-by-*) ;;
      not-reversible:*) [ -n "${MG_UNDO[$c]#not-reversible:}" ] || { finding "claims: $c 的 not-reversible 没有理由"; bad=1; } ;;
      *) finding "claims: $c 声明了词表外的 undo=${MG_UNDO[$c]}"; bad=1 ;;
    esac
    [ -n "${MG_EFFECT[$c]}" ] && [ -n "${MG_AUTH[$c]}" ] && [ -n "${MG_UNDO[$c]}" ] || { finding "claims: $c 三类字段不齐"; bad=1; }
    # every declared value names a probe: the probe id must exist in this file's recipe table
    probe_recipe "${MG_PROBE[$c]}" >/dev/null || { finding "claims: $c 的探针 id ${MG_PROBE[$c]} 没有配方"; bad=1; }
  done
  # the renderer's own closed set of authorization conditions must be the one this checker knows
  local declared; declared="$(grep -o 'TEAM_HELP_AUTH_CONDITIONS="[^"]*"' "$skill/scripts/lib/cmd-help.sh" | head -1 | sed 's/.*="//; s/"$//')"
  [ "$declared" = "$TEAM_HELP_AUTH_CONDITIONS" ] || { finding "claims: 渲染器声明的授权条件（$declared）与夹具认识的（$TEAM_HELP_AUTH_CONDITIONS）不一致"; bad=1; }
  [ "$bad" = "0" ] && ok "三类声明齐备、取值都在封闭词表里，且每个命令名到一条探针（${#MG_ORDER[@]} 个命令）"
  return 0
}

probe_env_of() { # <cmd> → extra env assignments for this probe
  case "$1" in
    close) printf 'TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON=probe\n' ;;
    # P276：普查读的是主机 /proc；探针把它指到一个空夹具根 —— 确定性、且绝不碰真机器上的进程。
    reap)  printf 'TEAM_ORPHAN_PROC_ROOT=%s/empty-proc\n' "$tmp" ;;
    # P292：interrupt 探针的对象是一个真的 stub 席位进程（TEAM_AGENT_BIN 指到它，argv[0] 的 basename
    # 因此命中）与窗口表里的一行；pane_pid 由 shim 从这个 pid 文件回答。
    interrupt) printf 'TEAM_AGENT_BIN=%s/interrupt-agent HS_PANE_PID_FILE=%s/pane-pids/interrupt\n' "$SHIM" "$tmp" ;;
  esac
}

probe_stdin_of() { # <cmd> <dir> → the stdin source for this probe (default /dev/null)
  case "$1" in
    reply) printf '%s\n' "$2/reply-body.md" ;;
    *) printf '\n' ;;
  esac
}

probe_stdin_prepare() { # <cmd> <dir>
  case "$1" in
    reply) printf 'the probe body for team reply post\n' > "$2/reply-body.md" ;;
  esac
  return 0
}

probe_prepare_extra() { # <cmd> <dir> <tmp> — the per-command extras that need the fixture's branches
  local cmd="$1" d="$2"
  case "$cmd" in
    review)
      rm -rf "$tmp/review-$cmd"
      git -C "$d" worktree add -q --detach "$tmp/review-$cmd" task/T1-first-task >/dev/null 2>&1 || true ;;
  esac
  return 0
}

probe_prepare() { # <cmd> <dir> <setup>
  local cmd="$1" d="$2" setup="$3"
  case "$cmd" in
    draft) printf '# note\n' > "$d/draft.md" ;;
    reap)  mkdir -p "$tmp/empty-proc" ;;
    resume) # a seat with unfinished work whose window is gone
      grep -v "^p-$cmd:dev$" "$tmp/windows.reg" > "$tmp/windows.reg.tmp" 2>/dev/null || true
      mv "$tmp/windows.reg.tmp" "$tmp/windows.reg" 2>/dev/null || true ;;
  esac
  return 0
}

probe_args() { # <cmd> → the argv with the per-probe placeholders resolved
  local cmd="$1" d="$2" rec
  rec="$(probe_recipe "$cmd")"; rec="${rec#*|}"
  rec="${rec//PROBE/$3}"
  rec="${rec//DRAFT/$d/draft.md}"
  rec="${rec//REVIEWDIR/$tmp/review-$cmd}"
  printf '%s\n' "$rec"
}

run_probe() { # <cmd> → ok/finding
  local cmd="$1" rec setup d argv envs
  rec="$(probe_recipe "$cmd")" || { finding "claims: $cmd 没有探针配方"; return 1; }
  setup="${rec%%|*}"
  d="$(new_repo "p-$cmd")"
  if ! setup_fixture "$setup" "$d" "p-$cmd" >"$tmp/logs/p-$cmd.setup" 2>&1; then
    finding "claims: $cmd 的夹具（$setup）搭不起来：$(tail -1 "$tmp/logs/p-$cmd.setup")"
    return 1
  fi
  argv="$(probe_args "$cmd" "$d" "p-$cmd")"
  envs="$(probe_env_of "$cmd")"
  HS_ENV="$envs"
  HS_STDIN="$(probe_stdin_of "$cmd" "$d")"
  probe_prepare "$cmd" "$d" "$setup"
  probe_stdin_prepare "$cmd" "$d"
  probe_prepare_extra "$cmd" "$d"
  mkdir -p "$tmp/probe-tmp/$cmd"
  local eff="${MG_EFFECT[$cmd]}" faces="${MG_FACES[$cmd]}" before after i face changed missing
  before="$(fp_all "$d")"
  local launch_before launch_after
  launch_before="$(cat "$tmp/tmux-calls.log" "$tmp/launch.log" 2>/dev/null | wc -l)"

  if probe_is_bounded "$cmd"; then
    # a whole-suite command: judge a bounded window and say so
    ( cd "$d" && env -u TMUX -u TMUX_PANE PATH="$SHIM:$PATH" TMPDIR="$tmp/probe-tmp/$cmd" \
        TEAM_PI_BIN="$SHIM/fakeagent" TEAM_MEETINGS_DIR="$TEAM_MEETINGS_DIR" \
        TEAM_PI_AGENT_DIR="$tmp/pi-agent" $envs \
        ${TIMEOUT_BIN:+"$TIMEOUT_BIN" 25} bash "$team" $argv </dev/null >"$tmp/logs/p-$cmd.out" 2>&1 )
    after="$(fp_all "$d")"
    if [ "$before" = "$after" ]; then
      ok "claims: $cmd 只读（有界窗口 25s 内调用者未被改动；整段套件按窗口判定，见报告）"
    else
      finding "claims: $cmd 在有界窗口内改动了调用者：$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -2 | tr '\n' ' ')"
    fi
    return 0
  fi

  if [ "${MG_AUTH[$cmd]}" = "needs-yes" ]; then
    env_run "$d" $(printf '%s' "$argv" | sed 's/--yes//') >/dev/null 2>&1
    local rc_ny="$HS_RC" out_ny="$HS_OUT" face
    after="$(fp_all "$d")"
    changed=""
    while read -r face _; do
      [ "$(printf '%s\n' "$before" | grep "^$face ")" = "$(printf '%s\n' "$after" | grep "^$face ")" ] || changed="$changed $face"
    done <<< "$after"
    changed="${changed# }"
    # 「没有 --yes 就不动手」有两种诚实形状：① 拒绝（rc≠0；既有：meeting 的条件授权）；② **计划态**
    # （rc=0；interrupt 的边界规格明文写着「计划态退 0、零写盘」）。共同的不变量是「一个字都不写」
    # 加上「点名 --yes」：声明了 needs-yes 却照样动手（面有变化）或对 --yes 只字不提，都还是红。
    # （旧臂只认 ①，而且它的 case 词写成了 `$MG_AUTH[$cmd]`（没有花括号）—— 一个从不执行的死行：
    #   bare needs-yes 第一次被真用到时它就以 `MG_AUTH: unbound variable` 崩掉，本段替掉它。）
    if [ -n "$changed" ]; then
      finding "claims: $cmd 声明 needs-yes，但没有 --yes 时照样动手（改了：$changed）"
    elif ! printf '%s' "$out_ny" | grep -q -- '--yes'; then
      finding "claims: $cmd 声明 needs-yes，但没有 --yes 时既不拒绝、也不点名 --yes（rc=$rc_ny）"
    elif [ "$rc_ny" = "0" ]; then
      ok "claims: $cmd 没有 --yes 时只给计划：一个字不写、点名 --yes（rc=0；计划态不是执行）"
    else
      ok "claims: $cmd 没有 --yes 时拒绝（rc=$rc_ny）、点名 --yes 且一个字不写"
    fi
    argv="$argv --yes"
  fi

  env_run "$d" $argv >/dev/null 2>&1
  local rc="$HS_RC"
  printf '%s\n' "$HS_OUT" > "$tmp/logs/p-$cmd.out"
  after="$(fp_all "$d")"
  changed=""
  while read -r face _; do
    grep -q "^$face " <<< "$after" || continue
    [ "$(printf '%s\n' "$before" | grep "^$face ")" = "$(printf '%s\n' "$after" | grep "^$face ")" ] || changed="$changed $face"
  done <<< "$after"
  changed="${changed# }"
  launch_after="$(cat "$tmp/tmux-calls.log" "$tmp/launch.log" 2>/dev/null | wc -l)"

  printf '  \033[2m·\033[0m 探针 %-11s rc=%-3s 变化=%-28s\n' "$cmd" "$rc" "${changed:-（无）}"
  case "$eff" in
    read-only)
      if [ -z "$changed" ]; then ok "claims: $cmd 只读（跑完后状态指纹不变）"
      else finding "claims: $cmd 声明 read-only，但它改了：$changed"; fi ;;
    starts-process)
      if [ "$launch_after" -gt "$launch_before" ]; then ok "claims: $cmd 起进程（记录器里有启动：$((launch_after - launch_before)) 条）"
      else finding "claims: $cmd 声明 starts-process，但记录器里没有启动（rc=$rc，$(head -1 "$tmp/logs/p-$cmd.out" | cut -c1-60)）"; fi ;;
    writes-*)
      if [ -n "$changed" ]; then ok "claims: $cmd 写了声明的面（$changed）"
      else finding "claims: $cmd 声明 $eff，但没有任何面发生变化（rc=$rc，$(head -1 "$tmp/logs/p-$cmd.out" | cut -c1-60)）"; fi ;;
  esac
  # every declared touched face must have moved
  for face in $faces; do
    [ "$face" = "-" ] && continue
    case " $changed " in *" $face "*) ;; *) finding "claims: $cmd 声明触碰 $face，但该面没有变化";; esac
  done
  # F1（V52 返修轮次 1）：反向判据 —— **动了的面必须都在声明里**。没有这一条，无论声明里删掉一个面
  # （`state docs` → `state`），还是实现多写一个未声明的面（真去写 `config`），探针都照样全绿：
  # 它只能证伪「声明了却没动」，不能证伪「动了却没声明」。声明的集合 = `faces` 列 ∪ `writes-<face>`
  # 效应点名的那个面；`read-only` 的「居然改了」由上面的分支判定，不在这里重复报一遍。
  if [ "$eff" != "read-only" ]; then
    for face in $changed; do
      case " $faces " in *" $face "*) continue ;; esac
      [ "$eff" = "writes-$face" ] && continue
      finding "claims: $cmd 动了没有声明的面 $face"
    done
  fi
  # undo
  case "${MG_UNDO[$cmd]}" in
    idempotent)
      # the declared recorded-time fields (IDEMPOTENT_TIME_FIELDS) get the sentinel before the second
      # run: the field is named, not excused, and the verdict cannot depend on the wall clock
      local base again stamped n_stamped lost="" s rc2 rc_missing wrote f field
      stamped="$tmp/logs/p-$cmd.stamped"; : > "$stamped"; n_stamped=0
      if [ -n "$(idem_fields "$cmd")" ]; then
        idem_stamp "$cmd" "$d" "$stamped"
        n_stamped="$(grep -c . "$stamped" 2>/dev/null || true)"
      fi
      base="$(fp_all "$d")"
      # The sentinel above covers the fields somebody *declared*. A clock-derived value nobody declared
      # is still invisible inside one second: run 1 and run 2 write the same bytes. Sleeping past a
      # second boundary makes the probe judge "a later run changed nothing" instead of "a run inside
      # the same second changed nothing" — the verdict stops depending on how fast the machine is,
      # which is exactly the clock the P290 flake hid behind (host green, container red). Cost: ~1.1s
      # per idempotent command, and only in the full gate (FAST does not run `claims`).
      sleep 1.1
      env_run "$d" $argv >/dev/null 2>&1
      rc2="$HS_RC"
      again="$(fp_all "$d")"
      # O1（V46）：第二次跑的退出码也要判——「第二次失败、不写盘」若只看字节会被当成幂等（假绿）。
      # 判据是「与第一次一致」而不是「必须为 0」：夹具里 gh/gl/pr 这类命令在没有远端时本来就以非零
      # 退出（只读拒绝），要求全部为 0 会把它们判红。rc 打进输出，红时点名两次的数。
      printf '  \033[2m·\033[0m 幂等 %-11s rc=%s → %s\n' "$cmd" "$rc" "$rc2"
      if [ "$rc2" = "$rc" ]; then
        ok "claims: $cmd 幂等：第二次跑退出码与第一次一致（rc $rc → $rc2）"
      else
        finding "claims: $cmd 声明幂等，但两次跑的退出码不同（rc $rc → $rc2）：第二次跑失败不算「什么都没变」"
      fi
      if [ "$base" = "$again" ]; then
        if [ "$n_stamped" = "0" ]; then
          ok "claims: $cmd 幂等（第二次跑逐字节不变）"
        else
          ok "claims: $cmd 幂等（第二次跑逐字节不变；指名的记录时间字段$(idem_names "$stamped") 经哨兵验证未被重写）"
        fi
      else
        while IFS= read -r s; do
          [ -n "$s" ] || continue
          grep -q "^${s#*:}=$IDEMPOTENT_SENTINEL$" "$d/${s%%:*}" 2>/dev/null || lost="$lost ${s#*:}（${s%%:*}）"
        done < "$stamped"
        if [ -n "$lost" ]; then
          finding "claims: $cmd 声明幂等，但第二次跑重写了指名的记录时间字段$lost：哨兵值被覆盖"
        else
          finding "claims: $cmd 声明幂等，但第二次跑改了状态"
        fi
      fi
      # F1（V46 返修轮次 1）：记录在、但没有指名的记录时间字段时，「没有可保留的时间」等于
      # 「没有记录」——命令必须照旧把字段补全并 rc=0。守卫若用裸赋值接一个没命中的 grep，在
      # set -e 下会把整个 CLI 带走（rc=1、一字不写）：既有的 smoke §17 用的就是这个形状。
      if [ "$n_stamped" != "0" ]; then
        while IFS= read -r s; do
          [ -n "$s" ] || continue
          f="$d/${s%%:*}"; field="${s#*:}"
          grep -v "^$field=" "$f" > "$f.p290m" 2>/dev/null || true
          mv "$f.p290m" "$f"
          env_run "$d" $argv >/dev/null 2>&1
          rc_missing="$HS_RC"; wrote=no
          grep -q "^$field=" "$f" 2>/dev/null && wrote=yes
          if [ "$rc_missing" = "0" ] && [ "$wrote" = "yes" ]; then
            ok "claims: $cmd 记录里缺指名的记录时间字段 $field 时补全并 rc=0（缺时间戳不是错误）"
          else
            finding "claims: $cmd 记录里缺指名的记录时间字段 $field 时 rc=$rc_missing、字段写回=$wrote（静默失败与不补全都算缺陷）"
          fi
        done < "$stamped"
      fi ;;
    undo-by-*)
      local undo_cmd="${MG_UNDO[$cmd]#undo-by-}"
      HS_ENV=""; HS_STDIN=/dev/null
      env_run "$d" "$undo_cmd" $( [ "$undo_cmd" = "pulse" ] && printf 'down' ) >/dev/null 2>&1
      local back; back="$(fp_all "$d")"
      [ "$before" = "$back" ] && ok "claims: $cmd 的撤销命令 `team $undo_cmd` 把状态放回去了" \
        || finding "claims: $cmd 声明 undo-by-$undo_cmd，但跑完之后状态没有复原" ;;
  esac
  return 0
}

check_claims() {
  section "claims · 封闭词表 + 逐命令探针（断言效应；幂等臂另判两次退出码一致）"
  check_vocabulary
  local c
  if [ -n "${TEAM_HELP_SURFACE_ONLY:-}" ]; then
    for c in ${TEAM_HELP_SURFACE_ONLY}; do run_probe "$c"; done
    return 0
  fi
  for c in "${MG_ORDER[@]}"; do
    run_probe "$c"
  done
  return 0
}

# ---------------------------------------------------------------- content
BASELINE_FLAGS=$(cat <<'EOF'
add-agent --create --no-install --print --register
board --allow-dup
bootstrap --agents --pm-model --print --task-models
changelog --since
change --json
dispatch --allow-overflow --branch --fresh --model --print
draft --now
mark-loaded --version
meeting --all --intent --knock --note --peek --since --topic --ttl --with --yes
monitor --events --height --interval --json --no-pulse --once --print --width
notify --from
outbox --now
perf --host
pulse --print
reload --done
reply --from --stdin --title
report --force
resume --agent --all --dry-run
review --allow-unresolved-branch --dir --no-gates --strong
say --now
standby --reason
task --agent --category --deps --issue --title
teardown --agent --all --force --purge --register
up --agents --fresh-pm --print
version --check
watch --interval --once --ui
EOF
)

check_invariants() {
  section "invariants · 命令名/旗标名/跨规格字面量一个不改（逻辑）"
  # the literals other specs expect
  local init_page; init_page="$tmp/pages/en/command--init.txt"
  local n=0
  grep -q '\.pi/skills' "$init_page" || { finding "invariants: init 页没有点名 .pi/skills"; n=1; }
  grep -q -- '--copy' "$init_page" || { finding "invariants: init 行没有 --copy"; n=1; }
  grep -q -- '--no-skills' "$init_page" || { finding "invariants: init 行没有 --no-skills"; n=1; }
  local aa; aa="$tmp/pages/en/command--add-agent.txt"
  for f in --register --create --no-install --print; do
    grep -q -- "$f" "$aa" || { finding "invariants: add-agent 行没有 $f"; n=1; }
  done
  grep -q -- '--model' "$aa" && { finding "invariants: add-agent 行打印了退休的 --model"; n=1; }
  grep -q -- '--register' "$tmp/pages/en/command--teardown.txt" || { finding "invariants: teardown 行没有 --register"; n=1; }
  grep -q -- '--branch <name>' "$tmp/pages/en/command--dispatch.txt" || { finding "invariants: dispatch 行没有 --branch <name>"; n=1; }
  [ "$n" = "0" ] && ok "跨规格字面量（init/add-agent/teardown/dispatch）逐条成立"
  # the pre-change flag set is a subset of the new one
  local nb=0 line cname fl
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    cname="${line%% *}"
    for fl in ${line#* }; do
      grep -q -- "$fl" "$tmp/pages/en/command--$cname.txt" || { finding "invariants: $cname 的页不再打印 $fl（旧面打印过它）"; nb=1; }
    done
  done <<< "$BASELINE_FLAGS"
  [ "$nb" = "0" ] && ok "改动前的每条 (命令,旗标) 声明都还在新面里"
  return 0
}

# ---------------------------------------------------------------- route
check_route() {
  section "route · 三级可达、两条入口逐字节相同、未知 token exit 2、无项目可用"
  local rc
  page en help >/dev/null; [ $? = 0 ] && ok "team help 是菜单（rc=0）"
  ( cd "$tmp" && bash "$team" >/dev/null 2>&1 ); [ $? = 0 ] && ok "team（无参）是菜单（rc=0）"
  local g
  for g in "${MG_GROUPS[@]}"; do
    local out; out="$(page en help "$g")"
    printf '%s\n' "$out" | grep -q "^  " || { finding "route: 组页 $g 没有命令"; continue; }
  done
  ok "每个分组页都列出命令"
  local c same=0
  for c in "${MG_ORDER[@]}"; do
    if ! diff -q <(page en help "$c") <(page en "$c" --help) >/dev/null 2>&1; then
      finding "route: $c 的两条入口不逐字节相同"; same=1
    fi
    if ! diff -q <(page en help "$c") <(page en "$c" -h) >/dev/null 2>&1; then
      finding "route: $c 的 -h 入口与 help 页不同"; same=1
    fi
  done
  [ "$same" = "0" ] && ok "team help <命令> 与 team <命令> --help/-h 逐字节相同（${#MG_ORDER[@]} 个命令）"
  # a page never falls back to the menu
  local dpage; dpage="$(page en dispatch --help)"
  case "$dpage" in
    "teamsmith · dispatch"*) ok "命令页以自己的标题开头（没有退回菜单）" ;;
    *) finding "route: 命令页退回了菜单：$(printf '%s' "$dpage" | head -1 | cut -c1-60)" ;;
  esac
  # unknown tokens
  local d; d="$(new_repo route-refusal)"
  setup_fixture proj "$d" route-refusal >/dev/null 2>&1
  local before after
  before="$(fp_all "$d")"
  for spec in "frobnicate --help" "help frobnicate" "help not-a-group" "-h frobnicate"; do
    env_run "$d" $spec
    local out="$HS_OUT" rc2="$HS_RC"
    if [ "$rc2" != "2" ]; then finding "route: team $spec 的退出码是 $rc2（应为 2）"; continue; fi
    if ! printf '%s' "$out" | grep -q 'frobnicate\|not-a-group'; then finding "route: team $spec 没有点名 token"; continue; fi
    printf '%s' "$out" | grep -q 'team help' || { finding "route: team $spec 没有指回 team help"; continue; }
  done
  after="$(fp_all "$d")"
  [ "$before" = "$after" ] && ok "未知 token：exit 2、点名 token、指回 team help，且不写状态" \
    || finding "route: 未知 token 的拒绝写了状态"
  # a name the dispatcher accepts is never refused this way
  local nope=0 c2
  for c2 in "${MG_ORDER[@]}"; do
    env_run "$d" "$c2" --help
    [ "$HS_RC" = "0" ] || { finding "route: 已知命令 $c2 的 --help 退出码是 $HS_RC"; nope=1; }
  done
  for c2 in "${MG_ORDER[@]}"; do
    for a in ${MG_ALIASES[$c2]}; do
      [ "$a" = "-" ] && continue
      env_run "$d" "$a" --help
      [ "$HS_RC" = "0" ] || { finding "route: 别名 $a 被拒绝（rc=$HS_RC）"; nope=1; }
    done
  done
  [ "$nope" = "0" ] && ok "dispatcher 接受的每个名字（含别名）都不会被当成未知 token"
  # a known parent with an unknown subcommand: the page plus a refusal naming the sub
  env_run "$d" config frobnicate --help
  if [ "$HS_RC" = "2" ] && printf '%s' "$HS_OUT" | grep -q 'frobnicate'; then
    ok "team <命令> <未知子命令> --help：打印该页并在页首点名子命令、exit 2"
  else
    finding "route: 未知子命令的形态不对（rc=$HS_RC）"
  fi
  # no project: every help entry works and writes nothing
  local nd="$tmp/no-project"; rm -rf "$nd"; mkdir -p "$nd"
  local w=0
  for spec in "help" "help dispatch" "dispatch --help" "help seats"; do
    ( cd "$nd" && env -u TMUX -u TMUX_PANE PATH="$SHIM:$PATH" TEAM_PI_BIN="$SHIM/fakeagent" \
        ${TIMEOUT_BIN:+"$TIMEOUT_BIN" "$timeout_sec"} bash "$team" $spec </dev/null >/dev/null 2>&1 )
    [ "$?" = "0" ] || { finding "route: 无项目目录时 team $spec 失败"; w=1; }
  done
  [ "$(find "$nd" -mindepth 1 | wc -l)" = "0" ] || { finding "route: 帮助路径在无项目目录里写了文件"; w=1; }
  [ "$w" = "0" ] && ok "帮助路径不需要项目：无 git、无契约的目录里四个入口都 exit 0 且不写文件"
  # requesting help never runs the helped command
  local lb; lb="$(cat "$tmp/tmux-calls.log" "$tmp/launch.log" 2>/dev/null | wc -l)"
  page en help dispatch >/dev/null
  page en dispatch --help >/dev/null
  local la; la="$(cat "$tmp/tmux-calls.log" "$tmp/launch.log" 2>/dev/null | wc -l)"
  [ "$lb" = "$la" ] && ok "请求帮助不执行被帮助的命令（记录器没有新调用）" \
    || finding "route: 请求帮助起了进程"
  return 0
}

# ---------------------------------------------------------------- red sides (--flip)
flip_copy() { # <name> → a scratch tree with its own copy of the skill
  local name="$1" c
  c="$tmp/flip/$name"
  rm -rf "$c"; mkdir -p "$c/skills"
  cp -a "$skill" "$c/skills/teamsmith"
  printf '%s\n' "$c"
}

flip_run() { # <label> <copy> <select> <expected substring> [only-command]
  local label="$1" copy="$2" sel="$3" expect="$4" only="${5:-}"
  local out rc fx="$0"
  # A mutation inside the fixture itself (the declared internal-entry list) only takes effect if the
  # copy's own checker runs; every other mutation is in the product, and the copy's fixture is
  # byte-identical to this one, so running it is the same check either way.
  [ -f "$copy/skills/teamsmith/tests/help-surface.sh" ] && fx="$copy/skills/teamsmith/tests/help-surface.sh"
  out="$(TEAM_HELP_SURFACE_TREE="$copy" TEAM_HELP_SURFACE_ONLY="$only" \
          bash "$fx" --select "$sel" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then
    finding "翻转 $label 没有红（检查看不见这个破坏）"
  elif ! printf '%s' "$out" | grep -qF -e "$expect"; then
    finding "翻转 $label 红了，但没有点名「$expect」：$(printf '%s' "$out" | grep '✗' | head -1 | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-70)"
  else
    # the evidence line prefers the finding this side was aimed at, and falls back to the first red
    local ev
    ev="$(printf '%s' "$out" | grep '✗' | grep -v '== 结果 ==' | grep -F -e "$expect" | head -1)"
    [ -n "$ev" ] || ev="$(printf '%s' "$out" | grep '✗' | grep -v '== 结果 ==' | head -1)"
    ok "翻转 $label：$(printf '%s' "$ev" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-90)"
  fi
  if [ "$keep" = "1" ]; then printf '\n保留翻转副本：%s\n' "$copy"; else rm -rf "$copy"; fi
}

flip_edit() { # <file> <python-expression on the text> — rewrites a file in place; must change it
  local file="$1" code="$2"
  python3 -c '
import sys
p, code = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
ns = {"s": s}
exec(code, ns)
if ns["s"] == s:
    sys.exit("flip_edit: the mutation changed nothing (stale pattern in %s)" % p)
open(p, "w", encoding="utf-8").write(ns["s"])
' "$file" "$code"
}

flip_wanted() { # <id> — does this red side belong to the requested --flip-only subset?
  [ -z "${TEAM_HELP_SURFACE_FLIP_ONLY:-}" ] && return 0
  case " $TEAM_HELP_SURFACE_FLIP_ONLY " in *" $1 "*) return 0 ;; esac
  return 1
}

# flip_case <id> <label> <file-relative-to-the-copy> <python> <select> <expected> [only-command]
# One red side end to end: copy the tree, mutate (asserted), run the check, judge the finding.
flip_case() {
  local id="$1" label="$2" rel="$3" code="$4" sel="$5" expect="$6" only="${7:-}"
  flip_wanted "$id" || return 0
  local c s
  c="$(flip_copy "flip-$id")"
  s="$c/skills/teamsmith/$rel"
  if ! flip_edit "$s" "$code" 2>"$tmp/flip-$id.err"; then
    finding "翻转 $label：变异没落地（夹具缺陷）—— $(head -1 "$tmp/flip-$id.err")"
    rm -rf "$c"
    return 0
  fi
  if [ "${TEAM_HELP_SURFACE_FLIP_DRY:-0}" = "1" ]; then
    ok "翻转 $label：变异落地（dry 模式只审模式）"
    rm -rf "$c"
    return 0
  fi
  flip_run "$label" "$c" "$sel" "$expect" "$only"
}

do_flips() {
  section "flip · 每条红侧：破坏 → 指定用例红 → 还原 → 全绿（只留逻辑类）"
  local dry="${TEAM_HELP_SURFACE_FLIP_DRY:-0}"

  # ③ a command disappears from its group page (its usage line survives only on its own page)
  flip_case "group-missing" "①组页漏一条命令" "scripts/lib/cmd-help.sh" \
    's = s.replace("""    [ "${_TH_GROUP[$i]}" = "$g" ] || continue""", """    [ "${_TH_GROUP[$i]}" = "$g" ] || continue
    [ "${_TH_NAMES[$i]}" != "status" ] || continue""", 1)' \
    coverage "与清单不一致"

  # ④ one manifest row is deleted (the dispatcher still accepts the command)
  flip_case "row-deleted" "②删一条命令记录" "scripts/strings/commands.tsv" \
    's = "\n".join(l for l in s.split("\n") if not l.startswith("cmd\tbg\t"))' \
    coverage "bg"

  # ⑤ an unknown token is answered with exit 0
  flip_case "unknown-zero" "③未知 token 走成 exit 0" "scripts/lib/cmd-help.sh" \
    's = s.replace("team_help_refuse \"$token\"; return $?", "team_help_menu; return 0", 1)' \
    route "退出码是 0"

  # ⑥ the help path loads the project contract before answering
  flip_case "help-loads-config" "④帮助路径读配置" "scripts/team" \
    's = s.replace("""if [ "$_TEAM_HELP_REQ" = "1" ]; then""", """team_load_config || exit 1
if [ "$_TEAM_HELP_REQ" = "1" ]; then""", 1)' \
    route "无项目目录"

  # ⑦ an invalid TEAM_LANG is silent
  flip_case "lang-silent" "⑤非法 TEAM_LANG 静默" "scripts/lib/cmd-help.sh" \
    's = s.replace("""    *) printf \x27teamsmith: TEAM_LANG=%s is not a known language (en, zh); printing English\\n\x27 "$TEAM_LANG" >&2 ;;""", "    *) ;;", 1)' \
    lang "非法 TEAM_LANG"

  # ⑧ one Chinese key is missing (the page must name it and fall back)
  flip_case "key-silent" "⑥缺键静默（不渲染标记）" "scripts/lib/cmd-help.sh" \
    's = s.replace("  printf \x27%s\x27 \"$(team_help_marker \"$key\")\"", "  :", 1)' \
    lang "缺键没有渲染出可见标记"

  # ⑩ a machine exit starts carrying language-dependent output
  flip_case "machine-drift" "⑦机器出口跟着语言走" "scripts/lib/common.sh" \
    's = s.replace("team_paths_json() {", "team_paths_json() {" + chr(10) + "  [ -z \"${TEAM_LANG:-}\" ] || printf \x27%s\x27 \"$TEAM_LANG\" >&2", 1)' \
    lang "语言改变了 team paths"

  # ⑰b a declared flag with no prose key → the page prints a missing-key marker
  flip_case "arg-key-missing" "⑧声明的旗标没有散文键" "scripts/strings/help.en.tsv" \
    's = "\n".join(l for l in s.split("\n") if not l.startswith("cmd.dispatch.arg.--fresh\t"))' \
    coverage "missing key" 

  # ── help-robustness (P278) ────────────────────────────────────────────────────────────────────
  # O1: the width classification reads the locale again — the old `$'\uXXXX'` brace ranges made one
  # CJK character three cells under LC_ALL=C, so the same page wrapped differently in the two locales
  flip_case "locale-dependent-width" "⑨宽度计算退回 locale 依赖" "scripts/lib/cmd-help.sh" \
    's = s.replace("""    if [ "$cp" -ge "${r%-*}" ] && [ "$cp" -le "${r#*-}" ]; then _TH_CELLS=2; return 0; fi""", """    if [ "$cp" -ge "${r%-*}" ] && [ "$cp" -le "${r#*-}" ]; then
      case "${LC_ALL:-${LANG:-}}" in *UTF-8*|*utf8*) _TH_CELLS=2 ;; *) _TH_CELLS=3 ;; esac
      return 0
    fi""", 1)' \
    locale "随 locale 变" dispatch

  # O2a: one more `__`-prefixed dispatcher label than the declared internal set names
  flip_case "internal-undeclared" "⑩dispatcher 多一个 __ 标签" "scripts/team" \
    's = s.replace("""  __panel-data) team_cmd_panel_data "$@" ;;""", """  __probe-x) exit 0 ;;
  __panel-data) team_cmd_panel_data "$@" ;;""", 1)' \
    coverage "__probe-x"

  # O2b: the declared internal set names one entry that is no longer a dispatcher label
  flip_case "internal-list-short" "⑪声明清单里删一个内部名" "tests/help-surface.sh" \
    's = s.replace("__inbox-write __panel-data", "__panel-data", 1)' \
    coverage "__inbox-write"

  # O6a: a declared group disappears from the manifest while its commands still name it
  flip_case "group-row-deleted" "⑫清单删一条分组记录（命令仍声明它）" "scripts/strings/commands.tsv" \
    's = "\n".join(l for l in s.split("\n") if l != "group\tversions")' \
    coverage "versions"

  # O6b: the menu renderer skips one declared group (the group page still lists its commands)
  flip_case "menu-skips-group" "⑬菜单渲染器跳过一个已声明的分组" "scripts/lib/cmd-help.sh" \
    's = s.replace("    local title purpose cells pad line", """    local title purpose cells pad line
    [ $g = versions ] && continue""", 1)' \
    coverage "versions"

  # G4: the placeholder check disappears → the guard's scratch copy prints the token literally
  flip_case "placeholder-check-gone" "⑭去掉未声明占位符的检查" "scripts/lib/cmd-help.sh" \
    's = s.replace("""  [ "$_bad" = "0" ] || return 1""", """  [ "$_bad" = "0" ] || :""", 1)' \
    coverage "{undeclared}"

  # ── P290 · 幂等探针的红侧（声明与行为不一致的三种形状） ──────────────────
  # ①a command that really writes on every run while its row declares `idempotent`
  flip_case "idem-writes" "⑮幂等命令第二次跑仍然写状态" "scripts/lib/cmd-status.sh" \
    's = s.replace("""team_cmd_status() {\n  team_require_docs""", """team_cmd_status() {\n  team_require_docs\n  mkdir -p \"$TEAM_STATE_DIR\"; printf \x27%s\\n\x27 \"$(wc -l < \"$TEAM_STATE_DIR/probe-idem.txt\" 2>/dev/null || true)\" >> \"$TEAM_STATE_DIR/probe-idem.txt\"""", 1)' \
    claims "声明幂等，但第二次跑改了状态" status

  # ②the recorded-time field is rewritten on every run again — the P290 flake's exact shape; the
  #   sentinel makes this red no matter how fast the two runs are (no clock, no sleep)
  flip_case "mark-loaded-rewrites" "⑯去掉「无变化不重写」的守卫（P290 的时钟缺陷回退）" "scripts/lib/cmd-update.sh" \
    's = s.replace("""  if [ -n "$stored_at" ] && [ "$stored_core" = "$core" ]; then""", "  if false; then", 1)' \
    claims "重写了指名的记录时间字段" mark-loaded

  # ③the declared field is no longer written at all: the table's entry must be a finding, not a
  #   silently passing no-op
  flip_case "time-field-gone" "⑰声明的记录时间字段不再被写（声明过期必红）" "scripts/lib/cmd-update.sh" \
    's = s.replace("""    printf \x27AT=%s\\n\x27 \"$(team_timestamp)\"\n""", "", 1)' \
    claims "声明过期" mark-loaded

  # ⑱ a clock field nobody declared, with the declaration table emptied for mark-loaded: the sentinel
  #   cannot see that pair, so the only thing that makes the rewrite visible is the 1.1s gap — this is
  #   the red side that shows the gap is load-bearing rather than decoration, and it is the exact shape
  #   of the P290 defect (an undeclared clock field, invisible on a fast same-second host)
  if flip_wanted "clock-undeclared"; then
    local c18
    c18="$(flip_copy "flip-clock-undeclared")"
    if flip_edit "$c18/skills/teamsmith/scripts/lib/cmd-update.sh" \
         's = s.replace("""  if [ -n "$stored_at" ] && [ "$stored_core" = "$core" ]; then""", "  if false; then", 1)' 2>"$tmp/flip-18a.err" \
       && flip_edit "$c18/skills/teamsmith/tests/help-surface.sh" \
         's = s.replace("  [mark-loaded]=\".pi/team/state/pm-loaded.env:AT\"\n", "", 1)' 2>"$tmp/flip-18b.err"; then
      flip_run "⑱未指名的时钟字段（只有 1.1s 间隔抓得住）" "$c18" claims "第二次跑改了状态" mark-loaded
    else
      finding "翻转 ⑱：变异没落地（夹具缺陷）—— $(head -1 "$tmp/flip-18b.err" 2>/dev/null || head -1 "$tmp/flip-18a.err")"
      rm -rf "$c18"
    fi
  fi

  # ── P290 · 返修轮次 1（V46 的 F1 与 O1）─────────────────────────────────────
  # ⑲ F1 的形状回退：守卫改回裸赋值接一个没命中的 grep，set -e 把 CLI 带走。记录里没有指名的
  #    时间字段时必须补全并 rc=0——这条红侧证明夹具里那条新臂是承重的（V46 F1 的真实形状）。
  flip_case "missing-time-field" "⑲记录缺 AT= 行时静默失败（V46 F1 的回退）" "scripts/lib/cmd-update.sh" \
    's = s.replace("""    stored_at="$(grep -s -m1 \x27^AT=\x27 "$f" 2>/dev/null || true)"\n  fi""", """    stored_at="$(grep -s \x27^AT=\x27 "$f" | head -1)"\n  fi""", 1)' \
    claims "记录里缺指名的记录时间字段 AT" mark-loaded

  # ⑳ O1：第二次跑以非零退出、且不写盘（V46 的 m3）——只看字节会判绿，退出码断言是唯一抓手。
  flip_case "second-run-fails" "⑳第二次跑失败但不写盘（退出码盲区）" "scripts/lib/cmd-update.sh" \
    's = s.replace("""    team_ok "本会话 skill 版本未变化：$ver（指纹 $hash；保留 $(basename "$f") 里记录的时间）"\n    return 0""", """    team_ok "本会话 skill 版本未变化：$ver（指纹 $hash；保留 $(basename "$f") 里记录的时间）"\n    return 1""", 1)' \
    claims "两次跑的退出码不同" mark-loaded

  # ── P292 · 返修轮次 1（V52 的 F1）────────────────────────────────────────────────────────────
  # ㉑ 少声明：interrupt 的 `faces` 删掉 docs。旧探针只判「声明的面都动了」，这一改照样全绿（V52 §2.5）；
  #    反向判据必须红并点名那个没被声明的面。
  flip_case "interrupt-face-unlisted" "㉑命令页少写一个已触碰的面" "scripts/strings/commands.tsv" \
    's = s.replace("\tseat\tstate docs\twrites-state\t", "\tseat\tstate\twrites-state\t", 1)' \
    claims "动了没有声明的面 docs" interrupt

  # ㉒ 多写未声明面：实现真去写 `config`（V52 §2.6 的同一形状）—— 反向判据必须红并点名 config。
  #    声明侧一个字没动：红只能来自「变了的面没在声明里」，不能来自探针变瞎。
  flip_case "interrupt-writes-undeclared" "㉒实现多写一个没有声明的面" "scripts/lib/cmd-interrupt.sh" \
    's = s.replace("""    "${7:--}" "${8:--}" "${9:--}" >> "$f" || return 1""", """    "${7:--}" "${8:--}" "${9:--}" >> "$f" || return 1
  printf \x27# probe mutation\n\x27 >> .pi/team/config.sh""", 1)' \
    claims "动了没有声明的面 config" interrupt

  # ㉓ 写工作树：实现往席位工作树里写一个文件（`interrupt` 的规格明写工作树逐字节不变）。旧指纹只有
  #    `worktree list` + 分支 ref，对内容和写盘是盲的（V52 §2.6 尾）；现在 worktree 面含内容 → 必须红。
  flip_case "interrupt-writes-worktree" "㉓实现往席位工作树里写文件" "scripts/lib/cmd-interrupt.sh" \
    's = s.replace("""    "${7:--}" "${8:--}" "${9:--}" >> "$f" || return 1""", """    "${7:--}" "${8:--}" "${9:--}" >> "$f" || return 1
  printf \x27# probe mutation\n\x27 > .worktrees/dev/probe-mut.txt""", 1)' \
    claims "动了没有声明的面 worktree" interrupt

  return 0
}

# ---------------------------------------------------------------- result
load_manifest "$str/commands.tsv"
_need_pages=0
for _s in coverage invariants; do want "$_s" && _need_pages=1; done
[ "$FLIP" = "1" ] && _need_pages=1
if [ "$_need_pages" = "1" ]; then
  render_pages en
  [ -n "${TEAM_HELP_SURFACE_ONLY:-}" ] || render_pages zh
fi
if want coverage; then check_coverage; fi
if want locale;   then check_locale;   fi
if want lang;     then check_lang;     fi
if want claims;   then check_claims;   fi
if want invariants; then check_invariants; fi
if want route;    then check_route;    fi
if [ "$FLIP" = "1" ]; then do_flips; fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FIND" "$SKIP"
[ "$FIND" -eq 0 ] && exit 0
exit 1
