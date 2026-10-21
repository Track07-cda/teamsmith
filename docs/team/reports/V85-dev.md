# V85 · P348 的独立验收：第 3 轮精简有没有减掉必要覆盖

agent: dev   status: **PASS**（第二轮，候选 `7ae5f46b`：返修的三条全部成立，§第二轮）
第一轮（候选 `bedf9e0a`）判 PARTIAL：⑫ `space-trail` 删掉了唯一覆盖，返修后已恢复   time: 2026-10-21T03:20Z
branch: `task/V85-test-round3-verify`（local 模式，未 push，未合并）   PR/MR: -
受检：第二轮候选 `7ae5f46b`（`bedf9e0a` + `c6a7ecd6` 恢复 `space-trail` 的返修 + 返修报告）；第一轮候选
`bedf9e0a`（实现 `d2118a43` config-cli、`18ad0d18` key-replies）。候选 delta 只有这两个测试文件
＋作者报告，没有第三个产品文件：`git diff --stat 3dc61570 bedf9e0a` → `reports/P348-dev-bob.md`、
`tests/config-cli.sh`（+49/−27 行）、`tests/key-replies.sh`（+37/−19 行）。
作者报告：`docs/team/reports/P348-dev-bob.md`。

## 第二轮（定点复看，候选 `7ae5f46b`）：**PASS**

三条都成立；每一条都是我自己在候选的私有副本里跑出来的，没有引用作者的表或日志。

**① `space-trail` 真的回来了，而且咬的正是那一件事。**

```
$ bash skills/teamsmith/tests/config-cli.sh roster                 # 未变异（候选）
== 结果 ==  ✓ 97  ✗ 0  SKIP 0

$ # 窄变异：team_config_seat_violation 只放行"尾部空白"（前导、内嵌、制表符照拒）
$ bash skills/teamsmith/tests/config-cli.sh roster
  ✗ ⑫ space-trail：4（invalid，写入前就拒）（期望 [4]，实际 [1]）
  ✗ ⑫ space-trail：名册字节不变（期望 [ac15bd17…]，实际 [fdda2a3a…]）
  ✗ ⑫ space-trail：审计里没有 ok 行（期望 [0]，实际 [1]）
  ✗ ⑫ space-trail：没给接受形状（✗ 未知 agent：api （名册：dev verify api ））
  ✗ ⑫ space-trail：没给路线（✗ 未知 agent：api （名册：dev verify api ））
== 结果 ==  ✓ 92  ✗ 5  SKIP 0
    （同场 space-inner / space-lead / tab 三个形状全绿 —— 只有 space-trail 这一条红）

$ cp 候选原件 cmd-config.sh  # 还原（cmp 逐字节相同）
== 结果 ==  ✓ 97  ✗ 0  SKIP 0
```

与上一轮同一变异打在删后树上 `✓92 ✗0` 的读数对照：这一轮复活了 5 条，且只有它红。

**② 它那张 20 行表抽 4 行复跑，4 条全部 CAUGHT。** 抽的是 2 条合并（K1 input、K4 receipts）与 2 条删重复
调用（C1 坏枚举的重复 `check_rc`、C9 三席位 `set-agent-model` 循环）；变异按它表里写的那一件事打，红的正是
它表里写的那条存活断言：

| 行 | 窄变异（只坏这一件事） | 红的读数 | 组读数 |
|---|---|---|---|
| C1 | 枚举拒绝的文案不再列接受域 | `✗ 枚举报错没点名接受域（✗ TEAM_MONITOR_UI=colour 不合法：只接受合法值）` | validate ✓21 ✗1 SKIP1 |
| C9 | `set-agent-model` 退休拆掉（返回 0） | `✗ ⑪ set-agent-model 已退休 → 5（期望 [5]，实际 [0]）`、`✗ ⑪ 退休路线不完整（）`、`✗ ⑪ pm 席位…（期望 [5]，实际 [0]）` | roster ✓94 ✗3 |
| K1 | 同正文重发被合并回已有编号 | `✗ input：重复提交/编号不对（total_slots=1…）` | input ✓23 ✗1 |
| K4 | `show` 也去抢写锁 | `✗ receipts：锁被占时 show/list 照常（都 rc=0）：期望 [0/0] 实际 [5/0]` | receipts ✓17 ✗1 |

四条的形状一致：**绿侧全绿、只加一处窄变异就红**，红的是它表里点名的存活断言，不是别的断言连带红
（判据是每一行都有「未变异 → 全绿」的对照，四个都在候选树上现量：validate ✓22 ✗0 SKIP1、roster ✓97 ✗0、
input ✓24 ✗0、receipts ✓18 ✗0；每个变异体只让一组里的一到三条断言变红，没有整组连带红）。

**方法与边界（第二轮）**：只跑了两个夹具文件（`config-cli.sh`、`key-replies.sh --all`）在**两棵树**上的整份读数
（cand 140.6 s + 708.7 s，base 159.8 s + 714.7 s），加上五个变体各跑一组（roster ×2、validate、input、receipts）；
**没有**跑 `smoke.sh` 的任何段、没有任何门禁运行。全部破坏都在 `/var/tmp/v85r2/` 的私有副本里
（`cand`=`7ae5f46b`、`base`=`3dc61570`、`mut-*`=各变异体），受检树只读、工作树干净；驱动脚本
`/var/tmp/v85r2/run-{verify,counts}.sh`，日志在 `.pi/team/state/bg/v85r2-*.log`。

**③ 总数对得上（两棵树都是我自己跑的）。**

| 树 | `config-cli.sh` | `key-replies.sh` | 说明 |
|---|---|---|---|
| 删之前 `3dc61570` | **350** | **212** | 基线 |
| 第一轮候选 `bedf9e0a` | 326 | 203 | −24 / −9 |
| 本轮候选 `7ae5f46b` | **331** | **203** | −19 / −9 |

净减 **28 条**（562 → 534，−5.0%），**恢复 5 条**（`space-trail` 一个形状 = 5 条断言），
`331 = 326 + 5` 与 `git diff bedf9e0a 7ae5f46b -- skills/` 只有那一个循环（4 增 3 删）互相印证。

---

## 第一轮（候选 `bedf9e0a`）的结论（先看这里）

**PARTIAL。** 三个问题的答案：

1. **两轮共删/合并 20 处、−33 条断言；我抽样 6 处、每处做一次变异（不是读一遍相信）——5 处的接管者真会
   咬，1 处根本没有接管者。** 那 1 处是 `config-cli.sh` ⑫ 的 `space-trail`（`api `），它删掉了唯一覆盖。
   把产品改成"空白在尾部就放行、其他位置照拒"这种窄回归，打进候选树后 `config-cli.sh roster` **仍然
   ✓92 ✗0（全绿）**；同一变异打进入前的树（`3dc61570`）**红 5 条**，其中一条把脏名册直接打出来：
   `未知 agent：api （名册：dev verify api ）`。这就是 P105/F1 的形状（失败的命令改了状态、名册里多一个
   用户没打的名字），作者在提交信息与报告里写的"判据没放宽 / 删掉的不是唯一守门人"对这一条不成立。
2. **按三条判据挑最可能踩线的 3 条**：⑫ `space-trail` 是**真踩线**；`docs` 段的 schema→`references/config.md`
   对拍、`shape` 段的 `rej_seat '/a'`+`'a/'` 我判**可接受**，各自边界在 §3。
3. **`panel-b3.sh` 确实不在任何门禁段里**（三种查法一致，§4），**而且它今天是红的：`✓223 ✗8`**，cand 与
   main 读数一模一样（7 条是同一个原因：空的 `dropped` 车道在 120 列的 side-by-side 看板上渲染成**不带标签**
   的三列折叠框，夹具却断言 `已放弃` 在场；第 8 条是鼠标点击后的焦点判定，原因另查）。另外 `section-select
   --paths …/panel-b3.sh` 给的是 `decision=RUN`（§12b-h0d + §40），**不是 FULL**——改动它既不会跑它，也不会
   落进"未声明路径 → 跑全套"的兜底，选段器看起来"有归属"。所以建议是**接线并连同裁决那 7 条**（照 P327 给
   `panel-b2.sh` 的配方：不新增段，在 §28 里加一条腿 + 在 §28 的 patterns 行登记），不是删掉、也不是维持现状：
   现状已经证明它会烂——8 条红着，没人知道。

另外两处它只报不改的：

- **§0e `--loop-check`：main 已经 86/86 绿（rc=0），候选树仍红 1 条——但这不是 P348 引入的**：候选的 base
  （`3dc61570`）早于 PM 的 `915f0512`，带着旧清单第 47 行；候选 delta 不碰 `smoke.sh`/`loop-inventory.tsv`。
  把候选那两个测试文件覆盖到**当前 main** 的树上再跑 → 86/86 绿（§5.1）。
- **§62 注释的「整段约 1.8 分钟」确实错了**：同一段在本仓库历年读数是 297 s / 122 s / 95 s / 131 s /
  **729 s**（P348 本轮选段），我这次脚本直跑 **702.65 s**。其中**至少 300 秒是一条故意挂到上限的臂**
  （`flip_probe_fifo_block` 的 `timeout 300`，它期望 rc=124）。结论：注释里不该写挂钟预测，要写就写**上限**
  ——典型用时机器自己已经打印了（§5.2）。

返修建议（一处、5 条断言）：把 `space-trail:api ` 加回 `config-cli.sh` 既有的 `for shape` 循环（或把存活
形状里的 `tab` 换成它）。净删从 −33 变 −28（−5.9% → −5.0%），判据回到"一条没放宽"。除此之外我不建议返工。

## 1 · 我跑了什么（真实命令与读数）

所有破坏都在 `/var/tmp/v85/` 的私有副本里；受检树只读，工作树全程干净。副本由 `git archive` 展开成
`cand`（`bedf9e0a`）、`base`（`3dc61570`）、`main`（`a9dbafc3`）、`merged`（main + 候选两个测试文件）。
驱动脚本 `/var/tmp/v85/mut.sh`、`/var/tmp/v85/mut2.sh`，逐场日志
`.pi/team/state/bg/v85-{baseline-groups,mutations,mutations-2,full-fixtures}.log`。

```
# 两个夹具的全量读数（数就是交付数字；都在 cand 副本里跑，cwd 在副本里 ⇒ tree/SKILL_DIR 指向 cand）
$ bash skills/teamsmith/tests/config-cli.sh
WALL 136.53 s
== 结果 ==  ✓ 326  ✗ 0  SKIP 0
$ bash skills/teamsmith/tests/key-replies.sh --all
WALL 702.65 s
== P234 key-replies 结果 == ✓203 ✗0 SKIP0
```

```
# 选段器对 panel-b3.sh 的回答（受检树）
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/panel-b3.sh
decision=RUN
sections=135
keys=6
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
reason=0d ← prologue
reason=12b-h0d ← skills/teamsmith/tests/panel-b3.sh
reason=40 ← skills/teamsmith/tests/panel-b3.sh
```

```
$ grep -n 'panel-b3' skills/teamsmith/tests/section-paths.tsv | grep -o 'panel-b3[a-z-]*\.\(sh\|py\)' | sort | uniq -c
      3 panel-b3-stub.sh                    # 全表没有一行声明 panel-b3.sh 本体
```

```
# §0e，三棵树各一次
$ bash /var/tmp/v85/main/skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
section-guard --loop-check: 全过                                   rc=0
$ bash /var/tmp/v85/cand/skills/teamsmith/tests/section-guard.sh --loop-check
bad: smoke.sh:6449 的 while 行与清单第 30 行的锚点不符
     源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
     清单：  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; …
section-guard --loop-check: 1 条不成立                              rc=1
$ bash /var/tmp/v85/merged/skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 86 行清单 / 86 个 while+sleep 循环，配平 86 个
section-guard --loop-check: 全过                                   rc=0
```

```
# panel-b3.sh 本体跑一次（健康状况 + 代价）——它今天不跑，所以这是第一次有人量它
$ bash skills/teamsmith/tests/panel-b3.sh --all          # cand 副本
WALL 208.67 s
  ✗ 按 4 切到看板页（六车道在场）（…/board/p4.txt 里找不到 [已放弃]）
  ✗ 重启后仍在看板页（panel-page 记忆）（…/board/relaunch.txt 里找不到 [已放弃]）
  ✗ 点击卡片后焦点没有移到被点的卡（no）
  ✗ 夹具：控制台停在看板页（六车道在场）（…/detail/board.txt 里找不到 [已放弃]）
  ✗ q 返回看板页（…/detail/back-q.txt 里找不到 [已放弃]）
  ✗ Esc 返回看板页（…/detail/back-esc.txt 里找不到 [已放弃]）
  ✗ B5 切到看板页（…/workdetail/board.txt 里找不到 [已放弃]）
  ✗ B5 esc 回到看板页（…/workdetail/board-back.txt 里找不到 [已放弃]）
== 结果 ==  ✓ 223  ✗ 8
$ bash skills/teamsmith/tests/panel-b3.sh --all          # main 副本（同一份文件，main 一字未改过它）
WALL 211.83 s
== 结果 ==  ✓ 223  ✗ 8        # 同样 8 条，同样取证路径
```

两棵树读数一样，说明这 8 条红与 P348 无关：它是**这份不跑的夹具自己烂掉了**。

## 2 · 六条抽样：接管者都在，而且真会咬（每条一次变异）

每一行的变异都只在 `/var/tmp/v85/mut-*` 副本里改产品，跑完不动受检树。**六条全部实做变异**（任务书要求
至少 2 条）：含 2 条「合并」、2 条「删重复调用」、2 条「删文案档断言」。

| # | 类型 | 被删/被合并的原文 | 声称的接管者 | 我的变异 | 结果 |
|---|---|---|---|---|---|
| 1 | 合并 | `input：重复提交不合并（两条）` + `input：编号严格递增` | 合成的 `jok`（两条 + 最新 no=2） | `replies.mjs` 的 `list` 把相邻同标题条目吞掉（"重发被当成重复提交"） | 合并那条**红**：`✗ input：重复提交/编号不对（entries 只剩 1 条，total_slots=2）`，✓23 ✗1 |
| 2 | 合并 | paging 的 `条数 123` + `起点 123` + `终点 1` + `去重后仍 123` | 合成的「链恰好是 `123 122 … 1`」 | 同一页内把第 11、12 条**对调**（条数/起点/终点/去重四条都不受影响） | 合并那条**红**（点名 `… 113 112 111 …`），✓18 ✗1 —— 被删的四条在这种破坏下会全绿，合并后更强 |
| 3 | 删重复调用 | `check_rc "坏枚举的报错带接受域（TEAM_MONITOR_UI）" 4 …`（同 argv、同 rc、只判 rc） | `check_rc "TEAM_MONITOR_UI=colour → 4"` + 紧跟的 `case *auto*tui*text*` | `cmd-config.sh` 的 enum 分支不再比对值域 | 两个接管者**都红**：`✗ TEAM_MONITOR_UI=colour → 4（期望 [4]，实际 [0]）`、`✗ 枚举报错没点名接受域`，✓19 ✗3 |
| 4 | 删重复调用 | `for seat in dev pm dev4` 的 6 条 `set-agent-model` 断言 | roster ⑪（未知席位 + pm 两种身份） | 退休诊断只剩 `retired`，不再点名 `set-task-model`/`TEAM_PM_MODEL` | `✗ ⑪ 退休路线不完整（✗ retired）`；rc=5 那条仍绿 —— ⑪ 的两半各守一个面，✓91 ✗1 |
| 5 | 删文案档 | ① `case *"什么都没做"*`（"明说零副作用"） | ①「契约逐字节不变」+「没有工作树」+「没有 state 文件」 | `add-agent` 的无旗标未知席位分支**先写名册再拒绝**（行为变坏、文案一字未改） | 行为断言**红 4 条**：① 契约 sha、① 审计行、② 契约 sha、③ diff 行数，✓88 ✗4 |
| 6 | 删文案档 | ⑫ `space-trail:api `（5 条） | 声称由 `space-lead`（` api`）"同一条判据"接管 | `team_config_seat_violation` 只拒**前导**空白与"空白后接非空白"，尾部空白放行 | **候选树 ✓92 ✗0（没人咬）**；同一变异打进 base 树 → **✗5 全点名 `space-trail`**，含 `未知 agent：api （名册：dev verify api ）` |

第 1 行我第一次的变异选错了对象（`nextNumber` 复用上一槽位）：它把写路径本身弄坏，红了 4 条**别的**断言
（`合法 label 放行` 由 0 变 4 等），合并那条反而绿——说明"槽位复用"不是这条断言守的回归，所以我换成第一行
那个"读者把重发吞掉"的变异。失败的尝试留在 `state/bg/v85-mutations.log`。

## 3 · 三条"最可能踩线"的判断

判据用任务书给的三条：契约面 / 点名过的事故 / 哑失效。

**① ⑫ `space-trail` —— 真踩线（唯一一处）。** 三条判据全中：席位名是 CLI 契约的一部分（"一个 token，
写入前拒"）；紧挨着的注释点名的就是 P105/F1；改坏之后是**哑失效** —— 命令写进一个用户没打的席位名，
之后才以 rc=1 报 `未知 agent：api `，正是那次事故的原样。它是**唯一**覆盖尾部空白的断言：`space-inner`
（`api 1`）、`space-lead`（` api`）、`tab` 三个存活形状在我的变异下全绿——产品规则虽然只有一条
`*[[:space:]]*`，但**回归可以只破其中一个位置**（把 `rstrip` 接到判据前就是这种写法）。作者的删除理由
"`space-lead` 是同一个形状、非对称的 trailing 空白也被它守"在代码层面不成立：`space-lead` 打的是**前导**
空白，它连"首尾"这个词的另一半都没碰到。

**② `docs` 段删掉的 schema→`references/config.md` 对拍 —— 可接受。** 接管者 `check_completeness` 的第三个
while 与它逐字同源（同一个 `schema_keys_of`、同一个 `grep -qF "\`$k\`" "$md"`），并且多了两个反方向
（模板键→schema、文档键→schema）。要核的是"跑到 `docs` 段时接管者是否在场"：全仓只有两处**执行**这个夹具
——§33 无参跑（`completeness` 段在 1413 行的 `docs` 段之前）、§51 跑 `list validate roster`（`docs` 根本没被
选中）；`smoke.sh:19041` 只是把它 `sed` 成 lint 翻转副本，不执行；`checkout-shape-probe.sh:70` 也是复制。
所以"任何跑到它的门禁上下文里接管者都在场"成立。残余风险只有一条：将来若有人把 `docs` 加进某个子集调用，
这条判据会静默消失；取代方向是"`docs` 段自己再调一次 `check_completeness`"（一行），不必把旧断言搬回来。

**③ `shape` 段删掉的 `rej_seat '/a'`（provider 为空）与 `rej_seat 'a/'`（model 为空）—— 可接受。**
两条判据（rc=4 + 点名原因）由 `rej_default` 的同名两条守着；"三条写入路共用同一处判定"由存活的
`rej_seat 'a//b'` 守着（如果 `set-task-model` 那条路不再走共享的模型形状判定，`a//b` 也会放行 → 红）。
边界要留一句：`a/` 与 `a//b` 命中**不同分支**（"model 为空" vs "model 有空段"），所以这不是"同一个短语"
的重复，而是"同一条判定、两个分支"；删掉的是价值最低的一面（rc 相同、短语不同）。若要最小代价补回严格性，
这 2 条比 `space-trail` 的 5 条便宜。

其余被删的（`writer` 段的 `bash -n`、⑨ 的两条 `grep -c`、`refuse` 的 rc 与 sha、①④ 的文案、`original` 的
`sha256`、`interrupt` 的尺寸、`receipts`/`bounded`/`concurrency` 的合并）按同一口径看过：接管者是**断言同一
事实且更直接**的那一条（整文件 sha 蕴含尺寸与席位名；`cmp -s` 蕴含 sha256；同一个文件后面还有两次
`bash -n`），没有一条落在三条判据上。

## 4 · `panel-b3.sh` 的处置：确认不跑，它今天是红的，建议接线并连同修

事实（三种查法一致）：

- `smoke.sh` 里 `panel-b3.sh` **只出现在 5 处注释**（12754 / 12834 / 12931 / 13607 / 13782），没有调用点；
  被调用的是 `panel-b3-stub.sh`。
- `section-paths.tsv` **没有声明 `panel-b3.sh` 的行**；只有 `panel-b3-stub.sh` 出现在 §28 与 §12f。
- `.github/workflows/gates.yml` 不含任何测试文件名——它跑 `smoke.sh --floor --paths "$@"`，跑哪些段完全由
  选段表 + 段体决定。

比"不跑"更值得点名的一条：**`--paths` 对它是 `decision=RUN`，不是 FULL。** §12b-h0d 与 §40 都声明了
`skills/teamsmith/tests` / `skills/teamsmith/tests/*`（理由分别是"递归 grep 整棵 tests 树找第二份几何实现"
与"`tmp-hygiene.sh --lint` 扫 `*.sh`"），所以改 `panel-b3.sh` 会被选进这两段，而两段都不执行它。也就是说
**"已声明"在这一条上是空头支票**：改动它既不会跑它，也不会落进"未声明 → 全套"的兜底；而
`coverage-inventory.sh` 的比对粒度是**段**（C/L/R 行都按段键），也看不见"某份夹具没有被任何段执行"。
仓库自己记过这笔账：`references/troubleshooting.md:1128`「…is pinned only by `tests/panel-b3.sh board`,
which the gate does not run: no gate section carries it」。

它守的东西里，**今天没有任何机器在看的**是这些（§28 覆盖的是 `--snapshot` 可判定的那一半）：
真按键（能力键、焦点行走、详情原地返回）、SGR 鼠标直驱与 tmux 全链路、滚轮、resize 的**实时**重排、
`q` 收起后巡检仍在跑（7.1）、看板折叠的重启持久化（P123）、以及同一 `id` 两行共享一个游标。

### 4.1 而且它今天是红的：`✓223 ✗8`（cand 与 main 读数相同）

这是作者只报了"不跑"、没报"红"的那一半，两棵树各跑一次整份（§1 第三段），**8 条红一模一样**：

- **7 条是同一个原因：空的 `dropped` 车道在宽屏上渲染成不带标签的三列框。** 夹具用默认数据档
  （`panel-b3-stub.sh`：`done 7 / review 0 / dropped 0`），两个空车道（`review`、`dropped`）命中
  `laneFolded()`（`scripts/panel/src/layout.ts`："a lane nobody named folds only while it is empty"）被折叠；
  120 列的看板走 side-by-side tier，折叠后画的是 `foldedLaneFrame()`——**三列边框 + `…`，不带标签**，
  源码注释写明 "The frame alone says which lane it is because the order never moves"。于是
  `assert_has … "已放弃"` 找不到东西：7 条红分布在 `board`（2）、`detail`（3）、`workdetail`（2）。
- **剩下 1 条是另一回事**：`点击卡片后焦点没有移到被点的卡（no）`——鼠标点击后的焦点判定，原因要单独查，
  这一轮我不下结论。

对处置建议的影响：**接线不能直接上**（会立刻把门禁打红），要分两半步——先对那 7 条裁决：是夹具跟不上 P125
的折叠形态（改夹具），还是折叠框丢了可辨识度（改产品）；裁决之后再接线。这一条顺带把一个产品问题摆到桌面
上，值得 PM 自己看一眼：120 列时六个车道里五个有名字，空的 `review` 与 `dropped` 是两个只剩边框的匿名框
（可点区域只有 3 列宽）；"the order never moves" 是写给已经会用这块看板的人的，不是写给第一次看的人的。

建议**接线**，照 P327 给 `panel-b2.sh` 的现成配方（`section-paths.tsv` §38 行的 basis：「P327：38-h 腿跑写信面
夹具 `tests/panel-b2.sh`（不新增段、不新增检查器），该夹具就是这条腿的判定面」）：

1. 在 §28 里加一条腿跑 `bash "$SKILL_DIR/tests/panel-b3.sh" <场景…>`，先只选门禁完全没有的那一半
   （`board`、`fold`、`mouse`、`wheel`、`collapse`）；增量代价先量再定整份还是子集（§28 今天 22–46 s）。
2. §28 的 patterns 行补上 `skills/teamsmith/tests/panel-b3.sh`，让"改它就跑它"这条关系变成真的。
3. 不接线的代价已经量出来了：**8 条断言红着、没人知道**。这比"没覆盖"更坏——它同时是"没覆盖"和"以为有
   覆盖"（§12b-h0d/§40 的宽通配还让选段器看起来有归属）。删掉则等于承认这几条用户可见行为不打算守；
   两者代价都比接线大。要动 `smoke.sh`/`section-paths.tsv`（P344/P346 写集），不在我的写集里（§8）。

## 5 · 两处"只报不改"的核对

### 5.1 §0e `--loop-check`：main 绿、候选红、合起来绿

- main（`a9dbafc3`）：86 行清单 / 86 个循环，`全过` rc=0 —— PM 的 `915f0512` 生效。
- 候选（`bedf9e0a`）：1 条不成立 rc=1。原因不是 P348：候选 base 是 `3dc61570`，在 `915f0512` 之前，带着
  旧的第 47 行；候选 delta 不含 `smoke.sh` / `loop-inventory.tsv`。
- merged（当前 main 的树 + 候选那两个测试文件）：86/86 `全过` rc=0。

所以这条不阻塞候选；但**候选树单独跑 §0e 会红**，PM 复验时要用 merged 形状（或先 merge main），不要用候选树
单独跑。

### 5.2 §62 注释的「整段约 1.8 分钟」

数字核了，是错的，而且不是"差几分钟"的量级：

| 出处 | §62 实测 |
|---|---|
| P234（段出生那一版，`7037f708`） | 297 s |
| P266 | 122 s |
| P267 | 95 s |
| P301 | 131 s |
| P348 本轮选段 | 729 s（12m09s） |
| **我这次脚本直跑 `--all`** | **702.65 s**（11m43s） |

时间去哪了：`key-replies.sh:998` 的 `flip_probe_fifo_block` 用 `timeout 300` 跑一条**期望挂住**的臂（判据是
rc=124）——**至少 300 秒是故意的固定挂起**；其余是 13 组里 `bounded`（10 万槽 + 内核计数器）与 `flip`
（九条变异臂，每条"改源码→跑→还原"）的固定成本。作者把它归给"原版就如此"，只对了一半：数字在出生那版
就是 297 s，也早就不准。

这类注释该写成什么？**不该写挂钟预测。** 理由不是"数字不准"，是三种事实被混成一个数字：

- **典型用时**：机器自己打印了（每段收口行 `· 参考 用时 Ns`，与 `sections.tsv` 同源）。注释手写一份等于给
  同一个事实第二个来源，而手写的那份不会跟着组数/夹具规模更新——这一段在五次记录里从 297 s 摆到 729 s。
- **上限**：这才是注释能稳定表达、门禁也真正需要的性质（P316 之后本仓库只剩"等待都有上限"这一条口径，
  `section-guard.sh` 的头注释写明"每段不再有预算表"）。写法例如："本段的固定挂起 ≤ 300 s
  （`flip/fifo_block` 的 `timeout 300`），其余步骤都等状态"。
- **预算**：已经不存在，注释里不需要任何"应该多久"的承诺。

## 6 · 计数核对（静态算术 + 全量读数）

被删/合并的运行时断言按 diff 逐条数，两边对得上：

- `config-cli.sh` **−24** = 9 条单点（`bash -n`、`check_rc` 枚举、refuse rc、refuse sha、① 文案、④ 文案、
  ⑨ 两条 `grep -c`、docs 对拍）+ 6 条（三席位循环 3×2）+ 5 条（`space-trail` 一个形状）+ 4 条
  （`rej_seat '/a'` 与 `'a/'` 各 2）→ 13 处。
- `key-replies.sh` **−9** = 合并 −7（input −1、concurrency −1、receipts −1、bounded −1、paging −3）+ 删除 −2
  （`original` 的 sha256、`interrupt` 的尺寸）→ 7 处。
- 全量读数与报告的 326 / 203 一致（§1）；算术反推 326+24=350、203+9=212，与报告的改前读数一致。

## 7 · 没验到的

- 没跑门禁整套（任务书边界）；也没跑 P348 报的那 9 段选段（43 分钟）——作者已跑过，我这轮的目标是判据
  本身，不是再确认一次挂钟。
- **没有对 13 处删除逐条变异**：抽样 6 条做了（含 2 合并、2 删重复调用、2 删文案档），其余 7 处按"接管者是
  同一事实的更直接断言"读代码判定，**没有实际变异**。
- `panel-b3.sh` 在 cand 与 main 上各跑了整份一次（健康 + 计时），**没有**逐场景审它的断言分布、也没有追
  那 8 条红里第 8 条（点击焦点）的成因，更没有裁决"改夹具还是改产品"——那是接线任务的第一件事。

## 8 · Decisions and deviations

- `panel-b3.sh` 接线要动 `smoke.sh` 与 `section-paths.tsv`（P344/P346 写集），并且要先裁决那 7 条红：
  `BLOCKED: 需 PM 派 apply 任务给 smoke.sh / section-paths.tsv 的当前写者，任务里带上 §4 的三步与 §4.1 的裁决`。
- 唯一返修项（⑫ `space-trail`）属 `skills/teamsmith/tests/config-cli.sh`，我这一轮是 verify 席位、不改实现：
  `BLOCKED: 需 PM 决定派给测试面写者，还是 PM 自己补回 5 条断言`。
  **第二轮已关闭**：作者在 `c6a7ecd6` 恢复了它（净减回到 −28），第二轮复看判 PASS（见文首 §第二轮）。
- 驱动脚本与全部副本在 `/var/tmp/v85/`，未提交进仓（任务书只允许写本报告与线程）。

## 9 · Flip evidence（缺陷面）

```
# 候选树 + 「尾部空白放行」变异（行为变坏，文案一字未改）→ 全绿，没人咬
$ TEAM_CONFIG_TREE=/var/tmp/v85/mut-m6cand bash skills/teamsmith/tests/config-cli.sh roster
== 结果 ==  ✓ 92  ✗ 0  SKIP 0

# 同一变异打进改动前的树（3dc61570，space-trail 还在）→ 红 5 条
$ TEAM_CONFIG_TREE=/var/tmp/v85/mut-m6base bash skills/teamsmith/tests/config-cli.sh roster
  ✗ ⑫ space-trail：4（invalid，写入前就拒）（期望 [4]，实际 [1]）
  ✗ ⑫ space-trail：名册字节不变（期望 [ac15bd17…]，实际 [fdda2a3a…]）
  ✗ ⑫ space-trail：审计里没有 ok 行（期望 [0]，实际 [1]）
  ✗ ⑫ space-trail：没给接受形状（✗ 未知 agent：api （名册：dev verify api ））
  ✗ ⑫ space-trail：没给路线（✗ 未知 agent：api （名册：dev verify api ））
== 结果 ==  ✓ 96  ✗ 5  SKIP 0
```

六条抽样的其余五次变异（合并 ×2、删重复调用 ×2、删文案档 ×1）的读数在 §2 表里；正向面同日实测：
`config-cli.sh` `✓326 ✗0`、`key-replies.sh --all` `✓203 ✗0`、merged 树 `--loop-check` 86/86。

## 10 · Suggested next steps

- 最小返修：把 `"space-trail:api "` 加回 `config-cli.sh` 的 `for shape` 循环（5 条断言），或把 `tab` 换成它。
  返修后跑一次 `config-cli.sh roster`（约 90 s）＋§51 的 roster 腿即可。
- `panel-b3.sh` 接线独立派单（§4 三步 + §4.1 的裁决），**先量增量**再决定整份还是子集；顺带补 §28 的
  patterns 行，消掉"改动它 → 选到不跑它的段"这个假覆盖。那 7 条 `已放弃` 的红要先有裁决，否则接上就红。
- §62 的注释改成上限句（或删掉时间），不要动任何时限。
- 候选合并前用 merged 形状复验 §0e，不要用候选树单独跑。
