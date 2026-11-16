# V173 · 模型参数检查独立验证

agent: verify · status: **PASS（A/B均完成）** · time: 2026-11-16T16:04:20Z
branch: `task/V173-routing-parameter-check-verify` · PR/MR: -（local）

## 最终结论

**阶段A/B均通过，原生清单6/6，CRITICAL/WARNING/SUGGESTION均为0。** 已验A的一次正常boundary为863/0，五原故障与自身副本恢复由一次bounded parent接受51/0，原父异常结果消费与指定调用边反例均成立。合并版本 `28621c5755f7bc7ec1700cd8ecab9b08fb83d5d7` 的129项执行/规划/输入依赖与A逐字节相同，合并后唯一短parameters为279/0、rc0；正式P468 review已绑定该merged SHA，实际执行者仍verify。

本轮B未重跑boundary、五臂parent、结果回放或调用边反例，未扩其它组或旧平台。三个A流程CRITICAL已由B实证与精确同步清单关闭；A当时的3/6、驱动错误及全部正常/坏/恢复原件保留。尚未执行或擅自授权archive，PM负责证据接受与既有确认流程。

## 最终OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | **6/6 tasks；1/1 MODIFIED requirement本批映射完整** | `merged/final-own-apply.json`：total6/complete6/remaining0、六项done；作者1.1–1.3从merged保持，仅相对merged勾2.1–2.3 |
| Correctness | **本批六场景全部闭合** | A正常/五故障/同副本恢复/原父异常消费/真实调用边实证；B129/129同一及短parameters279/0，补齐A最后场景的post-merge部分；原17场景未另重跑 |
| Coherence | **Design Adherence / Code Pattern Consistency通过** | B从实际merged cwd重新读取四执行文件及全部contextFiles；临时runner未硬编码旧候选执行；保留原规则、调用shell结果、输入隔离及A的有限退休范围 |

### CRITICAL

None。A的C1/C2为行为已验但按授权暂不勾的2.1/2.2，C3为尚未执行的B/2.3；B实际通过且清单精确同步后均已关闭，依据 `merged/task-sync-proof.json` 与 `merged/final-own-apply.json`。

### WARNING

None。

### SUGGESTION

None。

### Final assessment

- Counts：**CRITICAL 0 · WARNING 0 · SUGGESTION 0**。
- Readiness：本brief所有适用验证均已完成，在已验范围具备按流程收尾条件；不代替PM证据接受或归档确认，不执行archive。
- Applicable checks not verified：None within the brief。未改组/原17场景及A实证依同一性和既有接受记录复用；未冒称在merged重新执行完整A。
- Excluded：完整CORE/61b/flip、smoke/FAST/meta/夜间、其它26臂、其它路由/功能矩阵、安装/构建/性能/真实模型未运行，不称通过，不宣称整套净提速。

## 阶段B · 合并后实际证据

PM接受A提交 `473bdd61` 后提供固定只读 `/var/tmp/p468-review-merged`。先建本人 `merged-parent-tmp`，保持原模型/SID/稳定任务分支，从本人worktree执行：

```text
$ TEAM_GATES='bash /var/tmp/v173-verify.nVTzgL/stage-b.sh' TEAM_REVIEW_TIMEOUT=7200 TMPDIR=<已建私有parent> \
    bash skills/teamsmith/scripts/team review P468 --dir /var/tmp/p468-review-merged --branch 28621c5755f7bc7ec1700cd8ecab9b08fb83d5d7
# rc=0，中央PASS，实际执行者verify，ran=1s；时间仅参考。
MERGED HEAD 28621c5755f7bc7ec1700cd8ecab9b08fb83d5d7 clean and ignored=0; 129 execution/planning/input dependencies byte-identical to accepted A
MERGED native schema spec-driven progress {'total': 6, 'complete': 3, 'remaining': 3}
$ bash skills/teamsmith/tests/task-model-routing.sh --select parameters
RESULT pass=279 fail=0 selected=parameters
rc=0
$ openspec validate routing-parameter-check-dedup --type change --strict --no-interactive
Change 'routing-parameter-check-dedup' is valid
rc=0
# 四执行文件bash -n全部rc0；起止HEAD、普通/ignored状态、129项hash均不变。
STAGE B actual_rc=0; actual merged source used; one parameters run only; A normal/fault/restoration/replay/caller evidence reused, not rerun
```

`stage-b.sh`以正式review的真实cwd为源码根，独立核完整SHA，逐项读取执行/输入/规划依赖；不是用旧候选路径跑出一个绿结果。四执行文件hash与A表完全相同。原生apply的四个具体contextFiles均实际读取：proposal2687、spec31509、design20462、tasks4074 bytes，来源全部是merged，记录在 `merged/context.log`；merged清单仍3/6，未写该只读检出。

B全过后才从merged精确同步本分支tasks：正文必须全部相同，作者1.1–1.3保留x，仅相对merged将2.1–2.3改x。本人分支旧表为0/6，因此git diff显示六行checkbox变化，前三行是复制merged既有作者状态，不是新增作者勾选或改任务正文。同步后真实执行：

```text
$ openspec instructions apply --change routing-parameter-check-dedup --json
# nearest root=本verify worktree（记录树，不作为产品受测版本）
progress: {total:6, complete:6, remaining:0}
all six done: True
rc=0
$ openspec validate routing-parameter-check-dedup --type change --strict --no-interactive
Change 'routing-parameter-check-dedup' is valid
rc=0
```

行为结论始终绑定只读merged，自己记录分支只同步表和报告，不把该分支未同步的四测试源码称作已验实现。

B原件在同一证据根 `merged/`：`review-original.md/.log`、起止manifest、每步命令/rc/log、context、parameters原件、`task-sync-proof.json`、`final-own-apply.json`及strict；A原件均保留，当前不清理。候选与merged均未被写入；唯一主根工具写入仍是获授的P468正式review两文件。

### 最终报告暂存后的Ledger/diff

最终报告及tasks暂存后，在本席位分支实际执行；`merged/ledger-draft.log`保存本次回执，最终暂存版本再由`final-b-checks.sh`复核至`merged/ledger-final.log`，不使用主根扫描替代本分支：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2828 hits=0 names=ok user=resolved
rc=0
$ git diff --check
diff rc=0
$ git diff --cached --check
cached diff rc=0
```

## 阶段A历史原报告（当时3/6；非当前结论）

以下保留A时点的评估、三个流程CRITICAL、B未验范围及原驱动错误。A原报告完整字节在提交 `473bdd61`；当前结论以上方最终评估为准，B没有重复A行为。

agent: verify · status: 阶段A PASS / 当时阶段B未执行 · time: 2026-11-16T15:49:17Z

### A原结论

**冻结候选的阶段 A 行为通过，未发现实现缺陷。** 正常 boundary 只执行一次，863/0、rc=0；五条原故障只经一次 bounded parent 取得，每条自身副本 healthy→原故障→字节恢复→restored 均符合预期，父级51/0、rc=0。原父消费短回放能拒绝六种明确标记的异常输入；三个实际写前边界及四个最终renderer旁路均使原观察失败，未用无关setup错误顶替。候选始终只读，起止HEAD、普通/ignored状态及129项执行/规划依赖字节相同。

受检候选 `b60de2ab53694db0815a1c3cfaa406f8344b8090`，实现 `68e8e2ea9fe4e725205848c1e7650c8f35b813cb`，比较基点 `0de91aae`。**原生清单仍3/6；后三项按brief保留未勾。** 以下三个CRITICAL仅为原生清单/阶段未收口，不是实现缺陷：2.1/2.2的行为已验，2.3仍缺合并后证据。A允许交PM接受并进入B，不构成归档就绪或最终合并验证结论。

## Deliverables与执行来源

| Path | What |
|---|---|
| `docs/team/reports/V173-verify.md` | 本任务唯一分支写入；静态、实际行为、原生评估与边界 |
| `/var/tmp/v173-verify.nVTzgL/` | 本席位驱动、副本、完整原件；不git add，PM收存前不删 |
| `/var/tmp/p468-review-b60de2ab` | PM准备的固定独立检出，始终只读 |
| `docs/team/reviews/P468.md`、`P468-verify.log` | 仅通过获授的本人worktree `team review`写入，实际执行者verify、绑定上述候选 |

使用change `routing-parameter-check-dedup`。已读主根原生 `openspec-verify-change/SKILL.md`、候选apply返回的全部proposal/specs/design/tasks contextFiles、D255、ACCEPTED proposal review及作者报告。沿用已接受的OpenSpec 1.16版本回执；本候选实际 `native-status.json` / `native-apply.json` 确认为spec-driven、nearest root指向固定候选，`progress={total:6,complete:3,remaining:3}`，未拿自己分支旧0/6替代。

## OpenSpec assessment

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 原生3/6；1/1 MODIFIED requirement映射；2.1/2.2行为已覆盖，2.3部分完成 | `native-apply.json`及下方六任务映射；后三项不提前勾 |
| Correctness | 本批六场景的A部分通过；最后一项post-merge部分Not verified | boundary863/0、五原故障/同副本恢复、父回放、调用边旁路原件；原17场景未扩大重跑 |
| Coherence | Design Adherence / Code Pattern Consistency在A范围通过；merged同一性Not verified | 四文件diff、共用规则和隔离输入、真实guard、原父消费、两处私有选择差异、129项manifest；B尚无固定输入 |

需求为 `verification#A gate that cannot judge says so` 的本批routing-parameter有限替换。实现映射：`task-model-routing.sh:50–56,460–469,1413–1569`；`model-routing-boundary.sh:54–209,294–298,433–476`；`model-routing-expansion.sh:87–136`及保留的真实caller；`model-routing-roles.sh:4–65,130–213`。不将该完整MODIFIED块原有17场景误称本轮新执行。

### 本批六场景

| 场景 | 实证与边界 |
|---|---|
| Normal parameter rules do not replay every CLI permutation | 同一共享函数在正常boundary实际279条通过；含fresh部分绑定正例、固定bound fields及literal值；22个CLI见证都具名rc1/诊断/无新增argv/完整状态不变；两list使用standalone合法的unknown-before-model/resume输入 |
| Five original parameter faults still fail shared assertions | 原变异器不改，五个child均rc1并命中全部必需名；各自healthy/restored均279/0、rc0，实际修改的common.sh恢复且全部scripts hash相同；child没有repo初始化 |
| Correct helpers cannot hide a disconnected real caller | 三个有效写前边界旁路使原purity断言红并实际写prompt，末端仍真实拒绝；四个直接renderer坏输入在调用缺失后rc0，原renderer-refused断言红。PM仅真实up，同时旁路两道写前检查，不另做direct start |
| Actual wrong-model and lost-binding observations remain grounded | 六类worker合法selector、PM合法selector、quoted literal实际argv、PM builtin/custom显式continuation、metadata损坏/恢复及publication撤销在唯一boundary中通过；argv oracle固定期望，不比较产品tokens与自身 |
| Parameter failures reach the real parent verdict | 实际bounded parent接受五臂；从其源码提取的原结果消费者对rc0、rc124、setup rc3、缺必需名、healthy失败、restored失败分别记具名父FAIL并非零；真实结果回放34/0、rc0，非第二轮故障行为 |
| Only this batch's repeated executions and incidental observations retire | 源码退休账、其它26臂/合法控制/PM尾部/P457两样本的同一性及A受影响证据具备；B的merged字节/短parameters仍Not verified；不声称逐串CLI纯净性全等保留或净节省 |

### 六任务

| 任务 | 候选勾选 | 实际覆盖 |
|---|---|---|
| 1.1 | x | 三助手共享原输入；每项子shell只产观察，调用shell累计；短入口在git/配置/CLI/tmux准备前返回；正常direct及五臂实际通过 |
| 1.2 | x | 21次launch+1次PM preview，list诊断、同resume-key真实metadata、四renderer正常/拒绝、合法启动/argv及PM尾部实际通过 |
| 1.3 | x | 五臂只改parameters，原mutator/规则/1800s预算和其它26臂保留；同副本healthy/恢复和原父消费实际通过 |
| 2.1 | 未勾 | A唯一boundary、具名结果和分开计数已取得；按brief等B后同步勾选 |
| 2.2 | 未勾 | A唯一五臂parent、原消费异常回放、指定调用边旁路已取得；按brief等B后同步勾选 |
| 2.3 | 未勾 | A四文件/清单/未改覆盖及参考用时已核；PM尚未提供merged，B同一性与短接入未执行 |

## A历史CRITICAL（当时流程未收口，现已关闭）

- C1：原生2.1未勾；A行为已满足，按授权在B真实通过后精确同步，不先改表。
- C2：原生2.2未勾；A行为已满足，按授权在B真实通过后精确同步，不先改表。
- C3：原生2.3未完成；PM接受A并提供固定merged后，同模型/SID/分支核依赖字节，仅补一次短parameters及适用静态，再精确同步三个verify叶子。

## WARNING

None within A；正常、故障、恢复、父消费或调用边均无未解决失败。B未执行已在C3及Not verified中列明。

## SUGGESTION

None。

## Verification evidence

### 1. 独立源码核对与退休账

`prepare.py`、`retained-controls.py`只读冻结基点/候选，最终均rc0，日志在同名`.log`。整个六文件交付的diff统计为683增/246删，不拿行数当行为证明；产品源码、mutator、已接受规划/delta、正式spec、smoke/CI/选择表未改。

- `source-audit.log`：PM完整尾部/中间未改组、boundary前preview/dispatch/resume/publication准备、原变异器、P457两个argv样本、metadata、publication、argv oracle、observable snapshot逐字节相同；worker/PM模板数组和role输入生成相同；31臂分组映射只有指定五项变化。
- `retained-controls.log`：六类worker合法模板、PM fresh合法preview/launch/argv、lost-history/selector/continued、quoted literal template/extra、PM显式continuation、合法role启动/argv逐字节相同。直接输入数组、独立固定bound/literal期望及每项输入隔离由四文件diff和实际279条结果共同验证。
- 原潜在562次负向CLI仅是writer接受前提下的源码排列，不是旧实跑数量。本轮实际22次，退休其余逐串mode/capture；不宣称被删排列逐一无副作用。五棵坏树的完整boundary、合法启动、metadata/事务附带观察有意退休；正常路径仍执行。没有另藏slow入口、SKIP或补旧PASS配额。
- 未改恢复/事务/其它路由组及P457/V163前批完整61b复用已接受记录与本次源码同一性，不重新执行或重审其长原件。既有版本、spec-refs及选择平台回执复用，不重跑。

准备审计首轮把publication函数定位到错误助手，后续合法控制审计两次选错源码片段结束位置；分别保留 `source-audit-driver-error.log`、`retained-controls-driver-error*.log`。修正查找范围后精确字节比较rc0；这些是验证侧静态提取错误，未修改候选、未运行额外boundary或故障。

### 2. 唯一正常boundary与五臂parent

本人从稳定worktree实际执行：

```sh
TEAM_GATES='bash /var/tmp/v173-verify.nVTzgL/measured-batch.sh' TEAM_REVIEW_TIMEOUT=7200 \
  bash skills/teamsmith/scripts/team review P468 --dir /var/tmp/p468-review-b60de2ab --branch b60de2ab
# rc=0；实际执行者verify；中央PASS，ran=173s
# 原记录另存 review-measured-original.md/.log
```

runner在固定候选实际执行四文件`bash -n`及：

```text
$ openspec validate routing-parameter-check-dedup --type change --strict --no-interactive
Change 'routing-parameter-check-dedup' is valid
rc=0
$ TEAM_ROUTING_EVIDENCE=<root>/boundary-evidence bash skills/teamsmith/tests/task-model-routing.sh --select boundary
RESULT pass=863 fail=0 selected=boundary
rc=0 elapsed=160s
```

`inventory.py`实际rc0，将863项分为direct279、22次拒绝见证132、renderer16、其它准备/合法启动/PM尾部436；最后一类包含原PM尾部105，不再相加。279内有原197负例输入、4个model-only/opaque continued语义负例和78条合法/固定值断言。197/22只作此次盘点，不新增永久次数守卫。

22份捕获的before/after `effect.hash`及复制原件逐字节相同；完整snapshot包含config/BOARD、全部state文件及prompt、argv、窗口/pane/PID标识和worktree状态。实际21次launch、1次PM provider preview；两个list分别有 `worker-role-extra-unknown-before-model-fresh-launch`、`pm-role-extra-unknown-before-resume-launch` 原件，diagnostic匹配unknown arity before protected model/resume，不是standalone缺值先拒绝。PM continued的真实publisher/loader和相同resume-key检查全部PASS。PM矩阵实际13种损坏/13次恢复，另有缺记录登记观察；publication失败后未提交进程撤销断言PASS。

普通私有副本只改两处选择（`bounded-selection.diff`）：CORE=parameters，原flip名单仅保留五个id；其余实际父执行/消费、mutator、规则、预算字节相同。随后仅运行一次既有前门：

```text
$ TEAM_ROUTING_EVIDENCE=<root>/parent-evidence bash <root>/bounded/skills/teamsmith/tests/task-model-routing.sh --flip
RESULT pass=51 fail=0 selected=flip
rc=0 elapsed=12s
```

这是bounded parent，不是完整flip/61b；没有先单跑五臂。baseline短child279/0，五条结果如下，child计数不加到父51：

| 原故障 | healthy | 原故障child | restored | 必需目标/恢复 |
|---|---|---|---|---|
| extra-shadow | 279/0 rc0 | 255/24 rc1 | 279/0 rc0 | model ownership；匹配/语法/hash及原父具名项PASS |
| template-shadow | 279/0 rc0 | 80/199 rc1 | 279/0 rc0 | worker all-hardcoded continued、PM provider fresh；同前 |
| template-unbound | 279/0 rc0 | 164/115 rc1 | 279/0 rc0 | worker positional-model/data-sid、PM continued positional-model/fresh data-provider；同前 |
| template-roles | 279/0 rc0 | 221/58 rc1 | 279/0 rc0 | worker model:--skill、PM provider:--skill、resume --skill --continue；同前 |
| literal-shell-expansion | 279/0 rc0 | 242/37 rc1 | 279/0 rc0 | worker/PM template与shared-extra model-glob；同前 |

五个实际修改的common.sh各在自身副本恢复，全部scripts前后hash相同。16份短child导出（baseline+五组三腿）都没有repo初始化目录；没有携带完整正常前半、PM metadata或事务尾部。

### 3. 原父消费短回放

第二个正式review使用临时 `TEAM_GATES='bash /var/tmp/v173-verify.nVTzgL/supplemental-batch.sh'`，同目录/同候选/同实际执行者，rc0、中央PASS、ran=10s。保存 `review-supplemental-original.md/.log`。它只复用前批实际rc/log，再执行原父短回放及调用边旁路，没有重复正常boundary或五条行为。

`replay-parent.py`从候选提取原check/eq、预算处理、flip_run及各原父结果判定；只把实际child执行位置换为读取已取得log/rc的replay_child。baseline、healthy、red、目标名、restored由原代码判定，不另写一套故障判定。`source-extraction.json`记录原片段hash和替换行，七份`input-provenance.json`分别标记真实输入或人为改动。

| 回放输入 | 实际父结果 | 原父具名失败 |
|---|---|---|
| 真实原结果 | 34/0 rc0 | 无 |
| 人为unexpected rc0 | 33/1 rc1 | flip-extra-shadow-red |
| 人为rc124 | 33/2 rc1 | flip-extra-shadow-arm-budget及red |
| 人为setup rc3 | 33/1 rc1 | flip-extra-shadow-red |
| 人为删必需model名，保留其它FAIL | 33/1 rc1 | flip-extra-shadow-specific-model |
| 人为healthy rc1 | 33/1 rc1 | flip-extra-shadow-healthy |
| 人为restored rc1 | 33/1 rc1 | flip-extra-shadow-restored |

34为此回放实际消费断言数，不冒称原父51；没有重做target/shape/source恢复。原`flip_run`会打印child日志尾部，故 `replay.log` 中的子FAIL不属于父失败；`replay-summary.json`明确只统计`FAIL flip-*`及最后`selected=replay`结果。rc124为人工注入，保留原1800s文案，不声称实际等了1800s。

### 4. 调用边旁路及恢复

`callers-body.sh`只用原fixture准备前缀、相同policy/brief/recording CLI和私有socket，不执行完整boundary准备/循环。先取得合法worker真实启动及固定argv；`prepare-callers.py`证明所有实际guard定义逐字节不变，只在私有产品副本删除指定调用/阻断动作；各diff保留在`callers/`。正常原见证由前述boundary提供，不为每个反例重跑。

```text
BYPASS worker-extra-early witness_rc=1
FAIL worker-extra-pure:model:launch
BYPASS worker-template-early witness_rc=1
FAIL template-pure:all-hardcoded:launch
PM real-up premise state=missing selected_policy=vendor/pm:high
SETUP PASS pm-policy
BYPASS pm-real-up-early witness_rc=1
FAIL pm-template-pure:provider:launch
CALLER_OBSERVATION unexpected_failures=0 (three effective early boundaries, four final-renderer witnesses)
```

三个写前旁路均为原见证5PASS/1FAIL，真实CLI仍rc1、指定末端诊断及无新增argv成立，但原本不存在的prompt实际变为非空，因此purity失败不是setup错误。worker template同时处理字段判定的阻断与显式预检，不要求只删任一冗余检查必红。PM沿用已停止私有场地，从真实 `up --fresh-pm` 同时旁路real-up预检及start首道检查；它实际创建PM窗口、写pm-prompt后由保留的真实最终renderer拒绝，没有另做direct start。

最终renderer四个原坏输入（worker/PM×builtin-extra/custom-template）在删除对应最终调用后均实际rc0，原 `renderer-refused:<seat>:<field>` 全部FAIL。PM builtin-extra仍可能输出其内部参数诊断，故不声称四条diagnostic检查都红；本次观察依据是原拒绝rc断言红及实际renderer rc0。正常四类合法/拒绝控制早在boundary全部通过。旁路结束后三份私有产品文件恢复字节相同，固定候选未写。

### 5. 同一性与报告检查

两次正式review均核固定候选HEAD不变、普通/ignored状态空；起止129项执行/规划依赖manifest匹配。四执行文件最终指纹：

| 文件 | SHA-256 |
|---|---|
| task-model-routing.sh | `220ea9c695701d18f73bb9f77119da7ec88dfce003c2dd1dd645163a241c1f57` |
| model-routing-boundary.sh | `7d0eed071734174bc26d5bc7ad3a59494a9b1a03aeadf6aeaa3abf456a6c4b62` |
| model-routing-expansion.sh | `493b07030b86d837c7ff3ac720137cbc3b296fbbc0adbba26265a6f833a56a5a` |
| model-routing-roles.sh | `fcd284c4ede1f69813d620ef432c69c580626f9470c01aef6d40e58e3a1db336` |

本报告暂存后在本席位分支实际运行，原件 `ledger-draft.log`；最终暂存版本由 `report-final-checks.sh` 复核并保存 `ledger-final.log`，不拿主根扫描替代本分支：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2828 hits=0 names=ok user=resolved
rc=0
$ git diff --check
diff rc=0
$ git diff --cached --check
cached diff rc=0
```

## Flip evidence

原五故障的真实healthy/坏/restored rc0/1/0及具名红、同副本hash恢复见表与`parent-evidence/`，原父回放和调用边反例见上；没有为了拿父结果再跑五条。旁路源恢复只做字节验证，未在已恢复树重复整个boundary。

## Decisions and deviations

无产品/规划范围变更。正常与五臂一次取得，随后短消费/调用边补充分别由正式review绑定同候选；两份中央记录的原件都保留。静态提取驱动错误已逐个保留并限定为验证侧错误，没有删断言、缩超时或吞错换绿。

## A历史评估与PM接手（以下后续工作现已完成）

- Counts：**CRITICAL 3（仅清单/阶段收口）· WARNING 0 · SUGGESTION 0；实现缺陷0。**
- A Readiness：本批A通过，可交PM接受并准备合并；B未执行，不具备归档就绪或最终合并验证结论。
- Applicable checks not verified：B固定merged的依赖同一性、一次短parameters及适用结构/报告检查。没有提供该输入前不提前执行、不勾表。
- Excluded：完整CORE/61b/flip、smoke/FAST/meta/夜间、其它26臂、其它路由/功能矩阵、安装/构建/性能/真实模型全部未运行，不称通过。实际160s、12s、1s回放、9s调用边仅作参考，不作整套提速结论。
- PM接手：接受A后提供固定干净merged检出与SHA；本席位同模型/SID/分支完成B。若129项相关前提有变化先交PM收敛补验，不能自行扩全量；若字节一致仅一次短parameters。B真实通过后从merged精确同步tasks，只改三个verify叶子完成状态，作者勾选及原文保持。
- 本分支只本地提交，不merge/push/archive/tag/npm，不改变真实团队配置、提醒或待命；原件待PM收存，当前不清理。
