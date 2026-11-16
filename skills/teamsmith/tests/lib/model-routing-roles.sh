#!/usr/bin/env bash
# F5: isolated parameter-role controls; no runtime Pi/parser dependency.
# Uses only the routing front door's real recorder/repo/HOME/private socket.
routing_role_faults() { # caller supplies seat/good and a local faults array
  faults=()
  # Both emitted tool scalar roles, every identity selector and argv-list seam.
  # Unknown arity is NOT guessed, including unknown equals/quoted option forms.
  for tool in '--skill' '-e' '--unknown' '--unknown=value' '"--unknown"'; do
    faults+=("provider:$tool|$tool --provider {provider} --model {model}")
    faults+=("model:$tool|--provider {provider} $tool --model {model}")
    if [ "$seat" = worker ]; then
      faults[${#faults[@]}-2]+=' --session-id {session_id}'
      faults[${#faults[@]}-1]+=' --session-id {session_id}'
      faults+=("sid:$tool|--provider {provider} --model {model} $tool --session-id {session_id}")
    else
      faults[${#faults[@]}-2]+=' {resume_args}'
      faults[${#faults[@]}-1]+=' {resume_args}'
      faults+=("resume-list:$tool|--provider {provider} --model {model} $tool {resume_args}")
    fi
    faults+=("extra-list:$tool|$good $tool {extra_args}")
  done
  faults+=("unknown-scalar-prefix|--unknown harmless $good" "unknown-equals-prefix|--unknown=harmless $good" "quoted-unknown-prefix|\"--unknown\" harmless $good")
  if [ "$seat" = pm ]; then
    faults+=('extra-consumes-resume|--provider {provider} --model {model} {extra_args} {resume_args}'
      'extra-unknown-before-resume|--provider {provider} --model {model} {extra_args} {resume_args}'
      'resume-unknown-before-model|{resume_args} --provider {provider} --model {model}')
  else
    faults+=('extra-consumes-model|--provider {provider} {extra_args} --model {model} --session-id {session_id}'
      'extra-unknown-before-model|--provider {provider} {extra_args} --model {model} --session-id {session_id}')
  fi
}
routing_resume_role_faults() {
  faults=('--skill --continue' '-e -c' '--unknown --continue' '--unknown harmless --continue' '--skill --session-id fixture-sid' '-e -s fixture-sid' '--unknown --session-id fixture-sid')
}
routing_parameter_role_probes() {
  local seat kind good tool body tag extra resume field bound bad observed rc mode
  local -a faults
  for seat in worker pm; do
    kind=launch; good='--provider {provider} --model {model} --session-id {session_id}'; bound='provider model session_id'
    if [ "$seat" = pm ]; then kind=pm; good='--provider {provider} --model {model} {resume_args}'; bound='provider model'; fi
    routing_role_faults
    for body in "${faults[@]}"; do
      tag="${body%%|*}"; body="${body#*|}"; extra=''; resume=''
      [ "$seat" != pm ] || resume=' --continue'
      case "$tag" in
        extra-consumes-*) extra=' --skill' ;;
        extra-unknown-*) extra=' --unknown harmless' ;;
        resume-unknown-*) resume=' --continue --unknown' ;;
      esac
      routing_parameter_template "parameter-role-refused:$seat:$tag" "$kind" "fixture-pi $body {prompt}" continued 1 '' "$extra" "$resume"
    done
    for field in tool-prefix unknown-suffix extra-prefix; do
      body="--skill harmless -e 'literal extension' $good --unknown 'two words'"; extra=''
      [ "$field" != unknown-suffix ] || body="$good --unknown 'two words'"
      if [ "$field" = extra-prefix ]; then body="{extra_args} $body"; extra=' --skill harmless -e "literal extension" --no-tools'; fi
      for mode in fresh continued; do
        routing_parameter_template "parameter-role-legal:$seat:$field:$mode" "$kind" "fixture-pi $body {prompt}" "$mode" 0 "$bound" "$extra" ' --continue'
      done
    done
  done
  routing_resume_role_faults
  for bad in "${faults[@]}"; do
    rc=0; observed="$(TEAM_EXTRA_PI_ARGS=''; TEAM_PM_EXTRA_PI_ARGS=''; TEAM_PM_RESUME_ARGS="$bad"; team_pm_resume_args_guard 2>&1)" || rc=$?
    printf 'OBSERVE parameter-resume-role-refused:%s rc=%s value=%s\n' "$bad" "$rc" "$observed"
    check "parameter-resume-role-refused:$bad" eq "$rc" 1
  done
}
routing_role_probes() { # worker|pm
  local seat="$1" oldmap tag body mode before sid='' field tool good
  oldmap="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  run config set-task-model routine vendor/routine
  check "$seat-role-category-ready" eq "$RC" 0
  if [ "$seat" = worker ]; then
    run config set TEAM_AGENT_CMD '' --yes
    run config set TEAM_EXTRA_PI_ARGS '' --yes
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/deep/model:high --fresh
    check worker-role-assignment-ready eq "$RC" 0
    team_assignment_load dev; sid="${TEAM_ASSIGN[sid]}"; stop_fixture_seat dev
    good='--provider {provider} --model {model} --session-id {session_id}'
  else
    routing_fixture_tmux new-window -d -t routing-fixture -n role-anchor 'sleep 1200'
    stop_fixture_seat pm
    run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
    # config set 的前门拒收 `-` 开头的值：按既有夹具惯例用前导空格写入（读取侧 team_trim）。
    run config set TEAM_PM_RESUME_ARGS ' --continue' --yes
    (TEAM_PM_MODEL=vendor/pm:high; TEAM_PM_RESUME_ARGS=--continue; TEAM_PM_FRESH_LAUNCH=0; team_pm_metadata_publish fixture-role-control)
    cp -p "$STATE/pm-launch.env" "$TMP/role-pm-trusted"
    good='--provider {provider} --model {model} {resume_args}'
  fi
  local -a faults; routing_role_faults
  if [ "$seat" = pm ]; then
    (TEAM_PM_MODEL=vendor/pm:high; TEAM_PM_RESUME_ARGS=--continue; TEAM_PM_FRESH_LAUNCH=0; team_pm_metadata_publish fixture-role-control)
    cp -p "$STATE/pm-launch.env" "$TMP/role-pm-trusted"
  fi
  # Prefix tool data has a proved scalar role. Unknown options/literal quoted
  # data are a suffix after ALL protected groups, not guessed zero-arity flags.
  for field in tool-prefix unknown-suffix extra-prefix; do
    body="--skill harmless -e 'literal extension' $good --unknown 'two words'"
    [ "$field" != unknown-suffix ] || body="$good --unknown 'two words'"
    if [ "$field" = extra-prefix ]; then
      body="{extra_args} $body"
      if [ "$seat" = worker ]; then run config set TEAM_EXTRA_PI_ARGS ' --skill harmless -e "literal extension" --no-tools' --yes
      else run config set TEAM_PM_EXTRA_PI_ARGS ' --skill harmless -e "literal extension" --no-tools' --yes; fi
    fi
    if [ "$seat" = worker ]; then run config set TEAM_AGENT_CMD "$TMP/recording-pi $body {prompt}" --yes
    else run config set TEAM_PM_CMD "$TMP/recording-pi $body {prompt}" --yes; fi
    check "$seat-role-legal-config:$field" eq "$RC" 0
    for mode in preview launch fresh-preview fresh-launch; do
      [ "$seat" != pm ] || cp -p "$TMP/role-pm-trusted" "$STATE/pm-launch.env"
      before="$(routing_observable_snapshot)"
      if [ "$seat" = worker ]; then
        case "$mode" in preview) run dispatch dev T1 docs/team/tasks/T1-fixture.md --print ;; launch) run dispatch dev T1 docs/team/tasks/T1-fixture.md ;; fresh-preview) run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh --print ;; fresh-launch) run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh ;; esac
      else
        case "$mode" in preview) run up --print ;; launch) run up ;; fresh-preview) run up --fresh-pm --print ;; fresh-launch) run up --fresh-pm ;; esac
      fi
      check "$seat-role-legal:$field:$mode" eq "$RC" 0
      case "$mode" in
        *preview) check "$seat-role-legal-pure:$field:$mode" eq "$(routing_observable_snapshot)" "$before" ;;
        *)
          if [ "$seat" = worker ]; then
            team_assignment_load dev; sid="${TEAM_ASSIGN[sid]}"
            check "$seat-role-actual:$field:$mode" routing_identity_argv_check "$TMP/argv-jsonl" vendor deep/model:high "$sid" -
          else
            local continuation=--continue; [ "$mode" != fresh-launch ] || continuation=-
            check "$seat-role-actual:$field:$mode" routing_identity_argv_check "$TMP/argv-jsonl" vendor pm:high - "$continuation"
          fi
          if [ "$seat" = worker ]; then stop_fixture_seat dev; else stop_fixture_seat pm; fi ;;
      esac
    done
    if [ "$seat" = worker ]; then run config set TEAM_EXTRA_PI_ARGS '' --yes; else run config set TEAM_PM_EXTRA_PI_ARGS '' --yes; fi
  done
  local diagnostic
  for body in "${faults[@]}"; do
    tag="${body%%|*}"; body="${body#*|}"
    case "$seat:$tag" in
      worker:model:--skill|pm:provider:--skill) diagnostic='identity argv role unprovable: --skill needs one literal tool-data value' ;;
      worker:extra-unknown-before-model) diagnostic='identity argv role unprovable: unknown arity --unknown before protected --model' ;;
      pm:extra-unknown-before-resume) diagnostic='identity argv role unprovable: unknown arity --unknown before protected {resume_args}' ;;
      *) continue ;;
    esac
    if [ "$seat" = worker ]; then
      run config set TEAM_EXTRA_PI_ARGS '' --yes
      run config set TEAM_AGENT_CMD "$TMP/recording-pi $body {prompt}" --yes
      check "$seat-role-template-config:$tag" eq "$RC" 0
      [ "$RC" = 0 ] || return 1
      if [ "$tag" = extra-unknown-before-model ]; then
        run config set TEAM_EXTRA_PI_ARGS ' --unknown harmless' --yes
        check "$seat-role-extra-config:$tag" eq "$RC" 0
        [ "$RC" = 0 ] || return 1
        routing_refusal_observe worker-role worker-role "$tag" fresh-launch "$diagnostic" dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
      else
        routing_refusal_observe worker-role worker-role "$tag" launch "$diagnostic" dispatch dev T1 docs/team/tasks/T1-fixture.md
      fi
      stop_fixture_seat dev
      run config set TEAM_EXTRA_PI_ARGS '' --yes
    else
      run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
      run config set TEAM_PM_RESUME_ARGS ' --continue' --yes
      run config set TEAM_PM_CMD "$TMP/recording-pi $body {prompt}" --yes
      check "$seat-role-template-config:$tag" eq "$RC" 0
      [ "$RC" = 0 ] || return 1
      if [ "$tag" = extra-unknown-before-resume ]; then
        run config set TEAM_PM_EXTRA_PI_ARGS ' --unknown harmless' --yes
        check "$seat-role-extra-config:$tag" eq "$RC" 0
        [ "$RC" = 0 ] || return 1
        (TEAM_PM_MODEL=vendor/pm:high; TEAM_PM_RESUME_ARGS=--continue; TEAM_PM_FRESH_LAUNCH=0; TEAM_PM_SESSION_ID=''; team_pm_metadata_publish fixture-role-control)
        check "$seat-role-record:$tag" eq "$?" 0
        check "$seat-role-trusted:$tag" routing_pm_continuation_ready ' --continue'
        routing_refusal_observe pm-role pm-role "$tag" launch "$diagnostic" up
      else
        routing_refusal_observe pm-role pm-role "$tag" fresh-launch "$diagnostic" up --fresh-pm
      fi
      stop_fixture_seat pm
      run config set TEAM_PM_EXTRA_PI_ARGS '' --yes
      run config set TEAM_PM_RESUME_ARGS ' --continue' --yes
    fi
  done
  if [ "$seat" = worker ]; then run config set TEAM_AGENT_CMD '' --yes
  else run config set TEAM_PM_CMD '' --yes; run config set TEAM_PM_RESUME_ARGS '' --yes; fi
  run config set TEAM_TASK_MODELS "$oldmap" --yes
  check "$seat-role-policy-restored" eq "$RC" 0
}
routing_resume_role_probes() {
  local field bad mode diagnostic
  local -a faults
  for field in builtin custom; do
    if [ "$field" = builtin ]; then run config set TEAM_PM_CMD '' --yes
    else run config set TEAM_PM_CMD "$TMP/recording-pi --provider {provider} --model {model} {resume_args} {prompt}" --yes; fi
    check "pm-role-resume-template:$field" eq "$RC" 0
    [ "$RC" = 0 ] || return 1
    routing_resume_role_faults
    for bad in "${faults[@]}"; do
      case "$field:$bad" in
        'builtin:--skill --continue') mode=launch; diagnostic='identity argv role unprovable: --skill needs one literal tool-data value' ;;
        'custom:-e -c') mode=fresh-launch; diagnostic='identity argv role unprovable: -e needs one literal tool-data value' ;;
        *) continue ;;
      esac
      run config set TEAM_PM_RESUME_ARGS " $bad" --yes
      check "pm-role-resume-config:$field:$bad" eq "$RC" 0
      [ "$RC" = 0 ] || return 1
      (TEAM_PM_MODEL=vendor/pm:high; TEAM_PM_FRESH_LAUNCH=0; TEAM_PM_SESSION_ID=''; TEAM_PM_RESUME_ARGS="$bad"; team_pm_metadata_publish fixture-role-resume)
      check "pm-role-resume-record:$field:$bad" eq "$?" 0
      check "pm-role-resume-trusted:$field:$bad" routing_pm_continuation_ready "$bad"
      if [ "$mode" = launch ]; then
        routing_refusal_observe pm-role-resume pm-role-resume "$field:$bad" "$mode" "$diagnostic" up
      else
        routing_refusal_observe pm-role-resume pm-role-resume "$field:$bad" "$mode" "$diagnostic" up --fresh-pm
      fi
      stop_fixture_seat pm
    done
  done
  run config set TEAM_PM_RESUME_ARGS '' --yes
  run config set TEAM_PM_CMD '' --yes
}
routing_identity_argv_fields() { # <argv-jsonl>：最后一行的 argv 里真实的身份 selector 集合（逗号，规范顺序）
  python3 - "$@" <<'PY'
import json, sys
args = json.loads(open(sys.argv[1]).readlines()[-1])
found = set(); i = 0
while i < len(args):
    a = args[i]; i += 1
    if a in ('--provider', '--model', '-m', '--session-id', '--session', '-s'):
        key = {'--provider': 'provider', '--model': 'model', '-m': 'model',
               '--session-id': 'session_id', '--session': 'session_id', '-s': 'session_id'}[a]
        found.add(key); continue
    for opt, key in (('--provider=', 'provider'), ('--model=', 'model'), ('--session-id=', 'session_id'), ('--session=', 'session_id')):
        if a.startswith(opt):
            found.add(key); break
    else:
        if a.startswith('-m') and len(a) > 2: found.add('model')
        elif a.startswith('-s') and len(a) > 2: found.add('session_id')
print(','.join(f for f in ('provider', 'model', 'session_id') if f in found))
PY
}
routing_publication_probes() {
  # P228/R6（OBS1）：三态（全绑 / 只绑 model / 全不绑）—— 发布不得多于 argv 实际交付。
  #   ① 记录 identity_via == argv 里真实的身份 selector 集合（逐条对账，不是「包含」）
  #   ② 横幅/预览行只声明已交付的字段，未交付的显式点名
  #   ③ 同任务续跑对未交付身份仍如实拒绝（F5 的 guarded continuation 规则不许被这轮放松）
  local oldmap tag body sid before
  oldmap="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  # 本组自己建前提（如 pre-resume 组删过 routine，新选择必须是当前已映射类别）
  run config set TEAM_TASK_MODELS 'routine=vendor/routine analysis=vendor/analysis verify=vendor/verify' --yes
  check publication-map-ready eq "$RC" 0
  stop_fixture_seat dev
  run config set TEAM_AGENT_CMD '' --yes
  run config set TEAM_EXTRA_PI_ARGS '' --yes
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/deep/model:high --fresh
  check publication-setup-recorded eq "$RC" 0
  team_assignment_load dev; sid="${TEAM_ASSIGN[sid]:-missing}"; stop_fixture_seat dev
  local -a arms=('builtin|' 'all-bound|--provider {provider} --model {model} --session-id {session_id}' \
                 'model-only|--model {model}' 'opaque|--ask {prompt}')
  for body in "${arms[@]}"; do
    tag="${body%%|*}"; body="${body#*|}"
    if [ "$tag" = builtin ]; then run config set TEAM_AGENT_CMD '' --yes
    else run config set TEAM_AGENT_CMD "$TMP/recording-pi $body" --yes; fi
    check "publication-config:$tag" eq "$RC" 0
    before="$(routing_observable_snapshot)"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh --print
    check "publication-preview:$tag" eq "$RC" 0
    check "publication-preview-pure:$tag" eq "$(routing_observable_snapshot)" "$before"
    case "$tag" in
      builtin|all-bound)
        check "publication-preview-sid:$tag" contains "$OUT" 'sid='
        check "publication-preview-no-gap:$tag" bash -c '! [[ "$1" == *identity-delivery* ]]' _ "$OUT" ;;
      model-only)
        check "publication-preview-no-sid:$tag" bash -c '! [[ "$1" == *"sid="* ]]' _ "$OUT"
        check "publication-preview-gap:$tag" contains "$OUT" 'identity-delivery: 未交付 provider,session_id' ;;
      opaque)
        check "publication-preview-no-model:$tag" bash -c '! [[ "$1" == *"model="* ]]' _ "$OUT"
        check "publication-preview-gap:$tag" contains "$OUT" 'identity-delivery: 未交付 provider,model,session_id' ;;
    esac
    # 真启动：横幅里的身份声明只含已交付字段（与上面的 argv 对账）
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
    check "publication-launch:$tag" eq "$RC" 0
    team_assignment_load dev
    case "$tag" in
      builtin|all-bound)
        check "publication-record:$tag" eq "${TEAM_ASSIGN[identity_via]:-}" 'provider,model,session_id'
        check "publication-claim-full:$tag" contains "$OUT" "provider=vendor model=${TEAM_ASSIGN[model]#*/} session=${TEAM_ASSIGN[sid]}" ;;
      model-only)
        check "publication-record:$tag" eq "${TEAM_ASSIGN[identity_via]:-}" 'model'
        check "publication-claim-gap:$tag" contains "$OUT" '模板未交付 provider,session_id'
        check "publication-claim-no-provider:$tag" bash -c '! [[ "$1" == *"provider=vendor"* ]]' _ "$OUT" ;;
      opaque)
        check "publication-record:$tag" eq "${TEAM_ASSIGN[identity_via]:-}" ''
        check "publication-claim-gap:$tag" contains "$OUT" '模板未交付 provider,model,session_id'
        check "publication-claim-no-model:$tag" bash -c '! [[ "$1" == *"model=${TEAM_ASSIGN[model]#*/}"* ]]' _ "$OUT" ;;
    esac
    check "publication-record-equals-argv:$tag" eq "$(routing_identity_argv_fields "$TMP/argv-jsonl")" "${TEAM_ASSIGN[identity_via]:-}"
    stop_fixture_seat dev
  done
  # 读侧：模板没把模型交给 CLI 的席位，ps 列不得把它当「在跑的模型」
  run config set TEAM_AGENT_CMD "$TMP/recording-pi --ask {prompt}" --yes
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
  check publication-reader-launch eq "$RC" 0
  check publication-reader-unavailable contains "$(team_agent_session_cols dev)" '（未交付）'
  stop_fixture_seat dev
  # 同任务续跑（未 --fresh）对未交付身份如实拒绝：模型只绑一半 → 不是完整 Pi 身份
  run config set TEAM_AGENT_CMD "$TMP/recording-pi --ask {prompt}" --yes
  run dispatch dev T1 docs/team/tasks/T1-fixture.md
  check publication-continuation-refused eq "$RC" 1
  check publication-continuation-named contains "$OUT" 'guarded continuation'
  stop_fixture_seat dev
  run config set TEAM_AGENT_CMD '' --yes
  run config set TEAM_TASK_MODELS "$oldmap" --yes
  check publication-policy-restored eq "$RC" 0
}
