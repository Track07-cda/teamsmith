# P214 · 公开仓 CI 那 20 条红的定性（只读诊断，不改任何实现）

```
task:   P214
agent:  dev
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只读定性
deltas: -
grant:  docs/team/reports/P214-dev.md · docs/team/reports/P214-dev/**
deps:   **现场**：公开仓 `Track07-cda/teamsmith` 的 Actions 每次 push 都跑完整门禁，最近一次 **✓4591 ✗20**（单次约 49 分钟）。
        **我已看到的线索**：本仓现在是"内部形状"的检出（有 `docs/team`、`openspec/changes`、`AGENTS.md`、`SCOPE.md`），
        于是 `tests/lib/checkout-shape.sh` 判它是内部树，**要求** `.pi/skills/openspec-*` 与 `.pi/prompts/opsx-*` 在位 —— 而 `.pi/` 是忽略的。
        另外 `signal-lint` 的豁免清单里有一行指向 `docs/team/reports/M35-dev2/pkg/lib.sh`（**证据层已刻意不进仓库**）→ 真红。
status: todo
budget: 小到中
priority: 中高（它决定"公开仓的 CI 能不能有信誉"；不修就是永久红）
```

## 要做的（**只读**：不许改实现、不许改工作流、不许推公开仓）

1. **拿到 20 条的原文**：用 GitHub API 取最近一次失败 run 的 job 日志（`gh` 未配置就用 curl + `.github-pat`；日志接口返回的是纯文本，直接 grep `✗`）。
   逐条抄下**断言原文 + 段号**，放进报告的表格。
2. **逐条定性**（每条必须落到三类之一，并给出判据）：
   - **① 内部前提缺失**（`.pi/**` 相位命令/skill、`SCOPE.md`、内部账本等）：给出"是哪条清单/哪个函数判它是内部树"的证据（文件:行）。
   - **② 我们的排除造成的**（例如 `signal-lint` 豁免行指向已不进的证据文件）：给出文件:行 + 那条路径现在是否存在。
   - **③ 真缺陷**（产品行为错，与前提无关）：**必须在本地复现**（容器内跑那一段，附命令与输出），不许只凭 CI 日志断言。
3. **修法建议**（只写不做得）：每类给一条最小修法，并**量化**（几处改动、哪几个文件）；对 ③ 给出复现命令。
4. **不许**：改任何实现、改 `.github/workflows/**`、往公开仓推东西、把 `docs/team` 的证据层补进仓库。
5. **门禁**：本条**不跑全量**（只读诊断）；报告里点名"没跑什么、为什么"。
