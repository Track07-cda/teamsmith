# P74 · one-line-draft-judgement 独立验证（verify 阶段）

```
task:   P74
agent:  dev2
issue:
change: one-line-draft-judgement
specs:  delivery-guard#An automated send never types into a non-empty input box / notify-and-inbox#Messages to a stopped agent fall back to the inbox
phase:  verify
anchor: change
deltas: delivery-guard, notify-and-inbox
grant:  docs/team/reports/P74-dev2.md · docs/team/reports/P74-dev2/**（只写报告与证据，不改实现）
deps:   P63（propose，dev3）· **P67（apply，dev3）**——apply 作者不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。**apply 是 dev3 做的 → 你来验（D31）。**

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **边框邻行按内容读**：自己造帧（**不要**只用它的 `tests/frames/*`）——
   ① 0.87 布局（状态行**在框外**）+ 单行草稿 → 必须读出草稿、判 `BUSY`；
   ② 0.85.1 布局（框内最后一行是**框自带状态行**）+ 空框 → 必须仍判 `EMPTY`；
   ③ 光标**停在**邻行上的形态 → 不许因"光标在其上"而误判；④ 多行草稿 → `BUSY`。
2. **边框配对**：顶边框取**最靠下**的候选（草稿自画的等宽分隔线不许冒充边框）；spinner 形状行不作候选；
   **整行等宽**与 spinner 两类各自可辨。
3. **检查框内每一行**（含光标**下方**的内容行；自己造"先按回车再打字"与"↑ 取回"两种）。
4. **两处判据同源**：`team_input_box_text`（真 pane）与 `box-judge.sh`（帧级）必须走同一个提取
   —— 自己改一处（在 scratch 副本里）→ 另一处必须**跟着变**（分叉即失败）。
5. **安全面（最重要）**：单行草稿的 pane 上，**就绪门拒绝放行**（rc≠0、keylog 零行）；
   `team say` 与 `draft send` **只排队**（keylog 零行、队列计数正确）；**一个键都不许敲进草稿**（前后 sha256）。
6. **覆盖层优先权未回退**（P59 的面）：真信任弹窗仍判 `overlay`（不是草稿、不是空框）。
7. **零回归**：FAST + 全量 smoke、`pm-box-real.sh` 三态。
   ⚠️ 当前 main 上可能有两条**已知**红：`12b-j`（审计日志毒化，P73）与 `40 lint`（若在含 P64 的树上应已清）
   —— 如遇到，**点名区分**，不算本 change 的回归。

## 至少三条变异（红→绿原始输出）

- 把邻行谓词改回"一律按 chrome 排除" → 单行草稿帧翻 `EMPTY`（红侧）；
- 把"多候选取最靠下"改成"取最近" → 草稿自画分隔线的形态红；
- 让两处判据分叉（只改 `box-judge.sh`）→ 同源断言红；
- 还原后 `git status --porcelain` 干净。

## ⚠️ PM 更正（2026-09-22 18:3x，收到 P74 的报告后）

本 brief 第 2 条我写反了两处，**以规格为准**（`openspec/specs/delivery-guard/spec.md`，base 原文）：

| 我写错的 | 规格其实是 |
|---|---|
| 「顶边框取**最靠下**的候选」 | **「When several rows qualify, the top border is the HIGHEST qualifying row above the bottom border, never the nearest one」** —— 取**最高**的合格行 |
| 「**spinner 形状行不作候选**」 | 顶边框**可以**是 spinner 形状行（`── ` 前缀 + 长横线）；**不作候选的是 Pi 的工作行**（` ⠋ Blanching…` 那颗盲文行，规格明确写它 deliberately NOT an eligible border） |

P74 按**规格**验并据此判定，结论正确；错的是我的措辞。**F1**（"下边框"候选选择）是规格里**确实**没写的一条
（规格只钉了顶边框取最高、以及邻行按内容读）——已按 P74 的建议开后续 change。

