# P44 · pty 夹具的负载前提：`panel-p21` 在忙机器上不许假红（propose）

```
task:   P44
agent:  dev3
issue:
change: pty-fixture-load-premise
specs:  -
phase:  propose
anchor: change
deltas: verification, panel
deps:   M59（settled-frame 引擎）· M68/P30/P32（新 pty 段）· D33（性能不进正确性门禁）
status: todo
budget: 一个工作块（只出提案包；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 问题（PM 实测，2026-09-22）

`panel-p21.sh choices` 在**机器忙时确定性失败**：

```
load ≈ 11 → ✓ 48 ✗ 89   （连跑 3 次，计数器完全一致 → 不是抖动，是等待预算被耗尽）
load ≈ 2  → ✓ 110 ✗ 0   （连跑 2 次）
```

同一天我还实测到：`panel-p21 choices` 在 **load≈11** 与安静机的**行数/断言数一致**，差别只在**有没有等到**。
后果：门禁在团队并行干活时假红（今天已为此浪费过好几轮复验），而 D33 已经定过"性能不进正确性门禁"——
**pty 夹具是正确性夹具，但它现在的等待预算事实上把"机器忙"当成了失败。**

## 要裁决的设计问题

1. **前提的形态**（参考 M20/M35/P26/P27/P32 的既有模式，仓库里已有先例）：
   - 给 pty 段加**可见前提**：忙（`loadavg_1m > k × 逻辑核`）→ **可见 SKIP**（带原因与读数），
     而不是让它们去撞一个有界的等待预算然后红；
   - 或者：**提高等待预算**（但必须有实测依据：给出"多少 load 以下、多长的预算够用"的数据）；
   - 或者两者结合（前提用来 SKIP，预算用来兜住偶发慢）。
   **给出取舍**（含"宁可 SKIP 也不假红"与"不许把真回归也 SKIP 掉"的平衡）。
2. **系数 k 的来源**：不能拍脑袋——给**实测表**（load 2 / 5 / 11 / 20 各跑同一段，记录耗时与成败），
   从交叉点推出 k（与 27-d 的 0.75、panel-cpu 的 0.25 同一方法）。
3. **不许把回归藏进 SKIP**：反向夹具——把视图的滚轮消费去掉（真回归），**在安静机上必须红**；
   忙机上的 SKIP 也要**可见**（不静默）。
4. **FAST/全量的分工**：慢 pty 段只在全量跑（P32 已把三场景接进 38-f），FAST 里是可见 SKIP —— 保持。
5. **不许改 D33 的口径**：正确性门禁里不引入任何**墙钟阈值断言**；本 change 只处理"等待预算 vs 机器忙"。

## 硬要求

- policy B：delta 落 `verification`（门禁前提的通用规则）与 `panel`（pty 段自身的前提），
  每条可证伪；MODIFIED 不删 base scenario（`panel` 的既有 scenario 很多，**逐条核对**）；
- 每条 requirement 给复核方法；
- **不写实现**；现实与上文冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/pty-fixture-load-premise/{proposal.md,design.md,tasks.md}`
- `openspec/changes/pty-fixture-load-premise/specs/{verification,panel}/spec.md`
- 报告 `docs/team/reports/P44-dev3.md`

## 硬要求（新增 · 09:12 事故后追加，必读）

你在做负载实验时跑过一个"blackout 脚本"，按命令行模式 `panel.js.*--root /tmp/panel-p21`
**给进程发 SIGSTOP**；09:12–09:14 之间它可能冻结了 **P42 复验夹具**（pid 1427784、`/tmp/p42-mut`）的 panel。
**这不可以**（PM 裁定），提案必须把它写成规矩：

1. **只对自己 spawn 的进程发信号**：实验脚本在启动子进程时**记录 PID**，之后只对**这些 PID**发 SIGSTOP/SIGCONT/SIGKILL；
   **禁止**按命令行/名字模式匹配去信号别人（模式的边界永远说不清，实际也确实打到了别人的夹具）；
2. **SIGSTOP 必须与 CONT 配对**：脚本用 `trap '... SIGCONT ...' EXIT INT TERM` 兜底，
   绝不许留下 STOPPED 的进程（今天 PM 全机扫了一遍才确认没有残留）；
3. **实验用私有身份/私有路径**（自己的临时根 + 自己的 socket/端口），与其他席位并存；
4. 若确实要制造整机负载：用**可回收的资源**（例如 `stress-ng`/自旋进程，自己拥有它们）而不是冻结别人的进程；
5. 提案里要有一条**可证伪的要求**："负载实验不得影响未由它启动的进程"（红侧：脚本尝试对不属于自己的 PID 发信号 → 拒绝/红）。
