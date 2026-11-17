---
id: V174
title: 五批精简后的一次完整产品测试计时
agent: verify
category: verify
phase: verify
change: -
specs: verification#The run reports each section's outcome counts and its slowest sections
deltas: -
branch: task/V174-post-slimming-full-timing
---

# V174 · 只做一次完整计时，不阻塞新开发

用户2026-11-17明确授权“1. 后台做”，同时继续其它开发。五批精简已全部接受关闭；本次是里程碑测量，不是把其接受结果重新作废、追加验收或启动发版。固定源`532c8b474f9aa3ec9d9094b28ae88463cd9d88e5`，PM独立干净检出`/var/tmp/v174-review-532c8b47.RgzJCh`。你未实现这些变更，只运行和报告，不改产品/tests/规格。

## 立即执行

1. 读本人线程、brief及所引用的短规范上下文即可；本单change为`-`，不跑OpenSpec change工作流、不重新审查已验五批或整仓历史。确认固定HEAD/干净状态，在本人已创建的唯一/var/tmp目录保存原始输出；TMPDIR使用确实存在的目录，避免V171父目录不存在的问题。准备完成即启动下面唯一运行，不为写runner先做预跑/完整研究。
2. 从本人worktree调用正式review，唯一中央写入例外是`docs/team/reviews/V174.md`、`V174-verify.log`，实际执行者verify：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
TEAM_GATES='env TEAM_META=0 bash skills/teamsmith/tests/smoke.sh --snapshot=532c8b474f9aa3ec9d9094b28ae88463cd9d88e5 </dev/null' \
TEAM_REVIEW_TIMEOUT=14400 \
bash skills/teamsmith/scripts/team review V174 \
  --dir /var/tmp/v174-review-532c8b47.RgzJCh \
  --branch 532c8b474f9aa3ec9d9094b28ae88463cd9d88e5
```

在本席位`team_bg_run`启动整条命令就结束回合，完成唤醒后`team_bg_wait`收取。保留原生锁和已有超时，不另起并行套件、不回合内等/轮询。`--snapshot`已支持活树继续提交，用既有机制，不要求PM停止其它开发或另造冻结/调度框架。源固定，后续设置界面的改动不属于本轮受测版本。

3. 本次完整正常产品检查只跑一次；`TEAM_META=0`按现有分类明确不执行额外元套件，记录实际跳过及原因，不把它们说成通过。不追加meta/完整61b、安装、打包、性能套件、真实模型或另一轮全量；也不先单独跑参数/帮助/配置/粘贴。
4. 完成后先给答案：本轮实际运行墙钟、排队时间分开，退出码、段/断言/跳过计数，以及原生逐段统计中最慢10项。原始完整log、工具record和原生统计保留。旧`/var/tmp/rel47-first-order.log`约113分钟仅参考，不是同负载净提速，不为了对照再跑旧版本。不新增计时阈值或机器安静判据。
5. 如出现真实失败或中断，原样保存并点名现象/已覆盖范围，交PM判断；不改代码、不拉长时间、不加SKIP、不盲目重跑，不把不完整耗时称完整结果。测量不自动撤销已完成任务或阻止新功能合并；新失败另有证据和任务处理。

## 交付

只写本人`docs/team/reports/V174-verify.md`及上述中央正式review例外，及时本地提交，说明真实命令/退出码/源SHA/计数/慢项与原件位置。最终报告暂存后只做适用ledger/diff短检查，不补业务。不得push/merge/tag/npm，不动实际项目配置、提醒、待命或别的项目，不清自己的原件或PM固定检出，等PM收存。先通知“后台job id已启动”，完成后再发最终交付，避免PM把仍在运行当成已完成。
