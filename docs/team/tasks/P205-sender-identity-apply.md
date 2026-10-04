# P205 · `sender-identity-refusal` apply：实现与规范对齐（含提案里那四个边界）

```
task:   P205
agent:  dev                         # 与 P204 的提案作者不同（dev2）✓
issue:
change: sender-identity-refusal      # 提案已验收并合入 main
specs:  notify-and-inbox#A manual notification is attributed to its sender
phase:  apply
anchor: change
deltas: notify-and-inbox
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · skills/teamsmith/references/** · openspec/changes/sender-identity-refusal/** · docs/team/reports/P205-dev.md · docs/team/reports/P205-dev/**
deps:   `openspec/changes/sender-identity-refusal/tasks.md`（**按它的 1.1–4.4 逐条做** ✓）· P201 的实现（在 main ✓）· P203 的独立验证（16 格 ✓ + F1 ✓）
status: todo
budget: 一个工作块
priority: 中高（规范与行为对齐 ✓；且提案点出了 P201 没被要求处理的边界 ✓）
```

## 要点

1. **先核基线**（1.1–1.3）✅：delta 与**将被替换**的那条 requirement 对齐 ✓（**基线场景一条不丢** ✓）。
2. **边界实现**（2.x）✅：提案新增的七条 scenario 里，凡**当前实现不满足**的都要实现 ✓ —— 特别是：
   **窗口线索是调用者自己的 pane（不是客户端当前窗口）** ✓、**别的会话同名窗口不算线索** ✓、**名册外名字不算线索** ✓、
   **显式 `--from` 仍胜** ✓、**席位工作树不被拒** ✓；四条影子（2.2–2.5）各要红侧 ✓。
3. **预演**（3.x）✅：在 scratch 树里试归档 ✓（不许在真树上试 ✗）。
4. **门禁**（4.x）✅：`validate --all --strict` ✓ + `spec-refs.sh --check` ✓ + 容器 FAST ✓ + **容器内全量** ✓（改了脚本层 ✓）。
5. **报告**点名"哪些自己跑、哪些引用" ✓；**复验换人** ✓。
