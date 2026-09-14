# 配置与落盘布局

## 1. 配置发现顺序

`team` CLI：

1. `--config <file>` / 环境变量 `TEAM_CONFIG_FILE`
2. `--root <dir>` / `TEAM_ROOT` 下的 `.pi/team/config.sh`
3. 从当前目录向上逐级找 `.pi/team/config.sh`

notify 扩展（在 agent 进程内，**不 source 配置、不执行项目代码**）：
同样向上查找，只解析它需要的少数扁平 `KEY=VALUE`；找不到时用 git 主工作树兜底。
值里的 `$VAR` / `${VAR}` 会被按 `process.env` 展开。

## 2. 配置键（`.pi/team/config.sh`）

配置文件由 bash source，所以可以写 `$HOME`、条件逻辑；但 notify 扩展只能读懂**扁平单行赋值**，
所以需要注意的键（session/pm-window/worktrees/docs/notify）请保持字面量或简单的 `$VAR`。

### 身份 / 名册

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_PROJECT` | 主工作树目录名 | 展示名 |
| `TEAM_SESSION` | `$TEAM_PROJECT` | tmux session（PM 与所有 agent 共用） |
| `TEAM_PM_WINDOW` | `pm` | PM 会话所在窗口；通知敲这里 |
| `TEAM_AGENTS` | 空（`init` 给 `dev verify`） | 名册，空格分隔 |
| `TEAM_AGENT_MODELS` | 空 | 个体模型覆盖：`dev=deepseek/deepseek-flash verify=xai/grok-4.6` |
| `TEAM_DEFAULT_MODEL` | `deepseek/deepseek-flash` | 默认模型（`provider/model`） |
| `TEAM_MODEL_LIMITS` | `kimi-coding/k3=2` | 并发上限，`provider/model=N` 空格分隔；`0`=不限 |
| `TEAM_EXTRA_PI_ARGS` | 空 | 追加给 pi 的参数（空格分隔，不支持含空格的值） |

### 工作流

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_GATES` | `init` 自动探测 | 复验门禁命令（如 `pnpm verify`） |
| `TEAM_PI_BIN` | `pi` | pi 可执行文件（非 PATH 安装时给绝对路径；自测常用） |
| `TEAM_INSTALL_CMD` | 空 | 新建 worktree 后执行的安装命令（如 `pnpm install --frozen-lockfile`） |
| `TEAM_DOCS_DIR` | `docs/team` | 任务书/报告/复验/线程/收件箱目录 |
| `TEAM_WORKTREES_DIR` | `.worktrees` | 长期 worktree 目录（同时用于识别「这是 agent 会话」） |
| `TEAM_PROTECTED_BRANCH` | `main` | 只有 PM 能推进的分支 |
| `TEAM_REMOTE` | `origin` | 远端名（local 模式也要有，用于 push 分支） |

### agent adapter（worker 用任意 TUI agent；四个都留空 = 内置 Pi，历史行为不变）

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_AGENT_CMD` | 空 | 启动 agent CLI 的命令模板；空 = 内置 Pi 命令。占位符：`{cwd}` `{session_id}` `{model}` `{provider}` `{prompt_file}` `{prompt}` `{skill_dir}` `{notify_ext}` `{extra_args}`；未知**或畸形**占位符（`{ cwd }`/`{{cwd}}`…）→ `dispatch` 直接失败并列出支持集；纯空白/多行模板同样被拒（首词必须是裸可执行名） |
| `TEAM_AGENT_NOTIFY_CMD` | 空 | worker 回合结束通知 PM 的命令模板（`{summary_file}` `{summary}` `{agent}` `{cwd}` `{session_id}` `{model}` `{provider}` `{skill_dir}`）；空 = Pi 通知扩展。**摘要是数据**：worker 先写进 `{summary_file}`，再原样跑渲染出的固定命令（推荐 `… notify pm --from-file {summary_file}`）；`{summary}` 只为兼容保留，渲染成「读该文件的引用」，不做文本插值。模板不可用时只警告，且提示词整段换成「写进报告」 |
| `TEAM_AGENT_LOG_GLOB` | 空 | `team monitor --activity` 的活动来源：最新匹配文件的**尾部**（`*` `?` `**`、行首 `~`、`{agent}` = agent 名）；空 = Pi 会话文件；没匹配到就退回「无会话」并说明原因 |
| `TEAM_AGENT_LOG_TAIL_BYTES` | 空（=64KiB） | 日志尾部最多读多少字节（正整数，硬上限 1MiB；超上限夹住、坏值回默认并在 stderr 警告）。**注意**：`team monitor` 只把 `TEAM_AGENT_LOG_GLOB` 显式转发给 monitor.mjs，所以想用这个键必须在 `.pi/team/config.sh` 里写成 `export TEAM_AGENT_LOG_TAIL_BYTES=…`（或直接在 shell 里 export / 给 monitor.mjs 传 `--log-tail-bytes`），普通赋值到不了子进程 |
| `TEAM_AGENT_BIN` | 空 | 窗口 PATH 就绪等待 / 存在性检查 / `doctor` 用的可执行文件；空 = `TEAM_AGENT_CMD` 首词，否则 `TEAM_PI_BIN` |

> 契约（teamsmith 负责什么 / adapter 负责什么）、占位符语义、codex 与 opencode 实测例子、验证清单与明确不支持的事：见 [agent-adapters.md](agent-adapters.md)。

### forge

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_VCS` | 自动探测 | `local` / `github` / `gitlab` |
| `TEAM_TOKEN_FILE` | `.gh-pat` | github：PAT 文件（主工作树根，chmod 600，gitignore） |
| `TEAM_GITLAB_HOST` | 空 | gitlab：`https://gitlab.example.com[:port]` |
| `TEAM_GITLAB_PROJECT` | 空 | gitlab：`group/sub/project`（脚本会 URL 编码） |
| `TEAM_GITLAB_TOKEN_FILE` | `$HOME/.gitlab-pa-token` | gitlab：PAT 文件 |
| `TEAM_CONFIRM_WRITES` | `1` | `1`=写操作必须 `--yes`（**建议保持**） |

| 守护 | 默认 | 作用 |
|---|---|---|
| watchdog 只做“算待办 + 叫醒 PM”（有待办才叫）；agent 的启停/续跑是 PM 的活（`team resume`） |
| `TEAM_REQUIRE_MAGIC_CONTEXT` | `0` | `1` = 把 magic-context（PM 记忆）当硬依赖：没装则 `team doctor` 失败 |
| `TEAM_PI_SETTINGS_FILE` | `~/.pi/agent/settings.json` | 探测 Pi 扩展（magic-context）的位置；测试/多用户环境可覆盖 |
| `TEAM_WATCH_INTERVAL` | `900` | 巡检周期（秒）：默认 15 分钟，建议 300~3600。这是“定时看看有没有活儿”的节拍，不是心跳 |
| `TEAM_WATCH_NUDGE_GAP` | `900` | 同一批待办最快多久再提醒一次（秒） |
| `TEAM_WATCH_REBUILD_TMUX` | `0` | `0`=不管 tmux（session/窗口没了只告警）；`1`=允许重建 session/PM 窗口（机器重启自恢复） |
| `TEAM_WATCH_MAX_RESTARTS` | `5` | PM 每小时最多自动拉起次数（防崩溃循环） |
| `TEAM_WATCH_WINDOW` | `watchdog` | tmux 后端的窗口名 |
| `TEAM_MONITOR_REFRESH` | `5` | 监视器刷新间隔（秒） |
| `TEAM_MONITOR_ACTIVITY` | `0` | `1`=面板下方追加各 agent 会话活动流（只列本 session 在跑的窗口）；默认关 |
| `TEAM_MONITOR_EVENTS` | `4` | 每个 agent 显示最近几条会话事件 |

| `TEAM_PM_MODEL` | 空 | PM 自己的模型，空 = `TEAM_DEFAULT_MODEL` |
| `TEAM_PM_SESSION_ID` | 空 | 空 = `pi -c`（延续本目录上一个会话，保住 PM 历史） |
| `TEAM_PM_EXTRA_PI_ARGS` | 空 | 追加给 PM 的 pi 参数 |
| `TEAM_PM_START_WAIT` | `6` | 启动 PM 后等它起来的秒数 |

### 守卫（容量）

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_MIN_FREE_SWAP_MB` | `1024` | **底线**：空闲 swap 低于此值拒绝派单（打满会被 OOM killer 杀进程） |
| `TEAM_MIN_TOTAL_MB` | `512` | RAM+swap 的绝对底线 |
| `TEAM_WARN_AVAIL_MB` | `2048` | RAM 可用低于此值：只警告（允许卡顿），不拒绝 |
| `TEAM_AGENT_MEM_MB` | `6144` | 单个 agent 的经验占用，用于 `team ps` 的“还能加几个”估算 |
| `TEAM_NOTIFY_TMUX` | `1` | `0`=只写收件箱，不敲 PM 窗口 |
| `TEAM_NOTIFY_DEDUP_SEC` | `20` | 去重窗口（秒）；`0`=不去重 |
| `TEAM_INBOX_MAX_CHARS` | `150` | 简报里 agent 末条消息的截断长度 |
| `TEAM_NOTIFY_LOG` | `/tmp/<project>-teamsmith-notify.log` | 扩展调试日志（排查通知问题看这里） |

### 分支模型（D1）

| 键 | 默认 | 作用 |
|---|---|---|
| `TEAM_VCS` | `local` | `local`\|`github`\|`gitlab`\|`other`（other=项目自己的 forge，见下两行） |

> 分支模型的键（见下）只是**命名约定**（skill 不建/不切分支；`dispatch` 只用它给出提示）。

| `TEAM_BRANCH_MODE` | `task` | `task`=一任务一分支（`task/<ID>-<slug>`；复验/合并/回滚单位=任务）｜`agent`=一 agent 一长期分支 |
| `TEAM_TASK_BRANCH_PREFIX` | `task` | 任务分支前缀 |
| `TEAM_TASK_BRANCH_RESET` | `1` | `close` 后 worktree 退回 `detached@保护分支` |
| `TEAM_AGENT_BRANCH_PREFIX` | `agent` | `agent` 模式的前缀 |

## 3. 项目内落盘布局

```
<项目根>/
├── .pi/team/
│   ├── config.sh          # 配置（入库，团队共享）
│   └── state/             # 运行时状态（gitignore）：<agent>.env、notify-dedup、
│                          #   prompt-<agent>-<ID>.md（本次派单的提示词；{prompt_file} 指向它）
├── AGENTS.md              # 含 <!-- teamsmith:begin --> 协议段落（init 写入/刷新）
├── .worktrees/
│   ├── <agent>/           # 每个 agent 的长期 worktree（分支 agent/<名>）
│   └── review-<ID>/       # PM 复验用的 detached worktree（可随时删）
└── <docs>/                # 默认 docs/team
    ├── PROTOCOL.md        # 协议摘要（给人和 agent 看）
    ├── BOARD.md           # 任务板（team board / task / merge / close 维护状态列）
    ├── ROADMAP.md         # 里程碑与退出标准
    ├── OWNERSHIP.md       # 目录归属 + 名册
    ├── DECISIONS.md       # 决策日志（理由/影响）
    ├── tasks/<ID>-<slug>.md
    ├── reports/<ID>-<agent>.md
    ├── reviews/<ID>.md  + <ID>-verify.log     # 复验记录（log 已 gitignore）
    ├── threads/<agent>.md                     # append-only 消息线程
    └── inbox/<agent>.md                       # 自动简报（gitignore）
```

`.gitignore` 由 `init` 追加：

```
.pi/team/state/
<docs>/inbox/
<docs>/reviews/*.log
.worktrees/
```

## 4. 环境变量（不写进配置也能用）

| 变量 | 作用 |
|---|---|
| `TEAM_ROOT` | 显式指定项目根 |
| `TEAM_CONFIG_FILE` | 显式指定配置文件（`team --config` 同义） |
| `TEAM_MIN_AVAIL_MB` | `1024` | **硬线**：MemAvailable 底线（CEP 机器设 4096，对应两次 OOM 的教训） |
| `TEAM_MIN_FREE_SWAP_MB` | `1024` | **硬线**：磁盘 swap 空闲底线（**不含 zram**） |
| `TEAM_ZRAM_WARN_PCT` | `85` | zram 占用超此值只警告 |
| `TEAM_MERGE_PREFER_THEIRS` | 空 | `merge` 冲突时默认取分支侧的路径（逗号分隔，如 `pnpm-lock.yaml`） |
| `TEAM_REVIEW_TIMEOUT` | `1800` | `team review` 跑门禁的硬超时（秒）；超时 → `TIMEOUT`（按 FAIL 处理） |
| `TEAM_MIN_FREE_SWAP_MB` | 临时覆盖磁盘 swap 底线 |
| `TEAM_MEMINFO_FILE` | 指定 meminfo 文件（容器/测试无 `/proc/meminfo` 时用） |
| `TEAM_MODEL_LIMITS` | 临时放宽/收紧并发（`""` 表示不限） |
| `TEAM_ASSUME_YES` | `1`=跳过 `--yes`（只建议在自动化脚本里用） |
| `NO_COLOR` | 关闭颜色 |
