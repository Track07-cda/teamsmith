# V201 · 独立审阅 PM 待命指令

agent: verify   status: ACCEPTED（仅方案）   time: 2026-11-26T01:49:21Z

branch: `task/V201-pm-standby-guidance-proposal-review`   PR/MR: - (local)

**当前结论：方案通过。** 修订版 `defb5f1b8472` 已补上 Pulse 消息，只计划删除 `digest 看详情` 后面的待命指示与唤醒承诺。见末节；未实施、未运行行为测试。

## 首轮审阅 · 2026-11-26T01:43:57Z

**首轮结论：暂不通过。方案修正了开场说明，却漏掉了 Pulse 发给正在运行的 PM 的消息。** 这条消息仍允许 PM 一遇到需要人工介入的事就进入待命，即使独立验证还在跑，也没有让 PM 先遵守项目的人工决定规则。只需把这条消息改成查看待办并遵循项目 `AGENTS.md` 的指引，不改发送方式或任何待命行为。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V201-verify.md` | 冻结候选 `6c7675d24291d77b418ed1312cd4224b25898864` 的独立方案判定、最小返修及校验回执。作者：dev-bob。 |

## OpenSpec assessment

固定检出未带 `.pi/skills/openspec-verify-change/SKILL.md`，按 `skills/teamsmith/references/openspec.md` §6 做等效的方案静态审阅，不生成会话指令。

| Dimension | 结论 | 依据 |
|---|---|---|
| Completeness | 缺一个仍在使用的指令入口 | P508 的九处写集覆盖模板和所列文档，但不包含 Pulse 直接发送给 PM 的指示，见 R1。六项实施均未勾选，符合方案阶段。 |
| Correctness | 规则正文符合 D270，仍有一条消息与之矛盾 | `design.md:19` 与 delta `:13–15`：采用新默认后，只有无事可推进且无运行中任务、验证或自动返回结果可等时才允许自行进入；只等人的决定可符合条件，另有自动结果时不符合；空看板或结束回合均不够。项目保留给人的决定优先，PM 不自行解除。普通 Pulse 被抑制，人工解除和实际定时提醒只解除与之匹配的待命状态保持原样，符合 `watchdog:178–191` 与 `agent-self-reminder:114–126`。 |
| Coherence | 列出的文档改动相互一致；R1 必须一起收口 | 基线目标条文与 delta 逐行比较：只新增两段和一个待命场景，原场景只限定“三个文件”是先前自主推进改动的范围；不删原三文件检查、显式刷新、标记外原字节、原授权或独立审阅要求。新场景另查本次具体写集。 |

## CRITICAL

### R1 · Pulse 仍会直接给 PM 发出另一套待命指令

- `skills/teamsmith/scripts/lib/cmd-watch.sh:630–641`：有待办且 PM 正在运行时，巡检调用 `team_nudge`。`skills/teamsmith/scripts/lib/common.sh:4807–4817` 构造并发送 `[pulse]` 消息，原话是“若确实没活可推或需人工介入，跑 … standby on … 让自己停下（之后不会再叫醒你）”。这不是人工操作说明。即使项目要求人来决定，或正在等验证结果，也可能收到此指令；“之后不会再叫醒”还遗漏了现有定时提醒例外。
- 最小返修：请 P508 作者把 `common.sh` 这条消息列入方案唯一新增的文字落点，更新写集及既有待命文字审阅场景。保留原消息前缀、待办摘要和 `digest` 指示；删除其后的待命命令与条件，或仅指向项目 `AGENTS.md` 的待命规则。保持消息发送、排队、去重、积压、唤醒和状态处理不变；不要刷新项目或加测试。

## WARNING

无其他必须修改项。`workflows.md:483` 改为 `Standby` 后可提供 `#standby`；现有已跟踪产品 Markdown 未引用将被替换的旧标题锚点。`workflows.md:505–510` 的手动维护命令和 `scripts/panel/README.md:124–126` 的人工按键操作不动。

## SUGGESTION

无。

## Final assessment

- CRITICAL 1 · WARNING 0 · SUGGESTION 0。P508 先修订 R1，再复看差异；不建议现在派实施。
- `templates/AGENTS.section.md.tmpl:111–114` 保留巡检机制及原引用，只在这里将原人工 `on|off` 说明替换为完整规则。对照 `templates/pm-prompt.md.tmpl:11,111–130`：开头只在 Pulse 未运行且未待命时提示启动；后段、`templates/PROTOCOL.md.tmpl:89–92` 及每日技能只回指项目规则。硬阻塞括注仅删 `and stand down`，不影响 `delivered`、`hard-blocked`、`suspended on background jobs` 或后台完成后回到原会话。`smoke.sh:6672–6673,8279,9036–9091,12053–12054` 与 `task-model-routing.sh:1007–1008` 的既有逐字匹配与列出的编辑点没有冲突；对照的是源文字，未执行测试。
- `skills/teamsmith/templates/pm-prompt.md.tmpl:154–159` 与 `skills/teamsmith/SKILL.md:216–220` 的工具源升级分步授权保留原文，不混入日常操作。`references/migration.md:29–67` 说明共享源后续读取、当前 AGENTS 与既有 PROTOCOL 的生成是不同路径；方案要求新建或另行授权、明确采用，不授权重启现行 PM、批量改写、改变当前待命状态，或仅通过重启 Pulse 采用文字。
- 只验证方案结构与静态差异；未运行模型、指令读取测试、渲染、真实会话、产品行为、构建或发布检查。无实现，运行前后对照不适用。

## Verification evidence

```text
$ PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive
Change 'clarify-pm-standby-guidance' is valid
validate rc=0
$ git diff --check d7976a63..HEAD
diff-check rc=0
$ git diff --exit-code d7976a63..HEAD -- skills README.md openspec/specs
source+baseline unchanged rc=0
$ git diff --name-status d7976a63..HEAD
A  docs/team/reports/P508-dev-bob.md
A  openspec/changes/clarify-pm-standby-guidance/.openspec.yaml
A  openspec/changes/clarify-pm-standby-guidance/design.md
A  openspec/changes/clarify-pm-standby-guidance/proposal.md
A  openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md
A  openspec/changes/clarify-pm-standby-guidance/tasks.md
```

以上从固定检出取证。逐行对照正式 `init-skill` 目标条文与拟替换内容，`diff -u` 退出 1，差异是两段新增正文、一个新增场景和原三文件场景的一行范围限定，不是验证失败。固定检出前后均干净。

Ledger ban（本任务工作树，根路径已遮蔽）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<verify-worktree> scope=published files=3132 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Decisions and deviations

只提交本报告。未修改候选、项目指令或运行状态；未动 V196 分支、会话、证据或标签；未推送、合并。

## R1 定点复看 · 2026-11-26T01:49:21Z

**ACCEPTED：R1 关闭，只接受方案。** 冻结 `defb5f1b847202051e9302253aec770f56f15c92` 的 `design.md` 给出 `common.sh` → `team_nudge` 的完整目标消息，和现有 `common.sh:4813` 逐字比对，直到 `digest 看详情` 没有变化；仅从分号起删除原待命尾句，不补新文字。`tasks.md` 1.4/2.2 明订这一个实施位置和原文字审阅检查，`init-skill` 原待命场景纳入同一消息，`proposal.md` 也只增加这一条消息。前缀、摘要、语言、计数、发送、排队、去重、恢复及所有待命/定时提醒行为均不改；`cmd-watch.sh` 调用处不在写集内。首轮其余结论保留，不重审。

```text
$ PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive
Change 'clarify-pm-standby-guidance' is valid
validate rc=0
$ git diff --check 6c7675d2..HEAD
diff-check rc=0
$ git diff --exit-code 6c7675d2..HEAD -- skills README.md openspec/specs
source+baseline unchanged rc=0
$ git diff --name-status 6c7675d2..HEAD
M  docs/team/reports/P508-dev-bob.md
M  openspec/changes/clarify-pm-standby-guidance/design.md
M  openspec/changes/clarify-pm-standby-guidance/proposal.md
M  openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md
M  openspec/changes/clarify-pm-standby-guidance/tasks.md
```

固定检出无未提交改动；本轮只跑同一 change strict 及差异检查。无行为执行、脚本修改、项目采用或状态更新。
