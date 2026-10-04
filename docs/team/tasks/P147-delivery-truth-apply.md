# P147 · `delivery-truth` apply：真帧几何 + 队列阻碍如实 + notify 三处同名

```
task:   P147
agent:  dev
issue:
change: delivery-truth            # 提案已验收并合入 main（本任务书生成时的评审记录同上一次提交）
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  apply
anchor: change
deltas: delivery-guard,notify-and-inbox,panel
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/extension/** · skills/teamsmith/tests/** · panel/src/** · openspec/changes/delivery-truth/** · docs/team/reports/P147-<agent>.md · docs/team/reports/P147-<agent>/**
deps:   `openspec/changes/delivery-truth/tasks.md`（覆盖映射照它做）· P138 的容器配方与真帧（`docs/team/reports/P138-verify/pkg/` + `logs/`，**红侧基准**）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）不许碰 · **D31**：验证换人 · **归档顺序**：本 change 与 `meeting-liveness` 都改 `delivery-guard`，后归档者要在归档后的基线上重写 delta（D40/D42）
status: wip
budget: 一个工作块
priority: 高（真 Pi 上仍复现 ✗ 且是**假绿**形状：退出 0 + 永不兑现的承诺）
```

> 本地模式：不 push main；推送带 `[skip ci]`（CI 不是判据）。

## 交付 = `tasks.md` 全部做完，且**真帧红侧必须自己在容器里跑出来**

1. **几何按闭集形状定位**（P67/P78/P86 那一族）：真 Pi 的聊天区分隔线/空行/状态行不得被配成输入框边框；
   **红侧**：P138 的真实空框帧 → 修前 `second_received=0`，修后**恰好一次**进去（配方 `run-case.sh` + `judge-second.py`）。
2. **队列阻碍必须如实且有界**：无法可信判定几何时 → **不许**给"清空后自动投递"这类承诺；
   连续可信空框仍卡住 → `held`/`stalled` 之类**可见**结论 + 恢复命令 + 非 0 退出；
   **反向**：真草稿/正在工作的目标**不许**被误标为 stalled（场景已在 delta 里）。
3. **notify 三处一致**：耐久收件人文件、outbox 的 inbox 声明、wake 里的全文路径**指向同一个真实存在的文件**；
   **反向**：PM 仍是 knock 目标（行为不变）。
4. **不许放松任何既有守卫**（真草稿 → 推迟；至多一次 → 不变；M6.5 存活判据 → 不碰）。
5. 门禁：`openspec validate --all --strict` + **相关段**（投递/面板/inbox-watch）+ **FAST** + **一次全量**（动了投递主路径）；
   每条 What flips 留红→绿原始输出；报告点名"哪些自己跑、哪些引用 P138"。
