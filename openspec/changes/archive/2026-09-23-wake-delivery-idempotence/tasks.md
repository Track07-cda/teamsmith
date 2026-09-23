# Tasks: `wake-delivery-idempotence`

Planning only — nothing in this file is executed by the propose task (P71). **One apply brief** (five verifiable
batches, landed in order) plus **one independent verify brief** (a different agent, never the implementer). The
change touches one capability, `notify-and-inbox`, with three **ADDED** requirements and two **MODIFIED** ones
(`deltas: notify-and-inbox`).

Coverage map (requirement → items): **notify-and-inbox#A wake is at most once: the delivery record is written
before the send and survives a restart** → 1.1–1.4, 2.1–2.3, 3.1–3.3, 5.2, 5.3; **notify-and-inbox#A wake names
its source line so a recipient can prove what it is** → 2.1–2.4, 3.3, 5.3; **notify-and-inbox#The delivery
journal is the only dedup memory, and it is bounded and auditable** → 1.2, 4.1–4.3, 5.3;
**notify-and-inbox#Only fresh lines wake the session; stale lines stay silent and countable (MODIFIED)** →
3.2, 5.3; **notify-and-inbox#The ledger separates new traffic from recovery (MODIFIED)** → 1.3, 3.3, 4.2, 5.3.
Every item names the capability it moves; no item is an orphan.

Both briefs carry the change's foreign key: `change: wake-delivery-idempotence`, `deltas: notify-and-inbox`,
`phase: apply` (dev) and `phase: verify` (a different agent).

Batches: **B1** — the journal and the write-ahead order (1.x); **B2** — identity in the wake text and the
sender's id field (2.x); **B3** — the three-state restart judgment and recovery (3.x); **B4** — the ledger, the
journal bound and the `.seen` retirement, with the migrated assertions (4.x); **B5** — the incident replay,
gates and evidence (5.x). B1 is a prerequisite of B2–B4; B2 and B3 are independent of each other; B4 needs B1;
B5 needs B1–B4.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s (the harness,
`flip-p71.sh`, the smoke pins need no PM grant); `skills/teamsmith/extension/team-inbox-watch.ts`,
`skills/teamsmith/scripts/lib/outbox.sh` and `skills/teamsmith/references/{agent-adapters,troubleshooting}.md`
need the brief's explicit grant. `openspec/**` stays with the phase's owner, `docs/team/**` with the PM.

Fixture rules (unchanged): every fixture clears inherited team identity first and keeps its private tmux
server and its `BASHPID`-guarded cleanup; no call may reach the default tmux server; injection knobs are honoured
**only** under `TEAM_SMOKE_FIXTURE=1` and are printed as ignored otherwise; the gate runs with stdin on
`/dev/null`; the harness keeps its reverse guard over the real repository's `state/`. Crash cases MUST run the
extension in a **separate process** that is killed at the injection point — an in-process `session_start` cycle
is not a restart, because the journal must be proven to be the authority rather than memory.

Documented residuals (design §5, not fixed here): the `deliverAs: followUp` presentation delay and the
session-side queue (no ack API — the wake text and journal make them provable instead); the pulse's periodic
re-nudge with unchanged text; `TEAM_INBOX_WATCH_STALE` (registration liveness, sender) vs
`TEAM_INBOX_WATCH_STALE_SEC` (line age, reader); the one-way `.seen` retirement. No item below may widen a
bound or weaken an existing assertion to make the incident disappear.

## 1. B1 — the delivery journal and the write-ahead order (`notify-and-inbox` ADDED)

- [x] 1.1 The per-target append-only journal `state/inbox-watch/<key>.deliver` exists with the record kinds and
  field order of design §2 D2 (`start` / `read` / `intent` / `sent` / `failed` / `floor`, each ISO-stamped, the
  `read` record carrying identity, offset, size, head fingerprint, source time, kind, from, durable and the
  bounded preview). A line's identity is its `id=` field when present and the whole spool line otherwise.
  Verify: a harness case appends one fresh line and asserts the record shapes and their order in the file, and
  that no record is written for a stale line; the file is plain text, one record per line.
- [x] 1.2 The write-ahead order is enforced: no `pi.sendMessage` happens without `read`+`intent` on disk, and an
  unwritable journal directory produces **no** send, one `deliver blocked` ledger line, and the line still
  unseen. Verify: harness S25c's unwritable-journal half (chmod 0500 on a scratch state dir or an equivalent
  deterministic failure), then making it writable delivers the line exactly once; a `read`-only journal is what
  the crash runner sees in 3.1.
- [x] 1.3 `sent` is appended only after the session API returned, and `failed` only when it raised; both are
  one ledger line each (`wake … seq=` / `wake failed seq=<n> reason=<why>`). Verify: a fake host that throws for
  one batch — the ledger reads `wake failed`, no `sent` record exists, and the next tick retries the same line
  once and records `sent`; a fake host that returns — `sent` follows the call.
- [x] 1.4 A send failure is retried at most once per tick and never after the freshness horizon, and a retry
  that succeeds is the only wake that line ever produces. Verify: harness case (throw, throw, success) asserts
  one wake, one `wake failed` line per attempt, and a `stale=` classification once the fixture back-dates the
  line past `TEAM_INBOX_WATCH_STALE_SEC` — no wake in that step.

## 2. B2 — identity in the wake text and in the spool line (`notify-and-inbox` ADDED)

- [x] 2.1 The sender writes the id of its own durable record into the spool line: the id appended at
  `scripts/lib/outbox.sh:1137` is the outbox entry name (the same string `state/outbox/delivered.log` records
  in its `name` column), and a line without the field keeps working (whole-line identity). Verify: run the real
  CLI on the pi route (the S10 end-to-end shape) and `grep -c "<entry-name>" state/outbox/delivered.log` = 1
  while the spool line carries `id=<entry-name>`; a hand-appended 5-field line is still delivered.
- [x] 2.2 The wake text carries the wake's monotonic `#<seq>`, its absolute send time, for every listed line
  that line's absolute source timestamp and its identity, and the path of the delivery journal the identities
  were recorded in. Timestamps are ISO-8601 UTC, never relative ages; the preview stays bounded and folded to
  one line per line; no payload dump. Verify: harness S26 asserts `#<n>` grows by one per wake, the source time
  is the line's first field rendered as UTC, the printed identity is the line's `id=`/whole line, and the named
  journal path resolves to the file the case's ledger lines came from; S4's no-dump assertion stays green.
- [x] 2.3 Two spool lines with byte-identical payloads and different ids produce two wake texts that differ in
  identity and source time, and neither is re-woken by a rewrite. Verify: harness S25d (two nudge-shaped lines
  with the production text, the ids from design §1: `1790093637236` / `1790094537381`), then a rewrite of one
  of them → zero wakes and `replay suppressed reason=rescan`.
- [x] 2.4 The wake's identity is cross-referenceable: for a real-CLI delivery the id printed in the wake text
  resolves to exactly one `state/outbox/delivered.log` record and to the durable inbox line the wake names.
  Verify: the S10 case extended to assert the id's uniqueness in the log and the inbox line's presence.

## 3. B3 — the three-state restart judgment and recovery (`notify-and-inbox` ADDED)

- [x] 3.1 A child-process crash runner in the harness: `TEAM_INBOX_WATCH_ABORT_AFTER=read|intent` (fixture-only,
  gated by `TEAM_SMOKE_FIXTURE=1`, printed as ignored otherwise) makes a **separate process** exit at the
  injection point, and the parent continues with a fresh process. Verify: the runner's own case shows a real
  `SIGKILL`/exit code and no `sent` record; the knob outside `TEAM_SMOKE_FIXTURE=1` is inert.
- [x] 3.2 `read` without `intent` → exactly one recovery wake (`recovery n=1`), the material coming from the
  journal, and the freshness rule applied first: a recovered line past the horizon is counted `stale=1`, never
  woken (the MODIFIED stale requirement's new scenario). Verify: S25a (fresh) and the stale half of 1.4/3.2;
  both under the child runner.
- [x] 3.3 `intent` without `sent`/`failed` → zero wakes, one `inflight assumed n=1`, treated as delivered from
  then on; a torn trailing record is read as this state with a `torn tail` ledger line. Verify: S25b (delete
  `.seen` before the restart to prove the journal is the authority) and S25e's torn-tail step; a later rewrite
  of those bytes adds no wake and no `total=`.
- [x] 3.4 `sent` is terminal across restarts and across rescan; an identity below the compaction `floor` is
  `unprovable` and never woken. Verify: S25e's compaction step (bound held, `floor=` printed, every retained
  identity still suppressed) and a below-floor line re-read → `unprovable`, no wake, `total` unchanged.

## 4. B4 — the ledger, the journal bound and the `.seen` retirement (`notify-and-inbox` MODIFIED)

- [x] 4.1 The journal is the only dedup memory: a `<key>.seen` from the previous code is imported once,
  additively, and recorded; afterwards deleting, emptying or corrupting `<key>.seen` changes no decision.
  Verify: S25e's upgrade step (pre-seed `.seen`, no journal → import; rewrite silent; `rm .seen` → rewrite
  still silent); harness S11 and S13 and the smoke `12b-pi M43：去重记忆跨会话重启` pin move to the journal
  (`<key>.deliver`) and are **not** weakened.
- [x] 4.2 The modified ledger requirement's counters exist and are counted apart from `total=`: `replay
  suppressed n=<n> reason=<normal|rescan>`, `inflight assumed n=<n>`, `recovery n=<n>`, `unprovable n=<n>`,
  `deliver blocked`, `torn tail`, `baseline swallowed n=<n>`; every `wake` line names `seq=` and the identities
  it carries; `rescan … deliver=0` still coexists with a non-zero `dup=`. Verify: one harness case per counter
  (each counter appears exactly once per event it names) and S9's ledger-shape assertions extended, not
  relaxed; the startup case (S25g) asserts `baseline swallowed n=` while the `started … baseline=<n>` line still
  names the current spool end, so the P28 baseline contract and S5 are untouched.
- [x] 4.3 Compaction is bounded and non-resurrecting: past `TEAM_INBOX_WATCH_JOURNAL_MAX` (default 1024) the
  file is rewritten under the bound with its `floor=` recorded, and the retained identities keep their state.
  Verify: a harness case that writes past the bound on a scratch state dir and asserts size, `floor=`, and a
  rewrite of retained and evicted identities (`replay suppressed` and `unprovable` respectively).
- [x] 4.4 The references say what the code does: `references/agent-adapters.md` (§4a.1 delivery contract) and
  `references/troubleshooting.md` describe `<key>.deliver`, the record order, the three states, the counters,
  the bound and the one-way `.seen` import, and no longer present `<key>.seen` as the dedup memory. Verify:
  `grep -rn 'seen' skills/teamsmith/references/` shows only the migration note; the two files' §-numbers keep
  their existing anchors.

## 5. B5 — the incident replay, gates and evidence

- [x] 5.1 The incident replay fixture: the archived bytes (the dev2 nine-line spool with ids `1789810336525`
  … `1790086196029`; the three nudge ids `1790093637236` / `1790094537381` / `1790095437514`; the PM's
  76100-byte pre-truncation spool from `/var/tmp/P71-pm-wake-spool-1746.bak`, clipped to a bounded fixture) with
  a journal seeded from the incident's `sent` facts must produce **zero** wakes, classify the rewrite as
  `replay suppressed`, and reproduce the recorded `rescan … deliver=0`; the dev2 line missing from `.seen` is
  classified by the import/stale rules and never woken. Verify: the harness case prints the classification per
  incident id and the assertion list; the raw archived file is cited by path and size in the report.
- [x] 5.2 `flip-p71.sh` carries four break-it mutations, each with a named red: (a) drop the `intent` write →
  S25a reds with a second wake; (b) read `intent` as "not started" → S25b reds; (c) drop the identity from the
  wake text → S25d reds; (d) drop the `floor` rule → 3.4 reds. Verify: `bash skills/teamsmith/tests/flip-p71.sh`
  exit 0 with each mutation's red tail printed.
- [x] 5.3 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, then the harness on the changed tree,
  then `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** gate once — paste
  the tails; `git status --porcelain` clean. The two MODIFIED requirements must collide with no open change's
  delta (grep the open changes for both base requirement names and paste the result).
- [x] 5.4 The report's evidence: the requirement→item and scenario→item→evidence maps; every fixture's raw
  tail; the incident replay's per-id classification; the four mutation reds; the gate tails; and the explicit
  statement of which incident claims were refuted (design §1: `total=1` is a per-session counter; there was no
  unpersisted-offset re-read) with the ledger lines that refute them.

## 6. V — independent verification (a different agent)

- [x] 6.1 Rerun, out of tree and on the apply's tip: `openspec validate --all --strict`, the harness, the full
  gate, `flip-p71.sh`; exercise every scenario of the delta with red/green evidence (including the stale
  recovery scenario and the two byte-identical lines) and record it in `docs/team/reviews/P71.md`. Confirm the
  incident replay on the archived bytes independently (its own fixture, not the apply's), that no existing
  assertion was weakened to pass, and that `<key>.seen` is no longer written. A PASS that still carries
  findings is rework (`DECISIONS.md`).

> **PM 勾选说明（2026-09-23）**：propose=P71（verify 席位）· apply=P81（dev2）· verify=P89（dev）——三人分工合规。
> 验收：P89 自建 86 断言包（干净副本复跑一致）· fail-closed 实证（日志不可写 → 零投递 + `deliver blocked` +
> 该行保持未读；恢复可写后**恰好一次**、记为普通唤醒）· `flip-p71.sh` 6 条 · FAST 2641/0 · 全量 3308/0。
