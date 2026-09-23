# Design: `change-centric-discipline` — the change is the assignment unit

## Context

What this design works with, measured on this branch (main `1288b46`, worktree
`.worktrees/dev-bob`, branch `task/P23-change-change-b-propose`) unless a line says otherwise.

- **The brief header is parsed loosely and never checked.** `team_brief_field` (`common.sh:2391`) takes the
  **first** line matching `^[[:space:]]*<key>:`, strips a trailing `#` comment and trims; `team_task_phase`
  (`:2422`) accepts only the closed set and maps everything else to "no phase"; `team_task_change` (`:2429`) treats
  `-`/`—`/empty as "none" and otherwise returns **whatever is there**. Measured (`. skills/teamsmith/scripts/lib/common.sh`
  in this worktree): a brief with `change: alpha, beta` yields `[alpha, beta]`, and a brief with two `change:` lines
  (`alpha`, then `beta`) yields `[alpha]` — the second line is never read, and the value is passed straight into
  `state/<agent>.env` and the review-record name. Nothing rejects a comma list, two space-separated ids or a title
  case id.
- **The dispatch guards that exist** (`team_cmd_dispatch`, `cmd-agents.sh:496`) run before any window is opened:
  the brief must live inside the project (`:521`), one ID must not match several briefs (`:536`, no `--force`), the
  per-agent stack guard (`team_dispatch_stack_guard`, `:445`, called at `:552`; `--force` prints an override and,
  on the real path, appends one line through `team_wlog` → `state/watchdog.log`, `:715`), the worktree/branch
  identity guard (`team_check_worktree_for_task`, `:565`), the memory floor, the model limit and the session-window
  guard. **None of them looks at a change id, at delta files, or at an author.**
- **Review knows nothing about authorship.** `team review <ID> --dir <checkout>` runs `$TEAM_GATES` and writes
  `docs/team/reviews/<ID>.md`; its inputs are the checkout and the branch, and the record's independence sections
  describe the *checkout* and the *report*, not who implemented the change. Independence is prose:
  `references/openspec.md` §2 ("no agent verifies its own work", the apply phase by an agent that did not propose)
  and the generated `AGENTS.md`/`PROTOCOL.md` sections — plus the PM's judgement.
- **The recorded P18/V18 pair is not an exception.** `P18`'s B3 commits (`aec2d84`, `98a8837`, `1b034b4`,
  `171e1a7`, `15997b0`) live on `task/P18-apply-console-board-page-mar` and carry `Agent: dev3` trailers; the PM's
  thread to `dev3` (2026-09-18T11:33Z) assigned the tail work to dev3; `V18` was run by `verify`, and its report says
  it changed no `skills/**`, `openspec/**` or ledger file. The brief's premise («P18 的 B3 由 verify 写») is not
  reproducible from the ledger (see §5 for the ruling).
- **The live shape of the risk** is `console-project-settings`: `P22` (apply, agent `verify`) is merged and left the
  change's `tasks.md` at `0/33`; `M49` (apply, agent `verify`) is queued and its brief says it edits the *same*
  change's `panel` delta. Two apply tasks of one change, in sequence, by the same agent — and an archive that a
  future task could reach while a sibling is unfinished.
- **Archive evidence is one directory.** `team_done_phase_evidence` (`common.sh:2470`) for `phase: archive` accepts
  `openspec/changes/archive/<date>-<change>/`; nothing else about the change is consulted. `team_task_open_reason`
  (`:2610`) and `team_done_evidence` (`:2554`) already answer "is this one task finished, and by what evidence" with
  the phase-aware rules (PASS/UNKNOWN/SKIPPED record, merged branch with a committed report, accepted proposal
  review, archived directory) — the archive rule must reuse them, not invent a second notion.
- **The views that would group by change** already exist in shell: `team digest` prints sections `[1]`–`[5]`
  (`cmd-status.sh:480,510,527,579,640,647`), and the console's `changes` block is `team_panel_changes_json`
  (`cmd-watch.sh:887`), one entry per non-archived change dir with `id`, `done/total`, `age`, `phase`, served to the
  panel through `team __panel-data --block changes` (`:1156`) with a 180 s TTL (`panel/src/data.ts:169`).
- **Cheapness is a contract now.** `M50` (in flight) will require read paths to stay bounded: ≤1 `git` call for a
  single-row read and ≤50 for `team digest`, no per-file subprocess fan-out. Everything this change adds must be
  computed in-process from files that are already being read.

## Goals / Non-Goals

**Goals.**

- One machine-checkable key between a task and a change, and the guards that make "one task, one change" real at the
  only place where it can still be cheap: **dispatch time**, before a window opens.
- Policy B made enforceable: a change-less brief either names an anchor that resolves in `openspec/specs/`, or says
  out loud that it is infrastructure work and why.
- The delta files of a change have one writer at a time, and a second unfinished task that wants the same file is
  refused **by name** rather than discovered as a merge conflict later.
- Per-change verification independence, visible in the tool, not only in the PM's head.
- An archive that is gated on the **whole** change, with one predicate shared by the command, the views and the
  board's `done` gate.

**Non-Goals.**

- No new spec system, no new ledger: the briefs stay the only place a task↔change mapping lives; no
  `state/changes.json`, no second database.
- No git/forge wrapper: this change adds no `team change new|close|merge|push` command; `team change status` is
  read-only.
- No retroactive editing of the eight existing `change: -` briefs, no re-labelling of history, no automatic archive.
- No change to the launch proof, the delivery guard, the panel performance contract, or any `TEAM_*` key.

## Decisions

### 1. The model, the header grammar, and where each field is read

`1 change : N tasks` (N≥1: several agents, several batches, rework) and `1 task : 0..1 change`. A change is the
contract and the dispatch unit (proposal/design/delta/tasks + archive); a task is a batch or a phase inside it.
The brief's header is the foreign key — five lines, two of them new (`anchor:`, `deltas:`; `change:`, `specs:` and
`phase:` already exist, with sharper rules):

| field | accepted value | absent | who reads it |
|---|---|---|---|
| `change:` | exactly one id token (`[A-Za-z0-9][A-Za-z0-9._-]*`) or `-` | same as `-` | rule 1 (dispatch), the change view, rules 2–4 |
| `phase:` | `explore\|propose\|apply\|verify\|archive` (unchanged) | `-` | existing phase evidence, rule 3 |
| `specs:` | `<capability>[#<requirement>]` entries, `;`-separated; `-` = none | none | policy B (change-less briefs), the PM's checklist |
| `anchor:` | `none (infra) — <non-empty reason>` | none | policy B (change-less briefs) |
| `deltas:` | `<capability>` entries, `,`-separated; `-` = **writes none** | **unknown** | rule 2 (single writer), the change view |

Three deliberate asymmetries:

- **`-` and "absent" differ for `deltas:`.** `-` is a positive statement ("this task writes no delta file") and
  allows parallel work; absent is *unknown*, and unknown is treated as "may write every delta file of the change".
  Silence is never a claim (the same discipline as `--from-file`'s "missing file fails loudly").
- **`change:` absent ≡ `-`**, because policy B then forces the anchor declaration anyway; a brief that says
  nothing still has to say *something* about why it is not change-anchored.
- **`specs:` keeps its free-form history.** For a change-less brief it must resolve (see §3), but the field is not
  redefined for change-anchored briefs, where it stays a list of the requirements the task must satisfy.

`templates/task.md.tmpl` already writes `change:`, `specs:` and `phase:` lines with `-` defaults; it gains the two
new lines (`anchor:`, `deltas:`) and the comments of the four change-related lines carry the grammar above, so
`team task` writes a brief that already declares its (empty) state — the author edits a value, not a question.

### 2. The spec home: no new capability, three ADDED deltas

The four rules are not a new behavior area; each constrains a surface an existing capability already owns:

- `dispatch` — the brief contract ("A brief is self-contained and names its evidence") and every other
  window-opening guard live here. Rules 1 and policy B are brief-contract rules; rule 2 is a dispatch guard.
- `verification` — the capability whose purpose is "the PM's independent check of an agent's claim". Rule 3 is
  exactly that independence, stated per change.
- `board-and-status` — "done means landed and pushed", the digest's pending work and the ledger's promises. The
  change view and the archive precondition are ledger promises.

The delta is **ADDED-only** (7 requirements), so no existing statement is superseded and no MODIFIED block risks
dropping a scenario. Alternatives considered and rejected:

- **A new `openspec-pipeline` capability for all four rules.** Rejected: its "brief names one change" requirement
  would duplicate the brief contract in `dispatch`, its "no self-verification" requirement would restate the
  `verification` capability's own purpose, and its "archive" requirement would hold a promise enforced by
  `team board set`'s existing `done` gate. The checklist's rule 7 (no parallel statement) and the project rule
  "never grow a second spec system" both argue against a capability whose content is other capabilities' behavior.
- **Everything in `dispatch`.** Rejected: the archive readiness and the change view are not dispatch behavior, and
  a dispatch requirement promising what `team digest` prints would be unimplementable where it is stated.
- **`memory-and-deps` for the gate rule (backfill, §9).** Rejected there in favour of `verification`; see §9.

### 3. Determinism: what refuses, what warns, and every escape

The failures these rules prevent are silent (a false green, a merge conflict discovered at merge time, a rule with
no anchor); the cost of a refusal is one line in a brief or one flag. So the default is refuse, with exactly one
escape per rule where an override can be legitimate:

| rule | behavior | escape |
|---|---|---|
| 1 · one change id | **refuse** at `team dispatch`, and at `--print` too | none — the fix is the brief |
| B · anchor declared | **refuse** when a change-less brief declares neither form; **refuse** when `specs:` names a capability or requirement that does not resolve | `anchor: none (infra) — <reason>`, or `--force` + one audit line |
| 2 · delta single writer | **refuse** | `--force` + one audit line |
| 3 · verifier ≠ apply author | **refuse** | `--force` + one audit line |
| 4 · archive readiness | **refuse** `team board set <archive-ID> done` | the existing done-gate override (`TEAM_BOARD_DONE_FORCE=1` + a written reason) |
| ①③ views | never refuse; `team change status <id>` exits 1 when not ready | none (read-only) |

Two consistent details inherited from the M9.3 guard family: **"cannot tell" is loud but passes** (no `agent:` line
recorded, no brief for the sibling, no change directory → the guard prints which signal is missing and proceeds),
and **every override writes one audit line** (`team_wlog`, `state/watchdog.log`), so `team monitor`'s events column
shows it later. Rule 1 gets no override on purpose: there is no legitimate task that implements two changes at
once, and a flag would only let the silent-pick bug back in through the front door.

Refusals never touch the board: a refused dispatch leaves the task's status exactly as it was (the existing
"A failed step does not leave a false status" requirement already promises this, and the new guards are part of the
same pre-window block).

### 4. Rule 2 in detail: the declaration and the change-wide scan

**Why a declaration.** At dispatch time nothing can see what a task will write. Two possible signals exist:

- the brief's `deltas:` line — the intent, auditable before any work happens;
- the sibling's branch diff — what a task *has* written so far (`git diff --name-only <base>..<tip> --
  openspec/changes/<C>/specs`).

The guard uses the first as its criterion and the second as *evidence in the view* (§7): `team change status <C>`
prints, per task, the declared delta files and the ones actually touched on its branch, so a declaration that lies
is visible instead of silent. Dispatch decides on declarations only — deterministic.

**The scan is change-wide, not agent-local.** The existing stack guard only looks at the agent's own recorded task;
a delta collision can just as easily come from a task on another agent. So the guard:

1. resolves `C` from the brief being dispatched (rule 1 has already validated the value);
2. enumerates every task mapped to `C` by scanning `docs/team/tasks/*.md` for their `change:` line **in one pass**;
3. keeps the unfinished ones (`team_task_open_reason`, `common.sh:2610` — the same predicate the stack guard uses),
   excluding the task being dispatched (a resume is not a conflict);
4. intersects their delta target sets with this task's, where a task's set is: `-` → empty, a list → those
   files, absent → **every** `openspec/changes/<C>/specs/*/*.md` present in the change directory;
5. refuses on a non-empty intersection, naming the sibling task, its recorded status, the shared file(s) and both
   declarations; `--force` prints the same block as a warning and writes the audit line.

Consequence (the intended one): **two apply batches of one change run in parallel only when both declare `deltas: -`**
(or disjoint capability lists). That is the common case, since a change's delta is written in the propose phase and
an apply task only touches it when it closes a finding or reworks a scenario — exactly the `M49`-style case the
rule exists for. `tasks.md` checkbox ticking stays **outside** the guard: the ledger shows it is not a per-task
writer (`P20` ticked its change's tasks, `P22` did not — `console-project-settings` is still `0/33`), and refusing
on it would block the parallel batches the model wants.

### 5. Rule 3 in detail: the author set, the enforcement point, and the P18/V18 ruling

**The author set** for a `phase: verify` task dispatched for change `C` is: every task mapped to `C` whose
`phase:` is `apply`, or absent (a code task carrying a change id is an apply task in everything but name). Tasks
whose board status is `dropped` are excluded and named in the message.

**The enforcement point** is dispatch, together with rules 1, B and 2 (one pre-window block). The guard compares
`agent:` lines — the only auditable author of record — and the message says which tasks the agent wrote. A missing
brief or a missing `agent:` line is a loud pass, per §3.

**The P18/V18 ruling.** The brief asked whether the historical pair is an intentional exception to ratify. The
ledger does not support the premise: B3's commits are on dev3's branch with `Agent: dev3` trailers, the PM's thread
assigned the tail to dev3, and V18 (agent `verify`) verified it without touching the tree — i.e. the recorded trail
**honours** the rule. The ruling is therefore: **adopt the rule, no exception, no carve-out**, and record that this
proposal found no ledger evidence of a self-verification case; if the PM holds session-only knowledge that
contradicts the trailers, the correct repair is the audit line (`--force`), not a silent exemption — and the review
record for this proposal is the place to say so. The rule binds new dispatches only; nothing done is re-judged.

**Deliberate boundary:** the *propose* and *explore* authors are **not** machine-checked. openspec.md §2 allows
explore and propose to be the same agent (it holds the context), and D31's corollary names apply authors. The PM's
checklist (§8) keeps the broader prose rule ("the apply phase by an agent that did not propose") as a judgement.
`team change status` prints every mapped task's `agent:` so the judgement is made on visible data.

### 6. Rule 4 in detail: one readiness predicate, three consumers

`ready(C)` is true when **at least one** task is mapped to `C` and **every** mapped task is *finished* per
`team_task_open_reason` (`common.sh:2610`): its board status is `done`/`closed`/`dropped`, or its evidence exists —
a review record with a verdict other than `FAIL`/`TIMEOUT`, a merged branch whose commits carry the task's report,
or the phase-specific evidence (accepted proposal review for `propose`, the archived directory for `archive`, and
so on). Reusing that function is the point: the archive rule cannot drift from the `done` gate, and D31's «全部任务
done 且有复验» is read through the tool's existing notion of "finished with evidence" instead of a new one.
A `dropped` task counts as finished **and is printed**, so an abandoned batch is visible in the readiness output
rather than silently ignored.

Three consumers, one implementation (`team_change_ready`):

1. `team change status <id>` — exit 0 iff ready, exit 1 otherwise, naming each blocker (§7).
2. `team board set <archive-ID> done` — the `phase: archive` evidence route requires readiness, so a task cannot
   reach `done` while a sibling of the same change is unfinished. The refusal names the sibling, its status and its
   missing evidence, and the existing override (`TEAM_BOARD_DONE_FORCE=1` + `TEAM_BOARD_DONE_REASON`) still works.
3. The digest section and the panel block (§7) show the same verdict, marked `ready`/`not-ready`.

The PM's own actions stay in the loop (the machine check is a backstop, not a replacement): the archive checklist
row gains the command and the trial archive (§8), and cannot be satisfied by the tool alone.

### 7. The three surfaces of mechanism ①/③

**`team change status <id>`** (new verb group, matching `board`/`meeting`/`pulse`):

```
$ team change status console-project-settings
change console-project-settings · not ready
  tasks
    P21  propose  dev-bob  done    reviews/console-project-settings-proposal.md: ACCEPTED
    P22  apply    verify   done    reviews/P22.md: PASS
    M49  apply    verify   wip     —（board wip）
  delta files (openspec/changes/console-project-settings/specs/)
    panel/spec.md            declared by M49 · touched by —
    memory-and-deps/spec.md  declared by (no `deltas:` line) · touched by P22
  blockers
    M49 · apply · wip · no review record, branch not merged
```

- Read-only: no file writes, no board writes, no git writes; branch diffs are computed with one
  `git diff --name-only` per task **that has a resolvable branch**, and `--json` prints one object
  (`{"id","ready","tasks":[…],"deltas":[…],"blockers":[…]}`) for tests and scripts.
- Unknown change id (no task and no change directory) → exit 1 and a message that names both facts.
- `self-verify: <agent>` is printed on a verify task whose agent also authored an apply task (§5), so rule 3 is
  visible even when the dispatch guard was overridden.

**`team digest`** gains one section, `[6] change 归组`, without renumbering `[1]`–`[5]` (existing smoke assertions
name those numbers). One line per open change: `change X → M1 done · M2 wip · V1 PASS`, plus `ready`/`not ready`,
bounded to 8 lines with a `+N` tail like the digest's other lists. A change directory with no task pointing at it
prints `（没有任务指向它）`; a task pointing at a missing change directory prints `（change 目录不存在）` — both are
honest and cheap. When there is nothing to show, the section prints one dim `（无）` line, like the others.

**The panel** keeps `team_panel_changes_json` as the single reader and adds a `tasks` array per change entry
(`id`, `phase`, `board`, `verdict`), bounded to 8 tokens; the layout renders one token line under the change row
(`X  M1 done · M2 wip · V1 PASS`) inside the existing budget, so a narrow frame drops the task line rather than
reflowing the block. `--print`/`--json` stay byte-identical except for the timestamp (the block is console-only,
like `board` and `detail` before it).

Cost, per the M50 contract: one `awk` pass over `docs/team/tasks/*.md` for the whole section, no per-file `team`
subprocess, no new `git` call on the common path (branch diffs only in `team change status`, for one change at a
time). The new section is covered by the same "digest stays under its budget" assertion M50 will land.

### 8. The PM's checklist, executable (goes into `references/openspec.md`)

§4's list grows from eight to ten points; the two new ones are written so that each can be judged on files, and the
rest of the list is untouched:

9. **One change per task** — every brief the change's plan will dispatch declares exactly one `change:` id (or `-`
   with an anchor). Judgement: `grep -n '^change:' docs/team/tasks/*.md` and, once the briefs exist,
   `team change status <id>` must list them under this change and no other. A brief with two ids, a second
   `change:` line or a typo is a NEEDS-CHANGES item naming the brief and the line.
10. **The anchor exists** — each dispatched brief either points at this change, or names a `specs:` requirement
    that resolves in `openspec/specs/<capability>/spec.md`, or declares `anchor: none (infra) — <reason>` with a
    reason from the allowed classes (environment/CI/toolchain, pure internal refactor, docs and fixtures).
    Judgement: `grep -n '^anchor:\|^specs:' <brief>` and, for the infra form, is the reason honest — a rule that
    must hold across tasks (silent failure, destructive action, authority, identity, gate, performance contract) is
    **not** infrastructure, whatever the brief says; the correct verdict is NEEDS-CHANGES with the capability named.

§5's archive row gains the machine half of the archive gate, and §2 states the model:

- **§2** (one paragraph): `1 change : N tasks`, `1 task : 0..1 change`; the change is the dispatch unit, the task a
  batch inside it; the header fields and their grammar (§1 of this design) live in the brief template.
- **§5 archive row**: before the trial archive, run `team change status <id>` and require `ready` (exit 0); the
  change's tasks with their evidence form the review record's per-task table; the trial archive still runs first,
  and the user still confirms.

### 9. The backfill: per-task table and recommendation

The eight briefs predate D31 and carry `change: -`. Policy B classifies each rule; "evidence that fixes the text"
names what the requirement must be pinned to. **Recommendation: one backfill change for the six shipped rules**
(`spec-backfill-runtime-guards`), because their text is already fixed by assertions that landed — its apply phase is
transcription plus reconciliation against those assertions, and its independent verification is text-vs-assertion.
**M48 and M50 get one change each** (`board-duplicate-identity`, `read-cost-budgets`): their rules are still plans,
their text cannot be pinned to assertions that do not exist, and mixing plans with backfilled facts in one change
would put two different kinds of claim behind a single verification record.

| task | rule (why it is cross-task) | class (D31) | anchor today | recommended home · op | evidence that fixes the text |
|---|---|---|---|---|---|
| **M36** | the runtime tmux gate records every call and refuses `kill-*` against the default server | destructive action, authority | none | `boundary` · ADDED | smoke §31c (`smoke.sh:9620`): exit 64, `act=refused` + socket + pid in `state/tmux-calls.log`, private-socket pass-through, `TEAM_ALLOW_DESTRUCTIVE_TMUX=1`. Text must say "a call that goes through the PATH gate" — the absolute-path blind spot (`/usr/bin/tmux`) is a documented non-promise |
| **M41** | the gate's socket resolution replicates tmux's own `TMUX_TMPDIR` fallback (a nonexistent dir → the default socket) | destructive action | none | `boundary` · ADDED | smoke §31c ①c/①d: a nonexistent `TMUX_TMPDIR` + `kill-server` is refused and logged with the default socket; the read-only twin is logged as default; the mutant flip goes red |
| **M43** | a rewritten/truncated spool is not replayed; the wake count and ledger stay honest | silent failure | none | `notify-and-inbox` · ADDED | `team-inbox-watch-harness.mjs` S11–S13 + `flip-m43.sh`: no redelivery of already-delivered lines, the ledger records the shrink and the skip, `total` grows only for real new lines |
| **M44** | the gate reds a tracked file that carries merge-conflict markers | gate | none | `verification` · ADDED | smoke §0d (`smoke.sh:533`): `git grep` over tracked files for the three marker lines, the red names file:line, the tracked-only scope, the fixture flip. (`memory-and-deps` was the alternative; rejected because that capability owns the *spec* system, while this rule is gate content — the evidence the verification phase runs on) |
| **M45** | the input-box reader tolerates the CLI's own banner (an idle box still reads EMPTY, a real draft still reads HOLDS_ONLY) | silent failure | none | `delivery-guard` · ADDED | smoke §12b-h0b (`smoke.sh:5488`): the banner's line shapes are excluded, "banner + real draft" still reads the draft, the no-banner host stays green, and the exclusion list stays narrow |
| **M46** | a skipped watcher is visible as a delivery degradation, and the slow path self-heals | silent failure | none | `notify-and-inbox` · ADDED (visibility) + `delivery-guard` · ADDED (self-heal, held entries whose target is gone) | smoke §12b-pi2 (`smoke.sh:6186`): the warning names the session mismatch, the outbox still delivers on the slow path, no permanent `stalled` entry, old targets are reported |
| **M48** | board duplicate ids: the write refuses, the duplicate is visible, the focus is per drawn row | authority (board writes), user-visible panel behaviour | none | **own change** `board-duplicate-identity`: `board-and-status` · ADDED (the write guard + the visibility) + `panel` · **MODIFIED** (the kanban requirement's "tracked by entry id" clause conflicts with per-row focus, so it must be superseded, not restated) | M48's own brief (Deliverables 1–5) becomes the delta; the assertions do not exist yet, so the apply lands them with the code |
| **M50** | read paths stay inside measurable cost budgets (≤1 `git` call for a row read, ≤50 for `team digest`, a derived index that equals the direct parse) | performance contract | none | **own change** `read-cost-budgets`: new capability `read-cost` · ADDED | M50's brief (Deliverables 1–4). A new capability is the honest home: the budgets span `team` startup, `digest` and `__panel-data`, so `board-and-status` or `panel` alone would leave the startup rule homeless |

Two notes the backfill's propose must carry:

- **Write the text from the assertion, not from memory.** Every scenario in the backfill quotes its section and the
  command that reds it; where the assertion is narrower than the prose (M36's PATH-only gate, M45's fixed banner
  shape), the requirement states the narrower promise and `references/troubleshooting.md` keeps the rest.
- **`M47` (CI portability, in flight) is the legitimate infra case** and needs no backfill: environment/toolchain
  work, its brief should carry `anchor: none (infra) — CI runner environment and test portability`. Its board row
  is `wip`, so the PM edits its brief before any re-dispatch (the new guard would refuse it otherwise).

### 10. Rejected alternatives (beyond §2)

- **Infer the delta targets from the branch instead of declaring them.** Impossible at dispatch time (the future is
  unknown) and non-deterministic afterwards; the declaration plus the view's declared-vs-touched comparison keeps
  both the intent and the fact visible.
- **Store the task↔change map in `state/`.** A second source that drifts from the briefs; the brief is the ledger,
  and the scan is one pass over a few dozen files.
- **Make rule 1 overrideable with `--force`.** No legitimate two-change task exists, and the flag would restore the
  silent-pick failure the rule removes.
- **Auto-archive when ready.** Archiving is the PM's act with the user's confirmation (openspec.md §1 phase 5), and
  `openspec archive` is not wrapped by the skill.
- **Block parallel work on one change entirely.** D31 explicitly wants several batches; only the delta file needs a
  single writer.
- **Per-task worktrees for the same agent.** Out of scope; the stack guard already owns that ground.

### 11. Testability (what can be red, per rule)

| requirement | fixture | the observable that goes red |
|---|---|---|
| rule 1 | a fixture brief with `change: a, b`, another with two `change:` lines | dispatch exits non-zero naming the line; `--print` refuses too; a tmux shim proves no window was requested |
| policy B | fixture briefs: `-`+nothing, `-`+unresolvable `specs:`, `-`+`anchor: none` (no reason) | refusal names both accepted forms; the `anchor: none (infra) — reason` and resolving-`specs:` briefs proceed |
| rule 2 | a fixture project with an unfinished sibling declaring `panel`, a change dir with `panel/spec.md` | the same-declaration dispatch is refused naming both tasks and the file; `deltas: -` vs `deltas: panel` proceeds; both-absent refuses; `--force` adds exactly one `state/watchdog.log` line |
| rule 3 | fixture briefs: apply by `dev` + verify by `dev` for one change | the verify dispatch is refused naming the change, the agent and the authored task; a `verify`-agent dispatch proceeds; `--force` audits |
| rule 4 | fixture BOARD + briefs + an archived change dir | `team board set <archive-ID> done` is refused while a sibling is `wip` (naming it) and allowed when every task is finished; `team change status` exit code agrees with the gate |
| views | fixture project, `--print`/`--json` byte-stability | the grouping section/tokens appear for an open change, collapse when empty, and never renumber `[1]`–`[5]`; the panel's `--json` is unchanged (console-only block) |

Every guard batch also carries the family's two standard controls: **no window is opened on a refusal** (a tmux
shim that only records) and **the guard does not touch the board** (the row's status is unchanged after a refusal).

## Risks

- **A declaration that lies.** The dispatch decision rests on `deltas:`/`anchor:` text. Mitigation: the view prints
  declared vs touched, and the review record's file list already exposes a delta edit. The guard's job is the
  honest conflict, not a police state.
- **Over-refusal on in-flight work.** Three briefs are already written with `change: -` (M47, `wip`; M48 and M50,
  queued). The refusal messages name the exact fix, and §9 tells the PM what to edit before re-dispatching. `M49`
  is already anchored (`change: console-project-settings`) and is the case rule 2 was designed for.
- **A field that is easy to forget.** The template writes all five header lines with `-` defaults, so forgetting a
  line is visible in the brief rather than only in a refusal.
- **Cost creep in the views.** Bounded by the M50 contract; the design adds no per-file subprocess.
- **Drift between the three surfaces.** They share `team_change_ready`; no surface re-derives the predicate.
