# trust-prompt-and-fixtures · design

## 1. The measured scene

**Trigger.** `skills/teamsmith/scripts/lib/cmd-init.sh` installs `.pi/skills/teamsmith` (+ `teamsmith-init`) in
the project (`team init`, and `team bootstrap`'s upgrade path through the same function). Pi's
`TRUST_REQUIRING_PROJECT_CONFIG_RESOURCES` contains `"skills"` — re-verified on the host's Pi 0.87.0
(`dist/core/trust-manager.js`), the PM verified the same list in the pinned image's 0.86.0 — and Pi asks before
loading a project it has no saved decision for (`README.md` §Project Trust). So any project after `team init`
shows, on the first interactive `pi`, the prompt:

```
 Trust project folder?
 <cwd>

 This allows pi to load .pi settings and resources, install missing project packages, and execute project extensions.

 → Trust
   Trust parent folder (<parent>)
   Trust (this session only)
   Do not trust
   Do not trust (this session only)

 ↑↓ navigate  enter select  escape/ctrl+c cancel
```

**Frame.** Captured on the host (Pi 0.87.0, private tmux socket, 120×30 pane, `--no-session`, a git repo with
`.pi/skills/teamsmith` and no saved trust decision): a full-width rule row at pane row 1, the question at row 3,
the cwd at row 4, the options at rows 8–12, the key hint at row 14, and the prompt's bottom rule at row 16;
`cursor_y` reports 15 (0-based), i.e. the prompt's bottom rule. Reproduction:

```sh
mkdir -p /tmp/trust-repro/{sock,sess} /tmp/trust-repro/proj/.pi/skills/teamsmith
cd /tmp/trust-repro/proj && git init -q -b main && printf '# x\n' > README.md && git add -A && git commit -qm init
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux new-session -d -s trustrepro -x 120 -y 30 \
  -c /tmp/trust-repro/proj "HOME=$HOME pi --no-session --session-dir /tmp/trust-repro/sess"
sleep 6
env -u TMUX -u TMUX_PANE TMUX_TMPDIR=/tmp/trust-repro/sock tmux capture-pane -p -t trustrepro
```

**Why the fixture misreads it.** The fixture's readiness wait accepts any full-rule row (`grep -E '^(─)+$'`), and
the prompt has two. Its idle judgement is binary: `verdict == EMPTY` → ok, anything else → `idle-read=NOT-EMPTY`
(i.e. "a draft"). On the measured frame the guard locates **no box** below the cursor (the prompt's rules are
above it) → `UNKNOWN`; with the cursor on an option row it pairs the prompt's own rules (top 1 / bottom 16) and
reads the question and options as box content → `BUSY`. Both are non-`EMPTY`, both print `NOT-EMPTY`, and the
fixture then pastes its payload (no `Enter`; the guard cannot locate the box, so the retraction path is a no-op)
before exiting 1. That is P54's F2 and the §31b2 red.

**Green side, measured.** A `/tmp` copy of the fixture with one line changed (`pi --approve --no-session …`) ran
on the host: rc=0, `M45 idle-read=EMPTY ok`, paste → `BUSY`, `RETRACT=ok`, isolation self-check green. Pi's
`resolveProjectTrusted` returns `--approve`'s override before the prompt/store path, and
`~/.pi/agent/trust.json`'s mtime was unchanged across the run (2026-09-14 before and after). `--approve` has
existed since the trust feature (≪ 0.86) and is the documented "trust project-local files for this run" flag.

## 2. Fixture side: which strategy

| | A · `pi --approve` (recommended) | B · `team init --no-skills` | C · drive the prompt | 
|---|---|---|---|
| `.pi/skills/` installed in the fixture project | **yes** | no | yes |
| Needs an interactive trust decision | no | no | yes (keys) |
| Writes Pi's trust store | no | no | no (only if the session-only option is hit) |
| Deterministic across hosts | **yes** — the override wins over the developer's own trust store/settings | yes | no — dialog absent when the host already trusts the path |
| Still an end-to-end "init → real pi" run | **yes** | no (install surface only in `install-shape.sh`, which never runs Pi) | yes |
| Coupled to Pi's dialog wording/order | no | no | yes (brittle; order/keys by hand) |
| Risk to the fixture run | if `--approve` disappears, the run fails loudly at startup | none | keys into a live dialog; could cancel it or write a decision |

**Decision: A.** B trades away exactly the shape §31b2 exists for (a real Pi opened in a project `team init`
provisioned) and `install-shape.sh` cannot recover it — it never starts Pi. C's determinism is an illusion (the
prompt's presence depends on the developer's own trust store) and it puts keys into a modal, which is the class of
action `references/protocol.md` keeps out of fixtures. A keeps `.pi/skills/` installed, keeps one copy of the
project contract, and is a one-line fixture change.

**Rejected, not forgotten:** the fixture is not skipping §31b2; it keeps running real Pi in the provisioned
project.

## 3. Fixture side: the judgement fix (the general rule)

The brief's general rule — *an unexpected whole-screen popup is not a "non-empty input box"* — is implemented
where the judgement lives, not in the delivery guard:

1. **Readiness** releases only when the judgement locates the real input box and its text is empty (two
   consecutive quiescent reads, the existing bounded wait), not on a full-rule row. The prompt's frame fails this
   by construction.
2. **Classification.** When an overlay is present, the fixture prints `overlay=trust-prompt`, keeps the last
   frame, exits non-zero, and **stops before the payload steps** (no paste, no retraction keys). `idle-read=
   NOT-EMPTY` is reserved for a pane whose located box holds text.
3. **Falsifiability.** A real frame is stored under `skills/teamsmith/tests/frames/` (the existing convention:
   raw capture, provenance and cursor row in the README) and a `--frame <file> --cursor <row>` judgement mode
   runs it without tmux, so the FAST gate exercises the rule. `M24_OVERLAY_DETECT=0` disables the predicate and
   must bring back the old verdict (`idle-read=NOT-EMPTY`, exit 1) — the red side.
4. **The real overlay is still reachable on demand**: a documented overlay mode starts Pi without the override,
   expects the prompt, and exits 0 only after naming it with no payload step — so the legibility promise is
   exercised on a real pane, not only on the stored frame.

Why not teach `outbox.sh` the overlay? Because this change's promise is about what the *fixture* concludes, and
the guard's own verdict for a modal is conservative for delivery (no `Enter` is pressed when the box cannot be
re-read). The guard's `UNKNOWN → deliver as today` path can type text into a modal — recorded as **Residual 1**
below. Touching it would widen this change into `delivery-guard` and change delivery behaviour for every target,
which the brief does not ask for.

## 4. Install side: the hint, and why ADDED

**Decision: print the hint.** The install is the only moment teamsmith knows the consequence is coming, and a
modal trust dialog plus a security decision is a poor surprise. Docs only would leave the person who just ran
`team init` and immediately typed `pi` to meet it unannounced.

- Line printed by `team_init_install_skills` when the step leaves the skills present (fresh install, `copy`, or
  `skip` on a rerun) and never with `--no-skills`; it names the trigger (`.pi/skills/`) and the three answers
  (`pi --approve`, `/trust`, `team init --no-skills`). One implementation → `team init` and `team bootstrap`
  (both call points) say the same thing.
- Prose in the `teamsmith-init` skill's install beat and in `references/bootstrap.md`'s project-skills row.

**ADDED, not MODIFIED.** The base's `init-skill` requirement "Initialization guidance lives in a dedicated
teamsmith-init skill" is already MODIFIED by two unarchived changes (`npm-cli-and-project-init`,
`roster-writer-and-route-truth`), and D40 records what happens when deltas on one requirement archive out of
order. This change's obligation is a new one (the trust consequence), so it becomes its own requirement and
stays archive-order independent: whether `npm-cli-and-project-init` archives before or after, neither delta
needs rewriting. The same applies on the `verification` side (`change-centric-discipline`,
`dispatch-verify-seat-guard`, `ledger-and-gate-noise`, `test-tmp-hygiene` and `pty-fixture-load-premise` all
carry unarchived `verification` deltas; this one is another distinct ADDED).

## 5. Residuals (recorded, not fixed here)

1. **Delivery into a modal.** The guard's unlocatable-box verdict (`UNKNOWN`) is "deliver as today with one
   warning", so an automated sender can type text into a trust prompt. No `Enter` follows (the post-paste
   re-check needs a locatable box), so the prompt is not answered; if this is ever seen to bite, it is a
   `delivery-guard` change with its own red side.
2. **Pi's wording is Pi's.** `overlay=trust-prompt` keys on the measured prompt shape/wording. If a later Pi
   renames it, the predicate stops firing — but the readiness gate still refuses to release and fails legibly
   (named overlay absent, no box located, frame printed), so the failure mode stays visible rather than becoming
   a false draft.
3. **`--approve` is the fixture's dependency.** The pinned container image carries the flag; if it ever
   disappears, the fixture fails at Pi's argument parsing, which is loud.
4. **Other install surfaces.** `install-shape.sh` keeps its install-surface assertions unchanged; the
   new hint assertions go beside them, not over them.

## 6. What apply must not do

- Not skip, weaken or bypass §31b2, and not remove `.pi/skills/` from the fixture project.
- Not touch `outbox.sh`'s verdict semantics (Residual 1), Pi's trust behaviour, or `install-shape.sh`'s existing
  assertions.
- Not write to a developer's real `~/.pi/agent/trust.json` (no interactive answers, no `--trust` saves) and not
  read credential files.
- Not turn the gate into a 30-minute run: the frame-level checks run in FAST, the real-pane overlay mode and
  §31b2 stay in the full gate.
