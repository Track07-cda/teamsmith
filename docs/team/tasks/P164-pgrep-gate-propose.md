# P164 · `signal-gate-pgrep` propose：`pgrep`/`pidof` 要不要也纳入闸门，以及哪些形态可以放行

```
task:   P164
agent:  verify                        # propose 只写 openspec/changes/**（不违反 D36）
issue:
change: signal-gate-pgrep
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  propose
anchor: change
deltas: boundary
grant:  openspec/changes/signal-gate-pgrep/** · docs/team/reports/P164-verify.md · docs/team/reports/P164-verify/**
deps:   P159 的实现与残余边界（评审 `docs/team/reviews/P159.md` ✓）· 三次同族事故：**D37（dev3 按模式 SIGSTOP ✓）、D57/#1529（我用 `pgrep -f` 取到自己的 shell ✓）、D72（dev-bob 用 `pkill -f` 误杀同期门禁客户端 ✓）**——**其中两次是 `pgrep` 基** ✓ · lint 现状（`tests/signal-lint.pl`：覆盖脚本里的 `kill $(pgrep …)` ✓，但**只读脚本** ✗）
status: wip
budget: 一个提案
priority: 中高（同族事故 3 次、其中 2 次走 `pgrep`；但**不要过度设计** —— 用户的既有裁断是"别把 skill 过拟合复杂化" ✓）
```

## 现场（我在容器里实测的形状）

```
PATH 里放 P159 的 shim → pkill -f <标记>            → exit 64 ✓（被拒）
                       → kill $(pgrep -f <标记>)    → **放行** ✗ → 模式命中我自己那条命令行 ✗ → 杀掉我自己的探针 shell（exit 143）
```
即：闸门覆盖 `pkill`/`killall` ✓，**不覆盖 `pgrep`/`pidof`** ✗；lint 能抓**脚本里**的形态 ✓，**shell 手敲**的看不见 ✗。

## 要 propose 的（**必须给出取舍与代价**，不许"全都拦"）

1. **先量清楚**：仓库里 `pgrep`/`pidof` 的**合法用法**有哪些 ✓（已知至少三处：`common.sh` 的 `pgrep -g <pgid>` ✓、
   `tests/panel-cpu.sh` 的 `pgrep -P <pid>` ✓、`tests/smoke.sh` 的 `pgrep -fc <路径>` 只读断言 ✓）——
   **逐条列出并判断**"纳入闸门后会不会被误伤" ✓。
2. **裁一个窄规则**（给方案与代价）：
   - 方案 A：只拦**按模式/按用户**的形态（`-f` ✓、`-u` ✓），放行按 **pgid/parent** 的（`-g` ✓、`-P` ✓）；
   - 方案 B：全拦 `pgrep`/`pidof`，把仓库里三处合法用法**改成按记录 pid**（代价：改产品代码 ✓）；
   - 方案 C：不拦，**只在文档里写明残余边界** ✓（代价：shell 手敲仍可绕过 ✓，且这与"三次事故两次走 pgrep"的事实不符 ✗）。
   给出推荐 ✓ 与**可证伪的红侧**（例：把闸门 shadow 成恒放行 → 新断言必须红 ✓）。
3. **不许扩成"什么都拦"** ✗：任何放行形态都要有**理由与证据** ✓；不许把 `ps`/`fuser` 这类**只读**工具一并拦掉 ✗（除非你能量出它们的危险形态 ✓）。
4. **与 P159 的关系**：P159 已合入 ✓；本 change 若落地，须与它**同一契约**（同一条 requirement ✓ 不许另立一套 ✗）。
5. 交付：`openspec/changes/signal-gate-pgrep/{proposal,design,tasks}.md` + `specs/boundary/spec.md` ✓ +
   `openspec validate --all --strict` ✓ + MODIFIED 不丢基线场景（给前后对照 ✓）+ 每条 What flips 有红侧 ✓。
