# M38 · public-release-prep：打包与发布准备（准备工作，**不发布**）

agent: dev-bob   status: DONE（待 PM 复验）   time: 2026-09-19T09:40Z
branch: `task/M38-public-release-prep`（local 模式：不 push，分支留在 `.worktrees/dev-bob`）
change: -（无规格变更；本任务只加打包/发布准备文件，不动 `skills/**` 行为代码）

用户已明确：**只做准备，暂不公开发布** —— 仓库可见性、npm 发布、tag push 一律没动（见「Decisions and deviations」第 6 条）。

## Deliverables

| Path | What |
|---|---|
| `package.json`（新增） | `pi` 清单：`pi.skills: ["./skills"]`（**刻意不写** `pi.extensions`）、`name: teamsmith`、`version: 1.40.0`（= skill 版本）、`license: MIT`、`repository`、`keywords` 含 `pi-package`、`files` 白名单（`skills/` + `install.sh`）、`scripts.test/test:full/gates` |
| `README.md`（改） | 新增/重写三段：`Install`（pi 包三条路径 + checkout 安装 + `install.sh`）、`Requirements`（pi 版本下限实测、bash/git/tmux、node/bun、magic-context、OpenSpec、podman 仅测试）、`Quickstart`（teamsmith-init → bootstrap → 第一个任务 → 独立复验）；另加「清单声明了什么、刻意不声明什么」与「本仓库 `docs/team/` 是它自己的真实账本」两句；顺手修掉与新版 Requirements 自相矛盾的旧句「no jq/python/**node**」 |
| `.github/workflows/gates.yml`（新增） | `push: main` + `workflow_dispatch`，ubuntu-latest，装 tmux/perl + bun + OpenSpec CLI，跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`（**未在真实 CI 上跑过**，见 §5） |
| `docs/team/PUBLISH.md`（新增） | 发布清单：改可见性 / 推 tag / 可选 npm publish / pi 画廊字段 / 公告，每条写「谁做 · 在哪做 · 怎么验证 · 怎么回滚」，外加「现已就绪」表与「等用户拍板」两项 |
| `docs/team/reports/M38-dev-bob-probe-pi-manifest.mjs`（新增） | 可复现证据脚本：用 pi 自己的 `DefaultResourceLoader` 回答「这个项目会加载到哪些 skill」 |
| `docs/team/reports/M38-dev-bob-check-workflow.mjs`（新增） | 可复现证据脚本：workflow 的 YAML 契约 + 每个 `run:` 块 `bash -n` |

提交序列：`64f1de4`（package.json）→ `4c0a479`（README）→ `1d58c26`（workflow）→ `e104854`（PUBLISH.md）→ 本报告。
`skills/**` 一个字节没动（brief 的 Boundaries 明令禁止；「Suggested next steps」里有一条给 PM 的建议，需要 PM 自己决定要不要落到 `tests/**`）。

## §1 必做验收 ①：本地 path 安装（证明 `pi` 清单真能被发现）

brief 的命令按「开发者本地安装」场景跑（先把分支 clone 成一个叫 `teamsmith` 的目录，再装它）—— 这样
`pi list` 列出的源里才带包名，能照 brief 的 `grep -i teamsmith` 验证。**为什么不用 brief 里那个绝对路径**：
那指向**主 worktree**，而本任务的分支还没合并，主 worktree 上**还没有** `package.json` —— 清单那一半只有在
分支 worktree（或其 clone）上才能测；「没有清单时靠约定目录仍然可用」那一半在 §3 的 CONVENTION-ONLY 列
单独证明。两条路都已实测。

```
$ cd /tmp/m38-real-a && git init -q -b main
$ git clone -q -b task/M38-public-release-prep <worktree> vendor/teamsmith && git -C vendor/teamsmith rev-parse --short HEAD
31e8f31
$ pi install -l vendor/teamsmith          # PI_CODING_AGENT_DIR 指到 /tmp，不动用户级设置
Installing vendor/teamsmith...
Installed vendor/teamsmith
$ cat .pi/settings.json
{ "packages": [ "../vendor/teamsmith" ] }
$ pi list --approve | grep -i teamsmith
  ../vendor/teamsmith
    /tmp/m38-real-a/vendor/teamsmith
$ pi remove -l --approve /tmp/m38-real-a/vendor/teamsmith
Removing /tmp/m38-real-a/vendor/teamsmith...
Removed /tmp/m38-real-a/vendor/teamsmith
$ pi list --approve
No packages installed.
$ cat .pi/settings.json
{ "packages": [] }
```

三条**操作面上的实测细节**（README 里已按实测写）：
1. `pi list` / `pi remove` 在**未信任**的项目里需要 `--approve`：不带时 `pi list` 说 `No packages installed.`，
   `pi remove -l` 打印 `Project is not trusted. Use --approve to modify local package config.`（**而且退出码仍是 0**
   —— 只看退出码会以为删掉了；`pi list` 仍是关键证据）。
2. 本地 path 安装**记录成相对路径**（`../vendor/teamsmith`），但 `pi remove -l <绝对路径>` 也能删（pi 会解析）。
3. 用户级设置**未被触碰**：`~/.pi/agent/settings.json` 在整轮验收前后 md5 都是 `456237603…1c0e`。

## §2 必做验收 ②：private 仓库的 git 源安装（SSH key）

```
$ cd /tmp/m38-real-b && git init -q -b main
$ pi install -l git:git@github.com:Track07-cda/teamsmith@v1.40.0
Cloning into '/tmp/m38-real-b/.pi/git/github.com/Track07-cda/teamsmith'...
HEAD is now at a0cd880 P16: split-teamsmith-init-skill — ...
Installed git:git@github.com:Track07-cda/teamsmith@v1.40.0
$ pi list --approve | grep -i teamsmith
  git:git@github.com:Track07-cda/teamsmith@v1.40.0
    /tmp/m38-real-b/.pi/git/github.com/Track07-cda/teamsmith
$ pi remove -l --approve git:git@github.com:Track07-cda/teamsmith@v1.40.0
Removed git:git@github.com:Track07-cda/teamsmith@v1.40.0
$ pi list --approve
No packages installed.
$ ls .pi/git/github.com/Track07-cda      # 卸载后 clone 目录也删掉了
ls: cannot access '.pi/git/github.com/Track07-cda': No such file or directory
```

**负例（写进 README 的那条）**：brief 里写的 HTTPS 简写 `git:github.com/Track07-cda/teamsmith@v1.40.0`
在 private 仓库上**失败**（pi 把它解析成 HTTPS，私有仓要凭据）：

```
$ pi install -l git:github.com/Track07-cda/teamsmith@v1.40.0
fatal: could not read Username for 'https://github.com': terminal prompts disabled
Error: git clone https://github.com/Track07-cda/teamsmith ... failed with code 128
```

所以 README 的推荐形式是 `git:git@github.com:…@v1.40.0`（或 `ssh://git@github.com/…`）；仓库转公开后
HTTPS 简写才可用。v1.40.0 那棵树**没有** `package.json`，它走的是约定目录发现 —— 这正是 §3 探针里
「CONVENTION-ONLY」那一列证明的等价路径。

## §3 发现性证据：清单到底驱不驱动物理发现（含翻转）

`pi list` 只证明「设置里有这个包」，不证明 skill 被加载。用 pi 自己的 `DefaultResourceLoader`
（`docs/team/reports/M38-dev-bob-probe-pi-manifest.mjs`，同一套发现机制，不起模型、不开 TUI）跑矩阵，
`HOME`/`PI_CODING_AGENT_DIR` 全指到 `/tmp/m38-home`，避免用户级 skill 混进来：

| 夹具 | 装的是什么 | 结果 |
|---|---|---|
| BASE | 什么都没装 | `SKILLS_TOTAL 0` |
| POSITIVE | 有 `package.json`（`pi.skills: ["./skills"]`） | `SKILL teamsmith`、`SKILL teamsmith-init`、`SKILLS_TOTAL 2` |
| CONVENTION-ONLY | 同一个包**删掉** `package.json`（只有约定目录 `skills/`） | `SKILLS_TOTAL 2`（旧行为不变，加清单没有破坏它） |
| FLIP | 清单改成 `pi.skills: ["./does-not-exist"]`（`skills/` 仍在盘上） | `SKILLS_TOTAL 0` |

（POSITIVE 那行还带完整路径：`SKILL teamsmith <- /tmp/m38-ev/pkg/skills/teamsmith/SKILL.md`。）

**FLIP 这一列就是本任务的翻转证据**：把清单指向一个不存在的路径，约定目录 `skills/` 明明还在盘上，
发现结果却归零 —— 证明「装了包能看见 skill」是**清单**在起作用，不是约定目录碰巧兜住；也解释了为什么
清单必须把要暴露的资源**写全**（因此 Extension 才需要单独说明：它们不在清单里，由 `-e` 逐窗口注入，
见 README「What the package declares — and what it deliberately does not」）。

## §4 必做验收 ③：pi 版本下限（实测，不是猜）

本机只装了一个 pi（0.85.1），所以下限是**装真版本来量的**：用 npm 在 `/tmp` 装候选版本，再用
teamsmith 自己的判据（`scripts/lib/cmd-project.sh` 的 `pi --help 2>/dev/null | grep -q -- '--session-id'`）
和探针各量一次。

| pi 版本 | `--session-id` 在 `--help` 里 | `--help` 走哪个流 | doctor 式判据（只读 stdout） | 探针：清单发现 |
|---|---|---|---|---|
| 0.74.0（当前 npm 名下的最老版本） | 无（`2>&1` 也找不到） | stderr | ✗ FAIL | 2 个 skill（清单在 0.74.0 已被尊重；FLIP 场景 = 0） |
| 0.76.0 | **有** | **stderr** | ✗ FAIL（假红：stdout 是空的） | — |
| 0.79.1 | 有 | stdout | ✓ PASS | — |
| 0.85.1（本机） | 有 | stdout | ✓ PASS | 2 个 skill（BASE=0，见 §3） |

- CHANGELOG 依据（`@earendil-works/pi-coding-agent` 包里的 `CHANGELOG.md`）：`--session-id` 是 **0.76.0** 加的；
  「help/version 在被重定向时也能正常输出」的修正是 **0.79.1**。
- 所以 README 的 Requirements 写的是 **Pi ≥ 0.79.1**：`--session-id` 虽然 0.76.0 就有，但 0.76.0–0.79.0 的
  `--help` 写到 stderr，doctor 的探针（只读 stdout）看不到 → 会把「功能其实够用」的版本报成过旧。
- **给 PM 的 finding（不是本任务能改的）**：doctor 那条 `pi --help 2>/dev/null | grep -q -- '--session-id'`
  只看 stdout，在 0.76.0–0.79.0 上会报一个假的「pi 版本过旧」。修法很简单（`2>&1` 或
  `pi --help 2>&1 >/dev/null` 再判），但 `scripts/**` 是 PM 归属，我没动（见 §7）。

## §5 交付物 3/4/5/6 的验证

### 5.1 `.github/workflows/gates.yml` 语法与契约（**未经真实 CI**）

工作流本身在本地跑不了（没有 runner）。能做的检查都做了：

```
$ bun check-workflow.mjs <repo-root>        # docs/team/reports/ 里那份
ok   trigger: push on main
ok   trigger: workflow_dispatch (manual)
ok   no pull_request trigger (Actions minutes on a private repo)
ok   job `gates` present
ok   runs-on: ubuntu-latest
ok   timeout-minutes: 45
ok   bash -n step 0 (System dependencies)
ok   bash -n step 1 (OpenSpec CLI)
ok   bash -n step 2 (Gates)
ok   gate step runs exactly: openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
PASS

$ <actionlint v1.7.12 (从官方 release 下到 /tmp)> .github/workflows/gates.yml ; echo $?
0                                            # 无任何 finding
```

- **没验证的**：真实 GitHub Actions 运行（private 仓库、Actions 额度、runner 上的 tmux/perl/bun/openspec
  组合、以及 smoke 在无 TTY runner 上的行为）。第一次手动触发时请把结果与本地等价命令对照 —— 这句已写进
  `PUBLISH.md` §7。
- **本地等价命令**（就是门禁那两件套）：
  `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`

### 5.2 npm 名检查

```
$ npm view teamsmith name version
npm error 404 Not Found - GET https://registry.npmjs.org/teamsmith - Not found
$ npm view teamsmith --json | head -3
{ "error": { "code": "E404", ... } }
```

→ `teamsmith` **未被占用**，不需要备选名（备选仍写进 PUBLISH.md §3：`pi-teamsmith` / `@<scope>/teamsmith`）。
另外实测本机 `npm whoami` = `ENEEDAUTH`（没有登录态）→ 现在**不可能**误发布。

### 5.3 npm 打包面（为可选的 `npm publish` 做准备）

```
$ npm pack --dry-run --json | node -e '…'
package: teamsmith@1.40.0 | filename: teamsmith-1.40.0.tgz
entries: 134 | unpackedSize: 3468860 bytes
skills/ entries: 130
install.sh present: true
README.md: true | LICENSE: true | package.json: true
leaks (docs/ .pi/ openspec/ AGENTS.md SCOPE.md .github/): none
```

→ `files` 白名单确实把 `docs/team/**` 账本、`.pi/**`、`openspec/**` 挡在包外。

### 5.4 发布前历史检查（PUBLISH.md §1 的前置命令，先替用户跑一遍）

```
$ git log -p --all | grep -nE 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|glpat-[A-Za-z0-9_-]{15,}' | head -5
（空）
$ git ls-files | grep -iE 'token|secret|\.env$|\.pem$|\.key$'
（空）
```

### 5.5 LICENSE（brief 第 6 条：只建议，不改）

`LICENSE` 仍是 `Copyright (c) 2026 pm-skills contributors` —— **按 brief 要求没有擅自改**。
建议：公开发布前改成 teamsmith 的口径（如 `teamsmith contributors`）；改动会牵动 README/`package.json` 的
`license` 口径说明，放进发布清单更自然（`PUBLISH.md` §6 已列为「等用户拍板」）。

### 5.6 版本号的单一来源与 `package.json` 的同步义务

`package.json:version` 现在是 `1.40.0`，与 `scripts/lib/common.sh` 的 `TEAM_VERSION`、两个 `SKILL.md` 的
`metadata.version` 一致（brief 里写的「现在 v1.41.0」与实际不符：仓库当前盘上/`main` 上都是 **1.40.0**，
见 `git show main:skills/teamsmith/scripts/lib/common.sh | head -6` → `TEAM_VERSION="1.40.0"`；发布时的 bump 由 PM
决定，所以 `package.json` 跟的是**当前**版本号）。四处实测：`grep -m1 '^TEAM_VERSION=' …` = 1.40.0、
两个 `SKILL.md` 的 `metadata.version` = 1.40.0、`node -p 'require("./package.json").version'` = 1.40.0。
**bump 时必须四处一起改**（smoke §11f 钉住 `common.sh` ↔ 两个 `SKILL.md`，第四处 `package.json` 目前没有门禁），
`PUBLISH.md` §2 已把对照命令写死。

## Verification evidence (must have actually been run)

```
$ TIP: f5c3919 | tree == HEAD? 0 modified tracked files     # 门禁跑在冻结的 tip 上（git status --porcelain -uno 为空）

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters  ✓ spec/board-and-status  ✓ spec/boundary  ✓ change/console-board-page
✓ spec/delivery-guard  ✓ spec/dispatch  ✓ spec/init-skill  ✓ spec/meeting  ✓ spec/memory-and-deps
✓ spec/notify-and-inbox  ✓ spec/panel  ✓ spec/pm-lifecycle  ✓ spec/verification  ✓ spec/watchdog
Totals: 14 passed, 0 failed (14 items)
VALIDATE_RC=0

$ bash skills/teamsmith/tests/smoke.sh </dev/null        # 全量（1165s，含同机排队）
  ✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变
  ✓ M28 容器里跑真 pi 体检：输入框判据 + 收回在真实现场成立
== 结果 ==  ✓ 2079  ✗ 0
smoke 全绿
SMOKE_RC=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh    # 快模式（317s，同一内容，见下面的口径说明）
== 结果 ==  ✓ 1646  ✗ 0
FAST 模式：跳过 20 个真进程段落（1c·M11 真沙盒窗口|6·dispatch 真拉起|6g·非 Pi agent 端到端|
  6h·派单启动证据（真窗口）|6i·非 Pi PM 端到端|6j·worker adapter 启动证据（真窗口）|
  10c-②·后台进程组里的门禁（M25）|11·close 后窗口|11b·巡检/pulse|11b2·PM 存活证据链|
  11b3·启动中的 PM（M7.2）|11c·agent 续跑|11d·边界守卫（真打字）|11g②·say 离线投递|11g③·敲门探测|
  11j·pulse 迁移夹具|12b-e·巡检一拍排水|12b-h·真 pane 端到端（守卫/排水/草稿窗口）|26-m·真 pane|
  31b·容器 tmux 自检（podman））——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
FAST_RC=0
```

- Verdict: **两件套全绿**（`openspec validate --all --strict` 14/14；全量 smoke 2079 绿 0 红；快模式 1646 绿 0 红）。
- 口径（写清楚以防误读）：两轮门禁读的是**同一份内容** —— 四个交付提交 + 两个证据脚本 + 本报告（当时是带
  占位的未提交版）。全量那次是 tip `f5c3919` 上的**冻结复跑**（跑前 `git status --porcelain -uno` 为空）。
  门禁绿了之后只改过**本报告自身**（占位 → 真实输出），没有碰任何被门禁读取的交付文件。
- Notes（未验证的部分，不冒充）：workflow 不在真实 CI 上（§5.1）；`smoke` 的同机排队等待（1165s 里含排队）
  会让耗时数字偏大，功能结论不受影响。

## Flip evidence

本任务不是缺陷修复任务，但有两个「故意破坏 → 检查器必须红 → 恢复后必须绿」的证据：

1. **清单是发现之源**（§3 FLIP）：有清单 → 2 个 skill；把清单指向不存在的路径（`skills/` 仍在盘上）→ **0 个**；
   反向的 CONVENTION-ONLY（删掉 `package.json`）仍是 2 个 → 旧行为没被破坏。
2. **workflow 检查器不是空跑**（在 `/tmp/m38-wfflip` 的副本上做，仓库里的文件没被碰过）：

```
### clean copy                                              -> PASS（rc=0）
### break 1: 删掉 workflow_dispatch                        -> FAIL 1
### break 2: 门禁行只剩 openspec validate --all（丢 smoke）  -> bad  gate step = "openspec validate --all" / FAIL 1 (rc=1)
### break 3: run 块写成 bash 语法错（if 不闭合）              -> FAIL 1（bash -n 抓到）
### break 4: YAML 本身坏掉（branches: [main）                -> rc=1（解析异常，不冒充绿）
### restore                                                 -> PASS（rc=0）
### diff 仓库里的 gates.yml 与副本                          -> identical
```

actionlint v1.7.12 对干净版独立复核为 0 finding（§5.1）。

## Decisions and deviations

1. **① 的命令形状**：brief 写 `pi list | grep -i teamsmith`。实测 `pi list` 对**本地 path** 安装只打印路径、
   不打印包名（git 源安装才带 `teamsmith`），且未信任项目需要 `--approve`。为了不改 brief 的验收意图，
   ① 用「clone 成 `teamsmith/` 目录再本地安装」的形状跑（见 §1），② 原样带包名。**没有**用 `pi list` 的退出码
   当证据（它不带 `--approve` 时也退 0）。
2. **Requirements 的 pi 下限**：brief 说「写成你验证过的数字」。实测结论是 **≥ 0.79.1**（理由见 §4），
   不是更早的 0.76.0（flag 有了但 doctor 探针看不见）。
3. **README 里的旧句**「No forge dependency, no container dependency, no jq/python/node」与新的必需依赖
   （`node ≥ 20`/`bun ≥ 1.3` 是 doctor 的必需依赖，M5.1/D19）自相矛盾，改写为「CLI 是 bash（no jq/python），
   JS 运行时见 Requirements」。这是 brief 三段之外的**必要**修正，特此声明。
4. **workflow 不加 `pull_request`、不加快速 smoke 前置步**：brief 明确「先做成手动 + main push」且提醒
   private 仓库额度；额外步骤会多花额度。
5. **OpenSpec CLI 不锁版本**：本地 1.8.0 / npm 上 1.13.1；口径（specs 跟着当前 CLI）写进 workflow 注释与
   `PUBLISH.md` §7，要钉版本就是一处改动。
6. **没有动 `LICENSE`、可见性、tag、npm、`.gitignore`**；`skills/**` 未动。

## Suggested next steps

- **建议立项（PM 决定）**：doctor 的 pi 探测只看 stdout，对 0.76.0–0.79.0 报假红（§4）。改法是
  `pi --help 2>&1 | grep -q -- '--session-id'`（或同时接受 stderr）。这属于 `skills/teamsmith/scripts/**`，
  归 PM；若要派单，请把「翻转夹具：0.76.0 式 help-to-stderr 的假 pi + 0.79.1 式真 help」写进任务书。
- **建议立项（PM 决定）**：`package.json:version` 与 `TEAM_VERSION` 的同步现在没有门禁守着（smoke §11f
  只钉 SKILL.md ↔ common.sh）。若认可，加进 smoke §11f 是几行的事 —— `skills/teamsmith/tests/**` 当前归 dev。
- **首次真实 CI**：手动 `workflow_dispatch` 触发一次，把结果与 §5.1 的本地等价命令对照后再把它当门禁引用。
- **等用户拍板**：LICENSE 署名（§5.5）、npm 名（§5.2，目前可用）、仓库可见性与 tag 的实际发布时机
  （`PUBLISH.md` §1–§2）。
