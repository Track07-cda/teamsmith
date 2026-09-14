---
name: pi-team
description: 用 Pi Agent 组建并调度一支可复用的多 Agent 团队（PM 编排 + worker 并行开发）：tmux 窗口派单与唤醒、git worktree 隔离、任务书/报告/复验记录/消息线程/inbox 契约、独立复验门禁、PR/MR 与合并授权、容量守卫与定时巡检（podman 容器看门狗：有待办才叫醒 PM、PM 可 standby 主动停工；一键 bootstrap 初始化新项目）。Use when the user wants to organize multiple Pi agents into a team, dispatch tasks to worker agents, run agents in parallel in tmux with git worktree isolation, act as a PM/orchestrator over other agents, set up an agent collaboration protocol, review an agent's work independently, bootstrap this skill into a new project, run the watchdog as a podman container, wake the PM only when there is pending work / auto-restart the PM after a crash or reboot, or resume and coordinate a multi-agent project；用户说「组建 agent 团队 / 多 agent 并行 / 派单 / PM 编排 / 团队协作规范 / 复验 agent 的活 / 管理几个 agent / 新项目怎么初始化 / 看门狗容器 / 团队全停了怎么恢复 / 保活 watchdog」时同样适用。
license: MIT
metadata:
  version: "1.11.5"
---

# pi-team · Pi Agent 团队

把「一个 PM 会话 + 若干 worker agent」的工作方式固化成一键可用的工具：PM 写任务书并派单，
worker 在各自的 worktree 里并行实现、写报告、开 PR/MR，PM 在独立 checkout 上复验后合并。
**你自己通常就是那个 PM**：用户让你「组建团队/派单/并行开发」时，按下面的 PM 循环来做。

```
PM(本会话, tmux <session>:pm)          worker agents(各自 .worktrees/<agent>)
   task / dispatch ──────────────────▶  pi --session-id <s>-<a>（交互式，可旁观）
   digest / inbox  ◀── 回合结束自动通知 ──  extension/team-notify.ts → inbox + tmux 唤醒
   review(PM 给的独立 checkout 跑门禁) ──▶  报告 reports/<ID>-<a>.md + PR/MR
   merge / close   ──────────────────▶  BOARD → done
```

## 新项目：一条命令

```bash
cd <你的项目>                     # 需要是 git 仓库（有提交）
bash <skill>/scripts/team bootstrap
```

`bootstrap` 幂等地把项目装到「可以派单」：探测当前 tmux session/窗口 → 写 `.pi/team/config.sh` +
`docs/team/` 文档骨架 + `AGENTS.md` 协议段 + `.gitignore` → **打印**每个 agent 的
`git worktree add` 命令（git 归 PM；想让它代建就加 `--create-worktrees`）→ 起看门狗（默认同 session 的
`watchdog` 窗口，`--container` 换 podman）→ 打印下一步清单。详见 [references/bootstrap.md](references/bootstrap.md)，
也可以把 `templates/bootstrap-prompt.md.tmpl` 交给新项目的 PM 让它照做。

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
$TEAM add-agent dev --create                        # --create 才代建 worktree（默认只打印 git 命令）
$TEAM dispatch dev T1.1 docs/team/tasks/T1.1-*.md
```

## 命令表

| 目的 | 命令 |
|---|---|
| 初始化 / 自检 | `team init [--session s] [--agents "a b"] [--vcs local\|github\|gitlab]`、`team doctor` |
| 观察 | `team roster`（窗口/分支/脏/领先）、`team status [ID]`、`team ps`（容量+模型并发+PM/watchdog 存活）、`team digest`（PM 待办） |
| 收件箱 | `team inbox [agent] [--ack] [--all]` |
| 文档契约 | `team task <ID> --title ... --agent a`、`team board add\|set\|ls`、`team thread <a> "..." --from pm --re <ID>`、`team report <ID> <a>` |
| 派单 | `team add-agent <a>`、`team dispatch <a> <ID> <taskfile> [--model m] [--fresh] [--print]` |
| 协作 | `team say <a> "<单行消息>" [--no-verify]`（发送后校验送达；agent 没在跑时落收件箱并提示 `resume`）、`team notify <a> "<一句话>"`（agent→PM） |
| 复验 | `team review <ID> --dir <PM 准备的独立 checkout> [--no-gates] [--strong]` → `reviews/<ID>.md`（只跑门禁 + 写证据；`--strong` 要求对抗性验证包 + finding 翻转证据） |
| 收尾 | `team close <ID> [--keep-window]`（只动 BOARD/状态/窗口，不碰 git）、`team teardown --agent a [--purge]`（模块化的窗口/worktree 清理，需显式指定） |
| 初始化 | `team bootstrap [--agents "dev verify"] [--print]`（推荐）、`team init`、`team doctor` |
| 看门狗 | `team watchdog up\|down\|restart\|status\|logs`（默认 tmux 后端：同 session 的 `watchdog` 窗口跑监视器；`--container` 换 podman 容器）、`team watch [--once]`（前台巡检） |
| 监视器 | `team monitor [--once] [--activity]`（**只服务当前 tmux session**：谁在跑/任务/待办/容量；`--activity` 才追加各 agent 会话活动流，默认关）、`team panel` 由它复用 |
| PM/agent | `team up [--agents]`（恢复 PM）、`team resume`（PM 的工具，续跑停了的 agent）、`team standby on\|off`（PM 主动停工） |
| 跨项目会议 | `team meeting open/say/read/list/inbox/propose/agree/close`（PM 对 PM 的 peer 交流：接口对接/建议/问题报告；**不是指令通道**，共识需双方 agree） |
| 更新 | `team mark-loaded`（开局记版本）、`team version --check`（是否该刷新）、`team changelog [--since X]`、`team reload` |
| 排障 | `team paths`（当前解析出的路径/session）、`team smoke`（端到端自测）、`team version` |

## 作为 PM 的循环（你该怎么做）

> 开局（或被叫醒后）先跑：`team digest` → `team inbox --ack` → `team resume --dry-run` → `team watchdog-status`。
> 职责划分：**watchdog 是“定时看看有没有活儿”的节拍器**（默认 15 分钟一次）：有待办才叫醒你，
> 没待办就不打扰，不要求你一直运行。agent 的启停/续跑、复验、合并都是你的事。
> 如果你确认无事可做或需要人工介入：`team standby on --reason "…"` 主动停工（之后不会再被叫醒，
> 人处理完 `team standby off`）。

1. **建模**：`team doctor`，必要时 `init`；把用户需求拆成里程碑写进 `ROADMAP.md`，
   每个任务写成**自包含**任务书（背景/交付物/边界/可复制的验收命令/报告要求）——
   默认开发模型是便宜模型，它不会纠正模糊需求。
2. **派单**：`team dispatch <a> <ID> <taskfile>`。派单前先 `team ps`（内存/模型并发）。
   一个 agent 一个长期 worktree；同一 agent 再派单即复用会话（断点续跑），要开新会话用 `--fresh`。
3. **等通知**：worker 回合结束会自动写 `inbox/<agent>.md` 并敲你的窗口叫醒你。
   不要轮询 agent 的屏幕；读 `team inbox --ack` 与 `team digest`。
4. **复验（不可跳过）**：`team review <ID>` —— 在独立 detached worktree 上跑门禁，产出
   `reviews/<ID>.md`。**报告是主张，复验结果是证据**；自己再读一遍 diff 是否满足任务书。
5. **通过** → 你自己跑 git/forge：squash 合并（有 PR 就先 `gh pr merge --squash --delete-branch <PR>` 再
   `git fetch && git merge --ff-only`）→ `team board set <ID> done` → `team close <ID>`。
   **不通过** → `team thread <a> "<失败证据 + 期望>"` + `team say <a> "<单行指令>"` 退回。
6. **收尾 / 汇报**：更新 `BOARD.md`（`team board set`）、把关键决策写进 `DECISIONS.md`（含理由与影响），
   向用户汇报「交付了什么 + 证据在哪 + 下一步」。用户要的是结论与风险，不是命令流水。

PM 需要停下来问用户的情况只有：合并/推送等**共享状态变更**（skill 用 `--yes` 表达授权）、
范围变更、需要用户拍板的选型（先派调研任务取证，再写 `DECISIONS.md`）。

## 拿到 skill 更新（三条路径）

```bash
bash <skill>/scripts/team mark-loaded      # PM 开局记一次：我这一会话加载的是哪个版本
bash <skill>/scripts/team version --check  # 任何时候：磁盘版本 vs 本会话版本 + 生效方式
bash <skill>/scripts/team changelog        # 变更史（--since v1.8.0 只看新的）
```

| 内容 | 生效方式 |
|---|---|
| `scripts/**`（CLI） | **零操作**：每次调用现读盘 |
| `SKILL.md` / `references/**` / `templates/**` | 在 Pi 里输入 **`/reload`**（或 `/pi-team-reload`，或让模型调 `reload_skills` 工具）。**注意**：`/reload` 只刷新技能清单/描述（system prompt）与扩展；**已经读进对话历史的正文不会变**，所以 reload 后要重新 `read <skill>/SKILL.md`（本扩展会在 reload 后自动发一条 follow-up 提示，触发这轮重读） |
| `extension/team-notify.ts` | 同上（`/reload` 会清扩展缓存并重新 import） |

依据：Pi 的 `/reload` 会重新发现 skill 并重建 system prompt，同时清扩展模块缓存、重新解析
`--skill`/`-e` 传入的路径。`team version --check` 提示"本会话是旧的"时，按上面表格操作即可；
不需要重启整个会话（`-c` 重启也不会丢历史，但没必要）。

## git 与 forge：PM 直接用工具，skill 不包装

skill **不执行**、也**不代打印** git/forge 命令——那属于"过度包装已有工具"。PM 按下面的约定直接用 `git` / `gh` / `glab`：

```bash
# ① 准备（每个 agent 一个长期 worktree；v1.11 起由 PM 建）
git -C <root> worktree add -b <分支> <root>/.worktrees/<agent> <保护分支>

# ② 开工前（dispatch 只检查、不代做）：工作树不脏、不在保护分支上
git -C <root>/.worktrees/<agent> status --short

# ③ 复验（PM 自己准备独立 checkout；skill 只跑门禁 + 写证据）
git -C <root> worktree add --detach /tmp/review-<ID> <分支>
team review <ID> --dir /tmp/review-<ID> --strong

# ④ 合并（有 PR：先合 PR 再快进本地；没 PR：本地 squash）
gh pr merge --squash --delete-branch <PR>          # 或 glab mr merge
git -C <root> fetch origin <保护分支> && git -C <root> merge --ff-only FETCH_HEAD
# 无 PR：git -C <root> merge --squash <分支> && git -C <root> commit -m "<ID>: <标题>"
git -C <root> push origin <保护分支>

# ⑤ 收尾：代码真的进了保护分支之后才标 done
team board set <ID> done
```

forge 无关：GitHub 用 `gh`、GitLab 用 `glab`/`curl`、Gitea 用 `tea`、没有 CLI 就网页操作——**都由 PM 决定**，
skill 不假设任何 forge。token 从配置的 token 文件读（`TEAM_TOKEN_FILE` / `TEAM_GITLAB_TOKEN_FILE`），
只在调用命令时注入，不回显、不写日志。

## 跨项目边界（谈事可以，指挥不行）

- **允许**：讨论接口怎么接、提建议+依据、报告问题与复现、约联调窗口、各自认领自己那半边。
- **不允许**：指挥别的 PM/agent、替对方决策、冒充人类下令、改对方仓库或状态。
- 跨项目讨论走 `team meeting`（PM 对 PM，文件为真相 + 可选敲门）；**worker 不参会**（在报告里写
  `BLOCKED:` 由 PM 去谈）。机制里没有 `command` 这种 intent，`--as-user` 只有人类终端能用。
- 详见 [references/meeting.md](references/meeting.md)。

## 不可协商的规则（会被复验）
- **没有真实执行过，不得声称通过**。报告必须带命令与输出尾部；PM 独立复跑。
- agent 只改自己有归属的目录（`OWNERSHIP.md`）；跨目录 → 报告写 `BLOCKED:`。
- agent 禁止 push 保护分支、force push、merge PR/MR、rebase/删除他人分支。
- token 放在项目里的 token 文件（`TEAM_TOKEN_FILE`/`TEAM_GITLAB_TOKEN_FILE`，`.gitignore` 忽略），
  由 PM 在调用真实工具时注入（`GH_TOKEN="$(< .gh-pat)" gh …`）；**永不回显、永不落盘、不进提交**。
- 会写共享状态的操作需要 `--yes`（= 用户已授权）：`team meeting open/close/agree` 等。
  git/forge 的写操作不经过 skill —— 由 PM 自己判断并执行（也是共享状态变更，同样要有授权）。
- 一个 agent 一个长期 worktree：**不要移动它**（Pi session 按 cwd 归属，移动等于丢记忆）。
- 默认 `TEAM_BRANCH_MODE=task`：**一任务一分支**（`task/<ID>-<slug>`，从保护分支切出），复验/合并/回滚的单位都是任务；
  想要一 agent 一长期分支就设 `agent`。
- **看门狗由 PM 配置**：`team watchdog up` —— 默认在**同一个 tmux session 的 `watchdog` 窗口**里跑
  `team monitor`（上半屏团队状态，下半屏每个 agent 的会话活动流），同时每 15 分钟（可配）巡检一次“有没有活儿”。
  `status` / `logs` / `down` 都支持；想让它在 tmux server 挂了之后也活着，用 `team watchdog up --container`（podman）。
- **PM 不需要一直运行**：有待办时才需要你在线。默认每 15 分钟一次定时巡检（`TEAM_WATCH_INTERVAL=900`，
  建议 300~3600）：有待办就叫醒你（你现在不在跑就用 `pi -c` 把你拉起来），没待办就什么都不做。
  **确认无事可做 / 需要人工介入时，`team standby on --reason "…"` 主动停工**——之后不会再被叫醒，
  待办积压仍会记进 `state/watchdog.log`，人处理完 `team standby off`。
  巡检**不管 tmux 布局、不管 agent**；停了的 agent 由你用 `team resume` 决定续不续。

## 深入阅读（按需，不要一次全读）

| 文件 | 什么时候读 |
|---|---|
| `references/protocol.md` | 想理解每条规则的理由（独立复验、唤醒机制、容量底线、保活链路、安全模型） |
| `references/config.md` | 配置键含义、项目落盘布局、环境变量覆盖（环境变量优先于配置文件） |
| `references/meeting.md` | 跨项目会议：边界（能讨论什么、不能干什么）、共享区、命令、敲门、守卫 |
| `references/bootstrap.md` | 新项目初始化：一条命令做什么、之后 PM 怎么走 |
| `references/workflows.md` | 端到端 runbook：建队、派单、复验、合并、**巡检/看门狗容器**、并行扩展、阻塞处理 |
| `references/troubleshooting.md` | 通知不到、会话丢失、worktree 冲突、forge 403、报告不实 |
| `templates/` | 需要手写任务书/报告/看板时抄模板 |
| `scripts/team`、`scripts/lib/*.sh` | 要改行为时（先用 `team <cmd> --print` 看它生成什么） |
| `tests/smoke.sh`、`tests/skill-load.mjs` | 想确认这套工具在本机可用：`team smoke`（临时仓库端到端自测，不碰本项目） |

## 环境要求

git（≥2.31，用 `--path-format=absolute`）、bash ≥4、tmux、pi（支持 `--session-id`/`-e`/`--skill`）。
可选：`gh`/`glab`（PM 自己用；`team doctor` 只做存在性提示）、podman（看门狗容器后端）。无 jq/python/node 依赖。
