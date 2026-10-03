#!/usr/bin/env bash
# Run ONLY inside a disposable container. Sources /src read-only; outputs /evidence.
#
# P163：从 P147/P157 的授权配方提升进夹具。两处有意改动（P163 的两条 finding）：
#   ① 现场单次性：读 run-case.sh 写的 run.json 运行戳，并在每个判据读的事件文件第一行写
#      run_start 标记；judge-second.py 靠这一对证据（+ run-start.txt 单次运行戳，P197）拒绝旧现场 /
#      跨次累积的现场。
#   ② 版本透传：P163_MODE/P163_PI_VERSION 由 run-case.sh 决定（host = 人工观察，judge 拒绝出判据）。
set -euo pipefail
[ "${P138_CONTAINER:-}" = 1 ] || { echo 'refused: container only'; exit 64; }
CASE=${1:-watch-dirty}; L=/evidence/logs/$CASE
RUN_ID=${P163_RUN_ID:-}
[ -n "$RUN_ID" ] || { echo 'refused: missing P163_RUN_ID (run through run-case.sh)' >&2; exit 65; }
[ -f "$L/run.json" ] || { echo "refused: $L/run.json missing (scene not cleared/stamped by run-case.sh)" >&2; exit 65; }
python3 - "$L/run.json" "$CASE" "$RUN_ID" <<'PY' || exit 65
import json, sys
run = json.load(open(sys.argv[1]))
for key, want in (('case', sys.argv[2]), ('run_id', sys.argv[3])):
    if run.get(key) != want:
        raise SystemExit(f'refused: run.json {key}={run.get(key)!r} != {want!r} (stale scene?)')
PY
SKILL=${P138_SKILL:-/src/skills/teamsmith}
mkdir -p "$L"
# 单次运行标记：判据读的文件第一行。judge-second.py 要求它的 id 与 run.json 完全一致。
MARK="{\"event\":\"run_start\",\"run\":\"$RUN_ID\",\"ts\":$(date +%s)}"
printf '%s\n' "$MARK" > "$L/dev-events.jsonl"
printf '%s\n' "$MARK" > "$L/pm-events.jsonl"
printf '%s\n' "$MARK" > "$L/requests.jsonl"
printf 'P163 case=%s run=%s mode=%s runtime=%s\n' "$CASE" "$RUN_ID" "${P163_MODE:-unknown}" "${P163_PI_VERSION:-unknown}" > "$L/run-start.txt"
R=$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-p163-real.XXXXXX"); mkdir -p "$R/sock" "$R/home" "$R/agentdir" "$R/bin"
export HOME="$R/home" PI_CODING_AGENT_DIR="$R/agentdir" TMUX_TMPDIR="$R/sock" TERM=xterm-256color
unset TMUX TMUX_PANE
for k in ${!TEAM_@}; do unset "$k"; done
export P138_LOG="$L"
python3 /evidence/pkg/mock-server.py >"$L/server.log" 2>&1 & SERVER_PID=$!
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmux kill-server 2>/dev/null || true
  kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true
  rm -rf "$R"
}
trap cleanup EXIT
CLI=${P138_PI_CLI:-/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js}
printf '#!/bin/sh\nexec node %q "$@"\n' "$CLI" > "$R/bin/pi"; chmod +x "$R/bin/pi"
export PATH="$R/bin:$PATH"
python3 - "$R/agentdir/models.json" <<'PY'
import json,sys
json.dump({'providers':{'p138':{'baseUrl':'http://127.0.0.1:18738/v1','api':'openai-completions','apiKey':'fixture-not-a-secret',
'models':[{'id':'p138','name':'P138 local fixture','reasoning':False,'input':['text'],'contextWindow':128000,'maxTokens':2048,
'cost':{'input':0,'output':0,'cacheRead':0,'cacheWrite':0}}]}}},open(sys.argv[1],'w'))
PY
mkdir -p "$R/proj"; cd "$R/proj"
git init -q -b main; git config user.name P138; git config user.email p138@fixture
printf 'init\n' > README; printf '.pi/team/state/\ndocs/team/inbox/\n.worktrees/\n' > .gitignore
mkdir -p .pi/team docs/team/inbox
cat > .pi/team/config.sh <<EOF
TEAM_SESSION=p138
TEAM_AGENTS=dev
TEAM_PM_WINDOW=pm
TEAM_PI_BIN=$R/bin/pi
TEAM_NOTIFY_TMUX=0
TEAM_NOTIFY_LOG=$L/notify.log
TEAM_REQUIRE_OPENSPEC=0
TEAM_REQUIRE_MAGIC_CONTEXT=0
EOF
git add .; git commit -qm init; git worktree add -qb task/P138 .worktrees/dev
WT="$R/proj/.worktrees/dev"
TEAM=(bash "$SKILL/scripts/team")
"${TEAM[@]}" paths > "$L/paths.txt"
pi --version > "$L/pi-version.txt"
launch() {
  local window=$1 cwd=$2 seed=$3 watcher=$4
  local args=(pi --no-session --session-dir "$R/sessions" --approve --no-extensions --no-skills --no-context-files
    --provider p138 --model p138 -e /evidence/pkg/observe.ts)
  [ "$window" != dev ] || args+=(-e "$SKILL/extension/team-notify.ts")
  if [ "$watcher" = yes ] && [ -f "$SKILL/extension/team-inbox-watch.ts" ]; then args+=(-e "$SKILL/extension/team-inbox-watch.ts"); fi
  [ -z "$seed" ] || args+=("$seed")
  local cmd; printf -v cmd '%q ' env "P138_EVENTS=$L/$window-events.jsonl" "TEAM_INBOX_WATCH_TARGET=p138:$window" "${args[@]}"
  if ! tmux has-session -t p138 2>/dev/null; then
    tmux new-session -d -s p138 -n "$window" -x 120 -y 32 -c "$cwd" "$cmd"
  else tmux new-window -d -t p138 -n "$window" -c "$cwd" "$cmd"; fi
}
wait_for() {
  local file=$1 needle=$2
  for i in $(seq 1 150); do grep -q "$needle" "$file" 2>/dev/null && return 0; sleep .2; done
  echo "TIMEOUT: $needle in $file"; tmux capture-pane -p -S -100 -t p138:dev || true; return 1
}
launch pm "$R/proj" '' yes
seed=P138-SEED-CLEAN; [[ "$CASE" != *dirty* ]] || seed=P138-SEED-DIRTY
watcher=yes; [[ "$CASE" != tmux-* ]] || watcher=no
launch dev "$WT" "$seed" "$watcher"
wait_for "$L/dev-events.jsonl" 'agent_settled'
sleep "${P138_SETTLE_DELAY:-1}"
( cd "$WT" && git status --porcelain ) > "$L/dirty-before.txt"
tmux capture-pane -p -S -100 -t p138:dev > "$L/dev-before.frame"
# sender runs in the fixture main root, not in the worker directory.
MSG="P138-SAY-$CASE"
if [ "${P138_LONG:-0}" = 1 ]; then MSG="$MSG $(printf '请核对未提交文件并报告检查结果。%.0s' {1..70})"; fi
printf '%s\n' "$MSG" > "$L/payload.txt"
set +e
"${TEAM[@]}" say dev "$MSG" > "$L/say.txt" 2>&1; SAY_RC=$?
set -e
printf 'say_rc=%s\n' "$SAY_RC" | tee "$L/result.txt"
sleep 4
"${TEAM[@]}" outbox list > "$L/outbox-after-say.txt" 2>&1 || true
if [[ "$CASE" = tmux-* ]]; then
  tmux display-message -p -t p138:dev '#{cursor_y}' > "$L/cursor-after-say.txt"
  P138_PROBE_SKILL="$SKILL" bash -c '
    . "$P138_PROBE_SKILL/scripts/lib/common.sh"
    . "$P138_PROBE_SKILL/scripts/lib/outbox.sh"
    team_load_config
    printf "verdict=%s\n" "$(team_delivery_verdict p138:dev)"
    printf "box_text=[%s]\n" "$(team_input_box_text p138:dev | tr "\n" "|")"
  ' > "$L/box-after-say.txt" 2>&1
fi
cp -a .pi/team/state "$L/state-after-say"
cp -a docs/team/inbox "$L/inbox-after-say"
tmux capture-pane -p -S -100 -t p138:dev > "$L/dev-after-say.frame"
# A second correction after the first real turn settled: false BUSY can strand it.
if [ "${P138_SECOND:-0}" = 1 ]; then
  tmux capture-pane -p -t p138:dev > "$L/second-before.frame"
  set +e
  "${TEAM[@]}" say dev "P138-SECOND-$CASE" > "$L/second-say.txt" 2>&1; SECOND_RC=$?
  set -e
  printf 'second_say_rc=%s\n' "$SECOND_RC" | tee -a "$L/result.txt"
  sleep 2
  "${TEAM[@]}" outbox flush > "$L/second-flush-1.txt" 2>&1
  sleep 2
  "${TEAM[@]}" outbox flush > "$L/second-flush-2.txt" 2>&1
  tmux capture-pane -p -t p138:dev > "$L/second-after.frame"
  "${TEAM[@]}" outbox list > "$L/second-outbox.txt" 2>&1
  cp -a .pi/team/state "$L/state-after-second"
fi
# P143 negative control: real editor draft, no submission; keep raw frames.
if [ "${P143_DRAFT:-0}" = 1 ]; then
  tmux send-keys -t p138:dev -l 'P143-HUMAN-DRAFT'
  sleep 1
  tmux capture-pane -p -t p138:dev > "$L/draft-before.frame"
  tmux display-message -p -t p138:dev '#{cursor_y}' > "$L/draft-cursor.txt"
  set +e
  "${TEAM[@]}" say dev "P143-DRAFT-GUARD-$CASE" > "$L/draft-say.txt" 2>&1
  DRAFT_RC=$?
  set -e
  printf 'draft_say_rc=%s\n' "$DRAFT_RC" | tee -a "$L/result.txt"
  sleep 1
  tmux capture-pane -p -t p138:dev > "$L/draft-after.frame"
fi
# notify <recipient> stores to recipient but knocks PM, NOT that worker.
set +e
if [ "${P138_OLD_NOTIFY:-0}" = 1 ]; then
  TEAM_NOTIFY_TMUX=1 "${TEAM[@]}" notify dev "P138-NOTIFY-$CASE" > "$L/notify.txt" 2>&1
else
  TEAM_NOTIFY_TMUX=1 "${TEAM[@]}" notify dev --from pm "P138-NOTIFY-$CASE" > "$L/notify.txt" 2>&1
fi
NOTIFY_RC=$?
set -e
printf 'notify_rc=%s\n' "$NOTIFY_RC" | tee -a "$L/result.txt"
sleep 4
"${TEAM[@]}" outbox list > "$L/outbox-final.txt" 2>&1 || true
cp -a .pi/team/state "$L/state-final"; cp -a docs/team/inbox "$L/inbox-final"
tmux capture-pane -p -S -100 -t p138:dev > "$L/dev-final.frame"
tmux capture-pane -p -S -100 -t p138:pm > "$L/pm-final.frame"
( cd "$WT" && git status --porcelain ) > "$L/dirty-after.txt"
python3 - "$L" <<'PY'
import json,sys,pathlib
p=pathlib.Path(sys.argv[1]); events=[json.loads(x) for x in (p/'dev-events.jsonl').read_text().splitlines()]
starts=[e.get('prompt','') for e in events if e['event']=='before_agent_start']
settled=[e for e in events if e['event']=='agent_settled']
print('dev_turns=',len(starts),'dev_settled=',len(settled))
print('dev_prompt_prefixes=',json.dumps([s[:160] for s in starts],ensure_ascii=False))
print('dev_editor_at_settle=',[e['editor'] for e in settled])
print('dirty_before=',(p/'dirty-before.txt').read_text().strip())
print('dirty_after=',(p/'dirty-after.txt').read_text().strip())
PY
printf 'Evidence: %s\n' "$L"
