#!/usr/bin/env bash
# Shared test-only fixture constructors. Callers must provide an owned temp root.
routing_fixture_record() { # state seat task worktree brief model sid [origin] [time] [category] [branch]
  local state="$1" seat="$2" task="$3" wt="$4" brief="$5" model="$6" sid="$7" origin="${8:-policy}" started="${9:-2026-10-09T00:00:00Z}"
  local category="${10:-analysis}" branch="${11:-task/$task-fixture}"
  mkdir -p "$state"
  printf 'assignment_version=1\ntask=%s\ntaskfile=%s\ncategory=%s\nbranch=%s\nworktree=%s\nwindow=%s\nseat=%s\nmodel=%s\nselected_via=%s\nlaunch_via=assignment\nsid=%s\nlaunch_nonce=fixture-nonce\nstarted=%s\nsid_bytes=0\nmode=continued\n' "$task" "$brief" "$category" "$branch" "$wt" "$seat" "$seat" "$model" "$origin" "$sid" "$started" > "$state/$seat.env"
}
routing_fixture_config() { # destination template session roster
  mkdir -p "$(dirname "$1")"
  python3 - "$@" <<'PY'
import pathlib,re,sys
out,template,session,agents=sys.argv[1:]
s=pathlib.Path(template).read_text()
values={'PROJECT':pathlib.Path(out).parents[2].name,'SESSION':session,'PM_WINDOW':'pm','AGENTS':agents,'GATES':'true','DOCS_DIR':'docs/team','VCS':'local','DETECTED_VCS':'local','SKILL_DIR':'fixture-only','TODAY':'2026-10-09'}
for k,v in values.items(): s=s.replace('{{'+k+'}}',v)
# P235: the template carries empty model-policy keys; the fixture fills both.
s=re.sub(r'^TEAM_TASK_MODELS=.*$', 'TEAM_TASK_MODELS="routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k"', s, flags=re.M)
s=re.sub(r'^TEAM_PM_MODEL=.*$', 'TEAM_PM_MODEL="deepseek/deepseek-flash"', s, flags=re.M)
# P261: the template's shape number is a render placeholder too; the fixture declares the shape it builds
# (same style as the two model keys above), otherwise the literal '{{CONFIG_VERSION}}' would read as a
# non-integer shape marker and the startup transaction would refuse the fixture.
s=re.sub(r'^TEAM_CONFIG_VERSION=.*$', 'TEAM_CONFIG_VERSION="2"', s, flags=re.M)
pathlib.Path(out).write_text(s)
PY
}
# S1 deliberately does not consume the S3 template. Explicit policy upgrade is fixture-only.
routing_fixture_upgrade() { # CLI project
  (cd "$2" && bash "$1" config upgrade-models --task-models 'routine=vendor/routine analysis=vendor/analysis verify=vendor/verify' --pm-model vendor/pm --yes) >/dev/null
}
