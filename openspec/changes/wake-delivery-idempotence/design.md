# Design: `wake-delivery-idempotence` — the doorbell is at-most-once, the message is exactly-once

## 1. The incident record (what the durable files say)

All times UTC, all evidence from the project's own state under `.pi/team/state/` (read-only for this propose).

**dev2 (the first report).** `inbox-watch/teamsmith_dev2-e88859f1.wake` is 1929 bytes in 9 lines;
`teamsmith_dev2-e88859f1.seen` is 1701 bytes in 8 lines. The missing key is exactly the oldest line, the
`1789810336525` / `say` / 227-byte `M35 范围+1` line, and the ledger says it *was* delivered —
`2026-09-19T09:32:16.682Z wake n=1 total=1 inbox=dev2 kinds=say`. The 14:09 line (`1790086196029`, 427 bytes,
field `say`) has exactly one wake in the ledger (`2026-09-22T14:09:56.190Z wake n=1 total=4 inbox=dev2
kinds=say`); no dev2 wake exists after that, the spool's `1790086196029` is present in `.seen`, and the durable
inbox holds that summary once (`docs/team/inbox/dev2.md:82`). So the second presentation dev2 reported at
14:44:48 did not come from the watcher's send path.

**The PM (the second report).** `nudges.log` holds three identical-text nudges —
`16:13:56Z 未读通知 7 · 待复验 4`, `16:28:56Z 未读通知 7 · 待复验 4`, `16:43:56Z 未读通知 9 · 待复验 4` — with three
distinct spool ids in the pre-truncation spool (`1790093637236`, `1790094537381`, `1790095437514`; each appears
once in `/var/tmp/P71-pm-wake-spool-1746.bak`, 76100 bytes, 247 lines). The ledger delivered each of them
exactly once (`16:13:57.517 total=85`, `16:28:57.673 total=86`, `16:43:57.763 total=89`). After 16:43:57 the
ledger has **no** `kinds=nudge` wake until `19:45:38.901 total=100` (the new `未读通知 1` nudge), and `.seen`
contains all three (the PM's own `grep -c "待复验 4" .seen` = 3). The 17:46:49 truncation was recovered as
`spool shrink: size fell below offset=76100 …` + `rescan lines=0 dup=0 skipped=0 deliver=0 … total=92`, i.e.
the rescan delivered nothing; the eight lines appended afterwards produced exactly the eight later wakes
(each spool id maps to one ledger wake within ~200 ms: 17:55:11.123→.277, 18:36:07.580→.733,
18:55:17.407→.561, 19:06:06.807→.961, 19:11:36.300→.453, 19:42:56.255→.407, 19:43:12.760→13.072,
19:45:38.638→38.901), and the same ids are in `state/outbox/delivered.log`.

**The `total=1` line (the PM's item 4).** `14:33:07.285 wake n=1 total=1 inbox=dev kinds=say` is the **dev**
watcher: the line it woke about is `docs/team/inbox/dev.md:82`, appended at `14:33:07Z`
(`[say] agent:dev · P55 提醒…`), and that session's own `started target=teamsmith:dev … baseline=1958` is at
`11:46:36.930`. Its neighbours in the log (`14:32:59.391` / `.414`, dev3) are a different target's restart: the
ledger is a single file for all targets. `total` is the **session's** cumulative count of woken lines, not a
spool line count, so `total=1` means "first wake of this session" — the label is correct, nothing was read from
the head.

**What is genuinely broken in the durable record.**

1. The dedup memory is not a complete record of deliveries: dev2's `.seen` lacks the 09-19 delivery. The memory
   is written on the read path, after the read and beside the send, and its write failure is swallowed
   (`markDelivered`'s `catch`), so "delivered but unrecorded" is a state the files can hold. Within the 900 s
   horizon that shape replays on an external rewrite. (dev2's missing line is 3 days old, so the P28 stale rule
   saves that instance — it does not close the shape.)
2. The record precedes the send and the send's failure is swallowed: `wake()` does
   `seen += n; markDelivered(lines); appendLedger('wake …'); pi.sendMessage(...) catch {}`. A `wake` line in the
   ledger and an entry in `.seen` therefore prove *"we tried"*, not *"the session accepted it"* — and a thrown
   send leaves a silent loss. `pi.sendMessage(message, options?)` returns void (Pi docs,
   `docs/extensions.md` §pi.sendMessage), so "accepted" is the strongest truth available; nothing today records
   even that.
3. The reader's position is process memory only. Across a restart everything written before `session_start` is
   silently swallowed by `baseline = end of the last complete line` — no ledger counter, so "wake lost" and
   "wake never due" are indistinguishable from the files.
4. The wake text carries no identity: no line id, no source timestamp, no sequence. A recipient that receives a
   `deliverAs: followUp` wake hours after its line was written (the PM's 16:13/16:28/16:43 nudges, presented at
   ~17:5x/18:0x while the PM ran a long turn) cannot tell a late queued copy of an old line from a fresh
   duplicate, and two distinct lines with byte-identical text are indistinguishable by construction.

**Refuted as stated** (the brief asked for a verdict): "the wake path does not persist its offset, so it
re-reads the old line every round and `.seen` is not consulted on that path". Re-reading would have produced one
`wake` **and** one `dedup:` ledger line per round; after 16:43 the ledger has neither. The offset advanced in
memory, `deliverNormal`/`rescan` both consult the dedup set, and the three nudge sends the PM saw are the three
distinct lines. The real defect the PM measured is the *presentation* half (item 4 above), not a re-read.

## 2. Decisions

**D1 — Semantics: the wake is at-most-once; the message is exactly-once.** The wake is a doorbell; the durable
inbox line (written by the sender *before* the spool line, `outbox.sh:1128-1136`) is the message. Duplicates cost
real work and are indistinguishable from news — this incident consumed two agents' turns and a PM
investigation; a *lost* wake is recovered by the durable inbox on the next `team inbox` / `digest` / pulse nudge,
and must be visible in the ledger rather than silent. Therefore: never twice, sometimes never, and every "never"
is named. The brief's two candidate directions (① record-before-send, ② in-flight + three-state) collapse into
this; ②'s three-state judgment is the stronger form because it can still *recover* the one state in which a send
provably never happened.

**D2 — One durable per-target delivery journal replaces `.seen`.** `state/inbox-watch/<key>.deliver`,
append-only, one record per line, ISO-stamped:

```
start  <baseline-offset> <size> <head> <ts>       (one per session start)
read   <seq> <offset-after> <size> <head> <identity> <ts> <kind> <from> <durable> <preview>
intent <seq>
sent   <seq> <accepted-ts>
failed <seq> <reason>
floor  <oldest retained identity>        (written by compaction)
```

`identity` is the line's `id=` field when the sender supplied one, else the whole spool line (the P28 key).
The `read` record holds the wake material (everything the wake text needs), so recovery never depends on spool
bytes that an external rewrite may have destroyed. Ordering is the contract: `read` → `intent` → send →
`sent`/`failed`. The send happens only if `read`+`intent` were appended; an unwritable journal means *no wake*
(`deliver blocked`) and the lines stay unseen for a later tick — losing a doorbell is allowed, losing the
journal is not.

**D3 — Restart judgment is three-state, out of the journal, never out of memory.**

- `read` with no `intent` → the send never started: wake it once (freshness first) and ledger `recovery`.
- `intent` with neither `sent` nor `failed` (a torn tail reads as this) → unknown: do **not** wake; ledger
  `inflight assumed` once; treat as delivered from then on.
- `sent` → never again.
- `failed` → known-not-sent: retry at most once per tick, never after the horizon.
- an identity at or below the compaction `floor` → `unprovable`, never woken (the journal can no longer prove
  it was not delivered).

**D4 — Keep the startup baseline doctrine.** A line written before `session_start` that *no* session has read is
still swallowed, and the session's baseline stays what it is today: the current spool's end — the journal does
not change `notify-and-inbox#The wake reader's offset advances by the bytes it read, never past the file end`
or S5. What the persisted offsets are for is **audit**, not resumption: the `start`/`read` records give the
timeline a session left behind (where its reader stood, what it read, what it intended), and
`baseline swallowed n=<n>` names the complete lines present at startup that no journal record covers, so the
doctrine's cost is counted instead of silent. What the change adds is therefore exactly one exception to the
swallow: a line a *previous live* session read and died before sending is recovered, because the journal
proves a session was watching when it arrived. Resuming the reader from the persisted watermark (delivering
everything appended while the session was down) is deliberately **not** chosen: it changes a documented
doctrine inside a defect-fix change and would wake for backlog (`S5`'s fresh-before-startup line) — the stale
rule would hide most of it, but "hidden by age" is not a contract.

**D5 — Identity in the wake text.** Header `[teamsmith] inbox wake #<seq> · <absolute send time>`, each row
carrying its line's absolute source time and its identity (`id <identity>`). Two byte-identical payloads from
two lines now differ in the text, and a repeated identity is provably a replay from durable files. This is what
the recipient-side self-evidence requirement asks for, and it is also what makes the PM's own case readable
after the fact: three nudges with identical text, three identities.

**D6 — The sender writes the id into the spool line.** One field appended to the existing five
(`outbox.sh:1137`), carrying the outbox entry name — the same id `state/outbox/delivered.log` records. The
recipient (or the PM) can then tie a wake to the sender's own ledger with `grep`. Old lines without the field
keep the whole-line identity, so the change is backward compatible with the current spool and fixtures.

**D7 — Delivery mode stays `followUp` (the mode is spec'd).** The residual is named, not papered over: while the
recipient is mid-turn a wake is presented at the next turn boundary, which can be hours later; with D5 that
presentation is visibly old (absolute source time) and identifiable. `deliverAs: 'steer'` would present it
sooner but interrupts the turn; that is a product decision, not this defect fix. There is no ack API to require
presentation, so the journal's terminal record means "the session API accepted the message".

## 3. How each reported shape is answered

| Reported shape | Answer |
|---|---|
| dev2: the 14:09 line presented again at 14:44 | Not a watcher send (one `wake`, `.seen` has it). D5 makes the two presentations provably the same identity; D2/D3 make a genuine second send impossible and provable. |
| PM: the same nudge text delivered "twice in 10 minutes" | Two distinct lines with identical text (16:13 and 16:28, ids `1790093637236`/`1790094537381`), each sent once and presented late. D5 distinguishes them; D1/D3 guarantee no re-send. |
| PM: an old nudge reappears after the spool was truncated (`deliver=0`) | The queued `followUp` copy of the 16:43 send, not a rescan (the rescan line says `deliver=0`). D5 timestamps it. |
| dev2's `.seen` (8) < `.wake` (9) | The 09-19 delivery predates the memory and was never recorded there. D2's journal is written *with* the delivery, so the gap cannot be created again; D3's `unprovable`/stale rules cover imported history (`grep count 3` in the PM's `.seen` is not a dedup failure either). |
| "delivered but not recorded must never be delivered again" | D2 (record before send, append-only, torn tail = unknown) + D3. |
| "replay must be distinguishable from news in the ledger" | The modified ledger requirement: `replay suppressed`, `inflight assumed`, `recovery`, `unprovable`, `baseline swallowed`, plus `seq=` on every wake. |
| "the recipient must be able to prove it from files" | D5 + D6: identity, source timestamp, wake sequence, sender-log cross-reference. |
| "`total=1` / the mislabelled line" | Refuted with the ledger and the inbox line (`dev.md:82`, the 11:46:36 `baseline=1958`); `total` is a per-session counter. |
| "stale lines (> `TEAM_INBOX_WATCH_STALE_SEC`) must never wake" | Already true on the read/rescan paths; the delta adds the recovery path to the rule and a scenario that proves a stale `read`-without-`intent` line is counted, not woken. |
| "the same text must not reappear on any later path" | At-most-once *enqueue* is now journal-provable; a session-side duplicate is provable by identity (D5) and reportable, not silently repeated. |

## 4. Falsifiable fixture plan (each item is red on today's tree)

A **child-process runner** is added to the harness so crash cases kill a real process: the parent starts
`node team-inbox-watch-harness.mjs --child …` with a fixture knob (`TEAM_INBOX_WATCH_ABORT_AFTER=read|intent`,
fixture-only, ignored outside `TEAM_SMOKE_FIXTURE=1`), the child appends/reads the line and exits at the
injection point, the parent continues with a new session in a *new* process.

- **S25a** kill after `read` → restart → exactly one wake, ledger `recovery n=1`; a rewrite of the same bytes
  adds none. (Break `intent`-before-send: the second wake appears.)
- **S25b** kill after `intent` → restart → zero wakes, `inflight assumed n=1`, `.seen`-independent (delete
  `.seen` before restart), durable inbox line intact. (Break the state read: `intent` treated as "not started"
  → a second wake appears.)
- **S25c** message API raises → `wake failed`, no delivery record, one retry on the next tick, never after the
  horizon; and an unwritable journal → no send, `deliver blocked`, delivered once after it becomes writable.
- **S25d** two byte-identical lines, two ids → two wake texts differing in identity/time; rewriting one → no
  wake, `replay suppressed reason=rescan`, `total` unchanged. (Break the identity: the two texts become
  indistinguishable — the assertion is on the printed identity.)
- **S25e** upgrade: a `.seen`-only tree imports once, then deleting `.seen` changes nothing; torn tail → no
  re-send + `torn tail`; compaction → `floor=`, bound held, retained identities still suppressed.
- **S25f** the incident replay: a fixture built from the archived bytes (the dev2 nine lines; the three nudge
  ids `1790093637236`/`1790094537381`/`1790095437514`; the PM's 76100-byte pre-truncation spool from
  `/var/tmp/P71-pm-wake-spool-1746.bak`, clipped to a bounded fixture) with the
  journal seeded from the incident's `sent` facts must produce **zero wakes** and classify the rewrite as
  `replay suppressed`, matching the recorded `rescan … deliver=0`.
- **S25g** startup accounting: a spool whose complete lines have no journal record produces
  `baseline swallowed n=<n>` with the `started … baseline=<spool size>` line unchanged (the existing `S5`
  assertion stays green because the baseline is still the current spool end).
- **S26** the wake text contract: shape unchanged (`customType`, `triggerTurn`, `followUp`, bounded preview, no
  payload dump) plus `#<seq>`, the source timestamp and the identity; the identity appears exactly once in
  `state/outbox/delivered.log` for a real-CLI delivery (S10's end-to-end shape extended).

Existing assertions that must move with the artifact (not weaken): harness S11's `dedup: skipped` check → the
`replay suppressed` line; S13's `<key>.seen` persistence → the journal; smoke's 12b-pi titles and the
`12b-pi M43：去重记忆跨会话重启` assertion. `flip-p71.sh` carries the break-it side of S25a–S25d.

## 5. Residuals and non-goals

- **Session-side queue copies.** Pi may present an accepted wake long after the fact, and an accepted-but-never-
  presented wake is knowable only as `sent`. No ack API exists (D7); the change makes both provable from the
  text and the journal instead of invisible.
- **The pulse's periodic re-nudge with unchanged text** (`TEAM_PULSE_NUDGE_GAP`) is intentional; the change
  makes consecutive nudges distinguishable rather than suppressing them.
- **`TEAM_INBOX_WATCH_STALE` (300 s, registration liveness, sender side) vs `TEAM_INBOX_WATCH_STALE_SEC`
  (900 s, line age, reader side)** stay as they are; the names are documented in the references.
- **`.seen` retirement is one-way** (import once); a rollback to the previous tree would start with an empty
  memory — the imported keys are in the journal and the old code ignores the journal. Documented in the
  references so an operator knows the direction.
- **No `deliverAs` change, no pulse cadence change, no outbox entry-format change** beyond the one `id` field.
