# P250 · 回合通知的合并（C-1）：propose

task: P250
agent: dev3
phase: propose
category: analysis
change: turn-notice-merge
specs: notify-and-inbox
deltas: notify-and-inbox
branch: task/P250-turn-notice-merge-propose
deps: -

## 背景（用户已采纳，2026-10-14）

**C-1（候选提案收件箱的第一条，状态已改为「采纳」）**：席位每次回合结束自动写一条自我状态行，落在**该席位自己的收件箱文件**里，同时敲 PM 一下。实测噪声（今天的行数）：`verify` 71 行其中 46 条这类、`dev` 48/33、`dev3` 43/31、`dev2` 35/24、`dev-bob` 26/20；我（PM）的未读一度到 **93**。绝大多数是同一任务上「挂起 → 复活 → 再挂起」的重复轮次。

真实样貌（两行）：

```
- 2026-10-13T22:47:59Z [auto·suspended] agent:dev · P245 · branch=task/P245-… · uncommitted=0 · awaiting=P245-routing-recheck · unpushed=56(no-upstream) · task=P245 tip=…
- 2026-10-13T23:02:32Z [auto] agent:dev · P245 · … · unpushed=59 · task=P245 tip=8028cb489ffb :: P245 交付完成…
```

**用户批准的做法（我的推荐，也是本提案要落的合同）**：**带兜底的合并**——
- 只在**同一席位 + 同一任务 + 同一状态类 + 同一 `awaiting` 集合**内合并，显示「×N」加**首末时间**；
- **每一条原始事件照样写进一个明细文件**（`state/notify.log`，有界、**不进收件箱**）；
- **状态类一变立刻新起一条并叫醒 PM**（不是只在计数变化时叫醒）；
- 跨席位、跨任务、跨状态类**永不合并**。

## 你要产出的东西

一个 OpenSpec change：`openspec/changes/turn-notice-merge/{proposal.md,design.md,tasks.md}` 与 `specs/notify-and-inbox/spec.md` 的 delta（该能力现有多条 requirement 涉及通知的写入、陈旧判据与叫醒，delta 要与它们**对齐**而不是另立一套）。至少覆盖：

1. **合并键与显示**：键的四个分量（席位、任务、状态类、`awaiting` 集合）各自怎么取、怎么规范化（例如集合顺序不影响键、空集与缺字段的区别）。合并后的行形状（保持既有前缀词汇 `[auto]`/`[auto·suspended]`/`[auto·interrupted]` 与字段 `task=`/`tip=`/`branch=`/`awaiting=`/`uncommitted=` 不变，新增计数字段与首末时间），以及**既有读者**（陈旧判据、面板、`team digest` 的分类）读到合并行时的行为——**合并行不得冒充「当前状态」**，陈旧判据必须仍能按行内字段逐事件解析。
2. **明细文件**：路径、格式（一行一事件，含原始字段）、**有界策略**（轮转或按宿主/大小截断，缺文件、被轮转、写入失败都要**可见**而不是静默），以及它与收件箱行的关系（收件箱是摘要，明细是原始记录）。
3. **叫醒语义**：什么时候叫醒 PM——**状态类变化**（例如 `delivered`→`suspended`、`suspended`→`interrupted`、出现新任务）必须叫醒；**同类计数抖动不叫醒**（这是巡检叫醒键那次（P174）的教训）；合并发生时用哪种入口（更新既有行 vs 追加新行）写清。
4. **不变量**：跨席位/跨任务/跨状态类不合并；`uncommitted`/`unpushed`/`tip` 等字段在合并行里取**最后一条**的值并注明它是最后一条（不是"合并"出来的假值）；`[manual]`/`[draft]`/`[nudge]` 三类通知**完全不受本变更影响**。
5. **红侧**（每条合同都要给）：同类连续三次 → 只留一条并标 ×3、明细里三条都在；状态类变化 → 新行 + 叫醒；不同任务或不同席位 → 不合并；同类计数抖动（同键再来一条）→ **不**叫醒；明细文件缺失/被轮转 → 可见提示而不是静默；陈旧判据在合并行上仍逐事件解析（不能把旧任务的通知当当前状态）。

## 边界

- 本变更只碰**通知写入与收件箱/明细**这一面（实现面大概率是 `extension/team-notify.ts` 与 `scripts/lib/` 里的收件箱写入口 + 门禁登记）；**不碰**：敲门的传输机制、巡检叫醒键（P174 已治）、关键回复页（已归档）、派单/路由/账本写入、`team reply`。
- 不改 `[auto*]` 前缀词汇与既有字段名（它们是既有读者的输入）。
- 别在提案里植入对「谁该被叫醒」的猜测——叫醒规则要写成可证伪的判据。
- 只写提案；apply 与 verify 另行换人（写的人不验自己的活）。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P250-dev3.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

每条 MODIFIED requirement 必须与基线逐场景对照、不许丢场景；新增场景要写得出红侧。做完 `team notify pm`，PM 复核后再派 apply。
