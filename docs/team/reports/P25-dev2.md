# P25 · 收件箱投递：假缩容、重扫与过期唤醒（propose）

agent: dev2   status: **DONE**（propose 阶段只出规划产物；未改任何实现文件）
time: 2026-09-20T10:25:00Z
branch: `task/P25-propose`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev2`）

change: `inbox-spool-resilience`（本任务即 propose 阶段；apply 等 PM 的
`docs/team/reviews/inbox-spool-resilience-proposal.md` 判定 ACCEPTED）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/inbox-spool-resilience/proposal.md` | Why / What / Capabilities / Impact / 验收 / 翻转 / 边界 / 报告证据（494 词） |
| `openspec/changes/inbox-spool-resilience/specs/notify-and-inbox/spec.md` | **ADDED ×4**：字节真实偏移 / 缩容需证据且收敛 / 过期行不唤醒 / 账本区分新增与恢复；12 个 scenario |
| `openspec/changes/inbox-spool-resilience/design.md` | 事故实测（账本行 + `.seen` 字节 + `cut` 复现）、根因链、与 PM 判断的差异、D1–D8、阈值表、夹具计划、风险与替代方案 |
| `openspec/changes/inbox-spool-resilience/tasks.md` | B1…B5 分批（读者 / 缩容证据 / 过期门 / 账本与文档 / 翻转包与门禁），覆盖表与路径授权 |
| `docs/team/reports/P25-dev2/probe-p25-red.mjs` | 证据脚本：在**当前树**上复现「假缩容 + 循环 + 过期唤醒」与 ASCII 对照组（独立临时仓库，不碰本仓） |
| 提交 | `9b2b905`（proposal）、`b758823`（delta）、`7e8b0c9`（design）、`6d59511`（tasks） |

## 根因链（复核后；证据全部来自本仓只读账本/状态）

**① 生产者**：`team_inbox_watch_deliver`（`scripts/lib/outbox.sh:1017`）用 `LC_ALL=C cut -c1-700` 裁预览，
`cut -c` 在该主机（GNU coreutils 9.10）按**字节**裁，落在多字节字符中间就留下半个字符 —— spool 行可以不是
合法 UTF-8（durable 收件箱行是全文，不受影响）。实测复现：`b'xy' + '红'*300` 裁到 700 字节 = 「698 字节 +
半个 3 字节字符（2 字节）」，解码后 **701 字节 + 恰好 1 个 U+FFFD**。

**② 读者**：`readNewLines()`（`extension/team-inbox-watch.ts:351`）把新 offset 算成
`Buffer.byteLength(text.slice(0, end + 1), 'utf8')` —— 一次「解码 → 再编码」，不是实际读到的字节数。
每个非法字节变成 U+FFFD（3 字节）→ 计数 **大于** 物理字节。于是 `baselineOffset()` = `size + 1`，
`offset ≤ size` 这个不变量在**启动时**就被破坏，并且只要文件字节不变，这个偏差是**确定性的、稳定的**。
2026-09-20 账本里的 19635 vs 19634 就是这么来的；`.seen` 里 `1789837182057 knock pm pm …`（写于
2026-09-19T16:59:42.057Z，M40 的手工 knock）预览解码 701 字节、恰好 1 个 U+FFFD，全文件只此一处 —— 加上
它正好 +1。

**③ 循环**：`flush()`（:558）看到 `size < offset` 就按「外部截断/重写」调 `rescan()`；`rescan()`（:544）
用同一套算法重算出同一个偏大的 offset → 下一拍继续 `size < offset`。没有计数、没有收敛条件、不区分
「文件被动过」与「我们自己的 offset 算错了」。5 秒轮询把它变成每 5 秒一对账本行（06:42:44→06:44:14），
直到 PM 手工清空 spool。

**④ 过期唤醒**：`rescan()` 从 0 重读、**完全绕过**启动基线（S5 的「启动前的行不唤醒」），它唯一的
新鲜度判据是 `.seen`（「最近 512 次投递里有没有这一行」），不是「这一行多久前写的」。那 66 行
`dup=0` —— 从没投递过，于是全是「新行」；重放上限 20 把它切成四批（20/20/20/6，06:42:44–06:42:59），
把 1 小时到 1.5 天前的 backlog 叫醒成四条「新消息」。

**⑤ 与 2026-09-19T16:59（M43 现场）的关系**：那次的 invalid 预览行写于 16:59:42.057Z，第一次 42 行重放落在
16:59:43.940Z —— 相隔 1.9 秒；M43 之前的代码在 `size < offset` 时静默 `offset = 0`，用同一份偏斜就能复现它。
也就是说「有外部力量截断文件」这个前提对那次事故**不是必需的**（可能就是读者自己的算术）。本 change 不移除
M43 对**真实**截断/重写的响应（S11–S13 与 smoke 引脚必须保持绿），只是拿掉它的假触发器。

**⑥ 与 PM 初步判断不同的一条（有证据）**：brief 说 offset 是「按缓冲区长度推进，而不是按 `readSync`
实际读到的字节数」。**效果判断对，机制判断不同**：真实机制是按**解码后再编码的长度**推进 —— 既不是
`buf.length`，也不是 `bytesRead`；它不需要并发写、也不需要短读，静态文件 + 一行裁剪预览就能确定性复现
（所以基线在一拍都没走之前就已经错了）。忽略 `readSync` 返回值是**另一条**真实但潜伏的缺陷（短读会留下
NUL 填充，`lastIndexOf('\n')` 落在有效前缀里 → 效果是**少读**、靠去重兜住），design §2.2 把它连同一并修，
但它不是这次事故的根因。

**⑦ 不是根因的**（都查过）：`.seen` 的 512 上限与格式（66 行从没进过它）；`trimSpool` 的 128KB 上限
（文件才 19KB）；`fs.watch` 不可用（轮询兜底照跑）；进程内并发（读路径同步，一拍内不会交错）。

## Verification evidence（实跑输出）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/inbox-spool-resilience
…（共 15 项）
Totals: 15 passed, 0 failed (15 items)                        # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
  ✓ 12b-pi 扩展夹具全绿（runner=<home>/.bun/bin/bun，75 条用例）
== 结果 ==  ✓ 1876  ✗ 0
FAST 模式：跳过 24 个真进程段落（… 完整门禁请不带 TEAM_SMOKE_FAST 重跑）
smoke 全绿                                                    # rc=0（未改测试与实现，跑的是既有门禁）

# 试归档（草稿副本，不碰本仓；证 ADDED-only 的 delta 能被后续增量叠加）
$ rm -rf /tmp/p25-trial && mkdir -p /tmp/p25-trial && cp -r openspec /tmp/p25-trial/ \
  && (cd /tmp/p25-trial && PATH="$HOME/.bun/bin:$PATH" openspec archive -y inbox-spool-resilience)
Specs to update:
  notify-and-inbox: update
  + 4 added
Totals: + 4, ~ 0, - 0, → 0
Change 'inbox-spool-resilience' archived as '2026-09-20-inbox-spool-resilience'   # rc=0
# 归档后 notify-and-inbox 仍是原有 6 条 + 新增 4 条，无一条被改写/删除

$ git status --porcelain
（空输出）                                                     # 工作树干净
```

## Flip evidence

**Red before（当前 HEAD、未改实现；`docs/team/reports/P25-dev2/probe-p25-red.mjs`，自己的临时仓库）**：

```
$ ~/.bun/bin/bun docs/team/reports/P25-dev2/probe-p25-red.mjs \
    "$PWD/skills/teamsmith/extension/team-inbox-watch.ts" clipped
mode=clipped spool_size=956
started: … baseline=957                                  # ← size + 1（假缩容的源头）
shrink_lines=5 rescan_lines=5 wakes=1                     # ← 900ms 内 5 对 shrink+rescan（循环）
ledger: … spool shrink: size fell below offset=957 inbox=pm → bounded rescan from 0（外部截断/重写；仓内只有追加写）
ledger: … rescan lines=6 dup=0 skipped=0 deliver=6 total=0 inbox=pm
ledger: … wake n=6 total=6 inbox=pm kinds=knock,…        # ← 6 条 24 小时前的 backlog 被叫醒
wake: … - [knock] from pm :: stale backlog line 1 | - [knock] from pm :: stale backlog line 2

$ … probe-p25-red.mjs … valid                            # 对照组：同样的 6 行、预览是纯 ASCII
mode=valid spool_size=275
started: … baseline=275                                  # ← size 相等：没有假缩容
shrink_lines=0 rescan_lines=0 wakes=0                     # ← 零移动、零唤醒
```

对照组钉住机制：唯一差别就是那一行预览是否在字符中间被裁 → 偏斜、循环、过期唤醒同时出现/同时消失。

**Green after（apply 阶段的翻转包，已规划、尚未实现）**：`tests/flip-p25.sh` 三棵树 —— 红树（`TEAM_FLIP_BASE`）
必须复现 S18 的 `baseline=size+1` 与重复 `spool shrink`；绿树（未来实现）S18–S21 全绿；变异 A（恢复
`Buffer.byteLength(decoded)` 推进）→ S18 红、变异 B（A + 去掉 clamp/repeat 守卫）→ 循环回来、变异 C（一律
clamp 不 rescan）→ S19b 红。**propose 阶段没有实现，因此没有绿树输出可给** —— 这一条是 apply 的验收义务，
写进了 tasks.md 的 B1/B2/B3/B5。

## Isolation evidence

- probe 自己 `git init` 一个 `/tmp` 临时仓库（`TEAM_ROOT`/target/轮询间隔全部显式覆盖），从不写
  `.worktrees/dev2` 或主工作树的 `state/`、`docs/team/inbox/**`。
- 证据读数（`.seen`/账本）全部**只读**；未执行任何会改变仓库或 tmux 状态的命令。

## Decisions and deviations

- **规格的家 = ADDED（不是 MODIFIED）**：`grep -rn 'spool\|wake\|inbox-watch' openspec/specs/` 在
  `notify-and-inbox` 里一条都匹配不到 —— watch/spool 通道今天**没有 requirement**（M30/M43/M46 的行为只活在
  references 与测试里）。ADDED-only 既不改写既有 6 条，也让 P27（backfill）可以独立往同一份文件加自己的
  requirement（试归档实测 +4/~0/-0）。
- **账本字段顺序刻意兼容 M43**：rescan 行保留 `lines= dup= skipped= deliver=` 前缀，新计数（`stale=`
  `unparsable=`）**追加在后面** —— flip-m43 的 S12/S13 正则与 smoke 引脚一字不用改（tasks.md 4.3 要实跑两
  个既有 flip 包证明）。
- **clamp 只向前（`offset := size`）**：回退到上一个行首会跨回基线之前的内容、把 S5 故意静默的行重新投递；
  半个行的读取由「起点在一行中间就跳到下一个 `\n`」吸收。
- **阈值**：`TEAM_INBOX_WATCH_CLAMP_BYTES`（默认 64）、`TEAM_INBOX_WATCH_STALE_SEC`（默认 900）；沿用扩展
  既有的 `process.env` 读取方式（扩展 source 不了项目配置），不动 `templates/config.sh.tmpl` /
  `references/config.md`。风险（同头小改写会被 clamp 掉、过期阈值可能压掉一次迟到的唤醒）都在 design §6
  具名写出，没有藏。
- **未做**：不改唤醒通道（`fs.watch`+`sendMessage`）、不改 outbox 写入路径、不改 `.seen` 格式、不写实现。
- **边界外的 PM 待办（不阻塞）**：`outbox.sh:1017` 的字节裁剪会把 U+FFFD 带进预览（wake 文本上只是观感问题，
  durable 收件箱是全文）。建议 PM 后续单独处理（字符边界裁剪）；本 change 不碰 `scripts/**`。
- **`.seen` 的一条证据边界**：06:42:39 时 `.seen` 只有 13 行，而上一个会话记了 `total=118`；仅凭日志无法
  重建它的历史。这不影响结论（`dup=0` 证明 66 行从未投递过），写在这里而不是替它编一个解释。
- **无 BLOCKED**。

## Suggested next steps

1. PM 按 `references/openspec.md` §4 的八点清单出 `docs/team/reviews/inbox-spool-resilience-proposal.md`；
   ACCEPTED 后再派 apply（B1→B5，B1–B4 每批一个 brief）。
2. apply brief 明授 `skills/teamsmith/extension/**`、`skills/teamsmith/tests/**`、
   `skills/teamsmith/references/**`（后两个/一个是 PM 目录）；`scripts/**` 不授权。
3. P27（backfill）若先落地，同一份 `notify-and-inbox` delta 按 ADDED 叠加即可（试归档已证）。
