# V68 · 独立审阅锁等待提案，不实现、不跑门禁

task: V68
agent: verify
phase: verify
category: analysis
change: -
anchor: verification#The hard timeout covers the gate run, not the queue
deltas: -
branch: task/V68-waiter-proposal-review

## 问题与证据入口

P332提出用已有进度心跳替换已失去预算来源的等待上限投影。独立判断它是否真正解决“合法长跑让排队者失败”，而没有新增控制系统。审阅固定提交 `6be339045201` 的 `openspec/changes/gate-waiter-patience/` 四文件、`docs/team/reports/P332-dev3.md`；实现现状读本分支的 `scripts/lib/gate-lock.sh`、`tests/lib/section-guard.sh` 和 `scripts/lib/cmd-review.sh`（均在 `skills/teamsmith/` 下）。读取任务书P332和本席线程后开始。

PM尚未接受提案；不写apply brief。本任务只出审阅报告，不改提案、规格、产品或测试，不跑选段、全量、容器、探针或计时实验；使用已记录的现场与静态调用关系即可。无需新测试夹具。

## 必答四点（每个结论指向原文或调用关系）

1. 规则一致性：delta第一段仍写wait bounded by W，后面又允许4W；“无心跳时不声称心跳状态”与state=none提示的冲突；旧场景名讲remaining、正文却检验忽略remaining。给最小纠正，不要求新协议。
2. 从真实顶层/review子进程路径证明心跳确实可见；辨别mtime变化、ticks进度与仅进程活着。尤其审阅design §2.1所谓避免双红的论证：已等超过W后心跳转stalled，ceiling回落W仍会当轮失败，是否支持它的声称？若不支持，删除该声称还是必须改行为，写明依据。
3. 用所有活登记中的最新心跳，是否限定为当前锁的实际持有运行？已有身份/登记关联足够就引用，不凭空加另一套认证或监测。公开holder不存在心跳与子登记有心跳这两种形状如何复用原有读取。
4. 验证计划减法：tasks的[7,10]秒、“2秒左右”、每条破坏再重复三条反向与定点后FAST全量，是不是不必要重复。保留时间作为产品语义的精确验证，但不恢复负载敏感墙钟带；优先现有函数输入/可控时间或既有测试协议，不引入通用时钟框架。提出最小必要入口与一到两个关键反例，未改部分复用既成证据，整体只在合并/发布最终跑一次。明确每项裁剪没有失去哪条必要行为。

## 交付

`docs/team/reports/V68-verify.md`，先给PASS/PARTIAL/FAIL及是否可实现，再列阻塞项与最小改法；没有证据的担心不列。报告标明静态审阅，没有实跑就不报测试通过。按账本禁令检查后提交（Agent: verify），通知PM，local模式不push。PM接回裁定后才允许实现；没有新增守卫净零配额或场景逐一翻转配额。
