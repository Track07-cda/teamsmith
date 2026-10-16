# P301 · 「写给用户的回复都要发布」：apply（三处发出面 + 那一页的说明 + 两类门禁断言）

task: P301
agent: dev
phase: apply
category: code
change: replies-for-the-user-are-published
specs: key-replies, panel
deltas: -
branch: task/P301-replies-for-the-user-apply
deps: P300（提案已 ACCEPTED 并入 main；判据＝**按读者**，见 `docs/team/reviews/replies-for-the-user-are-published-proposal.md`）

## 范围

1. **三处发出面**按新判据改写：`templates/pm-prompt.md.tmpl`、`references/protocol.md` §4b、`SKILL.md` 的命令表段——都写「**读者决定是否发布**」+ 五类示例（回答／汇报状态与进度／结论或裁定／请用户决策／交付与复验摘要）+ 排除项（巡检、其他席位、别的项目 PM、工具回执）+ **兜底**（判断不下来按「写给用户」）+ 自测题「这条回复是写给谁的？」。**不许留旧措辞的残留**（例如单句「answer to a question」当作完整触发）。
2. **`panel` 那条 ADDED 落地**：关键回复页加一行自述（这一页是什么、什么属于它、谁发布、那句自测题）；页面**保持只读**（不许加输入、不许自动检测聊天流）。
3. **门禁两类**（D170）：① 三处各有「读者判据」这一段（删任一处 → 红并点名**哪一面**）；② 示例命令是当前可用形式（写错 → 红）。**措辞与语气不设断言。**
4. **不变量**：`team reply` 存储/列表/正文语义不变、面板只读、退出码不变、不新增配置键、不恢复「自称/未经核验」字样。

## 验收

```bash
bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
交付后写报告、notify pm；**由没写过本变更的席位做独立复验**（自设反例：删三处任一处必须红、示例写错必须红、并核那一页说明真的渲染出来）。
