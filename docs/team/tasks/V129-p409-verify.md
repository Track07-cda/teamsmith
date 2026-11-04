---
id: V129
title: P409（team remind CLI 与视图）独立复验
agent: verify
category: verify
phase: verify
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/V129-p409-verify
---

# V129 · P409 独立复验（非作者）

被验 `task/P409-remind-cli` @ `9aafbbcc`（作者 dev2）。这一片是第一次让人能真敲 `team remind`，但**还没有**任何投递：没有 Pi 消息、没有 Pulse 扫描、没碰 Standby。

## 必须独立证明

1. **只走一份权威**：`add/list/show/cancel` 全部经 `state-authority.mjs` 的事务，没有第二份文件读写、没有自己拼路径。给出你从 CLI 驱动后快照文件的证据（不是看代码注释）。
2. **时间解析是真的严**：非法串、无时区绝对时间、过去时间各自被拒并给出可读原因；相对时间（`30s`/`5m`/`2h`）换算正确。自己构造反例，不只跑作者的用例。
3. **正文不截断**：长 UTF-8 正文（含中文、emoji、换行）写入后 `show` 能逐字节取回；比对原始字节，不要只比长度。
4. **`key` 幂等**：同 key 活跃时 `add` 必须拒；该条终结后可复用；并发两次同 key 只能成一个。
5. **视图是派生的**：手工把快照里某条改成终结态后，`list` 的 queued/observed/到期计数必须跟着变——证明它不是另存了一份。若它其实另存了，判红。
6. **有界历史 + 高水位**：超过上限后最旧的终结项消失、ID 高水位不回退；把高水位写坏或写缺，必须显式失败而不是从 1 重发号。
7. **隔离**：夹具跑完主项目 `.pi/team/` 一个字节没变（沿用命名白名单判据，不许"整段跳过 `state/`"）；你自己复核一次。
8. **没越界**：代码里没有任何写 `state/standby` 的路径、没有 Pulse 改动、没有 Pi 投递。越界即判红（这一片不该有）。
9. **红侧**：时间解析、幂等、派生计数、高水位四处各自能红。

## 允许的命令

- `bash skills/teamsmith/tests/remind-cli.sh`（或它支持的选择）
- `bash skills/teamsmith/tests/state-authority.sh`（确认权威层没被这一片改坏；作者动过它 117 行，请看清是重构还是改了判据）
- `bash skills/teamsmith/tests/smoke.sh --select <按路径选到的段>`
- `openspec validate --all`（本仓非 strict，见 D226）、`spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`git diff --check`

## 边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布；不在真实项目上跑任何写状态的命令。
- 结论写 `docs/team/reviews/V129-verify.md`，第 3 行 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。
