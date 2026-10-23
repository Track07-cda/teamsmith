# turn-notice-in-pm-inbox · 独立复验记录（V102）

- 判定: **PASS**
- task: V102 · reviewer: dev-bob（非 A1/A2 作者）· PM: pm
- 受检: `42d71db8`（分支 `task/V102-turn-notice-verify`；A1 `e035c57e`、A2 `d9e219b2` 已在 main）
- 复验面: 只做 `openspec/changes/turn-notice-in-pm-inbox/tasks.md` §5 的 5.1–5.4。清单条目**没有勾**，交 PM。

## 0 · 做法与现场

- 私有副本：`git clone --shared -b task/V102-turn-notice-verify <repo> /var/tmp/v102-priv`，
  HEAD `42d71db8`（与我的 worktree 同一个提交），`git status --porcelain --untracked-files=all` 为空。
  三次选段与两条变异都在这一份副本里，破坏用 `git checkout -- .` 还原，两次还原后脏文件数都是 0。
- 全量日志：`/var/tmp/v102-logs/{baseline,r4,r6,r4-restored,regress-12f51}.log`（容器内路径，随容器生命周期；
  报告里的每一条读数都是这些文件的 `grep` 原文）。`--select` 只跑改动点到的段，整套留给 PM 在归档前跑。
- 副本里门禁锁记录把席位写成 `agent=pm worktree=/var/tmp/v102-priv`：解析规则是「`.worktrees/<名>` → 该名，
  其余按主检出记 pm」，与真实席位的记录不同构。这是记录口径，不影响本节任何读数。

## 1 · 5.1 定点执行 `--select 7,13,25`（自己的副本，不复用 apply 的日志）

```
$ cd /var/tmp/v102-priv && bash skills/teamsmith/tests/smoke.sh --select 7,13,25   # exit 0，用时 181s
== 选段 == decision=RUN · 运行 9/135 段 · 未跑 126 段
```

九段（除 7/13/25 外是 `needs` 带进来的 0/0b/0c/0d/2/5）：

| key | 段 | ✓ | ✗ | 用时 |
|---|---|---|---|---|
| 0 | 临时仓库 | 3 | 0 | 0s |
| 0b | skill 可被 pi 解析器加载 | 3 | 0 | 0s |
| 0c | 静态检查（函数结尾的 set -e 陷阱） | 9 | 0 | 0s |
| 0d | 冲突标记守卫 | 9 | 0 | 1s |
| 2 | init | 39 | 0 | 1s |
| 5 | add-agent | 3 | 0 | 0s |
| **7** | notify / inbox / digest | **113** | **0** | 101s |
| **13** | notify 扩展（去重 + 只在 worktree 触发） | **1** | **0** | 6s |
| **25** | 唤醒计数 = digest 的可行动列表 | **65** | **0** | 62s |

```
账本自查： 9 段收口 · 增量 ✓245 ✗0 SKIP0 ｜ 结果行 ✓245 ✗0 —— 一致
== 选段结果 ==  ✓ 245  ✗ 0
```

运行指纹：输出里没有「本次运行无效」行（`grep -c` = 0），退出码 0 —— 副本在跑动中未被改动。

### 新增断言的原文

A1 指针行三条（`skills/teamsmith/tests/smoke.sh`）：

- `smoke.sh:5107` 等号断言 —— `指针行形状（字段顺序写死：身份 · 任务 · knock · see · 修订戳）`，
  期望行 `- 2026-10-22T05:42:38.123Z [auto] agent:dev · P362 · knock=enqueued · see=docs/team/inbox/dev.md · task=P362 tip=1a2b3c4d5e6f`
- `smoke.sh:5117` 等号断言 —— `指针行与记录行同一个合并键（缺 task= 戳就退化成两条）`（两侧都是 `team_notify_line_key` 的输出）
- `smoke.sh:5104` 字节断言 —— `R2 指针是旁路：记录行逐字节不变（指针开/关同一结果）`（`cmp` 前后）

A2 的账行与 digest 两行：

- `smoke.sh:5221` 正则断言 —— `P365：enqueued 的账行字段顺序与行身份（ISO · seat · task · class · outcome · pointer · identity）`，
  模式 `^- [0-9T:.-]+Z seat=dev · task=P362 · class=delivered · outcome=enqueued · pointer=ok · identity=line|`
- `smoke.sh:5239` —— `P365：未敲门按类分组（闭集外的类显示成 其它（原样））`，
  期望原文 `未敲门 3 条已记录的通知没有叫醒 PM（suspended 1 · notify-off 1 · 其它（something-new 1））`
- `smoke.sh:5255` —— `P365：两行各自独立（指针失败不改「未敲门」的读数）`（期望 `未敲门 3 条已记录的通知没有叫醒 PM`）；
  同一段里 `smoke.sh:5254` 的 `P365：指针缺失从账本当前代读出并点名文件` 断言的是
  `指针缺失 1 条通知没有写进 PM 收件箱（pointer-write-failed；state/notify-knock.log 当前代，更早的代不计）`

## 2 · 5.2 反向对照（只做 brief 点名的两条）

### R4 · 合并取新事件的 `knock=`

```
--- a/skills/teamsmith/scripts/lib/cmd-agents.sh
+++ b/skills/teamsmith/scripts/lib/cmd-agents.sh
@@ -1823,7 +1823,7 @@ team_notify_line_merge() {
   if [ -n "$prev" ]; then
-    pk="$(team_notify_knock_of "$prev")"
+    pk=""   # MUTANT(R4)：合并取新事件的 knock=
```

`bash skills/teamsmith/tests/smoke.sh --select 7,13b` → **exit 1**，`== 选段结果 ==  ✓ 174  ✗ 8`：

```
✗ R4 knock= 是 run 级字段：扩展事件不改写首事件的 enqueued（期望 [knock=enqueued]，实际 [knock=skipped:merged]）
✗ M4.3 E 扩展测试失败（runner=node）
FAIL: R4：扩展事件把 run 级 knock= 改写成了 skipped:merged（- 2026-10-23T09:26:31.246Z [auto] agent:dev · unknown · knock=skipped:merged · see=docs/team/inbox/dev.md · ×2 first=… last=…）
✗ E2：同回合压缩但已完成 → 照常通知（不过度抑制）（…ext-e.log 中找不到 [E2 压缩过但已完成：一行 + 敲门（对照组）]）
✗ P365：未敲门按类分组（闭集外的类显示成 其它（原样））（…p365-digest1.log 中找不到 [未敲门 3 条已记录的通知没有叫醒 PM（suspended 1 · notify-off 1 · 其它（something-new 1））]）
✗ P365：两行各自独立（指针失败不改「未敲门」的读数）（…p365-digest2.log 中找不到 [未敲门 3 条已记录的通知没有叫醒 PM]）
#6 7 · notify / inbox / digest · ✓110 ✗3
#7 13b · 通知只代表「回合结束」 · ✓1 ✗5
```

两处连带红不是噪声，是同一个机制：`未敲门` 数的就是 PM 收件箱里**尚未 ack 的指针行的 `knock=skipped:<类>`**
（`scripts/lib/cmd-status.sh:81`），被改写成 `skipped:merged` 的那行从「已敲门」跳到「未敲门」，读数从 3 变 4。
即：R4 不只是 §13b 的字节断言在承重，digest 的读数也在承重。

还原（`git checkout -- .`，脏文件数 0）后同一选段 `--select 7,13b` → **exit 0**，`== 选段结果 ==  ✓ 182  ✗ 0`
（`账本自查： 7 段收口 · 增量 ✓182 ✗0 SKIP0 ｜ 结果行 ✓182 ✗0 —— 一致`）。

### R6 · 删记录判据

```
--- a/skills/teamsmith/scripts/lib/cmd-status.sh
+++ b/skills/teamsmith/scripts/lib/cmd-status.sh
@@ -41,7 +41,7 @@ team_inbox_line_is_record() {
   ag="${body#*agent:}"; ag="${ag%% *}"
-  [ "$ag" = "$seat" ]
+  [ "$ag" = "$seat" ] && return 1   # MUTANT(R6)：判据失效
```

`bash skills/teamsmith/tests/smoke.sh --select 7` → **exit 1**，`== 选段结果 ==  ✓ 172  ✗ 4`：

```
✗ 发现可能让调用方在 set -e 下静默退出的函数：            （0c 静态检查，被这次变异的形状本身抓住）
✗ R6：席位自己的 auto 记录不算它自己的未读流量（期望 [0]，实际 [1]）
✗ R6：待办里的未读通知 = 1（不是 2）（[未读通知 2] 里找不到 [未读通知 1]）
✗ R6：待办没有把同一次交付数两遍（不该出现 [未读通知 2]）
#3 0c · 静态检查（函数结尾的 set -e 陷阱） · ✓8 ✗1
#6 7 · notify / inbox / digest · ✓110 ✗3
```

四条红的构成要说清：三条是 R6 的行为断言，第四条是 `§0c` 的静态检查 —— 变异把函数的最后一条语句变成
`&& return 1`，正是 `set -e` 陷阱的形状。这不是「R6 有两条独立的控制」：静态检查抓的是**我写下的形状**，
不是「一份计数」这个行为；行为层的控制仍然是那三条等号/包含断言。
还原后（脏文件数 0）`--select 7,13b` 已在上节复核为 ✓182 ✗0。

## 3 · 5.3 账本与规格自洽

在 `42d71db8` 的检出上（我的 worktree，只读）：

```
$ ~/.bun/bin/openspec validate --all --strict        # openspec 不在 PATH 上，用包内安装的 1.8.0
✓ change/turn-notice-in-pm-inbox
Totals: 23 passed, 0 failed (23 items)               # exit 0

$ bash skills/teamsmith/tests/spec-refs.sh --check
retired openspec/specs/verification/spec.md:371 docs/team/reviews/<ID>.md by behavior-focused-ci
retired openspec/specs/verification/spec.md:398 docs/team/PUBLISH.md by behavior-focused-ci
spec-refs: judged 121 reference(s) (49 distinct) in 13209 effective line(s); retired 2; undeclared 0;
           id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]      # exit 0

$ bash skills/teamsmith/tests/spec-refs.sh --flips
guard reverse-guard    openspec/specs + docs/team/inbox unchanged (ccf2146f1ef1)
spec-refs: --flips OK（19 用例如预期，0 个不符；break=none）        # exit 0，4.6s

$ bash skills/teamsmith/tests/ledger-ban.sh
ledger-ban: root=<worktree> scope=published files=2149 hits=0 names=ok user=resolved   # exit 0

$ git diff --check ; echo $?                                        # 0（工作树干净）
$ git show --check --oneline e035c57e ; git show --check --oneline d9e219b2   # 两条都无空白告警
```

`--check` 的两条 `retired` 是 pending change `behavior-focused-ci` 退场的既有引用，不是本次引入的遗漏；
`undeclared 0` 才是这条检查的判据。

`tasks.md` 5.3 额外点名的两处回归（本 change 的写集之外，但断言落在同一批文件上）：

```
$ cd /var/tmp/v102-priv && bash skills/teamsmith/tests/smoke.sh --select 12f,51   # exit 0，用时 1488s
#5 33 · 项目契约的读写面 · 参考 用时 196s · ✓1 ✗0      （§51 内部自己嵌套选段，内层 `== 结果 == ✓ 331 ✗ 0`）
#6 12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token） · 用时 24s · ✓27 ✗0
#7 51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99） · 用时 1255s · ✓3 ✗0
账本自查： 7 段收口 · 增量 ✓55 ✗0 SKIP0 ｜ 结果行 ✓55 ✗0 —— 一致
== 选段结果 ==  ✓ 55  ✗ 0
```

（§51 实测 1255s，是这一批里最贵的一段；它比本 change 的断言面贵两个数量级，不作为复验的常规手段。）

## 4 · 未测项与边界

- **没有跑整套**：本 change 的断言落点（§7 / §13 / §13b / §25）都在上面跑过，但 `§61b` 变异矩阵、`§36` 嵌套、
  面板段等 126 个键没跑。整套只能由 PM 在归档前跑一次；本记录不代替它。
- **R1/R2/R3/R5/R7–R12 没有重复**：brief 只允许两条。其余在案的只有 R2/R4/R6/R9/R10/R11 与 R8 的一半（apply 阶段 §3 表 +
  V96/V98/V99）；按 P371 的账，**R1、R3、R5、R7、R12 到今天仍没有一次「破坏 → 红」的实测**——这是已知缺口，本轮没有补。
- **5.1 证明的是「HEAD 上绿」，不是「这些断言是唯一控制」**。R6 那一节就是反例：一条破坏同时被静态检查抓住。
  唯一覆盖的判据要看逐条变异，不在本复验的分工里。
- 沿用 V98 的已知未验项：扩展 `suspended` 分支的 `identity=` 只有静态证据，没有行为级断言。
- 本记录**不做归档**，也不改任何清单条目：`openspec archive` 与勾选是 PM 在用户确认后的动作。

## 定点补验（V104）

- 判定: **PASS**
- task: V104 · 席位 dev-bob · phase verify · 受检 `074722c4`
- 补的是什么：V99 的结论仍成立，本单只补『同席位』这个纪律缺口 —— V99 的执行席位 `dev` 后来做了本
  change 的 `P373`，同一席位在同一 change 里既实现又复验；不重开 V99 验过的东西（它验的是 P368 的夹具
  契约，与 P373 的红侧是两件事）。

现场：私有副本 `/var/tmp/v104/priv`（`git clone --shared -b task/V104-p368-spot`，HEAD `074722c4`，两轮
运行前后 `git status --porcelain --untracked-files=all` 都是 0 个文件）；夹具仓库 `/var/tmp/v104/fix`
（先剥掉调用者的 `TEAM_*` 与 `TMUX*` 再跑 CLI，`team paths` 解析出 `main_root=/var/tmp/v104/fix` 之后才
造现场）；日志 `/var/tmp/v104/logs/`。没有跑整套，没有跑容器。

### 1 · P368 的核心主张在本提交上再成立一次

```
$ cd /var/tmp/v104/priv && bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail
bg-ledger：23 passed, 0 failed                        # exit 0，16.7s
```

构成：`merge` 组 13 条、`detail` 组 7 条、夹具自证 3 条（`team paths` 指向夹具仓库、真项目 `state/` 与
`inbox` 零夹具标记 + 前后快照一致）。P368 的验收记录写的是 22 passed，我这里 23 —— 差的这一条是 P368
合入之后才有的用例，两处数字不一致仅登记备查，「绿」这个结论不受影响。

### 2 · 从 §13c 的子集里去掉 merge/detail：可见地红，并且点名

变异只有一行（`skills/teamsmith/tests/smoke.sh:8362`，只发生在私有副本里）：

```diff
-  bash "$SKILL_DIR/tests/bg-ledger.sh" --select wording,ledger,suspend-shape,owner-scope,merge,detail >"$TMP/p236-owner.log" 2>&1 || P236_RC=$?
+  bash "$SKILL_DIR/tests/bg-ledger.sh" --select wording,ledger,suspend-shape,owner-scope >"$TMP/p236-owner.log" 2>&1 || P236_RC=$?
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 13c                     # exit 1
  ✗ P251 合并行在行计数读者里只算一行（merge 组折进 13c）（…/p236-owner.plain.log 中找不到 [✓ merge: line-counting readers count a merged line once]）
  ✗ P251 明细读面只读不 ack（detail 组折进 13c）（…/p236-owner.plain.log 中找不到 [✓ detail: detail reading does not acknowledge]）
#12 13c · 团队后台车道（M27/M30）：拉起链注入 / 收割契约 / 账本 / worktree 侧 · 参考 用时 32s · ✓65 ✗2 SKIP0 · ticks 67
账本自查： 12 段收口 · 增量 ✓461 ✗2 SKIP0 ｜ 结果行 ✓461 ✗2 —— 一致
== 选段结果 ==  ✓ 461  ✗ 2
```

两处要读的细节：

- 红的形状是**按用例名的两条 ✗ 并点名缺的组与那条用例原文**，不是「入口 rc 变了」——入口自己的
  `P236_RC` 仍是 0（被删掉的是子集，不是入口），这两条按名断言就是唯一把它抓住的东西，也正是 P368
  补的那道控制。删两个键，全绿段里只有这两条变红（整轮 12 段只有这 2 条 ✗）。
- 计数对照：受检树上段内是 `✓67`，变异后 `✓65` —— 少的正是这两条，没有别的断言被牵连。

还原与绿侧：`cp -p` 备份回原地，`cmp` 逐字节相同，`git status --porcelain --untracked-files=all | wc -l`
= 0，再跑：

```
$ bash skills/teamsmith/tests/smoke.sh --select 13c                     # exit 0
  ✓ P236/P237 车道合同入口：wording+ledger+suspend-shape+owner-scope+merge+detail 全绿（56 条断言）
  ✓ P251 合并行在行计数读者里只算一行（merge 组折进 13c）
  ✓ P251 明细读面只读不 ack（detail 组折进 13c）
#12 13c · 团队后台车道（M27/M30）：拉起链注入 / 收割契约 / 账本 / worktree 侧 · 参考 用时 46s · ✓67 ✗0 SKIP0 · ticks 67
== 选段结果 ==  ✓ 463  ✗ 0
```

两轮输出里「本次运行无效」都是 0 次：破坏与还原都发生在两次运行**之间**，没有打断任何一轮的运行指纹。

### 3 · A1 计数契约的两个读数（造现场，逐档读）

夹具 `docs/team/inbox/` 两个文件，三档现场，读数取自 `team digest` 的 `[2] 待处理通知`、`team inbox
<席>` 与 `team inbox --all`：

| 现场 | 文件里有什么 | `dev` 未读 | `pm` 未读 |
|---|---|---|---|
| ① | `dev.md` 只有 1 行 `[auto] agent:dev` 记录行 | **0**（`[2]` 打印「（无）」；`team inbox dev` 无输出；`--all` 里那行在，文件确为 1 行） | 0 |
| ② | 再加 1 行 `pm.md` 指针行 `[auto] agent:dev · P368 · knock=enqueued · see=docs/team/inbox/dev.md · task=P368 tip=38ee09b73abc` | **0** | **1**（`pm（PM 自己的收件箱） · 1 条新`） |
| ③ | 再加 1 行 `dev.md` 的 `[manual] agent:pm`（对照：流量行） | **1**（只列出 manual 那条，记录行仍不计数） | 1 |

即：`[auto] agent:<本席>` 的记录行不让该席位未读 +1，而 `pm.md` 里的指针行（`agent:` 是发送者）让它 +1。

### 4 · 边界

- V99 的结论仍成立，本单只补『同席位』这个纪律缺口，没有重开它验过或没验过的东西（整套、容器、其余
  R 项都不在本单）。
- `--select 13c` 带进来 12 段（0/0b/0c/0d/2/4/5/3b/6/6f/6i/13c），其余 123 个键没跑；本记录不代替归档前
  的那一次整套。
- 门禁锁排队：第一轮运行时机器级门禁锁由 verify 席位的整套运行持有（`/tmp/.teamsmith-smoke.lock.machine.holder`：
  `pid=1292624 kind=top agent=verify bound=4500`），本单把「破坏 → 跑 → 还原 → 再跑」串成一条链式作业，
  只吃一次排队（整条作业 771.9s，其中两段自报 32s / 46s）。
