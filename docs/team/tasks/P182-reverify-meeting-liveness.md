# P182 · `meeting-liveness` **换人复验**（P153 FAIL → P160 返工之后）

```
task:   P182
agent:  dev
issue:
change: meeting-liveness
specs:  meeting#A knock names the turn it announces
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P182-<agent>.md · docs/team/reports/P182-<agent>/**
deps:   第一轮 `docs/team/reports/P153-verify.md`（F1 排队敲门不写账本 / F2 标识宽度随 git 配置 / F3 空闲分支造 task ✓）· PM 评审 `docs/team/reviews/P153.md` ✓ · 返工 **P160**（dev-bob ✓）· **换人** ✓（D31）
status: todo
budget: 一次对抗性验证
priority: 高（它是 `meeting-liveness` 归档的**唯一**前置；该 change 改的是巡逻 / 敲门投递 / 通知 / 待办读者 ✓ 面很广）
```

## 要独立证明或证伪的（**重点：上一轮三条真修好了吗**）

1. **F1 账本补记** ✅（自己造）：
   ① 目标忙/有草稿 → 敲门入队 ✓（**共享区此刻仍不写** ✓ —— 不许提前写 ✗）；
   ② 清空后 `outbox flush` 真正投递 → `knocks.log` **出现该轮次** ✓（`[meeting:<slug>#<turn>]` ✓ 同一轮号 ✓）；
   ③ **反向**：只入队、从未投递 → 账本里**没有**该轮 ✓。
2. **F2 标识宽度** ✅：把 `core.abbrev` 设成 7 ✓ 与 12 ✓ 各跑一次 → 同一 HEAD 的 `tip=` **逐字节相同** ✓；
   **影子**：把实现改回 `git rev-parse --short HEAD` → 两次必须**不同**（即断言红 ✓）。
3. **F3 不编造 task** ✅：在 `agent/<name>` 分支上（无 `state/<agent>.env`、无任务书、无看板行 ✓）→ inbox 行与 knock 载荷里**都没有** `task=` ✓；
   **反向**：真任务分支上**必须有** ✓。
4. **不许破既有承诺** ✅：真草稿仍受保护 ✓、至多一次 ✓、`standby` 不叫 ✓、无待办沉默 ✓（P109 那两条 ✓）。
5. **发现性与收尾** ✅（第一轮已验证过的部分，抽查即可）：未读会议进待办 ✓、过期可 `close --stale` ✓、`--peek` 不动读位 ✓。
6. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 55,56` ✓ + 容器内 FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓。
