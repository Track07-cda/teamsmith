# P241 · 修 routing 合并引入的 12 条产品回归（B2 + B3）

agent: dev   status: delivered（B3 的 11 条翻绿；B2 的产品缺陷已修 —— §11b4 那条断言是夹具侧遗留，见文末 BLOCKED）   time: 2026-10-13T10:50Z
branch: `task/P241-routing-b-regressions`（产品改动 tip `7353918`，本报告提交在其上；local 模式，留在本地）   PR/MR: -

## 结论（先说事实，再说判断）

1. **B3（11 条：§11c 7 + §15b 5）就是任务书写的那条链**，两边都复现了：`team close` 清掉 `state/<seat>.env` → 之后 `team inbox --ack` 调 `team_state_set`（文件不存在会新建）把 `inbox_lines=N` 写进那份 assignment 文件 → 下一次非 fresh 派单被 `team_assignment_parse` 判成 `legacy/unknown assignment_version`，拒绝并要求 `--fresh`。主修 + 防御都做了（见 §改动）。
2. **同选集对照（钉死容器、干净克隆、同一命令）**：§11c `✓8 ✗7 → ✓15 ✗0`；§15b `✓21 ✗5 → ✓26 ✗0`；选集 A 总账 `✓601 ✗12 → ✓608 ✗5`。剩下的红全是**既存**（6i 3 条、11b3 1 条，两轮同值）与**§11b4 的夹具侧遗留**（见下）。
3. **B2 的产品缺陷（`common.sh` 单独被 source 时 PM 启动路径报 `team_config_model_violation: command not found`）已消除**：判定本体留在 `cmd-config.sh`（唯一一份），`common.sh` 自己的 5 个使用点在用之前用 `team_model_shape_require` 确保该模块已加载；只 source `common.sh` 的渲染与全量加载的渲染**逐字节一致**（现场实测，两侧各一次）。
4. **§11b4 的那条断言（`P36 ①：模板路径默认把 {resume_args} 渲染出来`）修后仍然红，但原因换人了**：修前它红在 B2（`command not found` → model 策略守卫先失败，渲染为空）；修后守卫过了，暴露出**夹具自己的冻结模板 `mycli run {resume_args} {prompt}` 不消费身份占位符**，而本 change 的 spec 明确要求这种模板拒绝 guarded continuation（`openspec/changes/task-model-routing/specs/dispatch/spec.md:522`：*Frozen custom templates must consume the resolved identity placeholders to claim Pi continuity; a command with unverifiable hard-coded identity SHALL refuse guarded continuation with a template correction*）。这是夹具侧要更新的东西（`skills/teamsmith/tests/**`，不在本任务边界内），已按边界交回 PM。
5. 期间发现并**放弃**了一个更"顺"的实现：把判定本体搬进 `common.sh`（它也是本任务最初的写法）。那会让 `config-cli.sh` 的 F-S1 变异夹具失去落点 —— 它在 `cmd-config.sh` 里插变异来证明 model-kind / pairlist / set-task-model 三条 CLI 路径共用同一判定；实测搬走本体后 `config-cli` 从 `✓331 ✗0` 掉到 `✓329 ✗2`（smoke §33 会跟着判红：那条断言正是本 change 的验收面）。最终实现改成"定义不动、使用点按需加载"，`config-cli` 与 F-S1 恢复全绿（见 §Flip evidence 与 §Decisions）。

一句话：**B3 的 11 条与 B2 的产品缺陷都修掉了、翻转证据齐；§11b4 那条红要夹具侧消费身份占位符，不是产品回归。**

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh` | 收件箱已读基线改住 sidecar `state/<seat>.inbox`（`team_inbox_acked` / `team_inbox_ack_set`）；读侧 sidecar 优先、旧键 `inbox_lines` 回落；`team_inbox_new` / `team_inbox_since` 走新读法 |
| `skills/teamsmith/scripts/lib/common.sh` | ① `team_state_clear` 连同记录清 sidecar；② `team_assignment_field` / `team_assignment_record_present`（"这份文件是不是 assignment 记录"的唯一判据）；③ `team_assignment_parse` 只在文件自称是记录时判 legacy；④ `team_model_shape_require` + 5 个使用点守卫（B2） |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | 派单闸门的拒绝只对"自称是记录"的文件生效（没有记录 → 按没有记录继续派单） |
| `docs/team/reports/P241-dev.md` | 本报告 |
| 仓外证据包 | `pm-skills-ledger/team/reports/P241-dev/`（`README.txt` 是索引；含容器两轮日志、现场脚本与全部产物、变异树日志） |

三个提交（每个都可独立验证）：

```
5462abd fix(inbox): the read baseline is recorded outside the assignment file
eccf056 fix(dispatch): a file without assignment fields is not a legacy record
7353918 fix(common): the model-shape callers load the module that defines it
```

改动本体（B3 主修，`cmd-status.sh`）：

```diff
-team_state_set "$a" inbox_lines "$(team_inbox_total "$a")"
+team_inbox_ack_set "$a" "$(team_inbox_total "$a")"      # 只写 state/<seat>.inbox
```

```diff
+# common.sh · team_state_clear（close/teardown）
+  rm -f "$TEAM_STATE_DIR/$1.inbox"
```

## Verification evidence（都是真跑的）

### 验收命令 1：`openspec validate --all --strict`

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/task-model-routing
✓ spec/notify-and-inbox
✓ spec/pm-lifecycle
✓ spec/verification
✓ spec/watchdog
Totals: 16 passed, 0 failed (16 items)      RC=0
```

### 验收命令 2：钉死容器两份选集（容器 + 干净克隆，同一命令对照）

命令（改前树 = `3372602`，即任务书给的合并 tip；改后树 = 本任务 tip）：

```
$ git clone --no-local --single-branch --branch task/P241-routing-b-regressions <repo> /tmp/p241-post2
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -e TMPDIR=/scratch -v <tree>:/work -v /tmp/p241-post2-scratch:/scratch -w /work \
    localhost/teamsmith-gate:local \
    bash -c 'git config --global --add safe.directory "*";
      bash skills/teamsmith/tests/smoke.sh --keep --select 7,7b,8,11b,11b2,11b3,11b4,11,11c </dev/null
      bash skills/teamsmith/tests/smoke.sh --keep --select 11,11b,15b </dev/null'
```

段级对照（原始日志：`container-before.log` / `container-after-final.log`）：

| 段 | 改前 `3372602` | 改后 `7353918` | 说明 |
|---|---|---|---|
| §11c agent 续跑 | `✓8 ✗7` | `✓15 ✗0` | **B3 主修**：7 条红全消 |
| §15b 必需依赖预检 | `✓21 ✗5` | `✓26 ✗0` | **B3 主修**：dispatch 预检不再被 legacy 拒绝卡住 |
| §11b4 PM 交接 | `✓32 ✗1` | `✓32 ✗1` | B2 已修（`command not found` 消失），剩下的 1 条是夹具模板（见 §结论 4） |
| §7 notify/inbox/digest | `✓31 ✗0` | `✓31 ✗0` | 读侧改动没有碰坏收件箱/摘要 |
| §7b | `✓30 ✗0` | `✓30 ✗0` | |
| §11 收尾 | `✓23 ✗0` | `✓23 ✗0` | |
| §11b 巡检 | `✓64 ✗0` | `✓64 ✗0` | |
| §11b2 PM 存活 | `✓32 ✗0` | `✓32 ✗0` | |
| §11b3 | `✓56 ✗1` | `✓56 ✗1` | 既存红，两轮同值（不在本任务范围） |
| §6i PM adapter | `✓124 ✗3` | `✓124 ✗3` | 既存红，两轮同值 |
| 选集 A 合计（22 段） | `✓601 ✗12` | `✓608 ✗5` | 差集 = §11c 7 条 + §15b 5 条 |
| §15b 段（选集 B，16 段） | `✓431 ✗8` | `✓436 ✗3` | |

两轮的**断言宇宙没有变化**（没有 skip、没有少跑一段）：选集 A 两边都是 613 条（`✓601+✗12` / `✓608+✗5`），选集 B 两边都是 439 条（`✓431+✗8` / `✓436+✗3`）。

§11c 改前的 7 条红（断言原文，全部指向 B3 那条链）：

```
✗ 崩溃 agent 的任务记录还在（…/state/dev.env 中找不到 [task=T1.1]）
✗ digest 仍把崩溃 agent 算成待办（…/digest-crash.log 中没有匹配 [停了的 agent [0-9]]）
✗ 死窗口释放模型槽位（RUNNING=0）（期望 [0]，实际 [可用]）
✗ resume --dry-run 能识别待续跑任务（…/resume-dry.log 中找不到 [可续跑：T1.1]）
✗ resume 重新派单（…/resume.log 中找不到 [续跑 dev]）
✗ resume 后 dev 窗口回来了（期望 [1]，实际 [0]）
✗ up --agents 才会续跑 agent（…/up-agents.log 中找不到 [续跑 dev]）
```

§15b 改前的 5 条红：

```
✗ 缺依赖不阻塞派单（--print 退出码 0）（期望 [0]，实际 [1]）
✗ dispatch 告警依赖缺失（…/dispatch-deps.log 中找不到 [依赖缺失（不阻塞派单）]）
✗ 告警点名 magic-context（…）
✗ 告警点名 OpenSpec（…）
✗ 告警每次派单只一行（期望 [1]，实际 [0]）
```

§11b4 改前 / 改后同一断言的原因对照（原文）：

```
改前：
/work/skills/teamsmith/scripts/lib/common.sh: line 1340: team_config_model_violation: command not found
/work/skills/teamsmith/scripts/lib/common.sh: line 1367: team_config_model_violation: command not found
✗ TEAM_TASK_MODELS: ；修法：team config set TEAM_TASK_MODELS <完整映射> --yes
TEAM_PM_MODEL: ；修法：team config set TEAM_PM_MODEL <独立模型> --yes
  ✗ P36 ①：模板路径默认把 {resume_args} 渲染出来（[] 里找不到 [--continue]）

改后：
✗ TEAM_PM_CMD: guarded continuation lacks bound {provider}；补完整身份 selector 或显式 fresh 磁盘交接
  ✗ P36 ①：模板路径默认把 {resume_args} 渲染出来（[] 里找不到 [--continue]）
```

### 端到端小现场（任务书要求的那条，`p241-field.sh`）

干净夹具（`team init` + 任务书 + 席位 worktree），`team close` → `team inbox --ack` → 非 fresh 派单：

```
改前 3372602：
  dev.env = [inbox_lines=3 ]        dev.inbox = (absent)
  非 fresh 派单（--print）rc=1
  ✗ dev: legacy/unknown assignment_version；保留磁盘交接，dispatch dev T1.1 … --fresh
  ✗ 共 1 个阻塞项

改后 7353918：
  dev.env = (absent)                dev.inbox = [3 ]
  非 fresh 派单（--print）rc=0
```

同一个现场还覆盖了读侧（`旧键回落` → 3 行新盒 + `inbox_lines=2` 应显示新 1 条；`ack 后 dev.inbox = [3 ]`；截短到 2 行后应重新显示 2 条）与 B2 对照（见下）。

### 验收命令 3：`task-model-routing.sh --select dispatch,resume,transaction,pm,config`

```
$ bash skills/teamsmith/tests/task-model-routing.sh --select dispatch,resume,transaction,pm,config
改前 3372602：RESULT pass=304 fail=0 selected=dispatch,resume,transaction,pm,config
改后 7353918：RESULT pass=304 fail=0 selected=dispatch,resume,transaction,pm,config
```

（两边同值 —— routing 的既有语义没有回退：类别映射、同任务复用记录的 model/SID、换 model 必须 `--fresh`、发布身份不得多于 argv 交付。两次都是真跑的，日志在证据包 `routing-final.log` 与 `routing-before.log`。）

### 验收命令 4：`ledger-ban.sh`

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=1387 hits=0 names=ok user=resolved      RC=0
```

（同一条命令在容器里那份克隆树上跑会拿到 `names=missing` 的**可见跳过**、`RC=3` —— 名单文件不在克隆里；这也是设计如此：缺名单不是通过。两处输出都在证据包，`ledger-ban-final.log` 那行就是克隆树上的跳过。）

### 验收命令 5：`git diff --check && git status --short`

```
$ git diff --check && git status --short
（无输出：没有空白错误，工作树干净）
```

### B2 的两侧对照（只 source `common.sh` vs 全量加载，逐字节）

```
$ bash p241-field.sh <tree> <fixture> <label>        # [5]/[6] 两步
改前 3372602：
  team_pm_launch_cmd rc=1 ；command not found 出现 4 次
  输出首行：…/common.sh: line 1340: team_config_model_violation: command not found
  两份渲染不一致（common=0 字节，all=1177 字节）
改后 7353918：
  team_model_policy_guard rc=0 ；team_pm_launch_cmd rc=0 ；command not found 出现 0 次
  两份渲染逐字节一致（1381 字节）
```

## Flip evidence（缺陷修复必备）

三条修复各自的"破了就红"（每一条都在**副本树上**现做现跑，跑完不还原原树；原树的绿由验收命令 2/3 各自证明）：

| # | 破法（副本树上的变异） | 期望红侧 | 实测 |
|---|---|---|---|
| B3 主修 | `cmd-status.sh` 把 `team_inbox_ack_set "$a" …` 改回 `team_state_set "$a" inbox_lines …` | 记账又落进 assignment 文件 | `dev.env = [inbox_lines=3 ]`、`dev.inbox = (absent)`（现场脚本 `[1]`） |
| B3 防御 | `common.sh` 的 `team_assignment_record_present` 前面加 `return 0`（退回"文件存在就算记录"） | 只有无关键的旧形状文件重新被判 legacy 并拒绝 | `[3]`：`record_present=yes`、非 fresh 派单 `rc=1`（改后是 `record_present=no`、`rc=0`） |
| B3 两处一起 | 上面两处同时回退（= 合并前的形状） | 现场 `[1]` 的端到端拒绝回来 | `dev.env = [inbox_lines=3 ]`、`dev.inbox = (absent)`、`rc=1`、`✗ 共 1 个阻塞项`（文案是新的 `not an assignment record`，因为本任务同时改了判据文案；`3372602` 上是 `legacy/unknown assignment_version`） |
| B2 | `common.sh` 删掉 5 个使用点的 `team_model_shape_require` 调用 | 只 source `common.sh` 的路径又报 `command not found`、渲染为空 | `[5]`：`common.sh: line 1356: team_config_model_violation: command not found`、`team_model_policy_guard rc=1`；`[6]`：common=0 字节 vs all=1065 字节 |

反例（"改完是不是顺手放宽了判据"）——真正的 legacy / 半条记录**照旧**被拒：

```
$ bash p241-field.sh <改后树> …            # [4] 两种形状
  task=T1.1                              → load=rejected diag=[legacy/unknown assignment_version]；record_present=yes；非 fresh 派单 rc=1
  model=…/window=dev/task=T1.1/started=… → 同上
```

`config-cli.sh`（本 change 的 shape 面，也是"判定只有一份"的守卫）：

```
搬走判定本体（最初的写法）：config-cli  ✓329 ✗2   ← F-S1 mutant 打空 + 红侧不再红
最终写法（定义留在 cmd-config.sh）：config-cli ✓331 ✗0   F-S1/F-S2 两个变异都照常绿/红
```

## Decisions and deviations

- **判定本体的位置**：留在 `cmd-config.sh`，`common.sh` 的使用点按需加载（`team_model_shape_require`，幂等；失败时给可读诊断）。理由：`config-cli.sh` 的 F-S1 变异夹具以 `cmd-config.sh` 为落点证明"三条 CLI 路径共用同一判定"，搬走本体会**静默**让那条守卫失去意义（实测 `✓329 ✗2`，smoke §33 会判红）。因此选任务书给的另一条路（"调用点做存在性守卫"），并做到"与全量加载逐字节一致"。
- **sidecar 语义**：`state/<seat>.inbox` 与 assignment 记录**同生命周期** —— `team_state_clear`（`close` / `teardown` / `dispatch --fresh` 的清理路径）连同记录一起删；记录没了就重新从未读展示，宁可重放已读，不可吞掉未读（F26 的既有取向）。
- **升级兼容**：sidecar 不存在时读旧的 `inbox_lines`（升级后不会一次性重放历史行）；写侧只写 sidecar，不再往 assignment 文件写任何记账键。
- **防御判据的键集合**：`team_assignment_field` 认 v1 字段 + `v0.1.2` 的历史字段（`model` / `model_src` / `window` / `worktree` / `task` / `taskfile` / `branch` / `started` / `sid` / `sid_bytes`）；读不了 / 超限 / 含 NUL 的文件**仍按"有记录"**保守处理（不假装文件不存在）。
- **范围外的红**：P240 记过的"选段闭包缺口"（`--select 11c` 单独跑不带 §5、§11b3）本次没有复现 —— 验收命令的 11 个选键展开成 **22 段**运行，§5（add-agent，建 `.worktrees/dev`）与 §11b3（`wait_window_gone` 的定义处）都在运行名单里；这也是 §11c 能 `✓15 ✗0` 的前提。
- **没跑全量门禁**：按任务书的验收命令跑（openspec + 两份容器选集 + routing 五组 + ledger-ban + diff 检查），另加 `config-cli.sh`（改动面：判断"判定只有一份"的守卫）与 `shape flip-shape` 两组。全量留给 PM 的 wrap-up / 复验。

## 未做项 / BLOCKED

- **§11b4 的夹具模板（交回 PM → 夹具侧任务）**：`skills/teamsmith/tests/smoke.sh` 的 `P36_TPL_CMD='mycli run {resume_args} {prompt}'` 是 `P36 ①：模板路径默认把 {resume_args} 渲染出来` 这条断言现在唯一失败的原因。本 change 的 spec（`openspec/changes/task-model-routing/specs/dispatch/spec.md:522`）要求冻结模板消费身份占位符才认 Pi 续跑，产品按 spec 拒绝是对的；夹具要**消费身份占位符**（例如 `mycli run {resume_args} {provider} {model} {session_id} {prompt}`）或把这条断言改到 fresh 档（`--fresh-pm 下模板路径的 {resume_args} 渲染为空` 已经绿）。任务书禁止本任务碰 `tests/**`，故未改。
- **§6i 3 红 / §11b3 1 红**：改前改后同值（既存红，不在本任务的 12 条里）。
- **V25 的分类口径**：B2 被记成"§11b4 1 条"，那条断言在修后仍然红（原因换人）。建议复验时把它按"夹具侧"重分类，别计入产品回归的翻绿数。

BLOCKED:（唯一一项，落在 `skills/teamsmith/tests/smoke.sh`，即 P238 / 夹具侧任务的写集合）

- 谁：持有 `skills/teamsmith/tests/**` 的任务（任务书写明是 P238 一侧）。
- 改什么：`P36_TPL_CMD` 消费身份占位符（或把该断言移到 fresh 档）。改完 §11b4 应为 `✓33 ✗0`。
- 依据：`container-after-final.log` 的 §11b4 段（`✗ TEAM_PM_CMD: guarded continuation lacks bound {provider}…`）与 spec `task-model-routing/specs/dispatch/spec.md:522`。
