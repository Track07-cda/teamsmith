---
id: P411
title: 把元套件的记录形状登记进隔离清单的白名单（连带一次真红侧）
agent: dev2
category: code
phase: apply
change: -
specs: -
anchor: none (infra) — 修的是隔离判据的白名单覆盖面，不改产品行为
deltas: -
branch: task/P411-meta-suite-whitelist
---

# P411 · 一个合法写入者没登记，于是判据假红

## 现场（PM 实测，2026-11-04 07:00 UTC）

P409 的隔离判据在 main 上报红一条：

```
✗ F 主项目 .pi/team 出现了非白名单变化（./state/meta-suite/2026-11-04T06-46-57Z.log）
```

那个文件是 **P410 正在做的元套件**写的运行记录（`tests/meta-suite.sh` 第 19、53 行：记录目录默认
`<项目根>/.pi/team/state/meta-suite`，而项目根取 `git-common-dir` 的主检出——所以从 worktree 跑也会落在主检出）。
`tests/lib/main-team-fingerprint.sh` 的 `main_team_volatile` 里，`./state/` 下的子目录只列了
`bg|inbox-watch|outbox|spool|draft|key-replies` 与 `release-*|product-field-trial`，**没有 `meta-suite`**。

## 判断

判据本身是对的（它抓的正是"有人往主项目状态写了东西"），错的是**合法写入者没被登记**。这不是放宽：
`state/meta-suite/` 只有一个写入者（元套件的记录），内容是运行记录而不是产品状态。

## 要做的（两项，别扩）

1. `tests/lib/main-team-fingerprint.sh`：在 `./state/` 的子目录分支里加 `meta-suite`，并在注释里写明**谁写**
   （`tests/meta-suite.sh`，写的是运行记录）与**为什么它是易变的**（每次跑元套件都会新增一个文件）。
2. 红侧：证明这次改动没有把"杂散文件"这条判据弄松——写一个 `./state/<别的名字>/x.log` 必须仍然报红；
   以及 `./state/meta-suite/` 下的新增必须**不**报红。两条都要具名断言。

## 验收

- `bash skills/teamsmith/tests/remind-cli.sh` → 全绿（F 那条不再假红）
- `bash skills/teamsmith/tests/state-authority.sh` → 全绿（同一份判据，不能一处松一处紧）
- `MAIN_TEAM_BREAK=skip-state` 的红侧仍能红
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P411-dev2.md`，提交推分支，通知 PM

## 边界

只改这个 lib 与两处夹具的断言；不碰产品代码、不碰 P410 的元套件记录路径、不跑全量 smoke。
