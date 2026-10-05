# P227 · P226 的换人独立验证（探针夹具自洽 / 不许吃环境）

```
task:   P227
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 验证 P226
deltas: -
grant:  docs/team/reports/P227-verify.md · docs/team/reports/P227-verify/**
deps:   被验实现**已并入 main**（`49e40f04`）；apply=dev；你没写过它 —— 合规。
        **先看 `/tmp` 余量**：低于容量地板（1024 MB）时容器里嵌套夹具的 dispatch 会被磁盘腿拒绝、级联出一堆假红（PM 自己踩过，见 `docs/team/reviews/P226.md`）。
status: todo
budget: 中
priority: 中高（这条修的是"夹具吃环境"这一族；判松了下次还会在别的形状里假红）
```

## 要验什么（自己造两棵环境树，别复用探针的 scratch）

1. **红→绿的决定性对照**：造一棵"完整内部树"（把两份豁免清单注册的 **17 个文件**从仓外归档 `pm-skills-ledger/team/reports/**` 逐条复原，sha256 需与清单相符），分别在**修复前**（`git show 728f1736:skills/teamsmith/tests/checkout-shape-probe.sh` 覆盖进副本）与**修复后**（被验 HEAD）跑探针：
   - 修复前：必须**红**（PM 量到 `ok 134 bad 4`，四条都是"内部树 + 清单文件都在"那组）；
   - 修复后：必须 **`ok 146 bad 0`**。
2. **证据层不在时也绿**：同一 HEAD、证据层不在的环境 → `ok 146 bad 0`。
3. **树自洽守卫承重**：把探针里"剔除证据层"那一步改成 no-op（或在构造后手动把注册文件塞回 scratch 树）→ 必须**红**并点名"scratch 树自洽：证据层为空"。**这条是本次修复的核心守卫，务必让它真的咬一次。**
4. **空面边界仍在**：把 `.pi/prompts`/`.pi/skills` 建成**空目录** → §19 判红（10 条），不是跳过；删掉空目录 → 回到 SKIP10。
5. **门禁**：`openspec validate --all --strict` + 容器内 §36（含探针，约 12 分钟；**报出耗时**）；报告点名"哪些自己跑、哪些引用"；证据包按 D94 留在工作树。
