# P190 · P188（一份分类器 + 命令链 + 别名）独立验证 —— 换人

```
task:   P190
agent:  dev2
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 只读验证与报告
deltas: -
grant:  docs/team/reports/P190-dev2.md · docs/team/reports/P190-dev2/**
deps:   P186 的独立验证（四条：F1 builtin command / F2 命令链真杀 server / F3 别名漂移 / F4 探针过时 ✓）· 返工 **P188**（在 main ✓）· PM 复验（那条合并提交信息里 ✓，含我的同源影子 ✓）· **铁律：破坏性实验一律在容器内** ✓
status: wip
budget: 一次对抗性验证
priority: 高（它是"隔离静默失效 → 打到共享默认 socket"的唯一机制，已被绕过三轮 ✓）
```

## 要独立证明或证伪的

1. **一份实现** ✅（本轮的核心 ✓）：自己改**共享分类器**里的一处判定 ✓ → **运行时 shim 与套件包装器两侧**必须**同时**变 ✓
   （影子：让分类器恒"非破坏性" → 两侧的绕过用例**都必须红** ✓ —— PM 试过：0h ✗176、31c ✗83 ✓，你用自己的形状再来一次 ✓）。
2. **命令链** ✅：`tmux list-sessions ';' kill-server` ✓、带前置选项的变体 ✓、`command tmux … ';' …` ✓ → **必须硬停** ✓；
   **真执行验证**：容器里用**自己的私有 socket**跑同一条链 → `has-session` **仍为 0** ✓（前置真拦住了 ✓）。
3. **别名与包装** ✅：`killw` ✓ `killp` ✓ `builtin command tmux` ✓ → 必须硬停 ✓；**反向**：`list-sessions` ✓ `display-message` ✓ 照旧透传 ✓（逐字节相同 ✓）。
4. **不确定性 fail-closed** ✅：认不出的选项/缺值 → 按**破坏性**对待 ✓（不装懂 ✓）；自己造两种 ✓。
5. **F4 的探针前提** ✅：产品面探针现在证明"包装器存在且**同源**" ✓ —— 请自己**弄坏同源**（把共享文件挪走/改名 ✓）→ 探针必须红 ✓（不是删检查换绿 ✓）。
6. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 0h,31c` ✓ + 容器内 `--select 36` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
