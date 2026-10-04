# P39 · pi-only-scope apply — the contract promises Pi; the launch/notify seam is a frozen internal seam

agent: dev3   status: DONE   time: 2026-09-22T07:25Z
branch: `task/P39-pi-only-scope-apply-pi-only-`   PR/MR: - (local mode: no push, the branch stays local)

Design truth: `openspec/changes/pi-only-scope/design.md` (D0–D7) + `tasks.md`; proposal review
`docs/team/reviews/pi-only-scope-proposal.md` (ACCEPTED). Base revision: `d2b73b8` (the P39 brief commit).

## Deliverables

| Path | What |
|---|---|
| `README.md` | line 5 keeps the Pi promise and points at the frozen seam; the `install.sh` section says what the installer really does (place skill **files** where a skill directory can be read) instead of routing through another harness |
| `skills/teamsmith/SKILL.md` | description names Pi + the frozen seam (994 chars, still routes `teamsmith-init`); `## Agent adapters (Pi; the seam is internal and frozen)`; intro states reserved/no-compatibility/not-asked; deep-reading row retargeted |
| `skills/teamsmith-init/SKILL.md` | item 2 drops the four-key/other-harness half; item 4 becomes "Pi version and installed plugins" (Pi ≥ 0.76.0 floor + `已装插件 packages`, information only); 66 lines (`≤ 100`) |
| `skills/teamsmith/references/agent-adapters.md` | title/intro state `internal seam (frozen)` with the no-compatibility sentence **before** the first worked non-Pi example; PM note + unsupported list carry it; worker/notify tables and the `pm-side` block untouched |
| `skills/teamsmith/references/config.md` | adapter section heading + note carry the marking; the four key rows keep their documented domains |
| `skills/teamsmith/references/migration.md` | PM-CLI row and §8 "not supported" state the seam is frozen and the PM side runs Pi |
| `skills/teamsmith/references/troubleshooting.md` | §4d, §14 and the identity note carry the frozen wording (maintenance diagnostics, not a support offer) |
| `skills/teamsmith/templates/config.sh.tmpl` | adapter comment carries the marking; the four keys stay declared empty in order; the worked opencode example leaves the template (points at the reference doc) |
| `skills/teamsmith/scripts/monitor.mjs` | degradation message names the frozen `TEAM_AGENT_LOG_GLOB` seam (no other-harness offer); line-7 comment reworded with it |
| `skills/teamsmith/scripts/lib/cmd-config.sh` | the four adapter rows' 8th (free-text route/note) field gets the marking; the header comment widens that column's description; nothing else moves |
| `docs/team/reports/P39-dev3.md` | this report |

**Zero test file changes; zero behaviour changes; no version bump; no npm publish.**

## Delta → requirement map (design D0)

| Delta | Capability | Requirement | Items |
|---|---|---|---|
| `specs/agent-adapters` | `agent-adapters` | R1 "The contract promises Pi; the launch and notify seam is an internal frozen seam" | 1.1–1.8 · 4.2 |
| `specs/init-skill` | `init-skill` | R2 "The new-project questionnaire checks Pi's version and its plugins, and asks nothing about adapters" | 2.1–2.3 |
| `specs/memory-and-deps` | `memory-and-deps` | R3 "The worker-launch keys are an internal frozen seam, not a supported extension point" | 3.1–3.4 |

Scenario → fixture (design §5): R1/1 → the claimed-surface walk + the scratch-copy flip (flip A, below);
R1/2 → `dispatch --print` with a custom template; R1/3 → `config-cli.sh` §6f/§6i doc↔engine scanners +
template read; R1/4 → the two-revision render diff + §6i's `LEGACY_REF`; R1/5 → §18b; R2/1 → the init
walk + flip B; R2/2 → §15b/§15c; R2/3 → `bootstrap --print` + `config-cli.sh completeness`; R3/1 → flip C
+ `config list --json`; R3/2 → the writable/domains section; R3/3 → the rendered contract + completeness.

## Acceptance (all commands actually run from the worktree)

### 1 · `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`

```
✓ change/pi-only-scope
Totals: 16 passed, 0 failed (16 items)
openspec rc=0
```

### 2 · `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` (in-batch)

```
== 结果 ==  ✓ 2301  ✗ 0
smoke 全绿
```
(One FAST run after the whole edit batch — the brief's "每批" is this change's single batch; the full run is
the delivery gate below, per the thread's resource discipline.)

### 3 · Full gate, once, before delivery: `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`

```
openspec rc=0
== 结果 ==  ✓ 2810  ✗ 0
smoke rc=0
```

Sections this change can move, from that run:

| Section | Line |
|---|---|
| §6f doc↔engine | `✓ 文档占位符表里的 token 都被引擎支持` / `✓ 每个 launch 占位符都在文档里出现过` / `✓ 翻转自测：文档里混进未支持的占位符会被抓到` |
| §6i PM invariance | `✓ M8.1 默认渲染与历史逐字节一致（TEAM_PM_CMD/BIN/RESUME_ARGS 全空；M27 起含 -e bg、M30 起再含 -e inbox-watch、M36 起带闸门 exports 前缀、M40 起带身份环境前缀）` |
| §15b Pi floor | `✓ M39：--help 走 stderr 的 pi 不再被误报「版本过旧」（探针看两流）` |
| §15c plugins | `✓ doctor 有「已装插件」行` / `✓ doctor 输出里没有任何安装推荐` / `✓ 不再点名第三方包（一）（二）` |
| §18b split invariants | `✓ 两条 description 路由干净（init 短语只在 init 侧，日常短语只在日常侧）` / `✓ 日常 description 点名 teamsmith-init` / `✓ 两条 description 都在 1024 上限内（日常 994 / init 800 字符）` / `✓ 改 init SKILL.md：会话指纹不变（init 文本不吵醒在跑的 PM）` |
| §18 M73 | `✓ references/** 与 SCOPE.md 的正文全英文（CJK 只出现在代码 span / 围栏块里）` |
| §14b stale commands | `✓ 真树无残留（词边界口径：team merge|pr|gh|gl）` |
| §33 config-cli | `✓ 33 config-cli.sh 全绿（133 条断言）` |
| §38 panel | `✓ 38-a panel-choices.sh 全绿（ ✓ 41 ✗ 0）` / `✓ 38-b panel-p21.sh choices 全绿（ ✓ 110 ✗ 0）` / `✓ 38-e 视图分组：layout.ts 无类分组表、无键→域表` |

### 4 · Panel note-line outcome (design D3's named risk)

The four rows now render a note line (`layout.ts:1289` `warning || route || comment`; row height 2 at
`layout.ts:1380`), so the settings view was run beyond the gate:

```
$ bash skills/teamsmith/tests/panel-p21.sh settings groups wheel
== 结果 ==  ✓ 87  ✗ 0        (settings + groups + wheel; rc=0)

# scratch copy of the same fixture (+2 assertions on the adapter row; tests/** in the repo untouched):
$ TEAM_P21_TREE=/tmp/p39-evidence/p21tree bash .../panel-p21.sh settings
  ✓ P39: adapter row renders the frozen note
  ✓ P39: the row still names its raw key
  --- P39 adapter row frame (grep) ---
    │ › 席位启动命令           "" · 立即生效  内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问  │
    │  命令行：team config set TEAM_AGENT_CMD <新值>                                                                    │
== 结果 ==  ✓ 41  ✗ 0
```

**No window count moved**: the settings view's window/pagination, focus-push, click targets, filter and
wheel assertions (§87 green above) are unchanged with the note lines present. No panel source change was
needed — the note comes from the schema row's free-text column (the brief's conditional panel grant was
not triggered).

## R1 zero behaviour · two-revision render diff (`dispatch --print`)

Technique: both revisions are staged with `git archive <rev> | tar -x -C $P` into the **same scratch path**
and rendered against the **same fixture project** (`team init` + `team task T1.1`, anchor declared,
`.worktrees/dev` on the task branch, `TEAM_PI_BIN` = a stub, `TEAM_REQUIRE_OPENSPEC=0`). Same path ⇒ a raw
`diff` is meaningful (a two-worktree diff would differ only by the tree's own directory name, which the
rendered command embeds).

```
$ render d2b73b8  # pre-change revision
$ render HEAD     # this branch
render rc: pre=0 branch=0
$ diff pre.out branch.out
(empty; exit 0)          # byte-identical: footer "=== 提示词（N 字） ===" and every line match
```

The rendered worker string (identical on both revisions):

```
cd /tmp/p39-evidence/fx/.worktrees/dev && export PATH=/tmp/p39-evidence/same-tree/skills/teamsmith/scripts/shim:"$PATH"; export TEAM_TMUX_CALLS_LOG=/tmp/p39-evidence/fx/.pi/team/state/tmux-calls.log; export TEAM_TMUX_REAL=/tmp/p39-evidence/shim/tmux; /tmp/p39-evidence/fake-bin/pi --provider deepseek --model deepseek-flash -e /tmp/p39-evidence/same-tree/skills/teamsmith/extension/team-notify.ts -e /tmp/p39-evidence/same-tree/skills/teamsmith/extension/team-bg.ts -e /tmp/p39-evidence/same-tree/skills/teamsmith/extension/team-inbox-watch.ts --skill /tmp/p39-evidence/same-tree/skills/teamsmith --session-id p39ev-dev "$0"
```

Assertions on that string: carries `extension/team-notify.ts`, `extension/team-bg.ts`,
`extension/team-inbox-watch.ts`, `--skill`, `--session-id p39ev-dev`; no leftover `{`; `adapter: built-in
(Pi)`; the two revisions' strings are identical. PM side: §6i's `LEGACY_REF` literal assertion is green
unmodified (line quoted above). R1/2 (seam still usable, no refusal):

```
$ TEAM_AGENT_CMD='myagent run --ask {prompt}' TEAM_AGENT_BIN=bash team dispatch dev T1.1 <brief> --print
rc=0 · adapter: custom: myagent run · myagent run --ask "$0" · no 'unsupported' error
```

## Flip evidence (red → green, raw output)

### Flip A · banned phrase (`README.md` in a scratch copy of the nine claimed files)

```
clean copy: no banned hit (green)
--- red-side hits ---
README.md:137:See the roadmap for any TUI agent support.
✓ appended phrase caught in README.md with its line   (searcher exits non-zero)
restored copy: green again
--- real tree walk (claimed surface) ---
✓ real tree: zero banned hits
```

Claimed surface walked: `README.md`, `skills/teamsmith/SKILL.md`, `skills/teamsmith-init/SKILL.md`,
`references/{agent-adapters,config,migration,troubleshooting}.md`, `templates/config.sh.tmpl`,
`scripts/monitor.mjs`. Out of the claimed surface by D2 (kept byte-for-byte): source comments in
`scripts/lib/{common,cmd-project}.sh`, the test suite's section titles, `CHANGELOG.md`.

### Flip B · init checklist (`omp` + `TEAM_AGENT_CMD` in a scratch copy)

```
clean copy: no harness/keys hit (green)
--- red-side hits ---
68:Also fill `TEAM_AGENT_CMD` when the harness is omp.
✓ appended omp/TEAM_AGENT_CMD caught   (searcher exits non-zero)
restored copy: green again
--- real init SKILL ---
✓ real init SKILL: zero hits
✓ real init SKILL names the Pi floor          (Pi ≥ 0.76.0)
✓ real init SKILL names the plugin row        (已装插件 packages)
✓ init SKILL ≤ 100 lines (66)
```

### Flip C · schema marking cleared in a `TEAM_CONFIG_TREE` scratch tree

```
green side (this branch): team config list --json
  ok: four records class=apply + frozen route
red side (scratch tree, TEAM_AGENT_CMD row's 8th field cleared)
  missing: TEAM_AGENT_CMD            (non-zero, names the key)
restore: TEAM_CONFIG_TREE=<this tree> bash tests/config-cli.sh list  →  green
```

## R3 marking / writable / domains

`team config list --json`, the four records (verbatim):

```
TEAM_AGENT_CMD        class=apply kind=tpl  form=plain default='' route=内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问
TEAM_AGENT_NOTIFY_CMD class=apply kind=tpl  form=plain default='' route=内部接缝（frozen）：…
TEAM_AGENT_LOG_GLOB   class=apply kind=text form=plain default='' route=内部接缝（frozen）：…
TEAM_AGENT_BIN        class=apply kind=path form=plain default='' route=内部接缝（frozen）：…
```

The human table header is still `KEY … CLASS … KIND … VALUE`. Writable/domains (fixture contract):

```
rc: valid template=0 · unresolvable TEAM_AGENT_BIN=0 · two-line template=4 (sha unchanged)
audit: 2026-09-22T07:13:57Z result=ok actor=cli key=TEAM_AGENT_BIN old='' new='/nonexistent/cli'
       2026-09-22T07:13:57Z result=invalid actor=cli key=TEAM_AGENT_CMD old='myagent {prompt}' new='line1
TEAM_PROJECT (refuse class) → exit 5   # the frozen note did not turn apply into refuse
```

Class census, `apply` before (`d2b73b8`) and after (this branch) on all four keys:

```
TEAM_AGENT_CMD class=apply        TEAM_AGENT_CMD class=apply
TEAM_AGENT_NOTIFY_CMD class=apply TEAM_AGENT_NOTIFY_CMD class=apply
TEAM_AGENT_LOG_GLOB class=apply   TEAM_AGENT_LOG_GLOB class=apply
TEAM_AGENT_BIN class=apply        TEAM_AGENT_BIN class=apply
```

## Paths the diff touched (`git diff --stat d2b73b8..HEAD`)

```
 README.md                                      |  5 +++--
 skills/teamsmith-init/SKILL.md                 | 11 ++++-------
 skills/teamsmith/SKILL.md                      | 14 ++++++++------
 skills/teamsmith/references/agent-adapters.md  | 18 +++++++++++++-----
 skills/teamsmith/references/config.md          | 12 +++++++++---
 skills/teamsmith/references/migration.md       |  7 ++++---
 skills/teamsmith/references/troubleshooting.md | 10 ++++++++--
 skills/teamsmith/scripts/lib/cmd-config.sh     | 10 +++++-----
 skills/teamsmith/scripts/monitor.mjs           |  4 ++--
 skills/teamsmith/templates/config.sh.tmpl      | 12 +++++-------
 10 files changed, 61 insertions(+), 42 deletions(-)
```

Commits (small steps, one per batch):

```
8781169 P39: promise Pi in README + daily skill, mark the seam frozen (R1 items 1.1-1.2)
1d6f023 P39: Pi-only init questionnaire (R2 items 2.1-2.2)
545ab94 P39: frozen wording in the adapter docs and the monitor degradation message (R1 items 1.3-1.6, 1.8)
231a48f P39: the contract template marks the seam frozen and drops the opencode example (R1 item 1.7, R3 3.3)
b88e112 P39: the four worker keys carry the frozen marking in the schema's free-text column (R3 3.1)
```

## Decisions and deviations

- **Same-path revision staging for the render diff** (documented above): it is what makes a *raw* empty
  `diff` honest; a two-worktree diff can only prove path-independent rendering after normalizing the
  tree's own skill-dir prefix. The strict statement: the rendering code and the two built-in command
  strings are byte-identical for identical inputs.
- **No panel source change**: the note is schema data rendered through the existing read
  (`layout.ts:1289`), so the conditional `panel/src/strings/*.ts + panel.js` grant was not triggered.
- **References wording is English** (M73); the schema note and the monitor message are `scripts/**` and
  stay Chinese, like every other route/comment there.
- **`scripts/**` source comments keep their bytes** (D2): `common.sh`, `cmd-project.sh`, the test-section
  titles and `CHANGELOG.md` still contain "任意 TUI agent"; they are outside the claimed surface.
- **No `ROADMAP.md` edit** (PM-owned, D7): the ROADMAP still advertises M3 — the PM asked for a note, not an edit.
- Deviations from the brief: none. (The brief's item 2.3 "description checked, not changed" holds: init
  description 800 chars, unchanged.)

## Not verified / known risks / TODOs

- The non-FAST gate was run **once**, before delivery, as the thread's resource discipline asks; the
  FAST run and the full run above are the only two smoke executions of this task.
- The remaining "another harness is possible" phrasing in ROADMAP M3/C1 and in `scripts/**` comments is
  known and out of this change (D2/D7); a future change owns it.
- Doctor's `pi` row keeps its "custom adapter ⇒ pi not needed" condition while the seam is configured —
  design D4 records this asymmetry deliberately (fixing it would be a behaviour change).

## Suggested next steps

- Independent verification in the **verify** phase by a different agent (`verify` seat), then the PM's
  `opsx-archive` after the user confirms — per the five-phase pipeline.
