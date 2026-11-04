---
id: P407
title: 把 CI 的 OpenSpec 钉到 1.16.0，并把门禁改成非 strict（附烧掉 237 条长需求的清单）
agent: dev2
category: code
phase: apply
change: -
specs: -
anchor: none (infra) — 工具链版本与门禁口径，不改产品契约
deltas: -
branch: task/P407-openspec-116
---

# P407 · 单一版本 1.16 + 暂时非 strict

用户 2026-11-04 决策 B：**OpenSpec 全链路统一到 1.16.0**，门禁暂时用 `openspec validate --all`（非 strict），把 1.16 新判为 warning 的 237 条长需求作为清单分批烧掉，烧完再把 `--strict` 打开。

## 背景（已实测）

- 本机 CLI 已是 1.16.0，`.pi/prompts/`、`.pi/skills/` 的相位面也已是 1.16 生成的；
- 但 `ci/Containerfile` 的 `OPENSPEC_VERSION=1.8.0`，于是 CI 与本地**版本错配**：PM 按 1.16 的指令（`sourcePath`/`line`、`store`、项目检查）读 1.8 的输出；
- 1.16 把"需求文本 >500 字符"从提示升为 warning、`--strict` 判失败；当前 237 条命中，非 strict 下 20/20 通过。

## 要做的

1. `ci/Containerfile`：`ARG OPENSPEC_VERSION=1.8.0` → `1.16.0`；文件头那句 `openspec 1.8.0 ... --strict` 的注释同步改成 1.16.0 + 非 strict 现状与原因。
2. `ci/Containerfile` 的 `CMD`：`openspec validate --all --strict && bash …` → `openspec validate --all && bash … </dev/null`（与 `.pi/team/config.sh` 的 `TEAM_GATES` 现已一致）。
3. `.github/workflows/gates.yml` 里描述镜像内容的那句注释（"openspec 1.8.0"）同步。
4. `CONTRIBUTING.md` 里那条门禁命令：保留 strict 作为**目标态**的写法，但加一行说明本仓当前跑非 strict、原因是 237 条长需求待烧、清单在 `docs/team/tasks/P408-spec-burn-down.md`。
5. **不改** `skills/teamsmith/templates/*` 与 `SKILL.md`/`references/*` 里 strict 的推荐口径——那是对**其他项目**的产品默认，1.16 下新项目应当按 strict 写。若你判断某处必须改，先在报告里说明为什么，不要顺手改。

## 红侧 / 断言

- `workflow-entry.sh` 与 `smoke.sh` 里断言"文档写明 `openspec validate --all --strict`"的用例必须仍然绿（模板口径没变）；
- 你自己的验证要能证明 CI 的 `CMD` 与 `TEAM_GATES` **逐字一致**（把两者都抓出来比，别肉眼比）。

## 验收（自己跑，贴 rc 与输出尾）

- `openspec validate --all` → 20/20（1.16.0，非 strict）
- `bash skills/teamsmith/tests/workflow-entry.sh --select …`（选到那条门禁断言）
- `bash skills/teamsmith/tests/smoke.sh --select 39 </dev/null`（或覆盖文档断言的段）
- `section-select.sh --check`、`ledger-ban.sh --names-file .pi/team/forbidden-names.txt`、`git diff --check`
- **容器镜像不要求你真建**（本机 podman 需经宿主机），但要在报告里写清"镜像未重建，因此 1.16 的层未实测"，不许写成已验证
- 报告 `docs/team/reports/P407-dev2.md`，提交推分支，通知 PM

## 边界

- 只改 `ci/Containerfile`、`.github/workflows/gates.yml`、`CONTRIBUTING.md`。
- 不改规格文本、不动 `.pi/`、不跑全量 smoke、不合并/归档/发布。
