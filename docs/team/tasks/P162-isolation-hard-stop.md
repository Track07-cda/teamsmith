# P162 · 破坏性段开跑前必须**证明**隔离生效，否则硬停（不许"先跑再看"）

```
task:   P162
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 门禁自身的隔离前置；只改门禁与夹具
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/scripts/lib/** · skills/teamsmith/references/** · docs/team/reports/P162-<agent>.md · docs/team/reports/P162-<agent>/**
deps:   D83（四次死亡与门禁运行重合、我方审计零 kill 类；两个"假隔离"机制：#1250 的 TMUX_TMPDIR 不存在目录回退、P115/P120 的 AF_UNIX 107 字节超限）· D57（不干涉外部环境 ✓ —— 本任务是**让门禁打不到**共享 server ✓）· P159（信号纪律：模式选择一律拒 ✓）· 现场：`smoke.sh:837` 的「tmux 隔离：私有 socket 没生效」目前是**断言**而不是**前置**
status: wip
budget: 一个工作块
priority: 最高（共享 server 被反复杀掉，全队与其它会话一起遭殃）
```

## 要做的（**可证伪**，每条都要红侧）

1. **前置证明** ✅：任何会 kill server / kill session / kill window 的段或夹具，**在动手之前**必须逐条证明：
   ① 目标 socket 路径**确实存在且属于本轮**（`TMUX_TMPDIR` 目录已 `mkdir -p` ✓，socket 文件在 ✓）；
   ② 实际使用的 server 就是它（`tmux display-message -p '#{socket_path}'` 或 `ls -l` 该 socket ✓）；
   ③ 与**默认 socket**（`/tmp/tmux-$(id -u)/default` ✓）**不同** ✓（逐字节比较路径 ✓）。
   三条有一条不成立 → **硬停**：打印一行醒目结论 + 该段记为 `SKIP（前置不成立：<哪一条>）` ✓，**绝不继续** ✗。
2. **不许有例外路径** ✅：`TEAM_*` 环境变量、`--force`、CI 模式都**不得**绕过这个前置 ✗（若确有需要，写明理由并让 PM 裁 ✓）。
3. **红侧（可证伪）**：
   ① 把 `TMUX_TMPDIR` 指到一个**不存在**的目录 → 段必须**硬停并点名** ✓（复刻 #1250 的回退形状 ✓）；
   ② 把 TMPDIR 设成**超深**（socket 路径 > 107 字节 ✓）→ 段必须硬停并点名"路径超 AF_UNIX 上限" ✓（复刻 P115/P120 ✓）；
   ③ 反向：隔离**正常**时 → 段照常跑 ✓、结论与今天逐字节相同 ✓；
   ④ 影子：把前置判据改成恒真 → ①②两条红侧必须**红** ✓（证明判据不是橡皮章 ✓）。
4. **审计** ✅：每次硬停写一行到门禁日志（段号 + 哪一条不成立 + 实际 socket 路径 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + FAST ✓ + **一次全量**（改了门禁本体 ✓）；
   报告点名"哪些自己跑、哪些引用" ✓。
