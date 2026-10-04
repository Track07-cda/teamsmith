# P19 report — propose: `panel-ergonomics` (pi-style compose line, clipboard images, work-page detail entry, `线程` → `往来记录`)

**Phase**: propose · **Agent**: dev-bob · **Branch**: `task/P19-propose` (local; not pushed — local mode) ·
**Date**: 2026-09-19 · **Tip**: `9d14d68` (acceptance re-run on it; the report/evidence commits follow)

## Deliverable

`openspec/changes/panel-ergonomics/` — four planning artifacts, planning only, no code. `openspec status`:
**4/4 complete**; `openspec list`: `panel-ergonomics  0/38 tasks`.

- `proposal.md` — why / what changes / capabilities / impact / verbatim acceptance / boundaries (499 words, under
  the schema's 500-word rule).
- `specs/panel/spec.md` — delta: **ADDED ×6, MODIFIED ×5**.
- `specs/memory-and-deps/spec.md` — delta: **MODIFIED ×1** (the ledger's Chinese label).
- `design.md` — 11 decisions with alternatives and pi's own source as evidence, 9 risks with mitigations, a
  six-batch migration plan with per-batch rollback, no open questions.
- `tasks.md` — six apply briefs with headless siblings, flips and the requirement → item coverage map.

The requirement/scenario shape (matching the PM's "one requirement, one behaviour topic" rule): cursor editing;
pi's key map; the kill ring and undo; multi-line editing; the clipboard paste; the work page's rows and detail
entry — plus MODIFIED write (`C-e` → `C-o`), mouse, read-only, string tables and detail requirements.

Commits: `8b462fa` (rename + proposal), `25a4aab` (delta specs), `7781748` (design), `aaf6782` (tasks),
`9d14d68` (the renamed-away paths removed so exactly one change exists), then the report commit.

## The brief's asks → where they are answered

| Brief item | Where |
|---|---|
| Cursor model: codepoint index, insert/delete at the point, ←/→/Home/End, the cursor column under soft and explicit wrapping agreeing with `tmux display -p '#{cursor_x}'`, commit/paste/reject paths unchanged | ADDED "The compose line edits at an insertion point…" (requirement + 6 scenarios); design.md §2 (codepoint index; pi's **split** line semantics: logical line for Home/End/ctrl+a/ctrl+e, visual rows for ↑/↓, backed by pi's `moveToLineStart()`/`moveCursor(±1,0)`), §3 (`useCursor` placement + the windowed draft) |
| Image paste: `Ctrl-V`, Wayland → X11, `${TMPDIR}/teamsmith-paste-<uuid>.<ext>`, insert at the cursor, silent fallback, a **fixed** testability hook | ADDED "`C-v` pastes a clipboard image as a temporary file path" (requirement + 6 scenarios); design.md §8 (`PATH` is the only seam — no new `TEAM_*` key; probe forms, MIME priority, 1 s/3 s/50 MiB bounds, never deleted, never on the render path) |
| Rename `线程` → `往来记录` (block title, counts line, empty state; `cmd-docs.sh`/`cmd-project.sh` copy; `templates/threads-README.md`), directory/command/English term unchanged | MODIFIED panel "All visible text comes from external zh/en string tables" (+ clause and scenario) and MODIFIED `memory-and-deps` "The disk is the source of truth…" (+ a CLI scenario and a template scenario); design.md §11 |
| **追加①**: the keymap inherits pi's `tui.editor.*` defaults + multi-line | ADDED "The compose line's key map is pi's editor key map" (3 scenarios) and ADDED "The compose line has pi's kill ring and undo" (2 scenarios) and ADDED "The compose line edits multiple lines, and `ctrl+j` is the newline key" (4 scenarios); design.md §4 (one pure decoder for both encodings), §5 (ring/undo), §6 (the protocol), §7 (the encodings) |
| **追加①** terminal realities: ctrl+j vs pasted LF; shift+enter's protocol dependency; multi-line normalization into `draft-send.sh`/the guard/the reason | design.md §6/§7 state each with the measured Ink parser outputs; the spec pins the LF-as-Enter consequence explicitly, the shift+enter degradation ("behaves as `enter`, never a dead binding") and the reason's single-line rule; the pty fixtures send the raw byte and the Kitty bytes (`\x1b[106;5u`, `\x1b[13;2u`, `\x1b[45;5u`) so every claim is testable without a Kitty terminal |
| **追加②**: the work page's board rows focusable, Enter/click opens the same detail, `esc`/`q` returns to where you came from, the existing boundaries reused, no focusable-but-unopenable item | ADDED "The work page's board rows are focusable and open the same detail view" (4 scenarios) + MODIFIED panel detail requirement (two entry points, return to origin) + MODIFIED panel mouse requirement (the rows are targets; `pageUp`/`pageDown` keep the page scrollable, a second keyboard-only exception); design.md §9 |
| **追加②**: change id `panel-ergonomics`, title/impact rewritten for the four blocks, requirement granularity | the change directory was renamed (the old paths removed in `9d14d68`); proposal.md is rewritten for the four blocks; the delta keeps one requirement per behaviour topic |
| **The PM's ruling**: `C-e` = line end, the external editor moves to `C-o`, the hints updated | MODIFIED panel write requirement (`C-o` + the hint clause) with a new migration scenario; design.md §10; tasks 3.3–3.4 |
| `tasks.md` with tests and flips | six batches (B1–B6), each with a headless model fixture, a `[real]` pty scenario, a flip item, a regression item and a gate item; every batch rebuilds `panel.js` so the fixtures exercise what the branch would ship |

## Two brief premises corrected (with evidence)

1. **"面板已经在探 `client_termfeatures`/`extended-keys`"** — it does not.
   `grep -rn 'termfeatures\|extended-keys\|kitty' skills/teamsmith/scripts/panel/src skills/teamsmith/scripts/lib`
   prints nothing; the only extended-key machinery in the tree is Ink's own support, and it is **opt-in**
   (`render(node, {kittyKeyboard})`, `ink.js:800-860`). pi, by contrast, requests the protocol itself
   (`DESIRED_KITTY_KEYBOARD_PROTOCOL_FLAGS = 7`, `KITTY_KEYBOARD_PROTOCOL_QUERY`). The design therefore decides to
   enable Ink's `kittyKeyboard: { mode: 'auto' }` and pins the degradation for terminals that never answer the
   query (design.md §6), instead of resting on a probe that does not exist.
2. **"工作页（page 1）"** — the board rows live on **page 2**: `strings/zh.ts` has `pageOverview: '总览'` for 1 and
   `pageWork: '工作'` for 2, and `layout()`'s `case 2` is the one pushing `boardBlock`. The requirement and the
   tasks name page 2 (the brief's page-1 note would have pointed the apply work at the overview).

## Acceptance (verbatim, run on tip `9d14d68`)

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ change/panel-ergonomics
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)
rc=0
```

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec show panel-ergonomics --json | head -40
{
  "id": "panel-ergonomics",
  "title": "Propose: `panel-ergonomics` — a pi-style compose line, clipboard images, work-page detail entry, and `线程` → `往来记录`",
  "deltaCount": 12,
  "deltas": [ … ]
```

The machine-cut summary of the same run (no hand-editing):

```text
$ … openspec show panel-ergonomics --json | python3 -c '…'
deltaCount = 12
memory-and-deps  MODIFIED  scenarios_in_block=4
panel            ADDED     scenarios_in_block=6
panel            ADDED     scenarios_in_block=3
panel            ADDED     scenarios_in_block=2
panel            ADDED     scenarios_in_block=4
panel            ADDED     scenarios_in_block=6
panel            ADDED     scenarios_in_block=4
panel            MODIFIED  scenarios_in_block=6
panel            MODIFIED  scenarios_in_block=7
panel            MODIFIED  scenarios_in_block=3
panel            MODIFIED  scenarios_in_block=3
panel            MODIFIED  scenarios_in_block=7
```

The brief's two literal lines name the change's old id (`panel-compose-ergonomics`), which the PM's follow-up
renamed; the PM's brief header (`change:` line) still carries the old id and needs the PM's pen.

Beyond the brief's two commands, the repository gate's other half was run too (planning-only change, so this is
belt-and-braces evidence):

```text
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh      # 319 s, on tip 9d14d68
…
== 结果 ==  ✓ 1720  ✗ 0
FAST 模式：跳过 23 个真进程段落（1c·M11 真沙盒窗口|6·dispatch 真拉起|…|31c·窗口注入端到端）
smoke 全绿
SMOKE_RC=0
```

## Why every new/changed scenario can be falsified in the apply phase (today's red)

The gate cannot see this (D23: `openspec validate` does not check scenario quality), so it is checked by hand.
Grouped by requirement; each row names the observable and the red state on today's tree.

| Requirement (delta) | Scenarios | Today (red) |
|---|---|---|
| ADDED cursor | typographic insert/delete + wide glyph; wrapped draft (`Home`+`Z`); `↑` clamp; `alpha\nbeta`; the 30-line window; the window following the point | `←`/`↑`/`Home` are unbound in the compose (`intake('')` does nothing), `Z` appends at the end, `#{cursor_x}`/`#{cursor_y}` never move, and a 30-line draft pushes the frame to 3 rows with the draft's head off-screen. The `cjk`/`draft`/`paste`/`receipt` scenarios stay green as the regression guard |
| ADDED key map | the word/line/forward-delete sequence; the logical-line case; the Kitty encoding of a bound key | `ctrl+w`/`alt+b`/`ctrl+d`/`ctrl+k`/`ctrl+a` are unbound (some leak their letter: `ctrl+c` types a `c` today); the 45-character-line case would leave the tail; `\x1b[98;5u` does nothing |
| ADDED kill ring/undo | delete→`ctrl+y`→`alt+y`; undo restoring text **and** the cursor | the ring and undo do not exist; `ctrl+y` types `y`, `\x1b[45;5u` is dropped by Ink's legacy mapping (`name ''`), so the undo assertion is red |
| ADDED multi-line | the legacy `\n` byte inserts a break while `\r` submits; Kitty `ctrl+j`/`shift+enter`; a pasted three-line payload; the reason stays one line | today a lone `\n` **submits** (`intake` maps `\r` and `\n` to submit) — the exact defect the brief names; the reason would carry the newline into `team standby on --reason` |
| ADDED paste | image → path at the point; Wayland→X11 with the call log; text fallback; no tool; a never-answering tool; the reason mode | `C-v` is unbound: the letter `v` is appended and no temp file is written; with a fake clipboard the call log stays empty |
| ADDED work page | `↓`+`enter` opens the first row's detail on page 2; closing returns to the origin page; a click focuses then opens; an empty/degraded board has no dead item | the work page's rows have no focus and no targets, `enter` on page 2 does nothing, and the detail only renders on page 4 — the "dumped on another page" shape the briefs warns about cannot even be reached today |
| MODIFIED write (`C-o`) | `C-e` moves to the line end and does not run the editor, `C-o` runs it once | today `C-e` runs `$EDITOR` and `C-o` is unbound (it would append an `o`) |
| MODIFIED read-only | the paste writes outside the project and runs no command | no temp file is written at all (the first clause is red) |
| MODIFIED strings | the messages page reads `收件箱与往来` and `grep -c 线程 zh.ts` is 0 | the bundled table and the frame say `收件箱与线程` |
| MODIFIED detail | (folded into the work-page scenarios) | — |
| MODIFIED mouse | (folded into the work-page scenarios + the p28 target-map assertion) | the work page's rows are not targets |
| memory-and-deps | `team thread dev` on an empty thread names `往来记录`; the rendered threads README carries the label | the warning says `线程还没有内容`, the template's title is `# Agent ↔ PM 消息线程` |

Two assertions are guards rather than flips, labelled as such in `tasks.md`: 2.6 (`ctrl+c` inserts nothing — a fix
of an existing quirk) and 4.4 (no clipboard tool runs while the console is idle).

## Terminal realities the apply phase must satisfy (stated, not implied)

- **`ctrl+j` vs a pasted LF.** Ink's parser (7.1.1) gives `\n` → `name 'enter'`, `return: false` and `\r` →
  `name 'return'` (measured), so the compose line can tell the two apart: `key.return && !key.shift` submits, a
  lone `\n` inserts. The consequence — a terminal whose Enter reports `\n` inserts a break instead of submitting —
  is written into the requirement rather than hidden; pi behaves the same way, and the Kitty protocol removes the
  ambiguity.
- **`shift+enter`.** It reaches the panel only as `CSI 13;2u` (Kitty), which Ink's parser yields as
  `return + shift`; the panel enables Ink's protocol in auto mode and the requirement pins that without it the key
  behaves exactly as `enter`. The pty fixtures inject the Kitty bytes directly, so the binding is proven without a
  Kitty terminal.
- **Multi-line normalization.** `state/draft.md` keeps LF; `team draft send` delivers a multi-line draft as one
  message through bracketed paste (or as file plus pointer on targets that cannot take one) — the existing path,
  unchanged and still covered by the `paste`/`receipt` scenarios; the standby reason is flattened to one line at
  insertion time, so the state file, the panel's line and `watchdog.log` never see a newline.

## Delta hand-check against the base specs (the D23 validate hole)

- The five MODIFIED blocks were copied **whole** from `openspec/specs/panel/spec.md` and edited in place: every
  base scenario is still present (write 5+1 new, mouse 7, read-only 2+1, strings 2+1, detail 7) and no base
  sentence was silently dropped; `memory-and-deps` carries its 2 base scenarios plus 2.
- Trial archive on a scratch copy (`mkdir /tmp/p19-trial && cp -r openspec /tmp/p19-trial/openspec && cd
  /tmp/p19-trial && openspec archive -y panel-ergonomics`): **+6 added, ~6 modified, 0 removed**, exit 0, and the
  merged `openspec/specs/panel/spec.md` then carries **114 scenarios** — OpenSpec's own checker saw no missing
  scenario and no ADDED collision.
- `grep -rn 'thread' openspec/specs/` and a heading scan confirm the ADDED requirements do not restate an existing
  promise (the base has no cursor/keymap/ring/multi-line requirement and no clipboard promise; its one paste
  scenario is about a bracketed terminal paste staying one message). The four-page requirement is untouched: the
  detail view on page 2 is a view, not a fifth page.

## Requirement → task coverage map

In `tasks.md` §Coverage map: cursor → 1.1–1.8; key map → 2.1, 2.3–2.6; kill ring and undo → 2.2–2.5; multi-line →
3.1, 3.2, 3.4–3.7; write (`C-o`) → 3.3–3.5; paste → 4.1–4.6; read-only → 4.3, 4.4; work page → 5.1–5.5; detail →
5.1–5.3, 5.5; mouse → 5.2, 5.4; strings and `memory-and-deps` → 6.1–6.4; every requirement also by the gate item
7.1. Every `[real]` item has a headless sibling (1.1/2.1/2.2, 3.1's decoder cases, 4.2), and no requirement hangs on
a real pane alone.

## Defect-flip note

This is a propose task, not a defect fix, so the report carries no red→green section of its own; the flips live in
`tasks.md` per batch (1.7, 2.5, 3.6, 4.5, 5.5, 6.4) and each names the assertion that must go red.

## Boundaries honored

Wrote only `openspec/changes/panel-ergonomics/**` and this report (and removed the renamed-away paths).
`skills/**` is untouched: `git diff --name-only main...HEAD` lists the change directory and the report only. No
state-changing `team` command was run; the tmux/tooling checks were read-only. Branch is local for PM review (local
mode).

## What the PM's proposal review should poke at

1. **The two scope additions inside the compose editor**: the kill ring/undo (§5) and the windowed draft (§3). Both
   are self-contained batches the PM can cut without touching the rest.
2. **Enabling Ink's Kitty protocol** (§6): it is the only route to the brief's "shift+enter when the terminal
   supports it" and to `ctrl+-`, and it is the one change here that alters what a real terminal sends for *all*
   keys — the design bounds it (auto mode, Ink's default flags, disable around the editor relay, a documented
   degradation), but it is the riskiest of the eleven decisions.
3. **The LF-as-Enter consequence** (§7): a terminal that reports Enter as `\n` would insert a break instead of
   submitting. It is stated in the requirement; if the PM wants it excluded, the alternative is exactly what the
   brief ruled out (dropping `ctrl+j`).
4. **Page 2's `↑`/`↓`** now move the row focus instead of scrolling, with `pageUp`/`pageDown` added as the
   keyboard-only scroll (a second exception beside `r`, recorded in the mouse requirement).
5. **The CLI/template half of the rename** stays pinned in `memory-and-deps` (the only requirement naming the
   ledger), not in a new capability.
6. **The brief's two stale premises** (no `termfeatures` probe; the work page is page 2) — the PM may want to
   correct the brief's text and its `change:` header line before the apply dispatch.
