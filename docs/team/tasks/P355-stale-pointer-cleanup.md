# P355 · 收尾：9 行指向已删夹具的假指针

task: P355
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 注释指针
deltas: -
branch: task/P355-stale-pointers

## 依据（V89 的 §5，`docs/team/reports/V89-dev.md`）

P354 删掉 13 个死夹具后，10 行注释仍以「证据见 `tests/X.sh`」的口气指向它们。V89 判其中 **9 行必须改**，第 10 行只是过时的变异名。

已核实的行号（V89 核过、PM 又 grep 过一遍）：

- `skills/teamsmith/tests/smoke.sh`：6095、6135（`flip-m7.2`）、9295（`flip-m46`）、9306（`flip-p25`）、9330（`flip-p71`）、9385（`flip-m43`）、12365（`panel-keyprobe`）、18892（`panel-flip-m54`）
- `skills/teamsmith/extension/team-inbox-watch.ts`：452（`flip-m46`，**这行保留、只把口气改对**，因为 `flip-m46` 已删而它引用的是注射锚点的形状）
- `skills/teamsmith/extension/team-inbox-watch.ts`：599（`flip-p25`，V89 判它只是过时的变异名，行为仍由 `§12b-pi` S18–S21 守着）

**其中一处不只是死指针、是自相矛盾**：`smoke.sh:12365` 写着「真进程部分由 `tests/panel-keyprobe.sh` 覆盖」，而 `tests/README.md` 新写的是「这条契约今天没有活守门人」。两句必须只剩一句真的——按事实写：**今天没有活守门人，面板 pty 面由 P349 接线后覆盖**。

## 要做的

1. 逐行改成与今天一致的口气：指向**活的**段号（例如「§12b-pi S18–S21」），或明确写「该夹具已退役（P354），这一面今天没有活守门人」。
2. 不要为了少写几个字把历史删掉——这些注释记录的是事故与判据，改的是**指向**，不是**历史**。
3. 全树 grep 13 个已删文件名，确认改完只剩「历史叙述」与这三类允许的命中（历史账本、明确标注退役的注释）。
4. 报告里给逐行的「原文 → 改后」，以及那条 grep 的最终读数。

## 边界

写集：`skills/teamsmith/tests/smoke.sh`（只这 8 行注释）、`skills/teamsmith/extension/team-inbox-watch.ts`（只这 2 行注释）、`docs/team/reports/P355-dev3.md`。**不改任何代码逻辑、不改断言、不碰 `section-paths.tsv`**。

跑：`bash -n` 两个文件、`--select 12b-pi` 一次（约几分钟，确认注释改动没碰到脚本结构）、账本禁令、`git diff --check`。
