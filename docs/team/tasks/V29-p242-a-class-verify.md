# V29 · P242（A 类 210 条按新合同转绿）独立复验

task: V29
agent: verify
phase: verify
category: verify
change: -
anchor: none (infra) — 对夹具/期望更新做独立复验（不改产品、不写规格）
deltas: -
branch: task/V29-p242-verify
deps: P242（apply 已交付；受门禁树 = `4cb980f7`，其后只有报告提交）

## 复验对象与要证伪的核心主张

P242 的交付声明（`docs/team/reports/P242-dev-bob.md`）：① 按 `docs/team/reports/V25-verify.md` §3 的 A1–A9 聚类把 **210 条 A 类红全部转绿**，**产品代码一行未动**；② 每个聚类都有红绿对照；③ 另有 8 处同族陈旧夹具一并修；④ A9 的隔离 lint 双向都验；⑤ **合并树 `4cb980f7` 的全量门禁 `✓4727 ✗0`**。

你要做的是**自己把它跑出来**（不是复核它的日志），并**主动找反面**：有没有把断言削弱、换成跳过、或把判据放宽来换绿。

## 必须自己做的

1. **全量门禁自己跑一次**：钉死容器 + 干净独立 clone（`git clone --no-local`，detached 到受检树），记 rc 与 `== 结果 ==` 行；`/tmp` 先看余量（15 G tmpfs 常被别的任务占）。**这一跑要包含 §61 与 §61b（live，约 82 分钟）**——因为「全绿」的声明必须包含变异套件真的跑过；若你的运行把 §61b 跳过，这一份就不能作为「全绿」证据（如实记）。
2. **不削弱断言（结构审计）**：审计 `main..受检树` 里 `skills/teamsmith/tests/**` 的 diff：
   - 统计**删除**的行里有多少含断言（`check`/`assert`/`✗`/`t_*` 之类）——作者报告说 0，自己数；
   - 新增的 `skip`/`fast_skip`/`SKIP` 各在哪一段、理由是什么、在 live 里是否真跑；
   - 抽 3 个聚类（你挑，建议 A1 brief 的 `category:`、A3 换模型必须 `--fresh`、A9 隔离 lint）逐条对着 `openspec/changes/task-model-routing/tasks.md` §1–§7 与 canonical/delta 的原文核对：**新断言是否至少和旧的一样严**（例如旧断言检查「有诊断」、新断言只检查「rc≠0」就是削弱）。
3. **产品面无改动**：`git diff --stat main..受检树 -- skills/teamsmith/scripts skills/teamsmith/extension skills/teamsmith/panel skills/teamsmith/templates skills/teamsmith/references skills/teamsmith/bin package.json` 必须为空；若有改动，逐条判是否属于本任务范围（例如为夹具可测性而动的产品代码＝越界）。
4. **A9 的牙**：把 `tests/lib/tmux-iso.sh` 的包装去掉一处（或把某个 `routing_fixture_tmux` 调用改回裸 `tmux`）→ 隔离 lint 必须**红并点名该文件**；还原后绿。
5. **反向证据（最重要）**：抽 2 条被「修好」的红，用**你自己的方式**证明新断言确实能咬住真正的回归——例如把对应的产品行为在 scratch 副本里破坏（或在夹具里植入旧形状），期望该段变红；而不是只在夹具层面等价替换。
6. **清单对齐**：把 `docs/team/reports/V25-verify.md` §3 的红项清单与你现在跑出的结果对齐（哪一条现在绿了、有没有清单外的段现在红了）。V25 说 224 条里 A=210、B=14（B 已由 P240/P241 修）——你要给出「全量红 = 0」是否与这份清单自洽。
7. 基线纪律：任何「这条红是既有红」的说法必须在**同一条命令**下对照 **v0.1.2（tag）**；容器纪律：真 tmux 只用私有 socket。

## 交付

`docs/team/reviews/V29.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；**你自己那一次全量门禁的结果行**；结构审计的数字；反向证据；写明运行模型与负载）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V29-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
