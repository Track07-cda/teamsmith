# P186 · P180（隔离前置按 argv 解析）独立验证 —— 换人

```
task:   P186
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 只读验证与报告
deltas: -
grant:  docs/team/reports/P186-verify.md · docs/team/reports/P186-verify/**
deps:   第一轮 `docs/team/reports/P178-verify.md`（F1：首参分类可被 `-S`/`-L`/前置选项绕过 ✓）· 返工 **P180**（在 main ✓）· PM 复验 `docs/team/reviews/P180.md`（hmm：我没写独立评审文件 ✓，证据在那条合并提交信息里 ✓）· **铁律：一切破坏性实验在容器里** ✓
status: wip
budget: 一次对抗性验证
priority: 高（它是"隔离静默失效 → 打到共享默认 socket"的**唯一**机制 ✓，而第一轮它就被绕过了 ✓）
```

## 要独立证明或证伪的（**自己造形态**）

1. **动词解析** ✅：`-S <path>` ✓ `-L <name>` ✓ `-f <file>` ✓ `-c <cfg>` ✓ `-u` ✓ 组合 ✓、`--` 结束符 ✓、
   多选项叠加（`-u -f /dev/null kill-server` ✓）→ 动词都要被**解析出来**并过前置 ✓（不是绕过 ✓）。
2. **目标必须仍是本轮私有 socket** ✅：`-S /tmp/tmux-<uid>/default` ✓、`-L default` ✓ → **硬停** ✓；
   `-S <本轮私有 socket>` ✓ → 照常 ✓。
3. **同源纳入** ✅：`command tmux` ✓、`\tmux` ✓、`builtin command tmux` ✓ → 都走包装器 ✓（影子：把 `command()` 影子去掉 → 该形态必须红 ✓）。
4. **无绕过** ✅：`TEAM_*` 一堆 ✓、`--force` ✓、`CI=1` ✓ → 都硬停 ✓（第一轮验过 ✓，复跑 ✓）。
5. **真身未执行** ✅：容器里把真 `tmux` 换成 argv 记录桩 ✓ → 硬停场景记录**为空** ✓；正常场景记录**有** ✓。
6. **不误伤** ✅：非破坏性调用（`list-sessions` ✓ `display-message` ✓）逐字节透传 ✓（与改动前相同 ✓）。
7. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 0h` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
