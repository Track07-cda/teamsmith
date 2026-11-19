---
id: P480
title: 删除关键回复只读检查中三次无用终端启动
agent: dev3
category: code
phase: opsx-apply
change: -
specs: panel#Key reply blocks are async demand reads and absent from machine exits
deltas: -
branch: task/P480-key-replies-readonly-tmux-dedup
---

# P480 · 只去掉只读检查的空终端

先读 AGENTS、本人线程、OWNERSHIP、P477 报告，检查 `skills/teamsmith/tests/{key-replies-ui.sh,key-replies-pty.sh,lib/reply-fixture.sh}`。只允许改这三个测试文件和本人报告：把既有项目准备、种子发布和记录参数，与空终端的启动分开。只读的 blocks/machine/snapshots 不启动 bootstrap 窗格，不再为这三组重启私有会话；原三个独立项目、真实 CLI、真实视图及全部原断言保留。确认未创建窗口时只读路径不操作当前/其他项目或落到共享 tmux；保持项目身份与私有运行环境。真实终端的九组仍用原私有隔离、起停和等待，不合并数据，不改路由旧场景或工具前置，不加通用选项，尽量用简单的调用边界。若不能不启动就拿到原应有的数据，不引入新的替身或绕过，带证据返回。

作者只做 `bash -n` 对受影响脚本、`git diff --check`，本地提交并交 `docs/team/reports/P480-dev3.md`。非作者独立只跑一次 `key-replies-ui.sh --select blocks,machine,snapshots` 加一次 `key-replies-pty.sh --select pages`，核全部原有断言和不启动空终端，并核真实第 5 页跨重启可读。无会话启动证据在私有测试环境外部收集，不往产品或正式检查加永久逻辑。历史 §63 的条数/耗时只作参考，若需旧版启动日志用短样本，不重复整组。长作业走后台，不测试 FIFO、设置、全量或真实团队；不推送或发布。
