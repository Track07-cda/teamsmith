# P51 · `npm-cli-and-project-init` 独立验证（verify 阶段）：dev2 的 apply 对抗性复验

agent: dev   status: 交付（PASS **带 1 条 finding**，见 §F1——按 D-规矩「PASS 带 finding = 返工还是归档时顺手修」由 PM 裁决）   time: 2026-09-23
branch: `task/P51-npm`   PR/MR: -（local 模式：不 push，分支留在本地 worktree）
change: `npm-cli-and-project-init`   deltas: `init-skill`, `memory-and-deps`   phase: **verify**
apply 作者: **dev2（P40，d2716cd）——不是我**；本报告不复述其报告，所有结论出自我自己的探针与原始输出。
验证基线: `764ccfc`（本分支 tip = main 当时位置，含 P40 apply）；实现零改动（`git status --porcelain` 除本报告授权路径外为空，60·⑤ 钉了指纹前后一致）。

## 验证包与复跑方法

`docs/team/reports/P51-dev/pkg/`：`lib.sh` + `run.sh` + 八个编号节脚本；原始输出全部在 `pkg/out/`。

```sh
bash docs/team/reports/P51-dev/pkg/run.sh          # 八节全跑（70 节只解析 out/70*.log，门禁日志已入库）
```

整包终态（2026-09-23 完整跑）：**✓ 151 · ✗ 0 · finding 1 · skip 0**。

| 节 | 覆盖 brief | 结果 |
|---|---|---|
| 10-wrapper | #1 等价 | ✓ 11 ✗ 0 finding 0 |
| 20-shell | #2 shell 前置 | ✓ 13 ✗ 0 finding 0 |
| 30-init | #3 安装语义 | ✓ 69 ✗ 0 finding 0 |
| 35-bootstrap | #4 bootstrap | ✓ 16 ✗ 0 finding 0 |
| 40-doctor | #5 doctor 三态 | ✓ 21 ✗ 0 finding 0 |
| 50-surfaces | #6 六个面 | ✓ 13 ✗ 0 **finding 1**（§F1） |
| 60-mutations | 变异 ≥3 | ✓ 10 ✗ 0 finding 0（4 条变异全钉住） |
| 70-regression | #7 零回归 | ✓ 8 ✗ 0 finding 0 |

探针自身质量说明：第一轮运行我的包出过 8+4 个 finding，根因全是**我自己 lib.sh 的树路径多退一层**
（`P51_TREE` 指到 `dev/docs`），另有两处探针 bug（`local` 同行引用、`printf` 格式串以 `--` 开头）在后续轮
次抓出——findings 机制把探针 bug 和实现缺陷分开暴露，修完探针后才有现在的全绿。判据有效性的反面证据：
60 节每条变异的对照侧（真实树）都必须绿、变异侧必须红，缺一即 ✗。

## §1 包装器 ↔ bash 入口等价（brief #1 / init-skill R3）——PASS

`out/10-wrapper.log`：version / help / paths / config list / 未知子命令 / 坏参数（`init --frobnicate`）/
缺参数（`review`）七组，**stdout、stderr、rc 三个通道逐字节一致**；坏参数没留下任何写盘。手动复核
（在本 worktree 根，命令可复制）：

```
$ for sub in "help" "version" "paths" "config list"; do node bin/team.mjs $sub >/tmp/w.out 2>/tmp/w.err; wr=$?;
    bash skills/teamsmith/scripts/team $sub >/tmp/b.out 2>/tmp/b.err; br=$?; ...; done
team help → stdout=同 stderr=同 rc=0/0
team version → stdout=同 stderr=同 rc=0/0
team paths → stdout=同 stderr=同 rc=0/0
team config list → stdout=同 stderr=同 rc=0/0
team bogus → stdout=同 stderr=同 rc=2/2
✗ 未知子命令：bogus（team help 看全部；最近有破坏性变更，team version --check 检查 skill 版本）
```

打包契约（`out/70-regression.log` 70f）：`npm pack --dry-run --json` 清单 166 项，含 `bin/team.mjs`、
两个 `SKILL.md`、`install.sh`，无 `docs/team/`、`.pi/`、`openspec/`、`node_modules/`。

## §2 shell 前置检查（brief #2 / memory-and-deps R4）——PASS

`out/20-shell.log`：四个格子全过，含两个对抗格（假 bash 答非数字、夹具有效性对照）。拒跑消息原文：

```
== PATH 无 bash ==（绝对 node 调包装器，只有 shell 解析能失败）
teamsmith: 找不到可用的 bash（bash: ENOENT）：CLI 是 bash 脚本，需要 bash >= 4。装一个 bash 4+（Windows 用
Git Bash 或 WSL，或把 Pi 的 shellPath 指到它）并确保它在 PATH 里；前置条件见 README.md 的 Requirements 表
rc=3
== 假 bash 报 3 ==（对 BASH_VERSINFO 探针答 3，其余转交真 bash）
teamsmith: bash 版本太旧：解析到的 bash 报了版本 3，需要 bash >= 4。升级 bash 后重试；前置条件见 README.md 的 Requirements 表
rc=3
```

反向格：同一个报 3 的 shim 下直接跑 bash 入口**能**出版本行——拦住 CLI 的是包装器检查，不是环境坏了；
两格输出均无 `teamsmith 1.42.0` 版本行（CLI 没跑）。非数字探针（答 `abc`）也拒跑。正常 bash → 版本行与
bash 入口同一行、rc=0。

## §3 `team init` 安装语义（brief #3 / init-skill R2）——PASS

`out/30-init.log`（69 条，全在 `$HOME/.cache` 的临时仓，写盘前 `team paths` 逐仓证明身份隔离）：

- **默认 link**：两条软链解析到 `$TEAM_SKILL_DIR` 与兄弟目录；逐 skill 一条 `link <dest> → <src>`；
  `.gitignore` 恰好一条 `.pi/skills/`。
- **linked worktree 装主检出**（brief 点名专验）：在 `p-wt/.worktrees/wt` 里跑 init，条目落在**主检出**
  `p-wt/.pi/skills/`，worktree 侧无任何条目。
- **--copy**：真目录、`SKILL.md` 与源 `cmp` 相等、带 `scripts/team`；源树**真实存在**的
  `scripts/panel/node_modules` 被排除；`.git/` 排除另用 scratch 源栽了一个 `.git/PLANTED` 验证——副本里没有。
- **--no-skills**：不建 `.pi/skills/`、明说跳过、`.gitignore` 不塞该行。
- **幂等**：第二次 init 两个 `skip`、目标不变、仍只有两条；第三次 `--copy` 对已有软链也 skip；三次后
  `.gitignore` 仍一条。
- **冲突表逐格**（每格都有字节/目标指纹）：
  | dest 状态 | 默认 | --force |
  |---|---|---|
  | 外来软链 | 非 0，点名 `--force`/`--no-skills` 出路，目标不变 | rc=0，重指当前源 |
  | 目录无 SKILL.md / name 不符 / 普通文件（三种形状） | 非 0，字节 sha 不变 | **仍非 0，字节 sha 不变（连 --force 都不删）** |
  | 手改 vendored 副本（name 相符，version 改 0.0.1） | 非 0，字节不变 | rc=0，`SKILL.md` 与源逐字节相等 |
  | 手改且连 name 都改掉的副本（brief「不认识的目录」读法格） | — | **仍非 0，整树 sha 不变** |
  | 与源一致的副本 | rc=0 skip | rc=0 skip（不覆盖） |
- **.gitignore 与已跟踪条目**：预置 `.pi/skills/` 行不重复；仓里**已 git 跟踪**的
  `.pi/skills/openspec-foo/x.md` init 后仍在索引、内容 sha 不变、`.pi/skills/` 里=3 条。

## §4 bootstrap 复用同一实现（brief #4）——PASS

`out/35-bootstrap.log`：老项目形状（有 `config.sh`、无 `.pi/skills/`）跑 `bootstrap --no-pulse --agents dev`
→ 装上两条软链、**既有 config.sh sha 不变**、`.gitignore` 幂等一条；`bootstrap --print`（新项目形状与已存在
配置形状各一格）→ 计划点名 `.pi/skills/` 安装步，`.git`/`.pi` 指纹前后不变（一个字节没写）。

## §5 doctor 三态（brief #5 / init-skill R5）——PASS

`out/40-doctor.log`（stub pi + 依赖项降级，让 rc 只反映 install 行以外的硬失败）：无入口 → **无 install 行**
、rc=0；软链指向当前源 → `✓ <dest> → <目标>`、不 warn、rc=0；同版本 copy → pass；**别的版本 copy（0.0.1）**
→ `!` warn 点名 0.0.1 与 `team init --force`、**rc=0**；外来软链 → warn 点名两侧路径与修法、rc=0；
无 SKILL.md 目录 → warn 给修法、rc=0（永不 fail 成立）；两条修复路径（`init --force`）后都回到 pass。

## §6 六个面口径一致（brief #6 / init-skill R1）——PASS 带 §F1

`out/50-surfaces.log`：init SKILL（96 行，npm(17) < team init(18) < team bootstrap(59)，点名 `.pi/skills/`，
两条替代路线都在）；README §Install（npm(38) 在 pi install(53)/install.sh(80) 之前，bash 行写明入口检查）；
`team help`（init 行带 `.pi/skills`/`--copy`/`--no-skills`，bootstrap 行点名该步）；日常 skill 命令表；
bootstrap.md 步骤表；PUBLISH §3 演练（npm i -g(90) → team init(92) → team doctor(94) → `init --force`(95)）。
同一件事（team init 装、装到 `.pi/skills/`、两个旗标）在六处说法一致。

## §7 零回归（brief #7）——PASS

`out/70-regression.log` + 四个原始门禁日志（已入库 `pkg/out/70{a,b,c,d}-*.log`）：

```
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null   → == 结果 == ✓ 2329 ✗ 0（FAST 跳过 29 个真进程段落） rc=0
bash skills/teamsmith/tests/install-shape.sh                        → == 结果 == ✓ 90 ✗ 0 SKIP 0  rc=0
bash skills/teamsmith/tests/config-cli.sh                           → == 结果 == ✓ 125 ✗ 0 SKIP 0  rc=0
bash skills/teamsmith/tests/panel-choices.sh                        → == 结果 == ✓ 41 ✗ 0          rc=0
```

`version`（'1.42.0'）与 `pi.skills`（['./skills']）对 P40 apply 的父提交（d2716cd^）逐值比对**未动**。

## §M 变异证据（brief 要求 ≥3，红→绿原始输出）——4 条全钉住

`out/60-mutations.log`：判据是我自己的探针，**对照侧（真实树）必须绿、变异侧（$TMPDIR 的 scratch 树）必须红**。

| # | 变异（scratch 树） | 对照（真实树） | 变异后（红） |
|---|---|---|---|
| ① | `bin/team.mjs`：`process.exit(child.status ?? 1)` → `process.exit(0)` | ✓ rc 一致且非 0（2） | ✓ 红：`未知子命令 rc：wrapper=0 bash=2` |
| ② | `cmd-init.sh`：未识别拒绝调用换成 `rm -rf "$dest"` | ✓ 目录还在、字节不动、rc=1 | ✓ 红：`--force 把不认识的目录删了（rc=1）` |
| ③ | `cmd-init.sh` 尾部追加 `team_project_skill_install_row() { return 0; }`（warn 静默） | ✓ warn 点名 0.0.1 与修法，doctor rc=0 | ✓ 红：`warn 行不对：[]` |
| ④ | `package.json`：`files` 删掉 `bin/` | ✓ bin 一项 + files 带 bin/ | ✓ 红：`files 缺 bin/：['skills/', 'install.sh']` |

还原证据（60·⑤）：变异全程只在 scratch 树；真实树 `git status --porcelain` 指纹前后一致，且除本报告
授权路径（`docs/team/reports/P51-dev/`）外为空。

## §F Findings

### F1（minor，文档面内部口径不一致；PUBLISH.md 是 PM-owned）

`docs/team/PUBLISH.md:79`（§3 npm publish 清单内）：

```
npm pack --dry-run --json | head -40     # 清单来自 package.json 的 files 白名单（skills/ + install.sh）
```

括注仍写 files = `skills/ + install.sh`，**漏了 `bin/`**——本 change 的 R3 已把 files 改成
`["skills/", "bin/", "install.sh"]`，同文件 §0 表里的 P40 行（:18）是正确的新口径。即同一文件两处说法
不一致，是 apply 改 PUBLISH 时漏顺手更新的一行注释（§0 演练行本身没错）。建议：归档时把括注改成
`（skills/ + bin/ + install.sh）`；不到返工程度，但按「PASS 带 findings 不是归档授权」记在这里，PM 裁决。

## Acceptance（本分支交付 tip；实现零改动，报告提交不影响门禁——三条均在写报告前真跑）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 20 passed, 0 failed (20 items)                      # out/80-acceptance-openspec.log，rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2329  ✗ 0                                     # out/70a-fast-smoke.log，rc=0

$ bash skills/teamsmith/tests/install-shape.sh
== 结果 ==  ✓ 90  ✗ 0  SKIP 0                               # out/70b-install-shape.log，rc=0
```

**终态确认（报告提交后在交付 tip `5cc57d9` 上重跑三条，原始日志 `pkg/out/81-final-acceptance.log`）：**
`openspec validate --all --strict` → Totals: 20 passed, 0 failed（A1_RC=0）；
`TEAM_SMOKE_FAST=1 smoke` → rc=0（A2_RC=0）；`install-shape.sh` → == 结果 == ✓ 90 ✗ 0 SKIP 0（A3_RC=0）。

## 边界自证

- **没改实现**：`bin/**`、`skills/**`、`tests/**`、`openspec/**` 一律未动；本分支相对 764ccfc 只新增
  `docs/team/reports/P51-dev.md` 与 `docs/team/reports/P51-dev/**`（grant 逐字覆盖）；变异全部落在
  `$HOME/.cache` 的 scratch 树。
- 所有夹具仓库在 `$HOME/.cache/p51-verify.*`（跑完自删）；不写本仓库、不碰别人的 worktree、不开 tmux/pi
  进程（doctor 用 stub pi）；每个写盘命令前 `team paths` 证明 `main_root` 是夹具。
- 不 push、不改 `docs/team/**` 里 PM 的文件；PUBLISH 的 F1 只记录、没动手。

## Suggested next steps

- PM 独立复验：`bash skills/teamsmith/scripts/team review P51 --strong`（复跑入口：
  `docs/team/reports/P51-dev/pkg/run.sh`；变异节 60 的红/绿两侧与门禁原始日志都在 `pkg/out/`）。
- F1 处置（一行注释），然后走 verify 结论 → 用户的归档确认。
