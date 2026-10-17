# tmp-root-on-disk · 临时根的默认值从内存盘（`/tmp`）换到磁盘上、按项目分包的一个目录

## Why

临时根今天是 `${TMPDIR:-/tmp}`，本机 `/tmp` 是 **tmpfs（15 GB 的内存盘）**：夹具往临时根写多少字节，就吃多少内存与
inode —— 与 OOM 杀进程、swap 打满**同一个池**。2026-09-22 它满过一次（可用 0 字节、inode 表也满），2026-10-17 又到
过一次边缘，两次的后果都一样：**派单被拒**（容量地板）与**门禁假红**（ENOSPC 与代码无关）。这不是「谁不小心」，
而是「默认值指向了一个容量与内存共享的盘」——所以修的是默认值，而不是提醒。

本机同一天的两次读数（PM 2026-10-17 与我同日复测，命令在报告里）：

| 路径 | 文件系统 | 总量 | 已用 | 可用 | inode 表 |
|---|---|---|---|---|---|
| `/tmp` | `tmpfs`（内存盘） | 15.2 GB | 11.7 GB（78%） | **3.3 GB** | 3,811,433 总数 / 3,248,477 空闲 |
| `/var/tmp` | `overlay`（磁盘，挂在 `/`） | 930 GB | 696 GB（76%） | **228 GB** | 不报（`df -i` 为 0） |

关键在于：**机制早就在**（`TMPDIR` 在 `skills/**` 里有 171 处引用，`tmp-hygiene.sh` 认它，实测在
`/var/tmp` 下 `--status` 正常），缺的只是**默认值**与**一处解析**。因此本变更不是新机制，是**把默认值挪到磁盘、把
「谁算这个根」收敛成一个函数，并让余量地板、清扫器、门禁与医生行都跟着那一个根走**。

## What Changes

### 1 · 一处解析：`team_tmp_root()`（ADDED `verification#One resolution decides every temp path, and it says how it decided`）

解析顺序（**这一次改动就要把顺序钉死，且只有一份实现**）：

1. `TMPDIR` —— 调用进程自己设了（非空）就用它；这是标准约定，也是本仓**所有嵌套夹具做隔离**用的机制（实测 **84** 处
   夹具站点设 `TMPDIR`，`openspec/specs/**` 里有 **12** 处场景写成 `TMPDIR=D`）；
2. `TEAM_TMP_ROOT` —— 项目契约里的键（新，可空）；
3. 平台默认 —— `/var/tmp/teamsmith-<ns>`（`/var/tmp` 是可写目录时），否则 `/tmp`。

`<ns>` 用既有的 `team_project_ns()`（`<slug>-<hash8>`，P287 已在用），所以同一项目的所有 worktree 同一个目录、两个项目
不可能撞。**每个打印这个根的面都要打印它是怎么解析出来的**（`source=tmpdir|config|default`）；当 `TMPDIR` 与
`TEAM_TMP_ROOT` 同时存在且不同时，说一句「谁赢了、另一个没用」——分歧允许，**静默不允许**。

调用点因此全部归口：夹具创建者、门禁自己的工作根与事故诊断、清扫器的基准、派单余量地板判的路径（以及这条路径的
**标签与修法文案**）、`team doctor` 的余量行、控制台的数据读、以及每一个直接落在根下的临时模板。

### 2 · 默认值：磁盘上、按项目一包（MODIFIED `verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed`）

默认腿变成 `/var/tmp/teamsmith-<ns>`：

- **为什么不留在 `/tmp`**：它是 tmpfs —— 写盘等于吃内存，`/tmp` 满与 OOM 是同一件事的两面；而且它**不跨重启**，
  被 KILL 的运行留下的残留只能靠人记着清。默认落在磁盘上之后，同一个门禁轮次的 95 MB 不再从内存里出，
  3.3 GB 的余量也不再是我们自己的占用造成的。
- **为什么不是家目录（`~/.cache/...`）**：临时根目前是**机器级共享面**，`--status` / `--sweep` 的归属判定、锁对、
  容器跑法都建立在「同一台机器上的一处临时根」上；搬进家目录会把「共享面」变成「某个用户的面」，CI 与容器里的
  语义就要重写一遍。这不是这次要付的代价。
- **为什么不是裸的 `/var/tmp/<ns>`**：`/var/tmp` 是 1777 的共享目录，家族名 `teamsmith-` 是清扫器「这是我们自己的」
  的第一道判据；按项目一包的是**父目录**，里面的根名规则**不改**（见 D3）。

创建与归属（D4）：默认腿的这个目录由**创建者**按需建（`0700`，是本变更里唯一被自动创建的目录）；**显式选定的根
必须已经存在且可写**，否则**具名失败**（路径 + 原因 + 修法），绝不静默退回 `/tmp`。只读面（`team doctor`、
`--status`、控制台）遇到「默认根还没建」时**按最近的存在祖先判**并说出来，**不创建**任何东西。

### 3 · 余量地板绑定到选定根（MODIFIED `dispatch#The capacity floor protects the host`、MODIFIED `watchdog#\`team doctor\` reports the temp root's headroom`）

- 字节 + inode 两条腿判的是**解析出的那个根**（不是在本处再算一遍的 `/tmp`）；拒绝文案点名那个**路径**、它的
  **来源**、读数、跨过的阈值与 `修法：`；标签（`临时根` vs `工作树`）与修法也用同一个根判定 —— 今天这两处是按
  `${TMPDIR:-/tmp}` 比较的，根一换，文案就会把临时根说成工作树、把修法指错地方。
- **不可用的选定根是阻塞项**：显式选定的根不存在 / 不是目录 / 不可写 → 拒绝派单并给修法（今天这种情况会走「读不到 →
  不判」的沉默分支，正是 brief 要堵的那条）。
- **锁的文件系统在这里刻意不判**：`/tmp` 满会挡住门禁取锁（P287 的守卫会响亮地停），但它**不该拒绝派单** ——
  所以那条腿只在 `team doctor` 上**只警告不拒绝**（见 D6）。

### 4 · 清扫器走同一个根，旧默认根的残留可见且一条命令可达（MODIFIED `verification#Killed-run residue is identifiable and reclaimable through one entry`）

- `--status` 的表头从 `临时根：/tmp` 变成 `临时根：<解析出的路径>（来源 <source>）`；`--sweep` 的候选谓词、占用证明、
  年龄判据、`review-<ID>` 的记录判据**一个字不改**，只是基准跟着解析出的根走。
- 当解析出的根**不是**旧默认根（`${TMPDIR:-/tmp}`）时，`--status` 多印一段**只读**的「旧默认根下的残留：N 个家族
  目录」以及**一条**能回收它们的命令（`TMPDIR=/tmp bash …/tmp-hygiene.sh --sweep …`）—— 一次 `--sweep` 只作用于一个
  基准，第二个基准不新增候选规则、不新增第二份实现。

### 5 · 静态闸加第二条规则（MODIFIED `verification#The fixtures' temp-root ownership rule is enforced by a static check`）

`--lint` 除了今天四条（写死绝对目录 / 不在家族里 / 不带 ns / 根下的每运行条目既非点开头也不带 ns），再加一条：
**任何自己算临时根的地方都是 finding**（`${TMPDIR:-/tmp}`、`${TMPDIR}`、JS 侧的同类回落、写死 `/tmp/…` 的 `mktemp`
模板），唯二豁免是解析器自己的定义与创建者对它的转调。理由就是 red side ①：**两处各算 = 两个答案 = 清扫器与门禁
对不上基准**。

### 6 · 配置键（契约面）

`TEAM_TMP_ROOT` 按**位置键**登记（与 `TEAM_ROOT` / `TEAM_STATE_DIR` / `TEAM_MAIN_ROOT` 同族）：`refuse` 类、
`path` + `dir,opt`、默认空、组 `identity`、只能改项目配置文件（`team config set` 对它退出 5）。四个面都要登记
（schema 表、`templates/config.sh.tmpl`、`references/config.md`、控制台 zh/en 标签），控制台的标签进 `panel.js`
**提交的构建产物**（必须用钉住的工具链重建）。

### 7 · 迁移与回滚

- **默认行为变化**（升级后第一次运行就会遇到）写进 `skills/teamsmith/CHANGELOG.md` 与
  `references/migration.md` §5（行为变化表）：Linux 上 `TMPDIR` 未设时，门禁与夹具的根从 `/tmp` 改到
  `/var/tmp/teamsmith-<ns>`；磁盘上、跨重启保留；旧根的残留不会自己搬，用 §4 的那一条命令回收。
- **回滚**：`TEAM_TMP_ROOT=/tmp`（写进契约）或 `TMPDIR=/tmp`（一次调用）即恢复旧位置；不需要数据迁移，锁的路径与
  语义**没动**，所以升级窗口里新旧版本仍然串行。

## Capabilities

### Modified Capabilities

- `verification`：
  - **MODIFIED** `A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed` —— 解析腿改成「一处解析」
    并加「默认根磁盘化 / 显式根必须可用 / 打印来源」的正文；既有正文（ns、标记、台账、点开头或带 ns、`INT`/`TERM`
    回收、`TEAM_TMP_KEEP`、只对记录过的 pid 发信号）逐字保留；新增三条 scenario（默认腿在磁盘上且不碰 `/tmp`、
    进程自己的 `TMPDIR` 赢且分歧被打印、不可用的选定根具名失败且不回落）。
  - **MODIFIED** `Killed-run residue is identifiable and reclaimable through one entry` —— `--status` 印解析出的根与来源、
    旧默认根残留的只读计数与一条回收命令；`--sweep` 仍旧一次一个基准；既有四条 scenario 逐字保留 + 一条新 scenario。
  - **MODIFIED** `The fixtures' temp-root ownership rule is enforced by a static check` —— 加「自己算根 = finding」与
    第三条红侧副本；既有三条 scenario 逐字保留 + 一条新 scenario。
  - **ADDED** `One resolution decides every temp path, and it says how it decided` —— 一处解析、解析顺序、磁盘默认的理由、
    只读面按最近祖先判且不创建、打印来源；三条 scenario。
- `dispatch`：
  - **MODIFIED** `The capacity floor protects the host` —— 判的是解析出的根（不是本处再算的默认）、拒绝文案带路径与来源、
    显式选定根不可用 → 阻塞项且不回落、未创建的默认根按祖先判、锁的文件系统只警告不拒绝；既有六条 scenario 逐字保留 +
    三条新 scenario。
- `watchdog`：
  - **MODIFIED** `` `team doctor` reports the temp root's headroom `` —— 行名带来源；未创建的默认根按最近祖先判并说出来；
    锁所在的文件系统在没被别的行覆盖时加一条**只警告**行；既有五条 scenario 逐字保留 + 三条新 scenario。

不新增 capability：临时根的机制面本来就在 `verification`，容量面在 `dispatch`，可见面在 `watchdog`。

## Impact

- 产品面：`scripts/lib/common.sh`（解析器 `team_tmp_root`/`team_tmp_root_source`/`team_tmp_root_default`/最近祖先与可用性判据；
  `team_disk_label`/`team_disk_remedy`/`team_capacity_line` 改用解析器；inotify 探针与 `teamsmith-lock-*` 模板）、
  `scripts/lib/cmd-agents.sh`（地板判的路径 + 不可用根阻塞项）、`scripts/lib/cmd-status.sh`（doctor 行）、
  `scripts/lib/cmd-watch.sh`（面板数据读）、`scripts/lib/cmd-review.sh`（队列标记与合并临时目录模板）、
  `scripts/lib/gate-lock.sh`（只把发布路径读出来给医生行用，**路径本身不动**）、`scripts/lib/cmd-config.sh`（schema 行）、
  `templates/config.sh.tmpl`（键行）、`scripts/panel/src/strings/{zh,en}.ts` + 重建 `scripts/panel/panel.js`。
- 夹具面：`tests/lib/tmp-root.sh`（基准走解析器；默认腿建目录 `0700`；显式根不可用具名失败；不回落）、
  `tests/tmp-hygiene.sh`（基准、表头来源、旧根残留段、`--lint` 第二条规则、自检新 stage）、
  `tests/smoke.sh`（自己的根与诊断走解析器；开跑行印来源）、`tests/section-budgets.tsv`（§40 的 band 复测）。
- 规格面：`openspec/specs/verification/spec.md` 的 3 MODIFIED + 1 ADDED，`dispatch` 的 1 MODIFIED，`watchdog` 的 1 MODIFIED；
  delta 在 `openspec/changes/tmp-root-on-disk/specs/`。
- 文档面：`references/config.md`（新键 + 阈值行的「临时根」改成解析出的根）、`references/troubleshooting.md`（ENOSPC 一节、
  §「临时根」一节的默认值与回滚）、`references/migration.md` §5/§6/§7、`skills/teamsmith/CHANGELOG.md`。
- 兼容性：`TEAM_SMOKE_LOCK` / 门禁锁的发布路径与伴生锁、`TEAM_TMP_KEEP`、`TEAM_TMP_SWEEP_AGE`、`TEAM_TMP_LEDGER`、
  `TEAM_TMP_MIN_FREE_MB` / `TEAM_TMP_MIN_FREE_INODES` 的名字与语义**一个都不改**；退出码集合与判定 token 不改。
  唯一可见的行为变化是**默认位置**（本文 §7 的迁移条目）与**不可用选定根从沉默变阻塞**。
- 分工：apply 需要明授 `skills/teamsmith/scripts/**`、`skills/teamsmith/tests/**`、`skills/teamsmith/templates/**`、
  `skills/teamsmith/references/**`、`skills/teamsmith/CHANGELOG.md`、`skills/teamsmith/scripts/panel/**`（含重建产物）。
  `.github/workflows/gates.yml` **不在**本变更（见 Out of scope）。
- 排期：todo —— propose（本任务）→ PM 复核 → apply（另派）→ verify（第三席位，独立克隆重跑全部场景与三条红侧）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **D1 · 解析顺序**：**`TMPDIR` → `TEAM_TMP_ROOT` → 平台默认**（推荐：`TMPDIR` 是标准约定的**进程级**选择，也是本仓
   **84** 处嵌套夹具做隔离的唯一机制、**12** 处规格场景的写法；把它排到配置键之后，任何在契约里钉了 `TEAM_TMP_ROOT`
   的项目，其门禁的隔离断言会集体变红 —— 钉住即自杀）。代价如实写：**环境里一个 `TMPDIR` 会盖过项目钉的值**，所以
   分歧必须印出来（D1 的正文要求），`references/config.md` 写明「要让钉的值生效，别让环境里出现 `TMPDIR`」。
   备选（brief 的字面顺序）`TEAM_TMP_ROOT` → `TMPDIR` → 默认：需要把上面 **84 + 12** 处隔离机制整体迁到新键，
   并把 `TMPDIR=D` 的场景按新键重写，回归面远大于本变更的目的。
2. **D2 · 默认值**：**`/var/tmp/teamsmith-<ns>`**（推荐，见 §2 的三条理由：磁盘、跨重启、与既有机器级共享面同构）。
   备选：`/var/tmp/<ns>`（少一层目录，但把「家族名」这条清扫器判据挪掉）、`~/.cache/teamsmith/tmp`（把机器级共享面变成
   用户面，容器/CI 语义要重写）、`/tmp`（现状）。
3. **D3 · 根名**：**不改**，仍是 `teamsmith-<kind>-<ns>.XXXXXX`，即使基准本身已经是按项目一包的目录（名字里出现两次 ns
   是有意的：**名字规则不依赖基准是谁**，回滚到 `/tmp` 时 P287 的保护照旧，`--lint` 与 `--sweep` 的谓词也不用分情况）。
   备选：私有基准下去掉 ns（规则变成有条件，清扫器与 lint 都要分两种形状）。
4. **D4 · 谁创建目录**：**只有创建者建「默认腿」那一个目录（`0700`），显式选定的根必须已存在**（推荐：显式路径写错时
   自动建目录会把人引到错的地方；而默认腿不建就没法用）。备选：默认腿也要求用户先建（则开箱即用性失去）。
5. **D5 · 配置键的形状**：**`refuse` + `path` + `dir,opt` + `identity`**，与 `TEAM_ROOT`/`TEAM_STATE_DIR` 同族，
   `team config set` 拒绝写它（推荐：它是**位置键**，与既有的位置键同一语义；`apply` 类会把它做成设置页里可编辑的一行，
   而改位置这件事本来就该走配置文件）。代价：控制台仍要求 `label_TEAM_TMP_ROOT` 两语标签（字符串门禁对**每个** schema 键
   双向走查），所以面板源码要改、`panel.js` 要用钉住的工具链重建。
   备选：`apply` + 设置页可编辑（多一个可编辑的路径行，写入口更宽）；或**不进契约**、只认环境变量（回滚与 CI 更简单，
   但「项目钉住」这件事就没有地方记）。
6. **D6 · 锁的文件系统**：**不进门禁地板，只在 `team doctor` 加一条只警告行**（推荐：brief 的红侧 ② 明确「选定的根很空、
   `/tmp` 很满时不许拒绝」；而 `/tmp` 满仍会挡住取锁 —— 那件事该**响亮**、该**可见**，不该变成「拒绝派单」）。
   备选：把锁一起判（会满足红侧 ② 的反面，与 brief 冲突）；什么都不加（则 `/tmp` 的余量在医生面上彻底消失）。
7. **D7 · 旧默认根的残留**：**`--status` 只读计数 + 打印一条命令**（推荐：一次 `--sweep` 一个基准，不新增第二套候选规则；
   回滚键 `TEAM_TMP_ROOT=/tmp` / `TMPDIR=/tmp` 顺手就是迁移工具）。备选：`--sweep --legacy` 同时扫两个根（多一套谓词与
   红侧）；自动迁移（会动别人的活运行，D37 家族）。
8. **D8 · 红侧落在哪**：**扩 §40（临时根纪律）**：三条红侧做成 `tmp-hygiene.sh --self-test` 的新 stage + 一个翻转夹具，
   §40 的 band 复测后按实测抬。备选：新开 `40b` 段（隔离更干净，但要动 `section-paths.tsv`/`section-budgets.tsv` 两处
   并让 `0e` 重新自述）。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/smoke.sh --select 40              # 临时根纪律：解析 / 命名 / 泄漏断言 / lint
bash skills/teamsmith/tests/smoke.sh --select 3,6b            # doctor 行与容量守卫矩阵（地板绑定到选定根）
bash skills/teamsmith/tests/smoke.sh --select 34,34c,34d      # 锁的路径与身份面零回退（P287 的合同）
bash skills/teamsmith/tests/smoke.sh --select 38,33           # 设置页/契约行：新键的标签与只读语义
bash skills/teamsmith/tests/smoke.sh --select 0e               # 预算表自述（§40 的 band 必须是实测值）
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test --break=inline-root
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test --break=fixed-floor
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test --break=missing-root
bash skills/teamsmith/tests/tmp-hygiene.sh --lint
bash skills/teamsmith/tests/config-cli.sh                     # 新契约键的四条纪律（只读 / 组 / 标签 / 人读表）
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

**不许改**的是：锁的发布路径与伴生锁、`TEAM_TMP_KEEP`/`TEAM_TMP_SWEEP_AGE`/`TEAM_TMP_LEDGER` 的语义、清扫器的候选谓词
（家族前缀 + 点开头不是候选）、占用证明与年龄判据、只对记录过的 pid 发信号、夹具的隔离/清理语义、门禁的判定口径、
以及本文 §1 的解析顺序。

## Out of scope

- **不改 `.github/workflows/gates.yml`**：容器里今天把宿主产物目录挂到 `/tmp`、`HOME=/tmp`；解析器在容器里跑，容器自己的
  `/tmp` 就是容器层（不是 tmpfs），改默认值不改变 CI 的语义。改成 `-e TEAM_TMP_ROOT=/artifacts` 是**下一步**（CI 的改动
  是 PM 的裁量，不在本变更）。
- **不动 `TEAM_NOTIFY_LOG` 的默认值**（`/tmp/teamsmith-notify.log`）：它是日志、不是临时根，而且是**契约键**（有自己的
  默认值与升级故事）；记一条 finding（D9），不塞进本变更。
- **不清理**今天 `/tmp` 下的历史残留（家族目录 109 个、点开头的 `.teamsmith-*` 目录 165 个共 733 MB、以及 13 个候选根里
  10 个没有 owner 标记的那些）；本变更只保证**新**的根长在磁盘上、旧的可见且一条命令可达（D7）。
- 不改门禁的判定口径、`TEAM_SMOKE_FAST` 分层、锁的排队上限，也不给清扫器加自动运行（它仍只由人触发）。
