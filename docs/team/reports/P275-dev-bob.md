# P275 · 启动自愈：文档只说真话（清单 5.2）

agent: dev-bob ｜ status: DELIVERED ｜ branch: `task/P275-self-heal-docs` ｜ PR/MR: -（local 模式，分支留本地待复验）
phase: apply ｜ change: startup-self-heal ｜ category: code

## 测试状态（先说）

- 任务书验收命令 5 条**全部真跑**（在合并 main 之后的树上），全绿，原始输出照贴在下文。
- `smoke --select 17`（迁移指南段：`references/migration.md` 在它的路径集里）已按纪律用 `team_bg_run`
  后台跑（门禁锁当时被 P264/dev3 的长跑持有，排队后拿到）：`✓ 189 ✗ 0`，rc=0，输出尾见「§17」一节。
- 全量门禁**没有跑**（纪律 #2012：只选变更触及的段，全量留给 PM 复验）。本条只动文档。

## 交付物

| 落点 | 内容 |
|---|---|
| `skills/teamsmith/references/migration.md` §5b | 第一句从「needs an explicit transaction instead of a re-render … the repair is the dedicated four-key transaction」改成「a re-render cannot do … **两条路线**（启动事务 / 手工事务）」；补 `team up --print` / `--no-migrate` 的语义；**新增「How the shape is detected」**：迁移表一行一条（`from`/`to`/transform/引入版本）、按序且幂等、加一条迁移 = 一行 + 一个 transform + 一组夹具、`TEAM_CONFIG_VERSION` 的含义（工具写、`refuse` 类）、缺键时按键判定、**高于已知形状号直接拒绝**（表里没有对应行也拒绝） |
| `skills/teamsmith/references/migration.md` §6 步骤 4 | 「A config still carrying the retired model keys is REFUSED here — run the explicit migration first」改成「migrate first with the startup transaction (`team up`) or explicitly」 |
| `skills/teamsmith/references/config.md` 的 `TEAM_TASK_MODELS` 行 | `breaking migration: team config upgrade-models` → `breaking migration: the next team up (startup transaction) or team config upgrade-models` |
| 另外三条路径（`skills/teamsmith-init/SKILL.md`、`skills/teamsmith-init/references/bootstrap.md`、`skills/teamsmith/references/workflows.md`） | **本条的基线里已经是「两条路线」**——由同一 change 的 apply（P261）在合并提交 `23f42b04` 里改掉了；见下文「四条路径的 before → after」逐条贴出的 diff。本条核过它们没有旧话残留，未重复改动。 |

改动面：产品面只有两个文档文件（`config.md` 一行、`migration.md` 两处），账本面是 `tasks.md` 的 5.2 勾选与本
报告；`skills/**` 的**行为**（`cmd-config.sh`、帮助面 `cmd-help.sh`/`strings/*`）、`references/protocol.md` §4b、
`tests/**` 一律没碰。交付前已 `git merge main`（merge 提交 `c1b66cb8`；main 只多了一份 `docs/team/reviews/P271.md`）。

## 判据 1：`grep -rn 'upgrade-models' skills/teamsmith*/` 无残留旧话

原始输出（判据命令，命中里没有「只能走手工事务」这类句子）：

```
$ grep -rn 'upgrade-models' skills/teamsmith*/ | head -20
skills/teamsmith/references/migration.md:151:team config upgrade-models --task-models 'routine=<model> …' --pm-model '<model>'        # preview: prints the diff, writes nothing
skills/teamsmith/references/migration.md:152:team config upgrade-models --task-models '…' --pm-model '<model>' --yes                                                # the one write
skills/teamsmith/references/migration.md:206:#    team config upgrade-models --task-models '…' --pm-model '…' [--yes]
skills/teamsmith/references/config.md:43:…; breaking migration: the next `team up` (startup transaction) or `team config upgrade-models` |
skills/teamsmith/references/config.md:47:… and migrates on the next `team up` (the startup transaction derives the pairs …) or through the explicit `team config upgrade-models …` transaction …
skills/teamsmith/references/config.md:421:team config upgrade-models --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6' --pm-model deepseek/deepseek-flash --dry-run
skills/teamsmith/references/config.md:435:model. `team config upgrade-models …` is the one **breaking migration** transaction: … The startup path calls the same transaction (`team up`, actor `up-migration`): …
skills/teamsmith/references/workflows.md:40:transaction) or through the explicit `team config upgrade-models`) and
skills/teamsmith/scripts/lib/cmd-bootstrap.sh:176:        team_dim "  已有项目升级：$TEAM_CLI config upgrade-models … --dry-run"
…（其余命中都在 scripts/ 里：运行时的**拒绝建议**与「手工事务路线」的措辞，正是 spec 要求「拒绝建议给出一条可粘贴命令」的那批，不是假话）
```

补充扫描（确认没有「只此一条路」的措辞残留在文档面）：

```
$ grep -rn 'only through\|只能走\|only route\|the sole route\|only via' skills/teamsmith/references/ skills/teamsmith-init/ skills/teamsmith/SKILL.md
skills/teamsmith/references/agent-adapters.md:640:- **CLIs that cannot accept a prompt non-interactively** (prompt only via a human TUI). Use
skills/teamsmith/references/config.md:42:| `TEAM_AGENTS` | … grows only through `team add-agent <a> --register` … |
skills/teamsmith/references/config.md:494:| `TEAM_BG_STOP_GRACE` | … reachable only through the escalation … |
（三条都与模型策略迁移无关）
```

四条路径各自的「两条路线」措辞（现行文本）：

```
$ grep -n 'startup transaction\|next `team up`' skills/teamsmith-init/SKILL.md skills/teamsmith-init/references/bootstrap.md skills/teamsmith/references/config.md skills/teamsmith/references/workflows.md
skills/teamsmith-init/SKILL.md:71:   install/ledger/worktree/pulse work and migrates on the next `team up` (the startup transaction derives the
skills/teamsmith-init/references/bootstrap.md:26:| Model policy | … migrates on the next `team up` (the startup transaction) or through the explicit `team config upgrade-models` transaction | ✔ |
skills/teamsmith/references/config.md:43:| `TEAM_TASK_MODELS` | … breaking migration: the next `team up` (startup transaction) or `team config upgrade-models` |
skills/teamsmith/references/workflows.md:39:`--task-models` and `--pm-model`; a legacy config is refused and migrates on the next `team up` (the startup
```

## 四条路径的 before → after

**① `skills/teamsmith-init/SKILL.md`（P261，提交 `23f42b04`）**

```
-   install/ledger/worktree/pulse work and migrates only through `team config upgrade-models --task-models '<map>'
-   --pm-model '<model>'`; `bootstrap`, `init --force` and inference are not migration routes.
+   install/ledger/worktree/pulse work and migrates on the next `team up` (the startup transaction derives the
+   category pairs from the old keys, prints them, backs the file up and re-enters itself) or through the explicit
+   `team config upgrade-models --task-models '<map>' --pm-model '<model>'` transaction; `bootstrap`, `init --force`
+   and inference are not migration routes.
```

**② `skills/teamsmith-init/references/bootstrap.md`（P261，提交 `23f42b04`）**

```
-| Model policy | … and migrates only through `team config upgrade-models` | ✔ |
+| Model policy | … and migrates on the next `team up` (the startup transaction) or through the explicit `team config upgrade-models` transaction | ✔ |
```

**③ `skills/teamsmith/references/workflows.md`（P261，提交 `23f42b04`）**

```
-`--task-models` and `--pm-model`; a legacy config is refused and migrates through `team config upgrade-models`) and
+`--task-models` and `--pm-model`; a legacy config is refused and migrates on the next `team up` (the startup
+transaction) or through the explicit `team config upgrade-models`) and
```

**④ `skills/teamsmith/references/config.md`（本条）**——P261 改了 §retired keys 那段（第 47 行，现在写「migrates on
the next `team up` … or through the explicit `team config upgrade-models …`」）；本条把同一文件里**表格行**上还只
点名手工命令的那句也补成两条路线：

```
-…; breaking migration: `team config upgrade-models` |
+…; breaking migration: the next `team up` (startup transaction) or `team config upgrade-models` |
```

**外加 `references/migration.md`（本条，§5b 与 §6 步骤 4）**：见下面 `git diff` 全文。

## 验收命令（真跑，原始输出）

```
$ git diff --stat main..HEAD
 docs/team/reports/P275-dev-bob.md           | 211 ++++++++++++++++++++++++++++
 openspec/changes/startup-self-heal/tasks.md |  10 +-
 skills/teamsmith/references/config.md       |   2 +-
 skills/teamsmith/references/migration.md    |  27 +++-
 4 files changed, 239 insertions(+), 11 deletions(-)

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -3
✓ spec/watchdog
Totals: 23 passed, 0 failed (23 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11467 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1540 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出）
rc=0
```

文档 diff（产品面全部改动，`git diff main..HEAD -- skills/`）：

```
$ git diff main..HEAD -- skills/teamsmith/references/migration.md
@@ ## 5b. The breaking model-policy upgrade (task categories)
-This is the one upgrade that needs an explicit transaction instead of a re-render. The retired keys
+This is the one upgrade a re-render cannot do: it needs the four-key migration transaction. The retired keys
 TEAM_AGENT_MODELS and TEAM_DEFAULT_MODEL are no longer read (an old seat model is **not** reinterpreted as a task
 model): a project that still carries them is refused by `team dispatch`/`team up` and by `team init`/
-`team bootstrap` — before any install, ledger, worktree or pulse work — and the repair is the dedicated
-four-key transaction:
+`team bootstrap` — before any install, ledger, worktree or pulse work. Two routes apply the same transaction: the
+**startup transaction** (the next `team up` derives the pairs from the old keys, prints every pair before → after
+with the backup path and the restore command, writes through the checked writer and re-enters itself) or the
+**explicit transaction**:
@@
-file and line plus the manual-normalization route. `team init --force`, `bootstrap` and inference are **not**
-migration routes; a fresh project passes `--task-models`/`--pm-model` to `init`/`bootstrap` instead.
+file and line plus the manual-normalization route. `team up --print` writes nothing (it prints the same
+prediction, with the backup path it would use) and `team up --no-migrate` refuses instead of writing, naming the
+manual command. `team init --force`, `bootstrap` and inference are **not** migration routes; a fresh project
+passes `--task-models`/`--pm-model` to `init`/`bootstrap` instead.
+
+**How the shape is detected.** Detection is a version table with **one row per migration** — the shape it matches
+(`from`), the shape it produces (`to`), the transform it applies and the tool version that introduced it — applied
+in order and idempotently; adding a migration is one table row plus one transform plus one fixture group. A
+project's shape number is `TEAM_CONFIG_VERSION` (written by `init`/`bootstrap` and by every migration; a `refuse`
+key — the console never writes it); a configuration **without** that key is classified by its keys (a retired key
+⇒ the pre-policy shape, otherwise the current one). A shape number **higher** than this tool's newest known one is
+**refused** rather than migrated with an older row, and so is a shape the table has no row for.
@@ ## 6. Upgrade recipe（步骤 4）
-#    A config still carrying the retired model keys is REFUSED here — run the explicit
-#    migration first: team config upgrade-models --task-models '…' --pm-model '…' [--yes]
+#    A config still carrying the retired model keys is REFUSED here — migrate first with
+#    the startup transaction (`team up`) or explicitly:
+#    team config upgrade-models --task-models '…' --pm-model '…' [--yes]
```

「形状表结构」这段与代码是同一份事实（`cmd-config.sh` 的 `team_config_migration_table()` 返回 `id|from|to|introduced`，
形状判定顺序在 `team_config_shape_read()`/`team_config_migration_decide()`：标记 → 键 → 表，`marker > TEAM_CONFIG_SHAPE_CURRENT` 即拒绝）；
本条只是把这份事实写进指南，没有改代码。

### §17 · smoke 迁移指南段

命令：`TEAM_SMOKE_LOCK_WAIT=5400 bash skills/teamsmith/tests/smoke.sh --select 17`（后台 job `p275-select17`，
exit=0，192.3s；门禁锁当时被 P264/dev3 的长跑持有，排队后拿到）。`--select 17` 连带它的依赖段（共 10 段）：

```
#10 17 · 迁移指南与 doctor 指引（M7.1） · 用时 11s · ✓34 ✗0 SKIP0 · ticks 34
#9 15b · 必需依赖：doctor 三态 + paths + dispatch 预检 · 用时 10s · ✓26 ✗0 SKIP0 · ticks 26
#8 3b · git 归 PM（skill 不执行、也不过度包装 git） · 用时 6s · ✓58 ✗0 SKIP0 · ticks 58
账本自查： 10 段收口 · 增量 ✓189 ✗0 SKIP0 ｜ 结果行 ✓189 ✗0 —— 一致

== 选段结果 ==  ✓ 189  ✗ 0
rc=0
```

与本条改动直接相关的断言全 ✓：`migration.md 有这一节：Upgrade recipe`、`指南篇幅 ≥ 120 行（不是占位符）`、
`本任务交付的 references 文档全英文（无 CJK）`、`config.md 指向迁移指南`、`SKILL.md 阅读表指向迁移指南`。
（`--select 17` 不是全套门禁；没跑的 119 个键由 smoke 自己点名，全量留给 PM 复验。）

## 5.2 勾选

`openspec/changes/startup-self-heal/tasks.md` 的 5.2 按事实勾上（§17 绿了之后落，见上一节），证据指针指向本报告
（判据 grep + 四条路径 before→after + §17 输出尾 + 文档 diff）。这是本条的交付物本身。

## 边界与未做

- `skills/teamsmith/SKILL.md:62` 的 commands 表里还有「a legacy config is refused before any side effect and
  points at `team config upgrade-models`」——它**不在**任务书授权的四条路径里（授权的是
  `skills/teamsmith-init/SKILL.md`，不是 `skills/teamsmith/SKILL.md`），且它说的是「拒绝建议指向那条命令」
  （与 spec 一致的真话，只是没提启动事务）。**未改**，留一句观察给 PM 决定要不要归 P255。
- `references/migration.md` 的**完整重写**留给 P255；本条只做「不说假话 + 不误导」的最小修正。
- 本条的基线里四条路径已被 P261 改对，所以本条的净新增只有 `migration.md`（§5b + 步骤 4）与 `config.md`
  的一处表格行。

## 给 P255 的交接（migration.md 完整重写要覆盖的既有事实）

- §5b 现在有：两条路线、`--print`/`--no-migrate` 语义、形状表结构与 `TEAM_CONFIG_VERSION` 语义、失败关闭的
  形状清单（export/多行/变量展开/重复键）。
- §6 步骤 4 现在两条路线都点名；完整重写时别把它退回单条路线。
- 形状表**只有一份**（`cmd-config.sh` 的 `team_config_migration_table()`）；文档写的是它的结构，不是副本。
