# P324 · 修复 keep 模式回收探针与失败现场的实际收集路径

task: P324
agent: dev2
phase: apply
category: code
change: -
specs: verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed
deltas: -
branch: task/P324-ci-scene-and-reclaim-repair
deps: P323

## 已知原因与输入

用户授权同时修复 npm/CI。先读 AGENTS.md、自己的最新线程、OWNERSHIP.md、本任务。P323 已在独立工作树上归因（报告 `docs/team/reports/P323-verify.md`，未入主分支时可用 `git show task/P323-ci-failure-diagnosis:docs/team/reports/P323-verify.md` 读）：CI 的 --keep 导出 TEAM_TMP_KEEP，34c 退出回收探针却继承了保留开关，产品正确保留而夹具错误判红；收集器仍拷 /tmp 并匹配旧平铺根，实际现场已在磁盘根下且带 ns。

只按这些已存在的契约修，不新增失败现场的规格承诺、不制定 CI 分层策略。P322 正在为 CI 默认范围写独立 OpenSpec 方案；本单不移出任何测试、不提高 job 时限。实现前等 PM 合入 P316 后，从当时 main 新切分支；不得自己合并 P316。

## 唯一写入范围

本单临时拥有 `.github/workflows/gates.yml`、`ci/collect-scene.sh` 以及 `skills/teamsmith/tests/smoke.sh` 中 p287c_run 与 p287n_root_live 的环境前缀。报告只写 `docs/team/reports/P324-dev2.md`。不要改其它 smoke 段、公共 helper、产品、规格、版本、npm、CI 触发条件/60分钟时限、--min-families 阈值、上传成功条件。不新建 suite/守卫/选择器/自修复器。

## 最小实现方向

- 回收探针和对应嵌套运行清掉外层保留开关（TEAM_TMP_KEEP、TEAM_SMOKE_KEEP）；外层 --keep 继续保留自己现场，不跳过回收断言，不拉长等待，不改变产品保留契约。
- 让 gate 与 collector 使用同一个显式的磁盘临时根：可在 workflow 定义一个值，传给容器 TMPDIR 并在调用 gate 前创建；collector 通过一个明确源参数接收同一值，拷该根内容，不重新计算 ns。既有 --stage 入口继续可用。不要新增根路径标记协议、取消后 exec 容器、遍历宿主 /var/tmp 或拷整个容器。只在本次自有容器里操作。
- 更新现场族名到当前带 ns 的形式，并在实际临时根这一层收集。打包仍只带现场族、不跟随软链；锁文件不得算成现场。help/注释相应改正，不保留死的路径假设或无用途的兼容分支。

## 验证（仅定点）

先用实际命令 `bash skills/teamsmith/tests/smoke.sh --select 34c --keep`，再用同入口验证非 keep 路径；树冻结、私有磁盘 TMPDIR、私有锁，不在主检出跑。使用原有 tmp-root 回收翻转证明必要行为仍会红，原样还原并报告字节一致，不新加产品测试钩子。

复用现有固定镜像在自己一次性容器中跑这个选段（不重建镜像、不跑全量），用 workflow 相同 TMPDIR 设置。选段通过后故意让容器非零退出，真实 collector 从停止容器收集；查看生成 tgz 确认有具名实际现场文件，而不只是目录/锁，软链不会被跟随。用同一小现场改回旧路径/旧前缀应重现收集失败；空现场和只有锁仍非零，不能只改脚本返回绿。没有镜像才 BLOCKED，交给PM，不擅自建全栈。

Podman 只经 `distrobox-host-exec podman`，不信号/停止他人容器，所有输入/副本使用 /var/tmp 自有目录。测试复制/替身只在 tests/ 或一次性临时目录，不进入 ci 产品代码。长运行走后台车道；不重跑 FAST、31臂变异或发布套件。

小步提交、Agent: dev2；报告先给两处行为实际结果与原始命令/日志位置，再写边界。交付前 bash -n 受影响 shell、git diff --check、固定账本禁令；本地交付冻结，禁止 push/发版/合并。独立复核者不能是你。
