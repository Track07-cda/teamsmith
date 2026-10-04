# P159 · `safe-signal-discipline` apply：模式选进程一律 fail-closed，信号只按记录的 pid

agent: dev-bob   status: done   time: 2026-10-02
branch: `task/P159-apply`   PR/MR: -（local 模式：分支留在本地工作树，未 push）
change: `safe-signal-discipline`（phase `apply`；`deltas: boundary`；分叉点 `690fcfd6`，`main@2b244212` 已于 `9ace3da3` 合入；两次 PM 的 wip 快照在其后）

> 这一轮是**断点续跑**：07:13 / 08:00 共享 tmux server 两次死亡把窗口带走，PM 把未提交的工作快照成
> `beeaeef4` / `b9b28aa6` 两个 wip 提交。我从 `b9b28aa6` 接着做，先补上报告里缺的夹具与门禁段，
> 再补 5.x 的契约/文档，最后跑门禁。开工时磁盘上的进度：闸门实现、`team bg` 实现、lexer 抽取、
> signal lint、harness S13、`signal-gate.sh` 都在（前 6 个提交），**缺** `team-bg-stop.sh`、smoke 段、
> 契约行、文档，以及三条红侧证据。

## 0. 纪律两条（PM 2026-10-02 的临时纪律与我的回答）

1. **门禁一律在容器里跑**（`localhost/teamsmith-gate:local`，容器自带 /tmp 与自己的 tmux server）。
   本轮所有夹具、lint、FAST/全量门禁、以及 `--select` 都在容器里跑；容器脚本见
   `docs/team/reports/P159-dev-bob/pkg/ct.sh`（把**整个 pm-skills 仓库**按宿主同路径挂进去，
   只挂 worktree 会让 `.git` 指针解析不到）。
   **我在宿主上跑过的**：`openspec validate --all --strict`（只读）、`config-cli.sh completeness docs json`
   （纯逻辑 + 私有临时根）、`section-select.sh --check`、`section-guard.sh --budget-check`、
   `panel-strings.mjs`、`cmp/sha256sum`、以及两次 `perl tests/signal-lint.pl`（只读扫描）。
   这些都不碰 tmux（`config-cli.sh` 那一段会在**私有临时根**里起 panel.js / team CLI 的进程；
   `section-*` 与 lint 是纯逻辑）；**没有**看到过「tmux 隔离：私有 socket 没生效」这类红。
2. **P159 夹具「绝不执行真 pkill/killall」不再是自述，而是容器内的构造证明**（见 §F4 见证跑）：
   `/usr/bin/pkill`、`/usr/bin/killall` 在容器里被替换成 argv 记录桩，任何一次真身执行都会留字。
   绿侧 + 红侧跑完，`witness.log` 为空 —— 真身一次都没被调用。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/shim/signal-gate`（+ `pkill`/`killall` 入口） | 闸门本体：一切选择形态 exit 64（不解析真身、不发信号），只读四词（`--help/-h/-V/--version`）透传；每次调用一行审计，拒绝逐字节进 `<log>.forensics`（熬得过轮转）；写失败可见但不改判定 |
| `skills/teamsmith/scripts/lib/common.sh` | `team_tmux_shim_exports` 的同一段前缀多两个 pin：`TEAM_SIGNAL_CALLS_LOG`、`TEAM_SIGNAL_REAL`（不写任何授权变量） |
| `skills/teamsmith/extension/team-bg.ts` | 作业身份记录 `state/bg/<id>.job`（id/pid/pgid/start/cwd/log/cmd），在返回 job id **之前**落盘 |
| `skills/teamsmith/scripts/lib/cmd-bg.sh` + `scripts/team` | `team bg list`（只读、一行一作业、逐行标身份）/ `team bg stop <id>`（身份 = pid + 启动时间指纹；组 TERM→KILL；退出码 0/2/3/4/5/6；每个拒绝零信号） |
| `skills/teamsmith/tests/lib/shell-lex.pl` + `tests/tmux-lint.pl` | 词法器抽出（tmux lint 改为 require），`--list` 在真树上逐字节不变 |
| `skills/teamsmith/tests/signal-lint.pl` + `signal-lint-legacy.txt` + `fixtures/signal-lint-cases.txt` | 静态那一半：模式选择红（含 `command`/`env` 前缀、字面绝对路径、`xargs kill`、`kill $(pgrep …)`），pid 精确形态干净；历史证据包按 sha256 冻结 |
| `skills/teamsmith/tests/signal-gate.sh` | RA1/RA2 夹具（62 断言）+ `--break=pass` 红侧 |
| `skills/teamsmith/tests/team-bg-stop.sh` | RA3 夹具（37 断言）+ `--break=no-identity` 红侧 |
| `skills/teamsmith/tests/team-bg-harness.mjs` | S13：记录字段与活进程/`/proc` 逐项相同；`--record-only` 把 id/root 交给门禁段（段内 `team bg stop` 真停） |
| `skills/teamsmith/tests/smoke.sh` | 新段 **58**（lint + 两只夹具 + harness S13 + 段内 stop），M8.1 逐字节参考前缀补信号两段，M36 窗口断言补 `pkill`/`killall` 解析与信号 pin，M25 清理改 pid 形态 |
| `tests/section-paths.tsv` / `section-budgets.tsv` | 段注册：6 条真实路径 token；容器实测 7s → band 7 / budget 60 |
| `scripts/lib/cmd-config.sh` / `panel/src/strings/{zh,en}.ts` / `panel.js` / `references/config.md` / `references/protocol.md` / `SKILL.md` | 三个新旋钮登记为 `refuse` 行 + zh/en 标签 + 文档行；protocol.md 补记录/身份/拒绝文案/闸门触达；SKILL.md 命令表补 `team bg list|stop <id>` |
| `tests/routes.sh` | Walk B 的 `bg-stop-grace` 探针（宽限 0 不等待 / 2 等够，账本 `signal=TERM,KILL`） |
| `docs/team/reports/P159-dev-bob/pkg/` | `ct.sh`（容器跑法）、`run-witnessed.sh`（见证跑）、`tmux-lint-list-{before,after}.txt` |
| `docs/team/reports/P159-dev-bob/logs/` | 每条验收命令的原始输出 |

提交（`task/P159-apply`，15 个：前 8 个是断点前 PM 已快照的进度 + 合入 main）：

```
1a987379 fix(bg/routes): the KILL escalation reports reality, and the grace knob gets a probe (P159)
8a94814c feat(smoke): section 58 runs the signal discipline end to end (P159)
40b904ec feat(config/docs): register the three signal-discipline keys (P159)
192f85b6 feat(tests): the team bg stop fixture pins identity, refusals and reach (P159)
59157b83 feat(tests): the bg harness records the job identity (S13 + --record-only) (P159)
69c99b7a fix(tests): the signal gate fixture cannot fall back to the real pkill (P159)
b9b28aa6 wip(dev-bob): PM snapshot of work in progress when the shared tmux server died (2026-10-02 08:00)
9ace3da3 Merge branch 'main' into task/P159-apply
beeaeef4 wip(dev-bob): PM snapshot of uncommitted work when the tmux server died (2026-10-02 07:13)
b0e3ba81 feat(tests): signal lint keeps scripts off name/pattern selection
98de0eab refactor(tests): extract the shell lexer into tests/lib/shell-lex.pl
bb0c4436 feat(team-bg): team bg list|stop signals only the recorded job
5a8f972e feat(team-bg): record each job identity before the id is returned
1689700b feat(signal-gate): carry the signal pins in the one launch prefix
1ce8dcd0 feat(signal-gate): refuse every pkill/killall selection and record the call
```

## Recon（开工时的现状，只读取证）

`docs/team/reports/P154-dev-bob/recon.log`（propose 阶段，PM 已验收）里的四条现状在本轮开工时依然成立，
我按它开工并逐条对照：闸门目录只有 `tmux`（`pkill`/`killall` 解析到 `/usr/bin`）；模式选择同时命中
两个诱饵与调用者自己的 shell；`kill -TERM <记录过的 pid>` 只动一个进程；`team bg` 当时不是子命令、
`state/bg.log` 里没有 pid；tmux 隔离 lint 在 `tests/smoke.sh` 自己那两条 `pkill -f` 现身前照样全绿。
断点续跑时我又确认了一遍落点（`git log`/`git diff main...HEAD`/未跟踪文件），没有重复劳动。

## Delta → requirement map（照 `tasks.md` 的覆盖映射）

| Delta | Requirement | 覆盖它的 scenario | 由哪些 item 落地 |
|---|---|---|---|
| MODIFIED | `boundary#The gate's actions are logged, and no window carries a destructive-call grant` | 基线 7 条逐字保留 + `The rendered window carries the whole gate family` + `The window's gate resolves the name-selecting tools` | 1.3、1.4 |
| ADDED | `boundary#Signals go to a recorded pid, never to a name or a pattern` | 5 条（拒绝每一种选择形态 / 诱饵活着 / 真身零调用 / 继承环境不授权 / 只读透传 / `kill <pid>` 仍通） | 1.1、4.1 |
| ADDED | `boundary#The signal gate's calls are recorded, and its refusals outlive the call log's rotation` | 4 条（一行一调用 / 拒绝逐字节进 `.forensics` / 轮转标记自述 / 保留失败可见不改判定 / pass 不保留 / FIFO 不挂住） | 1.2、4.1 |
| ADDED | ``boundary#`team bg` stops a job by the pid it recorded, and prints what it signalled`` | 4 条（真作业停掉且邻居活 / 未记录 id=3 / 畸形=4 / pid 复用=5 / 已完成 no-op 不追猎） | 2.1–2.4、4.2 |
| ADDED | `boundary#Scripts select processes by recorded pid, and the lint keeps it that way` | 3 条（真树干净 + scratch 翻转 / 模式与谓词形态红 / pid 精确形态干净 / 历史豁免机制） | 3.1–3.4、4.3 |

## 逐条交付与证据（实际跑过的）

### 1 · 信号闸门与它的记录（RA1/RA2/RM）

- **1.1/1.2/4.1**（`tests/signal-gate.sh`，容器，`logs/03-signal-gate-green.txt`）：

```
== RA1 · 模式选择一律拒，且两个诱饵都活着 ==
  ✓ pkill -f <marker> 退出 64 / ✓ 拒绝文案点名 pkill 与完整 argv / ✓ 拒绝文案说清「模式不是身份」
  ✓ 拒绝文案给出安全路线 team bg stop <id> / team bg list / kill <记录过的 pid>
  ✓ 桩一个调用都没收到（拒绝不执行真身） / ✓ 诱饵 A 还活着 / ✓ 诱饵 B 还活着
== RA1 · 每一种选择形态都被拒 ==        （-x / -P / -u / killall）
== RA1 · 继承环境不授权 ==              （TEAM_ALLOW_PATTERN_KILL=1 仍 64、子 shell 同样 64）
== RA1 · 只读四词原样透传（记 act=pass）==（--help/-h/-V/--version 逐字节到桩；退出码原样来自真身）
== RA1 · pid 精确路线照旧通 ==          （kill -TERM <记录过的 pid> 只收掉那一个；闸门不为 kill 记行）
== RA1 · 拒绝不依赖真身能否解析 ==      （TEAM_SIGNAL_REAL 指向不存在的路径仍 64）
== RA2 · 两行日志 + 拒绝逐字节进 .forensics ==
== RA2 · 拒绝熬得过主日志轮转 ==        （首行 rotation 标记 dropped=1101；标记 + 1000 条调用行）
== RA2 · 保留写失败：可见、不改判定、不挂住 ==（目录当保留路径 → 仍 64 + ✗ + retention=failed）
== RA2 · FIFO 目标不挂住 ==
== signal-gate 结果 == ✓ 62  ✗ 0
```
（段 58 打印的「63 条断言」是 `grep -c '✓'` 数的，多算的那一条就是夹具自己的结果行 `== signal-gate 结果 == ✓ 62 ✗ 0`；
`team-bg-stop` 的 37/38 同理。）

- **1.3/1.4**（`logs/01-launch-prefix.txt`；窗口里的读回由 M36 段在门禁里跑）：

```
export PATH=…/skills/teamsmith/scripts/shim:"$PATH"; export TEAM_TMUX_CALLS_LOG=…/.pi/team/state/tmux-calls.log;
export TEAM_TMUX_REAL=/usr/local/bin/tmux; export TEAM_SIGNAL_CALLS_LOG=…/.pi/team/state/signal-calls.log;
export TEAM_SIGNAL_REAL=/usr/bin/pkill;
→ 同一段前缀里没有 TEAM_ALLOW_/ALLOW_PATTERN/DESTRUCTIVE（符合契约：环境不授权）
```
  真窗口那一半（worker 与 PM 窗口的 `env` 读回）由 M36 段新增的 4 条断言钉住：`pkill_at=<shim>/pkill`、
  `killall_at=<shim>/killall`、`TEAM_SIGNAL_CALLS_LOG` 指向本项目 state、`TEAM_SIGNAL_REAL` 绝对路径，
  以及「env 里没有任何信号授权键」。**这两条腿需要真 tmux，只在全量门禁里跑**（FAST 里是可见 SKIP）。

### 2 · 作业记录与 `team bg stop`（RA3）

- **2.1/2.4**（`team-bg-harness.mjs`，容器）：

```
TEAM-BG-CASE PASS S13 the job record exists :: /tmp/…/.pi/team/state/bg/p159-record.job
TEAM-BG-CASE PASS S13 record id/pid match the live process :: {"id":"p159-record","pid":836626,"live":true}
TEAM-BG-CASE PASS S13 record pgid is the live pid's process group (detached spawn ⇒ pgid == pid) :: record=836626 proc=836626
TEAM-BG-CASE PASS S13 record start is the /proc/<pid>/stat start-time fingerprint :: record=18505792 proc=18505792
TEAM-BG-CASE PASS S13 record carries cwd/log/cmd :: {"cwd":"/tmp/teamsmith-bg-ww37ju/repo","log":"…/p159-record.log","cmd":"sleep 300"}
TEAM-BG-RECORD id=p159-record pid=836626 root=/tmp/teamsmith-bg-ww37ju/repo record=… state=…
TEAM-BG-HARNESS OK
```

- **2.2/2.3/4.2**（`tests/team-bg-stop.sh`，容器，`logs/04-team-bg-stop-green.txt`）：

```
== RA3 · 真作业按记录停掉：job 死、邻居活、账本留痕 ==
  ✓ list 里作业行标 identity=holds / ✓ list 行带 pid 与 cmd
  ✓ team bg stop job1 退出 0 / ✓ 输出点名 job/signal/result / ✓ 输出点名被停的命令
  ✓ 作业 leader 已被停掉 / ✓ 没有记录的邻居仍然活着（只停了记录里的那个）
  ✓ state/bg.log 记下 stop 行 / ✓ stop 只追了 1 行账本
== RA3 · 无记录 → 3 / 记录畸形 → 4 / pid 复用（指纹对不上）→ 5 ==（三条都 ✓ 邻居照旧活着）
== RA3 · 记录只认本项目 state ==        （兄弟 state 目录里的 id → 3；list 不列它）
== RA3 · 已结束的 leader：rc=0，不追猎活着的子孙 ==
== RA3 · 用法：没有子命令 / stop 缺 id → 2 ==
== team-bg-stop 结果 == ✓ 37  ✗ 0
```

- 段内端到端（`smoke.sh` 58 段，容器，`--select 58` 的输出）：

```
✓ 58 harness S13：真扩展写的作业记录（5 条断言，job=p159-record pid=2602968）
✓ 58 段内 team bg stop 用记录停掉 harness 起的作业（rc）
✓ 58 stop 打印它信号了谁（result=stopped） / ✓ 58 stop 点名被停的命令
✓ 58 harness 作业已按记录停掉（pid 2602968 不在）
```

### 3 · lint 与模式清理（RA4）

- **3.1**（词法器抽取的不变量）：

```
$ cmp tmux-lint-list-before.txt tmux-lint-list-after.txt   → 逐字节相同
7ce64c816adeb5869510ad455ab53205ea9ecfb539676a1e222bd25316ec8cf9  （before == after）
```

- **3.2/3.3**（`logs/02-lint-selftest.txt` + 真树扫描）：

```
✓ signal-lint --selftest：29 个夹具 + 豁免机制全部符合预期（该红的红、该净的净）    rc=0
$ perl tests/signal-lint.pl
  LEGACY  docs/team/reports/M35-dev2/pkg/lib.sh  ×2  —— M35-dev2 证据包（P159 之前：M25 对照组的 pkill -f 清理）
signal-lint：红 0 条；另有 2 条落在**历史豁免**的 1 个文件里（按 sha256 冻结）      rc=0
$ perl tests/signal-lint.pl --no-legacy      → rc=1，点名 lib.sh:46/47
$ perl tests/signal-lint.pl --root skills/teamsmith/tests → 干净（扫描 80 个脚本）
```

- **3.4**：M25 夹具的两条 `pkill -CONT/-TERM -f` 已改成对**夹具自己定位到并记录过的 pid**
  （`kill -CONT "$M25_CPID"` + `kill -TERM "$M25_CPID"`，见 `smoke.sh` M25-② 收尾注释），
  M25 段在全量门禁里跑（见「门禁结果」的全量那一块）。

### 4 · 夹具与门禁段

- **4.1/4.2** 见 §1/§2 的绿侧；红侧见「Flip evidence」F1/F2。
- **4.3/4.4**（段注册与 FAST 行为）：

```
$ bash tests/section-select.sh --check        → == 选段自检 ==  ok 7  bad 0（120 段 / 120 行；435 个 token 被覆盖）
$ bash tests/section-guard.sh --budget-check  → ok: 预算表覆盖 120/120 且每行都满足 max(ceil(band×4), 60)
$ bash tests/smoke.sh --select 58             → == 选段结果 == ✓ 428 ✗ 0
   #13 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 7s · ✓12 ✗0 SKIP0 · ticks 12
```
  段 58 不请求私有 socket、不进容器、不点 `live_mark`，所以 FAST 下照跑（见「门禁结果」的 FAST 那一块）。

### 5 · 契约行、标签与文档

```
$ bash tests/config-cli.sh completeness docs json   → == 结果 == ✓ 15 ✗ 0（117 个键双向对齐）
$ node tests/panel-strings.mjs                      → ok: contract-key labels — 117 schema keys covered in zh and en；panel-strings: ok
$ bash tests/routes.sh promises                     → == 结果 == ✓ 17 ✗ 0（含两条新探针）
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 0 → 忽略 TERM 的作业被立刻 KILL（账本 signal=TERM,KILL，用时 0s）
  ✓ promise（TEAM_BG_STOP_GRACE）：宽限 2 → 先 TERM、等 2s 后 KILL（旋钮改变等待）
$ grep -c 'team bg stop' skills/teamsmith/SKILL.md skills/teamsmith/references/protocol.md → 1 / 2
```

```
$ team config list --json（三个新键的 class/kind/default/group）
TEAM_SIGNAL_CALLS_LOG → {'class': 'refuse', 'kind': 'path',    'default': '',  'group': 'policy'}
TEAM_SIGNAL_REAL      → {'class': 'refuse', 'kind': 'path',    'default': '',  'group': 'policy'}
TEAM_BG_STOP_GRACE    → {'class': 'refuse', 'kind': 'seconds', 'default': '5', 'group': 'policy'}
$ team config set <每个新键> x
三个都 rc=5 ｜ ✗ … 是只读键，控制台不改它 ｜ schema 未变=yes（一个字都没写）
```

三个新旋钮（`team config list --json` 里都是 `refuse` 行，写请求被拒；schema 与 `references/config.md`
双向对齐由 completeness 段守）：

| Key | class · kind | default | 标签（zh / en） |
|---|---|---|---|
| `TEAM_SIGNAL_CALLS_LOG` | refuse · path | 空 | 信号调用审计 / Signal call log |
| `TEAM_SIGNAL_REAL` | refuse · path | 空 | 信号真身 / Real signal tool |
| `TEAM_BG_STOP_GRACE` | refuse · seconds | 5 | 作业停止宽限 / Job stop grace |

## Flip evidence（红侧 → 绿侧，全部是原始输出）

### F1 · 闸门放行 = 夹具必须红（`--break=pass`）

```
$ bash skills/teamsmith/tests/signal-gate.sh --break=pass      → rc=1
红侧成立：34 条断言变红 —— pkill -f <marker> 退出 64（期望 [64]，实际 [0]）,
拒绝文案点名 pkill 与完整 argv, 拒绝文案说清「模式不是身份」, … ,
桩一个调用都没收到（拒绝不执行真身）（期望 [0]，实际 [1]）, 诱饵 A 还活着（pid … 不在）,
诱饵 B 还活着（pid … 不在）, 调用日志记下 act=refused（实际 act=pass）,
保留路径是目录时仍退出 64（期望 [64]，实际 [0]）, FIFO 日志目标…（期望 [64]，实际 [0]）
（这就是断侧该有的结果：闸门放行 → 真身被调用、诱饵被收掉、exit 不再是 64）
$ bash skills/teamsmith/tests/signal-gate.sh                   → rc=0，✓ 62 ✗ 0（还原后）
```
（原始输出：`logs/05-signal-gate-break.txt`、`logs/03-signal-gate-green.txt`）

### F2 · 跳过身份核对 = pid 复用必须被误杀（`--break=no-identity`）

```
$ bash skills/teamsmith/tests/team-bg-stop.sh --break=no-identity   → rc=1
红侧成立：3 条断言变红 —— 指纹对不上 → 5（期望 [5]，实际 [0]）,
理由点名启动时间指纹（实际 result=stopped）,
记录里的 pid 指向的**真进程**没有被误杀（pid … 不在）
（跳过指纹核对后，记录里的 pid 被直接当身份：pid 复用场景不再被拒、邻居被误杀）
$ bash skills/teamsmith/tests/team-bg-stop.sh                       → rc=0，✓ 37 ✗ 0（还原后）
```
（原始输出：`logs/06-team-bg-stop-break.txt`、`logs/04-team-bg-stop-green.txt`）

### F3 · 历史豁免真的会失效（`signal-lint-legacy.txt`）

在一份 scratch 仓库副本里跑（**没有碰**任何人的证据包；`/tmp/p159-legacy-flip`）：

```
① 默认（sha 匹配）：  LEGACY docs/team/reports/M35-dev2/pkg/lib.sh ×2 → signal-lint：红 0 条 … rc=0
② 冻结文件加一行：    RED …/lib.sh:46 / :47 → signal-lint：2 条按名字/谓词选进程的调用 … rc=1
```

### F4 · 见证跑：真 pkill/killall 一次都没被执行（容器构造证明）

`docs/team/reports/P159-dev-bob/pkg/run-witnessed.sh`（容器内；`/usr/bin/{pkill,killall}` 被换成记录桩）：

```
== A · 桩在 PATH 里确实生效 ==
  ✓ command -v pkill → …/scripts/shim/pkill（闸门入口，不是真身）
  ✓ command -v killall → …/scripts/shim/killall
== B · 见证的正向对照（可证伪：真身被调用时必须留字）==
  ✓ /usr/bin/pkill 与 /witness/pkill 逐字节相同（同一个替身；宿主真身不在容器里）
  ✓ 见证活着：执行 pkill --help 留了一条记录（REAL-PKILL-EXECUTED --help）
  ✓ /usr/bin/killall 与 /witness/killall 逐字节相同 + 留字
== C · 夹具跑完，真身必须一次都没被调用 ==
  绿侧 signal-gate.sh rc=0（✓ 62 ✗ 0）；红侧 --break=pass rc=1（34 条变红）
  ✓ 两次运行（绿侧 + 红侧）之后 witness.log 仍然是空的：真 pkill/killall 一次都没执行
== run-witnessed 结果 == 见证跑全绿
```

### F5 · 见证跑当场抓到的那个洞（**我自己夹具的缺陷，已修**）

第一次见证跑（红侧）留下 `REAL-PKILL-EXECUTED -f x`：`signal-gate.sh` 的「真身不可解析」那条腿故意
给了一个不存在的 `TEAM_SIGNAL_REAL`，闸门于是回落到 PATH 扫描；绿侧拒绝在前（不解析），但**红侧**
（放行副本）扫到了 `/usr/bin/pkill` 并执行了它 —— 也就是说那条腿本身是「夹具可能执行真身」的洞
（`pkill -f x` 会命中任何命令行里带 `x` 的进程）。修法：那条腿的 PATH 里放 `$REAL_SHIM/pkill → 桩`
（提交 `69c99b7a`），此后见证跑全绿。**这是「夹具自述不可信、要用构造证明」的直接收益。**

### F6 · 门禁/探针抓到的三条缺陷（已修：`1a987379`、`80d225d5`）

1. **`team bg stop` 的 KILL 升级会误报 `still-alive`/exit 6**：发完 `KILL` 立刻 `kill -0`，那一刻进程
   可能还是僵尸（父进程尚未回收）→「正在死」被当成「停不掉」。修法：KILL 之后再等最多 2s 让它真的
   消失（与宽限无关）。抓它的是 routes.sh 的新探针（`result=still-alive` vs 期望 `result=stopped`）。
2. **schema 注释点名 `team bg stop` → Walk B 要求 promise 探针**：补 `bg-stop-grace` 探针（上表），
   顺带改掉文档里写错的 0 语义（`0` = 立刻升级，不是「不升级」）。
   另外**第一次 FAST 跑就是被它拦下的**（`51 · 用法诚实性` ✗1），说明这道门禁有效。
3. **M36 段的 PM 窗口断言是假红**：`gate-pm.sh` 夹具只 `env | sort`，不打印 `pkill_at`，于是
   「PM 窗口里 pkill 也解析到闸门入口」永远红。修法：让 PM 夹具与 worker 夹具同形，也写
   `pkill_at`/`killall_at` 两行（窗口里 `command -v` 当场求值）。
   隔离复验：`smoke.sh --select 6i` → `#10 6i · PM adapter … ✓126 ✗0`，`== 选段结果 == ✓ 267 ✗ 0`。

## 作废的三轮（如实记账）

跑过三轮全量、两轮 FAST，只有**冻结树上的那两轮**算数（下面「门禁结果」里的）。作废的三轮是：

- **全量 run A**（`p159-full-smoke`，没 tee，只有 team 的作业日志）：启动时 M36 夹具还没修；在它跑到
  第 110 段（约 11:25）时我按记录终止了它（`kill <记录的 pid>` + 子进程，容器随 `--rm` 退），因为同一棵
  树在跑动期间被改过（`cmd-bg.sh`/`routes.sh`/schema）—— 它没有完整结果，也不参与判定。
- **全量 run B**（`p159-full2`，tee → `logs/08-full-smoke-run1-m36-red.txt`）：跑完了，
  `✓4148 ✗1 SKIP3`，唯一那条红就是 §F6-3 的 M36 假红。它同样不算数：跑到第 26 段（`6i`）报红之后，
  我在它还在跑的时候改了 `gate-pm.sh`（修 F6-3）—— 一轮门禁不能跑在两棵树上。修好后在冻结树上跑
  了 run C（下面的全量结果）。
- **FAST run1**（`p159-fast-smoke`，没 tee）：跑完 17 分钟，`✓3425 ✗1`，唯一那条红是 §F6-2
  （`51 · 用法诚实性`：schema 注释点了命令却没 promise 探针），修好后重跑 → `✓3426 ✗0`。

## 门禁结果

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 20 passed, 0 failed (20 items)          （含 change/safe-signal-discipline）

$ bash skills/teamsmith/tests/signal-lint.pl --selftest      → rc=0（29 个夹具 + 豁免机制）
$ bash skills/teamsmith/tests/signal-gate.sh                 → rc=0，✓ 62 ✗ 0
$ bash skills/teamsmith/tests/team-bg-stop.sh                → rc=0，✓ 37 ✗ 0
$ bash skills/teamsmith/tests/signal-gate.sh --break=pass    → rc=1，34 条变红（红侧成立）
$ bash skills/teamsmith/tests/team-bg-stop.sh --break=no-identity → rc=1，3 条变红（红侧成立）
```

FAST 与全量门禁（容器内，`localhost/teamsmith-gate:local`）：

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null        # 容器内，冻结树；11:26:24 → 11:55:51（≈30 分钟）
== #117 58 · 信号纪律：闸门 / 作业 pid / lint（P159） == … 预算 60s
#117 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 7s · ✓12 ✗0 SKIP0 · ticks 12
账本自查： 119 段收口 · 增量 ✓4149 ✗0 SKIP3 ｜ 结果行 ✓4149 ✗0 —— 一致
== 结果 ==  ✓ 4149  ✗ 0
smoke 全绿
（3 条 SKIP 都是条件不满足：12b-h ⑤/⑥ 要求 TMUX 内运行、12b-pi 的可见 S2；与本 change 无关）
（真窗口那两条腿在这次全量里真的跑了：#10 6i PM adapter … ✓126 ✗0，含
 ⑪ worker/PM 窗口里 pkill、killall 都解析到闸门入口 + 信号调用日志钉住 + 没有任何信号授权键）
（原始输出：logs/09-full-smoke.txt）

```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null    # 容器内，冻结树；11:59:32 → 12:16:24（≈17 分钟）
== #118 58 · 信号纪律：闸门 / 作业 pid / lint（P159） == 2026-10-02T12:16:17+00:00 · 预算 60s
  ✓ 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（1 个历史豁免文件逐条打印）
        LEGACY  docs/team/reports/M35-dev2/pkg/lib.sh  ×2  —— M35-dev2 证据包（P159 之前：M25 对照组的 pkill -f 清理）
  ✓ 58 lint --selftest：双向夹具全部符合预期
  ✓ 58 翻转①：干净文件不报红
  ✓ 58 翻转②：种下的 pkill -f 被判红并按 file:line 点名
  ✓ 58 翻转③：kill "$pid" 形态不报红（反向不误报）
  ✓ 58 signal-gate 全绿（63 条断言）
  ✓ 58 team-bg-stop 全绿（38 条断言）
  ✓ 58 harness S13：真扩展写的作业记录（5 条断言，job=p159-record pid=3000555）
  ✓ 58 段内 team bg stop 用记录停掉 harness 起的作业（rc）
  ✓ 58 stop 打印它信号了谁（result=stopped）
  ✓ 58 stop 点名被停的命令
  ✓ 58 harness 作业已按记录停掉（pid 3000555 不在）
#118 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 7s · ✓12 ✗0 SKIP0 · ticks 12
账本自查： 120 段收口 · 增量 ✓3426 ✗0 SKIP36 ｜ 结果行 ✓3426 ✗0 —— 一致
== 结果 ==  ✓ 3426  ✗ 0
smoke 全绿
（36 条 SKIP 都是 FAST 原本就跳的真进程段落 —— 新段 58 不在里面，它照跑）
（原始输出：logs/10-fast-smoke.txt）
```

## 自己跑 / 引用 / 没测到

- **自己跑的**：上表全部；容器脚本 `pkg/ct.sh`，见证跑 `pkg/run-witnessed.sh`。
- **引用的**：`docs/team/reports/P154-dev-bob/recon.log`（现状取证，propose 阶段已验收）；
  `pkg/tmux-lint-list-before.txt`（词法器抽取**之前**的 `tmux-lint.pl --list` 输出，抽取后当场重跑对比）。
- **没测到 / 边界**：
  - 真窗口那两条腿（worker/PM 窗口里 `pkill` 解析与信号 pin）只在**全量**门禁里跑，FAST 里是可见 SKIP；
    我**没有**在宿主上跑过任何真 tmux 夹具（PM 的临时纪律 + #1794）。
  - 闸门的明说边界照设计 D3：`kill`/`pgrep`/`ps`/`pidof` 不拦（exec 时只看到展开后的 argv），
    字面绝对路径（`/usr/bin/pkill`）与没有把闸门目录放 PATH 最前的 shell 在闸门**之外** ——
    这两半由静态 lint 覆盖仓库脚本，不假装运行时覆盖。
  - 绝对路径绕过的那一半我**没有**做运行时兜底（设计 D3 明确不做），lint 会红。
  - `TEAM_BG_STOP_GRACE` 的探针只测了 0 与 2 两档（等待差可测），默认 5s 的行为由夹具的
    「按记录停掉」路径间接覆盖（那条路径不需要升级）。

## Deviations / 与任务书的差异

1. 任务书 4.3 说「新段用下一个空号（57 已被 delivery-truth 占用，apply 时确认）」→ 实际用 **58**（57 仍在用）。
2. 任务书 5.1 的三行 schema 里，`TEAM_BG_STOP_GRACE` 的注释我写成点名 `team bg stop`（这触发了
   routes.sh 的 promise 要求），因此**额外**在 `tests/routes.sh` 里加了一条探针（agent-owned 的
   `tests/**`）。若 PM 认为该注释不该点名命令，可以只回退注释 + 探针两处，其余不受影响。
3. `team bg stop` 的 KILL 升级路径我做了任务书没写的一处小修（KILL 后等最多 2s 再判 still-alive），
   理由是它把「正在死」误报成失败（exit 6）；行为契约（退出码集合）不变。
4. 第一次全量门禁在 26 分钟处被我**主动终止**：跑的过程中我改了三处实现（`cmd-bg.sh`、`routes.sh`、
   schema 注释），那一轮的树前后不一致，结果**作废**（不是判定）。之后在冻结的树上重跑（见 §门禁结果）。

## Next steps

- 交 verify 席位独立复验（另一个 agent，`docs/team/tasks/P159-verify-*.md`）。
- 复验时建议优先看：`--break` 两条红侧是否仍能变红、`signal-lint` 的历史豁免是否只豁免那两个文件、
  以及「段内 `team bg stop` 停 harness 起的作业」那条端到端是否仍能真停。
