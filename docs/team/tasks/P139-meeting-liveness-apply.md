# P139 · `meeting-liveness` apply：发现性 + 收尾 + 投递安全 + 每方窗口 + 身份判定 + 可判定标识

```
task:   P139
agent:  dev3                     # 提案人继续实现（守卫只要求"复验换人" ✅，D31 允许多阶段同人 ✅）
issue:
change: meeting-liveness         # 提案已验收并合入 main（reviews/meeting-liveness-proposal.md）
specs:  meeting#A participant is recognized by its recorded names, not by one spelling
phase:  apply
anchor: change
deltas: meeting,notify-and-inbox,watchdog,delivery-guard,panel
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/extension/team-notify.ts · skills/teamsmith/tests/** · openspec/changes/meeting-liveness/** · docs/team/reports/P139-dev3.md · docs/team/reports/P139-dev3/**
deps:   `openspec/changes/meeting-liveness/tasks.md`（**覆盖映射与每项的 verify/red 都在里面，照它做** ✅）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）**不许碰** ✅
status: todo
budget: 一个工作块
priority: 高（用户已批 A+B+规格+投递安全 ✅；D65 的实证 ✅）
```

> 本地模式：不 push main。**CI 不是判据**（D54）：推送带 `[skip ci]`。

## 交付 = change 的 `tasks.md` 全部勾完（含每项自己写的 verify 与 red）

不要跳项：`tasks.md` 的覆盖映射已经把每条 requirement 对到具体条目（1.1–1.4 发现性/读位、2.1–2.4 过期与收尾、
3.1–3.6 投递安全与标识、4.1–4.5 每方窗口与身份判定、5.1 面板、6.1–6.4 门禁、7.1 独立验证）。

## 除 `tasks.md` 外，本次特别要求

1. **身份判定（R1）要按"记录名任一并集"实现** ✅：`open` 写发起方仓库名、`peer`/`--repo` 可写对方仓库名 ✅、
   `state.env` 同时留 session ✅ → 判定时**声明名 / 仓库 basename / session 任一匹配即算参与方** ✅；
   **真正不在名单里的项目仍必须被拒** ✅（这条要有红侧 ✅）。
2. **标识（R2）两个面都要** ✅：会议 knock → `[meeting:<slug>#<N>]` + `knocks.log` 同号 ✅；
   任务侧 turn-end 通知 → inbox 行与 knock 载荷都带 `task=<ID> tip=<7-hex>` ✅，
   **接收方仅凭自己的账本**（board 状态 / `reviews/<ID>.md` 里的 HEAD）就能判 stale ✅，
   **不许**要求它去读发送方工作树 ✅；没有 task 记录的（worktree 外的手工 `team notify`）**不许编造**标识 ✅。
3. **投递安全** ✅：敲门一律走受守卫的投递 ✅；忙 → 一条 `state/outbox/**` 队列项 + 命令报 `queued`（不是 `knocked`）✅；
   红侧：把发送器换回裸 `send-keys` → "草稿不被污染"那条必须红 ✅。
4. **发现性不许打扰** ✅：无未读会议时巡逻**必须静默** ✅（基线场景保留 ✅）；`team meeting read --peek` **不动**读位 ✅。
5. **`team_pending_counts` 的 tuple 变更**：新增末字段要**同一提交**改完**所有**读取点 ✅
   （bash 会把多余的词折叠进最后一个变量 —— `tasks.md` 1.2 已点名 ✅）；并要求"快速读数与全量读数逐字节一致"的断言 ✅。

## 门禁与证据

`openspec validate --all --strict` ✅ + **FAST 全绿** ✅ + **一次全量**（本 change 动了巡逻/投递 ✅）；
每条 What flips 与每个红侧都留**原始输出**（红→绿）✅；报告里点名**哪些是你自己跑的、哪些是引用** ✅。
