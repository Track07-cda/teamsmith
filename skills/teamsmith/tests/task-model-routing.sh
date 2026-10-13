#!/usr/bin/env bash
# P228: isolated policy/identity front door. Recording agents prove argv/state, not providers.
set -uo pipefail
here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$here/lib/tmp-root.sh"
source "$here/lib/model-policy.sh"
source "$here/lib/model-routing-boundary.sh"
source "$here/lib/model-routing-expansion.sh"
source "$here/lib/model-routing-roles.sh"
source "$here/lib/tmux-iso.sh"
TREE="${TEAM_ROUTING_TREE:-$(cd "$here/../../.." && pwd)}"
EVIDENCE="${TEAM_ROUTING_EVIDENCE:-}"
SELECT='policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary'
while [ $# -gt 0 ]; do
  case "$1" in --select) SELECT="${2:?}"; shift 2 ;; --flip) SELECT=flip; shift ;; *) printf 'unknown option: %s\n' "$1"; exit 2 ;; esac
 done
for group in ${SELECT//,/ }; do
  case "$group" in policy|machine|config|upgrade|dispatch|resume|transaction|limits|preview|sid-readers|pm|boundary|init|flip) ;; *) printf 'unknown group: %s\n' "$group"; exit 2 ;; esac
 done
while IFS='=' read -r k _; do case "$k" in TEAM_*) unset "$k" 2>/dev/null || true ;; esac; done < <(env)
TMP="$(tmp_root_create task-model-routing)" || exit 3
# Never inherit the shared runtime shim; a private wrapper must exec a real binary, not itself.
IFS=: read -r -a path_parts <<< "$PATH"; clean_path=''
for part in "${path_parts[@]}"; do case "$part" in */scripts/shim) ;; *) clean_path="${clean_path:+$clean_path:}$part" ;; esac; done
export PATH="$clean_path"
unset TMUX TMUX_PANE
export HOME="$TMP/home"; mkdir -p "$HOME"
PASS=0 FAIL=0; LIVE_SOCKET=''
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ -n "$LIVE_SOCKET" ] && tmux_iso_guard_soft routing cleanup --tmpdir "$TMUX_TMPDIR" --sock-name "$LIVE_SOCKET" --own-root "$TMP"; then
    tmux -L "$LIVE_SOCKET" kill-server 2>/dev/null || true
  fi
  if [ -n "$EVIDENCE" ]; then
    mkdir -p "$EVIDENCE"
    cp -a "$TMP" "$EVIDENCE/$(basename "$TMP")" || printf 'evidence export failed: %s\n' "$EVIDENCE" >&2
    printf 'evidence: %s/%s\n' "$EVIDENCE" "$(basename "$TMP")"
  fi
  tmp_root_reap_all
}
trap cleanup EXIT
has() { case ",$SELECT," in *",$1,"*) return 0 ;; esac; return 1; }
check() { local name="$1"; shift; if "$@"; then PASS=$((PASS+1)); printf 'PASS %s\n' "$name"; else FAIL=$((FAIL+1)); printf 'FAIL %s\n' "$name"; fi; }
eq() { [ "$1" = "$2" ]; }
contains() { [[ "$1" == *"$2"* ]]; }
sha() { if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else printf absent; fi; }
CLI="$TREE/skills/teamsmith/scripts/team"
SKILL="$TREE/skills/teamsmith"
REPO="$TMP/repo"; mkdir -p "$REPO/.pi/team" "$REPO/docs/team/tasks" "$REPO/docs/team/threads"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.name fixture; git -C "$REPO" config user.email fixture@example.invalid
printf '# fixture\n' > "$REPO/README.md"; git -C "$REPO" add README.md; git -C "$REPO" commit -qm fixture
cat > "$REPO/.pi/team/config.sh" <<EOF
TEAM_PROJECT='routing-fixture'
TEAM_SESSION='routing-fixture'
TEAM_PM_WINDOW='pm'
TEAM_DOCS_DIR='docs/team'
TEAM_AGENTS='dev verify'
TEAM_TASK_MODELS='routine=vendor/routine analysis=vendor/analysis verify=vendor/verify custom=vendor/custom'
TEAM_PM_MODEL='vendor/pm:high'
TEAM_WORKTREES_DIR='.worktrees'
TEAM_VCS='local'
TEAM_GATES='true'
TEAM_MIN_FREE_SWAP_MB=0
TEAM_MIN_TOTAL_MB=0
TEAM_MIN_AVAIL_MB=0
TEAM_TMP_MIN_FREE_MB=0
TEAM_TMP_MIN_FREE_INODES=0
TEAM_MODEL_LIMITS=''
TEAM_PI_BIN='$TMP/recording-pi'
EOF
cat > "$TMP/recording-pi" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$@" >> '$TMP/argv.log'
python3 -c 'import json,sys; open(sys.argv[1],"a").write(json.dumps(sys.argv[2:])+chr(10))' '$TMP/argv-jsonl' "\$@"
[ ! -f '$TMP/fail-launch' ] || exit 9
sleep 180
EOF
chmod +x "$TMP/recording-pi"
effect_snapshot() {
  [ -n "$EVIDENCE" ] || return 0
  { printf '\n%s\n' "$1"; sha256sum "$REPO/.pi/team/config.sh" "$REPO/docs/team/BOARD.md" 2>/dev/null || true
    [ ! -d "$REPO/.pi/team/state" ] || find "$REPO/.pi/team/state" -maxdepth 1 -type f -print0 | sort -z | xargs -0 -r sha256sum
  } >> "$TMP/effect-hashes.log"
}
run() { local rc=0; effect_snapshot "before $*"; OUT="$(cd "$REPO" && timeout 35 bash "$CLI" "$@" 2>&1)" || rc=$?; RC="$rc"; printf 'command=%q ' "$@"; printf '\nrc=%s\n%s\n' "$RC" "$OUT"; effect_snapshot "after rc=$RC $*"; }
STATE="$REPO/.pi/team/state"; CONFIG="$REPO/.pi/team/config.sh"
# Direct library fixtures are still isolated; never load real project state/config.
export TEAM_ROOT="$REPO" TEAM_MAIN_ROOT="$REPO" TEAM_STATE_DIR="$STATE" TEAM_CONFIG="$CONFIG" TEAM_CLI=team TEAM_SKILL_DIR="$SKILL" TEAM_DOCS_ABS="$REPO/docs/team" TEAM_DOCS_DIR=docs/team TEAM_SESSION=routing-fixture TEAM_PM_WINDOW=pm TEAM_AGENTS='dev verify' TEAM_WORKTREES_DIR=.worktrees TEAM_PI_AGENT_DIR="$HOME/.pi/agent"
source "$SKILL/scripts/lib/common.sh"
for lib in "$SKILL"/scripts/lib/cmd-*.sh; do source "$lib"; done
team_load_config
check isolation-root eq "$TEAM_MAIN_ROOT" "$REPO"
check isolation-home contains "$HOME" "$TMP"
if has policy; then
  for map in '' 'routine=x/y analysis=x/z verify=x/v routine=a/b' 'routine=x/y analysis=x/z verify=' 'Routine=x/y analysis=x/z verify=x/v' 'routine=a//b analysis=x/z verify=x/v'; do
    rc=0; team_task_map_violation "$map" || rc=$?; check "policy-invalid:$map" eq "$rc" 1
  done
  check policy-minimum-analysis-verify team_task_map_violation 'analysis=provider/deep/id:high verify=provider/verify'
  check policy-custom-category team_task_map_violation 'custom=provider/name routine=p/r analysis=p/a verify=p/v'
  # F6（真缺陷）：analysis/verify 不是引擎必备类别 —— 合同写「Initial routine/analysis/verify are examples, not
  # mandatory engine categories」（memory-and-deps）与「Initial examples … do not close the engine vocabulary」
  # （dispatch delta）。旧实现无条件要求这两个名字，于是项目自定义词汇的整映射被拒。唯一非法的映射是空映射。
  check policy-custom-vocabulary-only team_task_map_violation 'maintenance=vendor/light'
  check policy-custom-vocabulary-partial team_task_map_violation 'routine=x/y analysis=x/z'
  check policy-drop-analysis-verify team_task_map_violation 'routine=vendor/routine maintenance=vendor/light'
  check policy-drop-routine-analysis team_task_map_violation 'verify=vendor/verify maintenance=vendor/light'
  check policy-custom-vocabulary-multi team_task_map_violation 'ops=vendor/light audit=vendor/audit:high release=vendor/release'
  before="$(sha "$CONFIG")"; run config set TEAM_DEFAULT_MODEL p/old --yes; check retired-key eq "$RC" 5
  run config set-agent-model dev p/old; check retired-command eq "$RC" 5
  run add-agent dev --model p/old; check retired-register-option eq "$RC" 2
  check retired-no-write eq "$(sha "$CONFIG")" "$before"
  run config set-task-model custom vendor/custom:high
  printf '| ID | 任务 | Agent | 分支 | 依赖 | 状态 |\n|---|---|---|---|---|---|\n' > "$REPO/docs/team/BOARD.md"
  run task G1 --title generated --slug generated --category custom --agent dev
  printf 'generator rc=%s\n%s\n' "$RC" "$OUT" > "$TMP/generator-result.log"
  check generated-mapped-category eq "$RC" 0
  check generated-category-header eq "$(grep -cx 'category: custom' "$REPO/docs/team/tasks/G1-generated.md" || true)" 1
  for fault in missing malformed unmapped; do
    case "$fault" in
      missing) run task G2 --title refused --slug refused ;;
      malformed) run task G2 --title refused --slug refused --category Bad/token ;;
      unmapped) run task G2 --title refused --slug refused --category unmapped ;;
    esac
    check "generation-refused:$fault" bash -c '[ "$1" != 0 ]' _ "$RC"
    check "generation-no-file:$fault" bash -c '! test -e "$1"' _ "$REPO/docs/team/tasks/G2-refused.md"
  done
fi
if has machine; then
  run config list --json
  check machine-json python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert "seats" not in d["models"] and "default" not in d["models"]; assert d["models"]["policy"]["pm"]=="vendor/pm:high"; assert all(x["diagnostic"] for x in d["models"]["assignments"]); assert all(not x["model"] for x in d["models"]["assignments"]); assert [k for k in d["keys"] if k["name"]=="TEAM_TASK_MODELS"][0]["group"]=="task-model"' "$OUT"
fi
if has config; then
  before="$(sha "$CONFIG")"; run config set-task-model custom openrouter/amazon/nova-lite:high --dry-run; check map-preview eq "$RC" 0; check map-preview-pure eq "$(sha "$CONFIG")" "$before"
  run config set-task-model custom openrouter/amazon/nova-lite:high; check map-upsert eq "$RC" 0
  run config set-task-model broken a//b; check map-invalid eq "$RC" 4
  fp="$(sha "$CONFIG")"; run config set-task-model custom p/one --fingerprint "$fp"; check map-cas-first eq "$RC" 0
  run config set-task-model custom p/two --fingerprint "$fp"; check map-cas-loser eq "$RC" 3
  fp="$(sha "$CONFIG")"
  (cd "$REPO" && bash "$CLI" config set-task-model race-a p/a --fingerprint "$fp" > "$TMP/race-a.log" 2>&1; printf '%s' "$?" > "$TMP/race-a.rc") & p1=$!
  (cd "$REPO" && bash "$CLI" config set-task-model race-b p/b --fingerprint "$fp" > "$TMP/race-b.log" 2>&1; printf '%s' "$?" > "$TMP/race-b.rc") & p2=$!
  wait "$p1" "$p2"
  check simultaneous-map-cas python3 -c 'import pathlib,sys; assert sorted(pathlib.Path(x).read_text() for x in sys.argv[1:])==["0","3"]' "$TMP/race-a.rc" "$TMP/race-b.rc"
  # F6：写侧整映射（不含 analysis/verify）+ 读侧同一份映射；空映射仍是一个真拒绝。
  map_fixture="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  run config set TEAM_TASK_MODELS 'maintenance=vendor/light ops=vendor/ops:high' --yes
  check map-custom-vocabulary-write eq "$RC" 0
  check map-custom-vocabulary-line eq "$(grep -c "^TEAM_TASK_MODELS='maintenance=vendor/light ops=vendor/ops:high'\$" "$CONFIG" || true)" 1
  run config list --json
  check map-custom-vocabulary-read python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert [c["category"] for c in d["models"]["policy"]["categories"]]==["maintenance","ops"], d["models"]["policy"]' "$OUT"
  run config set-task-model release vendor/release --yes
  check map-custom-vocabulary-upsert eq "$RC" 0
  check map-custom-vocabulary-upsert-line eq "$(grep -c "^TEAM_TASK_MODELS='maintenance=vendor/light ops=vendor/ops:high release=vendor/release'\$" "$CONFIG" || true)" 1
  run config set TEAM_TASK_MODELS '' --yes
  check map-empty-refused eq "$RC" 4
  run config set TEAM_TASK_MODELS "$map_fixture" --yes
  check map-fixture-restored eq "$RC" 0
  payload="literal\$(touch '$TMP/PWNED')"
  run config set TEAM_GATES "$payload" --yes
  check writer-literal-payload-accepted eq "$RC" 0
  run config list --json
  check writer-payload-does-not-expand bash -c '[ ! -e "$1" ]' _ "$TMP/PWNED"
  check writer-literal-roundtrip eq "$(bash --noprofile --norc -c 'source "$1"; printf "%s" "$TEAM_GATES"' _ "$CONFIG")" "$payload"
  run config set TEAM_GATES true --yes
fi
if has upgrade; then
  cp -p "$CONFIG" "$TMP/new-policy"
  printf "TEAM_DEFAULT_MODEL='' # retired note\nTEAM_AGENT_MODELS='dev=p/old'\n" >> "$CONFIG"
  before="$(sha "$CONFIG")"; audit="$(sha "$STATE/config.log")"
  run config upgrade-models --task-models 'routine=p/r analysis=p/a verify=p/v' --pm-model p/pm
  check upgrade-preview eq "$RC" 0; check upgrade-preview-config eq "$(sha "$CONFIG")" "$before"; check upgrade-preview-audit eq "$(sha "$STATE/config.log")" "$audit"
  run config upgrade-models --task-models 'analysis=p/a verify=p/v' --pm-model p/pm --yes
  check upgrade-commit eq "$RC" 0
  check upgrade-retired-removed bash -c '! grep -Eq "^TEAM_(DEFAULT_MODEL|AGENT_MODELS)=" "$1" && grep -q "retired note" "$1"' _ "$CONFIG"
  for shape in 'export TEAM_DEFAULT_MODEL="x/y"' 'TEAM_DEFAULT_MODEL=$(printf x/y)' 'TEAM_DEFAULT_MODEL="x/y"; echo nope' 'if true; then TEAM_DEFAULT_MODEL="x/y"; fi' 'TEAM_DEFAULT_MODEL="x/y"\nTEAM_DEFAULT_MODEL="x/z"' 'TEAM_DEFAULT_MODEL="x/y\nx/z"'; do
    cp -p "$TMP/new-policy" "$CONFIG"; printf '%b\n' "$shape" >> "$CONFIG"; before="$(sha "$CONFIG")"
    run config upgrade-models --task-models 'analysis=p/a verify=p/v' --pm-model p/pm --yes
    check "upgrade-refuse:$shape" eq "$RC" 5; check "upgrade-no-write:$shape" eq "$(sha "$CONFIG")" "$before"
  done
  cp -p "$TMP/new-policy" "$CONFIG"
  upgrade_fault() (
    kind="$1"
    printf "TEAM_DEFAULT_MODEL='p/old'\nTEAM_AGENT_MODELS='dev=p/old'\n" >> "$CONFIG"
    old="$(sha "$CONFIG")"; expected=6; result=write-error
    # Alias the trusted loaded function, not config data, so early field writes remain real.
    definition="$(declare -f team_config_set_in_file)"
    eval "${definition/team_config_set_in_file /p228_original_set_in_file }"
    case "$kind" in
      alloc) mktemp() { return 1; } ;;
      copy) cp() { return 1; } ;;
      render) team_config_set_in_file() { [ "$2" != TEAM_PM_MODEL ] || return 1; p228_original_set_in_file "$@"; } ;;
      syntax) bash() { [ "${1:-}" != -n ] || return 1; command bash "$@"; } ;;
      rename) mv() { return 1; } ;;
      late-cas)
        expected=3; result=conflict
        team_config_set_in_file() {
          p228_original_set_in_file "$@" || return
          [ "$2" != TEAM_PM_MODEL ] || printf '# retained concurrent writer\n' >> "$CONFIG"
        } ;;
      stale-cas) expected=3; result=conflict; printf '# retained concurrent writer\n' >> "$CONFIG" ;;
    esac
    rc=0
    team_config_upgrade_transaction "$CONFIG" 'analysis=p/a verify=p/v' p/pm 0 "$old" "p228-$kind" || rc=$?
    printf 'upgrade-fault=%s rc=%s expected=%s\n' "$kind" "$rc" "$expected"
    [ "$rc" = "$expected" ] || return 1
    case "$kind" in
      *cas) grep -q '^# retained concurrent writer$' "$CONFIG" && grep -q '^TEAM_DEFAULT_MODEL=' "$CONFIG" || return 1 ;;
      *) [ "$(sha "$CONFIG")" = "$old" ] || return 1 ;;
    esac
    [ "$(grep -c "result=$result actor=p228-$kind " "$STATE/config.log" || true)" = 1 ] || return 1
    [ "$(find "$(dirname "$CONFIG")" -maxdepth 1 -name '.model-upgrade.*' | wc -l)" = 0 ]
  )
  for fault in alloc copy render syntax rename stale-cas late-cas; do
    cp -p "$TMP/new-policy" "$CONFIG"
    check "upgrade-whole-file-fault:$fault" upgrade_fault "$fault"
  done
  cp -p "$TMP/new-policy" "$CONFIG"
  for fault in missing-map missing-pm invalid-pm invalid-map; do
    before="$(sha "$CONFIG")"
    case "$fault" in
      missing-map) run config upgrade-models --pm-model p/pm --yes ;;
      missing-pm) run config upgrade-models --task-models 'analysis=p/a' --yes ;;
      invalid-pm) run config upgrade-models --task-models 'analysis=p/a' --pm-model p//pm --yes ;;
      invalid-map) run config upgrade-models --task-models 'analysis=p/a analysis=p/b' --pm-model p/pm --yes ;;
    esac
    check "upgrade-input-refused:$fault" bash -c '[ "$1" != 0 ]' _ "$RC"
    check "upgrade-input-pure:$fault" eq "$(sha "$CONFIG")" "$before"
  done
  printf "TEAM_DEFAULT_MODEL='p/old'\nTEAM_AGENT_MODELS='dev=p/old'\nS1_UNRELATED_FINAL='keep # no newline'" >> "$CONFIG"
  run config upgrade-models --task-models 'analysis=p/a verify=p/v' --pm-model p/pm --yes
  check upgrade-no-final-newline-commit eq "$RC" 0
  check upgrade-no-final-newline-preserved python3 -c 'import pathlib,sys; b=pathlib.Path(sys.argv[1]).read_bytes(); assert b.endswith(b"S1_UNRELATED_FINAL=\x27keep # no newline\x27") and not b.endswith(b"\n")' "$CONFIG"
  cp -p "$TMP/new-policy" "$CONFIG"
  upgrade_audit_unwritable() (
    TEAM_STATE_DIR="$TMP/audit-unwritable"; mkdir -p "$TEAM_STATE_DIR/config.log"
    rc=0
    team_config_upgrade_transaction "$CONFIG" 'analysis=p/a verify=p/v' p/pm 0 '' p228-audit-unwritable > "$TMP/upgrade-audit-unwritable.log" 2>&1 || rc=$?
    [ "$rc" = 0 ] && bash -n "$CONFIG" &&
      grep -q 'TEAM_PM_MODEL=.*p/pm' "$CONFIG" && grep -Eqi 'audit|审计' "$TMP/upgrade-audit-unwritable.log"
  )
  check upgrade-audit-unwritable-honest-committed-result upgrade_audit_unwritable
  cp -p "$TMP/new-policy" "$CONFIG"
  upgrade_concurrent_readers() (
    printf "TEAM_DEFAULT_MODEL='p/old'\nTEAM_AGENT_MODELS='dev=p/old'\n" >> "$CONFIG"
    old="$(sha "$CONFIG")"; failed=0
    old_map="$(bash --noprofile --norc -c 'source "$1"; printf "%s" "$TEAM_TASK_MODELS"' _ "$CONFIG")"
    old_pm="$(bash --noprofile --norc -c 'source "$1"; printf "%s" "$TEAM_PM_MODEL"' _ "$CONFIG")"
    definition="$(declare -f team_config_set_in_file)"
    eval "${definition/team_config_set_in_file /p228_original_set_in_file }"
    team_config_set_in_file() {
      p228_original_set_in_file "$@" || return
      if [ "$2" = TEAM_TASK_MODELS ]; then
        touch "$TMP/upgrade-reader-ready"
        for ((j=0; j<400; j++)); do
          [ ! -f "$TMP/upgrade-reader-release" ] || return 0
          sleep .05
        done
        return 1
      fi
    }
    (team_with_lock "config:$CONFIG" team_config_upgrade_transaction "$CONFIG" 'analysis=p/a verify=p/v' p/pm 0 '' p228-readers > "$TMP/upgrade-readers-writer.log" 2>&1) & writer=$!
    for ((j=0; j<200; j++)); do [ ! -f "$TMP/upgrade-reader-ready" ] || break; sleep .05; done
    [ -f "$TMP/upgrade-reader-ready" ] || failed=1
    for ((j=0; j<10; j++)); do
      [ "$(sha "$CONFIG")" = "$old" ] && bash -n "$CONFIG" || failed=1
      bash --noprofile --norc -c 'source "$1"; [ "$TEAM_DEFAULT_MODEL" = p/old ] && [ "$TEAM_PM_MODEL" = "$3" ] && [ "$TEAM_TASK_MODELS" = "$2" ]' _ "$CONFIG" "$old_map" "$old_pm" || failed=1
    done
    touch "$TMP/upgrade-reader-release"
    wait "$writer" || failed=1
    bash --noprofile --norc -c 'source "$1"; [ "${TEAM_DEFAULT_MODEL+x}" != x ] && [ "${TEAM_AGENT_MODELS+x}" != x ] && [ "$TEAM_PM_MODEL" = p/pm ] && [ "$TEAM_TASK_MODELS" = "analysis=p/a verify=p/v" ]' _ "$CONFIG" || failed=1
    [ "$failed" = 0 ]
  )
  check upgrade-readers-wholly-old-before-rename-new-after upgrade_concurrent_readers
  cp -p "$TMP/new-policy" "$CONFIG"
  # F6：升级（现有的迁移/种子入口）也接受自定义词汇整映射，并把未交付的类别报给读侧
  printf "TEAM_DEFAULT_MODEL='p/old'\nTEAM_AGENT_MODELS='dev=p/old'\n" >> "$CONFIG"
  run config upgrade-models --task-models 'ops=vendor/ops audit=vendor/audit:high' --pm-model p/pm --yes
  check upgrade-custom-vocabulary eq "$RC" 0
  check upgrade-custom-vocabulary-line eq "$(grep -c "^TEAM_TASK_MODELS='ops=vendor/ops audit=vendor/audit:high'\$" "$CONFIG" || true)" 1
  run config list --json
  check upgrade-custom-vocabulary-read python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert [c["category"] for c in d["models"]["policy"]["categories"]]==["ops","audit"], d["models"]["policy"]' "$OUT"
  cp -p "$TMP/new-policy" "$CONFIG"
fi
brief() { cat > "$REPO/docs/team/tasks/$1-fixture.md" <<EOF
# $1 · fixture
agent: $2
phase: apply
category: ${3:-routine}
change: -
anchor: none (infra) — isolated recording fixture
branch: task/$1-fixture
## Scope
No real provider or project state.
EOF
}
brief T1 dev routine; brief T2 verify routine
mkdir -p "$REPO/.worktrees"
git -C "$REPO" worktree add -qb task/T1-fixture "$REPO/.worktrees/dev"
git -C "$REPO" worktree add -qb task/T2-fixture "$REPO/.worktrees/verify"
printf '| ID | 任务 | Agent | 分支 | 依赖 | 状态 |\n|---|---|---|---|---|---|\n| T1 | fixture | dev | task/T1-fixture | - | todo |\n| T2 | fixture | verify | task/T2-fixture | - | todo |\n' > "$REPO/docs/team/BOARD.md"
if has preview || has dispatch || has resume || has transaction || has limits || has boundary; then
  # Private socket bound shim; cleanup never reaches the shared server.
  LIVE_SOCKET="routing-${BASHPID}-${RANDOM}"
  export TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR" "$TMP/bin"
  REAL_TMUX="$(type -P tmux)"
  printf '#!/usr/bin/env bash\nexec %q -L %q "$@"\n' "$REAL_TMUX" "$LIVE_SOCKET" > "$TMP/bin/tmux"; chmod +x "$TMP/bin/tmux"
  export PATH="$TMP/bin:$PATH"
  tmux_iso_require routing launch --tmpdir "$TMUX_TMPDIR" --sock-name "$LIVE_SOCKET" --own-root "$TMP"
  before="$(sha "$STATE/dev.env")"; board="$(sha "$REPO/docs/team/BOARD.md")"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
  check preview-success eq "$RC" 0; check preview-no-assignment eq "$(sha "$STATE/dev.env")" "$before"; check preview-no-board eq "$(sha "$REPO/docs/team/BOARD.md")" "$board"
  check preview-no-prompt bash -c '! test -f "$1/prompt-dev-T1.txt" && ! test -f "$1/dev.pending"' _ "$STATE"
  check preview-no-session bash -c '! tmux -L "$1" has-session 2>/dev/null' _ "$LIVE_SOCKET"
  cp -p "$REPO/docs/team/tasks/T1-fixture.md" "$TMP/legal-brief"
  for fault in missing blank duplicate malformed explore propose verify; do
    cp -p "$TMP/legal-brief" "$REPO/docs/team/tasks/T1-fixture.md"
    case "$fault" in
      missing) sed -i '/^category:/d' "$REPO/docs/team/tasks/T1-fixture.md" ;;
      blank) sed -i 's/^category:.*/category: /' "$REPO/docs/team/tasks/T1-fixture.md" ;;
      duplicate) printf 'category: analysis\n' >> "$REPO/docs/team/tasks/T1-fixture.md" ;;
      malformed) sed -i 's/^category:.*/category: Bad\/token/' "$REPO/docs/team/tasks/T1-fixture.md" ;;
      *) sed -i "s/^phase:.*/phase: $fault/" "$REPO/docs/team/tasks/T1-fixture.md" ;;
    esac
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:high --force --print
    case "$fault" in explore|propose|verify) expected=0 ;; *) expected=1 ;; esac
    check "category-explicit-phase-independent:$fault" eq "$RC" "$expected"
    if [ "$expected" = 0 ]; then check "phase-does-not-infer-category:$fault" contains "$OUT" 'category=routine'; fi
    check "category-fault-record-pure:$fault" eq "$(sha "$STATE/dev.env")" "$before"
    check "category-fault-board-pure:$fault" eq "$(sha "$REPO/docs/team/BOARD.md")" "$board"
  done
  cp -p "$TMP/legal-brief" "$REPO/docs/team/tasks/T1-fixture.md"
  brief T2 verify unmapped
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --force --print
  check new-unmapped-category-override-refused eq "$RC" 1
  check unmapped-override-no-board eq "$(sha "$REPO/docs/team/BOARD.md")" "$board"
  check unmapped-override-no-assignment bash -c '! test -f "$1/verify.env" && ! test -f "$1/prompt-verify-T2.md"' _ "$STATE"
  # F6：同一套守卫在**自定义词汇**下也成立 —— 新选择只要求「类别在当前映射里」，映射里没写的仍拒绝。
  # 任务/分支/工作树仍用本组的 T1 夹具（不碰工作树身份），只换类别。
  map_fixture="$(team_config_file_value "$CONFIG" TEAM_TASK_MODELS)"
  run config set TEAM_TASK_MODELS 'maintenance=vendor/light' --yes
  check new-selection-custom-map-ready eq "$RC" 0
  sed -i 's/^category:.*/category: maintenance/' "$REPO/docs/team/tasks/T1-fixture.md"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
  check new-selection-custom-vocabulary eq "$RC" 0
  check new-selection-custom-vocabulary-model contains "$OUT" 'model=vendor/light'
  sed -i 's/^category:.*/category: ops/' "$REPO/docs/team/tasks/T1-fixture.md"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
  check new-selection-custom-vocabulary-unmapped-refused eq "$RC" 1
  check new-selection-custom-vocabulary-unmapped-reason contains "$OUT" 'category 未映射：ops'
  check new-selection-custom-vocabulary-no-assignment bash -c '! test -f "$1/dev.pending" && ! test -f "$1/dev.env"' _ "$STATE"
  cp -p "$TMP/legal-brief" "$REPO/docs/team/tasks/T1-fixture.md"
  run config set TEAM_TASK_MODELS "$map_fixture" --yes
  check new-selection-custom-map-restored eq "$RC" 0
  brief T2 verify routine
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:high --fresh
  check first-recorded-launch eq "$RC" 0
  check first-complete-record team_assignment_load dev
  SID_A="${TEAM_ASSIGN[sid]:-missing}"
  check argv-full-suffix grep -Fxq strong:high "$TMP/argv.log"
  if has resume; then
    tmux kill-window -t routing-fixture:dev
    cp -p "$STATE/dev.env" "$TMP/trusted-assignment"
    argv_before="$(sha "$TMP/argv.log")"
    for fault in missing malformed task_file category worktree branch; do
      cp -p "$TMP/trusted-assignment" "$STATE/dev.env"
      case "$fault" in
        missing) rm "$STATE/dev.env" ;;
        malformed) sed -i 's/^assignment_version=.*/assignment_version=broken/' "$STATE/dev.env" ;;
        task_file) sed -i "s|^taskfile=.*|taskfile=$REPO/docs/team/tasks/T2-fixture.md|" "$STATE/dev.env" ;;
        category) sed -i 's/^category=.*/category=analysis/' "$STATE/dev.env" ;;
        worktree) sed -i "s|^worktree=.*|worktree=$REPO/.worktrees/verify|" "$STATE/dev.env" ;;
        branch) sed -i 's|^branch=.*|branch=task/T2-fixture|' "$STATE/dev.env" ;;
      esac
      damaged="$(sha "$STATE/dev.env")"
      run resume --agent dev --dry-run
      check "untrusted-recovery-refused:$fault" eq "$RC" 1
      check "untrusted-recovery-record-pure:$fault" eq "$(sha "$STATE/dev.env")" "$damaged"
      check "untrusted-recovery-no-launch:$fault" eq "$(sha "$TMP/argv.log")" "$argv_before"
    done
    cp -p "$TMP/trusted-assignment" "$STATE/dev.env"
    run config set TEAM_TASK_MODELS 'analysis=vendor/new verify=vendor/verify' --yes
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
    check deleted-routine-recovery eq "$RC" 0; check recovery-model contains "$OUT" 'vendor/strong:high'; check recovery-sid contains "$OUT" "$SID_A"
    run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --print
    check new-unmapped-override-refused eq "$RC" 1
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:low --print
    check suffix-change-requires-fresh eq "$RC" 1
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh --print
    check fresh-keeps-stored-model eq "$RC" 0; check fresh-model contains "$OUT" 'vendor/strong:high'
    tmux_iso_require routing stop-fixture --tmpdir "$TMUX_TMPDIR" --sock-name "$LIVE_SOCKET" --own-root "$TMP"
    (cd "$REPO" && tmux kill-window -t routing-fixture:dev)
    run resume --agent dev --dry-run
    check resume-stored-identity eq "$RC" 0; check resume-sid contains "$OUT" "$SID_A"
    run resume --agent dev
    check actual-resume-after-policy-removal eq "$RC" 0
    check actual-resume-argv-exact python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert a[a.index("--provider")+1]=="vendor" and a[a.index("--model")+1]=="strong:high" and a[a.index("--session-id")+1]==sys.argv[2]' "$TMP/argv-jsonl" "$SID_A"
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
    check actual-same-model-fresh-after-policy-removal eq "$RC" 0
    check actual-fresh-record team_assignment_load dev
    SID_FRESH="${TEAM_ASSIGN[sid]:-missing}"
    check actual-fresh-SID-different bash -c '[ "$1" != "$2" ]' _ "$SID_A" "$SID_FRESH"
    (cd "$REPO" && tmux kill-window -t routing-fixture:dev)
    run resume --agent dev
    check actual-resume-retains-fresh-identity eq "$RC" 0
    check actual-resume-fresh-argv-exact python3 -c 'import json,sys; a=json.loads(open(sys.argv[1]).readlines()[-1]); assert a[a.index("--provider")+1]=="vendor" and a[a.index("--model")+1]=="strong:high" and a[a.index("--session-id")+1]==sys.argv[2]' "$TMP/argv-jsonl" "$SID_FRESH"
    (cd "$REPO" && tmux kill-window -t routing-fixture:dev)
  fi
  if has dispatch; then routing_publication_probes; fi
fi
# Hook only the owned fixture shell; shipped files are never modified by these faults.
hooked() {
  (cd "$REPO" && timeout 45 bash --noprofile --norc -c '
    CMD=dispatch; ARGS=()
    source "$1/scripts/lib/common.sh"
    for lib in "$1"/scripts/lib/cmd-*.sh; do source "$lib"; done
    team_load_config || exit
    source "$2"
    shift 2; team_cmd_dispatch "$@"
  ' _ "$SKILL" "$TMP/hook.sh" "$@")
}
run_hook() { RC=0; effect_snapshot "before hook $*"; OUT="$(hooked "$@" 2>&1)" || RC=$?; printf 'hook rc=%s\n%s\n' "$RC" "$OUT"; effect_snapshot "after hook rc=$RC $*"; }
stop_fixture_seat() { (cd "$REPO" && tmux kill-window -t "routing-fixture:$1") 2>/dev/null || true; }
assignment_snapshot() { printf '%s:%s:%s' "$(sha "$STATE/dev.env")" "$(sha "$STATE/dev.pending")" "$(sha "$REPO/docs/team/BOARD.md")"; }
if has boundary; then
  routing_template_probes
  routing_pm_template_probes
  routing_expansion_probes worker
  routing_expansion_probes pm
  routing_role_probes worker
  routing_role_probes pm
  routing_resume_role_probes
fi
if has limits || has transaction; then
  run config set TEAM_TASK_MODELS 'routine=vendor/routine analysis=vendor/analysis verify=vendor/verify' --yes
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:high --fresh
  check advanced-setup-recorded-launch eq "$RC" 0
fi
if has limits; then
  run config set TEAM_MODEL_LIMITS 'vendor/*=1' --yes
  snap="$(assignment_snapshot)"; argv_before="$(sha "$TMP/argv.log")"
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --print
  check positive-full-model-cap eq "$RC" 1
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/different --print
  check wildcard-bucket-counts-actual-peer eq "$RC" 1
  check cap-refusal-keeps-assignment eq "$(assignment_snapshot)" "$snap"
  check cap-refusal-no-launch eq "$(sha "$TMP/argv.log")" "$argv_before"
  run config set TEAM_MODEL_LIMITS 'vendor/*=1 vendor/strong:low=1' --yes
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:low --print
  check exact-suffix-bucket-independent eq "$RC" 0
  run config set TEAM_MODEL_LIMITS 'vendor/*=1 *=0' --yes
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/different --print
  check zero-wildcard-does-not-erase-positive-cap eq "$RC" 1
  cp "$STATE/dev.env" "$TMP/known-dev.env"
  python3 - "$STATE/dev.env" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); p.write_text(''.join(x for x in p.read_text().splitlines(True) if not x.startswith('model=')))
PY
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --force --print
  check unknown-live-peer-fail-closed-even-force eq "$RC" 1
  check unknown-live-peer-named contains "$OUT" 'unknown=dev'
  check unknown-live-peer-clear-route contains "$OUT" 'teardown --agent dev'
  snap="$(assignment_snapshot)"; argv_before="$(sha "$TMP/argv.log")"
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --force
  check unknown-live-peer-real-launch-refused eq "$RC" 1
  check unknown-live-peer-real-record-preserved eq "$(assignment_snapshot)" "$snap"
  check unknown-live-peer-real-no-launch eq "$(sha "$TMP/argv.log")" "$argv_before"
  run config set TEAM_MODEL_LIMITS 'vendor/*=0' --yes
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --print
  check unlimited-does-not-demand-peer-model eq "$RC" 0
  cp "$TMP/known-dev.env" "$STATE/dev.env"
  # P228/R6（OBS1）：模板没交付模型的活跃同伴（identity_via 里没有 model）同样是「完整已提交模型身份不存在」
  # —— 不得按记录里的选择计数，正/通配限额下都 fail-closed（同一车道，新的一格）。
  run config set TEAM_MODEL_LIMITS 'vendor/*=1' --yes
  sed -i 's/^identity_via=.*/identity_via=provider,session_id/' "$STATE/dev.env"
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:high --force --print
  check undelivered-model-peer-fail-closed eq "$RC" 1
  check undelivered-model-peer-named contains "$OUT" 'unknown=dev'
  cp "$TMP/known-dev.env" "$STATE/dev.env"
  run config set TEAM_MODEL_LIMITS 'vendor/*=0' --yes
  check pm-does-not-consume-worker-bucket bash -c '
    source "$1/scripts/lib/common.sh"; for lib in "$1"/scripts/lib/cmd-*.sh; do source "$lib"; done; team_load_config
    TEAM_AGENTS="dev pm verify"; TEAM_MODEL_LIMITS="vendor/*=1"
    team_agent_live() { return 0; }
    team_model_peers vendor/strong:high verify
    [ "$TEAM_MODEL_KNOWN_COUNT" = 1 ] && [ -z "$TEAM_MODEL_UNKNOWN" ]
  ' _ "$SKILL"
  stop_fixture_seat dev; stop_fixture_seat verify
  run config set TEAM_MODEL_LIMITS 'vendor/*=1' --yes
  for a in dev verify; do
    id=T1; [ "$a" != verify ] || id=T2
    (cd "$REPO" && bash "$CLI" dispatch "$a" "$id" "docs/team/tasks/$id-fixture.md" --model vendor/strong:high --fresh > "$TMP/cap-$a.log" 2>&1; printf '%s' "$?" > "$TMP/cap-$a.rc") &
  done
  wait
  check cross-seat-serialized-admission python3 -c 'import pathlib,sys; assert sorted(pathlib.Path(x).read_text() for x in sys.argv[1:])==["0","1"]' "$TMP/cap-dev.rc" "$TMP/cap-verify.rc"
  windows="$(cd "$REPO" && tmux list-windows -t routing-fixture -F '#{window_name}')"
  check cross-seat-only-one-worker-window eq "$(printf '%s\n' "$windows" | grep -cE '^(dev|verify)$')" 1
  stop_fixture_seat dev; stop_fixture_seat verify
  run config set TEAM_MODEL_LIMITS '' --yes
fi
if has transaction; then
  stop_fixture_seat dev
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:high --fresh
  check transaction-initial-complete eq "$RC" 0
  # Both processes must finish preflight on the same old generation before either admits.
  cat > "$TMP/hook.sh" <<'HOOK'
team_dispatch_judge_seat_hint() {
  if [ "${_TEAM_DISPATCH_PREFLIGHT_ONLY:-0}" = 1 ]; then
    printf ready > "$TEAM_MAIN_ROOT/barrier-$FIXTURE_ATTEMPT"
    local i; for ((i=0;i<200;i++)); do
      [ ! -f "$TEAM_MAIN_ROOT/barrier-a" ] || [ ! -f "$TEAM_MAIN_ROOT/barrier-b" ] || return 0
      sleep 0.02
    done
    return 1
  fi
}
HOOK
  calls_before="$(grep -c -- '^--provider$' "$TMP/argv.log")"
  (FIXTURE_ATTEMPT=a hooked dev T1 docs/team/tasks/T1-fixture.md --fresh > "$TMP/same-a.log" 2>&1; printf '%s' "$?" > "$TMP/same-a.rc") & p1=$!
  (FIXTURE_ATTEMPT=b hooked dev T1 docs/team/tasks/T1-fixture.md --fresh > "$TMP/same-b.log" 2>&1; printf '%s' "$?" > "$TMP/same-b.rc") & p2=$!
  wait "$p1" "$p2"
  check same-seat-generation-race python3 -c 'import pathlib,sys; assert sorted(pathlib.Path(x).read_text() for x in sys.argv[1:])==["0","1"]' "$TMP/same-a.rc" "$TMP/same-b.rc"
  check same-seat-loser-no-second-launch eq "$(( $(grep -c -- '^--provider$' "$TMP/argv.log") - calls_before ))" 1
  rm -f "$REPO/barrier-a" "$REPO/barrier-b"
  # External edit bypasses the CLI config lock: final snapshot must still reject it.
  cp "$CONFIG" "$TMP/config-before-race"
  cat > "$TMP/hook.sh" <<'HOOK'
eval "$(declare -f team_dispatch_final_snapshot | sed '1s/team_dispatch_final_snapshot/fixture_original_snapshot/')"
team_dispatch_final_snapshot() { printf '\n# external edit\n' >> "$TEAM_CONFIG"; fixture_original_snapshot "$@"; }
HOOK
  snap="$(assignment_snapshot)"; argv_before="$(sha "$TMP/argv.log")"
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check final-config-snapshot-refused eq "$RC" 1
  check final-config-snapshot-record-preserved eq "$(assignment_snapshot)" "$snap"
  check final-config-snapshot-no-launch eq "$(sha "$TMP/argv.log")" "$argv_before"
  cp "$TMP/config-before-race" "$CONFIG"
  cp "$REPO/docs/team/tasks/T1-fixture.md" "$TMP/brief-before-race"
  cat > "$TMP/hook.sh" <<'HOOK'
eval "$(declare -f team_dispatch_final_snapshot | sed '1s/team_dispatch_final_snapshot/fixture_original_snapshot/')"
team_dispatch_final_snapshot() { printf '\nexternal brief edit\n' >> "$TEAM_MAIN_ROOT/docs/team/tasks/T1-fixture.md"; fixture_original_snapshot "$@"; }
HOOK
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check final-brief-snapshot-refused eq "$RC" 1
  check final-brief-snapshot-record-preserved eq "$(assignment_snapshot)" "$snap"
  cp "$TMP/brief-before-race" "$REPO/docs/team/tasks/T1-fixture.md"
  # Actual startup failure: owned recording executable exits 9, never a real provider.
  run config set TEAM_AGENT_CMD "$TMP/recording-pi --provider {provider} --model {model} --session-id {session_id}" --yes
  touch "$TMP/fail-launch"; old="$(sha "$STATE/dev.env")"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
  check failed-launch-refused eq "$RC" 1
  check failed-launch-old-record-bytes eq "$(sha "$STATE/dev.env")" "$old"
  check failed-launch-nonce-diagnostic bash -c 'test -n "$(find "$1" -name "dispatch-dev.failed-*" -print -quit)"' _ "$STATE"
  rm -f "$TMP/fail-launch"
  run config set TEAM_AGENT_CMD '' --yes
  cat > "$TMP/hook.sh" <<'HOOK'
eval "$(declare -f team_wait_launch_proof | sed '1s/team_wait_launch_proof/fixture_original_wait/')"
team_wait_launch_proof() { fixture_original_wait "$1" "$2" 2 >/dev/null || return; printf 'stale-nonce %s\n' "$BASHPID" > "$(team_dispatch_spawn_file "$1")"; fixture_original_wait "$1" "$2" 0; }
HOOK
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check stale-launch-proof-refused eq "$RC" 1
  check stale-launch-proof-old-record eq "$(sha "$STATE/dev.env")" "$old"
  check stale-launch-proof-diagnostic grep -q 'failed=no nonce proof' "$STATE/dispatch-dev.attempts.log"
  cat > "$TMP/hook.sh" <<'HOOK'
mv() { local last="${!#}"; [ "$last" != "$TEAM_STATE_DIR/dev.env" ] || return 1; command mv "$@"; }
HOOK
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check failed-publication-refused eq "$RC" 1
  check failed-publication-old-record-bytes eq "$(sha "$STATE/dev.env")" "$old"
  check failed-publication-no-worker-window bash -c '! tmux list-windows -t routing-fixture -F "#{window_name}" 2>/dev/null | grep -Fxq dev'
  cat > "$TMP/hook.sh" <<'HOOK'
team_board_set() { return 1; }
HOOK
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check board-failure-after-commit-not-rollback eq "$RC" 0
  check board-failure-complete-record team_assignment_load dev
  check board-failure-new-generation bash -c '[ "$1" != "$2" ]' _ "$(sha "$STATE/dev.env")" "$old"
  check board-failure-pending-matches eq "$(awk -F= '$1=="launch_nonce"{print $2}' "$STATE/dev.pending")" "${TEAM_ASSIGN[launch_nonce]:-missing}"
  stop_fixture_seat dev
  cat > "$TMP/hook.sh" <<'HOOK'
eval "$(declare -f team_dispatch_prepare_record | sed '1s/team_dispatch_prepare_record/fixture_original_prepare/')"
team_dispatch_prepare_record() { fixture_original_prepare "$@" || return; kill -TERM "$BASHPID"; }
HOOK
  old="$(sha "$STATE/dev.env")"; run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check interrupted-before-commit eq "$RC" 143
  check interrupted-before-commit-old-record eq "$(sha "$STATE/dev.env")" "$old"
  pending_nonce="$(awk -F= '$1=="launch_nonce"{print $2}' "$STATE/dev.pending")"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
  check interrupted-pending-requires-explicit-fresh eq "$RC" 1
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
  check interrupted-pending-fresh-takeover eq "$RC" 0
  check interrupted-pending-preserved test -f "$STATE/dispatch-dev.interrupted-$pending_nonce"
  # Crash AFTER low-model proof but BEFORE rename: a past complete high-model record cannot identify that live peer.
  cat > "$TMP/hook.sh" <<'HOOK'
mv() { local last="${!#}"; if [ "$last" = "$TEAM_STATE_DIR/dev.env" ]; then kill -TERM "$BASHPID"; else command mv "$@"; fi; }
HOOK
  old="$(sha "$STATE/dev.env")"
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh --model vendor/strong:low
  check interrupted-proven-unpublished-launch eq "$RC" 143
  check interrupted-proven-old-record-bytes eq "$(sha "$STATE/dev.env")" "$old"
  run config set TEAM_MODEL_LIMITS 'vendor/strong:low=1' --yes
  run dispatch verify T2 docs/team/tasks/T2-fixture.md --model vendor/strong:low --fresh --force --print
  check interrupted-peer-positive-cap-unjudgeable eq "$RC" 1
  check interrupted-peer-current-nonce-mismatch contains "$OUT" 'unknown=dev (interrupted pending launch/assignment nonce mismatch)'
  run config set TEAM_MODEL_LIMITS '' --yes
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh
  check interrupted-proven-fresh-takeover eq "$RC" 0
  cat > "$TMP/hook.sh" <<'HOOK'
team_board_set() { kill -TERM "$BASHPID"; }
HOOK
  run_hook dev T1 docs/team/tasks/T1-fixture.md --fresh
  check interrupted-after-commit eq "$RC" 143
  check interrupted-after-commit-complete team_assignment_load dev
  committed_sid="${TEAM_ASSIGN[sid]:-missing}"
  run dispatch dev T1 docs/team/tasks/T1-fixture.md --print
  check interrupted-after-commit-recoverable eq "$RC" 0
  check interrupted-after-commit-sid contains "$OUT" "$committed_sid"
  # Close/teardown queued AFTER proof cannot kill/clear a provisional worker through the held seat lock.
  for clear_command in teardown close; do
    rm -f "$REPO/proof-ready" "$REPO/proof-release"
    cat > "$TMP/hook.sh" <<'HOOK'
eval "$(declare -f team_wait_launch_proof | sed '1s/team_wait_launch_proof/fixture_original_wait/')"
team_wait_launch_proof() {
  local got i; got="$(fixture_original_wait "$@")" || return
  printf ready > "$TEAM_MAIN_ROOT/proof-ready"
  for ((i=0;i<300;i++)); do [ ! -f "$TEAM_MAIN_ROOT/proof-release" ] || { printf '%s\n' "$got"; return 0; }; sleep 0.02; done
  return 1
}
HOOK
    old="$(sha "$STATE/dev.env")"
    (hooked dev T1 docs/team/tasks/T1-fixture.md --fresh > "$TMP/proof-$clear_command-dispatch.log" 2>&1; printf '%s' "$?" > "$TMP/proof-$clear_command-dispatch.rc") & pending_pid=$!
    for ((i=0;i<300;i++)); do [ ! -f "$REPO/proof-ready" ] || break; sleep 0.02; done
    check "$clear_command-current-proof-held" test -f "$REPO/proof-ready"
    if [ "$clear_command" = teardown ]; then args=(teardown --agent dev); else args=(close T1 --status dropped); fi
    (cd "$REPO" && bash "$CLI" "${args[@]}" > "$TMP/proof-$clear_command-clear.log" 2>&1; printf '%s' "$?" > "$TMP/proof-$clear_command-clear.rc") & clear_pid=$!
    sleep 0.3
    check "$clear_command-waits-for-publication-lock" bash -c '[ ! -f "$1" ] && [ "$2" = "$3" ]' _ "$TMP/proof-$clear_command-clear.rc" "$(sha "$STATE/dev.env")" "$old"
    touch "$REPO/proof-release"; wait "$pending_pid" "$clear_pid"
    check "$clear_command-proof-dispatch-success" eq "$(<"$TMP/proof-$clear_command-dispatch.rc")" 0
    check "$clear_command-queued-clear-success" eq "$(<"$TMP/proof-$clear_command-clear.rc")" 0
    check "$clear_command-no-identity-resurrection" bash -c '[ ! -e "$1" ]' _ "$STATE/dev.env"
    git -C "$REPO/.worktrees/dev" switch task/T1-fixture >/dev/null 2>&1
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --model vendor/strong:high --fresh
    check "$clear_command-proof-fixture-restored" eq "$RC" 0
  done
  # Explicit teardown/close serialized against a dispatch paused BEFORE seat admission.
  for clear_command in teardown close; do
    rm -f "$REPO/clear-ready" "$REPO/clear-release"
    cat > "$TMP/hook.sh" <<'HOOK'
team_dispatch_judge_seat_hint() {
  if [ "${_TEAM_DISPATCH_PREFLIGHT_ONLY:-0}" = 1 ]; then
    printf ready > "$TEAM_MAIN_ROOT/clear-ready"
    local i; for ((i=0;i<250;i++)); do [ ! -f "$TEAM_MAIN_ROOT/clear-release" ] || return 0; sleep 0.02; done
    return 1
  fi
}
HOOK
    (hooked dev T1 docs/team/tasks/T1-fixture.md --fresh > "$TMP/clear-$clear_command.log" 2>&1; printf '%s' "$?" > "$TMP/clear-$clear_command.rc") & p1=$!
    for ((i=0;i<250;i++)); do [ ! -f "$REPO/clear-ready" ] || break; sleep 0.02; done
    check "$clear_command-race-preflight-ready" test -f "$REPO/clear-ready"
    if [ "$clear_command" = teardown ]; then run teardown --agent dev; else run close T1 --status dropped; fi
    check "$clear_command-explicit-clear" eq "$RC" 0
    touch "$REPO/clear-release"; wait "$p1"
    check "$clear_command-race-no-resurrection" eq "$(<"$TMP/clear-$clear_command.rc")" 1
    check "$clear_command-assignment-cleared" bash -c '! test -e "$1/dev.env"' _ "$STATE"
    git -C "$REPO/.worktrees/dev" switch task/T1-fixture >/dev/null 2>&1
    run dispatch dev T1 docs/team/tasks/T1-fixture.md --fresh --model vendor/strong:high
    check "$clear_command-fixture-restored" eq "$RC" 0
  done
  # Deterministic generator forces both a recorded and an on-disk SID collision.
  check collision-source-complete team_assignment_load dev
  COLLISION_A="${TEAM_ASSIGN[sid]}"; dir="$(team_pi_session_dir "$REPO/.worktrees/dev")"; mkdir -p "$dir"
  printf '{}' > "$dir/000_fixed-clock-history.jsonl"; printf 0 > "$TMP/candidate-count"
  printf 'sid=fixed-clock-staged\n' > "$STATE/.assignment-collision-staged"
  eval "$(declare -f team_sid_candidate | sed '1s/team_sid_candidate/fixture_original_candidate/')"
  team_sid_candidate() {
    local n; n="$(<"$TMP/candidate-count")"; n=$((n+1)); printf '%s' "$n" > "$TMP/candidate-count"
    case "$n" in 1) printf '%s' "$COLLISION_A" ;; 2) printf fixed-clock-history ;; 3) printf fixed-clock-staged ;; *) printf fixed-clock-unique ;; esac
  }
  collision_sid="$(team_unique_sid dev "$REPO/.worktrees/dev")"
  check forced-sid-collision-regenerated eq "$collision_sid" fixed-clock-unique
  check forced-sid-collision-four-candidates eq "$(<"$TMP/candidate-count")" 4
  eval "$(declare -f fixture_original_candidate | sed '1s/fixture_original_candidate/team_sid_candidate/')"
  # Alive owners are not stolen; stale PID ownership is reclaimed with evidence.
  check lock-owner-liveness-and-reclaim bash -c '
    export TMPDIR="$2"; mkdir -p "$TMPDIR"; source "$1/scripts/lib/common.sh"
    lock="$(team_lock_path seat:dev)"; mkdir -m 700 "$lock"
    mine="$BASHPID"; printf "%s %s live\n" "$mine" "$(team_proc_start_identity "$mine")" > "$lock/owner"
    TEAM_LOCK_WAIT_TICKS=1 team_with_lock seat:dev true && exit 1
    printf "999999999 123 stale\n" > "$lock/owner"
    team_with_lock seat:dev true || exit
    test -n "$(find "$TMPDIR" -name "*.stale.*" -print -quit)"
  ' _ "$SKILL" "$TMP/lock-tests"
fi
if has sid-readers; then
  mkdir -p "$STATE"; routing_fixture_record "$STATE" dev T1 "$REPO/.worktrees/dev" "$REPO/docs/team/tasks/T1-fixture.md" vendor/strong:high recorded-A explicit
  dir="$(team_pi_session_dir "$REPO/.worktrees/dev")"; mkdir -p "$dir"
  printf '{"type":"session","cwd":"%s"}\n{"type":"message","message":{"role":"assistant","stopReason":"error","errorMessage":"429 rate_limit_error","content":[]}}\n' "$REPO/.worktrees/dev" > "$dir/000_recorded-A.jsonl"
  printf '{"type":"session"}\n{"type":"message","message":{"role":"assistant","stopReason":"error","errorMessage":"403 invalid_api_key","content":[]}}\n' > "$dir/999_newer-B.jsonl"
  check reader-session-A contains "$(team_agent_session_cols dev)" recorded-A.jsonl
  check reader-cause-A contains "$(team_agent_session_latest dev)" recorded-A.jsonl
  OUT="$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)"
  check reader-monitor-A contains "$OUT" recorded-A.jsonl
  routing_reader_matrix
  rm "$dir/000_recorded-A.jsonl"
  check reader-missing-A-no-B bash -c '! [[ "$1" == *newer-B* ]]' _ "$(team_agent_session_cols dev)"
  cp "$STATE/dev.env" "$TMP/reader-record"; rm "$STATE/dev.env"
  check reader-no-record-no-newest-fallback bash -c '! [[ "$1" == *newer-B* ]]' _ "$(team_agent_session_cols dev)"
  OUT="$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)"
  check reader-no-record-monitor-unavailable bash -c '! [[ "$1" == *newer-B.jsonl* ]]' _ "$OUT"
  cp "$TMP/reader-record" "$STATE/dev.env"
  : > "$dir/000_recorded-A.jsonl"
  check reader-fresh-zero-bytes eq "$(team_session_bytes recorded-A "$REPO/.worktrees/dev")" 0
  printf '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"later recorded A growth"}]}}\n' >> "$dir/000_recorded-A.jsonl"
  check reader-later-A-growth bash -c '[ "$1" -gt 0 ]' _ "$(team_session_bytes recorded-A "$REPO/.worktrees/dev")"
  check reader-growth-still-A contains "$(team_agent_session_cols dev)" recorded-A.jsonl
  rm "$dir/000_recorded-A.jsonl"
  OUT="$(node "$SKILL/scripts/monitor.mjs" --root "$REPO" --only dev --json)"
  check monitor-missing-A-unavailable contains "$OUT" 'committed SID unavailable'
fi
if has init; then
  # P235 · S3 的前门：新鲜 init/bootstrap 必须拿显式类别映射 + 独立 PM 模型；旧配置在任何写入之前拒绝。
  # 所有命令走真 CLI（不是 source 库），每条都记命令/rc/输出到 init-cmds.log。
  iclean=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
    -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_PM_WINDOW -u TEAM_AGENTS -u TEAM_DOCS_DIR \
    -u TEAM_WORKTREES_DIR -u TEAM_GATES -u TEAM_VCS -u TEAM_CONFIG -u TEAM_CONFIG_FILE \
    -u TEAM_STATE_DIR -u TEAM_SKILL_DIR -u TEAM_PULSE_WINDOW -u TEAM_MODEL_RETIRED_ENV)
  i_new_repo() { # <dir>
    rm -rf "$1"; mkdir -p "$1"
    ( cd "$1" && git init -q -b main && git config user.name fixture && git config user.email fixture@example.invalid \
        && printf '# init fixture\n' > README.md && git add -A && git commit -qm fixture ) >/dev/null 2>&1
  }
  i_run() { # <dir> <team args...>
    local d="$1"; shift
    RC=0; OUT="$( cd "$d" && "${iclean[@]}" bash "$CLI" "$@" 2>&1 )" || RC=$?
    { printf 'command='; printf '%q ' "$@"; printf '\nrc=%s\n%s\n' "$RC" "$OUT"; } >> "$TMP/init-cmds.log"
    return 0
  }
  i_hash_tree() { find "$1" -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum | sha256sum | cut -d' ' -f1; }

  # ① 显式输入逐字渲染，绝不猜：配置里只有新策略键 + 用户给的值
  i_fresh="$TMP/init-fresh"; i_new_repo "$i_fresh"
  i_run "$i_fresh" init --no-skills --session init-fresh --agents 'dev verify' --vcs local --gates true \
        --task-models 'maintenance=vendor/light audit=vendor/audit:high' --pm-model 'vendor/pm:max'
  check init-fresh-rc eq "$RC" 0
  check init-fresh-map eq "$(grep -c "^TEAM_TASK_MODELS='maintenance=vendor/light audit=vendor/audit:high'\$" "$i_fresh/.pi/team/config.sh" || true)" 1
  check init-fresh-pm eq "$(grep -c "^TEAM_PM_MODEL='vendor/pm:max'\$" "$i_fresh/.pi/team/config.sh" || true)" 1
  check init-fresh-no-retired-key bash -c '! grep -qE "^(export )?TEAM_(DEFAULT_MODEL|AGENT_MODELS)=" "$1"' _ "$i_fresh/.pi/team/config.sh"
  check init-fresh-ledger test -f "$i_fresh/docs/team/BOARD.md"
  check init-fresh-protocol grep -qF '<!-- teamsmith:begin -->' "$i_fresh/AGENTS.md"
  i_run "$i_fresh" config list --json
  check init-fresh-machine python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["models"]["policy"]["categories"]==[{"category":"maintenance","model":"vendor/light"},{"category":"audit","model":"vendor/audit:high"}], d["models"]["policy"]["categories"]; assert d["models"]["policy"]["pm"]=="vendor/pm:max"' "$OUT"

  # ② 缺输入在配置/账本/安装/工作树/state 任何写入之前拒绝；退休旗标给修正路线
  i_missing="$TMP/init-missing"; i_new_repo "$i_missing"
  i_run "$i_missing" init --no-skills --session init-missing --agents dev --vcs local --gates true
  check init-missing-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check init-missing-route contains "$OUT" '--task-models'
  check init-missing-no-side-effect bash -c '! test -e "$1/.pi/team/config.sh" && ! test -e "$1/.pi/team/state" && ! test -e "$1/.pi/skills" && ! test -e "$1/docs/team" && ! test -e "$1/AGENTS.md"' _ "$i_missing"
  i_run "$i_missing" bootstrap --no-pulse --agents dev
  check init-bootstrap-missing-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check init-bootstrap-missing-no-side-effect bash -c '! test -e "$1/.pi/team/config.sh" && ! test -e "$1/.pi/team/state" && ! test -e "$1/.pi/skills" && ! test -e "$1/docs/team" && ! test -e "$1/.worktrees"' _ "$i_missing"
  i_run "$i_missing" init --no-skills --session init-missing --agents dev --model p/old
  check init-retired-flag eq "$RC" 2
  check init-retired-route contains "$OUT" 'upgrade-models'

  # ③ 非法输入拒绝且不落盘
  i_bad="$TMP/init-bad"; i_new_repo "$i_bad"
  i_run "$i_bad" init --no-skills --session init-bad --agents dev --task-models 'notamap' --pm-model 'vendor/pm'
  check init-bad-map eq "$RC" 4
  i_run "$i_bad" init --no-skills --session init-bad --agents dev --task-models 'routine=vendor/light' --pm-model 'badshape'
  check init-bad-pm eq "$RC" 4
  check init-bad-no-config bash -c '! test -e "$1/.pi/team/config.sh"' _ "$i_bad"

  # ④ 合法新策略项目可无输入重入（策略逐字节保留）；显式输入与现有策略不同时必须拒绝而不是静默忽略
  i_before="$(sha "$i_fresh/.pi/team/config.sh")"
  i_run "$i_fresh" init --no-skills --session init-fresh --agents dev --vcs local
  check init-reentry-rc eq "$RC" 0
  check init-reentry-keeps-policy eq "$(sha "$i_fresh/.pi/team/config.sh")" "$i_before"
  i_run "$i_fresh" init --no-skills --session init-fresh --agents dev --vcs local --task-models 'routine=other/x' --pm-model 'vendor/pm:max'
  check init-reentry-different-refused eq "$RC" 4
  check init-reentry-different-no-write eq "$(sha "$i_fresh/.pi/team/config.sh")" "$i_before"

  # ⑤ 旧配置：init / init --force / bootstrap / bootstrap --print 全在写入之前拒绝；身份与账本哈希不变
  i_legacy="$TMP/init-legacy"; i_new_repo "$i_legacy"
  mkdir -p "$i_legacy/.pi/team" "$i_legacy/docs/team"
  cat > "$i_legacy/.pi/team/config.sh" <<'EOF'
TEAM_PROJECT='init-legacy'
TEAM_SESSION='init-legacy'
TEAM_DOCS_DIR='docs/team'
TEAM_AGENTS='dev verify'
TEAM_AGENT_MODELS='dev=p/old'
TEAM_DEFAULT_MODEL='p/old'
TEAM_GATES='true'
TEAM_VCS='local'
EOF
  printf '# BOARD legacy\n' > "$i_legacy/docs/team/BOARD.md"
  i_cfg0="$(sha "$i_legacy/.pi/team/config.sh")"; i_led0="$(i_hash_tree "$i_legacy/docs")"
  i_run "$i_legacy" init --no-skills --session init-legacy --agents dev
  check init-legacy-plain-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check init-legacy-plain-route contains "$OUT" 'upgrade-models'
  i_run "$i_legacy" init --force --no-skills --session init-legacy --agents dev --task-models 'routine=p/new' --pm-model 'p/pm'
  check init-legacy-force-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check init-legacy-force-route contains "$OUT" 'upgrade-models'
  i_run "$i_legacy" bootstrap --no-pulse --agents dev
  check init-legacy-bootstrap-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  i_run "$i_legacy" bootstrap --no-pulse --agents dev --print
  check init-legacy-print-refused bash -c '[ "$1" != 0 ]' _ "$RC"
  check init-legacy-print-readonly contains "$OUT" 'upgrade-models'
  check init-legacy-config-unchanged eq "$(sha "$i_legacy/.pi/team/config.sh")" "$i_cfg0"
  check init-legacy-ledger-unchanged eq "$(i_hash_tree "$i_legacy/docs")" "$i_led0"
  check init-legacy-no-side-effect bash -c '! test -e "$1/.pi/skills" && ! test -e "$1/.pi/team/state" && ! test -e "$1/.worktrees" && ! test -e "$1/AGENTS.md"' _ "$i_legacy"

  # ⑥ 新鲜 bootstrap：给输入才写；--print 只读
  i_boot="$TMP/init-boot"; i_new_repo "$i_boot"
  i_run "$i_boot" bootstrap --no-pulse --agents dev --task-models 'routine=vendor/light' --pm-model 'vendor/pm:high'
  check init-bootstrap-fresh-rc eq "$RC" 0
  check init-bootstrap-fresh-map eq "$(grep -c "^TEAM_TASK_MODELS='routine=vendor/light'\$" "$i_boot/.pi/team/config.sh" || true)" 1
  check init-bootstrap-fresh-pm eq "$(grep -c "^TEAM_PM_MODEL='vendor/pm:high'\$" "$i_boot/.pi/team/config.sh" || true)" 1
  i_print="$TMP/init-print"; i_new_repo "$i_print"
  i_run "$i_print" bootstrap --no-pulse --print
  check init-print-rc eq "$RC" 0
  check init-print-no-writes bash -c '! test -e "$1/.pi/team" && ! test -e "$1/docs/team"' _ "$i_print"

  # ⑦ 共享来源 vs 未链接的私有集成树：私有树里的 init/升级不碰保留源与链接；指南点名共享读取与四个门
  i_shared="$TMP/shared-source"; rm -rf "$i_shared"; mkdir -p "$i_shared"
  cp -a "$SKILL" "$i_shared/teamsmith"
  i_shared0="$(i_hash_tree "$i_shared/teamsmith")"
  ln -sfn "$i_shared/teamsmith" "$TMP/shared-link"
  i_link0="$(readlink -f "$TMP/shared-link")"
  i_private="$TMP/private-integration"; rm -rf "$i_private"; mkdir -p "$i_private/skills"
  cp -a "$SKILL" "$i_private/skills/teamsmith"
  i_repo="$TMP/init-private"; i_new_repo "$i_repo"
  ( cd "$i_repo" && "${iclean[@]}" bash "$i_private/skills/teamsmith/scripts/team" init --no-skills --session init-private \
      --agents dev --vcs local --gates true --task-models 'routine=vendor/light' --pm-model 'vendor/pm' ) >/dev/null 2>&1
  check init-private-rc eq "$?" 0
  check init-private-shared-source-unchanged eq "$(i_hash_tree "$i_shared/teamsmith")" "$i_shared0"
  check init-private-link-intact eq "$(readlink -f "$TMP/shared-link")" "$i_link0"
  check init-guidance-shared-effect bash -c 'for f in "$1/references/migration.md" "$1/templates/pm-prompt.md.tmpl"; do grep -q "installer" "$f" && grep -qi "shared" "$f" || exit 1; done' _ "$SKILL"
  check init-guidance-separate-gates bash -c 'grep -q '\''separate recorded gates'\'' "$1/references/migration.md" && grep -q '\''separate recorded gates'\'' "$1/templates/pm-prompt.md.tmpl"' _ "$SKILL"
  check init-guidance-ownership-not-model bash -c 'grep -q "not a model" "$1/templates/OWNERSHIP.md.tmpl" && ! grep -qE "^\| Agent \| Model" "$1/templates/OWNERSHIP.md.tmpl"' _ "$SKILL"
fi
if has pm || has boundary; then
  TEAM_TASK_MODELS='analysis=p/a verify=p/v'; TEAM_PM_MODEL='pm-provider/deep/model:high'; TEAM_PM_FRESH_LAUNCH=1
  check pm-independent-model contains "$(team_pm_pi_args)" '--provider pm-provider --model deep/model:high'
  for extra in '--model x/y' '--model=x/y' '--provider=other' '-m other' '--session=/tmp/f.jsonl' '-c' '-r' "$TMP/file.jsonl"; do
    TEAM_PM_EXTRA_PI_ARGS="$extra"; rc=0; team_pm_identity_guard || rc=$?; check "boundary-reject:$extra" eq "$rc" 1
  done
  TEAM_PM_EXTRA_PI_ARGS='--no-tools'; check boundary-harmless team_pm_identity_guard
  TEAM_PM_EXTRA_PI_ARGS=''; TEAM_PM_FRESH_LAUNCH=0
  rm -f "$STATE/pm-launch.env"; rc=0; team_pm_identity_guard || rc=$?; check pm-unknown-needs-fresh eq "$rc" 1
  TEAM_PM_FRESH_LAUNCH=1; team_pm_metadata_publish test-nonce
  # P228/R6（OBS1）：PM 记录也发布实际交付的身份字段（与 worker 同一份判据）；成功行只声明已交付的
  TEAM_PM_CMD="$TMP/recording-pi --model {model} {prompt}"; TEAM_PM_FRESH_LAUNCH=1
  team_pm_metadata_publish fixture-partial-pm
  check pm-partial-publication-record eq "$(grep '^identity_via=' "$STATE/pm-launch.env" | cut -d= -f2-)" 'model'
  check pm-partial-publication-claim contains "$(TEAM_PM_MODEL='pm-provider/deep/model:high'; team_pm_identity_claim)" 'model=pm-provider/deep/model:high'
  TEAM_PM_CMD="$TMP/recording-pi --ask {prompt}"; TEAM_PM_FRESH_LAUNCH=1
  team_pm_metadata_publish fixture-opaque-pm
  check pm-opaque-publication-record eq "$(grep '^identity_via=' "$STATE/pm-launch.env" | cut -d= -f2-)" ''
  check pm-opaque-publication-claim contains "$(TEAM_PM_MODEL='pm-provider/deep/model:high'; team_pm_identity_claim)" 'model 未由模板交付'
  TEAM_PM_CMD=''; TEAM_PM_FRESH_LAUNCH=1; team_pm_metadata_publish test-nonce
  TEAM_PM_FRESH_LAUNCH=0; check pm-known-continues team_pm_identity_guard
  routing_pm_metadata_matrix
  TEAM_PM_MODEL='pm-provider/deep/model:low'; rc=0; team_pm_identity_guard || rc=$?; check pm-suffix-change-needs-fresh eq "$rc" 1
  TEAM_PM_FRESH_LAUNCH=1; check pm-suffix-explicit-fresh team_pm_identity_guard
  TEAM_PM_MODEL='pm-provider/deep/model:high'; TEAM_PM_FRESH_LAUNCH=0
  TEAM_PM_SESSION_ID=unrecorded-sid; rc=0; team_pm_identity_guard || rc=$?; check pm-changed-resume-selector-needs-fresh eq "$rc" 1
  TEAM_PM_SESSION_ID=''; TEAM_PM_FRESH_LAUNCH=1
  TEAM_PM_RESUME_ARGS='--model wrong/model'; rc=0; team_pm_identity_guard || rc=$?; check pm-resume-args-cannot-shadow-model eq "$rc" 1
  TEAM_PM_RESUME_ARGS=''
  pm_no_respawn_guard() (
    team_pm_window_exists() { return 0; }
    team_pm_starting() { [ "$1" = ignored ]; } # replaced per arm below
    team_tmux_respawn_pane() { touch "$TMP/pm-unexpected-respawn"; return 1; }
    if [ "$1" = starting ]; then
      team_pm_starting() { return 0; }
      team_pm_starting_age() { printf '1\n'; }
      team_pm_evidence() { printf 'owned test starting marker\n'; }
    else
      team_pm_starting() { return 1; }
      team_pm_state() { printf 'running:owned-test-process\n'; }
    fi
    team_pm_start && [ ! -e "$TMP/pm-unexpected-respawn" ]
  )
  check pm-running-not-respawned pm_no_respawn_guard running
  check pm-starting-not-respawned pm_no_respawn_guard starting
  pm_publication_failure() (
    old="$(sha "$STATE/pm-launch.env")"
    team_pm_window_exists() { return 0; }
    team_pm_starting() { return 1; }
    team_pm_state() { printf 'idle:test\n'; }
    team_pm_check_launch() { return 0; }
    team_pm_check_bin() { return 0; }
    team_pm_write_prompt() { printf '%s\n' "$TMP/pm-fixture-prompt"; }
    team_pm_launch_cmd() { printf 'sleep 300\n'; }
    team_pm_pane_agent_pid() { tmux display-message -p -t routing-fixture:pm '#{pane_pid}'; }
    team_pm_launch_diag() { printf 'publication failure before stop\n' > "$TMP/pm-publication-diagnostic"; }
    mv() { return 1; }
    # The recording launcher owns an idle pm window already; do not create an ambiguous duplicate name.
    if ! tmux list-windows -t routing-fixture -F '#{window_name}' | grep -Fxq pm; then
      tmux new-window -d -t routing-fixture -n pm 'sleep 300' || return 1
    fi
    tmux list-windows -t routing-fixture -F '#{window_name} #{pane_id}' > "$TMP/pm-windows-before.log"
    rc=0; team_pm_start || rc=$?
    printf 'pm start rc=%s\n' "$rc" > "$TMP/pm-rollback-result.log"
    [ "$rc" = 1 ] && [ "$(sha "$STATE/pm-launch.env")" = "$old" ] &&
      [ -s "$TMP/pm-publication-diagnostic" ] && [ ! -e "$STATE/pm.pid" ] &&
      [ ! -e "$STATE/pm.pid.proof" ] && ! tmux list-windows -t routing-fixture -F '#{window_name}' 2>/dev/null | grep -Fxq pm
  )
  if [ -n "${LIVE_SOCKET:-}" ]; then check pm-publication-failure-stops-uncommitted pm_publication_failure; fi
fi
if has flip; then
  CORE='policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary'
  # One green baseline and one green restoration of the whole slice; each red arm has its own copy.
  flip_run() {
    local tag="$1" tree="$2" groups="$3" rc=0
    TEAM_ROUTING_TREE="$tree" TEAM_ROUTING_EVIDENCE="$TMP/flip-evidence/$tag" timeout 900 bash "$here/task-model-routing.sh" --select "$groups" > "$TMP/flip-$tag.log" 2>&1 || rc=$?
    printf 'CONTROL %s rc=%s log=%s\n' "$tag" "$rc" "$TMP/flip-$tag.log"
    tail -4 "$TMP/flip-$tag.log"
    FLIP_RC="$rc"
  }
  flip_run baseline "$TREE" "$CORE"
  check flip-baseline-green eq "$FLIP_RC" 0
  if [ "$FLIP_RC" = 0 ]; then
    for mutation in unmapped-override required-categories fingerprint expanding-quote recovery-drift partial-publication unknown-as-zero latest-shell latest-monitor pm-fallback pm-publication extra-shadow template-shadow template-unbound template-roles monitor-record-drift literal-shell-expansion pm-literal-resplit worker-literal-resplit identity-overclaim init-legacy-proceeds template-retired-key; do
      case "$mutation" in
        unmapped-override) groups=dispatch ;;
        required-categories) groups=policy,config,upgrade,dispatch ;;
        identity-overclaim) groups=dispatch,limits ;;
        fingerprint|expanding-quote) groups=config ;;
        recovery-drift) groups=resume ;;
        partial-publication) groups=transaction ;;
        unknown-as-zero) groups=limits ;;
        latest-shell|latest-monitor) groups=sid-readers ;;
        pm-fallback) groups=pm ;;
        pm-publication) groups=dispatch,pm ;;
        extra-shadow|template-shadow|template-unbound|template-roles|literal-shell-expansion|pm-literal-resplit|worker-literal-resplit) groups=boundary ;;
        monitor-record-drift) groups=sid-readers ;;
        init-legacy-proceeds|template-retired-key) groups=init ;;
      esac
      scratch="$TMP/mutants/$mutation"; mkdir -p "$scratch/skills/teamsmith"; touch "$scratch/.routing-mutant"
      for source_dir in scripts references templates extensions; do
        [ ! -d "$SKILL/$source_dir" ] || cp -a "$SKILL/$source_dir" "$scratch/skills/teamsmith/"
      done
      before="$(find "$scratch/skills/teamsmith/scripts" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
      python3 "$here/lib/model-routing-flips.py" "$scratch" "$mutation" > "$TMP/mutation-$mutation.json"
      check "flip-$mutation-target-matched" eq "$?" 0
      check "flip-$mutation-shape-valid" bash -c 'for file in "$1"/scripts/lib/*.sh; do bash -n "$file" || exit; done; node --check "$1/scripts/monitor.mjs"' _ "$scratch/skills/teamsmith"
      flip_run "$mutation" "$scratch" "$groups"
      check "flip-$mutation-red" eq "$FLIP_RC" 1
      check "flip-$mutation-named-assertion" grep -q '^FAIL ' "$TMP/flip-$mutation.log"
      case "$mutation" in
        required-categories)
          check flip-required-categories-policy grep -q '^FAIL policy-custom-vocabulary-only$' "$TMP/flip-$mutation.log"
          check flip-required-categories-writer grep -q '^FAIL map-custom-vocabulary-write$' "$TMP/flip-$mutation.log"
          check flip-required-categories-upgrade grep -q '^FAIL upgrade-custom-vocabulary$' "$TMP/flip-$mutation.log"
          check flip-required-categories-selection grep -q '^FAIL new-selection-custom-vocabulary$' "$TMP/flip-$mutation.log" ;;
        identity-overclaim)
          check flip-identity-overclaim-record grep -q '^FAIL publication-record:model-only$' "$TMP/flip-$mutation.log"
          check flip-identity-overclaim-argv grep -q '^FAIL publication-record-equals-argv:model-only$' "$TMP/flip-$mutation.log"
          check flip-identity-overclaim-opaque grep -q '^FAIL publication-record:opaque$' "$TMP/flip-$mutation.log"
          check flip-identity-overclaim-claim grep -q '^FAIL publication-claim-gap:model-only$' "$TMP/flip-$mutation.log" ;;
        template-shadow) check flip-template-shadow-specific-worker grep -q '^FAIL template-refused:all-hardcoded:preview$' "$TMP/flip-$mutation.log"
          check flip-template-shadow-specific-pm grep -q '^FAIL pm-template-refused:provider:launch$' "$TMP/flip-$mutation.log" ;;
        template-unbound)
          check flip-unbound-worker-positional grep -q '^FAIL template-refused:positional-model:launch$' "$TMP/flip-$mutation.log"
          check flip-unbound-worker-data grep -q '^FAIL template-refused:data-sid:preview$' "$TMP/flip-$mutation.log"
          check flip-unbound-pm-positional grep -q '^FAIL pm-custom-missing-refused:positional-model:launch$' "$TMP/flip-$mutation.log"
          check flip-unbound-pm-data grep -q '^FAIL pm-template-refused:data-provider:preview$' "$TMP/flip-$mutation.log" ;;
        template-roles)
          check flip-role-worker-selector-as-data grep -q '^FAIL worker-role-refused:model:--skill:launch$' "$TMP/flip-$mutation.log"
          check flip-role-pm-selector-as-data grep -q '^FAIL pm-role-refused:provider:--skill:launch$' "$TMP/flip-$mutation.log"
          check flip-role-pm-resume-data grep -q '^FAIL pm-role-resume-refused:builtin:--skill --continue:launch$' "$TMP/flip-$mutation.log" ;;
        monitor-record-drift) check flip-monitor-record-drift-specific-nonce grep -q '^FAIL reader-monitor-unavailable:nonce$' "$TMP/flip-$mutation.log" ;;
        literal-shell-expansion)
          check flip-literal-shell-specific-worker-template grep -q '^FAIL worker-expansion-refused:template:model-glob:launch$' "$TMP/flip-$mutation.log"
          check flip-literal-shell-specific-worker-extra grep -q '^FAIL worker-expansion-refused:extra:model-glob:launch$' "$TMP/flip-$mutation.log"
          check flip-literal-shell-specific-pm-template grep -q '^FAIL pm-expansion-refused:template:model-glob:launch$' "$TMP/flip-$mutation.log"
          check flip-literal-shell-specific-pm-extra grep -q '^FAIL pm-expansion-refused:extra:model-glob:launch$' "$TMP/flip-$mutation.log" ;;
        pm-literal-resplit)
          check flip-pm-resplit-specific-extra grep -q '^FAIL pm-expansion-literal-argv:extra$' "$TMP/flip-$mutation.log"
          check flip-pm-resplit-specific-resume grep -q '^FAIL pm-resume-literal-argv:builtin$' "$TMP/flip-$mutation.log" ;;
        worker-literal-resplit)
          check flip-worker-resplit-specific-extra grep -q '^FAIL worker-expansion-literal-argv:extra$' "$TMP/flip-$mutation.log" ;;
        init-legacy-proceeds)
          check flip-init-legacy-proceeds-plain grep -q '^FAIL init-legacy-plain-refused$' "$TMP/flip-$mutation.log"
          check flip-init-legacy-proceeds-force grep -q '^FAIL init-legacy-force-refused$' "$TMP/flip-$mutation.log"
          check flip-init-legacy-proceeds-bootstrap grep -q '^FAIL init-legacy-bootstrap-refused$' "$TMP/flip-$mutation.log" ;;
        template-retired-key)
          check flip-template-retired-key-specific grep -q '^FAIL init-fresh-no-retired-key$' "$TMP/flip-$mutation.log" ;;
      esac
      cp -a "$SKILL/scripts/." "$scratch/skills/teamsmith/scripts/"
      restored="$(find "$scratch/skills/teamsmith/scripts" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)"
      check "flip-$mutation-source-restored" eq "$restored" "$before"
      printf 'CONTROL %s source_before=%s source_restored=%s\n' "$mutation" "$before" "$restored"
    done
    flip_run restored "$TREE" "$CORE"
    check flip-restored-all-green eq "$FLIP_RC" 0
  fi
fi
printf '\nRESULT pass=%s fail=%s selected=%s\n' "$PASS" "$FAIL" "$SELECT"
[ "$FAIL" = 0 ]
