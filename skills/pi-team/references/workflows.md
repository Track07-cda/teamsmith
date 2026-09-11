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
# github 模式：先建 issue（可选，但推荐：issue 是需求口径，任务书是执行口径）
printf '# 骨架与质量门禁\n\n## DoD\n- ...\n' > /tmp/issue.md
bash <skill>/scripts/team gh issue create --title "[T1.1] 骨架与质量门禁" --body-file /tmp/issue.md --yes

bash <skill>/scripts/team task T1.1 --title "骨架与质量门禁" --agent dev --issue 12
$EDITOR docs/team/tasks/T1.1-*.md      # 写清背景/交付物/边界/验收命令

bash <skill>/scripts/team add-agent dev
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
bash <skill>/scripts/team review T1.1                      # 自动找分支 → detached worktree → 跑门禁
bash <skill>/scripts/team review T1.1 --branch task/T1.1-x --no-gates   # 只做人工评审
```

产物 `docs/team/reviews/T1.1.md`：HEAD、diffstat、提交列表、文件清单、门禁输出尾部、结论清单。
门禁失败时命令返回非 0 —— 别忽略。

**PM 自己也要读 diff**：门禁只证明「现有测试没挂」，不证明「实现符合任务书」。

## F. 合并与收尾

local 模式：

```bash
git -C .worktrees/dev switch main 2>/dev/null || true    # （worktree 不切 main；主工作树才是主）
git -C <main-root> status                                 # 必须干净且在保护分支
bash <skill>/scripts/team merge T1.1 --push               # 默认本地 squash → 需要 --yes
bash <skill>/scripts/team close T1.1                      # 关窗口、清任务、BOARD → done
```

github 模式：

```bash
bash <skill>/scripts/team pr T1.1 --yes                   # 用复验记录/报告作为 body
bash <skill>/scripts/team gh pr checks                    # 只读命令无需 --yes
bash <skill>/scripts/team gh pr merge <N> --squash --yes  # PAT 有 pull-requests:write 才行
```

gitlab 模式：

```bash
bash <skill>/scripts/team pr T1.1 --yes                                   # POST merge_requests
bash <skill>/scripts/team gl GET "/projects/<id>/merge_requests?state=opened"
bash <skill>/scripts/team gl PUT "/projects/<id>/merge_requests/<iid>/merge" --yes
```

> 若 PAT 没有合并权限（返回 403），退回 CEP 的做法：
> 本地 `git fetch origin <branch> && git merge --squash FETCH_HEAD && git commit && git push`，
> 然后 `team gh pr comment <N> --body "squash 合并于 <sha>"` + 关闭 PR。

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

| 方式 | 命令 | 能撑住 |
|---|---|---|
| 手动 | 发现 PM 停了/睡了就 `team up` | 你自己发现的时候 |
| tmux 窗口 | `tmux new-window -n watchdog -d -- <skill>/scripts/team watch` | PM 崩/睡（tmux server 还在） |
| systemd --user | `team install-watchdog --yes` | 上面全部 + watchdog 自己崩（配 `TEAM_WATCH_REBUILD_TMUX=1` 还能扛机器重启） |

```bash
bash <skill>/scripts/team install-watchdog --yes      # 装 + 开机自启（systemd --user）
bash <skill>/scripts/team watchdog-status             # 看状态与最近巡检
bash <skill>/scripts/team uninstall-watchdog --yes    # 停掉（--purge 连 unit 文件一起删）
loginctl enable-linger $USER                          # 建议：没登录时也让 unit 跑
```

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
