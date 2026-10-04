# P167 · `signal-gate-pgrep` apply：窄规则（组/父标量 + 整命令计数放行，按名/按模式一律拒）

```
task:   P167
agent:  dev-bob
issue:
change: signal-gate-pgrep
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/scripts/shim/** · skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · openspec/changes/signal-gate-pgrep/** · docs/team/reports/P167-<agent>.md · docs/team/reports/P167-<agent>/**
deps:   **顺序依赖（我在 scratch 实测过）**：本 change 的 `MODIFIED` 指向的 requirement 现在只在 `safe-signal-discipline` 的未归档 delta 里 ✗ →
        **必须先归档 `safe-signal-discipline`** ✓（它的前置是 **P166** 独立验证 ✓），然后本 change 的 delta **在归档后的基线上重写** ✓（scratch 预演 ✓）；
        顺序反了会被工具当场拒绝（`boundary MODIFIED failed … not found` ✓ 且不改文件 ✓）
status: wip
budget: 一个工作块
priority: 中高（同族事故 3 次、其中 2 次走 pgrep；**但禁止过度设计** ✓ —— 只按提案的语法表实现 ✓）
```

## 交付 = `tasks.md` 全部做完，**逐形态**都要有红侧

1. **闸门扩到 `pgrep`/`pidof`** ✅（同一 `signal-gate` ✓，新增两个入口 symlink ✓；工具名分派与**整 argv** 分类照提案的语法表 ✓）：
   - **放行**：正标量 ID（`-g N` ✓ `-P N` ✓，`N` 必须是正整数 ✓，不许 0/负/非数字 ✗）、
     **整命令计数**（`-fc <命令>` ✓ 等三个形态 ✓）、单个只读信息 token（`--help`/`-V` … ✓）；
   - **一律拒（exit 64 + 空 stdout + 点明工具与完整 argv ✓）**：任何按**名字**或按**模式**的选择 ✓
     （含 `-x` ✓ `-u` ✓ 裸名 ✓ 绝对路径 ✓ `command pgrep` ✓ `env pgrep` ✓）、`pidof` 的**一切选择形态** ✓、任何**列表/输出**形态 ✓。
2. **真身路由** ✅：放行的形态必须仍能拿到**真身的结果** ✓（`TEAM_SIGNAL_REAL` 机制扩展 ✓）；
   夹具要用**同名的记录桩**放在闸门之后 ✓（证明"放行 = 真被调用"✓、"拒绝 = 真身未被调用"✓）。
3. **红侧（每条都要原始输出）**：
   ① 把闸门 shadow 成恒放行 → 上面每一条"必须拒"的形态都要红 ✓；
   ② 把 `-g`/`-P` 的**正整数**校验去掉（允许 `0`/负/非数字）→ 对应用例必须红 ✓；
   ③ 把"整命令计数"放行放宽成"任何 `-c`" → 计数以外的形态必须红 ✓。
4. **不许误伤** ✅：仓库里四处合法调用（`common.sh:1507` ✓ `panel-cpu.sh:285/340` ✓ `smoke.sh:8095` ✓）**必须继续工作** ✓
   —— 在**容器里**跑 `--select 26,58` ✓ 与 FAST ✓ 证明之 ✓。
5. **文档** ✅：`references/` 里那节"信号纪律"补上 `pgrep`/`pidof` 的语法表与**已知边界** ✓（交互式绕过仍存在 ✓ 如实写 ✓）。
6. **门禁**：`openspec validate --all --strict` ✓ + **容器内** `--select 26,58` ✓ + 容器内 FAST ✓ + **一次全量**（改了脚本层 ✓）；
   报告点名"哪些自己跑、哪些引用" ✓。
