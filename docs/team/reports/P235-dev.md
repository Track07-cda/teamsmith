# P235 · task-model-routing · S3：init/bootstrap 前门、模板与指引、路由夹具

agent: dev   status: DONE   time: 2026-10-12 08:10 UTC
task: P235   change: task-model-routing   phase: apply   deltas: init-skill
branch: `task/P235-routing-init-s3`   PR/MR: -（local 模式，无远端；分支留在本地等 PM 复验后合并）

一句话：初始化前门收口 —— `team init` / `team bootstrap` 现在**必须**拿到
`--task-models '<类别=provider/model …>'` 与 `--pm-model '<provider/model>'`（没有默认模型可猜），
两个值走同一个校验器和同一个加固写入器逐字落盘；缺输入、非法输入、以及**配置里还留着退休键**
的旧项目，一律在任何写入（配置 / 账本 / 装 skill / worktree / pulse）之前停住并给出一条真能走的路线；
模板、两处任务书入口、PM/worker 指引、README 与迁移指南同步改成「任务类别 + 独立 PM 模型」的口径，
退役的 `TEAM_AGENT_MODELS` / `TEAM_DEFAULT_MODEL` 在模板里彻底消失。路由夹具新增 `init` 组 44 条断言
与两条具名翻转红臂，适配后的选段门禁在本分支上除**继承自 base 的红项**外全绿。

## Deliverables

| Path | What | Commit |
|---|---|---|
| `skills/teamsmith/scripts/lib/cmd-project.sh` | 退休键闸门 + `team_init_model_policy_resolve`；init 的 `--task-models/--pm-model`、`--model/--default-model` 退休、显式输入与现有策略不同即拒、下一步提示带 `--category` | `d5868f0` `ec2616a` `ddd0d6b` |
| `skills/teamsmith/scripts/lib/cmd-bootstrap.sh` | 同一闸门（含 `--print` 只诊断不写）+ 两个必填旗标 + 计划里点名必填输入 + 透传给 init + 下一步提示带 `--category` | `d5868f0` `ddd0d6b` |
| `skills/teamsmith/templates/config.sh.tmpl` | 两个**新必填键**（`TEAM_TASK_MODELS` / `TEAM_PM_MODEL`）取代 `TEAM_AGENT_MODELS` / `TEAM_DEFAULT_MODEL`，注释写明类别地图、单类别写入器、升级事务、独立 PM 模型 | `d5868f0` |
| `skills/teamsmith/templates/BOARD.md.tmpl` | 建行示例与工具行带 `--category`（否则模板教人建出派不出去的任务书） | `ddd0d6b` |
| `skills/teamsmith-init/SKILL.md`（100 行）、`references/bootstrap.md`、`templates/bootstrap-prompt.md.tmpl` | 问卷第 2 条换成「类别映射 + 独立 PM 模型」，写明旧键拒绝与 `config upgrade-models` 路线；安装节/共享链接影响/四个独立门 | `a60f91b` `ddd0d6b` |
| `skills/teamsmith/templates/{pm-prompt.md,PROTOCOL.md,AGENTS.section.md,task.md,OWNERSHIP.md,memory-seed.md}.tmpl` | 类别选择纪律、共享配额、磁盘交接、`--fresh-pm`、四个独立门、owner 表与「席位不是模型」 | `a60f91b` |
| `skills/teamsmith/references/{config.md,protocol.md,workflows.md,migration.md,agent-adapters.md}`、`skills/teamsmith/SKILL.md`、`README.md` | 键表/命令面/§5 §6/§5b 破坏式升级、adapter 示例、日常 skill 命令表 | `a60f91b` `9275e27` `ec2616a` |
| `skills/teamsmith/tests/lib/model-policy.sh` | 夹具配置渲染器改成新两键（不再删旧键、不再插 `TEAM_DEFAULT_MODEL`） | `9275e27` |
| `skills/teamsmith/tests/config-cli.sh` | `--model` 退休 / `set-agent-model` 退休 / `--model` 不再改造 state 记录（P105/F2 场景重指向） | `a60f91b` |
| `skills/teamsmith/tests/task-model-routing.sh`、`tests/lib/model-routing-flips.py` | 新 `init` 组 44 条 + 两条具名翻转臂（`init-legacy-proceeds`、`template-retired-key`） | `a60f91b` |
| `skills/teamsmith/tests/smoke.sh`、`tests/install-shape.sh` | 夹具适配：必填模型输入、`team task --category`、完整 assignment 记录、PM 身份记录、M14 重指向；§29 标题同时改到两份登记表 | `9275e27` `459733d` `4802123` `ec2616a` `85a20bd` |
| `docs/team/reports/P235-dev.md` | 本报告 | 本报告的提交 |

## 实现要点（对照 delta 的 S3 需求）

### `init-skill#Initialization teaches category policy and breaking upgrades without live adoption`

- **新鲜项目必填、逐字渲染**：两个值先用唯一写入器的同一个校验器（`team_config_validate_value`
  → `team_task_map_violation` / `team_config_model_shape_ok`）验，再用 `team_config_set_in_file`
  写进渲染出的配置；任一步失败删掉这次的半成品配置并 rc=1，绝不留下缺键的契约。
  实测：`init --task-models 'maintenance=vendor/light audit=vendor/audit:high' --pm-model 'vendor/pm:max'`
  → rc=0，配置第 22/24 行使这两行（单引号形式），模板里没有旧键可写。
- **拒绝发生在任何写入之前**：缺输入 → rc=4，且 `config/docs/state/skills` 全都没生成；
  非法输入（`notamap`、`badshape`）同样 rc=4 且不落盘；退休旗标 `--model`/`--default-model` → rc=2，
  诊断点明新入口与升级事务。
- **重入零变化**：已有**合法新策略**的项目不带输入重入 rc=0，配置逐字节不变；显式输入与现有策略
  不同则 rc=4（不静默忽略）并指向 `config set-task-model` / `config set TEAM_TASK_MODELS --yes`。
- **旧项目不是迁移路径**：配置里还留着 `TEAM_AGENT_MODELS` / `TEAM_DEFAULT_MODEL`（真赋值行，
  注释里提到不算）时，`init`、`init --force`、`bootstrap`、`bootstrap --print` 全部在**任何写入之前**
  rc=1，点名两个键、点明「init/--force/bootstrap 都不是迁移路径」、指向
  `team config upgrade-models … --dry-run`；账本与身份哈希不变、`--print` 依旧只读。
- **模板与指引不含旧口径**：config 模板只剩新两键；两处任务书入口（`team init` 下一步清单、
  `bootstrap` 下一步清单、`BOARD.md.tmpl` 建行示例、两个 skill 的 bootstrap 提示词）都带 `--category`；
  OWNERSHIP 的 owner 表删掉「Model」列并写明「席位是名册里的名字，不是模型」；PM/worker 提示词、
  PROTOCOL、protocol §5/§6、workflows、README、日常 skill 命令表统一讲任务类别选择、共享配额、
  磁盘交接、`--fresh-pm` 与四个独立门；`references/config.md` 明确 `team task --category` 只是
  任务书生成器、不是派单覆盖。
- **本仓不是共享源落地**：本刀只在自己的 worktree 里改私有树，没动 `~/.agents/skills/teamsmith`
  的目标内容、没跑安装器、没重启任何进程（共享链接读取的是**目标当前字节**，这一点写进了
  `migration.md` §5b 与 `pm-prompt`，并明确「未知消费者不做零影响承诺」）。

### 夹具与守卫（同刀）

- 新 `init` 组（`task-model-routing.sh --select init`，44 条）：显式输入逐字渲染 + `config list --json`
  机器可读策略；缺输入/非法输入/退休旗标在任何写入前拒绝；合法策略重入保留；旧键的四种命令全拒且
  身份+账本+无副作用；新鲜 bootstrap 写入、`--print` 只读；共享源与私有集成树哈希不变、链接不变；
  三个指引文件分别含共享链接影响、四个独立门、owner 不是模型。
- 两条**具名**翻转臂：`init-legacy-proceeds`（让 init 在旧键下继续跑）→
  `init-legacy-plain-refused` / `init-legacy-force-refused` / `init-legacy-bootstrap-refused` 三条同时变红；
  `template-retired-key`（把 `TEAM_DEFAULT_MODEL` 写回模板）→ `init-fresh-no-retired-key` 变红；
  pristine 树同一组 44/0。

### smoke/其他夹具的适配（P235 口径）

必填模型输入让一批把 init/bootstrap 当脚手架用的夹具必须显式给输入：`smoke.sh` 里 33 处 init + 5 处
bootstrap 走统一的 `P235_MODELS` 常量（PM 模型故意用历史值 `deepseek/deepseek-flash`，让
「渲染逐字节一致」的适配器断言继续有参考值），M11 真 tmux 沙箱那条单独补全；`team task` 夹具一律加
`--category routine`（否则生成的任务书不可派单，会连锁带红十余段）。S1 的两条新规则让另一半夹具必须
给**完整现场**：`team_state_set dev task <ID>` 写的半条记录会被认成 legacy/unknown assignment 直接挡住
派单，故 §3b 用新的 `smoke_assignment` 写整条 v1 记录；§6i 的 PM 续跑渲染前按产品自己的发布函数
（`team_pm_metadata_publish`）写一份与当轮环境一致的 identity 记录（续跑档），§6j 的三条 `--print`
夹具改用 `--fresh`（同一任务上换掉启动身份本来就该显式 fresh）。§29/M14 从「配置压过旧记录」重指向为
「映射管新选择、已提交的记录管续跑、未映射类别拒绝、roster 显示启动身份或 `unavailable`」。

## 验收命令与真实输出

```
$ bash skills/teamsmith/tests/task-model-routing.sh --select init
PASS init-guidance-ownership-not-model
RESULT pass=44 fail=0 selected=init

$ grep -rn 'teamsmith-init' skills/teamsmith/templates/config.sh.tmpl \
      skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl
（无输出，rc=1）                      # 模板不依赖 init skill（delta 场景）

$ wc -l < skills/teamsmith-init/SKILL.md
100                                   # ≤100 行预算

$ openspec validate --all --strict
✓ change/task-model-routing … Totals: 14 passed, 0 failed (14 items)

$ bash skills/teamsmith/tests/install-shape.sh surfaces
== 结果 ==  ✓ 10  ✗ 0  SKIP 0
```

```
== A. 新鲜 init（显式输入） ==
✓ write .../a/.pi/team/config.sh
…
 3) team task T1.1 --title "第一个任务" --category <类别> --agent dev
rc=0
22:TEAM_TASK_MODELS='maintenance=vendor/light audit=vendor/audit:high'
24:TEAM_PM_MODEL='vendor/pm:max'
（配置里没有 TEAM_DEFAULT_MODEL / TEAM_AGENT_MODELS 行）

== B. 新鲜 init（缺输入） ==
✗ init: 缺少 --task-models（项目类别映射是必填输入；没有默认模型可猜）
  新项目：team init --task-models '<category=provider/model …>' --pm-model '<provider/model>'
  已有项目：team config set-task-model <category> <model>（或 config set TEAM_TASK_MODELS '<完整映射>' --yes；破坏式升级走 config upgrade-models）
rc=4
after: config=absent docs=absent state=absent skills=absent

== C. 旧键配置：init / init --force / bootstrap / bootstrap --print ==
rc=1 cmd=init --no-skills --session c --agents dev
    ✗ init: …/config.sh 还在用退休的模型键（TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS）—— 任何写入之前停住
      项目模型策略是破坏式升级：init / init --force / bootstrap 都不是迁移路径
rc=1 cmd=init --no-skills --force --session c --agents dev --task-models routine=p/new --pm-model p/pm
rc=1 cmd=bootstrap --no-pulse --agents dev
    ✗ bootstrap: … 还在用退休的模型键（TEAM_DEFAULT_MODEL TEAM_AGENT_MODELS）—— 任何写入之前停住
rc=1 cmd=bootstrap --no-pulse --agents dev --print
no side effects: skills=absent worktrees=absent state=absent（账本与配置哈希不变）

== D. 合法新策略重入（不带输入） ==
rc=0 policy unchanged: yes
rc=4 (显式输入与现有不同 → 拒绝)  policy still unchanged: yes

== E. 新鲜 bootstrap --print（只读） ==
rc=0
    5:  模型策略    <新鲜项目必填：--task-models '<category=provider/model …>'> ［独立 PM：<必填：--pm-model '<provider/model>'>］
   11:  1. team init … --task-models '<category=provider/model …>' --pm-model '<provider/model>'（新鲜项目必填）
wrote nothing: config=absent docs=absent
```

选段门禁（`bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only 611f72d..HEAD)`，
decision=RUN、125 段选中；本轮实跑 **76 段 / ✓3036 ✗34**，收尾账本自查「增量 ✗34 ｜ 结果行 ✗34 —— 一致」
且「P70 对账：本套没有触发过超时」；未跑的 48 个键清单与 base 那轮选段运行逐字相同，是选段判定的
固有形状，不是本刀跳过）：

| 段 | 结果 | 说明 |
|---|---|---|
| 0e · 段落自述：看门狗/预算表/循环清单（P70） | ✓ 23 ✗ 0 | 收尾修复后（见下节） |
| 2 · init | ✓ 42 ✗ 0 | 模板/渲染/幂等全绿 |
| 33 · 项目契约的读写面（P22/B1） | ✓ 1 ✗ 0 | 内嵌 config-cli.sh 全部 347 条断言绿 |
| 39 · npm CLI 与项目 skill 安装（P40） | ✓ 1 ✗ 0 | 内嵌 install-shape.sh 10 条断言绿（含翻转两侧） |
| 29 · 派单模型解析：映射管新选择…（M14） | ✓ 25 ✗ 0 | 本刀重指向后 |
| 12k · 模板与文档 | ✓ 32 ✗ 0 | 任务书模板 + 账本模板断言 |
| 12b · 延后投递与草稿入口 | ✓ 87 ✗ 0 | |
| 1c / 4 / 4b / 4c / 6 / 6d / 6e / 3b | ✓ 全绿 | 最少的 3b 也有 58 条断言 |
| 11h / 15b / 15c / 12b-pi / 18b | ✓ 全绿 | 含「信号与承诺的诚实（V4.0）」「doctor 三态 + 预检」「harness 只告知不推荐」「输入框判据」 |
| 6f / 6i / 6j / 12b-h0c / 25 / 26 / 31 / 36 | ✗ 34 | **全部继承自 base**，见下节 |

## 翻转证据（缺陷修复证明）

**① 红 → 绿（本刀的核心行为）**：把「缺失的必填输入」这条路走一遍，改动前后的对照就是红/绿两侧 ——
改动前同一个仓库的命令不写任何东西却打印一条「假成功」的下一步清单；改动后（当前分支）：

```
$ team init --no-skills --session <s> --agents dev --vcs local --gates true
✗ init: 缺少 --task-models（…）；rc=4；config=absent docs=absent state=absent skills=absent
$ team init … --task-models 'routine=vendor/light' --pm-model vendor/pm    # rc=0，两行逐字落盘
```

**② 破坏实现 → 守卫必须变红**：新增两条具名翻转臂，各自对**同一份 pristine 夹具**跑出绿、对影子树跑出红：

```
$ TEAM_ROUTING_TREE=<影子树> bash skills/teamsmith/tests/task-model-routing.sh --select init
FAIL init-legacy-plain-refused          # 影子：init 在旧键配置下继续跑（不拒绝）
FAIL init-legacy-force-refused          # 影子：init --force 同样继续
FAIL init-legacy-bootstrap-refused      # 影子：bootstrap 同样继续
$ … --select init                      # pristine 树
RESULT pass=44 fail=0 selected=init
```

`template-retired-key`（把 `TEAM_DEFAULT_MODEL` 写回模板）→ `FAIL init-fresh-no-retired-key`；
两臂都在 `--flip` 全流程里注册（`flip_arm_summary` 会点名红臂的名字，不是「随便红一条」）。

**③ 夹具适配期的实测红 → 绿**：`--select 3b,6i,6j,29` 在本刀适配前分别红 25 / 32 / 23 / 18 条；
按上面三条规则（整条 assignment 记录、按当前环境发布 identity 记录、显式 `--fresh`）修好后
分别 58/0、124/3、37/1、25/0（余项见下节）。

## 继承的发现（不在本刀范围，带 base 对照证据）

下面 8 段是本轮唯余的红项（共 34 条）。它们在 **base 提交 611f72d**（S1/S2 已落地、夹具未适配的树）
上**同样红，且数字相同或更好**（本刀自己的夹具适配把红项压了下来）；对照运行的日志都在
`.pi/team/state/bg/` 下：

| 段 | 本分支 | base 611f72d | 证据 / 性质 |
|---|---|---|---|
| 6f 提示词通知段 / `{summary}` 文件通道 / 敌意摘要逐字节送达 | ✓ 114 ✗ 21 | ✓ 79 ✗ 57 | `p235-base-smoke.log`；同一批断言文本（worker 通知段与 `--from-file` 选路整体未接通，属交付面/适配层） |
| 6i PM adapter 的 `{resume_args}` 文案与 argv，以及「启动失败时窗口不该连诊断一起被杀」 | ✓ 124 ✗ 3 | base 的 6i 因超时中止（rc=2），可见红里已含同一对 `resume_args` 断言 | `p235-base-6ij.log` |
| 6j worker adapter 的同一「窗口被连诊断一起杀掉」断言 | ✓ 37 ✗ 1 | base 未跑到（上一段 rc=2 停跑） | `p235-base-6ij.log` |
| 12b-h0c P59「叫醒语入队而不是粘字」/「队列恰好一条」 | ✓ 123 ✗ 2 | ✓ 123 ✗ 2（逐字相同） | `p235-base-12bh0c.log` |
| 25 M9.8「待复验 1」「未读通知 1」「磁盘代码变化」三条唤醒计数 | ✓ 53 ✗ 3 | ✓ 53 ✗ 3（逐字相同） | `p235-base-25-29.log` |
| 26 面板 g：`session_tokens` / `elapsed`（需要真实会话文件） | ✓ 146 ✗ 2 | ✓ 145 ✗ 3 | `p235-base-263136.log`（base 还多一条红） |
| 31 M28 真树里未隔离的 tmux 变更命令 | ✓ 11 ✗ 1 | ✓ 11 ✗ 1（逐字相同） | `p235-base-263136.log` |
| 36⑧ 产品面检出探针 | ✓ 115 ✗ 1（17 条子探针） | ✓ 113 ✗ 3（18 条子探针） | `p235-base-263136.log`（base 多一条子探针红） |

这些红项不在本刀范围（adapter / 交付面 / 面板），本刀只是一条也不弱化：没有删断言、没有加 skip、
没有放宽判据。

## 不在本刀范围 / 需要 PM 裁决

- 上表 F1–F3 是 change 内其他刀（S1/S2 adapter 与 delivery 面）的红项，本刀不改它们的实现。
- `openspec/changes/task-model-routing/tasks.md` 与 delta 文件：按任务书分刀，PM/其他刀负责勾选。
- 共享源落地（`~/.agents/skills/teamsmith` → 本仓）与任何安装/重启/他项目采用：本刀一律未做，
  是否授权见 `migration.md` §5b 的四个独立门与任务书边界。

## 收尾阶段自己引入的一个缺陷（已修）与两个中止的运行

**1）§0e 登记表缺陷（我引入，已修）**：我把 §29 的标题改成「映射管新选择，已提交的记录管续跑（M14）」，
却漏了两份登记表 —— `section-budgets.tsv`（P70 预算检查逐字比对 `section "…"` 与表里的标题）与
`section-paths.tsv`（选段/检出探针按标题认段）—— 于是全路径运行报 `§0e ✗2`（「P70 预算检查：干净树绿
（期望 [0]，实际 [1]）」+ 它的还原臂）。修法是把三处标题一起改（`85a20bd`），修后定向复跑
`--select 0e,29,34,36`：§0e 23/0 ✓、§29 25/0 ✓、§34 27/0 ✓；随后完整运行里 §0e 也是 23/0 ✓。
这条缺陷是真实事故，不是环境噪声：改标题必须同时改两份登记表。

**2）第一次全路径运行中止（`p235-acceptance`，rc=2）**：除上述 §0e 红项外，在写段 #34（键 15b）
因 **超时 105s / 预算 104s** 停跑；当时机器 load average 13–30（我在并排跑 base 对照与定向运行），
实际最后进度停在 89s。修复后重跑的那一轮里，同一段 15b 只用 33s（✓26/0），收尾还打印
「P70 对账：本套没有触发过超时」—— 说明那是负载导致的超时，不是断言失败；但我把它如实记下来，
并把**未中止的那一轮**（`p235-acceptance2`）作为本报告的验收依据。

## 给 PM 的复验提示

1. 主要验收日志：`/tmp/p235-acceptance2.log`（未中止的 76 段全量，✓3036 ✗34）、
   `/tmp/p235-target.log`（修后的定向复跑 0e,29,34,36）；副本在 `.pi/team/state/bg/` 下
   （`p235-acceptance.log` 是中止的那一轮）。base 对照：`.pi/team/state/bg/` 里的
   `p235-base-smoke.log`、`p235-base-25-29.log`、`p235-base-12bh0c.log`、`p235-base-6ij.log`、
   `p235-base-263136.log`；base 树是 `/tmp/p235-base` 的 611f72d 只读克隆。
2. 独立复验时 `--paths` 的那一轮请以本报告的段表为准；`--select 29`、`--select init` 与
   `task-model-routing.sh --select init` 是最快的三处定点。
3. 红线遵守：未推送任何分支、未 merge、未改仓库设置；分支 `task/P235-routing-init-s3` 留在本地。
