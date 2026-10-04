# E7 · explore: teamsmith 拆成日常 skill + 初始化 skill 的边界与代价

```
task:   E7
agent:  dev
issue:  
change: -            # explore 阶段不指名 change；若结论是要做，提案阶段再建
specs:  -
phase:  explore      # 纯探索：只产报告，不改代码
deps:   -
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev` 工作树即可，PM 复验后本地合并。

## Context

用户提出并已批准探索：teamsmith 现在是单 skill(SKILL.md ~290 行 + 13 篇按需 references + templates + scripts + extension)。初始化一个新 repo 和日常 PM 运转共用同一份指引。用户论点：① 日常 agent 加载了用不上的初始化指引；② 初始化是**交互式**流程（依赖插件、模型偏好、名册、VCS 模式需要问用户），和日常自治运转性质不同；③ 「不要把所有指引放到一个大 skill」是 skill 的设计初衷。

PM 的初步倾向（供批判，不是结论）：拆两个——`teamsmith`（日常）+ `teamsmith-init`（初始化，含交互式配置问答，完成后交接给日常 skill);worker 不拆（走 AGENTS.md + 任务书）,opsx 五相不拆（已是独立命令）。

## 要回答的问题（每个都要有证据，不接受纯推理）

1. **盘点**:SKILL.md/references/templates/extension 里哪些内容是初始化专用、日常专用、两边共享？给出逐节清单与行数。
2. **发现机制实测**:Pi 的 skill 发现是按 description 匹配的——拆成两个后，「在这个 repo 搭团队」和「派活」两类意图的匹配会更准还是更混？（可用本机两个已装 skill 做对照实验，或读 Pi 的 skill 加载代码/文档。）
3. **初始化交互流的家**:bootstrap 今天要问用户什么（依赖、模型、名册、VCS)?现在这些信息在哪承载（`templates/bootstrap-prompt.md.tmpl`？还是 PM 临场发挥）？拆出 `teamsmith-init` 后这条流长什么样？
4. **版本与漂移**:两个 skill 同仓库同发布（版本号、CHANGELOG、`team version --check`、热重载）怎么保持同步？references/scripts/templates 是共享还是各拷一份？（scripts 显然共享——skill 分叉但 `team` CLI 只有一个。）
5. **安装形态**:`~/.agents/skills/` 现在是一个软链；拆后是两个条目还是一个聚合？
6. **代价与风险**:交叉引用断裂、文档漂移、用户困惑（装哪个）、迁移期。给出「不拆，只把初始化内容进一步下沉到 references」这个替代方案的诚实对比。
7. **既有探索参照**:`docs/team/reports/E4-dev2.md`(pulse 控制台化）与 E6（可行性实测）的探索报告格式可参照；openspec 管线见 `skills/teamsmith/references/openspec.md`。

## Deliverables

1. `docs/team/reports/E7-dev.md` — 探索报告：7 个问题的答案（带证据）、选项对比、明确推荐与工作量估计。
2. 只读：不改任何代码/文档（报告文件除外）。

## Boundaries (do not do)

- 不改 `skills/**` 的任何实现；不动 `~/.agents/`；不碰其它项目。
- 不建 OpenSpec change（那是 propose 相的事）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 报告里的每个结论附证据（文件:行 或实测输出）
```

## Report

Write it to `docs/team/reports/E7-dev.md`（格式参照 `docs/team/reports/E6-dev2.md`）。
