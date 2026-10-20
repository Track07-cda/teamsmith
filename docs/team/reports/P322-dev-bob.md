# P322 · 行为为主的 CI：清掉重复嵌套而不丢必要覆盖（探索）

agent: dev-bob   status: delivered（仅探索，无实现；PM 03:44:11Z 裁定后的订正稿）   time: 2026-10-20
branch: `task/P322-ci-scope-explore`   change: `behavior-focused-ci`（本阶段不建目录）   phase: explore
本阶段不实施自己提出的方案；**推荐方案 A 未被采纳**，方向由另派的 propose 单定。
本稿为 PM 03:44:11Z 裁定后的订正版：只改算术与测量表述、撤回「断言一条不删」的承诺、把性能规格并回本 change，
不新增任何实验（探针没有重启，也没有再跑别的计时套件）。

## 结论（先看这一段；这是 PM 03:44:11Z 裁定后的订正稿）

**方案 A 未被采纳。** 本报告从「建议直接进 apply 的方案书」降级为两样东西：① 可复核的事实与**算术**，
② 供 propose 单使用的方向与代价。本阶段不写实现、不写规格；方向（普通 CI 的产品行为、按相关源变更的重型工具
自检、可实际完成的完整验收入口）由 propose 单钉死。

**这一稿订正了什么（对应 PM 的第 ①–⑤ 条）**

1. **算术（PM ①）**：上一稿 §3.5 的七项在 CI 列相加是 **1211s，不是 1064s**。差的 147s 正是「嵌套套件自身的
   启动/收尾」那一行——它**已经包含在**每次嵌套的总耗时里（55.9s 这类数字本来就含启动），被算了两次。去掉它：
   618+93+82+22+11+238 = **1064s**。但这仍是**同义反复**：CI 列本来就是按 1064/672 这一个比值摊出来的，
   它不是独立证据。现在 §3.5 把**实测**与**按单比值摊派**分开写，摊派只用来解释份额，不用来证明份额。
2. **「完整运行实测」不成立（PM ①）**：3544s 是 **109/135 段**的求和；段索引 110–135 共 26 段（含 §58）从未收口，
   这次运行是被 60 分钟上限截断的。按路径把若干段相加，得到的仍是**这个子集**的和，不能叫完整运行实测（§2 已改口径）。
3. **「缩到约 2 秒」不证明覆盖（PM ②）**：`--paths ci/Containerfile`、`install.sh` 的 5 个 key / 2s，只是**选择器的
   回答**，不是「交付行为被覆盖」的证据；而这张表已被证有漏映射（`bin/team.mjs`、`ci/**` 落 `FULL`），
   所以普通 CI 的**产品基线不能由路径映射表推导**（§5.2 已改）。
4. **入口自相矛盾（PM ③）**：上一稿一边写 `workflow_dispatch` 保持全量、一边写全量一定超过 60 分钟，二者不能同时成立。
   另外「把同一段 22 分钟挪到每次本地 review」不叫清掉重复——review 本来就在跑全量。真正的减法在 §5.1：
   **先减 29 次嵌套本身**，全量才有机会落回 60 分钟以内（§5.4 给算术投影，不称测量）。
5. **规格口径（PM ⑤）**：本 change 按原 brief **一起**更新旧性能规格与 CI 口径；同一 capability 的多条 requirement
   放**一个** delta 文件，不另留 P316 的规格尾巴（§6 第 3 条已改）。删 §36 里 `outbox.sh` 样例声明会**触犯**现有
   字面映射检查（`--check` ⑥，红侧实测见 §5.5），所以它不能「顺手删掉」，只能选一条说清楚的路线。

**事实部分（未变，仍是本报告可用的部分）**

- 门禁自检块 §0e+§0f+§0g+§0h+§0i+§36 = **1431s**，是 109 段求和（3544s）的 **40%**；其余 2113s 判交付产品。
- §36 一段 **1314s**，其中 ⑧ 检出形状探针 **1064s**、①–⑦ **250s**；探针在 CI 里是唯一的输出静默区。
- 探针 **29 处嵌套调用 / 203 次段落执行**（116 前导 + 87 正文）；`--select 58` 展开 13 个 key，一次嵌套 55.9s 里
  **42s 是 `needs` 闭包**（§6f 17s、§13c 11s、§3b 7s），探针里这样的运行有 7 次。
- 两条表缺陷（§5.5）：`bin/team.mjs` 与 `ci/**` 无行声明 → `FULL`；`outbox.sh` 既是 §36 的样例 token、又是多条
  产品行的真实依赖，删声明会被 `--check` ⑥ 判红。

## 1. 这份报告怎么得出结论

- **不改仓库、不跑全量**：全部结论来自 ① 现成的 CI 日志（只读）、② 静态调用链、③ 一次有界实验（在 `/tmp` 的
  副本上给检出形状探针加计时，不碰工作树）。
- 静态材料：`.github/workflows/gates.yml`、`ci/collect-scene.sh`、`skills/teamsmith/tests/smoke.sh`（135 段）、
  `tests/section-select.sh`、`tests/section-paths.tsv`、`tests/checkout-shape-probe.sh`、
  `openspec/specs/verification/spec.md`、`.pi/team/state/release-030/public-ci.log`、`public-ci-job.json`、
  `docs/team/reviews/release-0.3.0.md`。
- 一次实验：`/tmp/p322/root` = 工作树的 `cp`（排除 `.git/.worktrees/.pi`），其中 `checkout-shape-probe.sh`
  副本加了 `nest()`/`scratch_tree()` 计时（命令与原始输出见 §3.3）。仓库工作树**未改动一个字节**
  （收尾 `git status --porcelain --untracked-files=all` 为空）。

## 2. 实测：CI 那 59 分钟花在哪

作业 `118406985548`（run 39354787618）：构建镜像 59s（01:41:05→01:42:04），门禁容器 01:42:04→02:41:14
（3550s），随后被 60 分钟上限取消在段索引 #110（共 135 段），现场收集失败（0 个现场族），性能步骤未运行。
按段的收口行统计（109 段有收口行，合计 **3544s**；段索引 110–135 共 26 段没有收口行，其中包含 §58）。
**口径**：下面这张表是**被截断那一次运行里 109 段的求和**，不是完整运行实测；按变更路径把其中若干段相加，
得到的也只是同一子集里的和（下面所有按路径的数字都按这个口径读）：

| 段 | 键 | 用时 | 是什么 |
|---|---|---|---|
| #100 | 36 | **1314s** | 选段/分段账本/检出形状自检 |
| #102 | 38 | 365s | 设置选项（面板 choices / 一致性走查 / 选择器夹具） |
| #87 | 33 | 164s | `team config` 读写面 |
| #98 | 34d | 118s | 门禁锁身份面 |
| #79 | 26 | 111s | 面板 |
| #64 | 12b-pi | 80s | 投递换道 |
| #63 | 12b-h0c | 74s | 输入框判据（覆盖层） |
| #95/#96 | 34/34b | 69s/67s | 门禁锁记账 / 排队守卫 |
| #103 | 39 | 62s | npm CLI 与项目 skill 安装 |
| #81 | 28 | 56s | 控制台表面 |
| #105 | 41 | 51s | pane 留存 |
| #104 | 40 | 48s | 临时根纪律 |
| #9 | 0i | 36s | 运行指纹 |
| #8 | 0h | 10s | tmux 隔离前置 |
| #6/#7 | 0f/0g | 5s/1s | 超时段落夹具 / 等待有界自检 |

**分类（按被测对象是不是「门禁自己的源码」）**：门禁自检块 = §0e 65s + §0f 5s + §0g 1s + §0h 10s + §0i 36s +
§36 1314s = **1431s（3544s 的 40%）**；其余 2113s（60%）判的是交付出去的产品（CLI、面板、投递、锁、安装、
信号纪律）。门槛不模糊：§34/§34b/§34d、§31c、§40 判的是**已交付**的 `scripts/lib/gate-lock.sh`、`scripts/shim/tmux`、
`scripts/lib/tmp-root.sh`，所以归产品侧，不能挪。
`public-ci.log` 里 §36 自己还打了一行 `⚠ #100 用时 1314s，超过实测带 338s（这是记录，不是判定）`——**记录的实测带
只有它的 26%**，即这段的增长（P222/P226/P239 之后）没有在任何被看见的地方体现过。

## 3. 22 分钟自检的内部：哪些在重复跑真实产品路径

### 3.1 两半：250s 的选择器自检 + 1064s 的检出形状探针

- ①–⑦（`section-select.sh --check` 六个腐烂方向、②`--paths` 语义、③④⑤ 嵌套选段、⑥ 覆盖清单、⑦ 全键副本
  `bash -n` + 红侧）：02:09:46 → 02:13:56 = **250s**，其中 ⑦ 占 117s。
- ⑧ 检出形状探针（`tests/checkout-shape-probe.sh`）：02:13:56 → 02:31:40 = **1064s**，期间唯一的输出是每 60s 一次
  的心跳，最后一行 `✓ 36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）`。**它一个人占全程的 30%。**

### 3.2 探针在做什么：29 次嵌套 smoke，203 次段落执行

`checkout-shape-probe.sh` 里 `nest()` 调用点 **29 处**（`--select 19`×7、`31`×7、`58`×7、`18`×5、`18,19`×1、
`12k,31`×1、`12k`×1）。每次嵌套跑都是「私有 TMPDIR + 清身份 + `TEAM_SMOKE_FAST=1` + 不排队」，并且**先跑 4 个前导段**。
按选择器实际展开（§3.4 的 `--select 58` 展开为 13 个 key）算：29 次嵌套 = **116 次前导段 + 87 次正文段 = 203 次段落执行**，
而它要回答的问题只有一句：*换一种检出形状，前提跳过与判红的分界还在不在*（`verification#A gate that cannot judge
says so`）。

重复的正是这些：§58、§31、§19、§18 在这份套件的**顶层**已经各跑过一次（CI 里 §19=1s、§31=7s、§18=1s；
§58 因取消没跑到，本地同一份树的成本见下），探针又在 7/7/7/5 份 scratch 树上各重跑一遍——不同的是树形，相同的
是产品断言。算上顶层那一次，一次全量门禁里 §19 被跑 8 遍、§31 8 遍、§58 8 遍、§18 6 遍。这是**有意的**
（要证明跳过只在缺内部面时发生），但它同时意味着同一批产品断言被反复重判。

### 3.3 计时实验（一次，有界）

命令（工作树只读，副本里改计时）：

```
$ tar -c --exclude=.git --exclude=.worktrees --exclude=.pi . | tar -x -C /tmp/p322/root
$ # /tmp/p322/root/.../checkout-shape-probe.sh 里给 nest()、scratch_tree() 各包一层计时，追加到 timing.tsv
$ cd /tmp/p322/root && LC_ALL=C TMPDIR=/tmp/p322t P322_TIMING=/tmp/p322/timing.tsv \
    bash skills/teamsmith/tests/checkout-shape-probe.sh > /tmp/p322/probe.out 2>&1
```

实测（本机，32 核，loadavg 22.5；运行 328.6s 后由 PM 按记录主动停止——`bg.log` 记
`stop id=p322-probe-timing signal=TERM result=stopped … by=3257021`，PM 的 say（03:34:48Z）要求用已有日志完成、
**不重启探针、不启动其他计时套件**，此后确实没有再跑任何计时套件）：

| 类型 | 次数（实测） | 每次总耗时 | 其中正文段 | 其中启动/收尾（列内分解，不另相加） |
|---|---|---|---|---|
| `--select 18` / `19` / `18,19` | 11（3×18、6×19、1×`18,19`） | 3.6–4.7s | 1–2s | ≈3s |
| `--select 31` | 2 | 8.4s / 8.5s | 4–5s | ≈4s |
| `--select 58` | 2 | **55.9s / 55.0s** | **52s / 51s** | ≈4s |
| `scratch_tree`（50MB 真拷 + `git init/add/commit`） | 10 | 0.3–0.4s | — | — |

- 15 次嵌套合计 **173.7s**，其中被嵌套的段落正文合计 **126s**，即**每次嵌套约 3.2s 是套件自身的启动/收尾**
  （身份隔离、私有 socket、临时根、指纹、锁豁免、选段头与未跑清单）。这一项乘 29 ≈ 93s，**已含在**每次嵌套的总耗时里。
- 剩余时间（328.6 − 173.7 − 3.8 = **151s**）是探针自己的比较工作：`--check`、140 余次 `case`/`sed` 比对日志、
  `coverage-inventory.sh --static`（扫 22845 行的 `smoke.sh`）、`real_fp`（md5 5400 个文件，跑两次）。

### 3.4 真正的放大器：`--select 58` 的 `needs` 闭包

```
$ bash skills/teamsmith/tests/section-select.sh --select 58
decision=RUN  sections=135  keys=13
reason=0/0b/0c/0d ← prologue
reason=2  ← needs:5, needs:4
reason=4  ← needs:6, needs:3b
reason=5  ← needs:6i, needs:6f, needs:6, needs:3b
reason=3b ← needs:6
reason=6  ← needs:6i, needs:6f
reason=6f ← needs:13c
reason=6i ← needs:13c
reason=13c ← （§58 的 needs）
reason=58
```

一次 `--select 58` 实际跑 9 个正文段（`2,4,5,3b,6,6f,6i,13c,58`）+ 前导。实测那次嵌套的段落账（`nest-hy.log`）：
`2:1s 4:1s 5:0s 3b:7s 6:1s 6f:17s 6i:4s 13c:11s 58:10s`——**§58 本体只有 10s，闭包拿走 42s**，其中 §6f（面板适配器）
和 §13c（后台车道）与「豁免清单缺席时 lint 还要不要判」这个问题毫无关系。探针里 `--select 58` 有 7 次：
**7 × 42s ≈ 294s（本机）/ ≈ 465s（按 §3.5 的单一比值摊派）纯粹是闭包带来的重复产品断言。**

### 3.5 本机实测、本机投影、以及 CI 那一个数（三者分开说）

**实测（本机，运行 328.6s 后被 PM 停止）**：

| 桶 | 实测 |
|---|---|
| 15 次嵌套合计（**已含**每次的启动/收尾） | 173.7s |
| 其中被嵌套的段落正文 | 126s |
| 10 棵 scratch 树（50MB 真拷 + git） | 3.8s |
| 探针自己的比较工作（`--check`、140 余次 `case`/`sed` 比对、`coverage-inventory --static`、两次 `real_fp`） | 151s |

**本机投影（含未被测到的尾段）**：剩余 14 次嵌套按**已测同类单价**推算——5×§58≈280s、5×§31≈42s、1×§19≈4.5s、
1×§18≈3.6s、`12k,31`≈9s、`12k`≈5s ≈ 344s；其余 9 棵树≈3s。合计 328.6 + 344 + 3 ≈ **676s**
（分桶：嵌套 **518s**、树 **≈7s**、探针自身 **151s**）。这一列里除 15 次嵌套与 10 棵树外都是推算。

**CI 的那一个数**：探针在 CI 里 **1064s**（02:13:56→02:31:40，段收口行同源），这是**唯一一个 CI 侧实测值**。
本机投影 676s → CI 1064s，比值 **1.57**。

**按比值摊派（不是测量）**：518×1.57 ≈ **815s**（嵌套，含各自启动/收尾）、7×1.57 ≈ **11s**（树）、
151×1.57 ≈ **238s**（探针自身比较），合计 1064s。上一稿把「启动/收尾」单列一行又加一遍，才出现 1211 这个数；
删掉那一行就是因为**它已经在 518s 里**。摊派只说明份额大致怎么分，**不能**用来证明份额（比值是由总数反推的）。

**独立于摊派的结论**（这些不靠比值）：29 处嵌套、7 次 `--select 58`、每次 §58 运行里正文 10s / 闭包 42s、
203 次段落执行、每次嵌套约 3.2s 是套件自身启动（15 次实测里 126s 正文对 173.7s 总耗）。这几条是探针成本的
真实结构；至于它们在 CI 的 1064s 里各占多少秒，只有本机实测 + 一次比值摊派。

## 4. 哪些是选择器/账本自检的**必要**行为（不能删）

| 断言 | 为什么必要 | 现在的守卫 |
|---|---|---|
| `--check` 六个腐烂方向（缺行/收窄/未知 needs/声明豁免类/字面缺失/账本映射） | 表是唯一归属声明处；表腐烂 = 静默少选，安全方向被打破 | §36①（每向一条红侧，51s） |
| `FULL` 兜底 + 点名未声明路径 | 「跑多了总是安全」的唯一兜底 | §36④（嵌套空壳变体，4s） |
| 嵌套 run 不继承标记、不自称全套 | 继承标记会让嵌套子进程静默跑全套 | §36③（嵌套 `--select 0b`，16s） |
| 前提下跳过必须是可见 `SKIP（条件不满足）`、计数分开、不得当通过 | 这就是「跳过假绿」事故的守门 | §36⑤/⑤b/⑤d/⑨/⑩ + §19/§31/§58 的 SKIP 行 |
| 产品字面缺失照旧红（跳过不许放大到产品路径） | P222/P226 的核心边界 | §36③/⑨/⑩ 的牙齿与三个影子 |
| 空面不算缺席、混入一个内部面不许跳过 | 同上 | §36⑤d/⑨ |
| 覆盖清单不许把旧断言换成跳过 | P148 的「跳过不是通过」 | §36⑥ + `coverage-inventory.sh` |

以上都在**同一段**里、和探针混在一起：**没有一个能在不改变语义的前提下删掉**。可以变的只有它们**跑的次数与次数
背后的闭包**，以及**什么时候跑**。

## 5. 方向与代价（供 propose 单参考；方案 A 本身未被采纳）

### 5.1 先减 29 次嵌套本身（这是真的减法，其它都是搬家）

探针的 29 次嵌套不是 29 个不同的判断题：`--select 19`×7、`31`×7、`58`×7、`18`×5、`18,19`×1、`12k,31`×1、`12k`×1。
每次先跑 4 个前导段（29×4 = 116 次），再跑正文；`--select 58` 每次还拖着 8 个闭包段。

可动的三条轴（选哪条、减到多少由 propose 定；这里只给代价与必须保住的东西）：

| 轴 | 现在（实测/结构） | 代价与风险 | 减法必须保住什么（可证伪） |
|---|---|---|---|
| ① 减少 §58 控制的次数 | 7 次，各 55–56s（正文 10s + 闭包 42s） | 每次对应一棵变异树（产品面 / 内部树+清单在位 / 缺产品文件 / 放宽判据的影子 / 植入 pkill / 混合形状），合并会削弱「一条变异 → 一条红」的对应 | 每条被合并的控制都要指出：改坏归属判据后**哪条断言**仍会红；说不出来就是删覆盖 |
| ② 把 §58 拆成「静态 lint」与「真实记录」两段，嵌套只选前者 | 闭包 42s/次 × 7 | 需先证明 §58 正文在空闭包树上仍成立（**未验**）；拆段要过 `--check` 的「每段恰好一行」与 token 覆盖 | §58 本体断言一条不少；真实记录那段仍由顶层全量跑到 |
| ③ 让嵌套 run 不带 `needs` 闭包 | `--select` 的语义就是「带前导 + needs 闭包」 | **会改选段语义**，与「一条选择不得变成空转的通过」冲突 | 必须证明被跳过的闭包段在那棵 scratch 树上本来就不影响该段判决；证明不了这条路不能走 |

另外两条便宜的：29 次嵌套的**启动/收尾**（本机实测每次约 3.2s，合计 ≈93s）只能靠**减少次数**降，不能靠优化套件启动；
19 棵 scratch 树的真拷 + git 只有 ≈7s，不值得动。

**不承诺「断言一条不删」**：减法可以是合并、下移、或换成更便宜但**等价**的控制，但每一条都必须回答「保住了什么、
靠哪条断言仍能变红」。上一稿那句「断言一条不删」是承诺不是证据，本稿撤回。

### 5.2 普通 CI = 产品行为（基线不能由路径表推导）

`--paths` 只回答「改了什么就多跑什么」，它不回答「哪些段是交付行为」；而这张表已被证有漏映射
（`bin/team.mjs`、`ci/**` 落 `FULL`），所以普通 CI 的**基线**若由路径推导，一次漏映射就是一次静默少跑。

因此普通 CI 需要一条**不依赖路径**的产品基线，路径逻辑只用来**加**（加的是重型的门禁自检，多跑无害）。两种表达方式
（propose 定）：（a）给表加一列（例如 `kind: product|self-check`），`--check` 沿用「每段恰好一行」的口径要求每行有值，
CI 无条件跑 product 类、self-check 类按路径加选——声明可复核，新段漏填会被现有行形状检查挡住；（b）在工作流里显式列
一组 key——rot 风险高，`--check` 看不见。

**代价必须先说清**：109 段子集里产品块是 2113s（35 分钟），另有 26 段没跑到（其中 §55/§56 会议、§62/§63 关键回复、
§64 升级配方、§65 斜杠命令都是产品段，时长未知）。所以**现在**把 CI 改成「只跑产品块」也不保证装得进 60 分钟——
这正是 §5.1 必须先做的原因。

### 5.3 重型工具自检按相关源变更触发

表里已经写着（`section-select.sh`、`section-paths.tsv`、`smoke.sh`、`lib/section-guard.sh`、`lib/checkout-shape.sh`、
`checkout-shape-probe.sh`、`coverage-inventory.sh` 都声明在 §36 行里），`--check` ⑥ 守着「段正文点名的路径必须被本行
覆盖」。这条**不需要新机制**：改这些文件的推送本来就会选中 §36 与 §0e/§0f/§0g/§0h/§0i。

### 5.4 完整验收入口必须「能跑完」

上一稿的「`workflow_dispatch` 保持全量」+「全量一定超过 60 分钟」是自相矛盾。事实：**现在**全量 3544s（还只是 109 段的
子集）+ 构建 59s + 现场收集越过 60 分钟，所以现在唯一能跑完的完整入口是**宿主机上的 `team review`**（不受 CI 上限约束）
与 `docs/team/RELEASE-PUBLIC.md` 里那条手工容器命令。

**§5.1 落地后**才谈得上把完整入口放进 CI。算术投影（**投影，不是测量**）：7 次嵌套 §58 的闭包 ≈465s（按 1.57 摊派）
与重复的 §31/§18/§19 嵌套 ≈175s 若被合并掉，全量从 3544s 落到 ≈2900s（48 分钟），加构建与收集仍在 60 分钟内。这是
「先减重复、再谈入口」的理由；反过来用「CI 只跑产品段」把矛盾盖住是不行的。

### 5.5 两条表缺陷（其中一条不能「顺手删」）

1. **`bin/team.mjs` 与 `ci/**`（除 `ci/Containerfile`）没有任何行声明 → `decision=FULL`。** 实测 `--paths bin/team.mjs`
   → `FULL`、`--paths ci/zzz-new.sh` → `FULL`。前者是交付的 CLI 包装器，后者是门禁镜像与收集脚本；新口径下这两处
   要么补归属，要么明确「这两个目录的变更走完整入口」。
2. **§36 行里的 `skills/teamsmith/scripts/lib/outbox.sh` 不能只删声明。** 它同时是 §36② 的 `--paths` 样例 token
   （`smoke.sh:18003`），而 `--check` ⑥ 要求「段正文点名的真实路径必须被本行覆盖」。实测（表副本 + `--table`，纯逻辑）：
   ```
   $ bash skills/teamsmith/tests/section-select.sh --check --table /tmp/p322chk/table-no-outbox.tsv
   bad: 段 36 读了它没声明的路径：token skills/teamsmith/scripts/lib/outbox.sh（源码行 18003）—— 补进该行的 patterns
   rc=1
   ```
   三条可行路线（都不绕过检查、不造例外）：(a) 声明照旧，接受改 `outbox.sh` 会选中 §36；(b) 声明照旧但**拆段**（§5.1 轴 ②），
   样例留在便宜的那一半，于是改 `outbox.sh` 付 250s 而不是 1314s；(c) 把 §36② 的样例路径换成 §36 本行已声明的另一个产品
   路径，并同步改那一组样例断言的期望（这是改断言输入，不是删断言）。表本身不需要新例外，`--check` 也不放宽。

### 5.6 诚实披露（已有机制，直接复用）

选段运行**已经**打印 `decision=`、跑了多少段、未跑的 key 清单，结果行是 `== 选段结果 ==`，并且禁止打印 `smoke 全绿`
（`verification#A selected run says what it did not run`，§30 段实测在）。CI 里只需在步骤名前把 decision 打出来；
`team review` 的记录规则不变。

## 6. 必须由 propose 处理的三处 capability 冲突（不建平行规范）

1. **`verification#CI runs the two gates separately and performance does not block`** → 场景
   *The workflow carries two independent conclusions* 写着「the correctness command is the unchanged
   `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`」。按 §5.1，普通 CI 不再是
   那条命令 → 这条 requirement 要 MODIFIED，改成：普通 CI 跑 `--paths` 选中的产品段（`FULL` 兜底）、完整门禁由
   本地 review / 手动 / 发布三个入口承担、性能步骤的非阻塞性质不变。
2. **`verification#A gate that cannot judge says so`** → 场景 *The public workflow remains a blocking correctness
   check* 写着「the command remains … **without FAST**」并要求「CI's correctness step MUST retain its command and
   blocking failure semantics」。同上，同样要 MODIFIED；**保留**的部分必须写清：选段运行仍是阻塞的正确性判定、
   仍然 `--keep </dev/null`、仍然不注入 `CI`/`GITHUB_*`、仍然由 `ci/collect-scene.sh` 自证现场。
3. **`verification#The performance suite is separate, self-describing and non-blocking`** → 场景
   *The pre-release run is named* 引用 `docs/team/PUBLISH.md`，**该文件不存在**（仓里是 `docs/team/RELEASE-PUBLIC.md`
   + `tools/release-check.sh`）；同一条 requirement 至今仍写着「2000 ms 预算 / 0.75 与 0.25 前提因子 /
   median-of-five」，而 P316（已独立验收、未合并）把这套判定整体删掉了。
   **按 PM 03:44:11Z ⑤：本 change 统一更新旧性能规格与 CI 口径，不另留 P316 的规格尾巴**——一个 capability 的多条
   requirement 更新写在**同一个** delta 文件（`openspec/changes/behavior-focused-ci/specs/verification/spec.md`）里，
   不是多个 delta 文件；P316 落地后由本 change 的这段文本承接它删掉的判定，P316 自己不再单独开 spec 变更。
另外两处**不建议**动：`verification#The correctness gate judges correctness only`（性能不进正确性门禁）与
`verification#A changed-path list selects the sections to run, or the full suite`（选择器语义、`FULL` 兜底、
「全量仍是默认与交付/复验/归档门禁」）——本方案只改**谁在 CI 上用它**，不改它。

## 7. 已有事故 → 订正后的方案下仍由谁守

下表按 PM 03:44:11Z 的方向（产品基线不靠路径推导、重型自检按源变更、完整入口要能跑完）读：

| 事故 | 守它的段/断言 | 订正后仍在哪跑 |
|---|---|---|
| 安装后信号入口（0.3.0 的 npm 包缺 `scripts/shim/{pkill,killall,pgrep,pidof}` 四个 tracked 软链） | §39 `install-shape.sh`（真树 + 五组翻转红侧）+ §58 `signal-lint.pl` / `signal-gate.sh` | 产品侧：§39 由 `install-shape.sh`/`cmd-init.sh`/`cmd-project.sh`/`cmd-bootstrap.sh` 的行覆盖（实测 `--paths skills/teamsmith/tests/install-shape.sh` → 含 39），§58 由 `signal-lint.*`/`signal-gate.sh`/`team-bg-*` 的行覆盖；`install.sh` 本身选中的是 §18（「安装器唯一入口」）。**真实 npm 包与源树的逐文件等价仍是发布步骤**（`release-0.3.0.md` 记的那次比对），不在门禁里——新方案不改这一点，也不假装它被门禁守住了 |
| 身份泄漏（继承的 `TEAM_*` 静默赢过 cwd，M40） | §32（CI 30s）+ §36⑨ 的继承身份控制 + 探针 `nest()` 清身份 | §32 在产品基线里常跑；§36⑨ 属门禁自检（改 `common.sh`/`smoke.sh` 时按路径加选，实测 `common.sh` → 32、36 都在 45 个 key 里） |
| 锁互斥 / 祖先排队（P26/G1、P287、P310） | §34、§34b、§34c、§34d（CI 69+67+19+118=273s）+ §10 的 `flip-p310-lock.sh` | 产品侧（`gate-lock.sh` 是交付件），在产品基线里常跑 |
| 心跳泄漏（看门狗心跳文件被留下/被当锁） | §0e/§0f/§0g（看门狗与现场）+ §40①（临时根泄漏断言，`TMP` 消失即 tripwire） | §40 在产品基线里常跑（48s）；§0e/§0f/§0g 属门禁自检 |
| 只读面建目录（P314：`team doctor` 不许把默认根建出来） | §40④（真腿/显式根/legacy 三腿，18930 起） | 产品侧，在产品基线里常跑 |
| 跳过假绿（P222/P226/P148） | §36⑤/⑤b/⑤d/⑨/⑩ 的 `SKIP（条件不满足）` 计数、牙齿与三个影子；§19/§31/§58 的 SKIP 行；`coverage-inventory.sh --compare` | 门禁自检：只在形状机器相关源变更时跑（表里已声明，`--check` ⑥ 守着 token 覆盖）+ 每次全量（review / 手动 / 发布）。改 `lib/checkout-shape.sh`/`section-select.sh`/`smoke.sh`/`checkout-shape-probe.sh` 任一都会选中它——但**这条触发依赖路径表**，所以产品基线（§5.2）不能建在它上面 |

## 8. 不做的事 / 与其它在飞任务的关系

- **不重叠 P316**（`task/P316-delete-load-sensitive-tests`，已验收未合并）：它删墙钟判据、退役 `section-budgets.tsv`、
  改 §0e/§0f/§35/§36③。它**没有碰** `checkout-shape-probe.sh`/`section-select.sh`/`coverage-inventory.sh`，所以本报告的
  核心发现（探针 + 闭包 = 1064s）与它无关；但 §5.1 的拆段/改表要在它落地之后做（§0e 的行、§36③ 的断言文本都会变）。
- **不重叠 P317**（`task/P317-swallowed-errors-common`，只改 `scripts/lib/common.sh`）：它的行归属在 §5.5 之后仍是
  `common.sh → 45 个 key`（§32/§34*/§36 都在内），不需要额外处理。
- **不碰 P318**（原三文件清理已暂缓）：本报告不提议删任何文件。
- **不写**：新测试矩阵、调度平台、预算表、强制耗时阈值、新守卫、把 60 分钟改 120 分钟；本阶段也不写实现与规格。
- **不重跑**全量/FAST/31 套变异；不重新计时全部测试。

## 9. 未测量 / 风险（按证据说话）

- **CI 侧只有一个实测数**：探针 1064s。§3.5 的 CI 分桶是按本机投影 676s → 1064s 的**单一比值**摊派的，与总数相等
  是**构造出来的**，不是独立测量。要变成测量，得让探针在 CI 里打中间计时（那是实现，不在本阶段）。
- **3544s 不是完整运行**：109/135 段收口，26 段从未跑到（含 §58 的顶层运行）。所有按路径的求和只覆盖这个子集，
  所以「改 X 只花 N 秒」应读作「在已跑到的那部分里是 N 秒」。
- **29 次嵌套的尾段未实测**：计时实验在 328.6s 被 PM 停止（`bg.log` 记 `by=3257021`），尾段 5 次 §58、5 次 §31、
  1 次 §19、1 次 §18、`12k,31`、`12k` 是按已测同类单价推算，没有写成测量值。此后没有再启动任何计时套件。
- **本机 loadavg 22.5 / 32 核**：绝对值会偏大；结论用的是同一台机器上的相对结构（正文 vs 启动、本体 vs 闭包）与次数。
- **`--check --table` 那次红侧是纯逻辑检查**（表副本、不改树、秒级），不是运行时测量；它只证明「删声明会被 ⑥ 判红」。
- **表的窄化风险仍在**：`--check` ⑥ 只保证「段正文点名的路径被本行覆盖」，段读了却没点名的路径照样会欠选
  （`bin/team.mjs`、`ci/**` 就是这么漏的）。新口径下产品基线不依赖路径，风险因此落在「重型自检会不会被漏选」上，
  不落在产品覆盖上。
- **§5.4 的 48 分钟是投影**：它假设 §5.1 的减法落地且不减掉判决；实际数值取决于 propose 定下的减法范围。

## 10. 已裁定的与仍需 propose 定的

**已由 PM 03:44:11Z 裁定（不再由我提议）**：方案 A 不进 apply；本 change 按原 brief 统一更新旧性能规格与 CI 口径、
不另留 P316 尾巴；不以「把 60 分钟改 120 分钟」为解法；减少重复优先动 29 次嵌套本身，而不是把同一段成本搬进本地 review；
不承诺「断言一条不删」。

**仍需 propose 单定的三件事**（本报告只给代价与红侧，不给结论）：

1. **普通 CI 的产品基线怎么表达**：给表加 `kind` 列（声明式、可复核）还是在工作流里显式列 key（rot 风险）；
   以及产品基线在 §5.1 落地前能否装进 60 分钟（现在不能保证，见 §5.2：2113s 只是 109 段子集，另有 26 段未知）。
2. **§5.1 三条轴选哪条**：减少 §58 控制次数 / 拆 §58 只把静态 lint 带进嵌套 / 让嵌套 run 不带闭包。
   每条都要能说出「改坏后哪条断言仍会红」。
3. **完整入口在 §5.1 落地前怎么自称**：`workflow_dispatch` 是先保持全量（明知会超时）还是先改成有界子集并自称子集。

## 11. 验收命令（本阶段实际跑过的）

```
$ git -C <worktree> status --porcelain --untracked-files=all
(空)
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh
decision=RUN / keys=36
$ bash skills/teamsmith/tests/section-select.sh --select 58
keys=13（2,4,5,3b,6,6f,6i,13c,58 + 前导）
$ bash skills/teamsmith/tests/checkout-shape-probe.sh        # 在 /tmp/p322/root 的计时副本上，只跑到 ⑨ 就被外部 TERM 收掉
（没有 ok/bad 汇总行：探针未跑完；唯一完整的一次是 CI 里的 `✓ 36⑧ 产品面检出探针全绿（ok 146 bad 0 skip 0）`）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<本工作树> scope=published files=1807 hits=0 names=ok user=resolved
$ echo $?
0
$ bash skills/teamsmith/tests/section-select.sh --check --table /tmp/p322chk/table-no-outbox.tsv
bad: 段 36 读了它没声明的路径：token skills/teamsmith/scripts/lib/outbox.sh（源码行 18003）—— 补进该行的 patterns
$ echo $?
1
$ git diff --cached --check
(空，rc=0)
```
