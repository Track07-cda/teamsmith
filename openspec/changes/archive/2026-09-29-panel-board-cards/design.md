# panel-board-cards · design

Status: propose phase (planning only — no `skills/**` change in this task). Everything below was read off the
tree at this branch's base; the file paths and line numbers are the ones a reader can re-check (`git grep`).

## 0. The problem, stated precisely

The board page is `kanbanBlock` (`skills/teamsmith/scripts/panel/src/layout.ts:1033`): six lanes from BOARD.md's
legend, side by side at ≥100 columns with `laneW = max(8, floor((width - 5) / 6))`, one card line per row built
by `cardLine` (`layout.ts:880`), each lane a boxed column (`laneColumn`, `layout.ts:920`).

At the reported geometry (190 columns) the lane is 30 wide and the card's inner width is 26. The current line
spends `cursor 2 + glyph 2 + id+space 4 + agent+space 5 + phase+space 6 = 19` columns before the title, leaving
**7** — the screenshot's `审计日…`. The user's two asks (verbatim in the proposal) are:

1. hide the dispatched agent, keep the **id and the title**, and
2. let a lane be folded — above all the empty ones (`待复验 0`, `阻塞 0`) and the ones the human does not care
   about.

The second problem is in the same function: `laneW` is one number for all six lanes and an empty lane draws a
box with a dim `·`, so an empty lane holds 30 columns and a full-height column for nothing.

This change touches neither the data nor the contracts: `team __panel-data --block board` and its `rows[]`
(id, title, agent, branch, deps, state, phase) stay exactly as they are; the change is `layout()` plus the view
state the console keeps for itself (`state/panel.conf`, `ViewState` in `types.ts:567`).

## 1. The card line, and where the agent/phase go — three trade-offs

The card's line becomes `[cursor] <glyph> <id> <title>`: cursor 2 + glyph 2 + id+space 4 = **8** columns, so the
title gets 18 of the 26 (was 7). The removed fields must go somewhere; the options weighed:

| # | Option | Cost | What it gives | Verdict |
|---|---|---|---|---|
| (a) | The **focused** card's `agent · phase` in the key band's free width | one line that already exists; only the focused card's pair is visible | zero rows, full title everywhere, no new preference, density unchanged | **chosen** |
| (b) | A **second card line** when the lane is wide enough (`agent · phase` under the title) | each card costs two rows, so every lane window halves; the lane window, edge counters, focus walk and hit map all become two-row | metadata always visible on wide lanes | rejected |
| (c) | A **settings toggle** (`title only` / `full line`) | a sixth overlay item (the settings requirement says "exactly five"); the default still has to be chosen; the ladder stays unspecified | the human can opt into the old line | rejected |

Why (a): it is the only option that both hides the agent (the literal ask) and keeps one row per card — the
`done` lane holds 236 cards and the lane window's price is the change's biggest regression risk. (b) answers the
opposite question ("keep the metadata") at the cost the user did not ask to pay. (c) cannot fix the *default*,
which is the complaint, and it would change an existing contract (the overlay's item count) for a rendering
preference the user has not asked to tune.

The demoted pair, concretely:

- **Placement**: the key band (`keyBandBlock`, `layout.ts:1841`) is the footer line the board page already
  draws. The pair renders right-aligned in the free width the band's own chips leave, in the `dim` tone, with
  the same `›` cursor glyph that marks the focused card (`› P77 · dev2 · apply`). It gets **no hit target**: it
  is data, not an affordance, and `placedWithHits` must not be asked to carry it.
- **The drop order**: built only when the chips already laid out fit; then, from the remaining width, the band
  renders `agent · phase` if it fits, else `phase` alone (the agent drops first), else nothing. The band's
  documented chips are laid out first and are never pushed out — the pair is spent from what is left.
- **Tiers**: at 190/160 columns the pair fits after the nav chips; at ~120 it may fit in reduced form; under
  100 the chips alone fill the band, so the pair is absent — which is exactly the ladder's last rung, not an
  exception to it.
- **The placeholder**: an entry with no brief or no `phase:` line shows the `-` placeholder in the pair (the
  `board` reader keeps returning `-`); nothing about the pair is written to the `board` block.

### The degradation order, stated once

`agent → phase → title truncation`:

1. as the surface that carries the pair narrows, the **agent** drops first (the pair becomes `phase` alone);
2. then the **phase** drops (the pair disappears);
3. only the card's own line truncates the **title**, and it is the line's only truncatable field — no width
   exists at which a card truncates its title while still showing an agent or a phase, because the card line
   starts at the title (this is the user's complaint, turned into an invariant).

The ladder is observable at three places: the band's pair content at a given width (scenario "The demoted pair
drops the agent before the phase"), the card line never carrying `agent`/`phase` (scenario "A card carries id,
agent, phase and title", plus the FAST pin), and the 59-column frame keeping the id and truncating the title
(scenario "Narrow terminals degrade to one grouped column").

## 2. The fold — three trade-offs

| # | Option | Cost | What it gives | Verdict |
|---|---|---|---|---|
| F1 | **In place, width re-shared**: the folded lane's column keeps its position, narrows to the line's width, draws one line and blank rows below; the unfolded lanes share the rest | a reflow of x-positions on toggle (hit maps are per-frame, so nothing stale); blank area under a folded line | answers both complaints (vertical noise, width occupation) and keeps one uniform rule for the wide and grouped tiers | **chosen** |
| F2 | **A folded strip above the lane row** (folded lanes stack as full-width lines, unfolded lanes split the full width) | a new region in the vertical budget; one lane set rendered in two places; the all-folded shape is a second layout | the most width freed | rejected |
| F3 | **Equal-width columns, one-line header only** | nothing moves | minimal diff | rejected: the empty lane's 30 columns stay occupied — half the complaint stands |

F1's folded lane, concretely:

- **The line**: one line, `<fold triangle> <label> <count><folded suffix>` — e.g. `▸ 完成 236（已折叠）` /
  `▸ done 236 (folded)`. The triangle (`▸`) is the layout's literal (like `›`, `·` and the state glyphs); the
  suffix comes from the string tables (`laneFolded`); so the state is a **glyph plus a text token**, never colour
  alone. An unfolded lane's header (`cardTop`, `layout.ts:146`) gains the mirror marker (`▾ 待办 1`) so the
  toggle is visible in both states.
- **No card rows are built**: the fold branch returns before the window loop, so no `cardLine` call runs for the
  lane's cards; the count comes from the lane's card list, which the frame already filters once. The P18/V18
  bounded-frame promise is untouched — folded lanes can only make a frame cheaper.
- **No window, no counters**: a folded lane contributes no edge counters and no hit targets for cards, and its
  `LaneWindow` record reports `visible: 0, count: 0`, so the App's `scrollLane` (`App.tsx:828`) has nothing to
  scroll (the wheel over the folded line stays that lane's — it must not fall through to the page).
- **The column keeps the lane body's height**: one line at the top, blank rows below, so the frame's height
  does not shrink and the footer stays the frame's last row even when every lane folds (the bounded-frame
  requirement's filler order does not change: the blank stays inside the lane area).
- **Fixed order**: the lane's index in `LANES` (`layout.ts:738`) is untouched, so folding never reorders the
  board and `←`/`→` keep walking the legend order.

### The width algorithm (the folded lane's "documented floor")

```
usable   = width - LANE_GAP * (LANES.length - 1)
folded   = the lanes whose fold resolves true; shown = the rest
if shown is empty:
    every folded line gets floor(usable / folded) columns (truncating as needed)
else:
    floor_shown = 8                       # the existing lane floor (Math.max(8, …))
    pool        = usable - floor_shown * |shown|
    w_folded    = min(natural_width(line), max(4, floor(pool / |folded|)))
    w_shown     = floor((usable - Σ w_folded) / |shown|)
```

*Folding degenerates before the cards do*: the folded line truncates to make room for the shown lanes' floor,
never the other way around. `natural_width` is the folded line's display width (label + count + suffix).

### Focus, keys and the mouse on a folded lane

- **The focus never moves on a toggle.** The focus is a card reference (`{lane, id, nth}`); folding only changes
  what is drawn. When the focused card lives in a folded lane the lane's one line carries the cursor glyph and
  the `selected` tone — exactly one cursor in the frame, as the existing requirement demands.
- `←`/`→` are unchanged: they walk the lanes that hold cards (`moveFocus`, `App.tsx:772`), and a folded lane
  still holds cards, so it stays a stop and the user can fold and unfold any lane from the keyboard.
- `↑`/`↓` **do not move the focus while the focused lane is folded**: the lane draws one row, so a silent move
  to a hidden card would be an invisible state change. (Alternative considered: walking the hidden cards — the
  frame cannot show which one is focused, so the cursor would lie. Rejected.)
- `Enter` still opens the focused card's detail view (the focus is a real card; the detail view is read-only).
- **Key**: `c` toggles the focused lane's fold. Candidates and why: `Enter` opens a card (taken); `Space` is the
  settings overlay's accept key and the compose editor's character (the brief rules it out); `z` is ruled out by
  the brief; `c` is the close-fold mnemonic from the editor vocabulary the console already borrows from, and it
  appears in **no** binding on any page in normal mode (`m f s r q , Tab 1-4 ↑ ↓ ← → Enter pageUp pageDown` are
  the whole map). It is ignored while the detail view or the overlay owns the page region, and while `busy`.
- **Chip**: `c 折叠` / `c fold` joins the board page's nav chips in `keyBandBlock`, after `↑/↓ 卡片` and before
  `Enter 打开`; it is a target like every other chip.
- **Click**: a lane's header line — an unfolded lane's top border **or** a folded lane's single line — carries
  the `{kind:'lane-fold', lane}` action: a click toggles that lane, the same frame change `c` produces for the
  lane it names. The App's wheel branch must treat `lane-fold` as that lane's region (today it accepts
  `lane-scroll`/`focus`/`open-focused`), so the wheel over a header still scrolls its lane and never the page.
- The folded line is one row, so a click on it cannot be anything else; a click on a card below it is unchanged.

## 3. Persistence — the model

`state/panel.conf` is the console's own runtime state (`settings.ts`). The change adds three keys and no overlay
item (the `theme` precedent; the settings requirement's "exactly five preferences" is not modified):

| key | value | meaning |
|---|---|---|
| `boardFold` | comma list of lane names | lanes folded explicitly |
| `boardShow` | comma list of lane names | lanes kept unfolded explicitly |
| `boardEmptyFold` | `0`/`1`, default `1` | the empty-lane default |

Rules (small enough to state, precise enough to test):

- Unknown lane names are dropped; duplicates dedupe; both lists are written in the `LANES` legend order; a lane
  in both lists **folds** (`boardFold` wins — the explicit hide is the stronger statement).
- Effective state: `explicit fold` → folded; else `explicit show` → unfolded; else `empty(lane) && boardEmptyFold`
  → folded; else unfolded.
- A lane the **default** folded unfolds by itself as soon as it holds a card (the default is recomputed per
  frame); an **explicit** state survives emptiness and restarts.
- A toggle writes the file immediately (the same `saveSettings` path `cyclePref` uses, `App.tsx:739`).
- A missing or corrupt file falls back to the defaults, exactly as the settings requirement already rules.
- `--print`/`--json` MUST NOT read these keys (the settings requirement's existing rule): the machine frame
  renders the **default** fold state — empty lanes folded, `boardEmptyFold`'s default — and two `panel.conf`
  fold states therefore print byte-identically. `--snapshot` is the TUI's own render path and does read them
  (the `defaultPage` path already does), which is what lets the fixtures pin the fold state without a pty.

## 4. Interaction with the existing contracts

- **`board-and-status` / `board` block**: untouched. The fold and the demotion are renderings of the same rows;
  `team __panel-data --block board` and `team monitor --json` gain no key.
- **Status ids and semantics**: untouched — no new state, no `BOARD.md` change.
- **Bounded frames**: the folded column pads to the lane body's height; the grouped tier's page window indexes
  over the drawn lines, so a folded lane costs one index. No new frame row is added anywhere.
- **Colour alone**: the fold marker is a triangle **and** the `（已折叠）` text; the focus is the `›` glyph **and**
  the `selected` tone — both already the console's rule.
- **i18n**: new keys (`laneFolded`, `keyFold`) in **both** `zh.ts` and `en.ts`; `panel-strings.mjs` asserts the key
  sets are equal, so the change cannot land half-translated. No CJK is introduced into `layout.ts`: the suffix
  and the chip are table values; the triangle is a glyph like the existing ones.
- **The mouse requirement**: `c` joins the documented keys, the header is its target; the folded line keeps the
  lane's wheel region.
- **The work page's board block and its `… 其余 n 条 done/dropped 收起` fold**: a different mechanism on a
  different page; untouched.
- **The detail view and the settings overlay**: the `c` key is ignored while either owns the page region, and
  the pair is not drawn in the detail view (no kanban on screen).
- **The committed bundle**: `panel.js` is rebuilt with the pinned bun and must reproduce byte-for-byte
  (`build.sh` + a second run; smoke §26-a rebuilds it in a sandbox).

## 5. Test strategy and the flips

- **FAST structural pins** (`skills/teamsmith/tests/smoke.sh`, the `28-h` family): `cardLine` builds no
  agent/phase segment; the fold branch in `laneColumn`/`kanbanBlock` returns before the card loop; the settings
  round-trip carries the three keys; the band chip `c 折叠` is present and in the target map.
- **Frame fixtures** (`--snapshot` + the pty scenarios): fold/unfold frames and the count; the empty default and
  `boardEmptyFold=0`; the restart persistence; the cursor on the folded line and `↑`/`↓` no-op; the width growth;
  the machine-frame identity; the band pair's ladder; the `*-p4.txt` snapshots re-pinned (the p1 pins unchanged).
- **Flips the apply must show red→green**:
  1. remove the fold short-circuit → the folded lane renders cards again (frame assertion red);
  2. put the agent back on the card line → the card-line pin and the `*-p4` snapshots red;
  3. read the fold keys in `--print` → the two `panel.conf` prints differ (identity assertion red);
  4. default `boardEmptyFold` off → the empty-lane scenario red;
  5. drop the width re-share → the lane borders do not move (width scenario red);
  6. drop the `saveSettings` call on toggle → the restart scenario red.

## 6. Decisions and the judgement calls left visible

- **D1** Card line = cursor + state glyph + id + title; agent/phase never on a card line.
- **D2** The pair rides the key band's free width, right-aligned, `dim`, no hit target.
- **D3** Degradation order agent → phase → title truncation, with the pair's drop computed from the chips' left-over width.
- **D4** Fold renders in place: one line, no cards/counters/window, the column keeps the lane body's height.
- **D5** Folded lanes take the width their line needs; the shown lanes share the rest; the folded line truncates first.
- **D6** The toggle never moves the focus; the folded line carries the cursor; `↑`/`↓` no-op while folded.
- **D7** `c` is the fold key (Enter/Space/`z` ruled out); the chip and the header click are its targets.
- **D8** `boardFold` / `boardShow` / `boardEmptyFold` in `state/panel.conf`; defaults recomputed per frame;
  explicit state persists; `--print`/`--json` ignore the keys.
- **D9** Two judgement calls the brief leaves to this proposal, recorded rather than hidden: the **width
  re-share** (F1 over F3 — it answers the 现场's "空车道也占位", and it is the part of F1 the apply can test
  cheaply by measuring the lane borders) and **`c`** as the key (the brief excludes Enter/Space/`z`; `c` is
  unclaimed on every page and matches the fold-close mnemonic). If the PM prefers an equal-width fold, F3 is a
  strictly smaller edit and the ADDED requirement's width paragraph is the only block that changes.
