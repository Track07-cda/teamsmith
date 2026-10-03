# sender-identity-refusal · design

## 1. What is wrong today

`openspec/specs/notify-and-inbox/spec.md` (requirement `A manual notification is attributed to its sender, not
its recipient`) promises two things the tool no longer does:

- "the project's main worktree resolves to `pm`" — unconditional;
- "An inherited `TEAM_AGENT` MUST NOT override the runtime directory: when it disagrees, the runtime directory
  wins and the ignored value MUST be named on stderr" — so a roster seat that happens to be in `TEAM_AGENT` is
  warned about and overridden.

The shipped behaviour (P201, commit `05b90f4`) is: the runtime directory still resolves a worktree under
`<main>/.worktrees/<name>` to that seat, but the main worktree resolves to `pm` **only while no seat clue is
present**. With a clue the call refuses: non-zero exit, no inbox line, no knock, and an error naming both the
directory's `pm` and the clue. The implementation is
`team_sender_resolve` + `team_sender_seat_clues` + `team_sender_is_main_checkout` in
`skills/teamsmith/scripts/lib/common.sh`; the reference prose (`references/agent-adapters.md`, `references/config.md`)
was updated in the same commit, which is why the tree today ships documentation that contradicts the spec.

## 2. The decision: record the shipped rule

The change records the shipped rule in the contract. Alternatives considered and rejected:

- **Revive the old behaviour so the spec stays true.** The accident the refusal prevents is measured: a seat's
  end-of-turn notification sent from the main checkout was recorded as `agent:pm`, byte-identical to a legitimate
  PM call, and the ledger records the **author**. Reverting would re-open a silent misattribution to serve a
  sentence, and it would contradict `references/agent-adapters.md`. The requirement's own last sentence ("Why a
  silent `pm` fallback is worse than a refusal", pointing at `references/philosophy.md`) already chose the
  refusal.
- **Leave the spec and fix the references.** That inverts the hierarchy: the spec is the contract the archive
  ships, `references/` explains it. A doc that contradicts the contract is the drift itself.
- **An ADDED requirement instead of MODIFIED.** It is the same promise; an additive block would leave the two
  false sentences in the base spec and give readers two rules.

## 3. The clue list, clause by clause

**A clue is a roster name (`TEAM_AGENTS`).** The window name is mutable UI state and `TEAM_AGENT` is inherited
state; neither may *become* the sender. They may only veto the main worktree's `pm`, and only when they name
someone the project knows. Without the roster filter every unrelated window name would refuse a legitimate PM
call, and every stale `TEAM_AGENT` from a shell would break `team notify` for the PM. The filter is the clause
that keeps the rule from becoming a landmine, so it gets its own scenario (a non-roster name refuses nothing) and
its own red side (a mutation that drops the membership test).

**The window clue is the caller's own pane, in this project's session.** `tmux display-message` without a target
answers the attached client's current window, not the caller's. Measured during P201 on tmux 3.7c: asked from a
`dev2` pane it returned `pm`, an echo that would have made the refusal depend on the wrong window. The
`TEAM_SESSION` scope mirrors the `[auto]` path's rule (a same-named window in another session is not this
project's seat).

**The clue never becomes the sender, and `pm` is not a conflict.** A clue that names `pm` agrees with the
directory; a clue that names anything else means the author is undecidable from the runtime context, and the two
honest resolutions are the ones the error names: state the author with `--from <name>`, or run from your own
worktree. Explicit `--from` keeps its precedence over everything (it is a human's claim, not a clue), and keeps
naming a disagreement with the directory.

**The refusal is total.** Non-zero exit, no inbox line, no knock, no outbox entry: the same "fail closed, write
nothing" shape the unresolved-directory refusal already has. The output names the directory's claim, every clue
with its source, and both ways out.

## 4. Baseline preservation (11 of 11)

Every scenario of the baseline requirement is carried into the MODIFIED block verbatim. None is dropped,
renamed or rewritten.

| # | Baseline scenario | Disposition |
|---|---|---|
| 1 | A manual worker inbox and PM wake name the same full-text file | kept verbatim |
| 2 | The same pointer survives a queued PM knock | kept verbatim |
| 3 | A failed durable write cannot authorize a wake | kept verbatim |
| 4 | An inbox-only notification retains its named recipient | kept verbatim |
| 5 | A worker's notification names the worker | kept verbatim |
| 6 | The PM's own notification still names `pm` | kept verbatim (a `pm` window is not a conflict) |
| 7 | An inherited `TEAM_AGENT` does not become the sender | kept verbatim (worktree context) |
| 8 | An unclassifiable runtime directory refuses instead of claiming `pm` | kept verbatim |
| 9 | `--from` is recorded as an explicit claim | kept verbatim |
| 10 | The knock and its queued entry carry the same sender | kept verbatim |
| 11 | Both paths name the same sender for one runtime context | kept verbatim |

`openspec validate` enforces this by title: a MODIFIED block that omits a baseline scenario fails with
`omits scenario(s) the current spec still has: "<title>"` (measured; see `docs/team/reports/P204-dev2/`).

## 5. Additions (7 of 7)

| New scenario | Clause it pins | Exercised today by | Red side |
|---|---|---|---|
| A seat clue in the main worktree refuses instead of claiming `pm` | refusal: non-zero, zero writes, both names, both ways out | smoke section 47 cases ①②; `flip-p201.sh` | `flip-p201.sh` shadow A (conflict branch removed) reddens the refusal assertions |
| The window clue is the caller's own pane, not the client's current window | the pane-target rule (an echo is not evidence) | smoke 47 case ① (`-t $TMUX_PANE` asserted on the shim's log) | shadow A; a regression to a target-less read reddens case ① because the fixture's shim answers only a targeted query |
| An inherited roster name refuses the main worktree's call | `TEAM_AGENT` is a clue | smoke 47 case ② | shadow A |
| A name outside the roster is not a clue | the roster filter (no mis-fire) | **nothing yet** | to add: smoke 47 case ③ (non-roster window and `TEAM_AGENT`) + shadow B (membership test dropped) |
| Another session's window of the same name is not a clue | the session scope | smoke 47 case ③c | shadow A keeps it green as the control; a session-check mutation would redden it |
| An explicit `--from` is still honoured with a seat clue present | claim precedence over clues, disagreement named | **nothing yet** (the P82 block covers claims without a clue) | to add: smoke 47 case ③ + shadow C (the refusal moved above the claim branch) |
| A seat worktree is not refused by a roster clue | clues veto the main worktree's `pm` only | **nothing yet** (the P82 block uses a non-roster `TEAM_AGENT`) | to add: smoke 47 case ③ + shadow D (the refusal's directory precondition removed) |

The three "nothing yet" rows are the apply's fixture work (`tasks.md` §2). Everything else is already shipped
and only needs its output quoted in the report.

## 6. Scenario counts

| | before | after |
|---|---|---|
| scenarios in the requirement | 11 | 18 |
| · kept from the baseline | — | 11 |
| · added | — | 7 |
| sentences rewritten in the body | — | 2 (the runtime-directory bullet, the `TEAM_AGENT` sentence) + 3 new paragraphs |

## 7. Falsifiability

Text level (`docs/team/reports/P204-dev2/trial.sh`, logs beside it):

1. `openspec validate --all --strict` on the delivered tree: green (14 items: 13 specs + this change).
2. the same run with one preserved baseline scenario deleted from the delta: red, with
   `omits scenario(s) the current spec still has: "The same pointer survives a queued PM knock"`.
3. a scratch `openspec archive -y sender-identity-refusal`: `~ 1 modified`, validate green afterwards, the base
   requirement then holding 18 scenarios, the refused paragraph present and the retired sentence gone.

Behaviour level:

4. `bash skills/teamsmith/tests/flip-p201.sh` — shadow A reddens cases ①② and leaves the no-misfire control
   green, then the restore is green again.
5. the apply's shadow B (membership test dropped) must redden the new non-roster assertions, C (refusal before
   the claim) the new `--from` assertions, D (directory precondition dropped) the new worktree assertion.

Limits, stated rather than hidden: the fixtures drive `tmux` through a shim (no real server); the shim answers
only `-t <caller pane>`, which is what makes a target-less read visible as a failure. No scenario in this
requirement needs a model call.

## 8. Re-baseline rule for the apply

The delta is written against today's baseline. If another change archives a modification of this requirement
first, the MODIFIED block replaces the whole requirement and would silently drop that change's sentences (the
title check catches dropped scenarios only). The apply therefore diffs the then-current baseline requirement
against the delta's preserved text and treats every unexpected hunk as a merge, not as noise; the same diff is
this change's own check that all eleven scenarios are the baseline's own text.

## 9. Out of scope

The `meeting` record-name union, `team say`'s delivery path, the `[auto]` extension's own resolution, the
`references/**` prose (already updated by P201), and `skills/teamsmith/scripts/**` (the behaviour is shipped; a
contradiction found there is a `BLOCKED:` for the PM, not an edit in this change).

## 10. Evidence

`docs/team/reports/P204-dev2/trial.sh` and its logs (`trial-1-validate-green.log`,
`trial-2-drop-scenario.log`, `trial-3-archive.log`, `trial-3-post-archive.txt`) are the propose-phase record.
