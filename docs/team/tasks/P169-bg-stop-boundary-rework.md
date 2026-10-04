# P169 · `safe-signal-discipline` 返工：`bg stop` 的 state 边界 + 一致 fail-closed + 清单勾选

```
task:   P169
agent:  dev2
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/scripts/lib/cmd-bg.sh · skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · openspec/changes/safe-signal-discipline/** · docs/team/reports/P169-<agent>.md · docs/team/reports/P169-<agent>/**
deps:   独立验证 `docs/team/reports/P166-verify.md` ✓ · PM 评审 `docs/team/reviews/P166.md`（含**我自己的复现** ✓）· 实现 `aa787487` ✓ · **F1 是 CRITICAL**：可信号本项目之外的进程 ✗（同族 D37/D57/D72 ✓）
status: wip
budget: 一个工作块
priority: **最高**（安全边界；且它挡住 `safe-signal-discipline` 归档 → 也挡住 `signal-gate-pgrep` ✓）
```

## F1（CRITICAL）· job id 与记录都必须**留在本项目内** ✅

**现场（我的复现，容器内 scratch 项目）**：本项目 `bg/` 下放一个**软链**指向邻居项目的记录 ✓ →
`team bg stop linked` → 打印 `cmd: sleep 600` ✓ → **邻居进程被停** ✗。
要求：
1. **job id 只允许"平坦名字"** ✅（无 `/` ✓、不是 `.`/`..` ✓、非空 ✓、长度有上限 ✓ —— 给上限与理由 ✓）；
2. 记录文件必须是**本项目 bg 目录内的正规文件** ✅：`realpath` 后其父目录 == 本项目的 bg 目录 ✓（拒绝软链 ✓、拒绝穿越 ✓）；
3. **发信号前再核一次身份** ✅（pid 的启动指纹 + pgid 必须与记录一致 ✓ —— 已有 ✓ 保留 ✓）；
4. **红侧（两条，逐字用我的形状）**：
   ① 邻居记录 + `bg stop ../../../../b/.pi/team/state/bg/outside` → **必须拒** ✓ 且**邻居进程仍然活着** ✓；
   ② 本项目 `bg/` 里的**软链**指向邻居记录 + `bg stop linked` → **必须拒** ✓ 且邻居仍活着 ✓；
   ③ 反向：本项目**自己的正规记录** → 照常收作业 ✓（不许误伤 ✓）。

## F2 · 畸形记录一致 fail-closed ✅

- `pid`/`pgid` 必须是**正整数** ✓（`0`/负/非数字 → 拒绝 ✓，**PM 已裁**：Linux process-group id 必为正 ✓）；
- 记录必须是**正规文件** ✓（FIFO/设备/目录 → 拒绝 ✓ 且**不阻塞** ✗ —— 用 `-f` + 非 FIFO 判定 ✓ 再读 ✓）；
- 红侧：`pgid=0` ✓、FIFO ✓ 两种都要**拒绝 + 明确诊断 + 有界**（不许 124 超时 ✓）。

## F3 · 清单按事实勾选 ✅

`openspec/changes/safe-signal-discipline/tasks.md` 的 24 项 ✓ 按**实际交付**勾选 ✓（含你**没有**独立核验的项要写明 ✓，例如 lexer 逐字节等价、真实窗口、完整门禁 ✓）——不许为了好看全勾 ✗。

## 不要做

**绝对路径**（`/usr/bin/pkill`）**不在**本 change 的射程 ✓（设计 D3 ✓，我的任务书写错了 ✓ 已改 ✓）——不要试图拦它 ✗。

## 门禁

`openspec validate --all --strict` ✓ + **容器内** `--select 58` ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 P166" ✓；**复验换人** ✓。
