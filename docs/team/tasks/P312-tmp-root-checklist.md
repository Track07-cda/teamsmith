# P312 · 按事实勾选 `tmp-root-on-disk` 的清单（作者侧）

task: P312
agent: dev2
phase: apply
category: code
change: tmp-root-on-disk
specs: verification
deltas: -
branch: task/P312-tmp-root-checklist
deps: P309（已并入）、V57（独立复验 PASS）

## 要做什么

`team change status tmp-root-on-disk` 的归档前置是**清单 26 项未勾**。按事实勾 `openspec/changes/tmp-root-on-disk/tasks.md`：

- **你自己做的那些**逐项追加 `· P312 按事实勾：<证据>`（提交号 / 报告小节 / 命令与 rc），**原文一字不动**；
- **PM 与复验的项留空**，由我勾（引用 V57）；
- **找不到证据的项留空**并单列一节原因（这道账此前八次翻出过真东西）；
- **一条特殊项**：报告里你写的「六处既有红 + 5 条具名 FAIL」要能被单独核对——请把它们的**对照命令与读数**在报告里做成一张表（我勾选时会引它）。
- 只动那一份 `tasks.md` 与你自己的报告；产品/测试/规格一个字不动。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
