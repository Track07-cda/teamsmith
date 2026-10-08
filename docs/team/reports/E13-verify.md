# E13 · 任务类别模型路由技术探索

- Agent: verify
- Phase: opsx-explore；基线提交：`7479376`；分支：`task/E13-task-model-routing-explore`
- 范围：D101 已确认方向内的只读探索；只写本报告，不创建 change、不实现、不升级配置、不推送。
- 结论：可以进入单独的 propose 阶段。路由改动必须同时处理配置全链路和任务启动记录，不能只替换 dispatch 的默认模型函数。
- 证据：外部 `pm-skills-ledger/team/reports/E13-verify/`。下文的建议和验收设计均非已实现行为，也不代替未来 OpenSpec delta。

## 1. 已观察到的现状

### 隔离复现

复跑入口（从本任务工作树执行；证据目录按 git common dir 定位，不按 worktree 的父目录猜测）：

```bash
MAIN="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
EVIDENCE="$(dirname "$MAIN")/pm-skills-ledger/team/reports/E13-verify"
python3 "$EVIDENCE/probe.py" "$PWD" > "$EVIDENCE/probe-run.log" 2>&1
```

最终运行退出 0。每个 CLI 调用由 Python `subprocess.run(timeout=20, stdin=DEVNULL)` 限时；记录 agent 调用另限 3 秒。夹具有独立 git 仓、自己的 worktree/config/state/HOME/TMPDIR，PATH 第一项是 recording tmux。桩没有透传真实 tmux 的分支，非 `e13-fixture` 对象目标直接拒绝。它记录产品交给 `respawn-pane` 的 argv，提取生成的 agent 命令，调用只记录 argv 的 agent，模拟 nonce 启动/退出证据。**不是运行真实 tmux、登录 shell、Pi 或 provider 的启动验证**；证明范围是现有 CLI 的解析、恢复、实际渲染参数及其状态写入。

夹具配置：`TEAM_DEFAULT_MODEL=vendor/default`、`TEAM_AGENT_MODELS=dev=vendor/seat`，无模型并发限制；任务 `T1` 的 branch/anchor/phase 合法。下表命令都在同一夹具上顺序执行，任务书是 `docs/team/tasks/T1-routing.md`。

| 文件与命令（省略固定 `team --root "$FX"` 前缀） | 捕获的实际 agent 参数 | 写入的 model / source / SID | rc |
|---|---|---|---|
| `01-normal.log`：`dispatch dev T1 docs/team/tasks/T1-routing.md` | `--provider vendor --model seat --session-id e13-fixture-dev` | `vendor/seat / config / e13-fixture-dev` | 0 |
| `02-override.log`：同上加 `--model vendor/override:high` | `--provider vendor --model override:high --session-id e13-fixture-dev` | `vendor/override:high / explicit / e13-fixture-dev` | 0 |
| `03-override-resume.log`：`resume --agent dev` | `--provider vendor --model seat --session-id e13-fixture-dev` | `vendor/seat / config / e13-fixture-dev` | 0 |
| `04-fresh.log`：原 dispatch 加 `--fresh` | `--provider vendor --model seat --session-id e13-fixture-dev-1791444015` | `vendor/seat / config / e13-fixture-dev-1791444015` | 0 |
| `05-fresh-resume.log`：`resume --agent dev` | `--provider vendor --model seat --session-id e13-fixture-dev` | `vendor/seat / config / e13-fixture-dev` | 0 |
| `06-config-write.log`：`config set-agent-model dev vendor/changed --yes` | 无启动 | 当前任务记录仍为 `vendor/seat / config / e13-fixture-dev` | 0 |
| `07-config-change-resume.log`：`resume --agent dev` | `--provider vendor --model changed --session-id e13-fixture-dev` | `vendor/changed / config / e13-fixture-dev` | 0 |
| `08-switch-without-fresh.log`：原 dispatch 加 `--model other/new` | `--provider other --model new --session-id e13-fixture-dev` | `other/new / explicit / e13-fixture-dev` | 0 |
| `09-preview.log`：原 dispatch 加 `--model vendor/preview --print` | 打印 `--provider vendor --model preview --session-id e13-fixture-dev`，无 agent 调用 | 任务记录仍为 `other/new / explicit / e13-fixture-dev` | 0 |

完整 argv 在 `fixture/agent-argv.jsonl`，渲染命令与 nonce 在 `fixture/rendered-agent.jsonl`，tmux 请求在 `fixture/tmux-argv.jsonl`；`summary.json` 和 `commands.log` 提供逐例摘要。SID 时间戳是本轮实测值，复跑不要求同一数字。

复验输出摘录（已去掉机器路径）：

```text
03: 续跑 dev · T1
✓ dispatched T1 → e13-fixture:dev（…provider=vendor model=seat session=e13-fixture-dev）
05: 续跑 dev · T1
✓ dispatched T1 → e13-fixture:dev（…provider=vendor model=seat session=e13-fixture-dev）
OBSERVED override dropped; fresh SID dropped; config re-resolved; switch without fresh allowed.
All launches are recording stubs.
```

两项恢复缺陷均已复现：显式覆写被重新按配置解析；fresh SID 被重建为基础 SID。另观察到配置修改会改变已派任务的续跑模型，直接换 provider/model 也不要求新会话。后两项是当前行为与 D101 新方向的差异，不冒充已有规格下的回归。

探针准备曾有两次无效尝试：`python` 不在 PATH（127）；初版桩没识别带 shim export 前缀的 agent 行，未产生 agent argv（1）。改用 `python3` 并修正**外部探针**解析后完整重跑；无效尝试不计产品证据。

### 源码解释与尚未实测的路径

- `scripts/lib/cmd-agents.sh:1166–1173`：`--model > team_agent_model(agent)`，SID 总是重新建成 `TEAM_SESSION-agent`，fresh 仅追加秒级时间戳。`common.sh:1288–1299` 解析席位 token，再回退 worker default。
- `cmd-agents.sh:1352–1363` 已记录 model、model_src、task、taskfile、branch、sid、sid_bytes。缺陷不是没有 SID 记录，而是恢复不使用它。
- `cmd-watch.sh:239–279` 的 `resume` 只传 agent/task/taskfile 到 dispatch。`up --agents` 也调用该 resume。**up 救援路径仅经源码核查，未执行**。
- 巡检本身不恢复 worker：`cmd-watch.sh` 开头注释、`team_cmd_watch` 与 watchdog capability 的 `The pulse never manages tmux layout, agents or quota` 一致。有 stopped worker 只唤醒 PM；PM 再选择 resume。**没有观察到 patrol 自动换 worker 模型，不应把它列成第三个已复现恢复缺陷**。
- PM 的 `common.sh:2097` 仍用 `TEAM_PM_MODEL > TEAM_DEFAULT_MODEL`；`team_pm_pi_args` 默认 `-c`，`team_pm_launch_cmd` 和 adapter 展开共用模型解析。PM 当前是否以人工参数选了另一模型不在此探索的实测范围；没有读真实会话历史。
- **roster/ps 的 SID 读侧不一致（PM 观察 + 本轮源码/metadata 核查）**：PM 在本次实际 fresh 派单后观察到 roster 仍报旧会话过大的数字。主仓 Teamsmith `state/verify.env` 的记录为 `sid=teamsmith-verify-1791443600`、`sid_bytes=0`；外部 `team/reviews/E13/dispatch-preview.log` 的 argv 和 `dispatch-receipt.txt` 都指向该 fresh SID。`common.sh:2747–2754 team_agent_session_cols` 却使用 `sid="$TEAM_SESSION-$a"`，即查基础 `teamsmith-verify`，没有读取记录 sid；`cmd-status.sh:416` 的 roster 与 ps 的会话区块都消费该 helper。因此启动与展示不是同一个身份源。**旧会话过大是 PM 的现场观察，不是我独立重跑 roster 的结果；fresh SID/派单时字节快照与 hardcoded 读侧已亲自核查。**没有打开任何 Pi session/history 文件。
- `cmd-death.sh:146–163` 按基础 SID 与 fresh 前缀选最新文件；`monitor.mjs:504–513` 按目录最新会话选活动源。这两项仍是恢复身份改变后的关联风险，**source-only**，不能沿用 roster 的现场观察冒充独立实测。
- `common.sh:3344–3357` 的并发计数遍历 worker roster，不含 PM，且判断窗口存在，不检查 agent 仍在执行。带旧记录的停止窗口可能计入配额，尤其需要覆盖“同任务恢复替换自己”的边界。此项 **source-only**；不能把现有限额宣传成 PM/worker 共用的总订阅限额。建议保留 limit 配置/精确与 wildcard 规则，在 propose 中明确停止窗口与替换自身的计数，不顺手扩成 PM 配额系统。
- `dispatch --print` 不开窗、不写任务模型记录，但 `cmd-agents.sh:1220–1223` 仍先写 prompt 文件。不能把当前 preview 描述成整个 state 零写入。

以上脚本短路径均相对 `skills/teamsmith/`；源码清单另在外部 `source-inventory.txt`。SID 读侧补充核查见 `sid-reader-source-check.txt`（仅 Teamsmith 元数据和源码摘要）。`sid_bytes=0` 是派单时快照，不说明当前运行会话仍然零字节；修复显示应按记录 SID 查当前文件并 stat，不能把快照常量当实时大小。fresh 不能通过删除旧历史让错误读侧“看起来恢复正常”。

## 2. 可供提案采用的最小方案

### 类别、配置与初始映射

建议三个类别，不引入 classifier，也不把席位名或 OpenSpec phase 当模型身份：

| category | PM 选用指引 | 首轮模型 |
|---|---|---|
| `routine` | 轻任务、边界清楚的一般实现/测试/文档 | `opencode-go/deepseek-v4.1-flash` |
| `analysis` | 复杂分析、方案探索、提案、重要架构判断 | `openai-codex/gpt-6.1-sol:high` |
| `verify` | 独立复验、对抗性检查 | `openai-codex/gpt-6.1-sol:high` |

两种模型足够起步；`analysis` 与 `verify` 分开是为了让独立复验用途明确，不是两种强模型质量的断言。模型名来自本仓已配置的 worker default 与 verify 覆写；未添加 provider、订阅或模型。现有快模型不等于已证明足够好，后续按返工次数和总交付时间判断；强模型并发受现有 `openai-codex/*=1` 约束，排队不自动降级。

建议继续以项目 `.pi/team/config.sh` 为唯一策略来源：

```bash
TEAM_TASK_MODELS='routine=opencode-go/deepseek-v4.1-flash analysis=openai-codex/gpt-6.1-sol:high verify=openai-codex/gpt-6.1-sol:high'
TEAM_PM_MODEL='openai-codex/gpt-6.1-sol:high'
# TEAM_MODEL_LIMITS / TEAM_MODEL_WINDOWS 继续独立存在，语义不变。
```

`TEAM_TASK_MODELS` 建议是单行完整映射，schema 专门校验闭集类别、唯一 token 和非空合法模型。`TEAM_PM_MODEL` 变为必填独立模型，不回退 worker 映射。删除 worker `TEAM_DEFAULT_MODEL`、`TEAM_AGENT_MODELS` 的解析/写入与 `set-agent-model`、`add-agent --model` 席位赋值语义；不留 routing-mode 开关或静默兜底。

推荐 brief 用唯一的 `category:` 声明；新 dispatch 必填。不同时增加一个 `--category` 第二来源，避免配置、任务书和 CLI 三处竞争。`phase:` 仍是流程责任边界；`verify` phase 与 `verify` category 的一致性可以确定性校验，其他 phase 的复杂度由 PM 判断，工具不读自然语言判断任务难度。

配置编辑前门建议为 `team config set-task-model <category> <provider/model>`，内部更新整个映射并复用 canonical writer 的 quoting/CAS/audit/dry-run。PM 使用 `team config set TEAM_PM_MODEL …`。类别不能用 `-` 删除后落到某个 default。设置页呈现「任务类别模型」和独立「PM 模型」，不再提供 worker 席位覆盖。

### 指引与工具各做什么

- PM 指引负责把复杂度和任务目的翻译成类别；普通实现默认推荐 routine，不因使用强模型较方便而全部升级。brief 保持自包含；记录选择理由与后续返工，不能用全绿门禁代替效果证据。
- 工具只检查类别、映射、模型参数形状、元数据身份、并发、窗口大小和已有所有派单守卫。保留显式 `--model`，来源记为 explicit；它不能绕过必填类别、并发或换模型新会话限制。不通过模型名猜强弱，不创建 compatibility matrix。
- 建议成功派单后一次性写启动记录：task、brief、category、选定完整 model（含 thinking suffix）、selection source、SID、branch、worktree、launch nonce/时间。已派任务在 `resume`、同任务 re-dispatch 和 `up --agents` 中复用**同一 model/SID**；修改映射仅影响下一项新任务。
- 显式接管换模型需要 `--fresh`；不带 fresh 在任何写 prompt/state/board 或开窗前拒绝，即使 `--force` 或 `--allow-overflow` 也不能绕过。相同模型的 fresh 可用于清理过长会话，但它生成的新 SID 必须成为后续恢复身份。
- 新任务默认新 SID，避免同席位跨任务/类别继承旧会话；建议不用秒级时间戳单独充当唯一性，采用已有 nonce 风格。旧 SID/已完成任务原文不删除。
- 新会话交接使用目标、代码/分支状态、报告/证据位置、未决事项等磁盘材料。提示词明确是恢复还是 fresh 接管，以及 category/model/source/SID；不读、转换或搬运隐藏思考或 Pi 消息。
- PM 建议记录 Teamsmith 自己启动时的模型身份；重建发现模型改变时要求 `up --fresh-pm`。旧记录或人工启动无法证明模型身份时，明确要求人工 fresh 接管，不读 Pi 历史来猜。巡检只能报告此阻塞，不能自动换模型继续 `-c`。这部分需要在提案中收紧既有 PM/adapter 启动情景，不能另写一套 PM 启动器。
- 展示把「已派任务实际选定模型」与「下一新任务的配置映射」分开。resume 的 source 可以是 `assignment`，并另保留原始 `selected_via=config|explicit`；不继续用“历史记录，下次 spawn 用新配置”解释同任务恢复。

## 3. 影响地图：复用、修改与删除现有契约

不存在独立 `capacity` capability；容量合同在 `dispatch`。巡检额外读了 `watchdog`，因为 brief 指定的六个 capability 没覆盖 patrol 边界。下面是 delta 定位建议，不是新增要求清单。

| capability 与既有 Requirement 标题 | delta 建议与原因 | 产品路径、现有检查/夹具 |
|---|---|---|
| dispatch — `A brief is self-contained and names its evidence` | MODIFIED：新任务 category 和 fresh 交接证据纳入头部/提示；新增任务选择与恢复情景放同 capability，避免重复 brief 约束 | `cmd-agents.sh` 的 prompt/dispatch、`cmd-docs.sh`、`templates/task.md.tmpl`；smoke 6/54、spec-refs |
| dispatch — `Model concurrency limits are enforced before dispatch`、`A dispatch refuses a session the model's window cannot hold` | MODIFIED：输入改为实际 assignment/model/SID；limit 数值、通配及 overflow 语义保留 | `common.sh` 的 `team_model_limit/running/guard`、`team_agent_session_cols`；`cmd-agents.sh` session guard；`cmd-status.sh` roster/ps；smoke 6c/6h/29。6h A5 只断言 fresh 命令通过与 SID 形状，A9 只断言基础大会话的 roster/ps 数字，缺少 fresh 成功后展示对应新 SID 的交叉检查 |
| dispatch — `The roster changes only through an explicitly authorized registration` | MODIFIED：去掉席位模型 `--model`/`-` 情景，保留 register、create、审计、失败事务性 | `team_cmd_add_agent/team_worktree_add`；`cmd-agents.sh:26,55` 甚至 add-agent 幂等路径也会写 model/model_src；`config-cli.sh roster`、routes、smoke 51 |
| dispatch — `A dispatch proves the agent started, or fails loudly`、`A refused dispatch hands over every blocker, once, with a fix that runs` | MODIFIED：新选择/身份阻塞纳入同一 preflight；成功元数据完整原子发布，失败不留下半个 assignment；保留 nonce proof、启动重试与现场 | `cmd-agents.sh:1071–1390`、dispatch judgment helpers；smoke 6h/54、routes；启动重试仍是同模型重试，不是跨模型 fallback |
| memory-and-deps — `A seat's model is read and written as a seat, never by composing the pair list in the caller` | REMOVED：整个合同依赖 default/seats/override/移除覆写，不应挂新“类别”要求却留下旧合同 | `cmd-config.sh` schema、model/pairlist validator、seat read、known/choices、set-agent-model；config-cli 的 models/seats/json/shape、panel-choices、panel-p21 |
| memory-and-deps — `The project contract has exactly one writer, and it preserves what it does not change`、`A write is accepted only against the file the writer read`、`Every attempt is audited in one line` | MODIFIED：类别写入口与原子升级事务仍走唯一 writer；不绕过 CAS/语法/注释保留/审计 | `cmd-bootstrap.sh:24` 的底层 writer、`cmd-config.sh` checked writer；config-cli writer/inject/cas/audit/callers |
| memory-and-deps — `A value is validated, quoted by the writer, and never copied from the caller's quoting`、`The machine read reports each key's choice set, and the schema is its only source`、`The machine read reports each key's functional group, and the schema is its only source` | MODIFIED：新映射值域与 task-model 分组；模型 shape 继续支持模型部分的 `/` 和 thinking suffix；known 来自本项目映射/PM/启动记录，不扫描机器 provider 集 | `cmd-config.sh` schema/choices/list JSON；`config-cli.sh shape/completeness/groups`、`panel-choices.sh`、`panel-strings.mjs` |
| memory-and-deps — `The disk is the source of truth, memory is a convenience` | MODIFIED：恢复读已选 assignment，不重新按当时配置猜；老记录缺字段给可执行修法 | `common.sh` state helpers；`cmd-watch.sh resume`、`cmd-status.sh`；smoke 11c/29 |
| panel — `The console edits a seat's model and shows where the displayed model came from` | REMOVED：替换为类别策略/PM 编辑与 assignment 展示，旧 source 三态和下一 spawn 切换语义不适用 | `panel/src/{App.tsx,main.tsx,layout.ts,types.ts,data.ts}`、`strings/{zh,en}.ts`；panel-p21、panel-choices |
| panel — `The console writes a project setting only through team config set, after validation and a confirmation` | MODIFIED：使用 owning category writer；保持 free-text/choice 两条确认路径、fingerprint、取消零写、诚实 timing；不重启 worker/pulse | 同上及 `cmd-config.sh`；smoke 33、panel-p21、panel-choices |
| panel — `The activity column is part of the default layout and stays bounded and session-scoped` | MODIFIED（若更换当前 session 选择）：优先当前记录 SID，不把旁边最新文件当当前任务；保持有界 tail | `monitor.mjs` session selector、`common.sh team_agent_session_cols`；活动/source fixture；本轮没有读会话内容 |
| agent-adapters — `The PM is an adapter too`、`The contract promises Pi; the launch and notify seam is an internal frozen seam` | MODIFIED：独立 PM 模型、旧 fallback 描述和“空配置字节不变”的情景需更新；保留 frozen seam，不扩大支持面 | `common.sh team_pm_model_resolve/team_pm_pi_args/team_pm_launch_cmd/team_agent_expand`、`cmd-watch.sh` up 的两处模型输出；smoke 6i/11b4、adapter invariant |
| pm-lifecycle — `PM liveness is proven, not inferred`、`A PM that is starting is a state, not a missing PM` | 保留证明/起飞中/quota 合同；若增加 PM 模型身份记录则 MODIFIED 相应情景，不把“选到强模型”当存活证明 | `common.sh team_pm_start`、`cmd-watch.sh team_cmd_up/team_cmd_watch`；smoke 11b2/11b3 |
| init-skill — `Initialization guidance lives in a dedicated teamsmith-init skill`、`Existing projects and running sessions see zero change` | MODIFIED：问卷的 per-agent models 改成类别映射+独立 PM；零行为变化承诺不能覆盖这次破坏式路由升级 | `cmd-project.sh team_cmd_init`、`cmd-bootstrap.sh`、`templates/config.sh.tmpl`、`skills/teamsmith-init/{SKILL.md,references/bootstrap.md,templates/bootstrap-prompt.md.tmpl}`；smoke 1b/2/18b/39 |
| watchdog — `The pulse never manages tmux layout, agents or quota`、`A cause belongs to the current launch of a seat, never to a previous one` | 保留 patrol 只叫 PM；当前 SID/launch 身份改变时 MODIFIED 死因归属情景，不添加自动 worker 恢复 | `cmd-watch.sh watch`、`cmd-death.sh team_agent_session_latest`；smoke 11b/11c/52、death-cause.sh |
| boundary / verification — `An actor touches only the paths its brief allows`、`The verifier of a change is not one of its authors`、`Verdicts are explicit, including the not run cases` | 保留；不因强模型或新类别绕过 ownership、提案评审、独立复验或授权止点 | guards/报告/独立 checkout；相关既有门禁，不增加一套审查系统 |

未来新增的正式行为（category 路由、assignment continuity、旧配置诊断）应在这些 capability 内补 delta；本表明确 REMOVED 的两项不能与新合同并存。没有对应旧标题的部分才用 ADDED。

### 只改 dispatch 会留下的读写面

1. **加载与解析**：`common.sh:887,889,958` 注入 default/PM/seat 值；`team_agent_model`、`team_agent_model_src`、`team_pm_model_resolve`；并发计数和启动显示消费的 state model；`team_agent_expand` 给模板的模型参数。
2. **席位生命周期**：`team_worktree_add` 无论创建还是仅打印都预写模型状态；`team_cmd_add_agent --model` 调用 seat writer；teardown 的 register 路径只改 roster，不清旧 model token，现有配置读侧会把孤立 token 报 warning。去掉席位策略后名册变更不应再与模型绑定；也不能保留空的虚假“席位默认模型”。
3. **CLI/schema/machine read**：`cmd-project.sh team help`；`cmd-config.sh` 三个老键、pairlist roster 验证、seats/source/override/default/known/choices、写接口与提示；`cmd-status.sh` roster/ps 来源显示和 `TEAM_DEFAULT_MODEL $TEAM_AGENT_MODELS` 模型表。模型表改取映射、PM、记录的去重模型，不只显示固定席位。
4. **恢复与 PM**：`cmd-watch.sh resume`、`up --agents`、PM up/巡检启动；`common.sh` PM built-in/adapter 参数；`cmd-watch.sh:182,194` 的成功消息也有旧 fallback，不能只改实际 argv 留下假显示。
5. **console**：`main.tsx setSeatModel` 仍发旧命令；App 的 target/editor/receipt、layout 的 seats 与 pairlist 导航、types/models.default/models.seats、zh/en 分组/label/说明都会残留。新 UI 不应自行拼完整映射；`settings.ts` 只存 panel.conf 偏好，不是项目模型写入口，无需新增模型状态。
6. **SID 的显示读侧**：`cmd-status.sh team_cmd_roster/team_cmd_ps` 共用 `common.sh team_agent_session_cols`；只改 dispatch 保存/恢复 SID，模型列可能正确却仍把旧基础会话数字和超窗警告配给新任务。应使用 assignment 的 SID 实时 stat；缺失身份显式 unavailable，不静默挑基础/最新文件。CLI/console 的调用层与死因/活动选择一起检查，但不能扩大成 Pi 会话转换。
7. **初始化与指导**：config 模板、init 的 `--default-model` 渲染、bootstrap 调用 init、OWNERSHIP 模板的 model 列、PM prompt 派单步骤、task 模板的 category、AGENTS/PROTOCOL/memory-seed 相关指引、teamsmith SKILL/config/workflows/protocol/agent-adapters/migration、teamsmith-init 问卷/模板，以及 README 的初始化说明。当前 dispatch 的 worker prompt 在 `cmd-agents.sh team_build_prompt`，没有单独 dispatch-prompt 模板。
8. **测试假设**：smoke 的共用 fixture、29 明确要求“配置压过记录”、config-cli 的 completeness/seat/source/PM fallback、panel-choices 的 default 和 seat model vocabulary、panel-p21 的 picker/移除覆写，以及 routes 的 `add-agent --model`/schema promise probes；death-cause 使用旧配置初始化夹具。不能机械删除红断言：旧语义情景应换成上述新的红/绿情景，其余安全/CAS/shape 断言保留。

## 4. 破坏式升级与可用的修复前门

### 拒绝旧配置，但不能把 canonical writer 一起锁死

建议 operational 前门在副作用前拒绝任何旧 `TEAM_DEFAULT_MODEL`/`TEAM_AGENT_MODELS`（包括空赋值或新旧混用），或缺少完整映射/PM 的配置；显式报退役键、缺项、文件和升级命令。不要只检查 key 非空后继续回退，也不能 `--force` 进入旧路由。环境中的旧键同样不给 routing 语义，报 unset 指引。

**不能在 `team_load_config` 无条件 die**：`scripts/team` 在分派子命令前调用它，这会让 `config set`、diagnostics 和 upgrade 无法修配置。建议加载负责定位/读取和标记 legacy，启动操作统一 preflight；`paths`、`doctor`、`config list --json/log`、upgrade 的 dry-run 是可用诊断面。`config list --json` 报 `migration_required` 和 retired keys，不再伪造 seats/default 作为可执行策略。

建议增加 canonical config 子命令（名称在 propose 中定稿）：

```text
team config upgrade-models --task-models '<完整新映射>' --pm-model '<明确模型>'
                          [--dry-run] [--fingerprint <sha256>] [--yes]
```

先输出具体差异并校验全映射/PM，再在**同一** checked writer 事务中写新字段、删除退役 assignment、语法校验、CAS、原子替换、写一次事务审计。不从旧席位配置自动推导 category，不创建另一套写入器；`config set` 可写新合法键，不许重写 retired 键；旧 `set-agent-model`/`add-agent --model` 给有实际效果的新 route，而不是继续偷偷映射。

升级失败/取消/dry-run 不改配置、state 或治理文件；CAS/非法值失败遵守既有 writer 的审计合同（允许规定的拒绝审计，不能把配置日志写入也误称“完全零写”）。缺/重复/多行/动态生成旧字段不能仅靠文本替换假装清理成功；不能安全定位时明确拒绝并让 PM 手动修正相关赋值，再重走校验。已有配置允许 bash 逻辑，不应本轮顺便改成另一格式。

### 不用 init --force 迁移已有项目

`cmd-project.sh team_cmd_init` 保留已有 config，但 `--force` 重渲染 config 与治理 skeleton；普通 init 仍按参数生成文档，bootstrap 还会安装 skill、创建 worktree、拉 pulse。它们不是安全的模型升级入口。

- **新项目**：init/问卷提供新映射和明确 PM；没有旧 worker default 参数。通用模板可用公开示例，但部署项目的 mapping 应由其 PM 明确填写，不假定所有机器都有本仓 provider。
- **已有项目**：显式 upgrade 仅改模型契约字段；不触碰 BOARD/ROADMAP/DECISIONS/OWNERSHIP/任务/报告、安装路径、名册或 worktree；bootstrap 在 legacy 配置下先拒绝并指 upgrade，不先填旧 defaults 或覆盖账本。
- **本仓**：PM 后续获准执行时，备份配置并持 fingerprint，预览本报告建议的两模型映射及独立 PM，保留现有限额/窗口/身份/账本路径。此探索没有修改本仓 `.pi/team/config.sh`。旧已完成任务和报告保持历史原文；必要的新 category 只给新任务或明确 fresh 接管的未完任务补写。
- **旧未完启动记录**：历史 model/sid 即使存在，也没有新的 category/record version。建议阻塞 resume 并给 fresh 接管和交接材料的 route，不默认猜类别、不回退到席位模型。完整的新版本 assignment 才允许 exact resume。不能删除旧 SID/成果来“修复”升级。
- **正在跑的席位**：配置升级不 kill/restart；实际模型继续由其旧进程持有。后续 re-dispatch/resume 按上述旧记录处理。独立 PM 新模型首次接管建议 `up --fresh-pm`，在授权和交接后执行；巡检不自动换模型。

## 5. 建议的验收策略（本轮未执行新功能测试）

优先复用已有前门和记录桩；每个红例保存 config/assignment/prompt/BOARD/worktree 指纹及 tmux argv 计数，修正后同命令转绿。不要只判 rc=0 或打印“dispatched”。CLI refusal 要判实际零开窗、零 launch、assignment 不变；writer failure 的合法 audit 另计。

| 入口 | 红侧与绿侧建议 |
|---|---|
| `dispatch <seat> <ID> <brief> [--model] [--fresh] [--print]` | 缺/重复/非法 category、缺映射、空 PM、旧/新混用配置拒绝且无启动；合法 brief 在不同席位仍选同类别模型；同席位不同类别选不同映射。显式 override 同时记录 category/explicit 和完整 thinking suffix。 |
| 同任务 dispatch / `resume --agent` / `resume --all` / `resume --dry-run` | 初次 explicit+fresh 后退出，恢复捕获的完整 model/SID 与启动记录逐字一致；更改 category 映射后仍恢复旧 assignment，新任务才用新映射。重复 resume 不生成新 SID；缺/损坏/不匹配 task/branch/brief/category 记录明确拒绝；dry-run 不写 thread/prompt/state。 |
| 换模型接管 | 不 fresh 的 override 拒绝，`--force`/`--allow-overflow` 不绕过；fresh 后 SID 必须不同、交接材料进入 prompt、旧材料不删；再次 resume 使用新身份。破坏读 record 的实现后 exact-recovery 测试必须红，恢复后绿；同秒两次 fresh 也不能 SID 冲突。 |
| `up --agents` / `watch --once` | up 救援恢复 exact model/SID；模拟断电缺窗的记录桩测试，不真实断电。patrol 发现 stopped 只提醒 PM、零 worker 启动；PM 明确 resume 后精确恢复。巡检可恢复 PM 自身，但旧/变更模型身份不能自动继续历史。 |
| `up --print` / `up --fresh-pm` | PM 模型不受 worker category 映射改变影响；无 PM 值拒绝；PM argv/成功消息/config JSON 使用同一解析；新模型复用已知旧 PM 会话拒绝，fresh 接管转绿；继续保留 liveness/spawn/in-flight/quota 夹具。 |
| `config list --json` / `config set-task-model` / `config set` / upgrade | 类别闭集、重复/缺项拒绝，provider+含 `/` 模型和 thinking suffix 接受；模型 known 只取项目数据。保留 quotation/injection/CAS/audit 原子性；旧命令给可执行修法。故障注入第二字段写失败时配置整体不变；upgrade 前后治理文件 byte-identical。 |
| console 项目设置 | category picker 与 PM 编辑通过 CLI 的 dry-run/write/CAS，不自行拼映射；未知类别/非法模型/旧配置诚实 receipt；取消无写；映射改后已派任务仍展示 assignment，新任务预览显示新 policy；不能重启 worker/pulse。包含真实 TUI 的方向键/确认/冲突复验，不只测 JSON。 |
| concurrency / session window | 配置选择、explicit、resume 都按**实际要启动的模型**判断；已有同 wildcard 归组满额时红，结束占用后绿，0/unmatched unlimited 保留。恢复的原 SID 超窗口红，fresh 明确转绿；不自动跨模型重试；RAM/swap/disk/branch/delta/verify-seat 守卫仍在同一 preflight。 |
| preview/source/extra args | print 与真实记录桩 argv同源，展示 category、实际 model、policy/explicit/assignment 来源、SID、fresh/continued；新 preview 建议完全不写 state/prompt。拒绝 extra args 中可覆盖 Teamsmith-owned model/provider/session 的参数，避免 argv 实际模型与 state 分叉；不靠 Pi 最后一个参数优先的偶然行为。 |
| SID 关联的显示/死因 | 扩展 smoke 6h A5/A9：用独立 HOME 和合成 stat 夹具留下超窗的基础 SID 文件，成功 fresh 后记录新 SID、初始 sid_bytes=0；`roster`/`ps` 不得继续报旧基础文件的超窗数。再增长新 SID 文件，仅 stat 验证显示随当前大小变化，不把派单快照0当实时数据；exact resume 后仍用新 SID。当前 SID A 旁有更新 B 时，size/activity/death 也不能误认 B；缺失身份明确 unavailable，launch nonce 限定当前死因。不读取真实用户 history，不检验隐藏思考。 |

分层执行：config-cli 的 writer/CAS/shape/callers + 新 routing/recovery isolated tests；routes 的新旧命令/修法；smoke 触及的 1b/2/6c/6h/6i/11b–11c/29/33/39/51/52/54，另跑 panel-p21/panel-choices/panel-strings；合并前由不同作者在独立 checkout 跑完整 correctness gate。最终发布/合并/归档仍需要各自授权；这张计划不构成执行许可。

## 6. 工作拆分、成本和主要风险

建议一次 change，propose 由当前 explorer 单独负责；PM 留下 ACCEPTED proposal review 后才派 apply，规划者不实现自己的提案。

- **apply 1（一个 owner）**：config/schema/唯一 writer/upgrade + dispatch/assignment/resume/PM + CLI help；这些共享 `common.sh` 和 `cmd-config.sh`，不宜让多个实现者同时写。先以完整配置交易和 exact recovery 两个可验证提交推进。
- **apply 2（另一 owner，可在接口明确后并行）**：console/schema types/zh-en/CLI wrapper 与真实 TUI fixture；只写 panel capability delta。
- **apply 3（一个 owner，可与 UI 并行）**：init/bootstrap/templates/问卷/guidance 和 fixture seed 更新；不得写前两个 owner 的 delta。同一 change 的 dispatch、memory-and-deps、agent-adapters、pm-lifecycle、watchdog delta 统一归 apply 1；init-skill delta 归 apply 3。
- **独立 verify**：不是 explorer/apply 作者；若 verify 席位参与 propose 就另选未参与作者身份的 agent。复跑恢复/新会话反例、writer 故障注入、console 实际 argv、旧配置升级字节差异以及全量门禁，PM 再独立评审。

估算为工程工作量而非已测耗时：提案 0.5–1 人日；核心 2–3 人日；console 1–2 人日；初始化/指导/广泛夹具改造 1–2 人日；独立对抗复验 1–2 人日。合计约 5.5–10 人日；并行能缩短日历时间，但不能省掉配置事务与恢复身份的联调。最大的工作量不在 if/else 选模型，而在撤销多条公开旧合同及其夹具假设。

主要风险：全局 loader 拦死修复命令；add-agent 预写覆盖 assignment；停止窗口计数导致同任务恢复被自身配额拦住；PM 不在既有 worker 配额计数内；多次 state_set 导致中断后半条记录；UI/ps 仍按下一 spawn 语义误报；extra args 覆盖真实 model/SID；旧会话继续关联基础 SID 或最新文件；PM 默认 continue 在换模型时越界；大量夹具仍靠旧 defaults 起跑；本仓强模型限额 1 导致规划/复验排队。全部可在提案里转为具体 delta/测试，无需模型 benchmark 或兼容矩阵。

**没有缺失的用户方向决定，也没有硬阻塞。** 类别/token、CLI 名称、state 版本与事务格式由团队在 propose 定稿。D101 的破坏式更新、PM 独立、Pi 边界和当前仅规划授权不再提请重复确认；apply/本仓配置执行仍等待后续明确授权。

## 7. 本任务验收与交付

本轮只验证报告、规格引用与隐私边界，不运行 smoke 产品段、完整门禁、真实模型质量测试、PM/巡检实时重启或真实 console 交互。以上新功能矩阵是下一阶段的验收设计。

初稿 `cb328da` 在 clean tree 上已执行全部五条验收命令，结果如下；`f161a77` 的复跑同样五条 rc=0，保存在 `pre-sid-supplement-acceptance.log`。PM 的 SID 显示补充纳入后再跑同一组，外部 `final-acceptance.log` 为最新交付版本的原始输出。`acceptance.log` 保存初稿输出；各轮均没有中途改动受检树。

| 实际命令 | rc | 输出摘要 |
|---|---|---|
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 0 | `Totals: 13 passed, 0 failed (13 items)` |
| `bash skills/teamsmith/tests/smoke.sh --paths docs/team/reports/E13-verify.md` | 0 | `decision=NONE`；报告属于 docs 豁免类；`一段都没跑、没有结果行、不是门禁证据` |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 0 | `judged 104 reference(s) (49 distinct)`；`retired 0; undeclared 0` |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --git-common-dir)/../.pi/team/forbidden-names.txt"` | 0 | `scope=published files=1301 hits=0 names=ok user=resolved`；本轮不是 rc=3 跳过，未打印名单内容 |
| `git diff --check` | 0 | 无输出 |

最终本地提交、分支与 clean status 记在外部 `delivery-state.log`，其命令为 `git rev-parse HEAD`、`git branch --show-current`、`git status --porcelain`。只交本报告，外部探针/日志不提交；不 push/PR/MR/merge。本任务是探索，不是 defect-fix；没有产品红转绿声明，上述恢复反例是提案的实测依据。
