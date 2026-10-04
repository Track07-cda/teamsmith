# P67 · one-line-draft-judgement apply：光标锚定 + 边框配对 + "紧贴下边框那行按内容读"

```
task:   P67
agent:  dev3
issue:
change: one-line-draft-judgement        # 提案已验收：docs/team/reviews/one-line-draft-judgement-proposal.md
specs:  delivery-guard#An automated send never types into a non-empty input box / notify-and-inbox#Messages to a stopped agent fall back to the inbox
phase:  apply
anchor: change
deltas: delivery-guard, notify-and-inbox
grant:  skills/teamsmith/scripts/lib/outbox.sh · skills/teamsmith/tests/lib/box-judge.sh · skills/teamsmith/tests/frames/（新增 0.87 单行草稿帧等）· skills/teamsmith/tests/pm-box-real.sh · skills/teamsmith/tests/smoke.sh（append-only）
deps:   P63（propose，已合并）· P59（同一条判据的覆盖层分支）· M24/M30/M45 的投递守卫血统
status: todo
budget: 一个工作块（B1 判据重写 + 帧 / B2 两处同源接线 / B3 夹具与翻转）
priority: **高**（投递安全：现状是 payload 可能被贴进人的草稿）
overlap: ⚠️ `smoke.sh` 同时被 P64/P62/P56 碰；新段加在文件末尾（下一段号自己看当前最大号 +1）。
```

> 本地模式：不 push。**真源 = `openspec/changes/one-line-draft-judgement/{design.md,tasks.md}`。**

## 硬要求

1. **光标锚定**：上下边框按**光标行**找；顶边框 = **等宽整行**或 **spinner 形状行**；
   **多个候选取最靠下**（草稿自画的分隔线不许冒充边框）。
2. **F1 的正解**：**紧贴下边框那行按内容读**，只有**同时**满足"光标不在该行"且"文本匹配状态行形状"才判为框自带状态行。
3. **检查框内每一行**（不只看光标及以上）。
4. **spinner 行不作边框候选**，并保留"未来 TUI 若提升为顶边框"的降级路径与告警。
5. **两处判据同源**（`outbox.sh` 与 `box-judge.sh` 不许各改各的）。
6. **红/绿两侧**：存下 **Pi 0.87 的单行草稿帧**（红侧：旧判据判 EMPTY、新判据判 BUSY/held）+
   **0.85.1 的真帧**（不许回退）+ 真空框仍 EMPTY + 多行草稿仍 BUSY + 覆盖层仍 overlay。

## Acceptance

```sh
bash skills/teamsmith/tests/pm-box-real.sh --expect-overlay
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
