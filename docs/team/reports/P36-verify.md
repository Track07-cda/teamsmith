# P36 · PM 会话交接（`team up --fresh-pm` + init 交接段 + 同 cwd 活会话提示）— PARTIAL / BLOCKED

agent: verify   status: BLOCKED   time: 2026-09-22T06:56Z
branch: `task/P36-pm-fresh-pm-init-cwd`   PR/MR: -（local 模式，未 push；分支只有 1 个基础提交，无实现）

## BLOCKED：任务书把实现路径授予 `agent: verify`，而 OWNERSHIP 明文禁止 verify 席位改实现

P36 任务书头部是 `agent: verify`、`phase: apply`，`Boundaries` 逐条列出了实现路径
（`skills/teamsmith/scripts/{team,lib/cmd-agents.sh,lib/common.sh}`、`skills/teamsmith-init/SKILL.md`、
`references/troubleshooting.md`、`tests/smoke.sh`），并要求交付「必须给的证据」里的**实现 + 翻转**证据。

但 `docs/team/OWNERSHIP.md`（本分支与 main 逐字节相同）把 verify 席位单独排除：

```text
    8  | `skills/teamsmith/tests/**` | agent:dev | 测试与门禁脚本（本阶段只在此处动刀） |
    9  | `docs/team/reports/**`、`docs/team/threads/**` | agent:* | 报告与线程（只写自己的报告文件） |
   11  | `skills/teamsmith/scripts/**`、… | apply 阶段任务书**明授**的 agent（默认 PM） | 实现；未获授权 → `BLOCKED:` 交回 PM |
   22  | verify | … | **对抗性复验：只写报告与复验证据，不改实现**（2026-09-21 起恢复严格执行） |
   24  > **实现路径的授权方式（2026-09-21 明确，取代早期"实现一律 PM 独占"的写法）**：
   25  > apply 阶段的 agent 可以改**它的任务书在 `deps:`/`Boundaries` 里逐条列出的实现路径**；
   26  > 任务书没列的路径 = 不能碰 → 在报告里写 `BLOCKED:` 交回 PM。
   27  > `verify` 席位例外：**无论任务书怎么写，都不改实现**（它的价值在于独立）。
```

第 27 行是**预置冲突裁决**：任务书不能给 verify 席位授权实现。因此本任务书要求的 A/B/C 三项改动
（新旗标、init 交接段、同 cwd 探测）我一项都没有动，`skills/**` 一个字节未改。

这不是孤例解释：2026-09-21 的 M53 就是同一形状（apply brief 派给了 verify），当时 PM 的处置是
**认下这条守卫**、把 apply 改派 dev2，并把上述例外写进 OWNERSHIP（同一提交 `e751ff2`）：

```text
$ git log --oneline -1 e751ff2
e751ff2 docs(team): fix OWNERSHIP (the table was a stale 2-seat template that contradicted the apply practice) and reassign M53's apply to dev2 with its paths granted explicitly

$ git show --stat e751ff2 | tail -3
 docs/team/OWNERSHIP.md                             | 14 +++++++++++---
 docs/team/tasks/M53-watch-degradation-apply.md     |  3 ++-
 docs/team/threads/verify.md                        |  4 ++++

$ git show 083965e:docs/team/reports/M53-verify.md | head -3
# M53 · watch-degradation 实施（apply）— PARTIAL / BLOCKED
agent: verify
status: BLOCKED
```

（`docs/team/reports/M53-verify.md` 现已改为指向 `M53-dev2.md` 的路径指针——那条 BLOCKED 报告本身在
`083965e`。thread `verify.md` 2026-09-21T03:48 的 PM 原文：「`verify` 席位例外……它的价值在于独立」。）

**结论：请 PM 把 P36 的 apply 重新派给 dev / dev2 / dev3 / dev-bob 之一（或 PM 自己实施），
再由未参与实现的席位做独立复验。** 若 PM 认定本次要破例让 verify 实现，必须先改 OWNERSHIP 第 22/27 行
并留下审计记录，不能靠任务书绕过席位例外。

## 我实际做的（只读核对，未触碰实现）

```text
$ cat -n docs/team/OWNERSHIP.md | sed -n '8,12p;18,27p'
（见上，第 22/27 行为冲突依据）

$ bash skills/teamsmith/scripts/team help | grep -A2 "up \["
  up [--agents] [--print]      恢复 PM：建 tmux 场地 + 把 PM 拉起来（pi -c 保留历史）
  resume [--agent a] [--all] [--dry-run]   PM 的工具：把停了但没交活的 agent 续跑
（红侧基线：`--fresh-pm` 不存在 —— 这正是 A 要加的东西）

$ grep -rn "fresh-pm\|fresh_pm" skills/ | wc -l
0
（全仓库无任何 `--fresh-pm` 痕迹；C 的探测同样不存在）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict | tail -2
Totals: 15 passed, 0 failed (15 items)

$ git status --porcelain
（空 —— 分支干净，仅含 P36 任务书的基础提交）
```

- Verdict: **BLOCKED（未实施，未跑门禁）**。
- **未跑**：`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`。没有实现就没有可验证的
  增量；共享门禁留给随后真正交付 P36 的那个席位（PM 复验时会再跑全量）。这一条是「未跑」，不是「跳过」。
- 我**没有**改动 `skills/**`、`docs/team/**`（除本报告文件）、`.pi/**`；没有动 tmux 窗口/本项目 PM。

## 只读勘察：给接单席位的实施地图（另有一条路径授权缺口）

接单者要注意：**任务书 Boundaries 列的实现路径不完整**——`team up` 的入口并不在 `cmd-agents.sh`：

| 条目 | 真实落点（本分支实测行号） | 任务书是否授权 |
|---|---|---|
| A · `team up` 参数解析（`--agents/--print`，未知 `-*` 拒绝） | `skills/teamsmith/scripts/lib/cmd-watch.sh:117` `team_cmd_up()` | **否**（Boundaries 只列了 `cmd-agents.sh`） |
| A · `--print` 现状 = 只打提示词 | `cmd-watch.sh:130` → `team_pm_prompt`（`common.sh:1847`） | 否 |
| A · `-c` 的落点 + 续跑优先级 | `skills/teamsmith/scripts/lib/common.sh:1861` `team_pm_pi_args()`（`TEAM_PM_SESSION_ID` > `TEAM_PM_RESUME_ARGS` > `-c`） | 是 |
| A · 启动文案/证据钩子 | `common.sh:2143` `team_pm_continuity()`、`common.sh:2159` `team_pm_continuity_note()`（调用点 `2240`/`2247`） | 是 |
| A · `--help` 文案 | `skills/teamsmith/scripts/lib/cmd-project.sh:68` | **否** |
| B · init 交接段 | `skills/teamsmith-init/SKILL.md` 的 `## 2. Handoff`（当前只有一段普通交接文字） | 是 |
| C · 同 cwd 活进程探测 | 可复用只读助手：`team_proc_cwd()`（`common.sh:1484`）、`team_cmdline_is_bin()`（`common.sh:1613`，一次读取传参闭竞态）、`team_proc_is_agent_bin()`（`common.sh:1810`） | 是（`common.sh`） |
| 测试（append-only） | `skills/teamsmith/tests/smoke.sh`：§11 `team up`（`:3304`）、§11b2 PM 存活证据链（`:3663`）、§11c 恢复（`:4005`）；私有 socket 夹具范式在 `:241-251` | 是 |

两条口径提示（供接单者/PM 决策，不是我的裁断）：

1. A 要求「给 `--fresh-pm` 与既有续跑优先级一个明确裁断并写进 `--help`」。可用的自然钩子是把
   「这一次启动」的影响收敛在 `team_pm_pi_args` 的一个每次启动变量上（与 dispatch/resume 的 `--fresh`
   同族：只影响本次、不写配置），并让 `team_pm_continuity()` 能报出 `fresh:`，这样成功文案与 `--print`
   都能拿它当可断言证据。
2. C 明确要求**只读探测、不动 M6.5**：`team_pm_state()`（`common.sh:1718`）/ `team_pm_alive()`（`:1753`）
   是判活逻辑，探测只能旁路复用 `/proc` 助手，不能改这两处语义。

## Suggested next steps

- **BLOCKED：PM 需改派 P36 的 apply** 给 dev / dev2 / dev3 / dev-bob（OWNERSHIP 第 18–21 行授权：任务书
  Boundaries 逐条列出的实现路径），或者 PM 自己实施；随后由**未参与实现的席位**做独立复验（含翻转证据）。
- 改派时建议同时**补齐 Boundaries**：`lib/cmd-watch.sh`、`lib/cmd-project.sh`（否则接单方会在同一处
  `BLOCKED:` 卡住——这次的冲突只是席位，下一次会是路径）。
- 我没有 push（local 模式）；分支 `task/P36-pm-fresh-pm-init-cwd` 上只有本报告的提交，随时可被改派覆盖。
