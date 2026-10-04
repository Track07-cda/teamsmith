# P110 · `gate-section-accounting` 返工：小数 band 的警告必须真的会打 + escalation 的归因不许撒谎

```
task:   P110
agent:  dev2
issue:
change: gate-section-accounting            # P108 独立验证 PARTIAL（2 条 finding，PM 已逐条复核并维持）
specs:  verification#（门禁的段落账目/预算/超时点名）
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/lib/section-guard.sh · skills/teamsmith/tests/section-guard.sh · skills/teamsmith/tests/section-budgets.tsv · skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/*（夹具）· openspec/changes/gate-section-accounting/specs/verification/spec.md（只在措辞确实需要时）
deps:   P70（你的 apply，已合并）· P108（独立验证报告 + 证据包 docs/team/reports/P108-dev-bob/）
status: todo
budget: 一个工作块
priority: 中高（归档前的门；F2 是"规范承诺了却永不可达"）
```

> 本地模式：不 push。**先 `git merge main`**（main 上有 P95/P99/P105/P106 的段，以及 P98 尚未合并）。

## F2（我复核过，成立）· 小数 band 的「超过实测带」警告**永不打印**

`lib/section-guard.sh` 的守卫：`case "${SG_BAND:-}" in ''|*[!0-9]*) ;;` —— 含 `.` 的 band 落进**空分支**，
而表里 **110/112 行**的 band 是小数（`0.02`…`44.00`；只有 §50/§51 是整数）✗。规范的原话是
"a section that closes above its recorded band SHALL print one warning line" → **对 110 行不可达** ✗。

要做：
1. 比较改成**数值比较**（例如 `awk -v a="$elapsed" -v b="$SG_BAND" 'BEGIN{exit !(a+0 > b+0)}'`），
   行为不变：**记录，不是判定**（不许接进红标/退出码 ✓ D33）；
2. 自检/夹具**必须用一个小数 band 的形状**钉住它（现在的 `_sg_selftest_case clean` 用 `SG_BAND=0` 整数 —— 这正是漏掉它的原因）；
3. 红侧：把比较还原成整数守卫 → 那条"band 被超过"的夹具**必须红**；
4. 顺带核对：**整数 band**（§50/§51）行为不变 ✓。

## F1（我复核过，成立）· escalation 的归因把"grace 用尽"说成"忽略 TERM"

`section-guard.sh:465-466` 打「段落 #N 的**子孙忽略 TERM** → 已发 KILL」，而现场里明明有 `Terminated sleep 3`
（子进程**响应了** TERM ✗）。现象不是行为错，是**现场在撒谎**（我们的 creed：失败必须可见且**诚实**）。

要做：
1. 措辞改成**只声明你确实知道的**，例如「grace 用尽 → 已发 KILL（是否忽略 TERM 由现场判定）」，
   或者**先判**再写（有 `Terminated`/无 `Killed` 证据时不得说"忽略"）；
2. 夹具：`--desc-grace 2` + 一个**响应 TERM** 的子进程 → 断言那行**不再**说"忽略 TERM"（红侧：还原措辞 → 红）；
3. 不许删掉现场（KILL 仍要发、现场仍要留 ✓）。

## 通用

- 跑：`--budget-check`（112/112 ✓）· `--loop-check` · 段落模块自检 · `routes.sh` · **FAST 全绿** · `openspec validate --all --strict`；
- 报告给**红/绿原始输出**；delta 只在措辞确实需要时改（改则说明）。
