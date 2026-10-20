# P325 · 提案：实际减少 CI 的重复嵌套，统一性能参考口径

task: P325
agent: dev-bob
phase: propose
category: analysis
change: behavior-focused-ci
deltas: verification
branch: task/P325-ci-scope-proposal
deps: P322

## 输入及本阶段边界

用户授权「那都修」；P322 探索以 PM 的收敛方向接受，不采纳原方案A。先读自己的最新线程、AGENTS.md、OWNERSHIP.md、references/openspec.md，再按本项目生成的 opsx-propose 工作流工作。只写 openspec/changes/behavior-focused-ci/ 四类制品和 docs/team/reports/P325-dev-bob.md；不写实现、不改既有 capability 正文、不碰CI或测试。提案不由你自己实现。PM 收到提案后另做独立方案审阅，再决定 ACCEPTED；本阶段不能提前开 apply。

材料：docs/team/reports/P322-dev-bob.md、docs/team/reviews/P322.md（接受范围优先于探索中的未采纳选项）、verification/spec.md、当前 main 上的 P316/P317。P321 npm入口修复和 P324 keep/现场收集修复是另外两条既有契约修复；P324拥有工作流和 smoke 两个环境前缀，后续 apply 须等它冻结、合入再改相同文件，不复制它的工作。原始日志 .pi/team/state/release-030/public-ci.log 只在主检出，允许只读。

## 已接受的方向（将实际承诺落到 OpenSpec，不在报告另造规范）

优先减少 checkout-shape-probe 的29次嵌套及无关 needs 重跑，必要语义保留而不是保证每条旧断言原样留下。区分产品正确性与昂贵的工具组合自检：普通 CI 产品基线不能仅靠未证明完整的 changed-path 表裁剪；保留小型必要自检，重型组合只在相关源变更或明确完整入口运行。不要把同一22分钟成本搬到每次本地review就宣称完成减法。

比较后选一个最小、可实现的方案，不交三选一问卷。尽量复用选择器/现有入口；若确需类别或开关，只有一处归属声明，不在工作流再复制一张key表。不新建调度器、预算表、路径扫描平台、产品测试钩子、通用测试框架或新守卫。不能为此跳过既有 needs/隔离前导、用sed/eval抽正文另造一套选段执行器，或把真实交付的 gate-lock/tmp-root/tmux/signal边界误归为可省的工具自检。

必要事故行为点名现有或替代执行入口：身份泄漏、锁互斥/祖先排队、心跳退出、只读面不建目录、跳过不算通过、安装后信号入口。缩减的是重复执行，不是故意破坏后仍应检出的行为。对保留的控制明确它检出什么；合并/删除的控制说明接管者，不以断言多或少证明质量。

完整入口要能实际执行、诚实区分全量/选段/FAST；不能把明知当前会被一小时取消的命令当可用交付方案。GitHub一小时上限不提高，性能数值不作新门槛；是否实际完成必须在实现后的运行里证实，不先承诺48分钟。产品失败和现场收集不能被 continue-on-error 掩盖；性能独立只参考。同步既有性能旧阈值、负载SKIP、时间预算及不存在的发布文档引用，一个 verification delta 承接所有相关 MODIFIED 要求；保留没有过时的场景，不另留P316规格尾巴。

## 证据使用与验收准备

只用现有日志、静态调用链、已存在的选择器/检查器轻量入口；不重启探针、不跑FAST/全量/模型路由变异、不做新计时实验或造负载。

P322的3544秒仅是109/135段的截断求和，不能减去一项就当新全量耗时；1064秒是探针总时间，按总数缩放的分项不是独立证据。未声明路径落FULL是保守多跑，本身不是静默漏测；真正的问题是某些已声明范围可能过窄、运行成本和执行契约未被证明。outbox样例token不能只删声明而绕开现有字面映射检查。

在 design 中写清调用如何减少、覆盖如何接管、入口如何触发及需要改的最小文件集合；tasks引用 delta 场景，不造另一张规范矩阵。为实现安排定点反事实和最终一次固定环境整体验收，不要求每步全套。若整个方案必须继续叠新机制才能成立，明确删掉什么而不是加层兜底。

交付前实际运行 openspec validate --all --strict、spec-refs.sh --check、一次磁盘临时副本试归档及归档后validate、git diff --check、固定ledger-ban（名单从git common-dir上一层 .pi/team/forbidden-names.txt）。不安装/升级工具；命令不可用需具名 BLOCKED，不替造检查器。报告先给选定方案和实际制品/校验结果，短列未证实边界，不复制proposal/specs全文。提交含 P325 与 Agent: dev-bob，保持本地冻结、禁止push/发版/合并。
