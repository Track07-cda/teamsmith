# Design: `dispatch-friction` — the dispatch handover stops guessing, stops dripping, and stops being silent

## Context

Recon against this checkout, 2026-09-30, all fixtures under `/tmp/p136-recon` with a record-only `tmux` shim on
`PATH` and every inherited `TEAM_*` cleared; the script and its log are committed beside the report
(`docs/team/reports/P136-dev2/recon.sh`, `recon.log`). The measurements that shape this design:

- **Branch churn.** The dispatcher derives `task/P134-p134-dispatch-friction-propo` from the BOARD title, while the
  PM had pre-created `task/P134-p134` — a branch that **is** `P134`'s own branch, under the same-ID rule
  `team_branch_is_for_task` already accepts. It is refused anyway, because `team_check_worktree_for_task` only
  accepts a slug mismatch when `state/<agent>.env task=` already equals the task being dispatched
  (`cmd-agents.sh:...`); a first dispatch never has that record. `--branch` is `✗ dispatch: 未知参数 --branch` today.
- **Wording.** For `change: panel（说明）` the refusal's first line is
  `拒绝派单：R2 的任务书 change: 行不合法（一个任务最多属于一个 change）` — no example, and the reason (trailing
  text outside the id) is mislabeled as "more than one change". For `deltas: panel · verification` the first line
  has no example and the whole value is reported as one bad token, so the comma syntax cannot be read out of it.
- **Silence.** With a `quota` record in `state/deaths.log` for the seat, `dispatch --print` prints the full plan and
  never mentions it.
- **The drip.** One corrected task took **5 attempts / 4 refusals**, each from a different guard, in the order
  change-syntax → deltas-syntax → unfinished previous task → branch identity. Every refusal is correct in
  isolation; together they cost one round-trip per guard.

The guards' judgements themselves are load-bearing and are not up for change (D16 stack guard, M6.3 branch
identity, D24 one change id, D36 verification seat, D40 archive order). Only the surface the PM meets changes.

## Goals / Non-Goals

**Goals.**

1. The task's branch name is declared once and printed, so nobody guesses it; a branch that is this task's own is
   accepted, and the branches git really uses stay the identity evidence.
2. A malformed `change:`/`deltas:` value is refused with the accepted shape and the real reason on the first line
   of its diagnosis, plus the exact line to write.
3. Every pre-launch blocker is handed over **once**, with a pasteable `修法：` command or an exact `改行：` line.
4. The printed fixes are exercised by the route walk: a fix that stops working reddens the gate.
5. A seat whose last round died of `quota`/`balance` or produced nothing is flagged before the next dispatch, and
   the tool stays silent when it cannot judge.

**Non-Goals.**

- No guard's judgement, override or audit semantics change; `--force` stays per-guard and audited.
- No bypass switch, no automatic branch switching, no git write by the skill (PM still runs git).
- No change to the death vocabulary or its classifier; the hint only *reads* it.
- No change to `docs/team/**` record formats, the tmux surface, or runtime launch behaviour.
- Not deciding *what* a task's change pointer should be — only how a wrong one is presented.

## Decisions

### D1. Spec homes: one capability, four modified and two added requirements

| Brief item | Requirement (capability `dispatch`) | Delta |
|---|---|---|
| 1 branch churn | `One task branch per task` | MODIFIED |
| 2a `change:` wording | `A brief names at most one change id` | MODIFIED |
| 2b `deltas:` syntax | `Two unfinished tasks of one change do not write the same delta file` | MODIFIED |
| 4 idempotence | `A refused dispatch hands over every blocker, once, with a fix that runs` (new) + `A dispatch never mixes two tasks in one worktree` (its refusal joins the report) | ADDED + MODIFIED |
| 4 pasteable fixes | `The printed route is a route that works` | MODIFIED |
| 3 quota pre-hint | `A dispatch warns before a seat that burned its last round` (new) | ADDED |

No other capability changes. The delta keeps every base scenario verbatim: `One task branch per task` 3 + 6 new,
`A brief names at most one change id` 5 + 2, `Two unfinished tasks …` 6 + 3, `A dispatch never mixes …` 2 + 1,
`The printed route …` 9 + 5, plus 5 + 5 for the two added requirements.

### D2. One declared branch name, resolved once

The name is resolved in this order and printed with its source (`--branch`, the brief's `branch:` line, the title):

1. `team task` renders the template with the derived name and writes it as a `branch:` header line. This makes the
   name visible before a worktree exists and pins it against later title edits; the derivation itself
   (`team_task_branch_for_id`) does not move.
2. `dispatch --branch <name>` overrides; it is validated with `team_branch_is_for_task` (task mode `task/<ID>-*`,
   agent mode `agent/<agent>`). When it is given, the worktree must be on exactly that name — the declaration is
   the PM's, and a same-task slug is not silently substituted. Without `--branch`, a worktree on any branch of
   **this** task is accepted and both names are printed (the churn fix).
3. No line, no flag → today's title derivation, unchanged.

The **another-task** refusal keeps its body and its `git switch` command. The identity evidence is unchanged: the
branch is still `task/<ID>-*`; only the slug is allowed to differ, which is what "same task" always meant.

*Alternatives considered.* (a) Derive from the brief's file slug — a second source that would drift from the BOARD
title and reintroduce churn. (b) Accept any branch matching `task/<ID>-*` *only* on resume (today) — leaves the
measured first-dispatch shape broken. (c) Let `--branch` name any branch — breaks the review evidence chain
(`team review` attaches to the worktree branch), so validation stays task-scoped.

### D3. Field refusals lead with the shape and the reason

The field readers (`team_task_change_value`, `team_task_deltas`) keep returning the *reason*; the dispatch guard
composes the first line as `拒绝派单：<ID> 的 <field>: 行不合法 —— <reason>；合法示例：<example>` and prints it
**first**, before the accepted forms and the `改行：` line. The reason text is made specific:

- change: `有 2 行（…）` / ``alpha, beta` 是多个 id` / `` `panel（说明）` 里有 id 之外的字符 `（说明）` ``;
- deltas: `分隔符是英文逗号，`·` 不是分隔符` / `逗号列表末尾有空项` / `` `·` 不是 capability token`` (the first bad
  token, not the whole value).

`改行：` carries a *valid* line derived from the value: the leading token for `change:`; for `deltas:` the tokens
re-joined with `, ` when every part is a valid capability, else `-`. It is a suggested line, not an interpretation
of intent, and the item says so.

*Alternative considered.* Making the whole refusal a single `拒绝派单：… —— …；例：…` line for every guard would
satisfy the letter of "first line" for the field case but degrade the multi-blocker report; the chosen format keeps
the field's own first line literal whenever the field blocker is the first item (the common case) and always
honest in the composite case.

### D4. One pre-launch pass, one refusal

Today `team_cmd_dispatch` calls guard after guard; the first failure `return`s. The change splits the pre-launch
phase into **collect** and **report**:

- Every guard that can be decided without side effects becomes a *finding producer*: header rules (change shape,
  anchor, deltas shape/single-writer, verify seat), state/worktree rules (multiple briefs, unfinished previous
  task, worktree presence, dirty state, branch identity), and launch preconditions (capacity floor, model
  concurrency, session-vs-window, agent executable). Each finding carries: the artifact it names, its reason, its
  fix lines, whether `--force` overrides it, and the audit line that override owes.
- A guard whose precondition is absent (no worktree, unreadable state) emits a finding that says it could not be
  judged — it is never reported as passed, and the report says so.
- The driver prints the first finding's own first line, then each remaining item, then one count line; exit 1 when
  any non-overridden blocker exists. Nothing is written (window, state, board, branch) before the report passes.
- With `--force`, overridable findings become warnings plus one audit line each, written only after a real launch —
  the existing `TEAM_DISPATCH_AUDIT_LINES` mechanism, now fed by several findings instead of one. `--print` writes
  none and still prints the warnings/report.
- Guard message bodies stay byte-for-byte where smoke and the spec pin them; only the *stopping* changes.

*Alternatives considered.* (a) Pick a "most actionable" blocker and hide the rest — that is today's drip in
disguise, and it makes the tool choose for the PM. (b) Run a separate `team dispatch --check` preflight command —
a new surface to learn; the PM asked for the dispatch itself to hand over. (c) Silently keep going past a blocked
guard — forbidden: a printed plan that cannot run is worse than a refusal.

*Trade-off.* A refusal can now be longer. It is bounded by the number of guards (about a dozen worst case), each
item is at most a few lines, and the count line makes the size explicit. Smoke legs will pin a three-blocker
composite.

### D5. The route walk exercises the printed fixes

`tests/routes.sh` gains a walk over the dispatch refusal surface, built like Walk A/B: a declared table
(fixture → expected blocker → printed route), each entry run in a fresh git fixture with the recording `tmux`
shim, `stdin` `/dev/null`, a hard timeout and cleanup. For an entry the walk runs the refusing command, asserts the
blocker appeared together with a `修法：`/`改行：` route, applies *the printed route* (write the `改行：` line into
the brief, or run the `修法：` command), re-runs the command and requires the blocker gone. Families in the table:

| Family | Printed route the walk applies |
|---|---|
| `change:` shape | `改行：change: <id>` |
| `deltas:` shape | `改行：deltas: <caps>` |
| worktree on another task's branch / declared `--branch` mismatch | the printed `git -C … switch …` |
| unfinished previous task | the printed re-dispatch with `--force` (honored as an override: warning + audit) |
| change-less anchor missing / delta single-writer | the printed `--force` route (honored as an override) |
| session over window | the printed `--fresh` route (honored as a new session) |

Two non-vacuity controls: a `修法：`/`改行：` family with no table entry is a finding (no printed route may go
unexercised), and a flip against a scratch tree whose fix-rendering is mutated (wrong switch target) must redden
the walk. A composite fixture of three *clearing* routes (a malformed `change:` line, a malformed `deltas:` line
and a wrong branch) proves the one-pass property: applying every printed route lets the re-run proceed, while the
override families are checked for being honored (their contract effect), not for clearing their condition.

### D6. The quota hint reads evidence; it never guesses

Two independent legs, each optional, both printed as `⚠` lines by the pre-launch phase (and `--print`):

- **Death leg** — `team_seat_death_fields <agent>` (the `agent-death-reason` reader, read-only) returns
  `quota`/`balance`: print the category, source, time and raw evidence line.
- **Zero-output leg** — at a successful launch, record the round's session id and the session file's size in
  `state/<agent>.env` (`sid=`, `sid_bytes=`). On the next dispatch, resolve the same session file: it exists and
  its current size equals the record → print `0 bytes ≈ 0 tokens` with the file. A missing record, missing file or
  unparsable value → the leg says nothing.
- Neither leg → nothing printed. The hint never returns non-zero, never opens a window and never appears as a
  refusal; the dispatch proceeds to D4's report/launch.

*Alternatives considered.* (a) Parsing Pi's JSONL for per-turn token usage — a new coupling to an internal format
the tool deliberately avoids (it only stats session files today); the byte-equality record uses what is already
there. (b) Timing-based (`session mtime < started`) — fragile across clock/timezone and a round that writes
metadata; rejected. (c) Blocking on the hint — the brief says非阻断; a hint that refuses would be a new guard
nobody asked for. (d) A duplicate quota probe at dispatch time — the reader already merges pane/session/deaths.log;
re-implementing classification here would drift.

### D7. Baseline compatibility

Every base scenario of the five modified requirements is carried verbatim in the delta; the new behaviour is
additive except for two intended changes: the same-task branch acceptance (today's refusal is the measured red
side) and the multi-blocker report replacing first-failure-abort. The one base scenario that mentions exact-match
semantics is the second half of "A worktree parked on another task's branch is refused" ("the same task resumed on
an earlier slug of its own branch stays allowed") — it stays true and is now a special case of the general rule.
Smoke legs that pinned first-failure behaviour or single-line wording are updated only where the delta requires it;
each such edit must be named in the apply report, and the PM's independent verification re-runs the full suite.

### D8. Verification and flip plan

Red sides are already measured in `recon.log`; the apply must reproduce them per task: (1) same-task branch
refused before → accepted after; `--branch` unknown before → accepted after; (2) first-line wording before →
example+reason after; (3) 4 refusals/5 attempts before → one refusal listing all after; (4) silent with a `quota`
record before → hint after, exit code unchanged; (5) a mutated printed route reddens the walk. The gate is
`openspec validate --all --strict` + `smoke.sh`; the apply also runs `routes.sh` standalone and measures the
changed smoke sections' bands for `tests/section-budgets.tsv` (P70 accounting).

## Risks / Trade-offs

- **Refactoring the guards into a collector can shift pinned messages/exit codes.** → Keep each guard's message
  body as data, add one smoke leg per family plus the composite, and let the PM's independent verification run the
  full suite; any wording change must be visible in the apply diff.
- **A longer refusal may read as noise.** → Items are one artifact each, the last line counts them, and the fixes
  are on their own lines so the list is skimmable; the composite is capped by the number of real blockers.
- **Accepting same-ID branches lowers the branch check's precision (a stale same-task branch from an earlier
  attempt).** → Both names are printed, `--branch` exists for exact pinning, and review/merge evidence is still
  task-scoped.
- **`0 bytes` can miss a round that wrote only metadata or an error frame.** → The death leg covers quota/balance
  directly; the byte leg is advisory and silent when unjudged; the spec forbids guessing.
- **Walk C runs commands the tool printed.** → It uses only scratch fixtures, the recording `tmux` shim first on
  `PATH`, `stdin` `/dev/null`, per-command timeouts and its cleanup trap; nothing reaches the caller's project or a
  real tmux server (D37/M36 discipline).
- **`state/<agent>.env` grows by two keys.** → Tiny and gitignored; no reader depends on unknown keys.

## Migration Plan

No data migration. Old briefs without a `branch:` line keep today's derivation; old state files without
`sid`/`sid_bytes` make the zero-output leg silent; the new walk table is the gate that keeps the printed routes
honest. Rollback is the reverse of the apply (revert the change directory's implemented commits); no external
state or config is touched.

## Open Questions

None blocking. The one reading worth recording: "a re-dispatch gets at most one actionable refusal" is implemented
as *one exhaustive refusal per attempt* (all blockers in one pass, each with a fix) rather than *one blocker per
attempt* — the latter is exactly the measured 5-attempt drip this change removes. If the PM's proposal review
wants the literal other reading, D4's collect phase is the only part that changes.
