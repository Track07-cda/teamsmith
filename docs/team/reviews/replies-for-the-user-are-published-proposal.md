# 提案复核 · `replies-for-the-user-are-published`（P300 第 2 轮）——**ACCEPTED**

- 判定: **ACCEPTED**
- 复核者：PM（未参与撰写）；输入：分支 `task/P300-answer-must-be-posted-propose`，受检 tip `f0a7ca6`；证据 `pm-skills-ledger/team/reviews/P300/`

| 检查 | 结果 |
|---|---|
| 严格校验 | **23 passed / 0 failed** |
| 基线场景对照（两条 MODIFIED） | **零丢失**（1 → 1；3 → 4） |
| 试归档投影 | 成功（`2026-10-16-replies-for-the-user-are-published`），归档后 **22/0** |
| 判据 | **按读者**，与用户 2026-10-16 的口径逐条对齐 ✓ |

## 我核过的判据原文（关键几处）

- 「its trigger is decided by the **reader**: a reply written for the user MUST be published」；
- 点名五类「写给用户的」：**回答提问 / 汇报状态与进度 / 给出结论或裁定 / 请用户决策 / 交付与复验摘要**，并补一句「**any other reply whose reader is the user**」；
- 排除项与用户一致：**与巡检、其他席位、别的项目 PM 的协调各走自己的渠道**，**工具生成的自动回执根本不是回复**；
- **兜底规则**（我特别认可的）：**读者判断不下来的，按「写给用户」处理**——与「不希望用户漏掉」同向；
- 自测题写进规则：**「这条回复是写给谁的？」**；`panel` 那条 ADDED 让那一页自述身份与归属。

## 准入条件（apply）

1. **三处发出面**（PM 提示词模板、协议 §4b、技能命令表）按新判据改写，**不许**留旧措辞的残留（例如「answer to a question」单独成句）；`panel` 那一页的说明行落地。
2. **门禁只加两类**（D170）：三处都有「读者判据」这一段（删任一处 → 红并点名该面）、示例命令是当前可用形式（写错 → 红）。措辞与语气不设断言。
3. **不变量**：`team reply` 的存储/列表/正文语义不变、面板保持只读、不改退出码、不新增配置键、不恢复「自称/未经核验」字样。
4. 验收：跑**闭包选段**并贴结果；`validate`、`spec-refs`、`ledger-ban`、`git diff --check` 全绿。
5. 独立复验由**没写过本变更**的席位做（要自设反例：把三处里任一处的「读者判据」删掉必须红、把示例命令写错必须红、并核那页说明行真的渲染出来）。
