# 排障（实战踩坑清单）

先跑 `team doctor`；再看扩展日志 `tail -f $(grep TEAM_NOTIFY_LOG .pi/team/config.sh)`。

---

## 1. PM 收不到 agent 的「回合结束」通知

按概率排查：

1. **扩展没加载**：linked worktree 里 Pi **不会**自动发现项目本地 `.pi/extensions/`。必须由
   `team dispatch` 传 `-e <skill>/extension/team-notify.ts`。手动起 agent 时要自己加。
2. **cwd 不在 worktree 下**：扩展只在 `<root>/<TEAM_WORKTREES_DIR>/...` 内触发。改了
   `TEAM_WORKTREES_DIR` 就要同步配置（扩展读同一份 `config.sh`）。
3. **窗口名等于 PM 窗口名**：会跳过（防自触发）。agent 窗口名必须与 agent 名一致——`team dispatch` 已保证。
4. **tmux session 不匹配**：扩展比较 `#{session_name}` 与 `TEAM_SESSION`。PM 会话必须在同名 session 里。
5. **去重**：`TEAM_NOTIFY_DEDUP_SEC`（默认 20s）内的相同简报只发一次。想调试就设 0。
6. **PM 窗口不存在**：只写收件箱，不敲窗口。`team doctor` 会警告。
7. **非 tmux 环境**：`TMUX_PANE` 为空 → 扩展判定不了窗口名，直接跳过。要么在 tmux 里跑，
   要么把 `TEAM_NOTIFY_TMUX=0` 并为 agent 显式设窗口名（目前不支持，属已知限制）。

## 2. agent 会话「找不回来」/ 记忆断了

Pi session 按 **cwd** 归属：`--session-id` 只在同一项目路径下能复用。

- 不要移动/重命名 agent 的 worktree；不要 `rm -rf .worktrees/<agent>` 后重建到别的路径。
- 重建过就 `team dispatch <agent> ... --fresh`（新会话），并在 thread 里记一笔为什么重来。
- session id 规则：`<TEAM_SESSION>-<agent>`（`--fresh` 会追加时间戳）。

## 3. 通知文本和 PM 的输入粘在一起

`tmux send-keys` 是把文本「敲」进 PM 会话的输入行，等于替你打字。已知副作用。缓解：

- 读通知后立刻回一个短句（清空输入行）。
- 调低信息量：`TEAM_INBOX_MAX_CHARS`；或 `TEAM_NOTIFY_TMUX=0`，只用 `team digest` 主动看。
- 不要在 PM 的输入框里长时间悬着半句没发出去的话。

## 4. `team dispatch` 拒绝派单

| 报错 | 原因 | 处理 |
|---|---|---|
| swap 只剩 X MB | `TEAM_MIN_FREE_SWAP_MB` 底线（默认 1024） | 等一个 agent 结束；确认可以卡就 `TEAM_MIN_FREE_SWAP_MB=0 team dispatch …` |
| 可用内存 X MB < 2048 | 只是警告（RAM 紧） | 可继续；嫌卡就降并发。要彻底关掉警告：`TEAM_WARN_AVAIL_MB=0` |
| 可用内存+空闲 swap 仅 X MB | `TEAM_MIN_TOTAL_MB` 硬底线 | 机器真的没资源了：先停 agent |
| 模型 X 并发上限 N | `TEAM_MODEL_LIMITS` | 等，或临时 `TEAM_MODEL_LIMITS="" team dispatch ...` |
| 未知 agent | 名册里没有 | 改 `TEAM_AGENTS` |
| worktree 不存在 | 没 `add-agent` | dispatch 会自动建，但更推荐显式 `team add-agent <a>` |
| 窗口已存在 → 替换 | 上一个回合还在跑 | 确认后再派：替换会打断它（先 `team say` 问进度） |

## 5. git worktree 报错

- `fatal: '<branch>' is already checked out`：该分支已在别的 worktree 里。用 `git worktree list` 找，
  或给复验用 detached checkout（`team review` 已经这么做）。
- 残留的 worktree 锁：`git worktree prune`。
- 删不掉（脏）：先 `git -C <wt> status`，确认无价值再 `team teardown --purge --force`。

## 6. 合并与「已合并」判断

- `git merge --squash` 后，任务分支**不是**保护分支的祖先，所以 `git branch --merged` 判断不出来。
  靠 `BOARD.md` 状态 + `reviews/<ID>.md` 记录，别靠 ancestry。
- 冲突：`git merge --squash` 会留下冲突现场；`git status --porcelain | grep '^U'` 看冲突文件，
  处理完 `git add -A && git commit`，或 `git merge --abort` 放弃重来。
- 合并前主工作树必须干净且在保护分支 —— 这是刻意的：避免把 agent 的脏状态混进合并提交。

## 7. forge（github / gitlab）

- `gh` 401/403：PAT 文件路径/权限/scope。合并需要 `pull-requests: write`，很多 PAT 没有 →
  退回本地 squash + 评论 + 关 PR（见 `workflows.md` F）。
- GitLab 403：token 需要 `api` scope 且有 Developer 以上角色；MR 目标分支若受保护，
  Developer 角色可能无法合并。
- 用真实工具时按需注入（`GH_TOKEN="$(< .gh-pat)" gh …`），不要长期 `export GH_TOKEN`，也不要 `cat` token 到屏幕/日志。

## 8. 报告与实际不符

- 症状：报告说「测试通过」，复验挂。
- 动作：贴失败输出到 thread → 退回 → 在任务书里补「必须先复现失败测试」的要求。
- 制度层面：`team review` 必须真的跑门禁（不要习惯性 `--no-gates`）。
- 反复出现同一 agent 同类型问题：换模型族做独立验证，或把验收命令写得可复制粘贴。

## 9. agent 越界改了别人的目录

- 立刻 `team say <agent> "停：<path> 不属于你，回退你的改动（git checkout -- <path>）"`。
- 在 `OWNERSHIP.md`/任务书里补明确的所有权行——越界多数是任务书没写清。
- 已经提交的越界改动：在复验时拒绝，让 agent 用 `git revert` 或重做分支。

## 11. 其它已知坑

- **skill 没被注入到系统提示**：pi 只在“有能读文件的工具”（`read` 或 `bash`）时才把 skills 写进系统提示。
  用 `--no-tools` 跑时看不到 skill 是正常现象，不是安装失败。验证方法：`bash tests/smoke.sh`
  或 `bun tests/skill-load.mjs`（用 pi 自己的解析器加载本 skill，零模型调用）。
- **收件箱到底写到哪**：notify 扩展优先认 git 主工作树（agent 的 worktree 里也有 `config.sh` 的副本），
  所以收件箱总是汇总到主工作树的 `<docs>/inbox/`；若日志显示 root 指向 worktree 路径，说明扩展版本过旧。
- **路径/配置怀疑错位**：先跑 `team paths`（输出 main_root / worktree / docs / session / pm_window）。
- **`TEAM_PI_BIN`**：pi 不在 PATH 时（或要拿假 pi 做自测时）在配置里指绝对路径。

## 11. 保活与存活判定

- **“PM 没在跑”是怎么判的**：`pane_current_command` 不是 shell → 在跑；是 shell 但命令行带非选项参数或有前台子命令 → 也当作在跑（`busy`）。
  这是为了容住 pi 用 shell wrapper 启动的情况（此时前台名显示 bash），以及用户 rc 钩子常驻子进程（不能因为“有子进程”就认定忙）。
- **team up 会 respawn PM 窗口的 pane**：只有当那里没有 pi 在跑（空提示符）时才动手。
  所以不要把 PM 窗口当普通终端用；要手动开工就到那个窗口重跑 `pi` 或干脆让 watchdog 拉。
  注：`pi` 是 pane 的进程本身（我们用 `exec`），所以 pi 退出时 pane 会关、窗口会消失——
  这正是 watchdog 报 `missing` 的场景（对应 `TEAM_WATCH_REBUILD_TMUX` 开关）。
- **只有“确实在跑”才会被打字**：`say`/`notify`/扩展在目标窗口是空提示符时会拒绝（否则文本会被 shell 当命令执行），
  只写收件箱等 PM 回来读。
- **watchdog 到底管什么**：定时算一遍待办（未读通知/待复验/看板 todo·wip/blocked/有任务但停了的 agent），
  **有待办才叫醒 PM**（在跑就发一句提醒；不在跑就用 `pi -c` 拉起）。没待办就什么都不做。
  它不会替你续跑 agent、不建 tmux session/窗口（除非 `TEAM_WATCH_REBUILD_TMUX=1`）、不合并代码。
- **PM 总是被叫醒/不想被叫**：`team standby on --reason "…"` 让 PM 主动停工（无需人工介入的“真没活”
  或“卡着等人”都属于这种情况）；`team standby off` 恢复。待命期间待办仍会记进 `state/watchdog.log`。
- **叫醒频率**：默认 15 分钟一次（`TEAM_WATCH_INTERVAL=900`，建议 300~3600）；同一批待办按
  `TEAM_WATCH_NUDGE_GAP` 限制重复提醒。想更慢/更快直接改这两个值。
- **PM 被“叫了两次”**：agent 回合结束的即时通知（notify 扩展）与 watchdog 的定时提醒是两回事——
  后者是对未处理待办的兜底。把待办处理/ack 掉就不会再提。
- **watchdog 说“PM 找不到（missing）…请人工 team up”**：tmux session/窗口没了（比如你关了窗口、机器重启），
  而默认不管 tmux。处理：`team up`；想让它自己处理就设 `TEAM_WATCH_REBUILD_TMUX=1`。
- **agent 停了不会自动续跑**（设计如此）：PM 自己说 `team resume --dry-run` 看、再 `team resume` 续；
  人工也可以 `team up --agents` 一次性带上。
- **PM 反复崩**：自动拉起配额（`TEAM_WATCH_MAX_RESTARTS`，默认 5/小时）会拦下并发告警，防止崩溃循环把机器拖垮；
  先看 `state/watchdog.log` 与 PM 窗口输出找原因（常见：模型额度耗尽、配置写错、依赖缺失）。
- **tmux 后端的看门狗窗口被关了**：`team watchdog up` 重开；`team watchdog logs` 看画面快照；
  监视器下半部分提示“本机没有 node/bun/tsx：跳过 agent 活动流” → 装 node 或 bun 即可（团队状态部分不受影响）。
- **看门狗自己也停了**：容器有 `--restart=always`，`podman start <name>` 可手动拉起；`team watchdog up` 会按当前配置重建。
- **机器重启后一片安静**：容器带 `--restart=always`，podman 起来后会自动拉起它（可用 `podman start <name>` 手动）；没配看门狗就 `team up` 一键恢复。
- **`ExecStart`/脚本权限**：本 skill 全部用 `bash <path>` 调用，不依赖可执行位（但 `scripts/team` 仍是 +x，
  `team smoke` 会检查）。

## 12. Pi 相关的通用坑

- **测试结论必须来自当次真实执行**：把命令与输出尾部写进报告，PM 复跑。
- 类型导入（`import type`）在开启 `verbatimModuleSyntax` 等项目下是硬要求——这类项目规则
  要写进 `AGENTS.md`，否则弱模型会反复踩。
- 终端抓屏不可靠（TUI 刷新/换行），别把 tmux scrollback 当证据；报告与日志才是。
- 长任务无进展：让 agent 每 30 分钟在报告里落一次状态，或 `team say` 问一次进度。
- 强模型很慢且额度低：一次只跑一个（`TEAM_MODEL_LIMITS`），PM 别同时派两个。
