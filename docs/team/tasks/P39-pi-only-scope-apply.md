# P39 · pi-only-scope apply：文档与问句收成 Pi-only，四个键标内部接缝

```
task:   P39
agent:  dev3
issue:
change: pi-only-scope                # 提案已验收：docs/team/reviews/pi-only-scope-proposal.md（ACCEPTED）
specs:  agent-adapters#The contract promises Pi; the launch and notify seam is an internal frozen seam / init-skill#The new-project questionnaire checks Pi's version and its plugins, and asks nothing about adapters / memory-and-deps#The worker-launch keys are an internal frozen seam, not a supported extension point
phase:  apply
anchor: change
deltas: agent-adapters, init-skill, memory-and-deps
grant:  README.md · skills/teamsmith/SKILL.md · skills/teamsmith-init/SKILL.md · skills/teamsmith/references/{agent-adapters,config,migration,troubleshooting}.md · skills/teamsmith/templates/config.sh.tmpl · skills/teamsmith/scripts/monitor.mjs（仅那条降级文案与其注释）· skills/teamsmith/scripts/lib/cmd-config.sh（**只**改那 4 行的自由文本列）· skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts + panel.js 重建（仅当 4 键的说明文字被面板渲染）
deps:   P34（propose，已合并 1f7ea30）· D35
status: todo
budget: 一个工作块；做不完交 PARTIAL
```

> 本地模式：不 push。**设计真源 = `openspec/changes/pi-only-scope/design.md`（D0–D6）+ tasks.md**，
> 以它们为准（尤其 D2 的**宣称面文件清单**、D3 的**自由文本列落点**、D5 的**两棵树渲染 diff**）。

## 硬要求

1. **只改文档与一条诊断文案**：`scripts/**` 的**行为零改动**（除 `monitor.mjs` 那条文案 + 注释、
   与 `cmd-config.sh` 那 4 行的自由文本列）；**不碰**渲染/校验/启动代码；**不需要改任何测试文件**；
2. **禁语必须清零**：`any TUI agent` / `any TUI Agent` / `another TUI agent` / `其它 TUI agent` /
   `任意 TUI agent` 在**宣称面**上不得残留；非 Pi CLI 的每处提及都要带 **frozen 措辞**
   （为将来的非 Pi 适配预留、不承诺兼容、不是受支持的扩展点）；
3. **README §Install 的"另一 TUI agent"那句**：改写为"非 Pi 宿主可用 `install.sh` 把 skill 放到
   `~/.agents/skills`"（去掉"为别的 TUI agent"的承诺）；
4. **init 问卷**：删掉"问用户用哪个 harness"和 omp/其它 CLI 分支，删掉"非 Pi 就填四个键"的指路，
   保留 Pi 版本 floor + `已装插件 packages`；
5. **四个键**：仍在 schema、仍 `apply` 类、行为不变；各行的自由文本列写 frozen 说明；
   `team config list --json` 逐字带出（可断言）；
6. **D5 的零行为证据**：`team dispatch … --print` **本分支 vs 改动前 revision** 两棵树渲染并 `diff`
   （原始输出进报告）；PM 侧引 §6i 的 LEGACY_REF；
7. 小步提交；每批 `TEAM_SMOKE_FAST=1 bash tests/smoke.sh </dev/null` 绿；交付前全量一次。

## 必给的翻转（红→绿原始输出）

- 往 `README.md` 追加一句 `any TUI agent` → 禁语搜索夹具**红**（点名文件行号）→ 还原绿；
- 往 init SKILL 追加 `TEAM_AGENT_CMD` → 问卷夹具红 → 还原绿；
- 把 4 键的自由文本列清空 → `config list --json` 的冻结标注断言红 → 还原绿。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前一次全量
```

## Boundaries

- **不碰**：`scripts/lib/*`（除那 4 行）、扩展、测试文件、`docs/team/**`、`openspec/**`；
- 不改任何行为、不改版本号、**不发 npm**；
- 矛盾/歧义 → `BLOCKED:` 交回 PM。

## Deliverables

- 改动 + 两棵树渲染 diff + 三条翻转原始输出 + 报告 `docs/team/reports/P39-dev3.md`。
