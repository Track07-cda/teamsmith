# P206 · `sender-identity-refusal` 独立验证（apply 是 dev → 换人）

```
task:   P206
agent:  verify
issue:
change: sender-identity-refusal
specs:  notify-and-inbox#A manual notification is attributed to its sender
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P206-verify.md · docs/team/reports/P206-verify/**
deps:   提案（P204 ✓ 已验收）· 实现 **P205**（已合入 main ✓）· PM 复验（§47 ✓102 ✗0 · flip ✓21 ✗0）· D31（实现是 dev ✓ → 换人 ✓）
status: wip
budget: 一次对抗性验证
priority: 高（它是该 change 归档的唯一前置 ✓）
```

## 要独立证明或证伪的（自己造项目，别复用作者的夹具）

1. **四条新边界** ✅（逐条自建）：① 窗口线索取**调用者自己的 pane** ✓（构造"客户端当前窗口是 pm、但调用者 pane 是 dev"→ 必须**拒绝** ✓）；② **别的会话同名窗口不算线索** ✓（→ 按 `pm` ✓）；
   ③ **名册外的名字不算线索** ✓（→ `pm` ✓，不许误伤 ✓）；④ **席位工作树不被拒** ✓（→ 记席位名 ✓）；⑤ **显式 `--from` 仍胜** ✓（→ 记显式名 + 既有告警 ✓）。
2. **拒绝的形状** ✅：非零退出 ✓ + 点名两个名字 ✓ + **零写入**（收件箱与 outbox 都不动 ✓）+ 两条出路 ✓。
3. **影子（两条）** ✅：把"命中名册才算线索"去掉 → 用例 ③ 必须红 ✓；把拒绝的目录前提去掉（任何目录都拒）→ 用例 ④ 必须红 ✓。
4. **不破既有** ✅：从 `.worktrees/<seat>` 里发 ✓、PM 从主检出发（无线索 ✓）、`--from` 分歧告警 ✓ 都照旧 ✓。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 47` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
