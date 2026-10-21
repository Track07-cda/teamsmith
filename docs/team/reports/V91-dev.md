# V91 · P349 的独立验收：`panel-b3.sh` 被 §38 的 `38-i` 腿真的跑起来

agent: dev · phase: verify · category: verify · change: `-` · anchor: none (infra) — 门禁接线
branch: `task/V91-panel-b3-wiring-verify` · 受检候选：`dee07d3b` · time: 2026-10-21T12:2xZ

**判定：PASS** —— 任务书的四件全部成立，且红侧在同一棵受检树上做成了「红 → 绿」一对读数。

| 任务书的问题 | 结论 | 一行证据 |
|---|---|---|
| 1 真的会被跑到 | 成立 | `--select 38`：`✓ 38-i … 全绿（ ✓ 231 ✗ 0）`，§38 `用时 947s · ✓17 ✗0 SKIP0`，全轮 `✓ 433 ✗ 0`，rc=0 |
| 2 地板里没有它 | 成立 | `--floor --slice 30/42`：`SKIP（条件不满足） 38-i·panel-b3-控制台表面`，§38 `用时 341s · ✓15 ✗0 SKIP2`，rc=0 |
| 3 夹具未改、段数未涨 | 成立 | `panel-b3.sh` 与 main 同 blob `2614cdf9…`；`--check` 135→135、`--loop-check` 83/83；清单与 main 逐字节相同，diff 里没有任何新增 `while`/`timeout`/`sleep` |
| 4 红侧（承重） | 成立 | 两份各改一行的私有副本：夹具直跑各 `✓ 224 ✗ 7` rc=1；门禁 `P349_SUITE=<红副本> --select 38` → `✗ 38-i … 有失败` + 逐条点名 7 行，`✓ 432 ✗ 1` rc=1；还原（同一棵树、同一条命令、不设 `P349_SUITE`）→ `✓ 433 ✗ 0` rc=0 |

受检范围核对：`dee07d3b` 相对 main 只动两处产品面 —— `skills/teamsmith/tests/smoke.sh`（§38 新增 `38-i`
腿 + `p327_direct` 提成两条慢腿共用的 `p38_direct`）与 `skills/teamsmith/tests/section-paths.tsv`（第 38
行 patterns 加 `panel-b3.sh`）；其余两条是 P349 自己的报告与候选未含的 V91 任务书。

## 方法：私有副本、私有临时根、私有锁，一套命令只跑一次

受检树是 `/var/tmp/v91/cand`（`git worktree add --detach dee07d3b`，逐字节等于候选，`git status` 干净），
红侧是两份整棵拷贝 `/var/tmp/v91/redA`、`/var/tmp/v91/redB`（各只改一行，见 §4）。所有运行：

```bash
env TMPDIR=/var/tmp/v91/tmp TMUX_TMPDIR=/var/tmp/v91/tmux \
    TEAM_SMOKE_LOCK=/var/tmp/v91/gate.lock TEAM_SMOKE_LOCK_WAIT=900 \
    bash /var/tmp/v91/cand/skills/teamsmith/tests/smoke.sh <选段>
```

段内自报的隔离证据（STEP1 日志头部）：

```
· 临时根：/var/tmp/v91/tmp/teamsmith-smoke-pm_skills-deb708fe.9adLrJ（4 KB · 2 文件 · source=tmpdir）
· tmux 私有 socket：/var/tmp/v91/tmp/.t-1000.NR97ab/tmux-1000/default（…；调用者的默认 server 不参与；49 字节 ≤ AF_UNIX 上限 107）
· 全量门禁互斥：持有 /var/tmp/v91/gate.lock（互斥在伴生锁 /var/tmp/v91/.gate.lock.machine；记录：kind=top pid=3113214 …）
```

即没有抢机器级门禁锁、没有跑整套、没有跑容器。五个步骤串行跑在一个后台作业里（`team_bg_run v91-verify`，
总 3203.9 s），日志留在 `/var/tmp/v91/logs/step{1..5}-*.log`。

## 1 · 它真的会被跑到（`--select 38`，绿侧只跑这一次）

```
== 选段 == decision=RUN · 运行 10/135 段 · 未跑 125 段
== #10 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） == 2026-10-21T11:24:47+00:00
  ✓ 38-h panel-b2.sh 写信面（11 场景） 全绿（ ✓ 167 ✗ 0）
  ✓ 38-i panel-b3.sh 控制台表面（12 场景） 全绿（ ✓ 231 ✗ 0）
      panel-b3 全绿
#10 38 · 设置选项（…） · 参考 用时 947s · ✓17 ✗0 SKIP0 · ticks 17
账本自查： 10 段收口 · 增量 ✓433 ✗0 SKIP0 ｜ 结果行 ✓433 ✗0 —— 一致
== 选段结果 ==  ✓ 433  ✗ 0
STEP1_RC=0 elapsed=1119s            # load 3.55 5.34 7.22（32 核）
```

`✓ 231 ✗ 0` 与作者报告的读数一致，且 `SKIP0` 说明这一轮 §38 底下**没有任何腿被跳过** —— 231 条断言是这条
腿在门禁里真跑出来的，不是从别处抄来的数字。§38 的 `用时 947s`（作者读数是 1213 s，我这轮负载更低 3.5–7.2）。

## 2 · 地板里没有它（具名 SKIP，不是静默不跑）

任务书允许「作者给的等价调用」，我用的是让 §38 成为本片**唯一 own 键**的那一片（`--floor --slice 30/42`，
526 s），而不是作者的 `--floor --slice 12/12`（当时约 37 min）。两者对 §38 的原因串是同形的，已核对：

```
$ section-select.sh --floor --slice 30/42   → own=1 borrowed=9 own-key=38 · reason=38 ← floor, needs:63, slice
$ section-select.sh --floor --slice 12/12   → own=11 borrowed=18        · reason=38 ← floor, needs:63, slice   （作者原调用）
$ section-select.sh --floor                 → keys=128                  : reason=38 ← floor, needs:63
```

同一片上跑门禁：

```
== #10 38 · 设置选项（M55：…） == 2026-10-21T11:43:51+00:00
  SKIP（条件不满足） 38-h·panel-b2-写信面 —— 本轮没有直接点到 38（地板 / needs 带进来的；单次全场景 431 s 不进地板，…）
  SKIP（条件不满足） 38-i·panel-b3-控制台表面 —— 本轮没有直接点到 38（地板 / needs 带进来的；单次全场景 211 s 不进地板，改控制台表面源码或本夹具时才跑）
#10 38 · 设置选项（…） · 参考 用时 341s · ✓15 ✗0 SKIP2 · ticks 17
账本自查： 10 段收口 · 增量 ✓431 ✗0 SKIP2 ｜ 结果行 ✓431 ✗0 —— 一致
== 选段结果 ==  ✓ 431  ✗ 0
STEP2_RC=0 elapsed=526s            # load 5.67 6.48 6.76
```

两次读数的差就是这条腿的价格：直接选到 §38 是 947 s，地板里是 341 s，两者相差 606 s 是 38-h + 38-i 合计；
夹具单跑（§4 的两次红侧，同一台机器）实测 **208 / 209 s**。所以「不进地板」这个取舍的代价是可量化的：
完整门禁每次会多付约 3.5 分钟。

判据本身还有第三种入口的旁证 —— §38 被别人拉进来时也不算「直接点到」：

```
$ section-select.sh --select 63   → reason=38 ← needs:63      （没有直接原因项 → 38-i 走 SKIP 分支）
$ section-select.sh --paths skills/teamsmith/scripts/panel/src/App.tsx → reason=38 ← …/App.tsx, needs:63  （有 → 跑）
$ section-select.sh --floor --paths skills/teamsmith/tests/panel-b3.sh → reason=38 ← …/panel-b3.sh, floor, needs:63 （有 → 跑）
```

## 3 · 夹具没被改、段数没涨

```
$ git -C /var/tmp/v91/cand rev-parse dee07d3b:skills/teamsmith/tests/panel-b3.sh main:skills/teamsmith/tests/panel-b3.sh
2614cdf9e74af2c5d61148d89cb5b110d43ce528
2614cdf9e74af2c5d61148d89cb5b110d43ce528

$ git -C /var/tmp/v91/cand diff --stat main
 docs/team/BOARD.md                            |   1 -      ← 候选落后 main 的账本提交，非产品面
 docs/team/reports/P349-dev2.md                | 187 +++
 docs/team/tasks/V91-panel-b3-wiring-verify.md |  28 ---    ← 任务书晚于候选，非产品面
 skills/teamsmith/tests/section-paths.tsv      |   2 +-
 skills/teamsmith/tests/smoke.sh               |  30 ++++-

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（135 行）
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: needs 声明全部存在且指向更早的段（108 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal…）：.pi/skills
ok: 字面模式（645 条）里 644 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（536 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 12  bad 0  SKIP 1                → rc=0

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 83 行清单 / 83 个 while+sleep 循环，配平 83 个
section-guard --loop-check: 全过                      → rc=0

$ git diff --stat main -- skills/teamsmith/tests/loop-inventory.tsv            → 空
$ git diff main -- …/smoke.sh …/section-paths.tsv | grep -E '^\+.*(while |timeout|sleep )'   → 空
$ bash -n skills/teamsmith/tests/smoke.sh                                      → ok
```

段数 135 → 135；改动里**没有新增任何循环**，所以清单无需新行（`loop-inventory.tsv` 与 main 逐字节相同，
`--loop-check` 83/83 也就是对这条结论的机器复核）。

## 4 · 红侧：夹具改坏 → 门禁 rc=1 并点名 → 还原复绿

两份红副本与受检树的唯一差异（`diff -u` 全文，各一行）：

```diff
# redA：期望的车道清单少一条（任务书说的「删掉一个车道让判据不成立」）
-board_lane_order="todo,wip,review,done,blocked,dropped"
+board_lane_order="todo,wip,review,done,blocked"

# redB：车道头判据改成不可能成立（作者用的是「多塞一个车道」，这里换成打判据本身）
-  if [ "$hits" -ge 1 ] && [ "$lanes" = "$board_lane_order" ]; then
+  if [ "$hits" -ge 999 ] && [ "$lanes" = "$board_lane_order" ]; then
```

夹具直跑（各 209 s 内，`bash <red>/skills/teamsmith/tests/panel-b3.sh --all`）：

```
redA: STEP3_RC=1 · == 结果 ==  ✓ 224  ✗ 7
redB: STEP4_RC=1 · == 结果 ==  ✓ 224  ✗ 7
  两条都以同一批 7 条断言红，逐条点名字段与实测值，例如
  ✗ 按 4 切到看板页（六车道在场）（帧上车道头 1 处、期望 ≥1；车道目标 [todo,wip,review,done,blocked,dropped]、期望 [todo,wip,review,done,blocked]）
```

同一次选段、夹具换成 redA 副本（这一步是承重的：证明**门禁**有牙齿，不只是夹具自己有牙齿）：

```
$ P349_SUITE=/var/tmp/v91/redA/skills/teamsmith/tests/panel-b3.sh bash skills/teamsmith/tests/smoke.sh --select 38
  ✓ 38-h panel-b2.sh 写信面（11 场景） 全绿（ ✓ 167 ✗ 0）
  ✗ 38-i panel-b3.sh 控制台表面（12 场景） 有失败
        ✗ 按 4 切到看板页（六车道在场）（…期望 [todo,wip,review,done,blocked]）
        ✗ 重启后仍在看板页（panel-page 记忆）（…）
        ✗ 夹具：控制台停在看板页（六车道在场）（…）
        ✗ q 返回看板页（…）
        ✗ Esc 返回看板页（…）
        ✗ B5 切到看板页（…）
        ✗ B5 esc 回到看板页（…）
      == 结果 ==  ✓ 224  ✗ 7
      panel-b3 有失败项（TEAM_B3_KEEP=1 保留现场）
#10 38 · 设置选项（…） · 参考 用时 946s · ✓16 ✗1 SKIP0 · ticks 17
账本自查： 10 段收口 · 增量 ✓432 ✗1 SKIP0 ｜ 结果行 ✓432 ✗1 —— 一致
== 选段结果 ==  ✓ 432  ✗ 1
STEP5_RC=1 elapsed=1123s           # load 11.56 6.58 6.42
```

还原：不设 `P349_SUITE`、同一棵树同一条命令 → §1 的 `✓ 433 ✗ 0` / rc=0。所以这一对读数是
**red（rc=1，点名 7 条）→ green（rc=0，✓231 ✗0）**，翻转面落在 `38-i` 这一条腿上，38-h 在两次里都绿
（说明红不是整段被带塌，而是点名到那条腿）。

`P349_SUITE` 这个缝本身也被这一步证明了：门禁确实按环境变量去跑**另一份**夹具文件。

## 本轮没验到的

- 没有跑整套门禁、没有跑 `--floor` 整轮（128 段）、没有跑容器 —— 任务书明确排除；§38 与它带的 5 段
  之外的覆盖不在本报告范围。
- `38-i` 的「夹具文件缺失 → `bad`」分支（`[ ! -f "$P349_SUITE" ]`）只做了静态核对（diff 里是显式
  `bad "38-i 缺 tests/panel-b3.sh…"`），没有为它单独跑一轮门禁。
- 作者报的 `--select 38` 1213 s、`--floor --slice 12/12` 381 s 我没有复现（那是他的读数）；本报告里的
  947 s / 341 s / 208 s 是我这台机器这轮的实测，负载逐条给出。
- 夹具 12 场景各自的行为（页面记忆、折叠、鼠标、resize、q 收起）由 `panel-b3.sh` 自己的 231 条断言判定，
  我只核了「它在门禁里真跑、坏了会点名、地板里不进」，没有逐场景重审这些断言是否判得够。

## Suggested next steps

- 这条腿的价格：完整门禁每次 +3.5 分钟（地板 341 s → 直接选到 947 s，夹具单跑 208 s）。作者建议的
  `38h`/`38i` 细粒度选段键会改选段器的 key 语义，不是接线能顺手做的；若要收，应单独立单。
- 候选的产品面没有发现缺陷，我不建议为它再开返修轮。
