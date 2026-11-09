# P427 · 夜间检查的三条失败

agent: dev   status: delivered（返修）   time: 2026-11-09T02:50Z
branch: `task/P427-doctor-readonly-nightly`   PR/MR: -（local 模式，未 push）

## 答案

三条红的根因同一个：**医生的外部子进程会写 `os.tmpdir()`**，而 `os.tmpdir()` 正是「解析出的临时根」。
写的人有三位：Node ≥ 23 的编译缓存（`node-compile-cache/`）、jiti 的转换缓存（`jiti/`）、pi 插件的日志
（`pi/magic-context/…`）。它们不只是往里写文件 —— **它们会把这个目录递归建出来**，于是一个「只读」的
doctor 把操作者设的根建了出来、余量行失去「尚未创建」。

复核退回的那一版（把子进程的 `TMPDIR` 指到最近的存在祖先）是错的：它只是把写入挪到**被检的基准目录**里。
现在这一版**不挪目录，关掉写入**：三个环境开关，`TMPDIR` 原样不动。

| 写的人 | 怎么关的 |
|---|---|
| Node 编译缓存 | `NODE_DISABLE_COMPILE_CACHE=1`（`enableCompileCache()` 自己认它） |
| jiti 转换缓存 | `JITI_FS_CACHE=false` |
| pi 插件日志（magic-context） | `MAGIC_CONTEXT_LOG_PATH=/dev/null` |

`team_readonly_run` 就是这三行；其余判据、余量行、报告读的根一个字没改。`isolation-ledger.sh` 那条 lint
独立无关，改的是它自己的临时根创建方式（走 `tests/lib/tmp-root.sh` 的唯一创建者）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | `team_readonly_run` = 关掉子进程三个写入开关（`TMPDIR` 不动）；上一版的 `team_tmp_root_child_tmpdir` 与 TMPDIR 改写整段删除；`team_inotify_probe` 走同一入口 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | doctor 的 `pi --version` / `pi --help`、`openspec --version`、`关键回复运行` 的 node 诊断走 `team_readonly_run` |
| `skills/teamsmith/tests/isolation-ledger.sh` | 临时根改 `tmp_root_create isolation`（owned 家族 + ns + 台账 + 退出回收） |

没有改断言、没有关 lint、没有加豁免、没有改隔离判据；没有把写入转交给共享临时目录。

## Verification evidence (must have actually been run)

### ① 复核退回的那条：真实 pi 下 §40（PM 复现用的同一条命令）

```
$ PATH="$HOME/.bun/bin:$PATH" TEAM_META=1 bash skills/teamsmith/tests/smoke.sh --select 40 </dev/null
  ✓ 40 P314 doctor 没有创建默认根（…/p314-doctor/base/teamsmith-proj-deb708fe 跑完仍然不存在；基准下也一个条目没多）
  ✓ 40 P314 doctor 前后 .pi/team/state/ 全树哈希不变（20dbee0f693e）
  ✓ 40 P314 余量行写清「尚未创建」并按祖先判
  ✓ 40 P314 余量行说清谁会建它（不是本命令）
  ✓ 40 P314 正对照：根存在时不再说「尚未创建」，仍印出来源
  ✓ 40 P314 source=config 腿：跑完 doctor 根仍然不存在
  ✓ 40 P314 source=tmpdir 腿：跑完 doctor 根仍然不存在
  ✓ 40 lint 干净：检查了 27 个 mktemp 模板与面板源码行…
#5 40 · 临时根纪律（P53：TMPDIR / owned 家族 / 泄漏断言 / lint） · 参考 用时 72s · ✓42 ✗0 SKIP0 · ticks 42
== 选段结果 ==  ✓ 66  ✗ 0
```

改前（同一形状，退回的那一版）：`✗ 40 P314 doctor 在默认基准下留下了东西（…/base/node-compile-cache …/base/jiti …）`、`✓41 ✗1`。

### ② 三种场景各自干净（本机独立夹具 + 真实 pi 在 PATH 上）

```
① 显式 TMPDIR=<尚不存在的根>   → ghost absent；余量行「尚未创建，按 <祖先> 的文件系统判 … source=tmpdir」
② 默认根（TMPDIR 未设）        → base 条目前后 0 → 0（医生跑完一个条目没多）
③ 显式 TEAM_TMP_ROOT=<不存在>  → ghost absent；余量行「不会被自动创建 + mkdir -p -m 700 '<路径>'」
④ 三种场景之后 .pi/team/state/ 仍然为空（find 无输出）
   doctor 的读数没退化：pi ✓ 1.5.0 · OpenSpec CLI ✓ 1.16.0（…/openspec）· JS 运行时 ✓ node v24.22.1 · 关键回复运行 ! unknown …（未注册，符合预期）
```

### ③ 开关的牙齿（哪一个开关关掉哪一个写入者，逐个实测）

```
$ TMPDIR=<ghost> ~/.bun/bin/pi --version        → CREATED ghost/node-compile-cache
$ TMPDIR=<ghost> ~/.bun/bin/pi --help           → CREATED ghost/node-compile-cache + ghost/jiti
$ TMPDIR=<ghost> ~/.bun/bin/pi --help           （NODE_DISABLE_COMPILE_CACHE=1）
                                                → CREATED ghost/jiti + ghost/pi          ← 还有两位
$ TMPDIR=<ghost> … 三个开关全开                  → absent（pi --version / pi --help / openspec --version / node 诊断四条都 absent）
$ … 三个开关全开 pi --help | grep -c -- --session-id
1                                                ← 能力探针仍然认得出这个旗标
```

### ④ 受影响的医生面（机制换了，所以在新 tip 上重跑）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 1,3,4c,8,12b-pi3 </dev/null
#5 1 · doctor（未初始化应失败）· ✓2 ✗0        #7 3 · doctor（初始化后）· ✓7 ✗0
#9 4c · 看板重复 ID（M48）· ✓42 ✗0             #14 8 · 从 agent worktree 调用 CLI · ✓2 ✗0
#17 12b-pi3 · M53 降级通道可见（doctor/status/面板 + inotify 余量）· ✓53 ✗0
== 选段结果 ==  ✓ 601  ✗ 0
```

### ⑤ 其余验收命令

```
$ bash skills/teamsmith/tests/isolation-ledger.sh
isolation-ledger: pass=15 fail=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1     (rc=0)
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2436 hits=0 names=ok user=resolved   (rc=0，写完本报告后复跑)
$ git diff --check     (空，rc=0)
```

- Verdict: **pass**
- Notes:
  - brief 的 `--names-file .pi/team/forbidden-names.txt` 在本 worktree 不存在（`.pi/**` 是 PM 独占、未进分支），按字面跑是
    `rc=3 SKIP names=missing`（**不是通过**）；上面那行是指到主检出同一份名单后的真判定。
  - brief 的 `smoke.sh --select 40` 不带 `TEAM_META=1` 只会打印「二阶 · 默认不跑」的 SKIP；真跑都加了 `TEAM_META=1`。
  - **没有跑**全量门禁（brief 不跑）；**没有**在 GitHub 夜间 CI 上复跑（要推分支触发 workflow，超出本任务边界）。
  - `--paths` 对这个改动选出 67 个键≈全量，只跑了医生面 5 个键 + 闭包 8 段，其余没跑，不能引用为「全绿」。
  - 开关里有两项点名了第三方（jiti、pi 插件的日志路径）。理由见「决策」；若它们换名字，§40 会立刻红（那就是它的作用）。
- Ledger ban: 见 ⑤（含写完报告后的复跑），`hits=0`、`rc=0`。

## Flip evidence (required for defect-fix tasks)

两次反向改坏都在真实 pi 的形状下跑 §40，跑完逐字节还原（`git diff --stat` 空）。

**A. 把三个开关拿掉**（子进程重新写缓存）→ 复核退回前的那两条原红：

```
  ✗ 40 P314 source=tmpdir 腿：没说「尚未创建」
  ✗ 40 P314 source=tmpdir 腿：doctor 把显式给的根建出来了（…/p314-doctor-legs/ghost-tmpdir）—— 只读面不许写盘
#5 40 · 参考 用时 54s · ✓40 ✗2   == 选段结果 ==  ✓ 64  ✗ 2
```

**B. 把「指到最近存在祖先」的旧写法放回去**（就是复核退回的那个形状）→ 复核点名的那条红：

```
  ✗ 40 P314 doctor 在默认基准下留下了东西（…/p314-doctor/base/node-compile-cache …/p314-doctor/base/jiti …/p314-doctor/base/pi ）
#5 40 · 参考 用时 60s · ✓41 ✗1   == 选段结果 ==  ✓ 65  ✗ 1
```

（复核日志里的那条只列了 `node-compile-cache … jiti`；这次多一个 `base/pi`，是 pi 插件日志目录同一个形状，一并点名。）
第二条红（lint）的翻转就是改前/改后本身：`isolation-ledger.sh:10 相对/非临时根的模板（-p）` → `lint 干净`。

## Decisions and deviations

- **不换目录，关写入**。只读面给子进程一个「别的临时目录」只是把污染挪个地方（复核就是这条）；开关是探针命令的既有做法
  （同 `GIT_OPTIONAL_LOCKS=0` / `PIP_NO_CACHE_DIR=1`），而且**根与基准目录的最终状态一个字都不变**，不需要任何补偿性清理。
- 三个开关里有两项点名第三方（`JITI_FS_CACHE`、`MAGIC_CONTEXT_LOG_PATH`）。这是「已知写入者」的清单，不是兼容矩阵：
  它只影响医生跑探针的那几秒；新写入者会被 §40 同一批判据咬住，代码注释写明「到那时在这里补一个开关，而不是换目录」。
- 上一版的 `team_tmp_root_child_tmpdir` 整段删除（净零：没有留下第二套判据，也没有留下白名单）。
- 没有新增任何守卫/夹具断言。

## Suggested next steps

- PM 复验：`PATH="$HOME/.bun/bin:$PATH" TEAM_META=1 bash skills/teamsmith/tests/smoke.sh --select 40`（~70s）与
  `bash skills/teamsmith/tests/isolation-ledger.sh`。
- 夜间 meta 作业要等下一夜（或手动 `workflow_dispatch`）才会消掉这三条红。
- 无 `BLOCKED:`。
