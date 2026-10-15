# V42 · 孤儿进程可见性与按 pid 清理：独立复验

task: V42
agent: -
phase: verify
category: verify
change: orphan-visibility
specs: seat-visibility, board-and-status, boundary
deltas: -
branch: task/V42-orphan-visibility-verify
deps: P276（apply 已交付，冻结 tip 见派单消息）

## 复验对象

`orphan-visibility` 的 apply：孤儿进程普查（身份 + 形状两条判据）、跨项目只报总量且标 `≥`、本项目按 pid 清理（无 pattern）、只读不写盘、缓存等价闸门把普查块当活字段滤掉。被检树：PM 冻结的独立 clone（tip 见派单消息）。

## 必须自己做的（不许只复跑作者脚本）

1. **自己造一个假孤儿**：起一个带本项目身份（`TEAM_MAIN_ROOT`/`TEAM_PROJECT`/`TEAM_SESSION` 指向本项目）但**不在任何 tmux pane 里**的替身进程 → 普查必须点名它（pid、RSS、席位、任务、启动时间）；`team reap --orphans` 的**计划**里列出它；**不带 `--yes` 时一个信号都不发**；带 `--yes` 后它消失且只动了那一个 pid。
2. **四个假阳性家族各造一例**（都必须**不判孤儿**）：① 命令行里出现 agent 路径但不是 agent 形状的进程；② 活着的席位窗口（不是「当前 pane」也要算活着）；③ 私有 socket 上的活席位（拿**默认 server** 的 pane 表比对会误判）；④ server 查询不到时**不判定**（不许猜）。
3. **跨项目零点名**：造一个身份属于**别的项目**的替身 → 只计入总量、**不点名**（pid/项目名/席位名/路径都不许出现），且总量标 `≥`。
4. **只读性质**：`team status`/`team ps` 的新读数**不写盘**（既有「状态哈希前后不变」断言不许回退）；普查块在缓存等价闸门里被当**活字段**滤掉（你自己把过滤拿掉 → 必须红）。
5. **不许 pattern**：`team reap` 里不许出现 `pkill`/`killall`/名字匹配；红侧：造一个「名字像但 pid 不是记录里那个」的进程 → 它**不许**被杀。
6. **不削弱**：`seat-visibility` 的新要求逐条对照；`board-and-status` 那条 MODIFIED 的原有场景零丢失（PM 复核时核过 3 → 4）。
7. 容器纪律：先看 `/tmp` 余量；任何「既有红」同命令对照 **v0.2.0（tag）**。

## 交付

`docs/team/reviews/V42.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc + 证据路径；你造的替身与四个假阳性家族的原始输出；写明运行模型）；证据包仓外；不改候选、不合并、不推送；结论按协议通知 PM。
