# Tasks: `panel-board-cards`

Planning only — nothing in this file is executed by the propose task (P121). One apply brief: the sources, the
string tables, the settings model and **the committed `panel.js` must land together**, because (a) the
string-table gate is red while only one table carries a new key and (b) smoke §26-a rebuilds `panel.js` from the
tree's own sources and compares it byte-for-byte, so sources and bundle cannot drift. The pty items need a real
process (private tmux server + the real bundle) and are marked; they are never the only evidence for a
requirement (the FAST pins and the `--snapshot` fixtures carry the cheap half).

Coverage map (requirement → items): **R1** the card's line and the demoted pair (`panel` MODIFIED — the kanban
requirement) → 1.1, 1.2, 2.1; **R2** the lane fold, its default, its persistence and its width share (`panel`
ADDED) → 1.3, 1.4, 2.2, 2.3; **R3** the fold key's click target (`panel` MODIFIED — the mouse requirement) →
2.4, 2.5; the gate/evidence → 3.1–3.4; independent verification → 4.1.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/panel/**` is **PM-owned** and
needs an explicit grant per brief; `skills/teamsmith/tests/**` is `agent:dev`'s; `openspec/changes/panel-board-cards/**`
belongs to the phase's owner; `openspec/specs/**` and `docs/team/**` stay PM-owned. The apply MUST NOT touch the
`board` block reader, `team __panel-data`, any status id, the work page's board block and its done/dropped fold,
the detail view, the settings overlay's five items, or any key binding other than the fold key.

Fixture notes: every fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`) and writes only
inside its scratch repo; the pty scenario uses a private tmux server; the bundle may only be rebuilt with the
pinned bun and must reproduce byte-for-byte.

> **状态（PM，2026-09-29）**：本文件是 P121 的规划稿；已落地并复验的是 **P123**（`docs/team/reviews/P123.md`）——已勾的项就是它落地的部分。**未勾的 6 项**（1.3 折叠形态、2.4 车道头的点击目标、3.3 快照、3.4 六条翻转、4.2 试归档、5.1 复验重跑）由 **P125**（宽度自适应：宽档三列圆角小框 · 窄档原地一行）重做；5.1 在换人复验重跑后由 PM 勾。

## 1. `panel` MODIFIED + ADDED: the sources

- [x] 1.1 `scripts/panel/src/strings/{zh,en}.ts`: add `laneFolded` (`（已折叠）` / ` (folded)`) and `keyFold`
  (`c 折叠` / `c fold`). Verify: `node skills/teamsmith/tests/panel-strings.mjs .` — red while only one table has
  them, green after both do.
- [x] 1.2 `scripts/panel/src/layout.ts`: `cardLine` (`layout.ts:880`) becomes `[cursor] <glyph> <id> <title>` —
  no `card.agent`, no phase token, the title the only truncatable field; `keyBandBlock` (`layout.ts:1841`) gains
  the focused card's pair, right-aligned in the width the chips leave, `dim`, no hit target, built only when the
  chips already fit, and dropping the agent before the phase (design §1). Verify: `--snapshot --page 4` frames
  at 190/160/120/99 columns show the card line without agent/phase and the pair dropping in that order.
- [ ] 1.3 `scripts/panel/src/layout.ts`: the fold branch — a folded lane draws its one line
  (`▸ <label> <count><laneFolded>`), builds no card line, no edge counter and no empty marker, pads its column to
  the lane body's height, and an unfolded lane's header carries the mirror marker (`▾`); the width share follows
  design §2's algorithm (folded line natural width, shown lanes' floor 8, the folded line truncates first). The
  lane order (`LANES`) and every card's row identity are untouched; the folded lane's `LaneWindow` reports
  `visible: 0, count: 0`. Verify: frames with a folded non-empty lane (no card titles, the count on the line),
  a folded empty lane (the default), `boardEmptyFold=0`, and the shown lanes' borders moving apart.
- [x] 1.4 `scripts/panel/src/types.ts` + `settings.ts`: `ViewState` carries the explicit fold state and
  `boardEmptyFold`; `Settings` parses/serializes `boardFold`, `boardShow` and `boardEmptyFold` per design §3
  (unknown lane names dropped, legend order on write, `boardFold` wins a conflict, corrupt file → defaults).
  Verify: a node round-trip over `parsePanelConf`/`serializePanelConf` plus the existing settings tests.
- [x] 1.5 Rebuild `scripts/panel/panel.js` with the pinned bun; a second rebuild is byte-identical. Verify:
  `bash skills/teamsmith/scripts/panel/build.sh` twice and `git diff --exit-code -- skills/teamsmith/scripts/panel/panel.js`,
  plus smoke §26-a's sandbox rebuild.

## 2. `panel` MODIFIED (mouse) + the console's interaction

- [x] 2.1 `scripts/panel/src/App.tsx`: the key-band pair needs no App change (the layout reads the focused row);
  confirm the detail view and the overlay draw no pair. Verify: the frames of 1.2 plus a detail-view frame.
- [x] 2.2 `scripts/panel/src/App.tsx`: `c` on the board page toggles the focused lane's fold and writes the new
  state through `saveSettings` (`App.tsx:739`); `↑`/`↓` leave the focus alone while the focused lane is folded;
  Enter still opens the focused card. Verify: the pty `fold` scenario.
- [x] 2.3 `scripts/panel/src/App.tsx`: the wheel over a folded lane stays that lane's (no page scroll), through
  the `LaneWindow` of 1.3. Verify: the pty `fold` scenario's wheel step.
- [ ] 2.4 `scripts/panel/src/layout.ts` + `App.tsx`: the lane header line (both states) carries the
  `{kind:'lane-fold', lane}` action; the App dispatches it like `c` for that lane and its wheel branch accepts
  `lane-fold` as the lane's region. Verify: the pty `fold` scenario's click step and the `28-h` target map.
- [x] 2.5 The `c 折叠` chip is pushed in the board page's nav chips after `↑/↓ 卡片`; the target map carries it.
  Verify: `28-h`'s band assertion and the target-map walk.

## 3. Tests, snapshots, the gate, the report

- [x] 3.1 `skills/teamsmith/tests/smoke.sh` (`28-h` family + FAST pins): the card-line pin (no agent/phase
  segment in `cardLine`), the fold short-circuit pin, the band pair's ladder assertions, the empty-lane default
  and `boardEmptyFold=0` frames, the settings round-trip pin, the `c` chip and its target; each pin must be shown
  red by removing its subject. Verify: the FAST tail plus each pin's red/green pair.
- [x] 3.2 `skills/teamsmith/tests/panel-b3.sh` (pty, **real process**): a `fold` scenario — `c` folds the
  focused lane (its cards gone, the count on the line), the cursor stays on the folded line and `↑`/`↓` do not
  move it, `c` again restores the card with the cursor on it, a click on the lane header toggles it, the `c 折叠`
  chip toggles the focused lane, the wheel over the folded line does not scroll the page, and a quit+relaunch
  keeps the state (the empty lane's explicit unfold sticks too). Verify:
  `bash skills/teamsmith/tests/panel-b3.sh fold` (slow batch).
- [ ] 3.3 `skills/teamsmith/tests/panel-snapshots.sh`: re-pin the `*-p4.txt` snapshots (the card line and the
  empty-lane default change them) and add one pinned folded-lane frame; the p1/`-detail` pins stay byte-identical.
  Verify: `bash skills/teamsmith/tests/panel-snapshots.sh` green with the new pins, and `git diff` showing only
  the intended `*-p4.txt` files plus the new one.
- [ ] 3.4 The flips of design §5, each with its red and green tail: (1) fold short-circuit removed, (2) the agent
  back on the card line, (3) `--print` reading the fold keys, (4) the empty default off, (5) the width re-share
  dropped, (6) the toggle without `saveSettings`.

## 4. Gate, trial archive, evidence

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** smoke and the pty batch
  once — paste the tails; `git status --porcelain` clean.
- [ ] 4.2 Trial archive on a scratch copy (`cp -r openspec /tmp/panel-board-cards-trial && (cd /tmp/panel-board-cards-trial
  && PATH="$HOME/.bun/bin:$PATH" openspec archive -y panel-board-cards)`) — proves the MODIFIED blocks keep every
  base scenario and merge without a collision with whatever changes are in flight at apply time.
- [x] 4.3 The report's evidence: the delta→requirement map for `panel`, the requirement→item and
  scenario→fixture maps, every flip's tails, the `*-p4` re-pin diff and the untouched p1 pins, the byte-identical
  bundle rebuild, and one line stating the `board` block, `team __panel-data`, the machine exits and every
  existing key binding other than the fold key were not touched.

## 5. V — independent verification (a different agent)

- [ ] 5.1 Rerun, out of tree and on the apply's tip: every flip of 3.4 (red and green), the pty `fold` scenario,
  the snapshot suite, `openspec validate --all --strict` and the **full** smoke; the record goes to
  `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings is rework, not archive).
