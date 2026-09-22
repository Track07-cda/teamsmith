# Tasks: `settings-view-groups`

Planning only — nothing in this file is executed by the propose task (P29). One apply brief: the schema tokens,
their labels, the view and the bundle must land **together**, because (a) the token⇄label bijection
(`panel-strings.mjs`) is red while only one side exists and (b) smoke §26-a rebuilds `panel.js` from the tree's
own sources and compares it byte-for-byte, so sources and bundle cannot drift. The pty items need a real process
(private tmux server + the real bundle) and are marked; they are never the only evidence for a requirement (the
FAST-wired gates of Batch 1 and the structural pins of 2.7 carry the cheap half).

Coverage map (requirement → items): **R1** group read + walk → 1.1–1.4, 1.6–1.7; **R2** functional grouping and
the per-row class → 1.6, 2.1–2.3, 2.6, 2.7; **R3** the wheel → 2.4, 2.6, 2.7. Docs (no requirement) → 1.5.
Gate/evidence → 3.1–3.3; independent verification → 4.1.

Path grants the apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/lib/cmd-config.sh`,
`skills/teamsmith/scripts/panel/**` and `skills/teamsmith/references/**` are **PM-owned** and need an explicit
grant per brief; `skills/teamsmith/tests/**` is `agent:dev`'s; `openspec/changes/settings-view-groups/**` belongs
to the phase's owner; `openspec/specs/**` and `docs/team/**` stay PM-owned.

Fixture notes: every fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`) and writes only
inside its scratch repo; the pty fixture uses a private tmux server and the argv-logging wrapper the `settings`
scenario already builds; the bundle may only be rebuilt with the pinned bun and must reproduce byte-for-byte
(`bash skills/teamsmith/scripts/panel/build.sh` twice → `git diff --exit-code` on the bundle).

## 1. The read carries the group (`memory-and-deps` ADDED)

- [ ] 1.1 `scripts/lib/cmd-config.sh`: the schema's header comment documents the 10th column (`group`, a closed
  ASCII token matching `^[a-z][a-z0-9-]*$`, one token per row; no row without one) and `team_config_field`'s
  documented range becomes `1..10`. Verify: `grep -n 'group' skills/teamsmith/scripts/lib/cmd-config.sh` shows
  the header line and the range, and `bash skills/teamsmith/tests/config-cli.sh` stays green.
- [ ] 1.2 `scripts/lib/cmd-config.sh`: all 111 rows gain their token from the design's table (D2: `identity` 12,
  `branch` 11, `policy` 16, `roster` 11, `seat-model` 3, `workflow` 14, `delivery` 13, `panel` 7, `patrol` 4,
  `pm-lifecycle` 6, `session` 10, `meeting` 4). Verify with the census one-liner (fails on a wrong count, a
  missing token or a bad shape):
  `awk -F'|' '/^# ----/{next} /^TEAM_[A-Z0-9_]+\|/{n++; t[$10]++} END{printf "rows=%d tokens=%d\n", n, length(t); for(k in t) printf "%s %d\n", k, t[k]}' skills/teamsmith/scripts/lib/cmd-config.sh | sort`
- [ ] 1.3 `scripts/lib/cmd-config.sh`: `team_config_list_json` emits `"group":"<the row's 10th field>"` on every
  known record and `"group":""` on a record for a key the schema does not know. Verify: on a fixture project,
  `team config list --json` carries `"group":"identity"` for `TEAM_PROJECT`, `"group":"panel"` for
  `TEAM_PULSE_INTERVAL`, `"group":""` for a hand-added key; `team config list`'s header is still
  `KEY CLASS KIND VALUE`; `team monitor --print`/`--json` carry no `group` token.
- [ ] 1.4 `skills/teamsmith/tests/config-cli.sh`: a new `groups` section — the walk (the sample keys' `group`
  verbatim against the schema row; every schema row's group non-empty and shape-checked; the schema-unknown key's
  `""`; the human table and the machine exits unchanged). Verify: the section's tail, then **F-G1** (a scratch
  tree via `TEAM_CONFIG_TREE` whose `TEAM_GATES` row lost its 10th field → the section exits non-zero naming
  `TEAM_GATES`; restore → green) and **F-G2** (a `NoPe!` token → red; restore → green). Both flips use the
  script's existing pattern (a scratch tree edited in place + `TEAM_CONFIG_TREE` + the internal red/green pair,
  `config-cli.sh`'s last fixture branch) so the section carries its own red side.
- [ ] 1.5 `skills/teamsmith/references/config.md` (PM grant): document the 10th column, the token shape, the
  twelve tokens' meaning and that the vocabulary is closed by the label bijection the strings gate enforces.
  Verify: `grep -n 'group' skills/teamsmith/references/config.md`.
- [ ] 1.6 `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts`: add the twelve `group_<token>` labels (the
  design's D2 table), `settingsGroupUngrouped` (`未分组` / 'Ungrouped') and the relabelled `settingsGroupSeats`
  (`席位` / 'Seats'); delete `settingsGroupApply`/`settingsGroupRestart`/`settingsGroupRefuse` from **both**
  tables. Verify: `node skills/teamsmith/tests/panel-strings.mjs .` is red between 1.2 and this item and green
  after it (both tails in the report).
- [ ] 1.7 `skills/teamsmith/tests/panel-strings.mjs`: rule 4's group half — parse every schema row's 10th field
  and assert `group_<token>` exists in both tables for exactly the tokens the rows use (a token without a label
  and a label without a token are both failures). Wire its two red sides next to §28-a2's existing key-label
  flips (the same scratch-tree pattern: delete one `group_<token>` from both tables → red naming the token; add
  `group_zzz` → red as stale) and paste both tails in the report.

## 2. The console groups, colours and scrolls (`panel` ADDED + MODIFIED)

- [ ] 2.1 `scripts/panel/src/types.ts`: `SettingsKey` gains `group?: string` (the `settings` block is the raw
  read, so the field passes through unmodified).
- [ ] 2.2 `scripts/panel/src/layout.ts`: `settingsViewRows` drops the class-bucket table — it walks the read's
  keys in order, opens a functional heading whenever the token changes, keeps the rows' order, appends the
  fallback group for empty tokens and the seats group last; heading labels come from `group_<token>`, falling
  back to the raw token when the table has none. Verify: 2.6's `groups` scenario (real process).
- [ ] 2.3 `scripts/panel/src/layout.ts`: the class tone covers the **badge only** (the value stays plain);
  `restart` → `warn`, `refuse` → `dim`, `apply` → the plain text tone. Verify: 2.6's badge/tone assertion, and a
  capture with the SGR sequences stripped still carries all three classes as words.
- [ ] 2.4 `scripts/panel/src/layout.ts` + `src/App.tsx`: the view's own window offset (state + ref, clamped to
  the row count; the layout uses it when set and keeps the focus-follow rule when it is not); the mouse branch
  consumes the wheel in every state of the view — the row list scrolls by one row per notch (focus unchanged),
  the choice editor and the seat picker walk their entries (`moveChoicePicker` as today, `moveSeatPicker` newly,
  whose wheel used to fall through to the page) — and the page behind the view is never scrolled; the focus keys
  and the `↑/↓ 行` chip push the offset using the window the frame returns, so the focused row is always inside
  it; the offset resets when the view opens and when the filter changes. Verify: 2.6's wheel scenarios (real
  process) plus 2.7's structural pin.
- [ ] 2.5 Rebuild `scripts/panel/panel.js` with the pinned bun; a second rebuild is byte-identical. Verify:
  `bash skills/teamsmith/scripts/panel/build.sh` twice and `git diff --exit-code -- skills/teamsmith/scripts/panel/panel.js`,
  plus smoke §26-a's sandbox rebuild.
- [ ] 2.6 `skills/teamsmith/tests/panel-p21.sh` (dev): update the `settings` scenario (the `立即生效` heading
  assertion becomes a functional heading; the click step filters to an `apply` row first, because the view now
  opens on the read-only skeleton) and add:
  - `groups` — the headings are the functional labels with no class word among them; the schema's order inside a
    group; a scratch CLI whose `TEAM_ZZZ_TEST` carries `workflow` and whose `TEAM_GATES` moves to `meeting` makes
    the committed bundle render both under the new headings (**no key→group table in the bundle**); a row whose
    token was deleted renders under the fallback heading, not nowhere;
  - `wheel` — three wheel-down notches over the view move its window three rows while the focus stays (the CLI
    hint still names the same key) and both edge counts follow; `esc` back to the page shows the page's offset
    unchanged (the pre-change red side: the frame is identical and the page moved); the first `↓` after a wheel
    scroll pushes the window onto the focused row; with the choice editor or the seat picker open the wheel walks
    that picker's entries and the page still does not move.
  Verify: `bash skills/teamsmith/tests/panel-p21.sh settings groups wheel` (real process, slow batch).
- [ ] 2.7 `skills/teamsmith/tests/smoke.sh` (dev): FAST structural pins so the fast gate still catches the two
  regressions while 2.6 is skipped — the view's grouping reads the record (no class-bucket table / no
  `settingsGroupApply` in `layout.ts`) and the mouse branch consumes the wheel in the view before the page
  scroll. Verify: the FAST smoke tail; removing the pin's subject makes it red.
- [ ] 2.8 The apply report carries every flip's red/green tail: F-G1/F-G2 (1.4), the label bijection (1.7), the
  no-hardcode move and the deleted token (2.6), the wheel before/after (2.6), the tone (2.3/2.6), and one line
  stating the writer is untouched (the existing `config-cli.sh writer cas validate audit` sections stay green).

## 3. Gate, trial archive, evidence (the apply's own report)

- [ ] 3.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`, then the **full** smoke once (the slow pty
  scenarios) — paste the tails; `git status --porcelain` clean.
- [ ] 3.2 Trial archive on a scratch copy (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
  settings-view-groups)`) — proves the MODIFIED mouse requirement keeps every base scenario and that the ADDED
  blocks merge without a collision with the open `change-centric-discipline`/`tmux-gate-grant-redesign` changes.
- [ ] 3.3 The report's evidence: the delta→requirement map for `panel` and `memory-and-deps`, the
  requirement→item and scenario→fixture maps, the measured group census, every flip's tails, and the writer
  statement.

## 4. V — independent verification (a different agent)

- [ ] 4.1 Rerun, out of tree and on the apply's tip: every flip of 2.8 (red and green), the `groups` and `wheel`
  pty scenarios, `openspec validate --all --strict` and the **full** smoke; the record goes to
  `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying findings is rework, not archive).
