# M46 · 投递通道降级必须可见（扩展 skip setup 的静默丢失快路径）

agent: dev3   status: DONE   time: 2026-09-20T03:32Z
branch: `task/M46-skip-setup`   PR/MR: -（local 模式：不 push；分支留在 `.worktrees/dev3`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/extension/team-inbox-watch.ts` | 跳过 setup 写本项目 `state/inbox-watch/<key>.skip`（target/session/window/expect/reason/detail/pid/cwd/heartbeat）；state 目录与配置路径锚定 cwd 推导出的项目根（继承的 `TEAM_STATE_DIR` / `TEAM_CONFIG_FILE` 指向另一个 teamsmith 项目 → 拒绝 + 记账本）；成功注册清掉同 target / 同 window 的旧痕迹；`TEAM_INBOX_WATCH_TARGET` 覆盖也过同一道会话检查 |
| `skills/teamsmith/scripts/lib/outbox.sh` | 读活 `.skip`（pid 活着 + cwd 在本项目；cwd 缺失退回心跳）；`team_inbox_watch_degraded_text/_line`（会话名不符按 window 匹配，与扩展的清痕规则成对）；排水前的**只读**残留巡检（`residue-clear … why=box-clear|target-gone`）；`team_outbox_target_gone` + held 死目标计数 |
| `skills/teamsmith/scripts/lib/cmd-status.sh` | `team status` / `team digest` 各加一条降级告警行（与 doctor/panel 同措辞；没降级一个字都不加） |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | doctor 新检查「投递通道 inbox-watch」：活注册 pass；无注册但能证明原因 → 告警（原因 + 「重启进程才加载扩展」的出路） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | 面板数据块 `panel.pm.delivery_warning` |
| `skills/teamsmith/scripts/panel/src/{types.ts,layout.ts,strings/zh.ts,strings/en.ts}` + `panel.js` | 状态带下多一行降级提示（warn 语气 + 文本 token；文案进 zh/en 表，bundle 用 bun 1.3.14 重建） |
| `skills/teamsmith/scripts/lib/cmd-outbox.sh` | `outbox list` 标 `target=gone` + 「目标已消失」计数 + `outbox drop gone` 清理提示；`outbox drop gone`（逐个点名丢弃，负例不误伤活目标） |
| `skills/teamsmith/references/troubleshooting.md` | §21「消息不自动发送：先看有没有 watcher 注册 / skip setup 原因」；纠正 `/reload` 的错误指导 |
| `skills/teamsmith/references/agent-adapters.md` | §4a.2：skip 记录 / state 与配置锚定 / 残留巡检 / 死目标清理的接口契约 |
| `skills/teamsmith/SKILL.md` | 扩展生效方式：`/reload` → **重启进程**（PM `team up` / worker `team resume`）；`-e` 是进程启动参数 |
| `skills/teamsmith/tests/team-inbox-watch-harness.mjs` | M46-S14–S17（含以真 CLI 跑 `team status` 的端到端断言） |
| `skills/teamsmith/tests/smoke.sh` | 12b-pi2 段 30 条断言 + harness M46 断言 |
| `skills/teamsmith/tests/flip-m46.sh` | 翻转包：红树 / 本树 / 1 个扩展变异 / 3 个 bash 变异，六组全成立 |
| `docs/team/reports/M46-dev3/pkg/{run.sh,host.mjs}` | 可重跑的现场复现（26 条断言；临时项目 + 假 tmux，只有 /tmp） |

## Verification evidence (must have actually been run)

验收命令（门禁两件套 + 快模式 + 现场复现）。完整输出存 `pkg/gate-full.out`；`openspec validate` 15 项全过，完整 smoke 全绿：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ change/console-project-settings
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ change/panel-ergonomics
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)
...
== 结果 ==  ✓ 2333  ✗ 0
smoke 全绿
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 1852  ✗ 0
smoke 全绿
```
（输出存 `pkg/gate-fast.out`。）

```
$ bash docs/team/reports/M46-dev3/pkg/run.sh     # 现场复现（本任务的验收第 3 条）
== 10 · 扩展启动时会话名不符 → 本项目留痕 + doctor/status/面板报降级 ==
  ✓ 真扩展跳过了 setup（未注册）
  ✓ 跳过痕迹落在**本项目** state（<frontend-project>_pm-4ce4341b.skip）
  ✓ 痕迹写明原因：会话名不符
  ✓ 痕迹记下真实会话名
  ✓ 痕迹记下配置期望的会话名
  ✓ team status 报投递通道降级（不再静默退回慢路径）
  ✓ team status 说出原因
  ✓ team status 给出出路（重启进程）
  ✓ team doctor 有投递通道一条
  ✓ team doctor 报同一条原因
  ✓ pulse 面板的 pm 块带 delivery_warning
  ✓ pulse 面板的**渲染帧**里看得见这行（不只是数据字段）
  ✓ 继承的 TEAM_STATE_DIR 指向别的项目 → 拒绝（不写别人家的 state）
  ✓ 反向守卫：别的项目的 state 里一个文件都没有
  ✓ 拒绝被记进本项目的账本
== 20 · 没有 watcher：脏框先排队，框空后的下一拍投出（不永久滞留） ==
  ✓ 脏框 → 报 queued（不粘字）
  ✓ 排队时一个键都没发
  ✓ 条目留在活动队列（下一拍可重试）
  ✓ 框空后下一拍真的投递（串行重试）
  ✓ 投完队列不残留
== 30 · 残留已不在框里 → residue-clear；死目标的 held → target=gone + drop gone ==
  ✓ 下一拍记 residue-clear（残留已不在框里）
  ✓ 状态行不再报「留在框里」
  ✓ 旧会话名的 held 被标成 target=gone
  ✓ 给出清理出口
  ✓ drop gone 点名丢弃的文件
  ✓ 死目标的 held 条目已清理
== pkg 结果 ==
✓ 26 / ✗ 0
```

扩展夹具（真扩展 + 真 CLI 的零模型形态；完整日志 `pkg/harness.out`，75 条 PASS）：

```
$ bun skills/teamsmith/tests/team-inbox-watch-harness.mjs skills/teamsmith/extension/team-inbox-watch.ts
TEAM-IW-CASE PASS M46-S14 a session-name mismatch leaves exactly one .skip record
TEAM-IW-CASE PASS M46-S14 the real CLI reports the delivery degradation in `team status`
TEAM-IW-CASE PASS M46-S15 a successful registration clears the stale .skip for its target
TEAM-IW-CASE PASS M46-S16 an inherited TEAM_STATE_DIR pointing at another project is refused
TEAM-IW-CASE PASS M46-S17 an inherited TEAM_CONFIG_FILE pointing at another project is ignored
TEAM-IW-HARNESS OK
```

- Verdict: **pass**（门禁、快模式、复现、夹具、翻转全绿）
- Notes / 未覆盖：
  - 面板提示的验证：复现包同时断言 `panel.pm.delivery_warning` 与 `team monitor --print` 的**渲染帧**
    含「投递降级」行；smoke 只查数据块（不每次起 panel.js）。没有加降级态 panel 快照（要造
    「PM 在跑但没有注册」的假 Pi，代价高、收益低）。
  - 完整门禁第一次跑时 M28（podman 容器自检）**单点失败**（当时另一套 FAST 门禁在并发跑）；
    单独重跑 `bash skills/teamsmith/tests/container-tmux.sh --selftest` 通过（宿主 tmux 指纹
    52225cb0… 前后逐字节不变），随后一次**干净、独占**的全量门禁全绿（2333/0）。现场留档：
    `pkg/m28-transient.out`。
  - 不是所有「没有 watcher」的形状都有 `.skip`：`resolveTarget()` 拿不到 tmux target（无 `TMUX_PANE`
    且无覆盖）时只记 `state/inbox-watch.log` 的 `skip setup: no tmux target`（没有 target 就无法按
    key 落痕迹）；这条由 doctor/status 的「PM 在跑但没有注册」兜底口径覆盖。
  - `draft-raced*`/`unconfirmed` 是规格终态：「下一拍自动清掉残留」实现为**只读**巡检 + 账本
    `residue-clear`（绝不发键、绝不重贴）；payload 仍在人的框里时不会自欺地报「已清」。
    若希望自动收回仍在混排框里的 payload，那是投递契约的修改（spec 的「a draft-raced entry is
    never pasted again / pane receives no key」），需要另立任务。

## Flip evidence (required for defect-fix tasks)

```
$ bash skills/teamsmith/tests/flip-m46.sh
✓ 红树（7de588c715a70aa0ccecb2168b9229a60d99dd44）复现成功：M46-S14/S15/S16 全红（修复前：跳过无痕、继承的 state 无锚定）
✓ 本树：harness 全绿（75 条用例，含 M46-S14/S15/S16/S17）
✓ 变异扩展（writeSkipRecord 空操作）：M46-S14 红 —— 守卫测试咬在留痕实现上
✓ bash 变异①（告警行恒假）：绿树 status 报降级 / 变异树不报 —— 这条断言真的钉在告警实现上
✓ bash 变异②（target_gone 恒假）：绿树 list 标 target=gone / 变异树不标 —— 断言钉在死目标判定上
✓ bash 变异③（residue sweep 空操作）：绿树记 residue-clear / 变异树不记 —— 断言钉在巡检实现上
exit=0
```

红树的具体红：M46-S14 `a session-name mismatch leaves exactly one .skip record`（旧扩展根本不写记录）、
M46-S15（旧扩展没有清痕）、M46-S16（旧扩展直接按 `TEAM_STATE_DIR` 把注册写进别人的项目）。
变异方向都是「删掉实现 → 断言红」，因此测试不是「实现怎么改都绿」。

## Decisions and deviations

- **`TEAM_INBOX_WATCH_TARGET` 现在也接受会话检查**（原来 `override` 会跳过检查）。理由：覆盖只是
  「从哪里读 target」的旋钮（headless/夹具），不该改变「哪个会话是本项目的」；否则继承/显式覆盖
  都能把外来会话塞进本项目的投递（也正好是夹具能确定性地造出「会话名不符」形状的前提 —— bun 缓存
  启动时的 PATH，PATH 假 tmux 在夹具里不可靠）。现有夹具（M30 harness、归档的 M30 复验包）的覆盖值
  与各自配置一致，不受影响；smoke 与 harness 全绿。
- **只读巡检而非「下一拍收回/重投」**：规格把 `draft-raced`/`unconfirmed` 定为终态且后续 drain
  不许给它发键，所以「自动清掉」实现为：下一拍排水先读框 → payload 已不在框里（或目标消失）→
  账本记 `residue-clear`，状态行不再报残留；排队的消息由**同一拍**继续投出（框已空）。
  payload 仍在框里（含混排）→ 什么都不记、照旧报「留在框里」，绝不自动碰人的框。
- **死目标清理是新的人显式出口**：`team outbox drop gone`（不静默；逐个点名）。`drop n` / `drop all`
  语义不变；身份观察白名单里 `outbox list` 已是只读，无需变更。
- **SKILL.md 的 `/reload` 行**：任务只点名 `references/troubleshooting.md`，但最常被读到的错误指导
  在 SKILL.md 的扩展表（「`/reload` clears the extension cache and re-imports」+「重启整会话不必要」）。
  按 Pi 自己的扩展文档（`-e` 是 quick tests；只有自动发现目录可热重载）改成「重启进程」。**文件归 PM**，
  如与 PM 的口径不一致请直接改回（这条改动是本任务里唯一越过任务书点名范围的一处）。
- **spec 未动**：M30/M43 建立的 watch lane 契约一直写在 `references/agent-adapters.md`（openspec
  specs 里没有 inbox-watch 能力），M46 的接口按同一先例补在 §4a.2；门禁的 `openspec validate --all --strict`
  不受影响（15 项全过）。
- **面板 bundle 重建**：`panel.js` 用本机 bun 1.3.14 重建（smoke 会做字节级重建比对）；zh/en 表键集
  相等由 `panel-strings.mjs` 与 smoke 28 段守门。

## Suggested next steps

- PM 复验建议顺序：① `team review M46 --strong`（独立 worktree 跑门禁）；②
  `bash skills/teamsmith/tests/flip-m46.sh`（六组翻转）；③
  `bash docs/team/reports/M46-dev3/pkg/run.sh`（26 条现场复现，只写 /tmp）。
- 遗留（未做，超出任务书；如需要请另立任务）：① 扩展的 `TEAM_CONFIG_FILE`/state 锚定已补，但
  CLI 侧 `TEAM_STATE_DIR` 仍是「显式值照用」（规格 scenario 要求如此）——若继承值是别人的项目，
  CLI 会把队列写过去；② 运行中的 PM 若跑的是**没有 M46**的旧扩展且配置会话名正确，只会有
  「扩展未加载」的兜底告警（没有 `.skip` 原因）；③ `no-tmux-target` 形状没有 key 化的痕迹。
