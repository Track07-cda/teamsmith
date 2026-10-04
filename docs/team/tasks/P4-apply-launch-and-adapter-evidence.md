# P4 · Apply: `launch-and-adapter-evidence` (C1 补账)

```
task:   P4
agent:  dev
phase:  apply
change: launch-and-adapter-evidence
deps:   P3 proposal ACCEPTED (docs/team/reviews/launch-and-adapter-evidence-proposal.md); D18 (E2 探索已接受)
note:   原审查条件"C0 检查器先进 main"已被 D23 取代——C0 已撤销，delta 名字类错误由"试归档"流程在归档前兜住，
        本任务不再依赖任何自定义 delta 检查。
```

## 要做什么

按 `openspec/changes/launch-and-adapter-evidence/tasks.md` 的顺序执行（那是一个 change、一个 apply、顺序子任务——
D18 的绑定条件）：dispatch 的三条 delta → 新 capability `agent-adapters` → 新 capability `pm-lifecycle` → 证据（4.1–4.4）。

## 绑定条件（P3 审查 + D18，全部生效）

1. 文档授权：只许为 tasks 4.x 动 `skills/teamsmith/references/openspec.md`；`references/` 其余不动。
2. **`openspec/specs/**` 一个字不许改**（那是 archive 阶段的活）。
3. 三条门禁全绿：`openspec validate --all --strict`、`bash skills/teamsmith/tests/spec-lint.sh`、
   `bash skills/teamsmith/tests/smoke.sh`。
4. 每条需求都有今天就可跑的证伪器（E2 §5 的表）；每条场景点名"哪条命令会失败"。
5. 发现实现与 delta 不一致（例如某个行为的真相和场景描述不符）→ 报告为 finding，不许悄悄改场景去迁就。

## 边界

- 你的文件：`openspec/changes/launch-and-adapter-evidence/**`、`skills/teamsmith/references/openspec.md`（授权范围内）、
  你的报告 `docs/team/reports/P4-dev.md`。
- 不动代码、不动 smoke、不动账本；不 dispatch、不 archive、不 push main。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
git status --porcelain   # 只有 change 目录 + openspec.md 那段 + 你的报告
```

## 报告要点

每条需求的"需求 → 场景 → 证伪器命令"映射表；trial-archive 在 scratch 副本上的结果；任何你发现
"场景描述与现实不符"的地方（这类发现是这次补账的主要价值）。
