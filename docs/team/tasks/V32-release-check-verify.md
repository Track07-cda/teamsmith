# V32 · P247（发布检查：tag 选法与 init 路线）独立复验

task: V32
agent: dev-bob
phase: verify
category: verify
change: -
anchor: none (infra) — 复验发布前检查工具的判据修正
deltas: -
branch: task/V32-release-check-verify
deps: P247（apply 已交付，冻结 tip 见派单消息）

## 复验对象

P247 修了 `docs/team/tools/release-check.sh` 的两处陈旧（任务书 `docs/team/tasks/P247-release-check-stale.md`）：① 「最新 tag」改为只看 **HEAD 可达** 的 tag，另打印「不在 HEAD 历史上的 tag」异常提示（不判红）；② 安装路线第 3 条（`team init`）按 routing 之后的合同传入 `--task-models`/`--pm-model` 并断言新形状落盘。

PM 已自己的核过（记录在派单消息里）：候选工具对着**真仓**跑出 `⚠ 旧 tag 异常：29 个 tag…` + `✓ 最新 tag v0.1.2 = package.json` + 唯一红「HEAD 领先 v0.1.2 78 个提交」；自测 `A 4/4`、`B tag 判据 4/4`。**你要独立复现，不要引用我的数字。**

## 必须自己做的

1. **可达性判据**：在**你自己的** scratch git 仓里造 tag（含 annotated 与 lightweight 两种）——一个可达且版本最高、一个可达但版本较低、一个**不可达**且版本最高（例如 `v9.9.9`）——确认工具选中的是「可达里版本最高的那个」，且不可达那个只出现在异常提示里（**不改判定**）。再让 HEAD 与选中的 tag 错位 / 重合，确认那条红的绿的变化符合原意。**顺带确认 annotated tag 走的是 `^{commit}` 而不是 tag 对象 sha**（造一个指向 tag 对象的边界）。
2. **异常提示不能假报或漏报**：真实仓里应当是 **29 个**（PM 数的，自己数一遍并对照 `git for-each-ref`/`merge-base` 的自算结果）；提示文案必须点名「不要 `git push --tags`」。
3. **init 路线**：确认它**真的**用发布包里的 `team` 跑 init、且断言了「两个技能软链逐字节相同 + 项目内 `team help` 退出 0 + `TEAM_TASK_MODELS`/`TEAM_PM_MODEL` 落盘且值等于传入」；红侧：把传入参数去掉（或把 `--pm-model` 换成不存在形状）→ 该路线必须红（不是静默通过）。**并确认这条路线没有碰真实的 `~/.agents/skills`**（它应当 `HOME="$INST/home"` 隔离；用你自己的 `HOME` 变量观察或读码确认并写清）。
4. **自测有牙**：`--self-test` 两个组都自己跑（A 组四条变异 + B 组 tag 判据 4/4）；确认 B 组的红侧不是橡皮章（例如把可达性判据改成「不过滤」→ B 组必须红）。
5. **不假阳**：在真仓上跑（用 `--root` 指向真检出并传真名单）→ 唯一红必须是「HEAD 领先可达最新 tag」那一条，其余全绿、无跳过（名单缺失导致的跳过要如实区分）。
6. 纪律同本项目惯例：不改候选、不合并、不推送；不改真实仓状态（不建/不删 tag，scratch 里随便造）。

## 交付

`docs/team/reviews/V32.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V32-dev-bob/`；结论按协议通知 PM。
