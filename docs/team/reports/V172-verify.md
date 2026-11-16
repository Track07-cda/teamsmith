# V172 · 正常路由及五项参数检查去重方案独立审阅

agent: verify · phase: opsx-verify · status: DELIVERED（仅方案审阅）
latest assessment: 2026-11-16T14:43:23Z · verdict: **ACCEPTED（规划）**
first assessment: 2026-11-16T14:21:49Z · verdict: **REWORK**（原件及四项保留如下）
branch: `task/V172-routing-parameter-proposal-review` · PR/MR: -
change: `routing-parameter-check-dedup`
latest candidate: `2c4f86d1b146a82b0fc99f0652386beb9629d239` · checkout: `/var/tmp/p467-review-2c4f86d1`
first candidate: `824cfd82ae339214261c88b2f72d2397810bb363` · checkout: `/var/tmp/p467-review-824cfd82`

**当前结论：四项均已关闭，无剩余必要返修。** 本次只复看 `824cfd82..2c4f86d1` 的 C1/C2/W1/W2 及直接矛盾，新 change strict 通过；详见文末差异复看。此 ACCEPTED 仅供 PM 接受规划，不是行为通过、apply 授权或归档就绪。

## 首轮结论与最小返修（历史 REWORK）

**REWORK：共用直接参数断言和五臂轻量入口的方向可行，但两条真实调用见证会在计划观察的位置之前被拒绝；42 次负向 CLI 仍有可直接删除的双模式重复；旧完整 61b 场景还没有明确限定到已完成的前批验收。** 本 change 严格结构校验通过，不等于这些行为已经证明。

只需作者 dev2 修同一组规划工件，无须实验、产品修改、新框架或再跑长测试：

1. 将两个 `extra-consumes-*` 的模板 list 接线见证替换为已有、能通过 standalone extra 检查但会被周围模板角色拒绝的输入，详见 C1。
2. 把 PM 旁路对象改成有效的整段写前拒绝边界，或明确直接调用真实 `team_pm_start` 的前提，不能只删它内部一条调用后再从 `up` 验，详见 C2。
3. 取消全部 21 个 tag 默认 preview/launch 双跑；每个 tag 只走一个必要模式，PM 独立 preview 分支留一个代表即可。21 次 launch 加一个 PM preview 是一种 22 次的具体安排，不是新配额，详见 W1。
4. 在完整 MODIFIED 块的旧 routing-argv 场景中明确“前批已完成的完整 61b 原件”，本批使用新受影响验收；不删除旧义务，也不再次执行它，详见 W2。

上述四项改变接受结论。其余共用函数、同副本健康/原故障/恢复、原父级消费和一次非作者验收安排可保留；不要求作者先运行未来的正常组、五臂或完整 61b。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V172-verify.md` | 独立方案结论、四项最小返修、源调用链依据及实际静态检查回执 |
| `/var/tmp/v172-verify.W3ZzNz/` | 本轮版本、结构校验 stdout/stderr/rc、候选身份和只读规格盘点；临时原件，不加入仓库 |

候选、主检出、规划工件、正式规格及产品/测试文件均未修改；本任务分支只写本报告。

## CRITICAL

### C1 · 两个 list 接线见证到不了模板角色判定

**影响：当前清单会把“extra 本身缺一个工具参数值”误当成“模板中的 argv-list 被错误解释”的真实调用证据；模板 list 检查失接时，这两个 CLI 仍可正常报拒绝。**

- 规划定位：`design.md:57,59,68` 留 worker `extra-consumes-model` fresh 和 PM `extra-consumes-resume` continued，声称覆盖 F5 scalar/list；原输入来自 `tests/lib/model-routing-roles.sh:43–64`，extra 均为 ` --skill`。
- 产品定位：worker 在 `scripts/lib/cmd-agents.sh:1162` 调用 `team_identity_extra_guard`；PM 在 `scripts/lib/common.sh:3266` 调用同一函数，均早于模板角色检查。该函数在 `common.sh:1937` 先用 `team_argv_roles_guard 0` 判 standalone extra；`common.sh:1917–1921` 对末尾孤立 `--skill` 的空值立即拒绝。
- 因而实际拒绝来自 standalone extra，而非 `common.sh:1956–1969` 将 `{extra_args}` 展入周围模板后的角色证明。配置 writer 接受这条字符串，也不能改变这个调用顺序；期望 rc=1、原诊断和状态不变仍可能全部满足。

**最小修订：** 直接用同一旧 faults 数组已有的 `extra-unknown-before-model` / `extra-unknown-before-resume`，extra 为 ` --unknown harmless`。从源码看，standalone extra 没有后续受保护参数，可通过现有 guard；放回原模板后，未知参数后面出现 `--model {model}` 或 `{resume_args}`，才由模板角色检查拒绝。保留现有 worker `model:--skill`、PM `provider:--skill` 和两个 resume-role 真实见证承担 scalar/恢复角色，不新增字符串矩阵。固定输入与预期诊断应随表明确；本轮没有运行该替换样本，最终实际结果仍由实施后的统一独立验收取得。

本项只要求换已有两个真实见证，不改变 197 个直接规则输入的盘点，也不要求单删每个冗余 guard 必红。

### C2 · PM start 的单点旁路被真实 up 的更早检查遮住

**影响：按当前 design 的 PM start 旁路，从真实 `up` 调用会在到达被改位置之前退出，不能证明计划所说的“写前检查丢失能被观察到”。**

- 规划定位：`design.md:123` 点名“PM start 的首道 identity 检查及最终 renderer”，Context 指向 `common.sh:3798`，而正常见证通过 `run up` 执行。
- 实际链路：`scripts/lib/cmd-watch.sh:338` 是 `up --print` 的 identity 检查；真实 `up` 在 PM 已停止的分支先执行 `:373`，通过后才在 `:408/420` 调 `team_pm_start`。后者再在 `common.sh:3798` 判 identity，`:3806` 写 prompt，`:3813` 调最终 renderer，renderer 在 `:3662` 再判 identity。
- 只旁路 `:3798` 时，`:373` 仍对同一坏输入给出同一参数拒绝；rc/诊断/快照都不必改变。design 末尾“被别层提前拦住就标未观察”不会制造假成功，但这是现已可定位的缺口，不应留到唯一行为验收才退回。

**最小修订：** 若继续由真实 `up` 验，定义一个有效的 PM real-up 写前边界：在同一私有副本一起旁路 `cmd-watch.sh:373` 和 `common.sh:3798`，保留真实函数和最终 renderer；用已有 custom PM 坏模板见证检查 prompt/诊断发生变化。或者明确在已有私有场地直接调用真实 `team_pm_start`，避开外层 up 的预检并保留其窗口/停止状态/合法 policy 前提。二选一即可，不要求两个方案都跑、不补其它入口矩阵，不要求删除冗余单点必红。正常 `up` 真实拒绝仍由表中见证保留。

## WARNING

### W1 · 每条见证再乘 preview/launch 仍在重复同一事实

**影响：`design.md:47–49` 和 `tasks.md:8,13` 将 21 个 tag 一律做成 42 次 CLI，即使两次都在模式相关动作前拒绝；这部分可以在不删除输入类别的情况下继续缩小。**

worker 的选择、字段判定和模板预检在 `cmd-agents.sh:1346–1390`，`--print` 相关写盘分歧在 `:1405–1407,1427–1429` 之后。对这些坏输入，preview/launch 的字符串规则、拒绝诊断和状态纯净性是同一前提下重复观察。PM 的 preview/real 确有 `cmd-watch.sh:338/373` 两条不同入口，但不必为所有 PM 字符串各重放一遍来证明这两个调用点。

**最小修订：** 去掉“每个 tag 两模式”的总规则；21 个 tag 各留一次实际 launch，另用一个已有 PM 坏模板覆盖独立 preview 检查即可，即一种可行清单是 22 次而不是 42 次。也可将部分 tag 分配为 preview，只要独立调用事实有明确归属；本报告不要求固定 22 个 PASS 或保留某个冗余组合。原合法 selector/argv/fresh/continued/metadata/撤销检查都不动。同步 proposal/design/tasks 和新场景的 preview/real 措辞，避免实施者仍照 42 次执行。

562、42、197 的现有算术本身无误；本项反对的是 42 的选择理由，不是拿另一个数替代永久配额。

### W2 · 新例外和旧“候选完整 61b”场景仍有适用对象冲突

**影响：新正文禁止本批重复旧验收，但完整 MODIFIED 场景仍可被读成要求新候选再提供一次完整 61b；这与 design/tasks 的一次受影响验收不一致。**

- 新 `specs/verification/spec.md:88–93` 明确本批只做变更后的 boundary、五故障/恢复、调用边和父结果，不要求重付完整 CORE/61b。
- 保留场景 `:132` 仍要求 `one final complete 61b integration run`；`:227` 仍写 `the candidate's complete 61b log`；`:241–242` 仍无批次限定地要求 `one final non-FAST complete 61b integration run` 供应 first CORE 和所有变异证据。
- P457/V163 已完成该前批义务。已读 `docs/team/reports/V163-dev3.md`：原完整 61b 为父 206/0、baseline 3140/0、31 臂、rc=0，合并 SHA `f5836f23f1758ec6bd77a2a3f447e6b7b6884532`；本轮仅引用既有结论，没有重新运行或再做长原件审计。

**最小修订：** 在上述旧场景局部明确其约束的是 routing-argv 替换批次，完整日志是已接受前批原件；后续 routing-parameter 批次按新场景取得变更事实，未改部分引用旧证据。保留旧场景标题与原完成义务，不删除旧证据、不再强求新候选完整日志、不重开旧三处已完成验收。

## SUGGESTION

None。没有建议新增 guard、runner、长期计数器或另一轮测试。

## 六项审阅问题的其余结论

以下是源码及规划一致性判断，不是行为实证。路径前缀 `tests/`、`scripts/` 均为 `skills/teamsmith/`。

| 问题 | 结论与依据 | 对方案的影响 |
|---|---|---|
| 共享直接断言/四文件是否足够 | `common.sh:1866–2044,3238–3263` 的 literal/extra/template/role/resume 函数可由传入字符串和显式 extra/resume/mode 变量执行；所需函数及错误输出函数都在同一 common 文件。template 自己处理 role 数组，无须复制 tokenizer；`tests/task-model-routing.sh:51–63` 已示范在完整项目准备前短分支，原 `check` 在 `:45` 累加父 shell 计数 | 接受 design §1 的子 shell 隔离 scratch arrays/错误状态、调用 shell 消费真实 rc/固定期望；正常 boundary 只调用同一规则一次。无需产品改动或源加载平台 |
| fresh/continued 与盘点 | worker 29 项两模式扣一个 fresh 合法部分绑定输入，负例 57；PM 21+7=28；展开 13×3+7=46；roles 25+26+7=58；extra 8，总数 197。`common.sh:2034–2042` 的 continued 完整性晚于角色/绑定检查，不能把 worker/PM 全部 fresh/continued 合并 | 接受这些直接输入及独立固定成功期望；数目只是清单。真实双模式按 W1 删除重复，不回补旧 PASS 总数 |
| writer、F3/F4/F5 真实对象 | `cmd-config.sh:429–445` 的 tpl 写入校验是空白/换行/未知占位符，不是模板身份 guard。清单的 hardcoded、positional、data、model-glob 使用已知占位符/无新 placeholder，未见必须绕过 writer 才能进入的语法；extra/resume 是 cmd 类型。原 `roles.sh:22`、`expansion.sh:209–214` 已有带前导空格写参数及同 resume-key publisher 前提 | 不建议绕过 writer、stub guard 或把 setup 拒绝记为 caller 成功。F3 四个 template/extra model-glob、F4 worker/PM 错绑、F5 scalar/resume 对象有依据；两个 list 见证按 C1 换已有输入 |
| 五原变异、恢复及父结果 | `model-routing-flips.py:73–82,108–130` 的五变异均只改 scripts/common 中的现有规则；design §5 的新失败名对应 direct 规则而非旧 launch 名。父级原 `flip_run`/rc=1 检查/必需名/脚本恢复在 `task-model-routing.sh:1422–1553`。对五臂扩展已有 healthy/restored case 即可，每份副本恢复 scripts 足以覆盖这五变异 | 接受原变异保持、同副本 0→1→0、异常 rc/timeout/缺名及健康/恢复失败由原父级消费。当前只是静态可行，未来仍须真实一次取得原五臂 |
| 私有父级/回放是否过重 | design §Migration 2–3 只收窄现有 loop 和 baseline selection，其余父级执行/消费保持字节；一次执行同时得到五臂，不先另跑。短回放使用同一实际消费代码及已取得日志/rc，不重放业务 | 可接受为一次性验证包；不需要永久提取 helper 或通用回放平台。实现验收需核所提取的实际代码及入口/出口，不能用手写 eq/grep 算法冒充原父结果 |
| 一次非作者验收与合并后 | `tasks.md:7–15` 作者静态、非作者一次 changed boundary/五臂及旁路，合并后同一性加短 parameters；未改组/前批两 argv 样本引用旧证据。六个新场景均有任务映射；本轮四规划工件齐、六项未来任务未勾符合 propose 阶段 | 接受此分工，不要求作者再实跑一遍、合并后再跑长套或引用旧证据就重验。只修 C1/C2/W1/W2；历史 3323s/575s 不合成净节省 |

只读规格盘点确认：一条完整 MODIFIED 需求，旧 17 个场景标题均在，新 6 个，共 23；没有缺失旧场景。候选相对 `a7dd6297` 的变更路径仅 change 五工件及作者报告，不含产品、配置、smoke/CI/选择表、其它 change 或发布对象。

## OpenSpec assessment

本任务是规划审阅，非实现完整性验收。自己的工作树未生成 `.pi/skills/openspec-verify-change/SKILL.md` 和 `.pi/prompts/opsx-verify.md`，按 `skills/teamsmith/references/openspec.md` 的等价 completeness/correctness/coherence 与分级流程审阅；未初始化或安装任何工具。

| Dimension | 状态 | Evidence |
|---|---|---|
| Completeness | 规划 4/4；未来 6 项未实施符合阶段 | proposal/design/tasks/完整 delta 均已读；旧17+新6场景清单及 tasks 1.1–2.3 映射，无需为审方案执行 apply |
| Correctness | REWORK：两处见证不能建立声称的调用前提 | C1 standalone extra 先拒绝；C2 up 在 start 前拒绝；皆为源码推论，本轮未运行任何路由样本 |
| Coherence | REWORK：双模式去重不足和旧场景批次限定待补 | W1 42次默认双跑；W2 新正文与旧完整61b场景；其余四文件边界/原五变异/独立一次验收可保留 |

## Verification evidence

### 本轮实际版本与严格结构检查

环境：`PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。在固定独立检出执行唯一一次本 change 结构校验；未执行全仓 strict/status/试归档或实现门禁。

```text
$ openspec --version
1.16.0
stderr: empty
rc=0
$ (cd /var/tmp/p467-review-824cfd82 && openspec validate routing-parameter-check-dedup --strict)
Change 'routing-parameter-check-dedup' is valid
stderr: empty
rc=0
$ git -C /var/tmp/p467-review-824cfd82 rev-parse HEAD
824cfd82ae339214261c88b2f72d2397810bb363
$ git -C /var/tmp/p467-review-824cfd82 status --porcelain=v1
(empty; 0 bytes)
```

原件：`/var/tmp/v172-verify.W3ZzNz/{version,structure}.{command,stdout,stderr,rc}`，以及 `candidate.sha`、`candidate.status`、`checked-at.txt`。只读 Python 规格标题/清单算术盘点输出保存为 `source-audit.json`，完整同名需求文本差异为 `requirement.diff`；该盘点未调用产品函数或参数样本。

```text
old_scenarios=17 delta_scenarios=23 missing_old_scenarios=[]
old_potential_negative_cli=562
planned_negative_cli=42
planned_direct_negative_inputs=197
```

### 自己报告的交付检查

报告暂存后，在自己的稳定工作树各执行一次，stdout/stderr/rc 保存于同一临时根的 `ledger.*`、`diff.*`、`cached-diff.*`。下列 root/名单路径中的 `<user>` 是扫描器原有隐去用户名格式，没有读取名单内容。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2819 hits=0 names=ok user=resolved
$ echo $?
0
stderr: empty
$ git diff --check
stdout/stderr: empty
rc=0
$ git diff --cached --check
stdout/stderr: empty
rc=0
```

检查覆盖报告主体；之后只补这段真实回执，未重跑扫描或差异检查。2026-11-16T14:25:17Z 再核固定独立检出仍为同一 SHA 且 status 为空。

## Flip evidence

N/A：本轮只审规划，未修缺陷或执行故障样本。C1/C2 是逐层源码定位，不是已经实跑的红/绿；五原变异、恢复及调用边旁路留待批准后的唯一独立实际验收。

## Final assessment（首轮历史）

- Counts：CRITICAL 2 · WARNING 2 · SUGGESTION 0。
- Readiness：**REWORK**，应先由 dev2 最小修订规划，再由 PM 接受方案；不据此派 apply、归档、合并或发布。
- 本轮适用的行为检查：无；brief 明确只审方案。未来正常 boundary、五臂、caller 旁路/父回放、合并后同一性均未运行，不能写为通过。
- 明确未运行：参数/路由样本、normal boundary/CORE、五臂/完整61b、smoke/FAST/meta/夜间、构建/安装/性能、真实 Pi/模型、全仓 strict/引用/选择平台和任何归档/发布。本轮没有新的耗时或节省实测。

## Decisions and deviations / Suggested next steps

无范围偏离。本报告交付的是四项可定位的规划修订，不是索取用户重新确认方向，也不是跨目录代修。作者仅需改同一 change 的 design/tasks/delta 及对应数字/报告；不要求新探索或样本轮。修订后同一 V172 可只复核这四项及直接矛盾；旧三处已完成验收、正常合法启动、恢复/撤销及未改组不重开。PM 负责看板和方案接受记录，本席位不写这些路径；分支只留本地，不 push/merge。

## 四项差异复看 · 2026-11-16 · ACCEPTED（规划）

冻结候选 `2c4f86d1b146a82b0fc99f0652386beb9629d239`，工件修订 `d5ceaaa8`。本次按 PM 新增 brief/thread，仅审 `824cfd82..2c4f86d1` 和 C1/C2 必要相邻源，未重开已审方案。原 `6955816d` 报告中的 REWORK、四项证据和实际静态回执完整保留；下面更新的是返修后结论。

### 四项关闭依据

| Finding | 修订内容及本次核对 | 状态 |
|---|---|---|
| C1 | design §3 固定两个旧 `extra-unknown-before-model/resume` 输入、` --unknown harmless`、worker fresh/PM continued 模板、PM ` --continue` 与同 resume-key metadata，并给出 `unknown arity --unknown before protected --model` / `... {resume_args}` 的预期诊断。必要相邻 `common.sh:1912–1969` 确认 standalone extra 无后续受保护词时可通过、模板展开 list 后才出现受保护词；tasks 1.2 与 delta Normal parameter rules 同步。原孤立 `--skill` 不再承担真实 list 接线证据，197 个 direct 输入不扩表 | CLOSED；这里只确认规划和源码前提，未运行替换样本 |
| C2 | design Context/Migration §4、tasks 2.2 和 Correct helpers 场景均只采用 real-up：同一私有副本一起旁路 `cmd-watch.sh:373` 与 `common.sh:3798`，保留真实 guard 和最终 renderer，使用已停止 PM/合法 policy/既有 fresh provider 坏 custom 模板，从真实 `up --fresh-pm` 观察 prompt/诊断变化。相邻源确认两处确实先于 `common.sh:3806` 写 prompt；不再追加直接 start 实验 | CLOSED；不再让未到达被改位置的单点删除充当证据 |
| W1 | proposal/design §3–4/tasks 1.2、2.1 及 Normal parameter rules 场景一致为 21 个 tag 各一次 launch，加既有 PM fresh provider 的一次独立 preview；算式 `4+(3+1)+2+4+2+2+2+2=22`，明确非永久配额。原合法启动、fresh/continued、metadata/撤销及其它组安排未动 | CLOSED；22 是修改后的计划，不是实跑结果 |
| W2 | delta 的 Internal checkout、Only the two routing boundary repeats、Routing evidence 三处旧完整61b表述均限定到 preceding routing-argv batch/accepted record；后续参数批次只交新增受影响证据并引用未改事实。design/tasks 同步引用 P457/V163 前批原件，不删旧场景标题、不要求新候选完整61b | CLOSED；不重验前批已完成三处或长原件 |

`git diff --name-only 824cfd82..2c4f86d1` 只列本 change 的 proposal/design/tasks/delta 和作者报告五条路径，`.openspec.yaml`、产品/tests/CI/正式 spec 均无变化。作者报告把原 `planned_live_cli=42` stdout 明确标为首轮历史，当前 22 只表述为计划；没有将旧盘点改写为本轮实跑。差异未改六项未来任务的勾选状态、197 输入、原五变异或一次非作者行为验收安排；未发现四项关联的直接矛盾。

### 本次实际检查

沿用首轮 OpenSpec 1.16.0 和版本/源盘点回执，不重新执行版本、根、名单、引用、选择平台或旧静态检查。

```text
$ git -C /var/tmp/p467-review-2c4f86d1 rev-parse HEAD
2c4f86d1b146a82b0fc99f0652386beb9629d239
$ git -C /var/tmp/p467-review-2c4f86d1 status --porcelain=v1
(empty)
$ (cd /var/tmp/p467-review-2c4f86d1 && openspec validate routing-parameter-check-dedup --strict)
Change 'routing-parameter-check-dedup' is valid
stderr: empty
rc=0
```

唯一新 strict 的环境同首轮；原件位于 `/var/tmp/v172-verify.W3ZzNz/revision-2c4f86d1/`：`structure.{command,stdout,stderr,rc}`、`candidate.sha`、`candidate.status`、`checked-at.txt` 及本次 `revision.diff`。strict 完成时点为 `2026-11-16T14:43:23Z`。报告暂存后的必要差异检查各一次，原件为同目录 `diff.*`、`cached-diff.*`；之后只补此真实回执，不重跑检查或首轮 ledger-ban。

```text
$ git diff --check
stdout/stderr: empty
rc=0
$ git diff --cached --check
stdout/stderr: empty
rc=0
```

### 最终 OpenSpec assessment（规划差异）

| Dimension | 最新状态 | Evidence |
|---|---|---|
| Completeness | 规划完整，六项未来任务未实施符合阶段 | 仅四项关联文字变更，原四工件/旧17+新6场景和六任务安排保留；未用未勾任务否定方案 |
| Correctness | 四项修订前提及观察对象自洽 | C1/C2 对应源与固定输入，未来样本仍由实施后统一验收，未将本轮静态判断称实证 |
| Coherence | ACCEPTED（规划） | W1 真实重复已从计划删除，W2 前批义务与本批证据边界一致；新 delta strict rc=0 |

- 当前 CRITICAL 0 · WARNING 0 · SUGGESTION 0；首轮 2/2/0 保留为历史，不表示仍有未解决项。
- **最终 ACCEPTED 绑定 `2c4f86d1`，仅是规划接受输入。** PM 尚未派 apply，本席位不授权实施、合并、归档或发布。
- 未验边界仍为未来全部行为：正常 boundary、五原故障/恢复、调用边旁路、父结果回放及合并后同一性。本轮均未运行，不追加长测试或新样本；旧静态/已接受行为引用边界不变。
- PM 可据本报告接受方案并决定后续派单。本任务只追加自己的报告，保留原分支/模型/SID，不改规划、看板、主检出或发布对象。
