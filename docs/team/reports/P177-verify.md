# P177 · product-checkout-gate 换人复验

## 结论

**FAIL；交付为 PARTIAL，归档被阻塞。** 所有任务书指定命令已经实际执行。P173 的归属修正和 P176 的 **§58 门禁归属**均有独立正反向证据，但当前两棵树 FAST 都有一条真实红；另有任务书与 standalone signal-lint 行为不一致，不能报通过。

只修改本报告及 `docs/team/reports/P177-verify/**`，没有修改实现、任务书或 OpenSpec。local 模式不 push，不合并、不归档。

## 验证对象与隔离

- 被验提交：`5a8ef970`，含 P173、P176，也已含 P180 的 wrapper 迁移。
- P148 前内部基线：`d52f367e`。实际复跑基线，不复用 implementer 的结果。
- 内部树：从本 worktree 独立 clone，detach 到被验提交。
- 产品树：实际运行 `bash docs/team/tools/publish-public.sh --rev 5a8ef970 --out <pkg/.scratch/product>`；不是手工删账本模拟导出。
- 三次 FAST 串行运行于 `localhost/teamsmith-gate:local` 的一次性容器；没有挂载宿主 tmux socket，不对共享 server 做探针。变异只改容器 `/tmp` 内的自己的副本；植入的 tmux / signal 调用仅供静态扫描，未执行。
- revision 完整 SHA、镜像 ID 与工具版本分别在 `pkg/logs/revisions.txt`、`image.txt`、`tools.txt`。

以下 `pkg/` 均指 `docs/team/reports/P177-verify/pkg/`。全部原始 stdout/stderr、每条命令的真实 rc 已提交。

## 指定门禁：原始结果

容器内命令：

```sh
openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```

| 检出 | OpenSpec | FAST rc | 段数 | ✓ | ✗ | SKIP |
|---|---|---:|---:|---:|---:|---:|
| 内部 `5a8ef970` | 22 passed, 0 failed | **1** | 123 | 3643 | **1** | 36 |
| 真实产品导出 | 13 passed, 0 failed | **1** | 123 | 3620 | **1** | 78 |
| 内部基线 `d52f367e` | 本次未另跑其 OpenSpec | 0 | 121 | 3475 | 0 | 36 |

两棵被验树的唯一红完全相同：

```text
✗ 36⑧ 产品面检出探针有失败（1 条）
    bad: ⑨ 牙齿一的前提不在：树里的 smoke.sh 没有 P162 的 tmux() 包装，这条牙齿会因别的原因通过
```

内部输出尾部：

```text
账本自查： 123 段收口 · 增量 ✓3643 ✗1 SKIP36 ｜ 结果行 ✓3643 ✗1 —— 一致
== 结果 ==  ✓ 3643  ✗ 1
smoke 有失败项（--keep 保留现场）
```

产品输出尾部：

```text
== 结果 ==  ✓ 3620  ✗ 1
检出前提 SKIP（条件不满足）：42 条 —— 产品面检出里刻意缺失的内部开发面（跳过不是通过）
smoke 有失败项（--keep 保留现场）
```

原始文件：`internal-fast.log/.rc`、`product-fast.log/.rc`、`baseline-fast.log/.rc`、`validate.log/.rc`、`public-validate.log/.rc`。没有把机器慢、超实测带或 FAST 跳过解释成这条红的原因。

## Flip evidence：P173 / 原 F1

独立植入 `tmp-hygiene.sh` 的裸 `tmux kill-server`；独立修改 lint 的归属规则，不使用产品自己的 checkout-shape-probe 判定这一用例。

| 独立用例 | lint / §31 的实际结果 |
|---|---|
| 原产品树 + 裸调用 | lint rc=1，`RED skills/teamsmith/tests/tmp-hygiene.sh:1188`；§31 rc=1，真树未隔离调用断言红 |
| 上例把归属改回同目录互认 | lint **rc=0**；§31 **仍 rc=1**，这次红的是 lint 自测，不是植入调用 |
| 明确含 smoke.sh 的 P162 wrapper 的副本 + 裸调用 | lint rc=1；§31 rc=1，仍点名 tmp-hygiene.sh |
| 上例改回同目录互认 | lint **rc=0**；§31 **rc=1**，自测捕获规则回退，真树调用被错误记绿 |
| 恢复未植入产品树 | §31 rc=0，✓30 ✗0；清单内部前提可见 SKIP |

含 P162 wrapper 的副本从 `baafe7e5`（P180 父提交）提取原函数，放在现代 guard installer **之前**；现代 installer 随后覆盖函数，执行面的隔离仍用当前实现。这一副本只是补齐任务书明确要求的静态前提，**不是**宣称当前原树仍有该定义。提取内容见 `p162-wrapper.txt`，生成方式在 `mutate.py`。

反向约束也实际测试了：

- 向 `smoke.sh` 自己追加调用，lint rc=0。
- 一个只有同文件 `tmux()` isolation wrapper 与调用的最小主题，rc=0；把 `wrapper_iso` 整体禁用后，**rc=1**，RED 点名该主题；因此不能靠删除所有 wrapper 认可机制满足测试。
- 影子 §31 是红的，不能拿其整体 rc 错说“真树仍拒绝”。`--list` 单独跑出的 1→0 才证明假绿发生在归属规则。

证据：`f1-*.log/.rc`。**P173 的归属修正有效；当前 §36 的前提检查已过时。**

## Flip evidence：P176 / 原 F2

产品树上 **§58 正常入口**：

```text
SKIP（条件不满足） 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（豁免清单） —— 产品面检出：内部开发面前提 docs/team/reports/** 不存在（跳过不是通过）
== 选段结果 ==  ✓ 367  ✗ 0
```

`--select 58` rc=0，内部面豁免前提跳过，lint 的其余判断、自测仍实际执行。

独立反向和影子：

| 用例 | 实际结果 |
|---|---|
| 冻结清单添加合法行，指向不存在的 `skills/teamsmith/scripts/p177-missing-product.sh` | §58 rc=1，点名产品路径；✓366 ✗1，不能享受内部前提归属 |
| 上例把 per-entry 归属放宽为所有缺失条目 | §58 **rc=0**，✓367 ✗0，假绿成立 |
| 产品文件植入 name-selected signal 调用 | §58 rc=1，真树断言红，内部清单 SKIP 不吞产品红 |
| 未变异的导出树恢复 | §58 rc=0 |

证据：`f2-missing-section.*`、`f2-shadow-section.*`、`f2-plant-section.*`、`f2-restored.*`。

但任务书第 2 条要求的 **直接命令**也原样执行了：

```sh
perl skills/teamsmith/tests/signal-lint.pl
```

产品树 rc=**1**，无 SKIP，原始输出为：

```text
✗ signal-lint: baseline —— docs/team/reports/M35-dev2/pkg/lib.sh：清单里的文件不在了（删文件就同时删豁免行）
signal-lint：豁免清单过期（1 个问题；扫描 89 个脚本）
```

同一命令在内部树 rc=0。P176 把归属实现在 smoke 的 §58，不在 standalone Perl 入口。因此**不能用 §58 的绿代替任务书所写的 standalone 绿**。直接命令加缺失产品行时 rc=1、点名两个路径，但原未变异导出树已经红，直接命令没有任务书要求的有效绿基线。证据：`direct-signal-public.*`、`direct-signal-internal.*`、`f2-missing-direct.*`。

## P148 其余约束：已测与限制

- **逐段覆盖**：`section-comparison.tsv` 逐一比较 121 个基线段；当前每段通过数都至少等于基线，没有新增内部检出前提 SKIP。当前增加到 123 段。
- **不能用总数遮住旧断言消失**：故意把内部 §18 的 `扫描根存在（SCOPE.md）` 换成 prerequisite skip。运行 rc 仍是 0，但 §18 从 ✓36 降到 ✓35、SKIP0→1；独立逐段比较抓到了下降，静态 inventory 比较也 rc=1、点名丢失标签与调用点减少。恢复原树 §18 ✓36、SKIP0。
- **静态全标签 comparison 本身不是全绿**：基线到当前 rc=1，缺两条旧 §0h 标签（`tmux() 包装体里看得见 tmux_iso_require`、`包装体里看得见私有 socket 形态`）。P180 将这两条 smoke-body 钉子换为共享 wrapper/argv 探针。通过数没有减少，但严格“每个旧标签原样保留”的证据不成立，不能谎报完整 inventory PASS。见 `static-compare.log` 与 `p180-smoke-change.diff`。
- **计数独立校验**：Python 从 top-level 的 ✓/✗/SKIP 输出重新数每段，再核 closing、账本、结果行。三棵 FAST 的三层都一致；产品 78 个 SKIP=36 FAST +42 检出前提，没有把 SKIP 加进 ✓。记录在 `judgment.json` 与 `*.inventory.json`。
- **产品真失败与 SKIP 并存仍红**：删 `skill-load.mjs` → selector `--check` rc=1、点名文件；protocol.md 注入中文 → §18 rc=1、✓52 ✗4 SKIP1；两种产品失败没有被检出分类吞掉。
- **内部/partial 不能当产品跳过**：产品树创建空 `docs/team/` 后 §19 rc=1；内部树删除 `opsx-apply.md` 后 §19 rc=1、点名缺失命令。
- **工具缺失不是检出前提**：用私有 PATH 隐藏 perl；产品 §18 rc=1、`没有 perl：英文正文不变量无法检查`，不是内部面 SKIP。
- selector 两棵树 `--check` 及 `--verify-copies` 都 rc=0；产品选表缺内部 literal 的 skip 逐项输出。
- 原始两棵 FAST 中 §18、§19、§36 的其他检查实际运行；checkout probe 仅上述旧 wrapper 前提失败，其其他分类、继承身份、fixture 造账本、负控均未红。

## BLOCKED：由 PM 协调，不越界改实现

1. **tests owner（agent:dev，或 PM 明授的 apply agent）**修 `skills/teamsmith/tests/checkout-shape-probe.sh:400`：当前硬搜 `tmux() {  # P162` 已不反映 P180 后的结构。需保留跨文件归属对抗性，并在与运行入口一致的前提上判断，不能单纯删除这条前提检查。修后两棵 FAST 都要重跑。
2. **PM**处理 brief 第 2 条与 §58/standalone 入口的差异：若本意是 §58，需要正式更正任务书；若确实要求 standalone，则应派 apply 让直接入口满足合同并独立复验。verify 不擅自更改验收口径。
3. **PM + tests owner**处理 P180 造成的两个旧静态标签替换：确认新断言的覆盖等价并记录允许的合同/基线变更，或补齐仍有意义的既有检查。本报告不以增加总数为豁免。

## 复现、证据及未测范围

```sh
# 在 verify worktree 执行；长任务用 team_bg_run，实际用了两个并已 harvest。
bash docs/team/reports/P177-verify/pkg/run.sh </dev/null
# 保留 scratch 时可只重跑变异控制与计数判定：
bash docs/team/reports/P177-verify/pkg/run.sh --cases-only </dev/null
```

第一次完整采集约 4099 秒。第一次控制清单的自造行漏了注释 `#`，所以两条 F2 控制测到的是格式错误，而不是路径归属；同时独立计数程序未把零断言的 helper 段 `15` 补为零行。**这两项是验证包自己的错误，不算产品 defect。** 修正后只重跑控制约 243 秒，rc=0；原始第一次输出保留在 `logs/first-controls/`，没有用错误的红支撑 F2 结论。最终 harness 的 rc=0 表示其捕获了固定提交的预期红/绿及正确计数，**不表示产品 FAST 绿**。

未跑：非 FAST 全套、发布 CI 的 full correctness 命令、真实 Pi/宿主 pane 段、性能结论、缺陷修正后的新 tip。没有容器构建或线上发布操作。本次使用已有镜像，未把内层没有 podman 的容器工具前提跳过当构建证明。选段控制不是全套门禁，各原始日志尾部已列未跑键；整套 FAST 的 36 个未跑真进程项在 `internal-fast.log` 与 `product-fast.log` 尾部逐项可查。

证据与报告均落在本分支；本任务的 FAIL 不能作为 `product-checkout-gate` 归档或发布许可。
