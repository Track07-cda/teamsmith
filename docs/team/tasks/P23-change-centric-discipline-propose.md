# P23 · change 为中心的派单纪律（propose）

```
task:   P23
agent:  dev-bob
issue:  
change: change-centric-discipline      # 本任务为 propose 阶段：写提案 + design + delta + tasks.md
specs:  -
phase:  propose
deps:   -                              # D31 用户决定（见 docs/team/DECISIONS.md）
status: todo
budget: 一个工作块（只出提案包，不写实现）
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev-bob`。
> **本任务只做 propose**：提案、design、delta specs、tasks.md。**不要**实现任何脚本/面板/测试。

## 背景（用户决定，原话）

> 「agent 按照 change 做，不要在一个任务中包含多个 spec change。B 方案」

已记录为 `D31`。要落成**可执行、可证伪**的机制：

**模型**：`1 change : N tasks`（允许不同 agent / 多批 / 返工再出任务）；反向 **`1 task : 0..1 change`**。
- change = 契约与派单的单位；task = change 内部的阶段/批次单位；brief 头 `change:` + `phase:` 是外键。
- 无 change 的 task 只允许：环境/CI/工具链、纯内部重构、文档与夹具 —— 且 brief 必须写明 `anchor: none (infra)` 及理由。

**政策 B（强制锚点）**：凡「跨任务必须成立」的规则（**静默失败 / 破坏性动作 / 越权 / 身份 / 门禁 / 性能契约**）
必须在规格库有 requirement+scenario 锚点。brief 要么指向**真的改了 delta** 的 change，
要么写明 `specs: <capability>#<requirement>`（被现有 requirement 覆盖）。PM 在提案审查里拒收无锚点的跨任务任务。

## 要提案化的四条规则（每条都要 requirement + 可证伪 scenario）

1. **change 数量为 1**：brief 的 `change:` 只能是一个 id 或 `-`；多值/逗号/多个字段一律拒绝（派单时与审查时都应拦住）。
2. **delta 单写者**：同一 change 的多个未结束任务**不得同时改同一份 delta/spec 文件**——派单时检测并默认拒绝
   （点名冲突任务与文件；给 `--force` + 审计的逃生门）。
3. **不许自己验自己（按 change 判定）**：verifier **不得**是该 change **任一** apply 任务的作者
   （现在只按单个任务判，历史上 P18 的 B3 由 verify 写、V18 又由 verify 验 —— 记录为**有意的例外**还是修掉，由提案裁决并写明）。
4. **归档前提 = 该 change 的全部任务 done 且有复验**：不是第一个任务 done。给出可见的「change → 任务 → 状态/复验」清单，
   并明确 PM 归档前的核对动作（机读 + 人读两条）。

配套的三个机制（design 里给出形状与 testability，**本任务不实现**）：

- **① change 归组视图**：`team digest` / 面板按 brief 的 `change:` 归组：`change X → 任务 M1( done) / M2(wip) / V1(PASS)`；
- **③ `team change status <id>`**（或 doctor 的一段）：列出该 change 的全部任务、各自 board 状态、复验记录与 delta 文件，
  给出 **ready / not-ready** 判定及缺项；
- **② 派单守卫**：(a) 一个任务带多个 change → 拒；(b) 与未结束任务共享 change 且要改同一 delta/spec 文件 → 拒（`--force` 可覆盖 + 审计）；
  (c) change 缺失且没有 `anchor: none (infra)` 理由 → 警告（是否升格为拒绝由提案裁决）。

## 提案要顺带裁决的事

- **规格的家**：新增 capability（如 `openspec-pipeline`）还是并入既有 `verification` / `board-and-status`？给出理由与 delta 形状；
- **确定性**：这些机制是"默认拒绝 + 逃生门"还是"警告"？哪些必须硬拦（安全类）哪些只警告（流程类）；
- **PM 审查清单**：B 的可执行形式（写进 `references/openspec.md` 的清单，PM 逐条可判）；
- **存量回填**：M36/M41/M43/M44/M45/M46/M48/M50 这 8 个 `change: -` 任务里，哪些属跨任务规则需要补锚点、
  哪些属 infra 可豁免 —— 给出**逐条表**与建议的回填方式（一个 backfill change？还是各归各的 capability 补 requirement？）。
  注意：M41/M43/M45/M46 的语义已由 smoke 断言固定，回填要求「spec 文本与既有断言一致」，不得凭记忆写。

## Deliverables

- `openspec/changes/change-centric-discipline/proposal.md`（Why/What/Impact，含 `1 change : N tasks` 模型陈述）
- `.../design.md`（四个机制的形状、判定规则、逃生门、testability、替代方案与取舍）
- `.../specs/<capability>/spec.md`（delta：ADDED/MODIFIED/REMOVED 明确标注）
- `.../tasks.md`（B1…Bn 分批：先 read-only 的 ①③，再有拦截语义的 ②，最后文档/清单；每批带夹具与翻转要求）
- 报告 `docs/team/reports/P23-dev-bob.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict      # 必须全绿（含本 change 的 delta）
git status --porcelain                                            # 工作树干净
```

## Boundaries

- **只 propose**：不改 `skills/teamsmith/**` 的任何脚本/面板/模板/测试，不改 AGENTS.md（那是 apply 阶段的事）。
- 不改 `docs/team/DECISIONS.md`（PM 的地盘）；需要写的决定写进 proposal/design。
- 不碰 M47/M48/M49/M50 在改的文件区域；不 push；不 merge。
