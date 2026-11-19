---
id: V181
title: 独立验证只读检查不启动终端且真实回复页不受影响
agent: verify
category: verify
phase: opsx-verify
change: -
specs: panel#Key reply blocks are async demand reads and absent from machine exits
deltas: -
branch: task/V181-key-replies-readonly-tmux-verify
---

# V181 · 三组只读检查与一个真实终端场景

先读 AGENTS、本人线程、OWNERSHIP、P480 任务与交付报告。作者 dev3；候选 `00f184fac002e0b4b8bc2bc4c3f620690c40c65b`，PM 固定检出 `/var/tmp/p480-review-00f184fa.r77bEA`。保持该检出干净；专用临时根均在 `/var/tmp`。不走真实系统的 tmux 会话、回复、队列或模型。之前 V179 清理是单独事项：原件已保存，先确认无在飞运行，只删除线程授权的 `v179-verify.TnHL8G` 并回报实际结果。

候选统一执行一次 `bash skills/teamsmith/tests/key-replies-ui.sh --select blocks,machine,snapshots` 加一次 `bash skills/teamsmith/tests/key-replies-pty.sh --select pages`。确认所有原断言保留，原结果中的跳过或失败明列，不能记绿。验证三组各有初始化与读取过的真实独立项目，不启动、重启或清理空终端，不连共享 socket；私有位置的只读窗口查询可正常发生。唯一真实终端场景用原隔离路径，第 5 页重开后原回复可读。可在套件外用一个转发给真实 tmux、记录 argv 与 socket 环境的临时包装记录；防止测试请求落在真实 socket，但不改退出码或制造结果，不在产品/正式脚本加逻辑。回执记实际启动次数、传入目录、退出码与通过/失败数；时间只作为本次读数，不推断整套收益。固定源差异核对 `init` 指向私有项目、无新的覆盖或终端启动及 pages 断言未改。不为对比重跑旧版全组。

通过 `TEAM_GATES='bash /var/tmp/<你的根>/<定点脚本>' bash skills/teamsmith/scripts/team review P480 --dir /var/tmp/p480-review-00f184fa.r77bEA --branch 00f184fac002e0b4b8bc2bc4c3f620690c40c65b` 保存正式记录，允许原生工具写主检出 `docs/team/reviews/P480.md` 与 `P480-verify.log`，其它只读；不要重跑全量、路由旧检查、存储 FIFO 或其他真终端组。用后台作业运行实测；实际命令、输出和证据位置在 `docs/team/reports/V181-verify.md`，本地提交、不合并、不推送、不发布。正式记录、完整输出和现场证据保留至 PM 接受。候选已经通过；合并版固定 `3b44b960c7c64d861618427ee90a5ea333892acd`，PM 干净检出 `/var/tmp/p480-merged-3b44b960.Jc43uO`。用原生工具绑定该检出和 SHA，仅比对两版三个测试文件并做 `bash -n`，不重复行为。候选原生记录已由 PM 保存，私有运行目录继续保留。
