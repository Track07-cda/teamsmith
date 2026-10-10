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

## 当前返修输入（2026-10-10 · 第六轮：F6 + OBS1）

第五轮独立复验（V19，候选 `aaffe5a`）结论 **FAIL**，报告 `docs/team/reports/V19-dev3.md`（第五轮修订）与证据根 `pm-skills-ledger/team/reports/V19-dev3/round5-aaffe5a/` 已按原字节收录。复验同时确认 **F5 参数角色修复通过**：PM 冻结探针旧 1/20 rc=1 → 新 21/0 rc=0、你自己第四轮的 206 项矩阵 206/0、复验者自设计 58 项角色矩阵 58/0、18 臂破坏套件 111/0（新 `template-roles` 臂三条定点全中）、13 条切片全 rc=0、前后源树逐字节一致。这些继续成立，不许回退。

本轮只修两点，都在已接受合同的车道内：

### F6（真缺陷）：`analysis`/`verify` 被硬编码成必备类别

- 合同原文：`specs/memory-and-deps/spec.md`（Requirement: Project task-model policy replaces seat and worker-default routing）写 `Initial routine/analysis/verify are examples, not mandatory engine categories.`；`design.md` 写「项目没有 routine 等键并非非法，映射为空才非法」；dispatch delta 另写 `Initial examples routine/analysis/verify do not close the engine vocabulary.`
- 实现：`skills/teamsmith/scripts/lib/common.sh` 的 `team_task_map_violation` 末尾（候选树 1342–1344 行）对**每一份**映射强制 `analysis` 与 `verify` 出现；写者（`cmd-config.sh` 383/1168/1235）与读侧加载器（`common.sh` 1301/1364）共用它，无旁路。
- 实证（证据 `round5-aaffe5a/required-category-check.log`、`required-category-asymmetry.log`）：整映射写 `maintenance=vendor/light` 被拒；`upgrade-models` 到自定义词汇 `ops=… audit=…` 被拒；去掉 `routine` 接受、去掉 `analysis` 或 `verify` 被拒（不对称，钉的是这两个名字）；手写合法映射后 `config list --json` 判 `policy.categories=[]`。delta 场景「Category map has one domain rule」（示例映射 maintenance/routine/verify，无 analysis）按整映射 SET 也会被拒。
- 结果要求：唯一非法的映射是空映射（以及重复/畸形/不可表示等既有规则）；任意合法的项目自定义词汇整映射必须可写、可读、可升级、可派单；不含 analysis/verify 的映射合法；只含 analysis/verify 的映射仍合法。未在映射里的类别用于**新选择**仍按既有规则拒绝，删掉某类别后的同任务可信恢复仍按既有规则保持——这两条不许被本轮弄松。
- 测试：写侧整映射/升级、读侧 `config list --json`、`team init`/`upgrade-models` 种子、以及 dispatch 场景各加断言；至少覆盖「自定义词汇整映射接受」「去掉 analysis/verify 接受」「只含 analysis/verify 接受」「空映射拒绝」四类；**红侧**：在 scratch 副本恢复那段必备循环 → 新断言必须变红。
- 注意：套件现有夹具一律携带全词汇，所以这条合同此前从未被钉过——新增断言必须真的走「不含 analysis/verify」的路径，不能靠改夹具词汇蒙过。

### OBS1（真缺陷，同一诚实性车道）：部分绑定的模板发布了未交付的身份

- 事实（证据 `round5-aaffe5a/roles-v4/own-probes/*/obs1-*`）：模板只绑 `--model {model}` 时，实际 argv 是 `["--model","expected:high",<prompt>]`、离线 Pi 解析 `provider=null sessionId=null`，而派单**发布**了完整身份（`provider=vendor model=expected:high session=<铸出的 sid>`）。
- 合同依据：tasks 3.5 要求 `no falsely published identity`；dispatch delta 的记录字段是「实际启动身份」；agent-adapters delta 要求模板 `consume one resolved complete launch identity`。
- 结果要求（两条路线任选其一，但**发布的身份不得多于 argv 实际交付的**）：要么拒绝「绑了部分身份占位符」的模板（全绑或全不绑；后者即诚实 opaque，不发布任何身份宣称）；要么照实发布——只交付到的字段进记录，未交付的（含 teamsmith 铸出的 SID）不得当作已启动身份发布。诚实 opaque 的既有路径与既有合法控制都要在这条规则下有明确定论。
- 测试：obs1 形状（只绑 model）、全绑、全不绑三态各加断言，核对**发布记录 ⊆ 真实 argv**；**红侧**：在 scratch 副本把发布改回「一律写完整身份」→ 新断言必须变红。同任务恢复对未交付身份仍须诚实拒绝。

保留所有既有验收与断言，不删/skip 换绿；F1–F5 的修复与冻结探针结果不得回退。修后冻结新 SHA；本轮输入 `aaffe5a` 不能标已接收或 done。未授路径或规格语义变化仍先 BLOCKED 给 PM。

PM 实测（D120，2026-10-10 03:18–03:52 UTC）：provider 连接失败时 Pi 会**在同一会话内**回落到另一个模型（`openai-codex/gpt-6.1-sol:high` → `opencode-go/deepseek-v4.1-flash`），而席位 state 与 `team ps` 仍按派单时写入的模型展示与计数。这作为**读侧与并发计数**的验收证据（对应 1.2 的诚实 ps/roster/status 与 3.3/4.1 的模型计数与读证据）：读侧不得把非活跃模型当成本会话在跑的模型——能用 Pi 会话记录判定就判定，判不了就如实标不可判定，不能继续宣称；并发名额不得被一个并不存在的强模型会话占用。回落策略本身属 Pi 职责，Teamsmith 不实现兼容矩阵或跨 provider 质量判断。

这条实测只作为读侧与并发计数的验收证据（对应 1.2 的诚实 ps/roster/status 与 3.3/4.1 的模型计数与读证据）：读侧不得把非活跃模型当成本会话在跑的模型——能用 Pi 会话记录判定就判定，判不了就如实标不可判定，不能继续宣称；并发名额不得被一个并不存在的强模型会话占用。不要实现 Pi 的回落策略、模型兼容矩阵或跨 provider 质量判断，那是 Pi 的职责。

## 授权与交付阶段

用户于 2026-10-09 批准启动隔离实现，见 D104。你不是 E13/E14 的探索或提案作者，只实施已接受 change 的 S1 核心切片。产品约束的唯一来源是 `openspec/changes/task-model-routing/`；本任务书是执行和目录授权，不另建规格。

当前控制面的 CLI 仍是旧版。PM 按 D122 用项目默认快模型 `opencode-go/deepseek-v4.1-flash` 派单：有确定目标的实现类不用强模型；这不代表新路由已经生效。

交付止于私有源码和定向验证。不得把产品代码合入主检出、部署或改实际配置。S1 私有交付不等于整个 apply 完成，不把本任务设 done/close；PM 记录私有验收和冻结交接后，才安排 S2、S3，完整集成后换人复验。

## 阅读顺序与 workflow

1. `AGENTS.md`、自己线程最新条目、此任务书、`docs/team/OWNERSHIP.md`。
2. `docs/team/DECISIONS.md` D101–D119、`docs/team/reviews/task-model-routing-proposal.md` 当前接受意见。
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
