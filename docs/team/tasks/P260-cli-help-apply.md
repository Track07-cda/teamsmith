# P260 · 帮助面三级菜单与语言层：apply

task: P260
agent: dev
phase: apply
category: code
change: cli-help
specs: help-surface, dispatch
deltas: -
branch: task/P260-cli-help-apply
deps: P252（提案已 ACCEPTED，见 `docs/team/reviews/cli-help-proposal.md`；change 目录已在 main）

## 范围

实现已接受的 `openspec/changes/cli-help/` 全部内容：proposal、design 十条决策、`tasks.md` 第 1–6 节、以及两个 delta——新能力 `specs/help-surface/spec.md`（7 条要求）与 `specs/dispatch/spec.md` 的 MODIFIED（**基线 14 条场景逐字保留 + 3 条新场景**，一个都不许丢）。**不重述**合同：以 change 目录与 `dispatch` 的基线要求为准。

三条来自 PM 复核的硬性条件（记在这里以便你自查）：

1. **第 0 级的规模由门禁计数**：渲染行数 ≤30、上手命令 3–5 条，两条都要有可跑的检查与红侧（灌入命令清单必须红、填充撑过 30 行必须红）。不许改成人工检查。
2. **走查扩面不许降级**：`tests/routes.sh` 的 Walk A 主语扩到每一级（菜单 / 每个组页 / 每个命令页），读同一份命令清单作为工作集；非空洞控制臂、承诺探针、既有翻转一条不动；报告里给出改动前后的覆盖数字（design 里写的是今天 1 面/47 用法行/42 命令 → 改后 1 菜单 + 8 组页 + 48 命令页）。
3. **第 0 级的组清单是清单、不是小节标题序列**（列 0 的 `Groups` 标题 + 每组一行、缩进 2）；`── Start here ──` 那块与组页/命令页照旧按四级缩进渲染。

## 边界

- 落点按 design 的「落点」一节：`scripts/strings/commands.tsv`、`scripts/strings/help.{en,zh}.tsv`、`scripts/lib/cmd-help.sh`（新）、`scripts/team`（全局参数循环里解析 `--help`/`-h`，先于配置加载）、`scripts/lib/cmd-project.sh`（删那 98 行 heredoc）、`scripts/lib/cmd-meeting.sh`（其 help 并入 `meeting` 页）、`tests/help-surface.sh`（新）、`tests/routes.sh`、`tests/smoke.sh` 的登记、`tests/section-paths.tsv`（必要时 `section-budgets.tsv`）。
- **不许碰**：面板字符串与设置页（那是 P258 的面）、`cmd-watch.sh`/`common.sh` 的报错文案（那是 P254 的面）、`references/migration.md`（P255）、`references/config.md`（P251）。命令名、旗标名、既有退出码、`--print`/`--json` 字节一个不改（未知 token 的 `--help` 由 exit 0 改 exit 2 是本变更唯一允许改的退出行为，delta 有专门场景）。
- **写集重叠**：`tests/smoke.sh` 与 `tests/section-paths.tsv` 正被 P251（通知合并）改动——交付前先 `git merge main`，冲突按**双方保留**解决（两处都是各自追加段/行），并在合并后的树上重跑你那批选段；出现**语义**冲突（不是两处各自追加）就停下来 `BLOCKED:` 给 PM。
- 不许删/skip 断言换绿；新增跳过要有名与理由。
- 不合并、不推送；做完 `team notify pm`。

## 验收（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/help-surface.sh --all            # 新入口（组名按你实现）
bash skills/teamsmith/tests/routes.sh                        # §51 的走查（扩面后）
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**红侧**（每条给「破坏→红（点名）→还原→绿」）：菜单灌入某组命令行；菜单被填充撑过 30 行；某条用法行只出现在命令页而不在组页（走查必须红）；删一条命令记录（覆盖红）；未知 token 走成 exit 0；帮助路径读配置（无项目目录时必须仍可用）；非法 `TEAM_LANG` 静默；删一条 zh 键不点名；页内声明与复述不一致；变异帮助表后机器出口变了。

## 交付

`docs/team/reports/P260-dev.md`（逐条 `tasks.md` 1–6 对照、命令与 rc、十一条红侧的前后证据、走查覆盖数字、`TEAM_LANG`/`TEAM_HELP_WIDTH` 的实测、未做项）；证据包按 D94 放仓外；之后由**未写过本任务**的席位独立复验。
