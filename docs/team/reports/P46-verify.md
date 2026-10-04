# P46 · `roster-writer-and-route-truth` — the proposal package and the measurements behind it

agent: verify   status: DONE   time: 2026-09-22T10:17Z
branch: `task/P46-propose`   PR/MR: - (local mode: no push, the branch stays local)

Phase: **propose** (planning only — no `skills/**`, `tests/**`, `scripts/**` or `openspec/specs/**` change; the
verify seat writes no implementation). Change: `roster-writer-and-route-truth` · deltas: `memory-and-deps`
(MODIFIED), `init-skill` (MODIFIED), `dispatch` (ADDED ×2). Base revision: `64120a3` (the P46 brief commit).

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/roster-writer-and-route-truth/proposal.md` | why · what changes · capabilities · impact/out-of-scope · the four acceptance commands · the flips · the evidence the apply report must carry |
| `openspec/changes/roster-writer-and-route-truth/design.md` | §1 the re-measured recon (the four claims; 62 printed-flag claims + the 28-command control; the un-indented `board` help line; the identity note's no-op route; the writer's refuse-class check), §2 goals/non-goals, D0–D8, the per-requirement review-method table, six residuals |
| `openspec/changes/roster-writer-and-route-truth/tasks.md` | one apply brief (with the implementation-first split named), coverage map R1–R4 → items, the path grants the brief must state, fixture/isolation notes, items 0.1–5.4 |
| `…/specs/memory-and-deps/spec.md` | **MODIFIED** `The project contract has exactly one writer, and it preserves what it does not change` — the roster-authorized entry (value rule, CAS, one `result=ok actor=cli` audit line), `TEAM_AGENTS` stays `refuse`, the value rule's read warning, and the rule that a schema note names only routes that work on an existing project (base 4 scenarios verbatim + 3 new) |
| `…/specs/dispatch/spec.md` | **ADDED** `The roster changes only through an explicitly authorized registration` (7 scenarios) and `The printed route is a route that works` (the two walks, the control and six flips; 8 scenarios) |
| `…/specs/init-skill/spec.md` | **MODIFIED** `Initialization guidance lives in a dedicated teamsmith-init skill` — the roster bullet names `--register`/`teardown --register` and promises no flagless growth (base 4 scenarios verbatim + 1 new) |
| `docs/team/reports/P46/repro.sh` + `repro.log` | the four field claims re-measured in a scratch fixture (claims 0/1a–1e/2/3/4) |
| `docs/team/reports/P46/probe-routes.sh` + `probe-routes.log` | the route-sincerity measurement: 62 `(command, flag)` claims probed against their own parsers + the 28-command non-vacuity control, with a summary line per walk |
| `docs/team/reports/P46/probe-promise.sh` + `probe-promise.log` | feasibility of the schema-note promise probes (identity hand-edit vs bare `team init` no-op vs `--force` re-render, `TEAM_DEFAULT_MODEL` via `dispatch --print`, `TEAM_PM_MODEL` via `up --print`, `TEAM_PULSE_WINDOW` via the shim's recorded `new-window -n`) |

## The brief's six design questions, answered

1. **The roster's write path — `--register`, not a new `team roster` verb.** `team add-agent <a> --register`
   grows the roster and `team teardown --agent <a> --register` shrinks it; both go through the contract's one
   writer with the roster's value rule, fingerprint CAS and one audit line, and `TEAM_AGENTS` stays `refuse`
   (`team config set TEAM_AGENTS …` keeps exiting 5, now naming a route that works). Without the flag the refusal
   names the two routes that really work (hand edit / `--register`). M48's `--allow-dup` is the precedent
   (explicit flag + one audit line), the two route names the schema already prints stay the same, and
   `team roster` is already the read-only view — giving that noun a write verb would make one word mean two
   things and duplicate `teardown`'s lifetime work. The write lands **before** the worktree step, which the
   existing code forces anyway (`team_worktree_add` calls `team_require_agent`).
2. **A seat that is about to join gets its model from `--register --model`**, not from a relaxed
   `set-agent-model`. The alternative would have to contradict the base scenario "An unknown seat is refused, in
   the pair form and in the whole value" (a MODIFIED delta on the very requirement P43 also modifies) and would
   write a pairlist token the pairlist validator itself refuses. `--model` is validated before any write, so a
   predictable error leaves nothing behind; the roster write then precedes the model write, and the command
   states what landed and what did not.
3. **`--model` is implemented, not deleted.** The help line already prints it; the seat's model is part of what
   the seat is; and the write is an existing one (the same writer and pairlist serializer as
   `config set-agent-model`, with `-` removing the override). Deleting the flag would be the cheapest honesty
   fix but removes a printed promise instead of honoring it. `dispatch --model` stays a per-run explicit choice.
4. **The falsifiable route check.** A new standalone fixture `tests/routes.sh` (wired into the gate): Walk A
   parses `team help`'s entry lines (derived from the command names, **not** from indentation — see finding F5),
   probes every printed `(command, flag)` claim against that command's own parser in a contained fixture, fails
   naming command+flag on the tool's unknown-parameter refusal, and fails naming any command-block line it cannot
   attribute; its non-vacuity control requires every flag-printing command to refuse `--frobnicate-probe` (two
   commands do not, today). Walk B derives from `team_config_schema()` every note that names a `team` command,
   requires the command to resolve and a declared promise probe to exist (coverage from the schema, not a
   hand-kept list), and asserts each sentence's **effect** in the fixture. Six flips are carried by the fixture
   itself (the field shape, a sibling flag, a swallowing parser, a fake schema command, an unprobed note, a
   broken roster write).
5. **Copy sync.** Schema notes (`TEAM_AGENTS`, the identity keys), `cmd-config.sh:915`, the `team help` lines
   (including the `--force` the parser accepts but the line hides), `skills/teamsmith/SKILL.md`,
   `references/{config,protocol,workflows,troubleshooting}.md`, `skills/teamsmith-init/SKILL.md:27` — each says
   who writes the roster, that the write needs the flag, and what audit it leaves (design §D7 + tasks 2.3/4.1/4.2).
6. **The invariant holds.** The console may not widen its own authority: the key stays `refuse`, the panel is out
   of scope (it renders the CLI's route text, which this change fixes), and what is added is an explicitly
   authorized CLI entry, not a writable key.

## What the recon found beyond the brief's four (all measured, logs committed)

- **F1 — the identity note promises a no-op.** `TEAM_PROJECT`/`TEAM_SESSION`/`TEAM_PM_WINDOW` say
  `手改 .pi/team/config.sh（或重新 team init）`; a bare `team init` on a project with a contract prints
  `skip …（已存在，--force 覆盖）` and leaves the file byte-identical (sha256 identical in `probe-promise.log`),
  while `team init --force` rewrites the whole contract (`TEAM_GATES='bash my-own-gate.sh'` → `"true"`). The
  note must name the hand edit and `team init --force` with its re-render cost.
- **F2 — a printed flag that does not exist.** 62 `(command, flag)` claims; 61 accept the flag and one is refused:
  `add-agent --model` (`✗ add-agent: 未知参数 --model`, exit 2). Every other printed flag is real.
- **F3 — two commands swallow unknown flags.** The control over the 28 flag-printing commands: 25 refuse with the
  unknown-parameter message, `reload` refuses with its usage line (exit 2); **`version` and `meeting list` accept
  an unknown flag and exit 0** (`teamsmith 1.42.0`, "还没有任何会议"). The walk's non-vacuity arm forces their
  standard `-*)` refusal — without it, "the flag was accepted" is not a safe inference for their own lines.
- **F4 — the help line under-documents `teardown`** (`--force` is accepted, not printed) — same line, same fix.
- **F5 — one help line is not indented.** `board add|assign|set|row|ls    …（add [--allow-dup] …）`
  (`cmd-project.sh:32`) starts at column 0, so any indentation-based parse skips that entry and the `--allow-dup`
  claim with it. The walk therefore derives entry lines from the command names the CLI carries and treats a
  non-entry, non-indented line in the command block as a failure; the two-space fix is part of the copy sync.

## Evidence

### The four claims (scratch fixture; `bash docs/team/reports/P46/repro.sh`, full log in `repro.log`)

```
===== claim 1a · schema says the roster route is: team add-agent / team teardown =====
43:TEAM_AGENTS|refuse|list||plain||-|名册：team add-agent / team teardown||identity

===== claim 1b · team add-agent <not in roster> dies on team_require_agent =====
✗ 未知 agent：dev2（名册：dev verify ）
(exit=1)

===== claim 1c · team teardown --agent <seat> does not touch TEAM_AGENTS =====
config.sh before=8b5c3f76cb87… after=8b5c3f76cb87…  (same=yes)

===== claim 1e · the only CLI route is a hand edit of .pi/team/config.sh =====
✗ TEAM_AGENTS 是只读键，控制台不改它
  名册：team add-agent / team teardown
(exit=5)

===== claim 2 · set-agent-model on a seat that is about to join =====
✗ 未知席位 dev2：名册是（dev verify）加 pm
  名册的键是 TEAM_AGENTS（只读）：team add-agent / team teardown
(exit=5)

===== claim 3 · team help prints [--model m] for add-agent; the parser refuses it =====
40:  add-agent <a> [--model m]    建长期 worktree（分支 agent/<a>）
✗ add-agent: 未知参数 --model
(exit=2)

===== claim 4 · the init skill's promise =====
27:   plenty**; `team add-agent <name>` adds more at any time, so the roster grows and shrinks with the work actually
```

### The route-sincerity premise (`bash docs/team/reports/P46/probe-routes.sh`)

```
add-agent --model                          FAKE (parser refused it, rc=2)   ✗ add-agent: 未知参数 --model
meeting list --frobnicate-probe            SWALLOWED (rc=0)                 还没有任何会议（team meeting open …）
version --frobnicate-probe                 SWALLOWED (rc=0)                 teamsmith 1.42.0
reload --frobnicate-probe                  refused, other message (rc=2)    ✗ reload [--done]

--- summary ---
walk A: 62 printed flags probed; refused by their own parser: add-agent --model
control: 28 commands probed; commands that swallow an unknown flag (exit 0): meeting list --frobnicate-probe
version --frobnicate-probe
```

### The promise probes are feasible (`bash docs/team/reports/P46/probe-promise.sh`)

```
  init: skip  …/.pi/team/config.sh（已存在，--force 覆盖）
  contract sha256 before=3dace17bbd99 / after=3dace17bbd99  (no-op: yes)
  before --force: TEAM_GATES='bash my-own-gate.sh'    …
  after  --force: TEAM_GATES="true"                   …
  dispatch --print: --model deepseek-flash
  up --print: --model pm-model
  shim recorded: new-window -t p46promise -n pulse2
```

### The proposal package's own gate

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 20 passed, 0 failed (20 items)

$ PATH="$HOME/.bun/bin:$PATH" openspec status --change roster-writer-and-route-truth
Progress: 4/4 artifacts complete
[x] proposal  [x] specs  [x] design  [x] tasks

$ mkdir -p /tmp/trial-p46 && cp -r openspec /tmp/trial-p46/openspec && (cd /tmp/trial-p46 && openspec archive -y roster-writer-and-route-truth)
Applying changes to openspec/specs/dispatch/spec.md:        + 2 added
Applying changes to openspec/specs/init-skill/spec.md:      ~ 1 modified
Applying changes to openspec/specs/memory-and-deps/spec.md: ~ 1 modified
Totals: + 2, ~ 2, - 0, → 0
```

The trial archive is the check that the two MODIFIED blocks keep every base scenario: the merged
`memory-and-deps` one-writer requirement carries its four base scenarios plus the three new ones, and the merged
`init-skill` requirement its four plus one. Trial copy removed afterwards (`/tmp` left clean).

## Flip sides

This is a propose task, so no implementation flips exist yet; what is measured **now** is the red side the apply
must turn green, and the guard's own falsifiability is specified scenario by scenario:

- red, measured: `add-agent --model` → `未知参数` (exit 2); the roster route naming a command that dies
  (`未知 agent`, exit 1); `team config set TEAM_AGENTS` exiting 5 with a route that cannot write; the identity
  note's `team init` re-run leaving the contract byte-identical; `version`/`meeting list` accepting an unknown
  flag.
- green, to be proven in apply (and re-proven independently): `--register` changing exactly one line + one
  `result=ok actor=cli` line; a stale `--fingerprint` exiting 3 with `result=conflict`; the walk green on the
  tree and red on each of its six flips (design §D5; scenarios in `specs/dispatch/spec.md`).

## Acceptance

| Command | Result |
|---|---|
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | exit 0, 20/20 |
| `bash docs/team/reports/P46/repro.sh` | exit 0, four claims re-measured |
| `bash docs/team/reports/P46/probe-routes.sh` | exit 0, one refused printed flag + the control |
| `bash docs/team/reports/P46/probe-promise.sh` | exit 0, all four probe legs observable |
| trial archive on a scratch copy | exit 0, `+2 ~2 -0` |
| `bash skills/teamsmith/tests/routes.sh`, the two gate commands | **not run** — they are the apply's deliverables; the brief's acceptance section marks them "after apply" |

## Decisions and deviations

- **Delta placement** as the brief allows: `dispatch` (not `watchdog`) for the two ADDED requirements — the
  roster is the set of seats a dispatch can address and `add-agent`/`dispatch`/`teardown` are one command surface;
  `watchdog` owns the pulse, which nothing here moves. The brief's `deltas:` header already lists `dispatch`.
- **P43 sequencing is honoured in the plan, not just in prose**: item 0.1 stops the apply unless P43's text is in
  the base. My delta deliberately does **not** touch the seat-model requirement P43 modifies, so the ordering
  constraint costs nothing but the base re-read.
- **`--fingerprint` on the two register entries** (documented, not printed in the help line — `config set`'s flags
  are documented in `references/config.md` too). It is what makes the CAS falsifiable without a test-only hook:
  a stale value is exit 3 with one `result=conflict` line.
- **No `--dry-run`** on the register entries: the flag is the authorization, the write is audited, and the fixture
  proves the effect; another knob would be another route to keep true.
- **Two parser fixes the walk's control forces** (`version`, `meeting list`) are in scope and named in design §D5
  / tasks 3.3 — without them the printed-flag check is vacuous for their own lines.
- **The panel is untouched** (out of scope, stated in the proposal): it keeps refusing the roster and prints the
  schema's route text, which this change fixes; no panel string or bundle changes.
- **Local mode**: no push, no PR; the branch `task/P46-propose` carries the three commits (evidence → package →
  this report).

## Boundaries

Wrote only `openspec/changes/roster-writer-and-route-truth/**`, `docs/team/reports/P46/**` and this report.
No `skills/**`, `tests/**`, `scripts/**`, `openspec/specs/**`, `docs/team/tasks/**` or `docs/team/BOARD.md`
change; every fixture ran inside a `mktemp -d` scratch tree with inherited team identity stripped, and each was
removed on exit (no `/tmp` residue; P50 hygiene).

## Suggested next steps

1. **PM proposal review** (`docs/team/reviews/roster-writer-and-route-truth-proposal.md`) against the ten-point
   checklist; the two judgement calls worth a second look are R3's Walk A parse rules (design §D5) and the
   promise-probe table (six probes for eight keys — the three identity keys share one probe).
2. Then the **apply** brief: `change: roster-writer-and-route-truth`, `phase: apply`, `deltas: memory-and-deps,
   init-skill, dispatch`, plus the path grants tasks.md lists (scripts/lib, SKILL.md, references, the init skill)
   and item 0.1's P43 precondition. A competent dev brief; the verify phase must be a different agent.
3. Two judgement items for the PM if they disagree: (a) whether the unknown-agent message used by
   `dispatch`/`say`/`notify` should also name the register route (design §5 residual 6 — deliberately out of
   scope); (b) whether the `version`/`meeting list` parser fix should ride along or be its own change (they are
   what makes R3's control meaningful, so this change carries them).
