# V73 · P334 的独立验收：门禁的私有锚点必须随本轮消失（外部 kill -9 也不许留）

task: V73
agent: dev2
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 门禁自己建的私有终端锚点的寿命
deltas: -
branch: task/V73-anchor-lifetime-verify

## 受检与问题

候选 `ca9f4929`（实现 `185b81fc`），报告 `docs/team/reports/P334-dev3.md`。改动只在 `skills/teamsmith/tests/smoke.sh` 两处：锚点 pane 从 `sleep 100000` 换成 `while kill -0 <本轮 pid>; do sleep 2; done`；socket 目录回收的形状判据从前缀 `.tm-*` 改成实际的 `.t-<uid>.<6 位>`。

要回答两件事：**（一）不可捕获的终止之后，锚点真的自己走掉了吗？（二）这个判据会不会误伤别人的东西？**

## 必须自己做的（先读报告，再自己造现场，别照抄它的实验）

1. **外部 `kill -9`（核心）**：在你自己的磁盘目录（`/var/tmp/…`，私有 `TMPDIR`、私有锁）里，从**一个 tmux 会话内部**起一次带 `--keep` 的选段运行（例如 `--select 0c`），然后从外部对**跑套件那个进程**发 `kill -9`。要求：≤30 秒内 `ps` 里不再有那个 `teamsmith-smoke-anchor-<它的 pid>`；贴出杀前/杀后的 `ps` 原文与耗时秒数。**再跑一次同样的实验**确认不是一次运气（两次都过才算过）。
2. **误伤检查（同等重要）**：同一次实验里
   - 你**自己调用者**的 tmux server 与 session 必须照旧活着（把名字与 pid 前后各打一次）；
   - 另一个**并行**的锚点（可以是你在实验前手动建一个假的 `teamsmith-smoke-anchor-<别的 pid>`，或同机另一个在跑的门禁）**不许**被这次运行带走；
   - `kill -9` 之后 socket 目录**允许**留下（报告已把它写成已知边界）——但你要确认留下的是**空目录**、不是还有一个活 server 在里面：`ls` 目录内容 + `ps` 里没有对应 server。
3. **形状判据只收自己那一个**：静态核 `case "$(basename …)" in .t-"$(id -u)".??????)` 这一行——把 `SMOKE_TMUX_TMPDIR` 设成几个**不该被收**的形状（例如 `$TMP/tmux`、`.t-<uid>.short`、`.t-<别的 uid>.abcdef`、`.t-<uid>.abcdefg`）各跑一次 `cleanup` 可达的最小入口（或直接在你的副本里调那段 `case`），确认它们**不会**被当成「本轮那一个」删掉；再把真实形状放进去，确认**会**。这一步是防「收窄成通配」。
4. **正常路径没被改坏**：一次正常退出（不带 `--keep`）之后，`ps` 里没有锚点、socket 目录也没了（贴 `ls` 结果）。
5. **`kill -0` 的僵尸形态**：报告说没验「父进程永不 reap」的情形。你不必为此造一个实验来证明它被覆盖——**只需判断这条边界在真实终止形态下会不会发生**（本仓的终止形态是超时预算与后台车道，父进程都会 `wait`），用一句话写清你的判断与依据；不许把它写成「已覆盖」。
6. 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

实验期间先 `ps` 确认没有别人的门禁在跑；**不要**跑整套、不要跑容器、不要抢机器级门禁锁。清理只删你自己建的锚点与目录，按显式 pid。

## 边界与交付

只读代码、只写 `docs/team/reports/V73-verify.md` 与自己的线程；不改实现、不合并、不 push。结论先写 PASS/PARTIAL/FAIL，再给命令、原始尾部与秒数；没做的如实写「未验」。local 模式，PM 合并与关单。
