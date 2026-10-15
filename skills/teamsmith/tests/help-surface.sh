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
#   claims      the declared effect / authorization / reversibility values: closed vocabularies,
#               one probe per value, and each probe run against a real fixture asserting the effect
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
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
str="$skill/scripts/strings"
timeout_sec="${_timeout_arg:-60}"
case "$timeout_sec" in ''|*[!0-9]*) timeout_sec=60 ;; esac
keep="$_keep_arg"

# render mode: this file re-invokes itself to render one page in parallel with its siblings
if [ "${1:-}" = "--render-one" ]; then
  _lang="$2"; _spec="$3"; _dir="$4"
  _kind="${_spec%%:*}"; _label="${_spec#*:}"
  [ "$_label" = "-" ] && _label="menu"
  case "$_kind" in
    menu)    _argv=() ;;
    group)   _argv=(help "$_label") ;;
    command) _argv=(help "$_label") ;;
    *) exit 3 ;;
  esac
  _rtmp="${TMPDIR:-/tmp}/teamsmith-help-surface-render.$$"
  mkdir -p "$_rtmp" "$_dir"
  ( cd "$_rtmp" && TEAM_LANG="$_lang" bash "$team" "${_argv[@]}" ) > "$_dir/$_kind--$_label.txt" 2>/dev/null
  _rrc=$?
  rm -rf "$_rtmp"
  exit $_rrc
fi

SECTIONS=()
FLIP=0
for a in "$@"; do
  case "$a" in
    --all) SECTIONS=(coverage lang claims invariants route) ;;
    --flip) FLIP=1 ;;
    --select) : ;;
    --select=*) IFS=',' read -r -a SECTIONS <<< "${a#*=}" ;;
    -*) printf 'help-surface: 未知参数 %s\n' "$a" >&2; exit 2 ;;
    *) IFS=',' read -r -a SECTIONS <<< "$a" ;;
  esac
done
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(coverage lang claims invariants route)
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
tmp="${TMPDIR:-/tmp}/teamsmith-help-surface.$$"
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
  list-panes) printf '0\n'; exit 0 ;;
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
      { git -C "$d" worktree list --porcelain 2>/dev/null; git -C "$d" for-each-ref --format='%(refname)' refs/heads 2>/dev/null; } | sha256sum | cut -c1-16 ;;
    skills)   fp_dir "$d/.pi/skills" ;;
    meetings) fp_dir "${TEAM_MEETINGS_DIR:-$tmp/meetings}" ;;
    *) printf 'unknown\n' ;;
  esac
}
fp_all() { # <dir> → every face's fingerprint
  local f
  for f in state docs config worktree skills meetings; do printf '%s %s\n' "$f" "$(fp_face "$1" "$f")"; done
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
    proj|task|wt|live)
      env_run "$d" init --no-skills --session "$sess" --agents "dev verify" --vcs local --gates true \
        --docs docs/team --task-models 'code=provider/model-fast' --pm-model 'provider/model-strong' \
        --pm-window pm > "$tmp/logs/$sess-init.log" 2>&1 || {
        printf 'init failed for %s:\n%s\n' "$sess" "$(tail -3 "$tmp/logs/$sess-init.log")" >&2; return 1; }
      ;;
    *) printf 'unknown setup %s\n' "$id" >&2; return 1 ;;
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
render_pages() { # <lang>
  local lang="$1" dir jobs
  dir="$tmp/pages/$lang"; jobs="$tmp/jobs-$lang.txt"
  mkdir -p "$dir"; : > "$jobs"
  local g c
  if [ -n "${TEAM_HELP_SURFACE_ONLY:-}" ]; then
    for c in ${TEAM_HELP_SURFACE_ONLY}; do printf 'command\t%s\n' "$c" >> "$jobs"; done
  else
    printf 'menu\t-\n' >> "$jobs"
    for g in "${MG_GROUPS[@]}"; do printf 'group\t%s\n' "$g" >> "$jobs"; done
    for c in "${MG_ORDER[@]}"; do printf 'command\t%s\n' "$c" >> "$jobs"; done
  fi
  awk -F'\t' '{printf "%s:%s\n", $1, $2}' "$jobs" \
    | xargs -P 6 -I@ bash "$0" --render-one "$lang" @ "$dir" >/dev/null 2>&1
  while IFS=$'\t' read -r kind label; do
    [ "$label" = "-" ] && label=menu
    printf '%s\t%s\t%s\t%s/%s--%s.txt\n' "$kind" "$label" "$lang" "$dir" "$kind" "$label" >> "$pages_tsv"
  done < "$jobs"
}

# page_text <lang> <kind> <label> → the rendered page
page_text() { cat "$tmp/pages/$1/$2--$3.txt"; }

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
  return 0
}

# ---------------------------------------------------------------- language
check_lang() {
  section "lang · 默认英文、TEAM_LANG 的机制（切中文 / 非法值告警回退 / 缺键可见）、机器出口"
  local en zh
  en="$(page en help)"; zh="$(page zh help)"
  if printf '%s' "$en" | grep -q '[一-龥]'; then finding "缺省语言不是英文（菜单里有 CJK 字符）"; else ok "缺省语言是英文"; fi
  if printf '%s' "$zh" | grep -q '[一-龥]'; then ok "TEAM_LANG=zh 切到中文"; else finding "TEAM_LANG=zh 没有切到中文"; fi
  # the structure is byte-identical between the languages: the usage lines must be
  local same=1
  for c in "${MG_ORDER[@]}"; do
    diff -q <(page en help "$c" | grep -E '^  [^ ]') <(page zh help "$c" | grep -E '^  [^ ]') >/dev/null 2>&1 || {
      finding "命令 $c 的用法行在两种语言下不相同"; same=1; }
  done
  [ "$same" = "1" ] && ok "命令路径、旗标与用法片段在两种语言下逐字节相同"
  # invalid value: one warning naming it, English surface, status unchanged
  local warn out rc
  out="$( cd "$tmp" && TEAM_LANG=fr bash "$team" help 2>/tmp/hs-warn.txt )"; rc=$?
  warn="$(cat /tmp/hs-warn.txt)"
  if [ "$rc" = "0" ] && printf '%s' "$warn" | grep -q 'TEAM_LANG=fr' && [ "$(printf '%s\n' "$warn" | grep -c .)" = "1" ]; then
    ok "非法 TEAM_LANG 打印一行点名告警、状态不变（rc=0）"
  else
    finding "非法 TEAM_LANG 没有可见告警或状态变了（rc=$rc）：$warn"
  fi
  printf '%s' "$out" | grep -q '[一-龥]' && finding "非法 TEAM_LANG 没有回退英文"
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
    local rc_ny="$HS_RC" out_ny="$HS_OUT"
    case "$MG_AUTH[$cmd]" in needs-yes:*) ;; esac
    if [ "$rc_ny" != "0" ] && printf '%s' "$out_ny" | grep -q -- '--yes'; then
      after="$(fp_all "$d")"
      if [ "$before" = "$after" ]; then ok "claims: $cmd 没有 --yes 时拒绝、点名 --yes 且一个字不写"
      else finding "claims: $cmd 拒绝时仍然写了东西"; fi
    else
      finding "claims: $cmd 声明 needs-yes，但没有 --yes 时照旧执行（rc=$rc_ny）"
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
  # undo
  case "${MG_UNDO[$cmd]}" in
    idempotent)
      local mid; mid="$(fp_all "$d")"
      env_run "$d" $argv >/dev/null 2>&1
      local again; again="$(fp_all "$d")"
      [ "$mid" = "$again" ] && ok "claims: $cmd 幂等（第二次跑逐字节不变）" \
        || finding "claims: $cmd 声明幂等，但第二次跑改了状态" ;;
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
  section "claims · 封闭词表 + 逐命令探针（断言效应，不看退出码）"
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
  local out rc
  out="$(TEAM_HELP_SURFACE_TREE="$copy" TEAM_HELP_SURFACE_ONLY="$only" \
          bash "$0" --select "$sel" 2>&1)"; rc=$?
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
  rm -rf "$copy"
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

# flip_case <id> <label> <file-relative-to-the-copy> <python> <select> <expected> [only-command]
# One red side end to end: copy the tree, mutate (asserted), run the check, judge the finding.
flip_case() {
  local id="$1" label="$2" rel="$3" code="$4" sel="$5" expect="$6" only="${7:-}"
  [ -z "${TEAM_HELP_SURFACE_FLIP_ONLY:-}" ] || case " $TEAM_HELP_SURFACE_FLIP_ONLY " in
    *" $id "*) ;; *) return 0 ;; esac
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
    layout,coverage "missing key" 

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
if want scale;    then check_scale;    fi
if want coverage; then check_coverage; fi
if want layout;   then check_layout;   fi
if want lang;     then check_lang;     fi
if want claims;   then check_claims;   fi
if want invariants; then check_invariants; fi
if want route;    then check_route;    fi
if [ "$FLIP" = "1" ]; then do_flips; fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FIND" "$SKIP"
[ "$FIND" -eq 0 ] && exit 0
exit 1
