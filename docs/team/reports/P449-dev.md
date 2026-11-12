# P449 · delivery-final-wake-integrity 实施

agent: dev   status: delivered   phase: opsx-apply   time: 2026-11-12T03:10Z
branch: `task/P449-final-wake-apply`   PR/MR: -（local，仅本地提交，不推送、不合并、不归档）

**结论：1.1–3.2 已完成，定向行为、破坏/恢复、真实通知选段和两场景真实 PM 演练均通过；V156 的 WARNING2（NOREV 直接证据）也已补齐，可交 V156 定点确认。全量 OpenSpec 校验没有通过：工作树里已归档的 `openspec/changes/panel-symlink-inside-project/` 仍是无文件空目录，校验器把它当成无 delta 的活动 change；本 change 的独立严格校验通过。4.1/4.2 未勾选，未做独立 Verify。**

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/extension/team-bg.ts` | 新 `.job` 同时写绝对 `session_cwd` 与执行 `cwd`；返回详情的执行目录语义不变 |
| `skills/teamsmith/extension/team-notify.ts` | 活 `(pid,start-time)` 校验后按发起身份归属；legacy 仅接受恰好等于席位工作树的 `cwd` |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | 唯一合并键增加 delivered-only 十二位 tip 分量；无戳为 `NOREV`，suspended/interrupted 不按 tip 拆行 |
| `skills/teamsmith/tests/bg-ledger-harness.mjs` | 复用原夹具覆盖独立 clone、legacy 边界、跨席位、delivered/suspended/interrupted 修订与唤醒计数 |
| `skills/teamsmith/tests/bg-ledger.sh` | 注册同一夹具的新红侧；保留 §13c 点名的 owner-scope 用例名；修正已有 wake-summarykey 变异锚到当前 `identity` 变量 |
| `templates/pm-prompt.md.tmpl`、`SKILL.md`、`references/workflows.md` | 通知优先、文件为准；重复等待前对账 digest/BOARD/任务分支报告/Git；不读屏、不代跑复验 |
| `references/protocol.md` | 合并键、`session_cwd` 与 legacy 归属规则同步 |
| `openspec/changes/delivery-final-wake-integrity/tasks.md` | 仅勾选 1.1–3.2；4.1/4.2 保持未勾选 |
| `docs/team/reports/P449-dev/pm/` | 两次真实 PM 的完整 session JSONL、工具命令、最终回复与场景断言；家目录和用户名按账本禁令替换为 `<home>`/`<user>` |

## 行为结果

- 独立 clone 作业的记录同时保留发起席位与执行目录。首次 suspended 不敲；另一席位不收养；最终报告的新 delivered tip 新起一行并只增加一次叫醒。夹具计数 `knocks=0,0,1,2` 中的第一次叫醒来自另一席位的 delivered 控制，目标席位自己的序列为 suspended `0` → delivered `+1`。
- 三个不同 delivered tip 产生三行、三个 PM 指针和三次叫醒；同 tip 的后续事件只在自己的行上形成 `×2`，不新增叫醒。suspended 与 interrupted 跨 tip 分别合并，suspended 始终零叫醒，interrupted 只有首行一次。
- 无 `session_cwd` 的旧记录只有真实路径恰好等于席位工作树才接受；独立 clone、席位子目录、其他席位、相对或失效路径均不收养。新记录存在显式 `session_cwd` 时绝不回退到执行 `cwd`。
- 无可证明 tip 的发送者仍按 `NOREV` 保持原合并边界；V156 补证中，两次无戳 delivered 形成一行 `×2`、一个 PM 指针 `×2`、两条明细和一次叫醒（`knocks=1,1`），行与指针均无 `tip=`；有 tip 的 delivered 对照仍为不同修订各自新行并各叫醒一次。没有伪造修订戳，没有新增通知系统、定时轮询、配置或人工双发。

## 真实 PM 指引演练

使用当前分支渲染的 PM 模板，模型 `opencode-go/deepseek-v4.1-flash:max`，独立 `/var/tmp/p449-pm-exercise` 项目和独立 session 存储。两场景均只允许 `read,bash`，未改文件、未派单、未运行验收、未读取 tmux 屏幕；旧提示未运行，因此没有提示词红绿对照结论。

| 场景 | 实际证据 | 结论 |
|---|---|---|
| A：最终唤醒缺失，但实现与最终报告已提交 | 模型实际运行 `team digest`，读取 BOARD，执行 `git show task/P449-final-wake-reconciliation:docs/team/reports/P449-dev.md` 并检查 Git 状态/diff | 识别 Agent 侧已经交付，下一步是准备独立 checkout 并交非实现者 `team review P449 --dir …`；没有重复同一等待状态，没有代跑验收 |
| B：作业仍活着，报告只是未提交草稿 | 模型读取 digest/BOARD、`team bg list`、活 pid、草稿和 `git cat-file`/`git log`/`status` | 明确“未交付，仍处于等待阶段”，不进入复验或合并 |

证据：`pm/scenario-checks.txt`、`pm/scene-{a,b}-final.md`、`pm/scene-{a,b}-tools.tsv`、`pm/scene-{a,b}-session.jsonl`。前六次夹具准备失败及 A 的首次不完整夹具不作为产品证据；上表只采用第七次完整重跑。

## OpenSpec assessment

这是 Apply 自验，不是独立 Verify。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 自验完成 | 1.1–3.2 均有实现和行为证据；4.1/4.2 留给非作者，未勾选 |
| Correctness | 定向通过 | owner/merge/wake 红绿恢复、§13c 与真实通知 §12b-pi、真实 PM 两场景；全量 OpenSpec 的红色边界见 WARNING |
| Coherence | 通过（定向） | 合并判定仍只有 CLI 一处，唤醒仍由新行驱动；沿用既有 watcher/outbox，无第二调度或通知通道 |

需求映射：`background-jobs` 四条场景 → ledger 默认目录断言、owner-scope 独立 clone/显式外来身份/legacy 矩阵；`notify-and-inbox` 归属、合并、指针、唤醒场景 → owner-scope/merge/wake 及 §12b-pi；`pm-lifecycle` 两条行为场景与无第二调度 → 上述真实 PM A/B 与三处指引静态核对。

## CRITICAL

- None（本 change 实施范围内）。

## WARNING

- `openspec validate --all` 与 `openspec validate --all --strict` 都不是绿：空目录 `openspec/changes/panel-symlink-inside-project/` 被报 `Change must have at least one delta`。`git ls-files` 对该目录为空，最新相关提交是既有的 `de349dca chore(openspec): archive panel-symlink-inside-project`；本任务未创建或修改它，也未越权删除。strict 另有既有长需求/Purpose 警告。`openspec validate delivery-final-wake-integrity --type change --strict` 单独通过。
- 旧独立-checkout 作业没有 `session_cwd`，按设计保持无归属；回滚到旧读取逻辑会重新引入新记录的非挂起缺陷。无戳发送者的跨修订静默合并仍是已接受边界，本 change 不处理。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 2 · SUGGESTION 0。
- Readiness: 可进入非作者 Verify；不宣称独立验收、全量门禁或归档就绪。
- Unverified applicable checks and reasons: 全量/夜间/61b 按 brief 明确不跑；全量 OpenSpec 已运行但失败，不能记为通过；旧提示未跑，故没有提示词 flip；4.1/4.2 由另一非作者执行。

## Verification evidence（均实际运行）

### 归属、合并、唤醒与红绿恢复

```text
$ bash skills/teamsmith/tests/bg-ledger.sh --select owner-scope,flip --evidence /var/tmp/p449-dev/final-owner-flips
✓ flip flip-initiator-fallback：红在「owner-scope: an independent-checkout job becomes one final delivery wake」
✓ flip flip-initiator-fallback：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
✓ flip flip-initiator-fallback：红在「owner-scope: a live record with a missing, relative or unresolvable cwd does not suspend (fail-closed)」
== flip · 还原后绿（pristine 树重跑） ==
bg-ledger：188 passed, 0 failed

$ bash skills/teamsmith/tests/bg-ledger.sh --select merge,wake,flip --evidence /var/tmp/p449-dev/final-merge-wake-flips
✓ flip flip-merge-delivered-tip：红在「merge: each delivered revision starts a new line and same-tip events merge」
✓ flip flip-merge-delivered-tip：红在「wake: each delivered revision wakes once and same-tip churn stays merged」
✓ flip flip-merge-delivered-tip：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
== flip · 还原后绿（pristine 树重跑） ==
bg-ledger：202 passed, 0 failed
```

### §13c 与真实通知 §12b-pi

```text
$ bash skills/teamsmith/tests/smoke.sh --select 13c,12b-pi </dev/null
#12 13c … ✓74 ✗0 SKIP0
#13 12b … ✓102 ✗0 SKIP0
#14 12b-pi … ✓149 ✗0 SKIP0
✓ 12b-pi P81：投递日志按 start → read → intent → sent 的顺序落盘
✓ 12b-pi 端到端：真 CLI 投递 → 监视扩展唤醒（零模型调用）
账本自查：14 段收口 · 增量 ✓765 ✗0 SKIP0 ｜ 结果行 ✓765 ✗0 —— 一致
== 选段结果 ==  ✓ 765  ✗ 0
== 选段：这次没跑的段 == 127 个键
```

选择器实际闭包为 `0,0b,0c,0d,2,3b,4,5,6,6f,6i,12b,12b-pi,13c`，没有段级 SKIP；段内 M53 的强制不可用用例按自身设计打印可见 SKIP 并让对应判据通过。`sent` 仍只表示 Pi API 接受，不表示 PM 已读或已行动。新 delivered tip 的行/指针/叫醒计数由上面的 bg-ledger 行为用例给出。

未跑键：

```text
0e 0f 0g 0h 0i 1 1b 1c 3 4b 4c 6b 6c 6d 6e 6g 6h 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 33 12e 12f 12g 12h 12i 12j 12k 34 34b 34c 34d 35 36 37 38 38m 39 40 41 42 43 44 45 46 47 48 49 50 51 51m 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65 66 68 69 67
```

### 结构与账本

```text
$ openspec validate delivery-final-wake-integrity --type change --strict
Change 'delivery-final-wake-integrity' is valid
rc=0

$ openspec validate --all
✗ change/panel-symlink-inside-project
  ✗ [ERROR] file: Change must have at least one delta. No deltas found.
Totals: 21 passed, 1 failed (22 items)
rc=1

$ openspec validate --all --strict
✓ change/delivery-final-wake-integrity
✗ change/panel-symlink-inside-project
  ✗ [ERROR] file: Change must have at least one delta. No deltas found.
Totals: 1 passed, 21 failed (22 items)   # strict 把既有 warning 也计入失败
rc=1

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14156 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0
# SKIP 是 internal 检出没有机器生成的 .pi/skills，自检明确“跳过不等于检查过”。

$ git diff --check
rc=0
```

- Verdict: 定向行为与真实 PM 通过；全量 OpenSpec 失败已如实披露，未跑全量/夜间/61b。
- Notes: 第一次非后台 `owner-scope,suspend-shape` 运行中独立 clone 最终唤醒断言为红，原因是夹具未给 owner-scope 加载私有 tmux shim；修正夹具后重跑通过。首次完整 flip 还暴露已有 wake-summarykey 变异仍匹配已删除的 `lineIdentity` 局部变量，已把变异锚更新到当前 `identity`，最终完整红绿恢复通过。
- Ledger ban (fixed acceptance line — run it **in your own worktree, on your branch's tree**):

  ```text
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2727 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence

红侧都在 scratch 源码副本上完成；pristine 基线与破坏后的 pristine 重跑均绿，真实工作树在最终运行时干净。除新增两条红侧外，原身份验证、目录解析、合并、明细、指针、唤醒红侧也全部执行并通过，未删除或弱化旧断言。

## Decisions and deviations

- 4.1/4.2 未勾选；本报告只证明 Apply 自验，另一非作者仍需独立复验。
- 旧提示控制未运行；即使它能处理也不能充当反向证明，本报告不作该主张。
- 全量 OpenSpec 的空目录问题超出本 change 写集，保留现场，没有删除其他 change 的目录。
- 真实 PM session 初次提交后账本禁令命中 40 处真实家目录/用户名；已在证据文本中统一替换为 `<home>`/`<user>`，最终同一扫描为 2727 文件、0 命中。没有放宽扫描或删除行为证据。

## V156 定点补证（WARNING2）

只改 `skills/teamsmith/tests/bg-ledger-harness.mjs`，没有改产品。新增用例不写 `taskProof`，因此分支名不能伪造 task/tip 戳；有 tip 的既有 `wake-revisions` 用例保持不变。

```text
$ bash skills/teamsmith/tests/bg-ledger.sh --select merge,wake,flip --evidence /var/tmp/p449-dev/norev-final-flips
✓ wake: delivered events without a proven tip merge without a second wake :: knocks=1,1 ::
  [auto] … ×2 … :: WAKE-NOREV delivered two || [auto] … knock=enqueued … ×2
✓ flip flip-merge-delivered-tip：红在「merge: each delivered revision starts a new line and same-tip events merge」
✓ flip flip-merge-delivered-tip：红在「wake: each delivered revision wakes once and same-tip churn stays merged」
== flip · 还原后绿（pristine 树重跑） ==
bg-ledger：205 passed, 0 failed

$ bash skills/teamsmith/tests/smoke.sh --select 13c </dev/null
#12 13c … ✓74 ✗0 SKIP0
账本自查：12 段收口 · 增量 ✓514 ✗0 SKIP0 ｜ 结果行 ✓514 ✗0 —— 一致
== 选段结果 ==  ✓ 514  ✗ 0
== 选段：这次没跑的段 == 129 个键
```

这次只重跑 merge/wake/flip 与受夹具影响的 §13c；§12b-pi 没有产品或 watcher 变更，沿用上面已通过的 765/0 选段证据，未重复运行。WARNING2 的直接证据缺口已关闭；无戳发送者的跨修订合并仍是 accepted boundary，不改变产品语义。

## Suggested next steps

- V156 定点核对新增 NOREV 用例、205/0 红绿恢复与 c 514/0，再继续既定独立验收。
- PM 准备独立 checkout，派非作者执行 4.1/4.2 与 OpenSpec 评估；全量 OpenSpec 需要先处理上述已归档空目录，不能把当前红色写成通过。
- 复验重点：独立 clone 最终唤醒、无 tip/legacy 边界、不同 delivered tip 各一次唤醒，以及真实 PM 会话中未出现验收或读屏命令。
