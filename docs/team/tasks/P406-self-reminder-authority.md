---
id: P406
title: 自我提醒 MVP 第一片：共享权威（状态根定位 + 版本化快照 + flock 事务）
agent: dev
category: code
phase: apply
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/P406-self-reminder-authority
---

# P406 · 第一片：先有权威，再谈提醒

`openspec/changes/agent-self-reminder/` 的提案已复核通过并合入 main（D205/D206）。**本片只做 `tasks.md` 的 1.1 与 1.2，不做 1.3。**

**明确不做 1.3（Standby 迁移）**：那一步会改写真实项目的 Standby 标记，属于要单独授权的动作；本片产出的权威层必须先能被 1.3 使用，但不能在本片里动任何活的 `standby` 状态。

## 必须成立

1. **1.1 状态根定位与身份**：CLI、Pulse、Pi 三处共用同一套身份判定；给出唯一的项目状态根定位函数，拒绝冲突的 override 与外来项目。分离 worktree、继承并用错了环境变量这两种形状要有隔离夹具。
2. **1.2 版本化快照 + flock 事务**：一份带版本号的快照、一个 `flock` 包裹的事务助手、原子写（文件与目录两级持久化）、持久的项目/序号身份、有界的锁失败（明确超时与错误，不许静默重试）。Bash/Node 争用、持锁者被杀、快照故障注入三种情形要有验证。
3. **损坏与不支持的锁是显式失败**：读不懂的快照、缺失的 `flock` 必须给出可读错误并停住，不许"当作空快照继续"。

## 隔离（这条是硬约束，来自 2026-10-31 的事故）

上一轮 P388 的夹具用了临时目录但没建 git 仓、也没给独立 cwd，`--root` 回落到真实 pm-skills 检出，往主项目写了提醒与 Standby 状态。本片要求：

- 每个夹具先 `git init` 自己的仓，显式传 `--root`，并隔离 `HOME`/`TMPDIR`；
- 夹具跑完要能证明**主项目的 `.pi/team/` 一个字节没变**（前后清单比对，写在测试里）；
- 报告里贴一次这个证明的输出。

## 红侧

- 破坏版本号 / 写半个快照 / 两个写入者并发 → 各自要有具名断言变红；
- 把 `flock` 助手换成一个不持锁的直写 → 并发断言必须红；
- 删掉状态根定位里的"拒绝外来项目"分支 → 身份断言必须红。

## 验收（自己跑，贴 rc 与输出尾）

- 新增/扩展的测试套件（自己挑既有入口，不要新开一个框架）
- `openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 相关选段（按你改到的路径选，不要跑全量）
- 报告 `docs/team/reports/P406-dev.md`，提交推分支，通知 PM

## 边界

- 不改 `openspec/changes/agent-self-reminder/` 里的任何规格文本（那是提案，不是实现）；不改 Pulse 的巡检节奏；不做 Pi 投递；不写活的 `standby` 标记；不合并/归档/发布。
- 若你判断 1.1/1.2 里的某一条无法在不碰 1.3 的前提下交付，停下来在报告里写 `BLOCKED:` 并说明，不要自行扩大范围。
