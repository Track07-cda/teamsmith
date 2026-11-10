# Design · reply-observer-skip-focus

## Context

动机见 `proposal.md`。现有路径定位均基于本提案开始时的测试源码，不是新测量：

| 位置（相对 `skills/teamsmith/tests/`） | 现有行为 | 本批处理 |
|---|---|---|
| `key-replies.sh:652–675` | bounded 先发布 20 条、建 100000×4096 字节索引并破坏最新槽，再检测观测能力 | 正常组保留全部准备和文件行为；仅将观测专属入口整理为可直接调用的函数 |
| `:674–717` | 不支持时发 bounded 读取量 SKIP，加一条预测 full_scan 也会跳过的 SKIP；支持时跑真实 IO/fd 比较 | 保留真实读量/fd 分支；预测通知删除，不是一项已执行检查 |
| `:871–900,943–960` | full_scan probe 缺能力返回 9，flip_run 负责具名 SKIP，不计坏/恢复通过；支持时做真实大/小存储比较 | 复用 probe 和实际结果消费者，不能另造缺席输出 |
| `:1013–1051` | 强制缺能力后完整子跑 bounded,flip；失败后再带 trace 跑整组；七条父级成功断言包含 SKIP 总数下限 | 整块执行替换为短样本及其反例，不保留重试式取证 |
| `:1399–1402,1426–1448` | 驱动发缺能力通知；分组调用后以累计 FAIL 决定退出 | 正常及短样本共享通知/结果收口；错误最终进入父级 FAIL |
| `lib/proc-io.sh:13–24` | `kr_io_supported` 和 `kr_io_why` 识别真实缺席或已有 `TEAM_REPLY_NO_PROC_IO=1` | 原样调用；不改库，不增加产品旋钮 |

这里的“真实判定路径”是正常 reply **测试**的能力处理路径；产品 `replies.mjs` 不以能否读取 `/proc` 决定产品可用性。短样本不冒称执行了无法观测的产品读量验证。

## Goals / Non-Goals

- 仅替换 `skip-path` 的执行单位；沿用一个组名、现有 smoke §62、同一套观测判定，不建第二入口体系。
- 独立文件断言由一轮正常 bounded 证明；把共享观测入口放在坏最新、不可枚举目录、不可读正文及权限恢复之后。短缺席样本证明该入口在观测专属准备之前返回，不再声称它执行了已经退休的完整缺席组。
- 不修改 `proc-io.sh` 的采样方式、任何数值阈值或 FIFO 的故障超时；不牵连共享它的 §63。
- 不新增产品条件、模块框架、长期删除监控、额外 smoke 段或夜间任务。三类负对照替代旧七断言中的宽泛计数/结束判定，不在旁边叠加第二套检查器。

## Decisions

### 1 · 在原测试文件内提取观测分支，而不是复制输出或另跑完整组

在 `key-replies.sh` 文件内整理出三个窄调用点；名称可随现有风格，职责不可变：

1. 驱动的缺能力通知函数：正常入口与短样本都调用现有检测/原因函数，缺席才发通知。它不是一个 SKIP 计数。
2. bounded 的观测专属函数：正常组先完成全部独立文件断言及权限恢复，再调用此函数；原 `674–717` 观测块提取到函数后，其唯一正常调用移到原 `718–751` 独立断言之后，不再保留“调用后继续跑独立断言”的路径义务。源码调用顺序及一轮 §62 的具名正常结果证明前一半；短缺席样本调用同一个入口，证明后一半——能力检查在任何 IO 专属准备之前返回，发具名读取量 SKIP，以现有 sentinel 9 表示未验证。支持时原真实 read/fd 检查不减；20 条发布、10 万槽、坏最新及权限检查仍只由正常 bounded 准备/执行一次。
3. full_scan probe 及其结果消费：将现有嵌套定义提升至同文件可调用位置，保留 gate-before-store 次序；短样本既调用 probe，也走正常 flip_run 使用的缺席结果消费者。不能仅测试 `kr_io_supported` 后手写 `skip`，也不能让新函数成为正常调用点不用的第二实现。

短样本在 subshell 中只执行这三条实际路径，使用已有 `TEAM_REPLY_NO_PROC_IO=1`，重置本地计数并捕获全部诊断。每次收集用自己的空项目和独立子根；调用前确认没有 reply 索引，调用 bounded/full_scan 后、清理前检查各项目 `.pi/team/state/key-replies/index.v1` 仍不存在，整个样本自有根也没有第二份准备的索引（60 槽也不许，不能只用文件大小判定）。它不扫描其它人的临时根。这一文件事实与真实 rc、结果分类同判；若只把能力检查移到准备之后，诊断仍正确也必须因索引出现而红。

上述准备顺序负例用 subshell 覆盖观测函数，使其先实际建一个小索引再委托原缺席处理；只需一槽就能反证“无索引”，不为负例恢复 400 MB 准备。还原后用未覆盖的真实函数重新收集。把该负例与无索引检查并入原“完整结果分类/退出”判断，不另增第七个父级成功。正例不发布 20/51 条、不建大存储、不复制/变异产品源码、不碰 FIFO 或运行其它臂。

正常代码与短样本复用结果格式化/退出处理小函数，但样本标签作为内部函数参数区分，使用 `== reply-observer absence sample 结果 ==`，不得使用 `== P234 key-replies 结果 ==`；父级原前缀不变，`smoke_inner_summary` 只能读到真正的父级结果。subshell 的输出描述符也定向至本次样本文件，防止继承 fd 3 使成功/失败行逃出被检查的日志。不另 printf 预期诊断/状态；临时根、清理、真实编号存储保护仍沿用原实现，不 source 整个脚本到其它项目或引入产品加载模式。

**未选方案：** 为 bounded/flip 增加通用 arm 选择器、缩短故障 timeout、保留完整组再缓存准备，都会保留无关工作或增加运行机制；固定三行“正确日志”则无法证明正常路径会这样处理缺席。

### 2 · 明确三种结果，接回现有父级退出

| 结果 | 观测专属路径 | 正常调用者 / 缺席样本 |
|---|---|---|
| 支持 | 执行原真实检查 | 原有成功/故障及坏→恢复规则不变 |
| 不支持 | 同一真实能力函数判定；bounded/full_scan 各一个具名 SKIP | sentinel 9 被相应消费者识别，既不变成 observation PASS，也不变成产品 FAIL |
| 错误 | 检查出错、诊断/分类不符、未正常收口 | 记录失败并非零退出；不能被当作 9 或静默忽略 |

短样本判断同时检查三条实际诊断的身份和原因、两条跳过的身份、无观测成功/产品失败，以及真实进程退出与完整结果行。它不以出现任意三个 SKIP 或一句 `✗0` 判成功。ANSI 样式不作为语义，理由必须来自当前 `kr_io_why`，不能在验证器里复制一份“正确理由”。

正常 `skip-path` 显式消费短样本/判定的 rc，失败须在父 shell 调 `bad`，具名输出 `✗ skip-path：缺席诊断/分类不完整` 并点名 bounded/full_scan 等实际缺项；该标签只由普通样本消费分支发出，内置反例的共享判定只返回状态/缺项文本，不输出此父级标签；这是原诊断或分类判断的失败分支，不新增计数项。现有主循环不因任意 helper `return 1` 自动增 FAIL，不能只返回被丢掉的 rc，也不能在命令替换的 subshell 内改 FAIL 后假定父变量已变。最终仍由父级 FAIL 出口退出 1，正常缺席为 0。仅观察父级 rc≠0 **不能**证明这条消费发生：三类反例的“还原应绿”可能已因同一损坏而红。

### 3 · 同一判定的三类反例，替代宽泛计数

只在本脚本的 subshell 中覆盖 tests 的实际处理函数，不用源码副本重进自检、不添加入口/开关或产品故障条件。正例及还原侧仍调用真实函数；负例只调用“收集短样本→同一证据判定”，不调用 `kr_group_skip_path`，也不启动 `--select skip-path`。示意函数名可随实现调整，调用形状固定：

```bash
(
  kr_bounded_observe() { return 0; } # 本例只覆盖该子 shell 的缺席分类
  if out="$(kr_skip_sample_collect)"; then sample_rc=0; else sample_rc=$?; fi
  kr_skip_sample_judge "$sample_rc" "$out"
)
# 离开 subshell 后覆盖消失，再以真实函数收集/判定还原侧。
```

先取得实际函数输出再判断，不改造日志模拟执行，也不让覆盖传播回父 shell或下一例。

| 类别 | 必测变体 | 判定与还原证据 |
|---|---|---|
| 缺诊断 | 分别去掉驱动、bounded、full_scan 诊断；至少一例补任意无关 SKIP 到三条以上 | 指出哪条事实缺失；无关行不能顶替；还原再绿 |
| 假通过 | bounded、full_scan 分别把缺席当成功 | 分类/计数或非预期路径必须被拒；仅保留启动通知不够；还原再绿 |
| 假产品失败 | bounded、full_scan 分别把缺席当失败 | 真实 rc/结果分类不符必须被拒；还原再绿 |

三类共至少七个定点变体，另有前节的一槽准备顺序变体，不复制九个产品故障臂。每类只有所有变体及还原都符合预期才报告一个成功；中途失败不得继续打印该类成功。所有内置反例在本进程的隔离子 shell 中结束，不启动脚本副本，因此没有自检递归。

父级消费的验收另由外部一次性 scratch 脚本副本完成，不把它放入内置反例循环：bounded/full_scan 分别取下列三侧，使用同一个既有 `--select skip-path` 入口各调用一次。

| 外部副本 | 必须读到的实际事实 | 不能据此冒称什么 |
|---|---|---|
| 只损坏共享缺席处理 | rc=1，且有 `✗ skip-path：缺席诊断/分类不完整`，点名该诊断/分类 | 不能仅以反例还原侧的其它红行或 rc=1 代替此行 |
| 同一损坏，再吞掉样本失败判定 | 仍 rc=1（内置反例的还原侧红），但上述具名父级断言**消失** | 这一侧不是成功传播；恰好反证 rc=1 不具区分力 |
| 还原全部修改 | rc=0、样本对应的正常判断成立 | helper 的 rc 不能替代原脚本事实 |

核对时去 ANSI 后匹配上述具名父级断言及其对象，不按任意 `✗` 行数。它们是实现交付时的定点取证，不增加常规入口、永久 smoke 段或再跑 bounded/flip。普通 full_scan 的产品全扫变异仍由原九臂中的真实内核证据证明，不用短样本取代。

### 4 · 执行和计数分别核账

| 对象 | 改前（源码可确定） | 改后计划 |
|---|---|---|
| 正常 bounded 组 | 1 次 | 1 次；全部断言保留 |
| 正常九臂 | 每臂坏/恢复一次 | 相同九臂各一次；没有转移运行模式 |
| 缺席 replay bounded | 1 个完整组，包含第二份大存储和独立文件断言 | 0；只有观测专属缺席入口 |
| 缺席 replay flip | 1 个完整九臂组；full_scan 返回 9，其余八臂仍坏/恢复 | 0；只调用 full_scan 缺席 probe 和正常消费者，不做产品变异 |
| replay 失败后的 trace | 失败时最多再完整执行一次 bounded,flip | 0；保留第一次短样本输出、rc、诊断/分类与失败身份 |
| 有效缺席 SKIP | replay 中 bounded 读量、bounded 预测、full_scan 共三条计数行；另有不计数的驱动通知 | 短样本恰两项未验证；删除预测行，保留三条不同身份的诊断 |
| skip-path 父级局部断言 | 7：强制能力 1、末行 1、诊断 3、无红 1、SKIP 下限 1 | 6：强制能力 1、完整诊断集合 1、完整结果分类/退出 1、三类反例各 1 |

最后一行仅指 skip-path 本身的局部判断，不含脚本其它组和外部取证。准备顺序的无索引/一槽变体合并在结果分类判断内，仍是七条旧父级判断换六条新判断，不多报一条成功。子样本以自己的非父级前缀收口 `✓0 ✗0 SKIP2`；父级六个成功指“证据处理与反例成立”，不是“缺工具的产品检查通过”。subshell 的 SKIP 不并入父级再次计数。独立文件断言的执行证据来自正常 bounded，不以强制缺席样本冒称又跑一遍；实际场地自然缺观测器时，正常 bounded/full_scan 的跳过仍按各自实际执行记账。

旧嵌套组的 PASS 从未汇入 key-replies 父计数，不能把八臂/大存储的退休当成父计数减少多少。§62 更外层原本仅以子进程 rc 和结果行给一条成功；不能拿它的 `✓1` 证明内层覆盖。交付必须列出本表对应的实际具名结果与内层计数，报告真实总数及差异来源，不预填整轮目标值、不补虚假成功行。

## Spec integration and ordering

`key-replies` 修改原 bounded requirement，保留两条原场景并补缺证据/正常 full_scan 场景。`verification` 修改原 `A gate that cannot judge says so` 的覆盖比较边界，再加入一个短样本 requirement；不改其它 requirement，也不建第二套规范。

现存 `route-page-check-determinism` 也修改同一 verification requirement，尚在 changes 中。**规格合入顺序为 route-page-check-determinism → 本 change**。本 delta 保留其全部路由义务和两条新增场景，但同步把原“only the three”一句改为允许三项 route-page 替代及单独点名的 reply-observer 退休，消除合成块冲突；不在对方目录写入。proposal 的文字不是自动依赖键。若前置候选再改，先由本 change owner 对齐完整修改块。

以下是 **PM 在接受/正式收尾前**用当时的 base 执行的可复制试合入步骤，作者本轮不运行。所有 `archive` 只作用于副本；真实项目仍需实现、独立验证及用户确认后才可定稿。

```bash
set -euo pipefail
export PATH="$HOME/.bun/bin:$PATH"
export CI=1 OPENSPEC_TELEMETRY=0 TMPDIR=/var/tmp
trial="$(mktemp -d -p /var/tmp p433-order.XXXXXX)"
printf 'trial=%s\n' "$trial"
for order in forward reverse; do
  mkdir -p "$trial/$order"
  cp -a openspec "$trial/$order/openspec"
done
(
  cd "$trial/forward"
  openspec archive -y route-page-check-determinism
  openspec archive -y reply-observer-skip-focus
) >"$trial/forward.log" 2>&1
(
  cd "$trial/reverse"
  openspec archive -y reply-observer-skip-focus
  openspec archive -y route-page-check-determinism
) >"$trial/reverse.log" 2>&1
python3 - "$trial" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
markers = (
    "The separate reply-observer exception",
    "identified reply-observer retired executions",
    "### Requirement: Reply observer absence is proved without replaying unrelated checks",
)
rows = []
for order in ("forward", "reverse"):
    text = (root / order / "openspec/specs/verification/spec.md").read_text()
    counts = tuple(text.count(marker) for marker in markers)
    print(order, "reply-exception=", counts[0], "inventory-exception=", counts[1], "added-requirement=", counts[2])
    rows.append(counts)
if rows != [(1, 1, 1), (0, 0, 1)]:
    raise SystemExit("Unexpected ordering evidence; retain scratch logs and do not integrate")
PY
# 成功后仅清理这次自己的具体目录；失败时 set -e 保留现场供核对。
rm -rf -- "$trial"
```

前两处读数才证明覆盖例外在正序各为 1、逆序各为 0；第三处两序都为 1，仅作“不足以判顺序”的对照。不能单看新增 requirement、两个 CLI 都返回成功或 trial 后结构校验通过。既有正反读数见 V133 报告，本次只提供命令与预期，不冒称重跑。

## Acceptance and migration

一个不同于提案者的 apply owner 做一个批次，无产品数据迁移。先提交窄提取及最小样本/负对照，再交一轮集成证据。所需行为和可失败条件以两个 delta 为准；任务对应关系见 `tasks.md`。

在项目规定的隔离门禁容器里运行，保存全部日志于 bind mount 的磁盘目录，TMPDIR 使用自己的 `/var/tmp` 根；沿用现有隔离规则，不接触真实团队：

```bash
# 先验证短样本与三类反例；包括同一 skip-path 的失败传播证据
bash skills/teamsmith/tests/key-replies.sh --select skip-path
# 只做这一轮正常 bounded/九臂及其它 reply 组，不在此前单独全跑 bounded,flip
bash skills/teamsmith/tests/smoke.sh --select 62 --keep </dev/null
# 静态整合检查；不扩大为全套行为测试
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
```

所有命令在当前树已存在；本提案未运行行为命令。若实现仍限同一测试文件，则映射只需核对原 §62，`proc-io.sh`/UI 未改，不增加 §63/38 行为运行。若实现必须改出此边界，先回交 PM 重新定范围，不自行扩大。

改前参考复用已存在的 §62 日志与源码，不再跑旧整组。新增的只有改后短样本和一轮 §62，完整日志给实际时长/结果。既有 §62 的 822 s 是一个历史全段读数，不是重复分支单独时长，不能与改后短样本相减来声称节省。没有全量、夜间、61b 或真实性能达标承诺。

回滚为撤销测试改动及对应未定稿 delta，恢复旧执行；不修改产品/运行时数据。若短样本没有进入正常调用点、父级仍绿、任一正常臂丢失、其它断言退休，或需要新通用框架，则停止接收本实现而不是放宽检查。

## Risks / Trade-offs

- 只测能力 helper 会漏掉消费者接线错误 → 短样本调用实际观测子路径和结果消费者，并以原脚本入口提供失败传播证据。
- 独立文件检查和缺席证据混为一谈 → 正常 bounded 的独立断言/权限恢复在共享入口之前证明；短样本只证明同一入口在准备之前返回，不冒称覆盖完整缺席组。
- 总数掩盖丢失检查 → 仅按具名退休映射解释变化，区分三层计数，不要求新总数凑旧总数。
- 规格完整版覆盖并行路由义务 → 按前述顺序保留前置全文，不把仅结构校验通过当作合并语义已验证。
