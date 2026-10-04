# P40 · npm-cli-and-project-init apply：`bin/team.mjs` + `team init` 装 `.pi/skills` + doctor 行

```
task:   P40
agent:  dev2
issue:
change: npm-cli-and-project-init      # 提案已验收：docs/team/reviews/npm-cli-and-project-init-proposal.md（ACCEPTED）
specs:  init-skill#team init installs the project's skills into .pi/skills / init-skill#The CLI ships as one npm bin / init-skill#The project-local install is visible and repairable / init-skill#Initialization guidance lives ...（MODIFIED）/ memory-and-deps#The shell the CLI runs on is checked where it can be seen
phase:  apply
anchor: change
deltas: init-skill, memory-and-deps
grant:  bin/team.mjs（新建）· package.json（bin/files/version 不动）· skills/teamsmith/scripts/lib/cmd-init.sh · cmd-project.sh（help 文案）· cmd-agents.sh（doctor 行）· skills/teamsmith/scripts/team（若需接线）· skills/teamsmith-init/SKILL.md · skills/teamsmith-init/references/bootstrap.md · skills/teamsmith/SKILL.md（命令表一行 + 新项目指引）· README.md · .gitignore · docs/team/PUBLISH.md · tests/smoke.sh（append-only）+ 新夹具文件
deps:   P37（propose，已合并 52adc3a）· **P39 必须先落地**（两者都改 README/init SKILL）
status: todo（等 P39 合并）
budget: 一个工作块（B1 bin + init 装 / B2 doctor 行 + 文案六面 / B3 夹具与翻转）
```

> 本地模式：不 push。**设计真源 = `openspec/changes/npm-cli-and-project-init/design.md`（Decision 1–5、§7 口径表、§9 验证、§10 不做）与 tasks.md。**

## 硬要求

1. **包装器逐字透传**：不实现任何子命令、不改参数；`team help`/`team version`/退出码与 bash 入口**逐字节一致**（有断言）；
   bash 缺失/过老 → **人话报错**（点名 README 的 Requirements 行）；
2. **init 装 skill 的目标与源**：`$TEAM_MAIN_ROOT/.pi/skills/<name>`；**按名取源**（不做目录扫荡）；
   默认 `link`、`--copy`（排除 `.git`、`node_modules`）、`--no-skills`；**冲突表逐格实现**
   （不认识的目录**连 `--force` 都不删**）；输出逐 skill 一行（`link/copy/skip`）；
3. **`bootstrap` 复用同一函数**（一个实现两个调用点；`bootstrap --print` 点名该步且不写盘）；
   **`bootstrap` 在 `config.sh 已存在` 时也要跑装 skill 这一步**（这就是升级路径）；
4. **doctor 行**：无入口→**安静**；pass / warn（陈旧/他源/无 SKILL.md）**永不 fail**，warn 给 `team init --force`；
5. **§7 六面口径一致**（init SKILL / README / `team help` / daily SKILL / bootstrap.md / PUBLISH 演练步）；
6. **`install.sh`、扩展注入、门禁、`pi.skills` 清单一律不动**；**不发 npm、不打 tag**；
7. 小步提交；每批 FAST 绿；交付前全量一次。

## 必给的翻转（红→绿原始输出）

- 把包装器的 `exit status` 透传改成 `exit 0` → 断言红（`team help` 的 rc 不一致）；
- 把冲突表里"不认识的目录"改成可删 → 断言红（**它是红线，宁可拒绝也不删**）；
- 去掉 doctor 的 warn（改成 fail 或静默）→ 对应断言红；
- 把 bootstrap 的装 skill 步去掉 → 升级路径断言红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
node bin/team.mjs version && bash skills/teamsmith/scripts/team version   # 同输出同 rc
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null            # 交付前全量
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不碰** `extension/**`、`install.sh`、`panel/**`、`openspec/**`、`docs/team/**`（PUBLISH.md 除外）；
- 不改任何既有子命令语义；矛盾 → `BLOCKED:` 交回 PM；
- 不 push。

## Deliverables

- 实现 + 五条翻转原始输出 + 报告 `docs/team/reports/P40-dev2.md`（含包装器与 bash 入口的 rc/输出一致性证据、
  冲突表逐格实测、doctor 三态实测、bootstrap 升级路径实测）。
