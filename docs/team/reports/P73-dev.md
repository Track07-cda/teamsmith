# P73 · 门禁的隔离扫描会被自己的审计日志毒化（propose）

```
task:    P73
agent:   dev
branch:  task/P73-apply（local 模式：不 push；分支留在 .worktrees/dev）
change:  gate-isolation-scan-scope（phase: propose；**未写任何实现**）
deltas:  verification（ADDED ×1）· boundary（MODIFIED ×1）
status:  DONE（提案包 + 红侧实测 + 提案自检；等 PM 提案审查）
```

本任务只出提案：`openspec/changes/gate-isolation-scan-scope/` 四件套 + 本报告。`skills/**`、
`openspec/specs/**`、任务书、`docs/team/**` 其它文件零改动。

**总结论**：任务书的第 2 条前提（"审计日志 append-only 无上限"）与当前树不符——M36 起 shim 就有
2000 行→留最新 1000 行的界（今天 1780 行，从未轮转）；真正的卫生缺口是**轮转无声**：裁掉历史后文件里
没有任何记号（实测 2100 seed + 一次调用 → 1000 行、首行 `seed 1102`、`grep rotation` = 0），取证者会把
"被裁掉"误读成"没发生过"。因此 `boundary` 的 delta 不是去加一个已存在的界，而是给这个界加**自述**：
轮转后首行是 marker（ISO 时间 · `rotation` · 累计 `dropped=<N>`），最新 1000 条调用行照旧保留。
扫描口径（`verification`）按任务书裁决：审计日志是**流量记录**不是账本状态，按**精确路径**排除；
`state/bg/**` 的既有排除保留；负对照照旧必须能红。

## Deliverables

| 路径 | 内容 |
|---|---|
| `openspec/changes/gate-isolation-scan-scope/proposal.md` | 两条判据的红侧、要收口的内容、验收命令、flip、边界（598 词，含代码块） |
| `openspec/changes/gate-isolation-scan-scope/design.md` | 现场测量、扫描作用域裁决（D1）、卫生界裁决（D2）、轮转自述（D3）、精确路径与负对照（D4）、可证伪计划、风险 |
| `openspec/changes/gate-isolation-scan-scope/specs/verification/spec.md` | **ADDED**：夹具痕迹扫描只读账本状态，不读流量记录（4 scenario） |
| `openspec/changes/gate-isolation-scan-scope/specs/boundary/spec.md` | **MODIFIED**：审计日志的流量记录定性 + 界保留 + 自述轮转（base 3 scenario 逐字保留，+1） |
| `openspec/changes/gate-isolation-scan-scope/tasks.md` | apply 计划（4 组、11 事；逐 requirement 复核表、路径授权、夹具纪律） |
| `docs/team/reports/P73-dev.md` | 本报告 |

## 验收命令（实际运行，尾部为真实输出）

### 1) OpenSpec 严格校验（提案包本体）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate gate-isolation-scan-scope --strict --type change
Change 'gate-isolation-scan-scope' is valid

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ spec/verification
✓ spec/watchdog
Totals: 27 passed, 0 failed (27 items)          # 基线 26 → 本提案 +1（新 change）
```

### 2) delta 形态自检（MODIFIED 标题对得上 base、基础 scenario 一条不丢）

```
$ python3（逐 Requirement / Scenario 比对 base spec 与 delta）
== boundary MODIFIED ==
  MATCHES-BASE: The gate's actions are logged, and no window carries a destructive-call grant
    base=3 delta=4 missing=[] added=['A truncated log says so']
== verification ADDED ==
  NEW: The fixture-trace scan reads ledger state, not traffic records (4 scenarios)
```

（`openspec validate` 不检查 MODIFIED 与 base 的匹配，也不检查 scenario 是否可失败 —— 上面逐条比对是我自己
做的。）

### 3) 试验归档（delta 真能并进 specs/，且不丢 base scenario）

```
$ rm -rf /tmp/trial-p73 && mkdir -p /tmp/trial-p73 && cp -r openspec /tmp/trial-p73/ \
  && (cd /tmp/trial-p73 && openspec archive -y gate-isolation-scan-scope)
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Change 'gate-isolation-scan-scope' archived as '2026-09-22-gate-isolation-scan-scope'.

$ (cd /tmp/trial-p73 && openspec validate --all --strict) | tail -3
Totals: 26 passed, 0 failed (26 items)          # 归档后 26 个 spec，无 delta 失效

$ awk '/^### Requirement: The gate.s actions are logged/,/^### Requirement: Destructive/' \
    /tmp/trial-p73/openspec/specs/boundary/spec.md | grep -c '^#### Scenario:'
4                                                # base 3 + 新增 1，一条没丢
```

### 4) 隔离 lint（提案承诺的验收命令存在且当前干净）

```
$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：红 0 条；另有 36 条落在**历史豁免**的 16 个文件里（M28 之前的证据包，按 sha256 冻结）
（exit 0）
```

### 5) 门禁本体：**未跑**（当时门禁锁被占，且 propose 不改代码）

```
$ flock -n /tmp/teamsmith-smoke.lock true    → 非 0（17:53:48 有持锁者）
$ uptime                                     → load average 8.64, 9.34, 7.74
```

按团队纪律（门禁是机器共享资源、一次只跑一个），我没有排队抢占；propose 阶段零实现，FAST/全量的基线归
PM 的提案审查与 apply。任务书未要求 propose 跑门禁。

## 缺陷的红侧（今日在本 worktree + /tmp 夹具里实测）

### ① 扫描自己毒化自己（brief 的第 1 条，坐实）

`real_ledger_hits()`（`smoke.sh:214`，12b-j / M16 / M98 / P10 共用）**逐字**从 smoke.sh 里抽出，在 scratch
root 里栽 6 处痕迹，跑的是真函数（不是复刻）：

```
$ eval "$(sed -n '/^real_ledger_hits()/,/^}/p' skills/teamsmith/tests/smoke.sh)"
$ real_ledger_hits 'P73SCAN' /tmp/p73-probe/root | sed 's#/tmp/p73-probe/root/##'
docs/team/inbox/leak.md
.pi/team/state/nested/tmux-calls.log
.pi/team/state/phantom.log
.pi/team/state/tmux-calls.log          ← ★ 审计日志被当成泄漏（毒化的正是这一条）
.pi/team/state/tmux-calls.log.1
（state/bg/gate.log 不在结果里——既有排除）
```

即：任何夹具（如 P67 的 `p67faketui-*`）只要**合法地**做一次带 shim 的 tmux 调用，shim 就按设计把它的
argv 写进真项目的 `state/tmux-calls.log`，下一轮 12b-j 必红，且 append（在 2000 行界内）让红粘住直到有人手工
删行——PM 今天就是这么处理的。

### ② 前提修正：审计日志**有界**（brief 第 2 条的"无上限"与树不符）

```
$ wc -l < <main>/.pi/team/state/tmux-calls.log ; stat -c %s …
1780 lines / 588676 bytes        # 今天，未轮转
$ grep -c p67faketui <main>/.pi/team/state/tmux-calls.log
0                                # PM 已手工清掉那两行（红侧现场已不在，机制仍在）
```

界在 `shim/tmux:299-303`：超 2000 行 `tail -n 1000` 留最新；`boundary` 的 base requirement 已把界写进
规格，31c ⑤（`smoke.sh:10573-10577`）已钉住。**所以本 change 不加第二个界**。

### ③ 真缺口：轮转无声（本 change 的 hygiene delta 落点）

用**真 shim**（`PATH=<shim>`、`TEAM_TMUX_REAL` 钉一个 exit-0 桩、日志写 scratch）实测：

```
$ seq 1 2100 | sed 's/^/seed /' > <state>/tmux-calls.log
$ tmux -V                       # 一次被闸门记录的调用
lines=1000
first=seed 1102                 ← 首行是被保留下来的最老调用行，没有任何"历史上被裁掉"的记号
newest=2026-09-22T17:53:41+00:00 · act=pass · sock=… · argv=-V · pid=… cwd=/tmp/p73-probe/root
oldest_seed_present=no
rotation_markers=0
```

取证读法因此会错：日志里"找不到某次调用"既可能是"没发生"，也可能是"被轮转掉了"，而现在两者不可区分。
（brief 点名的 D39 现场通道、以及 M62 的泄漏链诊断——`docs/team/reviews/M62.md:61` 引的就是这份日志的
连续两行——都读这份日志）这个歧义值得一个 `dropped=` 记号。

## 提案的关键裁决（复审要看的四处）

1. **D1 扫描作用域**：审计日志是**流量记录**（内容是调用者自己的 argv/socket，夹具名字出现在那里正是它
   的本职），不是夹具写进项目的**状态**。按**精确路径** `<root>/.pi/team/state/tmux-calls.log` 排除；
   `state/bg/**`（作业 stdout）保留。被否掉的方案（design D1 有理由）：按 shim 行格式过滤（把扫描耦合到
   会变的格式上）、净化日志内容（毁掉取证价值）、留在扫描面靠手工删行（把门禁变成需要日志手术）、按
   basename 排除（会连 `state/nested/tmux-calls.log` 这类真泄漏一起放过）。
2. **D2 界的裁决**：保留 2000→最新 1000 行；不做时间轮转（要调度器，无人在跑时留洞）、不做按
   session/caller 分片（毁掉"掉 server 之前谁打了什么"的时间序）。理由与体积账（今天实测 331 B/行，
   1000 行 ≈ 0.3 MB）在 design D2。
3. **D3 轮转自述**：`marker = <ISO 时间> · rotation · dropped=<N>`，`N` **累计**（前一个 marker 的 N +
   本次裁掉的调用行数），作为轮转后文件的**首行**；marker 不是调用行（不带 `act=`），四值动作词汇表保持
   封闭，最新 1000 条调用行有序保留。首轮 2101 行 → `dropped=1101`；再走 1100 行 → `dropped=2201`（数字
   写进了 delta scenario 与 tasks 2.1）。
4. **D4 精确路径 + 负对照**：delta 里用 scenario 钉住 `.log.1` 与 `nested/tmux-calls.log` **必须红**、
   `state/bg/**` 与审计日志必须静默、inbox/其它 state 文件的负对照照旧红——"变绿"绝不许来自"扫描不再扫描"。

## Flip evidence（propose 能给的那一半：红侧实测 + 绿侧可失败承诺）

| 项 | 红侧（已实测） | 绿侧承诺（apply，task） | 反向对照（必须红） |
|---|---|---|---|
| 扫描口径：审计日志 | `real_ledger_hits` 把 `state/tmux-calls.log` 列入命中（上节 ①） | 同一栽法 0 命中；12b-j 段保持绿（1.1/1.2） | 把排除删掉/放宽成 basename → 新腿红（1.2） |
| 扫描口径：真泄漏 | inbox / `state/phantom.log` / `.log.1` / `nested/…` 四条都命中 | 四条仍逐条点名，`state/bg` 仍静默（1.1–1.3） | 负对照（inbox 栽入）必须照旧红（1.2/1.3） |
| 轮转自述 | 2101 → 1000 行、首行 `seed 1102`、marker 0 个（上节 ③） | 首行 `… · rotation · dropped=1101`，1000 条调用行 + 最新在末、第二轮 `dropped=2201`（2.1/2.2） | 去掉 marker 写入 → §31c ⑤ 新断言红（2.2） |
| 词汇表 | 四值 `act=` 封闭 | marker 不带 `act=`，四个值仍是调用行仅有的动作（2.2） | 现有 31c ④ 断言照旧（2.2/2.3） |

## 每条 requirement 的复核方法（跑什么 → 看哪段 → 期望值）

| Req（能力） | 跑什么 | 看哪段 | 期望 |
|---|---|---|---|
| R1 扫描口径（verification） | 真 `real_ledger_hits`（从 smoke.sh 抽）+ FAST smoke | 命中清单 / 12b-j、M16 的隔离行 | 审计日志与 `state/bg/**` 静默；inbox、`state/phantom.log`、`.log.1`、`nested/tmux-calls.log` 逐条点名；负对照红 |
| R2 审计日志卫生（boundary） | 真 shim + 桩 `TEAM_TMUX_REAL`；31c ⑤ | 日志首行与行数 | `dropped=1101` → `dropped=2201`；1000 条调用行、最新在末；未越界无 marker |
| 门禁 | `openspec validate --all --strict`、FAST + 全量 smoke、`tmux-lint.pl` | 总数与段行 | validate 绿；smoke `✗0`；lint 红 0 |

完整表在 `openspec/changes/gate-isolation-scan-scope/tasks.md` 开头。

## 与任务书的偏差 / 需要 PM 知道的三点

1. **前提修正（重要）**：brief 写审计日志"append-only 无上限也会长（今天已 ~1000 行）"——实际上界自 M36
   就在（`shim/tmux:299-303`），今天 1780 行。因此 `boundary` delta 的内容不是"加界"，而是"给界加自述 +
   流量记录定性"；界本身**照旧**（任务书问"要不要轮转 / 分片"，我的裁决是不换形态、只补自述，理由在
   design D2/D3）。如果 PM 想要的是别的界（例如改成 N 天 / 分片），请说；我按裁决给的方案已写进 delta。
2. **分支名与 phase 不一致（一行小事）**：派单让我在 `task/P73-apply` 上做 `phase: propose`。名字不影响
   内容（本分支只有提案 4 件 + 报告，零实现），但 `team change status` / 后续 apply 分支命名会拿它当
   参照，请 PM 复审时顺手定一下。
3. **`deltas:` 头与方案一致**：头写 `verification, boundary`，我写的正是这两份（无偏差）。本 change 只有
   P73 一个任务，不存在"两任务写同一 delta"的冲突面。

## 没有做的事（propose 的边界）

- 没写实现：`skills/**` 零改动（diffstat 见下节）。轮转 marker 的落点在 tasks 2.1，授权待 PM 的 apply
  任务书写明（`scripts/shim/tmux` 默认 PM 独占）。
- 没改 `openspec/specs/**`、任务书、`docs/team/**` 其它文件（报告除外）。
- 没跑 FAST/全量 smoke：门禁锁被占（上节 5），且 propose 无实现可验。
- 没清理真项目的审计日志（PM 已清；红侧现场在 `/tmp/p73-probe` 复现，不碰真状态）。

## 复验入口

```bash
PATH="$HOME/.bun/bin:$PATH" openspec validate gate-isolation-scan-scope --strict
sed -n '1,80p' openspec/changes/gate-isolation-scan-scope/design.md      # 现场测量与 D1–D4
sed -n '1,70p' openspec/changes/gate-isolation-scan-scope/tasks.md       # apply 计划、路径授权、复核表
sed -n '1,80p' openspec/changes/gate-isolation-scan-scope/specs/boundary/spec.md
```

## 边界与干净证明

- 本分支相对 `main` 的改动只有 `openspec/changes/gate-isolation-scan-scope/**`（6 个文件）与本报告；
  `git diff --stat main...HEAD`（不含本报告这一笔时）→ `6 files changed, 422 insertions(+)`，`git status
  --porcelain` 交付时干净。
- 所有实验在 `/tmp/p73-probe/**`；桩 tmux 是 exit-0 脚本，未触碰任何真 server、未调用真 tmux 的破坏性
  子命令，未碰 `teamsmith` 会话。
- 真项目审计日志只做过**只读**读取（`wc -l` / `stat` / `grep`），未写入。

## 建议下一步

1. PM 按 `references/openspec.md` §4 的十条清单做**提案审查**，产出
   `docs/team/reviews/gate-isolation-scan-scope-proposal.md`（ACCEPTED / NEEDS-CHANGES）。
2. ACCEPTED 之后写 apply 任务书，逐条给：`skills/teamsmith/tests/**`（agent-owned）+
   `skills/teamsmith/scripts/shim/tmux`（**本次明授**，仅 logging 块）。
3. 不接受"手工删日志行"作为常规处置：那正是本 change 要消灭的形态。
