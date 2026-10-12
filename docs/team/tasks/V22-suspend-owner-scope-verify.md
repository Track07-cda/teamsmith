# V22 · P236（挂起按归属判定）独立复验

task: V22
agent: verify
phase: verify
category: verify
change: long-job-suspend
specs: notify-and-inbox
deltas: -
branch: task/V22-suspend-owner-scope-verify
deps: P236（apply 已交付，冻结 tip 见任务消息）

## 复验对象

P236：`team-notify.ts` 的挂起判定改为**按作业归属**（`.job` 记录的 `cwd` 必须解析到本会话自己的工作树/cwd；缺 `cwd`、相对路径、解析失败一律 fail-closed 不判挂起）。被检树：`pm-skills-ledger/team/reviews/V22/checkout`（独立 clone，detached 在交付 tip）。

## 必须自己做的

1. **真实缺陷形状复现**：构造两个会话（各自工作树、一个 `.job` 归 A），确认 **B 的回合结束通知里不出现** `awaiting=` / `[auto·suspended]`；再让 A 结束回合，确认 A **出现** `awaiting=<id>`。反例两类都要，不能只跑作者夹具（作者的夹具是单会话）。
2. **fail-closed 反例**：`cwd` 缺失、写成相对路径、软链工作树（记录里的路径与真实路径不同解析）、路径已被删除——四种都必须**不判挂起**，且不报假 `awaiting=`。
3. **不许回退 A 刀**：`start`/`wait` 两类账本行、`[auto·suspended]` 与 `awaiting=` 的语义、`uncommitted=` 保留、完成/未完成两条分支，逐条跑一遍（`bg-ledger.sh --select wording,ledger,suspend-shape`）。
4. **红侧**：在 scratch 副本里把归属判据删掉（退回「项目里有活作业即算」）→ 用例 1 必须红；还原后绿。
5. **不越界**：`git diff` 确认只碰 `extension/team-notify.ts`、测试与门禁登记；容器内 FAST 一次确认无新红。

## 交付

`docs/team/reviews/V22.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外 `pm-skills-ledger/team/reports/V22-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
