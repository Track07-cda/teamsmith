# P228 · S1 私有源码返修候选

agent: dev   status: PRIVATE REPAIR CANDIDATE（作者自测通过，尚未独立复验）
最新受检产品/测试 tip：`fbc42f4`；S1 路由 857/0，源码反例 72/0。旧候选 `16842c9` 未被接收，不能沿用旧验收结论。返修细节、所有原失败和冻结移交记录见文末。本次仍是私有候选，不是 main 交付或上线。

以下旧报告原样保留，属于历史记录。

---

# P228 · S1 私有源码候选交付

agent: dev   status: PRIVATE CANDIDATE（未独立复验；BOARD 保持 wip）
产品代码冻结 tip：`ba783c7`；含完整测试矩阵的受检 tip：`017fbf9`。最新切片 245/0、反例 59/0，详见文末「最终受检交接」。下方原授权阻塞报告完整保留，是历史记录，不代表当前实现状态。

# P228 · 任务模型路由 S1：目录授权阻塞

agent: dev   status: PARTIAL   time: 2026-10-09
branch: `task/P228-task-model-routing-core`   PR/MR: -（local 模式，不推送）

交付类型：**S1 私有源码任务的阻塞报告**，不是实现交付、main 交付或上线成功。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P228-dev.md` | 授权缺口、代码调用链及已执行的只读输入检查 |
| `../pm-skills-ledger/team/reports/P228-dev/` | 仓外原始 OpenSpec 输出、引用检查、边界定位日志 |

输入 commit：`da89f842225679b501c9bfaf027e83d8c2706379`。起始分支正确，`git status --short` 为空。输出为本报告的独立 Conventional Commit；产品源码仍与输入 commit 相同，交付 tip 另记仓外 `delivery.log`。

已核对任务书、最新往来记录、OWNERSHIP、D101–D104、ACCEPTED 提案评审及 change 工件。原生 OpenSpec 的 context/status/apply 输出均指向 `.worktrees/dev`，没有改 store 选择或运行 init/update/install。

共享来源只读核对：`~/.agents/skills/teamsmith` 和 `~/.agents/skills/teamsmith-init` 仍分别指向主检出的 `skills/teamsmith`、`skills/teamsmith-init`。未改链接、主检出、真实配置、运行中的 PM/pulse 或任何会话历史。

## Decisions and deviations

**BLOCKED: PM 需要明确授权 `skills/teamsmith/scripts/lib/cmd-review.sh` 的 `team_cmd_close` 部分，或指定已获授权的 owner 完成该调用点适配。当前任务书未授权此文件，不能直接修改。**

证据与必要性：

1. change `tasks.md` 3.2 要求适配 close/teardown；`design.md` 决策 3 要求完整记录及 close/teardown 的锁顺序由核心 owner 一起适配。dispatch 的目标席位锁覆盖最终复核、替换窗口、proof 和 assignment publication。
2. 实际 close 入口在未授权的 `scripts/lib/cmd-review.sh:1309`。其 `:1357–1368` 先读取任务/window，`:1361` 直接执行 `tmux kill-window`，随后分别 `team_state_set "$a" task ""` 和 `team_state_set "$a" branch ""`。
3. 只在授权的 common `team_state_set` 中加锁不够：close 已先执行杀窗；与 dispatch 并行时可杀掉刚提交的新启动，随后清除新 assignment 的字段。逐字段清除也不符合完整记录的一次性生命周期处理。锁必须在 close 的身份最终复核及杀窗之前取得，覆盖记录清理，不能靠 setter 事后补锁。
4. 因而必须改 close 的调用点。没有通过在 common 重定义 close、推测调用栈等方式绕过目录授权，也未缩减已接受行为以制造交付。

在读代码阶段发现此硬阻塞，立即停止产品实施。未创建新 routing 入口、未改任何 delta 或 tasks 勾选；任务保持未完成。

## Verification evidence (must have actually been run)

命令全部从自己的 worktree 执行；OpenSpec 和引用检查使用 `timeout 90`。下述 background job `P228-input-checks` 已通过 `team_bg_wait` 收割。其脚本逐命令记录 rc；不能以脚本总体退出码替代每项结果。

```text
$ df -h /tmp
Filesystem  Size  Used  Avail Use% Mounted on
tmpfs        15G  2.4G    13G  16% /tmp

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
rc=0; root.path=.../pm-skills/.worktrees/dev; source=nearest; role=openspec_root

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change task-model-routing --json
rc=0; root.path=.../pm-skills/.worktrees/dev; source=nearest

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" instructions apply --change task-model-routing --json
rc=0; state=ready; root.path=.../pm-skills/.worktrees/dev; source=nearest

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rc=0; Totals: 14 passed, 0 failed (14 items)

$ bash skills/teamsmith/tests/spec-refs.sh --check
rc=0; spec-refs: judged 104 reference(s) (49 distinct) in 10089 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ git diff --check
rc=0（新增报告提交前另外再跑）
```

原始日志：`openspec-{context,status,apply,validate}.log`、`spec-refs.log`、`diff-check.log`、`boundary.log`，均在上述仓外 evidence 目录。

Verdict：输入检查通过；**实现未完成 / 授权硬阻塞**。不是核心功能通过。

### 明确未执行

- `config-cli.sh writer inject cas validate audit shape json groups models seats`。
- `routes.sh`。
- `death-cause.sh --pure`、`--live`、`--flip`。
- `task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary`（新入口尚未实现）。
- `ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"`。
- 全量 smoke、provider/Pi 模型质量、真实配置升级、真实 PM 重启。

这些项均是未跑，不是 skip/pass。硬阻塞终止路径不声称已执行完整验收。

## Scenario / adversarial coverage

本次没有实现或执行任何功能 scenario，不能用输入工件验证替代功能证据。

| S1 tasks / planned groups | 真实 assertion / captured argv / hashes / nonce | 结果 |
|---|---|---|
| 1.1–1.2 policy,machine | 无功能 assertion | NOT RUN |
| 2.1–2.3 config,upgrade | 无功能 assertion | NOT RUN |
| 3.1–3.5 dispatch,resume,transaction,limits,preview | 无功能 assertion | NOT RUN；close 调用点授权缺失 |
| 4.1–4.2 sid-readers | 无功能 assertion | NOT RUN |
| 5.1–5.3 pm,boundary | 无功能 assertion | NOT RUN |

所有对应 delta scenario 与 tasks adversarial control index 仍待实施、逐条映射并实际执行。未生成 recording-agent argv、policy/assignment/prompt/board mutation hashes 或 proof/锁日志，未将缺项表示成已有证据。

## Flip evidence (required for defect-fix tasks)

NOT RUN。未改实现，也未对 scratch 源码做受控翻转；本报告不宣称恢复缺陷已经修复。没有 red→green 功能证据。

## 冻结 / 释放清单

- 产品写集合：**无修改、无产品交付 tip、无新增冻结接口**。全部授权脚本、monitor 与测试文件仍为输入基线；不能把此报告作为 S2/S3 的实现依赖。
- `cmd-docs.sh` task/header、`cmd-bootstrap.sh` writer、`cmd-project.sh` CLI/help，以及 `common/cmd-config/cmd-agents/cmd-watch/cmd-status/cmd-death`：均未动，无文件向后续 owner 移交。
- `config-cli/routes/smoke/death-cause` 与 shared fixture helper：均未动；`task-model-routing.sh` 未创建。
- `tasks.md` 1.1–5.3 未勾，五份 S1 delta 未改；UI/init delta、canonical specs、公共治理账本未改。
- 本报告以外无 worktree 修改；所有后台作业已收割。没有 push/PR/merge/archive/done/close。

## Suggested next steps

PM 补齐 close 调用点的窄授权及其冻结移交边界后，重新派回 P228；继续使用当前长期 worktree/分支和同一输入基线。若由其他 owner 改 close，需先明确串行交接及输入 tip，不允许两个 owner 同时写。不得为解除阻塞改主检出产品或共享技能来源。

---

## 当前 S1 交付 · 2026-10-09

原 close 入口授权已由 PM 补齐；沿原 worktree/分支继续，保留 `be7f76f` 的阻塞证据。私有产品提交依次为 `147e233`（核心）、`9f4aeb9`（竞态及恢复反例）、`aa05f25`（PM 未提交进程回收）、`ba783c7`（升级失败审计）。产品输入仍为 `da89f842225679b501c9bfaf027e83d8c2706379`；主检出最新线程/brief 仅用于读取新增授权。

这是候选源码交付，不是完整 change 验收、保护分支交付或上线。任务书所列切片命令全部实际执行且 rc=0；仍需不同作者独立复验。未做 push/PR/merge/archive/done/close、普通 resume、重启当前席位、共享安装、真实配置升级或真实 provider 调用。没有改 canonical specs、UI/init delta 或治理账本。

### 实现与冻结接口

- `common.sh`：共享类别/模型校验、严格策略诊断、项目模型词表、数据式读取 assignment v1、SID 分配、席位/worker admission/config 锁、实际模型计数与 unavailable 诊断、SID 读源、原 PM 模型/身份守卫及元数据发布。assignment 不 source/eval；过去的完整记录还必须与当前进程证明 nonce 对应，才能用于 live 计数。
- `cmd-config.sh`：`set-task-model`、显式四键 `upgrade-models`、未来策略与实际 assignment 的 JSON。CAS 比较配置**原始字节**，失败/冲突审计一次。升级只接受可直接确认的单行字面赋值，拒绝动态/导出/条件/重复形态。
- `cmd-agents.sh`：唯一类别头、新选择/显式覆写/同任务恢复、完整模型及 suffix 的 fresh 守卫；启动证明后才原子发布 assignment，BOARD 后失败不撤销已提交启动。close/teardown 与 dispatch 共用席位锁；最终复核配置、brief、branch、worktree 和 nonce。
- `cmd-docs.sh` 提供类别生成；`cmd-bootstrap.sh` 保留字节/注释的 hardened writer；`cmd-project.sh` 仅必要 help；`cmd-review.sh` **仅 close 入口**，没有改 review/gate/merge 路径。
- `cmd-watch.sh/cmd-status.sh/cmd-death.sh/monitor.mjs` 读取 committed assignment/SID，缺失或不可验证时 unavailable，不以最近邻会话或未来策略冒充实际身份。monitor 仅 S1 数据/读源改动，不是 S2 UI 交付。

供后续 owner 消费的 CLI 是 `config list --json`、`config set-task-model <category> <model>` 和 `config upgrade-models --task-models <map> --pm-model <model>`。JSON 的 `models.policy.categories` 为 `{category,model}` 有序行，`policy.pm` 独立；`assignments` 每席一行，完整记录含 task/category/model/selected_via/launch_via/sid，不完整为 assigned=false、空字符串及 diagnostic；`pm_launch` 独立；`known` 仅项目策略和已提交记录的有序去重词表。不再提供 seat/default 路由。

assignment v1 包含 task/taskfile/category/branch/worktree/window/seat/model/selected_via/launch_via/sid/launch_nonce/started/sid_bytes/mode。`team_assignment_load` 在调用方返回 `TEAM_ASSIGN` 和诊断，不执行记录。外部状态不得按字段拼造一半 assignment。

### 实际证据

证据根 `E=../pm-skills-ledger/team/reports/P228-dev`，上一轮受检 tip 在 `E/frozen-tested-tip.txt`，对应作业日志为主检出 `.pi/team/state/bg/P228-frozen-final-gates.log`。

`E/frozen-routing-evidence/teamsmith-task-model-routing.EAVxHP/trusted-assignment` 的实际记录为：

```text
assignment_version=1 task=T1 category=routine
model=vendor/strong:high selected_via=explicit launch_via=explicit
sid=routing-fixture-dev-1791541625-2650748-20413-4449
launch_nonce=1791541625-2649921-12188-14264-1 mode=fresh sid_bytes=0
```

同目录 `argv.log` 是隔离 recording agent 的真实进程 argv：provider 为 vendor、模型为 strong:high、SID 为上述 A。删除未来 routine 映射后，`resume --dry-run`、`resume`、同任务 dispatch 仍保留该完整模型/SID；新 routine 任务即使 override 也拒绝。恢复启动来源为 assignment，初选来源 explicit 不重标成 policy。改变 suffix 必须 fresh；fresh 产生不同 SID。

PM publication 测试在私有 socket 的 pm 窗口实际 respawn，再注入 rename 失败：旧 metadata 哈希保留、诊断先落盘、PID/proof 清理、仅本次未提交窗口被停止。running/starting 的控制臂不 respawn。记录桩证明参数、进程/文件和 Teamsmith 状态，**不证明**真实 Pi/provider 推理质量、消息转换或上下文兼容性。未读取真实会话或凭据。

### 命令与输出尾部

下列命令均在稳定 `ba783c7` 树执行，期间没有提交或写入工作树；后台作业已收割。`O=$HOME/.bun/bin/openspec`，本机用 `$HOME/.bun/bin/bun "$O"` 执行原生 CLI。

| 实际命令 | 输出 / rc | 原始日志 |
|---|---|---|
| `bun "$O" validate --all --strict` | 14 passed / 0 failed；0 | `E/frozen-openspec.log` |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs / retired 0 / undeclared 0；0 | `E/frozen-spec-refs.log` |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 169/0，顶层 SKIP 0；0 | `E/frozen-config.log` |
| `bash skills/teamsmith/tests/routes.sh` | 207/0，SKIP 0；0 | `E/frozen-routes.log` |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 87/0；0 | `E/frozen-death-pure.log` |
| 同脚本 `--live` / `--flip` | 7/0 / 4/0；均 0 | `E/frozen-death-live.log` / `frozen-death-flip.log` |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 231/0；0 | `E/frozen-routing.log` |
| 同脚本 `--select flip` | 59/0；0；11 个坏源码臂各 rc=1 | `E/frozen-flips.log` |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$MAIN/.pi/team/forbidden-names.txt"` | files=1310 hits=0 names=ok；0 | `E/frozen-ledger-ban.log` |
| `git diff --check` | 无输出；0 | `E/frozen-diff.log` |

config 日志中一个嵌套 preview 控制显示 SKIP 1，顶层 SKIP 0；不把它说成独立完整功能验收。命令驱动对测试设置独立 timeout，证据导出使用 `TEAM_ROUTING_EVIDENCE`。已重新完整 read 主检出 SKILL.md 并运行 `team version --check`，原始结果 `E/version-final.log`（v0.1.1）；没有按旧技能指引重启席位。

### S1 场景 → 实现 → 断言索引

以下对应接受 delta 中的新核心场景，不另立要求。名称相近的控制共用同一组；具体 PASS/FAIL 名称及 CLI stdout 在 routing 日志，遗留前门在上表。结果是自测，不是独立验收。

| 场景 | 实现位置 | 断言 / 结果 |
|---|---|---|
| category 缺失/空/重复/非法，override 不豁免；类别不由席位或 phase 推断 | cmd-agents/cmd-docs | `category-explicit-phase-independent:*`、`phase-does-not-infer-category:*`；PASS |
| override 仍要求新选择类别已映射 | cmd-agents | `new-unmapped-category-override-refused`、no-board/no-assignment；PASS |
| 自定义映射、生成必须有合法映射 | cmd-docs/cmd-config | `generated-mapped-category`、`generated-category-header`、`generation-refused:*` / no-file；PASS |
| override/fresh 经过恢复入口仍保留身份 | cmd-agents/common | `resume` 组 model/SID/provenance 与 argv 断言；PASS |
| 删除未来类别不改变完整旧 assignment，新选择仍拒绝 | cmd-agents/cmd-config | `deleted-routine-recovery`、实际 resume、JSON 与新任务拒绝断言；PASS |
| 非法整体策略或变更 task/category/file/worktree/branch 不获得类别删除豁免 | common/cmd-agents | `untrusted-recovery-refused:*` 及策略拒绝控制；PASS |
| 全模型/suffix 变更要求 fresh，同模型 fresh 也唯一 | common/cmd-agents | suffix 拒绝、同秒两次 fresh、强制 SID 碰撞重试；PASS |
| 未可信、半记录、legacy、缺失身份拒绝恢复 | common/cmd-agents | `untrusted-recovery-*`；PASS |
| dry recovery/preview/refusal 不写模型、SID、nonce、prompt、窗口、BOARD | cmd-agents | preview/resume/transaction 的哈希及无启动控制；PASS |
| 证明/发布失败保持旧 tuple、不发布半记录 | cmd-agents/common | failure-before-proof、rename 注入、完整 assignment、旧记录哈希控制；PASS |
| 中断 before/after rename 可区别，live proof nonce 不匹配不是旧模型 | cmd-agents/common | transaction interruption/pending/nonce 断言；PASS |
| 同席争用、close/teardown 与 dispatch、最终 config/brief/branch 快照 | cmd-agents/cmd-review/common | transaction race、final snapshot、`close-no-identity-resurrection`；PASS |
| BOARD 写失败不撤销已提交启动 | cmd-agents | transaction BOARD 故障与 committed record 控制；PASS |
| 实际模型 exact/wildcard/zero/replacement 计数；跨席最后一格竞争 | common/cmd-agents | limits slot/race/桶/替换断言；PASS |
| live unknown peer 在正限制下无法判断，force/preview 不绕过；dead/absent/PM/unlimited 对照与停/fresh 修法 | common/cmd-agents | limits unknown-family、非 live 对照、项目内修法与重试；PASS |
| extras 的 model/provider/session/continue 不与记录矛盾；无害 extras 允许 | common | `boundary-reject:*`、`boundary-harmless`；PASS |
| legacy/mixed 新选择拒绝，维修入口可达；retired 入口不再写席位模型 | common/cmd-config/cmd-agents | policy/retired 路由、config models/seats、routes；PASS |
| map 域规则和 PM 独立 | common/cmd-config | policy/machine/pm 组；PASS |
| 单 token upsert、同指纹同时写与 loser、不执行调用者 shell text | cmd-config/cmd-bootstrap | `simultaneous-map-cas`、`writer-payload-does-not-expand`、roundtrip；PASS |
| 显式升级 preview 不写，成功整份替换、保留无关字节/注释 | cmd-config/cmd-bootstrap | `upgrade-preview-*`、`upgrade-commit`、retired/comment 控制；PASS |
| 升级分配/复制/第二字段/语法/rename 故障与 stale/late CAS，清理且一次正确审计 | cmd-config | `upgrade-whole-file-fault:{alloc,copy,render,syntax,rename,stale-cas,late-cas}`；PASS |
| 导出/动态/条件/重复源拒绝且可修正 | cmd-config/common | `upgrade-refuse:*` / `upgrade-no-write:*`；PASS |
| JSON 未来策略/实际身份分离，category 删除仍完整，空/legacy 不伪造默认，known 不取机器 catalogue | cmd-config/common/monitor | machine/resume 组 JSON 断言、config shape/json/groups/models；PASS |
| SID A 与更近 B/base 不能串源，A 缺失不回退，zero bytes/后续增长是真实读数 | common/cmd-death/monitor | `reader-session-A`、`reader-cause-A`、`reader-missing-A-no-B`、growth、monitor unavailable；PASS |
| 无记录/unknown/stopped source 不冒充实际；分类死因及 bounded reader 不退化 | common/cmd-death | sid-readers + death pure/live/flip；PASS |
| PM 独立 provider/model/suffix，未知或变化要求显式 fresh | common/cmd-watch | `pm-independent-model`、known/unknown/suffix/resume-selector 及 extras；PASS |
| running/starting PM 保持受保护，失败 publication 不是成功启动证明 | common | `pm-running-not-respawned`、`pm-starting-not-respawned`、`pm-publication-failure-stops-uncommitted`；PASS |
| 启动参数与记录一致，Pi 隐藏推理/消息兼容不是 Teamsmith 能力 | common/cmd-agents | argv/full-suffix/assignment/boundary；参数断言 PASS；guidance 成品由 S3 交付 |

覆盖边界：未运行真实 provider/Pi 会话质量；未运行完整 UI/初始化/文档 smoke 或独立 review。原先缺少的 upgrade missing-args、显式 multiline、无末尾换行、audit-unwritable 及多读者观察**升级**过程专用矩阵，现已在 `017fbf9` 补齐并通过，详情见最终受检交接；不以通用 writer 覆盖冒充逐项新验。PM running/starting 控制替换了事实查询函数；publication 回收使用真实隔离 tmux 窗口，不声称真实生产 PM 已被测试。

### Flip evidence · 原失败保留、坏源码判红、恢复判绿

1. 原 `routes-final.log` 的 rc=1 是变异匹配旧源码、未实际落地；仅改 scratch 定位，保留原失败日志。现 routes 的 10 组 refusal 对照 207/0，控制臂同树保持绿。
2. 原 `routing-flips.log` 的 unmapped 反例落在 dispatch 子组，却只在 resume 子组有目标断言。补 dispatch 的 `new-unmapped-category-override-refused`，当前 scratch 坏源码必为 rc=1，不能以 override 越过映射。
3. `E/frozen-flips-evidence/teamsmith-task-model-routing.KY6Cpy/` 包含每个 `mutation-*.json` 的 matched=1 / before / after 字节哈希和 `flip-*.log`。11 种真实 scratch 破坏：unmapped-override、fingerprint、expanding-quote、recovery-drift、partial-publication、unknown-as-zero、latest-shell、latest-monitor、pm-fallback、pm-publication、extra-shadow；全部 rc=1，命中具名 guard。每臂原目录哈希恢复一致；整体 baseline/restored 均 rc=0，231/0。顶层反例驱动 59/0。
4. 升级真实 red→green：`E/upgrade-before.log` 为 21/3（alloc/copy 少审计、late-CAS 标错），`E/upgrade-after.log` 为 24/0；受控失败保留配置字节，删除临时文件，一次且如实审计。最终冻结树再全组复跑。没有删除或 skip 原错误来造绿。

独立复验包位置：`E/frozen-routing-evidence/`、`E/frozen-flips-evidence/`、上述 frozen 日志及 tested tip。这里由作者生成，**不是独立复验结果**；PM/不同 verifier 必须另 checkout 运行。

### 尚未完成 / 冻结交接

- 不宣称完整仓库绿。附加旧全组 config-cli 曾为 311/21；未迁移的 completeness/register/callers/dispatch-sync 仍期望 `add-agent --model`、`TEAM_AGENT_MODELS` 和 `models.seats` 等退休合同，任务书所列迁移组为 169/0。原失败日志 `E/config-tip.log`；这不是最终 tip 的全组复跑。S3 的初始化/教程及 completeness/docs/callers/模板 smoke 尚未迁移；不跳过或弱化它们来冒充完整验收。
- 冻结产品 tip `ba783c7`。`common/cmd-config/cmd-agents/cmd-watch/cmd-status/cmd-death/cmd-review close/monitor` 核心接口及上述 assignment/JSON 结构供 PM 私有接收；**PM 尚未记录 RECEIVED，不授权其他 owner 并发写核心**。
- 待 PM 明确串行移交给 S3：`cmd-docs.sh` task/header、`cmd-bootstrap.sh` writer、`cmd-project.sh` help，以及 `tests/config-cli.sh/routes.sh/death-cause.sh/lib/model-policy.sh/task-model-routing.sh/lib/model-routing-flips.py` 的共享部分。没有改 smoke 主脚本；现有改动是 fixture 输入与真实 guard，后续 owner 应保留断言及反例。S2 仅可按 PM 接收的接口读取，不自行修改本核心。
- 接受的五份 S1 delta 未改，tasks.md 仍未勾；避免把未接收的交接或完整 apply 标成完成。S1 的补充测试矩阵现已完成；PM 据 coverage 记录串行阶段交接，本报告不代替独立范围验收。UI/init/完整 rollout/真实共享源与 config 采纳仍全部 NOT RUN。
- 本轮新登记后台作业均收割。工作仅在长期私有 worktree 与 owned 临时根；没有改共享链接、main、实际模型/SID/config，未触发远端 CI。继续交付或不同作者复验均需保持 D104 的非部署边界。

### 最终受检交接 · 017fbf9

生产代码保持 `ba783c7`；`017fbf9` 只补测试。之前冻结命令/日志/argv 与失败证据原样保留，上表是 ba783c7 的运行，不混充新 tip。最新同一批切片命令在稳定 `017fbf9` 全部重新执行，完整后台日志为主检出 `.pi/team/state/bg/P228-handoff-gates.log`，受检 tip 为 `E/handoff-tested-tip.txt`。最终报告是后续纯报告提交，不改变受检产品或测试字节。

| 最新结果 | 日志 |
|---|---|
| OpenSpec 14/0；spec refs 104 / retired 0 / undeclared 0 | `E/handoff-openspec.log` / `handoff-spec-refs.log` |
| config 指定组 169/0；routes 207/0 | `E/handoff-config.log` / `handoff-routes.log` |
| death pure/live/flip 87/0、7/0、4/0 | `E/handoff-death-{pure,live,flip}.log` |
| routing 全部 S1 组 245/0 | `E/handoff-routing.log` |
| 源码反例 59/0；baseline/restored 均 245/0；11 个破坏臂各 rc=1 | `E/handoff-flips.log` |
| ledger-ban hits=0 / names=ok；diff 无输出 | `E/handoff-ledger-ban.log` / `handoff-diff.log` |

以上全部 rc=0，最终总项 `HANDOFF overall=0`。最新原始 fixture/argv/完整身份和 hash 为 `E/handoff-routing-evidence/teamsmith-task-model-routing.MqoXor/`；最新 scratch 变异/具名 FAIL/恢复字节 hash 为 `E/handoff-flips-evidence/teamsmith-task-model-routing.Lf5urp/`。

新增逐项索引：

- `upgrade-input-refused:{missing-map,missing-pm,invalid-pm,invalid-map}` 及同名 `input-pure`：缺参/非法模型/重复 map 拒绝，配置字节不变。
- `upgrade-refuse:TEAM_DEFAULT_MODEL="x/y\nx/z"` 与 no-write：多行源在 sourcing/替换之前拒绝。
- `upgrade-no-final-newline-commit` / `preserved`：完整升级成功、无关末尾行原字节且没有末尾换行。
- `upgrade-audit-unwritable-honest-committed-result`：config.log 故意成为目录，审计写失败诊断可见；已完成的有效配置提交不伪装失败回滚。
- `upgrade-readers-wholly-old-before-rename-new-after`：真正后台 writer 在 temp 只渲染完 task map 时暂停，10 个独立 Bash reader 读取旧原子配置、语法及旧 map/PM/legacy tuple；放行 rename 后读取完整新 map/PM 且旧键全部缺失。不是只在写前写后各扫一遍。

定向补验为 `E/upgrade-matrix-corrected.log` 的 38/0；最初矩阵日志保留在 `E/upgrade-matrix.log` 的 37/1，失败是 reader 把其他 select 组合的 map 字面量写死，现改为写前捕获实际旧 tuple 后逐次比较，没有降低原子性断言。两条原恢复失败、升级 3 红→绿和全部源码变异证据仍保留。

交接给 PM 的私有候选是 `017fbf9`（连同随后这份报告提交）；code/API/SID 记录接口与上文冻结清单一致。PM 接收前不释放给其他 owner 并发写、不自行 dispatch S2，不把 private candidate 标为完整 apply done。当前不是硬阻塞；等待 PM 的独立复验与私有 RECEIVED/串行移交，不请求真人执行共享操作。

旧作业收割例外已核验：技能 reload 后对 `P228-acceptance-flips` 调用 `team_bg_wait` 返回 `unknown job (this session started: (none))`，没有伪称工具收割成功。逐项读取其 durable job/log，原 routes rc=1、routing-flips rc=1，其他命令均 rc=0，与旧 exit=1 唤醒一致；PID 1788442 已不存在。原记录原样保留，副本为 `E/reload-orphan-acceptance.{job,log}`。没有重启席位或修改 extension/共享 job 状态来绕过丢失句柄；随后各重跑作业均由工具正常收割，当前没有待运行的旧进程。这是 reload 后旧句柄不可达的工具限制，不是忽略原红或将其计成通过。

---

## S1 返修交付 · 2026-10-09 · fbc42f4

### 结论、输入与授权边界

旧候选 `16842c9` 的独立检查未通过。本轮针对启动参数所有权和完整 assignment 读侧校验分叉返修；原报告、旧门禁和本轮所有失败日志保留，不将它们改成通过。

输入为 `16842c9`，分支始终为 `task/P228-task-model-routing-core`。三步提交：`3f80d40`（启动身份及共用解析器）、`20214ef`（PM 有界快照和新反例）、`fbc42f4`（无 GNU 专用参数的校验及组合夹具前提）。受检源码/测试 tip 为 `fbc42f4`；之后的报告提交不改变产品或测试。报告提交的完整 delivery tip 另写仓外 `repair/delivery.log`。

当前仅作者自测完成，等待不同作者独立复验及 PM 的私有 RECEIVED。没有 push、PR/MR、merge、archive、done/close、自行调度、共享安装、真实配置升级或实际 PM 重启。未改治理账本、canonical specs、delta、tasks 勾选或 S2/S3 文件；PM 的非部署 integration clone 未触碰。

本轮改动集合为以下六个源码/测试路径及本报告，其余原 S1 文件保持旧候选字节：

| 路径 | 返修内容 |
|---|---|
| `scripts/lib/common.sh` | 字面 argv 所有权检查；完整 assignment 数据解析；worker/PM 共用 64 KiB 有界、拒绝 NUL 的快照；完整日历及 canonical 路径检查 |
| `scripts/lib/cmd-agents.sh` | 恢复预检也调用相同模板守卫，拒绝发生在 nonce/prompt/窗口/BOARD 等启动副作用前 |
| `scripts/monitor.mjs` | 将捕获的数据交给同一 Bash 解析器，不再维护第二套较宽松的完整记录校验 |
| `tests/task-model-routing.sh` | 接入新矩阵与两个新源码翻转，保留原分组及原反例 |
| `tests/lib/model-routing-boundary.sh` | 新的实际 argv、纯拒绝、合法控制、29 种 assignment 损坏及 13 种 PM metadata 损坏夹具 |
| `tests/lib/model-routing-flips.py` | 真正关闭模板守卫、篡改 monitor 所读 nonce 的受控源码翻转 |

上表脚本路径均相对 `skills/teamsmith/`。没有改通知渲染、placeholder 词表、内建 extension/skill 集合、PID/nonce 启动证明或 Pi/provider 消息接口。

### 两处缺陷的修复与证据索引

1. **模板中的参数也必须受启动身份守卫约束。** 预检和最终渲染使用同一检查；provider/model/session 选择器必须绑定相应未加引号的占位符，拒绝硬编码、错配、重复、拼接、隐蔽脚本词及不可证明的 shell 执行形态。worker continuation 必须消费完整 provider/model/SID；PM 真正声明 continuation 时必须消费 provider/model/resume 参数。没有增加非 Pi 兼容承诺。
2. **完整记录只采用一份类型校验。** CLI、模型计数、SID 大小/死因读源继续使用共用 assignment loader；monitor 直接使用相同解析器验证它捕获的字节。nonce/SID、键及重复项、版本、category/model、来源/模式、字节计数、canonical 绝对路径、完整 UTC 日历时间、缺字段、空行及 NUL 的判定一致。失败为 unavailable/unassigned，不取最新 B/base 或未来策略冒充已启动身份。PM metadata 同样拒绝坏时间、nonce、重复/空行、NUL 和超长数据。

| 场景/控制 | 真实 assertion 前缀 | 日志与结果 |
|---|---|---|
| worker 硬编码/错绑/重复/隐蔽选择器；继续与 fresh，preview 与实际尝试 | `template-refused:*`、`template-pure:*` | `handoff-routing.log`，PASS |
| worker 缺失 SID 或省略 provider/model 不允许精确恢复；force 不豁免 | `template-refused:missing-sid-selector:*`、其余同组 missing/misbound 臂 | 同上，PASS |
| 分离、等号、短参数、短参数附着、带引号的无害 extras；完整多 slash 模型与 suffix/SID | `template-legal-*:{separate,equals,short,attached,extras}` | 同上，真实 recording argv，PASS |
| PM 硬编码 provider/model/SID、会话/继续参数、错绑及隐蔽脚本，print/启动均早拒绝 | `pm-template-refused:*`、`pm-template-pure:*` | 同上，PASS |
| PM 独立模型，已知 custom continuation，builtin 同模型继续；不消费 resume 的冻结接缝诚实说明失去历史 | `pm-template-legal-*`、`pm-custom-known-continue-*`、`pm-custom-continue-argv`、`pm-custom-missing-resume-*`、`pm-builtin-known-continue-*` | 同上，PASS；custom continuation 使用明确准备的可信 fixture metadata，不冒称实际 Pi 历史恢复 |
| 29 种坏 assignment，每臂都检查 Bash、size/death source、monitor、machine JSON、无读侧写入和恢复后的 A | `reader-record-rejected:*`、`reader-size-unavailable:*`、`reader-death-unavailable:*`、`reader-monitor-unavailable:*`、`reader-machine-unassigned:*`、`reader-record-unmodified:*`、`reader-restored-*` | 同上；`reader-matrix.log`、`reader-monitor-*.json`，全部 PASS |
| 13 种坏 PM metadata：读取、继续守卫、JSON、记录不变、恢复控制 | `pm-metadata-{rejected,continue-refused,machine-unavailable,read-only,restored,restored-continuation}:*` | 同上，全部 PASS |
| 禁用 date/readlink 仍可校验有效时间/记录，非法日历及 alias 仍拒绝 | `pm-record-calendar-without-date`、`reader-record-without-GNU-normalizers` | 同上，PASS；另有 `portable-data-probe-corrected.log` 的 6 有效路径、7 无效路径、9 时间、1 完整记录控制 |

29 种 assignment 臂是 nonce、SID、seat、window、category、空 branch/task、taskfile/worktree 的相对路径/点段/symlink、坏时间/日期、四类坏模型、坏键、重复、空行、版本、sid_bytes、selected_via、launch_via、mode、缺字段、NUL。每臂均恢复原始记录并再次证明 monitor 读取 A。13 种 PM 臂是 nonce、NUL、坏时间/日期、模型、project、window、版本、mode、缺字段、重复、空行、oversized。GNU 工具替代测试不是实际 macOS 端到端测试；未作此平台通过声明。

冻结接缝保留两项明确边界：新/fresh 的 opaque custom 不因此获得精确历史兼容承诺；PM 的 `{resume_args}` 缺失时仍按已接受 spec 报告“不继续/参数不会带上”，而不是假称 continuation。writer 已早拒绝的危险模板臂记录 rc=4 和纯拒绝，不将其冒充已执行 renderer/launcher。

### 实际 argv、完整身份与拒绝前后 hash

证据根 `R=../pm-skills-ledger/team/reports/P228-dev/repair`。实际路由 fixture：`R/handoff-routing-evidence/teamsmith-task-model-routing.eKm1oZ/`。

`trusted-assignment` 是实际录制启动的完整记录：`model=vendor/strong:high`、`selected_via=explicit`、`launch_via=explicit`、`mode=fresh`、`sid=routing-fixture-dev-1791563462-3924314-15418-25762`、`launch_nonce=1791563462-3924029-12860-14313-1`、`started=2026-10-09T16:31:02Z`。`argv-jsonl` 第一行的 provider/model/SID 与它逐字段一致；扩展/skill 与 briefing 全参数也在原文件，而不是仅字符串预览。

多 slash 控制的实际参数为 `--provider vendor --model deep/model:high --session-id routing-fixture-dev-1791563476-3950318-3202-3028`；PM 的实际独立记录在 `pm-fresh-control-record`：`model=vendor/pm:high`、`mode=fresh`、`nonce=1791563544-4128159-30046-14955`。合法模板/短参数/extras 与 PM continuation 的具名断言直接读 recording 进程的 JSON argv。录制器通过原 launcher 的 login bash、实际 configured PATH、私有 tmux 启动，不是 mock 渲染结果。

硬编码模板第一次 preview 早拒绝（rc=1）。`effect-hashes.log` 中该次 before/after 的 8 个文件 hash 全部相同，示例：

```text
policy/config 06e4e4f9f8fb4b0ca955b7ac97e7799eefe365b487e8ae751650f272c98bffb6
assignment    fcdac69c66689bdc2cc122d3df528e8e5856001ff7251a6836c279c1e1393a64
prompt        d5cc9348d4333dc27aa6cdff2ff2700a349eb13847249e86c569a76607f72097
BOARD         3b167488febba70a6370fdd8589f2522f3a9adabe1453759b64cfccfe8a4bd96
```

摘要保存在 `R/evidence-summary.json`；原每次 CLI before/after hash、launch nonce/proof/lock 输出和捕获 argv 都在上述 fixture。新的 pure 断言还比较所有 state 文件的内容/mtime、config、BOARD、argv 日志、窗口/pane/PID 及 worker git status 的聚合快照，拒绝不得写入或换窗。

### 最终验收命令与输出尾部

从自己的长期 worktree 启动 `R/run-final.sh`；它 clone 已提交 `fbc42f4` 到 owned `R/handoff-source`，然后在这棵稳定的私有来源上执行以下命令。所有产品 CLI 都在脚本断言的独立 repo/HOME/socket fixture 中运行，不以该来源或实际团队作为 config/dispatch/up 目标。原生 OpenSpec 输入定位已在 onboarding 验证为自己的 worktree；未更改全局 store。

后台 `P228-repair-handoff-gates` 已经 `team_bg_wait` 收割，exit=0；driver 的 `source stable=yes`、`FINAL overall=0`。完整 HEAD 在 `R/handoff-tested-tip.txt`。原始日志统一为 `R/handoff-<tag>.log`，每项 rc 另存同名 `.rc`；driver 是 `R/handoff-driver.log`。

| 实际命令 | 尾部 / rc | tag |
|---|---|---|
| `df -h /tmp` | 约 13 GB 可用；0 | space |
| `bun "$HOME/.bun/bin/openspec" validate --all --strict` | 14 passed / 0 failed；0 | openspec |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs，retired 0 / undeclared 0；0 | spec-refs |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 169/0，顶层 SKIP 0；0 | config |
| `bash skills/teamsmith/tests/routes.sh` | 207/0，SKIP 0；0 | routes |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 87/0，SKIP 0；0 | death-pure |
| 同脚本 `--live` / `--flip` | 7/0 / 4/0，SKIP 0；均 0 | death-live / death-flip |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 857/0；0 | routing |
| 同脚本 `--select flip` | 72/0；baseline/restored 各 857/0；0 | flips |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | hits=0 / names=ok；0 | ledger-ban |
| `git diff --check` | 无输出；0 | diff |

这里 `bun` 实际使用 `$HOME/.bun/bin/bun`。timeout 为 OpenSpec/refs 90s、config 240s、routes 600s、death 各 120s、routing 900s、源码 flips 2400s、ledger 120s；没有超时。config 的嵌套 JSON/preview 控制输出 SKIP 1，顶层 SKIP 0，未隐去。全量 smoke、UI/init、真实 provider/模型质量、SDK reasoning/message 兼容、生产 PM 和实际配置升级均 NOT RUN；这不是完整 change 验收。

### Flip evidence：真正破坏源码、具名红、恢复再绿

最终包为 `R/handoff-flips-evidence/teamsmith-task-model-routing.D3sWbk/`。保留原 11 臂，再新增 2 臂；13 臂都在带 owner marker 的 scratch source 中实际修改、shape 检查通过、真实 fixture 运行 rc=1、脚本字节 hash 恢复相同。baseline/restored 都 rc=0、857/0；顶层 72/0。

| 新破坏 | 坏源码实际结果 | 必须命中的具名失败 | source_before = source_restored |
|---|---|---|---|
| `template-shadow`：把共用模板所有权守卫改为 return 0 | boundary 251/184，rc=1 | `template-refused:all-hardcoded:preview`、`pm-template-refused:provider:launch` | `b91eda9b36106fb8beab4b137e9526e8d1bf8fad9e89f266d5bac121114cdff0` |
| `monitor-record-drift`：monitor 在校验前将 malformed nonce 偷换成合法 fixture nonce | sid-readers 243/2，rc=1 | `reader-monitor-unavailable:nonce` | `2afba45b1e5f773b6f61f5b0c4f6ce336b787187f8ef9fbc8008619552951051` |

新臂有专门的具名断言检查，不只 grep 任意 FAIL。`mutation-*.json` 记录唯一 matched=1 及所改文件 before/after SHA；`flip-*.log` 保存真实错误和 argv/状态；`flip-evidence/` 是各控制臂的原 fixture。旧的 unmapped、CAS、quote、recovery、publication、unknown-count、latest-source、PM 和 extras 反例全部重新执行，不以新矩阵替代。

### 本轮原失败原样保留

- `R/red.log`：首版探针在旧源码 246/96；`R/green.log` 为 318/24。其中 machine JSON 的 fixture 错把 `agent` 写成 `seat`，不能把这部分当产品红。修正后 `R/red-final.log` 为 317/105（rc=1），同组 `R/green-final.log` 为 422/0（rc=0）。更大的矩阵随后扩到 568/0、674/0，最终不是沿用早期数字。
- PM 子夹具停止最后一个窗口会让私有 session 消失，影响后面的原 publication-failure 控制；加独立私有 anchor 保持测试前提，不改产品清理/停止行为。
- `R/step-two.log` 657/15：新 Python argv 检查误用了 shell 单引号，以及 config set 的值以 `-` 开头被选项 parser 拒绝。改正确引号及已支持的前导空格值，增加 setter rc 前提断言。`R/step-two-fixed.log` 671/3：错误地把 PM 缺 `{resume_args}` 的已接受 lost-history 分支写成拒绝，改按 spec 实测“不继续”与真实 argv 没有 continue；`R/step-two-green.log` 674/0。
- `R/final-routing.log` 847/6、`R/final-flips.log` 2/1、`R/final-driver.log` overall=1，都是稳定 `20214ef` 的真实失败：resume 分组已经删除未来 routine 映射，新模板探针却要作显式新选择。夹具现在自己建立并恢复映射，不放宽新选择/override 必须映射的产品守卫、不改原 resume 场景。组合重跑 `R/combined-fixed.log` 711/0；最后 `fbc42f4` 完整重跑才为 857/0、72/0。
- `R/portable-data-probe.log` rc=1、`portable-data-debug.log` 记录 standalone probe 自己用了带 `..` 的 staging 路径并漏 source model helper；规范化 scratch 根并按实际 monitor 同样 source common/cmd-config 后，`portable-data-probe-corrected.log` 23 个控制通过。最终正式矩阵也验证这一前提。不是实际 macOS 测量。

这些原失败没有删除、覆盖或宣称通过。全部本轮背景作业均已收割，最新 stable clone 的 HEAD/status 从开跑到收尾相同。

### 冻结/释放与下一阶段

本轮最新冻结源码/测试为 `fbc42f4`，接口形状和 assignment v1/CLI JSON 结构不变。PM 接收前没有释放给任何下一 owner 并发写；不自动恢复席位、派单、集成或上线。

- `common.sh`、`cmd-agents.sh`、`monitor.mjs`：核心读/写/渲染冻结，S2 只读消费同一 JSON/记录语义，不维护第二套完整记录规则。
- 新 `tests/lib/model-routing-boundary.sh`、`tests/lib/model-routing-flips.py`、`tests/task-model-routing.sh`：本轮矩阵与全部反例冻结；后续迁移夹具必须保留这些断言和有界/不可执行数据前提。
- 原 S1 的 `cmd-config/cmd-watch/cmd-status/cmd-death/cmd-review close` 及锁/事务接口：本轮未改，连同最新核心作为同一私有候选，不拆出旧未接收 tip 当依赖。
- `cmd-docs` header、`cmd-bootstrap` writer、`cmd-project` help、config/routes/death fixture 与 `lib/model-policy.sh` 仍由 PM 明确串行借给 S3；本轮没有写这些路径。UI/init delta、教程、模板、公共账本均不释放给自己处理。

现阶段没有授权硬阻塞；交付等待独立复验，不能由作者把私有自测结论提升为 RECEIVED、完整 apply done 或保护分支采纳。

## 追加：F3 shell 展开与 literal argv 同源修复

### 结论与边界

最新已验源码为 `d823c7e497a621538dc697e782344f5814ff3dca`，本地私有候选 **SELF-PASSED，未 RECEIVED**。全部任务书验收命令与 16 臂源码翻转已跑完；没有 push/合并/远端 PR/安装/部署/恢复实际席位/修改真实团队配置。上一轮报告及原失败全部保留，旧 `fbc42f4` 自测不抵消 V19 失败。

最新 thread、任务书、V19 报告和 D112 为范围依据；读取 accepted proposal、对应 capability/delta specs。原生 context/status/instructions apply 定位自己的 worktree，输出归档 `G/openspec-{context,status,instructions}.json`，未改全局 store。`G=../pm-skills-ledger/team/reports/P228-dev/glob-repair`。

无授权硬阻塞；整体 change、S2 UI、S3 init/docs、full smoke、真实 Pi/provider/模型质量/SDK compatibility 仍 NOT RUN。未标记完整 apply done 或宣布下一 owner 解冻。

### 根因与修改

F3 是 ownership guard 校验配置字面词，而 launcher 执行 shell 展开后的实际 argv。私有 cwd 文件 `--model=wrong:low` 使 `--mod*` 在真实 login bash 启动后变成第二个 model selector；provider/SID/continue/resume 同类。`"--mod"*` 不是全引用 literal；brace/tilde 同样改变词。不能执行配置来猜 argv。

- `common.sh::team_literal_argv` 早拒绝未引用的 `* ? [ ] ~` 及非已知 placeholder 的 braces。保留既有 placeholder；引用内 wildcard/brace/tilde 是 literal。double-quoted backslash escape 保守拒绝，并指导用 single-quoted literal。没有新增 eval、配置执行、Pi reasoning/message/provider 转换或兼容矩阵。
- `cmd-agents.sh::team_pi_args` 和 `common.sh::team_pm_pi_args` 消费同一 lexer 的 tokens，再逐参数 `%q` 输出，不再把原配置字符串 word splitting/glob 二次解释。worker 构建失败传回 launcher。builtin worker/PM 以及 PM resume 的 quoted 空格/反斜杠/quote 语义与 guard 一致。
- CLI/state/schema/model routing/事务/锁/fresh handoff 接口不变；没有改 S2/S3 实现路径。

### 契约对应的新断言

| 原契约/风险 | 具名断言 | 实际覆盖 |
|---|---|---|
| provider/model/session/continue ownership、preview 只读 | `{worker,pm}-expansion-{refused,pure}:{template,extra}:<case>:{preview,launch}` | 两席位 × 两入口 × 13 个展开/escape case；snapshot 比较 config、BOARD、全部 state 内容/mtime、prompt、argv log、窗口/pane/PID 与 worker git status |
| PM continuation ownership | `pm-resume-expansion-{refused,pure}:{builtin,custom}:<case>:{preview,launch}` | 2 入口 × 7 case；同 resume-key 可信 metadata，不以 fresh-pm 清空参数伪造通过 |
| 合法 literal、占位符不误杀 | `{worker,pm}-expansion-literal-{preview,preview-pure,launch,argv}:{template,extra}` | 实际 `two words` 为一个值；`--mod*`、`{safe,words}`、`~/routing-note` 和 single-quoted backslash 保持 literal；model/provider 唯一，worker SID 保持记录值 |
| PM 合法 continuation 精确值 | `pm-resume-literal-{preview,preview-pure,launch,argv}:{builtin,custom}` | 实际 quoted SID 为 `fixture-literal-session`，不含 quote 字符；PM model 仍为独立 policy |
| 尺寸快照不等于身份完整性 | `reader-snapshot-{valid,monitor,pure}:`、`:0005` | `sid_bytes=''` 与 `0005` 被 Bash/monitor 接收；仍读取 A；记录 hash 不变；未删原非法 sid_bytes 与坏记录矩阵 |

录制器通过产品 launcher/login bash/私有 tmux/配置 PATH 启动，记录进程实际 argv，不是渲染字符串。未证明 Pi 接受这些 selectors、远端模型真的改变或输出质量；不假设未知短选项 alias。`-?[r]ong` 特意不匹配文件，验证拒绝不确定 pathname 语法；`-m*` 原 owned vocabulary 就会拒绝，两者不冒充新增绕过。

最终原 fixture `G/final-routing-evidence/teamsmith-task-model-routing.JH3oUm/`；`final-argv-summary.json` 中四个新增 literal controls、两个 PM resume controls 精确值通过，原录制 argv 没有 `--provider=other`、`--model=wrong:low`、`--session-id=other-history`、`--resume=other-history`。之前的 trusted assignment、全部拒绝 before/after hash 和窗口/PID 快照仍在 fixture 中。

### Before → after 与原失败保留

- `G/before-boundary.log` 554/146，含 config setter 把以 `-` 开头的值当 CLI 选项的 setup 失败；不将其当产品红。原日志/fixture/rc 保留。
- 改用已有 CLI 支持的前导空格值，将未修复产品冻结到 `G/source-before`：`G/baseline-boundary.log` 578/122、rc=1。实际 argv 收到额外 `--provider=other` 6 次、`--model=wrong:low` 7 次、`--session-id=other-history` 3 次、`--continue` 4 次、`--resume=other-history` 3 次。原 fixture 是 `G/baseline-fixtures/teamsmith-task-model-routing.pW6Wuh/`，摘要 `baseline-argv-summary.json`；样例同时有 `--model deep/model:high` 和 `--model=wrong:low`。
- 修 lexer/PM builtin 后 `G/targeted.log` 1064/1、rc=1：新合法 literal 控制发现 worker builtin 仍二次 split，收到 `"two` 与 `words"` 两词。修同源 tokens 后 `G/targeted-2.log` 1065/0、rc=0（boundary,sid-readers）。两轮原 argv/snapshot/fixture 保留。
- `G/argv-summary-first-failure.txt` 记录事后摘要脚本误以为只有 4 个 `two words` controls，实际 5 个（已有控制也使用该值）。按新增 single-quoted-backslash 特征过滤后精确为 4，未改产品或测试；不将该统计错误当产品缺陷。

### 最终验收命令与原始尾部

driver 为 `G/run-final.sh`，在自己的 worktree 启动，clone 已提交 `d823c7e` 为稳定私有 `G/final-source`。所有产品 CLI 在脚本断言的独立 repo/HOME/socket fixture 执行，不以真实团队为目标。后台 `P228-F3-final` 已收割，exit=0，driver `source stable=yes` / `FINAL overall=0`；总运行 2173.8s，无 timeout。完整日志 `G/final-driver.log`，每项 `G/final-<tag>.log` 与 `.rc`。

| 实际命令 | 尾部 / rc | tag |
|---|---|---|
| `df -h /tmp` | 容量地板充足，收尾约 13 GB 可用；0 | space |
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 14 passed / 0 failed；0 | openspec |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs，retired 0 / undeclared 0；0 | spec-refs |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 169/0，顶层 SKIP 0；0 | config |
| `bash skills/teamsmith/tests/routes.sh` | 207/0，SKIP 0；0 | routes |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 87/0，SKIP 0；0 | death-pure |
| 同脚本 `--live` / `--flip` | 7/0 / 4/0，SKIP 0；均 0 | death-live / death-flip |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 1244/0；0 | routing |
| 同脚本 `--select flip` | 94/0；baseline/restored 各 1244/0；0 | flips |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | hits=0 / names=ok；0 | ledger-ban |
| `git diff --check` | 无输出；0 | diff |

config 嵌套 JSON/preview 控制打印 SKIP 1，顶层 SKIP 0，未隐去。timeout 为 OpenSpec/refs 90s、config 360s、routes 900s、death pure 150s/live与flip 180s、routing 1400s、源码 flips 4200s、ledger 120s。开跑/收尾 HEAD/status 相同；`G/source-before.sha256` 与 `source-after.sha256` 文件逐字节一致，manifest SHA256 为 `bd9dd64a6b3674043eb066f705b4e7cc8bf163be561d23b7bfba8189d566a21f`。

### Flip evidence：破坏源码、具名红、恢复再绿

原包 `G/final-flips-evidence/teamsmith-task-model-routing.ve7FWl/` 保留 16 个独立 scratch mutations：既有 13 臂全部重新执行，再新增 3 臂。每臂要求目标唯一 matched=1、shape 检查、实际 fixture rc=1、具名 FAIL 及 source hash 恢复相同。全部恢复后全矩阵 1244/0；顶层 94/0，不是只 grep 任意报错。

| 新 mutation | 实际红 | 具名断言 | source_before = source_restored |
|---|---|---|---|
| `literal-shell-expansion`：移除 lexer 未引用展开拒绝 | boundary 654/162，rc=1 | worker/PM × template/extras 的 `*-expansion-refused:*:model-glob:launch` | `59441510a2acaa29f3730c851ecb2d52921a37e8719b42bcb67e29d85d36f823` |
| `pm-literal-resplit`：PM extras/resume 改回原文本 split | boundary 814/2，rc=1 | `pm-expansion-literal-argv:extra`、`pm-resume-literal-argv:builtin` | `f12a5f7680d01cb475eb5dd40221be47a116d66238d5dbafdd66eb90531056dd` |
| `worker-literal-resplit`：worker extras 改回原文本 split | boundary 815/1，rc=1 | `worker-expansion-literal-argv:extra` | `0fc69b47c3eb798435a4de4726d5ed074b54aafd93cdd61f3937c52497f56fa2` |

`mutation-*.json` 保存唯一匹配及文件 before/after SHA；`flip-*.log` 保存实际失败；各臂 `flip-evidence/` 保存原 argv/状态。既有 CAS、quote、unmapped、recovery、事务、unknown-count、latest-history、record drift、PM metadata/publication、template/extras ownership 反例全部保留。

### 冻结/释放

最新冻结核心为 `d823c7e` 的 `common.sh`、`cmd-agents.sh`，连同原 S1 事务/record/monitor。新 `tests/lib/model-routing-expansion.sh`、snapshot controls、flips 与测试入口是本轮 argv/guard 证据，下阶段只读消费并保留。公共 ledger/UI/init delta/教程/模板未改；接收、解冻或串行借用由 PM 决定。所有后台作业已收割；源码与报告留本地分支，等待独立复验，不用作者自测替代 RECEIVED。

---

## 追加：F4 身份占位符必须绑定对应 selector · 2026-10-09

### 最新结论与边界

最新受检产品/测试为 `8201eece2bab8e0806735ada6cc9861a58251090`。**作者自测通过，未独立接收**：S1 路由 1796/0，17 臂真实源码翻转 103/0；全部任务书切片命令通过。旧候选 `a1a285d` 仍是独立 FAIL，不沿用它的通过数字，也不删除任何旧报告或失败。

依据最新 thread、任务书、D114–D115、V19 完整失败报告及接受的 proposal/design/delta。原生 context/status/instructions apply 仍定位自己的 worktree，未改 store、未运行 init/install。分支始终为 `task/P228-task-model-routing-core`；仅本地提交，没有 push/PR/MR/merge/archive/done/close，没有切实际配置、重启实际 PM/worker/pulse、修改共享技能或其他项目。没有授权硬阻塞；等待 PM 冻结此候选后安排不同作者独立复验。

证据根：`B=../pm-skills-ledger/team/reports/P228-dev/binding-repair`。本节为最新追加结论，前文原字节保留。

### 根因与修改范围

原守卫已有 `refs`（占位符出现次数）和 `seen`（已校验的对应 selector），却以 `refs` 判 continued 完整性。`--label {provider}`、`-e {model}`、`--skill {session_id}` 或纯 positional 虽含占位符，却没有对应身份 selector；工具仍启动并发布 selected model/SID。

本轮唯一产品修改在 `common.sh::team_template_identity_guard`：

- 身份占位符出现时，必须已被对应的、值正确的 selector 消费；未绑定的 positional/其他参数值在 fresh 和 continued 都拒绝。
- continued 要求 worker 的 provider/model/SID、PM 的 provider/model 均有已校验的绑定。PM `{resume_args}` 仍按既有独立未引用 argv-list 规则校验，不将它当标量 selector。
- 原词法、重复/错绑/缺值/引用/硬编码/展开拒绝保留；opaque fresh 未增加精确身份或历史兼容承诺；缺 `{resume_args}` 的 PM lost-history 分支仍诚实说明不带继续参数。

测试仅改 `tests/lib/model-routing-boundary.sh`、`tests/lib/model-routing-flips.py` 和 `tests/task-model-routing.sh`。未改 CLI/schema、assignment/PM metadata 形状、锁/事务、读侧、S2/S3 或五份 delta。没有引入通用 shell/CLI parser、Pi reasoning/message 改写或非 Pi 兼容矩阵。

### 场景、真实参数与效果证据

| 已接受合同对应场景 | 具名断言 | 覆盖与结果 |
|---|---|---|
| 单个或全部身份仅作 positional/其他 flag 的值 | `template-{refused,pure}:{positional-all,positional-provider,positional-model,positional-sid,data-provider,data-model,data-sid}:*` | worker 7 形态 × continued/fresh × preview/real；拒绝且无副作用 |
| PM provider/model 未绑定 | `pm-template-{refused,pure}:*`、`pm-custom-missing-{refused,pure}:*` 的 positional/data 臂 | PM 5 形态 × fresh/continued × preview/real；拒绝且无副作用 |
| list 占位符不能填身份值；错绑、重复、缺值不误放行 | `template-refused:{list-as-model,misbound-placeholder,duplicate-model,duplicate-provider,duplicate-sid,missing-model-value}:*`；PM 同族 | 保留原断言并新增 SID/list 控制；均 PASS |
| 合法 separate/equals/short/attached selectors、完整模型路径及 suffix、无害 literal/extras | `template-legal-*`、`template-bound-fresh-*`、`pm-bound-*` | worker 6 形态及 PM 4 形态的继续/fresh 控制；真实 provider/model/SID 唯一且与记录一致；fresh SID 更新，PM fresh 不带 continue |
| 字面数据恰与 model/provider 字符串相同，不冒充身份 | `template-legal-argv:literal-data`、`pm-bound-exact-argv:*` | option-aware recording oracle 消费 probe 的 `--label/-e/--skill` 数据值，再核对实际身份选项；不是字符串出现或最后参数优先检查 |
| 保留诚实 lost-history 与合法恢复 | `pm-custom-missing-resume-*`、`pm-custom-continue-argv`、`pm-builtin-known-continue-*`、原 resume/sid-readers/transaction 组 | 原控制继续通过，不冒称真实 Pi 历史恢复或推理兼容 |

实际录制通过产品 launcher、login bash、配置 PATH 与隔离 tmux，不是只检查 render 文本。只证明工具发出的 argv/自身记录，不证明 Pi/provider 执行语义、未知参数 arity、内部模型切换、模型质量或跨模型兼容。

旧源码的实证：`B/before-evidence/teamsmith-task-model-routing.ZqVxiP/binding-cases/worker-data-model-launch/after/dev.env` 发布 `model=vendor/deep/model:high`、`mode=continued`、`sid=routing-fixture-dev-1791586743-2703762-4370-264`、`launch_nonce=1791586747-2711055-13945-14176-1`；同臂录制 argv 有 provider/SID，**没有 model selector**。provider/SID 错槽、纯 positional 及 PM continued/fresh 的缺 selector 同样在原 capture 中，而不是推测。

修后包：`B/final-routing-evidence/teamsmith-task-model-routing.YjIhPQ/`。每个负向模板臂的 `binding-cases/<entry>-<case>-<mode>/{before,after}/` 保存 config、完整 assignment/PM record（缺失则记 absent）、prompt、BOARD、实际 argv 与 effect hash。`commands.log` 保存 CLI 原输出/rc；原 `effect-hashes.log`、attempt nonce/proof 及所有读侧/展开矩阵保留。

`B/binding-summary.json` 由 `summarize-binding.py` 读取这些合成数据产生：F4 共 48 个 preview/real 对照，旧源码 24 个真实启动改变状态且新 argv 与发布记录不符；修后 48 个拒绝前后 effect hash 全相同、新增 argv 均为 0。快照包含全部 state 的内容/mtime、config、BOARD、argv、窗口/pane/PID、worker git status，不只比较模型字段。

### 最终命令、输出与源码冻结

从自己的 worktree 后台启动 `B/run-final.sh`，它 clone 已提交的 `8201eec` 到未部署的 `B/final-source`，所有产品操作仅在 fixture repo/HOME/socket。`P228-binding-final` 已由 `team_bg_wait` 收割，exit=0，3216.0s，无 timeout；原 driver 日志为 `B/final-driver.log`。每项完整命令（含 timeout）、日志及 rc 分别为 `B/final-<tag>.command/.log/.rc`。

| 实际命令 | 尾部 / rc | tag |
|---|---|---|
| `df -h /tmp` | 开跑约 13 GB 可用，收尾约 12 GB；0 | space |
| 逐文件 `bash -n`，`node --check monitor.mjs`，Python AST 校验 flip helper | 无错误；0；确切文件/命令在 `.command` | syntax |
| `TEAM_ROUTING_TREE=B/before-source bash skills/teamsmith/tests/task-model-routing.sh --select boundary` | 1294/74；1，**预期旧源码红** | before-binding |
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 14 passed / 0 failed；0 | openspec |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs，retired 0 / undeclared 0；0 | spec-refs |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 169/0，顶层 SKIP 0；0 | config |
| `bash skills/teamsmith/tests/routes.sh` | 207/0，SKIP 0；0 | routes |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 87/0，SKIP 0；0 | death-pure |
| 同脚本 `--live` / `--flip` | 7/0 / 4/0，SKIP 0；均 0 | death-live / death-flip |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 1796/0；0 | routing |
| 同脚本 `--select flip` | 103/0；17 坏源码臂各 rc1；baseline/restored 各 1796/0；0 | flips |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | files=1310 hits=0 names=ok；0 | ledger-ban |
| `git diff --check` | 无输出；0 | diff |

timeout：before boundary 900s、syntax 60s、OpenSpec/refs 90s、config 360s、routes 900s、death pure 150s/live与flip 180s、routing 1800s、源码 flips 6000s、ledger 120s。config 嵌套 preview 控制仍显示 SKIP 1，顶层 SKIP 0，不隐藏。driver 对旧源码红单独要求 rc1，其余要求 rc0；不是把任意非零都算通过。

driver 最后 `source stable=yes`、`FINAL overall=0`；HEAD/status 未变，`source-before.sha256` 与 `source-after.sha256` 逐字节一致，manifest SHA256 均为 `881cfdf4d8cacdba61274d746acfb4bcd3fc66f2618bcb02029fd1e7b1860432`。受检完整 SHA 在 `final-tested-tip.txt`；随后报告提交不改变产品/测试字节。

### Flip evidence：真正移除绑定证明，红后恢复绿

`B/final-flips-evidence/teamsmith-task-model-routing.dDKmQL/` 保留原 16 臂并新增 `template-unbound`，不是 stub guard 返回值。新臂实际删除未绑定检查，并把 continued 从 `seen` 恢复为 `refs`；两处目标均唯一 matched=1、shape 校验通过。

坏源码 boundary **1294/74，rc1**，必须命中以下具名失败：

```text
template-refused:positional-model:launch
template-refused:data-sid:preview
pm-custom-missing-refused:positional-model:launch
pm-template-refused:data-provider:preview
```

`mutation-template-unbound.json` 保存两次源码变更的 before/after SHA；`flip-template-unbound.log` 与该臂 `flip-evidence/` 保存真实 argv/发布记录及错误。source before/restored 聚合 hash 同为 `dc338dc51b1c4bdb9c379cbc19cddb8ddef1c99e78fc8a7e70c9a54d33d7488f`。17 臂均为真实 rc1、具名断言判红及字节恢复；baseline/restored 全组均 1796/0，顶层 103/0。原 F1/F2/F3、CAS、路由、恢复、事务、unknown peer、读源、PM publication 和 quoted-literal 反例全部重新执行。

旧源码 74 红中 72 是 positional/data 臂的拒绝/副作用断言；其余 2 是不安全启动已改 SID 后，首个合法 continued 控制对原 SID 的不一致，不能描述成 74 个独立缺陷。

### 本轮失败保留与移交

- 首轮 `local-before.log` 为 872/88、`local-after.log` 为 956/4，rc 均为 1。after 四红是新测试误引用不存在的 `TEAM_PM_META` 数组，而 loader 实际给 `TEAM_PM_METADATA_JSON`；修正测试读取合法发布记录，不改产品 metadata 规则来消红。原脚本快照 `local-first.boundary.sh`、源 manifest、argv/fixture/rc 均保留。
- 修正并加强合法 fresh/纯 preview 控制后的 `local-corrected-before.log` 为 954/74（旧源码 rc1），`local-corrected-after.log` 为 1028/0（修后 rc0），前后源 manifest 相同。随后只增加逐臂原始证据保存及其断言；最新冻结 commit 完整重跑才为本节的 1796/0、103/0。
- 源码/测试的三个后台作业 `P228-binding-local`、`P228-binding-control`、`P228-binding-final` 全部由工具收割。报告仅追加，原 prefix 留 `B/report-prefix.md`；没有覆盖旧失败。
- 追加报告首次收尾检查 `P228-binding-report-check` 已收割：隐私检查 rc0、原报告 prefix 检查 rc0，`git diff --check` 因新报告多一个 EOF 空行返回 rc2，driver rc1。原 `report-diff-check.log/.rc` 保留；只移除新追加部分的尾部空行，不改产品或旧报告字节。修正后的 `P228-binding-report-final` 已收割，隐私/prefix/diff 均 rc0，`REPORT FINAL overall=0`；原输出保存为 `report-final-*.log/.rc`。

冻结写集合：`common.sh` 与本轮三个测试文件，连同原 S1 所有接口，以 `8201eec` 为同一私有候选。未改变 core JSON/record 接口，未释放给 S2/S3 并发写；接收、串行借用与独立复验由 PM 决定。共享技能的两条软链接仍指向稳定主检出，未指向 worker/验收 clone。

**未执行**：全量 smoke、完整 change/S2/S3、真实 TUI 或正式性能验证、真实 Pi/provider/模型质量及兼容、实际配置升级/fresh/共享采纳、部署、远端 CI/写入、归档。当前只是原 S1 范围作者交付，不能据此标整个 apply done 或上线。

---

## 追加：F5 参数角色证明（selector-as-data）· 2026-10-10

### 结论与状态

- 输入：冻结失败候选 `985328b0f96bd755b85d5c7f81eff92e9f4d7fd3`（受检 `8201eec`）＋ V19 第四轮完整报告 `d35dbfcc` ＋ PM 冻结的 F5 反例探针
  `reviews/V19/binding-985328b/pm-selector-data-replay/probe.sh`（SHA256 `76341583b85e1dd95e26b09b84989ef338b8842d85f149f0059a376e2ac5b2fd`，本轮未改一字节）。
- 输出：产品/测试 tip `55d3bc6cfa8c844ac0ace8d4a979ec03cf4811dc`（本节追加报告 commit 之后产品字节不再变化；驱动在稳定克隆上验证的就是这个 tip）。
- 状态：**S1 私有返修候选，作者自测通过，尚未独立复验**。本节不自行接收、不标 done、不合并、不推送、不改共享源；旧候选 `985328b` 的「不接收」结论不变。
- 本节所有数字都在自己的 worktree / 稳定克隆里真实跑出；命令、rc、日志路径逐条列出，日志同时复制到仓外证据目录 `pm-skills-ledger/team/reports/P228-dev/f5-repair-2/`。

### 根因：词面出现 ≠ 参数角色绑定

F5 反例的核心形状是 `--skill` 消费了紧随其后的身份 selector：

| 模板（worker，冻结探针里的形状） | 实际 argv 角色 | 旧守卫（985328b）的结论 | 真相 |
|---|---|---|---|
| `--skill --provider {provider} --model {model} --session-id {session_id}` | `--skill` 的值 = `--provider`（工具数据） | 「provider 已绑定」→ 放行 | 该 `--provider` 从未成为 CLI 的 provider 选项 |

旧守卫按**词面**扫描：看到 `--provider` 这个词就置 `seen[provider]`。但 argv 的角色由**位置**决定：`--skill` 是吃一个标量值的选项，它后面的 token 是它的数据。于是「绑定」被伪造 —— 预览与真实启动都发布完整的 provider/model/SID 宣称，而 CLI 实际收到的是 null。PM 的独立复现是 10 次真实误放行 + 10 次预览误放行。

修法不是再补一个 `--skill` 特例，而是补**参数角色证明**：要么证明身份选项及其值确实按身份角色绑定，要么拒绝。

### 修法与拒绝边界（`skills/teamsmith/scripts/lib/common.sh`）

新增 `team_argv_roles_guard`（对一个字面 argv 做**角色**遍历，不是 Pi 参数表/arity 解析器），并在三条入口接线：
`team_identity_extra_guard`（worker/PM extra args）、`team_template_identity_guard`（worker/PM 模板，`{extra_args}`/`{resume_args}` 先在原位展开再证明）、`team_pm_resume_args_guard`（PM 恢复参数）。规则（全部只基于「Teamsmith 自己发出的、或既有合法控制用到的」最小已知集）：

1. `-e|--skill`：Teamsmith 自己的工具加载对（内置 Pi 路径就发这两个）。它必须**恰好消费一个普通字面数据值**；值是 `-` 开头、或是身份/列表占位符（`{provider}`/`{model}`/`{session_id}`/`{extra_args}`/`{resume_args}`）→ 拒绝。
2. 身份 selector（`--provider`/`--model`/`--session-id`/`--session`/`-m`/`-s` 及 `=`/短/粘连形式）与续跑形式（`--continue`/`-c`/`--resume`/`-r`）按角色跳过其值，跳过即**不绑定**；`--session`/`-s` 保留给真正被启动的那个 CLI 的 Pi 形 selector。身份 walk（F4 保留）随后要求每个身份占位符有对应且值正确的 selector；continued 的完整性判据仍是 `seen`（已证明的绑定），不是 `refs`（词面出现次数）。
3. `--no-tools`：唯一被白名单的零 arity 旗标 —— 既有合法控制（`TEAM_EXTRA_PI_ARGS='--no-tools …'`）需要它；其余未知开关一律**不猜 arity**。
4. 未知开关若在它之后还存在受保护 token（身份占位符、身份选项、`{extra_args}`/`{resume_args}`）→ 拒绝并给出修法（「把未知参数移到全部身份/恢复参数之后」）；未知开关出现在所有受保护组**之后**仍是允许的普通数据后缀。引号不改变角色（`"--unknown"` 也按未知开关处理）。
5. `--skill` 的值不再参与身份/连续性绑定：`--skill --continue` 或 `--skill --session-id` 都不再算「证明了续跑/身份」。

拒绝边界的代价（有意接受）：自定义 CLI 若把身份叫成发明的名字（`--prov`/`--sid`）、或把未知开关放在身份组之前，现在会被**保守拒绝**（修法已写在报文里：写成 Pi 形 selector，或把未知开关移到后面）。opaque 模板（不含身份占位符，如 `myagent run --ask {prompt}`）与文档里的 `codex`/`opencode` 诚实数据路径不受影响。**没有**引入新占位符、运行时 Pi/SDK 依赖、Pi 全参数表或兼容矩阵。

### 覆盖与具名证据（新测试文件 `tests/lib/model-routing-roles.sh`）

全部在路由前门自己的私有 repo/HOME/socket 里跑，用一个录制 CLI 落盘真实 argv，再按选项角色核对（不靠语义猜测）：

| 断言族 | 条数（baseline） | 覆盖 |
|---|---|---|
| `worker-role-refused:*` / `worker-role-pure:*` | 100 / 100 | worker：`{--skill, -e, --unknown, --unknown=value, "--unknown"}` × {provider, model, sid} 错位 + 未知标量/等号/引号前缀 + extra 列表吃掉 model；× {preview, launch, fresh-preview, fresh-launch}；每次拒绝都要求 rc=1 **且**前后可观测快照（config/BOARD/state/提示词/argv/窗口/PID）逐字节相同 |
| `pm-role-refused:*` / `pm-role-pure:*` | 104 / 104 | PM 同上（provider/model/`{resume_args}`），含 `{resume_args}` 被 `--skill` 吃掉、extra 吃掉 resume、resume 里混未知参数 |
| `pm-role-resume-refused:*` / `pm-role-resume-pure:*` | 56 / 56 | PM 恢复参数 7 种形态 × builtin/custom × 4 模式 |
| `worker-role-legal:*` / `pm-role-legal:*` | 21 / 21 | 合法控制：`--skill harmless`、`-e 'literal extension'` 前缀、未知开关后缀、extra 前缀（含 `--no-tools`）；launch 时按真实 argv 核对 provider/model/SID/continuation 精确值 |
| `role-capture:*` | 每臂 before/after | 绑定捕获：每次派单/启动前后的发布记录与真实 argv |
| 基线总量 | `RESULT pass=2848 fail=0`（12 组：policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary） | 既有臂与本轮新增臂都在本轮同一棵树上重跑 |

日志：`/tmp/teamsmith-task-model-routing.lXuVEl/flip-baseline.log`（副本在 `f5-repair-2/flip/` 下同轮证据目录）。

### 冻结反例：红 → 拒绝纯净 → 合法值 → 源码翻转/恢复

1. **PM 冻结探针**（同上一 SHA256，未改）：对冻结候选（PM 的 clone）`TOTAL pass=1 fail=20`、rc=1（10 误放行真实 + 10 误放行预览 + 20 条应拒绝断言红；`reviews/V19/binding-985328b/pm-selector-data-replay/replay.log`，本轮由我复跑一份 `f5-repair-2/old-probe.log`）；对本轮候选 `TOTAL pass=21 fail=0`、rc=0，10 次真实/预览全部拒绝、发布记录不变、合法 `--skill harmless` 控制精确解析出 `vendor/expected:high`（`f5-repair-2/pm-selector-data-replay-new/replay.log`）。
2. **源码翻转 `template-roles`**（在 owned scratch 副本上还原旧词法 walk 并去掉两处 `-e|--skill` 跳过）：boundary `RESULT pass=2030 fail=390`、rc=1，命中三条具名断言 `FAIL worker-role-refused:model:--skill:launch`、`FAIL pm-role-refused:provider:--skill:launch`、`FAIL pm-role-resume-refused:builtin:--skill --continue:launch`；源恢复后同一切片回到 2848/0，`source_before = source_restored`。
3. **源码翻转 `template-unbound`**（还原 F4 前的 unbound walk，并同时还原角色证明）：`RESULT pass=1956 fail=464`、rc=1，命中 `template-refused:positional-model:launch` 等具名断言，恢复后逐字节相同。
4. 其余 16 臂（F1–F4 与既有臂）在本轮同一棵树上重跑：每臂靶向断言红、具名断言命中、源恢复逐字节相同；全套 `RESULT pass=111 fail=0 selected=flip`（日志里的两条 `FAIL monitor-missing-A-unavailable`、`FAIL pm-publication-failure-stops-uncommitted` 是被翻转变异子运行**设计上**的红，紧随其后是它自己的 `RESULT … fail=1`，不是本轮套件失败）。
5. 无一条断言被删除、skip 或弱化：本轮的「红→绿」全是新增/保留断言的严格化（原来「一律接受」的两条已被拆成「合法形式接受」+「不可证明形式拒绝并点名规则」）。

### 同一请求的次要范围：smoke adapter 夹具（本轮只动我 lane 的部分）

任务 5.3 要求「update original pm-lifecycle/watchdog/adapters smoke guards」，断言不许弱化。`tests/smoke.sh` 里 adapter 夹具的模板写在 F4/F5 收紧之前，现按**已接受规则**调整，渲染断言一条不减：

| 位置 | 原形态 | 现形态 | 断言处理 |
|---|---|---|---|
| §6f ② `APLACE` | `--model {model} --prov {provider} --dir {cwd} --sid {session_id} …` | `--model {model} --provider {provider} --session-id {session_id} {extra_args} --dir {cwd} …` | model/provider/cwd/session/skill/prompt_file/prompt、无残留占位符、adapter 标签等渲染断言全部保留，仅把 `--prov deepseek`/`--sid …` 改为真实 selector 名 |
| §6g `ACMD` | `… {cwd} {session_id} {prompt_file} {skill_dir}` | `… --session-id {session_id} {cwd} {prompt_file} {skill_dir}` | 原断言（`{session_id}` 渲染值、无残留占位符）不变 |
| §6i ② `PM_TPL` | `--model {model} --prov {provider} --dir {cwd} … {resume_args} {extra_args}` | `--model {model} --provider {provider} {resume_args} {extra_args} --dir {cwd} …` | `{model}`/`{provider}`/`{cwd}`/`{prompt_file}`/`{prompt}`/`{skill_dir}`/`{resume_args}`/`{extra_args}` 与 harness/证据断言保留，仅 `--prov demo` → `--provider demo` |
| §6f ⑧ | 未引用 `{"a":1}` 与 `${HOME}` 断言「接受」 | quoted `'{"a":1}'` 接受 + 未引用花括号**新增拒绝**断言；相邻占位符单独接受 + 未引用 `${HOME}` **新增拒绝**断言 | 原两条断言拆成「合法形式仍接受（原意保留）」+「不可证明形式拒绝并点名规则」（复用既有 `m32_expect_fail`） |

按角色证明逐条验过（`f5-repair-2/smoke-form-probe.sh`）：`APLACE/ACMD/PM_TPL × fresh/continued` = rc0，`json-quoted` rc0，`json-unquoted`/`home-unquoted` rc1。

**未跑/跨切片阻塞（具名）**：`TEAM_SMOKE_FAST=1 --select 6f,6g,6i,6j` 在当前 S1 树上仍红 123 条，根因不在 adapter 夹具，而在 S1/S3 尚未交接的夹具链路：

- `§2 init` 生成的 config 没有 `TEAM_TASK_MODELS`（模板仍是 S1 前形状，S3 任务 7.1/7.4 负责），`§4` 的 `team task` 也还没有 `--category <类别>`；因此 `§4` 建不出任务书 → `TASKFILE` 为空 → `§3b/§6/§6f/§6i` 的 dispatch 连带失败；
- 另有 `dev: legacy/unknown assignment_version` 一类 preflight，需要在集成阶段按新 assignment 记录形状给夹具 seed（同属 S1/S3 交接）；
- 我为此做了一份**不入交付树**的 scratch 复现（`f5-repair-2/smoke-scratch/6f-6i-scratch.log`：模拟 S3 的 init 输入 = `config upgrade-models` + `--category routine` + 策略 map），`§4` 转绿、`§6f/§6i` 失败由 57/24 降到 42/22，剩余失败点名的仍是上述 preflight/seed 与其它非 adapter 段。

完整 smoke 与 init/模板/策略迁移属集成阶段（PM 已安排全量）；本节不宣称 full green。

### 改动集合（逐文件）

| 文件 | 改动 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | 新增 `team_argv_roles_guard`；三条入口接线；模板/extra/resume 三条 walk 按角色跳过 selector 值与 `-e|--skill` 数据 |
| `skills/teamsmith/tests/lib/model-routing-roles.sh`（新） | F5 角色矩阵与合法控制（worker / PM / resume） |
| `skills/teamsmith/tests/lib/model-routing-boundary.sh` | 两处控制的未知开关移到受保护组之后（断言不变） |
| `skills/teamsmith/tests/lib/model-routing-flips.py` | 新增 `template-roles` 臂；`template-unbound` 臂同时还原角色证明 |
| `skills/teamsmith/tests/task-model-routing.sh` | 接线新 role 组与 flip 列表/具名断言 |
| `skills/teamsmith/tests/smoke.sh` | 上表四处 adapter/模板夹具按已接受规则调整（断言保留） |
| `docs/team/reports/P228-dev.md` | 本节 |

未改：canonical specs、OpenSpec root、panel/bundle/strings、SKILL/references/templates/README、实际配置、真实团队运行面、其它项目、共享源位置。

### 冻结/释放

- 产品：`common.sh`（角色证明）为本轮唯一产品改动，既有 S1 接口与记录形状不变。
- 测试：`tests/task-model-routing.sh`、`tests/lib/model-routing-*`、`tests/smoke.sh`（adapter 段）为 S1 私有证据，交独立复验只读消费；`smoke.sh` 的 init/模板/策略段留给 S3 与集成阶段。
- 交接：`cmd-review.sh::team_cmd_close`、`cmd-bootstrap.sh`(writer)、`cmd-docs.sh`(header) 等上一轮已授权的文件本轮**未再改动**，仍按上一轮冻结交接；释放/借用由 PM 决定。

### 交付驱动：稳定克隆上的完整命令/rc/日志

驱动脚本 `f5-repair-2/final-run.sh`：从**已提交的 tip** 克隆一份稳定副本（`git clone --no-hardlinks <worktree> → f5-repair-2/final/source`，并以 `TEAM_ROUTING_TREE`/`TEAM_ROUTING_EVIDENCE` 把路由套件的树与证据都指到仓外），顺序跑下表各步；收尾比较 `HEAD + git status --porcelain --untracked-files=all` 与 `skills/teamsmith/{scripts,tests}` 的 sha256 清单，证明判的就是这个 tip、且跑动中没被改。

| 步骤 | 命令 | rc | 证据（`f5-repair-2/final/`） |
|---|---|---|---|
| space | `df -h /tmp` | 0 | `space.log`（tmpfs 15G，余 12G） |
| syntax | `bash -n`（10 个 lib 脚本 + 本 change 的 4 个测试脚本）+ `node --check monitor.mjs` + `ast.parse(model-routing-flips.py)` | 0 | `syntax.log` |
| openspec | `openspec validate --all --strict` | 0 | `openspec.log`（`14 passed, 0 failed`） |
| spec-refs | `bash skills/teamsmith/tests/spec-refs.sh --check` | 0 | `spec-refs.log`（104 引用 / 49 个不同） |
| config | `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 0 | `config.log`（✓169 ✗0，1 SKIP） |
| routes | `bash skills/teamsmith/tests/routes.sh` | 0 | `routes.log`（✓207 ✗0） |
| death-pure / death-live / death-flip | `bash skills/teamsmith/tests/death-cause.sh --pure/--live/--flip` | 0 / 0 / 0 | `death-*.log`（✓87 / ✓7 / ✓4，翻转红侧成立） |
| routing | `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 0 | `routing.log`：`RESULT pass=2848 fail=0` |
| ledger-ban | `bash skills/teamsmith/tests/ledger-ban.sh --names-file <主仓>/.pi/team/forbidden-names.txt` | 0 | `ledger-ban.log`（files=1310 hits=0 names=ok） |
| diff | `git diff --check`（稳定克隆内） | 0 | `diff.log` |
| 冻结探针 · 旧候选 | `bash probe.sh <PM 的 clone，985328b> <仓外> ` | 1 | `old-probe.log`：`TOTAL pass=1 fail=20`（设计红） |
| 冻结探针 · 本候选 | 同一脚本、同一环境 → 稳定克隆 | 0 | `pm-probe.log`：`TOTAL pass=21 fail=0`；合法控制的离线 Pi 解析 `provider=vendor model=expected:high sessionId=… skills=["harmless"]` |
| 稳定性 | `HEAD + git status --porcelain --untracked-files=all`、`find … sha256sum` 清单前后比较 | — | `source stable=yes`、`FINAL overall=0`（作业 exit=0，1028.8s） |

`--select flip`（第 13 条验收命令）由 PM 记录的后台作业 `p228-flip-2` 在本 worktree 上跑完（`f5-repair-2/flip.log`，`RESULT pass=111 fail=0`，18 臂各自 red/named-assertion/source-restored），PM 明确要求不要重复启同一套倒转；该次运行与本 tip 的字节同一性：从 04:33 到 05:48 之间我对这 5 个文件未做任何编辑，05:49 的 `git status` 只列出这 5 个文件且随后原样提交（tree clean），驱动正是从这个已提交 tip 克隆的稳定副本。

稳定克隆的 tip 就是本节声明的 `55d3bc6cfa8c844ac0ace8d4a979ec03cf4811dc`（产品/测试提交），报告本身不进驱动（报告 commit 在驱动之后）。日志与 `source-*.sha256`、`frozen-probe.sha256`、各步 `.command` 都在仓外证据目录；未跑 `smoke.sh`、未跑真实 TUI、未跑真实 Pi/provider/模型，未做配置升级/共享采纳/部署 —— 同「结论与状态」里的边界。

## 追加：R6 返修 F6 + OBS1 · 2026-10-10

### 结论与状态

- 输入：V19 第五轮 FAIL 候选 `aaffe5a`（受检 `V19-dev3.md` 第五轮修订）＋ 本任务书「当前返修输入（第六轮：F6 + OBS1）」。第五轮已确认通过的 F5 结果（冻结探针旧 1/20 rc=1 → 新 21/0 rc=0）本轮原样复跑，不回退。
- 输出：产品/测试 tip = `13bbe5f`（F6 `f771ff3`、OBS1 `0099418`、PM 发布修正 `13bbe5f`；本节之后的报告提交不改产品字节）。
- 状态：**S1 私有返修候选，作者自测通过，尚未独立复验**。不自行接收、不标 done、不合并、不推送、不改共享源；`aaffe5a` 的「不接收」结论继续有效。
- 本轮只动两点，都在已接受合同的车道内；未引入新拒绝（除了把「发布未交付的身份」变成不发布）、未新增占位符、未碰 Pi 供应商/推理/回落语义。
- **交付驱动自身逮到的回归（诚实记录）**：第一轮驱动以非 0 结束（`pm-probe rc=1`，`FINAL overall=1`）—— 冻结的 F5 探针在 PM 用例里**直接调用** `team_pm_metadata_publish`，而我把「模板不可证明」当成了报错；探针在第 13 个用例（第一个 PM 用例）就中断了。修法：不可证明 ⇒ 发布空集（仍是 under-claim；真实启动会被 `team_pm_identity_guard` 拒在前头），见提交 `13bbe5f`；同一探针现在回到 `TOTAL pass=21 fail=0` rc=0。

### F6：类别词汇是项目的，不是引擎的

**合同与实证**：`specs/memory-and-deps` 写 “Initial routine/analysis/verify are examples, not mandatory engine categories”，dispatch delta 写 “Initial examples … do not close the engine vocabulary”；`design.md` 写「项目没有 routine 等键并非非法，映射为空才非法」。V19 第五轮实测（`round5-aaffe5a/required-category-check.log`）：整映射写 `maintenance=vendor/light` 被拒、`upgrade-models` 到自定义词汇被拒、去掉 `analysis`/`verify` 被拒而去掉 `routine` 被接受（不对称）、手写合法映射后 `config list --json` 判 `policy.categories=[]`。

**根因**：`team_task_map_violation`（`common.sh`）在值规则之后对**每一份**映射强制 `analysis` 与 `verify` 出现；写者（`cmd-config.sh` 的整映射、`set-task-model`、`upgrade-models`）与读侧加载器（`common.sh` 的 `team_model_policy_issues`）共用它，无旁路。

**修法**：删掉那个必备循环。剩下的唯一非法映射是空映射，加上既有的重复/畸形/不可表示规则。两条不许弄松的既有规则照旧由别处保证：未在映射里的类别用于**新选择**仍由 `team_task_policy_model` 拒绝（`new-selection-custom-vocabulary-unmapped-refused` 仍 rc=1 并点名 `category 未映射：ops`）；删掉某类别后的同任务可信恢复不看映射成员（`deleted-routine-recovery` 仍 rc=0 且模型/SID 不变）。

**新断言（此前从未被钉过——既有夹具一律带全词汇）**：

| 断言 | 形状 |
|---|---|
| `policy-custom-vocabulary-only` / `-partial` / `-multi` | 直接调用：`maintenance=…`、`routine=…`（无 analysis/verify）、三类别自定义词汇都合法 |
| `policy-drop-analysis-verify` / `policy-drop-routine-analysis` | 只含 analysis/verify 仍合法；去掉任一名不再被拒 |
| `map-custom-vocabulary-write` / `-line` / `-read` / `-upsert` / `-upsert-line` | 写侧整映射与 `set-task-model` 追加；读侧 `config list --json` 的 `policy.categories` 逐字等于写的词汇 |
| `map-empty-refused` | 空映射仍 4 |
| `upgrade-custom-vocabulary` / `-line` / `-read` | `upgrade-models`（迁移/种子入口）接受自定义词汇整映射，读侧同 |
| `F6：init 过的项目接受自定义词汇整映射`…（`tests/config-cli.sh` validate 段） | `team init` 生成的契约 + 写者 + 读侧同一条路 |
| `new-selection-custom-vocabulary` / `-model` / `-unmapped-refused` / `-unmapped-reason` / `-no-assignment` | dispatch 场景：映射里有的类别可派单（模型=映射值），映射里没写的仍拒绝且零副作用 |

### OBS1：发布的身份不得多于 argv 交付的身份

**形状与实证**（V19 `round5-aaffe5a/roles-v4/own-probes/*/obs1-*`）：模板只绑 `--model {model}` 时实际 argv 是 `["--model","expected:high",<prompt>]`、离线 Pi 解析 `provider=null sessionId=null`，而派单横幅与 `state/dev.env` 发布了完整身份（`provider=vendor model=expected:high session=<铸出的 sid>`）。合同依据：tasks 3.5 “no falsely published identity”；dispatch delta 的记录字段是「实际启动身份」。

**修法（发布侧，不新增拒绝）**：`team_template_identity_guard` 在证明角色绑定时记下**它证明了哪些身份 selector 已绑定**（`TEAM_TEMPLATE_BOUND_FIELDS`），`team_launch_identity_fields` 把它变成「本次启动实际交付的字段集合」，两侧发布都用它：

- worker 记录新增 `identity_via`（规范顺序的逗号集合；**键缺省 = 历史记录 = 内建 Pi 的完整交付**；写了一定要合法，非法 = 记录不可信）；PM 记录 `pm-launch.env` 同名字段同理；
- 派单横幅只声明已交付字段，未交付的显式点名：`（…；模板未交付 provider,session_id（不当作已启动身份发布））`；**全交付时与旧文案逐字节相同**（`provider=P model=M session=S`）；
- `team ps` 的会话列与 `team config list --json` 不把未交付的模型当「在跑的模型」（`（未交付）` / 模型置空 + diagnostic）；
- 限额计数：模板没交付模型的活跃同伴算「完整已提交模型身份不存在」，正/通配限额下 fail-closed（`unknown=dev` + 既有修法路线），与「缺模型的活跃同伴」同一车道；
- **诚实 opaque 仍在车道里**：一个身份占位符都不绑的模板（`codex exec {prompt}` 形状）fresh 启动合法、发布空集合；同任务续跑（非 fresh）对未交付身份仍按 F5 规则拒绝。

**三态断言**（`tests/lib/model-routing-roles.sh::routing_publication_probes`，受检内部不变）：

| 断言 | 全绑（内建/all-bound） | 只绑 model | 全不绑（opaque） |
|---|---|---|---|
| 记录 `identity_via` | `provider,model,session_id` | `model` | 空 |
| `publication-record-equals-argv` | argv 里的身份 selector 集合逐条等于记录（不是「包含」） | 同 | 同（空集） |
| 横幅声明 | 完整（与旧文案同字节） | 只 `model=…` + 点名未交付 `provider,session_id` | 不声明任何身份 + 点名全部未交付 |
| 预览行 | 有 `sid=`、无 gap 行 | 无 `sid=` + `identity-delivery: 未交付 provider,session_id` | 无 `model=` + `identity-delivery: 未交付 provider,model,session_id` |
| 读侧（ps/JSON） | 照旧 | 模型算已交付 | `（未交付）`/模型置空 |
| 同任务续跑 | 照旧 | 合法（model 已绑定） | 拒绝（guarded continuation 缺完整身份） |

PM 侧新增：`pm-partial-publication-record` / `-claim`、`pm-opaque-publication-record` / `-claim`（部分/opaque 模板下 PM 记录与成功行只说交付到的字段）。

**语义决定（请 PM 复验时确认）**：`identity_via` 采用「键缺省 = 完整交付、写了空串 = 什么都没交付」两态，而不是新增一种「未知」值——这样历史记录（内建 Pi 路径与手写夹具）不需要迁移，opaque 也不会被误读成历史。

### 覆盖与具名证据（本轮新断言 → 场景）

| 合同句 | 断言（真实名字） | 证据 |
|---|---|---|
| “only an empty map is illegal”（自定义词汇整映射可写/可读） | `policy-custom-vocabulary-only`、`policy-drop-analysis-verify`、`map-custom-vocabulary-write`、`map-custom-vocabulary-read` | `routing.log`（`PASS`，行号见 `f6-obs1-repair/final/routing.log`） |
| 去掉 analysis/verify 仍合法（不对称消失） | `policy-custom-vocabulary-partial`、`policy-drop-routine-analysis`、`policy-custom-vocabulary-multi` | 同上 |
| 升级/种子入口同一条规则 | `upgrade-custom-vocabulary`、`upgrade-custom-vocabulary-read`、`F6：init 过的项目接受自定义词汇整映射` | `routing.log`、`config.log` |
| 空映射仍是非法 | `map-empty-refused`、`F6：空映射仍是 4` | 同上 |
| 未映射类别用于新选择仍拒绝 | `new-selection-custom-vocabulary-unmapped-refused`、`-unmapped-reason` | `routing.log`（`category 未映射：ops`） |
| 可信恢复不看映射成员 | `deleted-routine-recovery`、`recovery-model`、`recovery-sid`（本轮保留未改） | 同上 |
| 发布的身份 ⊆/＝ argv 交付 | `publication-record-equals-argv:{builtin,all-bound,model-only,opaque}` | `routing.log` |
| 记录字段本身 | `publication-record:*`、`pm-partial-publication-record`、`pm-opaque-publication-record` | 同上 |
| 横幅只声明已交付 | `publication-claim-full:builtin`、`publication-claim-gap:model-only`、`publication-claim-no-provider:*`、`publication-claim-no-model:*` | 同上 |
| 预览行/未交付提示 | `publication-preview-no-sid`、`-no-model`、`-gap:*`、`-no-gap:*` | 同上 |
| 读侧不把未交付模型当在跑的模型 | `publication-reader-unavailable`、`undelivered-model-peer-fail-closed`、`undelivered-model-peer-named` | 同上 |
| 恢复对未交付身份仍诚实拒绝 | `publication-continuation-refused`、`publication-continuation-named`（`guarded continuation`） | 同上 |
| PM 侧同一条规则 | `pm-partial-publication-claim`、`pm-opaque-publication-claim`、`pm-known-continues`（保留） | 同上 |

### Flip evidence：破坏实现 → 具名红 → 恢复绿

两个新臂都只改**产品源码的 scratch 副本**（`tests/lib/model-routing-flips.py`），不动任何断言；整套 flips 的判定是 `--select flip`，本轮以 `timeout 6900` 跑完（上一轮 45 分钟上限不够：本轮臂数 19、每个臂要重跑自己的组 + baseline/restored 两次全量 CORE）：

```console
$ timeout 6900 bash skills/teamsmith/tests/task-model-routing.sh --select flip
CONTROL baseline rc=0  log=…/flip-baseline.log     → RESULT pass=2920 fail=0
CONTROL required-categories rc=1 log=…/flip-required-categories.log
PASS flip-required-categories-red / -named-assertion / -policy / -writer / -upgrade / -selection / -source-restored
CONTROL identity-overclaim rc=1 log=…/flip-identity-overclaim.log
PASS flip-identity-overclaim-red / -named-assertion / -record / -argv / -opaque / -claim / -source-restored
CONTROL restored rc=0  log=…/flip-restored.log       → RESULT pass=2920 fail=0
PASS flip-restored-all-green
RESULT pass=129 fail=0 selected=flip
```

| 臂 | 在 scratch 树恢复的旧行为 | 实测变红的具名断言（`flip-*.log` 里的 `^FAIL `） |
|---|---|---|
| `required-categories` | 把 F6 删掉的必备循环原样写回 `team_task_map_violation` | `policy-custom-vocabulary-only`、`map-custom-vocabulary-write`、`upgrade-custom-vocabulary`、`new-selection-custom-vocabulary`（4/4 具名红） |
| `identity-overclaim` | `team_launch_identity_fields` 一律返回完整身份（旧发布行为） | `publication-record:model-only`、`publication-record-equals-argv:model-only`、`publication-record:opaque`、`publication-claim-gap:model-only`（4/4 具名红） |

每个臂的源码按 sha256 清单前后一致地恢复（`source_before == source_restored`），17 个既有臂（F1–F5 的破坏）全部保留并继续具名红；baseline 与 restored 两次全量 CORE 都是 `2920 pass / 0 fail`。

### 改动集合（逐文件）

| 文件 | 本轮改动 |
|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | F6：删掉 `team_task_map_violation` 的必备类别循环；OBS1：`TEAM_TEMPLATE_BOUND_FIELDS` 绑定记录、`team_launch_identity_fields`、`team_identity_field_list_valid`/`team_identity_field_in`/`team_identity_delivered_set`/`team_identity_delivered`/`team_identity_undelivered_text`/`team_dispatch_identity_claim`、记录解析校验 `identity_via`、`team_agent_session_cols` + `team_model_peers` + `team_models_known` 的读侧门、PM 记录 `identity_via` 与 `team_pm_identity_claim`、不可证明模板发布空集（`13bbe5f`） |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | worker 侧：算本次交付集合、预览行与横幅只声明已交付、记录写入 `identity_via` |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | PM 成功行改用 `team_pm_identity_claim`（只声明交付到的字段） |
| `skills/teamsmith/scripts/lib/cmd-config.sh` | `config list --json`：未交付的模型置空 + diagnostic，并新增 `identity_via` 字段；已知模型列表不含未交付模型 |
| `skills/teamsmith/tests/task-model-routing.sh` | F6/OBS1 断言、PM 部分/opaque 用例、限额的未交付模型同伴、两个新臂接线 |
| `skills/teamsmith/tests/lib/model-routing-flips.py` | 新臂 `required-categories`、`identity-overclaim` |
| `skills/teamsmith/tests/lib/model-routing-roles.sh` | `routing_identity_argv_fields` 与 `routing_publication_probes`（三态矩阵） |
| `skills/teamsmith/tests/config-cli.sh` | `validate` 段的 F6 断言（init 契约 + 写侧 + 读侧 + 空映射） |
| `docs/team/reports/P228-dev.md` | 本节 |

未改：canonical specs、OpenSpec root、panel/bundle/strings、SKILL/references/templates/README、实际配置、真实团队运行面、其它项目、共享源位置。

### 冻结/释放

- 产品：`common.sh`、`cmd-agents.sh`、`cmd-watch.sh`、`cmd-config.sh` 为本轮改动文件；上一轮已授权的 `cmd-review.sh::team_cmd_close`、`cmd-bootstrap.sh`(writer)、`cmd-docs.sh`(header) 本轮**未再改动**，仍按上一轮冻结交接，释放/借用由 PM 决定。
- 测试：`tests/task-model-routing.sh`、`tests/lib/model-routing-*`、`tests/config-cli.sh` 为 S1 私有证据，交独立复验只读消费。
- `tests/smoke.sh` 本轮**未改**（上一轮为 adapter 夹具改过的 4 处内容字节未动）。

### 交付驱动：稳定克隆上的完整命令/rc/日志

实测表格在本节末尾（`f6-obs1-repair/final-run.sh`，仓外证据目录 `pm-skills-ledger/team/reports/P228-dev/f6-obs1-repair/`）。

### 未跑 / 边界

- 未跑 `smoke.sh`（不在本切片验收表里，属 PM 的集成/全量集合）、未跑真实 TUI、未跑真实 Pi/provider/模型、未做配置升级/共享采纳/部署；S2 panel 与 S3 init-skill delta 不在本任务范围。
- 真实 Pi 行为（连接失败回落后的模型/会话归一）是 Pi 的职责，本轮不测也不实现；读侧只做「不发布多于 argv 的身份」。
- 本轮作者自测只覆盖 S1 私有面；独立复验（V19 下一轮）仍是接收前提。

### 交付驱动实测表（与上面的“未跑 / 边界”是一体：能跑的验收都在驱动里跑了）

驱动脚本 `f6-obs1-repair/final-run.sh`：从**已提交的 tip** `13bbe5f` 克隆一份稳定副本（`git clone --no-hardlinks <worktree> → f6-obs1-repair/final/source`，并以 `TEAM_ROUTING_TREE`/`TEAM_ROUTING_EVIDENCE` 把路由套件的树与证据都指到仓外），顺序跑下表各步；收尾比较 `HEAD + git status --porcelain --untracked-files=all` 与 `skills/teamsmith/{scripts,tests}` 的 sha256 清单。

| 步骤 | 命令 | rc | 证据（`f6-obs1-repair/final/`） |
|---|---|---|---|
| space | `df -h /tmp` | 0 | `space.log`（tmpfs 15G，余 10G） |
| syntax | `bash -n`（10 个 lib 脚本 + 本 change 的 4 个测试脚本）+ `node --check monitor.mjs` + `ast.parse(model-routing-flips.py)` | 0 | `syntax.log` |
| openspec | `openspec validate --all --strict` | 0 | `openspec.log`（`14 passed, 0 failed`） |
| spec-refs | `bash skills/teamsmith/tests/spec-refs.sh --check` | 0 | `spec-refs.log`（104 引用 / 49 个不同；undeclared 0） |
| config | `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 0 | `config.log`（✓173 ✗0） |
| routes | `bash skills/teamsmith/tests/routes.sh` | 0 | `routes.log`（✓207 ✗0） |
| death-pure / death-live / death-flip | `bash skills/teamsmith/tests/death-cause.sh --pure/--live/--flip` | 0 / 0 / 0 | `death-*.log`（✓87 / ✓7 / ✓4） |
| routing | `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 0 | `routing.log`：`RESULT pass=2920 fail=0` |
| ledger-ban | `bash skills/teamsmith/tests/ledger-ban.sh --names-file <主仓>/.pi/team/forbidden-names.txt` | 0 | `ledger-ban.log`（files=1310 hits=0 names=ok） |
| diff | `git diff --check`（稳定克隆内） | 0 | `diff.log` |
| 冻结探针 · 旧候选 | `bash probe.sh <PM 的 clone，985328b> <仓外>` | 1 | `old-probe.log`：`TOTAL pass=1 fail=20`（设计红，不回退） |
| 冻结探针 · 本候选 | 同一脚本、同一环境 → 稳定克隆 | 0 | `pm-probe.log`：`TOTAL pass=21 fail=0` |
| 稳定性 | `HEAD + git status --porcelain --untracked-files=all`、`find … sha256sum` 清单前后比较 | — | `source stable=yes`、`FINAL overall=0`（作业 exit=0，1233.0s） |

`--select flip`（第 13 条验收命令）在本 worktree 上单独跑：`timeout 6900 bash skills/teamsmith/tests/task-model-routing.sh --select flip` → `RESULT pass=129 fail=0`（19 臂；baseline 与 restored 两次全量 CORE 都是 `2920 pass / 0 fail`）。首次尝试用 `timeout 2700` 在 `template-roles` 臂处被砍（rc=124，臂数 19 加两次全量 CORE 超过 45 分钟预算），因此按上面的更长预算重跑；这不是产品失败。

其余补充证据：`/tmp/p228-r6-postfix.log`（`pm,boundary,dispatch,config,upgrade` → `RESULT pass=2532 fail=0`，用于确认 `13bbe5f` 的 PM 发布修正没有连带影响）。稳定克隆的 tip 就是 `13bbe5f5fded660d8d6d895ed8dcc2983a4d39f2`（产品/测试提交；报告本身在驱动之后提交，不进驱动）。未跑 `smoke.sh`、未跑真实 TUI、未跑真实 Pi/provider/模型，未做配置升级/共享采纳/部署 —— 同「结论与状态」里的边界。

### 契约面待 PM 复核的两处（本轮没有改 spec）

1. `identity_via` 的两态语义（键缺省 = 完整交付，写了空串 = 什么都没交付）——见上面「语义决定」。
2. `dispatch/spec.md` 现有 Requirement 里「未交付字段不当作已启动身份发布」的措辞是本轮新增的发布规则；若 PM 认为它需要作为一条独立 scenario 落在 delta 里，请指派写者（我未改 delta）。
