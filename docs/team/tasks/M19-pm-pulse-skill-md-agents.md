# M19 · PM 启动指引缺口：pulse 没在跑要明说拉起来（SKILL.md + AGENTS 模板）

```
task:   M19
agent:  dev3
issue:  
change: -            # OpenSpec change id this brief implements (`openspec list`, e.g. add-agent-timeout); "-" if no requirement changes
specs:  -            # requirements/scenarios it must satisfy, e.g. `dispatch: a brief is self-contained`; "-" if none
phase:  -            # OpenSpec pipeline phase this brief runs: explore|propose|apply|verify|archive ("-" for work outside the pipeline); one phase = one brief = one owner
deps:   M18          # M18 修 digest 的 pulse 状态行（信号）；本任务修指引（文字）。文件不重叠，顺序无所谓，但一起交付才算闭环
status: todo
budget: 半小时以内；超出就交 PARTIAL 报告
```

> 本地模式：不 push，把任务分支留在 `.worktrees/dev` 工作树即可，PM 复验后本地合并。

## Context

用户实测反馈（<peer-d> session)：手动开一个 Pi 会话、注入 teamsmith skill 后，agent 没有自动启动 pulse，要人开口才起。根因是指引断在这条路径上：

1. 手动注入 skill 的会话读到的是 `skills/teamsmith/SKILL.md`。其启动清单（约第 98 行，`## The PM loop` 的引用块）是
   `team digest` → `team inbox --ack` → `team resume --dry-run` → `team pulse status`
   ——只让**看**状态，从不说**看到没在跑要 `team pulse up`**。
2. 「没在跑就拉起来」这句命令只存在于 `skills/teamsmith/templates/pm-prompt.md.tmpl`（约 25 行），而那个模板只有 teamsmith 自己拉起 PM 时（`team up`/bootstrap 生成的 PM 窗口）才渲染。手动注入 skill 的路径看不到它。
3. `skills/teamsmith/templates/AGENTS.section.md.tmpl` 的 "Periodic patrol" 一节（约 91 行起）也只描述所有权与语义，没有启动命令。
4. 附带问题：pm-skills 本仓库自己的 `AGENTS.md` 里渲染的 teamsmith 段还是改名前的旧文本（讲 watchdog、旧命令）——`team init` 会就地迁移 marker 并重渲染，但没人跑过。

## Deliverables

1. `skills/teamsmith/SKILL.md` — 启动清单那行改成带动作的：`team pulse status` 之后明确「没在跑且不在待命（standby）就 `team pulse up`；在待命则不动」。一句话，不展开。
2. `skills/teamsmith/templates/AGENTS.section.md.tmpl` — "Periodic patrol" 一节加一条：PM 会话启动时若 pulse 没在跑且未待命，拉起它是 PM 职责的一部分（standby on 时不拉）。
3. pm-skills 本仓库 `AGENTS.md` — 跑 `bash skills/teamsmith/scripts/team init`（幂等）让 teamsmith 段重渲染为改名后的文本；把 diff 贴进报告（应只见该段变化）。

## Boundaries (do not do)

- 不改 `pm-prompt.md.tmpl`（它已经有这句话）；不改任何 `scripts/**`；不动 standby 语义。
- 不给 pulse 加「自动启动」的代码行为——本任务只改指引文字。是否该有代码级自动拉起是另一个讨论，不在此任务。
- 除上述三个文件 + 报告外不动别的。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
grep -n "pulse up" skills/teamsmith/SKILL.md                    # 启动清单行必须含动作指引
grep -n "pulse up" skills/teamsmith/templates/AGENTS.section.md.tmpl
grep -c "watchdog" AGENTS.md                                    # 重渲染后应为 0（别名期 CLI 名除外则逐行说明）
```

翻转证据（文档任务的等价物）：报告贴出修改前 SKILL.md 启动清单行原文（红 = 无动作）与修改后该行（绿 = 有动作），以及 `team init` 前后 `git diff AGENTS.md` 的关键段。

## Report

Write it to `docs/team/reports/M19-dev.md` (format: `docs/team/PROTOCOL.md` or the skill's
`templates/report.md.tmpl`). It must contain: deliverables, the real commands with output tails, anything not
verified / risks, deviations from this brief, and next-step suggestions.
