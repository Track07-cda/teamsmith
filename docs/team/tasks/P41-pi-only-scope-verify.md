# P41 · pi-only-scope 独立验证（verify 阶段）

```
task:   P41
agent:  dev
issue:
change: pi-only-scope
specs:  agent-adapters#The contract promises Pi; the launch and notify seam is an internal frozen seam / init-skill#The new-project questionnaire checks Pi's version and its plugins, and asks nothing about adapters / memory-and-deps#The worker-launch keys are an internal frozen seam, not a supported extension point
phase:  verify
anchor: change
deltas: agent-adapters, init-skill, memory-and-deps
grant:  docs/team/reports/P41-dev.md · docs/team/reports/P41-dev/**（只写报告与证据，不改实现）
deps:   P34（propose）· P39（apply，均已合并）
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。**apply 是 dev3 做的 → 你来验（D31）。**

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **禁语与 frozen 措辞（R1）**：
   - 在**宣称面**（README / `skills/teamsmith/SKILL.md` / `skills/teamsmith-init/SKILL.md` /
     `references/{agent-adapters,config,migration,troubleshooting}.md` / `templates/config.sh.tmpl` /
     `scripts/monitor.mjs`）搜五种禁语 → **零命中**；
   - 每处"非 Pi CLI"的提及**都带 frozen 措辞**（逐处列出来，别只搜禁语）；
   - **反向**：往 scratch 副本追加一句禁语 → 你的检查必须红（贴原始输出）。
2. **问卷（R2）**：init SKILL 里不得出现 harness 提问、`omp`、其它 CLI 分支、四个键名、
   `agent-adapters.md` 指路；同时必须仍点名 **Pi ≥ 0.76.0** 与 **`已装插件 packages`**。
3. **四个键（R3）**：
   - 仍 `apply` 类、行为不变（**自己跑**：写一个非空 `TEAM_AGENT_CMD` 走 `--print` 渲染 → 仍以 `custom:` 形态生效；
     全部清空 → 内置 Pi 串**逐字节**同改动前）；
   - 冻结标注在 `team config list --json` 里**逐字**带出（4 个键都要看）；
   - **反向**：scratch 里清空标注 → 断言红。
4. **零行为（R1 的硬证据）**：**你自己**复现两版渲染 diff——`git archive <改动前 rev>` 与当前 HEAD
   **落到同一 scratch 路径**、对**同一 fixture** 渲染 `team dispatch … --print`，`diff` **必须空**；
   并复跑 §6i 的 LEGACY_REF 断言（PM 侧逐字节）。
5. **doctor 两行行为不变**：`pi` 行的判定用 `--session-id` 探针（**0.76.0–0.79.0 把 `--help` 写到 stderr
   的形态也要过**）；插件行只报告、不推荐第三方。
6. **无测试文件被改**：`git diff --stat <改动前 rev>..HEAD` 里**不得出现 `tests/**`**（这是提案 D5 的承诺，
   也是"零行为"的第二证人）。

## 至少两条变异（红→绿原始输出）

- 把 `README.md` 的一句 frozen 措辞删掉（留下"非 Pi"提及但无 frozen）→ 你的措辞检查红；
- 把 `cmd-config.sh` 里某个键的标注清空 → JSON 标注断言红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git diff --stat d2b73b8..HEAD | grep -c "tests/"    # 期望 0
```

## Boundaries

- **不改实现**（`README.md`、`skills/**`、`tests/**` 一律不改）；缺陷写清楚交回 PM；
- 变异只在临时副本；不 push；不改 `docs/team/**` 里 PM 的文件。
