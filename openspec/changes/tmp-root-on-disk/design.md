# tmp-root-on-disk · design

Status: propose phase (planning only — no code in this change's proposal). Every number below was measured on
2026-10-17 in this worktree; the command and its output tail are in `reports/P306-dev2.md`. The PM's own
measurements of the same day are marked **PM**.

## 0 · 现场：临时根今天是什么

| 事实 | 读数（2026-10-17） |
|---|---|
| `/tmp` 的文件系统 | `tmpfs`，15,245,732 KB 总 / 11,763,280 KB 已用 / **3,482,452 KB 可用**（78%）· inode 3,811,433 总 / 562,956 已用 / **3,248,477 空闲** |
| `/var/tmp` 的文件系统 | `overlay`，挂在 `/`，975,437,824 KB 总 / 729,506,500 已用 / **239,160,732 KB 可用**（76%）· `df -i` 报 0（不报 inode 表） |
| 环境里的 `TMPDIR` | **未设**（`TMPDIR=[<unset>]`）—— 所以今天的默认腿就是 `/tmp` |
| `/tmp` 的条目数 | 4,031 个顶层条目；`du -sk /tmp` = 8.95 GB（`df` 说已用 11.7 GB，差额是已删除但仍被进程持有的文件） |
| 本项目的家族目录 | `/tmp` 下 `teamsmith-*` / `review-*` **109** 个 |
| 点开头的 `.teamsmith-*` 目录 | **165** 个，合计 **733,340 KB**（P287 的翻转夹具与探针留下的；点开头 ⇒ 清扫器永不删、只列） |
| 候选根里没有 owner 标记的 | `--status` 列 13 个根，其中 **10** 个写着「无 owner 标记（不是经助手创建的根）」—— 它们是**绕过创建者**用裸 `mktemp -d` 建的（`teamsmith-needs-audit-*`、`teamsmith-select-copies-*`、在跑的 `teamsmith-smoke-*`） |
| 非本项目的占用 | `node-compile-cache` 183 MB、`bunx-1000-bun@latest` 167 MB、若干别的项目的 scratch 树（每个 100–300 MB） |

结论：今天 `/tmp` 的 11.7 GB 里，**我们自己的家族目录不是大头**（家族目录在 `du` 里几乎为 0，最大的一族是点开头的
翻转载荷 733 MB）；大头是机器上别的缓存与 scratch。但这不改变要修的东西：**我们的夹具每写 1 MB 就往这个 15 GB 的
内存盘里写 1 MB**，一次门禁轮次约 95 MB、一个被 KILL 的 `config-cli` 根约 99 MB（`test-tmp-hygiene` 的 design
实测），而它一旦满，派单被拒、门禁假红（2026-09-22 与 2026-10-17 各一次，PM 现场）。磁盘上有 228 GB。

## 1 · 现状：解析写在多少处

| 面 | 今天的形态 | 站点 |
|---|---|---|
| 夹具创建者 | `tmp_root_base() { printf '%s\n' "${TMPDIR:-/tmp}"; }` | `tests/lib/tmp-root.sh` |
| 清扫器 | `BASE="${TMPDIR:-/tmp}"` + 归一化成绝对路径 | `tests/tmp-hygiene.sh` |
| 门禁 | 工作根走创建者；事故诊断 `SMOKE_TMP_DIAG="${TMPDIR:-/tmp}/.teamsmith-smoke-diag.$$.log"`；选段副本 `teamsmith-select.*`；排队标记 | `tests/smoke.sh`（4 处） |
| 派单地板 | `local disk_tmp="${TMPDIR:-/tmp}"` → `team_disk_guard "$disk_tmp" "$wt"` | `scripts/lib/cmd-agents.sh` |
| 地板标签/修法 | `team_disk_label` / `team_disk_remedy` 用 `"${TMPDIR:-/tmp}"` 比较 | `scripts/lib/common.sh` |
| 容量读数 | `team_capacity_line` 的默认路径数组 | `scripts/lib/common.sh` |
| doctor 行 | `team_disk_headroom_lines` 的默认路径数组 | `scripts/lib/cmd-status.sh` |
| 控制台数据读 | 面板的余量条目路径 | `scripts/lib/cmd-watch.sh` |
| 产品临时模板 | `teamsmith-lock-*`、`teamsmith-inotify-probe.*`、`teamsmith-npm.*`、`teamsmith-review-queue.*`、`teamsmith-p91-merge3-*` | `common.sh`、`cmd-watch.sh`、`cmd-review.sh` |
| 门禁锁 | `${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}` + 点开头的伴生锁 | `scripts/lib/gate-lock.sh`、`cmd-review.sh`、`smoke.sh` |
| 总量 | `skills/**` 里 `${TMPDIR:-/tmp}` 共 **171** 处（`scripts/` 18、`tests/` 146、其余 7），其中 **84** 处夹具站点是**为隔离而设** `TMPDIR`；`openspec/specs/**` 有 **12** 处场景写成 `TMPDIR=D` | — |

这就是 brief 说的「机制已经在，缺的是默认值」：机制在，但**算这个根的地方有十几处**，而位移默认值恰恰要求它们
对同一个答案。

## 2 · D1 · 解析顺序：`TMPDIR` → `TEAM_TMP_ROOT` → 平台默认

brief 的字面顺序是 `TEAM_TMP_ROOT` → `TMPDIR` → 默认。**提案按相反的顺序落笔**，理由是测出来的，不是偏好：

- `TMPDIR` 在本仓是**进程级隔离的唯一机制**：84 处夹具站点用 `TMPDIR=<私有目录>` 把被跑的东西关进自己的根
  （`smoke.sh` 的嵌套运行、`tmp-root.sh --self-test`、`section-guard.sh` 的夹具、`flip-p171.sh` 的 scratch 运行…），
  规格里有 12 处 scenario 直接写成 `TMPDIR=D`。
- 如果 `TEAM_TMP_ROOT` 排在它前面，那么**任何在契约里钉住 `TEAM_TMP_ROOT` 的项目，它的门禁隔离断言会集体变红**：
  被跑的子进程会忽略父进程给的 `TMPDIR`，写进钉住的那个共享根，而隔离断言（`team paths` 指向临时根）会当场判红。
  也就是说，字面顺序会让「钉住」这个功能**一旦启用就不能跑门禁**。
- 反过来，`TMPDIR` 在前只丢一件事：**环境里一个 `TMPDIR` 会盖过项目钉的值**。那件事不许静默（§2.2）。

### 2.1 解析器（唯一实现，`scripts/lib/common.sh`）

```
team_tmp_root()           # → 绝对路径（永不为空）
team_tmp_root_source()    # → tmpdir | config | default
team_tmp_root_default()   # → /var/tmp/teamsmith-<ns>（/var/tmp 是可写目录时），否则 /tmp
team_tmp_root_stat_path() # → 根存在就是根；否则最近的存在祖先（只读面判余量用）
team_tmp_root_usable()    # → 0 = 存在、是目录、可写
```

- `<ns>` 用 `team_project_ns()`（`<slug>-<hash8>`，P287 已在用），所以同一项目的所有 worktree 同一个默认目录，
  两个项目不可能撞；默认目录名因此可读（`teamsmith-pm_skills-deb708fe`）。
- 解析器**不创建任何东西**（纯函数）。创建只在两处发生：创建者的默认腿（§2.3），以及运维自己 `mkdir`。
- 相对路径、空串、`~` 不展开：`TEAM_TMP_ROOT` 与 `TMPDIR` 必须给绝对路径；相对路径 = **具名失败**（不猜 CWD 相对的意思）。

### 2.2 分歧必须可见

当 `TMPDIR` 与 `TEAM_TMP_ROOT` 都存在且不同时，每个会打印根的面打一行：

```
临时根：/var/tmp/teamsmith-<ns>（来源 TMPDIR；项目配置 TEAM_TMP_ROOT=/tmp 未生效）
```

理由：这正是「用户以为钉住了、其实没钉住」的现场形状；一行字把静默变成可观测。`references/config.md` 的键行写明
「要让契约里的值生效，别让环境里出现 `TMPDIR`（本仓的嵌套夹具会自己设它，那是它们**故意**的隔离）」。

### 2.3 创建、归属与不可用

| 情形 | 行为 |
|---|---|
| 默认腿的目录不存在 | **创建者**建（`mkdir -p`，`0700`），并打印它建了什么；这是唯一被自动创建的目录 |
| 默认腿建不出来（只读、ENOSPC、权限） | 具名失败：路径 + 原因（`errno` 的人话）+ `修法：`；不回落 |
| 显式选定的根不存在 / 不是目录 / 不可写 | 具名失败（创建者 exit 3；派单是阻塞项）；不回落、不代替用户建 |
| 只读面（doctor / `--status` / 控制台读）遇到未创建的默认根 | 按**最近的存在祖先**判余量，行里写明「尚未创建，按 `<祖先>` 的文件系统判」，**不创建**、不编数字 |
| 只读面遇到显式选定但不可用的根 | 报出来（`warn`），不判健康；不创建 |

## 3 · D2 · 默认值：`/var/tmp/teamsmith-<ns>`

三条理由（都来自 §0 的读数）：

1. **磁盘，不是内存**：本机 `/tmp` 是 tmpfs，15 GB 的写盘 = 15 GB 的 RAM；`/var/tmp` 在磁盘上，228 GB 可用。
   夹具写盘不再与 OOM 抢同一个池。
2. **跨重启保留**：`/var/tmp` 的语义就是「重启后还在的临时文件」（FHS）；被 KILL 的运行的残留不会因为重启而消失，
   于是「残留可见 + 一条命令回收」这条设计在重启后仍然成立。
3. **与既有的机器级共享面同构**：`--status`/`--sweep` 的归属判定、锁对、容器跑法都建立在「一处机器级临时根」上；
   按项目分包只是在这一层下面多一个父目录，不需要重写那些判据。

备选与代价：

| 备选 | 代价 |
|---|---|
| `/var/tmp/<ns>`（少一层） | 家族名 `teamsmith-` 这条清扫器判据被挪走；`/var/tmp` 是 1777 共享目录，家族名是第一道「这是我们的」 |
| `~/.cache/teamsmith/tmp` | 机器级共享面变成用户面：容器/CI（`--user`、只读挂载）与 `--status` 的归属判定都要重写 |
| `/tmp`（现状） | 本变更要解决的问题 |

## 4 · D3 · 名字不改

根仍叫 `teamsmith-<kind>-<ns>.XXXXXX`，落在解析出的基准下。于是默认腿的实际形状是
`/var/tmp/teamsmith-<ns>/teamsmith-<kind>-<ns>.XXXXXX` —— ns 出现两次，是**有意的**：

- 名字规则**不依赖基准是谁**，`--lint`、`tmp_root_path_ok`、`--sweep` 的候选谓词一个字不用改；
- 回滚到 `/tmp`（`TEAM_TMP_ROOT=/tmp`）时 P287 的保护照旧生效（根名仍带 ns，别的项目的 `rm -rf /tmp/teamsmith-*`
  仍然够不着活运行 —— 它连名字都匹配不上）；
- 反例（私有基准下去掉 ns）：规则变成有条件的，清扫器与 lint 都要按「基准是否私有」分两种形状，红侧翻倍。

## 5 · D5 · 契约键：位置键，不是可编辑设置

`TEAM_TMP_ROOT` 与 `TEAM_ROOT` / `TEAM_MAIN_ROOT` / `TEAM_STATE_DIR` / `TEAM_DOCS_DIR` 同族，按**位置键**登记：

```
TEAM_TMP_ROOT|refuse|path|dir,opt|plain||-|位置：临时根目录（空 = 按 TMPDIR → 平台默认自动解析）……||identity
```

- `refuse` 类 ⇒ `team config set` 退出 5、只能改 `.pi/team/config.sh` —— 与既有位置键同一语义（改位置是运维动作）。
- 四个面同时登记：`scripts/lib/cmd-config.sh` 的 schema 表、`templates/config.sh.tmpl`、`references/config.md`、
  控制台 `scripts/panel/src/strings/{zh,en}.ts` 的 `label_TEAM_TMP_ROOT`（字符串门禁对**每个** schema 键双向走查）。
- `panel.js` 是提交的构建产物：改了 strings 必须用钉住的工具链重建，否则沙盒重建的逐字节比对会红。
- 写入侧不校验目录是否存在（`path` 校验器只拒空，`dir,opt` 允许空）——**所以不可用根的具名失败只能在解析/创建侧发生**，
  这正是红侧 ③ 要钉的地方。

## 6 · D6 · 锁：路径不动，余量只警告

P287 已把门禁锁冻成一对：发布路径 `${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`（兼容声明，跨版本串行）
+ 点开头的伴生锁（真正的互斥）。**本变更不搬这两个文件**：

- 它们是**机器级**互斥，不是项目级数据；搬进按项目分包的基准会让两个项目/两个检出并发跑全量（P287 D1 已否过）。
- 搬走还会在升级窗口里**新开**一个静默并发窗口（旧版本仍取 `/tmp` 的那把）。
- 代价如实写：`/tmp` 满时**取锁**仍会失败。那件事本来就该响亮（P287 的锁守卫会点名 + 停跑），本变更把它放回
  `team doctor` 的一条**只警告**行（锁所在的文件系统若没被别的行覆盖）。
- **它不进派单的地板**：brief 的红侧 ② 明确「选定的根很空、`/tmp` 很满时不许拒绝」。所以「拒绝」与「警告」在这里
  被刻意分开：地板只判解析出的根 + 工作树；锁的文件系统只警告。

## 7 · D7 · 旧默认根的残留：可见 + 一条命令

升级后旧根的残留不会自己搬家，也不会消失（`/tmp` 不跨重启，但机器不重启就一直在）。`--status` 多一段**只读**输出：

```
旧默认根（${TMPDIR:-/tmp}）下还有 109 个家族目录：回收用
  TMPDIR=/tmp bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run   # 先看清单
  TMPDIR=/tmp bash skills/teamsmith/tests/tmp-hygiene.sh --sweep
```

- 一次 `--sweep` 只作用于一个基准（解析出的那个），**不新增第二套候选规则**；
- 打印的命令把旧基准显式选出来（`TMPDIR=/tmp`），于是回收动作与今天的实现完全一致（归属证明、占用证明、年龄判据
  一个都不少），而 `TMPDIR=/tmp` 在 D1 的顺序下**一定生效**（`TMPDIR` 在前）；
- 不做自动迁移：删别人的活运行是 D37 家族的事故形状（P287 的现场就是这么来的）。

## 8 · D8 · 红侧（brief 第 6 条的三条）

| # | 要证伪的缺陷 | 怎么造 | 期望 |
|---|---|---|---|
| ① | 解析退回「各处自己算」 | 静态：`--lint` 的新规则命中一份**自己算根**的副本（产品调用点写 `${TMPDIR:-/tmp}`）；动态：fixture-mode 影子让清扫器/门禁用 `${TMPDIR:-/tmp}` 自算，而解析器答磁盘默认 | lint：`<file>:<line>` finding、rc=1；动态：两个基准对不上，断言点名两个路径与分歧的面，撤掉影子即绿 |
| ② | 地板绑回固定的 `/tmp` | `TEAM_DISK_STATS_FILE` 给「解析出的根」一行很空（5 GB / 2.9 M inode）、给 `/tmp` 一行很满（120 MB / 40000 inode）；再开 fixture-mode 的 `--break=fixed-floor` 把地板指回 `/tmp` | 正常：派单**不拒**、容量行点名解析出的根；`--break=fixed-floor`：同一输入**拒绝并点名 `/tmp`**（红），撤掉即绿 |
| ③ | 选定根不可用时静默退回 `/tmp` | `TEAM_TMP_ROOT` 指向不存在的路径，再指向一个不可写的目录；`tmp-root.sh --self-test --break=missing-root` 把「回落」放回去 | 正常：具名失败（路径 + 原因 + `修法：`），`/tmp` 下**没有**新条目；`--break=missing-root`：自检红并点名「静默回落」 |

三条红侧都落在 §40（临时根纪律）的既有断言集里：①②③ 走 `tmp-hygiene.sh --self-test` 的新 stage，② 另有一条走
`team dispatch --print` 的夹具（§6b 的矩阵里加一臂），①的动态那半可以借用既有的 34c 影子形态。**翻转方向固定**：
`--break=<stage>` 必须红、撤掉必须绿（PM 复验时按这条重跑）。

## 9 · D9 · 顺带量到、但不修的三条（记 finding，不塞进本变更）

1. **`TEAM_NOTIFY_LOG` 的默认值仍是 `/tmp/teamsmith-notify.log`**（schema 的 `apply|path|file,opt` 行）：走同一个
   「别写内存盘」的道理，但它是**日志**、是契约键、有自己的默认值与升级故事，且通知路径必须在临时根不可用时也能写 —
   所以它不该跟着临时根走。要改是另一个变更。
2. **点开头的 `.teamsmith-*` 目录 165 个 / 733 MB**：点开头 ⇒ 既不是候选、也不计入根，`--status` 只在「不是根」段列
   目录本身。这是 P287 的翻转夹具留下的形状；清扫器要不要回收「点开头的**目录**」是另一个规则问题（今天点开头一律
   不删，是因为诊断/台账是文件而不是目录，这个前提已经不总成立）。
3. **13 个候选根里 10 个没有 owner 标记**：它们是绕过创建者的裸 `mktemp -d`。本变更的 ① 红侧（lint 的「自己算根」
   规则）会让这类站点显形，但**不**顺手把它们改成创建者 —— 那是逐站点的判断，留给后续任务。

## 10 · 迁移与回滚

**默认行为的变化**（升级后第一次运行就会遇到）：

- Linux 上 `TMPDIR` 未设时，夹具与门禁的根从 `/tmp/...` 改到 `/var/tmp/teamsmith-<ns>/...`；磁盘上、跨重启保留；
- 旧位置的残留不会自己搬；`--status` 会把旧默认根的残留数出来并给出**一条**回收命令（§7）；
- 锁的路径、语义、伴生锁都**没动**，所以升级窗口里新旧版本仍经发布路径串行（P287 的合同保持）。

**回滚**：`TEAM_TMP_ROOT=/tmp`（写进契约，持久）或 `TMPDIR=/tmp`（一次调用）。两者都让解析器回到旧位置，不需要数据迁移；
已经在磁盘上的根留着，`--status` 会把它们列成「当前基准之外」（以及旧根残留段的镜像情形）。

**回滚后要注意的两件事**（写进 `references/migration.md` §7）：回滚到旧版本会同时把「一处解析」的 lint 规则带回去
（新版树的 finding 在旧版不存在），以及磁盘上的根不会被旧版看见 —— 旧版的清扫器仍只看 `/tmp`，需要在同一路径上
手动确认。

## 11 · 边界（本变更不做、也不假装做到的）

- **不改 CI 的容器跑法**：`.github/workflows/gates.yml` 仍把产物目录挂到 `/tmp`、`HOME=/tmp`；解析器在容器里跑，
  容器自己的 `/tmp` 是容器层（不是 tmpfs），所以默认值变化不改变 CI 语义。改成
  `-e TEAM_TMP_ROOT=/artifacts` 是下一步，属于 CI 的裁量。
- **磁盘与仓库同命**：`/var/tmp` 在 `/`（overlay）上，而本仓在 `/home`（同一个 LUKS 设备、不同挂载点）。也就是说
  临时根与仓库**共享一块盘**：盘满时不再只是门禁红，提交也会受影响。这是换到磁盘的代价，换回来的是「不再吃内存」与
  228 GB 的余量；地板与医生行判的正是这一个文件系统，所以它在满之前会先警告。
- **inode 腿在磁盘上会变空**：`overlay` 不报 inode 表（`df -i` 为 0）⇒ 地板与医生行的 inode 腿变成「不适用」。
  今天 `/tmp` 的 inode 表恰好是 2026-09-22 那次死因之一（4,645 / 3,811,434 空闲），换盘之后这条腿就不再保护我们 ——
  这是**诚实的退化**，写进 `references/troubleshooting.md`，不作为「已解决」。
- 不改门禁判定口径、不改 `TEAM_SMOKE_FAST` 分层、不给清扫器加自动运行、不动 `review-<ID>` 的命名。
