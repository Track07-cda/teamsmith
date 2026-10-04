# P211 · 看板裁决 `dropped` 的报告不该再算「待复验」

agent: dev   status: done   time: 2026-10-04T17:05Z
branch: `task/P211-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
tip: `6b2413fc`（**被门禁与翻转验证的代码+夹具 tip**；本报告提交在其后，docs 改动不进门禁判据）
container: `localhost/teamsmith-gate:local`（`HOME=/tmp`、`--pid=host`、`--userns=keep-id`，与 P209 同口径）

```
task:   P211
agent:  dev
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改待复验清单的「看板已裁决」判据与它的夹具
deltas: -
```

## 结论

`dropped` 现在与 `done`/`closed` 同等算「看板已裁决」：**不进待复验清单**、**不进唤醒理由**
（`team_reports_pending` / 面板同源），但仍然**被点名**——digest 的「已按看板跳过」一行
把它列出来，`team status <ID>` 也明说这份报告为什么不列（`dropped` 不走 done 的证据闸门，
所以文案不复用 done 那句「见 reviews/`<ID>`-done.md」，不指一份不存在的记录）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | 三处判据点加 `dropped`：`team_reports_pending_list`（不列）、`team_reports_skipped_by_board`（点名）、`team status <ID>` 的说明（说理由）；[3] 段头与跳过行文案同步 |
| `skills/teamsmith/tests/smoke.sh` | §21 追加 ⑥（`dropped` → 不列 + 点名 + status 说明）与 ⑦（同形状看板改 `wip` → 仍列出来）；12f 的 [3] 段头字面量随判据同步 |
| `skills/teamsmith/tests/flip-p211.sh` | 五面翻转包（三处判据点各一 + 集合放大到 `wip` 的影子 + 跳过行文案），变异只打在 /tmp 副本上 |
| 本报告 | 证据正文全部内联（D94：账本只收正文，证据日志不进仓库） |

## Verification evidence

命令原文（在容器里、`/work` = tip `6b2413fc` 的干净 clone）：

```bash
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
  -v <clone>:/work -w /work localhost/teamsmith-gate:local bash -c '
    git config --global --add safe.directory /work
    openspec validate --all --strict
    bash skills/teamsmith/tests/section-guard.sh --budget-check
    bash skills/teamsmith/tests/section-guard.sh --loop-check
    TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 21,12f </dev/null
    TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null        # 全量
    bash skills/teamsmith/tests/flip-p211.sh
  '
```

### 1) 相关段（§21 待复验清单 / §12f change 归组）+ 纯逻辑门禁

```
tip: 6b2413fc4bb56b40b9b0df524aebdca59df36096
--- openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)                    validate-exit=0
--- section-guard --budget-check                           全过
--- section-guard --loop-check                             全过
--- smoke --select 21,12f
#6 21 · 待复验清单不得越过看板决定（M9.4） · 用时 8s · ✓35 ✗0 SKIP0 · ticks 35
#8 12f · change 归组（P45/B2：digest 的 [6] 段 + 面板 token） · 用时 10s · ✓27 ✗0 SKIP0 · ticks 27
账本自查： 8 段收口 · 增量 ✓125 ✗0 SKIP0 ｜ 结果行 ✓125 ✗0 —— 一致
== 选段结果 ==  ✓ 125  ✗ 0                             select-exit=0
```

- Verdict: **pass**（上面的结果行是容器原始输出的尾部；原始日志按 D94 留在本机未提交的
  `docs/team/reports/P211-dev/`，用上面命令原文可逐字重放）
- §21 的 35 条里，24 条是 M9.4 原有断言（`done`/`closed` 的「不列 + 点名」与 `wip`/未裁决
  控制组），11 条是本任务新增（6 个 `dropped` 正向 + 3 个 `wip` 反向 + 2 个夹具自检）。

### 2) 容器内 FAST 全量：**无新增红**

```
# 本分支 tip 6b2413fc
账本自查： 124 段收口 · 增量 ✓3858 ✗18 SKIP36 ｜ 结果行 ✓3858 ✗18 —— 一致
== 结果 ==  ✓ 3858  ✗ 18
# 基线 main=76375427（同一镜像、同一 clean clone 形状、基线自己的 smoke.sh）
== 结果 ==  ✓ 3847  ✗ 18
$ diff <(tip 红行) <(baseline 红行)   # /tmp/teamsmith-smoke.<rand> 归一为 TMP
RED SETS IDENTICAL（无新增红）
```

- 差值 `+11 ✓ / +0 ✗` 全部来自 §21 新增断言（§21：基线 `✓24 ✗0` → 本分支 `✓35 ✗0`，
  用时 10s，实测带 10.00，无预算告警；§12f 10s 同样无告警）。
- 那 18 条红在基线上**逐条相同**（tip 与基线的红行做 `diff`，结果为空）：
  全部与本任务改动无关，分三类（同一镜像、同一形状下基线一样红）：
  1. **干净 clone 缺生成文件**（15 条）：缺 `SCOPE.md`（§18×1）、缺 `.pi/prompts/opsx-*.md` 与
     `.pi/skills/openspec-*/SKILL.md`（§19×10）、缺 `AGENTS.md`（§12k×1）、由同一原因派生的
     §36 `--check` 夹具红（×3）；
  2. **账本改写留下的过期豁免清单**（§31×1、§58×1）——`fc9c570d` 把证据包移出仓库，但
     `tests/tmux-lint-legacy.txt` / `tests/signal-lint-legacy.txt` 还留着那些已删文件的行：
     `tmux-lint：豁免清单过期（16 个问题；扫描 68 个脚本）`（全部是
     `docs/team/reports/*/pkg/*`）、`signal-lint：豁免清单过期（1 个问题；扫描 96 个脚本）`；
  3. **v0.1.0 发布后的安装形状漂移**（§39×1）：install-shape 夹具期望 0.0.1 副本被判漂移，
     实际每一行都是「copy 0.1.0，与运行版本一致」→ 5 条断言红。

  这三类都不是 P211 的 scope；见「Suggested next steps」第 1–2 条。
- **交付分支的全量复核**：`6b2413fc`（代码+夹具 tip）与 `9582a3e2`（本报告首版）各跑一次同一套
  容器 FAST 全量 → 两次都是 `✓3858 ✗18`，红行 `diff` 为空（`IDENTICAL`）。这之后到本句为止
  只动本报告的正文行，不碰代码/夹具，不进门禁判据。
- `section-select.sh --check` 单独跑也是同一 7 条（tip 与基线输出逐条相同）：
  `行 2/12k/18c 缺 AGENTS.md`、`行 17/18/18c 缺 SCOPE.md`、`行 19 缺 .pi/skills`；其余 6 项
  （key 唯一、段↔行一一对应、needs 存在、豁免类、前导段、段内路径 token 覆盖）全 ok。
- 上面抄的是两次全量的结果行与红行；逐段用时/账本自查在原始输出里（命令见本节开头的命令原文）。

### 3) 没跑的段（FAST 跳过的 36 个真进程段）

`1c·M11 真沙盒窗口`、`6·dispatch 真拉起`、`6b·磁盘容量日志`、`6g·非 Pi agent 端到端`、
`6h·派单启动证据`、`6i·非 Pi PM 端到端`、`6j·worker adapter 启动证据`、`6k·worker 存活判据`、
`10c-②·后台进程组里的门禁`、`11·close 后窗口`、`11b·巡检/pulse`、`11b2·PM 存活证据链`、
`11b3·启动中的 PM`、`11b4·PM 交接`、`11c·agent 续跑`、`11d·边界守卫（真打字）`、
`11g②·say 离线投递`、`11g③·敲门探测`、`11j·pulse 迁移夹具`、`12b-e·巡检一拍排水`、
`12b-h·真 pane 端到端`、`26-m·真 pane`、`31b·容器 tmux 自检`、`31c·真私有 server 生死`、
`31c·指纹翻转`、`31c·窗口注入端到端`、`32⑧·spawn 清洗`、`12g·真实拒绝路径`、
`12h·--force 审计落盘`、`38-b·panel-p21-choices`、`38-f·panel-p21-settings-groups-wheel`、
`41·p55-pane-留存`、`42·P67-真pane`、`44·P80-真pane`、`52·p113-live`、`55·会议真 tmux`。

这些段要么与 P211 的判据链无关（真 pane/派单/会议），要么需要真 tmux 场地；**本任务的
判据链是纯逻辑**（报告清单/看板状态/文案），由 §21 与翻转包全量覆盖。全量真进程门禁
留给复验方跑（`bash skills/teamsmith/tests/smoke.sh </dev/null`，不带 `TEAM_SMOKE_FAST`）。

### 4) 哪些自己跑 / 哪些引用

- **全部自己跑**：上面 1–2 的每一条都在本会话里、`6b2413fc` 的干净 clone + 固定镜像里跑过，
  原始输出按 D94 不收进仓库（本机留档）；命令在 §0，任何人可逐字重放。
- **引用**：无。基线对照（`76375427`）也是我自己跑的同一套命令，用来把 18 条环境红归因清楚。
- 未引用任何别的 agent 的运行结果；未借用别人的 worktree 或会话。
- **宿主上也跑过**（口径说明，按团队纪律如实写）：迭代期的 `flip-p211.sh` 与
  `section-select.sh --check` 在宿主上跑过（都是纯逻辑，不碰 tmux）；交付口径的 16/16 翻转与
  两次全量都在容器里重跑。宿主侧没有出现「tmux 隔离：私有 socket 没生效」类红。
- **本包不是非 FAST 全量**：§2 的全量是 `TEAM_SMOKE_FAST=1`（跳过 §3 列出的 36 个真进程段），
  非 FAST 全量请由复验方在最终 tip 上跑（P208 的教训：不许把 FAST 说成全量）。

## Flip evidence（defect-fix 必填）

### A) 断掉 → 变红 → 还原 → 变绿（`flip-p211.sh`，容器内，副本上变异，真工作树一个字节不动）

```
$ bash skills/teamsmith/tests/flip-p211.sh
== flip-p211 · 看板裁决 dropped 的报告不再算「待复验」（三处判据点 + 两处影子） ==
  ✓ 基线：未变异的副本 §21 绿（✓ 110 行）
  ✓ ① 断点一 待复验清单的 dropped：断掉之后 §21 变红（rc=1）
  ✓ ① 断点一 待复验清单的 dropped：红侧点在预期的断言上
  ✓ ① 断点一 待复验清单的 dropped：还原之后 §21 变绿（✓ 110 行）
  ✓ ② 断点二 跳过点名的 dropped：断掉之后 §21 变红（rc=1）
  ✓ ② 断点二 跳过点名的 dropped：红侧点在预期的断言上
  ✓ ② 断点二 跳过点名的 dropped：还原之后 §21 变绿（✓ 110 行）
  ✓ ③ 断点三 status 说明的 dropped：断掉之后 §21 变红（rc=1）
  ✓ ③ 断点三 status 说明的 dropped：红侧点在预期的断言上
  ✓ ③ 断点三 status 说明的 dropped：还原之后 §21 变绿（✓ 110 行）
  ✓ ④ 影子 集合放大到 wip：断掉之后 §21 变红（rc=1）
  ✓ ④ 影子 集合放大到 wip：红侧点在预期的断言上
  ✓ ④ 影子 集合放大到 wip：还原之后 §21 变绿（✓ 110 行）
  ✓ ⑤ 文案 跳过行状态清单：断掉之后 §21 变红（rc=1）
  ✓ ⑤ 文案 跳过行状态清单：红侧点在预期的断言上
  ✓ ⑤ 文案 跳过行状态清单：还原之后 §21 变绿（✓ 110 行）

== 结果 ==  ✓ 16  ✗ 0
```

五个断点分别是：① `team_reports_pending_list` 的集合退回 `done|closed`；②
`team_reports_skipped_by_board` 同样退回；③ `team status <ID>` 的 `dropped)` 分支改成永不匹配；
④ **影子（反方向）**：集合放大成 `done|closed|dropped|wip`（判据不是橡皮章）；⑤ 跳过行文案退回
`done/closed`。红侧原文（全部五面）：

```
--- ① 断点一 待复验清单的 dropped-red.log
  ✗ P211：看板 dropped 的报告不再列为待复验（不该出现 [M94F]）
  ✗ P211：digest 不再给 dropped 的报告派 review 待办（不该出现 [team review M94F]）
--- ② 断点二 跳过点名的 dropped-red.log
  ✗ P211：跳过行点名了那份 dropped 的报告（…/m94-f-skipline.log 中找不到 [M94F-dev]）
--- ③ 断点三 status 说明的 dropped-red.log
  ✗ P211：team status <ID> 也说明这份 dropped 的报告为什么不列（…/m94-f-status.log 中找不到 [不列]）
--- ④ 影子 集合放大到 wip-red.log
  ✗ 看板还没裁决时，propose 任务的报告仍然列出来（控制组）（…/m94-b-pending.log 中找不到 [M94B]）
  ✗ wip 的 phase 任务给的是阶段下一步（M9.2 的证据）（…/m94-b-digest.log 中找不到 [阶段证据已就绪]）
  ✗ 控制组：没有 phase 的报告照旧列为待复验（…/m94-d-pending.log 中找不到 [M94D]）
--- ⑤ 文案 跳过行状态清单-red.log
  ✗ P211：跳过行的状态清单点名 dropped（不是只说 done/closed）（…/m94-f-skipline.log 中找不到 [任务已 done/closed/dropped]）
```

要点：影子 ④ 红的是 **M9.4 原有的老控制组**（M94B/M94D），说明「集合放大」不是只影响新夹具的
假绿；② 一开始是**假绿**——整份 digest 里 [4] 的「记录未入账」也会原样列出那份未提交的报告
（`· docs/team/reports/M94F-dev.md（pending fixture）`），拿整份 digest 匹配 `M94F-dev` 会在
「跳过点名」断掉后照样命中。夹具已改成**只认「已按看板跳过」那一行**（上面 ② 的红行就是
修好后的形状）。

### B) 修复前 → 修复后（真·红侧对照）

```
$ # 基线代码（main=76375427 的干净 clone）+ 本任务的新夹具
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 21
  ✗ P211：看板 dropped 的报告不再列为待复验（不该出现 [M94F]）
  ✗ P211：digest 不再给 dropped 的报告派 review 待办（不该出现 [team review M94F]）
  ✗ P211：跳过行点名了那份 dropped 的报告（… 中找不到 [M94F-dev]）
  ✗ P211：跳过行的状态清单点名 dropped（不是只说 done/closed）（… 中找不到 [任务已 done/closed/dropped]）
  ✗ P211：team status <ID> 也说明这份 dropped 的报告为什么不列（… 中找不到 [不列]）
#6 21 · 待复验清单不得越过看板决定（M9.4） · 用时 7s · ✓30 ✗5 SKIP0 · ticks 35
== 选段结果 ==  ✓ 92  ✗ 5                                 select-exit=1
   → 这 5 条红行就是上面抄的那些（基线 clone = main 的 `76375427`）

$ # 本分支（6b2413fc）同一夹具（这次带上 12f 一起跑）
#6 21 · 待复验清单不得越过看板决定（M9.4） · 用时 8s · ✓35 ✗0 SKIP0 · ticks 35
== 选段结果 ==  ✓ 125  ✗ 0（--select 21,12f）             select-exit=0
```

## Decisions and deviations

- **`dropped` 单独一句文案**：`done`/`closed` 的报告在看板转变时核对过证据（M9.2，
  `reviews/<ID>-done.md`），`dropped` 没有这道闸门也没有那份记录，所以 `team status` 里
  `dropped` 的活动文案是「被显式丢弃，不是『已交付待复验』」，**不**复用 done 那句
  （否则会指向一份不存在的 `reviews/<ID>-done.md`）。
- **跳过行文案**（`已按看板跳过 N 份报告（任务已 done/closed/dropped）…`）确实变长了，
  但仍然是一行 dim 文本；§21 钉的是它点名了那份报告与状态清单含 `dropped`，没有钉整句。
- **没动 `common.sh` 的同名旧实现**（`team_reports_pending_list`/`team_reports_pending`）：
  它被 `cmd-status.sh` 覆盖，改动属 M6.2 的边界，也不在 OWNERSHIP 里。
- **没动 references/**：那里没有「done/closed 不列待复验」的旧说法；唯一逐字提到
  `done/closed/dropped` 的清单是 dispatch 守卫（`references/troubleshooting.md:324`），
  本来就已经包含 `dropped`。
- **没动 `section-budgets.tsv`**：§21 容器实测 10s，等于现有 `band_s=10.00`，全量里无告警。
- 顺从现场（brief 的现场）之外，没有扩大范围：`blocked`/`review` 等看板状态不在本任务内。

## Suggested next steps

1. **建议开一个小任务（或并进账本改写的收尾）清理两条过期豁免清单**：
   `skills/teamsmith/tests/tmux-lint-legacy.txt`（16 行指向已删的 `docs/team/reports/*/pkg/*`）与
   `skills/teamsmith/tests/signal-lint-legacy.txt`（1 行指向 `docs/team/reports/M35-dev2/pkg/lib.sh`）。
   这两条是 `fc9c570d`「把证据移出仓库」的尾巴，**基线上一样红**，与 P211 无关；不清理的话，
   任何人在这个检出形状上跑全量都会看到 §31/§58 两红（台账 lints 的 `--selftest` 与翻转都还是绿的，
   只是清单里的文件不在了）。
2. **§39 install-shape 的既有红**（5 条断言：漂移副本的 warn 不出现）——看着是 v0.1.0 发布后的
   夹具版本假设过期，同样在基线上红；建议单独定位（本任务的 brief 不含它）。
3. 复验建议（`team review P211 --strong`）：重点是 **B) 修复前后**与 **A) 的②⑤两面**（文案与
   跳过点名），以及全量真进程段（§3 列出的 36 段）——那些段需要真 tmux 场地，本包按 brief
   只跑容器 FAST。
4. 现场同形的复现路径（复验可直接用）：§21 ⑥ 就是它——BOARD 行 `dropped` + 报告在场时，
   `team reports`/`digest [3]`/`team status <ID>`/唤醒理由四处都要一致。
5. 本任务 `change: -`（infra），归档不需要 openspec change 的勾选；无 `BLOCKED`。
