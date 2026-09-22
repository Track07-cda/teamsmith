# Tasks: `pi-only-scope`

Planning only — nothing in this file is executed by the propose task (P34). One apply brief: the three deltas
land together because they are one wording decision (a half-applied change leaves the promise alive in one
place and dead in another, and `openspec validate --all --strict` would still be green). No test file changes
(D35): every item below is verified with the existing suite, a scratch-copy flip, or a two-tree comparison.

Coverage map (requirement → items): **R1** (`agent-adapters`) → 1.1–1.8, 4.2; **R2** (`init-skill`) → 2.1–2.3;
**R3** (`memory-and-deps`) → 3.1–3.3; gates → 4.1–4.4; report → 5.1.

Path grants the apply brief must state (OWNERSHIP): `README.md`, `skills/teamsmith/SKILL.md`,
`skills/teamsmith-init/SKILL.md`, `skills/teamsmith/references/**`, `skills/teamsmith/templates/**`,
`skills/teamsmith/scripts/lib/cmd-config.sh` (only the four adapter rows' 8th field and the header comment's
sentence about that field) and `skills/teamsmith/scripts/monitor.mjs` (one message sentence) are PM-owned and
need the explicit grant. `skills/teamsmith/tests/**` is **not** granted — no test edit is allowed; a red test
is a finding for the PM, not a fix. `openspec/changes/pi-only-scope/**` belongs to the phase's owner;
`openspec/specs/**`, `docs/team/**` and `README.md` render no base-spec edit.

Fixture notes: every fixture clears inherited team identity (`TEAM_*`, `TMUX`, `TMUX_PANE`) and writes only
inside its scratch repo; the two-tree comparison for item 4.2 uses a second checkout of the pre-change
revision (`git worktree add` in the fixture, never the main worktree) and the same fixture contract; the
`TEAM_CONFIG_TREE` flips follow `config-cli.sh`'s existing red/green pattern.

## 1. The promise is Pi; the seam is frozen (`agent-adapters` R1)

- [x] 1.1 `README.md`: line 5 stops advertising another harness (it keeps the Pi promise and the frozen-seam
  pointer); the `install.sh` section (line 61) stops routing through another CLI and says what the installer
  really does — place the skill *files* where a skill directory can be read. Verify: `grep -nE 'any TUI
  agent|another TUI agent|其它 TUI agent|任意 TUI agent' README.md` prints nothing; the Pi ≥ 0.76.0 requirement
  row and the `install.sh` options block are still there.
- [x] 1.2 `skills/teamsmith/SKILL.md`: the `description` sentence names Pi and the frozen seam (no banned
  phrase); `## Agent adapters (any TUI agent can be a worker)` becomes a Pi/frozen heading; the deep-reading
  row points at the frozen seam instead of "codex/opencode/any TUI agent". Verify: the banned-phrase grep is
  empty; `sed -n 's/^description:[[:space:]]*//p' | head -1 | wc -c` is ≤ 1024; the description still contains
  `teamsmith-init`; smoke §18b is green without a test edit.
- [x] 1.3 `skills/teamsmith/references/agent-adapters.md`: title and intro carry the frozen wording before the
  first worked non-Pi example, with the no-compatibility sentence; the worker launch table, the notify table
  and the `<!-- pm-side:begin -->`/`<!-- pm-side:end -->` block keep every row and placeholder. Verify: §6f's
  `adapter_doc_tokens`/`adapter_doc_unsupported` and §6i's PM scanners are green unmodified; the banned-phrase
  grep is empty.
- [x] 1.4 `skills/teamsmith/references/config.md`: the adapter section heading and its note carry the frozen
  wording (reserved for a possible future non-Pi adapter, no compatibility promise, not asked in the init
  questionnaire); the four key rows keep their documented domains. Verify: `grep -n 'internal seam (frozen)'
  skills/teamsmith/references/config.md` prints the note; `config-cli.sh completeness` is green.
- [x] 1.5 `skills/teamsmith/references/migration.md`: lines 137 and 214 stop calling a non-Pi CLI a supported
  route; they state the seam is frozen and the PM side runs Pi. Verify: the banned-phrase grep is empty; the
  file's other upgrade rows are untouched.
- [x] 1.6 `skills/teamsmith/references/troubleshooting.md`: the custom-adapter diagnostics (§4d and the
  identity/PM notes that reference `TEAM_AGENT_CMD`) gain one sentence that the seam is an internal frozen
  seam, so the diagnostics do not read as a support offer. Verify: the banned-phrase grep is empty; the
  diagnostics' commands and paths are unchanged.
- [x] 1.7 `skills/teamsmith/templates/config.sh.tmpl`: the adapter section comment carries the frozen wording,
  the four keys stay declared (empty) in their current order, and the opencode worked example leaves the
  template (worked examples live only in `references/agent-adapters.md`, under the frozen wording). Verify: a
  rendered contract names all four keys and the frozen sentence and contains no `opencode`; `config-cli.sh
  completeness` and the callers section are green.
- [x] 1.8 `skills/teamsmith/scripts/monitor.mjs`: the degradation message at line 613 stops offering another
  TUI agent (it names the frozen `TEAM_AGENT_LOG_GLOB` seam instead); the comment at line 7 is reworded with
  it. No other byte of the file moves. Verify: the banned-phrase grep is empty; with no matching session log
  the message still prints (its condition is untouched); no test edit.

## 2. The questionnaire is Pi-only (`init-skill` R2)

- [x] 2.1 `skills/teamsmith-init/SKILL.md` item 2: drop the "Running workers with something other than Pi?
  Then also fill the four adapter keys … `references/agent-adapters.md`" half. Verify: `grep -nE
  'TEAM_AGENT_CMD|TEAM_AGENT_BIN|TEAM_AGENT_NOTIFY_CMD|TEAM_AGENT_LOG_GLOB|agent-adapters\.md'
  skills/teamsmith-init/SKILL.md` prints nothing.
- [x] 2.2 Same file, item 4: "Harness and installed plugins" becomes "Pi version and installed plugins" — it
  prescribes `team doctor`'s `pi` row (the Pi ≥ 0.76.0 floor) and its `已装插件 packages` row, keeps the
  information-only/no-third-party-recommendation sentence verbatim, and deletes the harness question and the
  `omp` branch. Verify: `grep -nE '\bomp\b|another CLI|which harness' skills/teamsmith-init/SKILL.md` prints
  nothing; `wc -l` is still ≤ 100; smoke §18b (three beats, description routing, fingerprint scope) is green.
- [x] 2.3 The `teamsmith-init` description is checked, not changed: it contains no harness phrase and no
  day-to-day phrase. Verify: §18b's `p16_desc_pollution` is empty and both descriptions are ≤ 1024 characters.

## 3. The keys are marked as a frozen seam (`memory-and-deps` R3)

- [x] 3.1 `skills/teamsmith/scripts/lib/cmd-config.sh`: the four adapter rows' 8th field carries
  `内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问`, and the schema header comment's
  line about the field is widened from `refuse` routes to "the free-text route/note the panel shows for
  `refuse` routes and frozen-seam notes". No other schema change. Verify: `team config list --json` in a
  fixture reports `"class":"apply"` and that route on `TEAM_AGENT_CMD`, `TEAM_AGENT_NOTIFY_CMD`,
  `TEAM_AGENT_LOG_GLOB`, `TEAM_AGENT_BIN`; the human table's header is still `KEY CLASS KIND VALUE`;
  `config-cli.sh` is green.
- [x] 3.2 `skills/teamsmith/references/config.md`: the four key rows (or the section note) carry the same
  three facts in English, cross-referencing `agent-adapters.md` for the reason. Verify: `config-cli.sh docs`
  (every schema key documented) and the M73 English-body check are green.
- [x] 3.3 `skills/teamsmith/templates/config.sh.tmpl` (shared with 1.7): the rendered contract's adapter
  section names the marking, so a new project reads it from the file itself. Verify: a rendered
  `.pi/team/config.sh` carries the four keys (empty) and the frozen sentence.
- [x] 3.4 Flip fixtures (report both tails): (a) clear one adapter row's 8th field in a scratch tree via
  `TEAM_CONFIG_TREE` → the config section exits non-zero naming that key; restore → green. (b) `team config
  set TEAM_AGENT_CMD 'myagent {prompt}' --yes` → 0 with one `result=ok` audit line; `team config set
  TEAM_AGENT_CMD $'line1\nline2' --yes` → 4 with the sha unchanged (class stayed `apply`, no refusal route).

## 4. Gates and invariance

- [x] 4.1 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` (already green at propose time; must
  stay green with the deltas on disk).
- [x] 4.2 Byte invariance, no new test: in the fixture, run `team dispatch dev T1.1 <brief> --print` and the
  PM renderer on this branch and on the pre-change revision (a scratch `git worktree`), then `diff` the four
  strings; paste the empty diff. Also paste the existing §6i `LEGACY_REF` assertion line (PM literal) and the
  §6f worker fragments (`-e …/team-notify.ts`, `-e …/team-bg.ts`, `-e …/team-inbox-watch.ts`, `--skill`,
  `--session-id`) — all unmodified.
- [x] 4.3 `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` in-batch, then the full gate
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`
  before delivery (one full run; the §6f/§6i/§15b/§15c/§18b/M73/config-cli sections are the ones this change
  can move). Report the panel sections' outcome for the four new note lines (D3's named risk: whether any
  window count moved).
- [x] 4.4 Flip set, all tails in the report: banned phrase appended to a scratch `README.md` (red), removed
  (green); init checklist with `omp`/`TEAM_AGENT_CMD` appended (red), removed (green); one adapter row's
  marking cleared (red), restored (green).

## 5. Report

- [x] 5.1 `docs/team/reports/<apply task>.md`: both acceptance tails; delta→requirement map; the
  requirement→item and scenario→fixture maps; every flip's red/green tail (4.4); the two-tree invariance diff
  (4.2); the four-key class census (`apply` before and after); the panel note-line outcome (4.3); and the
  list of paths the diff touched.

> **PM 勾选说明（2026-09-22）**：propose=**P34（dev3）**；apply=**P39（dev3，`9324a40`）**；
> verify=**P41（dev，`e9236d1`）** —— PASS（reviews/P41.md）：R1–R5 独立复跑（含三条变异）+ **它自己复现的两版渲染
> diff 逐字节一致**；F1 是我的验收命令在非线性历史上不成立（P35 后改过 `tests/smoke.sh`），按本 change 自身区间算
> 测试文件改动 = 0，判为**任务书写法问题、非缺陷**。
