# P51 · npm-cli-and-project-init 独立验证（verify 阶段）

```
task:   P51
agent:  dev
issue:
change: npm-cli-and-project-init
specs:  init-skill#The CLI ships as one npm bin entry and the package carries what it runs / init-skill#team init installs the project's skills into .pi/skills / init-skill#The project-local install is visible in team doctor, and repairable with team init / init-skill#Initialization guidance lives in a dedicated teamsmith-init skill / memory-and-deps#The shell the CLI runs on is a checked dependency, not an assumption
phase:  verify
anchor: change
deltas: init-skill, memory-and-deps
grant:  docs/team/reports/P51-dev.md · docs/team/reports/P51-dev/**（只写报告与证据，不改实现）
deps:   P37（propose）· **P40（apply，dev2）**——apply 作者不是你
status: todo
budget: 一个工作块（只写复验证据与报告）
```

> 本地模式：不 push。**apply 是 dev2 做的 → 你来验（D31）。**

## 要对抗性验证的（每条给可复现命令 + 原始输出；别复述别人的报告）

1. **包装器与 bash 入口的等价**：`node bin/team.mjs {help,version,paths,config list}` 与
   `bash skills/teamsmith/scripts/team …` **逐字节一致 + rc 一致**；**未知子命令**与**坏参数**也一致（rc 与 stderr）。
2. **shell 前置检查**：假 `bash`（报 3）→ 人话拒绝且 **rc≠0**；真 bash → 正常。**反向**：PATH 里没有 bash → 点名人话拒绝。
3. **`team init` 的安装语义**（在**临时仓**里跑，别碰本仓库）：
   - 目标 = `<主检出>/.pi/skills/<name>`（**在 linked worktree 里跑也装主检出**——这条要专门验）；
   - 默认软链、`--copy` 复制（不含 `.git/`、`node_modules/`）、`--no-skills` 跳过并说明；
   - **幂等**：第二次全 `skip`；
   - **冲突表逐格**：外来软链 → 冲突 + 三条出路 + 目标不变；`--force` → 换成当前源；
     **不认识的目录**（无 SKILL.md / name 不符 / 手工改过的 vendored copy）→ **连 `--force` 都不删**（自己造一个塞进去验）；
   - `.gitignore` 增 `.pi/skills/` 且**不重复**；已跟踪的 `.pi/skills/openspec-*` **不被动**。
4. **`bootstrap` 复用同一实现**：`config.sh` **已存在**时也跑安装步（老项目升级路径）；`bootstrap --print` 点名该步且不写盘。
5. **doctor 行三态**：无入口 → **安静**；软链指向当前源或同版本 copy → pass；**别的版本/别的源/无 SKILL.md → warn（永不 fail）** 且给 `team init --force`。
6. **六个面口径一致**（init SKILL / README §Install / `team help` 的 init 行 / 每日 SKILL 命令表 / bootstrap.md / PUBLISH 演练步）——
   抽查至少三处：**同一件事的说法一致**（谁装、装到哪、两个旗标）。
7. **零回归**：`TEAM_SMOKE_FAST=1 smoke`、`install-shape.sh`、`config-cli.sh`、`panel-choices.sh` 全绿；
   `pi.skills` 清单与 `version` 不动。

## 至少三条变异（红→绿原始输出）

- 把包装器的 `exit status` 透传改成 `exit 0` → 一致性断言红；
- 让"不认识的目录"在 `--force` 下被删 → 红线断言红；
- 把 doctor 的 warn 改成 fail（或静默）→ 三态断言红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/install-shape.sh
```

## Boundaries

- **不改实现**（`bin/**`、`skills/**`、`tests/**` 一律不改）；缺陷写清楚交回 PM；变异只在临时副本；
- 不 push；不改 `docs/team/**` 里 PM 的文件。
