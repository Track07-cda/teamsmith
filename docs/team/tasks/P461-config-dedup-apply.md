---
id: P461
title: 删除重复配置调用并解开七个准备依赖
agent: dev
category: code
phase: opsx-apply
change: config-check-execution-dedup
specs: verification
deltas: -
branch: task/P461-config-dedup-apply
---

# P461 · 只实现和静态验收，不重复真实行为验收

规划已经正式接受：`docs/team/reviews/config-check-execution-dedup-proposal.md`、D246，独立V166报告8ef5dc6c。实现起点main `9e3833bb`；原规划冻结1589612c，不重开设计。使用change `config-check-execution-dedup`，schema spec-driven，原生apply当前7项未勾。

先按AGENTS/自己的线程/本brief读，再读apply skill及此change的proposal/design/delta/tasks。用已安装OpenSpec1.16执行只读list/status/instructions apply确认本工作树根和任务位置，不安装/升级、不初始化另一个root，不把CLI计划当实际完成。

## 写集与分工

只改：
- `skills/teamsmith/tests/smoke.sh`
- `skills/teamsmith/tests/section-paths.tsv`
- `openspec/changes/config-check-execution-dedup/tasks.md` 中本轮实际完成的1.1/1.2/2.1复选框
- `docs/team/reports/P461-dev.md`

本单只执行清单1.1/1.2/2.1及其静态验收。实际33、七键、roster/短setup/缺brief坏腿和原日志复用对应1.3/2.2/3.1，统一留给后续非作者在PM固定检出执行一次；3.2合并后验证仍待完成。这是D246的执行分工，不删任何已接受行为或证据。仅三个已实现且静态验收覆盖的叶子可勾；未执行的四项留空，不把整体报成7/7。每项勾后刷新原生instructions确认其位置/进度。

## 最小实现

按已接受design：先删除51最后的重复config-cli整块及说明、更新相关路径token，小步提交；再原样移动完整p24路径/shim/十四函数准备至已确认的公共前导位置，删除七条needs/basis并提交。保留33无参数调用与父级非零失败分支、51前面的routes/help全部调用/输入/汇总、消费者正文与live前提。规划中的config-cli/routes/help-surface三个脚本必须与接受基线逐字节相同；其余needs/段/循环清单不改。

不得修改产品代码、正式spec、proposal/design/delta、CI、超时/FAST/跳过规则、其他测试断言；不新建助手平台、缓存或防护分支。出现真实数据依赖或必须越写集，保留现场报告BLOCKED，不用新needs/新豁免掩盖。

## 本轮实际验收命令

从自己的稳定工作树发起，TMPDIR=/var/tmp；较慢批次后台启动即结束回合。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec --version
openspec validate config-check-execution-dedup --type change --strict
bash -n skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/section-select.sh --self-sufficient
bash skills/teamsmith/tests/section-guard.sh --loop-check
bash skills/teamsmith/tests/spec-refs.sh --check
for key in 12e 12f 12g 12h 12i 12j 12k; do
  bash skills/teamsmith/tests/section-select.sh --select "$key" || exit
 done
for path in skills/teamsmith/tests/config-cli.sh skills/teamsmith/scripts/lib/cmd-config.sh skills/teamsmith/tests/task-header-model.sh ci/config-dedup-unclaimed; do
  bash skills/teamsmith/tests/section-select.sh --paths "$path" || exit
 done
# 最终报告暂存后
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

再以Git原blob核对：config-cli/routes/help-surface三脚本、33父调用和51保留调用/汇总/输入与接受基线9e3833bb相同；原准备块移动前后字节相同（纯移动除外），消费者正文原样；只有获准的调用/七边/两token/说明被退休。不造永久自检，比较命令与结果写报告即可。

**本单不执行smoke任何真实段、完整config/help/routes、坏样本、全量/FAST/meta/61b/夜间、安装或真实模型**，避免之后独立验证再跑一遍。报告明确本轮是实现+静态证据，不声称真实行为已验、整体已完成或已测提速。下一步是PM准备独立冻结检出交非作者覆盖全部1.3/2.2/3.1。

## 交付

小步提交，Conventional Commits含P461与Agent: dev。自有报告先说实际退休对象、三项完成/四项未执行、实际工具/根/命令/rc与具名SKIP，再列证据路径及下一步；不得把静态计划当运行。报告随分支提交，保持本地；不merge/push/tag/archive，不碰其他工作树。只清自己这一次具体临时目录，保留待复验原件。

后台工具自己的共享state/bg记录已识别为运行时行为，不因此扩修工具或停本单；未知来源的主检出源码改动仍按AGENTS处理。既有主根.cortexkit文件不是本轮新污染，不能据它中止。
