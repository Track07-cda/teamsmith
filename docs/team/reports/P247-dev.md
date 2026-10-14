# P247 · 发布检查跟上 routing 之后的形状：tag 选法 + init 路线参数

agent: dev   status: DONE   time: 2026-10-14T01:12Z
branch: `task/P247-release-check-stale`   PR/MR: -（local 模式：不 push、不合并，分支留本地给 PM 复验）

## 结论

- 两条缺陷都复现、都修好。同一个工具在同一个树上：修前 `通过 21 · 失败 4 · 跳过 0` —— 四条里**没有一条**是树的问题；
  修后 `通过 29 · 失败 1 · 跳过 0`，唯一那条红是 `HEAD 领先可达的最新 tag v0.1.2 79 个提交`（发布前的正常形态），
  另加一条不参与判定的旧 tag 异常提示。不带名单时对应 `通过 19 · 失败 4 · 跳过 2` → `通过 27 · 失败 1 · 跳过 2`。
- 缺陷一（三条 tag 恒假）：仓里 32 个 tag 中 29 个是改写前的旧 tag（不在 HEAD 历史上，最近的是 v1.42.0）。
  `git tag --sort=-v:refname | head -1` 按版本序取全量 tag，`1.42.0 > 0.1.2`，于是「最新 tag」永远是旧 tag。
  改为只从 `git tag --merged HEAD --sort=-v:refname` 里取（annotated tag 由 `--merged` 剥到 commit 再判可达）；
  不可达的 tag 另发一条 `⚠` 提示：计数、点名前五个（版本序）、附一句「不要 `git push --tags`」——
  不是红，也不进 通过/失败/跳过 计数。
- 缺陷二（安装路线第 3 条恒红）：routing 之后 `init` 必带 `--task-models`/`--pm-model`，无参数按设计 rc=4 拒绝。
  改为用发布包里的 team 传参，并加三条契约断言：两个键落盘且等于传入值、契约里没有退休键。
- `--self-test`：A 段四条变异一字未动，仍是 4/4；新增 B 段 tag 判据红侧 4/4 —— 不可达的高版本 tag 不带偏判据、
  第 2 节零红、HEAD 与可达 tag 错位一个提交时恰好红那一条。自测 rc=0。
- 未做/不动的：没有删那 29 个旧 tag（任务书明确留给 PM/用户，工具只提示）；没改 `install.sh`、
  `publish-public.sh`、`.gitignore`、`RELEASE-PUBLIC.md`、任务书。
- 环境说明：本机 `openspec` 不在登录 bash 的 PATH 上（可执行文件在 `~/.bun/bin/openspec`），用它跑
  `validate --all --strict` 是 16/16、rc=0。证据里出现的绝对家目录路径按账本禁令一律换成
  `<worktree>` / `<main-repo>` 占位符；原始日志在未进仓的证据包里。

## Deliverables

| Path | What |
|---|---|
| `docs/team/tools/release-check.sh` | 三处改动：第 2 节 tag 选择与旧 tag 异常提示；第 5 节 init 传参与三条契约断言；`--self-test` 新增 B 段 |
| `docs/team/reports/P247-dev.md` | 本报告 |
| `docs/team/reports/P247-dev/**` | 复跑证据包（`00`–`13` 共 18 个日志；证据层被 `.gitignore` 挡在树外，不进仓） |

三个提交（交付 tip `ec5baa1a`）：`c2cf33e6` tag 选择、`81e7d388` init 传参与断言、`ec5baa1a` 自测 B 段。

## 复现（修前）

### 一、三条 tag 失败在改写后的仓里恒假

旧工具（`0cf6dc5c:docs/team/tools/release-check.sh`）在本树上，带主检出的名单文件：

```
$ bash <旧工具> --root <worktree> --names-file <main-repo>/.pi/team/forbidden-names.txt
== 2. 最新 tag 与 HEAD ==
  ✗ 最新 tag（v1.42.0）≠ package.json（0.1.2）—— 版本号与标签指的不是一回事
  ✗ tag v1.42.0 不是 HEAD 的祖先（版本号指向别的历史）
  ✗ HEAD 领先最新 tag v1.42.0 671 个提交 —— 发布前先做版本落点 + 打 tag（清单见 docs/team/RELEASE-PUBLIC.md）

== 结果 ==
  通过 21 · 失败 4 · 跳过 0
✗ 发布前检查未通过（4 条）        # rc=1
```

`git tag --merged HEAD | wc -l` = 3（`v0.1.0 v0.1.1 v0.1.2`，都是 annotated），`git tag | wc -l` = 32 ——
差的 29 个就是改写前旧历史留下来的 tag，`merge-base --is-ancestor` 对它们全为假。第 4 条红是安装路线（见下）。

### 二、安装路线第 3 条：`init` 无参数按设计拒绝

工具原来跑 `"$INST/prefix/bin/team" init`（没有参数）。拿发布包里的 team 在临时项目里直接试：

| 输入 | rc | 首行输出 |
|---|---|---|
| 无参数 | 4 | `✗ init: 缺少 --task-models（项目类别映射是必填输入；没有默认模型可猜）` |
| `--pm-model noslash` | 4 | `✗ init: --pm-model 不合法：provider 缺失：需要 provider/model 形状（没有 /）` |
| `--pm-model nope/nope:high` | 0 | 形状合法但**不存在**的模型照写进契约（`TEAM_PM_MODEL='nope/nope:high'`） |

## 改动（都在 `docs/team/tools/release-check.sh`）

- **第 2 节**：`TAGREF` 改成 `git tag --merged HEAD --sort=-v:refname | head -1`（只认可达的 tag，annotated
  由 `--merged` 剥 commit 再判可达）；另外逐 tag 用 `merge-base --is-ancestor "$t^{commit}" HEAD` 数不可达的，
  有就打印 `⚠ 旧 tag 异常：N 个 …（前几个：…）` 与 `不要 git push --tags` 一行。可达 tag 一个都没有时
  明确报红「仓库里的 N 个 tag 没有一个是 HEAD 的祖先」。仍保留原有的三条判定与文案，只换掉选择面。
- **第 5 节**：`team init` 加 `--task-models 'infra=opencode-go/deepseek-v4.1-flash'` 与
  `--pm-model 'opencode-go/deepseek-v4.1-flash'`；新增三条断言 —— `TEAM_TASK_MODELS` 落盘且等于传入映射、
  `TEAM_PM_MODEL` 落盘且等于传入模型、契约里没有退休键 `TEAM_DEFAULT_MODEL`/`TEAM_AGENT_MODELS`。
  调用前 `env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION`（与原有的项目内 `team help`
  同一处理），保证这条路线只写临时项目、不碰真实项目。
- **`--self-test` 新增 B 段**：从 HEAD 导出树造一个真 git 仓，HEAD 打 `v<package.json 版本>`，另造一个
  parentless commit 打版本更高的 v9.9.9（改写后尘埃的形状）。B1 断言仍选可达的 v0.1.2、第 2 节零红、
  异常提示点名 v9.9.9 且 rc=0；B2 让 HEAD 错位一个提交，断言恰好红「HEAD 领先最新 tag … 1 个提交」。
  A 段四条变异一字未动。

## Verification evidence（本 tip 上真实跑的输出）

（本节各命令是在**代码 tip `ec5baa1a`** 上跑的；它之后的提交只改账本文档，所以复跑时
`HEAD 领先最新 tag…` 的计数 = 这里的数字 + 代码 tip 之后的提交数，其余输出不变。）

任务书的验收命令：

```
$ bash docs/team/tools/release-check.sh                     # rc=1
== 2. 最新 tag 与 HEAD ==
  ⚠ 旧 tag 异常：29 个 tag 不在 HEAD 的历史上（前几个：v1.42.0 v1.41.0 v1.40.0 v1.39.0 v1.38.0 …）
  ⚠   它们指向改写前的旧历史：不要 git push --tags（会把旧历史推进公开仓）；删不删由发布者决定
  ✓ 最新 tag v0.1.2 = package.json（0.1.2）
  ✓ tag v0.1.2 是 HEAD 的祖先（历史没被改写错位）
  ✗ HEAD 领先最新 tag v0.1.2 79 个提交 —— 发布前先做版本落点 + 打 tag（清单见 docs/team/RELEASE-PUBLIC.md）
...
== 5. 三条安装路线 ==
  ✓ npm pack 产出 teamsmith-0.1.2.tgz
  ✓ 全局安装到临时 prefix 成功
  ✓ 'team help' 退出 0
  ✓ 包内带 skills/
  ✓ install.sh：teamsmith 就位且与源树逐字节相同
  ✓ install.sh：teamsmith-init 就位且与源树逐字节相同
  ✓ team init：teamsmith 就位（软链）且与源树逐字节相同
  ✓ team init：teamsmith-init 就位（软链）且与源树逐字节相同
  ✓ 项目内 'team help' 退出 0
  ✓ team init：TEAM_TASK_MODELS 落盘且等于传入映射
  ✓ team init：TEAM_PM_MODEL 落盘且等于传入模型
  ✓ team init：契约用的是 TEAM_TASK_MODELS/TEAM_PM_MODEL，不是退休键
== 结果 ==
  通过 27 · 失败 1 · 跳过 2
✗ 发布前检查未通过（1 条）
```

```
$ bash docs/team/tools/release-check.sh --self-test          # rc=0
== 自测：四条变异必须被抓住 ==
  ✓ ①内网地址：被抓住（rc=1，命中「[net]」）
  ✓ ②编译缓存：被抓住（rc=1，命中「[file]」）
  ✓ ③装错skill：被抓住（rc=1，命中「install.sh」）
  ✓ ④版本错配：被抓住（rc=1，命中「不一致」）

== 自测 B：tag 判据（只认 HEAD 可达的最新 tag）==
  ✓ B1：可达的最新 tag v0.1.2 被选中（rc=0；不可达的 v9.9.9 没把判据带偏）
  ✓ B1：第 2 节零红（不可达 tag 不产生假红）
  ✓ B1：异常提示点名 v9.9.9（计数 1），且不改判定
  ✓ B2：HEAD 与可达最新 tag 错位 1 个提交 → 恰好红这一条（rc=1）

== 自测结果 ==
  A 四条变异  抓住 4 · 漏掉 0
  B tag 判据  4/4
✓ 自测通过：四条变异全部被抓住（tag 判据红侧 4/4）
```

```
$ git diff --check && git status --short                     # 无输出
```

与 PM 基线（`通过 21 · 失败 4`）对齐的带名单对照：

```
$ bash docs/team/tools/release-check.sh --names-file <main-repo>/.pi/team/forbidden-names.txt
== 结果 ==
  通过 29 · 失败 1 · 跳过 0
```

选段门禁（本任务只动 `docs/team/tools/release-check.sh`，`section-select.sh --paths` 选中的是 0/0b/0c/0d/60）：

```
$ bash skills/teamsmith/tests/section-select.sh --paths docs/team/tools/release-check.sh
decision=RUN · sections=127 · keys=5（0, 0b, 0c, 0d, 60）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 0,0b,0c,0d,60
#5 60 · 账本禁令 · ✓18 ✗0 SKIP1
== 选段结果 ==  ✓ 39  ✗ 0          # rc=0
$ ~/.bun/bin/openspec validate --all --strict
Totals: 16 passed, 0 failed (16 items)   # rc=0
```

账本禁令（模板要求的那条固定验收行，在本工作树、本分支的树上跑）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=… scope=published files=1434 hits=0 names=ok user=resolved
$ echo $?
0
```

`--remote`（可选，顺带跑了一次，`--skip-install`）：public 远端 main 落后本地 main 78 个提交 → 那一节红。
这是既有仓库状态（发布清单要求推之前先看），不是本任务引入的。

**没跑/没验证的（说清楚）**：
- 选段之外的 122 个门禁段没跑；本任务只动了一个工具文件，选段结果就是上面那 5 段。
- `release-check.sh --with-gates`（它内部的 FAST 门禁选项）没跑 —— 不是本任务的验收命令，FAST 全套列入合并门禁。
- 29 个旧 tag 的删除/保留没有动（任务书要求不删，只提示）。

## Flip evidence（翻转证据）

### 一、同一棵树：red before → green after

| 在交付 tip 上跑的 | 版本 | 结果 | 红的是哪几条 |
|---|---|---|---|
| 旧工具（`0cf6dc5c` 版）+ 名单 | 修前 | `通过 21 · 失败 4 · 跳过 0`，rc=1 | 三条 tag 假红 + 安装路线 |
| 新工具 + 名单 | 修后 | `通过 29 · 失败 1 · 跳过 0`，rc=1 | 只剩 `HEAD 领先可达的最新 tag v0.1.2 79 个提交`（真信号） |
| 旧工具，不带名单 | 修前 | `通过 19 · 失败 4 · 跳过 2` | 同上 |
| 新工具，不带名单 | 修后 | `通过 27 · 失败 1 · 跳过 2` | 同上 |

### 二、scratch 仓：只注入「不可达的高版本 tag」这一个缺陷

从 HEAD 导出一棵树、`git init` 成真仓、HEAD 打 v0.1.2，再在 parentless commit 上打 v9.9.9：

| 工具 | 结果 | 第 2 节 |
|---|---|---|
| 旧工具 | `通过 13 · 失败 3 · 跳过 3`，rc=1 | 三条 tag 全红（就是这棵树上唯一的缺陷） |
| 新工具 | `通过 16 · 失败 0 · 跳过 3`，rc=0 | 三条全绿，另有一条 `⚠ 旧 tag 异常：1 个 …（前几个：v9.9.9）` |
| 新工具，再让 HEAD 错位一个空提交 | `通过 15 · 失败 1 · 跳过 3`，rc=1 | 恰好红 `✗ HEAD 领先最新 tag v0.1.2 1 个提交` |

### 三、破坏实现 → 守卫必须失败 → 还原（tag 判据）

把选择面退回缺陷写法（`tag --merged HEAD --sort=…` → `tag --sort=…`）后跑 `--self-test`：

```
== 自测 B：tag 判据（只认 HEAD 可达的最新 tag）==
  ✗ B1：最新 tag 判据仍被不可达 tag 带偏
        ✗ 最新 tag（v9.9.9）≠ package.json（0.1.2）…
        ✗ tag v9.9.9 不是 HEAD 的祖先…
        ✗ HEAD 领先最新 tag v9.9.9 1 个提交…
  ✗ B1：第 2 节有 3 条红
  ✗ B2：错位一提交没有恰好红这一条（第 2 节红 3 条，rc=1）
== 自测结果 ==
  A 四条变异  抓住 4 · 漏掉 0
  B tag 判据  1/4
✗ 自测失败：有检查拦不住变异        # rc=3
```

还原后 `cmp` 与冻结副本逐字节相同、`git status --short` 为空、`--self-test` 回到 rc=0 且 A 4/4 + B 4/4。

### 四、安装路线的翻转（论证的"红侧"就是修前现场）

修前第 5 节最后一行是 `✗ team init 失败`（工具不带参数调 init，本任务书的对照组）；修后是 12 条 ✓，
含新增的三条契约断言。手动对照（同一发布包、同一临时项目形状）：无参数 rc=4、`noslash` rc=4、
形状合法但不存在的 `nope/nope:high` rc=0。

## 关于 `--pm-model` 形状校验的现状（任务书点名要如实记）

- `release-check.sh` **不做**模型形状或存在性校验：它把两个常量原样透传给发布包的 `team init`，判定就是
  「这条路线 rc 是否为 0」。
- 传不合法形状（如 `noslash`）→ `init` 自己 rc=4 拒绝 → 该路线变红（间接兜住）。
- 传形状合法但不存在的模型（如 `nope/nope:high`）→ `init` 照写进契约、rc=0 → 该路线绿。本仓没有模型注册表
  可查，这是现状；要不要在工具侧加形状校验，任务书不要求，留给 PM/用户。

## Decisions and deviations

- 提示行前缀用 `⚠`（新加的 `note()`），不用 `!` —— `!` 在工具里是「跳过」并计入 SKIP；这样"不是红、也不改判定"
  这条要求字面成立（结果行仍是 通过/失败/跳过 三个数）。
- 不可达 tag 的「前几个」按**版本序**取（从 v1.42.0 往下），比字母序更贴近"最近的那个旧 tag"。
- 自测 A 段的输出保持 `抓住 4 · 漏掉 0` 原样，B 段另计 `4/4`；`--self-test` 的退出码语义不变（有漏才 rc=3）。
- init 调用顺带清掉环境 `TEAM_*`（原来只有项目内 `team help` 这么做）—— 避免在团队会话里跑检查时把初始化
  写到真实项目上。
- 没动任务书的禁区文件；没 push、没建/删 tag。

## Suggested next steps

- PM 复验：任务书那三条命令；若要与基线计数对齐，加
  `--names-file <main-repo>/.pi/team/forbidden-names.txt`（就是 21 → 29 的对照）。
- **29 个旧 tag 的处置留给用户**：工具现在会提示，但删不删是仓库状态决定，本任务不删。若要清，建议先导出
  一份「tag → commit + 日期」清单再动手（不可逆，且这些 tag 只在本仓，公开仓并无它们）。
- 若发布清单与工具的提示措辞要统一，可在 `docs/team/RELEASE-PUBLIC.md` 里引用这条提示；本轮按边界没有改它。
