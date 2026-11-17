---
id: V175
title: 独立审阅Pulse项目设置精简方案
agent: dev3
category: verify
phase: opsx-verify
change: pulse-project-settings-simplify
specs: panel, memory-and-deps, verification
deltas: -
branch: task/V175-project-settings-proposal-review
---

# V175 · 只审方案，不执行未来UI验收

P470作者dev2，冻结交付`26f5e08eb44e3648c4bd35546983bdb959ef8222`；PM的独立干净检出`/var/tmp/p470-review-26f5e08e.eA48zu`，只读。完整规划metadata/proposal/design/tasks/两份delta齐备，9项实施与验收未勾是预期。当前无产品实现、Apply或归档授权；你未参与本change编写，不代作者修改工件。

先读AGENTS、自己线程、本brief、OWNERSHIP；再读固定源本change完整工件、P469/P470报告、reviews/P469.md及D257/D258，按实际UI和CLI调用点判断，不重做全仓探索。当前用户要求是减少设置和内部语言，不是把全表改成“高级”，也不是建一套配置系统。

## 只裁定这些会影响接受的问题

1. 默认C+7行、8个既有键加C类别的全编辑C+8、110退出键行的账是否正确且没有假装编辑器字段/按钮也算入11？是否保留所有实际类别而不硬编码3类？两个入口及把4资源阈值退出UI是否确有用户用途依据；默认页和低频页有没有仍可删的内部内容，不因怀念旧行而加页。
2. 通读未实现草图的默认、进入/返回、记录、选择/自由输入/表单/保存/取消、失败及中英文用词。名称是否让普通用户知道调整什么，“同时运行任务数”等是否准确表示实际作用范围，说明是否必要，保存是否误称已换模/重启。不得为文案建立词表测试；没有真实屏幕时明确只做草图/源码审阅，不声称视觉验收通过。
3. 并发两字段是否真能复用现有完整`TEAM_MODEL_LIMITS`值及writer，不建立匹配/优先级/默认值副本？对照`common.sh/team_model_limit`、`team_model_limit_pattern_for`、`team_model_peers`及配置校验，核精确/通配/重复/顺序、0及空值的显示说法。UI不要求用户手写表达式是目标；但未动spacing的字节保持、异常整值回退等安排也要判断是否有不必要的实现复杂度，给最小方案，不补通用解析/保护框架或排列矩阵。
4. 4个REMOVED+3个ADDED是否只退休了全表/分组等旧展示承诺，必要的已有写入、权限、完整CLI、模型身份/记录来源、missing/unreadable、后台重读/响应、键鼠/长列表、错误不丢等是否完整承接？作者为原生validate的场景身份规则作退休不等于语义已正确。查两份delta与其余正式spec是否冲突、任务是否双向对应；不要为了净减1或保旧场景数凑要求。
5. 执行安排是否最小且可实际执行：作者实现+静态，非作者一次受影响UI验收，同人merged同一性+必要短接入，另派归档。现有p21选择参数/环境和需要替换的断言是否真在，是否将原CLI全量、旧未改场景或长测试又隐含跑一遍？新增导航/表单检查必须替换旧全表断言，不扩检查段。V174的完整计时固定旧源，不等待、不停止、不受本次规划影响。

## 实际执行与唯一写集

只写自己稳定分支`docs/team/reports/V175-dev3.md`。固定源/主检出/正式spec只读，不执行team review默认实现门禁；不自行试归档，不安装/升级/初始化新root。使用现有OpenSpec1.16，本轮实际只运行一次本change严格结构校验及报告暂存后账本/diff各一次：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 在上述独立固定检出运行，不在自己没有change的任务树误跑
openspec validate pulse-project-settings-simplify --type change --strict --no-interactive
# 回到自己的稳定任务分支，暂存报告后
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

报告先给ACCEPTED/REWORK及真正改变结论的证据/最小返修，再给CRITICAL/WARNING/SUGGESTION、实际命令/版本/stdout-stderr/rc及未验范围。源码判断不是行为实测，结构通过不是交互通过；若有具体未知必须运行才能裁定，点名交PM，不自行扩跑。可读既有测试/报告，不运行UI/pty/类型构建/bundle/smoke/FAST/meta/61b/CLI全量/安装/真实Pi模型/性能/计时。

Conventional Commits含V175与`Agent: dev3`，分步本地提交报告后通知；不push/merge/archive/tag/npm，不改0.4.7、真实配置、队列或待命状态，不清其它人的临时根。较慢命令依后台规则启动后结束回合，不轮询等待。
