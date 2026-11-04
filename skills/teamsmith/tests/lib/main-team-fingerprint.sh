#!/usr/bin/env bash
# main-team-fingerprint.sh — the isolation ledger for the real project's `.pi/team` (P406/P409,
# change: agent-self-reminder).
#
# A live team is running while a fixture runs: the patrol, dispatches and launch logs really do move.
# So the judgement is not "skip everything under state/" -- that is exactly the defect shape P171
# allowed -- but a **named volatile whitelist**: only the shapes named here may appear or change;
# every other path appearing, disappearing or changing is a violation, including any stray file under
# state/. The authority's own write surface is never volatile, and that rule is independent of the
# whitelist, so "add a name to the list" cannot hide an accident.
#
# One implementation, two fixtures (tests/state-authority.sh and tests/remind-cli.sh): the isolation
# proof must be the same judgement in both, not two copies that can drift.
#
#   main_team_snapshot <dir>              → "path<TAB>hash", sorted (absent dir = empty ledger)
#   main_team_volatile <./relpath>        → 0 = the shape is allowed to move
#   main_team_violations <before> <after> → one path per non-whitelisted change
#   main_team_volatile_changes <b> <a>    → count of whitelisted changes (proves the check sees motion)
#
# MAIN_TEAM_BREAK=skip-state is the fixtures' own red side: it restores the old "skip state/" shape so
# a stray file there stops being reported. Product code never reads it.

main_team_authority_surface() { # <relative path, starting with ./ >
  case "$1" in
    ./reminder-locator*|./state/reminders|./state/reminders/*|./state/standby|./state/standby.*) return 0 ;;
  esac
  return 1
}

# The live team's runtime writers, named by shape. Two stages on purpose: directly under the state root
# a file name is matched by suffix/prefix; subdirectories are only the known ones (bash `case` lets `*`
# cross `/`, so a subdirectory needs its own branch and cannot be covered by `./state/*.log`).
main_team_volatile() { # <relative path, starting with ./ >
  local p="$1" rest dir base
  main_team_authority_surface "$p" && return 1
  case "$p" in
    ./state/*)
      rest="${p#./state/}"
      case "$rest" in
        */*)
          dir="${rest%%/*}"
          case "$dir" in
            # meta-suite: tests/meta-suite.sh writes one run record per run into
            # <project root>/.pi/team/state/meta-suite/ -- and the project root is the main checkout
            # (taken from git-common-dir), so a run started from a worktree still lands there. The
            # content is a run record, not product state: the same class as bg/*.log. Volatile
            # because every run adds a new file (P411).
            meta-suite) return 0 ;;
            bg|inbox-watch|outbox|spool|draft|key-replies) return 0 ;;
            release-*|product-field-trial) return 0 ;;
          esac
          return 1 ;;
      esac
      base="$rest"
      case "$base" in
        *.log|*.log.[0-9]*|*.last|*.nudge|*.tick|*.pid*) return 0 ;;
        *.spawn|*.exit|*-tail.txt|*.tmp|*.attempts.*|*.pending|*.inbox|*.lock|*.conf) return 0 ;;
        *.env|*.env.bak-*) return 0 ;;
        inbox-*|pm-*|pm.*|dispatch-*|draft-*|held) return 0 ;;
        notify*|nudge*|watchdog*|capacity*|digest-*|deaths.*|bg.log|panel*) return 0 ;;
        changes.json|refs|pane|_watch.*|reload-requested|interrupt.*|update-check.*|config.*) return 0 ;;
        summary-*|prompt-*|pm-loaded.*|pm-launch*) return 0 ;;
      esac
      return 1 ;;
  esac
  return 1
}

main_team_snapshot() { # <dir> → "path<TAB>hash", sorted by path (absent directory = empty ledger)
  [ -d "$1" ] || return 0
  ( cd "$1" && find . -type f -print0 | sort -z | xargs -0 -r sha256sum 2>/dev/null ) |
    awk '{ h = $1; $1 = ""; sub(/^ /, ""); print $0 "\t" h }' | sort -t "$(printf '\t')" -k1,1
}

main_team_violations() { # <before> <after> → one line per non-whitelisted change
  local before="$1" after="$2" path b a
  join -t "$(printf '\t')" -a1 -a2 -e MISSING -o '0,1.2,2.2' "$before" "$after" |
    while IFS="$(printf '\t')" read -r path b a; do
      [ "$b" = "$a" ] && continue
      if [ "${MAIN_TEAM_BREAK:-}" = "skip-state" ]; then
        case "$path" in ./state/*) continue ;; esac
      fi
      main_team_volatile "$path" && continue
      printf '%s\n' "$path"
    done
}

main_team_volatile_changes() { # <before> <after> → number of whitelisted paths that changed
  local before="$1" after="$2" path b a n=0
  while IFS="$(printf '\t')" read -r path b a; do
    [ "$b" = "$a" ] && continue
    main_team_volatile "$path" && n=$((n + 1))
  done < <(join -t "$(printf '\t')" -a1 -a2 -e MISSING -o '0,1.2,2.2' "$before" "$after")
  printf '%s\n' "$n"
}

# The proof target is this project's **main checkout**, never this worktree: the fixture runs from a
# worktree while the authority must never land in the main checkout.
main_team_project_root() { # <skill-dir> → the main checkout (empty when this checkout has none)
  local root
  root="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname)"
  [ -n "${root:-}" ] && [ -d "$root" ] || return 0
  printf '%s\n' "$root"
}
