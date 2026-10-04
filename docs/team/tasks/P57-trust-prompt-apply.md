# P57 · 项目信任弹窗不许把夹具判红（并写明它的 UX 后果）

```
task:   P57
agent:  （等席位）
issue:
change: trust-prompt-and-fixtures
specs:  -
phase:  propose
anchor: change
deltas: verification, init-skill
deps:   P54 的 F2（本任务的第一现场）· P40（`team init` 装 `.pi/skills`）· M24/M45（输入框判定夹具）
status: todo（等席位）
budget: 小到中（一个提案包；1–2 条 requirement）
```

> 本地模式：不 push。**只 propose。**

## 现场（P54 的 F2，PM 复核过关键环）

- **宿主上的全量 smoke 红在 §31b2**（"容器里跑真 pi 体检"）：唯一红点是容器里真 pi 的**项目信任弹窗**
  （`Do not trust` / `Do not trust (this session only)`），M24 夹具把它读成**非空输入框**
  → `M45 idle-read=NOT-EMPTY BAD` → 夹具 rc=1 → smoke `✗ 1`。
- **根因链**：Pi 的 `TRUST_REQUIRING_PROJECT_CONFIG_RESOURCES` **含 `"skills"`**
  （PM 复核：宿主 0.87.0 与固定镜像 0.86.0 **都有**这一项）+ **P40 让 `team init` 在项目里装 `.pi/skills`**
  → 没有 trust store 的夹具项目触发弹窗。P54 的归因矩阵（P40 之前的树 rc=0 · 含 P40 不含 P47 的树 rc=1 ·
  改成 `--no-skills` rc=0）把触发物钉在 `.pi/skills` 上。
- **这不是"环境噪声"**：它是**产品功能的真实副作用**——任何项目在 `team init` 之后，**第一次用 pi 打开就会被问信任**。

## 要裁决的两面

1. **夹具侧**：M24/M45 的输入框判定夹具必须能区分"信任弹窗"与"草稿"（要么在夹具里预置信任/`--approve`，
   要么让该夹具用 `--no-skills` 起项目、把"skill 安装面"交给 `install-shape.sh` 验——**给出取舍**）；
   不许用"跳过 §31b2"糊过去（那等于把真红藏起来）。
2. **产品/文档侧**：这个副作用要**写进文档**（`team init` 之后首次运行 pi 会要求信任项目；
   哪个文件/目录触发它；怎么批准），并裁决**要不要在 `team init` 的输出里提示**（例如最后一行"注意：pi 会请求信任本项目"）。

## 硬要求

- policy B：delta 落 `verification`（夹具判定的通用规则：**未预期的整屏弹窗不是"非空输入框"**）与
  `init-skill`（安装步的后果提示）；每条可证伪、MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法；**不写实现**；矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/trust-prompt-and-fixtures/{proposal.md,design.md,tasks.md}` + `specs/*/spec.md`
- 报告 `docs/team/reports/P57-<agent>.md`
