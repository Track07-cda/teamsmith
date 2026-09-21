# Tasks: `tmux-gate-grant-redesign`

Planning only — nothing here is executed by the propose task. The implementation becomes **two apply briefs**:
**A1 = B1** (the shim's verdict and the grant's removal) and **A2 = B2** (the fixtures, the lint and the flips);
**B3** is the PM's ledger work. A1 lands first: A2's assertions read the new action vocabulary.

Coverage map (requirement → items): R1 object-based verdict → 1.1–1.3, 2.1, 2.5; R2 log, no window grant, legacy
tombstone → 1.3–1.5, 2.2; R3 fixture discipline → 2.3–2.5. The PM's B3 items carry no requirement of their own: the
transfer (3.1) keeps the spec set free of two parallel statements, and 3.2/3.3 are the archive gates.

Path grants an apply brief must state (OWNERSHIP — `scripts/**` and `references/**` are PM-owned by default):

- **A1**: `skills/teamsmith/scripts/shim/tmux`, `skills/teamsmith/scripts/team`, `skills/teamsmith/scripts/lib/common.sh`,
  and (item 1.5) `skills/teamsmith/scripts/lib/cmd-config.sh`, `skills/teamsmith/scripts/lib/cmd-project.sh`,
  `skills/teamsmith/references/config.md`, `skills/teamsmith/references/troubleshooting.md`,
  `skills/teamsmith/CHANGELOG.md`.
- **A2**: `skills/teamsmith/tests/**` (agent:dev) plus `skills/teamsmith/tests/container-tmux.sh`.
- **Not granted to either**: the CLI call sites `cmd-agents.sh`, `cmd-review.sh`, `cmd-watch.sh` (D5 says they need
  no change — a brief that thinks otherwise stops and writes `BLOCKED:`), `openspec/specs/**`, `openspec/config.yaml`,
  `docs/team/**`, `extension/**`, `package.json`.
- Fixture rules for A2: every fixture clears inherited team identity and tmux identity before it runs; the
  default-socket probes pin the argv-recording stub; no host fixture starts a server from a process carrying
  `TEAM_ALLOW_DESTRUCTIVE_TMUX`.

## 1. B1 — the verdict is the target, the escape is an argv token (R1, R2)

- [ ] 1.1 `scripts/shim/tmux`: replace the environment-keyed three-state verdict (L159–163) with the object-based
  one. Parse the effective `-t` (last wins, `-t x` and `-tx`, on a copy) for `kill-session`/`kill-window`/
  `kill-pane`; refuse `kill-server` and `kill-session -a` on the shared default socket unconditionally; accept only
  a non-empty literal session component equal to `TEAM_SESSION` with the M40 binding (`TEAM_ROOT`/`TEAM_MAIN_ROOT`
  cwd-or-ancestor); refuse every unprovable shape; keep the socket block (L89–147), the destructive set (L149–157)
  and the private-socket pass byte-for-byte. New refusal text names the reason class, the socket, the token and the
  private-socket route. Verify (own evidence): a stub-pinned probe matrix — own target → 0/`allowed-owned`;
  `otherproj:pm`, `%1`, `@1`, `:dev`, `dev`, `""`, no `-t` → 64; `kill-server`, `kill-ser`, `kill-session -a` →
  64; unbound/empty `TEAM_SESSION` → 64; private socket → 0/`pass`; fake isolation → 64 with the default socket
  recorded. Paste the matrix.
- [ ] 1.2 `scripts/shim/tmux`: recognize `--teamsmith-allow-destructive` in the global-option position, remove
  every occurrence on its copy, log `act=explicit-flag` and exec the filtered argv; tokens after the subcommand are
  data. Verify: a stub-pinned probe shows exit 0, `act=explicit-flag`, the stub's argv without the token, the
  token in no environment, and a `send-keys` payload containing the token reaching the stub unchanged.
- [ ] 1.3 `scripts/team`: delete line 19 (the export) and its comment; nothing else in the CLI changes argv.
  Verify: `grep -rn 'TEAM_ALLOW_DESTRUCTIVE_TMUX' skills/teamsmith/scripts/` → no read and no export (the schema
  tombstone text of 1.5 is the only remaining mention);
  `grep -rn 'act=override' skills/teamsmith/` → nothing.
- [ ] 1.4 CLI call-site audit (no change expected): re-read the sites named in design D5
  (`cmd-agents.sh:779/812/1069`, `cmd-review.sh:883`, `cmd-watch.sh:1361/1376/1380`, `common.sh:1325–1332`) and
  confirm each target is `$TEAM_SESSION:<named object>`; run `team teardown --agent <a>` and `team review`'s cleanup
  in a gated private session and show the ledger lines are `act=allowed-owned` (never `explicit-flag`). If a site
  turns out not to target its own session, stop and write `BLOCKED:`.
- [ ] 1.5 Retire the key visibly (R2): `cmd-config.sh:65` keeps the row with the retirement description;
  `cmd-project.sh` (doctor) adds the read-only `tmux show-environment -g TEAM_ALLOW_DESTRUCTIVE_TMUX` residue line
  with the restart remedy, skipped when tmux is absent; `references/config.md:380`,
  `references/troubleshooting.md:582–600` and `CHANGELOG.md:21` are rewritten to the new model with "override"
  removed from the gate's vocabulary. Verify: `team config set TEAM_ALLOW_DESTRUCTIVE_TMUX 1 --dry-run` refuses
  (exit 5) and the file is unchanged; `team config list` still lists the key; the doctor line appears with the
  residue and not without it; `grep -rn 'override' references/troubleshooting.md` shows no gate override.

## 2. B2 — fixtures, lint and flips (R1, R3)

- [ ] 2.1 `tests/smoke.sh` §31c (L10012–10366) rewritten to R1's probes: the own/foreign/unprovable/server/
  widening/binding/inherited-environment/token/private/fake-isolation/read-only matrix, with the stub pinned for
  every default-socket probe and the default-server liveness bracket kept. Keep the section's sanitized-probe
  helper; the probes that execute a real kill stay private-socket-only. Verify: the section runs green under
  `TEAM_SMOKE_FAST=1` and (once) full smoke, with a helper-level proof that the section's `TEAM_TMUX_REAL` is the
  stub on the default-socket probes (print the resolved value per probe class).
- [ ] 2.2 `tests/smoke.sh`: extend the window probe (currently L10298–10330) to assert the worker window
  environment carries `TEAM_TMUX_CALLS_LOG`/`TEAM_TMUX_REAL` and neither `TEAM_ALLOW_DESTRUCTIVE_TMUX` nor any
  other grant, with `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` inherited by the dispatching shell; add one assertion that the
  CLI's own destructive calls in that window are logged `act=allowed-owned`. Verify: the probe's log and env file
  tails (it is a real-window item — mark it as such, never the only evidence for R2).
- [ ] 2.3 `tests/tmux-lint.pl`: accept the token as a global option while scanning so a flagged mutating call is
  still classified; keep A–D and the absolute-path rule unchanged; new selftest fixtures for
  `tmux --teamsmith-allow-destructive kill-server` (red), the same with `-L <private>` (clean), and the existing
  `/usr/bin/tmux -L <private> kill-server` (red). Verify: `perl skills/teamsmith/tests/tmux-lint.pl --selftest` and
  a repo scan, both with tails.
- [ ] 2.4 `tests/container-tmux.sh`: the leak-shape fixture of R3's third scenario — inside the container, a server
  started with `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` in its environment; from its pane `tmux kill-server` → exit 64 /
  `act=refused`, then `tmux --teamsmith-allow-destructive kill-server` → exit 0 / `act=explicit-flag` and the
  container's server gone; host fingerprint byte-identical; no runtime → exit 77 with the SKIP reason. Verify: the
  fixture's tail and `--selftest` still exit 0.
- [ ] 2.5 The four flips from the design's evidence map (each in a `/tmp` copy, restore → green): (a) restore the
  `TEAM_ALLOW_DESTRUCTIVE_TMUX` read → the inherited-environment probes go red; (b) accept every target → the
  foreign-target probes execute the stub; (c) drop the M40 binding → the unbound-identity probe allows;
  (d) keep the token in argv → the stub sees it. Verify: every red/green pair in the apply report, with the exact
  assertion names.

## 3. B3 — the ledger and the archive (PM)

- [ ] 3.1 **Transfer the pending gate rows** (design D1, a spec-backfill action): remove the two gate requirements
  from `openspec/changes/spec-backfill-2026-09/specs/boundary/spec.md` (L5–66, L68–104), keep its container
  requirement (L106) and its other four delta files, and record the transfer in its design/evidence map with a
  pointer to this change. Verify: the file's requirement list holds exactly one requirement; its evidence map's
  gate rows point at this change; `openspec validate --all --strict` stays green.
- [ ] 3.2 Trial archive both changes on a scratch copy in dependency order and paste the output:
  `cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y spec-backfill-2026-09 && openspec archive -y
  tmux-gate-grant-redesign)`. A MODIFIED/ADDED collision or a missing base requirement surfaces here.
- [ ] 3.3 Archive for real only after the independent verify record exists, the protected-branch gate is green, and
  the user confirms; then `team change status tmux-gate-grant-redesign` must exit 0.

> **Ordering**: 1.x → 2.1–2.4 → 2.5 → independent verify → 3.1 → 3.2 → archive (3.3).
> **Not in this change**: the container requirement (stays in `spec-backfill-2026-09`), the guarded subcommand set,
> the socket table, the launch prefix's semantics, and any change to the CLI's targets (D5).
