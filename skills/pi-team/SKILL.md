---
name: pi-team
description: 用 Pi Agent 组建并调度一支可复用的多 Agent 团队（PM 编排 + worker 并行开发）：tmux 窗口派单与唤醒、git worktree 隔离、任务书/报告/复验记录/消息线程/inbox 契约、独立复验门禁、PR/MR 与合并授权、容量守卫与保活自愈（watchdog 自动拉起 PM、续跑停掉的 agent、systemd 用户服务）。Use when the user wants to organize multiple Pi agents into a team, dispatch tasks to worker agents, run agents in parallel in tmux with git worktree isolation, act as a PM/orchestrator over other agents, set up an agent collaboration protocol, review an agent's work independently, keep an agent team alive / auto-restart the PM / resume stopped agents after a crash or reboot, or resume and coordinate a multi-agent project；用户说「组建 agent 团队 / 多 agent 并行 / 派单 / PM 编排 / 团队协作规范 / 复验 agent 的活 / 管理几个 agent / 团队全停了怎么恢复 / 保活 watchdog」时同样适用。
license: MIT
metadata:
  version: "1.2.0"
---

# pi-team · Pi Agent 团队

把「一个 PM 会话 + 若干 worker agent」的工作方式固化成一键可用的工具：PM 写任务书并派单，
worker 在各自的 worktree 里并行实现、写报告、开 PR/MR，PM 在独立 checkout 上复验后合并。
**你自己通常就是那个 PM**：用户让你「组建团队/派单/并行开发」时，按下面的 PM 循环来做。

```
PM(本会话, tmux <session>:pm)          worker agents(各自 .worktrees/<agent>)
   task / dispatch ──────────────────▶  pi --session-id <s>-<a>（交互式，可旁观）
   digest / inbox  ◀── 回合结束自动通知 ──  extension/team-notify.ts → inbox + tmux 唤醒
   review(独立 worktree 跑门禁) ────────▶  报告 reports/<ID>-<a>.md + PR/MR
   merge / close   ──────────────────▶  BOARD → done
```

## 30 秒上手

```bash
SKILL=~/.agents/skills/pi-team                       # 本 skill 目录
TEAM="bash $SKILL/scripts/team"                      # 单入口 CLI（`team help` 看全部子命令）

cd <你的项目>                                        # 必须已经是 git 仓库且有提交
$TEAM init --session myproj --agents "dev verify"    # 写配置+文档骨架+AGENTS.md 协议段
$TEAM doctor                                         # 环境自检（git/tmux/pi/门禁/forge/内存）

tmux new -s myproj -n pm                             # PM 会话（通知会敲进这个窗口），里面跑 pi
$TEAM task T1.1 --title "第一个任务" --agent dev      # 生成任务书
$EDITOR docs/team/tasks/T1.1-*.md                    # 写清背景/交付物/边界/验收命令
$TEAM add-agent dev && $TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md
```

## 命令表

| 目的 | 命令 |
|---|---|
| 初始化 / 自检 | `team init [--session s] [--agents "a b"] [--vcs local\|github\|gitlab]`、`team doctor` |
| 观察 | `team roster`（窗口/分支/脏/领先）、`team status [ID]`、`team ps`（容量+模型并发+PM/watchdog 存活）、`team digest`（PM 待办） |
| 收件箱 | `team inbox [agent] [--ack] [--all]` |
| 文档契约 | `team task <ID> --title ... --agent a`、`team board add\|set\|ls`、`team thread <a> "..." --from pm --re <ID>`、`team report <ID> <a>` |
| 派单 | `team add-agent <a>`、`team dispatch <a> <ID> <taskfile> [--model m] [--fresh] [--print]` |
| 协作 | `team say <a> "<单行消息>"`、`team notify <a> "<一句话>"`（agent→PM） |
| 复验 | `team review <ID> [--branch b] [--no-gates]` → `reviews/<ID>.md` |
| 合并/收尾 | `team merge <ID> [--push]`、`team pr <ID>`、`team close <ID>`、`team teardown --agent a [--purge]` |
| 保活/恢复 | `team up`（建 session + 拉起 PM + 续跑停了的 agent）、`team resume`、`team watch [--once]`、`team install-watchdog --yes`、`team watchdog-status` |
| forge 透传 | `team gh <gh 参数…>`、`team gl <METHOD> <path>`（token 由 wrapper 注入，不回显） |
| 排障 | `team paths`（当前解析出的路径/session）、`team smoke`（端到端自测）、`team version` |

## 作为 PM 的循环（你该怎么做）

> 开局（或被 watchdog 拉起后）先跑：`team digest` → `team inbox --ack` → `team resume --dry-run` → `team watchdog-status`。

1. **建模**：`team doctor`，必要时 `init`；把用户需求拆成里程碑写进 `ROADMAP.md`，
   每个任务写成**自包含**任务书（背景/交付物/边界/可复制的验收命令/报告要求）——
   默认开发模型是便宜模型，它不会纠正模糊需求。
2. **派单**：`team dispatch <a> <ID> <taskfile>`。派单前先 `team ps`（内存/模型并发）。
   一个 agent 一个长期 worktree；同一 agent 再派单即复用会话（断点续跑），要开新会话用 `--fresh`。
3. **等通知**：worker 回合结束会自动写 `inbox/<agent>.md` 并敲你的窗口叫醒你。
   不要轮询 agent 的屏幕；读 `team inbox --ack` 与 `team digest`。
4. **复验（不可跳过）**：`team review <ID>` —— 在独立 detached worktree 上跑门禁，产出
   `reviews/<ID>.md`。**报告是主张，复验结果是证据**；自己再读一遍 diff 是否满足任务书。
5. **通过** → `team merge <ID>`（或 `team pr <ID>` 走 forge）→ `team close <ID>`。
   **不通过** → `team thread <a> "<失败证据 + 期望>"` + `team say <a> "<单行指令>"` 退回。
6. **收尾 / 汇报**：更新 `BOARD.md`（`team board set`）、把关键决策写进 `DECISIONS.md`（含理由与影响），
   向用户汇报「交付了什么 + 证据在哪 + 下一步」。用户要的是结论与风险，不是命令流水。

PM 需要停下来问用户的情况只有：合并/推送等**共享状态变更**（skill 用 `--yes` 表达授权）、
范围变更、需要用户拍板的选型（先派调研任务取证，再写 `DECISIONS.md`）。

## 不可协商的规则（会被复验）
- **没有真实执行过，不得声称通过**。报告必须带命令与输出尾部；PM 独立复跑。
- agent 只改自己有归属的目录（`OWNERSHIP.md`）；跨目录 → 报告写 `BLOCKED:`。
- agent 禁止 push 保护分支、force push、merge PR/MR、rebase/删除他人分支。
- token 只由 wrapper 注入（`team gh`/`team gl`/`team pr`），永不回显、永不落盘。
- 任何改变共享/远端状态的操作需要 `--yes`（= 用户已授权）。
- 一个 agent 一个长期 worktree：**不要移动它**（Pi session 按 cwd 归属，移动等于丢记忆）。
- **团队必须能无人看守地活下去**：装 `team install-watchdog --yes`（或至少开一个 `team watch` 窗口）。
  恢复不依赖任何 agent——PM 挂了由 watchdog 用 `pi -c` 拉起并喂开场提示词，agent 挂了按 state 里记的任务书续跑。

## 深入阅读（按需，不要一次全读）

| 文件 | 什么时候读 |
|---|---|
| `references/protocol.md` | 想理解每条规则的理由（独立复验、唤醒机制、容量底线、保活链路、安全模型） |
| `references/config.md` | 配置键含义、项目落盘布局、环境变量覆盖（环境变量优先于配置文件） |
| `references/workflows.md` | 端到端 runbook：建队、派单、复验、合并、**保活/恢复**、并行扩展、阻塞处理 |
| `references/troubleshooting.md` | 通知不到、会话丢失、worktree 冲突、forge 403、报告不实 |
| `templates/` | 需要手写任务书/报告/看板时抄模板 |
| `scripts/team`、`scripts/lib/*.sh` | 要改行为时（先用 `team <cmd> --print` 看它生成什么） |
| `tests/smoke.sh`、`tests/skill-load.mjs` | 想确认这套工具在本机可用：`team smoke`（临时仓库端到端自测，不碰本项目） |

## 环境要求

git（≥2.31，用 `--path-format=absolute`）、bash ≥4、tmux、pi（支持 `--session-id`/`-e`/`--skill`）、
可选 `gh`（github 模式）或 curl + PAT（gitlab 模式）。无 jq/python/node 依赖。
