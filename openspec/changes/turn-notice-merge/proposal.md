# turn-notice-merge · 回合通知的合并与原始明细（C-1）

## Why

每个回合结束，席位往自己的收件箱追加一行 `[auto*]` 通知（`extension/team-notify.ts:530-534`），而 PM 的未读数
就是**行数**：`team_inbox_new` = 文件总行数 − ack 基线（`scripts/lib/cmd-status.sh:31`），`team digest` 的
「待处理通知」逐文件计数并只印尾 3 行（`cmd-status.sh:770-777`），面板的 inbox 块同样按行数统计
（`cmd-watch.sh:1121`）。一行的正文只带**最后一条摘要**（` :: <last>`），所以同一任务上「挂起 → 复活 →
再挂起」的每一次重复都必须留成新行，否则证据就没了 —— 今天只能全留，噪声直接变成 PM 的待办数。

任务书引用的实测（2026-10-13）：`verify` 71 行其中 46 条这类、`dev` 48/33、`dev3` 43/31、`dev2` 35/24、
`dev-bob` 26/20；PM 的未读一度到 **93**，绝大多数是同一任务上的重复轮次。本提案复核（2026-10-14，主检出
只读 `wc -l` / `grep -c '\[auto'`）：`verify` 71/47、`dev` 48/42、`dev3` 43/31、`dev2` 35/25 —— 同一形状。

**用户已采纳的做法（C-1，2026-10-14）**：**带兜底的合并** —— 只在**同一席位 + 同一任务 + 同一状态类 +
同一 `awaiting` 集合**内合并成一行（显示 ×N 加首末时间）；**每一条原始事件照样写进一个明细文件**
（`state/notify.log`，有界、**不进收件箱**）；**状态类一变立刻新起一条并叫醒 PM**；跨席位、跨任务、
跨状态类**永不合并**。

## What Changes

- **合并键与合并行**：key =（席位、任务、状态类、`awaiting` 集合）。席位取解析出的发送者；任务取行里的
  `<ID>` token（有 `task=` 戳时就是它）；状态类取标签（`[auto]`→`delivered`、`[auto·suspended]`→`suspended`、
  `[auto·interrupted]`→`interrupted`）；`awaiting` 是无序集合（ids 去重、顺序不改变 key），
  **缺字段与空集是两个不同的值**。合并只发生在**收件箱末尾那一行**上；末尾不是同类 run 就新起一行。
  **首个事件的行与今天逐字节相同**；一旦汇总 ≥2 条，行在 ` :: ` 前的字段区带上 `×N first=<ISO> last=<ISO>`，
  其余字段（`branch=`/`uncommitted=`/`unpushed=`/`tip=`）取**最后一条**的值，`last=` 点名那一条 ——
  不许取最大值、平均或任何合成值。既有前缀词汇（`[auto]`/`[auto·suspended]`/`[auto·interrupted]`）与既有
  字段名一个不改。
- **明细文件**：`state/notify.log` 一行一事件（内容 = 同一事件单发时的收件箱行），在合并判定**之前**落盘，
  所以合并行的 `×N` 与记录数**永远一致**（没有记录的事件不参与合并）。上界 `TEAM_NOTIFY_DETAIL_MAX`
  （默认 2048 事件）；越界轮转到 `state/notify.log.1`（只留一代），新代首行是轮转头（轮转时间 / 上代路径 /
  搬走的事件数），轮转另记扩展日志。写入失败**不许静默**：该事件不合并、行上带 `detail=unavailable`、
  扩展日志点名失败。`team inbox <agent> --detail` 是它的读面：打印当前代的原始记录与读到的文件路径/轮转
  状态，并对该席位每条合并行核对 `×N` 与找到的记录数；缺文件或记录不全都点名
  `state/notify.log`/`state/notify.log.1` 并**非零退出**。该标志只读：不 ack、不改变未读数。
- **叫醒判据（可证伪）**：**写入新行才叫醒** —— 每个写新行的 settle 恰好入队一条 knock；扩展既有 run 的
  settle **不入队、不敲字**（同类计数抖动看得见但不叫醒；P174 的教训：叫醒键按稳定的类别集合、计数抖动
  不叫醒，见 `openspec/changes/archive/2026-10-03-pulse-nudge-key`）。状态类变化就是键变化，必然新行并叫醒。
  knock 的去重身份是**行身份**（席位、合并键、首事件时间），两条文本逐字相同但不同的行不会被互相吞；
  写盘失败的 settle 不叫醒（与手工路径既有的「写失败不得授权唤醒」同一条规则）。
- **不变量**：跨席位/任务/状态类不合并；`[manual]`/`[draft]`/`[nudge]` 与 pulse 自己的行完全不受影响
  （不合并、不进明细、叫醒照旧），夹在两次同类事件之间也不被改写；行计数读者（`team digest` 未读计数、
  面板 inbox 块、`team inbox --ack`）把合并行当**一行**数，已读行被后续同类事件扩展后仍是已读；
  陈旧判据在合并行上读**最后一条**的 `task=`/`tip=`，且不得把行的字段当成席位当前状态。
- **范围外**：敲门的传输机制（`delivery-guard`/outbox 语义）、巡检叫醒键（P174 已治）、关键回复页
  （已归档的另一 change）、派单/路由/账本写入、`team reply` 一律不碰；不新增页面、不改面板；不改
  `[auto*]` 词汇与既有字段名；不改 `TEAM_NOTIFY_DEDUP_SEC` 的语义（窗口内的重复 settle 仍是同一事件：
  既不进明细也不推进 `×N`）。

## Capabilities

### Modified Capabilities

- `notify-and-inbox`：
  - **MODIFIED** `A turn-end notification appends one inbox line and knocks once`：合并键与合并行形状、尾行锚、
    叫醒判据、合并行上的陈旧判据与既有读者的行为、`detail=unavailable` 兜底；基线 16 条场景逐字保留。
  - **ADDED** `A turn-end notification's raw events stay in a bounded detail file`：明细文件的写入顺序、格式、
    上界与轮转、`team inbox --detail` 读面与缺口点名。
- 不新增 capability：通知的写入面本来就在 `notify-and-inbox`，本变更只改它的两条要求，不另立一套。

## Impact

- 产品面：`skills/teamsmith/extension/team-notify.ts`（settle 路径改为走写入入口，按写入结果决定叫醒）、
  `skills/teamsmith/scripts/lib/cmd-agents.sh`（收件箱写入口：per-recipient 锁 + 尾部 read-check-rewrite +
  明细与轮转）、`skills/teamsmith/scripts/lib/cmd-status.sh`（`team inbox --detail`）、
  `skills/teamsmith/scripts/lib/cmd-config.sh`（登记 `TEAM_NOTIFY_DETAIL_MAX`）、
  `skills/teamsmith/references/config.md`（键的说明）。
- 夹具面：`skills/teamsmith/tests/bg-ledger.sh` 与 `bg-ledger-harness.mjs` 增加 `merge`/`detail`/`wake`
  三组与对应翻转（通知面的既有夹具入口）；`skills/teamsmith/tests/section-paths.tsv`（或预算表）登记归属；
  `suspend-shape`/`owner-scope`、smoke §13/§13b/§13c 与 §7 作回归 —— **单事件行必须逐字节不变**。
- 规格面：`openspec/specs/notify-and-inbox/spec.md` 的 1 条 MODIFIED + 1 条 ADDED，delta 在
  `openspec/changes/turn-notice-merge/specs/notify-and-inbox/spec.md`。
- 兼容性：单事件行逐字节不变（不合并的行上没有 `×`/`first=`/`last=`）；合并行只是新增字段，旧读者照读；
  `state/notify.log` 是新文件、新键有默认值。
- 排期：一个 apply 席位做写入面（tasks 第 1–3 节）再读写面（第 4 节）；verify 由**另一席位**在独立克隆上
  重跑全部场景与红侧（写的人不验自己的活）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **锚只在尾行**：合并只认收件箱**最后一行**；中间被 `[manual]`/别的 run 的行插开就结束本 run，下一次
   同类事件新起一行。**推荐：是** —— 重写文件中间的行要与并发追加抢同一条尾巴；尾行锚 + per-recipient 锁
   是能证明「不丢行」的最短路径，代价只是打断后多一行，原始事件一条不少。若裁定「穿行合并」，需要额外的
   原子重写协议与对应的新红侧。
2. **明细上界用「一代轮转 + 默认 2048 事件」**：**推荐：是** —— 轮转的代价是更早的原始事件被覆盖，但
   缺口会被读面点名；按大小截断头部的方向相反（先丢最近的），「按宿主/大小截断」若被理解成截尾则不成立。
3. **新增读面 `team inbox --detail` 与它的非零退出**：**推荐：是** —— 缺文件/记录不全时退出非零，脚本能
   把它当异常；若希望 `team inbox` 保持「异常只警告、永远退出 0」，改一条断言与一行判定即可。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail,wake    # 写入面三组（夹具入口以 apply 冻结的键为准）
bash skills/teamsmith/tests/bg-ledger.sh --select flip                  # 逐条破坏 → 指定用例必红；还原 → 全绿
bash skills/teamsmith/tests/bg-ledger.sh                                # 挂起面回归 + 新三组
bash skills/teamsmith/tests/smoke.sh --select 13,13b,13c,7              # 单事件行逐字节不变 / 通知面回归
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-notify.ts \
  skills/teamsmith/scripts/lib/cmd-agents.sh skills/teamsmith/scripts/lib/cmd-status.sh
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。

## Out of scope

- 不改敲门的传输机制（sendMessage/followUp/triggerTurn、投递守卫、outbox 的排队与去重语义）。
- 不改巡检叫醒键（P174 已治）、不改关键回复页、不改 `team reply`。
- 不改派单/身份/模型路由/账本写入，不改面板与 `--print`/`--json` 的字节。
- 不给 `[manual]`/`[draft]`/`[nudge]`/pulse 行做合并或明细。
- 不新增配置以外的运行时依赖，不新增页面，不加 Pi 工具。
