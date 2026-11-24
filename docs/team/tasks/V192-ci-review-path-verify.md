---
id: V192
title: 独立复验 CI 短家目录与复验记录路径
agent: verify
category: verify
phase: verify
change: -
specs: verification#Delegated reviews record their actual executor and narrow ledger authority
deltas: -
branch: task/V192-ci-review-path-verify
---

# V192 · 只验现有 §10

作者 dev2；候选 `725e7ed2` 固定检出见线程，`163377a8` 只加报告。先核真实 diff、V191 原 CI 原件和指令。只在候选已冻结的独立检出执行原 §10 一次（自动前导如实记），实际复验目录位于 `/var/tmp`、`HOME=/tmp`，只在隔离容器内采用这个 HOME，`TMPDIR=/var/tmp`；不把宿主 HOME 指向共享 `/tmp`。优先用已有本机发布检查的固定镜像（不要拉取或修改共享镜像）；若宿主看不到给定检出，可按 V189 导出同一固定源至本席位私有且宿主可见的副本，核对来源与 Git 需要的隔离元数据。做不出精确布局则报告，不能以普通 HOME 通过替代。启动长命令用后台而不等待，保留实际出口和日志原件。

必须见真实 review 通过，合法 `/var/tmp/...` 与兄弟目录不被误判，真正 HOME 表示仍正确；故意关净化的既有样本仍报告真实绝对 main/HOME 及其失败，恢复原副本再通过；原四种语言环境正反与原记录判据保留。可用现有记录静态对照实际路径边界，不新增检查，遇到真实问题退回。只跑指定段，不跑整套、远端 CI 或模型；不改产品、测试、已发包/标签。交 `docs/team/reports/V192-verify.md`，仅本地提交，原件留待 PM 收取。合并后同一人只核相关字节，无变动不重跑。