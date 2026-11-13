---
id: V162
title: 模型路由三处精简提案独立审阅
agent: dev3
category: verify
phase: verify
change: routing-argv-check-slimming
specs: verification
deltas: -
branch: task/V162-routing-slimming-proposal-review
---

# V162 · 定点审阅 P455，不运行完整矩阵

候选 `8f244edc`，提案作者dev2。PM准备干净独立检出 `/var/tmp/p455-review-8f244edc`。只审阅提案和窄样本，不改实现或规划，不验证尚未实现的产品，不把缺少未来Apply证据当规划缺陷。

输入：`docs/team/reports/P454-dev2.md`、`P455-dev2.md`，change `routing-argv-check-slimming` 的proposal/design/specs/tasks。

只核四件事：

1. 两条resplit只更改参数拼接：实际Bash argv观察与固定期望可发现原错误，PM保留真实身份判定及显式resume路径，setup错误不冒充具名失败。独立运行所需最小worker/PM样本即可，不重跑已有长组。
2. 末尾CORE确实再次测未改原树，不是在测恢复后的副本；首个正常CORE、正常真实调用方与其他29臂保留。无关坏树观察明确舍弃，不把覆盖减少说成完全等价；既有反例并非全部神圣，但本批不能顺手丢真实行为。
3. 新短入口父级rc/具名错误/健康恢复接线足以替换旧路径；原执行真的删除，没有slow副入口，没有新框架、永久自证检查或为3处删除再造一层测试。评估规划的临时接线反例是否够用而不过量，提出最小删改，不扩审整个测试系统。
4. verification MODIFIED块保留原12场景及既有例外，新增内容只限定本批；计数来自实际执行而非凑旧203。完整集成只计划最终可执行字节上一次61b；独立及合并后检查按差异选择，不再机械每阶段重跑小时级矩阵。旧1419s不当净提速；本批不宣称正常61或完整一阶已变快。

执行当前OpenSpec1.16的本change严格结构校验、spec-refs、ledger-ban、diff-check；不跑full/61b/夜间/FAST全套，不重测历史计时或试归档。

`team review P455 --dir /var/tmp/p455-review-8f244edc --branch 8f244edc --no-gates` 仅写人工规划审阅记录，不冒充完整测试执行。中央工具写例外仅 `docs/team/reviews/P455.md` 与 `P455-verify.log`；其余只写自己的 `docs/team/reports/V162-dev3.md`，提交最终PASS/NEEDS-CHANGES、真实检查与未验证边界。报告先给影响结论与必要最小返修，不为格式偏好来回返工。

不修改他人分支、主spec或任务范围，不合并、不实施、不归档、不发布。完成后通知PM。
