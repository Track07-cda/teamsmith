# M27 · 自写 team-bg.ts：团队后台任务车道（E8 P2，用户拍板自写）

```
task:   M27
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M25          # 你手上 M25 交付后再开工；M26（doctor/init 探测）并行不冲突
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

用户拍板：**自写** `team-bg.ts`（不引第三方包进团队关键路径——pi-background-tasks 的 Anthropic
attribution 全局副作用不可接受）。E8 已把可行性实测完（`docs/team/reports/E8-verify/` 的 probes/ 可直接
改造成测试起点）：`registerTool` + job 表 + 子进程 exit 时 `pi.sendMessage(..., {triggerTurn:true,
deliverAs:'followUp'})` 能唤醒空闲 agent（RPC 事件流实证）。

**分层红线**：team-bg 只服务团队机械（PM 后台门禁、worker 长任务），经 dispatch/PM 启动的 `-e` 注入
（与 team-notify.ts 同通道）；用户自己会话里没有它；它只认**自己 job 表**里的作业，与用户可能自装的
任何后台包零串扰。

## Deliverables

1. `skills/teamsmith/extension/team-bg.ts`（~100-150 行，照 team-notify.ts 的守卫风格）：
   - 注册工具 `team_bg_run`（命名空间隔离）：spawn 脱离进程、立刻返回 job id + pid；输出落
     `state/bg/<id>.log`（有界，截断保留尾段）。
   - `team_bg_wait <id>`：收割（结果内联返回）；收割过的作业完成时**静默**（omp #689 第 1 条）。
   - job 表（session 级）；`agent_settled` 时查未收割集合：有 → 唤醒并提醒（合并成**一条**消息，
     #689 第 2 条；deliverAs 用 followUp）；无 → 静默。
   - 每次 settled 追加一行 `state/bg.log`（`settled-with-unharvested=<n>`）——让 PM 复验/digest 能读到
     「回合结束还有未收割作业」这个事实。
   - 生命周期纪律：factory 不起后台资源（session_start 才起，session_shutdown 收尾——pi 文档硬约束）。
2. dispatch/PM 启动链把它挂上（与 notify 扩展并列注入），并写进 `references/agent-adapters.md` 的
   通道说明（worker 模板提示词里教一句：长任务用 `team_bg_run` 且回合结束前必须 `team_bg_wait` 收割）。
3. 测试（翻转是硬要求）：
   - 未收割 → 唤醒；已收割 → 静默（E8 §2.3 的探针 2 改造成门禁级测试）；
   - 多条同时完成 → 合并成一条；
   - `state/bg.log` 的行格式断言；
   - 不进 smoke 的慢路径：用 `pi --mode rpc` 驱动（E8 probes 已给出零交互驱动形态），或用假 agent 替代
     真模型——报告里说明取舍。
4. PM 侧用法文档：references/workflows.md 加一节「PM 的后台门禁」（team_bg_run 跑门禁 → 回合结束 →
   被唤醒读结果），取代现在「开后台 tmux 窗口 + 盯日志」的手工姿势。

## Boundaries (do not do)

- 不订阅第三方包的 EventBus（E8 §5 的可选深接口，等运行数据说话）。
- 不动 outbox/投递守卫（M24 刚修好）；不动 pulse 巡检逻辑。
- 工具名不许用 `bg_run`/`process` 等可能与用户包撞车的裸名。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# team-bg 翻转测试实录：未收割→唤醒 / 已收割→静默 / 多条合并
```

## Report

`docs/team/reports/M27-dev2.md`（格式见 `templates/report.md.tmpl`）。
