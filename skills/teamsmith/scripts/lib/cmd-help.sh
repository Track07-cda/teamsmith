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

# The closed placeholder set: interpolation into the prose goes through these and nothing else.
# Every member has a substitution site in this file — {project} and {meeting_ttl} in team_help_subst,
# {token}/{sub}/{cmd} in team_help_refuse and in the alias line, {undo_cmd} in team_help_undo_text.
# `{effect}` and `{faces}` are deliberately NOT here: the claim sentence is composed in bash
# (team_help_effect_text + team_help_face_list), no code path substitutes them, and declaring a
# placeholder nothing resolves would let a value print it literally and still pass the check below.
# A `{…}` token outside this set would be printed literally, so a table carrying one is a defect
# rather than a rendering — and the set must not drift the other way either: a placeholder no table
# mentions is a claim the surface does not keep. Both directions are checked in team_help_load.
TEAM_HELP_PLACEHOLDERS="{project} {meeting_ttl} {token} {sub} {cmd} {undo_cmd}"

# ---------------------------------------------------------------- display width
# Locale-independent by construction: one read pinned to LC_ALL=C gives the raw bytes, and the
# UTF-8 decoding plus the 0/1/2-cell decision are integer arithmetic on code points. Nothing here
# may consult the caller's locale: the previous brace ranges written as $'\uXXXX' degraded to
# literal bytes outside a UTF-8 locale (they swallowed ASCII) and ${s:i:1} sliced bytes, so one CJK
# character counted three cells, a page wrapped differently, and a page could be cut in the middle
# of a character (the zh surface printed invalid UTF-8 under LC_ALL=C).
#
# Cost note: the wrap used to fork once per word (a subshell for the cell count, plus the counter
# itself), which made a single page cost seconds. Both walks below take the bytes once and stay in
# the shell, so a page's wrapping costs one walk per block instead of one subprocess per word.
team_help_byte_values() { # <text> → space-separated byte values (one locale-pinned read)
  LC_ALL=C printf '%s' "$1" | LC_ALL=C od -An -tu1 -v | tr -s ' \n' ' '
}

team_help_byte_len() { # <text> → its length in bytes
  local LC_ALL=C
  printf '%s' "${#1}"
}

team_help_slice_bytes() { # <text> <byte-offset> <byte-count> → those bytes
  local LC_ALL=C
  printf '%s' "${1:$2:$3}"
}

# team_help_cp_cells <code point> → sets _TH_CELLS to 0, 1 or 2. A setter, not a printer: this is
# the hot loop and a subshell per code point is exactly the cost that has to stay out of it.
_TH_CELLS=1
team_help_cp_cells() {
  local cp="$1" r
  case "$cp" in ''|*[!0-9]*) _TH_CELLS=1; return 0 ;; esac
  for r in 768-879 1155-1161 4448-4607 8203-8207 65024-65039; do
    if [ "$cp" -ge "${r%-*}" ] && [ "$cp" -le "${r#*-}" ]; then _TH_CELLS=0; return 0; fi
  done
  for r in 4352-4447 11904-12350 12353-13311 13312-19903 19968-40959 40960-42191 \
           44032-55203 63744-64255 65072-65103 65280-65312 65504-65510 \
           127744-128591 129280-129535 131072-262141; do
    if [ "$cp" -ge "${r%-*}" ] && [ "$cp" -le "${r#*-}" ]; then _TH_CELLS=2; return 0; fi
  done
  _TH_CELLS=1
}

team_help_char_width() { # <one code point> → 0, 1 or 2 display cells
  team_help_cp_cells "$1"
  printf '%s' "$_TH_CELLS"
}

# team_help_decode <b1> <b2> <b3> <b4> → sets _TH_CP and _TH_STEP (1..4) for one code point.
# A malformed byte is its own code point and counts one cell, so a broken table can never make the
# counter lose bytes.
_TH_CP=0; _TH_STEP=1
team_help_decode() {
  local b1="$1" b2="$2" b3="$3" b4="$4"
  _TH_CP="$b1"; _TH_STEP=1
  if [ "$b1" -ge 194 ] && [ "$b1" -le 223 ] && [ "$b2" -ge 128 ] && [ "$b2" -le 191 ]; then
    _TH_CP=$((((b1 & 31) << 6) | (b2 & 63))); _TH_STEP=2
  elif [ "$b1" -ge 224 ] && [ "$b1" -le 239 ] && [ "$b2" -ge 128 ] && [ "$b2" -le 191 ] \
    && [ "$b3" -ge 128 ] && [ "$b3" -le 191 ]; then
    _TH_CP=$((((b1 & 15) << 12) | ((b2 & 63) << 6) | (b3 & 63))); _TH_STEP=3
  elif [ "$b1" -ge 240 ] && [ "$b1" -le 244 ] && [ "$b2" -ge 128 ] && [ "$b2" -le 191 ] \
    && [ "$b3" -ge 128 ] && [ "$b3" -le 191 ] && [ "$b4" -ge 128 ] && [ "$b4" -le 191 ]; then
    _TH_CP=$((((b1 & 7) << 18) | ((b2 & 63) << 12) | ((b3 & 63) << 6) | (b4 & 63))); _TH_STEP=4
  fi
}

# team_help_cps <text> → one line per code point: "<byte-offset> <cells>"
team_help_cps() {
  local i=0 n
  local -a b=()
  read -r -a b <<< "$(team_help_byte_values "$1")"
  n=${#b[@]}
  while [ "$i" -lt "$n" ]; do
    team_help_decode "${b[$i]}" "${b[$((i + 1))]:-0}" "${b[$((i + 2))]:-0}" "${b[$((i + 3))]:-0}"
    team_help_cp_cells "$_TH_CP"
    printf '%s %s\n' "$i" "$_TH_CELLS"
    i=$((i + _TH_STEP))
  done
}

# team_help_words <text> → one line per whitespace-separated word: "<byte-offset> <byte-count>
# <cells> <word>". The split is the one `read -r -a` does (space, tab and newline), and the word
# travels with its own bytes so the caller needs no second pass.
team_help_words() {
  local LC_ALL=C    # the slices below are byte slices, so the word keeps its own bytes
  local i=0 n cells=0 wstart=-1
  local -a b=()
  read -r -a b <<< "$(team_help_byte_values "$1")"
  n=${#b[@]}
  while [ "$i" -lt "$n" ]; do
    team_help_decode "${b[$i]}" "${b[$((i + 1))]:-0}" "${b[$((i + 2))]:-0}" "${b[$((i + 3))]:-0}"
    if [ "$_TH_CP" = 32 ] || [ "$_TH_CP" = 9 ] || [ "$_TH_CP" = 10 ]; then
      if [ "$wstart" -ge 0 ]; then
        printf '%s %s %s %s\n' "$wstart" "$((i - wstart))" "$cells" "${1:$wstart:$((i - wstart))}"
        wstart=-1; cells=0
      fi
    else
      team_help_cp_cells "$_TH_CP"
      [ "$wstart" -ge 0 ] || { wstart=$i; cells=0; }
      cells=$((cells + _TH_CELLS))
    fi
    i=$((i + _TH_STEP))
  done
  if [ "$wstart" -ge 0 ]; then
    printf '%s %s %s %s\n' "$wstart" "$((n - wstart))" "$cells" "${1:$wstart:$((n - wstart))}"
  fi
}

team_help_cells() { # <text> → display cells (a CJK-wide character counts two)
  local off cells total=0
  while read -r off cells; do total=$((total + cells)); done < <(team_help_cps "$1")
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

# team_help_tokens_of <file> <kind> <label> → "<line>\t<source>\t<token>" for every `{…}` token in
# the file. The tables are read whole: a token in a value is what could be printed literally, and a
# token in the file's own header is the declaration that file makes about the set it may use — both
# are the table's text, and the two directions below are judged over the same text.
team_help_tokens_of() {
  awk -F'\t' -v kind="$2" -v label="$3" '
    NF == 0 { next }
    {
      comment = ($0 ~ /^#/)
      for (i = 1; i <= NF; i++) {
        f = $i
        while (match(f, /\{[^{}]*\}/)) {
          tok = substr(f, RSTART, RLENGTH)
          if (comment) {
            printf "%d\t%s header comment\t%s\n", NR, label, tok
          } else if (kind == "manifest") {
            name = (i == 2) ? "name" : (i == 3) ? "group" : (i == 4) ? "usage" : (i == 5) ? "flags" \
                 : (i == 6) ? "subs" : (i == 7) ? "aliases" : (i == 8) ? "terms" : (i == 9) ? "faces" \
                 : (i == 10) ? "effect" : (i == 11) ? "auth" : (i == 12) ? "undo" : (i == 13) ? "claims" \
                 : (i == 14) ? "probe" : (i == 15) ? "example" : ("col" i)
            printf "%d\t%s %s %s\t%s\n", NR, label, name, $2, tok
          } else {
            printf "%d\t%s %s\t%s\n", NR, label, $1, tok
          }
          f = substr(f, RSTART + RLENGTH)
        }
      }
    }
  ' "$1"
}

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
  # G4 · the declared set and the tokens in the tree must be equal in both directions
  local _line _src _tok _bad=0 _p
  local -A _seen=()
  while IFS=$'\t' read -r _line _src _tok; do
    [ -n "$_tok" ] || continue
    _seen["$_tok"]=1
    case " $TEAM_HELP_PLACEHOLDERS " in
      *" $_tok "*) ;;
      *) printf 'teamsmith: the help tables carry an undeclared placeholder %s (%s, line %s)\n' \
           "$_tok" "$_src" "$_line" >&2
         _bad=1 ;;
    esac
  done < <( { team_help_tokens_of "$dir/commands.tsv" manifest commands.tsv
             team_help_tokens_of "$dir/help.en.tsv" prose help.en.tsv
             team_help_tokens_of "$dir/help.zh.tsv" prose help.zh.tsv; } )
  for _p in $TEAM_HELP_PLACEHOLDERS; do
    [ -n "${_seen[$_p]+x}" ] || {
      printf 'teamsmith: the declared placeholder %s appears in none of the help tables\n' "$_p" >&2
      _bad=1
    }
  done
  [ "$_bad" = "0" ] || return 1
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
  local text="$*" line cells off len cw wrd
  line=""; cells=0
  while read -r off len cw wrd; do
    [ -n "$wrd" ] || continue
    if [ -n "$line" ] && [ $((cells + 1 + cw)) -le "$avail" ]; then
      line="$line $wrd"; cells=$((cells + 1 + cw)); continue
    fi
    if [ -n "$line" ]; then printf '%s\n' "$line"; line=""; cells=0; avail="$next"; fi
    if [ "$cw" -le "$avail" ]; then line="$wrd"; cells=$cw; continue; fi
    # a word longer than the line (CJK prose has no spaces): break it at code-point boundaries
    local soff scw seg=0 chunkc=0
    while read -r soff scw; do
      if [ $((chunkc + scw)) -gt "$avail" ] && [ "$soff" -gt "$seg" ]; then
        printf '%s\n' "$(team_help_slice_bytes "$wrd" "$seg" "$((soff - seg))")"
        avail="$next"; seg="$soff"; chunkc=0
      fi
      chunkc=$((chunkc + scw))
    done < <(team_help_cps "$wrd")
    line="$(team_help_slice_bytes "$wrd" "$seg" "$(( $(team_help_byte_len "$wrd") - seg ))")"
    cells="$chunkc"
  done < <(team_help_words "$text")
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
  team_help_flow 0 0 "teamsmith · $title — $purpose"
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
  team_help_flow 0 0 "teamsmith · $name — $title"
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
