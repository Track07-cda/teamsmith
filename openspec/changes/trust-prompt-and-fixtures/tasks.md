# Tasks: `trust-prompt-and-fixtures`

Planning only — nothing in this file is executed by the propose task (P57). **One apply brief** (three verifiable
batches, landed in order) plus **one independent verify brief** (a different agent). The change touches two
capabilities: `verification` (a fixture's input-box judgement distinguishes an unexpected overlay, **ADDED**) and
`init-skill` (the project-local install names Pi's trust consequence, **ADDED**).

Coverage map (requirement → items): **verification#A fixture's input-box judgement distinguishes an unexpected
overlay** → 1.1–1.6, 3.1–3.4; **init-skill#The project-local install names Pi's trust consequence** → 2.1–2.3,
3.1–3.4. Every item names the capability it moves; no item is an orphan.

Batches: **B1** — the fixture's judgement and the overlay rule (1.x), observable in FAST on the stored frame and
on a real pane on the host; **B2** — the install line and the documentation (2.x); **B3** — the gates and the
evidence (3.x). B1 and B2 are independent; B3 needs both.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s;
`skills/teamsmith/scripts/lib/cmd-init.sh` is PM-owned and needs the brief's explicit grant; so do
`skills/teamsmith-init/SKILL.md` and `skills/teamsmith-init/references/bootstrap.md` (not listed in
`OWNERSHIP.md`, so they are PM-owned by default). `skills/teamsmith/scripts/**` outside `cmd-init.sh`,
`outbox.sh`'s verdict semantics, and `openspec/**` (the phase owner's) are **not** touched.

Fixture notes: the judgement mode must run without tmux or Pi (frame in, verdict out, same shared judgement the
real-pane path uses — the M45 `12b-h0b` precedent); the overlay predicate must key on stable prompt markers
(`Trust project folder?`, `Do not trust`), not on row numbers, because the stored frame is 0.87.0 and the pinned
image is 0.86.0; the real-pane fixture keeps its private tmux socket, its `env -u TMUX -u TMUX_PANE` isolation,
its `BASHPID`-guarded cleanup and its trust-store non-write; no interactive trust answer is ever given by hand.

Documented residual (design §5, not fixed here): the delivery guard's `UNKNOWN → deliver as today` path can type
text into a modal (no `Enter` follows); items below must **not** widen this change into `delivery-guard`.

## 1. B1 — the fixture's judgement (`verification` ADDED)

- [ ] 1.1 Store the real capture `skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt` (raw
  `capture-pane -p` output, no comments) and a row in that directory's README naming its source (Pi 0.87.0,
  private tmux socket, 120×30 pane, `--no-session`, a git repo with `.pi/skills/teamsmith` and no saved trust
  decision), its cursor row and the reproduction command from design §1. Verify: the file is byte-identical to a
  fresh capture through the design §1 command, and the README row names file, source and cursor.
- [ ] 1.2 `tests/pm-box-real.sh`: the frame judgement mode — `--frame <file> --cursor <row>` runs the shared
  frame-level judgement with no tmux and no Pi and prints `overlay=trust-prompt` when the overlay predicate
  fires, else the input-box verdict (`idle-read=EMPTY` / `idle-read=NOT-EMPTY`); exit 0 for overlay/EMPTY,
  non-zero for NOT-EMPTY. `M24_OVERLAY_DETECT=0` disables the predicate (the flip control). Verify:
  `bash skills/teamsmith/tests/pm-box-real.sh --frame skills/teamsmith/tests/frames/pi-0.87.0-project-trust-prompt.txt --cursor <row>`
  → rc=0 with `overlay=trust-prompt`; the same command with `M24_OVERLAY_DETECT=0` → rc≠0 with
  `idle-read=NOT-EMPTY`.
- [ ] 1.3 `tests/pm-box-real.sh`: the readiness wait releases only when the judgement locates the input box and
  its text is empty (two consecutive quiescent reads, bounded by the existing 60 s ceiling), not on the first
  full-rule row; on timeout with an overlay present it prints `overlay=…` plus the last frame and exits non-zero
  **before** any payload step. Verify: the overlay mode of 1.4 shows no `deliver_text_lines=` and no
  `RETRACT=` in its output; a synthetic pane with the prompt's rule rows but no locatable box never releases the
  wait.
- [ ] 1.4 `tests/pm-box-real.sh`: the real pane — start Pi with the single-run trust override
  (`--approve`) so the provisioned project (`.pi/skills/` installed by the fixture's own `team init`) reaches the
  empty box; add the documented overlay mode (`--expect-overlay`) that starts Pi **without** the override,
  expects the prompt, and exits 0 only after printing `overlay=trust-prompt` with no payload step. Verify:
  `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3` → rc=0, `M45 idle-read=EMPTY ok`, `RETRACT=ok`;
  `bash skills/teamsmith/tests/pm-box-real.sh --idle-secs 3 --expect-overlay` → rc=0, `overlay=trust-prompt`, no
  `deliver_text_lines=`; `~/.pi/agent/trust.json`'s mtime is unchanged across both runs.
- [ ] 1.5 `tests/smoke.sh`: a new FAST section beside `12b-h0b` that runs 1.2's two judgements against the
  stored frame and asserts the flip (predicate on → `overlay=trust-prompt` and exit 0; predicate off →
  `idle-read=NOT-EMPTY` and non-zero exit), printing both tails. Verify:
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` exits 0 and the section's lines name the
  frame; injecting `M24_OVERLAY_DETECT=0` into the section's invocation in a scratch copy turns it red.
- [ ] 1.6 `tests/smoke.sh` §31b2: unchanged in shape — it keeps running `pm-box-real.sh` through
  `container-tmux.sh --with-pi`, and the fixture's tokens it greps (`RETRACT=ok`, `verdict=EMPTY`) survive the
  readiness/override changes. Verify: the full gate (3.2) is green, including the §31b2 assertions
  (`M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立`, `… 空闲空框被判 EMPTY`).

## 2. B2 — the install line and its docs (`init-skill` ADDED)

- [ ] 2.1 `cmd-init.sh` `team_init_install_skills`: print exactly one line when the step concludes with the
  project-local skills present (fresh install, `copy`, or `skip` on a rerun) and nothing with `--no-skills`; the
  line names `.pi/skills/`, `pi --approve`, `/trust` and `team init --no-skills`, and the step's exit status is
  unchanged in every case. Verify: in a fresh fixture repo, `team init --session … --agents "dev" --vcs local
  --gates true` exits 0 and its output carries the line; the same with `--no-skills` exits 0 with no such line
  and no `.pi/skills/`; a rerun (`skip`) carries it again.
- [ ] 2.2 `tests/install-shape.sh`: assertions for the line in the fresh install, the rerun/`skip`, and
  `team bootstrap --no-pulse --agents "dev"` on a repo whose config already exists, plus the absent case with
  `--no-skills`; the existing install-shape assertions stay untouched. Verify: `bash
  skills/teamsmith/tests/install-shape.sh` stays green and its log names the four new cases; deleting the print
  from a scratch tree's `cmd-init.sh` turns exactly those assertions red.
- [ ] 2.3 Documentation: `skills/teamsmith-init/SKILL.md`'s install beat and
  `skills/teamsmith-init/references/bootstrap.md`'s project-skills row state the fact — the trigger
  (`.pi/skills/`), the prompt, and the three answers. Verify: `grep -n` finds `.pi/skills/`, `pi --approve` and
  `/trust` in both files, and a scratch copy with the note deleted fails the same search.

## 3. B3 — gates and evidence

- [ ] 3.1 FAST gate: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` exits 0 (includes the
  new section and `install-shape.sh`), tail recorded.
- [ ] 3.2 Full gate: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash
  skills/teamsmith/tests/smoke.sh </dev/null` exits 0, §31b2 included (`--keep` for the scene if it does not).
- [ ] 3.3 Real-pane evidence on the host: the 1.4 runs' output tails (`idle-read=EMPTY ok` / `RETRACT=ok`; and
  `overlay=trust-prompt` with no payload step), plus the trust store's unchanged mtime.
- [ ] 3.4 The report (`docs/team/reports/<ID>-<agent>.md`, the apply brief's id) carries every acceptance tail,
  the stored frame's provenance, the flip tails (predicate on/off), the four install-line cases, and the list of
  paths the diff touched. Nothing in the report claims a run that is not pasted.
