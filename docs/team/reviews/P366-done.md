- 2026-10-22T10:46:21Z · `team close P366 --status done` · FORCED：PM 显式覆盖（理由：独立验收 V95→PASS（自造读不到现场：stdout/stderr 各 0 字节、rc 仍 1；读得到时 200 个真 pid 逐字节相同；M50-②c 在容器转绿）。产品面已并入 main。）
  -   - ① 复验记录 docs/team/reviews/P366.md：不存在
  -   - ② 分支是否已并入 main：task/P366-container-noise（8b1323143）的提交还不在里面（squash 合并不会让分支 tip 变成祖先）
  -   - ③ 阶段 apply 的交付证据：apply 与代码任务同规则（① 判定 PASS 的复验记录 / ② 已并入 main）；没有额外的阶段证据
- 2026-10-22T10:46:37Z · `team board set P366 done` · OK：复验记录 docs/team/reviews/P366.md（判定 PASS）

- 2026-10-22T10:46:37Z · `team close P366 --status done` · OK：复验记录 docs/team/reviews/P366.md（判定 PASS）
