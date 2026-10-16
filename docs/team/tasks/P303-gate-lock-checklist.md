# P303 · 按事实勾选 `gate-lock-external-deletion` 的清单（作者自查侧）

task: P303
agent: dev-bob
phase: apply
category: code
change: gate-lock-external-deletion
specs: verification, boundary
deltas: -
branch: task/P303-gate-lock-checklist
deps: P288（已并入 main）、V53（两轮独立复验，第二轮 PASS）

## 要做什么

`team change status gate-lock-external-deletion` 的归档前置是清单未勾。按事实勾 `openspec/changes/gate-lock-external-deletion/tasks.md`：

- **你自己做的那些**（apply 侧：伴生锁、兼容声明、入场检查、察觉与安全停跑、性能锁同族、文档、夹具与红侧）——每项末尾追加 `· P303 按事实勾：<证据>`（提交号 / 报告小节 / 命令与 rc），**保留原文一字不动**。
- **PM 与复验的项留空**，由我勾；**找不到证据的项留空**并单列一节说明原因（这道账前六次翻出过真东西）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动。
- **顺带一件**：V53 记录里「平铺判定」那条的**最终形态**已按你的返修落地（判据来自命名规则本身、以运行自己的 ns 为参照）——若清单里有条目描述的是**返修前**的做法，按「实际做法」注记写清差异，不改原文。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
