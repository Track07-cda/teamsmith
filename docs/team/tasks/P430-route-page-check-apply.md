---
id: P430
title: route-page-check-determinism 样本实施
agent: dev
category: code
phase: opsx-apply
change: route-page-check-determinism
specs: dispatch verification
anchor: openspec/changes/route-page-check-determinism/proposal.md
deltas: dispatch, verification
branch: task/P430-route-page-check-apply
---

# P430 · 只实施已接受的三项替代

## 唯一依据

完整阅读 `openspec/changes/route-page-check-determinism/` 的 proposal/design/tasks/两个 delta，以及 `docs/team/reviews/route-page-check-determinism-proposal.md`、V131 报告。候选提案已在 main；不要重新设计或扩大样本。

你没有参与 P428/P429。本任务执行 tasks 1.1–3.2；**3.3 是另一非作者的独立复验，不由你完成或勾选。**

## 实施范围

只允许：

- `skills/teamsmith/tests/routes.sh`（含 `pages` 段、三条旧臂退休和头部旧描述）；
- `skills/teamsmith/tests/lib/routes-pages.sh`（共享判定）；
- `skills/teamsmith/tests/section-paths.tsv` 既有 51/51m 登记；
- 本任务报告与必要的任务勾选。

不改产品帮助实现、正式规格、smoke、CI、配置、其它测试或文档。不为本任务新增脚本入口、框架、产品开关或删除 policing guard。

## 必做行为

1. **改前证据先行。** 按 design 的配方只手工复现旧⑪一次：复制 pristine 树，只改 scratch renderer，测试源码 `cmp` 相同；旧 `routes.sh walk` 必须 rc=1 且集合差诊断含 `dispatch`、完整 `dispatch --ghost-probe`。④/⑬只按源码父级断言归属，不重跑。保存磁盘日志，不制造 baseline-only 测试或选择器。
2. 提取菜单/组/命令完整逐页判定、层级判定、解析、比较、`ok`/`finding`/`FIND` 与状态到同一 helper；真实 `mr_walk_a` 在当前 shell 调用，保留两个调用点到 `failed=1` 的传播。负例子进程使用自己的计数，不污染父级。
3. 在同一 `routes.sh` 增加显式 `pages` 段，复用现有身份清理、临时根、shim、计数和清理。非 FAST `mr_flips` 无条件调用它一次，检查 rc=0 与至少 `替代④/⑪/⑬` 三条成功结果；缺命令、helper 或用例必须失败，不可跳过。验收使用完全相同命令。
4. ④、⑪保留原 renderer 变异与落地证明；受损页和**未变异树**正常页各渲染一次，四次均 rc=0 且非空。④要求列 0 归属诊断，但**不得断言 FIND==1**；⑪必须来自集合差“页与清单不一致/页上多出”，特例字面量不算。正常结果不得有 finding。
5. ⑬只用文件输入：菜单/命令页各自通过，缺 group 是唯一 finding；恢复 group 后无 finding。空文件另证原缺页行为且不算已读，不拿它替代主见证。
6. 删除三条旧完整 `walk`，⑬的整树复制和清单改写一并删除；不得保留夜间、fast/full 或备用路径。其它真实 CLI、Pi、tmux、进程和窗口测试不动。
7. 两个共享判定反向改坏：跳过列 0 归属必须让替代④红；删除集合差但保留特例字面量必须让替代⑪红。正常输入保持绿，恢复后同一 `pages` 命令回绿。

## 验收命令

在实际实现后运行并保留完整磁盘日志：

```bash
bash -n skills/teamsmith/tests/routes.sh
bash -n skills/teamsmith/tests/lib/routes-pages.sh
bash skills/teamsmith/tests/routes.sh pages
bash skills/teamsmith/tests/routes.sh walk control promises refusals
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
openspec validate --all
bash skills/teamsmith/tests/ledger-ban.sh --names-file <主检出名单>
git diff --check
```

- 正常真实走查在改前/改后各跑一次，比较逐页、用法、CLAIM 身份、判定和计数，不只比较总 PASS。
- 容器需要时使用 `distrobox-host-exec podman`，不要直接调用 podman；日志必须落宿主机 `/var/tmp` 的本次专属目录。若固定镜像无法执行，明确 PARTIAL，不把宿主替代说成镜像证据。
- 记录实际执行量与耗时，但旧三臂总节省不可测就明说；结构数不冒充秒数，性能不作门禁。

## 交付与边界

小步提交；`docs/team/reports/P430-dev.md` 先给结论，附真实命令、日志路径、旧路径删除点、计数映射、两类红侧和未跑范围。通知 PM 后由另一非作者独立复验。

**不跑**全量 smoke、完整 51m/flips、36、61b 或公开 CI；不合并、不归档、不发布、不推 main。
