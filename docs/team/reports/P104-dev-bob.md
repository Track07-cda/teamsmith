# P104 · `roster-writer-and-route-truth` 独立验证（换人）· **verify** · dev-bob

agent: dev-bob
status: **FAIL —— 2 个 finding（F1 名册在报错前被改且留下 ok 审计；F2 `add-agent --model` 的 state 记录是旧值）→ apply 需返工**
time: 2026-09-28T10:0xZ（本会话）
branch: `task/P104-p104`（local 模式：**不 push**，分支留在本地等 PM 复验/合并）
change: `roster-writer-and-route-truth`（verify 阶段；作者 dev@P99 已被换掉，本席位与其非同一人）
deltas: `-`（verify 不改 delta，只写报告）
验证对象: **main 上已合并的实现**（P99 = `ed3f6455`）；PM 复验 tip `1673a717`。
  - `git merge-base --is-ancestor ed3f6455 main` → yes（P99 在 main 里）
  - `git diff --quiet main HEAD -- skills/` → 空（本分支的 `skills/**` 与 main 逐字节相同；main 比本分支只多一条文档提交 `1673a717`（P101 样本））
证据: `docs/team/reports/P104-dev-bob/pkg/`（自建验证包：`lib.sh` + `run.sh` + `10..80` 九个编号分节）与 `pkg/logs/`（每节原始输出 + 门禁原始日志）

**总结论**：P99 的主干是对的——名册有了唯一一条授权、审计的写入路径（`add-agent --register` / `teardown --register`），
无旗标拒绝点名的两条路线**逐条实跑都能用**，斜杠/pm/重复 token 都被值规则拒绝且字节不变，对称移除与
`set-agent-model` 的未入册席位都给出可执行答案，`routes.sh` 对**我自己造的**的两个谎言能红并点名（还原即绿）。
但独立夹具抓到两个**作者自带夹具没有覆盖**的形状，都违反本 change 自己的契约：

| # | 形状 | 期望（brief / spec） | 实测 | 后果 |
|---|---|---|---|---|
| **F1** | 席位名带空白（`api 1`、` api`、`api `、`api\t1`）——`add-agent … --register` 与 `teardown --agent … --register` 两侧 | 明确拒绝 + 名册字节不变 | `add-agent`：名册先被改成 `dev verify api 1`、写下一行 `result=ok`、命令**再**以 rc=1 退出；`teardown --agent 'dev verify' --register`：rc=0、契约被重写（引号形态变了）、`result=ok old='dev verify' new='dev verify'`（什么都没移除却记了一笔 ok） | 失败的 add-agent 留下被污染的名册与一条假的 ok 审计；重复/半成品命令会把它当两个席位 |
| **F2** | `team add-agent dev --model vendor/m2 --no-install`（R2 的 scenario 原样） | `TEAM_AGENT_MODELS='dev=vendor/m2'`、一行该键审计、`team config list --json` 的席位行带 `vendor/m2` + `override:true` | 前两条成立；席位行是 `model=deepseek/deepseek-flash source=record override=True` —— **不是 vendor/m2** | 新建席位的 state 记录是写盘前的旧值；`team ps`/`config list --json` 对新席位显示回退模型并标「历史记录」（它根本没跑过） |

---

## 0 · 对象同一性（验证的到底是哪棵树）

```
$ git rev-parse --short HEAD main
8914244d  1673a717
$ git merge-base --is-ancestor ed3f6455 main && echo yes
yes
$ git diff --stat main HEAD -- skills/        # 空输出
$ git log --oneline main -c 5
1673a717 docs(team): P101 gets a live sample …
8914244d docs(team): P104 brief …
733dd957 docs(team): P70 thread note …
8ad5ad2f docs(openspec): archive npm-cli-and-project-init (D42 order step 1)
2c4d7406 docs(team): P99 done
```

即 P99 的代码在 main 里；本分支相对 main 只多 P104 的任务书提交，`skills/**` 逐字节一致。
所有夹具跑的是这份 `skills/teamsmith`（验证对象），不是作者分支。

## 1 · 记分板与复现入口

```
$ bash docs/team/reports/P104-dev-bob/pkg/run.sh 10 20 30 35 40 50 60 70     # 聚焦段（约 1.5 min）
… == P104 验证包汇总 == ok=136 finding=10 bad=0 skip=0

$ bash docs/team/reports/P104-dev-bob/pkg/run.sh 80                          # 门禁段（见 §5）
```
（`finding` 就是上表的 F1/F2；`bad=0` = 验证包自身没有夹具/骨架故障。逐节日志在 `pkg/logs/`。）

自建包的 containment：私有临时根（`tests/lib/tmp-root.sh`，`teamsmith-p104.*`，EXIT 回收）、
每格一个全新 git 仓库、第一个 PATH 上是**recording tmux shim**（session 查询一律答“不存在”，永不触真
session）、`TEAM_PI_BIN=/bin/true`、`TEAM_MEETINGS_DIR`/`TEAM_PI_AGENT_DIR` 在夹具内、`env -u TMUX -u TMUX_PANE`、
stdin `/dev/null`、每条命令 60 s 上限。**真名册（主工作树）从未被读写**：`git status --porcelain` 相对
基点只多本报告与 `pkg/**`（70 节的 ⑫ 有断言）。

---

## 2 · Findings（返工项）

### F1 —— 带空白的席位名没有被拒绝：契约先被改、并留下 `result=ok` 审计

**要求（brief §1 第三条）**：怪名字（空 / 带空格 / 带 `/` / `pm` / 已在名册）各自**明确拒绝**且**名册字节不变**。
**spec 侧同理**：`memory-and-deps`（MODIFIED）把席位名规则定为每个 token 匹配 `[A-Za-z0-9][A-Za-z0-9._-]*`；
`dispatch`（ADDED）要求可预测错误“nothing written”。

**实测（原始输出摘录，`pkg/logs/30-hostile.log`）**——四格全部：名册被改、审计 `result=ok`、命令 rc=1：

```
CASE space-inner | name=api\ 1  | rc=1 | bytes=YES | audit=1
  ✗ 未知 agent：api 1（名册：dev verify api 1 ）
  └ 名册被改成了：TEAM_AGENTS='dev verify api 1'
  └ 审计最后一行：… result=ok actor=cli key=TEAM_AGENTS old='dev verify' new='dev verify api 1'
CASE space-lead  | name=\ api   | rc=1 | bytes=YES | audit=1   → TEAM_AGENTS='dev verify  api'
CASE space-trail | name=api\    | rc=1 | bytes=YES | audit=1   → TEAM_AGENTS='dev verify api '
CASE tab         | name=$'api\t1' | rc=1 | bytes=YES | audit=1 → TEAM_AGENTS='dev verify api\t1'
```

**对称路径同样中招（`pkg/logs/40-teardown.log` ㉑，全新夹具、init 的双引号名册行）**：

```
$ team teardown --agent 'dev verify' --register
… rc=0；契约字节 YES（双引号被规范化成单引号）；审计：
2026-09-28T10:01:33Z result=ok actor=cli key=TEAM_AGENTS old='dev verify' new='dev verify'
```

**根因（读代码 + 实测）**：写入前后的“值规则”都是对**整段值按空白分词**（`team_config_list_violation`
里 `for tok in $val`），没有任何一处要求**席位参数本身是单个 token**：

- `cmd-agents.sh` `team_cmd_add_agent` 第 ③ 步 `team_config_list_violation "$agent"` 对 `"api 1"` 得到
  token `api`、`1`，两者都合法 → 放行；
- `cmd-config.sh` `team_config_write_roster` 校验的是**结果值** `dev verify api 1`（同样合法）→ 写盘 + `ok` 审计；
- 之后 `team_worktree_add` → `team_require_agent "api 1"` 用**精确字符串**比对名册 token，必然失败 → rc=1。
  于是「写成功 + 审计 ok + 命令失败」同时发生。
- `teardown` 的 `present` 判定是 `case " $old " in *" $seat "*)` 的子串匹配：`"dev verify"` 命中整段名册，
  移除循环又摘不掉任何 token，结果是把同值重写一遍（引号形态被规范化）并记一行 `ok`。

**最小修法建议（未实施——verify 不改实现）**：在 `team_cmd_add_agent` / `team_config_write_roster` /
`team_cmd_teardown --register` 入口把「一个席位参数 = 一个 token」定死，例如拒绝 `${seat}` 里的任何
空白字符并要求 `team_config_list_violation` 的 token 展开恰好等于 `seat` 本身（`[ "$seat" = "$(printf '%s' "$seat")" ]`
与 `set -- $seat; [ "$#" = 1 ]` 同义）；`present` 判定同步改成按 token 精确匹配。加一条形状断言进
`config-cli.sh roster` / `routes.sh` 的夹具即可把这条钉住。

### F2 —— `add-agent --model` 写下的 state 记录是写盘前的旧值，spec 的读回不成立

**要求（`dispatch` ADDED，scenario “--model is the seat's configured model”）**：
`team add-agent dev --model vendor/m2 --no-install` 之后，`team config list --json` **reports the seat with
that model** and `"override":true`。

**实测（`pkg/logs/60-model-flag.log`）**——scenario 原样复现：

```
$ team add-agent dev --model vendor/m2 --no-install        # rc=0
$ grep '^TEAM_AGENT_MODELS=' .pi/team/config.sh
TEAM_AGENT_MODELS='dev=vendor/m2'                           # ✓ 写对了
$ … config list --json | seats[dev]
{'agent': 'dev', 'model': 'deepseek/deepseek-flash', 'source': 'record', 'override': True}
# state/dev.env: model=deepseek/deepseek-flash model_src=config
# config 文件:   TEAM_AGENT_MODELS='dev=vendor/m2'          # ✗ 席位行不是 vendor/m2
```

**根因**：同一次 `add-agent` 进程里，模型通过 `team_config_write_checked` 写入**磁盘**，但没有像名册写入器
那样刷新**进程内**的 `TEAM_AGENT_MODELS`（名册侧有 `TEAM_AGENTS="$new"` 的显式刷新，见
`cmd-config.sh:984`；通用写入器写完后没有同等动作）。紧接着 `team_worktree_add` 执行
`team_state_set "$agent" model "$(team_agent_model "$agent")"`（`cmd-agents.sh:26`，`--create` 路径是 `:55`） —— 读到的还是进程内旧值（回退默认
`deepseek/deepseek-flash`），于是记录 `model_src=config` 却记了错误的模型。`team_config_seat_state`
（读侧）优先用这条记录，`team ps`/`config list --json` 都因此显示错误模型；来源标注在**新进程**里
会算成 `record`（历史记录），而该席位从未跑过。

**最小修法建议（未实施）**：写盘成功后同步刷新调用进程的变量（`TEAM_AGENT_MODELS="$canonical"`，
与名册写入器一致），或让 `team_worktree_add` 的 model 记录从契约文件重读；两种都只需一行到两行，
之后 `add-agent --model` 的席位行与配置一致。把 `config-cli.sh roster` ⑨ 的断言从“契约行 + 审计顺序”
扩到“`config list --json` 席位行 = 新模型”即可钉住（`routes.sh` 的承诺探针用的是**无 state 记录**的
席位，所以没有覆盖这个形状——这是它漏掉 F2 的原因）。

---

## 3 · 观察（不计 finding，信息给 PM 裁决）

| # | 形状 | 实测 | 为什么不判 finding |
|---|---|---|---|
| O1 | `team add-agent verify --register` | 名册里已有 `verify` → rc=0「已在名册」，字节不变、无审计；名册里没有 `verify`（`--agents dev`）→ 作为普通席位注册成功 | 值规则只保留 `pm`；`verify` 是默认名册里的普通席位。brief 的“`pm`/`verify` 这种保留名”若指“也必须拒绝”，与 spec 冲突；请 PM 裁定是文案还是规则 |
| O2 | `team init --agents ""` | rc=1，输出 bash 原话 `cmd-project.sh: line 165: 2: parameter null or not set`；没有写出契约 | 非零且零副作用 = 不静默；这是 `${2:?}` 的通用形状，属 init 的用法错误文案，不在名册写入器范围内 |
| O3 | 手改出重复的名册（`dev api api`）后跑**无旗标** `add-agent api` | rc=0，继续走工作树步骤（不碰名册） | spec 把强制的 exit 4 系在 **`--register` 的 no-op 路径**上（该路径实测确实 rc=4、点名重复 token，见 §4）；无旗标路径带的是合法 token，且名册已经是手改脏的，不因它更坏 |
| O4 | `teardown --agent ghost --register` | rc=5 + 点名名册 + 契约字节不变 + 恰好一行 `result=refused` 审计 | 拒绝也有据可查，符合审计词汇表；不是缺陷 |

## 4 · 逐条验收（brief 要求 → 我自己的实测结果）

| brief 要求 | 我跑的形状 | 结果 |
|---|---|---|
| 1a `add-agent X --register` 正常路径：名册真的变了 + 恰好一行审计 | 10 节 ①–㉔：diff 恰好一行、`bash -n`、`result=ok actor=cli key=TEAM_AGENTS` 一行且点名新旧值、读侧 class=refuse/route 带 `--register`、重复 register 是 no-op、陈旧/当前 `--fingerprint`（3/0 + 一行 conflict） | **全绿（24）** |
| 1b 拒绝路径：非零 + 两条出路**真的能用** | 20 节：无旗标 rc=5 + 点名 `--register`/`config.sh` + 零副作用（无工作树/state/审计）；**出路一**在全新夹具实跑 `add-agent api --register` rc=0、名册写入；**出路二**在拒绝夹具上手改 config.sh 后原命令 rc=0、打印工作树步骤 | **全绿（15）** |
| 1c 怪名字矩阵 | 30 节：空（rc=2、字节不变）、`api/1`（rc=4、点名 token+形状）、`pm`（rc=4、点名“PM 席位”）、`verify`/`dev` 已在名册（rc=0 no-op、字节不变）、脏名册重复 token（rc=4）、无旗标非法 token（rc=4）；**带空白的四格 → F1** | **8 finding（F1）** |
| 1d 非 git / 名册为空 | 35 节：非 git rc=1 + 说清需要 git + 无契约写出；手改空名册上 `--register` rc=0 长出第一个席位、`teardown --register` 回到空、`set-agent-model`/未知席位 rc=5 且给路线 | **全绿（14）**，另有 O2 |
| 2 对称移除：审计一行；移除不存在 → 拒绝 | 40 节：`teardown --register` 改一行 + 恰好一行 ok 审计（点名新旧值）；未知席位 rc=5 + 字节不变 + 一行 `refused`；`--all --register`/缺 `--agent` rc=2；无旗标名册字节不变；**整段名册当席位名的空格形 → F1 对称侧** | **1 finding（F1）** |
| 3 `set-agent-model` 未入册席位给可执行答案 | 50 节：rc=5 并点名 `add-agent nosuchseat --register`；**从文案里提取该路线原样执行** rc=0、席位入册，随后同一条 `set-agent-model` rc=0、模型写入 + 审计、读侧 `override=true` | **全绿（12）** |
| 4 `--model`：真支持（跑一次）| 60 节：help 行打印齐 `--register/--model/--create/--no-install/--print`；scenario 实跑 rc=0、契约行正确、恰好一行该键审计、`-` 清覆盖、坏形状 rc=4 零写入；**读回席位行 → F2** | **1 finding（F2）** |
| 5 走查本身可证伪（**自造**谎言，不许只引用它的 7 条翻转） | 70 节：见下 | **全绿（13）** |
| 6 零回归 | 80 节：见 §5 | 见 §5 |

### 5 的详情：我自己造的两个谎言 → 红且点名 → 还原 → 绿（`pkg/logs/70-walk-lie.log`）

不是引用 `routes.sh` 自带翻转：本包 `70` 节先把交付树拷成 scratch 树，**自己**改坏，再跑交付的 `routes.sh`。

```
① 未改动的 scratch 先绿（对照）: == 结果 ==  ✓ 129  ✗ 0  SKIP 0
谎言 A：sed 把 help 的 add-agent 行 [--no-install] 改成 [--p104-lie]
③ walk 非 0 ✓；④ 红并点名 add-agent --p104-lie：
   ✗ 断言 L36：add-agent --p104-lie 被自己的解析器拒绝（原文：✗ add-agent: 未知参数 --p104-lie）
⑤ 红只点名这一条（其余用法行仍绿）✓
谎言 B：sed 把 TEAM_GATES 的 schema 注释改成“维护：team frob-p104 off”
⑦ promises 非 0 ✓；⑧ 红并点名 TEAM_GATES / team frob-p104：
   ✗ promise：TEAM_GATES 的注释点名了 CLI 没有的命令「team frob-p104」
⑨ 还原两文件后 walk+promises → 0 ✓（== 结果 ==  ✓ 129  ✗ 0）
⑪ 没有留下 teamsmith-routes.* 临时根 ✓；⑫ 调用者的树未被改动 ✓
```

## 5 · 门禁（零回归）

全部在**本树（验证对象）**上重跑；原始日志：`pkg/logs/gate-*.log`。

| 门禁 | 命令 | 结果 | 原始输出尾巴 |
|---|---|---|---|
| 规格库 | `PATH=… openspec validate --all --strict` | rc=0，**17 passed / 0 failed** | `Totals: 17 passed, 0 failed (17 items)` |
| 用法诚实性（全量，含 7 条自带翻转） | `bash skills/teamsmith/tests/routes.sh` | rc=0，**✓170 ✗0 SKIP 0**；七条翻转全绿（含「注册报成功而名册没变 → promise 探针红并点名 TEAM_AGENTS」） | `== 结果 ==  ✓ 170  ✗ 0  SKIP 0` |
| 受影响夹具（作者自带） | `bash skills/teamsmith/tests/config-cli.sh list validate roster` | rc=0，**✓103 ✗0** | `== 结果 ==  ✓ 103  ✗ 0  SKIP 0` |
| 快速门禁（brief 的 FAST） | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | rc=0，**✓2876 ✗0**，`smoke 全绿`；33 个真进程段落按 FAST 设计**可见 SKIP** | `== 结果 ==  ✓ 2876  ✗ 0` |

两点说明：
- 与 P99 报告/复审里的数字（validate 18/0、routes 170/0、config-cli 103/0、FAST 223/0）口径不同：validate 少 1 条是因为 P99 之后 PM 已把 `npm-cli-and-project-init` 归档（`8ad5ad2f`，归档 change 不再进 `--all` 计数）；FAST 的 ✓ 数随断言增删而变。**判定只看本次 rc=0 / 0 failed / ✗0。**
- 受影响段全绿说明 F1/F2 **没有**让作者既有夹具变红——它们是既有夹具覆盖不到的新形状，这正是换人独立验证要抓的东西。

## 6 · 我自己的证据 vs 引用（按 brief 第 7 条）

**我自己（可复核）**：`pkg/` 里的全部夹具、断言、原始日志；§2 的两个 finding 全部由上面的命令与
`pkg/logs/*.log` 支撑；§5 的门禁由我自己在本树重跑（原始日志 `pkg/logs/gate-*.log`）。

**引用（只作上下文，不是我判定的依据）**：
- P99 作者的 `docs/team/reports/P99-dev.md` 与其 `claims.sh`（我没有跑它们，也没有拿它们的“before/after”当证据）；
- PM 的 `docs/team/reviews/P99.md`（PASS 记录；其中 routes ✓170/✗0、config-cli roster ✓103/✗0、FAST ✓223/✗0 是**作者/PM**的数据，我在 §5 重跑的才是我的）；
- 仓库内 `tests/routes.sh` 的七条翻转、`tests/config-cli.sh roster` 的十一段：作为门禁的一部分我**运行**了它们，但它们的断言是作者写的——它们没有覆盖 F1（带空格的名字）与 F2（`--model` 后读回席位行），这正是换人独立验证的价值。

## 7 · 复现

```
bash docs/team/reports/P104-dev-bob/pkg/run.sh            # 全部（含 80 门禁，约 10–20 min）
bash docs/team/reports/P104-dev-bob/pkg/run.sh 10 20 30 35   # 写入路径 / 拒绝出路 / 怪名字 / 空与 no-git
P104_KEEP=1 bash docs/team/reports/P104-dev-bob/pkg/run.sh 30  # 保留夹具目录并打印路径
```
包与报告在同一分支（`task/P104-p104`）；`run.sh` 的末行是机器可读汇总
`== P104 验证包汇总 == ok=N finding=N bad=N skip=N`。
