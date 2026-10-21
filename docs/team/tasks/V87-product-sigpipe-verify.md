# V87 · P350 的独立验收：产品里那两处管道判定

task: V87
agent: dev2
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 两处产品管道的判定
deltas: -
branch: task/V87-product-sigpipe-verify

## 受检

候选 `03d29158`（`common.sh` +11/−3、`cmd-status.sh` +12/−4），报告 `docs/team/reports/P350-dev-bob.md`。改法同一范式：先把被匹配的数据落进变量，再从 here-string 匹配；判据一个字没放宽。

作者自报的三个读数：`common.sh` 长标题流改前 30/30 误判、短标题流 30/30 判对、改后 30/30 判对；`cmd-status.sh` 直读腿与缓存腿（lookback 200 正确、400 误判）改前都有错、改后三种配置 30/30；把管道写回私有副本后两个红侧立刻恢复。

## 要回答的四件事

1. **判定没被放宽**：读两处的新判据，确认仍等价于原来的「精确匹配/带边界匹配」，没有变成「包含即通过」；给出一两个反例（近似的树哈希、近似的 id 前缀）**都必须不命中**。
2. **红侧自己复现**：在你自己的私有副本里，把这两处**改回管道写法** → 必须复现「长标题流误判」与「lookback 400 误判」；贴读数。这是证明「改的是根因」的唯一硬证据。
3. **`ls 2>/dev/null || true` 那处**：它在 diff 里新出现（`trees="$(git … || true)"` 带一行注释「留：查不到=空答案（不是故障）」）。判断这个 `|| true` 是否合法（按项目纪律：能一句话点名那个失败才允许留），并核「查不到 → 空答案」这个语义是否与原实现一致（原来是 `git … 2>/dev/null | grep -qx`，若 git 失败则 grep 得空、判「不在」——确认新写法同样判「不在」而不是判「在」）。
4. **没有别的行为变化**：这两处被哪些命令使用（`grep -rn` 找调用点），说明修复对这些命令的用户可见效果（例如已 squash 的分支不再被报「领先 N」）。

## 边界

只读代码、只在 `/var/tmp` 私有副本里造破坏、只写 `docs/team/reports/V87-dev2.md` 与自己的线程；不改实现、不合并、不 push。不跑整套；受影响选段若要跑，先 `ps` 确认没有别人的 `smoke.sh`。结论先写 PASS/PARTIAL/FAIL。local 模式。
