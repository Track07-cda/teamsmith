# P168 · 夹具的「真实仓库 state/ 未被触碰」漏掉了后台作业账本（`state/bg.log`）→ 假红

agent: dev   status: done   time: 2026-10-02T13:54:42Z
branch: `task/P168-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/signal-gate.sh` | 反向守卫的排除面改成**按路径逐条列**的并发车道清单（`BG_LANE_PATHS=(bg bg.log)`）+ 由它编译 `find` 判据；签名扫描复用同一份排除面；新增合成树上的 lane-shape 正向对照（3 条断言） |
| `skills/teamsmith/tests/flip-p168.sh` | 跑动中写入的四面翻转夹具（车道绿 / 车道外红 / 变异红 / 还原绿），在夹具+lib+shim 的副本里跑，真树一个字节不动 |
| `docs/team/reports/P168-dev.md`、`docs/team/reports/P168-dev/logs/*` | 本报告与四份翻转日志 |

## 要做的 1 · 车道到底写哪些路径（核实过，不是猜）

用**真扩展**（`extension/team-bg.ts`）跑 harness（假 Pi 宿主），再直接列出它写出来的 `state/` 形状：

```
$ TMPDIR=/tmp/p168-harness ~/.bun/bin/bun skills/teamsmith/tests/team-bg-harness.mjs \
      skills/teamsmith/extension/team-bg.ts --keep
TEAM-BG-CASE PASS reverse guard: the real repo state/ is untouched
TEAM-BG-HARNESS OK
fixture: /tmp/p168-harness/teamsmith-bg-TrxLuA

$ (cd <fixture>/repo/.pi/team/state && find . -mindepth 1 | sort)
bg  bg/big.job  bg/big.log  bg/m1.job  bg/m1.log  …  bg/s7.job  bg/s7.log  bg.log
```

结论：**只有两条路径**，没有别的自述文件 ——
`bg/`（`<id>.log` 作业 stdout、`<id>.job` 作业身份记录，`team bg list|stop` 读它）与 `bg.log`（账本）。
账本行的真实形状（同一跑里抓的 + `scripts/lib/cmd-bg.sh` 的 `team_bg_stop` 分支）：

```
2026-10-02T13:50:54.338Z settled-with-unharvested=1 jobs=s1:running     # 扩展 · 回合结束
2026-10-02T13:50:54.989Z wake count=1 ids=s1                            # 扩展 · 唤醒投递
<ts> stop id=<id> signal=TERM result=stopped pid=… pgid=… by=… cwd=…    # team bg stop
```

（宿主 node v24.19.0 跑不了 `.ts`：`ERR_UNKNOWN_FILE_EXTENSION`，所以这一步用 `~/.bun/bin/bun`；
容器里门禁自己的 runner 选的是 `node`，段内那条腿照旧绿。）

## 要做的 2/3 · 排除面：按路径、逐条可列、不扩大

`signal-gate.sh` 里现在只有**一处**声明，两条守卫都从它取：

```bash
BG_LANE_PATHS=(bg bg.log)          # 相对 state/ 的路径（不是名字匹配）
state_snapshot() { # <state-root>
  local root="$1" rel expr=()
  for rel in "${BG_LANE_PATHS[@]}"; do expr+=(-path "$root/$rel" -o); done
  expr=("${expr[@]:0:${#expr[@]}-1}")
  find "$root" -mindepth 1 \( "${expr[@]}" \) -prune -o -printf '%P\t%s\t%T@\n' | sort
}
```

每条路径的「为什么属于并发车道」写在注释里（`bg/`：作业产物，runner 把门禁输出抄进去；
`bg.log`：扩展每回合一行 + `team bg stop` 一行，都由**正在跑的门禁自己**写）。
签名扫描不再另写第二份判据，而是 `state_snapshot | cut -f1` 出来的那份文件列表上逐个 grep ——
排除面只有一处，两份不会漂移。

**不许扩大成「整个 state/ 都不看」**：段尾新增合成树探针（每次门禁都跑），在 `$TMP/lane-shape` 里
造 `bg/1.log`、`bg/1.job`、`bg.log`、`other.log`、`sub/keep.txt`，断言

- ✓ 车道之外的 `other.log` 照旧进快照；✓ 车道之外子目录里的 `sub/keep.txt` 照旧进快照；
- ✓ 车道两条（`bg/` 与 `bg.log`）都在排除面里。

任何「放宽成整个 state/」的改动会当场把前两条打红；任何「漏掉车道」的改动会把第三条打红
（翻转③的日志里第三条正是红的：`形状：并发车道里的路径还是进了快照（排除面漏了：bg.log …`）。

## Verification evidence

```
# 代码树 = 834f51b7（其后只有报告提交）
$ ~/.bun/bin/openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)                                   # rc=0

$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v "$PWD":/work -v <home>/Documents/syncthing/Work/Projects/pm-skills/.git:<home>/Documents/syncthing/Work/Projects/pm-skills/.git:ro \
    -w /work localhost/teamsmith-gate:local bash -c '…'
=== A) FAST --select 58 ===   #13 58 … ✓12 ✗0 SKIP0 · ✓ 58 signal-gate 全绿（66 行 ✓）
  == 选段结果 ==  ✓ 366  ✗ 0        A_RC=0
=== B) FULL --select 58 ===   #13 58 … ✓12 ✗0 SKIP0 · ✓ 58 signal-gate 全绿（66 行 ✓）
  == 选段结果 ==  ✓ 428  ✗ 0        B_RC=0

$ bash skills/teamsmith/tests/flip-p168.sh
== flip-p168 结果 == ✓ 13  ✗ 0   四面都符合预期（车道绿 / 车道外红 / 变异红 / 还原绿）
```

- Verdict: pass。
- **自己跑的**：`openspec validate --all --strict`；容器内 `--select 58` 的 FAST 与非 FAST 两轮；
  `flip-p168.sh` 四面（宿主，脚本里不调 tmux：夹具本身 `unset TMUX TMUX_PANE TMUX_TMPDIR`、只用
  argv 记录桩）；harness 的车道路径核实。开发期我还在宿主上直接跑过一次 `signal-gate.sh`
  （它同样零 tmux 调用）用来迭代，最终结论以容器那两轮为准。
- **引用的**：PM 2026-10-02 的现场（合并树 `58` 段红、差异行带 `bg.log`；干净 main 克隆同一夹具绿）——
  我没有重跑 PM 的那次现场，只在副本里用同一形状复现（见下面翻转③）。
- **没跑的**：全套门禁（交付/复验/归档时跑）。`--select 58` 的选段器点名了 108 个没跑的段
  （0h、10c、26、31c、52 … ），按段规范这不算全套门禁。
- 第一次容器跑我按线程里那段命令（没挂主仓库 `.git`）跑出 `0d` 一条红
  （`找不到受检的 git 工作树`）——那是环境：linked worktree 的 `.git` 文件指向主仓库
  `.git/worktrees/dev`，容器里没挂它。补上 `-v <主仓库>/.git:<同一绝对路径>:ro` 后 0d ✓9 ✗0，
  上面的两轮结果就是修正后的命令。

## Flip evidence（defect-fix）

四面共用同一个写入窗口：夹具建出自己私有根里的 `logs/` 之后再写。源码顺序是
`REAL_BEFORE` 快照（第一段之前）→ … → `LOGD=mkdir -p logs` → RA1/RA2 → `REAL_AFTER` 快照，
所以写入必然夹在两个快照之间；写入后夹具还跑了 499 ms（日志里每次打印实测值）。
四面日志在 `docs/team/reports/P168-dev/logs/`。

```
① 车道绿（修好后的排除面 + 跑动中追加 state/bg.log）
   夹具 rc=0；写入后夹具又跑了 499 ms
   ✓ 真实仓库 state/ 前后一致（排除后台作业车道 bg/ 与 bg.log）        # 整段零 ✗
   ✓ 写入确实发生了（state/bg.log 非空）

② 车道外红（跑动中写 state/other.log —— 证伪「排除面什么都放过」）
   夹具 rc=1
   ✗ 真实仓库 state/ 前后一致（…）（期望 [sentinel.txt 10 …]，实际 [other.log 52 …

③ 变异红（把副本的 BG_LANE_PATHS 改回修复前的 (bg) → 同样的写入）
   夹具 rc=1
   ✗ 真实仓库 state/ 前后一致（…）（期望 [sentinel.txt 10 …]，实际 [bg.log 66 …
   ✗ 形状：并发车道里的路径还是进了快照（排除面漏了：bg.log … other.log … sub/keep.txt …）

④ 还原绿（清单写回 (bg bg.log) → 同样的写入又绿）
   夹具 rc=0；✓ 真实仓库 state/ 前后一致（排除后台作业车道 bg/ 与 bg.log）；整段零 ✗
```

读法：**③ 就是修复前的排除面**（`sed` 只改那一行，锚点改前改后都断言过），它带 `bg.log` 的差异行
红得和 PM 的现场同形；**①/④ 是同一写入在修好后绿**。③ 也顺带证明 ① 的写入确实落在窗口里 ——
若写入落在窗口外，③ 不可能红。`outside-red.log` 里的差异行点名 `other.log`，证明排除面没有放宽。

## Decisions and deviations

- 新增 `tests/flip-p168.sh` 作为跑动中写入的驱动（brief 要求红侧两条，需要一个外层夹具）；
  没有改 `smoke.sh`（58 段的段内断言计数随夹具增加而增加，不是断言）。
- 签名扫描改成在 `state_snapshot` 的文件列表上 grep（原来是第二条 `find`）：排除面单一来源，
  顺带把车道从签名扫描里也排除掉（车道内容由 runner 并发写，不归夹具）。
- 车道清单是数组 + 一行 `find` 判据编译，而不是写死两条 `-path`：为了翻转脚本能**只改一行**
  回到修复前的形状（锚点 `^BG_LANE_PATHS=(bg bg.log)$` 有前置断言）。
- `BG_LANE_PATHS` 之外没有新增任何排除项（`state/panel.log`、`m36-*.log` 这些既有文件照旧进快照）。

## Suggested next steps

- PM 复验：`--strong` 建议直接看 `flip-p168.sh` 的四面 + 段尾三条 lane-shape 断言；独立复现时容器命令
  记得挂主仓库 `.git`（否则 0d 会给你一条与环境有关的红）。
- 归档顺序：本任务与 `safe-signal-discipline` / `signal-gate-pgrep` 无关（`change: -`，anchor: infra），
  不牵动 D87 的依赖链。
