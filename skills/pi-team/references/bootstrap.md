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
| 看门狗 | `team watchdog up`：podman 容器常驻（默认每 15 分钟巡检一次） | 已在跑则跳过 |
| 清单 | 打印「下一步」（ROADMAP/OWNERSHIP → 第一个任务 → 派单 → digest） | — |

## 之后 PM 的动作

```bash
team watchdog status            # 看门狗容器 / 巡检周期 / 待办 / PM 存活 / 容量
team task T1.1 --title "…" --agent dev
team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
team digest                     # 待办：通知 + 待复验 + 看板
```

## 看门狗是容器，且由 PM 配置

- `team watchdog up|down|restart|status|logs`（默认 tmux 后端；容器：加 `--container`）。
- **默认（tmux）**：在同一个 session 起 `watchdog` 窗口跑 `team monitor` ——
  上半屏是团队状态（PM/待办/容量/待命），下半屏是每个 agent 的 Pi 会话活动流（谁在干什么、空闲多久、最近事件），
  同时按 `TEAM_WATCH_INTERVAL` 做巡检。`team watchdog logs` 看画面快照。
- 两种运行形态（容器后端，见 `container/Containerfile` 顶部注释）：
  - **容器里开发（推荐）**：看门狗容器用 `podman-remote exec <你的开发容器> …watch` 驱动 ——
    `tmux`/`ps`/`pi` 都在原环境里跑（版本一致、看得见 pane 进程），看门狗却活在容器里、与 PM 会话解耦。
  - **裸机**：直接在容器里跑 `watch`（`--pid=host`，需要镜像里的 tmux 与宿主协议兼容）。
- 容器带 `--restart=always`：看门狗自己崩了/机器重启后由 podman 拉起；它再把 PM 拉起来。
- 改巡检周期：改 `.pi/team/config.sh` 的 `TEAM_WATCH_INTERVAL` 后 `team watchdog restart`。
- 改 `container/Containerfile` 会在下次 `up` 时自动重建镜像（tag = Containerfile 内容哈希）。

## 常见问题

| 现象 | 处理 |
|---|---|
| `容器未创建` | `team watchdog up`（首次会构建镜像，需要网络拉基础镜像 alpine） |
| `podman: command not found` | 容器里用 `distrobox-host-exec podman`（skill 会自动这么做）；裸机装 podman |
| 容器在跑但没有巡检 | `team watchdog logs`；常见是 podman socket 挂载失败（看 `CONTAINER_HOST`） |
| 想彻底停掉 | `team watchdog down`（再 `team standby on` 可让 PM 不再被叫醒） |
