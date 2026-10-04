# P107 · `roster-writer-and-route-truth` 返工后的**换人重验**（对 P105 的修复）· verify

agent: verify
status: **PASS（我的独立夹具 0 finding；本地全量门禁绿）** —— `roster-writer-and-route-truth` 归档前的最后一道门
time: 2026-09-28T13:1xZ（本会话）
branch: `task/P107-p107`（local 模式：**不 push**；分 4 个小提交留在本地，等 PM 复验/合并）
change: `roster-writer-and-route-truth`（verify 阶段；P99 的 apply 与 P105 的返工都不是本席位做的，换人成立）
deltas: `-`（verify 只写报告与证据，不改实现、不改 delta）
验证对象: **main 上已合并的实现** —— `HEAD` 的基点 = `main` = `631a7f84`（P107 任务书提交本身就在 main 上）；
  P105 的修复 `fdf1739e` 是 `main` 的祖先；`git diff --quiet refs/heads/main HEAD -- skills/` → **空**
  （0 个文件），即下面每一条夹具跑的就是 main 的那份 `skills/**`，本分支只多了报告/证据提交。
证据包: `docs/team/reports/P107-verify/pkg/` = `lib.sh` + `run.sh` + `15/10/20/30/40/50/60` 七个分节 + `logs/`
  （每格的原始输出；`run.sh` 末行是机器可读汇总）。

**总结论**：P104 的两条 finding 都**在 main 上闭环**，且用本席位**自己造的**夹具与期望值重新证过：

| brief 要求 | 我的独立证据 | 结果 |
|---|---|---|
| 1 F1：`api 1` · ` api` · `api ` · `api<TAB>1` · 空串 → 非零 + 名册字节不变 + 无 `result=ok`；`api1` → 成功 + 审计恰好一行 | 16 个全新 scratch 项目（5 格主矩阵 + 5 格精确码复核 + 1 格对照 + 5 格无旗标补充） | **37 ok / 0 finding** |
| 2 teardown token 精确：`'dev verify'` 拒 + 名册不变；`dev` 真移除 + 审计一行 | 同夹具两方向（拒绝后接着删） | **12 ok / 0 finding** |
| 3 F2：`add-agent … --model vendor/m2` 后 配置 / state / JSON 席位行同源；`-` 清覆写 | 先埋旧记录再写；三方逐值对照 | **15 ok / 0 finding** |
| 4 走查可证伪：自造谎言 → `routes.sh` 红且点名 → 还原绿 | 两个本包自定的谎言（help 假旗标 / schema 假命令） | **15 ok / 0 finding** |
| 5 零回归：validate + FAST + 一次全量 smoke | 我在这棵树上跑的（不是引用）：17/0 · 2876/0 · **3541/0 `smoke 全绿`** | **10 ok / 0 finding** |
| 交付纪律的 flip evidence | 把 P105 两处守卫逐条破坏到 scratch 拷贝 → 我的检查必须抓到 → 还原 → 对照干净 | **11 ok / 0 finding** |

包内合计：**100 ok · 0 finding · 0 bad · 0 skip**（15:11 · 10:37 · 20:12 · 30:15 · 40:15 · 50:7 · 60:3）。

---

## 0 · 对象同一性（验的到底是哪棵树）

```
$ git rev-parse --short HEAD refs/heads/main
（验证时刻）HEAD = 631a7f84 = refs/heads/main      # 我的证据提交之后 HEAD 只多了 docs 提交
$ git merge-base --is-ancestor refs/heads/main HEAD && echo yes
yes
$ git merge-base --is-ancestor fdf1739e refs/heads/main && echo yes     # P105 的两处修复
yes
$ git diff --quiet refs/heads/main HEAD -- skills/ && echo empty
empty            # 0 个文件 —— 所有夹具跑的是 main 的 skills/**
```

## 1 · 我的夹具（自建；预期值自定，不引用 P104/P105 的断言）

- 每格一个**全新 scratch 项目**：`$TMPDIR` 下 fresh `git init` + `team init --no-skills --agents 'dev verify'
  --vcs local --gates true`；出口由 `tests/lib/tmp-root.sh` 回收（`P107_KEEP=1` 才保留并打印路径）。
- 身份隔离：读任何路径之前先 `unset` 掉全部继承的 `TEAM_*`；每条 `team` 调用 `env -u TMUX -u TMUX_PANE`、
  stdin `/dev/null`、60s 上限；`PATH` 第一位是**recording tmux shim**（`has-session` 一律答不存在，其余只记录后
  exit 0，永不触真 server）；`TEAM_PI_BIN=/bin/true`。
- 真工作树从未被读写：40 节每轮都比对调用者的 `git status --porcelain`（忽略本包自己的文件）。
- 修复前/后的翻转（15 节）只在 `$P107_ROOT/flip-tree/` 的拷贝上破坏，交付树的实现文件全程未动
  （`git diff --name-only HEAD -- skills/` = 0）。

## 2 · F1 复核（brief 第 1 条）：空白形状在**任何写入之前**被拒

四格各一个夹具，先落空审计再跑 `team add-agent <name> --register --no-install`。`CASE` 行是每格的原始现场：

```
CASE space-inner  | name=api\ 1     | rc=4   | roster-bytes=no  | audit: ok=0 total=0
     first: ✗ add-agent：席位名 api 1 非法：席位名是一个 token，不能含空白（空格/制表符）；接受 [A-Za-z0-9][A-Za-z0-9._-]*
     sha e22cd3174102 -> e22cd3174102
CASE space-lead   | name=\ api      | rc=4   | roster-bytes=no  | audit: ok=0 total=0
CASE space-trail  | name=api\       | rc=4   | roster-bytes=no  | audit: ok=0 total=0
CASE tab          | name=$'api\t1'  | rc=4   | roster-bytes=no  | audit: ok=0 total=0
CASE empty        | name=''         | rc=2   | roster-bytes=no  | audit: ok=0 total=0
```

| 形状 | 非零 | 名册字节不变（sha256 前后） | 审计无 `result=ok` | 精确码（P105 声称） |
|---|---|---|---|---|
| `api 1` | ✓ rc=4 | ✓（`e22cd317…` → 同值） | ✓（total=0） | ✓ 4 |
| ` api` | ✓ rc=4 | ✓ | ✓ | ✓ 4 |
| `api ` | ✓ rc=4 | ✓ | ✓ | ✓ 4 |
| `api<TAB>1` | ✓ rc=4 | ✓ | ✓ | ✓ 4 |
| 空串 | ✓ rc=2（用法行） | ✓ | ✓ | ✓ 2 |

对照组合法名 `api1`（brief 要求“成功 + 审计恰好一行”）：

```
CASE legal | name=api1 | rc=0 | first:   需要 PM 执行（本命令不代做 git）：
  ✓ 名册行正好变成 TEAM_AGENTS='dev verify api1'
  ✓ 审计恰好一行；那一行 = result=ok actor=cli key=TEAM_AGENTS … new='dev verify api1'
  ✓ 写后契约 bash -n 通过；名册哈希确实变了
```

10c（超出 brief 的补充）：同五个形状走**无旗标**入口，三条断言同样全过（rc=4/4/4/4/2，字节不变，无 ok）。
即：守卫不只在 `--register` 一侧；它在“未知席位”分支之前。

## 3 · teardown 的 token 精确性（brief 第 2 条）

同一夹具、默认名册 `dev verify`，先后两刀：

```
CASE refuse | --agent 'dev verify' | rc=5 | roster=TEAM_AGENTS="dev verify"
     first: ✗ 席位 dev verify 不在名册里：名册是（dev verify）
  ✓ rc 非零/rc=5 ✓ 名册字节不变 ✓ 审计无 result=ok
  （① 之后审计 1 行：… result=refused actor=cli key=TEAM_AGENTS old='dev verify' new='dev verify'）
CASE remove | --agent dev | rc=0 | roster=TEAM_AGENTS='verify'
     first: worktree 仍保留（加 --purge 删除）；分支保留，需要时 git branch -d
  ✓ 名册正好变成 verify ✓ 相对①只新增一行审计 ✓ 恰好一行 ok actor=cli key=TEAM_AGENTS
  ✓ old='dev verify' / new='verify' ✓ 写后 bash -n 通过
```

说明（不是 finding）：拒绝路径留下 **1 行 `result=refused`**（既有审计词汇表，P104 的 O4 同形）；
brief 的“审计一行”我按“成功移除相对拒绝那一刻恰好新增一行 ok”判定并如实记录两者。

## 4 · F2 复核（brief 第 3 条）：三方同源读回

夹具**先埋**写盘前的旧记录 `model=old/legacy-model`（把“同源”问得更狠），再跑：

```
$ team add-agent dev --model vendor/m2 --no-install        # rc=0
       ① 契约行 : TEAM_AGENT_MODELS='dev=vendor/m2'
       ② 记录   : model=vendor/m2 model_src=config
       ③ JSON 席位行: {'agent': 'dev', 'model': 'vendor/m2', 'source': 'config', 'override': True}
  ✓ 旧值 old/legacy-model 已不在记录里 ✓ 审计恰好一行 ok key=TEAM_AGENT_MODELS

$ team add-agent dev --model - --no-install                # rc=0（清覆写）
       ① 契约行 : TEAM_AGENT_MODELS=''
       ② 记录   : model=deepseek/deepseek-flash model_src=config      # 夹具 TEAM_DEFAULT_MODEL
       ③ JSON 席位行: {'agent': 'dev', 'model': 'deepseek/deepseek-flash', 'source': 'config', 'override': False}
  ✓ 审计累计恰好两行 ok key=TEAM_AGENT_MODELS（写入 + 清覆写）
```

**我比对的三个值**：(1) 契约的 `TEAM_AGENT_MODELS` 逐席位 token；(2) `state/dev.env` 的
`model` + `model_src`；(3) `config list --json` 的 `models.seats[dev]`（model/source/override）。
三个方向（写 vendor/m2、清覆写、旧记录覆盖）都同源；`-` 方向记录回到配置解析的默认模型并
`override=False`，与 P105 §6 的口径一致。

## 5 · 走查本身可证伪（brief 第 4 条）：两个**我自己造**的谎言

在 scratch 树上改坏、跑交付树自己的 `tests/routes.sh`（`TEAM_ROUTES_TREE=scratch`）：

```
对照（未改动 scratch）：walk+promises rc=0；== 结果 ==  ✓ 129  ✗ 0  SKIP 0
谎言 A：sed 把 teardown 用法行的 [--force] 换成解析器不认识的 [--p107-ghost-flag]
  ✗ rc=1；== 结果 ==  ✓ 113  ✗ 1；红侧行：
    ✗ 断言 L78：teardown --p107-ghost-flag 被自己的解析器拒绝（原文：✗ teardown: 未知参数 --p107-ghost-flag）
    （其余用法行仍绿：非本条红 = 0）
还原 A → rc=0 绿
谎言 B：sed 把 TEAM_AGENTS 的 schema 注释里 `team teardown --agent <a> --register` 换成 `team p107-ghost`
  ✗ rc=1；== 结果 ==  ✓ 15  ✗ 1；红侧行：
    ✗ promise：TEAM_AGENTS 的注释点名了 CLI 没有的命令「team p107-ghost」
还原 A+B → rc=0；== 结果 ==  ✓ 129  ✗ 0（绿）
收尾：无新增 teamsmith-routes.* 临时根（8 → 8）；调用者的树未被动过
```

## 6 · flip evidence（交付纪律）：破坏实现 → 我的检查必须红 → 还原 → 对照干净

所有破坏只发生在 `$P107_ROOT/flip-tree/` 的**拷贝**上；交付树 `skills/**` 零改动。

| 方向 | 破坏 | 我的同名检查实测 | 判定 |
|---|---|---|---|
| 对照 | 无（交付树） | api1 形状 rc=4/字节不变/ok=0；teardown rc=5/不变/ok=0；model 三方同源 | caught=**no**（正确） |
| F1 | `team_config_seat_violation()` → `return 0` | 形状：rc=1、roster-bytes=**YES**、ok=**1** | caught=**yes** |
| teardown | present 循环换回 `case " $old " in *" $seat "*)`（跨 token） | teardown：rc=**0**、roster-bytes=YES、ok=1 | caught=**yes** |
| F2 | 删掉写入后的 `TEAM_AGENT_MODELS="$newval"` 同进程刷新 | set：state=deepseek/JSON=deepseek·record；clear：state=vendor/m2·record（应为默认+config） | caught=**yes**（两方向） |
| 还原 | 从交付树拷回 | scratch 的 `cmd-config.sh` 与交付树逐字节相同；三个对照重新 caught=no | ✓ |

## 7 · 零回归门禁（brief 第 5 条）——**我本人在本树跑的**

| 门禁 | 命令（原始日志） | 结果 |
|---|---|---|
| 规格库 | `openspec validate --all --strict`（`logs/50-openspec.log`） | rc=0；**Totals: 17 passed, 0 failed (17 items)** |
| 受影响夹具段 | `bash skills/teamsmith/tests/config-cli.sh roster`（`logs/50-config-cli-roster.log`） | rc=0；**✓ 106 ✗ 0 SKIP 0** |
| FAST | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`（`logs/50-fast-smoke.log`） | rc=0；**✓ 2876 ✗ 0**，`全绿行=1`；33 个真进程段落**可见 SKIP**（标记行在日志里） |
| **全量 smoke（决定性）** | `TEAM_SMOKE_LOCK_WAIT=5400 bash skills/teamsmith/tests/smoke.sh </dev/null`（`logs/50-full-smoke.log` + `.rc`） | rc=0；**== 结果 == ✓ 3541 ✗ 0**；`smoke 全绿`；墙钟 1309s（先排队 34s 等 dev2 的全量门禁，随后持锁跑完） |

全量门禁里的关键行（去 ANSI，逐字）：

```
✓ 33 config-cli.sh 全绿（267 条断言）
✓ 51 routes.sh 全绿（172 条断言，1 条可见跳过）        # 含七条翻转；1 条是嵌套 run 的可见 skip
✓ 51 名册/契约夹具（list+validate+roster）全绿（136 条断言）
✓ 38-g② 前提行是真读数（loadavg_1m 7.22 · 逻辑核 32）  # 机器同期待 P98 的 FAST 夹具，未触发“按机器负载跳过”
```

**CI 说明**：账号层仍被挡（引用 PM/P105 复验的结论，不是我的证据）；按 brief，以上本地全量门禁为决定性证据。

## 8 · 哪些是我的证据、哪些只是引用

**我自己的（可复核）**：`pkg/` 里全部夹具、断言、期望值与 `logs/` 原始输出；§2–§7 的所有数字（形状矩阵
5+5+5、teardown 两方向、F2 三方值、两个谎言的红/绿、三个破坏方向的 caught 表、四条门禁的 rc 与计数）都由
`pkg/logs/` 支撑；四条门禁是我在本树亲手跑的。

**引用（只作上下文，不参与判定）**：
- P104 的 `docs/team/reports/P104-dev-bob.md` 与 P105 的 `docs/team/reports/P105-dev.md`（只用来知道要复核
  哪两条 finding；我没有跑它们的夹具当证据，也没有引用它们的前后值）；
- PM 的 `docs/team/reviews/P105.md`（PASS 记录与 CI 说明；其中的门禁数字是 PM 的，我重跑了才算我的）；
- 交付树里的 `tests/config-cli.sh` / `tests/routes.sh` 断言是 dev 写的 —— 我**运行**它们（是门禁的一部分），
  但把它们与我的独立分节分开标注：抓 F1/F2 的是本包的 `10/20/30`，不是它们。

## 9 · 观察（不计 finding）

1. teardown 拒绝留 1 行 `result=refused`（见 §3）——既有审计词汇表，不是 ok，符合 P104 O4 的形状。
2. `--model -` 后 state 记录 = 配置解析的默认模型 + `model_src=config`；与 P105 §6 的口径（不用 `explicit`
   混淆语义）一致。
3. 全量门禁期间机器有 dev3/P98 的 FAST 夹具并发；smoke 的前提行是真读数（loadavg 7.22 / 32 核），
   没有段落因负载被跳过，结果照常全绿。

## 10 · 复现

```
bash docs/team/reports/P107-verify/pkg/run.sh 15 10 20 30 40      # 聚焦（本包夹具 + 翻转，约 4 min）
bash docs/team/reports/P107-verify/pkg/run.sh 50                  # validate + config-cli roster + FAST（约 12 min）
TEAM_SMOKE_LOCK_WAIT=5400 bash skills/teamsmith/tests/smoke.sh </dev/null \
  > docs/team/reports/P107-verify/pkg/logs/50-full-smoke.log 2>&1
echo $? > docs/team/reports/P107-verify/pkg/logs/50-full-smoke.rc
bash docs/team/reports/P107-verify/pkg/run.sh 60                  # 读全量门禁结论（机器可检）
P107_KEEP=1 bash docs/team/reports/P107-verify/pkg/run.sh 15 10 20 30   # 保留夹具并打印路径
```

## 11 · 提交（`task/P107-p107`，local，不 push）

```
10084e05 test(P107): the verifier's own roster re-check package — F1 shapes green (22 ok)
7e5691ad test(P107): teardown, model read-back, walk-lie and break/restore flip sections all green
01550123 test(P107): gate section green — openspec 17/0, config-cli roster 106/0, FAST smoke 2876/0
b0d2d452 test(P107): full smoke green (3541/0) + section 10's flagless extension
<report> docs(P107): the re-verification report — PASS, 100 ok / 0 finding, full smoke 3541/0
```

BLOCKED：无。跨目录改动：无（全部落在 grant 的 `docs/team/reports/P107-verify.md · docs/team/reports/P107-verify/**`）。
