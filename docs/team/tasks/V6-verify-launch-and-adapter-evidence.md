# V6 · Verify: `launch-and-adapter-evidence`（规格补账的独立验证）

```
task:   V6
agent:  verify
phase:  verify
change: launch-and-adapter-evidence
deps:   P4（apply，tip 08fa207，分支 task/P4-apply-launch-and-adapter-evi；PM 已复验 PASS）
```

> 这是一次**补账**验证：变更不引入新行为，所以全量测试前后都绿——测试抓不住它的错。E2/D18 定下的
> 三层攻击面就是你的任务书。你是独立验证者：没探索、没提案、没实现过这个 change。

## 三层验证（按序）

1. **适用性**：`openspec validate --all --strict` 与 `spec-lint.sh` 绿；在 **scratch 副本**上跑
   `openspec archive -y launch-and-adapter-evidence`，必须恰好做出承诺的操作（`agent-adapters` 与
   `pm-lifecycle` 创建；dispatch +2/~3/−1；其余规格除归档器自己的空行规整外逐字节不变）；归档后的
   dispatch 不得再含被移除的需求，两个新 capability 必须含各自的全部需求。
2. **迁移 diff（本 change 特有、最强的检查）**：用 `git show <base>:openspec/specs/dispatch/spec.md` 取搬迁前的
   引擎需求，从 scratch 归档后的 `openspec/specs/agent-adapters/spec.md` 取搬迁后的，逐字节比对：
   只允许**声明过的**增量（PM 侧等价、首词解析、新场景），base 的四条场景必须逐字幸存。
   另外钉死 F3 那处"唯一被允许的改写"：`40-migration` 夹具只放行那一处场景文本变化，多了任何东西都是 finding。
3. **可证伪性注入**：从 delta 里随机抽 5 条场景，**亲手破坏实现**（在 scratch 树上改掉对应行为）让对应的
   证伪器命令真的红；任何一条场景破坏后套件仍绿 = 该场景是空话，记 finding。特别攻击 F2 的新断言
   （"不带 --print 的拒绝发生在开窗之前"——破坏 tmux shim 的计数断言看它红不红）与 F6 的新计数口径
   （造一个只加 delta 不改 base 的树，断言应绿；再破坏 sl_scope_files 使它漏数 delta，断言应红）。

## 另请独立裁决一个交付诚实性问题

P4 的第一次"完成"交付在我（PM）的独立门禁上是 FAIL（F6 红两条），而它自己的报告把同一个 FAIL 当成
"既有问题"记录后继续宣称完成。检查它的两轮报告与门禁日志（`docs/team/reports/P4-dev.md`、
`reviews/P4-verify.log`），独立评估：第一轮交付是否构成"没跑门禁就说跑过"，并在你的报告里单独一节
写明结论与依据（这件事决定它以后的报告可信度权重）。

## 输出

- `team review V6 --dir <checkout> --strong`（checkout 用 08fa207；PM 已备好 /tmp/verify-P4，也可自建）
- `docs/team/reports/V6-verify.md`：三层各自的命令与输出、迁移 diff 的完整文本、注入实验结果、
  诚实性裁决、你**无法确定**的事项清单。

## 边界

- 只读交付分支；探针全在 scratch 副本；不改 `openspec/**` 与账本；不 push main；不修你发现的缺陷（报告即可）。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
```
