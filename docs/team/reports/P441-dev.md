# P441 · 提醒工具提案取消额度

agent: dev   status: delivered（提案修订；change strict 未通过，见下）   time: 2026-11-10T10:44:14Z
branch: `task/P441-remind-tool-proposal-revision`   PR/MR: -（仅本地提交）

## 结论

已将已接受提案修订为无额度的最小 PM 工具，未改产品代码或运行状态。初交同步更新 `proposal.md`、`design.md`、两份获授权 delta 和 `tasks.md`；V149 F1 后依新增授权补改 watchdog delta 一行，见末尾。完成项均指向已有交付证据，未做的工具注入、停跑 PM 恢复和完整验收继续留空。下一步是非作者定点审阅，再由 PM 更新正式提案结论后派 Apply，本报告不代替该审阅。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/agent-self-reminder/proposal.md` | 用用户最新决定替代原额度决策；明确只修订规划，不改变已落地代码，也不授权下一阶段 |
| `openspec/changes/agent-self-reminder/design.md` | 删除额度及其拒绝/计数/等待逻辑；保留有效输入、整批未知处理、Standby 和恢复；写清周期使用同一 key 安排下一次 |
| `openspec/changes/agent-self-reminder/specs/agent-self-reminder/spec.md` | 删除额度拒绝；加入跨越旧阈值仍保存全文、九条合批和无等待下批、观察后同 key 新 ID 场景；身份失效或 reload 后所有动作均不得访问提醒状态 |
| `openspec/changes/agent-self-reminder/specs/pm-lifecycle/spec.md` | 明确现有 PM 重启额度不是 Reminder 创建或投递额度，既有启动检查不变 |
| `openspec/changes/agent-self-reminder/tasks.md` | 2.2 改为无配置键的最小输入校验；3.3 保留 PM 工具注入；按 P406/V128、P409/V129、P422、P423 证据拆出 9 个完成项与 25 个未完成项 |
| `openspec/changes/agent-self-reminder/specs/watchdog/spec.md` | V149 F1：仅删遗留的自提醒批次间隔短语，普通巡检提醒间隔不变 |
| `docs/team/reports/P441-dev.md` | 本报告与本分支验收记录 |

### 删除项

- `TEAM_REMIND_MAX_ACTIVE`、`TEAM_REMIND_MAX_BYTES`，连同拟增加的 schema、模板、配置参考和面板标签实施项。
- 20 次/60 秒创建限制。
- 100 条 active/unknown 上限。
- 16 KiB 正文上限。
- 每批最多 8 条。
- 批次间隔 5 秒。
- 强制 30 秒最小延迟。

这些限制没有换名保留。原产品已实现的 `BATCH_LIMIT`、快照成员数量检查和 `BATCH_SPACING_MS` 本轮不改，删除工作明确留在新 tasks 2.2.2，不能把文档修订当成代码已经变化。

### 保留项

- 有效、可表示且严格在未来的时间；相对时间在同一创建事务内只计算一次。
- 非空、合法 UTF-8、无 NUL 的完整正文，保存、显示和投递不缩短。
- 活跃 key 同请求返回原 ID/原 due，不推迟到期；冲突明确拒绝；每次观察后释放 key，再用同一 key 安排下一次并获得新单调 ID。
- 单一状态顺序、完整批次 intent、结果未知不盲重发、整批确认和既有恢复含义。仅允许一批结果未定是防重复投递，不是创建额度；该状态不拒绝新创建。
- PM-only `team_remind` add/list/show/cancel，每次重新核验身份；worker、普通 Pi、伪造或失效/reload 上下文隐藏或拒绝，提醒状态零读写。
- 诚实 doctor 证据、Pi 实际消息观察、Pulse、Standby 代次和现有 PM 启动/容量/重启检查。
- 已实现的终态历史保留规则，不删除 active/unknown 或未消费权利，不将其作为创建额度。

## OpenSpec assessment

本次为 opsx-propose 修订，不是 opsx-verify；下表仅说明本次文档自查范围。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 本任务文档已交付，完整 change 未完成 | 获授权的 5 份规划文件已改；tasks 9 项完成/25 项未完成，工具、恢复和完整验收均未误勾 |
| Correctness | 非 strict 结构校验通过，strict 未通过 | `validate --all` 23/23；change strict rc=1，仅 6 条长需求段落警告；身份、全文、key 和恢复场景仍在 delta |
| Coherence | 待非作者审阅 | proposal/design/spec/tasks 均为无额度方案；明确批次代码仍由后续 Apply 删除，不把规划与产品当前行为混为一谈 |

## CRITICAL

- 本次规划交付范围内未发现必须改产品代码才能完成的阻塞；这不是完整 change 无缺陷的结论。工具和停跑恢复仍未实现，tasks 3.3、4.2 未勾选。

## WARNING

- Change strict 非零：6 条 `Requirement text is very long (>500 characters)`，涉及输入、Pulse、批次、真实唤醒、Standby 和跨进程状态顺序。基线 `8329bc9f` 同名 6 个需求正文也均超过 500 字符；本轮曾使工具可用性段也超长，已压短并重跑，最终不再报告第 7 条。未扩大本任务去拆分整个旧规格，非作者审阅和 PM 必须看到 strict 未通过的事实。
- 规划与产品暂时不同：当前 `remind-store.mjs` 的批次条数/间隔检查仍在，tasks 2.2.2 明确要求后续 Apply 同时删除发送与快照验证中的限制；本轮不能宣称运行中的工具已无额度。

## SUGGESTION

- None within this revision's scope.

## Final assessment

- Counts: CRITICAL 0（仅本次文档范围）· WARNING 2 · SUGGESTION 0。
- Readiness: 提案修订可交非作者定点审阅；未取得新的正式 ACCEPTED 结论，不可据此派 Apply、合并或归档。
- Unverified applicable checks and reasons: 未运行 smoke、长测试、真实 Pi/模型或运行时操作，任务书明确只跑结构检查；原 change 的未完成验收仍在 tasks section 5。非作者审阅由 PM 另行安排。

## Verification evidence（本轮亲跑）

受检规划提交：`0eeab2fa`（此前 `cf379ac1` 删除额度，`1226dfa4` 重整任务证据）；报告提交只增加本文件。系统默认 PATH 不含 OpenSpec，因此两条 OpenSpec 命令临时前置其实际安装目录，不修改配置。

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all
Totals: 23 passed, 0 failed (23 items)
rc=0

$ PATH="$HOME/.bun/bin:$PATH" openspec validate agent-self-reminder --strict
Change 'agent-self-reminder' has issues
6 × [WARNING] Requirement text is very long (>500 characters).
rc=1

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14084 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段 ↔ 行一一对应（源码 139 段 / 表 139 行）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0

$ git diff --check
（无输出）
rc=0

$ git diff --exit-code 8329bc9f HEAD -- skills extension panel .pi
（无输出）
product-diff rc=0
```

- Verdict: 非 strict 校验、引用、映射、完整账本禁令和 diff 检查通过；change strict 未通过，不能报告全绿。
- Notes: section-select 的 1 条条件跳过未当作通过。引用 P406/P409/P422/P423 的历史验证仅用于重整任务勾选，本轮没有重复运行其测试。

账本扫描在当前 worktree 运行并包含本报告。默认扫描因本席位没有本地禁令名单而 rc=3，未当作通过；随后明确只读引用主项目现有名单、仍扫描本 worktree，完整扫描 rc=0。未修改名单或扫描范围。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh
ledger-ban: SKIP names —— 禁令名单未配置（这一项不是通过）
ledger-ban: ... scope=published files=2583 hits=0 names=missing user=resolved
rc=3

$ bash skills/teamsmith/tests/ledger-ban.sh --root . --names-file ../../.pi/team/forbidden-names.txt
ledger-ban: names：名单已配置（../../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: ... scope=published files=2583 hits=0 names=ok user=resolved
rc=0
```

## Flip evidence

N/A — 本任务是已接受提案的文档修订，不实施缺陷修复，不运行产品变异。后续 2.2.2 要用旧阈值正向场景替换旧额度预期，不新增另一套额度检查。

## Decisions and deviations

- 删除额度依用户最新决定；既有待命、投递确认和恢复不重议。
- 初交只改任务书明授的两个 delta；V149 F1 后，PM 更新任务书授权 watchdog delta 的一行修订。其余 delta、canonical specs、代码、配置、主检出和现有提案审查记录不动。
- 未推送、未合并、未归档，未操作真实提醒或 Standby。

## Suggested next steps

1. 非作者定点审阅这 6 份规划文件与本报告，重点核对没有变相额度、任务勾选与证据一致，以及 strict 的已披露边界；本次仅交 V149 复核 F1 差异。
2. PM 记录本 revision 的正式提案结论后再派 Apply；实现范围包括 tasks 2.2.2 的旧批次限制删除和 3.3 工具注入，不把停跑恢复或完整验收算作已完成。

## 2026-11-10 · V149 F1 定点修订

已按 PM 收件箱 2026-11-10T10:59:53Z 指令及最新任务书修正 F1。相对初交 `bb1bf144`，规划文件仅改 `specs/watchdog/spec.md:107` 一行：删除 `and its own batch spacing`，并将单数主语后的 `are` 改为 `is`。`MUST NOT relax the ordinary nudge gap` 原样保留，`TEAM_PULSE_NUDGE_GAP` 及其全部行为、场景均未改。

亲跑记录：

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate agent-self-reminder --strict
Change 'agent-self-reminder' has issues
6 × [WARNING] Requirement text is very long (>500 characters).
rc=1（与初交相同的六个需求；无新增告警）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all
Totals: 23 passed, 0 failed (23 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14084 effective line(s); retired 0; undeclared 0
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0（仍为缺少 .pi/skills 的同一条件跳过，不当作通过）

$ bash skills/teamsmith/tests/ledger-ban.sh --root . --names-file ../../.pi/team/forbidden-names.txt
ledger-ban: ... scope=published files=2583 hits=0 names=ok user=resolved
rc=0

$ git diff --check
（无输出）
rc=0
```

未跑长测试，未改产品代码、运行状态或任务勾选；未合并或归档。交回 V149 仅做差异复核，本报告不自判独立审阅通过。
