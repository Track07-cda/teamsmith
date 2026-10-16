# P305 · 门禁锁抗删除：补齐清单里如实留空的 8 项 + 修 F1（归档前置）

task: P305
agent: dev-bob
phase: apply
category: code
change: gate-lock-external-deletion
specs: verification, boundary
deltas: -
branch: task/P305-gate-lock-gaps
deps: P303（勾选已并入 main；留空原因见 `docs/team/reports/P303-dev-bob.md` §留空项与原因）｜V53（两轮 PASS，但那是**修 F1 之前**的树）

## 要做的五件（排序＝优先）

1. **F1（真缺陷，必修）**：`flip-p287-lock.sh --self-test` 在**并入 main 的树**上 rc=1。根因（你已查明、我复现）：leg2 的「改动前的树」探测写成 `git show … | grep -q …`，脚本 `set -o pipefail`，`grep -q` 命中即退 → `git show` 吃 SIGPIPE（141）→ 管道整体非 0 →「不含伴生锁」被误判为真；而**并入 main 后 main 本来就含变更**，于是这条腿选了含变更的树。
   **改法（两条都要求）**：① 探测**不许**用会提前退出的管道（`git show … | grep -q` 之类）——把内容读进变量或用不早退的形式；② leg2 的「改动前」**必须真的往回找**（点名一个**确定的**改动前提交/tag/记录的基线 tip，而不是 `main`），并在报告里证明它**选中的确实是那棵树**。**红侧**：把探测改回旧写法 → 该腿必须**再次红**（你今天这个现场就是现成的红侧）；再把基线指回 `main` → 也必须红（说明它不再真空通过）。
2. **1.1 的三向断言**：补「**非 git 检出 / PATH 无 git 时 `team_project_ns` 不报错**」的断言（你的手工探针只证明了行为，没有断言）。
3. **2.4 的断言**：补任务书点名的 `mtime >= claimed`（取锁时刷了伴生锁 mtime）——用 `stat -c %Y` 前后对照。
4. **4.1 的逐字 diff 证据**：按我下面的**裁定**产出证据。
   **PM 裁定**：两条防御性文案（「排队/加锁失败：flock 没能把本套跑起来」「注意：flock 探锁失败」）的**消失算机制改写的必然**——准入条件冻结的是「上限算式 / token 闭集 / 退出码集合 / `team_review_verdict`」，不是那两句文本；新实现（进程内 fd + 有界轮询）里「加锁失败」这条路径的等价表达是**非零退出 + 一行点名**。请你：① 产出**冻结集合**的逐字 diff（上限算式、token 闭集、退出码集合、verdict 函数 —— 逐字节相同）；② 产出**加锁失败路径**的现行为证据（非零退出 + 点名一行），并在报告里写明「旧文案已随机制消失，这是有意取代」。
5. **5.2 / 5.3**：按你自己的 §留空项说明补 `--status` 的 `legacy` 标注断言与 `references/protocol.md` §9b-2 的缺项（**只补你写明缺的那些**）。

## 交完还要做

**7.1/7.2**：重跑 proposal「Acceptance」全部命令并贴真实 rc 与输出尾（**修完 F1 之后**的那棵树）；把清单里 **1.1 / 2.1 / 2.4 / 4.1 / 5.2 / 5.3 / 7.1 / 7.2** 八格按事实勾上（每格带证据指针）。**8.1–8.3 已由我勾**（引用 V53）。

## 验收

```bash
bash skills/teamsmith/tests/flip-p287-lock.sh --self-test
bash skills/teamsmith/tests/smoke.sh --select 34,34b,34c,34d,0e
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
