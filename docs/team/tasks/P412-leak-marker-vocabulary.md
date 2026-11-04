---
id: P412
title: 隔离扫描的两处假红：泄漏标记用了普通英文句子、取样范围没含元套件记录
agent: dev2
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P412-leak-marker-vocabulary
---

# P412 · 隔离扫描的假红

## 现场（PM 从 2026-11-04 13:30 那次全量记录里读出来的，不是推测）

三段隔离断言在活团队上误报：

```
✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（实际 [/…/.pi/team/state/meta-suite/2026-11-04T13-30-26Z.log]）
✗ 26-l 隔离：夹具痕迹出现在真项目里：/…/docs/team/inbox/dev2.md
✗ M16 隔离：夹具的痕迹出现在真实账本里：/…/.pi/team/state/meta-suite/2026-11-04T13-30-26Z.log
```

两类原因，各自独立：

**其一：泄漏标记里混进了一句普通英文。** `smoke.sh` 的 `P10_LEAK_SCAN` 用
`pats="P10 夹具阻塞行|P10Z|wrote the report|$P10SESS"`。`docs/team/inbox/dev2.md` 第 228 行之所以被点名，是因为某个席位的英文交付消息里写了
"because I wrote the report while it ran" —— 命中 `wrote the report` 这个词组。一个双语项目里，这个短语在正常报告里必然出现。

**其二：取样范围没含元套件记录。** `real_ledger_hits` 扫 `docs/team/inbox` 与 `.pi/team/state`，已按确切路径排掉
`bg/**`、`tmux-calls.log(.forensics)`，按前缀排掉 `state/release-*/**`（P342：那是"**关于**一次夹具运行的日志"）。
`.pi/team/state/meta-suite/<时间>.log` 是同一类东西——它整份就是一次门禁运行的日志，内容必然带夹具标记。

## 要做的（两条，都是收窄到"能证伪"的程度，不是关掉）

1. **标记词表只放不可能自然出现的串**：删掉 `wrote the report` 这类普通英文句子；保留/改成带前缀的唯一标记（例如
   `P10Z-LEAK`、`P10 夹具阻塞行`、夹具 session 名）。负对照必须仍在：往一个假"真项目"里栽真标记，必须被抓到；
   顺手加一条反向断言——把一句普通英文（含 `wrote the report`）放进 inbox，**必须不**被点名。
2. **取样范围加 `.pi/team/state/meta-suite/`（按前缀）**，注释写清：那是元套件自己的运行记录，等同 `release-*/**`
   的先例；并且点名残余风险——真往这个目录写夹具痕迹不会再被抓，由"目录里只该有元套件记录"这条评审纪律兜。
   另外：`36` 里的"并集/清单"判据不要因此放松。

3. **顺带定性，不要求修**：`38-i panel-b3.sh` 那条 `收前后窗口数不变（期望 [3]，实际 [2]）`。给出你的判断——是并发
   夹具竞争，还是真回归；判真回归就修，判竞争就给出证据（窗口列表前后对比）并说明为什么它不是这次改动引入的。

## 红侧（每条都要能红）

- 把标记词表改回含 `wrote the report` → 你新加的反向断言必须红；
- 去掉 `meta-suite/` 前缀排除 → 那段隔离断言必须回到误报；
- 真往 `docs/team/inbox/` 与 `.pi/team/state/`（非排除路径）写标记 → 必须仍被抓到。

## 验收

- 相关选段（按你改到的路径选）；`section-select.sh --check`；`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`；`git diff --check`；
- 报告里给出"改前 3 条假红、改后 0 条"的同一命令输出对照。

## 边界

只改 `skills/teamsmith/tests/**`。不跑全量 smoke、不改产品代码、不合并/归档/发布。
