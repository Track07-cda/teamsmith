# P101 · 席位死因：分类 + 一次通报（额度/余额/限流/窗口/正常/未知）

```
task:   P101
agent:  （等席位）
issue:
change: agent-death-reason
specs:  -
phase:  propose
anchor: change
deltas: watchdog, panel, notify-and-inbox
grant:  openspec/changes/agent-death-reason/**
deps:   D46（我 09-22 记下的缺口：死因只在 pane 里）· 用户 2026-09-28 的问题（截图：kimi 5 小时额度
        `403 permission_error … usage limit … quota` 打死一个 worker，pulse 只说「停了的 agent」）
        · P49/P55（死 pane 遗体 + `pane_dead` 证据已存在）· M6.5（存活判据是"证明"，本任务**不改**它）
status: todo（等席位；**先 propose**）
budget: 一个提案包
```

> 本地模式：不 push。**本任务只 propose**（apply 另行派单）。

## 现状（我 grep 核过）

- **有**"它停了/被打断"：通知扩展标 `[auto·interrupted]`（`extension/team-notify.ts:339`）；死 pane 留遗体与
  `dead|status|signal|time`（`cmd-agents.sh:446`）；pulse 报"停了的 agent N"。
- **没有**"为什么"：全仓库 `usage limit / quota / 额度 / insufficient / permission_error` **零命中**；
  原因只存在于 **pane 画面**（我去翻过两三次）。
- **没有** fallback（本任务**不做**，见 Non-Goals）。

## 要做的（提案阶段给出设计、取舍与可证伪）

1. **死因分类（闭集，绝不编造）**：`quota`（额度/用量上限）· `balance`（余额不足）· `rate_limit`（限流）·
   `window`（上下文超窗）· `auth`（凭证/权限）· `normal`（正常退出）· `unknown`（**匹配不上**）。
   判定只读**有界尾部**（例如最后 N 行，N 可配），并要求**供应商错误的形状**（如 `403`+`permission_error`、
   JSON 错误对象、`error`+`quota`）——**拒绝**"正文里偶然提到 quota"就判定（给出反例夹具）。
   **原始行必须随分类一起保留**（PM 可核对，分类只是线索不是裁决）。
2. **两个证据源，缺一即 `unknown`**：① tmux 遗体画面（scrollback）② pi 会话文件里的最后错误（若有）。
   两源都给时取"更具体"的一个并记明来源；**取不到任何一源 → `unknown`**（不许猜）。
3. **只对"当前这一次死亡"生效**：按 `(席位, 分类, pane_dead_time/pid)` 记账；席位重启后**旧死因不得粘在新会话上**
   （给出"重启后不显示旧原因"的断言）。
4. **可见面**：`team status`（该席位行 + 原因）· `team digest` [1] · 面板 agents 块（能塞就塞，塞不下就说明）。
5. **一次通报（B）**：pulse 巡逻发现非 `normal` 死亡（含 `unknown`）→ 给 PM 发**一次** knock，带
   席位 + 分类 + 原文行；**同一次死亡只报一次**（去重键写清）；`normal` **不报**；`unknown` 报但**不假装知道原因**。
6. **可证伪**：合成额度帧 → `quota`；正常退出 → 无通报、无分类；乱码帧 → `unknown` + 一次通报；
   同一次死亡连跑三拍 → 恰好 1 条；"正文提到 quota 但形状不对" → **不判 quota**（反例）。

## Non-Goals（写明）

- **不改 M6.5 的存活判据**（本任务只加"为什么"，`running/dead/foreign/unknown` 的规则一字不动）。
- **不做自动 fallback**（换模型/换 provider 是另一个 change：涉及"自动花另一个 provider 的钱"的策略与授权）。
- 不越界改其他项目；机制做在 skill 里，装了 teamsmith 的项目共享。

## 现场样本（2026-09-28T09:21Z，我亲手遇到的）

```
[knock] from dev3 :: [auto·interrupted] agent:dev3 · P98 · branch=task/P98-apply · uncommitted=0 · unpushed=4
```

**信号里没有任何原因** ✗ —— 我唯一的办法是去 `tmux capture-pane -t teamsmith:dev3 -S -25` 看 pane，
结果它**活着**（Working 旋转、17%/1.0M、$0.121、正在按它自己的 8 条 todo 推进 ✓）。
所以这次是**良性**的"回合未完成"（无摘要、无 payload），但**光看通知分不出**：
"回合被打断"与"进程死了/额度耗尽/窗口超限"共用**同一种形状** ✗ —— 这正是本任务要补的那一格。
（另外注意：`uncommitted=0` 说明它的改动都已提交 ✓，所以"未完成"不等于"有丢失"，也需要分类来区分。）
