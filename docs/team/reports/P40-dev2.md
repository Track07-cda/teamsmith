# P40 · npm-cli-and-project-init apply：`bin/team.mjs` + `team init` 装 `.pi/skills` + doctor 行

agent: dev2   status: 交付（本分支；验收命令与门禁见 §6）   time: 2026-09-22
branch: `task/P40-npm-cli-team-init-pi-skills-`   PR/MR: -（local 模式：不 push，分支留在本地 worktree）
change: `npm-cli-and-project-init`（proposal 已验收）   deltas: `init-skill`, `memory-and-deps`
base: `98712da`（当时的 main，含 P39）；交付前已 rebase 到 `main@7290fd1`（只与 P32 的 smoke §38-f 同点插入，冲突已解：38-f 与 39 并存）

## Deliverables

| Path | What |
|---|---|
| `bin/team.mjs`（新） | npm bin 包装器：先验 shell（`bash` 解析不到 → 点名 ENOENT，版本 < 4 → 点名找到的版本；两种都打 `bash >= 4` 的修法并指向 README Requirements，非 0 退出、不跑 CLI），然后 argv/stdio/env 原样交给 bash CLI，退出码逐字透传（信号 → 128+signo）。不实现、不包装、不改写任何子命令 |
| `package.json` | `bin: {"team": "./bin/team.mjs"}`（恰好一项）+ `files` 加 `bin/`；`version`/`pi.skills` 不动 |
| `skills/teamsmith/scripts/lib/cmd-init.sh`（新） | `team_init_install_skills`：目标 `<main worktree>/.pi/skills/<name>`；按名取源（`$TEAM_SKILL_DIR` + 兄弟目录，绝不扫荡）；link（默认）/`--copy`（只排除 `.git/`、`node_modules/`）/`--no-skills`；design §3 冲突表（**不认识的条目连 `--force` 都不删**）；逐 skill 一行 `link/copy/skip`；成功才把 `.pi/skills/` 写进 `.gitignore`（一次）。`team_project_skill_install_row` 是 doctor 行的判定 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `init` 解析 `--copy`/`--no-skills` 并调用安装步；`team help` 的 init/bootstrap 两行；`team doctor` 增一行 |
| `skills/teamsmith/scripts/lib/cmd-bootstrap.sh` | config 已存在的分支也跑同一实现（老项目的升级路径）；`--print` 计划点名该步、不写盘 |
| `.gitignore` | 本仓 teamsmith 块加 `.pi/skills/`（已跟踪的 `.pi/skills/openspec-*` 不受影响） |
| `skills/teamsmith-init/SKILL.md` | 安装节在最前（`npm install -g teamsmith` → `team init` → `.pi/skills/`），两条替代路线（Pi 包 / `install.sh`），Preconditions 不再假设 CLI 已在 PATH；96 行（≤ 100），三段交接节保留 |
| `skills/teamsmith/SKILL.md` | 命令表 `init` 行点名项目 skill 安装与两个旗标；“Starting a new project” 指引点名 `.pi/skills/` |
| `README.md` | §Install：npm CLI + `team init` 为主路线（在两条替代路线之前）；打包声明段补一个 bin 入口；§Requirements 的 `bash` 行写明入口会检查并打印修法 |
| `skills/teamsmith-init/references/bootstrap.md` | 步骤表增 “Project skills” 行；`.gitignore` 行补 `.pi/skills/` |
| `docs/team/PUBLISH.md` | §0 增 npm CLI 打包契约证据行；§3 增发布后演练（`npm i -g` → `team init` → 断言解析到装出来的包 → doctor 无 fail → `--force` 修复路径） |
| `skills/teamsmith/tests/install-shape.sh`（新） | headless 夹具，七节（surfaces/install/conflict/shell/pack/doctor/flip）：自起 `$TMPDIR` 仓库、先剥 `TEAM_*`/`TMUX`、写盘前用 `team paths` 证明夹具；每组承诺一份可复用 `chk_*` 判据 + scratch 树翻转；无 tmux/pi 进程，doctor 节用 stub pi |
| `skills/teamsmith/tests/smoke.sh` | §2 增 P40 断言（两条软链、`.gitignore`、第二次 init 两个 `skip`）；新 §39 跑夹具（FAST 照跑）；P16 工具面检查点名唯一例外（§8） |
| `docs/team/reports/P40-dev2/pkg/run.sh` + `out/` | 证据包：九节原始输出 + FAST/全量门禁日志（本报告引用的原始证据都在这里，可复跑） |

## 覆盖映射（requirement ↔ tasks.md 项 ↔ 证据）

| requirement（delta） | tasks.md | 实现 | 原始证据 |
|---|---|---|---|
| init-skill#The CLI ships as one npm bin entry and the package carries what it runs | 1.1–1.3, 4.1 | `package.json`、`bin/team.mjs` | `out/5-pack.log`、`out/8-wrapper-and-pack.log`、夹具 `shell`/`pack` 两节 |
| init-skill#team init installs the project skills | 2.1–2.4, 4.1–4.2 | `cmd-init.sh`、`cmd-project.sh`、`cmd-bootstrap.sh` | `out/2-install.log`、`out/3-conflict.log`、smoke §2/§39 |
| init-skill#The project-local install is visible in team doctor, and repairable with team init | 2.5, 4.1 | `cmd-init.sh` 的 row + `cmd-project.sh` doctor | `out/6-doctor.log` |
| init-skill#Initialization guidance lives in a dedicated teamsmith-init skill（MODIFIED） | 3.1–3.5 | init SKILL / 日常 SKILL / README / bootstrap.md / `team help` / PUBLISH | `out/1-surfaces.log` |
| memory-and-deps#The shell the CLI runs on is a checked dependency, not an assumption | 1.2–1.3, 4.1 | `bin/team.mjs` | `out/4-shell.log`、`out/8-wrapper-and-pack.log` |

## Verification evidence（全部真跑；原始输出在 `docs/team/reports/P40-dev2/pkg/out/`）

```
$ bash docs/team/reports/P40-dev2/pkg/run.sh          # 九节夹具证据（rebased tip）
1-surfaces             rc=0  ✓ 10 ✗ 0
2-install              rc=0  ✓ 40 ✗ 0
3-conflict             rc=0  ✓ 13 ✗ 0
4-shell                rc=0  ✓ 4  ✗ 0
5-pack                 rc=0  ✓ 4  ✗ 0
6-doctor               rc=0  ✓ 11 ✗ 0
7-flip                 rc=0  ✓ 14 ✗ 0
8-wrapper-and-pack     rc=0
9-openspec             rc=0   →  Totals: 18 passed, 0 failed (18 items)
```

包装器 ↔ bash 入口（`out/8-wrapper-and-pack.log` 原文节选）：

```
== node bin/team.mjs version ==        teamsmith 1.42.0   rc=0
== bash skills/teamsmith/scripts/team version ==   teamsmith 1.42.0   rc=0
== help 逐字节比较 ==                  byte-identical
== 未知子命令 rc ==                    wrapper rc=2 / bash rc=2
== 没有 bash（PATH 指向空目录）==
teamsmith: 找不到可用的 bash（bash: ENOENT）：CLI 是 bash 脚本，需要 bash >= 4。装一个 bash 4+（Windows 用
Git Bash 或 WSL，或把 Pi 的 shellPath 指到它）并确保它在 PATH 里；前置条件见 README.md 的 Requirements 表
rc=3
== bash 太旧（探针答 3 的 shim）==
teamsmith: bash 版本太旧：解析到的 bash 报了版本 3，需要 bash >= 4。升级 bash 后重试；前置条件见 README.md 的 Requirements 表
rc=3
== npm pack --dry-run：关键条目（逐条点名）==
有 bin/team.mjs ｜ 有 skills/teamsmith/SKILL.md ｜ 有 skills/teamsmith-init/SKILL.md ｜ 有 install.sh
账本/node_modules 条目数 = 0
== npm 私有 prefix 安装（真用户路径）==
teamsmith 1.42.0   rc=0        （tarball：165 files / 1.5 MB packed）
```

`team init` 安装矩阵（`out/2-install.log`）：默认 link 两条（软链解析到 `$TEAM_SKILL_DIR` 与兄弟目录）、
`.gitignore` 恰好一条 `.pi/skills/`、第二次 init 两个 `skip` 且条目/目标不变、`--copy` 对着已有软链 `skip`、
`--no-skills` 不建目录也不动 `.gitignore`、`--copy` 是真目录且 `SKILL.md` 字节相等、无
`scripts/panel/node_modules` 与 `.git`、linked worktree 装到主工作树（worktree 侧无条目）、
`bootstrap` 对“配置已存在、`.pi/skills` 缺席”的项目装上两条且 `config.sh` sha 不变、
`bootstrap --print` 点名该步且不写盘（`.git` 指纹不变）。

冲突表逐格（`out/3-conflict.log`）：三种“不认识”的形状（无 `SKILL.md` / frontmatter `name` 不符 / 普通文件）
默认与 `--force` 都非 0、字节不变；手改副本默认非 0 且字节不变、`--force` 后 `SKILL.md` 与源逐字节相等；
别源软链默认非 0 且目标不变、`--force` 重指到运行树。

doctor 三态（`out/6-doctor.log`）：link → `✓ <入口> → <目标>`，退出 0；无安装 → 无该行，退出 0；
副本版本 0.0.1 → `! … 修法 team init --force`，退出 0；别源软链 → warn 点名两侧路径，退出 0；两条修复路径
都回到 pass。

五个宣称面（`out/1-surfaces.log`）：init SKILL 行序 npm(17) < team init(18) < team bootstrap(59)、
点名 `.pi/skills/`、两条替代路线都在；`team help` 的 init 行有 `.pi/skills`/`--copy`/`--no-skills`、
bootstrap 行点名装 skill；日常 skill 的命令表 init 行点名安装；README §Install 的 npm 路线在两条替代路线之前、
Requirements 的 bash 行写明检查。init SKILL 96 行。

门禁（本报告交付前的最后一次全量运行）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 18 passed, 0 failed (18 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2322  ✗ 0
smoke 全绿   （FAST 模式：28 个真进程段落显式 SKIP）

$ bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ <FULL_PASS>  ✗ 0
smoke 全绿
```

§39 与 §2 的新断言在 FAST 里就是绿的：`✓ 39 install-shape.sh 全绿（90 条断言，含翻转绿/红两侧）`、
`✓ P40 init 装了项目 skill…`、`✓ P40 第二次 init 对两个 skill 都报 skip`、
`✓ 工具面只在 P40 安装步（cmd-init.sh）引用 teamsmith-init，其余不再引用`；
§18b 的渲染面仍绿（`✓ 默认命令仍带 --skill`、`✓ 渲染的启动命令仍挂日常 skill 目录（--skill）`）。

## Flip evidence（每条承诺一个 scratch 树红侧；原始输出 `out/7-flip.log`）

判据是**同一份** `chk_*` 函数：先在真实树跑出绿，再在只改一处的 scratch 树跑出红；夹具只复制到
`$TMPDIR`，跑完比对真实仓库的 `git status` 指纹（第 ⑥ 条）。

| # | 承诺 | 破坏实现（scratch 树） | 破坏后 | 未破坏 |
|---|---|---|---|---|
| ① | 包装器逐字透传退出码 | `process.exit(child.status ?? 1)` → `process.exit(0)` | 红：未知子命令 `wrapper=0 / bash=2` | 绿：`version/help/未知子命令 rc 三处一致（rc=2）` |
| ② | 不认识的条目连 `--force` 都不删 | 把拒绝调用换成 `rm -rf "$dest"` | 红：目录被删/不再报红线 | 绿：`拒绝且连 --force 都不删（rc=1，sha 不变）` |
| ③ | doctor 漂移给 warn + 修法 | 覆盖 `team_project_skill_install_row` 为静默 | 红：`install 行没有 warn：[]` | 绿：`warn 点名版本与修法` |
| ④ | bootstrap 复用安装步（升级路径） | 删掉 cmd-bootstrap.sh 里的 `team_init_install_skills` 调用 | 红：`没有装上 .pi/skills/teamsmith` | 绿：`已存在配置也装了 skill，config.sh 未动` |
| ⑤a | 声明面：恰好一个 bin + `files` 带 `bin/` | `files` 去掉 `bin/` | 红：`files 白名单里没有 bin/：['skills/', 'install.sh']` | 绿：`bin 一项 + files 带 bin/（'./bin/team.mjs'）` |
| ⑤b | 打包清单带着它要跑的东西 | 删掉 scratch 树的 `bin/team.mjs` | 红：`缺：bin/team.mjs` | 绿：`清单齐全（165 项）且不含账本/node_modules` |
| ⑥ | 夹具不碰真实树 | — | — | 绿：`夹具没碰真实树（git status 指纹不变）` + `反向守卫（M7.2）：整轮夹具没往真实仓库收件箱写一个字节` |

⑤a 的说明：设计 §9 / R3 场景写的是“`files` 去掉 `bin/` → 走查红、点名缺 `bin/team.mjs`”。**npm 实测不是这样**：
`npm pack` 永远带上 `bin` 目标（连 `files` 里没有也会带，见 §8 的独立实验），所以走查不会红。判据改成两层：
声明面（`package.json` 的 bin/files，去掉 `bin/` 就红）+ 打包清单（bin 目标文件不存在就红），两层都有红侧。

## Decisions and deviations

1. **授权路径与 brief 的 `grant:` 不完全一致（需要 PM 追认）**：
   - brief 的 grant 没列 `skills/teamsmith/scripts/lib/cmd-bootstrap.sh`，但硬要求 #3（bootstrap 复用同一实现、
     config 已存在时也跑）与 tasks.md 的路径授权都要求它 —— 已按硬要求改（4 行：一个调用 + 一行 `--print` 计划）。
   - brief 的 grant 写 `cmd-agents.sh（doctor 行）`，但 `team_cmd_doctor` 实际在 `cmd-project.sh`（grant 只写了
     “help 文案”）。doctor 行按代码事实加在 `cmd-project.sh`（含 init 的安装调用与旗标解析）；**`cmd-agents.sh` 未动**。
2. **改了一处既有门禁断言（不是 append-only）**：P16 的“工具面从不引用 `teamsmith-init`”与新规格（安装步按名装兄弟
   skill）直接冲突。smoke 的该扫描现在只把 `scripts/lib/cmd-init.sh` 排除，ok 行也点名这个例外；注入探针
   （`p16-probe.sh`）仍会红，守卫没有失去牙齿。原始 diff 见 §6 的门禁命令。
3. **措辞受 M29 政策扫描约束**：`pi install git:…@v<version>` 会命中 M29 的 `pi install [a-zA-Z@]`（“还在推第三方包”）。
   R1 要求两条替代路线留在页面上，于是按规格原文用 `pi install …`（不带包名）。路线仍然可读、可照做（README 有完整命令）。
4. **`--force` 的既有语义保留**：`team init --force` 依旧覆盖 config/文档骨架；它同时对冲突条目生效（同一次运行）。
5. **`readlink -f` 回退**：BSD 缺 `readlink -f` 时回退到 `readlink` 的原始目标再判冲突（我们自己建的链接存的是绝对源路径），
   避免把“同一来源”误报成冲突。
6. **P16 之外没有第二套 spec 系统**：本报告只记证据与偏差；承诺都在 deltas 里。

## 未触碰面（边界自证）

`git diff --name-only 7290fd1..HEAD`（本分支的实际基线 = rebase 后的 main）恰好是 §Deliverables 的 13 个路径；
**`install.sh`、`extension/**`、`openspec/**`、`panel/**` 与其它 `cmd-*.sh` 都不在其中**。交付门禁跑完后 main
又前进了（`bb9783f`：P44/P47/P48 的账本与 openspec 文件），与这 13 个文件**零重叠**，所以本分支仍可直接
squash 合并。没有 npm publish、没有 tag、没有改仓库设置。`pi.skills` 清单未动（smoke 与夹具都钉了渲染面
`--skill` 不变）。

## 隔离与异常记录

- 夹具的隔离链：先 `unset` 继承的 `TEAM_*`/`TMUX`/`TMUX_PANE` → 每个夹具仓库写盘前 `team paths` 断言
  `main_root` 就是它 → 整轮结束再断言真实仓库 `docs/team/inbox/**` 指纹不变（M7.2 的反向守卫）→ 翻转节再断言
  真实仓库 `git status` 指纹不变。原始 ok 行见 `out/*.log`。
- 一次外部干扰（不是本任务造成的）：第一轮 FAST 运行期间，另一个进程往
  `docs/team/reports/P36-dev2/pkg/out/8-fast-smoke.log`（我 worktree 里的旧证据文件）追加了一行
  `FAST_SMOKE_RC=0`。我没有提交它，已 `git checkout --` 还原；本报告的交付树里它是干净的。
- 第二次全量门禁尝试撞上**环境故障：`/tmp`（15G tmpfs）被历史 review checkout 写满**（剩余 1.4G），
  真进程段落因此大面积报 `No space left on device`（M8.2 的派单、F16、pulse 等）——这不是本分支的回归：
  同一分支的 FAST 已经全绿，失败日志里第一条原因就是 ENOSPC。处置：杀掉那次运行，最后一次全量改在
  `TMPDIR=$HOME/.cache/p40-smoke-tmp`（宿主盘，304G 空闲）上跑，**门禁锁仍用共享的
  `/tmp/teamsmith-smoke.lock`**（没有绕过排队）。证据包 `pkg/out/11-smoke-full.log` 是修好后的那次。
  提醒 PM：`/tmp/review-*` 平均各占 ~0.9G、累计 ~5.5G，不清理的话其他 agent 的全量门禁还会撞同一面墙
  （清不清由 PM 定，我没动别人的目录）。

## Suggested next steps

- PM 独立复验：`team review P40 --strong --dir <独立 checkout>`（翻转红/绿两侧与证据包路径分别是
  `out/7-flip.log` 与 `docs/team/reports/P40-dev2/pkg/run.sh`）。
- 合并顺序：本分支已 rebase 到 `main@7290fd1`（与 P32 的 §38-f 同点插入，冲突已解），merge 时应无冲突。
- 若 PM 想把“npm 永远打包 bin 目标”写回 `init-skill` 的 R3 场景（现在的场景与 npm 实测不符），那是 PM 的 spec
  改动，本任务没动 deltas。
- 设计与本任务都提到的 `tests/__pycache__/fake-tui.cpython-313.pyc` 仍未处理（不属于本任务范围）。
