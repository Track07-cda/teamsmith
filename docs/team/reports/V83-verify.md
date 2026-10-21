# V83 · P342 的独立验收：取样范围收窄了，判据还剩多少牙

agent: verify   status: **PASS**（四条问题逐条成立；一条不阻塞的遗留问题见「残余风险」里的 F1）
                time: 2026-10-21T00:05Z（受检候选 2026-10-20T23:44:11Z）
branch: `task/V83-ledger-scope-verify`（local 模式，未 push，未合并）   PR/MR: -
受检：`5ab8a377`（实现 `d773a8ad`，写集 `skills/teamsmith/tests/smoke.sh` +18/−2，一个文件）。
作者报告：`docs/team/reports/P342-dev-bob.md`。

## 结论（先看这里）

**PASS。四条问题逐条成立，且红侧是我自己造的、在不改受检树的前提下把判据打到红再还原。**

1. **前缀边界严密，三种「仍算账本」的形状都仍被点名。** `in_release_dir()`（候选树 `skills/teamsmith/tests/smoke.sh:897-900`，
   即 `d773a8ad` 那份文件）要求
   `index(p, "<root>/.pi/team/state/release-") == 1` **且** 该前缀之后还有 `/`。在私有副本里放三枚探针
   —— 同前缀的**文件** `release-scan.log`、嵌套目录 `nested/release-x/a.log`、账本侧同名目录
   `docs/team/inbox/release-x/a.log` —— M9.8 与 M16 **都红，并把三条路径逐个点名**（`✓106 ✗2`），
  而同场在座的 `release-030/container-full.log`、`public-ci.log` **没有被点名**。
2. **真泄漏仍然抓得住，而且只点名泄漏。** 同一棵树里往真实状态目录（非 `release-*`）放
   `.pi/team/state/v83-leak-probe.txt`，两条断言都红，红行里**只有这一个路径**，发布证据依旧静默
   （`✓106 ✗2`）。
3. **没有顺手削弱别的。** `real_ledger_hits` 的三条既有豁免（`-v audit=` / `-v forensics=` / `-v jobs=`）
   与两个扫描根（`for d in "$root/docs/team/inbox" "$root/.pi/team/state"`）在父版本与候选里**逐字相同**；
   函数体 diff 只有新增的 `-v releases=`、`in_release_dir()` 与条件末尾的 `&& !in_release_dir($0)`。
4. **残余风险如实写了，我判它可接受**（依据在下），但有一条要 PM 知情的不阻塞问题 **F1**：这条豁免
   **没有任何常驻断言**钉住它的边界，我的变异实测证明「放宽成路径里含 `release-` 就跳过」**整套相关段照样全绿**
   —— 今天这点牙是人工验过的，不是门禁守着的。

作者的 `--select 12b,25,26,30` 口径（扫描器的四个消费者）我复跑得到 `✓379 ✗0`、rc=0，与它的报告一致。

## 我跑了什么（真实命令与读数）

所有破坏都在 `/var/tmp/v83-verify/` 的私有副本里；受检树只读。副本由 `git archive 5ab8a377` 展开成独立
git 检出，再把**真实** `.pi/team/state/release-030/{container-full.log,public-ci.log}` 只读拷进去
（`prepare()` 在驱动脚本里）。驱动脚本：`/var/tmp/v83-verify/run-v83.sh`，整场日志
`/var/tmp/v83-verify/driver.log`，逐场次日志 `/var/tmp/v83-verify/logs/S*.log`。

任务书只允许写本报告与我的线程，所以驱动脚本与场次日志留在 `/var/tmp` 而不是提交进仓 —— 复跑命令见下
（每一场都是：进副本、`bash skills/teamsmith/tests/smoke.sh --select <段>`）。

```
$ bash /var/tmp/v83-verify/run-v83.sh          # 23:46:53Z → 00:02:25Z，933s
```

门禁互斥：这五场都在机器锁下排队（先有另一个席位的全量 smoke 在跑，日志里留了 `另一套全量 smoke 正在跑…`
与 `本轮由 pid=… 持有 …（伴生锁；本套是它跑的那一套，不再排队）` 两行），没有绕过锁、没有用
`TEAM_SMOKE_NO_LOCK`。

### ① 真实账本上的只读前后对比（同一根、同一批文件，只换扫描器文本）

父版本（`d773a8ad^`）与候选（`d773a8ad`）的 `real_ledger_hits` 原样抽出，对真实主检出跑：

```
$ bash /var/tmp/v83-verify/scan.sh /var/tmp/v83-verify/smoke-old.sh <真主检出> 'M98[.A-G]'
…/.pi/team/state/release-030/container-full.log
…/.pi/team/state/release-030/public-ci.log
$ bash /var/tmp/v83-verify/scan.sh /var/tmp/v83-verify/smoke-new.sh <真主检出> 'M98[.A-G]'
（空）
（M16[.A-E] 两个方向完全相同：旧 2 命中 → 新 0 命中）
```

这两份命中的文件就是 `--floor` 当日报的那两条红，形状对得上。

### ② S1 · 三枚「仍算账本」的边界探针（期望红、逐个点名）

副本 `T1`，探针内容统一是 `M98G1 夹具痕迹 V83 探针` + `M16A 夹具痕迹 V83 探针`：

```
$ cd /var/tmp/v83-verify/T1 && bash skills/teamsmith/tests/smoke.sh --select 25,30
  ✗ M9.8 隔离：夹具的痕迹出现在真实账本里：/var/tmp/v83-verify/T1/docs/team/inbox/release-x/a.log /var/tmp/v83-verify/T1/.pi/team/state/nested/release-x/a.log /var/tmp/v83-verify/T1/.pi/team/state/release-scan.log
#5 25 · 唤醒计数 = digest 的可行动列表（M9.8） · 参考 用时 31s · ✓57 ✗1 SKIP0 · ticks 58
  ✗ M16 隔离：夹具的痕迹出现在真实账本里：/var/tmp/v83-verify/T1/docs/team/inbox/release-x/a.log /var/tmp/v83-verify/T1/.pi/team/state/nested/release-x/a.log /var/tmp/v83-verify/T1/.pi/team/state/release-scan.log
#6 30 · 代号必须带名字（M16） · 参考 用时 6s · ✓26 ✗1 SKIP0 · ticks 27
账本自查： 6 段收口 · 增量 ✓106 ✗2 SKIP0 ｜ 结果行 ✓106 ✗2 —— 一致
exit=1
```

三条探针**逐个点名**，`release-030/` 下的两份证据**没有出现在红行里**。同树的函数级扫描（`scan.sh`，
同一个 fakeroot 形状）给出同一结论：旧实现 6 条命中（含两份发布证据），新实现 4 条（三枚探针 + 真泄漏探针）。

### ③ S2 · 真泄漏探针（期望红、只点名探针）

```
$ cd /var/tmp/v83-verify/T2 && bash skills/teamsmith/tests/smoke.sh --select 25,30
  ✗ M9.8 隔离：夹具的痕迹出现在真实账本里：/var/tmp/v83-verify/T2/.pi/team/state/v83-leak-probe.txt
  ✗ M16 隔离：夹具的痕迹出现在真实账本里：/var/tmp/v83-verify/T2/.pi/team/state/v83-leak-probe.txt
账本自查： 6 段收口 · 增量 ✓106 ✗2 SKIP0 ｜ 结果行 ✓106 ✗2 —— 一致
exit=1
```

### ④ S5 · 扫描器四个消费者的绿侧基线

```
$ cd /var/tmp/v83-verify/T4 && bash skills/teamsmith/tests/smoke.sh --select 12b,25,26,30
✓ 12b · 延后投递与草稿入口 · ✓87 ✗0 SKIP0 ｜ ✓ 25 · M9.8 · ✓58 ✗0 ｜ ✓ 26 · 面板 · ✓143 ✗0 ｜ ✓ 30 · M16 · ✓27 ✗0
账本自查： 10 段收口 · 增量 ✓379 ✗0 SKIP0 ｜ 结果行 ✓379 ✗0 —— 一致
exit=0
```

`T4` 里只有 `release-030/` 的两份真实发布证据、没有任何探针 —— 即「假红已消失」的绿侧现场。

### ⑤ 第三条（没有顺手削弱别的）的静态证据

```
$ diff -u <父版本函数> <候选函数>
     | awk -v audit=… -v forensics=… -v jobs=… \
-          '$0 != audit && $0 != forensics && index($0, jobs) != 1' \
+          -v releases="$root/.pi/team/state/release-" '
+        # P342：发布证据目录 <root>/.pi/team/state/release-<名字>/ —— 前缀命中且**目录名后面还有路径分量**…
+        function in_release_dir(p) {
+          if (index(p, releases) != 1) return 0
+          return index(substr(p, length(releases) + 1), "/") > 0
+        }
+        $0 != audit && $0 != forensics && index($0, jobs) != 1 && !in_release_dir($0)' \
     | sort -u || true
SAME  for d in  | { for d in "$root/docs/team/inbox" "$root/.pi/team/state"; do
SAME  -v audit=  | | awk -v audit="$root/.pi/team/state/tmux-calls.log" \
SAME  -v forensics=  | -v forensics="$root/.pi/team/state/tmux-calls.log.forensics" \
SAME  -v jobs=  | -v jobs="$root/.pi/team/state/bg/" \
```

（`SAME` 那四行是脚本逐字比较的输出；上一行 diff 里三行 `-v` 与扫描根都只是上下文。）

### ⑥ 轻量收口

```
$ bash -n skills/teamsmith/tests/smoke.sh && echo "bash -n OK"
bash -n OK
$ cmp -s <d773a8ad 抽出的版本> <候选树里的 smoke.sh> && echo "逐字节相同"
逐字节相同
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/…/.worktrees/verify scope=published files=1976 hits=0 names=ok user=resolved
rc=0
$ git diff --check; echo rc=$?
rc=0
```

## Flip evidence（红 → 绿 → 破坏 → 还原）

第 ① 条要证伪的是「豁免把判据关掉了」，所以翻转要在**同一棵树、同一批探针**上做，只改豁免表达式。

| 场次 | 树 | 改了什么 | 期望 | 实跑 |
|---|---|---|---|---|
| S1 | `T1`（候选原文 + 三枚边界探针 + 发布证据） | 无 | 红、点名三条 | **红**：`✓106 ✗2`、rc=1，三条路径逐个点名 |
| S2 | `T2`（候选原文 + 真实状态目录探针 + 发布证据） | 无 | 红、只点名探针 | **红**：`✓106 ✗2`、rc=1，只点名 `v83-leak-probe.txt` |
| S3 | `T3` = `T1` 的副本 | 把 `in_release_dir` 放宽成 `return index(p, "release-") > 0` | 三枚边界探针**变成不红** | **绿**：`✓108 ✗0`、rc=0；同树函数级扫描只剩真泄漏探针 |
| S4 | `T3`（原文放回，`cmp` 逐字节相同） | 还原 | 回到红 | **红**：`✓106 ✗2`、rc=1，同样那三条路径 |
| S5 | `T4`（只有发布证据） | 无 | 绿 | **绿**：`✓379 ✗0`、rc=0 |

S3 的变异原文（只改副本里的函数体，受检树未动）：

```
        function in_release_dir(p) {
          return index(p, "release-") > 0
        }
```

这一条同时给出两个结论：**探针有判别力**（放宽后它们立刻不再红），以及 **F1** —— 放宽之后门禁**不会**
报出任何异常，所以这套判据今天没有能自己发现这种放宽的墓碑。

## 第四条：残余风险，以及我为什么判它可接受

作者在代码注释（候选树 `skills/teamsmith/tests/smoke.sh:883-884`，即 `d773a8ad` 那份文件）与报告「残余风险与没有做成常驻断言的原因」一节里都点名了同一句：
真有夹具往 `.pi/team/state/release-*/` 里写东西，M9.8 / M16 不会再抓它。我的判断是**可接受**，依据三条：

1. **这个子树不是产品读写的账本。** 全仓 `grep -rn "state/release-" --include='*.sh' --include='*.md'
   skills/ docs/team/tools/` 零命中；状态目录的唯一消费者按文件读席位记录
   （`skills/teamsmith/scripts/lib/cmd-agents.sh:1119` 读 `$TEAM_STATE_DIR/<seat>.env|.pending`），不遍历子目录。
   也就是说 `release-*/` 里放的是**人在发布复核时写下的证据**，不是工具会读的账本；判据的本职「夹具不许把
   痕迹写进团队真正在用的账本」在那块区域本来就不适用。
2. **缺口是单向的、且今天的代码路径走不到那里。** 门禁的夹具全部写在 `$TMP` 下，没有任何段会写发布证据目录；
   要落进这个缺口，得有人**新增**一条往 `release-*/` 写的路径 —— 那已经是一次代码变更，会在评审里看见。
3. **另一条路更差。** 按内容猜「这行像日志」会造出一族假阴（任何日志文件里的夹具标记都会被放过），
   比一处按前缀的取样豁免宽得多；作者选前缀而非内容匹配，方向是对的。

**F1（不阻塞，请 PM 知情后裁定）**：这条豁免**没有常驻断言**。作者的报告自己说了这一点，我的 S3 实测把它变成
可量化的结论：把边界放宽成「路径里含 `release-`」之后，`--select 25,30` 与四个消费者全绿（`✓108 ✗0`），
所以在门禁层面这次放宽是**静默**的，只能靠人工评审发现。任务书没有要求这次加墓碑，而净零原则要求新增守卫
必须同时退役一个，所以我没有把它当缺陷。若 PM 认为该钉，作者报告里给的位置是对的：M16 的负对照块加
「`state/release-x/leak.log` 静默 + `state/release-scan-current.log` 点名」两条，覆盖假阴的两侧 —— 但那需要
同一次变更里退役一条既有断言，属于下一次改动的范围。

## Decisions and deviations

- 任务书要求「跑一次 `--select 25,30` 与 `--select 12b,25,26,30`」：我多跑了三次（S2/S3/S4），因为它们才是
  第三、四条问题的承重证据；没有跑整套（按任务书，且 §61b 在全套里会撞挂住上限）。
- 段号按作者查到的 **25 / 30**（`13` 是 notify 扩展，与这两条断言无关），我复核了段标题：
  `25 · 唤醒计数 = digest 的可行动列表（M9.8）`、`30 · 代号必须带名字（M16）`。
- 写集：只有本报告与我的线程。受检树、实现、看板、规格一律未动；没有合并、没有 push（local 模式）。
- 我没有复用作者 `/var/tmp/p342-flip/` 的任何脚本：它那份 `prepare()` 用作者的工作树做 `git archive`，
  我用自己的驱动脚本对我的工作树取 `5ab8a377`，两者独立。
- 副本的 `.pi/` 与 `docs/team/inbox/` 都被 `.gitignore` 覆盖，所以探针不会让门禁的运行指纹（P158）判本次运行
  无效；五场的 `账本自查` 行都一致（`增量 = 结果行`），没有出现 `本次运行无效`。

## Suggested next steps

1. **合并**：`d773a8ad` 的写集只碰 `real_ledger_hits`，与 P343/P344 的改动无交叠；merge 时注意别把候选基点里
   没有的账本提交一并带过去（本任务只判实现，不动账本）。
2. **F1 的墓碑**（若 PM 要钉）：下次动 `smoke.sh` 时在 M16 负对照块补两条，并同时退役一条等价的弱断言，
   以守住净零。
3. **P342 报告的一处口径**：作者写「`--select 25,30` ✓108 ✗0」是在**没有探针**的树上，我复现了同一读数
   （S5 里 25/30 各 `✓58/✓27` 全绿）；它没有声称过带探针仍绿，两处不矛盾。
