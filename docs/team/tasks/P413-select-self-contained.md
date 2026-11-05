---
id: P413
title: 按段裁剪出来的脚本必须自足：11b4 依赖 11b 里定义的助手，分片一跑就红
agent: dev
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P413-select-self-contained
---

# P413 · `--select` 裁出来的段脚本不自足

## 现场（公开 CI，0.4.0 的首跑）

run `41937306370`、shard 3（job `126948971928`）、**18m56s** 完成，`== 选段结果 == ✓1250 ✗8`。八条红全在同一段，且全是同一形态：

```
/var/tmp/teamsmith-ci-tmp/s3/teamsmith-select.work-0c9a453f.11735.sh: line 3282: make_pm_idle: command not found
/var/tmp/teamsmith-ci-tmp/s3/teamsmith-select.work-0c9a453f.11735.sh: line 3291: pm_state_now: command not found
✗ P36 ②：--fresh-pm 起出的 PM 不是 running（）
✗ P36 ③：默认成功文案说续用 -c（… 找不到 [续跑：pi -c]）
✗ P36 ④：同 cwd 有活 PM CLI 会话 → 打提示（… 找不到 [检测到同目录]）
（另四条同源）
```

`pm_state_now`、`pm_state_until`、`make_pm_idle` 定义在 **`section "11b · 定时巡检…"` 内部**（`smoke.sh:6264/6266/6315`），而 **`11b4 · PM 交接（P36）`** 调用它们。`--select 11b4` 把该段裁成独立脚本时不会带上 11b 的函数，于是三条助手全部 `command not found`，随之八条断言红。

本地全量按顺序跑不会暴露它——11b 在前、函数还在 shell 里；分片按哈希取段，11b4 单独下发就红。**这与 P405 修的 §2 依赖上一段 `cd` 是同一类：段与段之间的隐式依赖。**

## 要做的

1. **把这三个助手搬出 section 11b**，放到任何 `--select` 都能带上的位置（`tests/lib/` 里由 `smoke.sh` 顶部 `source` 的那类文件）。要求：`--select 11b4` 单独跑必须 ✓（自己贴输出），`--select 11b` 也必须照旧 ✓。
2. **找出同一类的其它实例**并一并处理：搜索 `section` 边界内定义的函数、以及跨段的变量/目录假设。判据一句话——**任意一段被单独裁出来时，它要么绿、要么以"缺前置"为理由显式 SKIP，不许 `command not found`**。给出你找到的清单与处理（搬走 / 显式前置断言 / 说明为什么不会发生）。
3. 「自足」这条要可证伪：加一条**便宜**的检查（不是又一轮全量）——遍历表的 key，对每个 key 检查裁出的脚本里引用的函数名是否都在同一份脚本里定义（或来自被 source 的 lib）。它自己不许依赖跑任何段。**净零**：这条检查要顶掉一条现有的同类检查，或说明为什么产品自己承载不了（在报告里点名被顶掉的那条）。

## 红侧

- 把三个助手搬回 11b 内部 → 新检查必须红并点名 11b4；
- 把新检查关掉、让 11b4 回到 `command not found` → 分片选择（`--select 11b4`）必须红。

## 验收

- `bash skills/teamsmith/tests/smoke.sh --select 11b4 </dev/null` → 绿（贴输出）
- `bash skills/teamsmith/tests/smoke.sh --select 11b,11b3,11b4 </dev/null` → 绿
- 新检查的绿/红两侧输出
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P413-dev.md`，提交推分支，通知 PM

## 边界

只改 `skills/teamsmith/tests/**`。不跑全量 smoke（除上面点名的选段）、不改产品代码、不合并/归档/发布。
