# P438 · 模型配置变化不得停用关键回复捕获

agent: verify   status: BLOCKED   time: 2026-11-09T10:13:47Z
branch: `task/P438-reply-config-change`   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P438-verify.md` | 记录席位权限冲突；未修改实现或测试。 |

## Verification evidence (must have actually been run)

```
$ git status --short --branch
## task/P438-reply-config-change
```

- Verdict: not run。任务书要求修改 `team-reply.ts`、补反向改坏与真实 PM 探针，属于 apply 实现工作；`docs/team/OWNERSHIP.md` 明确规定 verify「只写报告与复验证据，不改实现」，且「无论任务书怎么写，都不改实现」。因此未运行实现后的验收命令，也不声称任何功能通过。
- Ledger ban:

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
docs/team/tasks/P438-reply-config-change.md:18: [names] <names#5> 在 06:54 仅修改 `TEAM_TASK_MODELS`。下一条回复时，`team-reply.ts` 的 `verify()` 对整个 identity 做深比较，因 configHash/configIno 变化写入 `degraded: identity/config changed`。该消息没有 intent/source，Pulse 无内容可显示。
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2533 hits=1 names=ok user=resolved
$ echo $?
1
```

唯一命中来自 PM 所有的只读任务书第 18 行，不是本报告新增内容；本席位不能修改该文件。

## Flip evidence (required for defect-fix tasks)

未运行；本席位未获实现权限，不能执行“修改实现 → 改坏 → 恢复”的验收流程。

## Decisions and deviations

- 未修改 `team-reply.ts`、测试或规格。任务书的 `agent: verify`、`phase: apply` 与 OWNERSHIP 的 verify 席位例外直接冲突，按硬阻塞交回 PM。

## Suggested next steps

- BLOCKED: 请 PM 将 P438 的 apply 实现改派给可写实现与测试的席位（如 dev），或由 PM 自行实现；verify 可在实现交付后承担独立复验。需要执行的范围仍是任务书中的真实 PM 探针、configHash/configIno 反向改坏、至少一项身份边界对照，以及指定选段和结构/账本/diff 检查。
- BLOCKED: 请 PM 清理任务书第 18 行的账本禁令命中；当前 `ledger-ban.sh` 实测 `hits=1`、`rc=1`，verify 无权修改该任务书。
