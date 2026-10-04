# M75 · tmux-gate-grant-redesign 独立验证（verify 阶段）

```
task:   M75
agent:  dev3
issue:
change: tmux-gate-grant-redesign      # propose=M63（dev-bob）· apply=M67（dev-bob）→ verify 必须换人（D31）
specs:  boundary#A destructive tmux call is decided by the object it targets, never by an inherited environment / boundary#The gate's actions are logged, and no window carries a destructive-call grant / boundary#Destructive gate fixtures never aim the real tmux at the real default socket
phase:  verify
anchor: change
deltas: boundary
grant:  docs/team/reports/M75-dev3.md · docs/team/reports/M75-dev3/**（只写报告与证据，不改实现）
deps:   M63（propose）· M67（apply，已合并）· M62（它当年 BLOCKED 的那条现在为真）
status: todo
budget: 一个工作块（只写复验证据与报告，不改实现）
```

> 本地模式：不 push。**纪律第一条：一切破坏性探针必须对着 argv 记录 stub 或私有 socket，绝不瞄准真实默认 socket**——
> PM 本人 2026-09-21 就是用真默认 socket 演示这条链，第 7 次杀掉了整台机（reviews/M62.md 事故附录）。容器夹具走 `container-tmux.sh`。

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **判定按目标（R1）**：
   - 私有 socket → **逐字节直通**（argv 不许被改写），记 `act=pass`；
   - 共享默认 socket：`kill-server`、`kill-session -a` **永远 exit 64**；三个子命令仅在
     `-t` 有效值非空、session 段字面等于**绑定的** `TEAM_SESSION` 时放行（`act=allowed-owned`）；
   - 不可证明的目标（无 `-t`/空/`%N`/`@N`/`:win`/`.`/`+`/`-`/裸窗名）→ 64；
   - **M41 的表格与两个"假隔离"形态不许被放宽**（私有 socket 判定、`TMUX_TMPDIR` 不存在时回退默认 socket 等）——
     逐个重跑并贴结果。
2. **环境零授权（R2，当年 BLOCKED 的那条）**：
   - 调用方环境带 `TEAM_ALLOW_DESTRUCTIVE_TMUX=1` → **判定不变**（默认 socket 的 kill-server 仍 64）；
   - **泄漏形状**：server 的**全局环境**带这个键（在容器里造）→ 窗口里的调用仍被拒；
   - `grep -rn TEAM_ALLOW_DESTRUCTIVE_TMUX` 找**任何残留读取方**（shim/脚本/扩展）→ 应只剩退役说明与 schema 墓碑行；
   - 词汇表：`grep -rn "override"` 在闸门代码/日志/报错里应**不存在**（`pass|allowed-owned|refused|explicit-flag` 四值）。
3. **argv token 的真假两态（R2）**：
   - `--teamsmith-allow-destructive` 只在**全局参数位**被识别：消费并从 argv 剥掉、**不进被执行进程的环境**、
     记 `act=explicit-flag`、对任何 socket 都执行；
   - **子命令之后的同名词是数据**：`send-keys -t X --teamsmith-allow-destructive` 的载荷必须**原样**到达下游；
   - `=1` 形式不识别 → 落到 tmux 报错（fail closed）。
4. **CLI 自用路径没坏（D5）**：`team teardown` / `team review` 的窗口清理 / `add-agent` 清理 /
   pulse 的卡窗处理——**都不带 token**，靠 ownership 过；至少挑两条在私有 socket 上实跑证。
5. **doctor 与墓碑（R2 的可见面）**：运行中的 server 全局环境带着退役键时 doctor 提示一行；
   schema 里那行仍是 refuse 类（`team config set TEAM_ALLOW_DESTRUCTIVE_TMUX 1` → exit 5）。
6. **夹具纪律（R3）**：`container-tmux.sh --selftest` 真跑（或可见 SKIP）；跑完**宿主指纹逐字节不变**
   （默认 server 的会话列表/客户端数、`tmux -V`、宿主 `state/tmux-calls.log` 不因夹具改变）。

## 变异（至少两条，红→绿原始输出）

- 把判定里"绑定身份"的条件去掉（或改成只比 session 名）→ 夹具必须红（指名那条）；
- 把 token 的"全局参数位"限制去掉（子命令后也剥）→ 载荷透传那条必须红；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/container-tmux.sh --selftest   # 无容器：可见 SKIP
```

## Boundaries

- **不改实现**（`scripts/**`、`tests/**`、`extension/**` 一律不改）；缺陷写清楚交回 PM；
- 不 push；不改 `docs/team/**` 里 PM 的文件。
