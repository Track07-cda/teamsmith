# fixture-waits-for-landed-reads · design

Status: propose phase (planning only — no `skills/**` change in this task). Every number below was measured
before this task; the raw logs live in `docs/team/reports/P52-dev2.md` (P52) and the verdicts in `DECISIONS.md`
D43/D44. Nothing here is a requirement; the normative text is the delta
`specs/verification/spec.md` in this change.

## 1. The measured scene

### 1.1 `panel-p21.sh`: the picker is a snapshot, the read is asynchronous

The chain (P52 §C, D43), read in the sources and reproduced by injection:

1. `skills/teamsmith/scripts/panel/src/main.tsx:792` — opening the settings view issues a **forced read** of the
   settings block (`cache.refresh({force:true, only:['settings']}).then(adopt)`); the view paints before it lands
   (P52 cited `main.tsx:788-793` on its revision).
2. `skills/teamsmith/scripts/panel/src/App.tsx:1211` (`openSettingsRow`) — the picker's entries are built **once**
   from the settings state on screen when the picker opens (`dataRef.current.blocks?.settings`); a later `adopt`
   does not rebuild them (M65/D11, and D43 keeps this; P52 cited `App.tsx:1251-1258` on its revision).
3. `tests/panel-p21.sh` — the hand-edited-value scenario writes `TEAM_NOTIFY_TMUX=true` into the contract,
   `reopen_view` (whose marker is the first functional **group heading**, i.e. a frame the skeleton alone can
   produce), then filters to the row, sleeps a fixed `0.5 s`, presses Enter and waits for the picker entry
   `true · 当前` (the source line is quoted in P52 §C).

So the wait can be perfectly patient and still fail: the picker was formed from the pre-read state. Measured:

| run | result |
|---|---|
| injection 0 s | `✓ 110 ✗ 0` |
| injection 2 s | `✓ 110 ✗ 1` |
| injection 3 s | `✓ 106 ✗ 7` |
| injection 6 s | `✓ 104 ✗ 9` (the three bool assertions) |
| injection 6 s + 200-round horizon | `rc=1`, that wait `200/200` ≈ 75 s, still `缺 [true · 当前]` |
| 2-CPU quota (`cpu.max=200000 100000`), 5/5 runs | `✓ 108 ✗ 3` — `非规范 bool 的选择器没有打开`, `非规范拼写的手改值原样显示成当前条目`, `非规范拼写不许被贴成规范值的标签` |

The last row is the CI shape; **enlarging the horizon is not the fix** (the picker never rebuilds). What is
missing is a wait for the **derived state itself** (the row carrying the new value) *before* Enter opens the
picker.

### 1.2 `panel-b3.sh` `collapse`: one sample after a fixed delay

`scn_collapse` (`tests/panel-b3.sh`, the scene quoted in P52 F2) starts `team pulse up` in the private session,
`sleep 5`, takes **one** `capture-pane` into `console.txt` and asserts `teamsmith pulse` (the console's own
title); after `q` it `sleep 3`/`sleep 5`/`sleep 6` and takes single captures again for the restore and for
`up.log`/`capacity.log`. On a loaded host the panel's first frame lands after that window, so the sample is a
skeleton/blank pane:

```
✗ pulse 窗口里是控制台（…/collapse/console.txt 里找不到 [teamsmith pulse]）
✗ 恢复后同一窗口里又是控制台（…/collapse/restored.txt 里找不到 [teamsmith pulse]）
```

P52 measured **4 red of 6 runs**, on the two different waits, with the same fixture otherwise unchanged. The
scene is the same shape as 1.1: the assertion reads a state the console derives asynchronously, and the fixed
delay + single sample is the only evidence.

### 1.3 `panel-cpu.sh`: the measurement target is the caller

`tests/panel-cpu.sh` defaults its tree to `$(cd -P "$here/../../.." && pwd)` — the checkout it was invoked from —
and runs the panel against that root. The console's first frame depends on that project's **data volume**, so the
number describes the checkout, not the console: P52 F4 measured `first_frame=3683 ms` from this worktree against
`391 ms` from a fresh project with the same bundle, the first past the fixture's ~3 s polling budget → `rc=2`
while the pane CPU stayed at 0.60 %. `perf.sh --tree` and `panel-cpu-premise.sh` propagate the same choice, so
two worktrees can reach two different conclusions for the same code and the same machine.

## 2. The rule, and what it is not

**The rule** (normative in the delta): a fixture's data-derived assertion must observe the state it asserts, on a
settled frame, with a bounded and attributed wait; the evidence must not be a skeleton marker or an unconditional
fixed delay plus one sample.

**Not a horizon enlargement.** 1.1's `200/200` run is the proof: a bigger budget does not make a snapshot
rebuild. The wait changes **what** is observed, not only **how long**.

**Not a performance judgment (D33).** The caps are liveness bounds with a measured basis, exactly like the
gate's section budgets: a read that lands slowly inside the bound must stay green, and nothing may fail because a
correct read was slow. The delay injections of §3 D2 are the falsification of "the wait is too short", never a
new red line.

**Not a product change (D43).** The picker keeps its snapshot semantics and no "read landed" signal is added to
the console; the fixture waits for what the user would see.

**Not the wait-cap requirement.** `verification#Every wait in the gate is bounded and attributes at its cap`
(`gate-section-accounting`, not yet archived) owns counted rounds, the cap, the attribution line and the loop
inventory. This change owns **which state the evidence is about**; the new waits reuse that discipline and
restate none of it, and no existing wait's cap is relaxed.

**Not input rhythm.** A delay between keystrokes (the `sleep 0.3/0.4/0.5` cadence in the pty fixtures) paces
input and is not evidence of anything; the requirement governs delays (and skeleton frames) used as the evidence
that data landed. The census in D6 is what keeps that distinction honest.

## 3. Decisions

### D1 — the wait's shape: a data-derived predicate on a settled frame, inside the existing engine

The new waits are conditions over what the fixture can already capture: the settings row carrying the
hand-edited value before Enter opens the picker; the console title `teamsmith pulse` present on a settled frame;
`pulse up`'s log naming the window; `capacity.log`'s row count having grown. `panel-p21.sh` already consumes the
pty engine (`pty_wait_frame` from `tests/lib/pty-wait.sh`, settled frames, the premise rule); `panel-b3.sh`
captures with a bare `tmux capture-pane` today and has no engine — the apply may source the same library or add a
small local bounded-capture helper, but either way the wait must count rounds, carry a cap, print one attribution
line naming the wait and the state it waited for, and be visible to the gate's loop inventory. A cap that is
satisfied by a **skeleton frame** is not a wait (that is the bug being fixed).

### D2 — the red sides are deterministic injections, not machine luck

Three recipes, all used in P52's evidence and re-runnable by the PM:

| # | case | injection | red side |
|---|---|---|---|
| A | settings read | a scratch copy of `panel-p21.sh` whose generated CLI wrapper sleeps before `__panel-data --block settings` (the wrapper is `tests/panel-p21.sh`'s own `$tmp/<name>-wrapper.sh`; `P21_CLI` is the seam) | pre-change: `✓ 108 ✗ 3` / 6 s → `rc=1`; post-change: green after the read lands, and an over-cap delay names the wait |
| B | console first frame | a scratch bundle run through `TEAM_B3_PANEL` that delays its first paint, or the loaded-host run of P52 F2 | pre-change: `console.txt`/`restored.txt` miss `teamsmith pulse` (4/6); post-change: green inside the bound, attributed at the cap when the title never comes |
| C | measurement target | the same `panel-cpu.sh` invoked from this worktree and from a fresh project | pre-change: `3683 ms` vs `391 ms`, one `rc=2`; post-change: one printed root, one conclusion |

The red sides must be produced on a tree whose sources are the pre-change ones (a scratch copy), so the flip is
"same injection, old shape red / new shape green" and not a load coincidence.

### D3 — `panel-cpu.sh` measures a fixed neutral project; the bundle stays the revision under test

The measured root becomes a neutral reference project the fixture fixes itself (a fresh `team init`-sized
project, created through `tests/lib/tmp-root.sh`'s owned family), while the console bundle and CLI stay the ones
from the tree under test (`--tree` keeps naming the code under test, and it is printed). That keeps the number
about the console and makes two worktrees comparable; the perf suite's environment self-description keeps naming
the revision under test, as its requirement already says. The premise fixture drives the same shape, so its four
expected exit codes keep working against a fixed root.

### D4 — ADDED deltas only: no base rewrite, no D40 collision

`verification#The correctness gate judges correctness only` is currently the target of two unarchived MODIFIED
deltas (`pty-fixture-load-premise`, `gate-section-accounting`), and `gate-section-accounting`'s design D7 records
the consequence: whichever archives first, the other's delta must be rewritten against the new base. This change
therefore **adds** two requirements and modifies nothing; it does not need a base rewrite and cannot invalidate
another change's MODIFIED scenarios. The archive step still runs the trial archive on a scratch copy
(`mkdir -p /tmp/p62-trial && cp -r openspec /tmp/p62-trial/openspec && (cd /tmp/p62-trial && openspec archive -y
fixture-waits-for-landed-reads)`), which is the integration check that the two ADDED names collide with nothing
in the base or in an open change. **Measured in this task**: `+ 2 added, ~ 0, - 0`, and the 24 remaining items
still pass `openspec validate --all --strict`. The copy must land in a directory *named* `openspec` — the CLI
resolves the nearest ancestor containing `openspec/`, so `references/openspec.md` §5's shorter form works only
when the target directory already exists (PM-owned doc; reported, not changed here).

### D5 — the bounds carry their measured band

Every new wait's cap is recorded where the fixture lives, next to the band it was derived from: the apply records
the settings-read latency band it measured (P52's injection rows are the starting band: 0/2/3/6 s, with the
natural read sub-second) and the console-first-frame band, and picks a cap **above** the band's slow end plus the
extension the engine already allows. A cap tightened below the recorded band is a false red and is the thing the
verify step must be able to break (D2's recipes are how).

### D6 — a bounded census, and a reported residual

The apply classifies every `sleep N` followed by a single sample **in the three fixtures this change touches**
(`panel-p21.sh`, `panel-b3.sh`, `panel-cpu.sh`) as input rhythm or as evidence, and converts the evidence ones.
Same-shape waits found in other fixtures are written into the report as findings with their file:line for the PM
to schedule — not silently fixed (scope) and not silently dropped (truth). The census table is part of the apply's
report.

## 4. Relations to the open changes

| change | relation |
|---|---|
| `pty-fixture-load-premise` (P48/P52) | its premise/extension owns *what a horizon's exhaustion means*; this change owns *what the assertion waited for*. The new waits reuse its attribution; no constant of it is changed. No shared delta: it MODIFIES the base requirement, this change ADDs. |
| `gate-section-accounting` (P56) | its *Every wait in the gate is bounded and attributes at its cap* is the discipline the new waits follow; the census D6 feeds the same inventory, and no cap it recorded moves. Per its D7, this change adds no third MODIFIED delta for the base requirement. |
| `test-tmp-hygiene` (P53/P58) | the neutral project of D3 is created through the owned temp-root helper that change introduces; the fixture keeps its `BASHPID`-guarded cleanup and its private tmux socket. |
| `trust-prompt-and-fixtures` (P57/P59) | shares only the pty fixtures' isolation rules; this change adds no new pane-level interaction and no overlay judgement. |

## 5. How each requirement is reviewed

| requirement | scenario | review recipe (independent of the implementer's tests) |
|---|---|---|
| A fixture observes a data-derived state before it asserts it | the delayed read is observed / the old shape reds | recipe A (D2): scratch `panel-p21.sh` + sleeping wrapper, `choices` on both trees; the pre-change red and the post-change green on one screen |
| | data that never lands | the same scratch wrapper with a delay past the cap: the attribution line names the wait and the expected state; exit is not 0 and not green; on an over-premise machine it is the visible `SKIP` |
| | the collapse scene | recipe B: `TEAM_B3_PANEL=<scratch delayed bundle> bash skills/teamsmith/tests/panel-b3.sh collapse`, pre/post |
| | no duration judgement | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` + `bash skills/teamsmith/tests/gate-guard.sh`; the new bounds are read in the sources with their bands, and the delay injection inside the band stays green |
| A measuring fixture measures a fixed tree | two worktrees | recipe C: run `panel-cpu.sh` from this worktree and from a fresh project; compare the printed roots and the verdicts |
| | the names are printed | the same two runs: the measured root and the bundle path are in the output |

## 6. Residuals

- **A read that lands after the cap** is not observed by construction: the run takes the premise decision
  (failure on a static scene under the premise, visible `SKIP` over it). The attribution line is what keeps that
  honest; the cap must be wide enough for the recorded band (D5), not for every stall.
- **`panel-p21 choices` under the 2-CPU quota** is the shape that must go green: an apply that only widens a
  horizon (rather than waiting for the value) has not fixed it, and the delay injection (§1.1) is the check that
  separates the two.
- **The census (D6)** can find same-shape waits outside the three files; they become findings, not silent
  scope.

## 7. Paths and ownership for the apply

`skills/teamsmith/tests/**` is `agent:dev`'s (OWNERSHIP), so the apply needs no PM grant for
`panel-p21.sh`, `panel-b3.sh`, `panel-cpu.sh`, `panel-cpu-premise.sh`, `perf.sh` or `lib/pty-wait.sh`. Two
caveats the brief must state: `skills/teamsmith/tests/smoke.sh` is the **gate file** and is touched only if a
FAST-able pin is added (then it needs the brief's explicit grant), and `skills/teamsmith/scripts/**` (the console
sources) is **not** touched at all — D43 keeps the product side as it is.
