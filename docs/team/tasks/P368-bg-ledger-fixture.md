# P368 · `bg-ledger.sh` 的两条断言假设了 A1 之前的计数

task: P368
agent: dev3
phase: apply
category: code
change: turn-notice-in-pm-inbox
specs: notify-and-inbox#A turn-end notification appends one inbox line and knocks once
anchor: none (infra) — 夹具判据
deltas: -
branch: task/P368-bg-ledger-fixture

## 事实（P365 交付时发现，PM 已核）

`tests/bg-ledger.sh --select merge,detail` 在 **main**（A1 合并后）就红两条，候选分支上同样这两条：

```
✗ merge: line-counting readers count a merged line once :: before=0 after=0
✗ detail: detail reading does not acknowledge :: before=0 after=0
```

根因：A1 的「记录行不算该席位的未读流量」是**设计**（`notify-and-inbox` 的新场景「One settle adds one to the
pending count, never two」），而这两条断言还在假设「一条 `[auto] agent:<本文件席位>` 的行会让未读 +1」。
`§13c` 的 bg-ledger 子集是 `wording,ledger,suspend-shape,owner-scope`，**不含** `merge` 与 `detail`，
所以门禁与 V96 都没跑到——这是承接缺口，不是回归。

## 要做的

1. 两条断言的判据改成**新契约**：流量用**指针行**（`pm.md`）或 `[manual]` 行来量，不要用记录行；
   合并语义（`×N first= last=`）仍要验——那是这两条本来要守的东西。
2. **红侧各一条**：把合并逻辑改坏（例如让第二个事件另起一行）→ `merge` 那条必须红；
   把 `--ack` 的读偏移写错 → `detail` 那条必须红。还原必须绿。
3. **顺手补承接**：把 `merge` 与 `detail` 加进 `§13c` 的 bg-ledger 子集（或你判定更合适的位置），并说明为什么
   它们之前不在里面；这条要有红侧（把子集去掉 → 该段不再跑它们，用可见的方式说明，不许静默）。
4. 交读数：`bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail`（全绿）、`--select all` 或全套
   （作者 20 条里那 2 条转绿、其余不变）、`--select 13` 与 `--select 13c`。

## 边界

写集：`skills/teamsmith/tests/bg-ledger.sh`、`skills/teamsmith/tests/smoke.sh`（只在 §13c 子集那一处）、报告。
不改产品实现、不改 A1 的计数判据、不新增段。
