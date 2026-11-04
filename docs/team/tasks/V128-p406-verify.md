---
id: V128
title: P406（共享状态权威 1.1/1.2）独立复验
agent: verify
category: verify
phase: verify
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/V128-p406-verify
---

# V128 · P406 独立复验（非作者）

被验 `task/P406-self-reminder-authority` @ `5a722bea`（作者 dev）。这一片是自我提醒 MVP 的**地基**：状态根定位、版本化快照、flock 事务。后面 1.3（Standby 迁移）与整条投递链都会压在它上面，所以这里的地基漏一处，后面全是错的。

## 必须独立证明（每条都要你自己的输出或反例）

1. **只有一份实现**：CLI（Bash 调 `--cli`）与 Node（`import { request }`）走的是**同一个** locator/snapshot/flock 实现，不是两份并行代码。给出你从两处入口分别驱动、观察到同一份快照文件与同一把锁的证据。
2. **原子性**：事务写是"临时文件 + fsync + rename + 目录 fsync"。用一个 failpoint 或精确时点注入证明"写一半就死"不会留下半个快照（要么旧值、要么新值），并且**读不到的快照不会被当成空快照继续**。
3. **锁语义**：`flock` 缺失、锁超时、持锁者被杀三种情形各自是**显式失败**（可读错误、退出码非 0），不是静默降级；并发两个写入者不会产生交错结果。用你自己的并发驱动，不要只看作者的断言。
4. **身份**：外来项目 / 冲突 override / 继承错的 `TMPDIR`·`HOME` 会被拒绝，而不是"就近找到一个根就用"。分离 worktree 的形状要有用例。
5. **隔离事故面**：这套夹具跑完后**主项目 `.pi/team/` 一个字节没变**。请自己复核这条，不要只看作者报告里那行 ✓：用一个独立清单（含 mtime/内容）在跑前跑后比，并确认它真的会红（故意让夹具写一次主项目，看它是否抓到）。
6. **1.3 没被偷偷做**：本片**不得**碰活的 `standby` 标记或做迁移。请确认代码里没有任何写 `state/standby` 的路径（读也不算做了迁移，但写就是越界）。
7. **红侧**：把事务换成不持锁的直写、把版本号破坏、把"拒绝外来项目"分支删掉，各自必须有具名断言变红。

## 允许的命令

- `bash skills/teamsmith/tests/state-authority.sh --all`（或它支持的等价选择）
- `node skills/teamsmith/tests/state-authority-node.mjs`
- `bash skills/teamsmith/tests/smoke.sh --select <你改到的段>`（作者加过一次段；按路径选）
- `openspec validate --all`（**本仓当前非 strict**，见 D226；不要用 `--strict` 判红）、`spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`git diff --check`

## 边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布；**不要**在真实项目上跑任何写状态的东西。
- 结论写 `docs/team/reviews/V128-verify.md`，第 3 行 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。
- 这是地基片：宁可判 NEEDS-CHANGES 让它补，也不要把"看起来对"放过去。
