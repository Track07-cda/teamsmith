---
id: V180
title: 独立验证复验准备、真实排队和报告结果
agent: dev-bob
category: verify
phase: opsx-verify
change: -
specs: verification#The hard timeout covers the gate run, not the queue
deltas: -
branch: task/V180-review-queue-report-verify
---

# V180 · 用几个短命令确认复验报告不再猜测

读 AGENTS、本人线程、OWNERSHIP、P478 任务/报告及 P476 已接受的原日志归因。实现者 dev2。候选固定 `c97a8efef4b8141d95b86d9a8ff62654ea02f0a3`，PM 准备干净的 `/var/tmp/p478-review-c97a8efe.BTOmDp`；旧版 `36c60698`。不在固定检出造项目或写状态；自行只在 `/var/tmp` 专属根准备测试项目、有效临时根和私有锁，保留命令、退出码、运行标记、正式报告和日志。不要让被测 review 同中央验证竞争同一锁，也不要写真实项目历史。

- 有效目录下运行带可见标记的短命令，分别退出 0 和 1；报告应为 PASS 和 FAIL、计入运行时间、没有排队超限，日志保留实际输出。
- 不存在的显式临时目录（原例使用 `TMPDIR`；该分支要让独立 `TEAM_SMOKE_LOCK` 指向有效可写路径，排除锁路径无法建立的降级）：旧版用同等隔离条件确实执行标记却写排队超限；候选明确报路径/准备失败和可操作修法，退出非零、不创建目录、不持锁或运行、不改原记录/日志（比较字节或 SHA）。保留真假两份证据，不重跑 26 项剪贴板检查，不改旧记录。
- 复用 §34② 的私有外部持锁短样本，核实际达到小等待上限、报告点名持有人、FAIL 与未运行，不能报硬超时；复用 §34③ 的短硬超时，核命令实际开始、报告 TIMEOUT 且记录运行时长，不能报排队超限。不跑 §34 整段或全量；其他锁路径只审实际 diff。
- 正式候选执行用 `TEAM_GATES='bash /var/tmp/<你的目录>/<定点脚本>' bash skills/teamsmith/scripts/team review P478 --dir /var/tmp/p478-review-c97a8efe.BTOmDp --branch c97a8efef4b8141d95b86d9a8ff62654ea02f0a3`。中央只许原生工具写 `docs/team/reviews/P478.md` 和 `P478-verify.log`；独立报告 `docs/team/reports/V180-dev-bob.md` 本地提交，列实际覆盖和未验项。不重跑长测试、不推送、不合并、不发布；作业需要较长则后台运行并回合结束。新证据不覆盖同批其他记录，保留至 PM 接收。
- 候选通过并收到合并版后只比对产品字节并做一条短失败命令，核记录仍为已执行，不重复整批。
