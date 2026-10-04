# P77 · gate-isolation-scan-scope apply — 审计日志按确切路径排除 + 轮转自述

agent: dev2   status: done   time: 2026-09-22T20:15Z
branch: `task/P77-apply`   PR/MR: -（local 模式：分支留本地，不 push）

```
commits: 2c32e966 fix(P77): the fixture-trace scan reads ledger state, not the gate audit log
         ea16b6d2 feat(P77): the tmux audit log self-describes its rotation
         262e9b68 fix(P77): the rotation marker is recognized by its exact field shape
base:    1087d99c（main，= 本地任务分支起点）
change:  gate-isolation-scan-scope（design 的 R1–R4 与 tasks 1.1–3.3 全部落地；4.1 归 verify 席位）
```

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | `real_ledger_hits()`：`root` 归一 + 按**确切路径**排除 `<root>/.pi/team/state/tmux-calls.log`（`--exclude-dir=bg` 照旧）；12b-j 六条腿（两条流量记录静默 + 四条账本腿逐条点名）；M16 对照加审计日志腿；31c ⑤ 轮转标记形状/未越界无标记/累计第二次轮转 |
| `skills/teamsmith/scripts/shim/tmux` | 轮转标记：首行 `<ISO 时间> · rotation · dropped=<累计调用行数>`；界照旧 2000 → 最新 1000 条调用行；marker 不带 `act=`；未越界不写 marker |
| `skills/teamsmith/references/troubleshooting.md` | 一段：审计日志是流量记录（被扫描按确切路径排除）、有界、轮转自述 |
| `openspec/changes/gate-isolation-scan-scope/tasks.md` | 勾选 1.1–1.4 / 2.1–2.3 / 3.1–3.3（4.1 verify 未勾） |
| `docs/team/reports/P77-dev2/pkg/` | 独立证据包：`run.sh` + `10-scan.sh`（六条腿，函数从 smoke.sh **抽取**）+ `20-rotation.sh` + `11-scan-mutant.sh` / `11-rotation-mutant.sh`（三个突变）+ `red/`（红侧与突变入口）+ `pre/`（main 的函数与 shim 快照，sha256 冻结） |
| `docs/team/reports/P77-dev2/logs/` | 全部原始输出（红/绿/突变/顺序观测/门禁/试归档） |

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 27 passed, 0 failed (27 items)          # rc=0

$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：红 0 条；另有 36 条落在**历史豁免**的 16 个文件里（M28 之前的证据包，按 sha256 冻结）   # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2450  ✗ 0
FAST 模式：跳过 32 个真进程段落 …
smoke 全绿                                     # rc=0（558.8s，机器 load 2.7–13）

注：FAST 在全量门禁之后又在本分支最终 tip（262e9b68）上重跑了一遍，两遍同为 ✓ 2450 ✗ 0（原始日志
`logs/green-fast-smoke.log`）。

$ TEAM_SMOKE_LOCK_WAIT=3600 bash skills/teamsmith/tests/smoke.sh </dev/null
另一套全量 smoke 正在跑（…）；本套排队，最多等 3600s
轮到本套了（排过队）
…
== 结果 ==  ✓ 3095  ✗ 0
smoke 全绿                                      # rc=0（作业 2146s：先排在 dev 的全量门禁后面，再自己跑完）
```

全量门禁本轮 **✗0**（没有 P71 类噪声红可点名），顶部没有 `SKIP（FAST 模式）` 段：**31b 容器段真的跑了**
（`M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server 指纹逐字节不变` + 容器里的真 pi 输入框
体检）。全套 13 处 `SKIP` 字样都是**夹具自报**的子计数（如 pty-wait 的 `SKIP 1`、M50-② 的 `SKIPPED`
记录），不是被跳过的段落；新增断言在全量日志里逐条为 ✓（`logs/green-full-smoke.log`）。

注：首次尝试用了外层 `flock -w 3600 … bash smoke.sh`，与 smoke **自己的**排队机制（它检测到锁被
持有就 `exec flock --close` 排队，见 `smoke.sh:102-128`）自锁死：外层持有锁、内层等同一把锁。
已终止那次作业（`FULL rc=143`，日志 `logs/full-smoke-attempt1-double-lock.log`），改用「不套外层
flock，让 smoke 自己排队」。这不是套件缺陷（协议本来就是套件自己排队），是我的调用方式错。

新增断言在 FAST 里逐条可见（原始日志 `logs/green-fast-smoke.log`）：

```
✓ 12b-j 负对照：审计日志是调用记录，不算账本痕迹（M7.2 红侧的成因）
✓ 12b-j 负对照：state/bg/ 的作业日志也不算账本痕迹（M30 口径）
✓ 12b-j 负对照：inbox 里的痕迹必须被点名
✓ 12b-j 负对照：同名兄弟 tmux-calls.log.1 必须被点名（排除是确切路径，不是 basename）
✓ 12b-j 负对照：子目录里的同名文件必须被点名
✓ 12b-j 负对照：四条真泄漏腿逐条点名（审计日志与 bg 仍不在清单里）
✓ M16 隔离对照：审计日志 tmux-calls.log 是调用记录，不算账本痕迹
✓ ⑤ 未越界：日志里没有轮转标记
✓ ⑤ 轮转：1 标记 + 1000 行
✓ ⑤ 首行是轮转标记（ISO 时间 · rotation · dropped=1101）
✓ ⑤ 标记不是调用行（不带 act=）
✓ ⑤ 第二次轮转：dropped 累计（1101+1100=2201）
```

独立证据包（不共用 smoke 的夹具，包内自己造六条腿；`pkg/run.sh` rc=0）：

```
$ bash docs/team/reports/P77-dev2/pkg/run.sh
──────── 10-scan.sh
   命中清单（…/skills/teamsmith/tests/smoke.sh）：
     /tmp/tmp.XXX/docs/team/inbox/leak.md
     /tmp/tmp.XXX/.pi/team/state/nested/tmux-calls.log
     /tmp/tmp.XXX/.pi/team/state/phantom.log
     /tmp/tmp.XXX/.pi/team/state/tmux-calls.log.1
ok      流量记录静默：.pi/team/state/tmux-calls.log
ok      流量记录静默：.pi/team/state/bg/gate.log
ok      扫描源码没有 basename glob 排除
ok      扫描源码按确切路径排除审计日志
== §10 扫描作用域 结果 == bad=0 finding=0
──────── 20-rotation.sh
ok      B 首行 = 「ISO 时间 · rotation · dropped=1101」
ok      B 标记不带 act=（不是调用行）
ok      B 最老的保留行 = seed 1102（丢了 1101 条）
ok      C 二轮 dropped 累计 = 1101+1100（2201）
== §20 审计日志轮转 结果 == bad=0 finding=0
P77 证据包：PASS                                # rc=0
```

## Flip evidence (required for defect-fix tasks)

**R1/R2 扫描：红 → 绿**（红侧 = main 的 `real_ledger_hits`，`pkg/pre/real_ledger_hits.pre.sh`，从 HEAD 抽取；
绿侧 = 本分支同一函数从 smoke.sh 抽取；两轮都在同一个六条腿 scratch 根上跑）：

```
$ bash docs/team/reports/P77-dev2/pkg/red/scan-pre.sh
   命中清单：                                   # pre（红）
     /tmp/tmp.XXX/docs/team/inbox/leak.md
     /tmp/tmp.XXX/.pi/team/state/nested/tmux-calls.log
     /tmp/tmp.XXX/.pi/team/state/phantom.log
     /tmp/tmp.XXX/.pi/team/state/tmux-calls.log   ← 审计日志被当成泄漏（P67 自毒红的根因）
     /tmp/tmp.XXX/.pi/team/state/tmux-calls.log.1
bad     命中总数 = 四条账本腿（期望 [4]，实际 [5]）
bad     流量记录被误判成泄漏：.pi/team/state/tmux-calls.log
bad     扫描源码里找不到确切路径排除
== §10 扫描作用域 结果 == bad=3 finding=0            # rc=1（红侧应有的样子）

$ bash docs/team/reports/P77-dev2/pkg/10-scan.sh     # 绿（上面 run.sh 节选）
== §10 扫描作用域 结果 == bad=0 finding=0            # 审计日志与 bg 静默；.log.1/nested/inbox/phantom 逐条点名
```

**R3 轮转：红 → 绿**（红侧 = main 的 shim，`pkg/pre/shim`，sha256 `cf090881…`；绿侧 = 本分支 shim）：

```
$ bash docs/team/reports/P77-dev2/pkg/red/rotation-pre.sh
ok      A 未越界：没有轮转标记（0）
bad     B 首轮：1 标记 + 1000 调用行（期望 [1001]，实际 [1000]）
bad     B 首行形状不对（实际：seed 1102）          ← 轮转无声：读日志的人分不清「没发生」与「被裁掉」
bad     B 标记恰一条（期望 [1]，实际 [0]）
bad     B 最老的保留行 = seed 1102（丢了 1101 条）（期望 [seed 1102]，实际 [seed 1103]）
== §20 审计日志轮转 结果 == bad=9 finding=0          # rc=1（红侧应有的样子）

$ bash docs/team/reports/P77-dev2/pkg/20-rotation.sh
ok      B 首行 = 「ISO 时间 · rotation · dropped=1101」
ok      C 二轮 dropped 累计 = 1101+1100（2201）
== §20 审计日志轮转 结果 == bad=0 finding=0          # rc=0
```

**R4 破坏实现 → 守卫必须红 → 还原**（对绿侧函数就地生成 mutant，两个方向都验证腿会红；
`pkg/11-scan-mutant.sh` 在 mutant 与原件逐字节相同/签名不出现时报 bad）：

```
$ bash docs/team/reports/P77-dev2/pkg/red/mutant-drop.sh     # 摘掉确切路径排除 → 审计日志腿必须红
     /tmp/tmp.XXX/.pi/team/state/tmux-calls.log     ← 又被点名了
ok      摘除突变被抓住：审计日志腿变红（被点名）
== §11 反向控制（drop） 结果 == bad=0

$ bash docs/team/reports/P77-dev2/pkg/red/mutant-basename.sh # 放宽成 --exclude=tmux-calls.log* → .log.1/nested 腿必须红
     命中清单里只剩 inbox/leak.md 与 phantom.log
ok      basename 突变被抓住：.log.1 腿变红（被静默）
ok      basename 突变被抓住：nested 腿变红（被静默）
== §11 反向控制（basename） 结果 == bad=0
```

**R4b marker 形状：带 `*` 的 glob 无法强制相邻（反向控制）**——`pkg/11-rotation-mutant.sh` 把字段切分
换成 `T*' · rotation · dropped='*` 的 glob 后，同一发「argv 里带这句话、且以数字结尾」的调用行被误读成
marker（把它的 4321 当累计起点）：

```
$ bash docs/team/reports/P77-dev2/pkg/red/mutant-marker-glob.sh
ok      glob 突变被 D 腿抓住：假 marker 被误读成 dropped=5422（正解 1102）
== §11b marker 形状反向控制 结果 == bad=0
```

**顺序真值观测**（`P77_SEQ=1`，真的一发一发走 1100 次；不是断言，是给复审的算术证据）：

```
note    E 顺序 1100 发：dropped=2102，在场调用行 1099（逐发检查在 2001 条处先轮转 → 2102）
```

## Gate & trial archive (tasks 3.1/3.3)

```
$ rm -rf /tmp/trial-p73b && mkdir -p /tmp/trial-p73b && cp -r openspec /tmp/trial-p73b/ \
  && cd /tmp/trial-p73b && PATH="$HOME/.bun/bin:$PATH" openspec archive -y gate-isolation-scan-scope
Specs to update:
  boundary: update
  verification: update
Applying changes to openspec/specs/boundary/spec.md:
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 1, ~ 1, - 0, → 0
Specs updated successfully.
Change 'gate-isolation-scan-scope' archived as '2026-09-22-gate-isolation-scan-scope'.   # rc=0

$ cd /tmp/trial-p73b && PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 26 passed, 0 failed (26 items)          # rc=0（归档后合并结果自身合法；MODIFIED 一条 scenario 没丢）
```

## Decisions and deviations

1. **任务书 `grant:` 行写的是 `scripts/lib/common.sh（审计写入路径）`，但审计日志真正的写入路径是
   `scripts/shim/tmux`**（`common.sh:2136` 只在渲染窗口启动命令时导出 `TEAM_TMUX_CALLS_LOG`，从不写日志）。
   design 的 Boundaries、proposal 的 Impact 与 tasks.md 的 path-grant 都写明「brief 明授 shim 的轮转块」，
   且硬要求 2/3/5（首行 marker、有界保留、红/绿两侧）离开它无法成立 —— 所以只改了 shim 的**轮转块**
   （logging 段），common.sh 未动。请 PM 在记录里确认/更正 brief 头。
2. **轮转累计的 delta 数字**：规范句是「N = 累计不再在文件里的调用行数」，实现逐字满足。scenario 里的
   `dropped=2201` 对应**批形**（轮转时在场 2100 条调用行、裁掉 1100）；严格顺序 1100 发会在第 2001 条处
   先轮转 → `2102`（上面 D 的实测），这不是实现偏差而是该 scenario 的算术形状。smoke 31c ⑤ 按其批形钉住
   累计解析（续 1099 条调用行 + 一发真调用 = 再走 1100 条）；若 PM 想改 scenario 措辞请另开小改动。
3. **`root="${2%/}"` 归一**：排除按确切路径比对，带尾斜杠的根会让路径多一个 `/` 而漏排除；函数先归一
   （证据包的 §10 有带尾斜杠的腿）。
4. **排除是输出侧过滤**（`grep -vxF -- "<root>/.pi/team/state/tmux-calls.log"`）：`grep --exclude` 只认
   basename，用它会把 `tmux-calls.log.1` 与 `nested/tmux-calls.log` 一起静默 —— 正是 design D1/D4 否掉的
   形状。函数在 `set -uo pipefail` 下以 `… | sort -u || true` 收尾，保持“无命中 = 0 行 + rc 0”。
5. **marker 识别按字段切分，不用 glob**：`T*' · rotation · dropped='*` 这类 glob 的 `*` 会跨过
   `act=…` 字段，把「argv 里带同样词、以数字结尾」的**调用行**读成 marker（实测 5422 而非 1102，见
   R4b）。现在先切出第一个 ` · ` 之前的时间戳，再要求剩余部分**以** ` · rotation · dropped=` 开头；
   读不出数字时按「marker 缺失」回退（只算本次轮转，design 允许）。
6. **1.4 的措辞清扫**：26-l 与 M98 的隔离注释本来就是口径无关的（「夹具的痕迹不得出现在真实账本里」），
   没有描述「整个 state 目录」的旧话术，未改；`real_ledger_hits` 自己的注释已写明账本状态/流量记录之分。
7. **`openspec/changes/gate-isolation-scan-scope/tasks.md`** 按 apply 流程勾选 1.1–3.3；4.1（独立复验）保持未勾。

## Known risks / not verified

- 全量 smoke 已实跑：**✓ 3095 ✗ 0**（无 P71 类噪声红）；31b 容器段真的跑了并通过，无因缺 podman 的 SKIP。
- 顺序 1100 发的观测是一次性的（约 16s），没有进 smoke（门禁不做慢观测）；smoke 只钉批形累计。
- 未做：把主仓库真实的 `state/tmux-calls.log`（1780 行、未轮转）拿来跑一次真轮转——会翻动生产日志，
  超出必要；界与 marker 都在 scratch 日志上做了 2101/2102 条的实测。

## Suggested next steps

- verify 席位按 change 的 4.1 跑：六条腿、两个轮转夹具、两个突变、负对照、`openspec validate` + 全量 smoke。
- PM 顺手定一下 brief 的 `grant:` 行（第 1 条偏差）；
- 若接受第 2 条对 scenario 措辞的建议，可在 archive 前把 `boundary` delta 的 2201 一句写成批形描述。
