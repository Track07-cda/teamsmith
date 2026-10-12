# P236 · long-job-suspend 返工：挂起判定按「作业归属」而不是「项目里有活作业」

- task: P236 · change: `long-job-suspend` · delta: `notify-and-inbox`
- agent: dev-bob · branch: `task/P236-suspend-owner-scope`
- tip: `51ee189`（产品/测试提交；本报告随后提交；base = 派单点 `9882815d2abd`；main 在本轮期间只前进了
  两个 docs 提交到 `e9216b7708bd`，产品文件零差异 —— `git diff --stat 9882815 main -- skills/teamsmith/extension/team-notify.ts` 为空）
- 判定：**交付**。任务书五条验收命令全绿；红侧有两条独立证据（变异 + 旧实现），都能复现缺陷现场。

## 一句话

`team-notify.ts` 的挂起判定过去读**车道 state 目录里的全部活作业**，于是同一车道目录里的别人的作业会把本席位
的回合打成挂起。现在记录里的 `cwd` 必须解析到**本会话自己的工作树/cwd**（真实路径相等）才算「我的作业」；
缺 `cwd`、相对 `cwd`、解析失败或指向别人工作树的记录一律不算（fail-closed）。A 刀已通过的判据（身份指纹、
车道目录解析规则、`awaiting=`/`[auto·suspended]`/`[auto·interrupted]`/`⚠` 的形状）逐条不动。

## 缺陷与根因

A 刀把「在跑作业集合」从车道目录读出来之后，只做了 `(pid, start-time)` 活体验证，没有把作业与**结束回合的
那个会话**对上。真实现场（PM 2026-10-12）：`dev` 的作业记录 `cwd=…/.worktrees/dev` 躺在共享的
`state/bg/` 里，`dev2`（当时没有任何自己的作业）回合结束时收件箱写出
`[auto·interrupted] agent:dev2 · P232 · … · awaiting=p235-acceptance2`。PM 随后在同一轮真实运行里给了第二处
证据：`dev3`（任务 P233、工作树 `.worktrees/dev3`）结束回合时也带上了同一个 `awaiting=p235-acceptance2`。
只要项目里任何一个席位在做长作业，其它席位每次结束回合都会被挂上别人的作业。

## 修法（`skills/teamsmith/extension/team-notify.ts`，+46/−10）

新增三个纯函数，`runningLaneJobs` 多收一个「本会话归属路径集合」：

| 函数 | 语义 |
|---|---|
| `realPathOf(p)` | `realpathSync` 归一（软链、尾斜杠）；只接受绝对路径；路径不存在 / 无权限 → 空串 |
| `ownedSessionPaths(cwd, worktree)` | 本会话的归属集合 = `cwd` 与它所在的工作树（`wtPrefix + agent`）各自解析后的真实路径；任一解析失败就不放进去，集合为空 = 一条都不认 |
| `isOwnedCwd(jobCwd, owned)` | 记录的 `cwd` 解析后**等于**归属集合里的某一项才算「我的作业」 |

调用点：

```ts
const owned = ownedSessionPaths(cwd, join(wtPrefix, agent))
const running = runningLaneJobs(laneDir, owned)
```

`runningLaneJobs` 的逐条顺序不变（平坦 id → 正规文件 → pid/start 合法性 → `/proc` 指纹 → **归属**），
每条不成立都 `continue`；`laneDir` 为空或归属集合为空时整个函数返回空数组。

三种结论，逐条对照任务书第 1–3 条：

| 记录形状 | 判定 | 依据 |
|---|---|---|
| `cwd` 解析到本会话的 cwd 或本会话的工作树（软链、尾斜杠也算） | 算在跑 | 真实路径相等 |
| `cwd` 指向别的席位的工作树 / 主工作树 / 别处的目录 | 不算 | 真实路径不在归属集合里（缺陷现场） |
| 缺 `cwd`、相对路径、路径已不存在、无权限、会话自己的路径也解析不出来 | 不算 | fail-closed，不猜 |

任务书第 3 条「不回退 A 刀判据」的核对：`procStartTime` 指纹比对、`laneStateDir` 的目录解析（显式
`TEAM_STATE_DIR` 优先，然后 worktree 自带 config / `TEAM_ROOT` / 最近的 config 祖先 / git 主工作树）、
完成/未完成两条分支、`awaiting=` 的拼法、`uncommitted=` 保留、`[auto]`/`[auto·suspended]`/`[auto·interrupted]`
与 `⚠` 前缀的取舍、`start`/`wait` 两类账本行 —— 这些代码在 diff 里零改动（`git show 9f3f5d0 --stat` = 单文件）。

## spec delta（`openspec/changes/long-job-suspend/specs/notify-and-inbox/spec.md`，本任务声明的 delta）

MODIFIED requirement 里补上归属判据的规范句：「Only a job the settling session itself started SHALL count …
resolves, through symlinks and trailing slashes, to the session's own working tree or working directory … the
ownership check fails closed rather than guessing.」并补三个场景（任务书第 1、2 条的可验形式）：

- Two seats, one job each（两席位共享车道目录，各自只出现自己的 id）
- An idle seat is not suspended by another seat's job（空席位保持 `[auto]`、无 `awaiting=`）
- A record with no owning directory does not suspend（缺 / 相对 / 解析不出来的 `cwd` → 保持 `[auto]`）

`openspec validate --all --strict` → `Totals: 16 passed, 0 failed`。

## 测试（`tests/bg-ledger.sh` 新增 `owner-scope` 组与红侧对照）

`bg-ledger-harness.mjs` 的 `makeBase` 现在可以给一个夹具仓库建多个席位工作树（名册与工作树同步扩展、
共享同一个车道 state 目录）；新增 `procStartTime`（手写记录要用真指纹）、`inboxLine/resetNotify` 支持指定
席位。`owner-scope` 八条用例（三个席位一个夹具，覆盖两个不同的非拥有者）：

| 用例 | 夹具与断言 |
|---|---|
| each seat suspends on its own job only (dev / dev2 / dev3) | 三个席位各有自己的活作业（`cwd` 各指自己的工作树）→ 每条收件箱行只带自己的 id（另两个席位的 id 不得出现） |
| a seat with no job of its own … (dev2 / dev3) | 只有 dev 有作业 → dev2 与 dev3 的行各自是 `[auto]` + `⚠ 未提交`，无 `awaiting=`、无 `suspended` |
| missing, relative or unresolvable cwd … | 活 pid 的三条畸形记录（无 `cwd` 行 / `cwd=.worktrees/dev` / `cwd=/nonexistent/…`）→ 不挂起 |
| cwd reaching the session worktree through a symlink … | 记录写软链路径 + 尾斜杠 → 仍算本会话（挂起） |
| a job started from the main worktree … | 主工作树里起的作业 → 席位不挂起 |

上一轮 `suspend-shape` 里死 pid / pid 复用两条记录补上了 `cwd`（指向本会话工作树）—— 否则新归属判据会
替身份指纹挡枪，把既有的「去掉身份验证」翻转变成不红（这一条是实测踩到的，见下）。

## 红 → 绿对照（翻转：删掉归属判据 / 旧实现 + 新用例，两条独立证据）

**A. 变异翻转**：把候选树（`tip`）复制到 scratch，`sed` 把 `if (!isOwnedCwd(fields.cwd ?? '', owned)) continue`
换成 `if (false) continue`（= 退回「同一车道目录里有活作业即算」），`flip_premise` 先证明破坏已打上，
再跑 `owner-scope` 组：

```
BG-CASE FAIL owner-scope: each seat suspends on its own job only (dev) :: … awaiting=bgl…-own-a,bgl…-own-b,bgl…-own-c …
BG-CASE FAIL owner-scope: each seat suspends on its own job only (dev2) :: … awaiting=bgl…-own-a,bgl…-own-b,bgl…-own-c …
BG-CASE FAIL owner-scope: each seat suspends on its own job only (dev3) :: … awaiting=bgl…-own-a,bgl…-own-b,bgl…-own-c …
BG-CASE FAIL owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev2) :: - … [auto·suspended] agent:dev2 · … awaiting=bgl…-own-busy …
BG-CASE FAIL owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev3) :: - … [auto·suspended] agent:dev3 · … awaiting=bgl…-own-busy …
BG-CASE FAIL owner-scope: a live record with a missing, relative or unresolvable cwd does not suspend (fail-closed) :: - … awaiting=bg-ledger-gonecwd,bg-ledger-nocwd,bg-ledger-relcwd …
BG-CASE FAIL owner-scope: a job started from the main worktree does not suspend a seat :: - … [auto·suspended] … awaiting=bgl…-own-main …
BG-LEDGER-HARNESS FAIL (7)        （红侧 rc=1）
```

带 `(dev2)` 与 `(dev3)` 的两行就是缺陷现场：两个非拥有者席位各自的回合都带着 `dev` 的作业 `awaiting=`
（PM 追加的第二处证据）。同一批八条用例子在同一轮 pristine 树基线里
全部 PASS（`h-flip-green.log`），「红在「…」+ 同一用例在 pristine 树上 PASS」成对打印在 ① 的输出里。
还原后绿：`flip-restored` 段重跑 pristine 树 → 全绿。

**B. 旧实现对照（不靠变异，直接拿 main tip 的扩展文件跑新用例）**：
`bash ../pm-skills-ledger/team/reports/P236-dev-bob/run.sh <候选树> --red` 用 `git show main:…team-notify.ts`
（改前真身）配新 `bg-ledger-harness.mjs` 的 `owner-scope` 组：

```
BG-CASE FAIL owner-scope: each seat suspends on its own job only (dev / dev2 / dev3) :: … awaiting=p236old-own-a,p236old-own-b,p236old-own-c …
BG-CASE FAIL owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev2) :: - … [auto·suspended] agent:dev2 · … awaiting=p236old-own-busy …
BG-CASE FAIL owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev3) :: - … [auto·suspended] agent:dev3 · … awaiting=p236old-own-busy …
BG-LEDGER-HARNESS FAIL (7)
红侧期望：非零退出（上面的 FAIL 行就是缺陷现场：dev2/dev3 的回合带着 dev 的作业 awaiting=）
```

同一条命令的验收面（`--accept`）在同一轮里给 `bg-ledger：115 passed, 0 failed`（rc=0）——
**旧实现 7 条 FAIL / 新实现 0 条**，红绿对照成立。

## 验收命令与真实输出（`tip=51ee189`，全量见证据包 `logs/final-acceptance.log`）

### ① `bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope,flip`

```
  ✓ flip flip-no-identity：红在「suspend: a dead pid does not suspend」
  ✓ flip flip-no-identity：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
  ✓ flip flip-owner-scope：红在「owner-scope: each seat suspends on its own job only」
  ✓ flip flip-owner-scope：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
  ✓ flip flip-owner-scope：红在「owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev2)」
  ✓ flip flip-owner-scope：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
  ✓ flip flip-owner-scope：红在「owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev3)」
  ✓ flip flip-owner-scope：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
  ✓ flip flip-owner-scope：红在「owner-scope: a live record with a missing, relative or unresolvable cwd does not suspend (fail-closed)」
  ✓ flip flip-owner-scope：同一用例在 pristine 树上 PASS（红 → 绿对照成立）
  ✓ flip flip-owner-scope：红在「owner-scope: a job started from the main worktree does not suspend a seat」
  ✓ flip flip-owner-scope：同一用例在 pristine 树上 PASS（红 → 绿对照成立）

bg-ledger：115 passed, 0 failed        （rc=0；含 A 刀既有的 suspend-shape/ledger/wording 全部用例）
```

### ② `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict`

```
Totals: 16 passed, 0 failed (16 items)        (rc=0)
```

### ③ `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-notify.ts skills/teamsmith/tests/bg-ledger.sh`

```
decision=RUN
sections=125
keys=31
...
reason=13c ← skills/teamsmith/tests/bg-ledger.sh        (rc=0)
```

（另外跑了 `section-select.sh --check`：`== 选段自检 ==  ok 7  bad 0  SKIP 1`，rc=0 —— 新增的 §13c 路径
token 已在本行声明，段↔行、needs、字面模式三条自检都成立。）

### ④ `bash skills/teamsmith/tests/ledger-ban.sh --names-file …`

```
ledger-ban: root=…/.worktrees/dev-bob scope=published files=1342 hits=0 names=ok user=resolved   (rc=0)
```

### ⑤ `git diff --check && git status --short`

无输出（干净，rc=0）。

## 门禁登记（任务书第 4 条「在 smoke.sh 里按既有方式登记」）

`smoke.sh` §13c 末尾新增一块：全量模式跑 `bash $SKILL_DIR/tests/bg-ledger.sh --select suspend-shape,owner-scope`，
并在去色后的日志上按用例名断言五条（A 刀挂起合同未回退 / 三席位各自只认自己的作业 / 两个非拥有者席位
（dev2、dev3）都不被别人的作业打成挂起 / 缺 cwd 不判挂起）；`TEAM_SMOKE_FAST=1` 时走 `fast_skip` 打一行
可见 SKIP。`tests/section-paths.tsv` 的 13c 行加了这个路径 token（`--check` 已绿）。

实测（`logs/smoke-fast-13c.log`，最终 tip）：

```
  SKIP（FAST 模式） 13c·挂起归属（P236） —— 要起真后台作业与真 git worktree（bg-ledger.sh 入口自带隔离）
#12 13c · 团队后台车道（M27/M30）… · 用时 10s · ✓18 ✗0 SKIP1 · ticks 19      （FAST 选段 rc=0）
```

全量模式的这一块用「原样摘出这段 + 完整模式变量」跑了 6 条断言全绿（`logs/block-sim.log` 的模拟输出：
`P236 块模拟：6 passed, 0 failed`）。**没有**在本轮跑完整 §13c（它的 needs 闭包要真 tmux/真 pi：6i/6f/6j/12b），
留给你独立的门禁复验 —— 这是本报告最需要你亲自跑的一条。

## 未做 / 未跑（不隐藏）

1. **没跑完整门禁 / §13c 全量**（见上）：本轮只跑了 §13c 在 FAST 下的选段（rc=0，含新 SKIP 行）与那段
   block 的完整模式模拟。全量 §13c 与 wrap-up 全量按纪律留在 PM 侧。
2. **没动 `openspec/changes/long-job-suspend/tasks.md`**：A 刀的 3.1/3.2 仍然勾着，本轮返工没有对应的
   任务行（返工是 PM 临时派单，不在 change 的 tasks 里）。要不要补一行 `3.3 返工（P236）`由你决定；
   我没写是因为 tasks.md 不在任务书授权的路径里。
3. **B 刀未做**（4.1–4.4：`cmd-agents.sh` 提示词 / 模板 / `references/**` / §13 折回）：本轮只把
   notify 侧两组接进 §13c；`wording`/`ledger` 两组仍只在独立入口里跑，折回 §13/§13c 的完整方案仍属 B 刀。
4. **`smoke.sh` 与 `section-paths.tsv` 是 P235（routing S3）也可能改的共享文件**：我的改动只落在 §13c 的
   尾部与 13c 那一行的 patterns 字段（P235 的 7.4 动的是 init/bootstrap/template 面），merge 时若仍冲突，
   冲突面就是这两处。
5. 归属判据用**真实路径相等**（不是「在工作树之下」）：作业带显式 `cwd` 指到工作树的子目录时不会被算作
   本会话的作业 —— 方向是 fail-closed（少判挂起，不误判）。如果实测显示子目录 `cwd` 常见，需要改成包含
   判据，那是新的语义决定（会放宽归属），不在本返工范围。

## 证据包（D94，仓外）

`../pm-skills-ledger/team/reports/P236-dev-bob/`

- `run.sh` — 复现脚本：`bash run.sh <候选树> [--accept|--red]`（`--accept` 跑任务书五条命令，`--red` 跑旧实现
  对照；`all` 两者都跑并给出总判定）
- `logs/final-acceptance.log` — 最终 tip 的五条验收全量输出（含 115 条用例、翻转对、pristine 基线）
- `logs/red-before-main-tip.log` — 红侧对照 B：main tip 的旧实现跑新用例（7 条 FAIL）
- `logs/h-flip-owner-scope.log`、`logs/h-flip-no-identity.log`、`logs/h-flip-green.log` — 翻转红侧与
  pristine 绿侧的原始日志
- `logs/smoke-block-13c.log`、`logs/smoke-fast-13c.log` — 门禁块原命令输出与 FAST 选段输出
- `logs/block-sim.log` — 门禁块在完整模式下的 6 条断言（摘出原样跑）
- `logs/run-sh.log` — `run.sh` 一次 `all` 运行的完整输出
- `evidence/` — A 刀阶段的翻转基线日志（对照用）

## 复核提示（给 PM）

- 最快复现缺陷：`bash ../pm-skills-ledger/team/reports/P236-dev-bob/run.sh <你的干净 clone> --red` → 七条
  `BG-CASE FAIL owner-scope …`（`dev2` 与 `dev3` 两个非拥有者席位的行各自带着 `dev` 的作业，
  退出码 0 表示“红侧确实红”，见脚本末行）；再把同一命令换成 `--accept` → 115/0 全绿。
- 代码面只需读 `team-notify.ts` 的 `realPathOf/ownedSessionPaths/isOwnedCwd` 与 `runningLaneJobs` 里那一行
  `isOwnedCwd` 调用；其余差异都在测试/门禁/规格 delta。
- 独立复验建议：干净 clone + `bg-ledger.sh --select …` 五组、`openspec validate`、`section-select --check`，
  以及全量 §13c（本轮我没跑的那条）。
