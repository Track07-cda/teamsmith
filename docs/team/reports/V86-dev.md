# V86 · P346 的独立验收：切片无损、并集断言有牙、两条自报风险

agent: dev   status: **PASS**（候选 `1a54477c`；五项全部成立，四条读数与作者报告不同，见「发现」）   time: 2026-10-21
branch: `task/V86-shard-parallel-verify`（local 模式，未 push，未合并；本分支 = 基点 `30c1cd69` + 本报告）   PR/MR: -
受检：`1a54477c`（P346 的五个提交），作者报告 `docs/team/reports/P346-dev2.md`。
受检树怎么来的：`git archive 1a54477c | tar -x -C /var/tmp/v86 --one-top-level=cand`（35 MB，无 `.git`；本分支的树
不含 P346，所以下面每条命令都在这个私有副本里跑，复验照同一条命令重建即可）。
任务书里 `agent: dev-bob` 与 PM 本轮派单的席位（`dev`）不一致；报告按派单写成 `V86-dev.md`，没有写别人的文件。

**结论**：切片的覆盖是无损的（三个 N 各自逐字对上，128/128），`--check ⑨` 的②真的只由它抓位置依赖，
coverage 作业在四种坏形状下都 rc≠0 并逐个 `::error::` 点名，`smoke.sh` 的 135 段正文一个字节没动。
**45.4 分这个估算我认可**（自己按同一份段账本加出来正好 45.4，余量 14.6 分；算上构建与 checkout ≈ 48.5 分，余量约
11.5 分）。**N 现在不要改**——第一次真跑完再看；真要拉余量就把矩阵改成 5 片（最慢 37.5 分，代价是计费分钟 +45 %）。
下面四条读数与作者报告不一致，其中两条要改文件（F1 注释里的时间、F2 四份镜像构建），一条是断言的证明边界（F3），
一条是噪声（F4）。

## 1 · 覆盖无损：三个 N 各自逐字对上，128/128

规则自己重写了一遍（`/var/tmp/v86/independent.py`：POSIX `cksum` 的 CRC-32/ISO-HDLC 用 Python 实现，不 source
选择器、不 import 它的任何函数），再把选择器写出的 own 清单与自己的逐字比。

地板声明集也自己数：表 135 行 key，`# gate-self-check:` 在第 17 行点名 7 个（`0e 0f 0g 0h 0i 36 61b`）→ 地板 128 段。

```
$ python3 /var/tmp/v86/independent.py          # 哈希先自证：135 个 key 全部与系统 cksum 一致
表：135 行 key；gate-self-check 行在第 17 行，点名 7 个：0e 0f 0g 0h 0i 36 61b
地板声明集（独立推导）：128 个 key
哈希自证：135 个 key 全部与系统 cksum 一致
N= 2：各片 own = [66, 62]  合计=128  OK      N= 3：[45, 43, 40]   OK
N= 4：各片 own = [35, 31, 31, 31]  合计=128  OK    N= 5：[33, 28, 27, 18, 22]  OK
N= 6：[23, 20, 20, 22, 23, 20]  OK          N= 8：[17, 16, 17, 15, 18, 15, 14, 16]  OK
N=12：[11, 14, 9, 14, 13, 9, 12, 6, 11, 8, 10, 11]  合计=128  OK
```

逐字比对（13 份清单，N=3/4/6 每片一份；`cmp` 全部相同，行数 45/43/40、35/31/31/31、23/20/20/22/23/20）：

```
$ for n in 3 4 6; do for k in $(seq 1 $n); do cmp -s /var/tmp/v86/out/N$n-k$k.keys /var/tmp/v86/py-N$n-k$k.keys \
    && echo "N=$n k=$k cmp 逐字相同 ($(wc -l < /var/tmp/v86/py-N$n-k$k.keys) 行)"; done; done
N=3 k=1 cmp 逐字相同 (45 行) … N=6 k=6 cmp 逐字相同 (20 行)          # 13/13 全部相同
```

并集 vs `--floor`（三个 N 都做，`comm` 两边都空、计数 128/128）：

```
$ bash section-select.sh --floor | awk -F'\t' 'NF>=2{print $1}' | sort > /var/tmp/v86/floor.keys   # 128 行
$ for n in 3 4 6; do cat /var/tmp/v86/out/N$n-k*.keys | sort -u > /var/tmp/v86/union-N$n.keys
    echo "N=$n 并集 $(wc -l < /var/tmp/v86/union-N$n.keys) 段 vs --floor $(wc -l < /var/tmp/v86/floor.keys) 段"
    echo -n "  comm -3：[$(comm -3 /var/tmp/v86/union-N$n.keys /var/tmp/v86/floor.keys | tr '\n' ' ')]"; done
N=3 并集 128 段 vs --floor 128 段    comm -3：[]
N=4 并集 128 段 vs --floor 128 段    comm -3：[]
N=6 并集 128 段 vs --floor 128 段    comm -3：[]
```

「对任意 N 成立」这句我按 `--check ⑨` 的 N ∈ {2,3,4,5,6,8,12} 全跑了一遍（见 2 的负对照行）：每片非空、无重复、
无遗漏，合计都等于 128。切片也确实是「只按 key」的：同名 key 换位置片号不变。

## 2 · `--check ⑨` 的三条断言有牙（私有副本里的两次变异）

三份私有副本：`cp -a /var/tmp/v86/cand /var/tmp/v86/{ctrl,flipA,flipB}`，只改副本里的 `slice_of_key` 一行。

```
$ bash skills/teamsmith/tests/section-select.sh --check        # 负对照（未变异）
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：128 段，每片非空、无重复、无遗漏）
ok: 分片只依赖 key（不是基线下标）：同名 key 换 4 个位置 × 7 个 N 后片号不变
== 选段自检 ==  ok 12  bad 0  SKIP 1        rc=0
```

**变异 A（哈希退化，全落第 1 片）**：`printf '%s' "$(( c % n ))"` → `printf '%s' 0`。

```
bad: 分片不是地板的精确划分：N=2：第 2 片是空的（分片退化）（共 33 处，首条如上）
== 选段自检 ==  ok 11  bad 1  SKIP 1        rc=1
```

**变异 B（按位置轮转）**：同一条 `printf` → `"$(( idx % n ))"`。

```
bad: 分片依赖了段在表里的位置（按位置轮转会让「第 k 片」随行的增删漂移）：N=2：key 0 在第 0 位是第 1 片、在第 127 位却是第 2 片
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：128 段，每片非空、无重复、无遗漏）     ← ① 在 B 下面仍是绿的
== 选段自检 ==  ok 11 bad 1 SKIP 1          rc=1
```

B 这一行是重点：位置轮转**仍然是一个精确划分**（每片非空、无重复、无遗漏），所以①抓不到它，**只有②抓得到**。
「规则只依赖 key」这条断言不是装饰。

**F3 · 但②的证明范围是采样，不是全部位置**：变异 C 让片号只在第 50 位漂移
（`if [ "$idx" = "50" ]; then printf '%s' "$(( (c + 1) % n ))"`），其余位置正常。

```
$ bash skills/teamsmith/tests/section-select.sh --check        # 变异 C
ok: 分片是地板的精确划分（…）   ok: 分片只依赖 key（…换 4 个位置…）   ok: 表里每一行的 key 都能被哈希（…）
== 选段自检 ==  ok 12  bad 0  SKIP 1        rc=0                ← 绿的
```

②比较的是 4 个低位（基线下标 0..3）与 4 个高位（127..124）× 7 个 N，中间位置的漂移它看不见；coverage 作业用
同一条规则重算，也看不见规则自身的错。影响有限（规则是一行代码，真正会犯的错——退化与按位置轮转——两个都被抓），
但「②证明它守的是『规则只依赖 key』」这句要读成「在这 8 个位置上成立」。要改成全位置证明，代价是 128 个下标 × 7 个 N
的比较（选择器里 n² 很小，`--check` 现在已经是秒级），**这是可以随手补的，我建议补**——它把一句采样结论换成一句真结论。

## 3 · coverage 作业真的会红（四种坏形状 + 两个正形状，全部实跑）

`slice-coverage.sh` 不吃矩阵语义、只认 `.keys` 文件，所以本地造形状就够：`/var/tmp/v86/cov/{floor-good,floor-missing,
floor-narrow,all-good,n3}`（每片 `shard-k.keys` + `shard-k.status`，都是选择器自己写出来的真清单）。

```
$ bash skills/teamsmith/tests/slice-coverage.sh --keys-dir … --matrix-file .github/workflows/gates.yml --shards-result …
good    rc=0  ::error::=0   汇总 == 分片覆盖 == ok 7 bad 0          # 正形状：4 片齐全、success
allgood rc=0  ::error::=0   汇总 == 分片覆盖 == ok 7 bad 0          # 正形状：base=all（定点不可解析的兜底）
missing rc=1  ::error::=64  汇总 == 分片覆盖 == ok 4 bad 3          # 片 3 工件缺失 + status=cancelled
narrow  rc=1  ::error::=2   汇总 == 分片覆盖 == ok 5 bad 2          # 片 2 清单被删掉一段
failed  rc=1  ::error::=1   汇总 == 分片覆盖 == ok 6 bad 1          # 4 片齐全但矩阵 result=failure
drift   rc=1  ::error::=34  汇总 == 分片覆盖 == ok 4 bad 34         # 真跑 3 片（k/3），矩阵写着 4 片
```

点名长这样（缺片那条，64 条 annotation 的构成：1 条矩阵结果 + 1 条片级 + 31 条「份额没跑到」+
31 条「没有任何一片 own 它」）：

```
::error::门禁矩阵的结果是 [cancelled]（不是 success）：任一片失败或被取消，这条覆盖断言就必须红
::error::片 3/4（作业结果 [cancelled]）：没有 key 清单（…/shard-3.keys）—— 它 own 的 31 段这次没有被任何片跑到
::error::段 [0d]：（片 3/4 的份额）没有跑到
::error::段 [2]：（片 3/4 的份额）没有跑到
…
::error::段 [0d]：没有任何一片 own 它（这次运行的覆盖缺口）
```

收窄那条（删的是片 2 清单里的第 22 段），三个信号同时到：

```
::error::片 2/4：清单与重算不一致（规则算 31 段，清单 30 段；首个差异 22）—— 某片静默收窄会让并集对上、覆盖对不上
  ✗ 片 2/4：清单 ≠ 重算（31 vs 30）
::error::段 [22]：没有任何一片 own 它（这次运行的覆盖缺口）
```

失败/取消那条只给聚合行（`::error::门禁矩阵的结果是 [failure]…`，1 条）：这是对的——**失败的片不阻止 coverage 判定，
它只是把结论拉到红**；哪一段红要去片自己的日志里看。反过来，缺清单的片一定按重算逐段点名，不会只留一句「少了片」。

**F4（噪声，不改也行）**：缺片时同一段会被点两次——「（片 3/4 的份额）没有跑到」与「没有任何一片 own 它」
各点名全部 31 段，N=4 下共 64 条 annotation。两条信息其实是同一件事的两个角度（谁该跑它 / 谁都没跑它），
合并成一条就够。要更省，把段级展开收进一枚 `::group::`；这属于阅读体验，不是覆盖。

## 4 · `smoke.sh` 只加管线没改断言，`slice`/`all` 也没把地板拉长

改动只有 4 个文件 `+627/−38`（`gates.yml`、`section-select.sh`、`slice-coverage.sh`、`smoke.sh`）；`section-paths.tsv`
一个字节没动，所以地板声明集仍是 128。

段正文逐字节比（自己把两份 smoke.sh 按 `section "` 切开，不靠 diff 的行号猜）：

```
段正文起点：旧 1518 行 / 新 1543 行（段数 旧 135 新 135）
段 id 集合相同: True
段正文有差异的段: 无
9 个 hunk：@@ -121 @@  -124,0 +125 @@  -143,0 +145,7 @@  -150 +158 @@  -216 +224 @@  -226 +234,3 @@
            -228 +238,5 @@  -254 +268 @@  -277,0 +292,11 @@     ← 全部落在 121–302 行，段正文之前
```

`slice`/`all` 的核：例外清单在 `smoke.sh:268` `''|floor|all|slice|prologue|needs:*|coupled:*) ;;`。要证的是「切片
不会把段标成『改动直接点到』」，因为那会把 7 分钟的 `tests/panel-b2.sh`（431 s 实测）挂进地板。

```
$ bash section-select.sh --floor --slice 2/4 | sed -n 's/^reason=.* ← //p' | tr ',' '\n' | sort -u
floor  needs:…  prologue  slice                       ← --slice 1/4 / 2/4 / 3/3 / 1/6 全都是这个集合
$ bash section-select.sh --floor --paths odo-undeclared.txt --slice 2/4 | …      # base=all 兜底
all  needs:…  prologue  slice
$ bash section-select.sh --floor --paths skills/teamsmith/tests/ledger-ban.sh --slice 1/4 | …   # 正对照
40  skills/teamsmith/tests/ledger-ban.sh, floor, slice        ← 真路径仍算直接点到（与不切片时同义）
```

集合里每一个 token 都在例外清单上 → 无路径的切片运行 `SELECT_DIRECT_KEYS` 为空。**这一条是承重的**：key 38 的 own
在片 4/4，若 `slice`/`all` 不豁免，片 4 就会把 431 s 的慢夹具算成「直接点到」→ 45.4 + 7.2 = 52.6 分，离 60 分只剩 7.4 分。

CI 入口本身也跑了一次可执行检查（`workflow-entry.sh` 执行的是工作流那段 `run:` 原文，docker 是记录 argv 的桩）：

```
$ TMPDIR=/var/tmp/v86/wfentry bash skills/teamsmith/tests/workflow-entry.sh --tree /var/tmp/v86/cand
✓ ① 有效基点时这一步退出 0        ✓ ① 容器命令带 `--floor` 与 `--paths "$@"`
✓ ① 3 条特殊文件名（换行/空格/引号+反斜杠）逐字节到达容器参数（cmp 一致）
✓ ② 基点不可解析（空 / 全零 / 不存在的 sha）→ ::warning:: + 正向确认完整入口（openspec + smoke.sh --keep，无 --floor）
✓ ③ 容器执行失败（stub rc=5）→ 这一步非 0（rc=5），失败没被吞
== workflow-entry == ok 7 bad 0 skip 0
```

那段桩不执行容器里的脚本，所以新增的「把 `.keys` 拷到 /artifacts」一行我单独按原文跑了两形状（`set -u; shopt -s
nullglob` 那段一字不改，只把 `/artifacts` 换成本地目录）：有 1 份 `.keys` → 写出 `shard-2.keys`、rc=0；一份都没有 →
`::warning::shard 3/4 wrote no key list (…/*.keys)`、rc=0（不红，留给 coverage 判）。

## 5 · 两条自报风险的判断

**① 45.4 分：认可，数字对得上，但作者有第二处时间说法与它矛盾。** 自己按段账本
`/var/tmp/p327/gate-tmp/teamsmith-smoke-pm_skills-deb708fe.ShhhQE/sections.tsv`（121 段 / 5324 s）加一遍——
每片的运行集取 `own ∪ borrowed`（借来的段照跑，所以必须算），账本里没有的段按作者同一口径 44 s 补：

```
N=3：30.7 / 33.9 / 57.1        最慢 57.1
N=4：23.2 / 34.6 / 18.5 / 45.4 最慢 45.4  ← 片 4 账本实测 2633 s + 64,65 两段各 44 s = 2721 s = 45.35 分
N=5：24.4 / 18.8 / 28.8 / 24.8 / 37.5   最慢 37.5
N=6：20.2 / 28.8 / 17.7 / 11.4 / 11.6 / 44.0  最慢 44.0
```

段执行量：N=4 各片运行集 45/51/43/46 = 185 段 vs 地板 128 段（+44.5 % 的段重复，计费墙钟 116.5 分 vs 88.7 分 = +31 %）。
45.4 是**段耗时**，真实墙钟还要加镜像构建 59 s（P322 的实测）与 checkout+openspec ≈ 2 分 → 约 48.5 分，余量 11.5 分。

**F1**：`gates.yml` 的头注释写着「wall clock drops to the slowest shard (**~19–37 min**)」，而本任务自己的测算是
45.4——同一份改动里两句话互相矛盾，读者信的是注释。要改成 19–45（或直接引用实测表），并把「余量 15 分」改成实际值。

**② 矩阵没真跑过，第一次会怎么坏——三条，都是我在本地按同样形状实跑出来的**：

1. **作业数不是 4**（`include`/`exclude`、有人改了列表、排队中的 run 用的还是旧文件）：coverage 只用文件里的
   `slice:` 列表定 N，真跑的片若按别的 N 切，清单与重算立刻不一致——实测 `drift`：`rc=1`，34 条
   `::error::`，逐片点名「规则算 35 段，清单 45 段」。多出来的 `shard-5.keys` 不会被读（它不在列表里），但红已经发生了。
2. **`needs` 语义**：`needs: [gates]` 是矩阵的聚合结果。任一 shard 失败 → `failure`；被取消 → `cancelled`；
   gates 被跳过 → `skipped`。三种都不是 `success`，coverage 一律红（实测 `failed` 形状 rc=1）。`if: always()`
   保证 coverage 不会被 `needs` 跳过——失败的片无法用「跳过 coverage」掩盖覆盖缺口。
3. **失败分片不会阻止 coverage 判定**：它只把结论拉到红。片在写清单之后才失败（例如某段红）时，清单齐全 →
   并集对得上，红只来自那条聚合行（实测 1 条 annotation）。所以「哪一段红」要打开片日志，「哪一段没跑到」在 coverage 里。

**F2（要改文件）· 四份镜像构建，与 D60 #1 的裁定相反**：每个矩阵实例都在自己的 VM 上从零
`docker build -f ci/Containerfile`（workflow 里没有任何 `actions/cache` / buildx `--cache-from`）。P130 §B 记的是
「每次运行的镜像构建 **1 次**」，并且带过一条翻转断言（「复制一份镜像构建步骤 → bad 镜像构建步骤 2 个（期望 1）」）；
D60 #1 的裁定原文是「两个 gate 作业**只构建一次**镜像」。P346 把 1 次变成 4 次（每次 59 s），同时那条结构断言在
今天的测试树里已经不存在（`grep -rn 'docker build' skills/teamsmith/tests/` 无命中）——所以这条不变量现在没人守。
计费 +3 分钟、每片墙钟 +1 分钟；`gates.yml` 里「the budget covers both suites + **one build**」这句随之变成假话。

## 发现（要做的三件事 + 一条可随手补的）

| # | 改什么 | 依据 |
|---|---|---|
| F1 | `gates.yml` 头注释「~19–37 min」改成实测（19–45 或直接引表） | 本任务自己的 45.4；两句话在同一份改动里矛盾 |
| F2 | 4 份构建：加 GHA 缓存/buildx `--cache-from`，或把构建收进一个作业再分发；并把注释里「one build」改对 | D60 #1、P130 §B 的实测与断言；`gates.yml` 构建步没有缓存 |
| F3 | `--check ⑨` 的②改成全位置比较（128 下标 × 7 N），或把话说成「8 个位置」 | 变异 C 下 `--check` 仍 rc=0 |
| F4 | （可选）缺片时 annotation 从 64 条压到「片级 1 条 + 段落 group」 | 同一段被点名两次 |

## 交付面上跑过什么、没跑什么

本报告是唯一改动（`docs/team/reports/V86-dev.md`），所以只有「管这份文件的那一段」值得跑：

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 40
== 选段 == decision=RUN · 运行 5/135 段 · 未跑 130 段
== 选段结果 ==  ✓ 65  ✗ 0                      rc=0（账本禁令含本报告在内，跑完树仍干净）
$ ~/.bun/bin/openspec validate --all --strict   → Totals: 21 passed, 0 failed
```

两处环境事实，留作复验时对表：`openspec` 不在这台机器的 PATH 上（绝对路径 `~/.bun/bin/openspec` 可跑），
所以 `gates.yml` 里那条 `openspec validate --all --strict` 只能在容器或配置了 PATH 的登录壳里成立；整套门禁按
任务书边界没跑（选段运行不是全套门禁的替代）。

## BLOCKED

无。不改实现、不合并、不 push、没触发远程 CI；破坏都在 `/var/tmp/v86` 的私有副本里造，跑完副本留着供复验。
