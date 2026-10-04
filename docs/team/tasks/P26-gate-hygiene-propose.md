# P26 · 门禁资源纪律：复验超时与性能断言的负载前提（propose）

```
task:   P26
agent:  verify
issue:
change: gate-hygiene
specs:  -
phase:  propose
anchor: change
deltas: openspec/changes/gate-hygiene/specs/{verification,panel}/spec.md
deps:   -
status: todo
budget: 一个工作块（只出提案包）
```

> 本地模式：不 push；分支留在 `.worktrees/verify`。**只 propose，不写实现。**

## 用户已决定的两件事（原话见 D31 之后的对话，2026-09-20）

1. **`team review` 的硬超时不该把"排队等锁"算进去**（用户选了"只写协议 + 超时不含排队"，**不**做复验插队）；
2. **性能断言要有负载前提**：机器忙时**可见跳过并记录 load**，安静机器上仍然维持原红线（首帧 2s）。

配套的过程规则（写进 `references/protocol.md` + AGENTS 模板，不是新规格）：
**全量 smoke 是整机唯一资源** —— 批内自测用 `TEAM_SMOKE_FAST=1`（不抢锁），全量只在交付前与复验时跑。

## 事故证据（提案必须引用，不能凭印象）

- **M49 复验 TIMEOUT（2026-09-20 07:49）**：`timeout 1800` 覆盖了**等锁 930s + 跑门禁**，
  真正的门禁跑到 28-i 段被 TERM 掉（`reviews/M49-verify.log`）；同一棵树、同一 HEAD 在机器安静后重跑
  **`✓ 2365 ✗ 0`、`smoke 全绿`**（`reviews/M49.md` 的 PM 收口段）。
- **同一拍的 27-d**：首帧装配 5 次采样中位 **4942ms**（样本 6335/4942/4436/5339/2880，红线 2000ms），
  当时 load average **26–32**、四个 pi agent 在跑；这正是"负载造成的假红"。
- **M47 复验**同一段时间里等了 915s 才拿到锁（但它的门禁赶在超时前跑完，判 PASS）。

## 要提案化的内容

### A. `verification`（新增 requirement + scenario）

- **复验的硬超时只覆盖门禁本身**，不覆盖排队等待；排队时长必须**单独记账并打印**（例如
  `queued 930s / ran 870s / limit 1800s`），且排队**不得**产生 TIMEOUT 判定；
- 排队等待有**独立上限**（沿用 `TEAM_SMOKE_LOCK_WAIT`，超了要**大声失败并说明是谁持锁**，不是静默降级）；
- 记录里要能区分三种结局：`PASS` / `FAIL` / `TIMEOUT(ran=…)`，排队时间不参与判定；
- scenario 至少三条：① 排队 930s + 跑 870s（上限 1800s）→ **PASS**（现在会 TIMEOUT）；
  ② 排队超上限 → 明确失败并点名持锁者（不是 TIMEOUT）；③ 门禁真跑超上限 → TIMEOUT（保持现有语义）。

### B. `panel` / 门禁的**性能断言负载前提**（新增 requirement + scenario）

- 时间敏感断言（首帧 2s、CPU 1% 这类）必须声明**前提**：机器负载低于阈值（阈值要写清，比如
  `loadavg_1m ≤ CPU 核数`）时按原红线判红；高于阈值时判**可见 SKIP**，并打印实测值 + 当时的 load，
  **绝不静默跳过**；
- 断言的红线**不许为了过测而放宽**（用户口径：安静机器上仍是 2s）；
- 仍需在**低负载**下有真实判红的能力（夹具：人为制造 >2s 的首帧 → 低负载下必须红）；
- 说明这条与既有 `panel` 性能契约 requirement（<1% 单核 / 首帧 <2s）的关系：是**前提补充**还是**改写**，
  给理由（我倾向：MODIFIED 那条，把"测量前提"写进去，而不是新加一条平行 requirement）。

### C. 过程规则（不进 spec，进文档）

- `references/protocol.md` + `templates/AGENTS.section.md.tmpl` + `AGENTS.md`：一段"全量门禁是稀缺资源"，
  明确 FAST 用于批内、全量用于交付/复验，并说明锁的存在与排队上限；
- `skills/teamsmith/SKILL.md` 的命令表在 `team smoke` 行补一句 FAST/全量的用途差别（若已有则只补排队语义）。

## Deliverables

- `openspec/changes/gate-hygiene/{proposal.md,design.md,tasks.md}`
- `.../specs/verification/spec.md`、`.../specs/panel/spec.md`（delta，明确 ADDED/MODIFIED）
- 报告 `docs/team/reports/P26-verify.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

- 只 propose：不改 `scripts/**`、`tests/**`、`extension/**`、`references/**`（apply 阶段的事）。
- **不做复验插队**（用户已否）；不改锁的默认路径 `/tmp/teamsmith-smoke.lock`；不放宽任何红线。
- 不与 M50（digest 读路径）重叠：本 change 不碰 digest。
