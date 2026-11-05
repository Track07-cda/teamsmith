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

## 一、关键回复页（`scripts/panel/src/strings/zh.ts`、`en.ts`）

现状（截图）：

```
关键回复 (259)
< 更早 更新 > r 最新
「这条回复是写给谁的？」——PM 写给用户的回复都在这里
259 个编号槽位
```

问题：① 反问句当成说明；② "槽位"是内部行话；③ 破折号前后没有空格，读着别扭；④ 三行说了同一件事。

改成：

- `replyPageNote`（zh）：**删掉这一行**——页面标题已经说明这是关键回复，多于一句话的说明本身就是噪音。若删除会破坏布局断言，就退成一句陈述：`给用户的回复`（不带问号、不带破折号）。
- `replyTotalSlots`（zh）：`{n} 条`（去掉"编号槽位"）。
- `en.ts` 同步：`{n} replies`（或等价的单数处理），`replyPageNote` 同样删除或退成 `Replies to the user`。
- 断言 `tests/key-replies-pty.sh:95/96` 与 `want_frame` 里那些 `「这条回复是写给谁的？」`、`个编号槽位` 必须跟着改——它们钉的是旧文案。

## 二、未知子命令（`scripts/team:158` + `team_usage_die`）

现状：

```
✗ 未知子命令：stop（team help 看全部；最近有破坏性变更，team version --check 检查 skill 版本）
run: team help
```

问题：括号里塞了两件无关的事，其中"最近有破坏性变更"是每次都出现的免责话；最后 `run:` 行与括号里的提示重复；`stop` 这种**曾经被误用过**的子命令，最该给的是"该用什么"。

改成：

- 一行说完：`✗ 不认识 stop，可用命令见 team help`。
- 删掉那个泛泛的"最近有破坏性变更"提示。
- `team_usage_die` 的 `run:` 行保留（它是所有用法错误的统一出口），但**它的文本与上面那行不重复**才允许保留；重复就删 `run:` 行。
- `stop` 不是任何版本的正式命令，不需要特判映射；但 `now`（0.4.0 移除的旧旗标）已有专门报错，别动它。

`en.ts` 对应文案同样处理。

## 验收（只跑选段，不跑全量）

- `bash skills/teamsmith/tests/key-replies-pty.sh --select pages`（或该套件里管这几行的段）
- `bash skills/teamsmith/tests/help-surface.sh --select claims`（用法文案的面）
- 一处 `team stop` 实跑输出（贴原文）
- `section-select.sh --check`、`git diff --check`
- 报告 `docs/team/reports/P416-dev.md`，提交推分支，通知 PM。**目标 40 分钟内**。

## 边界

只改 `scripts/panel/src/strings/{zh,en}.ts`、`scripts/team` 那一条 `*)` 分支、`lib/common.sh` 的 `team_usage_die`（若删 `run:`）、以及钉旧文案的断言。改面板源码后**必须**按钉住的工具链重建 `scripts/panel/panel.js`（`bun install --frozen-lockfile && bash build.sh`），否则 §26-a 沙盒重建逐字节比对会红。
