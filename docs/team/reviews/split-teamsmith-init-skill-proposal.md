# 提案评审 · split-teamsmith-init-skill

```
change:  split-teamsmith-init-skill
propose: P15（dev，分支 task/P15-propose-split-teamsmith-init，tip 见分支）
reviewer: PM
date:    2026-09-17
verdict: **ACCEPTED**
```

## 评审依据

- 方向与授权：E7 探索（D27 验收）→ 用户拍板「直接拆」+「CLI 保持统一不分叉」。提案的轻拆形态与授权一致。
- 完整性：proposal/design/tasks/specs 四件套齐；`openspec validate --all --strict` 实测 14/14 绿（含本 change）。
- spec 质量：5 条 requirement（init skill 存在且三拍 / 日常 skill 不再携带初始化指引 / 双 description 路由干净 / 单一 CLI 与工具副本 / 单一版本来源与指纹范围不变 / 存量项目零改动），全部带可证伪 scenario，与 tasks.md 逐步对应。
- 翻转证据设计：tasks 3.1/3.2/3.4/3.5/3.6 每条约含「改坏 → 断言红 → 还原」，含指纹范围的双方向翻转。
- 边界：零代码、CLI 不分叉、指纹不扩、worker/opsx 不拆——与 E7 实测结论一致。
- 成本已明示：smoke ~130 处引用重排（D6 逐类清单），迁移期存量项目零改动（R6 有断言钉）。

## 裁决点

- **D2（workflows.md §A 缩成指路）：批准保留。** 同一套初始化步骤留两处必然漂移；附录 A 的问答清单已收编其内容。
- 版本号 bump 幅度留给 apply 任务书（design Open Questions 已声明，合理）。

## 生效

ACCEPTED 起，apply 相可以派单（P16，另立任务书；apply 归 dev3，与 propose 的 dev 保持探索/实现分离）。
