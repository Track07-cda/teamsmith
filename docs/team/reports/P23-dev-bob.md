# P23 · change-centric-discipline（propose：提案包四件套）

agent: dev-bob   status: **DONE**（propose 阶段只出规划产物；两阶段验收命令已实跑，不含任何实现改动）
time: 2026-09-20T07:05:00Z
branch: `task/P23-change-change-b-propose`   PR/MR: -（本地模式：不 push，分支留在 `.worktrees/dev-bob`）

change: `change-centric-discipline`（本任务即 propose 阶段；apply 等 PM 的
`docs/team/reviews/change-centric-discipline-proposal.md` 判定 ACCEPTED）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/change-centric-discipline/proposal.md` | Why/What/Capabilities/Impact/验收/边界/报告证据；`1 change : N tasks` 模型陈述与政策 B 的一句话定义 |
| `openspec/changes/change-centric-discipline/design.md` | 四个机制的形状与判定规则、确定性表、规格的家、P18/V18 裁决、归档判据、三个视图表面、PM 清单十条、存量回填逐条表、替代方案、testability 表 |
| `openspec/changes/change-centric-discipline/specs/dispatch/spec.md` | ADDED ×3：单一 change id / change-less 锚点声明 / delta 单写者 |
| `openspec/changes/change-centric-discipline/specs/verification/spec.md` | ADDED ×1：按 change 判 verifier 独立性 |
| `openspec/changes/change-centric-discipline/specs/board-and-status/spec.md` | ADDED ×3：`team change status` 就绪判定 / digest+面板归组 / 归档前提 |
| `openspec/changes/change-centric-discipline/tasks.md` | B1…B8 分批（先只读 ①③、再有拦截语义的 ②、最后模板与文档、末尾门禁），每批带夹具与翻转、覆盖表、路径授权说明 |
| 提交 | `39384a1`（proposal+design）、`bf3aca7`（delta+tasks） |

三个 capability 共 7 条 requirement、35 个 scenario（dispatch 3/17、board-and-status 3/13、verification 1/5）；delta
**全部 ADDED**（不改写任何既有语句，因此没有 MODIFIED 的丢场景风险）。没有新增 capability、没有新增 `TEAM_*`、
没有动任何实现文件。

## Verification evidence (must have actually be run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/change-centric-discipline
…（共 16 项）
Totals: 16 passed, 0 failed (16 items)                       # rc=0

$ git status --porcelain
（空输出）                                                    # 工作树干净

# 试归档（openspec.md §5 的纪律：delta 形状缺陷只有这里看得见）——在 scratch 副本上跑，不碰本仓
$ rm -rf /tmp/p23-trial && mkdir -p /tmp/p23-trial && cp -r openspec /tmp/p23-trial/ \
  && (cd /tmp/p23-trial && openspec archive -y change-centric-discipline)
Specs to update:
  board-and-status: update
  dispatch: update
  verification: update
Applying changes to openspec/specs/board-and-status/spec.md:
  + 3 added
Applying changes to openspec/specs/dispatch/spec.md:
  + 3 added
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 7, ~ 0, - 0, → 0
Specs updated successfully.
Change 'change-centric-discipline' archived as '2026-09-20-change-centric-discipline'

# 现状实测（design §Context 的「measured」断言，不是读码推断）
$ printf 'task:   T9.9\nchange: alpha, beta\nphase:  apply\ndeps:   -\n' > /tmp/p23-brief-1.md
$ printf 'task:   T9.9\nchange: alpha\nchange: beta\nphase:  apply\n' > /tmp/p23-brief-2.md
$ bash -c '. skills/teamsmith/scripts/lib/common.sh >/dev/null 2>&1; \
    echo "comma-list value: [$(team_brief_field /tmp/p23-brief-1.md change)]"; \
    echo "two-line value:  [$(team_brief_field /tmp/p23-brief-2.md change)]"'
comma-list value: [alpha, beta]
two-line value:  [alpha]                                      # 第二行被静默忽略
```

- Verdict: **pass**（两条验收命令 rc=0；试归档 7 条 ADDED 全部落进 `openspec/specs/**`，无 delta 形状缺陷）
- Notes: 本任务**没有实现任何东西**——门禁 `smoke.sh` 未跑（propose 阶段按任务书只跑 validate + 工作树干净；
  apply 阶段的验收命令写在 proposal.md 的 "The apply brief's acceptance" 一节）。`openspec validate` 的
  strict 模式**不检查** scenario 是否有 WHEN/THEN（见 `references/openspec.md` §0 的说明），所以 35 条 scenario
  的可证伪性是写作约定 + 下面的「现状红」对照 + tasks.md 每批的夹具与翻转来兜的，PM 复审时按清单逐条判。

## 现状红：每条 requirement 今天为什么是「空的」（PM 清单第 2/6 条的材料）

| requirement | 今天可观察的现状（红） | 将由哪条夹具钉住 |
|---|---|---|
| dispatch · 单一 change id | `change: alpha, beta` 被原样接受（实测输出 `[alpha, beta]`），两行 `change:` 静默取第一行 | tasks 3.5 的多值/两行夹具 + 3.7 翻转 |
| dispatch · 锚点声明 | 没有任何 `specs:`/`anchor:` 解析；`change: -` 的 brief 照派 | 3.5 的十种 brief 夹具 + 3.7 翻转 |
| dispatch · delta 单写者 | 不存在 `deltas:` 概念，同一 change 的两个任务想写同一 delta 无人拦 | 4.4 的兄弟任务夹具 + 4.6 两组翻转 |
| verification · 独立性 | `team review` 不读任何作者信息；派 `verify` 任务时不比较 `agent:` | 5.4 + 5.5 翻转 |
| board-and-status · `team change status` | 命令不存在（`team change` 无此 verb） | 1.5 的 ready/not-ready/unknown 三种夹具 + 1.6 翻转 |
| board-and-status · 归组 | digest 无 change 段；面板 `changes` 块只有 `done/total`，没有任务 token | 2.3（digest + `__panel-data` + 字节稳定）+ 2.4 翻转 |
| board-and-status · 归档前提 | `team_done_phase_evidence archive` 只看归档目录存在 | 6.3 + 6.4 翻转 |

## Decisions and deviations

1. **规格的家 = 不新增 capability**（brief 点名要裁决）：三条规则分别落在 `dispatch`（brief 契约与所有
   开窗守卫）、`verification`（该 capability 的 purpose 就是独立复验）、`board-and-status`（台账与 done 承诺）。
   新 capability 会把别的 capability 的行为再写一遍；理由与两个被否掉的替代方案在 design §2。
2. **确定性 = 默认拒绝**（brief 点名的第二个裁决）：规则 1 无逃生门（两个 change 的任务不存在合法形态）；
   政策 B / 单写者 / 独立性三条给 `--force` + 一条审计（`team_wlog` → `state/watchdog.log`，与 M9.3 同族）；
   归档前提复用既有的 `TEAM_BOARD_DONE_FORCE=1` + 书面理由。「判不出来」一律响亮放行并点名缺哪个信号（M9.3 纪律）。
3. **P18/V18 裁决：不是例外，采用规则**。任务书的前提（「P18 的 B3 由 verify 写」）在台账里**复现不出来**：
   B3 的提交（`aec2d84`/`98a8837`/`1b034b4`/`171e1a7`/`15997b0`）都在
   `task/P18-apply-console-board-page-mar` 上、trailer 全是 `Agent: dev3`，PM 给 dev3 的 thread（11:33Z）派的
   就是这段收尾；V18（agent `verify`）验证时声明未改任何 `skills/**`、`openspec/**` 或账本。因此 design §5
   的结论是：不设历史例外，规则只约束新派单；若 PM 掌握与 trailer 相反的会话内事实，出路是审计（`--force`）
   而不是静默豁免——这一条请 PM 在提案复审里确认或反驳。
4. **新增两个 header 字段而不是一个**（brief 只点名了 `anchor:`）：`deltas:` 是单写者守卫的判据，
   `-`（明说不写）与**缺失**（未知 = 该 change 的全部 delta）语义不同——沉默不算声明。字段语法与三处刻意的
   不对称在 design §1。
5. **存量回填 = 一个 backfill change + M48/M50 各自的 change**（brief 点名的第三个裁决）：六条已上线的规则
   （M36/M41/M43/M44/M45/M46）文本已被既有断言钉死，适合一个 backfill change（其 apply 是誊写 + 与断言对账，
   独立复验是文本 vs 断言）；M48/M50 的规则还是计划，文本没有断言可钉，混进同一个 change 会让一份复验记录同时
   承担两种不同性质的断言——所以各自成为一个 change（`board-duplicate-identity` / `read-cost-budgets`）。
   逐条表（含每条的能力归属、ADDED/MODIFIED、以及「文本只能比断言窄」的实例）在 design §9。
6. **任务书 `specs: -` 与三 capability 的差异**：brief 头写 `specs: -`（propose 阶段不指向既有 requirement），
   但 Brief 的"要提案化的四条规则"自然落在三个既有 capability 上（brief 自己也举例了 `verification`/
   `board-and-status`）；这不算越界，因为 propose 只写 change 目录自己的 delta，没有动 `openspec/specs/**`。
7. **未做的事**（边界）：没有改任何实现脚本/模板/测试/面板，没有改 `AGENTS.md`、`docs/team/DECISIONS.md`，
   没有触碰 M47/M48/M49/M50 的文件区域，没有 push（本地模式），没有 merge。
8. **注意到但没动的两处**：① `M48` 的看板聚焦改动与 `panel` 规格里「focused card … SHALL be tracked by entry
   id」条款冲突，所以那张表的建议是 **MODIFIED** 而不是 ADDED；② digest 现有段落编号里 `[5]` 出现两次
   （`[5] 任务板` 与 `[5] 建议`），新段用 `[6]` 避开改号——这是一处既有的小瑕疵，本任务不顺手改（PM 的地盘）。

## Suggested next steps

1. **PM 提案复审**（`docs/team/reviews/change-centric-discipline-proposal.md`）：十条清单里第 9/10 条是本 change 新增的；
   请特别确认第 3 条（P18/V18 前提）——它决定规则 3 有没有历史例外。
2. 复审 ACCEPTED 后按 tasks.md 顺序派 B1→B8；每个 apply brief 要**显式授权** PM-owned 路径
   （`scripts/**`、`references/**`、`templates/**`、`SKILL.md`、`AGENTS.md`），`skills/teamsmith/tests/**` 是 `agent:dev` 的。
3. 与本 change 落地同时要安排的三个后续 change（design §9）：`spec-backfill-runtime-guards`（六条已上线规则补账）、
   `board-duplicate-identity`（M48）、`read-cost-budgets`（M50）。注意 M47（`wip`）与 M48/M50 的 brief 在新
   anchor 规则生效后会**被拒绝**，派单前先按 design §9 的两条备注改 brief（M47 属合法 infra）。
4. 本 change 落地后，`docs/team/DECISIONS.md` 的 D31 可以从「用户决定」升级为「已落成机制 + 存档的 proposal
   评审记录」——由 PM 决定何时写。
