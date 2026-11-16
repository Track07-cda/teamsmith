# V166 · 配置检查去重提案独立审阅

agent: verify   status: DELIVERED — proposal review: ACCEPTED   time: 2026-11-16T09:34:55Z
branch: `task/V166-config-dedup-proposal-review`   PR/MR: -
current candidate: `1589612c4ff9b97e340224ad8958fc25f3e38935`
current review root: `/var/tmp/p460-review-1589612c`
first-round candidate: `5ab4f040ada9b4b3052e7736c29735863f0fb740`（规划 `b00853dc`），检出 `/var/tmp/p460-review-5ab4f040`

## 当前判定：ACCEPTED，仅限提案

R1–R3 均已在四文件返修中闭合，未发现附带范围变化；第二轮证据与逐项结论见末节。接受的是后续实施方案，不是删除已经生效、行为已验或归档就绪。本轮没有重跑首轮源码调查、十一份选择计划或未来实施测试。

下面保留首轮 REWORK 及当时三项 WARNING 的完整事实；旧的建议返修文字是历史记录，不代表当前仍有三项未关闭。

## 首轮判定：REWORK（2026-11-16T09:14:25Z）

**两项精简的源码依据成立，但应先修订验收安排、完整运行的表述和缺准备负例，再接受规划。** 保留 §33 完整无参数入口、删 §51 第二次三组调用，比另维护“默认组减三组”清单更小；完整移动准备块也可以退休七条仅为定义的依赖边。三项 WARNING 只改变后续规划，不要求修改产品或扩大实施写集。

本 change 的 OpenSpec 1.16 严格结构、spec-refs、十一份现状选择计划及本报告账本检查实际通过。格式合法不消除 R1–R3。未执行未来实施的 smoke、配置组或变异，不能据此称删除已生效、选段已独立运行或已经节省时间。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V166-verify.md` | 本任务唯一写入：非作者审阅、具体反例、最小修订与真实检查回执 |

候选相对 `2bb1e36f` 的 `git diff --stat` 只有 change 的五个工件及作者报告，共六文件；没有产品、测试或正式 spec 差异。独立检出的 HEAD 与指定候选完全相同，`git status --short` 无输出。本席位只手工写自己的报告，未改候选、主检出源文件、提案、产品、tests、正式 spec、配置或远端；后台工具生成的共享运行时记录单列于实际回执之后。

## 逐项源码结论

### 1. 两个顶层配置入口：可以去重，内部不同输入不删

- `smoke.sh:17383–17398` 无参数调用同一 `$SKILL_DIR/tests/config-cli.sh`，根据 child 退出状态报告成功或失败；`:23437–23448` 再调用 `list validate roster`。不存在两处不同的产品树或参数环境赋值。
- `config-cli.sh:18–41` 先保存显式 TREE/KEEP 再清除 TEAM 身份，每个子进程建立私有 TMP/HOME；`:110–113` 默认集合确含三组，`want` 仅判组是否入选。`:118,345,584` 分别 `new_proj list/validate/roster`，先前 writer/inject/CAS 修改的是别的项目。两遍的绝对临时目录不同，但没有提供另一组待测条件。
- 无参数集合原样保留的是 `list groups writer inject cas validate seam audit roster models shape flip-shape model-window flip-model-window seats completeness docs callers flip groups-flip json`，不需要新排除参数。list 的 JSON/指纹、writer 的文件注释与引号、CAS/审计、validate 的拒绝与文件不变性、roster 的注册/撤销/脏名册/token 形状均仍在原组内。
- `config-cli.sh:397–440` 的 validate 正常/破坏/恢复三次子调用显式使用 scratch 产品树；`:1467–1511` 的 writer 红绿也使用不同产品树。这些不是第二个顶层入口，不能计入删除账。
- `routes.sh:700–727` 的 `mr_promise_roster` 另做真注册、审计、真撤销；§51 的 `routes.sh walk control promises refusals` 与 help-surface 调用都在待删配置块之前，不能按 roster 同名删除。

**对结论的影响：** 赞同保留 §33、只删 §51 最后一个配置块；不加 `51 needs:33`，不删独立默认组或 routes 承诺。正常运行仍按 child rc 判定，不能用外层 `✓1` 替代具名子结果。

### 2. 准备块：位置和输入成立，七段不是读取配置测试结果

`smoke.sh:17405–17495` 实际包含三个路径变量、mkdir、tmux 记录脚本的生成/chmod，以及十四个函数：

```text
p24_project p24_change p24_brief p24_add p24_team p24_dispatch
p24_shim_windows p24_branch p24_wt p24_pass p24_board_row
p24_unchanged p24_json_ok p24_read
```

候选提出的插入点在 `mkfile_meminfo doomed` 后、`SG_LOCK_NOTE` 前（`:1821–1825`）；此时 TEAM/P235_MODELS 已在 `:57–60` 定义，TMP/REPO/FAKE 在 `:1241–1246`，JS_RUNNER 在 `:1779–1781`，断言及 live_mark/FAST/HAVE_TMUX 准备也已就绪。该位置早于首个真实 `section "0 · …"`。选择器 `run_src_spec/emit_copy`（`section-select.sh:561–625`）总保留首 section 之前的源码，故不必执行 §33 才能取得该块。它增加的只是同轮小 shim 文件，不创建场景项目、不调用 config-cli，也不需要懒加载或公共框架。

| 消费段 | 自己创建的项目与独有消费 | 真前提仍需保留 |
|---|---|---|
| 12e | ready/notready/squash-merge/weird-paths；头读取、状态与真实 git 内容比较 | task-header-model 子入口、git/worktree；p244 助手仍在本段 |
| 12f | 普通/many/none；digest、真实 changes JSON、面板帧 | node/bun 可用性及既有条件披露；meminfo 在公共前导 |
| 12g | `p24_project 12g`；锚读取、拒绝及允许派单 | 原 `[real]` FAST/HAVE_TMUX 分支与 live_mark，不改为 shim 证明 |
| 12h | `p24_project 12h`；delta 冲突、审计和真实 monitor | 原 `[real]` 写盘分支、自造 pi 及真实 tmux |
| 12i | `p24_project 12i`；作者隔离、dropped、force | 自己创建任务/分支/worktree，不取前段名单或状态 |
| 12j | 普通/checklist/archived；归档状态与未完成清单 | 各自创建活动/归档目录，不取前段产物 |
| 12k | `p24_project 12k`；模板、读取器、文档/生成段落 | 原 AGENTS 检出形状条件；不误报产品面缺席已验证 |

七段正文未读取 `config-cli.log`、`p99-roster.log` 或 §33 配置子进程的目录。P24_SHIM_LOG 只是本轮调用记录，`p24_dispatch` 每次清空；项目均由 `p24_project` 创建，不是另一选段的可写结果。

**对结论的影响：** 可以把完整块移至该公共前导、七条 needs 改为 `-`，其余函数/消费者正文及 live 条件原样保留。具体实施后的七个独立运行仍未验证；不能用本次读源码替代它们。

### 3. 路径与七条依赖：拟改账完整，没有理由扩大模式表

实际 `section-paths.tsv:149–155` 逐行为 `12e/12f/12g/12h/12i/12j/12k → 33`，依据均写为 p24 定义；没有第八条准备边。`:148` 的 33 已声明 config-cli、cmd-docs、cmd-agents、cmd-project、team 及 openspec，却缺 cmd-config；`:177` 的 51 同时声明 config-cli、cmd-config 和 routes/help 相关来源。

| 路径 | 应保留/修正的归属 | 判断 |
|---|---|---|
| `tests/config-cli.sh` | 33；只从 51 patterns 退休该 token | 唯一配置入口不漏，其他保守消费者不缩 |
| `scripts/lib/cmd-config.sh` | 给 33 补精确 token，51 的 token 不删 | 配置行为与独立 routes promise 都有执行位置 |
| `scripts/lib/cmd-agents.sh` | 33 及原派单消费者 | 本批不借此重做表；现有 12g/12h/12i 等保留 |
| `tests/task-header-model.sh` | 12e；不再通过 needs 带入 33 | 段内原真实入口仍在 |
| 未声明路径 | FULL | 不加模式、豁免或缩选开关 |

表中的路径省略了共同前缀 `skills/teamsmith/`。本批操作应严格限于两个归属 token 和七条 needs/basis；不改 first-order/meta、其余 needs 或 CI。下节十一份实际选择计划仍显示现状七边和双入口；上述是逐行源码判断，不是改后计划实测。

### 4. 成本账：结构减少成立，秒数未测

已只读原日志 `/var/tmp/rel47-first-order.log`。其头尾均绑定 `572856a3ae57503396019020f58e8e6abcc08db4`、整次 rc=1；原全局失败不能改称全绿。源序记录给 §33 148s、1/0，§51 681s、3/0；尾部排行重复的一行不重复计数。原段中真实记录为：配置 349 条、routes 255 条且 1 条可见跳过、help-surface 132 条、第二次三组 137 条，均由当时父级标为成功，不是本席位重跑。

我另用 Git 原件逐字节比较该日志提交与本候选：config-cli/routes/help-surface 三脚本及 smoke 的 33→12e、51→51m 两段区域均相同。三脚本 SHA-256 为：

```text
config-cli.sh    a4a018b5c4a883e6929b95634dbcc32adf7cf489a40a5ebdcf1568c11a91a88c
routes.sh        0d1000f46c1a2f6045142a75d477fd6a205a6f935a9dcb5ce7637c6a532df2da
help-surface.sh  2ea27c25d7aabf25b95e103d966e4f8b49e6ca265b79da29999d28ff7c964b98
```

不声称整个产品树相同：四个产品文件相对旧日志有 13 增/6 删。已读 diff，分别是 common 版本号、cmd-project 的生成命令定位、cmd-review 的根路径显示、cmd-watch 的示例注释；不是 routes/help/config 解析规则改变。原 V161 报告记录了该批组合证据的边界，未来实施仍须以接受基线核对同一性，不能仅引用旧报告一句“通过”。

**对结论的影响：** 静态账只认顶层配置子进程 2→1、三个顶层组各 2→1、准备边 7→0。七段少带 33 是独立选段收益，完整运行原本仅一个 33，不能乘七；148s/681s 都不能分摊成三组已测节省。保留无参数 33 不增加第二张默认集合，确是更小做法。

## CRITICAL

None — 只审规划。上述两项删除对象有源码依据，未发现必须改变产品/架构的阻塞；不因此给实现或归档通过。

## WARNING

### R1 · 验收额外重跑未变化的 11 分钟段，并重复已有红绿

**证据：** design Migration Plan 和 tasks 1.3 强制 `smoke.sh --select 33,51 --keep`；51 的 681s 中 routes/help 两个调用及脚本均不改，待删块又是它们之后最后一个块。接着又要求 roster/validate/writer 各自坏/恢复，再以坏产品树执行一次完整 33。正常 33 已无参数包含 validate 内部的正常/坏/恢复及 `flip` 的旧 writer 红/新 writer 绿（源码 `config-cli.sh:397–440,1467–1511`）。tasks 3.1 说不重复“帮助/路由完整矩阵”，却不能消除 1.3 明列的整段真实成本。

**反例/影响：** 删除 51 最后一个配置块，既不改前面的两个调用，也不给它们改变输入；强制再花一轮完整 51 不是在验证一个新行为。额外单跑 validate/writer 又重复同轮 33 已有的坏/恢复。若父级坏树再执行完整默认集合，还再支付一份 33。上述成本不能记作产品必须保留的覆盖；这项改变后续验收范围，不改变保留的产品测试内容。

**最小修订：** 将 design/tasks 的硬性组合命令改成下表；不删正常完整套件里的 51，也不改永久断言/超时/框架。原 routes/help 证据沿用须绑定原日志、SHA、父调用与消费源码同一性，并逐项审出基线后差异。

| 后续验证 | 本批证明什么 | 最小安排 |
|---|---|---|
| 正常 33 | 唯一调用仍完整、默认组与真实 CLI/写盘/拒绝未丢 | 一次 `TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null`；保留 child 及嵌套日志，不额外无参数 config-cli |
| 51 的剩余承诺 | routes/help 调用及输入没被删错/改写 | 对比接受基线与实现：两个子调用/汇总分支原字节、顺序、输入相同，三脚本同字节；原真实日志沿用。删除块/段边界/选择计划静态核对；不默认重跑完整 51。发现剩余块或消费源码真实变化，才按该差异补原入口 |
| 七个独立键 | 新前导在每个过滤副本可用、没有 33、自己的项目及 live 前提仍成立 | 保留七次独立 `smoke.sh --select <key>`，每次新 TMP；它们消费不同文件/项目/条件，合跑或只查表不能替代 |
| validate/refuse、writer | 保留执行位置仍能发现原已知坏行为 | 复用本次正常 33 已产生的 `refuse-flip-green0/red/restored.log` 与 `flip-red/green.log`，核具名 TEAM_PROJECT/注释失败及恢复 rc；不再额外跑这两组。若实际日志未保留或没覆盖具名故障，再只补缺的一腿 |
| roster 假成功 | 注册返回成功但未改名单时，留下的真实字节断言能发现 | 一份 scratch 坏产品树单跑原 `config-cli.sh roster`；未坏基线/恢复复用正常 33 及字节还原证明，不重复完整配置 |
| 配置 child→33 失败 | 父级没有吞掉子退出失败 | 保留原父分支字节比较；用真实 config-cli 的短 setup 失败走一次真实 33，见下方命令。正常 33 里已有真实 assertion 红侧，原父分支不按具体非零码分流，不需为了证明该分支再全跑一次坏树默认集合 |
| 缺准备 | 不因无定义空跑为绿 | 一个不破坏项目根创建的必要定义负例，见 R3；恢复复用正常独立 12e，不重跑七次 |
| 选择/循环结构 | 两 token、七边退休且副本结构仍合法 | 原 `section-select --check/--self-sufficient`、路径/七键计划及 `section-guard --loop-check` 各一次；不另建检查器 |

父级短样本可在实施后的独立环境按原函数/入口执行如下命令；**这是建议，V166 未执行**：

```sh
empty_tree="$(mktemp -d -p /var/tmp config-child-no-cli.XXXXXX)"
# 真实 config-cli 自己因没有该树的 CLI 返回 setup rc=3；不是成功替身。
TMPDIR=/var/tmp TEAM_CONFIG_TREE="$empty_tree" \
  bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null
# 预期 smoke 非零、33 报 child 失败，子日志点名缺 CLI。
# 按打印的本次具体路径收证据并清理 empty_tree/临时根。
```

这条只证明真实 setup 失败的传播，不冒称重跑了产品 assertion rc=1；后者的拒绝/注释红侧由同轮 33 原有嵌套证据承担，父级通用非零分支再以字节同一性连接两项证据。若实施竟改动父分支，本轮替代前提不成立，按实际差异补验，不扩成固定新守卫。

### R2 · “normal smoke run”仍可同时解释为完整运行或正常独立选段

**证据：** delta 第一 requirement 首句是 `The normal smoke run SHALL execute ... once, through section 33`，没有 complete/full 限定；第二 requirement 又要求正常的独立 12e–12k 不执行 33。design §1 明说单选 51 不承担配置检查，tasks 2.2 也要求七个独立调用无 33。

**反例/影响：** 正常非 FAST 的 `--select 12e` 或 `--select 51` 按 design 都不执行 33，却违反首句对 normal run 的无条件一次承诺。具体场景虽写 33/51 合跑，没有消除 requirement 正文歧义；本项改变规格表述和实施验收解释，不改变运行行为。

**最小修订：** 首句明确“正常完整运行中，33 的完整无参数入口执行一次；51 不再追加”。再明写独立选择不强行加入 33：选中 33 才执行其完整入口，单选 51 或 12e–12k 不因本约定带入配置执行。design/tasks 用同一组术语。不要为满足错误表述增加 needs。

### R3 · 删 `p24_project` 的负例会把后续路径变成绝对根路径

**证据：** design Migration Plan 第 3 项指定删除 `p24_project` 后执行 12e。源码 `smoke.sh:17506` 的 `P24E_R="$(p24_project 12e-ready)"` 没有立即停止分支；定义缺失时变量为空，下一行仍调用 `p24_brief "$P24E_R" ...`。`p24_brief`（`:17427–17440`）直接 `mkdir -p "$p/docs/team/tasks"` 和重定向，`p24_pass` 也直接拼接 `$p/docs/team/reviews`。

**具体反例/影响：** 此时路径成为 `/docs/team/tasks`、`/docs/team/reviews`，而非本轮 scratch 项目；普通权限下可能拒绝，目录可写时就可能写出实验范围。把源码拷到 scratch 不会限制这些绝对路径。该负例也可能主要得到越界路径报错，而非所需的缺定义反证。本轮只静态追踪，没有执行这一负例或写那些路径。

**最小修订：** 不加新产品/测试守卫，换删 `p24_brief` 等不负责项目根创建、但 12e 确实需要的定义；保留 `p24_project/p24_change` 使后续所有项目路径仍由真实准备创建。核对该负例实际非零、缺定义被点名并有具名行为失败；恢复后复用独立 12e 正常结果。delta 只要求移除一个必要定义，不要求一定是 project，故无需扩写规格或新建隔离平台。

## SUGGESTION

None — 不提出与本批无关的新优化、自检或框架。

## OpenSpec assessment

本轮是 proposal review，不是实现的 opsx-verify。提案者未勾实现任务符合规划阶段，不能据此判实现遗漏，也不运行默认 `team review` 全量。

| Dimension | 当前评估 | Evidence |
|---|---|---|
| Completeness | 两项范围都有 delta 与 tasks；实施未开始 | 五工件齐全，1.1–3.2 全未勾；删除账/七段/路径落入任务 |
| Correctness | 源码依据成立，未来验收需 R1/R3 修订 | 同输入、私有项目、十四函数输入与消费者已逐条读；未执行改后行为 |
| Coherence | R2 尚存，结构合法 | normal 正文与独立选段承诺有具体反例；本 change 严格结构 rc=0，不能把格式通过当语义闭合 |

## Verification evidence

### 已完成的只读检查

```text
$ pwd; git status --short; git branch --show-current; git log --oneline -5
<本席位工作树>/.worktrees/verify
# status 无输出；当前分支 task/V166-config-dedup-proposal-review
# 起点 e4eb00f6
$ git -C /var/tmp/p460-review-5ab4f040 status --short
# 无输出
$ git -C /var/tmp/p460-review-5ab4f040 rev-parse HEAD
5ab4f040ada9b4b3052e7736c29735863f0fb740
$ git diff 2bb1e36f 5ab4f040ada9 --stat
# 五个 change 工件 + P460 作者报告；6 files changed, 349 insertions(+)
$ command -v openspec; openspec --version
# 初始 PATH 未解析到；openspec: command not found，127
$ "$HOME/.bun/bin/openspec" --version
1.16.0
```

源码与旧日志的读取/字节比较由只读 Python、Git、rg 完成：使用 Git 原 blob 比较，不只比摘要；原日志不是 UTF-8 全流，首次严格解码读取失败后改用 bytes 去 ANSI、仅对显示行 decode replace，未改原日志。结构检查将显式前置既有工具路径，不安装/升级或改用户配置。

### 本席位后台实际回执

作业 `v166-planning-checks` 从自己的 verify 工作树启动，已实际收割：**exit=0，23.9s**，末行 `V166_PLANNING_CHECK_FAILURES=0`，每个子命令分别记录 `CHECK_RC=0`。未启动真实 smoke 或模型。OpenSpec 只在子进程指定候选 cwd；spec-refs/选择器使用显式 root，未切当前任务分支。

```text
$ export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
$ openspec --version
1.16.0
# rc=0
$ python3 -c 'import os,subprocess,sys; root=sys.argv[1]; print("VALIDATE_CWD="+root,flush=True); sys.exit(subprocess.run(["openspec","validate","config-check-execution-dedup","--type","change","--strict"],cwd=root).returncode)' /var/tmp/p460-review-5ab4f040
VALIDATE_CWD=/var/tmp/p460-review-5ab4f040
# SPEC_ROOT=/var/tmp/p460-review-5ab4f040/openspec
Change 'config-check-execution-dedup' is valid
# rc=0
$ bash /var/tmp/p460-review-5ab4f040/skills/teamsmith/tests/spec-refs.sh --check --root /var/tmp/p460-review-5ab4f040
spec-refs: judged 122 reference(s) (49 distinct) in 14359 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
# rc=0
```

未运行全项目普通/strict validate，也不以作者的全项目普通回执代替它。

实际选择命令统一为 `bash /var/tmp/p460-review-5ab4f040/skills/teamsmith/tests/section-select.sh --root /var/tmp/p460-review-5ab4f040 <参数>`，不是 smoke 执行：

| 实际参数 | 实际输出 | rc |
|---|---|---|
| `--select 12e` | RUN，141 段，6 keys；33 ← needs:12e | 0 |
| `--select 12f` | RUN，141 段，6 keys；33 ← needs:12f | 0 |
| `--select 12g` | RUN，141 段，6 keys；33 ← needs:12g | 0 |
| `--select 12h` | RUN，141 段，6 keys；33 ← needs:12h | 0 |
| `--select 12i` | RUN，141 段，6 keys；33 ← needs:12i | 0 |
| `--select 12j` | RUN，141 段，6 keys；33 ← needs:12j | 0 |
| `--select 12k` | RUN，141 段，6 keys；33 ← needs:12k | 0 |
| `--paths skills/teamsmith/tests/config-cli.sh` | RUN，8 keys；含 33、51，另有原有 12b-h0d/40 | 0 |
| `--paths skills/teamsmith/scripts/lib/cmd-config.sh` | RUN，21 keys；含 51、不含 33 | 0 |
| `--paths skills/teamsmith/tests/task-header-model.sh` | RUN，8 keys；12e 直接入选、33 因 needs 入选 | 0 |
| `--paths ci/config-dedup-unclaimed` | FULL，keys=0，点名无任何行声明此路径 | 0 |

七个 6-key 计划均为四个前导 + 33 + 对应键；未写改后表、未把计划中的 FULL 真执行。

### Ledger ban 与 diff-check

初稿已暂存并提交为 `4f71366b` 后，在同一工作树运行了固定命令：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree>/.worktrees/verify scope=published files=2751 hits=0 names=ok user=resolved
# CHECK_RC=0
$ git diff --cached --check
# CHECK_RC=0，无输出
$ git diff --check
# CHECK_RC=0，无输出
$ git -C /var/tmp/p460-review-5ab4f040 status --short
# CHECK_RC=0，无输出
```

`root` 的家目录前缀仅作显示省略；实际扫描本席位自己的分支，包含本报告。补入本轮回执后已经重新暂存，再次运行同一固定命令：`files=2751 hits=0 names=ok user=resolved`、`FINAL_LEDGER_RC=0`；`git diff --cached --check` 和 `git diff --check` 均无输出、`FINAL_DIFF_CHECK_RC=0`。另运行 `git diff HEAD --exit-code -- skills openspec/specs .github AGENTS.md` 无输出，`PROTECTED_SOURCE_DIFF_RC=0`。本次收尾命令的实际 UTC 为 `2026-11-16T09:14:25Z`，不是沿用初稿检查代替新增正文。

### 工具自动记录的副作用

启动/收割工具明确将日志写到主检出的 `.pi/team/state/bg/v166-planning-checks.log`，启动 cwd 仍为 verify。该共享运行时记录不是本席位手工改主检出源码或 ledger；本席位不修后台工具、不清理共享记录。后台完整输出在该日志，关键回执已抄入本报告。

## 首轮 Final assessment（历史）

- Verdict：**REWORK**。Counts：CRITICAL **0** · WARNING **3** · SUGGESTION **0**。
- Readiness：源码支持两项最小精简；规划格式检查通过。R1–R3 修订前不建议 PM 接受并派 apply；这不是实现或归档就绪判定。
- 任务书要求的本轮结构/引用/报告检查已实际执行；未把未来实施验收的任何一项称为已执行。

- 未验证：删除调用、移动准备、改后七键与 33/51 的真实执行、坏/恢复、合并版行为、优化秒数。V166 明确禁止这些未来实施验收。
- 未运行：全量、FAST 全量、meta/61b/夜间、完整 help/routes/config、安装、真实模型、试归档或发布；本轮不作完整测试通过声明。

## Flip evidence

N/A — 本轮没有修复实现，也没有执行未来变异；R3 为源码可推导反例，未冒称动态复现。R1 建议的日志复用/短样本均为后续安排。

## Decisions and deviations

- 只提交本报告；正式 proposal review、任务书、看板与后续派单由 PM 处理。
- P432 §3.3/3.4/4C 的保留底线继续适用；赞同按 P460 明授范围保留 33，而非复制“默认组减三组”。
- 不通过暂停永久检查、缩短超时、改 FAST、假成功替身或增加平台来减少本批验证成本；R1 只退休与本次差异无关的额外重跑。

## Suggested next steps

首轮建议为：PM 将 R1–R3 一次性交给 dev2，只修 design/tasks 和 delta 的歧义；保留原规划提交用于对比。修订后做限定差异复看，不重开全案探索，不执行未来实施测试。以下是依该安排完成的第二轮。

## 第二轮定点复看 · 2026-11-16T09:33:34Z

**判定：ACCEPTED，R1–R3 全部关闭，仅限提案可接受。** 依据 PM 更新后的 V166 任务书，仅对 `5ab4f040ada9..1589612c4ff9` 的四文件差异做定点审阅；原模型、SID、任务分支和首轮记录保留。没有重开全案，也没有把作者的修订回执当作本席位执行。

### 四文件差异与三项闭合

实际 `git diff --stat` 为 **4 files changed, 83 insertions(+), 16 deletions(-)**：

```text
docs/team/reports/P460-dev2.md
openspec/changes/config-check-execution-dedup/design.md
openspec/changes/config-check-execution-dedup/specs/verification/spec.md
openspec/changes/config-check-execution-dedup/tasks.md
```

新独立检出的 HEAD 是 `1589612c4ff9b97e340224ad8958fc25f3e38935`，`git status --short` 无输出。产品/tests、正式 spec、CI、AGENTS、proposal 与原生元数据相对首轮候选均无差异，`git diff ... --exit-code` 实际返回 0。作者报告只增加返修说明/短检查/未执行边界，没有把初稿旧回执冒充新行为证据。

| 原项 | 实际修订及闭合证据 | 对当前结论的改变 |
|---|---|---|
| R1：未来验收重复成本 | design Migration Plan 改为最小验证表；tasks 1.3/3.1 同步。只要求一次正常 33、七键分别独立执行；51 沿用绑定 `572856a3` 的真实局部日志，并继续核父调用/汇总/顺序/输入/三脚本字节和期间产品消费差异；有相关差异才补原入口。validate/writer 复用同轮 33 具名嵌套原件；roster 只补缺的假成功坏腿；父级改真实短 setup 失败，并明确不是重跑 assertion rc=1 | **关闭**。完整 51、额外 validate/writer 和完整坏树默认集合不再是本批默认成本；真实默认组、七键和 routes roster 承诺未删除。静态同一性与原局部证据的组合前提及不成立时补验均写明，不是无条件沿用 |
| R2：完整/独立选段语义 | delta requirement 首句明确 `normal complete smoke run`；独立场景改为 `Independent entries keep their own execution scope`，明确选中 33 才执行其完整入口，单选 51/12e–12k 不因本约定加入 33。design §1/§4 与 tasks 1.1 使用相同区分 | **关闭**。原先正常单选 12e/51 与“每次 normal 都执行 33”的反例不再违反新正文；没有通过新增 needs 修饰行为 |
| R3：缺准备负例的空项目根 | design 与 tasks 2.2 只删 `p24_brief`，显式保留 `p24_project/p24_change`、路径和 shim；要求负例非零、点名缺定义且有具名行为失败，恢复按字节证明并复用正常独立 12e | **关闭**。项目根创建路径不再被该负例删除，避免首轮指出的空根拼成 `/docs/team/...`；没有新增产品保护代码或测试平台 |

三项只修规划和证据安排，没有扩成帮助面重构、守卫增量或默认组清单变更。原两项精简的源码结论继续有效；本轮没有重新声称执行次数已变成 2→1、七边已退休或已测到节省。

### 第二轮实际短检查

从自己的工作树发起命令，OpenSpec 子进程明确以新候选为 cwd；未安装/升级工具、未改变当前分支。

```text
$ export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
$ openspec --version
1.16.0
$ python3 -c 'import subprocess,sys; root=sys.argv[1]; print("VALIDATE_CWD="+root,flush=True); sys.exit(subprocess.run(["openspec","validate","config-check-execution-dedup","--type","change","--strict"],cwd=root).returncode)' /var/tmp/p460-review-1589612c
VALIDATE_CWD=/var/tmp/p460-review-1589612c
# SPEC_ROOT=/var/tmp/p460-review-1589612c/openspec
Change 'config-check-execution-dedup' is valid
ROUND2_STRICT_RC=0
$ git diff 5ab4f040ada9 1589612c4ff9 --exit-code -- skills openspec/specs .github AGENTS.md openspec/changes/config-check-execution-dedup/proposal.md openspec/changes/config-check-execution-dedup/.openspec.yaml
# 无输出；ROUND2_UNTOUCHED_SCOPE_RC=0
$ git -C /var/tmp/p460-review-1589612c status --short
# 无输出
```

本报告新增正文暂存后的固定命令与实际回执（`root` 家目录前缀仅显示省略；实际在本席位分支扫描）为：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree>/.worktrees/verify scope=published files=2751 hits=0 names=ok user=resolved
ROUND2_LEDGER_RC=0
$ git diff --cached --check
# 无输出，rc=0
$ git diff --check
# 无输出，rc=0；ROUND2_DIFF_CHECK_RC=0
# 本次命令收尾 UTC=2026-11-16T09:34:55Z
```

本轮命令均为短检查，没有启动新后台作业；首轮共享后台原日志保留未动。

### 第二轮 Final assessment

- Verdict：**ACCEPTED（proposal-only）**。当前未解决项：CRITICAL **0** · WARNING **0** · SUGGESTION **0**；首轮三项 WARNING 均按上表关闭，原 REWORK 和回执保留。
- 未重复：首轮源码调查、十一份现状计划、spec-refs、全项目 validate 或其它原检查，依更新后任务书不再执行；首轮结果仍只代表首轮范围。
- 未执行：未来的 33/51/七键 smoke、配置坏腿、setup/缺定义负例、完整套件、meta/61b/夜间、安装、真实模型、合并/归档/发布。未执行不记为通过；尚无改后耗时。
- 下一步由 PM 正式接受规划并另行决定 apply；本席位只交付原报告的定点复看增量，不动看板、提案或主检出。
