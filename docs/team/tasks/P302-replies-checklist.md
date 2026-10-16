# P302 · 按事实勾选 `replies-for-the-user-are-published` 的清单（作者自查侧）

task: P302
agent: dev
phase: apply
category: code
change: replies-for-the-user-are-published
specs: key-replies, panel
deltas: -
branch: task/P302-replies-checklist
deps: P301（已并入 main）、V54（独立复验 PASS）

## 要做什么

`team change status replies-for-the-user-are-published` 的归档前置是**清单 28 项未勾**。请按事实勾 `openspec/changes/replies-for-the-user-are-published/tasks.md`：

- **你自己做的那些**（apply 侧：三处发出面、页面说明、门禁两类断言、示例命令实跑等）——每项末尾追加 `· P302 按事实勾：<证据>`（提交号 / 报告小节 / 命令与 rc），**保留原文一字不动**。
- **PM 与复验的项**（提案复核、独立复验、归档）**留空**，由我勾；**人读/代理读相关的项**：若无该项就跳过，若有，如实写「代理读（已标注）」。
- **找不到证据的项：留空**并在报告里单列一节「未勾项与原因」——前几轮这道账翻出过六处真东西，宁可留空。
- **只动那一份 `tasks.md` 与你的报告**；产品/测试/规格一个字不动。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
