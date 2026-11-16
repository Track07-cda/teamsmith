---
id: A9
title: 同步规格并归档配置测试去重
agent: dev3
category: code
phase: archive
change: config-check-execution-dedup
specs: verification
deltas: -
branch: task/A9-archive-config-dedup
---

# A9 · 仅归档已验收变更

## 已满足前置与有效确认

实现者dev；你未实现该change。P460/V166/P461/V167均已关闭。当前起点main `6f948310`，PM接受记录 `reviews/V167.md`，D247依D241用户授权作出小步可逆代理确认：同步已批准delta并归档，不另等用户确认。完整原生清单7/7；同一verify对b26bd419/c442b57ac两阶段通过，最终报告b0998289/清单03a181d9，CRITICAL0/WARNING0。两个requirement/五scenario的验收范围已覆盖；原生成面SKIP和51原1条可见SKIP仍是边界，不把它们改记PASS，不要求为此追加全量。

## 执行与写集

1. 读AGENTS、自己的线程、本brief、archive skill及本change全部规划/正式verification spec。用已安装OpenSpec1.16的原生list/status/instructions确认当前根与7/7；按skill读取可用archive guidance/specs rules，不能据advisory改CLI行为或写入无关规则。`team change status config-check-execution-dedup`只能剩A9自身未完成；别的阻塞要报告。
2. 先在自己的 `/var/tmp` 唯一私有副本试运行原生 `openspec archive -y config-check-execution-dedup`，核真实同步结果；再在自己的稳定任务工作树按同样原生命令同步/归档。不安装、升级或初始化新root，不用手写移动/合并替代CLI。同步选择已授权为sync后archive；不跳规格、不跳验证。
3. 写集仅该change整体移入日期archive（含.openspec.yaml）、`openspec/specs/verification/spec.md` 追加已接受两requirement/五scenario、确实必要的现有索引引用，以及自己的 `docs/team/reports/A9-dev3.md`。既有Purpose与其余正式需求必须逐字节保持，不能扩修长需求、产品/测试/CI/超时或任何真实团队状态。
4. 在自己的归档分支运行一次以下短检查，保留真实输出/rc。较慢批次 `team_bg_run` 后结束回合；不在回合内等待。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
# 最终报告暂存后
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

本项目当前全项目非strict是既有决定，不改称strict全绿；本change严格校验已有独立证据。不跑smoke任何真实段、全量/FAST/61b/meta/夜间、完整51/help/config、安装或性能，不为归档重复已验行为。

5. 核实际归档目录/原生根、清单7/7、两条需求/五场景同步恰一次及非delta正文不变；无未提交或漏纳入的归档文件。报告保留原SKIP/原51局部证据边界、未测全量耗时，给出命令和收据路径，而不是复制全部历史。若CLI动了授权外内容，报告BLOCKED，保留现场，不自己扩大范围。
6. 小步提交，Conventional Commits含A9及Agent: dev3，保持本地；PM接受后合并/关单。你不合并、不推送、不发版/动tag/npm；0.4.7既有包和标签不变。只清理自己的这次具体临时根，不碰P461/V167或别人的原件。
