# M65 · 设置选择重做：先测延迟根因，再改交互契约（propose 修订）

agent: dev2   status: done   time: 2026-09-21T17:14:00Z
branch: `task/M65-m65`   PR/MR: -（local 模式：分支留在本地工作树，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/M65-dev2/measure/run.sh` | 一键复跑：夹具 + CLI 计时 + xtrace 普查 + pty 三段计时 + 归属 + 单遍读原型（`M65_KEEP=1 bash run.sh 7`） |
| `docs/team/reports/M65-dev2/measure/measure.py` | pty 打点器：真 bundle 跑在 raw pty 上，自带最小 VT 屏模型，按键→帧时间戳；断言失败 `exit 2` 并打印现场屏 |
| `docs/team/reports/M65-dev2/measure/read-prototype.sh` | 单遍读原型（**证据，不接线**）：一次 awk + 纯 bash，与真 `team config list --json` 逐记录比对 |
| `docs/team/reports/M65-dev2/measure/results-{cli,spawns,pty,attr,prototype}.txt` + `results-pty.json` | 原始数据（本次提交就是设计里引用的那份） |
| `openspec/changes/settings-choice-editors/proposal.md` | 增补：重做的四条用户决定、测量结论、响应性目标、重做翻转 |
| `openspec/changes/settings-choice-editors/design.md` | 新增 §5（方法/原始数字/瓶颈定位/修法选型/翻转）+ D10/D11（直写契约、响应性是行为契约）+ D0/D3/D6/D8 对齐 |
| `openspec/changes/settings-choice-editors/specs/panel/spec.md` | delta 修订：选中即写（无第二确认帧）、「其他」是唯一手输路径、危险值仍一次确认、「交互路径不读盘」+ 三个新 scenario |
| `openspec/changes/settings-choice-editors/tasks.md` | 追加第 5/6 批：W 项（apply，含翻转）与 V 项（独立 verify，D31） |

**没有动实现**：`scripts/**`、`extension/**`、`tests/**` 零改动；`memory-and-deps` delta 一字未动（schema 读取侧没变）。

## 测量结果（原始数字，全部由 `run.sh` 产出）

夹具：`team init` 的真项目，schema 108 键、文件里 59 键有值；host 环境，node 24，160×40 pty。

| 段 | 中位 | 原始样本（ms） | 段内 owning-command 子进程 |
|---|---|---|---|
| `view` 设置视图首帧（有行） | **3446** | 3446 | `__panel-data --block settings` 3379 |
| `open` 选中 enum 行 → 选择器首帧完整渲染 | **3303** | 3284 3333 3314 3270 3303 3545 3252 | `--block settings` 占 99.5% |
| `move` 选择器内一次 ↓ → 帧稳定 | **6.2** | 7 6 5 6 6 6 5 | 无子进程 |
| `pick` 选中一项 → 写入编辑器首帧 | **3393** | 3262 3342 3339 3442 3460 3393 3487 | `--block settings` 占 99.5% |
| `dry` 编辑器里确认 → 确认行 | **88.9** | 90 90 86 87 86 89 91 | `config set … --dry-run` ~74 |
| `write` 二次确认 → 回执帧 | **176.1** | 175 167 165 176 182 176 187 | `config set … --yes` ~115 |

CLI 单次成本（5 次原始 ms）：`config list --json` 3227 3268 3388 3251 3164 ｜ `config list`（人读表）979 972 958
948 969 ｜ `__panel-data --block settings` 3266 3229 3304 3300 3248 ｜ `config set --dry-run` 72 76 74 74 76 ｜
`config set --yes` 115 113 114 117 115。

读路径普查（`bash -x` 一次 `team config list --json`）：26509 条 trace、**623 个外部进程**（grep 170 · head 170 ·
awk 119 · sed 109 · tr 45 …）、**最大单段间隔 6.4 ms、>20 ms 的间隔 0** —— 不是某一个慢命令，是逐键/逐行的扇出
（`team_config_file_value`/`team_config_file_comment` 每键 `grep|head`+`awk`；unknown-keys 扫描每**行**一个 `sed`）。

单遍原型：**semantic match，111 条记录与真读逐字段相同**；5 次 931 ms → **≈186 ms/次读**（对 ≈3.3 s）。

**瓶颈定位**（对应任务书四类候选）：①「视图构造（108 键一次性构图）」排除 —— 选择器帧只比数据晚 ~12 ms，
视图自己那点构图 ~67 ms；②「每次按键全量重渲染」排除 —— `move` 6.2 ms；③「写入路径同步起子进程」真实但量级小
（72–117 ms/次，dry+write 共 89/176 ms）；④**其他 = 读取路径** —— `team config list --json` 每次 3.2–3.4 s，而
控制台在**视图进入、每次开行、每次选择**都同步起它（`refreshSettings()`），于是用户体感的「打开有延迟」「确认
也有延迟」是同一个读（选择那一步也要等 3.4 s 才能到编辑器）。

**修法（数据定的）**：M1 把读从交互路径上拿掉（选择器/编辑器用屏上已有 `settings` 块构图；选中即 dry-run+写；
写完后后台只刷 `settings` 块；回执帧不被重读拖住）；M2 把读本身从 623 进程扇出改成一遍扫（原型已证同字段、
≈0.19 s）。被数据否掉的：缓存/增量构图（没东西可省）、只把读挪后（编辑器仍等 3.4 s）、无校验异步写（违反用户
②的「校验 + CAS + 审计保留」）、只加 TTL 不删强制重读（现状 15 s TTL 也照强读）。

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/agent-adapters … ✓ change/settings-choice-editors … Totals: 17 passed, 0 failed (17 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） ==
  ✓ 38-a panel-choices.sh 全绿（ ✓ 35 ✗ 0；含一致性走查与 F-A/F-D 翻转）
  SKIP（FAST 模式）38-b·panel-p21-choices —— panel-p21.sh choices 要真 tmux 场地 + 真 bundle（慢段 ~2.5 分钟）
== 结果 ==  ✓ 2205  ✗ 0
smoke 全绿

$ git status --porcelain                       # 交付前：只有本任务该有的改动
 M openspec/changes/settings-choice-editors/design.md
 M openspec/changes/settings-choice-editors/proposal.md
 M openspec/changes/settings-choice-editors/specs/panel/spec.md
 M openspec/changes/settings-choice-editors/tasks.md
?? docs/team/reports/M65-dev2/

$ git status --porcelain                       # 三个提交落地后：干净
（空）  7271869 测量包 · fb4d6fc 提案修订 · 8855bf4 报告 · 784de1e D4/D6 对齐
```

测量一键复跑（本次提交的证据就是它产的）：

```
$ M65_KEEP=1 bash docs/team/reports/M65-dev2/measure/run.sh 7
== pty segments (samples=7) ==
  view   median   3446.2 ms   samples [3446]
  open   median   3302.9 ms   samples [3284 3333 3314 3270 3303 3545 3252]
  move   median      6.2 ms   samples [7 6 5 6 6 6 5]
  pick   median   3392.7 ms   samples [3262 3342 3339 3442 3460 3393 3487]
  dry    median     88.9 ms   samples [90 90 86 87 86 89 91]
  write  median    176.1 ms   samples [175 167 165 176 182 176 187]
== the read path: current vs single-pass prototype (same fixture) ==
semantic match: 111 records identical to `team config list --json`
prototype single-pass read: 5 runs 931 ms (186 ms per read)
== run summary: PASS=3 FAIL=0 ==
```

规格完整性（本任务自己跑的，含 B4.2 的试用归档形态）：

```
$ python3 <比对 base 的 MODIFIED requirement 与 delta 的 scenario 标题>
base scenarios : 7   delta scenarios: 7   MISSING FROM DELTA: none — every base scenario survives

$ cp -r openspec /tmp/m65-trial/openspec && (cd /tmp/m65-trial && openspec archive -y settings-choice-editors)
Applying changes to openspec/specs/memory-and-deps/spec.md:  + 1 added  ~ 1 modified
Applying changes to openspec/specs/panel/spec.md:             + 1 added  ~ 1 modified
Totals: + 2, ~ 2, - 0, → 0
```

- Verdict: **pass**（propose 范围内的验收命令全绿；实现/夹具未动，apply 与 verify 留给 W/V 两批）
- 未验证 / 已知边界：整套测量是 **host 读数**，不是参考环境（性能红线归 `tests/perf.sh` 的可见 SKIP + 0/2/3/4，
  D33，不进正确性门禁）；`read-prototype.sh` 是**证据原型**，没有接线到 CLI，也没有跑过 `panel-choices.sh` 全量
  走查（W-5.3 的验收才是那个）；重做的交互本身尚无实现，故无翻转。

## Flip evidence

本任务是 propose（无实现改动），所以给的是**方法学翻转**：让「测量/比对」自己具备红侧，而不是只有绿。

读等价性红绿（`read-prototype.sh` 的比对就是 W-5.3 的判据）：

```
$ bash /tmp/m65-proto-flip.sh <tree> <fixture>
GREEN: semantic match (111 records)
RED: broken parse diverges on 38 record(s) -> the equality check has a red side
  < TEAM_AGENT_MEM_MB	6144	                # empirical memory per agent…	apply	1
  > TEAM_AGENT_MEM_MB	6144                # empirical memory per agent…		apply	1
（"恢复" = 仓库里那份原型，再次 GREEN 111 条）
```

打点器红侧（预期帧永不出现时必须失败，不许编数字）：

```
$ sed 's/TEAM_MONITOR_UI/TEAM_ZZZ_ABSENT/g' measure.py > /tmp/absent.py && python3 /tmp/absent.py …
✗ the enum row never came into focus
--- last screen ---（打印现场屏）
harness rc=2
```

重做契约本身的翻转（选中即写的 argv 序列、交互路径无读子进程、危险值仍一次确认、「其他」仍两步）已写进
design §5.6 与 tasks 5.6（W-A/W-B/W-C），由 apply 的交付报告给出红绿。

## 隔离证据（夹具不碰真账本）

- `run.sh` 开头清空全部继承的 `TEAM_*` 且 `unset TMUX TMUX_PANE`；夹具是 `$TMPDIR/m65-measure.*` 里的新
  git 仓库（本次两次全量跑的留样：`/tmp/m65-measure.1HHlFT`、`/tmp/m65-measure.BA3UX9`；`M65_KEEP=1` 才保留，
  不带该旋钮时跑完即删）。
- 面板跑在 **raw pty** 上，全程**没有创建或触碰任何 tmux server**（默认 server 与团队 session 零接触）。
- 真仓库证据：`git status --porcelain` 只有本任务该有的 4 个修改 + 1 个新目录；`.pi/team/state/**`、
  `docs/team/inbox/**` 无新增（本任务没有调过 `notify`/`say`/`board` 等写账本命令）。

## Decisions and deviations

- **delta 只动 `panel`**：按任务书；`memory-and-deps` 未改。M2（读路径去扇出）只改**实现手段**、不改任何机器可读
  契约（`--json` 字段、人读表、退出码全同），所以不需要第二个 delta；design D11 与 proposal Boundaries 已写明。
- **响应性写成行为契约**：不是「3 秒内」这类墙钟红线，而是「按键与它产生的帧之间不得有读子进程」「回执帧不被
  settle 重读拖住」——夹具用 wrapper argv 日志证明，墙钟归 `tests/perf.sh`（W-5.5）。
- **多测了一段 `pick`**：任务书要求三段（open/move/write），但用户原话的「确认也有延迟」实际发生在「选中 →
  编辑器」这一段（选择器 accept 里又强读一次）；不测它就会把根因记错，故加测并在设计里明说。
- **没做实现**（含原型不接线）：任务书明令 propose 只测量 + 改提案；原型在报告的 measure/ 下作为证据。

## Suggested next steps

- PM 评审本修订包（重点：design §5.5 的两条修法与 §5.6 的翻转表、delta 的「无第二确认帧 + 交互路径不读盘」是
  否与用户 ②③④ 逐字对齐）。
- 评审通过后按 tasks 第 5/6 批派单：**W（apply）需要显式授权 `scripts/panel/**` 与 `scripts/lib/cmd-config.sh`**
  （后者 PM-owned），夹具项落 `tests/panel-p21.sh`/`tests/perf.sh`；**V（verify）必须换一个 agent**（D31），
  且 M60 的记录不覆盖重做后的交互。
- 复验可直接用本报告的一键命令 `M65_KEEP=1 bash docs/team/reports/M65-dev2/measure/run.sh 7` 复现全部数字。
