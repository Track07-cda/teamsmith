# P228 · 任务模型路由：S1 核心隔离实现

task: P228
agent: dev
phase: apply
category: analysis
change: task-model-routing
specs: dispatch, memory-and-deps, agent-adapters, pm-lifecycle, watchdog
deltas: dispatch, memory-and-deps, agent-adapters, pm-lifecycle, watchdog
branch: task/P228-task-model-routing-core
anchor: change
deps: E14; docs/team/reviews/task-model-routing-proposal.md ACCEPTED

## 当前返修输入（2026-10-09）

最新冻结候选 `a1a285df366b49c95fe65ddbad358221c62de921` 判 FAIL，未被接收。V19 第三轮完整报告 `ef8f952672a2d9f81a195b79ecd415d556f4dac9` 已收录；11条指定切片全rc0、1244/0及16臂94/0仍漏掉F4：continued模板中的provider/model/SID占位符可作为普通positional或放在label后，真实argv缺相应selector，工具仍成功发布原身份并标continued。PM另行固定输入复现11/8；verifier固定大包144/8、小纯positional包1/6分别保留，不混统计。旧F1/F2/F3绿不代表F4消失。先读主检出reviews/V19.md、收录的新报告、D114–D115及线程最新条目；自己worktree旧线程不是返修授权。原S1写集合再次仅返还你，S2/S3不接手；PM同强模型fresh交接，旧版resume和Pi历史重写都不用。

先按已接受的精确启动身份合同补足绑定判据：占位符出现、selector存在、值归属及最终argv一致不能相互替代。审查guard收集seen却只以refs止点判continued的缺口，并覆盖缺失、错槽、重复和合法绑定，不能只特判label。对PM共享guard等未实测路径先在私有fixture确认，不把猜测或未知CLI参数语义记成缺陷；不能扩成完整shell AST、Pi兼容矩阵或非Pi支持。保留诚实opaque/fresh磁盘交接和窄grammar的合法字面量/明确拒绝；按报告区分未加引号的身份占位符与普通quoted literal。补preview/real拒绝前后record/board/proof不变、合法actual argv对照、真实源码红→绿与恢复，以及能抓回这类绑定缺失的源码翻转；原验收和非模型断言不删、不skip。先完成并验证局部机制，再在稳定独立副本一次性跑交付清单，别每个小改都重跑长suite。

只修已接受模型/身份/读侧合同的缺口，维持原验收清单，增加可复现的源码红绿与合法控制。未授路径或规格语义变化仍先 BLOCKED 给 PM。修后冻结新 SHA，当前失败输入不能标已接收或 done。

## 授权与交付阶段

用户于 2026-10-09 批准启动隔离实现，见 D104。你不是 E13/E14 的探索或提案作者，只实施已接受 change 的 S1 核心切片。产品约束的唯一来源是 `openspec/changes/task-model-routing/`；本任务书是执行和目录授权，不另建规格。

当前控制面的 CLI 仍是旧版。PM 显式使用 `openai-codex/gpt-6.1-sol:high` 和 fresh 派单：核心事务、并发和 PM 启动身份属于复杂实现，使用强模型符合已批准的策略，不代表新路由已经生效。

交付止于私有源码和定向验证。不得把产品代码合入主检出、部署或改实际配置。S1 私有交付不等于整个 apply 完成，不把本任务设 done/close；PM 记录私有验收和冻结交接后，才安排 S2、S3，完整集成后换人复验。

## 阅读顺序与 workflow

1. `AGENTS.md`、自己线程最新条目、此任务书、`docs/team/OWNERSHIP.md`。
2. `docs/team/DECISIONS.md` D101–D115、`docs/team/reviews/task-model-routing-proposal.md` 当前接受意见。
3. change 的 proposal/design/tasks、全部七份 delta 和对应 canonical capability specs；重点执行 tasks 1.1–5.3，并按 coverage index 逐 scenario 映射证据。
4. 按 opsx-apply workflow 获取原生 apply instructions。生成文件若不存在，读取现有 OpenSpec 1.8.0 workflow/templates 与相关 store-selection 文档，不运行 init/update/install 生成它们。

先记录 `git status`、HEAD、分支和输入工件。使用现有 Bun/OpenSpec：

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change task-model-routing --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions apply --change task-model-routing --json
```

确认原生 CLI 的工件和写入根是自己的 worktree；误指向共享 store 时硬阻塞，不改全局选择设置。没有自动路由、推理桥接或 Pi 历史变换工作。

## 私有源码与稳定控制面的分离

自己的长期 worktree `.worktrees/dev` 是本切片写入树，保持 cwd 不变。机器全局两份 skill 仍引用 PM 主检出，不能改链接。PM 另准备仓外 `pm-skills-ledger/team/integration/task-model-routing/` 的非部署 clone，初始只保存基线；你不要写或集成该 clone。交付后由 PM 接收已检查的 tip，作为后续切片输入，不以 shared main 为依赖。

由 git common directory 得到主检出，记录到不含秘密的本地变量：

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
CONTROL="$CONTROL_ROOT/skills/teamsmith/scripts/team"
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/P228-dev"
mkdir -p "$EVIDENCE"
```

向 PM 通知只调用稳定控制面：`bash "$CONTROL" notify pm "P228 (task-model routing core): <结果或阻塞>"`。生成 prompt 的自收件示例是已记录的旧缺陷，不要照做或修它。**被测私有 CLI 不得对真实 worktree/主检出运行 config/dispatch/resume/up/watch/init/bootstrap/close/teardown；即使只想诊断，也先用已知只读 shell/git 元数据。** 测试必须在自己的独立 fixture repo/HOME/tmux socket 中显式断言 TEAM 根，不继承真实 TEAM 身份；不得读真实会话历史、凭据或触达现有 PM/pulse/其他项目。

## 临时目录授权与移交

依据 OWNERSHIP 的任务书明授条款，以下是你在本 worktree 的唯一产品写集合：

- `skills/teamsmith/scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death}.sh`。
- 补充窄授权（阻塞 tip `be7f76f1d563` 核查后）：`skills/teamsmith/scripts/lib/cmd-review.sh` 的 `team_cmd_close` 函数及仅该入口使用的必要新局部 helper，用于落实已接受 tasks 3.2 的锁、最终身份复核与完整 assignment 生命周期清理；保持既有 close/window/board/done 合同。不改此文件其余 review/gate/复验/合并相关路径，不增加真实团队操作。
- `skills/teamsmith/scripts/lib/cmd-bootstrap.sh` 的 writer 部分、`cmd-project.sh` 的 CLI/help 部分；不做新项目 init/bootstrap 教程或模板，留给 S3。
- `skills/teamsmith/scripts/lib/cmd-docs.sh` 的 task/category header 生成部分临时借予 S1，以执行 tasks 3.1；其余文档/初始化职责不变，交付后与共享文件一并冻结交给 S3。
- `skills/teamsmith/scripts/monitor.mjs`。
- `skills/teamsmith/tests/{config-cli,routes,smoke,death-cause}.sh` 和新 `task-model-routing.sh`；确实被这些夹具使用的 `skills/teamsmith/tests/lib/**` helper。不随意调整其他门禁。
- change 的 `tasks.md` 中仅 tasks 1.1–5.3 的真实完成勾选与证据索引；上述五份 delta 仅在必要且不改变已接受行为时修正，语义变更先交 PM。
- 自己的 `docs/team/reports/P228-dev.md` 和仓外 EVIDENCE。

S2 panel、S3 init-skill delta 不属于你；不改 panel/bundle/strings、SKILL/references/templates/README、canonical specs、OpenSpec root config、公共任务书/看板/评审/决策/ownership、任何真实 `.pi/` 配置。如 core 必须触及未授路径，记录具体调用链和 BLOCKED 给 PM，不能通过宽目录授权绕开边界。

冻结/释放记录必须逐路径说明：共享脚本（含新增借用的 cmd-review/close）及 config/routes/smoke/routing fixtures 哪些留给 UI 只读、哪些之后借给 S3。S1 返修已交出的文件必须先让 PM 收回权限；不能与下一 owner 同时写。

## 实施与验收指向

依 tasks 1.1–5.3 实施，不截断已接受的核心行为。spec/task coverage index 与 adversarial control index 是验收索引；每个本切片 scenario 在报告中列真实 assertion 名、日志路径、结果，没做的是缺项，不拿其他切片或 stub 成功替代。

新测试入口按 design 创建。以下命令在自己的 worktree 执行，fixture 先断言隔离：

```bash
df -h /tmp
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/death-cause.sh --pure
bash skills/teamsmith/tests/death-cause.sh --live
bash skills/teamsmith/tests/death-cause.sh --flip
bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary
bash skills/teamsmith/tests/task-model-routing.sh --select flip
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
```

命令加合理 timeout，日志放仓外；任何自己启动的长 gate 用 team_bg_run 并收割。原入口与非模型断言保留，新配置 fixture 适配不能变成 skip/删测试。S1 阶段模板/初始化/UI 尚未接手，按设计用手工新策略 fixture；对仍需 S2/S3 的跨切片失败具体归因，不声称 full green。局部复验选相关段，不每次跑全量。完整集成后的全量由 PM 安排一次，稳定树背景运行，结果收割后才做最终独立验收。

必须实际执行本切片所有受控破坏再恢复的反例，保留 rc、captured argv、policy/assignment/prompt/board hashes、nonce/proof/锁日志。只在 owned scratch source 中翻转，不在本 worktree 跑 gate 时修改树。没有 provider/模型质量测量、SDK 思维链测试、真实配置升级或实际 PM 重启。

## 报告与提交

每个可验证步骤 Conventional Commit，含 P228 和 `Agent: dev` trailer；产品提交不含 `[skip ci]`。不推送、不建 PR/MR、不合并、不 archive、不自行调度后续 agent。

报告记录输入/输出 commit、完整改动集合、命令及 rc/日志、逐 scenario 证据、反例红绿、未跑/skip/跨切片阻塞、冻结交接清单。报告类型是 **S1 私有源码交付**，不是 main 交付或上线成功。勾选只依据已完成、可复验的工作，不勾 S2/S3/V/采纳事项；任务板 done 权限不在你这里。

结束前提交报告，确认 branch 正确、树干净、所有后台作业收割，通知 pm。硬阻塞则写 PARTIAL 与证据后通知 pm，不中途问用户确认，不去做其他范围的修复。
