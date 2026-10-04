# P160 · `meeting-liveness` 返工：排队敲门补账本 · 标识宽度固定 · 空闲分支不许造 task

```
task:   P160
agent:  dev-bob
issue:
change: meeting-liveness
specs:  meeting#A knock names the turn it announces
phase:  apply
anchor: change
deltas: meeting,notify-and-inbox
grant:  skills/teamsmith/scripts/lib/cmd-meeting.sh · skills/teamsmith/scripts/lib/outbox.sh · skills/teamsmith/scripts/lib/cmd-agents.sh · skills/teamsmith/extension/team-notify.ts · skills/teamsmith/tests/** · openspec/changes/meeting-liveness/** · docs/team/reports/P160-<agent>.md · docs/team/reports/P160-<agent>/**
deps:   独立验证 `docs/team/reports/P153-verify.md`（三条缺陷 + 证据包 ✓）· 评审 `docs/team/reviews/P153.md`（我逐条复核过 ✓）· 实现已合入 main ✓ · **复验必须换人** ✓（D31）
status: wip
budget: 一个工作块
priority: 高（`meeting-liveness` 因此**不可归档** ✓）
```

## 三条（每条都要红→绿原始输出；**不许**放松既有承诺）

### F1 · 排队敲门在**真正投递**时必须补账本 ✅
现场：`cmd-meeting.sh:564–575` 只在 `delivered|watched|unknown-sent` 分支写 `knocks.log` ✗；`queued)` 分支不写 ✗ →
入队后由 `outbox flush` 投递时**账本里仍没有该轮** ✗ → 接收方按账本判"这轮没收到过" ✗。
要求：**共享区零写入**这条不许破 ✓（入队时仍不写 ✓），但**实际投递发生时**必须补记**同一轮次** ✓（`[meeting:<slug>#<turn>]` ✓）；
红侧：入队 → 清空草稿 → `outbox flush` → **账本里出现该轮** ✓；反向：仅入队未投递 → **账本里没有** ✓（不许提前写 ✓）。

### F2 · 修订标识**宽度固定**、两个发送方同一契约 ✅（**PM 的裁断**）
现场：`cmd-agents.sh:1536` 用 `git rev-parse --short HEAD` ✗ —— 它**服从** `core.abbrev` 与对象数 ✓（7 vs 12 ✓）→
同一 HEAD 在 CLI 与扩展两处盖出**不同**的 `tip=` ✗。
**裁断**：标识 = **HEAD 的前 12 个十六进制字符，工具自己截** ✓（`git rev-parse HEAD | cut -c1-12` ✓），
**不**使用任何受配置影响的缩写形式 ✓；CLI 与扩展**同一实现/同一常量** ✓；
接收方的 stale 判定按**同一宽度**比较 ✓（`reviews/<ID>.md` 里记的 HEAD 也按前 12 位比 ✓，并在文档里写明 ✓）。
红侧：把 `core.abbrev` 设成 7 与 12 各跑一次 → 同一 HEAD 的 `tip=` **逐字节相同** ✓；反向：把宽度改回受配置影响 → 断言必红 ✓。

### F3 · 空闲 agent 分支**不许**造出 task 标识 ✅
现场：`cmd-agents.sh:1531–1535` 同时接受 `task/*` 与 `agent/*` ✗，并把后缀首段当 task ID ✗ → `agent/dev` 上发出 `task=dev` ✗。
要求：只有**能证明**是任务分支（`task/<ID>-…` 且**该 ID 在 `state/<agent>.env` 的 `task=` 或看板/任务书里存在** ✓）才允许盖 `task=` ✓；
`agent/*` 与其它分支 → **不盖** ✓（**不编造** ✓）；手工 `team notify` 同样 ✓。
红侧：在 `agent/dev` 上（无 `state/dev.env`、无任务书、无看板行 ✓）→ inbox 行与 knock 载荷里**都没有** `task=` ✓；
反向：真任务分支上**必须**有 ✓。

## 门禁与报告

`openspec validate --all --strict` ✓ + 相关段（`55`/`56`/`12b-pi` ✓）+ FAST ✓ + **一次全量** ✓；
每条红→绿原始输出 ✓；报告点名"哪些自己跑、哪些引用 P153" ✓；**复验换人** ✓。
