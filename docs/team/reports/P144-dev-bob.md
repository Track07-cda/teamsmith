# P144 · `capacity-floor-disk` apply：派单前的磁盘/inode 腿 + 三个契约行 + 面板读数

agent: dev-bob   status: done   time: 2026-10-01
branch: `task/P144-capacity-floor-disk-apply-sc`（local 模式：分支留在工作树，未 push）
change: `capacity-floor-disk`（phase `apply`；`deltas: dispatch,watchdog,panel`）
base：起点 `main@d8e2417d`；开工时 merge main 一次，收尾时再 merge 到 `main@3d223353`（P139 与两条 P151/P153
的 docs 提交）。收尾 merge 后重跑了全套门禁与所有证据（见下）。
交付分支停在 `main@3d223353` 的基线上：之后 main 又走了 10 个提交（P152 发布面的修复等），**我没有再 merge** ——
因为那条 tip 在 39 段自己就是红的（见「main 上的 39 段红」），把别人未绿的回归烘进交付分支会让复验的红指向错的地方。
grant 边界：只动 `skills/teamsmith/{scripts/lib,scripts/panel,tests,references}/**` 与我自己的报告目录。

## 交付（按 change `tasks.md` 的 8 组）

| 组 | 文件 | 内容 |
|---|---|---|
| 1 R1 | `scripts/lib/common.sh` | `team_disk_stats <path>`（生产 `df -P -k` + `df -P -i`；夹具 `TEAM_DISK_STATS_FILE`，最长前缀匹配；缺行/缺列/非数字 → 该腿无读数；`itotal` 空/0 → inode 腿不适用）、`team_disk_guard <path…>`（两条阈值腿、非数字回退默认、`0` 关腿、同文件系统只判一次、读不到不判不说）、`team_disk_human_kb` / `team_disk_reading_text` / `team_disk_label` / `team_disk_remedy`；`team_capacity_line [path…]` 带每个被判文件系统的读数（RAM 在前、估算在最后） |
| 1 R1 | `scripts/lib/cmd-agents.sh` | 启动前那一趟里加 `team_df_run_lib team_disk_guard "$disk_tmp" "$wt"`（P140 的 finding 形状），放行时读数作为一条「说明」打印；判的是 `team_agent_worktree` 解析出的**这个 agent 的工作树** |
| 2 R2 | `scripts/lib/cmd-watch.sh` | `team_panel_capacity_json` 增 `disk` 数组（`path`/`avail_mb`/`free_inodes` 或 `null`/`readable`），与派单腿同一份测量；tick 行沿用 `team_capacity_line`，`capacity.log` 每行带两个文件系统的字节与 inode（500 行上限与 spark 解析未动） |
| 3 R3 | `scripts/lib/cmd-status.sh`、`scripts/lib/cmd-project.sh` | `team_tmp_headroom_line` → `team_disk_headroom_lines`（每个被判文件系统一行；同一文件系统一行），doctor 用 `team_disk_doctor_rows` 打印：warn 文案说「现在派单会被拒绝」+ 修法，读不到说读不到（绝不 pass），不报 inode 表说出来；退出码与 swap 警告未动 |
| 4 R4 | `scripts/panel/src/{types,layout,strings/zh,strings/en}.ts`、`scripts/panel/panel.js` | `PanelCapacity.disk` 类型、状态带里每个文件系统一段（`—` 回退，spark 宽度扣掉读数占宽）、zh/en 标签、重建提交的 bundle |
| 5 | `tests/smoke.sh`（6b） | R1 的六态夹具 + 读数面 + 逃生口令 + 三个契约行 + 只读断言 + 旧腿的反向断言 + P140 整合断言 + `[real]` 两拍 `capacity.log` |
| 5 | `tests/flip-p144.sh` | 翻转夹具：`skills/` 副本上跑两遍 `--select 6b`（对照 / 拆掉磁盘腿），要求红在磁盘族断言上 |
| 5 | `tests/panel-p21.sh`（settings 场景） | 三个新契约行的行文本/徽章/回车路线断言 |
| 7 Docs | `references/config.md`、`references/troubleshooting.md` | 两个阈值进 backtick 键表（含推导）并移出「故意不进契约面」段（`TEAM_TMP_KEEP`/`TEAM_TMP_SWEEP_AGE` 留下）、夹具缝一行；ENOSPC 行写清拒绝内容/修法/逃生口令 |
| 8 R5 | `scripts/lib/cmd-config.sh` | 两个 `apply` 阈值行（`mb` 1024 / `int` 100000，组 `delivery`，`0` 的 danger 注记）+ `TEAM_DISK_STATS_FILE` `refuse` 行；`--allow-danger` 的容量底线清单加上这两个键 |

## 提交（`git log --oneline main..HEAD`）

```
6b0e0283 test(P144): the disk leg and the memory leg are two findings of one refusal
8d7890c2 Merge branch 'main' into task/P144-capacity-floor-disk-apply-sc
24b207dc merge(P144): bring main's pre-launch pass in and make the disk leg one of its findings
dc73254d test(P144): assert the old capacity leg did not move and that reading writes nothing
d7c2e480 test(P144): keep the frame comparisons honest about the new live readings
8fa264b4 test(P144): pin the three contract rows in the settings view and add the flip
03d97637 test(P144): pin the six disk fixtures, the readings and the escape in smoke 6b
d54e56e4 feat(P144): register the disk floor's keys and render the readings in the band
dbae2df6 feat(P144): carry the disk readings in the capacity block and the tick line
293a0a99 feat(P144): refuse a dispatch on the disk leg and give doctor one row per filesystem
7d337fbc feat(P144): measure the disk/inode leg and judge it before dispatch
```

## 验收命令与原始输出（全部在收尾 merge 之后重跑）

| 命令 | 结果 | 原始输出 |
|---|---|---|
| `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | `Totals: 19 passed, 0 failed (19 items)` | 本文件末尾 |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` | `== 结果 == ✓ 3384 ✗ 0` | `docs/team/reports/P144-dev-bob/gates-fast.txt` |
| 同上，**在交付 tip `740a1fc8`（tree `a6b8951b`）上重跑**（PM 说事故那一轮的结论作废） | `== 结果 == ✓ 3384 ✗ 0`，rc=0 | `gates-fast-rerun-tip.txt` |
| `bash skills/teamsmith/tests/smoke.sh </dev/null`（全量） | `== 结果 == ✓ 4116 ✗ 0` | `docs/team/reports/P144-dev-bob/gates-full.txt` |
| 同上，第一次跑（收尾 merge 后、机器上有别人的门禁与两个孤儿容器时） | `✓ 4114 ✗ 1`（51 段）—— 未复现，见「§51 那一条红」 | `gates-full-attempt1-red.txt` |
| `bash skills/teamsmith/tests/config-cli.sh </dev/null` | `✓ 335 ✗ 0` | `config-cli.txt` |
| `node skills/teamsmith/tests/panel-strings.mjs .` | `panel-strings: ok` | `panel-strings.txt` |
| `TMUX_TMPDIR=<私有> bash skills/teamsmith/tests/panel-p21.sh settings` | `✓ 55 ✗ 0` | `panel-p21-settings.txt` |
| `bash skills/teamsmith/tests/flip-p144.sh --keep` | 对照 `✓ 192 ✗ 0` / 断侧 `✓ 175 ✗ 17`，翻转成立 | `flip.log` + `flip-green.log` + `flip-red.log` |
| `bash docs/team/reports/P144-dev-bob/evidence.sh` | R1 六态 + doctor 三态 + 面板 + capacity.log + 逃生口令 + 契约行 | `evidence.log` |

## What flips（红 → 绿）

断侧 = 把启动前那一趟里的 `team_df_run_lib team_disk_guard "$disk_tmp" "$wt"` 删掉（D67 的失明形态：
文件系统已经贴墙也不拒绝，席位照样被 ENOSPC 打死）。两侧跑同一份 `--select 6b`，都在 `skills/` 的整棵副本里
跑，当前树一个字节不动。

- 对照侧：`== 选段结果 == ✓ 192 ✗ 0`
- 断侧：`== 选段结果 == ✓ 175 ✗ 17`，17 条红全部落在这次修的那件事上，每条都带着「找不到什么」：

```
✗ 临时根低于磁盘底线时应当拒绝派单
✗ 拒绝点名临时根路径（…/disk-full.log 中找不到 [临时根 /tmp 磁盘不足]）
✗ 拒绝点名实测字节与阈值（… 中找不到 [可用 120.0 MB < 底线 1024MB]）
✗ 拒绝点名实测 inode 与阈值（… 中找不到 [inode 可用 40000 < 底线 100000]）
✗ 拒绝给临时根的归属有据修法（… 中找不到 [tmp-hygiene.sh --status 看清单，再 --sweep]）
✗ 拒绝给显式逃生口令（… 中找不到 [TEAM_TMP_MIN_FREE_MB=0]）
✗ 拒绝发生在任何开窗动作之前（没有打出启动计划）（不该出现 [=== agent 命令]）
✗ 字节低（无 inode 表）时应当拒绝        ✗ 工作树低于底线时应当拒绝
✗ 拒绝点名该 agent 的工作树路径（… 中找不到 [工作树 …/.worktrees/dev 磁盘不足]）
✗ 逃生口令前：字节腿低于底线应当拒绝      ✗ 关掉字节腿不该关掉 inode 腿
✗ 同一份拒绝里有磁盘阻塞项（… 中找不到 [磁盘不足]）
✗ 拒绝末行数出两个阻塞项（… 中找不到 [共 2 个阻塞项]）
```

- 脚本自己的判定：`flip-p144: 翻转成立（断侧红 → 修好侧绿）`

## 关键原始输出（节选，全文在 `evidence.log`）

```
$ TEAM_DISK_STATS_FILE=<full：/tmp 120MB/40000 inode> team dispatch dev T1.1 <brief> --print
✗ 临时根 /tmp 磁盘不足（可用 120.0 MB < 底线 1024MB、inode 可用 40000 < 底线 100000）：拒绝派单
✗   读数：可用 120.0 MB（inode 40000）（总 14.5 GB）
✗   修法：bash …/tests/tmp-hygiene.sh --status 看清单，再 --sweep 回收（只回收归属可证的根）
✗   或显式冒险：TEAM_TMP_MIN_FREE_MB=0（关字节腿）/ TEAM_TMP_MIN_FREE_INODES=0（关 inode 腿）team dispatch …
共 1 个阻塞项 —— 修好上面每一项后重新派单（--force 只覆盖允许覆盖的项）     # rc=1，没有打印启动计划

$ TEAM_DISK_STATS_FILE=<plenty> team dispatch … --print                       # rc=0
  RAM 可用 7812MB ｜ 磁盘 swap 空闲 64511MB ｜ 临时根 /tmp 可用 5.0 GB（inode 2978499） ｜ 工作树 …/.worktrees/dev 可用 5.0 GB（inode 2978499） ｜ 估算可再加 11 个 agent

$ TEAM_DISK_STATS_FILE=<none：临时根没有行> team dispatch … --print           # rc=0，无拒绝无警告
  RAM 可用 7812MB ｜ 磁盘 swap 空闲 64511MB ｜ 临时根 /tmp 无法读取 ｜ 工作树 … 可用 5.0 GB（inode 2978499） ｜ 估算可再加 11 个 agent

$ TEAM_DISK_STATS_FILE=<noino：itotal=0、字节足> team dispatch … --print      # rc=0，inode 腿不印数字
  … ｜ 临时根 /tmp 可用 5.0 GB（inode n/a） ｜ 工作树 … 可用 5.0 GB（inode n/a） ｜ …
$ TEAM_DISK_STATS_FILE=<noino、字节低> team dispatch … --print                # rc=1，只点字节阈值
✗ 临时根 /tmp 磁盘不足（可用 120.0 MB < 底线 1024MB）：拒绝派单        # 没有点 inode 阈值
$ TEAM_DISK_STATS_FILE=<工作树 120MB> team dispatch … --print                 # rc=1，点名该 agent 的工作树
✗ 工作树 …/.worktrees/dev 磁盘不足（可用 120.0 MB < 底线 1024MB）：拒绝派单
✗   修法：腾空这个文件系统：…/.worktrees/dev（清掉占用它的产物；本工具不代删）

$ TEAM_DISK_STATS_FILE=<full> TEAM_TMP_MIN_FREE_MB=0 TEAM_TMP_MIN_FREE_INODES=0 team dispatch … --print   # rc=0
  RAM 可用 7812MB ｜ 磁盘 swap 空闲 64511MB ｜ 临时根 /tmp 可用 120.0 MB（inode 40000） ｜ …

$ team doctor（夹具 full 那一跑）
  临时根余量          ! /tmp：可用 120.0 MB / 总 14.5 GB 低于底线 1024MB、inode 可用 40000 / 总 3811434 低于底线 100000 —— 现在派单会被拒绝；修法：… tmp-hygiene.sh --status 看清单，再 --sweep 回收
  工作树余量          ✓ …/.worktrees：可用 289.2 GB / 总 930.2 GB · inode 可用 2978499 / 总 3811434
  容量 / swap 底线     ✓ RAM 可用 11052MB ｜ 磁盘 swap 空闲 54430MB ｜ 临时根 /tmp 可用 120.0 MB（inode 40000） ｜ … ｜ 估算可再加 10 个 agent
$ team doctor（读不到临时根）       临时根余量  ! /tmp 的余量读不出来（…）—— 绝不当作充足；修法：…
$ team doctor（不报 inode 表）      临时根余量  ✓ /tmp：可用 5.0 GB / 总 14.5 GB · inode 不适用（这个文件系统不报 inode 表）
  磁盘低的 doctor 与不带夹具的 doctor 退出码相同 → 宿主资源行不改退出码：yes

$ team monitor --json → panel.capacity.disk
  [{"path": "/tmp", "avail_mb": 5120, "free_inodes": 2978499, "readable": true},
   {"path": "…/.worktrees", "avail_mb": 5120, "free_inodes": 2978499, "readable": true}]      # 没有 zram 键
$ team monitor --print          RAM 7.6G ｜ swap 63.0G ｜ 可再加 11 个 agent ｜ /tmp 5.0G（inode 2978499） ｜ …
$ tail -2 .pi/team/state/capacity.log
2026-10-01T20:02:29Z RAM 可用 7812MB ｜ 磁盘 swap 空闲 64511MB ｜ 临时根 /tmp 可用 5.0 GB（inode 2978499） ｜ 工作树 …/.worktrees 可用 5.0 GB（inode 2978499） ｜ 估算可再加 11 个 agent
（两拍两行，行数=3 = 首拍前的一次 + 两拍）

$ TEAM_CONFIG_FILE=<契约副本> team config set TEAM_TMP_MIN_FREE_MB 0            # rc=7
✗ TEAM_TMP_MIN_FREE_MB=0 是危险值：容量底线归零（守卫失效）（确认要写就加 --allow-danger）
被拒的写没动契约副本：yes     # 审计：… result=danger-refused actor=cli key=TEAM_TMP_MIN_FREE_MB old='' new='0'
$ TEAM_CONFIG_FILE=<副本> team config set TEAM_TMP_MIN_FREE_MB 0 --allow-danger --yes    # rc=0，契约可解析
2026-10-01T20:02:30Z result=ok actor=cli key=TEAM_TMP_MIN_FREE_MB old='' new='0'
$ TEAM_CONFIG_FILE=<副本> team dispatch … --print                             # rc=0（字节腿关）
$ TEAM_CONFIG_FILE=<副本> TEAM_DISK_STATS_FILE=<inode 低> team dispatch … --print
✗ 临时根 /tmp 磁盘不足（inode 可用 40000 < 底线 100000）：拒绝派单          # inode 腿照旧判
主契约逐字节未动：yes（1255ea4d…）

$ team config list --json
TEAM_TMP_MIN_FREE_MB       class=apply   default=1024    group=delivery  value='0'
TEAM_TMP_MIN_FREE_INODES   class=apply   default=100000  group=delivery  value=''
TEAM_DISK_STATS_FILE       class=refuse  default=        group=policy    value=''
$ team config set TEAM_DISK_STATS_FILE <path>     # rc=5（refuse 类）
$ openspec validate --all --strict                # Totals: 19 passed, 0 failed (19 items)
```

## Delta → requirement → 实现 → 测试

| delta | requirement | 实现 | 测试（自己跑的） |
|---|---|---|---|
| `specs/dispatch/spec.md` | `The capacity floor protects the host`（磁盘/inode 腿、读数、schema 行） | `common.sh`、`cmd-agents.sh`、`cmd-config.sh` | smoke 6b 六态 + 逃生 + 契约行 + 只读 + 旧腿反向 + P140 整合；`config-cli.sh`；`flip-p144.sh` |
| `specs/watchdog/spec.md` | `Restart quota and capacity logging`（tick 行带读数） | `cmd-watch.sh` 的调用点 + `common.sh` | 6b `[real]` 两拍 `capacity.log`；26-n 帧比较 |
| `specs/watchdog/spec.md` | `` `team doctor` reports the temp root's headroom `` | `cmd-status.sh`、`cmd-project.sh` | 6b 的 doctor 三态 + 退出码不变 + 只读 |
| `specs/panel/spec.md` | 状态带带读数 | `cmd-watch.sh`（JSON）、`panel/src/**`、bundle | 6b 的 `--json`/`--print`；26-c/26-f/28-e；38-f（真 pane，全量里跑） |
| `specs/panel/spec.md` | 三个键是控制台读得到的契约行 | `cmd-config.sh`、`strings/{zh,en}.ts` | 6b 的 `config list --json`；`panel-p21.sh settings`；`panel-strings.mjs`；`config-cli.sh` |

## §51 那一条红（第一次全量跑）—— 未复现，附证据

第一次收尾全量门禁（`gates-full-attempt1-red.txt`）报了 `✓ 4114 ✗ 1`，红的是 **51 段（用法诚实性：
`tests/routes.sh`）**。当时的现场：

- 该段用时 271s，超出它自己的实测带 231s（机器当时还跑着别人的门禁容器与两个孤儿容器 —— 我此前用
  `pkill -f smoke.sh` 清自己后台门禁时误伤了别的门禁客户端，两个容器一直挂到自行退出）。
- 段内打印的 10 行 `✗` 其实都是**通过**的断言（它们的「说明」字段是工具自己的红字首行，例如
  `✓ 断言 L38：dispatch --print → rc=2 ｜ ✗ dispatch <agent> …`），真正的 finding 被 `head -10` 截掉了 ——
  这是 51 段失败摘录本身的弱点，不是本次代码的结论。
- 复现尝试：① 单独 `--select 51`（FAST）✓ 190 条断言；② 收尾后 FAST 全套 ✓ 3384 ✗ 0（含 51）；
  ③ 收尾后**全量**再跑一次（`TEAM_TMP_KEEP=1`，同一棵树、同一段）✓ **4116 ✗ 0**，51 段绿。
- 对照：**原样的 main（`3d223353`，`/tmp` 里的干净拷贝）**跑全量是 `✓ 4060 ✗ 1`，红的是 **M28 容器里跑真
  pi 体检**（另一条红，与 51 无关）—— 也就是说那段时间这台机器上的容器/门禁环境本身不稳。
- 结论：51 段那条红**不是这次改动造成的**（同一棵树、同一段重跑全绿），最可能是当时的机器/容器环境与
  并发负载下 `routes.sh` 里逐条 `timeout` 包裹的探针被拖超时。**我没有把它算成绿**：两侧的原始日志都在
  报告包里（`gates-full-attempt1-red.txt` / `gates-full.txt`），请 PM 在自己的独立复验里判。

## main 上的 39 段红（不是这次改动，已报 PM）

收尾后又把 main 的 10 个新提交（`7d2c868b` 等）merge 进来重跑 FAST，红在 **39 段（`install-shape.sh`）**：

```
✗ 39 install-shape.sh 有失败
      ✗ README 的 bash 行没写检查
      ✗ 没有 bash：拒跑、点名 bash/4、指向 Requirements：没点名最低版本 4：[teamsmith: … 需要 bash >= 5。…]
      ✗ 老 bash（探针答 3）：点名 3 与 4、CLI 没跑：没点名最低大版本 4：[teamsmith: bash 版本太旧：… 需要 bash >= 5。…]
```

即 main 自己把 CLI 的最低版本提到 bash >= 5（`cmd-project.sh` 的 doctor 行 + 启动器文案），却没同步
`tests/install-shape.sh` 的三条旧断言（仍在点名 4）。**在干净的 main 拷贝上单独跑 `--select 39` 一样红**
（`✓ 21 ✗ 1`）—— 与本 change 无关，不是我能自己动手修的范围（属于那条改动的 owner）。
处理：没有把它修进交付分支，而是把 merge 撤回到 `main@3d223353`（我的分支保持全绿），并把这条红连同
复现步骤报给 PM（`team notify`）。

## 事故后重跑（PM 的 inbox 指令：那一轮结论作废）

被 `pkill` 误伤的那一轮门禁（还有别人的客户端）结论作废 —— 此后每一次门禁都是**新跑**的，不是复用旧日志：

| 轮 | 对象 | 结果 | 日志 |
|---|---|---|---|
| 全量 #1 | 收尾 merge 后（`main@3d223353` + 本 change） | `✓ 4114 ✗ 1`（51 段，未复现） | `gates-full-attempt1-red.txt` |
| 全量 #2 | 同上，`TEAM_TMP_KEEP=1` | `✓ 4116 ✗ 0` | `gates-full.txt` |
| FAST #1 | 同上 | `✓ 3384 ✗ 0` | `gates-fast.txt` |
| FAST #2 | **交付 tip `740a1fc8`（tree `a6b8951b`）** | `✓ 3384 ✗ 0`，rc=0 | `gates-fast-rerun-tip.txt` |
| config-cli / panel-strings / panel-p21 settings / flip / evidence | 同上 | 见上表 | 各自的日志 |

交付 tip 与全量 #2 的**代码树逐字节相同**（tip 上只多了三个 docs 提交），所以全量的结论适用于交付 tip；FAST #2 则是直接在交付 tip 上跑的。

## 自己跑的 / 引用的

- **自己跑**：`openspec validate --all --strict`、FAST 全量、全量（两次）、`config-cli.sh`、`panel-strings.mjs`、
  `panel-p21.sh settings`（私有 `TMUX_TMPDIR`）、`flip-p144.sh`（两侧）、`evidence.sh`、`--select 6b/26/28/33/36/38/51`
  的选集，以及 main 干净拷贝上的对照全量。
- **引用**（未单独复跑）：`panel-b2.sh` / `panel-cpu.sh` / `routes.sh`（单独跑过）/ `section-needs-audit.sh` 等
  只在全量门禁里跑到的段落 —— 结论来自上面全量日志的原始输出，不是单独跑出来的。

## 偏离、说明与自查

1. **与 P140 的整合**（收尾 merge 才看到 main 的启动前那一趟）：磁盘腿从「自己 `return 1`」改成
   `team_df_run_lib team_disk_guard …` 的一个 finding，读数改成放行时的一条「说明」。守门断言：磁盘 + 内存
   双低时必须是**一份**拒绝、点名两个阻塞项、末行 `共 2 个阻塞项`（6b ⑮）。delta 的每条 scenario 逐条仍成立。
2. **帧比较的归一化**：磁盘读数会随文件创建变化（inode 计数），26-n 与 28-e 把「可用 X（inode N）」当易变量
   处理（28-e 另加磁盘夹具），否则那些段会因为机器正常活动变红；`--json` 的字段形状仍由 26-f 逐字段断言。
3. **读数只读**：6b 在测量函数与 `team doctor` 跑一圈前后比 `state_fp`，一个字节都不许变。
4. **反向断言（不动既有容量腿）**：既有内存守卫断言（MemAvailable 见底 / swap 见底 / zram 只警告）仍绿，
   另加形状断言：容量行仍是 RAM → swap → 磁盘读数 → 估算，zram 分账文案照旧。
5. **8.3（数 schema 键的夹具不许写死旧值）**：`config-cli.sh`（`wc -l` 现算）、`panel-choices.sh`
   （`schema_count` 现算）、`panel-p21.sh settings`（按过滤导航；本次输出 `rows(13)+↑(0)+↓(105)=命令报的键+席位（118）`）
   三处都随 schema 增长，没有写死值需要改。
6. **事故自报**：收尾时我用 `pkill -f 'smoke.sh'` 清自己的后台门禁，模式命中了同时段别人的门禁客户端
   （`teamsmith-gate:local` 容器夹具与 `p148-public` 的 FAST 门禁），已当场 `team notify` 报给 PM；两个容器
   自行退出。若 P148 复验因此报红/超时，成因是我而不是被测代码。此后我只按自己的 job pid 收尾。
7. **本地模式**：本仓库无远端，分支留在 `.worktrees/dev-bob` 的 `task/P144-capacity-floor-disk-apply-sc`
   上，未 push；等 PM 独立复验后本地合并。
