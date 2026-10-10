# V20 · long-job-suspend A 刀独立复验

task: V20
agent: verify
phase: verify
category: verify
change: long-job-suspend
specs: background-jobs, notify-and-inbox
deltas: background-jobs, notify-and-inbox
branch: task/V20-long-job-suspend-apply-a-verify
deps: P230（A 刀 apply，已交付 8913ba341037）；E17（提案 ACCEPTED，docs/team/reviews/long-job-suspend-proposal.md）

## 你复验的是什么

`long-job-suspend` 的 **A 刀**（扩展侧）实现：候选冻结 tip **`8913ba341037`**（分支 `task/P230-long-job-suspend-apply-a`，本地未推）。改了三个文件：`skills/teamsmith/extension/team-bg.ts`、`skills/teamsmith/extension/team-notify.ts`、新增 `skills/teamsmith/tests/bg-ledger.sh` 与 `bg-ledger-harness.mjs`（作者自带的入口与夹具）。

**不在本轮范围**（B 刀未实现，别当缺陷报）：`scripts/lib/cmd-agents.sh`、`templates/**`、`references/**`、`smoke.sh` 的登记。`dispatch` 那份 delta 的场景**本轮不可验**——在报告里明确写成「未实现、未验」，不要静默跳过、也不要算它通过。

## 被检树与控制面

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
CANDIDATE="$CONTROL_ROOT/../pm-skills-ledger/team/reviews/V20/checkout"   # 由 PM 准备：独立真实 clone，detached 在 8913ba341037
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/V20-verify"
```

先核对：clone 的 HEAD 是 `8913ba341037`、`.git` 是真目录、`git status` 干净；产品/测试与交付一致。自己另做 fixture 时用 `/tmp` 下的 scratch，别把候选树当运行环境（夹具要清继承的 `TEAM_*`）。

## 必须自己做的检查（不许只复跑作者入口）

1. **五条破坏面各自有牙**（在 scratch 副本里做，还原后必须复绿）：① 措辞回退成「回合结束前必须收割」→ 词面场景红；② 删掉 `start` 行 → 账本场景红；③ `waited_s` 记成**作业年龄**而不是本次调用等待 → 挂起/内联区分场景红；④ 去掉 `(pid, start-time)` 活体验证 → 死 pid / 复用 pid 场景红；⑤ 把记录目录改成 notify 自己的 root → worktree-自带-config 场景与 `TEAM_STATE_DIR` 场景红。
2. **既有行形状逐字节不变**：`wake count=…`、`settled-with-unharvested=…`、`spawn-error …`、CLI 的 `stop …` 与新行的插入点不破坏旧读者（给一条自己构造的旧格式账本，跑一轮，确认旧行不被重写/不消失）。
3. **fail-closed**：目录不可读、记录畸形、`/proc` 读不到时，通知**不得**出现挂起形状（要有你自己的反例，不能只跑作者的）。
4. **状态目录规则**：显式 `TEAM_STATE_DIR` 优先；worktree 自带 `.pi/team/config.sh` 时用**自己**的记录（主工作树放诱饵记录）；两条都要有你自己的夹具与红侧。
5. **不越界**：`team_bg_wait` 的默认超时与返回形状未变；`extension` 没有引入 Pi/provider 解析或兼容矩阵；内置 Pi 启动命令（`-e` 集合与顺序）逐字节不变（`git diff` 核）。
6. **回归**：按 `bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/extension/team-bg.ts skills/teamsmith/extension/team-notify.ts` 选段跑一遍；容器内跑一次 FAST（`TEAM_SMOKE_FAST=1`）确认没有新红（把命令与结果贴进报告）。

## 交付

- 复验记录：`docs/team/reviews/V20.md`（判定 `PASS` / `FAIL` / `NEEDS-CHANGES`，逐条命令 + rc + 证据路径；FAIL 要说清哪条场景、什么形状、复现命令）。
- 证据包（D94 仓外）：`pm-skills-ledger/team/reports/V20-verify/`。
- 不改候选树、不合并、不推送；结论按协议通知 PM。
