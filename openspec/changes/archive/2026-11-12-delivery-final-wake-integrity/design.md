# Design

## Context

`team-bg.ts` currently writes only the tool's effective execution `cwd`; an override can therefore erase the identity of the session that initiated the job. `team-notify.ts` uses that field for suspension ownership. The CLI merge key excludes `tip`, and the extension wakes only for a newly written line, so changing only the extension's send behavior cannot fix a merged final revision. The accepted exploration is `docs/team/reports/P447-dev2.md`; its V153 evidence bounds this change to these existing mechanisms.

## Goals / Non-Goals

**Goals:**

- Preserve initiator ownership across independent execution checkouts without weakening process identity checks or adopting another seat's legacy job.
- Make the existing writer produce one actionable line for each distinct delivered tip, retaining all current line, pointer, detail, dedup and wake invariants elsewhere. Senders without a provable tip retain the existing no-revision merge boundary.
- Make ordinary PM waiting recover from a missing final notice by reading existing durable records.
- Fit implementation and focused verification in one Apply brief, followed by a different agent's independent Verify brief.

**Non-Goals:**

- No second notification store, wake service, polling timer, manual duplicate notification, retroactive wake or automatic task completion.
- No change to watcher delivery modes, `read`/`intent`/`sent` meanings, PM liveness/recovery, Standby, background process lifetime or `team bg list|stop` process selection.
- No full/nightly/61b gate requirement and no new gate section or parallel harness.

## Decisions

### 1. Persist `session_cwd`; keep `cwd` as the execution location

At `team_bg_run` entry, capture the session's absolute `ctx.cwd` before applying `params.cwd`. Write it as `session_cwd` in the existing `.job` record, while `cwd` remains the resolved command execution directory. The in-memory job and returned details keep their current execution meaning; no second identity store is introduced.

`team-notify.ts` first performs the existing record-shape and live `(pid, start-time)` validation. For records containing `session_cwd`, canonicalize it and compare only with the settling session's canonical cwd/worktree set. An empty, relative, unresolved or foreign value is unowned and never falls back to `cwd`. For a record with no `session_cwd` field, use the bounded legacy rule: canonical `cwd` must equal the settling seat's worktree exactly. A subdirectory, independent clone, main/other-seat path or invalid path is not adopted. Symlinks and trailing slashes retain the existing canonical-path behavior.

This preserves the independent-clone case without treating shared state or a live PID as ownership. The alternative of accepting any legacy path below a seat was rejected because it would make unrelated nested checkouts ambiguous. Continuing to use only execution `cwd` was rejected because it reproduces V153.

### 2. Put the delivered tip boundary in the CLI's one merge key

Extend `team_notify_line_key` in `cmd-agents.sh`; do not add a second merge decision in TypeScript. Its tuple becomes seat, state class, task, normalized awaiting set and a revision component. For `[auto]`, that component is the parsed twelve-character `tip=` or a distinct no-revision marker. For `[auto·suspended]` and `[auto·interrupted]`, it is constant, so their existing cross-tip progress merging remains available.

The record and PM pointer continue to use this same key. A different delivered tip therefore creates both new lines, and the existing `state=new` path enqueues one wake whose dedup identity includes that new line key and first-event time. A same-tip delivered event extends the existing line and does not wake; the existing revision-aware short-window dedup is unchanged. Suspended-to-delivered remains a state-class change and wakes only for the delivered line. No `extended` event is force-sent.

Replace the old delivered cross-tip merge fixture with complementary cases: suspended progress at different tips remains one non-waking line carrying the last values, an interrupted pair at different tips remains one `×2` line with only its initial wake, and delivered tips produce separate lines and one wake each. Keep same-tip count churn, pointer parity, raw details, line readers and dedup coverage. An implementation with the tip component removed must fail the named delivered-revision case; forcing wakes in the extension alone cannot satisfy the line and pointer assertions.

### 3. Reconciliation is guidance inside the existing PM loop

Update the same waiting step in `templates/pm-prompt.md.tmpl` and `SKILL.md`, and expand `references/workflows.md` §D. The common meaning is: notifications are the first prompt, but files decide state; before repeating an unchanged waiting report, inspect `team digest`, BOARD, the task-branch report and task-worktree `git log`/`status`. Read a committed report with `git show <task-branch>:<report-path>` without switching branches. An uncommitted report is a draft, not delivery.

The existing patrol and normal notifications trigger this work; there is no new cadence. Guidance retains the ban on polling seat screens and explicitly says the assigned non-implementer verifier runs acceptance tests. It does not infer completion merely from an old tip, absent notification, merged line or live process.

Validate with a one-time isolated real PM and private project/tmux state, not the live team. Scene A has a committed final task-branch report whose final wake is absent: the resulting session/tool evidence must show file reconciliation and recognition of delivery without repeating the same waiting state or running gates. Scene B has a live job and no committed final report: it must not declare delivery. Run the old prompt as a control only where useful; if it also handles a scene correctly, record that result and do not claim red-to-green prompt evidence. This is behavioral evidence for the guidance, not a new recurring model test.

### 4. Reuse the registered harness and real notification path

Extend `tests/bg-ledger-harness.mjs` in its existing `owner-scope`, `merge` and `wake` groups. Replace obsolete expectations rather than adding a parallel suite; §13c already registers and executes this file. Exercise independent-clone suspension through final report delivery, other-seat isolation, legacy acceptance/refusal, dead/reused PIDs, distinct/same delivered tips and suspended progress.

Run the existing real notification path as focused integration. Its durable record, wake identity and watcher journal must reconcile `read`/`intent`/`sent` for each new actionable line. `sent` remains only Pi API acceptance and must not be reported as PM reading or acting. The Apply evidence names every selected section and any dependency the selector adds; it makes no claim about unrun sections.

## Risks / Trade-offs

- **Every distinct delivered tip can wake, not only report commits.** This is the accepted cost of making the stamped revision the observable boundary; same-tip merging and dedup bound repetition without trying to infer which files a commit contains.
- **A sender without a provable revision stamp keeps today's cross-revision silent merge.** A seat branch, detached worktree or unproven task ID has no `tip=` component, so later delivered revisions still extend one no-revision line without another wake. Closing that class requires a separate proposal; this change does not invent a stamp.
- **Legacy independent-checkout jobs remain unowned.** Inferring their initiator would be guessing; only newly written records gain reliable ownership. This is visible as non-suspension, not cross-seat adoption.
- **Prompt guidance cannot prove every model will always reconcile.** The isolated real-PM scenes test the shipped guidance in two concrete states; an old-prompt success is reported honestly rather than used as flip evidence.
- **More delivered lines can increase unread counts.** This is intentional: each unreviewed revision remains separately actionable, while same-tip runs retain their existing compact representation.

## Migration Plan

New `.job` records gain one field in place; existing records are not rewritten. The new reader applies the bounded legacy rule above. Old binaries ignore `session_cwd`, but rolling back while using independent execution directories restores the old non-suspension defect, so rollback evidence must disclose that limitation. No live job is adopted, stopped or signalled by the upgrade.

Existing inbox lines remain readable. The new key applies to future settles; already merged events are not split and no historical wake is synthesized. Rollback restores cross-tip merging for future events without rewriting files. PM guidance changes are text-only and take effect only when the corresponding prompt/skill is loaded by a new or reloaded session; no automatic live-team restart is part of this change.
