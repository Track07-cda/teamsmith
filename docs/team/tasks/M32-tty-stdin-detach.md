# M32 · smoke 的 tty 敏感探针自 detach stdin（PM 在 tmux 窗口直接跑门禁必绿）

```
task:   M32
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M25          # stdin=/dev/null 纪律（review 侧）；本任务修 smoke 侧对**外部** stdin 的依赖
status: todo
budget: 半个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

**事故（今天实录）**：PM 在 teamsmith tmux 窗口里直接跑全量门禁（自然姿势：`bash -c '… smoke.sh' </dev/null 之外
的 `> log 2>&1`，即 **stdin=pane pty、stdout=文件**）→ 一条红：

```
✗ 拒绝理由说明了冒充（…/mtg-user.log 中找不到 [冒充]）
```

根因（已被 PM 双向实测钉死）：

- `cmd-meeting.sh:283` 的 `--as-user` 守卫：`[ ! -t 0 ] && [ ! -t 1 ]` → 冒充消息；**只要有一个 fd 是 tty** →
  走另一条 `TEAM_MEETING_ALLOW_USER_ID` 消息（不含「冒充」）。
- tmux 窗口里 stdout 重定向到文件时：stdin=pty(y)、stdout=文件(n) → else 分支 → 断言红；
  `</dev/null` 后：n/n → if 分支 → 绿。
- `team review` 的门禁（M25 起 stdin 固定 `/dev/null`）一直是绿的——所以这条红只在**PM 手工跑**时冒出来。

判据：测试断言不许依赖**调用者**的 fd 形状。smoke 自己模拟「agent 进程」（无 tty），就该在探针层显式
`</dev/null`，与外部怎么调用无关。

## Deliverables

1. **修探针**：`skills/teamsmith/tests/smoke.sh` 的 `--as-user` 探针加 `</dev/null`（那行命令以及任何
   同类「模拟无 tty agent」的探针——自查一遍，报告列出你扫了哪些、为什么其余不需要）。
2. **回归断言**：smoke 新增一节（或并入 10c 的 tty 块）**自检本类问题**——在 smoke 内部用
   `setsid`/`script` 或 `bash -c … <tty 模拟>` 造出「stdin 是 tty、stdout 是文件」的外部形状跑一次
   `--as-user` 探针本体，要求消息仍是冒充版（即证明探针已与外部 fd 解耦）。做不到真 tty 时用 `script -qc`
   兜底并 skip 说明，报告里写清。
3. **验收姿势固化**：报告里给出两种跑法的证据——`</dev/null >log` 与 **在 tmux 窗口里 `>log`（stdin=pty）**
   ——全量 smoke 都必须 `✗ 0`。这就是回归测试。

## Boundaries (do not do)

- **不修改 `cmd-meeting.sh` 的守卫语义**（人/agent 判定与两条消息的分工是对的；错的是测试依赖外部 fd）。
- 不动 review 侧 stdin 纪律（M25）；不动投递/巡检。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 关键：在 tmux 窗口里跑（stdin=pane pty），stdout 重定向到文件 → 必须 ✗ 0
tmux new-window -d -t <你的会话（私有 socket!）> -n m32-gate "bash -c 'cd <worktree> && bash skills/teamsmith/tests/smoke.sh' > /tmp/m32-gate.log 2>&1; echo EXIT=\$? >> /tmp/m32-gate.log"
```

> tmux 纪律（记忆 #1250）：任何 tmux 调用 `env -u TMUX -u TMUX_PANE` + 私有 `TMUX_TMPDIR`，绝不碰默认 server。

## Report

`docs/team/reports/M32-dev2.md`（格式见 `templates/report.md.tmpl`）。
