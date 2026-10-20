# P336 · 写信面夹具：把固定 sleep 换成状态等待（写集只有 panel-b2.sh 一个文件）

task: P336
agent: dev
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具的等待方式，不改产品行为
deltas: -
branch: task/P336-panel-b2-bounded-waits

## 为什么拆成这一件

`panel-b2.sh`（1236 行、11 个场景，守 V33/P20/P249 三次点名事故）今天不在任何门禁段里，接进门的活是 P327；但它慢（满地固定 `sleep`）是独立的成本问题，**写作集只在它自己身上**，所以先做这一半，P327 再来接线。

## 要做的

把固定 `sleep` 换成**既有**的有界等待：`skills/teamsmith/tests/lib/bounded-spin.sh` 或 `lib/pty-wait.sh`（先读两者契约，挑合适的；两个都不够就在报告里写清缺什么，**不许**新建第三个等待库）。

判据是「等到那件事为真、或到上界」，例如：等面板画出目标行、等草稿行出现、等编辑器返回、等私有 server 里那个窗口真的起来。

允许保留并要逐条说明理由的：
- 夹具 bootstrap 的占位进程（`-c 'sleep 600'` 那类）；
- 确实**没有可观测状态可等**的位置（例如只在等一个纯粹的节流间隔）——每一处保留在报告里写一句为什么等不到状态。

明令禁止：放宽断言、删场景、把上界设成分钟级来「稳过」、把 `sleep` 藏进循环绕过来。

## 必须交的证据

1. **一条不少**：改前改后 ①场景名集合 ②断言行集合 各做一次 `diff` 并贴结果；只允许「等待方式」的差异。
2. **耗时对照**：改前改后各跑一次全场景（私有磁盘 `TMPDIR`、私有 tmux server），贴两边实际用时（参考值，不作判据）。达不到明显改善就如实写，不许为上界或断言作弊。
3. **不稳定性的证据**：改后**连跑三次**全场景，三次都必须全绿；任何一次红都说明等待上界不够或判据不对，按真实原因调，不许加大 `sleep`。若你的环境里某场景本来就红（例如粘贴那条依赖桌面剪贴板），把它单独列出来并给出**你实际看到的**原因，不许用「环境问题」四个字带过。
4. **私有性**：确认全程只用私有 tmux server（`-L …`）与私有夹具项目；实验前后各打一次你自己调用者的默认 server，证明没被碰。
5. 轻量收口：`bash -n`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

跑之前先 `ps` 确认没有别人的 `smoke.sh` 在跑；结束时清掉自己建的现场（`TEAM_B2_KEEP=1` 时保留并点名）。

## 边界

- 写集：`skills/teamsmith/tests/panel-b2.sh`、`docs/team/reports/P336-dev.md`。**不碰 `smoke.sh` / `section-paths.tsv`**（那是 P327 的写集）。
- 不碰产品实现、不新增夹具/等待库/门禁段、不改任何时限与预算。
- 净零：这条只把「等时间」换成「等状态」，没有新增检查器；接线由 P327 负责。
