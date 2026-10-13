# P237 · long-job-suspend · B 刀：提示词与文档面（工人简报的三态合同）

agent: dev   status: DONE   time: 2026-10-13 07:20 UTC
task: P237   change: long-job-suspend   phase: apply   deltas: dispatch
branch: `task/P237-long-job-suspend-prompt`   PR/MR: -（local 模式，无远端；分支留在本地等 PM 复验后合并）
输入基线：main = `c633f21`（派单 tip）。此后本仓 main 只多出 `46241f4`、`7aeadf5` 两个提交，命中的都是
`docs/team/DECISIONS.md` 与 `docs/team/PRODUCT-PROPOSALS.md`（纯账本文本），与 B 刀五个产品面零交集。

一句话：工人简报按 design 决策 1 整段改口径 —— 后台车道默认「起完结束回合、完成叫醒是正常收割点」，
原地等收成有界例外（三条同时成立 + 内联等待预算数字）；「Never stop mid-task」列出**恰好三种**合法回合
结束状态（delivered / hard-blocked / suspended on background jobs），挂起要求回合末行点名在等的 job id、
不写终稿、不报 `BLOCKED:`；续跑行加「上一会话的叫醒随进程死了，先查 `state/bg.log` 与 `team bg list`」。
AGENTS 模板、`references/protocol.md`、`references/workflows.md` §E2 收敛到同一份三态合同；PM 模板与
`SKILL.md` 逐字未动。A 刀的 wording/ledger 用例与 P236 的挂起归属用例折进 smoke §6/§13/§13c，
新增的四处一致性断言按 delta 的四条场景自称；一条 §4.4 夹具证明挂起后死亡的席位命中**既有**巡检待办条款。

## Deliverables

| Path | What | Commit |
|---|---|---|
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | 车道段整段重写 + 三种结束状态 + 续跑查盘（§4.1） | `adc7be0` |
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | 纪律条同步三态一句话版（§4.2） | `84a3b6c` |
| `skills/teamsmith/references/protocol.md` | 通知小节登记 `[auto·suspended]` 与 `awaiting=`（§4.2） | `84a3b6c` |
| `skills/teamsmith/references/workflows.md` | §E2 车道规则：结束回合默认 + `start`/`wait` 账本行（§4.2） | `84a3b6c` |
| `skills/teamsmith/tests/smoke.sh` | §6 注入夹具 + §13c 场景断言与 §4.4 兜底夹具（§4.3/§4.4） | `e5a8ff6`、`12bf9c9` |
| `skills/teamsmith/tests/section-paths.tsv` | §13c 行声明它现在读的面（§4.3 登记） | `e5a8ff6` |
| `docs/team/reports/P237-dev.md` | 本报告 | 本报告的提交 |

仓外证据包（D94，主检出同级的 `pm-skills-ledger/`）：`pm-skills-ledger/team/reports/P237-dev/`
—— `accept/`（五条验收命令全量输出、渲染出的提示词原文、基线 log、PM 模板核对记录）+
`flips/`（四条红侧与还原后绿跑：`.log` 全量、`.reds` 只留 ✗ 行）+ `flips-run.sh`（可复跑的红侧脚本）。

## 实现要点（逐条 §4 对照）

### §4.1 `cmd-agents.sh`：车道段、三态、续跑查盘

- 车道段（`bg_block`，注入条件仍是 `''|*'{bg_ext}'*`，逐字节未动）整段重写为：
  `start them with team_bg_run …, then **end your turn** -- the completion wake-up is the normal harvest point:
  when the job finishes you are woken once (several jobs finishing together arrive as one message) and harvest it
  with team_bg_wait <id> … **In-turn waiting is the bounded exception**: use it only when all three hold -- the job
  is expected to finish within the inline-wait budget (about 2 minutes), its result blocks your immediate next step,
  and no other task work can advance meanwhile.`（渲染原文见 `accept/rendered-prompt.txt`）。
- 「Never stop mid-task」段从 `exactly two situations` 改为 `exactly three situations`：
  **(a) delivered**（跑完验收命令 + 报告写好 + 分支落定）、**(b) hard-blocked**（notify PM + 报告里
  `BLOCKED:`）、**(c) suspended on background jobs**（本会话起的作业仍在跑、不依赖其结果的工作都做完；
  「A suspension is neither a delivery nor a blockage -- do not write the report's final verdict and do not notify
  `BLOCKED:` for it」，并要求**最后一行**点名在等的 job（`waiting on: <id>[, <id>…]`））。
- 续跑行加：`A previous session's wake-ups died with its process, so jobs it left running will never wake you:
  check `state/bg.log` and `team bg list` before you await or re-run their results.` 这一行在共用的
  续跑行里 —— 对**所有**适配器都在（含没有 `{bg_ext}`、拿不到车道段的模板），见 §4.3 场景 4 的两处断言。
- 退休措辞零命中：`accept/rendered-prompt.txt` 里 `Harvest every job|before your turn ends|costs a turn|exactly two situations` 命中数为 0。

### §4.2 模板与 references：一份合同跨面

- `templates/AGENTS.section.md.tmpl` 纪律条：`either deliver … or be hard-blocked` → 三态一句话版，
  并带上同一条车道规则与**同一个预算数字**（`the completion wake-up is the normal harvest point` /
  `inline-wait budget (about 2 minutes)`）。渲染后的 `AGENTS.md` 因此不会与提示词漂移。
- `references/protocol.md` 通知小节登记挂起标签 `[auto·suspended]` 与 `awaiting=` 字段（含三条结局的交叉引用）。
- `references/workflows.md` §E2 规则 1「Harvest before the turn ends」→ 结束回合默认、内联等待为例外；
  规则 2 的账本清单补 `start id=<id> pid=<pid>` 与 `wait id=<id> outcome=… waited_s=<s>` 两类行。
- **PM 模板与 SKILL.md 未动**（`git diff --name-only main...HEAD` 里没有这两个文件），既有口径行仍在：
  `templates/pm-prompt.md.tmpl:79-80`（`team_bg_run`, let the turn end, `team_bg_wait` when the wake-up arrives）、
  `SKILL.md:20`（`long gate: team_bg_run → turn ends → woken once → team_bg_wait`）、`SKILL.md:58`（车道快照行）；
  两文件里退休措辞命中数 0。核对记录：`accept/pm-template-check.log`。

### §4.3 smoke 登记与一致性断言

- **折进**：§13c 里现在跑 A 刀的两组与 P236 的两组同一个入口
  （`bash "$SKILL_DIR/tests/bg-ledger.sh" --select wording,ledger,suspend-shape,owner-scope`，41 条断言），
  另有 4 条 assert 按**用例名**钉住「wording 组在跑、ledger 组在跑、活记录 → suspended、两席位互不侵占」；
  输出先剥 ANSI 再断言（入口带颜色）。
- **一致性断言**（§13c，按 delta 场景名自称）：
  * `The built-in Pi prompt carries the three states`（7 条）：三种结束状态、第三态点名、`waiting on: <id>`、
    起完结束回合、完成叫醒是正常收割点、预算数字、旧两态措辞已被取代。
  * `A template without the lane placeholder`（8 条，落在 **§6**，见下）：无 `{bg_ext}` → 不注入车道段/
    没有预算段，但三态合同与续跑查盘指引都在；带 `{bg_ext}` → 车道段出现且同一口径。
  * `The resume guidance points at the on-disk evidence`（4 条）：`state/bg.log`、`team bg list`、
    「叫醒随进程消失」，并在无车道段的适配器上也成立。
  * `One contract across the shipped surfaces`（26 条）：worker prompt / AGENTS 模板 / `protocol.md` /
    `workflows.md §E2` 四个面各自「车道默认 + 预算数字 + delivered + hard-blocked + suspended on background jobs
    + 零退休措辞」，PM 模板单独钉住既有规则行在且没被弱化 —— 任一面缺第三态就在这条点名那个面。
- **注入条件夹具落在 §6 而不是 §13c（一处必要的搬迁，附理由）**：这两次 `--print` 是**真派单预览**，
  走 §6 的续跑守卫。放到 §13c 时它以 full 模式跑在 §11 之后 —— 那时 T1.1 已 close、dev 的 state 被
  §11b/§11d 覆写，守卫按续跑判定就拒了预览（首次 full 跑实测 6 条红）。搬到 §6 的真拉起段之后（那里
  T1.1 刚派单、记录完整），夹具模板按 §6f 的 `$APLACE` 形状绑上身份占位符
  （`--model {model} --provider {provider} --session-id {session_id}`），full 与 FAST 两种模式都成立。
  断言本身一条没减、没换：同样的场景名、同样的 token，只是换了跑的地方与夹具模板。§6f/§6i 的既有断言
  一条未动（含身份/续跑守卫那一批）。

### §4.4 兜底夹具：挂起后死亡的席位命中既有待办条款

§13c 末尾的夹具（FAST 模式显式跳过，理由「要起真后台作业 + /proc 验活」）自造最小仓库（带 P235 的
类别映射），用**真后台作业 + 真 `/proc` 指纹**造出挂起物理形态，再用**读命令**取证，不写巡检代码、
不新增 watchdog 条款：

```
$ team bg list   → p237-fallback  pid=… identity=holds  cmd=smoke fixture
$ team digest    → 待办  停了的 agent 1（dev=unknown）（PM 窗口不存在：需要人工 team up）
                   · dev 未在跑但仍有任务 P237FALLBACK → team dispatch 续跑，或 close P237FALLBACK
```

断言：`identity=holds`（盘上确有活的挂起形状）、待办计数 `停了的 agent 1（dev=unknown）`（席位不在窗口
即进既有待办，车道里的活作业既不遮住它也不需要专门分支）、digest 建议点名该席位与任务、**作业也结束后
待办逐字不变**（既有条款只看「任务未完成 + 窗口不在」，不看车道）。夹具输出原文也打进 smoke 日志
（`13c·P237 §4.4 夹具输出：…`）。

## 验收命令与真实输出

五条按任务书原文跑；输出是真实尾部（全量见证据包 `accept/`、`flips/`）。

### ① `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict`

```
✓ change/long-job-suspend
✓ spec/notify-and-inbox
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)
rc=0
```

### ② `bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')`

```
decision=RUN
sections=125
keys=73
6 in selection ｜ 13c in selection ｜ （键 `13` 不在 paths 命中里：B 刀不碰 notify 扩展，但按任务书要求下面仍把它选上跑）
```

### ③ `bash skills/teamsmith/tests/smoke.sh --select 6,13,13c`（full，非 FAST；跑在交付树上）

```
  ✓ The built-in Pi prompt carries the three states：恰好三种合法回合结束 …（7 条全 ✓）
  ✓ A template without the lane placeholder：无 {bg_ext} → 不注入车道段 …（8 条全 ✓）
  ✓ The resume guidance points at the on-disk evidence：点名 state/bg.log …（4 条全 ✓）
  ✓ One contract across the shipped surfaces：…（26 条全 ✓）
  ✓ 13c·P237 §4.4：挂起后死亡的席位进既有待办计数（任务未完成 + 窗口不在）
#9  6 · dispatch        ✓21 ✗0
#12 13 · notify 扩展    ✓1 ✗0
#13 13c · 后台车道      ✓68 ✗0 SKIP0
== 选段结果 ==  ✓ 457  ✗ 24
```

`✗ 24` 是**环境预存**的失败（§6f 21 + §6i 3），在任何分支上都一样 —— 见下「复查提示」的基线对照。
逐段：`accept/` 打包的 `flips/green-restored.log`（同一棵树的三次 full 跑给出同一组 24 条）。

### ④ `bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope`

```
  ✓ ledger: a suspension is distinguishable from an inline wait from the ledger alone :: … inline_wait=1.1s suspend_wait=0s
  ✓ suspend: a completed turn with a live job record is tagged suspended :: … [auto·suspended] … awaiting=…-sus-live …
  ✓ suspend: an interrupted turn with a running job keeps the interrupted tag and names it :: [auto·interrupted] … awaiting=…-int-live …
  ✓ owner-scope: each seat suspends on its own job only (dev/dev2/dev3)
  ✓ owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev2/dev3)
  ✓ 真项目 state/ 与 inbox 里没有夹具标记（bgl…）
bg-ledger：41 passed, 0 failed
rc=0
```

### ⑤ `bash skills/teamsmith/tests/ledger-ban.sh --names-file …/.pi/team/forbidden-names.txt`

```
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=1367 hits=0 names=ok user=resolved
rc=0
```

### ⑥ `git diff --check && git status --short`

```
git diff --check rc=0
（git status --short 无输出 —— 交付树干净；六个改动文件见 diffstat）
skills/teamsmith/references/protocol.md           |  10 ++
skills/teamsmith/references/workflows.md          |  15 ++-
skills/teamsmith/scripts/lib/cmd-agents.sh        |  17 ++-
skills/teamsmith/templates/AGENTS.section.md.tmpl |   9 +-
skills/teamsmith/tests/section-paths.tsv          |   2 +-
skills/teamsmith/tests/smoke.sh                   | 134 +++++++++++++++++++++-
6 files changed, 171 insertions(+), 16 deletions(-)
```

## 红侧四条（可复跑：`bash /tmp/p237-flips.sh`，脚本与全量日志在证据包）

每次破坏先证明「变异真的打上了」，跑完立刻 `git checkout -- <file>` 还原；四轮跑完再跑一轮还原后的绿。
`✓/✗` 计数是整段选段结果（含环境预存的 24 条），P237 命中的 ✗ 行列在最后一列。

| 红侧 | 变异（真打上的证据） | 命中的场景（✗ 原文） | 结果 |
|---|---|---|---|
| ① 第三态从 AGENTS 模板删掉 | `**suspended on background jobs**` → `**paused**`（`[premise-ok]`） | `One contract across the shipped surfaces：AGENTS template 缺 第三态 suspended on background jobs（找不到 [suspended on background jobs]）` | ✓456 ✗25，红侧 1 条，点名「AGENTS template」 |
| ② 旧「回合结束前必须收割」措辞还原进提示词 | `then **end your turn** -- the completion wake-up is the normal harvest point` → `then harvest with team_bg_wait <id>: **Harvest every job before your turn ends**`（`[premise-ok]`） | `One contract across the shipped surfaces：worker prompt 还有退休措辞（[Harvest every job\|before your turn ends\|costs a turn]）` + `worker prompt 缺 车道默认（完成叫醒是正常收割点）` + `The built-in Pi prompt carries the three states：起完默认结束回合` + `完成叫醒是正常收割点` + `A template without the lane placeholder：带 {bg_ext} 的车道段是同一口径` | ✓452 ✗29，红侧 5 条（其余 24 条仍是环境预存） |
| ③ 无 `{bg_ext}` 也注入车道段 | `''\|*'{bg_ext}'*)` → `''\|*)`（`[premise-ok]`，`case "${TEAM_AGENT_CMD:-}" in` 的下一行确认已改） | `A template without the lane placeholder：无 {bg_ext} → 不注入车道段（不该出现 [team_bg_run]）` + `无 {bg_ext} → 没有内联等待预算段（不该出现 [inline-wait budget]）` | ✓455 ✗26，红侧 2 条 |
| ④ 续跑指引丢掉 `state/bg.log` | `check \`state/bg.log\` and \`team bg list\`` → `check \`team bg list\``（`[premise-ok]`，文件里 `state/bg.log` 命中数 1 → 0） | `The resume guidance points at the on-disk evidence：点名 state/bg.log（… 中找不到 [state/bg.log]）` + `无车道段的适配器也拿得到盘上证据指引` | ✓455 ✗26，红侧 2 条 |
| 还原后 | `[restore-ok] 树与开跑前逐字节同状态`（`git status --porcelain` 前后 diff 为空） | 无 P237 红 | ✓457 ✗24（= 破坏前那一轮，逐段一致：§6 ✓21✗0、§13c ✓68✗0） |

## 复查提示（给 PM）

1. **`✗24` 与本任务无关，是这台机器上的预存状态**：`accept/p237-baseline-6f.log` 与
   `accept/baseline-main-full-6f6i.log` 是同一台机器上从 **main（`46241f4`）干净 clone** 跑的同一批段
   （`--select 6,6f,6i`，full）：`#10 6f ✓114 ✗21`、`#11 6i ✓124 ✗3`，与本分支 `--select 6,13,13c`
   的 6f/6i 计数**逐条相同**（31 行 ✗ 逐行 diff 只差临时根路径）。它们是自定义 adapter 的通知提示词落盘
   与 `{resume_args}`/pane 抓取这几组断言，与本 change 的四个面没有交集。若要复验，建议先跑一遍基线
   clone 再跑本分支，别把环境预存红当成 B 刀的回归。
2. 复核时最该看的两个数字：`#13 13c ✓68 ✗0`（A 刀折进 + 四场景 + §4.4 夹具都在这一节）与 §6 的
   `✓21 ✗0`（注入条件夹具）。§13c 用时 27s（> 记录带 8.08s）是本轮真起了作业与夹具仓库的记录，不是判定。
3. 本段只登记了 B 刀改了的东西：§13c 行新增 `templates/AGENTS.section.md.tmpl`、`references/protocol.md`、
   `references/workflows.md`、`tests/bg-ledger.sh`、`tests/team-bg-harness.mjs`、`extension/team-bg.ts`
   （后三者在 6i 需要之外，还因为 13c 现在真跑 bg-ledger 入口）；`section-select.sh --check` 自检
   ok 7 / bad 0 / SKIP 1（`.pi/skills` 的检出形状跳过，不是通过）。

## 未做项与边界

- 未改 A 刀已并入 main 的两个扩展（`extension/team-bg.ts`、`extension/team-notify.ts`）与
  `tests/bg-ledger*` 的判据本身；未增删既有断言、未 skip 任何既有断言换绿（新增的 FAST skip 只属于
  本轮新加的 §13c·P237 §4.4 夹具，理由写在 skip 文本里）。
- 未改派单的身份/模型路由逻辑（S1–S3 面），未改 canonical specs，未动 `openspec/changes/long-job-suspend/`
  里的 tasks 勾选（§4 的勾选由 PM 在复验后做，避免自己给自己盖章）。
- 未跑 5.x（独立复验 / wrap-up 全量 / 归档）—— 按协议由未写过本任务另一席位与 PM 做。
- 本仓 local 模式：未 push、未合并、未归档；分支 `task/P237-long-job-suspend-prompt` 留本地，
  `git status --short` 干净。

## V24 复验返修（唯一阻塞项：报告里的家目录字面量）

V24 判 FAIL，阻塞项在本报告自身：交付时第 29 行的仓外证据包路径写成了**绝对家目录字面量**，
命中 §60 账本禁令的 `[home]` 形状（产品面与门禁改动全部通过，返修不动任何产品文件）。

- 修法一行：该行改成主检出同级的相对写法（与 P230 报告同一形式），其余字节与所有数字未动。
- 我的漏检原因：交付时我在**写报告之前**跑了一遍 `ledger-ban.sh`（当次 `hits=0` 是真的 —— 报告文件
  那时还不存在，扫描只列 `*.md`），而报告落地后没有重跑。教训：账本面扫描必须在报告**提交之后**再跑一次。

**flip（红 → 绿，均在同一台机器、同一分支上）**

| 侧 | 命令 | 结果 |
|---|---|---|
| 红（`6f00d12`，返修前） | `bash skills/teamsmith/tests/ledger-ban.sh --names-file …/.pi/team/forbidden-names.txt` | `rc=1` · `hits=1` · 点名 `docs/team/reports/P237-dev.md:29: [home]` |
| 红（`6f00d12`，干净 clone 跑门禁段） | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 60` | `rc=1` · `#5 60 … ✓15 ✗1` · `✗ P212 真实账本有命中（scope=published files=1368 hits=1 names=missing user=resolved）` |
| 绿（`0771ca5`，返修后，worktree） | 同 ① | `rc=0` · `hits=0` |
| 绿（`0771ca5`，干净 clone） | 同 ② | `rc=0` · `#5 60 … ✓17 ✗0 SKIP1` · `✓ P212 真实账本：无命中（… hits=0 …）`（SKIP 是 clone 里没有被忽略的禁令名单文件，属可见跳过） |

两份 §60 全量输出与返修前后的 ledger-ban 输出补进证据包（`accept/`）：`p237-60-before.log`、
`p237-60-after.log`、`p237-ban-before.log`、`p237-ban-after.log`。
