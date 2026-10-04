# P134 · `meeting-liveness` propose：发现性（A）+ 收尾（B）+ 投递安全 + 规格补齐

```
task:   P134
agent:  dev3
issue:
change: meeting-liveness
specs:  watchdog#Pending work is defined, and no work means no wake-up · meeting#The shared area is the single source of truth · meeting#Meetings are bounded · delivery-guard#An automated send never types into a non-empty input box
phase:  propose
anchor: change
deltas: meeting,notify-and-inbox,watchdog,delivery-guard,panel
grant:  openspec/changes/meeting-liveness/** · docs/team/reports/P134-dev3.md · docs/team/reports/P134-dev3/**
deps:   D64/D65（两条实测缺陷 + <peer-c> 的实证 ✓）· `docs/team/DECISIONS.md` D64/D65 · **不做**：① 不写对方仓库（`meeting#Zero writes into the peer project` 保持 ✓）· ② 不引入 `order/command` 类 intent（`meeting#Intents are informational…` 保持 ✓）· ③ 不做跨机器 ✓
status: todo
budget: 一个提案
priority: 高（用户已批"AB+规格" ✓；D65 的实证：同行 PM 的反馈躺了 2.5 周 ✗）
```

> **用户已定的范围**：**A（发现性）+ B（收尾）+ 补规格** ✓；**投递安全**由 PM 并入同一 change ✓（见下 ③ ✓）。

## 现场（PM 实测，都要变成可证伪的 requirement）

1. **发现性 = 0** ✗：`team watch` / `team status` / `digest` 里 **grep `meeting` 0 命中** ✗ →
   对端发言后**没有任何东西叫醒 PM** ✗。实证：`<peer>-pi-team-feedback` 的 3 条同行报告 **躺了 2.5 周** ✗（D65 ✓）。
2. **收尾靠自觉** ✗：TTL 到期只变**只读** ✓，不标 `expired` ✗、不在任何视图显示 ✓ → 该会议至今 `open(过期)` ✗。
3. **投递安全** ✗（PM 今晚实测，D64）：敲门走 `team_tmux_send_text` = **裸 `send-keys -l` + `Enter`** ✓，
   **不经过** P63/P67 的输入框判定 ✓ → 若对方 PM 输入框里有草稿 ✗，通知会被**粘进草稿** ✗。
   （对照：内部路径自 P63/P67 起**永不**往非空输入框打字 ✓ —— `delivery-guard#An automated send never types into a non-empty input box` ✓。）
4. **`PM_WINDOW` 一个字段服务两个方向** ✗（D64）：默认 `pm` ✗ → 对方 PM 窗口叫 `pi` ✗ 时**静默失败** ✗；
   改成 `pi` 后**送达** ✓，但"他们敲我们"会打到 `teamsmith:pi`（不存在 ✗）→ 需要**每个参与方各自登记自己的窗口** ✓（或自动探测该 session 里的 pi pane ✓）。

## 要 propose 的（每条都要 requirement + scenario，**可证伪**）

- **A 发现性** ✓：把「**有指向我、且我没读过的会议发言**」并入 `watchdog#Pending work is defined…` 的 pending 定义 ✓
  （**保留**该 requirement 的基线场景 ✓：无待办必须**静默** ✓）；`team status` / `digest` 各一行 ✓；
  `meeting inbox` 语义不变 ✓；面板一行（`panel` delta ✓）。
  **判据**：对端发言 → **下一个巡逻周期** PM 被唤醒 ✓；无新发言 → **依然静默** ✓（两向 ✓）。
- **B 收尾** ✓：TTL 到期 → 状态标 **`expired`** ✓（仍只读 ✓）、`status`/`digest` 显示"已过期未关闭" ✓、
  `team meeting close --stale` 一键收 ✓（语义：只关**过期**的 ✓，不动别人正在用的 ✓）。
  **判据**：过期会议的 `list` 行**能看出过期** ✓；`close --stale` 只碰过期项 ✓（反例：未过期 → 拒绝 ✗）。
- **③ 投递安全** ✓（并入同一 change ✓）：敲门必须走**同一条受守卫的自动化投递** ✓（或至少在投递前判 box ✓），
  复用 `delivery-guard` 的既有 requirement ✓（**MODIFIED 不许丢基线场景** ✓）。
  **判据（红侧）**：让对方 PM 的窗口里**放一份草稿** → 敲门**不许**把通知粘进去 ✓（要么报"排队/未投递" ✓）。
- **④ 每方自己的 PM 窗口** ✓：把"对方窗口"从**会议级单字段**改成**每参与方一条** ✓；
  **判据**：对方窗口名不是 `pm` 时敲门仍然**送达** ✓；改我们这边自己的窗口名**不影响**对方 ✓。
- **规格补齐** ✓（用户要的"规格"）：把实现里有、规格里没有的行为补成 requirement：
  transcript 是唯一真相 ✓、TTL/轮次（bounded ✓）、agreement 的双向确认（不能自证自己提的 ✓）、
  **写隔离**（零写入对方项目 ✓）、以及 A/B/③/④ 各自的新 requirement ✓。
  **约束**：`meeting` 现有 **6 条 requirement / 9 个 scenario** ✓、`delivery-guard`/`watchdog`/`panel` 的基线场景**一条都不许丢** ✓
  （写清 MODIFIED 的前后对照表 ✓）。

## 交付

`openspec/changes/meeting-liveness/{proposal,design,tasks}.md` + `specs/{meeting,notify-and-inbox,watchdog,delivery-guard,panel}/spec.md` ✓；
`openspec validate --all --strict` ✓；**非目标** ①②③ 写在 proposal 里 ✓；给 PM 的评审清单足够**机械可核**（MODIFIED 前后场景对照 + 每条判据的红侧 ✓）。
