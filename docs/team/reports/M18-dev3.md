# M18 · cmd-status.sh:463 team_watchdog_state_text 未定义（P8 改名漏网）

agent: dev3   status: done   time: 2026-09-17T07:36Z
branch: `task/M18-cmd-status-sh-463-team-watch`   PR/MR: -（local 模式：不 push，分支留在 `.worktrees/dev3`，PM 复验后本地合并）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-status.sh:463` | `team_watchdog_state_text` → `team_pulse_state_text`（P8 改名后的函数，定义在 `cmd-watch.sh:1181`）；行内标签 `watchdog` → `pulse`（用法对齐 `cmd-project.sh:452`，未动别名兜底逻辑） |
| `skills/teamsmith/tests/smoke.sh`（第 7 节，首条 `team digest` 之后） | 三条回归断言：digest 输出不含 `command not found`；不含旧函数名 `team_watchdog_state_text`；`｜ pulse <非空白>` 状态字段非空。第 7 节在 FAST 与全量两种模式都跑，不加任何 fast/cond skip |
| `docs/team/reports/M18-dev3.md` | 本报告 |

两个提交（分支 tip = `97587cd`）：

```
0d1273d test(teamsmith): M18 assert digest never leaks the removed watchdog state fn
97587cd fix(teamsmith): M18 digest calls team_pulse_state_text, label pulse
```

## Verification evidence (must have actually been run)

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 13 passed, 0 failed (13 items)

$ bash skills/teamsmith/tests/smoke.sh            # 全量（不设 TEAM_SMOKE_FAST），07:31:39 → 07:36:09
== 结果 ==  ✓ 1827  ✗ 0
smoke 全绿   (rc=0)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1424  ✗ 0
FAST 模式：跳过 18 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿   (rc=0)

$ bash skills/teamsmith/scripts/team digest 2>&1 | grep -c 'command not found'
0
$ bash skills/teamsmith/scripts/team digest 2>&1 | sed -n '5p'
  agent 3/4 在跑 ｜ RAM 可用 7691MB ｜ 磁盘 swap 空闲 65535MB，zram 用 4%/物理 279MB ｜ 估算可再加 11 个 agent  PM ● 在运行（pi） ｜ pulse ● tmux 窗口 teamsmith:pulse 在跑
```

新断言在全量模式里的实际输出：

```
  ✓ M18：digest 里没有 command not found（P8 改名漏网）
  ✓ M18：digest 里没引到已删除的旧函数名
  ✓ M18：digest 的 pulse 状态字段非空
```

- Verdict: pass
- Notes:
  - `bash skills/teamsmith/scripts/team digest` 的 `rc` 修前修后都是 0（shell 的 `command not found` 只污染输出、不改退出码）——所以断言盯着输出文本，不盯退出码。
  - 修前状态字段是空串（`｜ watchdog ` 后面直接换行），只断言「没有报错」不够；加了「字段非空」这条，防止以后函数名对了但状态函数返回空。
  - 未验证项：无。`TEAM_SMOKE_FAST=1` 也覆盖了这三条断言（第 7 节不在 FAST 跳过名单里，见 `SMOKE_FAST` 自检 + 全量/快模式两次运行的同一行号 521–523）。
  - 只读命令未改运行时状态：`team digest` 前后未动 `.pi/team/state/`（未跑会被 M6.1 的 `state_fp` 断言挡住；全量 smoke 里那节全绿）。

## Flip evidence (required for defect-fix tasks)

**① 修前红（断言先加、实现未改）** —— `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh`：

```
  ✗ M18：digest 里没有 command not found（P8 改名漏网）（不该出现 [command not found]）
  ✗ M18：digest 里没引到已删除的旧函数名（不该出现 [team_watchdog_state_text]）
  ✗ M18：digest 的 pulse 状态字段非空（…/digest.log 中没有匹配 [｜ pulse [^[:space:]]]）
== 结果 ==  ✓ 1421  ✗ 3      (rc=1)
```

同一时刻真实仓库的 digest 报错行（修前）：

```
  agent 3/4 在跑 ｜ … ｜ 估算可再加 11 个 agent  PM ● 在运行（pi）/…/skills/teamsmith/scripts/lib/cmd-status.sh: line 463: team_watchdog_state_text: command not found
 ｜ watchdog 
```

**② 修后绿** —— 三条断言全 `✓`（见上），全量 1827 ✓ / 0 ✗、FAST 1424 ✓ / 0 ✗。

**③ 不是剧场：把实现临时改回旧名 → 断言必须红** —— `sed` 只改第 463 行回退成 `｜ watchdog %s` / `team_watchdog_state_text`，跑 FAST：

```
$ sed -n '463p' skills/teamsmith/scripts/lib/cmd-status.sh
  printf ' ｜ watchdog %s\n' "$(team_watchdog_state_text)"
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
  ✗ M18：digest 里没有 command not found（P8 改名漏网）（不该出现 [command not found]）
  ✗ M18：digest 里没引到已删除的旧函数名（不该出现 [team_watchdog_state_text]）
  ✗ M18：digest 的 pulse 状态字段非空（…/digest.log 中没有匹配 [｜ pulse [^[:space:]]]）
== 结果 ==  ✓ 1421  ✗ 3      (rc=1)
$ git checkout -- skills/teamsmith/scripts/lib/cmd-status.sh   # 还原
$ sed -n '463p' skills/teamsmith/scripts/lib/cmd-status.sh
  printf ' ｜ pulse %s\n' "$(team_pulse_state_text)"
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
== 结果 ==  ✓ 1424  ✗ 0      (rc=0)
```

失败面正好是这三条（1421 ✓ / 3 ✗，没有连带红），说明断言直接钉住被修的行为。

## Decisions and deviations

- 报告路径按派单提示写 `docs/team/reports/M18-dev3.md`（任务书正文写的是 `M18-dev.md`；本任务已改派给 dev3，`team review M18` 按 `reports/M18-*.md` 取候选，两者都能命中）。以派单提示为准。
- 断言多做了一条「不含旧函数名」：`command not found` 依赖 shell 错误文案，如果将来给旧名补了兜底（v2.0.0 之前不允许，见任务书 Boundaries），光靠 `command not found` 会漏掉「又接回旧名」这种回归。三条断言一起钉住「不报错 / 不接旧名 / 字段非空」。
- 其余按任务书：只改这两个文件 + 本报告；`cmd-watch.sh` 的 5 个 `team_watchdog_*` 兼容别名（1333–1337 行）一字未动。
- 顺带核查：`grep -rn 'team_watchdog_' skills/teamsmith/scripts/` 现在只剩上述 5 个有定义的别名，没有其他未定义旧名的调用点。

## Suggested next steps

- PM 复验：独立 checkout 上跑 `openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`；本分支 `97587cd` 已含实现 + 断言，可直接本地合并。
- 建议合并在 P14/V16 之后（本改动与 pulse-console 无交集，只是同一文件行号在并行改动里有轻微冲突可能：`cmd-status.sh:463`）。
- 长期（v2.0.0 清理别名时）：把 `cmd-watch.sh` 的 5 个 `team_watchdog_*` 别名一起删掉，并给 smoke 加一条「旧 CLI 名已下线」的断言。
