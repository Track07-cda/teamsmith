# P400 · 指令瘦身 Apply 第一片：受管块边界 + AGENTS 短宪章

agent: dev   status: delivered for independent review   time: 2026-11-02T14:50Z
branch: `task/P400-instruction-apply-1`   PR/MR: -（local 模式，分支留在本地）

## 结论

三件事都落地了，且每件都有会变红的断言：

1. **旧的写入器根本不当「一对围栏外独占行的标记」是判据**：它用 `grep -qF` 判「有没有标记」、再用 awk 取
   **第一行** begin 到**第一行** end 之间的所有字节。于是正文（或代码围栏示例）里被引用的一行标记就成了
   受管段起点：围栏示例被整段替换、示例的结束行、真实的开始标记与块内的旧正文一起被吃掉（实测 514 →
   23 306 字节，示例首尾都不见了）。CRLF 文件更糟 —— `$0==b` 匹配不上带 `\r` 的行，**一个字节都没换却打印
   「协议段落已刷新」**（117 → 117 字节）。旧名迁移是全局 `sed`，把围栏里的旧名示例一并改写。
2. **现在写入器先数全部候选、再决定**：候选行 = 围栏外、独占整行、逐字节等于标记的行；只在恰好一对时做
   一次范围替换，标记外每个字节（含行尾与文件末尾有无换行）原样回写；两只对、孤立 begin/end、新旧混用、
   顺序颠倒、以及「没有候选但文件结束在未闭合围栏里」一律**点名拒绝且字节不动**，不再猜、不再每次重跑
   长一块。
3. **AGENTS 受管段换成共享短宪章**：模板 11 385 → 9 101 字节，渲染后的段 11 501 → 9 930 字节（167 → 112
   行），并把「项目自定义规则写在标记之外、升级会替换标记内的内容」写在标记内的显眼处，PM 启动提示词的同
   一条规则指向 `references/migration.md`。没有生成器、没有字数门禁。

## 本片做的 tasks.md 条目

| tasks.md 条目 | 状态 |
|---|---|
| 3.1 写入器改成「只认围栏外独占行的一对标记」，标记外逐字节保留，歧义/未闭合拒绝 | 做（本片） |
| 3.2 旧 `pi-team` 标记按同一处范围编辑迁移，示例里的旧名不动 | 做（本片） |
| 3.3 幂等 + 追加/创建/拒绝形状的覆盖，`--no-skills` 与 linked worktree 路径 | 做（本片） |
| 3.4 AGENTS 模板改共享短宪章（权限/安全/阅读顺序/交付地板），不删 worker 红线 | 做（本片） |
| 3.5 自定义规则落点提示：AGENTS 受管段 + PM 启动提示词，详细家在 `references/migration.md` | 做（本片） |
| 3.6 flip 证据（围栏判据 / 行尾跟随 / 旧名迁移三条窄变异） | 做（本片） |
| PM 提示词瘦身、SKILL/参考手册分工、worker 席位提示 | **不做**（不在本片） |

## 改的是什么

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `team_marker_scan()`（唯一扫描实现：行内容 + 该行自己的终止符 + 候选行 + 未闭合围栏标记）、`team_legacy_marker_candidates()`、重写的 `team_write_section()`；init 不再 `sed` 迁移旧名标记，改为把旧名对交给同一个写入器；`team_migration_reasons()` 用候选行判据替换子串 grep |
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | 共享短宪章 + 「规则写在标记外」条 |
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | Boundaries 里同一条落点规则（指向 `references/migration.md`） |
| `skills/teamsmith/tests/install-shape.sh` | `chk_agents_refresh` 与五个夹具变体（LF / CRLF / 混行尾 / 末行无换行 / 旧名标记）、单条事实断言、拒绝基线、`--no-skills` 与 worktree 两条路径、flip ⑭a/⑭b/⑭c |
| `skills/teamsmith/tests/smoke.sh` | §17 里新增 ②b/②c/②d/②e 四条腿（整文件比较、拒绝基线、追加/创建/幂等）；三处「`grep -cF '<!-- teamsmith:begin -->'` = 1」改成数**独行**（`-cxF`） |

`-cxF` 那三处不是顺手改：新契约下「正文里提到一行标记」是普通内容，旧的子串计数会把模板里那句
`<!-- teamsmith:begin -->` … `<!-- teamsmith:end -->` 也算进去（实测渲染后 2 处），断言本来就是量错了对象。

## 改前 / 改后（同一套探针，`bash probe.sh <tree>`）

探针 = 先 `team init` 造一个干净项目，再把 AGENTS.md 换成一段「标记外项目规则 + 围栏示例 + 真标记对」的
文件，再 `team init` 一次。`red` 树用 `5fb64aea` 的 `cmd-project.sh` + 旧模板，`after` 树用本分支。

| 用例 | 改前（旧写入器） | 改后（本分支） |
|---|---|---|
| A 围栏示例在真标记对之前 | 514 → 23 306，**示例被替换、示例结束行与真开始标记被吃掉**，却报 `update` | 514 → 12 265，标记外逐字节相等（head/tail 比对 True），示例三行原样 |
| B 只有行内引用的标记（无独占对） | 122 → 122，报 `update`（**什么都没干却宣称刷新**） | 122 → 12 012，报 `append`（追加一块），原文逐字节保留 |
| C CRLF 文件里的真标记对 | 117 → 117，报 `update`（**CRLF 永远刷不了，静默失败**） | 117 → 12 118，标记外 CRLF 逐字节保留，插入正文也用自己的 `\r\n` |
| D 结束行没有末尾换行 | 63 → 11 501，报 `update`（顺手长了尾巴） | 63 → 11 900，末尾仍然没有换行（不补字节） |
| E 旧名标记 + 围栏里的旧名示例 | 175 → 23 049，报 `update`（**全局 sed 把示例里的旧名也改写**） | 175 → 12 004，只有受管那两行变成当前名，示例里的旧名两行原样 |
| F 无候选 + 文件结束在未闭合围栏 | 75 → 11 516，报 `update`（**追加落进围栏，每次重跑再长一块**） | 75 → 75，`✗ 标记形状无法确定`，原因点名「文件结束在一个未闭合的代码围栏里」，字节不动 |

改后逐项复核（同一探针输出）：`head==` / `tail==` 四个用例全 True（标记外逐字节相等）、C 的受管段
`body-endings CRLF`（其余 LF，各随自己的 begin 行）。

## 验收命令与输出尾

### 1. 受管段/模板夹具（brief 点名的「AGENTS 夹具升级测试」）

```
$ bash skills/teamsmith/tests/install-shape.sh install
  ✓ 刷新受管段：LF / CRLF / 混行尾 / 末行无换行 / 旧名标记五例整文件等于期望：LF：块外字节逐字节保留、
    受管段等于独立渲染（10309 字节）CRLF：（10440 字节）混合行尾（标记外 CRLF 段 + LF 段）：（10435 字节）
    末行无换行：（10308 字节）旧名标记迁移：（10364 字节）
  ✓ 重复刷新：AGENTS 字节不变（幂等，不追加第二对）
  ✓ --no-skills 也刷新了受管段（旧块内容已消失）
  ✓ --no-skills 刷新后标记行还是示例 1 对 + 受管 1 对（没有长出第二批）
  ✓ worktree 侧检出的 AGENTS.md 一个字节都没被 init 动过（没有私有副本）
== 结果 ==  ✓ 84  ✗ 0  SKIP 0
```

（夹具的构造：`agents_head`/`agents_tail` 自己拼输入，期望文件用「同参数独立渲染出来的受管段」拼回去，
然后 `cmp` 整文件 —— 不是范围断言。）

### 2. 反向自检（brief 点名的「去掉判据必须变红」）

```
$ bash skills/teamsmith/tests/install-shape.sh flip
  ✓ ⑭ 对照：真实树刷新受管段、标记外逐字节保留：LF/CRLF/混行尾/末行无换行/旧名标记 五例
  ✓ ⑭a 翻转：扫描不认围栏（闭合示例里的标记当成受管段）：翻转后红（init 非 0：
     「有多对受管标记（开始 2 行、结束 2 行）」）
  ✓ ⑭b 翻转：正文不再跟随 begin 行的终止符（CRLF 块被写成 LF）：翻转后红（CRLF：整文件与期望不同
     10376 vs 10486 字节）
  ✓ ⑭c 翻转：旧名迁移退化回全局 sed（围栏里的示例被一并改写）：翻转后红（旧名标记迁移：整文件与期望不同
     10470 vs 10466 字节）
== 结果 ==  ✓ 46  ✗ 0  SKIP 0
```

### 3. smoke（分段跑，非全量；本机用 `--select`，逐条给结果）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 17   → ✓ 216  ✗ 0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 2    → ✓  63  ✗ 0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 1b   → ✓  48  ✗ 0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 12k  → ✓  57  ✗ 0   （模板/文档段）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 18b  → ✓  40  ✗ 0   （拆分不变量：init 无代码/指纹范围）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 13c  → ✓ 388  ✗ 0   （渲染面段落总成）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 19   → ✓  40  ✗ 0
$ bash skills/teamsmith/tests/smoke.sh --select 17                      → ✓ 216  ✗ 0   （全模式）
$ bash skills/teamsmith/tests/smoke.sh --select 26                      → ✓ 206  ✗ 0   （全模式）
$ bash skills/teamsmith/tests/smoke.sh --select 28                      → ✓ 418  ✗ 0   （全模式）
$ bash skills/teamsmith/tests/smoke.sh --select 38                      → ✓ 434  ✗ 1   （全模式，见下方「§38 那条红」）
$ bash skills/teamsmith/tests/smoke.sh --select 38   （同一条命令重跑一次）  → ✓ 434  ✗ 1（复现，同一条断言）
$ bash skills/teamsmith/tests/section-select.sh --check → ok 12  bad 0  SKIP 1   rc=0（f9eab8d7 上复跑）
```

### 4. 静态门禁

```
$ ~/.cache/openspec-1.8.0/node_modules/.bin/openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)                       rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) …; retired 1; undeclared 0; …
$ bash skills/teamsmith/tests/ledger-ban.sh
ledger-ban: … scope=published files=2300 hits=0 names=missing user=resolved
$ git diff --check            （空）
```

`spec-refs` 的 `retired 1` 与 `ledger-ban` 的 `names=missing` 都是既有状态：被 retired 的那条引用在
`docs/team/reports/P143-verify/pkg/run-case.sh`，禁令名单 `.pi/team/forbidden-names.txt` 本仓本来就没有；
两个文件都不在本单 diff 里。

## §38 那条红（`panel-b3.sh` 的窗口数）

`--select 38` 全模式跑两遍都是 `✓ 434 ✗ 1`，唯一红项稳定在同一条：

```
✗ 38-i panel-b3.sh 控制台表面（12 场景） 有失败
    ✗ 收前后窗口数不变（一个后端、一个窗口）（期望 [3]，实际 [2]）
```

被量的那段（`panel-b3.sh` 的 `scn_collapse`）：先起一个 `cmd` 辅助窗口跑 `team pulse up … ; sleep 1`，
等控制台首帧后用 `tmux list-windows | wc -l` 记 `wins_before`，按 `q` 收起、等进程换成 `--headless`，
再数一次。代码注释自己写着「`cmd` 辅助窗口的命令末尾有 `sleep 1`，它自己退掉后剩下的才是后端窗口」——
也就是说 3 → 2 正是那个辅助窗口在两次采样之间退掉。它与本单改动（AGENTS 写入器 / 模板 / §17 断言）
没有调用关系。

结论的判据不是推理而是对照跑：把整棵树复制到 `/var/tmp/p400/base-tree`，把本单改过的五个文件全部回退到
`5fb64aea`（`cmd-project.sh`、`AGENTS.section.md.tmpl`、`pm-prompt.md.tmpl`、`install-shape.sh`、`smoke.sh`），
提交成干净树后跑同一条命令：

```
$ cd /var/tmp/p400/base-tree && bash skills/teamsmith/tests/smoke.sh --select 38
✗ 38-i panel-b3.sh 控制台表面（12 场景） 有失败
    ✗ 收前后窗口数不变（一个后端、一个窗口）（期望 [3]，实际 [2]）
== 选段结果 ==  ✓ 434  ✗ 1        rc=1
```

**基线与本分支的数字完全相同（434 / 1，同一条断言、同一对期望值）**，所以这条红是本单之前就有的、与
AGENTS 受管段无关；本单不修它（`panel-b3.sh` 的 `scn_collapse` 采样竞态，属另一个 brief 的边界）。

## V122 阻断项：`section-select --check` 曾在本候选上变红（已修）

`bash skills/teamsmith/tests/section-select.sh --check` 在本分支候选 `1840ee84` 上是
`ok 11  bad 2  SKIP 1`、rc=1，两条都是同一条：

```
bad: 段 17 读了它没声明的路径：token AGENTS.md（源码行 10630）—— 补进该行的 patterns
```

原因是 §17 新夹具的一条 `ok`/`bad` 消息里把项目文件名写成了裸 token（`m71 起动夹具：AGENTS.md 就是…`），
而 `--check` 把「段里出现的路径形状的 token」当读路径来核，§17 当然没声明它。修法不是往 patterns 里补
（夹具并不读那个裸名字），而是让消息不再写裸 token —— 这一条消息不承载判据，夹具真读文件的那一行照旧写
`"$M71/AGENTS.md"`，patterns 一个字母没动。

| 提交 | `section-select.sh --check` | `--select 17` |
|---|---|---|
| `1840ee84`（V122 判定的候选） | `ok 11  bad 2  SKIP 1`，rc=1 | — |
| `f9eab8d7` + `44ffe99c`（修后，本分支） | `ok 12  bad 0  SKIP 1`，rc=0 | `✓ 216  ✗ 0`（FAST，含 §2/§3b/§15b 连带段） |

最终候选（`e7c3cecf` 树，工作树干净）上的一轮完整复跑，日志 `/var/tmp/p400/final.log`：

```
install-shape install → ✓ 84  ✗ 0    rc=0
install-shape flip    → ✓ 46  ✗ 0    rc=0
smoke --select 17     → ✓ 216 ✗ 0    rc=0
smoke --select 2      → ✓ 63  ✗ 0    rc=0
smoke --select 1b     → ✓ 48  ✗ 0    rc=0
section-select --check→ ok 12 bad 0 SKIP 1   rc=0
```

**这条修为什么在上一轮报告里被当成已修**：我先在工作树里改了它、跑绿了 `--check`，但**没提交**；随后为了
定位 §38 的 `panel-b3` 红，我把 `smoke.sh` 整体覆盖成基线版本（`cp`）、再用 `git checkout --` 还原 ——
还原的是**已提交的**那一版，未提交的那条修改就被静静地丢掉了，而 `git status` 于是干净、报告里的
「ok 12 bad 0」是当时真跑出来的、只是不在候选树里。教训写在这里：诊断用的覆盖/还原必须作用在临时树上，
工作树里的改动要么先提交、要么先 `git stash`。

## 观察（不改，属于别处）

- **`--select 1b,2` 会红，且与本单无关**：`section-select.sh` 生成的副本把 §1b 末尾那段（`# ---- 1c.` 起的
  M11 沙盒块连同随后的 `cd "$REPO"`）一起剪掉了，于是 §2 在 `bootrepo` 里跑、`team paths` 认错项目而
  `exit 1`。用 `5fb64aea` 的 `smoke.sh`（本单之前的版本）跑同一条命令，失败一模一样：
  ```
  $ timeout 600 env TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 1b,2
    ✗ 身份隔离失败（team 认错项目/session）：{ "project": "bootrepo", … }
  ```
  所以本单的证据按段分跑，不按 `1b,2` 合并跑。修它属 `section-select.sh` 的剪贴器，不在本单边界内。

## 决策与偏差

1. **拒绝也要有出口**：契约要求「形状不是恰好一对就大声拒绝」，但「文件里一个候选都没有」在旧实现里是
   **追加**路径（首次 init、以及正文只在围栏里引用标记的项目都靠它）。我保留追加，只把「没有候选 + 文件
   结束在未闭合围栏里」判成拒绝 —— 因为往未闭合围栏里追加既落进围栏、又每次重跑再长一块，那不是可用行为。
2. **行尾归属**：受管段正文用 **begin 行自己的终止符**，标记外的行各用各的终止符。混合行尾文件里这两个
   决定互不冲突，且 CRLF 项目拿到的块不会一半 LF 一半 CRLF。
3. **`doctor` 的迁移提示换成同一判据**：旧的是子串 grep，正文里引用一次旧名标记就会让提示永不消失（旧名
   标记已经不会被 init 改写了，提示就成了假警报）。现在它和写入器读同一份扫描结果。
4. **没有加新门禁段**：所有断言都长在既有 §17、install-shape 的两个既有段落里（净零：只新增断言，不新增
   段、不加字数门禁、不加生成器）。
5. **只跑选段，不跑全量**：brief 要求「不要跑整套 smoke」。选段运行不是全套门禁证据，未跑的键已在运行
   输出里点名。
6. **分支没推远端**：本项目的 `TEAM_VCS=local`，派单说明写的也是「local 模式：不用 push，把分支留在本地，
   PM 复验后本地合并」。本仓虽然有 `public`（GitHub）远端，但约定只镜像 `main:dev`，任务分支不乱推；分支
   `task/P400-instruction-apply-1` 留在本地，7 个提交从 `40c7732b` 到本报告。
7. **两次运行作废过**：第一批里我先跑了 `--select 28` 与 `--select 38`，同时提交了测试改动，两轮都被判
   「树在跑动中被改动」（退出码 4、✓/✗ 不作数）。已在干净树上重跑，本报告引用的都是干净树的结果
   （`/var/tmp/p400/gate-sections2.log`、`/var/tmp/p400/base-38.log`）。
