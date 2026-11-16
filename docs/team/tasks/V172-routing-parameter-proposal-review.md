---
id: V172
title: 独立审阅正常路由及五项参数故障检查的去重方案
agent: verify
category: verify
phase: opsx-verify
change: routing-parameter-check-dedup
specs: verification
deltas: -
branch: task/V172-routing-parameter-proposal-review
---

# V172 · 只审规划，不执行未来行为验收

P467作者dev2，冻结交付`824cfd82`（首步工件d8023907），工作树干净。PM准备只读独立检出`/var/tmp/p467-review-824cfd82`。你未参与本change的规划或实现；当前是方案审阅，不是实现完成性验证。四规划工件完成、未来六项任务未勾是预期，不据此要求实施或声称归档就绪。

先读AGENTS/自己线程/本brief及OWNERSHIP，再读本change全部工件、作者报告、P454相关结论和真实产品/测试调用点。复用已有P228 F3/F4/F5、P457/V163证据，不重做全仓研究或重建成本基线。遵守D245/D246/D254：削减真实重复，不因防御性偏好保底全部排列，也不以独立审阅名义新增一轮长测试。

## 只判断这些影响接受与否的问题

1. 共用直接断言是否真的能被正常boundary和五条故障共用，且四份既有测试文件足够？核产品helper的输入、fresh/continued差异、变量/数组隔离与同shell累计结果。固定期望是否独立；没有复制parser、产品改动、源加载平台或隐性完整准备。
2. 正常旧潜在562次与计划42次真实CLI/197个直接负例的账及有意舍弃的观察是否正确？这些是盘点不是保底配额。特别判断21对每条都preview+launch是否仍重复同一事实；若可更简单，给最小删减，不要求凑旧计数或再保留所有组合。必要合法启动/实际argv/记录、fresh/continued、PM metadata/撤销仍保留。
3. 具名真实见证是否能建立有效前提、到达计划观察的真实调用点？原配置writer会提前拒绝部分非法输入，不能将setup红当caller拒绝。核设计的合法准备及坏输入取得方式是否足以支撑每类见证，按源定位具体缺口，不自行跑样本。F3的四个template/extra入口、F4误绑定、F5 scalar/list与恢复角色须有真实观察，不用helper正确替代；也不要求每条冗余guard单删必红。
4. 五个原变异保持、同副本healthy/坏/恢复、目标失败名和父级消费是否自洽？私有bounded parent仅改选择/基线、其余消费同一的办法是否够小且可复核？真实一次取得原五臂，短回放不再重跑业务、不复制判定；异常rc/timeout/缺目标名/healthy或restored失败确实不能误算成功。若提取/旁路安排过重，明确最小替代，不增框架。
5. 完整MODIFIED需求与旧17场景、新六场景、design/tasks是否一致？特别核旧routing-argv场景的“one final non-FAST complete 61b”与本批明确不再跑整组的适用边界，不能留下让实施者再付73分钟的文字冲突。旧三处已完成验收不得重开；本批不变更产品、配置、等待/观察窗口、smoke/CI/选择表、其它组或发布对象。
6. 作者静态/非作者一次实际受影响验收/合并后同一性加必要短检的安排是否覆盖本批独立事实且没有重复？不要求为审方案、引用旧证据或合并账本而重跑正常boundary、五臂、完整CORE/61b或其它功能。历史3323s/575s不是本轮实测，不能合成节省承诺。

## 本轮执行与写集

只写自己稳定任务分支的`docs/team/reports/V172-verify.md`。候选、主检出及规划只读；不执行`team review`默认实现门禁，不代作者修工件。不安装/升级/初始化新OpenSpec根。必要时读原生root/status确认冻结源，采用现有OpenSpec1.16。

实际只运行本change严格结构校验，以及自己报告暂存后的账本/差异检查各一次：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 在固定独立检出确认本change；结果保存到自己的临时证据根
openspec validate routing-parameter-check-dedup --strict
# 自己报告暂存后，在自己的稳定任务树
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

报告先给ACCEPTED/REWORK与能改变结论的证据、最小返修，再列CRITICAL/WARNING/SUGGESTION和实际未验边界。不得把源码推论或结构通过称行为实证；若必须有小样本才能定论，点名具体未知交PM，不自行扩跑。报告保留真实命令、版本、stdout/stderr/rc及临时原件位置，不强制加入原日志。较慢批次后台启动即结束回合，完成唤醒再收取，不等待/轮询。

不跑参数/路由样本、构建、正常boundary/CORE、五臂/61b、smoke/FAST/meta/夜间/其它功能/安装/性能/真实Pi或模型；不重跑全仓strict/引用或选择平台。Conventional Commits含V172、`Agent: verify`，小步本地提交交付；不merge/push/归档/发布，不动0.4.7包。仅处理自己本次临时根，已收存的V171旧根不重建、不延伸清理。
