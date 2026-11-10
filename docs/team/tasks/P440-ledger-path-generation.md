---
id: P440
title: 生成的复验记录与 PROTOCOL 不再写入绝对家目录
agent: dev
category: code
phase: apply
change: -
specs: verification init-skill
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P440-ledger-path-generation
---

# P440 · 修复账本路径生成源

## 现场

A1 归档已完成，但账本禁令在基线也红：`docs/team/PROTOCOL.md` 因 `{{SKILL_DIR}}` 渲染绝对 home；`docs/team/reviews/P424.md`、`P439.md` 因 `team review` 记录 worktree/agent 报告绝对 home。只手工清理会被下一次生成重新污染。

## 要做的

1. `team review` 生成的 Markdown 记录不得包含当前用户的绝对 home/main-root 路径。用项目相对路径或稳定占位显示主工作树和 agent 报告；独立 `/var/tmp` checkout 可保留。锁记录、报告摘录、门禁尾部等动态内容也要走同一显示净化，不能只修两行模板。
2. `team init` 渲染的 `docs/team/PROTOCOL.md` 不得包含绝对 home。给 SKILL_DIR 一个**项目内可用的相对形式**：源仓可用 `skills/teamsmith`，普通项目可用 `.pi/skills/teamsmith`；不要把源码路径写死到所有项目，也不要让 `--no-skills` 项目得到假路径。可用既有路径解析，必要时加一个明确的相对占位，不新增配置键。
3. 不放宽 ledger-ban、不改 forbidden names、不吞错误，不改变 review 的执行者/SHA/命令/结果证据。
4. 现有历史文件的清理由 PM 在 main 上做；你只改生成源与测试。

## 验收

- 在隔离项目中，从 `.worktrees/verify` 执行真实 `team review`，生成记录通过 `ledger-ban.sh`，仍含实际执行者、 reviewed SHA、真实命令和结果；恢复绝对路径输出必须红。
- 在源仓形状与普通项目形状分别运行 `team init`，生成的 PROTOCOL 通过账本检查，且其中命令路径真实存在；`--no-skills` 形状不得伪造安装路径。
- 运行受影响选段（至少 10、10b、17、19，按实际读取更新 section-paths）、`spec-refs`、`section-select --check`、`openspec validate --all`、账本禁令和 `git diff --check`。不跑全量/夜间/61b。

## 交付

`docs/team/reports/P440-dev.md`，先给结论，附真实生成样例、两个项目形状、红/绿/恢复证据和未跑范围。只提交本地分支并通知 PM；由非作者复验，不合并、不发布。
