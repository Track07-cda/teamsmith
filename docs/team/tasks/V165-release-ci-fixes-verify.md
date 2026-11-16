---
id: V165
title: 独立复验CI三处修复与单文件分类修正
agent: verify
category: verify
phase: opsx-verify
change: -
specs: verification#The record states what was verified
deltas: -
branch: task/V165-release-ci-fixes-verify
---

# V165 · 独立短复验，先候选再合并提交

你完成过V164诊断，未实现P459。候选bf483405aa06（完整SHA见检出HEAD），最后代码992fb4c9；PM准备干净检出 `/var/tmp/p459-review-bf483405`。自己的任务树只写 `docs/team/reports/V165-verify.md`，不改实现。源范围见P459任务书（以main的最终续跑授权为准）和候选 `docs/team/reports/P459-dev.md`。0.4.7已发布，不动tag/npm/远端CI。

## 证据与边界

- 原三项修复的同一冻结82ea7496选段：18段458/6、510s。10/10b/39绿，真实Pi工具/恢复/对抗10/3/7均绿，6个外层失败唯一违例均为活PM每5秒更新的current.json。
- 最终多2行共享分类：只允许 `./state/remind-tool/current.json` 正常变化，原权威状态优先拒绝不动。四组原件旧判定只报该文件/新判定无违例；两组被原封装删除，只有完整输出12/0、7/0和同一判定调用。原458/6不能改写成全绿；两组缺原件必须保留，不合成、不补造、不为补文件重跑业务。
- 原件/检查脚本/日志 `/var/tmp/p459-dev.ND49Qq/`；原smoke现场 `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.kbie4E/`，Pi原件在p442/p443/p444。四组before/after的精确目录见候选报告表。源码5文件diff、该报告及classification-check*.log、原18段日志均需核读。
- 前导skill-load三个SKIP与section-select的一个生成目录SKIP是已披露边界，不记通过；全项目strict长文本问题不在本次范围。

## 阶段A · 实际短验证

先核候选干净和5个变更文件、授权、原始收据，判断组合证据是否足以证明对应行为；有可证反例就给FAIL，不因PM准许组合证据而自动通过。

在自己的 `/var/tmp` 精确临时根写短runner，直接调用候选原函数/原driver；不能重新实现产品判定或只做字符串检查：
1. 实跑P440现有显示矩阵（两HOME、C/C.UTF-8）及旧替换反例/恢复；确认真实路径中段不被改、真正根仍显示占位。既有真实review完整证据可复用，不重跑18段。
2. 实跑共享init比较和原⑮正常/真参数错误反例，对齐安装方式后的完整AGENTS比较/config不变仍承重。可以审阅并适配作者的仓外提取脚本到候选，但记录实际输入/输出，不能在作者工作树代跑或信未读脚本。
3. 仅独立跑原driver **一个**正常受控场景 `--select=adversarial-batch`：私有HOME无.bun/bin/pi、调用者PATH有Pi、unset P442_PI，记录实际Pi路径/版本、session/event/provider请求与结果，确认不是假通过。再用显式P442_PI的原短命错误输入检查真实退出码和错误立即暴露；不要重新跑20场景或7场景整组，不用真实外网模型。
4. 实际调用共享main_team_violations重放四组原件；另两组只核完整输出/未变调用并写明不能重放。复用原短污染反例和现有 `bash skills/teamsmith/tests/isolation-ledger.sh`：单个运行记录可动，任意旁文件、locator、reminders、Standby的新增/修改仍红；不能排除整个目录。
5. `bash -n`适用shell、`node --check`driver，当前OpenSpec1.16 `validate --all`、spec-refs、section-select、自己的报告暂存后ledger-ban/diff-check。不跑全量、FAST全量、61b/meta/夜间/性能/安装三路线，也不再跑10/10b/39/67–69整段。

把上述实际短命令放入runner，通过该runner运行正式review，不允许调用默认完整TEAM_GATES：

```bash
# 从自己的verify工作树发起；C为上面的独立检出，E为自己的精确临时根
TEAM_GATES="bash $E/verify-short.sh" bash "$C/skills/teamsmith/scripts/team" review P459 --dir "$C" --branch "$(git -C "$C" rev-parse HEAD)"
```

只授权此工具写主检出 `docs/team/reviews/P459.md` 和 `docs/team/reviews/P459-verify.log` 及既有运行账目；不手改主检出、不碰其他记录。实际执行者必须是verify，PM只是准备/接受，不用no-gates的SKIPPED代PASS。不重复跑runner一次再让review再跑一次。较慢命令后台启动即结束回合，完成后收割。

报告先给结论、实际命令/结果、原件核对、CRITICAL/WARNING/SUGGESTION及Final assessment；明确原组合证据与自己这次执行的范围。若全部适用证据通过，提交报告并通知PM；不要合并或关P459。

## 阶段B · 等PM合并后同一会话续验

PM另给固定merged SHA和干净检出，再核5文件与已验候选同一性，只重跑适用短入口/分类边界和结构检查；若字节相同不重复Pi集成、安装或全部反例。中央记录绑定新SHA，报告保留两阶段证据及警告。当前还没有merged输入，不得先称阶段B通过。
