# P320 · 修复发布验收的三种失效前提，不改产品行为

agent: dev3
category: code
phase: apply
change: -
specs: -
anchor: none (infra) — 修复现有门禁的会话前提、测试私有变量及版本字面量，不增加产品或测试要求
branch: task/P320-release-fixture-repair

## 输入与授权

沿用 P319 的确定性诊断与 PM 接受记录 `docs/team/reviews/P319-proposal.md`，不重新探索。P319 报告在 `docs/team/reports/P319-dev3.md`。本任务是发布门禁自身修复，不是外部评审或 P316/P317 清理；不能把这些变更合入本分支。

P316 测试源码已冻结，V61 只读复核；本任务期间上述三个测试文件唯一写者为本席位。PM 负责发布和独立复核，你不移动标签、不推 main、不合并。

## 唯一可写范围

- `skills/teamsmith/tests/smoke.sh`
- `skills/teamsmith/tests/routes.sh`
- `skills/teamsmith/tests/task-model-routing.sh`
- 自己的报告 `docs/team/reports/P320-dev3.md`

只做 P319 已证明的三件修复：
1. §42/§44 中，在可能杀掉最后一个 dev 窗口之后再调用现有 `smoke_live_session_ensure`，保证 new-window 有现成会话。不新增窗口守卫或 helper。
2. 将两份录制 shim 的四个 `TEAM_ROUTES_*` 传播位改用非 `TEAM_` 私有前缀（如 `SMOKE_ROUTES_*`），生产的身份剥离保持不变。
3. updatecheck 的本地版本预期从被测树取值，不再写死 0.2.0。特别保住“same”用例：`u_arm 0.2.0 same` 在当前树实际测的是旧版本，应让它真正返回当前版本；older 仍必须更旧，禁用/只读缓存字节不变等断言不删。缓存种子是否替换按原场景语义，不把故意旧的缓存改成新鲜缓存。

不修失败摘要打印、不动耗时判据、不退役测试、不增加断言、静态守卫、夹具、版本矩阵或新开关；不修改产品、规格、发布工具。出现新问题交回 PM，不顺手扩大。

## 最小验证（现有入口，固定容器）

在固定镜像 `1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b` 的完整 clone 上验证；HOME=/tmp，工作目录 /work，不直接挂载 .git 位于容器外的 worktree。只用已有时间预算运行参数避免历史秒数切断行为验收，明确记录参数；不改预算表、不等待低负载。

- `bash skills/teamsmith/tests/smoke.sh --select 4,6,6i,42,44,54`：覆盖曾杀掉最后窗口的顺序、两处回放、派单审计/恢复原有断言。
- `bash skills/teamsmith/tests/routes.sh walk control promises refusals`：不跑 flips。
- `bash skills/teamsmith/tests/task-model-routing.sh --select updatecheck`：原 45 条全部实际跑，不用 grep 代替结果。
- 语法、`git diff --check`、固定账本禁令。

不重跑全量、FAST 全量或整套 61b。61b 的变异此前未执行，PM 会在独立复核时单独补齐这一必需部分，不能把它写成已通过。本任务不再新增红侧：P319 已有同一源码/同一断言的改前红，配上本次改后结果即可。

## 交付

小步提交，报告先给结果、精确 diff 范围、三个现有入口的命令与实际读数，以及是否修改过任何原有行为断言。没有运行的如实列明；完成后冻结源码并明确通知 PM。不要在报告末尾建议重跑整套门禁。

## V62 独立复核后的唯一收口（同一任务）

三处修复已独立通过：smoke 495/0，路由 CORE 基线及还原均 3141/0；31 条变异均执行、组级变红并还原，但外层 `flip-init-legacy-proceeds-bootstrap` 未通过，不能称整套全绿。V62 已在私有树量化证明复制集合写成复数 `extensions`，实际源目录为单数 `extension`；bootstrap 因缺扩展文件先失败，掩盖了目标拒绝检查。

现在只授权在 task-model-routing.sh 的既有 `for source_dir in scripts references templates extensions` 复制清单中纠正目录名，删除错误复数项，不加兜底、存在性守卫、断言、永久筛选开关或新夹具；另更新自己的报告。当前分支 c5c85855、树干净，保留原三处修复，不拉入 P316/P317 或其它产品变更。

作者只需语法、diff --check、账本禁令；V62 已有该臂反事实证据，不要求作者再跑整批或复做独立实验。小步提交后立即冻结、给新 tip。

仍由同一 V62 席位在固定容器磁盘私有 clone 审这一个增量，复用原有 init 复演方法，覆盖共享 init 分组的三条既有变异（init-legacy-proceeds、template-retired-key、legacy-route-placeholder），检查原具名断言与源码还原。正常基线/还原只需 init 组。其它组按实际是否安装扩展界定影响：若找到额外消费者，具名说明后只补受影响的，不默认重跑 31 臂、CORE、smoke 或全量。不提交新选择器或测试机制。

最终合记此前完整运行与此次定点补验，不冒充“一次原样 --flip 全绿”；没有通过的仍逐条列出。P320 与 V62 沿同一任务收口，不另派新的验收轮次；0.3.0 范围继续排除性能精简与吞错清理。
