# P130 · CI 结构性省额度（paths-ignore + 只构建一次镜像）

agent: dev   status: done   time: 2026-09-29T17:56Z
branch: `task/P130-ci-paths-ignore`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev`，PM 复验后本地合并）

change: -（无 change）· anchor: none (infra) —— 只改 `.github/workflows/gates.yml` 的触发条件与作业拓扑，不改产品行为与门禁语义
deltas: -

## Deliverables

| Path | What |
|---|---|
| `.github/workflows/gates.yml` | **A**：`on.push.paths-ignore: ['docs/**']` —— 纯文档/账本 push 不再触发；**B**：perf 作业合并进 `gates` 作业（`continue-on-error: true` 的步骤），一次运行只 `docker build` 一次 |
| `docs/team/reports/P130-dev/pkg/**` | 静态证明与翻转夹具（`run.sh` 一条命令复现，末行 `== P130 结果 ==`；不触发 CI、不改真文件） |
| `docs/team/reports/P130-dev/pkg-run.log` | `pkg/run.sh` 的完整输出存档 |
| `docs/team/reports/P130-dev/gate-full.log` | 本地全量门禁日志（`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`） |

提交（分支 tip 见 `git log`）：

```
8b893fe5 docs(P130): executable evidence package for the CI trigger matrix and single-build topology
331c6d6d ci(P130): let docs-only pushes skip CI, and build the gate image once per run
（+ 本报告与上述两份日志）
```

改动逐字：`git diff main...HEAD -- .github/workflows/gates.yml` 只有两处 —— `on.push` 里加了 `paths-ignore: - 'docs/**'`（+ 注释），以及把第二个 `perf:` 作业收进 `gates` 作业末尾的步骤（删除重复的 Checkout/Build，perf 保持 `continue-on-error: true`）。正确性步骤、失败现场收集/上传步骤、`permissions`、`concurrency` 一字未动。

## A · `paths-ignore` 触发矩阵

判定依据（GitHub 官方文档，逐字）：

> When all the path names match patterns in `paths-ignore`, the workflow will not run. If any path names do not match patterns in `paths-ignore`, even if some path names match the patterns, the workflow will run.
> —— <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>（"Example: Excluding paths"）

> If you define both `branches`/`branches-ignore` and `paths`/`paths-ignore`, the workflow will only run when both filters are satisfied. / Path filters are not evaluated for pushes of tags.
> —— 同页（`on.<push|pull_request|pull_request_target>.<paths|paths-ignore>`）

| # | 改动路径（一次 push 的**全部**改动文件） | 触发? | 判定依据 |
|---|---|---|---|
| 1 | `docs/team/BOARD.md` | **不触发** | 全部文件命中 `docs/**` → 文档规定「will not run」 |
| 2 | `docs/team/reports/P130-dev.md` | **不触发** | 同上（嵌套任意深度都由 `**` 覆盖） |
| 3 | `skills/teamsmith/scripts/team` | **触发**（反例①） | 未命中 `docs/**` → 「will run」；这正是门禁本身 |
| 4 | `openspec/specs/teamsmith/spec.md` | **触发**（反例②） | 同上；`openspec validate` 的输入 |
| 5 | `ci/Containerfile` | **触发**（反例③） | 同上；门禁镜像的定义 |
| 6 | `.github/workflows/gates.yml` | **触发**（反例④） | 同上；工作流自身 |
| 7 | `install.sh` | **触发**（反例⑤） | 同上；根目录脚本 |
| 8 | `docs/team/DECISIONS.md` + `skills/teamsmith/tests/smoke.sh`（混合 push） | **触发** | 只要**一个**文件未命中就触发（不是逐文件判） |

可执行形式（每个断言都真的求值，见 §证据 2）：`node docs/team/reports/P130-dev/pkg/wfcheck.cjs matrix`。

**忽略面只写 `docs/**`，不多写别的**：每多一条 ignore 就多一处「本该跑却被跳过」的失手面；README/SCOPE 这类根文档改动很罕见，且是发版面（`package.json` 的 pi 预览字段等）的邻居，宁可让它触发。`docs/**` 正是那 ~30 次 push 的来源（D54 的账本 push），也是任务书要求的「至少」。

文档里三条边界（都在同一节 "Git diff comparisons"）如实记录：

- `>1,000` commits 的 push → **总是跑**（配额方向更保守，不会漏门禁）；
- 生成 diff 超时 → **总是跑**（同上）；
- diff 超过 300 文件、且过滤器匹配到的文件不落在返回的前 300 个之内 → **不跑**。这一条是**可能漏跑**的边界（例如一次巨大重构 push）；本仓库的 push 都是小步/攒批，真实命中概率极低，且 D54 已定「接受判据 = 本地门禁，CI 不是判据」，所以不为此加机制——真遇到就 `workflow_dispatch` 手工补一次（见下）。
- 标签 push 不做路径过滤 → 与本工作流无关：`branches: [main]` 本身就不接受 tag push。
- `workflow_dispatch` 没有路径过滤（路径过滤只属于 `push`/`pull_request` 事件）→ 手工跑永远可行，这也是「>300 文件边界漏跑」的兜底。

## B · 作业拓扑：一次运行只构建一次镜像

选 **①（合并成一个作业，perf 作为 `continue-on-error` 步骤）**，理由与失效模式：

| | ① 合并（选中） | ② 两作业 + GHCR 缓存镜像 |
|---|---|---|
| 每次运行的镜像构建 | **1 次**（job 内一个 Build 步骤，两个套件共用同一 tag `teamsmith-gates:ci`） | 1 次构建 + 1 次 pull |
| runner 分配 / 网络 / 存储 | 1 个 runner、无网络依赖 | 2 个 runner、需 registry 存储与网络 |
| 凭证与权限 | **无**（`permissions: contents: read` 原样不动；与文件头「no registry credentials, no floating image tag」的设计口径一致） | 需要 `packages: write`/`read`；权限、仓库设置、私有 registry 可见性都要管 |
| 失效模式 | 正确性与 perf 在**同一 runner 上串行**：正确性挂死吃满 60 分钟超时 → perf 这次不跑 | registry 不可用 / 权限配错 / tag 过期 → 要么整段红，要么回退构建 → **悄悄又变成两次构建**（正是本任务要消灭的）；缓存镜像还有 stale/投毒面 |
| 代价评估 | perf 数值的正式记录本来就在发版前手工跑钉死容器（`docs/team/PUBLISH.md` §0）；CI 里的 perf 只是顺带结论，不阻塞、不归档，因此串行与「挂死时不跑」都可接受 | 多一层外部依赖换来的只是并发；与本仓库「self-contained」口径相悖 |

拓扑（`on` → 单个 `gates` 作业）：

```
on: push [main] 且改动文件不全是 docs/**    （或 workflow_dispatch：无路径过滤）
        │
        ▼
job gates (ubuntu-latest, 60 min)
  0  Checkout
  1  Build the gate image            ← 一次运行只此 1 次 docker build
  2  Gates (pinned container)        ← 硬门：openspec validate + smoke.sh（无 continue-on-error）
  3  Collect the failure scene       ← if: always()   （原样）
  4  Upload the failure scene        ← if: failure()  （原样）
  5  Performance suite               ← if: !cancelled() + continue-on-error: true（不阻塞）
```

**不变项与证明**：

1. **正确性仍是硬门**：步骤 2 没有 `continue-on-error`，作业级也没有（`wfcheck structure` 两条断言 + 翻转 B 证明这条不是空话）；步骤 2 失败 → 作业 `failure` → 工作流红。
2. **perf 失败不阻塞**：步骤 5 `continue-on-error: true`；按 GitHub 文档语义（`jobs.<job_id>.steps[*].continue-on-error`：「Prevents a job from failing when a step fails. Set to `true` to allow a job to pass when this step fails.」，步骤本身显示红 + 注解，作业/工作流结论不变）—— 模型四组合（见下）与翻转 B 一起钉住。
3. **perf 仍是独立结论、不被正确性红吃掉**：`if: ${{ !cancelled() }}` —— 正确性红时它照跑（旧两作业布局的性质：两个作业互不依赖，各自出结论），显式取消时不跑（文档推荐 `!cancelled()` 而非 `always()`，后者在取消时也会尝试起步骤）。这一条也是被检查器钉住的：删掉 `if` 会让它退回默认 `success()`，正确性红时静默跳过 → 翻转 D 必须变红。
4. **一次构建**：`jobs` 只有 1 个（`wfcheck structure` 的第一条断言），`docker build -f ci/Containerfile` 步骤恰好 1 个，且它在正确性与 perf 步骤之前；两个套件都跑同一个 tag。

## 证据

### 1) YAML 可解析（任务书命令在本机的等价形式）

任务书给的 `python3 -c 'import yaml, sys; ...'` 在本机不可用 —— `python3 -c 'import yaml'` → `ModuleNotFoundError: No module named 'yaml'`。等价形式：`wfcheck.cjs` 依次尝试 node 的 `yaml` 包（宿主 `NODE_PATH=~/.bun/install/global/node_modules`）、`~/.bun/bin/bun` 的 `Bun.YAML`、`python3+pyyaml`，第一个可用的就够：

```
$ PATH="$HOME/.bun/bin:$PATH" node docs/team/reports/P130-dev/pkg/wfcheck.cjs parse .github/workflows/gates.yml
ok YAML 可解析：…/gates.yml（解析器 yaml@2.9.0，顶层键 name, on, permissions, concurrency, jobs）
ok on.push 存在
ok on.workflow_dispatch 存在
ok jobs 非空：gates
== wfcheck parse == ok=4 bad=0 finding=0 skip=0
```

（bun 1.3.14 的 `Bun.YAML.parse` 单独跑过，同一份文件解析出同样的顶层键。）

### 2) 触发矩阵 + 拓扑 + 非阻塞模型（一条命令，全文在 `pkg-run.log`）

```
$ bash docs/team/reports/P130-dev/pkg/run.sh
...
ok 触发矩阵: 纯账本：只改 docs/team/BOARD.md [docs/team/BOARD.md] → 不触发（按 docs/**）
ok 触发矩阵: 纯报告：只改 docs/team/reports/P130-dev.md [docs/team/reports/P130-dev.md] → 不触发（按 docs/**）
ok 触发矩阵: 反例①：改门禁代码 skills/teamsmith/scripts/team … → 触发
ok 触发矩阵: 反例②：改规格 openspec/specs/teamsmith/spec.md … → 触发
ok 触发矩阵: 反例③：改门禁镜像 ci/Containerfile … → 触发
ok 触发矩阵: 反例④：改工作流 .github/workflows/gates.yml … → 触发
ok 触发矩阵: 反例⑤：改根脚本 install.sh … → 触发
ok 触发矩阵: 混合推送：docs 账本 + skills 代码同一次 push … → 触发
== wfcheck matrix == ok=9 bad=0 finding=0 skip=0
ok 作业数 1（gates）—— 一次运行只有一份镜像构建的前提
ok 镜像构建步骤恰好 1 个（steps[1]）
ok 正确性步骤没有 continue-on-error —— 失败即作业红（硬门）
ok perf 步骤 continue-on-error: true —— 失败不阻塞
ok perf 步骤的 if="${{ !cancelled() }}" —— 正确性红时仍跑出独立结论，显式取消时不跑
ok 步骤顺序：构建(1) → 正确性(2) → perf(5)
ok 两套件与构建使用同一镜像标签 teamsmith-gates:ci（同一次构建的产物）
== wfcheck structure == ok=13 bad=0 finding=0 skip=0
ok 非阻塞模型: 正确性 ✓ · perf ✓ → 作业 success（期望 success）
ok 非阻塞模型: 正确性 ✓ · perf ✗ → 作业 success（期望 success）      ← perf 红不阻塞
ok 非阻塞模型: 正确性 ✗ · perf ✓ → 作业 failure（期望 failure）      ← 硬门成立
ok 非阻塞模型: 正确性 ✗ · perf ✗ → 作业 failure（期望 failure）
== wfcheck model == ok=4 bad=0 finding=0 skip=0
== P130 结果 ==
全部段落通过（0 段红）
```

「模型」不是拍脑袋：它从解析后的 YAML 里取两个步骤各自的 `continue-on-error`，按文档语义（作业结论 = failure 当且仅当存在「失败且没有 continue-on-error」的步骤）枚举四种组合；步骤的属性变了，四行结论就跟着变。

### 3) 翻转证据（实现改坏 → 检查器必须变红 → 真文件未动）

`pkg/50-flip.sh` 把四种改坏形态写到 `mktemp` 副本上（**不碰真文件**），每条都必须让对应检查器出现 `bad`：

```
$ bash docs/team/reports/P130-dev/pkg/50-flip.sh
ok 翻转 A · paths-ignore 换成 skills/**：matrix 按预期变红（bad 触发矩阵: 纯账本：只改 docs/team/BOARD.md … 期望 不触发，实际 触发）
ok 翻转 B · 删掉 perf 的 continue-on-error：model 按预期变红（bad 非阻塞模型: 正确性 ✓ · perf ✗ → 作业 failure（期望 success））
ok 翻转 C · 复制一份镜像构建步骤：structure 按预期变红（bad 镜像构建步骤 2 个（期望 1）—— 每个都会付一次 docker build）
ok 翻转 D · 删掉 perf 的 if：structure 按预期变红（bad perf 步骤的 if 是 "(缺省 success())"（期望包含 !cancelled() 或 always()）—— 正确性红时 perf 会被静默跳过）
ok 翻转全程真文件未被改动（sha256 前后一致：218bd1396510661d52848fd9e885daf08fb162154321d37d4fc7c435e5669336）
ok git diff 对真工作流为空
== 50 结果 == ok=6 bad=0 finding=0 skip=0
```

### 4) 本地门禁不受影响（接受判据）

命令（D54：接受判据 = 本地门禁；本任务**不触发任何 CI**）：

```
$ cd .worktrees/dev
$ PATH="$HOME/.bun/bin:$PATH" bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh'
```

结果（完整日志 `docs/team/reports/P130-dev/gate-full.log`，300K）：

```
- Validating...
✓ spec/agent-adapters … （13 个能力）
Totals: 13 passed, 0 failed (13 items)
...
== 最慢 5 段 ==
  #97 38 · 设置选项（M55…） · 用时 302s · ✓22 ✗0 SKIP0 · ticks 22
  #110 51 · 用法诚实性… · 用时 161s · ✓2 ✗0 SKIP0 · ticks 2
  #95 36 · 选段与分段账本自检… · 用时 123s · ✓105 ✗0 SKIP0 · ticks 105
  #76 26 · 面板… · 用时 107s · ✓142 ✗0 SKIP0 · ticks 142
  #84 33 · 项目契约的读写面… · 用时 92s · ✓1 ✗0 SKIP0 · ticks 1
账本自查： 114 段收口 · 增量 ✓3775 ✗0 SKIP0 ｜ 结果行 ✓3775 ✗0 —— 一致

== 结果 ==  ✓ 3775  ✗ 0
smoke 全绿
GATE rc=0
```

`openspec validate --all --strict` → **13 passed / 0 failed**；smoke → **✓3775 ✗0**（含账本自查「增量 = 结果行」一致），门禁 rc=0。本次改动不碰 `skills/**`，所以段数与前几次全量运行同量级。

未改动 `smoke.sh` / `openspec/**` / `.pi/team/config.sh` —— 全量 diff 的文件清单为证：

```
$ git diff --name-only main...HEAD
.github/workflows/gates.yml
docs/team/reports/P130-dev/pkg/10-yaml.sh
docs/team/reports/P130-dev/pkg/20-matrix.sh
docs/team/reports/P130-dev/pkg/30-topology.sh
docs/team/reports/P130-dev/pkg/40-nonblocking.sh
docs/team/reports/P130-dev/pkg/50-flip.sh
docs/team/reports/P130-dev/pkg/lib.sh
docs/team/reports/P130-dev/pkg/mutate.cjs
docs/team/reports/P130-dev/pkg/run.sh
docs/team/reports/P130-dev/pkg/wfcheck.cjs
```

## 交回 PM 的备注（不在本任务 grant 内，未动）

1. `docs/team/PUBLISH.md` §7 写着「`.github/workflows/gates.yml` 现在是 `workflow_dispatch` + `main` push」——触发面现在多了 `paths-ignore: docs/**`，那句话值得补一句（PM 的文件）。同节「工作流此前从未在真实 CI 上跑过」的提醒不变。
2. D60 #4（P103 的 `ETXTBSY`）本任务书没点名，按范围纪律未动。
3. 下一次真实 CI 是第一次吃到这套新拓扑的运行：若那天要核对，看两件事即可 —— 运行里只有一个作业、一次 `Build the gate image`；纯 `docs/**` 的 push 列表里不出现新的 run。
