# M17 · 打字后没按 Enter 的兜底：不许把自动消息留在用户输入框里

agent: dev2   status: DELIVERED   time: 2026-09-17T09:2x:00Z
branch: `task/M17-m17`   PR/MR: -（本仓库 local 模式，分支留本地，PM 复验后本地合并）

> **接手记录**：系统维护重启预告下达时最后一轮全量门禁只剩两类红 —— 4 项英文正文不变量（已在 `ae75b51`
> 按检查器口径修掉并复查为零命中）、以及 1 项与 M17 无关的面板 26-m 时序项。重启后在交付树上按 brief 的
> 验收命令**串行重跑**：`openspec` 13/13 → full smoke `1840✓/0✗` → FAST smoke `1427✓/0✗` 全绿，
> `flip-m17.sh` 红→绿→变异红。（26-m 那一次红是**多套全量 smoke 并发**造成的负载抖动，现场与证据见下文
> 「26-m 的一次红」—— 它此后在安静机器上连跑两轮全绿。）

用户实测（2026-09-17）：一条 `[auto]` 消息被自动打进 PM 输入框但没发送，用户手动按了 Enter 才发出去。
根因：复检失败时守卫按设计**放弃 Enter**，但把已经打进去的字留在了框里。M17 给放弃路径加「收回纪律」：
只有此刻框里**只有我们打进去的东西**（逐字 / 单个 +K 对得上的折叠占位符 / 前后缀显示窗口 / 空框 /
整框就是我们自己的半成品占位符帧）才清 —— 用 Pi 编辑器自己的键 `ctrl+a`（行首）+ `ctrl+k`
（删到行尾、行尾并下一行），成对重复，与光标位置无关、空框幂等；混进人的字**一个键都不碰**
（宁留不删）。held 原因区分 `draft-raced-retracted`（已收回，框里无残留）与 `draft-raced-left`
（留在框里，日志写明「框里已有人的内容，未动」），两者都是终态（绝不重贴）；digest / status 的
`outbox …` 行、`team outbox list`、面板队列页都能看到这层区分。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/outbox.sh` | `team_box_text_holds_only`（纯文本判据，从原 `team_box_holds_only` 拆出）+ `team_box_retract_safe`（放弃 Enter 前的收回判定）+ `team_tmux_retract`（ctrl+a/ctrl+k ×24，写完轮询确认框空）+ 放弃路径改写（成功 → rc 7；失败/混入 → rc 3 且一个键都不再发）+ `draft-raced-left` / `draft-raced-retracted` 两种终态原因（终态集合 `draft-raced\|draft-raced-*\|unconfirmed`）+ `team_outbox_held_residue_counts` + status/digest 行的「已收回 X · 留在框里 Y」分档 |
| `skills/teamsmith/tests/fake-tui.py` | 夹具从「尾部字符串」升级成**带光标的编辑器模型**（Pi 0.85.1 键位：`ctrl+a` 行首 / `ctrl+k` 删到行尾、行尾并下一行 / `ctrl+u` 删到行首 / `ctrl+e` 行尾 / backspace 删前一个字符、行首并上一行；打字与粘贴插在光标处；光标按折行后的显示坐标绘制；半成品被收回后不再自行补全）——没有这个，收回键序只会被当成控制字节插进框里，测出来的「已收回」是假的 |
| `skills/teamsmith/tests/smoke.sh` | `12b-g` 新增残留分档断言（status / digest / outbox list / 面板队列块 `team __panel-data --block outbox_list` 四个出口）；`⑨` 改成 M17 形状②（混入人的字 → `draft-raced-left`、整段原样不动、digest 报「留在框里 1」）；`⑰` 改成形状①（停顿超过等待上限 → 收回、框里无残留、`draft-raced-retracted` 终态、之后排水零提交）；`⑰d` 新增升级兼容（老 `stall-timeout` 条目仍被下一拍补 Enter，恰好一次提交） |
| `skills/teamsmith/tests/flip-m17.sh` | 独立翻转包：同一真 pane 夹具（折叠停顿 2500ms）对三棵树各跑一遍 —— 红 = 分叉点（旧实现留字）、绿 = 本树（已收回）、变异 = 绿树副本禁掉 `team_box_retract_safe`（必须重新变红）。tmux 走私有 socket（PATH shim），身份先断言 `team paths` 指向夹具仓库 |
| `skills/teamsmith/references/troubleshooting.md` | §3 重写相关条目：收回纪律与两种残留状态、收回键与「收回经过回读验证」、V9-B6 的 resume 只适用于老版本留下的 `stall-timeout` 条目 |

**范围自查（brief 的边界）**：只动了 `scripts/lib/outbox.sh`、`tests/**`（夹具 / smoke 自己的段 /
新增翻转包）、`references/troubleshooting.md` 一节。**账本（BOARD/ROADMAP/DECISIONS/OWNERSHIP/reviews/
tasks）一个字节没动**；`openspec/**` 没动（见 BLOCKED）。

## Verification evidence (must have actually been run)

**最终验收（交付树；这一提交是 docs-only，下面的命令在这个树上串行跑完）**：

```sh
$ export PATH="$HOME/.bun/bin:$PATH" \
  && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh \
  && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
- Validating... … ✓ spec/watchdog
Totals: 13 passed, 0 failed (13 items)
… == 结果 ==  ✓ 1840  ✗ 0
smoke 全绿
… == 结果 ==  ✓ 1427  ✗ 0
FAST 模式：跳过 18 个真进程段落 …
smoke 全绿                                                     三段 rc=0

$ bash skills/teamsmith/tests/flip-m17.sh
== 结果 == flip 全绿（红→绿→变异红）                          rc=0
```

M17 改写/新增的断言全在绿里（对照 `main`：新增 24 条、替换 7 条）：`12b-g` 残留分档 6 条（status / digest /
outbox list / 面板队列块四个出口）、`⑨` 形状② 5 条（含「一个键都没碰」与「留在框里 1」）、
`⑰` 形状① 13 条（收回、终态、digest「已收回 1」）与升级兼容 `⑰d` 3 条；正常路径（形状③）由同节的
`⑯a/⑯b` 原断言守着（恰好一次提交、已确认送达、队列清空）。

**26-m 的一次红（如实记录，与本任务无关）**：同一条验收链在 07:26 那次是 `✓ 1839  ✗ 1`，唯一的红是
`26-m 回响：按 s 后 1.5s 内标题带没出现待命原因`（现场标题行仍是 `… 巡检 900s · 待命 off`）。判断依据：

- **那一刻机器上有另一套全量 smoke 在跑**：`ps` 快照里 PID 2137625 `timeout 1800 … smoke.sh`（ELAPSED 1602s
  → 07:10 启动，快照时 07:37 仍在）；稍后还有另一个 agent 的 M18 验收全量（`/tmp/M18-full-smoke.txt`）与
  PM 的 `/tmp/review-M18` 复验并发。机器空闲下来后的串行重跑（本报告上方的验收块）是 `1840✓/0✗`；
  本分支共 4 次全量里，这个断言红过 2 次、绿 2 次（同一断言、同一 deadline；本次红时有另一套全量 smoke 在跑）。
- 那条断言是**面板输入回响的 1.5s deadline**（按 `s` → 输入 → `Enter` 后 1.5s 内标题带必须出现原因），
  红在面板自己的输入路径上；**M17 不在那条路径上**：M17 唯一改的可见性函数 `team_outbox_status_line` 只被
  `scripts/lib/cmd-status.sh` 的 status/digest 调用；面板每个数据块走 `team __panel-data --block …` →
  `team_panel_*_json`（cmd-watch.sh），这些函数本分支没改；面板 TUI 源码（`scripts/panel/**`）与 `monitor.mjs`
  也不在本分支 diff 里。

建议由该段 owner（PM）决定：把 1.5s 的输入回响 deadline 放宽或改成轮询重试采样 —— 该段不在 M17 的边界内，我没动。
（各轮全量的断言总数在 1839/1840 之间浮动一条，属运行时分叉的那类断言；M17 自己的断言全部在绿里。）

## Flip evidence (required for defect-fix tasks)

```sh
$ bash skills/teamsmith/tests/flip-m17.sh
flip-m17 · 红树=fe42bbc…（分支分叉点） 绿树=本 worktree（真 pane 夹具：折叠停顿 2500ms 后放弃 Enter）
  ✓ 红（修复前）：放弃 Enter 后字还留在框里（判据会红）
      reason=stall-timeout  submits=1
      flush 之前的框（残留行）：4:[paste #1 +14 lines]     ← 用户的形状：字留在框里
  ✓ 红树确实是用户实测的形状：flush 之前框里立着我们的 payload/占位符
  ✓ 绿（本树）：放弃 Enter 后已收回 —— 框里无残留、零提交、reason=draft-raced-retracted
      reason=draft-raced-retracted  submits=0
  ✓ 绿树：flush 之后仍然零提交、框里仍然没有残留（终态）
  ✓ 变异：去掉收回后同一判据变红（守门断言可被证伪）
      reason=draft-raced-left  submits=0
      flush 之前的框（残留行）：4:[paste #1 +14 lines]
  ✓ 变异树走了「留在框里」分支（reason=draft-raced-left）—— 正是没收该走的路
== 结果 == flip 全绿（红→绿→变异红）
# 独立包：skills/teamsmith/tests/flip-m17.sh（不复用 smoke 的夹具与断言；tmux 私有 socket + 身份断言）
```

## Decisions and deviations

- **中间帧停顿（V9-B6）的新结局**：新条目不再产生 `stall-timeout`；停顿超过等待上限时按 brief
  形状①**收回 + held（`draft-raced-retracted`，终态）**。旧版已经落盘的 `stall-timeout` 条目
  仍走 resume（只补 Enter、绝不重贴）——`12b-h ⑰d` 守着这条升级兼容。
- **终态集合**从 `draft-raced|unconfirmed` 扩成 `draft-raced|draft-raced-*|unconfirmed`：两种新
  原因与旧原因同样是终态，`flush` / `flush --now` 都不重贴。
- **发送方的措辞没动**：spec 要求 held 消息对发送方仍报 `queued`（退出码 0），所以 `draft send` /
  `say` 的消息保持原样；但它们尾巴上的「清空后自动投递」对**终态** held 是不准确的 —— 修它要动
  `cmd-draft.sh` / `cmd-agents.sh`（PM 目录，不在本任务边界），作为 finding 交回。
- **面板可见性**：每条的区分走 `reason`（面板队列页已经渲染 `扣住原因：<reason>`，`team
  outbox list` 同样逐条显示）；面板**顶栏摘要**（`monitor.mjs outboxSummary`、`team_panel_outbox_json`）
  仍只有 held 计数 —— 要让摘要也显示「已收回/留在框里」需要动 PM 目录，见 BLOCKED。
- **收回键的残余窗口**：清键与「框里只有我们」的读数之间隔一条命令；混入的字不会被删，但理论上
  存在一个极窄的交错窗口。按既有纪律写进 troubleshooting §3，不藏。

## Suggested next steps

- `BLOCKED:` **delivery-guard spec 需要 PM 的 spec delta（openspec/** 是 PM 独占，本 brief 没明授）**：
  `openspec/specs/delivery-guard/spec.md` 里 “A slow fold is held recoverably and completed by the next
  drain” 场景与主文中 “a later drain MUST retry it in resume mode — completing the pending `Enter` when
  the box still holds only that payload” 已被 M17 取代：新条目在等待上限处**收回**并终态 held；
  resume 只服务老条目。另一处措辞：“A draft-raced entry is terminal” 的触发原因现在分
  `draft-raced-left` / `draft-raced-retracted`（终态集合已扩）。
- `BLOCKED:`（可选，取决于用户要不要在**顶栏摘要**看到分档）面板摘要行在
  `skills/teamsmith/scripts/monitor.mjs` + `scripts/lib/cmd-watch.sh`（PM 目录，不在本任务边界）；
  队列页的逐条区分已生效，无需改动。
- 阶段任务的最终门禁已在 `9a9c04e` 上全绿（见上）；`26-m` 的时序抖动与本任务无关，若后续负载下再现，
  由面板 owner（PM 目录）决定要不要放宽 deadline。
