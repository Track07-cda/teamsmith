# pm-reply-discipline · 设计

## Context

动机、用户口径与范围见 proposal 与任务书（`docs/team/tasks/P257-pm-reply-discipline-propose.md`）。以下是本轮
读取的基线事实（均为当前磁盘状态，不是待实现能力）：

- **机制面已归档**：change `pulse-key-replies`（`openspec/changes/archive/2026-10-14-pulse-key-replies/`）把
  `team reply post/list/show`、存储、编号、只读读取与面板第 5 页都落了地；能力规格
  `openspec/specs/key-replies/spec.md` 有 10 条 requirement，本变更动的是第 9 条
  `Publication does not gate the normal answer or create work`（`:128`），其余一条不改。
- **三处表面的现状**（本 worktree 实测）：
  - `skills/teamsmith/templates/pm-prompt.md.tmpl`：129 行，`team reply` 命中 **0**；`## Talking to the user`
    小节（`:16-28`）已经统管 user-facing output（代号带名字、长列表逐行自明）。
  - `skills/teamsmith/references/protocol.md` §4b（`:138`）：有完整机制、回执含义、只读读取与「发布不阻断
    答复」，但入口句是条件式许可（「When an answer itself is the durable artefact …」），末条自称
    「it is written here as a rule, not enforced by the store」。
  - `skills/teamsmith/SKILL.md`：command table `Key replies` 行在 `:54`（机制 + 回执含义 + 只读读取）；
    `## Non-negotiable rules` 的 bullet 在 `:249`（「Publish the body before you answer」，有动词无触发条件）。
- **门禁现状**：`tests/key-replies.sh` 十二组（`input paths original concurrency receipts interrupt paging
  bounded readonly workflow flip skip-path`），对上述三处表面 0 命中；`smoke.sh:20731` 的 §62 已在跑
  `key-replies.sh --all`。可复用先例是 §13c 的 `p237_has`（稳定短语 × 四个面 × 红侧）。
- **写集现状**：P260（cli-help apply）明确不改 SKILL/references 内容（其 impact 只提 `config.md` 与
  `cmd-project.sh`）；P261（startup-self-heal apply）的落点是 `cmd-watch.sh`/`cmd-config.sh`/`common.sh`/
  `config.sh.tmpl`/`references/{config,workflows,migration}.md`/`teamsmith-init/**`，**不含本变更的四个文件**；
  两者与 P264（gate slimming，todo）共用 `tests/section-paths.tsv`/`smoke.sh`，而本变更按裁定点 5
  **不动这两处**（§62 已跑 `--all`）。
- **P264 的裁定**（2026-10-14，`docs/team/tasks/P264-gate-slimming-propose.md`）：门禁只留「用户能观察到的
  行为与状态」与「承诺兑现」类断言，措辞/术语/排版类的拿掉；边界是「表面在检查一串字、实际在代理一个
  行为」的算逻辑。本变更的门禁面必须按这条裁定自证归类（见决策 7）。

## Goals / Non-Goals

**Goals**：让「关键结论先发布」这条纪律**随工具走**（注入提示词 + 协议参考 + 命令表三处同口径）；让
「纪律被悄悄删掉」这件事在门禁里可判、可点名、可还原；让「印出来的示例命令真的能用」由真解析器背书而
不是靠读；明确写下门禁**不能**证明什么。

**Non-Goals**：不改 `team reply` 的 CLI/存储/退出码/编号/并发；不改面板与字符串表；不改 worker 提示词；
不引入「哪条重要」的语义判定；不迁移历史结论；不改帮助面、`routes.sh`、`smoke.sh` 与两张 tsv（裁定点 5）。

## Decisions

### 1. 三处表面各司其职，措辞是同一套词汇而不是同一段字节

| 表面 | 为什么是它 | 它必须说什么 |
|---|---|---|
| `templates/pm-prompt.md.tmpl` | 每次 `team up`/bootstrap 注入，是 PM 真正会读到的那份 | 纪律本体：触发时点、命令与完整正文、发同一份、可合并、只结论 |
| `references/protocol.md` §4b | 会话之外的参考面，被 PM 与后代重读 | 同上，并写成「PM 的常设义务」；保留机制、回执含义、只读面；保留诚实边界 |
| `SKILL.md` | 命令表是「有哪些出口」的地方；人/agent 先查这里 | command table 行点明 `reply` 是**给用户的关键结论**的出口，并与 `say`/`notify` 内部通道分开；Non-negotiable bullet 补触发条件 |

三面**不要求逐字相同**（各自语域不同），只要求共享同一套**语义锚点**（决策 3）。理由：今天三处已经各自
成文，强行逐字对齐会让任何一次措辞润色都变红，而真正要防的是「某个面整个丢了纪律」。

### 2. 提示词的落点：`## Talking to the user` 小节内，不新增顶级章节

规则讲的是「给用户的输出」，与该小节同题；放在这里读者不会跳段。**不**在 loop 第 6 步的 Report 行加第二
份副本（两处副本必然漂移）。要求形态（英文，≤8 行）：

```
**Key conclusions go to the reply page first.** When a milestone lands, when you make a ruling, or before you
ask the user to decide, publish the complete answer — not a summary — with
`team reply post --from pm --title '<short title>' --stdin < <file>`, then send that same body in the
conversation. A batch of conclusions may be one reply; publish conclusions, not process narration. See
`{{SKILL_DIR}}/references/protocol.md` §4b.
```

示例命令是全模板**唯一**一行 `team reply post …`（探针按它取值，见决策 4）。

### 3. 语义锚点：一条共享词汇，三处按面断言

守卫里的词汇是**语义锚点**（对象 / 触发 / 通道 / 内部通道），不是句子；每个锚点各有一句「丢了它意味着
什么」，红时按面点名：

| 锚点 | 含义 | template | protocol | SKILL |
|---|---|---|---|---|
| `conclusion`（大小写不敏感） | 发布的对象是**结论** | ✓ | ✓ | ✓ 行内 |
| `milestone` | 触发一：里程碑落地 | ✓ | ✓ | ✓ 文件内 |
| `ruling` | 触发二：做出裁定 | ✓ | ✓ | ✓ 文件内 |
| `ask the user` | 触发三：请用户决策之前 | ✓ | ✓ | ✓ 文件内 |
| `--stdin` | 完整正文只从 stdin 来 | ✓ | ✓ | ✓ 行内（既有） |
| `say` + `notify` | 内部通道与用户通道分开 | - | - | ✓ 行内 |
| `No tool can verify` | 诚实边界（门禁不证明某个人照做了） | - | ✓ | - |

`--stdin` 在 SKILL 行内今天已有；其余按上表补。断言大小写不敏感（`grep -iF`），不 lock 整段文字。

### 4. 示例命令探针：跑印刷出来的那一行，而不是对拍文本

从模板取出唯一一行 `team reply post …`，在私有夹具项目里**按印刷原样执行**（只把行首的 `team` 解析为真
CLI、把重定向目标指向夹具正文文件），然后：

1. **接受臂**：真解析器必须接受这些旗标与取值 —— 期望 rc=0、回执 `outcome:"saved"`，且夹具存储里多出
   一条编号槽位（「印出来就能用」的兑现）。
2. **非空洞控制**：同一 argv 追加 `--frobnicate-probe` → 真解析器必须以「未知参数」拒绝（rc=2、诊断含
   `未知参数`），且**没有**新的槽位（拒绝发生在发布之前）。
3. **不撒手**：若某命令吞掉未知旗标，控制臂红；若示例旗标是拼错的（`--stdinX`），接受臂红并点名模板。

不采用 `--help` 对拍/追加 `--help`（本 CLI 的全局参数循环会把任意位置的 `--help` 折成帮助页，等于绕开
旗标解析）；不采用纯正则对拍（那只是把模板再抄一遍，P264 的「承诺兑现」类要的是真解析器）。

### 5. 红侧在组内常跑：四个变异，逐面点名，还原即绿

守卫的检查函数按 **(表面路径, 表面名)** 参数化，组内先对真树跑出全绿，再对四份**副本**各做一次变异，
每次都必须红且点名被改的那个面：

1. 模板副本：删掉持有 `Key conclusions` 锚点的**整段**（按空行切段删除）→ 红，点名 `prompt template`；
2. 协议副本：把 §4b 的常设义务段整段删掉 → 红，点名 `protocol reference`；
3. SKILL 副本：把 `| Key replies |` 行换成不含锚点的行 → 红，点名 `command table`；
4. 模板副本：示例行的 `--stdin` 改成 `--stdinX` → 红，点名 `example command`。

变异只落在 `$TMP` 的副本上，真树与真项目一个字节不动；还原 = 重新从真树复制。四次变异加一次真树全绿是
`guide` 组的**常跑断言**，不是评审时的一次性动作 —— 这样守卫自己就有「坏得掉」的证据。

### 6. 组放在 `tests/key-replies.sh`，`guide` 三名内部分工

`guide` 组内部拆成三段断言前缀，便于 P264 分类与将来单独处置：
`guide-surfaces`（锚点，文本类）、`guide-example`（探针 + 控制，逻辑类）、`guide-flip`（四变异，逻辑类）。
不动 `tests/routes.sh`（P260 正在重写它；它判的是帮助页）与 `tests/smoke.sh`（§62 已经 `--all`）。

### 7. 与 P264 的归类（逐条自证）

- **留（逻辑类）**：`guide-example` 与 `guide-flip`。「印出来的用法行必须被真解析器接受」「控制臂拒绝未知
  旗标」「破坏表面必红、还原必绿」都是行为与状态，正是 P264 划的「承诺兑现」与可证伪守卫。
- **文本类（最小化，接受 P264 复核）**：`guide-surfaces` 的锚点词汇。它不是「排版/翻译/概念呈现」，而是
  **合同词汇的在场证明**（对象、三个触发、完整正文通道、两条通道的分野）：丢了它就是某个面没这段纪律。
  文档交付物没有别的机器可判形式；若 P264 仍判它文本类，本 change 的降级是安全的 —— 删掉
  `guide-surfaces` 后仍留下 `guide-example` + `guide-flip` + 评审的逐面阅读，纪律的内容仍在三处表面里。
  分类表里可直接引用本小节。

### 8. 诚实边界与要求命名

`protocol.md` §4b 末条改写为「门禁只守三处表面的在场与示例命令可用；没有任何工具能证明某个活着的 PM
照做了」，并保留 `No tool can verify` 的开口（守卫按它断言）。新增要求名
`The key-conclusion duty is shipped on its instruction surfaces and held by the gate` 把「谁承载」与
「谁能证伪」写进名字；MODIFIED 的那条保留原名与既有非阻断语义，用一句交叉引用把可观测面指到新增要求
（`key-replies#The key-conclusion duty …`）。

### 9. 被否决的替代方案

- **只改协议**：不进注入提示词就等于没修用户的原始诉求（别的项目/机器的 PM 读不到协议）。
- **在 CLI 层强制**（例如 post 必须来自 `pm`、或答复必须引用回执编号）：标签是自称标识符、不是身份认证
  （`key-replies` 的安全要求），强制只会造出一个可绕过的形式；且会改 CLI 行为，超出本变更。
- **自动判定哪条重要**：发哪条是判断不是机械（任务书「不做」第 4 条），工具只提供出口与纪律。
- **扩 `routes.sh` 或另立 smoke 段**：`routes.sh` 判帮助页且在飞（P260）；新 smoke 段要动共享文件与选段表，
  而 §62 已经跑 `key-replies.sh --all`，加组是零登记成本。

## Risks

- **措辞漂移**：锚点词汇与三处文案可能被后续润色改掉 → 红侧会点名缺哪个锚点，改词同时改守卫语义即可
  （守卫是单一来源，锚点集中在一处）。
- **探针副作用**：探针会在**夹具项目**里真发布一条回复；只在 `$TMP` 私有根内（沿用 `kr_new_proj` +
  `KR_CLEAN` 的既有隔离与 `kr_paths_check`），真项目零写入。
- **P264 之后**：若 P264 删掉 `guide-surfaces`，本变更的三条场景里「表面丢纪律」那条只剩评审阅读把关；
  设计上已把探针与锚点分开，删一半不会伤另一半。
- **选段缺口（裁定点 5）**：改模板/协议/SKILL 的增量选集不含 §62，`guide` 只在全量或改
  `tests/key-replies.sh`/CLI 时跑。本变更按「先不动 tsv」落笔；缺口写在 proposal 与本节，不静默。

## 落点与任务书头字段

apply 一个席位完成：`templates/pm-prompt.md.tmpl`、`references/protocol.md`、`SKILL.md`、
`tests/key-replies.sh`；verify 由另一席位在独立克隆上逐场景与逐红侧重跑。delta 文件
`specs/key-replies/spec.md` 只由本 change 的 propose/apply 写（P259 已 dropped，无第二写者）。
