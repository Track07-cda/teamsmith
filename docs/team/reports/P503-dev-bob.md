# P503 · Pulse 看板最近更新优先

agent: dev-bob   status: DONE   time: 2026-11-25T11:04:08Z

branch: `task/P503-pulse-board-recent-first-apply`   PR/MR: -

**已实现，构建和静态检查通过；行为尚未独立验收。** Pulse 第四页各栏先显示最近实际新增、换人或改状态的任务；没有记录时间的旧任务不补日期。第四页的键盘、鼠标和刷新按同一份顺序找原任务行；工作页、命令行行序及机器输出的原布局不改。`board ls` 和 `board row` 原样显示任务表，因而可以看到新列。

## Deliverables

| 路径 | 交付 |
|---|---|
| `skills/teamsmith/scripts/lib/{common,cmd-watch}.sh` | `68f9565c`、`902af680`：两个原写入口共用按实际替换路径定位的锁。锁内按旧方式找行、找列、判重和决定插入位置；仅当实际变化的行对齐可辨认的任务表时，在同次替换写入专用末列。替换失败不清原调用进程缓存、不记新增成功。原批量 `board` 块按物理行附可选时间，不改行序和计数。 |
| `skills/teamsmith/scripts/panel/{src,README.md,panel.js}` | `25468b66`、`ef9dffcf`：第四页单独生成显示顺序，同编号仍按原文件中的出现次序认行。宽屏保持各栏偏移，自动取到新数据时仅对原来可见、重排或换栏后出窗的选中卡补偿；窄屏仍是一个跟随焦点的窗口。卡片不显示时间。提交实际加载的 bundle；README 记录产物字节数和哈希。 |
| `skills/teamsmith/tests/{panel-b3.sh,panel-b3-pty-mouse.py,smoke.sh}`、`openspec/changes/pulse-board-recent-first/tasks.md` | `3ce14bdb`：只在已有 `board` 场景委托真实私有项目的看板和详情读取，复用原直驱 PTY、计轮等待和 `fold` 栏头滚轮。4c 仅把已声明的专用末格排除出原非负责人列比较。清单只勾实现项 1.1、1.2、2.1；§3 全部保留给独立验收。 |

## OpenSpec assessment

| 维度 | 作者阶段结论 | 依据 |
|---|---|---|
| 完整性 | 实现已落盘，未验行为 | 原变化的两份要求及设计未改；清单 §3 未勾。构建使用真正的入口 `build.sh`，锁定依赖文件未改。 |
| 正确性 | 静态核对通过 | 新增和字段写入在锁内使用 `TEAM_SCAN_CACHE=0`；状态相同或负责人去首尾空白后相同不更新时间。行时间比较使用规范形状及 UTC 解析后的往返值；同秒保持文件顺序，历史栏的无时间行从文件尾开始。 |
| 一致性 | 原调用路径未改 | `cmd-docs.sh` 的 `task/board add` 仍进 `team_board_add`；`board set/assign`、派单登记 `wip`、办结的状态写入仍进原字段写入入口。`cmd-agents.sh:1574` 仍只在板写入成功时删 pending；`cmd-review.sh:1561` 仍按板写入结果区分办结审计与未更新提示。`buildJson` 仍只输出 `panel/activity`，`--print --page 4` 继续用原文件序和原历史窗口。 |

## CRITICAL / WARNING / SUGGESTION

作者静态检查未发现新增阻塞。没有运行真实写入、并发、画面、鼠标或失败行为，不能据此判定这些行为通过。

## Verification evidence

实际工具：GNU Bash `5.3.9(1)`、Node `v24.22.1`、Bun `1.3.14`、TypeScript `6.0.3`、Python `3.13.12`、OpenSpec `1.16.0`、Git `2.53.0`。TypeScript 使用环境已有的 `tsc`；项目目录已有 `node_modules`，冻结安装检查 45 项、46 个包，未变更锁文件或全局包。

```text
$ bash -n skills/teamsmith/scripts/lib/common.sh
bash -n skills/teamsmith/scripts/lib/common.sh rc=0
$ bash -n skills/teamsmith/scripts/lib/cmd-watch.sh
bash -n skills/teamsmith/scripts/lib/cmd-watch.sh rc=0
$ bash -n skills/teamsmith/tests/panel-b3.sh
bash -n skills/teamsmith/tests/panel-b3.sh rc=0
$ bash -n skills/teamsmith/tests/smoke.sh
bash -n skills/teamsmith/tests/smoke.sh rc=0
$ python3 -c 'import ast,pathlib,sys; p=pathlib.Path(sys.argv[1]); ast.parse(p.read_text(), filename=str(p))' skills/teamsmith/tests/panel-b3-pty-mouse.py
Python AST parse rc=0
```

最终构建 `p503-final-bundle`，退出 0：

```text
$ export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
$ ( cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile && tsc --noEmit )
bun install v1.3.14 (0d9b296a)
Checked 45 installs across 46 packages (no changes) [2.00ms]
tsc --noEmit rc=0
$ bash skills/teamsmith/scripts/panel/build.sh
Bundled 562 modules in 47ms
panel.js written (975138 bytes, sha256 d654596f29c8572d7742f523d147193478e0e155feaa3d366fc1ba7daf797e06)
bundle build rc=0
$ git diff --exit-code -- skills/teamsmith/scripts/panel/{package.json,bun.lock}
[无输出，rc=0]
$ openspec validate pulse-board-recent-first --type change --strict --no-interactive
Change 'pulse-board-recent-first' is valid
OpenSpec strict rc=0
$ git diff --check
[无输出，rc=0]
$ git diff --cached --check
[面板提交和场景提交均无输出，rc=0]
$ git diff --check 24b30c18..HEAD
[实现及场景提交无输出，rc=0]
```

账本检查：

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<dev-bob worktree> scope=published files=3105 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Flip evidence / 独立验收交接

作者没有运行 `panel-b3.sh board fold`、`smoke.sh --select 4c`、机器输出对照、反例或全量套件。没有启动真实 Pulse，也没有改正在使用的任务表。以下是独立席位一次执行需要的设置，不是测试回执：

1. 在 PM 固定检出中使用候选自带 bundle、Node、Python 3、Bash 和 tmux。`TMPDIR=/var/tmp`；如需指定 `TMUX_TMPDIR`，先建短路径的本轮私有目录。清除继承的 `TMUX/TMUX_PANE`，不要连到项目的活窗。顺序运行 `TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board fold` 与 `bash skills/teamsmith/tests/smoke.sh --select 4c </dev/null`，分别记下两个场景和实际执行到的 smoke 段。4c 依赖 4→2，另有前导 0、0b、0c、0d；按实际输出报告。不要重跑整组。
2. B3 的保留目录有 `board/root`、`board/board-cli`、`paths.json`、`state-path.txt`、两份原表样本及画面证据。场景先核 `main_root/worktree/docs` 和默认状态路径，再写表。只有 `board/detail` 用真实 CLI，其余块仍用原替身；`fold` 全程仍用替身。`clock-reads.txt` 只记录真实写命令取行时间的调用。`click-card.bin.*.txt` 保存点前、选中、正文和返回的完整帧；两种滚轮分别保留同一 PTY 的滚前、滚后帧。`board-after-adds.md` 是两次真实新增后的原表；`board-a-updated.md` 是 M9 实际换人后的原表。
3. 只在上述私有项目保存当前 `docs/team/BOARD.md`，临时换入 `board-after-adds.md`。令 `ROOT` 为 `board/root`，`state="$ROOT/.pi/team/state"`，`board_cli` 为场景保存的局部入口，`PANEL` 为固定检出的 bundle。用 `"$board_cli" monitor --json` 核顶层只有 `panel/activity`；用 `"$board_cli" board ls` 核专用末列、文件序和任务数。运行 `node "$PANEL" --print --lang zh --page 4 --width 120 --height 32 --root "$ROOT" --state-dir "$state" --team-cli "$board_cli"`，原序应为 M9,M8、历史栏仍取末窗；只把 `--print` 换成 `--snapshot`，同一表应显示 M8,M9、历史栏时间优先。工作页从原 B3 的 `dup-work-*` 捕获核对原行序。场景材料中有两栏各 36 张历史卡及 3 张活跃卡，核对计数不随显示顺序变化。
4. 反例只换入私有样本 `board-a-updated.md`，只渲染同样 120×32 的一帧。对正常 bundle、在独立副本把 `layout.ts` 的 `timed.sort((a, b) => b.time - a.time)` 倒为 `a.time - b.time` 后经同锁 Bun 重建的 bundle、恢复后的正常 bundle，各执行一次上面的 `--snapshot`。对三帧使用同一条 M9 应先于 M8 的断言（例如只取 `M[89] Card [AB]` 的画面行序），应见 `M9,M8 → M8,M9 → M9,M8`；保存实际 bundle 哈希和帧。反例不用启动外层 PTY，不开新测试入口，不重跑 B3 或 4c。恢复私有 `BOARD.md`；不要把反转带进候选。

## Final assessment

- CRITICAL 0 · WARNING 0 · SUGGESTION 0（仅作者静态范围）。候选可交给非作者验收，不构成合并或发布结论。
- 未验证项见上节。写入锁覆盖用同一锁目录的本版写入者，不涵盖手改、旧版本或异锁目录。每次需要记录行时间的写入只取一次行时间；原显式重复新增审计仍按既有日志路径自行记时。
- 本任务只留下本地提交；不合并、不推送，不改标签、巡检或运行中的 Pulse。

## V200 首轮失败后的定点返修 · 2026-11-25

**已修表头识别，待非作者复验。** V200 对 `78466b22` 的首轮 FAIL 保留（`docs/team/reports/V200-dev3.md`，`1810f112`）：真实新增 M9、M8 成功，但原表更新时间格是空的，已有历史时间也没读出，首帧仍显示 M9、M8。V200 在系统 mawk 上观察到赋值目标先创建元素，原表达式因而把首次出现的表头也标为重复。

`e565af56` 只改 `common.sh` 的共用 `bt_scan`：先检查列名是否已存在，再分别赋列位或重复标记。复看 `_TEAM_BOARD_TIME_AWK` 的其余 `in` 用法：两处是遍历，分别复制和删除已有元素，没有另一处把存在判断放进同一个赋值。测试、bundle、等待、解析器依赖和规格均未改。

```text
$ bash -n skills/teamsmith/scripts/lib/common.sh
bash -n common.sh rc=0
$ git diff --check
[无输出，rc=0]
$ git diff --cached --check
[无输出，rc=0]
```

返修只做上述静态检查，未重跑任何行为验收。按 PM 的更新任务书，下一轮补真实看板、此前未达项和私有旧表首次增列；沿用同一候选证据边界，已通过的 `fold` 不重跑。
