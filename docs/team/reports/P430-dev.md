# P430 · route-page-check-determinism 样本实施

agent: dev   status: DONE（作者验收完成，待非作者独立复验）   time: 2026-11-09T03:57:31Z
branch: `task/P430-route-page-check-apply`   PR/MR: -

## 结论

已实施且仅实施旧④/⑪/⑬三项替代。最终非 FAST `routes.sh pages` 为 **✓7 ✗0**，包含 `替代④`、`替代⑪`、`替代⑬` 三条成功结果；改后真实 `walk control promises refusals` 为 **✓254 ✗0**，与改前规范化后的 255 条判定/计数记录逐项相同。两个共享判定反例分别使 `替代④`、`替代⑪` 变红，恢复后均回绿。

产品源码、正式规格、smoke、CI、配置及其他测试未改；完整 51m/flips、全量 smoke、36、61b 和公开 CI 未跑。任务 3.3 留给另一非作者，未勾选。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/lib/routes-pages.sh` | 从真实走查提取的共享 awk、续行解析、菜单/组/命令逐页判定与层级收尾；直接调用现有 `ok`/`finding` 并维护 `FIND`、已读页和返回状态 |
| `skills/teamsmith/tests/routes.sh` | 真实走查接回共享判定；新增同一脚本 `pages` 段；删除旧④/⑪/⑬完整 walk；非 FAST `mr_flips` 无条件调用同一 `pages` 入口并核对三个具名结果 |
| `skills/teamsmith/tests/section-paths.tsv` | 只在既有 51/51m 行登记共享 helper；既有段名和旧计数说明未改 |
| `openspec/changes/route-page-check-determinism/tasks.md` | 勾选 1.1–3.2；3.3 保持未勾选 |
| `docs/team/reports/P430-dev.md` | 本报告 |

实现提交：`de45d31a`；任务勾选提交：`cbc8893f`。

## 1 · 改前证据与计数映射

### 1.1 运行边界

改前基线为 `962e97e9c5f4498546106074054656c777c396d4`，候选实现为 `de45d31a983cd7669ef0296422d7aaacf0e7bb37`。容器镜像均为：

```
localhost/teamsmith-gate:local
fa756c126b701b2ca3fae88588799dca7414a57a609e52e729c25beaecec2d20
```

证据根为 `/var/tmp/P430-route-pages.Xukuyb`。容器产生的完整日志位于**宿主**该目录；相同相对路径的日志与现场也已同步到 distrobox 内，便于复核。实际执行配方完整保存在 `run-baseline.sh`、`run-after.sh`、`run-flips.sh`，容器内均使用 `/ev` 作为该证据根的 bind mount。

前两次容器启动分别在宿主证据目录缺失、工作树 `.git` 指针未挂载处停止，未进入 routes 测试；第三次起使用预先传入的提交号，以下结果均来自实际完成的运行。

### 1.2 正常真实走查：改前/改后同一命令、同一镜像

两次均执行：

```bash
bash skills/teamsmith/tests/routes.sh walk control promises refusals
```

结果与耗时：

| 运行 | 提交 | rc | ✓/✗/SKIP | 墙钟 |
|---|---|---:|---|---:|
| 改前 | `962e97e9` | 0 | 254 / 0 / 0 | 103 s |
| 改后 | `de45d31a` | 0 | 254 / 0 / 0 | 102 s |

原始日志：`logs/baseline-normal.log`、`logs/after-normal.log`；元数据：`logs/baseline-meta.log`、`logs/after-meta.log`。

比较不是只读总 PASS。规范化仅去除 ANSI、临时路径、附带的命令输出说明及运行时刻，保留页面标签、命令/旗标身份、rc、判定和总计：

```
$ diff -u logs/baseline-normal.canonical-inventory logs/after-normal.canonical-inventory
# 空，rc=0
baseline_lines=255 after_lines=255
page_identities=56 claim_identities=106
```

清单文件：`logs/{baseline,after}-normal.canonical-inventory`；空差异：`logs/normal-canonical-inventory.diff`。因此真实菜单/组/命令页、CLI CLAIM、control/promises/refusals 的规范化身份与结果没有因提取而改变。

### 1.3 只手工复现旧⑪一次；④/⑬不重跑

按 design 配方复制 pristine `teamsmith`/`teamsmith-init`，只改 scratch renderer。落地证明：

```
anchor_count_before=1
injected_line_count_after=1
routes_cmp_rc=0
559:  [ "$name" != "dispatch" ] || team_help_flow 2 4 "dispatch --ghost-probe"
```

`routes_cmp_rc=0` 是改前/副本 `routes.sh` 逐字节相同，没有修改测试源码、增加 baseline 选择器或运行旧④/⑬。旧⑪实际结果：

```
$ bash skills/teamsmith/tests/routes.sh walk   # scratch 树、非 FAST、同一镜像
rc=1 wall_seconds=38
✗ walk: dispatch 的页与清单不一致（页上多出：dispatch --ghost-probe；页上缺少：无）
difference_lines=1 complete_usage_lines=1
```

证据：`logs/old-11-mutation.log`、`logs/old-11.log`、`logs/old-11.rc`、`logs/old-11-difference.log`、`logs/old-11-complete-usage.log`。

旧父级断言只按基线源码归属，各 1 条，不把嵌套 walk 日志加进父级：

| 旧父级 | 基线位置 | 改前证据 | 新结果 |
|---|---|---|---|
| ④ | `routes.sh:1779` | **source-attributed, not rerun** | `替代④`，列 0 归属 finding + 正常 board 无 finding |
| ⑪ | `routes.sh:1923` | 本次唯一旧臂复现，rc=1，38 s | `替代⑪`，集合差“页上多出” + 正常 dispatch 无 finding |
| ⑬ | `routes.sh:1942` | **source-attributed, not rerun** | `替代⑬`，缺 group 为唯一 finding，恢复后无 finding |

源码摘录与候选删除核对在 `logs/deletion-and-call-sites.log`。

P428 的历史非 FAST 记录单独保留：公开夜间 `2026-11-07T10-42-26Z.log` 的 51m 整段 **512 s、18 条通过、1 条可见跳过**，没有逐臂日志或耗时（`docs/team/reports/P428-dev2.md` §1/§2）。它没有与上述父级、嵌套 walk 或新样本计数相加。

## 2 · 实现与旧路径删除

### 2.1 一份共享判定，真实走查同 shell 接回

`mr_write_parser`、`mr_page_usage`、完整逐页比较/归属/记账和 `mr_level_finish` 均在 `tests/lib/routes-pages.sh`。真实 `mr_walk_a` 的两个调用点不是命令替换或管道子 shell：

```bash
mr_page_judge "$kind" "$label" "$page" || failed=1
mr_level_finish || failed=1
```

共享操作自身调用 `ok`/`finding`，递增 `FIND`，并维护实际非空已读页、`n_pages/n_entries/n_claims` 与 `LEVEL_OK`。空文件不进入已读状态。两个真实走查调用点的失败传播已按源码复核；本样本**没有**声称用廉价文件用例行为证明了受损真实 walk 的两个调用点，这仍是非作者复验边界。

### 2.2 `pages` 的真实执行清单

最终候选在同一固定镜像执行：

```bash
bash skills/teamsmith/tests/routes.sh pages
# rc=0，wall=3 s
== 结果 ==  ✓ 7  ✗ 0  SKIP 0
```

七条实际成功结果为：替代④、替代⑪、续行、重复多重集、缺失集合差、替代⑬、空文件不计已读。原始输出：`logs/final-pages.log`；四次渲染：`final-pages-artifacts/renders.log`；逐用例子进程日志：`final-pages-artifacts/page-samples/`。

四次且仅四次真实 renderer 调用均 rc=0、非空：

| 来源 | 命令 | rc | bytes |
|---|---|---:|---:|
| ④受损 scratch | `team help board` | 0 | 1604 |
| 未变异树 | `team help board` | 0 | 1575 |
| ⑪受损 scratch | `team help dispatch` | 0 | 3243 |
| 未变异树 | `team help dispatch` | 0 | 3218 |

④受损页实际有 2 条 finding，实现只要求正确归属诊断，**没有断言 FIND==1**：

```
✗ walk: board 的页与清单不一致（…）
✗ walk: command board 的第 4 行无法归属…命令块里列 0 的行带着旗标（无法归属到任何条目）：board add <ID> [--allow-dup]
SAMPLE_STATE pages=1 … findings=2 failed=1
```

⑪必须有集合差，不接受只有特殊字面量：

```
✗ walk: dispatch 的页与清单不一致（页上多出：dispatch --ghost-probe；页上缺少：无）
```

⑬主见证中菜单和 dispatch 文件各自通过，已经生成但未提供给子进程的 group 文件不算已读；缺 group 是唯一 finding。恢复实际 group 文件后三页均通过、无 finding：

```
# missing
SAMPLE_STATE pages=2 menu=1 group=0 command=1 findings=1 failed=1
✗ walk: group 这一级一条都没被判到（静默漏读）
# restored
SAMPLE_STATE pages=3 menu=1 group=1 command=1 findings=0 failed=0
```

独立空文件见证为 `帮助面缺一页`，且 `pages=0 command=0`，没有替代⑬主见证。

### 2.3 退休与父级接入

候选中 `flip-unattributable`、`flip-page-ghost`、`flip-level-unread` 均为 0 命中；旧⑬整树复制、group 清单改写和完整 walk 一并删除。没有夜间、FAST/full 或备用入口保留这三条 walk。其余四条 `mr_flip_run "$s" walk…` 属于未改的①②③⑩。

`mr_page_samples` 函数体内 `mr_flip_run`、`mr_walk_a`、`new_fixture`、`mr_probe_claim`、完整 `mr_pages` 调用均为 0 命中；运行现场只有上述四次单页渲染，没有完整 walk、项目初始化或全清单 CLI 循环。

非 FAST `mr_flips` 在既有 `mr_flip_run` 嵌套身份/日志/临时根机制中无条件执行一次：

```bash
mr_flip_run "$tree" pages
```

随后同时要求 child rc=0 和三个不同的成功行 `替代④/⑪/⑬`；缺 helper、命令、用例或非零 child 都进入 finding，不存在按存在性跳过。按任务边界未运行完整 `mr_flips`，此接入由源码与 `logs/deletion-and-call-sites.log` 核对。

## 3 · 两个共享判定的红侧与恢复

两棵隔离副本都只改 `routes-pages.sh`，运行与验收完全相同的 `routes.sh pages`。精确变异记录在 `logs/flip-attribution-mutation.log`、`logs/flip-multiset-mutation.log`，父日志与逐页现场在 `logs/flip-*.log`、`flip-artifacts/`。

| 变异 | 预期红 | 实际 rc/汇总 | 关键证据 | 恢复后 |
|---|---|---|---|---|
| 将列 0 的 `fail(...)` 改为空块 | 替代④ | rc=1；✓6 ✗2 | `替代④没有兑现`；受损 board 不再有 `列 0 的行`；替代⑪/⑬仍绿 | rc=0；✓7 ✗0 |
| 只删除集合差 `finding`，保留特殊旗标 finding | 替代⑪ | rc=1；✓4 ✗4 | `替代⑪没有兑现`；仍有 `打印了清单没有的旗标（dispatch --ghost-probe）`，但无 `页与清单不一致` | rc=0；✓7 ✗0 |

第二棵树的额外两条红来自同一被删除的集合差规则所覆盖的重复/缺失文件用例，不是加载、语法或 renderer 失败。两棵受损树中的正常 board 与正常 dispatch 子进程均为 `findings=0 failed=0`，证明正常输入仍绿。恢复后 helper 与候选逐字节 `cmp` 相同，再跑同一命令回绿。

```
run=flip-attribution rc=1 wall_seconds=3
run=flip-attribution-restored rc=0 wall_seconds=4
run=flip-multiset rc=1 wall_seconds=3
run=flip-multiset-restored rc=0 wall_seconds=3
```

## 4 · 验收命令实跑

以下结构检查在最终实现的 worktree 中执行；完整输出在 `logs/acceptance-*.log`。

```
$ bash -n skills/teamsmith/tests/routes.sh
rc=0
$ bash -n skills/teamsmith/tests/lib/routes-pages.sh
rc=0
$ bash skills/teamsmith/tests/routes.sh pages
== 结果 == ✓ 7 ✗ 0 SKIP 0；固定容器 rc=0（见 logs/final-pages.log）
$ bash skills/teamsmith/tests/routes.sh walk control promises refusals
== 结果 == ✓ 254 ✗ 0 SKIP 0；固定容器 rc=0（见 logs/after-normal.log）
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 121 reference(s) (49 distinct) … retired 0; undeclared 0
rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 == ok 13 bad 0 SKIP 1
rc=0
$ openspec validate --all
Totals: 22 passed, 0 failed (22 items)
rc=0（长需求等既有 warning 未改，本任务未声称 strict）
$ git diff --check
rc=0
```

Ledger ban 在本 worktree、本分支树执行，报告写入后重跑：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=… scope=published files=2459 hits=0 names=ok user=resolved
rc=0
```

## 5 · 执行量、耗时与未跑范围

- 基线 manifest 为 47 命令 + 8 组：旧④/⑪各渲染 56 页，旧⑬渲染 48 页，结构上为 `56+56+48=160` 次 help；新样本含正常对照共 4 次，结构减少 156 次。该算术只描述当前 manifest，不换算秒数。
- 实测：旧⑪单臂 38 s；改前/改后完整正常产品路径 103/102 s；新完整 `pages` 样本 3 s（包含四次 renderer、全部文件用例和 scratch 准备）。
- 旧④/⑬没有本轮运行，旧三臂合计耗时与节省时间**不可测**；历史 51m 整段 512 s 不能当作三臂耗时。性能不作通过条件。
- 未跑：全量 smoke、完整 51m/flips 矩阵、36、61b、公开 CI；未跑旧④/⑬；未做真实 walk 受损时两个调用点的行为试验（只按要求做源码审查）。
- 未合并、未归档、未发布、未 push；本任务分支仅本地交付。

## Decisions and deviations

无范围偏离。④保留集合差与列 0 归属两条真实 finding，没有误加“唯一 finding”限制。容器初次启动的两次环境错误没有产生测试结果，成功证据均来自后续完整运行。

## Suggested next steps

由另一非作者执行任务 3.3：独立重复同一 `pages`、两个诊断特异性反例和真实产品路径，复核三条退休、父级具名结果检查及两个 same-shell `failed=1` 调用点。作者验收不替代独立复验。
