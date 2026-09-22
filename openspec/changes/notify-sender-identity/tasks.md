# Tasks: `notify-sender-identity`

Planning only — nothing in this file is executed by the propose task (P72). **One apply brief** (batches B1–B4,
landed in order) plus **one independent verify brief** (a different agent, never the implementer). The change
touches one capability, `notify-and-inbox`, with **one ADDED** requirement and **one MODIFIED** one
(`deltas: notify-and-inbox`).

Coverage map (requirement → items): **notify-and-inbox#A manual notification is attributed to its sender, not
its recipient** → 1.1–1.6, 2.1, 3.1–3.2, 4.1–4.3, 5.1–5.3; **notify-and-inbox#A turn-end notification appends
one inbox line and knocks once (MODIFIED)** → 2.1, 3.2, 4.1, 5.1, 5.3. Every item names the capability it
moves; no item is an orphan.

Both briefs carry the change's foreign key: `change: notify-sender-identity`, `deltas: notify-and-inbox`,
`phase: apply` (dev) and `phase: verify` (a different agent).

Batches: **B1** — the CLI resolver and the attribution surfaces (1.x, the ADDED requirement); **B2** — the
extension's derivation (2.x, the MODIFIED requirement); **B3** — the cross-path agreement fixture (3.x);
**B4** — the smoke section and the docs (4.x); **B5** — the flip, the gates and the report (5.x). B1 and B2 are
independent code paths; B3 needs B1 and B2; B4 needs B1–B3; B5 needs B1–B4.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is `agent:dev`'s (the new
section and `flip-p72.sh` need no PM grant); `skills/teamsmith/scripts/lib/cmd-agents.sh`,
`skills/teamsmith/extension/team-notify.ts`, `skills/teamsmith/SKILL.md` and
`skills/teamsmith/references/{agent-adapters,protocol,troubleshooting}.md` need the brief's explicit grant.
`openspec/**` stays with the phase's owner, `docs/team/**` with the PM.

Fixture rules (unchanged): every fixture clears inherited team identity first, keeps its private tmux server
and its `BASHPID`-guarded cleanup, and no call may reach the default tmux server; the gate runs with stdin on
`/dev/null`; injection knobs are honoured only under `TEAM_SMOKE_FIXTURE=1` and printed as ignored otherwise.
The worker fixtures MUST run with `TEAM_AGENT` explicitly unset (the brief's measured shape) and with
`TEAM_ROOT` either unset or pointing at their own worktree.

Documented residuals (design §5, not fixed here): historical inbox lines (no rewrite), `team say` / pulse /
meeting line shapes, the recommended adapter command change (a docs item in 4.2, not a spec promise), and the
`--root` override semantics.

## 1. B1 — the CLI sender resolver and the attribution surfaces (`notify-and-inbox` ADDED)

- [ ] 1.1 `team notify` accepts `--from <name>` as the explicit sender claim: it wins over the runtime
  directory, is recorded verbatim, and a disagreement with the runtime directory is named on stderr. Verify:
  from a fixture worktree, `team notify pm --from dev3 --from-file <f>` writes a line matching
  `[manual] agent:dev3 · `; the same from the main worktree writes `agent:dev3` and names the disagreement.
- [ ] 1.2 The runtime-directory resolution, M40-based: the main worktree → `pm`; the worktree under
  `<main>/<TEAM_WORKTREES_DIR>/` → its directory name, including when the process cwd is a subdirectory of it;
  a roster worktree match is preferred over the basename. Verify: the worker fixture (cwd = the worktree root)
  and the same fixture cwd = `<worktree>/docs` both write `agent:<seat>`; the main-worktree run writes
  `agent:pm`.
- [ ] 1.3 An inherited `TEAM_AGENT` never overrides the runtime directory. Verify: the worker fixture with
  `TEAM_AGENT=pm` exported writes `agent:<seat>` and stderr names the ignored value.
- [ ] 1.4 An unresolved runtime directory (a worktree of the project outside `<main>/<TEAM_WORKTREES_DIR>/`,
  nothing else naming the sender) exits non-zero, writes no inbox line and enqueues no knock, and names
  `--from` in its output. Verify: `git worktree add <tmp>/elsewhere` in the fixture, run there, and compare
  the inbox file byte for byte (`cksum` before/after).
- [ ] 1.5 The resolved sender is carried to every attribution surface: the durable inbox line, the knock text
  and the knock's outbox entry `from:` field (the watcher renders it as `from <x>` and `delivered.log`
  records it). Verify: the durable-line scenario plus a dirty-box queue fixture asserting the entry's `from:`
  line and its payload text.
- [ ] 1.6 The recipient is still the addressee: the line lands in `docs/team/inbox/<recipient>.md` and the
  knock target is the recipient's window; `team notify dev …` from a worker writes to `inbox/dev.md` with
  `agent:<worker>`. Verify: one assertion per direction in the fixture.

## 2. B2 — the extension derives the same sender (`notify-and-inbox` MODIFIED)

- [ ] 2.1 `extension/team-notify.ts` derives `agent` from the worktree containing the session cwd (roster name
  preferred) instead of `window || basename(cwd)`; the tmux window name is used only to detect and log a
  disagreement, and the existing guards (cwd under the worktrees directory, not the PM window, session match)
  and the write-before-knock order are unchanged. Verify: the smoke-runner extension fixtures — headless cwd
  in `<main>/.worktrees/dev2` writes `inbox/dev2.md` with `agent:dev2`; cwd `<worktree>/docs` does the same;
  a fake tmux reporting window `dev` still writes `dev2` and logs the ignored window; a PM-window session
  still skips.

## 3. B3 — the cross-path agreement fixture (ADDED + MODIFIED)

- [ ] 3.1 One runtime context, both paths: the `dev2` fixture runs `team notify pm --from-file <f>` and the
  extension's settle; the `agent:<name>` token of both resulting lines is `dev2`. Verify: the smoke section
  extracts and compares the tokens (not a substring count), so a line still saying `agent:pm` fails.
- [ ] 3.2 The agreement survives the adversarial window: the same fixture with a fake tmux reporting window
  `dev` (cwd `.worktrees/dev2`) still yields `dev2` on both paths. Verify: the fixture's assertion names both
  lines and the window it lied about.

## 4. B4 — the smoke section and the docs

- [ ] 4.1 A new smoke section (the next free number) titled for this change pins scenarios 1.1–1.6, 2.1, 3.1
  and 3.2 with concrete assertions, using the fixture discipline above; no existing assertion is weakened or
  deleted. Verify: the section runs in `TEAM_SMOKE_FAST=1` and in the full gate, and a `git diff` of
  `tests/smoke.sh` shows only additions.
- [ ] 4.2 `SKILL.md` (the commands table) and `references/{agent-adapters,protocol,troubleshooting}.md` state
  the attribution rule, the `--from` escape and the refusal; the recommended adapter notify command becomes
  `bash {skill_dir}/scripts/team notify pm --from {agent} --from-file {summary_file}`. Verify: `grep -n 'team
  notify' skills/teamsmith/SKILL.md skills/teamsmith/references/*.md` shows the rule and the updated
  recommendation; no doc still shows a bare `notify pm --from-file` as the adapter recipe without noting the
  sender.
- [ ] 4.3 The existing notify/say fixtures still pass unchanged (the `[auto]`/`[say]`/`[draft]` line shapes and
  the PM-inbox content assertions in sections 7, 12b-pi and 13). Verify: those sections' result lines in the
  full gate, with no relaxed assertion.

## 5. B5 — the flip, the gates and the report

- [ ] 5.1 `flip-p72.sh` carries four mutations, each with a named red: (a) the line/knock/entry sender back to
  the recipient argument → 1.1/3.1 red; (b) an unresolved runtime directory falling back to `pm` → 1.4 red;
  (c) `window || basename(cwd)` in the extension → 3.2 red; (d) dropping the `TEAM_AGENT` guard → 1.3 red.
  Verify: `bash skills/teamsmith/tests/flip-p72.sh` exits 0 with each mutation's red tail printed and the tree
  restored (self-checked).
- [ ] 5.2 The red-before/green-after evidence for the delta's first scenario on the real tree: the red tail
  comes from the pre-fix code path (the apply's first commit may carry it, or the flip script's mutation (a)
  reproduces it), the green tail from the delivered tip. Verify: the report quotes both with the fixture
  commands.
- [ ] 5.3 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, then
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full**
  `bash skills/teamsmith/tests/smoke.sh </dev/null` — paste the tails; `git status --porcelain` clean.
- [ ] 5.4 The report's evidence: the requirement→item and scenario→item→evidence maps; the fixture tails for
  every scenario; the four mutation reds; the gate tails; and the statement that the 55 historical
  `agent:pm` lines were left untouched (no migration).

## 6. V — independent verification (a different agent)

- [ ] 6.1 Rerun out of tree on the apply's tip: `openspec validate --all --strict`, the full gate,
  `flip-p72.sh`; exercise every scenario of the delta with red/green evidence and record it in
  `docs/team/reviews/P72.md`; confirm no existing assertion was weakened, that the extension's line still
  lands in the sender's own inbox file, and that an unclassifiable runtime directory writes nothing. A PASS
  that still carries findings is rework (`DECISIONS.md`).
