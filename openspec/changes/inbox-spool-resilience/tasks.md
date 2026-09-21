# Tasks: `inbox-spool-resilience`

Five apply batches, dispatched and verified one by one, in this order: **B1** the byte-true reader (R1), **B2** the
evidence-based shrink policy and its convergence (R2), **B3** the stale gate (R3), **B4** the ledger contract and
the documents (R4), **B5** the flip package, the smoke pins and the gates. B2/B3/B4 all edit `readNewLines()`/
`flush()`/`rescan()`, so their order is not cosmetic; each batch is green on its own and its harness cases fail
without it (the flip is named per batch).

Coverage map (requirement → items): R1 → 1.1–1.4; R2 → 2.1–2.5; R3 → 3.1–3.4; R4 → 4.1–4.4; the documents → 4.5;
every requirement is also exercised by the final gate item 5.4 and by the flip package 5.2.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/extension/**` is **PM-owned** and must be
granted explicitly; `skills/teamsmith/tests/**` belongs to `agent:dev`; `skills/teamsmith/references/**` is
**PM-owned** and must be granted explicitly for B4; `openspec/changes/inbox-spool-resilience/**` belongs to the
phase's owner; `docs/team/reports/<ID>-<agent>.md` is the worker's own file. `scripts/**` is **not** granted — the
writer-side byte clip is a PM-owned follow-up (design §7.1), and `openspec/specs/**`, `docs/team/**` and the ledger
stay PM-owned.

Fixture note: every batch is verified through `skills/teamsmith/tests/team-inbox-watch-harness.mjs` (its fake Pi
host, its own scratch repository, `TEAM_*`/`TMUX` cleared, and the real-state reverse guard) — no new harness. The
harness gains `appendWakeRaw()` (append a `Buffer` verbatim) for the byte-clipped line; `TEAM_IW_KEEP=1` keeps a
failing fixture.

## 1. B1 — the reader advances by the bytes it read (R1)

- [x] 1.1 `extension/team-inbox-watch.ts`: rewrite `readNewLines()` (line 351) — honour `readSync`'s return value,
  parse lines from `buf.subarray(0, bytesRead)` (no string round trip for boundaries), advance by the byte position
  of the last `0x0a` plus one, and keep the existing `shrank` semantics (`size < offset`, or the file disappeared
  while `offset > 0`). Decode only the line text. Verify: `node`/`bun` runs the harness; S5/S6/S11–S13 stay green.
- [x] 1.2 `extension/team-inbox-watch.ts`: when a read starts inside a line (only reachable after B2's clamp),
  skip to the first `\n` without delivering and write one `offset resync skipped=<bytes>` ledger line. Verify: 1.4's
  fixture plus the clamp of S19a in B2.
- [x] 1.3 Harness case **S18**: append a byte-clipped line (`appendWakeRaw`, e.g. a preview containing `xy` +
  three-byte characters whose 700-byte cut lands mid-character) ending in `\n`, start the session, wait three poll
  ticks, then append a complete line; assert `started … baseline=` equals `statSync().size`, no `spool shrink` line,
  exactly one wake, the appended line's preview byte-complete, `total=` +1. Verify: the harness's S18 PASS line.
- [x] 1.4 Flip: in a scratch copy, restore the `Buffer.byteLength(text.slice(0, end + 1), 'utf8')` advance → S18
  fails with `baseline = size + 1` and a `spool shrink` per tick; restore → green. Verify: both tails in the report.

## 2. B2 — a shrink needs evidence, and recovery converges (R2)

- [x] 2.1 `extension/team-inbox-watch.ts`: record the head fingerprint (first `min(256, size)` bytes, inline FNV-1a
  or `node:crypto`) whenever the offset is established (baseline, successful advance, rescan).
- [x] 2.2 `extension/team-inbox-watch.ts`: the regression branch of `flush()` (line 558) implements design §4/D3:
  unchanged head and `offset - size ≤ TEAM_INBOX_WATCH_CLAMP_BYTES` (default 64, `envNum` range 1…1 MiB) → set
  `offset = size` and write one `offset clamp from=… to=… head=same` line; changed head or a larger regression →
  the existing `spool shrink` + bounded rescan path. Clamping never moves the offset backwards; the reader's
  mid-line rule (1.2) covers the partial line. Verify: 2.4.
- [x] 2.3 `extension/team-inbox-watch.ts`: convergence — remember the last shrink episode's `(size, head)`; an
  identical observation writes one `shrink repeat size=… head=… action=clamp` line and clamps instead of rescanning;
  a normal advance clears the episode. Verify: 2.4's case (c) and the mutant of 2.5.
- [x] 2.4 Harness case **S19**: (a) remove the file's last byte with the head unchanged → exactly one
  `offset clamp`, no `spool shrink`/`rescan`/wake, a later append wakes once; (b) replace the file with shorter
  content whose head differs → one `spool shrink` + one `rescan …`, the next tick adds nothing; (c) repeat the same
  `(size, head)` → `shrink repeat`, no second `rescan`. Verify: the harness's S19 PASS lines.
- [x] 2.5 Flips: (a) make the regression branch always rescan → S19a fails; (b) make it always clamp → S19b fails;
  (c) remove the repeat guard and restore the old advance → S18 fails with a repeating `spool shrink` (the loop of
  2026-09-20). Restore each → green. Verify: both tails per mutation.

## 3. B3 — stale lines never wake (R3)

- [x] 3.1 `extension/team-inbox-watch.ts`: `TEAM_INBOX_WATCH_STALE_SEC` (default 900, `envNum` minimum 1) and a
  classifier over field 1 of a spool line: `fresh` (age ≤ horizon), `stale` (older), `unparsable` (the field is not
  an integer). Unparsable lines are treated as fresh for delivery. Verify: 3.4.
- [x] 3.2 `extension/team-inbox-watch.ts`: `deliverNormal()` (line 533) and `rescan()` (line 544) drop `stale` lines
  before `wake()`; the spool bytes are left alone. Verify: 3.4's cases (a) and (b).
- [x] 3.3 `extension/team-inbox-watch.ts`: the rescan line gains `stale=<n>` and `unparsable=<n>` **after** the
  existing `lines=/dup=/skipped=/deliver=` run (design §4/D6 — M43's assertions stay byte-identical); a wake that
  carried a fresh line is unchanged in shape. Verify: 3.4 plus the M43 cases of 5.4.
- [x] 3.4 Harness case **S20**: (a) a spool line timestamped one hour ago, absent from `.seen`, with its durable
  inbox line present → the rescan line reads `stale=1`, no wake, `total=` unchanged, the inbox line still present,
  the spool line still in the file; (b) a fresh line afterwards → one wake naming only it, `total=` +1; (c) a line
  whose timestamp is `zzz` → delivered and counted `unparsable=1`. Verify: the harness's S20 PASS lines.
- [x] 3.5 Flip: make the classifier always return `fresh` → S20a fails (a stale line wakes); restore → green.
  Verify: both tails.

## 4. B4 — the ledger contract and the documents (R4)

- [x] 4.1 `extension/team-inbox-watch.ts`: the ledger's field contract as design §4/D6 — `wake n=` counts only the
  lines the wake carries, `total=` counts only woken lines, the rescan prefix keeps
  `lines=/dup=/skipped=/deliver=`, and `offset clamp` / `shrink repeat` / `offset resync` are one line per action.
  Verify: 4.4.
- [x] 4.2 Harness case **S21**: (a) rewrite with only delivered lines → `deliver=0` and a non-zero `dup=`, `total=`
  unchanged, no `wake` line; (b) rewrite with only stale lines → `deliver=0 stale=<n>`, `total=` unchanged;
  (c) append two fresh lines → one wake with `n=2` and `total=` +2. Verify: the harness's S21 PASS lines.
- [x] 4.3 Regression pass: run `bash skills/teamsmith/tests/flip-m43.sh` and `flip-m46.sh`; S11–S17 and the smoke
  12b-pi/12b-pi2 assertions must be green with no test-text edits. Verify: both tails.
- [x] 4.4 `references/agent-adapters.md` (§4a.1) and `references/troubleshooting.md` (§19): document the new
  invariants — byte-true offsets, the clamp/fingerprint rule and its named trade-off, the stale horizon and where a
  stale line stays readable, and the ledger fields (including that a repeated `spool shrink` with `deliver=0` is a
  defect signal). Verify: `grep -n` for the new key names and the ledger fields returns both files.
  **BLOCKED (dev2, P28)**: `references/**` is PM-owned (`docs/team/OWNERSHIP.md`) and the P28 brief grants only
  `extension/**` (reader), the outbox preview clip and `tests/**`. The prepared text for both sections is in
  `docs/team/reports/P28-dev2.md` (§ "BLOCKED: the two reference sections, prepared for the PM") — the PM applies it,
  or grants the directory and sends the batch back.

## 5. B5 — the flip package, the smoke pins, the gates

- [x] 5.1 `skills/teamsmith/tests/flip-p25.sh`: the three-tree package of design §5.2 (red = `TEAM_FLIP_BASE`,
  default `git merge-base HEAD main`; green = the worktree; mutants A/B/C), exit 0 only when the red tree reproduces
  S18's failure, the green tree is fully green, and each mutant fails its case; isolation and cleanup as in
  `flip-m43.sh`. Verify: the script's tail.
- [x] 5.2 `skills/teamsmith/tests/smoke.sh` section 12b-pi: `assert_has` lines for the S18–S21 PASS messages (same
  style as the M43/M46 pins). Verify: the section's tail and a grep that the four case names are pinned.
- [x] 5.3 The report `docs/team/reports/<ID>-<agent>.md`: the root-cause chain, the flip evidence per requirement
  (red before → green after for B1/B2/B3, mutant evidence for B5), the regression tails of 4.3, and the fact that
  no existing assertion text was edited. Verify: the report is committed on the branch.
- [x] 5.4 The gate of the final branch:
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh` exits 0
  (during development `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` is the same suite with the
  slow sections skipped). Verify: the final run's tail in the report.

## 6. B6 — the sender clips on a character boundary (PM decision, 2026-09-20)

The writer-side trigger of the incident: `outbox.sh`'s `LC_ALL=C cut -c1-700` is byte-based in every locale on
this host, so a preview cut inside a multi-byte character becomes a spool line that is not valid UTF-8.

- [x] 6.1 `scripts/lib/outbox.sh`: replace the preview clip with `team_inbox_watch_clip()` — a byte prefix
  (`head -c`) repaired with `iconv -c -f UTF-8 -t UTF-8` (drops the incomplete trailing sequence, never emits
  U+FFFD), with an ASCII-only fallback when iconv is unavailable. Nothing else on the `say`/`notify`/`draft` paths
  changes. Verify: the smoke 12b-pi ⑩ assertions.
- [x] 6.2 delta `notify-and-inbox`: the ADDED requirement "The sender clips the spool preview on a character
  boundary, under `LC_ALL=C` as well" and its two scenarios. Verify: `openspec validate --all --strict`.
- [x] 6.3 smoke 12b-pi ⑩: a fixture-validity control (the old byte clip really does produce invalid UTF-8 for the
  same payload) plus the assertions (the spool line is valid UTF-8, no U+FFFD, the preview is 698 bytes, the
  durable inbox still holds the full payload). Verify: the section's tail (red: restoring `cut -c` makes it fail).

> **PM 勾选说明（2026-09-21）**：**4.4** 由 PM 本轮补齐（`references/**` 属 PM 所有权）：
> `references/agent-adapters.md` 新增 **§4a.1b**（offset 必须按实际读到字节推进、逐行解码；生产者不得写出半个字符；
> shrink 需要 `(size, head 指纹)` 证据且恢复必须收敛；只有**新鲜行**唤醒，`TEAM_INBOX_WATCH_STALE_SEC=900`；
> 账本区分流量与恢复，`deliver=0` 的重复 `spool shrink` 是**缺陷信号**）与
> `references/troubleshooting.md` §20 的对应段落；`references/config.md` 登记 `TEAM_INBOX_WATCH_STALE_SEC`。
