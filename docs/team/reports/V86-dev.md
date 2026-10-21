# V86 · P346 的独立验收：切片无损、并集断言有牙、两条自报风险

agent: dev   status: **PASS**（第三轮受检 `0d554bb6`：缓存去掉了、注释与实现一致、没有顺手改别的——三件都成立，见 §7；两处措辞小项不阻塞）   time: 2026-10-21T07:00Z
branch: `task/V86-r3-shard-verify`（local 模式，未 push，未合并；本分支 = `main@64ff7d4e` 的树 + 本报告。报告里带上第二轮的 §6，让这一份文件自成完整记录）   PR/MR: -
受检：第三轮 `0d554bb6`（§7）；第二轮 `8ebd637e`（§6，FAIL——F2 不成立）；第一轮 `1a54477c`（§1–§5，PASS）。作者报告 `docs/team/reports/P346-dev2.md`。
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

## 6 · 第二轮（定点复看 `8ebd637e`，只验 F1–F4）

**判定：FAIL。** F1、F3、F4 三件成立；**F2 不成立**——`docker buildx build … --cache-from/--cache-to type=gha` 写在 `run:` 步骤里，
而 runner 只把 `ACTIONS_RUNTIME_TOKEN` / `ACTIONS_CACHE_URL` / `ACTIONS_RESULTS_URL` 注入 Node 与容器 action、不注入 `run:` 步骤，
所以 gha 缓存后端拿不到 url/token（buildkit 的报错是 `token not set for github actions cache`）。
**「只有第 1 片写缓存」这个选择本身是对的**，缺的是它前面一个能拿到凭据的入口（6.2 给三条修法）。
第一轮的 PASS 只对 `1a54477c` 成立，不对当前 tip 成立。

受检：`8ebd637e`（相对 `1a54477c` 只动 `.github/workflows/gates.yml`、`skills/teamsmith/tests/section-select.sh`、
`skills/teamsmith/tests/slice-coverage.sh` 与作者报告，+92/−21；`smoke.sh` 与 `section-paths.tsv` 未动，第一轮 §4 的
「段正文零改动、地板仍是 128」继续成立）。私有副本：`/var/tmp/v86r2/cand`（`git archive`，无 `.git`）、
变异副本 `flipA/B/C/D`、构建副本 `/tmp/v86r2-cand`（`/var/tmp` 在宿主不可见，构建只能在 `/tmp` 的副本里跑）。

### 6.1 F1 成立：区间与余量都对上我的读数

用第一轮同一份段账本（2026-10-20 17:08，121 行 / 5324 s / 88.7 min）自己重算，每片运行集取 own ∪ borrowed、
账本里没有的段按作者同一口径 44 s 补：

```
$ python3 /var/tmp/v86r2/f1.py          # 选择器 own + 借来的段，逐片求和
N=4: shard1: 23.2 min (1395s, 45 sections, 1估) | shard2: 34.6 min (2077s, 51 sections, 2估)
     shard3: 18.5 min (1108s, 43 sections, 2估) | shard4: 45.4 min (2721s, 46 sections, 2估)
       slowest 45.4 min; sum 7301s = 121.7 min
```

注释里的 23 / 35 / 19 / 45、19–45、余量 11.5 与我这一致（45.4 + 构建 59 s + checkout/openspec ≈ 2 分 = 48.4 → 余量 11.6，
与第一轮的 11.5 同口径）。「shard 4 owns §51 = 1023 s 与 §38 = 767 s」也核过：账本最贵的两段正是它们，且都在 shard 4 的
own 清单里（own=31，shard4 的 `own-key=` 行含 `51` 与 `38`）。`19–37` 已经不存在；`one build` 的三处都改成了
「per job / four builds」的准确说法（`gates.yml:85`、`:273` 以及 `:115` 讨论 artifact 那一段）。

四个不阻塞的残项，都是文字与数字口径，不影响本条成立：

1. 第 54–55 行把 11.5 写成「45.4 against the 60-minute ceiling」，但 60 − 45.4 = 14.6；11.5 只有在加上约 3 分钟的构建与
   setup 之后才对（第一轮的账就是这么算的）。读者照这句自己减会得到 14.6。
2. 同一份账本在同一文件里有两个总数：第 39 行写 5322 s，新注释写 5324 s。账本实测 5324 s（121 行求和），第 39 行那个是旧的。
3. `gates.yml:308` 还写着「a cancelled shard's share is named one section at a time」，而 F4 已改成整组一行——这句现在与实现相反（属 F4 的文档面，见 6.4）。
4. `gates.yml:85` 的「the layer cache below is what keeps them cheap」在 F2 不成立时是假话（见 6.2）。

### 6.2 F2 不成立：缓存这一步拿不到凭据，第一条构建命中不了

**选择本身是对的。** Docker 文档（gha 后端）写明 scope 默认 `buildkit`，且「If you build multiple images, each build will
overwrite the cache of the previous, leaving only the final cache」——四个并发 exporter 抢的是同一个 cache object。cache 条目按 key
不可变，后到的保存会失败（actions/cache 的典型报错 `Unable to reserve cache with key X, another job may be creating this cache`），
而 buildx 的 `--cache-to` 默认 `ignore-error=false`（Docker 文档参数表），所以并发写不只是白写，还可能把构建步骤弄红。
只留一个写者是正确解，与它并发的三片只做 `--cache-from`（读到的是**上一次**运行的缓存，因为四片同时开跑）。

**但这一步拿不到缓存凭据。** 三条独立证据：

- actions/runner 当前 main（`b6d10b59c178`，2026-10-20）：`NodeScriptActionHandler.cs:57/60/73` 与
  `ContainerActionHandler.cs:223/226/239` 才注入 `ACTIONS_RUNTIME_TOKEN` / `ACTIONS_CACHE_URL` / `ACTIONS_RESULTS_URL`；
  `run:` 步骤用的 `ScriptHandler.cs` 一个都不给（它只注入 `ACTIONS_ID_TOKEN_REQUEST_*`，317–318 行）。
- Docker 文档同一页 Authentication：「If you invoke the `docker buildx` command manually from an inline step, then the variables
  must be manually exposed. Consider using the `crazy-max/ghaction-github-runtime` GitHub Action as a helper for exposing the variables.」
- 那个 helper 的实现反过来证明默认没有：它把自己环境里所有 `ACTIONS_*` 用 `core.exportVariable` 写进 `$GITHUB_ENV`（`src/github.ts`），
  后面的 `run:` 步骤才看得到。

buildx 侧（当前 main `a9bcf45d2a7c`，2026-10-19）：`build/opt.go` 的 `CreateCaches` → `addGithubToken` 从
`os.LookupEnv("ACTIONS_RUNTIME_TOKEN"/"ACTIONS_CACHE_URL"/"ACTIONS_RESULTS_URL")` 取，`commands/build.go:1164-1165` 对 import 与
export 都调用它；取不到就把 attrs 留空下发。buildkit 的 gha 后端随后报 `token not set for github actions cache` /
`url not set for github actions cache`（`cache/remotecache/gha/gha.go:80/102`）。

**会怎么坏**（按源码判读，本机无法跑 Actions）：导入侧 `lazyCacheManager.Query` 把初始化错误吞掉、当成「没有记录」
（`solver/llbsolver/bridge.go:329-335`）→ 静默冷构建；导出侧第 1 片的 `--cache-to` 解析失败、默认 `ignore-error=false` →
构建步骤非零退出，该片红、coverage 跟着红。也就是说第一次真跑大概率是「第 1 片红在导出、其余三片冷构建」，之后永远没有缓存可命中。

顺带排除一个看错的可能：`docker/setup-buildx-action@v3` 的 bundle（`dist/index.cjs`）里确实出现 `ACTIONS_RUNTIME_TOKEN`，
但那是它自己作为 Node action 跑 `cache-binary`（把 buildx 二进制缓存进 Actions cache）用的；整份 bundle 里 `GITHUB_ENV` 出现 **0** 次，
它不会把凭据写给后面的 `run:` 步骤。

**本机能测到的那一半**（作者自报 0.8 s）：在候选副本里用宿主 podman 重建同一份 `ci/Containerfile`，20/21 个 STEP 打印
`Using cache`（只有 STEP 1 的 `FROM` 不打印）：

```
$ cd /tmp/v86r2-cand && time distrobox-host-exec podman build --layers -f ci/Containerfile -t localhost/teamsmith-gates:v86r2 .
… STEP 21/21: CMD […] --> Using cache 01a49fc12205…
real 0m0.610s
$ distrobox-host-exec podman image inspect --format '{{.Size}}' localhost/teamsmith-gates:p346size
1352897576          # 1290 MiB / 1.35 GB；作者写的「1290 MB」是 MiB 口径
```

这证明「本机 layer store 命中后构建本身 ≈0.6 s」，也复现了作者的 0.8 s 量级；但它是本机层缓存，没有网络导入。CI 的暖路径
还要从 Actions cache 拉约 1.29 GB，再把 1.29 GB 用 `--load` 写进 docker 镜像库（作者在提交信息里说 `--load` 未测，文件注释里没写）。
所以 0.8 s 是下界，不是 CI 暖路径的读数；同理，「用 artifact 分发比重建贵」只算了下载，没算 buildx 这条路径自己的 `--load`。

**修法**（「只有第 1 片写」保持不变）：

- **A（推荐）** 改用官方 `docker/build-push-action`——它是 Node action，url/token 自动可得：
  ```yaml
  - uses: docker/build-push-action@v6
    with:
      context: .
      file: ci/Containerfile
      tags: teamsmith-gates:ci
      load: true
      cache-from: type=gha
      cache-to: ${{ matrix.slice == 1 && 'type=gha,mode=min' || '' }}
  ```
- **B** 保留手写 `docker buildx build`，在它前面加一步 `uses: crazy-max/ghaction-github-runtime@v4`（把 `ACTIONS_*` 写进 `$GITHUB_ENV`）。
- **C** 另有一个要 PM 裁的取舍：给 `--cache-to` 加 `ignore-error=true`。文档写明默认 false，缓存导出失败会连带把构建步骤判红；
  这个项目「不吞错」的纪律与之相反，所以「缓存故障该不该挡住一棵绿的产品树」是产品判断，不是必须改。

改完还需要第一次真跑确认两件本机测不到的事：第 1 片导出成功、下一次运行四片都命中（以及暖路径的真实墙钟）。

### 6.3 F3 成立：变异 C 现在会红（不是只改措辞）

控制组（候选原样）`--check` 绿，②的 ok 行把覆盖面写成 (a)/(b)/(c)，并明说「不等同于所有 key × 所有位置」：

```
ok: 分片只依赖 key：(a) 表首 key 在全部 128 个基线下标 × 7 个 N 上与 0 号位同片（889 次比较）；
    (b) 另 3 个 key 各比首尾两点 × 7 个 N；(c) 每个 key 各比首尾两点（N=4）—— 片号都不变，不等同于「所有 key × 所有位置」全比
== 选段自检 ==  ok 12  bad 0  SKIP 1          rc=0
```

变异 C（`flipC`，与第一轮**同一行**：只在基线下标 50 处返回 `(c+1)%n`）现在红并点名：

```
bad: 分片依赖了段在表里的位置（…）：N=2：key 0 在 0 号位是第 2 片、在第 50 位却是第 1 片
== 选段自检 ==  ok 11  bad 1  SKIP 1          rc=1
```

第一轮同一变异是 `rc=0`（只改了措辞就仍是 0），所以这是真修。变异 A（全落第 1 片）与 B（按位置轮转）也仍各自红并点名。

**边界（我自己加的变异 D）**：只在第 50 位漂移、且只对**非表首**的 key 生效 → 仍绿（`ok 12 bad 0`）。这与 ok 行声明的范围一致：
现在的②证明的是「表首 key 在所有位置成立」，不是「所有 key × 所有位置」，边界写在 ok 行里而不是藏着。
**代价**：单次 `--check` 从 10.7 s 涨到 15.65 s（+5 s）。按 §36 代码里的调用点数是 **11 次**执行（真树 1 + 表副本 1 +
7 个 `p98_flip` + 2 个 token 变体树），所以注释里说的 3-key 全位置版本（作者测 30 s/次）代价是 11 × 19.3 s ≈ 3.5 分钟，
不是「§36 调用 17 次…多 5 分钟」——17 是 `--check` 字样在该段出现 17 次（含注释与消息串），不是调用次数。结论（不做 3-key 版本）不变，数字要改。

### 6.4 F4 成立：缺片时 64 条 annotation 压到 4 条，判定不变

用第一轮同一批坏形状（`/var/tmp/v86/cov/*`，keys 与 status 都是当时选择器写的真清单）跑候选的 `slice-coverage.sh`：

```
floor-missing（片 3 缺清单、作业 cancelled）：rc=1  ::error::=4   汇总 ok 4 bad 3     ← 第一轮 64 条 / ok 4 bad 3
floor-narrow（片 2 清单被删一段，success）：   rc=1  ::error::=2   汇总 ok 5 bad 2     ← 不变
floor-good + --shards-result failure：        rc=1  ::error::=1   汇总 ok 6 bad 1     ← 不变
n3（真跑 3 片、矩阵写 4 片，success）：        rc=1  ::error::=34  汇总 ok 4 bad 34    ← 不变
floor-good（success）：                        rc=0  ::error::=0   汇总 ok 7 bad 0     ← 不变
allgood（基点不可解析的兜底，success）：        rc=0  ::error::=0   汇总 ok 7 bad 0     ← 不变
```

缺片那 4 条就是「矩阵结果 1 + 片级 1 + 整组 1 + 并集汇总 1」，组里一行列出全部 31 段：

```
::error::门禁矩阵的结果是 [cancelled]（不是 success）：…
::error::片 3/4（作业结果 [cancelled]）：整片缺清单（…/shard-3.keys）—— 它 own 的 31 段这次没有任何片跑到
::error::片 3/4 的份额（整组 31 段）：0d 2 3 6b 6c 10b 10c 11b4 14b 12b-h0 12b-h0d 14 14c 18b 18c 20 21 32 33 12e 12j 12k 46 47 48 49 54 55 60 61 15
::error::并集缺 31 段，全部来自上面「整片缺清单」的那些片（已按片成组点名，这里不重复）
```

收窄形状仍逐段点名被删的那一段（`段 [22]`），没有被新逻辑吞掉。残项只有 6.1 第 3 条那句 `gates.yml:308` 的旧注释。

### 6.5 这一轮跑过什么、没跑什么

跑过：四件的全部复验命令（选择器 `--check` 控制组 + 三个变异 + 一个自造变异、coverage 六种形状、段账本重算、
本地层缓存重建）。没跑：整套门禁、没触发任何远程 CI/Actions、没改受检树、没碰产品文件。
本报告自身的账本面用了项目固定验收行（`ledger-ban.sh --names-file …`，输出 `files=2018 hits=0 names=ok rc=0`），
没有另跑 §40 选段。
构建测试在 `/tmp/v86r2-cand`（候选副本）里用宿主 podman 做，测试后已删掉 `teamsmith-gates:v86r2` 这个临时 tag，
镜像本体与原有 tag 未动。

## 7 · 第三轮（定点复看 `0d554bb6`，只验三件）

**判定：PASS。** 三件都成立：缓存真的没了（行为上零缓存，`type=gha` 只剩注释里对「被否决选项」的那一次引用），
注释的四个数与实现逐条对得上（`gates.yml:308` 那句旧说法已改成实测行为，我在本轮候选树上重跑缺片形状拿到 **4 条**
annotation），本轮 P346 只有一处代码提交，且四处受检面相对 `8ebd637e` **逐字节相同**。
两处措辞小项不阻塞（1290 是 MiB 不是 MB；coverage 头注释漏了「基点不可解析 → 基线是全集」这个兜底），
另有两处第二轮就记下的旧措辞，本轮没动也不属本轮范围，一起列在 7.4 备查。

受检：`0d554bb6`（P346 分支 tip）。本轮 P346 侧的代码提交只有一个——`d39c344f`（`git show --stat` =
`.github/workflows/gates.yml` 一个文件，+24/−26）；`0d554bb6` 自己只加/改 docs。分支在这两个提交之间从 main
合过一次（`216e4d23`），所以下面的比对把「P346 自己的改动」与「merge 从 main 带进来的改动」**分开算**。

### 7.1 缓存真的没了：行为上零缓存，`--cache-from/--cache-to type=gha` 只剩注释里那一次「为什么不用」

```
$ git show 0d554bb6:.github/workflows/gates.yml > gates.yml@0d554bb6     # 下面的 grep 都读这份副本
$ grep -n -iE 'cache|buildx|type=gha' gates.yml@0d554bb6        # 8 行，全部是注释
60:  # builds the gate image once — ~4 billed minutes for four shards, with no cache (the build step
87:  # one image build (P346: four shards = four builds, ~59 s each, no cache — see the build step).
120: #   * **Actions layer cache**: `--cache-from/--cache-to type=gha` inside a `run:` step does NOT
121: #     receive `ACTIONS_RUNTIME_TOKEN` / `ACTIONS_CACHE_URL` / `ACTIONS_RESULTS_URL` — the runner
126: # So: no cache, one plain build per shard. If the build ever becomes the dominant cost, the fix
127: # is a helper action that exports the cache correctly — not a cache flag inside this block.
267: # … was chosen over option ② (keep two jobs + a GHCR-cached image): one runner, one
271: # property is per job, not per run, and there is no layer cache (the build step says why).
$ grep -n -E 'docker build' gates.yml@0d554bb6                  # 全文唯一的构建命令
129:        run: docker build -f ci/Containerfile -t teamsmith-gates:ci .
$ grep -nE 'setup-buildx|--cache-from|--cache-to|type=gha,mode' gates.yml@0d554bb6 | grep -v '^120:'
（无输出：没有任何一处把缓存写进命令）
```

**关于「不该再出现 cache-from / cache-to / type=gha」这句，要点名一个细节**：这三个字符串确实还在，但只在
`gates.yml:120` 的注释里，而且是在**说明为什么不用它**——PM 的判据是「注释里若还有『缓存让构建便宜』这类话
就是新的假话」，这句给的是相反的结论：为了省 4 分钟，引入一条凭据依赖 + 一条会红的第一跑，不值得。
第 126 行的 `So: no cache, one plain build per shard` 是这段的落点。全文没有任何一处把缓存写成现在的行为，
`docker/setup-buildx-action` 也一并消失了。

### 7.2 注释与实现一致：四个数逐个对上；`gates.yml:308` 那句现在说的是实测行为

| 注释里的说法 | 我的读数 | 结论 |
|---|---|---|
| 四片各构建一次 | 唯一构建步在矩阵作业里，无 `if:` 排除、无缓存，全文没有第二个 `docker build`（第 129 行） | ✓ |
| 每次 59 s、四片约 4 分钟计费 | 59 × 4 = 236 s；GitHub 按作业分钟向上取整（每片 59 s → 1 min）→ 4 min。59 s 的出处是 `docs/team/reports/P322-dev-bob.md:56`（run 39354787618：构建镜像 59s） | ✓ |
| 镜像 1290 MB | `podman image inspect localhost/teamsmith-gate:local --format {{.Size}}` → **1,352,897,482 字节 = 1290.3 MiB = 1.35 GB** | ✓（单位写错，见 7.4-1） |
| 制品分发要搬 1290 MB 四趟、比重建贵 | 1290 MiB × 4 ≈ 5.0 GiB 的网络+存储，对比 4 分钟重建 | ✓ |
| 为什么不用缓存 | 与我第二轮的三条证据一致（runner 的 `ScriptHandler` 不注入那三个变量 / Docker 文档点名叫 helper action / buildkit gha 后端报 `token not set`）；注释把它们压成两句，没有多承诺 | ✓ |

**`gates.yml:308`（旧行号）那句**：`8ebd637e` 里写的是「a cancelled shard's share is named one section at a
time」，与 F4 之后的实现相反；本轮改成「a missing section gets its own ::error:: unless a whole shard is missing
— then its share is one shard-level annotation plus one line listing that shard's keys」。**在本轮候选树里重跑缺片
形状核对**（`git archive 0d554bb6` 解到 `/var/tmp/v86r3/cand/t`，四片真清单由候选自己的选择器写出，删掉片 3 的
清单、status=cancelled）：

```
$ for k in 1 2 3 4; do bash skills/teamsmith/tests/section-select.sh --slice $k/4 --out $D/shard-$k >/dev/null; done
  shard-1 35 / shard-2 35 / shard-3 33 / shard-4 32 = 135（无 --paths 时基线就是全集；地板是 128）
$ rm $D/shard-3.keys; echo cancelled > $D/shard-3.status
$ bash skills/teamsmith/tests/slice-coverage.sh --keys-dir $D --matrix-file .github/workflows/gates.yml \
    --shards-result cancelled ; echo rc=$?
::error::门禁矩阵的结果是 [cancelled]（不是 success）：任一片失败或被取消，这条覆盖断言就必须红
::error::片 3/4（作业结果 [cancelled]）：整片缺清单（…/shard-3.keys）—— 它 own 的 33 段这次没有任何片跑到
::error::片 3/4 的份额（整组 33 段）：0d 0e 2 3 6b 6c 10b 10c 11b4 14b 12b-h0 12b-h0d 14 14c 18b 18c 20 21 32 33 12e 12j 12k 46 47 48 49 54 55 60 61 61b 15
::error::并集缺 33 段，全部来自上面「整片缺清单」的那些片（已按片成组点名，这里不重复）
== 分片覆盖 == ok 4 bad 3
rc=1                                                       ← 4 条 annotation（第一轮同一形状是 64 条）
```

所以「片级 1 条 + 一行列出该片 keys」是实测，不是描述。顺带一条复验提示：这份夹具必须用**候选树自己**的选择器
写清单——我第一遍图省事用了 `/var/tmp/v86` 里第一轮留下的旧夹具，它按旧的段账/地板切，重算立刻报「规则算 35、
清单 31」。那是夹具过期（我自己的操作），不是缺陷。

### 7.3 没有顺手改别的：本轮一处代码提交，四处受检面逐字节相同

```
$ git show --stat d39c344f
 .github/workflows/gates.yml | 50 +++++++++++++++++++++----------------------
 1 file changed, 24 insertions(+), 26 deletions(-)
$ git show d39c344f --format= | grep -E '^@@'                     # 5 个 hunk
@@ -56,7 +56,9 @@   @@ -82,7 +84,7 @@   @@ -110,26 +112,21 @@   @@ -270,8 +267,8 @@   @@ -304,8 +301,9 @@
```

非注释的改动只有一处（buildx 步骤换成一行普通构建）：**删 11 行非注释、增 2 行**（净 −2 行，与 PM 说的「两行删除」
对得上；那 11 行里 2 行是 `setup-buildx` 步骤、9 行是原 buildx 构建步的 name/env/run）。其余四个 hunk 只动注释。
四处受检面相对 `8ebd637e`：

```
section-select.sh   blob d351ba83 在 8ebd637e / d39c344f / 0d554bb6 三处相同
slice-coverage.sh   blob 2169289e 同上（main 上还没有这个文件——P346 未合并）
coverage 作业块       从 '  coverage:' 到 EOF 共 39 行，cmp 逐字节相同
smoke.sh 选段块       第 1..1542 行（第一个 '^section "' 之前），cmp 逐字节相同
```

`--slice k/N` 的规则与 `--check ⑨` 都在 `section-select.sh` 里，所以第一行就是它们的证据。`smoke.sh` 整文件相对
`8ebd637e` 差 44 行，**全部是 merge 带进来的 main 改动**（P344 的三处 SIGPIPE 修法，hunk 行号 18250 / 18504 /
19591，都在选段块之后）；选段块本身零改动。merge 也没有回退 main 的东西：

```
$ git diff --name-status 8f6a6baa 216e4d23      # 8f6a6baa = 这次 merge 的 main 侧父提交
M .github/workflows/gates.yml            A docs/team/reports/P346-dev2.md
M skills/teamsmith/tests/section-select.sh   A skills/teamsmith/tests/slice-coverage.sh
M skills/teamsmith/tests/smoke.sh
```

—— 相对 main 侧父提交，合并结果只多了 P346 自己的 5 个文件。这轮树里 `loop-inventory.tsv`、`cmd-status.sh`、
`common.sh`、`config-cli.sh`、`routes.sh`、`section-paths.tsv` 与 main 逐字节相同（我逐个比过 blob），它们是
merge 带进来的别人的活，不是本轮改的。

### 7.4 措辞项（不阻塞：三件的成立都不依赖它们）

1. **1290 MB 应为 1290 MiB**：`podman image inspect` 的 `.Size` 给的是字节（1,352,897,482），1290 是 MiB，
   写成 MB 差 4.7%。结论不变（1.29 GiB × 4 与 1.35 GB × 4 都远大于 4 分钟重建），但读者拿 `podman` 的输出
   自己核会得到「1290 不对」。
2. **coverage 头注释漏了兜底**：它写「asserts the union is exactly the floor ∪ changed paths」，而代码在基点
   不可解析时用的基线是**全集**（我这次实测：无 `--paths` 时四片 own 合计 135 = 整张表，不是地板 128）；
   第 50 行那句「asserts the union is exactly the floor」同样只说地板、没提 `--paths`。这两句在本轮之前就在。
3. 两处第二轮已记下的旧措辞，本轮没动也不属本轮范围：第 39 行 `5322 s` 与第 53 行 `5324 s` 两个总数；
   第 54–55 行「45.4 against the 60-minute ceiling leaves 11.5 min」（60 − 45.4 = 14.6，11.5 只在算上约 3 分钟
   构建 + setup 之后成立）。

### 7.5 交付面上跑过什么、没跑什么

本报告是唯一改动，所以只跑账本面那一条固定验收行（与第二轮同一口径，不占门禁锁）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --root . \
    --names-file <主检出的 .pi/team/forbidden-names.txt>          # 名单只交给工具读，不打印
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/verify scope=published files=2030 hits=0 names=ok user=resolved
rc=0
```

没跑整套门禁、没跑任何 `smoke.sh` 选段、没触发远程 CI、没 push（local 模式）。破坏只在 `/var/tmp/v86r3` 的私有
副本（`git archive` 解出来的树）里造，副本留着供复验。

## BLOCKED

无。不改实现、不合并、不 push、没触发远程 CI；破坏都在 `/var/tmp`（及 `/tmp` 用于 podman 构建的那份副本）里造，复验照本节的命令重建即可。
