---
id: P484
title: 查清两份提醒测试的临时目录及证据保留方式
agent: dev
category: analysis
phase: opsx-explore
change: -
specs: verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed
deltas: -
branch: task/P484-reminder-test-temp-roots-explore
---

# P484 · 顺序第三项：只查两份提醒测试如何使用现有临时根

承接 `docs/team/reports/V160-dev3.md` 关于 `remind-tool-real.mjs` 与 `remind-adversarial-faults.mjs` 的后续项；不要重做 P453。先核当前源码而非复述旧报告：前者目前在 `P442_EVIDENCE`（默认专名目录）下建 `run-`，后者直接建 `/var/tmp/p444-remind-faults-*`。沿四个现有测试入口核调用、默认和显式证据目录、各自成功/失败退出的存留行为，以及能否直接复用 `tests/lib/tmp-root.sh` 和其现行清理方式。提出一个最小方案，区分应该自动清理的运行文件与必须保留的显式证据，保留已有调试和验收方式；说明哪些入口和行为需验证、是否存在直接调用 `.mjs` 的实际使用。不给正式产品加逻辑，不新增清理机制、命名豁免或静态检查，不批量清理历史目录。只读源码和旧报告；不运行提醒、真实 Pi、长检查、临时目录扫描或版本安装。不在本阶段改实现、正式规格或测试。

唯一已授权的现场清理：你拥有以前的 `/var/tmp/P474-dev-static.PKFsT1`。依原线程及 `docs/team/reviews/V179.md`，PM 已封存记录。只在核对 `.pi/team/state/evidence/P474/P474-dev-raw.sha256`、路径形态且确认无相关后台作业或进程占用后，清这一个具体的本人路径（已没有则记录；不能确认则保留并报告）；不得清其他旧目录、检出或归档。此处不拷贝、删除证据包，不测试或更改实际队列。

本地提交 `docs/team/reports/P484-dev.md`，先回答清理结果及建议，给出现有和拟用路径/退出分支证据、最小独立验收、实际命令与未执行范围；只跑报告差异检查，不推送。