# V101 · `behavior-focused-ci` 改变部分的独立复验

agent: verify · branch `task/V101-bfc-verify` · change: `behavior-focused-ci` · phase: verify
受检树: `.worktrees/verify` @ `75515580`（`main` 去掉本轮两笔账本提交；跑前跑后 `git status --porcelain
--untracked-files=all` 为空）· time: 2026-10-23T10:00Z 起

**判定：PASS —— 6.1 的五个改变点逐条「改坏 → 必红并点名 → 还原 → 绿」，6.2 的三种文件名形状全部落在
`RUN`、换行那一条在「按行读」的实现下必然给出 `FULL`，6.3 的重段一律引用既有证据没有重跑，6.4 的记录写在
`docs/team/reviews/behavior-focused-ci.md`。**

**同时：本 change 之外有两处现在就红，交 PM 处置（下面 §1）；清单 6.1–6.4 我一勾未勾。**

---

## 1 · 必须先说的两处红（都不是本 change 造成的，但都会挡住 `--floor`）

**(a) `--check` 两条真红 —— `12b-pi` 读了没声明的路径。** 由 `1b2840a9`（P370）引入：它把两个 token 写进
`smoke.sh` §12b-pi 的段体，却没有同步 `section-paths.tsv` 那一行的 patterns。

```
bad: 段 12b-pi 读了它没声明的路径：token skills/teamsmith/tests/team-notify-knock-marker.mjs（源码行 9974）
bad: 段 12b-pi 读了它没声明的路径：token skills/teamsmith/extension/team-notify.ts（源码行 9974）
== 选段自检 ==  ok 11  bad 2  SKIP 1
```

反证（同一棵树上只补那一行的 patterns，源码不动，`/var/tmp/v101/t8/12bpi-widened.tsv`）：
`== 选段自检 == ok 12 bad 0 SKIP 1`。后果：`--check` 是 §36① 的前提、§36 在地板里，所以下一次 `--floor`
（含 CI 的正确性步）会在 §36① 红。修法是一行，但不在本 change 的写集，我没有改。

**(b) §33 / §3b / §6 在宿主上红，且与近期提交无关。** `--select 33` → `#5 33 … ✓0 ✗1`，rc=1，内部四条：

```
✗ TEAM_PROJECT=x → 5（refuse）（期望 [5]，实际 [4]）
✗ P266：适配器键的标记丢了：[ TEAM_AGENT_CMD ]
✗ 渲染器：dispatch --print 退出 0（期望 [0]，实际 [1]）
✗ 渲染器：dispatch 的 --model 不是第一个 / 之后（）
```

同一批断言在 `6f23252a`（P370 之前、PM 干净跑所用的那棵树；我用 `git archive 6f23252a | tar -x` 重建到
`/var/tmp/v101/pre370` 并 `git init` 一次）上、同一宿主里同样红：`--select 3b,6` → `#8 3b ✓46 ✗9`、
`#9 6 ✓4 ✗18`、`== 选段结果 == ✓121 ✗27`，rc=1。而 PM 在钉死镜像里对同一棵树跑整套是 `✓4525 ✗0`。
所以差异在**运行环境**（宿主 vs `pmskills-gates`），不在被检代码；根因本轮**没有诊断**（属另一件事）。

由此，我的 §36 选段跑是红的，逐条归因如下（这一条很重要：红不是 bfc 改变的部分造成的）：

```
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 参考 用时 1146s · ✓115 ✗6 SKIP3
== 选段结果 ==  ✓ 139  ✗ 6          rc=1
```

| 红 | 归因 |
|---|---|
| 36① `--check` 红 / 副本表未改就红 / 变体树注入前就红了 | (a) 的 12b-pi 表腐烂 |
| 36⑦ `--select 3b` 选集有红（`✓46 ✗9`）、`--select 6` 选集有红（`✓2 ✗10`） | (b) 的宿主红 |
| 36⑧ 产品面检出探针有失败（8 条） | 3 条 = (a)；5 条 = (b)（探针 `--select 12k,31` 经 needs 拉进 §33） |

`36⑨` 本身是绿的：`✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）`。

## 2 · 6.1 逐条的红→绿（我自己造的坏侧，不复用作者日志）

破坏一律在 `/var/tmp/v101/tree`（`rsync` 私有副本）与 `/var/tmp/v101/t8`（表副本）；每条改完立刻还原并用
`cmp` 证明与原件逐字节一致。细节与完整输出尾部在 `docs/team/reviews/behavior-focused-ci.md` §1–§5。

- **6.1-1 `⑧`（`gate-self-check` 行的读取）**：四个方向各一份表副本 —— 重复点名 → `bad: gate-self-check 行
  重复点名：0e`；点名前导段 → `bad: … 点名了前导段：0b`；拼错 → `bad: … 点名了不存在的段：61bb`；行在但为空
  → `bad: … 在但没有点名任何段` + `--floor` rc=2 拒绝空地板。反向：整行删掉不判红，`--floor` 的 key 从 128 变
  135（安全方向）。原表副本 `ok … 7 个 key`。
- **6.1-2 `⑨`（划分 + 只看 key）**：片号掺进表内下标 `(cksum+idx%2)%N` → `bad: 分片依赖了段在表里的位置…`，
  还原后 `ok: 分片只依赖 key …（889 次比较）`。附带发现：这个变异下**并集夹具仍全绿**（分片仍是划分），
  只有 ⑨ 抓得到它 —— V86 第一轮「只比 8 个位置」时是绿的，说明这条断言有真实分辨力。
- **6.1-3 `--slice` 分片与并集**：四份基线（floor 128 / paths 7 / floor+paths 129 / all 135）× N∈{2,3,4,5,6,8,12}
  = 160 次调用，逐 key 比对并集 == 基线、查跨片重复，全绿；未声明路径的兜底也按片切（`base=all`）；五种
  互斥/用法各 rc=2 点名。坏侧（片号比较 0 基→1 基）：并集少 35（N=2）/ 20（N=4）个 key 并点名。
- **6.1-4 正交**：坏侧（切片时丢掉 `--paths` 的路径选集）→ 四处同时红：`base=floor(期望 paths)`、并集缺 `36`、
  兜底 `base` 不是 `all`、兜底并集缺 `0e 0f 0g 0h 0i 36 61b`。还原后全绿。
- **6.1-5 `36⑨` 真的执行**：当轮 `✓ 36⑨ … ok 7 bad 0 skip 0`（不是 SKIP）；坏侧（工作流普通推送那条命令掉
  `--floor`）→ `✗ workflow-entry ①：容器命令不是 --floor --paths 形状`，`ok 6 bad 1`；还原 → `ok 7 bad 0`。

## 3 · 6.2 三种文件名的形状反例（没有跑整套地板）

做法：私有副本里造三个真文件（空格 / 引号+反斜杠 / 换行），`--floor --paths <那个真实字节串>` 问决策，并打印
「逐行读 / 未引用展开」会把它拆成什么、拆开后每段各自会得出什么决定：

```
ok: 形状 space → RUN        · 对照：单独喂同一串 → RUN
ok: 形状 quote+backslash → RUN
ok: 形状 newline → RUN      · 对照：按行读拆成 [skills/teamsmith/tests/shape] → RUN 与 [break.sh] → FULL
== harness shapes: FAIL=0 ==
```

坏侧（`claim_paths` 改成逐行展开）→ `bad: 形状 newline：rc=0 decision=FULL`（5 ok / 2 bad）；还原 → 7 ok / 0 bad。
边界写在记录里：引号与反斜杠在「引号内按字节传参」的实现下不分裂，分辨力弱于换行，所以我把它记为形状证据，
不当独立判据；没有跑整套地板（PM 已两次，一次干净 rc=0、一次改坏断言 rc=1）。

## 4 · 6.3 没有重跑的重段

§61b（4946 s/段）、`perf.sh` 性能套件、容器侧的 `--select 34c` 都没重跑，理由与既有证据：
`docs/team/reports/P326-dev.md`（61b 被声明、不在地板里；E4 两向）、`docs/team/reports/P316-dev.md`（性能套件
改成只打印参考读数）、`docs/team/reviews/V65.md`、`docs/team/reviews/V66.md`、`docs/team/reviews/V71.md`
（第二轮 `--select 36` 是 `✓121 ✗0 SKIP3`）。本轮的 §36 读数（`✓115 ✗6`）只作为「36⑨ 当轮真的执行」的证据。

## 5 · 交付物与边界

- 复验记录：`docs/team/reviews/behavior-focused-ci.md`（任务书 6.4；含判定、命令与输出尾部、未重测项的引用）。
- 受检树只多了这一份 review；其余改动都在 `/var/tmp/v101/`（驱动脚本、日志、私有副本），没有进树。
- 现场保留（--keep）：`/tmp/teamsmith-smoke-pm_skills-deb708fe.cCvhU5`（§36 的选段现场）、
  `/tmp/.teamsmith-p148-shape-probe.4160417`（形状探针现场，`nest-po2.log` 的摘录已拷到
  `/var/tmp/v101/evidence/`）。
- 未覆盖：`--floor` 的整体墙钟（同机有 PM 的整套在跑）；宿主与容器差异的根因（§1(b)）。
- 清单 6.1–6.4 未勾：结论交 PM，由 PM 勾选。
