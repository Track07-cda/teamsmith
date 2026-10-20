# P322 · 探索行为为主的 CI，清掉重复嵌套而不丢必要覆盖

task: P322
agent: dev-bob
phase: explore
category: analysis
change: behavior-focused-ci
deltas: -
branch: task/P322-ci-scope-explore
deps: -

## 输入与本阶段边界

用户已授权同时修 npm 与 CI。先读 AGENTS.md、自己的线程、OWNERSHIP.md、skills/teamsmith/references/openspec.md，再按生成的 opsx-explore 工作流执行。这一 brief 仅探索，不实现、不写提案规格（propose 另单），只写 docs/team/reports/P322-dev-bob.md。不会实施自己后续提出的方案。

复用 .pi/team/state/release-030/public-ci.log、public-ci-job.json（仅主检出有这些文件，允许只读），及 docs/team/reviews/release-0.3.0.md。真实 CI 镜像59秒、测试3550秒后被60分钟取消；选段/账本自检1314秒、设置组合365秒、配置读写164秒。smoke.sh 选段36 的 p98_nest 与 checkout-shape-probe 嵌套调用已确认。不得把未量出的成本写成测量结论。

本轮重点是把必要行为的执行路径理顺，不是按行数或时间直接删测试。阅读 verification/spec.md 的 correctness/performance/CI/selector 要求，实际 CI workflow、ci/、smoke、section-select 与形状探针、设置入口。对照尚待合并且已独立验收的 task/P316-delete-load-sensitive-tests、task/P317-swallowed-errors-common，不能重新做同一工作。P318 原三文件清理暂缓，避免另开重叠瘦身线。

## 要回答的问题

用源码调用链说明22分钟自检里哪些重复执行真实产品路径、哪些确为选择器的必要行为；建议一种最小方案（普通 CI 的产品路径、只有相关源变更才跑的工具自检、手动/发布的完整入口如何诚实区分）。任何移出默认路径的必要覆盖都要点名留下的入口和实际触发方式；不能把挪到无人会跑的位置当作保留。

对安装后信号入口、身份泄漏、锁互斥/祖先排队、心跳泄漏、只读面建目录、跳过假绿这些已有事故，列清新方案仍由谁守。不要写新测试矩阵、调度平台、预算表、强制耗时阈值或新守卫。优先简化现有调用，不把60分钟改120分钟。性能只参考，P316 的视界/无进度防死等与产品参数语义不能删。

指出需改的现有 capability 要求及冲突（特别是每次完整门禁、性能旧阈值/负载SKIP、CI收集路径），让后续 propose 在唯一 OpenSpec 变更里更新，不创建平行规范。目录级路径匹配/选择器若是方案，必须解释改变选择器本身、安装代码以及公共 helper 时如何仍跑到应有检查；但本阶段不造新选择器。

## 成本与交付

先用现有日志和静态调用图，不跑全量/FAST/整套31变异，也不重新计时全部测试。只有现有证据无法分辨时才做一个小型有界实验，记录必要性；长命令后台挂起。提交报告（Conventional Commit + P322 + Agent: dev-bob），运行固定账本检查与 git diff --check 后冻结，通知 PM；报告给一个推荐方案及代价/待确认事实。后续由 PM 接受方向再给 propose brief。
