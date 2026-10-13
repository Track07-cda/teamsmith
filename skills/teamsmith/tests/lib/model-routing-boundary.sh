#!/usr/bin/env bash
# P228 repair probes. Sourced only by the isolated routing front door.
routing_observable_snapshot() {
  { find "$STATE" -type f -printf '%p %T@ %s\n' 2>/dev/null | sort
    find "$STATE" -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum
    sha256sum "$CONFIG" "$REPO/docs/team/BOARD.md" "$TMP/argv-jsonl" 2>/dev/null || true
    tmux list-windows -t routing-fixture -F '#{window_id} #{pane_id} #{pane_pid}' 2>/dev/null || true
    git -C "$REPO/.worktrees/dev" status --porcelain
  } | sha256sum | cut -d' ' -f1
}
# Preserve each negative template arm, not only the final restored record. All files
# are synthetic fixture data; capture lives outside observable project state.
routing_binding_capture() { # entry tag mode before|after
  local entry="$1" tag="$2" mode="$3" phase="$4" f dest
  dest="$TMP/binding-cases/$entry-$tag-$mode/$phase"
  mkdir -p "$dest" || return 1
  for f in "$CONFIG" "$REPO/docs/team/BOARD.md" "$TMP/argv-jsonl" \
      "$STATE/dev.env" "$STATE/pm-launch.env" "$STATE/prompt-dev-T1.md" "$STATE/pm-prompt.md"; do
    if [ -f "$f" ]; then cp -p "$f" "$dest/" || return 1; else printf '%s\n' "$f" >> "$dest/absent.txt" || return 1; fi
  done
  routing_observable_snapshot > "$dest/effect.hash"
}
# Option-aware record-only oracle, not a Pi/provider compatibility parser. The
# probe's supported selectors must each occur once; unrelated data flags consume
# their literal value, and do not count as identity merely by containing it.
routing_identity_argv_check() { # jsonl provider model sid|- continuity|-
  python3 - "$@" <<'PY'
import json,sys
path,provider,model,sid,continuity=sys.argv[1:]
args=json.loads(open(path).readlines()[-1]); found={k:[] for k in ('provider','model','sid','continuity')}
i=0
while i<len(args):
    a=args[i]; i+=1
    if a in ('--label','-e','--skill'):
        assert i<len(args),args
        i+=1; continue
    if a in ('-c','--continue'):
        found['continuity'].append(a); continue
    for key,opts in {'provider':('--provider',),'model':('--model','-m'),'sid':('--session-id','-s')}.items():
        if a in opts:
            assert i<len(args),args
            found[key].append(args[i]); i+=1; break
        if any(a.startswith(o+'=') for o in opts):
            found[key].append(a.split('=',1)[1]); break
        if any(len(o)==2 and a.startswith(o) for o in opts):
            found[key].append(a[2:]); break
expected={'provider':[provider],'model':[model],'sid':[] if sid=='-' else [sid],
          'continuity':[] if continuity=='-' else [continuity]}
assert found==expected,(found,expected,args)
PY
}
routing_template_probes() {
  # A preceding resume group deliberately removes routine from future policy.
  # This probe makes a new explicit choice: establish its own mapped premise,
  # then restore the prior policy. Never weaken the unmapped-override guard.
  local before_map; before_map="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  run config set-task-model routine vendor/routine
  check template-probe-category-ready eq "$RC" 0
  stop_fixture_seat dev
  # Begin with an actual complete assignment and a stopped recording CLI.
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/deep/model:high --fresh
  check template-probe-trusted-setup eq "$RC" 0
  team_assignment_load dev; local sid="${TEAM_ASSIGN[sid]:-missing}" bad tag mode snapshot
  stop_fixture_seat dev
  local good="$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id}"
  local -a faults=(
    'all-hardcoded|--provider other --model wrong:low --session-id other-history'
    'provider-hardcoded|--provider other --model {model} --session-id {session_id}'
    'model-hardcoded|--provider {provider} --model wrong:low --session-id {session_id}'
    'sid-hardcoded|--provider {provider} --model {model} --session-id other-history'
    'equals-hardcoded|--provider=other --model=wrong --session-id=other-history'
    'short-hardcoded|-mwrong -sother-history'
    'quoted-identity|"--model=wrong" --session-id {session_id}'
    'duplicate-model|--provider {provider} --model {model} --model wrong --session-id {session_id}'
    'duplicate-provider|--provider {provider} --provider {provider} --model {model} --session-id {session_id}'
    'script-placeholder|"--provider {provider} --model {model} --session-id {session_id}"'
    'hidden-script-option|--provider {provider} --model {model} --session-id {session_id} "exec pi --model wrong"'
    'joined-placeholders|{provider}{model}{session_id}'
    'positional-all|{provider} {model} {session_id}'
    'positional-provider|{provider} --model {model} --session-id {session_id}'
    'positional-model|--provider {provider} {model} --session-id {session_id}'
    'positional-sid|--provider {provider} --model {model} {session_id}'
    'data-provider|--label {provider} --model {model} --session-id {session_id}'
    'data-model|--provider {provider} -e {model} --session-id {session_id}'
    'data-sid|--provider {provider} --model {model} --skill {session_id}'
    'list-as-model|--provider {provider} --model {extra_args} {model} --session-id {session_id}'
    'duplicate-sid|--provider {provider} --model {model} --session-id {session_id} --session-id {session_id}'
    'continue|--provider {provider} --model {model} --session-id {session_id} --continue'
    'resume|--provider {provider} --model {model} --session-id {session_id} -r other-history'
    'bare-session|--provider {provider} --model {model} other-history.jsonl'
    'missing-model-value|--provider {provider} --model --session-id {session_id}'
    'missing-sid-selector|--provider {provider} --model {model}'
    'misbound-placeholder|--provider {model} --model {provider} --session-id {session_id}'
    'quoted-placeholder|--provider {provider} --model "{model}" --session-id {session_id}'
    'hidden-shell|--provider {provider} --model {model} --session-id {session_id}; touch TEMPLATE_PWNED'
  )
  for bad in "${faults[@]}"; do
    tag="${bad%%|*}"; run config set TEAM_AGENT_CMD "$TMP/recording-pi ${bad#*|}" --yes
    # The writer may reject the template, which itself is a safe no-launch result.
    if [ "$RC" != 0 ]; then check "template-writer-refusal:$tag" eq "$RC" 4; continue; fi
    for mode in preview launch fresh-preview fresh-launch; do
      # Only continuation requires the opaque template to expose full identity;
      # fresh does not upgrade the frozen seam into a non-Pi compatibility promise.
      case "$tag:$mode" in missing-sid-selector:fresh-*) continue ;; esac
      snapshot="$(routing_observable_snapshot)"
      check "binding-capture:worker:$tag:$mode:before" routing_binding_capture worker "$tag" "$mode" before
      case "$mode" in
        preview) run dispatch dev T1 docs/team/tasks/T1-fixture.md --force --print ;;
        launch) run dispatch dev T1 docs/team/tasks/T1-fixture.md --force ;;
        fresh-preview) run dispatch dev T1 docs/team/tasks/T1-fixture.md --force --fresh --print ;;
        fresh-launch) run dispatch dev T1 docs/team/tasks/T1-fixture.md --force --fresh ;;
      esac
      check "template-refused:$tag:$mode" eq "$RC" 1
      check "template-pure:$tag:$mode" eq "$(routing_observable_snapshot)" "$snapshot"
      check "binding-capture:worker:$tag:$mode:after" routing_binding_capture worker "$tag" "$mode" after
      # Do not let a red old implementation leave an uncommitted worker running.
      stop_fixture_seat dev
    done
  done
  for mode in separate equals short attached extras literal-data; do
    case "$mode" in
      separate) good="$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id}" ;;
      equals) good="$TMP/recording-pi --provider={provider} --model={model} --session-id={session_id}" ;;
      short) good="$TMP/recording-pi --provider {provider} -m {model} -s {session_id}" ;;
      attached) good="$TMP/recording-pi --provider={provider} -m{model} -s{session_id}" ;;
      extras) good="$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id} {extra_args}"
        run config set TEAM_EXTRA_PI_ARGS ' --no-tools --label "two words"' --yes
        check template-harmless-extra-config eq "$RC" 0 ;;
      literal-data) good="$TMP/recording-pi -e 'deep/model:high' --skill literal --provider {provider} --model {model} --session-id {session_id} {extra_args} --label vendor" ;;
    esac
    run config set TEAM_AGENT_CMD "$good" --yes
    check "template-legal-config:$mode" eq "$RC" 0
    snapshot="$(routing_observable_snapshot)"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
    check "template-legal-preview:$mode" eq "$RC" 0
    check "template-legal-preview-pure:$mode" eq "$(routing_observable_snapshot)" "$snapshot"
    check "template-legal-preview-sid:$mode" contains "$OUT" "$sid"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md
    check "template-legal-launch:$mode" eq "$RC" 0
    check "template-legal-argv:$mode" routing_identity_argv_check "$TMP/argv-jsonl" vendor deep/model:high "$sid" -
    if [ "$mode" = extras ]; then
      check template-legal-extra-data python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert "--no-tools" in a and a[a.index("--label")+1]=="two words"' "$TMP/argv-jsonl"
    fi
    stop_fixture_seat dev
    snapshot="$(routing_observable_snapshot)"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh --print
    check "template-bound-fresh-preview:$mode" eq "$RC" 0
    check "template-bound-fresh-preview-pure:$mode" eq "$(routing_observable_snapshot)" "$snapshot"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
    check "template-bound-fresh-launch:$mode" eq "$RC" 0
    local old_sid="$sid"; team_assignment_load dev; sid="${TEAM_ASSIGN[sid]:-missing}"
    check "template-bound-fresh-new-sid:$mode" test "$sid" != "$old_sid"
    check "template-bound-fresh-record-model:$mode" eq "${TEAM_ASSIGN[model]:-missing}" vendor/deep/model:high
    check "template-bound-fresh-record-mode:$mode" eq "${TEAM_ASSIGN[mode]:-missing}" fresh
    check "template-bound-fresh-exact-argv:$mode" routing_identity_argv_check "$TMP/argv-jsonl" vendor deep/model:high "$sid" -
    stop_fixture_seat dev
  done
  run config set TEAM_EXTRA_PI_ARGS '' --yes
  run config set TEAM_AGENT_CMD '' --yes
  run config set TEAM_TASK_MODELS "$before_map" --yes
  check template-probe-policy-restored eq "$RC" 0
}
routing_pm_template_probes() {
  local tag bad mode snapshot good
  local -a faults=(
    'provider|--provider other --model {model}'
    'model|--provider {provider} --model wrong'
    'equals|--provider=other --model=wrong'
    'short|-mwrong'
    'duplicate|--provider {provider} --model {model} --model {model}'
    'missing|--provider {provider} --model'
    'session|--provider {provider} --model {model} --session-id wrong'
    'session-placeholder|--provider {provider} --model {model} --session-id {session_id}'
    'continue|--provider {provider} --model {model} -c'
    'resume-equals|--provider {provider} --model {model} --resume=wrong'
    'quoted|--provider {provider} "--model=wrong"'
    'bare-session|--provider {provider} --model {model} history.jsonl'
    'misbound|--provider {model} --model {provider}'
    'positional-all|{provider} {model}'
    'positional-provider|{provider} --model {model}'
    'positional-model|--provider {provider} {model}'
    'data-provider|--label {provider} --model {model}'
    'data-model|--provider {provider} -e {model}'
    'list-as-model|--provider {provider} --model {extra_args} {model}'
    'script-placeholder|"--provider {provider} --model {model}"'
    'hidden-script-option|--provider {provider} --model {model} "exec pi --model wrong"'
  )
  # Keep the private server/session alive while each arm deliberately stops PM.
  # Otherwise stopping its last window destroys the premise of the older rollback
  # control later in this same fixture (not a product publication failure).
  tmux new-window -d -t routing-fixture -n boundary-anchor 'sleep 600'
  check pm-template-private-anchor eq "$?" 0
  stop_fixture_seat pm
  for bad in "${faults[@]}"; do
    tag="${bad%%|*}"; run config set TEAM_PM_CMD "$TMP/recording-pi ${bad#*|} {resume_args} {prompt}" --yes
    check "pm-template-config:$tag" eq "$RC" 0
    for mode in preview launch; do
      snapshot="$(routing_observable_snapshot)"
      check "binding-capture:pm-fresh:$tag:$mode:before" routing_binding_capture pm-fresh "$tag" "$mode" before
      if [ "$mode" = preview ]; then run up --fresh-pm --print; else run up --fresh-pm; fi
      check "pm-template-refused:$tag:$mode" eq "$RC" 1
      check "pm-template-pure:$tag:$mode" eq "$(routing_observable_snapshot)" "$snapshot"
      check "binding-capture:pm-fresh:$tag:$mode:after" routing_binding_capture pm-fresh "$tag" "$mode" after
      stop_fixture_seat pm
    done
  done
  good="$TMP/recording-pi --provider {provider} --model {model} {resume_args} {prompt}"
  run config set TEAM_PM_CMD "$good" --yes
  run up --fresh-pm --print
  check pm-template-legal-preview eq "$RC" 0
  run up --fresh-pm
  check pm-template-legal-launch eq "$RC" 0
  check pm-template-legal-argv routing_identity_argv_check "$TMP/argv-jsonl" vendor pm:high - -
  stop_fixture_seat pm
  cp -p "$STATE/pm-launch.env" "$TMP/pm-fresh-control-record"
  run config set TEAM_PM_RESUME_ARGS ' --continue' --yes
  check pm-custom-resume-selector-config eq "$RC" 0
  # Explicitly prepared trusted fixture metadata; this is not a claim about Pi
  # history quality. The real launcher must still deliver the selected argv.
  (TEAM_PM_MODEL=vendor/pm:high; TEAM_PM_RESUME_ARGS=--continue; TEAM_PM_FRESH_LAUNCH=0; team_pm_metadata_publish fixture-custom-continuation)
  check pm-custom-known-record-prepared eq "$?" 0
  cp -p "$STATE/pm-launch.env" "$TMP/pm-custom-control-record"
  for tag in provider model positional-all positional-provider positional-model data-provider data-model; do
    case "$tag" in
      provider) bad='--model {model} {resume_args} {prompt}' ;;
      model) bad='--provider {provider} {resume_args} {prompt}' ;;
      positional-all) bad='{provider} {model} {resume_args} {prompt}' ;;
      positional-provider) bad='{provider} --model {model} {resume_args} {prompt}' ;;
      positional-model) bad='--provider {provider} {model} {resume_args} {prompt}' ;;
      data-provider) bad='--label {provider} --model {model} {resume_args} {prompt}' ;;
      data-model) bad='--provider {provider} -e {model} {resume_args} {prompt}' ;;
    esac
    run config set TEAM_PM_CMD "$TMP/recording-pi $bad" --yes
    for mode in preview launch; do
      snapshot="$(routing_observable_snapshot)"
      check "binding-capture:pm-continued:$tag:$mode:before" routing_binding_capture pm-continued "$tag" "$mode" before
      if [ "$mode" = preview ]; then run up --print; else run up; fi
      check "pm-custom-missing-refused:$tag:$mode" eq "$RC" 1
      check "pm-custom-missing-pure:$tag:$mode" eq "$(routing_observable_snapshot)" "$snapshot"
      check "binding-capture:pm-continued:$tag:$mode:after" routing_binding_capture pm-continued "$tag" "$mode" after
      stop_fixture_seat pm
    done
  done
  # Frozen seam explicitly keeps the lost-history branch: if {resume_args} is
  # absent, report that it is not used, rather than pretending to continue.
  run config set TEAM_PM_CMD "$TMP/recording-pi --provider {provider} --model {model} {prompt}" --yes
  run up --print
  check pm-custom-missing-resume-lost-preview eq "$RC" 0
  run up
  check pm-custom-missing-resume-lost-launch eq "$RC" 0
  check pm-custom-missing-resume-honest contains "$OUT" '参数不会带上'
  check pm-custom-missing-resume-no-continue-argv python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert "--continue" not in a and "-c" not in a' "$TMP/argv-jsonl"
  stop_fixture_seat pm
  cp -p "$TMP/pm-custom-control-record" "$STATE/pm-launch.env"
  run config set TEAM_PM_CMD "$good" --yes
  run up --print
  check pm-custom-known-continue-preview eq "$RC" 0
  run up
  check pm-custom-known-continue-launch eq "$RC" 0
  check pm-custom-continue-argv routing_identity_argv_check "$TMP/argv-jsonl" vendor pm:high - --continue
  stop_fixture_seat pm
  # Same continuation with literal data and alternate supported selector forms.
  for tag in separate equals short attached; do
    cp -p "$TMP/pm-custom-control-record" "$STATE/pm-launch.env"
    case "$tag" in
      separate) good='--provider {provider} --model {model}' ;;
      equals) good='--provider={provider} --model={model}' ;;
      short) good='--provider {provider} -m {model}' ;;
      attached) good='--provider={provider} -m{model}' ;;
    esac
    # --label is recording-CLI data with unknown production arity: keep it
    # after every owned group instead of assuming a Pi-wide option table.
    run config set TEAM_PM_CMD "$TMP/recording-pi -e 'pm:high' --skill literal $good {extra_args} {resume_args} {prompt} --label vendor" --yes
    check "pm-bound-config:$tag" eq "$RC" 0
    for mode in preview launch; do
      snapshot="$(routing_observable_snapshot)"
      if [ "$mode" = preview ]; then run up --print; else run up; fi
      check "pm-bound-valid:$tag:$mode" eq "$RC" 0
      if [ "$mode" = preview ]; then
        check "pm-bound-preview-pure:$tag" eq "$(routing_observable_snapshot)" "$snapshot"
      else
        check "pm-bound-exact-argv:$tag" routing_identity_argv_check "$TMP/argv-jsonl" vendor pm:high - --continue
        check "pm-bound-continued-record:$tag" contains "$(team_pm_metadata_load && printf '%s' "$TEAM_PM_METADATA_JSON")" '"mode":"continued"'
        stop_fixture_seat pm
      fi
    done
    snapshot="$(routing_observable_snapshot)"
    run up --fresh-pm --print
    check "pm-bound-fresh-preview:$tag" eq "$RC" 0
    check "pm-bound-fresh-preview-pure:$tag" eq "$(routing_observable_snapshot)" "$snapshot"
    run up --fresh-pm
    check "pm-bound-fresh-launch:$tag" eq "$RC" 0
    check "pm-bound-fresh-exact-argv:$tag" routing_identity_argv_check "$TMP/argv-jsonl" vendor pm:high - -
    check "pm-bound-fresh-record:$tag" contains "$(team_pm_metadata_load && printf '%s' "$TEAM_PM_METADATA_JSON")" '"mode":"fresh"'
    stop_fixture_seat pm
  done
  run config set TEAM_PM_RESUME_ARGS '' --yes
  cp -p "$TMP/pm-fresh-control-record" "$STATE/pm-launch.env"
  run config set TEAM_PM_CMD '' --yes
  run up --print
  check pm-builtin-known-continue-preview eq "$RC" 0
  run up
  check pm-builtin-known-continue-launch eq "$RC" 0
  check pm-builtin-continue-argv python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert a[a.index("--model")+1]=="pm:high" and "-c" in a and any(x.startswith("@") for x in a)' "$TMP/argv-jsonl"
  stop_fixture_seat pm
  for bad in '--continue --session-id other' '--session-id' '--session-id=' '-s' '--resume history.jsonl --continue' '"--model=wrong"' '--provider=wrong' '-mwrong'; do
    (TEAM_PM_FRESH_LAUNCH=1; TEAM_PM_RESUME_ARGS="$bad"; team_pm_identity_guard) > "$TMP/pm-resume-guard-${RANDOM}.log" 2>&1
    check "pm-resume-ownership:$bad" eq "$?" 1
  done
}
routing_pm_metadata_matrix() {
  check pm-record-calendar-without-date bash --noprofile --norc -c '
    source "$1"
    date(){ return 91; }
    for t in 2026-10-09T00:00:00Z 2024-02-29T23:59:59Z 2000-02-29T00:00:00Z; do team_launch_time_valid "$t" || exit 1; done
    for t in 2026-02-30T00:00:00Z 1900-02-29T00:00:00Z 2026-13-01T00:00:00Z 2026-01-01T24:00:00Z 0000-01-01T00:00:00Z 2026-10-09Tgarbage; do
      if team_launch_time_valid "$t"; then exit 1; fi
    done
  ' _ "$SKILL/scripts/lib/common.sh"
  local saved="$TMP/pm-metadata-original" tag before rc
  cp "$STATE/pm-launch.env" "$saved"
  for tag in nonce nul time invalid-date model project window version mode missing duplicate blank oversized; do
    python3 - "$saved" "$STATE/pm-launch.env" "$tag" <<'PY'
import pathlib,sys
src,dest,tag=sys.argv[1:]; text=pathlib.Path(src).read_text()
r=dict(line.split('=',1) for line in text.splitlines())
faults={'nonce':('nonce','bad nonce'),'time':('time','2026-10-09Tgarbage'),
'invalid-date':('time','2026-02-30T00:00:00Z'),'model':('model','vendor//bad'),
'project':('project',r['project']+'/../repo'),'window':('window','wrong'),
'version':('metadata_version','2'),'mode':('mode','guess')}
if tag in faults: r[faults[tag][0]]=faults[tag][1]
if tag=='missing': del r['nonce']
text=''.join(k+'='+v+'\n' for k,v in r.items())
if tag=='nul': text=text.replace('nonce=', 'nonce=\0',1)
if tag=='duplicate': text+='nonce=other\n'
if tag=='blank': text+='\n'
if tag=='oversized': text+='padding='+'a'*65536+'\n'
pathlib.Path(dest).write_text(text)
PY
    before="$(sha "$STATE/pm-launch.env")"; rc=0; team_pm_metadata_load || rc=$?
    check "pm-metadata-rejected:$tag" eq "$rc" 1
    rc=0; team_pm_identity_guard > "$TMP/pm-metadata-$tag.log" 2>&1 || rc=$?
    check "pm-metadata-continue-refused:$tag" eq "$rc" 1
    run config list --json
    check "pm-metadata-machine-unavailable:$tag" python3 -c 'import json,sys; assert json.loads(sys.argv[1])["models"]["pm_launch"]=={}' "$OUT"
    check "pm-metadata-read-only:$tag" eq "$(sha "$STATE/pm-launch.env")" "$before"
    cp "$saved" "$STATE/pm-launch.env"
    check "pm-metadata-restored:$tag" team_pm_metadata_load
    check "pm-metadata-restored-continuation:$tag" team_pm_identity_guard
  done
}
routing_reader_matrix() {
  local saved="$TMP/reader-matrix-original" tag rc cols latest output before
  cp "$STATE/dev.env" "$saved"
  # A launch-size snapshot may be unknown or zero-padded; neither invalidates
  # complete identity or changes which committed session the readers select.
  for tag in '' 0005; do
    python3 - "$saved" "$STATE/dev.env" "$tag" <<'PY'
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text()
lines=[('sid_bytes='+sys.argv[3]) if x.startswith('sid_bytes=') else x for x in text.splitlines()]
pathlib.Path(sys.argv[2]).write_text('\n'.join(lines)+'\n')
PY
    before="$(sha "$STATE/dev.env")"
    check "reader-snapshot-valid:$tag" team_assignment_load dev
    check "reader-snapshot-monitor:$tag" contains "$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)" recorded-A.jsonl
    check "reader-snapshot-pure:$tag" eq "$(sha "$STATE/dev.env")" "$before"
    cp "$saved" "$STATE/dev.env"
  done
  check reader-record-without-GNU-normalizers bash --noprofile --norc -c '
    source "$1"; source "${1%/*}/cmd-config.sh"; TEAM_STATE_DIR="$2"
    date(){ return 91; }; readlink(){ return 91; }
    team_assignment_load dev && team_launch_path_valid / && team_launch_path_valid "$3/missing/leaf"
  ' _ "$SKILL/scripts/lib/common.sh" "$STATE" "$TMP"
  local -a faults=(nonce sid seat window category empty-branch empty-task taskfile-relative worktree-relative taskfile-dot worktree-dot taskfile-link worktree-link started started-date model-colon model-empty model-segment model-space key duplicate blank version bytes origin via mode missing nul)
  ln -s "$REPO/.worktrees/dev" "$TMP/reader-link-wt"
  ln -s "$REPO/docs/team/tasks/T1-fixture.md" "$TMP/reader-link-brief"
  for tag in "${faults[@]}"; do
    python3 - "$saved" "$STATE/dev.env" "$tag" "$TMP" <<'PY'
import pathlib,sys
source,dest,tag,tmp=sys.argv[1:]; text=pathlib.Path(source).read_text()
r=dict(line.split('=',1) for line in text.splitlines()); bad={
'nonce':('launch_nonce','malformed nonce'), 'sid':('sid','bad sid'),
'seat':('seat','verify'), 'window':('window','verify'), 'category':('category','Bad/category'),
'empty-branch':('branch',''), 'empty-task':('task',''),
'taskfile-relative':('taskfile','relative.md'), 'worktree-relative':('worktree','relative'),
'taskfile-dot':('taskfile',r['taskfile'].replace('/tasks/','/tasks/../tasks/')),
'worktree-dot':('worktree',r['worktree']+'/../dev'),
'taskfile-link':('taskfile',tmp+'/reader-link-brief'), 'worktree-link':('worktree',tmp+'/reader-link-wt'),
'started':('started','2026-10-09Tgarbage'), 'started-date':('started','2026-02-30T00:00:00Z'),
'model-colon':('model','bad:provider/model'), 'model-empty':('model','vendor/:high'),
'model-segment':('model','vendor/deep//model'), 'model-space':('model','vendor/model bad'),
'bytes':('sid_bytes','NaN'), 'origin':('selected_via','guess'), 'via':('launch_via','guess'),
'mode':('mode','guess'), 'version':('assignment_version','2')}
if tag in bad: r[bad[tag][0]]=bad[tag][1]
if tag=='missing': del r['launch_nonce']
text=''.join(k+'='+v+'\n' for k,v in r.items())
if tag=='key': text+='bad-key=unknown\n'
if tag=='duplicate': text+='sid='+r['sid']+'\n'
if tag=='blank': text+='\n'
if tag=='nul': text=text.replace('fixture-nonce','fixture-\0nonce')
pathlib.Path(dest).write_text(text)
PY
    before="$(sha "$STATE/dev.env")"; rc=0; team_assignment_load dev || rc=$?
    check "reader-record-rejected:$tag" eq "$rc" 1
    printf '%s rc=%s diagnostic=%s\n' "$tag" "$rc" "$TEAM_ASSIGN_DIAGNOSTIC" >> "$TMP/reader-matrix.log"
    cols="$(team_agent_session_cols dev)"; latest="$(team_agent_session_latest dev || true)"
    output="$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)"
    printf '%s\n' "$output" > "$TMP/reader-monitor-$tag.json"
    check "reader-size-unavailable:$tag" bash -c '! [[ "$1" == *recorded-A* || "$1" == *newer-B* ]]' _ "$cols"
    check "reader-death-unavailable:$tag" eq "$latest" ''
    check "reader-monitor-unavailable:$tag" contains "$output" 'committed SID unavailable'
    run config list --json
    check "reader-machine-unassigned:$tag" python3 -c 'import json,sys; d=json.loads(sys.argv[1]); r=next(r for r in d["models"]["assignments"] if r["agent"]=="dev"); assert not r["assigned"] and not r["sid"] and not r["model"] and r["diagnostic"]' "$OUT"
    check "reader-record-unmodified:$tag" eq "$(sha "$STATE/dev.env")" "$before"
    cp "$saved" "$STATE/dev.env"
    check "reader-restored-record:$tag" team_assignment_load dev
    check "reader-restored-monitor:$tag" contains "$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)" recorded-A.jsonl
  done
}
