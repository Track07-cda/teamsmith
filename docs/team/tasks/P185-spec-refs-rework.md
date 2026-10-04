# P185 · `spec-rationale-self-contained` 返工：具体引用按**确切相等**判 + 畸形声明行不许静默丢弃

```
task:   P185
agent:  dev
issue:
change: spec-rationale-self-contained
specs:  boundary#Specs are the contract, and a published spec stands on its own
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/tests/** · openspec/changes/spec-rationale-self-contained/** · docs/team/reports/P185-<agent>.md · docs/team/reports/P185-<agent>/**
deps:   独立验证 `docs/team/reports/P184-verify.md` ✓ · PM 评审 `docs/team/reviews/P184.md`（含**我亲手复现** ✓）· 实现 `b665b331` ✓ · **F3 不是你的活** ✓（我的任务书错，已改 ✓）
status: wip
budget: 小到中
priority: 高（它决定**公开契约**能不能自洽 ✓；两条都是"假绿"形状 ✓）
```

## F1 · 具体引用必须匹配**确切**行，通配/占位行只许出现在 `slot`

**现场（我复现）**：植入未声明具体引用 `docs/team/reports/P184-dev.md` ✓ + 声明表副本加通配行 `docs/team/reports/P184*.md` ✓ →
走查 **rc=0** ✗（`undeclared 0` ✗）—— 具体引用被通配行吞了 ✗。
要求：
1. `kind` 为 `ledger`/`example` 的行：模式里的 `*`/`<…>` **一律拒绝加载** ✓（那种形状只属于 `slot` ✓），并**点名表名/行号/模式** ✓；
2. 具体引用的判定改为**字符串确切相等** ✓（不是正则匹配 ✓）；
3. **红侧**：① 上面那条通配行 → 走查**必须拒绝加载**（rc≠0、点名 ✓）；② 未声明的具体引用 → **红** ✓（既有 ✓，复跑 ✓）；
   ③ **反向**：合法的 `slot` 行（含 `<…>` ✓）照旧工作 ✓、`docs/team/reports/` 根与固定文件（`ledger` ✓）照旧 ✓（不许误伤 ✓）。

## F2 · 畸形声明行不许静默丢弃

**现场**：表里加一行缺列的数据行 → 走查 rc=0 ✗（被无视 ✓）。
要求：**每条非注释数据行**都必须有全部必需列（`pattern`/`kind`/`basis` ✓，`basis` 非空 ✓，`kind` 属闭集 ✓）→ 缺了**拒绝加载并点名**表名 + **行号** + 该行内容 ✓；
**红侧**：缺列 ✓、`basis` 空 ✓、`kind` 非法 ✓ 三种各一条 ✓（都要点名 ✓）。

## 不要做

**F3**（待归档 delta 的判定口径 ✓）与 **F4**（六族之外的 id 族 ✓）**都不是你的活** ✓ —— 前者是我任务书写错 ✓（已改 ✓），后者已记为边界 ✓。

## 门禁

`openspec validate --all --strict` ✓ + 相关段（`18c` ✓）✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 P184" ✓；**复验换人** ✓。
