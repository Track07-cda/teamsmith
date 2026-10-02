# Tasks: `safe-signal-discipline`

Planning only — nothing here is executed by the propose task (P154). The apply is one dependency-ordered whole:
the signal gate and its record first (the refusal must exist before anything can be tested against it), then the
background lane's record and stop entry point, then the lint (which also fixes the gate's own two pattern-based
cleanup lines), then the fixtures and the gate section that pin every scenario, then the contract rows and the
docs. The verify phase is a separate brief owned by a different agent. The change's whole delta is
`specs/boundary/spec.md`.

Coverage map (requirement → items): **RM** `boundary#The gate's actions are logged, and no window carries a
destructive-call grant` → 1.3, 1.4; **RA1** `boundary#Signals go to a recorded pid, never to a name or a pattern`
→ 1.1, 4.1; **RA2** `boundary#The signal gate's calls are recorded, and its refusals outlive the call log's
rotation` → 1.2, 4.1; **RA3** `boundary#\`team bg\` stops a job by the pid it recorded, and prints what it
signalled` → 2.1–2.4, 4.2; **RA4** `boundary#Scripts select processes by recorded pid, and the lint keeps it that
way` → 3.1–3.4, 4.3; contract rows/labels → 5.1–5.4; gates/evidence → 6.1–6.4.

How each requirement is re-checked (run what → read which part → expected value):

| Req | Run | Read | Expected |
|---|---|---|---|
| RM | the launch-command renderer on a fixture project (`team dispatch … --print`, `team up --print`) plus a real worker window's environment | the rendered prefixes and the window's `env` | the gate directory first in `PATH`, `TEAM_SIGNAL_CALLS_LOG`/`TEAM_SIGNAL_REAL` pinned beside the tmux pair, no authorization assignment written by either renderer |
| RA1 | `tests/signal-gate.sh` with the stub pinned, then `--break=pass` | exit codes, the refusal text, the stub's record, the decoys' liveness, the call log | refusal exits 64, names the tool/argv/reason/`team bg stop`, the stub's record is empty for it, both decoys alive; `--break=pass` turns the "stub not called" assertion red with a non-zero exit |
| RA2 | `tests/signal-gate.sh`'s log legs | log and `.forensics` line bytes, the rotation marker, `retention=failed` | one line per call with the family's fields, refusal copied byte for byte, marker with the cumulative `dropped`, a directory retention path exits 64 with the `✗` diagnostic |
| RA3 | `tests/team-bg-stop.sh`, `--break=no-identity`, and the harness record case in `13c`/the new section | exit codes 0/3/4/5, the printed signals, `state/bg.log`'s `stop` line, the neighbour's liveness | the recorded job dead, the unrecorded neighbour alive, refusals signal nothing; `--break=no-identity` reddens the reused-pid assertion |
| RA4 | `perl tests/signal-lint.pl` on the tree, `--selftest`, `--no-legacy`, and the scratch-copy flip | exit codes and the reported file:line | tree exit 0 with the frozen legacy files printed, `--selftest` green in both directions, a planted `pkill -f x` exits 1 naming it, the rewritten pid form exits 0 |
| rows/labels | `team config list --json`, `team config set TEAM_SIGNAL_CALLS_LOG …`, `node tests/panel-strings.mjs`, `tests/config-cli.sh` | the three records' class/kind/default, the view rows | all three are `refuse` rows, a write is refused with exit 5, each label exists in both tables and fits the column |

Path grants the apply brief must state. **Agent-owned (no grant needed):** `skills/teamsmith/tests/**` — the new
lint and its legacy list, the two fixtures, `team-bg-harness.mjs`, `smoke.sh`, `section-paths.tsv`,
`section-budgets.tsv` and any accounting table the section registry requires. **PM-owned, granted for the named
hunks only:** `skills/teamsmith/scripts/shim/{signal-gate,pkill,killall}` (new),
`skills/teamsmith/scripts/lib/{common,cmd-bg,cmd-config,cmd-project}.sh`, `skills/teamsmith/scripts/team`,
`skills/teamsmith/extension/team-bg.ts`, `skills/teamsmith/SKILL.md`,
`skills/teamsmith/references/{protocol,config,troubleshooting}.md`,
`skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` and the rebuilt committed bundle
`skills/teamsmith/scripts/panel/panel.js`. **Untouched:** the tmux shim's own verdict table and logging
(`scripts/shim/tmux`), `openspec/specs/**`, the panel beyond the three labels, the tmux-family seams'
registration, other projects' state and sessions.

Fixture notes. No fixture may execute the real `pkill`/`killall`: every shim fixture pins `TEAM_SIGNAL_REAL` to an
argv-recording stub (or puts a stub first on a private `PATH`) and asserts the stub's record. No fixture makes a
tmux call — the signal gate needs none — so the new smoke section must not request a private socket or a
container. Fixtures clear the inherited team identity (`TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION` and
the four gate variables) and run in their own scratch git repo under the owned temp family
(`tests/lib/tmp-root.sh`); the real repository's `state/` is snapshotted before and after. Every decoy/job process
is spawned by the fixture, its pid recorded, and killed by that pid in the fixture's cleanup (never by pattern).
`--break=<name>` is the fixture's own red side, and the report carries its raw output.

Acceptance commands (the same block as `proposal.md`):

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/signal-lint.pl --selftest
bash skills/teamsmith/tests/signal-gate.sh
bash skills/teamsmith/tests/team-bg-stop.sh
bash skills/teamsmith/tests/signal-gate.sh --break=pass
bash skills/teamsmith/tests/team-bg-stop.sh --break=no-identity
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## 1. RA1/RA2/RM · the signal gate and its record (`scripts/shim`, `common.sh`)

- [x] 1.1 `scripts/shim/signal-gate` + the `pkill`/`killall` entry points: refuse every selecting invocation
  with exit 64 before resolving anything (the message names the tool, the argv, why name/pattern is not identity
  — neighbours, other sessions, the caller's own shell — and the safe routes `team bg list`/`team bg stop <id>`/
  `kill <recorded pid>`); pass `--help`, `-h`, `-V`, `--version` through to the executable `TEAM_SIGNAL_REAL`
  names, else the first same-named file on `PATH` that is not the gate (exit 127 with a message when neither
  resolves); read no environment variable as an authorization. Verify: the selecting forms exit 64 with the stub's
  record empty; the read-only forms reach the stub byte for byte; a gate copy with the real binary unresolvable
  still exits 64 for `pkill -f x`.
- [x] 1.2 the audit record: `$TEAM_SIGNAL_CALLS_LOG` gets exactly one line per call
  (`<ISO> · act=<pass|refused> · tool=… · argv=… · pid=… ppid=… cwd=…`), refusals copied byte for byte into
  `$TEAM_SIGNAL_CALLS_LOG.forensics`, the family's bound/rotation marker, a failed retention printed with `✗` and
  marked `retention=failed` without changing the verdict or blocking. Verify: the 4 RA2 scenarios' raw shapes
  (two-line log, seeded rotation with the cumulative count, a directory retention path, an untouched `pass`
  retention), plus a FIFO target that does not block.
- [x] 1.3 `common.sh`: `team_tmux_shim_exports` (the single prefix the two launch renderers share) also exports
  `TEAM_SIGNAL_CALLS_LOG` (the project's state file) and `TEAM_SIGNAL_REAL` (the resolved real executable),
  names no authorization variable, and stays byte-identical for the tmux pair. Verify: the rendered prefix from
  `team_pm_launch_cmd`/`team_agent_launch_cmd` carries the four pins and no `TEAM_ALLOW_*`/signal authorization;
  a tmux-only fixture's environment still contains `TEAM_TMUX_CALLS_LOG`/`TEAM_TMUX_REAL` unchanged.
- [x] 1.4 RM's window scenarios: the gate directory first in `PATH` now resolves `pkill`/`killall` to the gate
  inside a freshly launched PM window and worker window. `[real]` one worker window's environment read back.
  Verify: `command -v pkill` and `command -v killall` inside the window name the gate directory; the environment
  carries the four pins; the renderer output is asserted in the smoke section for speed.

## 2. RA3 · the job record and `team bg stop`

- [x] 2.1 `extension/team-bg.ts`: write `state/bg/<id>.job` (`id`, `pid`, `pgid`, `start`, `cwd`, `log`, `cmd`)
  after `spawn` and before the tool returns the job id; `start` is the process's start-time fingerprint from
  `/proc/<pid>/stat` (empty when it cannot be read). Verify: the harness case (2.4) reads the record back and its
  `pid`/`pgid` match the live process.
- [x] 2.2 `scripts/lib/cmd-bg.sh` (auto-sourced by `scripts/team`) + the `bg` dispatch entry + the `team help`
  row: `team bg list` prints one row per record (id, pid, group, identity-holds/gone, command) from the current
  project's state directory only, and signals nothing. Verify: a scratch state directory with two records lists
  both; a record of a sibling state directory is not listed; `team bg` with no subcommand and `team bg stop`
  without an id exit 2 with the usage line.
- [x] 2.3 `team bg stop <id>`: identity check (pid alive + start-time fingerprint equal), group `TERM` then
  `KILL` after `TEAM_BG_STOP_GRACE` while `pgid == pid`, pid-only signalling with the "descendants not reached"
  line otherwise, the printed job/group/command, the `stop` line in `state/bg.log`, exit codes 0/2/3/4/5/6 and
  nothing signalled on every refusal, no search outside the current state directory. Verify: the four RA3
  scenarios' raw outputs (a real job stopped with the neighbour alive; unknown id 3; reused pid 5; malformed 4;
  already-gone 0 with a live descendant). **P169 (F1/F2) addendum**: the id must be a flat name and the record a
  regular file that `realpath` keeps inside this project's `bg` directory — a traversing id exits 2, a symlink,
  `pgid=0` and a FIFO record exit 4 (the FIFO before any read, never 124), and each refusal leaves the sibling's
  process alive; a live process whose current group differs from the recorded `pgid` exits 5. Verified by the
  fixture's F1/F2 sections and the `--break=no-boundary` red side.
- [x] 2.4 `tests/team-bg-harness.mjs`: a case that starts a job through the real tool and asserts the record file,
  its fields and the live pid, plus that `team bg stop` of that id (run by the section, not the harness) finds it.
  Verify: `TEAM-BG-CASE PASS` for the new case in `13c`/the new section's log.

## 3. RA4 · the lint and the pattern cleanups

- [x] 3.1 extract the shell lexer from `tests/tmux-lint.pl` into `tests/lib/shell-lex.pl`; `tmux-lint.pl` requires
  it, and the lexer annotates each word with the command words of its command substitutions. Verify: on the real
  tree `perl tests/tmux-lint.pl --list` is byte-identical before and after (`diff` of the two outputs, the
  before-file kept in the report package), `--selftest` green, the frozen legacy check unchanged; if
  byte-identity cannot be shown, the item stops and reports instead of shipping the extraction.
- [x] 3.2 `tests/signal-lint.pl`: the rule matrix (red: `pkill`/`killall` command words including `command`/`env`
  prefixes and literal absolute paths, `xargs kill|pkill|killall`, `kill` with a substitution over
  `pgrep|pidof|ps|fuser`; clean: `kill -TERM "$pid"`, `kill -0 "$pid"`, `kill -- -"$pgid"`,
  `kill "$pid1" "$pid2"`, `kill "$(cat "$pidfile")"`), `--selftest` in both directions, `--root`, `--quiet`,
  `--list`, exit 0/1/2, file:line in every report. Verify: the RA4 scenarios' raw outputs.
- [x] 3.3 `tests/signal-lint-legacy.txt` + the family's exemption code: freeze the historic evidence-package hits
  by sha256 (`docs/team/reports/M35-dev2/pkg/lib.sh`, `docs/team/reports/P119-verify/pkg/logs/*/copies/*.sh`),
  check the count every run, print them, `--no-legacy` reddens them all, and refuse to exempt anything under
  `skills/teamsmith/tests/**`. Verify: the real tree exits 0 with the frozen files printed; `--no-legacy` exits 1
  naming them; one changed byte of a frozen file makes it red by default.
- [x] 3.4 rewrite the gate's own pattern cleanup in the M25 fixture (`tests/smoke.sh`'s two `pkill -CONT/-TERM -f`
  lines) to signal the control pid the fixture already locates, with the same assertions kept. Verify: the M25
  section green in the full gate; the lint clean for `tests/**`; the section's cleanup leaves no control process.

## 4. Fixtures and the gate section

- [x] 4.1 `tests/signal-gate.sh`: the RA1 and RA2 scenarios (refuse `-f`/`-x`/`-P`/`-u`/`killall` with the decoys
  alive and the stub's record empty; `TEAM_ALLOW_PATTERN_KILL=1` grants nothing; the four read-only forms pass;
  `kill -TERM <recorded pid>` works; the log/forensics/rotation/failed-retention legs) and `--break=pass` (the
  gate executes the call → the "stub not called"/"decoys alive" assertions red). Verify: default run exit 0,
  `--break=pass` exit non-zero with the failing assertion named; no real `pkill` executed in either run (the stub
  is the only executable the gate resolves).
- [x] 4.2 `tests/team-bg-stop.sh`: the RA3 scenarios (real job stopped with the neighbour alive; unknown id 3;
  malformed record 4; reused pid 5; already-gone 0 with a live descendant; `team bg list` rows) and
  `--break=no-identity` (skip the fingerprint check → the reused-pid assertion red). Verify: default run exit 0
  with the raw outputs, `--break=no-identity` exit non-zero.
- [x] 4.3 `tests/smoke.sh`: one new section (the next free number — 57 is taken by delivery-truth as of this merge, so the apply confirms the then-free number) running the lint (tree + selftest +
  the scratch-copy flip), `signal-gate.sh`, `team-bg-stop.sh` and the harness record case; the section registry
  rows in `tests/section-paths.tsv` and `tests/section-budgets.tsv` (plus any accounting table the registry walk
  demands) and `bash tests/section-select.sh --check` green before the gate (a duplicate section key is the known
  failure mode). Verify: `--select` on the new section's key runs it green; the full suite counts the new
  assertions; `--check` exits 0.
- [x] 4.4 FAST behaviour: the new section runs in `TEAM_SMOKE_FAST=1` (no tmux, no container) or prints a visible
  SKIP with the reason — never silently absent. Verify: the FAST output names the section and its counts.

## 5. Contract rows, labels and docs

- [x] 5.1 `cmd-config.sh` (PM-owned hunk): register `TEAM_SIGNAL_CALLS_LOG|refuse|path|file,opt|plain||-|<route>||policy`,
  `TEAM_SIGNAL_REAL|refuse|path|file,opt|plain||-|<route>||policy` and
  `TEAM_BG_STOP_GRACE|refuse|seconds|0,|plain|5|<route>||policy`. Verify: `team config list --json` reports all
  three with class `refuse`; `team config set TEAM_SIGNAL_CALLS_LOG x` exits 5 writing nothing; `tests/config-cli.sh`
  green (groups/choices/completeness).
- [x] 5.2 `panel/src/strings/{zh,en}.ts`: `label_TEAM_SIGNAL_CALLS_LOG` (`信号调用审计` / `Signal call log`),
  `label_TEAM_SIGNAL_REAL` (`信号真身` / `Real signal tool`), `label_TEAM_BG_STOP_GRACE` (`作业停止宽限` /
  `Job stop grace`) — non-empty, not a re-spelling of the key, ≤22 cells in en — then rebuild the committed
  bundle. Verify: `node tests/panel-strings.mjs` green; the settings view/`config list` rows render the labels.
- [x] 5.3 `references/config.md`: rows for the three keys (the docs→schema direction reads them) and the sentence
  that names which family's seams stay environment-only. Verify: `tests/config-cli.sh` completeness green.
- [x] 5.4 `SKILL.md`'s command table (`team bg list|stop <id>` beside the background lane row) and
  `references/protocol.md`'s background-lane section: the record file, the identity rule, the refusal text and
  the signal gate's reach. Verify: `tests/routes.sh` green (the help/route walk) and a grep of both docs names
  `team bg stop`.

## 6. Gates and evidence

- [x] 6.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` passes with the change's delta.
- [x] 6.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` passes with the new section run.
- [x] 6.3 `bash skills/teamsmith/tests/smoke.sh </dev/null` passes on an idle-enough machine (the section makes no
  tmux call; if a timed panel section reddens on the machine premise, record the load and re-run — the section's
  own premise governs).
- [x] 6.4 Report `docs/team/reports/<ID>-<agent>.md`: the recon, the delta→requirement map, the two `--break` red
  runs and the restored green runs, the lint's selftest and the scratch-copy flip, the lexer-extraction
  `--list` diff, the launch-prefix rendering tail, both gate tails and the raw outputs of every scenario above.

## Apply status (P169 rework, 2026-10-02)

All 24 items are delivered; this footer names the evidence so the ticks are not read as 24 independent
re-verifications. Re-verified by P169's own runs (`docs/team/reports/P169-dev2.md`): 1.3 (a rendered launch prefix
carries the four pins and no authorization), 2.1–2.4 and 4.2 (fixture, both break modes, harness record case),
3.1 (pre-extraction vs extracted `tmux-lint.pl` print byte-identical `--list` on the same tree), 3.2/3.3 (tree
green, `--selftest`, `--no-legacy` red by name), 4.1 (both runs), 4.3/4.4 (registry check, container `--select 58`,
FAST), 5.1–5.3 (config-cli completeness, panel strings, config.md rows), 6.1/6.2. Taken from P159's apply
(`docs/team/reports/P159-dev-bob.md`) and P166's independent matrix (`docs/team/reports/P166-verify.md`) without
re-running here: 1.4 (the real PM/worker windows — full gate only), 3.4's M25 leg (the pid-form rewrite is in
`smoke.sh` and the lint is clean for `tests/**`; the section itself runs in the full suite), 6.3 (the full suite;
last recorded run is P159's `✓4149 ✗0` — this rework's gate contract is the container `--select 58` + FAST).
