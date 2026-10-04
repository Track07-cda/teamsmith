# P180 · P162 返工：隔离前置只看**首参**，`-S`/`-L` 与命令链都能绕过它

```
task:   P180
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改隔离前置的 argv 解析与其红侧
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/scripts/lib/** · docs/team/reports/P180-<agent>.md · docs/team/reports/P180-<agent>/**
deps:   P178 的独立验证（`docs/team/reports/P178-verify.md` ✓，容器内用 argv 记录桩实测绕过 ✓）· P162 的实现 `smoke.sh:583-591`（`case "${1:-}"` **只看首参** ✗，其余落 `*) command tmux "$@"` **原样透传** ✗）· M36/M67 的闸门（已有 argv 解析可参照 ✓）· 四次 server 死亡的历史（D80/D81/D83 ✓）
status: wip
budget: 一个工作块
priority: **最高**（这条前置是挡"隔离静默失效打到共享默认 socket"的**唯一**机制 ✗，而它可被一个 `-S` 绕过 ✗）
```

## 现场（验证者容器内实测；我读代码确认）

`smoke.sh:584` 的 `case "${1:-}"` 只判**第一个词** ✗ → 下列形态**不进前置** ✗、直接 `command tmux "$@"` **原样执行** ✗（argv 记录桩收到了它们 ✓）：
```
tmux -S /tmp/tmux-<uid>/default kill-server      # 显式指共享默认 socket
tmux -L default kill-server                      # 等价写法
tmux -f /dev/null kill-server                    # 其它前置选项
（命令链/包装：任何让 kill-server 不在 argv[1] 的写法）
```
即：**破坏性动词不在首位就能绕过** ✗ —— 与"隔离没生效"叠加时，正是打死共享 server 的形状 ✓。

## 要做的

1. **按 argv 解析出"动词"** ✅：跳过**前置选项**（闭集：`-S` ✓ `-L` ✓ `-f` ✓ `-c` ✓ `-u` ✓ `-2` ✓ `-8` ✓ `-v` ✓ `-V` ✓ `-D` ✓ `-C` ✓ `-N` ✓ … 带值的要跳过其**值** ✓），
   取第一个**非选项**词作为动词 ✓；动词属于 `kill-server|kill-session|kill-window|kill-pane` → **过前置** ✓；
   **不许**用"整条命令行包含某串"当判据 ✗（#1529 ✓）。
2. **目标也要判** ✅：若调用方给了 `-S <路径>` 或 `-L <名字>` ✓ → 该目标**必须仍等于本轮的私有 socket** ✓；
   指向**共享默认 socket**（`/tmp/tmux-<uid>/default` ✓ 或 `-L default` ✓）→ **直接硬停** ✓（哪怕前置三条件都成立 ✓）。
3. **命令链** ✅：若一次 shell 调用里有多个 tmux 调用 ✓（`a; tmux kill-server` ✓ / `a && tmux kill-server` ✓）→
   包装函数天然只包住 `tmux` 这个词 ✓ —— 请**核实**还有哪些形态能绕 ✓（例如 `command tmux` ✗ / `\tmux` ✗ / 绝对路径 ✗ ✓ ——
   **绝对路径本就在射程外** ✓（设计如此 ✓），但 `command tmux` 与 `\tmux` 属于**同一条 PATH 解析** ✓ → 一并纳入 ✓）。
4. **红侧（逐形态，容器内 + argv 记录桩）** ✅：上面每一种绕过形态 → **必须硬停** ✓ 且**记录桩为空** ✓；
   **影子**：把动词解析改回"只看首参" → 每种绕过形态必须红 ✓；
   **反向**：正常形态（`tmux kill-server` ✓、`tmux -S <本轮私有 socket> kill-session -t <本轮> `✓）→ **照常执行** ✓（不许误伤 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 0h` ✓ + 容器内 FAST ✓；
   报告点名"哪些自己跑、哪些引用 P178" ✓；**复验换人** ✓。
