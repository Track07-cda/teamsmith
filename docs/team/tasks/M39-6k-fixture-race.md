# M39 · 6k④ 夹具竞态：断言前有界等到窗口成型 + 失败信息带现场

```
task:   M39
agent:  verify
issue:  
change: -            # "-" if no requirement changes
specs:  -
phase:  -
deps:   M37          # 已合并；这是它 6k 段的 ④ 子夹具
status: todo
budget: 半个工作块；超出就交 PARTIAL 报告
```

> 本地模式：不 push，任务分支留在 `.worktrees/verify`。

## Context（PM 取证记录，可直接复用）

**现象**：`6k ④ 启动中的 harness（命令行里有 agent 路径但没有 agent 进程）判停（期望 [stopped]，实际 [alive]）`

- **M34 分支树**（= main + M34，含 M35/M37/M38）上**确定性红**：`team review M34` 一次 +
  直接跑 `bash skills/teamsmith/tests/smoke.sh` 一次，两次都是同一条红（2088 ✓ / 1 ✗）。
- **M37 分支树**上同段**绿**（2088 ✓ / 0 ✗）；**main** 上全量门禁也绿（同一份夹具代码）。
- **PM 的独立复现**：把 ④ 的夹具形状原样搬到一个私有 tmux server 里（`bash -c "sleep 600 && true  #
  派单 harness 形状：<stub> … dispatch-m37w.spawn"`）+ 用被测树的 `team_agent_alive_in_pane` 判：
  **两次都 stopped**（M37 树、M34 树都一样；连「建窗后立刻判」也 stopped）。
- **PM 在 M34 树上打的临时诊断**（已回滚）显示：断言报 alive 之后**同一条检查立刻重跑就变 stopped**，
  现场形状正确：
  ```
  [m34diag] verdict=stopped            ← 断言后重跑
  [m34diag] shape=pane_pid=4011052 cmd=bash
  [m34diag] tree: 4011052 bash -c sleep 600 && true  # 派单 harness 形状：…/fake-bin/m37-agent … dispatch-m37w.spawn
                  4011151 4011052 sleep 600
  [m34diag] is_agent_bin(pane)=no
  [m34diag] bin_path=/tmp/teamsmith-smoke.6Hht37/fake-bin/m37-agent
  ```
  → 断言执行的那一瞬判据拿到了「别的什么东西」，随后窗口成型就对了：**典型的「建窗后立刻断言」竞态**。

## 交付物

1. **判据侧的现场取证**：④（以及同段的 ①②③ 若同病）在断言前**有界轮询等夹具成型**——
   等的条件要具体（例如目标窗口的 `pane_pid` 可读且其命令行含本段的夹具标记），不是固定 sleep。
2. **失败信息必须自己带现场**：断言变红时打印 `pane_pid` / `pane 命令行` / `team_pane_agent_pid`
   命中的 pid 及其命令行 / `team_proc_is_agent_bin` 对该 pid 的判定 —— 一次红就能定位，不必再像 PM 这样
   打补丁重跑（PM 这次的补丁已回滚，别依赖它）。
3. **把这次的真实形状钉住**：在 M34 树（main + M34；PM 留了 checkout 线索：`git worktree add` 一份
   `task/M34-work` 即可）上复现「修前红 → 修后绿」；如果修后**在 M34 树上**仍然红，说明肇事者不是竞态，
   报告里给出新的机制分析（别硬把等待加上去当创可贴）。
4. 报告里写清：为什么 main/M37 树上绿而 M34 树上红（时序/前序段落的残留状态？），以及你的修法怎么
   消除这个差异。

## Boundaries

- 只动 6k 段与相邻夹具（smoke.sh）；不改 `team_agent_alive_in_pane` 的判据语义（M37 的判据本身是对的：
  隔离复现两次都 stopped）。
- tmux 纪律照旧（#1250）：测试自己用私有 socket；**跑门禁前先 `tmux ls | head -3` 记一笔**。

## Acceptance (must actually be run; put the output in the report)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
# 关键证据：在 task/M34-work 树上连跑 ≥3 次，6k 段 0 红；修前同树 ≥2 次红（已由 PM 提供）
```

## Report

`docs/team/reports/M39-verify.md`。
