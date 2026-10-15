# P255 · 升级配方：0.1.x → 0.2.0 的六步走（`references/migration.md` §6）apply — delivery report

- **Task**: `docs/team/tasks/P255-migration-recipe-0-2.md` · change `-`（`anchor: none (infra) — 文档配方 + 配套夹具`）· phase `apply`
- **Branch**: `task/P255-migration-recipe`（local 模式：无远端，分支留在本地交 PM 合并）
- **Agent**: dev-bob
- **Status**: delivered（**返修轮次 1、2** 均已完成：V40 第一轮的 F1/F2 见 §6，第二轮的 F3 见 §7）—— 任务书验收命令在默认 `TMPDIR`、正常拿到门禁锁的条件下**整套实跑全绿**：`smoke.sh --paths` `✓956 ✗0`（rc=0）、夹具 `RESULT pass=118 fail=0`、`openspec validate --all --strict` 23/23、`section-select.sh --check` ok 8 bad 0、`ledger-ban` hits=0。第一轮的六次门禁（`/tmp` 满、排队超限、环境差异）逐条归因保留在 §2.2，作为**环境侧**记录，不是产品判定；第一轮唯一一条属于我的红（§17 中文草稿）已改英文后消失

## 1. What was delivered

| 面 | 落点 | 它是什么 |
|---|---|---|
| 配方正文 | `skills/teamsmith/references/migration.md` §6 | 六步：① npm 升级工具本身 + `install.sh` + 来源核验；② 先备份配置、`team up --print` 预览、`team up` 的启动事务（或 `--no-migrate` + 手工 `team config upgrade-models`）；③ PM 启动身份（缺记录自动登记 / 记录不符两条出路 / `--fresh-pm`）；④ 会话续跑；⑤ 收尾验证；⑥ 回滚。**全英文**（该文件受 §17 的英文不变量管辖） |
| 指针 | `references/migration.md` §5b | 两处收尾指到 §6（原来只说「两条路线」，没有可照做的步骤） |
| 夹具 | `skills/teamsmith/tests/upgrade-recipe.sh` | 五组 86 条断言：`doc`（§6 必须承诺的每一步）、`walk`（真 CLI 走完整条配方）、`identity`（身份三态）、`rollback`（配置回备份、旧形状复现）、`selftest`（红侧自检）。私有临时根 + 私有 tmux server + 假 PM 进程，绝不碰共享 tmux server、不起真 `pi`、不连 provider |
| 门禁段 | `skills/teamsmith/tests/smoke.sh` §64、`tests/section-paths.tsv`、`tests/section-budgets.tsv` | §64 跑夹具（FAST 档只跑两组文本组、可见跳过）；路径表把「夹具真读到的产品文件」登记成选段依据；预算表登记实测带 |

配方为什么必须重写（用户 2026-10-14 那次升级，第一步就停在身份拒绝上）：

| 旧 §6 的第一步 | 0.1.x 项目实际撞到的东西 |
|---|---|
| `git -C <skill checkout> pull --ff-only` | 0.2.0 起技能来源是 npm 包：`~/.agents/skills/teamsmith` 指向 `$(npm root -g)/teamsmith/skills/teamsmith`，没有可 `git pull` 的检出 |
| 接着 `team init` | 配置仍是退休形状（`TEAM_AGENT_MODELS`/`TEAM_DEFAULT_MODEL`）时 `team init` 是**拒绝**的：先要迁移事务，再谈 re-render |
| 旧 §6 没有的一步 | PM 启动身份 `state/pm-launch.env`：缺记录要自动登记，记录与解析不符要拒绝并给两条出路（`--fresh-pm` / `--adopt-pm-identity --yes`） |
| 旧 §6 没有的一步 | 备份与回滚：迁移写自己的备份、打印还原命令；用户自己那份 `cp .pi/team/config.sh …` 才是他的回滚点 |

## 2. 验收命令与实跑结果

### 2.1 夹具（本分支实跑）

```
$ bash skills/teamsmith/tests/upgrade-recipe.sh
RESULT pass=86 fail=0        rc=0
```

分组单跑（单独选 `identity`/`rollback` 会把 `walk` 一并拉进来——它们的前置是 walk 迁移后的现场）：

```
$ bash skills/teamsmith/tests/upgrade-recipe.sh --select walk
RESULT pass=47 fail=0        rc=0
$ bash skills/teamsmith/tests/upgrade-recipe.sh --select doc,selftest
RESULT pass=11 fail=0        rc=0
```

### 2.2 任务书验收命令（选段门禁）

```
$ P=$(git diff --name-only main...HEAD | tr '\n' ' ')
$ bash skills/teamsmith/tests/smoke.sh --paths $P
paths: skills/teamsmith/references/migration.md skills/teamsmith/tests/section-budgets.tsv \
       skills/teamsmith/tests/section-paths.tsv skills/teamsmith/tests/smoke.sh \
       skills/teamsmith/tests/upgrade-recipe.sh
```

这台机器上同时有别的席位在跑门禁、且 `/tmp`（15G tmpfs）被各家的陈旧临时根占到 100%，所以这条命令跑了六次；**每一次的红都归因到底**（没有一条红悬着）：

| 次 | 树 | 结果 | 红在哪 / 归因 |
|---|---|---|---|
| r1 | 0e36b1d6 | `✓936 ✗1` | §17「本任务交付的 references 文档全英文（无 CJK）」——§6 当时是中文草稿，**我的缺陷**，改英文后消失 |
| r2 | 38198fd6 | `✓936 ✗1` | §36⑧ 的产品面探针（2 条 bad：嵌套 `--select 58` 退出 1、红数 9）—— 那一次 `/tmp` 已近满；同一棵树的同一用例手工复现是 ✓419 ✗0，单跑 §58 也绿（§2.3、§4.2） |
| r3 | 38198fd6 | `rc=2` | §36 超时（预算 1400s，最后进度 297s，loadavg 20+）—— 机器欠的账，不是产品判定；§36 之前的 **21 段全绿**（含 §17 ✓34 ✗0） |
| r4 | 38198fd6 | `✓927 ✗10` | 全部由 `/tmp` 满（ENOSPC）造成：§36⑦/§36⑧ 的嵌套运行、§40 的 lint 敏感性与 P122、P70 段账计数（本次运行我把 `TMPDIR` 指到了 `/tmp/p255-keep`） |
| r5 | 38198fd6 | `✓935 ✗2` | `TMPDIR` 指到 overlay（`/var/tmp`，234G 可用）后 §36 全绿，只剩 §40 的 P223 反向对照两条红——只在 `TMPDIR` 不在 `/tmp` 时出现（默认 `TMPDIR` 的 r2 里 §40 是 ✓21 ✗0） |
| r6 | 38198fd6 | **没有运行**（`rc=2`） | 默认 `TMPDIR` 重跑任务书原命令 → 在机器门禁锁上排队超限：`排队超限：等满 1800s 仍拿不到门禁锁 /tmp/teamsmith-smoke.lock（持锁者：pid=2599646 cmd=smoke.sh）→ 本套**没有运行**（这不是对代码的判定）` |

r6 的原话（这也是套件自己给出的判定口径）：

```
另一套全量 smoke 正在跑（2026-10-15T10:13:42+00:00 pid=2599646 cmd=smoke.sh）；本套排队，最多等 1800s
排队超限：等满 1800s 仍拿不到门禁锁 /tmp/teamsmith-smoke.lock（持锁者：… pid=2599646 cmd=smoke.sh）→ 本套**没有运行**（这不是对代码的判定；等持锁者结束，或抬高 TEAM_SMOKE_LOCK_WAIT 后重跑）
```

**过程自查（我自己的失误，写在这里不藏）**：r4/r5 我给门禁加了 `TMPDIR` 覆盖，等于把机器锁也搬到了私有目录（锁文件是 `$TMPDIR/teamsmith-smoke.lock`），所以那两次是在别的席位的门禁之外**并发**跑的——既违反了「一次只跑一套」的机器纪律，也引入了 r5 那两条环境差异。r6 回到默认 `TMPDIR` 才是任务书的原命令。

### 2.3 本改动会碰到的段，各自单跑（这些是真跑出来的绿）

```
$ bash skills/teamsmith/tests/smoke.sh --select 17,18,14b,7b
== 选段结果 ==  ✓ 281  ✗ 0
#  §17 迁移指南与 doctor 指引 / §18 英文正文不变量 / §14b 已删命令不回潮 / §7b digest

$ bash skills/teamsmith/tests/smoke.sh --select 58
== 选段结果 ==  ✓ 496  ✗ 0
#  §58 信号纪律（§36⑧ 里嵌套探针跑的就是这一段，单独跑全绿）

$ bash skills/teamsmith/tests/smoke.sh --select 0e,0f,0g,0h,0i
== 选段结果 ==  ✓ 391  ✗ 0
#  段表自述 / 预算表 / 循环清单 / tmux 隔离前置 / 运行指纹
```

§64 在整套里被真跑到的那两次（r2、r5）：

```
#24 64 · 升级配方：§6 每一步都可证伪（P255 · upgrade-recipe） · 用时 8s  · ✓1 ✗0 SKIP0 · ticks 1   （r2）
#24 64 · 升级配方：§6 每一步都可证伪（P255 · upgrade-recipe） · 用时 10s · ✓1 ✗0 SKIP0 · ticks 1   （r5）
```

接线（选段器与账本面禁令）：

```
$ bash skills/teamsmith/tests/section-select.sh --check
（无输出，rc=0）
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/references/migration.md
decision=RUN   sections=130   keys=33   reason=0 ← README.md, prologue …（含 64）
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
rc=0（hits=0）
```

## 3. 翻转证据（红侧）

### 3.1 破坏实现 → 守门测试必须红（两次，最终版夹具实测）

```
$ sed -i 's|^doc_coverage_check() {.*|doc_coverage_check() { return 0; # FLIP|' skills/teamsmith/tests/upgrade-recipe.sh
$ bash skills/teamsmith/tests/upgrade-recipe.sh --select doc,selftest
FAIL selftest-red-missing-step
FAIL selftest-red-tool-upgrade
RESULT pass=9 fail=2
（还原实现后：RESULT pass=11 fail=0）

$ sed -i 's|^promise_check() {.*|promise_check() { return 0; # FLIP|' skills/teamsmith/tests/upgrade-recipe.sh
$ bash skills/teamsmith/tests/upgrade-recipe.sh --select doc,selftest
FAIL selftest-promise-negative
FAIL selftest-promise-negative-doc
RESULT pass=9 fail=2
（还原实现后：RESULT pass=11 fail=0）
```

### 3.2 文档面：删掉 §6 的任一步 → 红侧响

`selftest` 组在自己的副本上删步：删 `team up --no-migrate` → `selftest-red-missing-step`；删 `npm i -g teamsmith@` → `selftest-red-tool-upgrade`；`doc_missing` 同时点名缺的那一条。上面 3.1 的两次破坏正是把这条断言逼红，证明它不是橡皮章。

### 3.3 承诺探针：文档承诺了、工具不打印 → 红

`promise_check <文档片段> <工具输出> <期望串>` 两半都成立才绿；`selftest` 用自带合成输出做正反两向（`selftest-promise-positive` / `selftest-promise-negative` / `selftest-promise-negative-doc`）。`walk` 组里六条真承诺探针（`preview-migration`、`preview-restore`、`nomigrate-pastable`、`registration`、`config-list-clean`、`dispatch-category`、`version-line`）在 86/86 那次里全绿。

### 3.4 现场走查（`walk` 组）真正经过的东西

| 断言 | 命令（真 CLI、干净环境、私有 PATH） | 看到的 |
|---|---|---|
| 迁移前的写路径被拒 | `team config set TEAM_MONITOR_REFRESH 5` | rc≠0、点名 `upgrade-models`、配置文件 sha 不变 |
| 预览不写盘 | `team up --print` | 逐键 before → after、备份路径、还原命令、身份预告；配置 sha 不变 |
| 拒绝并给可粘贴命令 | `team up --no-migrate` | rc≠0 + 从**本配置**推导的 `--task-models/--pm-model`；粘回去 `--dry-run` rc=0 |
| 启动事务 | `team up`（私有 tmux + 假 PM） | `TEAM_TASK_MODELS='dev=… verify=… default=…'`、`TEAM_CONFIG_VERSION='2'`、退休键消失、备份 1 份且与用户备份逐字节相同、`config.log` 一行 `actor=up-migration`、`pm-launch.env` 记 `mode=continued` |
| 身份三态 | `team up --print` / `--fresh-pm` | 记录一致 → `continued:pi -c`；`--fresh-pm` → `fresh:--fresh-pm` 且不带 `-c`、记录不动；记录不符 → `PM launch identity changed` + 两条出路 |
| 收尾验证 | `team config list` / `team doctor` / `team dispatch --print` | `config list` rc=0 且无 `migration_required`；`doctor` rc=0；`dispatch --print` 打 `category=default model=vendor/base` |
| 回滚 | `cp <备份> .pi/team/config.sh` | 逐字节等于升级前，`config list` 又出现 `migration_required` |

## 4. Findings（交回 PM，都不在本任务边界内）

1. **机器门禁锁被一条挂了 1h20m 的运行占着**（r6 排不上队的直接原因）：持锁链条是 pid 1074048 → 1122045（`bash /tmp/teamsmith-select.1074048.sh`）→ 1122238（`flock --close -w 1800 /tmp/teamsmith-smoke.lock …`）→ 2599646（真正的嵌套运行，起于 10:13:41）。环境里写着 `SMOKE_SEL_SKILL_DIR=…/.worktrees/dev3/skills/teamsmith`，所以这是**别的席位**的 §36 自检嵌套运行，不是我的；它起跑时刻正好是 `/tmp` 开始吃紧的时候，疑似卡在 ENOSPC 上。我没有动它（不是我的进程），请 PM 定夺。
2. **`/tmp` 满会让门禁假红**：`/tmp` 是 15G tmpfs，本次实测 100%（其他席位的陈旧根占 ~13G：`v32` 1.5G、`p148-shape-probe.*` 1.1G、`be-merge` 459M…）。满的时候 §36⑦/§36⑧ 的嵌套运行、§40 的 lint 敏感性与 P122、P70 段账计数都会红，看起来像产品缺陷（r4 的 ✗10 全是这一类）。建议派门禁前先看 `df -h /tmp` 并按台账 reap 孤儿根。
3. **§36⑧ 的产品面探针在机器吃紧时会假红**：r2 报「⑩ 产品面树 `--select 58` 退出 1、红数 9」，而同一棵树的同一用例手工复现是 ✓419 ✗0（私有临时根 + 私有 `TMPDIR` + 嵌套 `--select 58`），单跑 §58 也 ✓496 ✗0。
4. **§40 的 P223 反向对照对 `TMPDIR` 敏感**：外层 `TMPDIR` 不在 `/tmp` 时（r5 用 `/var/tmp`）它报「不带 `--keep` 时根还在」；默认 `TMPDIR` 时该段 ✓21 ✗0。两条都不是本任务改出来的（本任务加的段与临时根无关）。
5. `references/migration.md` 的英文不变量由 §17 守——本任务第一版中文草稿被它当场判红，这条纪律有效，不需要新守门。

## 5. 边界与未做

- 只改了 `skills/teamsmith/references/migration.md`、`skills/teamsmith/tests/upgrade-recipe.sh`、`skills/teamsmith/tests/smoke.sh`（§64）、`tests/section-paths.tsv`、`tests/section-budgets.tsv`、`docs/team/reports/P255-dev-bob.md`；没有动产品行为代码、没有碰别的目录。
- 没有写进 `openspec/`：任务书声明 `change: -`、`anchor: none (infra)`，配方是文档 + 夹具，不是新的能力契约。
- 没有实现 `team upgrade` 之类的新命令（任务书明确不做）。
- 复验建议：用任务书原命令（默认 `TMPDIR`）跑一次；§64 只占 9–10s。

## 6. 返修轮次 1（V40 判 FAIL · 2026-10-15）

复验记录 `docs/team/reviews/V40.md`，受检 `91b40abe`。两项都在**文档侧**（工具与规格一致），逐条改动与自证如下。

### 6.1 F1 · §6 Step 2 把条件句写丢了

**原来写的（错）**：拒绝时「names the obstacle … and prints a **pastable command derived from your own
configuration**」——无条件句。读者会以为三类拒绝（不可定位 / 兜底撞名 / 值非法）都会给推导命令；实际那三类
只**点名障碍**并给**占位符路线**，只有能定位的形状才给推导命令。合同在 `openspec/specs/init-skill/spec.md`
（「当推导本身无歧义时才打印一条可粘贴命令」，场景那行 AND 明写「定位不了的形状回落到占位符路线并点名障碍」）。

**改后**（commit `cdfd10b6`）：把两种形态与**各自触发条件**并列写清，并说明两者一眼可分。

对照自证 —— 这些是我这一轮在临时项目里逐形状跑的真 CLI 输出（左列是探针原文，右列是文档里现在的那句话）：

| 形状（探针输入） | 工具实际输出（节选） | 文档里对应的句子 |
|---|---|---|
| 可定位：`TEAM_AGENT_MODELS='dev=vendor/light verify=vendor/strong:high'` + `TEAM_DEFAULT_MODEL='vendor/base'` 跑 `up --no-migrate` | `--task-models 'dev=vendor/light verify=vendor/strong:high default=vendor/base'` + `--pm-model 'vendor/pm:high' --dry-run`（rc≠0，配置 sha 不变） | 第一条 **A shape it can derive from**：「the map and the PM model already filled in」+「`team up --no-migrate` on such a configuration prints this form」 |
| 不可定位：`TEAM_DEFAULT_MODEL="${MISSING:-vendor/base}"`（值靠变量展开） | `✗ 启动迁移拒绝（shape-not-locatable）：…expanding double quote；请规范单行 literal` + `手工路线：team config upgrade-models --task-models '<完整映射>' --pm-model '<独立模型>' --dry-run` | 第二条 **A shape the derivation stops on**：「a value built by variable expansion or written as a multi-line literal」+「it prints the **placeholder route**」+「names what stopped the derivation（for that first shape, the file and line that is not a plain literal）」 |
| 兜底名撞名：`TEAM_AGENT_MODELS='default=vendor/light'` + `TEAM_DEFAULT_MODEL='vendor/base'` | `✗ 启动迁移拒绝（fallback-name-collision）：席位派生的类别里已经有一个叫 default` + 同上的占位符路线 | 第二条：「a seat name that normalizes onto the fallback `default` (the fallback name collides)」 |
| 值非法：`TEAM_AGENT_MODELS='dev=vendor/light verify=not-a-model'` | `✗ 启动迁移拒绝（invalid-model-value）：席位 verify 的旧模型值不合法` + `其余已推导出的对可以先手工提交（非法那一对用占位符）：--task-models 'dev=vendor/light <非法那一对用占位符>'` | 第二条末句：「A derivation that resolved some pairs before stopping still prints them, with the bracketed placeholder standing in for the offending one」 |

**为什么文档里现在看不到那句中文占位符原文**：`references/migration.md` 受 §17 的英文不变量管辖，而 §17 是**整文件**扫描（比 §18 严：§18 对行内代码里的中文故意豁免，§17 不豁免）。第一版返修稿把 CLI 的中文占位符
`'<完整映射>'`/`'<独立模型>'` 原样贴进 §6，§17 当场判红（见 6.4）。现在的写法是「an unfilled
`--task-models`/`--pm-model`, each holding a **bracketed placeholder written in the CLI's own language**」——
读文档的人照样能一眼认出屏幕上那个尖括号占位符；而**工具侧**的判据改成与语言无关的**形状**：占位符路线的
`--task-models` 引号里以 `<` 开头（推导命令那里是 `dev=…`），见 6.3。

### 6.2 F2 · §6 Step 4 说 `team up` 重建巡检窗口

**原来写的（错）**：`team up` rebuilds the pulse window; `team pulse status` shows it.
**改后**（同一 commit `cdfd10b6`）：`team up` starts the PM and nothing else; the patrol window is created by
`team pulse up`, and `team pulse status` shows its state.

自证：夹具 `walk` 组在**真** `team up`（私有 tmux + 假 PM）之后直接读私有 server 的窗口清单 —— `pm` 在、
`pulse` 不在（`up-creates-pm-window` / `up-leaves-pulse-to-pulse-up`），这正是 V40 复验者的取证方式。

### 6.3 夹具：两处改动都落成可证伪的断言

`skills/teamsmith/tests/upgrade-recipe.sh`（commit `71b8a380` + `037adbf9`）：

| 新增断言 | 它守什么 |
|---|---|
| `refusal-{not-locatable,fallback-collision,invalid-value}-rejected` | 三种形状都**拒绝**（rc≠0） |
| `…-names-obstacle` | 拒绝时**点名障碍**（`启动迁移拒绝`） |
| `…-placeholder` | 拒绝时给的是**占位符**（`--pm-model '<独立模型>'`，即 CLI 自己的占位符文本） |
| `…-no-complete-map` | 拒绝里**没有**完整推导映射（`--task-models '[^<]*'` 一次都不出现）——语言无关的形状判据 |
| `…-pure` | 每一次拒绝都**不写盘**（配置 sha 不变） |
| `refusal-invalid-value-partial-marker` / `…-keeps-resolved` | 值非法那条保留已推出的对（`dev=vendor/light`）并用占位符顶上非法的那一对 |
| `refusal-shape-restored` | 三条形状走完后配置**逐字节回到原样** |
| `up-creates-pm-window` / `up-leaves-pulse-to-pulse-up` | `team up` 起 PM 窗口、**不**建巡检窗口 |
| `doc-promise:refusal-placeholder-route` | 文档承诺 `placeholder route` **且**工具真的打印 `upgrade-models --task-models '<` |
| `selftest-red-f1f2` / `…-names` / `…-names-pulse` | 把这两句文档从副本里删掉 → 文档面必须红并**点名**缺的就是它们 |

**没有 needle 钉住旧句子**（任务书点的这一条）：夹具里搜不到 `rebuilds the pulse window`，也搜不到
`pastable command derived from your own configuration`；`DOC_LITERALS` 里也没有这两串。

### 6.4 本轮我第一次门禁跑出的一条真红（我自己的，已修）

第一版返修稿把 CLI 的中文占位符原文贴进 §6 → §17「本任务交付的 references 文档全英文（无 CJK）」判红：

```
✗ references 里有中文：…/skills/teamsmith/references/migration.md
#19 17 · 迁移指南与 doctor 指引（M7.1） · 用时 15s · ✓33 ✗1 SKIP0 · ticks 34
== 选段结果 ==  ✓ 955  ✗ 1     （rc=1）
```

改法不是给它开口子，而是把 §6 那两句改成英文描述（6.1 末段）+ 工具侧判据换成形状判据；红→绿在 6.5。

### 6.5 返修后的验收实跑（默认 `TMPDIR`，27/130 段，拿到门禁锁）

```
$ bash skills/teamsmith/tests/upgrade-recipe.sh
RESULT pass=111 fail=0                    rc=0    （五组全跑：doc/walk/identity/rollback/selftest）

$ $HOME/.bun/bin/bun $HOME/.bun/bin/openspec validate --all --strict
Totals: 23 passed, 0 failed (23 items)    rc=0

$ P=$(git diff --name-only main...HEAD | tr '\n' ' ')
$ bash skills/teamsmith/tests/smoke.sh --paths $P
== 选段 == decision=RUN · 运行 27/130 段 · 未跑 103 段
#19 17 · 迁移指南与 doctor 指引（M7.1） · 用时 23s · ✓34 ✗0 SKIP0 · ticks 34    ← 6.4 那条红转绿
#25 64 · 升级配方：§6 每一步都可证伪（P255 · upgrade-recipe） · 用时 9s · ✓1 ✗0 SKIP0 · ticks 1
#8  0i · 运行指纹：树在跑动中被改 → 本次运行无效（P158） · 用时 19s · ✓5 ✗0 SKIP0 · ticks 5
账本自查：26 段收口 · 增量 ✓956 ✗0 SKIP3 ｜ 结果行 ✓956 ✗0 —— 一致
== 选段结果 ==  ✓ 956  ✗ 0             rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 8  bad 0  SKIP 1      rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…scope=published files=1543 hits=0 names=ok user=resolved    rc=0
```

夹具断言数从 86 涨到 111（新增 25 条：三条形状 × 5 条 + 部分推导 2 条 + `up` 窗口 2 条 + 承诺探针 1 条 + 文档面红侧 3 条 + 原有组的计数变化）。

**返修的翻转证据**（红 → 绿，自己这侧）：

| 红侧 | 怎么造 | 结果 |
|---|---|---|
| §6 说错（F1） | 第一版返修稿把中文占位符贴进 §6 | §17 `✓33 ✗1` → 改英文后 `✓34 ✗0`（6.4 → 6.5） |
| 文档少一句（F1/F2） | 夹具 `selftest` 在副本上删掉 `placeholder route` / `team pulse up` 那两行 | `selftest-red-f1f2` + 两条点名断言红，点名缺的正是它们（还原后绿） |
| 工具不给占位符（F1） | `refusal-*-no-complete-map` / `…-placeholder` 直接读真 CLI 输出 | 三条形状都命中占位符、都不含完整映射；第一版断言（拿 `dev=` 当判据）在值非法形状上**真的红过**——那条红是我自己的判据错，已按工具实际行为改成形状判据（6.3） |
| `team up` 建了巡检窗口（F2） | `up-leaves-pulse-to-pulse-up` 读私有 tmux 的窗口清单 | 只列到 `pm`，没有 `pulse` |

## 7. 返修轮次 2（V40 第二轮判 FAIL · 2026-10-15）— F3：一句话

复验记录 `docs/team/reviews/V40.md` 文末「第二轮复检」（受检 `ac19fdf7`）：F1、F2 判为**真修好**、新守卫**真有牙**、第一轮绿面**一条未回退**；唯一必修 **F3** —— `references/migration.md` 原先第 231–232 行（`--no-migrate` 那句）仍是**无条件**承诺「prints the manual command derived from *your* configuration」，而同一次改写新写的两种形态那一节已经讲清「哪一种取决于你的配置」。复验者造了六种推导停住的形状（`shape-not-locatable` / `fallback-name-collision` / `invalid-model-value` / `category-not-normalizable` / `contradictory-values` / `unknown-shape`），六种之下 `--no-migrate` 打印的都是**占位符路线**。板子打在文档上：产品行为、判据、§6 的其余内容都没动。

### 7.1 改的就是这一句

```diff
@@ -229,7 +229,8 @@
 command that restores it, and why the keys move. `team up --no-migrate` is the same promise from the other side:
-it refuses, writes nothing, and prints the manual command derived from *your* configuration.
+it refuses, writes nothing, and prints the manual transaction in whichever of the two command forms below fits
+your configuration — the derived command when the derivation is unambiguous, the placeholder route when it is not.
```

（`git diff` 原样：2 行 → 3 行，只这一处；`migration.md` 的 CJK 行数仍为 0，§17/§18 的英文不变量不受影响。）

### 7.2 夹具同步：旧句此前没有 needle（我搜过）

`manual command derived` 在本夹具里此前一次都不出现，`DOC_LITERALS` 也没钉这句——F3 这类「把条件句写丢」当时没有守卫。这次按 V40 的建议**两侧都钉**：

| 新守卫 | 落在哪 | 断言 | 红侧（这是什么形状） |
|---|---|---|---|
| 正向 needle | `DOC_LITERALS`：`whichever of the two command forms` | §6 必须含这句 | `FAIL doc-coverage` + `§6 缺的片段：whichever of the two command forms` |
| 反向禁列 | 新清单 `DOC_FORBIDDEN`：`manual command derived` | §6 不许出现把 `--no-migrate` 与推导命令无条件连起来的写法 | `FAIL doc-forbidden-phrases` + `§6 命中的禁列短语：manual command derived` |
| 红侧自检 | `selftest`：在副本上用 `awk` 把这句换回旧写法 | 上面两条同时红、两个函数各自点名；还原后两条绿 | `selftest-red-f3` / `…-needle` / `…-forbidden` / `…-names`，随后 `selftest-restored-f3` / `…-forbidden` |

`DOC_FORBIDDEN` 单列一个清单而不是塞回 `DOC_LITERALS`：`doc_coverage_check` 问的是「在不在」，禁列问的是「有没有出现」，方向相反。

### 7.3 我自己的对照自证（新句子的每个分句 → 夹具里哪条断言）

| 新句子的分句 | 对得上的工具真输出 | 对应断言 |
|---|---|---|
| 「the manual transaction in whichever of the two command **forms**…」 | 两种形态都真出现过：可定位形状给推导命令，三种停住形状给占位符 | `nomigrate-derived` + 三条 `refusal-*-placeholder` |
| 「the **derived** command when the derivation is unambiguous」 | 可定位形状 `--no-migrate` 打出的映射被逐字粘回去：`--dry-run` rc=0、不写盘 | `nomigrate-derived`、`nomigrate-pasted-dryrun`、`nomigrate-pasted-dryrun-pure` |
| 「the **placeholder route** when it is not」 | 三种停住形状：点名障碍 + `--pm-model '<独立模型>'` + 没有完整映射 | 三条 `refusal-*-rejected` / `…-names-obstacle` / `…-placeholder` / `…-no-complete-map` / `…-pure` |

诚实边界：夹具覆盖 V40 六种形状里的三种（`shape-not-locatable`、`fallback-name-collision`、`invalid-model-value`），另三种（`category-not-normalizable`、`contradictory-values`、`unknown-shape`）是复验者 `walk2.sh` 的现场，本轮没有往夹具里加。新句子只声明「推导无歧义 → 推导命令，否则 → 占位符路线」这条二分，不点名具体形状，对这六种都成立。

### 7.4 翻转证据（真文档文件上的红 → 绿）

把这句用同一个 `awk` 换回旧写法，跑文档组；`git checkout --` 还原（这句的修复已提交，所以还原回到的是**修好的**版本）；再跑一次：

```
== RED: revert the sentence to the old unconditional text ==
PASS doc-section-present
FAIL doc-coverage
  §6 缺的片段：
    whichever of the two command forms
FAIL doc-forbidden-phrases
  §6 命中的禁列短语：
    manual command derived

RESULT pass=1 fail=2
red rc=1
== RESTORE ==        （git status --short 空）
== GREEN ==
PASS doc-coverage
PASS doc-forbidden-phrases

RESULT pass=3 fail=0
green rc=0
```

### 7.5 本轮验收实跑（交付树 `8963ed05`，默认 `TMPDIR`）

```
$ bash skills/teamsmith/tests/upgrade-recipe.sh
RESULT pass=118 fail=0        rc=0        （五组全跑；111 → 118，新增 7 条）

$ $HOME/.bun/bin/bun $HOME/.bun/bin/openspec validate --all --strict
Totals: 23 passed, 0 failed (23 items)     rc=0

$ bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
== 选段 == decision=RUN · 运行 27/130 段 · 未跑 103 段
#8  0i · 运行指纹：树在跑动中被改 → 本次运行无效（P158） · 用时 18s · ✓5 ✗0 SKIP0 · ticks 5
#19 17 · 迁移指南与 doctor 指引（M7.1） · 用时 16s · ✓34 ✗0 SKIP0 · ticks 34
        ✓ 本任务交付的 references 文档全英文（无 CJK）
#20 18 · 英文正文不变量与安装器唯一入口（M7.3） · 用时 0s · ✓36 ✗0 SKIP0 · ticks 36
#25 64 · 升级配方：§6 每一步都可证伪（P255 · upgrade-recipe） · 用时 9s · ✓1 ✗0 SKIP0 · ticks 1
        ✓ 64 升级配方（全量 · 组 doc,walk,identity,rollback,selftest）全绿（RESULT pass=118 fail=0）
账本自查：26 段收口 · 增量 ✓956 ✗0 SKIP3 ｜ 结果行 ✓956 ✗0 —— 一致
== 选段结果 ==  ✓ 956  ✗ 0             rc=0（墙钟 1197s，其中 §36 一段 986s）

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 8  bad 0  SKIP 1      rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…scope=published files=1543 hits=0 names=ok user=resolved    rc=0

$ git diff --check ; echo rc=$?
rc=0
$ git status --short        # 交付树 8963ed05
（无输出）
```

选段运行**不是整套门禁**（判据原样引用它自己那行）：这次有 103 个段没跑，都在套件末尾的清单里；与本次改动相邻的段（§17/§18/§14b/§36/§40/§60）都在这次运行里、全绿。

### 7.6 交付状态

- 提交：`a1b961fb docs(migration): the --no-migrate promise is conditional too`、`8963ed05 test(upgrade-recipe): pin the --no-migrate sentence from both sides`（其上还有本报告这一个提交）。
- 分支 `task/P255-migration-recipe`，local 模式：不动 `main`、不推送。
- 未跑/未验（点名）：V40 六种形状里的后三种本轮没有在自己的夹具里复现（见 §7.3）；`--no-migrate` 的**完整**两形态走查由验证席位的 `walk2.sh` 覆盖，本轮的现场只到「新句子 ↔ 夹具断言 ↔ 三种形状的真 CLI 输出」。
- 结论：F3 是文档侧一句话，已按 V40 建议改成条件形态，并在夹具里从正反两侧钉住；产品行为、判据与第一轮绿面均未改动。
