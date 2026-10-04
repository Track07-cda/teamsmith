# P94 · `TEAM_AGENT_SCENE_LINES=0` 的边界：按配置不打印现场块（P88 的 F1）· **apply** · dev2

agent: dev2   status: **DONE**
time: 2026-09-23T02:00Z（openspec + FAST + 全量 smoke 三套都跑完）
branch: `task/P94-scene-lines-0`（local 模式：**不 push**，分支留给 PM）
change: `-` ｜ specs/anchor: `none (infra) — 修 SCENE_LINES=0 的边界语义，不改既有现场来源` ｜ deltas: `-`
grant 内改动: `skills/teamsmith/scripts/lib/cmd-status.sh` · `skills/teamsmith/tests/smoke.sh`（append-only）·
`skills/teamsmith/references/troubleshooting.md`（一句）
证据包: `docs/team/reports/P94-dev2/pkg/run.sh`（与 smoke 夹具**不复用**：自建 scratch 仓库 + 自带的
560 KB 夹具 + 私有 tmux socket；可重跑，原始输出在 `docs/team/reports/P94-dev2/logs/`）

**总结论**：`TEAM_AGENT_SCENE_LINES=0` 有了**显式语义** —— 按配置不打印现场块：rc=0、一行
`现场：（按 TEAM_AGENT_SCENE_LINES=0：不打印画面）`，三个现场来源一个都不读。旧实现的
`tail -n 0` → SIGPIPE → `pipefail` → **rc=141 中止**（P88 的 F1）不再出现。`n>=1` 一分不动
（1/3/40 与既有断言逐字相同）。门禁加了 §48：22 条断言 + append 突变红侧（旧形状在同夹具上
翻回 rc=141）。

## 1 · 交付物

```
skills/teamsmith/scripts/lib/cmd-status.sh    team_seat_scene_zero_note()（新守卫）
                                              team_status_tail_scene() 的 N=0 护栏（同族兜底）
                                              team_seat_scene_print() 在选来源之前调用守卫
skills/teamsmith/tests/smoke.sh               §48：22 条断言（绿侧 / 1·3·40 回归 / append 突变红侧 / 第二层）
skills/teamsmith/references/troubleshooting.md §11b 一句话：0 = no scene block by configuration
docs/team/reports/P94-dev2/                    pkg/（lib.sh + run.sh + 5 节 + 2 探针）+ logs/（原始输出）
```

commits（小步，各带 `Task: P94` / `Agent: dev2`）：

- `cb94c55a` — `fix(P94): give TEAM_AGENT_SCENE_LINES=0 an explicit "no scene block" meaning`（实现）
- `1941fea9` — `refactor(P94): extract the zero-note guard into team_seat_scene_zero_note`（可测的守卫）
- `1d61fe94` — `test(P94): smoke §48 pins TEAM_AGENT_SCENE_LINES=0 (note, rc=0, nothing read)`（测试 + 文档一句）
- `832e64ab` — `docs(P94): independent evidence package (pre-fix red side, boundaries, mutant, isolation)`（证据包）
- 报告提交 — `docs(P94): apply report`（本文件；分支 tip）

## 2 · 现场与根因（P88 的 F1）

P88 复验（`docs/team/reviews/P88.md` 的 F1，我这边同一形状复现）：`TEAM_AGENT_SCENE_LINES=0` +
560 KB 的 `state/dispatch-<agent>-tail.txt` → `team status <ID>` **rc=141**、席位段的现场块不出来。

机理（`cmd-status.sh` 第三层来源的读取器）：

```sh
awk '{ … }' "$f" | tail -n "$n"      # n=0 时 tail 立刻退出、什么都不读
```

`tail -n 0` 不读输入就退出 → awk 的写端吃 **SIGPIPE**（输出量远超管道缓冲）→ 调用链是
`set -euo pipefail`（`scripts/team:13`）→ **rc=141 中止**，而不是「显示 0 行」。同族先例：P28 的
`printf | grep -q`。三个来源的读取管道末尾都有这个 `tail -n "$n"`（第三层 `team_status_tail_scene`、
第二层的 `sed … | tail -n +2 | tail -n "$n"`、第一层 `team_agent_corpse_scene` 的
`tmux capture-pane | … | tail -n …`），所以修点在**选来源之前**，不在某一条来源里。

## 3 · 修法与边界

1. `team_seat_scene_zero_note "<N>"`（新助手）：`0` → 打印显式措辞并让调用方**直接返回**
   （三个来源一个都不读）；非 0 或非数字 → 返回 1，调用方照旧选来源。判定是**数值**（`-eq 0`），
   所以 `00` 也同 0。
2. `team_status_tail_scene` 自己的 N=0 护栏：空输出、不建管道（为将来的调用者兜底；
   原位注释里「N=0 也走空块」的说法已删）。
3. **不改** `n>=1`：尾空行裁剪、不足 N 给全部、只有空行说 `来源里没有可读内容`、第一/第二层的
   声明与语义 —— 全部逐字不变（§48② + P75 §43 既有断言）。
4. 只动 grant 列的三条路径；`cmd-agents.sh`（第一层函数与 dispatch 遗体留证）**未动**。

## 4 · Flip evidence（红 → 绿）

同一份夹具（560 KB 尾屏 + 无窗口席位，`TEAM_AGENT_SCENE_LINES=0`）、同一个 CLI，只换被测树。
完整输出：`docs/team/reports/P94-dev2/logs/run-full.log`（§10 红前 / §20 绿后 / §40 突变）。

**Red before**（真实的历史前身：`cb94c55a^`，即本分支基点 `99bcc29a` 的 `cmd-status.sh`）：

```
$ bash docs/team/reports/P94-dev2/pkg/run.sh 10
ok   pre-fix 读取器取到（cb94c55a…^:skills/teamsmith/scripts/lib/cmd-status.sh）
ok   红前：TEAM_AGENT_SCENE_LINES=0 → rc=141（tail -n 0 → SIGPIPE 中止）（141）
ok   红前：没有显式措辞
ok   红前：现场块一行都没有（0）
== 10 · 红前（pre-fix blob） 结果 == ok=5 bad=0 finding=0 skip=0
```

**Green after**（当前树）：

```
$ bash docs/team/reports/P94-dev2/pkg/run.sh 20
ok   绿后：0 → rc=0（0）
ok   绿后：显式措辞点名配置
ok   绿后：一行画面都不打印（0）
ok   绿后：来源里的内容一个字都不出现
ok   绿后：不是「取最后 0 行」的空块措辞
ok   绿后：连来源行都没印（读取器没被走到）
  · 绿后席位段：
        座位 p94w：无窗口
        现场：（按 TEAM_AGENT_SCENE_LINES=0：不打印画面）
ok   绿后：n=1 rc=0（0）
ok   绿后：n=1 = 最后 1 行（逐字节）（P94-TAIL-MARK-LAST）
ok   绿后：n=3 rc=0（0）
ok   绿后：n=3 = 最后 3 行（逐字节）（…P94-PAD-07999 / 08000 / P94-TAIL-MARK-LAST）
ok   绿后：n=40 rc=0（0）
ok   绿后：n=40 = 最后 40 行（逐字节）（…）
ok   绿后：默认（不设旋钮）rc=0（0）
ok   绿后：默认 40 行 = 最后 40 行（逐字节）（…）
ok   绿后：默认声明照旧（P75 的措辞）
== 20 · 绿后（当前树） 结果 == ok=15 bad=0 finding=0 skip=0
```

**门禁内的翻转（§48③，不靠历史提交）**：把当前树的 skill 副本 append 两行覆盖
（P94 之前的读取器管道 + `team_seat_scene_zero_note() { return 1; }`，原件部分逐字节未改）→
同一发命令翻回旧形状：

```
  ✓ P94 ③ 突变夹具：只多出 4 行覆盖（append；原件部分逐字节相同）
  ✓ P94 ③ 翻转：旧形状下同一发命令回到 rc=141（tail -n 0 → SIGPIPE 中止）
  ✓ P94 ③ 翻转：显式措辞消失（status 在席位段中止）
  ✓ P94 ③ 翻转：mutant 的现场块一行都没有
```

## 5 · 验收命令与结果

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 30 passed, 0 failed (30 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 48 · P94 现场行数为 0：按配置不打印画面（P88 的 F1） ==
  ✓ P94 ①：TEAM_AGENT_SCENE_LINES=0 → rc=0（旧实现 rc=141 SIGPIPE 中止，P88 的 F1）
  ✓ P94 ①：显式措辞点名配置
  …（§48 共 22 条，全绿）
== 结果 ==  ✓ 2734  ✗ 0
smoke 全绿

$ bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前的全量（00:41 排队，01:41 开跑，02:00 结束）
== 结果 ==  ✓ 3400  ✗ 0
smoke 全绿
SMOKE_EXIT=0

§48 的 22 条在全量里同样全绿；既有回归也在：`P55 ④：现场块标注来源`、
`P55 ④：TEAM_AGENT_SCENE_LINES=2 → 恰好两行现场`（第一层真 pane）、
`P55 ⑤A/B/C：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行`（第二层存盘/回读）、P75 §43 全节。
原始日志：`docs/team/reports/P94-dev2/logs/gate-fast.log` · `logs/gate-full.log`。

$ bash docs/team/reports/P94-dev2/pkg/run.sh
sections: 10-red-before 20-green-after 30-boundaries 40-mutant-and-isolation 50-observation-corpse-capture  ok=47 bad=0 finding=1 skip=0
== run 结果 == ok=47 bad=0 finding=1 skip=0  →  PASS
```

§48 的 22 条在 FAST 与全量里都跑（纯逻辑，无真进程），两套都全绿；P55 §41 / P75 §43 的
既有现场断言在两套里照旧。

## 6 · 边界与残留

- **`n=0` 的三个来源**：守卫在选来源之前返回，所以第一层（活遗体 pane）也不读 —— §48④ 用
  第二层在场的夹具钉住「来源不同也同一条路」；第一层的函数本身未改，P55 的真 pane 段在 `n>=1`
  下照旧（全量里跑）。
- **同族残留（finding，不计 P94 验收）**：`team_agent_capture_corpse`（`cmd-agents.sh`，**未授权改**）
  在 API 口径（`pipefail`）下 N=0 会写下一个只有头部 + `--- scene ---` 的留证文件并**报 rc=1、
  不回路径**。它**不会中止** dispatch（调用点有 `|| true`，只是一句 warning 里少了「现场已存 …」），
  所以不是 P88 的 F1 形状。可复现：`pkg/run.sh 50`（`find 遗体留证 N=0：rc=1、不回路径（capture rc=1
  printed_path=[] file bytes=130 scene_lines=0 header=1）`）。归属：`cmd-agents.sh` 是 PM 目录，
  要不要顺手给它加同样的 0 守卫由 PM 决定。
- 无 `BLOCKED`；没有碰别的工作树 / 别的项目。
