# P488 · 默认 PM 自行推进规则

agent: dev-bob   status: DELIVERED — 文字候选已冻结   time: 2026-11-23T10:14:18Z
branch: `task/P488-pm-autonomy-guidance-apply`   PR/MR: -

已落实批准的文字方案 `f3d8f015`。候选 `6e6e9754f0ea7fc5e81af3f9e34902bd3e5382fd` 只改三份提示文字，另勾任务 1.1、1.2。PM 不再为已授权的工作反复请示；用户只要方案时，不因目标和范围已谈妥就开始实施。生产操作、合并、推送和发布的授权要求不变。最终文字复核 2.1 待非作者完成。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | `b827ae4a`：在角色表和阅读顺序之间增加唯一完整规则。写明核实、拆分委派、小而可逆的选择、协调纠正、安排独立复核和收尾；需要用户裁定时，先做不受影响的工作，再给建议及其影响。 |
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | `6e6e9754`：启动提示指向 `AGENTS.md` 的角色章节；四步仅用于 Teamsmith 工具源升级。共享链接可在不安装的情况下读到改过的目标；共享和远端操作仍须明确授权。 |
| `skills/teamsmith/SKILL.md` | `6e6e9754`：日常流程指向同一规则，原独立复核、共享写入授权和决策记录仍保留；升级四步与启动提示一致。 |
| `openspec/changes/pm-autonomy-guidance/tasks.md` | 两次提交各只勾对应的 1.x 项；2.1 未勾。 |

## OpenSpec assessment

| Dimension | Result | Evidence |
|---|---|---|
| Completeness | 作者范围完成 | `openspec instructions apply` 显示 1.1、1.2 完成，2.1 未完成。 |
| Correctness | 作者已对照文字；待独立复核 | 两份升级说明逐项保留私有源验证、已验证源进入共享或受保护位置、项目配置写入及首次读取配置的新 PM 启动、采用变更后的共享技能或副本来源。每条命令均须先预览并取得授权，配置写入与首次启动分别授权。`--yes` 只表达已经取得的授权，不授予权限，也不适用于直接执行的 Git 或托管平台操作。 |
| Coherence | 写入范围已核对 | `032d0d2e..6e6e9754` 只含三份提示文字和两处勾选；生成、加载、当前项目 `AGENTS.md`、刷新说明、独立复核和收尾指引未改。`references/migration.md` §1b 仍说明已有项目须显式使用非 `--force` 的 `team init` 刷新，且刷新不只写 `AGENTS.md`。 |

## Verification evidence

```text
$ git diff --check 032d0d2e HEAD
candidate_diff_check_rc=0
$ git diff --name-status 032d0d2e HEAD
M	openspec/changes/pm-autonomy-guidance/tasks.md
M	skills/teamsmith/SKILL.md
M	skills/teamsmith/templates/AGENTS.section.md.tmpl
M	skills/teamsmith/templates/pm-prompt.md.tmpl
$ git diff --stat 032d0d2e HEAD
 4 files changed, 29 insertions(+), 14 deletions(-)
```

```text
$ export PATH="$HOME/.bun/bin:$PATH" OPENSPEC_TELEMETRY=0 TMPDIR=/var/tmp
$ openspec status --change pm-autonomy-guidance
Progress: 4/4 artifacts complete
status_rc=0
$ openspec instructions apply --change pm-autonomy-guidance --json
实施前：state=ready，complete=0，remaining=3，rc=0
实施后（从同一命令的 JSON 提取）：state=ready，complete=2，remaining=1
1.1=true；1.2=true；2.1=false
apply_instruction_rc=0
```

- Verdict：作者的写入范围、差异空白检查和 OpenSpec 进度查询已完成；不是独立复核通过。
- Ledger ban：未执行。任务书只准核对写入范围、`git diff --check` 和查询 OpenSpec 进度，不运行程序测试。
- 未执行模板渲染、初始化、现有项目刷新、会话启动或重启、模型运行、实际读取行为验证及任何测试。不推断运行中的 PM 已获得规则，也不推断模型会如何执行。未推送、未合并、未发布。

## Flip evidence

不适用。任务只改指导文字，未授权执行行为或故障对照。

## Decisions and deviations

无。产品候选为 `6e6e9754`；其后的本报告提交只增加交付证据。

## Suggested next steps

PM 固定候选，派非作者对照 OpenSpec 2.1 复核最终差异、授权边界和刷新说明；本席位交付后不再改动。
