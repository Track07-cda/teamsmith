# turn-notice-merge · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每项都留下可复跑的夹具与其红侧）；**verify** 由**另一个**
席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与两组红侧。本文件不是规格；
合同文本在 `specs/notify-and-inbox/spec.md` 的 delta 里，逐条 MODIFIED 不得丢基线场景（基线 16 条）。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案评审 `docs/team/reviews/turn-notice-merge-proposal.md`，确认三个裁定点（尾行锚 / 一代轮转
  + 2048 / `--detail` 非零退出）按提案推荐或按裁定改写判定与场景；结论摘进报告。 · 证据：`docs/team/reviews/turn-notice-merge-proposal.md`（ACCEPTED，含两条 PM 注记；三个裁定点都落成了合同：尾行锚 + 每收件人一把锁的截尾重写、上界 2048 只留一代、`--detail` 缺文件/记录不全点名并非零退出）+ P251-dev3.md 的 Deliverables 表与 Decisions + V34.md §2.1/§2.3（独立复核这三条）。实际做法：报告没有单列「三个裁定点」小节，三条分别落在 Deliverables 表与 V34 的对应小节。
- [x] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y turn-notice-merge && ｜ PM 补证据（2026-10-15 重跑）：PM 在**收窄后**的 delta 上重跑投影（G2 的补做）：干净克隆里 `openspec validate --all --strict` 22/0 → `openspec archive -y turn-notice-merge` 成功（`2026-10-15-turn-notice-merge`）→ 归档后校验 21/0（比归档前少 1 项，正是被归档的那条 change）
  openspec validate --all --strict)` 必须绿；逐条 MODIFIED 与基线逐场景对照（丢一条基线场景 = 返工），并确认
  没有第二个未归档 change 动 `notify-and-inbox`。 · 证据（**留空**，见报告「缺口」一节）：记录里没有 apply 阶段（范围追加后的 delta）的投影命令与输出尾——本仓 `docs/team/` 全量 grep `archive -y turn-notice-merge` **0 命中**；提案复核 `docs/team/reviews/turn-notice-merge-proposal.md` 记过一次试归档（`archive` → `+1 ~1 -0`、归档后 16/0），但那是**范围追加（挂起只记录）之前**的稿子；P251-dev3.md 的验收七条与 V34.md §5 都没有跑 `archive -y turn-notice-merge`。第二半「没有第二个未归档 change 动 `notify-and-inbox`」本轮复核**成立**；逐条 MODIFIED 与基线 16 条场景的对照由 V34.md §5 机械复核（`missing from delta: []`）。

## 1 合并键与合并行（规格：`notify-and-inbox`#A turn-end notification appends one inbox line and knocks once）

- [x] 1.1 写入入口：在收件箱写入口（`scripts/lib`）实现「读尾行 → 按四分量键判定 → 截尾重写或追加」，
  每收件人一把锁；`team_inbox_append` 走同一把锁；锚校验不过一律追加（fail-safe）。键的规范化按 design
  决策 2（`awaiting` 顺序无关；缺字段 ≠ 空集）。 · 证据：P251-dev3.md Deliverables 第 1 行（`cmd-agents.sh`：合并键 = 席位\|状态类\|任务\|`awaiting` 集合、尾行锚 + 每收件人 `flock` 截尾重写、`flock` 不可用时降级为历史行为、先明细后合并、内部命令 `__inbox-write`）+ 验收 ②（`bg-ledger --select merge,detail,wake,suspend-shape,owner-scope` → 48 passed / 0）+ 本轮核对 `cmd-agents.sh:1868`（`team_inbox_append` 与扩展的 `__inbox-write` 共用同一把锁）+ V34.md §2.1（11 条用例：同键三条合并 `×3`、汇总行取最后一条的值、跨类/跨任务/跨 `awaiting` 必然新起一行、`awaiting` 按集合比较（预置反序仍合并）、只有最后一行是锚、跨席位各写各的文件、摘要里像键的 token 不污染、`awaiting=` 空集与字段缺失是两个键、非回合行不合并、去重窗口内字节相同的重复不计）。
- [x] 1.2 合并行形状：汇总行 = 最后一条事件的行 + 首事件时间戳 + 字段区 `×N first= last=`；首条事件的行
  逐字节不变。 · 证据：P251-dev3.md Deliverables 第 1 行 + V34.md §2.1（`×3`、`first=`/`last=` 等于明细第 1/3 条的 ISO、汇总行的 `uncommitted`/`tip` 取最后一条）+ §2.5（单事件行与 v0.2.0 逐字节对照：归一化时间戳与 tip 后 `IDENTICAL`）+ 验收 ⑤（`smoke.sh --paths` ✓4667 ✗0，含 §13/§13b 的既有逐字节断言）。
- [x] 1.3 扩展改为消费写入结果（新行/扩展），不再自己 `appendFileSync` 收件箱行。 · 证据：P251-dev3.md Deliverables 第 5 行（`team-notify.ts` 调 CLI 写入口并消费 `state=new/extended/failed`）+ V34.md §2.2（扩展日志写明 `no knock (inbox write state=extended)`）+ §2.6（`tests/**` 删除行审计：只替换了 knock 去重键形状那一条断言，不是删断言换跳过）。
- [x] 1.4 红侧：去掉键比较 / 跨类合并 / 取第一条的值 / 穿行重写 —— 各自让对应场景变红，还原后绿。
  · 证据：P251-dev3.md Flip evidence（12 处破坏：键比较去掉 / 键里的状态类固定成 `delivered` / 汇总行取旧尾行 / 锚改扫「文件里最后一条 auto 行」/ 删明细落盘 / 越界不轮转 / `--detail` 静默空输出 / `--detail` 顺手 ack / 每次 settle 都入队 knock / 把「挂起也敲门」加回去 / knock 去重键改成摘要文本 / 写盘失败仍叫醒；逐条红在点名用例，还原后 pristine 重跑全绿）+ V34.md §3（复验者自写的 15 条破坏轮，四条 merge 红点全中）。

## 2 明细文件与读面（规格：`notify-and-inbox`#A turn-end notification's raw events stay in a bounded detail file）

- [x] 2.1 先明细后合并：`state/notify.log` 一行一事件（单发形状），上界 `TEAM_NOTIFY_DETAIL_MAX`（默认 2048），
  越界轮转到 `state/notify.log.1`（一代）+ 新代轮转头 + 扩展日志；明细写失败 → 不合并、行带
  `detail=unavailable`（该行也不做后续事件的锚）、日志点名；明细记录不追加收件箱行、不入队 knock。
  · 证据：P251-dev3.md Deliverables 第 1/3 行 + 验收 ②（`--select merge,detail,wake,…` 48 passed / 0）+ V34.md §2.3（9 条用例：`×N` 与记录数一致、记录不是流量（无收件箱行无 knock）、上界逐拍快照（`TEAM_NOTIFY_DETAIL_MAX=2` 时第 2 条不轮转、第 3 条轮转且只有一代）、缺文件点名非零退出、被轮转出去点名缺口、失败写带 `detail=unavailable` 且不作锚、同键两条 run 分离、`--detail` 只读、手工通知不进明细）+ 本轮核对 `cmd-config.sh:129`（键表 `TEAM_NOTIFY_DETAIL_MAX|apply|int|1,|plain|2048`）与 `references/config.md:162`。
- [x] 2.2 `team inbox <agent> --detail`：打印当前代该席位的记录 + 读到的路径/轮转状态；对每条合并行核对
  `×N` 与记录数，缺文件/记录不全点名 `state/notify.log.1` 并非零退出；只读、不 ack。 · 证据：P251-dev3.md Deliverables 第 2 行（`cmd-status.sh`：只读、非零退出点名缺口、不 ack、不动未读数）+ V34.md §2.3（缺文件/记录被轮转出去都点名 `state/notify.log`/`state/notify.log.1` 并非零退出、`--detail` 不改未读数）+ 验收 ② 与 ⑤（`smoke.sh --select 7,13,13b,13c` 在 V34.md §5 复跑 ✓519 ✗0）。
- [x] 2.3 红侧：删掉明细落盘 / 越界不轮转 / `--detail` 静默空输出 / 把 `--detail` 写成会 ack —— 各自变红。
  · 证据：P251-dev3.md Flip evidence 表（删明细落盘 / 越界不轮转 / `--detail` 静默空输出 / `--detail` 顺手 ack）+ V34.md §3 表（同四条各自红在点名用例，还原后 29 条全绿）。

## 3 叫醒（规格：`notify-and-inbox`#A turn-end notification appends one inbox line and knocks once）

- [x] 3.1 只有写新行才入队 knock（扩展既有 run 不入队、不敲字）；knock 的 `--dedup` 换成行身份（席位、键、
  首事件时间）；写入失败零条目。状态类变化必然新行 → 必然叫醒。 · 证据：P251-dev3.md Deliverables 第 5 行（只有写了新行且行可行动才入队 knock；去重键 = `line|<合并键>|<首事件时间>`）+ 用户可见行为变化第 1 条（范围追加：挂起只记录不叫醒）+ V34.md §2.2（9 条用例：交付新行恰好 +1、合并的 settle 计数不变、中断 +1、挂起 +0 但收件箱行与明细都在、挂起→交付/中断各 +1、写盘失败 +0、两条正文相同的不同行各自入队）。
- [x] 3.2 红侧：每 settle 都入队 knock / 用摘要文本当去重键 / 写失败仍叫醒 —— 各自变红。
  · 证据：P251-dev3.md Flip evidence 表（每次 settle 都入队 knock / 把「挂起也敲门」加回去 / knock 去重键改成摘要文本 / 写盘失败仍叫醒）+ V34.md §3 表（同四条）。

## 4 既有读者与手工路径回归（规格：同两条要求）

- [x] 4.1 未读计数/digest `[2]`/面板尾行/`--ack` 在合并行上仍按一行算；已读行被扩展后仍已读（不改这三处代码）。
  · 证据：P251-dev3.md 用户可见行为变化第 2/3 条 + V34.md §2.4（digest `[2]` 对该席位 1 条新且尾行是合并行带 `×3`；面板 JSON `inbox_new=1`/`inbox_lines=1`；`--ack` 之后行的后续扩展不再变未读）+ V34.md §5（作者夹具对照重跑 + `smoke.sh --select 7,13,13b,13c` ✓519 ✗0）+ 验收 ⑤。
- [x] 4.2 `[manual]`/`[draft]`/`[nudge]`/pulse 行不合并、不进明细、叫醒照旧；插在 run 中间时结束 run 且本人
  逐字节不变。 · 证据：V34.md §2.1（`non-turn-end lines never merge and never enter the detail file`；中间插 `[manual]` → run 结束且本人逐字节不变）+ §2.3（`a manual notice never enters the detail file`）+ P251-dev3.md Decisions（`smoke.sh` §13 的 manualBreak 修正：不插分隔符后一条会合并进同一行、对照就消失）+ 验收 ⑤。
- [x] 4.3 陈旧判据在合并行上读最后一条的 `task=`/`tip=`（board done/closed 与 reviews HEAD 两条判据都要跑）。
  · 证据：V34.md §2.4（`a merged line is judged by its last event`：`line.tip=664b27f1…` 取最后一条，而 reviews HEAD 是第一条 → 合并行不陈旧、第一条记录本身陈旧；board done 规则读同一字段）+ P251-dev3.md 用户可见行为变化第 3 条 + 验收 ⑤（§13b）。
- [x] 4.4 去重窗口语义不变：窗口内的重复 settle 既不进明细也不推进 `×N`。 · 证据：V34.md §2.1（`a byte-identical repeat inside the dedup window neither counts nor records`：行=1、明细=1）+ P251-dev3.md Deliverables（去重窗口的残余职责）+ Decisions（`references/protocol.md` 通知段的旧句「同一条简报每 `TEAM_NOTIFY_DEDUP_SEC` 秒只发一次」已按新合同重写）。

## 5 配置、文档与门禁登记

- [x] 5.1 `TEAM_NOTIFY_DETAIL_MAX` 登记进 `scripts/lib/cmd-config.sh` 的键表，`references/config.md` 写清语义与默认；
  需要时在 `references/protocol.md` 的通知段加一行交叉引用。 · 证据：本轮核对 `cmd-config.sh:129`（键表行）、`:265`（flat 列表）、`references/config.md:162`（语义与默认 2048）、`panel/src/strings/zh.ts:346`（`label_TEAM_NOTIFY_DETAIL_MAX`）+ P251-dev3.md Deliverables 第 3/6 行（键表/文档 + 面板两张标签表 + `build.sh` 重建 `panel.js`）+ 验收 ② 与 ④。实际做法：`references/protocol.md` 的交叉引用不是「加一行」而是把该段旧句按新合同重写（P251 Decisions 末段）。
- [x] 5.2 新夹具归属登记（`tests/section-paths.tsv`，必要时 `section-budgets.tsv`）；反向守卫（真项目
  `state/`+`inbox/` 前后快照、夹具标记零命中）保持绿。 · 证据：P251-dev3.md Deliverables（`tests/section-paths.tsv` 把 `bg-ledger-harness.mjs` 登记进 §13c）+ 本轮核对 `section-paths.tsv:81`（§13c 行含 `bg-ledger-harness.mjs` 与 P251 注记）+ V34.md §5（`bg-ledger.sh` 尾部的守卫行 + 破坏轮之后真实工作树仍干净：`git status --porcelain -uall` 空）+ 验收 ④（`section-select.sh --check` ok 8 / bad 0 / SKIP 1）。

## 6 收尾

- [x] 6.1 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check`
  + `ledger-ban.sh`；全量门禁留给 PM 复验，按纪律后台跑。 · 证据：P251-dev3.md 验收 ①③④⑤⑥⑦（validate 17/0；`bg-ledger --select flip` 171/0；`section-select --check` ok 8 / bad 0 / SKIP 1；`smoke.sh --paths` ✓4667 ✗0（117 段，rc=0，4839s）；`ledger-ban` files=1458 hits=0；`git status --porcelain -uall` 空）+ V34.md §5（`spec-refs.sh --check` rc=0、validate 17/0、`smoke.sh --select 7,13,13b,13c` ✓519 ✗0）。实际做法：全量门禁未跑（报告已点名没跑的 12 个键）；本清单点名的 `spec-refs.sh --check` 由**复验者** V34 跑出 rc=0（作者侧七条里没有它）。
- [x] 6.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾，以及第 1.4/2.3/3.2 节的
  **red→green 原始输出**（破坏实现必红、还原必绿）。 · 证据：`docs/team/reports/P251-dev3.md`（Deliverables 表、Verification evidence 七条、Flip evidence 四步与 12 处破坏表、Decisions 含三条自己踩到并修掉的缺陷与一条事故自报）+ V34.md §0/§3（独立复验确认四步完整、12 条红点、还原后 29 条全绿）。

## 7 独立验证（另一席位，不是 apply 作者）

- [x] 7.1 在独立冻结克隆重跑第 1–4 节的**全部**场景与保留回归（`merge`/`detail`/`wake`/`suspend-shape`/ ｜ PM 补证据：V34 在冻结克隆里重跑第 1–4 节全部场景与保留回归：`docs/team/reviews/V34.md`（自写 39 用例夹具全绿）
  `owner-scope`、smoke §7/§13/§13b/§13c），逐条给 command/assertion/rc 与 skip。 · 证据：独立记录 + 原始日志
- [x] 7.2 逐条重做第 1.4/2.3/3.2 节的**每一条**红侧（破坏必红、还原必绿），不是只复跑绿侧。 ｜ PM 补证据：V34 逐条重做红侧（12 处自写破坏，各自红在点名用例、还原后绿）：`docs/team/reviews/V34.md`
  · 证据：red→green 原始输出
- [x] 7.3 自设计反例：并发追加与合并的临界区（sentinel 暂停）、轮转边界（恰好等于/超过上界）、 ｜ PM 补证据：V34 自设反例（并发追加与合并的临界区、轮转边界、陈旧判据逐事件解析）：`docs/team/reviews/V34.md`
  去重窗口与合并的交互、同键但不同窗口的两条 run 在 `--detail` 下的分离、跨席位/任务/集合。 · 证据：反例脚本与输出尾
- [x] 7.4 判 `verification` 的正确性门：只有证据通过；不因为「作者报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md` ｜ PM 补证据：PM 据 V34 的证据判过（PASS），不以作者报告为准：`docs/team/reviews/P251.md` 合并记录

## 8 apply / verify 的验收命令（本阶段不运行）

```bash
bash skills/teamsmith/tests/bg-ledger.sh --select merge,detail,wake   # 第 1/2/3 节（键名以 apply 冻结为准）
bash skills/teamsmith/tests/bg-ledger.sh --select flip                # 第 1.4/2.3/3.2 节的逐条红侧
bash skills/teamsmith/tests/bg-ledger.sh                              # 挂起面回归 + 新三组
bash skills/teamsmith/tests/smoke.sh --select 7,13,13b,13c            # 第 4 节的读者/单事件行回归
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-notify.ts \
  skills/teamsmith/scripts/lib/cmd-agents.sh skills/teamsmith/scripts/lib/cmd-status.sh
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧按第 1.4/2.3/3.2 节逐条现场改坏再还原（scratch 变异，只写 `${TMPDIR:-/tmp}` 下的 owned 根）；夹具与命令的
最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。
