# P179 · `dispatch-friction` **换人复验**（P149 FAIL → P151 返工之后）

```
task:   P179
agent:  verify
issue:
change: dispatch-friction
specs:  dispatch#A refused dispatch hands over every blocker, once, with a fix that runs
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P179-<agent>.md · docs/team/reports/P179-<agent>/**
deps:   第一轮 `docs/team/reports/P149-verify.md`（FAIL：五条缺陷 ✓）· PM 评审 `docs/team/reviews/P149.md` ✓ · 返工 P151（在 main ✓）· **换人** ✓（D31）
status: todo
budget: 一次对抗性验证
priority: 中高（它是 `dispatch-friction` 归档的诚实前置；且它改的是**派单主路径** ✓）
```

## 要独立证明或证伪的（重点：上一轮五条真修好了吗）

1. **一次列全** ✅：自己造**四个**同时成立的阻塞项（工作树停在别的任务分支 ✓ + 头部 `change:` 两行 ✓ + `deltas:` 用 `·` ✓ + 未提交改动 ✓）→
   一次调用**全部**出现 ✓、总数与逐条自洽 ✓、每条**修法可粘贴** ✓（**照着粘贴真的能修好** ✓ —— 上一轮的 F1/F2 就在这里 ✓）。
2. **同一任务的另一 slug 放行 / 别的任务仍拒** ✅（上一轮 F4 是"兄弟循环里 `return` → 只报第一个" ✓，请**造两个**未完成的兄弟 ✓）。
3. **上一轮产出的判定时点** ✅（F5：字节数取在 respawn 之后 ✗ → 把真实产出说成 0 ✓）：造一个"上一轮有产出"的席位 → 提示**不许**说 0 ✓。
4. **续跑提示的分支名** ✅（W2/W3）：预建同任务的另一种 slug ✓ → 提示里出现的必须是**守卫接受的那条** ✓（不是推导名 ✓）。
5. **配额预提示** ✅：判得出来点名类别 ✓、判不出来**闭嘴** ✓、**不阻断** ✓。
6. **门禁**：`openspec validate --all --strict` ✓ + `--select 54` ✓ + FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
