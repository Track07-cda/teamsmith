# P24 · change 为中心的派单纪律（apply）

```
task:   P24
agent:  dev-bob
issue:  
change: change-centric-discipline        # 提案已验收并在 main：docs/team/reviews/change-centric-discipline-proposal.md
specs:  dispatch#A brief names at most one change id / dispatch#A change-less brief declares its spec anchor / dispatch#Two unfinished tasks of one change do not write the same delta file / verification#The verifier of a change is not one of its authors / board-and-status#team change status reports a change's readiness / board-and-status#tasks are grouped in the digest and the panel / board-and-status#An archive waits for every task of the change
phase:  apply
anchor: change
deltas: openspec/changes/change-centric-discipline/specs/{dispatch,verification,board-and-status}/spec.md
deps:   P23（propose，已合并）
status: todo
budget: 分批推进 B1…B7（见下）；做不完交 PARTIAL + 已完成批次清单
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev-bob`。

## 计划就是 change 自己的 tasks.md（别另写一份）

**唯一实施计划**：`openspec/changes/change-centric-discipline/tasks.md` 的 **B1…B7 + 门禁节**。
每个批次的验收、夹具、翻转都在那里；本任务书只补边界、顺序与碰撞协议。

## 顺序与碰撞协议（重要——现在有三个在飞任务动同类文件）

| 批次 | 现在可做？ | 理由 |
|---|---|---|
| **B1**（严格头部读取 + change read-model + `team change status`） | ✅ 现在做 | 新增函数，不动 digest 主体 |
| **B3 / B4 / B5 / B6**（派单守卫 ×3 + 归档前提） | ✅ 现在做 | 守卫挂在 dispatch/board 路径 |
| **B7**（模板 + `references/openspec.md` 清单第 9/10 点 + protocol/SKILL/AGENTS 与模板） | ✅ 现在做 | 文档与模板 |
| **B2**（digest 归组节 + 面板 token） | ⛔ **先不做** | `M50` 正在重写 digest 读取路径、`M49` 正在改面板字符串、`M48` 正在改面板聚焦——三者都会撞 B2 |

→ **B2 单独留到 M48/M49/M50 落地后**（我会另派一个小任务，或让本任务续跑第二阶段）。
现在做的批次**不要**顺手改 digest 的读取路径或面板渲染，只在你必须的地方加最小钩子（例如 read-model 供 B2 用的导出函数）。

**smoke.sh 冲突纪律**：只**追加**自己的段落，绝不重排他人段落；若与 M48/M50 的新段落在同一区，
按"两侧都留"解决并在报告里点名。`panel.js` 未改则**不要**重建；若必须重建，从合并后源码重建并在报告里写清。

## Boundaries

- **不许改 pi 的更新检查行为**（用户明令）；夹具遇横幅按 M45 的判据层容忍。
- 不改 `docs/team/DECISIONS.md`（PM 地盘）；不改在飞任务的三份 brief。
- 不改 `openspec/changes/console-project-settings/**`（M49 正在写它的 delta）。
- 所有守卫必须**拒绝时点名**（哪个 id/哪条 line/哪个文件/哪个任务），并在 `--force` 时写**一行审计**；
  规则 1（一任务一 change）**没有逃生门**。
- 新守卫不得扩大任何 agent 的权限（只收紧），不得让只读命令变慢到肉眼可见（B1 的 `team change status` 走一次扫描，别套娃）。

## Acceptance (must actually be run; 贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/flip-p23.sh          # tasks.md §8.2 要求的翻转包（若无此文件，在报告里说明你放在哪）
```
外加**手工实录**：① 一个带两个 change id 的 brief → dispatch 拒绝（贴文案）；② 一个 `anchor: none` 无理由 → 拒绝；
③ 同一 change 的两个未结束任务声明同一 delta → 拒绝并点名双方与文件；④ 归档阶段任务在兄弟未结束前 `board set done` → 拒绝；
⑤ `team change status <id>` 对「全完成 / 有一个未完成 / 未知 id」三种输入的实际输出与退出码。

## Report

`docs/team/reports/P24-dev-bob.md`：per requirement 的覆盖表 + 每批翻转（红→绿）+ 独立包路径 + **未做的 B2 与原因**。
