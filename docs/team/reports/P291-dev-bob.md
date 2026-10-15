# P291 · 给工具加一条「打断席位长回合」的正式入口（propose）

agent: dev-bob   status: DONE   time: 2026-10-15T23:37:00Z
branch: `task/P291-seat-interrupt-entry`   PR/MR: -（本仓 local 模式，分支留本地待 PM 复验）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/seat-interrupt-entry/proposal.md` | 提案：机制缺口 + 现状复核（只读实测）+ What Changes + 能力落点（`boundary` 两条 ADDED，不新开能力）+ Impact（含 apply 的写面） |
| `openspec/changes/seat-interrupt-entry/specs/boundary/spec.md` | 合同：① 入口/计划态/对象证明链/发信号前复验/信号与审计行/拒绝集合/读命令不打断；② 理由必填与投递（thread 是阅读顺序第二步）+ 新鲜窗口与 `--force` + 工作树与会话文件逐字节幸存 |
| `openspec/changes/seat-interrupt-entry/design.md` | 推理：三条事实基础、与 `long-job-suspend` 的边界、机制选择与被否掉的四个备选、对象证明链、判据两侧与代价、审计行形状（与 `reap` 的差异）、明说的边界（工具子进程/窗口不是遗体/后台作业/死因词表）、能力落点与任务切分、Non-Goals |
| `openspec/changes/seat-interrupt-entry/tasks.md` | 规格 ↔ 任务对照（两向闭合）、§0 提案（已勾，逐条带证据指针）、§1–§3 apply 任务（含红侧方向）、§4 独立验证、§5 验收命令 |

## Verification evidence (must have actually been run)

### 1. 本阶段验收四条（任务书原文，逐条真跑）

```console
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/writing-discipline
Totals: 23 passed, 0 failed (23 items)          # 基线 22/0，本 change 落地后 23/0（rc=0）

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 12357 effective line(s); retired 0; undeclared 0;
  id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]        # rc=0（未新增任何引用，也没有退场）

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/…/.worktrees/dev-bob scope=published files=1632 hits=0 names=ok user=resolved
$ echo $?
0
# 这一行是**含本报告**那棵树上的读数（再跑一次 files 从 1631 变 1632，hits 仍为 0）

$ git diff --check && git status --short
（无输出；rc=0 —— 本分支只新增 openspec/changes/seat-interrupt-entry/，工作树干净）
```

### 2. 归档投影自证（deltas 真的能并进基线，零丢失）

```console
$ cp -r openspec /tmp/p291-trial/openspec && (cd /tmp/p291-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y seat-interrupt-entry)
Applying changes to openspec/specs/boundary/spec.md:
  + 2 added
Totals: + 2, ~ 0, - 0, → 0
Specs updated successfully.
Change 'seat-interrupt-entry' archived as '2026-10-15-seat-interrupt-entry'.

$ 计数（基线 → 归档投影）
boundary requirements: 15 -> 17
boundary scenarios:    70 -> 79          # +9 = delta 自己的 9 个场景，一个不多一个不少
$ grep -n '^### Requirement: A running seat\|^### Requirement: An interrupt carries' /tmp/p291-trial/openspec/specs/boundary/spec.md
848:### Requirement: A running seat's turn is ended only by an audited interrupt aimed at that seat's own process
927:### Requirement: An interrupt carries its reason to the seat, and a seat that is writing is not interrupted by accident
$ bash skills/teamsmith/tests/spec-refs.sh --check --root /tmp/p291-trial
spec-refs: judged 111 reference(s) … retired 0; undeclared 0 …      # rc=0（归档投影里也干净）
```

两条都是 **ADDED**（`~ 0, - 0`）：既有 15 条要求一条没被改写、70 个场景一个没丢——本变更不与任何既有合同冲突，
也没有平行陈述。

### 3. 提案承诺的验收命令：今天存在吗（PM 的 spot-check 那一半）

| tasks.md §5 里的命令 | 今天 |
|---|---|
| `bash skills/teamsmith/tests/interrupt.sh …` | **不存在**（apply 新建；`MISSING` 是预期） |
| `… tests/help-surface.sh --select coverage` | 存在，今天跑：`✓ 15 ✗ 0 SKIP 0`，`45 个命令`（apply 后应为 46） |
| `… tests/config-cli.sh` | 存在（completeness 双向走查；本变更不新增契约键） |
| `perl … tests/signal-lint.pl --legacy /dev/null` | 存在，今天跑：`干净（扫描 114 个脚本；pid 精确形态全部干净）` rc=0 |
| `… tests/section-select.sh --check` | 存在，今天跑：`== 选段自检 ==  ok 8  bad 0  SKIP 1` rc=0 |
| `… tests/smoke.sh --select 51c,51,51b,33,37` | `smoke.sh` 存在；`51c` 是 apply 要新建的段（id 定 `51c`，撞号时以落地的 id 为准并在报告里写明） |
| `… tests/spec-refs.sh --check`、`openspec validate --all --strict`、`… ledger-ban.sh` | 存在，见 §1 |
| `git diff --check && git status --short` | 见 §1 |

### 4. 事实基础（propose 期间只读实测，数字是读数不是回忆）

```console
$ awk -F'\t' '$1=="cmd"' skills/teamsmith/scripts/strings/commands.tsv | wc -l
45                                     # 45 条命令里没有一条能结束一个正在跑的回合
$ grep -n "reap)\|resume)\|teardown)" skills/teamsmith/scripts/team
100:  reap)       team_cmd_reap "$@" ;;        # 孤儿席位的 pid（boundary 已有合同）
119:  teardown)   team_cmd_teardown "$@" ;;
121:  resume)     team_cmd_resume "$@" ;;       # 给**停了**的席位

# 长回合：窗口在跑，会话文件不动（2026-10-15T23:36:34Z 读数）
$ tmux capture-pane -p -t teamsmith:dev -S -6 | grep -E 'Elapsed|Working'
 Elapsed 57m 2s
── ⠼ Working ──…
$ stat -c '%s bytes mtime=%y' <dev 那次会话的会话文件>
2112882 bytes mtime=2026-10-15 22:39:31        # age=3423s
# 同一份读数的两次采样（23:32:39Z 与 20 秒后）：bytes 都是 2112882，mtime 不变

# 同一会话 id 跨进程死亡继续追加（这是 resume 路线今天已经在跑的机制）
$ grep -m1 '^started=\|^mode=' .pi/team/state/dev.env
started=2026-10-15T22:38:58Z
mode=continued                                # sid 指向的那份会话文件是 03:36 创建的
```

只读盘点里确认「要用的机器都在」：`cmd-reap.sh` 的「按 pid + 发信号前复验（本项目身份 + 启动时刻一致）+
`SIGTERM`→有界 5s→`SIGKILL` + `state/reap.log` 一行」、`common.sh` 的 `team_orphan_*` 身份判据（进程**自己**的
`environ`）、pane 侧的 `team_pane_agent_pid`、`team_inbox_append` 与 thread 写入器、`team_guard_resume_session`，
以及 `config-cli.sh` 的 completeness 方向（`references/config.md` 里出现的 `` `TEAM_*` `` 必须在 schema 里 —— 所以
新鲜窗口作为**实现接缝**留在实现里，不进文档就不必登记，`TEAM_REAP_GRACE_SEC` 是同族先例）。

### 5. 未跑的东西（明说）

- **没有在真席位上执行过任何打断**：propose 阶段只读；`dev` 那个 57 分钟的长回合我没有碰（工具本身在 apply 之后
  才有），所以「打断一个真席位后 resume 回到同一会话」这条**端到端**证据还没有——它的两个前提今天各自有读数
  （§4 的会话跨进程继续 + `state/dev.env` 的 `mode=continued`），完整的端到端由 apply 的夹具与 verify 去证。
- **没有跑门禁**：apply 才落代码与夹具，smoke/夹具的验收命令今天没有对象可跑（能跑的 spot-check 见 §3）。
- **没有验证 Pi 在 `SIGTERM` 下的收尾行为**（工具子进程是否随之退出、TUI 屏幕留在哪一屏）：设计里把它写成明说的
  边界（design §8 的第一条），夹具只断言**我们发过的那个对象**恰好一个 pid 且它确实退出。

## Flip evidence (required for defect-fix tasks)

不适用：本任务是 **propose**（只写提案，不改产品代码、不含缺陷修复），没有「红前 → 绿后」的实现可证。可证伪的
那一半写在 `tasks.md` 的红侧条目里（1.2 换掉身份判据 → 必红；1.3 拆掉发信号前复验 → TOCTOU 必红；2.3 让 `--force`
越过身份拒绝 → 必红；2.6 夹具变异臂），由 apply 的夹具落地、由**另一个席位**的 verify 逐条重做。

## Decisions and deviations

- **命令名 `interrupt`**：任务书把起名权给了我；账本 D188 里登记的候选名就是 `team interrupt <seat>`，用它正好让
  那条手工动作的退役条件可判。
- **两级授权：`--reason` 必填 + `--yes` 才执行**（任务书只要求理由必填）。`--yes` 不是我加的花样：`reap` 已经是
  本项目唯一另一条会发信号的入口，它的合同写着「`--yes` 是唯一授权，配置键/环境变量/继承值都不能让信号默认开」，
  而任务书的判据要求「不是静默杀进程」。计划态（无 `--yes`）把「看清对象与证据」落成了一个可以复跑的输出。若 PM
  认为两次授权是多余的摩擦，这是改判据而不是改实现——请在提案复核里点名。
- **新鲜窗口默认 3600 秒**：两侧代价不对称（假阳 = PM 多打一个 `--force` 与一行越权审计；假阴 = 丢掉席位没提交的
  活），D188 的症状（16/18 小时）离 1 小时很远，而正在写盘/跑长门禁的席位通常在窗口内。窗口可用
  `TEAM_INTERRUPT_FRESH_SEC` 调；**没有**「关掉它」的开关（`--force` 就是那条路，而且它会留痕）。
- **不新增契约键**：窗口与有界 5 秒都按 `TEAM_REAP_GRACE_SEC` 的先例留在实现里，默认值与行为写进命令页与规格文本；
  因此本变更不动 `cmd-config.sh` 的 schema、不动面板数据面与 `panel.js` 重建产物。
- **一个 apply 任务**：单写者守卫按「同一能力同一份 delta 文件」判，本变更只落 `boundary` 一份 delta，两个 apply
  任务会互相挡；能用一个工作块做完的依据是机器都已存在（design §7）。
- **任务书没要求、我加进来的**：计划态（无 `--yes` 的打印）、拒绝集合各自给出路、审计行里的 `guard=forced` 与
  `signal=`、命令打印回去的路线、以及「读命令永不打断」那条场景。它们都在「可观测 + 不静默 + 对象是证明过的」这三
  条判据里面，不是新功能；写不进去请按越界打回。
- **写集串行（给 PM 的提醒）**：apply 要动 `tests/smoke.sh` 与 `tests/section-*.tsv`，此刻 `gate-lock-hygiene`
  （未归档）也在动同一批。apply 交付前 `git merge main`，冲突按两侧保留，语义冲突停下报 PM（已写进 `tasks.md`
  §2.6 与 design §7）。

## Suggested next steps

- **PM 的提案复核**：`docs/team/reviews/seat-interrupt-entry-proposal.md`（ACCEPTED 之后才可派 apply）。复核时值得
  逐条看的四点：① `--yes` 两级授权是否保留；② 新鲜窗口的默认 3600 秒与「证据 = 会话文件 ∪ git 报为改动的文件」；
  ③ 拒绝集合（停/孤儿/名册/跨项目/自身）与各自的路；④ 审计行字段（谁/何时/哪个席位/pid/理由/打断前会话最后落盘
  时间/未提交数/越权标记/信号/结果）。
- **apply 的 grant**：写面见 `proposal.md` 的 Impact 末条（新增 `cmd-interrupt.sh`/`tests/interrupt.sh`；改
  `scripts/team`、`scripts/strings/*`、`tests/smoke.sh`、`tests/section-*.tsv`、`tests/help-surface.sh`、
  `references/{troubleshooting,protocol}.md`）；产品面既有语义文件不在写面里。
- **verify 必须是别的席位**：我写了这份提案，所以本 change 的 apply 与 verify 都不能派给 dev-bob。
- 本分支留本地（local 模式，未推送）：`task/P291-seat-interrupt-entry` tip 见提交列表；`docs/team/tasks/P291-*.md`
  是 PM 的只读文件，我一字未动。
