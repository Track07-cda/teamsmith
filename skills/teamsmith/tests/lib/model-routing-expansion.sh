#!/usr/bin/env bash
# F3: run real shell argv against files that turn an innocent-looking token into
# an owned selector. Only the routing front door's private repo/HOME/socket is used.
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
