# PM memory: what to remember, what to write down

> This document is about the **PM's own memory**: what belongs in it, what must go to disk instead, and what
> survives compaction, restarts and `/reload`. magic-context is a **required dependency** since D10 — the skill's
> files never hold memory, so without the extension the PM's memory layer is simply empty
> (`team doctor` fails; `TEAM_REQUIRE_MAGIC_CONTEXT=0` downgrades that to a warning for odd environments).

## 1. Why the PM is the role that needs memory

The PM is the only role that spans tasks, restarts and time: a worker agent is one short session with one brief,
while the PM holds the roadmap, the decision history and the constraints that were learned the hard way. When the
the pulse raises the PM again — or a human opens a new session — someone has to know *why* the interface looks like
this, which option was already rejected, and which trap cost a day last time.

Memory is what stops three failure modes we have actually hit:

- **decisions get re-litigated**: the same question is answered twice, and answered differently;
- **constraints silently disappear**: "gates need a hard timeout", "never move the worktree" — nobody contradicts
  them, they are simply not there any more;
- **the context says X, the disk says Y**: a skill copy that the PM loaded days ago still lives inside a compacted
  context and describes behaviour that was replaced since; the PM reasons from the stale copy while the repository
  says something else. Disk wins — see [philosophy.md](philosophy.md) #6 and §4 below.

## 2. The three layers, and who trusts each one

| Layer | What it is | Who trusts it |
|---|---|---|
| **Session memory** | magic-context (`ctx_search`, `ctx_expand`, `ctx_memory`, `ctx_note`, memory ids) — recall across compaction and restarts for *this* session | the PM, as a shortcut |
| **Disk evidence** | `reports/`, `reviews/`, `BOARD.md`, `threads/`, `DECISIONS.md`, `ROADMAP.md`, the commits | the next PM, any human, any other tool |
| **Skill version state** | `team mark-loaded` / `team version --check` / `/reload` — memory *about the tool itself* | the PM, before trusting its own recollection of the skill |

The rule that ties them together: **conclusions and evidence land on disk; "I remember" is never evidence**
([philosophy.md](philosophy.md) #1 independently verifiable, #6 handover-ready). Project memory is the PM's
fast path back into a project, not a second copy of the record. If the two ever disagree, the disk is right.

## 3. What belongs in project memory

One **standalone fact per entry** — it has to make sense without this session's context, because that is exactly
who reads it later. Three families are worth the effort:

- **Project facts**: session/window names, roster, gates command, protected branch, worktree paths, branch mode.
  Each one is verifiable, and each one saves a fresh session a round of `team paths` / `git worktree list`.
- **Working rules**: the part of the creed that applies to this project — reports are claims, status is a promise,
  repeated problems must become mechanisms, skips must be declared. These are cross-project, so they are copied
  from the creed rather than invented per project.
- **Project-specific traps**: "the e2e gate needs a build first", "this test is flaky ~5%, re-run once before
  judging", "gates must carry `timeout`". Each of these cost real time once and will cost it again.

`templates/memory-seed.md.tmpl` is the starting set — it lists the project facts and the working rules with
placeholder values, so the first session can copy it into memory entry by entry.

**What does not belong:**

| Not in memory | Where it goes instead |
|---|---|
| current task state ("T3.2 is in review") | `BOARD.md` — it changes hourly and memory cannot be kept in sync |
| secrets, tokens, anything from a credential file | nowhere: token files stay on disk, injected for a command only (see [protocol.md](protocol.md) §7) |
| long logs, diffs, gate output | the report/review file, or the git history |
| anything that is evidence | the file that holds it — memory must not become the only copy |
| anything that will be stale tomorrow | the roadmap's leftovers or a session note (`ctx_note`), not memory |

## 4. When to read, when to write

The PM prompt gives the two moments; in detail:

**On start** (raised by the pulse, or a new session): with memory available, `ctx_search` for the project's
existing constraints, the last progress and the options that were already rejected — *before* re-deriving them.
Without it, read `DECISIONS.md`, the roadmap's leftovers and the newest thread entries. Then the ordinary waking
routine: `team pulse status` → `team digest` → `team inbox --ack` → `team resume --dry-run`
(see [workflows.md](workflows.md) I).

**On wrap-up** (after a delivery or a decision): ① land the conclusion and this round's evidence on disk — report,
review record, BOARD status, `DECISIONS.md` with rationale and impact ([protocol.md](protocol.md) §10); ② only
then add what holds **across tasks** to project memory, and park "do later" items as notes or roadmap leftovers.

**When memory and disk disagree — disk wins, then fix the memory.** Do not "average" them and do not trust the
more recent-sounding one: read the file, correct the entry (or archive it), and record why the drift happened if
it is interesting. A memory entry that survived a rewrite of the thing it describes is worse than no entry.

## 5. Lifecycles: what survives what

| Event | What happens to memory | What to do |
|---|---|---|
| `/compact` (or automatic compaction) | history is summarised; the raw turns stay retrievable through `ctx_search` / `ctx_expand` | nothing — this is what memory tooling is for |
| Restart (`pi -c`, or the pulse bringing the PM up) | the session continues, so the memory attached to it continues too | re-read `state/watchdog.log` and the newest thread entries to find where you stopped; do not redo finished work |
| `/reload` (skill updated on disk) | the skill text in the *current context* may still be the old one | re-read the file you are about to rely on; `team version --check` tells you whether the loaded version is current |
| The worktree is moved or renamed | sessions are keyed by **cwd**, so the memory of that path can be orphaned | never move an agent worktree ([protocol.md](protocol.md) §3, [troubleshooting.md](troubleshooting.md) §2); if it already happened, treat it as a new session and rebuild from disk |
| A different machine | nothing is shared: memory is per session and per machine | anything that must travel goes to disk or a `team meeting` — see §7 |

What magic-context honestly does **not** do:

- it does not make the PM stateless-safe — disk is still the only durable record;
- it does not sync between machines or users, and it is not shared with worker agents (they have their own
  sessions, and they do not read the PM's memory);
- it does not verify anything: an entry is a claim the PM wrote, exactly like a report is a claim an agent wrote;
- it does not survive the session being deleted — prune or revert a session and its memory goes with it.

## 6. When it is missing (and what "required" means)

Since D10 magic-context is a **required dependency**, not a recommendation: `team doctor` fails without it, and
`dispatch` prints a one-line warning (it does not block a worker — the evidence/spec layer is what is incomplete,
not the task). `TEAM_REQUIRE_MAGIC_CONTEXT=0` downgrades the failure to a warning for odd environments; the skill
then behaves exactly as it did when memory was optional.

With the dependency missing and downgraded, the routine below is what a session actually does — it is a degraded
mode, not an equivalent one: read `DECISIONS.md` (with rationale and impact), the roadmap's leftovers, the newest
entries of `threads/<agent>.md` and the last review records, and walk `templates/memory-seed.md.tmpl` as a
checklist instead of expecting recall. (The CLI still prints its output strings in Chinese; the line there is the
"not detected" warning, see [troubleshooting.md](troubleshooting.md).)

The fallback routine is the disk: read `DECISIONS.md` (with rationale and impact), the roadmap's leftovers, the
newest entries of `threads/<agent>.md`, and the last review records. `templates/memory-seed.md.tmpl` doubles as a
reading checklist in that mode: walk its items and answer them from the project, rather than expecting to recall
them.

What you lose without it: search over compacted history (you re-read files instead of recalling), and the ability
to park a note that resurfaces later — use the roadmap's leftovers for that instead. What you do **not** lose is
any evidence: reports, reviews, the board and the decision log are all files.

Two config keys matter here, both documented in [config.md](config.md): `TEAM_PI_SETTINGS_FILE` (where the
extension is detected; override it for tests or multi-user setups) and `TEAM_REQUIRE_MAGIC_CONTEXT=1` (make memory
a hard requirement — `team doctor` fails without it). A project should only set the latter when every PM session
is guaranteed to have it, otherwise the first session without it sees a failing `doctor`.

## 7. Keeping another PM (or a human) in sync

Memory is per session and per machine, so **anything another PM needs must be on disk** — or, for a different
project, in a `team meeting` ([meeting.md](meeting.md)): the transcript there is the only truth, and the peer PM
cannot read this project's memory. When a second PM takes over (a shift change, a second machine, a human reading
the project for the first time), the handover is the disk: `BOARD.md`, `DECISIONS.md`, the newest reviews, the
threads — plus the seed items from `templates/memory-seed.md.tmpl` so the newcomer can rebuild its own memory
rather than inherit yours. If a fact is only in your memory, then for everyone else in the system it does not
exist yet.
