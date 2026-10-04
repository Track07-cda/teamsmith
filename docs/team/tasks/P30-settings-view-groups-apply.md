# P30 · settings-view-groups apply（第 10 列 group + 功能域分组 + 行级 class + 滚轮）

```
task:   P30
agent:  dev-bob
issue:
change: settings-view-groups      # 提案已验收：docs/team/reviews/settings-view-groups-proposal.md（ACCEPTED）
specs:  panel#The settings view groups the contract by the schema row's domain / panel#Every key affordance is also a mouse target / memory-and-deps#The machine read reports each row's group
phase:  apply
anchor: change
deltas: panel, memory-and-deps
grant:  scripts/lib/cmd-config.sh · scripts/panel/src/**（App/layout/types/strings）· scripts/panel/panel.js（build 重建）· tests/config-cli.sh · tests/panel-strings.mjs · tests/panel-p21.sh（settings/groups/wheel 段）· tests/smoke.sh（§33/§38 附近 append-only）
deps:   P29（propose，已合并 328c062）· settings-choice-editors（已归档的直写/零读取基线——只读相邻，不许动）
status: todo
budget: 一个工作块；做不完交 PARTIAL
```

> 本地模式：不 push。**设计真源 = `openspec/changes/settings-view-groups/design.md`（D0–D8）+ tasks.md**；
> 以它们为准，尤其：D1（第 10 列）、D2（12 slug 与标签来源）、D3（顺序与降级）、D4（词+tone）、
> D5（自己的 offset + 消费事件）、D7（门禁与红侧）。

## 硬要求

1. **单一真源**：group 只在 schema 行里（第 10 个 `|` 字段）；`team config list --json` 逐字带上；
   键存在但 token 缺失/畸形 → 记录里空 + 视图落"未分组"可见降级（不消失）；schema 未知键同理；
2. **不许动已归档基线**：直写（dry-run→--yes）、交互路径零读取、危险值例外、「其他」路径、
   `choices` 字段语义——一个字不动；新字段只是**挨着** `choices` 多一个 `group`；
3. **颜色不做唯一通道**：行级 class 永远有**词**（`立即生效`/`重启生效`/`只读`），tone 是附加；
4. **滚轮**：设置视图有自己的 offset、事件**消费**（不穿透）；焦点键把聚焦行带回窗口内；
   b3 的三处既有 wheel（页面/泳道/详情）**不许回归**；
5. **FAST 不许塞慢 pty**：慢 scenario 进全量门禁；FAST 保留结构钉（§38-d 模式）；
6. **i18n**：12 个 group 标签 zh/en 双侧、`panel-strings.mjs` 双向核对（有键无标签 → 红）；
7. 每批 `TEAM_SMOKE_FAST=1 bash tests/smoke.sh </dev/null` 绿 + 小步提交（`wip:` 允许）。

## 必给的翻转（红→绿原始输出）

- 删掉某键的 group（或改畸形）→ `config-cli` 的 groups 段红（点名该键）；
- 把某键的 group 改到别的域 → 视图 headings/归属跟着变（证明视图不硬编码）；
- 去掉滚轮的"消费"→"滚轮不穿透"scenario 红；
- 去掉行级词只留 tone → "词+tone"那两条红；
- 删一个 group 标签 → panel-strings 红；还原后 bundle 两次构建字节一致。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
node skills/teamsmith/tests/panel-strings.mjs
bash skills/teamsmith/tests/config-cli.sh
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不改** `tests/panel-b3.sh`（它的三处 wheel 是参照，不是目标）；
- 不 push；不改 `docs/team/**`（PM 台账）；矛盾/歧义 → `BLOCKED:` 交回 PM，别自行扩大范围。

## Deliverables

- 实现 + 翻转证据 + 报告 `docs/team/reports/P30-dev-bob.md`（逐条对照 D1–D8 + 每条的翻转原始输出 + 全量门禁结果）。
