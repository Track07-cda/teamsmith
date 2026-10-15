# P260 · cli-help apply — delivery report

- **Task**: `docs/team/tasks/P260-cli-help-apply.md` · change `cli-help` · phase `apply`
- **Branch**: `task/P260-cli-help-apply` (local mode: no remote, the branch stays local for the PM)
- **Agent**: dev
- **Status**: delivered — 全部验收命令已在本分支实跑；选段门禁 108 段 **✓ 4596 / ✗ 0**（rc=0），`openspec validate --all --strict` 19/19，`ledger-ban` hits=0，工作树干净

## 0. 范围修订（D170）之后这份交付是什么

用户裁定（2026-10-14）：**门禁只管逻辑，文本类（措辞、排版、语言内容、概念定义）由设计与评审把关**。任务书的
「范围修订」一节据此收窄了本变更的**门禁面**，**行为面不变**。这一轮的改动：

| 面 | 改动 | 落点 |
|---|---|---|
| delta | 删三条要求、收窄两条 | `openspec/changes/cli-help/specs/help-surface/spec.md`：删掉「入口页规模」「页面内容 schema」「版式可机械检查」；`TEAM_LANG` 那条删掉键集比对检查、保留机制；「声明与探针」那条删掉散文纪律（数字/旗标一致性）、保留探针注册表与效应探针 |
| design | 版式层级、第 0 级规模、页面 schema、概念定义**保留为设计决定**（不是合同），并写明 D170 的分工 | `design.md` 决策 2/4/6/7/8 与开头的范围注 |
| 夹具 | 删 `scale`/`layout`/`content` 三组、删版式判官 `tests/lib/help-layout.py`、删文本类红侧；`coverage` 去掉「三步内可达」（改由清单单一真源 + Walk A 保证）；`lang` 只留机制；原 `content` 收成 `invariants`（命令名/旗标名/字面量不改） | `tests/help-surface.sh`、`tests/section-paths.tsv` |
| 段表 | §51 的说明与路径登记跟着收窄 | `tests/section-paths.tsv` |
| 合并 | `git merge main`（无冲突） | 本分支 tip |

## 1. What was delivered

The help surface now has one language-neutral source of truth and is rendered from it. Before this
change the help text was a 98-line heredoc inside `cmd-project.sh`, `meeting` carried a second copy of
its own page, and §51 read the *printed prose* with a regex — so a line could be dropped and the check
would simply stop testing it.

| Piece | Path | What it is |
|---|---|---|
| command manifest | `skills/teamsmith/scripts/strings/commands.tsv` | 44 commands + 8 groups; per command: group, usage fragments, flags, subcommands, aliases, concepts, example, touched faces, `effect`/`auth`/`undo` declarations and a probe id |
| prose, English (source) | `skills/teamsmith/scripts/strings/help.en.tsv` | 464 keys |
| prose, Chinese (translation) | `skills/teamsmith/scripts/strings/help.zh.tsv` | the same 464 keys |
| renderer | `skills/teamsmith/scripts/lib/cmd-help.sh` | menu / group page / command page; the fixed layout ladder; display-cell wrapping; missing-key markers; `TEAM_LANG`, `TEAM_HELP_WIDTH` |
| route | `skills/teamsmith/scripts/team` | `team`, `team help …`, `team <cmd> --help`, `team <cmd> -h` — answered before the project contract is loaded |
| removed | `cmd-project.sh` (98-line help heredoc), `cmd-meeting.sh` (`team_meeting_help`) | the second sources of the same text |
| surface fixture | `skills/teamsmith/tests/help-surface.sh` | coverage / lang / claims / invariants / route + 8 red sides (`--flip`) — 只判逻辑（D170） |
| layout judge | ~~`tests/lib/help-layout.py`~~ | 已按 D170 删除：版式与页面 schema 由评审读样张把关 |
| Walk A re-cut | `skills/teamsmith/tests/routes.sh` | the working set comes from the manifest (every command × every usage line), every level is judged, every claim is fed to the real parser |
| knobs | `skills/teamsmith/references/workflows.md` §K | `TEAM_LANG` (en/zh, default en) and `TEAM_HELP_WIDTH` (default 100), English |
| gate registration | `skills/teamsmith/tests/smoke.sh`, `tests/section-paths.tsv`, `tests/section-budgets.tsv` | §51 runs the fixture; the paths and the measured band are registered |

The three levels and the layout contract:

```
team                     → the entry menu: what teamsmith is, the 8 groups, 4 start-here commands
team help <group>        → that group's commands, one usage line each, in manifest order
team help <command>      → one command's page: Usage, What it does, When to use it, Arguments,
                           Example, Reads, Writes, Side effects, Authorization, Undo, Concepts, See also
team <command> --help    → byte-identical to `team help <command>` (also `-h`, also through an alias)
```

## 2. `tasks.md` 1–6 与范围修订，逐条

| item | where it landed | evidence |
|---|---|---|
| 1.1 the manifest, one record per dispatcher label | `scripts/strings/commands.tsv` (44 commands, 8 groups, 66 usage fragments, 82 flags, 42 subcommands, 5 aliases) | coverage: `dispatcher 的每个标签都有记录或别名声明（49 个标签）` / `清单里每个命令都被 dispatcher 接受`（内部标签 `__*` 不算命令名） |
| 1.2 the renderer, the ladder, display-cell wrapping, the three exits | `scripts/lib/cmd-help.sh` | coverage + the samples in §4（层级仍照设计实现，断言已按 D170 移出） |
| 1.3 attributable layout | the renderer | Walk A（`routes.sh`）判可归属；版式断言移出 |
| 1.4 `meeting` folded into the renderer, `$TEAM_PROJECT`/TTL through declared placeholders | `cmd-meeting.sh`, manifest + both tables | `team help meeting` 与 `team meeting help` 逐字节相同（coverage 的别名检查） |
| 2.1 the three levels, before `team_load_config` | `scripts/team` | route：四个入口在「既不是 git 也不是项目」的目录里都 exit 0 |
| 2.2 unknown token → exit 2, named, points back at `team help` | `cmd-help.sh` | route：`frobnicate --help`、`help frobnicate`、`help not-a-group`、`-h frobnicate` |
| 2.3 the entry level is bounded | manifest `begin` row + `menu.lead` | **改由设计+评审**（D170）：菜单仍做成三级、入口页仍短小，不再数行数；样张见 §4 |
| 2.4 the help path never loads the project | `scripts/team` | route：四个入口 exit 0、不写文件；请求帮助不执行被帮助的命令 |
| 2.5 the red sides | `--flip` | §5：8 条，逐条红并点名 |
| 3.1 the two tables and the key scheme | `help.en.tsv`, `help.zh.tsv` | lang：机制（缺省英文/切中文/非法值告警/缺键可见）；**键集齐全度由评审核对**（D170 删了比对检查） |
| 3.2 `TEAM_LANG` / `TEAM_HELP_WIDTH`, environment only | `cmd-help.sh` | lang + §6 |
| 3.3 a missing key is visible and falls back | `team_help_txt` | lang + 红侧 ⑥⑧ |
| 3.4 language never moves a machine exit | `paths --json`, `monitor --print` | lang：两种语言下相同 |
| 3.5 the red sides | `--flip` | §5：⑤⑥⑦⑧ |
| 4.1 the 13 concepts, both languages | `term.<id>.def` | **改由评审**（D170）：定义仍在两表里、页面仍复述，深度与质量由评审读样张 |
| 4.2 the twelve parts, ordered and non-empty | the renderer | **改由评审**（D170）：样张见 §4 |
| 4.3 the reader test | §7 | 读者测试的三条真缺陷已修并留下守卫（缺键标记、空 Arguments、中文分隔符） |
| 4.4 the red sides | `--flip` | 文本类红侧随 D170 删除；保留的是缺键标记那条（⑧） |
| 5.1 the closed vocabularies | manifest columns 10–12 | claims：44 个命令三类字段齐备，越界取值判红 |
| 5.2 probes that assert the effect | `run_probe` | claims：44 条探针，逐条打印 rc 与变化的面 |
| 5.3 prose discipline (numbers, flags, `→`) | — | **已按 D170 移出门禁**（改由评审读样张） |
| 5.4 the red sides | `--flip` | 保留「一个取值没有探针」这类逻辑红侧（见 §5 说明） |
| 6.1 the manifest working set | `routes.sh` `mr_manifest_claims` | `walk 覆盖面：53 个页面（1 菜单 + 8 组页 + 44 命令页）、66 条用法行、87 条 (命令,旗标) 断言` |
| 6.2 every level through the same parser, non-vacuity per level | `mr_walk_a` | `routes.sh walk`：142 ✓ / 0 ✗，每级各有一条判定行 |
| 6.3 the existing red sides untouched, three new ones | `routes.sh flips` | 基线红侧未动，新增的三条（第 2 级坏用法行、清单漏命令、逐级都判到） |
| 6.4 the coverage numbers | §8 | before 1 page / 47 usage lines / 40 commands → after 53 pages / 66 usage lines / 44 commands |

## 3. Acceptance commands — real runs

Every command ran in this worktree on `task/P260-cli-help-apply`.

### 3.1 `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict`

```
✓ change/panel-preview-and-compose
✓ spec/pm-lifecycle
✓ change/turn-notice-merge
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)
rc=0
```

### 3.2 `bash skills/teamsmith/tests/help-surface.sh --all`（D170 收窄后）

```
== 结果 ==  ✓ 90  ✗ 0  SKIP 0        (5m45s)
```

（收窄前是 468 ✓ / 0 ✗；差值就是移出门禁的文本类断言。）

The five groups and what each one judged（D170 后）:

```
== coverage ==   every dispatcher label has a record or an alias (49, the internal `__*` labels are
                 not command names); every manifest command is accepted; every command page and
                 every group page prints exactly the manifest's usage lines; no page prints a
                 missing-key marker; the Arguments rows equal the flag list; every alias reaches
                 its primary (byte-identical apart from its own alias line)
== lang ==       the mechanism: English by default, `TEAM_LANG=zh` switches, an invalid value prints
                 one warning and stays English, a missing key renders a visible marker, and
                 `paths --json` / `monitor --print` do not move with the language
== claims ==     the closed vocabularies, one probe per value, and 44 probes that assert the effect
== invariants == the cross-spec literals (`init`/`add-agent`/`teardown`/`dispatch`) and the
                 pre-change (command, flag) set still printed
== route ==      the three levels, the byte-identical entries, the refusals with exit 2, the help
                 paths without a project, and that asking for help starts nothing
```

### 3.3 `bash skills/teamsmith/tests/routes.sh`

```
== 结果 ==  ✓ 142  ✗ 0  SKIP 0     (walk)
  · walk 覆盖面：53 个页面（1 菜单 + 8 组页 + 44 命令页）、66 条用法行、87 条 (命令,旗标) 断言，逐条喂过真解析器
== 结果 ==  ✓ 179  ✗ 0  SKIP 0     (walk control)
```

### 3.4 `bash skills/teamsmith/tests/section-select.sh --check`

```
ok: needs 声明全部存在且指向更早的段（106 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面…）：.pi/skills
ok: 字面模式（577 条）里 576 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（504 个 token 检查过）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1
rc=0
```

### 3.5 `bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')`

队列史：第一次（15:46 起）等满 5400s 未拿到门锁，harness 记「本套没有运行（这不是对代码的判定）」；第二次
（17:17 起）跑满 108/129 段、82 分钟，**7 条 ✗**；修完之后第三次（19:38 起）**1 条 ✗**（就是 `翻转⑩对照`，
见 §10.1）；再修一次之后第四次（20:39 起）跑满 108 段、2 小时 58 分：

```
== 选段结果 ==  ✓ 4596  ✗ 0
#101 51 · 用法诚实性 · 用时 833s · ✓3 ✗0 SKIP0
#87  36 · 选段与分段账本自检 · 用时 852s · ✓120 ✗0 SKIP3
账本自查： 108 段收口 · 增量 ✓4596 ✗0 SKIP16 ｜ 结果行 ✓4596 ✗0 —— 一致
gate rc=0
```

108 段全绿，含 §0e 预算检查（`129/129`）、§11j、§12k、§36⑧、§33（`config-cli` ✓331/✗0）、§51（`routes.sh` +
`help-surface.sh` 两组夹具）。

### 3.6 `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"`

```
ledger-ban: names：名单已配置（…/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=1473 hits=0 names=ok user=resolved
rc=0
```

### 3.7 `git diff --check && git status --short`

```
$ git diff --check        # 无输出
$ git status --short      # 无输出（工作树干净，全部改动已提交）
```

## 4. 哪些内容从门禁移到评审（D170）

**删掉的门禁断言**（这些检查曾写在 `help-surface.sh` 的 `scale`/`layout`/`content` 三组与 `tests/lib/help-layout.py` 里，
现在都不存在；判官文件已删除）：

| 曾有的门禁断言 | 现在的把关方式 |
|---|---|
| 菜单 ≤30 行、上手命令 3–5 条、分组各列一次、组清单在第一个标题之前 | 设计决定（design 决策 2）：菜单仍做成三级、入口页仍短小；评审读 §5 的入口页样张 |
| 行宽 ≤ 有效宽度、续行严格更深、阶梯外的缩进判红 | 渲染器仍按层级排版（它的性质），断言移出；评审读样张 |
| 禁用形态：`→` 链、散文里的数字必须有声明、散文里的 `--flag` 必须在用法行 | 评审读样张（措辞类） |
| 12 个小节有序且非空、`Arguments` ↔ `Usage` 旗标集合相等、`Example` 是真实命令路径 | 评审读样张（页面深度） |
| 13 个概念在页内逐字节复述、两表键集相等 | 评审核对两表与页面 |
| 「任何命令从菜单三步内可达」 | 清单单一真源 + Walk A（每个命令都有页、每条用法行都喂过真解析器） |
| 中文面不得出现西文逗号分隔 | 评审读中文样张 |

**留在门禁里的逻辑**（逐条对应任务书「范围修订」的 1–5 点）：三级路由与退出码、命令页与组页逐字节一致、未知
token exit 2 且点名、`--help` 不加载配置/不执行被帮助的命令/不起进程、Walk A 的清单工作集与非空洞控制臂、
命令名/旗标名/字面量不改、`--print`/`--json` 字节不受语言影响、`TEAM_LANG` 的机制（缺省英文/切中文/非法值一行
告警后回退/缺键渲染可见标记）、`effect`/`auth`/`undo` 每个取值一条真探针、清单一行只渲染出它自己那条用法行。

**给评审的读法**：下面 §5 的样张是**本分支的渲染输出**（不是设计稿里的示例）；`design.md` 的「目标排版样例」
是照着读的尺子。中文面另可 `TEAM_LANG=zh bash skills/teamsmith/scripts/team help dispatch` 现场读。

## 5. 渲染样张（入口页 / 一个组页 / 两个命令页）

```
### 入口页（第 0 级）：team
teamsmith turns one git repository into a small team: a PM agent that plans, writes briefs and
verifies work, and worker agents that implement in their own worktrees. Every promise it prints is
checked by its own gate.

Groups
  start     Set a project up and check that the ground can carry it.
  observe   Seats, capacity, the ledger view and the machine-readable paths.
  ledger    The written record the team works from.
  seats     Give one brief to one seat, and talk to that seat.
  patrol    The metronome that wakes the PM, and the windows it runs in.
  peers     Peer talks with another project's PM.
  finish    Verify a delivery, wrap up, and run the tool's own suites.
  versions  Which skill version is loaded, and what changed.

── Start here ──────────────────────────────────────────────────────────────────────────────────────
  bootstrap [--agents <names>] [--task-models <map>] [--pm-model <model>] [--print]
      set up a whole project in one command
  status [<ID>]
      the roster plus the task and report state
  dispatch <a> <ID> <task-file> [--model <model>] [--branch <name>] [--fresh] [--allow-overflow]
    [--print]
      hand one brief to one seat
  review <ID> --dir <checkout> [--no-gates] [--strong] [--allow-unresolved-branch]
      verify a delivery on an independent checkout

`team help <group>` lists a group's commands; `team help <command>` prints one command's own page.
```

```
### 组页（第 1 级）：team help seats
teamsmith · Handing out work — Give one brief to one seat, and talk to that seat.

── Handing out work ────────────────────────────────────────────────────────────────────────────────
  add-agent <a> [--register] [--create] [--no-install] [--print]
      Creates a seat's long-lived worktree and branch and, when asked, records it in the roster. It
      prints the git command it would run rather than running it, so the PM keeps ownership of every
      git operation.
  dispatch <a> <ID> <task-file> [--model <model>] [--branch <name>] [--fresh] [--allow-overflow]
    [--print]
      Creates the seat's task branch, records the assignment and starts or resumes that seat's
      session in its own worktree. A first dispatch picks the model from the brief's category;
      dispatching the same task again reopens the recorded model and session instead of choosing new
      ones.
  say <a> <message> [--now]
      Puts one line in front of a seat. If the seat's input box already holds a draft, the message
      is queued and delivered when the box is clear, so a person's half-written line is never
      overwritten.
  notify <a> <message> [--from <sender>]
      Writes one line into the PM's inbox and knocks on the PM's window. The sender is resolved from
      the directory the command runs in, so a seat cannot claim to be the PM by typing a name.
  draft [pm]
      Opens a scratch window to write a message in, or sends the contents of a file, and queues the
      text for delivery. Queued text is delivered when the target's input box is clear, so nothing
      is typed over a draft someone is writing.
  outbox [list]
      Lists what is waiting to be delivered, flushes it early, or drops entries. An entry appears
      here when a message could not be typed into a busy window, so nothing is lost and nothing is
      typed over a person's draft.
  reply list
      Publishes a reply body as its own file before it is sent, and lists or shows the replies
      already published. The body is taken from standard input, so the published text is the text
      that was sent.

`team help <group>` lists a group's commands; `team help <command>` prints one command's own page.
```

```
### 命令页（第 2 级）：team help dispatch
teamsmith · dispatch — hand one brief to one seat

── Usage ───────────────────────────────────────────────────────────────────────────────────────────
  dispatch <a> <ID> <task-file> [--model <model>] [--branch <name>] [--fresh] [--allow-overflow]
    [--print]
      What it does: Creates the seat's task branch, records the assignment and starts or resumes
      that seat's session in its own worktree. A first dispatch picks the model from the brief's
      category; dispatching the same task again reopens the recorded model and session instead of
      choosing new ones.
      When to use it: Use it once the brief exists and the seat is chosen. Run it again with the
      same id to continue an unfinished task, and with a new model and the fresh flag when the model
      must change.
      Arguments:
          --model               use this model instead of the one the brief's category maps to.
          --branch              declare the task branch this dispatch expects; the worktree must be
                                on it.
          --fresh               start a new session instead of reopening the recorded one; required
                                whenever the model changes.
          --allow-overflow      dispatch even when the model's concurrency limit is already reached.
          --print               print the launch command without starting anything.
      Example:
          team dispatch dev P1 docs/team/tasks/P1-first-task.md --branch task/P1-first-task
      Reads: the brief, the contract, the board and the roster
      Writes: the board row, the seat record and the worktree
      Side effects: it starts a process, and it writes the team ledger, the state directory
      Authorization: no extra authorization is needed
      Undo: not reversible
      Concepts:
              seat          A seat is one worker agent. It has its own tmux window, its own git
                            worktree and its own session, so two seats never edit the same files.
              brief         A brief is the task file under the team's tasks directory. It is the
                            single source of scope and acceptance commands for one task.
              worktree      A worktree is a second checkout of the same repository on its own
                            branch, so a seat can write files while the PM keeps working in the main
                            checkout.
              task-branch   A task branch is the branch a seat's worktree is on. It is named after
                            the task, and it is the evidence of which work belongs to which task.
              gate          A gate is the project's own check suite. Green means the checks really
                            ran on this tree; it is evidence only because the same gate fails when
                            the work is broken.
      See also: `team resume`, `team review`, `team task`

`team help <group>` lists a group's commands; `team help <command>` prints one command's own page.
```

```
### 命令页（第 2 级，含 --yes 与撤销）：team help meeting
teamsmith · meeting — talk to another project's PM

── Usage ───────────────────────────────────────────────────────────────────────────────────────────
  meeting open <slug> --with <peer> --topic <text> [--ttl <hours>] [--yes]
  meeting say <slug> --intent <intent> <message> [--knock]
  meeting read <slug> [--since <n>] [--peek]
  meeting list [--all]
  meeting inbox
  meeting agree <slug> <option> [--note <text>]
  meeting close <slug>
      What it does: Runs a meeting between this project and another: each side speaks into one
      shared transcript, and a proposal is only settled when both sides agree to it themselves. It
      never writes into the other project's repository, and it has no way to give an order: a human
      is the only one who can carry a decision across projects.
      When to use it: Use it for an interface between two projects, for advice with evidence, or to
      report a problem that the other side has to know about. It is not a channel for commanding
      another team.
      Arguments:
          --with                the other project, optionally as project:session, this meeting is
                                with.
          --topic               one line saying what the meeting is about.
          --ttl                 how many hours the meeting stays open; the default is 72 hours, and
                                an expired meeting can still be read.
          --yes                 the explicit authorization this write to shared state needs.
          --intent              what kind of speech this is: information, a question, a report, a
                                proposal or a request.
          --knock               also knock on the other side's window.
          --since               read only what was said after this number.
          --peek                read without marking the transcript as read.
          --all                 include the meetings that are already closed.
          --note                one line recording what your side does with the agreement.
      Example:
          team meeting open rename --with other:pm --topic "rename the interface"
      Reads: the shared meeting area and this project's session
      Writes: the shared meeting area
      Side effects: it writes the shared meeting area
      Authorization: it needs --yes only when the project sets TEAM_CONFIRM_WRITES. the project asks
      for confirmation on writes to shared state (`TEAM_CONFIRM_WRITES`), so without it the refusal
      is the tool own
      Undo: not reversible
      Concepts:
              pm            A PM is the agent that owns the project: it writes the briefs,
                            dispatches the seats, verifies what comes back and merges it. There is
                            exactly one PM per project.
      See also: `team thread`, `team say`

`team help <group>` lists a group's commands; `team help <command>` prints one command's own page.
```

## 6. Red sides — break → red (named) → restore → green

`bash skills/teamsmith/tests/help-surface.sh --all --flip`（D170 后只留逻辑类，8 条；每条都红并点名它针对的
finding，干净树全绿）：

| # | Break | The red it produced |
|---|---|---|
| ① | one command disappears from its group page | `✗ 组页 observe 与清单不一致（< status [<ID>]）` |
| ② | one manifest row is deleted | `✗ dispatcher 接受的 bg 在清单里没有记录（也没有别名声明）` |
| ③ | an unknown token is answered with exit 0 | `✗ route: team frobnicate --help 的退出码是 0（应为 2）` |
| ④ | the help path loads the project contract | `✗ route: 无项目目录时 team help 失败` |
| ⑤ | an invalid `TEAM_LANG` is silent | `✗ 非法 TEAM_LANG 没有可见告警或状态变了（rc=0）` |
| ⑥ | one Chinese key is missing | `✗ 键集不相等：< cmd.status.what`（D170 后这条红侧由「缺键渲染可见标记」的行为检查触发） |
| ⑦ | a machine exit starts carrying language-dependent output | `✗ 语言改变了 team paths 的输出` |
| ⑧ | a declared flag has no prose key | `✗ 命令 dispatch 的页打印了缺键标记：--fresh «missing key: cmd.dispatch.arg.--fresh»` |

每条红侧在判之前先断言**变异真的落地**（`flip_edit` 对「改了等于没改」的陈旧模式报 `变异没落地（夹具缺陷）`），
所以陈旧模式永远不会被当成通过。随 D170 删除的红侧（①菜单灌入命令、②菜单撑行、⑨概念漂移、⑪⑫⑬⑭⑯⑰⑱版式、
⑰c中文分隔符）对应的是已移出门禁的文本类检查。

`bash skills/teamsmith/tests/routes.sh flips` (Walk A's own sides, brief §2):

| # | Break | The red |
|---|---|---|
| ① | `add-agent --model` printed again while the parser refuses it | `add-agent --model` named |
| ② | `add-agent`'s line prints `dispatch`'s `--fresh` | `add-agent --fresh` named |
| ③ | a flag-printing path swallows its flag | the refusal names it |
| ④ | a column-0 line really rendered inside the command block | the walk names the line (the pre-change `board` shape) |
| ⑪ | a second-level page prints a usage line the manifest does not declare | `dispatch --ghost-probe` named |
| ⑬ | a level nothing was judged for | `这一级一条都没被判到` |
| — | the landing criterion itself (`mr_flip_landed` a/b) | its own two red sides |

## 7. Coverage — before and after

Measured on this branch, not estimated:

| | before | after |
|---|---|---|
| surfaces the walk reads | 1 (the flat help text) | 1 menu + 8 group pages + 44 command pages = **53 pages per language** |
| usage lines judged | 47 | **66** (every declared fragment, on every level) |
| commands | 40 with a usage line | **44** (the dispatcher's labels minus its internal labels `__*`) |
| (command, flag) claims fed to the real parser | 0 | **87** |
| declaration fields per command | — | effect, authorization, reversibility, touched faces, probe id, example — all 44 |
| assertions | §51 ≈ 130 | `help-surface.sh --all` **90**（D170 后只判逻辑）+ `routes.sh` walk 142 + control 179 + the §51 lines |

## 8. `TEAM_LANG` / `TEAM_HELP_WIDTH` — measured

```
$ bash skills/teamsmith/scripts/team help            # English, 100 cells
$ TEAM_LANG=zh bash skills/teamsmith/scripts/team help dispatch
      副作用：会起一个进程；并写入团队账本、状态目录
      授权：不需要额外授权
      能不能撤：不可撤销
$ TEAM_LANG=fr bash skills/teamsmith/scripts/team help
teamsmith: TEAM_LANG=fr is not a known language (en, zh); printing English     (rc=0, English page)
$ TEAM_HELP_WIDTH=40 bash skills/teamsmith/scripts/team help
teamsmith turns one git repository into
a small team: a PM agent that plans,
$ TEAM_HELP_WIDTH=abc bash skills/teamsmith/scripts/team help
teamsmith: TEAM_HELP_WIDTH=abc is not a positive integer; using 100            (rc=0)
```

Both knobs are read from the environment only: the help paths never load the project contract, so
they work in a directory that is not a project yet (route group).

## 9. Reader test (tasks 4.3)

Five English pages read as a reader who does not know teamsmith, answering the six rubric questions:

| page | what / when | reads · writes | side effects | `--yes` | undo |
|---|---|---|---|---|---|
| `dispatch` | creates the seat's task branch, records the assignment and starts/resumes its session; re-dispatching reopens the recorded model and session / once the brief exists and the seat is chosen | brief, contract, board, roster · board row, seat record, worktree | starts a process; writes the ledger and the state directory | no | not reversible |
| `bootstrap` | initialises contract, skeleton, protocol section, skill copy, worktrees, patrol window; idempotent / on a fresh checkout, and after an upgrade | repository, template skill · contract, skeleton, protocol section, skill copy, worktrees, state | starts a process; writes contract, ledger, skill copy | no | not reversible |
| `review` | checks the delivery out into its own detached worktree, runs the gate there, writes the record; refuses a dirty tree / after delivery, before the merge | branch, gate, delivery report · review record, independent worktree | writes the ledger | no | not reversible |
| `bg` | lists the recorded background jobs with pid, start fingerprint and command; stops one only when pid and start time still match / when a job is still running | the job records · the job records | writes the state directory | no | running it again changes nothing |
| `meeting` | a meeting between two projects: one shared transcript, settled only when both sides agree; never writes into the other repository and cannot give an order / for an interface, advice with evidence, a problem report | the shared meeting area, this project's session · the shared meeting area | writes the shared meeting area | `--yes` when the project asks for confirmation on shared-state writes | not reversible |

Two Chinese pages read the same way: `team help dispatch` and `team help meeting` — the twelve parts
are present with Chinese labels (用法 / 它做什么 / 什么时候用它 / 参数 / 例子 / 读什么 / 写什么 /
副作用 / 授权 / 能不能撤 / 概念 / 相关命令), the concept definitions are Chinese, and the separators
are Chinese (`、` `；`) rather than the English ones.

The test found three real defects, all fixed and now guarded: the `«missing key: cmd.<name>.arg.-»`
row on the 14 flagless pages (now no page may print a missing-key marker), an empty `Arguments` part
on those pages (now `this command takes no flags`), and the untranslated claim separators in Chinese
(now the separators come from the language table, and a Latin comma-space in a Chinese page is a
finding).

## 10. Testing status

全部在本分支、本工作树、真树上跑（不是副本）：

| 命令 | 结果 |
|---|---|
| `bash skills/teamsmith/tests/help-surface.sh --all` | ✓ 90 / ✗ 0 / SKIP 0（5m45s，含 44 条逐命令探针）；`lang` 组另加「缺键渲染可见」的行为断言后 ✓ 91 |
| `bash skills/teamsmith/tests/help-surface.sh --all --flip` | 8 条逻辑红侧，逐条红并点名（见 §6；第 ⑥ 条按 D170 改成破坏「缺键可见」机制本身） |
| `bash skills/teamsmith/tests/routes.sh` | walk / control / flips 三段（见 §3.3）；merge 之后单独复跑 walk+control 仍是 ✓ 142 / ✓ 179、0 ✗ |
| `bash skills/teamsmith/tests/section-select.sh --check` | ok 8 / bad 0 / SKIP 1（可见跳过） |
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 19 passed / 0 failed |
| `bash skills/teamsmith/tests/smoke.sh --paths <本分支改动的路径>` | **✓ 4596 / ✗ 0**（108 段，2h58m，rc=0） |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file …` | files=1486 hits=0 rc=0 |
| `git merge main` | 无冲突（P251 的 `tests/smoke.sh` 与两张段表与本分支的改动互不重叠）；merge 之后 `walk control` 单独复跑仍 ✓ 179 / 0 ✗ |
| `bash skills/teamsmith/tests/routes.sh flips` | 16 ✓ / 1 ✗ —— 见下「一条待 PM 判断的记录」 |
| `git diff --check` / `git status --short` | 干净 |

本任务范围外（按任务书）：面板字符串与设置页（P258）、`cmd-watch.sh`/`common.sh` 的报错文案（P254）、
`--json`/`--print` 的字节形状（设计上不变，由 lang 组断言）。

### 10.1 `翻转⑩对照`：定位、证据与修法（我自己的夹具，已修）

现象：全量 `routes.sh flips` 在**门禁的调用方式**下（`( cd "$TMP" && bash routes.sh )`）报
`✗ 翻转⑩对照：修坏的树上 Walk A/控制臂不该变红（rc=1）`；直接在 worktree 里跑同一段是绿的。

定位（三步，全部留下日志）：

1. 按门禁方式复现 ✓：`cd /tmp/… && TMPDIR=/tmp/… bash routes.sh flips` → 同一条红（`✓16 ✗1`）；
2. 把嵌套的那段单独跑出来（`TEAM_ROUTES_NESTED=1 TEAM_ROUTES_TREE=<scratch> bash routes.sh walk control`）：
   **整棵副本 ✓179/✗0**，**最小副本红一条** —— 红的是
   `✗ 控制：smoke 吞掉了未知参数 --frobnicate-probe（rc=1）`；
3. 对照 main：`bash routes.sh control` 从非 git 目录跑是 **✓34/✗0**（控制臂本身是好的）。

根因：`mr_scratch_tree` 只拷 `scripts/references/templates` + `tests/perf.sh`（最小副本）。我的 Walk A 把控制臂的
工作集从「`team help` 打印出来的路径」扩到「清单声明的**每条路径**」（含 `smoke`），而 `smoke` 会走到 `tests/`，
最小副本让它在嵌套 run 里以「环境缺件」的形状红 —— 与「吞掉未知旗标」无关，`翻转⑩对照` 于是把它读成
「修坏的树把 walk 弄红了」。

修法（一行）：`mr_scratch_tree` 拷**整棵** skill 加同级 `teamsmith-init`（提交 `9033b88c`）。复跑 `routes.sh flips`
见 §10.4。

### 10.2 一处跨任务的断言更新（已修，需 PM 知悉）

`tests/config-cli.sh`（R2 的「打印面」检查，属 `tests/**`＝本席位目录，但不是本变更的产物）里有两条断言直接 grep
`team help` 的**入口菜单**：

```
*'add-agent <a> [--register] [--create] [--no-install] [--print]'*
*'teardown [--agent a] [--all] [--purge] [--force] [--register]'*
```

三级帮助面（本变更的设计）不再把每个命令的用法行铺在入口菜单上，这两行只在各自的命令页上。证据：

- main 上 `bash skills/teamsmith/tests/config-cli.sh` → **✓ 331 / ✗ 0**；
- 本分支（D170 收窄后）→ **✓ 329 / ✗ 2**，两条正是上面这两条（`③ help 的 add-agent 行没打印齐旗标` /
  `③ help 的 teardown 行没打印 --register`）；
- 用 `git archive main` 的干净副本逐文件回灌定位：**只把 `scripts/team` 换成我的版本**就会复现这两条红，
  说明红的原因就是三级路由本身（不是别的改动）。

修法（最小、保留原意）：两条断言改读 `team help add-agent` / `team help teardown`，判定「该命令的用法行上有
这些旗标」（不再钉死占位符写法 `<a>` / `a`）。修后 `config-cli.sh` 回到 **✓ 331 / ✗ 0**。

这是本任务动到的唯一一处「别人任务留下的断言」；如果 PM 认为该由 P251/dev3 自己改，请告知，我可以回退这一提交
（`5c2cda0f`）并改成 `BLOCKED:` 交接。

### 10.3 旧帮助文本的断言：全仓扫描 + 修好（4 处，全部留下原意）

帮助面分三级之后，**任何直接读 `team help`（入口菜单）找某个命令用法行的断言都会失效**。我做了一次全仓扫描
（`grep` 所有测试里读 help 的位置），只找到四处，逐处改成读对应命令页，判定意图不变：

| 位置 | 原断言 | 改法 | 复跑 |
|---|---|---|---|
| `tests/config-cli.sh` ③ | `team help` 里找 add-agent / teardown 的用法行 | 读 `team help add-agent` / `team help teardown`，判定该页用法行上有 `--register/--create/--no-install/--print`、`--register` | ✓ 331 / ✗ 0 |
| `tests/smoke.sh` §11j | `team help` 里找 `pulse up\|down\|restart\|status\|logs` 与「弃用」 | 读 `team help pulse`；弃用标注改成点名别名 `watchdog`（页面打印 `Aliases: watchdog — older names of this command`） | §11j ✓ 48 / ✗ 0 |
| `tests/smoke.sh` §12k | `$($TEAM help)` 里找 `change status` | 读 `team help change` | §12k ✓ 32 / ✗ 0 |
| `tests/install-shape.sh` | `team help` 里截三行找 init / bootstrap 行 | 读 `team help init` / `team help bootstrap`，按整页判定（行会折行，三行窗口本来就不稳） | ✓ 101 / ✗ 0 |

`tests/smoke.sh` 按任务书此刻归 P251（dev3）：我动的是这**三处**与帮助面直接相关的断言（其余一字未改），并在此
写明；若 PM 认为该由 dev3 做，回退提交 `b54f8589`（那一条同时改了 `install-shape.sh` 的两处）即可，我把同样内容
写进交接单。修完的三段复跑：§11j ✓48/0、§12k ✓32/0、§0e ✓23/0，`smoke.sh --select 0e,11j,12k` → ✓167/✗0；
`install-shape.sh` ✓101/0；`checkout-shape-probe.sh`（§36⑧ 的探针）→ 146 ok / 0 bad。

**顺带补的一处产品面精度**：`bootstrap` 页的「写什么」原来写「the skill copy」，现在写「the skill copy under
`.pi/skills`」（与 init 页一致，也是上面那条断言要的事实）。

### 10.4 复跑（修完之后）

| 命令 | 结果 |
|---|---|
| `bash skills/teamsmith/tests/routes.sh flips` | **✓ 17 / ✗ 0**（含 `✓ 翻转⑩对照：同一棵修坏的树上 Walk A/控制臂照旧绿`） |
| `bash skills/teamsmith/tests/smoke.sh --paths <本分支改动的路径>` | **✓ 4596 / ✗ 0**（最终复跑，108 段） |
| `bash skills/teamsmith/tests/smoke.sh --select 0e,11j,12k` | ✓ 167 / ✗ 0 |
| `bash skills/teamsmith/tests/config-cli.sh` | ✓ 331 / ✗ 0 |
| `bash skills/teamsmith/tests/install-shape.sh` | ✓ 101 / ✗ 0 |
| `bash skills/teamsmith/tests/checkout-shape-probe.sh` | 146 ok / 0 bad |
| `bash skills/teamsmith/tests/help-surface.sh --all` | ✓ 90 / ✗ 0（D170 收窄后） |
| `bash skills/teamsmith/tests/routes.sh walk control` | ✓ 142 / ✓ 179，0 ✗ |

## 11. Notes for the PM

- The one exit behaviour this change is allowed to alter does alter: an unknown token with `--help`
  used to print the menu with exit 0; it now prints a refusal naming the token, points back at
  `team help`, and exits 2. The `dispatch` delta carries its own scenario.
- The manifest carries `smoke --select` and no `--keep` (the flag is not implemented); every
  pre-change (command, flag) pair the old surface printed is still printed (content group).
- §51's budget was re-estimated for the new surface (band 1300s, budget 5200s, container arm left
  unmeasured rather than guessed) and the gate run above is the confirmation of the number.
- The evidence bundle stays outside the repository (D94); this report is the only artifact in the tree.
- Not done, by the brief: no shell completion, no man page, no `--json` help output.
- **给 PM 的一条提醒**：`proposal.md` 的「承诺清单」表里仍把版式/规模/概念那几条写成「布局组/内容组」的门禁兑现
  （proposal 是 PM 的文件，我没动）。按 D170 这些已移到评审；若要 proposal 与 delta 一致，需要 PM 自己改那两行。
- 交付 tip：`b04e3bbf`（merge main 之后）+ 本轮的范围修订提交；分支未推（local 模式），工作树干净。
