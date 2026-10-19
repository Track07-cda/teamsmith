# V63 · 独立定点复检性能精简返修

agent: dev-bob
category: verify
phase: verify
change: -
specs: -
anchor: none (infra) — 复检 P316 第一轮独立复核发现的具体缺口，不增加产品或测试要求
branch: task/V63-performance-reference-recheck

## 冻结输入

- P316 作者 dev；本席位没有实现 P316。候选 `b025fbdf` / `task/P316-delete-load-sensitive-tests`，源码提交 `03e0c5ba`，最新提交只补报告。
- 只看 `d73ca771..b025fbdf` 的返修差异，以及 V61 已记录的必要上下文。完整报告 `git show b025fbdf:docs/team/reports/P316-dev.md`，先读返修轮次；V61 原报告在 main 的 `docs/team/reports/V61-verify.md`，PM 裁定在 `docs/team/reviews/P316.md`。
- 作者原地破坏实验已经结束，PM 已核对树干净、产品目录与返修前逐字节相同。本任务如需破坏，只能在你自己的磁盘临时完整 clone 里操作，不改交付树、他人 clone 或生产文件。
- P320/V62 是另一冻结发布候选，本任务不得合入这些修复、移动标签、合并或推送。P316 仍不进入 0.3.0。

## 独立要回答的五件事

1. 持续进度是否不会被总耗时停跑，原有无进度/失控/退出与现场行为是否仍在？只复用 section-guard 既有自检，不新增看门狗、进度协议或永久夹具。
2. 三处首帧等待是否真正统一了调用视界与含义，性能读数是否仍不作正确性失败？结合真实 diff，不凭“参考”等字面标记。
3. 限时取锁用真实锁竞争的返回/未发布行为加外部 flock 限时协议守住，是否足够；绑定文件描述符字面量 3 是否必要，别把实现细节变成契约。
4. 宽限旋钮覆盖是否真的恢复？PM 发现两条腿同时改变了旋钮和作业行为，存在混淆：0 配忽略 TERM，2 配响应 TERM，结果不同可能只由作业造成。**只做一个必要反例**：在私有 clone 将实现固定为 grace=2，复用现有 promises 入口，看宽限相关断言是否仍绿。不要把无关既有红当作这个反例成功，也不要建立变异器/版本矩阵；若源码已足以证明，记录反例逻辑亦可。报告准确区分“检测不等待”与“检测旋钮值被遵守”。同时检查新增作业四秒自然寿命、固定 sleep 起步是否又引入隐含机器速度前提，不以猜测宣告失败。
5. 参考汇总数字/单位是否修复、自指措辞检查是否删去或收窄、产品源码是否保持未改？复用作者原始数据和差异即可，不必重复测性能。

## 独立运行的上限

只需三个现成入口：
- `bash skills/teamsmith/tests/lib/section-guard.sh --self-test`
- `bash skills/teamsmith/tests/key-replies.sh --select receipts`
- `TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises`（包括上面唯一的受控反例；按命名结果判，不要求修复范围外的旧红）

不跑全量、FAST 全量、smoke 闭包、routes flips 或整套路由变异；不造负载、不等待安静机器，不改测试以使其通过。耗时仅参考，必要等待语义不能偷换成毫秒区间测试。

长命令用 team_bg_run 挂起，完成通知后 harvest。临时根走已选磁盘 TMPDIR/TEAM_TMP_ROOT，不把副本写到 tmpfs `/tmp`。

## 交付

只写 `docs/team/reports/V63-dev-bob.md`。结论 PASS / FAIL / PARTIAL，并逐项给已成立部分、实际缺口与最小下一步，不能因作者总数一致或净减行数而宣布覆盖充分。不得自行实现修复或建议加整套守卫。测试字节与源码恢复核对、实际命令/读数、未验证边界都要明确；提交前账本禁令与 git diff --check，完成后明确通知 PM。