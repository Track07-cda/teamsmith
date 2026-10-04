# P11 · Propose: `pulse-console`（控制台化实施提案）

agent: dev2   status: DONE   time: 2026-09-16T18:06:28Z
branch: `task/P11-propose-pulse-console-e6`   PR/MR: -（local 模式，分支留本地）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/pulse-console/proposal.md` | 为什么/改什么/边界/验收 + 任务书五个必答题（494 词，config 规则 <500） |
| `openspec/changes/pulse-console/specs/panel/spec.md` | panel delta：9 ADDED + 4 MODIFIED + 1 REMOVED |
| `openspec/changes/pulse-console/specs/watchdog/spec.md` | watchdog delta：1 MODIFIED（一窗口两形态） |
| `openspec/changes/pulse-console/design.md` | 取舍与决策：capability 归属、批次、异步/写信/收起机制、E6 §3 逐条裁定 |
| `openspec/changes/pulse-console/tasks.md` | 三批 apply（B1 异步化 → B2 写信 → B3 控制台表面），第 0 步 = D26 前置实测，v1.1 延后清单 |

提交（小步）：`07415cf` proposal → `7df2d31` spec deltas → `b392a40` design → `3ae143f` tasks。

## Verification evidence (must have actually been run)

```
$ openspec validate --all --strict
✓ spec/agent-adapters … ✓ change/pulse-console … ✓ spec/watchdog
Totals: 13 passed, 0 failed (13 items)

$ openspec change show pulse-console
（完整渲染 proposal 全文 + 无报错；该命令自带 deprecation warning：change show 系列已弃用，
建议动词优先命令——但任务书验收原文就是这条，命令本身可用、退出码 0）

$ openspec status --change pulse-console
Progress: 4/4 artifacts complete
[x] proposal  [x] specs  [x] design  [x] tasks
All planning artifacts complete!
```

针对 v1.8.0 validate 洞（#1077 / D23）的手工核对脚本（python 逐字比对 delta 与 base 的需求名、
MODIFIED 的 base 场景保留）：

```
ok  [panel] MODIFIED requirement name matches base: The panel is a TUI in a terminal and never a TUI on a pipe
ok  [panel]   scenario kept: A pipeline receives plain text
ok  [panel]   scenario kept: Redirecting stdout selects the plain-text path
ok  [panel]   scenario kept: The TUI still renders in a real pane
ok  [panel] MODIFIED …: The panel process is the patrol's single tick loop（2 个 base 场景全保留）
ok  [panel] MODIFIED …: The deferred-delivery queue is read, counted and never touched（3 个全保留）
ok  [panel] MODIFIED …: The `TEAM_MONITOR_*` keys keep their meaning…（3 个全保留）
ok  [panel] REMOVED requirement name matches base: The layout is four ordered bands…
ok  [watchdog] MODIFIED …: One backend, inside the team's tmux session（2 个全保留）
HAND-CHECK CLEAN
```

- Verdict: **pass**
- Notes：proposal 的词数按 `wc -w` 494（含 markdown 记号）；本任务是 propose 阶段，未写任何实现代码、
  未动 `openspec/specs/**`、未动账本；spec delta 的场景可证伪性留给 PM 提案审查把关（checklist #2）。

## Flip evidence (required for defect-fix tasks)

不适用——P11 是 propose（规划）阶段，无缺陷修复。flip 预埋在 tasks.md 里：B1 第 0 步要求在复验基线上
先记录红（7.2s 帧 + 按键失真复现），B1.4 的按键夹具在改造前必须红、改造后必须绿。

## Decisions and deviations

1. **布局需求用 REMOVED+ADDED 而非 MODIFIED**（对任务书"倾向 MODIFIED 布局/交互需求"的一处偏离）：
   四条带 → 三页是整体替换，base 的三个场景标题（"Band order is stable" 等）在新世界没有对应物；
   v1.8.0 的 archive 会拒绝丢场景的 MODIFIED。REMOVED（带 Reason+Migration）+ 新 ADDED 是
   checklist #7 允许的另一种 supersession 表达。其余演化型需求（tick 循环、outbox、TEAM_MONITOR_*、
   管道契约、watchdog 一后端）全部 MODIFIED 且场景标题逐字保留。
2. **capability 归属采纳任务书倾向**：并入 `panel`，不新建 `pulse-console` capability（理由在 design.md §1）；
   `watchdog` 必须搭一个 MODIFIED，否则"窗口必须同时是 status monitor"与 q 收起后的 headless 形态矛盾。
3. **新增一条伞需求**「The console is read-only except through three commands」：给 `f`（冲刷）和 `s`
   （待命开关）一个规格家——它们不属于写信需求，而设计纪律"只读+三动作"必须可证伪。
4. **E6 §3 开放点的裁定**（design.md §8）：待办计数门控 v1 不改语义；里程碑进度条/树、"上次门禁"记录点、
   队列"丢弃"动作、`draft send --json` 全部 `[v1.1]`（design 内部张力"三动作 vs 丢弃"按三动作收口，
   丢弃是第四且破坏性动作，留给用户定夺）；`--print` 钉死总览帧。
5. **`TEAM_MONITOR_REFRESH` 默认 5s→3s**（设计红线"活动页 3s 一刷"），以 MODIFIED + `panel.refresh_s`
   机读可见的方式落地——这是一条契约变更，请提案审查时重点看一眼。
6. **主题不进设置浮层**：设计稿浮层恰好五项，主题做成终端背景自动检测 + `panel.conf` 的 `theme` 键钉定
   （快照套件 4 档 × 深浅主题需要确定性开关）。
7. v1.1 标记形态：tasks.md 末尾纯 bullets（非 checkbox），apply 阶段不会被误勾，也不影响归档完整性。

## Suggested next steps

- PM 提案审查：`docs/team/reviews/pulse-console-proposal.md`（checklist 八条；本报告 §Verification 已附
  手工核对表）。**ACCEPTED 之前不得派 apply**。
- 若 ACCEPT：B1 的 apply 按流水线必须派给**不是 dev2** 的 agent（propose 与 apply 不同人）。
- 提醒：E6 报告（`docs/team/reports/E6-dev2.md` + pkg/）目前只在分支 `task/E6-explore-pulse-pi-api`
  （aa804b8）上，尚未合入 main；proposal/design 引用了它。建议在归档 P11 之前把 E6 的报告合入 main，
  否则引用悬空。这不阻塞本任务（提案文件自身完整）。
