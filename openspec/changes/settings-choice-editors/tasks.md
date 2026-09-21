# Tasks: `settings-choice-editors`

Planning only — nothing in this file is executed by the propose task. Four batches become **two apply briefs**:
**A1 = B1** (the read: the `choices` field, the suggestion column and the `known` fix — `memory-and-deps`) and
**A2 = B2 + B3** (the console's editor and its fixtures — `panel`), then **B4** is the PM's archive prep. A1 lands
first: A2's picker and fixtures read the new field. Every guard needs a red → restore-green flip in its apply
report.

Coverage map (requirement → items): R1 choices read → 1.1–1.4; R2 known model set → 1.2, 1.4; R3 choice editor →
2.1–2.6, 3.1–3.4; R4 write path unchanged → 2.7, 3.5. **R3/R4 as reworked by M65 (a chosen value writes directly;
the interaction path reads nothing; the read stops fanning out) → 5.1–5.7, verified by 6.1–6.2.** Docs (no requirement) → 1.5. Gate/evidence → 4.1–4.3.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**` and
`skills/teamsmith/references/**` are **PM-owned** and need an explicit grant per brief (A1:
`scripts/lib/cmd-config.sh`, `references/config.md`; A2: `scripts/panel/**`); `skills/teamsmith/tests/**` is
`agent:dev`'s (A1: `tests/config-cli.sh`; A2: `tests/panel-p21.sh`, `tests/flip-m54.sh`, `tests/smoke.sh`);
`openspec/changes/settings-choice-editors/**` belongs to the phase's owner; `openspec/specs/**` and `docs/team/**`
stay PM-owned.

Fixture notes: every fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`) and writes only inside
its scratch repo; the panel bundle may only be rebuilt with pinned bun and must reproduce byte-for-byte
(`bash skills/teamsmith/scripts/panel/build.sh` twice → `git diff --exit-code`). The Pi model catalogue fixture is
a scratch `HOME` (never the developer's), and the `sub2api` string in it is a synthetic name.

## 1. B1 — the read reports the choice set (`memory-and-deps` ADDED + MODIFIED)

- [x] 1.1 `scripts/lib/cmd-config.sh`: the schema gains the optional 9th column `suggest` (comma-separated whole
  values, numeric kinds only; absent = no suggestions, existing 8-field rows unchanged) and
  `team_config_field`'s documented range becomes `1..9`. A `team_config_choices <row>` helper returns the object
  `{source, values, min, max, empty, note}` from the row alone plus the models block's `known`: `bool` → `["1","0"]`;
  `enum` → `constraints` in order; `int|seconds|mb|bytes|pct` → the `suggest` tokens with `min`/`max` from
  `constraints`; `path`/`model` → `empty` from the spec's `,opt`; `model|pairlist|winlist|pattern` → `known`;
  `text|cmd|tpl|list` → `none`. Verify: `team config list --json` on a fixture prints the object for every kind.
- [x] 1.2 `scripts/lib/cmd-config.sh`: `team_config_list_json` emits `choices` on every key record, schema-unknown
  file keys included (`source: none`), and `models.known` gains the `pm` seat's displayed model through the same
  `team_config_seat_state` resolution the seats block uses (deduplicated, first-seen order). Verify: fixture runs
  `TEAM_AGENT_MODELS` without the PM model and `TEAM_PM_MODEL=kimi-coding/k3-256k` → `known` carries it once.
- [x] 1.3 `tests/config-cli.sh` (dev): a new `choices` section asserting the per-kind table of R1's scenario
  (`TEAM_BRANCH_MODE`, `TEAM_MONITOR_UI`, `TEAM_NOTIFY_TMUX`, `TEAM_PULSE_INTERVAL`, `TEAM_AGENT_BIN` vs
  `TEAM_PI_BIN`, `TEAM_GATES`, an unknown file key) and R2's `known` behaviour of 1.2. **The consistency walk**:
  for every schema key, every `choices.values` and every suggestion-column token is fed to
  `team config set <KEY> <value> --dry-run` in a fixture contract; a value the validator refuses fails the section
  (exit 0 or 7 is accepted — danger is valid). Verify: the section's tail and its red on a patched scratch tree.
- [x] 1.4 Flips: **F-A** — drop the pm seat from `known` → 1.3's model assertion red; **F-D** — a scratch tree
  (`TEAM_CONFIG_TREE`) whose `TEAM_PULSE_INTERVAL` suggests `30` (min `60`) → the consistency walk red. Restore both
  → green. Verify: both red/green tails in the report.
- [x] 1.5 `references/config.md` (PM grant): document the 9th column, the `choices` field's shape and that
  suggestions are schema data validated by the fixture gate. Verify: `grep` finds the column and field names.
- [x] 1.6 Verify FAST smoke already runs the section (smoke §33 invokes `config-cli.sh` unconditionally):
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → green with a larger ✓ count in §33.

## 2. B2 — the console chooses (`panel` ADDED + MODIFIED)

- [x] 2.1 `scripts/panel/src/types.ts` + `data.ts`: `SettingsKey` gains an optional `choices`
  (`{source, values, min, max, empty, note}`); assert the `settings` block carries the field through unmodified
  (it is the raw `--json` payload). Verify: a fixture block with a `choices` object renders its picker.
- [x] 2.2 `scripts/panel/src/App.tsx`: a `choicePicker` state machine shaped like the seat picker: opened by an
  editable row whose key has a choice set (`refuse` rows and unknown keys keep today's behavior); entries built as
  current → default → `choices.values` (deduped) → kind entries; `↑/↓` + accept; accept opens `openCompose('setting', value)`
  (so the existing dry-run/confirm/write steps are untouched); the keep-unset entry cancels; `pairlist` moves the
  focus to the seats block; a no-choice kind opens the compose editor directly with the reason state; `esc` closes
  back to the row list with the focus preserved. Verify: the pty scenarios of 3.1.
- [x] 2.3 `scripts/panel/src/layout.ts`: render the picker in the settings view's own line budget exactly like the
  seat picker (same window/offset rules, `placedWithHits` click actions per entry, current/default/unset markers,
  the numeric interval text, the `path` existence mark, the no-choice reason line, the keep-unset/clear/free-text
  labels). No row-list change → no snapshot churn. Verify: 3.1 plus `tests/panel-snapshots.sh` unchanged.
- [x] 2.4 `scripts/panel/src/strings/{zh,en}.ts`: the new labels (on/off words, current, default, keep-unset,
  clear, free text, exists/missing/not-executable, the no-choice and interval templates) in both tables with
  matching placeholders. Verify: `node skills/teamsmith/tests/panel-strings.mjs .` green.
- [x] 2.5 Rebuild `scripts/panel/panel.js` with the pinned bun and commit the bundle; a second rebuild is
  byte-identical. Verify: `bash skills/teamsmith/scripts/panel/build.sh` twice and `git diff --exit-code` on the
  bundle, plus smoke's bundle assertions (26-a/26-b).
- [x] 2.6 The closed- vs open-domain rule: `bool`/`enum` render no free-text entry; `model`/numeric/`path` render
  one; `winlist`/`pattern` insert `<model>=` at the insertion point. Verify: 3.1's scenario tails.
- [x] 2.7 Prove the write path did not move: choosing an entry leads to the same
  `config set … --dry-run` → confirmation → `config set … --yes --fingerprint` argv sequence as typing, and a
  cancelled picker writes nothing. Verify: the existing `panel-p21.sh write conflict` scenarios stay green plus
  the new argv assertion in 3.1.

## 3. B3 — fixtures and flips (`panel`)

- [x] 3.1 `tests/panel-p21.sh` (dev): a new `choices` scenario (private tmux server, argv-logging wrapper) covering
  R3's scenarios: the bool two-entry editor; the enum's exact constraints; the unset key's keep-unset entry (accept
  → sha256 and audit unchanged); the numeric interval text and free-text path; the path clear-entry absence for a
  required spec; the no-choice reason line (`TEAM_GATES`); the pairlist focus move; a click accepting an entry and
  `esc` writing nothing. Verify: the scenario's tail, all ✓.
- [x] 3.2 `tests/flip-m54.sh` (dev, the `flip-p22.sh` pattern): **the enum flip** — a scratch CLI whose schema gains
  `TEAM_ZZZ_MODE|apply|enum|red,blue|plain|red` makes the committed bundle offer `red`/`blue`; the same schema with
  the constraints removed makes it open free text with the reason; then **F-B** — a bundle whose `choices` reader is
  disabled → 3.1 red; **F-C** — a fixture Pi catalogue naming `sub2api/…` → the model entries/`known` assertions
  red if it leaks. Restore → green and bundle byte-identical. Verify: every red/green pair in the report.
- [x] 3.3 `tests/smoke.sh` (dev): wire the new `panel-p21.sh choices` scenario where the existing panel sections
  are run, keep FAST behavior explicit (a visible skip, never a silent omission), and state which parts are slow.
  Verify: the section tail under FAST and (once) full smoke.
- [x] 3.4 The catalogue fixture of 3.2 is a scratch `HOME`; assert both the read (`team config list --json` with
  that `HOME`) and the picker carry no `sub2api` token. Verify: the assertion's tail.
- [x] 3.5 Re-run the existing write/conflict/seat/readonly scenarios unchanged to prove the write path and the
  seat editor are untouched. Verify: their tails.

## 4. B4 — gate, trial archive, evidence (PM)

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and the full
  `bash skills/teamsmith/tests/smoke.sh` — green; paste the tails.
- [x] 4.2 Trial archive on a scratch copy (`cp -r openspec /tmp/trial && (cd /tmp/trial && openspec archive -y
  settings-choice-editors)`) — proves both MODIFIED blocks keep every base scenario and that a schema-key/value
  addition lands without a collision with the open `watch-degradation`/`gate-hygiene` panel changes. Verify: the
  trial output.
- [x] 4.3 The report's evidence: the delta→requirement map for `panel` and `memory-and-deps`, the
  requirement→item and scenario→fixture maps, every flip's red/green tail, and one line stating that the writer's
  validation, CAS, audit and danger list were not touched (the existing `config-cli.sh writer cas validate audit`
  sections stay green).

> **PM 勾选说明（2026-09-21）**：本文件的实现/夹具项由 **M55（dev3，squash `78fc880`）** 交付；
> 独立验证由 **M60（dev 席位，`7433768`）** 完成（记录 `docs/team/reviews/M60.md`，PASS）。
> PM 亲自重跑其对抗性探针 `probe-enum.sh` → **`✓44 ✗0`**；M60 的全量 smoke 在其 tip 上 **`✓2723 ✗0`**。
> 一致性闸门另有一次与 F-D 方向相反的翻转（收紧校验器 → 走查红并点名键与值），证明它不是恒真仪式。

## 5. W — the M65 rework (apply: one brief; the user's decisions of 2026-09-21)

> Added by **M65** (propose, dev2). Items 1–4 are the delivered M55/M60 work and stay as history; the rework's
> interaction and responsiveness contract lives in `specs/panel/spec.md` and its measurements in design §5. The
> apply brief must grant `scripts/panel/**` **and** `scripts/lib/cmd-config.sh` (PM-owned) for 5.3; the fixture
> items below are dev-owned paths. **5 = one apply brief, 6 = a different agent's verify brief**; B4's archive
> prep reruns on the rework's tip.

- [ ] 5.1 `scripts/panel/src/App.tsx`: accepting a value entry (`current`/`default`/`choices.values`/`clear`) runs
  validation and write on that one accept — `setSetting(key, value, {dryRun:true, fingerprint})` then the same with
  `dryRun:false` and `allowDanger` only after the danger confirmation; no compose editor and no confirmation on the
  direct path; exit 7 keeps the existing danger confirmation frame; the free-text entry is the only
  `openCompose('setting', …)` caller; `keep-unset`, `pairlist` route and `esc` unchanged. Verify: 5.4's
  `choices-direct` scenario plus the existing `write`/`conflict` scenarios.
- [ ] 5.2 `scripts/panel/src/App.tsx` + `main.tsx`: the read leaves the interaction path — the picker and the
  free-text editor are built from the `settings` block already on screen (`openSettingsRow`/`chooseChoiceOption`
  stop forcing `refreshSettings()`), the fingerprint is that block's, and a settle refreshes only `['settings']` in
  the background without holding the receipt frame. Verify: 5.4's argv-log scenario (no read child inside the
  window) and the direct-path CAS scenario.
- [ ] 5.3 `scripts/lib/cmd-config.sh`: the read stops fanning out — one pass over the contract for values, inline
  comments and schema-unknown keys instead of the per-key `grep|head`+`awk` and the per-line `sed`, with byte-
  identical output. The evidence prototype is `docs/team/reports/M65-dev2/measure/read-prototype.sh` (semantic
  match on 111 records; ~186 ms vs ~3300 ms). Verify: the prototype's equality diff against
  `team config list --json` and `tests/panel-choices.sh read known walk` green; the wall-clock guard belongs to 5.5.
- [ ] 5.4 `tests/panel-p21.sh` (dev): a `choices-direct` scenario — accept an enum entry → the argv log carries
  `config set … --dry-run` then `config set … --yes --fingerprint …` as the only children, no confirmation line
  ever renders, the sha256 changed once, the audit grew one line and the receipt names the class's timing; the
  free-text entry still shows editor → confirmation → write; `esc` writes nothing; a first click focuses and a
  second click accepts; and the read-gap assertion: no `config list`/`__panel-data` child between the open/accept/
  free-text keystrokes and the frames they produce.
- [ ] 5.5 `tests/perf.sh` (dev): one visible, D33-shaped guard for the read — the fixture's `team config list
  --json` cost measured in the reference environment (SKIP + exit 4 when it is unavailable), never a smoke
  assertion and never a correctness red.
- [ ] 5.6 Flips (required in the apply report): **W-A** re-adding `refreshSettings()` to `openSettingsRow` turns
  5.4's read-gap assertion red; **W-B** restoring the pre-rework accept (editor instead of direct write) turns its
  argv assertion red; **W-C** re-introducing a per-key subprocess in the read fails the prototype's equality (or the
  5.5 guard); every one restored green.
- [ ] 5.7 Rebuild `scripts/panel/panel.js` with the pinned bun, second rebuild byte-identical; `panel-strings.mjs`,
  the snapshot suite and smoke's bundle assertions stay green.

## 6. V — independent verification of the rework (a different agent)

- [ ] 6.1 Rerun, out of tree and on the rework's tip: every flip of 5.6 (red and green), the `choices-direct` pty
  scenario, the prototype's equality diff, `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` and the
  **full** smoke; the record goes to `docs/team/reviews/<ID>.md` with a verdict and any findings (a PASS carrying
  findings is rework, not archive).
- [ ] 6.2 The PM reruns the measurement's one command (`docs/team/reports/M65-dev2/measure/run.sh`) plus the
  protected-branch gates on the merged tip before the archive; **M60's record covers the pre-rework interaction and
  does not cover this batch** — the rework needs its own verify record (D31: a different agent from 5's author).
