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
| 可用内存 X MB < 阈值 | `TEAM_MIN_FREE_MB` 守卫 | 等其它 agent 结束；或临时 `TEAM_MIN_FREE_MB=0 team dispatch ...` |
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
- 冲突：`team merge` 会尝试 abort 并打印冲突文件；处理完再重跑。
- 合并前主工作树必须干净且在保护分支 —— 这是刻意的：避免把 agent 的脏状态混进合并提交。

## 7. forge（github / gitlab）

- `gh` 401/403：PAT 文件路径/权限/scope。合并需要 `pull-requests: write`，很多 PAT 没有 →
  退回本地 squash + 评论 + 关 PR（见 `workflows.md` F）。
- GitLab 403：token 需要 `api` scope 且有 Developer 以上角色；MR 目标分支若受保护，
  Developer 角色可能无法合并。
- 永远用 `team gh` / `team gl` / `team pr`，不要自己 `cat` token；不要 `export GH_TOKEN`。

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

## 12. Pi 相关的通用坑

- **测试结论必须来自当次真实执行**：把命令与输出尾部写进报告，PM 复跑。
- 类型导入（`import type`）在开启 `verbatimModuleSyntax` 等项目下是硬要求——这类项目规则
  要写进 `AGENTS.md`，否则弱模型会反复踩。
- 终端抓屏不可靠（TUI 刷新/换行），别把 tmux scrollback 当证据；报告与日志才是。
- 长任务无进展：让 agent 每 30 分钟在报告里落一次状态，或 `team say` 问一次进度。
- 强模型很慢且额度低：一次只跑一个（`TEAM_MODEL_LIMITS`），PM 别同时派两个。
