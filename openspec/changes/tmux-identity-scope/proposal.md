# tmux-identity-scope · 本项目起窗口时不再把身份写进共享 tmux server 的全局环境（并让历史泄漏不再挡住别的项目）

## Why

用户 2026-10-15 报的现象（原文与 PM 的现场实测见任务书 P268）：这台机器上**三个项目共用一个 tmux 服务**。
GNOME 崩溃带走 tmux 服务、用户重开之后，在**别的项目**的目录里跑 `team pulse up` 被拒：

```
✗ 身份冲突（pulse）：当前目录属于 '<项目甲>'（…/<项目甲>），而继承的环境指向别的项目
  TEAM_ROOT=…/本仓（继承） ‹ …/<项目甲>（按目录推导）
  TEAM_SESSION=teamsmith（继承） ‹ <会话乙>（按目录推导）
```

守卫本身是对的（继承的身份不许静默赢过 cwd），**错的是泄漏**：本项目起自己的服务/窗口时，把调用者的
身份写进了 tmux **server 的全局环境**；该 server 上**任何**项目新开的窗口/pane 都会继承它，于是别的项目
的每一条命令都被自己的身份守卫拒掉。这正是「人类照着 PM 的指令去跑一条命令」这个场景 —— 不是各项目自己
的启动坏了（三个正在跑的 Pi 身份都是对的），而是**它们启动之后新开的 shell 继承了一个不属于它的身份**。

## 现状复核（本 worktree 只读实测，数字为度量）

1. **机制**（私有 socket 实测，tmux 3.7b）：server 在**启动那一刻**把**启动它的那个客户端**的环境复制进
   server 的**全局环境**；此后新建 session/window/pane 的环境来自**全局环境**（会话环境），**不是**来自
   发起那次调用的客户端环境。实测：先以 `TEAM_PROJECT=leaky` 启动 server，再以 `TEAM_PROJECT=second`
   `new-session` → 全局环境仍是 `leaky`、新 pane 里也是 `leaky`；`new-session -e VAR=v` 只写**会话**环境
   （全局环境不动）。**能启动 server 的命令只有 `new-session`/`new-window`/`start-server`**（实测
   `kill-*`/`has-session`/`list-*`/`display-message`/`send-keys`/`respawn-pane`/`split-window` 在没有
   server 时都是 rc=1 且**不**建 socket）；`tmux start-server` 单独跑留不下 server（`exit-empty` 默认
   开着，没有 session 就退出）—— 所以「先起一个干净 server」这条捷径不存在。
2. **本项目真的会泄漏**（用真 CLI 在私有 socket 上复现）：`team up`（stub PM 命令）之后
   `tmux show-environment -g | grep ^TEAM_` = **12 个**变量，全部指向本 fixture 项目：
   `TEAM_ROOT`、`TEAM_MAIN_ROOT`、`TEAM_PROJECT`、`TEAM_SESSION`、`TEAM_CONFIG_FILE`、`TEAM_ASSUME_YES`、
   `TEAM_PM_CMD`、`TEAM_PM_BIN`，外加 agent 窗口里继承来的 `TEAM_TMUX_CALLS_LOG`、`TEAM_TMUX_REAL`、
   `TEAM_SIGNAL_CALLS_LOG`、`TEAM_SIGNAL_REAL`；同一 server 上该项目的**会话环境是 0 个** ——
   与 PM 在现场看到的一模一样（连「会话里 0 个、全局里一堆」这个对照都一致）。
3. **受害面**：同一个 server 上另建项目 B 的 session 后，B 的新 pane 里 `env | grep ^TEAM_` 拿到的是
   A 的值；在 B 的目录里带着这些继承值跑 `team up` → **rc=1 + `身份冲突被拒` + 什么都没建**
   （用户报的原形状，本 worktree 已复现）。
4. **唯一的 server 启动点**：产品面里能建 session 的调用只有一处 ——
   `skills/teamsmith/scripts/lib/common.sh` 的 `team_tmux_ensure_session`（`tmux new-session`）；其余
   建窗口点（`cmd-watch.sh` 的 pulse 窗口、`cmd-agents.sh` 的派单占位窗口、`cmd-draft.sh` 的草稿窗口、
   `team_tmux_new_window`）都需要已存在的 session，**不可能**启动 server。所以「谁把身份写进全局环境」
   的答案是**一个函数**。
5. **守卫的既有夹具必须保持红**：`smoke.sh` §32③/§32⑧a（`m40_foreign`：显式把 A 的四件套放进环境，
   在 cwd=B 跑 `board add`/`pulse up`）今天要求 **rc=1 且拒绝**。它们的环境值**不在** server 的全局环境里
   （夹具私有 socket），所以「按来源归因」的判据不会把它们放行 —— 这是本次设计的关键约束。
6. **审计面**：`boundary#The gate's actions are logged…` 写着「每次过闸门的调用 SHALL 恰好追加一行到
   `$TEAM_TMUX_CALLS_LOG`」，而闸门（`scripts/shim/tmux`）只在**调用者环境里有这个键**时才写日志。
   「把命名空间洗干净」与「这一行照旧要写」因此会打架 —— 见「需要 PM 裁定的点 C」。

## What Changes

### 1. 写侧（根因）：起窗口/服务的那次 tmux 调用不带本项目的 `TEAM_*` 命名空间

产品面所有 tmux 调用收进一个包装（`team_tmux`），**建对象的那几条**（`new-session`/`new-window`，
连同 `split-window`/`respawn-*` 一起按同一条规则）把**整个 `TEAM_*` 命名空间**从子进程环境里摘掉再执行；
**kill-\* 那几条保留环境**——M67 闸门的 `allowed-owned` 判定正是绑在 `TEAM_SESSION`/`TEAM_ROOT` 上，而
kill 类调用**不可能**启动 server（实测），所以保留它们既不泄漏也不削弱闸门。

身份仍按 M40 已有的写法到达窗口：**渲染进窗口的启动命令里的显式 export**
（`team_identity_env_prefix`：先 unset 再写目标目录的身份），PM/pulse/worker/草稿四个窗口今天都带着它。

**不改**闸门语义、不改配置键、不引入「先起一个干净 server」这类捷径（实测不存在）。

### 2. 写侧的证据面：全局环境一个 `TEAM_*` 都不许有，且**只读**可查

红侧直接断言根因：私有 socket 上从「带着身份与闸门 pin 的 shell」跑 `team up` 之后，
`tmux show-environment -g` 里**没有**本项目的任何 `TEAM_*`；同一 server 上**另一个项目**的 session 的
pane 里也没有；而本项目自己四个窗口的环境里身份照旧（worker = 它的工作树、PM/pulse/草稿 = 主工作树）。
再补一条**行为**断言（不是 grep 文本）：跑完建窗口/关窗口/自己的破坏性调用之后，server 的全局环境
逐字节未变。

### 3. 读侧（自愈）：**来源**是共享 server 全局环境的分歧，按 cwd 解析并说明一行

身份闸门在「继承值与 cwd 推导不一致」时，先问一句**来源**：如果**每一个**冲突变量的继承值都**恰好等于**
运行中的 tmux server 在**全局环境**里持有的那个值（且调用发生在 tmux 里），那这就是**共享 server 的残留**，
不是调用者的意图 → 按 cwd 解析、在 **stderr** 打印一行（点名「运行中的 tmux server 的全局环境」+ 清除它的
那条命令），**不拒绝**；**不**去清、不重写共享 server 的全局环境（跨项目状态不擅自改）。
**其余一切分歧照旧拒绝**（同样的措辞、同样的退出码、同样的 `TEAM_ALLOW_FOREIGN_IDENTITY=1` 出路）：
显式继承的外来环境、值不在 server 全局环境里的分歧、没有 tmux 可归因的分歧、真嵌套（夹具/门禁）。
`team doctor` 增一行**只读**报告（点名变量 + 清除命令，不改动）。

### 4. 审计面（裁定点 C）：让「洗掉命名空间」不制造日志黑洞

包装把命名空间摘掉之后，闸门在**调用者环境里没有 pin** 时就写不出那一行。提案按**推荐解 A1** 落笔：
闸门在 `$TEAM_TMUX_CALLS_LOG` 缺席时，把日志目标解析到**它自己 cwd 所属项目**的
`state/tmux-calls.log`（`boundary` 的一条 MODIFIED：一行措辞 + 一条场景），于是
「每次过闸门的调用恰好一行」照旧成立、审计无洞，且**别的项目的 pane 里的调用记到它自己项目的日志**，
不再写进本项目的 forensics 文件。备选 A2（不动 boundary：包装保留闸门的四个 pin，只洗身份/配置族）与
A3（接受建对象调用不写日志这个洞）见裁定点 C。

## Capabilities

### Modified Capabilities

- `pm-lifecycle`（两条 **ADDED**）：
  - `Starting this project's tmux objects never writes its identity into the shared server's environment`：
    建对象的那次 tmux 客户端不带本项目 `TEAM_*` 命名空间；身份只经会话作用域或窗口启动命令到达；
    产品路径不写 server 全局环境；两个可观察后果（全局环境无本项目 `TEAM_*`、本项目自己的窗口仍有身份、
    别的项目在同一 server 上的 session 什么都继承不到；全局环境逐字节不变）。
  - `Identity inherited from the shared server's global environment resolves by the working directory`：
    来源可归因于共享 server 全局环境时分歧按 cwd 解析 + stderr 一行 + 不清共享状态；其余分歧**照旧拒绝**；
    `team doctor` 只读报告残留。
- `boundary`（一条 **MODIFIED**）：`The gate's actions are logged, and no window carries a destructive-call
  grant` —— 日志目标在 `$TEAM_TMUX_CALLS_LOG` 缺席时解析到 cwd 所属项目的 `state/tmux-calls.log`
  （其余措辞与八条既有场景逐字保留，另加一条场景）。这是裁定点 C 的推荐解；若 PM 裁 A2/A3，这条 delta
  换成对应的措辞（A3 同样要 MODIFIED：既有那句「每次恰好一行」在新情形下会变成假话）。

不新增 capability：身份解析、守卫、闸门、日志都在既有能力里；本次只加「写侧的作用域」与「读侧的归因」。

## Impact

- 产品面（apply 阶段写集）：
  - `skills/teamsmith/scripts/lib/common.sh` —— tmux 调用包装（洗命名空间 + 建对象调用点接入）、
    身份闸门的**归因**判定与那一行说明；
  - `skills/teamsmith/scripts/lib/cmd-watch.sh`（pulse 窗口/`team up` 的建窗口点）、
    `skills/teamsmith/scripts/lib/cmd-agents.sh`（派单占位窗口）、`skills/teamsmith/scripts/lib/cmd-draft.sh`
    （草稿窗口）—— 接入包装；
  - `skills/teamsmith/scripts/shim/tmux` —— **仅**裁定点 C 选 A1 时改日志目标解析（约 10 行）；
  - `skills/teamsmith/scripts/lib/cmd-project.sh` —— `team doctor` 的只读残留报告（约 6 行）。
- 夹具面：新增 `skills/teamsmith/tests/tmux-identity-leak.sh`（私有 socket、私有 fixture 项目，自带
  `--all/--select` 与红侧）；接入门禁段 **§32**（身份段）并按其自测口径补预算行 —— 见裁定点 D。
- 规格面：`openspec/changes/tmux-identity-scope/specs/pm-lifecycle/spec.md`（2 ADDED）、
  `.../specs/boundary/spec.md`（1 MODIFIED）。
- 兼容性：无新配置键、无状态格式变化、无面板改动；`team` 的命令行、退出码、拒绝措辞在**非归因**情形下
  逐字不变；`TEAM_ALLOW_FOREIGN_IDENTITY=1` 语义不变。
- 与在飞任务的分工：`tests/smoke.sh`、`tests/section-paths.tsv`、`tests/section-budgets.tsv`、`tests/lib/*`
  此刻被 P251/P261 改动、P264 排队（它按「文本类拿掉」会重排这些表）—— 见裁定点 D 与 `deps:`。

## 需要 PM 裁定的点（提案按推荐版本落笔）

1. **A：delta 放两个 capability**（推荐：是）。`pm-lifecycle` 装「起对象时身份的作用域」与「读侧归因」
   （用户的观察点就在 `team up`/`pulse up`）；`boundary` 装闸门日志目标那一条（既有 `boundary` 规格正好
   写着这条日志合同，按 review 清单第 7 条，取代它必须是 MODIFIED，不能在新要求里另说一套）。
   若 PM 要求只动一个 capability：把 boundary 那条 MODIFIED 的措辞并进 `pm-lifecycle` 会让
   「日志恰好一行」在 boundary 里变成假话（不推荐）。
2. **B：是否给会话加 `-e` 身份**（推荐：**加**，四个身份变量）。加 = `new-session -e TEAM_ROOT=… …`，
   身份落在**本项目自己的会话**作用域（实测：只写会话环境、不动全局环境），于是**人手**在本项目会话里
   新开的窗口照旧带本项目身份（M67 闸门对人手 `tmux kill-window -t <本项目会话>:x` 的
   `allowed-owned` 判定因此与今天一致）。不加 = 更小，但人手新开的窗口没有身份：`team` 命令照旧按 cwd
   工作（无冲突），而人手敲的 `tmux kill-*` 会被闸门 fail-closed 拒绝（要走 `team close`/`teardown`）。
   两种都在同一 server 上不泄漏；差别只在「人手窗口的便利」。
3. **C：审计面怎么补**（推荐：**A1**）。A1 = 闸门在 pin 缺席时按 cwd 解析日志目标（`boundary` MODIFIED，
   审计无洞，且别的项目的 pane 记到自己项目的日志）；A2 = 包装保留闸门的四个 pin、只洗身份/配置族
   （改动最小、不动 boundary，代价：全局环境里仍留四个指向本项目的 pin，**「本项目 `TEAM_*` 不得出现」这条
   断言必须收窄**，且别的项目的 pane 会把 tmux 调用写进本项目的 forensics 日志）；A3 = 接受「建对象调用
   不写日志」这个洞（同样要 MODIFIED，把那句「每次恰好一行」改成有例外的措辞）。
4. **D：门禁落点**（推荐：**新增独立夹具 + 接入 §32**）。夹具 `tests/tmux-identity-leak.sh`（私有 socket、
   私有 fixture，自带 `--all/--select`、红侧、末行 ✓/✗）由 §32 调用；§32 的预算行按 apply 的**实测**重填，
   并给 §32 的 patterns 补 `skills/teamsmith/scripts/lib/common.sh`（本次修复的落点，今天不在选段表里）。
   代价：碰 `tests/smoke.sh` 与两张 tsv（P251/P261 在写、P264 排队）→ 交付前 `git merge main`、冲突按双方
   保留；若 PM 希望零共享文件风险，可裁「本次不接门禁段、只交付独立夹具」，代价是这份合同在增量跑里没有牙
   （不推荐：这正是用户报过的缺陷）。
5. **E：`team doctor` 的只读残留行**（推荐：**要**）。它是「人类自己去看、自己决定清不清」的出口，
   与共享 server 属于用户的管辖一致；只读、不改任何东西。若 PM 想缩小范围可删（归因那一行仍在）。

## Acceptance（apply / verify 阶段执行；本阶段只写提案，不跑）

```bash
bash skills/teamsmith/tests/tmux-identity-leak.sh --all          # 新夹具：写侧 + 读侧 + 红侧
bash skills/teamsmith/tests/smoke.sh --select 32                 # 身份段（含既有 ①–⑧ 回归）
bash skills/teamsmith/tests/section-guard.sh --budget-check      # 若按裁定点 D 补了预算行
bash skills/teamsmith/tests/tmux-lint.pl --selftest              # 闸门/夹具的 tmux 隔离 lint
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
rm -rf /tmp/p268-trial && mkdir -p /tmp/p268-trial && cp -a openspec /tmp/p268-trial/openspec \
  && (cd /tmp/p268-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y tmux-identity-scope \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)
```

夹具与命令的最终形态以 apply 冻结的接口为准；**两条归因判据、四条红侧方向（全局环境零 `TEAM_*`、
归因后按 cwd 执行、非归因照旧拒绝、真嵌套不误清）不得改**（改了就是换合同，要重新走提案）。

## Out of scope

- 不改身份守卫的语义（继承不许静默赢 cwd）、不改 `TEAM_ALLOW_FOREIGN_IDENTITY`、不改配置键与配置 CLI。
- 不碰别的项目的仓库、会话与状态；**不**去清别的项目在共享 server 全局环境里的残留（只报告、不代改）。
- 不改 M67 闸门的判定（按目标 + argv token）、不改它的拒绝措辞与退出码。
- 不引入「先起一个干净 server」「把 `TEAM_*` 换成非 TEAM 名字」「用 `env -i` 重建整份环境」这类做法
  （实测不存在/会把泄漏藏进 grep 看不见的地方/会打掉窗口需要的环境）。
- 不做跨项目协调：用户现场的其他项目要不要重启自己的会话，由用户与那些项目的 PM 决定。
