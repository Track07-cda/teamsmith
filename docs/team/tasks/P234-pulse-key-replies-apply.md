# P234 · pulse-key-replies apply（发布路径 + 存储 + 面板第五页）

task: P234
agent: dev
phase: apply
category: code
change: pulse-key-replies
specs: panel, key-replies
deltas: panel, key-replies
branch: task/P234-pulse-key-replies-apply
deps: E16（提案 ACCEPTED，见 docs/team/reviews/pulse-key-replies-proposal.md）

## 范围

按已接受的 `openspec/changes/pulse-key-replies/`（proposal / design 六条决策 / tasks.md / 两份 delta）实现**全部条目**。范围以该 change 的 tasks.md 为准，本条不重述；设计要点是：`team reply` CLI 主动提交（正文由调用方显式传入，工具不去 Pi 历史里找「当前回复」）、固定长度提交索引 + 不可变原文、锁与持久提交点、Pulse 第五页复用既有渲染器与详情查看、正文只进仓外账本面（默认不进公开仓）。

边界：只碰该 change 授权的路径（`scripts/lib/**` 的 reply 命令、扩展若需要、`panel/**` 与 bundle、门禁段落登记）。**不要碰** `templates/**`、`references/**`、`SKILL.md`（属 routing S3）；不改 canonical specs；需要契约变动先 `BLOCKED:` 给 PM。

## 前置

- **串行约束**：P232（routing 的面板切片）正在改 `panel/**`。本任务必须在 P232 合并之后才开工——PM 会在派单时确认并把 P232 的交付 tip 写进消息；在此之前保持 todo。
- 交付前自己核对 `openspec/changes/pulse-key-replies/tasks.md` 的每条都有对应实现或明确的未做理由。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths <你实际改动的路径>
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
外加该 change 的 tasks.md 里点名的门禁段落与真 tmux 面板取证（第五页渲染帧、长正文滚动、重启后仍可读、失败可见但不阻断正常答复），以及红侧（索引越界 / 原文被改写 / 提交失败仍宣告成功 → 相应断言必须红）。

## 交付

`docs/team/reports/P234-dev.md`（逐条 tasks.md 对照、命令与 rc、渲染帧、未做项）、证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，之后由未写过本任务的席位独立复验。
