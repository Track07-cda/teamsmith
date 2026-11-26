# P504 · PM 待命指令只说一种意思

agent: dev-bob   status: DONE (explore)   time: 2026-11-26T01:27:52Z

branch: `task/P504-pm-standby-guidance-explore`   PR/MR: - (local)

**结论：把进入待命的判断只写在新项目生成的 `AGENTS.md` 共用规则里。** 只有项目授权，且已没有能推进的事、也没有在等运行中的任务、验证或自动返回的后台结果，PM 才可说明原因后主动进入待命。需要人来决定时，照项目要求；空看板不算依据。PM 不自行解除。人工解除和实际定时提醒唤醒时的既有例外保持不变。这次只交探索报告，不改任何指令源或运行状态。

## Deliverables

| 路径 | 内容 |
|---|---|
| `docs/team/reports/P504-dev-bob.md` | 冲突原文、后续最小文字写集、英文替换建议、规格位置、已有文字断言及采用路径 |

## 1. 冲突原文

以任务基线 `2e521d76` 和本地发布标签 `v0.4.8`（`c34e1468`）对照。两份模板只有 PM 开场 24–31 行附近的初始化模型说明不同；下列待命行在两份版本一致。路径及行号均为基线。

| 位置 | 原文及冲突 |
|---|---|
| `skills/teamsmith/templates/AGENTS.section.md.tmpl:113–114` | “`team standby on\|off` is a human's call.” 进入、解除被合并成同一个人工决定。 |
| `skills/teamsmith/templates/pm-prompt.md.tmpl:11` | `team pulse status       # running? if not: team pulse up (standby on = quiet; standby is a human's call)`，开头重申人工决定，而且注释没直说已待命时不要启动 Pulse。 |
| 同一 PM 模板 `:111–112,126–130` | 结束规则说 “a human: record it and stand down”；后段说 “If there is genuinely nothing to push, or you are blocked on a human (authorization, a decision, external information), write the conclusion into `{{DOCS_DIR}}/inbox/` or a thread and `team standby on --reason "…"`; a human runs `team standby off`.” 这里让 PM 执行 `on`，没有项目授权或仍在等任务回来的条件。 |

`workflows.md:458–464` 把 Pulse 待办列为通知、待复验报告、看板、阻塞和停下的未完任务；这不是 PM 能否推进的完整判断。`pm-prompt.md.tmpl:117–124` 又明确让 PM 结束当前回合、等后台完成通知再取结果。因此「在等待」可以结束当前回合，但不等于应切换待命，更不能只看空看板。

## 2. 建议文字及后续最小写集

### 唯一完整规则：`skills/teamsmith/templates/AGENTS.section.md.tmpl:111–114`

保留原 Pulse 段的命令、频率、职责与文档指向；将 `, not an automatic dispatch;` 处改为句号，删除 `on|off is a human's call`，紧接着加一段：

> **PM standby.** Follow the project's standby rules. If standby is the user's decision, leave it to them. If the project authorizes you to enter standby, use `team standby on --reason "…"` only when there is no work you can advance and you are not waiting for running tasks, verification, or results that will return automatically from background work. State why. An empty board is not enough. Standby suppresses ordinary Pulse wake-ups. Leave `team standby off` to a human. A scheduled Reminder that actually wakes the PM can still clear the matching standby state under the existing Reminder rules.

保留现有 `PM — proceed within authorization` 段（模板 `:20–25`）；它是一般工作授权，不是新添的待命权限。这里也不要求一直占用当前回合：等待任务或后台结果时仍按原完成通知回来。

### 引用共用规则的入口：不再分别定义谁能进待命

以下是另外八个文字文件的具体落点；前两列原文用于定位，第三列为可直接采用的英文或删除范围。相对路径均相对于仓库根。

| 位置 | 要消除的歧义 | 建议替换 |
|---|---|---|
| `skills/teamsmith/templates/pm-prompt.md.tmpl:11,111–112,126–130` | 开头说人决定，后段叫 PM 执行；结束规则的 “stand down” 易被读成切换待命。 | 首行保留 `team pulse status`，注释改 `# if Pulse is down and you are not on standby: team pulse up`。结束规则中仅改括号为 `(blocked on a human: record the blocker)`，原三种结束方式和后台段不动。巡检段保留首句，原判断及命令换成 `Follow the project's standby rule in AGENTS.md. Record any human blocker in {{DOCS_DIR}}/inbox/ or a thread.` 文件名和目录在模板正文用反引号；后面忙时如何处理与引用句不动。 |
| `skills/teamsmith/SKILL.md:3,58,212–215` | 摘要的 “the owner can deliberately stand down”、命令表的 “PM deliberately stands down” 及 “Nothing to do or a human needed” 另起了一套。 | 摘要删掉 `, and the owner can deliberately stand down`；命令表保留命令，括号用 `see **PM standby** in AGENTS.md`；`Non-negotiable rules` 保留 Pulse 职责，末句改 `For standby, follow **PM standby** in AGENTS.md.` 命令表中路径仍用反引号。`SKILL.md:83` 只说已待命不启动 Pulse，保留。 |
| `skills/teamsmith/templates/PROTOCOL.md.tmpl:89–92` | “Nothing to do, or a human is needed: …; only a human clears it.” 又定义进入条件，并遗漏提醒例外。 | 截止 `automatic resume.` 后，接 `For standby, follow the project rule in AGENTS.md.` 不重复命令或条件；保留末尾机制和巡检指向。 |
| `skills/teamsmith/references/protocol.md:430–431` (§8) | “The PM can stand down deliberately … (nothing to do / a human has to step in)” 是宽版授权。 | `- Standby suppresses ordinary Pulse wake-ups; the backlog is still logged. For standby authorization, follow the project's rule in AGENTS.md. See [Standby](workflows.md#standby) for commands and the Reminder exception.` 文件名用反引号。 |
| `skills/teamsmith/references/workflows.md:406–409,463–464,483–495,506–510` (§I) | 首个命令块默认 PM 可 `on`，同时说 “no more wake-ups”；后面再写 “When it applies: there really is nothing to push forward, or a human has to step in”。 | 从首个速查块删 `on/off` 两行；`:463–464` 改 `Standby suppresses ordinary Pulse wake-ups; see [Standby](#standby).` 标题用 `### Standby`；命令块前写 `Follow the project's standby rule in AGENTS.md.` 保留状态和 `on/off` 操作示例，`on` 注释改 `# suppress ordinary Pulse wake-ups`，`off` 注释用 `# human action: resume ordinary Pulse wake-ups`。删除 “When it applies” 两行开头的判断；保留积压、`team digest`、提醒例外，不重述权限。维护例子已是人工用途，`on` 注释也改为只指普通 Pulse 唤醒。 |
| `skills/teamsmith/references/troubleshooting.md:567–569` | “both … qualify” 把「等某人」一概算作可开启，`off` 没标人工。 | `- **The PM keeps being woken**: See [Standby](workflows.md#standby) for how to pause ordinary Pulse wake-ups without losing the backlog.` |
| `skills/teamsmith-init/references/bootstrap.md:75` | “Want to shut it down completely” 默认把 `pulse down` 和 `standby on` 捆绑；关巡检不等于写待命，更不是关掉全部唤醒。 | 左栏 `Stop the periodic patrol`，右栏只留 `team pulse down`；不从安装排障另开待命入口。 |
| `README.md:17` | “the PM can `standby` deliberately” 可被读作无条件授权。 | `The pulse wakes the owner only when work is pending; standby pauses ordinary Pulse wake-ups; when capacity is tight, work queues instead of thrashing`。外部说明只讲效果，不再写谁决定。 |

不改 `skills/teamsmith/references/reminders.md:63–90`（现有实际唤醒证据与例外）、`skills/teamsmith/scripts/panel/README.md:125`（人操作按键说明）、CLI 帮助、脚本、扩展、配置、测试、旧归档或任何现有项目生成件。`skills/teamsmith/scripts/lib/cmd-watch.sh:2412–2442` 的 `on/off` 仍是原有命令，不是新增 CLI 权限校验。没有切换待命的自动机制或读取要求要实现。

## OpenSpec assessment

- **Completeness（探索）**：只在 `openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md` 为 `openspec/specs/init-skill/spec.md:618` 的既有 **Installed team instructions separate shared rules from role procedures without losing required duties** 拟一条 `MODIFIED`。保留原段和场景的职责与权限；在 `:624–626` 共用规则后补待命判断及入口指向，增加一条独立文字审阅场景。不要另建规格或改初始化、巡检、提醒规格。
- **Correctness（待审文字，不是运行验证）**：建议正文： “The shared AGENTS section SHALL state that the PM may enter standby and record the reason only when project policy authorizes it, no work can be advanced, and no running task, verification, or background result is awaited. An empty board alone MUST NOT justify standby. If the project reserves the decision for a human, the PM SHALL leave it to them. The guidance MUST NOT authorize the PM to clear standby on its own or change the existing human clear and correlated Reminder-wake paths. The startup prompt, daily skill and generated PROTOCOL summary SHALL point to the shared rule rather than define a different entry policy.” 实际唤醒才能清除所绑定、可确认的同一代待命（`openspec/specs/agent-self-reminder/spec.md:114–126`）；普通 Pulse 不呼叫、不拉起，但仍留积压（`openspec/specs/watchdog/spec.md:178–191`）。不改两项行为。
- **Coherence（后续提案）**：`:660–664` 的原场景将写集说成 “only the three instruction sources”，适用于原 PM 授权改动，不能拿来要求本次同步多处入口也只能三份。保留原场景的限定对象，例如 `WHEN a reviewer reads the PM proceed-within-authorization change ...`，或改为只改相应说明文件、不能碰生成/加载。新场景建议 `WHEN a non-author reads the shared AGENTS standby rule, startup prompt, daily skill, generated PROTOCOL summary, and referenced procedures`；`THEN the project decides who may enter standby; the PM can enter only with no work to advance and no outstanding automatic result, not because the board is empty; the entry points do not contradict that rule, and human clear and actual Reminder wake stay unchanged.` `:666` 的显式刷新规则不动。

### 已有项目如何采用

1. **新项目**：采用含改动的工具源后，现有 `team init` 或首次 `team bootstrap` 由原路径生成 AGENTS 和缺失的 PROTOCOL；无需加步骤（`cmd-project.sh:495–531`、`cmd-bootstrap.sh:308–315`）。
2. **已有项目**：新源进仓不改当前项目、`<peer>` 或其状态。链接安装可能在今后读取时看到新源，复制安装不会自动变（`openspec/specs/init-skill/spec.md:508–512`、`skills/teamsmith/references/migration.md:29–70`）。已有 AGENTS 要经项目授权按该节先预览、必要时把项目规则保存在标记外，再显式非强制 init；标记外逐字节保持。已有 `PROTOCOL.md` 不会被普通 init 替换；如项目另行授权，只改旧巡检指令为指向 AGENTS，不用 `--force` 重渲染账本。不把 `--no-skills` 说成只写 AGENTS；已有配置的 `bootstrap` 或 `team up` 也不是 AGENTS 刷新路径。
3. **已有会话**：已读文字不会自动替换；采用新源后的后续普通 PM 启动才渲染新开场文件（`common.sh:3181–3193,3399–3404,3806`）。普通 `team up` 复用还活着的 PM，不算新开场（`cmd-watch.sh:372–434`）；技能 `/reload` 后需重读，不能替代刷新 AGENTS（`skills/teamsmith/SKILL.md:151–159`）。Reminder-only 恢复仍不带通用开场。P504 没有执行上述任何采用或刷新。

### 既有逐字检查与发布前审阅

- 定点搜索未发现直接锁住 `human's call`、`genuinely nothing to push`、`record it and stand down`、`only a human clears it` 或上述替换标题的测试。`tests/smoke.sh:6672–6673` 要保留 `pm-prompt.md`、`team digest`；`:9036–9091` 要保留 `delivered`、`hard-blocked`、`suspended on background jobs`、`harvest point`、`team_bg_run`、`let the turn end`、`team_bg_wait`；`:8279` 的 `Your creed` 不动。`smoke.sh:12037–12054` 的角色及专属验证措辞也不在改动范围。
- `tests/task-model-routing.sh:1007–1008` 原样查 `installer` / `shared` 和 `separate recorded gates`；这几句不改。`docs/team/reviews/REL-0.4.8.md:7,15` 记录过同义改写导致既有测试不匹配，也明确文字复核不代替发布判定。`smoke.sh:6777–6787` 测 CLI，而不是校对说明，不改其预期。上述是源码核对，未执行这些测试。
- 沿用 `openspec/specs/init-skill/spec.md:622,654–664` 与既有 V188 的独立文字审阅：由非作者在发布前逐处读最终差异，确认项目授权优先、空看板不触发、等运行结果不切换、人工解除和实际提醒例外不变，确认保留原句断言和采用边界。不新增测试，不用模型模拟、真实会话或「是否读到了」验证，不替代原发布流程。

## Verification evidence

```text
$ git diff --cached --check
(git diff --cached --check: rc=0)
$ git diff --cached --name-status
A       docs/team/reports/P504-dev-bob.md
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<P504-worktree> scope=published files=3118 hits=0 names=ok user=resolved
rc=0
```

`root` 为已遮蔽的本席位目录；账本扫描包含本报告。

- Verdict: 探索完成；未运行 OpenSpec 校验、渲染、安装/刷新、会话、模型、运行时测试或全套检查。没有实现，因此不适用修复前后故意改坏的证据；同一原句在发布标签和本任务基线的定位列于 §1。
- Decisions and deviations: 无。只提交本报告，不合并、不推送、不执行改变项目状态的命令。
- Suggested next steps: PM 按上面的单条 `init-skill` 修改路径另派提案，安排非作者对最终文字做独立审阅；实际项目采用仍另行授权。
