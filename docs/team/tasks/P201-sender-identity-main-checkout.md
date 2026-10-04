# P201 · 发送者身份：在**主检出**里工作时，席位的会话线索不许被静默当成 `pm`

```
task:   P201
agent:  dev2
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 只改发送者解析与其红侧/文档
deltas: -
grant:  skills/teamsmith/scripts/lib/common.sh · skills/teamsmith/scripts/lib/cmd-agents.sh · skills/teamsmith/references/** · skills/teamsmith/tests/** · docs/team/reports/P201-dev2.md · docs/team/reports/P201-dev2/**
deps:   P155 的诊断（`docs/team/reports/P155-dev2.md` ✓）· **PM 读码确认** ✓：`common.sh:653-666` 的 `team_sender_from_dir`
        在 `root == main` 时**直接** `printf 'pm'` ✗ —— **完全不看**会话/窗口线索 ✗ → 席位在主检出里发的通知被记成 `agent:pm` ✗（零告警 ✗，且与合法场景**逐字节相同** ✗）· P72/P93（身份实现与验证 ✓）· M40（运行时目录优先 ✓，但那是**读/状态**命令的规矩 ✓）· P134（身份按"记录名并集" ✓ —— 会议侧已如此 ✓）
status: todo
budget: 小到中
priority: 中高（账本把**作者**记错 ✓ 会误导后续所有人 ✓；且它已经真实发生过 ✓）
```

## 现场（P155 实测 + 我读码）

| 场景 | 现在记成 |
|---|---|
| 从 `.worktrees/dev` 里 notify | `agent:dev` ✓ |
| **主检出**里 + **会话/窗口是 worker 的** | **`agent:pm`** ✗（rc=0 ✓、**零告警** ✗、输出与下面那条**逐字节相同** ✗） |
| 主检出里 + 无线索 | `agent:pm` ✓（合法 ✓） |

根因 ✓：`team_sender_from_dir` 在 `root == main` 时**直接返回 `pm`** ✗，**不看**任何会话线索 ✗。

## 要做的（**PM 的裁定**，照此实现）

1. **线索清单（写进文档 ✓）**：① 运行时目录（工作树 → 席位名 ✓）；② 窗口名（`tmux display-message -p '#{window_name}'` ✓，仅当它命中**本名册**的席位 ✓）；③ `TEAM_AGENT` ✓（继承来的 ✓，命中名册才算 ✓）。
2. **主检出 + 有席位线索 → 拒绝** ✗（不是猜 ✓）：rc 非 0 ✓ + 点名**两个名字** ✓（目录说 `pm` ✓ / 线索说 `dev` ✓）+ **两条出路**（`--from <你的名字>` ✓；或从自己的 worktree 里调用 ✓）。
   **理由**：账本记的是**作者** ✓；"目录赢"（M40）是给**读/状态**命令的规矩 ✓，用在**署名**上会把作者的活记成别人的 ✓。
3. **主检出 + 无线索 → `pm`** ✓（照旧 ✓，不许误伤 PM 自己的调用 ✓）；**显式 `--from` → 照旧接受** ✓（既有告警保留 ✓）。
4. **红侧（四条）** ✅：① 主检出 + 窗口 `dev` → **拒绝并点名两个名字** ✓；② 主检出 + `TEAM_AGENT=dev` → 同样拒绝 ✓；
   ③ 反向：主检出 + 窗口 `pm` / 无线索 → 照旧 `pm` ✓（不许误伤 ✓）；④ 影子：把"拒绝"改回"直接 pm" → ①②必须红 ✓。
5. **文档同步** ✓：`agent-adapters.md` 的身份一节写明线索清单与"冲突即拒绝" ✓（含上面两条出路 ✓）。
6. **门禁**：`openspec validate --all --strict` ✓ + 相关段 ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 P155" ✓；**复验换人** ✓。
