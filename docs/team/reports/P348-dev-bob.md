# P348 · 第 3 轮：`config-cli.sh` −19、`key-replies.sh` −9，`panel-b3.sh` 报接线缺口（含 V85 返修）

agent: dev-bob   status: delivered（V85 判 PARTIAL 的返修已落地）   time: 2026-10-21
branch: `task/P348-test-review-round3`   change: `-`   phase: apply
commits：`d2118a43`（config-cli）· `18ad0d18`（key-replies）· `c6a7ecd6`（返修：恢复 space-trail）· 返修报告（本提交）

## 结论（先看这一段）

0. **V85 判 PARTIAL 判得对，返修已完成（§11）**：`config-cli` ⑫ 的 `space-trail` 是**唯一覆盖**（用窄变异
   才能看出来），已恢复；其余 19 处删/合并按同一把窄变异的尺子逐条重判，**20 条全部 CAUGHT**，无一例
   唯一覆盖。我上一轮的红侧方法（把整条规则拿掉）掩盖了这件事，两处口径错误也一并改正（§11.3）。
1. **三名单**：按断言调用点密度，未过轮次里最高的三个文件是 `tests/config-cli.sh`（281）、`tests/key-replies.sh`
   （258）、`tests/panel-b3.sh`（254）。前两个都在门禁段里（§33/§40/§51 与 §62），**第三个不在任何门禁段里**。
2. **`config-cli.sh`：运行时断言 350 → 331（−19，12 处保留 + 1 处已恢复）**（返修前口径是 326）。删的是重复调用、
   同一事实的另一种数法、以及行为面已被逐字节断言接管的文案档断言；判据一条没放宽（§2 逐条给了接管者）。
3. **`key-replies.sh`：运行时断言 212 → 203（−9，7 处，其中 4 处是合并）**。paging 的四条并成一条更强的
   「整条链恰好是 `123 122 … 1`」（§3）。
4. **红侧都实测，且返修后改用窄变异**：19 处里每一处都有一个「只坏这一件事」的变异体让存活断言红（§11.2
   的 20 行表）；`space-trail` 在删后树上对同一窄变异全绿、恢复后红 5 条（§11.1）。
5. **门禁选段 ✓153 ✗0，`smoke_rc=0`**（返修树上重跑：2584.6 s ≈ 43 分钟；含 `config-cli.sh` 全量
   ✓331 ✗0）；`openspec validate --all --strict` 21/21（§6）。
6. **`panel-b3.sh` 一条没删**：它守的 pty 面（真按键、鼠标、resize、`q` 收起）今天没有任何门禁或 CI 执行，
   在接线之前瘦身不产生任何真实信号。处置权交 PM（§5）。
7. **两处只报不改的既有缺陷**（都不在我的写集里、都可复现）：
   - **main 的 §0e 现在是红的**：`section-guard.sh --loop-check` 在 `main` 的树上 `rc=1`（`smoke.sh:6449` 的
     循环被 P326 换成 `R_MAX`，清单第 47 行还是旧锚点/旧上限字面量）。已验证的 3 列补丁在 §9.1。
   - `smoke.sh` §62 的注释写「整段约 1.8 分钟」，实测 **12 分 08 秒**（原版就如此）；其中约 5 分钟是
     `flip/fifo_block` 那一臂**故意的** 300 秒挂住上限——按任务书「不改时限」我没动。

| 文件 | 标记行/行数（任务书口径） | 断言调用点 | 实测运行时断言 | 变化 |
|---|---|---|---|---|
| `tests/config-cli.sh` | 0.133 | 281 → **273** | 350 → **331**（返修后） | 删 10 处、合并/去重 2 处；`space-trail` 已恢复（共 −19 条） |
| `tests/key-replies.sh` | 0.009 | 258 → **255** | 212 → **203** | 合并 4 组、删 3 条 |
| `tests/panel-b3.sh` | 0.129 | 254 → **254** | 未跑 | 不动（不在门禁段，见 §5） |

**总条数（十进制）**：改动前 `350 + 212 = 562` → 改动后 `331 + 203 = 534`，**−28 条**（−5.0%）。
其中 `config-cli` −19（V85 返修前曾报 −24，`space-trail` 恢复后 −19）、`key-replies` −9；
`panel-b3` 未变（未跑，不在门禁内）。

「标记行/行数」是第 1 轮那把尺子（`assert|✓|✗` 命中行数 ÷ 总行数，改前树）；「断言调用点」是本次用来排序的
尺子——正则 `(^|[;&|]|then|else)\s*(ok|bad|assert_*|eq|has|not_has|jok|cap_has|wait_cap_has|…)`，
数的是**真的会打印一条 ✓/✗ 的调用**（定义与复算脚本见 §1）。

## 1 · 三个文件是怎么选出来的（可复算）

两把尺子都算了，都指向同一组文件。基线树 = 本轮改动之前（`git archive` 出 `tests/` 后逐文件统计）：

```
 calls  call/line  P318  lines  file
  5146      0.224 0.158  22996  smoke.sh          ← 任务书 deps 排除（P344/P346 写集）
   551      0.241 0.138   2289  panel-p21.sh      ← 第 2 轮（P318 D-3）已过
   281      0.178 0.133   1583  config-cli.sh     ← 本轮
   258      0.195 0.009   1322  key-replies.sh    ← 本轮
   254      0.174 0.129   1461  panel-b3.sh       ← 本轮（不在门禁段，见 §5）
   210      0.170 0.006   1232  delivery-truth.sh ← 下一轮的自然候选
   197      0.156 0.127   1262  panel-b2.sh       ← 第 1 轮已过
```

- 已过轮次的四个文件（`signal-gate` 96 / `team-bg-stop` 73 / `panel-b2` 197 / `panel-p21` 551）不再计入；
  `smoke.sh`（5146）与 `routes.sh` 按任务书排除（P344/P346 写集）。
- 两把尺子给出的**同一组**前三个未过轮次文件，所以选哪把尺子都是这三个。
- **一处口径选择，请 PM 知情**：逐字严格的前三是 `panel-p21`(551)、`config-cli`(281)、`key-replies`(258)；
  但 `panel-p21` 正是第 2 轮（P318 D-3）交付的文件，`panel-b2` 是第 1 轮的任务书点名文件。我把**已过轮次的
  四个文件**（signal-gate / team-bg-stop / panel-b2 / panel-p21）从候选里去掉，取「未过轮次里最高的三个」。
  若你要的是逐字严格的前三，那就等于再瘦一遍第 2 轮的同一份文件——请裁定，我按你的意思重跑。
- `key-replies` 的 P318 密度异常低（0.009），是因为它的断言全部走 `eq/has/not_has/jok` 这层封装——这正是
  P318 之后换用「断言调用点」这把尺子的理由。

## 2 · config-cli.sh：350 → 326（逐条交接）

每一处都在代码里留了注释说明「删的是什么、谁接管」（↦ = 接管者）：

| 原文 | 处置 | 谁接管 |
|---|---|---|
| `check_rc "坏枚举的报错带接受域（TEAM_MONITOR_UI）" 4 TEAM_MONITOR_UI colour --yes` | 删 | 同 argv 的 `"TEAM_MONITOR_UI=colour → 4"`（rc）+ 紧邻的 `case *auto*tui*text*`（文案），两半都还在 |
| `assert_eq "refuse：TEAM_PROJECT 的退出码是 5"` | 删 | 矩阵里的 `check_rc "TEAM_PROJECT=x → 5（refuse）"`（同一条命令） |
| `assert_eq "refuse 被拒之后契约逐字节未变"` | 删 | 同区块的 `assert_eq "所有被拒的尝试都没改契约"`（矩阵已含该命令并比过 sha） |
| writer 段普通替换路径上的 `bash -n` | 删 | 同一文件后面两处 `bash -n`（追加路径、五个元字符值之后） |
| roster ①：`case *"什么都没做"*` | 删 | ①「契约逐字节不变」「没有工作树」「没有 state 文件」三条行为断言 |
| roster ④：`case *"已在名册"*` | 删 | ④ rc=0 + 契约逐字节不变 + 审计行数不变 |
| roster ⑨：`grep -c 'zeta'` | 删 | ⑨「退休拒绝不动契约」（整文件 sha）——字节没变不可能多出席位名 |
| roster ⑨：`grep -c '^TEAM_AGENT_MODELS='` | 删 | 同上 |
| seats：`for seat in dev pm dev4`（6 条：3 rc + 3 入口文案） | 删 | roster ⑪（未知席位 → 5、pm → 5、退休路线点名 `set-task-model` 与 `TEAM_PM_MODEL`）；⑪ 所在段在 §51 也跑 |
| shape：`rej_seat '/a'`（2 条） | 删 | `rej_default '/a'`（同一处判定的主路）+ `rej_seat 'a//b'`（这条路确实共用同一判定的证据） |
| shape：`rej_seat 'a/'`（2 条） | 删 | 同上 |
| roster ⑫：`space-trail` 形状（5 条：rc / 字节 / 审计 / 形状文案 / 手改路线） | **已恢复** | 上一轮当成 `space-lead` 的同形状删了；V85 的窄变异证明它是唯一覆盖，见 §11.1 |
| docs：schema → `references/config.md` 对拍（1 条） | 删 | completeness 段 `check_completeness` 的第三个 while（同一份 schema、同一个文件、同一个 `grep -qF`） |

**保留的（举其大类，每类给判据）**：退出码矩阵（validate 的 `4/5/7`、cas 的 `0/3/4`、JSON 四个机器出口）——
契约面；写入器的字节级约束（只改一行、注释保留、缺尾换行不粘行、单引号形态、sha 不变）——哑失效（写坏契约 =
之后每条命令都读错）；拒绝语的文件路线（`.pi/team/config.sh`）与不成句行话的禁令——CLI 表面的拒绝语义
（P278/O7）；夹具的仪器断言（mutant 是否落地、scratch 树是否先绿）——D-2 的先例，且 §4 证明它们仍会红。

## 3 · key-replies.sh：212 → 203（4 处合并 + 3 处删除）

| 原文 | 处置 | 谁接管 |
|---|---|---|
| input：`重复提交不合并（两条）` + `编号严格递增` | 合并成一条 `jok`（两条 + 最新编号=2） | 自己（一个谓词判两个面） |
| original：`两份 sha256 一致` | 删 | 紧挨着的 `cmp -s`（逐字节相同 ⇒ sha 相同，它不可能单独变红） |
| concurrency：`两条记录` + `编号互不相同且连续` | 合并成一条 `jok` | 自己 |
| receipts：`锁被占时 show 照常` + `list 照常` | 合并成一条（退出码对 `0/0`） | 自己（任一半走样都红） |
| interrupt：`坏槽尺寸未变` | 删 | `坏槽字节未被改写（sha 不变）`（整文件 sha 蕴含尺寸） |
| paging：`每个编号恰出现一次且降序` + `起点 123` + `终点 1` + `无重复编号` | 合并成一条「链恰好是 `123 122 … 1`」 | 自己（更强：四条各自独有的破坏都会红它，且顺带钉住无跳号） |
| bounded：`坏最新槽 summary=unavailable` + `坏最新不退回旧标题` | 合并成一条 `jok` | 自己 |

**明确留下并说明理由的两类**：

- `bounded` 的读数阈值（`≤64 KiB` / `≤100 syscr` / `≤8 KiB`）像「性能阈值」，但它判的是**有界读**本身
  （V27 的事故：读量随历史规模增长），不是时间；拿掉等于拆掉那条事故的墓碑。
- `paths` 的「净化规则两份实现字面一致」：判**留**。它不是文案快照，而是 `panel/src/sanitize.ts` 与
  `replies.mjs` 共用一套规则的唯一约束；紧邻的行为对拍只覆盖敌意载荷里出现过的字符类。若 PM 认为源文本
  比对不该进门禁（D170 口径），这是下一轮要裁的一条。

## 4 · 红侧（删掉的是重复，不是唯一守门人）

**a) config-cli**（`TEAM_CONFIG_TREE=` scratch 树，跑 `roster` 段）

```
== green side (unmutated scratch) ==
===== green0 ===== rc=0 == 结果 ==  ✓ 92  ✗ 0  SKIP 0

== mutant A: seat-name whitespace rejection removed ==
===== mutantA ===== rc=1 == 结果 ==  ✓ 77  ✗ 15  SKIP 0
  ✗ ⑫ space-inner：4（invalid，写入前就拒）（期望 [4]，实际 [1]）
  ✗ ⑫ space-inner：名册字节不变（… 实际 [59634cb4…]）
  ✗ ⑫ space-inner：审计里没有 ok 行（期望 [0]，实际 [1]）
  ✗ ⑫ space-lead：4（invalid，写入前就拒）（期望 [4]，实际 [1]）  …
  ✗ ⑫ tab：4（invalid，写入前就拒）（期望 [4]，实际 [1]）  …

== mutant B: set-agent-model no longer refuses (retires to rc 0) ==
===== mutantB ===== rc=1 == 结果 ==  ✓ 89  ✗ 3  SKIP 0
  ✗ ⑪ set-agent-model 已退休 → 5（期望 [5]，实际 [0]）
  ✗ ⑪ 退休路线不完整（）
  ✗ ⑪ pm 席位也只能走独立 PM 写入器（退休 → 5）（期望 [5]，实际 [0]）

== restore (byte-identical cmd-config.sh) ==
===== restored ===== rc=0 == 结果 ==  ✓ 92  ✗ 0  SKIP 0
```

mutant A 的 15 条红看着像「三个存活形状全红 ⇒ 删掉的 space-trail 有承接者」。**这个读法是错的**：
那是**宽变异**（整条空白拒判拿掉），它让被删的断言与存活断言一起红。V85 的窄变异（**只**放行尾部空白）
证明 `space-trail` 是唯一覆盖（删后全绿、删前红 5 条）——这条已恢复，窄变异读数见 §11.1。
mutant B 的 3 条红正好是 ⑪ 的三条，这一条结论不变（窄变异 C9 也复现了）。

**b) key-replies**（`KR_SKILL=` scratch 树，跑 `paging` 组）

```
===== green0 ===== rc=0 == P234 key-replies 结果 == ✓19 ✗0 SKIP0
== mutant: cursor made inclusive (page boundary repeats) ==
===== mutant ===== rc=1 == P234 key-replies 结果 == ✓8 ✗11 SKIP0
  ✗ paging：链恰好是 123 122 … 1（无重复、无缺失、降序）：… 实际 [… 75 74 74 73 … 26 25 25 24 …]
  ✗ paging：--json --before 31 生效（第一条 #30）：期望 [30] 实际 [31]
  …
===== restored ===== rc=0 == P234 key-replies 结果 == ✓19 ✗0 SKIP0
```

（两个红侧脚本留在 `/var/tmp/p348/redside-config.sh`、`/var/tmp/p348/redside-key-replies.sh`，复验命令见 §10。）

## 5 · panel-b3.sh：不在任何门禁段里，所以只报不删

- 判据来源是任务书边界（「若某个文件其实不在任何门禁段里，先报告、别急着删」）与本仓自己写下的取证：
  `references/troubleshooting.md:1128`「…is pinned only by `tests/panel-b3.sh board`, which the gate does not
  run: no gate section carries it」。
- 复核（三种查法一致）：`smoke.sh` 里 `panel-b3.sh` 只出现在 5 处**注释**里、没有调用点；`section-paths.tsv`
  不含它（§28 调的是 `panel-b3-stub.sh`）；`.github/workflows/gates.yml` 不含它。
- 它守的东西今天**没有任何门禁或 CI 执行**：真 pty 的按键（能力键 / 焦点行走 / 详情原地返回）、SGR 鼠标直驱与
  tmux 全链路、滚轮、resize 实时重排、`q` 收起后巡检仍在跑（7.1）、看板折叠（P123）。§28 覆盖的是
  `--snapshot` 可判定的那一半；pty 那一半是空档。
- 文件自己的断言分布（按场景，计调用点）：`workdetail 65`、`detail 47`、`board 35`、`fold 30`、`pages 15`、
  `collapse 14`、`settings 13(+4)`、`mouse 12(+4)`、`queue 11`、`resize 9`、`wheel 4`、plumbing 8，共 267。
  其中相当一部分是「捕获里有 [某页签]」这类文案断言——对 TUI 它们是**用户可见行为**，但在没有门禁执行的前提下
  多删只是让一个不跑的夹具更瘦，不产生真实信号。
- **请 PM 裁**：① 另立任务把它接进门禁（要动 `smoke.sh`/`section-paths.tsv`，P344/P346 的写集；P327 给
  `panel-b2` 做的是同一件事，可照抄配方）；② 或接受「pty 面只有快照半覆盖」并把它写成已知缺口。
  在①之前，这份文件的任何瘦身都不算交付价值。

## 6 · 稳定性：受影响的选段（实跑）

选段器给的就是这 9 段（`--paths` 只按改过的两个文件取段；整套里 §61b 的变异矩阵约 82 分钟，按任务书不跑）：

```
$ bash skills/teamsmith/tests/section-select.sh --paths \
    skills/teamsmith/tests/config-cli.sh skills/teamsmith/tests/key-replies.sh
decision=RUN · sections=135 · keys=8
0 0b 0c 0d 12b-h0d 33 40 51 62
```

```
$ bash skills/teamsmith/tests/config-cli.sh          # 返修树上的全量夹具
== 结果 ==  ✓ 331  ✗ 0  SKIP 0          （2m21s）

$ bash skills/teamsmith/tests/smoke.sh --select "0,0b,0c,0d,12b-h0d,33,40,51,62"
#1 0 · 临时仓库 · 参考 用时 0s · ✓3 ✗0 SKIP0 · ticks 3
#2 0b · skill 可被 pi 解析器加载 · 参考 用时 0s · ✓2 ✗0 SKIP0 · ticks 2
#3 0c · 静态检查（函数结尾的 set -e 陷阱） · 参考 用时 0s · ✓9 ✗0 SKIP0 · ticks 9
#4 0d · 冲突标记守卫（受版本控制的文件里不许有冲突标记） · 参考 用时 0s · ✓9 ✗0 SKIP0 · ticks 9
#5 12b-h0d · P80 下边框判据 · 参考 用时 8s · ✓83 ✗0 SKIP0 · ticks 83
#6 33 · 项目契约的读写面 · 参考 用时 142s · ✓1 ✗0 SKIP0 · ticks 1
#7 40 · 临时根纪律 · 参考 用时 244s · ✓42 ✗0 SKIP0 · ticks 42
#8 51 · 用法诚实性（help/名册路线） · 参考 用时 1086s · ✓3 ✗0 SKIP0 · ticks 3
#9 62 · 关键回复存储与 CLI · 参考 用时 729s · ✓1 ✗0 SKIP0 · ticks 1
账本自查： 9 段收口 · 增量 ✓153 ✗0 SKIP0 ｜ 结果行 ✓153 ✗0 —— 一致
== 选段结果 ==  ✓ 153  ✗ 0
smoke_rc=0                                  （挂钟 ≈ 43 分钟；返修前后各跑一次，两次读数一致）

$ "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 21 passed, 0 failed (21 items)      rc=0

$ git diff --check && git status --short    → 无输出（工作树干净）
```

## 7 · 改动范围

只改了两个文件：`skills/teamsmith/tests/config-cli.sh`、`skills/teamsmith/tests/key-replies.sh`。
没有碰 `smoke.sh`、`routes.sh`、`section-paths.tsv`、产品实现、`openspec/`；没有加门禁段、没有改任何时限；
`panel-b3.sh` 一条没删。返修只动 `config-cli.sh` 的 ⑫ 形状循环（恢复 `space-trail` 并改写那段注释）。

## 8 · 没做的事

- 没跑整套门禁（§61b 变异矩阵约 82 分钟，任务书明确不跑）。
- 没改 `smoke.sh` §62 的 300 秒挂住上限（任务书边界「不改时限」），只报成本（§9.2）。
- 没动 `panel-b3.sh` 的任何断言（§5）。

## 9 · 交还 PM 的两件（都不在我的写集里）

**9.1 main 的 §0e 现在红着（`--loop-check` 一条不成立）** —— `smoke.sh` 与 `loop-inventory.tsv` 我一个字没改
（`git diff main -- <这两个文件>` 为空），但 `main` 的树本身跑不过：

```
$ git archive main skills/teamsmith | tar -x -C <scratch> && cd <scratch>
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
bad: smoke.sh:6449 的 while 行与清单第 30 行的锚点不符
     源码：  while [ "$R_WAIT" -lt "$R_MAX" ]; do
     清单：  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; …
section-guard --loop-check: 1 条不成立        （rc=1）
```

成因：`33da8f86`（P326）把那个有界轮询重写成 `R_WAIT=0; R_MAX=1500; … while [ "$R_WAIT" -lt "$R_MAX" ]`
（为了让读端自己的退出码留下来），**没同步清单行**。§0e 的 `assert_eq "P70 循环清单：干净树绿" "$P70_RC" "0"`
因此必红——整套门禁在 main 上跑不起来，与我的改动无关。已验证的 3 列补丁（scratch 树上实测 `--loop-check`
→ `全过` rc=0），`skills/teamsmith/tests/loop-inventory.tsv` 第 47 行：

```diff
-smoke.sh	6365	cap="$R_WAIT" -lt 1500	  while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster 2>/dev/null | grep -qF "pi 已退出"; do sleep 0.2; R_WAIT=$((R_WAIT + 1)); done
+smoke.sh	6449	cap="$R_WAIT" -lt "$R_MAX"	  while [ "$R_WAIT" -lt "$R_MAX" ]; do
```

（第二列是行号，清单自己注明「文档用」；第三列 `cap=` 是判据文本，必须在循环文本里出现——只改锚点不改它，
会转成另一条红「循环丢了上限」。）建议派给 P326 的后续，或 P346（它已在动 `smoke.sh` 的测试面）。

**9.2 `panel-b3.sh` 的接线**：见 §5，需要动 `smoke.sh`/`section-paths.tsv`。

## 10 · 复验者怎么自己重跑

```sh
# 1) 两个文件各自的夹具（原版 vs 改后，断言数就是交付数字）
bash skills/teamsmith/tests/config-cli.sh          # 期望 ✓326 ✗0（2m18s）
bash skills/teamsmith/tests/key-replies.sh --all   # 期望 ✓203 ✗0（12m10s）
# 2) 红侧（scratch 树，不碰真树）
bash /var/tmp/p348/redside-config.sh               # 92/0 → 77/15 → 89/3 → 92/0
bash /var/tmp/p348/redside-key-replies.sh          # 19/0 → 8/11 → 19/0
# 3) 选段（选段器给的就是这 9 段）
bash skills/teamsmith/tests/section-select.sh --paths \
  skills/teamsmith/tests/config-cli.sh skills/teamsmith/tests/key-replies.sh
# 4) 门禁那 9 段（约 43 分钟）
bash skills/teamsmith/tests/smoke.sh --select "0,0b,0c,0d,12b-h0d,33,40,51,62"
# 5) 返修：20 处逐条窄变异（每处一个变异体，读「存活断言红不红」）
P348_W=$HOME/.cache/p348-rejudge bash /var/tmp/p348/rejudge.sh        # 期望 20 行全 CAUGHT（3 分钟）
P348_W=$HOME/.cache/p348-rejudge bash /var/tmp/p348/rejudge.sh C12    # 单跑 space-trail 那条窄变异
#    变异体：$HOME/.cache/p348-rejudge/patches/<id>.py；日志：$HOME/.cache/p348-rejudge/{cc,kr}-<id>-*.log
# 6) 交还 PM 的既有红（在 main 的树上也会红）
bash skills/teamsmith/tests/section-guard.sh --loop-check    # 期望 main 上 rc=1，打过 §9.1 补丁后 全过
```

## 11 · 返修（V85 判 PARTIAL 之后）

**V85 判得对，我上一轮的红侧方法有漏洞**：我用的变异是「整条规则拿掉」（把席位名的空白拒判整个删掉），
那会让被删断言与存活断言**一起**红，于是"有承接者"看起来成立。V85 用的是**窄变异**——只坏被删那一条守的
那件事（尾部空白放行、前导照拒）——`space-trail` 是唯一覆盖（删后 ✓92 ✗0，删前同变异红 5 条）。
按这个口径，我把 20 处（config-cli 13 处 + key-replies 7 处；其中 key-replies 的 7 处含 4 处合并）逐条重判了一遍。

### 11.1 恢复 `space-trail`（config-cli ⑫）

`skills/teamsmith/tests/config-cli.sh` 的形状循环恢复成四个：`space-inner` / `space-lead` / `space-trail` / `tab`，
注释写明它是窄变异的唯一覆盖（不留"同一形状"的假话）。

窄变异（`team_config_seat_violation`：只放行**尾部**空白，前导与内嵌照拒）：

```
===== 绿侧（未变异） =====  == 结果 ==  ✓ 97  ✗ 0
===== 变异（尾部放行） =====  == 结果 ==  ✓ 92  ✗ 5
  ✓ ⑫ space-inner：4（invalid，写入前就拒）        ← 存活
  ✓ ⑫ space-lead：4（invalid，写入前就拒）         ← 存活
  ✓ ⑫ tab：4（invalid，写入前就拒）                ← 存活
  ✗ ⑫ space-trail：4（invalid，写入前就拒）（期望 [4]，实际 [1]）
  ✗ ⑫ space-trail：名册字节不变（期望 [ac15bd17…]，实际 [fdda2a3a…]）
  ✗ ⑫ space-trail：审计里没有 ok 行（期望 [0]，实际 [1]）
  ✗ ⑫ space-trail：没给接受形状（✗ 未知 agent：api （名册：dev verify api ））
  ✗ ⑫ space-trail：没给路线（✗ 未知 agent：api （名册：dev verify api ））
```

这五行正是 V85 说的那类事故：**失败的命令改了状态，名册里多出一个用户没打的名字**。

### 11.2 20 处逐条窄变异读数

方法（可复算）：`git archive`/硬链接复制一份私有 skill 树 → 只打一处**窄**变异 → 跑那一处所在的门禁/夹具段
→ 读「存活断言是否红」。红 = 有承接者；全绿 = 唯一覆盖（必须恢复）。全 20 条 **CAUGHT**（无一例外），
下表每行的「红的读数」都是实跑日志里的一行原文（脚本：`/var/tmp/p348/rejudge.sh`，逐条变异体在
`$HOME/.cache/p348-rejudge/patches/<id>.py`，日志 `$HOME/.cache/p348-rejudge/`）。

| # | 文件 · 段 | 删/合并的东西 | 窄变异（只坏这一件事） | 红的读数（存活断言） |
|---|---|---|---|---|
| C1 | config-cli · validate | 同 argv 的重复 `check_rc`（标签说判文案，实际只判 rc） | 枚举拒绝的文案不再列接受域 | `✗ 枚举报错没点名接受域（✗ TEAM_MONITOR_UI=colour 不合法：只接受合法值）` |
| C2 | config-cli · validate | refuse 的 rc=5 重复断言 | refuse 类返回 4 | `✗ 退休 TEAM_AGENT_MODELS → 5（期望 [5]，实际 [4]）`（矩阵） |
| C3 | config-cli · validate | refuse 后契约未变的重复断言 | refuse 路径顺手写一行注释 | `✗ 所有被拒的尝试都没改契约（efdfa0… → cce9fb…）` |
| C4 | config-cli · writer | 就地替换后的 `bash -n` | 就地替换少一个收尾引号 **且** 摘掉写入器自带的语法复核 | `✗ 追加后 bash -n 失败` / `✗ 元字符值把文件写坏了` |
| C5 | config-cli · roster ① | 「什么都没做」文案断言 | 未知席位拒绝前先建工作树 | `✗ ① 居然建了工作树` |
| C6 | config-cli · roster ④ | 「已在名册」文案断言 | 重复 `--register` 时改一字节 | `✗ ④ 契约逐字节不变（153d9d… → c9a142…）` |
| C7 | config-cli · roster ⑨ | `grep -c 'zeta'` | 退休拒绝时把席位名写进注释 | `✗ ⑨ 退休拒绝不动契约（153d9d… → 40a4b5…）` |
| C8 | config-cli · roster ⑨ | `grep -c '^TEAM_AGENT_MODELS='` | 退休拒绝时造一个空 `TEAM_AGENT_MODELS` 键 | `✗ ⑨ 退休拒绝不动契约（153d9d… → 4107ea…）` |
| C9 | config-cli · seats 三席位循环 | `set-agent-model` 三个身份各跑一遍 | 退休拆掉（返回 0） | `✗ ⑪ set-agent-model 已退休 → 5（期望 [5]，实际 [0]）` |
| C10 | config-cli · shape | `rej_seat '/a'`（2 条） | 共享判定放行空 provider | `✗ 拒绝[model-kind] /a → 4（期望 [4]，实际 [0]）` |
| C11 | config-cli · shape | `rej_seat 'a/'`（2 条） | 共享判定放行 model 空段 | `✗ 拒绝[model-kind] a/b/ → 4（期望 [4]，实际 [0]）` |
| C12 | config-cli · roster ⑫ | `space-trail` 形状（5 条）→ **已恢复** | 只放行尾部空白 | `✗ ⑫ space-trail：…实际 [1]`（5 条，见 11.1） |
| C13 | config-cli · completeness | schema→config.md 对拍 | 删掉 `TEAM_PANEL_DETAIL_CAP` 的文档行 | `✗ 真实 schema 有缺口` |
| K1 | key-replies · input | 合并进一条 `jok`（两条 + 最新编号=2） | 同正文去重（第二次返回已有编号） | `✗ input：重复提交/编号不对（total_slots=1 …）` |
| K2 | key-replies · original | `两份 sha256 一致` | raw 导出多一个换行 | `✗ original：raw 与输入不同` |
| K3 | key-replies · concurrency | 合并成一条 `jok`（条数 + 编号集合） | 摘掉发布时的写锁 | `✗ concurrency：条数/编号不对（total_slots=1 …）` |
| K4 | key-replies · receipts | show/list 两条并成 `0/0` | show 也去抢写锁 | `✗ receipts：锁被占时 show/list 照常（都 rc=0）：期望 [0/0] 实际 [5/0]` |
| K5 | key-replies · interrupt | `坏槽尺寸未变` | 坏槽当尾巴截掉（改写已提交字节） | `✗ …坏槽字节未被改写（sha 不变）` |
| K6 | key-replies · paging | 四条并成「链恰好 123…1」 | cursor 改成包含式 | `✗ paging：链恰好是 123 122 … 1……实际 [… 75 74 74 73 …]` |
| K7 | key-replies · bounded | 两条并成一条 `jok` | 坏最新槽退回上一个好槽 | `✗ bounded：坏最新槽的处理不对（state":"ok" …）` |

**四条合并也按同一口径判过**（K1/K3/K4/K7）：两半各自都有「只坏它」的变异体让合并后的那条红；
K6 的四条用 inclusive-cursor 一个变异体就同时点名（重复的 74 与 25）。

### 11.3 两处上一轮说法不成立、这一轮改口径的

1. **C4（writer 的 `bash -n`）**：上一轮我说「同文件后面还有两次 `bash -n`，这一处坏了在下面同样红」。
   实测**不成立**——写入器自己在落盘前先跑一次 `bash -n`（`cmd-bootstrap.sh:99`），坏文件根本落不了地，
   于是测试侧那两条永远是绿的。真正的窄变异必须**同时**摘掉写入器自带的复核（上表 C4），此时
   `✗ 追加后 bash -n 失败` 与 `✗ 元字符值把文件写坏了` 一起红——删除仍然成立，但理由是「测试侧复核是
   写入器复核之外的第二道网」，不是"同文件后面还有两次"。
2. **C6/C7/C8 的第一版变异体是坏的**：我把写盘目标写成 `$TEAM_CONFIG_FILE`（那个上下文里是空的），
   `printf` 失败把命令本身的 rc 改掉了，红的是别的东西。改成 `$(team_config_contract_path)` 后，
   命令的 rc 不变、只有契约字节变，红的正是承接的那条 sha 断言。
