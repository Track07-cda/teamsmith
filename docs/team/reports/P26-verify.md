# P26 · 门禁卫生（propose：提案包四件套）

agent: verify   status: **DONE**（propose 阶段只出规划产物；不含任何实现改动）
time: 2026-09-20T10:23:34Z
branch: `task/P26-propose`   PR/MR: -（本地模式：不 push，分支留在 `.worktrees/verify`）

change: `gate-hygiene`（本任务即 propose 阶段；apply 等 PM 的
`docs/team/reviews/gate-hygiene-proposal.md` 判定 ACCEPTED）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/gate-hygiene/proposal.md` | Why/What/Capabilities/Impact + 验收命令原文 + 边界 + 「什么会翻转」+ 报告证据清单 |
| `openspec/changes/gate-hygiene/design.md` | 事故证据（M49/M47/V16 实测数字与文件行号）、队列机制的取舍、`ran=` 词表约束、负载阈值校准、skip 的证据路径、testability 表、风险 |
| `openspec/changes/gate-hygiene/specs/verification/spec.md` | ADDED ×1（5 个 scenario）：硬超时只覆盖「跑」，排队单列、有独立上限、超限大声失败点名持锁者、wrapped 祖先不重复排队、无 flock 要打印 |
| `openspec/changes/gate-hygiene/specs/panel/spec.md` | MODIFIED ×1（基线 3 个 scenario 原文逐字保留 + 新增 3 个）：两条红线加负载前提 `loadavg_1m ≤ 0.75 × 核数`，忙机可见 SKIP（打印实测值 + load），安静机红线不放宽 |
| `openspec/changes/gate-hygiene/tasks.md` | 五个 apply 批次 G1–G5，25 个可验证条目（每条带夹具与翻转）、覆盖表、路径授权、夹具纪律 |
| 提交 | `d6cec6f`（proposal+design）、`e3dffa5`（delta specs+tasks） |

规模：2 个 capability、2 条 requirement、11 个 scenario（verification 5 / panel 6 = 基线 3 + 新 3）。
没有新 capability、没有新 `TEAM_*` 键、没有动任何实现文件；propose 只写
`openspec/changes/gate-hygiene/**`。

## Verification evidence (must have actually been run)

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ change/change-centric-discipline
✓ spec/delivery-guard
✓ spec/dispatch
✓ change/gate-hygiene
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)          # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） ==
  ✓ 33 config-cli.sh 全绿（122 条断言）
      == 结果 ==  ✓ 116  ✗ 0  SKIP 0
== 15 · 完成 ==
   （全流程已在 0–14 节覆盖）
== 结果 ==  ✓ 1876  ✗ 0
FAST 模式：跳过 24 个真进程段落（1c·M11 真沙盒窗口|…|32⑧·spawn 清洗（真窗口））——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿                                         # rc=0，实测 286.8s

$ git status --porcelain
（空输出）
```

- Verdict: **pass**（brief 的三条验收命令全部实跑）。
- 未验证的内容，明确说清：① 全量 smoke 没跑（brief 只要求 `TEAM_SMOKE_FAST=1`）；它是 apply 阶段的
  验收命令，G5 里写着；② 下面「机制级复现」不是 `team review` 的端到端跑（端到端要等实现落地），
  它用与 `cmd-review.sh:479` 相同的 GNU wrapper 选项复现了「排队算进超时」的形状，已在文中标注；
  ③ M49 的 `reviews/M49-verify.log` 是被 `.gitignore` 排除的本地日志，仓里可核对的证据是
  PM 写进 `docs/team/reviews/M49.md` 的收口段（line 355-360）。

### 试归档（delta 形状缺陷只有这里看得见：MODIFIED 不许丢 scenario）

```sh
$ rm -rf /tmp/p26-trial && mkdir -p /tmp/p26-trial && cp -r openspec /tmp/p26-trial/ \
    && (cd /tmp/p26-trial && openspec archive -y gate-hygiene)
Task status: 0/25 tasks
Warning: 25 incomplete task(s) found. Continuing due to --yes flag.
Specs to update:
  panel: update
  verification: update
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 1, ~ 1, - 0, → 0
Change 'gate-hygiene' archived as '2026-09-20-gate-hygiene'      # rc=0
```

`- 0` 是关键：panel 的 MODIFIED 块没有丢掉基线 requirement 的任何 scenario（3 个原文保留 + 2 个新增）；
`0/25 tasks` 是 propose 阶段的正常状态（任务书条目由 apply 勾）。

### 机制级复现：今天「排队算进超时」，提案后「排队在时钟外」

`cmd-review.sh:479-499` 把整个门禁命令包进 `timeout`，并只量一个区间（`gate_elapsed`）；而全量 smoke 的
排队在门禁**内部**（`smoke.sh:94-116` 的 `exec flock --close -w`）。用与 review 相同的 wrapper 选项、一个
3s 的持锁夹具和 3s 的门禁桩（1/100 比例的 M49：930s 排队 + 870s 门禁 / 1800s 上限）：

```sh
$ bash /tmp/p26-mech.sh
current  rc=124 wall=5s     # 5s 预算被 3s 排队吃掉，门禁跑 2s 就被 TERM（wrapper 124 → 今天的 TIMEOUT）
proposed rc=0   wall=6s     # 3s 排队在时钟外；3s 运行 < 5s 上限 → PASS
```

（`current` 行是今天的形状；`proposed` 行是本 change 要实现的形状。端到端的红/绿夹具写在
`tasks.md` G1 1.5/1.6 与 G5 5.3。）

### `ran=` 为什么不写进粗体 token（设计偏差的实测依据）

`team_review_verdict`（`common.sh:2365`）用 `grep -m1 -oE '判定: \*\*[A-Za-z]+\*\*'` 解析记录：

```sh
$ printf '判定: **TIMEOUT(ran=2s)** · queued 930s / ran 870s / limit 1800s\n' | grep -m1 -oE '判定: \*\*[A-Za-z]+\*\*'
（无匹配 → 解析结果为 none：记录会被当成「没有判定行」）
$ printf '判定: **TIMEOUT** · queued 930s / ran 870s / limit 1800s\n' | grep -m1 -oE '判定: \*\*[A-Za-z]+\*\*'
判定: **TIMEOUT**                                            # → TIMEOUT
```

所以 brief 的 `TIMEOUT(ran=…)` 落成「闭合 token + 记账字段」，spec 里同时钉住两条断言。

### 负载阈值校准（0.75 × 核数 的来历）

```sh
$ awk 'BEGIN{cores=32; printf "cores=%d threshold=%.2f\nM49 load 26..32: %s\nV16 load 7..8: %s\n", \
    cores, 0.75*cores, (26>0.75*cores?"skip":"judge"), (7>0.75*cores?"skip":"judge")}'
cores=32 threshold=24.00
M49 load 26..32: skip
V16 load 7..8: judge
```

M49 的假红发生在 **32 核机器 load 26–32**（`reviews/M49.md` 收口段：中位 4942ms；五个样本
6335/4942/4436/5339/2880 见 P26 任务书的引用）；brief 举例的 `≤ 核数` 会**照旧判红**，正好复现这条 change 要消灭的假红，
所以阈值取 0.75×（本机 24）。V16 那次 load 7–8 的单次越线由既有的 5 次中位吸收（`smoke.sh:8755-8760`
的注释记了这段历史）。

## Requirement → task 覆盖

| Requirement | scenarios | 条目 |
|---|---|---|
| `verification` · The hard timeout covers the gate run, not the queue (ADDED) | 5 | G1: 1.1–1.7 |
| `panel` · Frame assembly is asynchronous… (MODIFIED) | 6（基线 3 + 新 3） | G2: 2.1–2.5；G3: 3.1–3.4 |
| FAST/全量资源纪律与锁的 why（brief C，**按决定不进 spec**） | — | G4: 4.1–4.4 |
| 门禁、翻转、试归档与真实路径证据 | — | G5: 5.1–5.5 |

每个 scenario 在今天的树上「红在哪、将来由哪个夹具钉住」，逐条写在 `design.md` 的 Testability 表里
（8 行，含每条翻转的破坏手法）。

## Flip evidence

本任务不是 defect-fix，按 dispatch 的规则不强制翻转小节；但提案的中心论断都有实测红证据：

- **今天的假 TIMEOUT**：`/tmp/p26-mech.sh` 机制复现 `current rc=124 wall=5s`（红）→
  `proposed rc=0 wall=6s`（绿），见上；端到端红/绿夹具在 G1 1.5/1.6。
- **解析器陷阱**：`**TIMEOUT(ran=2s)**` → 解析 `none`（红）→ `**TIMEOUT**` + 记账 → `TIMEOUT`（绿），见上。
- **负载前提**：M49 的 26–32@32 核 → `skip`；V16 的 7–8@32 核 → `judge`；安静机人为慢帧必须红
  （G2 2.4b / G3 3.3b 的夹具），忙机同注入必须 SKIP（G2 2.4a / G3 3.3a）。
- **MODIFIED 丢 scenario 的守卫**：试归档输出 `Totals: + 1, ~ 1, - 0`（`- 0` = 没有 scenario 被丢）。

## Decisions and deviations

1. **`TIMEOUT(ran=…)` 不写进粗体 token**（brief 的字面写法）：证据见上，字面写法会让
   `team_review_verdict` 返回 `none`（记录看起来「没有判定」比多一行记账糟得多）。spec 同时要求
   「闭合 token」与「TIMEOUT 必须带 `ran=Ns`」，两条都可断言。apply 的 1.5/1.6 会把解析结果钉住。
2. **负载阈值取 `0.75 × 核数`**（brief 举例 `≤ 核数`）：证据见上——M49 的假红正好是 26–32@32 核，
   `≤ 核数` 挡不住它。红线本身不放宽（安静机 + 人为慢帧仍判红），`references/protocol.md` 与 spec
   都写清公式与理由。
3. **队列机制的形状**：由 `team review` 自己在时钟外拿共享门禁锁（否则「排队不算超时」无法实现，
   因为排队在门禁命令内部）。配套：`SMOKE_LOCK_WRAPPED=1` 表示祖先已持锁 → 不重复排队（这也是全量
   smoke 里嵌套 review 夹具的防死锁路径）；smoke 的 FAST 模式给夹具一个私有 `TEAM_SMOKE_LOCK`。
   不新增键、不改锁默认路径 `/tmp/teamsmith-smoke.lock`、不做插队（用户已否）。
4. **`verification` 用 ADDED 而不是 MODIFY 既有的 "Gates run under a hard timeout"**（brief A 的字面
   要求）：既有 requirement 的「运行段」语义一字不改，新 requirement 只补「排队段」的关系；两条不冲突。
5. **C（FAST/全量 + 锁的说明）只进文档**（brief 明示「不是新规格」）：tasks G4 写
   `references/protocol.md` §9b、`templates/AGENTS.section.md.tmpl` + `AGENTS.md`、`SKILL.md`。
6. 与相邻 change 的关系：本 change 的 `verification` delta 与 P24 的 `verification` delta
   （"The verifier of a change is not one of its authors"）都是 ADDED、互不重叠；`panel` 只改性能契约那一条，
   不碰 digest（M50 的路径）。

## Suggested next steps

- PM 按 `references/openspec.md` §4 的八点清单审提案包，写
  `docs/team/reviews/gate-hygiene-proposal.md`；本任务到此为止（propose 的交付就是提案包 + 本报告）。
- apply brief 需要显式授权：`skills/teamsmith/scripts/lib/cmd-review.sh`、`references/**`、`templates/**`、
  `SKILL.md`、`AGENTS.md`（PM-owned）；`skills/teamsmith/tests/**` 给 `agent:dev`（G1 1.4、G2、G3 都动它）。
- 无 `BLOCKED:` 项。
