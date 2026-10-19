# V62 · 复核最小发布修复，补齐未执行的路由变异

agent: verify
category: verify
phase: verify
change: -
specs: -
anchor: none (infra) — 独立核验 P320 对现有发布夹具的三处修复，补跑发布验收中尚未执行的原有变异
branch: task/V62-release-fixture-review

## 冻结输入与结论范围

- P320 作者 dev3，不是本席位；源码冻结 `b4317dfd5354`，报告提交 `c5c85855`。自己核实两者测试字节相同。
- 受检分支 `task/P320-release-fixture-repair`，作者报告可用 `git show c5c85855:docs/team/reports/P320-dev3.md` 读取。
- 基线 `9c58e03e`，只有三个 tests 文件变化（+49/-37），不应含产品、规格、发布工具、P316/P317。
- 作者固定容器结果：smoke 14 段 ✓495 ✗0、routes 四段 ✓234 ✗0、updatecheck 45/0；这些是作者证据，不冒充独立复跑。P319 已有对应改前红。

本任务先裁定代码差异是否保持原行为断言与真实前提，然后完成一项尚未执行的必要验收：冻结树的原有模型路由变异清单。派单时条数误记为 28，V62 按源码核实为 31；仍执行同一个既有 --flip 命令，没有新增变异。不要把基线失败后“变异未跑”说成变异已绿。

## 独立核查

1. 逐 hunk 看三文件，确认会话 helper 只是挪到杀窗后、私有变量只改传播前缀、生产 TEAM_* 身份剥离未削弱。
2. 确认版本确实来自受检树；same 返回当前版本、older 真更旧、CHECKED_AT=1 仍旧、禁用/只读缓存字节不变；不要为了不存在的其他版本建矩阵或新守卫。
3. 固定镜像内独立跑 `bash skills/teamsmith/tests/smoke.sh --select 4,6,6i,42,44,54`，包括曾杀掉唯一窗口的顺序。无需重复作者单跑 §44 或 routes 四段。
4. 同一冻结树，**一次**跑原有 `bash skills/teamsmith/tests/task-model-routing.sh --flip`，其自带基线与源码列出的全部 31 个臂均需实际执行。它包含独立的 updatecheck 与路由场景，不另重跑 updatecheck 或整套 §61。

容器使用固定镜像 `1d723525ee58a8b177862746bc92cde2307a7d5f8a76045f5641703d8ac1a50b`，HOME=/tmp、/work 是完整 clone；从容器外使用 `distrobox-host-exec podman`。如复用已有冻结 clone，必须确认归本次独立运行所有，不改作者 clone。TMPDIR 显式指向磁盘目录，不能为测量制造负载或等待低负载。

可沿用 `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_SECTION_BUDGET=21600` 避免已否决的历史秒数预算切断行为验收；记录该参数，不改源码或预算表。长变异必须用 team_bg_run 挂起，完成通知后 harvest，不在前台循环轮询。

## 边界与交付

只写自己的 `docs/team/reports/V62-verify.md`；不修改产品、tests、规格、发布工具，不移动标签、不合并、不推送、不新增测试、静态检查器或变异器。已有变异红侧足够，不再为三个修复新增破坏实验。

不跑全量 smoke/FAST，不跑 routes flips，不重跑通过的原样 103 段。若失败，保存第一次原始错误和确切臂名，区分产品错误、夹具错误、未完成；不擅自修复、不用反复全组重跑取绿。

报告给 PASS / FAIL / PARTIAL、独立运行的实际读数、31 臂是否逐条执行并恢复、源码与范围核对、明确未跑部分；报告提交前账本禁令和 `git diff --check`。完成后冻结交付并通知 PM。