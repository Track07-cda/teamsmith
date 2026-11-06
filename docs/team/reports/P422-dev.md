# P422 · 待命迁到统一状态：唯一写点 + 一次性迁移

agent: dev   status: delivered   time: 2026-11-06T02:30:00Z
branch: `task/P422-standby-migration`   PR/MR: -（local 模式，不推远端）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/state-authority.mjs` | 新增 `standby-read/standby-on/standby-off/standby-import` 四个事务操作：待命读写与提醒共用同一把 flock、同一份快照；旧 `state/standby` 由迁移读一次后退役为 `standby.migrated`；快照的 `standby` 槽位加 `migrated` 标记（老快照缺这个键＝未迁移，不是损坏） |
| `skills/teamsmith/scripts/lib/common.sh` | `team_standby_on/off/in_standby/reason/status/migrate` 全部改走权威层，`team_standby_file` 删除（不再有第二个被当真的文件）；读失败不再静默返回「没待命」 |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `team standby` 增加 `migrate`；`on/off` 写失败就停住并说清「状态未变」；状态行改由权威层渲染（原因里的空格/标点原样保留）；面板读不到权威时按 off 显示而不弄花整帧 |
| `skills/teamsmith/scripts/strings/commands.tsv` · `help.en.tsv` · `help.zh.tsv` | 帮助面登记 `standby migrate`（用法行 + 子命令列表 + 中英文一句说明） |
| `skills/teamsmith/tests/state-authority.sh` | 新增 1.3 七组断言（①–⑦）+ 三条红臂（`standby-ignore` / `standby-file` / `standby-write`） |
| `skills/teamsmith/tests/lib/main-team-fingerprint.sh` | 事故形状判据从「这个路径必须不存在」改成「这次运行没动过它」（`main_team_touched`）：真团队的 `state/standby` 在迁移前本来就该在 |
| `skills/teamsmith/tests/death-cause.sh` · `pulse-nudge-key.sh` | 夹具的「项目主工作树」改成真 git 仓库并在里面跑（权威按当前目录所属项目钉状态根） |
| `skills/teamsmith/tests/smoke.sh` | 26-m 面板夹具的待命读写改指项目自己的 state 目录（原来另指一个临时目录，现在那会被权威当第二权威拒绝） |

## 语义（读完代码就能对照）

- **唯一真相**：快照 `standby: {on, generation, reason, since, migrated}`。`state/standby` 只在 `migrated=false` 时被读，之后即使有人在磁盘上重新造一个也不会改变任何判断（测试 ⑤b/⑤c 钉住）。
- **迁移**：`standby-import` 在同一个事务里做「读旧标记 → 写快照 → 退役旧标记」，失败顺序只会退化为「旧标记还在、快照已写」：因为快照已记 `migrated`，重放只做退役，不会重复导入（不会多加代次、不会丢原因）。
- **代次**：每次 `on` 都是新的一代（已在待命时再 `on` 也加一），`off` 不动代次，重复 `off` 一个字节都不写。迁移本身**不加代**（保持 0），这样「迁移」和「PM 重新下令停工」在记录上可区分。
- **读不落盘**：`standby-read` 不建定位器、不发布快照。未钉住的项目（还没写过状态）读到的仍是旧标记或 off，面板/巡检/`team standby status` 因此保持只读。
- **失败要说出来**：缺 flock、快照损坏、状态根与项目不符都按 P406 的约定显式失败；`team standby on` 会因此非零退出并说明「状态未变」。

## Verification evidence (must have actually been run)

```
$ bash skills/teamsmith/tests/state-authority.sh
flip 臂：unlocked,version,foreign,standby-ignore,standby-file,standby-write,manifest
== state-authority 结果 == ✓119 ✗0 SKIP0
```
1.3 的七组断言（只引关键几条）：`①a 旧标记还在时 status 读出 on 与原时间/原因`、`①f 只读路径不建定位器、不发布快照`、`②d/e/f/g 写入后统一状态：on / 代次 1 / 新原因 / migrated=true`、`③b/c/d/e 显式迁移保留原因+时间、代次仍 0`、`④b 重复迁移一个字节都不写`、`⑤b/c 手写旧标记改不动真相`、`⑥a/b/f 每次 on 加一代`、`⑦a/b 缺 flock 时非零退出并点名 flock`。

```
$ bash skills/teamsmith/tests/remind-cli.sh
flip 臂：view-stored,no-prune,highwater-lax,past-time,key-conflict-gone
== remind-cli 结果 == ✓94 ✗0 SKIP0
```

```
$ bash skills/teamsmith/tests/death-cause.sh --pure
== death-cause 结果 ==  ✓ 87  ✗ 0  SKIP 0
$ bash skills/teamsmith/tests/pulse-nudge-key.sh
== P174 结果 == ✓89 ✗0 SKIP0
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 11b,11b3,11b4,66,67
[11b] 定时巡检：有待办才叫醒 PM · ✓57 ✗0   [11b3] 启动中的 PM 一拍只拉起一次 · ✓56 ✗0
[11b4] PM 交接 --fresh-pm · ✓33 ✗0          [66] 项目状态权威夹具全绿（✓119 ✗0）· ✓3 ✗0
[67] 提醒 CLI 夹具全绿（✓94 ✗0）· ✓3 ✗0
== 选段结果 ==  ✓ 466  ✗ 0
· 这次没跑的段 124 个键（含 26 27 28 38 等面板段；见下一条单独跑）
```

```
$ bash skills/teamsmith/tests/smoke.sh --select 26,38
#7  26 · 面板（pulse-tui-panel） · ✓146 ✗0 SKIP0
#8  27 · 面板异步数据层 · ✓21 ✗0     #9  28 · 控制台表面 · ✓166 ✗0
#10 38 · 设置选项 · ✓16 ✗0（内含 panel-p21 ✓110/✓97、panel-b2 ✓167、panel-b3 ✓231）
== 选段结果 ==  ✓ 437  ✗ 0
```
（26-m 用真 `team monitor` 面板读待命、38-h 用真 `team standby on|off` 写信面，两条都在这次运行里跑到了。）

```
$ bash skills/teamsmith/tests/help-surface.sh
✓ 每个命令页打印的用法行与清单逐条相同（47 个命令 × 全部用法片段）
✓ 命令路径、旗标与用法片段在两种语言下逐字节相同
· 探针 standby     rc=0   变化=state
✓ claims: standby 写了声明的面（state）
== 结果 ==  ✓ 131  ✗ 0  SKIP 0          # rc=0
```
（改了 `commands.tsv` + `help.en/zh.tsv` 之后必跑：它校用法行与清单逐条相同、中英两种语言逐字节相同，并真的执行 `standby on --reason probe` 探针。）

```
$ ~/.bun/bin/openspec validate --all
Totals: 20 passed, 0 failed (20 items)          # rc=0
$ ~/.bun/bin/openspec validate --all --strict
Totals: 0 passed, 20 failed (20 items)          # rc=1
```
`--strict` 的 20 条失败**全部**是 “Requirement text is very long (>500 characters)” 警告被 strict 计入，20 个规格全部命中（含我一行没碰的 `agent-adapters`、`board-and-status`、`boundary` 等），与本次改动无关；任务书列的命令是不带 `--strict` 的那条，它是绿的。

```
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) in 13736 effective line(s); retired 0; undeclared 0   # rc=0
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ git diff --check
（无输出，rc=0）
```

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
docs/team/reviews/P415.md:7: [names] ## 一、问题（我在 <names#8> 的活 PM 上定位，不是听报告）
docs/team/reviews/P418.md:9: [names] <names#3>（0.4.1 + `team up`）回复仍带 `[[team-reply]]`…
docs/team/tasks/P415-safe-dir-own-group.md:33: [user] drwxrwxr-x <user> <user>  /…/Documents/syncthing/Work/Projects
docs/team/tasks/P420-dispatch-state-identity.md:23: [home] ✗   分支：task/P417-mark-loaded-at-launch（工作树 <home>/…/.worktrees/dev 还停在它上面）
ledger-ban: root=<home>/…/pm-skills/.worktrees/dev scope=published files=2412 hits=15 names=ok user=resolved
$ echo $?
1
```
- 15 条命中**全部**在 `docs/team/tasks/P415…P420*.md`、`docs/team/reviews/P415/P418.md` 这类**已有**文件里（他项目名与绝对家目录），没有一条落在我这次改的文件上（`git diff --name-only` 只列出上表那 9 个文件）。同一份扫描**不带** `--names-file` 时是 `hits=6 names=missing`（工作树里没有 `.pi/team/forbidden-names.txt`，该项按设计 SKIP，不算通过）。
- 也就是说：`smoke.sh` 的 P212 ④「真实账本禁令扫描」在当前树上本来就是红的（它不带名单文件，判 `[home]/[user]` 六条）。这不是本次引入，但会在整套门禁里出现，**PM 复验时会看到**。
- 我自己的新增文本没有新增任何命中：报告里一律写 `<home>` 占位。

- Verdict: pass（本任务书列出的每条验收命令都跑过，结果如上；未跑的是整套门禁）
- Notes:
  - **没跑整套门禁**（124 个键未跑）：按本仓库约定，整套留给合并/收口；这次跑的是本改动直接触及的面（巡检 11b/11b3/11b4、权威 66、提醒 67、面板 26/27/28/38、帮助面全套）。
  - 没有在**真项目**上执行迁移：迁移命令要在 PM 合并且让 PM/pulse 重启到新代码之后，由 PM 在真项目上跑一次（见下）。

## Flip evidence (required for defect-fix tasks)

三条新红臂都是「改坏实现 → 同一条具名断言必须红」：

```
$ bash skills/teamsmith/tests/state-authority.sh --flip=standby-ignore
✓ flip 变异已落地：迁移不再读旧标记
✓ flip（忽略旧标记）：原实现保留 on+原因，变异体成了 off、原因也没搬进来 —— ③b/③d 会红
$ bash skills/teamsmith/tests/state-authority.sh --flip=standby-file
✓ flip（读回文件）：原实现仍 off，变异体被旧标记改回 on —— ⑤b 会红
$ bash skills/teamsmith/tests/state-authority.sh --flip=standby-write
✓ flip（写回文件）：原实现的快照记 on，变异体只写了 state/standby（快照里没有 on）—— ②d 会红
```
不带 `--flip` 时七条臂全跑（✓119 ✗0）。

修红的过程（同一个判据，先红后绿）：
```
⑦a 缺 flock 时没有显式失败（rc=0，输出：… flock unavailable …|rc=1）   # 断言拿错了层：runchild 自己的 rc
事故形状：夹具在主项目里留下了 .pi/team/state/standby                    # 判据错了：真团队本来就有这个文件
→ 改成「退出码 1 + 报错点名 flock」「这次运行没动过它」后：⑦a/⑦b/⑤ 全绿，仍保留可证伪性（flip 臂照旧咬得住）
```

## 现场（真项目，只读）

```
$ cat <main-checkout>/.pi/team/state/standby
2026-11-05T15:24:19Z board clean, seats stopped; waiting on the two user decisions …
$ ls <main-checkout>/.pi/team
state            # 没有 reminder-locator.json、没有 state/reminders —— 项目还没被权威钉住
```
- 任务书里写「`state/standby` 目前不存在」——**实测它存在**（上面是原文）。所以真实团队当前是 `standby on`，迁移必须把它原样带过来（原因是两条等用户决定的事），不能当成「没有待命」。
- 迁移后用户看到的首行应是 `standby: on（自 2026-11-05T15:24:19Z，原因：board clean, seats stopped; …）`，代次 0。
- **升级中的团队不会被读成「没待命」**（这就是任务书第 3 条的现场证据，沙盒里跑真面板）：

  ```
  $ printf '2026-11-05T15:24:19Z board clean, waiting\n' > state/standby   # 未钉住的临时项目
  $ team monitor --print --no-pulse --once
  teamsmith pulse · sa-panel  02:36:33  巡检 900s · 待命 on（原因：board clean, waiting）
  …
  $ find .pi/team -maxdepth 3; ls state
  .pi/team/config.sh          # 没有 reminder-locator.json、没有 state/reminders
  standby                     # 旧标记原样未动（展示路径不写盘）
  ```

## Decisions and deviations

- 任务书末尾写「报告 `docs/team/reports/P421-dev.md`」，但本任务 id 是 P422、派单指令也是 P422 —— 按 P422 写（本文件）。P421 是另一个已存在的 id，写成 P421 会盖掉别人的报告。
- 快照结构：`standby` 槽位新增 `migrated` 布尔键，`version` 保持 1（缺这个键的老快照合法＝「未迁移」，不是损坏；有键但类型不对才按损坏拒绝）。
- 读路径**不**创建定位器/快照（只读不落盘）：这样面板、巡检、`team standby status` 仍然是纯读；代价是「未钉住的项目」读到的是旧标记或 off，直到第一次写或显式迁移。这一点与 P420（显式 `TEAM_STATE_DIR` 必须被尊重）不冲突：写仍然只会落在项目钉住的那个根上，换个 `TEAM_STATE_DIR` 去写会被显式拒绝（`canonical state-root mismatch`）。
- 新增 `standby migrate` 是**唯一**的新命令面（帮助面已同步登记）；没有新增配置键、没有新增文件格式。
- 两个夹具（`death-cause`、`pulse-nudge-key`）改的是「夹具自己的项目根是真 git 仓库并在里面跑」——不是放宽产品的身份判据（§4 的「继承根与目录不一致必须拒」仍然绿）。
- 面板 26-m 夹具原来把待命写进另一个临时目录；权威钉住状态根之后那等于「挑第二个权威」，所以改指项目自己的 state。这是夹具形状变化，不是产品放宽。

## Suggested next steps

- PM 复验：独立工作树跑 `bash skills/teamsmith/tests/smoke.sh --select 26,38,66,67`（或整套）；`state-authority.sh` 的七条 flip 臂值得抽查一条。
- 合并后**按这个顺序**收尾（真项目）：
  1. 让 PM 与 pulse 重启到新代码（旧进程还带着旧代码，`team_in_standby` 会继续读旧文件）；
  2. 在主检出跑一次 `bash skills/teamsmith/scripts/team standby migrate`，核对首行是 `standby: on（自 2026-11-05T15:24:19Z，原因：…）`、代次 0；
  3. 核对 `state/standby` 已变成 `state/standby.migrated`、`state/reminders/state.json` 里 `standby.migrated=true`；
  4. 再跑一次同样命令，应当输出「迁移：无需迁移」且快照哈希不变（幂等）。
- 已知遗留（不属于本任务，报给 PM 决定）：`docs/team` 里 15 条账本禁令命中（P415/P417/P418/P420 的任务书与复验），会把整套门禁的 P212 ④ 判红。要么把那些绝对路径/他项目名改写成 `<home>`/`<names#N>` 占位，要么在账本里明确接受；这两件都在我改动范围之外。
