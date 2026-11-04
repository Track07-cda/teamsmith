---
id: P409
title: 自我提醒第二片：team remind 的 CLI 与版本化视图（不接投递、不碰 Standby）
agent: dev2
category: code
phase: apply
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/P409-remind-cli
---

# P409 · 先让人能敲进去

权威层已落地（`skills/teamsmith/scripts/state-authority.mjs`，P406 + V128 PASS）。本片做 `tasks.md` 的 **2.1 与 2.3**，**不做** 2.2（限额）、**不做** 3.x（Pi 投递）、**不做** 4.x（Pulse 与恢复）。

**为什么可以先不做 2.2**：本片产出的 `team remind` 只给人敲，模型侧 `team_remind` 工具还没注入（那是 3.3）。没有自主创建，就没有无界自唤醒的环路；但**取值为空或缺失时**依然要拒绝非法输入（时间解析、空正文），不许落到"看起来建成了"。

## 必须成立

1. **CLI**：`team remind add|list|show|cancel`，全部走 `state-authority.mjs` 的事务（`--cli` 入口），**不许**自己写一份文件读写。
   - `add`：严格的绝对/相对时间解析（错就拒、给出可读原因）、正文完整 UTF-8（不截断）、记录 source/owner/task、`key` 幂等（同 key 活跃则拒绝，已终结可复用）。
   - `list/show/cancel`：只读或终止态变更；`cancel` 对已终结项要说明而不是假装成功。
2. **视图（2.3）**：`scheduled / derived-due / queued / intent / observed / unknown / cancelled / resolved` 这些状态要能从快照**派生**出来，不额外存一份真相；`list` 的默认视图要能一眼看出"什么时候要响"和"现在会不会响"。
3. **有界历史**：终结态保留有上限，持久化 ID 高水位不能因为修剪而回退。
4. **`team help` 与文档**：新命令必须出现在帮助面里（`help-surface` 那套要绿），并在 `references/` 里有一处可执行的说明（别写成营销文案）。

## 硬约束

- 新增/改动路径要进 `section-paths.tsv`，`section-select.sh --check` 必须 ok、bad 0。
- 夹具必须**隔离**：自建 git 仓、显式给主根与状态根、隔离 `HOME`/`TMPDIR`；跑完证明**主项目 `.pi/team/` 一个字节没变**（沿用 P406 的命名白名单判据，别再退回"整段跳过 state/"）。
- **不许**写 `state/standby`、不许碰 Pulse、不许改 1.3 的任何东西。

## 红侧（每条都要能红）

- 时间解析：非法串、过去时间、无时区绝对时间 → 各自拒绝并点名；
- `key` 幂等：同 key 重复 `add` 必须拒；取消后复用必须允许；
- 视图派生：手工改快照把某条置为 terminated 后，`list` 的 queued/observed 计数必须跟着变（证明是派生不是副本）；
- 修剪：超过上限后最旧终结项消失、ID 高水位不回退；把高水位写坏 → 必须红。

## 验收（自己跑，贴 rc 与输出尾）

- 新夹具 + `bash skills/teamsmith/tests/smoke.sh --select <按路径选到的段>`
- `openspec validate --all`（本仓非 strict，见 D226）、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P409-dev2.md`，提交推分支，通知 PM

## 边界

- 只改 `skills/teamsmith/scripts/**`、`skills/teamsmith/tests/**`、`skills/teamsmith/references/**`（说明用）、`section-paths.tsv`。
- 不改规格文本、不跑全量 smoke、不合并/归档/发布。
