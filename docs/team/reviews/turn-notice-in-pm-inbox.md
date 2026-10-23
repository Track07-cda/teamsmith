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
