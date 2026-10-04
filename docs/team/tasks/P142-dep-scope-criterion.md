# P142 · 判据修正：`14b` 的 dep-scope 检查要按"主题"判，不按"工具名"判

```
task:   P142
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改门禁判据本身与其翻转自测
deltas: -
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/tests/** · docs/team/reports/P142-dev.md · docs/team/reports/P142-dev/**
deps:   P137 的 FINDING F1（实测：PM 自己的一段 harness 说明被误报 ✅）· **它自己的翻转自测已经预期"harness 语境应当被豁免"** ✅
status: wip
budget: 小
priority: 中（每次全量门禁都会踩这两条假红 ✅）
```

## 现场

`14b` 的 `dep_scope_hits` 用**工具名白名单**做豁免 ✅（`container-tmux.sh|team perf|perf.sh|TEAM_PERF|性能套件`）。
PM 在 `references/troubleshooting.md` 里写了一段**讲门禁套件在钉死镜像里跑**的排障说明 ✅ ——
主题是 **harness** ✅，但句子里没有那些工具名 ✅ → 被判「文档还在把容器当依赖」✗（`eb25b765` 引入 ✅）。
PM 已用**最小改动**让该句点名 `tests/smoke.sh` / `tests/perf.sh` / `tests/container-tmux.sh` ✅ → 当前 main 上 `14b` **26 ✓ 0 ✗** ✅。
**但判据本身仍是错的** ✅：下一个写 harness 说明的人还会踩 ✗ —— 而且**它自己的翻转自测就写着"harness 语境应当被豁免"** ✅（第二条假红正是"翻转自测：测试 harness 的容器说明被误报" ✅）。

## 要做

1. 让判据按**主题**判：一行若在讲**测试 harness / 门禁套件**（可以点名 `tests/**`、`smoke.sh`、套件/夹具语境 ✅，具体形式你定 ✅）
   → **不算**"文档把容器当依赖"；
2. **反向必须有牙**：一行在讲**产品本身**跑在/需要容器 ✅（例如"看门狗跑在容器里"或"装 teamsmith 需要 podman"）
   → **仍必须红** ✅；
3. 更新两条翻转自测 ✅ 使它们**真的**检验上面两条 ✅（现在的第二条之所以红，正是因为注入的 harness 文案没有工具名 ✅；
   如果你把判据改成按主题判 ✅，它应当**自然变绿** ✅ —— 报告里给出红→绿的前后对照 ✅）；
4. 报告写清：这次改的是**判据**不是文案 ✅，并列出改后仍会红/不再红的**具体句子** ✅。

## 门禁

`--select 14b` ✅（应 26 ✓ 0 ✗ 或更多断言 ✅）+ `openspec validate --all --strict` ✅ + FAST ✅（不用全量 ✅）。
