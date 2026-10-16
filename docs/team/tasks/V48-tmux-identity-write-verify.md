# V48 · 共享 tmux 全局环境泄漏（写侧 apply-1）独立复验

task: V48
agent: verify
phase: verify
category: verify
change: tmux-identity-scope
specs: boundary, pm-lifecycle
deltas: -
branch: task/V48-tmux-identity-write-verify
deps: P274（apply-1 已交付，冻结 tip 见派单消息）

## 复验对象

写侧：`team_tmux` 包装（只对**可能启动 server** 的动词摘掉本项目 `TEAM_*`，其余保留）+ 会话作用域 `-e` 身份 + 既有 `shim/tmux`。被检树：PM 冻结的独立 clone。

## 必须自己做的（不许只复跑作者脚本）

1. **自己造泄漏现场**：起一个**私有的** tmux server（`-L` 独立 socket），先用**未修改的** main 树跑一次「从别的项目身份起一个会话」→ 观察它的**全局环境**里有没有本项目 `TEAM_*`（应当**有**，即泄漏存在）；再在**候选树**上同一命令 → 全局环境**必须零个**本项目 `TEAM_*`。两侧都要留原始 `tmux show-environment -g` 输出。
2. **本项目自己的窗口仍带身份**：候选树上，用项目身份起一个本项目会话 → 该会话/pane 环境里 `TEAM_MAIN_ROOT`/`TEAM_PROJECT`/`TEAM_SESSION` **必须在**（否则席位会失去身份、`@liveness` 与新创建的全局环境都不再显示身份——作者报告里点名的两处替代记录要一并核）。
3. **只摘该摘的**：`kill-*`/`list-*`/`show-*` 等**不会启动 server** 的动词，身份**必须保留**（闸门的归属判定绑在它上面）——你自己造一个「只读动词＋身份」的现场证明这一点；反过来，把「只对建对象动词摘」改成「全部摘掉」→ 必须红并点名。
4. **四条假阳性家族**（都要**不判**为泄漏）：别人的 pane 恰好带同名变量但值不同、`TEAM_*` 出现在**命令行参数**而不是环境、私有 socket 上的本项目窗口、以及「身份为空」的调用者。
5. **不改**：`signal-lint.pl` 只认 pid 精确形态、既有 `boundary#…` 断言、`@liveness` 语义；`doctor` 的只读残留行属于 apply-2，**不在本轮**（作者报告里写明未做，你要核这一条是否如实）。
6. 容器/资源纪律：先看 `/tmp` 余量；任何「既有红」同命令对照 **v0.2.0（tag）**；**给真进程调用加 `timeout` 兜底**（今天两个夹具因为缺它各挂了一个半小时——这条对你自己也适用）。

## 交付

`docs/team/reviews/V48.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc + 证据路径；你自己的两侧 `show-environment` 原始输出与红侧；写明运行模型）；证据包仓外；不改候选、不合并、不推送；结论通知 PM。
