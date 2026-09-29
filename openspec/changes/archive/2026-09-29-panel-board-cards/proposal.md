# panel-board-cards · proposal

## Why

At 190 columns the board page is unreadable: each lane is ~30 columns, and the card line
(`glyph + id + agent + phase + title`) spends ~19 of 26 inner columns before the title — the field that names
the work — leaving it ~7. The user, with a screenshot (2026-09-29):

> 「…隐藏所派遣的 agent 名字，只显示任务序号和标题…以及允许折叠整个看板，例如空的看板（如待复验）和不关心的？」

The six lanes also split the width evenly and box every lane, so an empty lane costs a sixth of the board for
nothing.

## What Changes

- **MODIFIED — `panel`** (*The board page is a kanban over the board's states*): a card's line becomes
  `cursor + glyph + id + title`; the agent and phase leave the card — the **focused card's** pair renders in the
  key band's free width, dropping the agent before the phase, so no width exists at which a card truncates its
  title to keep them.
- **ADDED — `panel`** (*A lane folds from its header, and empty lanes fold by default*): a lane folds to one line
  (`▸ 完成 236（已折叠）`) — no card rows, counters or empty marker — and the unfolded lanes share the width the
  folded lines do not use. Empty lanes fold by default; explicit state persists in `state/panel.conf`
  (`boardFold` / `boardShow`, `boardEmptyFold` turns the default off). A folded lane builds no card line, so the
  bounded-frame promise holds.
- **MODIFIED — `panel`** (*Every key affordance is also a mouse target*): `c` joins the documented keys; a click
  on a lane's header line toggles that lane, and the wheel over a folded lane never reaches the page.

## Capabilities

### Modified Capabilities

- `panel`: the card's line and the agent/phase demotion; the fold key and its click target.

## Impact

`scripts/panel/src/{layout,App,settings,types}.ts`, `src/strings/{zh,en}.ts`, the rebuilt `panel.js`;
`tests/{panel-strings.mjs,smoke.sh,panel-b3.sh,panel-snapshots.sh}` and the `*-p4.txt` pins. Untouched:
`team __panel-data`, status ids, the machine exits, the work page's board block, the detail view, the overlay's
five items, every other key.

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
```

(Propose: the delta validates with complete scenarios; the apply's gate adds the FAST smoke.)

## What flips

Fold a lane → its cards vanish and the count stays; removing the fold short-circuit renders them again → red. A
card line carries no agent/phase; putting the agent back reddens the card-line pin and the `*-p4` pins, and
making `--print` read the fold keys reddens the machine-frame identity check.

## Boundaries

Planning only: this task writes `openspec/changes/panel-board-cards/**` and the report. Apply paths need the
brief's grant (`scripts/panel/**` is PM-owned, `tests/**` is `agent:dev`'s). Out of scope: the `board` block,
status ids, the work page's board block, the detail view, the overlay's item count, any other key.

## Evidence the report must contain

Propose: the validate tail, the delta→requirement map, the scenario inventory, the trade-off rulings. Apply:
the gate/FAST tails, the `*-p4` re-pin with the p1 pins untouched, the pty fold/restart frames, every flip's
tail, the byte-identical rebuild, the untouched-contract statement.
