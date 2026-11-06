---
id: P417
title: team up 之后 doctor 仍报「本会话加载 0.4.0」——版本记录没人写
agent: dev
category: code
phase: apply
change: -
specs: pm-lifecycle
anchor: openspec/specs/pm-lifecycle/spec.md
deltas: -
branch: task/P417-mark-loaded-at-launch
---

# P417 · 版本记录靠人记得写，于是永远过期

## 现场

用户在 <other-project> 里升到 0.4.1 并 `team up` 重启 PM，doctor 仍报：

```
迁移指引  ! 本会话加载 0.4.0、磁盘 0.4.1：读 …/references/migration.md
$ team version
teamsmith 0.4.1
```

<other-project> 里同样：`pm-loaded.env` 停在 `VERSION=0.3.4`、`AT=2026-10-29`。

## 结论（2026-11-05 改向：不写记录，删掉记录）

这份记录只由 `team mark-loaded` 写，PM 提示词里没有这一步、也没人检查，于是它永远过期，从"提示旧会话"退化成"永久误报"。而它能回答的那件事（"我这个会话加载了哪份 skill"）可以由**已有事实推导**：PM 进程的启动时刻 vs skill 文件的最后修改时刻。既然推导得出来，就别再维护一份会烂的副本。

所以本任务从"启动时写记录"改为**删除这份记录**：

1. 去掉 `pm-loaded.env` 及其写入路径：`team mark-loaded` 命令、`team_loaded_*` 的读写、doctor 的第二条判据（`本会话加载 X`）。`team` 的子命令表、help 文案、`commands.tsv`/`help.*.tsv` 里的条目一并删。
2. **改成推导**：doctor / `team version --check` 比较「PM 进程启动时刻」与「skill 文件的最近 mtime（`SKILL.md` + `extension/*` + `scripts/**` 的顶层文件）」：
   - 磁盘比进程新 → 提示"磁盘上的 skill 在这台 PM 启动之后有改动，`/reload` 或重启 PM"，并给出那个时间；
   - 否则静默（doctor 不该多刷一行）。
   - 没有 PM 在跑时不说会话的事，只说磁盘版本。
3. **红侧**：把某个 skill 文件的 mtime 改到 PM 启动之后 → 提示出现并给出时间；改回 → 静默。删掉推导、退回读旧记录 → 必须红。
4. 删掉断言 `pm-loaded.env` 存在/含 `HASH=` 的那些（`smoke.sh:7289/7290` 一类），换成推导的两侧断言。这是**减法**，报告里写清楚删了哪些断言、哪条新断言顶替。

## 验收（选段，不跑全量）

- `bash skills/teamsmith/tests/smoke.sh --select 11f </dev/null` 与 `--select 3,17`（doctor 面）
- 一次真实流程：`touch` 一个 skill 文件 → `team doctor` 出现提示 → `touch -d` 改回旧时间 → 静默
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P417-dev.md`，提交推分支，通知 PM。**目标 1 小时内**。

## 边界

只改 `lib/cmd-update.sh`、`lib/cmd-project.sh`（doctor 分支）、`scripts/team` 子命令表、help 文案与相关断言。不改 `team version` 的输出格式、不动发布流程。`pm-loaded.env` 若已存在于用户项目里，不需要主动删（不再读它即可）。
