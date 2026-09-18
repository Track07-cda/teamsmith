# split-teamsmith-init-skill · design

## Context

现状与约束（全部经 E7 实测、本树复核一致）：`skills/teamsmith/SKILL.md` 288 行，description 977 字符
（上限 1024）；references 11 篇、templates 13 个；唯一 CLI 在 `scripts/`，以自身位置 `TEAM_SKILL_DIR`
为锚解析模板与状态目录；版本单一来源 `TEAM_VERSION`（common.sh:6），`metadata.version` 与之相等由
smoke 断言（smoke.sh:3210-3211）；会话指纹 `team_skill_hash` = sha256(日常 SKILL.md + extension)
（cmd-update.sh:27-31）；安装形态是 `~/.agents/skills/teamsmith` 一条软链。Pi 是 progressive
disclosure：常驻上下文只有 description，匹配由模型做；团队建立后 PM/worker 都经 `--skill` 显式加载，
description 只在首次路由参与（E7 §Q2）。动机见 proposal.md。

## Goals / Non-Goals

**Goals:**

- 两个 skill 各自可被发现、可被 Pi 解析器加载，description 路由词汇不重叠。
- 初始化问答清单收编 5 个散点，集中进 init SKILL.md 一份有序清单。
- 单一 CLI、单一版本来源、指纹范围不变；存量项目与在跑会话零改动。

**Non-Goals:**

- 不拆 worker 指引（AGENTS.md + 任务书路线，与 skill 边界正交）、不拆 opsx（独立生成的命令）。
- 不给 init skill 任何运行时所有权（pulse/派单/复验/合并一律归 teamsmith）。
- 不建多步向导框架：init SKILL.md 是一份清单，不是交互程序（bootstrap 本身零交互，E7 §Q3）。
- references/templates 不在两侧各拷一份（漂移源，E7 §Q4.3）。

## Decisions

### D1 · 轻拆：只动「指引与入口」

新建 `skills/teamsmith-init/`（SKILL.md + 迁入两个文件），`scripts/`/`extension/`/`tests/`/`templates/`（除
被迁的一个）全部留在日常 skill。备选：①全拆（references/templates 两边各拷）——共享文件必然漂移，
E7 已否；②不拆只下沉——用户已拍板直接拆，D27 触发条件作废（proposal.md Why）。

### D2 · 迁移清单 = 两个文件；migration.md 留下，workflows.md §A 缩成指路

迁 `references/bootstrap.md` + `templates/bootstrap-prompt.md.tmpl`（E7 轻拆清单）。`migration.md`
**不迁**：它的受众是「老项目升级/回滚」的在跑 PM，是日常维护指引。`workflows.md` §A（初始化命令序列
~14 行）缩成一行指向 init skill——这是 E7 最小清单之外的一项：同一套初始化步骤若留在两处必然漂移，
且 §A 的内容正好被问答清单收编。**PM 评审可砍这条**（保留 §A 原文也不违反任何 spec，代价是双份指引）。

### D3 · 版本与指纹：一个来源、两边跟随、指纹不扩

`TEAM_VERSION` 仍是唯一来源，CHANGELOG 一份；两个 SKILL.md 的 `metadata.version` 都跟随，smoke 断言从
「common/SKILL/CHANGELOG 三处一致」（smoke.sh:3211）扩成「common/两个 SKILL/CHANGELOG 四处一致」。`team_skill_hash` 输入**不变**（日常 SKILL.md + extension）：
init skill 的受众是新项目的第一个会话，现存 PM 会话永远用不到它，把 init 文本加进指纹只会让每个文案
改动都吵醒所有在跑的 PM（E7 §Q4.2）。备选「三文件指纹」因此拒绝。

### D4 · 安装形态 A：两条软链

`~/.agents/skills/teamsmith`（不动）+ `~/.agents/skills/teamsmith-init` → 仓库 `skills/teamsmith-init/`。
备选 B（聚合目录 `teamsmith-suite/` 靠递归发现）：仓库多一层目录、`TEAM_SKILL_DIR` 锚定逻辑要重验、
相对路径变丑，无收益（E7 §Q5）。跨 skill 相对链接（bootstrap.md ↔ migration.md）在仓库内按
`skills/<a>/references/../../<b>/...` 解析，两条软链并排安装后同名路径同样成立。

### D5 · init skill 不用 disable-model-invocation

拆分的核心收益就是首次路由准确度；`disable-model-invocation: true` 会把 init skill 从 system prompt
藏起来，等于放弃收益。降噪已由「description 变短变专」拿到。备选（启用）因此拒绝。

### D6 · smoke 重排清单（逐类；E7 §A.8 计数本树复核一致：SKILL.md 24 / references 74 / bootstrap 32）

1. **版本断言**（smoke.sh:3210-3211）：`DOC_V` 改从两个 SKILL.md 各取一次，四处相等
   （common/SKILL×2/CHANGELOG）才 ok。
2. **§0b skill 加载**（smoke.sh:178-189）：`skill-load.mjs` 对 `skills/teamsmith` 与
   `skills/teamsmith-init` 各跑一遍（init 侧定位用 `$SKILL_DIR/../teamsmith-init` 兄弟推导）。
3. **文档扫描段**（smoke.sh:3642-3730 的 14b 等）：扫描范围清单（`$SKILL_DIR/SKILL.md` /
   `references` / `templates`）扩充为两个 skill 的对应路径；bootstrap.md 专属断言
   （smoke.sh:4840 的互链、4848 的 CJK）改到 `skills/teamsmith-init/references/bootstrap.md`，
   互链断言同步改跨 skill 相对路径。
4. **新增断言**：两条 description 交叉污染（R3）；init 侧无 `scripts/extension/tests` 且工具不引用
   `teamsmith-init`（R4）；指纹翻转——fixture 里改 init SKILL.md 指纹不变、改日常 SKILL.md 指纹变
   （R5）；模板与 dispatch --print 不含 `teamsmith-init`（R6）。
5. 既有两处 bootstrap.md 引用（migration.md:77、SKILL.md §Deeper reading 行）改跨 skill 指路；
   bootstrap.md 内部指向 `templates/bootstrap-prompt.md.tmpl` 的链接在迁移后仍然有效（两者同迁）。

### D7 · description 编辑方案

日常侧删 3 个 init 短语（113 字符）加一句指路（`…or bootstrap a new repo: use teamsmith-init`），目标
≤ ~910 字符；init 侧收编这 3 个短语作为路由词汇 + 交接语义（`hands off to teamsmith for day-to-day
operation`），不含日常运转短语（dispatch/patrol/review 三词组为断言口径，见 spec R3）。

## Risks / Trade-offs

- smoke ~130 处引用重排漏一处 → 门禁当场红（可观测、非静默），逐类清单 D6 把漏网面压到最小。
- 双 description 长期漂移 → R3 交叉污染断言钉死；其余措辞漂移属文案层面，接受。
- 用户多一个「装哪个、读哪个」的概念 → 两条 description 自述分工 + init skill 交接句 + 日常 skill
  指路行；接受这个成本（用户已拍板）。
- 跨 skill 相对链接在某些网页渲染器下可能不如同目录链接稳 → 同仓库 `skills/` 兄弟路径，forge 与本地
  编辑器都可解析；接受。

## Migration Plan

存量项目：零改动——软链不动、`.pi/team/config.sh` 无新键、AGENTS.md 协议段不变、启动命令不变、指纹
不变（spec R6 逐条有断言）。本仓库的迁移就是文件 `git mv` + 文档改写 + smoke 重排 + 本机加一条软链。
回滚：init skill 是纯新增——`git revert` 合并提交 + 删除 `~/.agents/skills/teamsmith-init` 软链即回到
单 skill 形态；无数据、无状态、无配置迁移。

## Open Questions

无。版本号 bump 幅度（如 1.39.0）属发布决策，由 apply 任务书定具体号，本 change 只承诺三方相等
（spec R5）。
