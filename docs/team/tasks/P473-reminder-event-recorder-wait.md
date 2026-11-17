---
id: P473
title: 修正提醒单场景等待测试记录的时序
agent: dev2
category: code
phase: opsx-apply
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/P473-reminder-event-recorder-wait
---

# P473 · 只改现有一处等待，不改提醒产品

事实见已接受的P472报告29664d0f（合并a50ed0fd）及reviews/P472.md：event-after等待产品observed后，马上assert另一处理器写的custom_start；authority先发布状态、下游记录器稍后运行，两个观察没有同步保证。历史现场已失，不能说已证明V174本次失败必由此引起；原FAIL仍保留。本单修可直接定位的检查顺序，不新增产品要求或change。

先读AGENTS/本人线程/OWNERSHIP与P472的F2。唯一实现写集为`skills/teamsmith/tests/remind-tool-real.mjs`的既有`adversarial-event-after`场景（原557行）及本人`docs/team/reports/P473-dev2.md`。

把即时事件assert替换为复用原`until`等待**相同事件条件**。现有90秒上界、50ms轮询不改，不加sleep、不增加匹配/身份/默认层；产品observed等待、之前忙碌/intent的断言、之后generation-ambiguous/on/generation=2及receipt均保留。测试新等待替换旧即时检查，净增检查/fixture/入口/脚本为零；不改产品、永久provider夹具、其它场景、schema/规格、真实队列/配置/待命。单场景选择早已支持，不另写选择器。

## 作者仅静态交付

先本地提交最小修复，再补本人报告；真实执行只需：

```sh
node --check skills/teamsmith/tests/remind-tool-real.mjs
# 报告暂存后
git diff --check
git diff --cached --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
```

不运行Pi/单场景/其余69、smoke/FAST/meta/61b或完整计时，不为这一行新建OpenSpec或复现框架。报告先STATIC-READY，给实际命令/rc、修复前后及候选SHA；不称历史根因已证实或行为已过。短作业如变慢按background规则，不回合内等待。

交付后由PM另派非作者，在独立固定源仅跑既有`node skills/teamsmith/tests/remind-tool-real.mjs --select=adversarial-event-after`，私有HOME/tmux/loopback provider，无外部模型。必须保留`P442_KEEP=1`和本人唯一`P442_EVIDENCE=/var/tmp/...`原件；用最小临时记录器先后控制证明旧即时断言会失败、等待修复后通过，保留后续G2业务断言，不能拿注入/启动失败当红侧。控制只在非作者私有副本/证据，不引入永久fixture或生产hook；本单作者不提前执行这组。该批之外不补全套或其它cases。

Conventional Commits含P473及`Agent: dev2`，仅本地提交，不push/merge/archive/tag/npm。P471设置实现并行、写集不相交，不顺手碰其界面或旧颜色检查，不清别人的目录。
