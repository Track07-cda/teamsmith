# P82 · notify-sender-identity apply — 发送者按运行时目录解析，未解析 = 拒绝

agent: dev-bob   status: **done（等 PM 复验）**   time: 2026-09-22T23:3xZ
branch: `task/P82-sender-apply`（local 模式：分支留本地，不 push）   PR/MR: -

```
base:    0b223324（main，= 本地任务分支起点）
change:  notify-sender-identity（真源 = openspec/changes/notify-sender-identity/{design,tasks}.md，提案复审 ACCEPTED）
commits: 022d204f feat(P82): the notify sender is the runtime directory, and an unresolved sender is refused
         623ec396 test(P82): section 46 pins the sender resolution, the refusal and the three surfaces
         77fc4057 test(P82): flip-p72.sh — three CLI-side breakages redden section 46
         20975146 docs(P82): the attribution rule, the --from escape and the recommended adapter command
         9e630c00 test(P82): mutation (a) is a behaviour break (not a syntax break) + the report package and raw logs
         0a3da801 docs(P82): delivery report (PARTIAL + the three BLOCKED paths) and the refreshed evidence logs
         359e30e4 docs(P82): the report names the two one-line doc patches too (SKILL.md, team help)
         2a21e037 docs(P82): findings — the dispatch prompt's blocked branch notifies the worker itself
         8859cca2 feat(P82): an ambiguous summary source is refused (positional text + --from-file)
         b3e575b3 feat(P82): the notify extension derives the sender from the runtime directory too
         954539fc test(P82): the cross-path agreement fixture (3.1/3.2) and the extension mutation
         330f6cd5 docs(P82): SKILL.md's Collaborate row and team help name the --from escape
         653af581 docs(P82): all four batches landed — the report, the ticks and the refreshed evidence
         45938c82 docs(P82): the report's FAST tail carries the measured count (2627/0)
         a7f797ce docs(P82): the final gate tails (full 3293/0, 50 P82 assertions inside) and the refreshed red-before
         df6c03c6 docs(P82): the third grant is recorded as explicit (help line already landed) + the docs evidence
         （共 17 个提交；代码改动到 330f6cd5 为止，之后全是 docs/tasks/logs）

追加授权（PM 2026-09-22 的 say，分两次）：`extension/team-notify.ts` + `SKILL.md` commands 表 + flip-p72.sh 第四对变异；
随后第三条 `scripts/lib/cmd-project.sh` 的 `team notify` help 行也明确授权 —— 三处齐，均按报告 §BLOCKED 里备好的两个补丁落地。
```

## 结论

change 的四个批次全部落地，**两条路（[manual] CLI / [auto] 扩展）同源**，未解析一律拒绝：

- **解析**（一处规则，两处实现）：显式 `--from <名字>` ＞ 运行时目录（M40 身份：主工作树 → `pm`；
  `<main>/<TEAM_WORKTREES_DIR>/<name>` → 该目录名，**含子目录**；名册拼写优先）＞ **拒绝**（CLI 非 0 +
  零收件箱行 + 零 knock + 输出点名 `--from`；扩展**跳过并记日志**，绝不编一个发送者）。继承的
  `TEAM_AGENT` 绝不压过目录（分歧点名，目录赢）。
- **归属面**：同一名字进 durable 收件箱行、knock 文本、outbox 条目 `from:`；收件人仍然只是收件人
  （收件箱文件名 + 敲门目标）。
- **可证伪**：旧代码 + 新夹具 = 22 ✓/28 ✗（两条路各自的红都在）；本 tip 46 段 = **50 ✓/0 ✗**；
  `flip-p72.sh` 的**四对**变异各自点名红断言（13 ✓/0 ✗）。

## 硬要求逐条对照（任务书）

| # | 硬要求 | 状态 | 证据（可复跑） |
|---|---|---|---|
| 1 | 未解析 = 拒绝：非 0、零收件箱行、零 knock、点名 `--from`、绝不静默退回 `pm` | ✅ | 46 段 `P82 1.4`（四断言 + `cksum` 前后逐字节 + 队列 0 条）；flip 变异 b 把回落写回来 → 四条全红 |
| 2 | 运行时目录解析：主工作树 → `pm`；`.worktrees/<name>` → 目录名（含子目录） | ✅ | 46 段 `P82 1.2`（工作树根 / `<worktree>/docs` → `agent:dev2`；主工作树 → `agent:pm`） |
| 3 | `TEAM_AGENT` 不许压过；分歧在 stderr 点名 | ✅ | 46 段 `P82 1.3`；flip 变异 c 让继承值赢 → 两条全红 |
| 4 | 三处同名：收件箱行、knock 文本、outbox 条目 `from:` | ✅ | 46 段 `P82 1.5`（脏 PM 框夹具：`from: dev2` + payload `[manual] agent:dev2 · …`，零按键）；flip 变异 a → 三条全红 |
| 5 | 两条路同源（`[auto]` 与 `[manual]` 同一解析） | ✅ | 46 段 `P82 3.1/3.2`（**提取两行的 `agent:<名字>` token 比较**，不是子串计数；3.2 的窗口故意报 `dev`）；flip 变异 d → 恰好四条 3.2 断言红、3.1 保持绿 |
| 6 | 可证伪：worker → `agent:<worker>`（旧代码是 `agent:pm`）、主树 → `agent:pm`、无 worktree 且无 `--from` → 非 0 零写入 | ✅ | `logs/red-before-46.log`（旧树 + 新夹具 = 22 ✓/28 ✗，两条路各自的红都在）、`logs/green-probe-46.log`（50 ✓/0 ✗） |
| 7 | 零回归：`openspec validate` + FAST + 全量 smoke | ✅ | 见「门禁」 |

## change 映射（requirement → item → evidence）

| requirement（delta） | tasks items | 交付 | evidence |
|---|---|---|---|
| `notify-and-inbox#A manual notification is attributed to its sender, not its recipient`（ADDED，7 场景） | 1.1–1.6 | `common.sh`：`team_sender_from_dir` / `team_sender_resolve`；`cmd-agents.sh`：`team_cmd_notify` 的 `--from` 解析 + 三处归属 + `team_inbox_append` 可选 sender | 46 段 50 条断言；7 个场景逐条：worker→`dev2`（1.2）· PM→`pm`（1.2）· `TEAM_AGENT` 不压过（1.3）· 未解析拒绝（1.4）· `--from` 原样记录（1.1/1.5）· knock 与条目同名（1.5）· **两条路同名（3.1）** |
| `notify-and-inbox#A turn-end notification appends one inbox line and knocks once`（MODIFIED，新场景「The worktree, not the window, names the sender」） | 2.1、3.1、3.2 | `extension/team-notify.ts`：`senderFromDir()`（名册 `TEAM_AGENTS` 进 `Cfg`）+ `agent_settled` 的发送者推导 + 分歧日志 | 46 段 `3.1`（窗口 `dev2`）/`3.2`（窗口撒谎报 `dev`）+ 扩展包 `pkg/run-extension-package.sh`（S1–S4：headless 根、子目录、撒谎窗口、PM 窗口跳过；红 5 bad → 绿 0 bad） |

回归面（旧行为不变）：`team say` / `draft` / pulse 的收件箱行形状不变（不传第 4 参，回落到 owner 标签）；
扩展的守卫（cwd 在 worktrees 之下、非 PM 窗口、session 匹配）与「先写收件箱后敲门」的顺序不变；历史 55 行
`agent:pm` 不重写（design §5 前向修复，**本轮一行都没动**）。

## 翻转证据（每个断点：断掉 → 红 → 还原 → 绿）

`bash skills/teamsmith/tests/flip-p72.sh` → **✓ 13 ✗ 0**（`logs/green-flip-p72.log`）。变异只打 `/tmp` 下的技能树副本，
且每个变异先过两道「这真的是行为变异吗」的守卫：`bash -n`（shell）+ 扩展的 **import 检查**（TS，`bash -n` 覆盖不到）。

| 变异 | 断掉的是 | 红侧点名（节选，全文 `logs/red-flip-*.log`） | 结果 |
|---|---|---|---|
| a | 发送者退回**收件人**（收件箱行 / knock / 条目三处一起） | `P82 1.2 发送者 = 工作树目录名`（期望 `agent:dev2`，实际 `agent:pm`）· `P82 1.5 条目的 from: 是发送者` · `P82 1.6 dev 的收件箱里发送者仍是 worker` | 26 ✓/13 ✗ |
| b | 未解析的运行时目录**静默退回 pm**（缺陷本身） | `P82 1.4 …应当拒绝`（退出码 0）· `拒绝时零写入`（cksum 变了）· `拒绝输出点名 --from` | 35 ✓/4 ✗ |
| c | 继承的 `TEAM_AGENT` **压过**运行时目录 | `P82 1.3 发送者仍是运行时目录的 dev2`（实际 `agent:pm`）· `P82 1.3 stderr 点名被忽略的 TEAM_AGENT 值` | 37 ✓/2 ✗ |
| d | 扩展回到 `window || …`（**窗口**重新决定发送者） | `P82 3.2 窗口撒谎（报 dev）时 [auto] 这一路仍是 dev2`（实际写去了 `inbox/dev.md`）· `3.2 两条路在对抗性窗口下仍然同名` · `3.2 窗口名没有变成发送者（不存在 inbox/dev.md）` · `3.2 扩展日志点名被忽略的窗口` | 46 ✓/4 ✗（3.1 三条仍绿） |

**红→绿（交付前/交付后同一夹具）**：`logs/red-before-46.log` = 旧代码（base `0b223324` 的 `scripts/` **与** `extension/`）
+ 46 段夹具 → `✓ 22 ✗ 28`：CLI 那半写的是「期望 `agent:dev2`，实际 `agent:pm`」，扩展那半在撒谎窗口下写去了
`inbox/dev.md`（`3.2 窗口名没有变成发送者` 红）—— **两条路各自的红都在**；`logs/green-probe-46.log` = 本分支 tip
→ `✓ 50 ✗ 0`。46 段同时进 FAST 与全量门禁。

## 追加授权后的落地（原 §BLOCKED）

三条路径都按报告里备好的补丁落了，**补丁先在生产代码上重跑**：

| 路径 | 改动 | 复跑证据 |
|---|---|---|
| `skills/teamsmith/extension/team-notify.ts` | `pkg/extension-sender.patch`（`patch -p1 -d skills/teamsmith`）；`senderFromDir()` + `Cfg.roster` + 分歧日志；顺手把 helper 里 `roster.includes(seg) ? seg : seg` 的废话改成 `roster.find(...) ?? first` | `pkg/run-extension-package.sh` → **rc=0**（红侧 4 ok/5 bad：子目录记成 `docs`、窗口 `dev` 冒充发送者；绿侧 9 ok/0 bad；红侧 = **对交付的树反向应用同一个补丁**，所以它同时证明「补丁 ≡ 交付的改动」）＋ 46 段 3.1/3.2 |
| `skills/teamsmith/SKILL.md` | Collaborate 行加 `[--from <sender>]` + 一句归属规则（`pkg/docs-and-help.patch` 第一段） | 46 段 3.x + 文档一致性段落门禁全绿 |
| `skills/teamsmith/scripts/lib/cmd-project.sh`（`team help`） | notify 用法行加 `[--from <发送者>]`（同一补丁第二段；**PM 第三条授权明确点名了它**） | `bash -n` + `team help` 实测第 41 行 + 门禁 |

## 门禁（真跑过，原始日志在 `logs/`）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 30 passed, 0 failed (30 items)                                  # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2627  ✗ 0
FAST 模式：跳过 33 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿                                                              # rc=0

$ bash skills/teamsmith/tests/flip-p72.sh
== 结果 ==  ✓ 13  ✗ 0
flip-p72 翻转成立                                                        # rc=0

$ bash skills/teamsmith/tests/smoke.sh </dev/null
另一套全量 smoke 正在跑（2026-09-22T22:14:35+00:00 pid=2617076 cmd=smoke.sh）；本套排队，最多等 5400s
…（本套 22:14 提交、排到 23:08 才拿到锁 —— 同机 dev/dev2/dev3 三套全量在争；作业总时长 3802.8 s）
…  46 段在全量里同样是 50 ✓ / 0 ✗（无 FAST 跳过行 = 真进程段落全跑了）
== 结果 ==  ✓ 3293  ✗ 0
smoke 全绿                                                              # rc=0
```

额外跑过的（不是本任务门禁，但同树同 tip）：`perl skills/teamsmith/tests/tmux-lint.pl` → 红 0 条（我的夹具只写假
tmux，不碰真 server）；`openspec validate --all --strict` 在**最终 tip**（含 tasks 勾选与报告提交）上又跑了一遍
（30/30，`logs/green-openspec-validate.log`）；文档证据 = `logs/green-docs-evidence.log`（tasks 4.2 的三条 grep：
SKILL.md、references/*、help 行；所有 adapter 配方都带 `--from`）。

## 决定与偏差

1. **`TEAM_AGENT` 只在「按目录解析」这条路上被检查**：显式 `--from` 是更强的声明，此时不拿 `TEAM_AGENT` 去比
   （规范只要求「不许压过**运行时目录**」）。
2. **`--from` 的名字不许含空白**（新守卫，`team_usage_die`）：名字里有空白会把 `agent:<名字> ·` 折成两行、污染
   durable 账本；空名字同样拒绝。
3. **`--from=`/`--from-file=` 等号形式**也接受；未知 `-*` 参数报 usage（以前会被当成摘要正文静默吞掉）。位置摘要与
   `--from-file` **同时给 → usage 拒绝**（摘要只有一个来源，不静默挑一个）。
4. **扩展的「未解析」是跳过 + 记日志，不是非 0**：扩展跑在 agent 会话里，任何失败都不能影响会话（既有契约：
   「通知绝不能影响 agent 会话」）；CLI 那条路才是 fail-closed 的拒绝。两条路的**判定规则**同源，**失败姿态**按
   各自的契约不同 —— design §2/§4 没有要求扩展非 0，46 段钉住的是「不编造、不误标」。
5. **dedup 键仍按收件人**（`team_notify_dedup_key "$agent" "$msg"`，未改）：同文、不同发送者、20s 内仍会互相抑制
   **knock**（durable 收件箱行各自照写）。规范没要求改它，保持最小面；若 PM 认为该按发送者分键，一行的事。
6. **`team --root <main> notify …` 仍解析成 `pm`**（显式位置覆盖，design §5 的既定语义；扩展的 knock 走的是
   `outbox enqueue --from`，不经此路）。
7. 夹具的假 tmux 用**文件**拿窗口名：实测 `bun` 的 `execFileSync` 不把运行期 `process.env` 改动传给子进程（node 会），
   按环境变量写会在 bun 下假绿（扩展自带 smoke 夹具的历史形状不受影响——它们的 env 在进程启动前就设好了）。
8. 扩展的 `roster` 与「名册优先」在语义上是**等价增强**：worktree 的一级目录名本来就等于名册席位名，名册匹配只是
   给非席位目录（`review-<ID>`）留出「照目录名记」的出口；注释里写明了，没有把它说成额外的保险。
9. **`references/protocol.md` 没加规则句**：tasks 4.2 点了三个 references 文件，我在 `agent-adapters.md` 写了完整的
   一段（规则 / `--from` 出路 / 拒绝），`troubleshooting.md` 的车道行与 `config.md` 的键行各一句；`protocol.md:71`
   只有一句流程里的 `team notify <agent> "…"` 提法（不是 adapter 配方，且 worker 在窗口里跑会自动解析正确）。
   要不要逐文件都写规则句，等 PM/verify 一句话；补上就是一行 + 重跑门禁。

## Findings（不在本变更路径上，交给 PM 排期）

1. **派单提示词的 BLOCKED 分支把「给 PM 发消息」渲染成了给自己发**：`cmd-agents.sh` 的提示词模板（约 166 行）写的是
   `notify the PM with … $cli notify $agent "<one line>"`，而 `$agent` 是**被派的 worker** —— 我这次收到的提示词就是
   `/…/team notify dev-bob "<one line>"`（等于让自己给自己发）。照做会写出 `inbox/dev-bob.md` 而 PM 永远看不到。
   应该是 `$cli notify pm …`（本任务未改：它不属于 change 的 delta，改它需要你排期）。
2. **`TEAM_AGENT` 语义的双重身份**（本任务只做了防守）：adapters 侧它是「窗口/席位」标签，而 CLI 侧从来没有设过它；
   本轮只保证「不许压过运行时目录」。若将来真的要用它当身份，需要 delta 明确优先级。

## 交付物

| Path | 内容 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | `team_sender_from_dir` / `team_sender_resolve`（M40 身份 + `--from` + `TEAM_AGENT` 守卫 + 拒绝语义） |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | `team_cmd_notify`：参数解析（`--from`/`--from-file`/`--any`）、sender 先解析（fail closed）、三处归属、含糊输入拒绝；`team_inbox_append` 第 4 参可选 |
| `skills/teamsmith/extension/team-notify.ts` | `senderFromDir()` + `Cfg.roster` + `agent_settled` 的运行时目录推导与分歧日志（窗口不再是发送者） |
| `skills/teamsmith/tests/smoke.sh` | 新增 46 段（50 条断言：1.1–1.6 全场景 + 脏框队列条目 + 含糊输入拒绝 + 3.1/3.2 两条路同名） |
| `skills/teamsmith/tests/flip-p72.sh` | 四对变异 + `bash -n`/TS import 双守卫 + 基线自检（✓ 13 ✗ 0） |
| `skills/teamsmith/references/{agent-adapters,config,troubleshooting}.md` | 归属规则一句 + 推荐 adapter 命令改为 `--from {agent}` |
| `skills/teamsmith/SKILL.md` · `scripts/lib/cmd-project.sh` | Collaborate 行 / `team help` 的 notify 用法（追加授权后） |
| `openspec/changes/notify-sender-identity/tasks.md` | 勾选 1.1–1.6 / 2.1 / 3.1–3.2 / 4.1–4.3 / 5.1–5.4（6.1 归 verify 席位） |
| `docs/team/reports/P82-dev-bob/pkg/` | `extension-sender.patch`（已落地）· `ext-identity.mjs` · `run-extension-package.sh`（扩展夹具）· `docs-and-help.patch`（已落地） |
| `docs/team/reports/P82-dev-bob/logs/` | `red-before-46` / `green-probe-46` / `green-fast-smoke` / `green-full-smoke` / `green-flip-p72` / `red-flip-{a,b,c,d}` / `green-extension-package` / `green-openspec-validate` |

## 建议的下一步（PM）

1. 交 **verify 席位**（tasks 6.1）：在独立 checkout 上重跑 `openspec validate`、全量门禁、`flip-p72.sh`，把 3.1/3.2 的
   两条路对断言与「未解析的运行时目录零写入」逐条复核（本轮的红侧基线 `logs/red-before-46.log` 可直接当红侧素材）。
2. 若同意 Findings 1（派单提示词的 BLOCKED 分支），它值得单独一个任务：worker 现在照提示词做会联系不到 PM。
