# gate-lock-external-deletion · 别人的清理命令不再能删掉门禁的活运行（夹具根与锁的归属 + 锁身份的察觉）

## Why

2026-10-15 18:07:21，本机**另一个项目**的清理命令里带了一条 `rm -rf /tmp/teamsmith-smoke.*`，删掉了当时**正在跑**的
门禁的私有 TMP，`/tmp/teamsmith-smoke.lock*`（锁文件本身）也在那个 glob 里（D184）。两条后果，一条被挡住、一条没有：

1. **被挡住的那半**：被删的那次运行按 M33 的哨兵设计**响亮地停**（一条点名红 + exit 2，不是假红）—— 这条防线
   （`smoke.sh:744`–`:861`：金丝雀 + 0.2s 轮询的后台哨兵 + 证据文件在 `$TMP` 之外 + 一条点名行 + 安全点停跑）
   正是为「现场被抽走」建的，它工作了。
2. **没挡住的那半**：**锁文件被删会静默破坏互斥**。`flock` 锁的是 inode，持有者握着已被 unlink 的 inode，新运行
   在**新建的** inode 上拿到「锁」—— 两套「顶层」运行可以并发，双方都以为自己独占，而且**没有任何一行输出**
   （本 worktree 实测，design §1.3，私有锁）。今天一整轮里**没有任何一处**回头核对「路径上那个文件还是我持有的那个吗」
   （`SMOKE_LOCK_HELD=1` 是从环境标记推出来的，`smoke.sh:396`；收尾只删 `<lock>.holder`，`:881`）。

**根因不是「有人不小心」，是命名**：本轮的工作根与锁文件都**直接躺在解析后的临时根下、共用一个前缀**
（`teamsmith-smoke.*`，`tmp-root.sh:148` / `smoke.sh:326`），而任何装了 teamsmith 的项目都看得见同一个前缀 ——
于是「清理自己的残留」很自然就命中了别人的**活**运行。这不是理论：本机 `/tmp` 下今天有 **111** 个 `teamsmith-*`
条目，其中包括**第二把机器级锁**（`teamsmith-perf.lock`），而事件那条命令的射程实测正好是**工作根 + 锁 + 持有者记录**
三样（design §1.2）。所以修法不能是「请大家小心」——它已经失败过一次。

代价可算：这一族事件的「可承受」那半要浪费一整轮全量门禁（协议 §9b-2 记着一次完整套件 13–20 分钟）再加上重跑；
「危险」那半没有代价上限 —— 两套全量并发正是 M23/P255 量过的把机器压垮的形状（§36 超时、ENOSPC 假红那一族）。

**本变更的两条腿**：① **归属** —— 让运行自己的东西不再长在共享前缀上（工作根带项目命名空间；互斥换成点开头的
**机器级伴生锁**，那条 glob 够不着，实测 §1.4）；② **察觉** —— 持有者能发现自己的锁**没了/被换了**，有界时间内
**响亮地停**（点名 + 证据 + 约定的停止码），等待者能看出「我等的那把已经变了」，新来的运行入场前能看出
「同一把锁上有一个活运行记着另一个 inode」并**拒绝起跑**。两条腿合起来，事件那条命令对互斥**不再有破坏力**，
而「静默并发」在两侧都变成一行响亮的输出。

现状复核（2026-10-15，本 worktree 只读 + 私有锁夹具，机器锁一个字节没碰）：

| 事实 | 证据 |
|---|---|
| 事件那条 glob 命中工作根与 `teamsmith-smoke.lock*`，不命中队列标记/诊断/过滤副本 | design §1.2 实测 A（`case` 表） |
| 锁被删后新运行能在新 inode 上拿到「锁」= 静默并发 | design §1.3 实测 B |
| 点开头的伴生名不在那条 glob 射程内，且删完之后互斥**保持** | design §1.4 实测 C |
| 一整轮里没有任何一处核对锁文件还是不是自己持有的那个 | `smoke.sh:396`–`:400`、`:881`（读码） |
| M33 哨兵：0.2s 轮询、证据在 `$TMP` 之外、一条点名行、exit 2、`KEEP=1` | `smoke.sh:744`–`:861`（读码） |
| 家族、owner 标记、run 台账（台账头已带 `repo=`） | `tmp-root.sh:39`、`:102`、`:148` |
| `--lint` 只扫 `mktemp -d`（本树 15 个）、只认前缀：文件模板与家族外模板无静态闸 | `tmp-hygiene.sh:577`/`:627`（读码）+ `--lint` 实测输出 |
| 平铺面上还有 7 个文件模板没有静态闸（家族内 4 + 家族外 3） | `cmd-review.sh:1071`、`smoke.sh:355`、`common.sh:1198`、`cmd-watch.sh:244`；`panel-cpu.sh:161`、`panel-knobs.sh:34`、`cmd-review.sh:372` |
| `/tmp` 是 tmpfs、本机无 age 清理规则；`/run/user/<uid>` 存在且可写 | design §1.6 |

## What Changes

### 1 · 归属 · 工作根与每运行标记带项目命名空间（MODIFIED `A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed`）

夹具的唯一创建者 `tests/lib/tmp-root.sh` 把根命名成 `teamsmith-<kind>-<ns>.XXXXXX`，`ns` 由**项目自己的身份**推出
（`<slug>-<hash8>`：slug 取 `TEAM_PROJECT` 或主检出目录名，hash 取主检出的 realpath —— 与 P122 已经写进 run 台账头的
`repo=` 是**同一条解析**，所以同一个项目的所有 worktree 得同一个 ns、两个项目不可能撞）。owner 标记与 run 台账
各加 `ns=`。**同一个项目的**运行里所有直接落在解析后临时根上的东西，从此只有两种形状：点开头（台账 / pid / 诊断）
或带 ns（根 / 队列标记 / 过滤副本）；产品与夹具里另外 7 个直接落在临时根上的文件模板
（家族内 `teamsmith-review-queue.*`、`teamsmith-smoke-queue.*`、`teamsmith-inotify-probe.*`、`teamsmith-npm.*`；
家族外 `p12cpu.*`、`panel-knobs.*`、`p91-merge3.*`）一并归位 —— 顺带把它们拉进 `--status` 的视野（家族外那三个
今天连家族都不在）。

### 2 · 归属 · 互斥换成机器级伴生锁，发布路径保留为兼容声明（ADDED `The gate's lock is identified, and losing it stops the run loudly`）

两把锁，两个角色：

- **发布路径**（`${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}`）：名字、语义、文档一个字不改 ——
  它是**每个 P287 之前的写入者**取的那把锁，本版本的运行也**先取它**（顺序固定：发布路径 → 伴生锁），
  于是新旧版本之间**仍然串行**；
- **机器锁（伴生锁）**：发布路径的同行同目录、basename 加 `.machine`、**点开头**
  （`…/teamsmith-smoke.lock` ⇒ `…/.teamsmith-smoke.lock.machine`）—— 互斥真正落在它身上，而事件那条命令够不着它
  （实测 §1.4）。它的注册与持有者记录放在它边上（`<companion>.runs/*`、`<companion>.holder`，点开头 ⇒ 天然不是
  `--sweep` 的候选）。

账要如实记：发布路径因此是**活运行仍在创建的唯一的平铺家族形状的文件**（命名规则的一个例外，写进文档与夹具），
它被删只丢「与旧版本串行」——守卫会**点名 + 记录但不停止**（互斥完好）；而它的**持有者永远不许删除或改名它**
（删掉一个还有等待者阻塞在其 inode 上的锁文件，正好就是事件那条机制本身）。

### 3 · 察觉 · 锁身份登记 + 守卫（同一个 ADDED 要求）

- 取锁时记下**自己持有的那个文件**的身份（能读到持有者 fd 的 `dev:ino` 就记它，否则记路径身份并写明
  `source=path`），并刷一次伴生锁的 mtime（按 age 的临时目录清理器不该删一个**活**锁）。
- 运行期间由**同一个**后台哨兵（既有 M33 哨兵，0.2s 轮询）多看一条前提：伴生锁还是不是我持有的那个文件。
  **路径不在** ⇒ 一行「锁已不在」；**路径上是另一个文件** ⇒ 一行「锁已被替换」并印两个身份。两种都：证据写进
  `$TMP` 之外那个点开头的诊断文件（追加一节 lock 现场），`KEEP=1` 留现场，**安全点停跑**，退出码沿用约定的 **2**
  （协议 §9b-2 的 1/2/3/4 不新增码），**绝不在之后给出对代码的判定**。发布路径的丢失只印不停止（与伴生锁的处置
  有意区分），文案一眼可辨。
- `team review` 走同一实现：门禁运行中丢锁 ⇒ 记录写「门禁没有跑完（锁在运行中丢失）」，判定不为 `PASS`，
  排队记账的三个键与 token 闭集不变。

### 4 · 察觉 · 等待者与入场检查（同一个 ADDED 要求）

- **等待者**：把一次 `flock --close -w` 阻塞改成**有界轮询**（短 `flock -n` 尝试），每一轮重新解析路径；发现
  「我等的那把已经变了」就印一行（两个身份）再继续等。上限算式仍是 P281 冻结的那条，marker 语义（P66：
  「真的跑起来了」的唯一证据）与超限/加锁失败的文案、退出码**一字不改**。
- **入场检查**：拿到锁、跑套件之前读 `<companion>.runs/*`，若有**活着的 `top` 登记**记着**另一个身份**，就证明
  互斥已经断了 —— 印一行点名那个运行、席位、工作树与两个身份，**不跑套件**（「本套没有运行」，退出码 2）。
  这是新来者侧唯一的保护，也是「静默并发」在另一侧被堵住的时刻。
- **旧版本的记录**照 P281 对旧写入者的既有口径打印：有多少字段打多少，缺的写 `?`，标 `version=legacy`，
  绝不印 `holder unknown`。

### 5 · 静态闸与纪律（MODIFIED `The fixtures' temp-root ownership rule is enforced by a static check`、MODIFIED `The sweep proves occupancy and touches this project's own roots only`）

- `--lint` 的规则从「`mktemp -d` 根模板必须在前缀家族里」扩成「**直接落在解析后临时根上的每一个模板**要么点开头、
  要么带 ns；根还要在家族里」，作用域从 `tests/**` 扩到「夹具 **与** 产品自己的临时模板」（§1.5 那 6 个今天
  在静态闸之外）；finding 仍是 `<file>:<line>`、退出码 1，红侧是两份副本（一份写死 `/tmp`、一份保留家族前缀但丢 ns）。
- `--sweep` 的谓词**不动**（根仍是 `teamsmith-` 前缀；伴生锁/记录是点开头、发布路径是文件，本来就不是候选），
  842 只加一句：三样都要在 `--status` 里按**角色**报出来（运行互斥 / 兼容声明 / 运行注册）。
- `references/protocol.md` §9b-2 写进：两把锁的角色与顺序、no-unlink 纪律、**安全清理入口**（`tmp-hygiene.sh --sweep`，
  或只删自己项目的 `teamsmith-<kind>-<ns>.*`，绝不写针对共享前缀的 `rm -rf`），以及过渡期口径（旧写入者只经发布路径串行）。

## Capabilities

### Modified Capabilities

- `verification`：
  - **MODIFIED** `A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed`：既有正文（含
    `INT`/`TERM` 回收、`TEAM_TMP_KEEP`、只对记录过的 pid 发信号三条语义）一句不改，加「名字带项目命名空间、
    标记与台账带 `ns=`、每运行产物点开头或带 ns」的正文 + 两条 scenario（命名空间证据与平铺模式够不着；
    同项目 worktree 共享 ns / 第二个仓库不同 ns）。
  - **MODIFIED** `The sweep proves occupancy and touches this project's own roots only`：新增正文只点名锁对与注册
    永不成为候选、`--status` 按角色报出；既有五条 scenario 逐字保留，锁那条扩面。
  - **MODIFIED** `The fixtures' temp-root ownership rule is enforced by a static check`：作用域与规则扩面（见 What
    Changes 5）；既有两条 scenario 保留，新增「丢 ns 的模板是一条 finding」。
  - **ADDED** `The gate's lock is identified, and losing it stops the run loudly`：六条 scenario（删锁停跑 +
    shadow 翻转 / 换锁按「替换」判 / 正常跑不误报且持有者不删自己持有的锁 / 第二套入场拒绝 + shadow 翻转 /
    等待者看出变了 + 旧版本记录 / review 丢锁不为 PASS）。

不新增 capability：锁的机制面本来就在 `verification`（`gate-hygiene` 起），本变更加的是它的**归属**与**身份**面。
不碰 `The hard timeout covers the gate run, not the queue`（P281 正在改同一条 —— 两个未归档 change 改同一条 requirement
会让「有效文本」出现两个互斥版本，本变更刻意避让：发布路径的名字与语义不变，上限算式与 token 闭集一字不动）。

## Impact

- 产品面：`skills/teamsmith/scripts/lib/gate-lock.sh`（**P281 新建**：本变更在同一文件里加身份登记与守卫接口）、
  `scripts/lib/common.sh`（ns 纯函数；inotify 探针模板）、`scripts/lib/cmd-review.sh`（取锁/等待/入场检查/记录）、
  `scripts/lib/cmd-watch.sh`（npm 探针模板）。
- 夹具面：`tests/lib/tmp-root.sh`（模板 + 标记 `ns=` + 自检两条红侧）、`tests/smoke.sh`（两把锁的顺序、守卫接线、
  §34c/§34d 两个新段、P223/P70 里对平铺名的点名叫法）、`tests/tmp-hygiene.sh`（`--lint` 规则与作用域、`--status`
  的 ns 列与锁对角色、自检新用例）、`tests/flip-p287-name.sh` 与 `tests/flip-p287-lock.sh`（**新**：两条翻转夹具）、
  `tests/flip-m33.sh`、`tests/flip-p158.sh`（两处写死的平铺匹配器）、`tests/perf.sh`（**仅当** D4 裁一并）。
- 规格面：`openspec/specs/verification/spec.md` 的 3 MODIFIED + 1 ADDED，delta 在
  `openspec/changes/gate-lock-external-deletion/specs/verification/spec.md`。
- 段面：`tests/section-paths.tsv`、`tests/section-budgets.tsv` 的 `34c`/`34d` 行（新段，按实测补 band，`0e` 守表）。
- 文档面：`references/protocol.md` §9b-2。
- 兼容性：发布路径的名字、语义、`TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT` / `TEAM_SMOKE_NO_LOCK` 与
  `TEAM_SMOKE_FAST` 一个都不改；判定 token 闭集、退出码集合（1/2/3/4）、`team_review_verdict` 的解析都不动。
  唯一可见的行为变化：**锁被外部删除/替换时运行会停**（这是本变更的目的），以及锁的默认路径多了一把点开头的伴生锁。
- 分工：apply 需要明授 `skills/teamsmith/scripts/lib/**`（默认 PM）、`skills/teamsmith/tests/**` 与
  `references/protocol.md`；**串行要求**：P287 的 apply 必须在 **P281 的 apply 落地之后**（两者都动 `smoke.sh` 的锁块与
  `gate-lock.sh`；P287 **扩展**P281 冻结的实现，落地后按 landed 形状适配，不反向改 P281 的合同）；P287 用**新段**
  `34c`/`34d`，不改 P281 的 `34`/`34b`。
- 排期：todo —— propose（本任务）→ PM 复核 → apply（另派）→ verify（第三席位，独立克隆重跑六场景与两条红侧）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **D1 · 互斥的归属**：**机器级伴生锁**（推荐：机器级的资源、机器级的名字；换出平铺家族后事件那条命令够不着它，
   实测 C）+ 发布路径保留为兼容声明。备选 ①「锁放进本项目自己的状态目录」（brief 的括号那支）：更干净，但
   **把机器级串行交了出去** —— 两个项目/两个检出可以并发跑全量（M23/P255 量过的那族），而 P281 的 `nested` 纪律
   正建立在「锁串行化顶层运行」上；备选 ②「只保留发布路径、只加察觉」：最省事，但事件那条命令仍**删得掉互斥**，
   brief 第 1 条要的名字那一半没做。
2. **D2 · 兼容声明**：**保留**（推荐：机器上一定有 P287 之前的写入者，它们只取发布路径；不保留就等于在升级窗口里
   **新开**一个静默并发窗口 —— 与本变更的目的相反）。代价如实写：发布路径是命名规则唯一的例外，且它被删时
   只印不停（丢的是与旧版本串行，不是互斥）。备选：不保留（则在文档里把升级窗口的代价写明）。
3. **D3 · 入场检查**（拿到锁后核对活登记的身份，不同就拒绝起跑）：**做**（推荐：这是新来者侧唯一的保护，
   没有它时「静默并发」只能等旧持有者的守卫在 ≤0.2s 内发现 —— 两者互补；夹具里也最容易证伪）。
   备选：不做（则 §10 的窗口由守卫节奏单独承担）。
4. **D4 · 性能套件那把锁**（`teamsmith-perf.lock`，同一平铺家族、同一 `$TMPDIR`）：**一并走同一实现**（推荐：
   同一份库的第二个调用点，成本极低；而它分裂的后果是**静默的错误测量**，比门禁那次更糟）。
   备选：只记 finding，留给下一批。
5. **D5 · `ns` 的推导与形状**：**`<slug>-<hash8>`**（推荐：slug 取 `TEAM_PROJECT`、否则主检出目录名，
   hash 取主检出 realpath 的前 8 位 —— 可读、同项目所有 worktree 一致、不同项目不撞，且与 run 台账头的 `repo=`
   同源）。备选：只用 hash（不可读）、只用目录名（两个项目的目录同名就撞）。
6. **D6 · `--lint` 的作用域**：**扩到「夹具 + 产品自己的临时根模板」**（推荐：§1.5 那 6 个模板今天在静态闸之外，
   其中 3 个连家族都不在；规则本来就要为 ns 改一次，顺手把它们拉进 `--status` 的视野）。备选：作用域不动，
   只加 ns 规则（则那 6 个留成 finding）。
7. **D7 · 段落号**：**新开 `34c`（命名面）/ `34d`（身份面）**，不扩 `34`/`34b`（推荐：那两段是 P281 的写集，
   避让后两边可以各自独立复验；`section-select.sh --check` 照补两行）。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/smoke.sh --select 34c,34d          # 六场景 + 两条红侧的 shadow 翻转
bash skills/teamsmith/tests/smoke.sh --select 34,34b           # P281 的既有断言零回退
bash skills/teamsmith/tests/smoke.sh --select 0e               # 预算表自述（34c/34d 的新 band 必须登记）
bash skills/teamsmith/tests/flip-p287-name.sh --self-test      # 命名面翻转（平铺模式命中 → 红）
bash skills/teamsmith/tests/flip-p287-lock.sh --self-test      # 身份面翻转（guard / 入场检查各自 shadow）
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test
bash skills/teamsmith/tests/tmp-hygiene.sh --lint
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rm -rf /tmp/gled-trial && mkdir -p /tmp/gled-trial && cp -a openspec /tmp/gled-trial/openspec \
  && (cd /tmp/gled-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y gate-lock-external-deletion \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

夹具与命令的最终形态以 apply 冻结的接口为准；**不许改**的是：发布路径的名字与语义、两把锁的顺序、「删锁/换锁 ⇒
有界时间内点名 + 安全点停跑 + 退出码 2」、入场检查的拒绝语义、命名规则（点开头或带 ns）、以及上面六条 scenario 的方向。

## Out of scope

- **不把锁去掉**，也不把「删了锁文件」当成通过（那会变成静默并发）。
- 不关 `TMPDIR` 覆盖造成的互斥分裂（P255 r4/r5 的残留）：换了 `TMPDIR` 的运行取的是另一对文件、彼此不可见；
  本变更只把它写进诚实边界，不新增第二个解析规则。
- 不改 `review-<ID>` 检出的名字（git 记录归因，名字写在三处 shipped 文档里）；只记一条 finding
  （`rm -rf /tmp/review-*` 仍在它的射程内，但它是检出、不是活运行）。
- 不改排队上限算式、token 闭集、退出码集合、`team_review_verdict` 的解析（P281 的合同）。
- 不清理历史的 111 个平铺残留（那是 `--sweep` 与运维的事）；本变更只保证**新**的活运行不长在那个形状上。
- 不改 `TEAM_SMOKE_FAST` 分层、不改 FAST 档不排队的契约、不给等待者优先级/插队权。
