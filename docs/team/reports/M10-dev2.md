# M10 · Apply: drop-spec-lint（删掉自研 spec 检查器，规格管理归 OpenSpec）

agent: dev2   status: DONE   time: 2026-09-16T02:38:22Z
branch: `task/M10-apply-drop-spec-lint-validat`   PR/MR: -（本仓库 local 模式，分支留本地）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/spec-lint.sh` | 删除（-189 行） |
| `skills/teamsmith/tests/smoke.sh` | 移除 §16（spec lint 专节）及全部 `sl_*` 断言与夹具（-131 行）；`bash -n` 语法通过 |
| `.pi/team/config.sh` | `TEAM_GATES` 三件套 → 两件套（见下方前后对照） |
| `AGENTS.md`（团队块） | Gates 行三件套 → 两件套 |
| `docs/team/PROTOCOL.md` | Release checklist 的门禁串三件套 → 两件套 |
| `skills/teamsmith/references/openspec.md` | 引言改写成「OpenSpec owns spec management」+ 新增散文（写作约定仍在，但它是约定不是门禁）；phase 表 §1、评审记录模板 §4、八点清单第 5 条、§5 表 propose 行——四处删掉 spec-lint |
| `skills/teamsmith/references/workflows.md` | phase 表「both spec gates」→ `openspec validate --all --strict` green；命令块删掉 spec-lint 行 |
| `skills/teamsmith/references/migration.md` | 两处 `TEAM_GATES` 建议串删掉 spec-lint 段 |
| `openspec/changes/drop-spec-lint/tasks.md` | 勾选 1.1–1.4、2.1（2.2 随本报告提交） |

**任务书点名但本就无残留的（未改，附证据）**：

```
$ grep -rn "spec-lint" skills/teamsmith/SKILL.md skills/teamsmith/templates/ skills/teamsmith/scripts/
（无输出，rc=1）
```

- `SKILL.md` 的命令表/诊断行从未提 spec-lint（诊断行列的是 `team smoke`）；
- `scripts/lib/` 的 `{{GATES}}` 默认填充是 `team_detect_gates()`（cmd-project.sh:108），只探测
  pnpm/yarn/bun/npm 的 verify/test，从未含 spec-lint；
- `templates/config.sh.tmpl` 的 `TEAM_GATES="{{GATES}}" # gate command; …` 注释是通用措辞，无 spec-lint。

### 门禁字符串前后对照

```
- TEAM_GATES="openspec validate --all --strict && bash skills/teamsmith/tests/spec-lint.sh && bash skills/teamsmith/tests/smoke.sh"
+ TEAM_GATES="openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh"
```

## Verification evidence (must have actually been run)

```
$ openspec validate --all --strict        # openspec 1.8.0（<home>/.bun/bin/openspec，本机 PATH 不含它）
✓ spec/agent-adapters … ✓ change/drop-spec-lint … ✓ spec/watchdog
Totals: 11 passed, 0 failed (11 items)
validate rc=0

$ bash skills/teamsmith/tests/smoke.sh    # 完整套件（非 FAST）
== 结果 ==  ✓ 1357  ✗ 0
smoke 全绿
smoke rc=0

$ grep -rn "spec-lint" skills/ .pi/team/config.sh AGENTS.md docs/team/PROTOCOL.md
skills/teamsmith/CHANGELOG.md:176:- **M5.3 规格 lint**：`openspec validate --strict` 看不见"场景缺 THEN"这类问题，新增 `tests/spec-lint.sh`
（唯一残留是 CHANGELOG 的 M5.3 历史条目——验收规则明确允许「除 CHANGELOG/历史外无残留」）
```

- Verdict: **pass**（三条验收命令全部实际运行并贴出）
- Notes: 完整 smoke 在此机约数分钟；`openspec` 不在默认 PATH，用 `<home>/.bun/bin/openspec`（1.8.0）。

## Flip evidence（规格缺陷仍会被诚实拦下——PM 昨日实测的缺陷类，本次独立重跑）

夹具（scratch 副本，真树未动）：`cp -r openspec /tmp/m10-scratch/`，新建
`changes/broken-drop-scenario/specs/boundary/spec.md` —— 一条 MODIFIED delta，逐字重述
「Credentials are never read, echoed or committed」但**丢掉** base 的第二个场景
（"The scripts contain no credential reads"）。

**Red —— 门禁时间（validate 就拦下）：**

```
$ cd /tmp/m10-scratch && openspec validate --all --strict
✗ change/broken-drop-scenario
…
✗ [ERROR] boundary/spec.md: MODIFIED "Credentials are never read, echoed or committed" omits scenario(s)
  the current spec still has: "The scripts contain no credential reads". Copy them into the MODIFIED block …
Totals: 11 passed, 1 failed (12 items)
validate rc=1
```

**Red —— 试归档（OpenSpec 自己的机器也拦下，且不动文件）：**

```
$ cd /tmp/m10-scratch && openspec archive -y broken-drop-scenario
boundary MODIFIED failed for header "### Requirement: Credentials are never read, echoed or committed" - current spec
contains scenario(s) not present in the modified block: "The scripts contain no credential reads". …
Aborted. No files were changed.
archive rc=1
$ grep -c "The scripts contain no credential reads" openspec/specs/boundary/spec.md   → 1（base 未被改写）
$ ls openspec/changes/   → archive  broken-drop-scenario  drop-spec-lint（未被归档）
```

**Green —— 对照组（把场景放回 delta，两者转绿，证明红确实由丢场景引起）：**

```
（delta 末尾补回 "The scripts contain no credential reads" 场景）
$ openspec validate --all --strict   → Totals: 12 passed, 0 failed；rc=0
$ openspec archive -y broken-drop-scenario → archived as '2026-09-16-broken-drop-scenario'；rc=0
```

scratch 保留在 `/tmp/m10-scratch/`（一次性副本，可随时删）。

## Decisions and deviations

- **SKILL.md / scripts/lib / templates/config.sh.tmpl 未改**：任务书 1.2/1.3 防御性点名，实测三处均无
  spec-lint（证据见 Deliverables 下的 grep）。改了反而引入与事实不符的文字。
- **tasks.md 1.4 核对**：delta 的 MODIFIED 块与 base 需求做 diff，除「命名 spec-lint 的旧场景被换成实测
  真相的新场景」外逐字相同（diff 区域从需求块第 14 行才开始）。
- **CHANGELOG.md 未动**：任务书边界清单不含它；其 M5.3 历史行属验收允许的「历史」。
- **`openspec/specs/**` 未动**（边界要求）：base spec 的改写留给 PM 在 phase 5 归档时由 OpenSpec 自己做。

## Suggested next steps

- PM 复验后按流程走 verify → archive；归档会把 delta 的 MODIFIED 需求写进
  `openspec/specs/memory-and-deps/spec.md`。
- 本机注意：`openspec` 不在默认 PATH（在 `<home>/.bun/bin/`），`team review M10` 跑门禁时若报
  `openspec: command not found`，是环境 PATH 而非本变更引入。
