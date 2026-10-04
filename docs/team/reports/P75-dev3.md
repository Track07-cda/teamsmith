# P75 · `team status` 尾部现场：成片空行把画面吃光（P65 的 F1）· **apply** · dev3

agent: dev3   status: **DONE**
time: 2026-09-22T19:11Z（全套门禁口径）
branch: `task/P75-p75`（local 模式：**不 push**，分支留给 PM）
change: `-` ｜ specs/anchor: `none (infra) — 修正读取器对既有文件来源的呈现，不改契约` ｜ deltas: `-`
grant 内改动: `skills/teamsmith/scripts/lib/cmd-status.sh` · `skills/teamsmith/tests/smoke.sh`（append-only）·
`skills/teamsmith/references/troubleshooting.md`（一句）
证据包: `docs/team/reports/P75-dev3/`（`repro.sh` 可重跑；`logs/` 是原始输出）

**总结论**：`team status <ID>` 的第三层来源（`state/dispatch-<agent>-tail.txt`）不再按字面取最后 N 行，
而是**先裁掉末尾空行、再取最后 N 行**（中间的保留）；声明改成「最后 N 行（去尾空行）」。
一份「4 行内容 + 5 行尾空行」的 tail 文件在 `TEAM_AGENT_SCENE_LINES=3` 下，从
「来源在但没有画面内容」变成 3 行内容（翻转见 §3）。只有空行 → 明说「来源里没有可读内容——没有非空行」；
非空行不足 N → 给现有的全部。第一层（活遗体 pane）与第二层（`dispatch-<agent>-pane-dead.txt`）的输出与
语义未被带改（§5 有三条回归断言 + 全量里既有的 P55 段）。

## 1 · 交付物

```
skills/teamsmith/scripts/lib/cmd-status.sh        team_status_tail_scene()（新读取器）+ 第三层分支的声明/空措辞
skills/teamsmith/tests/smoke.sh                   §43：17 条断言（绿侧 / 两个边界 / 默认口径回归 / 影子红侧 / 第一·第二层）
skills/teamsmith/references/troubleshooting.md    §11b 一句话：尾屏来源读的是「去尾空行后的最后 N 行」
docs/team/reports/P75-dev3/                       repro.sh（红绿可重跑）+ logs/（原始输出）
```

commits（小步，各带 `Task: P75` / `Agent: dev3`）：

- `c8cc375f` — `fix(P75): trim trailing blank lines when reading the dispatch tail scene`（实现）
- `99240067` — `test(P75): smoke §43 pins the tail-scene reader …`（测试 + 文档一句）
- 报告提交 — `docs(P75): apply report + reproducible flip evidence`（本文件 + `P75-dev3/` 证据包；分支 tip）

## 2 · 现场与根因

P65 的 F1（`docs/team/reviews/P65.md` 第 2 条）：第三层来源是 harness 在 agent 退出那一刻用
`tmux capture-pane -p -t "$TMUX_PANE" -S -200` 抓的原样落盘（`cmd-agents.sh:895` 的窗口 harness）。
capture 覆盖整屏 + 历史，末尾是 pane 下半屏的成片空行；旧读取器是字面取值：

```sh
scene="$(tail -n "$n" "$f" 2>/dev/null)"     # cmd-status.sh，第三层分支（改前）
```

`n=3` 时最后三行就是空行 → 命令替换把换行吃掉 → `scene` 为空 → 打「来源在但没有画面内容」。
默认 40 行时行数够多，症状被掩盖（P65 也是这样观察到的）。第一层（`team_agent_corpse_scene`）早就
有等价的尾空行裁剪；第二层存盘时走的是同一个 `team_agent_corpse_scene`，所以它们的语义本来就没有这个问题。

## 3 · 翻转证据（红 → 绿）

同一份夹具、同一个命令，只换读取器：红侧用 `c8cc375f^`（修复前提交）的 `cmd-status.sh` 装进一份 skill 副本
（`repro.sh` 用 `git show <prefix>:…` 还原，不动当前树）。完整输出 `logs/10-flip.txt`：

```sh
$ bash docs/team/reports/P75-dev3/repro.sh
--- 夹具 tail 文件（cat -A，末尾 5 行空行）---
  P75-MARK-1$
  P75-MARK-2$
  P75-MARK-3$
  P75-MARK-4$
  $ $ $ $ $                      # 5 行空行

==== 修复前（c8cc375f^ 的 cmd-status.sh）：SCENE_LINES=3 ====
  座位 p75w：无窗口
  现场：（来源在但没有画面内容）来源=…/dispatch-p75w-tail.txt（agent 退出时 harness 自抓的尾屏）   ← 红侧：画面被空行吃光

==== 修复后（当前树）：SCENE_LINES=3 ====
  座位 p75w：无窗口
  现场（来源：…/dispatch-p75w-tail.txt（agent 退出时 harness 自抓的尾屏） · 记录时间：… · 最后 3 行（去尾空行））：
    | P75-MARK-2
    | P75-MARK-3
    | P75-MARK-4                                                       ← 绿侧：3 行内容
```

红侧的第二条路（可证伪的**回归**守卫）在 smoke §43 ⑤：不改产品开关，把 `team_status_tail_scene` 影子成
旧的字面 `tail -n N`，同一份夹具**逐字**翻回「来源在但没有画面内容」（`logs/20-smoke-fast.txt` 里 §43 那两行）。

## 4 · 验收命令与结果

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 26 passed, 0 failed (26 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2447  ✗ 0
smoke 全绿
（§43 的 17 条全绿；跳过 32 个真进程段落 —— 本段是纯逻辑，FAST 里照跑）

$ bash skills/teamsmith/tests/smoke.sh </dev/null        # 交付前的全量（排队 18 分钟后开跑，共 2103.7s）
== 结果 ==  ✓ 3091  ✗ 0
smoke 全绿
rc=0
```

§43 的 17 条在两套里都绿；第一/第二层的既有回归也在全量里绿 —— P55 §41 真 tmux 段的
`P55 ④：现场块标注来源`、`P55 ④：TEAM_AGENT_SCENE_LINES=2 → 恰好两行现场`（第一层）、
`P55 ⑤A·dispatch / ⑤B·--fresh / ⑤C·resume：TEAM_AGENT_SCENE_LINES=3 → 现场恰好三行`（第二层存盘/回读）都在。
P65 F3 里那条**已知**红 `12b-j`（P73，别的工作树把夹具 payload 写进真 state 日志）**本次两套都没出现**
（FAST ✗0、全量 ✗0）—— 没有需要与本单区分的既有红。

## 5 · 边界与不回退

- **① 只有空行**：`logs/…` 里 smoke §43 ③ —— 输出点名「来源里没有可读内容——没有非空行」，画面行数 0
  （不是静默空块）；措辞与「有非空行但取窗为空」（`TEAM_AGENT_SCENE_LINES=0` 或读时文件被改写）的
  「来源在但没有画面内容」是分开的两句。
- **② 行数不足 N**：§43 ② —— 2 行内容 + 3 行尾空行、N=3 → 给现有的 2 行。
- **③ 第一/第二层不改语义**：
  - 第二层：§43 ⑥ 用一份 `dispatch-p75w-pane-dead.txt` 夹具断言声明仍是「最后 3 行）：」（无「去尾空行」后缀）
    且内容仍是既有语义的最后 3 行，并且它优先于第三层。
  - 第一层：唯一实现在 `team_agent_corpse_scene`（未改）；既有 smoke §41（P55）在**全量**里断言
    `TEAM_AGENT_SCENE_LINES=2 → 恰好两行现场` 与来源/记录时间行，本次全量绿（§4）。
  - 空分支的默认措辞保留给第一/第二层（`empty_note` 为空 → 原句），所以它们同一输入的输出逐字不变。
- **默认 40 行**：§43 ④ —— 4 行内容 + 尾空行、不设旋钮 → 4 行内容一字不少。

## 6 · 残留与归属

- 另一个读 tail 文件的地方是启动失败诊断（`team_dispatch_launch_diag`），它走 `team_pane_tail_normalize`
  （本来就丢空行、留前 30 行非空），与本单无关，未动。
- `TEAM_AGENT_SCENE_LINES=0` 的定义保持「取 0 行」：有内容的文件会落进「来源在但没有画面内容」——
  与新措辞的分工一致（「没有可读内容」只描述文件本身没有非空行）。
- 无 `BLOCKED`。
