# M21 · 控制台收尾：英文设置浮层键列窄 + F-V16-4/5 写实然 + F-V16-6 升级条目 + 两列底边对齐

agent: dev3   status: done   time: 2026-09-17T09:10Z
branch: `task/M21-f-v16-4-5-f-v16-6`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev3`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/panel/src/layout.ts`、`src/strings/index.ts`、`src/main.tsx`、`panel.js` | ①设置浮层列计划（双语键列 + 2 列间隔 + 降级）；②两列 body 底边齐平 + 看板历史随余量放宽；③夹具专用的 `--snapshot --overlay`（确定性渲染浮层帧）。bundle 已重建（883 229 字节，沙盒重建逐字节一致） |
| `skills/teamsmith/scripts/panel/README.md` | 记一句 `--snapshot --overlay`（夹具出口，非用户契约） |
| `openspec/changes/pulse-console/specs/panel/spec.md` | F-V16-4/F-V16-5 写进「Every key affordance is also a mouse target」（需求正文 + 2 个 scenario）；item 5 的齐平规则写进「The layout is a pure function of geometry with four width tiers」（正文 + 1 个 scenario） |
| `skills/teamsmith/references/migration.md` + `skills/teamsmith/SKILL.md` | F-V16-6：升级指南新增一行（`TEAM_MONITOR_REFRESH` 5→3、`state/panel.conf` / `panel-page` / `draft.md` 三个运行时文件），SKILL.md 的 Monitor 行提一句 `panel.conf` |
| `skills/teamsmith/tests/panel-snapshots.sh` | 新增两组断言：浮层列计划（zh/en × 160/120/99/59 + 降级档 24）、三页两列底边齐平；`tests/snapshots/` 4 个两列快照按新卡片高度重钉 |
| `docs/team/reports/M21-dev3/{captures,captures.sh,logs}` | 修前/修后 capture（浮层 16 帧 + 三页 6 帧）与可复跑脚本；门禁与探针日志 |

六个提交（分支 tip = `1e2aa84`）：

```
2187c39 fix(teamsmith): M21 settings overlay gets a real two-column plan
9a9c076 test(teamsmith): M21 assert the overlay's column plan at every width
23086db docs(team): M21 before/after overlay captures
0fe0b41 docs(teamsmith): M21 write F-V16-4/5 as the spec and F-V16-6 into the guide
f796a99 fix(teamsmith): M21 flush the two column bottoms and relax the board's history
1e2aa84 test(teamsmith): M21 assert the flush rule on all three pages + captures
```

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)                    （rc=0，logs/openspec.txt）

$ bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1843  ✗ 0                                   （rc=0，09:03→09:09）
  ✓ 26-a bundle：沙盒里重建逐字节一致（883229 字节）        ← bundle 与源码一致（logs/smoke-full.txt）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1430  ✗ 0                                   （rc=0，logs/smoke-fast.txt）

$ bash skills/teamsmith/tests/panel-snapshots.sh
== 结果 ==  ✓ 28  ✗ 0   → panel-snapshots 全绿             （logs/panel-snapshots-after.txt）
   ✓ overlay 160/120/99/59（zh+en 同列）：键值两列、间隔 2 列、full
   ✓ overlay 24（zh+en 同列）：键值两列、间隔 2 列、degraded
   ✓ zh-{dark,light}-{160,120}：两列 body 底边齐平
   ✓ page 2 (160) / page 3 (160)：两列 body 底边齐平

$ bash skills/teamsmith/tests/panel-b3.sh                  # 真 tmux 控制台夹具（on demand）
== 结果 ==  ✓ 60  ✗ 0                                      （rc=0，logs/panel-b3.txt）
```

机器出口未被布局改动碰到（`--print` 无高度上限，两条新规则都 gated 在 bounded frame）：

```
$ node <修前 bundle> --print … | sed 's/[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/TIME/' > before.txt
$ node skills/teamsmith/scripts/panel/panel.js --print … | (同上)                    > after.txt
$ diff before.txt after.txt
（无输出）— 17 行 vs 17 行，逐字节一致 ✓
```

- Verdict: pass
- Notes:
  - 快照重钉了 4 个文件（`zh-{dark,light}-{120,160}.txt`），diff 只有 agent 卡多出的 3 行空白内容区 + 底边下移（见下 flip ③）。99/59 是单列档，不需要齐平，未变。
  - `panel-b3.sh`（真窗格、120x34）绿：说明列计划与齐平只动布局层，没有动设置/鼠标/队列等交互面。
  - 未验证：真实用户终端的字体/CJK 宽度差异（沿用 `width.ts` 的既有口径）；真实 73 行看板上的放宽上限（夹具是 8 条历史；机制由 captures 可见，上限由 `flush target` 约束）。

## Flip evidence（真实跑出来的红 → 绿）

**① 设置浮层列计划（item 1）** —— 修前 bundle 的帧就是用户截图里那两行：

```
before-en-59.txt（captures/）              after-en-59.txt
│   › language    English                  │   › language         English
│     default pageoverview                 │     default page     overview
│     activity co…on                       │     activity column  on
│     mouse       on                       │     mouse            on
│     density     comfortable              │     density          comfortable
（after-zh-59.txt 同列对齐：语言 / 默认页面 / 活动列 / 鼠标 / 密度，值列同一起点）
```

**② 探针（panel-snapshots.sh）在同一份修前 bundle 上判红、在分支树判绿**：

```
$ TEAM_SNAPSHOTS_TREE=/tmp/m21-before bash skills/teamsmith/tests/panel-snapshots.sh     # 修前 bundle + 修前钉
  ✗ zh-dark-160：两列底边不齐（the last card-closing row closes 1 card(s) …）
  ✗ zh-light-160 / zh-dark-120 / zh-light-120：同上
  ✗ page 2 (160) / page 3 (160)：两列底边不齐
  ✗ overlay 160/120/99/59：列计划检查失败（'语言': no 2 blank columns after the 15-column key cell …）
  ✗ overlay 24：列计划检查失败（… after the 13-column key cell …）
== 结果 ==  ✓ 17  ✗ 11        （rc=1，logs/panel-snapshots-before.txt）

$ bash skills/teamsmith/tests/panel-snapshots.sh                                          # 分支树
== 结果 ==  ✓ 28  ✗ 0         （rc=0，logs/panel-snapshots-after.txt）
```

红的是被修的行为本身（11 条 = 5 条浮层 + 6 条齐平），没有连带红。

**③ item 5 三页（captures/before-page{1,2,3}-160.txt vs after-…）**：

```
page 2（work，board 12 行 vs 右列 17 行）
before：… P10/P9/P8/P7/P6 + 「… 3 older done/dropped rows folded」+ board 卡在第 14 行收口
        第 15–19 行左列全空（右列还在画 decisions）
after ：… P13/P12/P11 三条历史真出现（折叠行消失）→ 卡片带 3 行空白内容区 → 第 19 行收口，
        与右列 decisions 底边同一行
page 1（overview）：agent 卡从第 19 行下移到第 22 行（+3 行空白内容区），与 recent actions 底边齐平
page 3（messages）：queue 卡片下移到第 20 行（+12 行空白内容区），与 health 卡底边齐平
```

**④ 快照重钉的 diff（只有卡片高度）**：

```diff
-╰───…───╯   │  10:00:01 夹具动作一   │
-            │  10:00:02 夹具动作二   │
-            │  10:00:03 夹具动作三   │
-            ╰────…────╯
+│     …     │   │  10:00:01 …        │
+│     …     │   │  10:00:02 …        │
+│     …     │   │  10:00:03 …        │
+╰───…───╯   ╰────…────╯
```

`bash docs/team/reports/M21-dev3/captures.sh docs/team/reports/M21-dev3/captures` 可复跑全部 22 帧
（修前 bundle 由 base `f7c49fd` 的 `src/layout.ts` + 分支源码临时重建，脚本里写明）。

## Decisions and deviations

- **新增夹具出口 `--snapshot --overlay`**（`src/main.tsx` + README 一行）：浮层此前没有确定性渲染路径（只有真 tmux 按 `,`），四档宽度 × 双语 = 8 帧的 capture 与门禁断言都需要它。它只与 `--snapshot` 组合生效，不是用户契约；`--print`/`--json` 不读、不渲染浮层。
- **① 只在 bounded frame 生效**（`height > 0`）：`--print` 没有高度上限，若也补齐会把空白行塞进机器出口（spec 要求它保持 pre-console 形状）。实现里用 `height > 0` gated，并用修前/修后 `--print` 逐字节 diff 证明没变（17 行一致）。这个边界写进了 spec 正文。
- **② 的「该列分到的实际高度」= 齐平目标**（两列天然高度的较大者）：看板只吃「本来会变成空白的那部分高度」，不会把页面顶高——看板自己是最长列时没有余量可让，就保持默认 5 条（代码注释写明）。空余仍多于折叠行数时，剩下的由 ① 以卡片空白补足（page 2 的 after 帧：3 条历史 + 3 行空白）。
- **降级链未动**：只有「最后一个卡片（最后一行是 `cardBottom`）」才会被拉长；`rule`/`summary` chrome 保持原高度，超宽/超高仍由既有 truncate/合并补位（`panel-b3` 的 60 条与 60x8 tiny 断言都绿）。
- **看板列计划只放宽折叠，不改列宽**：`boardBlock` 的 `cell(id,10)/cell(agent,8)/cell(state,8)` 保持原样（brief 明说不动内容逻辑）。同属「硬编列宽粘值」这一类缺陷，若要一起清，见 next steps。
- 报告路径按派单提示写 `M21-dev3.md`（任务书正文写 `M21-dev.md`）。
- item 5 是 PM 中途追加的第 5 条：前面 4 条的提交（2187c39…0fe0b41）在其之前，flip 证据刻意分开记录，便于 PM 逐条复验。

## Suggested next steps

- PM 复验：独立 checkout 跑两个门禁 + `bash skills/teamsmith/tests/panel-snapshots.sh`；`1e2aa84` 可直接本地合并（M20 的门禁计时改动与本文不冲突）。
- 归档 pulse-console 前：本任务的 delta 文字（F-V16-4/5 + 齐平规则）已写进 change spec；归档时按流程并入 `openspec/specs/`。
- 建议另立一条小任务（`skills/**`，PM 独占）：`boardBlock` 的三列用的是「cell(x, N) 紧贴」的旧写法——值刚好占满 N 列时会和邻列粘连（与本次浮层同类的缺陷，例如 agent 名恰好 8 列）。修法同本次：显式间隔或共享列计划；顺带给 smoke 加一条「列间至少一列空白」的断言。
- V16 余下的 F-V16-1/F-V16-3（首帧与 resize 堆水位）与 F-V16-10（27-d 计时抖动 → M20）是性能/门禁账，与本任务无交集。
