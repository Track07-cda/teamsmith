# M57 · 性能测试从全量门禁里拆出来（propose）

agent: dev-bob   status: DONE   time: 2026-09-21T09:10Z
branch: `task/M57-perf-suite-split`（local 模式：不 push，分支留在 `.worktrees/dev-bob`；PM 复验后本地合并）   PR/MR: -
tip: `e76d817`   base: `fd4fcf6`   change: `perf-suite-split`（propose；只出提案包，未动任何实现）

> 本任务只写 `openspec/changes/perf-suite-split/**` 与本报告。`scripts/**`、`tests/**`、`extension/**`
> 一个字节未改（`git status` 证据见下）。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/perf-suite-split/.openspec.yaml` | 变更目录（`openspec new change perf-suite-split`） |
| `.../proposal.md` | Why / What Changes / Capabilities / Impact / Acceptance（任务书逐字三条）/ What flips / Boundaries / Evidence（579 词） |
| `.../design.md` | 复核现状 + D0–D10 裁决（入口与命名、默认环境、锁、搬迁与双侧守卫、knob 完整性、CI、文档与 doctor、冻结语义）+ 风险与验证计划 |
| `.../tasks.md` | 6 个批次 → 3 个 apply 任务书，requirement→item 覆盖表、路径授权清单、每个守卫的红→绿要求 |
| `.../specs/panel/spec.md` | MODIFIED「Frame assembly is asynchronous, cached and never blocks input」：正确性承诺与三个数值原样保留，判定位置搬到性能套件；新增两条 scenario（门禁不得因慢帧变红、旋钮不得漏进真路径） |
| `.../specs/verification/spec.md` | ADDED ×4：门禁只判正确性（可机检守卫）；性能套件独立/自述/退出码/双环境/自有锁/不进 review；CI 分开且不拦合并 + 发版前记录；文档与 doctor 可发现性 |
| `docs/team/reports/M57-dev-bob.md` | 本报告 |

## Requirement coverage（delta → 设计裁决 → apply item → 计划夹具/翻转）

| Delta 需求 | 设计 | apply item | 夹具 / 翻转 |
|---|---|---|---|
| `panel`#Frame assembly…（MODIFIED） | D1 搬迁清单、D6 双侧守卫、D7 knob 完整性 | 1.1, 1.7, 1.8, 2.1, 2.2 | perf.sh 三判定（1.1）；`tests/panel-knobs.sh`（1.7/2.2）；§27-b/c、§27-d JSON 形状、§28-i 原样保留（2.1） |
| `verification`#The correctness gate judges correctness only | D1 边界（有界轮询/确定性计数留下）、D6 | 2.1–2.3, 5.1 | 注入慢帧 → 门禁绿（5.2）；守卫三向红色（5.1）；knob 检查（2.2） |
| `verification`#The performance suite is separate, self-describing and non-blocking | D2 入口、D3 判定与退出码、D4 环境、D5 锁 | 1.1–1.8, 3.1, 3.2, 5.2, 5.4 | 套件自检（1.4：注入红 / 超前提 SKIP / 边界）；双环境 tail（5.5）；串行锁（1.5） |
| `verification`#CI runs the two gates separately and performance does not block | D8 | 4.1, 4.2 | `gates.yml` 读 + YAML 语法；容器 tail（4.2） |
| `verification`#The two gates are discoverable, and the doctor names the next step | D9 | 3.3–3.6 | 文档 grep；doctor 在场/缺席两态（3.2） |
| 冻结语义（R6，散在两条需求文本里） | D10 | 1.1, 1.4, 1.7, 5.4 | 阈值单源常量；与 `fd4fcf6` 的 diff 只剩位置（5.4） |

## Verification evidence

### 1. 任务书验收命令（真实跑过）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/perf-suite-split
Totals: 18 passed, 0 failed (18 items)
validate rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2223  ✗ 0
FAST 模式：跳过 27 个真进程段落（… 36·panel-cpu-premise）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
smoke rc=0

$ git status --porcelain
（空——提交后工作树干净；本报告提交前只剩它自己）
```

### 2. Delta 完整性：试归档（propose 阶段就把归档期才会暴露的 delta 缺陷提前抓出来）

```
$ cp -r openspec /tmp/m57trial2/openspec && cd /tmp/m57trial2 && openspec list
perf-suite-split              0/29 tasks    just now
$ openspec archive -y perf-suite-split
Specs to update:
  panel: update
  verification: update
Applying changes to openspec/specs/panel/spec.md:
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  + 4 added
Totals: + 4, ~ 1, - 0, → 0
Change 'perf-suite-split' archived as '2026-09-21-perf-suite-split'.
```

- 归档后逐条点名核对：base 的 8 条 scenario 全部保留（`The parenthetical measurements…` / `Keystrokes
  survive…` / `A broken block renders…` / `The red line is measured…` / `A loaded machine skips…` / `A quiet
  machine still fails…` / `The steady-state CPU line…` / `A machine without the measuring tool…`），新增 2 条
  （门禁慢帧、旋钮真路径）；`verification` 从 7 条需求变 11 条（+4）。
- 中途一次 ERROR 值得记：MODIFIED 里我把旧 scenario 改名成「…— by the performance suite」时，
  `openspec validate --strict` 直接报 `omits scenario(s) the current spec still has: "The red line is measured,
  not promised"` —— 说明这一版 CLI **确实会**检查 MODIFIED 的 scenario 保留（memory #1212 里「不检查」的
  说法至少对本例不成立）。改回原名后 18/18 绿。

### 3. 复核 PM 的现状判断（任务书「你要复核」）

**三条墙钟/CPU 红线，确实只有三条**（按源码逐行核对，不是照抄任务书）：

| 位置 | 判定 | 前提 |
|---|---|---|
| `tests/smoke.sh:9141,9151`（§27-d，采样 `:9177–9184`） | 5 次 `team monitor --print --no-activity` 的中位 `≤ 2000ms` | 0.75（`:9112–9124`） |
| `tests/panel-cpu.sh:337,340` | 交互首帧 `≥ 2000ms`、窗格 CPU 中位 `≥ 1%` 为红 | 0.25（`:47–66`），中位 of 3（`:166–190, :293–300`），缺 GNU time → exit 4（`:111, :329`） |
| `tests/smoke.sh:11384–11409`（§36 驱动 `panel-cpu-premise.sh` 四例） | 上述红线的判定本身 | 同上 |

- **27-d 的余量比任务书描述的大**：本轮 FAST 实测中位 **395ms**（样本 408/396/390/394/395，loadavg 8.96，
  夹具仓库）——它是「松」的那条；**贴线的是真 checkout 的交互首帧**。
- **前提成立也可能是红**：本轮宿主 `panel-cpu.sh . 6`：loadavg **6.13 ≤ 8.00**（0.25×32，前提成立）→
  首帧 **3445/3413/3415 → 3415ms**，`panel-cpu: RED`（exit 2），窗格 CPU 中位 0.50%。
- **同一分钟、同一棵树、同一个宿主、容器内**（`localhost/teamsmith-gate:local`，`ci/Containerfile` 镜像，
  `/work` 只读挂载，`--pid=host` 被 rootless podman 拒绝所以没加）：loadavg **5.60**，`nproc` 32，
  `cpu.max = max 100000`（无配额）→ 首帧 **208/209/209 → 209ms**，`panel-cpu: OK`（exit 0）。
  **16 倍差距里没有负载成分**（两次前提都成立）——环境本身决定数字，这就是 D4「参考环境 = 钉死镜像」的
  实测依据（原因未诊断，也不需要：结论是参考环境必须被钉住）。
- **真正没有红线的那些**（复核清楚了，免得搬迁误伤）：26-m/27 的有界轮询（`P10_POLL_SECS` 默认 10s，
  首帧 20s，M20 已从固定 sleep 改成条件轮询；典型帧 1.24–1.6s 安静 / 4.1s load 7–8）是**存活性**等待；
  §37 的 `board row ≤1`、`digest ≤50` 是**确定性调用计数**；§34 是 review 的排队记账。三者都不搬。
- `d-realpath`（旋钮不得漏进真路径）今天在门禁里由 §35f（真路径忽略两个注入并打印）和 §36 的
  `panel-cpu-premise d-realpath`（premise 行不许出现 9999/1 核）共同钉住；本轮 FAST 里 §35f 读到真值
  loadavg 6.49 —— 这条正确性我按 R3 留在门禁（D7：改成 `panel-cpu.sh` 的 premise-only 模式 + 新的
  `tests/panel-knobs.sh`，不判任何时长）。

### 4. 与任务书数字的两处出入（都是复核结果）

1. **「2096 条断言」**：本轮 FAST 模式单独就是 `✓ 2223 ✗ 0`（不含 27 个真进程段）。2096 应是更早的读数；
   全量套件数字本次未跑（propose 只跑任务书验收命令），设计里没有引用 2096。
2. **R3 的「刷新中按键不丢」今天就不在全量门禁里**（finding F1）：`tests/panel-keyprobe.sh`（pty 夹具，
   stub 读者睡 5s，`m`+`hello`+Enter）没有任何 smoke 段调用它，只在 P12/P13/P18 的报告里作为证据出现。
   门禁里属于「异步性」的只有 §27-a（渲染路径无 `spawnSync`）与 §27-b（坏块降级）。design 采取的口径：
   **不新增门禁项**，只保证现有覆盖一条不丢（§27-a/b/c + JSON 形状 + §36 的 knob 检查）；把按键探针真的
   纳入门禁是一个新决定（成本：真 pty ≈1 分钟，属真进程段）。请 PM 裁决（见「Suggested next steps」）。

## Flip evidence

propose 任务没有实现，所以这里给的是**红侧已实测** + 绿侧由 apply 任务书承担的对应项（tasks.md 5.1–5.3）。
R1 的红侧在本轮真跑了：

```
$ TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600 TEAM_SMOKE_FAST=1 \
    bash skills/teamsmith/tests/smoke.sh </dev/null
✗ 27-d 装配红线：5 次采样的中位 2987ms（> 2000ms；样本 2972, 2987, 3000, 2985, 3004ms；
  loadavg 5.71 —— 负载前提成立时这就是面板的问题）
== 结果 ==  ✓ 2222  ✗ 1
injected-gate rc=1
```

即：**一个「慢但正确」的注入，在现状下确实让全量门禁变红**（前提成立，不是负载）。按 design D1/D6，
拆分后同一注入不得再影响门禁（apply 5.2 的红→绿），而它必须在性能套件里照样判红（`TEAM_PERF_FIXTURE=1
TEAM_PERF_FRAME_DELAY_MS=2600 bash tests/perf.sh` → exit 2）。

其余两侧翻转（apply 必须逐条给出 tail）：守卫三向（smoke 里回潮 → 红；perf.sh 里删标记 → 红；修复 → 绿）、
R3 三条正确性断言各删一条 → 门禁红。本轮未执行（它们需要实现存在）。

## Decisions and deviations

- **D4 默认环境 = 钉死容器（有引擎/镜像时），宿主是显式 `--host` 的替代**。理由就是上面那组实测：宿主
  3415ms 红 vs 容器 209ms 绿，同树同一分钟、前提都成立。宿主仍是「本机跑一次」的支持路径（R2），但输出
  会标注它不是参考环境；无引擎/无镜像时打印原因与 build/run 命令并可见 SKIP（exit 4），不静默当参考。
- **D5 锁 = 自有 `TEAM_PERF_LOCK`，绝不拿 `TEAM_SMOKE_LOCK`**：性能套件不能拖慢 `team review` 的排队；
  对门禁锁只做只读非阻塞探测（持锁则打印 holder 与提示）。
- **D6 搬迁 = move（不是 copy 后删），守卫双向**：门禁里不许出现判定标记，`perf.sh` 里必须出现；否则
  守卫红。门禁通过新的 `tests/panel-knobs.sh` 触达 premise-only 模式，所以 `smoke.sh` 自己不会出现任何
  测量夹具的名字——这使守卫可机检（任务书建议的 `budget 2000` 字样被标记集包含）。
- **F1（按键探针不在门禁）**：见上，属于现状复核结论，不擅自扩大范围。
- **protocol.md §5 的试归档命令有坑（给 PM 的文档 nit）**：`cp -r openspec /tmp/trial && (cd /tmp/trial &&
  openspec archive -y <id>)` 在 openspec 1.8.0 下报 `Change … not found. No active changes exist in this root`
  ——CLI 需要根目录**名字是 `openspec`**（或项目根下有 `openspec/`）；本报告用的是
  `/tmp/m57trial2/openspec`，成功。该文件（`skills/teamsmith/references/protocol.md`）是 PM 独占，未改。
- 未做（明确不做）：不动任何阈值/前提因子、不弱化可见 SKIP、不碰 `refuse`/CAS/写入/authz、不重校前提
  （D32 的「安静但不够快」缺口记为 follow-up，见 design §5）、不新增正确性门禁项。

## Suggested next steps

- **PM 提案复审**（`docs/team/reviews/perf-suite-split-proposal.md`）：重点建议看 ①D4 默认环境这个裁决
  （它把「跑在哪」变成契约的一部分）②D6 守卫的标记集够不够硬 ③R3 的 F1 口径是否接受。
- **F1 裁决**：若 PM 认为「刷新中按键不丢」必须回到全量门禁，那是一个新增门禁项的独立范围（真 pty ≈1 分钟，
  真进程段）——需要新任务书，不在本 change。
- **apply 拆分**（tasks.md 已写好）：A1 = B1+B2（`skills/teamsmith/tests/**`，含新 `tests/perf.sh`、
  `tests/panel-knobs.sh`、`smoke.sh` 三处改写 + 守卫）；A2 = B3+B4（`scripts/**`、`SKILL.md`、
  `references/**`、`.github/workflows/gates.yml`、`docs/team/PUBLISH.md`——后两者 PM 独占，需逐条授权或
  PM 自改）。B1→B2 是硬顺序（守卫断言 B1 建的标记）。
- 验收口径不变：`PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` +
  `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`；性能套件上线后它的 `--host` /
  `--container` 两条 tail 进 apply 报告。
