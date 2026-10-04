# spec-backfill-2026-09 · PM proposal review

time: 2026-09-21T11:0x:00Z · reviewer: pm · verdict: **ACCEPTED**

```
change:  spec-backfill-2026-09
owner:   dev-bob（propose）
tip:     e0b6e1f（task/M61-2026-09）
user:    spec 政策 B（2026-09-20「一：按照你的建议」）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 19 passed, 0 failed
$ git status --porcelain                                         → 0
# delta 规模：boundary 3R/12S · verification 1R/3S · delivery-guard 1R/5S · board-and-status 3R/10S · panel 2 MODIFIED (11S)
# panel 的 MODIFIED 逐条比对 base：board 页 5→6 scenario（丢失 0）、work 页 4→5（丢失 0）
```

## Findings

1. **六条减成五条，理由成立（D2）— PASS。** 我任务书里写的第 6 条（投递降级）要求"先核对、已覆盖就不要再写"；
   它核对到 `watch-degradation` 的 delta（并跟踪到归档后的 land spec），**明确不写**，避免了两份 change 在归档时
   ADDED 同一 requirement 的碰撞。这是"少写一条"而不是"漏写一条"，并给了证据行号。
2. **面板两条走 MODIFIED 是对的（D3）— PASS。** base 里"焦点按裸 id 追踪"在 M48 之后**已经错了**；
   正确处理是改写那句 + 加一条 scenario，**base 的 5+4 条 scenario 全部原样保留**（我逐条比对过）。
   若改成 ADDED，错误的句子会留在规格里 —— 这条判断很关键。
3. **只钉"封闭 token"（D4/D5）— PASS。** 退出码 64、`TEAM_ALLOW_DESTRUCTIVE_TMUX=1`、`act=refused|override|pass`、
   日志上限 2000/1000、`EMPTY`/`HOLDS_ONLY=yes`/`RETRACT=ok`/`banner=present|absent`、`--allow-dup`、`board assign`、
   `TEAM_SCAN_CACHE=0`、≤1/≤50 次 git 调用 —— 都是工具/gate 已经定义的枚举；**不冻结实现文案**，也不加时间红线
   （与 D33 的一致性守住了：读预算用**调用计数**）。
4. **证据地图可复核 — PASS。** 每条 requirement 都给了 `文件:行` 与**独立复核方法**；apply 计划是"逐行核对证据、
   代码与契约矛盾时写 `BLOCKED:` 交回 PM、不许顺手改行为"。
5. **风险表诚实 — PASS。** 尤其"环境相关证据可能是空跑"这条：横幅夹具必须报 `present|absent`、容器段是**可见 SKIP**。
6. **它抓到的红成立，且已由 PM 修掉** — §33 completeness（我加的 3 条文档键没登记 schema）。
   修复：`9c943e2`（登记 schema，测试旋钮按 `TEAM_SMOKE_FAST` 先例设为 `refuse`）+ `9e7c990`（补 zh/en 标签，en ≤22 格，
   重建 bundle）。证据：`config-cli ✓116 ✗0`、`panel-choices ✓35 ✗0`、`panel-strings ok`（111 键）、FAST smoke `✓2224 ✗0`。
7. **一个附带 finding（PM 记，不在本 change 内）**：`tests/config-cli.sh` 的完整性检查里**前缀豁免是死代码**
   （`grep -vxE 'TEAM_PULSE_|…'` 的 `-x` 让它永不匹配）。我没有放宽它（那会削弱既有保证）；记为后续项。

## 结论

**ACCEPTED**。apply = 证据核对（不改行为）；verify 必须换人。

## CI 确认（2026-09-21）

- 归档批次的推送 run **`35584703749` = failure**（§33 completeness，即本记录第 6 条的红）；
- 修复推送后的 run **`35588949737` = success**（钉死容器：Build the gate image ✓ + Gates ✓）。
  即：**main 在钉死容器里已恢复全绿**，本记录第 6 条的修复闭环。
