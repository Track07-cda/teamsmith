# P261 · 启动自愈：apply

task: P261
agent: dev-bob
phase: apply
category: code
change: startup-self-heal
specs: init-skill, pm-lifecycle
deltas: -
branch: task/P261-startup-self-heal-apply
deps: P256（提案已 ACCEPTED，见 `docs/team/reviews/startup-self-heal-proposal.md`；change 目录已在 main）

## 范围

实现已接受的 `openspec/changes/startup-self-heal/`：proposal、design 十一条决策、`tasks.md` 六节、两个 delta（`init-skill` 的两条 MODIFIED 加两条 ADDED、`pm-lifecycle` 的一条 MODIFIED）。**基线场景一条都不许丢**（`init-skill` 2→2 与 6→7、`pm-lifecycle` 4→6，我在复核时逐条核过）。合同以 change 目录为准，本任务书不重述。

三件先做掉的事：

1. **把你 P253 分支上的两笔提交带过来**：`task/P253-migration-self-service`（`72754edc`、`7b63ade3`）做的正是本变更 design 里「拒绝信息从同一张推导表生成一条可粘贴命令」那一半。把它 cherry-pick 到本任务分支；与设计有出入的地方按设计调整（例如推导表要成为**唯一**来源。迁移与拒绝信息共用它），并在报告里说明改了什么。P253 已作废并入本变更，不要单独交付它。
2. **P254 也已并入**：拒绝信息说人话、打印两边 model（后缀显式）与 resume_key 这一条在本 delta 的 `pm-lifecycle` 要求里，按它实现。
3. **与 P260（帮助面实现）的写集串行**：两边都会碰 `tests/smoke.sh` 与 `tests/section-paths.tsv`；`cmd-project.sh` 也被 P260 改动（它要删掉那段 98 行的帮助文本）。交付前先 `git merge main`，冲突按**双方保留**解决；若冲突落在同一个函数的语义上，停下来 `BLOCKED:` 给 PM。

## 我在复核时点名的准入条件（自查用）

1. 迁移**值一个都不改**；写前打印计划、写带时间戳的备份（保留 5 份）、逐键打印 `before → after`、写一行审计；顺序在身份守卫之前、建场地之前、拉起 PM 之前。
2. 失败关闭八类各自**一个字节都不写**（配置、备份、审计都不动），并点名文件与具体障碍。
3. `--print` 不写任何字节、不联网、不写缓存，但打印同一份预测。
4. 身份：缺记录 → 登记并打印一行；不一致 → 仍拒绝并打印两边值；`--adopt-pm-identity` 显式且带审计。
5. 版本提示只做提示：有界 ≤2 秒、缓存 24 小时、除「本地落后」外一律静默且退出码与启动决策不变、`TEAM_UPDATE_CHECK=0` 连查询都不发生、`--print` 跳过并说明；工具从不自己安装。
6. 端到端：迁移之后**派单真的按类别选中了模型**（不是只看 `config list` 退出码）；新项目 `init`/`bootstrap` 也要写入形状号 `TEAM_CONFIG_VERSION`（红侧：新建项目缺形状号 → 判红）。
7. 吸收 P253 的那条命令要真能粘贴执行：除「换回占位符必红」外，另做一次端到端现场（复制命令 → `--dry-run` → `--yes` → `config list` 复核）。

## 边界

- 落点按 design；**不许碰**：帮助面（`cmd-project.sh` 的帮助段、`scripts/team` 的帮助路由——P260 的面）、面板字符串与设置页（P258）、`references/migration.md`（P255）、`references/config.md` 的既有段落（新键追加按 design §10 走）。
- 新键 `TEAM_CONFIG_VERSION`、`TEAM_UPDATE_CHECK` 必须三面一致（schema + `templates/config.sh.tmpl` + `references/config.md`），由 `tests/config-cli.sh` 覆盖。
- 不许删/skip 断言换绿；新增跳过要有名与理由。
- 不合并、不推送；做完 `team notify pm`。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/task-model-routing.sh --select heal,adopt,updatecheck   # 新三组（组名按你实现）
bash skills/teamsmith/tests/config-cli.sh
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**：design §11 的八条翻转逐条（删迁移表行 / 不建备份 / 不写形状号 / 缺记录走拒绝 / 忽略 `--yes` / 相同或更旧也打印 / `TEAM_UPDATE_CHECK=0` 仍联网 / `--print` 写缓存），每条给「破坏→红（点名）→还原→绿」；再加「新建项目缺形状号 → 红」与「迁移后派单按类别选中模型」的端到端。

## 交付

`docs/team/reports/P261-dev-bob.md`（逐条 tasks 对照、命令与 rc、红侧前后证据、P253 两笔提交的去向与调整说明、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验。
