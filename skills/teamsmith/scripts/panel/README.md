# teamsmith pulse panel (`team monitor`)

The panel is the process that owns the pulse window: an [Ink](https://github.com/vadimdemedes/ink) + React
front end that draws one frame per `TEAM_MONITOR_REFRESH`, runs one patrol tick per `TEAM_PULSE_INTERVAL`, and
consumes the existing data layer unchanged (`scripts/monitor.mjs --json` for the activity stream, the bash
readers for the team fields). `team monitor` never reads state files itself.

The team fields arrive **per block**: `data.ts` spawns one `team __panel-data --block <name>` child per block,
asynchronously and with its own timeout, and the renderer only ever reads the in-memory cache. A source that is
missing, unreadable, too slow or failing renders its own band as `—` and never delays the rest of the frame or a
keystroke (see `openspec/changes/pulse-console`).

```
team monitor                    # TUI in a terminal; plain text when stdout is not a TTY
team monitor --once             # one frame through the same renderer selection, plus the due tick
team monitor --print            # exactly one plain-text frame (no escape bytes, no state writes, no tick)
team monitor --json             # {"panel": {...}, "activity": [...]} (same guarantees as --print)
team monitor --width N --height N
```

## Compose and the three actions (pulse-console B2)

`m` opens a bottom input line on the page; Enter sends through the guarded delivery path and the receipt is
one of three honest states — **delivered**, **queued** (the PM's box is busy) or **held** (the payload is in
`state/outbox/held/`). Esc keeps the draft in `state/draft.md` and the next `m` brings it back; `C-e` hands the
draft to `$EDITOR` with rendering suspended for the whole handoff. `f` runs `team outbox flush` and `s`
toggles standby (switching it on asks for a one-line reason in the same input line). The console itself never
types into the PM's pane — every delivery is the owning command's, and the input line keeps refreshing the
rest of the frame while it is open.

The receipt is mapped from the send command's machine tokens, never from its human prose:
`draft-send.sh` runs the same guarded `team draft send` function in one shell (the CLI's
`TEAM_SEND_OUTCOME` / `TEAM_OUTBOX_RESULT` cannot cross a process boundary) and prints
`rc=<n> outcome=<token> result=<token>` for the console to parse. It lives under `scripts/panel/**` and
changes nothing in the CLI's own files.

The console's own files live in the project's state directory (`--state-dir`, passed by `team monitor`):
`state/draft.md` today (`state/panel.conf` and `state/panel-page` arrive with B3).

## What is committed, and why

| Path | What it is |
|---|---|
| `panel.js` | **the committed bundle** — the only file the runtime path uses. It runs with no `node_modules` and no network, so installing the skill needs no package manager |
| `src/*.tsx`, `src/*.ts` | the sources (layout, Ink app, width table, sanitizer, the bash data adapter, the CLI) |
| `package.json`, `bun.lock` | the pinned build-time dependencies (`bun install --frozen-lockfile` is part of the build) |
| `build.sh` | the one build command; it writes `panel.js` |
| `draft-send.sh` | the send bridge: the guarded `team draft send` run in one shell, printing one machine line (rc + outcome tokens) for the receipt |
| `tsconfig.json` | types only (`bunx tsc --noEmit` is a development check, not a gate) |

## Rebuilding it

```sh
bun install --frozen-lockfile
bash skills/teamsmith/scripts/panel/build.sh
```

The build needs the network (it resolves the pinned dependencies) and Bun ≥ 1.3; it is a maintainer action, not
something a user of the skill ever runs. The result is deterministic: the same lockfile, sources and Bun version
produce the same bytes, so `cmp` against the committed `panel.js` is the release-time check (the smoke suite runs
the same comparison when Bun is available).

The committed artifact at the time of writing:

```
file:   skills/teamsmith/scripts/panel/panel.js
size:   843210 bytes
sha256: ebed65002612aa02d240269df20a333a9901cbf77df5e12ee98a36eb824beb23
pins:   ink 7.1.1 · react 19.3.0 · runtime floor: node >= 20 | bun >= 1.3
```

The bundle's header (first lines of `panel.js`) names the same pins and the build command; `node panel.js
--version` prints them too, so a stale bundle is visible without a rebuild.

## Notes for maintainers

- `package.json` is only read by the build and by a consistency check; nothing installs it at runtime. The
  repository stays free of `node_modules` (it is `.gitignore`d here).
- Ink imports `react-devtools-core` statically; it is pinned as a dependency so the bundle resolves it offline.
  `--external react-devtools-core` is *not* an option: it moves the failure to the runtime.
- `TEAM_MONITOR_UI=tui` forces the TUI renderer even when stdout is redirected. Ink writes no control bytes when
  stdout is not a TTY, so a piped sample cannot tell the two renderers apart — the real-pane capture is what
  pins the renderer.
- The panel's own sanitizer (`src/sanitize.ts`) runs on every string before layout; the bash data command also
  strips control bytes before JSON-encoding, because a raw control byte makes the JSON unparseable.
