# meeting-liveness · 提案评审（P134，含 R1/R2 返工）— PM 判定

time: 2026-09-30T06:0xZ · reviewer: pm · verdict: **ACCEPTED**

```
change: meeting-liveness（propose=dev3 · tip 9c98fad1 · 8 commits）
首轮 NEEDS-CHANGES：R1 参与方身份判定口径 · R2 陈旧 knock 可判定（见 git 历史）
```

## 我亲手核的

| 项 | 结果 |
|---|---|
| `openspec validate --all --strict` | **14/0** |
| **MODIFIED 不丢基线场景**（机械比对，逐 requirement） | delivery-guard 13→14 · 2→3 · meeting 1→6 · notify-and-inbox 4→6 · 1→3 · panel 2→3 · watchdog 3→6 —— **丢失 0**，新增 **16** |
| A 发现性 | 未读并进 `team_pending_counts` 单一来源 + 新增末字段 + **所有 tuple 读者同 commit 更新** + 无事则静默的基线场景保留 |
| B 收尾 | `expired` 为派生态（`STATUS` 仍 `open|closed`）+ `close --stale` 只碰过期项 + 过期可关（解开死锁） |
| 投递安全（D64 发现 2） | 敲门走 `team_send_guarded`，忙则**排队**并报 `queued` 而非 `knocked`，红侧场景齐 |
| 每方窗口（D64 发现 1） | `PM_WINDOWS=<proj>=<win>;…` + 兼容旧 `PM_WINDOW` + 重登记我方行不影响对方行 |
| **R1** | 新增 requirement「A participant is recognized by its recorded names, not by one spelling」：记三种名字（声明名 / 仓库 basename / session），**任一匹配即算参与方**；<peer>/<peer-b> 的真实形状写成场景；**第三方仍被拒**的场景也在 |
| **R2** | 会议侧：knock 载荷带 `#<turn>` + `knocks.log` 同步，**只用 transcript + read/<proj>.seq 即可判 stale**；任务侧：turn-end 通知的 inbox 行与 knock 载荷都带 `task=<ID> tip=<7-hex>`，且**不打开发送方工作树**即可判定（board done/closed 或 (task,tip) 与 reviews/<ID>.md 记录的 HEAD 相同 ⇒ stale） |
| 非目标 | 未扩到 N 方会议；不写对方仓库；无 order/command intent |

## 结论

**ACCEPTED** → 提案合入 main。apply = **P139**（授权路径与覆盖映射由 change 的 `tasks.md` 给出）；
独立验证须**换人**（D31）。
