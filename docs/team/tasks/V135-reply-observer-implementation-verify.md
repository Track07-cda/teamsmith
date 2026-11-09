---
id: V135
title: reply-observer-skip-focus 实现独立复验
agent: dev3
category: verify
phase: opsx-verify
change: reply-observer-skip-focus
specs: key-replies verification
anchor: openspec/changes/reply-observer-skip-focus/tasks.md
deltas: -
branch: task/V135-reply-observer-implementation-verify
---

# V135 · 非作者实现复验（tasks 3.3）

冻结候选 `1b34991d`，作者 dev。你未参与实现；提案审阅不能替代行为复验。阅读 change 全部规划、P434 报告、实际 diff 和作者证据 `/var/tmp/p434-reply-observer/`。

PM 已重跑结构检查：OpenSpec 23/23、change strict、spec refs 125、section-select ok13、账本禁令 hits0、diff check。不要把它们当行为证据。

## 必须独立做

1. 在自己的检出和 `/var/tmp` 证据根中运行 `key-replies.sh --select skip-path`，检查三条真实诊断、两项未验证、无索引、一槽反例、三类反例与还原、独立子样本前缀。不得只复述作者输出。
2. 在自己的外部完整副本中分别取得 bounded/full_scan 的损坏、吞错、还原六组原始结果：损坏必须出现具名父级诊断；吞错即使 rc=1 也不得出现；还原回绿。副本必须能解析 `lib/proc-io.sh`。
3. 在固定隔离容器中独立跑一轮非 FAST `smoke.sh --select 62 --keep`，保留完整 bind-mount 日志；核对正常 bounded 独立文件断言先于观测入口、九臂真实坏/恢复、full_scan 内核读量和其它回复组。不能仅阅读作者 §62 日志。
4. 确认两处完整 `bounded,flip`、失败 trace、预测 SKIP 和 SKIP 总数判据确已删除，没有备用/夜间路径；正常覆盖未转移。
5. 核对三层计数、真实执行量与耗时，不把旧 822s 与新 458s 直接当作同环境净节省，不把缺观测器说成产品通过。

## 工具与边界

容器用 `distrobox-host-exec podman`，不要直接 podman；日志落自己的 `/var/tmp` 专属目录。不得修改真实项目，不跑全量、夜间、61b、无关 UI 或公开 CI。

## 交付

`docs/team/reports/V135-dev3.md`，先给 **PASS / NEEDS-CHANGES**，每项附自己的命令和日志；拒绝只引用作者证据。可补跑结构检查；只提交报告，不改实现/规划，不勾选任务，不合并、不归档、不发布。通知 PM。
