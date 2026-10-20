# P323 · 公开 CI 两条红的定点归因（verify）

agent: verify   status: delivered   time: 2026-10-20T03:40Z
branch: `task/P323-ci-failure-diagnosis`   PR/MR: -（local 模式）
phase: explore（只读归因：未改产品、测试、CI、规格、发布工具）
证据基：`docs/team/reviews/release-0.3.0.md`、`.pi/team/state/release-030/public-ci.log`（只读）、
`public-ci-job.json`（只读）、本分支 tip `a586b4a7` 的源码；两次最小点定复演（§4）。行号均按本分支 tip。

## 结论

两条红都不是「CI 超时连带的负载抖动」，也都不是新出现的产品缺陷。它们各自有一个可以点名的原因，而且**落在不同的责任面**：
34c 是夹具没有跟随它自己的运行模式，collect-scene 是收集步的两条前提在 P287/P309 之后过期。

### 原因一：34c「主人退场后根还在」= `--keep` 模式与夹具断言冲突，产品按契约保留

链路可以逐行钉死：

1. CI 的 gate 步用 `--keep` 跑套件（`.github/workflows/gates.yml:91`）；`smoke.sh:161` 把它落成
   `export TEAM_TMP_KEEP=1`（这一步在拿机器锁之前，是 P223 修好的继承）。
2. §34c ④ 的两个探针由 `p287n_root_live`（`smoke.sh:17264`）启动，命令前缀只有
   `env -u TEAM_PROJECT TMPDIR=… TEAM_TMP_RUN_ID=…`（`smoke.sh:17265`）——**没有清掉 `TEAM_TMP_KEEP`**。
3. 探针进程退出时，`tmp-root.sh` 的 EXIT trap 走 `_tmp_root_remove_owned`，读到 `keep=1` 就
   **打印路径并继续**（`tmp-root.sh:325`、`:337-339`）——这正是 verification 规格写死的契约：
   根「normal exit 与 INT/TERM 都回收，**只有 `TEAM_TMP_KEEP=1` 才留**」（`openspec/specs/verification/spec.md:802`）。
4. 而 §34c 的判据要求「主人退场后两个根都没了」（`smoke.sh:17344-17354`）。

原日志就是这四步的现场：红的上方紧挨两行
`保留临时根：…/p287-ns/tmp/teamsmith-nsprobe-repo{2,}-…（TEAM_TMP_KEEP=1）` 和两行 `保留 run 台账`
（`public-ci.log:5186-5189`），保留发生在 `02:07:44.54`，断言在 `02:07:48.457`、跑满 4s 的等待上限后判红
（`smoke.sh:17345` 的 `seq 1 40`×`sleep 0.1`）。**产品做的事与契约一致；判红的是夹具。**

责任面与最小修复位置：夹具（`skills/teamsmith/tests/**`，dev 面）。在 `smoke.sh:17265` 的 env 前缀加
`-u TEAM_TMP_KEEP`（连同 `-u TEAM_SMOKE_KEEP` 与仓里其它嵌套夹具一致：`smoke.sh:1813`、`:17788`、
`:18175`、`:19196` 都是这么写的）。这一改不损失现场：两个探针根都**在外层 smoke 根里面**
（`…/teamsmith-smoke-work-0c9a453f.ItVlj3/p287-ns/tmp/…`，见 `public-ci.log:5186`），外层根在 `--keep` 下照样保留。

为什么不是另外两种「修法」：

- **不是「等久一点」**：保留是契约的终态（`tmp-root.sh:337-339`），再等 4s、40s 都不会消失；日志里保留先发生
  （44.54）、断言后发生（48.457）也证明等待把上限跑满了。§34c 的 40×0.1s 本来就是「防死等的上限」而不是判据，
  这与 P316 已验收的口径一致（见 §5）。
- **不是「keep 模式下跳过这条断言」**：CI 的 gate 步**永远**带 `--keep`（`gates.yml:91`），跳过就等于
  产品默认回收这条行为在 CI 里再也不会被测——而它正是这一节存在的理由。仓里已有的正确处理是**嵌套夹具显式清开关**
  （同 §40 在 keep 下不判泄漏，`smoke.sh:19271-19289`），而不是放弃断言。

红侧仍是可证伪的：把开关放回探针（或给探针 `TMP_ROOT_BREAK=noreap`，`tmp-root.sh:344` 一带）断言必须红。
本轮 A/B 已经把「开关是唯一变量」量出来：同一棵树、同一条命令、只差 `--keep` —— 带 → `rc=1`、`✓25 ✗1`、
同一条具名红；不带 → `rc=0`、`✓26 ✗0`（§4-A）。

### 原因二：collect-scene 的 0 个现场 = 拷贝源与扫描名都停在 P287/P309 之前

收集步有两条独立过期的前提，任何一条单独就足以让现场丢失：

1. **拷贝源写死容器的 `/tmp`**（`ci/collect-scene.sh:77`：`$DOCKER cp "$CONTAINER:/tmp/."`）。
   套件的临时根由产品解析器决定：容器里 `TMPDIR` 未设 → `source=default` →
   `/var/tmp/teamsmith-<ns>`（`common.sh:4020-4028`，`/var/tmp` 可用时的磁盘默认根）。本轮的 ns 是
   `work-0c9a453f`（slug 取容器内检出目录 `work`），日志点名的保留根就是
   `/var/tmp/teamsmith-work-0c9a453f/teamsmith-smoke-work-0c9a453f.ItVlj3/…`（`public-ci.log:5186`）。
   所以 `docker cp` 成功（`rc=0`）搬出来的是容器的 `/tmp`——`HOME=/tmp` 造成的 `.cache/.bun/.npm/.pi`
   和 `.t-1001.*`，共 79 项（`public-ci.log` 收集段）——**套件写东西的 `/var/tmp` 一个字节都没拷**。
2. **前缀表写死平铺名 `teamsmith-smoke.`**（`ci/collect-scene.sh:30`）。P287 之后根名是
   `teamsmith-<kind>-<ns>.XXXXXX`（`openspec/specs/verification/spec.md:791`），平铺 `teamsmith-smoke.*`
   按设计**不再命中**——§34c 自己就断言「平铺家族模式零命中」（`smoke.sh:17187-17189`）。收集步用的正是
   那条被契约禁止再命中的模式，所以就连 `$STAGE/teamsmith-smoke.*` 那 1 项也只剩锁文件
   （`teamsmith-smoke.lock`，被正确地判为「同前缀但不算现场」）。
   三个点名现场日志同样写在 `$TMP` 下（`smoke.sh:14231`、`:19409`、`:22355`），不在 `/tmp`，于是打印「不在」。

这不是阈值问题：`--min-families 1` 没被改动、也不需要改；现场**根本没进暂存目录**。容器也没有在收集前消失：
`docker cp rc=0` 且拿到 79 项。

责任面与最小修复位置：`ci/collect-scene.sh`（PM 独占，非 verify 面）。两处缺一不可，而且**不是一次字符串替换**：
容器内的 ns 只有容器自己算得出（slug 取 `/work`、hash 取容器内 realpath），宿主算不出同一个值，所以拷贝源除了
`/tmp` → 容器解析出的根，还要跨过一层 `teamsmith-<ns>/`。两个可行形态（取舍交 PM）：

- **(A) 精确**：gate 步在容器里把 `team_tmp_root` 写进 `/tmp` 下一个固定名字的标记文件，收集步 `docker cp` 后读它，
  再 cp 那个目录。代价是依赖「取消时这一步也跑得完」。
- **(B) 粗糙**：`docker cp "$CONTAINER:/var/tmp/."`，然后按「一层目录 + 家族名 `teamsmith-smoke-`」扫。
  取消后一定有效（镜像里 `/var/tmp` 只有本项目的根），代价是多搬一层目录。

两种形态都必须把前缀表改成带 ns 的 `teamsmith-smoke-`；锁文件 `teamsmith-smoke.lock` 与它就不再同前缀，
「同前缀但不算现场」那行会自然消失，判据不受影响。

## 3 · 已知边界（观测到 / 未观测到）

- 容器随 runner 销毁了，`/var/tmp/teamsmith-work-0c9a453f/` 里到底有多少文件**无法再观察**；「拷出来就能打包成功」
  由脚本逻辑与 §4-B 的 `--stage` 复演支持，没有第二份 CI 现场。
- §97 的另外 25 条断言在 keep 模式下全绿（`public-ci.log:5161-5185`），所以这条红与负载无关；但本轮**没有**做
  全库断言普查（任务书禁止扩面）。读到的相关处只有：§40 在 keep 下显式不判泄漏（`smoke.sh:19271-19289`），
  以及三处嵌套夹具清 `TEAM_TMP_KEEP`（`smoke.sh:1813`、`:17788`、`:18175`、`:19196`）。
  顺带观察（不改本轮范围）：§34c ①②③ 里的嵌套运行 `p287c_run`（`smoke.sh:17132-17137`）也没有清这个开关，
  于是它自己那套 §40 泄漏断言在 CI 里会被跳过——是覆盖变弱，不是假红。
- 60 分钟上限只是**触发**收集步的原因（`public-ci-job.json`：gate 步 59m10s，job 1h0m19s、`cancelled`），
  不是这两条红的原因；P316 的 30 分钟单段极端上限也不会改变 job 级上限。CI 容量属于 P322，本报告不越界。

## 4 · 复演：命令与输出（只动我自己的临时目录与进程）

A 组——34c 的 A/B（本工作树、私有 TMPDIR、私有锁；两腿之间树指纹干净、HEAD 未变）：

```bash
D=$(mktemp -d /tmp/p323ab2.XXXXXX)
env TMPDIR="$D" TEAM_SMOKE_LOCK="$D/teamsmith-smoke.lock" \
  bash skills/teamsmith/tests/smoke.sh --select 34c --keep      # A1 = CI 的运行模式
env TMPDIR="$D" TEAM_SMOKE_LOCK="$D/teamsmith-smoke.lock" \
  bash skills/teamsmith/tests/smoke.sh --select 34c             # A2 = 只差这一项
```

```
=== run keep ===   rc=1
保留临时根：<D>/teamsmith-smoke-<ns>.XXXXXX/p287-ns/tmp/teamsmith-nsprobe-repo2-….…（TEAM_TMP_KEEP=1）
保留临时根：<D>/teamsmith-smoke-<ns>.XXXXXX/p287-ns/tmp/teamsmith-nsprobe-repo-….…（TEAM_TMP_KEEP=1）
  ✗ 34c 主人退场后根还在（回收没生效？）
#5 34c · … · 用时 28s · ✓25 ✗1 SKIP0 · ticks 26
=== run nokeep === rc=0
  ✓ 34c 主人退场 → 两个根都被回收（生命周期归创建者）
#5 34c · … · 用时 17s · ✓26 ✗0 SKIP0 · ticks 26
```

`✓25 ✗1` 与 CI 的 `✓25 ✗1`（`public-ci.log:5191`）逐项同形，同一句具名红。
（同一 A/B 在 V55 §4.6 已有一份既有记录：同树同命令只差 `TEAM_TMP_KEEP`，结论相同。）

B 组——collect-scene 的命名判据（同名同内容的 stage，只改名字；无容器、无他人路径）：

```bash
mkdir -p <D>/stage <D>/out
mkdir -p <D>/stage/teamsmith-smoke-work-0c9a453f.ItVlj3 ; : > <D>/stage/teamsmith-smoke.lock
bash ci/collect-scene.sh --stage <D>/stage --out <D>/out          # 带 ns 的真名
mv <D>/stage/teamsmith-smoke-work-0c9a453f.ItVlj3 <D>/stage/teamsmith-smoke.MB2qWl
bash ci/collect-scene.sh --stage <D>/stage --out <D>/out          # P287 之前的平铺名
```

```
带 ns 名：同前缀但不算现场…teamsmith-smoke.lock ／ 判据：现场族 0 个 · 阈值 1 ／
         ✗ 找到的现场族（0）少于阈值（1）—— 失败现场没带出来        rc=1
平铺名：  [族] teamsmith-smoke.MB2qWl  1 文件 ／ 判据：现场族 1 个 · 阈值 1 ／
         ✓ 现场带出来了（1 个族进 …/out）                           rc=0
```

C 组——解析器的默认腿（容器里的同形，TMPDIR 未设）：

```bash
env -u TMPDIR -u TEAM_TMP_ROOT -u TEAM_PROJECT bash -c \
  'p="$1"; . "$p/skills/teamsmith/scripts/lib/common.sh" >/dev/null 2>&1; \
   printf "source=%s root=%s\n" "$(team_tmp_root_source)" "$(team_tmp_root)"' _ "$PWD"
# → source=default root=/var/tmp/teamsmith-<slug>-<hash8>     （与日志 5186 的 /var/tmp/teamsmith-work-… 同形）
```

一条过程记录，为了不误导复验：第一次 A/B 我误在主检出里跑，另一席位的提交让那次运行的树指纹失效（退出码 4，
套件自己声明「本轮 ✓/✗ 都不作数」）。本报告只采信上表这次在自己工作树上的重做；重做前后
`git status --porcelain --untracked-files=all` 为空、HEAD 停在 `a586b4a7`。

## 5 · 与 P316 的关系（哪些证据可复用）

- **P316 的已验收候选不是原因，也不携带修复。** 它的 tip `368d9cec` 不含 CI 测的产品提交：`git merge-base
  --is-ancestor bf368ceb task/P316-delete-load-sensitive-tests` 为假；它对 `smoke.sh` 的 661 行改动与 §34c 的
  P287N 段零交集（diff 里唯一出现 `TEAM_TMP_KEEP` 的行是上下文）。
- **可复用的是它的口径，不是它的读数。** P316 已验收的原则「上限只用来防死等，不许把上限当判据」正好判掉
  「34c 是不是等得不够」这条路：那里的 40×0.1s 是上限，判据是状态，而状态按契约永不出现。
  P316 的另一条（行为断言必须有红侧）给出修复后的验收形态：清掉开关后必须仍能用
  `TMP_ROOT_BREAK=noreap` 把它打红。
- P316 的 FAST/选段读数（V61/V63/V64）**没有**覆盖 CI 的 `--keep` 与收集步，不能当作这两条红的通过证据。

## 6 · 按现有契约修 vs 需要改规格

| 项 | 结论 |
|---|---|
| 34c 夹具 | **按现有契约修**。规格已写死「正常退出回收、只有 `TEAM_TMP_KEEP=1` 才留」(`spec.md:802`)，夹具一行 env 即可；不需要 delta。 |
| collect-scene 拷贝源/前缀 | **按现有契约修**（根名带 ns、根在解析出的临时目录下都已写进规格 `spec.md:787-802`）。收集步本身**没有任何规格**描述，所以这只是普通修复。 |
| 「取消/失败后现场必须到达工件」 | **需要新规格**才会成为契约。现在只有「保留现场」被写死，没有「带出来」这一条；要把它钉住，需 PM 立 change/delta。 |
| 给这次漂移加守卫 | 若 PM 想要（例如把收集表与 `tmp-root.sh` 的命名对齐），按本仓「net-zero for guards」规则需同时退役一条或说明产品无法自守；更省的方向是 (A) 形态——让收集步去问容器的解析器，命名不再有第二处编码，比加守卫更小。 |

## 7 · 未做与遵守的边界

未改任何产品/测试/CI/规格文件，只新增本报告；未重跑全量、FAST、31 臂变异或发布检查；未触发远程 CI；
未读任何 credential/token/auth 文件；只读主检出的 `.pi/team/state/release-030/` 日志与 job JSON；
复演只写我自己的 `/tmp/p323*` 目录与进程，结束后已清理；没有碰别人的容器、路径或分支。
