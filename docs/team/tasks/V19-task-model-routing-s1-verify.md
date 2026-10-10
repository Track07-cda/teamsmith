# V19 · 任务模型路由：S1 私有候选独立复验

task: V19
agent: dev3
phase: verify
category: verify
change: task-model-routing
specs: dispatch, memory-and-deps, agent-adapters, pm-lifecycle, watchdog
deltas: -
branch: task/V19-task-model-routing-s1-verify
deps: P228 F6+OBS1-repaired S1 candidate 8bea13e7e325b10bb4032fcc9cb59fe04a7d7118 (前一个产品提交 55d3bc6); E14 accepted proposal

## 范围与调度

用户已批准隔离实现与独立验证。你未参与该 change 的提案或实现。只复验 P228 的 S1 私有候选，不验证尚未实施的 S2 panel、S3 初始化/指南，不把局部通过说成整个 change 已通过。前四轮候选16842c9、a21a0a3、a1a285d、985328b 的FAIL报告及原证据保持不变。本轮输入是**第六轮**（F6 类别词汇 + OBS1 身份发布）返修后的候选；PM 显式用强模型 fresh 派单，不超并发、不自行启动。

阅读 AGENTS、自己的最新线程、本 brief、OWNERSHIP、D104–D116；再读接受的 task-model-routing proposal/design/tasks、七份 delta 与对应 canonical specs、P228 brief/完整报告/冻结清单。历史线程的 E12/P158 命令不属于本任务。原生 OpenSpec 1.8.0 没有 verify workflow，按本仓 openspec reference 的独立验证流程执行，不安装或生成工具。

## 第六轮重点（F6 + OBS1）

- **F6（你上一轮判定的真缺陷）**：`analysis`/`verify` 曾被硬编码为必备类别。核实现在**唯一非法的映射是空映射**：整映射用自定义词汇（不含 analysis/verify）必须可写、可读、可升级、可派单；只含 analysis/verify 的映射仍合法；未映射的类别用于**新选择**仍拒绝；同任务可信恢复的既有规则不许放松。别只复跑作者的用例——自己造一份无 analysis/verify 的映射走一遍写侧/读侧/派单。
- **OBS1（PM 裁定的真缺陷）**：只绑部分身份占位符的模板曾发布完整身份。核实规则是「**发布的身份不得多于 argv 实际交付的**」：部分绑定的模板要么被拒、要么只发布实际交付到的字段（teamsmith 铸的 SID 不得当已启动身份发布）；诚实 opaque 路径与既有合法控制在同一条规则下有明确结论。核对**发布记录 ⊆ 真实 argv**（读你自己的真实 argv 证据，不读报告结论）。
- 回归：F1–F5 的既有结果不许回退（含 PM 冻结探针旧 1/20 → 新 21/0，以及 18 臂破坏套件）。
- 夹具纪律：作者在 `smoke.sh`/适配器夹具上做过改动，逐条比对断言数量与强度，确认没有用改夹具代替删断言。

## 被检树与控制面

自己长期 worktree 只写报告，不加载候选为实际运行的共享技能。PM 准备的新仓外独立真实 clone 为 `pm-skills-ledger/team/reviews/V19/round6-8bea13e/checkout`，检出完整候选 `8bea13e7e325b10bb4032fcc9cb59fe04a7d7118`（第六轮 F6+OBS1 返修后的 tip；`55d3bc6` 是它之前的产品提交）。旧clone、前四轮报告与所有中断/勘误证据不覆盖。由主检出的 git common directory 解析路径：

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
CANDIDATE="$CONTROL_ROOT/../pm-skills-ledger/team/reviews/V19/round6-8bea13e/checkout"
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/V19-dev3/round6-8bea13e"
OLD_CANDIDATE="$CONTROL_ROOT/../pm-skills-ledger/team/reviews/V19/binding-985328b/checkout"
PM_PROBE="$CONTROL_ROOT/../pm-skills-ledger/team/reviews/V19/binding-985328b/pm-selector-data-replay/probe.sh"
```

先验证 CANDIDATE 的绝对路径、HEAD、`.git` 为真实目录、git status 干净，产品/测试树与 `55d3bc6` 逐字节一致、`55d3bc6..aaffe5a` 只改 `docs/`；再核对 PM 冻结探针 `probe.sh` 的 sha256 仍是 `76341583b85e1dd95e26b09b84989ef338b8842d85f149f0059a376e2ac5b2fd`（本轮不得改它）。错根或脏树先 BLOCKED，不修改来通过前置检查。被测 CLI 只能在显式隔离的 fixture repo/HOME/tmux socket 中运行，清除真实 TEAM 身份并在任何写盘前核对 fixture 根；不能在候选根或真实团队调用 config/dispatch/resume/up/close/teardown/init/bootstrap/watch。仅稳定主检出的 CLI 用于 notify pm；不读真实 Pi 历史、credential，不启动 provider。

## 独立检查

对照接受的 S1 tasks 1.1–5.3 与场景索引，自己读代码和 diff，不只复用作者的 PASS。重点审查：类别/整体策略与恢复删除类别的豁免边界、suffix/extras 与 SID、数据式完整 assignment、启动证明/nonce/原子提交、锁顺序和配额未知身份、close/teardown、配置 CAS/整个升级与审计失败、多个读者的中间态、PM 原模型恢复/启动失败回收，以及 SID A 不读 B/base。核对窄 cmd-review/close 授权，原有非模型断言不得被删/skip/弱化。

自己在稳定候选执行以下切片验收，日志全部另放 EVIDENCE，不将作者日志冒充独立结果。一个 gate 一次，长命令用 team_bg_run 并在结束前全部收割；检查 /tmp 容量，遵守全套锁。不要跑尚需 S2/S3 的全仓 smoke：完整集成后另有全量 verify。

```bash
df -h /tmp
# 从 CANDIDATE 执行；每条设置合理 timeout 并记录 rc
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/death-cause.sh --pure
bash skills/teamsmith/tests/death-cause.sh --live
bash skills/teamsmith/tests/death-cause.sh --flip
bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary
bash skills/teamsmith/tests/task-model-routing.sh --select flip
bash "$PM_PROBE" "$OLD_CANDIDATE" "$EVIDENCE/old-probe"      # 期望 rc=1、TOTAL pass=1 fail=20
bash "$PM_PROBE" "$CANDIDATE" "$EVIDENCE/new-probe"          # 期望 rc=0、TOTAL pass=21 fail=0
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
```

测试运行前后对 HEAD/status/source hash，树在跑动中变了则整轮无效。原源码不改；17个破坏臂仅在自己的独立scratch副本执行，保留matched/hash/具名FAIL/rc/恢复逐字节控制。源码flips的外层timeout至少6000s；routing至少1800s，未完成不能冒称通过。独立重查前四项F1/F2/F3/F4：对旧源码仍能复现，对新源码明确检查真实启动 argv 或早拒绝的无副作用、坏记录的所有读者与正常恢复控制；不要原封不动运行只期望旧缺陷仍存在的探针。补至少一项自己设计的新边界或竞态反例，不能仅转录作者2848/0或111/0。

本轮重点 F5「参数角色证明」（根因：词面出现 ≠ 参数角色绑定；`--skill`/未知开关/续跑形式会把身份 selector 当成自己的数据）。必做：用 PM 冻结探针对**旧的** `985328b` clone 复现红（期望 `TOTAL pass=1 fail=20`、rc=1），对 CANDIDATE 期望 `TOTAL pass=21 fail=0`、rc=0；再自己设计角色反例，至少覆盖 `-e`/`--skill`/未知开关（含 `=` 形式与加引号）/`--continue`/`--resume` 这几种「吃什么」的位置形态 × worker/PM × preview/真实启动，并检查拒绝时 config/BOARD/state/提示词/窗口/PID 无副作用。合法一侧要检查真实 argv 精确绑定（provider/model/SID 的**值**，不是词面出现），包括 `--skill harmless`、`{-e}`、`{resume_args}` 原位展开后的形式。审查新增 `team_argv_roles_guard` 的判据本身：它是否把「已证明的绑定」与「词面出现」真正分开？未知开关的保守拒绝边界与已接受窄 grammar 是否一致，有没有把 Pi 参数表/arity 解析或兼容矩阵偷偷引入（那是 Pi 职责）？作者自报的未跑部分（`§2 init` 无 `TEAM_TASK_MODELS`、`§4 team task` 无 `--category`、S1/S3 交接期的夹具 seed）必须自己核到根因，判断它是否真在 S1 车道之外，而不是照抄作者的边界声明；`smoke.sh` 的 adapter/模板夹具改动要逐条比对断言数量与强度，确认没有用改夹具代替删断言。先读第三轮ef8f952与作者F4追加，固定独立脚本重演旧红→新拒绝及无副作用、合法绑定绿；覆盖worker/PM的单个/全部positional和其他参数数据槽，不能从相同字符串出现推断绑定。审查实际选择器与占位符错绑、fresh/continued/opaque边界、引号及 extras、PM 接缝，以及同一解析器在不同读者的快照/有界性；按已接受规格区分承诺内漏洞与不承诺的接缝行为，不自行扩张 Pi 职责。monitor 新增同步 Bash 子进程，记录多席位读源是否出现明显阻塞；未跑性能门禁不得作性能通过声明。F3须在隔离cwd放可命中的model/provider/SID/continue诱饵，分别验证worker/PM模板、extras及PM恢复入口的preview/真实调用。对支持的quoted literal检查实际参数逐字节一致，保守拒绝也可满足已接受窄grammar，不把字面`--mod*`无展开却不改身份的路径误判为绕过。新脚本运行前冻结内容与SHA、源码/输入前后核对，不能边跑边改；旧轮未知短别名、sid_bytes和quoted假定已勘误，不重造假红。新测试脚本只存仓外，不替作者修产品/测试；发现失败保留精确复现，交回 PM。将原有真实故障、预期 mutant 红和新发现分开，不能把坏源码臂红误记为基线失败。

## 产物与写边界

只写自己的 `docs/team/reports/V19-dev3.md`，以及 EVIDENCE 下的独立日志/脚本/owned scratch。CANDIDATE 原树只读；不可写产品、canonical/change/tasks 勾选、Main 公共治理账本/评审或私有 integration clone，不合并/推送/归档/部署。最终正式 review 由 PM 据你的报告与自身复验写入；不把 report 假装成 PM verdict。

报告逐项映射场景→真实断言→命令/rc/原始证据，结论 PASS/FAIL/PARTIAL 限定 S1，列未测 S2/S3/真实 provider/共享采纳。保留已有报告正文及首轮 FAIL，追加本轮独立修订记录、当前限定 S1 结论与新输入，不把旧失败覆盖成绿。包含受检完整 SHA、差异集审查、独立反例红绿和源稳定性检查；明确作者证据与自己的证据分离。每个可验证步骤提交 Conventional Commit，含 V19 与 `Agent: dev3`，报告已提交/自己树干净、所有 jobs 收割后通过稳定 CONTROL_ROOT CLI 通知 pm。不 mark P228 done，不用真实共享环境证明候选正确。
