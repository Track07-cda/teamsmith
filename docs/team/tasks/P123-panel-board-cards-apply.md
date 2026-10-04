# P123 · 看板显示层（apply）：卡片只留序号+标题，车道可折叠

```
task:   P123
agent:  dev3                     # 提案作者是 dev2（D31：换人）· 复验还需第三方
issue:
change: panel-board-cards        # 提案已 ACCEPTED 并合入 main（`docs/team/reviews/P121.md`）
specs:  panel#A lane folds from its header, and empty lanes fold by default · panel#The board page is a kanban over the board's states · panel#Every key affordance is also a mouse target
phase:  apply
anchor: change
deltas: panel
grant:  skills/teamsmith/scripts/panel/** · skills/teamsmith/tests/panel-*.sh · skills/teamsmith/tests/smoke.sh（append-only 一段）· docs/team/reports/P123-dev3.md · docs/team/reports/P123-dev3/**
deps:   `openspec/changes/panel-board-cards/`（提案 + design）· P18/V18（有界帧 + 内存承诺）· P20（键位与鼠标同权）· P32（设置视图）
status: todo
budget: 一个工作块（内部分批）
priority: 中高（用户点名；纯显示层，零契约影响）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。**提案里的场景就是验收标准** ✓（`openspec/changes/panel-board-cards/specs/panel/spec.md`）。

## 分批（每批一个可验证的提交）

- **B1 · 卡片主行**：卡片行改 `游标+字形+序号+标题` ✓；agent/阶段**移出卡片** ✓ → 进入**聚焦卡片**在**底栏**的显示 ✓；
  **降级序**照 design 只写一遍 ✓，并实现成"**不存在**为留住 agent/阶段而截标题的宽度" ✓✓；窄档（含**单列合并档**）行为照基准 ✓。
- **B2 · 车道折叠**：车道头可折叠 ✓（折叠 = **一行**含计数 ✓、**不建卡片行** ✓）；**空车道默认折叠** ✓（`boardEmptyFold` 可关 ✓）；
  **未折叠车道分到被让出的宽度** ✓（design 的宽度算法 ✓）；**机器帧忽略折叠** ✓✓。
- **B3 · 键位/鼠标/持久化**：`c` 键 ✓ + 车道头**点击** ✓ + 折叠车道上的**滚轮** ✓（与既有键位不冲突 ✓、页脚提示 ✓、中英双语 ✓）；
  折叠状态写入 `state/panel.conf` ✓（**重启后面板仍生效** ✓、"显式展开会粘住" ✓）。
- **B4 · 夹具与红侧**：为每条新场景准备断言 ✓ + **每条都有红侧** ✓（至少：把降级序倒过来 → 标题先被截 → 红 ✓；
  折叠仍建卡片行 → 有界帧断言红 ✓；折叠状态不持久化 → 重启断言红 ✓；机器帧受折叠影响 → 红 ✓）。

## 硬约束

1. **不许改**状态 id/语义 ✗、数据源与 `team __panel-data` 契约 ✗、有界帧/内存承诺 ✗（折叠**不渲染**卡片是其保证 ✓）；
2. **不许**让折叠/展开破坏既有交互：`←/→` 换道 ✓、`↑/↓` 走卡片 ✓、`Tab` 翻页 ✓、详情页返回 ✓（折叠车道上的聚焦卡要有界 ✓）；
3. **必须**给**用户看到的那件事**留证据：在 **190×49** 与一个窄尺寸（如 60 列 ✓）各拍一份**渲染前后对照** ✓
   （卡片行文本 + 折叠一行 + 未折叠车道宽度 ✓），贴进报告 ✓。

## 验收

`openspec validate --all --strict` ✓ · 相关段落（`panel-*` ✓）全绿 ✓ · **FAST 全绿** ✓ · 报告写清"哪些场景由哪条断言覆盖 + 红侧原始输出" ✓。
