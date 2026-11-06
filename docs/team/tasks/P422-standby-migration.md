---
id: P422
title: 待命开关迁移到统一状态（agent-self-reminder 1.3）
agent: dev
category: code
phase: apply
change: agent-self-reminder
specs: agent-self-reminder
anchor: openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md
deltas: -
branch: task/P422-standby-migration
---

# P422 · 待命开关只有一个地方能写

用户 2026-11-06 授权。做 `openspec/changes/agent-self-reminder/tasks.md` 的 **1.3**。

## 现状（已核对）

- 待命标记是 `state/standby`（`common.sh:4721` 的 `team_standby_file`；`team_standby_on/off/is_on/in_standby` 四个函数）。
- 统一状态（`state-authority.mjs`）里**已有** `standby: { on, generation, reason, since }` 字段与校验，但**没有读写者**——这就是要接上的那一步。
- `state/standby` 目前不存在（团队当前是待命，用户说的“开着”是指 standby on，实际文件可能在恢复后已清；以你读到的现场为准）。

## 必须成立

1. **唯一写点**：所有待命读写都走统一状态的事务（`state-authority.mjs`），不能再有第二个文件被当成真相。`team_standby_file` 这类直接读写 `state/standby` 的路径要改走权威层。
2. **原子迁移**：已有 `state/standby` 时，把它**一次性**搬进统一状态（保留 `reason`、`since`），随后旧标记失效；重复跑迁移必须幂等，不能反复加代次、不能丢原因。
3. **旧读取路径仍对**：`team standby on/off/status` 的行为与文案保持可读（用户看到的只是开关），但读的是统一状态；在迁移前已存在的旧标记要被认出来并迁移，不能当作“没有待命”。
4. **没有 `flock` 时显式失败**：写待命失败要报可读错误并停住，不许“当作关掉了”。
5. **不改变当前待命语义**：迁移本身不能把一个待命的团队弄成非待命，反之亦然；`generation` 从 0 起，迁移不代次 +1。

## 红侧（每条都要能红）

- 旧标记存在时迁移：原因/时间保留，旧文件不再被当成真相；
- 迁移重复跑：状态不变、代次不变；
- 把迁移改成“忽略旧标记”→ 必须红；
- 把读写改回直接写文件 → 必须红（读不到统一状态的改动）；
- 缺 `flock` → 显式失败，不是静默成功。

## 验收（选段，不跑全量）

- 新增/扩展的权威层测试（`bash skills/teamsmith/tests/state-authority.sh`）与提醒 CLI（`bash skills/teamsmith/tests/remind-cli.sh`）
- `bash skills/teamsmith/tests/smoke.sh --select 11b,11b3,11b4,66,67`（待命相关段与权威/提醒段；11b3 若因提示词缺模型而红，写明真因）
- `openspec validate --all`、`spec-refs.sh --check`、`section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- 报告 `docs/team/reports/P421-dev.md`，提交推分支，通知 PM

## 边界

- 只改待命读写与迁移；**不做**提醒投递、不做模型侧工具注入、不改 Pulse 巡检节奏。
- 不动 `openspec/changes/agent-self-reminder/` 的规格文本；不改当前团队的待命状态本身（迁移只在夹具里演示，真实状态由 PM 在合并后按同一命令执行一次并核对）。
- 不合并/归档/发布。
