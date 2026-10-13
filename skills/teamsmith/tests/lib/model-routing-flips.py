#!/usr/bin/env python3
"""P228 scratch-only mutations; print exact byte hashes and require one target."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]).resolve()
name = sys.argv[2]
assert (root / '.routing-mutant').is_file(), 'not a marked owned scratch tree'
lib = root / 'skills/teamsmith/scripts/lib'
changes = []


def replace(path, old, new):
    text = path.read_text()
    assert text.count(old) == 1, (name, str(path), text.count(old))
    before = hashlib.sha256(text.encode()).hexdigest()
    text = text.replace(old, new)
    assert text.count(new) == 1
    path.write_text(text)
    after = hashlib.sha256(text.encode()).hexdigest()
    assert before != after
    changes.append(dict(file=str(path), matched=1, before=before, after=after))


def function(path, symbol, body):
    text = path.read_text()
    begin = text.index(symbol + '() {')
    line_end = text.index('\n', begin)
    end = line_end if text[begin:line_end].rstrip().endswith('}') else text.index('\n}', begin) + 2
    old = text[begin:end]
    replace(path, old, '# P228_FLIP_' + name + '\n' + symbol + '() {\n' + body + '\n}')


if name == 'unmapped-override':
    replace(lib / 'cmd-agents.sh',
            '  local policy_model; policy_model="$(team_task_policy_model "$category")" || { team_err "category 未映射：$category；config set-task-model $category <model>（override 仍须映射）"; return 1; }',
            '  # P228_FLIP_unmapped-override\n  local policy_model; policy_model="${override:-$(team_task_policy_model "$category" || true)}"')
elif name == 'required-categories':
    # F6 red side: restore the hardcoded analysis/verify requirement the contract forbids.
    replace(lib / 'common.sh',
            '  # 唯一非法的映射是**空映射**',
            '  for cat in analysis verify; do\n    case "$seen" in *" $cat "*) ;; *) printf \'required category missing: %s\\n\' "$cat"; return 1 ;; esac\n  done # P228_FLIP_required-categories\n  # 唯一非法的映射是**空映射**')
elif name == 'identity-overclaim':
    # R6/OBS1 red side: publish the complete identity no matter what the template delivered.
    function(lib / 'common.sh', 'team_launch_identity_fields', "  printf 'provider,model,session_id\\n'")
elif name == 'fingerprint':
    function(lib / 'cmd-config.sh', 'team_config_fingerprint', "  printf '%064d\\n' 0")
elif name == 'expanding-quote':
    replace(lib / 'cmd-bootstrap.sh', 'newline="${form}${k}=\'${quoted}\'${comment}"',
            'newline="${form}${k}=\\"${v}\\"${comment}" # P228_FLIP_expanding-quote')
    replace(lib / 'cmd-bootstrap.sh', 'newline="${form}${k}=\'${quoted}\'"',
            'newline="${form}${k}=\\"${v}\\"" # P228_FLIP_expanding-quote')
elif name == 'recovery-drift':
    replace(lib / 'cmd-agents.sh', 'TEAM_SELECTED_MODEL="$oldmodel"; TEAM_SELECTED_SID="$oldsid";',
            'TEAM_SELECTED_MODEL="$(team_task_policy_model "$category" || true)"; TEAM_SELECTED_SID="$TEAM_SESSION-$agent";')
elif name == 'partial-publication':
    replace(lib / 'cmd-agents.sh', '  TEAM_ASSIGN_TMP="$TEAM_STATE_DIR/.assignment-$seat-$nonce"',
            '  TEAM_ASSIGN_TMP="$TEAM_STATE_DIR/.assignment-$seat-$nonce"\n  printf "model=forbidden/partial\\n" > "$TEAM_STATE_DIR/$seat.env" # P228_FLIP_partial-publication')
elif name == 'unknown-as-zero':
    replace(lib / 'common.sh', '  running="$TEAM_MODEL_KNOWN_COUNT"; rule="$(team_model_limit_pattern_for "$model")"',
            '  running="$TEAM_MODEL_KNOWN_COUNT"; rule="$(team_model_limit_pattern_for "$model")"\n  TEAM_MODEL_UNKNOWN="" # P228_FLIP_unknown-as-zero')
elif name == 'latest-shell':
    function(lib / 'common.sh', 'team_session_file',
             '  local d; d="$(team_pi_session_dir "$2")"\n  find "$d" -maxdepth 1 -type f -name "*.jsonl" -print 2>/dev/null | sort | tail -1')
elif name == 'latest-monitor':
    replace(root / 'skills/teamsmith/scripts/monitor.mjs', '(!match || f.endsWith(match))', 'true /* P228_FLIP_latest-monitor */')
elif name == 'pm-fallback':
    function(lib / 'common.sh', 'team_pm_model_resolve', "  printf '%s\\n' vendor/routine")
elif name == 'pm-publication':
    function(lib / 'common.sh', 'team_pm_abort_uncommitted', '  return 0 # leave uncommitted process and proof alive')
elif name == 'extra-shadow':
    function(lib / 'common.sh', 'team_identity_extra_guard', '  return 0 # identity shadow accepted')
elif name == 'template-shadow':
    function(lib / 'common.sh', 'team_template_identity_guard', '  return 0 # hardcoded template identity accepted')
elif name == 'literal-shell-expansion':
    path = lib / 'common.sh'
    text = path.read_text()
    start = text.index("      '*'|'?'|'['|']'|'~')\n")
    end = text.index("      ' '|$'\\t')", start)
    replace(path, text[start:end], '      # P228_FLIP_literal-shell-expansion: launch shell expands unchecked argv\n')
elif name == 'init-legacy-proceeds':
    # P235 red side: the legacy-model gate is removed, so init/bootstrap migrate by overwrite.
    function(lib / 'cmd-project.sh', 'team_config_legacy_model_keys', '  return 0 # P235_FLIP_init-legacy-proceeds')
elif name == 'template-retired-key':
    # P235 red side: the shipped template carries the retired worker key again.
    replace(root / 'skills/teamsmith/templates/config.sh.tmpl',
            'TEAM_TASK_MODELS=""',
            'TEAM_DEFAULT_MODEL="{{PROJECT}}" # P235_FLIP_template-retired-key\nTEAM_TASK_MODELS=""')
elif name == 'worker-literal-resplit':
    replace(lib / 'cmd-agents.sh',
            '    team_literal_argv "$TEAM_EXTRA_PI_ARGS" || return 1\n    piargs+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    piargs+=($TEAM_EXTRA_PI_ARGS) # P228_FLIP_worker-literal-resplit')
elif name == 'pm-literal-resplit':
    replace(lib / 'common.sh',
            '    team_literal_argv "$TEAM_PM_RESUME_ARGS" || return 1\n    args+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    args+=($TEAM_PM_RESUME_ARGS) # P228_FLIP_pm-literal-resplit-resume')
    replace(lib / 'common.sh',
            '    team_literal_argv "$TEAM_PM_EXTRA_PI_ARGS" || return 1\n    args+=("${TEAM_LITERAL_TOKENS[@]}")',
            '    args+=($TEAM_PM_EXTRA_PI_ARGS) # P228_FLIP_pm-literal-resplit-extra')
elif name == 'template-roles':
    # Restore F5's lexical-only walk on a real copied source, including the
    # resume selector-as-data path. No assertion/test code is changed.
    function(lib / 'common.sh', 'team_argv_roles_guard', '  return 0 # argv roles ignored')
    replace(lib / 'common.sh',
            '      -e|--skill) i=$((i+1)); continue ;; # proved scalar data, never a selector',
            '      # P228_FLIP_template-roles: tool data mistaken for selectors')
    replace(lib / 'common.sh',
            '      -e|--skill) i=$((i+1)) ;; # scalar role already proved; its data is not continuity',
            '      # P228_FLIP_template-roles: tool data mistaken for continuity')
elif name == 'template-unbound':
    # Restore F4: occurrence is mistaken for an owned selector binding.
    # The new surrounding-role proof independently refuses identity-as-tool-data,
    # so restore that part of the older source as well; leave tests untouched.
    function(lib / 'common.sh', 'team_argv_roles_guard', '  return 0 # old unbound data walk')
    path = lib / 'common.sh'
    text = path.read_text()
    start = text.index('  # Presence is not ownership:')
    end = text.index('  if [ "$mode" = continued ]; then', start)
    replace(path, text[start:end], '  # P228_FLIP_template-unbound: no binding proof\n')
    replace(path, '[ "${seen[$token]:-0}" = 1 ] || { team_err',
                  '[ "${refs[$token]:-0}" = 1 ] || { team_err')
elif name == 'monitor-record-drift':
    replace(root / 'skills/teamsmith/scripts/monitor.mjs',
            '      team_assignment_parse "$2" "$data" || exit 1',
            '      data="$(printf "%s" "$data" | sed "s/malformed nonce/fixture-nonce/")" # P228_FLIP_monitor-record-drift\n      team_assignment_parse "$2" "$data" || exit 1')
else:
    raise SystemExit('unknown mutation: ' + name)
print(json.dumps(dict(mutation=name, changes=changes), ensure_ascii=False))
