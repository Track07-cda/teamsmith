# P79 · digest 段号重复：`[6]` ×2（P69 的 F1）

```
task:    P79
agent:   dev
branch:  task/P79-digest（local 模式：不 push；分支留在 .worktrees/dev）
change:  -（infra：既有输出面的编号卫生）
anchor:  none (infra) — 只动段号与随之而来的断言，判定语义零变化
deltas:  -
status:  DONE（全量门禁 ✓3077 ✗0 + 翻转证据；等 PM 复验）
```

**一句话**：B2 的 `[6] change 归组` 保留，P55 的「死 pane 席位」段顺延 `[7]`（正文逐字节不变）；
`tests/smoke.sh` §41（死 pane 真实夹具）新增 3 条断言把「段号逐行唯一」钉住 —— `[7]` 改回 `[6]`
时三条同时红，改回来全绿。全表扫查：另一个重复是**历史** `[5]×2`（不是本次回归），按 brief 第 2 条
**不动它**，只把这条豁免显式写进断言与报告。

## 1. 现场与根因（时序有 git 证据）

PM 的现场（`docs/team/tasks/P79-digest-section-renumber.md`，P69 实测）：同一份 digest 里两行 `[6]`。

```console
# 本树（无遗体窗口时）的段头 —— 两个 [6] 只在"有遗体"时同框，所以平时看不见：
$ bash skills/teamsmith/scripts/team digest | grep -nE '^\['
4:[1] 容量与存活
9:[2] 待处理通知
13:[3] 待复验（…）
19:[4] 待收尾（…）
34:[5] 任务板
61:[5] 建议
64:[6] change 归组
```

引入时序（`git log -S`，两条都出自同一台机器同一晚）：

```console
$ git log --oneline -S'[6] 死 pane 席位' -- skills/teamsmith/scripts/lib/cmd-status.sh
0b2d9473 P55: apply agent-pane-survivability — an agent window outlives its pane and a dead pane is never a live seat
$ git show -s --format='%ci' 0b2d9473
2026-09-22 15:36:39 +0000

$ git log --oneline -S'[6] change 归组' -- skills/teamsmith/scripts/lib/cmd-status.sh
8073acd3 P45: apply change-centric-discipline's B2 — the digest groups a change's tasks and the console carries change tokens
$ git show -s --format='%ci' 8073acd3
2026-09-22 16:53:32 +0000
```

改动前 `cmd-status.sh` 里的段头字面量（`grep -n 'printf .*\[[0-9]\]'`）：`[1]`…`[5] 任务板`、`[5] 建议`、
`[6] change 归组`、`[6] 死 pane 席位`。P55 在前、B2 在后，且 B2 的 `[6]` 被 smoke `12f` 的
`F_HDRS_EXPECTED` 逐字节钉着 —— 所以按 P69 裁定**保留 B2、顺延 P55**。

## 2. 全表重复段号扫查（brief 第 2 条）

### 2.1 `[5]×2` 是什么：一次 2026-09-11 的改号漏了下面那段

```console
# 初版（2026-09-11 07:21:30，7b4ed4b6）：任务板是 [4]，建议是 [5] —— 不重复
$ git show 7b4ed4b6:skills/pi-team/scripts/lib/cmd-status.sh | grep -n 'printf .*\['
145:  printf '\n%s\n' "[4] 任务板"
152:  printf '\n%s\n' "[5] 建议"

# v1.9.0（2026-09-11 15:04:14，40bbad6a）：插入 [4] 待收尾，任务板改成 [5]，建议留在 [5] → 重复诞生
$ git show 40bbad6a -- skills/pi-team/scripts/lib/cmd-status.sh | grep -E '^[-+].*\[[0-9]\] '
-  printf '\n%s\n' "[4] 任务板"
+  printf '\n%s\n' "[4] 待收尾（脏工作区 / 未 push）"
+  printf '\n%s\n' "[5] 任务板"
```

即：`[5] 任务板` 与 `[5] 建议` 是「板 + 建议」同族两块，重复形状与本次 `[6]` 事故**同根**
（改号只改了上面那段），但它早于 teamsmith 改名（v1.13.0）、早于本次全部 change，属于既有现状。

### 2.2 处置建议：本次不改，只把豁免显式化

- **不改**，理由三条：① brief 第 2 条明确「历史重复属于既有现状 → 不要为了整齐去改无关段」；
  ② 改它必然顺延 `[6] change 归组`→`[7]`、`[7] 死 pane`→`[8]`，直接违反本任务第 1 条（保留 B2 的 `[6]`）
  并让 `12f` 的逐字节段头钉全红；③ `[5]` 这一族本来就是两块连续输出，`grep '^\[5\]'` 仍能一次拿到
  板 + 建议，没有「用段号定位失效」那种真实伤害（两个 `[6]` 的伤害在于两个**不相干**的段抢一个号）。
- **显式化**：新增断言把重复集钉成恰好 `5`（见 §3），豁免从此是被写下来的，而不是静默的例外。
- 若 PM 之后想要「全局严格唯一」，这是一个独立小任务：`[5] 建议`→`[6]`、change 归组→`[7]`、
  死 pane→`[8]`，同步 `12f` 的 `F_HDRS_EXPECTED` 与本任务的三条断言，重新做一轮翻转。**本任务不做。**

### 2.3 其余段号

改后全表字面量（唯一持有者是 `cmd-status.sh`；`grep -rn 'printf .*\[[0-9]\]' scripts/lib/*.sh`
的另一条命中是 `cmd-agents.sh:851` 的说明文字 `argv[0]`，不是段头）：

```
[1] 容量与存活
[2] 待处理通知
[3] 待复验（…）
[4] 待收尾（…）
[5] 任务板
[5] 建议          ← 2.1 的历史重复（豁免）
[6] change 归组
[7] 死 pane 席位  ← 本次顺延（只有出现遗体窗口时才渲染）
```

digest 没有 `--print/--json` 机器出口（机器面是 `__panel-data`，按键名分块、不编号），所以编号面
只有这一张表。「其它命令有没有段号」：`grep` 全部 lib 只有上面这 8 个字面量。

## 3. 改动

| 文件 | 改动 |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | 死 pane 段头 `[6]`→`[7]` + 上方注释写明「P55 原用 [6]，P69-F1 之后顺延；断言在 smoke §41」 |
| `skills/teamsmith/tests/smoke.sh` §41 | 新增 3 条断言（段头逐字节是 `[7]` / 段号逐行唯一，豁免 `[5]` / 按序覆盖 `[1]–[7]`） |
| `docs/team/reports/P79-dev.md` | 本报告 |

刻意**只有段号 + 断言**：正文一个字节没动（第一条断言就是「正文逐字节同 P55」）。
路径与 brief 的 `grant:` 一致；`references/**` 不需要同步，证据：

```console
$ grep -rn --include='*.md' '死 pane 席位' skills/            # → 0 行
$ grep -rn --include='*.md' -E '\[[1-9]\] ' skills/ | grep -v node_modules
skills/teamsmith/references/workflows.md:116: … `digest` §[4] measures the push state …
skills/teamsmith/references/workflows.md:120: … §[4] only asks for a push when there really are unpushed …
skills/teamsmith/references/workflows.md:129: … §[3] only points the PM at `team review <ID>` …
skills/teamsmith/CHANGELOG.md:249: …（历史条目，[3] 的语义没变）
```

`workflows.md` 的 §[3]/§[4] 指向的段没动，所以不用改；`openspec/changes/change-centric-discipline/`
（仍 active，未归档）里写的 `[6] change 归组` 依然成立，也未动；P55 的翻转夹具
`tests/fixtures/p55/flip-p49.sh` 只 grep 内容（`! p55w pane 已死（signal=9）`），不含段号。

## 4. 可证伪：断言 + 翻转证据

### 4.1 断言（`tests/smoke.sh` §41，死 pane 真实夹具）

```bash
assert_has "$TMP/p55-digest.log" \
  "[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）" \
  "P79：死 pane 段是 [7]，且只有段号变（正文逐字节同 P55）"
P79_NUMS="$(grep -oE '^\[[0-9]+\]' "$TMP/p55-digest.log" | tr -d '[]' | paste -sd' ' -)"
P79_DUPS="$(printf '%s\n' "$P79_NUMS" | tr ' ' '\n' | sort -n | uniq -d | paste -sd' ' -)"
assert_eq "P79：digest 段号逐行唯一（唯一豁免：历史 [5]×2）" "$P79_DUPS" "5"
assert_eq "P79：段号按序 [1]–[7]、[5] 历史重复成对" "$P79_NUMS" "1 2 3 4 5 5 6 7"
```

为什么必须放在 §41：`[7]` 段只在**真有遗体 pane** 时渲染（`team_seat_condition` = `dead*`），
没有遗体的 digest 根本看不到这一行 —— 放在别处会写成一条恒真断言。

### 4.2 交给 PM 的直读复现（与 §41 同一口径的探针）

探针在 `/tmp/p79-probe.sh`（私有 `TMUX_TMPDIR` + `/tmp` 夹具项目 + `bootstrap --no-pulse`，
跑完 trap 自回收；不碰真项目、真 session、真审计日志）。逐字输出：

```console
# 绿侧（交付树）
$ bash /tmp/p79-probe.sh green-after-restore
== 遗体证据 ==
  pane_dead=1 signal=9
== team digest | grep -E '^\[' （/tmp/p79-digest-green-after-restore.log）==
4:[1] 容量与存活
8:[2] 待处理通知
11:[3] 待复验（真任务报告：记录缺失 / 记录已过期（分支又动了）/ 没跑过门禁；草稿另标；看板已 done/closed 的不列）
14:[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 main 另计；squash 已合并单独标注）
17:[5] 任务板
24:[5] 建议
27:[6] change 归组
31:[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）
== 断言（与 smoke §41 同一口径）==
  段号序列 = [1 2 3 4 5 5 6 7]
  重复段号 = [5]   （期望 [5] = 历史豁免）
  断言 = PASS

# 红侧（把 [7] 改回 [6]：`sed -i 's/\[7\] 死 pane 席位/[6] 死 pane 席位/'`）
$ bash /tmp/p79-probe.sh mutant
== 遗体证据 ==
  pane_dead=1 signal=9
== team digest | grep -E '^\[' （/tmp/p79-digest-mutant.log）==
…
27:[6] change 归组
31:[6] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）
== 断言（与 smoke §41 同一口径）==
  段号序列 = [1 2 3 4 5 5 6 6]
  重复段号 = [5 6]   （期望 [5] = 历史豁免）
  断言 = FAIL
```

红侧逐字复现了 PM 现场的两行 `[6]`。

### 4.3 变异 → 门禁红 → 还原（`--strong` 要的那条）

在变异树上跑**全量 smoke**（完整日志 `/tmp/p79-mutant-full.log`，220 KB；§41 的同一夹具）：

```console
$ sed -i 's/\[7\] 死 pane 席位/[6] 死 pane 席位/' skills/teamsmith/scripts/lib/cmd-status.sh
$ bash skills/teamsmith/tests/smoke.sh > /tmp/p79-mutant-full.log 2>&1; echo rc=$?
rc=1

$ grep -n 'P55 ④：digest\|P79：' /tmp/p79-mutant-full.log
3198:  ✓ P55 ④：digest 点名死 pane 席位
3199:  ✓ P55 ④：digest 行带退出证据（任务未结束 = 异常）
3200:  ✓ P55 ④：digest 行带登记任务
3201:  ✗ P79：死 pane 段是 [7]，且只有段号变（正文逐字节同 P55）（…/p55-digest.log 中找不到 [[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）]）
3202:  ✗ P79：digest 段号逐行唯一（唯一豁免：历史 [5]×2）（期望 [5]，实际 [5 6]）
3203:  ✗ P79：段号按序 [1]–[7]、[5] 历史重复成对（期望 [1 2 3 4 5 5 6 7]，实际 [1 2 3 4 5 5 6 6]）

$ grep -n '== 结果 ==' /tmp/p79-mutant-full.log | tail -1
3323:== 结果 ==  ✓ 3075  ✗ 3
smoke 有失败项（--keep 保留现场）
```

P55 自己的三条 `④` 断言仍绿 —— 变异只打中 P79 的三条，证明断言打的是段号、不是内容。

还原（同一条 git 命令，交付树 `git status` 为空）：

```console
$ git checkout -- skills/teamsmith/scripts/lib/cmd-status.sh
$ grep -n '死 pane 席位（窗口是遗体' skills/teamsmith/scripts/lib/cmd-status.sh
1237:    … "[7] 死 pane 席位（窗口是遗体：现场可读；死 pane 不是投递目标，消息已换道收件箱）"; fi
$ git status --short          # → 空
$ bash -n skills/teamsmith/scripts/lib/cmd-status.sh && echo ok
ok
# 还原后探针再跑一遍：PASS（§4.2 绿侧那段就是还原之后的运行）
```

## 5. 验收命令（实际运行）

```console
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 27 passed, 0 failed (27 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # 尾部
== 结果 ==  ✓ 2430  ✗ 0
FAST 模式：跳过 32 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿

$ bash skills/teamsmith/tests/smoke.sh                           # 全量（交付 tip c12754ee，门禁锁排队后）
job p79-full-smoke finished exit=0 after 1786.9s
  ✓ P55 ⑤C·resume：…（§41 在跑，紧随其后的 §42 断言也在）
== 结果 ==  ✓ 3077  ✗ 0
smoke 全绿
```

计数说明：FAST 与本次开工前的基线逐字相同（`✓2430 ✗0`，新增断言不在 FAST 面）。全量两轮（本树 / 变异树）的断言总数是
`✓3077 ✗0` 与 `✓3075 ✗3`：**差异里 3 条是确定的红锚点**（§4.3）；两轮总数相差 1 是套件自身的动态项
（面板计时/负载断言在忙时会**可见跳过**，不计数 —— 见 protocol 的「排队与跳过」小节），与 P79 无关。

## 6. 边界与残留

- **判定语义零变化**：只换段号 + 加断言；死 pane 段的正文、触发条件、`!`/`·` 标记全未动。
- **[5]×2 保持**：见 §2.2，是历史现状且修复会连带改 B2 的 `[6]`；若 PM 要严格唯一，另开小任务。
- **无遗体时看不到 `[7]`**：这是既有条件渲染，不是缺陷；断言放在 §41（有遗体）就是为了让它可失败。
- **探针不入库**：`/tmp/p79-probe.sh` 及其输出是复现证据；跑完自回收（`trap` kill 私有 server + 删夹具），
  真项目 state/审计日志零写入（调用时剥掉 shim 与继承的全部 `TEAM_*`，夹具项目在 `/tmp`）。

Agent: dev
