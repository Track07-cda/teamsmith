# P15 · propose: split-teamsmith-init-skill（四件套，零代码）

agent: dev   status: DELIVERED   time: 2026-09-17
branch: `task/P15-propose-split-teamsmith-init`   PR/MR: -（local 模式，分支留 `.worktrees/dev`）

phase: propose —— 只产规划产物 `openspec/changes/split-teamsmith-init-skill/`，未写任何实现代码、未改
SKILL.md/scripts/tests。apply 等 PM 的提案评审（`docs/team/reviews/split-teamsmith-init-skill-proposal.md`）
ACCEPTED 之后再派。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/split-teamsmith-init-skill/proposal.md` | 为什么（E7 三条修正后论点 + 用户拍板、D27 触发条件作废）、拆/不拆边界、轻拆形态、capability 归属、验收命令 |
| `openspec/changes/split-teamsmith-init-skill/specs/init-skill/spec.md` | 新增 capability `init-skill`：6 条 requirement、13 个 scenario，每条 scenario 都点名可跑的证伪器（test/grep/skill-load/fixture 指纹翻转） |
| `openspec/changes/split-teamsmith-init-skill/design.md` | D1 轻拆 / D2 迁移清单（含 workflows.md §A 缩指路，PM 可砍）/ D3 版本与指纹 / D4 软链形态 A / D5 不用 disable-model-invocation / D6 smoke 重排逐类清单（带行号）/ D7 description 编辑方案 + 迁移期承诺与回滚 |
| `openspec/changes/split-teamsmith-init-skill/tasks.md` | 4 组 16 项实施任务，每项带验证命令；附录 A 是 init SKILL.md 问答清单大纲（6 条，收编 E7 §Q3 的 5 个散点并逐条注明出处） |
| `openspec/changes/split-teamsmith-init-skill/.openspec.yaml` | schema: spec-driven，created: 2026-09-17 |

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ spec/pm-lifecycle ✓ change/pulse-console
✓ change/split-teamsmith-init-skill ✓ spec/verification ✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1431  ✗ 0
FAST 模式：跳过 18 个真进程段落 …（完整门禁请不带 TEAM_SMOKE_FAST 重跑）
smoke 全绿
```

- Verdict: **pass**（两条验收命令都在本分支 tip 实跑，输出如上）
- Notes: 这是 propose 任务，spec delta 里的 scenario 描述的是 apply 完成后的可检状态，本阶段刻意不跑它们
  （代码零改动）；任务书验收命令只有上面两条，均绿。

## 事实复核（提案引用的每个数字都在本树重测，非照抄 E7）

| 草稿断言 | 本树实测 | 结果 |
|---|---|---|
| SKILL.md 288 行、description 977/1024、3 条 init 短语 113 字符 | 288 行；977 字符；三短语全部在场 | ✓ |
| smoke 引用计数 SKILL.md 24 / references 74 / bootstrap 32 | 24 / 74 / 32 | ✓ |
| 版本断言 smoke.sh:3210-3211 | 3210 `DOC_V` + 3211 `assert_eq`（详见下文修正） | ✓ 行号对，措辞已修 |
| §0b skill-load smoke.sh:178-189、14b 扫描段 3642-3730、bootstrap.md 互链/CJK 断言 4840/4848 | 行号全部命中 | ✓ |
| `team_skill_hash` = sha256(日常 SKILL.md + extension)（cmd-update.sh:27-31）、TEAM_VERSION common.sh:6 | 逐行核对一致 | ✓ |
| migration.md:77 引用 bootstrap.md；workflows.md §A ~14 行；SKILL.md §New project L24 / §30-second start L49 | 全部命中 | ✓ |
| 既有 12 个 capability 无一覆盖 SKILL.md 内容/description/版本元数据/指纹 | `grep -rn 'TEAM_VERSION\|CHANGELOG\|metadata.version' openspec/specs/` 零命中；'bootstrap' 仅 watchdog 一处且不相干 | ✓ 新增 capability 有据 |

## Decisions and deviations

- **capability 归属**：新建 `init-skill`（brief 已提示「bootstrap 无现成 spec 可能要新增」）。pm-lifecycle 管
  PM 进程存活、watchdog 管巡检，均不覆盖「skill 文档内容/发现入口/版本指纹」这层；grep 证实无重叠，
  全部承诺以 ADDED 进入新 capability，零 MODIFIED。
- **对 brief 的一处措辞修正**：brief 说「`metadata.version` 断言改『两边相等』」，但现行断言
  （smoke.sh:3211）本来就是**三处**一致（common/SKILL/CHANGELOG）。四件套统一写成准确的「扩成
  **四处**一致（common/两个 SKILL/CHANGELOG）」，spec scenario 同步改为 four version strings。
- **超出 E7 最小清单的一项**（已在 proposal/design 中显式标注、PM 评审可砍）：workflows.md §A（~14 行
  初始化命令序列）缩成一行指路，理由 D2——同一份初始化指引留两处必然漂移，且 §A 正被问答清单收编。
- 与 E7 报告的出入：**无**。E7 的「轻拆」清单、§Q4.2 指纹不扩、§Q5 形态 A、§A.8 计数全部原样采纳；
  D27 三条触发条件按用户拍板作废（proposal Why 末节写明）。
- 本 worktree 接手时四件套草稿已在（untracked、未提交）；本次逐条复核事实、修正版本断言口径后提交，
  门禁在本分支实跑见上。

## Suggested next steps

- PM 按 M9.1 的门做提案评审，产出 `docs/team/reviews/split-teamsmith-init-skill-proposal.md`；
  评审清单第 2 条（每个场景都能失败）可重点抽查 spec 里 13 个 scenario 的证伪器命令。
- design D2（workflows.md §A 缩指路）是显式标注的可砍项；若砍，tasks 1.4 跳过一个勾即可。
- ACCEPTED 后再派 apply；apply 任务书需定具体版本号（design Open Questions 已留位）。
