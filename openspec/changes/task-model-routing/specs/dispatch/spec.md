## MODIFIED Requirements

### Requirement: A brief is self-contained and names its evidence

`team task <ID> --title <title> --agent <a> --category <category>` SHALL render `templates/task.md.tmpl` into
`docs/team/tasks/<ID>-<slug>.md` carrying the task id, the agent, exactly one `category:` header naming a project-mapped category, deliverables, explicit boundaries, copy-pasteable
acceptance commands and the report path; `team dispatch` SHALL reference that file in the prompt instead of
inlining the work. The prompt SHALL name category, complete model, original selection source, current launch source, SID and fresh/continued mode. A fresh takeover SHALL point at disk handover materials (goal, branch/code status, evidence and unresolved work), never reconstructed Pi history.

#### Scenario: A generated brief carries the contract

- **WHEN** `team task T1.1 --title "first task" --agent dev --category routine` runs in an initialised project
- **THEN** `docs/team/tasks/T1.1-*.md` exists and contains the acceptance section and the report path
  `docs/team/reports/T1.1-dev.md`

#### Scenario: The prompt points at the brief

- **GIVEN** a brief at `docs/team/tasks/T1.1-first-task.md`
- **WHEN** `team dispatch dev T1.1 docs/team/tasks/T1.1-first-task.md --print` runs
- **THEN** the rendered prompt contains that path as the single source of scope

#### Scenario: A brief outside the project is refused, `--print` included

- **GIVEN** a brief at `/tmp/outside-brief.md` and the project's main worktree at `<root>`
- **WHEN** `team dispatch dev T1.1 /tmp/outside-brief.md --print` runs
- **THEN** it exits non-zero, names `<root>`, and does not describe the path as repo-relative
- **AND** the same command without `--print` exits non-zero before any window is opened

### Requirement: Model concurrency limits are enforced before dispatch

`team dispatch` SHALL refuse to start a worker when the number of running agents on the same model has reached the
limit set in `TEAM_MODEL_LIMITS` (`<provider>/<model>=<n>`, `*` wildcards supported, `0` = unlimited) and MUST name
the model, the limit and the current count when judgeable. The input SHALL be the actual resolved launch model, including an explicit override or a recovered assignment. Only proven-live worker seats count; PM, dead/exited/absent panes do not. Replacing the target seat counts it once after replacement, not both the old and new launch. Exact rules precede wildcard rules; wildcard groups count their other matching workers, and the strictest matching positive wildcard limit applies. Unmatched models and 0 remain unlimited. For a target with an applicable positive limit, a proven-live peer in this project whose complete committed model identity is missing, legacy, incomplete or malformed SHALL make admission unjudgeable and refuse, in preview and real calls even with `--force`. Such a peer cannot be excluded from an exact/wildcard group or counted as zero by guessing from a partial model field, future category policy or retired seat presets. The diagnostic SHALL name target model/rule/limit, the unknown peer and record defect, distinguish known occupancy from unknown occupancy, and print a project-local correction route: explicitly fresh-dispatch that peer with a valid brief, or explicitly stop only that named project's worker through the existing lifecycle command before retrying. No automatic cleanup, record fabrication or other-project operation is allowed. A target being replaced is excluded from the old peer set and counted once at its known planned model. A positive clean dead/exited/absent determination excludes a peer regardless of missing model identity; PM never enters this set. If the actual target has no positive limit under the existing exact/wildcard/0 rules, unknown peers do not create a model-budget refusal. No automatic downgrade or cross-model retry is permitted. Final worker admission counts and launch-to-proof publication SHALL be serialized across seats so concurrent accepted previews cannot oversubscribe a limit.

#### Scenario: The limit is reached

- **GIVEN** `TEAM_MODEL_LIMITS='kimi-coding/k3=1'` and one running agent already on `kimi-coding/k3`
- **WHEN** a second dispatch on the same model runs
- **THEN** it exits non-zero and prints the model, the limit and the running count

#### Scenario: Zero means unlimited

- **GIVEN** `TEAM_MODEL_LIMITS='kimi-coding/k3=0'` and one running agent on that model
- **WHEN** another dispatch on the same model runs
- **THEN** the model guard does not refuse the dispatch

#### Scenario: Actual model, wildcard group and replacement determine the count
- **GIVEN** a category policy different from the assigned/explicit model, an exact rule and overlapping wildcard rules, one proven-live peer, stopped/dead/absent peers and a live PM
- **WHEN** overrides, assignment recovery and same-seat replacement are checked at their applicable limit
- **THEN** count/diagnostic use actual model, exact priority or strictest shared wildcard positive limit, count a replaced target only once, exclude stopped peers and PM, and refuse a full group before state changes

#### Scenario: Two seats cannot claim the same final slot
- **GIVEN** an applicable worker limit of one and two concurrent dispatch attempts on different seats
- **WHEN** both pass their initial reads with zero live workers
- **THEN** final admission/proof is serialized; one proven-live launch succeeds, the other reports the new count and refuses without window/assignment/board changes

#### Scenario: A live unknown-model peer blocks limited admission
- **GIVEN** target strong model limit 1 and another worker proven live by current PID/nonce evidence, but with missing, legacy, incomplete or malformed model assignment in equivalent fixtures
- **WHEN** exact-rule and positive-wildcard target admission run as preview and real dispatch, with and without force
- **THEN** each refuses before effects, names that peer and record defect plus target rule/limit, reports model occupancy unjudgeable rather than count 0/pass, gives a concrete project-local fresh takeover or named-worker teardown route, and does not infer a model from partial/retired/future policy

#### Scenario: Unknown peer identity does not make dead workers or PM occupy slots
- **GIVEN** the preceding fixture, then equivalent fixtures where the peer is positively stopped/dead/exited/absent or is the PM
- **WHEN** limited admission is checked
- **THEN** the live unknown worker blocks, while each non-worker/non-live control occupies no slot; an explicitly authorized local stop of the named worker followed by retry clears the unknown-occupancy blocker without deleting its worktree/branch/history or changing other projects
- **AND** an exact 0 or unmatched unlimited target does not fabricate an occupancy count or acquire a budget blocker merely because a live peer's model is unknown

### Requirement: A dispatch proves the agent started, or fails loudly

`team dispatch` SHALL report success only when the window harness recorded **this round's** launch proof: the file
`state/dispatch-<agent>.spawn` MUST begin with the nonce minted for this attempt and the pane shell's pid, so a
record left behind by an earlier round never counts. "The harness came up" MUST NOT be reported as "the agent is
running": the agent's exit MUST be read from the event file `state/dispatch-<agent>.exit`, written by the harness
after the agent returns and carrying the same nonce, never from sampling the pane. When no proof arrives the
dispatch SHALL retry once, kill the leftover window (no half-started window may outlive the failure) and exit
non-zero naming the missing evidence. On the custom-adapter path an agent that exits non-zero within
`TEAM_DISPATCH_ALIVE_SEC` (default 1 s) SHALL fail the dispatch with the real `exit=<code>` and MUST leave
`state/dispatch-<agent>-launch-failed.log` holding the rendered command, the resolved binary, the exit code and the
window tail, without writing a task record; the built-in Pi path keeps its older contract, where a short-lived
`TEAM_PI_BIN` is reported honestly instead of failing the dispatch. A successful launch SHALL atomically publish the complete versioned assignment described by this capability; a failed attempt leaves the previous assignment byte-identical and cannot advertise success. Launch evidence and failed diagnostics remain separate from committed assignment state. Why each piece is evidence and not inference:
`references/agent-adapters.md` §3 and `references/troubleshooting.md`.

#### Scenario: A wedged window is a failure, not a success

- **GIVEN** a tmux whose `new-window` returns success but never runs the command (the process wedges before reading
  its input)
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, states that the start could not be confirmed instead of printing a success line, and
  retries exactly once
- **AND** the leftover window is really killed, so the window's final state is "does not exist"

#### Scenario: A stale exit record is not this round's evidence

- **GIVEN** `state/dispatch-dev.exit` holds a record from an earlier dispatch whose nonce is not this round's
- **WHEN** the agent of this round is still running
- **THEN** the dispatch does not report that the agent already exited, and only an exit record carrying this
  round's nonce yields `exit=<code>`

#### Scenario: The exit code comes from the event file, not from the pane

- **GIVEN** a built-in Pi fixture whose CLI exits 3 right after the launch proof
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** the dispatch still reports success (the launch proof is real) and states the observed exit code 3 and
  that the agent has already exited
- **AND** `state/dispatch-dev.exit` exists and carries this round's nonce and that code

#### Scenario: An adapter that exits non-zero fails the dispatch with diagnostics

- **GIVEN** a `TEAM_AGENT_CMD` whose CLI prints an error and exits 7
- **WHEN** `team dispatch dev T1.1 <brief>` runs
- **THEN** it exits non-zero, prints `exit=7`, and names `state/dispatch-<agent>-launch-failed.log`
- **AND** that file holds the rendered command, the resolved binary, the exit code and the CLI's own error text
- **AND** no task record is written for the failed dispatch

### Requirement: A dispatch refuses a session the model's window cannot hold

When a dispatch would resume an existing session, `team dispatch` SHALL compare the session's estimated size
(JSONL bytes ÷ 4 — a deliberately coarse estimate) against the actual resolved launch model's context window and MUST refuse to
start when the estimate exceeds it, naming the session file, the estimate and the window. `--fresh` (a new,
uniquely identified session id) and `--allow-overflow` (an explicit, loud override) SHALL be the two ways through, and the
guard MUST also run for `--print` so no window is planned around a session that cannot fit. The window SHALL be
resolved from `TEAM_MODEL_WINDOWS` (`<provider>/<model>=<tokens>`, matching either the full name or the bare model
name) first and from the model catalogue second; when neither resolves it, the guard MUST use the conservative
threshold `TEAM_SESSION_WARN_TOKENS` (default 200000) and say that the window could not be resolved. `team roster`
and `team ps` SHALL show the estimate next to the model as `used/window`. The measured file SHALL match the committed assignment SID and worktree, not the seat base SID or latest neighboring session. Displays SHALL stat that file on each read; `sid_bytes` is only a launch snapshot. A known fresh SID with no file yet reads 0; missing/untrusted assignment identity reads unavailable, not a fabricated 0. Model-change restrictions still apply even for a wider window and cannot be bypassed by `--allow-overflow`. Why reuse is the dangerous case (a
361k-token session under a 272k window wedges while `roster` still shows a running agent): `references/protocol.md`.

#### Scenario: A big session with a small-window model is refused

- **GIVEN** a session whose file size estimates ~400k tokens and a model `sub2api/gpt-5.6-sol` with a 272000-token
  window
- **WHEN** `team dispatch dev T1.1 <brief> --model sub2api/gpt-5.6-sol` runs
- **THEN** it exits non-zero, names the estimate and `272000`, explains the estimate (`JSONL bytes ÷ 4`) and offers
  both `--fresh` and `--allow-overflow`
- **AND** the same command with `--print` is refused by the same guard before printing a plan

#### Scenario: A wider window may reuse the same session

- **GIVEN** the same session and the committed assignment model whose window is larger than the estimate
- **WHEN** the dispatch resumes that same assigned model
- **THEN** it proceeds and reuses the same session id

#### Scenario: An unresolvable window falls back to the conservative threshold, and says so

- **GIVEN** a model that neither `TEAM_MODEL_WINDOWS` nor the model catalogue resolves, and a session larger than
  `TEAM_SESSION_WARN_TOKENS`
- **WHEN** the dispatch runs
- **THEN** it exits non-zero and says the window could not be resolved, printing the conservative threshold it used

#### Scenario: `--fresh` and `--allow-overflow` are the two explicit ways out

- **GIVEN** the over-large session of the first scenario
- **WHEN** the dispatch runs with `--fresh`
- **THEN** it proceeds with a new, uniquely identified session id, so the reused history is not what the agent loads
- **AND** with `--allow-overflow` it proceeds under a loud warning that the over-large session was explicitly
  allowed, instead of passing silently

#### Scenario: `TEAM_MODEL_WINDOWS` overrides the catalogue

- **GIVEN** `TEAM_MODEL_WINDOWS` that gives the selected model a window larger than the estimate
- **WHEN** the dispatch runs
- **THEN** the guard accepts the session even though the catalogue would have refused it

#### Scenario: roster and ps show the estimate against the window

- **GIVEN** the same over-large session and a configured window of 272000
- **WHEN** `team roster` and `team ps` run
- **THEN** both show the agent's estimate as `400k/272k`, and `roster` explains that the figure is
  "estimated tokens / model window"

### Requirement: The roster changes only through an explicitly authorized registration

`team add-agent <agent> [--register] [--create|--no-install|--print]` SHALL be the
only CLI route that grows `TEAM_AGENTS`, and `team teardown --agent <agent> --register` the only one that shrinks
it. Both SHALL write through the project contract's one writer, with the roster key's value rule, its fingerprint
CAS and its audit (`memory-and-deps`: "The project contract has exactly one writer, and it preserves what it does
not change"), and `TEAM_AGENTS` SHALL keep class `refuse`. `team add-agent <agent>` for a seat the roster does not
carry and without `--register` SHALL exit 5, name the two routes that really work (hand-editing
`.pi/team/config.sh`, or re-running with `--register`), and MUST NOT open a window, create a worktree, write state
or touch the contract. `--register` for a seat the roster already carries SHALL be a visible no-op (exit 0, no
write, no audit line) — and, because the value rule is not waived by the no-op path, a roster whose current value
violates that rule (a hand-edited duplicate or an illegal token) SHALL instead exit 4 naming the offending token
before any worktree or state is touched. `team teardown --register` SHALL require `--agent` (`--all --register` is a usage error,
exit 2) and SHALL refuse a seat the roster does not carry (exit 5 naming the roster, nothing written). Both
entries SHALL accept `--fingerprint <sha256>` with `team config set`'s semantics, and their own read-modify-write
SHALL pass the fingerprint of the bytes they read. A seat name the roster's value rule refuses (whitespace, `/`,
`pm`) SHALL exit 4 **before any write** — the roster byte-identical and no `result=ok` line — never a written
roster with a later worktree failure. Seat registration SHALL NOT choose a model, pre-write a model/source/SID or overwrite an existing assignment. The retired `add-agent --model` flag SHALL exit 2 with a category-policy editing route before any write, even with `--register`. `team help`'s `add-agent` line SHALL print `--register`, `--create`, `--no-install` and `--print`, not `--model`, and `teardown`'s line SHALL print `--register`.

#### Scenario: `--register` grows the roster as one audited write

- **GIVEN** a fixture project whose roster line is `TEAM_AGENTS="dev verify"` among comments and other keys
- **WHEN** `team add-agent api --register --no-install` runs
- **THEN** it exits 0, `diff` shows exactly one changed line reading `TEAM_AGENTS='dev verify api'` (the
  writer's canonical single-quoted form), `bash -n`
  exits 0, and `<state>/config.log` gained exactly one `result=ok actor=cli` line naming `TEAM_AGENTS`
- **AND** the printed worktree step is the one `add-agent api --no-install` prints for a seat already in the roster

#### Scenario: The flagless refusal names two routes, and both work

- **GIVEN** the same contract and the sha256 recorded
- **WHEN** `team add-agent api` runs
- **THEN** it exits 5, the message carries `--register` and `.pi/team/config.sh`, the sha256 is unchanged, and no
  window, worktree or state record for `api` exists
- **AND** hand-editing the roster line to `TEAM_AGENTS="dev verify api"` makes `team add-agent api --no-install`
  print the worktree step instead of refusing — the hand edit is the second route, not a fallback that also fails

#### Scenario: Re-registering is a no-op and a stale fingerprint refuses

- **GIVEN** the contract of the first scenario after `api` joined, and its sha256
- **WHEN** `team add-agent api --register` runs again
- **THEN** it exits 0, prints that `api` is already in the roster, the sha256 is unchanged and `config.log` gained
  no line
- **AND** GIVEN a fingerprint read before another writer changed the file, `team add-agent api2 --register
  --fingerprint <stale>` exits 3, names the changed file, writes nothing and appends one `result=conflict` line

#### Scenario: Teardown removes a seat through the writer, and only on request

- **GIVEN** the same contract with `api` in the roster and `api`'s window and state present
- **WHEN** `team teardown --agent api --register` runs
- **THEN** the roster line reads `TEAM_AGENTS='dev verify'` with every other byte unchanged, one `result=ok`
  `actor=cli` line names `TEAM_AGENTS`, and the window/state cleanup of a plain `teardown --agent api` happened too
- **AND** `team teardown --agent api` (no flag) leaves the roster byte-identical (today's behaviour is the default),
  `team teardown --all --register` exits 2 without touching anything, and `team teardown --agent nosuch --register`
  exits 5 naming the roster with the sha256 unchanged; a name that is only a concatenation of two roster tokens
  (`api 1` where the roster carries `api` and `1`) is not a seat either — exit 5, byte-identical, no `result=ok`
  line (the pre-change membership test matched it across tokens and reported a successful removal of nothing)

#### Scenario: `--model` is the seat's configured model, not a per-run choice

- **WHEN** the retired `team add-agent dev --model vendor/m2 --no-install` runs
- **THEN** it exits 2, names `team config set-task-model` as the replacement policy route, writes no model or assignment, and opens no window

#### Scenario: A predictable model error writes nothing, and a retry completes

- **GIVEN** a recorded contract fingerprint and roster `dev verify`
- **WHEN** `team add-agent api --register --model vendor/m2` runs
- **THEN** it exits 2 before registration with contract/state/roster unchanged
- **AND** retrying without `--model` registers api with one roster audit and no model assignment

#### Scenario: The help lines print the register route

- **WHEN** `team help` runs
- **THEN** the `add-agent` line carries `--register`, `--create`, `--no-install` and `--print`, and the
  `teardown` line carries `--register`
- **AND** the pre-change lines are this check's red side: `add-agent` printed `[--model m]` (a flag the parser
  refused) and neither line mentioned registration at all

### Requirement: The printed route is a route that works

The project's correctness gate SHALL carry a route-sincerity walk (`bash skills/teamsmith/tests/routes.sh`, run by
the correctness gate's `smoke.sh` and runnable standalone) that judges the CLI's printed surface against the CLI's
real one:

- For every usage line of `team help`, every `--flag` the line prints MUST be accepted by that command's own
  parser: the walk runs the command with that flag in a fixture project and fails, naming the command and the
  flag, when the parser answers with the tool's unknown-parameter refusal (for a command that only execs another
  program, the walk reads that program's own argument table instead — declared with the file and the reason). A
  flag only a sibling command accepts MUST NOT satisfy the line. A usage line the walk cannot attribute to a
  command and its flags MUST fail naming the line — an unparsable line is never skipped.
- For every command whose line prints at least one flag, an unknown flag (`--frobnicate-probe`) MUST be refused:
  a command that swallows unknown arguments fails naming the command. This is the walk's non-vacuity control —
  without it, a printed flag that is quietly ignored reads as accepted.
- For every schema note that names a `team` command, that command MUST resolve in the CLI, and the sentence's
  promise MUST really happen in the fixture through a declared promise probe; the set of keys needing a probe is
  derived from the schema, not from a hand-kept list, so a note naming a command with no probe fails naming the
  key, and a named command the CLI does not carry fails naming the key and the command. The probes assert
  effects, not exit codes: the roster's probe changes `TEAM_AGENTS` and writes its audit line, a category's probe
  writes the category token, the pulse window's probe makes the backend's recorded window call carry the key's value,
  and the model keys' probes make the next new task's rendered command carry the new model while same-task recovery keeps its assignment.
- For every refusal route the CLI prints (`修法：<command>` and `改行：<exact line>`), the walk SHALL apply the
  printed route in a fixture and re-run the command that refused. A clearing route — a `改行：` line, or a command
  that removes the condition (a `git switch`, a `git worktree add`) — MUST make that blocker disappear; an
  override route (`--force`, `--fresh`, a configuration knob) MUST be honored: the re-run proceeds under that
  route's own contract (its warning, and for a real launch its audit line), so a printed route can never be a
  line the tool itself refuses. A route that no longer clears its blocker, or is no longer honored, fails naming
  the family and the route. The families the walk exercises are declared in the walk itself (fixture → expected
  blocker → printed route kind → expected effect); a `修法：`/`改行：` family with no entry fails naming the
  family, so no printed route can go quietly unexercised. A `改行：` route is applied by writing that exact line
  into the brief header; a `修法：` route is applied by running it, inside the fixture, under the walk's recording
  `tmux` shim and its hard timeout.

The walk MUST NOT touch anything outside its own scratch fixtures: every command it runs runs in a fresh git
repository under `$TMPDIR` with a recording `tmux` shim first on `PATH`, `TEAM_MEETINGS_DIR` inside that fixture,
`stdin` from `/dev/null` and a hard timeout; it removes every directory it creates; it prints one line per usage
line, per probe and per refusal route (never a silent skip) and exits 0 only when every line, control, probe and
route is green.

#### Scenario: The committed tree is green

- **WHEN** `bash skills/teamsmith/tests/routes.sh` runs on this tree, and the correctness gate runs
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
- **THEN** both exit 0, the walk prints one `ok` line per usage line it parsed, one per probe and one per refusal
  route (never a silent skip), and no `bad` line

#### Scenario: The field defect is caught, with the command and the flag named

- **GIVEN** a scratch tree whose `add-agent` help line incorrectly prints retired `[--model m]` while its parser refuses it with exit 2
- **WHEN** the walk runs against it
- **THEN** it exits non-zero and names `add-agent` and `--model`, and the other usage lines stay green

#### Scenario: A sibling command's flag does not satisfy the line

- **GIVEN** a scratch tree whose `add-agent` help line prints `[--fresh]` — a flag `dispatch` really accepts,
  `add-agent` does not
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `add-agent` and `--fresh`

#### Scenario: A command that swallows unknown flags fails the control

- **GIVEN** a scratch tree whose `ps` parser no longer refuses unknown arguments (today's measured shapes are
  `version` and `meeting list`, which accept them and run)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `ps`

#### Scenario: A command-block line the walk cannot attribute is a failure

- **GIVEN** a scratch tree whose command block carries a line at column 0 that no command owns while it prints a
  flag (the pre-fix `board add|assign|set|row|ls … [--allow-dup]` shape — measured: `cmd-project.sh:32` is not
  indented, so an indentation-based parse would skip it and leave `--allow-dup` unjudged)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that line instead of skipping it

#### Scenario: A schema route naming a command that does not exist fails

- **GIVEN** a scratch tree whose `TEAM_GATES` note names `team frob off`
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_GATES` and `team frob`

#### Scenario: A schema note naming a command without a promise probe fails

- **GIVEN** a scratch tree whose schema gains a key whose note names `team config set-task-model` while no probe
  entry covers that key
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the added key as a note that names a command without a promise probe, naming
  no other key

#### Scenario: A broken promise is a failure, not a warning

- **GIVEN** a scratch tree whose roster registration no longer changes `TEAM_AGENTS` (the write path is broken
  while the command still exits 0)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming `TEAM_AGENTS`'s probe — the probes assert the effect, so a command that
  reports success without doing the sentence's work cannot pass

#### Scenario: The walk leaves the caller alone

- **WHEN** the walk finishes
- **THEN** no directory it created remains under `$TMPDIR`, the caller's project (`docs/team`, `.pi/team/state`,
  `git status`) is unchanged, and the real tmux session was never its target (every tmux call came from its shim)

#### Scenario: The new flag is a printed route like any other

- **GIVEN** the committed tree's `dispatch` usage line prints `--branch <name>` (the pre-change line did not, and
  the pre-change parser answered `✗ dispatch: 未知参数 --branch`, measured)
- **WHEN** the walk runs
- **THEN** the `dispatch` line's `--branch` claim is probed against the dispatch parser and stays green, and the
  sibling-flag and unknown-flag controls still hold

#### Scenario: A printed fix that stops clearing its blocker fails the walk

- **GIVEN** a scratch tree whose branch-refusal route prints a `git switch` to a branch that belongs to another
  task (the fixed command no longer clears the branch blocker)
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming the refusal family and that route, while the other families stay green

#### Scenario: Applying every printed route clears the composite refusal

- **GIVEN** the committed tree's composite clearing fixture (a malformed `change:` line, a malformed `deltas:`
  line and a worktree on another task's branch)
- **WHEN** the walk applies every `改行：` line and every clearing `修法：` command the refusal printed
- **THEN** the re-run of the same dispatch no longer reports any of those blockers

#### Scenario: An override route is honored, not just printed

- **GIVEN** the unfinished-previous-task family, whose printed route is the re-dispatch with `--force`
- **WHEN** the walk applies that printed route
- **THEN** the re-run proceeds under the override's own contract (the warning naming the task it overrides), and
  the walk records the family as honored instead of as cleared

#### Scenario: A printed route family with no walk entry fails

- **GIVEN** a scratch tree whose refusal prints a `修法：` route for a family the walk has no entry for
- **WHEN** the walk runs against it
- **THEN** it exits non-zero naming that family instead of skipping it

### Requirement: A refused dispatch hands over every blocker, once, with a fix that runs

Before any window is opened — and for `--print` as well — `team dispatch` SHALL judge every pre-launch guard it can
decide without side effects in one pass, and it SHALL report **one** refusal listing every blocker it found. A
refused dispatch MUST NOT open a window, switch a branch, write state or change any board status.

The set judged this way is the guards that today refuse one after another: the brief's header rules (`change:`
shape, unique legal `category:` with mapping membership required for new selection rather than trusted same-task recovery, the change-less anchor, `deltas:` shape and single-writer, verification independence), the task and
worktree state (more than one brief for the id, an unfinished previous task, a missing worktree, a dirty worktree,
the branch identity), and the launch preconditions (the capacity floor, model concurrency, the session-vs-window
check, the agent executable, routing-config validity, assignment identity, required fresh takeover and conflicting extra arguments). Routing and identity blockers are non-overridable; `--force`/`--allow-overflow` never waive them. A proven-live peer with unjudgeable model identity makes positive-limit admission unjudgeable as specified by the concurrency requirement; this is a blocker, not a passed zero-count guard. Resolution-dependent guards SHALL report unjudgeable when category/model/SID cannot resolve, while independent branch/capacity guards still run. A guard that cannot be judged because its precondition is missing SHALL say so in
the report and MUST NOT be reported as passed.

The refusal opens with the first blocker's own first line (there is no separate banner) and ends with a line
stating how many blockers were found. Each blocker is one item that names the artifact it is about (brief path,
worktree, seat, model or session), the reason, and at least one fix printed on its own line:

- `修法：<command>` — a command the PM can paste and run, with concrete values (a worktree path, a branch name, a
  task id), never a placeholder;
- `改行：<exact line>` — the exact brief header line to write, for blockers whose fix is a header value.

`--force` keeps each guard's own semantics: with `--force`, a blocker that guard allows to be overridden is
printed as a warning and yields exactly one audit line in `state/watchdog.log` — written only after a launch
really happened, and never for `--print`; a blocker with no override still refuses. Without `--force`, an
overridable blocker is a refusal item like any other. Runtime failures after the preflight (no launch proof, an
adapter exiting non-zero) stay governed by `dispatch#A dispatch proves the agent started, or fails loudly`.

#### Scenario: Every known blocker is handed over in one refusal

- **GIVEN** a brief whose `deltas:` value is malformed, a worktree parked on another task's branch, an unfinished
  previous task recorded for the seat, and a board row for the task
- **WHEN** `team dispatch dev P200 <brief>` runs
- **THEN** the single invocation exits non-zero and its output names all three blockers, each with its artifact
  and reason, ends with a line counting 3, and carries at least one `修法：` or `改行：` line per blocker
- **AND** no window was requested, `state/<agent>.env` is unchanged and the board row is unchanged

#### Scenario: Applying the printed fixes in one pass clears the refusal

- **GIVEN** a fixture whose blockers are all clearing routes: a malformed `change:` line, a malformed `deltas:`
  line and a worktree parked on another task's branch
- **WHEN** every printed `改行：` line is written into the brief and the printed `git switch` command is run inside
  the fixture
- **THEN** the next `team dispatch dev P200 <brief>` exits 0 and none of those blockers is reported

#### Scenario: `--print` prints the same refusal and no prompt

- **GIVEN** the same three-blocker fixture
- **WHEN** `team dispatch dev P200 <brief> --print` runs
- **THEN** it exits non-zero, prints the same three blockers and no `=== 提示词 ===` section

#### Scenario: `--force` keeps the audit contract under several blockers

- **GIVEN** a fixture whose only blockers are overridable (a change-less brief with no anchor, a delta
  single-writer conflict and an unfinished previous task)
- **WHEN** `team dispatch dev P200 <brief> --force` really starts the worker (the record-only tmux shim the smoke
  suite uses)
- **THEN** it proceeds with one warning per overridden blocker and `state/watchdog.log` gains exactly one line
  per overridden blocker
- **AND** the same command with `--print --force` writes no audit line

#### Scenario: An unjudgeable guard is named, not reported as passed

- **GIVEN** the same fixture with the worktree directory removed while an unfinished previous task is recorded
- **WHEN** the dispatch runs
- **THEN** the refusal carries the missing-worktree blocker with its `git worktree add` fix and says the branch
  identity could not be judged, instead of claiming the branch was checked

## ADDED Requirements

### Requirement: A task declares one project category and new dispatch selects its model explicitly

A brief SHALL declare exactly one `category:` header token matching `[a-z][a-z0-9-]*`. For first selection, a new task or a fresh takeover that must reselect from changed/untrusted identity, its category SHALL be present in the current project mapping even with an explicit model. Missing, duplicate (even identical), empty or malformed declarations always refuse before any side effect and in preview as well; an unmapped declaration refuses new selection but does not invalidate trusted unchanged same-task recovery as defined below. Phase and seat SHALL NOT infer category; dispatch has no category override flag. `team task --category <token>` SHALL validate and render that header; omission refuses generation. Initial examples routine/analysis/verify do not close the engine vocabulary.

A new task SHALL resolve a complete model token from explicit `--model` when present, otherwise its mapped category, and SHALL mint a new unique SID even if the previous task used the same model. Explicit model selection does not waive category/configuration validation or other dispatch guards. Model syntax is the shared provider/model shape; thinking suffix is preserved verbatim, not interpreted for compatibility. No classifier, automatic fallback, downgrade or cross-model launch retry is permitted. Preview SHALL display category, policy model, actual complete model, original selection source (`policy` or `explicit`), current launch source and fresh/continued identity.

#### Scenario: Category faults refuse without launching
- **WHEN** missing, duplicate and malformed category briefs, and new-selection briefs with unmapped categories, are dispatched, with and without `--print --force`
- **THEN** each names the offending header and accepted mapped category correction, exits non-zero, writes no prompt/assignment/board/window and still reports independent preflight blockers

#### Scenario: Categories are project-defined and not seat-defined
- **GIVEN** mapping `maintenance=vendor/light analysis=vendor/strong:high` and legal briefs
- **WHEN** maintenance is dispatched on two different seats and analysis later on either seat
- **THEN** maintenance selects vendor/light on both seats, analysis selects vendor/strong:high, with new SID per new task and no seat preset lookup

#### Scenario: An override retains category and original provenance
- **WHEN** a routine brief is dispatched with `--model other/vendor/model:custom`
- **THEN** captured argv and assignment carry the whole override, category routine, selected_via explicit and launch_via explicit; no thinking vocabulary judgement or compatibility claim occurs

#### Scenario: Generated tasks require a mapped category
- **WHEN** `team task T1 --title first --agent dev --category maintenance` runs with maintenance mapped, then generation is tried without category and with an unknown one
- **THEN** the first writes exactly one category header; the others refuse with no new brief/board row

### Requirement: Same-task recovery preserves the full committed launch identity

Same-task dispatch, `resume --agent`, `resume --all` and `up --agents` SHALL use the complete committed assignment's category/model/SID rather than new policy resolution. Required identity SHALL include version, task, canonical brief path and category, actual branch, canonical worktree, seat/window, complete model, original selection source, launch source, SID, current launch nonce/time and launch-time byte snapshot (empty if unreadable). Brief path, category, task, branch and worktree must still match. Description/acceptance edits do not invalidate identity. Original selection source stays distinguishable from launch_via `assignment`. The overall current routing configuration must remain complete and valid, but membership of a recorded category in its future mapping is not a recovery identity check. Changing or removing that category's mapping SHALL leave trusted unchanged same-task recovery's category, complete model, SID and original selection provenance intact. This includes same-assigned-model fresh takeover without a new override (with a new SID); explicit same-model continuation retains model/SID while recording explicit selection as specified below. It does not turn a new task or changed/untrusted identity into a mapped selection. A different explicit model remains subject to fresh and current mapped-declaration validation. Legacy/incomplete/malformed/mismatched records refuse with an actionable same-task `dispatch ... --fresh` handover route; no partial record is upgraded by guessing.

Same-task `--fresh` without `--model` retains assigned model and original selection provenance. An explicit `--model` records explicit provenance even when selecting the same complete token; it may continue that token's SID without fresh, while fresh allocates a new SID. Any complete-model change, thinking suffix included, SHALL require `--fresh`; `--force`/`--allow-overflow` do not waive it. Fresh takeover of a legacy/incomplete/malformed or changed identity revalidates the current brief/config and guards, selects explicit override or current category policy (never guesses from the unusable record), uses a different unique SID and points to disk handover; old history/code/evidence is preserved. No message or reasoning block is replayed or transformed. Plain resume has no model/fresh selection side channel. Dry-run SHALL resolve the same guards/plan as resume without launching or writing even missing-brief notifications.

#### Scenario: Override and fresh survive every recovery entry
- **GIVEN** an explicit override plus fresh launch, a stopped worker and a subsequently changed category mapping
- **WHEN** same-task dispatch, resume --agent, resume --all and up --agents are tested in equivalent fixtures
- **THEN** captured launch argv retains the identical full model and SID, selected_via explicit and launch_via assignment, with a new launch nonce only; a later new task uses the new mapping

#### Scenario: Removing a future category preserves a trusted same-task assignment
- **GIVEN** a complete routine task assignment selected explicitly as vendor/strong:high with SID A and unchanged task/brief/category/branch/worktree, then a valid nonempty project mapping containing only analysis/verify and a valid independent PM model
- **WHEN** same-task dispatch, resume --agent, resume --all and up --agents run in equivalent stopped-worker fixtures, with preview counterparts
- **THEN** recovery uses category routine, vendor/strong:high, SID A and original selected_via explicit with launch_via assignment, no forced fresh/header edit/reselection; current-policy display reports routine unmapped without fabricating a policy model
- **AND** another new routine task, even with explicit override or force, refuses as unmapped before effects; same-model fresh on the complete original identity retains model/category/origin but allocates a different SID

#### Scenario: Legal category deletion is not a waiver for invalid overall config or changed identity
- **GIVEN** the complete assignment of the preceding scenario
- **WHEN** the entire mapping becomes empty/missing/invalid, independent PM policy is missing/invalid or retired routing keys are present
- **THEN** ordinary recovery and preview refuse before effects; they do not treat malformed configuration as the legal deletion case
- **AND** changing the original brief category/task/path, branch or worktree still fails identity checks; explicit model/suffix changes require fresh plus a currently mapped declaration rather than old-seat/default inference

#### Scenario: A model or suffix change needs explicit fresh
- **WHEN** a same-task model/provider change or only a thinking-suffix change is tried without fresh, including with force/allow-overflow
- **THEN** it refuses before writes/launch; adding fresh succeeds with a different SID and later resume preserves that new identity

#### Scenario: Same-model fresh is unique even within a second
- **WHEN** two successful same-model fresh takeovers occur within one timestamp second
- **THEN** their SIDs differ from each other and the old SID; captured prompts name disk handover and do not contain copied session history

#### Scenario: Untrusted identity refuses rather than silently reselecting
- **WHEN** records are legacy, truncated, unknown-version or mismatch task/brief/category/branch/worktree
- **THEN** normal recovery refuses with the specific mismatch and concrete correction/fresh route; explicitly correcting the brief and taking fresh permits launch without rewriting old materials

#### Scenario: Dry recovery is genuinely read-only and fails honestly
- **WHEN** resume --dry-run is run for valid, missing-brief, broken-assignment and changed-model policy fixtures
- **THEN** output carries the exact recoverable model/SID or refusal, no state/prompt/thread/inbox/config/board timestamps change and a requested blocked recovery exits non-zero

### Requirement: Launch assignments are complete transactions and previews cannot mutate launch state

Dispatch SHALL serialize the target seat's launch decision through proof and assignment publication and serialize final worker admission across seats. It SHALL recheck the pinned assignment and routing fingerprint before any window replacement; a concurrent change refuses or recomputes before launch, never launches a stale plan. After this round's nonce proof and the existing launch-success judgement, the complete assignment SHALL replace its predecessor atomically. A failed proof/launch/publication SHALL exit non-zero without publishing partial identity, leave the old assignment byte-identical, stop any uncommitted new worker and retain diagnostic launch evidence. Interruption before publication leaves no usable new assignment; recovery SHALL detect nonce disagreement or outstanding interrupted-launch evidence and require fresh takeover rather than inherit the old identity. Board wip follows committed identity; a failed board write is reported as committed launch plus board failure, not a fictitious rollback. A complete committed identity remains recoverable after caller interruption.

`dispatch --print`, resume dry-run and refused preflight SHALL NOT create/modify prompt files, assignments, launch markers, board, config/audit or tmux windows. Fresh preview SHALL show an explicitly non-reserved candidate SID and warn that actual launch allocates its own SID; continued preview's SID/model SHALL equal actual recovery argv. Teamsmith-owned model/provider/session/continue arguments in worker or PM extra Pi arguments SHALL be refused, including separate/equals/short forms and bare session paths; arbitrary non-identity extras remain allowed. Frozen custom templates must consume the resolved identity placeholders to claim Pi continuity; a command with unverifiable hard-coded identity SHALL refuse guarded continuation with a template correction, not claim exact recovery.

#### Scenario: Proof and publication failures cannot create half an assignment
- **GIVEN** a previous complete record
- **WHEN** proof never arrives, an adapter exits non-zero, or publication fails before replacement
- **THEN** the command fails, previous bytes remain, no new task/model/SID is advertised, uncommitted worker is stopped and diagnostic evidence names the attempt

#### Scenario: Crash boundaries are distinguishable
- **WHEN** dispatch is interrupted before proof, after proof before replacement, and after complete replacement in separate fixtures
- **THEN** the first two cannot be recovered as a successful new assignment and require fresh after detecting interrupted evidence; the last resumes the complete committed model/SID without mixing fields

#### Scenario: Overlapping dispatch cannot overwrite a newer decision
- **WHEN** two launches target the same seat and another writer changes policy or the assignment while the first waits
- **THEN** at most one launch decision proceeds at a time, the stale plan does not replace the window, and every visible assignment is one complete version

#### Scenario: Preview and refusal leave all observable state unchanged
- **WHEN** a valid fresh preview, valid continued preview and a composite refused dispatch run
- **THEN** hashes and timestamps of state/config/board/prompt/worktree and recording-tmux call counts remain unchanged; preview renders the same model argument resolver used by recorded launches and identifies fresh SID as non-reserved

#### Scenario: Extra identity arguments cannot contradict records
- **WHEN** worker/PM extra args contain --model, --provider, --session-id, --session, --continue/-c or --resume/-r in supported separate/equals/short forms, or a bare session file
- **THEN** preview and launch refuse before side effects with the conflicting key/argument and correction; a harmless extra such as --no-tools survives rendering without changing assignment identity

#### Scenario: Board failure does not erase a committed launch
- **WHEN** assignment commits but the board wip update fails
- **THEN** output distinguishes the running committed launch from the failed board update, exposes the repair and preserves the complete identity for resume
