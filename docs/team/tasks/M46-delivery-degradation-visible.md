# M46 · 投递通道降级必须可见（扩展「skip setup」静默丢失快路径）

```
task:   M46
agent:  dev3
change: -
specs:  -
phase:  -
deps:   -            # M40 已修根因（身份=运行时目录）；本任务修的是「降级没被看见」
status: todo
budget: 一个工作块
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev3`。

## 现场（2026-09-20 用户报「<peer-g> 又没自动发消息」，PM 只读排查所得）

<peer-g> 的 PM 进程（16:11 启动）加载的是 **M40 合并前**的 `team-inbox-watch.ts`：扩展按「环境变量优先」
解析项目根 → 解到 **pm-skills** → 用 pm-skills 的配置算出期望会话名 `teamsmith`，与真实会话 `<peer-g>`
不符 → **每 2 秒失败一次**，而所有痕迹都写进了 **pm-skills 的** `state/inbox-watch.log`：

```
2026-09-19T16:11:45.129Z skip setup: session <peer-g> != teamsmith
2026-09-19T16:11:47.172Z skip setup: session <peer-g> != teamsmith
…（持续）
```

后果链：**没有 watcher 注册** → 投递退回 tmux 输入框路径 → 一次 `draft-raced-left`
（`outbox/HOLDING.log` 02:26:59）→ 2 条消息滞留在 `outbox/`（02:37 的 web knock）没送出 → 用户看到
「消息不会自动发送」。同时 `held/` 里还堆着 5 条 `<peer-g>:pi`（旧会话名）的历史残渣。

**根因已由 M40 修掉**（身份 = 运行时目录）；但扩展代码是**进程启动时读取**的，所以：
- 运行中的会话必须**重启进程**（`team up`/`team resume`）才会拿到新代码；
- `/reload` **不会**补上进程启动时的 `-e` 扩展 —— 这一条今天在 <peer-g> 的 PM 里被写成了待办
  （「等用户在 Pi 里输入 /reload」），是**错的指导**，文档/提示要用 M46 修掉。

## Deliverables

1. **降级可见（核心）**：扩展**跳过/失败**必须留下**本项目的**、看得见的痕迹，而不是静默：
   - 落到**本项目** `state/inbox-watch.log`（即使根解析有分歧也要能定位到「哪个会话、为什么跳过」）；
   - 在 `team doctor` / `team status` / digest 里给一条**明确的降级警告**：例如
     「本项目 PM 没有 inbox-watch 注册（原因：会话名不符 / 扩展未加载）→ 通知走输入框慢路径」；
   - 面板（pulse）在 PM 会话缺 watcher 时给出可见提示（一行即可）。
2. **不再跨项目写日志**：跳过时若怀疑根解析分歧，日志与提示必须指向**调用者所在目录推导出的项目**；
   绝不把另一个项目的 state 当自己的家（M40 的原则，这里补齐诊断面）。
3. **慢路径自身要稳**：`draft-raced-left` 的残留必须能被下一拍自动清掉/重投（不允许「一次竞态 → 永久滞留」）；
   `held/` 里目标已不存在的条目要能被识别并给出清理出口（不静默堆积）。
4. **测试**（每条都要能红）：
   - 会话名不符 → doctor/status 出现降级警告（翻转：去掉告警 → 断言红）；
   - 扩展未注册时，outbox 的投递仍能完成（串行重试），且**不留下永久 stalled 条目**；
   - 旧目标名的 held 条目被报告为「目标已消失」并可清理。
5. **文档**：`references/troubleshooting.md` 增一条
   「消息不自动发送：先看有没有 watcher 注册 / skip setup 原因」；并纠正 `/reload` 的错误指导
   （`-e` 扩展必须重启进程才生效）。

## Boundaries

- 不改投递契约、收件箱格式、outbox 的文件命名；不引入新的常驻进程。
- 别动 M45（`team-inbox-watch.ts` 的输入框判据）与 P22（config 写入门面）的语义；
  与 M45 同文件时只做你需要的**最小**改动并在报告里点名冲突面。
- 测试纪律：私有 tmux socket、破坏性调用进容器、别用绝对路径调 tmux。

## Acceptance (must actually be run)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 现场复现（读-only 的现场用你自己的临时项目造，不要动 <peer-g>）：
#   造一个「扩展启动时会话名不符」的项目 → 观察 doctor/status 的降级警告与 outbox 的自愈
```

## Report

`docs/team/reports/M46-dev3.md`。
