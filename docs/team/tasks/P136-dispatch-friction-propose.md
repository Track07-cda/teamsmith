# P136 · `dispatch-friction` propose：派单摩擦与幂等

```
task:   P136
agent:  dev2
issue:
change: dispatch-friction
specs:  dispatch#One task branch per task · dispatch#A brief names at most one change id · dispatch#The printed route is a route that works · dispatch#A dispatch never mixes two tasks in one worktree
phase:  propose
anchor: change
deltas: dispatch
grant:  openspec/changes/dispatch-friction/** · docs/team/reports/P136-dev2.md · docs/team/reports/P136-dev2/**
deps:   D66（<peer> 的 8 条回答 ✓）· D62/D61（PM 自己踩的同一族 ✓）· 保持既有守卫语义（D16 叠任务 · M6.3 分支身份 · D24 一个 change · D36 verify 席位 · D40 归档顺序 ✓）
status: todo
budget: 一个提案
priority: 高（这是使用方 PM 列的第一号摩擦 ✓）
```

## 现场（两个独立使用者各自撞到，都要变成可证伪的 requirement）

一位同行 PM（两周约 30 个任务）与 PM 自己（2026-09-30 一夜）都遇到同一组摩擦：

1. **分支名循环**：dispatcher 从**任务标题/阶段**推导期望分支名，而 agent 按任务书**预建**另一个名字 → 被拒 →
   查期望名 → `git switch -c` 重命名 → 再派。对方约 **10 次**；PM 一夜 **3 次**（`task/P134-p134` vs 要求
   `task/P134-propose`；`task/P135-apply` vs 要求 `task/P135-infra-tidy-close-iproute2-fa`）。
   **要求**：派单**输出**里必须给出期望分支名（并说明它从哪里推导 ✓）；任务书模板/派单提示要让 agent **不必猜**；
   `--branch <名>` 显式指定必须可用。**守卫不许放松**：工作树停在**别的任务**的分支上仍必须拒。
2. **`change:` 行的报错文案**：`change: panel（说明）` 这种自然写法被拒，报错要看两次才懂；`deltas:` 的合法
   语法（**逗号分隔 capability**，不是 `·`）PM 自己也撞了一次。
   **要求**：报错**第一行**给出合法格式示例 ✅ 与**为什么**非法 ✅。
3. **配额预提示**：对方撞过两次 403（kimi 周额度 / Codex 额度），当时**工具沉默**（会话 0 token 空转，人工查 tmux 才发现）；
   机制侧已有死因分类 ✅，但**派单时**仍不提示。
   **要求**：派单前若目标席位**上一轮 0 token 产出**或最近死因是 `quota`/`balance` → 打印**可见提示**（**不阻断** ✅；
   判不出来就**闭嘴** ✅，不许猜）。
4. **幂等**：同一任务修正后重派，现在最多被**不同守卫各拦一次**（对方重试 **5 次**）。
   **要求**：一次重派最多**一次**可执行的拒绝 ✅；拒绝消息必须给出**可直接粘**的修复命令 ✅。

## 交付

`openspec/changes/dispatch-friction/{proposal,design,tasks}.md` + `specs/dispatch/spec.md` ✅
（**非目标**：不放松任何既有守卫 ✅ 不引入无审计的绕过开关 ✅ 不改 `docs/team/**` 的记录格式 ✅）
+ `openspec validate --all --strict` ✅ + MODIFIED 不丢基线场景 ✅ + 每条 What flips 有红侧 ✅
