# P248 · Pulse：写信槽与只读预览（propose）

task: P248
agent: dev2
phase: propose
category: analysis
change: panel-preview-and-compose
specs: panel
deltas: panel
branch: task/P248-panel-preview-propose
deps: -

## 用户报的三件事（原话）

> 1. 写信的消息发送后，清空输入框
> 2. 可预览 spec 和 变更详情
> 3. 可预览决策详情

PM 已核对第 ① 条**是真缺陷**：`skills/teamsmith/scripts/panel/src/main.tsx` 只在 489/497 行读写 `state/draft.md`、在 556 行把草稿文件交给 bridge 发送，**发送成功后没有清空草稿**——所以输入框里还留着刚发出去的正文（磁盘草稿也还在）。现有行为下用户要手动全删，否则下一次发送会把旧文重复发出。

②③ 是**新的只读面**：在 Pulse 里看 OpenSpec 的规格与变更详情、看 `docs/team/DECISIONS.md` 的条目详情。

## 本阶段要产出什么（只写提案，不写实现）

一个 OpenSpec change：`openspec/changes/panel-preview-and-compose/{proposal.md,design.md,tasks.md}` 与 `specs/panel/spec.md` 的 delta。要求：

1. **草稿生命周期**写成**可证伪的合同**，至少覆盖：发送成功（收到 `ok` 类回执）→ 草稿清空（内存与磁盘一致）；发送失败 / 未确认（`unconfirmed`）/ 队列忙（busy）→ **草稿保留**（不能因为一次失败丢掉用户打的字）；用户手动清空的既有入口不受影响；重启后**残留草稿**的行为要说清（在发送成功后被清掉的前提下，重启后应当没有"幽灵草稿"）。写清这与既有「草稿跨重启保留」意图的关系（那意图是**发送之间**保留，不是发送之后）。
2. **只读预览**的合同：能在面板里读到 ①`openspec/specs/<capability>/spec.md`、②`openspec/changes/<id>/` 的 proposal/design/tasks、③`docs/team/DECISIONS.md` 的**单条决策**（按决策号定位到条目正文）。必须**复用**既有的读取与展示机制（有界块 + 详情视图 + 安全展示路径），**不许**为预览新造第二条文件读取/渲染路径；路径只许落在被允许的根内（规格与变更在 `openspec/**`、决策在账本面），**不许**接受任意路径或跟随软链；坏源 / 缺文件 / 超长正文要有明确行为（有界、可见、不崩）。
3. **入口与体验**：用户怎么到达这三个面（页/键位/在被引用处跳转），要在 design 里给出取舍（新开第六页 vs 在既有页里开详情 vs 从别处的引用跳过来），并说明与既有四/五页导航、宽窄屏降级、主题、i18n 的关系。**不要**为预览引入写操作。
4. **tasks.md 分阶段**：apply 阶段一个席位能顺序完成；verify 阶段要点名「每条合同配什么红侧」（例如：发送成功后草稿仍在 → 必须红；把预览指向规格根之外的路径 → 必须拒绝并点名；正文超长/坏源 → 有界且可见；旧四页程序读到新页 → 既有 fallback 不崩）。
5. **范围边界**：本 change **不**动路由/派单/账本写入、不改 `team reply`（关键回复在另一个 change，已归档）、不引入新依赖；只碰面板面与它读的既有数据面。

## 现场（写进 proposal 的 evidence 段，自己复核一遍）

- 缺陷：`skills/teamsmith/scripts/panel/src/main.tsx:489,497,556`（读/写/发送草稿，**无删除**）；`compose.ts:18-19` 定义 `DRAFT_FILE = 'draft.md'`。
- 既有可复用机制：`panel/src/data.ts` 的块协议、`panel/src/main.tsx` 的详情视图路径、关键回复第五页（`docs/team/reviews/V27.md` 第三/五节）是最近一次同类实现的范本；规格 `openspec/specs/panel/spec.md` 里已有「详情视图 / 有界异步块 / 安全展示」的既有条款，delta 要**与它们对齐**而不是另立一套。
- 真面板取证：可参考 `tests/key-replies-ui.sh` 与 `tests/key-replies-pty.sh` 的做法（真 bundle + 真 pty + 私有 tmux server），提案里要给 verify 阶段留下可执行的取证方式。

## 验收（本阶段）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/P248-dev2.md
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

每条 MODIFIED requirement 必须与基线逐场景对照、不许丢场景；新增场景要写得出红侧。做完 `team notify pm`，PM 复核后再派 apply（**写的人不验自己的活**，apply 与 verify 会是不同席位）。
