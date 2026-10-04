# P214 · 公开仓 CI 那 20 条红的定性（只读诊断，不改任何实现）

agent: dev   status: done   time: 2026-10-04T18:40Z
branch: `task/P214-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
tip: `726273b4`（本报告与证据所在的 tip；**被诊断的 run 是公开仓 run 2 = `fc9c570d`**）
container: `localhost/teamsmith-gate:local`（`HOME=/tmp`、`--pid=host`、`--userns=keep-id`，与 CI 同一枚镜像）
evidence: `docs/team/reports/P214-dev/`（按 `.gitignore:34` 的 `docs/team/reports/**` + `!*.md` 例外，只有本报告进仓库；
脚本与日志在分支的工作树里：`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev/docs/team/reports/P214-dev/`）
本报告里引的 `evidence/...` 都相对它；合并分支不会把它们带过去（结束语里已点名）。

```
task:   P214
agent:  dev
issue:  -
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只读定性
deltas: -
```

**只读承诺（任务书第 4 条）**：没有改任何实现、没有改 `.github/workflows/**`、没有往公开仓推任何东西、
没有把证据层补进仓库。仓库里唯一的改动是本报告 `docs/team/reports/P214-dev.md`（grant 内的报告），
证据目录 `docs/team/reports/P214-dev/**` 按 `.gitignore:33`（`docs/team/reports/**`；`:34` 的 `!*.md` 例外
才让报告进仓库）**不进仓库**——留在本分支的工作树里，路径见页首 `evidence:` 行。

## 一、现场：那 20 条是怎么拿到的

`gh` 未登录，用 curl + `.github-pat`（token 只从文件读进 shell 变量、只出现在请求头里，不落盘、不打印）：

```bash
curl -s  -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/Track07-cda/teamsmith/actions/runs?per_page=10"
curl -s  -H "Authorization: token $TOKEN" \
     "https://api.github.com/repos/Track07-cda/teamsmith/actions/runs/37214217522/jobs?per_page=20"
curl -sL -H "Authorization: token $TOKEN" \
     "https://api.github.com/repos/Track07-cda/teamsmith/actions/jobs/111472971239/logs" -o job.log
```

| run | head | 时段 | 计数 | 备注 |
|---|---|---|---|---|
| 37214217522 / job `111472971239` | `fc9c570d` | 15:54:47Z→16:34:55Z（40 min） | **✓4591 ✗20 SKIP3** | 任务书点的那一次（`账本自查： 123 段收口 · 增量 ✓4591 ✗20 SKIP3`，与结果行一致） |
| 37211955576 / job `111464774439` | `8b2e0fff` | 15:09:39Z→15:54:44Z | ✓4588 ✗23 | 多出来的 3 条是 §0i「树在跑动中被改」（发布那次 push 的过程中树在动）；**其余 20 条逐条相同** |
| 37221247842 | `726273b4` | 17:37:59Z→18:16:38Z | **✓4603 ✗19** | 发布后恢复 AGENTS.md/SCOPE.md 的那次；它跑时我本地已经量完，两者**逐条对上**（下） |

三次的 job 日志逐字节落进了证据目录（`evidence/ci-run1-8b2e0fff.job.log`、`evidence/ci-run2-fc9c570d.job.log`、
`evidence/ci-run3-726273b4.job.log`，sha256 前两位分别是 `450dc0fe…`、`dc39f908…`、`10adf64b…`），
三次的失败原文抄录在 `evidence/ci-run2-failures.txt`、`evidence/ci-run3-failures.txt`。

### run 3（`726273b4`）与本地复现的逐条对照

run 3 在我把报告写完的过程里跑完，正好当成一次**独立交叉验证**：`账本自查： 123 段收口 · 增量 ✓4603 ✗19 SKIP3`，
19 条与我在容器里重跑出来的**逐条同名同数**：

| 段 | run 3（公共 CI，job 111491871272） | 本地容器（干净 clone，同一枚镜像） |
|---|---|---|
| 19 | ✗10（5 个 prompt + 5 个 skill，名字逐个对上） | ✗10 |
| 31 | ✗1（`M28 真树有未隔离的 tmux 变更命令`） | ✗1 |
| 36 | ✗4（`36① --check 红：bad: 行 19 … .pi/skills` + 两条夹具基准 + `36⑧ … 4 条`） | ✗4（同一行号、同一四条） |
| 39 | ✗1 段（里面 `✓ 92 ✗ 5`，漂移行原文就是 `copy 0.1.0，与运行版本一致`） | ✗1 段（`✓ 92 ✗ 5`，同五条） |
| 41 | ✗2（`P55 ④ running` + 机器面 `state=exited`） | ✗2（同两条） |
| 58 | ✗1（`signal-lint: baseline —— docs/team/reports/M35-dev2/pkg/lib.sh`） | ✗1 |

（另：日志末尾那个 `Process completed with exit code 4`、`没有红，但有 2 条可见 SKIP → 没结论` 是
**步骤 7「Performance suite … non-blocking」**，该步骤在 GitHub 一侧是 success（设计上不拦）；拦住这个 job 的
只有步骤 4 里那 19 条。）

**失败现场没能带出容器**（两次都有这个病）：`gate-failure-scene` 工件里**只有锁文件** ——
run 2 的 285 字节、run 3 的 283 字节，解包开都是单独一份 `teamsmith-smoke.lock.tgz`，
`m28-lint.log` / `p159-lint.log` / `p55-roster.log` / 整个 `teamsmith-smoke.*` 根都**不在**（`evidence/ci-run2-failures.txt`、
`evidence/ci-run3-failures.txt` 里带着工件清单）。机制我看到两个候选但**没定下来**
（① 收藏步容器的 /tmp 里只剩锁，可能因为 gate 步结束后容器已停、或 ② smoke 根的清理时机），
本报告不断言是哪个——但结论不变：**CI 的红只能从日志与本地复现来定**，所以每一条我都在容器里重跑过，
没有一条只凭 CI 日志下结论。这也是一份给 PM 的待办：工件带不出失败现场，CI 一红就得靠人跑一遍。

## 二、20 条的红表（段号 / 断言原文 / 类 / 在 tip 的现状）

段号用 smoke 的段号；"判据"列给出「凭什么这么判」的锚点（文件:行）。类：① 内部前提缺失、
② 我们的排除/发布改写造成的、③ 真缺陷。

| # | 段 | 断言原文（逐字，路径已缩短） | 类 | 判据 | 现状 @`726273b4` |
|---|---|---|---|---|---|
| 1 | 18 | `✗ 扫描根存在（SCOPE.md）（缺 /work/SCOPE.md）` | ② | 发布改写把 SCOPE.md 丢了（`git ls-tree fc9c570d -- SCOPE.md` 空；`726273b4` 才恢复） | **已绿** |
| 2-6 | 19 | `✗ 本仓库为 Pi 生成了相位命令 opsx-{explore,propose,apply,verify,archive}（缺 /work/.pi/prompts/opsx-*.md）` | ① | `tests/lib/checkout-shape.sh:29,43-52`（六内部面之一即可判 internal）；`.gitignore:13,29`（`.pi/` 不进仓库） | **仍红** |
| 7-11 | 19 | `✗ 相位 skill openspec-{explore,propose,apply-change,verify-change,archive-change} 在位（…）（缺 /work/.pi/skills/*/SKILL.md）` | ① | 同上 + `smoke.sh:438-441`（跳过只在 product-only 形状生效） | **仍红** |
| 12 | 31 | `✗ M28 真树有未隔离的 tmux 变更命令（见 …/m28-lint.log）` | ② | `tests/tmux-lint-legacy.txt:14-31` 的 16 行指向 `docs/team/reports/*/pkg/**`，证据层不在仓库；`.gitignore:33-34` | **仍红** |
| 13 | 12k | `✗ 7.4 repo AGENTS.md 与模板逐字一致（模板是源）` | ② | 同一份改写把 AGENTS.md 丢了（日志里紧邻的 `awk: cannot open …/AGENTS.md`） | **已绿** |
| 14 | 36 | `✗ 36① --check 红：bad: 行 2 的字面模式在工作树里不存在：AGENTS.md` | ② | 同 #13（选择器要求字面模式在位，`section-paths.tsv:2` 声明 `AGENTS.md`） | 变成 ①：现在红在第 19 行 `.pi/skills` |
| 15 | 36 | `✗ 36① 副本表未改就红（夹具本身有问题）` | ② | 上一条的级联（负面夹具的基准自己就红了） | 同上（仍红） |
| 16 | 36 | `✗ 36① 变体树注入前就红了（夹具本身有问题）：…AGENTS.md` | ② | 同上 | 同上（仍红） |
| 17 | 39 | `✗ 39 install-shape.sh 有失败` + 里面 5 条 `✗`（`手改副本：默认 init 居然 0` / `冲突消息没给 --force 出路` / `漂移副本：warn 点名 0.0.1…` / `漂移修复后行不对` / `③ 对照：真实树漂移 warn`） | ② | `tests/install-shape.sh:480,549,606,608` 写死 `version: "1.42.0"`，发布改写把它变成 `0.1.0`（`SKILL.md:6`）→ `sed` 空转 | **仍红** |
| 18 | 41 | `✗ P55 ④：roster 四态 ① running（证明成立）`（`没有匹配 [^p55live +● .*在跑]`） | ③ | `smoke.sh:16437`（夹具用脚本形态的假 agent 当 pane 命令）+ `smoke.sh:16448`（断言） | **仍红** |
| 19 | 41 | `✗ P55 ④：机器面断言失败`（`p55live 不是 running+live：{'state': 'exited', …, 'pane': 'live'}`） | ③ | `scripts/lib/common.sh:1999-2016`（P210：前台是裸 shell 时只认直接子进程） | **仍红** |
| 20 | 58 | `✗ 58 lint 真树判红` + `✗ signal-lint: baseline —— docs/team/reports/M35-dev2/pkg/lib.sh：清单里的文件不在了` | ② | `tests/signal-lint-legacy.txt:14`（唯一一条数据行）指向证据层；`.gitignore:33-34` | **仍红** |

合计：**20 = ① 10（§19）+ ② 8（§18·§31·§12k·§36×3·§39·§58）+ ③ 2（§41）**。

**换到 tip `726273b4` 再量一次（同一枚镜像、同一份选段，干净 clone `/tmp/p214-clone`）：21 段 · ✓721 ✗19 SKIP1**
（`evidence/probe-container-select-tip.txt`）：

| 段 | tip 的收口 | 相对 run 2 |
|---|---|---|
| 18 | ✓36 ✗0 | **修好**（`726273b4` 补回 SCOPE.md） |
| 19 | ✓16 ✗10 | 不变 |
| 31 | ✓8 ✗1 SKIP1 | 不变 |
| 12k | ✓32 ✗0 | **修好**（同一个提交补回 AGENTS.md） |
| 36 | ✓106 **✗4** | −3（AGENTS.md 回来了）+**1（新红：⑧ 产品面检出探针，见下）** |
| 39 | ✓0 ✗1（段内 `✓ 92 ✗ 5`） | 不变 |
| 41 | ✓94 ✗2 | 不变 |
| 58 | ✓12 ✗1 | 不变 |

也就是 tip 上是 **19 条红**：§19(10) + §31(1) + §36(4) + §39(1) + §41(2) + §58(1)。
**那次恢复只拿掉了 2 条（§18/§12k），又露出 1 条（§36⑧）——公开仓的 CI 还是红的**（run 3 已证实：✗19）。

**新露出的那条（`✗ 36⑧ 产品面检出探针有失败（4 条）`）不是新缺陷，是 ② 的同一根因在探针里显形**：
```
bad: ⑨ 内部树 --select 12k,31 退出 0（期望 [0]，实际 [1]）
bad: ⑨ 内部树：§31 的 M28 lint 照旧跑（带豁免清单）（[ … 里找不到 [M28 真树：变更类 tmux 调用全部有隔离证据]]）
bad: ⑩ 内部树 --select 58 退出 0（期望 [0]，实际 [1]）
bad: ⑩ 内部树：豁免清单照旧逐条核对（M35-dev2 的 pkill 包记 LEGACY）
```
机理：`checkout-shape-probe.sh:359` 把"内部树控制"挂在一个前提上，
`[ ! -f "$REAL_ROOT/AGENTS.md" ] || [ ! -d "$REAL_ROOT/docs/team/reports" ] → pskip`：`fc9c570d` 时 AGENTS.md 不在，
这条控制**整条被可见跳过**（所以 run 2 的 §36 只有 3 条红）；`726273b4` 补回 AGENTS.md 后它真的跑起来，
而在公开检出里 §31/§58 的豁免清单冻的 17 个证据包按构造不在位 → 内部树那一侧确实红 → 探针自带的
"内部树必须照旧逐条核对"的两条断言应声失败。**这四条与 §31/§58 是同一条根因**（P148 的救生通道只在
`product-only` 上开），只是这回红在探针自检里。

**为什么本地门禁没有先看见这些**（账本里就有，不用推测）：本地复验常用
`TEAM_SMOKE_FAST=1 smoke.sh --select <key>`（AGENTS.md 的口径；P211 的复验记录就是这么写的），而 FAST 把
§41 整段跳过（`smoke.sh:16348-16350`）；其余几段在账本里也已经有 FAST 的账：
`docs/team/reports/P211-dev/gate-full-fast-tip.summary.log`（tip `6b2413fc`）写着
`#73 19 ✗10`、`#85 31 ✗1`、`#99 36 ✗3`、`#102 39 ✗1`、`#121 58 ✗1`（那一拍 §18/§12k 也各 ✗1）——
也就是**发布之后本地跑法本来就是红的**；不在那次选段里、也不在 FAST 里的 §41，连红的影子都看不到。
P210（引入 §41 那条回归的提交 `55326ee4`）的证据面也印证这一点：提交信息只写
"section 6k is 21 ok / 0 red and flip-p210 reproduces the flip"，`docs/team/reviews/P210.md` **不存在**，
`docs/team/reviews/P210-done.md` 记的是"FORCED：PM 显式覆盖"。

## 三、逐类定性

### ① 内部前提缺失（10 条，§19）——判据是"哪条清单判它是内部树"

公开仓的检出**不是产品面检出，也不是标准的内部检出，而是两者的混合**：账本的可读层（`docs/team` 1222 个
跟踪文件（加本报告就是 1223）、`openspec/changes` 279 个）已经进仓库，`AGENTS.md`/`SCOPE.md` 在 `726273b4` 之后也在；而 `.pi/`
按 `.gitignore:29` 永远不在任何检出里。形状判据只认"六面全无 = 产品面"：

- `skills/teamsmith/tests/lib/checkout-shape.sh:29` — `CHECKOUT_INTERNAL_SURFACES=(docs/team openspec/changes AGENTS.md SCOPE.md .pi/prompts .pi/skills)`
- 同文件 `:43-52` — `checkout_shape()`：六面**任一**存在（空目录/坏软链也算）→ `internal`
- 同文件 `:64-68` — `checkout_prereq_missing()`：只有 `product-only` 才允许按前提缺失跳过
- `skills/teamsmith/tests/smoke.sh:90-91` — 形状按"脚本所在树"算；`:438-441` — `smoke_prereq_absent()` 把两件事一起要求

实测（`evidence/probe-checkout-shape.txt`，在 `726273b4` 的树上跑同一份函数）：

```
shape=internal
  docs/team        present      openspec/changes present
  AGENTS.md        present      SCOPE.md         present
  .pi/prompts      absent       .pi/skills       absent
  .pi/prompts/opsx-apply.md    internal  prereq=judge  literal=judge
  .pi/skills                   internal  prereq=judge  literal=judge
```

于是十条断言走向 `assert_file` 而不是 `prereq_skip`（`smoke.sh:9614-9626` 的两个 for 循环）。

**这不是"键写错了"，是前提本身在公开检出里不可满足**：`.pi/prompts/opsx-*.md` 与 `.pi/skills/openspec-*/SKILL.md`
是 `openspec init --tools pi` 在**本机**生成的（README.md:125 就是这么写的），而 `.pi/` 被忽略 → 任何 clone、
任何 CI 检出都不可能有它们。反过来，同一份协议文本（`AGENTS.md` 的 OpenSpec 段）把这两处当成项目的
*必需依赖*——它说的是"你的项目要先跑 `openspec init --tools pi`"，而不是"这个仓库里必须有这两处的副本"。

**顺带一个更要紧的发现（会决定修法）**：钉住的那版 openspec **根本生成不出 verify 那一对**。

```
$ openspec --version            # 容器里，与 ci/Containerfile 的 OPENSPEC_VERSION=1.8.0 一致
1.8.0
$ openspec config profile expanded
Error: Unknown profile preset "expanded". Available presets: core
$ openspec config list | tail -3
  workflows: propose, explore, apply, update, sync, archive (from core profile)
```

`openspec init --tools pi` 在一个干净检出里生成 6 个 prompt + 6 个 skill（`opsx-{explore,propose,apply,archive,sync,update}`），
**没有 `opsx-verify`**，也没有 `openspec-verify-change`（`evidence/probe-openspec-init-tools-pi.out`）。
也就是说：即使把 CI 改成"先跑 `openspec init --tools pi`"，十条里也还有 2 条（verify 那一对）不可能绿；
而 `references/openspec.md:35` 与 `README.md:125` 仍写着五个相位命令"由 `openspec init --tools pi` 生成"——
**这句话在 pin 1.8.0 上已经不成立**。

### ② 我们的排除/发布改写造成的（8 条：§18、§31、§12k、§36×3、§39、§58）

**(a) 发布改写丢了两个文件（§18、§12k、§36×3；`726273b4` 已修回其中 2 条）**

```
$ git ls-tree -r --name-only 8b2e0fff -- AGENTS.md SCOPE.md | wc -l   → 0
$ git ls-tree -r --name-only fc9c570d -- AGENTS.md SCOPE.md | wc -l   → 0
$ git ls-tree -r --name-only 726273b4 -- AGENTS.md SCOPE.md | wc -l   → 2
```
§36① 的三条是同一根因的三重表现：选择器 `--check` 要求映射表里的**字面模式**在工作树里存在，
第 2 行是 `AGENTS.md`（`section-paths.tsv:2`）→ 文件不在 → 真树 `--check` 红 → 两个"负面夹具的基准"
（"副本表未改也该绿"、"变体树注入前该绿"）跟着红。这三条**没有随恢复消失**，只是换了行号：
现在真树 `--check` 红在**第 19 行**（`bad: 行 19 的字面模式在工作树里不存在：.pi/skills`，
见 `evidence/probe-selector-check.txt` 与容器运行），根因换成 ① 的 `.pi/` 前提。

**(b) 豁免清单指向刻意不进的证据层（§31、§58；仍红）**

```
$ git ls-files docs/team/reports/M35-dev2/pkg/lib.sh | wc -l           → 0
$ git ls-files docs/team/reports | wc -l                                  → 288（全部是 .md；非 .md 的 0 份）
$ git ls-files docs/team/reports | grep -vc '\.md$'                       → 0（证据层一份都不在仓库里）
$ git check-ignore -v docs/team/reports/M35-dev2/pkg/lib.sh
.gitignore:33:docs/team/reports/**	docs/team/reports/M35-dev2/pkg/lib.sh
```
`signal-lint-legacy.txt:14` 是唯一一条数据行；`tmux-lint-legacy.txt:14-31` 是 16 条数据行，全部落在
`docs/team/reports/*/pkg/**`。清单是"按 sha256 冻结的账"，文件不在就判"清单过期"（红是**设计**）。
`smoke.sh:13001` 与 `:19293` 各有一段 P148 的救生通道（换成空清单跑 + 一次可见 SKIP），但它的门槛是
`[ "$CHECKOUT_SHAPE" = "product-only" ]`——公开检出是 internal，通道不触发。

**这两条红不是"真泄漏"**：同一棵树、同一份 lint、换成空清单：

```
$ perl skills/teamsmith/tests/tmux-lint.pl                       → rc=1，16 条 baseline 过期
$ perl skills/teamsmith/tests/tmux-lint.pl --legacy /dev/null     → rc=0  干净（扫描 68 个脚本，194 条变更命令全部有隔离证据）
$ perl skills/teamsmith/tests/signal-lint.pl                      → rc=1，1 条 baseline 过期
$ perl skills/teamsmith/tests/signal-lint.pl --legacy /dev/null   → rc=0  干净（扫描 96 个脚本）
```
（`evidence/lint-tmux-real-list.out`、`lint-tmux-empty-legacy.out`、`lint-signal-*.out`）

**(c) 发布改写把版本号 1.42.0 → 0.1.0，夹具的 sed 锚点空转（§39；仍红）**

`tests/install-shape.sh` 有 4 处（`:480,549,606,608`）用同一句把"已装副本"改成漂移版：

```bash
sed -i 's/^  version: "1\.42\.0"/  version: "0.0.1"/' "$p/.pi/skills/teamsmith/SKILL.md"
```

发布改写后源树里是 `metadata.version: "0.1.0"`（`skills/teamsmith/SKILL.md:6`，同一个值在 `package.json:3`），
所以这句 sed 什么都不改：副本**没有被改坏** → `init` 认为"认得出的副本，无冲突"→ rc=0（断言 1 红）；
冲突消息里自然也没有 `--force` 出路（断言 2 红）；doctor 读出的是"（copy 0.1.0，与运行版本一致）"→ 没有 warn
（断言 3 红），后面两条是它的下游（断言 4、5 红）。5 条红只剩 1 个根因，且**红侧那条更危险**：
`flip ③` 的"把 doctor 的 warn 静默掉"现在"红"得莫名其妙（因为 sed 空转就已经红了），
**那个红侧现在是橡皮章**——它绿不了也说明不了任何事。

### ③ 真缺陷（2 条，§41）——P210 的判据与 §41 的夹具互相矛盾

两条红是同一个现象的两面：`p55live` 这个"活着的席位"被读成 `state=exited`（roster 不显示"在跑"，
机器面给了 `'state': 'exited', 'pane': 'live'`）。

机制（在钉住的容器里用同一份 `common.sh` 的函数实测，`evidence/probe-p55-pane.out`）：

```
p55live pid=3056966 cmd=bash dead=0            # 夹具：tmux new-window -d … "$FAKE/p55-agent"
3056966 3056947 bash /tmp/p214probe-fake/p55-agent
3056972 3056966 sleep 120
team_is_shell_cmd(bash)              → 是（裸 shell）
team_proc_cmdline_is_bin(pane_pid)   → 命中（agent 路径就在 pane_pid 的命令行里！）
直接子进程 3056972                   → 不命中（sleep 120）
```

`scripts/lib/common.sh:1999-2016`（P210，提交 `55326ee4`）的规则是：前台命令是裸 shell →
**只认直接子进程**，pane_pid 自己的命令行不算证据。这条规则针对的是"启动壳/遗留壳的 argv 里读到
agent 路径"的假活（P103：dev-bob 的遗体 pane 被算成在跑，PM 26 小时没被叫醒）——它是对的，
但它把"agent **本身**就是一个以 shell 跑的脚本"也一起否掉了：`#!/usr/bin/env bash` 的 agent 直接当
pane 命令时，pane_pid 是那个 bash，`pane_current_command` 就是 `bash`，它唯一的子进程是 `sleep`。
`smoke.sh:16437` 的夹具正是这个形状，`smoke.sh:16448/16474` 断言它是"在跑"。

**这是真缺陷，不是前提问题**：判据的输入（pane、进程树）都在，两侧说的却是相反的结论；
`TEAM_AGENT_BIN` 的契约是"任意 TUI agent"（`references` 里的 adapter 章），一个 shell 包装脚本是合法配置。
两边都可能是"错"的那一边，所以我把**四种启动形状**在容器里一个一个量了出来
（`evidence/probe-p55-shapes.out`）：

| 形状 | pane_pid 的 argv | 直接子进程 | P210 判成 |
|---|---|---|---|
| ① 夹具现状：pane 命令 = agent 脚本 | `bash /tmp/…/p55-agent`（argv[1] 就是 agent） | `sleep 300` | **exited** |
| ② 外面套一层 `bash -lc <agent>` | `bash /tmp/…/p55-agent`（**一样**） | `sleep 300` | **exited** |
| ③ `bash -lc '<agent> & wait'` | `bash -lc /tmp/…/p55-agent & wait` | `bash /tmp/…/p55-agent` ✓ | running |
| ④ `bash -lc '<agent>; :'`（生产 harness 的形状） | `bash -lc /tmp/…/p55-agent; :` | `bash /tmp/…/p55-agent` ✓ | running |

两条要点：

1. **② 与 ① 逐项相同** —— bash 对 `-c` 的**最后一条命令**会直接 `exec`，所以"外面套一层 shell"
   **一点用都没有**（我先试了这条修法，实测 §41 仍是 ✓94 ✗2，`evidence/probe-fix41-fixture-shape-patched.out`）。
   真正起作用的不是"有没有 shell"，而是"**agent 是不是 pane_pid 的直接子进程**"。
2. 生产里 agent **永远是子进程**：dispatch 走 `respawn-pane … bash -lc <harness>`，而 harness 在 agent
   前后都有语句、末尾还 `exec bash`（`scripts/lib/cmd-agents.sh:1288-1300`）——所以"夹具现状"那个形状
   在生产里不会出现；能出现它的是**人工在座位窗口里直接起 agent**。

`common.sh` 的判据（`:1999-2016`）是：`pane_dead=1` → 先判死（P103 的遗体洞已经先堵住了）；
否则"前台是裸 shell → 只看直接子进程"。而匹配器 `team_proc_cmdline_is_bin`（`:1746-1771`）
是**整串 argv 逐 token 比 basename**——所以 P210 的红侧夹具
（`flip-p210.sh:117`：`bash --noprofile --norc -s "$AGENT"`，agent 路径在 argv[4]）会因为"argv 里提到了
agent 路径"而假活。**危险的不是"argv 提到 agent"，而是"argv 里那个 token 只是提到它"**：
`bash <agent>`（argv[1] 就是那个脚本）的语义**就是"跑这个脚本"**，两者可以分开。

### 顺带发现（不在那 20 条里，但下次会坑人）：§41 的 `needs` 是空的

跑修法验证时发现的：`smoke.sh --select 41`（不带别的段）会得到 **✓36 ✗67**，根因与 P210 无关 ——
夹具要的 `$REPO/.pi/team/state/` 是由 §2 init 建的，而映射表里 §41 的 `needs` 是 `-`
（`section-select.sh --list`；对比 §4 写了 `needs=2`）。所以单独选 §41 会大量空跑：
`T9.55-brief.md: No such file or directory` → 派单失败 → 后面 60 多条级联。
CI 跑全量时 §2 在，看不见；但它让"只跑这一段"的复验/诊断跑不通。
（实测：`evidence/probe-41-unpatched-baseline.out`（`--select 41`）与 `evidence/probe-fix41-fixture-shape.out`
前半段（`--select 2,41`）；两个失败的 §41 与大选段里 ✓94 ✗2 的 §41 是同一个夹具、同一枚镜像，
区别只在前面跑过哪些段。）

## 四、修法建议（只写不做得）与量化

### ① §19（10 条）+ §36①（1 条根因）：把"机器生成的内部面"单列一类

最小改动：在共用的形状判据里加第三个类别（**机器生成面**），只影响 `.pi/prompts/**`、`.pi/skills/**`：

| 文件 | 改动 | 量 |
|---|---|---|
| `skills/teamsmith/tests/lib/checkout-shape.sh` | 新增 `CHECKOUT_GENERATED_SURFACES=(.pi/prompts .pi/skills)` + 一个 `checkout_generated_absent <rel>`（内部面里"由工具在本机生成、永不进 git"的那两个），`checkout_prereq_missing`/`checkout_literal_skippable` 各加一行放行 | +约 12 行，1 个文件 |
| `skills/teamsmith/tests/smoke.sh` | 什么都不用改（§19 已经在调 `smoke_prereq_absent`），除非要给 SKIP 文案标注"生成面" | 0–2 行 |
| `skills/teamsmith/tests/checkout-shape-probe.sh` + §36⑩ | 加一个钉住的口径：`AGENTS.md`/`SCOPE.md`/`docs/team`/`openspec/changes` **缺席照旧红**（新的放行面不许把它们吞掉） | +1 个用例 |

**已实测（只在 /tmp 副本上，仓库未动；`evidence/probe-fix19-generated-surface.out`）**：上面那 14 行补丁在 pin 住的容器里跑出——
```
形状矩阵：.pi/skills / .pi/prompts/** 两种形状都 skip；AGENTS.md / SCOPE.md 在 internal 里照旧 judge
选段器 --check：SKIP（条件不满足）: 行 19 … : .pi/skills   · ok 7 bad 0 SKIP 1 · rc=0
smoke --select 19：✓16 ✗0 SKIP10（十条从 ✗ 变可见 SKIP）
smoke --select 18,12k（负面对照）：✓90 ✗0（这两段没被放行）
```

代价：公开仓 CI 里这十条变成**可见 SKIP**（"跳过不是通过"），公开仓的 CI 就不再检验相位命令是否装了——
这是老实话：公开检出里本来就没法检验本机生成物。

**另一条路（不是替代，是补在前面）**：CI 在跑门禁前真的把前提造出来。实测 `openspec init --tools pi`
在一个可写副本里只给 **4/5 对**（没有 verify），而且会新写 `openspec/config.yaml`；要让 verify 也在，
要么钉一版还有 verify 的 openspec，要么把 verify 那一对作为 teamsmith 自己的模板发出去。
**这条要与规格对齐**：`AGENTS.md` 的 OpenSpec 段和 `references/openspec.md:35` 现在都断言
"`openspec init --tools pi` 生成五个相位命令"——在 pin 1.8.0 上这句是假的。改它属于规格/契约层（PM）。

### ② §31、§58（各 1 条）：让"豁免清单的前提"自己可判

这两处的 `prereq_skip` 通道已经写好了（空清单 + 一次可见 SKIP，`smoke.sh:13001-13012`、`19293-19302`），
只是门槛写成"整棵树是产品面"。题设的条件应该换成"**清单里每一条的前提都不在这棵检出里**"：

| 文件 | 改动 | 量 |
|---|---|---|
| `skills/teamsmith/tests/lib/checkout-shape.sh` | 新增 `checkout_registered_paths_absent <root> <list-file>`（逐行读 `<sha> <n> <路径>`，任一条在位就返回 1） | +约 10 行，1 个文件 |
| `skills/teamsmith/tests/smoke.sh:13001`、`:19293` | 门槛从 `[ "$CHECKOUT_SHAPE" = "product-only" ]` 换成 `[ "$CHECKOUT_SHAPE" = "product-only" ] \|\| checkout_registered_paths_absent …`（两处各 1 行） | 2 行 |
| `skills/teamsmith/tests/smoke.sh` §36 的两条牙齿（`P159_LEGACY_*`、`M28_LEGACY_*` 的反向夹具） | 加一条"清单里只要有一条**产品面**路径在位 → 照旧用原清单跑、缺了就红"的钉法 | +1 个用例 |
| `skills/teamsmith/tests/checkout-shape-probe.sh` | §36⑧ 的四条随之转绿（内部树的那两条保留原有的牙：里面的 `AGENTS.md` 是夹具自己造的、不在位的前提不存在），只补一条"内部树 + 账不在位 → 可见 SKIP" | +1 个用例 |

代价：公开仓 CI 里 §31/§58 各记一次 SKIP（"这一册账在检出里无法裁决"），产品文件上的 194 条
变更命令与 96 个脚本的判定**照旧跑**（已实测：空清单下 rc=0 且扫描量不变）。
在**开发树**（证据层在）里什么都不变：清单在位 → 照旧逐条核对。

### ② §39（1 段 / 5 条断言）：锚点不要写死版本

| 文件 | 改动 | 量 |
|---|---|---|
| `skills/teamsmith/tests/install-shape.sh:480,549,606,608` | `s/^  version: "1\.42\.0"/` → `s/^  version: "[^"]*"/`（或从 `$tree/skills/teamsmith/SKILL.md` 读出版本再拼锚点）；每处都在 sed 后加一行"断言文件真的变了"，锚点再漂就当场红 | 4 行（+ 4 行自检），1 个文件 |

**已验证**（只在 /tmp 副本上，仓库未动；`evidence/probe-fix39-version-anchor.out`）：

```
源版本 = 0.1.0；4 处锚点已替换
$ bash skills/teamsmith/tests/install-shape.sh
== 结果 ==  ✓ 97  ✗ 0  SKIP 0          # CI 现场是 ✓ 92 ✗ 5
```

### ③ §41（2 条）：判据要的是"argv[1] 就是那个 agent"，不是"argv 里提到它"

两个修法，都只动 1 个文件（**要 PM 裁决**；两者的分岔点是：人工在座位窗口里直接起一个脚本型 agent，
算不算"在跑"）：

**(A′) 把 P210 的判据改准（我倾向这条）**：`pane_pid` 算证据的条件从"前台不是裸 shell"改成
"**它正在执行的命令**就是 agent"——`argv[1]` 逐字等于 agent 路径（`bash <agent>` 的语义就是跑它）；
"agent 路径只出现在别的 argv 里"（启动壳的 `-s <agent>`、harness 的 `-c` 脚本正文）一律不算。

| 文件 | 改动 | 量 |
|---|---|---|
| `scripts/lib/common.sh` | 新增 `team_proc_executing_bin <pid> <bin>`（读一次 `ps -o args=`，`argv[1]` 的 basename 等于 bin 的 basename；`dispatch-*.spawn` 照旧排除），`team_agent_alive_in_pane` 的 shell 分支改成"先按它找（scope=all），再退回 children" | +约 10 行 |
| `tests/flip-p210.sh` | 红侧保留（`-s <agent>` 那种 shell 不算）；**新增绿侧**"`bash <agent>`（argv[1] = agent、子进程只有 sleep）算 alive"，否则收紧没有钉子 | +1 个用例 |
| `skills/teamsmith/tests/smoke.sh` §41 | 不用改（夹具现状就是它钉的形状） | 0 行 |

**(B′) 把夹具改成生产形状**（**已实测能让 §41 从 ✗2 变 ✗0**）：`smoke.sh:16437` 改成 ③ 或 ④ 那种
（agent 当**直接子进程**；注意②那种"套一层 `bash -lc`"实测无效）。

| 文件 | 改动 | 量 |
|---|---|---|
| `skills/teamsmith/tests/smoke.sh:16437` | `"$FAKE/p55-agent"` → `bash -lc "$FAKE/p55-agent & wait"`（或 `…; :`），并在上面一行注明"生产里 agent 永远是 pane_pid 的子进程（`cmd-agents.sh:1293-1299`）；bash 会 exec 掉 `-c` 的最后一条命令，所以必须先加一层 shell 再把它变成子进程" | 1 行 + 注释 |
| `tests/flip-p210.sh` | 补一条"pane 命令直接就是 agent 脚本、且没有 agent 子进程 → 不算在跑"（把①那个形状钉成**有意为之**，不是漏判） | +1 个用例 |

实测（`evidence/probe-fix41-subchild-shape.out`，同一份 `--select 12k,18,19,31,39,41,58`）：

```
改动前： #19 41 · ✓94 ✗2（整段选跑 ✗15）
改动后： #19 41 · ✓96 ✗0（整段选跑 ✗13）     ← 产品代码零改动，P210 判据原样
```

代价（两者共同的分岔点）：A′ 多一条产品侧判据，改变了 roster/status/pulse 的读数面（按本仓库的
纪律应当走一次规格/changeProposal，并在 `flip-p210.sh` 上补红/绿钉子）；B′ 不改产品，但**从此人工在
座位窗口里直接起的脚本型 agent 会被读成"已退出"**（错方向的报告同样会让 pulse 做出错的裁决）。

我的建议：**A′ 与 B′ 一起做**（A′ 是判据的根因修复，B′ 把夹具对齐到生产形状，两条各自都要能红）——
但这是产品侧的行为决定，交回 PM/规格层。

## 五、跑过的门禁、没跑的、以及为什么

- **没跑全量**（任务书第 5 条明确写了不跑）：本条的产物是定性，不是实现；全量约 49 分钟且会占机器锁。
- **跑了的**（都是只读）：
  1. 钉住容器里的选段运行（8 段，与 CI 同一枚镜像、同一个 `--keep`、同一个 `/work` 形状）：
     `bash docs/team/reports/P214-dev/run-select.sh /tmp/p214-clone /tmp/p214-scene3 '12k,18,19,31,36,39,41,58' p214-run-b`
     —— 对一个**干净 clone**（`/tmp/p214-clone`，tip `726273b4`）跑，与 CI 的检出形状一致；
     收口 **21 段 · ✓721 ✗19 SKIP1**，逐段与红行原文在 `evidence/probe-container-select-tip.txt`；
     （第一次跑直接挂在自己的 worktree 上，§0d 因为它是 linked worktree（`.git` 指到主仓）而假红一条，
     已改成挂 clone，不算在结论里）；
  2. 宿主上的纯逻辑：`section-select.sh --check`、形状函数矩阵、两份 lint（真清单 / 空清单）；
  3. 容器里的 6 个探针（两个只在 /tmp 副本上打补丁，仓库字节未动）：
     `probe-checkout-shape`（形状函数矩阵）、`probe-p55-shapes`（四种启动形状的进程树与判据）、
     `probe-openspec-init-tools-pi`（`openspec init --tools pi` 生成物与污染面）、
     `probe-fix39-version-anchor`、`probe-fix19-generated-surface`、`probe-fix41-fixture-shape`。
- **③（§41）的复现命令**（PM 可逐条跑；两者都在钉住的容器里）：

```bash
# ① 机制：四种启动形状的进程树 + P210 判据各判成什么（十几秒，只读）
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
  -v "$PWD":/wt:ro -v /tmp/p214-clone:/work:ro -w /work localhost/teamsmith-gate:local \
  bash -c 'git config --global --add safe.directory /work; bash /wt/docs/team/reports/P214-dev/probe-p55-shapes.sh'
# ② 端到端：那两条红与修法（需要 /tmp/p214-clone = tip 的干净 clone；约 5.5 分钟）
bash docs/team/reports/P214-dev/probe-fix41-fixture-shape.sh /tmp/p214-clone 12k,18,19,31,39,41,58
```
- **没跑 `openspec validate --all --strict`**：与本条无关（它判的是 `openspec/specs/**` 这一册契约，
  CI 的那一半在三次 run 里都过了——`validate && smoke` 是串联的，smoke 跑到了就说明 validate 过了）。本报告不动规格。
- **没做的事**：没有改实现、没有改 `.github/workflows/**`、没有推公开仓、没有往仓库里补证据层文件。

## 六、翻转证据（本条不实施，用候选修法的"红 → 绿"实测代替）

本条是**定性**，没有实现可以"破坏再恢复"。等价物是：对每个候选修法，在 /tmp 副本上先量红、再量绿，
并用反向对照确认没有把该红的放行。三处实测：

| 候选修法 | 红（改之前） | 绿（改之后） | 反向对照 |
|---|---|---|---|
| ① 形状判据加"机器生成面"（14 行，`checkout-shape.sh`） | `smoke --select 19`：**✗10** | `smoke --select 19`：**✓16 ✗0 SKIP10**（十条变可见 SKIP）；选段器 `--check`：`bad: 行 19 … .pi/skills` → `SKIP（条件不满足）…`、`ok 7 bad 0`、rc=0 | `smoke --select 18,12k`：改动前后都是 **✓90 ✗0**（`AGENTS.md`/`SCOPE.md` 的缺席照旧红）；形状矩阵里 `AGENTS.md`/`SCOPE.md`/`docs/team` 在 internal 里照旧 judge |
| ② §39 的版本锚点（4 处，`install-shape.sh`） | 整份 `install-shape.sh`：**✓92 ✗5** | **✓97 ✗0**（同一份夹具、同一枚镜像） | 锚点改法与夹具自检同源：漂移夹具仍是把副本写坏再断言 warn（不是把断言删掉）——`evidence/probe-fix39-version-anchor.out` |
| ③ §41 的夹具形状（1 行，`smoke.sh:16437`） | `--select 12k,18,19,31,39,41,58`：`#19 41 ·` **`✓94 ✗2`**（整段选跑 ✗15） | 改成 `bash -lc '<agent> & wait'`（agent 当直接子进程）后 `#19 41 ·` **`✓96 ✗0`**（整段选跑 ✗13）——**产品代码一个字节没动**，P210 的判据原样（`evidence/probe-fix41-subchild-shape.out`） | **反例（也算翻转）**：只加一层 `bash -lc <agent>` 时 `#19 41 · ✓94 ✗2` 一模一样——判据要的不是"有 shell"，是"agent 是子进程"（`evidence/probe-fix41-fixture-shape-patched.out`） |

\#41 那一行还带了四个形状的进程树实测（`evidence/probe-p55-shapes.out`）：

```
① pane 命令 = agent 脚本          pane_pid=bash /tmp/…/p55-agent   子=sleep 300        → exited
② 外套一层 bash -lc <agent>       pane_pid=bash /tmp/…/p55-agent   子=sleep 300        → exited（与①逐项相同）
③ bash -lc '<agent> & wait'        pane_pid=bash -lc …            子=bash …/p55-agent → running
④ bash -lc '<agent>; :'（同③语义） pane_pid=bash -lc …            子=bash …/p55-agent → running
```

## 七、逐条判据的反证（能推翻的都试过）

| 判据 | 反证/翻转 | 结果 |
|---|---|---|
| §19 的十条是"形状 + 前提"问题，不是"文件写错" | 用同一份 `checkout_shape`/`checkout_prereq_missing` 喂四组输入：product-only 全 skip，internal 全 judge（`evidence/probe-checkout-shape.txt`） | 与结论一致 |
| §31/§58 的红全是"账过期"而不是真泄漏 | 同一棵树换空清单跑：`rc=1` → `rc=0`，且扫描量不变（68 脚本/194 变更命令、96 脚本） | 与结论一致 |
| §39 的红是锚点写死版本 | 只把 4 处锚点改成版本无关，同一份 `install-shape.sh`：`✓92 ✗5` → `✓97 ✗0` | 与结论一致 |
| §19/§36① 的修法（给形状判据加"机器生成面"） | 只在 /tmp 副本上打 14 行补丁：§19 `✗10` → `✓16 ✗0 SKIP10`；选段器 `--check` 的 `bad: 行 19` → 可见 SKIP、rc=0；负面对照 §18/§12k 仍 ✓90 ✗0 | 与结论一致 |
| §41 不是"路径写错/没装上" | 探针里 `team_proc_cmdline_is_bin(pane_pid)` **命中** agent 路径，却被 P210 的 scope 排除；子进程只有 `sleep` | 与结论一致 |
| §41 的"agent 必须是子进程" | 四种启动形状逐个量：①（夹具现状）与②（外套一层 `bash -lc`）**逐项相同**（bash `exec` 最后一条命令）；只有③/④ 那种 agent 当直接子进程的形状才判 running（`evidence/probe-p55-shapes.out`） | 与结论一致（也推翻了我第一次的修法猜测） |
| §41 的红与本次改动无关 | 同一份 `--select 12k,18,19,31,39,41,58`：未改的 clone 与改了夹具的副本都是 `#19 41 · ✓94 ✗2`（同两条） | 与结论一致 |
| §41 单独选跑是红的（`needs` 缺口），不是 P210 的锅 | 未改的 clone 上 `--select 41` 与 `--select 2,41` 都是 ✓36 ✗67（`T9.55-brief.md: No such file or directory` 起头） | 与结论一致 |
| §18/§12k 已被 `726273b4` 修回 | 容器选段运行里 §18 `✓36 ✗0`、§12k `✓32 ✗0`（含 `7.4 repo AGENTS.md 与模板逐字一致` ✓） | 与结论一致 |
| 本报告的 19 条与公共 CI 自己在 tip 上的读数一致 | run 3 的 `账本自查 ✓4603 ✗19` 与本地容器（同一枚镜像、干净 clone）逐段逐条对上（见第一节的表） | 与结论一致（独立交叉验证） |

## 八、给 PM 的下一步

1. **§18/§12k 不用再管**（`726273b4` 已修回）。**§36 在 tip 上是 4 条红**：①②③ 的根因从 `AGENTS.md` 换成了
   `.pi/skills`（与 §19 同一处，已验证 14 行补丁能让它变可见 SKIP、选段器 `--check` 回到 rc=0），
   ④ 是 §36⑧ 的四条，与 §31/§58 同根因。
2. **一份"公开仓 CI 要绿"的最小清单**（按代价从低到高）：§39 的 4 行锚点（②，1 文件，已实测
   `✓92 ✗5 → ✓97 ✗0`）→ §19/§36 的生成面类别（①，1–3 文件，已实测十条变可见 SKIP）→ §31/§58 的门槛 + 反向钉
   （②，2 文件，红→净已在同一棵树上实测）→ §41 的 A′/B′ 二选一（③，1 文件，要裁决）。
3. **两个要 PM/规格层决定的事**：
   - pin 1.8.0 不再生成 `opsx-verify` 那一对，而 `AGENTS.md` 的 OpenSpec 段与 `references/openspec.md:35`
     仍断言五条命令由 `openspec init --tools pi` 生成——在 pin 上是假的，要么改契约文案，要么把 verify 那一对
     收进 teamsmith 自己的模板。
   - §41 的 A′（改产品判据）会让 roster/status/pulse 的读数面多一种"算在跑"的形状，按本仓库纪律应当先过规格。
4. **一条与本次无关的豁口**（顺手记下）：§41 的 `needs` 是空的，单独 `--select 41` 会 ✓36 ✗67（见上面的
   "顺带发现"）。
5. **BLOCKED 无**：本报告只给修法不实施；四个候选修法都落在 `skills/teamsmith/{tests,scripts}/**` 与
   `common.sh`（dev 的归属内，但要每次明确授权）。
