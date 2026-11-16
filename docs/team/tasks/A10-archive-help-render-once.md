---
id: A10
title: 同步规格并归档帮助入口单次生成
agent: dev2
category: code
phase: archive
change: help-route-render-once
specs: verification
deltas: -
branch: task/A10-archive-help-render-once
---

# A10 · 只收尾已独立验收的帮助测试变更

实现者dev，你未实现该change。P462/V168/P465/V170已接受关闭；D251依D241用户授权确认归档，不再等额外人类确认。最终证据为V170报告5277cf1c、P465工具记录（dev3执行，merged7d768f1a PASS）、V170 PM接受记录；4/4任务、1requirement/4scenario，CRITICAL/WARNING/SUGGESTION均0。候选完整route只跑一次10/0/SKIP0，合并字节同一仅短验0/1/0，不能为归档重跑帮助或全量。

先读自己的线程、本brief、archive skill及change全部工件/正式verification。用已安装OpenSpec1.16原生list/status/instructions确认根和4/4，按skill读取适用archive guidance/specs rules，不据advisory改变CLI或写无关内容；不安装/升级/新建root。`team change status help-route-render-once`若只剩A10自身未完成属预期，别的阻塞应报告。

## 执行及写集

1. 先在自己的唯一/var/tmp普通独立副本试原生 `openspec archive -y help-route-render-once`，确认只同步既定delta；不能用hardlink副本让预演写回原树。再在自己稳定A10工作树用同样原生命令真实同步/归档，不手写移动/另建规格副本，不跳同步或验证。
2. 唯一写集：该change整体移入日期archive（含.openspec.yaml）、`openspec/specs/verification/spec.md`追加已接受一条requirement/四scenario，以及自己的 `docs/team/reports/A10-dev2.md`；确有必要的既有索引引用才说明并最小更新。既有Purpose、其它requirement/scenario和全部产品/tests/CI必须逐字节不变，不碰clipboard提案或任何真实团队状态。
3. 在自己分支真实跑一次 `openspec validate --all`（本项目非strict沿用既有决定，不冒称全仓strict）、`bash skills/teamsmith/tests/spec-refs.sh --check`；映射/选择器没变且原回执已接受，不再整套选择自检。最终报告暂存后ledger-ban（主git公共目录名单）及普通/暂存diff-check。采用现有OpenSpec1.16，TMPDIR=/var/tmp，CI=1、OPENSPEC_TELEMETRY=0；较慢批次后台启动即结束回合，不在回合内等待。
4. 核真实归档目录/原生根、4/4、正式新增需求/四场景恰一次、非delta正文及可执行字节不变；报告真实命令/rc/原件位置和保留的证据边界。不把旧全轮rc1/帮助局部132或未改组复用改写为本轮全绿，不承诺整套提速。
5. 归档小步提交后交付，本地分支不push/merge/tag/npm。PM接受后合并关单，你不代PM写接受结论。只清自己本次具体试验根；P465/V170原件未收存，绝不动它们或别人的目录。原日志/快照留本地，不git add -f。

不运行任何帮助/route/locale/routes/51、smoke真实段、全量/FAST/meta/61b/夜间/构建/安装/性能/真实模型。若原生CLI触及授权外内容或4/4/最终证据不匹配，保留现场BLOCKED并通知PM，不自行修产品、规格范围或门禁。提交Conventional Commits含A10及Agent: dev2；消息不是交付，报告/归档提交和真实回执须完整。
