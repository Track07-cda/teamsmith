# 模型路由参数检查与重复执行精简

## Why

两条仅改变参数拆分的变异各重跑完整 boundary，结尾又在未变异原树重跑一次完整 CORE；已接受的探索记录三次旧执行共 1,419 s，但这不是净提速承诺。PM 短样本已在保留真实身份校验的私有前提下取得 extra/resume 两项实际 Bash argv 的正常→原变异失败→同副本恢复通过，因此可以只替换这两条变异的执行并删除原树重复执行。

## What Changes

- `worker-literal-resplit`、`pm-literal-resplit` 从完整 boundary 改为短 argv 检查；固定预期独立于产品 lexer，产品 `%q` 输出经真实 Bash 形成实际参数。保留原三条具名失败与现有 `--flip` 的 child rc/父级失败统计。
- 两条改造臂各在自己的副本取得正常、原变异失败和恢复后的正常结果；PM 不替换 `team_pm_identity_guard`，resume 经显式 `TEAM_PM_RESUME_ARGS` 而非 fresh 或更高优先级 SID 分支。
- 删除末尾 `flip_run restored "$TREE" "$CORE"` 及其成功断言，不留 slow 备用入口。开头正常 CORE、正常 boundary 真实调用方、其余 29 条变异和原恢复机制不变。
- 为以上执行退休在 verification 的原断言/count 约束中增加具名窄例外；明确舍弃两条坏树整组的无关附带观察与第二次原树重复性取样，不声称所有观察等价保留。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `verification`：仅修改 `A gate that cannot judge says so`，容许上述两条完整 boundary 的替换及第二次原树 CORE 的退休，同时保留 route-page、reply-observer 的既有例外与其他断言约束。

## Impact

- 预期实现写集：`skills/teamsmith/tests/task-model-routing.sh`、`skills/teamsmith/tests/lib/model-routing-expansion.sh`，以及 `section-paths.tsv` 的 61b 行登记该已存在 helper。原变异器只读，不改产品脚本。
- 只降低 61b 的重复工作；正常 §61 及首个 CORE 不减场景，不宣称一阶已提速。无新依赖、配置、守卫、case 表、调度框架或独立验测试套件。
- 一个实现批次；非提案作者实施，非实现者独立验证。实施交付只需一次最终完整 61b 集成运行，局部调试使用短样本；不按小提交或报告补提交反复运行小时级矩阵。具体边界及验收见 design/tasks，原始样本与历史成本出处见本任务报告和已接受的探索报告。
- 不纳入 0.4.7 冻结发布对象；本提案不授权实施、归档、真实团队操作、合并或发布。
