# P410 · 一阶每次跑，二阶低频跑

agent: dev   status: delivered   time: 2026-11-04
branch: `task/P410-order2-split`   PR/MR: -（local 模式：提交留在任务分支，不推远端）

**结论先说**：门禁拆成两阶 —— 一阶（验产品行为）每次跑，二阶（验我们的测试/夹具/断言/文档承诺本身
有没有牙齿）默认不跑、逐段打印「为什么它是二阶」与「最近一次绿记录」，由 `tests/meta-suite.sh`
低频执行并落记录；同一条记录**在一阶门禁里被断言**（存在、≤7 天、内容读得出来），所以「每晚都失败」
一周之内必然把发版门禁点红。拆出去的二阶腿实测合计 **7316 s（121.9 分钟）**，它们的失败含义是
「测试自己错了」，与「产品对用户做错了事」不是同一类信号。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/section-paths.tsv` | 两份**显式**清单：`first-order:` 132 段 + `meta-suite:` 6 段（每段一行「为什么它是二阶」）；新行 `38m` / `51m`（§38、§51 的二阶腿，产品面留在原地）；`gate-self-check:` 补 `38m 40 51m` |
| `skills/teamsmith/tests/section-select.sh` | `--meta` 只读出口；`--check ⑩`「一阶 ∪ 二阶 = 全部段」：缺口 / 重叠 / 空理由 / 产品基线段进二阶，各自红 |
| `skills/teamsmith/tests/smoke.sh` | `smoke_meta_begin <key>` 逐段跳过行（`SKIP（二阶 · 默认不跑）<段号> —— <理由>；最近一次绿记录：<时间>（距现在 N 天）（<路径>）`）；§0e/§36/§40/§38m/§51m 按频率跳过；§38 只剩产品腿、§51 只剩产品面；§14d 增运行时账（见下） |
| `skills/teamsmith/tests/meta-suite.sh` | 低频入口：清单只读 `--meta` → `smoke.sh --select <二阶全部>` + `TEAM_META=1` → 记录：`<项目根>/.pi/team/state/meta-suite/<ISO>.log` + `history.tsv`（6 列：时间/判定/项目根/日志/总耗时s/段数）；绿红由**日志内容**判（`judge_log` 三条判据） |
| `skills/teamsmith/tests/flip-p410-order2.sh` | 红侧夹具 10 条（下表） |
| `.github/workflows/gates.yml` | `schedule: cron '47 3 * * *'` + 作业 `meta`（`timeout-minutes: 150`，跑元套件并把记录作为工件留存）；**push 触发的门禁段集不变** |
| `skills/teamsmith/tests/smoke.sh`（`--snapshot`） | 被指纹判定的运行改为跑在**冻结快照**上：`git worktree add --detach <sha>` 到独立目录，在**那里**跑；活树后的提交不再让整轮作废（PM 2026-11-04 裁定：改机制不改纪律），快照内部指纹照旧 |
| `skills/teamsmith/tests/gate-guard.sh` | 测量夹具判据从「文件里出现即红」改成行为面「单引号之外出现即红」（修 main 上自 P404 合并以来的红），§0e 加两条具名翻转 + 还原对照 |
| `docs/team/reviews/release-0.4.0-prep.md` | 发布门槛新增一节：≤7 天的元套件绿记录（路径、证据形状、是谁在断言它） |

§14d 新增的五条运行时断言（全部在一阶）：

| # | 断言 | 它守的是 |
|---|---|---|
| 1 | 跳过行的理由不为空（`META_NOREASON_N == 0`） | 跳过行必须说得出「为什么它是二阶」 |
| 2 | 输出里的跳过行数 == 本轮跳过段数 | 跳过行被拆走/删掉 → 红（`tee` 的落盘副本就是输出本身） |
| 3 | 全量运行里表里每一行都开过段（唯一例外 §14c，点名） | 「搬家没搬干净」：谁把 `smoke_meta_begin` 的 `if` 拆了，那段会回到每次门禁里 |
| 4 | 本项目最近一条 GREEN 记录存在且 ≤7 天 | 夜里那条连续失败一周也没人看见 → 变成会红的断言 |
| 5 | 记录 6 列 / 总耗时与段数是正整数 / 段数 == 日志收口行数 | 「文件存在即通过」的反面：畸形记录、截断记录都红 |

## 为什么加 `--snapshot`（PM 2026-11-04 裁定「改机制不改纪律」）

同一形状发生过两次（P398、本轮第三轮）：门禁的「本次运行无效」指纹抓到**运行中提交**，把整轮作废 ——
第三轮那次指纹起点 `1bfaaeec`，开跑 7 秒后我提交了 `f7c1ca8f`。判据本身是对的（夹具改树就该作废），
错的是把「跑的时候别提交」当成纪律去要求人：两小时的运行期间不许提交，等于要求人停手。

所以改的是机制：`smoke.sh --snapshot[=<sha>]` 把被验**提交**导成独立工作树（`git worktree add --detach`），
在**快照里**跑；记录里写死 sha（`TEAM_SNAPSHOT_SHA`，元套件记录头/尾各一处）。快照内部指纹完全保留 ——
它现在只可能抓到「夹具自己改了树」，那正是它该抓的。

三个实现细节，各自有它的原因：

- 快照根放 `/var/tmp`，**不占调用者的 `TMPDIR`**：§40 会拿 `TMPDIR` 清点「本轮的临时根家族」，一个装着整份
  仓库的外姓目录出现在那里会让它误判。`TEAM_SNAPSHOT_DIR` 可覆盖。
- 内层运行放**后台**、外层用 `wait` 等：bash 对前台子进程会把 trap 推迟到子进程结束，对 `wait` 不会 ——
  这样 Ctrl-C / `kill` / 管道那头先关（SIGPIPE）都能走 trap 收尾。实测过：管道被 `head` 关掉原本会漏一个
  完整的仓库副本 + 一条已注册的工作树。
- `git worktree remove --force` 失败不静默：打印没成的那一条，再用 `prune` + `rm` 兜底，删不掉也点名。

CI 的检出是只读挂载（`-v $PWD:/work:ro`）＝按构造冻结，不需要也不能建快照，workflow 保持原样。

## 判据

一句话：**这段失败意味着「我们的测试/夹具/断言/文档承诺错了」→ 二阶；意味着「产品对用户做错了事」→ 一阶。**
落到具体一段时用第二个问题：*如果它红了，交付物（用户拿到的 teamsmith）是不是真的坏了？* §36（选段器、
映射表、剪贴副本、覆盖探针的自检）红了说明选择器错了，产品行为没变 —— 二阶。§38 的真 pty 走查（38-b/f/h/i）
红了说明命令在真终端里选不动、屏幕上没有那条提示 —— 一阶，一条都不许搬。

## 代价表（本机实测，2026-11-04）

一阶每次跑的部分（本次直接量到的）：

| 段 | 拆后内容 | 实测 |
|---|---|---|
| §38 产品腿 | `panel-choices.sh read known read-equality catalogue`（choices 读 / 模型词表 / 读写等价） | 7 s |
| §51 产品面 | `routes.sh walk control promises refusals`（help 的每条承诺都有夹具兑现 / 吞参数的解析器被点名） | 99 s |

搬到二阶的 6 段（第二轮元套件记录里的逐段耗时，同一台机器、同一棵树）：

| 段 | 为什么它是二阶 | 第二轮实测 |
|---|---|---|
| `61b` | 模型路由的 31 条翻转变异 | 5715 s |
| `36` | 选段器 / 映射表 / 剪贴副本 / 覆盖探针的自检 | 1001 s |
| `51m` | routes.sh 的十次变异翻转（走查的牙齿） | 413 s |
| `38m` | 一致性走查（86 次 `config set --dry-run`）+ F-A/F-D 翻转 + 等待库自检 | 77 s |
| `40` | 临时根纪律 lint / 泄漏断言 / owned 家族 | 60 s |
| `0e` | 段落自述、看门狗、循环清单的自检 | 50 s |
| 合计 | | **7316 s ≈ 121.9 min** |

拆前拆后（同一段拆开量，不是估算）：`panel-choices.sh` 全跑 94 s = 产品腿 7 s + 二阶腿 87 s；
`routes.sh` 全跑 = 产品面 99 s + 翻转 413 s（第二轮记录）。参照：2026-10-30 那次全量门禁 184.9 分钟里，
`61b` 一段 5724 s、`36` 964 s、`51` 1037 s、`38` 718 s —— 那四个数是同一起因的量级证据，不是本轮的量。

**一阶段全量门禁（实测，快照 ca1f70b1）**：`== 结果 == ✓5024 ✗2`，**77 分 7 秒**（逐段 elapsed 合计
4627 s，137 段）—— 拆前同一套是 185 分钟。剩下的两块大头是 `62` 792 s、`38` 628 s、`51` 622 s、`61` 554 s；
后两块的产品腿实测只有 7 s / 99 s，其余时间仍留在里面的是真进程走查（pty/tmux 场景），不是「测试测试自己」。

那两条红不是本任务的：见下面「未验证」的第一条。

## Verification evidence

```
$ bash skills/teamsmith/tests/flip-p410-order2.sh
  ✓ ① union-gap：删掉二阶清单里的 0e → --check 红并点名 0e（「从两次运行里一起消失」）
  ✓ ② product-leg：把 7 notify/inbox/digest 错放进二阶 → --check 红并指出它本该在一阶/FAST 里跑到
  ✓ ③ no-reason：二阶行不写理由 → --check 红并点名 0e（跳过行必须说得出为什么）
  ✓ ④ skip-line：跳过行不进输出 → 运行时 §14d 红（输出行数 0 ≠ 跳过段数 1）
  ✓ ④ skip-line 对照：pipe 放回去 → 同一棵树、同一条断言绿（那条红确实由它产生）
  ✓ ⑤stale：> 7 天 → §14d 红并点名（绿记录的两个字段都判）
  ✓ ⑤secs：记录与日志不一致 → §14d 红并点名（绿记录的两个字段都判）
  ✓ ⑤total：总耗时读不出来 → §14d 红并点名（绿记录的两个字段都判）
  ✓ ⑤redonly：没有本项目的 GREEN 记录 → §14d 红并点名（绿记录的两个字段都判）
  ✓ ⑤对照：合法记录（7 天内、段数与日志一致、总耗时 120s）→ §14d 绿
== flip-p410 == ok 10 bad 0
```

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 表里每一行的 key 都能被哈希（138 个 key × 7 个 N 都在 0..N-1 内）
ok: 两阶段是全部段的精确划分（一阶 132 + 二阶 6 = 表 138 行；二阶每段有理由、都是 gate-self-check 段）
== 选段自检 ==  ok 13  bad 0  SKIP 1
```

```
$ TEAM_META=1 bash skills/teamsmith/tests/smoke.sh --select 0e </dev/null
#5 0e · 段落自述：看门狗 / 循环清单（P70 · P316） · 参考 用时 50s · ✓26 ✗0 SKIP0 · ticks 26
账本自查： 5 段收口 · 增量 ✓50 ✗0 SKIP0 ｜ 结果行 ✓50 ✗0 —— 一致
== 选段结果 ==  ✓ 50  ✗ 0
```

```
$ bash skills/teamsmith/tests/gate-guard.sh            # 本分支
gate-guard: 三向都过（…）                                rc=0
$ bash /var/tmp/p410-mg/gate-guard.sh                  # main 的 smoke.sh + main 的守卫
bad: smoke.sh 点名了测量/参考夹具：11405: 'tests/perf.sh' …;11413: …   rc=1
```
（main 侧那一跑是把 `git show main:` 的 smoke.sh / gate-guard.sh / lib 落到 `/var/tmp` 再跑的，
证明这条红不是本任务引入的。）

```
$ bash skills/teamsmith/tests/workflow-entry.sh            # CI 入口（含新的 schedule/meta 作业）
== workflow-entry == ok 21 bad 0 skip 0
$ node -e "js-yaml.load(gates.yml)"                        # YAML 结构体检
jobs: resolve-pi,gates,meta,coverage | triggers: push,workflow_dispatch,schedule
```

```
$ bash skills/teamsmith/tests/section-guard.sh --loop-check --tree <tests 副本>
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个          # 新增两条（快照收尾 / panel-b3 计数）
$ openspec validate --all
Totals: 20 passed, 0 failed (20 items)
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) in 13657 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2358 hits=0 names=ok user=resolved      rc=0
$ git diff --check && echo diff-check OK
diff-check OK
$ bash skills/teamsmith/tests/smoke.sh --snapshot </dev/null     # 一阶全量，快照 ca1f70b1
== 结果 ==  ✓ 5024  ✗ 2
$ bash skills/teamsmith/tests/smoke.sh --select 25,30 </dev/null  # 那 2 条红所在的段，清理后重跑
== 选段结果 ==  ✓ 121  ✗ 0
```

元套件的记录与本轮真实跑（第二轮，7321 s）：

```
$ cat <项目根>/.pi/team/state/meta-suite/history.tsv
2026-11-04T06:46:57Z	RED	<项目根>	…/2026-11-04T06-46-57Z.log	7486	0
2026-11-04T08:56:16Z	RED	<项目根>	…/2026-11-04T08-56-16Z.log	7321	10
```

第二轮那 6 段**全绿**（`0e ✓26 ✗0`、`36 ✓121 ✗0`、`38m ✓2 ✗0`、`40 ✓42 ✗0`、`51m ✓1 ✗0`、`61b ✓1 ✗0`，
`账本自查： 10 段收口 · 增量 ✓217 ✗0 … 一致`），记录却写成 RED —— 判据②要求每段收口行带 `SKIP0`，而 §36
正常就有 3 条可见跳过。修法是判定改成**读日志内容**（`judge_log`），并在同一份日志上重算验证：
`judge_log 2026-11-04T06-46-57Z.log → RED`（正确：那轮 §0e 真有 2 红）、
`judge_log 2026-11-04T08-56-16Z.log → GREEN`。修完这条判据不重跑那 2 小时，第三轮跑出的是干净记录。

## 元套件第一条可引用的 GREEN 记录（2026-11-04T19:06:45Z）

```
$ cat <项目根>/.pi/team/state/meta-suite/history.tsv | tail -1
2026-11-04T19:06:45Z	GREEN	<项目根>	…/2026-11-04T19-06-45Z.log	7165	10	edda4fcb
$ head -1 …/2026-11-04T19-06-45Z.log
# meta-suite 2026-11-04T19:06:45Z · 检出 …/.worktrees/dev @ edda4fcb · 二阶段 6 段 · 运行面=冻结快照 edda4fcb00dc8f62c4955d4fd551135040b9ed83 · 判据 edda4fcb
$ sed 's/\x1b\[[0-9;]*m//g' …/2026-11-04T19-06-45Z.log | grep '· 参考 用时'
#5  0e  · 参考 用时 49s    · ✓26  ✗0 SKIP0
#6  36  · 参考 用时 953s   · ✓121 ✗0 SKIP3
#7  38m · 参考 用时 76s    · ✓2   ✗0 SKIP0
#8  40  · 参考 用时 61s    · ✓42  ✗0 SKIP0
#9  51m · 参考 用时 392s   · ✓1   ✗0 SKIP0
#10 61b · 参考 用时 5628s  · ✓1   ✗0 SKIP0
== 选段结果 ==  ✓ 217  ✗ 0
# meta-suite result verdict=GREEN total=7165s sections=10 … 判据=edda4fcb
```

七列依次是：时间 / 判定 / 项目根 / 日志 / 总耗时 / 段数 / **判据 sha**（PM 2026-11-04：让「日志绿、记录红」
一眼可辨）。本次是 `--snapshot` 在 `edda4fcb` 的冻结快照上跑的 —— 活树上的后续提交不再让整轮作废。

同一判据在历史日志上的复核（只读 `--judge`，不写 history、不跑段）：

```
$ bash skills/teamsmith/tests/meta-suite.sh --judge …/2026-11-04T16-50-35Z.log
  判定：GREEN（只读：没有写 history、没有跑任何段）
$ bash skills/teamsmith/tests/meta-suite.sh --judge …/2026-11-04T11-01-40Z.log
  判定：RED（… 这一轮被 smoke 判为「本次运行无效」…）
$ bash skills/teamsmith/tests/meta-suite.sh --judge …/2026-11-04T06-46-57Z.log
  判定：RED（… 最后一条 == 选段结果 == 不是 ✗0：== 选段结果 ==  ✓ 211  ✗ 2）
```

## Flip evidence

上表 10 条；`flip-p410-order2.sh` 每次都在 `$TMPDIR` 下的私有变体树上做（产品面软链到真树，只有
`smoke.sh`/`section-paths.tsv` 是真副本），退出时删根；`--keep` 保留现场。除 ④ 的两条要走 §14d 之外，
其余都是纯静态判据（`--check`），一条 1 秒级。

## 一次「意外全套」给出的分类证据（2026-11-04 13:30，快照 6e80c3c6）

第四轮元套件因为 `--snapshot` 转发时丢了 `--select`（已修），内层跑成了**全套**：137 段、186 分钟、
`== 结果 == ✓5203 ✗12`。这一轮本身按纪律作废（记录写 RED，因为它不像一次元套件运行），但它把
「拆完之后还红什么」一次性全暴露了，逐条如下：

| ✗ | 归属 | 处置 |
|---|---|---|
| `P70 循环清单：干净树绿`、`P70 翻转（循环）还原`、`P313 翻转（盲区）还原` | 我新增的 `while kill -0…; do sleep 0.2` 收尾等循环没登记 | 登记进 `loop-inventory.tsv`（84→85 行，配平 85 个） |
| `12b-j` / `M9.8` / `26-l` / `M16` 隔离：「夹具痕迹出现在真项目/真实账本」 | 元套件把运行记录写进 `<项目根>/.pi/team/state/meta-suite/`，四道隔离判据不认识这个合法写入者 | PM 已派 P411 登记白名单（`main-team-fingerprint.sh`）；本任务按指示**不改路径、不加跳过** |
| `38-i … 收前后窗口数不变（期望 [3]，实际 [2]）` | 老缺陷：`cmd` 辅助窗口的 `sleep 1` 还没退就被计数。**在 main（3d855705）上同样红**，与 P410 无关 | 已修（计数前有界等辅助窗口消失），断言未放松；`panel-b3.sh collapse` 单独跑 8✓0✗ |
| `P410 二阶账：清单里 6 段各自经 smoke_meta_begin（期望 [] 实际 [61b]）` | §61b **从没上过频率闸** —— 拆分名义上搬走了它，实际每次门禁还在跑那 95 分钟 | 现在与 0e/36/40 同形（`if smoke_meta_begin "61b"`） |
| `P410 并集：全量运行里只有 §14c 没开段（期望 [14c] 实际 [14c 15]）` | 例外表漏了收尾段 §15（没有段体） | 改成两个具名例外：`14c`（FAST-only）与 `15`（收尾） |
| `P410 元套件记录：没有本项目的 GREEN 记录` | 当时确实还没有一条绿记录 | 由本轮的 GREEN 记录解决 |

四条隔离红是 P411 的缺口（PM 已派），其余六条都是本任务范围内的缺陷，已逐条修掉并各自有红侧。

## 未验证 / 风险 / 待办

- **一阶段全量门禁剩 2 条红，都是同一个脱轨产物**：`M9.8 隔离` 与 `M16 隔离` 点名
  `<项目根>/.pi/team/state/meta-suite/2026-11-04T13-30-26Z.log` —— 那是第四轮「意外跑成全套」的 620 KB
  转录，里面当然有夹具自己的 session 代号（`M98B`、`M16 口径` …）。记录目录本身不含夹具痕迹（绿记录那份
  75 KB 干净），问题只在这份作废转录。处置：删掉这四份作废产物（13:30 全套转录 + 三份 `--judge` 误触发的
  真跑，均随进程被杀），history 里那条 RED 行保留（判定与耗时仍在，转录的 12 条红已逐条抄进本报告）。
  删后重跑这两段：`--select 25,30` → `== 选段结果 == ✓121 ✗0`（上面「Verification evidence」里有原文）。
  这条 deletion 是清理，不是「为消红改机制」——路径与记录形状一字未动。
- **P409 隔离判据对 `state/meta-suite/` 的假红**：P411 已在 main 落地（`5ac9ef47` 把 `meta-suite` 登记进
  `main-team-fingerprint.sh` 的易变白名单）。本分支在 P411 之前，按 PM 指示未改路径、未加跳过；
  合并后这形状不再报红。
- **CI 侧没跑过**：nightly `meta` 作业（`schedule: cron '47 3 * * *'`，`timeout-minutes: 150`）是头一次
  落地，首跑要看 Actions 日志（本地实测 7165 s ≈ 119 分钟，余量 31 分钟）。push 触发的门禁段集不变。
- `openspec validate --all --strict` 在 main 上就红（20/20 failed，都是「requirement 文本 >500 字符」
  这类警告升级），与本任务无关（本分支对 `openspec/` 零改动）；CI 实际用的是非严格模式
  （`gates.yml`: `openspec validate --all`）。协议文本里的 `--strict` 与 CI 口径不一致，留 PM 决定。
- **记录目录会涨**：一份记录约 75 KB（作废的全套转录 620 KB），没有保留策略。要不要按 N 份滚动删除
  是产品决定，本任务不擅自加（net-zero 规则：加一个清理守卫得先去掉一个）。
- 门禁锁：五轮元套件（每轮约 2 小时）+ 一阶段全量门禁都独占 `/var/tmp/teamsmith-smoke.lock`，本轮与
  其它席位串行；两轮因作废重跑是这台机器的实际代价（`61b` 单段 94 分钟）。
