# replies-for-the-user-are-published · 写给用户的回复必须发布到关键回复页（按读者分类，并把这一页说明白）

## Why

用户 2026-10-16 的要求（本变更的唯一需求来源）：

> 关键信息的标记被使用的情况还是有点不理想，**对于用户的问题的直接回答必须标记关键回答**，加到 Pulse 里。

同一天用户把判据收窄成一条更简单的规则（PM 转述的原话，**以这条为准**）：

> 总之就是不希望用户漏掉的回复，希望用户能够看到的回复都要添加。回复 Pulse 的、其他 agent 的不需要算。

也就是说，**判据不是话题而是读者**：**凡是写给用户的回复都要发布**（回答、汇报、结论、裁定、请示、交付摘要，
不论长短），**写给 `pulse`/巡检、写给其他席位、写给别的项目 PM、以及工具自动回执都不算**。今天这条纪律只认三类
**时点**（里程碑落地 / 做出裁定 / 让用户决策之前）——按读者算的话，**汇报、交付摘要、短回答全都漏在外面**，而它们
恰恰是用户事后最想回头找的。另一半是用户说的「加到 Pulse 里」：让关键回复页自己说清它是什么。

**范围修订记录**：本轮之前的第一版提案（分支 tip `1fd263b0`，change 名 `answer-must-be-posted`）按「回答用户的问题」
落笔；用户澄清后按上面这条判据重写，change 随之改名（见「修订说明」）。

## 现状复核（本 worktree 只读实测，数字为度量）

1. **触发条件只有三类时点，三处如此**：`templates/pm-prompt.md.tmpl:31`（「When a milestone lands, when you make a
   ruling, or before you ask the user to decide」）、`references/protocol.md:140`（同一句话的另一份）、`SKILL.md:54`
   （command table 的 `| Key replies |` 行「a landed milestone, a ruling, a decision you ask the user for」，同文件
   `:250` 是第二份副本）。**三处都没有「读者是谁」这条判据**。
2. **拟用的冻结 token 今天在三处都是 0 命中**：`grep -ciF "written for the user"` 对这三个文件都是 **0**（同一轮
   实测的另外三个候选 `the reader is the user` / `the reply is for the user` / `the user is the reader` 也都是 0）。
3. **门禁已有牙、且过了 D170 分类**：`tests/key-replies.sh` 的 `guide` 组（`:1050-1260`）用 `guide_spec()` 给三处各
   定一组语义锚点（大小写不敏感），组内对四份 `$TMP` 变异副本做红侧（删段/换行 → 红并点名面 → 还原 → 绿），并用
   `guide-example` 拿**真 CLI** 跑模板里印的那行示例命令（接受臂 rc=0 + 未知旗标控制臂 rc=2）。今天实测
   `bash tests/key-replies.sh --select guide` → **✓18 ✗0**。P264（门禁瘦身，已 done）的裁定「没有机器面、而那串字
   是某个要紧行为的唯一证据 → 留一条稳定 token（不是整句）」正是本变更新增锚点的归类。
4. **Pulse 那一页没有自我说明**：`scripts/panel/src/strings/{zh,en}.ts` 里 `replyPageNote` 一类键 **0 命中**；
   `layout.ts:1386-1394` 第 5 页列表第一行是导航、第二行就是「N 个编号槽位」——读者看不到「这一页是什么、什么属于
   它、谁发布」。页面**只读**（`replyBodyHint`「只读 · 按发布的原文显示」；`key-replies-ui.sh` 的 machine 组守着机器
   出口不读回复、compose 组守着「写信不写 store」），本变更保持这一点。
5. **基线数字**：`bun openspec validate --all --strict` → **22 passed / 0 failed**（加本 change 后 23/0）；
   `bash tests/spec-refs.sh --check` → **rc=1，1 条 undeclared**（见下条）；`section-select.sh --paths <三处表面>` →
   `sections=133 / keys=26`，**不含 62**。
6. **已知问题（不是本变更造成的，PM 需要裁一次）**：`spec-refs.sh --check` 今天已经红，唯一一条是
   `undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md`——出自 `86c7ada9`（slash-team 归档）
   写进 `extension-slash` 规格的一行场景，形状 `docs/team/tasks/<ID>.md`（无 slug）不在声明表
   `tests/spec-ledger-refs.tsv` 的槽位里。**基线对照**：把本 change 目录从 `openspec/` 副本里删掉后重跑，输出完全
   相同（`undeclared 1`、rc=1），与本提案无关；修它在 PM 的地盘（裁定点 6）。
7. **选段面的已知缺口**：`tests/section-paths.tsv:153`（段 62）的 patterns 不含这三处指令面——只改这三处时增量跑
   不会选中 §62。这是 P257 裁定点 5 明确留给 P264 的收口项，而 P264 已 done 却没有收（今天实测 `keys=26` 无 62）。

## What Changes

### 1. 三处指令面：把判据换成「按读者」

三处都写同一条规则（不要求逐字相同，共享同一套语义锚点，token = `written for the user`）：

- `templates/pm-prompt.md.tmpl`：现有那段（`:31-35`）改成按读者判：写给用户的回复——回答、汇报、结论、裁定、请示、
  交付与复验摘要——**都要发布**；写给巡检 / 其他席位 / 别的项目 PM 的与工具回执**不算**；
- `references/protocol.md` §4b（`:138` 起）：常设义务那句改成同一条判据，并补一段可执行的边界；
- `SKILL.md`：command table 的 `| Key replies |` 行（`:54`）与 `:250` 的 Non-negotiable bullet 同步（同一份纪律的
  两处副本，不许一处有一处没有）。

### 2. 判据可执行：有问题就问「这条回复是写给谁的」

边界就一句话，三处同口径：

- **写给用户的 → 必须发布**：回答用户的问题、汇报状态与进度、给出结论或裁定、请用户决策、交付与复验的要点摘要，
  以及任何其他读者是用户的回复；**不论长短、不论话题大小**；
- **不算**：写给 `pulse`/巡检的门控回执、写给其他席位（工人）的派单与协调、写给另一个项目 PM 的跨项目消息、
  工具自动生成的回执——它们的读者不是用户；
- **判不准时**：按「写给用户」处理（用户这次报的就是漏标记，宁可多一条也不要漏一条）。

### 3. Pulse 侧：第 5 页加一行自我说明（页面仍然只读）

`scripts/panel/src/strings/{zh,en}.ts` 加一个键（建议 `replyPageNote`），在 `layout.ts` 第 5 页列表的**导航行之后、
槽位计数之前**画一行 dim 说明（`layout.ts:1386`），空 store 与降级读数也看得见。推荐文案：

- zh：`PM 发布的关键回复：写给用户的回答、汇报与结论`
- en：`key replies the PM publishes: replies written for the user`

这一行是**陈述不是控件**（无 mouse target、无动作）；页面只读不变。**诚实边界**：面板不读聊天流/会话/历史，无法
自动检测「用户刚问了什么、刚收到了什么」，所以文案只说「写给你的回复落在这里」，**不承诺自动标记**——这条同时
写进规格（panel 的第二场景用「记录的读者调用只有有界的 key-reply 块」来钉住它）与 design。

### 4. 门禁：只加两类断言（存在性 + 行为，D170）

- **存在性**：三处表面各带 token `written for the user`；任一处丢了它 → 红并**点名那个面与丢的判据**；
- **行为**：`guide-example` 的「印出来的示例命令必须被真 CLI 接受 + 未知旗标的控制臂必须被拒」原样保留（本变更不改
  示例命令，但要求它继续被真解析器背书）；
- **不设**任何措辞/语气/句子形状断言；「写给巡检/其他席位不算」这一极属于文本类，由设计与评审把关。

## Capabilities

### Modified Capabilities

- `key-replies`：
  - **MODIFIED** `Publication does not gate the normal answer or create work`——触发从「三类时点」换成**按读者**（写给
    用户的必须发布、写给巡检/席位/别的项目 PM 与工具回执不算、判不准按写给用户处理）；「发布不阻断答复」「回执
    含义」「不新增状态/配置」与既有场景**逐字保留**。
  - **MODIFIED** `The key-conclusion duty is shipped on its instruction surfaces and held by the gate`——三处表面的义务
    改成同一条判据；门禁的失败形状补一条（丢了判据的那个面点名自己）；写明门禁判的是**在场与行为**、不判措辞；
    诚实边界补上「没有工具能判定某条回复是不是写给用户的，也没有表面可以承诺自动标记」；既有三条场景逐字保留。
- `panel`：
  - **ADDED** `The key replies page states what it is and who publishes into it`——第 5 页用一行（来自 zh/en 表）说明
    这一页收什么（PM 写给用户的回复）与谁发布；不是控件；面板不读聊天流，不许承诺自动标记。

不新增 capability：机制面（`team reply` 与存储）与页面骨架本来就在 `key-replies` / `panel`，本变更只补指令面的一句
判据、门禁的一条 token 断言与页面的一行说明。`team reply` 的 CLI、退出码、存储、编号、并发**一个字节都不改**。

## Impact

- 指令面：`skills/teamsmith/templates/pm-prompt.md.tmpl`（一段内改写）、`references/protocol.md` §4b（1 句 + 1 段）、
  `SKILL.md`（`:54` 行 + `:250` bullet）。
- 面板面：`scripts/panel/src/strings/{zh,en}.ts`（各加 1 键）、`src/layout.ts`（1 行），以及**重建的提交产物**
  `scripts/panel/panel.js`（钉住的工具链：`bun install --frozen-lockfile && bash build.sh`；不重建 → §26-a 的沙盒
  重建逐字节比对红）。
- 夹具面：`tests/key-replies.sh` 的 `guide` 组（三处锚点各加 token；新增一条只摘掉判据的变异红侧）；
  `tests/key-replies-pty.sh`（`pages` 组 zh、`language` 组 en 各一条「这一行在窗格里」断言）。
- 规格面：`openspec/specs/key-replies/spec.md` 2 条 MODIFIED、`openspec/specs/panel/spec.md` 1 条 ADDED；delta 在
  `openspec/changes/replies-for-the-user-are-published/specs/{key-replies,panel}/spec.md`。
- 兼容性：无运行时行为变化（唯一的产品代码改动是面板多画一行）；无新配置键；无退出码变化；不改 `team reply` 的存储/
  列表/正文语义；不恢复「自称/未经核验」字样（用户已裁定默认信任）。
- 排期：一个 apply 席位做完（三处文本 + 面板一行 + 重建产物 + 两组夹具）；verify 由**另一席位**独立复验。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **delta 形状：2 条 MODIFIED（key-replies）+ 1 条 ADDED（panel）**。推荐：是——义务（行为合同）与「随工具发出、
   由门禁守住」（表面与门禁合同）失败方式不同，分开写才能让任务项与场景一一对应；面板那一行是页面自己的新行为，
   基线里没有任何要求说「页面要说明自己」，所以是 ADDED。
2. **冻结 token 用 `written for the user`**。推荐：是——它就是用户那句「写给用户的」的英文说法，三处都能自然嵌进去，
   今天三处 0 命中所以非空洞；其余措辞一概不进断言。代价要写明：词一旦改（例如改成 `the reader is the user`）
   门禁会红，改 token 属于改合同。备选：不设 token，只靠评审读差异——与用户「标记使用情况不理想」的诉求相悖，不推荐。
3. **面板文案**（上面给出的 zh/en 两句）。推荐：按这两句落；它们是**不被门禁断言**的文本（门禁只断言这一行在不在、
   四档宽度下是否渲染得出来），PM 在提案评审里可以直接改词。
4. **第 5 页那一行的位置**：导航行之后、槽位计数之前（`layout.ts:1386` 紧后）。推荐：是——空 store 与降级读数会走
   早退分支，放在这个位置它们也带着这一行；代价是列表可视行数少 1 行（`room = budget - lines.length` 的既有算术，
   四档宽度下仍 ≥1 行，既有断言没有一条数行数）。
5. **「判不准时按写给用户处理」这条要不要**。推荐：**要**——它是用户这次诉求的方向（漏标记才是问题），并且把边界
   变成一句话而不是一道判断题；若 PM 认为会让页面变吵，删掉这一句即可（不牵动其他任何东西）。
6. **§62 的选段声明要不要顺手补**（`tests/section-paths.tsv:153` 的 patterns 加这三处路径；实测今天 `keys=26` 不含
   62）。推荐：**补**——本变更的守卫正好长在这三处文件上，不补的话「只改这三处」的增量跑不会选中 §62；改动是一行 +
   `section-select.sh --check` 的绿证据，且此刻没有别的在飞任务占这张表。若 PM 认为该留给另一次门禁事务，就按 P257
   的旧裁定保持不动，design 里把缺口写成已知限制（apply 的验收仍然显式跑 `--select 62`）。
7. **`spec-refs.sh --check` 那条既有红**（`extension-slash/spec.md:47` 引用 `docs/team/tasks/P1.md`，来自 slash-team
   归档 `86c7ada9`）。推荐：**由 PM 另立一条小任务或在本次 apply 里明授权**——修法二选一，① 把那行场景里的路径改成
   声明表已有的槽位形状（`docs/team/tasks/P1-<slug>.md`）；② 在 `tests/spec-ledger-refs.tsv` 给
   `docs/team/tasks/<ID>.md` 加一条 slot 行并写 basis。两条都落在 PM 的地盘，本提案**不动**。

## Acceptance

**本阶段（propose）亲跑的四条**（结果与输出尾在报告里）：

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

**apply / verify 阶段执行**（本阶段只写提案，不跑）：

```bash
bash skills/teamsmith/tests/key-replies.sh --select guide     # 三处锚点 + 五条变异红侧 + 真 CLI 示例对拍
bash skills/teamsmith/tests/key-replies.sh --all              # 十二组回归 + guide
bash skills/teamsmith/tests/key-replies-pty.sh --select pages,language   # 第 5 页那一行在 zh/en 窗格里
( cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile && bash build.sh )   # 重建提交产物
node skills/teamsmith/tests/panel-strings.mjs .               # 两张表的键集/占位符一致
bash skills/teamsmith/tests/smoke.sh --select 26,28,62         # bundle / 字符串表 / 关键回复（含 guide 组）
bash skills/teamsmith/tests/section-select.sh --check          # 裁定点 6 若裁「补声明」
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rm -rf /tmp/p300-trial && mkdir -p /tmp/p300-trial && cp -a openspec /tmp/p300-trial/openspec \
  && (cd /tmp/p300-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y replies-for-the-user-are-published \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

夹具与命令的最终形态以 apply 冻结的接口为准；**场景名、两条红侧方向（摘掉判据 → 红并点名面；示例命令的旗标写坏
→ 红）与「印出来的示例命令必须被真解析器接受」不得改**（改了就是换合同，要重新走提案）。

## Out of scope

- 不改 `team reply` 的 CLI 行为、退出码、存储、编号与并发语义。
- 不改面板的只读性质：不加发布/编辑/标记动作，不加 mouse target，不让面板读聊天、会话或历史。
- 不做「自动判定哪条回复是写给用户的」：这是语言判断，工具只提供出口、纪律与页面说明。
- 不改 worker 侧提示词（`templates/task.md.tmpl`、派单/续跑提示词）——这条是 PM 与用户之间的通道。
- 不迁移既有聊天/报告里的历史回复，不新增导入命令；不改造 `team say`/`notify` 的通道语义。
- 不改 `references/{workflows,config,migration}.md`、帮助面与 `routes.sh`。

## 修订说明（本轮相对第一版）

| | 第一版（tip `1fd263b0`，change `answer-must-be-posted`） | 本版 |
|---|---|---|
| 判据 | 「回复的主要目的是回答用户的问题」 | **按读者**：写给用户的回复都要发布（回答、汇报、结论、裁定、请示、交付摘要…），写给巡检/席位/别的项目 PM 与工具回执不算 |
| token | `the user's question` | `written for the user` |
| 面板那一行 | 「对你提问的回答与关键结论」 | 「写给用户的回答、汇报与结论」 |
| 不变 | 三处落点、两类门禁断言（存在性 + 行为）、只读与诚实边界、不变量 | 同左 |

change 同时改名 `answer-must-be-posted` → `replies-for-the-user-are-published`（旧名会误导后续读者把范围读窄）。
