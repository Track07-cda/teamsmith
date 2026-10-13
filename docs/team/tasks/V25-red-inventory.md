# V25 · routing 合并后的全量红清单与分类（只读诊断，不修）

task: V25
agent: verify
phase: verify
category: verify
change: -
anchor: none (infra) — 只读诊断：给合并后 main 的每一条红定性并给出修法归属，不做任何修改
deltas: -
branch: task/V25-red-inventory
deps: 只读；不得改产品/测试/规格（只写你自己的报告）

## 背景（PM 已确认的事实）

`task-model-routing` 并入 main（`e897a7d`）之后，**上一次全绿的全量门禁是 v0.1.2 的 `69692a6`（✓4653 ✗0）**，而合并后的完整门禁在钉死容器里跑出 **20 个段带红、合计 157+ 条**（PM 的作业日志：`/tmp/ljs-gate.log`，原始带颜色；`/tmp/ljs-gate-clean.log` 是去色副本，作业完成时生成；冻结克隆留在 `/tmp/ljs-gate`，detached 在合并 tip `14499ed`）。已知的几个例子：

- **夹具 brief 缺 `category:` 头 → 派单被新合同拒发 → 级联红**：`§41`（P55 pane 留存）`✗69`，第一条就是 `P55 ①：派单失败`；同族还有 `§32⑧c ✗2`、`§11c up --agents ✗2`。拒发原文 `cmd-agents.sh:1116 brief 必须唯一 category: header；显式 override 不豁免`。
- **适配器/提示词文本类**：`§6f ✗21`、`§6g ✗14`、`§6h ✗15`、`§6i ✗3`、`§6j/6k ✗1 ×2`——断言在渲染出的提示词里找不到旧句子（`Notify the PM when your turn ends`、`not Pi`、摘要文件路径、`no substitutions…`、敌意摘要逐字送达等）。
- **`§12g/12h/12i`（change 锚点 / delta 单写者 / 独立性）`✗7/✗13/✗4`**、`§22 ✗16`、`§15b ✗5`、`§25 ✗3`、`§26 ✗2`、`§31 ✗1`、`§31c ✗6`、`§36 ✗1`、`§11b3/11b4 ✗1 ×2`。
- 另有 PM 自己的对照教训：**选段闭包不同会造出假红**（`--select 11c` 单独跑在 v0.1.2 上也有 8 红；加前置 `6,13,32,11c` 后 v0.1.2 是 `✓230 ✗1`）。所以分类时**必须**在同一选集/同一前提下对照 v0.1.2。

## 你要交付的东西

一张**逐条分类表**（CSV + 报告里的可读表），覆盖全量门禁里**每一条红**，每条给出：

| 字段 | 说明 |
|---|---|
| section | 段号与段名 |
| assertion | 断言原文（截断到可辨识） |
| class | `A` 夹具/期望需按新合同更新（行为是意图内的、规格已写）；`B` 产品真回归（行为与已接受规格冲突或丢失既有功能）；`C` 未归档状态造成的假红（例如 `task-model-routing` 的 delta 已并入 main 但 change 未归档，导致 12g/12h/12i 类检查判红）；`D` 选段闭包/顺序/环境假红（同一前提在 v0.1.2 上同样红） |
| evidence | 你对 v0.1.2（`/tmp/base012`，`69692a6`）与合并 tip（`/tmp/ljs-gate`）的**同命令**对照结果（贴数字） |
| spec | 你判定「意图内」时引用的规格/契约位置（change 的 delta 或 canonical spec 的 requirement 名）；判定 `B` 时引用被违反的既有 requirement |
| owner | 修法落在谁的写集合：`tests/smoke.sh` 或 `tests/section-paths.tsv`（当前 P238 持有）、`scripts/lib/**`、`references/**`、`templates/**`、`openspec/**` |
| fix | 一句话修法（例如「夹具 brief 加 `category: routine`」/「把断言改成新措辞 X」/「恢复 dry-run 清单行」） |

另附两节：

1. **总量与分布**：按 class 与 owner 汇总（`A: n`、`B: n`、`C: n`、`D: n`），并给出「哪些段在修完 A/D 后应当全部转绿」的预测。
2. **红是否为真**：对每条 `B` 给一个**最小复现**（容器里、单段、可重跑的命令 + 期望/实际），因为它们是必须修产品的部分。

## 规矩

- **只读**：不修改仓库任何文件（除你自己的报告 `docs/team/reports/V25-verify.md`），不写测试、不改规格、不合并、不推送。夹具/前置若需要，写在 `/tmp` 或仓外。
- 跑门禁一律在钉死容器 + 干净 clone 上（`git clone --no-local . /tmp/<dir>` + `distrobox-host-exec podman run … localhost/teamsmith-gate:local`），不要在工作树里跑。
- 对照**必须同命令**（同一 `--select`），否则记成 `D` 并说明。
- 不确定就写「未定」，并给出你还需要什么证据；**不许把不确定归成 A**（那是把缺陷洗成夹具问题）。

## 交付

`docs/team/reports/V25-verify.md`（分类表 + 汇总 + 每条 B 的最小复现）；机器可读的 CSV 放仓外 `pm-skills-ledger/team/reports/V25-verify/`；做完 `team notify pm`。PM 依据它拆修复任务（一个 owner 一条线，串行改同一文件），修完再由你或另一席位在容器里跑全量确认转绿。
