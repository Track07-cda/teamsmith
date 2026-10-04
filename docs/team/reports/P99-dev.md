# P99 · `roster-writer-and-route-truth` apply（名册的唯一授权写入路径 + 用法诚实性走查）· **apply** · dev

agent: dev   status: **DONE**
time: 2026-09-28（上一会话在 08:42 因换模型重启；本会话在 tip `72e7d503` 上重跑了全部验收命令）
branch: `task/P99-apply`（local 模式：**不 push**，分支留给 PM 合并；基点 `085d136a`。main 已前进（含 P95 的 `8617b826`），合并时有 `tests/smoke.sh` 一处 append 冲突（两个 §50、同一插入点）——解法见 §6.2）
change: `roster-writer-and-route-truth`（提案复验 `docs/team/reviews/roster-writer-and-route-truth-proposal.md` ACCEPTED）
deltas: `memory-and-deps`（MODIFIED）· `init-skill`（MODIFIED）· `dispatch`（ADDED ×2）；brief 硬要求 1–8 全兑现
grant 内改动（18 文件，+1395/−51）:
`scripts/lib/{cmd-agents,cmd-config,cmd-project,cmd-meeting,cmd-update}.sh` · `scripts/team`（一行 help 注册表）·
`tests/config-cli.sh` · `tests/routes.sh`（新）· `tests/smoke.sh`（append-only §50）·
`SKILL.md` · `references/{config,protocol,workflows,troubleshooting}.md` · `teamsmith-init/SKILL.md` ·
`openspec/changes/roster-writer-and-route-truth/specs/{dispatch,init-skill,memory-and-deps}/spec.md`
证据: `docs/team/reports/P99-dev/logs/`（15 份原始输出：claims before/after、routes 全绿 + 七翻转、
config-cli roster、manual 端到端、trial archive、递归事故记录、FAST 与交付全量门禁日志）

**总结论**：名册有了**唯一一条授权、审计的 CLI 写入路径**（`team add-agent <a> --register` /
`team teardown --agent <a> --register`，`TEAM_AGENTS` 仍是 `refuse` 类，控制台照旧写不了），
`add-agent --model` 从「help 印了但解析器拒绝」变成真写席位模型；`team help` 的每条用法行、每条
schema 注释承诺、每条点名命令都有夹具兑现（`tests/routes.sh`，七条翻转证明它在真树上会红并点名）。
四个字段复现（字段 → 修复）见 §2，翻转证据见 §4。三条验收命令在本 tip 上重跑全绿；`openspec validate`
的唯一红（`gate-section-accounting`）是**基点就有的外部 change 红**，本 change 自己的 validate 从红转绿，
详见 §5.4 与 §6.1。

## 1 · 交付物（硬要求 → 落点）

| brief 硬要求 | 落点 | 证据 |
|---|---|---|
| 1 名册唯一授权路径；无 `--register` 拒绝并给两条真出路；删掉假的那句 | `cmd-agents.sh`（`team_cmd_add_agent`）；`cmd-config.sh:1045` 的 `set-agent-model` 拒绝行；schema `TEAM_AGENTS` 注释 | `config-cli roster` ①②；`logs/manual-tip.log` §1/§2/§8 |
| 2 对称移除 + 审计一行 | `cmd-agents.sh`（`team_cmd_teardown --register`）；`team_config_write_roster remove` | `config-cli roster` ⑧；`manual-tip.log` §9 |
| 3 `set-agent-model` 对未入册席位给可执行答案 | `cmd-config.sh`:1046 第二行点名 `add-agent <seat> --register` | `config-cli roster` ⑪（3 条断言）；commit `72e7d503` |
| 4 `--model` 真支持（实现而非删 help） | `add-agent --model` → 与 `set-agent-model` 同一 pairlist 写入器；`--model -` 清覆盖 | `config-cli roster` ⑨；`manual-tip.log` §6/§7 |
| 5 用法诚实性检查（help↔解析器、schema 注释↔承诺、反向翻转） | `tests/routes.sh`（Walk A / 非空洞控制 / Walk B 承诺探针 / 七翻转）；`smoke.sh` §50 接线 | `logs/routes-tip.log` ✓170 ✗0；`logs/routes-full.log` 七翻转全绿 |
| 6 delta 按归档后 base 重写（D40），不丢 base 场景 | `specs/{init-skill,dispatch,memory-and-deps}/spec.md` | `logs/trial-archive.log`（场景数 before→after，`- 0`） |
| 7 `TEAM_AGENTS` 仍是 `refuse` | 类检查在值规则之前（`cmd-config.sh` 未动）；新入口走独立写入器 | `config-cli roster` ②（class=refuse + sha 不变）；`manual-tip.log` §8 |
| 8 零回归 | 见 §5 | validate：基点 ✗2 → tip ✗1（本 change 自己由红转绿）；FAST/全量见 §5.5/§5.6 |

### commits（小步，各带 `Agent: dev` 尾注；任务号 P99 在 subject）

- `b617cae2` — `docs(openspec): P99 rewrite the init-skill delta against the post-archive base`
- `37801613` — `feat(teamsmith): P99 the roster's one audited entry, the list value rule and the honest routes`（实现主体）
- `114995e0` — `test(teamsmith): P99 the route-sincerity walk (Walk A/control/Walk B/flips)`
- `212e56f1` — `fix(teamsmith): P99 the route walk no longer runs itself — flips never run flips`（事故修复）
- `21cba1f5` — `fix(teamsmith): P99 the roster value rule holds where it was skipped`（两个洞）
- `13945185` — `test(teamsmith): P99 the roster fixtures — seven shapes, one value rule, CAS, audit`
- `11330e8e` — `test(teamsmith): P99 the correctness gate runs the route walk and the register fixtures`
- `3636dd3b` — `test(teamsmith): P99 the remaining roster scenarios — help lines, worktree-step parity, audit order`
- `019fb40d` — `docs(openspec): P99 the delta says what the writer really writes, and what the no-op really is`
- `aa27e584` — `test(teamsmith): P99 the walk's awk loop variable no longer collides with P80's one-implementation guard`
- `72e7d503` — `test(teamsmith): P99 set-agent-model's unknown-seat refusal is asserted to name a route`

## 2 · 四个字段复现（before → after）

同一份 claims 脚本（`docs/team/reports/P99-dev/claims.sh`，自建 scratch 仓库 + `team init --agents "dev verify"`；
用法 `bash claims.sh <tree-root>`）跑在
**基点树**（`git archive 085d136a` → `/tmp/p99-base`）与**交付树**上：`logs/claims-before-base-085d136a.log`
vs `logs/claims-after-tip.log`。

| 字段复现 | before（基点 `085d136a`） | after（tip `72e7d503`） |
|---|---|---|
| **claim 1** 无旗标未知席位 | `✗ 未知 agent：dev2（名册：dev verify ）`，**exit=1**，没有出路 | `✗ 未知 agent：dev2…` + 两条真路线（`--register` / 手改 config.sh）+ 明说零副作用，**exit=5** |
| **claim 2** `config set TEAM_AGENTS` 拒绝行 | `名册：team add-agent / team teardown`（假路线） | `名册：team add-agent <a> --register / team teardown --agent <a> --register（都走审计写入器）` |
| **claim 3** `add-agent dev --model vendor/m9`（help 印 `[--model m]`） | `✗ add-agent: 未知参数 --model`，exit=2，`TEAM_AGENT_MODELS=""` | exit=0，`TEAM_AGENT_MODELS='dev=vendor/m9'`，一行 `result=ok` 审计 |
| **claim 4** schema `TEAM_AGENTS` 注释 | `名册：team add-agent / team teardown` | 同上（真实入口 + 审计） |
| **claim 5** init skill 句子 | `` `team add-agent <name>` adds more at any time `` | `` `team add-agent <name> --register` grows…（both audited…） `` |
| **claim 6** help 行 | `add-agent <a> [--model m]` / `teardown [… --purge]` | `add-agent <a> [--register] [--model m] [--create] [--no-install] [--print]` / `teardown [… --force] [--register]` |

另外三条洞（同上日志，before 会走到非法路径）：

| 洞 | before | after |
|---|---|---|
| A 名册 `dev api api` + `add-agent api --register` | `未知参数 --register` exit=2 | exit=4 点名重复 token（no-op 不豁免值规则） |
| B 名册 `dev api/1` + 无旗标 `add-agent api/1` | 继续走到 worktree/state，裸 bash 报 `state/api/1.env: No such file or directory` rc=1 | exit=4 点名 `api/1` 与接受形状，什么都没建 |
| C 名册 `dev api/1` + `add-agent api/1 --register` | `未知参数 --register` exit=2 | exit=4，审计一行 `result=invalid` |

## 3 · 实现要点

- **R1 写入器**：`team_config_write_roster`（`cmd-config.sh`）是 `TEAM_AGENTS` 唯一的读-改-写入口，
  复用 `team_config_set_in_file`（字节保全 / 原子 / `bash -n`）与 `team_config_write_checked` 的尾巴
  （审计 + CAS 词汇）。值规则 `team_config_list_violation` 只有一份：写侧校验**结果值**，读侧
  `config list --json` 把它作为 `TEAM_AGENTS.warning`（点名 token）；`team config set TEAM_AGENTS` 的
  `refuse` 类检查仍在最前（spec 的 R1 红线）。
- **R2 两个 CLI 入口**：`add-agent --register [--model m|-] [--fingerprint sha256]`、
  `teardown --agent a --register [--fingerprint sha256]`。写序：模型形状先判 → 名册写 → 席位模型写 →
  今天的 worktree 步骤；`--register` 对已在名册席位是可见 no-op（0 / 不写 / 不审计），但**值规则不豁免**
  （脏名册 exit 4）；`teardown --all --register` / 缺 `--agent` 是用法错 exit 2；名册外席位 exit 5。
- **R2.3 copy sync + 两处解析器修复**：help 的 `add-agent`/`teardown` 行带全旗标、`board add|…` 行补两格
  缩进（Walk A 的不可归属行）；`cmd-update.sh version` 与 `cmd-meeting.sh meeting list` 补 `-*)` 未知参数
  拒绝（控制臂要求的两个「吞旗标」命令，`reload` 已拒绝、未动）。这两处解析器修复是设计 D6 / tasks 3.3
  明列的改动（brief 的 grant 行以「两个 parser fixes」计入），不是自选范围。
- **R3 走查**：`tests/routes.sh` 四段（walk / control / promises / flips），自建 `mktemp -d` 夹具 +
  缺席应答的 tmux shim（记录变更、`has-session`→1）+ `TEAM_PI_BIN=/bin/true` + stdin `/dev/null` +
  每探针超时 + EXIT trap 全回收；`smoke.sh` §50 接线（FAST 透传，flips 一行可见 SKIP）。
- **R4 文案**：`teamsmith-init/SKILL.md` 名册句带 `--register`（100 行上限内）、`SKILL.md` 命令表、
  `references/{config,protocol,workflows,troubleshooting}.md` 的 refuse 行与名册配方；`config.md` 记录了
  两个入口的 `--fingerprint`。
- **D40 delta 重写**：`init-skill` 的 MODIFIED 块按**归档后**（含 npm 场景）的 base 重写，
  `dispatch`/`memory-and-deps` 保留全部 base 场景（§4.4 的 trial archive 证明 `- 0`）。

## 4 · Flip evidence（红 → 绿）

### 4.1 四个字段复现

见 §2：`logs/claims-before-base-085d136a.log`（红侧）→ `logs/claims-after-tip.log`（绿侧），
两条日志逐项对应、可重跑。

### 4.2 七条 walk 翻转（把树改坏 → walk 必须红并点名）

`logs/routes-full.log`（routes.sh 的完整跑，含 flips）：

```
  ✓ 翻转①：help 打印 --model 而解析器拒绝 → walk 红并点名 add-agent --model
  ✓ 翻转②：add-agent 行印上兄弟命令的 --fresh → walk 红并点名 add-agent --fresh
  ✓ 翻转③：ps 吞掉未知旗标 → 控制臂红并点名 ps
  ✓ 翻转④：命令块里的列 0 行 → walk 红并点名该行（修复前的 board 形状）
  ✓ 翻转⑤：TEAM_GATES 的注释点名 team frob → walk 红并点名 TEAM_GATES / team frob
  ✓ 翻转⑥：新键的注释点名命令却没有探针 → walk 红并只点名该键
  ✓ 翻转⑦：注册报成功而名册没变 → promise 探针红并点名 TEAM_AGENTS（断言的是效果）
  ✓ 翻转收尾：嵌套 run 的临时根都回收了
== 结果 ==  ✓ 170  ✗ 0  SKIP 0
```

第①条同时是 brief 要求的**反向**（help 留 `--model`、解析器删掉 → 必须红）。本 tip 的独立复跑
（`logs/routes-tip.log`）同样是 ✓170 ✗0、120.8 s、`$TMPDIR` 无残留、`git status --porcelain` 不变。

**上一会话的事故与修复（翻转本身的有效性）**：flips 段最初给任何子集追加 flips，每个 flip 的嵌套
`routes.sh walk` 又追加 flips —— 08:08→08:20 进程链每 ~40 s 长一层、32 个进程、跑 12 分钟不返回，只能人工
按 pid 清（`logs/recursion-chain.txt`、`logs/section-rule-before-after.txt`）。修法：段集显式
（裸跑 = walk+control+promises+flips；子集不追加）+ `TEAM_ROUTES_NESTED=1` 的嵌套 run 打印可见 SKIP
（结构守卫，commit `212e56f1`）。修复前的 flips 段是 ✓1 ✗7（嵌套 run 因 scratch 树没有 `tests/perf.sh`
全部 exit 3，`logs/flips-before-114995e0.log`）—— 即**翻转证据在修复前根本不成立**，修复后才产出上面的七条。

### 4.3 名册写入器的 raw 证据（`logs/manual-tip.log`，由同目录 `manual.sh` 端到端一次跑完）

```
=== 1 register add ===
  sha changed: yes; roster: TEAM_AGENTS='dev verify api'; audit+1
2026-09-28T08:55:35Z result=ok actor=cli key=TEAM_AGENTS old='dev verify' new='dev verify api'
=== 2 flagless refusal ===   rc=5；sha unchanged；worktree/state 都没有
=== 3 re-register noop ===   rc=0；sha unchanged；audit+0
=== 4 stale fingerprint ===  rc=3；sha unchanged
2026-09-28T08:55:35Z result=conflict actor=cli key=TEAM_AGENTS old='dev verify api' new='dev verify api api3' expected=deadbeef actual=7cc7d037…
=== 5 invalid tokens ===     api/1 → rc=4；pm → rc=4
=== 6 model ===              TEAM_AGENT_MODELS='dev=vendor/m2' + result=ok；`--model -` 清空
=== 7 model shape error ===  rc=4；sha unchanged；audit+0；名册未动
=== 8 config set refusal === rc=5，点名 --register
=== 9 teardown ===           --register rc=0，名册回 'dev verify' + 一行 ok；--all --register rc=2；nosuch rc=5
=== 10 warning/route ===     warning: 席位名 api/1 非法…；route: 名册：team add-agent <a> --register / …
=== 11 version/meeting 控制 == version --frobnicate-probe rc=2；meeting list --frobnicate-probe rc=2（修复前两者 exit 0）
```

`config-cli.sh list validate roster`（fresh，`logs/config-cli-fresh.log`）把同样七组形状钉成 103 条断言
（✓103 ✗0），含「读侧 warning 的 token = 写侧拒绝的 token（一份规则）」「陈旧 `--fingerprint` 恰好一行
conflict、零字节写入」「审计顺序：名册行在前、席位模型行在后」。

### 4.4 trial archive（D40：MODIFIED 不丢 base 场景）

`cp -r openspec /tmp/trial-p46 && (cd /tmp/trial-p46 && openspec archive -y roster-writer-and-route-truth)`
的输出（`logs/trial-archive.log`）：

```
Totals: + 2, ~ 2, - 0, → 0
dispatch: scenarios 49 -> 65
init-skill: scenarios 32 -> 33
memory-and-deps: scenarios 55 -> 58
verification: scenarios 83 -> 83
dispatch requirements 13 -> 15
```

`- 0`：没有丢任何 base 场景；`dispatch` 的两条 ADDED requirement、`init-skill`/`memory-and-deps` 的 MODIFIED
重写块（含 npm 归档后的场景）都在。

## 5 · 验收命令与结果（本会话在 tip 上重跑）

### 5.1 `bash skills/teamsmith/tests/routes.sh`

```
== 结果 ==  ✓ 170  ✗ 0  SKIP 0        （exit 0，120.8 s；logs/routes-tip.log）
```
Walk A：help 的每条用法行一条断言（不可归属行不是 SKIP）；控制：打印旗标的每条路径必须拒 `--frobnicate-probe`；
Walk B：schema 注释点名的每条命令 ↔ 六组承诺探针（断言效果，不看退出码）；flips 七条全绿。

### 5.2 `bash skills/teamsmith/tests/config-cli.sh list validate roster`

```
== 结果 ==  ✓ 103  ✗ 0  SKIP 0        （exit 0；logs/config-cli-fresh.log）
```
R1/R2 的七组形状：flagless 拒绝（两条路线 + 零副作用）、`config set` 仍 refuse 且点名 `--register`、
register 一行 diff + 一行 ok 审计、no-op、陈旧指纹 conflict、非法 token 4、脏名册读/写同 token、
teardown 四形状、`--model` 写/清、坏形状零写入、`set-agent-model` 未入册席位给路线。

### 5.3 `bun skills/teamsmith/tests/skill-load.mjs skills/teamsmith-init`

```
✓ pi 解析器加载成功：name=teamsmith-init desc=800 字符 诊断=0     （exit 0；wc -l = 100）
```
（本会话 PATH 里没有 `bun`，按 brief 的写法补 `PATH="$HOME/.bun/bin:$PATH"` 后运行。）

### 5.4 `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`

```
tip  : 16 passed, 1 failed (17 items)   Details: openspec validate gate-section-accounting --type change
base : 15 passed, 2 failed (17 items)   （gate-section-accounting + roster-writer-and-route-truth）
main : 18 passed, 0 failed (18 items)
```

本 change 自己的 validate **由红转绿**（base 失败 → tip 通过）；剩下的 `gate-section-accounting` 是基点就有的
**外部 change** 的红，与本 diff 无关，详见 §6.1。

### 5.5 FAST 门禁（本会话重跑，`TEAM_SMOKE_FAST=1`）

```
FAST_RC=0
== 结果 ==  ✓ 2814  ✗ 0
FAST 模式：跳过 33 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
```
（`logs/gate-fast-tip.log`。上一会话的 `logs/gate-fast-1.log` 已改名 `logs/gate-fast-p80-red-before-aa27e584.log`——那是 P80 守卫修复前的现场：✓2813 ✗1，已被本跑取代。）

§50 的两条断言在本跑里：`✓ 50 routes.sh 全绿（163 条断言，2 条可见跳过）`、`✓ 50 名册/契约夹具（list+validate+roster）全绿（104 条断言）`。

### 5.6 全量门禁（交付前一次）

上一会话以同一 tip 启动（08:44），排队后在 08:52:49 取得门禁锁，09:15:19 结束：

```
== 结果 ==  ✓ 3479  ✗ 0
smoke 全绿
```

（`logs/gate-full-tip.log`。P99 的两段在全量里：`✓ 50 routes.sh 全绿（171 条断言，1 条可见跳过）`
——全量跑完 7 条翻转；`✓ 50 名册/契约夹具（list+validate+roster）全绿（104 条断言）`。）

全量跑在代码 tip `72e7d503` 上；其后到交付 tip 之间只有本报告与证据日志的提交——
`git diff 72e7d503..HEAD --name-only` 全部落在 `docs/team/reports/P99-dev*`，代码/测试/spec 未再动。

## 6 · 给 PM 的说明 / 未决

### 6.1 `openspec validate` 里唯一的外部红（不是本 diff 造成的）

`gate-section-accounting`（P56 的 propose，`c8019d73`）的 MODIFIED「The correctness gate judges correctness
only」块漏了四条当前 spec 已存在的场景：`A machine over the premise skips visibly…`、
`The premise is not an escape from a real regression`、`A skipped fixture is never reported as a passing one`、
`The premise's readings stay real on the real path`。已测：这四条只在 **pty-fixture-load-premise 归档已合入**
的 base 里（本分支基点 `085d136a`）存在；main 把它们 revert 了（D52 的 hold），所以 main 上 validate 全绿。
即：这是 D52「held archive ↔ 依赖它的 delta」的排序问题，**不是本任务能改的文件**（不在 grant 里）。
PM 重新 cherry-pick 归档时需要顺带让 P56 的 delta 带上这四条场景（或由 P56 apply 重写），届时 validate 才会 0。

### 6.2 与 main 的合并：只有 `tests/smoke.sh` 一处 append 冲突（PM 侧解）

在 tip 上做只读合入模拟（`git merge-tree --write-tree --name-only HEAD main`，git 2.53）：

```
Auto-merging skills/teamsmith/references/troubleshooting.md
Auto-merging skills/teamsmith/tests/smoke.sh
CONFLICT (content): Merge conflict in skills/teamsmith/tests/smoke.sh
```

唯一冲突：main 的 P95（`8617b826`）在 §49 之后加了自己的 `section "50 · P95 合并基准 = 该任务的 squash 提交…"`，
本任务在同一插入点加了 `section "50 · 用法诚实性…"`（两个 §50 撞号 + 同一位置）。解法：**两段都留**，
把本任务这段改号为 §51，并同步该段内 7 处以 `"50 ` 开头的断言前缀（`grep -n '"50 ' tests/smoke.sh`）；
`troubleshooting.md` 自动合并、无冲突。本分支没有自带这个改号：改了会让正在跑的交付全量门禁失去意义、
要重跑约 40 分钟，而这类 append 改号此前也是 PM 侧在合并时完成的（P53/P41 先例）。

### 6.3 本 change 的合并顺序（D40 / D52）

本 change 的 `init-skill` MODIFIED 块是按**post-npm-archive** 的 base 写的（brief 的 D40 明确要求）；
main 当前把 npm/pty 归档 revert 了，直接合本分支再 cherry-pick 归档时，本 delta 的 MODIFIED 块会**多带回**
npm 场景（这是 trial archive 的 `- 0` 要保的东西）。按 D52 的顺序（先归档、再合本分支）不会冲突；
PM 合并时以此为准。

### 6.4 两个过程性事实

- **递归事故**（§4.2）是上一会话把 flips 段写坏造成的，已按 pid 清理干净（无残留进程 / `/tmp` 目录），
  修复是结构性的（段集显式 + 嵌套 SKIP），不是靠超时兜底。
- **P80 一处实现守卫**：walk 里 awk 的 `for (k=…)` 命中了 smoke §P80 的
  「`tests/**` 里没有第二份几何/候选循环实现」模式；smoke 对本任务是 append-only，所以改 walk 的循环变量名
  （`kk`，commit `aa27e584`），行为不变。旧的 `logs/gate-fast-p80-red-before-aa27e584.log` 里那 1 红就是它，
  fresh FAST 已绿（§5.5；FAST 不排队，与同机全量门禁并行不互斥）。

### 6.5 未决 / 交给复验的点

- `team_require_agent` 的 `未知 agent：…（名册：…）`（`dispatch`/`say`/`notify` 路径）仍不带路线，属该
  change 的 Non-Goals + 设计 §5.6 的 one-line follow-up；本任务未动。
- Flips 段在完整门禁里每次重跑 ~120 s（routes.sh 独立运行才是完整 7 条翻转；§50 里 FAST 可见 SKIP，
  全量才跑）——这是设计的取舍（翻转必须跑在 scratch 树上），不是 flake。
