# 在项目里初始化 pi-team（bootstrap）

给新项目（或第一次接手某个仓库的 PM）用的最短路径。**PM 负责初始化，包括配置看门狗。**

## 一句话

```bash
bash <skill>/scripts/team bootstrap              # 幂等；自动探测当前 tmux session/窗口
bash <skill>/scripts/team bootstrap --agents "dev verify api"   # 自定义名册
bash <skill>/scripts/team bootstrap --print      # 只看计划，不动任何东西
```

或者把 `templates/bootstrap-prompt.md.tmpl` 的内容（替换占位符后）直接交给新项目里的 PM：
「读一遍，然后执行」。

## bootstrap 具体做什么

| 步骤 | 结果 | 幂等性 |
|---|---|---|
| 探测 tmux | 采用 PM 自己所在的 `session:window` 写进配置（不用手填） | 每次重算 |
| 写配置 | `.pi/team/config.sh`（身份/名册/模型/门禁/安装命令/forge/守卫/看门狗） | 已存在则保留，只补空缺项 |
| 文档骨架 | `docs/team/{ROADMAP,BOARD,OWNERSHIP,DECISIONS,PROTOCOL}.md`、`tasks/`、`reports/`、`reviews/`、`threads/`、`inbox/` | 存在则跳过 |
| 团队协议 | 往 `AGENTS.md` 注入 `<!-- pi-team:begin --> … end -->` 段落（**刷新**而非重复追加） | ✔ |
| `.gitignore` | `.pi/team/state/`、`docs/team/inbox/`、`docs/team/reviews/*.log`、`.worktrees/` | ✔ |
| agent worktree | 每个名册成员一个长期 `.worktrees/<agent>`（分支 `agent/<agent>`），有 `TEAM_INSTALL_CMD` 时顺手装依赖 | 已存在则跳过 |
| 看门狗 | `team watchdog up`：同 session 的 `watchdog` 窗口跑监视器（默认每 15 分钟巡检一次） | 已在跑则跳过 |
| 清单 | 打印「下一步」（ROADMAP/OWNERSHIP → 第一个任务 → 派单 → digest） | — |

## 之后 PM 的动作

```bash
team watchdog status            # 看门狗窗口 / 巡检周期 / 待办 / PM 存活 / 容量
team task T1.1 --title "…" --agent dev
team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
team digest                     # 待办：通知 + 待复验 + 看板
```

## 看门狗是窗口，且由 PM 配置

- `team watchdog up|down|restart|status|logs`（**只有一个后端**：同 session 的 `watchdog` 窗口）。
- **默认（tmux）**：在同一个 session 起 `watchdog` 窗口跑 `team monitor` ——
  上半屏是团队状态（PM/待办/容量/待命），下半屏是每个 agent 的 Pi 会话活动流（谁在干什么、空闲多久、最近事件），
  同时按 `TEAM_WATCH_INTERVAL` 做巡检。`team watchdog logs` 看画面快照。
- 为什么只有一个后端（v1.12.0 起不再有 podman/容器/systemd 形态）：**依赖越少越可靠**——
  少一个运行时、少一层 socket/权限/镜像问题，出事时只有一个地方要查。看门狗不需要跨 tmux server 存活：
  server 没了 PM 也没了，重建时 `team up` / `team watchdog up` 一起起来就行。
- 看门狗自己也挂了怎么办：`team watchdog status` 会发现它不在；`team watchdog up` 重建窗口。没人会自动重启它（这也是"少管"的代价，换来的是零额外运行时）。
- 改巡检周期：改 `.pi/team/config.sh` 的 `TEAM_WATCH_INTERVAL` 后 `team watchdog restart`。
- 别再引入第二个后端（容器/systemd）：换来的那点存活能力，要靠多一层运行时/权限/socket 去换，不值。

## 常见问题

| 现象 | 处理 |
|---|---|
| `容器未创建` | `team watchdog up`（首次会构建镜像，需要网络拉基础镜像 alpine） |
| 窗口在但没巡检 | `team watchdog logs` 看面板输出；`team watch --once` 手动跑一拍定位 |
| 想彻底停掉 | `team watchdog down`（再 `team standby on` 可让 PM 不再被叫醒） |
