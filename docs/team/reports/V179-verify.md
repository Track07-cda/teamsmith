# V179 · 消息页发送受阻提示的独立验证

agent: verify · status: PASS · time: 2026-11-19T02:48:16Z

branch: `task/V179-panel-outbox-type-verify` · PR/MR: -

**合并版 `0e6677e2085b4b60058f678039a321041581e786` 通过定点复核。** P474 两个产品文件与通过完整类型检查和重建比对的候选逐字节相同。用合并版实际取的一张消息页画面仍在队列区显示两条受阻消息及各自原因、时间，见文末合并后证据。

## 候选验证（2026-11-19T02:42:28Z）

**候选 `22a1c4aff372fdad1c71093100d876539ef78e2b` 通过。** 消息页队列区显示两条受阻消息的数量、各自的原因和时间；旧版在同一份数据上能正常打开队列，也能列出两条消息，但缺少这组提示。只有普通待发消息时不显示受阻提示；已知受阻但找不到诊断文件时，仍计为受阻且提示诊断不可用。观察前后没有队列、尝试记录或发送变化。完整类型检查通过，重建产物与提交逐字节相同。

## 交付物与证据

| 路径 | 内容 |
|---|---|
| `docs/team/reviews/P474.md`、`docs/team/reviews/P474-verify.log` | 中央记录现绑定合并版，执行者 `verify`，PASS；候选 `22a1c4aff` 的原件另存在下述证据目录（20s，PASS）。 |
| `/var/tmp/v179-verify.TnHL8G/{targeted.sh,frame-check.py,final-record.md,final-gate.log}` | 可复现的定点脚本、画面断言、正式记录与完整输出。 |
| `/var/tmp/v179-verify.TnHL8G/candidate-final/` | 四张独立原画面及 `.plain`、返回码文件、诊断 JSON、状态前后清单、隔离 tmux 调用日志和构建结果。 |

## OpenSpec 评估

没有新 OpenSpec 变更；对既有 `openspec/specs/panel/spec.md` 的 **The deferred-delivery queue is read, counted and never touched** 需求做定点评估，而非变更归档评估。

| 维度 | 结论 | 证据 |
|---|---|---|
| 完整性 | 本轮范围通过 | `git diff --name-status 2ac59d49..22a1c4af` 只见 `layout.ts`、生成的 `panel.js`、实现者报告。受检 checkout 前后干净；完整 panel 类型检查及构建比对通过。 |
| 正确性 | 本轮范围通过 | 新旧使用同一隔离队列，`__panel-data --block outbox` 原始 JSON 相同，两版画面正常退出，旧版只在检查队列区受阻行时失败；候选的缺诊断与普通待发对照均通过。 |
| 一致性 | 本轮范围通过 | `queueBlock` 从 `panel.outbox` 消费已有诊断，仍从 `blocks.outbox_list` 消费列表和全文。读取与发送实现未改；三个场景的状态清单和内容哈希相同，隔离 tmux 无发送操作。 |

- CRITICAL：0；WARNING：0（任务范围内）；SUGGESTION：0。
- 未覆盖：按任务书未跑面板全套、`delivery-truth` 各阶段、全量检查、真实模型或实时 Pulse；未复测纯文本渲染、消息全文、刷新/交互、更多屏宽及其他未改入口，不把上述定点结果当作这些入口的验证。

## 实际命令与结果

从本人工作树运行，安装和构建只在固定候选的私有副本执行。场景从既有 `delivery-truth.sh` 提取 `fix_setup` 与 `section_panel` 的种子前缀，复用两个受阻样本；未执行该脚本的任何整段。`--snapshot --page 3` 使用真实提交的 `panel.js` 及相应版本的 CLI；只在画面中 `deferred queue …` 的框内匹配总数与详情，不从页首或列表行上取证。

```text
$ TEAM_GATES='bash /var/tmp/v179-verify.TnHL8G/targeted.sh' bash skills/teamsmith/scripts/team review P474 --dir /var/tmp/p474-review-22a1c4af.jwDL7B --branch 22a1c4aff372fdad1c71093100d876539ef78e2b
门禁输出：docs/team/reviews/P474-verify.log（PASS，20s）
复验记录：docs/team/reviews/P474.md（PASS）
rc=0

$ bun install --frozen-lockfile
45 packages installed
frozen_install rc=0
$ bunx tsc --version
Version 6.0.3
typescript_version rc=0
$ bunx tsc --noEmit
typescript rc=0
$ env BUN=… bash ./build.sh
Bundled 562 modules
panel.js written (973655 bytes, sha256 b9648e46f5a4bc994d9f6b5b5614631136cecdb3fcb4f2530a6ec07e888f7206)
build rc=0
$ cmp <固定候选>/skills/teamsmith/scripts/panel/bun.lock bun.lock
lockfile rc=0
$ cmp <固定候选>/skills/teamsmith/scripts/panel/panel.js panel.js
bundle rc=0
```

Bun 1.3.14、Node v24.22.1。`bun install` 按 `bun.lock` 安装依赖；面板的现有 `bunx tsc` 命令另外实测为 6.0.3，未把它说成锁文件里的编译器。旧版 4 处 TS2339 与 rc2 是实现者的实跑记录（`docs/team/reports/P474-dev.md`），本轮不重复旧版编译。

### 新旧对照与两组边界

```text
candidate outbox rc=0; previous outbox rc=0; held.same-diagnostics rc=0

candidate render rc=0
held: deferred queue 0 (held 2)
delivery impeded 2: queue-stalled · geometry-untrusted
20260101000000-0001-p147:dev.msg → queue-stalled (2026-01-01T00:00:03Z)
20260101000000-0002-p147:dev.msg → geometry-untrusted (2026-01-01T00:00:02Z)
candidate.assert rc=0

previous render rc=0
held: deferred queue 0 (held 2)
1. [held] 20260101000000-0001-p147:dev.msg · 0s  held reason: queue-stalled
2. [held] 20260101000000-0002-p147:dev.msg · 0s  held reason: geometry-untrusted
held: FAIL: queue-local delivery impeded summary absent (found 0)
previous.assert rc=42

ordinary render rc=0
ordinary: deferred queue 1 (held 0)
ordinary: PASS: queued row, no impediment warning
ordinary.assert rc=0

missing render rc=0
missing: deferred queue 0 (held 2)
delivery impeded 2: queue-stalled · geometry-untrusted
20260101000000-0001-p147:dev.msg → queue-stalled ( (diagnostics unavailable; read HOLDING.log))
missing.assert rc=0

held.state-diff rc=0
ordinary.state-diff rc=0
missing.state-diff rc=0
```

`missing.outbox.json` 按 `HOLDING.log` 保留 `impeded: 2`；第一条 `diagnostic: unavailable` 且无时间，第二条仍 `available` 并显示自己的时间。三个场景分别比较了 `state/outbox` 和测试收件箱的路径与 SHA-256（含现有 `HOLDING.log` 尝试记录、诊断、正文，未新建 `delivered.log` 或 `forced.log`）；每个隔离 tmux 日志的 send/paste/load 调用数和按键记录大小均为 0。未连接真实会话或运行发送命令。

### 前两次执行记录

- 第一次正式执行已通过重建和类型检查；隔离环境下的默认 Node 包装脚本找不到 `/usr/bin/distrobox`，画面命令 rc127。已换实际的 `/usr/bin/node`；原记录保留在 `first-record.md` / `first-gate.log`。
- 第二次在 160×40 已观察到缺诊断提示中的 `diagnostics unavailable`，其末尾超出左栏，要求全文的断言返回 1。最终所有对照统一用 220×40，看到完整提示；不把 160 列的全文断言算作通过。原记录保留在 `second-record.md` / `second-gate.log`。

### 报告检查

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/verify scope=published files=2888 hits=0 names=ok user=resolved
ledger-ban rc=0
```

`git diff --check` 返回 0。

## 合并后定点复核（2026-11-19T02:48:16Z）

```text
$ TEAM_GATES='bash /var/tmp/v179-verify.TnHL8G/merged.sh' bash skills/teamsmith/scripts/team review P474 --dir /var/tmp/p474-merged-0e6677e2.zBAdGA --branch 0e6677e2085b4b60058f678039a321041581e786
门禁输出：docs/team/reviews/P474-verify.log（PASS，4s）
复验记录：docs/team/reviews/P474.md（PASS）
rc=0

scripts diff rc=0 (excluding unrelated board help wording; saved separately)
layout.ts SHA-256 a41b4a1d76a3ba3c28bf87f0f8724c67ada36543e14525374bdbfc7dcf9ac830; cmp rc=0
panel.js SHA-256 b9648e46f5a4bc994d9f6b5b5614631136cecdb3fcb4f2530a6ec07e888f7206; cmp rc=0
merged render rc=0
held: deferred queue 0 (held 2)
delivery impeded 2: queue-stalled · geometry-untrusted
20260101000000-0001-p147:dev.msg → queue-stalled (2026-01-01T00:00:03Z)
20260101000000-0002-p147:dev.msg → geometry-untrusted (2026-01-01T00:00:02Z)
merged.assert rc=0
V179 merged: PASS (same P474 bytes, one held-queue frame; fixed checkout remains clean)
```

两处 `cmp` 直接比较两个固定检出中的文件；脚本目录唯一额外差异是 P475 的 `strings/commands.tsv` 中 `board add` 帮助用词，原 diff 保存在 `merged-run/board-help.diff`，不声称整仓相同。用合并检出实际 `panel.js` 和 CLI、同一组隔离样本取一帧；原画面、无颜色版本、标准错误、断言和返回码都在 `/var/tmp/v179-verify.TnHL8G/merged-run/`。正式原件另存在 `/var/tmp/v179-verify.TnHL8G/merged-record.md` 与 `merged-gate.log`。

本轮未重做安装、类型检查、构建或候选场景；没有连接实际 Pulse、发送或改动真实状态。本人分支只提交报告，不推送、不合并、不发布。原件保留至 PM 接收。

合并证据追加后的报告检查：`git diff --check` rc0；同上 `ledger-ban` 命令 rc0，`files=2888 hits=0 names=ok user=resolved`。
