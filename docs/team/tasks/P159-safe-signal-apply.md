# P159 · `safe-signal-discipline` apply：模式选进程一律 fail-closed，信号只按记录的 pid

```
task:   P159
agent:  dev-bob
issue:
change: safe-signal-discipline      # 提案已验收并合入 main
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/scripts/** · skills/teamsmith/tests/** · skills/teamsmith/references/** · openspec/changes/safe-signal-discipline/** · docs/team/reports/P159-<agent>.md · docs/team/reports/P159-<agent>/**
deps:   `openspec/changes/safe-signal-discipline/{design,tasks}.md`（覆盖映射照它做）· D37（dev3 按模式 SIGSTOP 冻结别人夹具 ✓）· D57/#1529（我按模式取 pid 杀了自己的 shell ✓）· D72（dev-bob 用 `pkill -f` 误杀同期的门禁客户端 ✓）· M36/M41/M67（破坏性 tmux 的既有闸门形态可参照 ✓）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）不许碰
status: wip
budget: 一个工作块
priority: 高（这一族已经发生三次，每次伤到的都是别人的进程）
```

> 本地模式：不 push main；推送带 `[skip ci]`。

## 交付 = `tasks.md` 全部做完，且**三条红侧**都要有原始输出

1. **模式选择一律拒** ✅：`pkill` / `killall` 的任何形态（含 `-f`、含不带 `-f` 的按名匹配 ✅）→ **exit 64** ✅ +
   可见理由（"模式不是身份" ✅）+ 指向正确做法（`team bg` 的 pid / 自己 spawn 时记下的 pid ✅）；
   **红侧**：造两个诱饵进程（名字/命令行里含被匹配的串 ✅）→ 拒绝后**两个都活着** ✅ + argv 记录桩**为空** ✅。
2. **信号只按 pid** ✅：允许 `kill <pid>` ✅（**必须**是数字或从记录文件读出的 pid ✅）；
   **红侧**：`kill $(pgrep -f x)` 与 `kill $(cat job.pid)` 在 shim 看来是同样的四个词 ✅ → 请说明你的判据如何区分（设计里已给结论 ✅，实现照它 ✅），
   并证明**前者被拒、后者放行** ✅（两条都要原始输出 ✅）。
3. **记录与保留** ✅：闸门每次调用写一行（闭合动作词表 ✅）；拒绝记录进长保留文件 ✅（同 P132 的形态 ✅），
   主日志轮转**不丢**它 ✅；写失败**可见但不改判定** ✅（仍 exit 64 ✅）。
4. **`team bg` 按 pid 收作业** ✅：`team bg stop <id>` 用记录里的 pid ✅，并**打印它信号了谁** ✅；
   **红侧**：把 pid 记录改成一个**假的** pid（指向诱饵 ✅）→ 必须**拒绝**或明确报"记录与进程不符" ✅（不许按名字猜 ✗）。
5. **lint** ✅：脚本/夹具里出现模式选择（`pkill`/`killall`/`kill -f`/`kill $(pgrep …)`）→ 门禁红并点名文件行 ✅；
   **反向**：`kill "$pid"` 形态**不许**被误报 ✅。
6. **门禁**：`openspec validate --all --strict` ✅ + 相关段 ✅ + FAST ✅ + **一次全量**（改了脚本层 ✅）；
   报告点名"哪些自己跑、哪些引用" ✅。
