# teamsmith · 目录归属（Ownership）

> **只改属于你的目录。** 需要跨目录改动 → 在报告里写 `BLOCKED:` 说明谁该改什么，交回 PM 协调。
> 没有列出的目录 = PM 独占。

| 路径 | Owner | 说明 |
|---|---|---|
| `skills/teamsmith/tests/remind-tool-real.mjs` | agent:dev（P473已关闭，默认维护权恢复） | 一行测试修复cea2b7f2已接受，P473临时写权收回；P471不因此扩到此文件 |
| `skills/teamsmith/tests/**` | agent:dev | 本轮P471仅现有panel-p21.sh/panel-strings.mjs的设置相关断言替换；P473上述单文件除外，其它范围未授 |
| `.github/workflows/gates.yml` | agent:dev（P326 临时） | 仅任务书明授的CI入口，不提高60分钟上限；冻结交付后归还PM |
| `ci/collect-scene.sh` | PM | P324已合入，临时写权收回；当前无实现任务改此文件 |
| `docs/team/reports/**`、`docs/team/threads/**` | agent:* | 报告与线程（只写自己的报告文件） |
| `docs/team/reviews/P461.md`、`docs/team/reviews/P461-verify.log` | PM（V167已接受关闭） | verifier实际记录已收存；仅PM接受与结案，不再授权新执行 |
| `docs/team/reviews/P465.md`、`docs/team/reviews/P465-verify.log` | PM（V170已接受关闭） | 两阶段实际记录由dev3执行，已接受merged证据；临时工具写权收回 |
| `docs/team/reviews/P466.md`、`docs/team/reviews/P466-verify.log` | PM（V171已接受关闭） | 两阶段实际记录由verify执行，已接受merged证据；临时工具写权收回 |
| `docs/team/reviews/P468.md`、`docs/team/reviews/P468-verify.log` | PM（V173已接受） | 实际两阶段由verify执行，merged28621c57通过；工具临时写权收回，不再授权新执行 |
| `docs/team/reviews/V174.md`、`docs/team/reviews/V174-verify.log` | PM（计时交付接受；检查FAIL保留） | 原件已收存，P472已只读归因并关闭，历史结果不改 |
| `docs/team/reviews/P473.md`、`docs/team/reviews/P473-verify.log` | PM（V176最终证据已接受） | 候选三臂及merged cea2b7f2同一性/语法rc0已接受，临时中央写权收回；旧完整FAIL不改，原件待中央保存后清理 |
| `docs/team/reviews/P471.md`、`docs/team/reviews/P471-verify.log` | agent:dev3（V177临时） | 9c1adb1c原FAIL已私有保存；在独立5f3f320a上仅正式定点补验，八帧及有效记录红侧复用，不重跑十场景或完整已过case；旧四错按D261单列，其余主检出只读 |
| `skills/teamsmith/scripts/panel/src/**`、`skills/teamsmith/scripts/panel/panel.js`及对应README/config/SKILL设置说明 | agent:dev（P471产品冻结） | UI/bundle同5f3f320a已实测；当前只许panel-p21.sh的wheel等待一行及本人报告，不再改产品/生成物；V177随后只复用实际帧，不重跑UI；旧四错按D261保留 |
| `openspec/changes/pulse-project-settings-simplify/tasks.md` | agent:dev（P471临时） | 只勾已实施/静态完成的1.1–1.6；其余规划和正式spec只读，独立行为验收另派 |
| `openspec/changes/archive/2026-11-16-routing-parameter-check-dedup/**` | PM（A12已接受） | 已验6/6的五工件原样归档，临时写权收回 |
| `openspec/changes/archive/2026-11-16-config-check-execution-dedup/**` | PM（A9已接受） | 已验证7/7原样归档，不再授实现写入 |
| `openspec/specs/verification/spec.md` | PM（A12已接受） | 已验MODIFIED目标原生同步；两处段落空行处理已接受，Purpose及其余正文不变，临时写权收回 |
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
