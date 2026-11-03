---
id: P402
title: 既有项目上 init 渲染受管块时要用契约里的会话名与名册，而不是目录名和硬编码默认
agent: dev
category: code
phase: apply
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: init-skill
branch: task/P402-init-render-from-config
---

# P402 · 受管块不能写进假事实

## 现象（PM 2026-11-03 在本项目实测，不是推测）

本项目 `.pi/team/config.sh` 里 `TEAM_SESSION="teamsmith"`、`TEAM_AGENTS="dev verify dev2 dev3 dev-bob"`。跑 `bash skills/teamsmith/scripts/team init --no-skills`（既有合法契约，正常跳过 config）后，刷新出来的受管块写的是：

- 第 4 行 `` A **PM (orchestrator)** in tmux `pm-skills:pm` `` —— 会话名变成了目录名；
- 第 5 行 `Roster: dev verify` —— 名册变成硬编码的两个席位。

只有显式 `--session teamsmith --agents "dev verify dev2 dev3 dev-bob"` 才渲染正确。原因在 `skills/teamsmith/scripts/lib/cmd-project.sh`：`session="${session:-$project}"`、`agents="${agents:-dev verify}"` 在**已有契约**时也没有回落到契约值。

后果不是排版问题：受管块是 agent 读到的"PM 在哪、有谁"的权威说明，写错就是文档撒谎。2026-10-30 那次现场 init 事故里同样的两个值也变成了默认。

## 要做的（窄）

1. 既有合法契约存在且用户**没有**显式给 `--session`/`--agents`/`--pm-model` 等对应参数时，渲染用的 `SESSION`、`AGENTS`、`PM_WINDOW`、`DOCS_DIR`、`GATES` 取自**契约里的现值**，而不是目录名与硬编码默认。显式参数仍然优先（`--force` 重建契约时也按显式参数/新默认，语义不变）。
2. 新建项目（无契约）的行为不变。
3. 不许新增命令、旗标、配置键或"修复"启发式；只改取值的回落顺序，并复用现有的契约读取函数（不要再写一套解析）。

## 红侧必须留下

- 一条具名断言：既有契约 `TEAM_SESSION=X`、`TEAM_AGENTS="a b c"` 的项目里跑**裸** `team init`，受管块必须写出 `X` 与 `a b c`；把回落顺序改回"目录名/硬编码默认"，该断言必须变红，还原即绿。
- 一条对照组：无契约的新项目裸 init 仍写目录名与默认名册（证明不是把两条路径合并成一条）。
- 既有 `install-shape.sh` / smoke §17 的相关行不许删、不许把断言放宽成"包含某个子串就算过"。

## 验收（自己跑，贴 rc 与输出尾）

- 上面三条（红、绿、对照）各自的命令与输出。
- `bash skills/teamsmith/tests/install-shape.sh`（完整矩阵，`flip` 段用 `bash skills/teamsmith/tests/install-shape.sh flip`，不是 `--flip`）
- `bash skills/teamsmith/tests/smoke.sh --select 17 </dev/null`
- `openspec validate --all --strict`（用 `~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P402-dev.md`，提交推分支，通知 PM。

## 边界

- 只改 `skills/teamsmith/scripts/lib/cmd-project.sh` 的取值回落与相应测试；不动 P400 的标记扫描/写入范围、不动模板内容、不改 P401 的提示词。
- 不对真实项目跑 init（PM 已在本项目手工跑过，不走这条路径验证）、不合并/归档/发布。
