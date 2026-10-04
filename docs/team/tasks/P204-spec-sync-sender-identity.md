# P204 · `sender-identity-refusal` propose：把 P201 的行为写进契约（主检出 + 席位线索 = 拒绝）

```
task:   P204
agent:  dev2                        # propose 只写 openspec/changes/**（不违反 D36）
issue:
change: sender-identity-refusal
specs:  notify-and-inbox#The sender is resolved from the runtime directory, never from the recipient
phase:  propose
anchor: change
deltas: notify-and-inbox
grant:  openspec/changes/sender-identity-refusal/** · docs/team/reports/P204-dev2.md · docs/team/reports/P204-dev2/**
deps:   **P203 的独立验证 F1**（`docs/team/reports/P203-verify.md` ✓）：`openspec/specs/notify-and-inbox/spec.md:530-541` 仍承诺
        「主检出 → `pm`」与「`TEAM_AGENT` 分歧 → **目录赢**（点名但照记）」✗ —— 而 **P201**（已合入 main ✓ `05b90f4` ✓）把
        **主检出 + 席位线索**改成了**拒绝** ✓ → **契约文本落后于行为** ✗（D31 的"契约=规范"要求补齐 ✓）
status: todo
budget: 一个小提案
priority: 中高（规范漂移 ✓；它不影响发布门禁 ✓ 但必须在下次归档前补齐 ✓）
```

## 要 propose 的（**照 P201 的裁定** ✓，不许另立一套 ✗）

1. **MODIFIED** 那条 requirement ✓：把"线索清单"与"冲突即拒绝"写清 ✓ ——
   线索 = 运行时目录 ✓ / 窗口名 ✓ / `TEAM_AGENT` ✓（后两者**仅当命中本名册** ✓）；
   **主检出 + 席位线索 → 非零退出、点名两个名字、**不写任何行** ✓；主检出 + 无线索 → `pm` ✓；显式 `--from` → 照旧接受并点名分歧 ✓；
   从 `.worktrees/<seat>` 调用 → 席位名 ✓（不变 ✓）。
2. **MODIFIED 必须抄全基线 scenario** ✓（一条不丢 ✓）——P184/P185/P198 那一族教训 ✓；给**前后场景计数对照** ✓。
3. **可证伪**：每条 What-flips 有红侧 ✓（尤其"命中名册才算线索" ✓ —— 否则误伤 ✓）。
4. **不许**扩大射程 ✗：只改这一条 requirement ✓；`meeting` 侧的"记录名并集"（P134 ✓）**不许**动 ✗。
5. 交付：`openspec/changes/sender-identity-refusal/{proposal,design,tasks}.md` + `specs/notify-and-inbox/spec.md` ✓ +
   `openspec validate --all --strict` ✓（22 项全绿 ✓）。
