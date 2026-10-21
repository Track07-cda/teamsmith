# P353 · 普查：还有哪些夹具「写好了、没人跑」

task: P353
agent: dev3
phase: apply
category: analysis
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 只读普查
deltas: -
branch: task/P353-never-run-audit

## 为什么做这个

今晚已经遇到**两个**「写好了、不在任何门禁段里、坏了没人知道」的夹具：`tests/panel-b2.sh`（守 V33/P20/P249 三批事故，已接进 §38）和 `tests/panel-b3.sh`（不在任何段里、且**红了两个星期**，8 条全是夹具假设，正在修）。两次都是碰巧发现的。

所以把这件事一次查完：**还有多少个这样的夹具，各自守的是什么。**

## 要回答的

1. **清单**：`skills/teamsmith/tests/*.sh`（以及 `tests/lib/*.sh` 里可独立执行的）逐个判「今天有没有任何**执行路径**能跑到它」：
   - 被某个门禁段的正文调用（`smoke.sh` 里的 `bash …/xxx.sh`）；
   - 被 `.github/workflows/gates.yml` 调用；
   - 被另一个会被调用的夹具调用（要追到根）；
   - 被 `--select` 的映射表声明为某段的判定面（**这条不算执行**——`panel-b3` 就是「有归属但没人跑」）；
   - 被某个 `flip-*.sh` / `panel-flip-*.sh` 调用，而那个 flip 本身有没有人跑。
   给出一张表：文件名 / 有无执行路径 / 追到的根（段号或 workflow 步）/ 它在守什么（能点名事故就点名）。
2. **排序**：把「无执行路径」的那些按「守的东西有多贵」排序（点名过的事故 > 契约面 > 其他），并给出建议：接线 / 删掉 / 保留但不接（说明理由）。
3. **一件要单独确认**：`--select` 映射表里那些「有归属但没人跑」的行有多少（那种假象最难发现）。

## 边界

- **只读普查**：不改夹具、不改门禁、不改映射表。写集只有 `docs/team/reports/P353-dev3.md`。
- 可以跑夹具来确认它能跑（每个最多一次、别跑全套），但**不要**为了普查去跑门禁段。
- 结论先给一张表 + 一句话总结（`X 个夹具无执行路径，其中 Y 个守着点名过的事故`）。
