# P167 · `signal-gate-pgrep` apply：`pgrep`/`pidof` 进闸门（窄规则，按**整个 argv** 判定）

agent: dev-bob   status: done（带一条必须由 PM 裁决的流程事故）   time: 2026-10-03
branch: `task/P167-apply`   PR/MR: -（local 模式：分支留在本地工作树，未 push）
change: `signal-gate-pgrep`（phase `apply`；`deltas: openspec/changes/signal-gate-pgrep/specs/boundary/spec.md`；
分叉点 `3246e0e6`，派单基线 `d491c2f1`（P159 归档后的 main tip））
容器：`localhost/teamsmith-gate:local`（`pkg/ct.sh` 来自 P164 的 runner：私有 PID namespace + 私有 `/tmp`，
宿主 tmux socket 在挂载之外）。宿主上只跑过纯文本/纯逻辑命令（`openspec validate`、`bash -n`、夹具本体、
`spec-refs.sh`）。

## 0. 事故：我在**主工作树**里改文件并提交了（必须先说，PM 需要裁决）

我犯了一个流程错误，且被 PM 的后续提交放大成 main 上的历史污染。时间线（全部有 `git log/reflog` 为证）：

| 时间 | 事件 |
|---|---|
| 02:06:27 | PM 在我的工作树建 `task/P167-apply`（从 main `d491c2f1`）并把 P167 派给我 |
| 02:11–02:15 | **我**在 `<home>/…/pm-skills`（**主工作树**，不是 `.worktrees/dev-bob`）编辑了 `scripts/shim/signal-gate`、建了两条软链、加了夹具，并在那里 `git commit` → `9cf5a775`、`c47c3158` 落在 **main** 上 |
| 02:25:41 | PM 在主工作树提交 `2e4a55c1`（"records before merging P190"），把我**未提交**的 `smoke.sh` / `references/protocol.md` / `docs/team/reports/P167-dev-bob/pkg/*` 一并扫进了 main |
| 02:26:03 | PM 在 main 上继续 P190 的合并记录（`0e4b0af1`、`d37eec47`）—— 我的提交成了它们的祖先 |
| 02:48:20 | PM 从 inbox 告知：已 `revert`（`a744bbfc`），main 回到 P167 之前，让我从 `task/P167-apply` 照常交付；规矩改成路径限定 `git add` |

**我做的止损**（都已执行，且每一步只用只读命令核对过）：

1. 把工作搬回它该在的地方：`git merge --ff-only c47c3158`（快进，不是重写）→ 我的分支现在有 `9cf5a775`、
   `c47c3158`；再用 `2e4a55c1` 里我那几个文件的补丁重建 `ceda589d`（smoke 31c）、`05a69675`（protocol.md），
   并把证据包提交为 `ef52af21`。**交付分支与 main 上同名文件的字节完全相同**（逐文件 `cmp` 过）。
2. 恢复主工作树干净：`docs/team/reports/P167-dev-bob/pkg/lib.sh`（我 02:30 的未提交改动）已拷回我的工作树，
   主工作树现在是 `git status` 干净；**此后我没有再碰主工作树的任何文件**。
3. 已用 `team notify pm` 一条说明事故与现状。

**我没有做也不会自己做的**：main 的历史改写（`git reset`/`rebase`/`revert`）。你已经自己把 main 回退到 P167 之前
（`a744bbfc`：三段 934/0、夹具 68/0、validate 15/0），交付分支完好、照常交付。**唯一需要你注意的是下面 §0b 的合并几何**：
回退之后直接 `merge`/`cherry-pick` 这条分支会**半截合并**（实现丢掉、smoke/protocol 前进），请用 §0b 的按路径配方。

## 0b. ⚠️ 合并几何：**不要直接 `merge`/`cherry-pick` 这条分支**（已实测）

你把 main 回退到 P167 之前（`a744bbfc`）后，`task/P167-apply` 与 main 的 **merge-base 变成了我的第二个提交
`c47c3158`**（它已经包含本次实现，而 main 侧把它 revert 了）。后果：

```
$ git merge --squash task/P167-apply          # 在干净的 main 上，无冲突、无报错
Automatic merge went well; stopped before committing as requested
  skills/teamsmith/scripts/shim/pgrep            **被删掉了**
  skills/teamsmith/scripts/shim/pidof            **被删掉了**
  skills/teamsmith/scripts/shim/signal-gate      存在（156 行） ← 与 revert 后的 main 逐字节相同（旧实现）
  skills/teamsmith/tests/signal-gate.sh          存在（366 行） ← 与 revert 后的 main 逐字节相同（旧夹具）
  skills/teamsmith/{tests/smoke.sh,references/protocol.md}、tasks.md 却来自我的分支
```

即：**无声的半截合并** —— 我的分支对这四条文件没有再改（改在 `c47c3158` 里，而那个提交在两边都算“共同历史”），
merge 于是取了 main 的 revert 版本；而 `smoke.sh`/`protocol.md` 却前进到了我的版本 → 31c 会要求闸门目录里有
`pgrep`/`pidof`，而那两个软链根本不存在，门禁必红。原输出见 `logs/78-merge-geometry.log`。

**可用的配方**（内容等价于交付分支，已在一次性克隆里验证：软链形态对、`git diff <分支> -- <路径>` 为空、
夹具 ✓388 ✗0）：

```bash
# 在 main 上，按路径取交付分支的内容（不要用 merge）
git checkout task/P167-apply -- \
  skills/teamsmith/scripts/shim \
  skills/teamsmith/tests/signal-gate.sh skills/teamsmith/tests/smoke.sh \
  skills/teamsmith/references/protocol.md \
  openspec/changes/signal-gate-pgrep/tasks.md \
  docs/team/reports/P167-dev-bob.md docs/team/reports/P167-dev-bob
# 然后按你的规矩提交；等价写法：git diff 3246e0e6 f75c21ae -- <路径> | git apply
```

## 1. 纪律（本轮怎么跑的）

1. **容器**：所有 smoke / 夹具 / 选段都在 `pkg/ct.sh` 的容器里跑（`--checkout` = 克隆交付 HEAD 再挂进
   `/work`）；宿主上没有起过 tmux、没有探过任何活窗口。F1 的真窗口红侧用"只盖住 `scripts/shim` 的 scratch
   目录"覆盖挂载进容器，**不碰宿主的 shim 目录**。
2. **真身永远是记录桩**：夹具 `p164_gate` 把 `TEAM_SIGNAL_REAL` 钉在 argv 记录桩上、PATH 里紧跟闸门放同名
   `pgrep`/`pidof` 记录桩；替换用例里的 `kill` 是只记 argv 的 shell 函数。整轮里没有任何一次真
   `pkill`/`killall`/`pgrep`/`pidof` 被执行（桩日志即证据）。
3. **变异只改副本**：基线/变异脚本在 `/tmp/p167-*.XXXX` 建副本树，当前树一个字节不动（`git status` 干净）。
4. **只按记录的 pid 收进程**：夹具的诱饵与"自有进程"都是自己 spawn、pid 记录在案，收尾只按这些 pid 发
   `TERM`；没有任何按名字/模式的进程选择。

## Verification evidence（实际跑过的；原始日志在 `logs/`，一键复跑是 `pkg/run-gates.sh`）

全部在容器里（`pkg/ct.sh`：私有 PID namespace + 私有 `/tmp`，宿主 tmux socket 不在挂载里），工作目录 `.worktrees/dev-bob`。

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/signal-gate.sh
…
== signal-gate 结果 == ✓ 388  ✗ 0
signal-gate 全绿
                                                               # logs/10-fixture-green.log
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash -c 'rc=0; bash skills/teamsmith/tests/signal-gate.sh --break=pass >/tmp/p164-red.log 2>&1 || rc=$?; tail -50 /tmp/p164-red.log; test "$rc" = 1 && grep -E "✗.*P164" /tmp/p164-red.log'
…
  ✗ P164 pgrep -f <marker>（模式）：文案点名工具 pgrep（[] 里没有 [pgrep]）
  ✗ P164 pgrep -f <marker>（模式）：文案带完整 argv（[] 里没有 [pgrep -f p159-signal-marker]）
  ✗ P164 pgrep -f <marker>（模式）：文案给出安全路线 team bg stop <id>（[] 里没有 [team bg stop <id>]）
                                                               # logs/20-fixture-red.log
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/smoke.sh --select 31c,58
#14 31 · tmux 接触面：隔离 lint + 容器跑法（M28） · 用时 4s · ✓9 ✗0 SKIP1 · ticks 10
#15 31c · tmux 运行时闸门：按目标判定 + argv token + 注入（M36/M67） · 用时 4s · ✓287 ✗0 SKIP0 · ticks 287
#16 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 12s · ✓13 ✗0 SKIP0 · ticks 13
== 选段结果 ==  ✓ 789  ✗ 0
                                                               # logs/30-select-31c-58.log
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/smoke.sh --select 26,58
#13 26 · 面板（pulse-tui-panel：…） · 用时 150s · ✓138 ✗10 SKIP0 · ticks 148
#14 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 用时 11s · ✓13 ✗0 SKIP0 · ticks 13
== 选段结果 ==  ✓ 567  ✗ 10                                        # 段 26 的红在基线上一模一样，见 logs/77
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh openspec validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)
                                                               # logs/40-openspec-validate.log
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout env TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
账本自查： 123 段收口 · 增量 ✓3795 ✗3 SKIP36 ｜ 结果行 ✓3795 ✗3 —— 一致
== 结果 ==  ✓ 3795  ✗ 3                                        # 加上段前那一条 section-guard ✗
                                                               # logs/50-fast-smoke.log
```

```
$ bash docs/team/reports/P164-verify/pkg/ct.sh --checkout bash skills/teamsmith/tests/smoke.sh
账本自查： 122 段收口 · 增量 ✓4532 ✗1 SKIP3 ｜ 结果行 ✓4532 ✗1 —— 一致
== 结果 ==  ✓ 4532  ✗ 1                                        # 唯一一条红是 18c retired（基线同红）
                                                               # logs/60-full-smoke.log
```

**判据（不假报）**：10、20、30、40 四条与夹具命令都是 rc=0；50、60、31(26) 是 rc=1，每一条红都在下面的
“基线/同树对照”里给出了出处（同树或基线逐行相同），不是靠“看起来不相关”排除的。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/shim/signal-gate` | 判定改成**整个 argv** 的分类器：`pkill`/`killall` 维持 P159 契约；`pgrep` 只放行 `-g N`/`-P N`（显式正整数）与三种整命令计数 `-fc P`/`-f -c P`/`-c -f P`（`P` 非空且不以 `-` 开头）；`pidof` 只放行单个信息词；其余一律 exit 64、stdout 空。放行的 `pgrep`/`pidof` **忽略旧 pin**，按自己的名字在 PATH 上解析真身 |
| `skills/teamsmith/scripts/shim/pgrep`、`.../pidof` | 指向 `signal-gate` 的软链（唯一新增入口，不放行 token、不加配置键） |
| `skills/teamsmith/tests/signal-gate.sh` | P164 段（10 种拒绝形态 / 18 种放大形态 / 6 次计数 / 4×2 信息词 / 不可用 pin + 继承 token / 替换 / 取证轮转与保留失败 / ps·fuser 对照），每条断言带 `P164` 前缀；`--break=pass` 也绕开选择器拒绝 |
| `skills/teamsmith/tests/smoke.sh` | 只动 31c：渲染的 PATH 前缀与 PM/worker 真窗口里 `command -v pgrep`/`pidof` 必须命中闸门目录，并断言 PM 窗口 env 里没有选择器授权键 |
| `skills/teamsmith/references/protocol.md` | 信号段重写：整 argv 分类、放行的规范诊断/计数、不支持的拼写、同名真身与旧 pin、`-g`/`-P` 是诊断不是授权、绝对路径/未加闸 shell/shell 函数/`ps`/`fuser` 的残留边界 |
| `openspec/changes/signal-gate-pgrep/tasks.md` | 1.1–3.2、4.1 勾选（4.2 PM-owned 未勾） |
| `docs/team/reports/P167-dev-bob/pkg/**` | 证据包：`ct.sh`（容器 runner）、`lib.sh`、`run-gates.sh`、`15-baseline-old-shim.sh`、`10-gate-mutants.sh`、`20-f1-resolution.sh`、`README.md` |
| `docs/team/reports/P167-dev-bob/logs/**` | 每次门禁/红侧的原始输出 |

## Delta → scenario map（逐条对照 `specs/boundary/spec.md` 的 `MODIFIED` 需求）

| Delta 里的话 | 实现点 | 夹具断言 |
|---|---|---|
| launch PATH 也拦 `pgrep`/`pidof` | 同日录软链 + 工具名分派 | `P164 闸门入口…`（夹具）、31c 的 6 条解析断言 + 2 条 PM 窗口解析断言 |
| 只放行 `-g N`/`-P N`、`-fc P`/`-f -c P`/`-c -f P` 与四个信息词 | 三条 `case` 分类 + `_is_positive_int` + 模式非空且不以 `-` 开头 | `P164 显式 -g/-P 诊断…`（8 条）、`P164 FAST 的整命令计数…`（14 条）、`P164 只读信息词…`（10 条） |
| 其余 `pgrep` 形态与一切选择型 `pidof` 必须 exit 64、stdout 空、点名工具/argv/安全路线 | 拒绝分支（`_act=refused`）沿用 P159 文案 + 两行工具专属补充 | `P164 按名字/模式/所有者的选择一律拒`（10 形态 × 9 条）、`P164 部分匹配/隐式 ID 不能放大选择`（18 形态 × 9 条） |
| 放行的调用保留 argv/stdout/stderr/退出码 | 逐字节 `exec "$_real" "${_shim_argv[@]}"` | 诊断段（含配置的非零退出码 3）与计数段的两种响应（`0`+exit 1 / `2`+exit 0） |
| `TEAM_SIGNAL_REAL` 钉 `pkill` 时**不得**把放行的 `pgrep` 改道 | 新工具分支不读该 pin，只按 basename 在 PATH 找非自身同名文件 | `P164 pkill 见证桩零调用`、`P164 同名桩收到 …`、`P164 日志按实际工具名记` |
| 新调用/拒绝共用记录与取证契约 | 沿用同一 `_bounded_append` / `.forensics` / 轮转 / `retention=failed` | `P164 新选择器的拒绝进同一份取证记录`（逐字节 cmp、轮转 2100、目录与 FIFO） |
| 继承环境不授权（含选择器） | 判定不读任何 `TEAM_*` 授权键 | `P164 拒绝与 pin / 继承环境无关`（direct + child × 2 形态）、31c 的"没有选择器授权键" |
| 被拒的替换不给 shell 任何 PID | 拒绝 ⇒ stdout 空 | `P164 被拒的替换不给 shell 任何 PID`（只记 argv 的 kill 零参数） |
| `kill`/`ps`/`fuser` 不拦 | 工具名分派之外不介入 | `P164 ps / fuser 不在这道闸门的管理面内`（见证桩 argv/状态 + 闸门零日志行） |
| 五个 P159 场景逐字节保留 | 演进而非重写夹具 | 绿侧 388 断言里 P159 那 69 条全绿（本 change 前后都在跑） |

## Flip evidence（破坏 → 红 → 恢复绿；原始输出在 `logs/`）

这一段是 `team review --strong` 要看的“翻转”：每一处都先**破坏**（临时副本里改一处/删一处），再要求**点名**的断言变红，
最后在未动的树上**恢复绿**。证据包（`pkg/`）是**自写**的：不改产品夹具，只读地建副本、把夹具当黑盒跑，“真身”永远是
夹具自带的记录桩；它与产品实现的唯一共享是**交付的夹具与 `signal-gate` 本体**，不是实现内部函数。

### B · 基线：旧闸门 + 新夹具（`pkg/15-baseline-old-shim.sh` → `logs/72-baseline.log`）

取派单基线 `d491c2f1` 的旧 `signal-gate` 进副本，副本夹具按基线语义改**两行**（选择器按 PATH 解析而不是
走闸门入口；停用"四条入口齐备"的硬检查），其余逐字节相同。结果 **✓14 ✗0**：

- 红的（新拒绝断言在旧实现上不成立）：`P164 pgrep -f <marker>：exit 64`、`…：stdout 为空`、`…：选择器桩零调用`、
  `P164 pidof sleep（裸名）：exit 64`、`P164 只记 argv 的 kill 两次调用都没有 PID 参数`、`P164 kill 没有记录到任何
  PID 参数`、`P164 替换里的 pgrep -f 退出 64 且 stdout 空`、`P164 十种拒绝：日志十行 refused`、
  `P164 两次放行都记 act=pass · tool=pgrep`。
- **替换用例的红正是 D5-F2 描述的基线形状**：旧树里 `pgrep -f` 直接执行同名记录桩、把 `424242` 交给只记 argv 的
  `kill`（`kill argv=[424242]`）—— 证明"闸门只管 pkill"时代的洞是真的。
- 绿的对照：`pkill -f <marker> 退出 64`、`只读形式的退出码原样来自真身（7）`、反向守卫（真实 `state/` 受看面
  前后一致）—— 旧行为与新实现在这三处一致。

### M1–M3 + F3a/F3b/F4/F5：七个变异，每个点名一条该红的断言（`pkg/10-gate-mutants.sh` → `logs/71-gate-mutants.log`）

| # | 变异（只改一处） | 点名的红断言（全部实测变红） |
|---|---|---|
| M1 | 判定行 `_act="refused"` → `"pass"`（夹具自带 `--break=pass` 走同一处） | `P164 pgrep -f <marker>（模式）：exit 64` / `…选择器桩零调用` / `P164 pidof sleep（裸名）：exit 64` |
| M2 | `_is_positive_int` 直接 `return 0` | `P164 pgrep -g 0（隐式组）` / `-P -1（负数）` / `-g 1,2（多值）` / `-P ''（空值）`：exit 64 |
| M3 | 计数放宽成"argv 里任何含 `-c` 的成员" | `P164 pgrep -fc sleep -l（计数加列表）` / `-fcl sleep（融合拼写）` / `-fc ''（空模式）`：exit 64 |
| F3a | 拒绝分支改 `if true`（恒拒绝） | `P164 pgrep -g <记录的组 id> 的退出码来自真身（3）` / `P164 同名桩收到 -g 的 argv 逐字节` |
| F3b | 新选择器也认旧 pin（`if true` 让它们走 `TEAM_SIGNAL_REAL`） | `P164 pkill 见证桩零调用（放行不走旧 pin）` / `P164 同名桩收到 10 次调用` |
| F4 | 日志条件排除 `pgrep`/`pidof`（选择器不记账） | `P164 第一行 act=refused · tool=pgrep` / `P164 十种拒绝：日志十行 refused` |
| F5 | `ps`/`fuser` 见证桩改成 `exit 64` | `P164 ps -p 12 的退出码来自自己的真身（0）` / `P164 fuser /tmp/p164-file 的退出码来自自己的真身（0）` |

每个变异都同时检查一条**对照断言仍绿**（M1 看计数、M2/M3 看 `-f` 拒绝、F3a/F3b 看 `-f` 拒绝、F4 看 `-f` 拒绝、
F5 看 `-f` 拒绝）—— 变异没有越过界。合计 **✓25 ✗0**。

### F2 · 夹具红侧（交付夹具自带，P164 的验收命令）

`bash pkg/ct.sh --checkout bash -c '… signal-gate.sh --break=pass …; test "$rc" = 1 && grep -E "✗.*P164"'`
→ rc=0（红侧成立），`grep` 打出的正是**新**断言（`logs/20-fixture-red.log` 末尾：`P164 pgrep -f <marker>（模式）：
文案点名工具 pgrep`、`…：文案带完整 argv`、`…：文案给出安全路线` 等），不是旧 pkill 的失败。

### F1 · 删掉一条选择器软链 → 解析/窗口断言必须红（`pkg/20-f1-resolution.sh`，`logs/73-f1-resolution.log`）

两部分，每个变异都同时看**另一个**选择器的同名断言是否仍绿（对照）：

- **(a) 夹具内**（×2 工具）：副本树删掉一条软链 → `PATH=<shim>:/usr/bin:/bin command -v <工具>` 落到
  `/usr/bin/<工具>`；夹具自己的“四条入口齐备”硬检查会先把夹具停掉，所以副本里**额外**停用那一行，
  好让解析断言本身变红 —— `P164 PATH 最前是闸门目录时 pgrep 解析到闸门`（或 pidof）**变红**，另一个工具
  的同一断言**仍绿**。合计 ✓6 ✗0。
- **(b) 真窗口**（×2 工具）：容器里跑 `smoke --select 31c,58`，把**只少一条软链**的 scratch shim 目录
  覆盖挂载到 `/work/skills/teamsmith/scripts/shim` → smoke rc=1，且逐条点名：
  `P167 worker 窗口里 <工具> 解析到闸门入口`、`P167 PM 窗口里 <工具> 也解析到闸门入口`、
  `P167 渲染出的 PATH 前缀里 <工具> 解析到闸门目录`；另一个工具的两条窗口断言**仍绿**，
  示例原文：`✗ P167 渲染出的 PATH 前缀里 pgrep 解析到闸门目录（期望 [/work/…/shim/pgrep]，实际 [/usr/bin/pgrep]）`、
  `✗ P167 worker 窗口里 pgrep 解析到闸门入口（…/m36/env-worker.log 中没有匹配 [^pgrep_at=/work/…/shim/pgrep$]）`。
  合计 ✓10 ✗0。
- **恢复绿**：不改树，直接跑 `logs/30-select-31c-58.log`（✓789 ✗0）。

## 门禁结果（全部在容器里；原始日志在 `logs/`，命令在 `pkg/run-gates.sh`）

| # | 命令 | 结果 |
|---|---|---|
| 10 | `ct.sh --checkout bash skills/teamsmith/tests/signal-gate.sh` | **✓ 388 ✗ 0**（P159 的 69 条 + P164 的 319 条） |
| 20 | 上表的红侧命令（`--break=pass`） | **rc=0**，P164 红断言逐条打出 |
| 30 | `ct.sh --checkout bash skills/teamsmith/tests/smoke.sh --select 31c,58` | **✓ 789 ✗ 0**（含 11 条 P167 窗口/入口断言、夹具 388 条、lint 与 `team bg stop`） |
| 31 | `ct.sh --checkout bash skills/teamsmith/tests/smoke.sh --select 26,58` | 段 58 **✓13 ✗0**；段 26 **✓138 ✗10**（全是 `26-m` 的“面板 10–20s 内没渲染/没跳动”时序断言）—— **基线树同一容器同一份红，逐行相同**（`logs/77-26-baseline-compare.log`） |
| 40 | `ct.sh openspec validate --all --strict` | **15 passed, 0 failed** |
| 50 | `ct.sh --checkout env TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | **rc=1 · ✓3795 ✗3** + 段前一条 section-guard ✗（四条都不是本 change；见下节） |
| 60 | `ct.sh --checkout bash skills/teamsmith/tests/smoke.sh` | **rc=1 · ✓4532 ✗1（122 段收口）**；唯一一条红是 18c 的 `retired` 断言，本 change 的所有断言（夹具 388 + 31c 的 11 条 P167）全绿 |

（50/60 各跑一次：FAST 1456s、全量 2164s；原始日志 `logs/50-fast-smoke.log`、`logs/60-full-smoke.log`。）

### 门禁 50/60 里那四条红（逐条判据，都不判给本 change）

| 红断言 | 判据 |
|---|---|
| `section-guard：看门狗没起来（/tmp/.teamsmith-smoke-guard.pid.1）` | 看门狗启动只等 1 秒（`tests/lib/section-guard.sh:352-368`：50×0.02s）。**同一棵树的全量跑里看门狗正常起来**（60 的段 0e/1c 全绿），并且有别人的容器先例：`docs/team/reports/P133-verify/fast-container.log:6` 同样的行（见 `logs/75-section-guard-precedent.log`）。判：容器里的一次瞬态，不是本 change |
| `P70 看门狗：活着但不在作业表里（双重 fork）`（段 0e，FAST ✗1） | 同一棵树全量跑：`✓ P70 看门狗：活着但不在作业表里（双重 fork）`，段 0e **✓23 ✗0** |
| `M11 ⑤：点名现场窗口`（段 1c，FAST ✗1） | 同一棵树全量跑：`✓ M11 ⑤：点名现场窗口`，段 1c **✓24 ✗0** |
| `18c 被 pending change 退场的引用逐条点名（retired 行）`（段 18c；FAST 与全量都红） | **基线同红，且原因可定位到 PM 的归档提交**：`spec-refs.sh --check` 在 `f7241906`（`d491c2f1` 的父提交，归档之前）打印 `retired 4`，在 `d491c2f1`（本 change 的派单基线＝归档后的 main tip）与交付树上都打印 `retired 0` —— 归档 `safe-signal-discipline` 之后，那句“必须至少有一条被 pending change 退场的引用”在新树状态上不再成立。原始对照见 `logs/74-18c-baseline.log`。判：**PM 归档引起的既有红**（PM 复验时会原样看到；要么按既有红记账，要么另派一个小任务修断言） |
| `26-m` 的 10 条面板时序红（`--select 26,58`） | **基线同红**：`d491c2f1` 的树在同一个容器、同一条命令下给出**逐行相同**的 ✗10 与相同的计数（`#13 26 … ✓138 ✗10`、`#14 58 … ✓13 ✗0`、`== 选段结果 == ✓567 ✗10`），见 `logs/76-select-26-58-baseline.log` 与对照 `logs/77-26-baseline-compare.log`。判：容器/现场（面板真 pane 渲染不出来），不是本 change |

### 交付 HEAD（`e9f53f36`）上的验收重跑

把任务书里的验收命令在提交后的交付 HEAD 上原样重跑一遍（原始输出 `logs/80-final-*.log`）：

| 命令 | 结果 |
|---|---|
| `ct.sh --checkout bash skills/teamsmith/tests/signal-gate.sh` | `== signal-gate 结果 == ✓ 388  ✗ 0` · `signal-gate 全绿` |
| 夹具红侧（`--break=pass`，见上面第 20 行） | rc=0，逐条打出 `✗ P164 …：exit 64 / stdout 为空 / 文案… / 选择器桩零调用 / 日志记 act=refused` |
| `ct.sh --checkout bash skills/teamsmith/tests/smoke.sh --select 31c,58` | `== 选段结果 ==  ✓ 789  ✗ 0` |
| `ct.sh openspec validate --all --strict` | `Totals: 15 passed, 0 failed (15 items)`（含 `✓ change/signal-gate-pgrep`） |
| `git diff --name-only 3246e0e6..HEAD`（任务书 3.2 的交付面） | 只有 `skills/teamsmith/{scripts/shim/{signal-gate,pgrep,pidof},tests/{signal-gate.sh,smoke.sh},references/protocol.md}`、`openspec/changes/signal-gate-pgrep/tasks.md` 与本报告包 |
| `bash -n skills/teamsmith/scripts/shim/signal-gate skills/teamsmith/tests/signal-gate.sh skills/teamsmith/tests/smoke.sh` | `bash -n OK（三份）` |

## Decisions and deviations（偏离 / 未测 / 残留，如实记账）

- **没做**：不改四个产品调用点（`common.sh:1507` 的 `pgrep -g`、`panel-cpu.sh` 两处 `pgrep -P`、`smoke.sh` 的
  `pgrep -fc`），不动 lint、不动配置 schema、不拦 `kill`/`ps`/`fuser`（`specs/boundary/spec.md` 明确要求）。
- **残留（写在 protocol.md 里）**：绝对路径 `/usr/bin/pgrep`、没把闸门目录放 PATH 最前的 shell、shell 函数、
  `ps`/`/proc` 等其它产 PID 列表的通道都还在闸门之外；计数可以被误用成 PID 原料；`-g`/`-P` 的返回不是
  spawner 记录过的身份，只是诊断。
- **`-g 0` 的语义变化**：`panel-cpu.sh` 的 `pgrep -P "${time_pid:-0}"` 在 `time_pid` 为空时会拿到 exit 64 与
  一行 stderr（设计 D6 已接受：那正是"隐式 pid 0 不归调用者"），面板仍以既有的启动错误 exit 3 可见失败。
- **未测**：真机（宿主）窗口里的解析行为——按 PM 纪律，本轮只在容器里验真窗口（31c 的私有 server）。
- **PM 需要裁决**：§0 的 main 历史；以及 50/60 里那四条红是否按"与本 change 无关"记账（我给的是同树基线与
  归档前基线的对照证据，见文末）。

## Suggested next steps（给 PM 的裁决点，三句话）

1. **合并 / 复验**：分支 `task/P167-apply`（tip `f75c21ae`，本地、未 push）内容是本次 apply 的全量；
   请用 **§0b 的按路径配方**（不要直接 merge），交付面只有 `skills/teamsmith/{scripts/shim,tests,references/protocol.md}` +
   `openspec/changes/signal-gate-pgrep/tasks.md` + 本报告包。独立复验请用另一个 agent（我写了该 change 的 apply）。
2. **门禁里的三组红都不是本 change**（都有同树或基线的对照）：18c `retired`（PM 归档引起，基线同红）；
   `26-m` 面板时序 ✗10（基线逐行相同）；FAST 里的 section-guard/P70/M11（同一棵树的全量跑全绿 + 容器先例）。
   复验时请用同一口径记账；要不要另开一个小任务修 18c 断言，听你的。
3. **交付边界**：我只改 `skills/teamsmith/{scripts/shim,tests,references/protocol.md}` 与
   `openspec/changes/signal-gate-pgrep/tasks.md`（勾选）+ 报告包；`.worktrees/dev-bob` 留在本地、未 push。
