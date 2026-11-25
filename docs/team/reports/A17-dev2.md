# A17 · 同步已验收的初始化要求并收尾

agent: dev2   status: delivered   time: 2026-11-25T07:30:19Z
branch: `task/A17-archive-quick-init-model-defaults`   PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-25-quick-init-model-defaults/` | 用 OpenSpec 1.16.0 原生 `archive -y` 一次归档；五份规划工件与入档前 Git 对象逐字节相同 |
| `openspec/specs/init-skill/spec.md` | 仅同步 delta 点名的四个 MODIFIED requirement；其余 12 个 requirement、Purpose 和顺序不变 |
| `docs/team/reports/A17-dev2.md` | 本报告及实际命令回执 |

归档提交：`eac307309428`（`docs(init): archive quick init model defaults (A17)`）。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 5/5 | `tasks.md` 为 checked=5、unchecked=0；原生工具报告 `~ 4 modified`，归档后四个目标块与已接受 delta 一致 |
| Correctness | PASS（归档范围） | 五份工件均为 R100；正式规格其余 12 个 requirement 逐字节不变；普通 validate 21/21、spec-refs 122 条均 rc=0 |
| Coherence | PASS（归档范围） | requirement 集合与次序、Purpose 未变；没有边缘空行变化，也没有可执行文件、模板、运行状态或其他 change 的写入 |

## CRITICAL

- None。

## WARNING

- None。普通 `openspec validate --all` 仍打印既有长 requirement 警告；本单没有运行 strict，也不把这些警告写成新失败或 strict 已通过。

## SUGGESTION

- None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0。
- Readiness: 归档范围内可交付。产品行为与合并验收沿用任务书点名的 V198 已接受证据，本单不冒充重新验证产品行为。
- Unverified applicable checks and reasons: 按任务书明确不重跑首轮 100 项、行为测试、模型、安装、发布或全量 smoke；这些项目没有在本轮执行，不记为通过。

## Verification evidence (must have actually been run)

### 工具、分支与入档前状态

```
$ "$HOME/.bun/bin/openspec" --version
1.16.0

$ git branch --show-current
task/A17-archive-quick-init-model-defaults

$ git status --porcelain | wc -l
0

$ grep -c '^- \[x\]' openspec/changes/quick-init-model-defaults/tasks.md
5
$ grep -c '^- \[ \]' openspec/changes/quick-init-model-defaults/tasks.md
0

$ "$HOME/.bun/bin/openspec" validate quick-init-model-defaults --type change
Change 'quick-init-model-defaults' is valid
validate rc=0
```

### 唯一一次正式原生归档

```
$ "$HOME/.bun/bin/openspec" archive -y quick-init-model-defaults
Task status: ✓ Complete

Specs to update:
  init-skill: update
Applying changes to openspec/specs/init-skill/spec.md:
  ~ 4 modified
Totals: + 0, ~ 4, - 0, → 0
Specs updated successfully.
Change 'quick-init-model-defaults' archived as '2026-11-25-quick-init-model-defaults'.
archive rc=0
```

### 五份工件逐字节对照

入档前以 `git show HEAD:openspec/changes/quick-init-model-defaults/<file>` 读取 Git 对象，与归档文件执行 `cmp -s`；结果：

```
IDENTICAL .openspec.yaml
IDENTICAL proposal.md
IDENTICAL design.md
IDENTICAL tasks.md
IDENTICAL specs/init-skill/spec.md
```

入档前后 SHA-256 均为：

```
3c3c72cd1a100807c59ef8347538654b4d2d22269f59561c985b01cb44c39491  .openspec.yaml
be0dd34c5b496a77b9ada6310ae2f33fbae719d316a7dcb518d5a88758ebf9b6  proposal.md
dd8c60f80d1885461b045df45365d58ceafa6273aa1d8bd73a5b7021f2439d09  design.md
57dbea9eec0f2b2658a35196bd27c77a1a7a84b2b7d2f0bfa8305b5d0f379ec6  tasks.md
31fcda48d9ac7ef4173e0b3f8447ed8c81f5e7b811c3d86570fd0afc3810bacf  specs/init-skill/spec.md
```

暂存时 Git 同样判定五份工件为 `R100`：

```
$ git diff --cached --name-status
R100  openspec/changes/quick-init-model-defaults/.openspec.yaml  openspec/changes/archive/2026-11-25-quick-init-model-defaults/.openspec.yaml
R100  openspec/changes/quick-init-model-defaults/design.md  openspec/changes/archive/2026-11-25-quick-init-model-defaults/design.md
R100  openspec/changes/quick-init-model-defaults/proposal.md  openspec/changes/archive/2026-11-25-quick-init-model-defaults/proposal.md
R100  openspec/changes/quick-init-model-defaults/specs/init-skill/spec.md  openspec/changes/archive/2026-11-25-quick-init-model-defaults/specs/init-skill/spec.md
R100  openspec/changes/quick-init-model-defaults/tasks.md  openspec/changes/archive/2026-11-25-quick-init-model-defaults/tasks.md
M  openspec/specs/init-skill/spec.md
```

### 正式规格范围对照

用 Python 从 `HEAD` 读取入档前正式规格，按 `### Requirement:` 分块，与归档 delta 和入档后正式规格比较；目标块忽略的仅是块尾分隔换行，块内文字逐字比较，非目标块包括块尾逐字节比较。

```
DELTA MATCH Initialization guidance lives in a dedicated teamsmith-init skill
DELTA MATCH One CLI, one copy of every tool file
DELTA MATCH The new-project questionnaire checks Pi's version and its plugins, and asks nothing about adapters
DELTA MATCH Initialization teaches category policy and breaking upgrades without live adoption
RESULT targeted=4 untouched=12 order=unchanged purpose=unchanged
```

`git diff -- openspec/specs/init-skill/spec.md` 只含上述四个 requirement 的内容 hunk；没有新增或删除边缘空行，因此无需另列空白字节差异，也没有为凑结果改写文件。

### 归档后普通校验

```
$ "$HOME/.bun/bin/openspec" validate --all
✓ spec/init-skill
…
Totals: 21 passed, 0 failed (21 items)
openspec validate --all rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14556 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec-refs --check rc=0
```

### 差异与隐私检查

```
$ git diff --check
git diff --check rc=0

$ git diff --cached --check
git diff --cached --check rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2 scope=published files=3088 hits=0 names=ok user=resolved
$ echo $?
0
```

- Verdict: pass（以最终报告提交前的上述实跑回执为准）。
- Notes: 本报告只声明归档同步与列出的静态检查；未运行项目已在上方逐项说明。
- Ledger ban: 最终实跑结果见上方 `ledger-ban` 回执；运行位置为本人 worktree，覆盖本分支树中的新报告。

## Flip evidence

N/A — 本单是已验收变更的归档同步，不是缺陷修复。

## Decisions and deviations

- none。没有手工同步、目录移动、硬链接、跳过参数、试归档或第二次正式归档；没有清理任何临时根。

## Suggested next steps

- PM 接收本分支归档证据后按 local 模式复验并合并；五份原件及归档文件均保留，不推送、不发布。
