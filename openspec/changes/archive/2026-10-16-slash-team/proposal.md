# slash-team · 在 Pi 里给用户一个 `/team` 前门：常用命令 + 状态读取

## Why

用户 2026-10-14 的要求（本变更的唯一需求来源，原话）：

> Sometimes pm agent inform me that I can run some `team` command if I need to do something with it. It could be
> better to provide slash commands in pi like `/team pulse up`.
>
> B，你需要筛选放进来的命令，不要机械的放入。把通常用户常用的放入，以及状态读取等放入。

（`team up` 那条由用户自己否掉：能在对话里输入说明 PM 在跑，斜杠命令就在那个会话里；PM 崩了就没处输入。）

现状复核（本 worktree 实测，2026-10-15，命令与输出尾见 Evidence）：

- **Pi 侧已有的三个扩展全是席位/PM 的自动化**（`extension/team-notify.ts` 回合结束自动写收件箱、`team-bg.ts`
  后台作业、`team-inbox-watch.ts` 投递换道），都由启动命令 `pi -e <skill>/extension/<file>.ts` 显式注入；
  **没有任何用户可输入的斜杠命令**。用户想跑一条 `team` 命令，现在只能自己切到终端。
- **Pi 的项目扩展目录 `.pi/extensions/` 是自动发现的**（`--approve` 之后加载），`/reload` 热重载即可生效；
  它在 Pi 的项目信任清单里，与 `.pi/skills/` 并列（`docs/configuration.md`、`docs/security.md`）。
  `-e` 注入的模块相反：只在进程启动时读一次，改完要重启（`SKILL.md:166` 已写明这条差别）。
- **命令面是现成的**：用户清单里的每条命令今天都能跑，形状与规模已实测（`status` 440 行/43 KB、`board`
  428 行/41 KB、`digest` 82 行/19 KB、`config list` 129 行/12 KB、`ps` 28 行、`pulse status` 12 行、
  `reply list` 1 行 3.7 KB、`version` 1 行 16 B、`meeting inbox` 1 行）。**大输出是常态，不是边角**。
- **扩展的纯逻辑可以被 `bun` 直接 `import`**（`import type` 被擦除，不需要 pi 包在场）——这正是 `team doctor`
  今天预检 notify 扩展的形状（`team_ts_runner` + `await import(...)`）。
- **端到端可测且封闭**：`pi --mode rpc --no-session --approve` 里发 `/team status`，回执
  `disposition:"handled"`，扩展写进对话的自定义消息以 `message_start`/`message_end` 事件出现，子进程的退出码
  完整带回；`PI_CODING_AGENT_DIR` 指向空目录（无凭据、无模型）也照跑——夹具不碰 `~/.pi`、不用网络。
- **守卫面的事实**：`TEAM_ASSUME_YES=1` 会把 `config upgrade-models` 的预览直接变成写
  （`common.sh:825`：`TEAM_UPGRADE_CONFIRMED="${TEAM_ASSUME_YES:-0}"`），而 `TEAM_*` 会从会话环境漏进新进程——
  本会话的环境里就有 `TEAM_ASSUME_YES`（还有 8 个别的 `TEAM_*`）。前门如果原样继承环境，用户没打的
  「yes」会替他签字。

## What Changes

### 一个前门，不是一套重实现

- 新扩展 `skills/teamsmith/extension/team.ts`（与现有三个扩展同一个目录），由 `team init`/`bootstrap` 装到
  `<main worktree>/.pi/extensions/team.ts`（默认软链、`--copy` 复制、冲突表与 `.pi/skills/` 同源同款）。
  Pi 从那里自动发现；`/reload` 或下次启动即可用。
- 它只做两件事：**认命令**（白名单）+ **把用户打的 token 原样交给真的 `team` CLI**（子进程，cwd = 项目根）。
  一条命令都不重新实现，不注入任何旗标，不解析命令语义。
- **不注册任何模型可调用的工具**：`/team` 是用户亲手输入的斜杠命令，模型做不了这件事。

### 白名单是一张数据表（单真源）

- 两组、十五条（用户确认过的清单）：**读取** `status`、`digest`、`ps`、`board`、`reply list`、
  `reply show <n>`、`config list`、`version`、`doctor`、`meeting inbox`、`meeting read <名>`；
  **你自己动手** `pulse up|down|status`、`config upgrade-models …`、`meeting say …`、`meeting close`。
- 每条一行数据：组 / 命令路径 / 只读行的固定形状 / 一句用途。`/team`（无参，或 `/team help`）的菜单与
  参数补全都从这**同一张表**渲染——加一行就出现在菜单里，删一行就同时消失（apply 的红侧钉这条）。
- 读取行是**严格形状**（多一个 token 就拒绝，例如 `config list --json`）；动作行是**命令路径 + 用户自己的尾巴**
  （`meeting say` 需要 `--intent`、`config upgrade-models` 需要 `--task-models/--pm-model`，这些由用户打、
  原样透传）。清单外的命令（`dispatch`、`say`、`notify`、`close`、`teardown`、`config set`、`review`、
  `change`、`archive`、`bg`、`add-agent`、`init`、`bootstrap`、`draft`、`outbox`、`inbox`、`thread`、
  `monitor`、`smoke`/`gate`/`perf`、`pr`、`gh` …）**拒绝并点名**：「这是 PM / 席位的命令，请到终端执行」，
  一个进程都不起。
- 表里每行的命令路径都必须是 CLI 真的分发的路径（apply 的探针：给该路径喂一个不存在的旗标，必须得到
  「未知参数/未知子命令」而不是顶层的「未知子命令：<命令>」——`frobnicate` 那条就是红侧样本）。

### 两个已知的坑写进规格

1. **会重启/新建 PM 会话的命令必须明确拒绝**：`up` 与任何带 `--fresh-pm` 的调用一律拒绝并说明——这个会话
   就是 PM 会话，从这里重启会把当前对话一起带走；要重启请到终端（用户已否掉把 `up` 放进来）。
2. **清单里没有长命令、也没有开窗口的命令**，所以没有「卡住对话」的问题：子进程不接 stdin、有 60s 有界等待，
   到点杀掉并如实报失败（不是挂住）。

### 输出与退出码

- **一句话的结果**（单行且 ≤ 200 字符，如 `version`、`meeting inbox`）→ 只弹一条通知。
- **其它**→ 进对话正文（Pi 的 `custom_message`，display 打开）：正文头写明 `$ team <argv>` 与退出码，随后是
  stdout、stderr。**失败必须是看得见的失败**：非 0 退出/被杀 ⇒ 错误通知（点名退出码或原因）+ 正文，绝不
  吞成成功。
- 保险丝：输出超过 500 行或 64 KiB 时，中段省略并**显式说明**完整输出去哪看——今天清单里最大的 `status`
  是 440 行/43 KB，够不到这条线（它是防跑飞的保险丝，不是显示策略）。

### 安全边界：前门不替用户做主

- CLI 自己的守卫**原样生效**（写配置要 `--yes`、派单守卫、容量、身份、生命周期），扩展不加自己的确认框、
  不注入 `--yes`。
- 唯一一处收紧：**子进程环境剥掉「替你说 yes」的三个变量**（`TEAM_ASSUME_YES`、`TEAM_UPGRADE_CONFIRMED`、
  `TEAM_ALLOW_FOREIGN_SESSION`）。用户打的 `--yes` 原样到达，没打就永远是预览；这是为了不把会话里漏进来的
  「yes」当成用户的授权（本会话环境里就有 `TEAM_ASSUME_YES`）。

### 安装与可见性

- `team init`/`bootstrap` 的**同一步**装扩展（老项目重跑 `team init --force` 就是升级路径）：`link`/`copy`、
  冲突表、`.gitignore` 加 `.pi/extensions/`、信任提示行同时点名两个触发资源。
- `team doctor` 加一行 `/team` 扩展的安装态（软链指向本源/副本与运行版本一致 = pass；缺失/指向别处/副本版本不同
  = warn + `team init --force`），**只在项目本来就有项目本地安装时**打印（用 Pi 包的项目不被骚扰）。
- 新扩展**不进**会话指纹（`team_skill_hash` 仍只哈希 `SKILL.md` + `extension/team-notify.ts`）：它是可
  `/reload` 的资源，不需要因此叫醒正在跑的会话。

## Capabilities

### New Capabilities

- `extension-slash`: 用户从 Pi 对话里输入 `/team …` 调用真 CLI 的这个面——白名单、单真源菜单、参数分词、
  输出位置与退出码、以及「前门不加自己的政策」的边界。

### Modified Capabilities

- `init-skill`: 三条既有需求随安装面一起改——`team init` 的安装步骤（同类目里多装一个扩展）、信任提示行
  （触发资源现在是两个目录）、`team doctor` 的安装可见性（多报告这一个扩展）。

## Impact

- 新增：`skills/teamsmith/extension/team.ts`、`skills/teamsmith/tests/slash-team.sh`（bun 假 pi 的逻辑面）、
  `skills/teamsmith/tests/slash-team-e2e.sh`（真 pi RPC 端到端）。
- 改：`scripts/lib/cmd-init.sh`（安装步骤）、`scripts/lib/cmd-project.sh`（doctor 一行 + gitignore 一项）、
  `skills/teamsmith/SKILL.md`（扩展表一行 + 加载方式的说明）、`tests/install-shape.sh`（扩展冲突表）、
  `tests/smoke.sh`（一个新段）、`tests/section-paths.tsv`、`tests/section-budgets.tsv`。
- 不碰：`team` CLI 的任何命令行为（只加安装/doctor 的可见性）、面板、`.pi/team/config.sh` 的键、
  `TEAM_VERSION`/会话指纹、worker worktree（扩展只装在主工作树；席位不需要斜杠命令）。
- 依赖方向（P260）：帮助面若落地语言层（`TEAM_LANG`），`/team` 的文案跟随它；今天只有中文一份，语言列留成
  数据表的一列，后续是加一列而不是改写。这不进本变更的规格（今天不可证伪的场景不写进 delta）。

## 需要 PM 裁定的四点（提案按推荐版本写）

1. **大输出进上下文**：推荐**全量进正文**（保险丝 500 行/64 KiB）。理由：用户要的就是 `status`/`board` 这类
   读取，截断等于把用户要的东西收走；代价是它同时进模型上下文（`status` ≈ 11k token）。
   备选 A：更小的显示上限；备选 B：只进 transcript、不进模型上下文（`appendEntry` + entry renderer，另写一个
   渲染器，正文仍可见但模型看不到）。两条都不难，是产品取舍，请裁定。
2. **环境剥离**：推荐剥离 `TEAM_ASSUME_YES` / `TEAM_UPGRADE_CONFIRMED` / `TEAM_ALLOW_FOREIGN_SESSION`
   （用户没打的 yes 不算授权）；备选是**原样继承**（与终端逐字节一致，代价是会话里漏进来的 yes 会替用户签字）。
3. **doctor 行**：推荐加（安装态可见、可修）；备选是完全不碰 CLI 的输出（代价：`--copy` 装的旧扩展没有任何
   可见性）。
4. **安装默认**：推荐**软链**（与 `.pi/skills/` 一致：跟随包更新，不存在陈旧副本）；`--copy` 保留给
   临时/无共享源的场景。

## Evidence（本阶段实跑，2026-10-15）

1. **真 pi 端到端**（空 agent dir、无凭据、无模型）：

```bash
mkdir -p /tmp/p265-probe/proj/.pi/extensions && cat > …/team.ts <<'EOF'   # registerCommand("team") → pi.exec → pi.sendMessage
cd /tmp/p265-probe/proj && { printf '{"id":"1","type":"prompt","message":"/team status"}\n'; sleep 6; } \
  | HOME=/tmp/p265-probe PI_CODING_AGENT_DIR=/tmp/p265-probe/agentdir \
    "$HOME/.bun/bin/pi" --mode rpc --no-session --approve --session-dir /tmp/p265-probe/sessions2
```

输出（尾）：`{"type":"message_start","message":{"role":"custom","customType":"team","content":"$ team status\nexit=3\n--- stdout ---\nargv: status\nline two\n--- stderr ---\nboom\n","display":true}}` /
`{"id":"1","type":"response","command":"prompt","success":true,"data":{"disposition":"handled"}}`，
另有一条 `extension_ui_request` `method=notify` `notifyType=error`。即：项目扩展被加载、命令被执行、
argv 与退出码完整、输出进了对话、失败是 error 通知。

2. **扩展可被 bun 预检**：`"$HOME/.bun/bin/bun" -e "const m = await import('/tmp/p265-probe/proj/.pi/extensions/team.ts'); console.log(typeof m.default)"` → `function`。

3. **命令面实测**（规模）：`status` rc=0 440 行/43419 B、`digest` rc=0 82/19171、`ps` rc=0 28/1354、
   `board` rc=0 428/40867、`reply list` rc=0 1/3744、`reply show 1` rc=0 7/154、`config list` rc=0 129/11814、
   `version` rc=0 1/16、`doctor` rc=1 36 行（本项目当前有一条真 warn/err —— 非 0 退出是真实场景，不是异常）、
   `meeting inbox` rc=0 1/33、`pulse status` rc=0 12/1084、`meeting read <不存在的 slug>` rc=1 且 stderr 一行。

4. **「表里的路径 CLI 真的分发」探针**（每行喂 `--teamsmith-slash-probe`）：清单里的 18 个形状全部落在
   「已分发」（rc=0 或 `未知参数`/`board: 未知子命令`），`frobnicate` 是唯一得到顶层
   `✗ 未知子命令：frobnicate` 的一条 —— 这就是 apply 那条断言的红侧样本。

5. **环境里已经有「yes」**：`env | grep '^TEAM_'` 9 条，含 `TEAM_ASSUME_YES`；
   `common.sh:825` 把它接成 `TEAM_UPGRADE_CONFIRMED` —— 即 `config upgrade-models` 会拿它当授权。

## Out of scope

- 本阶段只写提案：apply 与独立 verify 另派席位（`apply` 简报要等 PM 的提案评审 ACCEPTED）。
- 不放进来的命令（用户已定）：`up`/`--fresh-pm`（PM 会话自身）、`dispatch`、`say`、`notify`、`close`、
  `teardown`、`config set`、`smoke`/`gate`/`perf`、`review`、`change`、`archive`、`bg`、`add-agent`、`init`、
  `bootstrap`、`draft`、`outbox`、`inbox`、`thread`、`monitor`、`pr`、`gh` —— 会写账本/会起进程/会改配置/
  是 PM 工作的，都不进。
- worker worktree 的安装（席位用 bash 调 CLI，不需要斜杠命令）；把 `/team` 做成**模型工具**（用户亲手输入是
  这条边界的一部分，不做）。
- 帮助面（P260）的语言层落地前的 en 文案；面板；`team` CLI 的命令语义。
