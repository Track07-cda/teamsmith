# startup-self-heal · 设计

## Context

一个 0.1.2 的项目升到 0.2.0 要人做四件事（升工具、迁移配置、补 PM 启动身份记录、重启会话），用户在第三步
撞墙。本设计的边界由任务书给定：机械的自动做，需要判断的明确声明，不许静默改值；工具自身只提示不安装
（用户裁定 A）。

三块现状代码决定了落点：

- `TEAM_AGENT_MODELS`/`TEAM_DEFAULT_MODEL` 是**退休键**：`team_model_policy_issues`（`common.sh`）按**文件里有没有
  这些行**拒绝写路径，`team_config_model_source_shape`（`cmd-config.sh`）对**形状**（顶层单行字面量、无重复键、
  无展开）给出行号级拒绝，`team_config_upgrade_transaction` 是唯一写入器（临时文件 → `bash -n` → 指纹 CAS →
  原子改名 → 一行审计）。旧配置的类别映射推导今天**只在人的脑子里**（PM 给三个项目手工推导过）。
- PM 启动身份记录 `state/pm-launch.env` 由 `team_pm_metadata_publish` 在**启动证明成功之后**写；`team_pm_identity_guard`
  读不到或读到的 model/resume_key 与当前解析不一致时拒绝——**缺记录**与**记录不一致**走同一条拒绝。
- `team_cmd_up`（`cmd-watch.sh`）的顺序是：身份 guard → 场地 → 启动；`--print` 走 guard 之后打印「会话判定 +
  完整命令」；配置由 CLI 启动时 `team_load_config` source 一次。
- 版本面：`TEAM_VERSION` 是唯一版本源；`state/`（`.pi/team/state/`）是本项目运行时目录且被 gitignore；
  `team version --check` 是会话级版本自检，和 npm 上的最新版无关。

## Goals / Non-Goals

**Goals**

1. 旧形状配置（退休键）在 `team up` 里**自动**迁移：值一个不动、先备份、原子写、有审计、逐键可见。
2. 缺 PM 启动身份记录时**登记本次启动身份**并说明；不一致时照旧拒绝但说清两边与两条出路；补记录有正式入口。
3. 工具版本只**提示**不安装：`up` 触发、有界查询、24h 缓存、失败静默、rc 不变、可用开关关掉。
4. 每条不能自动的情形**失败关闭**并说清障碍；用户随时能退回去（`--no-migrate`、`--print`、备份还原）。

**Non-Goals**（理由一并给出）

- **不自动安装工具**：用户裁定 A（全局动作 + 联网 + 影响同机其他项目）。
- **不提示「哪些会话是用旧版本起的」**：今天**没有任何按会话记版本的地方** —— `state/pm-loaded.env` 只记
  PM 自己最近一次 `mark-loaded` 的版本/指纹（不是会话级主张、也不覆盖席位会话），`state/<agent>.env` 里没有
  版本字段，Pi 的会话文件不记录加载过的 `SKILL.md` 版本。判不准就不猜（任务书原话）。
- **不重写模型值 / 不解释类别语义 / 不搬 `docs/` 目录 / 不在别的会话里重启 agent**。
- **不改** `config upgrade-models` 的既有语义、报错与退出码（它是保留的手工入口），不改 `team help`（P252）。
- **不把 `up --print` 变成会写盘的命令**：预览不产生备份、审计、缓存或状态文件。

## Decisions

### 1. 落点、步骤序与「写后重入」

落点：`cmd-config.sh` 放**纯决策**（形状表、推导表、形状版本、无副作用），`cmd-watch.sh` 的 `team_cmd_up`
放**编排**（打印、备份、写入、exec、身份、版本提示），`common.sh` 只改两处既有函数（拒绝建议、身份缺记录
分支）。

`team up` 真实运行的步骤序（每一步失败都停下，不进入下一步）：

```
0 解析旗标（--no-migrate / --adopt-pm-identity；--yes 由全局解析器给 TEAM_ASSUME_YES）
1 迁移决策（纯函数）：形状 + 推导表 → 计划 / 拒绝理由
   1a 计划非空 且 非 --print 且 非 --no-migrate：
      打印逐键表 → 备份 → 复用 upgrade-models 的事务写入（actor=up-migration，含形状号）
      → 打印结果与备份/还原 → export TEAM_MIGRATION_BACKUP → exec 自己（同一 argv）→ 回到步骤 1
   1b --no-migrate 且需要迁移：打印建议命令或障碍 → 拒绝（非 0），不写
   1c --print：打印预告（逐键表 + 备份路径 + 身份预告），不改盘
2 身份 guard：缺记录 → 放行并记下「本次要登记」；不一致/不可读 → 拒绝（打印两边值 + 两条出路）；
   --adopt-pm-identity[--yes] → 写记录 + 一行审计
3 --print：打印「会话判定 + 完整命令」（或「迁移后重跑才看得到完整预览」）+ 版本检查跳过说明 → 退 0
4 场地（session/窗口）→ PM 启动 → 成功行 + （缺记录时）登记行
5 版本提示：查询/缓存 → 只在「本地 < 最新」时打一行；失败静默；不改 rc
```

**为什么写后 exec**：配置在 CLI 启动时 source 进进程，写完文件后进程里的变量仍是旧值（`team_model_policy_issues`
还会直接 grep 文件看到退休键）。`exec` 让**所有**后续判据（身份、启动、面板）都读**新字节**，比在内存里
投影一套「假装已迁移」的状态诚实得多：没有第二条判定通道，也就没有「预览与真跑不一致」的空间。迁移幂等
（写完就没有退休键），所以不会循环；`TEAM_MIGRATION_BACKUP` 只在这一次启动的环境里（不写配置），供后续
失败信息打印还原命令。

**被否决**：① 在 `up` 里手工改内存变量（要额外给 guard 开一条「跳过文件检查」的投影通道，等于把判据分成
两套）；② 迁移失败就整体放弃并让用户手工（与用户的要求相违）；③ 迁移与启动分成两条命令（用户要的就是一条）。

### 2. 形状版本表与未知形状守卫

检测以**一行一条迁移**的表为准（`cmd-config.sh`）：

| 列 | 含义 |
|---|---|
| `id` | 迁移名（`m1`），也是审计里可读的落点 |
| `from` / `to` | 配置形状号（整数），当前形状 = 2，形状 1 = 0.2.0 之前的退休键形状 |
| `transform` | 纯函数：`<配置路径> → 计划（键值对 + 说明 + 拒绝理由）`，不写盘 |
| `introduced` | 引入它的工具版本（写入 `state/config-backups/` 的备份名与 `--print` 预告） |

判定顺序：

```
shape = 文件里的 TEAM_CONFIG_VERSION（有 → 用它）
        否则 文件里有退休键 → 1；否则 → 2
marker > 本工具已知最新 → 拒绝（"这个项目的配置比工具新"），不套旧行
按 from 升序：shape == row.from → 用该 row 的 transform；shape < row.from → 拒绝（缺中间行）；
              shape > row.from → 跳过（已经更新）
结束 shape != 最新已知 → 拒绝
```

新初始化的项目与迁移都写 `TEAM_CONFIG_VERSION=<最新>`。表格结构写进 `references/migration.md`（以后加一条
迁移 = 加一行 + 一个 transform + 一组夹具），夹具里有一条**翻转**：从表里删掉 `m1` → 旧配置项目必须红。

**为什么加形状号**（裁定点 3）：没有它，「未来怎么加一条迁移」只能靠键猜，「旧工具读到新形状」没有确定的
拒绝判据（旧工具会把新形状当「没见过的键」静默放过——正是任务书要防的「未知的更新形状」）。缺失时按键
判定保证今天的项目不需要先补写它。

### 3. 推导表（值一个都不改）

| 旧 | 新 | 规则 |
|---|---|---|
| `TEAM_AGENT_MODELS` 的每个 `席位=模型` | 同名**类别**=同一个模型 | 名字 = 小写、`[^a-z0-9-]` → `-`、折叠连续 `-`、去掉首尾 `-`；结果必须匹配 `^[a-z][a-z0-9-]*$`，否则**拒绝**；规范化改过名字时把原名与结果一起打印 |
| `TEAM_DEFAULT_MODEL` | 类别 `default` = 同一个模型 | 兜底名与任何席位类别撞名 → **拒绝**（不换名） |
| `TEAM_PM_MODEL` | `TEAM_PM_MODEL` | 原样；文件里缺失/为空 → 用 `TEAM_DEFAULT_MODEL` 的值并在报告里说明；两者都缺 → 拒绝 |

顺序：席位对按**文件里的出现顺序**，兜底对最后（`--print` 预告与真跑逐字节一致，夹具可以逐字断言）。类别名
形状与模型值形状都用既有校验器（`team_category_valid` / `team_config_model_violation`），不新写第二份。

**为什么兜底名是 `default` 而不是 P253 文字里的 `code`**（裁定点 2）：类别名描述**任务种类**，派单不会
隐式回退到任何类别；`default` 只是「这个项目里承载旧全局默认模型的那个类别」，不暗示映射有回退语义，而
`code` 会给那个值安一个它没有的含义。撞名一律拒绝，两处（自动迁移 / 拒绝建议）共用同一张表——这是本提案
与被吸收 P253 文字的唯一口径差。

### 4. 失败关闭分类学（一字节不写：不写配置、不建备份、不写审计）

| 形状 | 判据 | 拒绝信息 | 给建议命令？ |
|---|---|---|---|
| 行形状不可定位 | `team_config_model_source_shape` 非 0 | 文件:行 + 形状名 | 否（说明为什么算不出） |
| 模型值不合法 | `team_config_model_violation` | 键 + 值 | 是（其它对仍然给出，非法那一对用占位符） |
| 类别名规范化不出来 | `^[a-z][a-z0-9-]*$` 不成立 | 原名 + 规范化结果 | 否 |
| 规范化后互相撞名 / 撞 `default` | 去重表 | 撞的两个名字 | 否（让人自己选名） |
| 退休键在**环境**里 | `TEAM_MODEL_RETIRED_ENV` 非空 | `unset <键>` | 否 |
| 新旧值同时存在且矛盾 | 文件里既有退休键又有 `TEAM_TASK_MODELS`/`TEAM_PM_MODEL` 的非空值 | 两个键 + 两个值 | 否（先手工决定留哪套） |
| PM 模型推导不出来 | `TEAM_PM_MODEL` 与 `TEAM_DEFAULT_MODEL` 都缺/空 | 缺什么 | 否 |
| 形状号高于已知 | 见 §2 | 读到的号 + 已知最新 | 否 |

「一字节不写」的判据：文件 sha256 前后相同、`state/config-backups/` 无新文件、`state/config.log` 的 mtime/内容
不变。夹具对每一种形状都断言这三条。

### 5. 写入路径、备份与审计（与手工事务同一条）

- **写入器**：`team_config_upgrade_transaction`（原有）。自动迁移只是它的另一个调用点：同一条指纹 CAS、
  同一个 `bash -n`、同一个原子改名；`actor=up-migration`（审计里一眼分辨是人跑的还是启动时自动的）。
  迁移同时写 `TEAM_CONFIG_VERSION`，所以事务的参数表加一个「附加键」入口（默认空，手工入口不受影响）。
  审计仍写进既有通道与既有行形状（`state/config.log`），`team config log` 照读，不需要新的读面。
- **备份**：`$TEAM_STATE_DIR/config-backups/config.sh.pre-<工具版本>-<UTC 时间戳>`（例如
  `config.sh.pre-0.2.0-20261014T120000Z`）。`state/` 已被 gitignore、不发布，也不会被任何解析器当成契约文件
  （`.pi/team/config.sh` 是唯一契约路径）。保留**最新 5 份**，更旧的静默删（备份是恢复手段不是档案）。
- **打印**：备份路径 + 还原命令（`cp <备份> .pi/team/config.sh`）+ 每对 `旧键/新键 before → after`（值可见）
  + 一句「为什么」（0.2.0 起按任务类别选模型，这两个键不再被读取）。
- **迁移后仍失败**：`TEAM_MIGRATION_BACKUP`（只在本进程环境里）让 `up` 的后续失败分支多打一行「本次迁移的
  备份 + 还原命令」；`--print` 里不设置该变量（没有发生过迁移）。

### 6. 可见性、逃生舱与预览边界

- 真实运行：`i` 一行开头（形状与原因）→ 逐键表 → 备份/还原 → `✓ 迁移完成（审计已写）：重新执行 up 读取新配置`。
- `--no-migrate`：与拒绝同构（建议命令或障碍 + 手工事务路线），退出非 0，不写；对已是新形状的项目是 no-op。
- `--print`：**不写盘、不联网**；需要迁移时打印预告（逐键表 + 备份路径 + 「为什么」）与身份预告（缺记录 →
  登记行；不一致 → 两边值），然后说明「迁移后重跑 `team up --print` 才有完整启动预览」，退 **0**（迁移可
  用时）；迁移不可用（拒绝形状）时按拒绝退非 0。**不**为预览开 guard 投影开关（裁定点 7）。

### 7. 身份：缺记录登记、不一致仍拒绝、adopt 显式

- **缺记录**（`state/pm-launch.env` 不存在）：guard 放行，并记下「本次要登记」；真正的写入仍由**成功启动后**的
  `team_pm_metadata_publish` 完成——不在 guard 里预写。理由：基线合同「Failed proof/publication leaves prior
  launch metadata intact and no fictitious success」；预写会产生一条「关于没发生的启动」的主张。缺记录时
  `up` 在成功行之后打一行：`此前没有启动记录；已登记本次启动身份：model=… resume_key=… mode=…（要换 PM 模型
  必须 --fresh-pm）`。
- **身份登记跟着「启动」走**（不是 `up` 专属）：pulse 唤起 PM 走的是同一个 `team_pm_start` 与同一份发布，
  所以它同样会把缺记录的项目登记上——这是「启动时自愈」的直接推论，也是本设计有意为之（否则要维护两套
  判据）。既有的「patrol 只报告 continuity blocker、从不自动 fresh/重启」不受影响：它只对**仍拒绝**的
  情形报告。
- **记录存在但不一致**：照旧拒绝；信息打印 `记录 model=… / 现在 model=…`（suffix 显式）、`记录 resume_key=…
  / 现在 resume_key=…`，点名**哪一处**变了，再给两条出路与后果（`--fresh-pm` = 新对话、磁盘账本是交接、
  Pi 历史不动；`--adopt-pm-identity --yes` = 声明按当前解析续跑）。
- **不可读/异项目/异窗口/老版本记录**：仍拒绝（这份记录不能证明是同项目同窗口的同一个模型）。
- **`--adopt-pm-identity`**：显式入口。记录缺失 → 直接写（与自愈同一份记录格式）；已存在且不一致 → 不给
  `--yes` 就拒绝并点名该旗标；给了 `--yes` → 写记录 + `state/config.log` 一行审计
  （`key=pm-launch-identity`，old/new 各带 model 与 resume_key）+ 打印「我声明这次续跑的身份是 X」+ 本次运行
  继续启动。`--yes` 用全局解析器已有的 `--yes`（`TEAM_ASSUME_YES`），不新造第二个确认旗标。
- **`--print`**：缺记录时打印将要登记的那一行且**不建文件**；不一致时打印两边值并按拒绝退非 0。

### 8. 版本提示：有界、缓存、只在有更新时说话

- **触发**：只有 `team up`（真实运行）。`doctor` **不**查——门禁/面板会跑 doctor，网络调用不该出现在那里
  （扁平面：触发点越少越可证）。
- **查询**：`command -v npm` → `npm view teamsmith version --registry https://registry.npmjs.org`，**两秒上限**：
  优先 `timeout`；没有 `timeout`（例如 macOS 缺 GNU coreutils）时用「后台 + 定时 kill」的有界等待，输出写临时
  文件（不读阻塞管道）。查不出（不存在、超时、非 0、输出不是 `X.Y.Z` 形状）→ 静默。
- **缓存**：`$TEAM_STATE_DIR/update-check.env`，三行 `CHECKED_AT=<epoch>`、`LATEST=<版本|->`、`LOCAL=<本次检查
  时的本地版本>`；原子写。**失败也写一行**（`LATEST=-` + 时间戳），这样离线机器每次启动不会都付 2s（裁定
  点 6）；TTL 24h 内不再联网。
- **比较**：按数字段比较 `X.Y.Z`；带预发布的版本按「不比数字段更大就不提示」处理（保守：宁可少说一句，
  不说错一句）。
- **输出**：只有「本地 < 最新」时打一行：
  `i 本地 teamsmith 0.2.0，npm 上已有 0.2.1（工具从不自己安装）：npm i -g teamsmith@0.2.1 --registry https://registry.npmjs.org && bash "$(npm root -g)/teamsmith/install.sh"`
- **不阻塞、不改 rc**：检查在**启动决策之后**（PM 启动已尝试完）跑；整段包在容错分支里，任何失败都不影响
  `up` 的退出码与是否启动。
- **开关**：`TEAM_UPDATE_CHECK`（配置键 + 环境变量，默认 `1`；`0` = 连查询都不发生）。登记进 key 表、模板、
  `references/config.md`（既有先例：`TEAM_NOTIFY_DETAIL_MAX`）。
- **`--print`**：不联网、不写缓存，打一行 `（本可检查 npm 上的新版本：--print 下不联网、不写缓存）`。

### 9. 被否决的替代方案

| 方案 | 否决理由 |
|---|---|
| 在 guard 里预写身份记录（缺记录时） | 会出现「关于没发生的启动」的主张，违反既有失败语义 |
| 迁移时一并「顺手」把类别名改成 `routine`/`analysis` | 改语义不是机械动作，用户明确要「值一个都不改」 |
| 撞名时自动换名（`default2`） | 「静默改值」的同类风险；手工建议路径让人自己选名 |
| 每次 `up` 都联网查版本 | 噪声 + 不可预测的启动延迟；24h 缓存是任务书给定的 |
| `doctor` 里也查版本 | doctor 在门禁与面板的等待路径上，网络调用会污染两者 |
| 用 `TEAM_CONFIRM_WRITES` 卡自动迁移 | 默认模板就是 `1`，等于默认关掉用户要求的功能；该键的语义是远端/共享状态 |
| 在 `init`/`bootstrap` 里也自动迁移 | 与既有承诺「`init --force`/`bootstrap` 不是迁移路径」冲突，且把迁移写进大写入面 |

### 10. 键 / 环境变量表（本变更新增或改动）

| 键 | 类别 | 默认 | 语义 |
|---|---|---|---|
| `TEAM_CONFIG_VERSION` | refuse（只读键，工具写） | — | 配置形状号；缺失按键判定；迁移与新建写入最新值 |
| `TEAM_UPDATE_CHECK` | apply（bool） | `1` | `0` = 不做 npm 版本查询（连缓存都不读不写） |
| `TEAM_MIGRATION_BACKUP`（仅环境，不写配置） | — | — | 本次启动刚写的备份路径；供失败信息打印还原命令 |

夹具钉桩：版本提示的桩就是 `PATH` 上的 `npm`（与既有 `fake-bin` 同族），不新增桩用键；这样
「`TEAM_UPDATE_CHECK=0` 时零调用」可以用桩计数断言。

### 11. 夹具与红侧落点（apply 阶段冻结接口）

- `tests/task-model-routing.sh` 新增三组：`heal`（迁移 / 形状拒绝 / 预览 / `--no-migrate` / 建议命令 /
  形状号守卫）、`adopt`（缺记录登记 / 不一致拒绝 / adopt / 审计）、`updatecheck`（桩 npm 五种回答 / TTL /
  开关 / `--print`）。
- 翻转（每条：破坏 → 指定用例必红 → 还原）：删掉迁移表行 / 不建备份 / 不写形状号 / 缺记录走拒绝 /
  忽略 `--yes` / 把「相同或更旧」也打印 / `TEAM_UPDATE_CHECK=0` 仍联网 / `--print` 写缓存。
- 回归段：smoke §61/§61b（驱动该套件）、§11b4（`--fresh-pm` 与身份）、§33（config 读写面）、§17（迁移指南
  文本）；`tests/config-cli.sh` 覆盖新键的 schema/模板/文档三面一致。
- 归属登记：`tests/section-paths.tsv`（必要时 `section-budgets.tsv`）为新夹具与改动文件登记段落。
- 投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y startup-self-heal &&
  openspec validate --all --strict)` 必须绿（确认没有第二个未归档 change 动这两个 requirement）。

## Risks

1. **exec 的可见性**：`exec` 之后同一次启动的 `$$` 不变、已打印的行保留；但若迁移在**写完之后**、`exec` 之前
   失败（例如 CLI 路径解析不到），用户会看到「已迁移但没启动」。缓解：`exec` 前把结果与备份路径先打印；
   exec 失败时打印还原命令并把非 0 退出留在原地（不吞）。
2. **并发两次 `up`**：事务的 `config:<path>` 锁串行化；第二者读到已迁移的文件 → 无操作。夹具里用两个进程
   并发跑一次（红侧：去掉锁 → 指纹 CAS 至少要让其中一个可见失败，不允许出现半写）。
3. **`--print` 的「不写」承诺**：`up --print` 现在只渲染到 stdout；新代码必须不建备份/缓存、不写审计。夹具
   断言配置 hash、备份目录列表、`state/update-check.env` 与 `state/config.log` 的 mtime 全不变。
4. **网络桩泄漏**：门禁机器有网。夹具断言桩被调用的**计数**，并且 `--print`/`TEAM_UPDATE_CHECK=0` 两处为 0；
   万一实现没走 PATH 解析，计数会为 0 而断言「有更新时打过行」必红。
5. **形状判定与既有 parser 漂移**：迁移决策复用 `team_config_model_source_shape` 与两个校验器，不抄第三份；
   夹具里有一条「与 `config upgrade-models` 对同一文件给出同一拒绝形状」的对照。
6. **审计噪声**：自动迁移会让 `state/config.log` 多一行（这是可审计性的代价，也是要求）。备份目录有上限
   （5 份），不会无限增长。
