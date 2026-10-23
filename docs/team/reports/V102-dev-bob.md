# V102 · 独立复验 `turn-notice-in-pm-inbox` 的 5.1–5.4

agent: dev-bob · phase: verify · category: verify · change: `turn-notice-in-pm-inbox` · deltas: `-`
anchor: none (infra) — change 自带 delta · branch: `task/V102-turn-notice-verify` · time: 2026-10-23T09:55:01Z · 交付

## 结论（先回答任务书）

- **判定 PASS**，四条复验项都做到了，读数在 `docs/team/reviews/turn-notice-in-pm-inbox.md`：
  5.1 定点选段 `--select 7,13,25` 在我自己的副本上 `✓ 245  ✗ 0`（退出码 0，无「本次运行无效」）；5.2 两条反向对照
  （R4、R6）都**真红**、还原后同一选段**再绿**；5.3 五条自洽检查全绿。
- **清单条目一条都没勾**（按 brief：勾选是 PM 的动作）。`tasks.md §5` 四条 `[ ]` 原样留着。
- **顺手补上了 P371 报的缺口**：`docs/team/reviews/turn-notice-in-pm-inbox.md` 之前不在盘上（P371 报告 §结论第 4 条），
  P371 建议「归档前要么补那份合并记录，要么裁定两份采纳记录即 5.4」。这次 5.4 的产物就是它，缺口自然闭合。
- **一处越出 brief 字面的花费，主动报**：`tasks.md` 5.3 除了 brief 列的四个命令，还点名「§25 手工通知计数、§12f 段头
  字面量、§13 扩展字节断言、§51 内部命令白名单」没有回归。§25 与 §13 已由 5.1 的选段覆盖，我另跑了 `--select 12f,51`，
  `✓ 55  ✗ 0`。它花了 **1488s**——其中 §51 一段 1255s（它内部自己嵌套选 §33，内层 `✓ 331  ✗ 0`）。这比本 change 的断言面
  贵两个数量级，值不值由你判；我把它单列成一条证据，没有把它塞进「改动点到的子集」。

写集：只写 `docs/team/reviews/turn-notice-in-pm-inbox.md` 与这份报告。产品代码、`tests/**`、清单文件、别的目录一字节没动。

## 1 · 5.1 定点执行（不是查表）

私有副本 `git clone --shared -b task/V102-turn-notice-verify <repo> /var/tmp/v102-priv`，HEAD `42d71db8`
（与我的 worktree 同一提交，`git status --porcelain --untracked-files=all` 空）。破坏只在这一份副本里做，
还原用 `git checkout -- .`，两次还原后脏文件数都是 0。

```
$ cd /var/tmp/v102-priv && bash skills/teamsmith/tests/smoke.sh --select 7,13,25     # exit 0，181s
== 选段 == decision=RUN · 运行 9/135 段 · 未跑 126 段
#7 7 · notify / inbox / digest · 参考 用时 101s · ✓113 ✗0 SKIP0
#8 13 · notify 扩展（去重 + 只在 worktree 触发） · 参考 用时 6s · ✓1 ✗0 SKIP0
#9 25 · 唤醒计数 = digest 的可行动列表（M9.8） · 参考 用时 62s · ✓65 ✗0 SKIP0
账本自查： 9 段收口 · 增量 ✓245 ✗0 SKIP0 ｜ 结果行 ✓245 ✗0 —— 一致
== 选段结果 ==  ✓ 245  ✗ 0
```

`needs` 带进来的是 `0 0b 0c 0d 2 5`（各 ✓3/3/9/9/39/3，✗0），所以九段全部收口。
负向读数：`grep -c 本次运行无效` = 0 —— 副本在跑动中没被改动，这一轮的 ✓ 不作废。

新增断言原文（逐条抄自源码，不是概括）：

- 指针行三条 —— `smoke.sh:5107` 等号断言 `指针行形状（字段顺序写死：身份 · 任务 · knock · see · 修订戳）`；
  `smoke.sh:5117` 等号断言 `指针行与记录行同一个合并键（缺 task= 戳就退化成两条）`；
  `smoke.sh:5104` 字节断言 `R2 指针是旁路：记录行逐字节不变（指针开/关同一结果）`。
- A2 账行与 digest 两行 —— `smoke.sh:5221` `P365：enqueued 的账行字段顺序与行身份（…）`（正则
  `^- [0-9T:.-]+Z seat=dev · task=P362 · class=delivered · outcome=enqueued · pointer=ok · identity=line|`）；
  `smoke.sh:5239` `P365：未敲门按类分组（闭集外的类显示成 其它（原样））`；
  `smoke.sh:5255` `P365：两行各自独立（指针失败不改「未敲门」的读数）`；同段 `smoke.sh:5254` 的
  `指针缺失 1 条通知没有写进 PM 收件箱（pointer-write-failed；state/notify-knock.log 当前代，更早的代不计）`。

## 2 · Flip evidence（红 → 还原 → 绿）

### R4 · 合并取**新事件**的 `knock=`

```
--- a/skills/teamsmith/scripts/lib/cmd-agents.sh
+++ b/skills/teamsmith/scripts/lib/cmd-agents.sh
@@ -1823,7 +1823,7 @@ team_notify_line_merge() {
   if [ -n "$prev" ]; then
-    pk="$(team_notify_knock_of "$prev")"
+    pk=""   # MUTANT(R4)：合并取新事件的 knock=
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 7,13b          # exit 1
✗ R4 knock= 是 run 级字段：扩展事件不改写首事件的 enqueued（期望 [knock=enqueued]，实际 [knock=skipped:merged]）
FAIL: R4：扩展事件把 run 级 knock= 改写成了 skipped:merged（… knock=skipped:merged · see=docs/team/inbox/dev.md · ×2 first=… last=…）
✗ M4.3 E 扩展测试失败（runner=node）
✗ P365：未敲门按类分组（闭集外的类显示成 其它（原样））
✗ P365：两行各自独立（指针失败不改「未敲门」的读数）
#6 7 · notify / inbox / digest · ✓110 ✗3      #7 13b · … · ✓1 ✗5
== 选段结果 ==  ✓ 174  ✗ 8
$ git checkout -- . && git status --porcelain | wc -l     # 0
$ bash skills/teamsmith/tests/smoke.sh --select 7,13b          # exit 0
== 选段结果 ==  ✓ 182  ✗ 0
```

两处 `P365` 连带红不是噪声：`未敲门` 数的就是 PM 收件箱里**尚未 ack 的指针行的 `knock=skipped:<类>`**
（`scripts/lib/cmd-status.sh:81` 的注释把口径写死），被改写成 `skipped:merged` 的那一行从「已敲门」跳到「未敲门」，
读数从 3 变 4。也就是说 R4 的破坏同时被 §13b 的字节断言与 digest 的读侧咬住。

### R6 · 删掉记录判据

```
--- a/skills/teamsmith/scripts/lib/cmd-status.sh
+++ b/skills/teamsmith/scripts/lib/cmd-status.sh
@@ -41,7 +41,7 @@ team_inbox_line_is_record() {
-  [ "$ag" = "$seat" ]
+  [ "$ag" = "$seat" ] && return 1   # MUTANT(R6)：判据失效
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 7              # exit 1
✗ R6：席位自己的 auto 记录不算它自己的未读流量（期望 [0]，实际 [1]）
✗ R6：待办里的未读通知 = 1（不是 2）（[未读通知 2] 里找不到 [未读通知 1]）
✗ R6：待办没有把同一次交付数两遍（不该出现 [未读通知 2]）
✗ 发现可能让调用方在 set -e 下静默退出的函数：            （§0c 静态检查）
#3 0c · 静态检查（函数结尾的 set -e 陷阱） · ✓8 ✗1     #6 7 · … · ✓110 ✗3
== 选段结果 ==  ✓ 172  ✗ 4
$ git checkout -- . && git status --porcelain | wc -l     # 0（还原后 --select 7,13b = ✓ 182 ✗ 0，见 R4 末行）
```

四条红里有一条是**我自己写下的变异形状**被 §0c 抓住（`&& return 1` 落在函数最后一条语句上），不是「一份计数」
的第二道行为控制。区分这一点有用：以后有人删掉那三条 R6 断言而留下静态检查，读数仍会绿。

## 3 · 5.3 自洽检查（`42d71db8` 的检出上，只读）

```
$ ~/.bun/bin/openspec validate --all --strict          # 1.8.0；openspec 不在 PATH 上
Totals: 23 passed, 0 failed (23 items)                 # exit 0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 121 reference(s) (49 distinct) in 13209 effective line(s);
           retired 2; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]      # exit 0
$ bash skills/teamsmith/tests/spec-refs.sh --flips
guard reverse-guard    openspec/specs + docs/team/inbox unchanged (ccf2146f1ef1)
spec-refs: --flips OK（19 用例如预期，0 个不符；break=none）                                # exit 0，4.6s
$ bash skills/teamsmith/tests/ledger-ban.sh
ledger-ban: scope=published files=2149 hits=0 names=ok user=resolved                     # exit 0
$ git diff --check ; echo $?                                   # 0
$ git show --check --oneline e035c57e ; git show --check --oneline d9e219b2   # 两条都无空白告警
```

`--check` 的两条 `retired` 是 pending change `behavior-focused-ci` 退场的既有引用（`openspec/specs/verification/spec.md:371`
的 `docs/team/reviews/<ID>.md`、`:398` 的 `docs/team/PUBLISH.md`），判据是 `undeclared 0`，不是这两行。

## 4 · 未测项（不是「都验过了」）

- **没跑整套**：§61b 变异矩阵、§36 嵌套、面板段等 126 个键没跑。本 change 的断言落点（§7/§13/§13b/§25）都在上面，
  但整套只能由 PM 在归档前跑一次；这份记录不代替它。
- **R1/R2/R3/R5/R7–R12 没重复做**（brief 只允许两条）：它们的红侧在案于 apply 阶段与 V96/V98/V99 的采纳记录，
  不在本轮。按 P371 的账，其中 R1/R3/R5/R7/R12 到今天仍**没有一次「破坏 → 红」的实测**——这是已知缺口，不是本次新发现。
- **5.1 证明的是「HEAD 上绿」**，不证明这些断言是唯一控制（R6 那节就是反例）。唯一覆盖要逐条变异，不在本复验分工里。
- 沿用 V98 的未验项：扩展 `suspended` 分支的 `identity=` 只有静态证据，没有行为级断言。
- 副本的门禁锁记录把席位写成 `agent=pm worktree=/var/tmp/v102-priv`（「`.worktrees/<名>` → 该名，其余按主检出记 pm」），
  与真实席位的记录不同构。这是记录口径，本报告不据此判任何事。

## 5 · 交付

- 提交：`b9e0852f`（复验记录）+ 本报告。分支 `task/V102-turn-notice-verify`，本地模式，不推送、不合并。
- 复验记录：`docs/team/reviews/turn-notice-in-pm-inbox.md`（判定 PASS；命令、输出尾部、未测项都在里面）。
- 待 PM：勾 `tasks.md §5` 的四条、`openspec archive`（需用户确认），以及是否接受 §51 那 1255s 的花费。
