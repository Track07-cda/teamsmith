# P203 · 独立验证 P201（发送者身份：主检出里的席位线索不许记成 pm）

```
task:   P203
agent:  verify
issue:
change: -
specs:  -
phase:  verify
anchor: none (infra) — 只读验证与报告
deltas: -
grant:  docs/team/reports/P203-verify.md · docs/team/reports/P203-verify/**
deps:   P155 的诊断 ✓ · P201 的实现（已合入 main ✓，提交 `05b90f4` ✓）· PM 复验（三格 scratch 探针 ✓）· D31（实现是 dev2 ✓ → 换人 ✓）
status: wip
budget: 一次对抗性验证
priority: 中高（账本作者身份 ✓；且它今天真实发生过 ✓）
```

## 要独立证明或证伪的（自己造项目，别复用 PM 的探针）

1. **三格** ✅：主检出 + 无线索 → `pm` ✓；主检出 + **席位线索**（窗口名 ✓ 与 `TEAM_AGENT` ✓ 各试一次）→ **拒绝** ✓ 且**零写入** ✓；
   显式 `--from` → 接受 ✓（既有告警保留 ✓）。
2. **线索只在命中名册时才算** ✅：`TEAM_AGENT=nosuch` ✓、窗口名不是名册席位 ✓ → **不许**拒绝（按 `pm` ✓ —— 否则会误伤 ✓）；**红侧**：把"命中名册"检查去掉 → 这条必须红 ✓。
3. **不误伤** ✅：从 `.worktrees/<seat>` 里发 ✓ → 仍记席位名 ✓；PM 自己（窗口 `pm` ✓）→ `pm` ✓。
4. **影子** ✅：把"冲突即拒绝"改回"直接 pm" → 第 1 条必须红 ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
