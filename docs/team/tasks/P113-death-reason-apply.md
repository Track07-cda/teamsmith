# P113 · `agent-death-reason` apply（席位死因：闭集分类 + 一次通报）

```
task:   P113
agent:  （等席位；**不能是 verify 席**——D36 的守卫会拒 apply）
issue:
change: agent-death-reason        # 提案已验收：docs/team/reviews/agent-death-reason-proposal.md (ACCEPTED)
specs:  watchdog#（闭集分类 + 当前一次死亡 + 可见面）· notify-and-inbox#（异常死亡恰好一次 knock）· panel#（agents 块带 cause）
phase:  apply
anchor: change
deltas: watchdog, notify-and-inbox, panel
grant:  skills/teamsmith/scripts/lib/*.sh（分类助手 + status/digest 行 + 巡逻的 knock）· skills/teamsmith/scripts/panel/**（agents 块）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/tests/**（夹具）· skills/teamsmith/references/{troubleshooting,config}.md（需要时一句）
deps:   P101（propose=verify，已合并）· P49/P55（死 pane 遗体与 pane_dead 证据已存在）· M6.5（**一字不改**）
status: todo（等席位）
budget: 一个工作块
priority: 中高（今天的痛点：只知道"停了"，不知道为什么）
```

> 本地模式：不 push。**CI 不再作为判据**（D54，额度已被我烧光）——本地门禁才是决定性证据 ✓。
> 真源 = `openspec/changes/agent-death-reason/{design.md,tasks.md}`（**逐条兑现 6 条 requirement**）。

## 硬要求（照提案的 15 条场景实现，别自创口径）

1. **闭集**：`quota · balance · rate_limit · window · auth · normal · unknown` —— **匹配不上就是 `unknown`，绝不编造** ✓；
   判定只读**有界尾部**且要**供应商错误形状**；**必须**覆盖两条反例：① 看起来像 auth 的供应商帧**仍归 quota**；
   ② **仅仅提到某个词的散文不算分类** ✓；
2. **缺证据 → `unknown`**（两个证据源缺一即 unknown ✓，绝不猜）；
3. **只对当前这次死亡生效**：重启**不继承**旧因 ✓ · 同一次死亡跨 tick **一个身份** ✓ · 重启后的第二次死亡是**新**死亡 ✓；
4. **可见面**：`team status`（分类 + **来源** + **原始行**）· `team digest`（计数旁点名分类）· 面板 agents 块（`cause` 键；
   **运行中的席位不带 cause** ✓）；
5. **通报**：**异常死亡恰好一次** knock（含 `unknown`——报但**不假装知道** ✓）；**正常退出静默** ✓；
   一次死亡跑三个 tick → **恰好一条** ✓；**standby 时顺延而不是丢** ✓；无来源可读 → **点名而不重复 knock** ✓；
6. **不许碰的**：M6.5 的存活判据（`running/dead/foreign/unknown` 的规则）**一字不改** ✓ · **不做自动 fallback** ✓ ·
   不改 `[auto·interrupted]` 标记 ✓ · 不放松任何既有断言 ✓。

## 交付与验收

- 新断言的**红侧**：至少三条（分类器影子成"永远 unknown" → 合成额度帧那条红；把"粘"的行为还原 → 重启继承那条红；
  把去重去掉 → 三次 tick 变三条 knock 那条红 ✓）；
- 跑：`openspec validate --all --strict` + **FAST 全绿** + 你判断需要的段（`section-select.sh --paths` 可用 ✓）+ 一次全量；
- 报告写明"哪些是你的证据"并附**红/绿原始输出**；delta 只在措辞确实需要时改。
