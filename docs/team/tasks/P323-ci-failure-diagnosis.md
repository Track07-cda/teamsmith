# P323 · 定点诊断公开 CI 的回收失败和现场收集失败

task: P323
agent: verify
phase: explore
category: analysis
change: -
anchor: openspec/specs/verification/spec.md#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed
deltas: -
branch: task/P323-ci-failure-diagnosis
deps: -

## 任务与边界

用户已授权「都修」，本单先独立只读归因，后续另派实现者。先看 AGENTS.md、自己的最新线程和 OWNERSHIP.md。只写 docs/team/reports/P323-verify.md；不改产品、测试、CI 或规格。主检出的 .pi/team/state/release-030/public-ci.log 和 public-ci-job.json 可只读；不要读任何 credential、token、auth 文件，不重新触发远程CI。已有综合结论 docs/team/reviews/release-0.3.0.md。

## 两个具体现象

1. GitHub run 39354787618，产品 bf368ceb；第97段/键34c 一条“主人退场后根还在”，段落25通过1失败，原日志约5190行。34c 是运行指纹/临时根被删除的现场，不能仅根据名字断言产品回收有bug或只是负载。定位它的父进程退出、等待/清理判据与产品/夹具责任，判断 P316 已验收候选是否已触及原因。
2. 第110段执行中被60分钟上限取消之后，collect-scene 找到0个现场族（要求至少1），上传没执行；原日志约5863行。对照实际临时根、磁盘默认根、容器挂载/拷贝与扫描命名，解释现场是在何处丢失，而不是加静默豁免、取消最少1要求或新守卫。

## 方法与交付

先读原日志及源码，证据不足才一个最小、只动自有临时目录/进程的定点复演。不要重跑全量、FAST、31臂变异或发布检查；不造负载、不等安静机器。长命令用后台车道。可用 host podman 读镜像或起仅自己的小实验容器，但只经 distrobox-host-exec podman，不动别人的容器/路径。

报告先答两个原因的已知/未知，引用源码与日志，给最小修复位置与反事实（如何确认不是随意等久一点/放宽断言），明确可复用的已验收 P316 证据。若无法复现，交付已知边界，不无限重跑。按现有契约修复与需要改规格的部分分开，交给PM定执行范围；不自行创造新规范。固定账本禁令、git diff --check 后小提交（Agent: verify），冻结并通知 PM。
