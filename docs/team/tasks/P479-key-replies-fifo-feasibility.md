---
id: P479
title: 判断关键回复 FIFO 故障检查能否不等五分钟
agent: dev3
category: analysis
phase: opsx-explore
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/P479-key-replies-fifo-feasibility
---

# P479 · 只试一个等待，不启动组验收

先读 AGENTS、本人线程、OWNERSHIP、P477 报告及 `skills/teamsmith/tests/key-replies.sh` 的 `flip_probe_fifo_block` 与既有工具。目标是用简短、已有工具可取得的直接证据结束故障侧等待，不是降低超时阈值，不改产品，也不删现有 FIFO 正常拒绝或坏源/恢复检查。

允许在本次专属 `/var/tmp` 隔离副本用一次短样本试可行性：对比未改源码与仅去掉 `O_NONBLOCK` 的源码，对同一个无写端 FIFO 启动真实 `reply list`。正常侧应退出 4、说明为什么拒绝；坏侧必须可靠识别这个实际进程在等这个 FIFO 的写端，不能把进程活着、启动慢、随便一个失败或等待兜底当作证明。能取得证据后只结束自己启动的进程，并确认没有残留。没有简洁、现有环境能用的办法，就建议保留原检查；不引入强制依赖、产品自检、通用观察框架或为省几分钟制造更多代码。上下游八个故障检查和只读界面三次会话另项不动。

只写 `docs/team/reports/P479-dev3.md`，记录实际命令和退出、如何区分真阻塞与未启动、对现有运行环境的限制及建议。短样本跑完即止，长作业走后台；不改工作树测试代码、不跑 key-replies 组及整套、不推送。PM 决定是否另开小改动，由非实现者验收。
