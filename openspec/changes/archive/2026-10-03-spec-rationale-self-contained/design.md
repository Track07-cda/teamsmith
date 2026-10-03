# Design: `spec-rationale-self-contained` — the public contract cites only what it ships

## Context

The measurement this design rests on is `docs/team/reports/P145-dev2/recon.sh` / `recon.log` (read-only; the
counts quoted here are its §10, §20, §30, §40 output), and the rule's calibration is the dry run
`docs/team/reports/P145-dev2/dryrun.sh` / `dryrun.log` (the draft declared table over the real tree, then over a
scratch copy with the four planned rewrites). Three facts decide the shape of the change:

1. **The shipped contract cites the internal ledger four times, and the reference vocabulary is otherwise
   legitimate.** `openspec/specs/**` holds 87 `docs/team/…` references (file:line:ref triples, 44 distinct).
   Four of them point at records that exist only here — `docs/team/reports/P52-dev2.md` at
   `verification/spec.md:611`, `:632`, `:672` and
   `docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log` at `notify-and-inbox/spec.md:105` — and all
   four carry evidence ("measured 0 s green, 6 s red", "3683 ms from this worktree against 391 ms", "4 of 6 runs
   were red", "the shape of the real frame"). The other 83 are the skill's own vocabulary: 24 slots
   (`docs/team/reports/<ID>-<agent>.md`, `docs/team/inbox/<agent>.md`, …), 5 whole-ledger references
   (`docs/team/**`), the ledger's fixed files (`BOARD.md`, `OWNERSHIP.md`, `DECISIONS.md`) and the specs'
   example records.
2. **The record ids cannot simply be deleted.** 135 tokens of the families `P/M/D/V/E/F` stand in six spec files.
   Some are *fixture ids a scenario invents* (`M39`, `M1`, `V1`, `P1`, `P17`), some are *quoted fixture output*
   the gate really prints (`M45 idle-read=EMPTY ok` — `tests/pm-box-real.sh:244`; the section title
   `看板重复 ID（M48）` — `tests/smoke.sh:1531`), and some are *citations* of internal records (`V9-B5`, `E6 §0`,
   `D37`, `M49`, `V16 F-V16-4`). A blanket ban on the tokens would desynchronise the spec from what the fixture
   prints, which is the one thing a scenario may not do.
3. **The base specs are written only by archive** (`memory-and-deps#Spec management belongs to OpenSpec`), and a
   delta cannot carry a `## Purpose` — the CLI reads one only when the target spec does not exist yet and ignores
   it otherwise with a warning (`@fission-ai/openspec@1.8.0`, `dist/core/specs-apply.js:209-212`). So a fix that
   edits a spec's prose has to ride a MODIFIED block, and a fix that adds a note above the requirements has no
   carrier at all.

The anchor named by the brief, `boundary#Specs are the contract`, does not exist in the tree
(`grep -rn 'Specs are the contract' openspec/` matches only the brief), so the change adds it; no baseline
requirement is modified by this task's delta and no baseline scenario can be lost.

## Goals / Non-Goals

**Goals**

- A reader holding only the public tree can read any spec's rationale: every claim's evidence is in the text, and
  every `docs/team/…` reference is one the skill itself defines or an example the spec's own fixture owns.
- The maintainers' record ids may stay (they are how a maintainer finds the evidence, and they are inside quoted
  output), but their meaning is stated once, in the contract, and a family the text uses cannot go unnamed.
- Both promises are asserted by the project gate, with a falsifiable red side, and the assertion does not lie about
  a citation that a pending change is about to retire.

**Non-Goals**

- No rewrite of the specs' scenarios, their commands or their numbers; no weakening of a requirement.
- No vocabulary change in `skills/**` (scripts, tests, references): the brief allows the codenames there, and the
  fixtures must keep printing what they print.
- No leak scan here: `docs/team/**` contains no secret, and `publish-public.sh` already excludes the tree.

## Decisions

### D1 — the rule is about *references*, not about the string `docs/team/`

The brief's example assertion ("`openspec/specs/**` must not contain `docs/team/` paths") would fail 83 of the 87
references — and three of those failures are promises the contract must keep: `boundary#An actor touches only the
paths its brief allows` names `docs/team/OWNERSHIP.md` as the source of ownership;
`verification#The record states what was verified` names `docs/team/reviews/<ID>.md`; the notify and delivery
capabilities name `docs/team/inbox/<agent>.md` as the durable copy. Deleting those references would weaken the
specs, which item 2 of the brief forbids. The rule therefore names what is forbidden — a reference to a record of
the maintainers' ledger — rather than the string.

### D2 — the reference vocabulary is *declared*, not inferred

The forbidden set is expressed as the complement of a table: a reference is allowed when
`skills/teamsmith/tests/spec-ledger-refs.tsv` declares it, with its kind (`slot` | `ledger-file` | `example`) and
the basis for letting it into the public contract. Two cheaper rules were measured and rejected:

- **Exists in this repo's ledger ⇒ forbidden.** `docs/team/reviews/T1.1.md`, `docs/team/reports/T1.1-dev.md`,
  `docs/team/reviews/P1-done.md` and `docs/team/threads/dev.md` all exist (recon §10) and are the specs'
  *examples* (`T1.1` is the running example id of four capabilities, and `smoke.sh` builds the `P1`/`P17` panel
  fixture). The rule would call them citations, and creating any unrelated file under `docs/team/reports/` would
  redden a spec that never changed.
- **Forbid the id families in `docs/team/` paths.** The gate's own fixtures build exactly those paths:
  `smoke.sh:10698` creates `docs/team/tasks/P1-a.md`, `:1892` creates `docs/team/reports/P2-closure.md`, and
  `:13816` runs the selector over `docs/team/BOARD.md docs/team/reports/P97-dev3.md` — the same paths the specs
  name. The rule would force renames in the gate and leave the spec describing a fixture that no longer exists.

A declared table keeps the judgment auditable in one place (the `basis` column), makes a *new* reference a
deliberate act, and does not depend on what happens to exist on disk. Its cost is its length: one row per distinct
reference (44 today, 41 rows in the draft at `docs/team/reports/P145-dev2/spec-ledger-refs.draft.tsv`).

**The matcher is part of the rule, and a permissive one is a false green.** The draft's first version let every row
match every reference, so the slot pattern `docs/team/reports/<ID>-*.md` swallowed
`docs/team/reports/P52-dev2.md` and the walk reported 0 undeclared references on a tree that still held all four
citations (evidence: `dryrun.log` §1, first run). The rule is therefore split by reference shape: a slot-shaped
reference (carrying `<…>` or `*`) is allowed only by a `slot` row, and a concrete reference only by an exact
`ledger`/`example` row. With that separation the dry run's red set is exactly the four citations, line for line,
and the four planned rewrites in a scratch copy drive it to zero (`dryrun.log` §1/§2).

### D3 — the walk judges the text the archive will write

At apply time the base specs still hold the citations (they can only leave through the archive), so a walk over
`openspec/specs/**` alone would be red until phase 5 and no apply could deliver a green gate. The walk therefore
builds the **effective text** of every capability: the base spec, plus, for each pending directory under
`openspec/changes/*/specs/<capability>/`, `ADDED` requirements appended, `MODIFIED` requirements substituted by
requirement title, `REMOVED` requirements dropped. Requirements are matched by their title, the one identity the
OpenSpec format guarantees.

Retirement is judged conservatively: a reference found in a base block whose requirement *any* pending change
rewrites is **retired** only when **every** pending version of that requirement drops it; if one pending version
keeps it, the archive could still write it and the walk fails. A retired reference is printed once with the file,
the line and the retiring change id, and does not fail the run. This is the same resolution the gate already uses
for spec-text pins, which resolve "the active change → the archive → the main spec"
(`tests/smoke.sh` §6j, `V94_SPEC`).

*Alternative considered:* two changes — first retire the citations and archive them, then ship the walk, which
would then need no overlay. Rejected: the brief is one change, the overlay is ~40 lines of text handling with no
process to start, and the retirement line is what keeps the walk usable by the *next* change that has to retire
something.

### D4 — the id key is a marker line inside the requirement, not a `Purpose` note

Three carriers were possible and only one survives the process: a `## Purpose` note per spec (not deliverable —
see Context 3), inline glosses at each first occurrence (deliverable, but 135 tokens over six files and ~20
MODIFIED blocks, far past "minimal"), or one line in the added requirement. The line is stated as a contract
marker, the way `修法：` is in the refusal contracts:

```
Id families: `P<n>` a task brief, `M<n>` a milestone, `D<n>` a decision record, `V<n>` a verification pass and
`V<n>-<letter><m>` one of its findings, `E<n>` an exploration report, `F<n>` a finding — the records they name live
outside the distributed tree and are not needed to re-run any scenario.
```

The walk reads the families from that line and refuses a text that uses one it does not name, so the gloss cannot
rot the way a hand-written note would.

### D5 — the four rewrites, and why falsifiability is untouched

| # | requirement (`phase: apply`) | before → after |
|---|---|---|
| 1 | `verification#A fixture observes a data-derived state before it asserts it` | `(the attribution recipe of \`docs/team/reports/P52-dev2.md\` §C measured 0 s green, 6 s red, 6 s + 5× horizon still red)` → `(the attribution recipe: 0 s green, 6 s red, 6 s plus five times the horizon still red)` |
| 2 | same requirement | `or the loaded host on which 4 of 6 runs were red (\`docs/team/reports/P52-dev2.md\`, F2)` → `or the loaded host on which 4 of 6 runs were red` |
| 3 | `verification#A measuring fixture measures a fixed tree, not the caller's worktree` | `measured in \`docs/team/reports/P52-dev2.md\` F4 as 3683 ms from this worktree against 391 ms from a fresh project` → `measured as 3683 ms from a large checkout against 391 ms from a fresh project` |
| 4 | `notify-and-inbox#Messages to a stopped agent fall back to the inbox` | `(the shape of the real frame \`docs/team/reports/P61-dev3/logs/15b-one-line-draft-frame.log\`)` → `(the shape of the captured single-line-draft frame shipped at \`skills/teamsmith/tests/frames/pi-0.87.0-one-line-draft.txt\`)` |

Every number stays in place, every `GIVEN`/`WHEN`/`THEN` line keeps its command and its assertion, and no scenario
loses a failure mode: rewrites 1–3 keep the measurements they quote and only drop the pointer to the record that
holds the recipe; rewrite 4 is a strict improvement — the frame it names is shipped in the public tree and is
byte-identical to the log it used to cite (`cmp` in tasks.md §2.4), so a public reader can now run that scenario
against the real captured shape.

The rewrites were exercised end to end on a scratch copy before this proposal was written
(`docs/team/reports/P145-dev2/trial.sh` / `trial.log`): the generated MODIFIED blocks keep every baseline scenario
(4/4, 2/2, 3/3 — `trial.log` §2), `openspec validate --all --strict` is green with them (§4), dropping one scenario
from a block reddens the same command naming the omitted scenario (§3 — the duty in item 4 of the brief is kept by
the project's own gate), and `openspec archive -y` on the scratch copy applies `+ 1 added, ~ 3 modified` with the
four citations gone from the base specs afterwards (§5–§6). The two blocks are left as drafts in
`docs/team/reports/P145-dev2/deltas/` so the apply starts from text that was already proven.

### D6 — what the walk deliberately does not reach

- `skills/**`: scripts, tests and `references/**` keep their codenames and their fixture names (the brief allows
  it). One shipped-doc instance is the same class as this change's defect — `tests/frames/README.md` cites the
  internal log as its provenance — and it stays: it is the *fixture's* provenance note, it is PM-owned, and it is
  worth a follow-up change if the PM wants the shipped references held to the same rule.
- `openspec/changes/**` (not shipped) and `docs/team/**` (not shipped): no rule.
- The three requirements' text outside the four rewrites: untouched, so the MODIFIED blocks are restatements, not
  edits.

### D7 — the walk's home and shape

`skills/teamsmith/tests/spec-refs.sh` (pure text: no tmux, no process, no network ⇒ it runs in `TEAM_SMOKE_FAST=1`
too), with `--check` (the live run), `--flips` (the two-directional self-test on scratch copies under the owned
tmp family), `--root`/`--table` (the fixture seams) and `--list-declared` (prints the table back, so a reader can
see what the contract is allowed to name). A new gate section runs `--check` and `--flips`; sections are cheap
here — the walk is text-only and the section owes its `section-budgets.tsv` / `section-paths.tsv` rows.

## Risks / Trade-offs

- **The table rots or grows.** Any new undeclared reference is red with file and line, so growth is visible; the
  `basis` column forces the author to argue the row. Accepted cost: a spec that legitimately wants a new slot must
  add a row.
- **A slot row can be too generous.** A reference like `docs/team/reports/P52-<agent>.md` is slot-shaped and would
  pass a `slot` row although it names a real record; no such reference exists today, the table's basis is reviewed,
  and the shape split in D2 is what keeps the common case (a concrete path) honest.
- **The overlay could mask a citation.** It can only mask a reference whose requirement a pending change rewrites
  *and* whose every pending version drops it — and the walk prints every such reference by name, so the archive's
  effect is visible rather than silent.
- **Vacuously green without a ledger.** A product-only checkout has no `docs/team/**` to cite; the walk prints an
  explicit `skip` line naming what it could not judge instead of a silent green.
- **The record-id key is one line for six files.** A reader of `panel/spec.md` will not see the key without
  opening `boundary/spec.md`; the alternative costs ~20 MODIFIED blocks (D4).

## Open Questions

- Does the PM want the same rule extended to the shipped `skills/teamsmith/references/**` and
  `tests/frames/README.md` (D6)? It is a separate change with its own inventory (recon §30).
- The declared table's draft (tasks.md §1.2) classifies `docs/team/PUBLISH.md` as a project-owned ledger
  document and `docs/team/reports/P97-dev3.md` as an example the selector fixture owns; if the PM reads either as
  a citation, they move to the rewrite list instead of the table.
