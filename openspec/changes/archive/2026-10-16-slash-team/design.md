# slash-team · 设计

本文件记录「怎么做」与「为什么这么选」。需求（外部可观测行为）在
`specs/extension-slash/spec.md` 与 `specs/init-skill/spec.md`；动机与范围见 `proposal.md`。本文件只写设计层
的取舍、机制与验证策略。

## 1 目标与非目标

**目标**：用户坐在 PM 会话里，用 `/team …` 跑他确认过的那十五条命令（读取 + 他自己动手的操作），输出进对话、
退出码诚实；前门不认识的东西一律拒绝并点名；CLI 自己的守卫一条不少。

**非目标**（设计层的边界，范围层见 proposal）：不给 `/team` 加任何自己的策略（确认框、重试、旗标推断）；
不实现第二条命令清单；不把 `/team` 做成模型工具；不改 CLI 的命令行为；不装到 worker worktree。

## 2 现状与约束（本 worktree 实跑，2026-10-15）

- **Pi 侧扩展的两种加载路径差别是设计的第一块地基**：`pi -e <file>` 只在进程启动时读一次（改完要重启），
  `.pi/extensions/` 是自动发现、`/reload` 热重载。现有三个扩展（notify/bg/inbox-watch）走 `-e`，因为它们是
  会被派单启动的席位进程的自动化；`/team` 是**用户坐在主工作树会话里**用的东西，热重载值钱，所以走
  `.pi/extensions/`（`SKILL.md:166` 已经把这条差别写在扩展表上）。
- **`.pi/extensions` 是 Pi 的项目信任清单里的一员**（与 `.pi/skills` 并列），所以安装它会让「第一次在这个项目跑
  `pi`」的信任弹窗继续存在——提示文案要把两个触发资源都点名。
- **扩展能被 `bun` 直接 import**（`import type` 擦除；`bun -e "await import(<file>)"` → `function`）。这是
  `team doctor` 现在预检 notify 扩展的同一形状（`team_ts_runner`），也是本变更把「纯逻辑」与「Pi 粘合」分开
  的根据：纯逻辑可以被夹具直接喂。
- **端到端可测且封闭**：`pi --mode rpc --no-session --approve`（`PI_CODING_AGENT_DIR` 指向空目录）里发
  `/team status` → 回执 `disposition:"handled"`；`pi.sendMessage` 的自定义消息以 `message_start`/`message_end`
  事件出现；`ctx.ui.notify` 以 `extension_ui_request` `method:"notify"` 出现；子进程退出码（3）完整带回。
  不碰 `~/.pi`、不用网络、不用模型。
- **`pi.exec` 的语义**（`dist/core/exec.js`）：`spawn(command, argv, {shell:false, stdio:["ignore","pipe","pipe"]})`，
  支持 `timeout`（SIGTERM，5s 后 SIGKILL）与 `signal`，返回 `{stdout, stderr, code, killed}`。**stdin 已经是
  ignore**，所以「子进程停下来问输入」这条风险在机制层就不存在；`ExecOptions` **没有 env 字段**，这是环境剥离
  必须绕一层的原因（§3.5）。
- **命令面的规模是设计输入**：`status` 440 行/43 KB、`board` 428 行/41 KB、`digest` 82 行/19 KB、
  `config list` 129 行/12 KB（`proposal.md` 的 Evidence 有全表）。所以「大输出」是常态——正文上限不能定得太小，
  而「一句话→通知」的判据必须按长度而不是按命令名。
- **会话环境会漏 `TEAM_*`**：本会话环境里 9 个（含 `TEAM_ASSUME_YES`）；`common.sh:825` 把它接成
  `TEAM_UPGRADE_CONFIRMED`，即 `config upgrade-models` 会拿它当授权。这是 §3.5 那条剥离的事实依据。
- **身份变量不需要剥**：实测 `TEAM_ROOT=<别的路径> … team status` 在项目里跑，CLI 自己判
  `TEAM_IDENTITY_CONFLICT：身份以目录为准 … 继承值被忽略，本命令按目录执行` 并按 cwd 执行。既然 cwd 就是
  项目根，前门不需要动身份四件套——那属于 CLI 已有的守卫（`boundary`）。
- **既有的安装实现是「一个实现、两个调用点」**：`team_init_install_skills`（`cmd-init.sh`）被 `team init` 与
  `team bootstrap` 共用，冲突表逐格写死在它的注释里；`team doctor` 的 notify 扩展行用 `team_ts_runner` 预检。
  扩展的安装必须长在同一处、同一张冲突表的语法里，不另立一套。

## 3 决策

### 3.1 加载：装进 `.pi/extensions/`，不注入 `-e`

- **选择**：`team init`/`bootstrap` 把 `skills/teamsmith/extension/team.ts` 装成
  `<main worktree>/.pi/extensions/team.ts`；Pi 从工作目录自动发现，`/reload` 即生效。
- **为什么不是 `-e`**：`-e` 要重启进程才读得到；用户是在**正在跑的 PM 会话**里用这个命令，而且技能/扩展会随包
  更新（软链安装下「更新」是立刻的），每次都要重启才生效会把这条命令变成「装好了但用不上」。
- **为什么不同时用 `-e`**：同一条命令被注册两次（重复注册/重复加载诊断）；规格里写作「不得有第二条加载路径」。
- **代价**：worker worktree 里没有它。这是有意的——席位用 bash 调 CLI，斜杠命令是人的界面；也让「命令在哪台
  会话里可用」有一个简单答案：**装它的那棵主工作树**。
- **未选的备选**：用户级 `<agent-dir>/extensions/`（跨项目生效，但那就不是「这个项目的命令」，且会把项目名写进
  用户目录的资源）；`pi install` 包（需要发布+安装动作，超出本变更）。

### 3.2 白名单：一张表，两种行

数据结构（一行一条，`group` / `path` / `shape` / `purpose`）：

| 组 | 命令路径 | 形状 | 用途（菜单里那一句） |
|---|---|---|---|
| read | `status` | `status` 或 `status <ID>` | 名册 + 任务/report 状态 |
| read | `digest` | 固定 | 给 PM 的待办摘要 |
| read | `ps` | 固定 | 容量：RAM/swap/还能再跑几个 agent |
| read | `board` | `board` 或 `board ls` | 看板（BOARD.md） |
| read | `reply list` | 固定 | 关键回复列表（JSON） |
| read | `reply show` | `reply show <n>` | 读第 n 条关键回复 |
| read | `config list` | 固定 | 项目契约的每个键与当前值 |
| read | `version` | 固定 | 磁盘版本 / 本会话加载版本 |
| read | `doctor` | 固定 | 环境自检 |
| read | `meeting inbox` | 固定 | 待回应的会议 |
| read | `meeting read` | `meeting read <slug>` | 读一场会议 |
| action | `pulse up` / `pulse down` / `pulse status` | 路径 + 自由尾巴 | 巡检窗口（起/停/看） |
| action | `config upgrade-models` | 路径 + 自由尾巴 | 模型策略升级（写盘要 `--yes`） |
| action | `meeting say` | 路径 + 自由尾巴 | 给对面 PM 发言（`--intent` 必填） |
| action | `meeting close` | 路径 + 自由尾巴 | 结束一场会议 |

- **读行严格、动行自由**：读行多一个 token 就拒绝（`config list --json`、`version --check` 都拒绝，并给出去终端
  跑的出路）；动行的尾巴是**用户自己的命令行**（`--task-models/--pm-model/--yes/--intent/--knock` 都靠它），
  原样透传、由 CLI 自己校验。这条区分让「表要有多宽」有一个封闭答案。
- **单真源**：菜单（`/team` 与 `/team help`）与参数补全都从这张表渲染；`/team` 无参时先印一句这个面是干什么的，
  再按两组列行（组名沿用 `读取` / `你自己动手`），最后一行说明「不在上面的命令是 PM / 席位的工具，请到终端跑」。
  菜单落点与命令输出同一条（多行 ⇒ 对话正文，见 §3.4）。
- **与 CLI 命令清单（P260 的 `commands.tsv`）的关系**：两张表管两件事——CLI 清单是「CLI 有什么」，`/team` 表是
  「用户在对话里能用什么、怎么一句话解释」。所以**不**从 CLI 清单派生（那会要求 CLI 先有清单，且会丢掉面向用户
  的用途句）；防它们漂移靠一条**可跑的检查**：给表里每行的路径喂一个不存在的旗标，CLI 必须回「未知参数 /
  未知子命令」而不是顶层的「未知子命令：<命令>」（`proposal.md` Evidence ④ 是这条的实测样本；`frobnicate`
  是红侧）。
- **不放进表的命令**（用户已定，规格里以「表外一律拒绝」表达）：`up`/`--fresh-pm`、`dispatch`、`say`、`notify`、
  `close`、`teardown`、`config set`、`smoke`/`gate`/`perf`、`review`、`change`、`archive`、`bg`、`add-agent`、
  `init`、`bootstrap`、`draft`、`outbox`、`inbox`、`thread`、`monitor`、`pr`、`gh`。

### 3.3 参数：自己分词，不经过 shell

- Pi 给命令处理器的 `args` 是**一个原始字符串**，所以要先分词：空白分隔；单引号内原样；双引号内允许空格与
  `\"`、`\\`；引号外的反斜杠转义下一个字符；**未闭合引号 ⇒ 拒绝并说明，什么都不跑**（不猜）。
- 不经过 shell（不用 `bash -c` 拼字符串）：argv 逐元素交给子进程，注入与二次展开都不存在。唯一的例外是 §3.5
  的剥离包装——它的写法 `exec "$0" "$@"` 只做转交，不做二次解析。
- 分词后先做白名单判定，再起进程：**拒绝的路径上零副作用**（无子进程、无窗口、无文件）。

### 3.4 输出与退出码

- **短**：`code === 0` 且（用 `trim` 后）单行、≤ 200 字符 ⇒ `ctx.ui.notify(text, "info")`，不写对话条目
  （用户要的是「一句话用通知」，也给模型上下文省掉无意义的一行）。
- **其它**：写进对话正文的 `custom_message`（`display: true`），正文头是命令与退出码：

  ```text
  $ team <argv...>
  exit <code>                       # 或 killed：超时 60s / 已中止
  --- stdout ---
  …
  --- stderr ---                    # 只在与空时有这一段
  ```

- **失败必须看得见**：`code !== 0` 或 `killed` ⇒ 除正文外再发 `ctx.ui.notify(…, "error")`，文案点名命令与退出码
  （或超时/中止）。绝不把非 0 呈现成成功；stderr 不丢；**失败总是进正文**（哪怕输出只有一行——短的那条规则只
  给成功的单行结果）。
- **有界等待**：`timeout: 60000`（所有表内命令实测都在 5s 内；`doctor` 最慢 4.6s），被 kill 的按失败报，附
  `killed` 事实。
- **保险丝**：输出超过 **500 行或 64 KiB**（先到先算）时，保留前 200 行与后 100 行，中间插一行
  `…（省略 N 行 / M 字节；完整输出：在终端跑 team <argv>）`。今天表里最大的 `status` 是 440 行/43 KB——够不到，
  所以这是防跑飞的保险丝，不是显示策略（大输出进上下文这个取舍见 proposal 的裁定点 1）。
- **模式无关**：`ctx.ui.notify` 在 print/JSON 模式下没有 UI 时是 no-op（Pi 自己的语义），而正文走
  `pi.sendMessage`，所以命令在任何模式下都不报错、不挂住。

### 3.5 边界：前门不加自己的政策

- **只注册命令，不注册工具**：`registerTool` 一次都不调。模型不能自己触发 `/team`——这是「用户亲手输入」的
  结构性保证，也是验收里的一条断言。
- **argv 逐字**：分词之后的 token 一个不改地交给 CLI；不注入 `--yes`、不补默认值、不重排。
- **环境剥离**（唯一的收紧）：因为 `pi.exec` 没有 env 字段，用一层 bash 包装转交：
  `pi.exec("bash", ["-c", 'unset TEAM_ASSUME_YES TEAM_UPGRADE_CONFIRMED TEAM_ALLOW_FOREIGN_SESSION; exec "$0" "$@"', cli, ...tokens], {cwd, timeout})`。
  剥的是「替用户说 yes」的三个变量：会话里漏进来的 `TEAM_ASSUME_YES` 不再是授权（用户打的 `--yes` 照旧到达）；
  `TEAM_ALLOW_FOREIGN_SESSION` 也不再替用户越过身份守卫。其余环境原样继承——CLI 的写守卫、容量、身份、
  生命周期判定一条不改。
  - 备选（proposal 裁定点 2）：完全原样继承。代价是上面那条实测风险；收益是与终端逐字节一致。
- **项目根与 CLI 的解析**（都是纯函数，可被夹具直接喂）：
  1. 项目根：从 `ctx.cwd` 向上找第一个含 `.pi/team/config.sh` 的目录；找不到 ⇒ 拒绝「这里不是 teamsmith 项目」。
  2. CLI 路径（按序）：`<root>/.pi/skills/teamsmith/scripts/team`（项目本地安装，本变更的默认形态）→
     `${TEAM_CLI}`（非默认安装/测试旋钮）→ 扩展文件自己的兄弟目录 `<ext-dir>/../scripts/team`（`-e` 或
     realpath 解析过的软链形态）→ 都找不到 ⇒ 拒绝并指名 `team init`。**顺序是有意的**：项目本地那份永远赢，
     漏进来的 `TEAM_CLI` 在正常安装下不起作用。
  3. `cwd` = 项目根（这也是「命令作用于哪个项目」的判据：CLI 实测按目录执行、把继承身份判成 conflict 并忽略）。
- **不加确认框**：用户自己打的命令不再问第二遍；写入的授权只来自他打的 `--yes`。

### 3.6 安装面

- **一个来源**：技能目录里的 `extension/team.ts`（与现有三个扩展同目录）。项目里的那份是**安装产物**（软链或
  副本），不是第二份真源。
- **同一实现、两个调用点**：`team_init_install_skills` 里跟着技能一起装，`team init` 与 `team bootstrap` 都走它；
  `--no-skills` 连扩展一起跳过（它就是「Pi 项目资源」这一步）。
- **模式与冲突表**（与技能同款）：不存在 ⇒ 装（默认软链、`--copy` 复制）；软链指向本源 ⇒ skip；字节等于本源
  ⇒ skip；软链指向别处 / 带标记的副本 ⇒ 冲突（`--force` 换成本源）；**不带标记的普通文件 ⇒ 连 `--force` 都不
  删**（红线，与技能一致）。标记 = 文件首行的注释 `teamsmith /team extension`（源文件自己带，安装时断言它在）。
- **`.gitignore`**：`.pi/extensions/` 与 `.pi/skills/` 同批加一次。
- **信任提示行**：把两个触发资源都点名（`.pi/skills/`、`.pi/extensions/`），答案不变
  （`pi --approve` / `/trust` / `team init --no-skills`）；同一实现、同一句，`teamsmith-init` 的安装节与
  `references/bootstrap.md` 同步一句。
- **`team doctor` 一行**：项目有项目本地安装时才打印——软链指向本源、或副本字节等于本源 = pass；缺失 = warn +
  修法 `team init`；指向别处/副本漂移 = warn + `team init --force`。doctor 的退出码不受影响；没有项目本地安装
  的项目（用 Pi 包 / `~/.agents/skills` 链接 / settings 里的 skill）**一行都不打**（沿用既有语义，不骚扰）。
- **不进会话指纹**：`team_skill_hash` 仍只哈希 `SKILL.md` + `extension/team-notify.ts`（`init-skill` 的既有
  要求）；`/team` 是可 `/reload` 的资源，没有叫醒运行中会话的理由。

### 3.7 语言（P260 的依赖方向）

今天是中文一份。文案集中在一个字符串表里（一行一条），语言是**表的一列**；P260 若落地 `TEAM_LANG`，
`/team` 跟随同一个解析结果（env > 配置 > 默认），届时本能力加一条 MODIFIED delta 与 en 列——是加数据，不是改写。
**不写进今天的规格**：今天没有任何语言开关可证伪，写进去就是一条永远绿的场景。

### 3.8 验证策略（三层，红侧逐条）

1. **纯逻辑层**（`tests/slash-team.sh`，bun 直接 import 源文件，零进程）：
   `bun -e` 加载 `skills/teamsmith/extension/team.ts`，用一个**假 pi**（记录 `registerCommand`/`registerTool`/
   `exec`/`sendMessage`/`notify`/`confirm` 的调用）驱动命令处理器。断言：argv 逐字（含引号/空格 token）、cwd、
   拒绝路径零 exec、短/长输出落点、退出码映射、超时被杀、无工具注册、无确认框、环境剥离的 unset 列表、项目根与
   CLI 路径的解析顺序、菜单与表一致、补全与表一致。**红侧**：改坏表（加/删一行）→ 菜单断言红；把剥离列表改空 →
   环境断言红；把拒绝分支短路 → 拒绝断言红；还原后全绿。
2. **端到端层**（`tests/slash-team-e2e.sh`，真 pi、RPC、无模型）：夹具项目装好扩展与一个**记录 argv/cwd/env 的
   `team` 桩**，`pi --mode rpc --no-session --approve` 里发 `/team …`，读 JSONL：回执 `disposition:"handled"`、
   `message_start` 的正文与 `display`、`extension_ui_request` 的 notify 级别、桩记录的 argv/cwd/env。
   红侧：桩退出非 0 → 事件里必须出现 error 通知与非 0 退出码；把扩展的 `sendMessage` 改成 notify → 正文断言红。
   按这个仓库的纪律挂进 FAST 的**可见跳过**或全量段（真进程段落进全量；FAST 里显式 SKIP 并点名）。
3. **安装层**（`tests/install-shape.sh` 的扩展组 + `team doctor` 行）：缺/软链/副本/冲突/`--force`/`--no-skills`
   逐格；红侧沿用 install-shape 现有的 scratch-tree 翻转法。门禁接线：新段（`smoke.sh`）+ `section-paths.tsv`
   一行（覆盖新文件与 `extension/team.ts`）+ `section-budgets.tsv` 一行（有实测 band，不许留空）。

## 4 风险与取舍

- **大读命令把上下文喂大**（`status` ≈ 11k token）→ 保留全量是提案的推荐（用户点名要这些读取）；保险丝只防跑飞。
  若用户后来嫌大，切到 transcript-only 是一个夹具可见的小改动（proposal 裁定点 1 已写明）。
- **`.pi/extensions/` 需要项目信任** → 主工作树本来就有 `.pi/skills/`，信任已经是要过的门；提示行同时点名两个资源。
- **表与 CLI 漂移**（CLI 删/改了命令）→ 3.2 的探针检查进段；CLI 的 `team help` 重排（P260）不影响它（它问的是
  dispatcher，不是帮助文本）。
- **`bash -c` 包装层**：多一层转交 → 用 `exec "$0" "$@"` 保 argv 逐字；端到端层用桩比对 argv 与字节，包装
  漏了就被抓。
- **`--force` 会不会误删用户的文件** → 只认标记行；不认的一律不删（与技能红线同款），install-shape 的红侧钉住。
- **残留**：会话里漏进来的 `TEAM_ROOT` 等身份变量由 CLI 自己的 conflict 守卫处理（实测按目录执行）；前门不重复
  实现这条守卫（`boundary` 已拥有它）。

## 5 未决（不影响本 change 的规格与任务拆分）

- P260 落地后加 en 列与 `/team` 的语言跟随（§3.7）——届时一条 MODIFIED delta。
- `team board`/`status` 这类大输出是否换成「只进 transcript」——proposal 裁定点 1，用户点头后是一个小 change。
- 是否给 worker worktree 也装（今天不做：席位不需要，且会让「装在哪」这个问题变复杂）。

## 6 规格 → 任务 的对照（没有孤儿任务，也没有无人认领的场景）

| 规格 | 任务 |
|---|---|
| `extension-slash#/team runs the project's real CLI…` | 2.1–2.4、4.1、4.2 |
| `extension-slash#The whitelist is one table…` | 2.2、2.5、4.1、4.3 |
| `extension-slash#The PM-restarting invocation is refused…` | 2.6、4.1、4.4 |
| `extension-slash#The result is written where it is visible…` | 2.7、4.1、4.2 |
| `extension-slash#The front door adds no authorization of its own…` | 2.8、4.1、4.4 |
| `extension-slash#The command is available where the project installed it` | 3.1–3.5、4.3 |
| `init-skill#team init installs the project skills` | 3.1–3.4、4.3 |
| `init-skill#The project-local install names Pi's trust consequence` | 3.3、3.5、4.3 |
| `init-skill#The project-local install is visible in team doctor, and repairable with team init` | 3.4、4.3 |
