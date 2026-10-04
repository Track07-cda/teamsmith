# M57 · 性能测试从全量门禁里拆出来（propose）

```
task:   M57
agent:  dev-bob
issue:
change: perf-suite-split
specs:  -
phase:  propose
anchor: change
deltas: panel, verification
deps:   -
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md）
```

> 本地模式：不 push。**只 propose**，不写实现。

## 用户决定（2026-09-21，D33，取代 M57 原方案）

> 「**性能相关测试不要放在全量测试里，单独做一个性能的测试，全量测试只测正确性。**」

这条决定了本 change 的形状：不是"把性能判定搬进配额容器"（那是我原来的方案），而是**先做职责分离**——
**全量门禁 = 只判正确性**（不得含任何墙钟红线），**性能 = 独立的一套**，可单独运行、自带环境自述。

## 现状（PM 实测，你要复核）

- 全量套件 **2096 条断言**里，真正的**墙钟红线只有 3 条**：27-d 帧装配中位 2000ms、`panel-cpu.sh` 的交互首帧 2000ms、
  以及稳态 CPU **≤1% 单核**（这条是 **CPU 时间 user+sys**，几乎不受负载影响）；
- 这三条由 `tests/panel-cpu.sh` / `tests/panel-cpu-premise.sh`（以及 smoke 里的 27-d 段）承载，
  **它们同时混着正确性断言**（必须保留，见 R3）：
  - `d-realpath` 系列：**夹具旋钮不得漏进真路径**（我称之为"反后门控制"）；
  - 27-d 的**异步性**：刷新进行中按键不丢、坏块渲染 `—` 而不炸帧 —— 这些是**正确性**，不是性能；
  - `gate-hygiene`（已归档）的 `ran/queued` 记账、`panel-cpu` 缺 `/usr/bin/time` → **可见 SKIP(exit 4)** —— 也是正确性/可观测性。
- 今天的实测证据（说明"墙钟红线"为什么必须与正确性门禁分开）：
  宿主安静时首帧中位 **1818ms / 1963ms**（红线 2000ms，**贴着线**），load 11 时 **3467/never/3517ms**；
  同一棵树在钉死容器里 **✓18/0 全绿**。→ 同一份代码，红绿由"谁在抢 CPU"决定。

## 要提案化的内容（每条 requirement + 可证伪 scenario）

1. **R1 · 全量门禁只判正确性**：`tests/smoke.sh`（全量门禁）**不得包含任何墙钟性能红线**——
   即它跑完后，**性能变慢不能让它变红**。**可证伪判据**：人为注入一个"慢但正确"的装配延迟（夹具旋钮），
   全量门禁**必须仍然全绿**（当前行为相反：那条延迟会判红）。
2. **R2 · 性能独立成一套，一条命令可跑**：新增独立入口（例如 `tests/perf.sh` 或 `team perf`，名字由 design 定），
   内容至少覆盖：交互首帧、帧装配线、稳态 CPU；**输出必须自带环境自述**（宿主/容器 · CPU 配额 · 可见核数 · loadavg），
   并支持"本机跑一次"与"容器里跑一次"两种用法（容器用同一个 `ci/Containerfile` 镜像）。
   **可证伪判据**：性能套件在明显慢的机器上给出**判红或可见 SKIP**（不许静默通过），且打印它判定的依据数值。
3. **R3 · 拆分不得丢掉正确性覆盖**（本 change 最容易做错的地方）：
   - `d-realpath` 的"旋钮不得漏进真路径"、premise 行只反映真读数 → **留在全量门禁**（或等价改写为不依赖时间的断言）；
   - 27-d 的**异步性**（刷新中按键不丢、坏块降级）→ **留在全量门禁**，只把**时间预算**搬走；
   - `gate-hygiene` 的排队记账、缺工具可见 SKIP → 语义不变。
   **可证伪判据**：删掉上述任一条正确性断言 → 全量门禁**红**（证明它们没被"一起搬走"变成没人测）。
4. **R4 · CI 的形态**：CI 里**正确性门禁与性能套件分开**（独立 step/job，各自独立结论与日志）；
   性能这套**不阻塞**代码合并（用户口径："全量测试只测正确性"），但必须在**发版前**跑一次并记录数值。
   design 要写清：什么时候跑（每次 push？手动？发版前？），失败怎么呈现（可见但不拦合并）。
5. **R5 · 文档与可发现性**：`SKILL.md`/`references/` 里讲清**两个门禁的分工**（正确性 = 每次；性能 = 单独/发版前），
   并给出两套的可复制命令；`team doctor`（或 digest）在性能套件缺席时给一句可执行的下一步。
6. **R6 · 红线数值与既有语义不动**：首帧 **2000ms**、稳态 **≤1% 单核**、装配 **2000ms** 一个都不改；
   `ran/queued` 排队记账、`exit 4` 可见跳过、CAS/写入路径全部保持。

## design 要顺带裁决

- 性能套件的**入口与命名**（`tests/perf.sh` / `team perf` / `make perf`），以及它与 `TEAM_SMOKE_*` 锁的关系
  （要不要自己的锁？还是只读、不抢锁？）；
- **默认环境**：默认在容器里跑还是宿主？（给出理由与实测数字：容器 4 核 vs 宿主 32 核的首帧对比）；
- 27-d / panel-cpu 的**搬迁方式**（移动 vs 复制后删）：必须保证"全量门禁里不再有 2000ms 判定"这条可机械检查
  （例如：全量门禁里不允许出现 `budget 2000` 一类字样 + 一条 grep 夹具）。

## Deliverables

- `openspec/changes/perf-suite-split/{proposal.md,design.md,tasks.md}`
- `.../specs/panel/spec.md`（MODIFIED：把"帧装配/首帧红线"的**判定位置与前提**讲清——它不再属于正确性门禁）、
  `.../specs/verification/spec.md`（ADDED：**两个门禁的分工**与性能套件的环境自述）
- 报告 `docs/team/reports/M57-dev-bob.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

- 只 propose：不改 `scripts/**`、`tests/**`、`extension/**`。
- **不放宽任何红线**；**不掩盖回归**（性能套件必须仍会判红或可见跳过）；
- 不动 `refuse` 类、写入路径、authz 语义。
