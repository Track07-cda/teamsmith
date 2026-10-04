# P122 · `tmp-hygiene --sweep` 的三个可用性/正确性缺陷（apply）

- **agent**: dev-bob
- **status**: delivered
- **phase**: apply
- **change**: `-`（`anchor: none (infra)` —— 只动候选判定/输出/可见性，不动根清扫的占用/工作树/记录/lint 判据）
- **branch**: `task/P122-tmp-hygiene-tmux`（local 模式：分支留在本地 `.worktrees/dev-bob`，不 push；PM 复验后本地合并）
- **base**: `7e2f372b`（P122 brief；交付时 `main` = `2a7b03c2`，其中 `tmp-hygiene.sh`/`smoke.sh` 与 base 逐字节相同）
- **交付提交**: `1ac4443e` `93522c23` `24f0d579` `5c5fbd0e` `37a4cf43`（+ 报告提交）
- **报告包**: `docs/team/reports/P122-dev-bob/`（`logs/` 原始输出逐份落盘；`pkg/` 两条可复跑夹具）

## 0. 结论

| brief 条目 | 结果 |
|---|---|
| 1. 「是不是我们的」要有证（`review-*` 不能只靠名字）+ 台账记录仓库身份 | ✅ 归属证明链（git 痕迹 → 本项目记录 → 结构痕迹；指向别的仓库 = 反证）+ run 台账头 `repo=` 归因；归属未证/别家的目录**不进清单、绝不碰、逐条点名**（现场 4 个 <peer-b> 检出从根清单消失，见 §1.1） |
| 2. 拒绝不阻塞：跳过并点名、其余照常回收；退出码 0/3 写清 | ✅ 逐条 `[refuse]/[foreign]/[unproven]` + 原因，其余照常删；**0 = 做了事（有跳过也照常）· 3 = 一个都没做**（双向夹具 + 翻转，见 §1.2、§2.2） |
| 3. 可见性（D57 缺口 A）：`--status` 增 tmux 残留计数；清扫默认不动 + 显式开关；绝不动 `default` | ✅ 两行计数（孤儿私有 server / 陈旧 socket）；`--tmux-sockets` 才清；`default` 永不触碰；TERM（非 KILL）且只对逐字段证明的 pid（§2.3） |
| 4. 证据：两个方向 + 红侧 + FAST 全绿 + `openspec validate` | ✅ 方向 a/b/c 双方向（§1）；12 个 break 全红在各自守卫上（§3）；FAST **✓3063 ✗0**（返工轮）；`openspec validate --all --strict` **13/13** |

**判定：交付完成（含 PM 返工轮）。** 三个缺陷都有「红前 → 绿后」的可复跑证据（不是只有实现者自测：矩阵/自检的红侧由
`--break=<stage>` 恢复旧行为驱动，两个方向用 `main` 上的旧版脚本对照跑）。返工轮（PM FAIL F1/F2）的根因与
四处真改动见 §0.5。

## 0.5 返工轮（PM FAIL）：F1「别家 review-* 被标可回收」/ F2「拒绝仍阻塞全部」的根因

**PM 的原始观测在旧副本上完全可复现**（`logs/pm-field-fail-repro-main.txt`，同一台机器、只读 dry-run）：

```
$ cd <主工作树>            # P122 未合并（local 模式）的 tmp-hygiene.sh
$ bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run --age 30
  [refuse] /tmp/review-M7.35
  [reclaim] /tmp/review-M8.1     ← F1 的形状（.git 指向 <peer-b>，只因 reviews/ 有同名记录）
  [reclaim] /tmp/review-M8.2
将回收：11 个根 · 1.7 GB · 文件合计 62508
拒绝：有 2 个候选的安全前提不成立 —— 一个都没删   ← F2 的形状（计划 N 个，实删 0）
rc=3
```

`logs/field-status-before.txt`：同一副本的 `--status` 把 4 个 <peer-b> 检出列进根清单（合计 17 个根）。
**这正是 P122 要修的两个缺陷本身** —— 旧副本（主工作树）上没有本分支的改动。

**分支 tip 上的同一条命令**（`logs/field-status-after.txt` / `logs/field-sweep-dryrun.txt`）：4 个别家目录只在
「归属未证/别家」段逐条点名（`[foreign] … —— 目录的 git 指向别的仓库（/home/…/<peer-b>/.git）`），
不在候选；计划 9 个可回收根、跳过 4 个、**rc=0**。

**尽管如此，返工轮做了四处真改动**（PM 的验收词比 brief 更严，逐条对表）：

| # | PM 要求 | 落地 |
|---|---|---|
| F1 | 归属读 git 痕迹；指向别仓库或不明确 → 拒并点名 | 归属链顺序不变（git 痕迹否决记录）；**别家/不明从“只报计数”改成逐条点名**（status 与 sweep 两处，`[foreign]/[unproven] + 路径 + 理由`）；都计入“跳过” |
| F2 | 拒绝逐条跳过、其余照常回收（做事了→0 / 都没做→3） | 语义重写：`跳过 N 个（别家 / 归属不明 / 安全前提不成立，逐条见上）`；`will_do = reclaim + worktree`（注册 worktree 只打印 git 命令也算“按规则处理”）；`skipped>0 且 will_do==0` → **3**，否则 **0** |
| 双向证据 | 真 ID + 别仓库被拒；1 拒绝 + ≥2 合格 → 合格的真被删 | 自检 ⑪（`review-M8.2` 别家 + 本项目同名已提交记录 → 不在根清单、逐条点名；`review-U6.6` 痕迹不明 → `[unproven]`；`review-T5.5` 记录缺失 → `[refuse]`；两个 `teamsmith-good.H*` **都真删**、rc=0）+ ⑪b（全被挡下 → rc=3、一个没删）+ smoke 40 段同形断言 |
| 回归 | 红侧：关掉归属证明 → 影子确实会被删 | `--break=reviewproof`（矩阵）与 smoke 红侧；`--break=blockskip` 红在全停，`--break=tmuxtouch` 红在开关 |

**另外两处工程性修复（自我审查发现，不在 PM 清单里）**：

1. **归属判定函数会读到外层变量**：`local b="${d##*/}" id="${b#review-}"` —— bash 对同一条 `local` 先展开
   全部 RHS 再赋值，`${b#review-}` 读到的是**调用方的 `b`**（三个调用点恰好都设了同名 `b`，所以一直“能跑”；
   换一个没有 `b` 的调用点会在 `set -u` 下炸，或把 `id` 置空 → `_record_exists ""` 的空模式匹配**任何**看板行）。
   已拆成两句赋值，并给 `_record_exists` 加空 ID 守卫。
2. **身份自证 + 输出降噪**：两个命令头打印 `工具：<绝对路径> · rev <hash>`（跑错副本一眼可辨，这次的 FAIL 正是这个形状）；
   `/proc/<pid>/comm` 读取的竞争噪声用「`2>/dev/null` 在 `<file` 之前」消掉。

**没有做的**：没有在真实 `/tmp` 上跑过一次真实的 `--sweep`（PM 明令“修好前不要跑”，本轮只跑 `--dry-run` 与私有夹具）。

## 1. 复现：三个缺陷（红前）与修复后（绿后）

### 1.1 缺陷 1：别的项目的 `review-*` 被当成我们的（旧版会真删）

现场（只读）：`logs/field-status-before.txt`（`main` 上的旧版脚本，`--status`）——

```
  /tmp/review-M7.35
  /tmp/review-M7.36
  /tmp/review-M8.2
合计：10 个根（可回收 9 · 占用 1）
```

修复后（本分支，`logs/field-status-after.txt`）：

```
  归属基准仓库：<home>/Documents/syncthing/Work/Projects/pm-skills
  ! 另有 3 个家族目录**归属未证**（别的项目 / 无证据；不进候选、永不碰）：review-* 需本仓库 git 痕迹或记录，teamsmith-* 的台账 repo= 必须指向本仓库
合计：6 个根（可回收 5 · 占用 1）
```

三个 `/tmp/review-*` 一个都不在候选里；`--sweep --dry-run --age 30`（`logs/field-sweep-dryrun.txt`，
此时现场已有第 4 个别的项目的 review 目录）的计划里 `review-*` 出现 0 次：

```
  归属未证（不进候选、不碰）：4 个家族目录（review-* 需本仓库 git 痕迹/记录；teamsmith-* 的台账 repo= 必须指向本仓库）
```

夹具双方向（`logs/directions.txt` 方向 a，现场形状 `/tmp/review-M8.2`：`.git` 指向别仓库 + 本仓库恰有同名已提交记录）：

```
  old rc=0  清单里=在 影子=删了 → 红（把别家检出当自己的，真删）
  new rc=0  清单里=不 影子=在  → 绿（不进清单、绝不碰）
```

### 1.2 缺陷 2：一处拒绝 → 一个都不删；且拒绝不点名

方向 b（一个记录缺失的自家检出 + **两个**干净的可回收根）：

```
  old rc=3  干净根=在/在      记录点名=是 检出=在  → 红（rc=3：干净根也被拒绝项阻塞）
  new rc=0  干净根=删了/删了  记录点名=是 检出=在  → 绿（rc=0：跳过不可回收项、两个干净根都真删）
```

修复后的跳过行逐条点名（`[refuse] <检出路径>` + 原因 `记录不可回收（missing|uncommitted|dirty）：<主仓库>/docs/team/reviews/<ID>.md 不存在 / 不在 HEAD 里（未提交）/ 有未提交改动`），
结尾 `跳过 N 个（别家 / 归属不明 / 安全前提不成立，逐条见上）—— 其余照常处理`。

### 1.3 缺陷 3（D57 缺口 A）：tmux 侧残留不可见、开关是空话

```
  old tmux 行=没有 陈旧计数=-  陈旧=在  default=在  → 红（看不见、开关是空话）
  new tmux 行=有 陈旧计数=1  陈旧=删了 default=在  → 绿（计数可见、开关只删非 default）
```

现场（`logs/field-sweep-dryrun.txt`，只读 dry-run）：

```
  [tmux-stale]  /tmp/tmux-1000/p123man4-3740781
  ...
dry-run：没有删除任何东西（将回收 9 个根 · tmux 残留 4 条 · 跳过 4 个）
```

## 2. 修法

### 2.1 归属证明链（顺序 = 证据强度；`_review_verdict_of` / `_root_ledger_repo_verdict`）

1. **目录自己的 git 痕迹**（最强）：`git -C <dir> rev-parse --git-common-dir`，失败则读 `.git` 里的
   `gitdir:`（绝对/相对都归一化），与本仓库的 git 公共目录比对——**指向别的仓库是反证**：即使本项目
   有同名记录也拒（现场 `/tmp/review-M8.2` 正是这个形状）。
2. **本项目记录**：`docs/team/reviews/<ID>.md` 或 `docs/team/BOARD.md` / `ROADMAP.md` 里出现该 ID。
3. **本仓库结构痕迹**：目录里有 `skills/teamsmith/` 或 `.pi/team/config.sh`。

**归属未证 / 别家的目录不是候选**：**逐条点名**（路径 + 理由）——`--status` 列在「归属未证/别家」段
（`[foreign]/[unproven] <路径> —— <理由>`），`--sweep` 列在「不碰的家族目录」段；两者都不删。
`teamsmith-*` 若带 owner 标记，用 run 台账头的 `repo=` 归因；台账缺 `repo=` / 同类台账已不在 → `unknown`
（**照旧当候选**，与旧行为一致——不因为台账换代而漏收）。

**台账记录仓库身份**：`tests/lib/tmp-root.sh` 的 `_tmp_root_ledger_append` 在头行写
`repo=<主仓库绝对路径>`（`git rev-parse --git-common-dir` 的父目录），并加一条自检断言。

### 2.2 跳过不阻塞 + 退出码（`cmd_sweep`）

- 安全前提不成立（`[refuse]`）/ 别家（`[foreign]`）/ 痕迹不明（`[unproven]`）→ **逐条点名**、不阻止其余候选；
- `将回收：N 个根` 后跟 `跳过 M 个（别家 / 归属不明 / 安全前提不成立，逐条见上）—— 其余照常处理`；
- 退出码：**0 = 有事做了**（`will_do = reclaim + worktree`；注册 worktree 只印 git 命令也算按规则处理）；
  **3 = 一个都没做**（有跳过且 `will_do=0`，或 `--tmux-sockets` 的判据不可用）；`--dry-run` 与实跑同口径；
- 红侧 `--break=blockskip` 恢复「有拒绝就全停」的旧行为 → 新断言必须红（矩阵里确实红）。

### 2.3 tmux 侧残留（`_tmux_orphan_servers` / `_tmux_stale_sockets`）

- `--status`：`孤儿私有 server N 个（socket 已消失）· 陈旧 socket M 个` + 判据与 socket 目录；
- 判据：**非 `default`** · `ss -xl` 无监听 · 年龄 ≥ `--age`（默认 30 分钟）；
- 孤儿 server 逐字段证明：`/proc/<pid>/comm == "tmux: server"`、`argv[0]` 的 basename == `tmux`、
  命令行有 `-L`/`-S` 且名字非 `default`、socket 不存在、进程年龄达标、**排除自身与全部祖先 pid**
  （D57：不用整条命令行当身份判据）；
- `--sweep` **默认只报不动**；`--tmux-sockets` 才清（`TERM`，不是 `KILL`）；**`default` 的 socket 与
  default 命名的 server 永不触碰**；没有 `ss` 时陈旧 socket 显示 `?` 且不判（绝不把“查不了”当“没监听”），
  此时 `--tmux-sockets` 判据不可用 → 不做事并点名。

### 2.4 没动的

根清扫的占用证明、已注册 worktree、`review-` 记录状态、lint 的 13 个模板与 `mktemp -d` 口径全部原样；
`tmp-hygiene.sh --status`/`--sweep` 的旧选项语义不变（只增 `--tmux-sockets`）。

## 3. 证据（全部可复跑）

| # | 命令 | 结果 | 原始输出 |
|---|---|---|---|
| 1 | `bash skills/teamsmith/tests/tmp-hygiene.sh --self-test` | **✓ 63 ✗ 0**，rc=0（63 = 61 + 返工新增 2 条） | `logs/self-test-green.log` |
| 2 | `bash docs/team/reports/P122-dev-bob/pkg/run-flips.sh` | **1 绿 + 12 个 break 全红**（各自守卫），rc=0 | `logs/flips-matrix.txt`、`logs/self-test-<stage>.log` |
| 3 | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | **✓ 3063 ✗ 0**、114 段、账本自查一致；40 段 `✓14 ✗0` | `logs/fast-smoke-r2.log` |
| 4 | `openspec validate --all --strict` | **13 passed, 0 failed** | （本节文字） |
| 5 | `bash skills/teamsmith/tests/lib/tmp-root.sh --self-test` | **✓ 15 ✗ 0**；4 个 break 全红 | `logs/tmp-root-*.log` |
| 6 | `bash docs/team/reports/P122-dev-bob/pkg/run-directions.sh` | 方向 a/b/c 各「旧红 → 新绿」 | `logs/directions.txt` |
| 7 | 现场 `--status` 新旧对照 + `--sweep --dry-run` | 分支 tip：4 个别家逐条点名、9 回收/4 跳过/rc=0；旧副本：`[reclaim] review-M8.1/M8.2` + 全停 rc=3（PM FAIL 的原形） | `logs/field-*.txt`、`logs/pm-field-fail-repro-main.txt` |

红侧（旋转矩阵）里与本任务直接相关的四条，红在**它们自己的守卫**上（原文照抄自 `logs/self-test-<stage>.log`）：

- `--break=reviewproof`（关掉归属证明）→ `✗ P122 真 ID + 别仓库的影子被列成了根（应该在“归属未证/别家”段）`、
  `✗ P122 status 逐条点名别家（[foreign] + 路径）`、`✗ P122 不安全候选被动了`、`✗ P122 sweep 逐条点名别家`
  （共 6 条红）；
- `--break=blockskip`（回到「有拒绝就全停」）→ `✗ P122 1 拒绝 + 2 合格：sweep 退出 0（拒绝不再全停）`、
  `✗ P122 1 拒绝 + ≥2 合格 → 两个合格的真被删`（实际日志的文案：`✗ P122 sweep 退出 3（期望 0）`、
  `✗ P122 合格根没被回收（拒绝阻塞了其余候选）`）；
- `--break=tmuxtouch`（没开关也动 tmux 残留）→ `✗ P122 没给 --tmux-sockets 就动了 stale socket`、
  `✗ P122 没给开关就杀了孤儿 server`；
- `--break=ledgerrepo`（关掉台账归因）→ `✗ P122 台账别家的根被列成了根（应该在“归属未证/别家”段）`、
  `✗ P122 台账别家的根被删了`。

（其余 9 个 break 是原有/配套自查阶段，矩阵里同样全红；矩阵判据 `rc=0` = 绿绿 + 每个 break 都红。）

## 4. 范围与边界

- **grant 外的第二处改动**：`skills/teamsmith/tests/lib/tmp-root.sh`（+9 行实现 / +5 行断言）。
  理由：`repo=` 只能由**台账的写入方**写，而写入方就是它；brief 第 1 条明确要求「在台账里记录仓库身份」。
  改动最小：头行多一个字段 + 一条头行断言，不改 API/cleanup/信号路径。若 PM 认为该处应走独立 brief，
  报告在此点名，便于回退（`git revert 1ac4443e` 只影响这一处，tmp-hygiene 在没有 `repo=` 时按 `unknown` 走旧行为）。
- `smoke.sh`：只在 §40 内重写/append 一段（P122 块），未动 P53 的 lint/泄漏断言。
- `references/troubleshooting.md`：替换一段（tmp 卫生的口径），未动其它。
- D37/D57 纪律：只对**自己判定的 pid** 发 `TERM`；逐 argv 字段 + `comm` 判身份；排除自身与祖先；
  夹具 socket 目录是私有的（`TEAM_TMP_HYGIENE_TMUX_DIR`），自检**从不**扫真实 tmux socket 目录。
- 未做（留给 PM 复验）：真实 `/tmp` 的删除（只给 dry-run 证据，避免替用户做不可逆操作）；
  **full（非 FAST）门禁**不在本 pass 跑（brief 的验收命令是 FAST + openspec；full 由 `team review --strong` 跑）。
- **D57 缺口 A 的与 brief 的差异（请 PM 定盘）**：D57 原文的建议是「`team doctor` 增一行可见统计 +
  一个显式 opt-in 的清扫」，本 pass 按 **brief 第 3 条**把它落在 `tmp-hygiene --status/--sweep --tmux-sockets`
  （`cmd-status.sh` / doctor 不在本次 grant 内）。若 PM 要 doctor 行，需另开 brief（判据与开关可复用
  `tmp-hygiene.sh --status` 的输出）。

## 5. 提交

| 提交 | 内容 |
|---|---|
| `1ac4443e` | `feat(P122)`: run 台账头记下 `repo=<主仓库>`（`tests/lib/tmp-root.sh`） |
| `93522c23` | `fix(P122)`: 归属证明 + 拒绝不阻塞 + tmux 残留可见（`tests/tmp-hygiene.sh`） |
| `24f0d579` | `test(P122)`: smoke 40 段钉住三向（`tests/smoke.sh`） |
| `5c5fbd0e` | `docs(P122)`: troubleshooting 同步新语义 |
| `37a4cf43` | `test(P122)`: smoke 的 tmux 夹具挪到主回收断言之后（夹具自身顺序修正） |
| `43615ca9` | `fix(P122)` **返工轮**：归属判定 local 读外层变量 + 别家/不明逐条点名 + 全挡下才 3 + 工具身份自证 |
| 本次 | `docs(P122)`: 返工报告 + 证据包（pkg/logs） |

## 6. 复验建议

1. `bash docs/team/reports/P122-dev-bob/pkg/run-directions.sh`（约 30s：旧红/新绿对照：别家影子被真删 vs 保住；
   1 拒绝 + 2 合格 → 两个都真删；陈旧 socket 可见且只删非 default）；
2. `bash docs/team/reports/P122-dev-bob/pkg/run-flips.sh`（约 13 分钟：绿 + 12 个 break）；
3. `bash skills/teamsmith/tests/tmp-hygiene.sh --status`（分支 tip：`工具：…rev <hash>` 一行自证；
   别家/不明逐条点名；根清单里不该有 `review-*`）；
4. 现场对照：`main` 工作树里跑同一条 `--sweep --dry-run --age 30` → `[reclaim] /tmp/review-M8.1/M8.2` + 全停 rc=3
   （`logs/pm-field-fail-repro-main.txt`），分支 tip 里同一条命令 → 4 个别家逐条点名、9 回收/4 跳过/rc=0
   （`logs/field-sweep-dryrun.txt`）。

**待 PM 定的两件事**：① `tests/lib/tmp-root.sh` 的 `repo=` 那一处（grant 外，可单独回退）；
② D57 缺口 A 要不要在 `team doctor` 再加一行（本次按 brief 落在 `tmp-hygiene --status`，doctor 不在 grant 内）。
