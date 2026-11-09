---
id: P439
title: delegate-openspec-archive 默认规则实施
agent: dev3
category: code
phase: opsx-apply
change: delegate-openspec-archive
specs: verification
anchor: openspec/changes/delegate-openspec-archive/proposal.md
deltas: verification
branch: task/P439-delegate-archive-apply
---

# P439 · 落地 teamsmith 默认 verify/archive 委派

## 唯一依据

完整阅读 `openspec/changes/delegate-openspec-archive/` 全部规划、`docs/team/reviews/delegate-openspec-archive-proposal.md` 与 V142 报告。提案已接受，不重新设计。

你未参与提案。执行 tasks 1.1–3.2；**3.3 由另一非作者独立复验，不由你完成或勾选。**

## 范围

按 proposal/design 修改十二份指引、`templates/report.md.tmpl`、`scripts/lib/cmd-review.sh`、既有 smoke 10/10b/19/12j 与 `section-paths.tsv` 的实际登记，以及本任务报告。不得新增门禁段、流程引擎、配置键、永久席位或状态文件。

不改 P438 的回复捕获文件，不做当前两个变更的真实归档，不修改它们的 Purpose；本 change 自己的 Purpose 只能在后续归档席位明确授权后单独提交。

## 必须落地

1. verify/archive 及门禁由非实现者执行；PM 可准备 detached checkout、审阅和合并，但不以自己的后台门禁替代委派。
2. `team review` 的指定主检出 record/log 是窄例外；生成记录写真实运行时席位身份，不写死 PM。verify 任务自身文件是 PM acceptance，链接实现 ID 的执行记录、verifier 报告和 merged SHA。
3. 同一 verifier 在 PM 合并后绑定 merged SHA 复验，done/archive 只在接受通过后。修正三处 merged-tree 旧句。
4. 报告模板使用 OpenSpec 固定 CRITICAL/WARNING/SUGGESTION/Final assessment，不另造分类。
5. 归档 brief 字面 `phase: archive`；自身 blocker 只认同 ID+该值，其他 blocker 照阻断。保留限定 PM-proxy；trial 用 `/var/tmp` 私有目录；依赖归档串行。
6. 十二文件54命中逐项按 design CHANGE/KEEP 落实，包括 memory-seed、troubleshooting、README、init、§E2 与命令表；不得留下相反默认口径。
7. 用既有断言替换弱检查：真实 verifier 运行记录不写 PM；恢复 PM verify/archive 指令必须红；缺 post-merge owner、缺 CRITICAL 前置或错误自身 phase 必须红。保持正常/恢复对照，不新增另一层自检。

## 验收

按实际改动补充选段，至少：

```bash
bash skills/teamsmith/tests/smoke.sh --select 10,10b,19,12j </dev/null
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
openspec validate --all
openspec validate delegate-openspec-archive --type change --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

`openspec validate --all --strict` 的既有20项失败要原样记录，不得声称全绿。只跑受影响选段，不跑全量/夜间/61b。所有变异在自己的副本进行，保留红/绿/还原日志。

## 交付

小步提交，`docs/team/reports/P439-dev3.md` 先给结论，附真实命令、日志、十二文件映射、执行者记录样例和未跑范围。通知 PM 后由另一非作者复验。不合并、不归档、不发布、不推 main。

## V144 阶段 A 的最小返修（只修 W1/S1）

- `templates/DECISIONS.md.tmpl` 仍把复验执行写给 PM，会被 `team init` 渲染进每个新项目。改成 verifier 执行、PM 审阅接受；把该文件纳入 design/proposal/tasks 的清单与第19段既有断言，不加新段。
- `workflows.md` 与 `openspec.md` 的自身 blocker 说明改为：brief 必须写字面 `phase: archive` 使行读作 archive；工具按任务 ID 排除自身。不得暗示工具按 phase 文本匹配。
- 仅改这两类及相应规划计数/报告；其他已验内容不动。完成后通知 V144 做定点复核，再进入合并后阶段。
