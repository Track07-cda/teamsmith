# P98 · gate-runtime-budget apply（分段账本 + 路径选段）

agent: dev3   status: DONE   time: 2026-09-28（含合并 main 后的 F1 返工）
branch: `task/P98-apply`   PR/MR: -（本地模式，不 push；分支留在本地 worktree）

> **F1（2026-09-28 · PM thread 12:38Z）**：正文的原始证据块写于合并 `main` 之前（当时套件 105 段）；
> 合并后套件是 **109 段**。返工内容、合并解里那个真缺陷、以及 109 段口径下的全套证据见文末
> 「F1 · 合并 main 之后」。
> **F2（2026-09-28 · PM thread 14:12Z）**：P70（gate-section-accounting）在 F1 之后才落进 main，
> 两套段落机制真集成（收口行**统一成一条**）、段表/预算表/循环清单补齐，套件现在是 **113 段**。
> 口径以文末「F2 · 再合并 main」为准。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/section-paths.tsv` | 路径→段映射：109 行（`key/id/patterns/needs/basis`，合并 main 后 +4：`34b`/`49`/`50`/`51`）+ 豁免类 `docs/*` + 前导段 `0 0b 0c 0d`。`needs` 按实测补齐（每条在 `basis` 里写清观察到的失败）。 |
| `skills/teamsmith/tests/section-select.sh` | 选择器：`--paths` / `--select` / `--check` / `--list`；`decision=FULL\|NONE\|RUN` + `reason=` + `key<TAB>why` 行；matcher 是唯一的 `case` glob（`*` 跨 `/`，保守方向 = 多选）；硬错误（未知 key、路径出界、表畸形）退出 2。 |
| `skills/teamsmith/tests/smoke.sh` | ① 每段收口行 `#N id · 秒 · ✓P ✗F SKIPk`（纯文本、无门禁红标、不与阈值比较）+ 最慢 N 段汇总 + 账本自查；② `--paths`/`--select`（NONE 不排队不建根；RUN 跑过滤副本；FULL 兜底全套并把运行头/收尾记账改成 109/109）；③ 36 段自检（选择器、账本、夹具与门禁同一口径）+ 36⑤（锁 × 选段：P66 的 marker/loud-cap 与选段标记的组合）。 |
| `docs/team/reports/P98-f1/` | 锁×选段探针（`lock-select-probe.sh`）+ 合并解 `exec`→`env` 的 flip 现场（`logs-pre-fix` 红 → `logs-post-fix` 绿 13/0）。 |
| `docs/team/reports/P98-f2/` | F2（P70 集成）证据：`section36-harness.sh`（运行时抽取真 §36）、`shape-flip-probe.sh`（三处断言的形状翻转）、`logs/`（FAST/全量/check/budget/loop/routes/flip-m33/形状翻转/空段守卫对比）。 |
| `skills/teamsmith/references/protocol.md` | §9b-2 一句：`section-select.sh --paths` 是「FAST + 受影响段」的机械形式；选段运行列出没跑的段。 |
| `skills/teamsmith/references/troubleshooting.md` | 长任务条目一句：选段跑法；全量仍是交付/复验门禁。 |
| `skills/teamsmith/tests/flip-m33.sh` | 收割机等 26-i 锚点的上限 300s → 600s（见「Decisions」第 4 条：这是夹具的既存假红）。 |

## Verification evidence (must have actually been run)

### 选择器（纯逻辑）

```
$ bash skills/teamsmith/tests/section-select.sh --check          # 2.1s
ok: 映射表 key 唯一（105 行）
ok: 段 ↔ 行一一对应（源码 105 段 / 表 105 行）
ok: needs 声明全部存在且指向更早的段（60 条）
ok: 字面模式全部存在于工作树（446 条）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（376 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 7  bad 0
```

```
$ bash skills/teamsmith/tests/section-select.sh --paths docs/team/BOARD.md docs/team/reports/P97-dev3.md
decision=NONE
sections=105
keys=0
reason=docs/team/BOARD.md ← 豁免类（docs/*）：团队账本，门禁不为它开火
reason=docs/team/reports/P97-dev3.md ← 豁免类（docs/*）：团队账本，门禁不为它开火
reason=没有段落需要运行（no section needs to run）

$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/outbox.sh | head -6
decision=RUN
sections=105
keys=38
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← prologue
# 选中键含验收表点名的 14 个投递段：12b 12b-h0 12b-h0b 12b-h0c 12b-h0d 12b-pi 12b-pi2 12b-pi3 26 27 42 44 46 47

$ bash skills/teamsmith/tests/section-select.sh --paths ci/some-new-thing
decision=FULL
sections=105
keys=0
reason=ci/some-new-thing ← 没有任何行声明它（也不在豁免类）
reason=兜底：跑全套（多跑总是安全，少跑不是）

$ bash skills/teamsmith/tests/section-select.sh --select no-such-section; echo rc=$?
section-select: 未知 key：no-such-section（用 --list 看全部 key）
rc=2

$ bash skills/teamsmith/tests/section-select.sh --paths /etc/passwd; echo rc=$?
section-select: 路径出界：/etc/passwd（只接受仓库根相对路径，不允许绝对路径 / .. / ~）
rc=2
```

### 门禁侧：无 flag / NONE / RUN / FULL / 未知 key

```
$ bash skills/teamsmith/tests/smoke.sh --paths docs/team/BOARD.md        # FAST；整段输出
== 选段 == decision=NONE —— 没有段落需要运行（no section needs to run）
  没有段落需要运行（no section needs to run）
  选段运行：一段都没跑、没有结果行、不是门禁证据（交付 / 复验 / 归档仍跑整套）
rc=0 · 一个段头都没有（grep '== 0 · 临时仓库' = 0）

$ bash skills/teamsmith/tests/smoke.sh --select no-such-section; echo rc=$?
section-select: 未知 key：no-such-section（用 --list 看全部 key）
smoke: 选段被拒 —— 什么都没跑
rc=2（段头 0 条）

$ bash skills/teamsmith/tests/smoke.sh --select 12b      # FAST，rc=0，21s；运行 7/105 段（0 0b 0c 0d 2 5 12b —— 2/5 是 12b 的 needs 闭包）
== 选段 == decision=RUN · 运行 7/105 段 · 未跑 98 段
  这次不跑的键：1 1b 1c 3 4 4b 4c 3b 6 6b … 47 48 15
# 修复前（needs 未补齐）：#5 12b · 延后投递与草稿入口（delivery-guard：守卫 / 队列 / 排水 / 草稿） · 18.9s · ✓69 ✗11 SKIP1
# 修复后：              #7 12b · … · 19.5s · ✓80 ✗0 SKIP1     ← 与全量同 tip 的 12b 逐项一致
账本自查： 7 段收口 · 增量 ✓146 ✗0 SKIP1 ｜ 结果行 ✓146 ✗0 —— 一致
== 选段结果 ==  ✓ 146  ✗ 0
== 选段：这次没跑的段 == 98 个键
  1 1b 1c 3 4 … 47 48 15
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
# tail -25 里带未跑清单；全文没有 `smoke 全绿`、没有 `== 结果 ==`

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --paths ci/some-new-thing   # 真树 FULL 兜底
== 选段 == decision=FULL · 运行 105/105 段 · 未跑 0 段
  这次不跑的键：（无 —— 全套都在跑）
  ci/some-new-thing ← 没有任何行声明它（也不在豁免类）
  兜底：跑全套（多跑总是安全，少跑不是）
== 选段结果 ==  ✓ 2811  ✗ 0     # rc=0，647s；比裸 FAST 少 17 条 = 14c 的全套跳过清单自检在选段模式下显式跳过
== 选段：这次没跑的段 == 0 个键
```

### 账本（全量 FAST，纯记录不改退出码）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null    # rc=0，648s，load 6.1/6.1/5.7 → 12.5/12.2/9.5
账本自查： 105 段收口 · 增量 ✓2828 ✗0 SKIP33 ｜ 结果行 ✓2828 ✗0 —— 一致
== 最慢 5 段 ==
  #59 12b-pi · … · 76.1s · ✓103 ✗0 SKIP0
  #94 38 · … · 56.9s · ✓20 ✗0 SKIP2
  #90 34 · … · 47.3s · ✓27 ✗0 SKIP0
  #92 36 · … · 33.8s · ✓64 ✗0 SKIP0
  #74 26 · … · 33.1s · ✓121 ✗0 SKIP1
== 结果 ==  ✓ 2828  ✗ 0
# 105 条收口行、最后一条在结果行之前、收口行里没有 `  \033[31m✗\033[0m`（本次全量 grep 红标 = 0 条）
```

### 不变式：before / after（同一棵树，只有本 change 的差）

| 树 | 命令 | ✓ | ✗ | SKIP | exit | wall |
|---|---|---|---|---|---|---|
| `f5c53956`（parent） | `TEAM_SMOKE_FAST=1 smoke.sh` | 2764 | 0 | 33 | 0 | 676s |
| `task/P98-apply`（delivered） | 同上 | 2828 | 0 | 33 | 0 | 648s |

Δ = +64 ✓，正好等于 36 段自己的 ✓64（FAST / 全量两次跑里 36 段的收口行都是 `✓64 ✗0`）——既有段的计数没有变。
逐行核对：`git diff f5c53956 HEAD -- smoke.sh` 删除的行只有 5 处（`--keep` 解析行、门禁锁 re-exec 行、`section()`
定义、结果行 printf、最后的 `smoke 全绿` 行），没有删掉或改写任何既有断言；`bad "` 调用点 701 → 720，
增量 19 全部在新的 36 段里（36 段 `bad "` = 19）；`assert_*` 词元在 36 段外只多 1 处，那是账本自查注释里的
一个词（不是调用点）。

### 空段守卫（选段不许变成空跑）

`section-select.sh --paths …/outbox.sh` 选出的 38 段逐段与**同一 tip 的全量 FAST**对比（收口行的 ✓/✗/SKIP）：

```
# 方法：p98-ledger.sh 从两次运行的日志抽 #N 收口行，按 key join
# 结果：38 段全部一致（0 DIFF），rc=0，345s（全量 648s）
# 修复前：34 段、11 段低于全量（4 6f 6i 6j 11h 12b 12b-h0c 12b-pi 12b-pi2 12b-pi3 26），rc=1
```

`--select 17`（验收表点名）：运行 10 段（0 0b 0c 0d 2 4 5 3b 15b 17），`15b` 的段头在 `17` 之前；
`15b` ✓26 ✗0、`17` ✓34 ✗0，与全量逐项一致（0 DIFF），rc=0。

### 段自检（36 段，独立 harness 跑真实 36 段代码）

```
$ bash /tmp/p98sec36.sh      # 只用真 smoke.sh 的 36 段正文 + 真 assert 助手
== 段 36 结果 == ✓ 64 ✗ 0
# 含：--check 绿 + 5 个腐烂方向各自红且点名 + 未声明 token 红且点名 token 与源码行
#     + NONE/RUN/FULL 三形状 + 账本（收口数=key 数、增量之和=结果行、最慢段）
#     + 慢段照旧绿 + 旋钮只在 TEAM_SMOKE_FIXTURE=1 下生效 + 选段标记不外泄 + 必红段只对选中负责
# 同一份在 SMOKE_INVOKE_ROOT=""（flip-m33 的 cwd 条件）下重跑：✓64 ✗0
```

### 其它门禁

```
$ bash skills/teamsmith/tests/gate-guard.sh
ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
ok: panel-knobs.sh 不驱赶测量夹具
ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记
gate-guard: 三向都过（门禁无判定、旋钮助手在岗、性能套件带标记）   rc=0

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 31 passed, 0 failed (31 items)     rc=0

$ bash skills/teamsmith/tests/flip-m33.sh
== 跑 sentinel（… reap=once/mv；期望=sentinel） ==
  rc=2 · 红行 1 条 · 哨兵点名 1 条 · 到结果行 0 · 全绿 0
  ok sentinel：期望成立
flip-m33：证据成立    rc=0（见 FLIP-M33 节）

$ bash skills/teamsmith/tests/smoke.sh </dev/null      # 交付时一次全量
账本自查： 104 段收口 · 增量 ✓3493 ✗0 SKIP0 ｜ 结果行 ✓3493 ✗0 —— 一致
== 结果 ==  ✓ 3493  ✗ 0
smoke 全绿      rc=0，1162s（见 FULL-SMOKE 节）
```

## Flip evidence (required for defect-fix tasks)

### 1. 36 段自己：第一次 FAST 跑 6 条红 → 修 4 个夹具缺陷 → 0 条

```
# before（第一次 FAST，tip 32ac7afd）
  ✗ 36① 未声明 token 注入没打上（1 段的形状变了？）
  ✗ 36① 段正文塞了未声明 token：[--check] 没抓住（期望红）
  ✗ 36③ 跑了的段数 == 选择器给的 key 数（期望 [4]，实际 [8]）
  ✗ 36③ 段落增量之和 == 结果行总数（✓）（期望 [0]，实际 [42]）
  ✗ 36③ 账本自查行在（报告不是判定）（… 中找不到 [账本自查：]）
  ✗ 36④ 嵌套负例在选段子进程里仍被拒（… 中找不到 [✓ 夹具：… rc=2]）
# after（89641cd5 修 4 个夹具缺陷 → 36 段 ✓55；随后再加 FULL 兜底夹具 → ✓64）
== 段 36 结果 == ✓ 64 ✗ 0
```

四个缺陷（都在夹具侧，产品行为没被这些红指对）：
① token 变体把注入写到 `$P98_TK/skills/teamsmith/tests/smoke.sh`（`p98_variant` 返回的已经是 skill 根）→ perl 打空文件，
   检查器保持绿（两条红）；
② 最慢段汇总行用了和收口行一样的 `#N ` 前缀 → 收口数/增量被重复计数（4 段跑出 8 条、增量 42 对结果行 21）；
   汇总行改缩进两格，账本解析改成读 ✓/✗ 后面的数字；
③ 账本自查的冒号被颜色重置码隔开 → `assert_has` 找不到连续字节 `账本自查：`；
④ 泄漏夹具注入的脚本需要 `$TMP`/`$SKILL_DIR`，而 smoke.sh 不 export 它们 → 负例死在 `Permission denied`、rc=1 而非 2。

### 2. 选段空跑守卫：outbox 选段从 rc=1 / 11 段缩水 → rc=0 / 0 DIFF

```
# before（第一次真树 outbox 选段）
rc=1 wall=328s sections=34
 DIFF 4 sel=0/5/0 full=4 0 0        DIFF 6f sel=55/77/0 full=131 0 0
 DIFF 6i sel=68/3/1 full=71 0 1     DIFF 6j sel=13/4/1 full=16 0 1
 DIFF 11h sel=36/18/0 full=50 0 0   DIFF 12b sel=69/11/1 full=80 0 1
 DIFF 12b-h0c sel=16/3/1 full=19 0 1  DIFF 12b-pi sel=80/20/0 full=103 0 0
 DIFF 12b-pi2 sel=25/4/0 full=29 0 0  DIFF 12b-pi3 sel=40/12/0 full=52 0 0  DIFF 26 sel=120/1/1 full=121 0 1
# after（needs 按实测补齐：4/5/11h/26←2；6←4,3b；6f←6；6i←6；6j←…,6i；12b←5；12b-h0c←12b；12b-pi←6i,12b）
rc=0 wall=347s sections=38, 0 DIFF
```

每一条 needs 都是实测出来的，`section-paths.tsv` 的 `basis` 列写明观察到的失败（例：`12b` 的 `say dev` 在空名册上
报「收件人不在名册里」；`6j` 调 `login_shell_hides`，它定义在 `6i` 的段正文里；`6` 在 detached worktree 上拒绝派单）。

### 3. FULL 兜底记账：`运行 0/105 · 未跑 105` → `运行 105/105 · 未跑 0`

```
# before（tip f5c53956 上真树跑）：
== 选段 == decision=FULL · 运行 0/105 段 · 未跑 105 段     ← 明明是「全套照跑」
# after（delivered tip）：
== 选段 == decision=FULL · 运行 105/105 段 · 未跑 0 段
  这次不跑的键：（无 —— 全套都在跑）
```

修法：FULL 分支在渲染运行头之前把运行键集设为全部段；36 段用一个「只留段声明、去掉段正文」的空壳变体树把它钉住
（真树嵌套跑 FULL = 整套递归；也不在软链变体上跑正文，见 Decisions 第 5 条）。

### 4. `--check` 腐烂方向（绿 → 红且点名 → 恢复绿）

```
$ section-select.sh --check --table <每次只改一处的副本>
(a) 删掉 17 行              → bad: 源码里有段没有行：17
(b) 36 行 patterns 置 -     → bad: 段 36 读了它没声明的路径：token …section-select.sh（源码行 12459）
(c) 17 行 needs=no-such-seg → bad: 行 17 的 needs 指向未知段：no-such-seg
(d) 17 行 patterns 加 docs/team/* → bad: 行 17 声明了豁免类路径：模式 docs/team/* 覆盖 docs/team/BOARD.md
(e) 0 行加一个不存在的字面 pattern → bad: 行 0 的字面模式在工作树里不存在：skills/teamsmith/tests/p98-no-such-literal.md
(未声明 token：变体树 1 段正文里塞一行 → bad: … token skills/teamsmith/tests/section-select.sh（源码行 911）)
# 真表 --check 始终 ok 7 bad 0（夹具只改副本，不改真表）
```

## Decisions and deviations

1. **brief 里的 pre-change FAST 基线过期**：任务书写 `✓2759 ✗5 SKIP33`（P97 时代，main 上 14b/18 红）；
   本块实测 parent（`f5c53956`）= `✓2764 ✗0 SKIP33`（那两条红已被后续工作修掉）。基线以上表实测为准。
2. **smoke.sh 现在拒绝未知参数**（退出 2、什么都不跑），不再像以前那样静默忽略。理由：`--select` 打错一个字母
   却静默跑全套（或一段不跑）是同一种危险；仓库内没有调用方传 flag（`team review` 不带参）。
3. **needs 是实测声明的**，不是从「谁点名了路径」推导的：`--check` 只把「段正文读了没声明的路径」当腐烂方向，
   段与段之间的**状态依赖**只能靠选段跑出来的计数差发现（空段守卫）。每条补的 needs 在 `basis` 里带现场。
4. **flip-m33 的收割机上限 300s → 600s**：这不是本 change 引入的破——P97 的两轮全量实测（已提交在
   `docs/team/reports/P97/fast-section-times-r{1,2}.tsv`）里 26 段的累计时刻是 331s / 325s，本来就超过 300s；
   本块实测 342s。原夹具因此从来没等到锚点（沙盒里没有 `reaper:` 行、$TMP 没被动过、3 条红全来自变体段）。
   断言（恰好一条红 / 哨兵点名 / exit 2 / 诊断文件）一条没改，只抬了等锚点的时钟上限。
5. **变体树的软链风险**（给复验者的提醒）：`p98_variant` 造的树里文档面是**软链**；14b/18 那类「注入→还原」
   的夹具若在这种树上跑正文，会穿过软链写回真树。本 change 的所有变体跑法都只选不碰文档的段，FULL 兜底
   夹具更是只留段声明、去掉段正文（用它钉记账，不跑全套）。复验若要扩大变体跑法，先看这一条。
6. **`smoke.sh` 选段运行显式跳过 14c 的「预期段都被跳过」自检**：那张表对选段运行不成立（没选中的段既没跑
   也没跳过），跳过时打印一行说明而不是红。这不是放松既有断言：裸跑（无 flag）时它照旧执行（FAST 全量里
   `14c` = ✓17 ✗0）。
7. **`openspec/changes/gate-runtime-budget/tasks.md` 的勾选框留给 PM**：任务书的 `grant:` 没列
   `openspec/changes/**`（OWNERSHIP 写明实现路径必须逐条列出），我只交付实现与证据，不越权改 change 目录。

## FLIP-M33

```
$ bash skills/teamsmith/tests/flip-m33.sh
== 跑 sentinel（skill=…/dev3/skills/teamsmith；reap=once/mv；期望=sentinel） ==
  rc=2 · 红行 1 条 · 哨兵点名 1 条 · 到结果行 0 · 全绿 0 · 26-k 之后仍绿 0 条
  诊断：/tmp/.teamsmith-smoke-diag.991746.log（96 行）
  --- 诊断文件里的证据标题 ---
  == 2026-09-28T11:51:01+00:00 · $TMP 中途消失 · 后台哨兵（0.2s 轮询）第一次发现 ==
  期望：/tmp/teamsmith-smoke.s2PWaO（判据文件 /tmp/teamsmith-smoke.s2PWaO/.smoke-alive）
  现在：exists=no dev:ino=-
  ok sentinel：期望成立
pre 树：（git 里找不到不含哨兵的 smoke.sh，跳过 pre 侧：给 --pre-skill <树> 才跑）
flip-m33：证据成立（哨兵把「$TMP 中途消失」变成一条点名红 + 停跑）
flip-m33 rc=0 wall=318s
```

这是硬要求 1 的证据：新加的收口行 / 最慢段汇总 / 选段运行头尾都在同一份日志里，而**红标计数仍然是 1**
（只有哨兵那条）。全量 FAST（✓2828 ✗0）与所有选段运行（12b/17/outbox/NONE/FULL）里红标都是 0 条。
pre-change 侧被夹具自己 SKIP（git 历史里 40 个提交内没有「不含哨兵」的 smoke.sh），不是绿也不是假红；
给 `--pre-skill <树>` 可以补跑。

**F1 之后在最终 tip 上复跑**（合并 main + §36⑤ 落进去之后，rc=0，326s）：

```
$ bash skills/teamsmith/tests/flip-m33.sh
== 跑 sentinel（…） ==
  rc=2 · 红行 1 条 · 哨兵点名 1 条 · 到结果行 0 · 全绿 0 · 26-k 之后仍绿 0 条
flip-m33：证据成立（哨兵把「$TMP 中途消失」变成一条点名红 + 停跑）
```

红标计数与合并前一致（**1 条，只有哨兵**）—— 合并后的锁块（P66 的 marker/loud-cap × 选段标记）
与 §36⑤ 都没有往门禁红标计数里添东西。

## FULL-SMOKE

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
== load: 7.91 7.47 8.14 · nproc=32
账本自查： 104 段收口 · 增量 ✓3493 ✗0 SKIP0 ｜ 结果行 ✓3493 ✗0 —— 一致
== 最慢 5 段 ==
  #93 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 286.8s · ✓22 ✗0 SKIP0
  #59 12b-pi · M30 投递换道：pi 通道零 tmux 粘贴（收件箱监视唤醒） · 75.9s · ✓103 ✗0 SKIP0
  #58 12b-h0c · P59 输入框判据：覆盖层（Pi 的项目信任弹窗）≠ 非空输入框 · 64.0s · ✓124 ✗0 SKIP0
  #73 26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离） · 62.4s · ✓142 ✗0 SKIP0
  #89 34 · 门禁锁：排队/运行分开记账（P26/G1：…） · 47.3s · ✓27 ✗0 SKIP0
== 结果 ==  ✓ 3493  ✗ 0
smoke 全绿
FULL rc=0 wall=1162s
```

- 104 段收口（不是 105）：`14c · 快模式自检` 在全量模式下**从来不跑**（它只属于 FAST 分层，既有的条件段），
  所以「一段一条收口线」在两种模式下都成立（FAST 105 / 全量 104）。
- 增量之和 == 结果行（✓3493 ✗0，SKIP0），最后一条收口线在结果行之前，全日志红标 0 条。

## F1 · 合并 main 之后（2026-09-28 · PM thread 12:38Z）

**背景（PM 在合并树上实测）**：main 里新落进 4 段 —— `34b`（P66 排队守卫）· `49`（P94 零行现场）·
`50`（P95 合并基准）· `51`（P99 用法诚实性）—— 我的 `section-paths.tsv` 没有它们的行，`--check` 因此红
（PM 的合并树跑到 §36 时正是那 4 条红）。

**提交序**

| 提交 | 内容 |
|---|---|
| `be791aa8` | `git merge main`（60 个提交）。唯一冲突 = `smoke.sh` 的锁块：保留 P66 的 marker/loud-cap（不再 `exec`；没 marker + rc=1 → 点名 `<lock>.holder` + 等了多少秒 → exit 2），P98 的选段子进程在同一分支里把四个标记以命令行前缀带回去；§36 的段数 105 → 109。 |
| `2bc2a3ac` | 表补 `34b`/`49`/`50`/`51` 四行（patterns 按段内真实路径 token；`needs` 留待空段守卫）；行 33 的 `openspec/changes/change-centric-discipline/tasks.md` 随 change 归档（2026-09-23）→ 撤掉该字面模式（段内不再点名现存路径；`--check` 只把现存 token 计入覆盖）。 |
| `36437259` | 合并解里的真缺陷（见下）：标记前缀 `exec …` → `env …`；新增 §36⑤ + 独立探针 `docs/team/reports/P98-f1/`。 |
| `5638023a` | 空段守卫的实测结果：行 `49` 加 `needs: 2`。 |

**合并解里的一个真缺陷：`exec` 不认赋值前缀**

第一版把「命令行前缀」写成了 `exec SMOKE_SEL_CHILD=1 … bash <过滤副本>`。`exec` 不认 `VAR=value`
前缀 —— 锁路径上的选段必碎：`exec: SMOKE_SEL_CHILD=1: not found`，rc=127。§36 的其他嵌套跑都带
`TEAM_SMOKE_NO_LOCK=1`，覆盖不到这条组合（FAST 全绿也看不出来），是**独立探针**抓到的。改成
`env SMOKE_SEL_CHILD=1 … bash <过滤副本>` 后两个方向都对。这条组合现在有两层守卫：§36⑤（`--select 0b`
的锁路径，绿侧 + 排队超限红侧，7 条断言）与探针（同一形状，可脱离套件复跑）。

**返工后的验收（109 段口径）**

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（109 行）
ok: 段 ↔ 行一一对应（源码 109 段 / 表 109 行）
ok: needs 声明全部存在且指向更早的段（60 条）
ok: 字面模式全部存在于工作树（456 条）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（393 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 7  bad 0

$ bash skills/teamsmith/tests/routes.sh
== 结果 ==  ✓ 171  ✗ 0  SKIP 0        # rc=0，134.7s

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 17 passed, 0 failed (17 items)      # rc=0

$ bash skills/teamsmith/tests/gate-guard.sh
gate-guard: 三向都过（门禁无判定、旋钮助手在岗、性能套件带标记）    # rc=0

$ bash skills/teamsmith/tests/flip-m33.sh
== 跑 sentinel（…） ==
  rc=2 · 红行 1 条 · 哨兵点名 1 条 · 到结果行 0 · 全绿 0 · 26-k 之后仍绿 0 条
flip-m33：证据成立        # rc=0，326s（红标计数与合并前一致：只有哨兵那 1 条）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
#93 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 35.7s · ✓71 ✗0 SKIP0
账本自查： 109 段收口 · 增量 ✓2947 ✗0 SKIP33 ｜ 结果行 ✓2947 ✗0 —— 一致
== 结果 ==  ✓ 2947  ✗ 0
smoke 全绿      # rc=0，914.1s（含 §36⑤；§36 从 ✓64 增到 ✓71）
                # 最终一跑在含 `needs:2` 的 tip 上：同样 ✓2947 ✗0 SKIP33 / rc=0 / 691.1s

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 最慢 5 段 ==
  #94 38 · 设置选项（M55：…） · 286.6s · ✓22 ✗0 SKIP0
  #107 51 · 用法诚实性：… · 140.5s · ✓2 ✗0 SKIP0
  #59 12b-pi · M30 投递换道：… · 75.9s · ✓103 ✗0 SKIP0
  #58 12b-h0c · P59 输入框判据：… · 64.2s · ✓124 ✗0 SKIP0
  #73 26 · 面板（pulse-tui-panel：…） · 60.9s · ✓142 ✗0 SKIP0
账本自查： 108 段收口 · 增量 ✓3612 ✗0 SKIP0 ｜ 结果行 ✓3612 ✗0 —— 一致
== 结果 ==  ✓ 3612  ✗ 0
smoke 全绿      # rc=0，1315.5s（`14c` 只属于 FAST 分层，全量里从来不跑 → 108 条收口线）
```

**flip：锁×选段（`exec` → `env`）**

```
$ # 把 env 前缀去掉（还原第一版缺陷）
$ perl -0pi -e 's/\n          env SMOKE_SEL_CHILD=1/\n          SMOKE_SEL_CHILD=1/' skills/teamsmith/tests/smoke.sh
$ bash docs/team/reports/P98-f1/lock-select-probe.sh docs/team/reports/P98-f1/logs-pre-fix
  BAD ① 退出码 0（实际 127）
  BAD ① 选段结果 token
  BAD ① 选中的 0b 段真的跑了
  BAD ① 过滤副本确实作为持锁子进程跑了（…）
  == P98-F1 锁×选段探针 ==  ok 9  bad 4        # rc=1
  # 现场（green.log）：_: line 1: exec: SMOKE_SEL_CHILD=1: not found

$ # 还原 → 同一支探针绿
$ bash docs/team/reports/P98-f1/lock-select-probe.sh docs/team/reports/P98-f1/logs-post-fix
  ok  ① 退出码 0（实际 0）
  ok  ① 过滤副本确实作为持锁子进程跑了（SMOKE_LOCK_HELD=1 的收尾行在…）
  ok  ① 没跑没选的段（26 段头不在）
  ok  ② 退出码 2（不是 1、不静默；实际 2）
  ok  ② 一行说明排队超限并报等了多久
  ok  ② 那一行点名 holder 里的持有者
  ok  ② 子套件一段都没跑
  == P98-F1 锁×选段探针 ==  ok 13  bad 0        # rc=0
```

**空段守卫：新增 4 行的 `needs` 实测（选段 vs 全量，逐段计数）**

| 段 | 全量 | `--select 34b,49,50,51`（第一次） | 结论 |
|---|---|---|---|
| `34b` | ✓25 ✗0 | ✓25 ✗0 | `needs: -` |
| `49` | ✓22 ✗0 | ✓9 ✗13（单独跑时 `$REPO` 还没 init，`team status` 全部 rc=1） | **`needs: 2`** |
| `50` | ✓62 ✗0 | ✓62 ✗0 | `needs: -` |
| `51` | ✓2 ✗0（内层 routes 172 条 / 名册 136 条） | ✓2 ✗0（内层同为 172/136） | `needs: -` |

`49` 的红是第一次选择跑抓出来的（这正是空段守卫的用途）；加 `needs: 2` 之后 `--select 49`（闭包自动带上
2 段）→ 49 回到 ✓22 ✗0，与全量逐数一致；再跑一次 `--select 34b,49,50,51` → rc=0，四段计数全部与全量一致
（总账 ✓174 ✗0，50 段/51 段的内层计数也逐字一致）。

**范围说明**：§36⑤ 与探针是 PM 的 F1 没点名、但合并解必然新增的一条路径（P66 锁 × P98 选段）——
第一版它就是坏的，且原有夹具构造上覆盖不到。如果不想要这段守卫，单独回退 `36437259` 的 §36⑤ 即可
（探针可保留为报告证据）。

## F2 · 再合并 main：P70（gate-section-accounting）集成（2026-09-28 · PM thread 14:12Z）

**背景（PM）**：P70 在 F1 合并的 `631a7f84` 之后才落进 main。两套机制在同一处（段开闭）各自打行：
P70 是「开跑行 + `#N 用时 Ns · ticks N` 收口」（看门狗 / 硬预算 / 现场），我的是「`#N id · 秒 ·
✓P ✗F SKIPk` 收口 + 最慢 N 段 + 账本自查」（账目 / 选段）。PM 要求二选一并写明理由。

**决定：统一成一行**（不是两行并存）：

```
#N id · 用时 Ns · ✓P ✗F SKIPk · ticks T
```

理由（按两边既有断言的可证伪性）：

1. 两套机制讲的是**同一件事**（这一段结束了）。两行并存会把「一段一条收口」拆成两条互不知道的账，
   同一段还会出现两个时钟读数（P70 的 `date +%s` 与我的 `EPOCHREALTIME`）——读者不知道信哪个。
2. 统一后只有**一个时钟**：用时/ticks 由 P70 的看门狗记账，收口行与 `sections.tsv` 同源
   （`SG_ELAPSED`）；账本不再自己计时（`smoke_clock_us` / `smoke_elapsed` 删除）。
3. 证伪力没有丢，两边反而都更强：
   - P70 的 §14d 仍钉「每段一条收口、行尾是 ticks、rows=closes、starts=closes+1」，正则扩成
     `… 用时 Ns · ✓P ✗F SKIPk · ticks T$`（**增量字段也必须在**，少一个字段就红）；
   - 我的 §36 仍钉「收口行增量之和 == 结果行」「收口行不带门禁红标」「最慢段汇总」，解析器改成按
     字段取 ✓/✗/SKIP（不再假设它们一定是行尾三字段）。
4. 增量由账本侧在关段前用 `SG_CLOSE_COUNTS` 注入、由 guard 打行；没有账本的裸用法（模块自检）
   打 `-`，形状仍是同一条。stdout 与 `sections.log` **逐字节一致**（“读哪个流”不会分叉）。

**逐项（PM 的 F2 清单）**

| # | 要求 | 结果 |
|---|---|---|
| ① | `git merge main` | `fc9926e0`；唯一文本冲突 = `section()` 与尾部收尾 |
| ② | 两套机制并存、收口行统一 + 理由 | 见上。`section()` = `smoke_section_close`（账本注入增量 → guard 打唯一收口行）→ `section_guard_begin`（唯一开跑行，我原来自打的 `== id ==` 段头删掉）；尾部 = `smoke_section_close` → `section_guard_finish`（关看门狗）→ 最慢段 → 账本自查 → 结果行 |
| ③ | 受影响断言同步更新 + 红/绿原始输出 | 三处，见「形状翻转」 |
| ④ | `--check` 点名补行 | 它点名的正是 PM 预判的 `0e/0f/0g/14d`；另有 `--budget-check` 点名 §36 预算行、`--loop-check` 点名一个探针假阳性（见下） |
| ⑤ | 重跑五件套 | 见「各项门禁」 |
| ⑥ | 报告写清合并后统一/补齐 | 本节 |

**合并后才暴露的一处探针缺陷（loop-scan 假阳性）**：P70 的 `--loop-check` 在合并树上把参数循环报成
「45≠44 + 全部错位」。根因：`lib/loop-scan.awk` 数块开/闭用的是松的 `[^A-Za-z0-9_]` 前缀，于是
`--select` 里的 **select** 被算成一个 `select` 块开者 → 外层 `while [ $# -gt 0 ]` 永不关，`ext` 吞掉
上千行、还吞进一个 `sleep` → 一个假阳性的 while+sleep。修法：块计数与探测行同口径（前缀字符不许是
`-`）。红（69/70、锚点全错位、rc=1）→ 绿（69/69、rc=0），原始日志
`logs/loop-check-pre-fix.log` / `logs/loop-check-post-fix.log`；清单语义与 `cap=`/`bound=` 一字未改。

**补的映射表行与预算行**

- `section-paths.tsv` +4 行：`0e/0f/0g/14d`。`--check` 从 `bad: 源码里有段没有行：0e 0f 0g 14d`
  到 `ok 7 bad 0`（113 段 / 113 行 / 410 token 覆盖 / 471 字面模式）。
- `section-budgets.tsv` +1 行：§36（P98 自检段自己也要有上界）`band=50 / budget=200`
  （合并树 FAST 实测 49s 上取整；`ceil(50×4)=200`）。`--budget-check` 113/113。
- 空段守卫（新四行）：`--select 0e,0f,0g,14d` vs 同 tip 全量 FAST 逐段计数
  `0e 23/23 · 0f 19/19 · 0g 6/6 · 14d 7/7`（0 DIFF）→ `needs: -` 成立（日志 `logs/select-0e0f0g14d.log`）。
- 顺带加硬：P70 的段头是 `== #N id == …`，我原来的 `assert_not … "== 0 · 临时仓库 =="` 这类负例
  就永远成立了——改成 `"0 · 临时仓库"` / `"26 · 面板"` / `"0b · skill 可被 pi 解析器加载"`，两种
  段头形状都能抓住（P66 的 34b① 与 §36②③⑤ 共 6 处）。

### 形状翻转（③ 的红/绿原始输出）

`docs/team/reports/P98-f2/shape-flip-probe.sh`：变体树上只把一处断言退回旧形状，跑 FAST 选段；
三红各点名、rc=1；真树侧同口径全绿。

```
$ bash docs/team/reports/P98-f2/shape-flip-probe.sh
ok   14d-shape：§14d 的段账对账按旧收口形状解析（统一的增量字段落空 → closes=0） → 红且点名（rc=1）
ok   36-ledger-parser：§36 的账本解析按旧收口形状（收尾三字段） → 红且点名（rc=1）
ok   36-full-count：§36④ 的段数硬编码（109）对不上现在 113 段 → 红且点名（rc=1）
形状翻转探针：0 个方向不对（期望按 ① / ② / ③ 各红一次）

# ① 的红行（logs/shape-flip/14d-shape.log）：
  ✗ P70 对账：当前段已开跑、上一段已收（starts = closes + 1）（期望 [1]，实际 [8]）
  ✗ P70 对账：sections.tsv 每段一行（rows = closes）（期望 [0]，实际 [7]）
# ② 的红行（logs/shape-flip/36-ledger-parser.log）：
  ✗ 36③ 段落增量之和 == 结果行总数（✓）（期望 [21]，实际 [0]）
# ③ 的红行（logs/shape-flip/36-full-count.log）：
  ✗ 36④ FULL 兜底：运行头说全套都在跑（不是「0/113 · 没跑 113」）（… 中找不到 [运行 109/109 段]）
```

绿侧：真树 `logs/section36-f2-1.log`（§36 harness ✓71 ✗0，运行时抽取真 §36 正文）与最终 FAST
（§14d ✓7 ✗0、§36 ✓71 ✗0）。

### 各项门禁（最终 tip）

```
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 7  bad 0                              # logs/check-final.log

$ bash skills/teamsmith/tests/section-guard.sh --budget-check
section-guard --budget-check: 全过                        # 113/113 · logs/budget-check-final.log

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
section-guard --loop-check: 全过                          # 69/69 · logs/loop-check-final.log

$ bash skills/teamsmith/tests/lib/section-guard.sh --self-test
== 结果 ==  ✓ 40  ✗ 0 · section-guard 自检全绿            # logs/section-guard-selftest.log

$ bash skills/teamsmith/tests/gate-guard.sh
gate-guard: 四向都过（门禁无判定、旋钮助手在岗、性能套件带标记、时长比较只在段落守卫）

$ bash skills/teamsmith/tests/routes.sh
== 结果 ==  ✓ 171  ✗ 0  SKIP 0                            # rc=0 · 131.7s · logs/routes-f2.log

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 15 passed, 0 failed (15 items)

$ bash skills/teamsmith/tests/flip-m33.sh
  rc=2 · 红行 1 条 · 哨兵点名 1 条 · 到结果行 0 · 全绿 0 · 26-k 之后仍绿 0 条
flip-m33：证据成立        # rc=0，358.7s · 红标计数与合并前一致（只有哨兵那 1 条）· logs/flip-m33-f2.log
```

**FAST 最终 tip（113 段口径）**（`logs/fast-f2-final.log`，766.9s，rc=0，全日志红标 0 条）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null   # rc=0
账本自查： 113 段收口 · 增量 ✓3002 ✗0 SKIP33 ｜ 结果行 ✓3002 ✗0 —— 一致
== 最慢 5 段 ==
  #62 12b-pi · … · 用时 76s · ✓103 ✗0 SKIP0 · ticks 103
  #98 38 · … · 用时 60s · ✓20 ✗0 SKIP2 · ticks 22
  #96 36 · … · 用时 50s · ✓71 ✗0 SKIP0 · ticks 71
  #93 34 · … · 用时 48s · ✓27 ✗0 SKIP0 · ticks 27
  #5 0e · … · 用时 40s · ✓23 ✗0 SKIP0 · ticks 23
#112 14d · … · 用时 0s · ✓7 ✗0 SKIP0 · ticks 7
== 结果 ==  ✓ 3002  ✗ 0
smoke 全绿
```

**全量（交付时一次，同一 tip，不排队阻塞）**（`logs/full-f2.log`，1426.4s，rc=0，全日志红标 0 条）

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
账本自查： 112 段收口 · 增量 ✓3667 ✗0 SKIP0 ｜ 结果行 ✓3667 ✗0 —— 一致
== 最慢 5 段 ==
  #97 38 · … · 用时 293s · ✓22 ✗0 SKIP0 · ticks 22
  #110 51 · … · 用时 144s · ✓2 ✗0 SKIP0 · ticks 2
  #62 12b-pi · … · 用时 76s · ✓103 ✗0 SKIP0 · ticks 103
  #76 26 · … · 用时 70s · ✓142 ✗0 SKIP0 · ticks 142
  #61 12b-h0c · … · 用时 63s · ✓124 ✗0 SKIP0 · ticks 124
== 结果 ==  ✓ 3667  ✗ 0
smoke 全绿
```

- 112 段收口（不是 113）：`14c · 快模式自检` 只属于 FAST 分层，全量里从来不跑（既有条件段）；
  §95=36 用时 49s（预算 200）、§5..7 = 0e/0f/0g 40/5/1s、§111=14d ✓7 ✗0 —— 都在各自带内。
- 增量之和 == 结果行（✓3667 ✗0 SKIP0），最后一条收口线在结果行之前，全日志红标 0 条。

**合并基准**：`fc9926e0` 把 main@`5744003a`（P70 done + 两个归档）合进来了。此后 main 又落了
P108 验证记录 / P110 返工 brief / P109 brief / D54-D55 等提交——全是**纯文档**
（`git diff --name-only 5744003a..main -- 'skills/**'` 为空），本次交付的代码面与 main 无差异；
它们由 PM 合并时随带过来。P110（dev2）的 grant 会碰 `lib/section-guard.sh` 的 band 比较与
escalation 措辞；本 F2 改的是该文件的收口行打印（`_sg_close_current`）与新增的
`section_guard_close`/`SG_CLOSE_COUNTS`，不在同一段行上。

## Suggested next steps

- **verify 阶段（另一名 agent）**：按 tasks.md 5.1 在独立检出上重跑——两个决定形状与兜底、`--check` 各腐烂方向、
  选段运行的 header/token/tail、空段夹具（`17`/`15b`）、计数不变式、D33 flip、`gate-guard.sh`、`flip-m33.sh`、
  `openspec validate --all --strict` 与全量 smoke；F1 新增的两处按同一口径复核：`docs/team/reports/P98-f1/lock-select-probe.sh`
  （锁×选段两个方向）与 §36⑤，以及 `--select 34b,49,50,51` vs 全量的逐段计数表。
  **F2 追加**：① 收口行现在是**一条**统一行 `#N id · 用时 Ns · ✓P ✗F SKIPk · ticks T`——按这个形状复核
  §14d 与 §36 的解析，不要按 F1 的两条形状/旧 `用时 Ns · ticks` 形状去断言；② P70 的 `0e/0f/0g/14d`
  现在有行（`--check` 与 `--budget-check` 都该是 113/113），`lib/loop-scan.awk` 的块计数与命令位同口径；
  ③ 复跑 `docs/team/reports/P98-f2/shape-flip-probe.sh`（三红各点名）与 `docs/team/reports/P98-f2/section36-harness.sh`（✓71 ✗0）；
  ④ 若导出变体树跑长路径 TMPDIR（≥ ~110 字节的嵌套 socket 路径）会撞 Unix socket 上限、把 0c 的隔离断言染红
  ——那是路径长度的探针伪红（F2 的探针已用短路径绕开），不是被测行为。
- **PM**：勾 tasks.md、复验、合并（本地模式）。若复验要新增变体跑法，先读 Decisions 第 5 条。
- **已知余量**：`--paths` 目前做过计数对比的是 outbox（38 段）、`--select 17`（10 段）与 F1/F2 新增的 8 段
  （`34b/49/50/51` 与 `0e/0f/0g/14d`）；其他行的 `needs` 是按同一条判据（空段守卫）声明的，但没有逐条跑过对比表。
