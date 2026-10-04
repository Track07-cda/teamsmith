# P87 · gate-isolation-scan-scope 返工 — F1（bg 改确切路径）+ F2（marker 累计口径）

agent: dev3   status: done   time: 2026-09-22T23:45Z
branch: `task/P87-bg`   PR/MR: -（local 模式：分支留本地，不 push）

```
commits: 4871ccb2 fix(P87): the rotation marker is not a call line, and an unreadable count restarts
         9754653c fix(P87): the scan excludes background-job logs by exact path, not by directory name
         025e8c03 docs(P87): the specs state both exact-path exclusions and the unreadable-marker rule
         c09ad889 fix(P87): a marker count is readable only when it parses back unchanged
base:    67e5bb74（P87 任务书；代码基线 c3b8caf2，= P83 的 verify tip）
change:  gate-isolation-scan-scope（返工：reviews/P83.md 的 F1 必修 + F2 顺手；deltas: verification, boundary）
```

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/smoke.sh` | **F1**：`real_ledger_hits()` 的 bg 排除从 `--exclude-dir=bg`（basename glob）改为按 `<root>/.pi/team/state/bg/` 前缀的**确切路径**过滤（与审计日志的同一条 awk 过滤），注释写明两条流量记录排除都是确切路径；§12b-j 两条 bg 诱饵腿（inbox/bg、state/nested/bg 必须点名）+ 仍静默的 `state/bg/gate.log`；M16 双对照加 inbox/bg 腿。**F2**：§31c ⑤ 加两条夹具——读不出 N 的 marker（`dropped=abc`，2101 条调用行 → `dropped=1101`）与「marker + 恰 2000 条调用行不轮转」 |
| `skills/teamsmith/scripts/shim/tmux` | **F2**：marker 无论可读与否都**不是调用行**（不计入 2000 上限、下一轮被新 marker 顶替）；读不出 N 时累计从 0 起点按可读部分重算（不编造数）；可读 = 能**原样解析回来**的十进制（`10#` 防前导 0 触发八进制算术中止；超出整数范围的字面量按「读不出」处理，不把 bash 静默回绕后的假数写回日志） |
| `openspec/changes/gate-isolation-scan-scope/specs/verification/spec.md` | 需求句补「同名的 bg 目录仍是账本」+ 新 scenario「The background-job exclusion is exact too」（inbox/bg、nested/bg 点名，只有 `state/bg/**` 静默） |
| `openspec/changes/gate-isolation-scan-scope/specs/boundary/spec.md` | N 的定义改为「从最后一个**可读** marker 起累计」；marker 不是调用行（不计上限、不留存）；读不出 N（空/非数字/超范围）→ 计数从 0 重启；新 scenario「An unreadable marker restarts the count」「An oversized count is not readable」「The marker does not count toward the bound」 |
| `openspec/changes/gate-isolation-scan-scope/tasks.md` | 追加 §5「Rework — P83's F1/F2」（5.1–5.3 已落地，5.4 独立复验留给下一位验证者） |
| `skills/teamsmith/references/troubleshooting.md` | §18 写明两条确切路径排除与 marker/重启契约 |
| `docs/team/reports/P87-dev3/pkg/` | 独立证据包：`lib.sh` + `run.sh` + `10-scan.sh`（八条腿 + 尾斜杠 + 带空格根 + 源码形状）+ `11-scan-mutant.sh`（bg 放宽成 basename 的反向腿）+ `20-rotation.sh`（A 读不出/ B 累计/ C 边界/ D 假 marker 形状/ E 前导 0/ F 超大字面量）；`pre/`（开工前快照，sha256 冻结） |
| `docs/team/reports/P87-dev3/logs/` | 全部原始输出（红/绿/反向腿/门禁） |

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/trust-prompt-and-fixtures
✓ spec/verification
✓ change/wake-delivery-idempotence
✓ spec/watchdog
Totals: 30 passed, 0 failed (30 items)          # rc=0（P77 时 27，本次新增 3 个 scenario）

$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：红 0 条；另有 36 条落在**历史豁免**的 16 个文件里（M28 之前的证据包，按 sha256 冻结）   # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2597  ✗ 0
FAST 模式：跳过 33 个真进程段落
smoke 全绿                                     # rc=0（574.6s）

$ bash skills/teamsmith/tests/smoke.sh </dev/null     # 全量（日志 logs/green-full-smoke.log）
<见下方「全量门禁」节>

$ bash docs/team/reports/P87-dev3/pkg/run.sh
P87 证据包：PASS                               # rc=0（10-scan 17 ok，11 反向腿 8 ok，20-rotation 22 ok）
```

新增断言在 FAST 里逐条为 ✓（原始日志 `logs/green-fast-smoke.log`）：

```
✓ 12b-j 负对照：inbox/bg/ 里的痕迹必须被点名（bg 排除是确切路径，不是目录名）
✓ 12b-j 负对照：inbox/bg/ 腿之后恰三条命中
✓ 12b-j 负对照：state 下嵌套的 bg/ 里的痕迹也必须被点名
✓ 12b-j 负对照：state/bg/ 自家的作业日志仍静默（bg 的排除是确切路径）
✓ 12b-j 负对照：六条真泄漏腿逐条点名（审计日志与 state/bg/ 仍不在清单里）
✓ M16 隔离对照：inbox/bg/ 里的痕迹必须被抓到（bg 排除是确切路径，不是目录名）
✓ M16 隔离对照：两条真痕迹腿恰两条命中（state/bg/ 与审计日志仍不在清单里）
✓ ⑤ 读不出 N 的 marker：1 标记 + 1000 行
✓ ⑤ 读不出 N 的 marker：累计从 0 重启（2101 条调用行裁 1101，不编造数）
✓ ⑤ 读不出 N 的 marker：标记之后恰 1000 行
✓ ⑤ 读不出 N 的 marker：留下的最老一行是 badseed 1102
✓ ⑤ 读不出 N 的 marker：最新一行还在末尾
✓ ⑤ 恰 2000 条调用行：不轮转（marker 不计入调用行数）
✓ ⑤ 未越界：读不出的旧 marker 原样留着（不重写）
✓ ⑤ 超大 N：1 标记 + 1000 行
✓ ⑤ 超大 N：从 0 重算（2094 条调用行裁 1094，不是回绕假数）
✓ ⑤ 超大 N：留下的最老一行是 big 1095
```

### 全量门禁

```
$ bash skills/teamsmith/tests/smoke.sh </dev/null
另一套全量 smoke 正在跑（… pid=2617076 …）；本套排队，最多等 3600s
轮到本套了（排过队）
…
== 结果 ==  ✓ 3262  ✗ 0
smoke 全绿                                     # rc=0（作业 4076.0s：先排队 55min，再自己跑完）
```

全量没有跳过的段落（31b 容器段真跑了：`✓ M28 容器自检：容器内裸 tmux 开窗/杀 server 正常，宿主 server
指纹逐字节不变`；31c 真私有 server 生死/指纹翻转也真跑）。新增断言在全量日志里同样逐条 ✓（`logs/green-full-smoke.log`）。

## Flip evidence (required for defect-fix tasks)

红侧 = 开工前快照（`pkg/pre/`，sha256 `a5f265be…`（scan）/ `c4ba417d…`（shim）；用 `SMOKE_SRC`/`SHIM_SRC`
指过去跑同一套腿，不复制实现）。

### F1 · bg 的排除（红 → 绿 → 反向腿）

```
$ SMOKE_SRC="$PWD/pre/scan.pre.sh" bash pkg/10-scan.sh          # 红（logs/red-10-scan-pre.log）
bad     命中总数 = 六条账本腿（期望 [6]，实际 [4]）
bad     账本腿没被点名：docs/team/inbox/bg/leak.md
bad     账本腿没被点名：.pi/team/state/nested/bg/leak.md
bad     带尾斜杠的根：六条账本腿仍逐条点名（期望 [6]，实际 [4]）
bad     根路径带空格：命中总数 = 六条账本腿（期望 [6]，实际 [4]）
bad     更深/大写的 bg 目录与名为 bg 的普通文件：3 条都在账本侧（期望 [3]，实际 [2]）
bad     扫描源码出现 basename glob 排除（--exclude-dir=bg）
bad     扫描源码里找不到 bg 的确切路径前缀
== §10 扫描作用域 结果 == bad=8 finding=0

$ bash pkg/10-scan.sh                                            # 绿（logs/green-10-scan.log）
   命中清单：
     /tmp/tmp.v5O0bZmt7K/docs/team/inbox/bg/leak.md
     /tmp/tmp.v5O0bZmt7K/docs/team/inbox/leak.md
     /tmp/tmp.v5O0bZmt7K/.pi/team/state/nested/bg/leak.md
     /tmp/tmp.v5O0bZmt7K/.pi/team/state/nested/tmux-calls.log
     /tmp/tmp.v5O0bZmt7K/.pi/team/state/phantom.log
     /tmp/tmp.v5O0bZmt7K/.pi/team/state/tmux-calls.log.1
ok      命中总数 = 六条账本腿（6）
ok      账本腿被点名：docs/team/inbox/bg/leak.md
ok      账本腿被点名：.pi/team/state/nested/bg/leak.md
ok      流量记录静默：.pi/team/state/tmux-calls.log
ok      流量记录静默：.pi/team/state/bg/gate.log
ok      根路径带空格：命中总数 = 六条账本腿（6）
ok      更深/大写的 bg 目录与名为 bg 的普通文件：3 条都在账本侧（3）
ok      名为 bg 的普通文件被点名（只有 bg **目录树**出局）（1）
== §10 扫描作用域 结果 == bad=0 finding=0

$ bash pkg/11-scan-mutant.sh                                     # 反向腿（绿实现 + basename 放宽这一个突变）
   突变（唯一改动行）：
     5:      grep -rlE --exclude-dir=bg "$pats" "$d" 2>/dev/null || true
ok      突变后命中总数 = 四条（bg 的两条被 basename 静默）（4）
ok      basename 突变被抓住：docs/team/inbox/bg/leak.md 被静默（§10 该腿会红）
ok      basename 突变被抓住：.pi/team/state/nested/bg/leak.md 被静默（§10 该腿会红）
== §11 bg 反向控制 结果 == bad=0 finding=0
```

反向腿的含义：把修复后的实现只改回 `--exclude-dir=bg` 一行，§10 的两条 bg 腿立刻变红（被静默）——这条
约束真的被门禁守着，不是只写在注释里。

### F2 · marker 累计口径（红 → 绿）

```
$ SHIM_SRC="$PWD/pre/shim.pre" bash pkg/20-rotation.sh            # 红（logs/red-20-rotation-pre.log）
bad     A 读不出 N：新标记 dropped=1101（0 起点重算，不编造读不出的数）（期望 [1101]，实际 [1102]）
bad     B 二轮：dropped 累计 = 1101 + 1100（期望 [2201]，实际 [2202]）
bad     C 恰 2000 条调用行：不轮转（marker 不计入调用行数）（期望 [2001]，实际 [1001]）
bad     C 未越界：读不出的旧 marker 原样留着（不重写）（期望 [1]，实际 [0]）
bad     E 前导 0 可读：dropped = 8 + 1094 = 1102（十进制读数）（期望 [1102]，实际 [008]）
bad     E 前导 0 可读：标记之后恰 1000 行（期望 [1000]，实际 [2094]）
bad     F 超大 N：dropped = 1094（不是回绕后的假数）（期望 [1094]，实际 [7766279631452243013]）
== §20 轮转累计口径 结果 == bad=7 finding=0

$ bash pkg/20-rotation.sh                                        # 绿（logs/green-20-rotation.log）
ok      A 读不出 N：新标记 dropped=1101（0 起点重算，不编造读不出的数）（1101）
ok      A 读不出的旧 marker 被顶替
ok      B 二轮：dropped 累计 = 1101 + 1100（2201）
ok      C 恰 2000 条调用行：不轮转（marker 不计入调用行数）（2001）
ok      C 未越界：读不出的旧 marker 原样留着（不重写）（1）
ok      E 前导 0 可读：dropped = 8 + 1094 = 1102（十进制读数）（1102）
ok      F 超大 N：dropped = 1094（不是回绕后的假数）（1094）
ok      F 超大 N：超大的旧 marker 被顶替（0）
== §20 轮转累计口径 结果 == bad=0 finding=0
```

F2 的旧行为（实测，不是推断）：读不出的旧 marker 被**当成一条调用行**，于是 ①新 marker 写的是 1102 而不是
1101（多算了 marker 自己）；②「marker + 恰 2000 条调用行」被误判越界，日志被裁成 1001 行、旧 marker 被重写。
E/F 腿顺带钉住两字节形态：`dropped=008` 在旧实现里让轮转那组命令因 `$((008))` 算术错误整组中止（日志静默不轮转、
还停在 2095 行）；`dropped=99999999999999999999` 在 bash 里静默回绕成 7766279631452241919，旧实现会把回绕后的
**假数**写回日志（新实现按「读不出」处理，从 0 重算写 1094）。

## Decisions and deviations

- **F1 的实现方式**：不用 GNU grep 的 `--exclude-dir`（它只匹配 basename，禁止不了嵌套 `bg`），也就不用
  「grep 排除 + 事后过滤」两套机制；两条排除统一在 grep 之后的同一个 `awk` 里按**字面前缀**比对
  （`$0 != audit && index($0, jobs) != 1`）。只用 POSIX awk 的 `index()`（本机 mawk 1.3.4 实测），根路径带空格/尾斜杠、更深/大写的 `bg` 目录与名为
 `bg` 的普通文件都已实测（pkg §10 的额外腿）。
- **超出任务书但同族的两处加固**（已在 §5 与提交信息里写明）：①可读的 marker 用 `10#` 按十进制解析——
  红侧实测：前导 0 的可读 marker（`dropped=008`）会让**轮转整组**因算术错误中止，结局是日志静默不轮转；
  ②解析做**往返校验**——超出 bash 整数范围的字面量会被静默回绕（实测 `dropped=99999999999999999999` →
  7766279631452241919），直接写回就是「与 spec 不符的假数」，因此把「可读」定义为「能原样解析回来的十进制」，
  超范围按「读不出」重启。两处都是「口径必须说清楚」的同一族问题，已写进 `boundary` delta（含 scenario）
  并在 pkg 里配 E/F 腿。
- **spec 的措辞落点**：F2 的口径写进 `boundary` delta 的需求句（「counted from the last marker whose `N` was
  readable」+「读不出 → 从 0 重启」）并配三个 scenario（restart / oversized / 不计入上限）；
  F1 写进 `verification` 需求句 + 新 scenario。门禁
  （`openspec validate --all --strict`）已复跑。
- **未动** `design.md`（P73 的提案件，P87 任务书未授权；其 D3/R4 的表述与新口径不冲突）和 `openspec/specs/**`
  （归档时才由 PM 同步）。
- 本地模式：**没有 push**，分支停在本地 worktree。

## Suggested next steps

- **独立复验（换人）**：P83 的验证者是 dev3（本人）、apply 是 dev2 —— 下一位验证者不得是这两位。复验建议：
  ① 直接用 `docs/team/reports/P87-dev3/pkg/run.sh`（含红侧 `SMOKE_SRC`/`SHIM_SRC` 覆盖与 basename 反向腿）；
  ② 在最终 tip 上跑 `openspec validate` + 全量 smoke；③ 对抗性检查我**未**覆盖的边角（pkg §10 已钉住更深/大写
  `bg`、名为 `bg` 的普通文件，不重复）：符号链接目录、根路径带 `\n`、marker 出现在第 2 行、`dropped=`、
  `dropped=+5`、marker 后跟超长 argv 的调用行、两个并发调用同时轮转。
- 全量门禁若出现与本任务无关的红（历史抖动），需要 PM 按既有 flake 流程裁定；本任务的红/绿证据不依赖全量。
