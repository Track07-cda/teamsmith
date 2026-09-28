# Tasks: `roster-writer-and-route-truth`

Planning only — nothing in this file is executed by the propose task (P46). One apply brief is the plan: the
writer entry, the CLI entries and the two walks share one gate run and one report. If the PM prefers a split, the
order is **implementation first, walk second** — items 1–4 (the register entry, the value rule, the copy sync, the
init sentence) are one brief and items 5–6 (`tests/routes.sh` and its flips, the gate wiring) another, because the
walk's green run must happen on the final text of the routes it judges (a walk landed before the copy sync would
judge a tree that is about to change).

Coverage map (requirement → items): **R1** the contract's one writer covers the roster entry, the value rule and
the identity note (`memory-and-deps`, MODIFIED) → 1.1–1.3; **R2** the roster's CLI entry (`dispatch`, ADDED) →
2.1–2.3; **R3** the printed route is exercised (`dispatch`, ADDED) → 3.1–3.4; **R4** the init skill's roster
sentence (`init-skill`, MODIFIED) → 4.1–4.2; gate, evidence and verification → 5.1–5.3.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| R1 | `bash skills/teamsmith/tests/config-cli.sh list validate roster` | the read's `warning` for a hand-edited `dev api/1`, and the register write's `diff` + audit tail | `warning` names `api/1`; the write changes one line, `bash -n` exits 0, one `result=ok actor=cli` line; `team config set TEAM_AGENTS …` still exits 5 naming `--register` |
| R2 | `bash skills/teamsmith/tests/config-cli.sh roster` and the smoke section of 4.2 | the exit codes and messages of the seven shapes (register, flagless refuse, re-register, stale fingerprint, teardown, `--all --register`, `--model`) | 0 / 5 / 0 / 3 / 0 / 2 / the model line written — each with the roster bytes and audit lines named in the spec |
| R3 | `bash skills/teamsmith/tests/routes.sh` | one `ok` per usage line, one per probe, the control lines, and the six flips' outputs | exit 0 on the tree; each flip red naming the command/flag/key it must name; no fixture left under `$TMPDIR` |
| R4 | `grep -n 'register' skills/teamsmith-init/SKILL.md`; `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init` | the roster bullet and the line count | the bullet names `team add-agent <name> --register` and `teardown --register`, no flagless-growth promise, ≤100 lines, parser exit 0 |
| change | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`, then the two gate commands | their exit codes | 0 |

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/tests/**` is agent-owned;
`skills/teamsmith/scripts/lib/{cmd-agents,cmd-config,cmd-project,cmd-watch}.sh`,
`skills/teamsmith/scripts/team`, `skills/teamsmith/SKILL.md`, `skills/teamsmith/references/{config,protocol,workflows,troubleshooting}.md`
and `skills/teamsmith-init/SKILL.md` are **PM-owned** and need an explicit grant for this change (the register
entry, the roster value rule, the help text, the schema notes, the docs and the two parser fixes only);
`openspec/changes/roster-writer-and-route-truth/**` belongs to the phase's owner; `docs/team/reports/**` is the
agent's own file. `openspec/specs/**`, `docs/team/tasks/**` and the panel bundle stay PM-owned.

Fixture notes: every fixture clears inherited team identity (`env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT
-u TEAM_SESSION -u TMUX -u TMUX_PANE`) and writes only inside a `mktemp -d` scratch tree; the route walk's `tmux`
shim answers session queries as absent (`has-session` → exit 1, `list-windows` → empty) and records mutations —
a recording-only shim that exits 0 for every query makes the `TEAM_PULSE_WINDOW` danger check believe a backend
is live (measured, design §D5) — and every fixture removes its directories on exit (`$TMPDIR` hygiene, P50).

## 0. Preconditions (`memory-and-deps` base)

- [ ] 0.1 The apply re-reads the base requirement it edits. Verify:
  `grep -c 'Every seat row SHALL be serialized with a value in every field' openspec/specs/memory-and-deps/spec.md`
  prints `1` (P43 archived) and `ls openspec/changes/ | grep -c ledger-and-gate-noise` prints `0`. If either
  fails, STOP and hand back to the PM: this change's delta must be cut from the post-P43 base (design §D8), and
  P43's seat-model scenarios must stay intact.

## 1. The contract's writer and the roster value rule (`memory-and-deps`, MODIFIED)

- [ ] 1.1 `scripts/lib/cmd-config.sh`: give the `list` kind a rule (`cmd-config.sh:426` returns 0 today): every
  token matches `[A-Za-z0-9][A-Za-z0-9._-]*`, appears once, and is not `pm`. Verify: `team config set` on another
  key is unaffected; a scratch schema row of kind `list` refuses `a/b` — the fixture assertion lands in 1.3.
- [ ] 1.2 `scripts/lib/cmd-config.sh`: add the roster-authorized write entry — build the value from the current
  file (add or remove one token, canonical single-space join), validate the whole result with 1.1, CAS against the
  fingerprint of the bytes read (or the caller's `--fingerprint`), write through `team_config_set_in_file`, and
  append exactly one audit line (`ok`/`invalid`/`conflict`/`write-error` with `actor=cli`) — mirroring
  `team_config_write_checked`'s tail without widening `team config set`'s class check. Verify: the `roster`
  section of 1.3; plus `team config set TEAM_AGENTS 'dev verify' --yes` still exits 5 and its message carries
  `--register` (the class check is still first).
- [ ] 1.3 `scripts/lib/cmd-config.sh` (the read) and `tests/config-cli.sh`: report a roster token that violates
  1.1 as `TEAM_AGENTS`'s `warning` in `team config list --json` (naming the token, the way `TEAM_AGENT_MODELS`
  reports an unknown seat), and add the fixture assertions for 1.1/1.2/1.3 and the stale-`--fingerprint` conflict
  (exit 3, one `result=conflict`, nothing written). Verify: `bash skills/teamsmith/tests/config-cli.sh list
  validate roster` green, and a scratch tree whose warning is removed makes the section red.

## 2. The register entry (`dispatch`, ADDED)

- [ ] 2.1 `scripts/lib/cmd-agents.sh`: `team add-agent <agent> [--register] [--model <provider/model>|-]
  [--fingerprint <sha256>] [--create|--no-install|--print]` — validate the model shape first (nothing written on a
  predictable error), then the roster write (1.2) when `--register` is given and the seat is new, then the seat's
  model write through the existing pairlist path (`team_config_pairlist_upsert` + `team_config_write_checked`),
  then today's worktree step; `--register` on an existing seat is a visible no-op (exit 0, no write, no audit);
  without `--register` a seat outside the roster exits 5 naming the hand-edit and `--register` routes with no
  window, worktree, state or contract change. Verify: `bash skills/teamsmith/tests/config-cli.sh roster` (the new
  section) and `team add-agent dev2` in a fixture printing both routes.
- [ ] 2.2 `scripts/lib/cmd-agents.sh`: `team teardown --agent <agent> --register` removes the seat through 1.2
  before the existing window/state/worktree handling; `--all --register` and a missing `--agent` are usage errors
  (exit 2); a seat outside the roster exits 5 naming the roster with nothing written; without the flag the roster
  is byte-identical (today's behaviour). Verify: the `roster` section's teardown shapes.
- [ ] 2.3 `scripts/lib/cmd-project.sh` (help) + `cmd-config.sh` (schema notes, `:915`):
  `add-agent <a> [--register] [--model m] [--create] [--no-install] [--print]`,
  `teardown [--agent a] [--all] [--purge] [--force] [--register]`, the `TEAM_AGENTS` note naming
  `--register`, the `set-agent-model` refusal line naming `--register`, and the `board` line's missing indent
  (`cmd-project.sh:32` starts at column 0 — measured; an indentation-based parse skips it and the route walk
  would flag it as an unattributable line).
  Verify: `team help | grep -n 'add-agent\|teardown'` shows the flags; `team config list --json`'s
  `TEAM_AGENTS.route` carries `--register`; `team help | grep -c '^board add'` prints `0` (the line is indented
  now) — the route walk of 3.2 re-checks both.

## 3. The route-sincerity walk (`dispatch`, ADDED)

- [ ] 3.1 `tests/routes.sh` (new, standalone, `TEAM_ROUTES_TREE`/`TEAM_ROUTES_KEEP`/`TEAM_ROUTES_TIMEOUT`):
  Walk A — parse `team help`'s usage lines into fragments/paths/flags (design §D5 rules 1–4), resolve every path
  in the dispatcher, probe every (path, flag) in a contained fixture, fail naming path+flag on the tool's
  unknown-parameter refusal, and fail naming the line when a flag or fragment cannot be attributed (including a
  command-block line that is neither an entry nor indented deeper than the entry above it — today's `board add|
  assign|set|row|ls` shape, until 2.3 indents it). Verify:
  `bash skills/teamsmith/tests/routes.sh` green on the tree; a scratch `TEAM_ROUTES_TREE` copy with
  `add-agent <a> [--model m]` restored (no parser support) is red naming `add-agent --model`.
- [ ] 3.2 `tests/routes.sh`: Walk B — derive from `team_config_schema()` every note that names a `team` command,
  resolve the command, require a promise-probe entry (coverage from the schema), and run the six probes of design
  §D5's table (identity hand-edit + bare-`init` no-op + `--force` cost, register/teardown, seat model, PM model via
  `team up --print`, pulse window via the shim's recorded `new-window -n`, default model via `dispatch --print`).
  Also fix the identity notes to name only routes that work (hand edit; `team init --force` with its re-render
  cost) — R1's note rule, whose check is this walk. Verify: the walk green; a scratch copy whose `TEAM_GATES` note
  names `team frob off` is red naming `TEAM_GATES`/`team frob`; a schema note added without a probe is red naming
  the key.
- [ ] 3.3 `tests/routes.sh`: the non-vacuity control — for every path that prints a flag, an unknown flag
  (`--frobnicate-probe`) must be refused — plus the two parser fixes it forces: `cmd-update.sh`'s `version`
  branch and `cmd-meeting.sh`'s `meeting list` branch gain the standard `-*) team_usage_die` refusal (measured:
  both accept an unknown flag and exit 0 today; `reload` already refuses and stays untouched). Verify: the
  control's lines green; a scratch tree whose `ps` parser stops refusing unknown flags is red naming `ps`.
- [ ] 3.4 `tests/routes.sh` + `tests/smoke.sh`: the six flips (sibling flag `--fresh` on the `add-agent` line;
  a `ps` that swallows; the fake schema route; the unprobed note; a broken roster write) and containment — fresh
  `$TMPDIR` fixture per walk, absent-answering tmux shim, `TEAM_MEETINGS_DIR` inside the fixture, stdin
  `/dev/null`, a timeout per probe, an EXIT trap that removes every directory, and nothing of the caller's tree
  touched. Verify: each flip's tail; `ls "${TMPDIR:-/tmp}" | grep -c '^routes\.'` prints `0` after a run; the
  caller's `git status --porcelain` is unchanged.

## 4. The skill texts (`init-skill` MODIFIED, docs)

- [ ] 4.1 `skills/teamsmith-init/SKILL.md` (roster bullet, `:27`): name `team add-agent <name> --register` and
  `team teardown --agent <name> --register` and that the write is audited; no sentence promises flagless growth.
  Verify: `grep -n 'register' skills/teamsmith-init/SKILL.md` shows the bullet, `wc -l < skills/teamsmith-init/SKILL.md`
  is ≤ 100, `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init` exits 0.
- [ ] 4.2 `skills/teamsmith/SKILL.md` (command table), `references/config.md` (`refuse` row; the `TEAM_AGENTS`
  section: who writes the roster, the flag, the audit; the two entries' `--fingerprint`), `references/protocol.md`
  (one paragraph: who writes the roster, the flag, the audit, and why the console may not) and
  `references/{workflows,troubleshooting}.md` (the roster recipes use `--register`).
  Verify: `grep -rn 'add-agent' skills/teamsmith/SKILL.md skills/teamsmith/references/` shows no flagless roster
  recipe left, and the completeness walk inside `bash skills/teamsmith/tests/config-cli.sh completeness docs` stays
  green.

## 5. Gate and evidence

- [ ] 5.1 `tests/smoke.sh`: one section that runs `tests/routes.sh` (so the two-part gate covers it) and the
  register fixtures' cheap half; extend the existing init-skill assertion (`smoke.sh:5129`) to require `--register`
  in the roster sentence. Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` green, and
  reverting the init sentence alone turns that assertion red.
- [ ] 5.2 [real] `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`; `TEAM_SMOKE_FAST=1 bash
  skills/teamsmith/tests/smoke.sh </dev/null`; `bash skills/teamsmith/tests/smoke.sh </dev/null` (once, full);
  `git status --porcelain` clean. Paste the tails.
- [ ] 5.3 The report's flip section: the four field reproductions before → after, each walk flip's before/after
  tail, the stale-fingerprint conflict and the register write's `diff` + audit line, and the trial archive on a
  scratch copy (`cp -r openspec /tmp/trial-p46 && (cd /tmp/trial-p46 && openspec archive -y
  roster-writer-and-route-truth)`) proving the MODIFIED requirements keep every base scenario.
- [ ] 5.4 Independent verification (a different agent — the pipeline's verify phase): rerun the walk, the register
  fixtures and the full gate on the apply's tip; write the record to `docs/team/reviews/<ID>.md`. A PASS carrying
  findings is rework, not archive.
