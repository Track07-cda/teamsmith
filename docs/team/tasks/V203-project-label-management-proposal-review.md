---
id: V203
title: 独立审阅项目设置直接管理任务标签的方案
agent: dev3
deps: P506
category: verify
phase: opsx-verify
change: project-label-management
specs: panel,board-and-status
deltas: -
branch: task/V203-project-label-management-proposal-review
---

# V203 · 核项目设置标签管理的范围、兼容与可验收性

候选 `4719a40738abd040797f15655629055e1816f62a`，独立检出 `/var/tmp/p507-review-4719a407.FvYMJh`；作者 dev2。P509 已交独立验收，但本席仍负责其短返修直到结案，结案后再接本任务。读 AGENTS、本人线程、归属、D271、P506/P507 和固定工件。只交 `docs/team/reports/V203-dev3.md`；给接受或最少需修订点，不写候选。

1. 对照当前 `panel` 正式设置精简约定，核只多一条二级入口，并保留原来的设置项、列表/筛选、返回和键鼠。标签管理是普通名称、选色、数字与保存/取消/确认，不手输配置、Hex 或命令；标签详情仍用于查看，给任务加标签不混入。核已有自定义色保留、删除在使用时不可解绑，文案没有新增不必要的解释。样例 10→11 行不能冒称所有项目同样数量。
2. 对照冻结标签候选的真实 `define/edit/delete/ls`、原同名/已用/写结果不明与现行面板项目寻址。核唯一写入口和项目归属、命令行保留实际出错区别、精确参数与全长整数；新增可读结果需要说清必须信息，拒绝再造存储、第二份校验或建立过度机制。空标签为可编辑列表，读取失败不能用它替代。核写成功后的最小读回与看板新数据（不能只是返回在途旧读），不自动重试、轮询或改任务时间、排序算法、模型和派单。已合入倒序和原标签方案的衔接，定义层基础要求没合并前不能实施，若最终接口不同必须定点复审。不改 P497/V196 或其它提案。
3. 验证现有 `panel-p21.sh settings` 选择器能到实际真实写入的隔离场景；用原有限的通用导航检查替换、真实读回 1 次流程区别保存、保颜色、取消不写与已用拒删。勿为方案加测试包、进度仪表或重新验权重和看板全部。点名原命令与模型记录操作仍覆盖哪些，未实测的情况不算绿。

固定检出只运行一次 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate project-label-management --type change --strict --no-interactive`；保留实际回执和 Git 差异检查。报告按事实、结论与最少修订写，本地小步提交（V203 / `Agent: dev3`）。不跑 UI/业务命令、构建、全量、安装、模型，不动真实项目或 P497，无产品修改/推送/合并。