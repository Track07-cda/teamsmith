# writing-discipline · tasks

阶段口径：本文件是**执行清单**，不是规格；合同在 `specs/writing-discipline/spec.md`（4 条 ADDED requirement）。
propose 阶段（本文件作者）只写提案与设计，一行实现都不做：**apply** 由另一个席位按其任务书执行，**verify** 再由
**第三个**席位（不是 apply 作者）在独立检出上重跑。每一格由**做的人**勾，勾时在条目里写证据；没做的写明没做。

写集：`skills/teamsmith/templates/AGENTS.section.md.tmpl`、`skills/teamsmith/templates/pm-prompt.md.tmpl`、
`skills/teamsmith/references/protocol.md`、`skills/teamsmith/references/workflows.md`（本仓 `AGENTS.md` 见 0.3，
需授权）；对照材料在 `docs/team/reports/<对照任务 ID>-<席位>/compare/`。

## 要求 ↔ 条目对照（防孤儿任务）

| 规格要求 | 条目 |
|---|---|
| R1 谨慎只带证据留下（含「不删带证据的边界声明」与「禁止读成语气建议」） | 1.1 1.2 1.3 2.1 |
| R2 发现写明它改变了什么（且不新增必需栏位） | 1.1 1.2 1.3 2.3 |
| R3 规则随三处表面与评审读法发出、由评审而非门禁守（含诚实边界） | 1.1 1.2 1.3 1.4 2.2 |
| R4 效果由人读的对照判定，AI 评审打分不得作为接受信号 | 3.1 3.2 3.3 3.4 3.5 |
| 交付与独立复验（各阶段自己的要求，不映射到产品规格） | 0.* 4.* 5.* |

## 0 冻结与口径（apply 起步）

- [ ] 0.1 读 PM 的提案审查 `docs/team/reviews/writing-discipline-proposal.md`，逐条确认裁定点 1–7，结论摘进报告；
  与提案不同的裁定按它改写判定与措辞。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 抄**改动前**基线：四份文件的现状（`grep -ci 'answer the reader\|what it changed'` 在 templates/** 与
  references/** 全为 0）、`references/workflows.md` §E 的现有条目、`templates/report.md.tmpl` 的栏位清单（证明
  没有栏位被新增）、`references/openspec.md` 清单仍是十条。 · 证据：基线日志
- [ ] 0.3 本仓 `AGENTS.md` 的重渲染（**仅当任务书授权该文件**）：模板是源，`team_write_section` 就地刷新
  `<!-- teamsmith:begin -->`…`<!-- teamsmith:end -->` 标记块（幂等；只跑渲染，**不跑** `team init --force`）。
  未授权 → 报告写 `BLOCKED:` 并给出可复制的渲染命令交 PM。 · 证据：`git diff --stat -- AGENTS.md` + 标记块数量 = 1
- [ ] 0.4 记录门禁基线：`tests/section-select.sh --paths <四个文件>`（基线 `decision=RUN` / `sections=130` / `keys=28`，
  选集 `0 0b 0c 0d 2 4 4b 5 3b 6 6d 6e 6f 6i 7b 9 10 11 13c 14b 15b 15c 17 18 18b 19 33 12k`）、该选集的
  `smoke.sh --select`、`spec-refs.sh --check`、`openspec validate --all --strict`。若 `gate-lock-hygiene` 已落地
  （它写 `references/protocol.md` §9b）或 `main` 已前移：先 `git merge main`，冲突按双方保留（§9b 与 §11/§11b 不同节）。 · 证据：命令与输出尾

## 1 三处表面 + 评审读法（R1/R2/R3 的落面）

- [ ] 1.1 工人面 `templates/AGENTS.section.md.tmpl`：Non-negotiable discipline 里「范围/报告/磁盘交接」bullet
  之后加一条 bullet，含四条义务（先答问题再给证据 / 点名不到就删 / 边界只在带证据时声明且带了就留 / 发现写明
  改变了什么）与指向 `references/protocol.md` §11b 的一行。落点**避开**「The change is the assignment unit …
  while a sibling is unfinished.」（§12k 逐字比对）与车道三态 bullet；文本里不得出现 §13c 的退休短语
  （`before your turn ends` 等）；英文。 · 证据：改后段落原文 + `grep -c` 四条锚点
- [ ] 1.2 PM 面 `templates/pm-prompt.md.tmpl`：在 `## Talking to the user: a code never stands alone` 小节内、
  代号段之后加一段（同四条义务 + 诚实边界指向 §11b）；**不新开章节**、不动关键结论段（`key-replies` 的锚点
  全留）、不动代号段原文。 · 证据：改后段落原文 + `grep -c` 锚点
- [ ] 1.3 协议面 `references/protocol.md`：§11 之后加 `### 11b.` 子节（判据 + 短理由 + 诚实边界「no tool can
  verify …」）；§11 段落原文一字不动。 · 证据：`sed -n` 段落原文
- [ ] 1.4 评审面 `references/workflows.md` §E：加一段读法（每条发现写明改变了什么 / 没支撑的谨慎是待删项 /
  更长更防御不是更强证据 / 这是评审读法不是门禁）。**不碰** `references/openspec.md`（§12k 的
  `CHECKLIST-COUNT` = 10）。 · 证据：改后段落原文

## 2 不变量（R1 末句、R3 的「不设门禁」、R2 的「不加栏位」）

- [ ] 2.1 逐句核对删除项：列出本次 diff 删除的每一句，逐条说明它**没有**点名事实/缺口；列出留存的带证据边界句
  （至少：车道三态段、§12k 比对段、§11 代号段）。 · 证据：`git diff` 的删除行 + 判定表
- [ ] 2.2 证明门禁不持有它且未被改动：`git diff --stat` 只含四份文件（＋授权的 `AGENTS.md`）；
  新锚点词在 `skills/teamsmith/tests/` 里 `grep -rc` 命中 **0**；`smoke.sh --select <选集>` 全绿且与基线计数一致。 · 证据：`git diff --stat` + `grep` 输出 + 选集日志
- [ ] 2.3 证明没有把判据变成仪式：`templates/report.md.tmpl` 与 `templates/task.md.tmpl` **不在 diff 里**；报告形状
  无新增栏位（对照 0.2 的栏位清单）。 · 证据：`git diff --stat` + 栏位对照

## 3 对照（R4；建议独立席位在 verify 阶段执行，人读由用户或记录的代理完成）

- [ ] 3.1 **评分口径先落盘**：`compare/rubric.md`（五项 + 判定规则 + 「不用 AI 打分」的理由）在**派单之前**写出，
  记时间与哈希。 · 证据：文件 + 哈希/时间行 + 派单日志的时间戳
- [ ] 3.2 两臂构造：两个夹具项目，除那一条 bullet 外逐字相同（`diff -u` 只输出那一段）；同一份任务书（字节相同）、
  同一 `category:` 与模型、各自 `--fresh`；两边的 `state/dev.env` 模型相等；臂→标签映射写进 `mapping.sealed`
  （读前封存）。 · 证据：`diff -u` 输出 + 两份 env 片段 + sealed 文件的哈希
- [ ] 3.3 派单与收料：两个夹具各派一次；两份报告按掷硬币顺序复制成 `compare/arm-A.md` / `compare/arm-B.md`
  （除复制外零编辑）；任务书、夹具路径、模型、提交记进 `compare/README.md`。 · 证据：派单日志 + 两份 arm 文件
- [ ] 3.4 **人读**：用户（或用户明确委托 PM 代理并写明）按 rubric 填 `compare/sheet.md`，填完才解封 mapping；
  解封结果与两臂身份记进 `compare/README.md` 与复验记录。 · 证据：sheet + README
- [x] 3.5 判定：按 rubric 的规则给出「改写规则文本」或「保留原样」，写明样本限制（一个任务、一个读者）； · 证据：PM 作为**明确标注的代理读**填了 `pm-skills-ledger/team/reports/P286-dev-bob/arms-post-fix/sheet.md`：结论 **「规则按原样归档」**（两篇阅读难度 3/2，支持性判据与「发现带后果」两项均为 0，可删句 1/2，带规则那篇在同一证据上多指出一处实缺陷）；样本限制写明「一个任务、一个读者」，并如实标注**这次代理读不是盲读**（填表前已解封 `mapping.sealed`，属 PM 流程错误）。材料里**没有 AI 评分**（rubric 与 README 均明令禁止）
  材料里不得出现 AI 评分（`grep -riE 'score' compare/` 只应命中 rubric 里禁止它的那一句）。 · 证据：结论段 + `grep` 输出

## 4 验收与交付（apply）

- [ ] 4.1 跑齐 proposal「Acceptance」的命令（选集 + 全量 `smoke.sh` + `openspec validate --all --strict` +
  `spec-refs.sh --check` + `ledger-ban.sh` + 那段 `git diff --stat` 断言 + 投影自证），报告贴真实命令与输出尾（含 rc）。 · 证据：命令日志
- [ ] 4.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、第 2 节的三条不变量证据、**未测项**与
  已知风险。 · 证据：报告文件
- [ ] 4.3 小步提交（Conventional Commits + 任务 ID + `Agent:` trailer）；本仓 local 模式不推送；`team notify pm`
  一行交付说明。 · 证据：`git log --oneline` + 通知

## 5 独立验证（第三个席位；不是 apply 作者，不改实现）

- [x] 5.1 独立检出上把四个文件逐条对规格四条要求：每个面的义务逐条点名（缺哪条点哪条），复跑选集与 · 证据：V47 两轮在独立检出上逐条对过四个要求与五个发出面：`docs/team/reviews/V47.md`（第二轮 §2/§3，含 28 段选段）
  `spec-refs.sh --check`。 · 证据：复验记录 + 独立日志
- [x] 5.2 对抗一：从**副本**里删掉任一面的那一块 → 按规格 R3 的场景 2，判定必须失败并点名那个面；同时证明 · 证据：V47 第一轮做了该对抗：把三处规则文字全删 → 门禁照绿，并据此说明「文风靠评审、门禁守别的」是本变更的设定：`docs/team/reviews/V47.md` 第一轮 §5
  门禁在删掉前后**都绿**（「门禁不管措辞」是合同的一部分，不是漏洞）。 · 证据：两条运行输出
- [x] 5.3 对抗二：`templates/report.md.tmpl` 有没有被偷偷加栏位；`references/openspec.md` 的清单是否仍是十条 · 证据：V47 第一轮核过 `templates/report.md.tmpl` 未被加栏位、`references/openspec.md` 的清单仍是十条：`docs/team/reviews/V47.md` 第一轮 §4
  （§12k）；`scripts/**`、`extension/**`、`panel/**` 零改动；退出码/配置键零变化。 · 证据：`git diff` + §12k 输出
- [x] 5.4 对照材料复算：按 `compare/README.md` 的路径与命令重建两臂（或抽验其差异恰为那一段），核对 rubric 的 · 证据：V47 第二轮按 `arms-post-fix/README.md` 与 `fixture-correspondence.txt` 复算了两臂（含「两臂差异恰为那一段」与「与修订后模板逐字节相同」），并核 `mapping.sealed` 未泄露：`docs/team/reviews/V47.md` 第二轮
  时间/哈希早于两份报告、sheet 早于解封。 · 证据：复算输出
- [x] 5.5 判 `verification` 的正确性门：只按证据判；证据不足写明缺什么。 · 证据：复验记录 · 证据：PM 据证据判过（PASS，`docs/team/reviews/P286.md` 的合并记录）；人读那一步如实写成「代理读（已标注）」，样本限制随 sheet 一起记录
