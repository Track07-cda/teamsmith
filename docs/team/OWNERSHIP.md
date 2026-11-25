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
| `openspec/changes/task-labels/**`、`docs/team/reports/P496-dev2.md` | agent:dev2（P496） | 任务标签方案；仅 board-and-status 和 panel 的 delta，不写正式规格与产品 |
| `docs/team/reports/V195-dev3.md` | agent:dev3（V195） | 独立审阅任务标签方案；只写个人报告，不改候选 |
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
