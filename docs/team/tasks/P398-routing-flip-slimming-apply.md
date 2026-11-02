# P398 · 61b 执行瘦身首片

agent: dev3
category: code
phase: apply
change: gate-execution-slimming
specs: verification
deltas: openspec/changes/gate-execution-slimming/specs/verification/spec.md
deps: P397 proposal ACCEPTED (D220); V118 aa69cb387445 / 6081debe99ca
status: todo

## 接手与问题

执行 `/opsx-apply gate-execution-slimming` 的第一片：完成已接受 tasks.md §1，并交出实际执行减量、保留的错误发现能力和同环境耗时证据。不是重新提案，也不是三片一起做。提案作者dev2；你没有参与其编写，后续Verify必须由别人承担。category code用于已有设计下的有界实现。

先读AGENTS、自己的thread、本brief、`openspec/changes/gate-execution-slimming/`四文件、能力spec和正式proposal review。PM准备的新分支携带精确规划369c7d87及报告009b2835；V118最终报告用 `git show 6081debe99ca:docs/team/reports/V118-verify.md` 读取原件（不改原件格式）；主检出只接受方案，没有合入产品。生成的opsx命令若缺失，按 `skills/teamsmith/references/openspec.md` 执行并读 `"$HOME/.bun/bin/openspec" instructions apply --change gate-execution-slimming --json`；不要为补命令运行init。

## 执行片与边界

- 范围为tasks §1.1–§1.8，以及本片适用的0.1/0.3/0.4、交接和回滚说明；依赖的规范是delta中 `A fixture meta-mutation arm runs the cases it declares`。规范正文不复制到brief。
- 只临时借用：`skills/teamsmith/tests/task-model-routing.sh`、`skills/teamsmith/tests/lib/model-routing-boundary.sh`、新增 `skills/teamsmith/tests/lib/model-routing-arm-cases.tsv`。可在 `tests/section-paths.tsv` 既有61b行仅登记新表路径；不改选择算法、其它行或新增段。授权已写OWNERSHIP。
- change内仅更新本片实际完成的tasks勾选及交接位置，并一次清理V118 R4三处非阻塞文本：部分重名tag才在两循环命中；剩余“实测宽度”限定retained；循环键标题/嵌套反引号排版。不要改变接受的选择规则、计数前提或其它slice。
- 不改roles/expansion/resume-role子夹具、产品代码、smoke.sh、routes、其它选择器、工作流、通用SKILL/提示词、canonical specs、AGENTS或真实配置/团队状态。P396/其它任务未合入；只盘点，不导入、不修它们的代码。
- 新声明取代既有模糊grep和重复调用，不再叠加第二张golden表、通用选择器、runner、守卫段或跨段状态。发现必须跨边界才能完成时写BLOCKED及具体路径交PM，不能自行扩设计。

## 日志与测试安排

先盘点已有证据，不启动整套smoke作为开工动作。主要证据入口：`$HOME/.cache/P396/full-gate/`（中断整套不算PASS，61b可能有闭合记录）、P379报告 `git show task/P379-gate-simplification-explore:docs/team/reports/P379-dev2.md`、`$HOME/.cache/pm-skills-reviews/P397-3fdd1a8a/author-evidence/`及其校验和、随分支携带的P397/V118报告。不同提交/环境的时间不能相减冒充同轴收益。

1. 冻结源码/环境指纹，确认已有逐臂日志能否给出本片的before普查；标出不适用或缺失的具体臂/字段。只有确有具名缺口才补一次61b改前矩阵，不另跑完整smoke。必要的改前读数在独立只读scratch clone运行，以便你继续实现，不修改在飞树。
2. 日常只跑相关普通组与三种声明形状；采用既有scratch测试隔离。所有fixture必须有独立Git根/cwd，不继承真实团队root、会话或真实Pi调用。不可在main或真实团队上执行init/standby/notify等测试。
3. 最终冻结本片候选后，通过smoke的61b选段跑一次完整31臂及两次行为对照，兼作1.7的改后读数，不再额外直接跑一次 `--flip`。有具体失败先定点修复/归因，不每个小修重复整矩阵。
4. 本片不执行0.2的新一轮全量smoke，也不提前执行4.1整合全量；保持未完成项未勾选，不能把本片成功报成整个change完成。计时只作参考，不提高超时、不删正常/还原行为对照。最终独立Verify交PM另派。
5. 长运行使用team_bg_run并结束该turn，完成唤醒后harvest；日志及TMPDIR在本次自己创建的/var/tmp或自己的磁盘cache，保留完整日志、子日志与现场，不用 `/tmp`，也不pipe tail丢原文。只清本次确切临时根，不用共享前缀通配。

## 验收命令与交接

从自己的worktree执行，真实记录命令、环境及输出尾部；长命令先重定向完整文件后交后台运行。

```bash
bash -lc '"$HOME/.bun/bin/openspec" validate --all --strict'
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
bash skills/teamsmith/tests/task-model-routing.sh --select boundary
# 最终读数：一次即可；FAST必须关闭，且保留现场/全部日志
TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh --select 61b --keep
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/lib/model-routing-arm-cases.tsv
git diff --check
```

任务1.8的三种红/绿形状由既有臂表/夹具在私有scratch验证；恢复后还要绿。按0.4给出的五类路径保存改前/改后键清单并逐字比较，新增表路径必须选中61b。不把推导931或原计划固定键数当性能/数量硬断言；以实际baseline与输出对账，不更改选择范围来凑数。

本片报告 `docs/team/reports/P398-dev3.md`：答案在前，列减掉/保留/明示舍弃的观察、31臂具名检测、两控制、三种形状、逐臂实测派单/用例计数与时间、writer提前拒绝的差异、既有/补跑证据来源、未完成项和下一片入口。普查before/after TSV放 `docs/team/reports/P398-dev3/`，带retained/incidental分类和sha256；该目录被ignore，交接表要定点 `git add -f` 入仓，原始长日志只在磁盘保留并给路径，不冒称已提交。fixture不放报告目录。

本地小步提交，Conventional Commits带P398及 `Agent: dev3`。local模式不push、不发PR/MR、不merge/删分支、不真archive，不改P391旧分支。交付后冻结分支/报告，等待非作者验收。D219额度规则沿用：只有明确clinepass额度耗尽才报告原错，由PM按授权切备用模型+新SID，不因普通网络错换模。

## 派单审计

P391已交付并被D218接受，旧分支/报告保留且未合入；P397已被D220接受，提案者dev2停止写规划。若工具因这些未done记录拒绝派单，PM的force仅允许这次已交付席位交接/阶段delta所有权移交：P398是唯一当前实现写者，不消除独立验证或用户合入授权。新任务按code类别当前配置选模型、创建新SID，不带历史模型override。
