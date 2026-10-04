# gate-isolation-scan-scope · PM proposal review

time: 2026-09-22T18:2xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  gate-isolation-scan-scope（P73，propose=dev）
tip:     97e7fa72（task/P73-apply）· validate 27/27
firsthand: D45 的三次现场（dev3 的 P67 夹具把 p67faketui* 写进真 state/tmux-calls.log）
```

## Findings

1. **D1 的取舍对，而且它替我把理由说清了**：审计日志是**调用记录**（内容是调用者自己的 argv，
   由门禁代写），扫描的目的是证明"夹具没往**账本状态**里写"——把审计日志算成污染是**把证据倒置**。
   它还否掉了三个更差的替代（按行格式过滤 / 给 session 名做散列——**会毁掉 M62 那次泄漏链的取证价值** /
   手工删行——**"需要人手改生产日志的门禁不是门禁"**）✓
2. **它纠正了我的前提**：log **本来就有界**（2000 → 保留最新 1000 行），我简报里写的"append-only 无上限"是错的
   —— 它按"保持现状"处理并写明（1000 行 ≈ 0.3 MB，实测 331 B/行）✓ 并**否掉**了分片（会毁掉全序、
   正是默认 server 死亡后排查看"谁在前"所需）与按时间轮转（要靠 pulse 调度、恰好没 agent 时留空档）✓
3. **D3 是这条提案里最漂亮的一笔**：截断必须**自述**——首行一条**累计 `dropped=N`** 标记，
   且**不是调用行**（不带 `act=`，因此**闭集词表与所有解析器都不受影响**）✓ ——正好补上"读不到 ≠ 没发生"这个真实的取证风险
4. **D4 的精确路径排除 + 反向控制**：只排除两个**确切路径**；`state/tmux-calls.log.1` 与 `state/nested/tmux-calls.log`
   **仍算泄漏**（按 basename 排除会把后者静默，被它明确否掉）；`state/bg/**` 维持 M30 的口径 ✓
5. **可证伪 R1–R4** 具体到命令（含"把排除放宽成 basename glob → `.log.1`/嵌套腿变红"的反向腿）✓
6. **delta 检查**：`verification` ADDED 1（4 scenarios）+ `boundary` MODIFIED 1（base 3 → 4，**一条没丢**）✓

## 结论

**ACCEPTED**。apply 排队（当前 5/5 满），apply 时必须：① 只用**确切路径**排除；② 标记不带 `act=`；
③ 反向控制（`12b-j` + M16）照旧能红；④ 红/绿两侧原始输出。
