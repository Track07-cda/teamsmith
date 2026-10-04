# P101 · 席位死因：分类 + 一次通报（propose）：提案包

```
agent:   verify
status:  DONE（提案包 4/4；门禁与试归档都真跑过；无 BLOCKED）
time:    2026-09-28T15:20Z–16:05Z
branch:  task/P101-propose（local 模式：不 push；分支留在 .worktrees/verify 交 PM 复验）
change:  agent-death-reason（新建，phase: propose —— 只提案，**未动任何实现**）
brief:   docs/team/tasks/P101-agent-death-reason.md
base:    011119a2；我的提交只加 openspec/changes/agent-death-reason/**、docs/team/reports/P101*/**（见 §3.3）
```

## 0. 一句话

四件套齐：`proposal.md`（471 词）+ 三份 delta（watchdog 4 条 / notify-and-inbox 1 条 / panel 1 条 = **6 条
ADDED、0 条 MODIFIED**，共 23 个 Scenario）+ `design.md`（10 项决策：两个证据源与复用现场读取器的顺序、
**形状先于分类**的五类 frame 表与两个反例、`normal` 的正证据、当前 launch 身份与
`(seat,category,anchor)` 记录、**record-before-send** 的一次通报与 standby 延后、可见面/面板 JSON 契约、
旋钮与边界）+ `tasks.md`（1 个 apply + 1 个独立 verify；需求→条目覆盖表、逐需求复检表、路径授权、
夹具纪律）。实测：`openspec validate --all --strict` **16/0**（提交前、提交后各一次）；scratch 树上
`openspec archive -y` 试归档 **+6 / ~0 / -0**，归档后 validate **15/0**；FAST smoke **全绿 ✓2931 ✗0**
（rc=0，766.9s，33 段可见跳过）；`skills/**` **零 diff**。

## 1. Deliverables

| Path | What |
|---|---|
| `openspec/changes/agent-death-reason/proposal.md` | Why / What Changes（6 条 ADDED）/ Capabilities / Impact / Flip / Boundaries / Acceptance；471 词 |
| `openspec/changes/agent-death-reason/specs/watchdog/spec.md` | 4 条 ADDED：闭集分类与「绝不猜」· 当前 launch 身份 · 可见面 · 巡逻一次通报；17 Scenario |
| `openspec/changes/agent-death-reason/specs/notify-and-inbox/spec.md` | 1 条 ADDED：死因 knock 的内容与诚实性（含 `unknown` 不冒充、忙框排队不粘贴）；3 Scenario |
| `openspec/changes/agent-death-reason/specs/panel/spec.md` | 1 条 ADDED：agents 块四个 cause 键 + 打印行 token；3 Scenario |
| `openspec/changes/agent-death-reason/design.md` | 现状复核表（9 行，带锚点）+ 两个反例/五类 frame 的**可证伪表** + D1–D10 + 实现契约（§4）+ 覆盖表（§5）+ 风险（§6）+ 授权/排序（§7） |
| `openspec/changes/agent-death-reason/tasks.md` | 1 个 apply（1.1–4.2）+ 1 个独立 verify（5.1–5.5）；需求→条目覆盖表 + 逐需求复检表 + 授权路径 + 夹具纪律 |
| `docs/team/reports/P101/fast-result.txt` | 本次 FAST 的原始结果尾（`✓ 2931 ✗ 0`、`SMOKE_RC=0`） |

## 2. 任务书的六点「要做的」→ 落点

| Brief 的点 | 落点 |
|---|---|
| ① 死因分类（闭集、形状、反例） | watchdog R1 + design D2/D3：五类 frame 表（每类一个可证伪夹具 + 优先级）、`TEAM_DEATH_SCAN_LINES` 有界尾、两个反例（`quota` 散文 / `rate limit` 散文）必须 `unknown` |
| ② 两个证据源、缺一即 `unknown` | watchdog R1 第二段 + D2：pane 侧复用既有现场读取器的**同一个**三源顺序（活遗体 → 留证 → tail）+ 非零退出证据；session 侧 = 最新 pi JSONL 的有界尾（含 `--fresh` 命名，monitor.mjs 现在**丢掉**的 `errorMessage`）；两源都有 → 更具体/更近者胜并写明来源 |
| ③ 只对当前一次死亡生效 | watchdog R2 + D5：证据时刻 ≥ `started` 或 exit nonce 匹配；身份 `(seat,category,anchor)`；`state/deaths.log` 行格式；重启后不粘旧原因（scenario 3 条） |
| ④ 可见面 | watchdog R3 + panel R6 + D7/D8：`team status <ID>` 的 `原因：…（来源：…）· 原文：…`、`team digest` [1] 的 `停了的 agent N（dev=quota,…）`、agents 块四个键、打印行 ` · <cause>`；读取面仍只读（指纹断言） |
| ⑤ 一次通报（B） | watchdog R4 + notify R5 + D6：record-before-send（崩溃丢一条而不是发两条）、`--dedup death:<identity>`、`normal` 不报、`unknown` 报但不称因、standby 延后不丢 |
| ⑥ 可证伪 | 每条 requirement 的 Scenario + tasks 4.2（翻坏→红）+ 5.2–5.3（验证方自造夹具：帧超出扫描行数、`started` 之前的旧留证、`--fresh` 会话、截断 JSONL、`403 permission_error` 但**无** quota 措辞必须 `auth`） |

## 3. 实测证据（所有命令都真的跑过）

### 3.1 门禁与提案包

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict          # 提交前（第 1、2 提交后两次）
- Validating...
✓ spec/agent-adapters
✓ change/agent-death-reason
…
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)

$ openspec status --change agent-death-reason
Change: agent-death-reason
Schema: spec-driven
Progress: 4/4 artifacts complete
[x] proposal  [x] specs  [x] design  [x] tasks
All planning artifacts complete!

$ T=/tmp/p101-trial-final-$$; cp -r openspec "$T/openspec"; cd "$T"
$ openspec validate --all --strict            # 归档前：Totals: 16 passed, 0 failed (16 items)
$ openspec archive -y agent-death-reason
Warning: 22 incomplete task(s) found. Continuing due to --yes flag.
Specs to update:
  notify-and-inbox: update      + 1 added
  panel: update                 + 1 added
  watchdog: update              + 4 added
Totals: + 6, ~ 0, - 0, → 0
Change 'agent-death-reason' archived as '2026-09-28-agent-death-reason'.
$ openspec validate --all --strict            # 归档后：Totals: 15 passed, 0 failed (15 items)
$ grep -c '^### Requirement:' openspec/specs/{watchdog,notify-and-inbox,panel}/spec.md
18  19  38        # 对照基线 14 / 18 / 37 → 恰好 +4 / +1 / +1
```

试归档证明了三件事：delta 合法、能被 `archive` 写进主规格、写完之后整套 validate 仍绿；`~0 / -0`
说明**没有**改动或删除任何既有 requirement。

### 3.2 FAST smoke（本工作树的状态证据）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null      # 766.9s
== #112 15 · 完成 == …
== 结果 ==  ✓ 2931  ✗ 0
FAST 模式：跳过 33 个真进程段落（1c·M11 真沙盒窗口|6·dispatch 真拉起|…|44·P80-真pane）
smoke 全绿
SMOKE_RC=0
```

原始尾见 `docs/team/reports/P101/fast-result.txt`（45 行）与 `.pi/team/state/bg/p101-fast-smoke.log`（本
worktree 的私有夹具根；FAST 不进机器门禁锁 —— 本次跑完 `state/` 里没有门禁锁文件，与 P100 复核过的口径一致）。
本 diff 只加 `openspec/changes/**` 与
`docs/team/reports/**`，没有可执行实现；FAST 全绿是「这棵树本身是绿的」的旁证，不是对本 change 的验收
（验收在 apply 阶段）。

### 3.3 git

```
$ git log --oneline -4
cab9f75e docs(openspec): P101 propose — trim the proposal below the 500-word rule
fc7cd444 docs(openspec): P101 propose — agent-death-reason: the design and the apply/verify task plan
b51ceab6 docs(openspec): P101 propose — agent-death-reason: the proposal and the three delta specs
011119a2 docs(team): P107 done (its records were merged and the change archived earlier)

$ git diff --stat 011119a2..HEAD -- skills/ extension/            # 零 diff（只提案）
（空）
$ git status --porcelain                                          # 报告提交前的状态
?? docs/team/reports/P101-verify.md
?? docs/team/reports/P101/
```

### 3.4 现状复核（brief 的「现状」我自己 grep 过，不采信转述）

```
$ grep -rniE "usage limit|insufficient_balance|insufficient balance|permission_error" \
      skills/teamsmith/scripts skills/teamsmith/extension --include='*.sh' --include='*.ts' --include='*.mjs'
（无输出 —— 全仓库没有这套分类/措辞）
$ grep -rn "额度" skills/teamsmith/scripts/lib/common.sh | head -3
… 全是 inotify 配额（max_user_watches）与配置注释，和供应商死因无关
```

已核过的机制锚点（design §1 的每一行都在本 worktree 读过）：

| 锚点 | 现值 |
|---|---|
| 死 pane 证据 | `cmd-agents.sh:494 team_pane_dead_fields`（`dead|status|signal|time`）· `:560 team_agent_capture_corpse`（遗体留证 `dispatch-<agent>-pane-dead.txt`） |
| harness 启动/退出证据 | `:373/:382/:422`：`.spawn`/`.exit` 都是 `<launch-nonce> <value>`；`started` 在每次 dispatch/resume 写（`:1013`） |
| 座位状况 + 现场 | `cmd-status.sh:1099 team_seat_condition` · `:1196 team_seat_scene_print`（活遗体 → 留证 → tail） |
| 「停了的 agent」 | `cmd-watch.sh:668 team_panel_pending_counts_fast` —— 只有**计数** |
| 会话文件 | `common.sh:2440+ team_pi_session_dir`/`team_session_file`（`*_<sid>.jsonl`，漏 `--fresh`）；`monitor.mjs` 的 `readSession` 解析消息但**不读** `errorMessage` |
| 会动的既有断言 | `tests/smoke.sh:8838` 的精确相等 `… 停了的 agent 1`（M9.8-⑤）+ P55 段（132xx）+ `26-g` agents 块 + `26-a` 面板重建逐字节 |

## 4. 需要 PM 判读的口径（提案阶段显式列出，不是埋在正文里）

1. **「无任何可读证据的停席」不发专属 knock**（design D6 的边界）。行为：surfaces 仍报 `unknown`，待办行
   写成 `停了的 agent N（dev=unknown）`（唤醒理由更诚实），但**不**再发一条只有「unknown」的 knock。
   反方论证（若 PM 要求字面执行 brief 的「含 unknown → 一次 knock」）：那就牺牲这个边界，代价是每个
   半派单/夹具形状的停席都会多一条空泛 knock；本提案选择「有可读证据才发」（garbled 帧 = 有证据 → 发，
   仍然满足 brief 的乱码帧夹具）。**PM 判读点**。
2. **`normal` 取正证据**：当前 launch 的 exit 证据 = 0，或留遗体 `pane_dead_status=0`；「会话里最后一回合
   完成」**不**算（否则下一回合被 SIGKILL 会被误报成正常退出）。
3. **优先级表**把 D46 帧（同时含 `403 permission_error` 与 `usage limit`）判成 `quota` 而非 `auth`；
   反例按**形状**（frame + 措辞）判，散文提到 `quota` 一律 `unknown`。
4. **既有断言的必要更新**：`smoke.sh:8838` 的 `停了的 agent 1` 精确相等会因 [1] 新增原因括号而变化；
   apply 必须**更新期望值**（新文本里含 cause 列表）而不是删断言。design D10 已写明。**PM 需知晓**。
5. **一个 apply + 一个独立 verify** 的建议（design §7）：机制是一个 reader + 三个 caller，其中两个 caller
   同文件；拆成两个 apply 会把两个写者放到 `cmd-watch.sh`。
6. **面板 bundle 必须重建**（`26-a` 逐字节 `cmp`）：环境不能 `bun install --frozen-lockfile` 时是
   `BLOCKED:`，不许手改 `panel.js`。

## 5. 边界 / 未做

- `skills/**`、`extension/**`、`openspec/specs/**`、`docs/team/{tasks,BOARD,ROADMAP,DECISIONS,OWNERSHIP}.md`
  **零改动**；本报告是 verify 席位唯一动过的 `docs/**`（OWNERSHIP 允许）。
- Non-Goals 按 brief 写死：不改 M6.5 存活判据、不做自动 fallback、不动 `[auto·interrupted]` 标签、不做
  roster/doctor 新面、不跨项目；新增面只在 status / digest[1] / 面板。
- 本任务是 **propose**（非 defect-fix），没有「修前红」可翻；等价的可复现红/绿证据是 §3.1 的 scratch
  试归档（+6/~0/-0、归档后仍绿）与 §3.2 的 FAST 全绿。
- 我没碰 main、别的分支、别人的 worktree；没 push（local 模式）。

## 6. BLOCKED

无。两条仅需 PM 判读的口径见 §4（1 和 4），都不阻塞提案交审。
