# P154 · `safe-signal-discipline` propose：把「只杀自己记录过的 PID」变成机制

agent: dev-bob   status: done   time: 2026-10-01
branch: `task/P154-propose`   PR/MR: -（local 模式：分支留在本地工作树，未 push）
change: `safe-signal-discipline`（phase `propose`；`deltas: boundary`；起点 `main@fdbad1b8`，本 change 无其它分支来源）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/safe-signal-discipline/proposal.md` | Why / What Changes / Capabilities / Impact / What flips / Acceptance / Boundaries / Evidence（537 词） |
| `openspec/changes/safe-signal-discipline/design.md` | D1–D9：整体拒绝（含 `-x`/`-P`/`-u` 的理由）、无带内放行口令、诚实边界（`kill` 不包）、审计同族与 `.forensics`、注入点复用同一前缀（PM + worker 窗口；pulse 窗口不在内）、`team bg stop` 的 `(pid, start-time)` 身份与退出码、一个 lexer 两个 lint、三个新旋钮登记为 `refuse` 行、测试与 flip |
| `openspec/changes/safe-signal-discipline/specs/boundary/spec.md` | MODIFIED `The gate's actions are logged …`（基线 7 条 scenario 逐字保留 + 2 条新增）+ 4 条 ADDED requirement（信号闸门 / 审计与长保留 / `team bg stop` / lint 与 pid 纪律），共 25 条 scenario |
| `openspec/changes/safe-signal-discipline/tasks.md` | 依赖排序的 apply 计划：覆盖映射表、逐 requirement 复验表、路径授权（agent-owned vs PM-owned 明授）、夹具纪律（绝不给真 pkill 发信号）、6 组 21 项、两处 `--break` 红侧 |
| `docs/team/reports/P154-dev-bob/recon.sh` + `recon.log` | 现状取证：闸门目录只有 `tmux`；模式选择命中两个诱饵、也命中调用者自己的 shell；记录过的 pid 只杀一个；`team bg` 不是子命令且账本里没有 pid；tmux lint 在两条 `pkill -f` 现身前照样全绿 |
| `docs/team/reports/P154-dev-bob/proto/`（`pkill`、`gate/`、`stub`、`proto.sh`、`proto.log*`） | 提议机制的**原型**在三处可复现：拒绝（rc=64、stub 未被调用、诱饵全活、`act=refused` 落账）、红侧（`PROTO_BREAK=pass` → stub 收到 `-f <标记>`，而该模式经只读 `pgrep` 证明会选中 2 个）、`(pid, start-time)` 身份检查（匹配放行 / 陈旧指纹拒绝且进程存活） |
| `docs/team/reports/P154-dev-bob/logs/{validate,status}.txt` | 门禁与 openspec 状态的原始输出 |

提交（本地分支 `task/P154-propose`；`e767178f` 是开工后合入 `main@06293423` 的 merge，与本 change 无文件交集）：

```
8668f191  chore(P154): the prototype guards its own PATH resolution before invoking a name-selecting tool
f3a73908  docs(team): P154 report — the propose deliverable, the delta map, the 25 scenarios, the recon and the prototype
6757f0d9  docs(openspec): P154 after merging main — the gate section's number is confirmed at apply time (57 is taken)
e767178f  Merge branch 'main' into task/P154-propose
b75c9e4b  chore(P154): prototype evidence — the gate refuses a pattern kill, its break mode executes it, and the (pid, start-time) check refuses a reused pid
5f03da10  docs(openspec): P154 tasks — dependency-ordered apply plan with a coverage map, grants and the fixture matrix
aec6bb70  docs(openspec): P154 deltas — the launch prefix grows the signal family; four boundary requirements added
c126779f  docs(openspec): P154 design — nine rulings: total refusal, no escape token, the pid-recorded stop, one lexer
ec73be58  docs(openspec): P154 proposal — a recorded pid is the only identity a signal may use
b8c5ddec  chore(P154): recon of the signal surface — the gate family, pattern-vs-pid, the unrecorded bg lane
```

## Delta → requirement map

| Delta | Requirement | 覆盖它的 scenario | 由哪些 item 落地 |
|---|---|---|---|
| MODIFIED | `boundary#The gate's actions are logged, and no window carries a destructive-call grant` | 基线 7 条逐字保留 + `The rendered window carries the whole gate family` + `The window's gate resolves the name-selecting tools` | 1.3、1.4 |
| ADDED | `boundary#Signals go to a recorded pid, never to a name or a pattern` | 5 条：pattern 拒绝（诱饵活/未调用/`act=refused`）、每种选择形态拒绝、继承环境不授权、只读形态透传、`kill <pid>` 仍通 | 1.1、4.1 |
| ADDED | `boundary#The signal gate's calls are recorded, and its refusals outlive the call log's rotation` | 4 条：逐调用一行/长保留逐字节、拒绝熬过轮转、retention 失败可见不阻塞、pass 不进长保留 | 1.2、4.1 |
| ADDED | ``boundary#`team bg` stops a job by the pid it recorded, and prints what it signalled`` | 4 条：停自己那个作业（邻居活）、本会话没记录的 id 拒绝（rc=3）、pid 复用（rc=5）与畸形记录（rc=4）拒绝、已完成作业 no-op 且不追猎后代 | 2.1–2.4、4.2 |
| ADDED | `boundary#Scripts select processes by recorded pid, and the lint keeps it that way` | 3 条：真树干净 + scratch 里 `pkill -f x` 红并点名、`kill $(pgrep -f)`/绝对路径/`xargs kill` 红、pid-exact 形态干净 | 3.1–3.4、4.3 |

场景清单（25 条）：MODIFIED 9 + ADDED 5/4/4/3。每条 requirement 至少 3 条 scenario，每条都能失败（红侧见下）。

## Verification evidence（实际跑过的）

```
$ bash docs/team/reports/P154-dev-bob/recon.sh > docs/team/reports/P154-dev-bob/recon.log   # rc=0
1 · the shim directory holds exactly one gate            → shim/ 里只有 tmux；pkill/killall 解析到 /usr/bin
1c · the gate prefix the launch commands render          → export PATH=<shim>:"$PATH"; export TEAM_TMUX_CALLS_LOG=…; export TEAM_TMUX_REAL=/usr/bin/tmux
2 · pattern selection is not identity                    → pgrep -f <标记> 命中 2 个诱饵（无法区分）
2b · a pattern in the caller's own command line           → pgrep -af 命中调用者自己的 bash
2c · the safe route: the recorded pid                    → kill -TERM <pid1> 后 pid1=gone / pid2=alive
3 · the team background lane records no pid today        → team bg → rc=2 未知子命令；state/bg.log 里 pid= 行 0 条
4 · the tmux isolation lint has no opinion               → tmux-lint 真树绿；同一棵树上 smoke.sh:4141/4142 两条 pkill -f
```

```
$ bash docs/team/reports/P154-dev-bob/proto/proto.sh > proto.log       # rc=0（节选）
pkill -f <marker> → rc=64
    ✗ teamsmith pkill 闸门：已拒绝 pkill -f p154-proto-…；安全路径：team bg list / team bg stop <id> / kill <你自己记录过的 pid>
stub received the call: no (must be no)   decoys alive: alive alive
1b · 红侧：stub's record with the gate broken: -f p154-proto-…（pgrep -f 证明它会选中 2 个）
2 · 安全路径：kill -TERM <pid1> → pid1=gone pid2=alive
3 · 身份检查：(pid, start-time) 匹配 → accept；陈旧指纹 → refuse，进程仍 alive
```

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict      # rc=0（logs/validate.txt）
✓ change/safe-signal-discipline
Totals: 20 passed, 0 failed (20 items)

$ PATH="$HOME/.bun/bin:$PATH" openspec status --change safe-signal-discipline   # logs/status.txt
Progress: 4/4 artifacts complete — proposal / specs / design / tasks
```

- Verdict: propose 交付物齐全，validate 全绿，recon + 原型均为实测原始输出。
- 未做（明说）：apply 的实现、fixtures、lint、smoke 都还不存在——本任务按任务书只交提案；任务书给的验收命令只有 `openspec validate --all --strict`，全量/FAST 门禁由 apply 与复验阶段跑。

## Flip evidence（本任务按 defect-fix 口径给红侧）

本任务的红侧是**已实测的现状缺陷**，绿侧是原型的实测行为（apply 阶段必须把它做成产品行为并用 `--break` 复现）：

```
红（今天，recon/proto 实测）：pgrep -f <标记> 同时命中两个诱饵（无法用模式区分身份）；
                            调用者 shell 自己的命令行里有那个模式时，也命中调用者（2b）；
                            `team bg` rc=2、bg 账本 0 条 pid= 行（没有任何「记录过的 pid」可停作业）；
                            tmux lint 真树全绿，而 smoke.sh:4141/4142 是两条 pkill -f。
绿（原型，proto.log 实测）：同样一次 pkill -f <标记> → rc=64、stub 未被调用、两个诱饵都活着、审计行 act=refused；
                            故意破坏闸门（PROTO_BREAK=pass）→ stub 收到 -f <标记>（红侧）；恢复 → 重新拒绝；
                            kill -TERM <记录过的 pid> → 只死那一个；
                            (pid, start-time) 匹配 → 放行；陈旧指纹 → 拒绝且进程存活。
```

apply 阶段要交的红→绿（任务书已写进 acceptance）：`signal-gate.sh --break=pass` 与 `team-bg-stop.sh --break=no-identity`
必须非 0 退出（破坏实现 → 夹具变红），恢复后同一条夹具全绿。

## Honest boundaries（不在本 change 里的，明写）

- **`kill` 不被闸门包**：执行时只看到展开后的 argv，`kill $(pgrep -f x)` 与 `kill $(cat job.pid)` 同形——包它只会
  要么堵死安全路径、要么放过危险路径；脚本层由 lint 管（design D3）。
- **绝对路径与未注入闸门的 shell 绕过 shim**：`/usr/bin/pkill` 构造上拦不到，lint 负责把它报红；用户自己的终端、
  非 teamsmith 的 pi 会话、pulse 窗口（只跑 `team monitor`）都不在注入点里。
- **已完成作业的后代不追猎**：leader 退出后没有可证明的身份，`team bg stop` 只打印「不追猎」，不搜进程树/名字。
- **不追溯登记 tmux 家族的两个 launch 接缝**（`TEAM_TMUX_CALLS_LOG`/`TEAM_TMUX_REAL`）：它们早于「新旋钮必须登记」的规矩，
  本 change 只登记新增的三个（design D8），免得顺手扩范围——要不要补齐由 PM 另开任务。
- **我没跑 smoke**：本任务只改 `openspec/changes/**` 与 `docs/team/reports/**`，任务书验收命令就是 validate；
  全量门禁留给 apply 后与独立复验。（开工后合并过 main@06293423：本 change 与其无文件交集，合并后 validate 仍全绿；顺手更新了「下一段号」——57 已被 delivery-truth 占用。）

## Decisions and deviations

- **`-x` 也是拒绝**（任务书请我给判据）：精确名仍然是「按名字」，多个席位/会话跑同名二进制时一样会带走别人；`pkill -x bash`
  还会命中调用者自己的 shell。判据 = 选择集合必须能由调用者自己记录的对象枚举出来，`-x` 做不到。
- **无带内放行口令**（与 tmux 的 `--teamsmith-allow-destructive` 不同）：信号没有可命名的目标对象，口令只会把缺陷放回来；
  安全路径（记录过的 pid / `team bg stop`）永远在，`kill` 也没被包。
- **lint 与 tmux lint 同族**：抽出 `tests/lib/shell-lex.pl`（要求 `perl tmux-lint.pl --list` 前后逐字节一致作为提取的
  不变量），signal lint 复用同一词法器；`docs/team/reports/*/pkg/**` 里的历史 `pkill -f`（M35、P119 的冻结证据包）
  沿用同族的 sha256 冻结豁免，`tests/**` 不许豁免——M25 夹具那两行要真修（改按记录过的 pid）。
- **三个新旋钮登记成 `refuse` 行**（`TEAM_SIGNAL_CALLS_LOG`、`TEAM_SIGNAL_REAL`、`TEAM_BG_STOP_GRACE`）+ zh/en 标签 +
  `references/config.md` 行：这是 P141 复验 R1 立下的规矩，本 change 主动遵守。
- 任务书 `anchor: change` / `specs: boundary` / `deltas: boundary` 全部对齐：本 change 只写 `specs/boundary/spec.md` 一个 delta。

## Suggested next steps

- 请 PM 复审提案（`docs/team/reviews/safe-signal-discipline-proposal.md`）；通过后按 tasks.md 派 **apply（换人）**，
  再由**第三个** agent 跑 verify，最后 PM archive（archive 前需要用户确认）。
- apply 需要的 PM-owned 授权 hunk（tasks.md 已列）：`scripts/shim/{signal-gate,pkill,killall}`、
  `scripts/lib/{common,cmd-bg,cmd-config,cmd-project}.sh`、`scripts/team`、`extension/team-bg.ts`、`SKILL.md`、
  `references/{protocol,config,troubleshooting}.md`、`scripts/panel/src/strings/{zh,en}.ts` 与重建的 bundle。
- 两个可选项留给你裁：pulse 窗口要不要也带闸门家族；tmux 家族的两个接缝要不要补登记（design 的 Open Questions）。
