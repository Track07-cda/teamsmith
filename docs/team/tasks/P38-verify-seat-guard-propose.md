# P38 · dispatch 守卫：实现任务不得派给 verify 席位（propose）

```
task:   P38
agent:  dev3
issue:
change: dispatch-verify-seat-guard
specs:  -
phase:  propose
anchor: change
deltas: dispatch, verification
deps:   OWNERSHIP.md（verify 不改实现）· M53（先例）· P36（我第二次犯）
status: todo
budget: 小（一个提案包；1–2 条 requirement 改动、5–10 条 scenario）
```

> 本地模式：不 push。**只 propose。**

## 要解决的事（D36）

`OWNERSHIP.md` 明文：**verify 席位不改实现**（独立性的来源）。但 `team dispatch` **不拦**——
PM 连着两次（M53、P36）把 apply 任务派给 verify，都被席位自己按 OWNERSHIP 拒掉。
**人肉记忆不够，要守卫。**

## 提案要裁决的设计

1. **判据**：目标席位 = `verify`（可配置？`TEAM_VERIFY_SEAT`？还是读 `TEAM_AGENTS` 里名为 verify 的席位）
   **且** 任务书 `phase: apply` → **拒绝**，报错点名 OWNERSHIP 的行与两条出路（换席位 / 把 `phase:` 改成
   `verify` 并只做验证）。要裁决的边界：
   - `phase:` 缺失但 `grant:` 里列了实现路径（`skills/**`、`scripts/**`、`extension/**`）→ 拦不拦？
     （用户口径：**拦**，但报错要说清"你列了实现路径"）；
   - `phase: verify` / explore / docs-only 任务 → **放行**；
   - 纯文档任务（`docs/team/**`、`openspec/**`）→ 放行（verify 写过提案评审与勘察）。
2. **覆盖口**：`--force` 允许（留审计行），并说明"什么情况下该用"（例如 verify 席位临时改行做实现——
   那应该换席位，所以文档里建议：**别用**）。
3. **规格落点**：`dispatch` 能力补 scenario（拒绝的形状 + 放行的形状 + `--force` 的审计），
   `verification` 的"不得自验"旁边补一句**角色边界**（verify 席位的独立性还包括"不参与实现"）。
4. **红侧**：把守卫拆掉 → 夹具红；`phase: verify` 的任务仍放行（反向夹具）。
5. **文档**：`references/protocol.md` 的 dispatch 段 + `OWNERSHIP.md` 的 verify 行各加一句指向守卫。

## 硬要求

- policy B：delta 落 `dispatch`（+ `verification` 一句），每条可证伪；MODIFIED 不删 base scenario；
- 每条 requirement 给复核方法；
- **不写实现**；发现现实与 D36 冲突 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/dispatch-verify-seat-guard/{proposal.md,design.md,tasks.md}`
- `openspec/changes/dispatch-verify-seat-guard/specs/{dispatch,verification}/spec.md`
- 报告
