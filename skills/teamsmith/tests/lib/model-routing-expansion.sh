#!/usr/bin/env bash
# F3: run real shell argv against files that turn an innocent-looking token into
# an owned selector. Only the routing front door's private repo/HOME/socket is used.

# Short resplit samples branch before the full fixture's git/process preparation.
# Keep the PM guard and metadata publisher/loader real, with a private legal policy.
routing_argv_setup() {
  mkdir -p "$STATE" || return 1
  printf "TEAM_TASK_MODELS='routine=vendor/routine'\nTEAM_PM_MODEL='vendor/pm:high'\n" > "$CONFIG" || return 1
  printf 'identity decoy\n' > "$REPO/--model=wrong:low" || return 1
  export TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_STATE_DIR="$STATE" TEAM_CONFIG="$CONFIG" TEAM_SKILL_DIR="$SKILL"
  TEAM_CLI=team; TEAM_PM_WINDOW=pm
  source "$SKILL/scripts/lib/common.sh" || return 1
  source "$SKILL/scripts/lib/cmd-agents.sh" || return 1
  source "$CONFIG" || return 1
  TEAM_EXTRA_PI_ARGS=''; TEAM_PM_CMD=''; TEAM_PM_SESSION_ID=''
  TEAM_PM_EXTRA_PI_ARGS=''; TEAM_PM_RESUME_ARGS=''
  cd "$REPO" || return 1
}

routing_worker_argv_probe() {
  local rendered rc=0
  TEAM_EXTRA_PI_ARGS=' --label "two words" "--mod*" "{safe,words}" "~/routing-note"'
  TEAM_EXTRA_PI_ARGS+=" 'one\\two'"
  rendered="$(team_pi_args vendor/deep/model:high)" || rc=$?
  check worker-argv-renderer eq "$rc" 0
  [ "$rc" = 0 ] || return 1
  bash --noprofile --norc -c "printf '%s\\0' $rendered" > "$TMP/worker-argv.nul"; rc=$?
  check worker-argv-shell eq "$rc" 0
  [ "$rc" = 0 ] || return 1
  check worker-expansion-literal-argv:extra python3 - "$TMP/worker-argv.nul" <<'PY'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_bytes()
assert raw.endswith(b'\0'), raw
argv = raw[:-1].decode().split('\0')
print('ARGV worker-extra ' + json.dumps(argv))
assert argv[:4] == ['--provider', 'vendor', '--model', 'deep/model:high'], argv
assert argv.count('--provider') == argv.count('--model') == 1, argv
assert argv[argv.index('--label'):] == ['--label', 'two words', '--mod*', '{safe,words}', '~/routing-note', r'one\two'], argv
assert '--model=wrong:low' not in argv, argv
PY
}

routing_pm_argv_probes() {
  local field rendered rc metadata_before
  TEAM_PM_FRESH_LAUNCH=0
  TEAM_PM_RESUME_ARGS=" --session-id 'fixture-literal-session'"
  team_pm_metadata_publish fixture-argv || { check pm-argv-metadata-publish eq 1 0; return 1; }
  team_pm_metadata_load || { check pm-argv-metadata-load eq 1 0; return 1; }
  metadata_before="$(sha "$STATE/pm-launch.env")"
  for field in extra resume; do
    if [ "$field" = extra ]; then
      TEAM_PM_FRESH_LAUNCH=1; TEAM_PM_RESUME_ARGS=''
      TEAM_PM_EXTRA_PI_ARGS=' --label "two words" "--mod*" "{safe,words}" "~/routing-note"'
      TEAM_PM_EXTRA_PI_ARGS+=" 'one\\two'"
    else
      TEAM_PM_FRESH_LAUNCH=0; TEAM_PM_EXTRA_PI_ARGS=''
      TEAM_PM_RESUME_ARGS=" --session-id 'fixture-literal-session'"
    fi
    rc=0; rendered="$(team_pm_pi_args)" || rc=$?
    check "pm-argv-renderer:$field" eq "$rc" 0
    [ "$rc" = 0 ] || continue
    bash --noprofile --norc -c "printf '%s\\0' $rendered" > "$TMP/pm-argv-$field.nul"; rc=$?
    check "pm-argv-shell:$field" eq "$rc" 0
    [ "$rc" = 0 ] || continue
    local name=pm-expansion-literal-argv:extra
    [ "$field" != resume ] || name=pm-resume-literal-argv:builtin
    check "$name" python3 - "$TMP/pm-argv-$field.nul" "$field" <<'PY'
import json, pathlib, sys
raw = pathlib.Path(sys.argv[1]).read_bytes()
assert raw.endswith(b'\0'), raw
argv = raw[:-1].decode().split('\0')
print('ARGV pm-' + sys.argv[2] + ' ' + json.dumps(argv))
assert argv[:4] == ['--provider', 'vendor', '--model', 'pm:high'], argv
assert argv.count('--provider') == argv.count('--model') == 1, argv
assert not any(x in argv for x in ['-c', '--continue', '--model=wrong:low']), argv
if sys.argv[2] == 'extra':
    assert argv[argv.index('--label'):] == ['--label', 'two words', '--mod*', '{safe,words}', '~/routing-note', r'one\two'], argv
    assert '--session-id' not in argv, argv
else:
    assert argv.count('--session-id') == 1 and argv[argv.index('--session-id'):] == ['--session-id', 'fixture-literal-session'], argv
PY
  done
  check pm-argv-metadata-unchanged eq "$(sha "$STATE/pm-launch.env")" "$metadata_before"
}

routing_expansion_probes() { # worker|pm
  local seat="$1" field tag fragment mode before sid='' previous_map
  previous_map="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  run config set-task-model routine vendor/routine
  check "$seat-expansion-category-ready" eq "$RC" 0
  if [ "$seat" = worker ]; then
    run config set TEAM_AGENT_CMD '' --yes
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/deep/model:high --fresh
    check expansion-assignment-ready eq "$RC" 0
    team_assignment_load dev; sid="${TEAM_ASSIGN[sid]}"; stop_fixture_seat dev
  else
    # PM probes keep a private anchor alive; never use the shared session.
    routing_fixture_tmux new-window -d -t routing-fixture -n expansion-anchor 'sleep 600'
    stop_fixture_seat pm
  fi
  local root="$REPO" custom=""
  [ "$seat" != worker ] || root="$REPO/.worktrees/dev"
  local -a decoys=('--provider=other' '--model=wrong:low' '--session-id=other-history' '--continue' '--resume=other-history' '-mwrong' 'other-history.jsonl')
  for fragment in "${decoys[@]}"; do printf 'identity decoy\n' > "$root/$fragment"; done
  local -a faults=(
    'provider-glob|--pro*' 'model-glob|--mod*' 'sid-glob|--sess*'
    'continue-glob|--cont*' 'resume-glob|--resu*' 'short-class|-?[r]ong'
    'session-file-glob|*.jsonl' 'provider-class|--[p]rovider*'
    'mixed-quote|"--mod"*' 'brace|{--model=wrong:low,--no-tools}'
    'tilde|~/routing-note' 'doublequote-escape|"two\\\\words"'
  )
  # Match an actual short selector too (the first pattern deliberately matches
  # nothing but still has unprovable pathname semantics).
  faults+=('short-glob|-m*')
  for field in template extra; do
    for fragment in "${faults[@]}"; do
      tag="${fragment%%|*}"; fragment="${fragment#*|}"
      if [ "$seat" = worker ]; then
        run config set TEAM_EXTRA_PI_ARGS '' --yes
        custom="$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id}"
        if [ "$field" = template ]; then
          run config set TEAM_AGENT_CMD "$custom $fragment" --yes
        else
          run config set TEAM_AGENT_CMD '' --yes
          run config set TEAM_EXTRA_PI_ARGS " $fragment" --yes
        fi
      else
        run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
        custom="$TMP/recording-pi --provider {provider} --model {model} {resume_args} {prompt}"
        if [ "$field" = template ]; then
          run config set TEAM_PM_CMD "$custom $fragment" --yes
        else
          run config set TEAM_PM_CMD '' --yes
          run config set TEAM_PM_EXTRA_PI_ARGS " $fragment" --yes
        fi
      fi
      check "$seat-expansion-config:$field:$tag" eq "$RC" 0
      for mode in preview launch; do
        before="$(routing_observable_snapshot)"
        if [ "$seat" = worker ]; then
          if [ "$mode" = preview ]; then run dispatch dev T1 docs/team/tasks/T1-fixture.md --print; else run dispatch dev T1 docs/team/tasks/T1-fixture.md; fi
        else
          if [ "$mode" = preview ]; then run up --fresh-pm --print; else run up --fresh-pm; fi
        fi
        check "$seat-expansion-refused:$field:$tag:$mode" eq "$RC" 1
        check "$seat-expansion-pure:$field:$tag:$mode" eq "$(routing_observable_snapshot)" "$before"
        if [ "$seat" = worker ]; then stop_fixture_seat dev; else stop_fixture_seat pm; fi
      done
    done
  done
  # Quoted wildcard/brace/tilde text is literal data, not an expansion. Builtin
  # PM must consume the lexer's tokens, not re-split the original quoted text.
  local literal='--label "two words" "--mod*" "{safe,words}" "~/routing-note"'
  literal+=" 'one\\two'"
  for field in template extra; do
    if [ "$seat" = worker ]; then
      run config set TEAM_EXTRA_PI_ARGS '' --yes
      custom="$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id}"
      if [ "$field" = template ]; then run config set TEAM_AGENT_CMD "$custom $literal" --yes
      else run config set TEAM_AGENT_CMD '' --yes; run config set TEAM_EXTRA_PI_ARGS " $literal" --yes; fi
    else
      run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
      custom="$TMP/recording-pi --provider {provider} --model {model} {resume_args} {prompt}"
      if [ "$field" = template ]; then run config set TEAM_PM_CMD "$custom $literal" --yes
      else run config set TEAM_PM_CMD '' --yes; run config set TEAM_PM_EXTRA_PI_ARGS " $literal" --yes; fi
    fi
    check "$seat-expansion-literal-config:$field" eq "$RC" 0
    before="$(routing_observable_snapshot)"
    if [ "$seat" = worker ]; then run dispatch dev T1 docs/team/tasks/T1-fixture.md --print; else run up --fresh-pm --print; fi
    check "$seat-expansion-literal-preview:$field" eq "$RC" 0
    check "$seat-expansion-literal-preview-pure:$field" eq "$(routing_observable_snapshot)" "$before"
    if [ "$seat" = worker ]; then run dispatch dev T1 docs/team/tasks/T1-fixture.md; else run up --fresh-pm; fi
    check "$seat-expansion-literal-launch:$field" eq "$RC" 0
    check "$seat-expansion-literal-argv:$field" python3 - "$TMP/argv-jsonl" "$seat" "$sid" <<'PY'
import json,sys
argv=json.loads(open(sys.argv[1]).readlines()[-1])
assert argv[argv.index('--label')+1]=='two words',argv
assert all(x in argv for x in ['--mod*','{safe,words}','~/routing-note',r'one\two']),argv
assert '--model=wrong:low' not in argv and '--provider=other' not in argv,argv
assert argv.count('--model')==1 and argv.count('--provider')==1,argv
assert argv[argv.index('--provider')+1]=='vendor',argv
if sys.argv[2]=='worker':
 assert argv[argv.index('--model')+1]=='deep/model:high' and argv[argv.index('--session-id')+1]==sys.argv[3],argv
else:
 assert argv[argv.index('--model')+1]=='pm:high' and '-c' not in argv and '--continue' not in argv,argv
PY
    if [ "$seat" = worker ]; then stop_fixture_seat dev; else stop_fixture_seat pm; fi
  done
  if [ "$seat" = pm ]; then routing_pm_resume_expansion_probes; fi
  for fragment in "${decoys[@]}"; do rm -- "$root/$fragment"; done
  if [ "$seat" = worker ]; then
    run config set TEAM_AGENT_CMD '' --yes; run config set TEAM_EXTRA_PI_ARGS '' --yes
  else
    run config set TEAM_PM_CMD '' --yes; run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
  fi
  run config set TEAM_TASK_MODELS "$previous_map" --yes
  check "$seat-expansion-policy-restored" eq "$RC" 0
}
routing_pm_resume_expansion_probes() {
  local field fragment mode before saved="$TMP/pm-expansion-saved-record"
  cp -p "$STATE/pm-launch.env" "$saved"
  for field in builtin custom; do
    if [ "$field" = builtin ]; then run config set TEAM_PM_CMD '' --yes
    else run config set TEAM_PM_CMD "$TMP/recording-pi --provider {provider} --model {model} {resume_args} {prompt}" --yes; fi
    run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
    for fragment in '--mod*' '--pro*' '--sess*' '--cont*' '--resu*' '{--model=wrong:low,--continue}' '--session-id ~'; do
      run config set TEAM_PM_RESUME_ARGS " $fragment" --yes
      check "pm-resume-expansion-config:$field:$fragment" eq "$RC" 0
      # Controlled same-key metadata makes this a real continuation test, not a
      # fresh-pm call that discards resume_args before it can reach the shell.
      (TEAM_PM_FRESH_LAUNCH=0; TEAM_PM_RESUME_ARGS=" $fragment"; team_pm_metadata_publish fixture-resume-expansion)
      check "pm-resume-expansion-record:$field:$fragment" eq "$?" 0
      for mode in preview launch; do
        before="$(routing_observable_snapshot)"
        if [ "$mode" = preview ]; then run up --print; else run up; fi
        check "pm-resume-expansion-refused:$field:$fragment:$mode" eq "$RC" 1
        check "pm-resume-expansion-pure:$field:$fragment:$mode" eq "$(routing_observable_snapshot)" "$before"
        stop_fixture_seat pm
      done
    done
    fragment=" --session-id 'fixture-literal-session'"
    run config set TEAM_PM_RESUME_ARGS "$fragment" --yes
    check "pm-resume-literal-config:$field" eq "$RC" 0
    (TEAM_PM_FRESH_LAUNCH=0; TEAM_PM_RESUME_ARGS="$fragment"; team_pm_metadata_publish fixture-resume-literal)
    check "pm-resume-literal-record:$field" eq "$?" 0
    before="$(routing_observable_snapshot)"
    run up --print
    check "pm-resume-literal-preview:$field" eq "$RC" 0
    check "pm-resume-literal-preview-pure:$field" eq "$(routing_observable_snapshot)" "$before"
    run up
    check "pm-resume-literal-launch:$field" eq "$RC" 0
    check "pm-resume-literal-argv:$field" python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert a.count("--session-id")==1 and a[a.index("--session-id")+1]=="fixture-literal-session",a; assert a[a.index("--model")+1]=="pm:high",a' "$TMP/argv-jsonl"
    stop_fixture_seat pm
  done
  run config set TEAM_PM_RESUME_ARGS '' --yes
  cp -p "$saved" "$STATE/pm-launch.env"
}
