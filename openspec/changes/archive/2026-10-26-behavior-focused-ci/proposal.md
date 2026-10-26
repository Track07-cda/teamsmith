# behavior-focused-ci · 让 CI 判已交付的行为，让门禁自己的自证只在相关源变更时跑，并把同一批断言的重跑减掉

## Why

CI 是这个项目**唯一自动的正确性信号**，而它已经跑不完：最后一次公开运行（run 39354787618）在 60 分钟上限上被取消
在段索引 #110，已收口的 109 段合计 **3544 秒**。也就是说今天 CI 对一次普通推送给出的结论是「被取消」，
不是绿也不是红。

浪费是同一件事的三层重复：

1. **同一推动作跑整套，包括门禁自己的自证。** 那 3544 秒里 **1431 秒**（40%）是门禁在测自己：§0e–§0i 与 §36
   （其中检出形状探针 1064 秒）。更贵的一条是 **§61b**：路由翻转变异套件，表内登记 **4946 秒（约 82 分）**、22 条
   变异臂、V28 实测、V62 复验时完整跑过（31 臂、基线 `pass=3141`）。它证的是「§61 那段前门的断言会不会咬人」，
   不是产品行为（D147 的原话：「§61b 证的是夹具自己的牙齿」）。它是套件的**第 #128 段**，而那次运行死在 #110 ——
   所以 3544 秒里没有它；任何把它算进基线的入口，第一次跑到它就要多付 82 分钟。这两种成本都不该在每次推送里无条件付。
2. **同一批断言反复重判。** §36 的探针一次 **29 次嵌套套件、203 次段落执行**，每次嵌套先跑 4 个前导段。其中 7 次
   `--select 58` 各 55.9 秒，**正文只有 10 秒、闭包拿走 42 秒**（§6f 17s、§13c 11s、§3b 7s），而那三段与「豁免清单
   缺席时 signal-lint 还要不要判」没有关系 —— 那行的 `needs` 是历史「相关面」，不是运行前提。
3. **规格还在描述已经删掉的判定。** 性能套件的 2000 ms 红线、负载前提的可见 `SKIP`、按实测带推导的
   `section-budgets.tsv` 预算表都已在代码里退场（P316）并被用户确认删除，`verification` 里却仍写着它们，还引用不存在
   的 `docs/team/PUBLISH.md`；生效说明 `SKILL.md` 与 `references/protocol.md` 也仍在讲同一批旧红线。读文档的人无法知道
   门禁今天到底承诺什么。同一个文件里还留着一条**负载实验室专属**的要求（`A load experiment signals…`），它的夹具
   `tests/load-experiment.sh` 已随实验室一起删除。

## What Changes

四件事：前三件减少实际执行，第四件把规格与生效文档对齐到代码已经在做的事。

### 1 · 一处声明谁在「测门禁自己」，其余默认是产品基线（MODIFIED `verification#A changed-path list selects the sections to run, or the full suite`）

`section-paths.tsv` 表头已承载 `exempt:` / `prologue:` / `ledger-scan:` 三类声明。再加**一行**
`# gate-self-check: <key…>`：只列**主体是门禁自己的机制**的段 —— 段落自述/进度/现场（§0e §0f §0g）、tmux 隔离前导
（§0h）、运行指纹（§0i）、选段器/表/副本/探针/覆盖账（§36），以及**夹具元变异**（§61b：它证的是 §61 的断言会不会
咬人，主体是夹具而不是交付物）。**没被点名的段默认就是产品基线**，所以新加一段不会悄悄离开 CI；要让它出去，必须
显式写进这一行。`--check` 加一条纯逻辑规则：这一行每个 key 命中恰好一行、不重复、不点名前导段。

选择器加 `--floor`（可带 `--paths`）：一次回答「产品基线 ∪ 这次改动点到的段」。**不新增按行路径文件接口** —— 路径本身
可以含换行，`git` 默认列表还会把引号与反斜杠 C 转义，所以整链只用 NUL 分隔 + bash 数组 + 既有的 `--paths`。
未声明路径或不可解析基点照旧 `FULL`。

### 2 · 普通正确性入口 = 基线 ∪ 改动，性能仍然只参考（MODIFIED `verification#CI runs the two gates separately and performance does not block`、`verification#A gate that cannot judge says so`）

工作流在宿主侧 `git diff --name-only -z <base> <tip>` 读进数组，把这些路径**作为命令参数**传给容器里的
`smoke.sh --floor --keep --paths "$@"`（工作区是只读挂载，所以路径不能写成检出里的文件）。仍是阻塞步、无 `FAST`、
无 `continue-on-error`、`ci/collect-scene.sh` 的现场自证照旧；未声明路径或不解析的基点 → 全套（多跑安全）。性能步仍是
同一镜像里的**独立、不阻塞、只参考**的第二步；发布前那次读数的去处从不存在的 `docs/team/PUBLISH.md` 改到真实存在的
发布前置清单与当次发布记录。

**§61b 不进普通入口**：它的 4946 秒由「自己源变更时的选段」「显式入口 `--select 61b` / `task-model-routing.sh --flip`」
「合并/里程碑/release 的完整门禁」三条承接 —— 这正是 D147 已裁定的实践（全量与 §61b 留给合并/里程碑/release），本
change 只是把这条裁定落到 CI 的入口上，并让 §61（路由产品行为）留在普通入口。

### 3 · 减掉探针里重复的执行，用例一条不删（不改规格；落点 `checkout-shape-probe.sh` 与 §58 那一行的 `needs`）

- **7 次 §58 的闭包**：`needs: 13c` 改成 `-`。依据不是「键数变少」，而是**实际前置依赖 + 行为反例**：§58 正文只读
  文件与前导段状态（`$TS_RUNNER` 在前导段设好，§13c 只造自己 `$TMP` 下的夹具）；反例安排在 apply 里做成一**对**：
  §58 在没有闭包产物的树上照旧全绿、而某条**真有**闭包依赖的段（如 §17 依赖 §15b 建的假项目树）去掉它的前导后必红
  —— 前者证明删得对，后者证明 `needs` 机制本身没有变成橡皮章。
- **5 处同树同状态的嵌套合并**：`hy` 的 `19/31/58`、`hyteeth` 的 `31/58`、`in2`+证据层的 `31/58`、`mix` 的 `18/19`。
  **29 → 24 次嵌套、203 → 127 次段落执行**；被减掉的闭包段是产品段，在新基线里每次推送都在真实树上跑。
- **不动**：§36①–⑦（250 秒、16 次嵌套，各自独立的红侧；⑦ 的全键 `bash -n` 守的正是选段器依赖的剪贴器）、探针自身
  151 秒的比较工作、19 棵 scratch 树（约 7 秒，真拷是防穿软链写回真树的纪律）。

### 4 · 把一个 verification delta 对齐到代码与用户裁定（3 组退场重加 + 6 条按原标题 MODIFIED + 1 条退场）

- 三个「描述的判定已被删除」的要求整块退场，并在同一 delta 里以**保留原词干的新标题**重加：
  `The correctness gate judges correctness only, and a duration is a reading`、
  `The performance suite is separate, self-describing, and its numbers are reference-only`、
  `Every gate section accounts for itself, and a section that stops making progress is named`。
  `**Reason**`/`**Migration**` 逐条点名接手者。
- **退役负载实验室**：`A load experiment signals only the processes it started` 整块退场。通用规则（只对自己启动且身份
  已核实的进程发信号、绝不按名字或命令行模式选目标、`SIGSTOP` 必配释放陷阱）由既有契约承接：
  `boundary#Signals go to a recorded pid, never to a name or a pattern` 等三条，其守护夹具 `signal-gate.sh` /
  `team-bg-stop.sh` 仍在 §58 里跑。**不恢复实验室**，也不留尾巴单。
- 引用这些要求的句子在同一 delta 里改名，**不留悬空引用**；`A measuring fixture…` 删掉「两次运行必须读到相同数值」这条
  无依据的承诺（固定测量目标 ≠ 数值必须相同）。
- **生效文档同一轮对齐**：`skills/teamsmith/SKILL.md`（perf 行的 2000 ms / 前提因子 / 退出码 0/2/4/3）与
  `skills/teamsmith/references/protocol.md`（§9b-2 的「measurement premise」、perf 段的阈值与「skips visibly」）写进
  最小写集，与代码一起改，不再留旧红线。

## Impact

**改动的文件（apply 写集，逐条明授）**

- A：`skills/teamsmith/tests/section-paths.tsv`（表头一行）、`skills/teamsmith/tests/section-select.sh`（装载、
  `--check` 规则、`--floor`）、`skills/teamsmith/tests/smoke.sh`（`--floor` 透传）
- B：`.github/workflows/gates.yml`（NUL 数组 + `--floor` + 参数传递）、`docs/team/RELEASE-PUBLIC.md`（发布前置一条；
  PM 独占，需明授或由 PM 自己改）
- C：`skills/teamsmith/tests/checkout-shape-probe.sh`（5 处合并）、`section-paths.tsv` 的 `58` 行、`skills/teamsmith/tests/perf.sh`
  （只修一行过时注释）
- D：`skills/teamsmith/SKILL.md`、`skills/teamsmith/references/protocol.md`（旧红线）
- `openspec/changes/behavior-focused-ci/**`（本文件、`design.md`、`specs/verification/spec.md`、`tasks.md`）

**验收口径（这次按 PM 的 R2 改了）**：新增/改变的入口只做**定点证据**（选择器的 `FULL/NONE/RUN` 与键集合是纯逻辑入口，
不跑产品基线；合并后的断言共用一次实际运行），**最终一次固定环境整体运行**是交付门槛；未改变的 perf/锁/等待行为引用
P316、V65、V66 已成立的独立证据，不以场景数量生成翻转配额。

**不做的事**

- 不新建调度器、预算表、路径扫描平台、产品测试钩子、通用测试框架；不提高 CI 的 60 分钟上限；不恢复任何墙钟门槛；
  不删旧断言来「证明」质量；不恢复负载实验室；不把同一笔成本搬进每次本地 `team review`（完整入口仍是 `team review`
  与发布清单，CI 是被披露的选集）。
- 不碰 P321（npm 入口）与 P324（临时根 / 现场收集）正在修的文件：B 单必须等 P324 冻结并合入后再改 `gates.yml`。

**未知项（明说）**：基线在 CI 的墙钟要 apply 在容器里**实测一次**才作数 —— 109 段子集里的产品块是 2113 秒，另有几段
（§38-b 等）在 CI 走非 FAST 档会比记录更长；本提案不写「装得进 60 分钟」这句话。
