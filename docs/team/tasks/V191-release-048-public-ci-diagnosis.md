---
id: V191
title: 按公开原始记录查清 0.4.8 五个失败作业
agent: verify
category: verify
phase: opsx-explore
change: -
specs: verification#CI runs the two gates separately and performance does not block
deltas: -
branch: task/V191-release-048-public-ci-diagnosis
---

# V191 · 只读取证，区分产品问题和检查过时

已发布 `v0.4.8` / npm 0.4.8，标签冻结 `c34e1468ea2ab76bdff9cd2bbef0db650604d151`，已验证包不动。GitHub run `45318204605` 实际失败；PM 保留的 5 个完整 job 日志及 jobs/artifacts 索引位于主检出被忽略的本次发布目录，固定产品 Git 对象可直接查；见线程。只读，不重跑 GitHub、完整套件、Pi/模型或安装，不改产品/测试，不动标签、包、现实会话、项目配置，不推送。

先交根因表（产品缺陷 / 过时检查或不适用样本 / CI 环境触发 / 原件仍不足），按四段去重：§10 P440 路径记录两项，§28/§38 Pulse 设置的标签、旧入口、帧形态等（区别三类错误；不要把实际功能预判为正常），§67 提醒真实 Pi 工具夹具里的 doctor（核真正两个失败与生产能力相关性）。以测试代码、两轮报告和 Git 对象区分 0.4.7 déjà-vu、当时旧证据可覆盖范围、0.4.8 真新增；覆盖作业只因四片失败还是也有不同独立失败须对照原日志，不重复累计。每一类附原始具体输出、导致的影响、最小修法与必要独立验收；不对未证实根因下定论。只在原 job 日志不能定因时下载对应 `gate-failure-scene`（只读 GitHub，凭据不得输出）；若确有需要只在报告提定点复现方案，不启动长运行。结果 `docs/team/reports/V191-verify.md`、本地提交，原始记录留仓外。