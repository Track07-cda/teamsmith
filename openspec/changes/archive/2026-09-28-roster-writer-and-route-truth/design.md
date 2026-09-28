# Design: `roster-writer-and-route-truth` — the roster gets one authorized entry, and every printed route is exercised

## 1. Context

Read-only recon against this checkout (`.worktrees/verify`, branch `task/P46-propose`), measured 2026-09-22. The
field claims come from the task brief and the `do` project's incident; every number below was re-measured here in
scratch fixtures and is reproducible with `bash docs/team/reports/P46/repro.sh` (fixture reproductions) and the
probe prototype recorded in `docs/team/reports/P46/` (route-sincerity measurements). Two decisions from the brief
frame the work: **D36** — an implementation task must not be dispatched to the verify seat, so this task writes
planning artifacts only (`openspec/changes/**` + a report) and the apply goes to a dev — and **D37** — a fixture
must never signal a process it did not spawn, so the route walk shims `tmux` on `PATH` and spawns nothing to
signal.

### 1.1 The four field claims (re-measured, `docs/team/reports/P46/repro.log`)

Fixture: a fresh git repo + `team init --session p46 --agents "dev verify" --vcs local --gates true`.

| # | Measured output | Code |
|---|---|---|
| 1 | `team config set TEAM_AGENTS 'dev verify dev2' --yes` → `✗ TEAM_AGENTS 是只读键，控制台不改它` + `名册：team add-agent / team teardown` (exit 5) | schema row `cmd-config.sh:43`, message `cmd-config.sh:915` |
| 1b | `team add-agent dev2` → `✗ 未知 agent：dev2（名册：dev verify ）` (exit 1) | `team_worktree_add` → `team_require_agent` (`cmd-agents.sh:15`, `common.sh:1199`) |
| 1c | `team teardown --agent verify` → exit 0, contract sha256 unchanged | `team_cmd_teardown` never touches `TEAM_AGENTS` (`cmd-agents.sh:1049`) |
| 1d | the only `TEAM_AGENTS` write in the CLI is the `bootstrap`/`init` template render (`cmd-project.sh:196`); every other hit is a read | `grep -rn TEAM_AGENTS skills/teamsmith/scripts/` |
| 2 | `team config set-agent-model dev2 …` → `✗ 未知席位 dev2：名册是（dev verify）加 pm` + the same dead route (exit 5) | `cmd-config.sh:913-916` |
| 3 | `team help` line 40: `add-agent <a> [--model m]`; `team add-agent dev --model anthropic/claude-sonnet-4-20250514` → `✗ add-agent: 未知参数 --model` (exit 2) | `cmd-project.sh:40` vs `team_cmd_add_agent`/`team_worktree_add` |
| 4 | `skills/teamsmith-init/SKILL.md:27`: "`team add-agent <name>` adds more at any time" | promised behaviour ≠ 1b |

So the roster's only working route today is a hand edit — which the `do` PM correctly did. The defect is not the
refusal (refusing is right) but that **the printed route names a command that cannot do the job**.

### 1.2 The printed-route surface, measured

`team help` prints **41 distinct `--flag` tokens** in **62 (command, flag) claims** (multi-verb lines multiply:
`pulse up|down|restart|status|logs [--print]` is five claims). Each claim was probed against its own
command in a fixture (`<cmd> <flag>`, contained: `tmux` recorder shim, `TEAM_PI_BIN=/bin/true`, stdin
`/dev/null`; the committed probe is `docs/team/reports/P46/probe-routes.sh`, its log `probe-routes.log`):

- **58 accepted, exactly 1 refused**: `add-agent --model` (claim 3). The other flags are real, the ones printed
  only in a usage line's own description included (`board add --allow-dup`, `watch --ui`, `perf --host`,
  `outbox flush --now`). A flag mentioned only on a *continuation* line (e.g. `review`'s `--branch`) is outside
  the walk's scope by construction — the help wraps, and the walk reads entry lines.
- **One help line is not indented**: `board add|assign|set|row|ls …` (`cmd-project.sh:32`) starts at column 0, so
  every indentation-based parse (`^ {2}<command>`) misses that whole entry and with it the `--allow-dup` claim.
  This is why Walk A derives *entry lines* from the command names the CLI carries instead of from indentation, and
  treats a column-0/non-command line inside the command block as a failure: the walk must catch this line, not
  skip it (the two-space fix is part of the copy sync, D7).
- **Non-vacuity control** over the 28 commands that print at least one flag (an unknown flag
  `--frobnicate-probe`): 25 refuse it with the tool's unknown-parameter message; `reload` refuses with its usage
  line and exit 2 (enough — a command that refuses is not swallowing); **`version` and `meeting list` accept it
  and run** (exit 0). Those two are today's proof that "the flag was accepted" is not yet a safe inference: a
  command that ignores arguments cannot be trusted to have honoured a printed flag either.

Two schema notes are also false for an existing project (measured, `repro`-adjacent fixture):

- `TEAM_PROJECT`/`TEAM_SESSION`/`TEAM_PM_WINDOW` notes say `手改 .pi/team/config.sh（或重新 team init）`.
  A bare `team init` on a project that has a contract prints `skip …（已存在，--force 覆盖）` and leaves the file
  **byte-identical** — the note promises a no-op as a route. `team init --force` does change the key, but it
  re-renders the whole contract: `TEAM_GATES='bash my-own-gate.sh'` → `TEAM_GATES="true"` (measured).
- `TEAM_AGENTS`'s note names `team add-agent / team teardown`, i.e. claim 1's dead route.

**8 schema keys** name a `team` command in their note today: `TEAM_PROJECT`, `TEAM_SESSION`, `TEAM_PM_WINDOW`,
`TEAM_AGENTS`, `TEAM_DEFAULT_MODEL`, `TEAM_AGENT_MODELS`, `TEAM_PM_MODEL`, `TEAM_PULSE_WINDOW`.

### 1.3 The writer as it is

- `team_config_set_in_file` (`cmd-bootstrap.sh:24`) is the one low-level writer: single-line `KEY='value'`, byte
  preservation, atomic temp+`bash -n`+`mv`, no `#`/newline/quotes where the flat reader cannot take them.
- `team_config_write_checked` (`cmd-config.sh:794`) is the one checked entry: class → kind/range validation →
  danger list → fingerprint CAS → audit + write. It refuses class `refuse` **before** the value rules run
  (`cmd-config.sh:806-811`), and `TEAM_AGENTS` is `refuse` (`cmd-config.sh:43`).
- The audit is one line per attempt in `<state>/config.log` with the result vocabulary
  (`ok`/`refused`/`invalid`/`conflict`/`danger-refused`/`write-error`), the actor (`cli` default, `panel` from the
  console), key, old and new value (`cmd-config.sh:786-790`).
- The `list` kind has **no value rule** (`cmd-config.sh:426-427`: `return 0`), and `TEAM_AGENTS` is the only key of
  that kind — so there is no seat-name rule anywhere: `team init --agents 'a;b'` renders it, and only
  `team_require_agent` (exact string compare) notices.

## 2. Goals / Non-Goals

**Goals.** (1) One authorized, audited CLI route changes the roster; without it the refusal names routes that
work, and the key's refusal class is unchanged. (2) `add-agent --model` stops being a lie: the seat's configured
model is written through the same writer `set-agent-model` uses. (3) A gate check turns "the printed route must
work" from a convention into a fixture: every printed flag accepted by its own parser, no flag-printing command
swallows unknown flags, every schema note that names a command names one that exists and does what it says in a
fixture, and the whole walk is red on today's shapes. (4) The init skill's roster promise matches the tool.

**Non-Goals.** The panel (it keeps refusing the roster; it renders the schema's route text, which this change
fixes — no panel code changes); a `--json` form of `team help`; warning on malformed hand-edited rosters beyond
the register refusal and the read's `warning` field; `team init --force`'s destructive re-render (only its
existence is named in the note); `team config set`'s class model; everything outside `skills/**` and
`openspec/changes/<this change>/**`.

## 3. Decisions

### D0. Spec homes: `memory-and-deps`, `dispatch`, `init-skill`

| # | Promise | Capability | Delta |
|---|---|---|---|
| R1 | the contract's one writer also covers the roster entry: value rule, CAS, one audit line; `TEAM_AGENTS` stays `refuse`; the identity note names a route that works | `memory-and-deps` | MODIFIED (`The project contract has exactly one writer…`) |
| R2 | the roster's CLI entry: `add-agent --register [--model]` / `teardown --register`, refusals and exit codes, help lines | `dispatch` | ADDED |
| R3 | the printed route is exercised by the gate: help↔parser walk, non-vacuity control, schema-note promise probes, flips | `dispatch` | ADDED |
| R4 | the init skill's roster bullet names the register route | `init-skill` | MODIFIED (`Initialization guidance lives in a dedicated teamsmith-init skill`) |

The brief allows `dispatch` **or** `watchdog` for the third delta; this change writes `dispatch`, and the brief's
`deltas:` header already resolves it there. Reason: the roster is the set of seats a dispatch can address, and
`add-agent`/`dispatch`/`teardown` are one command surface (`cmd-agents.sh`); `watchdog` owns the pulse's wake-up
set, and nothing in this change moves it. R1 keeps the contract-side facts (the value rule, the writer's CAS and
audit, the refusal class) with the capability that owns the contract; R3 is the gate mechanism. To keep one
statement per rule, R1 owns the *note-text* rule ("a note names only routes that work on an existing project")
and R3 only *checks* it — R3's text says so explicitly.

### D1. The register flag, not a new `team roster` verb

Ruled: `team add-agent <agent> --register` and `team teardown --agent <agent> --register`.

- The two printed routes already name exactly these commands (`team add-agent` / `team teardown`), and M48's
  `--allow-dup` is the project's precedent for "the tool does the thing that is normally refused, behind an
  explicit flag plus one audit line". The fix keeps the vocabulary and makes the route true.
- Rejected `team roster add|remove`: `team roster` is already the read-only view of the roster; giving the same
  noun a write verb would make one word mean two things, and `roster remove` would duplicate `teardown`'s
  lifetime work (window/state/worktree) with unclear ordering. Two names for one act is the second-route disease
  this change is about.
- Rejected `--allow-roster-write` (names the mechanism, not the act), `--roster` (reads like a filter), a new
  `team register` verb (new vocabulary for one act, and `--model` would have no home).

### D2. The write path: a roster-authorized entry into the one writer

Ruled:

- A new internal entry (`team_config_write_roster` in design terms; the name is not part of the contract) mirrors
  `team_config_write_checked` for exactly `TEAM_AGENTS`: read the current value and fingerprint → build the new
  value (existing tokens in order + the new one, or minus the removed one) → validate the **whole resulting
  value** with the roster rule → CAS against the fingerprint of the bytes it read (or the caller's
  `--fingerprint`) → `team_config_set_in_file` → exactly one `result=ok actor=cli` audit line; the writer's exit
  codes (`3` conflict, `4` invalid, `6` write error) are reused. `team config set TEAM_AGENTS …` never reaches it
  (class check first), so the console's authority is unchanged.
- **One value rule** (`[A-Za-z0-9][A-Za-z0-9._-]*`, unique, never `pm`) lives with the key's `list` kind (R1), so
  `team config list --json` reports a violating token as that key's `warning` (the way `TEAM_AGENT_MODELS` reports
  an unknown seat) and the register entry refuses the same token with exit 4. The shape is not cosmetic: the token
  becomes a directory name under `.worktrees/`, a tmux window name, a state file and a branch.
- **Order of operations** in `add-agent`: validate `--model`'s shape first (a predictable error must not leave a
  registered seat), then the roster write, then the model write, then the existing worktree step (`team_worktree_add`
  still calls `team_require_agent`, which the register write has already satisfied — the reverse order cannot work,
  which is why the roster write is first by construction). Each written value gets its own audit line; the command
  states what landed and what did not.
- **Idempotence**: an existing seat with `--register` is a visible no-op (exit 0, no write, no audit), so a
  re-run after a partial failure completes the work.
- **CAS**: `--fingerprint <sha256>` has `team config set`'s semantics (documented in `references/config.md`, not
  printed in the help line — `config set`'s flags are documented there too, and the route walk only governs what
  `team help` prints). It is also what makes the CAS falsifiable without a test-only hook: a stale fingerprint is
  exit 3, nothing written, one `result=conflict` line.

### D3. `set-agent-model` keeps refusing an unknown seat

Ruled: unchanged. The brief's Q2 offers "allow the unknown seat with a visible warning + audit" or "let
`--register` carry `--model`"; we take the second, so the about-to-join seat is served by one command and the
config command keeps its rule. The first alternative was rejected twice over: it contradicts the base requirement's
scenario "An unknown seat is refused, in the pair form and in the whole value" (it would need a MODIFIED delta on
the very requirement P43 modifies, for a weaker statement), and it would write a `TEAM_AGENT_MODELS` token naming
a seat the roster does not carry — a value the pairlist validator itself refuses, i.e. a second, inconsistent
route to the same file.

### D4. `--model` is implemented, not deleted

Ruled: `add-agent --model <m>` writes the seat's configured model through the same writer and the same pairlist
serializer `set-agent-model` uses (`-` removes the override). Reasons: the help line already prints it and the
brief's Q2 leans on it; the seat's model is part of "what this seat is", so roster + model is one human intent;
and the write is an existing one, so this adds a second *real* route, not a new mechanism. `dispatch --model`
stays what it is (a per-run explicit model recorded as `model_src=explicit`), and the help lines make the
difference visible. Rejected: deleting `[--model m]` from help — it is the cheapest honesty fix, but it removes a
printed promise instead of honoring it and leaves the two-step window in which a seat exists with the fallback
model.

### D5. The route-sincerity walk: parse `team help`, probe behaviour, refuse to be vacuous

New fixture `skills/teamsmith/tests/routes.sh` (standalone; `TEAM_ROUTES_TREE=<tree>` for scratch-tree flips, the
`config-cli.sh` convention), wired into the correctness gate by one `smoke.sh` section, supporting `TEAM_ROUTES_KEEP=1`.

**Walk A — help lines ↔ parsers.**

1. Parse `team help`: the command sections are the blocks between the `── … ──` separators. **Entry lines** are the
   lines there whose first token (after leading whitespace) is a command the CLI carries (the dispatcher's names
   plus the pre-dispatch `help`/`version`) — deriving entries from the command names, not from indentation, is
   measured necessity: `board add|assign|set|row|ls` (a real entry with the `--allow-dup` claim) is not indented
   and an indentation-based parse skips it (design §1.2). Every other line in a command block is a continuation of
   the entry above it — and a line in a command block that is neither an entry nor indented **deeper** than the
   entry above it is a **failure naming the line**, as is any line carrying a `--flag` that no entry owns. A line
   splits into **usage fragments** on `｜` and `／` (today: `meeting read … ｜ meeting inbox ｜ meeting list
   [--all]`, `meeting propose … ｜ meeting agree … ｜ meeting close …`, `version / help`). A fragment names one
   command path: the leading command tokens, with a `|` group expanding into its alternatives (`pulse
   up|down|restart|status|logs`, `config list|set|log|set-agent-model`, `board add|assign|set|row|ls`, `outbox
   [list]`). Placeholders (`<a>`, `ID`, `…`, a quoted example) are not command tokens.
2. Flags: every `--[a-z0-9-]+` token in the fragment (bracketed or not — `meeting open`'s `--with`/`--topic` and
   `task`'s `--title` are mandatory but printed). A flag in the command part binds to every alternative of the
   group it follows (`--print` on the `pulse` group → all five verbs); a flag in the description binds to the
   nearest preceding verb token of that fragment's own group, else to the fragment's single command (`board …
   （add [--allow-dup] …）` → `add`; `perf …；--host …` → `perf`). A flag that binds to nothing, or a fragment
   that names no command, is a **failure naming the line**, never a skip.
3. A flag printed for more than one path may fail for one and pass for another: each (path, flag) pair is judged
   on its own, and the alternatives are probed separately (`board add --allow-dup` is a claim, and so are the
   other four verbs' flags).
4. Every named command path must resolve (the CLI's dispatcher table plus the pre-dispatch `help`); an unknown
   path is a failure naming it.
5. For every (path, flag): probe `<path> <flag>` in the fixture project with the containment below; a probe is a
   failure, naming the path and the flag, iff the output carries the tool's unknown-parameter refusal
   (`未知参数`) or an unknown-subcommand refusal naming that flag. Anything else (a missing-value error, a usage
   line, a contained run, a timeout) means the parser accepted it and is printed as the probe's note together with
   the observed first line — a slow or loud command stays visible.
6. **Non-vacuity control**: for every path that prints at least one flag, probe `--frobnicate-probe`; it MUST be
   refused (non-zero exit). This is the arm that catches `version` and `meeting list` today.
7. **Per-path probe mode**: default `run`; `source` for a command that execs another program (declared with a
   file and a reason — `perf` → `tests/perf.sh`, whose own parser owns `--host`; running `perf` to prove a flag
   would run the performance suite inside the fixture). `source` asserts the flag appears as an accepted case
   label in the declared file. `skip` does not exist for a printed flag — the mode table is a probe declaration,
   never an exemption.

**Walk B — schema notes ↔ reality.**

1. Parse `team_config_schema()`; for every row whose note text names a `team …` command: the command MUST resolve,
   and the key MUST have a promise-probe entry (the set is **derived from the schema**, so a new note naming a
   command without a probe fails naming the key).
2. Run the entry's probe in the fixture and require its asserted effect (never the exit code). Today's table
   (8 keys, 6 probes):

| Key(s) | Note's promise | Probe asserts |
|---|---|---|
| `TEAM_PROJECT`, `TEAM_SESSION`, `TEAM_PM_WINDOW` | hand edit (and `team init --force` with its cost) | a hand edit changes what `team paths` prints; a bare `team init` leaves the contract's sha256 unchanged; `--force` changes it by restoring the template value |
| `TEAM_AGENTS` | `team add-agent … --register` / `team teardown … --register` | the register write changes the line and audits it; teardown removes it |
| `TEAM_AGENT_MODELS` | `team config set-agent-model <seat> <model>` | the token is written, audited, and the read's seat row carries it |
| `TEAM_PM_MODEL` | `team up` rebuilds the PM with it | `team up --print`'s rendered command carries the value |
| `TEAM_PULSE_WINDOW` | `team pulse down` → change → `team pulse up` | with an empty-session shim, `pulse up`'s recorded `new-window -t <session> -n <value>` carries the key's value |
| `TEAM_DEFAULT_MODEL` | the next spawn takes it (`dispatch`/`resume`/`team up`) | with a worktree on the task branch, `team dispatch … --print` renders `--model <value>` |

**Containment (identical for both walks).** Every run happens in a fresh `mktemp -d` fixture under `$TMPDIR`
(`TEAM_CONFIG_TREE`-style tree override for the flips), with a recording `tmux` shim first on `PATH` that answers
session *queries* as absent (`has-session` → exit 1, `list-windows`/`list-panes` → empty) and records mutations —
this is measured necessity: a record-only shim that exits 0 everywhere makes the `TEAM_PULSE_WINDOW` danger check
believe a backend is live (`是危险值 …先 team pulse down`, measured in the prototype), while an absent-answering
shim lets the same key be set and lets `pulse up` record `-n pulse2` (measured). `TEAM_PI_BIN=/bin/true`,
`TEAM_MEETINGS_DIR` inside the fixture, `env -u TMUX -u TMUX_PANE`, stdin `/dev/null`, a hard timeout per probe
(`TEAM_ROUTES_TIMEOUT`, default 15 s) and an EXIT trap that removes every fixture directory (subshell-guarded, the
P50 hygiene rule). The timeout is **containment, never a verdict**: a probe that times out is recorded as
accepted with a visible note, so the walk adds no wall-clock red line to the correctness gate (`verification`:
"The correctness gate judges correctness only").

**Flips carried by the fixture** (each a scratch copy via `TEAM_ROUTES_TREE`): the field shape — `add-agent`'s help
line printing `--model` while the parser refuses it (today's tree is that shape, so the pre-change run is the red
side); a sibling flag (`--fresh`, accepted by `dispatch`) printed on the `add-agent` line; a `ps` parser that stops
refusing unknown flags; a `TEAM_GATES` note naming `team frob off`; a schema note naming a command with no probe;
and a broken roster write (register exits 0 without changing the file) for the promise probe.

### D6. The two parser fixes the control forces

`version` and `meeting list` accept unknown arguments and run (measured, exit 0). The control arm requires refusal,
so both gain the standard `-*)` unknown-argument refusal (`team_usage_die`), which also covers their printed
`--check`/`--all` flags. `reload` already refuses (exit 2, usage line) and is left alone — the control requires
refusal, not a specific wording, and inventing a wording rule would be a second contract.

### D7. Copy sync (one route, one wording)

| Where | What changes |
|---|---|
| `cmd-config.sh` schema rows | `TEAM_AGENTS` note → `名册：team add-agent <a> --register / team teardown --agent <a> --register`; identity rows → hand edit (and `team init --force` with its re-render cost) |
| `cmd-config.sh:915` | the refusal line names the register flag |
| `team help` | `add-agent <a> [--register] [--model m] [--create] [--no-install] [--print]`, `teardown [--agent a] [--all] [--purge] [--force] [--register]` (today the line hides `--force`, which the parser accepts — same line, same fix), and the `board` line's missing two-space indent (`cmd-project.sh:32`, measured) |
| `skills/teamsmith/SKILL.md` | the command table's `add-agent`/`teardown` rows carry the register flag |
| `skills/teamsmith/references/config.md` | the `refuse` row's route; the `TEAM_AGENTS` key section states who writes the roster, that it needs the flag, and that the write is audited; `--fingerprint` documented for the two entries |
| `skills/teamsmith/references/protocol.md` | one paragraph: the roster is a contract value with one authorized entry, the audit, and why the console may not write it |
| `skills/teamsmith/references/{workflows,troubleshooting}.md` | the roster-growth recipes use `--register` |
| `skills/teamsmith-init/SKILL.md:27` | the roster sentence names `--register` (and `teardown --register`), stays under the 100-line cap |

### D8. Sequencing against P43

P43 (`ledger-and-gate-noise`) modifies the `memory-and-deps` requirement *"A seat's model is read and written as a
seat…"*; this change modifies a **different** requirement in the same capability (*"The project contract has
exactly one writer…"*). The single-writer rule still binds because both deltas land in the same capability file at
archive time: this change's delta block must be written against the base that P43 leaves behind, so the apply brief
is dispatched only after P43's apply has landed (`openspec list` / the base spec shows P43's text), and the apply
owner re-reads the base requirement before touching the delta. Nothing in this change edits the seat-model
requirement, so P43's scenarios cannot be dropped by it.

## 4. Review methods

| Requirement | Command | Expected |
|---|---|---|
| R1 roster entry is a contract write | `bash skills/teamsmith/tests/config-cli.sh` (+ the smoke sections named in tasks) | register writes one line + one `result=ok actor=cli`; `team config set TEAM_AGENTS …` exits 5 naming `--register`; stale `--fingerprint` exits 3 with `result=conflict`; `dev api/1` → exit 4 + read `warning` |
| R2 the register CLI | the R2 scenarios in `specs/dispatch/spec.md`, exercised by smoke + `tests/routes.sh` | flagless refusal exits 5 with both routes; re-register no-op; `teardown --register` removes; `--model` writes the seat's model; `--all --register` exits 2 |
| R3 route sincerity | `bash skills/teamsmith/tests/routes.sh` and the scratch-tree flips it runs | green on the tree; red naming command+flag for a fake printed flag, a sibling flag, a swallow, a nonexistent named command, an unprobed note, a broken promise |
| R4 init skill | `grep -n 'team add-agent' skills/teamsmith-init/SKILL.md`; `wc -l < skills/teamsmith-init/SKILL.md` | the roster bullet carries `--register`; ≤100 lines |
| whole change | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` then the two gates in the proposal's Acceptance block | exit 0 |

## 5. Open risks / handed to the PM

1. **Two writes, one intent (`--register --model`).** The roster write lands before the model write by
   construction; the model's shape is validated first so the predictable error writes nothing. A CAS conflict or a
   write error on the second write leaves a registered seat on the fallback model and is reported with the retry
   command — the command states both outcomes, the seat is never half-created (no window/worktree).
2. **The description-flag rule in Walk A.** A flag mentioned in a usage line's own description is treated as a
   claim (today: `board add --allow-dup`, `watch --ui`, `perf --host`, `outbox flush --now` all pass). A future
   help line that mentions a foreign flag in its description will go red and must either drop the mention or make
   the flag real — intended, but worth knowing before the first surprise.
3. **The promise-probe table is hand-written per key.** Its coverage is schema-derived and the probes assert
   effects, but a lazy probe could be written; the PM's proposal review and the verify phase read the six probes
   individually. The alternative (probes generated from note text) is not implementable honestly.
4. **`version` / `meeting list` get a parser fix** even though the brief's field report did not mention them: they
   are what makes the printed-flag check vacuous for their own lines. Small, and named here so it is not a
   surprise in the apply diff.
5. **`team init --force` stays destructive.** This change only makes the note say so; a non-destructive
   "add a seat at init time" path is not part of the incident and would need its own change.
6. **`team_require_agent`'s message stays route-less** (`未知 agent：dev2（名册：dev verify ）`, exit 1), and
   `dispatch`/`say`/`notify` reach it for an unknown seat. That message prints no route and is neither a `team
   help` line nor a schema note, so it is outside this change's checks; adding the register hint there is a
   one-line follow-up if the PM wants it.
