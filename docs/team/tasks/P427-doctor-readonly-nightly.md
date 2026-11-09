---
id: P427
title: 修复夜间检查：doctor 不得创建显式临时根，隔离夹具写法过 lint
agent: dev
category: code
phase: apply
change: -
specs: verification
anchor: openspec/specs/verification/spec.md
deltas: -
branch: task/P427-doctor-readonly-nightly
---

# P427 · 夜间检查的三条失败

## 证据

公开夜间 run `42365002327`（main `d159a12b`）的完整记录已保存到
`/var/tmp/ci-meta-42365002327/2026-11-07T10-42-26Z.log`。`40` 段为 `✓39 ✗3`，其余段全绿。
11 月 6 日 run `42210721521` 是同样三条。

### 一、doctor 的只读行为（两条断言）

```
✗ 40 P314 source=tmpdir 腿：没说「尚未创建」
✗ 40 P314 source=tmpdir 腿：doctor 把显式给的根建出来了（…/ghost-tmpdir）—— 只读面不许写盘
```

调用方显式设置了一个尚不存在的 `TMPDIR` 后，`team doctor` 应只读取最近存在祖先的容量，说明该根尚未创建，
并给出由操作者创建的命令；它不得创建该根。修 `cmd-project.sh` / `cmd-status.sh` / `common.sh` 中实际造成写入或
错误文案的路径，不要改断言来接受创建行为。

红侧：重新调用创建函数或让探针落到不存在的根上时，这两条断言必须重新变红。默认根的既有正对照保持绿。

### 二、隔离夹具的 lint（一条断言）

```
✗ 40 lint 有 finding（rc=1）：skills/teamsmith/tests/isolation-ledger.sh:10: 相对/非临时根的模板（-p）
```

修 `tests/isolation-ledger.sh` 的临时目录创建方式，使项目既有的临时根检查通过；不得关闭 lint、添加豁免或改变隔离判据。
`isolation-ledger.sh` 的 15 条行为断言仍须全绿。

## 验收

- `bash skills/teamsmith/tests/smoke.sh --select 40 </dev/null`：改前/改后结果行都贴出，改后必须零失败；
- `bash skills/teamsmith/tests/isolation-ledger.sh`：全绿；
- `bash skills/teamsmith/tests/section-select.sh --check`；
- `bash skills/teamsmith/tests/ledger-ban.sh --names-file .pi/team/forbidden-names.txt`；
- `git diff --check`；
- 报告 `docs/team/reports/P427-dev.md`，小步提交，通知 PM。

## 边界

只修上述两处及对应夹具；不处理 11 月 8 日外部下载 503/504，不跑全量门禁，不合并、不发布。
