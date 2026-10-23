# P373 · 六条「从没被改坏过」的红侧

agent: dev · phase: apply · category: code · change: `turn-notice-in-pm-inbox` · deltas: `-`
branch: `task/P373-missing-red-sides` · time: 2026-10-23T09:45:00Z · 交付

## 结论（先回答任务书）

**六件里五件真的能红，第六件根本没有断言可红 —— 那就是这一件的结论，不是我的缺口。**

| # | 清单项 | 改坏什么 | 结果 |
|---|---|---|---|
| 1 | `turn-notice` 1.1.2 | 让同 run 的三个事件各起一行 | **红**：`--select 13` rc=1，`FAIL: F17 同 run 的三条简报应当合成一行 ×3（实际 3 行：…）` |
| 2① | `turn-notice` 1.4.3 | 把 `__notify-settle` 从 dispatcher 删掉 | **红**：help-surface `coverage` rc=1，`✗ 内部入口清单：声明清单里的 __notify-settle 已经不是 dispatcher 的 __ 标签` |
| 2② | `turn-notice` 1.4.3 | 把指针写失败吞掉（只读 `pm.md` 也报 ok） | **红**：`--select 7` rc=1，五条 `pointer=failed` 断言（§3） |
| 3a | `turn-notice` 1.5.3 R1 | 删掉扩展里那一次 `__notify-settle` 调用 | **红**：`--select 13` rc=1，`FAIL: P364 指针行：pm.md 应为 1 行（实际 0）` |
| 3b | `turn-notice` 1.5.3 R8 | 拿掉「并进既有 run」那一支的指针写入 | **红**：`--select 13` rc=1，`FAIL: P364 指针行没合并成 ×3（…knock=skipped:no-pane · see=…）` |
| 4 | `turn-notice` 1.7.2 R12 | 回到「按文件席位取记录」 | **红**：`--select 7` rc=1，三条 R12 断言，`--detail` 真的报出缺口（§5） |
| 5 | `notice-fulltext` 4.5 | 删死默认（**真实改动，走提交**） | 绿：`--select 13` ✓、`--select 33` ✓；`config set 300` 仍生效 |
| 6 | `notice-fulltext` 4.6 R8 | 文案改回「降低它就能降噪」 | **绿 —— 无门禁承接**：`--select 14b,18` rc=0 ✓75 ✗0，没有任何断言读那句话（§7） |

第 6 件的期望（「§14b/§18 的文案不撒谎断言必须红」）在盘上不成立：那几条断言**不存在**，所以它无法被改坏、也无法被还原。
`notice-fulltext-and-asks/tasks.md` 的 4.6 自己写了这条退路（「若没有承接断言，就在报告里写明『无门禁承接』并给出 4.2 的
手工读证」），`design.md` §8 也只点名了三处要改的文案（`config.md`、`troubleshooting.md`、面板标签），没有承诺任何门禁去守措辞。
我按那条退路交付，**没有**顺手加一条新断言：那会是一条只关于我们自己文档措辞的守卫，与「净零守卫」的纪律相抵，是否要加应由你裁定。

**可以由你勾的清单项**：`turn-notice` 的 `1.1.2`、`1.4.3`、`1.5.3`（R1 与 R8 两半都实测了）、`1.7.2`；`notice-fulltext` 的
`4.5`。`4.6` 只能按上述退路勾（勾的时候在行内写「无门禁承接 + 4.2 的手工读证」），或者由你决定另开一件补断言。**我一条都没勾。**

产品代码只动了一行（第 5 件）：提交 `90c50e5e`。其余五件的改坏全部发生在 `/var/tmp/p373-mut/base` 这个私有克隆里，
收尾时 `git status --porcelain` 为 0 行、停在 `90c50e5e`。

## 0 · 红侧怎么做的（可复核）

```bash
git clone --branch task/P373-missing-red-sides <主检出> /var/tmp/p373-mut/base
# 每件的改坏 = python 精确串替换（先断言"恰好命中 1 处"，否则拒绝并退出 3）；还原 = git checkout -- <file>
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select <段>     # 每件：改坏→跑→还原→再跑
```

- **私有克隆而不是主检出**：任务书要求红侧不改 main 的产品代码。收尾时克隆 `0 dirty`，主检出只有 `90c50e5e` 这一个提交。
- **`TEAM_SMOKE_FAST=1`**：这是 `#2012` 允许的「批次内用快模式」；本套只跑纯逻辑段，用私有锁、不排在全量套件后面。
  它不会让断言变少 —— 判据是「该段仍真的跑了」：`--select 13` 在快模式与全模式都是 `✓67 ✗0`（全模式那次见
  `/var/tmp/p373-mut/logs/13-base.log`，快模式见 `item5-live.log`），§7 与 §13 的正文里都没有 `FAST`/`skipped` 分支
  （`sed -n '5020,5329p'`、`sed -n '7846,8142p'` 各 `grep -c FAST` = 0）。
- 全量日志在 `/var/tmp/p373-mut/logs/`，逐件的紧凑记录在 `TRANSCRIPT.txt`；改坏的 `git diff` 也在里面。

## 1 · 第 1 件 · 同 run 的三条事件各起一行（1.1.2）

- 改坏点：`skills/teamsmith/scripts/lib/cmd-agents.sh:1995-1996`，`team_inbox_merge_or_append` 的尾行锚比对
  `… = "$key"` 改成 `… = "__p373-never"`，同 run 永不合并（记录行与指针行共用这一段）。
- 红（`logs/item1-mutant.log`，`--select 13` rc=1，结果行 `✓ 66 ✗ 1`）：

```
  ✗ 扩展测试失败（runner=node）
FAIL: F17 同 run 的三条简报应当合成一行 ×3（实际 3 行：- 2026-10-23T09:27:55.780Z [auto] agent:dev · unknown · branch=HEAD · uncommitted=0 · unpushed=2(no-upstream) :: All gates are green. I delivered the parser fix; the remaining work on this branch is the retry path.）
```

- 还原后绿（`logs/item1-restored.log`）：`== 选段结果 ==  ✓ 67  ✗ 0`。
- 一句边界：夹具在 F17 的第一条守卫（`exit 20`，一行 ×3）就退出，所以同一个块里「`notify.log` 三条」那条**没有走到**；
  指针行的 ×3 守卫由第 3b 件的红单独点名（`FAIL: P364 指针行没合并成 ×3`），不是靠这一件推出来的。

## 2 · 第 2 件 · 内部入口清单与 `pointer=failed`

**① 把 `__notify-settle` 从 dispatcher 删掉**（改坏点 `skills/teamsmith/scripts/team:105`，整行删除）

```
$ bash skills/teamsmith/tests/help-surface.sh --select coverage     → rc=1
  ✗ 内部入口清单：声明清单里的 __notify-settle 已经不是 dispatcher 的 __ 标签
== 结果 ==  ✓ 14  ✗ 1  SKIP 0
还原后：rc=0   ✓ 内部入口清单与 dispatcher 的 __ 标签双向相等（3 个）
```

**② 把指针写失败吞掉**（改坏点 `cmd-agents.sh:2127`：`elif team_inbox_write_pointer_line "$pointer_line" || true; then`
—— 只读 `pm.md` 也报 `pointer=ok`）

红（`logs/item2b-mutant.log`，`--select 7` rc=1，`✓ 171 ✗ 5`）—— 五条各自点名，不是一条熄灭后面全塌：

```
  ✗ R10：指针写失败被点名（pointer=failed）（…/p364-s3.log 中找不到 [pointer=failed]）
  ✗ P365/R10：指针写失败被点名（…/p365-s6.log 中找不到 [pointer=failed]）
  ✗ P365/R10：先指针后账本 —— 账行带得上 pointer=failed（…/notify-knock.log 中找不到 [task=P367 · class=delivered · outcome=enqueued · pointer=failed]）
  ✗ P365：指针缺失从账本当前代读出并点名文件（…/p365-digest2.log 中找不到 [指针缺失 1 条通知没有写进 PM 收件箱（pointer-write-failed；state/notify-knock.log 当前代，更早的代不计）]）
  ✗ P365/R9：指针缺失仍然在（账本不随 ack 变）（…/p365-digest3.log 中找不到 [指针缺失 1 条通知没有写进 PM 收件箱]）
```

还原后绿：`✓ 176 ✗ 0`（`logs/item2b-restored.log`）。注意 `R10：指针写失败时 pm.md 一行没多` 这一条在改坏时**仍然绿**——
它守的是「不谎报落盘」，而吞掉失败的实现恰好也确实没写进只读文件；这五条红才是它的对应面。

## 3 · 第 3 件 · 「那一次 settle 调用」与「某个分支的指针写入」（1.5.3 R1/R8）

**R1（删掉扩展里那一次 `__notify-settle` 调用）** —— 改坏点 `skills/teamsmith/extension/team-notify.ts:593`，
`settleSkipped` 体首插入 `return`（CLI 调用不再发生）：

```
红（--select 13 rc=1，✓66 ✗1）：FAIL: P364 指针行：pm.md 应为 1 行（实际 0）
还原后：✓ 67 ✗ 0
```

**R8（拿掉「并进既有 run」那一支的指针写入）** —— 改坏点 `team-notify.ts:670`，删除
`settleSkipped(writeState === 'extended' ? 'skipped:merged' : 'skipped:write-failed', …)`：

```
红（--select 13 rc=1，✓66 ✗1）：FAIL: P364 指针行没合并成 ×3（- 2026-10-23T09:32:22.057Z [auto] agent:dev · unknown · knock=skipped:no-pane · see=docs/team/inbox/dev.md）
还原后：✓ 67 ✗ 0
```

两次红各自对应一条断言，不是同一个守卫的两次读数：R1 的红是「一行都没有」，R8 的红是「有行但没合并」。

## 4 · 第 4 件 · `--detail` 回到「按文件席位取记录」（1.7.2 R12）

- 改坏点：`skills/teamsmith/scripts/lib/cmd-status.sh:1231`，`count="${KC["$k"]:-0}"` 换成按文件席位（`$agent`）数记录。
- 红（`logs/item4-mutant.log`，`--select 7` rc=1，`✓ 173 ✗ 3`）—— 任务书预言的那个缺口真的出现了：

```
  ✗ R12：team inbox pm --detail 退出码 0（×N 指针行不是缺口）（期望 [0]，实际 [1]）
  ✗ R12：指针行的 ×2 按自己的键对账（agent:dev · delivered）（…/p364-detail-pm.log 中找不到 [记录 2/2 OK]）
  ✗ R12：指针行不报缺口（不该出现 [缺口]）
```

- 还原后绿：`✓ 176 ✗ 0`。这条红的分量在于它同时动了退出码：`--detail` 从 0 变 1，也就是 PM 的读账命令在假缺口上失败。

## 5 · 第 5 件 · 死默认（4.5）：真实改动

提交 `90c50e5e` 删掉 `skills/teamsmith/scripts/lib/common.sh:1125`（改动前那一行
`TEAM_INBOX_MAX_CHARS="${TEAM_INBOX_MAX_CHARS:-150}"`）。它是**死默认**的证据留在提交说明里，这里只列读数：

```
$ grep -rn INBOX_MAX_CHARS skills/teamsmith --include='*.sh' --include=team    # 删后只剩 2 处，都不是读者
skills/teamsmith/scripts/lib/cmd-config.sh:129   ← schema 行（写进项目契约的默认值）
skills/teamsmith/scripts/lib/cmd-config.sh:270   ← TEAM_CONFIG_FLAT_KEYS（把契约里的值摊给 shell，来源是契约不是常量）
$ grep -c INBOX_MAX_CHARS skills/teamsmith/scripts/lib/common.sh → 0
```

删后仍生效（`/var/tmp/p373-mut/logs/item5-*.log`，夹具仓库里真跑的 CLI）：

```
$ team config set TEAM_INBOX_MAX_CHARS 300        → rc=0
$ grep -n INBOX_MAX_CHARS .pi/team/config.sh      → 100:TEAM_INBOX_MAX_CHARS='300'   # preview only: …
$ team config list | grep INBOX_MAX_CHARS         → TEAM_INBOX_MAX_CHARS   apply   int   300
```

读它的仍然只有扩展（`extension/team-notify.ts:279` 的 `pick('TEAM_INBOX_MAX_CHARS')`，它直接解析 `.pi/team/config.sh`）。

段证据：`--select 13` → `✓ 67 ✗ 0`（rc=0，`logs/item5-live.log`）；删除落在配置装载面上，所以补跑
`--select 33`（项目契约的读写面）→ rc=0，段内 `== 结果 ==  ✓ 331  ✗ 0`（`logs/item5-33-config.log`，190s）。

## 6 · 第 6 件 · 文案不撒谎（4.6 R8）：没有断言可红

- 改坏点：`skills/teamsmith/references/troubleshooting.md:300-308`，把 4.2 改回改动前的两句
  （恢复 `lower the volume with \`TEAM_INBOX_MAX_CHARS\``，并删掉「它只缩短预览」那一段）—— 这正是 `1b2840a9` 之前的原文。
- 结果：`--select 14b,18` **rc=0**，`✓ 75 ✗ 0`（`logs/item6-mutant.log`）。§14b 的判据是已删命令（`team merge|pr|gh|gl`），
  §18 的判据是英文正文/安装器入口/依赖收窄 —— 两句都不在它们的判据面上，改回来没有任何东西响。
- 手工读证（若你要按退路勾）：`docs/team/inbox/<seat>.md` 与 `state/notify.log` 存的是全文（变更前 §13 的 P370 ① 断言：
  4087 B 的消息逐字节全存，`--select 13` 绿即证）；`TEAM_INBOX_MAX_CHARS` 只影响敲门载荷里的预览（`team-notify.ts:719-720`
  `last.slice(0, cfg.maxChars - 1)`）。所以「降低它就能降噪」今天是假话，而**今天没有任何门禁说它假**。
- 我没有加断言：`turn-notice` 这类措辞守卫不在本任务书的写集里，且「净零守卫」要求新守卫换掉一条旧守卫 —— 是否补、补在哪，
  由你裁定。

## 7 · 验收命令与它们的输出尾巴

```
$ PATH="$HOME/.bun/install/global/node_modules/.bin:$PATH" openspec validate --all --strict
Totals: 23 passed, 0 failed (23 items)                     → rc=0
```

逐件的段运行汇总（全部 `TEAM_SMOKE_FAST=1` + `--select`，日志在 `/var/tmp/p373-mut/logs/`）：

| 运行 | 段 | rc | 结果行 |
|---|---|---|---|
| `item1-mutant` / `item1-restored` | 13 | 1 / 0 | ✓66 ✗1 / ✓67 ✗0 |
| help-surface `coverage` mutant / restored | coverage | 1 / 0 | ✓14 ✗1 / 全绿 |
| `item2b-mutant` / `item2b-restored` | 7 | 1 / 0 | ✓171 ✗5 / ✓176 ✗0 |
| `item3a-mutant` / `item3a-restored` | 13 | 1 / 0 | ✓66 ✗1 / ✓67 ✗0 |
| `item3b-mutant` / `item3b-restored` | 13 | 1 / 0 | ✓66 ✗1 / ✓67 ✗0 |
| `item4-mutant` / `item4-restored` | 7 | 1 / 0 | ✓173 ✗3 / ✓176 ✗0 |
| `item5-live` | 13 | 0 | ✓67 ✗0 |
| `item5-33-config` | 33 | 0 | 段内 ✓331 ✗0 |
| `item6-mutant` | 14b,18 | 0 | ✓75 ✗0（无承接断言） |

## 8 · 边界与遗留

- **没跑整套门禁**：本任务书没有要求，且 `90c50e5e` 只删一行、落点已被 §13 与 §33 覆盖；整套留给复验/合并那一次（`#2012`）。
  本节只声明「这次没跑的段」：除上表点名的 13 / 7 / 33 / 14b / 18 与 help-surface 的 coverage 组，其余段一个都没跑。
- **私有克隆留在盘上**（`/var/tmp/p373-mut/`：克隆 + 驱动脚本 `drive.sh` + 全量日志），方便你或复验方复跑；我没有清理别的目录。
- **一处判据面的观察，供你判断是否另开一件**：第 2 件的改坏证明 R10 那一组里「指针写失败时 pm.md 一行没多」在吞掉失败的实现下
  仍然绿 —— 它守的是另一半（不谎报落盘）。这不是缺陷，只是提醒：这两条断言必须成对存在，单独一条都拦不住那个 bug。
