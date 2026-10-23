# V104 · 定点补验：`turn-notice` 里「同席位既实现又复验」那一笔

agent: dev-bob · branch `task/V104-p368-spot` · phase verify · change: `turn-notice-in-pm-inbox` ·
anchor: none (infra) — 定点补验 · 受检 `074722c4` · time: 2026-10-23T10:30Z

**判定：PASS** —— 任务书三件全部落地：①P368 的核心主张在本提交上复现（`bg-ledger --select merge,detail`
23 passed / 0 failed）；②把 `merge`/`detail` 从 §13c 的子集里去掉，`--select 13c` **可见地红并点名**
（`✓461 ✗2`，两条按用例名断言各自点名缺的组），逐字节还原后 `✓463 ✗0`；③A1 计数契约的三档现场读数
（记录行不 +1 / 指针行 +1 / manual 行 +1）。补验记录已追加在
`docs/team/reviews/turn-notice-in-pm-inbox.md` 的 `## 定点补验（V104）` 一节。

V99 的结论仍成立，本单只补『同席位』这个纪律缺口：V99 的执行席位 `dev` 后来做了本 change 的 `P373`，
同一席位在同一 change 里既实现又复验。P373 的红侧与 P368 的夹具契约是两件事，本单不重开 V99 的判定。

## 0 · 现场与做法

- 私有副本：`git clone --shared -b task/V104-p368-spot <主检出> /var/tmp/v104/priv`，HEAD `074722c4`；
  两轮运行前后 `git status --porcelain --untracked-files=all` 都是 0 个文件，`git log --oneline -1` 仍是 `074722c4`。
- 破坏前先取备份：`cp skills/teamsmith/tests/smoke.sh /var/tmp/v104/smoke.sh.orig`；还原用 `cp -p` + `cmp` 逐字节比对。
- 计数契约的现场在 `/var/tmp/v104/fix`（一个独立 `git init` 的夹具仓库，`.pi/team/config.sh` 只写
  `TEAM_PROJECT/TEAM_AGENTS/TEAM_WORKTREES_DIR`）。跑 CLI 前把调用者的 `TEAM_*` 与 `TMUX*` 全部剥掉
  （`/var/tmp/v104/fixrun.sh`），并先确认 `team paths` 解析出 `main_root=/var/tmp/v104/fix` 再写盘：

```
$ /var/tmp/v104/fixrun.sh paths
{ "project": "v104-fixture", "main_root": "/var/tmp/v104/fix", "worktree": "/var/tmp/v104/fix", …
```

- 日志：`/var/tmp/v104/logs/{bgledger-merge-detail,mutant-13c,restored-13c}.log`（宿主路径，不是容器内 `/tmp`；
  下面每条读数都是这三个文件的原文）。没有跑整套，没有跑容器。

## 1 · P368 的核心主张（复现）

```
$ cd /var/tmp/v104/priv && bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail
  … （merge 组、detail 组、夹具自证逐条 ✓）
  ✓ 真项目 state/ 与 inbox 里没有夹具标记（bgl563981）
  ✓ 真项目 state/ 与 inbox 的快照前后一致

bg-ledger：23 passed, 0 failed
rc=0                                              # 16.7s
```

构成：`merge` 13 条、`detail` 7 条、夹具自证 3 条 = 23。P368 的验收记录写 22 passed，本提交上 23 ——
多出的一条是 P368 合入之后才有的用例；两处数字不一致，登记备查，不改变「绿」这个结论。

## 2 · 翻转证据：去掉 §13c 子集里的 merge/detail

### 2.1 红侧（破坏实现 → 门禁必须红，而且要点名）

变异只有一行（私有副本的 `skills/teamsmith/tests/smoke.sh:8362`）：

```diff
--- /var/tmp/v104/smoke.sh.orig	2026-10-23 09:58:56
+++ skills/teamsmith/tests/smoke.sh	2026-10-23 10:05:36
@@ -8359,7 +8359,7 @@
   P236_RC=0
-  bash "$SKILL_DIR/tests/bg-ledger.sh" --select wording,ledger,suspend-shape,owner-scope,merge,detail >"$TMP/p236-owner.log" 2>&1 || P236_RC=$?
+  bash "$SKILL_DIR/tests/bg-ledger.sh" --select wording,ledger,suspend-shape,owner-scope >"$TMP/p236-owner.log" 2>&1 || P236_RC=$?
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 13c
  ✗ P251 合并行在行计数读者里只算一行（merge 组折进 13c）（/var/tmp/teamsmith-priv-…/p236-owner.plain.log 中找不到 [✓ merge: line-counting readers count a merged line once]）
  ✗ P251 明细读面只读不 ack（detail 组折进 13c）（/var/tmp/teamsmith-priv-…/p236-owner.plain.log 中找不到 [✓ detail: detail reading does not acknowledge]）
#12 13c · 团队后台车道（M27/M30）：拉起链注入 / 收割契约 / 账本 / worktree 侧 · 参考 用时 32s · ✓65 ✗2 SKIP0 · ticks 67
账本自查： 12 段收口 · 增量 ✓461 ✗2 SKIP0 ｜ 结果行 ✓461 ✗2 —— 一致
== 选段结果 ==  ✓ 461  ✗ 2
rc=1
```

两处要读的细节：

- 红的形状是**按用例名的两条 ✗ 并点名缺的组与那条用例原文**；入口自己的 `P236_RC` 仍是 0（被删的是子集，
  不是入口），所以这两条按名断言是唯一抓住它的控制 —— 正是 P368 补的那道门。整轮 12 段里只有这 2 条 ✗。
- 计数对照：受检树 `✓67` → 变异后 `✓65`，少的正好是这两条，没有别的断言被牵连。

### 2.2 绿侧（还原 → 必须绿）

```
$ cp -p /var/tmp/v104/smoke.sh.orig skills/teamsmith/tests/smoke.sh
$ cmp /var/tmp/v104/smoke.sh.orig skills/teamsmith/tests/smoke.sh && echo "restored: 逐字节相同"
restored: 逐字节相同
$ git status --porcelain --untracked-files=all | wc -l
0

$ bash skills/teamsmith/tests/smoke.sh --select 13c
  ✓ P236/P237 车道合同入口：wording+ledger+suspend-shape+owner-scope+merge+detail 全绿（56 条断言）
  ✓ P251 合并行在行计数读者里只算一行（merge 组折进 13c）
  ✓ P251 明细读面只读不 ack（detail 组折进 13c）
#12 13c · 团队后台车道（M27/M30）：拉起链注入 / 收割契约 / 账本 / worktree 侧 · 参考 用时 46s · ✓67 ✗0 SKIP0 · ticks 67
账本自查： 12 段收口 · 增量 ✓463 ✗0 SKIP0 ｜ 结果行 ✓463 ✗0 —— 一致
== 选段结果 ==  ✓ 463  ✗ 0
rc=0
```

两轮输出里「本次运行无效」都是 0 次（`grep -c` = 0）：破坏与还原都发生在两次运行**之间**，没有打断任何
一轮的运行指纹。整条链（破坏→跑→还原→再跑）在一个后台作业里跑完，`rc` 汇总 `mutant=1 restored=0`。

## 3 · A1 计数契约的两个读数

三档现场，读数取自 `team digest` 的 `[2] 待处理通知`、`team inbox <席>` 与 `team inbox --all`：

| 现场 | 文件里有什么 | `dev` 未读 | `pm` 未读 |
|---|---|---|---|
| ① | `dev.md` 只有 1 行 `[auto] agent:dev` 记录行 | **0** | 0 |
| ② | 再加 1 行 `pm.md` 的指针行（`[auto] agent:dev · … knock=enqueued · see=…`） | **0** | **1** |
| ③ | 再加 1 行 `dev.md` 的 `[manual] agent:pm`（对照） | **1** | 1 |

原文（现场 ①：文件确为 1 行，但那行不计入未读）：

```
$ /var/tmp/v104/fixrun.sh inbox --all          # dev 段
 === dev（全部 1 行）
  - 2026-10-23T09:00:00.000Z ⚠ 未提交 1 个文件 · [auto] agent:dev · P368 · branch=task/P368-bg-ledger-fixture · uncommitted=1 · unpushed=1(no-upstream) :: V104 record line
$ /var/tmp/v104/fixrun.sh digest | sed -n '/待处理通知/,/^$/p'
[2] 待处理通知
  （无）
$ /var/tmp/v104/fixrun.sh inbox dev            # 无输出 = 0 条新
```

现场 ②（`pm.md` 一条指针行，`agent:` 是发送者 dev）：

```
$ /var/tmp/v104/fixrun.sh digest | sed -n '/待处理通知/,/^$/p'
[2] 待处理通知
  pm（PM 自己的收件箱） · 1 条新
      - 2026-10-23T09:01:00.000Z [auto] agent:dev · P368 · knock=enqueued · see=docs/team/inbox/dev.md · task=P368 tip=38ee09b73abc
$ /var/tmp/v104/fixrun.sh inbox dev            # 仍无输出：指针没让 dev +1
```

现场 ③（`dev.md` 追加一条 `[manual] agent:pm`）：

```
$ /var/tmp/v104/fixrun.sh digest | sed -n '/待处理通知/,/^$/p'
[2] 待处理通知
  dev · 1 条新
      - 2026-10-23T09:02:00.000Z [manual] agent:pm · V104 manual notice
  pm（PM 自己的收件箱） · 1 条新
      - 2026-10-23T09:01:00.000Z [auto] agent:dev · P368 · knock=enqueued · …
$ /var/tmp/v104/fixrun.sh inbox dev
 === dev（新 1 条）
  - 2026-10-23T09:02:00.000Z [manual] agent:pm · V104 manual notice
```

即：`[auto] agent:<本席>` 的记录行不让该席位未读 +1，而 `pm.md` 里的指针行让它 +1。

## 4 · 写集与授权

- `docs/team/reviews/turn-notice-in-pm-inbox.md`：按任务书第 3 条在**末尾追加**一节，没有改动 V102 的任何
  既有段落（`git diff --stat` 显示只增不减）。
- `docs/team/reports/V104-dev-bob.md`：本报告。
- 产品代码与 `tests/` 一行都没有改：所有破坏都在 `/var/tmp/v104/priv` 私有副本里，还原后 `cmp` 逐字节相同。
- 没有跑整套、没有跑容器；`--select 13c` 带进来 12 段（0/0b/0c/0d/2/4/5/3b/6/6f/6i/13c），其余 123 个键没跑。
- 门禁锁排队（不是判定）：第一轮运行时的持有者是 verify 席位的整套运行
  （`/tmp/.teamsmith-smoke.lock.machine.holder`：`pid=1292624 kind=top agent=verify bound=4500`）。为了只吃
  一次排队，把「破坏 → 跑 → 还原 → 再跑」串成一条链式后台作业（整条 771.9s，两段自报 32s / 46s）。
  没有用 `TEAM_SMOKE_NO_LOCK=1`，也没有碰别人的运行。
