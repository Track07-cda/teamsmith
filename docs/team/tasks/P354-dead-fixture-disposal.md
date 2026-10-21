# P354 · 按普查结果处置：删 11 个死夹具、5 个改成有记录的「人工验收工具」

task: P354
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具处置
deltas: -
branch: task/P354-dead-fixture-disposal
deps: 只动 `tests/` 下的夹具与文档；不碰 `smoke.sh` / `section-paths.tsv`（P346 的写集）

## 依据（你自己的普查，`docs/team/reports/P353-dev3.md`）

18 个顶尖夹具 + 1 个 lib 入口无执行路径，其中 13 个守着点名过的事故。

## PM 的裁定

**一 · 删掉（11 个）**——理由逐条按你表里的：

- 7 个 `merge-base` 形状的翻转（`flip-m4.3.sh`、`flip-m43.sh`、`flip-m45.sh`、`flip-m46.sh`、`flip-m7.2.sh`、`flip-p25.sh`、`flip-p71.sh`）：**修复进 main 之后它们在结构上就拒绝自己**，留着只会让后来的人以为有证据。
- `flip-p72.sh`（行为每轮由 §47 跑）、`flip-p171.sh`（形状已有正向对照；**删它时要一并改掉 `signal-gate.sh` 里指向它的那几处注释**，否则会留下假指针）、`flip-p287-lock.sh`（§34d 每轮跑）、`panel-flip-m54.sh`（要重建 bundle，而逐字节比对已在守）、`panel-keyprobe.sh` + `panel-keyprobe-stub.sh`（唯一守「刷新期间敲键不丢」的东西；`panel-b3` 接进门禁后会覆盖这一面——把这句话写进墓碑表）。

**二 · 保留但不接，并在文档里标明「人工验收工具」（5 个）**：`flip-m33.sh`、`flip-m44.sh`、`flip-p308-skip-not-pass.sh`、`section-needs-audit.sh`、`lib/tmp-root.sh --self-test`。给它们一个统一的说明位置（例如 `skills/teamsmith/tests/README` 或 `references/` 里已有的排障文档一节），写清：**它们不在任何门禁段里，是发布前或排障时人工跑的**，以及各自守什么。

## 必须交的

1. **墓碑表**：被删的每一个 → 守什么（点名事故） → 今天由谁守（段号或「面板 pty 面将由 P349 覆盖」） → 删在哪个提交。写进报告，并**同时**追加到 `docs/team/DECISIONS.md` 一条（一段话汇总，不逐条堆）。
2. **无假指针**：全树 `grep` 每个被删文件名，确认没有任何活文件（代码、注释、映射表、文档）还在指向它们；改掉的两处（`signal-gate.sh` 注释、`troubleshoot` 类文档）要贴改前改后。
3. **删完自检**：`section-select.sh --check`、`bash -n` 对所有保留的夹具、`--select 40`（管理 `tests/**` 的那一段）一次；贴读数。
4. 报告里给前后数字：`tests/*.sh` 从 64 个到多少个、总行数变化。

## 边界

不要删任何**有执行路径**的东西（你表 §1.2 那 46 个一个都不许动）；不改产品；不新增夹具/守卫。若删的过程中发现某个被删文件其实**被某个有根的夹具调用**（你的普查漏了），停下来报我，不要删。
