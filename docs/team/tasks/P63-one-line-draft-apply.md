# P63 · 单行草稿被读成空框（Pi 0.87 布局）——高优先级修复（propose+apply 一体，先给证据再改）

```
task:   P63
agent:  dev3
issue:
change: one-line-draft-judgement
specs:  -
phase:  propose
anchor: change
deltas: delivery-guard, notify-and-inbox
deps:   P61 的 F1（现场在 `docs/team/reports/P61-dev3/logs/15b-*.log`、`15d-*.log`）· M24/M45/M30 的投递守卫血统
status: todo
budget: 一个提案包（propose 先做；apply 另行派单）
overlap: ⚠️ 与 P55（dev，`cmd-status.sh` 末尾）无重叠；与 P60/P45 无重叠。你按 propose 走。
```

> 本地模式：不 push。**本单先只做 propose。**

## 事实（P61 实测，必须原样引用进提案）

- Pi **0.87.0** 的输入框是「上边框 / 内容行 / 下边框」，**状态行在框外**；
  0.85.1 时框内最后一行是框自带的状态行。
- 于是**单行草稿**落在 `OFFSET==1` 那一行——而 `team_input_box_text`（`outbox.sh`）与帧级判据
  （`tests/lib/box-judge.sh`）**按位置排除**这一行 → 判 `EMPTY`。
- **后果（两条，都有现场）**：
  1. 就绪门带单行草稿**放行并投递**（`15d-fixture-over-draft.log`：夹具 rc=0、`M45 idle-read=…`、
     keylog 收到 1 行输入）；
  2. **生产路径** `team_delivery_verdict` 同判 `EMPTY`、`team_box_holds_only` 返回空框语义
     → **payload 会被贴进人的草稿**（进入复检后才可能被判污染并收回）。
- **多行草稿不受影响**（`state=BUSY`、`holds_only` 正确）——F1 限定在"单行"这一形状。

## 要裁决的设计问题

1. **判据不能只看位置**：`OFFSET==1` 的排除要改成**按布局/内容识别**（例如"框内只解析到一行且非空 →
   认它是内容"；或识别框自带状态行的**形状**而不是它的**位置**），并给出**0.85.1 与 0.87.0 两版真帧**都通过的判定；
2. **两处判据必须同源**：`outbox.sh` 的 `team_input_box_text` 与测试侧 `box-judge.sh` 不许各改各的
   （一旦分叉，夹具会在生产已修的情况下继续骗人，或反过来）；
3. **红侧**：用 `15b/15d` 两份现场做**存下来的真帧**断言（单行草稿 → 必须 `HOLDS_ONLY=no`/`BUSY`，
   就绪门**不得**放行）；**绿侧**：真空框仍是 `EMPTY`、多行草稿仍是 `BUSY`；
4. **边界**：草稿内容恰好是 `Trust project folder?` 这类覆盖层文案（P61 的 F2）→ 给出裁决（倾向：**位置/结构优先**，
   文案匹配只作为降级信号），并把 F2 一起收口或明确写为"不修，理由"；
5. **不许**放宽"草稿在场就不投递"的既有红线（M24/M30）；**不许**把判据退化成"只要框里有字就 BUSY"而误伤覆盖层/空框。

## 硬要求

- policy B：delta 落 `delivery-guard`（判据语义）+ `notify-and-inbox`（投递路径的后果）——
  若你论证出更合适的家，写清理由；
- 每条 requirement 可证伪 + 给复核方法；**不写实现**；矛盾 → `BLOCKED:` 交回 PM。
