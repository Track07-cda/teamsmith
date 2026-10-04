# M26 · doctor/init 探测 harness 与后台任务包 + 推荐文案（E8 P1）

```
task:   M26
agent:  dev3
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   E8           # 探索报告 docs/team/reports/E8-verify.md（D28 验收；用户拍板 P1+P2 都做、推荐默认项目级、team-bg 自写）
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context

E8（报告与证物 `docs/team/reports/E8-verify.md` + `E8-verify/`，命令全部实测过）的 Phase 1：让
`team doctor` 与初始化流程知道「这个项目的 harness 有没有后台任务能力」，没有就打印一条可复制的推荐。
**分层红线（用户已确认）**：推荐是给「用户自己的 pi 会话」的；团队机械的后台车道是自写的 team-bg
（M27，与本任务并行），doctor/init 不推荐它、不依赖任何第三方包进团队关键路径。

## Deliverables

1. `skills/teamsmith/scripts/lib/cmd-project.sh`（doctor 表）加三行检查（命令在 E8 §4 全部实测过）：
   - `harness`：`command -v omp` 命中 → `! omp 自带后台任务（bash 后台派发 / hub / /jobs），无需装插件`；
     否则 pi（已有检查）；`TEAM_AGENT_CMD` 非空 → `! 后台能力取决于该 harness，无法探测`。
   - `background jobs`（包探测）：项目 `.pi/settings.json` + `pi list --approve` 里找已知包名
     （`pi-background-tasks` / `@aliou/pi-processes`）；命中 → ✓；未命中 → `!` 行打印可复制的
     **项目级**推荐（`pi install npm:@aliou/pi-processes -l` 为首选窄包，附 `pi-background-tasks` 及其
     Anthropic attribution 副作用的一句警告——文案照 E8 §3）。
   - `background jobs`（加载探测，可选加固）：`pi --mode rpc` 发 `{"type":"get_commands"}` grep 命令签名
     （`bg`/`jobs`/`ps`）；装了但没加载 → `!` 并指向 `pi list --approve`。注意超时保护（≤5s），RPC 起不来
     就降级为 skip，不许让 doctor 变慢变脆。
2. 推荐文案同时进 `skills/teamsmith-init/SKILL.md` 的问答清单（一条：harness 与后台任务能力怎么问、
   推荐什么、omp 不用装、用户 `/bg` 不唤醒模型的坑——E8 §3 两条坑都必须进文案）。
3. `docs/team/` 不动账本；在 `skills/teamsmith/references/troubleshooting.md` 或 workflows.md 加一小节
   「长任务的两种跑法」（插件车道 / 后台 tmux 窗口兜底），含「必须 agent 侧启动、通知合并、空闲才投递」。
4. smoke 断言：doctor 输出的三行在夹具里各有翻转（有包/无包/omp 三形态可用假 settings.json + PATH 里
   的假 omp 模拟；加载探测可用假 `pi` 脚本模拟 RPC 回答）。

## Boundaries (do not do)

- 不推荐全局安装（默认项目级 `-l`）；不推荐 pi-background-tasks 时不带副作用警告。
- 不动 `extension/`（那是 M27）；不动 pulse/派单/复验行为。
- doctor 不许因新检查变慢超过 1s（加载探测超时就 skip）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# doctor 三形态的夹具输出（有包/无包/omp）贴进报告
```

## Report

`docs/team/reports/M26-dev3.md`（格式见 `templates/report.md.tmpl`）。
