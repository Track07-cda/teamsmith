# V66 · 独立复核 keep 回收探针与真实容器现场收集

task: V66
agent: dev
phase: verify
category: verify
change: -
specs: verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed
deltas: -
branch: task/V66-ci-scene-review
deps: P324

## 输入与边界

先读 AGENTS.md、自己的最新线程、本任务和 OWNERSHIP。只读复核 P324，不验证自己实现的 P316。P324 冻结提交 `7e548ce129d0`，分支 `task/P324-ci-scene-and-reclaim-repair`，报告该提交内 `docs/team/reports/P324-dev2.md`；归因已入 main 的 `docs/team/reports/P323-verify.md`。本任务只写自己的报告 `docs/team/reports/V66-dev.md` 和自己的线程，不修改代码、其它报告、版本、CI、看板，不 push/merge/发版。

只查 P324 的三个文件差异：smoke 的两个保留开关环境前缀，workflow gate/collector 的临时根接线，collect-scene 的实际拷贝与族识别。不要重审 P316，不跑全量、FAST、安装套件、路由变异或新计时实验，不新增永久夹具/选择器/守卫。

PM 已要求作者仅精简两句不准确的 workflow 注释：TMPDIR 不是解析器最高优先级，未挂 tmpfs 的 Docker /tmp 不能笼统称为内存盘。你可先用上述冻结提交审查和定点实跑；若后到增量仅为注释和报告，以差异确认可执行内容未变后复用本轮证据，不重复跑，也不另开验收轮次。未经PM通知不追分支移动的 tip。

## 必须独立取得的少量证据

1. 自有磁盘目录里的固定私有克隆，使用原选段入口 `bash skills/teamsmith/tests/smoke.sh --select 34c --keep`：根确被回收，但外层失败现场保留；不能靠删掉断言或跳过。用原有 `TMP_ROOT_BREAK=noreap` 再跑同一入口，目标回收断言必须红。不要改源树；不重复作者已跑过的非 keep 路径。报告原始输出与真实返回码，不把预期的反例失败算成通过。
2. 复用已有 `localhost/teamsmith-gates:p223` 镜像，不构建新镜像。用自己的一次性容器、同一个显式 TMPDIR，先 mkdir 后跑上述选段，结束时主动非零退出，原 collector 从真实停止容器 cp。打开实际产物清单及其中一个具名现场文件，证明确有内容而不是只有目录和锁；锁不得算现场。利用同一容器比较旧 collector：旧源路径/前缀仍须失败，不再起第二次完整容器运行。
3. 复用这个小现场查看不跟随软链；用空目录/仅锁确认仍失败，合并为一次小型实验，不为每个参数建矩阵。作者现成的全部边角参数测试不重复。
4. 审 workflow 里的唯一根是否真正传给两个调用、显式根的创建权限与顺序；检查不改超时/阈值/上传条件。`bash -n` 两个相关 shell、workflow run 块的 shell 语法检查即可，不安装新的验证工具。

镜像不存在就明确 BLOCKED，不重建。Podman 只能经 `distrobox-host-exec podman`。不要碰共享容器/别人的临时根，不用 ns 通配清理。容器与宿主共享的挂载/cp 路径要用 `$HOME/tmp` 下自己唯一目录（distrobox 的 /var/tmp 并非宿主可见）；其它私有磁盘副本可用 /var/tmp。rootless 不支持 --pid=host 时如实记局部验证边界，不试图改宿主设置。若已用停止容器收齐，不为了删软链重新 start 并重跑容器原命令。

运行在固定克隆内，源码不写、报告/日志在克隆外，保护运行指纹。长命令用 team_bg_run 后结束回合，不在前台等待。报告结论先行，每条发现说明是否影响本次修复、给出原始证据；含实际命令与日志位置、钉住的代码SHA、输出尾段和未观测边界。时间用实际 `date -u`，不预填未来时间。

交付前在报告所在树跑固定账本禁令与 git diff --check。独立结论可 PASS/PARTIAL/FAIL，不能因为作者已绿而省去本单独立实测。保持代码只读并本地交付，不重试远程 CI。
