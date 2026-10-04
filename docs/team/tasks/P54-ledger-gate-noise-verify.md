# P54 · ledger-and-gate-noise 独立验证（verify 阶段）

```
task:   P54
agent:  verify
issue:
change: ledger-and-gate-noise
specs:  verification#The container self-test's host fingerprint is stable state, and only a real host change moves it / board-and-status#Unfinished work is visible as pending wrap-up / memory-and-deps#Every machine read is a JSON document, and an empty value is a value
phase:  verify
anchor: change
deltas: verification, board-and-status, memory-and-deps
grant:  docs/team/reports/P54-verify.md · docs/team/reports/P54-verify/**（只写报告与证据，不改实现）
deps:   P43（propose）· **P47（apply，dev-bob）**——apply 作者不是你
status: todo
budget: 一个工作块（只写复验证据与报告）
```

> 本地模式：不 push。

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **指纹（`--fingerprint-check` 与 `--selftest`）**：自己跑四条腿（风暴不变 / 杀范围内 server 变 /
   真会话变化变 / 无 server 只读同值）；**再自己造两条旧形状的反例**：
   ① 一个只在**命令行里提到 tmux** 的 shell（`bash -c 'echo tmux'`）不许移动值；
   ② 一个 **ppid=1 的真 server**（`tmux new-session -d`）必须**进入**指纹（旧实现漏它）。
2. **记录可见性**：主检出 + **每个 worktree** 的未入账 review/report/包内文件都要被点名（含 `<agent>:` 前缀）；
   **反向**：把记录提交（或删掉）→ 警告消失；**不许**把普通脏文件误报成记录。
3. **JSON 契约**：`config list --json`（含 `TEAM_AGENT_MODELS='dev='` 的空 override 形状）、`change status --json`、
   `paths`、`monitor --json`、`__panel-data` —— **每个出口一份可解析 JSON**；
   **自己造一次坏**（例如把某字段序列化改回无值形状）→ 门禁那条断言必须**红并点名命令与位置**。
4. **零回归**：`smoke`（FAST + 全量）、`tmux-lint.pl`、`container-tmux.sh --selftest`（宿主指纹逐字节不变）、
   `config-cli.sh`、`panel-choices.sh`、`panel-p21.sh choices`。

## 至少三条变异（红→绿原始输出）

- 把指纹的 socket 作用域改回全机 `ps` 快照 → 风暴腿红；
- 把记录扫描退回只扫主检出 → worktree 断言红；
- 把空 override 的序列化退回旧形状 → `json.tool` 那条红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
