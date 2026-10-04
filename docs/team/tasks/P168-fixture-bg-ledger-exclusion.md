# P168 · 夹具的"真实仓库 state/ 未被触碰"漏掉了后台作业账本（`state/bg.log`）→ 假红

```
task:   P168
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改夹具的排除面与其红侧
deltas: -
grant:  skills/teamsmith/tests/** · docs/team/reports/P168-<agent>.md · docs/team/reports/P168-<agent>/**
deps:   P159 的夹具 `tests/signal-gate.sh`（`state_snapshot` + "真实仓库 state/ 前后一致（排除 bg/ 并发车道）" ✓）· P73/P87 的先例（同一个洞的**目录**版：`bg/` 已排除 ✓、`bg.log` **没**排除 ✗）· 现场：**PM 今天实测** ✓ —— 合并树里跑 `58` 段红 ✓（`✗ 真实仓库 state/ 前后一致…` 带 `bg.log` 的差异行 ✓），而**同一条件在干净 main 克隆里绿** ✓（克隆里没有 `bg.log` ✓）→ 是**夹具的排除面**不够 ✓，不是产品 ✓
status: wip
budget: 小
priority: 中高（**任何 PM 用 `team_bg_run` 跑门禁都会踩** ✓ —— 也就是我们自己的标准工作流 ✓）
```

## 要做的

1. **把后台作业车道整条排除** ✅：`state/bg/` ✓（已有 ✓）+ **`state/bg.log`** ✓（缺 ✗）+ 该车道其它自述文件（若有 ✓ —— 请**核实** `team_bg_run` 到底写哪些路径 ✓，按**实际**写，不要凭猜 ✗）。
   判据要**按路径**（不是按名字 ✗ —— P87 的教训 ✓）。
2. **红侧（可证伪，两条）**：
   ① 在夹具跑动中**写一次 `state/bg.log`** ✓ → 断言**必须仍然绿** ✓（这就是今天的现场 ✓）；
   ② 在夹具跑动中写**车道之外**的文件（例如 `state/other.log` ✓）→ 断言**必须红** ✓（证明排除不是"什么都放过"✗）。
3. **不许扩大成"整个 state/ 都不看"** ✗ —— 排除面要能逐条列出来 ✓（并在注释里写清"为什么这个文件属于并发车道"✓）。
4. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 58` ✓ + FAST ✓；报告点名"哪些自己跑、哪些引用" ✓。
