# P347 · 给 P342 那条豁免配一个常驻的证伪者（V83 的 F1）

task: P347
agent: dev-bob
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 一条判据的边界断言
deltas: -
branch: task/P347-pin-exemption-boundary
deps: P342 的候选 `5ab8a377`（本任务在它上面加）

## 问题（V83 判 PASS 时点出的唯一不阻塞项）

P342 给 `real_ledger_hits` 加了一条按路径前缀的豁免（`.pi/team/state/release-<名字>/`）。V83 实测：把豁免**放宽**成「路径里含 `release-` 就跳过」，**相关段照样全绿**——也就是说这个边界今天没有常驻断言钉住，日后有人放宽它，门禁不会响。

按这轮一直执行的规矩：**契约必须能红**。放宽一条隔离判据没有证伪者，就是半把门禁。

## 要做的（一处，很小）

给 `real_ledger_hits` 加一组**对合成根**的直接断言（不需要真门禁运行，快）：

- 造一个临时根，里面放：
  1. `.pi/team/state/release-scan.log`（同前缀的**文件**，带夹具标记）→ 必须**命中**；
  2. `.pi/team/state/nested/release-x/a.log`（嵌套目录，带标记）→ 必须**命中**；
  3. `.pi/team/state/release-030/a.log`（发布证据目录，带标记）→ 必须**不命中**；
  4. `.pi/team/state/plain.log`（真账本，带标记）→ 必须**命中**。
- 断言用函数返回值（`real_ledger_hits <pat> <root>`），不要靠整段门禁跑一遍。
- 放进哪一段：与 M9.8/M16 同一族（`--select 25,30` 能选到的那个段），别新开段。

**红侧**：把豁免放宽成「路径里含 `release-` 就跳过」→ 第 1、2 条断言必须**变红**（这正是 V83 造出过假阴的那种放宽）；还原必须绿。把豁免收窄成「必须正好是 release-030」→ 第 3 条仍绿但第 1、2 条仍命中（说明它没有变成特例硬编码）。

## 收口

`--select 25,30`（或你放进去的那一段）一次全绿，贴读数与 rc；`bash -n`、`section-select.sh --check`、账本禁令固定验收行、`git diff --check`。不跑整套。

## 边界

写集：`skills/teamsmith/tests/smoke.sh`（只有这组断言与它必要的临时根）、`docs/team/reports/P347-dev-bob.md`。不改豁免逻辑本身、不加门禁段、不新增夹具文件（用函数直接断言）。
