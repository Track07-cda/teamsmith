# 跨项目会议（meeting mode）

两个项目之间**正常交流**（接口怎么接、提建议、报问题）用这套机制；它不是聊天室，更不是指挥通道。

## 边界（每次开会都适用）

| 允许 | 不允许 |
|---|---|
| 讨论接口/契约/字段/时序/错误码 | 指挥对方 PM 或 agent 做事 |
| 提建议 + 依据（实测/文档/权衡） | 替对方下决策 |
| 报告问题与复现 | 冒充人类下达指令 |
| 问信息、约联调窗口 | 改对方仓库/状态、替他合并 PR |
| 各自认领自己那半边 | 把"共同决定"当既成事实强推 |

- **会议只产出「共识 + 各自待办」**，不产出对另一方的命令；落地永远由各方在自己项目内完成。
- `intent` 只有 `info | question | report | proposal | request` —— **机制里没有 `command`**。
- 共识必须双方各自 `agree`；`AGREEMENTS` 里每条都写"我方落地 / 对方落地"。
- **worker 不参会**：跨项目沟通只走 PM。worker 需要外部配合就在报告里写 `BLOCKED:`。
- **用户**是唯一能跨项目下指令的人（人类终端里 `team meeting say --as-user`；agent 进程会被拒绝）。

## 共享区（两个项目之外）

```
<meetings>/<slug>/            # 默认 ~/.pi/team/meetings/<slug>/
├── agenda.md                 # 议题 + 边界 + 关闭记录
├── state.env                 # 参与方 / peer session / TTL / MAX_TURNS / 状态
├── transcript/0001_<项目>_<intent>.md    # 追加式发言（唯一真相，先写盘再敲门）
├── agreements/A1.md          # 共识条目（提案 + 各方 agreed-by）
├── read/<项目>.seq           # 各家已读位置（inbox 靠它算待读）
└── knocks.log                # 敲门记录（有敲门时）
```

## 命令

```bash
team meeting open <slug> --with <项目>[:<session>] --topic "订单接口对接" --ttl 72 --yes
team meeting say <slug> --intent proposal "建议 POST /orders 增加 idempotency_key（UUID，必填）" [--knock]
team meeting read <slug> [--since N] [--peek]      # 默认读到哪标记到哪
team meeting inbox                                  # 哪些会议在等我回应
team meeting list [--all]
team meeting propose <slug> "接口契约 v1：字段/错误码/超时" --sides "我方:… / 对方:…"
team meeting agree <slug> A1 [--note "我方落地：T4.2"]   # 必须是对方确认（不能确认自己提的）
team meeting close <slug> [--summary "结论与遗留"]        # 关闭后只读（transcript 冻结）
```

`--with <项目>:<session>` 里的 session 用于**敲门**（提醒对方 PM 有会议消息）；
不知道对方 session 也能开，只是敲门不可用（消息仍在共享区，对方巡检 `meeting inbox` 能看到）。

## 工作流示例

```bash
# A 项目（发起）
team meeting open order-api --with <peer>:<peer> --topic "订单接口对接" --yes
team meeting say order-api --intent proposal "POST /orders 建议增加 idempotency_key；重复提交返回同一单号"
#   → 想立刻提醒对方 PM（对方项目需允许敲门）：加 --knock（且双方 TEAM_MEETING_KNOCK=1）

# B 项目（回应）
team meeting inbox                     # → order-api（1 条新发言）
team meeting read order-api
team meeting say order-api --intent question "重复窗口多长？10 分钟够吗？"
team meeting say order-api --intent request "请你方决定：窗口 10 分钟 / 24 小时"   # 请求对方决策，但**不代他决定**

# 形成共识
team meeting propose order-api "窗口 24h；重复提交返回同一 order_id" --sides "我方:api 侧 / 对方:订单侧"
# 对方确认
team meeting agree order-api A1 --note "订单侧落地：T5.1"
team meeting close order-api --summary "契约已定；遗留：批量提交的幂等键格式待定"
```

## 敲门（默认关）

- `say` 默认**只落盘**：对方 PM 下次巡检 `team meeting inbox` 就会看到。
- 紧急时 `--knock`：给对方 PM 窗口发一行 `[meeting:<slug>] … 有新发言`。
  前提：① 全局开关 `TEAM_MEETING_KNOCK=1`；② `open` 时登记了对方 session；③ 对方窗口里正在跑 pi。
- 敲门是**唯一**允许的跨 session 动作，且只发"有消息"这一行——不替对方做任何决定。

## 敲门失败怎么查

```bash
team meeting peer <slug> <项目>:<session>   # 事后登记/更新对方 session（open 时没写也能补）
team meeting knock <slug>                   # 登记完重敲最后一条发言
```

`knock` 会按顺序报五件事：① `TEAM_MEETING_KNOCK` 开关 ② 对方 session 是否登记 ③ tmux 里有没有那个
session ④ 对方 PM 窗口里是否真的在跑 pi ⑤ 边界守卫是否放行。**敲门失败不影响消息**——它已经在共享区里。

## 守卫（代码级）

| 守卫 | 行为 |
|---|---|
| 跨 session 打字默认拒绝 | 未登记的跨 session `send-keys` 一律拒绝；只有"已登记会议的敲门"放行（`TEAM_GUARD_FOREIGN_TARGET=1`） |
| 先落盘再敲门 | 消息进 transcript 才可能敲门；敲门失败不丢信息 |
| 身份不可伪造 | 每条发言带 `from: <项目>/pm@<session>`；接收方一律按 peer 陈述对待 |
| 拒绝冒充人类 | `--as-user` 需要人类终端 + `TEAM_MEETING_ALLOW_USER_ID=1`；agent 进程写会被拒 |
| 拒绝下令 | `intent` 白名单外一律拒绝；正文带 `[order]/[command]/[指令]/[命令]` 也拒绝 |
| 限流 | 每边 `MAX_TURNS`（默认 20，取自会议登记，env `TEAM_MEETING_MAX_TURNS` 更严时以 env 为准） |
| 过期 | `TTL_HOURS`（默认 72）到期后只读，需 `close` 或 `open --force` 续期 |
| 零写他人 | 会议链路只写共享区；对对方仓库没有任何写权限 |

## 配置

| 键 | 默认 | 说明 |
|---|---|---|
| `TEAM_MEETINGS_DIR` | `~/.pi/team/meetings` | 共享区位置（两个项目之外，别放进某个项目仓库） |
| `TEAM_MEETING_TTL_HOURS` | `72` | 会议有效期；过期只读 |
| `TEAM_MEETING_MAX_TURNS` | `20` | 每边发言上限（硬上限，比会议登记更严时以它为准） |
| `TEAM_MEETING_KNOCK` | `0` | `1`=允许 `--knock` 提醒对方 PM 窗口 |
| `TEAM_MEETING_ALLOW_USER_ID` | 空 | `1`=允许人类终端用 `--as-user`（跨项目指令只由用户下） |
| `TEAM_GUARD_FOREIGN_TARGET` | `1` | 跨 session 打字总守卫（会议敲门是唯一例外） |
