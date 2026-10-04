# P6 · Apply: `deferred-delivery-and-draft-entry`（输入框守卫 + 延后投递 + 草稿窗口）

```
task:   P6
agent:  dev
phase:  apply
change: deferred-delivery-and-draft-entry
deps:   P5 提案 ACCEPTED（docs/team/reviews/deferred-delivery-and-draft-entry-proposal.md）；E3（D21）
note:   你的分支基于 P5 的提案 tip（920fa19d7162e85c13296df3ddf23fd0619ad9fa）并合入了 main（拿 F6 的测试口径修复）——change 产物已在树里。
```

## 绑定条件（P5 审查 + D21，全部生效）

1. tasks.md 第 0 项先行：先在夹具 pane 里复现"草稿被粘走"（红），再让守卫把它变绿——翻转证据是交付的第一条。
2. 守卫与排水各是一个函数；队列文件格式即对外契约；扩展（team-notify.ts）改为入队并把去重键带进队列条目。
3. 入队的消息在指纹校验循环**之前**返回"queued"；指纹校验挪进排水；watchdog（注意：在树里仍是这个名字，改名是另一个 change）的 nudge 走同一守卫。
4. 空白草稿检测洞**写进规格与文档**，不许静默地错。
5. `say`/`notify`/`team outbox` 的行为按 delta 逐条；`--now` 的逃生语义按规格。
6. 隔离条款（tasks 7.2）：夹具全在沙盒仓库跑、清 `TEAM_*` 继承、写前验 `team paths`、真实 inbox/state 前后哈希不变。
7. 三段门禁全绿 + fast 模式绿。

## 边界

- 你的文件：`skills/teamsmith/scripts/lib/**`（守卫/队列/排水/发送路径）、`extension/team-notify.ts`、
  `skills/teamsmith/tests/smoke.sh`、`references/troubleshooting.md`/`config.md`/`protocol.md`（按 tasks）、
  `templates/config.sh.tmpl`、`openspec/changes/deferred-delivery-and-draft-entry/**`、你的报告。
- 不动 `openspec/specs/**`、不动账本、不归档、不 push main。

## 验收

```sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-lint.sh
bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

## 报告

`docs/team/reports/P6-dev.md` + 证据包（翻转：胶水 bug 红 → 守卫绿；TTL/排水/去重/顺序；未知 pane 的放行政策；竞态：Enter 前的复检）。

---

## P6 rework 1（V7 的六条 finding，全部必修；2026-09-15）

V7（独立验证，探针包 ok 200 / bad 0 / finding 13，含**真实 Pi 复现**）确认主路径修住了，但下面六条必须处理。
完整证据在 `docs/team/reports/V7-verify.md`（分支 task/V7-verify-deferred-delivery-and-）。

1. **F1（高）**：检测器只看光标行**及以上**；草稿以空行开头、光标被移到上方空行时，文字在光标行下方 → 误判 EMPTY
   → 在真实 Pi 上**不需要竞态**就复现了原始事故（`V7-REALPI-BELOWCURSOR` 与两行草稿被粘成一条提交）。
   修：扫描区域必须覆盖**整个输入框**（光标上下都算），不限于光标行以上。规格/文档里"纯空白草稿是唯一已知漏检"
   的说法要同步更正（空白草稿仍是已知洞；F1 这类修掉）。
2. **F2（中）**：Enter 前的复检是"可见非空白字符数 ≤ payload 长度"，大 payload 被 TUI 折叠后必然放行。
   修：复检改为与"检查时刻的草稿指纹"比对（或你论证出的等价可靠信号），不许再用长度启发式。
3. **F3（中）**：被污染的草稿会被再投一次（同一 payload 到两次）。修：跨投递去重要覆盖这条路径。
4. **F4（中）**：投递确认只看 pane 尾部 400 字节 → 成功投递被判"未确认"→ 滞留队列 → 下一拍再贴一遍。
   修：确认信号要能找到 payload（例如回显 nonce/尾部特征），不能只盯尾部 400 字节。
5. **F5（中）**：一次成功的 `say` 也写收件箱（tag `queued`）并抬高巡检计数。修：已确认送达的窗格投递**不再**写收件箱
   （或写但不计入待办——选一个，理由写进报告）。
6. **F6（低-中）**：smoke §12b-h ⑤/⑥ 依赖 `$TMUX` 非空，非 tmux 环境下整套门禁变红。修：非 tmux 下按既有惯例
   打 `SKIP` 并说明，而不是 FAIL。

## 返工验收

```sh
openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh && bash skills/teamsmith/tests/smoke.sh && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```

报告追加一节：六条 finding 各自的修复前后证据（命令+输出），以及 V7 探针包在你修复后的重跑结果。

---

## P6 rework 2（V8 的 8 条新 finding；2026-09-15）

V8 确认六条旧 finding 全部真正关闭、F3b 证伪（实现者分析正确）。但三处新代码（整框检测/指纹复检/离框确认）
带来新的 8 条（证据：`docs/team/reports/V8-verify.md` §3 + `evidence/`，分支 task/V8-verify-p6-rework-finding-f3b）：

1. **V8-N1（高，必修）**：草稿里有一行"框线"时整框检测把脏框看成空框——**真实 Pi 上原样重演了 D20 事故**。
   N1c 是同根镜像（光标在框线上方）。修：先加"草稿含框线行"的 falsifier（真实 Pi 形状 V8 已备好，
   §8 引用了它），再修框线定位逻辑；规格场景同步。
2. **V8-F4b/F4c（中）**：投递未确认时**立即**进 held/（规格逐字如此要求），消除"人在窗口期按 Enter → 同一
   payload 到两次"的重复投递窗口。
3. **V8-N2（中）**：payload 自身含折叠占位符字样（如 `[paste #1 +K lines]`）时被误判为"占位符+别人的字"。
   修：占位符识别与"他人文字"判定解耦（你自己论证等价可靠的信号，不许再靠文本巧合）。
4. **V8-N3/N4（中）**：粘贴进行中的中间帧被当成"有人竞速"；双占位符场景。修或如实论证边界（V8 注明这两条只在
   夹具上确定复现，真实 Pi 的帧粒度未注入实测——你要么在真实 Pi 上补注入实验，要么把边界写进规格）。

报告追加 rework 2 一节：8 条各自的 before/after 证据 + V8 探针包重跑（`pkg/run.sh --skill <修复后的 skills/teamsmith>`）。

---

## P6 rework 3（V9 的 finding；2026-09-16）

V9 确认 N1 家族在真实 Pi 关闭（含半行/Unicode 变体）、残余 5 行是规格有意改义的正确翻转。新 finding 分四档
（证据：`docs/team/reports/V9-verify.md`，分支 task/V9-verify-p6-rework-2-n1-pi）：

**必修（消息安全级）**：
1. **V9-B5（中高·消息丢失）**：框被清空但**没有提交**（TUI 吞 Enter：覆盖层/转义/重绘）→ 现在报"已确认送达"并删条目
   → 消息不可恢复地丢了。修：**确认的信号必须从"payload 离开输入框"改成"payload 出现在会话区/提交记录"**
   （真实 TUI 提交后消息会进气泡区；清空只是消失）。并且：**任何未确认的条目永不删除**——进 held/ 且保留持久副本。
   规格里"离框即送达"的措辞要改成"出框且有提交证据才送达"。
2. **V9-B1（中·真实 Pi 已复现）**：payload 含 `[paste #` 片段（半成品占位符）→ 误判 draft-raced → 终态 held，
   消息永远留在人的框里。修：占位符识别必须是**完整折叠标记**（行首行尾/整行匹配），不是子串。

**修复或如实降级为文档化边界（不许静默）**：
3. **V9-A4/A5/A10**：等宽框线变体仍判 EMPTY——V9 注明真实 Pi 因 119 列折行**不可达**（夹具专属）。要么修，
   要么把"119 列以下的框线宽度才检测"的边界写进规格与 troubleshooting（如实）。
4. **V9-C1…C5（文档诚实性 5 处）**：N5 的触发形状与结论写错（实测 BUSY 写成 UNKNOWN）、槽位残余措辞等——逐条更正，
   文档必须与实测一致。
5. **V9-D2**：tier2 判定与真实 spinner 不符——修正或改文档。
6. **V9-E1**：smoke 的 PM 适配器段既有抖动（1/3）——不是本 change 的活，但在报告里点名它（我另行排队）。

**收敛判据（写死）**：下一轮验证（V10）若不再出现"在真实 Pi 上重演用户事故 / 消息丢失或粘稿"级别的 finding，
且文档诚实性 finding 清零，本 change 即交用户确认归档；否则继续按同一循环修。

## 返工验收

同前（三段门禁 + fast + 无 TMUX 三种环境）。报告追加 rework 3 一节：B5/B1 的 before/after（真实 Pi 证据）、
A 系列的处置选择及理由、C 系列逐条更正对照、V9 探针包重跑汇总。

---

## P6 rework 4（PM 重跑 V9 探针包后的残余；2026-09-16）

好消息先说：90-realpi 段全绿——B5/B1 的主形状在真实 Pi 上关闭，D20 事故不再重演。但探针包还有残余
（PM 自跑 `ok 98 / bad 3 / finding 8`，日志 `/tmp/v9pkg-rerun/logs/`；与你的自报逐条对账）：

1. **B1 变体没修完**：payload 正文里含 `[paste #` **子串**（不是完整占位符）仍被判成渲染中间帧。修：只有
   **完整折叠标记**（整行/行首行尾锚定）才触发中间帧判定。
2. **V8-N2 回归（B2）**：含完整占位符字样的合法 payload 现在不被正常投递（提交 1 次 + 队列里还压 1 条）。
   这是修 B1 时误伤的反向形状，修并加双向回归断言（占位符子串≠中间帧 AND 占位符字样 payload 正常送达）。
3. **B6**：渲染停顿超过约一秒等待上限时，干净消息被判竞态并**终态** held。修：超时进 held 必须是**可恢复的**
   （原因写 `stall-timeout`、下个排水周期重试），不许终态。
4. **C 系列文档诚实性（C1/C2/C4 仍在）**：rework 3 没改完——troubleshooting §3 的 whitespace 条目仍自称
   "这是唯一已知漏判"（实测还有别的形状）；N5/N6 边界的措辞与实测判定不符（BUSY/UNKNOWN 写反）。
   逐字更正到与实测一致。
5. **D2**：真实工作状态行的形状（braille spinner + 文字）与 tier2 预期不符——修正 tier2 或更正文档。

收敛判据不变（rework 3 写的）：V10 不再有"真实 Pi 重演事故 / 消息丢失 / 文档诚实性"级 finding 即归档。
