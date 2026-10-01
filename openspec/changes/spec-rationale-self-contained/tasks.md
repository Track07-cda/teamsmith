# Tasks: `spec-rationale-self-contained`

The propose task (P145) wrote the change, `design.md` and this task's delta — `specs/boundary/spec.md`, the ADDED
requirement. Nothing else below is executed by it. The apply is one dependency-ordered whole: the walk and its
declared table first (it must be able to redden before anything is retired), then the retirements the walk reports,
then the gate wiring and the authoring rule. The verify phase is a separate brief owned by a different agent.

Coverage map (requirement → items): **R1** `boundary#Specs are the contract` → 1.1–1.5, 2.5, 3.1–3.2, 4.1;
its two scenarios' flips → 1.4, 1.5, 2.5; the MODIFIED requirements of R1's retirement rule → 2.1–2.4;
gates and evidence → 5.1–5.4.

How each scenario is re-checked (run what → read which part → expected value):

| Scenario | Run | Read | Expected |
|---|---|---|---|
| R1 · the walk passes here, and reddens on a citation nothing retires | `bash skills/teamsmith/tests/spec-refs.sh --check` (and the same with `--root` a copy whose `openspec/changes/` is empty, and `--flips`) | exit code; the retirement lines; the red lines | this tree: exit 0, one retirement line per retired reference carrying file/line/retiring change, no undeclared reference; the empty-changes copy: non-zero naming `openspec/specs/verification/spec.md` and `docs/team/reports/P52-dev2.md`; `--flips` catches the planted concrete path that a slot pattern would otherwise swallow |
| R1 · a record-id family without its key is red | `--check --root` on a copy whose `Id families:` line is deleted, and on a copy whose line omits `F<n>` while the text uses `F2` | exit code; the named family | non-zero naming the file and the family; the untouched copy exits 0 |
| both | `bash skills/teamsmith/tests/spec-refs.sh --flips` | one `red`/`clean` line per mutation | every mutation in 1.4 behaves as required, exit 0 |

## 1. R1 · the walk and the declared reference table (`boundary`)

- [ ] 1.1 `skills/teamsmith/tests/spec-ledger-refs.tsv` (new): comment header with the columns
  (`pattern <TAB> kind <TAB> basis`), the matcher's semantics (`<…>` = one no-space component, `*` = wildcard
  within a component, `**` = any suffix; **a `slot` row matches only a slot-shaped reference — one that itself
  carries `<…>` or `*` — and a concrete reference only an exact `ledger`/`example` row**, so a slot pattern may not
  swallow a citation) and the `kind` vocabulary `slot | ledger | example`; then one row per declared reference,
  seeded from `docs/team/reports/P145-dev2/spec-ledger-refs.draft.tsv` (41 rows; the dry run proves the calibration
  in `docs/team/reports/P145-dev2/dryrun.log`). Verify:
  `bash skills/teamsmith/tests/spec-refs.sh --list-declared` prints exactly the file's rows, and `--check` names
  no reference on the current tree.
- [ ] 1.2 the rows themselves, checked against the tree: `grep -rhoE 'docs/team/[A-Za-z0-9_*./<>-]+' openspec/specs/ | sed 's/[.,)]*$//' | sort -u`
  (44 distinct references today) plus the backticked forms; the classes are the draft's (`slot` for a pattern with
  `<…>`/`*`, `ledger` for `docs/team/` and the ledger's fixed files, `example` for a concrete record a fixture
  owns). Two rows are judgment calls the design records and the PM may overturn: `docs/team/PUBLISH.md` → `ledger`
  (a project-owned ledger document, named by the shipped `references/workflows.md:214`),
  `docs/team/reports/P97-dev3.md` → `example` (an argument, not evidence). Verify: every row's `basis` is
  non-empty; `--check` on the current tree names exactly the four citations of 2.1–2.3 and nothing else (the
  dry-run expectation, line for line).
- [ ] 1.3 `skills/teamsmith/tests/spec-refs.sh` (new): build each capability's **effective text** — the base
  `openspec/specs/<capability>/spec.md` plus, for every directory under `openspec/changes/*/specs/<capability>/`,
  `ADDED` requirements appended, `MODIFIED` requirements substituted by requirement title, `REMOVED` requirements
  dropped; judge references on that text, matching by requirement title only. Verify: on the current tree the
  walk's own `--debug-blocks`-style output (or a fixture copy) shows
  `verification#A fixture observes a data-derived state before it asserts it` taken from the delta, not the base.
- [ ] 1.4 the retirement rule and the flips: a base reference whose requirement **any** pending change rewrites is
  retired only when **every** pending version of that requirement drops it; a retired reference prints one line
  `retired <file>:<line> <reference> by <change>` and does **not** fail the run; anything else fails with
  `undeclared <file>:<line> <reference>`. `--flips` mutates scratch copies under the owned tmp family
  (`tests/lib/tmp-root.sh`) and prints one line per mutation: **red** — `docs/team/reports/P52-dev2.md` planted in
  a spec's `## Purpose` (the concrete reference a slot pattern must not swallow; the first draft matcher passed it,
  which is why this mutation is in the list); an undeclared reference with no slot pattern of its shape; the
  `Id families:` line deleted; a line naming `V<n>` but not `F<n>` while the text uses `F2`; **clean** — a declared
  slot (`docs/team/reports/<ID>-<agent>.md`), a declared example record, the untouched tree. Verify: `--flips`
  exits 0 with all mutations as required; and with the `## ADDED Requirements` block removed from the change's
  boundary delta, `--check` exits non-zero.
- [ ] 1.5 the id key: read the families from the line beginning `Id families:` in the effective text (`` `P<n>` ``
  … `` `F<n>` ``), require the set used by the text to be a subset of the set named, and fail naming the file and
  the family otherwise; when `docs/team/` does not exist (a product-only checkout) print one explicit
  `skip` line saying no ledger is present to cite, never a silent green. Verify: the two red mutations and the
  clean copy of 1.4; the skip line under `--root` a copy without `docs/team/`.
- [ ] 1.6 reverse guard: before/after hashes of `openspec/specs/**` and `docs/team/inbox/**` must be identical
  after a `--flips` run (the fixture writes only under the tmp root), asserted inside `--flips`. Verify: the
  assertion is green, and it is red when the fixture is pointed at the real tree by hand.

## 2. R1 · the retirements (`verification`, `notify-and-inbox`)

The two MODIFIED blocks are **already drafted and proven** in `docs/team/reports/P145-dev2/deltas/{verification,notify-and-inbox}.spec.md`
(generated from the current baseline by `docs/team/reports/P145-dev2/trial.sh`; see `trial.log` §1–§2 and §5). The
apply copies them into the change, re-checks each rewrite against the then-current baseline (another change may have
archived a sibling requirement first), and keeps every scenario. The scenarios themselves are not edited — only the
four sentences in the table above change.

- [ ] 2.1 `openspec/changes/spec-rationale-self-contained/specs/verification/spec.md` (new delta): MODIFIED
  `A fixture observes a data-derived state before it asserts it` — the draft's block, i.e. the requirement in full
  with the design's rewrites 1 and 2 (`(the attribution recipe: 0 s green, 6 s red, 6 s plus five times the horizon
  still red)`; `or the loaded host on which 4 of 6 runs were red`) and all four baseline scenarios verbatim.
  Verify: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` green, and the scenario count keeping 4
  (trial.log §2).
- [ ] 2.2 same delta file: MODIFIED `A measuring fixture measures a fixed tree, not the caller's worktree` with
  rewrite 3 (`measured as 3683 ms from a large checkout against 391 ms from a fresh project`) and both scenarios.
  Verify: as 2.1 (2 scenarios).
- [ ] 2.3 `.../specs/notify-and-inbox/spec.md` (new delta): MODIFIED `Messages to a stopped agent fall back to the
  inbox` with rewrite 4, naming the shipped frame
  `skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt`, and all three scenarios. Verify: as 2.1 (3
  scenarios).
- [ ] 2.4 the frame swap is honest: `cmp skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log`
  exits 0 (byte-identical; the shipped copy is the one the gate already uses). Verify: the comparison's empty
  output, and `git grep -n 'pi-0.87.0-one-line-draft.txt' -- skills/teamsmith/tests/smoke.sh` showing the gate
  reads the shipped frame.
- [ ] 2.5 the scenario-preservation duty is kept by the gate itself: dropping one scenario from a MODIFIED block
  reddens `openspec validate --all --strict` (trial.log §3: `17 passed, 1 failed`, naming the omitted scenario);
  with the blocks intact the run is `18 passed, 0 failed` (trial.log §4). Verify: both runs, and a trial archive on
  a scratch copy (`cd <scratch> && openspec archive -y spec-rationale-self-contained`) applying
  `+ 1 added, ~ 3 modified` with the four citations gone from the base specs afterwards (trial.log §5–§6).
- [ ] 2.6 `--check` after 2.1–2.3: exit 0, four retirement lines (three for `P52-dev2.md` at
  `verification/spec.md:611,632,672`, one for the frame log at `notify-and-inbox/spec.md:105`), no undeclared
  reference. Verify: the run's output, and the same run against a copy whose `openspec/changes/` is empty naming
  all four.

## 3. R1 · the gate wiring (`boundary`)

- [ ] 3.1 `skills/teamsmith/tests/smoke.sh`: a new section (`18c · 公开契约的自洽：账本引用须声明 + 记录 id 须带键`)
  after section 18, running `--check` and `--flips` and reporting `bad` on a non-zero exit; no `[real]` marker (the
  walk starts no process). Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 18c </dev/null`
  is green, and the same run with an undeclared reference appended to a spec is red (the fixture copy, never the
  real tree).
- [ ] 3.2 the section bookkeeping the suite's own guards read: a `section-budgets.tsv` row with a measured band
  (`band = max(host, container, ci)`, at least one measured value; `--budget-check` must count the new section),
  a `section-paths.tsv` row whose patterns include `openspec/specs`, `openspec/specs/*`,
  `skills/teamsmith/tests/spec-refs.sh` and `skills/teamsmith/tests/spec-ledger-refs.tsv`, with its `needs` and its
  basis. Verify: `bash skills/teamsmith/tests/section-guard.sh --budget-check` and `--loop-check` are green (no
  `while`+`sleep` loop is added), and `section-select.sh --check` is green.

## 4. R1 · the authoring rule (`boundary`)

- [ ] 4.1 `skills/teamsmith/references/openspec.md`: one bullet in `## 2. One phase = one task = one owner`
  (PM-owned, needs the grant) — a spec cites only declared references, evidence belongs in the spec's text, the
  record ids stay defined by the `Id families:` line of `boundary#Specs are the contract`, and
  `bash skills/teamsmith/tests/spec-refs.sh --check` is the check to run before hand-off. Two text-shaped gate
  checks constrain the edit (smoke section 19): the bullet MUST NOT introduce a `^### Requirement:` line anywhere in
  the file, and it MUST NOT add a line matching `^[0-9]+\.` between `### The PM's proposal review checklist` and the
  next `## ` (the section counts exactly ten). Verify: the paragraph names the file and the command; smoke section
  18 (English body) and section 19 stay green; `flip-p23.sh`'s 7.5 flip (deleting checklist point 10) still reddens.
- [ ] 4.2 report `docs/team/reports/<ID>-<agent>.md`: the red tail (the empty-changes copy naming the four
  citations), the green tail with the retirements, the `--flips` output, the `cmp` output, both gate tails, the
  delta→requirement map and the exact changed-path list.

## 5. Gates and evidence

- [ ] 5.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` — green with both new delta files.
- [ ] 5.2 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` — green.
- [ ] 5.3 `bash skills/teamsmith/tests/smoke.sh </dev/null` — green on an idle-enough machine (a timed panel
  section that reddens on load records its load and is re-run; the section's own premise governs).
- [ ] 5.4 the walk's own commands are the flips' evidence: `--check` red then green, `--flips` green, and the
  retirement lines quoted in the report.

## 6. Path grants the apply brief must state

- The two delta files: `openspec/changes/spec-rationale-self-contained/specs/verification/spec.md` and
  `.../specs/notify-and-inbox/spec.md` (the change directory is the propose task's grant; the apply owns these two
  files, and no other unfinished task of this change writes them).
- Agent-owned: `skills/teamsmith/tests/**` — the two new files plus `smoke.sh`, `section-budgets.tsv` and
  `section-paths.tsv`.
- **PM-owned, needs an explicit grant**: `skills/teamsmith/references/openspec.md` (one paragraph).
- Untouched: `skills/teamsmith/scripts/**`, `skills/teamsmith/extension/**`, `skills/teamsmith/tests/**`'s existing
  fixtures' behaviour, the panel, tmux, `docs/team/**`, and `openspec/specs/**` — the base specs are written only
  by the archive, which is what phase 5 does with these deltas.

Fixture notes: the walk is pure text — no tmux, no network, no window, so nothing here can reach a real session;
`--flips` writes only under the owned tmp family (`tests/lib/tmp-root.sh`) and asserts the real
`openspec/specs/**` and `docs/team/inbox/**` are byte-identical afterwards (1.6).
