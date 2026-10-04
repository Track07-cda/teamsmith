# P178 · 独立验证 P162（隔离前置硬停）—— 目前只有 PM 自验

```
task:   P178
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 只读验证与报告
deltas: -
grant:  docs/team/reports/P178-verify.md · docs/team/reports/P178-verify/**
deps:   合并 `fix(teamsmith): P162 …`（在 main ✓）· PM 复验 `docs/team/reviews/P162.md`（**只有我自验** ✗ → 本条补换人 ✓）· 实现自述 `docs/team/reports/P162-dev.md`（主张，不是证据）· 铁律：**一切破坏性实验在容器里** ✓（P162 本身就是这条纪律的机制 ✓）
status: wip
budget: 一次对抗性验证
priority: 高（它是**唯一**能挡住"隔离静默失效 → 打到共享默认 socket"的机制 ✓；四次 server 死亡都与门禁运行重合 ✓）
```

## 要独立证明或证伪的（**自己造形状**，别只用它的夹具）

1. **三条前置逐条** ✅：① 目标路径存在且属于本轮 ✓ ② 真 tmux 解析出的 socket 就是它 ✓ ③ **不是**共享默认 socket ✓ ——
   各造一个**只违反一条**的场景 ✓（例如：路径存在但是**上一轮**的 ✓、socket 对但不是本轮目录 ✓）→ 每条都要**硬停并点名那一条** ✓。
2. **无绕过** ✅：`TEAM_*` 一堆 ✓、`--force` ✓、`CI=1` ✓、`TEAM_SMOKE_*` ✓ 各试一次 → **都必须硬停** ✓；
   **影子**：把前置判据改成恒通过 → 上面每一条必须红 ✓（PM 试过 8 条 ✓，你自己再来一遍 ✓）。
3. **破坏性调用真的没执行** ✅：容器里把真 `tmux` 换成 argv 记录桩 ✓ → 硬停场景下**记录为空** ✓（构造性证明 ✓）。
4. **非破坏性调用不受影响** ✅：`list-sessions`/`display-message` 等照常透传 ✓（改动前行为逐字节相同 ✓）。
5. **审计行** ✅：段号 ✓ / 哪一条不成立 ✓ / **期望与实际 socket** ✓（回退靶要能看出来 ✓）；写失败**可见但不改判定** ✓。
6. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 0h` ✓ + 容器内 FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓。
