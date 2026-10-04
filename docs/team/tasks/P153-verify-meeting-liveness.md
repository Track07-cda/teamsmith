# P153 · `meeting-liveness` 独立验证（换人：实现是 dev3）

```
task:   P153
agent:  verify                     # 只读验证；不许改实现（OWNERSHIP）
issue:
change: meeting-liveness
specs:  meeting#A participant is recognized by its recorded names, not by one spelling
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P153-verify.md · docs/team/reports/P153-verify/**
deps:   合并提交 `feat(teamsmith): P139 …`（在 main）· 评审 `docs/team/reviews/meeting-liveness-proposal.md` · 实现自述 `docs/team/reports/P139-dev3.md`（**是主张，不是证据**）· D31
status: wip
budget: 一次对抗性验证
priority: 高（动了巡逻 / 敲门投递 / 通知路径 / 多个待办读者 —— 面广）
```

## 要独立证明或证伪的（**自己造场景**，别只跑作者的夹具；每项都要红侧）

1. **发现性** ✅：造"有一场会议、对端发言、我未读" → `team __panel-data --block pending` 的 `meetings` 字段与 `total` 上升 ✅、
   `team status`/`digest` 的行可见 ✅、巡逻一拍（`team watch --once` ✅）**会把 PM 算成有待办** ✅；
   **反向**：全读掉之后**必须归零且静默** ✅（不许留一条"永远待办" ✅）。
2. **收尾** ✅：未过期 → `close --stale` **拒**且**什么都不写** ✅（比文件 mtime 更硬：内容逐字节不变 ✅）；
   过期 → `list` 可见 `expired` ✅、`close --stale` 只关过期项 ✅、关掉之后 `say` 只读 ✅；
   **边界**：把 `OPENED_EPOCH` 设成"刚好等于 TTL 边界"✅ 与"稍早一点"✅ 两种，判据要与文档一致 ✅。
3. **投递安全** ✅：对手忙/有草稿时敲门**不许**直接粘进去 ✅ —— 要么 `queued` 可见 ✅ 要么明确失败 ✅；
   **红侧**：把发送路径 shadow 回裸 `send-keys` ✅ → "草稿不被污染"那条断言必须红 ✅。
4. **身份（R1）** ✅：三方场景 —— 记的是**会话名**、记的是**仓库名**、以及**两者都不是**（真第三方）✅；
   前两种都要能用 ✅，第三种必须拒 ✅。（我在 PM 侧已验过前两种，请你用**自己的**夹具重做 ✅。）
5. **标识（R2）** ✅：会议 knock 带 `[meeting:<slug>#<turn>]` ✅ 且 `knocks.log` 同号 ✅；
   任务通知带 `task=<ID> tip=<7hex>` ✅ 且**只在任务分支上**打 ✅（手工 notify 不许编造 ✅）；
   **stale 判定只用接收方自己的账本** ✅（board done/closed 或 (task,tip) 与 reviews/<ID>.md 的 HEAD 相同 ✅）——
   请你**故意**造一条 stale 与一条 fresh，验证两种判定 ✅。
6. **每方窗口（R2 的另一半）** ✅：`PM_WINDOWS=<proj>=<win>;…` 与旧 `PM_WINDOW` 的兼容 ✅；
   改我方那行**不影响**对方 ✅（反之亦然 ✅）。

## 现场追加（**PM 今天实测撞到的**，务必优先复现）

2026-10-01T18:17Z，我用 `team meeting say <slug> --intent report --knock "…"` 对**真实对端**敲门 ✗ —— 命令**挂住了 900 秒**（我的外层 `timeout` 把它杀掉），
期间**没有**任何输出 ✗、`knocks.log` **没有**新增记录 ✗（最后一条仍是 09-30 的 ✅），
而我们自己的 `state/tmux-calls.log` 在 `18:17:03Z` 连续记录到对目标 pane 的
`capture-pane -p -t <peer>:pi` 与 `display-message -p -t <peer>:pi #{cu…` ✅（= 它反复在**判输入框** ✗），**始终没有** `send-keys` ✅。

**契约**（`meeting-liveness` 3.x）：目标忙/有草稿 → **排队**并如实报 `queued` ✅；不许把通知粘进草稿 ✗。
实测是**挂住** ✗ —— 要么某处无界等待 ✗，要么等待窗口长得离谱 ✗。

**要你做的**：
1. 在**夹具窗口**（私有 server ✅ 见安全铁律 ✅ 或容器 ✅）上复现：造一个"目标忙/框非空"的 pane ✅ →
   跑 `meeting say … --knock` ✅ → 记录：**是否有界**（多少秒 ✅）、退出码 ✅、输出 ✅、`knocks.log` ✅、是否 `queued` ✅；
2. 定位那几秒/几分钟花在哪（`capture-pane` 循环 ✅ / `display-message` 轮询 ✅ / 目标 pi 存活探测 ✅），给出代码行 ✅；
3. 若确认是**无界或过长等待** ✗ → 写成**可直接派单**的缺陷描述 ✅（含最小复现与红侧判据 ✅）；
4. **禁止**对真实对端窗口做任何实验 ✗（用夹具 ✅）；也**不要**再对真实对端重试敲门 ✗（消息已在共享区 ✅）。

7. **门禁**：`openspec validate --all --strict` ✅ + **你在自己的独立检出上**跑 `--select 55,56` ✅ + **FAST** ✅；
   报告写清原始输出 ✅、你**没有**测到什么（例如 pulse 面板真机目视 ✅、非 Pi 适配器 ✅）。
