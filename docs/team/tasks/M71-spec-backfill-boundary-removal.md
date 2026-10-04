# M71 · spec-backfill-2026-09 delta 修订：移除 boundary 三行（归 tmux-gate-grant-redesign）

```
task:   M71
agent:  dev-bob
issue:
change: spec-backfill-2026-09        # M70（verify）BLOCKED：boundary 1a/1b 写的是 M67 之前的模型
specs:  -
phase:  apply（delta 文本修订；不改实现）
anchor: change
deltas: boundary, verification, delivery-guard, board-and-status, panel
grant:  openspec/changes/spec-backfill-2026-09/**（只改这个 change 的文本）
deps:   M70（verify 报告 = 修订依据）· tmux-gate-grant-redesign（boundary 三条的归属）
status: todo
budget: 半个工作块
```

> 本地模式：不 push。**只改 `openspec/changes/spec-backfill-2026-09/` 里的文本，不改实现、不改别的 change。**

## PM 的裁定（照做，不要另起方案）

**把 boundary 的三条 requirement（1a/1b/1c）从本 change 的 delta 里整体移除**——这组规则已由
`tmux-gate-grant-redesign` 的 boundary delta（+3 requirement / 14 scenario）覆盖且更新：
- 它的 R1（按目标判定）覆盖 1a；它的 R2（动作日志 + 词汇表 + 窗口无授权）覆盖 1b；
  它的 R3（破坏性夹具绝不瞄准真实默认 socket）覆盖 1c。

理由与当年 item 6 一致：**同一组规则不写第二份**（两份 change 各写一份，归档时必然漂移——
M70 的 BLOCKED 就是预演）。

## 要改的（逐处核对，不留断链）

1. `specs/boundary/spec.md`：**整个文件移除**（本 change 不再有 boundary delta）；
2. `proposal.md`：六条规则改成五条，boundary 行注明"归 tmux-gate-grant-redesign（与 item 6 同一处理方式）"；
3. `design.md`：D1 的归属表删掉 boundary 行并加一行说明；**Evidence map 删掉 1a/1b/1c 三行**
   （保留 watch-degradation 的"已覆盖"行作参照）；D2 措辞不动（它讲的就是"已覆盖不再写"）；
4. `tasks.md`：删掉/改写 boundary 相关任务项，并在文件里加一行 PM 裁定说明（日期 + 原因 + 指向 M70 与本任务）；
5. 其余 7 行（verification / delivery-guard / board-and-status ×3 / panel ×2 MODIFIED）**一个字不动**；
6. 修订后：`openspec validate --all --strict` 必须绿（delta 结构变化后重新校验）。

## Deliverables

- 修订后的 change 目录 + 报告 `docs/team/reports/M71-dev-bob.md`（删了什么、为什么、validate 结果行）。
- 完成后 PM 让 M70（dev2）做针对性复核（它已验证的 8 行证据继续有效）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
git status --porcelain
```
