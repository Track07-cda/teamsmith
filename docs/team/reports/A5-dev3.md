# A5 · 归档 delivery-final-wake-integrity

agent: dev3   status: DONE   time: 2026-11-12T04:18:01Z
branch: `task/A5-archive-final-wake`   PR/MR: -

归档已完成：原生 `openspec archive` 将变更移至 `openspec/changes/archive/2026-11-12-delivery-final-wake-integrity/`，并更新三份正式规格。归档提交为 `b5a3026c4fe6`；普通校验 20/20、引用检查、选段自检、账本禁令和差异检查均通过。严格校验及全量、夜间、61b 未跑，不作通过声明。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-12-delivery-final-wake-integrity/` | 六个原变更文件由原生归档命令移动，Git 均为 R100；tasks 1.1–4.2 全部保持已勾选 |
| `openspec/specs/background-jobs/spec.md` | 加入发起会话目录与执行目录分离的正式要求 |
| `openspec/specs/notify-and-inbox/spec.md` | 加入按最终交付修订分行并唤醒、独立检出任务归属的正式要求 |
| `openspec/specs/pm-lifecycle/spec.md` | 加入 PM 等待时核对磁盘记录的正式要求 |

实际共改变 9 个路径：6 个 R100 移档、3 个正式规格更新；未手改 delta、正式规格或 Purpose。

## OpenSpec assessment

本表只评估归档完整性，不替代 V156 的独立实现复验；V156 已对 merged SHA `3dd18692` 判 PASS。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | PASS | `team change status` 只余 A5 自身；tasks 1.1–4.2 全部 `[x]`；六个原文件均以 R100 进入归档目录 |
| Correctness | PASS（归档范围） | `/var/tmp` 私有副本先试归档并逐文件 `cmp`，随后在任务分支执行同一原生命令；普通 validate 20/20 |
| Coherence | PASS（归档范围） | 三份正式规格均由原生归档命令更新；未手写规格或 Purpose |

## CRITICAL

- None.

## WARNING

- `openspec validate --all --strict` 未运行。任务书明确既有长需求/Purpose 失败归 P408；本次普通 `openspec validate --all` 为 20 passed、0 failed，但不能据此声称 strict 通过。

## SUGGESTION

- None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0.
- Readiness: 归档交付完成，可由 PM 复验并合并；产品实现的独立结论沿用 V156 PASS，不由本报告重新自证。
- Unverified applicable checks and reasons: strict 因上述 P408 既有边界未跑；全量、夜间、61b 按任务书未跑。

## Verification evidence (must have actually been run)

前置状态（命令返回 1 是因为 A5 尚未交付；其它四项均 done，无其它 blocker）：

```
$ bash skills/teamsmith/scripts/team change status delivery-final-wake-integrity
change delivery-final-wake-integrity · not ready
  tasks
    A5      archive  dev3      wip     …
    P448    opsx-propose dev2      done    docs/team/P448.md: PASS
    P449    opsx-apply dev       done    docs/team/P449.md: PASS
    V155    verify   dev3      done    docs/team/V155.md: PASS
    V156    opsx-verify dev3      done    docs/team/V156.md: PASS
  blockers
    A5 · archive · wip · …
$ echo $?
1
```

私有副本预演；六个归档文件与原变更逐文件 `cmp` 全部一致，随后只删除本次私有目录：

```
$ git clone --no-local --single-branch --branch task/A5-archive-final-wake . /var/tmp/a5-archive-dryrun.jczVgU/repo
$ cd /var/tmp/a5-archive-dryrun.jczVgU/repo
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y delivery-final-wake-integrity
Task status: ✓ Complete
Totals: + 2, ~ 1, - 0, → 0
Specs updated successfully.
Change 'delivery-final-wake-integrity' archived as '2026-11-12-delivery-final-wake-integrity'.
$ git diff --check
$ echo $?
0
identical design.md
identical proposal.md
identical tasks.md
identical specs/background-jobs/spec.md
identical specs/notify-and-inbox/spec.md
identical specs/pm-lifecycle/spec.md
removed /var/tmp/a5-archive-dryrun.jczVgU
```

任务分支实际归档：

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y delivery-final-wake-integrity
Task status: ✓ Complete
Specs to update:
  background-jobs: update
  notify-and-inbox: update
  pm-lifecycle: update
Totals: + 2, ~ 1, - 0, → 0
Specs updated successfully.
Change 'delivery-final-wake-integrity' archived as '2026-11-12-delivery-final-wake-integrity'.
$ test ! -e openspec/changes/delivery-final-wake-integrity && echo active-change-absent
active-change-absent
```

验收命令：

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all
Totals: 20 passed, 0 failed (20 items)
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14159 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 分片是地板的精确划分（N=2 3 4 5 6 8 12：131 段，每片非空、无重复、无遗漏）
== 选段自检 ==  ok 13  bad 0  SKIP 1
$ echo $?
0

$ git diff --check
$ echo $?
0
```

- Verdict: PASS（任务书指定的非 strict 验收范围）。
- Notes: strict、全量、夜间、61b 未跑；未重新运行 V156 的 bg-ledger 215/0 与 smoke 765/0，它们是被接受的 merged-SHA 复验证据，不是本回合新读数。
- Ledger ban（报告写入后的本工作树实测）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=… scope=published files=2735 hits=0 names=ok user=resolved
$ echo $?
0
```

## Flip evidence

N/A — 本任务是归档，不是缺陷修复；实现的红绿证据见 P449/V156。

## Decisions and deviations

- 本机 `openspec` 不在 PATH，实际通过既有 `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec"` 1.16.0 执行同一 CLI；未安装依赖或修改环境。
- 归档目录日期由 CLI 生成为 `2026-11-12`。
- 无范围偏差；未合并、未推送。

## Suggested next steps

- PM 在独立检出复验本分支并本地合并；本分支保持本地，不开 PR/MR。
