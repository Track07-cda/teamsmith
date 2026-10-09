# V19 · 任务模型路由：S1 私有候选独立复验

task: V19
agent: dev3
phase: verify
category: verify
change: task-model-routing
specs: dispatch, memory-and-deps, agent-adapters, pm-lifecycle, watchdog
deltas: -
branch: task/V19-task-model-routing-s1-verify
deps: P228 S1 candidate 16842c9ddf6f83db0e43f4fdbcfb2a4cc5170c74; E14 accepted proposal

## 范围与调度

用户已批准隔离实现与独立验证。你未参与该 change 的提案或实现。只复验 P228 的 S1 私有候选，不验证尚未实施的 S2 panel、S3 初始化/指南，不把局部通过说成整个 change 已通过。任务排在 E16 正式提案之后：由 PM 释放当前强模型名额后显式强模型、fresh 派单，不超并发、不自行启动。

阅读 AGENTS、自己的最新线程、本 brief、OWNERSHIP、D104–D106；再读接受的 task-model-routing proposal/design/tasks、七份 delta 与对应 canonical specs、P228 brief/完整报告/冻结清单。历史线程的 E12/P158 命令不属于本任务。原生 OpenSpec 1.8.0 没有 verify workflow，按本仓 openspec reference 的独立验证流程执行，不安装或生成工具。

## 被检树与控制面

自己长期 worktree 只写报告，不加载候选为实际运行的共享技能。PM 准备的仓外独立真实 clone 为 `pm-skills-ledger/team/reviews/V19/checkout`，检出完整候选 `16842c9ddf6f83db0e43f4fdbcfb2a4cc5170c74`。由主检出的 git common directory 解析路径：

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
CANDIDATE="$CONTROL_ROOT/../pm-skills-ledger/team/reviews/V19/checkout"
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/V19-dev3"
```

先验证 CANDIDATE 的绝对路径、HEAD、`.git` 为真实目录、git status 干净，以及其产品/测试与作者受检 `017fbf9` 完全一致（最终差异只有报告）。错根或脏树先 BLOCKED，不修改来通过前置检查。被测 CLI 只能在显式隔离的 fixture repo/HOME/tmux socket 中运行，清除真实 TEAM 身份并在任何写盘前核对 fixture 根；不能在候选根或真实团队调用 config/dispatch/resume/up/close/teardown/init/bootstrap/watch。仅稳定主检出的 CLI 用于 notify pm；不读真实 Pi 历史、credential，不启动 provider。

## 独立检查

对照接受的 S1 tasks 1.1–5.3 与场景索引，自己读代码和 diff，不只复用作者的 PASS。重点审查：类别/整体策略与恢复删除类别的豁免边界、suffix/extras 与 SID、数据式完整 assignment、启动证明/nonce/原子提交、锁顺序和配额未知身份、close/teardown、配置 CAS/整个升级与审计失败、多个读者的中间态、PM 原模型恢复/启动失败回收，以及 SID A 不读 B/base。核对窄 cmd-review/close 授权，原有非模型断言不得被删/skip/弱化。

自己在稳定候选执行以下切片验收，日志全部另放 EVIDENCE，不将作者日志冒充独立结果。一个 gate 一次，长命令用 team_bg_run 并在结束前全部收割；检查 /tmp 容量，遵守全套锁。不要跑尚需 S2/S3 的全仓 smoke：完整集成后另有全量 verify。

```bash
df -h /tmp
# 从 CANDIDATE 执行；每条设置合理 timeout 并记录 rc
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/death-cause.sh --pure
bash skills/teamsmith/tests/death-cause.sh --live
bash skills/teamsmith/tests/death-cause.sh --flip
bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary
bash skills/teamsmith/tests/task-model-routing.sh --select flip
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
```

测试运行前后对 HEAD/status/source hash，树在跑动中变了则整轮无效。原源码不改；11 个破坏臂仅在自己的独立 scratch 副本执行，保留 matched/hash/具名 FAIL/rc/恢复逐字节控制。补至少一项自己设计的边界或竞态反例，不能仅转录作者 59/0。新测试脚本只存仓外，不替作者修产品/测试；发现失败保留精确复现，交回 PM。将原有真实故障、预期 mutant 红和新发现分开，不能把坏源码臂红误记为基线失败。

## 产物与写边界

只写自己的 `docs/team/reports/V19-dev3.md`，以及 EVIDENCE 下的独立日志/脚本/owned scratch。CANDIDATE 原树只读；不可写产品、canonical/change/tasks 勾选、Main 公共治理账本/评审或私有 integration clone，不合并/推送/归档/部署。最终正式 review 由 PM 据你的报告与自身复验写入；不把 report 假装成 PM verdict。

报告逐项映射场景→真实断言→命令/rc/原始证据，结论 PASS/FAIL/PARTIAL 限定 S1，列未测 S2/S3/真实 provider/共享采纳。包含受检完整 SHA、差异集审查、独立反例红绿和源稳定性检查；明确作者证据与自己的证据分离。每个可验证步骤提交 Conventional Commit，含 V19 与 `Agent: dev3`，报告已提交/自己树干净、所有 jobs 收割后通过稳定 CONTROL_ROOT CLI 通知 pm。不 mark P228 done，不用真实共享环境证明候选正确。
