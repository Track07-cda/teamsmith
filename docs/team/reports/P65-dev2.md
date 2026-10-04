# P65 · agent-pane-survivability 独立验证（verify 阶段）

agent: dev2   status: PASS（六条对抗判据全部通过；门禁红两条已点名，见「发现与归属」）   time: 2026-09-22T17:2xZ
branch: `task/P65-agent-pane`（local 模式：不 push，分支留在 `.worktrees/dev2`）
change: `agent-pane-survivability`（propose=P49 · apply=P55/dev · verify=P65/dev2）

## 交付物

| Path | What |
|---|---|
| `docs/team/reports/P65-dev2/pkg/run.sh` | **独立验证包入口**（不复用实现夹具；六节 + 变异腿；exit 0 = 全绿） |
| `docs/team/reports/P65-dev2/pkg/lib.sh` | 私有 tmux socket + PATH shim + 私有 TMUXDIR + 夹具仓库/会话（`p65*-$$`）；EXIT trap 只在主进程清理 |
| `docs/team/reports/P65-dev2/pkg/10-timing.sh` | §10 remain-on-exit 的时机（harness 秒退） |
| `docs/team/reports/P65-dev2/pkg/20-corpse.sh` | §20 遗体可读 + `-S -` 必要性（滚出可见屏的行） |
| `docs/team/reports/P65-dev2/pkg/30-delivery.sh` | §30 死 pane 不是投递目标 + 复用 ×3 + 顺序证据 + teardown |
| `docs/team/reports/P65-dev2/pkg/40-states.sh` | §40 四态/机器面/现场来源/doctor·digest/噪音判据/只读 |
| `docs/team/reports/P65-dev2/pkg/50-bounds.sh` | §50 有界保留/knob/history-limit/无定时器 |
| `docs/team/reports/P65-dev2/pkg/60-mutations.sh` | §60 四条变异腿（在 /tmp 副本上，本 worktree 零改动） |
| `docs/team/reports/P65-dev2/logs/*.log` | 每节与每条变异腿的原始输出（本节所有引用都指向它们） |

## 独立验证包（怎么跑、结果）

```sh
$ bash docs/team/reports/P65-dev2/pkg/run.sh          # 约 2 分钟
############ 汇总 ############
10-timing        == 10-timing 结果 == ok=13 bad=0 finding=0 skip=0
20-corpse        == 20-corpse 结果 == ok=22 bad=0 finding=0 skip=0
30-delivery      == 30-delivery 结果 == ok=70 bad=0 finding=0 skip=0
40-states        == 40-states 结果 == ok=65 bad=0 finding=1 skip=0
50-bounds        == 50-bounds 结果 == ok=17 bad=0 finding=0 skip=0
60-mutations     == 60-mutations 结果 == ok=6 bad=0 finding=0 skip=0
（exit 0；全量日志见 logs/ 与 `team_bg_wait p65-package3` 的作业日志）
```

隔离口径：包内所有 tmux 调用（含被测工具内部的调用）都经 PATH shim 钉到
`-L p65pkg-$$` + 自建 `TMUX_TMPDIR`（`-L` 优先于 TMUX 环境变量，本轮实测过）；夹具仓库/会话名带
`$$`；顶层 `unset TMUX/TMUX_PANE` 且清空继承的 `TEAM_*`。全程没有一次落到默认 server 或真实 session。

## 一、逐条对抗（对照 brief 的六项）

### 1. `remain-on-exit` 的时机（`[10-*]`，logs/10-timing.log）

假 agent 打印一行后 `kill -9 "$PPID"`，**harness 与 pane 同秒死亡**；它同时还从 pane 内部读了选项：

```sh
$ tmux list-panes -t <sess>:p65t -F '#{pane_dead}|#{pane_dead_status}|#{pane_dead_signal}|#{pane_dead_time}'
1||9|1790096297
$ tmux capture-pane -p -S - -t <sess>:p65t | head -4
teamsmith agent:p65t → T9.65t
P65-t1-MARK-SUICIDE
OPTION-INSIDE=on          ← 从 pane 内部读到的 remain-on-exit
```

- `[10-A4]` 死后恰好一个窗口；`[10-A5]` 读回 `on`；`[10-A6]` `pane_dead=1`；`[10-A7]` `signal=9`；
  `[10-A8]` 从 pane 内部读到 `on`（= 选项先于 harness，不是死后补设）；`[10-A9]` 遗体画面含最后输出。
- `[10-A10]` PM 窗口无窗口级 `remain-on-exit`（D2）；`[10-A11]` 全树只有 agent 建窗点与既有 draft 窗设它
  （`cmd-draft.sh:62` 既有 + `cmd-agents.sh:902` 新增）；`[10-A12]` `kill-window` 仍能拆遗体。
- 红侧见 §变异 m1：删掉「设选项 + 读回」两步 → `[10-A5]` 红（窗口消失、读回为空）。

### 2. 遗体可读且证据在（`[20-*]`，logs/20-corpse.log）

fixture 先打 `c1-MARK-SCROLLED`、再打 30 行 filler、最后 `c1-MARK-LAST`（可见屏 24 行 → 首行必然滚出）：

```sh
# 可见屏 capture（不带 -S）读不到滚出的首行；带 -S - 读得到
[20-B8] 可见屏 capture（不带 -S）读不到滚出屏的首行 marker —— -S - 的必要性成立   ok
[20-B9] capture-pane -S - 读到滚出可见屏的行                                    ok
[20-B10] capture-pane -S - 读到最后一行                                          ok
# team status 的现场块（TEAM_AGENT_SCENE_LINES=40）也含滚出可见屏的 marker
[20-B18] status 现场块包含滚出可见屏的 marker（它读 scrollback）                  ok
```
- 另有 `pane_dead=1` / `signal=9` / `pane_dead_time` 可读、`kill-window` 仍可拆、现场读取器源码确实用
  `capture-pane -p -S -` 且显式丢弃 tmux 的 `Pane is dead (` 通知行（`[20-B11]`/`[20-B12]`）。

### 3. 死 pane 不是活座位（`[30-*]`，logs/30-delivery.log）

- **say**：`[30-C4]` rc=0；`[30-C5/5b/5c]` 输出不含「已确认送达 / said to / 已送达」；`[30-C6/7]` 点名
  `pane 已死` + `signal=9`；`[30-C8]` 消息新增进 `docs/team/inbox/p65d.md`；`[30-C9]` 遗体画面 sha256
  前后一致（`4095e61…`）。
- **notify**：`[30-C10..C12]` 消息落收件箱、遗体仍逐字节不变（敲门目标不是该席位）。
- **复用 ×3**（dispatch / `--fresh` / resume）：`[30-D2/3/4-*]` 每轮都断言
  `state/dispatch-p65d-pane-dead.txt` 存在且带 `seat/window/captured/exit: signal=9/dead_time` + 恰好 3 行
  现场（含**上一轮** marker、不含新一轮 marker），输出写「上一个 pane 已死（signal=9）」而不是「打断」，
  新一轮启动证明照常、恰好一个窗口、新窗口 `remain-on-exit` 仍 `on`。
- **顺序证据**（shim 调用日志，先抓后换）：

```text
[30-D2-order] capture-pane 调用（行 71）先于 new-window（行 74）：先抓现场再替换
[30-D3-order] capture-pane 调用（行 138）先于 new-window（行 141）
[30-D4-order] capture-pane 调用（行 207）先于 new-window（行 210）
```
- **teardown**：`[30-E1..E4]` 拆掉遗体后 roster 报「无窗口」、行内不再有 ▲。

### 4. 四态与机器面（`[40-*]`，logs/40-states.log）

五个现场一次成像（`p65live` 在跑 / `p65short` 正常退出 / `p65dead` 遗体 signal=9 /
`p65absent` 无窗口 / `p65code` 退出码 7 的遗体 / `p65outside` 同 binary 但 cwd 不在项目）：

```text
p65live    ● p65-live-live 在跑 …          ← [40-G2]
p65short   ○ p65-live-live 已退出 …        ← [40-G3]
p65dead    ▲ 已死 signal=9 …               ← [40-G4]
p65absent  · 无窗口 …                      ← [40-G5]
p65outside ○ p65-live-live 已退出 …        ← [40-G6] 证明规则不变：同 binary 但 cwd 不在项目 → 不 running
p65code    ▲ 已死 status=7 …               ← [40-G4b] 退出码形态的证据
```

- 机器面：`agents` 块的 `state` 词表仍 `running/exited/absent`，新增 `pane`/`pane_exit`；尸体是
  `exited + pane=dead + pane_exit=signal=9`，无窗口席位没有 `pane` 键；`team monitor --json` 的
  `panel.agents` 与 `__panel-data` 一致（`[40-H1/H3]`）。
- `team status <ID>`：死席位印状况 + `signal=9` + 来源 + 记录时间 + `TEAM_AGENT_SCENE_LINES=2` 恰好两行
  （`[40-I2..I8]`）；活席位无记录不印现场块（`[40-I11]`）；第三层来源（harness tail）按序回退（`[40-I14/I15]`）；
  退出码遗体印 `status=7`（`[40-I12]`）。
- `doctor` 一条告警（点名 + `signal=9` + `team status <ID>`）且退出码不受影响（`[40-J4/J5/J6/J10]`）；
  全活时不吭声（`[40-J7]`）；`digest` 点名未结束任务的遗体（`[40-J1..J3]`）；`pending.stopped` 计入它
  （`[40-J8]`）而不计活席位（`[40-J9]`）。
- **噪音判据**：`close --keep-window` 后 digest 改口「无登记任务」、doctor 不吭声、`stopped=0`、roster 仍
  如实 ▲（`[40-L1..L7]`）；teardown 后回「无窗口」（`[40-L8..L10]`）。
- **只读**：`roster/status/digest/doctor/__panel-data` 读完 `.pi/team/state/` 指纹（内容 + mtime + 大小）
  逐字节不变（`[40-K1]`）。
- 静态：`common.sh`（`team_agent_live` 等 M6.5 证明规则）在本 change 里**零 diff**（`[40-M1]`）。

### 5. 有界保留（`[50-*]`，logs/50-bounds.log）

- 默认 → 现场恰好 40 行且含最后一轮 marker、更早的滚出行被截掉（`[50-N5..N7]`）；
  `TEAM_AGENT_SCENE_LINES=abc` → 回落 40（`[50-N9]`）；`=3` → status 恰好 3 行（`[50-N11]`）。
- `history-limit` 全局值不变（100000）且没有窗口级设置（`[50-O1/O2]`）；新增行零定时器/常驻结构、零新增
  脚本文件、零后台化命令（`[50-O3..O5]`）。
- 每席位至多一具遗体：三轮回用后始终恰好一个窗口（§30 `[30-D*-win]`）。

### 6. 零回归

- `openspec validate --all --strict`：**26 passed / 0 failed**（见下「门禁」）。
- FAST + 全量 smoke：见「门禁」节；红项逐条点名并与本 change 的关系分开。

## 二、翻转证据（红 → 绿原始输出）

四条变异全部在 `/tmp` 的 `git archive HEAD` 副本上做（本 worktree 的 `skills/` 零改动，
`[60-R1]` 复核 `git status --porcelain -- skills/` 为空）。每条腿先跑干净副本（绿）再跑变异副本（红）：

| 变异 | 锚点 | 绿侧（干净副本） | 红侧（变异副本） |
|---|---|---|---|
| m1 删掉「设 remain-on-exit + 读回」 | `[10-A5]` | `ok: [10-A5] 死后窗口的 remain-on-exit 读回是 on` | `bad: [10-A5] …（实际 '' 期望 on）` |
| m2 删掉 say 对死 pane 的换道 | `[30-C6]` | `ok: [30-C6] 输出点名座位已死` | `bad: [30-C6] …（pane 已死 不在 say.log）` |
| m3 roster 把遗体显示成「在跑」 | `[40-G4]` | `ok: [40-G4] roster ③ dead（行内带 signal=9）` | `bad: [40-G4] roster p65dead 不是 ▲ 已死 signal=9` |
| m4 复用前不抓现场 | `[30-D2-file]` | `ok: [30-D2-file] 现场文件存在：…` | `bad: [30-D2-file] 现场文件不存在：…` |

红侧各腿的其它红行原样保存在 `logs/mut-m*-red.log`（m1 `ok=6 bad=7`、m2 `ok=62 bad=2`、
m3 `ok=52 bad=3`、m4 `ok=40 bad=6`），绿侧为 `logs/mut-m*-green.log`。`== 60-mutations 结果 ==
ok=6 bad=0 finding=0`。

「还原后干净」用变异副本之外的证据陈述：变异只写 `/tmp/p65-mut.*`，`[60-R1]` 断言
`git -C <worktree> status --porcelain -- skills/` 为空。

## 三、发现与归属

- **F1（finding，非阻断）**：`team status` 的第三层来源（`state/dispatch-<agent>-tail.txt`）在
  `TEAM_AGENT_SCENE_LINES=3` 时会打「来源在但没有画面内容」——tmux 的 capture 末尾是成片空行，
  读者按字面取「最后 N 行」就只剩空行；默认 40 不受影响。delta 的 scenario 钉的是死 pane 现场，
  未钉这个形态（`[40-I16]`）。建议归入后续（比如读取器对 tail 来源也做一次尾空行裁剪），不阻断本 change。
- **F2（本 change 自己的夹具踩中同级 lint，建议跟 P64 或单开小修）**：`tmp-hygiene.sh --lint` 在本树
  报 **8 条**，其中 2 条是已知的 P64（`container-tmux.sh:159/:215`），另外 **6 条在
  `tests/fixtures/p55/flip-p49.sh`**（`:29` 的 `p55-flip-sock` 不在 owned 家族，`:37/:173/:195/:203/:211`
  写死 `/tmp/p55-flip-*`）。P55 的翻转夹具是在 P53 的 lint 落地前写的、合并后一起进 main，
  交付报告与合并后复验只点了 container-tmux 那条（lint 的 bad 行只打印前 3 条 finding）。
  它不影响行为面（§60 的变异全部通过），但它是本 change 的 artifact 让当前门禁变红。
- **F3（外部并发干扰，非本 change 归属）**：FAST 跑的 `12b-j 隔离` 红（本轮 `✓2393 ✗2` 的第二条）
  起因是 **dev3 的 P67 fake-tui 夹具**在 17:10:34/17:10:38 把带夹具 payload 的 tmux 调用写进了
  真实主工作树的 `.pi/team/state/tmux-calls.log`（命中文本`半句草稿 half a sentence`，行内
  `cwd=…/.worktrees/dev3`、socket 是它的私有 tmp 目录）。我给 PM 的一条通知里会点名这件事。
- **P64 已知红**：`container-tmux.sh` 的 fpcheck 临时根（2 条 finding），按 brief 不计为本 change 回归。

## 四、门禁（交付时刻，分支 tip）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 26 passed, 0 failed (26 items)                       # rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2393  ✗ 2
✗ 40 lint 有 finding（rc=1）：…/container-tmux.sh:159 … :215 … fixtures/p55/flip-p49.sh:29 …
✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（期望 [none]，实际 […/pm-skills/.pi/team/state/tmux-calls.log]）
（两条红的原始上下文见 logs/gate-smoke-fast.log）

$ bash skills/teamsmith/tests/smoke.sh </dev/null            # 全量（见 logs/gate-smoke-full.log）
<<FULL_GATE_TAIL>>
```

## 五、决策与偏差

- brief 要求的六条我全部按「自己造现场 + 可复现命令 + 原始输出」执行；没有复用 P55 的
  `tests/fixtures/p55/flip-p49.sh` 或 smoke §41 的断言（本包是独立夹具、独立断言、独立会话）。
- brief 说「去掉设完读回」的红侧：我用的是「删掉 set+readback 两步、保留占位/respawn」的变异（m1），
  比换回旧的一行 `new-window` 更贴 brief 的措辞。
- 额外补了 brief 未点名但 delta 写了的两个形态：`pane_exit=status=7`（退出码证据）与
  `notify` 对死席位的换道（[30-C10..C12]）；以及一条「同 binary 但 cwd 不在项目 → 不 running」的
  证明规则对抗（[40-G6]）。
- 本任务只写 `docs/team/reports/P65-dev2/**`；没有改 `skills/**`（变异全在 /tmp 副本）。local 模式不 push。

## 六、建议下一步（给 PM）

1. 跑 `team review P65`（独立 checkout + 门禁）时，把 F2 的 6 条 lint 一并记进记录：要么并入 P64 的范围，
   要么开一条 `Pxx: p55 夹具临时根进 owned 家族` 的小修；本 change 的行为面不需要返工。
2. F3 属于 dev3/P67 的夹具泄漏（真实 `tmux-calls.log` 被写脏），跨 agent，请 PM 转达或并入 P67 的门禁口径。
3. F1 可留作后续改进，不阻断 archive。
