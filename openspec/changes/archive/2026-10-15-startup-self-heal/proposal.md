# startup-self-heal · 启动时自愈：升完工具，`team up` 就够了

## Why

**用户原话（2026-10-14）**：「升级不应该这么手动，在启动时应该自动升级」。

现实是：一个 0.1.2 的项目升到 0.2.0，今天要人做四件事 —— ① 升工具（`npm i -g` + `install.sh`）；② 迁移配置
（`team config upgrade-models`，还要人自己推导那张「席位 → 类别」映射）；③ 处理 PM 启动身份记录（记录缺失时
`team up` 直接拒绝）；④ 重启会话。用户在 ③ 撞墙（原话：「这个报错也很难懂」），提出上面那句要求。

**PM 的立场**（本提案正面回应）：启动路径要做到「**升完工具，`team up` 就够了**」——机械的部分自动做，
需要判断的部分明确声明，**不许静默改值**。本提案接受这个立场，并加三条自己的约束（依据是既有纪律而不是
偏好）：① 自动动作走**同一个写入器与同一条审计**，与手工事务不会出现两种写法；② 每一条「不能自动」的情形
都要**失败关闭**（一字节不写）并说清障碍；③ 用户要有**一口气退回去**的开关（`--no-migrate` / `--print` /
备份还原命令）。

事实基础（本项目自己的记录）：三个真实项目的迁移是 PM **手工推导**完成的——旧 `TEAM_AGENT_MODELS` 的每个
`席位=模型` 变成同名类别，旧 `TEAM_DEFAULT_MODEL` 变成本项目里那个 `code=…` 兜底类别，`TEAM_PM_MODEL` 原样。
那张表工具完全推导得出来（配置就在它手里），这段推理不该由人做。工具本身的安装则是另一回事：用户同日
裁定 **A：只检查并提示，不自动 `npm i -g`**（自动安装是全局动作 + 联网，会同时影响同机其他在跑的项目，
升级时机应由使用者决定）。

## What Changes

1. **自愈一 · 机械的配置迁移**（触发点只有 `team up`）：配置仍带退休键时，`up` 按**声明表**推导新键（**值一个
   都不改**），先备份、再用 `config upgrade-models` 同一个写入器落盘（临时文件 → `bash -n` → 指纹 CAS →
   原子改名 → 一行审计），打印**逐键 before → after**（值可见）、备份路径、还原命令与「为什么这么做」，
   然后 `exec` 自己一次，让后续每一步都读新配置。**顺序：先迁移、再身份、再建场地/拉 PM**。迁移之后仍失败
   的路径，信息里带备份路径与还原命令。
   - 推导表：`TEAM_AGENT_MODELS` 的每个 `席位=模型` → 同名类别（名字先规范化为 `[a-z][a-z0-9-]*`，规范化
     改过名字时把原名一起打印）；`TEAM_DEFAULT_MODEL` → 兜底类别 `default`；`TEAM_PM_MODEL` 原样，缺失/为空
     时用 `TEAM_DEFAULT_MODEL` 的值并说明。
   - **失败关闭**（配置一个字节都不写，不建备份、不写审计）：形状不可定位（非顶层单行字面量、重复键、
     变量展开、行内注释/多行等既有事务会拒的形状）、模型值不合法、类别名规范化不出来、规范化后互相撞名、
     兜底名撞名、退休键在**环境**里而不是文件里（修法是 `unset`）、同时带着互相矛盾的新旧值、或配置形状
     版本高于本工具已知的最新版。
   - **P253 的要求并入**：任何**拒绝**一个旧配置的写路径（`dispatch --print`、`config set`、`init`…）都从该
     项目自己的配置**推导**出一条可粘贴的 `team config upgrade-models --task-models '…' --pm-model '…'`
     命令（一次、成块出现在其它 blocker 之前）；推导不出来时退回占位符写法并点名障碍，**不许**打印可能
     错的命令。
   - 逃生舱：`--no-migrate`（不写、只报告并拒绝）、`--print`（不写盘、如实预告逐键表与备份路径，迁移可用
     时退出 0）。`init`/`bootstrap` **不**迁移：照旧拒绝并同时点名 `team up` 与手工事务。
   - 版本表与未知形状守卫：检测走一张「一行一条迁移」的表（形状判据 / 变换 / 引入版本），顺序执行且幂等；
     新初始化的项目写配置形状号 `TEAM_CONFIG_VERSION`，迁移也写它；没有这个键的项目按键判定；形状号高于
     已知最新 → **拒绝**而不是拿旧行去套。
2. **自愈二 · PM 启动身份**（P254 的要点并入）：**缺记录 ≠ 记录不一致**。缺记录时工具对过去没有主张，因此
   默认自愈——按本次实际解析登记身份，并打印一行：`此前没有启动记录；已登记本次启动身份：model=… resume_key=…
   mode=continued（要换 PM 模型必须 --fresh-pm）`；记录**存在但不一致**时**仍然拒绝**（既有合同：不许把用
   模型 A 开的对话当模型 B 续下去），但信息要打印**两边**的 model（suffix 显式）与 resume_key、点名
   **哪一处变了**、给两条出路及后果。补记录有正式入口 `team up --adopt-pm-identity [--yes]`（显式、有审计；
   记录已存在且不一致时不给 `--yes` 就拒绝）。`--print` 只预告、不写盘。
3. **提示三 · 工具版本提示**（用户裁定 A）：只有 `team up` 触发；`npm view teamsmith version` 查询**有界
   ≤2s**；结果落 `state/` 缓存（检查时间 / 查到的最新版本 / 当时的本地版本），**TTL 24h** 内不重复联网；
   只有「本地 < 最新」时打**一行**，含两边版本号、可粘贴的升级命令（`npm i -g teamsmith@<最新>
   --registry https://registry.npmjs.org && bash "$(npm root -g)/teamsmith/install.sh"`）与「工具从不自己安装」；
   离线/npm 缺失/超时/报错 → **一行都不打、rc 不变**。检查在**启动决策之后**跑；`TEAM_UPDATE_CHECK=0` 完全
   关闭；`--print` 不联网、不写缓存，并说明「本可检查版本，`--print` 下未检查」。
4. **明确不做**（Non-Goals 与理由见文末）：工具自更新安装、改模型值、改类别语义、搬 `docs/` 目录、在别的
   会话里重启 agent，以及「哪些会话是用旧版本起的」这类**判不准就不猜**的提示（今天没有任何按会话记版本
   的记录——`state/pm-loaded.env` 只记 PM 自己最近一次 `mark-loaded`，不是会话级主张）。

## Capabilities

### Modified Capabilities

- `init-skill`
  - **MODIFIED** `Initialization teaches category policy and breaking upgrades without live adoption`：把
    「Existing projects SHALL use explicit preview/upgrade, not init --force, bootstrap or **auto-inference** to
    migrate」改成「机械形状由**启动事务**（`team up`）或显式 `config upgrade-models` 迁移，`init --force`/
    `bootstrap` 仍然不是迁移路径」；并加入 P253 的「拒绝信息要给出从本项目推导的可粘贴命令」这句。
    六条基线场景逐字保留，「Legacy bootstrap is not an implicit migration」一条按新路线改写措辞（判据方向
    不变），另加一条推导命令的场景。
  - **MODIFIED** `Existing projects and running sessions see zero change`：只改其中「旧键要求走专用事务」这句
    （现在也可以是启动事务），其余与两条场景逐字保留。
  - **ADDED** `Retired model keys migrate on the startup path with their values unchanged`：触发点与顺序、推导
    表、失败关闭集合、版本表与未知形状守卫、可见性（逐键表 / 备份 / 还原 / 为什么）、`--print`/`--no-migrate`、
    迁移后仍失败的还原提示、`init`/`bootstrap` 不迁移。
  - **ADDED** `The startup path reports a newer tool release without installing it`：有界查询、24h 缓存、只打
    一行、失败静默且不改 rc、`TEAM_UPDATE_CHECK=0`、`--print` 不联网不写缓存。
- `pm-lifecycle`
  - **MODIFIED** `The existing PM launcher guards its selected model before continuing`：把「Missing/legacy/
    unknown manual-start metadata refuses continuation」拆成两半——**缺记录**登记本次启动身份并说明，
    **存在但不可读/不一致**照旧拒绝；补 `--adopt-pm-identity`、两边值 + suffix + 哪一处变了 + 两条出路的
    拒绝信息、以及 `--print` 的预告。这是本变更**唯一一条被有意反转的基线断言**：基线场景
    `Changed or unknown identity cannot automatically continue` 的标题保留（OpenSpec 的归档校验按标题
    判「丢了基线场景」），但它的 `WHEN` 从「missing/legacy/foreign/manual-unknown」收窄为「legacy/foreign/
    unreadable/值变了」——`missing` 这一支改由新场景 `A missing record is registered, not refused` 承担；
    另加 adoption 的场景。`--fresh-pm`、运行中 PM 不被重启、发布失败不留假记录三条不变。

**为什么落点是 `init-skill`**：破坏式升级的合同本来就住在这里（上面那条 requirement 就是 0.2.0 的路由升级写
下的），「工具版本」也挨着同一能力里的 `One version source, unchanged fingerprint scope`；本变更改的是同一件
事（项目配置形状的迁移 + 工具自身的版本面），不另立 capability、不写第二份规格。身份那一半是既有
`pm-lifecycle` 合同的反转，只能改在它自己身上——否则两条规格会互相矛盾（新要求说缺记录自愈，旧要求说缺记录
拒绝），PM 的「无冲突」检查会直接判红。

## Impact

- 产品面：`scripts/lib/cmd-watch.sh`（`team_cmd_up`：迁移决策 → 身份 → 场地/PM → 版本提示；新旗标
  `--no-migrate`/`--adopt-pm-identity`）、`scripts/lib/cmd-config.sh`（迁移表 / 推导表 / 未知形状守卫 / 事务
  写入器加形状号）、`scripts/lib/common.sh`（`team_model_policy_issues` 的建议命令、身份判据的缺记录分支、
  审计一行）、`templates/config.sh.tmpl` + `references/config.md`（`TEAM_UPDATE_CHECK`、`TEAM_CONFIG_VERSION`
  登记）。
- 文档面（只说真话的最小修正，**完整重写留给 P255**）：今天四处写着「只能走 `team config upgrade-models`」
  的句子会与新行为矛盾，必须一起改成「启动事务或手工事务」：`skills/teamsmith-init/SKILL.md`、
  `skills/teamsmith-init/references/bootstrap.md`、`references/config.md`（§ retired keys 那段）、
  `references/workflows.md`，以及 `references/migration.md` 的 §5b 与升级步骤。这是 P235/P16/P235 那几条既有
  requirement（模板与指导的完整性走查）会直接扫到的文本，不能留旧话。
- 夹具面：`tests/task-model-routing.sh` 增加迁移/预览/形状守卫/版本提示/身份数组（接口以 apply 冻结为准），
  smoke §61/§61b 与 §11b4（`--fresh-pm`/身份）、§33（config 读写面）、§17（迁移指南）作回归；
  `tests/section-paths.tsv`（必要时 `section-budgets.tsv`）登记归属；`tests/config-cli.sh` 覆盖新键。
- 规格面：`openspec/changes/startup-self-heal/specs/init-skill/spec.md`（2 MODIFIED + 2 ADDED）与
  `specs/pm-lifecycle/spec.md`（1 MODIFIED）。
- 兼容性：`team config upgrade-models` 语义不变（仍是手工入口）；自动迁移共用同一个写入器与审计通道；
  `--print` 的机器输出只新增字段；`team help` 的 `up` 段归 P252（本变更不加帮助文本——见裁定点 9）。
- 排期：一个 apply 席位做不完（配置迁移 + 版本提示 + 身份 + 夹具 + 红侧）。建议按 **delta 文件**切两个 apply
  任务：**apply-1** 写 `init-skill` delta（迁移表、拒绝建议、版本提示、键登记），**apply-2** 写 `pm-lifecycle`
  delta（身份自愈 + adopt + 拒绝信息），两者顺序执行（都碰 `cmd-watch.sh` 的 `team_cmd_up`，避免并发写）；
  verify 由**未写过本 change 的席位**在独立克隆上逐场景 + 逐红侧重跑。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **`deltas:` 头部要改**：任务书写 `deltas: init-skill`，但身份那一半必须改 `pm-lifecycle`（否则两规格互相
   矛盾）。**推荐**：把头部改成 `deltas: init-skill,pm-lifecycle`，并按上面「排期」切成两个 apply 任务（一
   个 delta 一个任务，天然满足 delta 单写者）。
2. **兜底类别名**：任务书建议 `default`，被吸收的 P253 文字建议 `code`（也是 PM 手工迁移时实际用的名字）。
   **推荐 `default`**：类别名是「任务种类」的词，`default` 不假装映射有回退语义（派单**不会**隐式选它），
   而 `code` 会给兜底值安一个它没有的含义；撞名一律**拒绝**（自动路径）或**点名 + 让人自己选名**（手工
   建议路径），两处共用同一张推导表、绝不悄悄换名。这是本提案与被吸收 P253 文字的唯一口径差。
3. **`TEAM_CONFIG_VERSION` 配置形状号**：**推荐做**。没有它，「未来怎么加一条迁移」与「旧工具读到新形状
   怎么办」都只能靠键猜；有了它，未知形状有确定的拒绝判据，未来迁移有确定的落点。缺失时按键判定（今天的
   项目无需先写它），新建与迁移都写它。
4. **自动迁移是否要 `--yes`/受 `TEAM_CONFIRM_WRITES` 约束**：**推荐不受**。它只写本项目自己的配置文件、
   先备份、原子写、留审计、有 `--no-migrate` 可退；`TEAM_CONFIRM_WRITES` 的既有语义是「远端/共享状态」。
   若裁定要受约束，默认模板（`TEAM_CONFIRM_WRITES=1`）会让这个功能永不生效，与用户的要求冲突。
5. **`init`/`bootstrap` 要不要一起自愈**：**推荐不要**（保持「`init --force`/`bootstrap` 不是迁移路径」的既有
   承诺，拒绝时点名 `team up` 与手工事务）。若裁定要一起自愈，两处拒绝判定与它们「任何写入之前停住」的
   顺序都要重写，并且 `init` 的其它写入面（技能安装、契约重渲染）会与迁移混在一条命令里。
6. **版本提示的两个细节**：registry 固定 `https://registry.npmjs.org`（不加镜像键）；**查询失败也写一行缓存**
   （空的最新版本 + 时间戳），这样离线机器不会每次启动都付 2s——**推荐这么做**，若裁定「失败不写缓存」，
   离线时每次 `up` 都会重试一次 2s。
7. **`--print` 在旧配置项目上的行为**：**推荐**「打印预告（逐键表 + 备份路径）+ 退出 0」，不打印基于未迁移
   值的启动命令（迁移完成后重跑 `--print` 才是完整预览）；不做 guard 投影开关（那要往判据里加一条预览
   通道，面更大）。
8. **P254 的标题**（`team up · <项目>（本次只恢复 PM；席位要加 --agents）`）：本变更不实现它。**推荐**由 PM
   决定：把 P254 标 absorbed、标题并入 apply-2，或让它单独跑（同一文件的不同区域，单写者不会撞）。
9. **帮助文本**：`--no-migrate`/`--adopt-pm-identity` 不进 `team help`（那一节归 P252）。**推荐**在 P252 的
   brief 里带上这两个新旗标，别让两个任务改同一段。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/task-model-routing.sh --select heal,adopt,updatecheck   # 三组新夹具（键名以 apply 冻结为准）
bash skills/teamsmith/tests/task-model-routing.sh --flip                            # 逐条破坏 → 指定用例必红；还原 → 绿
bash skills/teamsmith/tests/smoke.sh --select 11b4,33,61,61b,17                     # 身份 / 配置读写面 / 迁移指南回归
bash skills/teamsmith/tests/smoke.sh --paths skills/teamsmith/scripts/lib/cmd-watch.sh \
  skills/teamsmith/scripts/lib/cmd-config.sh skills/teamsmith/scripts/lib/common.sh
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

外加一段**端到端现场**（报告里贴原文）：临时项目里造「0.1.2 形状配置 + 缺身份记录」，跑真 `team up`，贴出
迁移逐键表、身份登记行、`config list` rc=0、`dispatch --print` 按类别选中模型的输出；再造一个「记录存在但
不一致」的现场贴拒绝信息与 `--adopt-pm-identity --yes` 的修复。红侧按 tasks.md 的每条现场破坏再还原。

## Out of scope

- **工具自更新安装**（用户裁定 A）：只提示，不 `npm i -g`。
- **改模型值、改类别语义、搬 `docs/pm` → `docs/team`**：这些是判断不是机械。
- **在别的会话里重启 agent**；「本项目有会话是用旧版本起的」这类提示——没有按会话记版本的地方，**判不准就不
  做**（理由写进 design 的 Non-Goals）。
- **不碰**：`team config upgrade-models` 的既有语义与报错、`team help`（P252）、升级 runbook 的完整重写
  （P255）、`docs/team/**` 账本、以及任何其它项目。
- 不改派单/合并/复验/看板的任何判据。
