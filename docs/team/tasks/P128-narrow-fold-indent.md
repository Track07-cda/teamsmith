# P128 · 窄档折叠行与它替代的卡片行**左对齐**（用户反馈）

```
task:   P128
agent:  dev2                     # 与 P125 不同人（同一片显示代码的独立实现者）
issue:
change: panel-board-cards        # delta 已由 PM 更新（+1 场景；`openspec validate` 14/0 ✓）
specs:  panel#A lane folds from its header, and empty lanes fold by default
phase:  apply
anchor: change
deltas: panel
grant:  skills/teamsmith/scripts/panel/** · skills/teamsmith/tests/panel-*.sh · skills/teamsmith/tests/snapshots/*-p4.txt（只重钉 page 4）· skills/teamsmith/tests/smoke.sh（append-only 一段）· docs/team/reports/P128-dev2.md · docs/team/reports/P128-dev2/**
deps:   P125（窄档原地一行 ✓ 已合并）· 用户 2026-09-29 反馈（窄档折叠后左侧指示没对齐 ✓ + 截图）
status: todo
budget: 小
priority: 中高（用户点名；纯显示层）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。

## 现场（PM 在 **60 列**下逐列量出来的）

```
  ▾ 待办 1                       ← 车道头：字形在第 1 列
  › · P103 CI 镜像 ETXTBSY（infra apply）   ← 卡片：字形在第 3 列（前有光标/缩进）
  ▾ 进行 3
    ▸ P124 看板显示层 独立验证     ← 卡片：字形在第 3 列
▸ 待复验 0（已折叠）             ← ✗✗ 折叠行：字形在第 1 列（跟车道头同列，但形状 ▸ 跟卡片字形同族）
```
→ 折叠行**比它替代的那些卡片行左出 2 列** ✗，眼睛把它和卡片归为一组（`▸` 与卡片的 `▸` 同形 ✗），所以看起来"没对齐" ✗。

## 要做

1. **窄档（成组）的折叠行按规格移到卡片列** ✓：**与它替代的卡片行同一缩进** ✓（含**光标列** ✓ ——
   聚焦折叠行时光标照旧占据那一列 ✓），折叠标记落在**卡片状态字形所在的那一列** ✓；
   车道头**不动**（仍在自己的标记列 ✓）。
2. **宽档三列小框不动** ✓（用户没意见，且它是列对齐的 ✓）。
3. **证据**：**你**在 **99 / 60** 两档各出一份**逐列对照表**（车道头 / 卡片行 / 折叠行的字形所在列 ✓ 原始帧 ✓）；
   **红侧**：把折叠行改回车道头那一列 → 新场景断言必须**红** ✓（另外把既有窄档场景复跑一遍 ✓）。
4. 重钉受影响快照（**只 page 4** ✓）+ `openspec validate --all --strict` ✓ + **FAST 全绿** ✓。
