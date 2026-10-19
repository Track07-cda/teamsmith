# P320 · 修复发布验收的三种失效前提，不改产品行为

agent: dev3
category: routine
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
