---
id: P421
title: 门禁里的 8 条红：2 处断言没跟上已定的改动、4 类隔离误报、1 类真实账本泄漏
agent: dev2
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P421-gate-red-attribution
---

# P421 · 2026-11-05 的一阶全量门禁：8 条红的归因与修正

门禁日志 `/var/tmp/fog-1.log`（137 段、耗时约 2.5 小时，rc=1）。**没有一条是产品行为坏**；但每类都要点名。

## 一、断言没跟上已经落地的改动（3 处，都是同一类错）

1. **四份提示词面**：`smoke.sh` 的「One contract across the shipped surfaces」仍要求
   `inline-wait budget (about 2 minutes)` 和 `the completion wake-up is the normal harvest point`。
   2026-11-05 已经把这些改成「不要在回合内等 / 完成唤醒是收割点」并给出短句。要**改断言**让它断言新措辞
   （四个面一致），并保留“旧预算不得出现”的反向断言。注意：你**不要**去把提示词改回旧措辞。
2. **`12b-pi` 唤醒模式**：`smoke.sh:10487` 期望夹具文案 `triggerTurn+followUp`；P419 已把 say 批改成 `steer`，
   夹具的 `S2` 文案现在是 `triggerTurn+steer`。把断言改成按类别（say → steer，通知 → followUp），夹具本身不用改。
3. **M28 tmux 隔离 lint**：`tests/live-capture-probe.sh:51` 的 `tmux kill-session -t probe 2>/dev/null` 没隔离。
   那是探针自己的清理行，要么补上私有 socket/tmpdir（看 lint 要的形状），要么整段用同一套 `tmux_iso` 隔离助手。
   **不是豁免**：探针自己的隔离也要做。

## 二、真实账本泄漏（要改文件内容，不是改扫描）

`P212 真实账本有命中`（15 处）都集中在我这两天写的文档里：

- `docs/team/reviews/P415.md:7`、`docs/team/reviews/P418.md:9`、`docs/team/tasks/P415-safe-dir-own-group.md:16,18`
  ——出现了别的项目名（本地用户的两个项目目录名，被扫描替换成 `<names#N>`）。
- 同族文件里 `drwxrwxr-x <user> <user>` 命中用户名。

要改的是**文档**：把别的项目名替换成「另一个项目（本地用户项目，带未升级的 PM）」这类描述，把 `ls` 输出的属主名
替换为占位（`<user>`），保留足够信息让人能复现但不含真实用户名/他项目名。不要去放宽 P212 的扫描范围。

## 三、隔离误报（同类问题多处）

`32⑨` 的「隔离：真实仓库账本面被改动」差异只有三个文件：
`.pi/team/state/bg.log`、`state/inbox-watch/<key>.reg`、`state/tmux-calls.log`——都是活的 PM/后台车道/闸门自己的正常写入，
不是夹具污染。`tmux-identity-leak.sh` 的 `ledger_manifest` 把整棵 `state` 都纳入逐字节比较了。

把该夹具的比较范围**收窄到它真正关心的对象**（与 P399 的做法同源：append-only 的审计与注册文件不算被污染；
杂散文件仍须报红）。要求：写一个 `state/<杂散文件>` 必须仍被点名；只是 `bg.log`/`tmux-calls.log`/`*.reg` 变化必须不报错。

另外它扫到的 `docs/team/inbox/<seat>.md` 里的夹具标记也要复核一次：第 12b-j / 26-l 同类断言在 P412 修过词表，
看看现在有没有新的普通英文短语混进来（本次日志里我没看到，但请你核一次并说明）。

## 验收

- 你改到的段的选段（`11f`、`6`、`31`、`32`、`60`、`12b-pi`），各贴段结果行；
- P212 命中数从 15 降到 0（贴命令输出）；
- 隔离夹具的红侧（杂散文件仍被点名）；
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`；
- 报告 `docs/team/reports/P421-dev2.md`，提交推分支，通知 PM。

## 边界

- 不跑全量 smoke（以上选段足够）；不改产品行为；不合并/归档/发布。
