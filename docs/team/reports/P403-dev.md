# P403 · 指令瘦身 Apply 第三片：SKILL 与参考手册的分工与纠错

agent: dev   status: delivered（待 PM 独立复验）   time: 2026-11-03T03:20Z
branch: `task/P403-instruction-apply-3`   PR/MR: -（本仓 local 模式，未推送）

## 答案

`tasks.md` 的 **2.4、2.5** 已完成并自测绿。日常 `SKILL.md` 从 **334 行 / 38,575 B 收到 251 行 / 31,306 B**
（−83 行 / −7,269 B）：命令表、角色入口、深读表与职责留在原地，长 runbook（PM 循环、重载、git/forge、巡检、
兼容性）改成「做什么决定 + 指到哪个既有 reference」。两处规格点名的声明面**逐字节未动**（下方有 diff 为空
的证据）：双门禁分工段，以及 frontmatter `description` + `## Agent adapters` 小节 + 深读表那一行。

`templates/PROTOCOL.md.tmpl` 收成操作摘要（101 行 / 7,548 B → **94 行 / 7,150 B**）：本地交付不再宣称 push/PR，
门禁段写双门禁与各自命令，容量写全判据，巡检不再自称续跑 agent，其余全部改为指针。

2.5 的纠错落在既有家：`protocol.md` §9 容量口径补齐 `MemAvailable` / RAM+swap / 磁盘 swap(zram 不计) /
解析后的临时根可用性 / temp+worktree 的字节与 inode 下限，§8 删掉与 watchdog 规格冲突的「巡检自动续跑」段；
`workflows.md` §E3 改成 0=取到读数、3=量不了（无 2/4），§F 拆出 local 不 push 与 remote 路线，§D 的 `team up`
注释改正，§I 删掉「巡检管理停掉的 agent」；`migration.md` 新增 **§1b** 承载既有项目 AGENTS 刷新契约，并改正
§2/§2c 两处「bootstrap 也会跑 init 的 AGENTS 写入器」的误导说法。

**中途抓到并修掉一处自己引入的回归**：PROTOCOL 模板第一版压缩时删掉了 `openspec change show` 与
`openspec archive -y`，smoke §2 的两条既有断言当场变红（`✓37 ✗2`）；补回后 §2 转绿（`✓39 ✗0`），见「Flip
evidence」。**未做**：全量门禁、真实项目 init、合并/归档/推送；本片只改文档与模板，未改任何行为代码。

## 对应 tasks.md 条目

| 条目 | 做了什么 | 证据 |
|---|---|---|
| 2.4 SKILL 收成索引与职责 | 命令表原样保留；PM 循环、重载三路径、git/forge 配方、巡检/别名期、兼容性细节改为「决定 + 指针」；职责（回复义务、所有权、凭据、共享状态授权、工作树、分支模式、四个 adoption gates）仍在 SKILL 本地 | 334→251 行；本章「规则走查表」 |
| 2.4 PROTOCOL 模板收成摘要 | 角色/生命周期/硬规则/门禁/模型策略/OpenSpec/巡检收成操作摘要 + 指针；改正本地交付、双门禁、容量、巡检四处口径 | 101→94 行；§2 断言 `✓39 ✗0` |
| 2.5 容量口径（protocol §9） | 从「只有 swap 与 RAM+swap 两个条件」改成与 `dispatch#The capacity floor protects the host` 一致的六条腿；§6 内存表补一句指向 §9 的非内存腿 | 下方「2.5 纠错逐条」第 1 条 |
| 2.5 巡检矛盾（protocol §8 / workflows §I） | 删掉「停掉的席位会被自动续跑回同一任务」的段落，改为「报为待办、由 PM `team resume`（或人的 `team up --agents` 兜底）」 | 第 2 条；代码侧 `cmd-watch.sh:6` 自述「agent 停了 → 不管」 |
| 2.5 性能口径（workflows §E3） | 旧文写 `0/2/4/3` 四种判定；改成 `0`=取到读数、`3`=量不了，无阈值、无判定 | 第 3 条；`perf.sh` 只有 `exit 0/3` |
| 2.5 本地交付（workflows §F / PROTOCOL 模板） | local 模式示例不再 `push origin`；remote 无 PR 时的 push 单列，并写明那是共享状态变更、需授权 | 第 4 条 |
| 2.5 既有项目刷新契约（migration §1b） | 边界形状、外部字节保留、渲染参数、主检出目标、init 的其它写入、非事务、force/拒绝边界、PM 先盘点再搬出 | 第 5 条 |
| 2.5 两处误导说法（migration §2/§2c） | 「跑一次 `team init`（或 `team bootstrap`）」与「下一次 `team init`/`team bootstrap` 原地重写标记」改成「显式 `team init`」，并写明既有合法契约时 bootstrap 不跑该写入器 | 第 5 条；`cmd-bootstrap.sh:307-312` 在 `had_config=1` 时只装 skill、不调 `team_cmd_init` |

## 验收（实际执行，含 rc 与输出尾）

### 1. 静态门禁（最终 tip，逐条）

```
$ ~/.cache/openspec-1.8.0/node_modules/.bin/openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) in 13580 effective line(s); retired 1; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1
rc=0

$ git diff --check
diff-check rc=0
```

### 2. 简报指定的选段：`--select 0b,1b,18b,19,39`（最终 tip）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0b,1b,18b,19,39 </dev/null
#1 0 · 临时仓库 · ✓3 ✗0
#2 0b · skill 可被 pi 解析器加载 · ✓3 ✗0
#3 0c · 静态检查 · ✓9 ✗0
#4 0d · 冲突标记守卫 · ✓9 ✗0
#5 1b · bootstrap（一条命令初始化） · ✓24 ✗0
#6 18b · 拆分不变量（description 路由 / 指纹范围 / 零改动） · ✓16 ✗0
#7 19 · OpenSpec 五阶段流水线 · ✓16 ✗0 SKIP10
#8 39 · npm CLI 与项目 skill 安装 · ✓1 ✗0（内部 install-shape.sh 203 条断言 ✓203 ✗0）
账本自查： 8 段收口 · 增量 ✓81 ✗0 SKIP10 ｜ 结果行 ✓81 ✗0 —— 一致
== 选段结果 ==  ✓ 81  ✗ 0
rc=0
```

选段器按依赖展开后实际执行 **8 段**（`0 0b 0c 0d 1b 18b 19 39`）。**没跑的 127 个键**：选段运行只对它执行过的
段负责（尾部逐键列出，未截断）。唯一与本次改动相关的 SKIP 是 §19 的 10 条「本仓库为 Pi 生成了相位命令/skill」
—— 本检出按构造没有 `.pi/prompts`/`.pi/skills` 机器生成面，逐条可见 SKIP（跳过不是通过）。

### 3. 附加选段：文档一致性、英文不变量、升级配方（同一最终 tip）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 14b,18,64 </dev/null
#5 14b · 文档一致性：已删命令不得回潮 · ✓26 ✗0
#6 18 · 英文正文不变量与安装器唯一入口 · ✓25 ✗0
#7 64 · 升级配方（FAST · 组 doc,selftest）· ✓1 ✗0 SKIP1（walk 组 FAST 跳过）
账本自查： 7 段收口 · 增量 ✓76 ✗0 SKIP1 ｜ 结果行 ✓76 ✗0 —— 一致
== 选段结果 ==  ✓ 76  ✗ 0
rc=0
```

### 4. 附加选段：init 渲染、模板与文档、迁移指引（同一最终 tip）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 2,12k,19 </dev/null
#5 2 · init · ✓39 ✗0
  ✓ PROTOCOL.md 给出日常 OpenSpec 命令
  ✓ PROTOCOL.md 说明归档命令
#6 19 · OpenSpec 五阶段流水线 · ✓16 ✗0 SKIP10
#8 12k · 模板与文档（P24/B7）· ✓32 ✗0
  ✓ 7.4 rendered PROTOCOL carries it
账本自查： 8 段收口 · 增量 ✓112 ✗0 SKIP10 ｜ 结果行 ✓112 ✗0 —— 一致
== 选段结果 ==  ✓ 112  ✗ 0
rc=0
```

同一命令在我修掉那处回归**之前**是 `✓247 ✗2`（`--select 12k,17` 的展开集），两条红就是 `PROTOCOL.md 给出日常
OpenSpec 命令` 与 `PROTOCOL.md 说明归档命令` —— 既有断言确实在判我改的文件，见「Flip evidence」。

### 5. 台账禁令（本分支的树上）

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=2322 hits=0 names=ok user=resolved
rc=0
```

`hits=0` 是在**本 worktree、本分支的树**上跑出来的（含本报告与四个提交后的内容），不是在主检出上跑的。

## 声明面证据（两处规格点名的面）

**① 双门禁分工**：`SKILL.md:64-70`，与改动前**逐字节相同**（`awk` 取出该段后 `diff` 为空）：

```
$ grep -n 'The two gates answer different questions\|Correctness, on every change:\|Performance, separately and before a release:' skills/teamsmith/SKILL.md
64:The two gates answer different questions and are run at different times. **Correctness, on every change:**
65:`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null` (the pair `team review` runs;
67:`bash skills/teamsmith/tests/perf.sh` (front door `team perf`; …
$ diff <(awk '/^The two gates answer different questions/,/never blocks a merge\./' old) <(… new)  → 空（7 行）
```

`references/protocol.md` 的门禁段仍写明「correctness only / no wall-clock」：

```
$ grep -n 'judges \*\*correctness only\*\*' skills/teamsmith/references/protocol.md
847:The gate judges **correctness only**: it contains no wall-clock or CPU-share red line, …
851:(`bash skills/teamsmith/tests/perf.sh`, front door `team perf`) and are **readings** …
```

**② Agent adapters 声明面**（`description` / `## Agent adapters` / 深读表行）与改动前逐字节相同：

```
$ grep -n '^description:\|^## Agent adapters\|references/agent-adapters.md` | The internal seam' skills/teamsmith/SKILL.md
3:description: … Works with Pi; the launch/notify seam is an internal seam (frozen) reserved for a possible future non-Pi adapter, with no compatibility promise. …
147:## Agent adapters (Pi; the seam is internal and frozen)
149:Pi is the promised worker. The four keys below are an **internal seam (frozen)**: reserved for a possible future
150:non-Pi adapter, no compatibility promise, not a public extension point …
216:| `references/agent-adapters.md` | The internal seam (frozen) for launch and notify: …
$ diff（description / adapters 段 25 行 / 深读表该行）→ 三处全空
```

## 规则走查表（SKILL.md → 既有家）

| SKILL.md 原文 | 现在在哪 | 为什么 |
|---|---|---|
| 开头 + 架构图 | 保留；图里一行改成 `reports/<ID>-<a>.md（local branch；remote on the PM's route）` | 本地模式没有无条件 PR；交付口径在 protocol §8e、workflows §F |
| 「Starting a new project」的安装/`team init` 细节 | `teamsmith-init` 的 SKILL.md（既有家）；日常 SKILL 留一句指针 | 初始化本来就在独立技能；日常 SKILL 不当第二个安装教程 |
| 「Name and compatibility」旧路径/别名/契约不变 | `migration.md` §§2–4/6；SKILL 留 5 行（旧名、契约未动、alias 已删、标记由**显式 init** 迁移） | 迁移细节的既有家；顺带改正「bootstrap 也会迁移标记」 |
| Command table | 原样保留 | 规格要求的命令索引；`reply` 与 `say`/`notify` 的读者区分仍在 |
| 双门禁段 | 原样保留（逐字） | verification 规格点名的声明面 |
| 信条段 | 原样保留 | — |
| PM 循环的逐条细节（dispatch 守卫、pre/post-merge 机制、D45 事故史、失败回退命令） | `workflows.md` §§B–F、`protocol.md` §5b/§8e/§9b-2；SKILL 留六个决策点 + 授权停止线 + pre/post-merge 的名字 | 详细序列的既有家；SKILL 只留「做什么决定、何时停」 |
| Specs 的「exit 0 iff every mapped task finished」 | 命令表 `team change status` 行原样保留；五阶段/两条硬规则/change 单元保留 | OpenSpec 定位与门禁保留，细节指 `openspec.md` §5b |
| 「Getting skill updates」三路径表 + 理由 | `migration.md` §6 step 4、`troubleshooting.md` §22；SKILL 留 8 行（scripts 读盘 / 文本要 `/reload` 并重读 / `-e` 要重启 / `/team` 跟 `/reload`） | 升级与重启边界的既有家；「已读文本不会变」这一实质保留 |
| git/forge 的 bash 配方 | `workflows.md` §F（本来就有）；SKILL 留边界（不执行不包装、PM 决定、token 不外泄） | 同一配方不在两处维护；避免把本地模式写成必须 push |
| Agent adapters 小节 | 原样保留（逐字） | agent-adapters 规格点名的声明面（冻结 seam 措辞） |
| Cross-project boundary | 原样保留 | 边界职责 |
| 回复义务长段 | 压缩但仍在 SKILL（标记字面量、手动 post 仅回填、批量、receipt 含义、protocol §4b） | key-replies 要求命令表把 `reply` 呈现为用户出口；命令表原样 |
| pulse 配置/别名期长段 | `protocol.md` §8、`workflows.md` §§D/§I、`migration.md` §2b；SKILL 留一条（metronome、不管 tmux/agent/quota、standby 由人解除） | 机制与边界的既有家；顺带删掉与 watchdog 规格冲突的自动续跑 |
| branch mode / 工作树 / token / 共享状态授权 | 压缩保留（红线，不是 runbook） | 这些不能只留链接 |
| 四个 adoption gates | 新加一条（原先只在 protocol §6 与 PROTOCOL 模板） | 设计要求保留的项；SKILL 是 PM 的入口 |
| Deeper reading 表 | 原样保留（含 adapters 行） | 规格点名的声明面 |
| Requirements | 原样保留 | 依赖契约 |

## 2.5 纠错逐条（改前 → 改后，附依据）

1. **protocol §9 容量**：改前「只有一个拒绝条件：free swap 低于 `TEAM_MIN_FREE_SWAP_MB` 或 RAM+swap 低于
   `TEAM_MIN_TOTAL_MB`」。改后六条腿：RAM+swap / `MemAvailable` / 磁盘 swap（zram 不计，`TEAM_ZRAM_WARN_PCT`
   仅告警）/ 解析后的临时根与 worktree 的 free bytes / 仅在有 inode 表时判 free inodes / 临时根不可用即拒绝且
   不静默换根。依据：`openspec/specs/dispatch/spec.md` 的 `The capacity floor protects the host`（
   `TEAM_MIN_AVAIL_MB` 1024、`TEAM_MIN_FREE_SWAP_MB` 1024、`TEAM_TMP_MIN_FREE_MB` 1024、
   `TEAM_TMP_MIN_FREE_INODES` 100000）；`config.md` §2「Guards (capacity)」是阈值表。
2. **巡检续跑（protocol §8 / workflows §I）**：改前「停掉且任务未完的席位会被自动续跑回同一任务
   （`cmd-watch.sh` 的 resume 路径）」。改后「不续跑：报为待办、由 PM `team resume`；唯一例外是人的
   `team up --agents`」。依据：`cmd-watch.sh:6` 自述「agent 停了 → 不管（agent 归 PM 管：team resume）」、
   `openspec/specs/watchdog/spec.md:225`「It MUST NOT resume stopped agents」。
3. **性能口径（workflows §E3）**：改前 `0`=全绿 / `2`=红 / `4`=无结论 / `3`=setup 失败。改后 `0`=取到读数、
   `3`=量不了；无阈值、无判定。依据：`tests/perf.sh` 只有 `exit 0` 与 `exit 3`（`protocol.md` §9b-2 已同口径）。
4. **本地交付（workflows §F / PROTOCOL 模板）**：改前 local 示例最后一行是 `git push origin <protected-branch>`，
   模板第 3 步要求 worker「push the branch; open a PR/MR」。改后 local 交付=提交好的报告 + 落定的任务分支（无
   push），remote 无 PR 时的 push 单列并写明是共享状态变更、需授权。依据：`TEAM_VCS=local` 下没有远端；设计
   §2 的「Worker/PROTOCOL require push+PR, including local」一行。
5. **既有项目刷新契约 + 两处误导（migration）**：新增 §1b（边界形状、外部字节保留、渲染参数、主检出目标、
   init 的其它写入与非事务性、force/拒绝边界、PM 先盘点再搬出）；§2 的「run `team init` (or `team bootstrap`)
   once」与 §2c 的「the next `team init`/`team bootstrap` rewrites the marker in place」改成显式 `team init`。
   依据：`cmd-bootstrap.sh` 在 `had_config=1` 时只调 `team_init_install_skills`，不调 `team_cmd_init`；
   `cmd-project.sh:427` 的 `team_write_section` 只在 init 里被调用。

## Flip evidence（红 → 绿，真实发生的一次）

```
# 第一版 PROTOCOL 模板（删掉了日常 OpenSpec 与归档命令）：
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 12k,17 </dev/null
  ✗ PROTOCOL.md 给出日常 OpenSpec 命令（… 中找不到 [openspec change show]）
  ✗ PROTOCOL.md 说明归档命令（… 中找不到 [openspec archive -y]）
#5 2 · init · 参考 用时 1s · ✓37 ✗2 SKIP0
== 选段结果 ==  ✓ 247  ✗ 2      rc=1

# 在 Specs 段补回两条命令后（最终 tip）：
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 2,12k,19 </dev/null
  ✓ PROTOCOL.md 给出日常 OpenSpec 命令
  ✓ PROTOCOL.md 说明归档命令
#5 2 · init · ✓39 ✗0     #8 12k · ✓32 ✗0     #6 19 · ✓16 ✗0
== 选段结果 ==  ✓ 112  ✗ 0      rc=0
```

这不是我为本次交付造的变异，而是既有断言在我改的文件上真的红了、补回后真的绿了 —— 它同时证明这些断言不是空跑。

## 决定与偏差

- **`references/protocol.md` 与 `migration.md` 变长了**（+15 / +44 行），`workflows.md` +2 行：2.5 要求把容量
  六条腿与刷新契约**补进**既有家，而不是压短。SKILL 与 PROTOCOL 模板合计减 90 行；整片 5 个文件 +220/−249 行。
  设计明确「不要为了文件更小而删有证据的边界」。
- **`TEAM_WARN_AVAIL_MB` 的默认值在仓里本身不一致**（`common.sh` 2048、`templates/config.sh.tmpl` 4096、
  schema 2048）。这不在 2.5 的纠错清单里，我没有改动它，也没在 §9 里给它写数字（避免把争议值写成事实）。
  这是一条值得另立任务的既有不一致。
- **PROTOCOL 模板的本地/远端交付按 `TEAM_VCS` 分流**，与 P401 的 worker 提示口径一致（local 无 push/PR；
  remote 由 PM 的授权路线决定）；模板仍保留「PM 自己跑 git」这一条。
- 巡检的别名期细节（`watchdog` 命令/窗口/变量、`state/watchdog.*` 文件名）从 SKILL 移出，只在
  `migration.md` §2b 与 `protocol.md` §8 保留 —— SKILL 只留「改名过、别名到 v2.0.0」一句。

## 边界与没做的事

- **未跑全量门禁**：本片只改文档/模板，按 `protocol.md` §9b-2 的选段纪律跑了 4 组选段（最终 tip：
  `0b,1b,18b,19,39` ✓81 ✗0；`14b,18,64` ✓76 ✗0；`2,12k,19` ✓112 ✗0）。没跑的段在每份日志尾部逐键列出；
  选段绿不等于整套绿。
- **未改行为代码**：`scripts/**` 一行未动（`git diff --stat f8ef4caf..HEAD -- skills/teamsmith` 只有 5 个
  文档/模板文件）。2.6 的写入器修正在 P400 已落地，本片只按它写契约。
- **未对任何真实项目跑 init**、未改本仓 AGENTS、未移动任何既有自定义段落、未合并/归档/推送（local 模式）。
- **本片的规则保留判定是作者自读**；独立实质复验（不同席位）与人工逐条阅读尚未发生，按设计属于 6.3。

## 建议的下一步

- PM 在独立 checkout 上复验：`openspec validate --all --strict`、四个静态检查、以及本报告点名的选段
  （至少 `0b,1b,18b,19,39` + `2,12k,19`，后者覆盖我改的 PROTOCOL 模板渲染）。
- 独立复验时建议重点读三处「口径改动」而非只看行数：`protocol.md` §9 六条腿是否与
  `dispatch#The capacity floor protects the host` 逐条对得上；`migration.md` §1b 是否与 `cmd-project.sh` 的
  `team_write_section` 现状一致；`workflows.md` §F 的 local/remote 分流是否与 P401 的 worker 提示一致。
- `TEAM_WARN_AVAIL_MB` 默认值三处不一致（见「决定与偏差」）建议由 PM 另立一条小任务收口，不并入本 change。
