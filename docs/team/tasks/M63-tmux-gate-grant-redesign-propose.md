# M63 · 破坏性 tmux 调用的授权模型重做（propose）

```
task:   M63
agent:  dev-bob
issue:
change: tmux-gate-grant-redesign
specs:  -
phase:  propose
anchor: change
deltas: boundary
deps:   M62（它的 BLOCKED 证据是本任务的输入；policy B：这是跨任务规则，必须走 change）
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md；不写实现）
```

> 本地模式：不 push。**只 propose。**

## 用户已拍板的方向（方案 2，2026-09-21）：不是"修一下"，是把授权模型重做

**把"override"这个概念从窗口路径里整个删掉。** 提案必须围绕这五条（用户已确认）：

1. **判定按目标归属，不按命令名**：破坏性调用 → 解析目标 socket/对象；目标是**共享默认 socket**
   → **一律拒绝（exit 64）**，shim 路径**没有 override**；目标是**本项目会话内的具名对象**
   （例如 `team teardown` 杀自己会话的窗口）→ 允许并**记审计行**。"属于本项目"的判据要在 design 里写死
   （建议：目标 session 名 == 本项目 `TEAM_SESSION`，且不得为空；`kill-server` 对默认 socket 没有任何例外）。
2. **唯一的逃生口是人的显式动作**，且**都不可继承**：
   - 绝对路径 `/usr/bin/tmux` 直接绕过 shim（文档写明的显式行为）；
   - argv 级一次性标志（design 定名，例如 `--teamsmith-allow-destructive`）：shim **消费并从 argv 剥掉**再 exec，
     **绝不进入环境**；带标志的调用也记审计。
3. **CLI 自用不再 export**：`scripts/team:19` 的 `export TEAM_ALLOW_DESTRUCTIVE_TMUX="${…:-1}"` 移除；
   CLI 自己的破坏性调用改用 argv 标志。环境变量 `TEAM_ALLOW_DESTRUCTIVE_TMUX` 从"授权"退役
   （design 要裁决：从 schema/config.md 删除 vs 保留为 refuse 类的历史兼容项——给出取舍）。
4. **默认值对齐**：以 schema 的 `0`（拒绝）为准；文档与实现不得再相反。
5. **证据**：窗口形状破坏性调用 → exit 64；CLI 自用（argv 授权）→ 允许+审计；
   "server 带着旧变量启动不影响判定"的回归夹具；**2026-09-21 事故形状的复现夹具（容器里）**。

## 证据（全部已落盘，提案要引用而不是重新发明）

- `docs/team/reports/M62-dev-bob.md` §5（BLOCKED）：泄漏链复现（server 全局环境继承 → 窗口 environ 带授权）；
- `docs/team/reviews/M62.md` + 事故附录：PM 独立复现 + **第 7 次默认 server 死亡**
  （shim 日志 `act=refused` → `act=override` 连续两行 = PM 自己的演示把闸门打开了）；
- 两个代码点：`scripts/team:19`（export 且默认 1）与 `cmd-config.sh` schema（默认 0）**互相矛盾**；
- 审计统计：`state/tmux-calls.log` —— 闸门上线路径里 `act=refused` 几乎为零、`act=override` 全是真杀窗口。
- shim 现状读 `skills/teamsmith/scripts/shim/tmux`（M36/M41 建的 socket 解析与两个回退形态——
  **重构时这两个回退形态必须保留判定**，别顺手简化掉）；调用点迁移面：`grep -rn TEAM_ALLOW_DESTRUCTIVE_TMUX`。

## 提案要裁决的设计问题（design 里逐一回答）

1. argv 标志的确切名字与语法（长标志？会不会与 tmux 自身参数冲突？shim 剥离的位置）；
2. "本项目会话内具名对象"的精确判据（含空目标、跨会话目标、相对目标的处置——复用 M40 的身份推导）；
3. `team teardown` / 复验清理 / `team up --agents` 等**现有合法破坏路径**如何表达授权（逐个点名，不许漏）；
4. 旧环境变量的退役路径（删键 vs refuse 兼容项；对存量使用者的迁移说明）；
5. 测试里的破坏性夹具（M41 的 lint 禁绝对路径破坏性调用）在新模型下怎么写——argv 标志在测试里是否允许、
   还是一律容器；
6. 审计行形状（`act=allowed-owned|refused|explicit-flag`，以及"override"这个词是否从词汇表删除）。

## 硬要求

- **这是跨任务规则（破坏性动作 + 越权 + 门禁），policy B 强制**：delta 落在 `boundary`，requirement + scenario，
  每条可证伪；`## REMOVED` 只在确有必要时用且说明；MODIFIED 不得删 base 的任何 scenario；
- 规模控制：预计 3–5 条 requirement、12–20 条 scenario；**不要膨胀**；
- 每条 requirement 在 design 里给"复核方法"（跑哪个脚本/看哪一段，期望什么）；
- 不碰实现（`scripts/**`、`tests/**`、`extension/**`、`references/**` 一律不改）；发现新矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/tmux-gate-grant-redesign/{proposal.md,design.md,tasks.md}`
- `openspec/changes/tmux-gate-grant-redesign/specs/boundary/spec.md`
- 报告 `docs/team/reports/M63-dev-bob.md`

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
