# P43 · ledger-and-gate-noise：门禁指纹假红 + 未入账记录扫不到 worktree + 空 override 的非法 JSON（propose）

```
task:    P43
agent:   dev-bob
branch:  task/P43-json-override-propose（local 模式：不 push；分支留在 .worktrees/dev-bob）
change:  ledger-and-gate-noise（phase: propose；**未写任何实现**）
status:  DONE（提案包 + 红侧实测 + 报告）
```

本任务只出提案：`openspec/changes/ledger-and-gate-noise/` 四件套（proposal / design / tasks / 三份
spec delta）+ 报告。`skills/**`、`openspec/specs/**`、任务书零改动。

## Deliverables

| 路径 | 内容 |
|---|---|
| `openspec/changes/ledger-and-gate-noise/proposal.md` | 三条缺陷的红侧与要收口的内容（506 词，含验收命令与 flip 承诺） |
| `openspec/changes/ledger-and-gate-noise/design.md` | 现场测量、能力归属裁决、四项设计裁决（D0–D4）、复验映射、交回 PM 的风险 |
| `openspec/changes/ledger-and-gate-noise/tasks.md` | apply 任务清单（5 组、16 项，每项带可失败的复核命令、路径授权、夹具纪律、逐 requirement 复核表） |
| `openspec/changes/ledger-and-gate-noise/specs/verification/spec.md` | **ADDED**：容器自检的宿主前提是稳定状态（4 个 scenario） |
| `openspec/changes/ledger-and-gate-noise/specs/board-and-status/spec.md` | **MODIFIED ×2**：未入账记录遍历 worktree（1→4 scenario）；git 调用预算与计数夹具（3→3，逐字保留） |
| `openspec/changes/ledger-and-gate-noise/specs/memory-and-deps/spec.md` | **MODIFIED**：席位读与空 token 解析（8→11，基础 scenario 逐字保留）；**ADDED**：机器出口都是 JSON（2 个 scenario） |
| `docs/team/reports/P43-dev-bob.md` | 本报告 |

## 验收命令（实际运行，尾部为真实输出）

### 1) OpenSpec 严格校验（提案包本体）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate ledger-and-gate-noise --strict
Change 'ledger-and-gate-noise' is valid

$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/ledger-and-gate-noise（19 项里的一个）
Totals: 19 passed, 0 failed (19 items)
```

### 2) delta 形态自检（MODIFIED 标题对得上 base、基础 scenario 一条不丢）

```
$ python3 …（读 base spec 与 delta，逐 Requirement 比对标题与 scenario 标题）
verification       ADDED     NEW           The container self-test's host fingerprint is stable state…
board-and-status   MODIFIED  MATCHES-BASE  Unfinished work is visible as pending wrap-up
board-and-status   MODIFIED  MATCHES-BASE  The ledger read path stays inside a git-call budget…
memory-and-deps    MODIFIED  MATCHES-BASE  A seat's model is read and written as a seat…
memory-and-deps    ADDED     NEW           Every machine read is a JSON document, and an empty value is a value

board-and-status: 'Unfinished work…'          base=1 delta=4 missing=[]
board-and-status: 'The ledger read path…'     base=3 delta=3 missing=[]
memory-and-deps : 'A seat's model…'           base=8 delta=11 missing=[]
```

（`openspec validate` 不检查 MODIFIED 与 base 的匹配、也不检查 scenario 是否有 WHEN/THEN —— 上述逐条比对是我
自己做的，不是门禁给的。）

### 3) FAST smoke（提案包不破坏现有门禁；全量留给 apply/verify）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2315  ✗ 0
FAST 模式：跳过 29 个真进程段落（1c·M11 真沙盒窗口|…|31b·容器 tmux 自检（podman）|31c·真私有 server 生死|…|38-f·panel-p21-settings-groups-wheel）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
（exit 0；后台作业日志 .pi/team/state/bg/p43-fast-smoke.log，当时只留了 tail -25）
```

## 三条缺陷的红侧（今日在本 worktree / 临时夹具里实测）

### ① M28 指纹把瞬时客户端算进去（D34）

复刻 `container-tmux.sh:102` 的 `host_tmux_fingerprint()` 逐字（探针在 `/tmp/p43fix/fp.sh`，未进仓库）：

```
== 现有选择的进程行（ps -eo pid=,args= | grep -E '(^|/)tmux( |$)'） ==
  PROCLINE  341435 /usr/bin/tmux -L p21-340854 new-session -d -s p21-340854 … sleep 900
  PROCLINE  352292 /bin/bash -c cd /tmp/p43fix && echo … bash fp.sh raw | head -5 …   ← 只是命令行里提到 tmux 的 shell
  PROCLINE  352356 bash …/skills/teamsmith/scripts/shim/tmux list-windows -t teamsmith -F #{window_name}

=== A: 并发瞬时客户端 → 指纹变？ ===
before=1477ba9ea881c6d1b9dadcd394a0ff44 after=a55a6516dc70bb1a28a05ce055185795  DIFFER

=== B: 私有“默认 socket”上的 server 活着 → 杀掉 ===
alive hash: d60a6e259f23453dfbbd23b931d82463
dead  hash: （空）   ← 现有函数在无匹配进程时因 `grep -v grep` 非 0 + `pipefail` 输出空串
```

两条根因都坐实了：

1. `^tmux` 那一支**永不命中**（`ps -eo pid=,args=` 的 pid 右对齐，行首是空格），真正命中的是 `/tmux `
   一支，即**带路径**的调用（门禁 shim、`/usr/bin/tmux …`）；**真正的 server 进程**（`tmux new-session -d …`，
   ppid=1）与 `tmux attach -t …` 都不命中。所以这份快照既漏 server、又被客户端与“命令行里提到 tmux 的 shell”
   左右。
2. `ps` 组件的匹配面决定了它不是“host 状态”，而是“此刻谁碰过 tmux”。

额外实测（写进 design D1 的依据）：`display-message -p '#{pid}'` 在**没有 server** 的 socket 上 rc=1
（`error connecting to …`），**不起 server**（只建了 socket 目录），所以“按 socket 拿 server pid”是只读、
可用的机制；`#{pid}:#{socket_path}:#{session_name}` 在活的私有 server 上返回
`808231:/tmp/p43fix/sock2/tmux-1000/default:p43pid`。

### ② 未入账记录扫不到 agent worktree（M31 / P36）

临时夹具（`team init` 出来的真仓库 + `git worktree add .worktrees/dev`，主检出与 worktree 各放一条记录）：

```
$ team digest（主检出有 docs/team/reports/P43m-dev.md；worktree 有 docs/team/reviews/P43r.md、
              docs/team/reports/P43d-dev.md、docs/team/reports/P43d-dev/run.sh，外加 junk.txt）
[4] 待收尾（脏工作区 / 相对 upstream 未 push 的提交；领先按 main 另计；squash 已合并单独标注）
  dev        脏 2 ｜ 无 upstream（未 push 无法判定）    ｜ task/p43-dev ｜ -
  记录未入账       1 份 untracked（squash 合并只带分支内容，先提交再合并/归档）：
    · docs/team/reports/P43m-dev.md（未入账）

$ grep -c 'P43r' digest.out     → 0        ← worktree 里的复验记录：[3]、[4] 都不提
$ grep -n 'P43d' digest.out     → [3] 一行：P43d-dev（在 dev 分支上）（未入账报告）… 先等 agent 交付
$ grep -n 'run.sh' digest.out   → 0        ← 报告包里的文件一条都不点名
```

即：worktree 里的**复验记录**完全不可见；worktree 里的报告只在 [3] 以“草稿/先等交付”的口径出现，[4] 的
“这些字节没进任何提交、squash 会丢”一句话永远不说，包内文件也不点名。主检出口径本身是好的（上图第一行）。

### ③ 空 override 产出非法 JSON（M74 坐实，main 上同样）

夹具：`team init` 仓库的 `TEAM_AGENT_MODELS="dev="`。

```
$ team config list --json
…"models":{"default":"deepseek/deepseek-flash","known":["deepseek/deepseek-flash","配置"],
"seats":[{"agent":"dev","model":"配置","source":"config","override":},{…}],…}
$ python3 -m json.tool out.json
Expecting value: line 1 column 35533 (char 35532)      rc=1
$ team ps
dev        · 无窗口 task/p43-dev                  2        0       -  0·配置               …
```

字段错位的机理（读代码 + 复现）：`team_config_seat_state` 对 `dev=` 回退成**空 model**，打印
`\t配置\ttrue`；`IFS=$'\t' read` 把前导 tab 当 IFS 空白吃掉，于是 `model=配置`、`src=true`、`override` 未设
—— 同一形状在 `models.known` 的第二次 `read`（`cmd-config.sh:661`）里把来源标签写进了模型词汇表。

## Flip evidence（propose 阶段能给的那一半：红侧实测 + 绿侧的可失败承诺）

本任务不写实现，所以“红 → 绿”只可能给出**红侧实测**与**绿侧承诺**（每条承诺都落在 tasks.md 的一个可失败
复核项上）。红侧全部在上节实测；绿侧逐条对应：

| 缺陷 | 红侧（已实测） | 绿侧承诺（apply，task） | 反向对照（必须是红的） |
|---|---|---|---|
| ① 指纹假红 | 客户端风暴 `1477ba9e…` → `a55a6516…`；server 死掉后旧函数输出空串 | `--fingerprint-check` 风暴腿字节相同、退出 0（1.2） | 把 `ps` 快照塞回 scratch 树 → 风暴腿红、§31c 静态 pin 红（1.2/1.3） |
| ② worktree 记录不可见 | `P43r` 在 [3]/[4] 都不出现；`run.sh` 不点名；`P43d` 只在 [3] 作草稿 | digest 点名 `dev: docs/team/reviews/T9r.md` / `dev: …/T9d-dev.md` / 包内文件（2.1/2.2） | 把扫描改回只扫主检出 → §7b 红；`junk.txt` 永远不报（2.2） |
| ③ 非法 JSON | `json.tool` 在第 35533 列失败；`"override":}`；`known` 含 `配置`；`team ps` `0·配置` | 四个机器出口全过解析；`dev` 行 `model`=`TEAM_DEFAULT_MODEL`、`override`=`true`（3.3/3.4） | F-J1：scratch 树里恢复无值字段 → `config-cli.sh` 红并报解析位置（3.3/3.4） |

## 每条 requirement 的复核方法（跑什么 → 看哪段 → 期望值）

完整表在 `openspec/changes/ledger-and-gate-noise/tasks.md` 开头，摘要：

| Req（能力） | 跑什么 | 看哪段 | 期望 |
|---|---|---|---|
| R1 指纹前提（verification） | `bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check` + smoke §31c | 四条腿的输出 | 风暴腿两值相等、退出 0；杀 server / 建会话腿两值不同、退出非 0；无 server 腿两次退出 0 |
| R2 记录可见性（board-and-status） | scratch 仓库 + worktree 夹具；smoke §7b | digest 的 `记录未入账` 块 | 每个文件一行 `dev: <路径>`；`junk.txt` 不出现；digest 退出 0 |
| R3 调用预算（board-and-status） | smoke §37 计数夹具（cache 开/关） | 打印的 git 调用数与 digest 块 | cache 开 ≤50 且 worktree 记录被点名；关 >50；开/关输出滤实时字段后逐字节一致 |
| R4 席位读与解析（memory-and-deps） | `config list --json` / `team ps` / `dispatch dev --print`（`TEAM_AGENT_MODELS="dev="`） | `models.seats` 的 dev 行与 `models.known` | `model`=`TEAM_DEFAULT_MODEL`、`source`=`config`、`override`=`true`、`known` 无标签、dispatch 渲染同一模型 |
| R5 JSON 有效性（memory-and-deps） | `bash skills/teamsmith/tests/config-cli.sh json`（smoke §33） | 逐出口的解析行 | 四个出口都退出 0 且被 `python3 -m json.tool` 接受；scratch 树红侧非 0 且报解析位置 |

## 提案的关键裁决（复审要看的四处）

1. **能力归属（D0）**：`verification`（指纹前提）+ `board-and-status`（记录可见性，含预算夹具）+
   `memory-and-deps`（机器读契约）。任务书正文允许「watchdog 或 board-and-status」二选一；我选
   **board-and-status**：被扩写的两条 requirement 都在它名下，`watchdog` 只管 pulse 的待办定义（唤醒集），本
   change 不动唤醒集。**但任务书 `deltas:` 头写的是 `watchdog`** —— 见下节。
2. **指纹形状（D1）**：保留三 socket 循环（`stat` + `list-sessions`），每条 socket 再带上**该 socket 上活着的
   server 的 pid**（`display-message -p '#{pid}'`，只读、不起 server），**删掉整个 `ps` 快照**。理由：`ps`
   无法把 server 归属到 socket，所以任何 ps 型 server 集合都会被“别的项目的私有夹具 server 在窗口里起落”
   继续打成假红（本机有四个项目共用）。红侧不丢：server 死 → socket 消失 + 会话表报错 + pid 行消失；
   `exit-empty off` 的空表 server 由 pid 行兜住。
3. **记录可见性（D2）**：走 `.worktrees/*` 目录而不是 `git worktree list`（git 已 prune、目录还在的记录恰恰
   是“没进任何提交”的那类）；每条记录 `<agent>: <相对路径>`，包内文件逐条点名；只 `??`、只两个 records 前缀、
   只提醒不阻断；[3] 的草稿口径与 [4] 不同问题，两条都留。
4. **空 override 的裁断（D3）**：`override` 永远是 JSON 布尔；`dev=` 是**存在**的 override（`true`），其
   **模型解析**回退到 `TEAM_DEFAULT_MODEL`（与“没 token”同解），`team ps` / `--json` / dispatch 渲染共用这一个
   解析；空串一律 `""`，**永不**出现无值字段，也不用 `null`。这一条会改到 `team_agent_model`
   （`common.sh:1174`），因此 dispatch 渲染的模型也一起变对（今天渲染空模型）；已在 delta 里用
   `dispatch dev --print` scenario 钉住。被否掉的方案（design D3 有理由）：`null`、丢掉该席位行、在读路径
   再放一份兜底、写入侧拒绝 `dev=`。

## 与任务书的偏差 / 需要 PM 决定

- **`deltas:` 头与正文不一致（要 PM 改一行）**：任务书头 `deltas: verification, watchdog, memory-and-deps`，
  正文写「watchdog 或 board-and-status（按能力语义选一个并说明）」。我选了 `board-and-status` 并写了理由
  （design D0）。这不是 BLOCKED：正文明确授权我选，且本 change 只有 P43 一个任务（不存在“两个任务写同一份
  delta”的冲突面）。请 PM 复审时把任务书头的 `watchdog` 改成 `board-and-status`，否则 `team dispatch` /
  `team change status` 的 delta 账目与实际不一致。
- **指纹机制与 D34 原文的措辞差异**：D34 写“只算 tmux server 进程（ps 里 argv 以 tmux 开头且不含子命令的
  server 形态）”，我裁决为“按 socket 取 live server 的 pid”（同一意图：只要 server、不要客户端；机制换成
  可归属的那种）。理由与实测见 design D1 与上面 ①。若 PM 坚持 ps 形态，请在复审里说，我改成
  `ppid=1` + 字段解析的 server 集合 —— 但那样会保留“别的项目私有 server 在窗口里起落”的假红通道。
- **proposal 词数**：配置规则要求 <500 词，实测 506（含验收命令代码块；只算正文 489）。没有为凑数删证据。

## 没有做的事（propose 的边界）

- 没有改任何实现（`skills/**` 零改动）、没有改 `openspec/specs/**`、没有动任务书与 `docs/team/**` 其它文件。
- 没有跑全量门禁（那是 apply/verify 的事）；本回合只跑了 FAST smoke（§3，✓2315 ✗0）作为“提案包不破坏现有
  门禁”的证据。
- 没有写 M31 的 staged/modified 扩展（任务书未要求，design 的 Non-Goals 与风险清单里点名）。

## 复验入口

```bash
bash openspec/changes/ledger-and-gate-noise/…            # 提案是文档，无脚本
PATH="$HOME/.bun/bin:$PATH" openspec validate ledger-and-gate-noise --strict
sed -n '1,80p' openspec/changes/ledger-and-gate-noise/design.md      # 现场测量与四项裁决
sed -n '1,60p' openspec/changes/ledger-and-gate-noise/tasks.md       # apply 任务与路径授权
```

## 边界与干净证明

- 改动只在 `openspec/changes/ledger-and-gate-noise/**` 与本报告（`docs/team/reports/P43-dev-bob.md`）。
- 交付时 `git status --porcelain` 干净；分支相对 `main` 的 diff 恰好 7 个文件（提案 4 件 + delta 3 件 + 本报告）、
  零删除（`git diff --stat main...HEAD` → 934 insertions）。
- 所有实验在 `/tmp/p43fix/**`（探针、夹具仓库、私有 socket 目录）；探针起的私有 server 已 `kill-server`，
  未触碰本队 `teamsmith` 会话与任何别的项目的 server。

## 附录：红侧复现（/tmp，未进仓库；PM 可在任意 checkout 重跑）

① 指纹探针（逐字复刻 `container-tmux.sh:102` 的旧实现，`bash fp.sh fp` 打印指纹、`bash fp.sh raw` 打印
选中行；探针本体如下，存成 `/tmp/p43fix/fp.sh` 即可重跑）：

```bash
#!/usr/bin/env bash
# P43 探针：逐字复刻 container-tmux.sh 现有的 host_tmux_fingerprint()
set -euo pipefail
caller_socket() {
  if [ -n "${TMUX:-}" ]; then printf '%s' "${TMUX%%,*}"; else printf '%s' "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/default"; fi
}
host_tmux_fingerprint() {
  local out="" s sock
  for s in "$(caller_socket)" "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/default" /tmp/tmux-$(id -u)/default; do
    [ -n "$s" ] || continue
    case "$out" in *"|$s|"*) continue ;; esac
    out="$out|$s|"
    if [ -S "$s" ]; then
      out="$out$(stat -c '%i:%Y:%s' "$s" 2>/dev/null || printf '?' )|"
      out="$out$(env -u TMUX -u TMUX_PANE timeout 5 tmux -S "$s" list-sessions \
                  -F '#{session_name}:#{session_created}:#{session_windows}:#{session_attached}' 2>/dev/null | sort | tr '\n' ',')|"
    else
      out="$out(absent)|"
    fi
  done
  out="$out|procs|$(ps -eo pid=,args= 2>/dev/null | grep -E '(^|/)tmux( |$)' | grep -v grep | sort | tr '\n' ';')"
  printf '%s' "$out" | md5sum | cut -d' ' -f1
}
case "${1:-}" in
  fp) host_tmux_fingerprint ;;
  raw) ps -eo pid=,args= 2>/dev/null | grep -E '(^|/)tmux( |$)' | grep -v grep | sort | sed 's/^/  PROCLINE /' | cut -c1-160 ;;
esac
```

然后：

```sh
A1=$(bash fp.sh fp)
( for i in 1 2 3 4 5 6; do /usr/bin/tmux -L p43probe list-sessions >/dev/null 2>&1 || true; done ) &
for i in 1 2 3 4 5 6 7 8; do A2=$(bash fp.sh fp); [ "$A1" = "$A2" ] || break; done; wait
echo "$A1 $A2"     # 实测：1477ba9e… ≠ a55a6516…
T=/tmp/p43fix/sock; mkdir -p "$T"
env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$T" /usr/bin/tmux new-session -d -s p43host sleep 30
B1=$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$T" bash fp.sh fp)
env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$T" /usr/bin/tmux kill-server || true
B2=$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$T" bash fp.sh fp)
echo "$B1 $B2"     # 实测：d60a6e25… ≠ （空/不同值）
```

② 记录可见性夹具：

```sh
t=$(mktemp -d); cd "$t"; git init -q -b main; git config user.email c@t; git config user.name c
printf '{"name":"t"}\n' > package.json; git add -A; git commit -qm init
bash <tree>/skills/teamsmith/scripts/team init --session t --agents "dev verify" --vcs local --gates true --docs docs/team
git worktree add -b task/dev .worktrees/dev main
mkdir -p .worktrees/dev/docs/team/reviews .worktrees/dev/docs/team/reports/T9d-dev
printf '# T9r\n' > .worktrees/dev/docs/team/reviews/T9r.md
printf '# T9d\n' > .worktrees/dev/docs/team/reports/T9d-dev.md
printf 'x\n' > .worktrees/dev/docs/team/reports/T9d-dev/run.sh
printf 'junk\n' > .worktrees/dev/junk.txt
env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION bash <tree>/skills/teamsmith/scripts/team digest | sed -n '/\[4\]/,/\[5\] 任务板/p'
# 实测：T9r 与 T9d 一条都不出现（主检出口径同一行里正常报警）
```

③ 空 override：把夹具 `.pi/team/config.sh` 的 `TEAM_AGENT_MODELS` 改成 `"dev="`，然后
`env -u TEAM_ROOT … bash <tree>/skills/teamsmith/scripts/team config list --json | python3 -m json.tool`
（实测 `Expecting value: line 1 column 35533 (char 35532)`），并 `team ps` 看 `0·配置`。
