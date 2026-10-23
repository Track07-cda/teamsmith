# behavior-focused-ci · 改变部分的独立复验

- 判定: **PASS（本 change 改变的部分成立）**；同时记下两处**与本 change 无关、在宿主上现在就是红**的读数
  （§0.2 / §0.3），处置交 PM。
- 复验者: verify（独立席位）· PM: pm · task: V101 · phase: verify · change: `behavior-focused-ci`
- 受检树: `.worktrees/verify` @ `75515580`（`main` 上去掉本轮两笔账本提交）；开跑前后
  `git status --porcelain --untracked-files=all` 均为空，除本文件与本任务的报告外未改动受检树。
- 范围（任务书 6.1–6.4）：只复验**改变的部分**。没有重跑整套门禁、没有拉起容器、没有触发远程 CI；
  清单条目**一条也没勾**（勾选自留 PM）。
- 破坏只在 `/var/tmp/v101/` 的私有副本里做；每次改完都用 `cmp` 证明与原件逐字节一致，再读一次绿。
  驱动脚本 `/var/tmp/v101/{mutants,slice-union,check-eighth}.sh`，日志 `/var/tmp/v101/*.log`（都在树外）。

## 0 · 结论

### 0.1 四条复验项全部成立

| 复验项 | 断言 | 我造的坏侧 | 红时点名 | 还原后 |
|---|---|---|---|---|
| 6.1-1 | `--check` ⑧：`gate-self-check` 行的读取 | 表副本四个腐烂方向（重复点名 / 点名前导段 / 拼错 key / 行在但为空） | 各自 `bad:` 点名 key 与文件行号 | 原表副本 `ok … 7 个 key` |
| 6.1-2 | `--check` ⑨：分片是地板的精确划分，且规则只看 key | 片号改成 `(cksum(key)+下标奇偶)%N`（位置污染） | `bad: 分片依赖了段在表里的位置…` | `ok: 分片只依赖 key …（889 次比较）` |
| 6.1-3 | `--slice` 的分片与并集（N∈{2,3,4,5,6,8,12}） | 片号比较 0 基→1 基（第 N 片永远空） | 并集少 35 / 20 个 key 并点名缺的 key | 160 次切片调用全绿 |
| 6.1-4 | `--floor`/`--slice`/`--paths` 正交 | 切片时丢掉 `--paths` 的路径选集 | `base=floor(期望 paths)`、并集缺 `36` | 四份基线 × 7 个 N 全绿 |
| 6.1-5 | `36⑨` 真实执行（不再 skip） | 工作流那一步掉 `--floor` | `workflow-entry` `✗` 点名命令形状 | `✓ 36⑨ … ok 7 bad 0 skip 0` |

### 0.2 与本 change 无关、现在就红的两处（同一棵树上量到的）

**(a) `--check` 的两条真红：`12b-pi` 行了读了没声明的路径。**

```
bad: 段 12b-pi 读了它没声明的路径：token skills/teamsmith/tests/team-notify-knock-marker.mjs（源码行 9974）—— 补进该行的 patterns
bad: 段 12b-pi 读了它没声明的路径：token skills/teamsmith/extension/team-notify.ts（源码行 9974）—— 补进该行的 patterns
== 选段自检 ==  ok 11  bad 2  SKIP 1
```

归因：这两个 token 是 `1b2840a9`（P370）加进 `smoke.sh` §12b-pi 段体的，同一笔提交没有动
`section-paths.tsv` 的 12b-pi 行（`git merge-base --is-ancestor 1b2840a9 HEAD` 为真；PM 的干净整套跑
`6f23252a` 是它的祖先，见 `git log --oneline 6f23252a..HEAD` —— 区间里唯一的产品提交就是它）。
反证：同一棵树上只把这两个 token 补进那一行 patterns（表副本 `/var/tmp/v101/t8/12bpi-widened.tsv`，源码不动），
`--check` 得 `ok 12 bad 0 SKIP 1`（`/var/tmp/v101/t8/widened.log`）。所以这不是 ⑧/⑨ 新规则的误报，是既有的
「段读了没声明的路径」规则抓到的真事，一行改动即可修。

后果：`--check` 是 §36① 的前提、而 §36 在地板里，所以下一次 `--floor`（含 CI 的正确性步）会在 §36① 红。

**(b) §33 / §3b / §6 在**宿主**上红，且不归因于任何近期提交。**

```
#5 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） · ✓0 ✗1 SKIP0    （--select 33，rc=1）
     ✗ TEAM_PROJECT=x → 5（refuse）（期望 [5]，实际 [4]）
     ✗ P266：适配器键的标记丢了：[ TEAM_AGENT_CMD ]
     ✗ 渲染器：dispatch --print 退出 0（期望 [0]，实际 [1]）
     ✗ 渲染器：dispatch 的 --model 不是第一个 / 之后（）
     config-cli.sh 内部收口：== 结果 ==  ✓ 327  ✗ 4
```

同一批断言在 `6f23252a`（P370 之前、PM 的干净跑所用的那棵树）上、同一个宿主里**同样红**
（`/var/tmp/v101/pre370` 是用 `git archive 6f23252a | tar -x` 重建的私有树，`git init` 一次让 §0d 有仓库可查）：

```
#8 3b · git 归 PM … · ✓46 ✗9 SKIP0          （--select 3b,6，rc=1）
#9 6 · dispatch … · ✓4 ✗18 SKIP0
== 选段结果 ==  ✓ 121  ✗ 27
```

而 PM 在钉死镜像里对同一棵树 `6f23252a` 跑整套是 `✓4525 ✗0`。所以差异在**运行环境**（宿主 vs
`pmskills-gates` 镜像），不在被检的代码；本轮没有诊断到具体根因（不属本任务范围），只给出读数与边界。
它对本次复验的结论没有影响：§33/§3b/§6 都不是 `behavior-focused-ci` 的写集。

### 0.3 我的 §36 选段跑为什么是红的（逐条归因）

`bash skills/teamsmith/tests/smoke.sh --select 36 --keep`（5 段：0 0b 0c 0d 36）：

```
#5 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 参考 用时 1146s · ✓115 ✗6 SKIP3 · ticks 124
== 选段结果 ==  ✓ 139  ✗ 6          rc=1
```

6 条红的身份与归因：

| 红 | 归因 |
|---|---|
| 36① `--check` 红 / 副本表未改就红 / 变体树注入前就红了 | §0.2(a) 的 12b-pi 表腐烂 |
| 36⑦ `--select 3b` 的选集有红（`✓46 ✗9`）、`--select 6` 的选集有红（`✓2 ✗10`） | §0.2(b) 的宿主红（§3b / §6） |
| 36⑧ 产品面检出探针有失败（8 条） | 3 条 = §0.2(a)；5 条 = §0.2(b) 的 §33 红（探针 `--select 12k,31` 经 needs 拉进 §33，`/var/tmp/v101/evidence/nest-po2-excerpt.log`） |

`36⑨`（本 change 的核心改变）在这轮里是绿的：`✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）`。

## 1 · 6.1-1 `--check` ⑧：`gate-self-check` 行的四个腐烂方向

只换表副本（`--table <副本> --check`），源码与真表不动（`/var/tmp/v101/eighth.log`）：

```
ok: ⑧ 基准（原表副本）：gate-self-check 行有效，7 个 key
ok: ⑧ [重复点名 0e] → --check rc=1 且点名：bad: gate-self-check 行重复点名：0e
ok: ⑧ [点名前导段 0b] → --check rc=1 且点名：bad: gate-self-check 行点名了前导段：0b（前导段永远跑，不是可声明的自检段）
ok: ⑧ [拼错 61b→61bb] → --check rc=1 且点名：bad: gate-self-check 行点名了不存在的段：61bb（拼错/陈旧的 key 会静静地换掉普通入口）
ok: ⑧ [整行删掉] → 不判红，按「每个段都在地板里」的安全方向（默认多跑）
  · 同一张表的 --floor：keys=135 / sections=135（= 全部段）
ok: ⑧ [行在但为空] → --check rc=1 且点名：bad: gate-self-check 行在但没有点名任何段（空声明，/var/tmp/v101/t8/empty.tsv:17）
  · 空声明的 --floor：rc=2 / section-select: --floor：空地板 —— gate-self-check 行（…:17）在但没点名任何段
```

两向都成立：点名一个**不存在**的 key 红并点名 key；把一行 key **删掉**则那一段回到地板（`--floor` 的 key
数从 128 变 135），即「声明是离开地板的唯一途径」，两个方向都按规格落在安全侧。

## 2 · 6.1-2 `--check` ⑨：分片是精确划分，规则只看 key

改坏（私有副本）：`slice_of_key` 的 `printf '%s' "$(( c % n ))"` → `$(( (c + idx % 2) % n ))`，即把段在表里的
下标掺进片号：

```
  · --check rc=1  ok 10  bad 3 SKIP 1
13:bad: 分片依赖了段在表里的位置（按位置轮转会让「第 k 片」随行的增删漂移）：N=2：key 0 在 0 号位是第 2 片、在第 1 位却是第 1 片
  · 并集夹具（floor N=2,4）在位置污染下：10 ok / 0 bad —— 分片仍是划分，只有 ⑨ 抓得到它
  · 还原：section-select.sh 与原件逐字节一致
  · --check rc=1  ok 11  bad 2 SKIP 1（= 只剩 §0.2(a) 的两条）
ok: 分片只依赖 key：(a) 表首 key 在全部 128 个基线下标 × 7 个 N 上与 0 号位同片（889 次比较）；(b) 另 3 个 key 各比首尾两点 × 7 个 N；(c) 每个 key 各比首尾两点（N=4）
```

这条变异的分辨力值得记一句：位置污染下「每段恰好进一片」照样成立（并集夹具 10 ok / 0 bad），只有 ⑨ 的
「同一 key 在任何下标上都必须同片」抓得到它——V86 第一轮「只比 8 个位置」时这类变异是绿的，所以这条断言
不是摆设。`889 = 127 个非零下标 × 7 个 N`（0 号位是参照点，不参与比较），与读数自洽。

## 3 · 6.1-3 `--slice` 的分片与并集（N∈{2,3,4,5,6,8,12}）

四份基线 × 7 个 N = 160 次切片调用，逐 key 比对「各片 own 的并集 == 未切片的决策集」，并查跨片重复
（`/var/tmp/v101/union-base.log`、`union-all.log`）：

```
base.counts floor=128 paths=7 floorpaths=129 all=135
ok: floor N=2 … N=12          128 个 key 的 own 并集 == 基线（逐 key 比对），无重复、无遗漏、base=floor
ok: paths N=2 … N=12          7 个 key …
ok: floor+paths N=2 … N=12    129 个 key …
ok: all N=2 … N=12            135 个 key …（不带决策只给 --slice = 全集按片切，base=all）
ok: 未声明路径（不切片）→ decision=FULL（ci/does-not-exist-thing.sh ← 没有任何行声明它（也不在豁免类））
ok: 未声明路径 + --slice → base=all（兜底也按片切）
ok: 未声明路径兜底 N=3：own 并集 == 全部 135 段
ok: 互斥/用法：[--floor --select 36] → rc=2（--select 与 --floor 不同用）
ok: 互斥/用法：[--select 36 --slice 1/2] → rc=2（--slice 只与 --floor / --paths / 不带决策（全集）同用）
ok: 互斥/用法：[--slice 0/4] / [--slice 5/4] / [--slice 4] → rc=2（各自点名）
```

改坏（差一）：`[ "$sh" = "$((SLICE_K - 1))" ]` → `[ "$sh" = "$SLICE_K" ]`：

```
  · 并集夹具：7 ok / 3 bad
bad: floor N=2： 并集≠基线（缺: 0b 0c 0d 10b … ）（并集 93 / 基线 128）
bad: floor N=4： 并集≠基线（缺: 0b 0c 11b2 … ）（并集 93 / 基线 128）
bad: 兜底分片的并集 ≠ 全集（缺: 0b 0c 10c … ）
  · 还原：section-select.sh 与原件逐字节一致
```

`own 并集 == 基线` 这个判据的分辨力也在这里得到验证：它抓得住「片少了一块」，抓不住「片怎么分」（后者归 ⑨）。

## 4 · 6.1-4 `--floor` / `--slice` / `--paths` 正交

读数是 §3 里的 `floor+paths`（129 = 地板 128 + 路径点到的 `36`）与「未声明路径兜底也按片切（base=all）」。

改坏（私有副本）：`do_floor` 里给路径选集加 `&& [ "${SLICE_N:-0}" -eq 0 ]`，即「切片时不再并入 `--paths`」：

```
  · 并集夹具：6 ok / 4 bad
bad: floor+paths N=2： k=1 base=floor(期望 paths) k=2 base=floor(期望 paths) 并集≠基线（缺: 36 ）（并集 128 / 基线 129）
bad: floor+paths N=4： k=1..4 base=floor(期望 paths) 并集≠基线（缺: 36 ）（并集 128 / 基线 129）
bad: 未声明路径 + --slice 的 base 不是 all（floor）
bad: 兜底分片的并集 ≠ 全集（缺: 0e 0f 0g 0h 0i 36 61b ）
  · 还原：section-select.sh 与原件逐字节一致
```

三种决定（地板 / 路径 / 兜底）与切片正交这四件，坏一处就有四处同时点名。

## 5 · 6.1-5 `36⑨` 的真实执行（不再 skip）

当轮读数（§0.3 的整段跑）：`✓ 36⑨ CI 入口：workflow-entry 三条行为全绿（ok 7 bad 0 skip 0）`——不是 SKIP。

坏侧：把 `.github/workflows/gates.yml` 普通推送那条命令里的 `--floor` 去掉（私有副本），跑同一套
`workflow-entry`：

```
  · workflow-entry.sh --tree 副本（改坏）：rc=1
      ✗ workflow-entry ①：容器命令不是 --floor --paths 形状（实际：set -u; shopt -s nullglob; mkdir -p "$TMPDIR"; openspec validate --all --strict || exit $?; bash skills/tea…
== workflow-entry == ok 6 bad 1 skip 0
  · 还原：gates.yml 与原件逐字节一致
  · workflow-entry.sh --tree 副本（还原后）：rc=0 → == workflow-entry == ok 7 bad 0 skip 0
  · workflow-entry.sh --tree 真树（未改坏）：rc=0 → == workflow-entry == ok 7 bad 0 skip 0
```

## 6 · 6.2 少量针对性反例（`--floor --paths` 的形状，不复用作者的日志）

做法（任务书允许的做法与边界）：**不跑整套地板**，只在私有副本里造三个真文件，用 `--floor --paths <那个字节串>`
问决策，并打印「逐行读 / 未引用展开」会把这个字节串拆成什么、拆开的每段各自会得出什么决定
（`/var/tmp/v101/shapes-real.log`）：

```
ok: 形状 space：真实字节串（ s k i l l s / t e a m s m i t h …）→ decision=RUN（被 tests/* 声明）
      |skills/teamsmith/tests/shape space name.sh|        → 单独喂：RUN
ok: 形状 quote+backslash：真实字节串 → decision=RUN
      |skills/teamsmith/tests/shape q"uote\back\slash.sh| → 单独喂：RUN
ok: 形状 newline：真实字节串 → decision=RUN
      |skills/teamsmith/tests/shape|  → 单独喂 [skills/teamsmith/tests/shape]：RUN
      |break.sh|                      → 单独喂 [break.sh]：FULL
ok: 地板（声明行原样）里没有 61b（它被 gate-self-check 点名）
ok: 61b 从声明行删掉 → 回到地板（默认方向 = 在基线里）
ok: 声明行删掉 61b 后 --check 仍绿（6 个 key），与地板读数一致
ok: 未声明路径 ci/no-such-path-here.sh → FULL（兜底不可绕过）
== harness shapes: FAIL=0 ==
```

换行那一条是关键读数：同一个字节串按行读会变成两条路径（`…/shape` 与 `break.sh`），而后者会单独得到
`FULL`——因此「按行读文件」的实现在这里必然与真实现分道扬镳。坏侧（把 `claim_paths` 改成逐行展开）：

```
bad: 形状 newline：rc=0 decision=FULL（期望 RUN：真实字节串被 tests/* 声明）
  · 改坏副本：5 ok / 2 bad      · 还原后：7 ok / 0 bad
```

引号与反斜杠两种在「引号内按字节传参」的实现下是 `RUN`；这两种形状的分辨力弱于换行（未引用展开的
分裂只会发生在空白上），所以我把它记为「形状证据」而不是单独的判据——这正是任务书说的「形状证据 + 一次
小选段」。

## 7 · 6.3 没有重跑的重段（引用既有证据）

没有重跑，原因与出处：

- **§61b**（`docs/team/reports/P326-dev.md` 记它单段在 CI 记 4946 s）：它被 `gate-self-check` 行点名、因此
  **不在地板里**（本轮读数：`--floor` 的 key 里没有 `61b`，见 §6）；「不在普通推送里跑」正是本 change 要的形状。
  它的行为证据见 `docs/team/reports/P326-dev.md`（E4：删声明 → 回到地板、路径点到 → 选回来）与
  `docs/team/reviews/V90-verify.md`（挂住判据的进度证据，两轮独立复看）。
- **性能套件 `perf.sh`**：P316 之后它只测量、只打印、退出码 `0/3`，证据是 `docs/team/reports/P316-dev.md`；
  `docs/team/reviews/V65.md`（P321 的增量，安装与 signal-gate 的既成读数）是它最近一次的独立复核。
  本轮不重测，也没有产生新读数。
- **容器侧（`--select 34c` 的 keep 回收探针）**：`docs/team/reviews/V66.md`（独立 verify 席位在一次性容器里
  `✓49 ✗0`）。本轮不拉容器（任务书：不重跑重段；PM 已跑整套）。
- **§36 的反例对与探针**：`docs/team/reviews/V71.md` 第二轮记 `--select 36` 整段 `✓121 ✗0 SKIP3`。本轮的
  §36 读数（`✓115 ✗6`）只作为「36⑨ 当轮真的执行」的证据，不冒充整套。

## 8 · 未覆盖与边界

- `--floor` 的整体墙钟本轮**没有测量**（同机还有 PM 的整套在跑，我只做选段与纯逻辑）；「地板在大机器上多快」
  在本记录里没有新读数。
- §0.2(a) 的修法（把两个 token 补进 12b-pi 行的 patterns）不在本 change 的写集，我不改；它会让本 change 的
  主路径（`--floor`，含 CI）在 §36① 红，建议在归档前先修掉、并用一次 `--check` + `--select 36` 复看。
- §0.2(b) 的宿主红没有诊断到根因（容器绿、宿主红）；它不影响本 change 的判定，但会让我在宿主上跑 §36 时
  反复看到 36⑦/36⑧ 红——PM 若要一条可在宿主上复现的绿灯，需要先决定这是「环境不许跑这套」还是「宿主上真有
  一个产品问题」。
- 清单 6.1–6.4 我一勾未勾。
