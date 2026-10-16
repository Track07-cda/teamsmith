# P288 · 门禁锁的两把锁与身份：apply（dev-bob）

**本文件读法**：顶部 = **返修轮次 1**（V53-F1 的修复与复跑，最终交付 tip `962ec637`）；下面保留第一轮
（tip `178e946f` 时代）的原始交付材料。两者冲突时以顶部为准。

---

## 返修轮次 1 · V53-F1 已修（2026-10-16）

**结论**：V53-F1 成立且已修 —— 「平铺」不再靠猜正则，改成与**本次运行自己算出的命名空间**对照
（平铺 ⇔ 不是点开头、也不带运行自己的 ns）。修完在**项目名不含 `_`** 的树上由红转绿（rc=1 → rc=0）、
在**含 `_`** 的树上仍绿、真平铺旧名仍判平铺；三条方向的定名臂与两条红侧开关都在下面逐条贴出。

交付 tip `962ec637`（= 返修提交 `18e971d0` + `git merge main`；`git merge-base --is-ancestor main HEAD`
为真，`main` 带进来的只有 `docs/team/**` 四个文件，返修的那个文件在合并前后逐字节不变），工作树
`git status --short` 为空。分支最终 tip = 本报告所在的提交 —— 从 `962ec637` 往后只多了 `docs/team/**`
的账本提交，产品面与 `962ec637` 逐字节相同（`git diff --stat 962ec637 HEAD -- skills/ AGENTS.md` 为空；
§2 的全部读数都是在 `962ec637` 的树上取得的）。本仓库 local 模式：按要求**不推送**，分支留在本地等 PM 合并。

写集：**一个文件** —— `skills/teamsmith/tests/flip-p287-name.sh`。`smoke.sh` 一个字节没动
（`git diff --stat 18e971d0^ HEAD -- skills/teamsmith/tests/smoke.sh` 输出为空），所以 P281 的
`34`/`34b` 与 P287 的 `34c`/`34d` 段字面未动 —— 那四段这次全绿（§2、§4）。

### 1 · 判据：从「猜正则」改成「命名规则本身」

改动前的那条模式是这轮返修的病灶所在：

```
FLAT_RE='^(teamsmith|review)-[a-z0-9-]*\.[A-Za-z0-9]{6}$'
```

它想表达「改动前的平铺形状」，但把它当**唯一**判据就必然误报：命名空间是 `<项目名 slug>-<hash8>`，
而 slug 允许 `_`，模式里的 `[a-z0-9-]*` 放不下 `_` —— 于是项目名里**没有** `_` 时（`cand-ccb43d8f`
这种）整段 ns 被那条「`-` 随便吃」的中间段吞掉，**合法根** `teamsmith-smoke-cand-<hash8>.<rand>`
被判成平铺名。合约里并没有这条假设：34c 段点名的是事故那条射程 `teamsmith-smoke.*`（前缀+点，
带 ns 的名字在点前面还有 `-<ns>`，够不着）。

现在的判据只有命名规则本身（`p287n_is_flat`）：

- 点开头 → 不是平铺；点开头是 `verification#A fixture's temp root…` 里正面列出的合规形状之一；
- 名字里带**运行自己写下的 ns** → 不是平铺；
- 其余 → 平铺旧形状；**拿不到参照 ns 时判平铺**（fail-closed，绝不把「不知道」当成合规）。

参照 ns 本身也要可核：`leg0` 从运行自己写的台账头（`… ns=<token>`）里取 ns，再与本夹具用**同一个**
`team_project_ns` 算出的值对照，两者不一致即红 —— 判绿不许建立在一个假定的 ns 上。夹具算 ns 时清空
`TEAM_PROJECT`（`smoke.sh` 自己 `unset` 它，嵌套运行的 ns 一律由检出路径推出），`--lint` 子进程同样
`env -u TEAM_PROJECT`，免得父进程一个 ns、子运行另一个 ns。

契约那条形状 `teamsmith-smoke.*` 仍然留着，但只承担一件事：钉住**事故命令的射程**（与 34c 段同口径，
发布锁路径是显式例外），不再兼任「平铺判定」的全部语义 —— 它的边界写在注释里：带**别的项目** ns 的名字
会被它和 `p287n_is_flat` 都判成「平铺」，对「我自己创建的条目」这是对的判据，拿去判全机器的条目就会误报
（那是 34c 段 `--status` 归因条目的活）。

### 2 · 验收命令（交付 tip `962ec637` 上逐条真跑）

| # | 命令 | rc | 读数（各自日志在 `/var/tmp/p288/acc/`） |
|---|---|---|---|
| 1 | `bash skills/teamsmith/tests/smoke.sh --select 34c,34d` | 0 | 34c ✓20 ✗0（17s）· 34d ✓101 ✗0（131s）· 增量 ✓142 ✗0（153s） |
| 2 | `bash skills/teamsmith/tests/smoke.sh --select 34,34b` | 0 | 34 ✓36 ✗0（59s）· 34b ✓101 ✗0（66s）—— 第一次运行**没跑**（§5-5），用 `TEAM_SMOKE_LOCK_WAIT=5400` 重跑 |
| 3 | `bash skills/teamsmith/tests/smoke.sh --select 0e` | 0 | 增量 ✓44 ✗0（336s） |
| 4 | `bash skills/teamsmith/tests/flip-p287-name.sh --self-test` | 0 | leg0 全绿 + shadow/lint/shape 三条腿各按预期（9s） |
| 5 | `bash skills/teamsmith/tests/flip-p287-lock.sh --self-test` | 0 | 绿侧点名并停跑、两条对照腿静默（46s） |
| 6 | `bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` / `--lint` | 0 / 0 | ✓73 ✗0（125s）；32 个 mktemp 模板合规（4s） |
| 7 | `bash skills/teamsmith/tests/section-select.sh --check` | 0 | ok 8 / bad 0 / SKIP 1（3s） |
| 8 | `bash skills/teamsmith/tests/spec-refs.sh --check` | 1 | 唯一一条 `undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md` —— **既有红**（§5-3） |
| 9 | `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 0 | Totals: 23 passed, 0 failed |
| 10 | `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | 0 | files=1698 hits=0 names=ok user=resolved |
| 11 | `git diff --check && git status --short` | 0 | 空 |
| 12 | `bash skills/teamsmith/tests/smoke.sh --select 34c,34d,51c` | 0 | 34c ✓20 · 34d ✓101 · 51c ✓2 · 增量 ✓144 ✗0（646s） |

（12 是任务书返修段点名的那条回归；1/2/3 是任务书的三个选段。选段运行不是全套门禁，没跑的段见 §5-4。）

### 3 · 返修的翻转证据（破坏 → 红点名 → 还原 → 绿）

**(a) F1 现场：同一棵树、只换项目名（A/B）。** 两个克隆同出 `962ec637` 之前的分支 tip，差别只在目录名，
因而 ns 不同；旧夹具取自 `c049cdb2:skills/teamsmith/tests/flip-p287-name.sh`（返修前的那份）：

```
$ env -u TEAM_PROJECT TMPDIR=/var/tmp/p288/tmp/cand bash <旧夹具> --self-test       # cand → ns=cand-ccb43d8f
  ✗ leg0：有条目不合规（1 条）
      BAD teamsmith-smoke-cand-ccb43d8f.zhZvsU ← 命中平铺家族模式        rc=1
$ env -u TEAM_PROJECT TMPDIR=/var/tmp/p288/tmp/cand bash <新夹具> --self-test       # 同一棵树
  ✓ leg0：运行自己写的 ns 与本夹具算的一致（cand-ccb43d8f）
  ✓ leg0：全部条目点开头或带 ns（13 条）                                  rc=0
$ env -u TEAM_PROJECT TMPDIR=/var/tmp/p288/tmp/can_d bash <新夹具> --self-test      # 项目名含 `_` 的方向
  ✓ leg0：全部条目点开头或带 ns（14 条）                                  rc=0
```

**(b) 调用者 ns 不是参照。** 旧夹具在 `TEAM_PROJECT=foo` 下把运行**自己**建的合法名判成不合规（父进程一个
ns、子运行另一个 ns，旧判据只认父进程那个）：

```
$ env TEAM_PROJECT=foo TMPDIR=/var/tmp/p288/tmp/foo3 bash <旧夹具> <树> --self-test
      BAD teamsmith-select.pm_skills-deb708fe.796375.sh ← 既不点开头、也没有 ns
      BAD teamsmith-smoke-pm_skills-deb708fe.901cGo ← 既不点开头、也没有 ns
      BAD teamsmith-smoke-queue.pm_skills-deb708fe.etoiwN ← 既不点开头、也没有 ns
  ✗ leg0：没有收到带 ns 的根（名字里找不到 -foo-deb708fe.）                rc=1
$ env TEAM_PROJECT=foo TMPDIR=/var/tmp/p288/tmp2 bash <新夹具> --self-test
  ✓ leg0：运行自己写的 ns 与本夹具算的一致（pm_skills-deb708fe）           rc=0
```

**(c) 真平铺旧名仍判平铺，且那两条臂有牙。** `--break=never-flat` 只把本夹具的平铺判定换成「永不成立」
（不改被测树、不改产品），两条依赖它的臂必须因此变红：

```
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test --break=never-flat        rc=1
  ✗ leg1：shadow 下契约形状零命中 / 没有不合规条目（contract=[teamsmith-smoke.8kEMXK] bad=0）—— 那条断言判不出「根回到平铺名」
  ✗ leg3①：契约那条平铺旧名：teamsmith-smoke.Ab3xY9 → 期望 flat、实得 named（判据与命名规则不一致）
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test                           rc=0   # 还原
```

**(d) F1 现场重现：把旧正则装回来，合法名立刻被判平铺。**

```
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test --break=flat-regex        rc=1
  ✗ leg3②：带 ns 的合法名（项目名不含 `_`）：teamsmith-smoke-cand-deb708fe.Ab3xY9 → 期望 named、实得 flat（判据与命名规则不一致）
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test                           rc=0   # 还原
```

**(e) 三个方向的定名臂（绿侧原文）** —— ②是 F1 的现场（项目名不含 `_`），③是改动前恰好绿的那个方向：

```
  ✓ leg3：臂②的 ns 里没有 `_`（ns=cand-deb708fe，项目名不含 `_`）
  ✓ leg3：臂③的 ns 里有 `_`（ns=can_d-deb708fe，项目名含 `_`）
  ✓ leg3①：契约那条平铺旧名：teamsmith-smoke.Ab3xY9 → 判「平铺」（期望）
  ✓ leg3②：带 ns 的合法名（项目名不含 `_`）：teamsmith-smoke-cand-deb708fe.Ab3xY9 → 判「合法」（期望）
  ✓ leg3③：带 ns 的合法名（项目名含 `_`）：teamsmith-smoke-can_d-deb708fe.Ab3xY9 → 判「合法」（期望）
  ✓ leg3：①落在契约那条形状的射程里（teamsmith-smoke.*）
  ✓ leg3：②/③都够不着契约那条形状的射程
```

**(f) 另两条腿的锚点没被这次改动削弱**（同一个夹具的既有一半）：`leg1` 用被测树自己的
`TMP_ROOT_BREAK=flat-name`（根回到平铺名）——绿侧原文：

```
  ✓ leg1：shadow 下 teamsmith-smoke.jqVa7k 命中契约形状，且它不满足命名规则（判的是命名规则）
```

`leg2` 是 `--lint` 的三份副本（写死 `/tmp`；家族前缀在、ns 丢了；合式），红侧各自点名 `file:line`
并含「命名空间」字样 —— 返修只把子进程的环境清干净（`env -u TEAM_PROJECT`），判据本身没动，三份照样
「红/红/绿」。`tmp-hygiene.sh --self-test`（含它自己的红侧用例）与 `--lint` 本次全绿（§2-6）。

### 4 · P281 四条不回退

V53 抽样过的四条（记录可归因 / 嵌套受祖辈预算 / 运行时按 `started` 算 / 写权不可继承）都落在 `34`/`34b`
两段里，本次不再是抽样：`smoke.sh --select 34,34b` → 34 ✓36 ✗0、34b ✓101 ✗0，两段 rc=0。比 V53 那次
（34b ✓100 ✗1，唯一红是已知的 34b⑫）还干净一条；两段所在文件在返修前后逐字节相同（§开头），所以这条
「不回退」是字面成立的，不是靠重跑碰运气。

### 5 · 未做项与诚实边界

1. **没改 `smoke.sh`、没改任何 delta / spec / proposal / design**（任务书 `deltas: -`）。所以本次不给新的
   规格面证据；合同一个字没动，34c/34d 的新字数与 V53 基线同数（20 / 101）。
2. **既有红，不是本次引入**：`spec-refs.sh --check` rc=1，唯一一条 `undeclared
   openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md`（指向 PM 拥有的旧任务书，且该文件今天
   已不在树上）。V53 已在**改动前**的 main（`3d92bb20`）上实测同一行、同一 rc；本变更没有新增或移动任何
   `openspec/**` 文件。
3. **选段运行不是全套门禁**：本次没跑的段已在各自日志里逐个点名（`34c,34d` 129 个键、`0e` 130 个、
   `34c,34d,51c` 128 个）。交付 / 复验 / 归档仍跑整套。
4. **`34,34b` 第一次运行没有运行**：它排在另一个席位的全量门禁后面，等满默认 1800s 的排队上限后按门禁
   自己的规矩退出（rc=2，日志里一条断言都没有）：

   ```
   排队超限：等满 1800s 仍拿不到门禁锁 /tmp/teamsmith-smoke.lock（持锁者：kind=top pid=1190211 cmd=smoke.sh
   agent=dev worktree=$HOME/…/.worktrees/dev 已跑 59s expected=83 bound=628）→ 本套**没有运行**
   （这不是对代码的判定；等持锁者结束，或抬高 TEAM_SMOKE_LOCK_WAIT 后重跑；TEAM_SMOKE_NO_LOCK=1 可跳过排队）
   ```

   重跑用 `TEAM_SMOKE_LOCK_WAIT=5400`（排队上限算式没动），rc=0，读数见 §2-2。两次的原始日志都在
   `/var/tmp/p288/acc/smoke-34-34b.log` 与 `…-rerun.log`。
5. **`--break=never-flat|flat-regex` 是红侧证据工具**，只作用在本夹具的判定上（不改产品、不改被测树），
   不参与任何验收行；默认（无 `--break`）跑出来的才是对命名规则的判定。
6. **判绿的前提取自合约本身**：`leg0` 需要运行的台账头带 `ns=`（`verification#A fixture's temp root…`
   的那条要求）。哪天台账头不再写 `ns=`，`leg0` 会**红**而不是悄悄放过 —— 这是有意的 fail-closed。
7. **平铺判定的语义边界**（写在 `p287n_is_flat` 的注释里）：它只判「点开头 或 带运行自己的 ns」。名字里
   带**别的项目** ns 的条目会被判平铺 —— 对「我自己创建的条目」正确，拿去判全机器条目会误报（那是
   `--status` 归因那条要管的活）。本次没有把它当全机器判据用。
8. 第一轮报告里的 OBSERVE（我清理临时根时误伤别的席位在跑的一段）本轮不复现：本轮所有临时根都点开头或
   带 ns，清理只删自己创建的 `$TD0`/`$TD1`。
9. **没做的事**：没有推送（local 模式）、没有合并、没有动 `main`、没有改任务书、没有动别的席位的目录
   （`OWNERSHIP` 面：本次写集只有 `skills/teamsmith/tests/flip-p287-name.sh` 与本报告）。

### 6 · 环境事实（复跑者要知道）

- 机器同时在跑别的席位的全量门禁（`loadavg` 在 10–23 之间，32 核），门禁锁因此排过队（§5-4）；
  本次四条选段的读数与 V53 基线的段内条目数一致，没有任何一条断言是靠机器空转才绿的。
- 所有临时根都建在 `${TMPDIR:-/tmp}` 下、点开头或带本项目的 ns；`TEAM_SMOKE_LOCK` 一律显式指向私有路径，
  全程没碰机器锁；门禁运行期间没有向工作树写入（`git status --short` 前后都空）。
- 日志与现场留在 `/var/tmp/p288/`（`acc/` 逐条命令的日志、`tmp/{cand,can_d}/` 两个 A/B 克隆、
  `old-flip-name.sh` 返修前的夹具、`break-*.log` 两条红侧），需要时可以就地复跑。

---
# P288 · 门禁锁的两把锁与身份：apply

agent: dev-bob   status: DONE   time: 2026-10-16T07:20:00Z
branch: `task/P288-gate-lock-external-deletion-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
phase: apply   change: `gate-lock-external-deletion`（apply 前的 propose/design 由 dev3 做，本席未参与）
spec: `openspec/specs/verification/spec.md`（delta：`openspec/changes/gate-lock-external-deletion/specs/verification/spec.md`）

结论：合同面的两个 requirement（命名面、身份面）与 D1–D7 全部落地；**改动前的树在 34/34b 上是红的
（✓153 ✗1），本分支是绿的（✓158 ✗0）**；两条新段 34c/34d 以及两条新翻转夹具全绿；`spec-refs --check`
的 1 条 undeclared 是 **main 上就有的**（在 PM 拥有的 `docs/team/tasks/P1.md` 里，本席无写权），逐条列在
Findings 里。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/gate-lock.sh` | 伴生锁路径（`<pub 同目录>/.<basename>.machine`）、fd 身份（`gate_lock_claim_identity` / `gate_lock_pid_holds_path` / `gate_lock_fd_of_pid` / `gate_lock_fd_identity`）、守卫探针（`gate_lock_snapshot` → `ok`/`gone`/`replaced` 两侧身份）、取两把锁（本进程 fd 8/9）、入场检查、pair 版记录源（活记录优先）/祖辈证明/心跳/描述/上限；记录格式末两个字段 `lock_identity=fd|path`、`lock_dev_ino=<dev:ino>` |
| `skills/teamsmith/tests/smoke.sh` | 顶层 = 取锁进程自己持 fd + 子套件 `8>&- 9>&-`；有界轮询等待（每轮重解析，我等的那把变了就印两侧身份）；守卫接进**既有 0.2s 哨兵**（同进程、同一停跑路径、退出码 2）；发布路径丢失只印不停；两个夹具红侧开关（`--break=no-lock-guard|no-entry-check`，仅 `TEAM_SMOKE_FIXTURE=1`）；新段 **34c**（命名面，20 条）与 **34d**（身份面，101 条，含 ⑦ 调用者侧：真跑一次 `team review` 并在门禁运行中删锁） |
| `skills/teamsmith/tests/lib/tmp-root.sh` | 根名 `teamsmith-<kind>-<ns>.XXXXXX`；owner 标记与台账头加 `ns=`；`tmp_root_path_ok` 认 ns；自检两条红侧（`--break=flat-name` / `--break=no-ns`） |
| `skills/teamsmith/tests/tmp-hygiene.sh` | `--lint` 规则扩成「**直接落在解析后临时根上的每个 `mktemp` 模板**：点开头或带 ns；根还要在 owned 家族里」，作用域从 `tests/**` 扩到整棵 skill 树（跳过扫描器自身与嵌套根 `$TMP/…`）；`--status` 加 ns 列并报**锁对**（运行互斥/兼容声明/运行注册，三样都不是清理候选） |
| `skills/teamsmith/scripts/lib/common.sh` | `team_project_ns()`（`<slug>-<hash8>`，纯函数：不读配置、无 git/无 sha256 也不报错）+ `team_hash8()`；inotify 探针的脚本/目录带 ns |
| `skills/teamsmith/scripts/lib/cmd-review.sh` | 走同一套两把锁：本进程 fd 8/9 + 门禁 `8>&- 9>&-`；入场检查（活登记身份不同 ⇒ 门禁不跑、`mutexbroken`）；跑完复核身份（锁没了 ⇒ 判定不可信、FAIL、抬头带机器可读标记）；收尾只删**自己**的持有者记录；记录与上限读 pair |
| `skills/teamsmith/tests/perf.sh` | 性能锁一并走同一实现（D4）：两把锁、序列固定、子进程关 fd、记录带身份、有界轮询、拿不到 = 没结论（exit 3，退出码集合不变）、跑完复核身份（破坏 ⇒ 判红 exit 2）；容器那一层由宿主层持锁（不再取锁、不透传身份） |
| `skills/teamsmith/tests/flip-p287-name.sh`、`flip-p287-lock.sh` | 两条新翻转夹具（各 `--self-test` 全绿；红侧见下） |
| `skills/teamsmith/tests/fixtures/p287/*.sh.in` | `--lint` 的两条红侧素材（写死 `/tmp`、家族前缀在但丢了 ns）与一条绿侧素材；`.sh.in` 后缀让它们不进扫描面 |
| `skills/teamsmith/tests/{section-paths,section-budgets,loop-inventory}.tsv` | 34c/34d 两行的路径声明、预算（max(⌈band×4⌉,60)）与循环上限登记 |
| `skills/teamsmith/references/protocol.md` §9b-2、`SKILL.md`、`templates/AGENTS.section.md.tmpl`、`AGENTS.md` | 协议文本：锁对与顺序、身份、守卫、等待者、入场检查、安全清理入口、`review` 的 `mutexbroken`；一句话把「记录在 `<lock>.holder`」改成伴生锁那一份 |
| 各夹具/产品的临时模板（约 20 处） | 逐条改成点开头或带 ns：`cmd-review`（queue marker、p91-merge3）、`cmd-watch`（npm）、`common`（inotify 探针）、`panel-draft-send`、`smoke`（select 副本、queue marker、FAST 私有锁）、`panel-cpu`/`panel-knobs`/`section-select`/`section-needs-audit`/`tmux-cap`/`section-guard`/`tmux-iso`/`checkout-shape-probe`/`ledger-ban`/`help-surface`/`scenario`/`flip-p49`/`flip-m33`/`flip-p158`/`routes` |

## Verification evidence (must have actually been run)

固定验收行（brief 的 13 行 + gate-guard 一条；全部在本 worktree、私有外层锁 `TEAM_SMOKE_LOCK=/tmp/p288-acc/machine.lock` 下跑；tip `ad928a70`，tree `a7c8e93e`）：

```bash
$ TEAM_SMOKE_LOCK=/tmp/p288-acc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34c,34d
#6 34d · 身份面：锁被删/被换 → 一行点名 + 证据 + 停跑；入场检查；等待者（P287 · …） · 用时 146s · ✓101 ✗0 SKIP0 · ticks 101
#5 34c · 命名面：运行条目点开头或带 ns，平铺家族够不着（P287 · …） · 用时 19s · ✓20 ✗0 SKIP0 · ticks 20
== 选段结果 ==  ✓ 142  ✗ 0
rc=0

$ TEAM_SMOKE_LOCK=/tmp/p288-acc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34,34b
#5 34 · 门禁锁：排队/运行分开记账（P26/G1：…） · 用时 52s · ✓36 ✗0 SKIP0 · ticks 36
#6 34b · 门禁锁排队守卫：超上限要大声失败并点名持有者（P66） · 用时 59s · ✓122 ✗0 SKIP0 · ticks 122
== 选段结果 ==  ✓ 158  ✗ 0
rc=0

$ TEAM_SMOKE_LOCK=/tmp/p288-acc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 0e
#5 0e · 段落自述：看门狗 / 预算表 / 循环清单（P70） · 用时 52s · ✓44 ✗0 SKIP0 · ticks 44
== 选段结果 ==  ✓ 44  ✗ 0
rc=0

$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test
FLIP 全绿：leg0 全绿 + 两条 shadow/lint 腿各按预期红（证据：/tmp/.teamsmith-p287flip-name-pm_skills-deb708fe.exp0BT）
rc=0

$ bash skills/teamsmith/tests/flip-p287-lock.sh --self-test
FLIP 全绿：绿侧按预期点名并停跑，两条对照腿各按预期静默（证据：/tmp/.teamsmith-p287flip-lock-pm_skills-deb708fe.ymy8sq）
rc=0

$ bash skills/teamsmith/tests/tmp-hygiene.sh --self-test          # rc=0（含 --break=flat-name / no-ns / … 全部红侧）
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint
检查了 32 个 mktemp 模板（…/skills/teamsmith；规则：点开头或带 ns「pm_skills-deb708fe」，根还要在 owned 家族里）
owned 家族 / TMPDIR / 命名空间口径全部合规
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check           # ok 8 bad 0，rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check       # 扫描 85 行清单 / 85 个循环，配平 85，全过
$ bash skills/teamsmith/tests/section-guard.sh --budget-check     # 覆盖 135/135 段且每行满足 max(ceil(band×4),60)，全过
$ bash skills/teamsmith/tests/gate-guard.sh                       # 四向都过（门禁无判定、旋钮在岗、性能套件带标记、时长比较只在段落守卫）
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict   # Totals: 23 passed, 0 failed，rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
rc=0
$ git diff --check     # rc=0
$ git status --short   # 空（写报告前）

$ bash skills/teamsmith/tests/spec-refs.sh --check
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
spec-refs: judged 112 reference(s) (50 distinct) in 12626 effective line(s); retired 0; undeclared 1; …
rc=1        # ← main 上同款（见 0.3），指向 PM 拥有的 docs/team/tasks/P1.md
```

## 交付前的 merge main 与合并后的重跑

按 PM 的要求（tip 上 main 必须是祖先；squash 落地会回退别人已验过的成果）补了第二次 `git merge main`：

```bash
$ git merge main --no-edit
Merge made by the 'recursive' strategy.        # 无冲突；按双方保留
$ git merge-base --is-ancestor main HEAD && echo yes
yes
$ git log --oneline -1
03493d07 Merge branch 'main' into task/P288-gate-lock-external-deletion-apply

$ # 合并后在同一条闭包选段上重跑（tip 03493d07，tree 93241a91，main=d44c6eb3）
$ TEAM_SMOKE_LOCK=/tmp/p288-macc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34c,34d
== 选段结果 ==  ✓ 142  ✗ 0        rc=0
$ TEAM_SMOKE_LOCK=/tmp/p288-macc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34,34b
== 选段结果 ==  ✓ 158  ✗ 0        rc=0
$ TEAM_SMOKE_LOCK=/tmp/p288-macc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 0e
== 选段结果 ==  ✓ 44  ✗ 0         rc=0
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test   # FLIP 全绿              rc=0
$ bash skills/teamsmith/tests/flip-p287-lock.sh --self-test   # FLIP 全绿              rc=0
$ bash skills/teamsmith/tests/tmp-hygiene.sh --self-test                              # rc=0
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint           # 32 个模板全部合规       rc=0
$ bash skills/teamsmith/tests/section-select.sh --check                               # rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check   # 全过                    rc=0
$ bash skills/teamsmith/tests/section-guard.sh --budget-check # 全过                    rc=0
$ bash skills/teamsmith/tests/gate-guard.sh                   # 四向都过                rc=0
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict               # rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: … hits=0 names=ok user=resolved                                          # rc=0
$ git diff --check                          # rc=0
$ git status --short                        # 空
$ bash skills/teamsmith/tests/spec-refs.sh --check
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md   # rc=1（下方「main 上同款」）
```

合并后的 main 侧对照（只读，在**主检出**上跑，`main` 自己的 tip 就是 `d44c6eb3`）：

```bash
$ bash skills/teamsmith/tests/spec-refs.sh --check
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
spec-refs: judged 112 reference(s) … undeclared 1 …                            rc=1
```

main 这次带进来的 12 个提交**全是文档/账本/openspec 文档**（`git diff --name-only` 里
`skills/teamsmith/**` 零命中），与我的写集没有语义交集；合并无冲突，闭合选段在合并后的 tip 上
全绿。第一次交付时的证据块（tip `ad928a70`）保留在上面，作为合并前的对照。

### 合并到最终 main 后的终检（tip `702323ef`，tree `600eb12b`，main=`d3806d1e`）

main 在复验窗口里又前进了一格（`d3806d1e` = P288 冻结 + 派 V53，只动 `docs/team/**`），按纪律再合并一次
（`702323ef`，main 已是祖先、无冲突、工作树干净），并在合并 tip 上重跑同一条闭包：

```bash
$ git merge main --no-edit && git merge-base --is-ancestor main HEAD && echo yes
yes                                  # 无冲突；main 带进来的两个提交零命中 skills/**
$ git diff --stat 03493d07..HEAD -- skills/teamsmith openspec/changes/gate-lock-external-deletion
（空）                                # 写集与上一次已验证的树（03493d07）逐字节相同

$ TEAM_SMOKE_LOCK=/tmp/p288-facc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34c,34d   # ✓142 ✗0 rc=0
$ TEAM_SMOKE_LOCK=/tmp/p288-facc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34,34b   # ✓158 ✗0 rc=0
$ TEAM_SMOKE_LOCK=/tmp/p288-facc/machine.lock bash skills/teamsmith/tests/smoke.sh --select 0e       # ✓44  ✗0 rc=0
$ bash skills/teamsmith/tests/flip-p287-name.sh --self-test / flip-p287-lock.sh --self-test  # FLIP 全绿 rc=0
$ bash skills/teamsmith/tests/tmp-hygiene.sh --self-test  # rc=0    --lint  # 32 个模板全合规 rc=0
$ bash skills/teamsmith/tests/section-select.sh --check   # rc=0
$ bash skills/teamsmith/tests/section-guard.sh --loop-check / --budget-check                 # 全过  rc=0
$ bash skills/teamsmith/tests/gate-guard.sh               # 四向都过                            rc=0
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict                     # rc=0
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"   # hits=0 rc=0
$ git diff --check  # rc=0     $ git status --short  # 空
$ bash skills/teamsmith/tests/spec-refs.sh --check
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md   # rc=1（main 上同款，见 Findings 1）
```

## OBSERVE · 我自己清理临时根时误伤了别的席位（如实记录，不是代码缺陷）

**事实**：在收尾清理 `/tmp` 杂物时我用了**项目共享命名空间**的通配（`/tmp/teamsmith-smoke-pm_skills-deb708fe.*`
与 `/tmp/.teamsmith-smoke-{heartbeat,guard.pid,diag}.*`），因此：

- **命中了一个正在跑的运行**：dev 席位的选段运行 `pid 2086606`（`/tmp/teamsmith-select.2066587.sh`，
  起跑约 07:02，`PWD=.worktrees/dev`，`SMOKE_LOCK=/tmp/teamsmith-smoke.lock` ⇒ `TMPDIR` 未设 ⇒ 根名
  `teamsmith-smoke-pm_skills-deb708fe.*` 正落在通配里）。它的根被我删掉，进程此后消失 ⇒ **它那一段要重跑**；
  复验记录里不得读成代码红（该运行的判据会自己报「$TMP 消失 / 不是对代码的判定」）。
- 判据（为什么只此一个）：此刻该 ns 下**唯一的活根** `…deb708fe.lzIyby` 的 birth 是 **07:28:17**（**晚于**
  我的 rm，且是我自己的终检运行 ⇒ 已被我按「只清自己的具体路径」的新规矩保留）；命中发生在 07:25–07:27，
  当时在跑的只有我自己的若干夹具与这一个 dev 的选段运行。
- **没有命中**：PM 在 `/proc` 里看到的两个 `p281-orphan2/…/repo` 活进程不是任何人在跑的门禁 —— 它们是
  §34b⑪(b) 夹具的**诱饵进程**（`trap "" TERM` ⇒ 对 TERM 免疫，只有 KILL 能收），由已经结束/被杀掉的运行
  留下；其中 **25 个归我**（场景根 `P8B5fp/qGHAg6/tph6yf/StB94p/M2RwYW/a5xDTc/EABAeX/FQvfTt/bQ6bqj/Z6ljBt/gZLBKR/CD63rx`），
  我已逐个核对 argv/env 后清掉（10 个选段副本 + 23 个诱饵）。现在剩余的**不是我的**：4 个在
  `/tmp/dev3-iter-tmp`（dev3 席位）+ 约 15 个在改动前的平铺根 `/tmp/teamsmith-smoke.<rand>`（无法归属）。

**教训与已落地的规矩**（已钉成项目记忆）：清理只限**自己那次运行的具体根**（按自己的标记/pid 识别），
跨席位、跨项目一律不动；临时根的批量清理走 `tests/tmp-hygiene.sh --sweep`（按占用与年龄判、跳过在用的根）。
这条与 D184 的三次事故同族（共享命名空间 + 通配删除），只是这次是我做的。

**顺带的产品观察**（不在本变更范围，建议另开小单）：在 §35 之前死掉的 `--select 34,34b` 运行会留下
⑪(b) 的诱饵自旋进程（TERM 无效、CPU 0.2s 一转），只有 §35 的孤儿检查会收它们；夹具自己收尾（或让
诱饵认 TERM）能让「被中断的选段运行」也干净退场。

## 0.1 七条裁定 → 落点

| 裁定 | 落点（可判证据） |
|---|---|
| D1 伴生锁 + 发布路径兼容 | 顺序 = 发布路径（fd 8）→ 伴生锁（fd 9），两把都永不 unlink；`34d④`（两把锁文件跑完都在）+ `34d⑥`（两把锁路径与角色自述）+ `34d⑦`（删伴生锁 → FAIL）+ `34d①`（发布路径单独丢失**只印不停**） |
| D2 保留兼容声明（只印不停） | `34d①`：删发布路径 → 一行 + 证据里一节，仍出结果行、退出码 0；`gate_lock_snapshot` 对 `gone` 的错误码与语义在 report 与 protocol §9b-2 里都写明 |
| D3 入场检查 | `34d③`：活登记记着**另一个身份** ⇒ 点名 + 不跑套件 + exit 2（绿侧），`--break=no-entry-check` 的 shadow 照跑（红侧） |
| D4 性能套件那把锁一并 | `perf.sh` 走同一实现（两把锁/身份/复核/有界轮询）；`gate-guard` 的「perf.sh 带标记」仍绿；容器层不再取锁（宿主层持锁），旧键 `TEAM_PERF_LOCK_WRAPPED` 已消失 |
| D5 `ns = <slug>-<hash8>` | `common.sh:team_project_ns`；34c①②③（根名带 ns、台账头与 owner 标记带 ns）+ 34c④（worktree 共享、两仓库不同、外来仓库根不被当候选） |
| D6 `--lint` 扩到夹具与产品模板 | `--lint` 32 个模板（改动前 15 个、只扫 `tests/**`）；34c③ 十三个模板逐条判合规；仓库里**已经没有**「家族前缀在但丢了 ns」的模板（`grep` 实查） |
| D7 新开 34c/34d | 两条新段 + 两张 tsv 登记；`34`/`34b` 的既有一字未回退（158 条断言全绿，含 P281 的全部合同点） |

## 0.2 合同的六个场景 → 落点

| 场景 | 落点 |
|---|---|
| ① 命名面：点开头或带 ns，平铺家族够不着 | `34c①②`（真入口运行里每个条目逐条点名；平铺模式零命中）+ `flip-p287-name` leg0（同一判据的第二实现） |
| ① 台账头带 ns | `34c②`（主人活着时抓的台账头，字段 `ns=`） |
| ① ns 只与项目绑定 | `34c④`（主检出 + worktree 共享、第二个仓库不同、`--status` 把外来根点名而**不当候选**） |
| ① 静态闸：家族内的根模板 + 家族外/写死绝对路径的模板 | `34c③` + `flip-p287-name` leg2（两份红侧素材各红且点名 `file:line`，合式绿） |
| ② 删锁 ⇒ 一行点名 + 工作根之外的证据 + 安全点停跑 | `34d①`（真入口；无结果行、exit 2、证据落 `$TMP` 之外）+ `flip-p287-lock` leg0 |
| ② 换锁 ⇒ 两侧身份、与「已不在」可区分 | `34d②`（`rm`+重建 与 `mv` 覆盖两种形状；`replaced` + 期望/实测两个 inode） |
| ② 干净运行不误报、锁文件不被 unlink | `34d④`（顺序两套：无点名行、结果行、退出码 0）+ `34d⑥` |
| ③ 入场检查 + shadow | `34d③` |
| ④ 等待者：路径变了就说出来并继续等；旧记录用 `?` | `34d⑤` + `34b②`（旧写入者的记录打印 `version=legacy` 与缺字段 `?`，不写「持有者未知」） |
| ⑤ review 侧：门禁丢了锁不许 PASS | `34d⑦`（真跑一次 `team review`，门禁运行中删锁 → rc≠0、判定 FAIL、抬头机器可读标记、排队记账三键不变、`team_review_verdict` 仍解析 FAIL）+ `flip-p287-lock` leg3（同一场景、把复核拆掉 ⇒ 判 PASS，红侧） |
| ⑥ 六个场景的方向不许改 | 上面每条都在新段里，`34`/`34b` 只做机械改写（记录读伴生锁边上那一份）+ 四条新增断言（兼容声明只读、`lock_identity`、`lock_dev_ino`、伴生锁登记清空） |

## 0.3 改动前 / 改动后

改动前 = 独立检出 `/tmp/p288-pre`（detached `main` = `9fff51d3`，工作树干净；**同一台机器、同一条命令**）：

```bash
$ git -C /tmp/p288-pre log --oneline -1
9fff51d3 docs(openspec): the publishing rule keeps its teeth

$ TEAM_SMOKE_LOCK=/tmp/p288-base/machine.lock bash skills/teamsmith/tests/smoke.sh --select 34,34b
  ✗ 34b⑫ 收尾：登记随它退出消失（只删自己那条）（期望 [1]，实际 [0]）
  ✗ 嵌套运行在生它的那一段收口后仍活着：pid=… kind=nested … → 只对这个登记过的 pid 发信号收尾
== 选段结果 ==  ✓ 153  ✗ 1
rc=1

$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint
检查了 15 个 mktemp -d 根模板（/tmp/p288-pre/skills/teamsmith/tests）
owned 家族 / TMPDIR 口径全部合规
rc=0

$ ls -d "${TMPDIR:-/tmp}"/teamsmith-* | wc -l     # 事件那条 glob 的射程：99 个平铺条目
99
$ ls -d "${TMPDIR:-/tmp}"/review-* | wc -l
1
```

改动后（本分支 `ad928a70`）：同一条 `--select 34,34b` → `✓158 ✗0` rc=0（见上）；`--lint` 32 个模板、
扫描面覆盖整棵 skill 树；新的运行条目全部点开头或带 ns。**改动前那 100 条平铺残余照原样留着**
（本变更只保证「不改动前的历史平铺残留」，见 design §10 的诚实边界与 spec 的相应 requirement）。

## Flip evidence

三条腿的绿不是橡皮章 —— 每条都有「把实现拆掉就变红」的对照：

1. **命名面**（`flip-p287-name.sh --self-test`）：leg0 真入口运行里 20+ 个条目逐条点名（点开头或带 ns、
   平铺模式零命中）——绿；leg1 用被测树自己的翻转开关 `TMP_ROOT_BREAK=flat-name` 让根回到平铺名 ⇒
   平铺模式**必须命中**（红侧成立）；leg2 两份 `--lint` 副本（写死 `/tmp`、家族前缀在但丢 ns）各红并
   点名 `file:line`，合式绿。
2. **身份面**（`flip-p287-lock.sh --self-test`）：leg0 运行中外部 `rm` 伴生锁 ⇒ 界内一行「已不在」+
   证据里的期望/实测身份 + 证据在 `$TMP` 之外 + 最后段落 + 无结果行 + exit 2——绿；leg1
   `--break=no-lock-guard`（仅 `TEAM_SMOKE_FIXTURE=1` 生效）同场景不点名、跑完、exit 0（改动前形状）；
   leg2 直接在**改动前的树**（`main` 的 `git archive`）上做同一件事 ⇒ 同样静默；leg3 变异树（把
   `review` 跑完的身份复核改成 `if false`）同场景 ⇒ 判 PASS 且一字未提互斥。
3. **P281 既有的 34/34b 不回退**：本分支把它们从红（改动前基线 ✓153 ✗1）带到全绿（✓158 ✗0），
   其中两条正是我自己踩出来的回归、在批次里先红后绿：`local gate_rc=0` 在排队循环**之后**声明会把
   排队撞上限写下的 `gate_rc=1` 抹成 0（34② 一度判成 PASS）；认领凭据 `SMOKE_LOCK_CLAIMER_*` 被
   子孙继承 ⇒ 嵌套运行不落 `.runs/*.run`（34b⑪(b) 一度 ✗）。修法分别写进 commit message。

## Findings（不在本变更范围，复验时要知道）

1. **`spec-refs --check` 的 1 条 undeclared 是 main 上就有的**：`openspec/specs/extension-slash/spec.md:47`
   指向 `docs/team/tasks/P1.md`（PM 拥有的任务书，本席无写权）。改动前的检出上输出逐字相同。
2. **改动前的 `main` 在 34/34b 上是红的**（34b⑫ 残登记、另一条嵌套运行孤儿收口的断言）。两条都是
   P281 家族，与 P287 的写集重叠；本分支已把它们带绿（属于「不改语义的机械改写」之外的顺带修复，
   若 PM 认为该由 P281 处理，请指名 —— 改动都在 `smoke.sh` 的收尾与凭据清理两处）。
3. `--lint` 从「家族内的 `mktemp -d` 根模板」扩到「临时根上的每个 `mktemp` 模板」后，扫描面里仍有
   两处历史遗留的平铺名字面量（`routes.sh`/`flip-m33.sh` 等的匹配模式），它们是**扫描器自己**的模式，
   不是要建的路径；本次只保证「会建东西的模板」合规。
4. **在飞写者重叠面**：本分支与另一名在飞席位都改了 `help-surface.sh`（且对方还动了
   `common.sh`/`smoke.sh`/`section-*.sh` 一大片）。交付前已 `git merge main`（`d4305847`），
   `help-surface.sh` 两处改动是**不相邻的行**、自动合并无冲突；合并后 `34c/34d/34/34b/0e` 与全部
   静态自检重跑一遍全绿（上面的验收证据就是合并后的 tip `ad928a70`）。`common.sh`/`smoke.sh` 上
   与本变更无重叠区（本席只加 ns 函数与锁机器），两边的语义都没被对方覆盖。
5. 嵌套运行的 `$TMPDIR` 必须在**临时根顶层**且名字短：tmux 私有 socket 有 AF_UNIX 路径上限（107 字节），
   套在深目录里会超（`34d`/`34c` 的夹具都据此改了形状，注释里写明）；这属于既有约束，不是本变更引入。

## Decisions and deviations

1. **34d⑦ 的断言用**「抬头里机器可读的标记」而非内部键名：`gates_marker=mutexbroken` 是**内部变量**，
   记录里的渲染形是与 `queuecap` 同形的抬头旗标（`gate mutex broken（互斥被破坏：判定不可信）`）。
   为让「机器可读」这条真的成立，本席给 `mutexbroken` 补了这条旗标（与 `queuecap` 并列），protocol.md
   的措辞同步改成「内部值 `mutexbroken`；记录里渲染为 `gate mutex broken`」。
2. **夹具红侧开关用 `--break=<阶段>` / `TEAM_SMOKE_BREAK`（仅 `TEAM_SMOKE_FIXTURE=1` 生效）**：真路径
   遇到它只打印一行「忽略它」，不静默降级；命名面的红侧复用 `tmp-root` 自己的 `TMP_ROOT_BREAK`
   （design §9 ⑥ 点名的那个开关）。
3. **认领凭据用完就扔**（`unset SMOKE_LOCK_CLAIMER_*`）：这是 P281 的 F4 教训在新形态上的加固 —— 判据
   本身不靠它（靠记录里活着的 pid 或父进程 `/proc` 里那个身份相符的描述符），这一条只防「下一代误认」。
4. **`team review` 的 `mutexbroken` 有两种时刻**：入场检查拒绝（门禁**没跑**）与跑完复核（门禁跑了但
   判定不可信）。后者**不**写「门禁没有运行」（34d⑦ 有一条断言钉这一点）；两者共用同一个抬头旗标。
5. **`perf.sh` 的退出码集合不变**（0/2/3/4）：拿不到锁仍是「没结论」exit 3；运行期间互斥被破坏 ⇒
   exit 2（原来只可能是断言失败，现在多一种「读数不可信」的原因，语义上更诚实）。
6. **34c/34d 的预算**按实测（19s / 146s）设 band 30/240，公式 `max(⌈band×4⌉,60)` 与 P70 的守卫一致；
   `--select 34c,34d` 整段 165s（含前导段），远在预算内。

## 未跑的东西（诚实边界）

- **没有跑全套门禁**（`smoke.sh` 无参数）：本席只跑了 brief 点名的段与三条静态/自检命令。整套留给 PM
  的独立复验（another seat，不是本席）。
- 没有碰机器锁的真实互斥：所有验收运行都用私有 `TEAM_SMOKE_LOCK`（`/tmp/p288-acc/machine.lock`），
  没有拿过 `${TMPDIR:-/tmp}/teamsmith-smoke.lock`；`team review` 的两次夹具运行也都在私有锁与私有沙盒仓里。
- 没有改任务书、没有改 `openspec/changes/**` 的 proposal/design/tasks（只有 spec delta 与它一致）、
  没有动 `docs/team/**` 的账本面（report 除外）。
- 历史平铺残留（99 + 1 条）**没有清理**（design §10 的诚实边界；清理是另一件事）。

## Suggested next steps

1. PM 独立复验：`git merge main` → 跑**整套**门禁（`openspec validate --all --strict && bash
   skills/teamsmith/tests/smoke.sh`），至少覆盖 `34c`/`34d`/`34`/`34b` 与两条新翻转夹具。
2. 由**没写过本变更**的席位（verify）自己造删锁/换锁现场（不许只跑作者夹具），并复核 `--select 34d`
   的预算与 `--select 34c` 的命名面证据。
3. `spec-refs` 那条 undeclared 建议单独开一张 PM 的杂务单（改 `docs/team/tasks/P1.md` 的引用面）。
