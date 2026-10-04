# M24 · PM 空闲时空框仍 draft-race + 收回零成功：投递守卫误判调查

```
task:   M24
agent:  dev2
issue:  
change: -            # OpenSpec change id this brief implements (`openspec list`, e.g. add-agent-timeout); "-" if no requirement changes
specs:  -            # requirements/scenarios it must satisfy, e.g. `dispatch: a brief is self-contained`; "-" if none
phase:  -            # OpenSpec pipeline phase this brief runs: explore|propose|apply|verify|archive ("-" for work outside the pipeline); one phase = one brief = one owner
deps:   M20          # 你手上 M20 复验合并完再开工；本任务现场在 outbox.sh，和 smoke 不撞
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev2` 工作树即可，PM 复验后本地合并。

## Context

今天同一族事故第三次（M17 合并**之后**仍在发生）：

1. 12:31Z dev2 的 M20 交付敲门投递到 PM 窗口，被判 draft-raced；payload 留在框里（`draft-raced-left`)。**当时 PM 会话空闲、输入框本应是空的**（上一轮结束于 10:55Z)。
2. 框被这团残留占着，之后 8 条 pulse nudge 全部 held(`expired-ttl`)，直到用户手动按 Enter——等于**一次误判把叫醒通道堵了 25 分钟**。
3. outbox 统计：held 条目的残留分档「已收回 0 · 留在框里 1 · 其它 8」——**M17 的收回从来没成功过一次**。rc=3 的设计是「框里混了人的字就一个键都不碰」，但 PM 空闲空框不该是这种形状。

怀疑方向（都要用夹具实测证伪/证实，不许只推理）:
- 空闲 pi 窗格的输入框在 `capture-pane` 里到底是什么形状——占位符/状态栏/光标行有没有被框内容检测（`team_box_*`）误读成「有内容」或「混了别人的字」;
- draft-race 的判定窗口期：粘贴发起时的框快照 vs 复检快照，中间 TUI 自己的重绘（时钟行/状态刷新）会不会把「只有我们的 payload」误判成 race;
- 收回函数 `team_tmux_retract` 的清键序列在真实 pi 编辑器上的实际效果（M17 的假 TUI 夹具建模了光标与清键，但真实 pi 有没有差别——比如 bracketed paste 标记残留、placeholder 重绘）;
- 取证钩子：默认关的 `TEAM_RESUME_DEBUG` 覆盖不到投递主路径——如需，给投递守卫加同款的取证日志（默认关），让下一次现网事故有数据。

现场数据：`.pi/team/state/outbox/HOLDING.log`、`delivered.log`、held 条目（已被人 drop，但日志在）;12:31Z 事故的 outbox 条目号 1789642271686-0001-teamsmith:pm.msg。

## Deliverables

1. 根因报告：上述三个怀疑方向逐个证实/证伪（夹具实测，含真实 pi 窗格，不只假 TUI)。
2. 修复：让「PM 空闲空框」的敲门投递不再误判 race；收回在该形状下必须真的收回（或证明收回失败的形状并堵掉）。
3. 翻转证据：夹具在修复前复现误判（红）、修复后同形状绿；收回成功的残留分档从 0 变成有。
4. 若根因不在 outbox.sh（比如在更底层的 tmux 探测），报告写 BLOCKED 交回 PM。

## Boundaries (do not do)

- 投递语义的红线不动：draft-raced/unconfirmed 仍是终态、绝不重贴（V8 的反二次投递纪律）；「框里有人的字就一个不碰」不动。
- 不动 panel/、不动 pulse 的叫醒逻辑。
- 除 `skills/teamsmith/scripts/lib/`（投递相关）+ `tests/` + 报告外不动别的。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 夹具实测：空闲 pi 窗格的 draft-race 复现（修前）与消失（修后）
```

## Report

Write it to `docs/team/reports/M24-dev2.md` (format: `docs/team/PROTOCOL.md` or the skill's
`templates/report.md.tmpl`)。
