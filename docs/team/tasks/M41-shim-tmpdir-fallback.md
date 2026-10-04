# M41 · shim socket 解析必须复刻 tmux 的回退行为（第 6 次默认 server 死亡实证）

```
task:   M41
agent:  dev2
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M36          # 在 shim 的 socket 解析里修
status: todo
budget: 一个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/dev2`。

## Context（PM 已复现，证据链完整）

第 6 次默认 tmux server 死亡（2026-09-19 14:14:59）根因，PM 实锤：

1. dev3 跑夹具：`T=/tmp/m40tmuxcheck; rm -rf $T; mkdir -p $T; export TMUX_TMPDIR=$T/sock`
   —— **只建了 `$T`，`$T/sock` 不存在**；
2. 后续 `env -u TMUX -u TMUX_PANE tmux new-session/kill-server` 看着是私有隔离，
   但 **tmux 在 TMUX_TMPDIR 指向不存在的目录时静默回退默认 socket**（PM 用 `/usr/bin/tmux` 绕开
   shim 复现：`TMUX_TMPDIR=<不存在目录> tmux ls` 返回的是默认 server 的会话列表）；
3. 于是 `new-session` 在默认 server 上建了 `tsess`，`kill-server` 把整个默认 server 杀了
   （全部项目的窗口阵亡）；
4. M36 shim 的日志记的是「sock=/tmp/m40tmuxcheck/sock/… · act=pass」——**shim 按公式机械计算
   socket 路径，没有复刻 tmux 的目录不存在回退**，所以放行了一个实际打默认 server 的 kill-server。

闸门日志全程清白（只有这一条「假私有」），shim 本身没问题，问题在它的解析模型与真 tmux 不一致。

## Deliverables

1. **修 `skills/teamsmith/scripts/shim/tmux` 的 socket 解析**：用 TMUX_TMPDIR 计算 socket 前先检查
   目录真实存在且可用（至少 `[ -d ]`；tmux 的实际判定如果更细——比如还看可写/可执行位——以真 tmux
   实测为准，报告里写清实测矩阵）；**不可用时按真 tmux 的回退解析**（落到 /tmp 的默认路径）——
   这样 dev3 那类调用会被判成「打默认 server」→ kill-* 直接拒绝，报错里点明
   「TMUX_TMPDIR 指向不存在的目录，真 tmux 会回退默认 socket（假隔离）」。
2. **smoke 断言**（31c 段同族）：
   - `TMUX_TMPDIR=<不存在的目录> tmux kill-server` → 拒绝（exit 64），日志记 `act=refused` + sock=默认；
   - 同形状的只读调用（`ls`）放行但 sock 判定必须是默认路径（不许记成私有）；
   - `TMUX_TMPDIR=<已建目录>` 的私有 kill-server 照常放行（既有断言不回归）；
   - **翻转**：去掉目录存在性检查 → 新断言红。
3. **文档**：`references/troubleshooting.md`（或 shim 头部注释）补上这第二种假隔离形态，
   安全写法一行：`env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<已 mkdir -p 的目录> tmux …`。

## Boundaries

- 只动 shim 的解析 + 对应 smoke 段 + 文档；不改拒绝清单（kill-server/kill-session/kill-window/kill-pane）
  与放行旋钮语义。
- 测试自己守纪律（私有 socket 目录先 mkdir -p）；跑门禁前后 `tmux ls | head -3` 探活默认 server。
- **别顺手改 dev3 正在做的 M40**（cwd-is-identity）——那是另一个任务。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 事故形状实录：逐字节复现 dev3 的 14:14:58 命令（rm -rf; mkdir -p 只建父目录; TMUX_TMPDIR 指向不存在的
# 子目录; env -u TMUX tmux kill-server）→ 必须被 shim 拒绝且日志 sock=默认；报告贴输出
```

## Report

`docs/team/reports/M41-dev2.md`。

---

## 追加约束（2026-09-19 15:05 · 第 8 次死亡后由 PM 补写）

**第 8 次的凶手是 PM 自己**：PM 用 `/usr/bin/tmux`（**绝对路径绕过闸门**）+ `TMUX_TMPDIR=<未创建的目录>`
跑 `kill-server` 验证回退行为 → 真 tmux 回退默认 socket → 默认 server 阵亡（15:05:5x）。
两个新要求：

1. **绝对路径盲区**：shim 只能拦 PATH 里的 `tmux`；`/usr/bin/tmux`、`command tmux` 等绕过。
   - 仓库脚本/fixture 里**禁止**用绝对路径做破坏性 tmux 调用（加静态检查；`REAL_TMUX` 解析类例外照旧）；
   - shim 头部注释 + `references/troubleshooting.md` 写明这个盲区。
2. **破坏性夹具一律进容器**：任何会 `kill-server`/`kill-session` 的复现或探针，默认跑法是
   `bash skills/teamsmith/tests/container-tmux.sh -- <cmd>`（M28 的容器把宿主 socket 目录挡在挂载外，
   构造上打不到宿主）；宿主机上只许跑「私有目录已 mkdir -p」这一种形态，且必须走 shim 的 PATH。
   任务书的验收命令按此改写；报告里贴容器内的输出。
