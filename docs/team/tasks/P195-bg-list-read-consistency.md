# P195 · `safe-signal-discipline` 返工：`bg list` 与 `bg stop` 必须**同一条规则**（读面不许说"身份成立"）

```
task:   P195
agent:  dev-bob
issue:
change: safe-signal-discipline
specs:  boundary#Signals go to a recorded pid, never to a name or a pattern
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/scripts/lib/cmd-bg.sh · skills/teamsmith/tests/** · openspec/changes/safe-signal-discipline/** · docs/team/reports/P195-<agent>.md · docs/team/reports/P195-<agent>/**
deps:   第三轮复验 `docs/team/reports/P189-verify.md`（F1 ✓）· PM 评审 `docs/team/reviews/P189.md`（**我复现** ✓）· P169/P187 的既有规矩（stop 与 list 一条规则 ✓）
status: wip
budget: 小到中
priority: 高（读面说谎会让操作者按错信息决策 ✓；且它挡着两条归档 ✓）
```

## 现场（我复现）

```
team bg list      → zero  pid=193515  pgid=0  identity=holds   cmd=sleep 300     ← ✗
team bg stop zero → ✗ … 的 pgid 是 0（Linux 的进程组 id 必为正）—— 记录…            ← ✓
```

## 要做的

1. **同一套校验** ✅：把 `bg stop` 用的记录校验（平坦 id ✓、正规文件 ✓、目录在项目内 ✓、pid/pgid 为正整数 ✓、启动指纹一致 ✓、实时组一致 ✓）
   抽成**一个函数** ✓，`bg list` **与** `bg stop` 都调它 ✓（**不许**两份判断 ✗）。
2. **读面如实** ✅：不可用时**标出原因** ✓（例如 `identity=unusable: pgid 0` ✓）—— 不许写 `holds` ✗；原因措辞与写面**一致** ✓。
3. **红侧（三条，逐字用验证者的形状）** ✅：非平坦 id ✓、`pgid=0` ✓、实时组不符 ✓ → `list` 必须**不再**显示"成立" ✓ 且**与 `stop` 的结论一致** ✓；
   **影子**：把 `list` 的校验改回"只看 pid 活着" → 三条必须红 ✓。
4. **反向**：正常记录 ✓ → `list` 显示成立 ✓ 且 `stop` 能收 ✓（不许误伤 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 58` ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 P189" ✓；**复验换人** ✓。
