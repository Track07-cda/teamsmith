# P109 · 巡逻的「待复验」误报：wip 任务的在写报告不该唤醒 PM · **apply** · dev-bob

agent: dev-bob
status: **DONE**（本地模式：不 push，分支 `task/P109-wip-pm` 留在本地等 PM 复验/合并）
time: 2026-09-28T16:12Z
branch: `task/P109-wip-pm`
change: `-`（anchor: none (infra) — 只改 `--actionable` 的一处判据，不动 digest [3] 的显示口径）
specs: `-`　deltas: `-`
base: `011119a2`（P109 任务书基点）；修复提交 `78a2bc21`
证据包: `docs/team/reports/P109-dev-bob/pkg/`（`run.sh` + `README.md` + `logs/` 五份原始清单）

## 交付物

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | `--actionable` 追加一条排除：报告所属任务在看板上仍 `todo\|wip` **且**归属席位进程在跑 → 不计入唤醒；新增 `team__report_seat_owner`（账本解析归属席位）+ `team_report_seat_live`（`team_agent_live` 包装） |
| `skills/teamsmith/tests/smoke.sh` | §25 追加一段（append-only）：wip+在跑 不计数 / 非归属席位对照 / wip+停跑 计数 / draft·done 不变 / 全量清单照旧列 / digest 照旧给 `team review` / **红侧**（把交付件复制一份、末尾影子掉新判据 → 又计数） |
| `skills/teamsmith/references/troubleshooting.md` | 4c「delivered but unreviewed」补一句：**已提交**的在飞报告（看板 todo/wip + 归属席位在跑）同样不叫醒，但 `digest [3]` 照旧列出 |
| `docs/team/reports/P109-dev-bob/pkg/**` | 证据包：before（修复前提交的 `cmd-status.sh`）→ after → 停跑反例 → 影子翻转，同一夹具、同一入口 |

## 机制（为什么这样做）

- **判据只有一处**：`team_reports_pending_list` 的 `--actionable` 分支（cmd-status.sh:180 附近），排在 M9.8 的草稿判据之后：
  看板状态是 `todo|wip` 且 `team_report_seat_live` → `continue`（不计数）。**全量分支（digest [3] 的清单）一个字没动**，
  `digest [4]` 的未入账判据也没碰（tasks 第 3/4 条）。
- **归属席位怎么解析**（任务书只说「归属席位」，没指定来源）：按账本第一个定得出来的 ——
  ① `state/<seat>.env: task=<ID>`（dispatch 的记录；与 `team_pending_counts` 判「停了的 agent」同一份映射，
  同一个席位不会一边算在跑一边算停了）；② 看板行的 `agent` 列（任务的指派）；③ 报告所在 agent 工作树的主人的
  **归属副本**（`team__report_copy_rank = 1`，与 digest 打「（在 X 分支上）」同一判据）。
- **判不出来 = 不生效**：三种来源都空（或看板为空）→ 照旧计数。宁可留下噪声，也不静默吞掉一条真待办
  （判不出来就静默是假阴性，比误唤醒坏）。
- **必须保留的反例**：`wip` + 归属席位**停跑** → 照旧计数（那才是真待办：PM 要 `team resume`）；
  席位活着的**不是它的归属**（对照 M98G2 用做非归属席位）→ 照旧计数。
- **实现期自我抓到的一个坑**：看板 `agent` 列是 `-` 时，得先归一化再落③工作树归属（否则 `-` 会被当成席位名，
  工作树归属这一路永远走不到）。我自己的探针抓到了它，已修进 `team__report_seat_owner`。

## 验证证据（全部实跑，原始输出见下与证据包 `logs/`）

| # | 命令 | 结果 |
|---|---|---|
| 01 | `~/.bun/bin/openspec validate --all --strict` | `Totals: 15 passed, 0 failed`，rc=0 |
| 02 | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --keep` | `✓ 2945  ✗ 0`，`smoke 全绿`，rc=0；§25 `#76 用时 13s`（预算 60s） |
| 03 | `bash docs/team/reports/P109-dev-bob/pkg/run.sh` | `== P109 结果 == ok=5 bad=0`（before 红 → after 绿 → 停跑保留 → 影子翻转），rc=0 |
| 04 | `bash skills/teamsmith/tests/smoke.sh`（全量，非 FAST；排队 21 分钟才轮到） | `✓ 3610  ✗ 0`，`smoke 全绿`，rc=0；§25 `#75 用时 13s`（预算 60s）；P70 对账「本套没有触发过超时」 |

```
$ ~/.bun/bin/openspec validate --all --strict
✓ spec/board-and-status … ✓ spec/watchdog
Totals: 15 passed, 0 failed (15 items)          # rc=0
```

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --keep
== #76 25 · 唤醒计数 = digest 的可行动列表（M9.8） == · 预算 60s
  ✓ P109 ⑧：wip + 归属席位在跑 → 不计数（可行动清单里没有它）
  ✓ P109 ⑧对照：活着的席位不是它的归属 → 该报告照旧计数
  ✓ P109 ⑧：可行动计数与清单行数同源
  ✓ P109 ⑧：席位停跑 → 同一份报告回到可行动清单（不静默）
  ✓ P109 ⑧：绿档比停跑档少这一条（Δ=1）
  ✓ P109 ⑧：真判据（无窗口）与夹具停跑档同值（新判据没有改变「席位没跑」的行为）
  · P109 原始计数（--actionable）：可行动行数 归属在跑=2 ｜ 停跑=3（真 CLI 同值）
  ✓ P109 ⑧：digest 全量清单照旧列出在飞报告（显示口径不动）
  ✓ P109 ⑧：草稿（M98G）全量清单照旧列出
  ✓ P109 ⑧：草稿（M98G）可行动清单照旧不数（行为不变）
  ✓ P109 ⑧：看板 done 的报告不在全量清单里（行为不变）
  ✓ P109 ⑧：digest [3] 仍然列出这份在飞报告（只是不叫醒）
  ✓ P109 ⑧：digest [3] 仍然给出 review 待办（显示口径不变）
  ✓ P109 ⑧红侧：影子掉新判据 → wip+在跑 又计数（绿断言咬的就是这条）
  ✓ P109 ⑧红侧：可行动计数回到停跑档（影子后新判据不再生效）
  · P109 红侧原始计数：影子后 M98G1 回到清单=1 ｜ 可行动行数=3（= 停跑档）
  ✓ M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹
  #76 用时 13s · ticks 56
…
== 结果 ==  ✓ 2945  ✗ 0      （FAST 模式：跳过 33 个真进程段落）      smoke 全绿   # rc=0
```

```
$ bash skills/teamsmith/tests/smoke.sh            # 全量（先排队等 dev 的全量跑完：21 分钟）
== #75 25 · 唤醒计数 = digest 的可行动列表（M9.8） == · 预算 60s
  ✓ P109 ⑧：wip + 归属席位在跑 → 不计数（可行动清单里没有它）
  …（同一组 P109 断言全绿；原始计数同样 归属在跑=2 ｜ 停跑=3）…
  ✓ M9.8 隔离：真实账本的 inbox/state 里没有夹具的痕迹
  #75 用时 13s · ticks 56
…
== 结果 ==  ✓ 3610  ✗ 0      smoke 全绿   # rc=0
```

> 全量跑先排队（前一套 15:48 开跑）约 21 分钟后在 16:14:47 取锁开跑，16:37:46 收尾；`P70 对账：本套没有触发过超时`。

> 夹具里**存活判据是显式名单**（替换 `team_agent_live`），因为 FAST 档没有真 tmux；真判据由 §6k/M37
> 独立钉住 —— 本节钉的是「`--actionable` 对新判据的接线」，不是 `team_agent_live` 本身。

## Flip evidence（缺陷修复：红 → 绿 → 影子翻转）

**A. before → after（证据包，同一夹具、同一入口）**

```
$ bash docs/team/reports/P109-dev-bob/pkg/run.sh
== P109 证据包 · 夹具 M1（wip + 工作树正本 + state task=dev） ==
   修复前提交：011119a2…（78a2bc21^）  ｜ 临时根：/tmp/p109-pkg.…
  ok   ① before（旧实现）+ 席位在跑 → 被计数（=1）          ← 红侧起点（P109 的现场形状）
  ok   ② after（交付）+ 席位在跑 → 不计数（=0）             ← 绿
  ok   ② after 的全量清单（digest [3] 口径）照旧列出它（=1）
  ok   ③ after + 席位停跑 → 又计数（真待办：resume）（=1）    ← 反例必须保留
  ok   ④ flip（影子掉 team_report_seat_live）+ 席位在跑 → 又被计数（=1）
== P109 结果 == ok=5 bad=0（判定：before 红 → after 绿 → 停跑保留 → 影子翻转）    # rc=0

-- before-actionable-live.log --
   M1	M1-dev	/tmp/p109-pkg.…/.worktrees/dev/docs/team/reports/M1-dev.md      ← 旧实现把它算成待复验
-- after-actionable-live.log --
                                                                                    ← 空 = 新判据生效
-- after-full-list.log --
   M1	M1-dev	/tmp/p109-pkg.…/.worktrees/dev/docs/team/reports/M1-dev.md      ← 显示口径不动
-- after-actionable-stopped.log --
   M1	M1-dev	/tmp/p109-pkg.…/.worktrees/dev/docs/team/reports/M1-dev.md      ← 停跑 → 回来
-- flip-actionable-live.log --
   M1	M1-dev	/tmp/p109-pkg.…/.worktrees/dev/docs/team/reports/M1-dev.md      ← 影子 → 又回去
```

原始日志（逐字节）：`docs/team/reports/P109-dev-bob/pkg/logs/*.log`。

**B. 常驻红侧（smoke §25 ⑧）**：把**交付的** `cmd-status.sh` 复制一份、只在末尾追加
`team_report_seat_live() { return 1; }`（= 新判据影子掉），同一套加载、同一个夹具 →
`wip+在跑` 的那份报告**重新进入**可行动计数（`=1`、总行数回到停跑档 3）。即：上面绿的断言咬的正是这条新判据，
不是别的东西顺手挡住了。

## Decisions and deviations

- **归属席位的三路解析顺序**是我定的（任务书只写「归属席位」四个字）；先 state 记录、后看板指派、
  最后工作树归属副本 —— 三路都以**账本**为准，判不出来就回落到「照旧计数」（宁噪声不静默）。
- **夹具的存活判据用显式名单替换函数**（FAST 无 tmux）；已在测试注释里写明与 §6k/M37 的分工。
- **一次 word-only 追加提交** `f50cc258`：把红/绿两条原始计数行的措辞写清楚（reviewer 一致读法），
  无行为变化；交付前重跑了 FAST（上表 02 即最终树）。
- CI：本仓库 local 模式 + 不 push，所以没有 CI run；全量门禁是决定性证据（§04）。
- **没有动**：digest [3] 显示口径、digest [4] 未入账判据、任务书、别的目录；没有 push/force-push/merge/rebase。

## Suggested next steps

- PM 独立复验：`bash skills/teamsmith/scripts/team review P109 --strong`（含 flip evidence 段与证据包
  `bash docs/team/reports/P109-dev-bob/pkg/run.sh`）。
- 通过后本地合并 `task/P109-wip-pm` 到 main（local 模式，分支留在本地）。
