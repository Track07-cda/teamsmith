---
id: P426
title: 两条隔离红：账本禁令扫描被自己写的措辞触发；身份夹具把活项目遥测当成改动
agent: dev2
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P426-gate-isolation-two-reds
---

# P426 · 全量门禁里的两条红，都不是产品回归

## 红一：`12b-j` 泄漏扫描被我们自己的措辞命中

```
✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（实际 [.../docs/team/inbox/dev2.md|.../state/notify.log]）
```

`docs/team/inbox/dev2.md:243` 是一条**正常交付消息**，里面写的是「词汇表现在只放不可能自然出现的串（`P10 夹具阻塞行`, `P10Z`, `$P10SESS`）…」——
它引用了扫描词表本身，于是被扫描判成夹具痕迹。P412 已经删掉过 `wrote the report` 这类普通英文，但根因没除：
**词表里的串一旦被写进报告就会被自己抓住**。

要做的（选一个，说明理由）：

- 把词表换成不可能被引用的形状：加一个固定但无意义的后缀（例如 `P10Z-LEAK-9c4e`），四段词表逐条这样处理；**不许**改成随机值（跨运行要可检测）。
- 或者：扫描区分「谁写的」——只对夹具自己产出的机器文件（`state/bg/<夹具名>*`、夹具会话 JSONL）做词表匹配，人类可读的 `docs/team/inbox/**` 与 `state/notify.log` 只按**路径形状**（夹具 session 名）判。

无论选哪个，**必须**保留反例能力：夹具真的往 `docs/team/inbox/` 写一行带夹具 session 名的记录时，仍须被抓到。

## 红二：`32⑨` 把活项目的遥测当成账本改动

```
✗ 隔离：真实仓库账本面被改动（夹具漏钉了目标？）—— 差异：（空）
```

`tests/tmux-identity-leak.sh:744-751` 自己对 `docs/team/inbox` + `.pi/team/state` 做整目录 sha256 清单。
但**这个项目是活的**：Pulse 每次巡检都写 `state/watchdog.log`、`notify.log`、`signal-calls.log` 等，运行期间清单必然变。
`tests/lib/main-team-fingerprint.sh` 早就有 `main_team_volatile` 这种命名白名单，这条夹具没用它、自己造了一份全量清单。

要做的：改用既有白名单（或等价的命名规则）判定——只比“不该变的那些”，遥测显式排除并在断言里写明；`state/` 下未登记的新子目录仍算改动。
红侧：往 `docs/team/inbox/` 写一行、或往 `state/` 下未登记子目录写一个文件，必须变红；只让 `watchdog.log` / `notify.log` 增长必须保持绿。

## 验收

- `bash skills/teamsmith/tests/tmux-identity-leak.sh`（红二）
- 与红一相关的选段（`--select 12b` 一族里带泄漏扫描的那段）
- 两次都贴改前/改后的断言行
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P426-dev2.md`，提交推分支，通知 PM

## 边界

只改这两条隔离判据与它们的夹具；不改产品行为、不改扫描覆盖的真实意图（假夹具痕迹仍须被抓到）、不跑全量 smoke、不合并。
