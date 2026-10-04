# P154 · `safe-signal-discipline` propose→apply：把"只杀自己的 PID"变成机制

```
task:   P154
agent:  dev-bob
issue:
change: safe-signal-discipline
specs:  boundary#Destructive operations are gated
phase:  propose
anchor: change
deltas: boundary
grant:  openspec/changes/safe-signal-discipline/** · docs/team/reports/P154-<agent>.md · docs/team/reports/P154-<agent>/**
deps:   D72（今天的事故 ✅）+ D37 ✅ + 记忆 #1529 ✅ · 既有 shim 设计（M36/M41/M67：PATH 里包 `tmux`，记录 + 拒绝 + fail-closed）✅
status: todo
budget: 一个提案
priority: 高（一天内同一家族四次 ✅ 每次都能带走别人的活 ✅）
```

## 现场（近两天连续发生，**两次是 agent 触发**）

- **D37**（09-22，dev3）：按命令行模式 `SIGSTOP` 了**别人的**验证夹具 ✗；
- **今天**（dev-bob 自报 ✅ D72）：`pkill -f 'smoke.sh'` 误杀同期**三个**门禁客户端 ✗ → 留下 3 个孤儿容器 ✗；
- 更早我自己两次（按路径假设 `kill-server` ✅ / 按模式取 pid 杀到自己的 shell ✅）。

共同形状：**用"名字或命令行模式"当进程身份判据** ✗ —— 模式既会命中别人 ✅ 也会命中自己 ✅。

## 要 propose 的（可证伪，**复用既有 shim 的形态**，别另造一套）

1. **PATH shim 扩展**：现在包 `tmux` ✅ → 同样包 `pkill` / `killall` ✅：
   - **任何**被 shim 拦到的调用都要**记录**（谁、argv、cwd ✅）到与 `tmux-calls.log` 同族的审计文件 ✅（命名与保留策略沿用既有约定 ✅）；
   - **拒绝带模式匹配的形态**（`pkill -f …` ✅ `killall …` ✅）→ 非 0 退出 ✅ + 消息**指出安全路径**（"用 `team bg` 记录的 pid" ✅，
     或"给具体 pid" ✅）；**不带模式**的（`pkill -x <确切进程名>` ✗ 也危险 ✅ → 请给出你的判据与理由 ✅）请明确结论 ✅；
   - **fail-closed**：判不出来 → 拒绝 ✅（沿用 M67 的取向 ✅）；
   - shim 必须在**所有会跑门禁/夹具的路径**里生效 ✅（PM 与 agent 会话的 PATH ✅）——请说清它在哪些入口注入 ✅ 以及**不在哪**（诚实边界 ✅）。
2. **安全停作业的正式入口**：`team bg`（或既有的作业台账 ✅）提供"停止这个作业" ✅ —— 只杀**该作业记录过的 pid**（含其进程组/子进程树 ✅ 判据自定 ✅），
   并**打印它杀了什么** ✅；**跨作业/跨会话不许动** ✗。
3. **lint**：仓库脚本/夹具/模板里**禁止**出现 `pkill -f` / `killall` / 按模式的 `kill` ✅（与既有的"绝对路径 tmux"lint 同族 ✅）；
   **反向**要有牙：在 scratch 副本里放一条 `pkill -f x` → lint 必须红并点名文件行 ✅。
4. **夹具（三条，都要红侧）**：
   a. 被 shim 拦到的 `pkill -f x` → 非 0 + 消息 ✅（且**真的没杀** ✅：一个"诱饵"进程仍活着 ✅）；
   b. 用正式入口停自己的作业 → 目标死 ✅ 且**邻居（另一个 pid）活着** ✅；
   c. 无 shim 的裸环境（诚实边界 ✅）：lint 仍然拦住脚本里的模式用法 ✅。
5. **规格**：把"进程身份判据 = 自己 spawn 的 PID；模式匹配不是身份"写成 requirement + scenario ✅（`boundary` 已有"破坏性操作有门" ✅ ——
   **MODIFIED 不许丢基线场景** ✅）。

## 交付

提案（本任务）+ 后续 apply 换人 ✅；`openspec validate --all --strict` ✅；每条 requirement 至少一个**可复现**的 scenario ✅。
