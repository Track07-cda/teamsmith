# pm-reply-discipline · 把「关键结论先发布」写进 skill（PM 提示词 + 协议 + 命令表 + 门禁）

## Why

用户 2026-10-14 的要求（本变更的唯一需求来源，原话）：

> 这个规则应该在 teamsmith 的 skill 里的，不只是你自己的记忆里。

指的是 PM 侧的一条行为纪律：**任何用户需要事后能找回的结论，先发布到关键回复页，再在对话里发同一份**
（里程碑落地、做出裁定、请用户决策之前各发一条；同一批可合并；只发结论，不发自述性噪音）。今天这条
纪律只活在 pm-skills 这个项目的记忆里（`ctx_memory`），别的项目、别的机器上的 PM 不知道它 —— 这正是要
修的地方：纪律要随工具走，而不是随某个项目的记忆走。

现状复核（2026-10-14，本 worktree 只读实测，数字为度量）：

- **机制齐全**：`team reply post/list/show` 已归档（change `pulse-key-replies`），存储、编号、并发、
  只读读取、面板第 5 页都在位；`references/protocol.md` §4b（`:138` 起）写清了机制、回执含义与
  「发布不阻断答复」的理由。
- **指令面是空的**：`templates/pm-prompt.md.tmpl`（每次 `team up` 注入 PM 的提示词）对 `team reply`
  **零提及**（`grep -c 'team reply' skills/teamsmith/templates/pm-prompt.md.tmpl` → **0**），129 行的
  提示词里没有任何「什么时候该发布」的句子。
- **文档面读起来是可选项**：§4b 的入口句是「When an answer itself is the durable artefact … publish that
  body explicitly before you send it」—— 一个「当你有一个值得留存的答复时」的许可，不是 PM 的常设义务；
  它自己最后一条也承认「it is written here as a rule, not enforced by the store」。
- **命令面给了机制、没给时点**：`SKILL.md:54` 的 command table `Key replies` 行写了用法、回执含义与
  只读读取，但没有一句说 `reply` 是**给用户的关键结论**的出口，也没把它与 `say`/`notify` 的内部通道
  区分开；`SKILL.md:249` 的 Non-negotiable bullet「Publish the body before you answer」有动词、没有触发条件。
- **门禁面没有牙**：`tests/key-replies.sh` 十二组（input/paths/original/concurrency/receipts/interrupt/
  paging/bounded/readonly/workflow/flip/skip-path）里没有任何一组读上面三处表面
  （`grep -c 'pm-prompt\|SKILL\.md\|references/protocol\.md' tests/key-replies.sh` → **0**）；删掉 §4b
  或提示词里那段话，今天没有任何断言会红。
- **可复用的先例**：`smoke.sh` §13c 已有 `p237_has` 一族断言，用稳定短语盯住「同一合同出现在
  pm-prompt 模板 / AGENTS 模板 / protocol / workflows 四个面」并配红侧；§62 今天已经在跑
  `tests/key-replies.sh --all`（`smoke.sh:20731-20743`）。本变更照这个形状加一条，而不是另造一套。

## What Changes

### 1. 指令面：注入的 PM 提示词带上这条纪律（短、可执行、英文）

在 `templates/pm-prompt.md.tmpl` 的 `## Talking to the user` 小节里加一段（≤8 行，与全篇同风格），说清：
**什么时候发**（里程碑落地 / 做出裁定 / 请用户决策之前）、**怎么发**
（`team reply post --from pm --title '<short title>' --stdin < <file>`，正文是**完整那份答复**）、
**发完再在对话里发同一份**、**同一批结论可以是一条**、**只发结论，不发过程性噪音**。
示例命令写成可被判定的唯一一行（探针按它取子命令与旗标）。

### 2. 文档面：协议写成常设义务，命令表分出通道

- `references/protocol.md` §4b：把「当你有一个值得留存的答复时」改成 **PM 的常设义务**，点名三个触发
  时点；保留机制、回执含义与「发布不阻断答复」的全部既有内容；把最后那条诚实边界改成与门禁一致的
  说法（门禁只能证明「纪律已随工具发出、示例命令真的可用」，不能证明某个活着的 PM 照做了）。
- `SKILL.md`：command table 的 `Key replies` 行加一句它**是给用户的关键结论的出口**，并把它与
  `say`/`notify`（内部通道）区分开；Non-negotiable bullet 保留机制文本并补上触发条件，避免同文件里
  两处说法互相漂移。

### 3. 门禁面：让这三处不能被悄悄删掉

在既有 `tests/key-replies.sh` 里加 `guide` 组（§62 今天已经 `--all` 跑它）：

- **表面存在性**：三处表面各自必须带着这条纪律的**稳定词汇**（按短语断言，不锁死整段文字），缺哪个面
  就按场景名点名那个面（template / protocol / command table）。
- **示例命令对拍（逻辑类）**：从模板里取出那一行示例，用**真 CLI** 在私有夹具项目里跑它的子命令与全部
  旗标 —— 真解析器必须接受（不是「未知参数」拒绝）；**非空洞对照**：同一探针加 `--frobnicate-probe`
  必须被真解析器拒（命令若吞掉未知旗标，对照臂红）。
- **红侧常跑**：组内对两处**变异副本**跑同一判定 —— ① 删掉模板里的纪律段 → 红并点名 template；
  ② 把示例里的旗标写坏（`--stdin` → `--stdinX`）→ 红并点名示例命令 —— 还原后绿。红侧是组的断言，
  不是只在评审时手工做一次。
- 与 P264（「门禁瘦身」）的关系见「需要 PM 裁定的点」第 6 条：**行为面（示例命令对拍 + 变异红侧）是
  保留的逻辑类断言；纯措辞面的短语清单最小化**，并明确接受 P264 的分类复核。

## Capabilities

### Modified Capabilities

- `key-replies`：
  - **MODIFIED** `Publication does not gate the normal answer or create work`：把「选一份关键答复去发布」
    （可选动词）收敛为 **PM 的常设义务**（三个触发时点、完整正文、同一份正文、可合并、只结论），并把
    由哪些表面承载、由谁守住指向新增要求；「发布不阻断答复」「回执含义」「不新增状态/配置」与既有场景
    逐字保留。
  - **ADDED** `The key-conclusion duty is shipped on its instruction surfaces and held by the gate`：三处
    表面各自的文本义务、门禁的失败形状（命名丢失纪律的那个面）、示例命令对拍的非空洞控制，以及必须
    继续写明的诚实边界。

不新增 capability：这条纪律的机制面（`team reply` 与存储）本来就在 `key-replies`，本变更只加它的指令面
与门禁面；`team reply` 的 CLI 行为、存储、面板渲染一个字都不改。

## Impact

- 文档与提示词面：`skills/teamsmith/templates/pm-prompt.md.tmpl`、`skills/teamsmith/references/protocol.md`
  §4b、`skills/teamsmith/SKILL.md`（command table 行 + Non-negotiable bullet）。
- 夹具面：`skills/teamsmith/tests/key-replies.sh` 新 `guide` 组（含两处变异红侧与真解析器探针）。
  不改 `tests/smoke.sh`（§62 已经跑 `--all`）。
- 规格面：`openspec/specs/key-replies/spec.md` 的 1 条 MODIFIED + 1 条 ADDED，delta 在
  `openspec/changes/pm-reply-discipline/specs/key-replies/spec.md`。
- 选段面：见裁定点 5。今天 `section-select.sh --paths <模板> <协议> <SKILL>` 解析出 26 个段
  （`sections=129 / keys=26`），**其中没有 62** —— 改这三处表面时，新守卫不会在增量跑里被选中；
  要补的话只需在 `tests/section-paths.tsv` 第 151 行（段 62）的 patterns 加这三个路径。
- 兼容性：无运行时行为变化（没有代码路径被改）、无新配置键、无状态写入、无面板改动；§62 现有十二组
  与 `openspec validate` 全绿不动；唯一新增的门禁条目是新组的断言。
- 与在飞任务的分工：本 change 不碰 `scripts/lib/cmd-project.sh` 的帮助段（P260）、
  `references/migration.md`（P255）、`references/config.md`（P261）。`tests/section-paths.tsv` 此刻有
  P260/P261 的写者在飞、P264 排队 —— 见裁定点 5。
- 排期：一个 apply 席位做完（文档 + 一个夹具组）；verify 由**另一席位**在独立克隆上重跑全部场景与红侧
  （写的人不验自己的活）。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **delta 形状：MODIFIED + ADDED 两条要求**。推荐：是 —— 义务（行为合同 + 既有非阻断语义）与
   「随工具发出、由门禁守住」（表面与门禁合同）失败方式不同，分开写才能让任务项与场景一一对应；
   若要求恰好一条 MODIFIED，就把 ADDED 的三条场景并入 MODIFIED（代价是要求名与内容进一步错位）。
2. **示例命令用 `--from pm`**。推荐：是 —— 它示范 PM 自己的用法；标签仍是自称标识符（不是身份认证，
   `key-replies` 的安全要求不变）。
3. **提示词里的位置**：放进现有 `## Talking to the user` 小节（该小节已经统管 user-facing output），
   不新增顶级章节、不改 loop 第 6 步的 Report 行（避免两处副本漂移）。推荐：是。
4. **门禁放 `tests/key-replies.sh` 的 `guide` 组**（§62 已跑 `--all`），不扩 `tests/routes.sh`
   （P260 正在重写它；且 routes.sh 判的是帮助页，不是 PM 提示词）。推荐：是。
5. **§62 的行是否补声明这三处表面**（`tests/section-paths.tsv` 第 151 行）：补了以后，改模板/协议/SKILL
   会选中 §62，守卫在增量跑里也生效；代价是碰一张此刻有 P260/P261 在写、P264 排队的共享表。
   推荐：**本 change 先不动该表**，把「增量选集不含 §62」作为已知缺口记在 design 里，由 P264 收口时
   一并处理（它本来就拥有选段表与文本类断言的整体分类）；若 PM 希望现在就补，apply 只需在该行
   patterns 加三个路径并跑一次 `section-select.sh --check`。
6. **与 P264 的关系（重要）**：P264 的用户裁定是「文本类的断言不要写进门禁，只留逻辑类」。本 change 的
   门禁面正是文本类；提案按「最小措辞断言（每面 2–3 个语义锚点）+ 行为探针（示例命令对拍 + 变异红侧）」
   落笔，design 里逐条说明哪些算逻辑类、哪些算文本类，供 P264 分类时直接采用。推荐：行为面必须留
   （属于 P264 界定的「承诺兑现」类），短语面最小化且接受 P264 复核。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/key-replies.sh --select guide        # 新组：表面 + 对拍 + 两处变异红侧
bash skills/teamsmith/tests/key-replies.sh --all                 # 十二组回归 + guide
bash skills/teamsmith/tests/smoke.sh --select 62                 # 门禁段 62（容器里跑全量更稳）
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/templates/pm-prompt.md.tmpl \
  skills/teamsmith/references/protocol.md skills/teamsmith/SKILL.md   # 裁定点 5 若裁「补声明」，选集必须含 62
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rm -rf /tmp/p257-trial && mkdir -p /tmp/p257-trial && cp -a openspec /tmp/p257-trial/openspec \
  && (cd /tmp/p257-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y pm-reply-discipline \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

夹具与命令的最终形态以 apply 冻结的接口为准；**场景名、红侧方向与「示例命令必须被真解析器接受」不得改**
（改了就是换合同，要重新走提案）。

## Out of scope

- 不改 `team reply` 的 CLI 行为、退出码、存储、编号与并发语义（一个字节都不改）。
- 不改面板渲染与第 5 页（`panel/**`），不改字符串表。
- 不改 worker 侧提示词（`templates/task.md.tmpl`、派单/续跑提示词）—— 这条是 PM 与用户之间的通道。
- 不引入「自动判定哪条重要」：发哪条是判断，不是机械；工具只提供出口与纪律，不做语义判定。
- 不迁移既有聊天/报告里的历史结论，不新增导入命令。
- 不改 `references/workflows.md`、`references/config.md`、`references/migration.md` 与帮助面。
