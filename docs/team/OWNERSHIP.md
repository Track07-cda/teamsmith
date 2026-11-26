# teamsmith · 目录归属（Ownership）

> **只改属于你的目录。** 需要跨目录改动 → 在报告里写 `BLOCKED:` 说明谁该改什么，交回 PM 协调。
> 没有列出的目录 = PM 独占。

| 路径 | Owner | 说明 |
|---|---|---|
| `skills/teamsmith/tests/remind-tool-real.mjs` | agent:dev（默认维护权恢复） | P486 实施临时写权已收回，合并版 `191e8097` 接受；其余受影响测试文件回到默认归属 |
| `docs/team/reviews/P486.md`、`docs/team/reviews/P486-verify.log` | PM（V185已接受） | 合并版 191e8097 已核字节、语法及接入，收回临时写权 |
| `skills/teamsmith/tests/**` | agent:dev | 本轮P471仅现有panel-p21.sh/panel-strings.mjs的设置相关断言替换；P473上述单文件除外，其它范围未授 |
| `.github/workflows/gates.yml` | agent:dev（P326 临时） | 仅任务书明授的CI入口，不提高60分钟上限；冻结交付后归还PM |
| `ci/collect-scene.sh` | PM | P324已合入，临时写权收回；当前无实现任务改此文件 |
| `docs/team/reports/**`、`docs/team/threads/**` | agent:* | 报告与线程（只写自己的报告文件） |
| `docs/team/reports/P495-dev2.md`、`docs/team/reviews/P495.md` | PM（P495 已接受） | 保留探索记录，无后续写权 |
| `openspec/changes/task-labels/**`（除实施任务勾选）、`docs/team/reports/{P496-dev2,V195-dev3,V205-dev3}.md` | PM（原范围和兼容修订均已接受） | 保留原方案、修订 `f36d1e51` 和独立回执，规划只读 |
| `docs/team/reports/{P497-dev,V196-verify}.md`、`docs/team/reviews/P497.md` 与 `P497-verify.log` | PM（P497/V196 已接受） | 候选和合并记录已分别保全，临时写权收回 |
| `openspec/changes/task-labels/**`、原生唯一归档目录、`openspec/specs/{board-and-status,panel}/spec.md` 的五个目标条款、`docs/team/reports/A20-dev2.md` | agent:dev2（A20 临时） | 只同步既定条款、原样移入六文件；不写项目设置变更、产品或实际运行状态 |
| `docs/team/reports/P498-dev2.md`、`docs/team/reviews/P498.md` | PM（探索接受） | 仅保留探索及接入裁定 |
| `docs/team/reports/{P499-dev2,V197-dev3}.md` | PM（方案接受） | 已接受的初始化方案审阅记录，收回原写权 |
| `docs/team/reports/P500-dev-bob.md`、`docs/team/reports/V198-dev3.md`、`docs/team/reviews/P500.md` 与 `P500-verify.log` | PM（候选与合并证据接受） | P500/V198 已完成，收回产品与中央记录暂时写权 |
| `openspec/changes/archive/2026-11-25-quick-init-model-defaults/**`、`openspec/specs/init-skill/spec.md`、`docs/team/reports/A17-dev2.md` | PM（A17 已接受） | 四条要求已核同步，五份工件原样移动；归档临时写权收回 |
| `docs/team/reports/P501-dev2.md` | PM（P501 探索已接受） | 核实逐行时间来源的报告 |
| `docs/team/reports/{P502-dev2,V199-dev3,P503-dev-bob,V200-dev3}.md`、`docs/team/reviews/{P503.md,P503-verify.log}` | PM（实施及合并短核已接受） | 方案、产品与验证临时写权撤回，不混入暂停的标签候选 |
| `openspec/changes/archive/2026-11-25-pulse-board-recent-first/**`、`openspec/specs/{panel,board-and-status}/spec.md`、`docs/team/reports/A18-dev2.md` | PM（A18 已接受） | 三条要求与实际五份工件已核对，收回归档临时写权 |
| `docs/team/reports/P504-dev-bob.md` | PM（P504 已接受） | PM 待命指令冲突与采用边界 |
| `openspec/changes/clarify-pm-standby-guidance/**`、`docs/team/reports/P508-dev-bob.md`、`docs/team/reports/V201-verify.md` | PM（已审方案与原报告） | 保持 `defb5f1b` 和 `a95ac8be` 的接受证据，原 V196 会话和证据不动 |
| `docs/team/reports/{P510-dev-bob,V204-verify}.md`、`docs/team/reviews/{P510,V204}.md` | PM（候选及合并文字比对已接受） | 十个产品文件与经审方案范围已核，临时产品和验收写权收回 |
| `openspec/changes/archive/2026-11-26-clarify-pm-standby-guidance/**`、`openspec/specs/init-skill/spec.md` 的目标要求、`docs/team/reports/A19-dev2.md` | PM（A19 已接受） | 原件 5/5 一致，现行说明只同步单个目标；收回临时写权 |
| `docs/team/reports/P505-dev3.md` | PM（P505 已接受） | 现行及标签候选的连续键读数 |
| `docs/team/reports/{P509-dev3,V202-verify}.md`、`docs/team/reviews/{P509.md,P509-verify.log}` | PM（P509/V202 已接受） | 候选与合并的实际帧结论已核，产品/测试和中央验证临时写权撤回 |
| `docs/team/reports/P506-dev2.md` | PM（P506 已接受） | 项目设置的标签操作与唯一写入入口探索 |
| `docs/team/reports/{P507-dev2,V203-dev3}.md`、`openspec/changes/project-label-management/` 方案及需求正文 | PM（受审方案） | 项目设置原方案已独立接受，不改受审范围 |
| `docs/team/tasks/P511-project-label-management-apply.md` 明授的标签定义命令、面板、一个现有设置测试、清单和报告 | agent:dev-bob（P511 临时） | 只实现项目设置入口与同一写入结果，不写正式规格、标签看板行为、巡检、当前项目或发布 |
| `docs/team/reviews/P461.md`、`docs/team/reviews/P461-verify.log` | PM（V167已接受关闭） | verifier实际记录已收存；仅PM接受与结案，不再授权新执行 |
| `docs/team/reviews/P465.md`、`docs/team/reviews/P465-verify.log` | PM（V170已接受关闭） | 两阶段实际记录由dev3执行，已接受merged证据；临时工具写权收回 |
| `docs/team/reviews/P466.md`、`docs/team/reviews/P466-verify.log` | PM（V171已接受关闭） | 两阶段实际记录由verify执行，已接受merged证据；临时工具写权收回 |
| `docs/team/reviews/P468.md`、`docs/team/reviews/P468-verify.log` | PM（V173已接受） | 实际两阶段由verify执行，merged28621c57通过；工具临时写权收回，不再授权新执行 |
| `docs/team/reviews/V174.md`、`docs/team/reviews/V174-verify.log` | PM（计时交付接受；检查FAIL保留） | 原件已收存，P472已只读归因并关闭，历史结果不改 |
| `docs/team/reviews/P473.md`、`docs/team/reviews/P473-verify.log` | PM（V176最终证据已接受） | 候选三臂及merged cea2b7f2同一性/语法rc0已接受，临时中央写权收回；旧完整FAIL不改，原件待中央保存后清理 |
| `docs/team/reviews/P471.md`、`docs/team/reviews/P471-verify.log` | PM（V177已接受） | merged967da984正式PASS与c03a2705报告已接收；非作者临时中央写权收回，旧FAIL和D261边界保留 |
| `docs/team/reviews/P474.md`、`docs/team/reviews/P474-verify.log` | PM（V179已接受） | 合并版 0e6677e2 定点复核通过，临时写权收回；P474 实现写权收回 |
| `docs/team/reviews/P475.md`、`docs/team/reviews/P475-verify.log` | PM（V178已接受） | 合并版 ec0ad970 定点核对通过，临时写权收回 |
| `docs/team/reviews/P478.md`、`docs/team/reviews/P478-verify.log` | PM（V180已接受） | 合并版 24ea698b 定点通过，临时写权及 P478 实现写权收回 |
| `docs/team/reviews/P480.md`、`docs/team/reviews/P480-verify.log` | PM（V181已接受） | 合并版 3b44b960 文件核对、语法检查通过，收回临时及 P480 实现写权 |
| `docs/team/reviews/P483.md`、`docs/team/reviews/P483-verify.log` | PM（V183已接受） | 合并版 282b9dc7 定点核对通过，收回 V183 写权及 P483 实施写权 |
| `openspec/changes/archive/2026-11-20-help-perf-entry-without-measurement/**`、`openspec/specs/verification/spec.md` | PM（A14已接受） | 五份工件原样移动且仅目标需求同步，收回归档临时写权 |
| `openspec/changes/archive/2026-11-20-reminder-test-temp-root-ownership/**`、`openspec/specs/verification/spec.md` | PM（A15 已接受） | 一条已验证要求同步，五份工件原样移动，收回临时写权 |
| `openspec/changes/archive/2026-11-23-pm-autonomy-guidance/**`、`openspec/specs/init-skill/spec.md` | PM（A16 已接受） | 一条已验证的文字要求同步，收回临时写权 |
| `skills/teamsmith/templates/AGENTS.section.md.tmpl`、`skills/teamsmith/templates/pm-prompt.md.tmpl`、`skills/teamsmith/SKILL.md` | PM（P488、P490 已接受） | 自主规则与原授权已核；一行升级措辞在 c34e1468 的自检通过 |
| `skills/teamsmith/tests/loop-inventory.tsv` | PM（P489 已接受） | 合并版 26/0，收回临时写权 |
| `skills/teamsmith/tests/smoke.sh` §10 的 P440 路径断言 | PM（P491 已验收） | 候选 47/0、合并版字节一致，收回临时写权 |
| `skills/teamsmith/tests/smoke.sh` §28/§38 的设置检查、`skills/teamsmith/tests/panel-p21.sh` | PM（P492 已验收） | 原操作与单行补验、合并文件均已独立核对，收回临时写权 |
| `skills/teamsmith/tests/remind-tool-real.mjs` 中两例诊断启动 | PM（P494 已验收） | 两例实际 2/0、合并版与运行文件一致，收回临时写权 |
| 其余 `skills/teamsmith/scripts/panel/src/**` 及对应README/config/SKILL设置说明 | agent:dev（默认维护权） | P471/V177已完成，P474不授写 |
| `openspec/changes/archive/2026-11-17-pulse-project-settings-simplify/**` | PM（A13已接受） | 已验9/9七工件原样归档，临时写权收回，不再授实现写入 |
| `openspec/changes/archive/2026-11-16-routing-parameter-check-dedup/**` | PM（A12已接受） | 已验6/6的五工件原样归档，临时写权收回 |
| `openspec/changes/archive/2026-11-16-config-check-execution-dedup/**` | PM（A9已接受） | 已验证7/7原样归档，不再授实现写入 |
| `openspec/specs/panel/spec.md`、`openspec/specs/memory-and-deps/spec.md`、`openspec/specs/verification/spec.md` | PM（A13已接受） | 原生同步已验delta，Purpose/未点名正文与全部可执行字节不变，临时写权收回 |
| `openspec/changes/archive/2026-11-16-clipboard-test-session-reuse/**` | PM（A11已接受） | 五工件原样归档，不再授实现写入 |
| `openspec/changes/archive/2026-11-16-help-route-render-once/**` | PM（A10已接受） | 已验4/4的五文件原样归档，不再授实现写入 |
| `docs/team/tasks/**`、`docs/team/BOARD.md`、`docs/team/ROADMAP.md`、`docs/team/DECISIONS.md`、`docs/team/OWNERSHIP.md` | PM | 任务书与看板 |
| `skills/teamsmith/scripts/**`、`extension/**`、`panel/**`、`SKILL.md`、`references/**`、`templates/**` | apply 阶段任务书**明授**的 agent（默认 PM） | 实现；未获授权 → `BLOCKED:` 交回 PM |
| `.pi/**`、`AGENTS.md`、`README.md`、`docs/**`（除上面列出的） | PM | 团队协议与配置 |

## 名册

| Agent | 模型 | 长期 worktree | 负责范围 |
|---|---|---|---|
| dev | `kimi-coding/k3-256k` | `.worktrees/dev` | 任务书授权的实现路径 + `skills/teamsmith/tests/**` |
| dev2 | 默认 | `.worktrees/dev2` | 任务书授权的实现路径 + 报告 |
| dev3 | 默认 | `.worktrees/dev3` | 任务书授权的实现路径 + 报告 |
| dev-bob | 默认 | `.worktrees/dev-bob` | 任务书授权的实现路径 + 报告 |
| verify | `openai-codex/gpt-5.6-terra:xhigh` | `.worktrees/verify` | **对抗性复验：只写报告与复验证据，不改实现**（2026-09-21 起恢复严格执行） |

> **实现路径的授权方式（2026-09-21 明确，取代早期"实现一律 PM 独占"的写法）**：
> apply 阶段的 agent 可以改**它的任务书在 `deps:`/`Boundaries` 里逐条列出的实现路径**；
> 任务书没列的路径 = 不能碰 → 在报告里写 `BLOCKED:` 交回 PM。
> `verify` 席位例外：**无论任务书怎么写，都不改实现**（它的价值在于独立）。

## 变更流程

1. 需要新目录归属 → PM 改本文件（并在任务书里引用）。
2. 临时借用 → 必须在任务书里写明 **临时** 与移交条件。
3. 复验收到的 finding 由 PM 决定是改实现（PM 自己改）还是派回 agent（写进线程）。
| `openspec/specs/**` · `openspec/config.yaml` | PM | 规格与配置是账本的一部分 |
| `openspec/changes/<change>/**` | 该 change 当前阶段的 owner（任务书明授） | propose 归提案者；apply 归实现者；archive 由非实现者worker执行，PM接受并合并 |
