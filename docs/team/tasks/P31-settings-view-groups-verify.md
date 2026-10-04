# P31 · settings-view-groups 独立验证（verify 阶段）

```
task:   P31
agent:  dev2
issue:
change: settings-view-groups      # propose=P29（dev-bob）· apply=P30（dev-bob）→ verify 必须换人（D31）
specs:  panel#The settings view groups the contract by the schema row's domain / panel#Every key affordance is also a mouse target / memory-and-deps#The machine read reports each row's group
phase:  verify
anchor: change
deltas: panel, memory-and-deps
grant:  docs/team/reports/P31-dev2.md · docs/team/reports/P31-dev2/**（只写报告与证据，不改实现）
deps:   P29 · P30（已合并）· settings-choice-editors（已归档的直写/零读取基线）
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。**破坏性夹具纪律**：真实 tmux 只许私有 socket；默认 server 的破坏性调用一律拒绝（M67 之后的语义）。

## 要对抗性验证的六条（每条给可复现命令 + 原始输出）

1. **单一真源**：`team config list --json` 的 `group` **逐字**来自 schema 第 10 字段（自己解析 schema 行比对，别信实现自己的输出）；
   未知键/缺 token/畸形 token → `""` + 视图落可见降级（不消失）；
   **视图不硬编码**：把某键的 group 改到别的域（临时副本）→ 视图归属跟着变。
2. **不按生效类分组**：视图 headings 是功能域名（12 个），**不是** apply/restart/refuse；
   组内顺序 = 读的顺序（不是字母序/视图规则）。
3. **颜色不做唯一通道**：每行的 class 是**词 + tone**；只用 tone 的变体（临时副本）必须让断言红。
4. **滚轮（用户痛点）**：设置视图自己的 offset、**事件消费**（背后页面不动）；焦点键把聚焦行带回窗口内；
   b3 的三处既有 wheel（页面/泳道/详情）不回归。
5. **基线未被动**：已归档 `settings-choice-editors` 的行为——直写 argv 序列（dry-run→--yes）、
   交互路径零读取、危险值例外、「其他」路径——**逐条重跑**并贴结果（这是"相邻只读"的证据）。
6. **i18n 与门禁**：12 个 group 标签 zh/en 双侧；`panel-strings.mjs` 双向核对；FAST 里有结构钉、
   慢 pty 在全量门禁（不许偷偷搬进 FAST 或反之）。

## 变异（至少两条，红→绿原始输出）

- 改掉某键的 group token → config-cli/groups 段红（指名）；还原绿；
- 去掉滚轮的"消费"（把事件放行给页面）→ 不穿透 scenario 红；还原绿；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/smoke.sh </dev/null
node skills/teamsmith/tests/panel-strings.mjs
```

## Boundaries

- **不改实现**（`scripts/**`、`tests/**` 一律不改）；缺陷写清楚交回 PM；
- 变异只在临时副本；不 push；不改 `docs/team/**` 里 PM 的文件。
