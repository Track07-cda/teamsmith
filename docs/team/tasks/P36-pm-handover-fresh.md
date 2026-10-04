# P36 · PM 会话交接：`team up --fresh-pm` + init skill 的交接段 + 同 cwd 活会话提示

```
task:   P36
agent:  dev2（实现）—— **不得派给 verify 席位**：OWNERSHIP 明文 verify 不改实现（M53 先例；P36 第一次派给 verify 已被 BLOCKED）
issue:
change: -
specs:  pm-lifecycle#PM liveness is proven, not inferred
phase:  apply
deltas: -
deps:   M8.1（`TEAM_PM_RESUME_ARGS` / `TEAM_PM_SESSION_ID` 的续跑优先级）· v1.42.0
status: todo（等一个非 verify 席位空出）
input:  verify 席位的只读勘察 + 实施地图：`.worktrees/verify/docs/team/reports/P36-verify.md`（commit e552f4e）——可直接采用，省一轮摸索
budget: 半个工作块
```

> 本地模式：不 push。**用户 2026-09-22 明确选择 A+B+C。**

## 现状（PM 已从代码核实，别凭记忆改）

- `team up` = 「建 tmux 场地 + 把 PM 拉起来（`pi -c` 保留历史）」；
- PM 的续跑参数优先级（`common.sh:775`、`team_pm_pi_args`）：`TEAM_PM_SESSION_ID` > 显式
  `TEAM_PM_RESUME_ARGS` > **历史的 `-c`**；`-c` 按 **cwd** 找上一个会话 → 由于 init 就是在**项目根**跑的，
  **PM 默认续用 init 那场对话**；
- **风险**：init 会话若还开着，`team up` 用 `-c` 会**两个进程续同一个会话文件（双写）**。

## A. `team up --fresh-pm`（新旗标）

- 语义：**明确开一场新对话**（不 `-c`），旧会话文件原样留在历史里（作为"开工记录"）；
- 实现口径：与 `--fresh`（dispatch/resume 的）同族——**只影响这一次启动**，不写进配置；
- 与既有优先级的关系要写清（`TEAM_PM_SESSION_ID` 仍优先？还是 `--fresh-pm` 最优先？**给一个明确裁断并写进 `--help`**）；
- `--print` 下要能看到"这次会新开会话"的证据（可断言）。

## B. init skill 的交接段

`skills/teamsmith-init/SKILL.md`：把"跑完 bootstrap 之后"写成明确的交接三步：
1. `bash <teamsmith>/scripts/team bootstrap …`；
2. **退出本会话**（或确认本会话就在 pm 窗口里）；
3. `bash <teamsmith>/scripts/team up [--fresh-pm]` —— 并说明**默认续用 init 那场对话**、要新对话就加旗标。

## C. 同 cwd 活会话提示

`team up` 在启动前**探测**：同 cwd 是否**已有活着的 Pi 进程**（读 `/proc/*/cwd` + argv 命中 agent 二进制；
只读，不算 PM 判活——不要动 M6.5 的判活逻辑）。命中时：
- 打印**明确提示**（"检测到同目录还有活着的 Pi 会话：pid N —— `-c` 可能双写；建议先退出它，或用 `--fresh-pm`"）；
- **不阻断**（提示而非拒绝），且**不改变**现有 PM 判活/替换语义。

## 必须给的证据

- A：`--print` 输出 + 一次**真跑**（私有 tmux server 上起一个临时项目？可以，别碰本项目的 pm 窗口）：
  干净环境里 `--fresh-pm` 起出的 PM **不是** `-c`（用启动日志/会话文件对比证明）；
- B：改后的 SKILL.md 段落原文；
- C：构造"同 cwd 有活 Pi"的场景（**用假进程/临时目录起一个 `pi` 太贵？退而求其次**：
  用 `/proc` 可读的真实进程证明探测逻辑，或写一个夹具注入假 pid 目录）→ 提示出现；**反向**：
  无同 cwd 活会话时**不打**提示。

## 翻转（红→绿原始输出）

- 去掉 `--fresh-pm` 的分支 → 对应断言红；
- 去掉 C 的探测 → 提示断言红；还原后 `git status --porcelain` 干净。

## Acceptance

```sh
bash skills/teamsmith/scripts/team help | grep -A2 "up \["
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Boundaries

- 只碰这些路径（**已按 verify 的只读勘察修正**——`team up` 的入口不在 cmd-agents.sh）：
  `skills/teamsmith/scripts/lib/cmd-watch.sh`（`team_cmd_up` 的参数解析与 `--print`，:117/:130）、
  `skills/teamsmith/scripts/lib/common.sh`（`team_pm_pi_args` :1861、`team_pm_continuity` :2143 /
  `team_pm_continuity_note` :2159、可复用的只读 `/proc` 助手 `team_proc_cwd` :1484 / `team_cmdline_is_bin`）、
  `skills/teamsmith/scripts/lib/cmd-project.sh`（`--help` 文案 :68）、`skills/teamsmith/scripts/team`、
  `skills/teamsmith-init/SKILL.md`（`## 2. Handoff`）、`skills/teamsmith/references/troubleshooting.md`（若需一句）、
  `skills/teamsmith/tests/smoke.sh`（append-only，§11/§11b2 一带）；
  勘察地图：`.worktrees/verify/docs/team/reports/P36-verify.md`（含两条口径提示：`fresh` 用"本次启动"变量 +
  `team_pm_continuity()` 报 `fresh:` 作为可断言证据；C 只读复用 `/proc` 助手，**不许改** `team_pm_state`/`team_pm_alive`）；
- **不许改** M6.5 的 PM 判活/替换语义、不许改 agent 的 `--fresh` 语义、不碰 outbox/通知路径；
- 不 push；不改 `docs/team/**`。
