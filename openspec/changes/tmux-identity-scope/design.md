# tmux-identity-scope · design

合同文本在 `specs/pm-lifecycle/spec.md`（2 ADDED）与 `specs/boundary/spec.md`（1 MODIFIED）。本文件是
**怎么做到**、**为什么不是别的做法**、以及**判据误判的代价与兜底**。数字全部来自本 worktree 的只读实测
（私有 socket、私有 fixture 项目，未碰真实 server 与真实项目）。

## 0 机制（决定整套修法的两条事实）

1. **server 在启动那一刻复制启动者的环境到全局环境**；之后新建的 session/window/pane 的环境来自
   **全局环境**，不来自发起该次调用的客户端环境。
   - 实测：`TEAM_PROJECT=leaky` 起 server → 再 `TEAM_PROJECT=second tmux new-session` → 全局环境仍
     `leaky`，新 pane 里也是 `leaky`；`new-session -e TEAM_PROJECT=third` 只写**会话**环境，全局环境不动。
   - 推论：**泄漏只发生在「谁启动了 server」这一件事上**；调用点再多，只要起 server 的那次调用不带
     命名空间就干净。
2. **只有建对象的命令能启动 server**。私有 socket 上逐个实测（没有 server 时）：`new-session` 建 socket；
   `kill-session`/`kill-window`/`has-session`/`list-sessions`/`display-message`/`send-keys`/`respawn-pane`/
   `split-window` 全部 rc=1 且**不**建 socket。`start-server` 单独跑 rc=0 但**留不下 server**
   （`exit-empty` 默认 on：没有 session 就退出）——所以「先起一个干净 server」不存在。
3. 产品面里唯一能启动 server 的调用点：`common.sh` 的 `team_tmux_ensure_session`
   （`tmux new-session -d -s "$TEAM_SESSION" …`）。其余建窗口点（`cmd-watch.sh` pulse、`cmd-agents.sh`
   派单占位、`cmd-draft.sh` 草稿、`team_tmux_new_window`）都需要已存在的 session。

真 CLI 复现（`team up`，stub PM 命令，私有 socket）：全局环境 **12 个** `TEAM_*`（身份四件套 +
`TEAM_CONFIG_FILE`/`TEAM_ASSUME_YES`/`TEAM_PM_CMD`/`TEAM_PM_BIN` + 闸门四个 pin），该项目自己的**会话环境
0 个**；同一 server 上项目 B 的新 pane 继承这些值，在 B 的目录里跑 `team up` → rc=1 + `身份冲突被拒`。

## 1 写侧：起对象的那次调用不带命名空间

**做法**：产品面所有 tmux 调用收进一个包装（`team_tmux`）。

- **建对象的动词**（`new-session`/`new-window`/`split-window`/`respawn-*`）→ 子进程环境里摘掉**整个**
  `TEAM_*` 命名空间（`env -u` 逐个已知键，或子 shell 里 `compgen -v TEAM_` 全 unset 后 `command tmux`）。
- **破坏性动词**（`kill-server`/`kill-session`/`kill-window`/`kill-pane`）→ **保留**环境：M67 闸门的
  `allowed-owned` 判定正是绑在 `TEAM_SESSION`/`TEAM_ROOT` 与 cwd 的关系上，而 kill 类调用**不可能**启动
  server（事实 2），所以「保留」既不泄漏也不削弱闸门。
- **只读动词**（`list-*`/`has-session`/`display-message`/`show-*`）→ 无所谓；按「只保留 kill 类带身份」
  这条更简单的规则统一成：**只有 kill 类带身份**。

**身份怎么到达窗口**：沿用 M40 已有的唯一写法 —— 渲染进窗口命令的显式 export
（`team_identity_env_prefix`：先 unset 再写目标目录的身份）。今天 PM/pulse/worker/草稿四个窗口都带着它
（`common.sh:3050/3078`、`cmd-watch.sh:2039`、`cmd-agents.sh:1454`、`cmd-draft.sh:49`），本变更不新增通道。

**裁定点 B（是否给会话加 `-e`）**：加了以后，人手在本项目会话里新开的窗口照旧带本项目身份（实测：
`-e` 只写会话环境），M67 闸门对「人手敲的 `tmux kill-window -t <本项目会话>:x`」的 `allowed-owned` 判定
与今天一致。代价：多一处「身份落在会话作用域」的断言；不加则人手窗口没有身份（`team` 命令照旧按 cwd 工作，
但人手敲的 `kill-*` 会被闸门 fail-closed 拒）。**推荐加**，因为它把「今天靠泄漏偶然成立的便利」变成
「作用域正确的显式行为」，且完全不写全局环境。

### 被否决的做法（各有实测或结构性理由）

| 做法 | 为什么不要 |
|---|---|
| 先 `tmux start-server` 起一个干净 server | 实测留不下 server（`exit-empty`）：没有 session 立刻退出，随后的 `new-session` 还是「启动者」 |
| 起完再 `set-environment -gu` 清全局环境 | 新会话的第一个 pane 已经带着泄漏环境创建了；清与建之间有竞态窗口 |
| 把 `TEAM_*` 换成非 TEAM 名字（如 `TMUXGATE_LOG`） | 泄漏照旧，只是 grep `^TEAM_` 看不见了 —— **假绿比没有更糟** |
| `env -i` 重建整份环境 | 会打掉窗口/工具需要的 TERM/PATH/语言等；且同样需要第二个实现来补回 |
| 所有 tmux 调用一律洗掉身份 | kill 类会因闸门看不到绑定身份而被拒 → CLI 连自己的窗口都关不掉（`close`/`teardown`/`pulse down` 全红） |
| 让闸门（PATH 里的 shim）去洗子进程环境 | 覆盖不到用户报的那条路：**server 死时它的窗口也没了**，起 server 的调用只可能来自「没有 shim 的普通终端」；shim 只活在窗口里，而窗口存在就意味着 server 已存在 |

## 2 读侧：归因判据（含误判代价与兜底）

**判据**：身份闸门已有「冲突对」（`team_identity_conflict_pairs`：继承值 ≠ cwd 推导值）。新增一步
**来源归因**：

```
可归因 ⇔ 调用发生在 tmux 里（TMUX 非空）
        且 对**每一个**冲突变量 V：tmux show-environment -g V 报出的值 == 继承值
```

（实测取值形状：`VAR=value`（rc=0）或 `unknown variable: VAR`（rc=1）。）

- **可归因** → 这是**运行中的共享 server 的全局环境残留**，不是调用者意图 → 按 cwd 解析、**stderr** 一行
  点名来源与清除命令、**不拒绝**、**不写**共享 server 的任何东西。
- **不可归因** → 照旧拒绝（措辞/退出码/`TEAM_ALLOW_FOREIGN_IDENTITY=1` 出路逐字不变）。

### 为什么不是「cwd 能解析出项目 + 继承身份指向另一个已存在的项目」就放行（任务书给的另一个候选）

那个判据更宽，但它会把**显式继承的外来环境**也放行 —— 而 `smoke.sh` §32③/§32⑧a（`m40_foreign`）正是
这个形状，规格与门禁都要求它**拒绝**（「继承身份不许静默赢 cwd」）。宽判据等于把守卫在真实场景里关掉，
且分不清「夹具/门禁的显式继承」与「泄漏的偶然继承」。归因判据用的是**泄漏自身的指纹**（值就在 server
的全局环境里），所以夹具的显式继承（值不在全局环境里）照旧红 —— 这条在 apply 的红侧里必须有一条。

### 误判的代价与兜底（诚实边界）

- **假阴（该放行的仍被拒）**：pane 的环境是**过期副本**（全局环境在 pane 创建之后被改过 / 或 server 重启
  过）→ 归因失败 → 仍拒绝。兜底：拒绝文案里给的那条 `env -u …` 一行命令；另外 `team doctor` 的只读残留行
  会点名变量与清除命令。**代价有界**：本变更落地后泄漏不再新增，过期副本只会越来越少。
- **假阳（不该放行的被放行）**：需要「冲突的每个变量的继承值都恰好等于 server 全局环境的值」同时成立。
  夹具/门禁里那种显式 `env TEAM_ROOT=… ` 的继承不会同时出现在 server 的全局环境里（夹具用的是私有
  socket，全局环境干净）→ 不会假阳。真正的假阳形状是「调用者**故意**把 server 的全局环境设成 A 的值、
  再在 B 的目录里跑」—— 那已经是「共享 server 的残留」这件事本身，放行并说明来源是可辩护的。
- **不做的事**：不清、不重写共享 server 的全局环境（跨项目状态，属用户的管辖）；因此「同一 pane 里
  连续多条命令」都会各自打一行说明（有界、可见，不静默）。

## 3 审计面（裁定点 C）

`boundary#The gate's actions are logged…` 要求「每次过闸门的调用恰好一行」，而闸门只在调用者环境里有
`$TEAM_TMUX_CALLS_LOG` 时才写。写侧洗掉命名空间后，建对象调用就写不出那一行 → 与既有合同冲突。三条路：

- **A1（推荐）**：闸门在 pin 缺席时把日志目标解析到**它 cwd 所属项目**的 `state/tmux-calls.log`
  （向上找 `.pi/team`，几个 `[ -d ]` 测试，不启子进程；找不到项目就不写）。审计无洞；额外好处：共享
  server 上**别的项目**的 pane 里的调用记到**它自己**项目的日志，不再污染本项目的 forensics 文件。
  代价：`boundary` 一条 MODIFIED（一行措辞 + 一条场景）。
- **A2**：包装只洗身份/配置族，保留闸门四个 pin。改动最小、不动 boundary；代价是全局环境里仍留四个指向
  本项目的 pin（「本项目 `TEAM_*` 不得出现」这条断言必须**收窄**），且别的项目的 pane 会把 tmux 调用写进
  本项目的 forensics 日志。
- **A3**：接受「建对象调用不写日志」。同样要 MODIFIED（把那句「每次恰好一行」改成有例外的措辞），且是
  一个**静默的洞** —— 与「故障要可见」相抵，不推荐。

推荐 A1：它是唯一同时满足「全局环境零 `TEAM_*`」「日志恰好一行」「不引入第二份 socket 解析」的做法。
（第二份 socket 解析不可取：P188 的教训是同一份契约写两遍必然漂移，而闸门的 socket 表在 `boundary` 里
是被规格钉住的。）

## 4 门禁落点（裁定点 D）

- 新夹具 `skills/teamsmith/tests/tmux-identity-leak.sh`：**只用私有 socket 与私有 fixture 项目**
  （沿用 `tests/lib/tmux-iso.sh` 的隔离写法与 `tmux-lint.pl` 的口径：`env -u TMUX -u TMUX_PANE
  TMUX_TMPDIR=<私有>`），自带 `--all/--select`、末行 ✓/✗ 计数、以及四条红侧（见下）。
- 接入 **§32**（身份段，已有 ①–⑧）：本次修的是身份的作用域与归因，同族；且 §32 的 patterns 已含
  `scripts/team`/`cmd-agents.sh`/`cmd-watch.sh`。
- 需要动 `tests/smoke.sh`（加调用）与 `tests/section-budgets.tsv`（§32 的预算行按 apply 实测重填），并给
  §32 的 patterns 补 `skills/teamsmith/scripts/lib/common.sh`。**这三张表此刻有在飞写者**
  （P251/P261 在写、P264 排队）→ apply 交付前 `git merge main`，冲突按双方保留；若 PM 裁「不接门禁段」，
  则这份合同在增量跑里没有牙（不推荐）。
- 断言分类（供 P264 采用）：**行为类（留）** —— 全局环境的字节/键集、真 CLI 的退出码与它建出来的对象、
  真 pane 的 `/proc/<pid>/environ`、`team doctor` 的输出行；**文本类（不新增）** —— 本次不写「某句话必须
  含某个词」这类断言，说明行的判定用「点名了 server 全局环境这件事」的稳定短语即可，且**必须**配一条
  行为红侧，避免退化成纯措辞检查。

## 5 红侧（apply/verify 必须逐条跑出来）

1. **根因（写侧）**：私有 socket 无 server + 带着身份与 pin 的 shell → `team up` →
   `tmux show-environment -g` 里零个本项目 `TEAM_*`；同一 server 上项目 B 的 session 的 pane 里也没有。
   翻转：把建对象调用改回「带环境」（`SPEC_...` 旋钮或直接变异一行）→ 同一条断言必须红。
2. **自愈（读侧）**：`tmux set-environment -g TEAM_ROOT=<A> …`（A 的值）→ 在 B 的目录、带着同样继承值跑
   `team up` → rc=0、stderr 一行点名运行中 server 的全局环境、建出来的是 B 的对象、A 的 session 未被碰、
   全局环境逐字节未变。翻转：关掉归因 → 必须回到 rc=1 + `身份冲突被拒`。
3. **守卫保留**：值**不在**全局环境里的外来身份（§32③/§32⑧a 的形状）→ 照旧 rc=1、什么都不建、什么都不清；
   真嵌套（继承身份就是本项目/夹具自己的）→ 不打印说明行、不清任何变量、不写全局环境。
   翻转：把归因判据改成无条件放行 → 这两条必须红。
4. **审计（仅 A1）**：pin 缺席时，从项目目录里过闸门的一次调用 → 该项目 `state/tmux-calls.log` 恰好 +1 行、
   字段与动作词汇同 pin 调用；从非项目目录 → 哪里都不写。翻转：去掉 fallback → 第一半必须红。

## 6 落点、拆分与顺序

一个 change、**两个 apply 批次**（写侧 / 读侧），同一分支串行，因为它们都动 `common.sh` 与同一夹具：

1. **apply-1（写侧 + 审计）**：包装与建对象调用点接入（`common.sh`、`cmd-watch.sh`、`cmd-agents.sh`、
   `cmd-draft.sh`）+ A1 的日志目标 fallback（`shim/tmux`）+ 夹具的红侧 1/4 + 段 §32 接入与预算行。
2. **apply-2（读侧）**：归因判定与说明行（`common.sh`）+ `team doctor` 只读残留行（`cmd-project.sh`）
   + 夹具的红侧 2/3。
3. **verify（另一席位）**：独立克隆上逐场景重跑四条红侧（不是只跑绿侧），并自设反例（见 tasks 5.3）。

`pm-lifecycle` 的两条 ADDED 由 apply-1（第 1 条）与 apply-2（第 2 条）分别兑现；`boundary` 的 MODIFIED
由 apply-1 兑现。写集与在飞任务的串行关系见 proposal 的裁定点 D。

## Risks

- **打错 server**：夹具只允许私有 socket（`tmux-lint.pl` 与 `tests/lib/tmux-iso.sh` 两道）；任何实验前
  `tmux ls` 探活。历史事故（多次默认 server 全灭）就是这条纪律的来历。
- **闸门判定的连带影响**：洗命名空间只作用于建对象动词，kill 类不动；若 apply 顺手把 kill 类也洗了，
  §31c/§6i 的 `allowed-owned` 断言会红 —— 那正是回归保护。
- **说明行的措辞漂移**：判定用「点名运行中 server 的全局环境」的稳定短语 + 行为红侧，不锁死整段文字。
- **预算行**：§32 的 band 必须等于 apply 实测的 max(host/container/ci)，照 `section-guard.sh --budget-check`
  的规则填（作者原写「上取整」被判不符的先例已记在 §62 的预算行里）。
- **裁定点未决项**：A/B/C/D/E 五个点若 PM 有不同裁定，按裁定改写判定与场景（不是改合同方向）。
