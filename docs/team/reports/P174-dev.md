# P174 · `pulse-nudge-key` apply：叫醒键按**正类别集合**（计数照旧显示，不参与去重）

agent: dev · status: DELIVERED（本地分支，不 push；PM 复验后本地合并） · time: 2026-10-02
branch: `task/P174-apply` · base: `01941cfd`（= 派单时的 main） · change: `pulse-nudge-key`（phase: apply）
授权实现路径：`skills/teamsmith/scripts/lib/**` · `skills/teamsmith/tests/**` · `openspec/changes/pulse-nudge-key/**` ·
`docs/team/reports/P174-dev.md` · `docs/team/reports/P174-dev/**`。

## 结论

`tasks.md` 的 1.1–3.2 与 4.1 做完并转绿；**4.2（换人复验）留给 verify**。三条红侧各留原始输出：

1. **键 = 正类别集合**（D1）：`team_pending_nudge_key` 把一拍快照序列化成 `pending:v1:<name,…>` —— 按既有
   八字段顺序、名序稳定、缺第八字段按 0、空集合有明确表示 `pending:v1:none`；**量级与停跑席位散文不进键**
   （`quota`/`unknown` 只在文本里）。运行中 PM 的提醒判定改用这把键；`watchdog.nudge` 与
   `_watch.env:nudge_sig` 记同一把键（不再多扫一遍）。**计数照旧**：`team_pending_sig`、`nudges.log`
   文本、`pending` JSON 的计数/总数/文案一个没动。
2. **空拍重置**（D2）：观察到的空批次在任何早退（含 standby）之前清掉提醒历史；非空 standby 拍的历史不动。
   被抑制的拍不写 `nudge_epoch`/`nudge_sig`（不推进 gap、不多投一次）。
3. **三条红侧**（原始输出见「红绿翻转」）：① 类别不变、计数 1→4 在 gap 内**不再叫**（现场 12:42/13:57/
   14:12/14:27 四拍那个噪声）；② 类别新增一类**立刻叫**；③ 类别清空后再出现**再叫**（不是"叫过就不再叫"）。
4. **既有承诺没破**：standby 不叫且照记积压日志、无待办且无 PM 完全沉默（P109 两条）；PM
   缺失/启动中/外来、quota、投递守卫的判据在既有门禁里原样保留（见「哪些自己跑 / 哪些引用」）。
5. **观察者不动**（D3）：被抑制的一拍之后，`team monitor --print/--json`、`team __panel-data --block pending`
   显示**当前**计数（4 / 总数 4 / 「未读通知 4」），不是被提醒时的 1；读取后 `state/` 逐字节 + mtime 不变，
   不新增 nudges 行、不新增 outbox 条目。TSX 源与已提交 bundle 未改（delta 里没有这项）。

## 提交

| Commit | 内容 |
|---|---|
| `837b8e0e` | 红侧基线：P172 探针 red-side（F1–F4）+ 与 main 基线的对比证据 |
| `0168bfbf` | 聚焦夹具 `skills/teamsmith/tests/pulse-nudge-key.sh`（五档）+ 修前红侧原始输出 |
| `2e6bace5` | 实现：类别键 + 运行中 PM 提醒判定 + 空拍重置 + `team_nudge` 第二参数 |
| `f5dea221` | 接入 smoke 第 59 段 + `section-paths.tsv` / `section-budgets.tsv` 两行 |
| （本报告） | 报告 + 证据日志（`docs/team/reports/P174-dev/logs/`） |

## 交付物

| Path | 做了什么 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | `TEAM_PENDING_NUDGE_KEY_EMPTY` / `team_pending_nudge_key` / `team_pending_nudge_empty`；`team_nudge` 接可选第二参数（叫醒键，单参数旧路径照用） |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `watch --once`：空拍重置（早退之前，只在确有历史时落盘）；运行中 PM 的判定 `key != last_key`，被抑制的拍不推进 `nudge_epoch`；`team_nudge "$text" "$key"` |
| `skills/teamsmith/tests/pulse-nudge-key.sh` | 新聚焦夹具，五档：`--keys` / `--transitions` / `--policy` / `--observers` / `--migration`（`--all` 全跑） |
| `skills/teamsmith/tests/smoke.sh` | 新增第 59 段，跑夹具五档；可见跳过行照印 |
| `skills/teamsmith/tests/section-paths.tsv` / `section-budgets.tsv` | 第 59 段的行（band=8s，容器实测 7–8s；预算 max(32,60)=60） |
| `openspec/changes/pulse-nudge-key/tasks.md` | 1.1–3.2、4.1 打勾；4.2 留给 verify |
| `docs/team/reports/P174-dev/logs/` | 00–08 全部原始日志 |

夹具设计要点：纯逻辑四档**直接 source 真库**，只影子化「外部世界」（扫描/容量/死亡/排水/PM 判定/投递/
`date`——`tmux` 影子直接 `exit 99`，碰一下就响）；`--policy` 档在私有夹具仓库里跑**真**普通/快速待办读者
（`pk_real_pending_counts` 改名保存后套开关），`--observers` 档在私有夹具仓库里跑**真 team CLI**
（`monitor --print`、`monitor --json`、`__panel-data --block pending`），tmux 走私有只读 shim。
所有临时根走 `tmp_root_create`/`tmp_root_reap_all`；没有 JS 运行时时 monitor 两条腿**显式 SKIP**（不假装绿）。

## 验证证据（都实际跑过；命令 + 原始输出尾巴）

**自己跑的**（新夹具与门禁命令我执行；命令本身是我写的或仓库既有的）：

```text
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/pulse-nudge-key
Totals: 22 passed, 0 failed (22 items)          # rc=0

$ bash skills/teamsmith/tests/pulse-nudge-key.sh --all        # 宿主，08-fixture-green.log
== P174 结果 == ✓89 ✗0 SKIP0

$ distrobox-host-exec podman run … teamsmith-gate:local bash -c 'TEAM_SMOKE_FAST=1 … --select 59'   # 04
#5 59 · pulse-nudge-key：叫醒键按类别集合（P174） · 用时 8s · ✓1 ✗0 SKIP0
  ✓ 59 pulse-nudge-key 五档全绿（90 条断言，0 条可见跳过）

$ distrobox-host-exec podman run … bash -c 'TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh'   # 07（独立 clone，tip=f5dea221）
#120 59 · pulse-nudge-key：叫醒键按类别集合（P174） · 用时 7s · ✓1 ✗0 SKIP0   # FAST 里照跑
账本自查：122 段收口 · 增量 ✓3477 ✗1 SKIP36 ｜ 结果行 ✓3477 ✗1 —— 一致
== 结果 ==  ✓ 3477  ✗ 1        # 唯一 ✗ = 36⑧ 产品面检出探针（既有红，见下）
FAST 模式：跳过 36 个真进程段落
FAST rc=1                      # 由该既有红导致：除 36⑧ 外 3477 条全绿

$ bash skills/teamsmith/tests/smoke.sh --select 3,3b,11b,11b2,11b3,11c,11j,12   # 06（容器，挂载 worktree）
#6  3 · doctor（初始化后）                          · 用时 2s  · ✓7  ✗0
#9  3b · git 归 PM                                  · 用时 5s  · ✓58 ✗0
#12 11b · 定时巡检：有待办才叫醒 PM                 · 用时 25s · ✓64 ✗0
#13 11b2 · PM 存活必须被证明                        · 用时 5s  · ✓32 ✗0
#14 11b3 · 启动中的 PM：一拍只拉起一次              · 用时 15s · ✓57 ✗0
#15 11c · agent 续跑是 PM 的事                      · 用时 26s · ✓15 ✗0
#16 11j · pulse 改名与别名期兼容                    · 用时 12s · ✓48 ✗0
#17 12 · roster / status / ps                       · 用时 6s  · ✓13 ✗0
== 选段结果 ==  ✓ 502  ✗ 1        # 唯一 ✗ = §0d 的环境前置（挂载 worktree 的 .git 指针指宿主路径，容器里看不到仓库）
                                  # 段内点名：冲突标记守卫：找不到受检的 git 工作树（/work/skills/teamsmith 不在仓库里？）

$ bash docs/team/reports/P172-verify/pkg/gate.sh     # 05：独立 clone + 完整门禁容器
✓ change/pulse-nudge-key  …  Totals: 22 passed, 0 failed (22 items)
#119 59 · pulse-nudge-key：叫醒键按类别集合（P174） · 用时 8s · ✓1 ✗0 SKIP0
账本自查：121 段收口 · 增量 ✓4201 ✗1 SKIP3 ｜ 结果行 ✓4201 ✗1 —— 一致
== 结果 ==  ✓ 4201  ✗ 1
  ✗ 36⑧ 产品面检出探针有失败（1 条）
      bad: ⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（跳过把产品问题吞了）
GATE_RC=1
```

**引用 P172 证据包的**（P172 的 verify 写的探针/包，我只跑、不改它的逻辑）：

```text
$ bash docs/team/reports/P172-verify/pkg/check-baseline.sh        # 00
PASS: both MODIFIED blocks retain every baseline scenario         # 4 条 verbatim + 两个 scenario 数

$ bash docs/team/reports/P172-verify/pkg/run.sh --expect-current-red   # 01：修前
SUMMARY failures=4 ids=F1-count-only,F2-empty-return,F3-standby-empty-return,F4-all-category-counts

$ bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed         # 03：修后
SUMMARY failures=0 ids=none                                         # G1–G12 全绿

$ bash docs/team/reports/P172-verify/pkg/run.sh --mutations            # 03：反过校正
MUTANT constant-key rejected   → FAIL F2,F3,G1,G2,G11（5 条，正是该抓的）
MUTANT frozen-panel rejected   → FAIL G9-panel-current-count
```

**已知的既有红（不属于本任务的改动）**：全量门禁唯一 ✗ 是 `36⑧ 产品面检出探针`——
`P172 基线` 的同一次运行里是同一条（`docs/team/reports/P172-verify/logs/full-gate.log` 里
`#96 36 … ✗1` 与同一行 `bad: ⑨ …`），PM 已把它派给 P173；我的改动没有新增红。FAST（clone 里）同样
只有这一条：✓3477 ✗1，其中 §59 照跑（7s ✓1 ✗0）。
另外 `--select` 在**挂载 worktree**（不是 clone）时 §0d 必然红：worktree 的 `.git` 是宿主绝对路径指针，
容器里看不到仓库——`gate.sh` 用 clone 正是为了绕开它，clone 里 §0d ✓8 ✗0。

## 红绿翻转（缺陷修复必交）

**红（实现前，`git stash` 掉 `lib/` 两个文件的改动后真跑；`logs/02-fixture-red.log`，✓56 ✗57）**：

```text
$ bash skills/teamsmith/tests/pulse-nudge-key.sh --all      # 未动 lib
  ✗ ①计数不变量级：nudges.log 仍 1 行：期望 [1] 实际 [2]          # 红侧①：类别不变、计数 1→4 在 gap 内多叫
  ✗ ①计数不变量级：nudge_epoch 没被推进：期望 [100000] 实际 [100900]
  ✗ ②八个位置的计数噪声一个都不叫（noisy=8）：期望 [0] 实际 [8]
  ✗ ⑤空拍：提醒历史被清（nudge_sig 空）：期望 [unset] 实际 [2427741911]
  ✗ ⑤空拍回来：第二次提醒：期望 [2] 实际 [1]                      # 红侧③：清空后再出现不再叫
  ✗ ⑥standby 回来：第二次提醒：期望 [2] 实际 [1]
  ✗ 观察者前提：被抑制的拍没有多叫：期望 [1] 实际 [2]
  == P174 结果 == ✓56 ✗57 SKIP0

$ bash docs/team/reports/P172-verify/pkg/run.sh --expect-current-red
SUMMARY failures=4 ids=F1-count-only,F2-empty-return,F3-standby-empty-return,F4-all-category-counts
  counts=4 0 0 0 0 0 0 0 epoch=100900 sig=31270149 nudges=2 sends=2
FAIL F1-count-only actual=2/100900 expected=1/100000
```

**绿（实现后）**：

```text
$ bash skills/teamsmith/tests/pulse-nudge-key.sh --all
== P174 结果 == ✓89 ✗0 SKIP0

$ bash docs/team/reports/P172-verify/pkg/run.sh --assert-fixed
PASS F1-count-only actual=1/100000
PASS F2-empty-return actual=2
PASS F3-standby-empty-return actual=2
PASS F4-all-category-counts actual=0
PASS G1-add-category actual=2   …   PASS G12-seven-field-text actual=停了的 agent 2
SUMMARY failures=0 ids=none
```

**反过校正（破实现 → 守卫必须红 → 自动还原）**：`run.sh --mutations` 在内存里覆盖后跑同一套：
constant-key 被 F2/F3/G1/G2/G11 抓（5 条），frozen-panel 被 G9 抓（1 条）；仓库文件未被改动。
三条红侧各自的对照也都在夹具里：② 类别新增立刻叫（`③新增类别：第二行提醒` + 键 `pending:v1:inbox,reports`
+ 投递载荷点名两个类别）；③ 清空后回来 `⑤空拍回来：第二次提醒/第二次投递`。

## 决策与偏差

- **`references/config.md` 未改**：`TEAM_PULSE_NUDGE_GAP` 的既有措辞（"same batch … reminded again"）与新的
  「批次 = 类别集合」不冲突，spec 里已给出定义；该目录也不在本次 grant 内。故按 tasks 2.5 的「if needed」
  判为不需要，不是 BLOCKED。
- **`watchdog.nudge` 第二字段的语义变了**（计数签名 → 类别键）。它是机器可读的提醒记录，唯一读者是
  `_watch.env`/巡检自身；文件名与位置不动（别名期 D22），人类可读的计数仍在 `nudges.log` 文本里。
- **空拍重置只在确有历史时落盘**（`nudge_sig` 非空或 `nudge_epoch` ≠ 0 才写），避免空转把 state 的
  mtime 弄脏（面板/门禁有基于 mtime 的只读判据）。
- **`--policy` 档影子 `team_agent_live`**（夹具里席位一律"没在跑"）只在该档进程内生效，进程退出即消失；
  真判据由既有段落钉住（11b2/11b3/12 全绿）。
- **`--observers` 在无 JS 运行时下显式 SKIP** monitor 两条腿（pending 块仍断言）——这里的门禁容器
  (`teamsmith-gate:local`) 有 node，实测 0 跳过。
- 未改：TSX 源、已提交 bundle、`team_pending_sig` 计数签名的既有用途（`last_sig` 与日志去重）、任何
  gap 的配置项与默认值。

## 建议下一步

- **4.2 换人复验**：请 verify（非本任务的 apply 作者）在独立 checkout 上重放
  `run.sh --assert-fixed`、`run.sh --mutations`、`gate.sh`，并核对本报告点名的「引用 P172」与「自己跑」
  两类证据（`logs/` 00–08 全部原始输出都在）。
- PM 复验后可本地合并 `task/P174-apply`；归档前记得 `team change status pulse-nudge-key` 与 P173 的关系
  （全量门禁的 `36⑧` 既有红由 P173 负责，与本次改动无关）。
