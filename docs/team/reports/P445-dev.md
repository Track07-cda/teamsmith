# P445 · 修复 teamsmith-init 行数与 remind-recover 帮助声明

agent: dev   status: DONE   time: 2026-11-10T19:26Z
branch: `task/P445-inherited-help-red`   PR/MR: -（local 模式，提交留在任务分支）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith-init/SKILL.md` | 只合并开头同一段的两处物理换行，101 → 100 行；模型、初始化、门禁和交付义务原文保留 |
| `skills/teamsmith/tests/help-surface.sh` | 内部入口声明补入 dispatcher 已有的 `__remind-recover`；删除声明的红侧变异同步到完整新声明；Reminder 行为未改 |

真实命令与声明对照：

```
scripts/team:134:  __remind-recover)   team_remind_recovery "$@" ;;
tests/help-surface.sh:762:  local internal="__inbox-write __notify-settle __panel-data __remind-recover"
```

## OpenSpec assessment

N/A — `change: -`；本任务不改规格，以既有 `help-surface` / `init-skill` 要求作为验收锚点。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | N/A | 两处指定修复均已落地，无新增规格义务 |
| Correctness | N/A | §39、§51 从各一红转为选段 ✓28 ✗0；两处反向改坏均被原判据抓住 |
| Coherence | N/A | 提交内容的独立导出 `openspec validate --all` 为 20 passed / 0 failed |

## CRITICAL

None.

## WARNING

- 工作树里有一个本任务未创建、Git 不跟踪的空目录 `openspec/changes/panel-symlink-inside-project/`。直接在原工作树运行 `openspec validate --all` 因此报 `Change must have at least one delta`；本任务未删除这个范围外目录。对 `HEAD` 的独立导出运行同一命令为 20 passed / 0 failed，PM 的干净独立检出不会带这个空目录。

## SUGGESTION

None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0.
- Readiness: 两处指定缺陷已修复，可交非作者独立复验；结论只覆盖本报告列出的选段和检查。
- Unverified applicable checks and reasons: 按任务书未跑全量、夜间与 61b；§39/§51 输出列出的其余 135 个键未跑。原工作树的直接 OpenSpec 命令受上述空目录影响而失败，未把它记为通过；提交内容的独立导出已通过。

## Verification evidence (must have actually been run)

修复前，基线 `0f72bd48`：

```
$ bash skills/teamsmith/tests/smoke.sh --select 39,51 </dev/null
✗ 39 install-shape.sh 有失败
  ✗ teamsmith-init/SKILL.md 超行数（101）
✗ 51 帮助面夹具有失败（rc=1）
  ✗ 内部入口清单：dispatcher 的 __ 标签 __remind-recover 不在声明清单里
== 选段结果 ==  ✓ 26  ✗ 2
```

修复后，最终产品提交 `13425feb`：

```
$ bash skills/teamsmith/tests/smoke.sh --select 39,51 </dev/null
✓ 39 install-shape.sh 全绿（204 条断言，含翻转绿/红两侧）
✓ 51 routes.sh 产品面全绿（255 条断言，1 条可见跳过）
✓ 51 帮助面夹具（help-surface.sh）全绿（132 条断言）
✓ 51 名册/契约夹具（list+validate+roster）全绿（137 条断言）
账本自查：6 段收口 · 增量 ✓28 ✗0 SKIP0 ｜ 结果行 ✓28 ✗0 —— 一致
== 选段结果 ==  ✓ 28  ✗ 0
```

相关定点检查：

```
$ wc -l skills/teamsmith-init/SKILL.md
100 skills/teamsmith-init/SKILL.md
$ bash skills/teamsmith/tests/install-shape.sh surfaces
✓ teamsmith-init/SKILL.md 仍是 100 行（≤ 100）
== 结果 ==  ✓ 11  ✗ 0  SKIP 0

$ bash skills/teamsmith/tests/help-surface.sh --select coverage
✓ 内部入口清单与 dispatcher 的 __ 标签双向相等（4 个）
== 结果 ==  ✓ 15  ✗ 0  SKIP 0
```

其余验收命令：

```
$ ~/.bun/bin/openspec validate --all                   # 在 HEAD 的独立导出目录
✓ spec/help-surface
✓ spec/init-skill
Totals: 20 passed, 0 failed (20 items)

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14088 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 13  bad 0  SKIP 1

$ git diff --check
（无输出）
```

- Verdict: 两处修复及指定选段 pass；原工作树 OpenSpec 的环境性失败见 WARNING。
- Notes: 未跑全量、夜间、61b；未修改 Reminder 实现。
- Ledger ban (fixed acceptance line — run it in your own worktree, on your branch's tree):

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  ledger-ban: root=… scope=published files=2651 hits=0 names=ok user=resolved
  $ echo $?
  0
  ```

## Flip evidence (required for defect-fix tasks)

行数：在 `8cde76f0` 的独立导出副本末尾恢复一个空行，文件回到 101 行；原工作树未改。

```
$ TEAM_INSTALL_TREE=/var/tmp/p445-init-lines.rshWjp/tree bash skills/teamsmith/tests/install-shape.sh surfaces
✗ teamsmith-init/SKILL.md 超行数（101）
== 结果 ==  ✓ 10  ✗ 1  SKIP 0
$ echo $?
1
```

声明：使用既有 `internal-list-short` 变异，在私有副本中从声明删除 `__inbox-write`；正向对照与红侧均实际运行。

```
$ TEAM_HELP_SURFACE_FLIP_ONLY=internal-list-short bash skills/teamsmith/tests/help-surface.sh --flip --select coverage
✓ 内部入口清单与 dispatcher 的 __ 标签双向相等（4 个）
✓ 翻转 ⑪声明清单里删一个内部名： ✗ 内部入口清单：dispatcher 的 __ 标签 __inbox-write 不在声明清单里
== 结果 ==  ✓ 16  ✗ 0  SKIP 0
```

§39/§51 的完整夹具也分别在最终产品提交上通过了自身全部翻转（§39 明示含翻转两侧；§51 帮助面 132 条断言全绿）。

## Decisions and deviations

- 只合并 `SKILL.md` 开头段的物理行，没有删改任何义务或行为文本。
- 原工作树直接 `openspec validate --all` 为 20 passed / 1 failed，失败只指向范围外的空目录；另在 `13425feb` 的独立导出运行得到 20 passed / 0 failed。两种结果都保留，没有把环境性失败写成产品通过。

## Suggested next steps

- 由非作者在干净独立检出复验并合并；本分支不推送、不合并、不发布。
