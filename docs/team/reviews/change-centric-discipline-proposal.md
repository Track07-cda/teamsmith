# change-centric-discipline · PM proposal review

time: 2026-09-20T07:2x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  change-centric-discipline
owner:   dev-bob（propose）
tip:     486d624（task/P23-change-change-b-propose）
```

## Commands run (real output)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
  → Totals: 16 passed, 0 failed (16 items)          # exit 0
$ git -C .worktrees/dev-bob status --porcelain | wc -l      → 0
$ grep -c '^### Requirement' openspec/changes/.../specs/*/spec.md → 3 + 3 + 1 = 7 wait…
   实测：board-and-status 3 条、dispatch 3 条、verification 1 条，共 7 条 requirement / 35 个 scenario
# 我另核的两条事实：
$ sed -n '2429p' skills/teamsmith/scripts/lib/common.sh
  → team_task_change() 只读 brief 的第一条 change: 行，多值/重复/拼错都静默通过（提案的 Why 成立）
$ git log -1 --format='%b' aec2d84 98a8837 171e1a7 | grep Agent:
  → 三条 P18/B3 提交的 trailer 都是 Agent: dev3
```

## Findings

1. **模型与四条规则（proposal §What Changes / delta ×7 条 requirement）— PASS。** 每条都落在既有 capability 上
   （`dispatch` / `verification` / `board-and-status`），delta 全为 ADDED、不重述既有 requirement；
   四个守卫的硬拦/警告边界明确：规则 1（一任务一 change）**无逃生门**，锚点/单写者/自验/归档四条是
   `--force` + 一行审计。
2. **35 个 scenario 可证伪 — PASS。** 逐条看了一遍，都是"可观察量 + 具体现场"（例如「同一 change 的两个未结束任务声明同一 delta → 点名拒绝”、
   「`anchor: none` 无理由 → 拒」、「verifier 是 apply 作者之一 → 拒」、「归档阶段任务在兄弟任务未结束前不能 done」）。
3. **提案改正了我的一处事实错误 — 接受，并向作者致意。** 我在 P23 任务书里写「P18 的 B3 由 verify 写、V18 又由 verify 验」，
   它用提交 trailer 反驳：B3 的三条提交是 `Agent: dev3`，V18 才是 verify 跑的 —— **我核了 trailer，作者是对的**；
   design §9 据此把「不许自己验自己」定为**按 change 判定**且 P18/V18 **不构成例外**。
4. **回填表（design §9）— PASS。** 八条 `change: -` 任务逐条给 class / 推荐的家 / 固定文本的证据（含 `smoke.sh:533` 这类行号），
   并给出**两段式**建议：六条已落地规则合成一个 backfill change（文本与既有断言对照），**M48/M50 各起一个 change**
   （它们还是计划，不能与已发生的事实共用一份复验）；`M47` 明确判为合理 infra，写 `anchor: none (infra) — …`。
5. **PM 审查清单（design §8）— PASS。** 把 B 落成 `references/openspec.md` 的第 9、10 条（一任务一 change / 锚点存在），
   判据是"能在文件上判定"，并且明写「跨任务规则不许自称 infra」——这正是 B 要防的偷懒口。
6. **tasks.md 分批（7 批 + 门禁节）— PASS。** 先只读的 ①③（B1/B2）、再有拦截语义的 ②（B3/B4/B5/B6）、最后模板与文档（B7），
   每批带夹具与翻转；B7 覆盖 `references/openspec.md`/`protocol.md`/`SKILL.md`/`AGENTS.md` 与模板。

## Transition note (PM-owned, recorded here)

三个在飞任务**早于 D31**：`M47`（infra，按 §9 补 `anchor: none (infra) — …`）、`M48`、`M50`（各需自己的 change）。
处理：**让其按原样落地**（它们已派单、有独立复验），随后按 design §9 的建议起 `board-duplicate-identity` 与
`read-cost-budgets` 两个 change、以及 `spec-backfill-runtime-guards` 回填 change；在 P24 的实现落地后，
再派单时会受新守卫约束（届时这三个 brief 必须先补齐锚点）。此例外**不在 P18/V18 那一类**（那是按 change 判定的规则本身），
而是**规则生效前已在执行的工作**，已在 D31 里写明。
