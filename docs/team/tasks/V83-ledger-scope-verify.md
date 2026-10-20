# V83 · P342 的独立验收：把取样范围收窄，而没有把判据关掉

task: V83
agent: verify
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 一条隔离判据的取样范围
deltas: -
branch: task/V83-ledger-scope-verify

## 受检

候选 `5ab8a377`（`smoke.sh` +18/−2），报告 `docs/team/reports/P342-dev-bob.md`。它给 `real_ledger_hits` 加了一条**按路径前缀**的豁免：`<root>/.pi/team/state/release-<名字>/` 下的文件不再算「账本」，因为那里是发布证据（日志内容必然带夹具标记）。

这是**放宽**一条隔离判据，所以独立验收的重点不是「红了没有」，而是**它还剩多少牙**。

## 要回答的四件事

1. **豁免的前缀边界是否严密**：读那段 awk，确认 `release-<名字>/` 必须后面还有路径分量才算豁免；验证这几种都**仍算账本**（必须被点名）：`.pi/team/state/release-scan.log`（同前缀的**文件**）、`.pi/team/state/nested/release-x/a.log`（嵌套目录）、`docs/team/inbox/release-x/a.log`（账本目录下的同名目录）。各造一个带夹具标记的探针文件，跑 M9.8/M16 所在段，确认**都红并逐个点名**。
2. **真的泄漏仍然抓得住**：往**真实状态目录**（非 release-*）放一个带标记的探针 → 必须红且只点名探针；release-030 里那两个既有文件 → 必须**不再**被点名。
3. **没有顺手削弱别的**：`real_ledger_hits` 另外三条豁免（`tmux-calls.log`、`.forensics`、`bg/`）逐字未变；扫描的两个根（`docs/team/inbox`、`.pi/team/state`）未变。
4. **残余风险如实**：报告点名了「真有夹具往 `release-*/` 写就不再抓它」。确认这句写在代码注释与报告里，并给出你的判断：这个残余是否可接受（可接受的依据是什么）。

## 红侧与收口

- 红侧：把豁免放宽成「路径里含 `release-` 就跳过」→ 第 1 条里那几个「仍算账本」的探针必须**变成不红**（证明你的探针有判别力），还原后必须回到红。
- 跑一次 `--select 25,30`（两条隔离断言所在段）与 `--select 12b,25,26,30`（扫描器的四个消费者），贴读数与 rc。**不要跑整套**（作者已经跑过，且它在 §61b 挂住上限）。
- 轻量收口：`bash -n`、账本禁令固定验收行、`git diff --check`。

## 边界

只读代码、只在 `/var/tmp` 私有副本与我给的探针里造破坏、只写 `docs/team/reports/V83-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL。local 模式。
