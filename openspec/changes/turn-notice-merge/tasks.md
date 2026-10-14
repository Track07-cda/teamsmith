# turn-notice-merge · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每项都留下可复跑的夹具与其红侧）；**verify** 由**另一个**
席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与两组红侧。本文件不是规格；
合同文本在 `specs/notify-and-inbox/spec.md` 的 delta 里，逐条 MODIFIED 不得丢基线场景（基线 16 条）。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/turn-notice-merge-proposal.md`，确认三个裁定点（尾行锚 / 一代轮转
  + 2048 / `--detail` 非零退出）按提案推荐或按裁定改写判定与场景；结论摘进报告。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y turn-notice-merge &&
  openspec validate --all --strict)` 必须绿；逐条 MODIFIED 与基线逐场景对照（丢一条基线场景 = 返工），并确认
  没有第二个未归档 change 动 `notify-and-inbox`。 · 证据：投影命令与输出尾

## 1 合并键与合并行（规格：`notify-and-inbox`#A turn-end notification appends one inbox line and knocks once）

- [ ] 1.1 写入入口：在收件箱写入口（`scripts/lib`）实现「读尾行 → 按四分量键判定 → 截尾重写或追加」，
  每收件人一把锁；`team_inbox_append` 走同一把锁；锚校验不过一律追加（fail-safe）。键的规范化按 design
  决策 2（`awaiting` 顺序无关；缺字段 ≠ 空集）。 · 证据：`bash tests/bg-ledger.sh --select merge`
- [ ] 1.2 合并行形状：汇总行 = 最后一条事件的行 + 首事件时间戳 + 字段区 `×N first= last=`；首条事件的行
  逐字节不变。 · 证据：`merge` 组 + smoke §13/§13b 既有逐字节断言的输出尾
- [ ] 1.3 扩展改为消费写入结果（新行/扩展），不再自己 `appendFileSync` 收件箱行。 · 证据：`merge` 组
- [ ] 1.4 红侧：去掉键比较 / 跨类合并 / 取第一条的值 / 穿行重写 —— 各自让对应场景变红，还原后绿。
  · 证据：报告里的 red→green 原始输出（场景：一条 run 一行并带窗口 / 状态类变化新起一行 / 最后一条的值 /
  打断后不改写别人的行）

## 2 明细文件与读面（规格：`notify-and-inbox`#A turn-end notification's raw events stay in a bounded detail file）

- [ ] 2.1 先明细后合并：`state/notify.log` 一行一事件（单发形状），上界 `TEAM_NOTIFY_DETAIL_MAX`（默认 2048），
  越界轮转到 `state/notify.log.1`（一代）+ 新代轮转头 + 扩展日志；明细写失败 → 不合并、行带
  `detail=unavailable`（该行也不做后续事件的锚）、日志点名；明细记录不追加收件箱行、不入队 knock。
  · 证据：`bash tests/bg-ledger.sh --select detail`（含「The detail file is not traffic」）
- [ ] 2.2 `team inbox <agent> --detail`：打印当前代该席位的记录 + 读到的路径/轮转状态；对每条合并行核对
  `×N` 与记录数，缺文件/记录不全点名 `state/notify.log.1` 并非零退出；只读、不 ack。 · 证据：`detail` 组 +
  `bash tests/smoke.sh --select 7`
- [ ] 2.3 红侧：删掉明细落盘 / 越界不轮转 / `--detail` 静默空输出 / 把 `--detail` 写成会 ack —— 各自变红。
  · 证据：red→green 原始输出（场景：计数与记录一致 / 轮转头 / 上界 / 缺口点名 / 只读）

## 3 叫醒（规格：`notify-and-inbox`#A turn-end notification appends one inbox line and knocks once）

- [ ] 3.1 只有写新行才入队 knock（扩展既有 run 不入队、不敲字）；knock 的 `--dedup` 换成行身份（席位、键、
  首事件时间）；写入失败零条目。状态类变化必然新行 → 必然叫醒。 · 证据：`bash tests/bg-ledger.sh --select wake`
- [ ] 3.2 红侧：每 settle 都入队 knock / 用摘要文本当去重键 / 写失败仍叫醒 —— 各自变红。
  · 证据：red→green 原始输出（场景：计数抖动不叫醒 / 每个新行恰好一次 / 文本相同的两条不同行不互吞）

## 4 既有读者与手工路径回归（规格：同两条要求）

- [ ] 4.1 未读计数/digest `[2]`/面板尾行/`--ack` 在合并行上仍按一行算；已读行被扩展后仍已读（不改这三处代码）。
  · 证据：`bash tests/smoke.sh --select 7,13b` + `merge` 组的读者断言
- [ ] 4.2 `[manual]`/`[draft]`/`[nudge]`/pulse 行不合并、不进明细、叫醒照旧；插在 run 中间时结束 run 且本人
  逐字节不变。 · 证据：`merge` 组（打断场景）+ `bash tests/smoke.sh --select 7`
- [ ] 4.3 陈旧判据在合并行上读最后一条的 `task=`/`tip=`（board done/closed 与 reviews HEAD 两条判据都要跑）。
  · 证据：`merge` 组的陈旧断言 + 既有 §13b 输出尾
- [ ] 4.4 去重窗口语义不变：窗口内的重复 settle 既不进明细也不推进 `×N`。 · 证据：`merge` 组

## 5 配置、文档与门禁登记

- [ ] 5.1 `TEAM_NOTIFY_DETAIL_MAX` 登记进 `scripts/lib/cmd-config.sh` 的键表，`references/config.md` 写清语义与默认；
  需要时在 `references/protocol.md` 的通知段加一行交叉引用。 · 证据：`team config` 输出 + `bash tests/smoke.sh --select 0c,13c`
- [ ] 5.2 新夹具归属登记（`tests/section-paths.tsv`，必要时 `section-budgets.tsv`）；反向守卫（真项目
  `state/`+`inbox/` 前后快照、夹具标记零命中）保持绿。 · 证据：`bash tests/section-select.sh --paths …` 的 RUN 决定
  + `bg-ledger.sh` 尾部的守卫行

## 6 收尾

- [ ] 6.1 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check`
  + `ledger-ban.sh`；全量门禁留给 PM 复验，按纪律后台跑。 · 证据：各命令 rc 与输出尾
- [ ] 6.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾，以及第 1.4/2.3/3.2 节的
  **red→green 原始输出**（破坏实现必红、还原必绿）。 · 证据：报告本体 + 提交

## 7 独立验证（另一席位，不是 apply 作者）

- [ ] 7.1 在独立冻结克隆重跑第 1–4 节的**全部**场景与保留回归（`merge`/`detail`/`wake`/`suspend-shape`/
  `owner-scope`、smoke §7/§13/§13b/§13c），逐条给 command/assertion/rc 与 skip。 · 证据：独立记录 + 原始日志
- [ ] 7.2 逐条重做第 1.4/2.3/3.2 节的**每一条**红侧（破坏必红、还原必绿），不是只复跑绿侧。
  · 证据：red→green 原始输出
- [ ] 7.3 自设计反例：并发追加与合并的临界区（sentinel 暂停）、轮转边界（恰好等于/超过上界）、
  去重窗口与合并的交互、同键但不同窗口的两条 run 在 `--detail` 下的分离、跨席位/任务/集合。 · 证据：反例脚本与输出尾
- [ ] 7.4 判 `verification` 的正确性门：只有证据通过；不因为「作者报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md`

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
