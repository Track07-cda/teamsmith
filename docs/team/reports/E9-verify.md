# E9 · 产品角色与 PM 平级：只读探索

agent: verify · status: DONE（只读探索交付） · time: 2026-10-05
branch: `task/E9-product-peer-explore` · PR/MR: -（按任务书本地交付，不 push）
研究基线：`2575d22`；身份是独立研究员，**没有产品席位上线，也没有实施试点**。

## 结论与推荐

1. **现有工具能保留产品意见原件，不能保证意见独立送达使用者。** 任务范围、启动、看板与后续阶段仍由 PM 控制；通知的自动目标仍是 PM。把 worker 叫 `product` 不会改变这些事实。[S2–S5]
2. 推荐未来的 **B2：使用者授予有限调查权，PM 负责运行与交付，产品意见有独立收件凭据和分歧出口**。这里的平级是产品判断独立，不是共享合并权。当前只能做 B1 的独立研究，不能诚实宣称已满足 B2。[S1–S5；下文为建议]
3. 首个值得调查的产品问题不是“再加一个角色”，而是：**从高层目标走到独立验收，使用者是否仍被迫理解检出目录与证据准备，或者误以为团队已经替他完成？** 有一份经处理的真实使用反馈支持调查，但当前是否仍有摩擦、是否需要产品改动尚未证实。[S6–S8]
4. 本报告原件可直接从本分支读取；PM 的接受、反对或实施意见应另写评审记录，不覆盖本结论。可读取不等于已阅读，更不等于已有防截留机制。[S2；docs/team/tasks/E9-product-peer-explore.md:32]

以下建议是研究选项，不是新增契约，不是 OpenSpec 提案，不授权启动角色或开发。

## 1. 使用者、来源与一条需求候选

### 证据等级

- **A：本次直接观察**：当前公开 README、现行规格与代码、只读 CLI 输出。[S2–S5、S7–S8]
- **B：经处理的项目内反馈**：D66 记录一位实际使用 Teamsmith 的同行 PM 希望“一条命令能搭好独立 worktree + 跑门禁 + 留证据目录”。我只读了本项目内记录，没有读其外部会话或联系他；记录里的频次、使用量未经本次独立核实，不用于排优先级。[S6]
- **C：产品假设**：首次安装者可能把自主交付理解为“不必介入临时检出及证据路径”，出现监督负担或误判完成。没有首次安装者访谈/现场观察，不能称为已证实需求。[S1、S6–S8 → 推断]

目标使用者是希望把项目开发交给团队、自己聚焦产品和架构的安装者；实际操作人还包括负责派单和复验的 PM agent。不能把 agent 的命令抱怨自动等同于人的购买/使用需求。公开 README 描述了 owner + crew、独立复验及账本，但它是产品自述，不是使用行为证据。[S1；README.md:3–18]

**公开说明确实读过**：<https://raw.githubusercontent.com/Track07-cda/teamsmith/main/README.md>，匿名 GET HTTP 200（15:45 UTC），与本工作树 `README.md` 字节一致，SHA-256 `61d40871d9a7a34357d3449420e0938c81f3edc4e92c57cce31d5686d8ca24bb`。因此下述 README 行号也适用于本次读取的公开内容。

**公开 issue/PR 确实读过**：匿名 GET 下列两端点，均 HTTP 200、`[]`、无分页 Link（2026-10-05 15:22 UTC）：

- <https://api.github.com/repos/Track07-cda/teamsmith/issues?state=all&per_page=100>
- <https://api.github.com/repos/Track07-cda/teamsmith/pulls?state=all&per_page=100>

日志：`E9-verify/github-readonly.log`。只能结论为“本次 API 返回的公开 issue/PR 集合为空”；不代表无人使用、无人反馈，未查私有 issue、Discussions、下载量或其他平台。也未调用任何写 API。

### 候选 P-01：自主交付应让人拿到可信验收证据，而非补做准备工作

| 层次 | 内容 | 能否证实 |
|---|---|---|
| **观察** | D66 第3项提出“一次完成检出、门禁、证据”的期待；同一记录把 `team review` 说成“就是这件事”。当前规格和实现却明确要求 PM 预备独立检出，缺 `--dir` 拒绝。本次真实运行 `team review E9` 也 exit=1，并点名 PM 先准备 checkout（`E9-verify/review-refusal.log`）。README 第三步也使用已有目录。[S6–S8] | 当前契约可直接核对；历史反馈仅 B 级，不把历史缺陷当作今天复现 |
| **推断** | “用过工具的人都不能准确辨认准备步骤由谁完成”，可能暴露验收责任和证据交付的可发现性问题，让人重新盯细节。 | C 级；也可能只是历史 PM 解释错误，后来已消除 |
| **方案** | 先观察一次“人给高层目标 → PM 用原生 git 准备独立检出 → review → 人查看证据”的现有流程。若 PM 已自主完成且人能理解，不加功能；若说明误导，改说明/PM 引导；若确有反复人工接管，再比较显式授权下的准备自动化。 | 候选，未实施；不先包装 git、不先设计新 CLI |

**还缺的证据**：一位非本项目维护者的首次/近期使用过程，具体在哪一步需要人接管、接管原因和耗时；他实际查看哪份验收证据、如何判断验的是哪版。获取须另外授权，由 PM 安排；本任务没有联系使用者。重复使用者与新安装者结果也可能不同。此候选尚无优先级、采纳率或市场结论。

它与 D99 的关系是把“人不必一直盯详细方案、团队补细节并验证”的目标转成可观察的使用结果；不以关键词命中推断需求来源。[S1]

## 2. 现有权限与渠道：已有 vs 缺失

| 对象 | 已有、归属与事实来源 | 对平级产品判断还缺什么 |
|---|---|---|
| roster / 配置 | 实测名册为 `dev verify dev2 dev3 dev-bob`；本席位任务为 E9，目标 session `teamsmith`、PM window `pm`。AGENTS 中四席位说明比运行名册少 `dev-bob`，不能当作运行配置。[S2；AGENTS.md:15；OWNERSHIP.md:17–24] | 名字没有调查权；注册席位需明确授权，且注册不改变角色权。[openspec/specs/dispatch/spec.md:707–725] |
| dispatch / 任务书 | 协议由 PM 拆任务派单；brief 定义范围和验收；dispatch 管分支、容量、启动证据，成功启动后置 `wip`。本任务只授报告路径。[AGENTS.md:11–23；openspec/specs/dispatch/spec.md:9–33；skills/teamsmith/scripts/lib/cmd-agents.sh:1071–1364] | 产品不能越过 brief 自主启动研究；PM 能不派下一单。需要来自人的有限调查授权，而非只换名 |
| OWNERSHIP / 看板 | 任务、BOARD、DECISIONS、OWNERSHIP 属 PM，agent 只写自己的报告；verify 不实现。BOARD 明写 agent 只读。[S2；BOARD.md:7] | 产品候选的创建、更新和独立保留权；不能借“产品”身份写 PM 的账本 |
| `thread` | append 到指定线程，包含时间、`from`、`re`；本项目允许 PM 与本席位追加。读线程本身不投递、不证明使用者收到。[skills/teamsmith/scripts/lib/cmd-docs.sh:92–111；AGENTS.md:143] | 独立收件人、回执；`--from` 是文本标记，不是使用者认证 |
| 手工 `notify` | 收件人须为名册席位或 pm；运行目录推导发送者，显式 `--from` 是声明；写收件人 inbox 后，knock **仍指 PM**。[S3] | `notify human` 不是已有用户出口；不使用 `--any` 或改 PM window 假造直达通道 |
| 自动 turn-end / inbox | 自动写 `inbox/<sender>.md`，通知 PM；inbox 是 gitignored 的本地文件，不是产品判断的版本原件。`inbox --ack` 修改已读游标，`--all` 仍可读保留行。[S4；openspec/specs/notify-and-inbox/spec.md:10–17、218–225；skills/teamsmith/scripts/lib/cmd-status.sh:902–935] | 不能把 PM 已 ack 当人已读，也不能只靠运行时 inbox 保留分歧 |
| pulse | 默认 900 秒检查待办，唤醒/启动 PM；停止的 worker 交 PM 决定 resume，不是独立产品调度器。[E9-verify/runtime-readonly.log；skills/teamsmith/references/protocol.md:219–237] | 使用者授权的产品触发条件、未送达核对、受限调查预算；不能把巡逻误当主动产品发现 |
| meeting | PM-to-PM 跨项目讨论，共享 transcript 是原件，双方 agree；worker 不参加，非用户指令通道。[S5] | 无法用 worker 的会话冒称另一个 PM，也不能绕外部项目回来给本项目的用户投递 |
| 报告 / 人查看 | 原件可提交在自己的 task 分支，人可直接读；本任务也要求 PM 意见另记。[S2；docs/team/tasks/E9-product-peer-explore.md:32] | 没有独立用户收件回执、可用性保证或防静默截留的强制核对 |

**为何普通 worker 不平级**：判断可以独立、可用证据反对 PM（philosophy.md:85–94），但执行范围来自 PM 的任务书，持续运行和下一阶段依赖 PM，候选不在独立保留/送达链上。协议上的目录归属也不是 OS 隔离：入口检查项目身份，相关写命令没有“只能 PM UID 写”的角色认证；`thread --from` 和 `notify --from` 不能充当授权凭据。[skills/teamsmith/scripts/team:69–118；skills/teamsmith/scripts/lib/cmd-docs.sh:92–111；skills/teamsmith/scripts/lib/cmd-agents.sh:1572–1594]

**PM 能否静默截留？** 按本任务规则不得改写原件，但机制上仍可不呈交、不继续派单或只给人摘要。保存在 worker 分支能减少依赖合并才可读的问题；同一公共 git 对象库/文件系统不构成对 PM 的安全隔离。已被人持有的原文副本或提交/内容哈希能揭示后续改写，不能证明此前从未被截留。[S2–S4 → 边界分析；paper-demo.log 的弱信任对照]

**何时误打扰人？** 今天这些通知唤醒的是 PM agent，不是已注册的 human target；人若正使用 PM 窗口，会看到工作交通。已有输入框守卫避免粘坏草稿，但不判断某条异议是否值得打断人。把每份候选、每轮 settle、每次 PM 不同意都转到人的通知会造成噪声；建议只有超授权、不可逆重大取舍、或在约定期限仍未解决的方向分歧才直达。[openspec/specs/notify-and-inbox/spec.md:19–23；S3–S4；后半为建议]

## 3. B 的两条路线及跨项目选项

本节全部是**未实施建议**，以 D99 已确认的独立判断目标为准，不要求重新确认产品目标。

| 决策环节 | B1：PM 派 product worker，原件可见 | B2：有限独立调查授权 + 独立异议出口（推荐） |
|---|---|---|
| 谁发起 | PM 写 explore brief；人也可要求 PM 派单 | 人先授领域/预算/截止边界；产品在边界内因新证据发起，PM 只提供运行资源。超范围交人决定 |
| 谁改候选 | worker 写自己的报告和补充版本；PM 的意见另记 | 产品拥有候选原件，修改用新版本引用前版；PM 只写可行性/资源意见，候选索引只存 ID、版本和指针 |
| PM 如何附意见 | 独立 review 关联报告 revision，不摘改结论 | 同左，另标安全、容量、依赖和可逆性依据；资源暂缓不伪装成产品价值否决 |
| 谁能否决/搁置 | PM 控制下一单，可实际搁置调查；这是 B1 不平级的核心限制 | 人否决产品方向。产品可撤回自己的候选。PM 可按已授预算/安全约束暂停执行，但保留原件、理由和下一核对时点，不能无限期静默搁置 |
| 冲突到人前 | PM 成对呈报告与意见；人可主动读分支原件，但漏呈无独立保障 | 产品提交原件后独立留下收件凭据；未解决分歧成对提交人，发送失败显示“待投递”，约定检查点核对缺项；不用 PM 的摘要替代双方原文 |
| 避免双写 | 报告为发现原件，review 为 PM 意见，BOARD 只存执行状态 | 同一 candidate ID 和版本串；人决定追加引用版本；获准后只指向正式 OpenSpec change，BOARD 仅指执行 task，不再抄一份需求 |
| 代价 | 不需先开发角色机制；每次派单/呈交有人工纪律成本 | 要调整授权、目录、独立收件/回执、未送达核对规则；PM 与产品需协调资源，人的注意力也有预算 |
| 不能保证 | 自主发起、反对意见必达、PM 不截留 | 没有外部持有的副本/凭据仍无强防篡改；收件不等于阅读、不等于采纳；有限预算可能错过新问题 |

**最小诚实 B2**不一定先写新代码：之后正式批准流程调整时，可先由人持有原件副本/收件清单，按需给已有席位一份调查授权，PM 仍通过原生工具启动它；产品与 PM 分开写意见，人在固定检查点看成对原件。授权来自人，PM 的 launch 是技术操作，不拥有取消产品判断的权力。先验证这条人工链是否值得工具化；仍须明确改现有 brief/OWNERSHIP/呈交规则的冲突，不能用本任务授权实施它。[冲突依据：S2、openspec/specs/dispatch/spec.md:9–33、skills/teamsmith/references/openspec.md:34–59]

**跨项目 PM 路线不推荐**：现有 meeting 能表达两方判断、留下 transcript、要求双方 agree，但它服务不同项目的边界，交付还要落各自账本。为了同一个产品建第二项目，会把产品候选、资源和执行拆成两个来源，且也没有使用者独立收件保障。它适合请另一个实际使用本工具的 PM 提供证据，不适合作为内部平级角色的身份变通。本次未开会、未访问共享区。[S5]

## 4. 可证伪演示与反向例

已执行 `python3 docs/team/reports/E9-verify/paper-demo.py`，全文见 `paper-demo.log`。这是纯本地纸面模拟：脚本临时文件全部在同名证据目录下，自动清理；没有 `team notify/say/meeting`、真实用户消息或新席位。产品意见与 PM 反对意见均明确标“纸面”，**不是实际 PM 的意见**。

| 演示步骤 | 今天能做 | 等机制/规则变更才能声称做到了 |
|---|---|---|
| 产品发起 P-01 | 接到本次 PM brief 后独立写研究原件 | 在人的持续有限授权内自行发起，不受 PM 产品价值否决 |
| PM 不同意代码方案 | 另写 R-01，保留 P-01，关联同一版本；纸面打印双方全文 | 自动强制成对呈交、时限核对；当前只靠规则与人主动查看 |
| 使用者看到原文 | 离线视图在 `paper-demo.log:5–14` 完整展示双方；人现在可以打开 | 人真正收到/读到的独立回执；此测试没有证明任何人已阅读 |
| 使用者选择 | 明写 `User decision = PENDING` | 等人实际决定，不能由测试编造“接受”或“采纳” |
| PM 静默改写/删除 | 与模拟的人持有副本/哈希比较，两种情况均检出，再恢复 | 真正独立保管和检查节拍；报告目录内的两份文件只是信任边界模型 |

真实输出要点：

```text
MODE=paper; real_user_deliveries=0; new_seats=0
PASS P-01 byte-identical to receipt
DETECTED changed P-01 (sha256 differs from independent receipt)
DETECTED missing P-01 (expected from independent receipt)
LIMIT same-controller rewrite of original AND baseline is undetectable by this hash check.
LIMIT withholding before an independent receipt arrives is not detected; scheduled reconciliation is missing.
RESULT paper forward + rewrite + delete + weak-trust control passed; no production mechanism installed.
```

反向判据不是“有 git 所以防篡改”：人已持有 P-01 回执，却只看到改写版或没有 P-01，核对就能报缺失/哈希不符；若 PM 连回执基准也能改，脚本对照**仍通过**，明确证明本地双副本不够。若在首次送达前就截留，哈希也无用，需人在约定截止点知道该有哪份原件并检查缺项。两点都尚未在产品里实现。

## 5. 何时考虑常设 C

以下评估建议不靠提案数量，也不预报采纳率：

- 每次研究开始前保存人的原始高层目标和已明确要求；结尾展示“哪条需求是人已说过的、哪条是由新证据推导的”。“主动提出”看可追溯的差额，不看 agent 自称原创。
- 由人评价一个具体工作结果：候选是否改变了他原本的产品/架构判断，或在一次授权的真实使用/交付中减少了本会发生的人工接管。保留负例；只是重复旧需求、改名、PM 摘要更漂亮不算新增价值。
- P-01 的反证：近期使用者已经由 PM 全程准备好检出，且能从现有报告辨认受检 revision/风险，不需人理解临时目录，则该功能候选撤回；若只是说明错误，接受说明改进，但不借它升级为常设产品席位。
- **建议预算**：先按需运行，不轮询所有文件；一个研究工作块只取一个使用结果、一个核心假设。最多每周一个非紧急人类检查点，持续分歧合并成一次成对呈交；紧急仅限授权边界、安全/不可逆取舍。工时/成本上限由实际授权填数，本任务不虚构可用 token 或币值。
- **停止条件**：越界研究或投递、原件被截留却未显式暴露、无证据地冒称需求/采纳，立即停试；连续两个约定观察周期仍没有新增使用证据，或工作块预算用尽，就交 PARTIAL 并停止扩展，不能靠多提案证明价值。
- **C 的必要条件**：不同时间/场景中出现可追溯的新增价值，用户确认它值得持续预算；有限调查和冲突呈交链经历至少一次真实分歧而未被压掉；PM 可行性意见仍发挥作用，没有重复开发账本。即使有价值，若频率低，仍保持 B，不必升 C。
- **当前不可测**：没有真实 B2 角色、真实独立回执、非维护者近期使用观察、相对现有 PM 的额外价值对照；因此今天无法给 C 的收益率或推荐上线时点。

**单一来源**：候选报告只记录观察、假设、方案及证据，不写“产品必须”的新 requirement。正式承诺之后走 explore 接受 → propose → PM ACCEPTED → dev apply → 不同 agent verify → 人确认 archive；承诺和场景只进 OpenSpec，说明进产品 references，任务/报告保留过程证据。候选转为指向 change 的历史记录，不复制 specs。B2 若要改变 PM 对 explore 的接受权，须在正式提案中明确调整这个 gate，不能默认 D99 已替换现行工具契约。[skills/teamsmith/references/openspec.md:34–70、87–120；S1]

## 6. 交付、命令证据与安全边界

| 路径 | 内容 |
|---|---|
| `docs/team/reports/E9-verify.md` | 原始研究结论、选项、推荐、不确定项 |
| `docs/team/reports/E9-verify/paper-demo.py` / `.log` | 可复跑的纸面双方分歧、删除/改写检出及弱信任对照 |
| `docs/team/reports/E9-verify/runtime-readonly.log` | paths/roster/选定非秘密配置键、分支和磁盘实测 |
| `docs/team/reports/E9-verify/source-index.log` | 文件行号索引 |
| `docs/team/reports/E9-verify/github-readonly.log` | 真实匿名 GitHub GET、issue/PR 空结果及公开 README 字节核对 |
| `docs/team/reports/E9-verify/review-refusal.log` | 缺少 --dir 的真实拒绝，未进入写复验记录路径 |
| `docs/team/reports/E9-verify/gate.log` | 容器干净 clone 上的完整验收输出 |

真实已运行：

```text
$ git status --short; git branch --show-current
[开工干净]
task/E9-product-peer-explore
$ bash skills/teamsmith/scripts/team paths
session=teamsmith; pm_window=pm; pulse_interval=900 [完整 JSON 在日志]
$ bash skills/teamsmith/scripts/team roster
dev verify dev2 dev3 dev-bob；verify 当前任务 E9 [完整输出在日志]
$ bash skills/teamsmith/scripts/team review E9  # 只探拒绝路径
✗ review 需要 --dir <路径>：请 PM 自己准备独立 checkout（skill 不执行 git）
exit=1
$ python3 docs/team/reports/E9-verify/paper-demo.py
RESULT paper forward + rewrite + delete + weak-trust control passed; no production mechanism installed.
```

**完整验收已运行并收齐：PASS（含可见跳过，不把跳过算通过）。** 在本报告目录下创建独立干净 clone，挂入现成 `localhost/teamsmith-gate:local` 容器；没有把 worktree 的 `.git` 指针直接挂进去，没有在共享宿主 tmux 跑 smoke，也没有 FAST 或选段替代。

```bash
E="$PWD/docs/team/reports/E9-verify"
git clone --no-local --depth 1 --single-branch --branch task/E9-product-peer-explore \
  "file://$PWD" "$E/.gate"
distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
  -e HOME=/tmp -v "$E/.gate:/work" -w /work localhost/teamsmith-gate:local \
  bash -c 'git config --global --add safe.directory /work; openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'
```

真实输出末尾及耗时：

```text
Totals: 13 passed, 0 failed (13 items)  # openspec validate
账本自查：124 段收口 · 增量 ✓4647 ✗0 SKIP19 ｜ 结果行 ✓4647 ✗0 —— 一致
== 结果 ==  ✓ 4647  ✗ 0
smoke 全绿
acceptance_exit=0
team_bg_wait: exit=0 after 2386.4s
```

19 个可见 SKIP 的全文在 `gate.log`：主要为未随 clone 携带的 `.pi` 生成面、冻结报告证据豁免清单；另含容器内无可用嵌套 podman 的 §31b、未配置本机禁令名字表的 §60 等。**没有声称这些前提受检通过。** 门禁验的是 clone 中不变的 `2575d220c1a67480b3433de881097b20ddce92c3`，收尾 clone 的 `git status --short` 为空；本分支后续增量仅本报告与证据，不冒称门禁验过随后写入的报告正文。完整日志只对本机真实家目录路径作脱敏，判定和数字不改。可重建 clone 在收齐后删除，不提交运行副本。

提交步骤：先提交来源与纸面证据 `ce7041c`，再提交研究正文和真实只读探针 `0c7c608`，最后提交验收日志与报告收尾；均含 `Agent: verify` trailer。交付前再核对 `git diff --check`、仅报告路径增量与干净状态；本地模式不 push。

### 证据索引（均为本工作树研究基线）

- **S1** `docs/team/DECISIONS.md:794–802`：D99 定位、B/C 决策、暂不实施及否定关键词统计。
- **S2** `docs/team/OWNERSHIP.md:3–13、16–35`；`AGENTS.md:11–23、136–147`；`runtime-readonly.log`：范围/名册/PM 账本权与本次运行身份。
- **S3** `openspec/specs/notify-and-inbox/spec.md:527–570`；`skills/teamsmith/scripts/lib/cmd-agents.sh:1410–1426、1565–1657`：发送者解析、收件人白名单、固定 PM knock 目标、声明不等于身份认证。
- **S4** `skills/teamsmith/extension/team-notify.ts:389–435`；`openspec/specs/notify-and-inbox/spec.md:10–23、218–225`；`skills/teamsmith/scripts/lib/cmd-status.sh:902–935`：自动通知、durable inbox 与 ack。
- **S5** `skills/teamsmith/references/meeting.md:6–33、76–113`；`skills/teamsmith/SKILL.md:231–239`：跨项目边界、原件和共识，不是内部 worker 平级出口。
- **S6** `docs/team/DECISIONS.md:327–338`（D66 表第3项在 332）：经处理的真实使用反馈；不是我本次访谈。`docs/team/DECISIONS.md:302–321`：历史反馈未读事件，仅作为信息可达风险背景，非今日复现。
- **S7** `openspec/specs/verification/spec.md:9–23`；`skills/teamsmith/scripts/lib/cmd-review.sh:880–925`：PM 先准备 checkout，review 不负责创建。
- **S8** `README.md:14–18、132–142`；`skills/teamsmith/references/openspec.md:34–70、87–120`；`skills/teamsmith/references/philosophy.md:30–39、85–94`：公开工作流、阶段权属、原生工具分工和证据授权原则。

### 偏差与未验证项

- 不改 task/spec/代码/配置，不建 seat，不向真实用户窗口发测试消息，不开会议、不读其他项目/外部会话、不读取 token、不写 API、不 push、不触发 CI。虽然 `git remote -v` 显示实际存在远端，仍按任务书的本地交付/no-push 边界执行。
- 本地 `.pi/prompts/opsx-explore.md` / `.pi/skills/openspec-explore/SKILL.md` 不存在；研究按已完整阅读的 `references/openspec.md` explore 阶段完成，未生成文件或假称运行缺失的命令。未写提案。
- 配置 JSON 第一次筛选误用字段 `key` 得到 `[]`；已检查 schema 字段为 `name`，日志追加纠正后的真实选定配置值，不把空筛选当无配置。
- 本任务不是 defect-fix；不提交产品修复 flip。纸面篡改检出有反向对照，但不是“产品防截留已修复”的证据。

### 给 PM 的下一步

请独立核对来源、原件和纸面边界，在单独评审文件中说明对 B2 及 P-01 的意见，并把本报告与该意见成对交使用者。后续只需决定研究/试点路线和有限预算；不得把 E9 的完成记作产品角色已上线。若继续 B2，先正式处理授权与独立收件规则，再试点。
