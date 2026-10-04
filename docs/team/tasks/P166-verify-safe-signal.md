# P166 · `safe-signal-discipline` 独立验证（换人：propose/apply 都是 dev-bob）

```
task:   P166
agent:  verify
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P166-<agent>.md · docs/team/reports/P166-<agent>/**
deps:   合并提交 `feat(teamsmith): P159 …`（在 main）· PM 复验 `docs/team/reviews/P159.md` ✓ · 实现自述 `docs/team/reports/P159-dev-bob.md`（主张，不是证据）· **残余边界**：`pgrep`/`pidof` 未纳入闸门 → 已转 P164 提案 ✓ · D31
status: wip
budget: 一次对抗性验证
priority: 高（这一族今天已经发生三次；且它是**唯一**能挡住"按模式杀进程"的机制）
```

## 铁律（先读，违反即报告作废）

**一切与 `pkill`/`killall` 有关的实验都在容器里做** ✓（`localhost/teamsmith-gate:local` ✓，容器自带 `/tmp` 与自己的 tmux server ✓）。
宿主上**只允许**：读代码 ✓、跑纯逻辑的 lint 扫描 ✓、`--help` 类只读调用 ✓。**绝不**在宿主上执行任何"可能落到真身"的形态 ✗。

## 要独立证明或证伪的（自己造，不要复用作者夹具的输出）

1. **拒绝的完整性** ✅：`pkill`/`killall` 的**每一种**选择形态（`-f` ✓ `-x` ✓ `-u` ✓ `-P` ✓ 裸名字 ✓ 绝对路径 ✓ `command pkill` ✓ `env pkill` ✓）
   在容器里都必须 **exit 64** ✓ 并**点名工具与完整 argv** ✓；`--help`/`-V` **必须放行** ✓（只读 ✓）。
   **红侧**：把闸门 shadow 成恒放行 → 上面每一条都要红 ✓。
2. **诱饵证明"没真杀"** ✅：造两个诱饵进程 ✓（名字/命令行含被匹配串 ✓）→ 拒绝之后**两个都活着** ✓；
   并且**你自己**要能证明真身没被调用 ✓（作者的做法是把容器里的 `/usr/bin/pkill`、`/usr/bin/killall` 换成记录桩 ✓ —— 你可以照做 ✓ 或用 `strace -f -e trace=execve` ✓）。
3. **记录与保留** ✅：每次调用一行 ✓（动作词表闭合 ✓）；**拒绝**记录进长保留 ✓ 且**熬得过主日志轮转** ✓；
   写失败 → **可见但不改判定** ✓（仍 64 ✓，不挂住 ✓）。
4. **`team bg stop` 只按记录** ✅：正常收作业 → 打印"信号了谁" ✓；
   **红侧**：把记录里的 pid 改成**另一个**进程（诱饵 ✓）→ 必须**拒绝或明确报不符** ✓（不许按名字猜 ✗）；记录缺失/畸形 → 拒绝且**什么都没发** ✓。
5. **lint 双向** ✅：自己造脚本 —— `pkill -f x` ✓、`xargs kill` ✓、`kill "$(pgrep -f x)"` ✓ → 三条都要红并**各自点名** ✓；
   `pid=$(cat job.pid); kill "$pid"` ✓、`kill -0 "$pid"` ✓ → **必须干净** ✓（不误报 ✓）。
6. **残余边界要如实量化** ✅：`pgrep`/`pidof` 未纳入闸门 ✓ —— 请在**容器里**复现"shell 里手敲 `kill $(pgrep -f …)` 会命中自己那条命令行"这一形状 ✓
   （PM 已复现：exit 143 ✓），并明确写进报告的"未覆盖"一节 ✓。
7. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 58` ✓ + 容器内 FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓。
