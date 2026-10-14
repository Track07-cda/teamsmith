# V34 · 通知合并（C-1 + 挂起不敲门）独立复验

task: V34
agent: dev2
phase: verify
category: verify
change: turn-notice-merge
specs: notify-and-inbox
deltas: -
branch: task/V34-turn-notice-verify
deps: P251（apply 已交付，冻结 tip 见派单消息）

## 复验对象

`turn-notice-merge` 的 apply：回合结束通知的合并（同一席位+任务+状态类+`awaiting` 集合并一行、`×N first= last=`、明细落 `state/notify.log` 且先明细后合并）+ **范围追加：挂起只记录不敲门**（`[auto·suspended]` 写行与明细但不入队不唤醒；`[auto]`/`[auto·interrupted]` 照旧敲门）。被检树：PM 冻结的独立 clone（tip 见派单消息）。设计在 `openspec/changes/turn-notice-merge/design.md`（§6 敲门、§8 合并行形状、§9 被否决的替代、§11 红侧）。

## 必须自己做的（不许只复跑作者脚本）

1. **合并键与显示**：自造现场——同一席位、同一任务、同一状态类、同一 `awaiting` 集合连续来三条 → 收件箱**只留一条**、行上带 `×3` 与首末时间、明细里有三条；不同任务/不同席位/不同状态类各自**不合并**。
2. **叫醒规则**（本次的重点）：自造三类事件并核对敲门——交付（`[auto]`）敲门、中断（`[auto·interrupted]`）敲门、**挂起（`[auto·suspended]`）敲门队列为空**但收件箱行与明细都在；同键再来一条（合并）不敲门；挂起 → 交付或中断的**状态类变化**要敲门。每条都给「敲了/没敲」的可证伪证据（敲门队列入队与否）。
3. **明细兜底**：明细缺失/被轮转/写入失败 → **可见**（点名缺口）而不是静默；`--detail` 缺文件非零退出且点名、不 ack。轮转上界（2048 事件/只留一代）至少验一次边界。
4. **既有读者零改写**：digest、面板、未读计数、`--ack` 都按行算；合并行不得冒充当前状态（陈旧判据仍按行内字段逐事件解析，不能拿旧任务的通知当当前状态）。
5. **兼容承诺**：单事件行与改动前**逐字节相同**（既有 `suspend-shape`/`owner-scope` 断言就是守卫——你要自己跑一次确认它们仍绿）。
6. **不削弱既有断言**：逐条看 `bg-ledger.sh`/`bg-ledger-harness.mjs`/`smoke.sh`/`section-paths.tsv` 的 diff——是新增/修正还是删断言换跳过；新增的跳过要有名有理由。
7. **容器纪律**：夹具在钉死容器 + 干净独立 clone 里跑；真 tmux 只用私有 socket；先看 `/tmp` 余量。
8. 任何「既有红」的说法必须同命令对照 **v0.2.0（tag `v0.2.0`）**。

## 交付

`docs/team/reviews/V34.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外 `pm-skills-ledger/team/reports/V34-dev2/`；不改候选、不合并、不推送；结论按协议通知 PM。
