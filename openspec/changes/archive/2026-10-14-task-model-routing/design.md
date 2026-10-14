## Context

动机见 proposal.md。E13 原件与独立评审证明：旧 dispatch 的 `--model > seat > default` 与 resume 重新解析会丢失覆写/fresh；现有记录不是不存在，而是写得分散、恢复不用它。会话大小硬编码基础 SID，活动取最新目录会话，死因按前缀取最新；后三者须同时改身份输入。PM 有独立启动器、存活/starting/spawn 证据，但模型仍回退 worker default。配置已有 schema、quoting、CAS、audit 和 hardened writer；设置页已有异步 machine read、CLI 子进程写、真实 pane 夹具。

本设计服务七个 delta，不引入另一份要求目录。规划者 verify 不参加 apply；规划和今后验收不能证明模型质量。

## Goals / Non-Goals

**Goals**：让策略解析、真实参数、完整 launch 记录和读侧关联使用同一身份；让 breaking 升级仍能通过安全 writer 修复；串行化共享文件写者，避免宽目录分工看似并行实际冲突。

**Non-Goals**：Pi/provider 推理/会话转换、隐藏思考、模型兼容矩阵、任务分类器、价格/质量 benchmark、订阅总预算；不检测 Pi 内手动换模型，不修改历史任务/报告/会话，不修 init 身份/force 或自收件通知缺陷，不新增自动安装、live rollout 或通用 bash parser。

## Decisions

### 1. 一个 brief 类别来源，项目映射定义词汇

`category:` 必须唯一，token `[a-z][a-z0-9-]*`；配置是 `TEAM_TASK_MODELS='category=provider/model ...'`。token 精确匹配、唯一、非空，至少一项。模型沿用现有 shared shape（第一个 `/` 分 provider，剩余 model 支持 `/`，suffix 原样保留），新入口不复制另一份校验。写者拒绝不能表示的字符；category-map 的模型不能携带空白、额外 `=`。项目没有 routine 等键并非非法，映射为空才非法。

不另加 dispatch `--category`；`team task --category` 只是生成 header。phase/seat 是流程/权限，不是复杂度。`phase: verify` 不在引擎硬编码等于 `category: verify`，因为项目可自定义 audit 等名称；PM 按独立复验指引选合适映射。比硬编码三类别或 phase 路由更小，也能避免 worker 席位重新变成模型身份。

初始本仓建议（非 engine 默认、尚未写入任何 live config）：

```bash
TEAM_TASK_MODELS='routine=opencode-go/deepseek-v4.1-flash analysis=openai-codex/gpt-6.1-sol:high verify=openai-codex/gpt-6.1-sol:high'
TEAM_PM_MODEL='openai-codex/gpt-6.1-sol:high'
```

不用新 provider/订阅。强模型用于 PM、复杂分析/重要架构判断/独立复验，普通 bounded apply 推荐快模型；是否足够好以后看真实返工和交付时间，不从门禁推出价值。

### 2. 策略与已派 assignment 分离

解析表（所有行先要求整体合法、完整的新配置和唯一合法 category header；先判已提交身份是否完整且 task/brief/category/branch/worktree 匹配。只有首次/新任务/需重新选择的接管检查当前映射成员资格；完整同任务恢复不重做类别成员资格判断）：

| 调用 | 完整 model | SID | selected_via / launch_via |
|---|---|---|---|
| 新任务 | override，否则类别映射 | 唯一新 SID | explicit/explicit 或 policy/policy |
| 完整同任务，无 override/fresh | 记录值 | 记录 SID | 原 selected_via / assignment |
| 同任务，同 model 的 explicit | explicit 值 | 记录 SID | explicit / explicit |
| 完整同任务，fresh，无 override | 记录值（非重新读策略） | 唯一新 SID | 原 selected_via / assignment，mode=fresh |
| 同任务，不同完整 model | 不带 fresh 拒绝；fresh 新选择还须当前合法映射类别 | 不分配可用身份 | 无发布 |
| 同任务，fresh+override | 同 model 保留身份；不同 model 要求当前映射中的声明后用 override | 唯一新 SID | explicit / explicit |
| 旧/破损/身份变化记录 | 普通恢复拒绝；fresh 接管重新合法声明 | fresh 才分配 | fresh 时 override 或当前 policy |

严格比较包含 thinking suffix；这是保守的 Teamsmith continuity 规则，不是 Pi 不兼容的证明。合法非空配置把未来 routine 类别改名或删除，不会使完整同任务 assignment 失效：原 routine/model/SID/selected_via 仍是恢复身份，launch_via 为 assignment，不要求改 header 或 fresh。同模型 fresh（无新 override）仍保留已派 model/category/origin，只换 SID；显式同模型可继续并按原有 explicit provenance 规则记录。显示当前 policy 无 routine 时标记缺少未来映射，不捏造 policy model/身份故障。新 routine 任务即使 override 仍拒绝。整体配置缺失、非法或含 retired keys 不是合法删除，照旧阻塞。改 brief category/task/path、branch/worktree 或请求不同 model 仍按 identity/fresh 规则；需要重新选模型的 fresh 接管必须有当前映射中的类别。brief 只匹配规范路径、category 与任务，改标题/验收正文不强制丢失上下文。

SID 用 session/seat 前缀 + 现有 nonce 风格的随机/进程/时间唯一部分，并在已知 assignment/attempt/file 候选中检查冲突；绝不用秒时间戳单独作唯一性。fresh preview 的 candidate 不保留，真实启动重新分配并明说差异；continued preview 完整 SID 可与实际 argv 逐字比。不读 session 内容来推断身份，不复制 reasoning/message 到新会话。prompt 包含 goal、分支/代码状态、证据位置、未决工作，并指向磁盘交接。

### 3. 发布一份完整记录，不逐字段写

继续使用 `state/<agent>.env` 做 flat data 记录，不另建恢复数据库。`assignment_version=1` 与完整字段是新记录标志。记录：task/taskfile/category/branch/worktree/window/seat/model/selected_via/launch_via/sid/launch_nonce/started/sid_bytes/mode；空快照用空字符串，其他必填不空。读取不 source、不 eval，以现有 data read 形状实现严格版本/唯一字段检查；字段换行不能表示即拒绝，路径采用 canonical path。旧 `model_src` 停用，旧记录保留但判 legacy。`team_worktree_add`/add-agent 不能预写“默认 model”。

真实 launch 的只读 preflight 全部接受后获取目标 seat 锁（同项目同 seat），覆盖最终复核→proof→publication；另取项目 worker admission 锁，跨 seat 的最终计数和启动到 proof 串行，防止两个席位都读到同一空余名额。选用已有 shell 可实现的 mkdir 锁，不增加依赖；锁位于系统临时区，以 canonical project hash/seat 区分，preview 不获取锁，不碰项目时间戳。记录 owner pid/开始身份/attempt，有限等待，不能证明 owner 已死亡时不强抢。可证明 stale 时先保留中断诊断并检查 pending nonce，不静默当成功。配置 writer 使用独立同文件锁覆盖读/CAS/rename，所有写入口共用；dispatch 只在短的最终 fingerprint 复核阶段持 config 锁，固定顺序 seat→worker-admission→config，config 不反向获取其他锁，避免锁环。

before-launch 在锁内重核全部 guards 和所读 config/assignment fingerprint；改变则在无项目写入/启动状态下拒绝或从只读状态重算。全部接受后准备完整 assignment 临时文件、验证全部字段后才允许 replacing window。开启 attempt/pending marker，内容是这轮 nonce 与计划身份，不是成功 assignment。preflight 保留复合拒绝，不变成十轮短路。

成功条件仍是本轮 nonce proof 加原有 built-in/custom 的成功裁定；记录不可冒充 agent 仍在运行。成功后同目录 rename 一次发布 complete record，再标 board wip、清 pending。失败保持 old record，保存 attempt 日志，停止未提交新 worker。若异常中断，pending 或 nonce 与 committed record 不一致阻塞普通恢复；必须显式 fresh。若 rename 已完成而 board/pending 清理未完成，匹配 nonce 证明完整提交，继续使用该 record，并报 board 故障；不撤销已经发生的 launch。

不选“先写 state 再 launch”：会把失败启动伪装接单；不选逐条 state_set：中断能混合 model/SID/task；不选覆盖另一文件再让读者拼起来：会制造两份真相。close/teardown 对该完整记录的清理和锁顺序由核心 owner 一起适配，但保留既有 task/window 清理合同。

### 4. 新的 configuration 前门，最小定点升级

退休 worker default/seat 两键和 `set-agent-model`/`add-agent --model`，不保留旧路由兼容。新映射 kind `task-model-map`、group `task-model`、class apply（新任务读）；PM required model/class restart（新 PM startup，还受 fresh guard）。limits/windows 不改数值或 worker scope。

`config set-task-model` 支持 upsert 自定义合法 category；没有 `-` fallback。删除类别使用 whole-map set，结果仍须非空合法；它限制未来新选择，不删除/失效化已有完整 assignment。新任务引用已删类别拒绝；完整匹配的同任务 resume/fresh 同模型遵循决策2。PM 仍普通 config set。映射只选 vocabulary 不扫描机器模型 catalogue；known = 有效项目 policy + 完整 committed records，即使已派类别不在未来映射中也保留其 model，保留多 slash/suffix，去重。

`config upgrade-models --task-models ... --pm-model ...` 是唯一额外编辑前门：完整明确输入、先 preview、--yes 才写；复用 checked writer 的 temp/render/bash-n/mode/CAS/rename/audit。事务 patch 只限四个 model keys：删 retired direct assignments，upsert 两个新 keys；删除行的 inline comment 转成原位 standalone comment，存活行 inline comment 保留，其他字节不动。单次 transaction 审计含 changed keys、before/after fingerprint，拒绝审计遵守原 exit codes，audit 写不出只告警而不谎报 config 未变。

安全接受的 relevant line grammar：顶层唯一 `KEY='literal'` 或 `KEY="literal-without-expansion"` 或无空白/扩展的简单 literal，可带 inline comment；canonical writer 的 escaped single-quote roundtrip 也可识别。相关字段出现 export/重复/多行/变量或命令扩展/条件块/indirect assignment 时保守拒绝并点名路径/行号，要求手工规范成顶层 literal 后重试。识别不能安全定位的 source shape即拒绝，不尝试通用 bash AST；无关代码不解析/重排。这里配置文件是已有受信 shell contract，不承诺阻止文件内任意恶意 Bash。

loader 标注 migration_required，不能无条件 die（否则修复命令死锁）。paths/help/doctor/config 诊断与写新字段都能工作；model-dependent operational preflight 才拒绝 retired presence，包括空 assignment 和环境旧变量。环境拒绝提供 exact unset 路线。init/bootstrap legacy 拦截早于 install/ledger/worktree/pulse；不在本功能修其其他身份/force 机制。

### 5. 读侧、并发和 console

`team_agent_session_cols` 等只用 committed worktree/SID，每次 stat 当前 file，sid_bytes 是零产出诊断的 launch snapshot。活动/死因保留 bounded head/tail 的 existing reader；目录最新/B/base 不作为 missing A 的 fallback。missing identity 不猜 0，known fresh 尚无 file 的 size可 0，activity/error仍 unavailable。所有夹具自己的 HOME，不打开真实用户历史。

Concurrency 仍只计本项目 proven-live workers；明确 stop/dead/exited/absent 与 PM不算。对有正上限的目标，其他已由 PID/nonce 证明存活、但 committed model 身份 missing/legacy/incomplete/malformed 的 worker 不能从组中排除：可能占用该 exact/wildcard 组，admission 判 unjudgeable 并拒绝，preview/force 一致。输出 target/rule/limit、known_count 与 unknown peer 名/record 缺陷，不把未知当0，不从 partial model、未来类别或旧席位配置猜当前 model。只打印本项目该席位的合法 brief+fresh 接管路线，或 `team teardown --agent <peer>`（不带 --purge/--register）的显式停席路线；不代执行，不影响其他项目，先保留诊断/磁盘交接，重试重新证明其状态。替换目标从 before-state peer 集合排除，加入已知计划 model计一次，不能因被替换目标旧身份不明而双计/阻塞。exact优先、wildcard最严正上限和共享归组保持，exact 0/unmatched 等实际无正限额目标不因 unknown peer 增加预算 blocker。不新增订阅预算。model guard/窗口 guard用实际 override/assignment；容量、branch、delta、verify-seat等复合 preflight不缩水。窗口 suffix处理复用既有解析，不用模型名推断难度。

JSON supersession：`models.policy.categories[{category,model}]`、`models.policy.pm`、`models.assignments[]`（assigned/task/category/model/selected_via/launch_via/sid/diagnostic）、`models.pm_launch` 与 `models.known`。不再有 default/seat override；空 actual字段使用空字符串、assigned=false。policies和实际 launch不同列/标题，不能把“下次 spawn用新配置”放到恢复行。记录只保证 Teamsmith 参数，不证明随后每轮 Pi内部模型。

panel 改类别 block/PM editable row和只读 assignment block，App/main wrapper走 category CLI，类型/strings/layout/data同步。mapping row导航类别编辑，不给整 pairlist compose；删除只通过明确 whole-map CLI，不发明 UI remove/fallback。已有 keyboard/mouse/scroll/filter/class/receipt/conflict/async re-read保持。legacy显示 migration route，不新增 in-panel transaction/worker/pulse restart。bundle与provenance由 UI owner生成。

### 6. PM 只扩展原启动器

`team_pm_model_resolve` 只取 required PM值；`team_pm_pi_args/team_pm_launch_cmd/team_pm_start` 各条路径同源。原 `pm.pid` proof/starting/liveness不变，新增小的 `pm-launch.env` complete metadata由原 starter发布，字段project/window/model/nonce/time/mode，不是一套 PM任务 assignment/resume。

已知同 model metadata允许原 -c/session/resume继续；missing/legacy/manual-unknown/变model或suffix须用户 fresh-pm。running/starting PM不受policy更改重启。PM `--print` 不先写prompt/markers，fresh覆盖旧continue args。attempt nonce与metadata发布故障处理在既有 start/proof处，无新 daemon。巡检预检continuity blocker，显式 fresh路线给PM/人，不自动切换且不耗restart slot。custom frozen模板仍支持，但无法证明参数身份的硬编码 continuation不许宣称exact；无历史继续的 custom仍诚实提示交接。

extra args 的 model/provider/session/continue包括 separate/equals/short和bare session路径拒绝，保留 harmless extras；不依赖 Pi最后参数优先。配置的 PM resume参数由原 continuity选择路径控制，并非 extra args禁令。不能检查/转换provider消息，也不宣称能知道Pi内部手动换模型。

## Execution slices and file ownership

以下是未来 PM 派单建议，不是任务授权。串行三次 apply，避免所有人修改 smoke/common；不是按目录强行三路并行。每阶段必须先取得 proposal review ACCEPTED，规划者不得 apply。

本机两个全局技能入口 `~/.agents/skills/{teamsmith,teamsmith-init}` 均软链到本仓主检出的 `skills/`；本轮只读 `readlink` 已再次确认。主检出产品字节变化会影响后续共享读取，不需要 installer。因此 S1→S2→S3 的“集成”专指 PM 在获批 apply 后准备的**私有非部署 clone/集成树**，不是实际共享 main，也不是把全局软链指向 worker。该树不能成为已知 global/project-live links 或 live CLI source 的目标；tests 使用 fixture HOME/config、私有 source 路径和隔离 tmux。各切片报告注明私有 commit、定向验证、冻结/释放的文件和接手者；PM只把它作为依赖交接，不在共享 main落部分代码，不调用 live init/bootstrap/install。

S1私有验收/集成后可按记录释放共同文件给S3；S1 apply task仍未完成到 protected main落地，不以 private branch ancestor 或定向测试报告提前标 done。PM在 thread/brief 中记录临时所有权交接及 exact input commit；需返修已释放文件时先收回交接，不能两人同时写。S2/S3的输入是该私有受检 commit，不要求为了满足依赖先把S1标done或合入共享主检出。

| 顺序 | 推荐 owner | 唯一产品/测试写集合 | delta 唯一 owner |
|---|---|---|---|
| S1 core | dev | scripts/lib/common.sh、cmd-config.sh、cmd-agents.sh、cmd-watch.sh、cmd-status.sh、cmd-death.sh、cmd-bootstrap.sh 中 writer、cmd-project.sh 中 CLI/help、monitor.mjs；tests/config-cli.sh/routes.sh/smoke.sh/death-cause.sh 和 shared fixture helpers；新 task-model-routing.sh 入口 | dispatch、memory-and-deps、agent-adapters、pm-lifecycle、watchdog |
| S2 UI（S1私有集成/验收后） | dev2 | panel/src/**、panel.js、panel README provenance；tests/panel-p21.sh/panel-choices.sh/panel-strings.mjs及UI专用模型夹具；不写common/config/smoke | panel |
| S3 initialization/guidance（S2后） | dev3 | 两技能与references、README、templates/**；cmd-docs.sh、cmd-project.sh init部分、cmd-bootstrap.sh bootstrap部分；tests/config-cli.sh completeness/docs/callers、routes/smoke 新项目 seed及task-model-routing.sh init/共享来源夹具相关变更由 S1 owner 串行交接授权给S3 | init-skill |
| V independent | 未参与apply的verify或新独立席位（PM确认） | 只读独立checkout、自己的report/证据；无实现/其他delta写权限 | deltas: - |
| archive | PM | 仅全部任务完成、独立复验通过且用户确认后正式archive | 全部 |

S1不得改templates/init UI产品面；它自己的 tests先用手工新配置 fixture，S3接过shared files时S1已私有交付、冻结并释放这些文件的临时写权限，但未据此标done。S1的cmd-project/help和cmd-bootstrap/writer与S3的init/bootstrap同文件，明确时间串行交接，不能同时unfinished写同delta。PM真正派单时给切片边界/branch/deltas，不从此表自动launch。共享测试逐步转换，不删除失败断言来保绿。

S1→S2冻结的JSON/CLI接口见决策5与memory delta，S2不能自己修core问题：BLOCKED回PM。S3不能同时替S1改assignment。verify不验证自身apply；此任务verify只做proposal不属apply author，但独立读工件仍由PM审查。

## Future acceptance front doors

**以下命令尚未执行，用于未来apply/verify；涉及新接口/sections的均尚未实现。** 所有test只在自己fixture使用 recording agent/隔离tmux，不运行真实provider，不读真实history。先检查/tmp余量，full suite一次只一个，背景启动收割，运行时树不改。

```bash
# 新测试入口（S1实现）；包含选择/恢复/事务/PM/读侧/并发/升级的 argv与效果证据
bash skills/teamsmith/tests/task-model-routing.sh
# 已有入口；S1/S3更新其旧模型语义
bash skills/teamsmith/tests/config-cli.sh
bash skills/teamsmith/tests/routes.sh
bash skills/teamsmith/tests/death-cause.sh --pure
bash skills/teamsmith/tests/death-cause.sh --live
bash skills/teamsmith/tests/death-cause.sh --flip
# UI已有前门；未来更新为category/assignment，包括真实tmux capture与logging CLI
bash skills/teamsmith/tests/panel-choices.sh
bash skills/teamsmith/tests/panel-p21.sh
"$HOME/.bun/bin/bun" skills/teamsmith/tests/panel-strings.mjs
# 已有build入口，只有本地依赖已备齐时跑；安装依赖须另授权，不暗装
BUN="$HOME/.bun/bin/bun" bash skills/teamsmith/scripts/panel/build.sh
# 合并/独立复验前一次完整门禁（不是本次规划验收）
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/smoke.sh
```

slice提交用config选段 writer/inject/cas/audit/shape/json/completeness + routing定向组，UI用settings/choices真pane，S3用init/docs/callers；各入口的retired models/seats段保留入口名但改断言为退役拒绝/类别替代，不能悄悄skip。full suite前全切片集成到私有非部署树，验证期间不把源码/全局链接指向它。新 routing脚本group和flip旋钮在tasks明确，不冒充当前可执行。验收附件必须含command/rc/captured argv/config/assignment/prompt/board hashes、nonce日志及真实pane捕获；skip/not-run单列，不用stub证明真实Pi质量。

## Risks / Trade-offs

- 严格fresh规则可能要求人补磁盘交接 → 给明确CLI route；不自动读/回放旧session。
- relevant source grammar过于保守 → 可行动的manual normalization；不改其他keys或重渲染账本。动态配置不为此编写通用parser。
- core先进入共享 main而templates/UI仍旧会暴露部分breaking实现 → 仅私有非部署集成，切片暂不done；完整独立验收和共享/source采纳授权前不落共享 main，不在中间调用live init/bootstrap。
- 同秒SID碰撞/半记录/并行覆写 → nonce、冲突检查、目标锁、CAS和中断反例都验证真实效果。
- metadata解释强于实际推理 → 明示selected launch，不证明后来Pi模型；不越过Pi职责。
- PM strong与worker并发可能仍争同订阅 → worker范围如实说明，由PM排队，不宣称总预算。
- /tmp低余量与真pane负载会造环境红 → 记录容量/真实premise，复验不能拿skip当通过。

## Migration Plan

1. 用户先看本工件、PM独立proposal review；没有ACCEPTED就无apply brief。此阶段到规划验收停止。
2. **私有源码验证**：S1→S2→S3只向未部署的私有集成树交付，按上述 commit/文件冻结方式交接；完整树上独立V复验。切片记录为已交付/私有已评审，apply任务仍未done。私有树不能被既有global/project-live skill或CLI来源引用。
3. **共享来源风险决策与保护分支落地**：PM展示已知两条global链接及其他已知shared/live引用的只读清单、目标/版本、完整新源码tip和未迁移配置可能拒绝后续操作的影响。未知消费者不能保证不受影响。推荐A：用户逐命令批准先把已知共享消费者隔离到保留的稳定旧源码/固定副本，验证链接/来源和读回，再另外批准完整源码落main。可选B：不隔离，但用户明确批准共享目标改变及后续读取的breaking影响，再批准完整已验源码落main。单独同意私有测试、普通merge或本仓config升级不代表已同意shared影响；无该选择/授权就停留私有树，不自行改链接/install/其他项目。任一方案都不把未经全切片独立验收的部分S1产品放到共享main。保护分支真正交付后PM才能按既有任务证据处理done。
4. **本项目配置切换**：单独展示旧配置fingerprint、精确四键差异和upgrade dry-run；用户逐命令授权备份和config transaction。source落地与config切换之间的行为变化/可能拒绝须纳入该执行窗口计划，不能承诺source落地无运行影响。保留limits/windows/identity/ledger；未完旧记录补合法category并由PM授权fresh接管，不改已完成历史。合法配置删未来类别不打断新格式完整同任务assignment。
5. **运行与共享采纳**：PM首次fresh、worker后续fresh/恢复分别预览授权，config更新本身不重启。若A先隔离，共享来源后来采用新完整源码也是单独授权步骤；installer、其他项目升级/服务操作各需其自己的盘点/确认。本change不代其他项目做配置/启停，也不建立自动扫描/部署系统；无installer不等于无shared source影响。
6. 回滚需同时回到对应source/config备份及已授权的共享链接隔离/采纳状态，不把新record强塞进旧resume；保留全部成果/历史并fresh交接。不能init --force恢复账本，不删除分支/会话。真正archive只在全部实施任务完成、独立验证和用户确认后进行；本阶段只在证据区scratch trial archive。
