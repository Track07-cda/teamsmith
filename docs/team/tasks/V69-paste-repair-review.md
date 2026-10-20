# V69 · 图片粘贴修复：独立验证落盘、降级与完整路径

task: V69
agent: dev-bob
phase: verify
category: verify
change: -
specs: panel#`C-v` pastes a clipboard image as a temporary file path
deltas: -
branch: task/V69-paste-repair-review

## 候选与范围

P331最终代码固定在 `950ac8af`（产品 `6c749518`、理由框断言 `6f516b42`），源码与受检bundle均在该ref。读本席线程、P331任务书与 `docs/team/reports/P331-dev2.md`。在自己的磁盘私有克隆检出这个ref，不修改作者/主检出；不合并追最新。只写自己的报告，local模式不push。

要回答：无capacity.log的新项目，容量块仍降级，图片能否按同一临时根解析结果落盘、字节正确且完整路径进入草稿和理由框？新修复不能把其它失败块的payload悄悄当成功数据，也不能因几何断言拼接整个屏幕而假绿。

## 只做这些验证

1. 审源码最终diff，确认只有capacity的temp_root字符串保留，原degraded/errors、--json/--print输出不变，成功/失败更新不会用上一轮临时根冒充本次无效payload。理由框重建只包含该框且完整非空路径；不要仅相信作者的“未改协议”说明。
2. 一次钉住工具链重建，比较提交的panel.js逐字节一致（`bun install --frozen-lockfile && bash build.sh`，从panel目录执行）；不重建未改动历史基线，不加新的构建检查器。
3. 同一固定克隆跑一次 `bash skills/teamsmith/tests/panel-b2.sh clipboard`，再用现有 `TEAM_B2_PANEL` 通道替换为 `b57db390^` 的旧bundle跑同一场景。修复候选必须全绿；旧bundle必须命中原三条落盘/字节断言（理由路径非空失败也如实记）。必须贴实际命令、退出码、具名输出；预期反例非0不是“测试通过”。
4. 不重跑26/27/28/38整批；从源码和已有协议测试断言判断数据层改动是否触碰外部输出。若发现现有断言无法证明，先写缺口给PM，不擅自开一套新用例或完整门禁。

不操作真实桌面剪贴板，不复演作者的真环境实验；已得真环境因果证据与本次独立夹具证据分别记账。用/var/tmp中的私临时根/锁/tmux，自己的日志在受检树外，运行中不改树。只清自己具体路径，不碰别人的工作根。

## 交付

`docs/team/reports/V69-dev-bob.md`：先PASS/PARTIAL/FAIL和是否可合入，再给原始输出位置与数据层/断言审查结论，时间用实际值。作者正在修报告中把早先/tmp现场写成/var/tmp的失真引用：评审以git历史f21b3e97与修订报告核对，不因报告改字重跑代码，也不将路径改写当新实验。

跑账本禁令、diff检查后提交，Agent: dev-bob；通知PM，冻结候选，不扩面接门禁（后续P327负责）。
