# P171 · 夹具的「真实仓库 state/ 未被触碰」收窄到夹具产品自己的写入面（活着的 PM 运行时让它不可满足）

agent: dev   status: done   time: 2026-10-02T14:58:00Z
branch: `task/P171-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
commits: `34975762`（判据）· `677a0864`（翻转夹具）· `1a066605`（软链跟随）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/signal-gate.sh` | 反向守卫从「整份 `state/` 前后快照 + 逐条排除活车道」改成**白名单**：只看 `signal-calls.log*`（内容哈希）；签名断言保留并改成扫**全树**（只放过 runner 自己的作业车道 `bg/`、`bg.log`）；段尾形状探针按新极性重写（内容敏感 / 软链 / 名单与产品源码一致三条新增）；`state_snapshot` 与 `state_files_for_signature` 先跟随软链 |
| `skills/teamsmith/tests/flip-p171.sh` | 七面翻转夹具（跑动中写入 + 变异 + 正控），在夹具 + `lib` + `shim` + `common.sh` 的副本里跑，真树一个字节不动 |
| `skills/teamsmith/tests/flip-p168.sh` | **删除**（P168 的排除面判据被本任务整体取代，锚点已不存在；面映射见「决定与偏离」） |
| `docs/team/reports/P171-dev/logs/*`（8 份） | 证据日志：夹具直跑、翻转、真活账本对拍、两个 harness 的空过守卫、三次 `--select 58`、openspec |

## 要做的 1 · 白名单：逐条从代码列（不许凭猜）

| 受看路径（相对 `.pi/team/state/`） | 谁写它 | 代码位置 | 为什么算在夹具头上 |
|---|---|---|---|
| `signal-calls.log` | 闸门每次调用追加一行 | `scripts/shim/signal-gate`：`_act` 判定之后写主日志的那段（`_bounded_append "$_log"`） | 窗口启动前缀把它钉成 `$TEAM_STATE_DIR/signal-calls.log`（`scripts/lib/common.sh:2227` 的 `team_tmux_shim_exports`），而 `TEAM_STATE_DIR` 默认就是 `<repo>/.pi/team/state`（同文件 927）→ 夹具**漏钉**（某一腿没把 `TEAM_SIGNAL_CALLS_LOG` 指到自己的私有根）时那一行就落在这里 |
| `signal-calls.log.forensics` | 同一行的长保留副本（只有拒绝路径写） | 同上：`_flog="${_log}.forensics"` | 同一次调用产生的兄弟文件，同一个前缀 |

两条归一族（glob `signal-calls.log*`）：闸门轮转时还会写 `<log>.tmp.<pid>` / `<log>.forensics.tmp.<pid>` 再 `mv`，族 glob 把这些瞬态残留也圈进来。

**除这一族之外，夹具（及其产品）在真实 `state/` 里没有别的写入面**：夹具自己的产物全部落在 `tmp_root_create` 的私有根里，脚本里 10+ 处调用逐一看过，每个调用点都显式钉 `TEAM_SIGNAL_CALLS_LOG`/`TEAM_SIGNAL_REAL`。判据形态：`find -maxdepth 1 -type f -name 'signal-calls.log*'` + `sha256sum`（**内容哈希**，不是大小/时间戳 —— 同长度改写也看得见）；目录不在记 `absent`（连「凭空建出 `state/`」也算变化）。

## 要做的 2/3/4 · 保留的守卫、红侧、以及**不覆盖**的边界

**保留**：诱饵签名断言（`p159-decoy-`）仍是主证据，并从「只在白名单那份文件列表上 grep」改成**扫全树**（任意文件名），唯一放过 runner 自己的并发车道 `bg/`、`bg.log`。理由：用 `team_bg_run` 跑门禁时 runner 把**本夹具自己的 stdout** 抄进作业日志，一次失败跑的 `bad()` 文案里就带着诱饵名 —— 那是夹具的输出被抄走，不是夹具写了账本（P168 那个假红同源）。两个判据互补：白名单管「产品那一族日志」（哪怕那行不带签名），签名管「任何文件名里带着夹具记号的东西」。

**红侧（三条 + 四条对照）** 全在 `tests/flip-p171.sh`（`logs/10-flip-console.txt`，✓22 ✗0）：

- ① **受看面红**：副本里插一腿「漏钉」的闸门调用（`TEAM_SIGNAL_CALLS_LOG` 指到真实 state 的配置路径）→ 夹具 rc=1，红的是反向守卫那条，快照「实际」一侧带 `signal-calls.log` 的哈希行；把那一腿去掉、同一份 state 又绿（红来自那一腿）。
- ② **活车道绿（今天的现场）**：夹具跑动中写 `capacity.log` / `nudges.log` / `bg.log` / `panel.log` / `dev.env` / `inbox-watch/*` → rc=0、整段零 ✗。
- ③ **签名红**：诱饵名种进**族外**文件（`capacity.log`）→ 签名断言红并点名 `capacity.log`。
- 对照：③′ 受看面放大成 `*`（= 修复前那种整份快照的最小形状）+ **同一批写入** → 必红，且「实际」一侧点名 `capacity.log`（证明 ② 的写入确实落在两次快照之间，② 不是空过）；④ 还原绿；⑥ 诱饵名种进 `bg/<id>.log` → 绿（runner 车道的边界）；⑦ 受看面改成不存在的名字 → 段尾形状探针红并打印「判据空转」。

**不覆盖（要求 4 的「写明白」）**：

- 受看面**只**认产品这一族路径 —— 活仓库别的车道怎么变，判据都不看（这正是它在活仓库里可满足的原因）。代价两条，写在这里而不是假装被覆盖：
  - (a) 产品把日志名改了而清单没跟着改 → 快照会空转：兜底是段内新增的「守卫名单与产品源码一致」断言（grep `scripts/lib/common.sh` 里 `TEAM_SIGNAL_CALLS_LOG=` 那行是否仍指向 `TEAM_STATE_DIR/signal-calls.log`）+ 形状探针（空转就红）。
  - (b) **别的文件名**落进 `state/`（例如夹具的私有产物因为 `LOGD` 指错而落进账本）这条判据发现不了 —— 那种情形只剩签名断言能发现（且只有那行带诱饵名时）。这是收窄的代价，不是遗漏。
- 判据**不区分作者**：真活着的会话里若有人真的调了被拒的 `pkill`/`killall`，写进去的正是同一个 `signal-calls.log` → 窗口重叠时仍会红。窗口约 2 秒，而该文件在真账本里今天**不存在**（下面 ③ 的活账本清单里没有 `signal-calls.log*`），要撞上得正好有人在门禁跑着的 2 秒里触发一次被拒的模式杀。这是残余风险：我没消除它，也不假装消除了。

## Verification evidence（都是真跑过的）

```
# 自己跑的 · 容器内（worktree 挂 /work，主仓库 .git 只读挂同路径）
$ podman run … localhost/teamsmith-gate:local bash -c '… TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 58'
  ✓ 58 signal-gate 全绿（69 条断言）      # 夹具自己 68 条 + 结果行那一行
  #13 58 · 信号纪律 … · ✓12 ✗0 SKIP0 · 用时 7s
  == 选段结果 ==  ✓ 366  ✗ 0              # logs/30-select58-fast.txt
$ … bash skills/teamsmith/tests/smoke.sh --select 58          # 非 FAST
  ✓ 58 signal-gate 全绿（69 条断言）· == 选段结果 ==  ✓ 428  ✗ 0   # logs/31-select58-full.txt
$ … -v <主仓库>/.pi/team/state:/work/.pi/team/state:ro … --select 58   # FAST，把**真活账本**挂在工作树上
  ✓ 58 signal-gate 全绿（69 条断言）· == 选段结果 ==  ✓ 366  ✗ 0   # logs/32-select58-live-state-fast.txt

# 自己跑的 · 容器内「真活账本」对拍（真账本 485 个文件；只读挂载；脚本 /tmp/p171-live-check.sh）
  ① 旧夹具（main/P168 那版）在活账本副本上、没人写 → rc=0
  ② 同一副本 + 活车道写入器 → 旧夹具 rc=1（红行：期望 [capacity.log	557…）；新夹具 rc=0
  ③ 新夹具对着**真**活账本（运行时照旧在写）→ rc=0
  ④ 正控：诱饵名种进活账本副本的 capacity.log → 新夹具 rc=1 且签名断言点名 capacity.log
  == 结果 == ✓ 10  ✗ 0                    # logs/20-live-ledger-check.txt

# 自己跑的 · 宿主（两件都零 tmux 调用：夹具自己 unset TMUX/TMUX_PANE/TMUX_TMPDIR、只用 argv 记录桩）
$ bash skills/teamsmith/tests/signal-gate.sh        → ✓ 68 ✗ 0      # logs/00-fixture-direct.txt
$ bash skills/teamsmith/tests/signal-gate.sh --break=pass → rc=1，34 条断言红（既有红侧没被我改坏）
$ bash skills/teamsmith/tests/flip-p171.sh          → ✓ 22 ✗ 0      # logs/10-flip-console.txt
$ ~/.bun/bin/openspec validate --all --strict       → Totals: 21 passed, 0 failed   # logs/40-openspec-validate.txt

# 引用的（我没重跑）
PM 2026-10-02 的现场：合并 P168 后在本仓库跑 --select 58 红 1 条、差异行是 capacity.log。我按它的形状复现（上面 ② ，
用的是活账本的真文件名），没有重跑 PM 那一次。

# 没跑的
**整套**门禁 —— `--select 58` 只跑 13 段，选段器点名 108 个没跑的段（0e…15、26、31c、52…），按段规范这不是全套门禁；
交付/复验/归档时按 brief 要求以 58 + FAST 为准。另外 `--select 58` 之外的段（含 13c、12b-pi）我一次都没跑。
```

- Verdict: pass。
- 已知残余风险：上面「不覆盖」的两条（族外文件名、活会话里真有人触发被拒的模式杀）。
- 环境备注：P168 那条「容器里要挂主仓库 `.git`（否则 0d 段红）」仍然成立，上面三轮都挂了。

## Flip evidence（defect-fix）

红 → 绿，**同一批写入、同一份活账本形状、同一时刻**（容器内，`logs/20-live-ledger-check.txt`）：

```
② 旧夹具（main/P168 那版）rc=1：
   ✗ 真实仓库 state/ 前后一致（排除后台作业车道 bg/ 与 bg.log）（期望 [capacity.log	557…
   新夹具 rc=0：同一份账本（软链到同一个目录）、同一个写入器还在写 → 整段零 ✗
③ 新夹具直接读真活账本（485 个文件、只读、运行时在写）rc=0
```

反向（判据不是橡皮章，四条，全在 `logs/10-flip-console.txt`）：

```
① 受看面里写一次（漏钉的产品调用）      → rc=1，实际一侧带 signal-calls.log 的哈希行
③′ 受看面放大成 *（修复前的整份快照）    → rc=1，实际一侧点名 capacity.log
⑤ 签名种进族外文件 capacity.log         → rc=1，签名断言点名 capacity.log
⑦ 受看面改成不存在的名字                → rc=1，形状探针红并打印「判据空转」
```

读法：② 的绿与 ③′ 的红是**同一批写入**的两面 —— ③′ 红证明写入确实落在两次快照之间（② 不是空过），② 绿证明收窄后的判据对活运行时的车道无感；①⑤⑦ 证明剩下的判据各自承重。

## 决定与偏离

- **删 `flip-p168.sh`**：P168 的四面按旧判据（排除面 `(bg bg.log)`）写，锚点在新代码里已不存在（跑起来会 exit 2），留着就是僵尸。面映射：P168 ①（车道绿）→ P171 ②；P168 ②（写 `state/other.log` 必红）在 P171 下**应当绿**（受看面只认产品那一族）—— 这条判据本身被取代了；P168 ③（清单退回 `(bg)`）→ P171 ③′（判据退回整份快照）；P168 ④（还原绿）→ P171 ④。P168 的四份日志仍在 `docs/team/reports/P168-dev/logs/`，脚本本体在 git 历史里（`git show 8d5425fb:skills/teamsmith/tests/flip-p168.sh`）。
- **新增「守卫名单与产品源码一致」断言**（不在 brief 字面里）：白名单最怕的是和产品漂移后静默空转，一条 grep 就能钉住，顺手加上。
- **软链跟随 + 探针**（不在 brief 字面里）：写「真活账本」对拍时发现 `find "<软链>"` 默认不跟命令行软链（只报软链自己，后面全空）→ `state/` 若是软链，判据会**静默**瞎掉（旧代码同样有这个洞）。两个函数各一行 `cd -P`，段尾加一条软链探针；发现过程与理由都写在注释里。
- **签名扫描保留 runner 车道排除**：沿用 P168 的结论（理由见上），但排除面现在与白名单**分开声明**（两个问题：快照看什么 / 签名扫什么），各自逐条带理由。
- 没有扩 `state_files_for_signature` 之外的范围；没有改 `smoke.sh`（58 段的断言计数随夹具增加而增加，那不是断言）。
- 分支基点：我做这活时 main 前进了三条文档提交（P171 派单、P166 关闭/P172 开、P172 派单），我的三个提交现在直接坐在 `4352c39e` 上（`git reset --soft main` 重建，没有回退任何人的改动；`git diff main` 只有上面三个文件）。

## 发现（不修，交给 PM 派单）

**F1：另两个「反向守卫」不是同一物种 —— 它们读的路径根本不存在，是**空过**的（永远绿）。**

- 位置：`skills/teamsmith/tests/team-bg-harness.mjs:60,67` 与 `team-inbox-watch-harness.mjs:190,197`：`const REAL_REPO = resolve(EXT, '../../..')`；而 smoke 传进来的是**文件**路径（`smoke.sh:6504`、`7819` 传 `"$SKILL_DIR/extension/team-bg.ts"`）→ `resolve('<repo>/skills/teamsmith/extension/team-bg.ts','../../..')` = `<repo>/skills`，于是 `REAL_STATE = <repo>/skills/.pi/team/state` —— 任何 checkout 里都不存在 → `snapshot()` 两次都返回 `'absent'` → 断言恒真。
- 证据（`logs/21-other-harness-guard-vacuity.txt`，容器内，活账本只读挂载）：
  - A 往**真**账本写（`capacity.log` 55648 → 78895 字节，写入器确实在跑）→ `TEAM-BG-CASE PASS reverse guard`；
  - B 往**它实际读的** `<repo>/skills/.pi/team/state` 写 → `TEAM-BG-CASE FAIL`（证明读的是哪个路径）。
- 影响：`smoke.sh:6519`、`7834`、`7925` 把「反向守卫 PASS」当断言（13c、12b-pi 两段），但那条守卫不可能失败。
- 建议：单独一件 —— 改路径（`'../../../..'`）**并且**照 P171 的白名单手法收窄；只修路径会让它立刻吃到活运行时的假红，那正是 P171 处理的那类。本任务书点名的夹具与门禁（`--select 58`）不含这两段，我没有动它们。若 PM 认为该并进 P171，说一声，我按新范围接着做。

## Suggested next steps

- PM 复验 `team review P171 --strong`：重点看 `flip-p171.sh` 七面 + 段尾四条形状断言，以及 F1 的独立复现（容器命令与挂载见 `logs/21-…txt`）。
- 归档顺序：本任务 `change: -`（anchor: infra），不牵动 openspec 的依赖链。
- 若接受 F1 的处理建议，请开新任务书（它自己的红侧：把路径改对之后，活车道写入必须仍绿、受看面写入必须红）。
