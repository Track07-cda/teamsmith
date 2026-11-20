---
id: P486
title: 让两份提醒测试用现有临时目录管理
agent: dev-bob
category: code
phase: opsx-apply
change: reminder-test-temp-root-ownership
specs: verification
deltas: -
branch: task/P486-reminder-test-temp-roots-apply
---

# P486 · 只实施已独立接受的方向

读本人线程、OWNERSHIP、`docs/team/reviews/reminder-test-temp-root-ownership-proposal.md` 的 ACCEPTED 记录、P485/V184 报告及 `openspec/changes/reminder-test-temp-root-ownership/` 当前 OpenSpec apply 上下文和工件。按任务 1.1–1.2 实施。任务 2.x 由非作者一次验证，不得代跑或勾上；保留返修回执中的停止顺序和验收边界。

允许写 `skills/teamsmith/tests/remind-tool-real.{sh,mjs}`、`remind-adversarial-real.sh`、`remind-adversarial-faults.{sh,mjs}` 共五个测试文件，和自己的报告；提交静态证据后只勾本 change `tasks.md` 的 1.x。复用现有目录管理、PID 与私有终端工具，保留原有参数、退出结果、指纹检查及主动保留的证据路径。既有恢复入口、smoke、共用工具、提醒产品与正式规格不动。禁止引入进程组信号、扫描、通用监督器、测试框架或额外开关。若见现有接口不能满足已批准方案，留具体反例并回 PM，不自行扩大文件或修改规格。

作者检查仅受影响 shell 的 `bash -n`、两份 `.mjs` 的 `node --check`、写集、`git diff --check`；按现有工具核对 apply 进度。不运行 2.x 行为样本、真实 Pi、故障矩阵、整套、现场提醒或模型。分步本地提交；在 `docs/team/reports/P486-dev-bob.md` 写改动、实际命令/退出码、未运行范围及精确候选 commit，不推送、不发布。完成后停止修改，交非作者独立验收。

V185 首轮 `bc51f1ba`：`f7db9e77` 五项四过，2.3 FAIL。仅修真实 Pi 中断清理：`tmux kill-server` 返回时，pane 内已启动的 Pi 尚可执行退出回调，实测由此重建了刚删的工作目录。只能在本次私有 Pi 确认退出后回收本次工作目录；沿用现有私有进程身份及精确 socket，只停本轮，不使用固定等待、按进程名查杀或进程组信号，不改产品退出回调。若不能证明退出，不把目录当已安全回收。修复仅限 `remind-tool-real.{sh,mjs}` 两个文件与作者报告，只做原静态检查、不运行行为；保留正常退出码及显式证据路径，不改其余已通过的入口、场景或检查。候选交回原验证者补跑 2.3，另外四项原件直接复用。

第二轮 `8a7a5567` 确认启动回执指向实际 Pi，但等待逻辑调用的共用读取函数用 `$20`，读成父进程号加 `0`，父进程变更时误以为 Pi 已退出。项目同类检查还在 `tests/tmp-hygiene.sh` 的 `_proc_start` 找到同一个错误。续修只许可更正 `tests/lib/tmp-root.sh` 与 `tests/tmp-hygiene.sh` 的这两处返回值为实际第 20 个位置参数（内核启动刻度），以及更新本人报告；保持 `f18c60e4` 的退出顺序、测试及其它源码不变。不新建读取函数、迁移旧记录、改清理判据、扫旧目录或动实际项目。只做两文件语法、写集与 diff。涉及新建目录归属记录、记录的子进程及清理工具状态显示，独立者以一个现有进程的真实启动刻度做一次短对照，加原失败 2.3 测试；不重跑其它四项和整套，不执行真实清扫。