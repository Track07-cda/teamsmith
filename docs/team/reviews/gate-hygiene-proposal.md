# gate-hygiene · PM proposal review

time: 2026-09-20T08:4x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  gate-hygiene
owner:   verify（propose）
tip:     b32de42（task/P26-propose）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
  → Totals: 15 passed, 0 failed (15 items)        # exit 0
$ git -C .worktrees/verify status --porcelain | wc -l   → 0
```

## Findings

1. **需求形状对 — PASS。** `verification` **ADDED 1 条**（「硬超时覆盖门禁运行、不覆盖排队」）+ `panel` **MODIFIED 1 条**
   （既有的「帧装配异步/缓存/不阻塞输入」那条被改写加上**测量前提**，而不是新加一条平行 requirement）——
   与我在任务书里写的偏好一致，也符合政策 B（契约改在既有的家）。
2. **三条关键 scenario 齐 — PASS。** ①长排队不消耗运行预算（930s 排队 + 870s 运行 / 上限 1800s → **PASS**，
   现在会 TIMEOUT）；②排队超上限 → **明确失败并点名持锁者**（不是 TIMEOUT）；③**真跑超限仍是 TIMEOUT**（语义不变）；
   另加两条：已持锁的子套件**不再二次排队**、无排队机制时**打印降级**（不静默）。
3. **性能断言的前提可证伪 — PASS。** 阈值 **`loadavg_1m ≤ 0.75 × 逻辑核数`**（32 核 → 24），
   **用事故标定**（M49 假红发生在 load 26–32）；低于前提时 **2s 红线照旧判红**（scenario「A quiet machine still fails a slow frame」），
   高于前提时打印 `SKIP（负载前提不成立：loadavg 26.0 > 0.75 × 32）`；`panel-cpu.sh` 用 **exit 4** 表示"因负载跳过"，
   保证任何包装器**无法把跳过当通过**；同一前提也覆盖稳态 CPU 那条线。
4. **红线没有被放宽 — PASS。** design §4 明写「阈值不动」；任务书要求的"低负载下仍能判红"由 2.4/2.5 的注入夹具 + 双向翻转兜住
   （always-skip → 红；always-judge → 红，两条互为反例）。
5. **没有复验插队 — PASS。** §1 只把排队变成**记账阶段**，锁路径与上限沿用现有键（`TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT`），
   并保留 M23 的 `--close` 语义（子进程不继承锁 fd），未引入优先级。
6. **文档批（G4）在计划里 — PASS。** `references/protocol.md` §9b + `templates/AGENTS.section.md.tmpl` + `AGENTS.md`：
   「全量门禁是整机唯一共享资源；批内 FAST、交付/复验才全量」——按政策 B 这属**过程规则**（不进 spec），放在文档里是对的。
7. **翻转要求齐 — PASS。** 每批都有红→绿与反向翻转（1.6 / 2.5 / 3.4），且 tasks.md 明确 `[real]` 的真路径检查（1.7）。

## 注意（交 apply 时我会盯的两点）

- 记录词汇**保持闭集**（`PASS|FAIL|TIMEOUT`）：排队超限走 `FAIL` 而不是新造 token，`ran=…` 写在粗体 token **之外**
  （`team_review_verdict` 的正则按 `**TOKEN**` 解析，design §3 已说明）——apply 时不得改动判定的正则兼容性。
- `TEAM_SMOKE_LOADAVG` / `TEAM_SMOKE_FRAME_DELAY_MS` 这类**夹具旋钮**必须在真路径下**不生效**（只能由夹具注入），
  否则"负载前提"会变成"想跳就跳"的后门——这一条我会当作独立复验要点。
