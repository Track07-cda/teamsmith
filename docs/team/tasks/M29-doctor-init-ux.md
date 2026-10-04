# M29 · init/doctor UX：插件只报已装+推荐只限必需；名册改最小起点

```
task:   M29
agent:  dev3
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M26          # 修订它昨天交付的推荐文案
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

用户在 <ontology-project> 首次实战 teamsmith-init 后拍板三条（原话整理）：

1. **后台任务插件的主动推荐砍掉**——「这个推荐不需要」。team 机械的后台车道是自写的 team-bg
   （M27 在飞），不向用户推第三方包。
2. **改为告知**：doctor/init 应**列出该项目已安装哪些插件**（读 `.pi/settings.json` 的 packages +
   `pi list --approve` 兜底），信息性呈现，不附「装吗？」。
3. **推荐只许推 teamsmith 必需或自己会用的**：如 magic-context（doctor 已有依赖检查）与将来 team-bg
   这类随 skill 分发的；永不推荐纯第三方功能性包（pi-processes / pi-background-tasks 从此不提安装）。

外加一条名册 UX（同一次实战反馈，用户原话「名册完全可以根据实际工作需要增减」）：

4. init 清单的名册条目改写成「**最小初始名册**（建议 1 dev + 1 verify；`team add-agent` 随时可加，
   名册随工作增减）」；doctor 的「名册为空」从 fail 降级为 warn（PM-only 开局合法，dispatch 时没 agent
   可用会在那里拦）。

## Deliverables

- `cmd-project.sh` doctor：`background jobs` 行改写为「已安装插件」信息行（列出包名与级别 project/global，
  无则 `! 未检测到插件（teamsmith 不依赖第三方插件；团队会话的后台任务由自带 team-bg 覆盖）`）——
  删掉 install 推荐文案与 attribution 警告（不再需要）；harness 探测行保留。
- `skills/teamsmith-init/SKILL.md`：问答清单的后台任务条目改为「告知已装插件 + 说明 team-bg 覆盖团队
  会话」；名册条目改最小起点措辞。
- doctor「名册为空」fail → warn，措辞「可 PM-only 开局；要派单先 `team add-agent`」。
- smoke：三处改动各配断言（推荐字样不再出现 / 已装清单出现 / 名册空=warn 不 fail），含一条翻转
  （把推荐文案塞回去 → 断言红）。

## Boundaries (do not do)

- 不动 M27（team-bg）的任何文件；不动 pulse/派单。
- 不删 harness 探测行本身（omp 检测仍有价值：omp 会话自带后台，文案不同）。
- 不推任何第三方包的安装命令（含注释里）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# doctor 三形态输出（无插件/有插件/omp）贴进报告
```

## Report

`docs/team/reports/M29-dev3.md`（格式见 `templates/report.md.tmpl`）。
