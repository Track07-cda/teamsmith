#!/usr/bin/env bash
# teamsmith · the help surface (change: cli-help · help-surface#The help surface is a level-0 menu…)
#
# One renderer for three levels: the level-0 menu, a group page (level 1) and a command page
# (level 2). Everything it prints comes from the command manifest (scripts/strings/commands.tsv) and
# the two parallel prose tables (scripts/strings/help.<lang>.tsv) — there is no second source.
#
#   team_help_route <explicit-help> [argv…]   the routing `scripts/team` calls before the contract is read
#   team_help_menu                            level 0: what teamsmith is, the groups, a beginner set
#   team_help_group_page <id>                  level 1: one group's commands
#   team_help_command_page <name> [<asked>]    level 2: one command's own page
#
# Layout: a fixed ladder, enforced here and checked by tests/help-surface.sh —
#   0    headers (`── <title> ──…`) and the lead lines of a fragment
#   2    a command usage line (an entry)
#   4    a wrapped usage continuation
#   6    a command's description block (hanging: every line in the column of the first)
#   10   an argument's flag column, an example block
#   32   an argument's description column (the only level deeper than ten; continuations align here)
#   14   a concept name
#   28   a concept's definition column
# Wrapping is done here, never by hand; a continuation is never shallower than the line it continues.
# Width: 100 display cells (a CJK-wide character counts two); TEAM_HELP_WIDTH overrides it, and an
# invalid value prints one warning and falls back. Both knobs are read from the environment only —
# the help paths never load the project contract, so they work in a directory that is not a project.

TEAM_HELP_DEFAULT_WIDTH=100
TEAM_HELP_ARG_COL=32
TEAM_HELP_TERM_COL=28
# The condition token a `needs-yes:<condition>` authorization may carry (closed set).
TEAM_HELP_AUTH_CONDITIONS="TEAM_CONFIRM_WRITES"

# ---------------------------------------------------------------- display width
# Decodes UTF-8 by hand: the tables carry CJK, and awk's byte classes cannot count cells.
team_help_char_width() { # <one character> → 0, 1 or 2 display cells
  case "$1" in
    [$'\u0300'-$'\u036f']|[$'\u0483'-$'\u0489']|[$'\u1160'-$'\u11ff']|[$'\u200b'-$'\u200f']|[$'\ufe00'-$'\ufe0f']) printf 0 ;;
    [$'\u1100'-$'\u115f']|[$'\u2e80'-$'\u303e']|[$'\u3041'-$'\u33ff']|[$'\u3400'-$'\u4dbf']|[$'\u4e00'-$'\u9fff'] \
      |[$'\ua000'-$'\ua4cf']|[$'\uac00'-$'\ud7a3']|[$'\uf900'-$'\ufaff']|[$'\ufe30'-$'\ufe6f']|[$'\uff00'-$'\uff60'] \
      |[$'\uffe0'-$'\uffe6']|[$'\U0001f300'-$'\U0001f64f']|[$'\U0001f900'-$'\U0001f9ff'] \
      |[$'\U00020000'-$'\U0003fffd']) printf 2 ;;
    *) printf 1 ;;
  esac
}

team_help_cells() { # <text> → display cells (a CJK-wide character counts two)
  local s="$1" i=0 n=${#1} total=0
  while [ "$i" -lt "$n" ]; do
    total=$((total + $(team_help_char_width "${s:i:1}")))
    i=$((i + 1))
  done
  printf '%s\n' "$total"
}

# ---------------------------------------------------------------- knobs (environment only)
team_help_lang() {
  case "${TEAM_LANG:-}" in
    ''|en|EN|en_US|en-US) printf 'en\n' ;;
    zh|ZH|zh_CN|zh-CN|zh_TW|zh-Hans|zh-Hant) printf 'zh\n' ;;
    *) printf 'en\n' ;;
  esac
}

team_help_width() {
  case "${TEAM_HELP_WIDTH:-}" in
    ''|0|*[!0-9]*) printf '%s\n' "$TEAM_HELP_DEFAULT_WIDTH" ;;
    *) printf '%s\n' "$TEAM_HELP_WIDTH" ;;
  esac
}

# One visible warning line per invalid knob; the help path's status is unchanged.
team_help_warn_knobs() {
  case "${TEAM_LANG:-}" in
    ''|en|EN|en_US|en-US|zh|ZH|zh_CN|zh-CN|zh_TW|zh-Hans|zh-Hant) ;;
    *) printf 'teamsmith: TEAM_LANG=%s is not a known language (en, zh); printing English\n' "$TEAM_LANG" >&2 ;;
  esac
  case "${TEAM_HELP_WIDTH:-}" in
    '') ;;
    0|*[!0-9]*) printf 'teamsmith: TEAM_HELP_WIDTH=%s is not a positive integer; using %s\n' \
      "$TEAM_HELP_WIDTH" "$TEAM_HELP_DEFAULT_WIDTH" >&2 ;;
  esac
}

# ---------------------------------------------------------------- manifest + prose tables (load once)
declare -a _TH_NAMES=() _TH_GROUP=() _TH_USAGE=() _TH_FLAGS=() _TH_SUBS=() _TH_ALIASES=() \
  _TH_TERMS=() _TH_FACES=() _TH_EFFECT=() _TH_AUTH=() _TH_UNDO=() _TH_CLAIMS=() _TH_PROBE=() _TH_EXAMPLE=()
declare -a _TH_GROUPS=() _TH_BEGIN=()
declare -A _TH_IDX=() _TH_EN=() _TH_ZH=()
_TH_LOADED=0

team_help_load() {
  [ "${_TH_LOADED:-0}" = "1" ] && return 0
  local dir file line i=0
  local -a col=()
  dir="$TEAM_SKILL_DIR/scripts/strings"
  file="$dir/commands.tsv"
  if [ ! -f "$file" ]; then
    printf 'teamsmith: the help surface is missing its manifest: %s\n' "$file" >&2
    return 1
  fi
  while IFS= read -r line; do
    case "$line" in ''|'#'*) continue ;; esac
    IFS=$'\t' read -r -a col <<< "$line"
    case "${col[0]}" in
      group) _TH_GROUPS+=("${col[1]}") ;;
      begin) _TH_BEGIN=("${col[@]:1}") ;;
      cmd)
        _TH_NAMES+=("${col[1]}"); _TH_GROUP+=("${col[2]}"); _TH_USAGE+=("${col[3]}")
        _TH_FLAGS+=("${col[4]}"); _TH_SUBS+=("${col[5]}"); _TH_ALIASES+=("${col[6]}")
        _TH_TERMS+=("${col[7]}"); _TH_FACES+=("${col[8]}"); _TH_EFFECT+=("${col[9]}")
        _TH_AUTH+=("${col[10]}"); _TH_UNDO+=("${col[11]}"); _TH_CLAIMS+=("${col[12]}")
        _TH_PROBE+=("${col[13]}"); _TH_EXAMPLE+=("${col[14]}")
        _TH_IDX["${col[1]}"]=$i
        i=$((i + 1)) ;;
    esac
  done < "$file"
  local lang
  for lang in en zh; do
    file="$dir/help.$lang.tsv"
    [ -f "$file" ] || continue
    while IFS=$'\t' read -r line; do
      case "$line" in ''|'#'*) continue ;; esac
      local key="${line%%$'\t'*}" val="${line#*$'\t'}"
      if [ "$lang" = "en" ]; then _TH_EN["$key"]="$val"; else _TH_ZH["$key"]="$val"; fi
    done < "$file"
  done
  _TH_LOADED=1
  return 0
}

team_help_cmd_i() { # <name> → manifest index
  team_help_load || return 1
  [ -n "${_TH_IDX[$1]+x}" ] || return 1
  printf '%s\n' "${_TH_IDX[$1]}"
}

team_help_primary() { # <token> → the primary name when <token> is an alias
  team_help_load || return 1
  local i a
  for i in "${!_TH_NAMES[@]}"; do
    for a in ${_TH_ALIASES[$i]}; do
      [ "$a" = "$1" ] && { printf '%s\n' "${_TH_NAMES[$i]}"; return 0; }
    done
  done
  return 1
}

team_help_group_exists() {
  team_help_load || return 1
  local g
  for g in "${_TH_GROUPS[@]}"; do [ "$g" = "$1" ] && return 0; done
  return 1
}

team_help_sub_known() { # <cmd> <sub>
  team_help_load || return 1
  local i
  i="$(team_help_cmd_i "$1")" || return 1
  local s
  for s in ${_TH_SUBS[$i]}; do [ "$s" = "$2" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------- prose lookup (missing key visible)
# A key the selected table lacks prints one marker that carries the key id, and the other table's
# value when it has one; an empty value is never printed.
team_help_marker() { printf '«missing key: %s»' "$1"; }

# team_help_have <lang> <key> → "x" when that table carries a non-empty value for the key
team_help_have() {
  local lang="$1" key="$2" v
  if [ "$lang" = "zh" ]; then v="${_TH_ZH[$key]:-}"; else v="${_TH_EN[$key]:-}"; fi
  [ -n "$v" ] && printf 'x'
  return 0
}

team_help_raw() { # <lang> <key> → that table's value (may be empty)
  if [ "$1" = "zh" ]; then printf '%s' "${_TH_ZH[$2]:-}"; else printf '%s' "${_TH_EN[$2]:-}"; fi
}

team_help_txt() { # <key>
  team_help_load || return 1
  local key="$1" lang other
  lang="$(team_help_lang)"
  if [ "$lang" = "zh" ]; then other=en; else other=zh; fi
  if [ -n "$(team_help_have "$lang" "$key")" ]; then
    team_help_raw "$lang" "$key"
    return 0
  fi
  printf '%s' "$(team_help_marker "$key")"
  if [ -n "$(team_help_have "$other" "$key")" ]; then
    printf ' %s' "$(team_help_raw "$other" "$key")"
  fi
  return 0
}

# team_help_subst <text> → declared placeholders resolved ({project} {meeting_ttl} are the prose
# ones; {effect} {faces} {undo_cmd} belong to the claim sentences and are substituted by their caller).
team_help_subst() {
  local s="$1"
  s="${s//\{project\}/${TEAM_PROJECT:-}}"
  s="${s//\{meeting_ttl\}/$(team_meeting_ttl_default 2>/dev/null || printf 72)}"
  printf '%s' "$s"
}

# ---------------------------------------------------------------- flow (the only place that wraps)
team_help_puts() { # <indent> <text…> — one already-built line
  local ind="$1"; shift
  [ $# -gt 0 ] || return 0
  printf '%*s%s\n' "$ind" '' "$*"
}

# team_help_wrap <first-avail> <cont-avail> <text…> — prints bare wrapped lines (no indent)
team_help_wrap() {
  local avail="$1" next="$2"; shift 2
  [ $# -gt 0 ] || return 0
  local text="$*" line cells cw wrd
  local -a words=()
  read -r -a words <<< "$text"
  line=""; cells=0
  for wrd in "${words[@]}"; do
    [ -n "$wrd" ] || continue
    cw="$(team_help_cells "$wrd")"
    if [ -n "$line" ] && [ $((cells + 1 + cw)) -le "$avail" ]; then
      line="$line $wrd"; cells=$((cells + 1 + cw)); continue
    fi
    if [ -n "$line" ]; then printf '%s\n' "$line"; line=""; cells=0; avail="$next"; fi
    if [ "$cw" -le "$avail" ]; then line="$wrd"; cells=$cw; continue; fi
    # a word longer than the line (CJK prose has no spaces): break it at character boundaries
    local chunk="" chunkc=0 k=0 ln=${#wrd} ch chw
    while [ "$k" -lt "$ln" ]; do
      ch="${wrd:k:1}"; k=$((k + 1))
      chw="$(team_help_char_width "$ch")"
      if [ $((chunkc + chw)) -gt "$avail" ] && [ -n "$chunk" ]; then
        printf '%s\n' "$chunk"; avail="$next"; chunk=""; chunkc=0
      fi
      chunk="$chunk$ch"; chunkc=$((chunkc + chw))
    done
    line="$chunk"; cells="$chunkc"
  done
  [ -n "$line" ] && printf '%s\n' "$line"
  return 0
}

# team_help_flow <first-indent> <hang-indent> <text…> — a hanging block
team_help_flow() {
  local find="$1" hind="$2"; shift 2
  local w; w="$(team_help_width)"
  local line first=1
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then team_help_puts "$find" "$line"; first=0
    else team_help_puts "$hind" "$line"; fi
  done < <(team_help_wrap $((w - find)) $((w - hind)) "$@")
  return 0
}

# team_help_item <label> <label-indent> <text-col> <text…> — an argument or a concept entry:
# the label sits at its own column, the text at the (deeper) text column, continuations align there.
team_help_item() {
  local label="$1" lind="$2" col="$3"; shift 3
  local w pad line first=1
  w="$(team_help_width)"
  pad=$((col - lind - $(team_help_cells "$label")))
  if [ "$pad" -lt 2 ]; then
    # the label is as wide as the description column (e.g. --allow-unresolved-branch): the text
    # starts on the next line at the description column instead of running on from the label
    printf '%*s%s\n' "$lind" '' "$label"
    team_help_flow "$col" "$col" "$@"
    return 0
  fi
  printf -v pad '%*s' "$pad" ''
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then
      printf '%*s%s%s%s\n' "$lind" '' "$label" "$pad" "$line"; first=0
    else
      team_help_puts "$col" "$line"
    fi
  done < <(team_help_wrap $((w - col)) $((w - col)) "$@")
  return 0
}

team_help_rule() { # <title> — a column-0 section header, padded to the width
  local title="$1" w bar pad
  w="$(team_help_width)"
  pad=$((w - 4 - $(team_help_cells "$title")))
  [ "$pad" -lt 2 ] && pad=2
  printf -v bar '%*s' "$pad" ''
  printf '%s%s\n' "── $title " "${bar// /─}"
}

team_help_blank() { printf '\n'; }

# ---------------------------------------------------------------- derived claim sentences
team_help_face_list() { # <faces>
  local f out=""
  for f in $1; do
    [ -n "$out" ] && out="$out$(team_help_txt claim.list-sep)"
    out="$out$(team_help_txt "face.$f")"
  done
  printf '%s' "$out"
}

team_help_effect_text() { # <effect> <faces>
  local eff="$1" faces="$2" out
  case "$eff" in
    read-only) out="$(team_help_txt claim.effect.read-only)" ;;
    starts-process)
      out="$(team_help_txt claim.effect.starts-process)"
      [ -n "$faces" ] && out="$out$(team_help_txt claim.extra-sep)$(team_help_txt claim.effect.and-writes)$(team_help_face_list "$faces")" ;;
    writes-*)
      out="$(team_help_txt claim.effect.writes)$(team_help_face_list "$faces")" ;;
    *) out="$(team_help_marker "claim.effect.$eff")" ;;
  esac
  printf '%s' "$out"
}

team_help_auth_text() { # <auth>
  local auth="$1" out
  case "$auth" in
    none) out="$(team_help_txt claim.auth.none)" ;;
    needs-yes) out="$(team_help_txt claim.auth.needs-yes)" ;;
    needs-yes:*)
      out="$(team_help_txt claim.auth.needs-yes) $(team_help_txt claim.auth.when) ${auth#needs-yes:}" ;;
    *) out="$(team_help_marker "claim.auth.$auth")" ;;
  esac
  printf '%s' "$out"
}

team_help_undo_text() { # <undo>
  local undo="$1" out cmd
  case "$undo" in
    idempotent) out="$(team_help_txt claim.undo.idempotent)" ;;
    undo-by-*) cmd="${undo#undo-by-}"; out="$(team_help_txt claim.undo.undo-by)"; out="${out//\{undo_cmd\}/$cmd}" ;;
    not-reversible:*) out="$(team_help_txt claim.undo.not-reversible)" ;;
    *) out="$(team_help_marker "claim.undo.$undo")" ;;
  esac
  printf '%s' "$out"
}

# ---------------------------------------------------------------- level 0 (the menu)
team_help_menu() {
  team_help_load || return 1
  local w; w="$(team_help_width)"
  team_help_flow 0 0 "$(team_help_subst "$(team_help_txt menu.lead)")"
  team_help_blank
  team_help_puts 0 "$(team_help_txt menu.groups)"
  local g
  for g in "${_TH_GROUPS[@]}"; do
    local title purpose cells pad line
    title="$(team_help_txt "group.$g.title")"
    purpose="$(team_help_subst "$(team_help_txt "group.$g.purpose")")"
    cells="$(team_help_cells "$g")"
    pad=$((12 - 2 - cells)); [ "$pad" -lt 1 ] && pad=1
    printf -v pad '%*s' "$pad" ''
    line="$g$pad$purpose"
    if [ "$(team_help_cells "  $line")" -le "$(team_help_width)" ]; then
      team_help_puts 2 "$line"
    else
      team_help_flow 2 6 "$g — $purpose"
    fi
  done
  team_help_blank
  team_help_rule "$(team_help_txt part.start.title)"
  local name i
  for name in "${_TH_BEGIN[@]}"; do
    i="$(team_help_cmd_i "$name")" || continue
    local frag; frag="${_TH_USAGE[$i]%% ;; *}"
    team_help_flow 2 4 "$(team_help_subst "$frag")"
    team_help_flow 6 6 "$(team_help_subst "$(team_help_txt "cmd.$name.title")")"
  done
  team_help_blank
  team_help_flow 0 0 "$(team_help_subst "$(team_help_txt menu.deeper)")"
  return 0
}

# ---------------------------------------------------------------- level 1 (a group page)
team_help_group_page() { # <group id>
  team_help_load || return 1
  local g="$1" title purpose
  title="$(team_help_txt "group.$g.title")"
  purpose="$(team_help_subst "$(team_help_txt "group.$g.purpose")")"
  printf 'teamsmith · %s — %s\n' "$title" "$purpose"
  team_help_blank
  team_help_rule "$title"
  local i name
  for i in "${!_TH_NAMES[@]}"; do
    [ "${_TH_GROUP[$i]}" = "$g" ] || continue
    name="${_TH_NAMES[$i]}"
    team_help_flow 2 4 "$(team_help_subst "${_TH_USAGE[$i]%% ;; *}")"
    team_help_flow 6 6 "$(team_help_subst "$(team_help_txt "cmd.$name.what")")"
  done
  team_help_blank
  team_help_flow 0 0 "$(team_help_subst "$(team_help_txt menu.deeper)")"
  return 0
}

# ---------------------------------------------------------------- level 2 (a command page)
team_help_command_page() { # <name> [<asked token>]
  team_help_load || return 1
  local name="$1" asked="${2:-}" i
  i="$(team_help_cmd_i "$name")" || return 1
  local title; title="$(team_help_txt "cmd.$name.title")"
  printf 'teamsmith · %s — %s\n' "$name" "$title"
  team_help_blank
  team_help_rule "$(team_help_txt part.usage.title)"
  local plain="${_TH_USAGE[$i]// ;; /;;;}"
  local f
  while [ -n "$plain" ]; do
    if [ "${plain#*;;;}" != "$plain" ]; then f="${plain%%;;;*}"; plain="${plain#*;;;}"; else f="$plain"; plain=""; fi
    team_help_flow 2 4 "$(team_help_subst "$f")"
  done
  # the description block (hanging at column 6)
  local what when example read write see extra
  what="$(team_help_subst "$(team_help_txt "cmd.$name.what")")"
  when="$(team_help_subst "$(team_help_txt "cmd.$name.when")")"
  example="$(team_help_subst "$(team_help_txt "cmd.$name.example")")"
  read="$(team_help_subst "$(team_help_txt "cmd.$name.read")")"
  write="$(team_help_subst "$(team_help_txt "cmd.$name.write")")"
  see="$(team_help_subst "$(team_help_txt "cmd.$name.see")")"
  local sep; sep="$(team_help_txt part.sep)"
  team_help_flow 6 6 "$(team_help_txt part.what.title)$sep$what"
  team_help_flow 6 6 "$(team_help_txt part.when.title)$sep$when"
  local fl
  # a command with no flags prints no argument row: the `-` placeholder is a manifest column value,
  # never a flag name (printing it produced `«missing key: cmd.<name>.arg.-»` on 14 pages). The part
  # itself is never left empty: a flagless command says so.
  if [ "${_TH_FLAGS[$i]}" = "-" ] || [ -z "${_TH_FLAGS[$i]}" ]; then
    team_help_flow 6 6 "$(team_help_txt part.arguments.title)$sep$(team_help_txt part.arguments.none)"
  else
    team_help_flow 6 6 "$(team_help_txt part.arguments.title)$sep"
    for fl in ${_TH_FLAGS[$i]}; do
      [ "$fl" = "-" ] && continue
      team_help_item "$fl" 10 "$TEAM_HELP_ARG_COL" "$(team_help_subst "$(team_help_txt "cmd.$name.arg.$fl")")"
    done
  fi
  team_help_flow 6 6 "$(team_help_txt part.example.title)$sep"
  team_help_flow 10 10 "$example"
  team_help_flow 6 6 "$(team_help_txt part.read.title)$sep$read"
  team_help_flow 6 6 "$(team_help_txt part.write.title)$sep$write"
  local eff faces
  eff="${_TH_EFFECT[$i]}"; faces="${_TH_FACES[$i]}"
  [ "$faces" = "-" ] && faces=""
  extra="$(team_help_txt "cmd.$name.effect")"; extra="$(team_help_subst "$extra")"
  local line; line="$(team_help_effect_text "$eff" "$faces")"
  [ -n "$extra" ] && [ "$extra" != "$(team_help_marker "cmd.$name.effect")" ] && line="$line. $extra"
  team_help_flow 6 6 "$(team_help_txt part.side-effects.title)$sep$line"
  extra="$(team_help_txt "cmd.$name.auth")"; extra="$(team_help_subst "$extra")"
  line="$(team_help_auth_text "${_TH_AUTH[$i]}")"
  [ -n "$extra" ] && [ "$extra" != "$(team_help_marker "cmd.$name.auth")" ] && line="$line. $extra"
  team_help_flow 6 6 "$(team_help_txt part.authorization.title)$sep$line"
  extra="$(team_help_txt "cmd.$name.undo")"; extra="$(team_help_subst "$extra")"
  line="$(team_help_undo_text "${_TH_UNDO[$i]}")"
  [ -n "$extra" ] && [ "$extra" != "$(team_help_marker "cmd.$name.undo")" ] && line="$line. $extra"
  team_help_flow 6 6 "$(team_help_txt part.undo.title)$sep$line"
  local aliases="${_TH_ALIASES[$i]}"
  if [ "$aliases" != "-" ] && [ -n "$aliases" ]; then
    team_help_flow 6 6 "$(team_help_txt part.aliases.title)$sep$aliases — $(team_help_txt part.aliases.note)"
  fi
  if [ -n "$asked" ] && [ "$asked" != "$name" ]; then
    local al; al="$(team_help_txt part.aliases.alias)"; al="${al//\{cmd\}/$name}"
    team_help_flow 6 6 "$(team_help_txt part.aliases.title)$sep$asked — $al"
  fi
  local t
  if [ "${_TH_TERMS[$i]}" = "-" ] || [ -z "${_TH_TERMS[$i]}" ]; then
    team_help_flow 6 6 "$(team_help_txt part.concepts.title)$sep$(team_help_txt part.concepts.none)"
  else
    team_help_flow 6 6 "$(team_help_txt part.concepts.title)$sep"
    for t in ${_TH_TERMS[$i]}; do
      team_help_item "$t" 14 "$TEAM_HELP_TERM_COL" "$(team_help_subst "$(team_help_txt "term.$t.def")")"
    done
  fi
  team_help_flow 6 6 "$(team_help_txt part.see.title)$sep$see"
  team_help_blank
  team_help_flow 0 0 "$(team_help_subst "$(team_help_txt menu.deeper)")"
  return 0
}

# ---------------------------------------------------------------- refusals
team_help_refuse() { # <token> [<parent command>]
  local token="$1" parent="${2:-}" line
  if [ -n "$parent" ]; then
    line="$(team_help_txt refuse.sub)"; line="${line//\{sub\}/$token}"; line="${line//\{cmd\}/$parent}"
  else
    line="$(team_help_txt refuse.unknown)"; line="${line//\{token\}/$token}"
  fi
  printf 'teamsmith: %s\n' "$line" >&2
  printf 'teamsmith: %s\n' "$(team_help_subst "$(team_help_txt refuse.hint)")" >&2
  return 2
}

# ---------------------------------------------------------------- routing (before the contract)
# team_help_route <explicit-help 0|1> [argv…]
#   0: argv[0] is the literal `help`; the token after it selects a group or a command.
#   1: `-h`/`--help` appeared anywhere in the argv; argv is the command path asked about.
team_help_route() {
  team_help_warn_knobs
  team_help_load || return 1
  local explicit="$1"; shift
  local token="" primary="" cmd="" sub=""
  if [ "$explicit" = "1" ]; then
    case "$#" in
      0) team_help_menu; return 0 ;;
      1) token="$1"
         if primary="$(team_help_primary "$token")"; then team_help_command_page "$primary" "$token"; return 0; fi
         if team_help_cmd_i "$token" >/dev/null 2>&1; then team_help_command_page "$token"; return 0; fi
         team_help_refuse "$token"; return $? ;;
      *) cmd="$1"; sub="$2"
         if primary="$(team_help_primary "$cmd")"; then cmd="$primary"; fi
         if ! team_help_cmd_i "$cmd" >/dev/null 2>&1; then team_help_refuse "$cmd"; return $?; fi
         if team_help_sub_known "$cmd" "$sub"; then team_help_command_page "$cmd"; return 0; fi
         team_help_command_page "$cmd"
         team_help_refuse "$sub" "$cmd"; return $? ;;
    esac
  fi
  # `team help [<token>]`: drop the literal `help`
  shift || true
  case "$#" in
    0) team_help_menu; return 0 ;;
    *) local token="${1:-}" primary
       if team_help_group_exists "$token"; then team_help_group_page "$token"; return 0; fi
       if primary="$(team_help_primary "$token")"; then team_help_command_page "$primary" "$token"; return 0; fi
       if team_help_cmd_i "$token" >/dev/null 2>&1; then team_help_command_page "$token"; return 0; fi
       team_help_refuse "$token"; return $? ;;
  esac
}
