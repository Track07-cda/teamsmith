# delegate-openspec-archive · 提案审阅

当前判定：**ACCEPTED — 允许派 Apply，尚未实施**

最终规划 `a5c82971`、报告 `669d6987`。V142（非作者 dev3）ACCEPT：归档 brief 字面 `phase: archive` 与 PM 接受记录两处均和工具语义一致，结构校验与账本禁令独立通过。此前 V138/V139 的各项均关闭。

实施边界：verify/archive 及门禁由非实现者执行；PM 只做审阅、接受和合并。同一 verifier 做合并后验证；保留限定 PM-proxy；依赖归档串行；Purpose 在 native archive 后单独明确提交。

历史审阅：V138 非作者审阅报告：`docs/team/reports/V138-dev.md`。方向接受，以下一次性返修，不重开“verify/archive 委派”这一用户裁定。

## PM 对五项阻断的裁定

1. **verify 的执行与记录归属**：PM 可以准备 detached checkout，但不跑门禁。verifier 执行 `team review`；该工具写主检出的一条指定 review 记录作为集中账本例外，必须在 OWNERSHIP 明确。`cmd-review.sh` 的“PM 独立复验/PM 提供/PM 结论”要改成真实执行者身份，纳入 Impact 与测试；不得名义委派、记录却写 PM。
2. **合并后的门禁**：同一 verifier 在 PM 合并后续跑，对合并后的 revision 做 post-merge verify；通过后才 done/进入 archive。把 `openspec.md` 两处和 `workflows.md` 一处 merged-tree 旧句逐条纳入清单。当前已授权两个 change 不追溯补跑。
3. **相反口径清单**：补入 V138 点名的 memory-seed、troubleshooting、README、teamsmith-init、§E2、命令表及基规格 Purpose，逐行决定改/保留。Purpose 不由 native archive 静默改写：同步保持既有 Purpose，随后用单独、明确的文档提交更新，并给前后差异，遵守 archive 的 Purpose 保护。
4. **PM-proxy**：**保留现有限定规则**。用户只裁定 verify/archive 不由 PM 执行，没有撤销“小步、可逆、已批准方案覆盖时 PM 可代理确认并记录理由”。删除 proxy 属扩权，不得加入 delta；archive worker 仍检查确认人与理由。
5. **CRITICAL/WARNING**：直接沿用 openspec-verify-change 的定义和固定报告分节，不另造分类。报告模板增加 `CRITICAL / WARNING / SUGGESTION / Final assessment` 位置；CRITICAL 未清零不得归档，WARNING 与未验证项在确认前披露。

## 两项联动

- `team change status`：archive 自己仅以 blockers 中 `phase=archive` 且 ID 等于本任务书 ID 的一行为自身项；其余任何 blocker 仍阻断。文档不得要求 archive 前该命令必须 exit 0。
- trial archive 示例改用磁盘临时根，不用 `/tmp`；当前项目约定为 `/var/tmp` 的本次专属目录。

## 边界

只修 proposal/design/tasks/delta 和 P435 报告；不实施、不跑真实归档。返修后交 V138 原审阅者定点复核。当前两个变更的用户授权 verify/archive 不受本提案阻塞。
