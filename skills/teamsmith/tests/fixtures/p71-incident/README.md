# P71/wake-delivery-idempotence — 事故字节夹具（原样复制，不重写）

这四份文件是 2026-09-22 现场文件的**逐字副本**，供 harness S25f（事故重放）直接使用。
来源与大小：

| 文件 | 原始路径 | 大小 |
|---|---|---|
| `dev2.wake` | `<pm-skills>/.pi/team/state/inbox-watch/teamsmith_dev2-e88859f1.wake` | 1929 B · 9 行 |
| `dev2.seen` | `<pm-skills>/.pi/team/state/inbox-watch/teamsmith_dev2-e88859f1.seen` | 1701 B · 8 行 |
| `pm-nudges.wake` | `/var/tmp/P71-pm-wake-spool-1746.bak`（76100 B 的 PM spool 前身）里含三个 nudge 时间戳的行 | 690 B · 3 行 |

形状（design §1 引用的事实）：

- `dev2.wake` 与 `dev2.seen` 的差集恰好是最老的一行（`1789810336525`，`M35 范围+1`）——
  它就是「投递过、但没记进去重记忆」的那一行；恢复规则不允许它再被叫醒，过期规则兜住它。
- `pm-nudges.wake` 的两行文本逐字相同（`[pulse] 待办：未读通知 7 · 待复验 4`），只有时间戳
  （`1790093637236` / `1790094537381`）与第三行的 `未读通知 9` 不同 —— PM 当时看到的
  「同一条被叫两次」正是这两条**不同**的行。

S25f 的行为：用这些原始字节建 spool，从 `.seen` 与三个 nudge 交付事实播种投递日志
（`sent … imported=1`），然后重放事故的截断/重写 —— 必须零唤醒、`rescan … deliver=0`，
没被记进记忆的那一行只计数、不唤醒。夹具自己按规格解析日志/算身份，不复用实现里的函数。
