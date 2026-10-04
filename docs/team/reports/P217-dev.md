# P217 · P210 的判据与 §41 的夹具互相矛盾：裁定 A（判据补准到 argv[1]）+ 夹具对齐生产形状

agent: dev   status: done   time: 2026-10-04T20:58Z
branch: `task/P217-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
tip: `dba16cc2`（**被门禁与翻转包验证的代码+夹具 tip**；本报告提交在其后，`docs/team/reports/**` 不进门禁判据）
container: `localhost/teamsmith-gate:local`（`HOME=/tmp`、`--pid=host`、`--userns=keep-id`，与 CI 同一枚镜像）
evidence: `docs/team/reports/P217-dev/`（按 `.gitignore` 的 `docs/team/reports/**` 只在工作树里，不进仓库：
`/home/yikdata/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev/docs/team/reports/P217-dev/`）

```
task:   P217
agent:  dev
issue:  -
change: -
specs:  -
phase:  apply
anchor: none (infra) — 修判据或夹具，二选一但必须说清理由
deltas: -
```

**哪些是我自己跑的、哪些是引用 P214 的**：本报告里所有读数都是我自己在容器里重跑的（四形状探针是我自己写的夹具；
P214 的 `probe-p55-shapes.out` 只用来对照，没有当下结论）。**唯一引用** P214 的地方是它的诊断分类（20 条红里
§41 那两条是真缺陷）与"夹具改成生产形状后 §41 全绿"这一条（V3，见第五节），两者都标了出处。

## 一、裁定：A（判据补准 + 夹具对齐生产形状），理由

两个候选都能让 §41 变绿，我选 A：

1. **§41 的断言是对的，判据是错的那一边。** 夹具说"pane 命令就是 agent 脚本、agent 在跑 → running"，
   而那个形状里 agent 确实在跑（`bash <agent>` 的语义就是"跑这个脚本"）。判据（P210 的第二道）把
   "**在执行** agent"和"**只是提到** agent"一起否掉了，这是一个假阴性。
2. **假阴性的代价是反方向的**，而且比假活更贵：读数 exited 之后，`team resume` 的下一步就是
   `respawn-pane -k` —— 那个动作会**杀掉一个正在干活的 agent**。P210 堵的 P103 是"漏掉一个已死的席位"，
   这一条是"杀掉一个活着的席位"，两个方向的错都必须堵。
3. **两种形状的 argv 有唯一稳定的分界**（P214 指出、我自己的探针复核）：`bash <agent>` 的 argv[1] 就是
   agent；P103 的 `bash --noprofile --norc -s <agent>` 的 argv[1] 是选项。按 argv[1] 逐词相等来判，
   既不误杀，也不会把"提到的"算成"在跑的"（洞照旧堵着，见第五节的红侧）。
4. **夹具仍要对齐生产**：dispatch 是 `respawn-pane … bash -lc <harness>`，harness 在 agent 前后都有语句、
   末尾 `exec bash`（`scripts/lib/cmd-agents.sh:1289` 的 inner、`:1299` 的 respawn），所以**生产里 agent 永远是
   pane shell 的直接子进程**。§41 测的是"派单留存"的语义，夹具停在"人工直起脚本"的形状上，
   会让"agent 不再是子进程"这类回归无声通过。

**为什么不选 B**（只改夹具）：假阴性留在产品里 —— 人工在座位窗口里直接起一个脚本型 agent（P214 实测：
生产不会自动出现，但这是人工恢复/手工起车的形状）会被读成"已退出"，下一个巡检/续跑就把人杀了；
而且 B 的交付物只有一行测试改动，判据的根因一个字没修。

## 二、复现：四种启动形状（**自写夹具**，容器内，两种树）

夹具：`docs/team/reports/P217-dev/probe-p217-shapes.sh`（私有 tmux server + 私有 `TMUX_TMPDIR`；一个假 agent
`#!/usr/bin/env bash` + `sleep 300`；六个窗口）。两种树：**pre = P217 之前**（`git archive 453d46e9` 解出来的树）、
**post = 本 worktree**。判据入口用生产同一条路（`team_load_config` + `team_agent_live`）。

```
形状 pane_pid 的 argv                          直接子进程            前台     pre       post
s1    bash /tmp/…/fake-bin/p217-agent          sleep 300             bash     stopped   alive
s2    bash /tmp/…/fake-bin/p217-agent          sleep 300             bash     stopped   alive
s3    bash -lc /tmp/…/p217-agent & wait        bash /tmp/…/p217-agent  bash   alive     alive
s4    bash -lc /tmp/…/p217-agent; :            bash /tmp/…/p217-agent  bash   alive     alive
sn1   bash --noprofile --norc -s /tmp/…/agent  （无）                 bash     stopped   stopped
sn2   bash -c sleep 600 && true                sleep 600             bash     stopped   stopped
```

（`docs/team/reports/P217-dev/evidence/probe-p217-shapes.out`，probe rc=0；六个形状各一条断言，post 树全过。
`pane_pid 的 argv` 是 `ps -o args= -ww` 的原样输出，窗口名见脚本里的 `s1…sn2`。）

与 P214 的对照：**s1/s2 逐项相同**（bash 对 `-c` 的最后一条命令直接 `exec`，所以"外套一层 `bash -lc <agent>`"
一点用都没有）—— 这一点我先按 P214 的说法写夹具，再自己量了一遍，读数一致；s1 与 s2 的进程形状与 P214 的
①/② 一致，s3/s4 与 ③/④ 一致。

## 三、改了什么

| 路径 | 改动 | 量 |
|---|---|---|
| `skills/teamsmith/scripts/lib/common.sh` | 新增 `team_proc_executing_bin <pid> <bin>`（argv[1] 的 basename 等于配置的 agent；保留 `pm.pid.spawn`/`dispatch-*.spawn` 两道排除）；`team_agent_alive_in_pane` 的"前台是裸 shell"那一支改成两步走：pane_pid 在执行 agent → 用它；否则退回"只看直接子进程" | +49 −5 行 |
| `skills/teamsmith/tests/smoke.sh` §41 | `p55live` 的启动形状改成生产形状：`bash -lc "$FAKE/p55-agent; :"`（agent 是 pane shell 的直接子进程），附注释说明"套一层 `bash -lc <agent>` 无效" | 1 行 + 4 行注释 |
| `skills/teamsmith/tests/smoke.sh` §6k | 新增 ⑧：pane 命令 = agent 脚本本身 → 判活（并钉住"没有 agent 子进程"这个前提 + `resume --dry-run` 不列它）；⑥（P103 的 `-s <agent>` 判停）原样保留 | 26 行 + 1 行改动 |
| `skills/teamsmith/tests/flip-p217.sh` | 新的独立验证包：六形状 × 三棵树（pre / green / mut），逐条断言 + CLI 层 + 影子；自带"修复前 revision"定位 | 288 行（新文件） |
| `skills/teamsmith/tests/loop-inventory.tsv` | 登记 flip-p217 的 1 个有界等待循环（`section-guard.sh --loop-check` 按文件内顺序配对） | +1 行 |

判据的 diff（`common.sh`）：`team_proc_executing_bin` 与 `team_proc_cmdline_is_bin` 的分工写在函数头注释里，
调用点只有一处：

```bash
  if team_is_shell_cmd "$cmd"; then
    # P217：前台是 shell 时，pane_pid **自己**可能就在执行 agent（`bash <agent>`，argv[1] 是它）。
    # 先问这一条（逐词相等，不是「整串里提到」），不成立才退回「只看直接子进程」。
    if team_proc_executing_bin "$pane" "$(team_agent_bin_path 2>/dev/null || true)"; then
      pid="$pane"
    else
      pid="$(team_pane_proc_tree_pid "$target" team_proc_is_agent_bin children 2>/dev/null || true)"
    fi
  else
    pid="$(team_pane_agent_pid "$target" 2>/dev/null || true)"
  fi
```

**没动的**：PM 侧判据（`team_proc_is_pm_bin`/`team_pm_pane_agent_pid`）、非 shell 那一支、`team_pane_proc_tree_pid`
的扫描、P210 的遗体 pane 判定（`pane_dead=1` 先判死）、`flip-p210.sh` 一个字节。

## 四、验证证据（都实际跑过）

### 4.1 `openspec validate --all --strict`（容器）

```
$ bash docs/team/reports/P217-dev/run-container.sh "$PWD" 'openspec validate --all --strict'
✓ spec/agent-adapters  ✓ spec/board-and-status  ✓ spec/boundary  ✓ spec/delivery-guard  ✓ spec/dispatch
✓ spec/init-skill  ✓ spec/meeting  ✓ spec/memory-and-deps  ✓ spec/notify-and-inbox  ✓ spec/panel
✓ spec/pm-lifecycle  ✓ spec/verification  ✓ spec/watchdog
Totals: 13 passed, 0 failed (13 items)          container-cmd-exit=0
```

### 4.2 缺陷面选段（容器）：`--select 2,4,5,3b,6,6k,41` → **✓264 ✗0**

```
$ bash docs/team/reports/P217-dev/run-copy.sh "$PWD" \
    'bash skills/teamsmith/tests/smoke.sh --select 2,4,5,3b,6,6k,41 </dev/null'
#9 6 · dispatch · ✓13 ✗0        #10 6k · worker 存活：… · ✓27 ✗0 SKIP0      ← 含新的 ⑧
#11 41 · pane 留存：…（P55） · ✓96 ✗0 SKIP0  ← P214 那两条红已消失
账本自查： 11 段收口 · 增量 ✓264 ✗0 SKIP0 ｜ 结果行 ✓264 ✗0 —— 一致
== 选段结果 ==  ✓ 264  ✗ 0
```

（`evidence/sel-brief-commands.out` 的 B 段（冻结 tip 上重跑）；`evidence/sel-criterion-git-mount.out` 是同一命令在
tip `ac2b2079` 上的读数，两次数值一致。选段为什么不是任务书写的 `--select 2,41`，见 4.4 与第七节 1。）

### 4.3 改动面选择器给的段（容器）：**✓2340 ✗24**，24 条红逐条定位，且都在 P217 之前的树上复现过

```
$ bash skills/teamsmith/tests/section-select.sh --paths \
    skills/teamsmith/scripts/lib/common.sh skills/teamsmith/tests/smoke.sh \
    skills/teamsmith/tests/flip-p217.sh skills/teamsmith/tests/loop-inventory.tsv
decision=RUN   sections=125   keys=54
0,0b,0c,0d,0e,0f,0h,0i,2,4,5,3b,6,6c,6f,6i,6j,6k,7b,11b,11b3,11d,11f,11h,14b,15c,12b-h0b,12b-h0d,14,14c,
18,18b,19,26,27,28,34,34b,36,38,40,42,43,45,46,47,48,50,52,54,55,56,59,14d

$ bash docs/team/reports/P217-dev/run-copy.sh "$PWD" 'bash skills/teamsmith/tests/smoke.sh --paths \
    skills/teamsmith/scripts/lib/common.sh skills/teamsmith/tests/smoke.sh \
    skills/teamsmith/tests/flip-p217.sh skills/teamsmith/tests/loop-inventory.tsv </dev/null'
copy-dest=/tmp/p217final-… tip=dba16cc2…（本 worktree 的 /tmp 副本 = CI 的新鲜检出等价物）
#18 6k · worker 存活：看 pane 进程树，不看 pane_current_command（M37） · ✓27 ✗0   ← 含新的 ⑧
#32 19 · OpenSpec 五阶段流水线：每阶段有所有者与门禁（M9.1） · ✓16 ✗10
#33 26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离） · ✓138 ✗10
#38 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · ✓106 ✗4
（其余 49 段全绿）
账本自查： 53 段收口 · 增量 ✓2340 ✗24 SKIP0 ｜ 结果行 ✓2340 ✗24 —— 一致
== 选段结果 ==  ✓ 2340 ✗ 24        container-cmd-exit=1
```

（`evidence/sel-changed-paths-copy.out`、`evidence/sel-final-tip.out`。§41 ✓96 ✗0 也在这一段里。）

**24 条红分成三组，每一组我都在 P217 之前的树上按同一选段/同一前缀复现过，逐条数字相同**：

| 组 | 条数 | 机制（都属于环境前置，不是判据、不是 P217 的改动） | 对照证据 |
|---|---|---|---|
| §19 相位 command/skill 在位 + §36① 的 `--check` + §36⑧ | 10 + 3 + 1 | `.pi/prompts/opsx-*.md` 与 `.pi/skills/*/SKILL.md` 是 `openspec init --tools pi` 生成的**机器面**，这台机器上**任何** worktree 里都没有（宿主实测：主 worktree 只有 `.pi/team/`） | pre 树同选段 `--select 19,26,36`：§19 ✓16 ✗10、§36 ✓106 ✗4（`evidence/sel-pre217-19-26-36.out`） |
| §26-m 真 pane（`pane=0 字节`） | 10 | **与选段的前缀/现场有关，与树无关**：面板夹具要在真 pane 里拉一帧，在前导段跑过一堆真 pi 窗口之后再拉就拉不出来；单独跑同一段则 ✓148 ✗0 | 同一段：我的树单独 `--select 26` ✓148 ✗0（`evidence/sel-tmpcopy-26.out`）；**带上同样的前导段**两边都是 ✓138 ✗10（`evidence/sel-prefix26-mine.out` / `sel-prefix26-pre.out`） |
| §36③/④/⑥ 嵌套跑里的 §0d | 4 | **跑法**造成：直接挂 worktree 时 `git rev-parse --git-common-dir` 的父目录落到主仓路径，容器里那只是 podman 建出来的空挂载点 → 嵌套 run 报 `dubious ownership`（§5.5 有机制与两个绕法） | 同一选段在 /tmp 副本上 §36 ✓106 ✗4（`evidence/sel-final-tip.out`）；挂 worktree 时 ✓102 ✗8（`evidence/sel-changed-paths.out`） |

三组的结论一致：**P217 碰得到的段全绿**（§6k ✓27 ✗0、§41 ✓96 ✗0，以及 49 段其余全绿），红的三段在 P217 之前的树上一字不差地同样红。

### 4.4 部分选段里"夹具起不来"的两种前提（给 P218 的材料）

冻结 tip（代码+夹具 tip `dba16cc2` 的副本）上，**任务书原话的那条命令**：

```
$ bash docs/team/reports/P217-dev/run-copy.sh "$PWD" 'bash skills/teamsmith/tests/smoke.sh --select 2,41 </dev/null'
#4 0d · 冲突标记守卫 · ✓9 ✗0          ← 副本是真仓库，这一条不再受挂载影响
#5 2 · init · ✓41 ✗0
#6 41 · … · ✓36 ✗67                   ← 第一条就是 `✗ P55 ①：派单失败`，随后 66 条级联
账本自查： 6 段收口 · 增量 ✓98 ✗67 SKIP0 ｜ 结果行 ✓98 ✗67 —— 一致
== 选段结果 ==  ✓ 98 ✗ 67      A-exit=1
```

同一个坑还有第二种表现：

```
$ bash … run-select.sh "$PWD" … 2,6k,41 p217-sel-2-6k-41
#6 6k · … · ✓11 ✗21 SKIP0        # §6k **不**建 session → 21 条级联
#7 41 · … · ✓96 ✗0               # §41 自己能把 session 建起来（dispatch → team_tmux_ensure_session）
== 选段结果 ==  ✓ 168 ✗ 22
```

机制：这些段的夹具都用 `tmux new-window -t "$SESSION"`，或者直接 `team dispatch`（最终 `respawn-pane`），
而 `$SESSION` 是**前面跑过 dispatch/pulse 的段**建的（`team_tmux_ensure_session`，`common.sh:1381`）——
`--select 2,41` 里没有那个前导段，派单当场失败，后面 66 条全是级联。
（`evidence/sel-brief-commands.out`、`evidence/sel-2-6k-41/select.log`。）

### 4.5 flip 包（容器）

`flip-p217.sh` 先打印夹具现场的进程形状（`ps -o args= -ww`），下面这几行本身就是证据：
**s1 与 s2 的 pane 命令行逐字相同**（`bash <agent>`；`bash -c` 的末条命令被 exec）；**s3/s4 的 agent 是**子进程；
**s5（`-s <agent>`）与 s6（对照）没有 agent 子进程**。

```
  夹具 p217s1   pane_pid=… 命令行=[bash /tmp/…/fake-bin/p217-agent]                     子进程=[sleep 600;]
  夹具 p217s2   pane_pid=… 命令行=[bash /tmp/…/fake-bin/p217-agent]                     子进程=[sleep 600;]
  夹具 p217s3   pane_pid=… 命令行=[bash -lc /tmp/…/p217-agent & wait]                   子进程=[bash /tmp/…/p217-agent;]
  夹具 p217s4   pane_pid=… 命令行=[bash -lc /tmp/…/p217-agent; :]                       子进程=[bash /tmp/…/p217-agent;]
  夹具 p217fake pane_pid=… 命令行=[bash --noprofile --norc -s /tmp/…/p217-agent]         子进程=[]
  夹具 p217ctl  pane_pid=… 命令行=[bash -c sleep 600 && true]                           子进程=[sleep 600;]

$ bash docs/team/reports/P217-dev/run-container.sh "$PWD" 'bash skills/teamsmith/tests/flip-p217.sh'
P217 之前的 revision: 2e473aee…^（docs(team): close P214）    ← 自己找到的（没传 TEAM_FLIP_PRE217）
  形状                   窗口       pre(无 P217)  green(P217)    mut(放宽成「提到」)
  ① pane 命令就是 agent p217s1       stopped        alive          alive
  ② 外层 bash -lc <agent> p217s2       stopped        alive          alive
  ③ <agent> & wait（子进程） p217s3       alive          alive          alive
  ④ 生产 harness 形状 p217s4       alive          alive          alive
  ⑤ P103 假活（-s <agent>） p217fake     stopped        stopped        alive
  ⑥ 对照（无 agent） p217ctl      stopped        stopped        stopped
  CLI 层：pre 列出 p217s1/s2 可续跑；green 只列 ⑤⑥（① 判活 → 不会被 respawn）
== 翻转断言 == 13 条全 ✓        flip-p217：翻转已复现（①② 假阴性红 → 绿；判据放宽即 ⑤ 红）   rc=0

$ bash docs/team/reports/P217-dev/run-container.sh "$PWD" \
    'TEAM_FLIP_BASE=872df9f3 bash skills/teamsmith/tests/flip-p210.sh'      # 872df9f3 = 55326ee4^（P210 修复前）
  形状                   红(修复前) 绿(修复后) 变异(判据改回)
  p210bare                 alive          stopped        alive
  p210run                  alive          alive          alive
  p210ctl                  stopped        stopped        stopped
  p210dead                 stopped        stopped        stopped
== 翻转断言 == 10 条全 ✓        flip-p210：翻转已复现（裸 shell 红 → 绿；判据改回即红）   rc=0
```

### 4.6 守卫模块自检（宿主，纯逻辑）

```
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 77 行清单 / 77 个 while+sleep 循环，配平 77 个        → 全过
$ bash skills/teamsmith/tests/section-guard.sh --budget-check
ok: 预算表覆盖 125/125 个 section 且每行都满足 max(ceil(band×4), 60)   → 全过
```

- Verdict: 4.1/4.2/4.3/4.5/4.6 通过（4.3 的 24 条红全部逐条定位并在 P217 之前的树上复现，见 4.3 的表）。
- Notes（**没测到的**）：全量套件（125 段）没跑；真 pi/真 agent CLI 的路径没测（夹具用假 agent 脚本）；
  panel 计时/perf 段落没跑（不在选段里）；PM 侧判据没动因此没测；`docs/team/reports/**` 里的证据目录不进仓库
  （合并分支不会带过去）。

## 五、Flip evidence

### 5.1 红 → 绿（同一选段、同一枚镜像，只有树不同）

```
$ bash … run-container.sh "$PWD" '…git archive 453d46e9 | tar -x -C /tmp/pre217 … \
    bash /tmp/pre217/skills/teamsmith/tests/smoke.sh --select 2,4,5,3b,6,41'      # pre = P217 之前
  ✗ P55 ④：roster 四态 ① running（证明成立）（…p55-roster.log 中没有匹配 [^p55live +● .*在跑]）
  ✗ P55 ④：机器面断言失败
#10 41 · … · ✓94 ✗2 SKIP0          ← P214 现场逐条复现（同样是这两条）
== 选段结果 ==  ✓ 235  ✗ 2         container-cmd-exit=1

$ bash … run-container.sh "$PWD" 'bash skills/teamsmith/tests/smoke.sh --select 2,4,5,3b,6,6k,41'   # 我的树
#11 41 · … · ✓96 ✗0 SKIP0
== 选段结果 ==  ✓ 264  ✗ 0
```

（`evidence/sel-pre217-41.out` / `evidence/sel-criterion-git-mount.out`。）

### 5.2 判据单独承重（我的树 + 旧夹具）

把 `p55live` 那一行在 /tmp 的副本里**改回旧形状**（`"$FAKE/p55-agent"`，判据仍是新的）：

```
$ bash … run-container.sh "$PWD" '…sed -i … p55live … bash /tmp/v4/skills/teamsmith/tests/smoke.sh --select 2,4,5,3b,6,41'
16464:  tmux new-window -d -c "$REPO" -n p55live -t "$SESSION" "$FAKE/p55-agent" …   ← 旧夹具那一行（已改回）
#10 41 · … · ✓96 ✗0 SKIP0
== 选段结果 ==  ✓ 237  ✗ 0        container-cmd-exit=0
```

意思是：§41 的绿不靠"把夹具挪出射程"换来 —— 判据补准之后，旧夹具那个形状本身也判对了。反方向（旧判据 + 新夹具
= 任务书的 B）P214 已实测 ✓96 ✗0（**引用**，我没有重跑）。

### 5.3 影子：把判据改回"命令行里提到 agent 就算在跑"

`flip-p217.sh` 的变异树只改一件事 —— `team_proc_executing_bin` 从"argv[1] 逐词相等"放宽成"整串 token 里
出现 agent"（P103 的旧口径）：

```
  ✓ 判据翻转：变异树把 ⑤ 判回 alive —— 绿树咬的就是 argv[1] 这条分界
  ✓ 判据翻转不是橡皮章：变异树对 ⑥（命令行里没有 agent）照旧判 stopped
```

也就是：放宽之后，P103 那条红侧（`bash --noprofile --norc -s <agent>`）**必须**变 alive；绿树对它
"必须 stopped"的断言就会红。两份 flip 包各自还带着各自的影子（flip-p210 的变异树把 P210 两道判据整个改回旧行为，
绿树断言照旧红）。

### 5.4 破坏实现 → 门禁断言必须红（我自己写的变异，只给复验看）

`docs/team/reports/P217-dev/mutate-6k-8.sh` 把我树上的**实现**改回 P217 之前（前台是 shell 时只认直接子进程），
其余一个字节不动，然后跑 §6k：

```
$ bash … run-container.sh "$PWD" '… git archive HEAD | tar -x -C /tmp/mut … mutate-6k-8.sh /tmp/mut \
    && bash /tmp/mut/skills/teamsmith/tests/smoke.sh --select 2,4,5,3b,6,6k'
已变异：前台是 shell 时只认直接子进程（= P217 之前）
  ✗ 6k ⑧ P217：pane_pid 自己就在跑 agent（argv[1] 就是 agent、没有 agent 子进程）判活（期望 [alive]，实际 [stopped]）
  ✗ 6k ⑧ P217：resume --dry-run **不列**它（不该出现 [m37w 可续跑]）
#10 6k · … · ✓25 ✗2 SKIP0
== 选段结果 ==  ✓ 166  ✗ 2
```

只有 ⑧ 的两条断言变红（⑥ 的 P103 形状照旧绿），也就是说 §6k 的新用例真的咬在 P217 的改动上，而不是橡皮章。

### 5.5 跑法（容器里怎么跑门禁）：直接挂 worktree 会多出 14 条假红，两条绕法

第一次把 worktree 直挂进容器跑改动面选段，收口是 ✓2336 ✗28；逐条定位之后，其中 14 条是**跑法**造成的，
不是树：

| 红 | 条数 | 机制 |
|---|---|---|
| §26-m 真 pane（`pane=0 字节`） | 10 | worktree 的 `.git` 是一行 `gitdir:` 指针 → `git rev-parse --git-common-dir` 的父目录落到**主仓路径**；容器里那只是 podman 建出来的**空挂载点**（宿主 `ls -ld`：属主 root）→ 面板夹具从仓库根解析的路径取不到东西，一帧也画不出来 |
| §36③/④/⑥ 的嵌套 §0d | 4 | 同一个指针 → `P98_MARKER_ROOT` / `SMOKE_INVOKE_ROOT` 取到那个 root 属主的空挂载点 → `git -C` 报 `detected dubious ownership` → 嵌套 run rc=1 |

两条绕法（都实测过）：

1. **把主仓根也挂进去**（只读）：`--select 26` → ✓148 ✗0（§26-m 的 10 条消失）。
2. **在一份宿主 /tmp 副本上跑**（`docs/team/reports/P217-dev/run-copy.sh`：`tar` 出工作树（除 `.git`）
   → `git init` 成一枚真仓库 → 挂它）—— 这就是本报告 4.3 采的跑法，也与 CI 的「新鲜检出」同形。

另外一个自伤的纪律问题也记在这里：**第一轮改动面选段我是三个容器（选段 + 变异 + 前置探针）同时跑的**，
里面既有「一轮门禁一份机器」的纪律问题，也让当时的读数不可信（同一份日志里 §26 的红我一开始归因成负载，
后来逐条排掉才发现是跑法）。后面的读数都是一次一个容器跑出来的。

## 六、没跑的、以及为什么

- **全量套件没跑**：任务书给的判据是"选段 + 改动面"，我跑的是缺陷面选段（§6k/§41 与它们的前提）+
  改动面选择器给的 54 键（其中 §26/§36 的读数与逐条定位见 4.3 与 5.5）。全量（125 段）留给发布门禁/PM 复验。
- **真 agent CLI**：夹具用脚本型假 agent（`echo` + `sleep`），没有真 pi 进程；判据只读进程命令行与 cwd，
  但"真 CLI 的 argv 形状"没有实测（生产 harness 的形状由 §41 的夹具与 `cmd-agents.sh:1289/1299` 的代码路径覆盖）。
- **§26-m 的环境敏感性**没修（不在本任务范围）：它在长选段里会红 10 条、单独跑是绿的，P217 之前的树同样如此
  （4.3 的对照）。我只用到「与 pre 树逐条相同」这一步，没有往下查它的前导段依赖。
- **跨平台**：只在容器的 Linux 上跑了；`ps -o args=` 的输出形状在别的平台未验证（原有判据同样假设）。
- 没跑的段（选段里没出现的）就是没跑；不改 `.pi/**`、`openspec/**`、`.github/**`。

## 七、决定与偏差

1. **选段命令与任务书不同（`--select 2,41` → `2,4,5,3b,6,6k,41`），原因是它的前提不只 §2**：
   `--select 2,41` 实测 **✓97 ✗68**（`evidence/select.log`，第一次基线运行）——§41 的夹具要
   (a) `$REPO/.pi/team/state/`、(b) 一个**已存在的 tmux session**（`tmux new-window -t "$SESSION"` 没有 session 就失败），
   而 §2 的 init 只写配置（session 是 `team_tmux_ensure_session` 在 dispatch/pulse 路径里建的）。
   `2,6k,41` 里 §6k 反而成了红的（21 条：窗建不起来），因为 §6k 也要那个 session；
   `2,4,5,3b,6,6k,41` 是能同时让 §6k 与 §41 站在真实前提上的最小集合。**这是 P218 的材料**：
   §41 与 §6k 的 `needs` 都是 `-`，而它们真正的前提是"前面跑过 dispatch 的段"。
2. **顺带发现（也给 P218）**：映射表里 §41 的行只声明 `skills/teamsmith/scripts/team`，所以"只改 §41 自己的夹具"
   这条路径**选择不到 §41**（我这次的改动面选段里没有 41；我手工把 41 补进了缺陷面选段）。§6k 的行声明了
   `common.sh`，所以它在改动面里 ✓。
3. **跑法（给复验者，细节在 5.5）**：worktree 直挂进容器会多出 14 条假红（§26-m ×10 + §36 嵌套 §0d ×4）；
   本报告的改动面选段是在一份 **/tmp 副本**（`run-copy.sh`）上跑的（✓2340 ✗24）。因此改动面里有 10 条 §26-m + 4 条
   §36 与树无关；剩下的 §19/§36① 两组（共 14 条）也是两边同红。用 worktree 直挂时还要多挂一份主仓 `.git`
   （`run-container.sh`），否则 `git -C /work archive …` 直接 fatal。
4. **规格层的一句话**：`openspec/specs/watchdog/spec.md` 的 "A dead pane is a seat condition …" 写着
   `running` 的证明规则不许变松（死 pane / 死 pid / 仅仅存在的窗口 MUST NOT 被报成 running）。判据补准没有放松
   这三条，也没有把"命令行提到 agent"算成证据，所以按任务书的 `change: -` / `anchor: none (infra)` 没有做 spec 变更。
   若 PM 认为"证明规则"的字面口径也要改，请在复验里退回，我把措辞补进 watchdog 的 scenario（那是规格层的活）。
5. **一处自伤的自查**：flip-p217 第一次跑时，断言文案里的反引号在双引号里被当成命令替换（日志里出现
   `bash: <agent>; :: command not found`）；断言逻辑没受影响，但日志不可粘贴。已单独提交修掉（`ac2b2079`）。

## 八、给 PM 的下一步

- 独立复验（换人）：`team review P217 --strong`。建议复验者亲手跑 §41/§6k 两个段与两份 flip 包
  （`flip-p217.sh` 会自己找到「修复前」的那个 revision，不用传参数），
  并至少试一次"把 `team_proc_executing_bin` 的 argv[1] 放宽成任意 token → §6k ⑧ 必须红"
  （证据目录里给了现成的变异脚本 `mutate-6k-8.sh`）。
- 跑门禁的建议（不要在 worktree 直挂上浪费时间）：`bash docs/team/reports/P217-dev/run-copy.sh <worktree> '…'`；
  两棵树的可比读数在 4.3 的表里（§26 那 10 条与树无关，跑之前先知道能省半小时）。
- P218（`needs` 的坑）：按第七节 1/2 修 §41/§6k 的 `needs`，并给 §41 的行补上 `skills/teamsmith/tests/smoke.sh`
  这条声明（否则"改夹具"这条路选择不到它）。
- P214 剩下的修法（§19/§36①/§31/§58/§39）与本任务无关，仍挂在 P214 的报告里。
