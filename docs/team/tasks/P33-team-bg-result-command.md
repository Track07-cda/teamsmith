# P33 · team_bg_run 的结果里带上原始命令（太长缩略）

```
task:   P33
agent:  dev2
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) —— team-bg 扩展的**工具输出文本**（工具面；spec 库里没有 team-bg 的家，
        本次改动是显示层，不改作业语义/生命周期/台账）
deps:   M27（team-bg 实现）· M30（worktree 根修复）
status: todo
budget: 小（一个提交 + 一处夹具断言即可）
```

> 本地模式：不 push。

## 用户反馈（2026-09-22）

`team_bg_run` 的结果现在只有：

```
job <id> started (pid N); log: <path>
Harvest it with team_bg_wait <id>.
```

**看不到"我到底跑的是什么命令"**。要加一行原始命令，**太长可缩略**。

## 要做的（照这个形状）

1. `skills/teamsmith/extension/team-bg.ts`（结果文本在 `:263` 附近）：
   - 文本里加一行命令：`  cmd: <命令>`；
   - **单行化**（换行 → 空格、压掉多余空白）——多行命令也要一眼能读；
   - **缩略**：超过 **100 个码点**就截断并加 `…`；**必须按码点切**，不许把一个 CJK 字符/代理对切成半个
     （P28 的教训：字节切会造出非法 UTF-8）；
   - `details` 里也带上 `cmd`（原样，不缩略）——`team_bg_wait` 与夹具都用得上；
   - `team_bg_wait` 的回执头一行也点名命令（同一形状；若改动超过两行就跳过并在报告里说明）。
2. **夹具**：`tests/team-bg-harness.mjs`（或 `tests/team-bg-flip.sh`）加断言：
   - 短命令：文本里有 `cmd: <命令>`、`details.cmd` 原样；
   - **长命令（>100 码点、含 CJK）**：文本里是缩略 + `…`、**末字符是完整码点**（不许半个字）、`details.cmd` 仍原样；
   - 带换行的命令：文本里是单行（无换行）。
3. 文档：若 `references/` 里有 team-bg 的用法段（troubleshooting 或 agent-adapters），补一句"结果里带命令"。

## Acceptance

```sh
node skills/teamsmith/tests/team-bg-harness.mjs
bash skills/teamsmith/tests/team-bg-flip.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Boundaries

- 只碰 `skills/teamsmith/extension/team-bg.ts` + 上述两个测试文件（+ 必要的 `references/` 一句话）；
- **不改**作业语义：id/pid/log 路径/台账/收割/裁剪/工作树根解析一律不动；
- 不 push；不改 `docs/team/**`。

## Deliverables

- 实现 + 夹具断言 + 报告 `docs/team/reports/P33-dev2.md`（含**缩略前后**的原始文本对照、
  长命令那条的码点边界证据、以及 harness 的结果行）。
