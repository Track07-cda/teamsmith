# P145 · 公开可读性：spec 的理据要自洽（不再引用内部账本路径）

```
task:   P145
agent:  dev2
issue:
change: spec-rationale-self-contained
specs:  boundary#Specs are the contract
phase:  propose
anchor: change
deltas: boundary
grant:  openspec/changes/spec-rationale-self-contained/** · docs/team/reports/P145-<agent>.md · docs/team/reports/P145-<agent>/**
deps:   2026-10-01 开源发布准备（`docs/team/RELEASE-PUBLIC.md`）· 发布树导出扫描（泄漏 0 ✅，但**内部代号与内部报告路径仍在**）
status: wip
budget: 一个提案（先量后议，不要直接改 spec）
priority: 中（不阻塞发布 ✅ 但影响公开可读性 ✅）
```

## 现场（我量过）

公开树（222 个文件）里：内部任务代号 `P\d+` **2693 次 / 141 文件**、`M\d+(\.\d+)?` **2603 次 / 101 文件**、
`D\d+` **381 次 / 57 文件**、`V\d+` **520 次 / 49 文件**；而 `openspec/specs/**` 的 scenario 正文里**直接引用**
`docs/team/reports/P52-dev2.md §C` 这类**公开树里不存在**的路径 ✗（约数十处）。

这不是泄漏（不含隐私 ✅），是**公开读者读不懂 / 点不开**的问题 ✅。

## 要 propose 的（先量后议 ✅）

1. **先量**：给出准确清单 —— 哪些是 `specs/**` 正文里的**外部引用**（`docs/team/**` 路径 ✅）、哪些只是代号 ✅、
   哪些在注释/测试里 ✅（测试与脚本可以留代号 ✅，公开读者不看 ✅）。
2. **再议**：给出**可执行的最小改法**，至少覆盖：
   - `specs/**` 正文里的 `docs/team/**` 路径 → 改成**自洽表述**（把结论与数字留在原地 ✅，而不是指路 ✅）；
   - 首次出现的代号 → 一句话说明它是什么 ✅（或者在 spec 顶部加一节术语表 ✅，你裁 ✅）；
   - **不许**弱化任何 requirement/scenario 的**可证伪性** ✗ —— 每条 scenario 仍必须能被独立重跑 ✅；
   - **不许**顺手大改 spec 文案（最小改动 ✅ 一次 change 一个主题 ✅）。
3. **红侧**：给出**可机械检查**的判据 ✅（例如"`openspec/specs/**` 正文不得出现 `docs/team/` 路径"这类断言 ✅
   放进门禁 ✅，且**能红**✅）。
4. 交付：`proposal/design/tasks` + `specs/boundary/spec.md` delta ✅ + `openspec validate --all --strict` ✅ +
   MODIFIED 不丢基线场景 ✅。**只提方案，不改 spec**（apply 另派换人 ✅）。
