# M61 · 规格回填（2026-09）：把已落地的跨任务规则写进契约（propose）

agent: dev-bob   status: DONE（提案包完成；FAST smoke 唯一一条红是既有 §33 缺口，M61 未触碰任何 skill 文件）   time: 2026-09-21T09:57Z
branch: `task/M61-2026-09`（HEAD `519faaf`；提交 `aa13de0`…`519faaf`）   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev-bob`）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/spec-backfill-2026-09/proposal.md` | 提案（policy B 回填；500 词上限内） |
| `openspec/changes/spec-backfill-2026-09/design.md` | 归宿决策、item 6 覆盖证明、证据总表（每条 requirement → 文件:行 → 复核方法）、风险 |
| `openspec/changes/spec-backfill-2026-09/tasks.md` | apply 验证计划（每条 requirement 至少一个可失败的命令；真进程项单独标注） |
| `.../specs/boundary/spec.md` | ADDED ×3：默认 socket 拦截（含 tmux 两条回退语义 / 假隔离）、调用日志与窗口注入、破坏性夹具容器化 |
| `.../specs/verification/spec.md` | ADDED ×1：受跟踪文件（工作树+索引）的冲突标记门禁、`file:line` 点名、三类排除 |
| `.../specs/delivery-guard/spec.md` | ADDED ×1：pi 更新横幅容忍（EMPTY / HOLDS_ONLY=yes / RETRACT=ok；不得关更新检查；对抗形状保守回退） |
| `.../specs/board-and-status/spec.md` | ADDED ×3：重复 ID 拒绝+可见性、`board assign`/`board set` 按 ID 寻址、读预算与 cache 等价断言 |
| `.../specs/panel/spec.md` | MODIFIED ×2：看板页/工作页焦点按行身份（id + 出现序号），各带 1 条新 scenario，base 的 5+4 条 scenario 原样保留 |
| `openspec/changes/spec-backfill-2026-09/.openspec.yaml` | `openspec new change` 生成的脚手架 |

规模：5 个 delta 能力、10 条 requirement（8 ADDED + 2 MODIFIED）、32 条新 scenario（panel 的 11 条中 9 条是
MODIFIED 保留的 base scenario），落在任务书 6–10 / 25–40 的区间内。

## Verification evidence（真实命令与输出尾巴）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
✓ spec/verification
✓ change/watch-degradation
✓ spec/watchdog
Totals: 19 passed, 0 failed (19 items)          # rc=0
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null     # 第 1 次（等价最终内容的代码状态）
…
== 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） ==
  ✗ 33 config-cli.sh 有失败
        ✗ 真实 schema 有缺口
…
== 结果 ==  ✓ 2223  ✗ 1
smoke 有失败项（--keep 保留现场）                                        # rc=1
```

```
$ bash skills/teamsmith/tests/config-cli.sh completeness                  # 把唯一那条红单独跑出来
== completeness · 模板键/文档键 ↔ schema 双向对齐（缺一个就红并按名点名） ==
  ✗ 真实 schema 有缺口
  文档键不在 schema：TEAM_INBOX_WATCH_FORCE_FAIL
  文档键不在 schema：TEAM_INBOX_WATCH_STALE_SEC
  文档键不在 schema：TEAM_IW_REQUIRE_WATCH
  ✓ 删行后检查器红并点名 TEAM_AGENT_MEM_MB
== 结果 ==  ✓ 1  ✗ 1  SKIP 0
```

这条红**与本任务无关**，且已存在在被保护分支上（证据）：

```
$ git diff --stat f51daaa..HEAD -- skills/                                # M61 一个 skill 文件都没改
（空输出）

$ git diff --stat main -- skills/teamsmith/tests/config-cli.sh skills/teamsmith/references/config.md skills/teamsmith/scripts/lib/cmd-config.sh
（空输出）——三个涉事文件与 main 逐字节相同

$ git log --oneline -1 main
829dc19 docs(openspec): archive watch-degradation and inbox-spool-resilience
```

根因（读代码确定）：`tests/config-cli.sh:427` 的文档键排除写的是
`grep -vxE 'TEAM_PULSE_|TEAM_WATCH_|TEAM_INBOX_WATCH_|TEAM_REVIEW_ALLOW_'` —— `-x` 是**整行精确**匹配，
本意显然是前缀排除；PM 的 `a4240fc` 往 `references/config.md` 加了 M53 的三条 fixture 控制键
（`TEAM_INBOX_WATCH_FORCE_FAIL` / `TEAM_INBOX_WATCH_STALE_SEC` / `TEAM_IW_REQUIRE_WATCH`），其中
`TEAM_IW_REQUIRE_WATCH` 连（修好的）前缀名单也不覆盖，于是三项都报「文档键不在 schema」。处置见
下节 `finding:`，**我没有改**（任务书边界 + 「发现实现与文档不一致 → 交回 PM」）。

「一次 FAST smoke 红 60 条」的第二次运行是环境噪声，不作为验收记录：`/tmp` tmpfs 当时
`15G 用 14G、仅剩 586M`，第二条运行里出现 `夹具 cas 的 team init 失败`、`当前目录不在 git 仓库内` 这类
夹具级失败（本机同时还有另一轮 smoke 现场 `/tmp/teamsmith-smoke.kgLC3y`，09:57）。AMEND 两个提交只改
`openspec/changes/spec-backfill-2026-09/**`，smoke 的 change/看板段落都跑在 `$TMP` 的夹具仓库里
（源码里没有对真实 `openspec/changes` 的扫描），故第 1 次运行的 ✓2223/✗1 是对最终代码状态的验收记录。

```
$ git status --porcelain
（空输出）
```

```
$ rm -rf /tmp/trial-M61 && mkdir -p /tmp/trial-M61 && cp -r openspec /tmp/trial-M61/openspec
$ (cd /tmp/trial-M61 && PATH="$HOME/.bun/bin:$PATH" openspec archive -y spec-backfill-2026-09)
Specs to update:  board-and-status: update  boundary: update  delivery-guard: update  panel: update  verification: update
  board-and-status: + 3 added
  boundary: + 3 added
  delivery-guard: + 1 added
  panel: ~ 2 modified
  verification: + 1 added
Totals: + 8, ~ 2, - 0, → 0
Change 'spec-backfill-2026-09' archived as '2026-09-21-spec-backfill-2026-09'.     # rc=0
```

Trial archive 后的合并结果核对（副本内）：panel 的 requirement 数 32 → 32（无重复、无丢失），看板页
scenario 5→6、工作页 4→5，base 的 5+4 条全部保留；`boundary`/`board-and-status`/`delivery-guard`/
`verification` 的 requirement 数分别 5→8、6→9、9→10、7→8。

## 对照表（规则 → requirement → 证据 → 复核方法）

| # | requirement | 证据（file:line） | 复核方法 |
|---|---|---|---|
| 1a | `boundary#Destructive tmux calls that resolve to the shared default socket are refused` | `scripts/shim/tmux` L10–12、L15–27、L129–162、L180–199；`tests/smoke.sh` §31c L10156–10175 / L10179–10211 / L10269–10274 / L10284–10296 / L10345–10385 | `TEAM_SMOKE_FAST=1 … smoke.sh` §31c 绿；变异见 §31c ①d（摘掉 `_real_dir` → 假隔离探针不再被拒） |
| 1b | `boundary#Every gate decision is logged and the gate is injected into the windows` | `shim/tmux` L165–176；`smoke.sh` L10302–10310、L10317–10329、L10386–10464；`tests/tmux-lint.pl` L26–30/L343/L497/L503；`smoke.sh` L10038–10056（M41 翻转④⑤） | FAST smoke §31/§31c 绿；lint 对字面绝对路径红、对 `"$REAL_TMUX"` 净 |
| 1c | `boundary#Destructive tmux fixtures run inside the container` | `tests/container-tmux.sh` L1–40（exit 77 契约）、L177/L218/L239–243（宿主 socket 不可见、指纹不变）；`smoke.sh` §31b L10058–10090 | `bash tests/container-tmux.sh --selftest`（真进程）→ 0 且宿主指纹逐字节不变；无 runtime → 77 + SKIP |
| 2 | `verification#The gate refuses tracked files that still hold conflict markers` | `smoke.sh` §0d L561–664（正/负夹具、索引侧、三类排除） | FAST smoke §0d 绿；`bash tests/flip-m44.sh` → 9 条预期（事故红、解掉绿、三个变异红） |
| 3 | `delivery-guard#The input-box verdict tolerates pi's update banner` | `tests/frames/pi-0.85.1-update-banner.txt`；`scripts/lib/outbox.sh` L75–76/L126–151/L184–215；`smoke.sh` §12b-h0b L5619–5715、§12b-h ⑳ L6088–6110；`tests/pm-box-real.sh` L16–19/L89–105/L190–196 | FAST smoke §12b-h0b 绿；真进程 `M45_REQUIRE_BANNER=1 bash tests/pm-box-real.sh --idle-secs 20`；`bash tests/flip-m45.sh` |
| 4a | `board-and-status#A duplicate board id is refused by default and visible wherever the board is read` | `smoke.sh` §4c L1030–1110；`scripts/lib/common.sh` L2927–2960/L3701–3760；`cmd-docs.sh` L47–66；`cmd-project.sh` L325–331 | FAST smoke §4c 绿；`bash tests/flip-m48.sh add`（去掉检查 → §4c 红，真树绿） |
| 4b | `board-and-status#The board addresses rows by id, and the agent column has its own entry` | `smoke.sh` §4c（assign 只改 agent 列 / 未知 id 不落盘 / set 两行同改）；`common.sh` L3660–3700；`cmd-docs.sh` L67–71 | FAST smoke §4c 绿；`bash tests/flip-m48.sh assign` |
| 4c | `panel#The board page is a kanban over the board's states`（MODIFIED） | `tests/panel-b3.sh` L163（`focused_row`/`AMBIGUOUS-CURSOR`）、L698–745；`src/layout.ts` L698–716/L744/L771–780；`src/App.tsx` L755/L766–782/L814/L844/L1230/L1802；`src/types.ts` L466–474 | `bash tests/panel-b3.sh board`（真进程：bundle + pty）；`bash tests/flip-m48.sh focus`（裸 ID 变异 → 10 条红） |
| 4d | `panel#The work page's board rows are focusable and open the same detail view`（MODIFIED） | `panel-b3.sh` L746–762 | `bash tests/panel-b3.sh workdetail`；`flip-m48.sh focus` 同覆盖 |
| 5 | `board-and-status#The ledger read path stays inside a git-call budget and its cache is an equivalence-checked view` | `smoke.sh` §37 L11426–11563（L11515/L11520/L11523/L11528/L11540/L11544/L11553/L11561）；`common.sh` L74–77；`cmd-status.sh` L216–226 | FAST smoke §37 绿；变异：让 `team_scan_cache_on` 恒假 → 计数越过预算、§37 红 |
| 6 | **不写 delta** —— 已由 `watch-degradation` 覆盖 | 分支基线上：`openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md` L3/L53/L77、`watchdog/spec.md` L3/L35；main 归档后：`openspec/specs/notify-and-inbox/spec.md` L124/L174/L198、`openspec/specs/watchdog/spec.md` L218/L250 | 下面这段 grep；并证明 `.../specs/notify-and-inbox/` 不存在（不重复写） |

```
$ grep -n '^### Requirement' openspec/changes/watch-degradation/specs/notify-and-inbox/spec.md openspec/changes/watch-degradation/specs/watchdog/spec.md
notify-and-inbox:3:### Requirement: A watcher registration failure is recorded with its cause
notify-and-inbox:53:### Requirement: Delivery continues on the polling fallback while watching is unavailable
notify-and-inbox:77:### Requirement: The inbox-watch gate measures an unavailable watcher visibly and has a strict path
watchdog:3:### Requirement: A live degraded channel is reported by `team doctor` and `team status`
watchdog:35:### Requirement: `team doctor` reports the inotify headroom of the wake channel

$ git show main:openspec/specs/notify-and-inbox/spec.md | grep -n '^### Requirement'   # 归档后即为 spec
124:### Requirement: A watcher registration failure is recorded with its cause
174:### Requirement: Delivery continues on the polling fallback while watching is unavailable
198:### Requirement: The inbox-watch gate measures an unavailable watcher visibly and has a strict path
…（另有 inbox-spool-resilience 的四条同批归档）

$ test ! -e openspec/changes/spec-backfill-2026-09/specs/notify-and-inbox && echo OK
OK
```

## Falsifiability（本任务不是 defect-fix，未跑翻转；下列是 apply/verify 要跑的包）

每条 requirement 都带一个「破坏实现 → 守卫必红」的现成包或其等价物，已写进 `tasks.md`：
`flip-m44.sh`（冲突标记）、`flip-m45.sh`（横幅）、`flip-m48.sh focus|add|assign`（行身份 / 拒绝 / 指派）、
§31c ①d（假隔离检查）、§37 变异（cache 恒假）、`container-tmux.sh --selftest`（宿主指纹）。
**propose 阶段我没有运行它们**（它们是 apply/verify 的命令；此处不冒充已验）。

## Findings

1. `finding:`（既有红，非本任务引入）FAST smoke 的 §33 completeness 在分支基线与 main 上都红：
   `references/config.md` L388–390 的三条 M53 fixture 控制键不在 `scripts/lib/cmd-config.sh` 的 schema 里，
   且 `tests/config-cli.sh:427` 的排除是 `grep -vxE`（整行精确，非前缀）。建议处置（属 `memory-and-deps`
   / M53 的后续，不是 M61）：要么把这三条键补进 schema（按其用途给类），要么——更贴近那行代码的本意——
   把 `grep -vxE` 改成真正的前缀排除并补上 `TEAM_IW_`，然后重跑全量门禁。
2. `finding:`（与任务书 `deltas:` 行的差异，**有意为之**）任务书列出 6 个 delta，其中 `notify-and-inbox`
   按任务书自己的 item 6 注明「已覆盖 → 不再添加」；覆盖证明见上表 #6。本 change 实际写 5 个 delta 文件。
3. `finding:`（任务书 `deltas:` 未列、但 item 4 需要）item 4 的面板部分要求把 base 规格里「tracked by
   entry id」改正为行身份——M48 报告 L212–216 也正是请 PM 做这条规格跟进。只改这两条 panel requirement
   （MODIFIED，base 的 5+4 条 scenario 原样保留），其余仍放 `board-and-status`。
4. 任务进行中 main 归档了 `watch-degradation`（`829dc19`）；proposal/design/tasks 已改成「基线 delta +
   main 已归档成 spec」两态都成立（提交 `519faaf`）。

## Decisions and deviations

- item 5（读预算）放 `board-and-status` 而非新能力：requirement 就是 `board row`/`digest`/`status` 的读契约，
  单条 requirement 开一个能力违背硬要求 4，也会与 `perf-suite-split` 的门禁侧改动分家（design D1）。
- 读预算只钉**调用次数**（≤1 / ≤50 / cache-off >50 的夹具非空转），不加墙钟阈值（design D5）。
- 面板两条 requirement 用 MODIFIED：base 的「按 entry id 跟踪」在重复 ID 下描述的是用户实测缺陷；
  用 ADDED 会把错句留在 base 里（design D3）。
- 交付守卫的横幅用 ADDED（不动那条超长 base requirement），并把「不得关闭 pi 更新检查」写进 requirement；
  `pm-box-real.sh` 的 `M45_REQUIRE_BANNER=1` 提供「没横幅就红、不冒充现场」的可证伪形态（design D6）。
- 面板两条新 scenario 的措辞按 `panel-b3.sh` 真正断言的内容收敛（详情页只断言到「详情 M39」，
  没有断言「哪一条 M39」），不做超出夹具的承诺。

## Suggested next steps

- PM：先把 finding 1 路由给 `memory-and-deps`/M53 的 owner（一行修复 + 重跑全量门禁），否则**任何**在 main 上
  跑的验收都会带着这条红；它挡住的是 `TEAM_SMOKE_FAST=1` 的绿，不是本 change 的提案质量。
- PM：然后做提案复审（`docs/team/reviews/spec-backfill-2026-09-proposal.md`）；`openspec validate --all
  --strict` 已绿，trial archive 已预跑通过（+8 ~2 -0）。
- 复审通过后派 apply（本 change 的 apply 是「按 `tasks.md` 核证据」；任一 requirement 与代码冲突 → BLOCKED
  交回，不许改代码），再由不同 agent verify，最后按流水线归档。
