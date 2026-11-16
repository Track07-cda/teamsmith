---
id: P468
title: 共用参数检查，删除正常及五项故障里的重复执行
agent: dev
category: code
phase: apply
change: routing-parameter-check-dedup
specs: verification
deltas: -
branch: task/P468-routing-parameter-check-apply
---

# P468 · 仅实现与静态交付

正式proposal review已ACCEPTED（返修2c4f86d1、V172最终7157bfcd、D255，规划合并9c8c0f0c）。你负责原生任务1.1/1.2/1.3；2.1/2.2/2.3由另一个席位集中验收，不提前勾选。此前只审规划，没有替换后的行为或耗时读数；原42次旧盘点保留为历史，当前22次只是计划，不是已完成结果或永久配额。

先读AGENTS、自己的线程、本brief、apply skill和原生apply返回的全部contextFiles。明确选择本change，沿用已安装OpenSpec1.16的list/status/instructions确认自己的根、4/4规划工件与0/6实施进度；逐项按真实sourcePath/line完成1.1–1.3。不得为了交付实现先跑一轮行为。

## Boundaries

- 实现仅四个既有文件：`skills/teamsmith/tests/task-model-routing.sh`、`skills/teamsmith/tests/lib/model-routing-boundary.sh`、`skills/teamsmith/tests/lib/model-routing-expansion.sh`、`skills/teamsmith/tests/lib/model-routing-roles.sh`。另可勾本change `tasks.md`的1.1–1.3、写自己的`docs/team/reports/P468-dev.md`。不改已接受proposal/design/delta、正式spec、原五故障变异器、产品、配置、smoke/CI/选择表、其它组或真实团队状态。
- 按design §1–3复用旧输入及真实产品函数，新增现有前门的唯一parameters分组；正常boundary和它共用同一规则断言，不新增parser、登记表、缓存、runner或五套选择器。子shell只产观察值，原调用shell累计真实结果；短分支在完整项目准备之前，不借正常boundary另跑第二次parameters。
- 按design §3用既定真实调用替代旧负向模式排列；保留准确诊断、合法前提、状态/argv观察和最终renderer。C1的两个list输入与PM continuation前提以已接受工件为准，不能拿更早的无关拒绝或setup失败代替目标行为。正常合法启动、quoted literal、fresh/continued、PM metadata/撤销和P457两项argv证据不动。
- 按design §5及Migration仅改五条参数臂的分组、必需失败名及同副本healthy/原故障/字节恢复/restored安排，真实父级仍消费具名结果；其它26臂和P457已退休三处不动。只交付bounded parent执行说明，不自行运行它，不建立第二套故障算法或专为凑PASS的检查。
- 197/22是本次迁移盘点，不是固定PASS数守卫；不为保住旧总数补成功断言，不缩等待/超时或改按键节奏。若实现真需写集外接口，给具体缺口BLOCKED，不扩库或改规划。其余细节以原生工件为准，不另立一套要求。

## 本席位唯一验收：静态

```sh
set -e
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
bash -n skills/teamsmith/tests/task-model-routing.sh
bash -n skills/teamsmith/tests/lib/model-routing-boundary.sh
bash -n skills/teamsmith/tests/lib/model-routing-expansion.sh
bash -n skills/teamsmith/tests/lib/model-routing-roles.sh
openspec validate routing-parameter-check-dedup --type change --strict --no-interactive
# 最终报告暂存后，采用现有项目名单；不读名单内容
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

只做必要源码核账：旧/新真实调用点与退休capture、共用规则输入/固定期望、五臂必需名及恢复/父结果处理、未改组/原合法控制的同一性。保留真实静态命令/rc与固定tip，不把源码计数写成实际执行数；最终原生进度应3/6。已有版本、引用、路径/选择登记与旧接受记录复用，不另跑源研究、spec-refs或选择器平台。

不运行任何boundary/parameters/argv/其它路由组、五臂/完整flip/61b、CORE、smoke/FAST/meta/夜间、其它功能矩阵、真实Pi/模型、性能、安装或构建。唯一行为轮次将由非作者在PM准备的冻结独立检出执行design Migration的一次正常boundary、一次五臂bounded parent及既定短旁路/结果消费；不先单跑五臂再跑父级，同字节合并只补短接入。

每个可核对实现步骤及时小提交，再补最终静态回执/报告，Conventional Commits含P468和`Agent: dev`。报告先说明实际删了什么重复、保留什么、哪些尚未行为验证，再给证据；原件仅存自己本次具体临时根，不git add日志。较慢静态批次用team_bg_run后结束回合，完成唤醒再收取，不等待/睡眠轮询。

分支只留本地，不merge/push/归档/发布；不清理P467/V172及其它席位的原件，不触碰已发布0.4.7包/tag或提醒/待命状态。
