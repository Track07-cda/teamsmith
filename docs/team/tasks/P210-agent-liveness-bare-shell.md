# P210 · 席位存活判据：pane 里只剩一个裸 shell 时，**不许**算"在跑"

```
task:   P210
agent:  dev3
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改存活判据与其夹具
deltas: -
grant:  skills/teamsmith/scripts/lib/common.sh · skills/teamsmith/tests/** · skills/teamsmith/references/** · docs/team/reports/P210-<agent>.md · docs/team/reports/P210-<agent>/**
deps:   **现场（PM 2026-10-04 实测）**：dev-bob 的 `pi` 早已退出（pane 无子进程 ✓、`pane_current_command=bash` ✓、最后提交 32 小时前 ✓），
        但 `team resume --dry-run` 报「**没有需要续跑的 agent（在跑 1 个）**」✗ → 它的 P103（`wip` ✓）**没被当成待续跑** ✗；
        **连带后果**：巡检因此**没有叫醒 PM** ✗（P109 的规则本该把它算成待办 ✓ ✗）—— 我漏验 P103 整整一天 ✓ ✗ 就是这么来的 ✓
status: done
budget: 小到中
priority: 中高（"停了的席位"是巡逻的核心信号之一 ✓；判错会让人**静默地**漏掉交付 ✓）
```

## 要做的

1. **先量**：`team_agent_alive_in_pane`（M37 ✓）在**这个**形状下为什么判活 ✓ —— 逐条列出它看的证据（进程名 ✓ 子进程 ✓ 命令行 ✓ cwd ✓），给出**它到底看到了什么** ✓（用 `/proc/<pane_pid>/…` 的原始输出 ✓）。
2. **判据收紧** ✅：pane 的**当前进程是裸 shell**（`bash`/`sh`/`zsh` ✓）**且**没有子进程是配置的 agent 二进制 ✓ → **判为不在跑** ✗（`foreign:`/`stopped:` 之类的既有语汇 ✓）；
   **反向**：agent 真在跑 ✓（包括**刚启动、还在读配置**的窗口期 ✓）→ 必须判活 ✓（不许误杀 ✓ —— M37 的既有承诺 ✓）。
3. **可证伪（三条）** ✅：① 裸 shell 的 pane → `resume --dry-run` 必须**列出**该席位 ✓ 且 `status` 说"停了" ✓；② 真跑着的 pane → 判活 ✓；
   ③ **影子**：把"裸 shell 也算活"改回去 → ① 必须红 ✓。
4. **连带** ✅：确认巡逻（P109 的 `--actionable` ✓）在这条修好后**会**把"席位停了 + 任务未完"算成待办 ✓（给它一条夹具 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告点名 ✓；**复验换人** ✓。
