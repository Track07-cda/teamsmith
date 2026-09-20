# Design: `inbox-spool-resilience` — byte-true offsets, evidence-based shrink, and a stale gate

## 1. Context

Read on `task/P25-propose` (branch point `f67a338`) and measured read-only against this repository's own ledger and
state; nothing in this phase changes code.

- **The channel.** Senders (the outbox drain) write the durable inbox line first and then append a one-line pointer
  to `state/inbox-watch/<key>.wake` (`scripts/lib/outbox.sh:990–1020`). The extension `extension/team-inbox-watch.ts`
  watches that file: at `session_start` it records a **baseline** (lines already in the file never wake anyone),
  then on every `fs.watch` event and every poll tick (`TEAM_INBOX_WATCH_POLL_MS`, default 5000) it reads the new
  complete lines and sends one `pi.sendMessage(…, {triggerTurn:true, deliverAs:'followUp'})` per batch
  (`wake`, line 490).
- **Code points.** `readNewLines()` line 351, `baselineOffset()` 379, `trimSpool()` 386, `loadSeen()` 437,
  `markDelivered()` 449, `deliverNormal()` 533, `rescan()` 544, `flush()` 558; defaults at 57–62
  (`REPLAY_MAX` 20, `SEEN_MAX` 512). Writer's preview clip: `outbox.sh:1017` (`LC_ALL=C cut -c1-700`), spool append
  at 1018.
- **Evidence files** (main worktree, read-only): `.pi/team/state/inbox-watch.log:179–205`,
  `.pi/team/state/inbox-watch/teamsmith_pm-d59ea631.{wake,seen}`.
- **Test surface.** `tests/team-inbox-watch-harness.mjs` (fake Pi host, scratch repo, real CLI in S10, real-state
  reverse guard) with cases S1–S17; `tests/flip-m43.sh`, `tests/flip-m46.sh`; `smoke.sh` sections 12b-pi and
  12b-pi2. The harness is the fixture of record for this change too.

### 1.1 The measured bytes

- `.seen` line `1789837182057	knock	pm	pm	…` is the spool line written **2026-09-19T16:59:42.057Z**. Its
  preview field decodes to **701 bytes containing exactly one U+FFFD**; the writer's clip is 700 bytes, and no
  other line in either file carries a replacement character. (The line is the `[manual] agent:pm · M40 交付完成`
  knock; the durable inbox has the full text.)
- The incident ledger: `started … baseline=19635` (06:42:39) on a file whose real size is 19634; then
  `spool shrink: size fell below offset=19635` followed by a `rescan` **every ~5 s** from 06:42:44 to 06:44:14 —
  `rescan lines=66 dup=0 skipped=46 deliver=20`, then `dup=20 skipped=26 deliver=20`, `dup=40 … deliver=20`,
  `dup=60 … deliver=6`, then `dup=66 deliver=0` repeated. It stopped only when the spool was cleared by hand.
- The 66 lines' spool timestamps run from 2026-09-18T12:48 to 2026-09-20T06:04 — hours to 1.5 days old. The 66
  lines were never in `.seen` (`dup=0` on the first rescan).

### 1.2 The producer, reproduced

`cut -c1-700` is byte-based in both `C` and `C.UTF-8` on this host (GNU coreutils 9.10) and appends a newline when
the input lacks one; the writer's `$( )` strips that newline:

```sh
$ python3 -c "open('/tmp/cutin','wb').write(b'xy' + ('红'*300).encode())"   # byte 700 splits a 3-byte char
$ LC_ALL=C cut -c1-700 /tmp/cutin | od -An -tx1 | tail -1
 ba a2 e7 ba                                      # raw output ends mid-character (700 bytes + newline)
# after $( ) strips the newline: 700 physical bytes, invalid UTF-8 at byte 698,
# decoded length = 701, exactly one U+FFFD — the shape measured in .seen
```

## 2. Root cause

### 2.1 The producer can write a spool line that is not valid UTF-8

`team_inbox_watch_deliver` flattens the payload and clips the preview with `LC_ALL=C cut -c1-700`. A clip that
lands inside a multi-byte character leaves the partial bytes in the spool line; the durable inbox line keeps the
full payload and is unaffected. The spool file is therefore allowed to contain arbitrary bytes, and the reader must
be correct for arbitrary bytes — not assume valid UTF-8.

### 2.2 The reader's advance is a decode→re-encode round trip, so it can exceed the file size

`readNewLines()` computes (line 362–368):

```ts
const buf = Buffer.alloc(size - offset)
readSync(fd, buf, 0, buf.length, offset)          // return value ignored
const text = buf.toString('utf8')                  // invalid bytes → U+FFFD
const end = text.lastIndexOf('\n')
const consumed = Buffer.byteLength(text.slice(0, end + 1), 'utf8')   // ← re-encoded length
return { lines, offset: offset + consumed, shrank: false }
```

`Buffer.byteLength` of a decoded slice is **not** the number of bytes that were read: each maximal invalid
subsequence becomes one U+FFFD and measures 3 bytes. A 3-byte character clipped to 2 bytes therefore costs 1 extra
byte (1 byte → +2, a 4-byte character → +1…+3). With exactly one such line in the file, `baselineOffset()` returns
`size + 1`; `offset ≤ size` is violated **by construction**, deterministically, for as long as the file's bytes
stay the same. That is the 19635 vs 19634 in the ledger.

Two further defects in the same function are fixed in the same rewrite, but they are not this incident's cause:
the ignored `readSync` return value (a short read leaves NUL padding; `lastIndexOf('\n')` then lands in the valid
prefix, so the effect is an *undershoot* and a re-read — dedup absorbs it, the ledger would show spurious
`dedup:` lines), and the string round trip for line splitting (line boundaries must come from the raw buffer).

### 2.3 `size < offset` is treated as evidence of an external rewrite, and rescan never converges

`flush()` (558) reads `shrank` and calls `rescan()`, which sets `offset = readNewLines(spool, 0).offset` — the same
overshooting arithmetic. So the next tick compares `size < offset` again, forever: no counter, no convergence
check, no distinction between "the file was rewritten" and "our own offset is wrong". The poll makes the damage
periodic (one rescan + two ledger lines per 5 s). M43's rules (shrink must be recorded, dedup, bounded rescan)
all assume `shrank` is trustworthy; it is not, because the reader can manufacture it.

### 2.4 The rescan's freshness oracle is the dedup memory, and `.seen` answers the wrong question

`rescan()` starts at 0 and ignores the session baseline (S5's "lines written before `session_start` never wake").
Its only filter is `delivered` (`.seen`: "have we woken about this line in the last 512 deliveries?"), which is not
"was this line written recently?". The 66 lines had never been delivered — they arrived during periods when a
session baseline covered them — so they were "new" to the rescan and the replay bound turned them into four wakes
(20/20/20/6, 06:42:44–06:42:59). A stale gate is therefore the invariant that prevents this user-visible damage
even when the offset arithmetic is wrong; it must gate every path, not just the rescan.

### 2.5 Relationship to M43's incident and to the M43/M46 assertions

The 2026-09-19T16:59 replay that M43 was diagnosed from needs no external force to be explained: the invalid-preview
line was written at 16:59:42.057 and the first 42-line replay was logged at 16:59:43.940; the pre-M43 code silently
reset `offset = 0` on `size < offset`, and the same skew reproduces it. This change does **not** weaken M43's
response to a genuine truncate+rewrite — S11, S12, S13 and their smoke pins must stay green — it removes the false
trigger. M46's skip records, degradation reporting and identity guards are untouched.

### 2.6 Where this differs from the brief's hypothesis

The brief says the offset is advanced "by the buffer length, not by the bytes `readSync` actually read". The effect
(offset past the file end) is right, but the mechanism is neither: it is a **re-encoded length** of the decoded
slice. It needs no concurrent writer and no short read — a static file with one clipped preview reproduces it
deterministically, which is why the baseline was wrong at startup before any tick. Honouring `readSync`'s return
value is still worth doing (it is a separate latent defect, §2.2), but it is not the fix for this incident.

## 3. Goals / Non-Goals

**Goals.** (1) Make the offset an accounting of bytes actually read, so it can never exceed the file size.
(2) Make a shrink a decision with evidence and a guaranteed end state, so no file state can produce an unbounded
rescan loop. (3) Make staleness — not the dedup memory — the gate for waking. (4) Let the ledger answer "new
traffic or recovery?" at a glance. All four with fixtures that fail on today's tree.

**Non-Goals.** The wake channel (`fs.watch`, `pi.sendMessage`), the outbox write path, `.seen`'s format and capacity,
the writer-side byte clip (`scripts/**` is PM-owned; §7.1), the replay bound, the dedup semantics, the trim cap,
backoff, any other capability.

## 4. Decisions

### D1. Spec home: four ADDED requirements in `notify-and-inbox`

The watch/spool channel has **no requirement today** — `grep -rn 'spool\|wake\|inbox-watch' openspec/specs/`
matches only the watchdog's own wake-ups and two delivery-guard prose references. So there is nothing to modify:
the delta is ADDED-only, four requirements with distinct names, and no existing requirement is restated. That is
also what keeps **P27 (backfill)** composable: P27 adds its own requirements to the same capability file and
neither change rewrites the other's text or the six existing requirements.

### D2. The reader advances by bytes, and never delivers a fragment

`readNewLines` is rewritten to honour `readSync`'s return value, slice the buffer to the bytes actually read, find
the last `0x0a` **on the raw buffer**, split lines from the raw bytes, and decode only per line. `consumed =
end + 1` is a byte count; no character-set round trip is involved. When the read starts inside a line (reachable
only after a clamp, D3), the bytes up to the next `\n` are skipped and the skip is recorded (`offset resync`);
a manufactured fragment must never become a wake.

### D3. A same-head small regression is a repair; everything else is a rewrite

The watcher remembers the head fingerprint (the first `min(256, size)` bytes) when the offset is established
(baseline, successful advance, rescan). On `size < offset`:

| Observation | Action | Ledger |
|---|---|---|
| head unchanged and `offset - size ≤ TEAM_INBOX_WATCH_CLAMP_BYTES` (default 64) | `offset := size` | `offset clamp from=… to=… head=same` |
| head unchanged and the regression is larger | bounded rescan | `spool shrink …` + `rescan …` |
| head changed | bounded rescan | `spool shrink …` + `rescan …` |

Why the head and a bound rather than the raw difference: a 1-byte difference is not evidence that anyone rewrote
the file (it is exactly the shape our own arithmetic produced), while a rewrite that replaces the prefix changes the
head and a rewrite that replaces a large tail moves the size by more than a few bytes. What the clamp can lose is
bounded and named: a same-head rewrite that *replaces* content after the offset and lands within 64 bytes of the
old size would be treated as a repair — everything the old offset already covered was delivered, so the loss is
limited to lines such a rewrite introduced, and the ledger shows the clamp (a human can see it). The alternative —
rescan on every regression — is what produced the incident.

**Clamp target: `offset := size`, never the previous line boundary.** Walking back to the last `\n` can cross into
content that predates the baseline and re-deliver a line S5 deliberately silenced; the reader's mid-line start rule
(D2) absorbs the partial line instead.

### D4. Convergence is a protocol property, not a consequence of correct arithmetic

- After any rescan, the offset is the end of the last complete line and is `≤ size`.
- A rescan is justified by *evidence*, so an **identical `(size, head)` observation must not rescan twice**: it is
  recorded (`shrink repeat`) and clamped. The guard is per shrink episode (cleared by a normal advance), so a later
  shrink with the same numbers is evaluated afresh.
- One ledger line per action; no per-tick repetition, and no backoff (the fixed poll cadence stays — M20 rejected
  exponential backoff).

This is deliberately independent of D2: even if a future reader regresses into an overshooting advance, the
protocol cannot loop (the mutant tree in §6.2 pins exactly that).

### D5. Staleness gates every wake; the ledger carries the count

A line's age comes from field 1 (epoch milliseconds, stamped by the sender at delivery time —
`team_epoch_ms` at `outbox.sh:1018`). A line older than `TEAM_INBOX_WATCH_STALE_SEC` (default 900) is never woken
about, on the normal path or through a rescan; it is counted (`stale=`) and its bytes stay in the spool. Its
readable copy is the durable inbox line the sender writes **before** the spool line (`inbox-written` / append
ordering, `outbox.sh:990–1020`) for `say`/`notify`/`draft`, or the sender's own log for the pointer-only
`knock`/`nudge` lines. Pointer-only stale lines are **not** copied into an inbox by the watcher: fabricating a
durable line would change what `team inbox` counts and could double-report. A timestamp that does not parse is
treated as fresh and counted (`unparsable=`) — never swallowed. The baseline path delivers nothing, so the gate only
has work on the other two paths.

### D6. Ledger: keep the existing field prefix, append the new counts

- `started … baseline=<n>` — unchanged (now a true byte count).
- `wake n=<woken> total=<cumulative> …` — meaning unchanged; `n` can no longer contain stale lines.
- `rescan lines=<read> dup=<already delivered> skipped=<over the replay bound> deliver=<woken> stale=<old>
  unparsable=<bad ts> total=… inbox=…` — `lines/dup/skipped/deliver` stay the leading run **verbatim** so M43's
  assertions (flip-m43 S12/S13 and the smoke pins) match without edits; the new counts follow.
- New lines: `offset clamp from=… to=… head=same`, `shrink repeat size=… head=… action=clamp`,
  `offset resync skipped=<bytes>`.
- `total` still counts only lines actually woken about; a dedup-only or stale-only recovery leaves it unchanged.

### D7. `.seen` keeps its format and capacity

The incident's 66 lines were never in it, so its cap was not a contributing cause; changing the on-disk format
would churn M43/M46 assertions and any operator muscle memory for no measured gain. (Design noted because the brief
allows touching `.seen` only with evidence.)

### D8. New keys are read from the environment, like the existing ones

The extension already reads `TEAM_INBOX_WATCH_*` from `process.env` (it cannot source the project config). The two
new keys follow that pattern, with `envNum` ranges:

| Key | Default | Range | Meaning |
|---|---|---|---|
| `TEAM_INBOX_WATCH_CLAMP_BYTES` | 64 | 1 … 1 MiB | same-head regression at or below this is a repair, not a rewrite |
| `TEAM_INBOX_WATCH_STALE_SEC` | 900 | ≥ 1 | lines older than this never wake |
| (fixed) head prefix | 256 bytes | — | the head fingerprint compared on a regression |

No key is added to the project config, so no change to `templates/config.sh.tmpl` or `references/config.md`.

## 5. Verification plan

### 5.1 New harness cases (the fixture is the existing fake-Pi harness)

- **S18 (D2/R1).** Append a spool line whose preview is byte-clipped mid-character (raw bytes, e.g. the §1.2
  reproduction), with the file ending in `\n`, then start the session. Assert: `started … baseline=` equals
  `statSync` size; no `spool shrink` line appears; three idle ticks add nothing; a complete line appended next
  wakes exactly once and its preview is intact (no leading fragment). *Red today*: baseline = size + 1, a
  `spool shrink` per tick.
- **S19 (D3/D4/R2).** (a) With delivered lines in `.seen`, rewrite the file with its last byte removed → exactly
  one `offset clamp`, no `spool shrink`/`rescan`/wake, and a later append wakes once. (b) Replace the file with a
  shorter one whose head differs → one `spool shrink` + one `rescan …`; the next tick adds nothing (converged).
  (c) The same `(size, head)` observed again → `shrink repeat`, no second `rescan`.
- **S20 (D5/R3).** (a) A spool line timestamped an hour ago and absent from `.seen`, whose durable inbox line
  exists → `stale=1`, no wake, `total` unchanged, inbox line still present. (b) A fresh line afterwards → one wake,
  only that line, `total` +1. (c) A line whose timestamp is not a number → delivered, `unparsable=1`.
- **S21 (D6/R4).** (a) A rewrite carrying only delivered lines → `deliver=0` with non-zero `dup=`, `total`
  unchanged. (b) A rewrite carrying only stale lines → `deliver=0 stale=<n>`, `total` unchanged. (c) Two fresh
  lines merged into one wake → `wake n=2`, `total` +2.

### 5.2 The flip package `skills/teamsmith/tests/flip-p25.sh`

Same three-tree shape as `flip-m43.sh`: **red** = the pre-change extension extracted from `TEAM_FLIP_BASE`
(default `git merge-base HEAD main`), **green** = this worktree, **mutant** = green plus one deliberate break:

- mutant A: restore the `Buffer.byteLength(decoded)` advance → S18 must fail (baseline = size + 1);
- mutant B: A + the clamp/repeat guard removed → S18 must fail with a repeated `spool shrink` (the loop itself);
- mutant C: `flush` clamps on every shrink (no rescan) → S19b must fail (a real rewrite is never read again).

Exit 0 only when red reproduces, green is fully green, and every mutant fails its case. Fixture isolation follows
the harness (its own scratch repo, `TEAM_*`/`TMUX` cleared, real-state reverse guard).

### 5.3 Smoke pins

Section 12b-pi gains `assert_has` lines for the S18–S21 PASS messages (the same style as its M43/M46 pins), so the
gate fails if the harness cases are removed or renamed. The full gate is
`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`; `TEAM_SMOKE_FAST=1` is the
during-development subset.

### 5.4 Assertions that must stay green

S1–S17, in particular S5 (baseline silences history), S6 (trim does not replay the tail), S11–S13 (M43: dedup
across restarts, bounded rescan, honest `total`) and S14–S17 (M46); `flip-m43.sh` and `flip-m46.sh`; smoke 12b-pi
and 12b-pi2. No existing assertion text needs editing: the rescan line keeps its leading
`lines=/dup=/skipped=/deliver=` run (D6).

### 5.5 Coverage map

| Requirement | Batch | Fixture |
|---|---|---|
| R1 offset advances by bytes, ≤ size | B1 | S18 |
| R2 shrink needs evidence, recovery converges | B2 | S19 |
| R3 stale lines never wake | B3 | S20 |
| R4 the ledger separates traffic from recovery | B4 | S21 |
| docs + gates | B4/B5 | full smoke, flip-p25 |

## 6. Risks, trade-offs, rejected alternatives

- **The clamp can miss a same-head, small rewrite.** Named and bounded (D3); the ledger records every clamp; a real
  append afterwards is read normally. The alternative (rescan on every regression) is the incident.
- **The stale horizon can silence a legitimately delayed wake.** 15 minutes is the brief's default; the durable
  inbox and `team digest` remain the door, the count is visible in the ledger, and the key is configurable.
- **Rejected: fixing only the writer's `cut`.** The reader must be byte-safe for any content in that file
  (the spool is a plain file under `state/`), and the writer is PM-owned (`scripts/**`), so a writer-side fix alone
  would leave the invariant unenforced.
- **Rejected: clamping to the last line boundary.** Walks the offset backwards over pre-baseline content (D3).
- **Rejected: backoff or a rescan counter as the loop fix.** The protocol (one rescan per evidence) is stronger
  and costs no state.
- **Rejected: dropping `.seen`.** Dedup across restarts is what makes a genuine rewrite silent (M43 S13).
- **No new dependency**; the head fingerprint is an inline FNV-1a or `node:crypto` — an implementation choice, not
  a spec term.

## 7. Open questions

1. **PM-owned follow-up (not blocking):** `outbox.sh:1017`'s byte clip puts U+FFFD into spool previews (cosmetic in
   wake texts; the durable inbox has the full text). Recommended: clip on a character boundary. It is outside this
   change's boundaries and is not needed for correctness after D2.
2. **Evidence boundary:** at 06:42:39 `.seen` held only 13 lines although the previous session had logged 118
   deliveries; the memory cannot be reconstructed from the logs. It does not affect the invariants (`dup=0` proves
   the 66 lines had never been delivered), but it is named here rather than silently explained.
