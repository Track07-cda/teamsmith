---
id: P474
title: 修复 Pulse 消息页读取发送受阻信息的类型错误
agent: dev
category: code
phase: opsx-apply
change: -
specs: panel#The deferred-delivery queue is read, counted and never touched
deltas: -
branch: task/P474-panel-outbox-type-fix
---

# P474 · 恢复消息页受阻提示与面板类型检查

D261/V177 已确认完整 panel tsc 有 4 处既有 TS2339。先读 AGENTS、本人线程、OWNERSHIP、D261、`docs/team/reports/V177-dev3.md` 的类型检查段和该现有需求。源码中 `queueBlock` 把诊断字段从 `outbox_list` 读出，但该来源仅有 entries/queued/held；`outbox` 已有真正的 impeded/impediments，且页首已有消费点。沿现有查询、刷新和 render 输入确认消息页拿得到它；优先复用这一路诊断，保持现有消息列表和详情、页首及纯文本/JSON行为，不新增数据结构、查询或旁路。不通过 optional 类型、断言、忽略、删除需求要求的提示或改变提示文字掩盖错误；不改发送和重试行为。

写集：`skills/teamsmith/scripts/panel/src/layout.ts`、原生构建生成的 `skills/teamsmith/scripts/panel/panel.js` 与本人报告。如果这两文件确实不能完成现有需求，报告 BLOCKED 与具体来源缺口，不越界。不写设置页、产品 schema/数据生产器、规格、永久测试框架或真实状态。

作者在自己工作树用锁定依赖检查 `bunx tsc --noEmit`（panel 目录，正常候选须 rc0）、原构建 `bash skills/teamsmith/scripts/panel/build.sh`、`git diff --check`，小步提交并给出实测命令、返回码及旧/新数据流。不要跑 smoke、完整面板批次，不更新当前 Pulse。非作者随后以隔离数据验证一组真实消息页受阻记录（识别两种已有原因、普通队列仍可读、无诊断不冒充受阻；没有发送动作或队列写入），并核对 tsc 与真实构建产物；先定位能复用的原有断言，不增检查框架。所有长作业后台跑，不推送、不合并、不发版（提交含 P474 与 Agent: dev）。
