# dispatch-friction · 提案评审（P136）— PM 判定

time: 2026-09-30T06:1xZ · reviewer: pm · verdict: **ACCEPTED**

```
change: dispatch-friction（propose=dev2 · 9 commits）
```

## 我亲手核的

| 项 | 结果 |
|---|---|
| `openspec validate --all --strict` | **14/0** |
| **MODIFIED 不丢基线场景**（逐 requirement 机械比对） | 「A dispatch never mixes two tasks…」2→3 · 「One task branch per task」3→9 · 「A brief names at most one change id」5→7 · 「Two unfinished tasks of one change…」6→9 · 「The printed route is a route that works」9→14 —— **丢失 0**，新增 **17** |
| 新增 requirement 确实不在基线 | 「A refused dispatch hands over every blocker, once, with a fix that runs」与「A dispatch warns before a seat that burned its last round」基线命中 **0** |
| ① 分支名循环 | 覆盖到位：「分支身份可见」·「**同一任务的另一个 slug 被接受而不是拒绝**」·「`--branch` 指定本任务期望名」·「**`--branch` 指向别的任务仍被拒**」·「工作树停在别的任务分支仍被拒」（**没放松守卫**） |
| ② 报错文案 | 「**首个合法示例出现在第一行**」·「逗号语法在畸形列表的第一行被教到」·「尾随逗号与空格列表被点名」（含 PM 自己撞过的 `·` 分隔符写法） |
| ③ 配额预提示 | 死因 `quota`/`balance` 时给出分类+来源+时间+原始行；上一轮 0 产出时用工具自己的粗词（`0 bytes ≈ 0 tokens`）；**判不出来就沉默、绝不猜、不阻断** |
| ④ 幂等 | 「一次拒绝列出**全部** blocker + 每条给可粘贴的 `修法：<command>`」；`--print` 同样判定；拒绝时不开窗、不切分支、不写状态、不动看板 |
| 非目标 | 明确排除：放松守卫 · 无审计的绕过 · `docs/team/**` 格式 · 死因词表 · tmux |

## 结论

**ACCEPTED** → 提案合入 main。apply = **P140**（守则：不放松守卫；独立验证换人）。
