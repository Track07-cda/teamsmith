# ledger-and-gate-noise · PM proposal review

time: 2026-09-22T09:3xZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  ledger-and-gate-noise（P43，propose=dev-bob）
tip:     b354232（task/P43-json-override-propose）· validate 19/19
user:    2026-09-22「可以」（批准 ①②④ 合并成一个小加固任务）
```

## Findings

1. **三条 delta 都落对了家**（design D0）：`verification` ADDED（容器自检指纹）、
   `board-and-status` MODIFIED（记录可见性）、`memory-and-deps` MODIFIED（空 override）+ ADDED（JSON 契约）✓
2. **MODIFIED 的 base scenario 一条没丢**（我逐条比对：`Unfinished work…` 1→4、`ledger read path…` 3→3、
   `seat's model…` 8→11，新增三条都是"空 token"形状）✓
3. **① 的红侧比我的 D34 记录更进一步**：它复刻了指纹函数并发现**两条**根因——
   除了"把瞬时客户端算进去"，`^tmux` 那一支**永不命中**（`ps -eo pid=,args=` 的 pid 右对齐），
   真正命中的是 `/tmux`（带路径：门禁 shim、`/usr/bin/tmux`）；**真 server 与 `tmux attach` 都不命中**。
   于是这份快照"既漏 server、又被客户端与'命令行里提到 tmux'的东西带着跑"。实测 `DIFFER` ✓
4. **D1 的替代机制有实测支撑**：`display-message -p '#{pid}'` 在无 server 的 socket 上 **rc=1 且不起 server**，
   活的私有 server 返回 `808231:/tmp/p43fix/sock2/…` —— 所以"按 socket 拿 server pid"可用 ✓
5. **② 的可见性缺口量化了**：worktree 里的**复验记录完全不可见**（`grep -c P43r` = 0），
   worktree 里的报告只在 [3] 以"草稿/先等交付"口径出现，**"这些字节没进任何提交、squash 会丢"从不提**，
   报告包内文件也不点名 ✓ —— 这正是 P36 那次险情的机制面。
6. **③ 的机理被我认可**：`team_config_seat_state` 对 `dev=` 回退空 model、`IFS=$'\t' read` 把**前导 tab 当
   分隔空白吃掉** → 字段错位 → `"override":}`；**同一形状还污染 `models.known`**（把来源标签写进模型词汇表）——
   这条是我在 D34/清单里没看出来的 ✓
7. **JSON 契约写成通用要求**（`memory-and-deps` ADDED）：所有机器出口对**门禁练过的每种契约形状**都必须是
   **恰好一份可解析 JSON**；空值序列化成 `""`、布尔是 `true|false`、**不许用 `null` 表示空**；
   门禁用 `python3 -m json.tool` 解析并在失败时**点名命令与位置** ✓
8. §5 的三条 open risk 我逐条裁定：① 我的 brief 表头 `deltas:` 写错（`watchdog`）——**PM 已改**
   （见下）；② M31 的 staged/modified 缺口**留作独立 change**（本次不夹带）；③ 指纹残留的 host session churn
   **若真出假红，裁定是"把会话行收窄到 name+creation"，而不是把进程扫描请回来** ✓

## 结论

**ACCEPTED**。apply **排在 P46 之前**（两者都写 `memory-and-deps` 的席位模型那条 requirement——
delta 单写者规则：串行落地）。
