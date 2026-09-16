# Propose: `pulse-tui-panel` — the status panel as a TUI front end over the data layer

## Why

D19 (user) rewrites the patrol panel with a real TUI framework and makes Node/Bun a required dependency; D24
accepted E4's measured pick — **Ink + TSX**, one committed bundle, `monitor.mjs` unchanged as the data layer. The
panel is also D20's first consumer: "N messages held because the PM's box was busy" is invisible today.

## Before (measured on the base, `544efc4`)

`team monitor --once` piped writes 3 ESC bytes (`ESC[H ESC[2J ESC[3J`); `--print` and `--json` are refused (`rc=2`,
`monitor: 未知参数`); `team doctor` has no JS-runtime check and `team paths` no `js_runner`/`require_js`; the panel
shows no queue field (`state/outbox/` does not exist; P5 owns it) and the activity column is opt-in
(`TEAM_MONITOR_ACTIVITY=0`). **After** (checked in apply): a byte-clean pipe, machine-readable `--print`/`--json`,
doctor failing without a runtime, the queue count as a field. Raw logs: `docs/team/reports/P9-dev2/`.

## What Changes

- **New capability `panel`** (12 requirements / 33 scenarios): the four output modes; the four-band layout and its
  degradation order; the per-field keep/fold/upgrade disposition; the sanitize chain; the panel process as the
  patrol's only tick loop; the loud failure without a runtime; the read-only `state/outbox/` field; the
  `TEAM_MONITOR_*` keys; the single-bundle distribution.
- **`memory-and-deps`** (ADDED + MODIFIED): a JS runtime becomes a required dependency (`node`/`bun`/`tsx` or
  `TEAM_JS_BIN`, doctor fails without one, `TEAM_REQUIRE_JS=0` downgrades that check), and `team paths` gains
  `js_runner`/`require_js`.
- **No `watchdog` delta, deliberately**: its only sentence about the panel stays true, while P5 and P7 already
  restate those requirements in full (design §2).

## Capabilities

### New Capabilities

- `panel`: what `team monitor` renders, in which mode, with which fields, from which sources — and what it must
  never do (write state, tick in an observer mode, touch the queue, emit control bytes).

### Modified Capabilities

- `memory-and-deps`: the runtime requirement and the visibility of the resolved runtime.

## Impact

At archive time `openspec/specs/panel/spec.md` is created and `memory-and-deps` gains one requirement, one restated
requirement and one scenario. No code, test, reference or ledger file changes in this phase; the apply briefs (A1
behavior + tests, A2 docs + release) own those.

## Acceptance (verbatim)

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
git status --porcelain
```

## Boundaries

- Only `openspec/changes/pulse-tui-panel/**` and `docs/team/reports/P9-dev2.md` (plus its evidence directory) may be
  written; `openspec/specs/**` is archive's job, and code, tests, references and the ledger belong to apply.
- Out of scope: step 2's visualization band (reserved, not implemented), P5's delivery guard (the panel only reads
  its queue directory), and every surface renamed by `rename-watchdog-to-pulse` (this change writes today's names).

## Evidence the report must contain

The `openspec change show` transcript, both gate tails, the scratch-archive run with its file list, the word-level
diff of the restated `memory-and-deps` requirement against `git show HEAD:openspec/specs/memory-and-deps/spec.md`, the
requirement → scenario → falsifier map with `[real]` marked, and the deliberate omissions.
