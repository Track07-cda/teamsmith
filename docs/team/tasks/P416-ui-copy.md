---
id: P416
title: 两处面向用户的文案：去掉反问句与免责话，删掉内部行话
agent: dev
category: code
phase: apply
change: -
specs: key-replies
anchor: openspec/specs/key-replies/spec.md
deltas: -
branch: task/P416-ui-copy
---

# P416 · 两处界面文案

用户看的是这两个界面，反馈是"语气文风有问题"。要改的就是文案本身，不动布局、不动逻辑。

## 一、关键回复页：删掉整行说明，去掉行话

现状（截图）：

```
关键回复 (259)
< 更早 更新 > r 最新
「这条回复是写给谁的？」——PM 写给用户的回复都在这里
259 个编号槽位
```

用户要求：**界面上不要啰唆，整条说明删掉**。所以：

- `replyPageNote` 这一行**整条删除**（zh 与 en 都删，`layout.ts:1389` 那行随之去掉）。不要改写它、不要缩成小字。
- `replyTotalSlots`：`{n} 条` / `{n} replies`（去掉"编号槽位"这个内部行话）。
- 断言 `tests/key-replies-pty.sh:95/96` 与 `want_frame` 里钉旧文案的地方跟着改：原来断言"说明行在"的，改成断言"说明行**不在**"——这是一条反向断言，比删掉它更能防回归。

## 二、未知子命令（`scripts/team:158` + `team_usage_die`）

**CLI 的用户可见文案一律用英文**（新规则，见 D228）。现状：

```
✗ 未知子命令：stop（team help 看全部；最近有破坏性变更，team version --check 检查 skill 版本）
run: team help
```

问题：括号里塞了两件无关的事，"最近有破坏性变更"是每次都出现的免责话，`run:` 行又重复一次。

改成（英文、一行）：

```
✗ unknown command: stop (see: team help)
```

- 删掉"最近有破坏性变更"这句；`team_usage_die` 的 `run:` 行若与上一行重复就删掉它（它给所有用法错误兜底，重复才是问题）。
- `stop` 不是任何版本的正式命令，不做特判；`now`（0.4.0 移除的旧旗标）的专门报错保留并同样改成英文。
- 本任务只改这一处 CLI 文案；其余 CLI 文案按 D228 分期迁移，不在本单范围。

## 验收（只跑选段，不跑全量）

- `bash skills/teamsmith/tests/key-replies-pty.sh --select pages`（或该套件里管这几行的段）
- `bash skills/teamsmith/tests/help-surface.sh --select claims`（用法文案的面）
- 一处 `team stop` 实跑输出（贴原文）
- `section-select.sh --check`、`git diff --check`
- 报告 `docs/team/reports/P416-dev.md`，提交推分支，通知 PM。**目标 40 分钟内**。

## 边界

只改 `scripts/panel/src/strings/{zh,en}.ts`、`scripts/team` 那一条 `*)` 分支、`lib/common.sh` 的 `team_usage_die`（若删 `run:`）、以及钉旧文案的断言。改面板源码后**必须**按钉住的工具链重建 `scripts/panel/panel.js`（`bun install --frozen-lockfile && bash build.sh`），否则 §26-a 沙盒重建逐字节比对会红。
