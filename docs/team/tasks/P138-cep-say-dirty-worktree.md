# P138 · 复现并归因 <peer-c> 报的"`team say` 在 agent 已 settle 且 worktree 脏时投递失败"

```
task:   P138
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 诊断与复现，只写报告
deltas: -
grant:  docs/team/reports/P138-verify.md · docs/team/reports/P138-verify/**
deps:   <peer-c> 的原始报告（共享区 `~/.pi/team/meetings/<peer>-pi-team-feedback/transcript/0005_*` 与 `0007_*` 的第 3 条 ✅）· 投递栈此后改过多处：M24/M30/P63/P67/P71/P81 ✅
status: todo
budget: 一个诊断
priority: 中高（同行 PM 报了两遍、我们两周没评估 ✅）
```

## 要回答的问题（不许引用别人的结论，自己造现场）

<peer-c> 的原话（两遍）：**`team say` 在 agent「已 settle 但留下未提交文件」时报成功却没投递**。

1. **今天是否仍复现？** 在**当前 main** 上自己造场景：一个真实 agent 窗口（私有 socket ✅ 见安全铁律）+
   让它停下并**留下未提交文件** ✅ → 对它 `team say` / `team notify` ✅ →
   检查**收件箱**、`state/outbox/**` 队列、投递日志（`.deliver` journal ✅）与实际**输入框内容** ✅ →
   结论必须是**二选一**：**仍复现**（给出最小复现步骤 + 原始输出 ✅）或**已不复现**（给出证据链 ✅）。
2. **若不复现，是哪一次改动关掉的？** 在投递栈的历史提交上**折半**定位 ✅（M24/M30/P63/P67/P71/P81 一族 ✅），
   并给出**反证**：在那个改动之前 / 之后各跑一次同一场景 ✅（红→绿 ✅）。
3. **若仍复现**：给出**最小**复现场景 ✅ + 涉及的代码路径（判定/排队/claim/确认 ✅）+ 为什么"报成功" ✅，
   并把它写成**可直接派单**的缺陷描述 ✅（我会另开 apply ✅）。
4. **边界**：明确写清你**没有**测到什么（例如只测了 tmux 适配器 ✅、未测非 Pi 适配器 ✅）。

## 安全铁律（D37/D57 · 记忆 #1794，务必遵守）

- **绝不**对**共享默认 tmux socket** 做任何破坏性/实验性操作 ✅ —— 用 `skills/teamsmith/tests/container-tmux.sh` ✅
  或**私有 socket**（`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<已 mkdir -p 的私有目录> tmux …` ✅）；
- 只对自己 spawn 的 PID 发信号 ✅ 不按命令行模式匹配 ✅ 不 SIGSTOP ✅；
- 不碰其它项目的仓库与会话 ✅（本任务只需本仓库的临时项目 ✅）。

## 交付

报告含：结论（复现/不复现）✅、最小复现或反证 ✅、原始输出 ✅、没测到的边界 ✅。
