# P334 · 门禁的私有 tmux 锚点不能活过它自己那一轮（我们自己的套装就会漏进程）

task: P334
agent: dev3
phase: apply
category: code
change: -
anchor: openspec/specs/verification/spec.md#The gate judges behaviour only, and never reports a skip as a pass
deltas: -
branch: task/P334-anchor-lifetime
deps: P326 与 P333 已并入 main（`smoke.sh` 单写者纪律，不得并发写）

## 问题（PM 已实测，一次干净复现）

`smoke.sh:1014`–`1024`：调用者本来在 tmux 里时，本轮会给自己在**私有** server 上建一个锚点 session：

```
TMUX_TMPDIR="$SMOKE_TMUX_TMPDIR"; export TMUX_TMPDIR
SMOKE_TMUX_ANCHOR="teamsmith-smoke-anchor-$$"
tmux new-session -d -s "$SMOKE_TMUX_ANCHOR" -n anchor "sleep 100000"
```

`cleanup()`（`smoke.sh:1316`）确实有 `kill-server`（私有 socket、`tmux_iso_guard_soft` 过了才执行）。但**进程一旦不是自己退出的，EXIT 陷阱就跑不到**。

PM 的复现（2026-10-20 08:38Z，就是本机）：从 PM 窗口（在 tmux 里）起一次 FAST 档 `smoke.sh`，让它被外部超时掐掉——**3 分钟后锚点 server 仍在**：

```
4157220  1  03:08  tmux new-session -d -s teamsmith-smoke-anchor-4155674 -n anchor sleep 100000
```

pid 的 ppid 已经是 1，`sleep 100000` 会一直睡着。盘上同一族还有 4 个更老的（Oct 15 一个、Oct 19 两个、Oct 20 一个），全部 `ppid=1`、cwd 指向已被删掉的夹具根 —— 也就是**每一轮被掐死/被信号打断的门禁，都会在本机永久留下一个私有 tmux server**。这个项目里门禁就是这样被跑的（超时预算、长作业车道都会终止它）。

顺带一条无关的旧账：同一台机器上还挂着两个 4 天前某次泄漏探针留下的 `shim/tmux`，各自空转约 **28 CPU 小时**（父进程早没了、读一个没有写端的管道）。那条来自席位在 `/tmp` 下的临时脚本，不是本仓代码，**本任务不管**；只在报告里记一句别把它当成本次范围。

## 要做的（一处，让锚点的寿命跟本轮绑定）

`cleanup` 的 `kill-server` 留着（正常退出/可捕获信号就该立刻收）；补的是**不可捕获的那一半**：让锚点 session 自己发现「起它的那一轮已经不在了」并退出，于是 server 随之消失。

- 锚点 pane 里那条 `sleep 100000` 换成一个**只看本进程树、不新增框架**的命令：本体 pid 还在就等，本体没了就退出（例如按 `$$` 记录的 pid 做 `kill -0` 轮询，间隔取秒级即可）。它必须是**纯 bash + sleep**，不许引入新脚本、新工具、新的守护进程。
- `$$` 要在建 session **之前**落成变量，并注意 `bash` 里 `$$` 是**外层 shell** 的 pid（本轮的 smoke 主进程），不要写成子 shell 的 `$BASHPID`——目的是「这一轮没了就收」，不是「某个短命子进程没了就收」。
- 私有 socket 目录那段清理里，前缀判断目前只认 `.tm-*`，而实际生成的是 `.t-<uid>.<随机>`（PM 观察到 `SMOKE_TMUX_TMPDIR=/tmp/.t-1000.96rJ5e`）——**先自己核实**再动：若确实对不上，就按实际形状收窄匹配（只收本轮自己的那一个，不许前缀通配），并在注释里写明依据。核实不了就如实写「未验」，不要猜。
- 不要新增门禁段、不要给 `tmux_iso_guard_soft` 放水、不要改成 `kill-server` 无隔离、不要碰 §0c 的 socket 路径长度判据。

## 必须交的证据

1. **正向**：正常运行（不是 FAST 也行，用最小段）跑完后，`ps` 里没有本轮的 `teamsmith-smoke-anchor-<本轮 pid>`；同时运行**期间** `$TMUX`/`$TMUX_PANE` 仍然有效（拿一条既有的「在 tmux 里」断言或直接打印证明，别删掉这条能力的理由）。
2. **反向（关键）**：起一轮带 `--keep` 的选段，**从外部**用 `kill -9` 打死它（就是 PM 复现的那个形态），等 ≤30 秒，`ps` 里必须**没有**那个锚点 server；打印 `ps` 原始输出与耗时。**这一条不过，本任务不算完成**——它正是今天的缺陷。
3. **不误伤**：同一次实验里，调用者自己的默认 server（`$TMUX` 指的那个 session）必须照旧活着；把你杀掉的那一轮的锚点名字与默认 server 的 session 名一起打印出来对照。
4. 断电式复核：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。
5. 报告里给「改动前同一实验也会留下锚点」的对照（PM 已有一次复现，你可以引用，也可以自己再跑一次作证；两次都写清时间与 pid）。

破坏与实验只在自己的磁盘目录（`/var/tmp/…`，私有 `TMPDIR`、私有锁）；**实验期间不要去跑会抢机器级门禁锁的整套**，也不要碰别人的运行。

## 边界

- 写集：`skills/teamsmith/tests/smoke.sh`（**只有锚点建立那几行、pane 命令、以及第 3 点的 socket 目录前缀判据与注释**）、`docs/team/reports/P334-dev3.md`。
- 不碰产品实现、不碰其它测试文件、不动任何时限/预算、不新增检查器或门禁段。
- 净零：这条改的是「我们自己的门禁每跑一次漏一个进程」的默认行为；没有新增守卫。
