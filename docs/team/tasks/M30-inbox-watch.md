# M30 · 投递换道：收件箱监视唤醒取代输入框粘贴（pi 通道废弃框侦探）

```
task:   M30
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M27          # team-bg.ts 刚交付，复用其会话内 sendMessage 模式；本任务等 M27 合并后开工
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context

draft-race 误判第五起（今天 05:58，M24 修复后仍发生，payload 460 码点无 emoji——夹具存
`docs/team/tasks/M30-evidence-payload.msg`）。**用户拍板：不再修框检测，换道**（原话：「如果不好修就移除
检测，直接推荐用户在 pulse 中进行消息的发送」——本设计是对这句话的实现，唤醒用扩展而不是等 pulse 拍，
pulse 降为保底）。

设计（E8 §2.2/§5 已实测全部前提）：

1. **pi 通道的投递 = 收件箱文件 + 会话内监视唤醒**，完全不碰输入框：
   - 新扩展 `skills/teamsmith/extension/team-inbox-watch.ts`（~40-60 行，照 `file-trigger.ts` 形态 +
     team-notify.ts 的守卫风格）：随 dispatch/PM 启动以 `-e` 注入；`fs.watch` 本项目
     `.pi/team/state/inbox/`（注意去重与队列目录细节，以实际布局为准）；新文件 → 读一行摘要 →
     `pi.sendMessage({customType:'team-inbox'}, …, {triggerTurn:true, deliverAs:'followUp'})`。
   - outbox 投递端（`outbox.sh`）对「目标是装了本扩展的 pi 会话」**只写收件箱，不再粘贴**；粘贴路径
     （含 M17/M24 的守卫与收回）保留给非 pi adapter 与显式 `--paste` 逃生门。
2. **判定「目标是 pi 且有监视」**：优先确定性强的方式（扩展在 state 里写心跳/就绪文件，或 dispatch 时记录
   adapter=pi 即可——选简单可靠的，报告里说明取舍）。
3. **pulse 保底不动**：节拍照常扫未读；面板收件箱块不动。
4. **退役边界**：框侦探/收回代码从 pi 投递路径摘下（非 pi 保留）；smoke 里对应断言改为「pi 通道不发
   tmux 粘贴」+「非 pi 通道守卫照旧」。

## Deliverables

1. `extension/team-inbox-watch.ts` + 注入链（dispatch 与 PM 启动）。
2. `outbox.sh` 投递分流（pi+watch → 仅收件箱；否则老路）。
3. smoke：新断言——pi 通道投递**零 tmux 粘贴调用**（用 PATH shim 记录 tmux 调用断言无 send-keys）、
   新文件落盘→监视扩展产出唤醒消息（可用假 pi/RPC 探针形态，E8 probes 可改造）、非 pi 通道守卫回归照旧。
4. 文档：`references/agent-adapters.md` 通知一节改写（双通道：watch 唤醒为 pi 默认、粘贴为非 pi/逃生门）；
   `references/troubleshooting.md` 把五次 draft-race 事故写进「为什么 pi 通道不碰输入框」。

## Boundaries (do not do)

- 不动 team-notify.ts 的回合结束通道（worker→收件箱本来就可靠）。
- 不动 pulse 巡检语义；不删 outbox 的 held/审计日志（事故复盘价值）。
- 收回/守卫代码不物理删除（非 pi 路径还在用），只是从 pi 投递路径摘下。
- 唤醒消息只带一行指针，不带 payload 全文（全文在收件箱；防注入习惯不变）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 端到端实录：假 worker 投递 → PM 会话零粘贴被唤醒 → PM 读到收件箱（RPC 日志或等价证据）
```

## Report

`docs/team/reports/M30-dev2.md`（格式见 `templates/report.md.tmpl`）。
