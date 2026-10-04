# P175 · `safe-signal-discipline` **换人复验**（P166 的 FAIL → P169 返工后）

```
task:   P175
agent:  dev3
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P175-<agent>.md · docs/team/reports/P175-<agent>/**
deps:   第一轮 `docs/team/reports/P166-verify.md`（F1 CRITICAL / F2 / F3 ✓）· PM 评审 `docs/team/reviews/P166.md` ✓ · 返工 `feat/fix … P169`（在 main ✓，我的复验证据在上面那条提交信息里 ✓）· **换人**：D31 ✓
status: wip
budget: 一次对抗性验证
priority: 高（它是 `safe-signal-discipline` 归档的**唯一**前置 ✓，而它又挡着 `signal-gate-pgrep` 的 apply ✓）
```

## 铁律

**一切 `pkill`/`killall`/`pgrep` 相关实验都在容器里** ✓（宿主只读代码 ✓、跑纯逻辑 lint ✓）。

## 要独立证明或证伪的（**重点：上一轮的三条缺陷真修好了吗**）

1. **F1 边界** ✅（**不许照抄我的形状** ✓，自己造）：
   ① 路径穿越 id（含 `../` ✓ 绝对路径 ✓ 空 ✓ 带 `/` 的名字 ✓）→ **必须拒** ✓ 且**本项目的诱饵进程仍然活着** ✓；
   ② 本项目 `bg/` 里指向**别处**的软链 ✓、指向**本项目内别处**的软链 ✓ → **都拒** ✓；
   ③ **反向**：本项目自己的正规记录 → **照常收作业** ✓（不许误伤 ✓）；
   ④ **再深一层**：记录是正规文件但**内容**指向别的进程（pid 存在 ✓ 但 pgid/启动指纹不符 ✓）→ **必须拒** ✓（不许按 pid 硬杀 ✗）。
2. **F2 一致 fail-closed** ✅：`pgid=0`/负 ✓、`pid=0` ✓、非数字 ✓、字段缺失 ✓、FIFO/设备/目录 ✓ → **全部 rc=4 + 明确诊断 + 有界**（不许 124 超时 ✓）；
   红侧：把"正规文件"判定 shadow 成恒真 → FIFO 用例必须**红**（或阻塞 → 即失败 ✓）。
3. **F3 清单** ✅：`tasks.md` 的勾选与**实际交付**一致 ✓（抽查 3 条：勾了的是否真做了 ✓、没勾的是否真没做 ✓）。
4. **不许放松** ✅：模式选择（`pkill`/`killall`）仍 exit 64 ✓、诱饵仍活着 ✓、lint 双向 ✓（自己造脚本 ✓）。
5. **残余边界如实量化** ✅：`pgrep`/`pidof` 未纳入闸门 ✓（P164/P167 在处理 ✓）；**绝对路径**不在射程（设计 D3 ✓）——
   在容器里复现一次"交互式 `kill $(pgrep -f …)` 命中自己命令行"✓（PM 已复现 exit 143 ✓）并写进"未覆盖"一节 ✓。
6. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 58` ✓ + 容器内 FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓。
