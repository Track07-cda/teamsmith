# teamsmith

**让一个 agent 真正负责一个项目**：自己排期、派活、独立复验、合并、留账。
默认跑在 Pi 上，设计上适配任意 TUI Agent（适配层见 ROADMAP M3.0）。

一句话对照：它是"项目的负责人 + 一支可被检阅的 crew"，而不是"更多 agent 一起聊天"。

## 它到底做什么

| 能力 | 具体机制 |
|---|---|
| 派活 | 任务书写成自包含（背景/交付物/边界/可复制验收命令），`team dispatch` 把 agent 拉进自己的 tmux 窗口与 worktree |
| **独立复验** | agent 的报告是**主张**；PM 在**独立 checkout** 上跑门禁才是证据（`team review <ID> --dir …`） |
| 留账 | `BOARD.md`（状态）、`reviews/`（复验证据）、`threads/`（决策往来）、`DECISIONS.md`（为什么） |
| 不僵化 | 看门狗只在"有待办"时叫醒负责人；PM 可 `standby` 主动停工；容量不足就排队而不是硬上 |
| 边界 | 跨项目只能"谈事"（`team meeting`），不能指挥；git/forge 归负责人自己用工具做 |

完整设计理念见 [references/philosophy.md](skills/teamsmith/references/philosophy.md)（8 条信条）与
[references/protocol.md](skills/teamsmith/references/protocol.md)（为什么这样定规则）。

## 已收录

| Skill | 说明 |
|---|---|
| [`teamsmith`](skills/teamsmith/SKILL.md) | 见上；旧名 `pi-team`（`skills/pi-team` 是兼容软链） |

## 兼容（旧名 pi-team）

- 命令仍是 **`team`**；项目配置仍是 **`.pi/team/config.sh`**；环境变量仍是 **`TEAM_*`**；文档仍是 **`docs/team/**`**。
- 旧路径 `skills/pi-team` → 软链到 `skills/teamsmith`（老配置里的绝对路径继续可用，零改动）。
- `AGENTS.md` 里的 `<!-- pi-team:begin -->` 标记会在下次 `team init/bootstrap` 时就地迁移。

## 安装

```bash
./install.sh                 # 软链到 ~/.agents/skills（改仓库即生效）
./install.sh --copy          # 复制一份
./install.sh --target ~/.pi/agent/skills
./install.sh --uninstall
```

或者不改动文件系统，直接让 Pi 从本仓库加载：

```json
{ "skills": ["~/Documents/syncthing/Work/Projects/pm-skills/skills"] }
```

## teamsmith 快速开始

```bash
SKILL=~/.agents/skills/teamsmith
cd <你的项目>                                  # 需要是 git 仓库
bash $SKILL/scripts/team init --session myproj --agents "dev verify"
bash $SKILL/scripts/team doctor
tmux new -s myproj -n pm                       # 在里面跑 pi（PM 会话）
bash $SKILL/scripts/team task T1.1 --title "第一个任务" --agent dev
bash $SKILL/scripts/team add-agent dev
bash $SKILL/scripts/team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
bash $SKILL/scripts/team digest                # PM 待办
git -C . worktree add --detach /tmp/review-T1.1 task/T1.1-*   # PM 准备独立 checkout
bash $SKILL/scripts/team review T1.1 --dir /tmp/review-T1.1      # 只跑门禁 + 写复验记录
# 合并由 PM 自己跑：git merge --squash <分支> && git commit && git push，然后 team board set T1.1 done
```

完整命令与流程见 [`skills/teamsmith/SKILL.md`](skills/teamsmith/SKILL.md) 与
[`references/`](skills/teamsmith/references/)。

## 设计来源

`teamsmith` 把 [composable-enterprise-platform](../composable-enterprise-platform) 项目里
已经跑起来的一套 PM Agent 管理规范，抽象成与项目无关、可一键安装的 skill：

| 原项目做法 | teamsmith 的改进 |
|---|---|
| `scripts/pm-*.sh` 里硬编码仓库路径、tmux session、章节 | 全部参数化到项目内 `.pi/team/config.sh`；脚本只从 skill 目录读取，升级 skill 即全项目受益 |
| `scripts/pm-dispatch.sh` 只支持 GitHub + 固定模型 | `TEAM_VCS=local\|github\|gitlab`；模型/并发上限/容量底线可配置并在派单前守卫 |
| `.pi/extensions/pm-notify.ts` 每个项目复制一份 | 扩展留在 skill 内，`dispatch` 用 `-e` 显式加载（worktree 不会自动发现项目扩展）并新增去重 |
| `docs/pm/**` 手工维护 | `team task/board/thread/report/review` 生成并维护骨架，状态可机器读取 |
| 复验靠人记流程 | `team review` 在独立 detached worktree 上跑门禁并写 `reviews/<ID>.md` 证据文件 |
| 教训散落在 AGENTS.md 各处 | `references/troubleshooting.md` 集中沉淀（通知不达、会话丢失、squash 合并、forge 403…） |
| 没有保活：PM 停了整支团队断线；内存守卫用“可用 RAM 阈值”，偏保守 | `team watch` + `install-watchdog`：**只保 PM 一个进程**的自愈守护（systemd → watchdog → PM，agent 归 PM 管）；人工救火 `team up`。容量底线改成 **swap 不被打满**，RAM 紧只警告（允许卡顿，不允许崩） |

## 自测

```bash
bash skills/teamsmith/tests/smoke.sh        # 临时仓库里端到端跑一遍（不碰当前项目）
bun  skills/teamsmith/tests/skill-load.mjs  # 用 pi 自己的解析器验证 SKILL.md
```

## License

MIT

## 边界

本仓库的 agent 只在**本仓库**里工作（改 skill、加测试、写文档），不读/不改其他项目的仓库与会话、
不操作其他项目的 tmux、不替别人合并代码。反馈由用户转达或用户点名文件。详见 [SCOPE.md](SCOPE.md)。
