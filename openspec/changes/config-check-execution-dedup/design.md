# Design

## Context

动机见 `proposal.md`。本稿以基线 `2bb1e36f` 的源码为依据，行号只定位该基线：

| 位置 | 当前事实 | 对方案的作用 |
|---|---|---|
| `tests/smoke.sh:17383–17398` | §33 无参数调用 config-cli，按 child rc 汇总 | 已有完整入口可以原样保留 |
| `tests/smoke.sh:23437–23448` | §51 再调用 `config-cli.sh list validate roster` | 唯一待删的配置子进程块 |
| `tests/config-cli.sh:110–113` | 无参数默认集合包含上述三组 | 不需修改默认组或引入排除参数 |
| `tests/config-cli.sh:16–41,61–77` | 清除继承的 TEAM 身份，私有临时根/HOME，每个 `new_proj` 新建项目 | 两次执行的隔离和初始输入同型，不依赖 smoke 共享项目 |
| `tests/config-cli.sh:116–140,343–442,582–811` | list/validate/roster 分别从自己的新项目开始 | 不是前一组写盘后再读同一项目的连续流程 |
| `tests/smoke.sh:17405–17495` | P24 路径、记录式 shim 与十四个 p24 函数在 §33 段体尾部 | 过滤副本把准备算进 §33，而非 config-cli 产生数据 |
| `tests/section-paths.tsv:149–155` | 12e–12k 的 needs 都是 33 | 删除对象恰为七条边，不碰其他真实准备依赖 |
| `tests/routes.sh:700–727` | schema 承诺分派到真实注册/撤销及审计判断 | 与 config-cli roster 不是同一测试调用，原样保留 |

本表中 `tests/` 均指 `skills/teamsmith/tests/`；规划不修改上述文件。

## Goals / Non-Goals

- 满足 delta 的两个新增 requirement，通过两处测试编排文件的小改完成。
- 不抽取产品规则，不改变配置写入器或独立配置测试默认集合；不处理 routes/help 自身的重复或模型路由、夜间/二阶段配置。
- 不新建测试平台、选择器语法、缓存或测试专用产品参数；不因本批重新统计全仓或重跑全量基线。

## Decisions

### 1. 保留 §33，删除 §51 的配置子进程

旧研究建议把三个组留在 §51、令 §33 显式列其余组。本稿改选 §33：现状已有一个完整无参数调用，删 §51 一块即可；反向需要维护“全部默认组减三组”的第二张参数清单，今后加组容易漏掉。任务允许按最小改动选择位置，未改变三个组全量 2→1 的目标。

删除 §51 的 `if [ -f .../config-cli.sh ]` 整块（包含 P99_ROSTER_RC、成功/失败/缺文件分支），同步该段头部说明。保留 §51 的 routes `walk control promises refusals` 与 help-surface 调用，尤其保留 `mr_promise_roster` 的真实注册、审计与撤销。正常完整运行中，由33的无参数入口执行完整配置一次，51不再追加；独立选段中，选中33才执行它的完整入口。**不加 `51 needs:33`**；单选51或12e–12k不因这条约定带入配置执行。

同态核对不是按名称猜测：

- 两个父调用使用同一 `$SKILL_DIR/tests/config-cli.sh`，没有为第二遍指定另一产品树、语言或配置文件。子脚本先保存调用者显式 `TEAM_CONFIG_TREE/KEEP`，再清理 TEAM 身份；smoke 无针对两处的不同 tree 设置。
- 两遍 argv 不同（无参数与三组），但 `want` 对这三组只判断是否入选，组正文和参数完全相同；没有“这是 §51”分支。
- list/validate/roster 各自 `new_proj`，HOME 在每个子进程自己的临时根下；先前 writer/groups/cas 使用别的项目，没有给它们提供状态。两遍临时目录的绝对名不同，这不是待测条件变化。
- validate 内的原状/破坏/恢复三次子调用显式带不同 `TEAM_CONFIG_TREE`；不能按同名删。此处只删除第二次顶层三组入口，内部所有不同树的证据不动。

### 2. 直接移动既有准备块，不建立新助手框架

把从 `P24_ROOT="$TMP/p24"` 到 `p24_read` 定义结束的既有完整准备块，从 §33 尾部移至首个 `section` 之前、TMP/TEAM/P235_MODELS/JS_RUNNER 均已定义的位置（当前可在 `mkfile_meminfo doomed ...` 后、`SG_LOCK_NOTE` 前）。这是一次块移动，不改十四个函数体和七个消费者。

真实准备仍有三条路径赋值、创建目录、生成/chmod 记录式 tmux shim；不能只移动函数而忘掉这些文件。它们由本次运行自己的 TMP 建立，未启动场景、未执行 config-cli，也没有读取其日志或产物。代价是任何选段的前导多生成一个很小的既有 shim，与现有 fake pi 准备同形；不为省这份小准备再加懒加载状态、缓存或初始化守卫。

各消费者的实际项目入口为：12e 的 ready/notready/squash-merge/weird-paths；12f 的普通/many/none；12g、12h、12i、12k 的同名项目；12j 的普通/checklist/archived。它们均经 `p24_project` 新建，使用自己的名字；没有消费者读取 `config-cli.log` 或 `p99-roster.log`。P24_SHIM_LOG 是既有调用记录，`p24_dispatch` 在每次派单前清空，不是跨用例结果缓存。git/worktree、真实 CLI 及各段 `[real]` 可用性规则不改。

因此删除 `12e→33`、`12f→33`、`12g→33`、`12h→33`、`12i→33`、`12j→33`、`12k→33`，七行 needs 从 `33` 改为 `-` 并更新依据。其他 needs 原样保留。移动块没有带 sleep 的 while 循环；loop 清单按出现顺序/原文锚点而非行号配对，纯移动不需要改 `loop-inventory.tsv`，用既有 `--loop-check` 核对。

### 3. 只修与删除调用有关的路径归属

| 路径输入 | 改后的必要归属 | 具体表变化 |
|---|---|---|
| `skills/teamsmith/tests/config-cli.sh` | 33，不再因配置子进程带 51 | 从 51 的 patterns 删除这一 token；33 已声明它 |
| `skills/teamsmith/scripts/lib/cmd-config.sh` | 33 与 51 | 给 33 加此产品路径；51 保留它以覆盖 routes 的配置承诺 |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | 33 及现有派单消费者 | 33 已声明；七段各自已有 patterns 不改 |
| `skills/teamsmith/tests/task-header-model.sh` | 12e 及其真实准备，不自动执行33 | 删除 needs 后仍按原精确模式选择12e |
| 未声明路径如 `ci/config-dedup-unclaimed` | FULL | 不增加模式或豁免 |

§33 既有的 openspec/cmd-docs/cmd-project 等保守模式本批不缩窄；移动准备不会引入相反的路径漏选。准备在共同前导，任何受影响选段都会带入它；不为它新增表行/section。第 51 段仍有两套与配置重复不同的真实检查，不能删段或整体改为“已由33覆盖”。

### 4. 删除账与成本口径

下面顶层调用/组的2→1只针对正常完整运行；独立选择按实际所选段执行，不要求每次单选都有33。

| 删除对象 | 改前 → 改后 | 不可冒称的收益 |
|---|---|---|
| 顶层 config-cli 子进程（33+51） | 2 → 1 | 不是全部配置 CLI 命令只执行一次 |
| list/validate/roster 顶层组执行 | 各 2 → 各 1，合计 6 → 3 | 不删除各组内部不同输入/不同树的调用 |
| 纯准备 needs 边 | 7 → 0 | 不是完整运行少了7次33；完整运行本来只有1个33段 |
| 配置组/独立默认组/不同树红绿证据 | 不删 | 不把断言数减少当性能证据 |
| 产品守卫/测试段/框架/配置项 | 新增0 | 不新增永久结构来证明本次移动 |

沿用已有研究的成本分类：旧 P432 样本中33为127s，51整段640s；只读较新 `/var/tmp/rel47-first-order.log` 的源序收口记录为33 **148s**、51 **681s**。后者的末尾排行重复摘录不再计数。它们都是整段读数，51还含 routes/help，33还含其他配置组，**均不能当作删除三组的节省**。本轮不量新秒数；单选12e–12k少带33是局部执行量收益，不加入完整运行收益。不混入夜间模型路由节省。

## Risks / Trade-offs

- [直接按旧研究的分组建议列剩余 argv，会复制默认集合] → 本稿保留无参数33，独立默认组逐字节不动。
- [只挪函数导致 shim/路径缺失] → 整块移动，七个键分别从新TMP运行；不靠合跑掩盖缺准备。
- [配置产品改动不再选中唯一执行点] → 33补cmd-config精确归属，核对改后计划和实际执行；保留51真实承诺归属。
- [移动源码影响已有文本锚点] → 使用已有 section-select/loop 检查；不改 assertion/循环上限以求绿，若出现真实额外数据依赖则停止删对应边并交PM。
- [旧外层只显示1条成功，容易漏看组内容] → 实施报告读取真实child日志的组名及具名断言；33按child非零失败的父级逻辑保留，不追加计数守卫。

## Migration Plan

一个后续 apply brief 足够：先按§1删除重复块和更新路径归属并小步提交；再按§2移动准备、删七边并提交。两项同批是因为都只改既有 smoke 编排/表，不改变配置接口，验证也共用该批选段；并不要求一种调整等待另一种的运行结果。

本稿下面是**未来实施/独立验证命令，不是P460已运行记录**。应在PM准备的独立检出、钉住环境内跑实际段；长作业用 team_bg_run，单批串行，不重跑全量/61b/meta/夜间。当前P460只执行tasks中的规划静态检查。

```sh
export PATH="$HOME/.bun/bin:$PATH"
CI=1 OPENSPEC_TELEMETRY=0 openspec validate config-check-execution-dedup --type change --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/section-select.sh --self-sufficient
bash skills/teamsmith/tests/section-guard.sh --loop-check
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/config-cli.sh
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/task-header-model.sh
bash skills/teamsmith/tests/section-select.sh --paths ci/config-dedup-unclaimed
for key in 12e 12f 12g 12h 12i 12j 12k; do
  bash skills/teamsmith/tests/section-select.sh --select "$key" || exit
 done
```

后续实施/独立验证采用以下最小表，不默认执行完整51、额外完整config-cli或坏树默认集合。正常完整运行的单位置保证由33真实执行、51删除块及原调用字节比较共同取证；七个独立选段则仍须分别运行，不能用合跑或静态计划代替。

| 后续验证 | 本批证明什么 | 最小安排 |
|---|---|---|
| 正常33 | 完整无参数入口、默认组与真实CLI/写盘/拒绝仍在 | 一次 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null`，保留真实child及嵌套日志，不另跑无参数config-cli |
| 51剩余routes/help承诺 | 删除最后配置块没有改到前面的调用或其输入 | 核对接受基线到实现的两套子调用及汇总分支字节、顺序、输入；config-cli/routes/help-surface三脚本保持原字节；沿用绑定下述来源的真实局部日志，不默认重跑51。实际发现消费源码/输入变化，才按具体差异补原入口 |
| 12e–12k | 公共准备在独立副本可用，不带33，真实项目/live前提仍成立 | 七次 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select "$key" </dev/null`，每次新TMP，key分别为12e–12k；保留具名执行及原条件披露 |
| validate/refuse与writer | 保留的字节/拒绝断言仍能发现已知故障 | 复用同轮正常33生成的 `refuse-flip-green0/red/restored.log` 与 `flip-red/green.log`，核具名TEAM_PROJECT/注释失败和恢复rc；不额外单跑validate/writer。日志缺失或不覆盖具名故障时，仅补缺的一腿 |
| roster假成功 | 注册返回成功却不改名单会被真实字节断言发现 | 一个scratch坏产品树单跑 `TEAM_CONFIG_TREE=<scratch-product-tree> bash skills/teamsmith/tests/config-cli.sh roster`；正常/恢复复用同轮33和产品树字节还原证明，不重跑完整配置 |
| 配置child→33失败 | 原父级通用非零分支没有吞错 | 比对父级分支原字节；仅以真实config-cli短setup失败走一次33，见下方命令，不再跑完整坏树默认集合 |
| 缺准备 | 必要定义缺失不能空跑为绿 | 仅移除不负责项目根创建的 `p24_brief` 定义；保留 `p24_project/p24_change`，坏腿单选12e，恢复复用正常独立12e及字节还原证明 |
| 选择与循环结构 | 两token/七边退休且副本自足 | 上方既有选择器/循环静态命令各一次，核删除块与段边界；不新增检查器 |

原51证据来源为 `/var/tmp/rel47-first-order.log`，日志绑定提交 `572856a3ae57503396019020f58e8e6abcc08db4`，全轮rc=1，不能把局部成功改称完整套件通过。V166已用Git原件核对该提交到候选5ab4f040的三脚本与相关父调用区域字节相同；后续必须继续核对接受基线到实现的同一性及期间产品/消费源码差异，不能只引用“先前已通过”。对应三脚本SHA-256：

```text
config-cli.sh    a4a018b5c4a883e6929b95634dbcc32adf7cf489a40a5ebdcf1568c11a91a88c
routes.sh        0d1000f46c1a2f6045142a75d477fd6a205a6f935a9dcb5ce7637c6a532df2da
help-surface.sh  2ea27c25d7aabf25b95e103d966e4f8b49e6ca265b79da29999d28ff7c964b98
```

原局部日志中的routes/help由原父级标为成功（routes有1条可见跳过）；它们不是本轮重跑。复用须分别核对父调用/汇总字节、输入条件、三脚本字节，并逐项审出期间产品/消费源码差异是否影响这些检查；不要求无关版本号或注释也逐字相同，更不能不审差异就沿用。只有实际影响该证据的差异才补真实原入口，不把整段51重跑设为默认要求。正常33的child日志须含完整默认组具名组头，不能只看外层✓计数。

父级短setup失败的未来命令如下，**本轮不执行**：

```sh
empty_tree="$(mktemp -d -p /var/tmp config-child-no-cli.XXXXXX)"
TMPDIR=/var/tmp TEAM_CONFIG_TREE="$empty_tree" \
  bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null
# 预期真实config-cli因空树缺CLI而setup rc=3，33报告child失败、smoke非零。
# 收取日志后只按本轮打印的具体路径清理empty_tree/临时根，不按项目通配删除。
```

这条只证明真实setup失败的传播，不冒称产品assertion rc=1已重跑。真实拒绝/注释assertion红侧来自同轮正常33嵌套原件；父级对所有非零统一处理，以原分支字节不变连接两项证据。若父分支实际变动，按该差异补验，不再直接沿用此前提。

缺准备负例只在独立scratch检出删除 `p24_brief` 定义，再运行 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select 12e </dev/null`。必须保留 `p24_project/p24_change` 及路径/shim准备：项目根仍由真实准备创建，不能删project使空变量落到绝对根路径。坏腿须非零、点名缺定义并有具名行为失败；恢复定义逐字节后复用同轮正常独立12e结果，不重复七键，不新增产品或测试防护设施。

这些对照替代重复运行的证明职责，不新增长期守卫。若现有环境缺少 `[real]` 所需前提，原规则具名披露，不能报该分支已验；必要时由PM补授可用环境。不能把上述计划或原日志复用当作本轮已执行；整轮正常完整运行改后耗时仍留给下一次原定完整运行记录，不为本小批另开全量。

回退仅撤销上述两处测试编排文件的本批diff，不改产品或配置；若独立单选缺定义、真实前提被误删、唯一路径漏选或父级吞错，则在合并前返修/保留原执行，不用新跳过或扩大写集绕过。