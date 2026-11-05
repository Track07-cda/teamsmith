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

## 现场（用户在 ai_interview 项目里贴的 doctor）

```
迁移指引  ! 本会话加载 0.4.0、磁盘 0.4.1：读 …/references/migration.md
$ team version
teamsmith 0.4.1
```

用户已经把包升到 0.4.1 并 `team up` 重启过 PM，doctor 仍说"本会话加载 0.4.0"。erp 里同样：`pm-loaded.env` 停在 `VERSION=0.3.4`、`AT=2026-10-29`。

## 根因（读实现确认）

`pm-loaded.env` **只由 `team mark-loaded` 写**。SKILL.md 里写着"开局记一次"，但：

- `templates/pm-prompt.md.tmpl` 没有这一步；
- `team up` 起 PM 时不写；
- 没有任何扩展在会话启动时写。

于是 PM 只要没想起来敲这一条，记录就永远是上一个版本。doctor 的判据本身没错（它比的是记录与磁盘），但**记录没人维护**，它就从"提示旧会话"退化成"永久误报"。

## 要做的

1. **`team up` 起 PM 成功后写这份记录**：在确认 PM 进程真的起来（现有 spawn 证明）之后，写 `pm-loaded.env`，版本取**本次启动所用的那份 skill**（即 `TEAM_SKILL_DIR` 的 `TEAM_VERSION`），指纹用 `team_skill_hash`。这不是"猜会话加载了什么"——启动命令里的 `--skill` 与 `-e` 都指向那个目录，两者同一份。
2. **保留人工入口**：`team mark-loaded` 不变（自定义 PM 命令、或会话中途 reload 之后由人补记）。
3. **doctor 不说谎**：记录存在但比 PM 进程启动时间更早（`AT` 早于 `pm.pid` 的进程启动时刻）时，措辞改成"记录早于当前 PM 进程，可能是升级前的残留"，而不是断言"本会话加载了 X"。判据要能从 `/proc/<pid>/stat` 或已有的 starttime 工具取，不要新增状态文件。
4. **红侧**：
   - 删掉 `team up` 里的这次写入 → 那条 doctor 断言必须红（在 0.4.1 的磁盘版本上起 PM，`team version --check` 应报一致）；
   - 把 `AT` 手工改早（早于 PM 启动）→ 措辞必须是"记录早于当前进程"，不是"本会话加载 X"。

## 验收（选段，不跑全量）

- `bash skills/teamsmith/tests/smoke.sh --select 11f </dev/null` 与 `--select 3,17`（doctor 与版本自检面）
- 一次真实流程：改 `common.sh` 的 `TEAM_VERSION` 到 9.9.9 → `team up` → `team version --check` 必须说一致 → 改回
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P417-dev.md`，提交推分支，通知 PM。**目标 1 小时内**。

## 边界

只改启动路径（`lib/cmd-watch.sh` / `common.sh` 的 `team_pm_*`）、`lib/cmd-update.sh` 的 doctor 措辞分支与相关断言。不改 `mark-loaded` 的语义、不动 `pm-loaded.env` 的字段格式。
