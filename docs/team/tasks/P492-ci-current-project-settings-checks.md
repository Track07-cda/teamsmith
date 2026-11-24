---
id: P492
title: 让公开设置检查按新版页面操作
agent: dev
category: code
phase: opsx-apply
change: -
specs: panel#Selected settings editors preserve owning-command choices and writes
deltas: -
branch: task/P492-ci-current-project-settings-checks
---

# P492 · 让公开设置检查按新版页面操作

读独立诊断 `docs/team/reports/V191-verify.md`，GitHub run 45318204605 的日志与已保存制品位置见本席位线程。已发布的 0.4.8 标签与 npm 包保持不变。

以 V191 根因表分三部分修 `skills/teamsmith/tests/smoke.sh` 的 §28/§38 与 `skills/teamsmith/tests/panel-p21.sh`。删去已不适用的全表标签、旧分组形状和措辞检查，复用已有当前可见标签与完整 CLI schema 的有效检查。选择与写入对照真实页面当前秒单位、实际入口；保留危险确认前不写/确认后一笔、模型规则保存取消及冲突不覆盖、真实 argv 零读取。修读帧按当前键栏/卡片，不把读取失败当 -3 行数；保留 10/1/3 与不同高度、窄屏返回和滚轮不穿透的已定真实行为。不增加整批矩阵、延长等待或改产品/规格。作者只做静态核对；若找到新实际产品缺陷，报告分开、不顺手改。实际操作统一由非作者组内验证，不重复全量。

交 `docs/team/reports/P492-dev.md`（真实命令、结果、覆盖和未运行范围），仅本地提交，不推送、不发布、不中断其他任务。

返修只限 `panel-p21.sh:733`。V193 `2aed3c89` 实测唯一失败：真实落盘 `TEAM_REVIEW_TIMEOUT='30'`，检查只接受无引号或双引号。使用保存后的正确标准单引号格式，仍要求精确键和值，不放宽数值、危险许可、一次调用和一次审计判据；不要增加一个新的解析器或修改前后交互。作者只静态检查并提交。复验直接用 V193 已实跑保存的原文件和故意改错数值/只留注释的私有副本核新断言，其他字节无变化就复用所有 UI 原件，不再启动选择器或整组。原 441/1 不改。