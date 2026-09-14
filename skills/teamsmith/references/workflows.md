# 流程手册（runbook）

每条都是可直接照抄的命令序列。默认 `team` 指 `bash <skill>/scripts/team`（若已加 PATH 或软链，直接 `team`）。

---

## A. 在一个新项目里组建团队

```bash
# 0) 前提到位：git 仓库、tmux、pi 都在；仓库至少有一个提交
bash <skill>/scripts/team init --session myproj --agents "dev verify" --vcs local
#   → 写 .pi/team/config.sh、建 docs/team/ 骨架、给 AGENTS.md 追加协议段、更新 .gitignore

# 1) PM 会话：在 tmux 里跑 pi（通知要敲进这个窗口）
tmux new -s myproj -n pm          # 然后在里面启动：pi

# 2) 编辑 .pi/team/config.sh：门禁、安装命令、模型与并发上限
bash <skill>/scripts/team doctor
```

## B. 派第一个任务

```bash
# 一条命令初始化（推荐）：bash <skill>/scripts/team bootstrap
# github 模式：先建 issue（可选，但推荐：issue 是需求口径，任务书是执行口径）
printf '# 骨架与质量门禁\n\n## DoD\n- ...\n' > /tmp/issue.md
# 用你们自己的方式建 issue：gh / curl 调 API / 网页（skill 不参与、不假设任何 forge）
gh issue create --title "[T1.1] 骨架与质量门禁" --body-file /tmp/issue.md

bash <skill>/scripts/team task T1.1 --title "骨架与质量门禁" --agent dev --issue 12
$EDITOR docs/team/tasks/T1.1-*.md      # 写清背景/交付物/边界/验收命令

bash <skill>/scripts/team add-agent dev --create   # --create 才代建 worktree（默认只打印 git 命令）
bash <skill>/scripts/team dispatch dev T1.1 docs/team/tasks/T1.1-*.md
bash <skill>/scripts/team dispatch dev T1.1 docs/team/tasks/T1.1-*.md --print   # 只想看提示词
```

派单做了这些事：守卫（内存/模型并发）→ 组提示词（范围、红线、交付流程）→ 在
`<session>:dev` 起交互式 pi（`--session-id <session>-dev`，`-e` 加载 notify 扩展，`--skill` 加载本 skill）。
断点续跑：再次 `dispatch` 同一个 agent 即复用会话；要开新会话用 `--fresh`。

## C. 围观 / 追问 / 重新引导

```bash
tmux attach -t myproj            # 直接旁观（Ctrl-b d 退出）
bash <skill>/scripts/team say dev "先别动 packages/api，那是 api 的目录"   # 单行消息（多行写文件让 agent 读）
bash <skill>/scripts/team thread dev "T1.1 的验收加一条 RLS 测试" --from pm --re T1.1
```

**追问要具体**：指出失败命令、期望 vs 实际、以及要求它先复现再修。

## D. PM 循环（每 10~30 分钟一次）

```bash
bash <skill>/scripts/team digest          # 待办：新通知 + 待复验 + 任务板 + 容量/存活
bash <skill>/scripts/team inbox --ack     # 读并标记已读
bash <skill>/scripts/team roster          # 谁在跑、分支、脏文件、领先提交
bash <skill>/scripts/team ps              # 容量（RAM/swap/还能加几个）+ 模型并发 + PM/watchdog 存活
bash <skill>/scripts/team up              # 一键修复：session/PM/停了没交活的 agent
```

收到「回合结束」通知后先看 `git -C .worktrees/<a> log --oneline -5` 与 `status`，再决定：
继续派下一个任务、退回、还是复验。长时间不在（下班、机器重启）回来后：**先 `team up`**。

## E. 复验（PM 的独立验证，不可跳过）

```bash
git -C <root> worktree add --detach /tmp/review-T1.1 task/T1.1-*   # PM 准备独立 checkout
bash <skill>/scripts/team review T1.1 --dir /tmp/review-T1.1      # 只跑门禁 + 写复验记录
bash <skill>/scripts/team review T1.1 --dir /tmp/review-T1.1 --no-gates   # 只做人工评审
```

产物 `docs/team/reviews/T1.1.md`：HEAD、diffstat、提交列表、文件清单、门禁输出尾部、结论清单。
门禁失败时命令返回非 0 —— 别忽略。

**PM 自己也要读 diff**：门禁只证明「现有测试没挂」，不证明「实现符合任务书」。

## F. 合并与收尾

**没有 PR（local 模式）**：

```bash
git -C <root> status                    # 主工作树必须干净、在保护分支上
git -C <root> merge --squash <分支>      # 冲突处理见 protocol.md §8e
git -C <root> commit -m "T1.1: <标题>"
git -C <root> push origin <保护分支>
bash <skill>/scripts/team board set T1.1 done   # 确认进了保护分支才标 done
bash <skill>/scripts/team close T1.1            # 关窗口、清任务
```

**有 PR/MR（forge-first：先合 PR，再快进本地）**：

```bash
gh pr merge --squash --delete-branch <PR>                  # GitLab: glab mr merge <iid> --squash
git -C <root> fetch origin <保护分支> && git -C <root> merge --ff-only FETCH_HEAD
bash <skill>/scripts/team board set <ID> done
```

> 顺序很重要：**先本地 push 会让 PR 立刻变成不可合并**（内容等价但提交不同），
> 报错却常被误读成"PAT 缺 pull-requests:write"。先合 PR 就没有这个问题。
> forge 没有 CLI（Gitea/自建）：用 `tea` 或网页操作，顺序同上。

## G. 并行扩展 / 收缩

```bash
bash <skill>/scripts/team add-agent api            # 新 agent（新 worktree + 分支）
bash <skill>/scripts/team ps                       # 先看容量与模型并发余量再派单
bash <skill>/scripts/team dispatch api T2.1 <taskfile>
bash <skill>/scripts/team teardown --agent api     # 关窗口（保留 worktree）
bash <skill>/scripts/team teardown --all --purge --force   # 连 worktree 一起删（谨慎）
```

规模经验：**并行 agent 数 ≈ min((RAM+空闲swap)/单 agent 占用, 强模型并发上限, 你能复验的带宽)**。
内存不再卡卡地设限（底线是 swap 不打满），但 PM 的复验带宽通常是真瓶颈——派单太快只会堆出待复验队列。
可用 `TEAM_AGENT_MEM_MB`（默认 6144）调估算值；`team ps` 会直接告诉你“还能再加几个”。

## H. 阻塞、冲突、越界

- agent 被阻塞：它会 `team notify` + 写 PARTIAL 报告。PM 的动作：补任务书 → `team say` 唤醒续跑。
- 两个 agent 改了同一文件：让先交付的那个先合并，另一个 `dispatch` 续跑做 rebase/重做（**不要**让 agent
  rebase 别人的分支）。
- agent 发现别人的 bug：报告里写 `BLOCKED:`，PM 决定是插新任务还是让原 owner 修。
- 事实与报告不符：把失败证据贴进 thread，退回；反复出现则换模型族做独立验证。

## H2. 分支与合并（task 模式）

```bash
git -C .worktrees/dev branch --show-current      # task/T1.2-api-health
git -C <root> worktree add --detach /tmp/review-T1.2 task/T1.2-api   # PM 准备独立 checkout
bash <skill>/scripts/team review T1.2 --dir /tmp/review-T1.2 --strong # 门禁带硬超时 + 强复验检查
gh pr merge --squash --delete-branch 17 && git -C <root> fetch origin main && git -C <root> merge --ff-only FETCH_HEAD
bash <skill>/scripts/team board set T1.2 done        # 确认进 main 之后才标 done
```

- 任务分支从保护分支切出；worktree 脏时 `dispatch` 会拒绝切分支（避免两个任务混在一个 diff 里）。
- `close T1.2` 之后 worktree 退回 `detached@保护分支`（`TEAM_TASK_BRANCH_RESET=1`），下一个任务干净开始。

## I. 定时巡检与 PM 节拍（watchdog 只管这一件事）

问题：PM（pi 进程）停了/睡了，agent 发了通知没人处理。定位：**watchdog 不是保活心跳，而是定时问一句
“现在有没有活儿”**——有就叫醒 PM，没有就不打扰（不要求 PM 一直运行）。agent 的启停/续跑仍是 PM 的事。

```bash
bash <skill>/scripts/team watchdog-status      # 看巡检周期、待命、待办、PM 状态、容量
bash <skill>/scripts/team standby on --reason "等用户拍板选型"   # PM 主动停工（不再被叫醒）
bash <skill>/scripts/team standby off         # 恢复叫醒
bash <skill>/scripts/team up                  # 人工救火：建 tmux 场地 + 把 PM 拉起来（不动 agent）
bash <skill>/scripts/team up --agents         # 顺手把“有任务但窗口没了”的 agent 也续起来
bash <skill>/scripts/team resume --dry-run    # PM 自己看：哪些 agent 该续跑
bash <skill>/scripts/team watch --once        # 跑一次巡检（等价于 watchdog 的一个 tick）
```

### 三种部署方式（从弱到强）

| 方式 | 命令 | 能撑住 | 适合 |
|---|---|---|---|
| **tmux 窗口（默认）** | `team watchdog up` | PM 崩/睡；tmux server 活着的范围 | 日常：一个窗口既是看门狗又是**状态监视器** |
| 看门狗窗口 | `team watchdog up` | tmux server / 窗口没了 | 只有这一个后端（无容器依赖） |
| 手动 | `team up` / `team watch --once` | 你自己发现的时候 | 排障 |

```bash
bash <skill>/scripts/team watchdog up          # 默认：本 session 的 watchdog 窗口跑监视器 + 巡检
bash <skill>/scripts/team watchdog logs        # 看一眼监视器画面（pane 快照）
bash <skill>/scripts/team watchdog status      # 窗口/周期/待命/待办/PM 存活/容量
bash <skill>/scripts/team watchdog down        # 关掉窗口
bash <skill>/scripts/team monitor --once       # 手动看一屏（只服务当前 session 的状态）
bash <skill>/scripts/team monitor --activity   # 需要时才追看各 agent 的会话活动流（默认关）
bash <skill>/scripts/team watchdog up --print                # 看它会起哪个窗口/什么周期（不执行）
```

监视器只服务**当前 tmux session**：窗口在不在跑、任务是什么、待办与容量。
各 agent 的会话活动流默认关闭（`TEAM_MONITOR_ACTIVITY=0`）——翻别人的会话既吵又贵
（6 个 agent ≈ 每次读 ~9MB JSONL，实测 RSS 7MB→67MB）；需要时 `--activity` 打开，且只列本 session 里活着的窗口。

```
teamsmith monitor · myproj                       2026-09-11T16:52:03Z  (每 3s 刷新，每 900s 跑一次巡检)
  巡检        900s（待办才叫醒 PM）｜ 后端 tmux
  待命        off
  PM          ● 在运行（pi）
  待办        未读通知 1 · 待复验 2
  容量        RAM 可用 6850MB ｜ swap 空闲 57779/80424MB ｜ 估算可再加 10 个 agent
  dev         ● pi 在跑 ｜ T1.2
  verify      ○ pi 已退出 ｜ -

agent 活动
🟢 活跃 dev          [task/T1.2-api*]  已运行 12m04s · 空闲 8s · 事件 57
     16:51:22 🔧 bash
     16:51:40 💬 实现完成，正在跑验收命令…
🟡 静默 verify        [agent/verify]  已运行 3h02m · 空闲 44m10s · 事件 128
     16:07:03 🔧 read
```

看门狗就是同 session 的 `watchdog` 窗口：跑 `team monitor`（状态面板）+ 按 `TEAM_WATCH_INTERVAL` 定时巡检。
它与 PM 的**取值依赖**解耦（只看磁盘状态与 tmux pane），但不试图脱离 tmux——不再需要 podman/镜像/socket。

每个 tick 三步：① 追一行容量趋势到 `state/capacity.log`；② 算待办（未读通知 / 待复验 / 看板 todo·wip / blocked /
有任务但停了的 agent）；③ **有待办才叫醒**——PM 在跑就发一句 `[watchdog] 待办：…`（同一批待办按
`TEAM_WATCH_NUDGE_GAP` 限制重复频率），不在跑就用 `pi -c` 在原窗口拉起；**没待办就什么都不做**。
`team standby on --reason "…"` 可让 PM 主动停工（之后 watchdog 不再叫醒，待办积压仍会记日志）。

### 边界（故意的）

- **不管 tmux 布局**：session/窗口丢了只告警，不自己建（`TEAM_WATCH_REBUILD_TMUX=0`，默认）。
  想让它连“机器重启/窗口被关”也能自己回来：设 `TEAM_WATCH_REBUILD_TMUX=1`。
- **不管 agent**：有任务但窗口没了的 agent 不会自动续跑——那是 PM 的判断（PM 开场跑
  `team resume --dry-run` 自己决定；人工一条 `team up --agents` 可以代劳）。
- **不管模型额度、不自动合并**：这些是 PM 的活。
- **不要求 PM 一直运行**：没待办的时段 PM 可以安静地待着（甚至不在跑）；watchdog 不会为了“保活”而叫它。
- 防失控：PM 自动拉起配额（`TEAM_WATCH_MAX_RESTARTS`，默认 1 小时 5 次）超了只告警；watchdog 自身有 pid 锁。

### 待命（PM 或人主动停工）

```bash
bash <skill>/scripts/team standby on --reason "等用户授权合并"   # watchdog 不再叫醒
bash <skill>/scripts/team standby status                        # 看原因/开始时间/积压待办
bash <skill>/scripts/team standby off                          # 处理完了，恢复叫醒
```

适用场景：确实没活可推、需要人工介入（授权/选型/外部信息）。进入待命不会丢事：
待办积压仍会写进 `state/watchdog.log`，`team digest` 也会显示。

### 为什么重启后还能接上

进度都在磁盘上：`state/`（模型/窗口/worktree/任务/任务书）、`docs/team/`（任务书/报告/复验/看板/线程）、
git 分支与 worktree。PM 被拉起时用 `pi -c` 延续原会话（历史不丢），并收到开场提示词：
先 `team digest` → `team inbox --ack` → `team resume --dry-run`，再接着干。

### 停机维护 / 故意停掉

```bash
bash <skill>/scripts/team standby on --reason "手动检修"   # 临时：别再叫醒 PM
bash <skill>/scripts/team teardown --all                   # 关所有窗口（worktree/分支/状态保留）
bash <skill>/scripts/team uninstall-watchdog --yes          # 彻底：连 watchdog 也停
```

## J. 持续运行（长项目）

- `BOARD.md` 是唯一事实来源；状态只有 todo/wip/review/done/blocked/dropped。
- 每个里程碑结束：更新 `ROADMAP.md` 状态、把决策写进 `DECISIONS.md`（含理由/影响）。
- 定期归档：已完成的报告与复验记录可移到 `docs/team/archive/`，线程保留（append-only）。
- worktree 长期不清理会占磁盘：`git worktree list` 检查，`teardown --purge` 清理不用的。
