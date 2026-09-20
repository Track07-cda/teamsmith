# Tasks: `console-project-settings`

Five apply briefs, dispatched and verified one by one, in this order: **B1** the command (`memory-and-deps`: one
writer, the CAS, validation, the audit, the model seats), **B2** the read-only view (`panel`: the row set, the
classes, the filter, the refusals), **B3** the write path (`panel`: the editor, the confirmation, the danger step,
the receipts), **B4** the model seats (`panel`: the seats block, the source tri-state, the per-seat picker), **B5**
the read-only requirement's replacement and the ships-with docs plus the final gate.

Coverage map (requirement → items): `memory-and-deps` one writer → 1.1, 1.2, 1.6, 1.7, 1.9; CAS → 1.3; value
validation/quoting → 1.2, 1.4, 1.9; audit → 1.5, 3.3; seat models read/written as seats → 1.11, 1.12, 1.13, 4.1,
4.4; `panel` "shows the contract with its effect class" → 2.1, 2.2, 2.3, 2.4, 2.6; `panel` "writes only through
`team config set`" → 3.1, 3.2, 3.3, 3.5; `panel` "edits a seat's model and shows its source" → 4.1, 4.2, 4.3,
4.5; `panel` MODIFIED settings overlay → 2.3, 3.2; `panel` ADDED read-only replacement + REMOVED old title → 5.1,
5.2; every requirement is also exercised by the gate item 5.3 and mapped in the report item 5.4.

Path grants an apply brief must state (OWNERSHIP): `skills/teamsmith/scripts/**` (the new `lib/cmd-config.sh`,
`scripts/team`, `lib/cmd-watch.sh`, `lib/cmd-bootstrap.sh`, the panel sources and the committed bundle),
`skills/teamsmith/SKILL.md`, `skills/teamsmith/references/**` and `skills/teamsmith/templates/**` are PM-owned and
must be granted explicitly; `skills/teamsmith/tests/**` belongs to `agent:dev`; `openspec/changes/console-project-settings/**`
belongs to the phase's owner; `openspec/specs/**`, `docs/team/**` and the ledger stay PM-owned. Every batch ends
with a `panel.js` rebuild (B2 onward) so the pty fixtures exercise what the branch would ship. `[real]` items need
a real tmux pane/pty; each has a headless sibling.

## 1. B1 — the command: one writer, the CAS, validation and the audit (`memory-and-deps`)

- [ ] 1.1 New `skills/teamsmith/scripts/lib/cmd-config.sh`: the schema table (one row per key: `class`
  `apply|restart|refuse`, the restart target, `kind`, `form` `plain|export`, default, the danger rule) and
  `team_cmd_config_list [--json]` (resolved path, `fingerprint` = sha256 of the bytes, `mtime`, one record per
  schema key plus one per unknown key in the file, the audit tail) and `team_cmd_config_log [N]`; `scripts/team`
  gains the `config` dispatch entry and `team help` its line. Verify: `config-cli.sh list` asserts the JSON shape,
  the fingerprint of a fixture contract and that `team config list --json` on a project without a contract exits
  non-zero naming `team init`.
- [ ] 1.2 `skills/teamsmith/scripts/lib/cmd-bootstrap.sh`: rewrite `team_config_set_in_file` as the single writer —
  whole-line replacement with the inline comment preserved by a quote-aware scan, append on a new line (adding the
  missing final newline), the writer-derived value form (`KEY='value'`, `export KEY='value'` for `form=export`
  keys, `'` → `'\''`), refusals for a line break, a `#` and a `'` on the notify extension's eight keys — and make
  `team config set` the only command that calls it. Verify: `config-cli.sh writer` (the pre-change behaviours as
  named assertions: the comment survives, the newline-less append does not join, `bash -n` passes) **and the flip
  `config-cli.sh inject`**: `team config set TEAM_GATES '$(touch PWNED)' --yes` then sourcing the contract exits 0
  and creates no `PWNED`, while the old function's file does (both tails in the report).
- [ ] 1.3 The fingerprint CAS and `--dry-run`: `--fingerprint` compares sha256 and refuses with exit 3 (nothing
  written, `result=conflict` audited naming expected/actual); `--dry-run` performs class/value/fingerprint checks
  and writes neither the contract nor the audit. Verify: `config-cli.sh cas` asserts the three exit codes and the
  byte-identical contract after a stale-fingerprint write.
- [ ] 1.4 The validators: `kind` checks (`bool`, `int` with `min`/`max`, `seconds`, `mb`, `pct`, `enum`, `list`
  tokens, `path` existence/executability, `cmd`/template placeholders reused from the dispatch validator) with exit
  4 and the accepted domain in the message; the danger list (design §5) with exit 7 and `--allow-danger`; a
  `refuse` or unknown key with exit 5. Verify: `config-cli.sh validate` asserts the exit code and that the sha256
  is unchanged for each of `TEAM_PULSE_INTERVAL=0`, `TEAM_NOTIFY_TMUX=maybe`, `TEAM_MONITOR_UI=colour`,
  `TEAM_AGENT_MODELS='dev'`, `TEAM_PULSE_INTERVAL=0 --allow-danger` (still 4) and `TEAM_MIN_FREE_SWAP_MB=0`
  (7 → 0 with the flag).
- [ ] 1.5 The audit: one line per attempt in `<state>/config.log` with the UTC timestamp, result, `--actor`
  (default `cli`), key, single-quoted old/new and, for a conflict, expected/actual; `team config log [N]` and the
  `list --json` tail read at most the last 16 KiB. Verify: `config-cli.sh audit` asserts one line per attempt
  (including refusals), the `actor=panel` case, a value with spaces staying one line, and a 10 MiB log answered
  with at most five lines.
- [ ] 1.6 Completeness both ways: a test that extracts every key of `templates/config.sh.tmpl` and every
  backticked `TEAM_*` of `references/config.md` and diffs them against the schema plus the explicit "not a contract
  key" allowlist, and the reverse direction. Verify: the test exits 0 and names the missing/extra keys; deleting
  one schema row (or adding one template key) turns it red with the key named — the flip.
- [ ] 1.7 The callers fail loudly: `team init`/`team bootstrap` report a refused `--gates`/`--install` value and
  exit non-zero instead of continuing without the key. Verify: in a scratch project `team init --gates 'a # b'`
  exits non-zero and the contract carries no `TEAM_GATES` line; the pre-change silent skip is the red side.
- [ ] 1.8 `skills/teamsmith/references/config.md`: a section stating the contract's classes, the value form, the
  danger list, the `team config list|set|log` surface and the audit file, with the class pointers for the
  `refuse` families. Verify: the section's own examples run as written (copy-paste), and `config-cli.sh
  docs` greps that every schema key appears in the file.
- [ ] 1.9 Flip bundle for B1: restore the old writer body (double quotes, comment drop, no `bash -n`) on a scratch
  copy → `inject`, `writer` and `validate`'s trailing-backslash case go red; restore → green. Verify: both tails in
  the report.
- [ ] 1.10 Register `config-cli.sh` in `skills/teamsmith/tests/smoke.sh` (headless section) so the gate runs it.
  Verify: `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` runs the new section and passes; a deliberately
  broken assertion fails the run.
- [ ] 1.11 `team config list --json`'s `models` block: `{default, known[], seats:[{agent, model, source,
  override}]}` over the roster plus `pm`, with `source` computed by the same semantics as `team_agent_model_src`
  (`config`/`explicit`/`record`) and `known[]` the union of the configured and recorded models. Verify:
  `config-cli.sh models` builds the three source fixtures (no record / explicit record / differing record) and
  asserts `list --json` and `team ps`'s label agree.
- [ ] 1.12 `team config set-agent-model <seat> <model|->`: the pair-list transform (parse + re-serialize
  `TEAM_AGENT_MODELS`, or `TEAM_PM_MODEL` for `pm`), `-` removing the token, the same writer/CAS/audit/`--dry-run`
  rules as `set`, and the seat allowlist (roster + `pm`, exit 5) plus the `provider/model` shape (exit 4). Verify:
  `config-cli.sh seats` asserts the one-token diff, the removal fallback, the unknown seat (both in the pair form
  and via `set TEAM_AGENT_MODELS 'dev4=…'`), the shapeless model and the `pm` seat's `TEAM_PM_MODEL` line.
- [ ] 1.13 The unknown-seat report: a `dev4=…` token already in the file produces a warning in the key's
  `list --json` record instead of being silently ineffective. Verify: `config-cli.sh models`'s hand-edited case
  exits 0 with the warning naming `dev4` and no `dev4` seat row; the pre-change silence is the red side.

## 2. B2 — the view: the contract, its classes and its refusals (`panel`)

- [ ] 2.1 `scripts/lib/cmd-watch.sh` + `panel/src/{types,data}.ts`: a console-only `settings` block
  (`team __panel-data --block settings`) whose payload is exactly `team config list --json`, built on demand (the
  `detail` block's pattern) and never part of a frame's default cadence; `BLOCK_NAMES` and the type gain it.
  Verify `[real]`: `team __panel-data --block settings` inside a fixture project prints the same JSON as
  `team config list --json`, and `team monitor --print`/`--json` stay byte-identical to the pre-change output apart
  from the timestamp.
- [ ] 2.2 `panel/src/layout.ts`: the project-settings view — title, group headings (not focusable), rows
  (`cursor key … value · badge`, the inline comment dimmed when present, the unset marker with the default), the
  window's hidden-row counts at both edges, the key band chips (`↑/↓`, `enter`, `/ filter`, `esc`) and the audit
  footer (at most three lines). Verify `[real]`: the view renders at 160/100/59 columns with no overrun, no
  `0x1b` byte in a capture, and the same frame twice for the same geometry.
- [ ] 2.3 `panel/src/App.tsx`: the view's state and origin (opened from the overlay's navigation row, `esc` returns
  to the overlay with that row selected, `q` keeps its global meaning), the focus/window, the filter line (a third
  mode of the compose editor, matching key or value, `esc` clears), the row click targets (focus, second click
  edits), the refuse-row path (no editor; the command's exit-5 message shown) and the `panel.conf`-untouched rule.
  Verify `[real]`: `skills/teamsmith/tests/panel-p21.sh settings` drives a fixture pane through each scenario of
  the first `panel` requirement (the rows/classes/default case, the scratch-schema case, the refuse case, the
  filter case, the focus/window/click case, the origin/`q` case).
- [ ] 2.4 `panel/src/strings/{zh,en}.ts`: the view's labels, the group names, the four class badges and the audit
  footer heading, in both languages. Verify: `node skills/teamsmith/tests/panel-strings.mjs` exits 0, and deleting
  one new key from `en.ts` makes it exit non-zero naming it — the flip.
- [ ] 2.5 Regression: every existing panel scenario (`panel-b2.sh`, `panel-b3.sh`, the snapshots) stays green with
  no re-pin, and `panel-cpu.sh` still reports <1% of one core and an uncached frame within 2 s with the view
  opened and closed. Verify `[real]`: the runs' tails.
- [ ] 2.6 Flip: hardcode the three classes for a handful of keys inside the bundle (the rejected second table) and
  rebuild → the "row set and classes come from the command" assertion (2.3) fails on the scratch-schema case;
  restore → green. Verify: both tails in the report.

## 3. B3 — editing: validation, confirmation and the honest receipt (`panel`)

- [ ] 3.1 `panel/src/{main,compose,App}.tsx`: the `setting` editor mode and the write flow — the editor opens
  holding the file's value or the schema default, `enter` runs `team config set … --dry-run` and renders the
  confirmation line (old → new, the class timing, the restart command for `restart`), the second `enter` runs
  `team config set … --actor panel --yes` (the fingerprint pinned when the editor opened), `esc` cancels with
  nothing written, the danger reply (7) demands one more `enter`, the exit-code map yields the four honest
  receipts (written / read-only / invalid / conflict / write error), and every settle re-reads the list and the
  audit footer. Verify `[real]`: `panel-p21.sh write` asserts the one-changed-line diff with the comment intact,
  the wrapper log's `--dry-run` + `--yes` pair, the cancel case (no audit line, no temp file), the invalid case
  (draft kept, sha256 unchanged), the danger two-step, the restart honesty case (the running console still reports
  `refresh_s` 3 while `team monitor --json` reports 7) and the audit footer.
- [ ] 3.2 The conflict case end to end: the fixture changes the contract under the open editor → the receipt names
  the conflict, the contract keeps the other writer's bytes, the view shows that writer's value, and the audit
  gained one `result=conflict` line. Verify `[real]`: the `panel-p21.sh conflict` scenario's capture and the
  hashes in the report.
- [ ] 3.3 Regression: the `m`/`f`/`s` actions, the four receipts and the compose editor's own scenarios stay green;
  the read-only sweep (5.1's fixture) is run here on the write paths. Verify `[real]`: the runs' tails.
- [ ] 3.4 Flip: drop the `--fingerprint` argument from the panel's `set` call and rebuild → 3.2's conflict scenario
  fails (the write overwrites); restore → green. Verify: both tails in the report.
- [ ] 3.5 Performance: `panel-cpu.sh` again with a view opened, an editor typed in and one write settled
  (<1% of one core, uncached frame ≤2 s). Verify `[real]`: the log in the report.

## 4. B4 — the model seats: per-seat editing and the source tri-state (`panel`)

- [ ] 4.1 `panel/src/layout.ts` + `types.ts`: the seats block — one row per roster seat plus `pm`, showing the
  displayed model, the source badge from the command's three labels (`配置`/`显式`/`历史记录`) and whether the seat
  carries an override; the source and model come from `team config list --json`'s `models` block (no fourth state,
  no bare model name), and the block renders even when the contract has no override at all. Verify `[real]`:
  `skills/teamsmith/tests/panel-p21.sh seats` renders the three source fixtures and asserts each badge and the
  matching `team ps` label.
- [ ] 4.2 `panel/src/App.tsx`: the seat picker — `enter` on a seat row opens the known-model list (the command's
  `known[]`) plus a free-text line (the compose editor's mode), the confirmation names the seat, the new model and
  the next-spawn rule, `-` removes the override, and the write goes through `team config set-agent-model … --actor
  panel --yes` with the same receipts as B3. Verify `[real]`: `panel-p21.sh seats` asserts the picker's write, the
  one-token diff, the removal case and the unknown-seat/shapeless-model receipts.
- [ ] 4.3 The honesty check `[real]`: with a running fixture seat window, a seat-model write leaves the window's
  process arguments and `state/<agent>.env` unchanged, the receipt prints no restart, and
  `team dispatch <seat> <ID> <brief> --print` afterwards renders the new model. Verify: the `panel-p21.sh seats`
  capture plus the printed dispatch command in the report.
- [ ] 4.4 Regression: `team ps`/`roster`'s model column and the `history` label semantics are unchanged (the seats
  block reads the same function), the smoke suite's status sections stay green, and `--print`/`--json` stay
  byte-stable. Verify `[real]`: the runs' tails.
- [ ] 4.5 Flip: make the seats block print the configuration model with no source badge (the rejected bare model
  name) and rebuild → 4.1's differing-record assertion fails; restore → green. Verify: both tails in the report.

## 5. B5 — the read-only requirement's replacement and the ships-with docs (`panel` + docs)

- [ ] 5.1 The read-only discipline as a fixture: extend the existing `readonly` sweep to watch the contract and
  `state/config.log` as well as `state/`, `docs/` and the inbox, and to assert that the four actions are the only
  `team` invocations the wrapper logs (`draft send`, `outbox flush`, `standby`, `config set` — with the
  `--dry-run`/`--yes` pair counted as one action) and that a cancelled edit changes nothing. Verify `[real]`:
  `panel-p21.sh readonly` exits 0; an intentionally undocumented key (or a direct write attempt from the panel) is
  the red side.
- [ ] 5.2 Ships-with docs: `skills/teamsmith/SKILL.md`'s command table gains the project-settings row (and the
  monitor row's pointer to `team config`), `team help` lists `config list|set|log` in the observation/workflow
  section, and `templates/config.sh.tmpl` gains the one-line pointer to `team config` (the template keeps every
  key as it is). Verify: `team help | grep -A2 '^  config'`, and a scratch `team init --force` still renders a
  contract the CLI sources and the notify extension parses.
- [ ] 5.3 Final: rebuild `skills/teamsmith/scripts/panel/panel.js` from the sources, commit it, and run the gate
  in full: `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`.
  Verify: the tail of the full run and the bundle's freshness check (`grep` for a new label plus the smoke
  section's byte-identical rebuild where the sandbox build is available).
- [ ] 5.4 The report carries, per requirement, the item that moves it, the fixture that can fail on it, the flip
  evidence, the coverage map above with every item accounted for, and the key-class table checked against
  `templates/config.sh.tmpl`.
