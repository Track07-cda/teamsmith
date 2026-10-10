# P230 · long-job-suspend · A 刀：车道侧（extension + 独立入口）

task: P230
agent: dev2
phase: apply
category: code
change: long-job-suspend
specs: background-jobs, notify-and-inbox
deltas: background-jobs, notify-and-inbox
branch: task/P230-long-job-suspend-apply-a
deps: E17（提案已 ACCEPTED，见 docs/team/reviews/long-job-suspend-proposal.md）

## 范围（只做 A 刀，B 刀另派）

实现 `openspec/changes/long-job-suspend/` 里属于**扩展侧**的合同（提案已接受，tip `d7f9453` 的提案文本是唯一来源）：

1. `skills/teamsmith/extension/team-bg.ts`
   - `team_bg_run` 的 description、promptGuidelines、起作业回执文本，与 `team_bg_wait` 的 description：按 design 决策 1 的口径改写——**起完默认结束回合**，完成叫醒是正常收割点；原地等是**有界例外**（预算约 2 分钟 + 结果卡住下一步 + 无别的可推进，三条同时成立）；不得再出现「回合结束前必须收割」的措辞，不得把叫醒写成损失。完成叫醒的合并消息继续点名每个未收割 job id 并指引 `team_bg_wait`（既有行为，钉住）。
   - 账本新增两类行（写在车道自己的 state 目录，与 `.job` 记录同一点位；ISO 时间戳沿用既有 append 逻辑）：`start id=<id> pid=<pid>`（返回 id 之前）与 `wait id=<id> outcome=<harvested|running|interrupted> waited_s=<秒>`（每次 `team_bg_wait` 返回；`waited_s` **只量本次调用**自己等的时间，不是作业年龄）。既有 `wake …` / `settled-with-unharvested=…` / `spawn-error …` / CLI 的 `stop …` 行形状**逐字节不变**。
2. `skills/teamsmith/extension/team-notify.ts`
   - 挂起判定：从**车道写记录的那个目录**读 `state/bg/*.job`（按车道的解析规则：显式 `TEAM_STATE_DIR` 优先；否则「cwd 的 worktree 带 `.pi/team/config.sh` → 它自己；`TEAM_ROOT`；最近的带 config 的祖先；git 主工作树」）——**不许用 notify 自己的 root（`--git-common-dir`，落主工作树）顶替**；逐条 `(pid, start-time)` 活体验证（与 `team bg list` 同一身份规则），验不过不算在跑。
   - 完成 + 在跑非空 → 标签 `[auto·suspended]`、带 `awaiting=<id>[,…]`、**省略** `⚠ 未提交 N 个文件 · ` 前缀（`uncommitted=<n>` 字段保留）；未完成 + 在跑非空 → 保持 `[auto·interrupted]` 并带 `awaiting=`；其余形状逐字节不变。判定中的任何失败（目录不可读、记录畸形、/proc 读不到）一律退回非挂起形状（fail-closed，不假造挂起）。
3. `skills/teamsmith/tests/bg-ledger.sh`（**新独立入口**，`--select wording,ledger,suspend-shape,flip`）
   - 词面：registered tool texts 呈现挂起默认与例外三条，旧措辞零命中。
   - 账本：`start` 先于返回、`wait` 每次返回一行且 `waited_s` 只量本次调用；超时/中止分别记 `outcome=running|interrupted`；「起了就等」与「挂起」只凭账本可区分。
   - 挂起形状：完成 + 活记录 → suspended；死 pid / 指纹不符（复用）→ 不挂起；中断 + 活记录 → interrupted + `awaiting=`；worktree 自带 config 的形状用**自己**的记录、主工作树诱饵不算；显式 `TEAM_STATE_DIR` 里的记录算数、notify root 下诱饵不算。
   - 夹具纪律：清继承的 `TEAM_*`、断言 `team paths` 解析到夹具、跑后断言真账本未动（既有 §13c 的纪律）。
   - **flip 组**（对 scratch 源码做真实破坏，必须变红、还原后绿）：措辞回退 / 删 `start` 行 / `waited_s` 记成作业年龄 / 去掉身份验证 / 改成读 notify 自己的 root。

## 边界

- **不要**碰 B 刀的东西：`scripts/lib/cmd-agents.sh`、`templates/**`、`references/**`、`smoke.sh` 与 section-select 映射表——它们等 `task-model-routing` 的 S1/S3 释放后由 PM 串行派单（design 决策 8）。
- 不改叫醒的传输机制、不改工具名与 `team_bg_wait` 行为语义（默认超时、返回形状不变）、不给非 Pi 适配器另造车道、不动派单/身份/模型路由代码。
- 不删/skip 既有断言换绿；不把「例外三条」放宽成「或」。
- 不 push、不合并、不归档；不勾 `tasks.md` 的 B 刀项（只勾你真正做完的 A 刀项，并在报告里点名）。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,flip
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-bg.ts skills/teamsmith/extension/team-notify.ts skills/teamsmith/tests/bg-ledger.sh
git diff --check && git status --short
```

另：`flip` 组的红/绿对照要留下可跑脚本与输出（证据包按 D94 放仓外 `pm-skills-ledger/team/reports/P230-dev2/`）。

## 交付

- 上述两个扩展 + 新入口的改动（Conventional Commits + 任务 ID + `Agent: dev2` trailer）。
- `docs/team/reports/P230-dev2.md`：改动清单、五条验收的真实输出、flip 红绿对照、未解问题、B 刀遗留。
- 做完按协议通知 PM（`team notify pm`）；**不实现 B 刀**，它由 PM 在 routing S1/S3 释放后另派。
