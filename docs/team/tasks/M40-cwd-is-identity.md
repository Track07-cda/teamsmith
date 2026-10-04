# M40 · 身份一律以运行时目录为准：TEAM_* 环境变量不许静默赢过 cwd

```
task:   M40
agent:  dev3
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   -            # M36 已合并；本任务收敛的是「身份解析」，不碰 shim
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## Context（2026-09-19 两起同族实测事故，用户已拍板设计方向）

**事故 ①**：用户在 <peer-g> 目录里跑 `/pm-skills/skills/teamsmith/scripts/team up` 被拒：
「当前目录属于 <peer-g>，而要被操作的是 pm-skills」——shell 继承了 pm-skills 的 `TEAM_*`，
CLI 把项目解析成了 pm-skills。护栏拦住了，**方向是对的**。

**事故 ②**：<peer-g> 的 pulse 面板渲染出 **pm-skills 的看板**。面板进程 cwd=<peer-g> 但
`TEAM_ROOT=pm-skills`（启动 pulse 的 shell 带着 pm-skills 的环境），而解析顺序是 **env 优先于 cwd**
→ 静默读错项目。这道门没有护栏，直接错了。

**用户的设计决定（本任务的规格）**：
- 「应该直接按照 `team up` 运行时的目录来配置 pulse 的目录」
- 「为什么要依赖环境变量？」——**身份（项目根/项目名/会话名）默认从 cwd 推导**；
  继承来的 `TEAM_*` 身份变量**绝不许静默赢过 cwd**。

## Deliverables

1. **入口解析规则**（`team` CLI 的启动处，一处实现全体共用）：
   - 项目根 = 从 cwd 推导（git worktree 上溯 → 主工作树 → 必须有 `.pi/team/config.sh`；已有的
     `team_cwd_in_project`/root 解析助手能复用就复用）；
   - `TEAM_ROOT`/`TEAM_MAIN_ROOT`/`TEAM_PROJECT`/`TEAM_SESSION` 与 cwd 推导结果**一致** → 照常；
     **不一致** → 醒目报错退出（指向「清掉继承变量或 cd 到目标项目」，与 team up 现有护栏同款措辞），
     **绝不静默跟随 env**；
   - cwd 不在任何已初始化项目里 → 现有报错路径（照旧）。
   - **保留测试逃生门**：smoke 夹具的用法是「env 设到 fixture + cwd 也在 fixture」（两边一致），
     不许被误伤；若有个别夹具依赖「cwd 与 env 故意不同」的形状，报告里点名并给出迁移方式。
2. **spawn 点清洗**：`team up`（PM 重建）、`team pulse up/restart`、`team monitor`、dispatch 的窗口启动
   命令——拼启动环境时**只带本命令现场推导出的身份**（继承来的 TEAM_* 先 `env -u` 再按推导值重设），
   保证「在哪个项目目录里启动，长驻进程就属于哪个项目」。
3. **面板/扩展侧同原则**：`scripts/panel` 与 `extension/team-inbox-watch.ts` 里的 envRoot 优先级收敛——
   env 仅在「与 cwd 推导一致」时被信任；不一致时按 cwd 走并在日志里留一行（面板不许静默渲染别的项目）。
4. **smoke 断言**（至少）：
   - 夹具：shell 带「另一项目」的 `TEAM_*`、cwd 在项目 B → `team pulse up --dry-run`/`team paths` 必须按 B
     解析并打不一致警告；env 与 cwd 一致 → 无警告；
   - spawn 清洗：从带外来 `TEAM_*` 的环境起 pulse，窗口进程的 `TEAM_ROOT` 必须是 cwd 的项目；
   - **翻转**：把入口改回 env 优先 → 上述断言红。

## Boundaries

- 不改 M36 的 shim 行为；不改 `team up` 现有护栏的拒绝语义（它已被证明是对的，本任务是把同原则推广到
  pulse/monitor/spawn/面板）。
- tmux 纪律照旧（#1250）；测试私有 socket；跑门禁前后 `tmux ls | head -3` 探活。
- 不顺手重构别的 env 旋钮（TEAM_SMOKE_FAST 等临时旋钮不在本任务范围）。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 事故②的真实形状复现：带外来 TEAM_ROOT 的 shell 在另一项目目录里 team pulse up（--dry-run 或临时会话），
# 面板解析到的是 cwd 项目 —— 把证据实录进报告
```

## Report

`docs/team/reports/M40-dev3.md`。

---

## 追加约束（2026-09-19 15:05 · 第 6/8 次死亡后由 PM 补写）

夹具里跑 `dispatch` 等会开窗的路径时：**必须清 `TMUX`/`TMUX_PANE`**，或整体进容器
（`bash skills/teamsmith/tests/container-tmux.sh -- <cmd>`）。宿主机上留在 tmux 窗口里跑会开窗的夹具，
`new-session`/`kill-server` 会落到调用者的 server（第 6 次死亡的成因）。报告里写清夹具怎么隔离的。
