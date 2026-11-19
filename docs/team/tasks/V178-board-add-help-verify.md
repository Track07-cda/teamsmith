---
id: V178
title: 独立验证看板新增帮助与实际命令一致
agent: dev-bob
category: verify
phase: opsx-verify
change: -
specs: help-surface#Every behaviour a help page states is declared and probed
deltas: -
branch: task/V178-board-add-help-verify
---

# V178 · 只验证 P475 的一条帮助

实现者 dev2，候选 `f4a4395544c39c848176560b31640ade212709c1`，PM 准备的只读独立检出 `/var/tmp/p475-review-f4a43955.YMSPRi`；候选改前 `2ac59d49`。先读 AGENTS、本人线程、OWNERSHIP、P475 任务书和交付报告、锚定需求。不要改候选、主检出产品、真实项目看板或正在运行的 Pulse。

1. 检查候选 SHA 和 clean 状态、确认产品 diff 只改 `commands.tsv` board 行。用候选 CLI `team board --help` 实际渲染英文默认和中文 `TEAM_LANG=zh`（先确认本项目实际值），两处均看到 `board add <ID> <title> [agent] [deps] [--allow-dup]`，其余 board 用法不变。用改前 CLI 实际输出跑相同的标题断言，应因为确实缺 `<title>` 而失败；不接受启动/依赖错误作为反例。
2. 在你用 `mktemp -d -p /var/tmp` 创建的独立临时项目内，使用候选 CLI 按该用法新增唯一测试行并读取该行，核对标题/负责人/依赖。不得调用真实项目写命令，不需要模型，不跑整组帮助或全量。临时检查脚本只写在本人隔离目录，不入库、不另起持久框架。
3. 用 `TEAM_GATES='bash /var/tmp/<你的证据根>/<定点检查脚本>' bash skills/teamsmith/scripts/team review P475 --dir /var/tmp/p475-review-f4a43955.YMSPRi --branch f4a4395544c39c848176560b31640ade212709c1` 写实际执行记录，行为集中运行一次；如果其中不便在同一次脚本读取改前树，可在脚本先创建只读改前快照。中央只允许该 review 写 `docs/team/reviews/P475.md` / `P475-verify.log`，其它主检出只读。本人报告 `docs/team/reports/V178-dev-bob.md` 列实际输出、exit、测到/未测边界、证据路径，`git diff --check` 后本地提交（V178 / Agent: dev-bob）；保留证据至 PM 接收。
4. 如 PM 合并，原验证者只在新独立检出核对产品文件同一、再呈现一次修正后的英文用法，不重复旧版反例、中文及新增记录。未获 PM 通知不自行合并或复跑。网络/工具环境断点明确报告，长作业用后台，不推送、不发布。
