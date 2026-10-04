# P85 · fixture-waits-for-landed-reads 独立验证（verify 阶段）

```
task:   P85
agent:  verify
issue:
change: fixture-waits-for-landed-reads
specs:  verification#A fixture observes a data-derived state before it asserts it / verification#A measuring fixture measures a fixed tree, not the caller's worktree
phase:  verify
anchor: change
deltas: verification
grant:  docs/team/reports/P85-verify.md · docs/team/reports/P85-verify/**（只写报告与证据，不改实现）
deps:   P62（propose，dev-bob）· **P68（apply，dev-bob）**——两个作者都不是你
status: todo
budget: 一个工作块
```

> 本地模式：不 push。

## 要对抗性验证的（给可复现命令 + 原始输出）

1. **等数据态**：① `panel-p21.sh` 的"手改 → 重开视图 → Enter"那条路**必须等到那一行本身**（不是骨架）；
   用**你自己的**延迟注入（scratch wrapper 给面板的 settings 读加 `sleep`）验证：
   `0s 绿 · 6s 仍绿（新）` 对比 `6s 红（旧夹具，用 git base 的副本）`；② **永不落定** → 有界耗尽 +
   **点名等的是哪个数据态**（不是"等超时了"），且**不报绿**。
2. **不许变成性能阈值**：门禁里没有把等待上限当**判定**的红线；上限数值**不是**墙钟阈值（自己核对：把上限调小 → 只影响等待长度，不改变任何"慢但正确"的判定）。
3. **量测固定目标**：`panel-cpu.sh` 从**两个不同工作树**跑 → **同一个被量根、同一结论**；输出**两个根都印**（量的项目 / 被测 bundle）。
4. **`panel-b3` 的固定 sleep 也纳入**：`collapse` 段改为观察控制台（自己造"控制台慢到 8s"的注入 → 新夹具仍绿、旧夹具红）。
5. **零回归**：`openspec validate` + FAST + 全量 smoke（**当前 main 应零红**）。

## 至少三条变异（红→绿原始输出，只在 scratch 副本上）

- 把等待改回骨架标记 → 对应断言红；
- 把"数据态"等待改成固定 `sleep` → 延迟注入下红；
- 让 `panel-cpu` 量调用者工作树 → 两工作树结论不一致的断言红；
- 还原后实现树干净。
