- 2026-10-22T11:52:28Z · `team close P364 --status done` · FORCED：PM 显式覆盖（理由：A1 由 V96→PASS，产品面已并入 main（指针行 + 一份计数）。A2（结果账与 digest 点名）另立 P365。）
  -   - ① 复验记录 docs/team/reviews/P364.md：不存在
  -   - ② 分支是否已并入 main：task/P364-notice-pointer-a1（0bdef80f1）的提交还不在里面（squash 合并不会让分支 tip 变成祖先）
  -   - ③ 阶段 apply 的交付证据：apply 与代码任务同规则（① 判定 PASS 的复验记录 / ② 已并入 main）；没有额外的阶段证据
- 2026-10-22T11:52:39Z · `team board set P364 done` · OK：复验记录 docs/team/reviews/P364.md（判定 PASS）

- 2026-10-22T11:52:40Z · `team close P364 --status done` · OK：复验记录 docs/team/reviews/P364.md（判定 PASS）
