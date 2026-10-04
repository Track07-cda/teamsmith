# P8 · dev2 · apply report: change `rename-watchdog-to-pulse`

```
task:   P8                        phase:  apply       deps: P7 proposal review ACCEPTED (docs/team/reviews/rename-watchdog-to-pulse-proposal.md)
agent:  dev2                      status: DELIVERED
branch: task/P8-apply-rename-watchdog-pulse-          PR/MR: - (local mode, no remote)
```

> **Gates are green on tip `3e104d4`** (the code/test tip; the report commit only adds `docs/team/reports/**` and
> the last `tasks.md` ticks): `openspec validate --all --strict` → `11 passed, 0 failed`;
> `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` → rc 0, **✓ 1106 ✗ 0**;
> `bash skills/teamsmith/tests/smoke.sh` (full) → rc 0, **✓ 1407 ✗ 0**, zero SKIP, including the real-process
> migration fixtures in §11j. The tasks' third historical gate (`spec-lint.sh`) no longer exists — removed in
> v1.35.0 with change `drop-spec-lint`; the brief's gate section (`openspec validate --all --strict` + smoke,
> matching `.pi/team/config.sh:TEAM_GATES`) governs.

## What shipped (tasks.md 1.1 → 6.2, all ticked)

One commit per verifiable step; branch log:

```
3e104d4 fix(teamsmith): P8 — watch 循环的 INT/TERM trap 不再吞信号（后台 sleep+wait，handler exit 走 EXIT 解锁）
cbcda60 fix(teamsmith): P8 — smoke 锁测试去竞态（exec+等锁+timeout 兜底）；修 watch_lock 反引号消息的历史执行 bug
3d1afe4 docs(teamsmith): P8 别名说明行同排带 alias/deprecated 词（5.1 验证器按行过滤）
4729513 test(teamsmith): P8 smoke — pulse 改名断言 + 别名/优先级/迁移夹具段 11j（D22 翻转证据）
ec71e0e docs(teamsmith): P8 rename watchdog->pulse in SKILL.md, references, templates; CHANGELOG v1.36.0 with migration notes
04a171d feat(teamsmith): watchdog 改名 pulse —— 命令组/窗口/TEAM_PULSE_* + 别名期兼容 (P8)
8ff5be3 openspec(team): P7 design + ordered tasks for the pulse rename        (cherry-pick from P7 branch)
9079f5d openspec(team): P7 proposal + watchdog delta for the pulse rename     (cherry-pick from P7 branch)
```

| tasks.md | Delivered | Evidence |
|---|---|---|
| 1.1 command group + aliases | `team_cmd_pulse*` are the implementation; `watchdog`/`watchdog-status`/`install-watchdog`/`uninstall-watchdog` are thin wrappers whose stdout **first line** is exactly `[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）`, body byte-identical to the pulse output; internal callers (`cmd-bootstrap`, `cmd-update`) call pulse functions directly and print nothing. `git grep -n 'team_cmd_watchdog' -- skills/` shows only the wrappers + dispatch lines | smoke §11j 别名断言 ×13 |
| 1.2 window resolution | `team_pulse_window()` = `TEAM_PULSE_WINDOW` → `TEAM_WATCH_WINDOW` → `pulse`; `team_pulse_legacy_window()` probe backs status/logs/state, makes `up` refuse to start a second patrol and name `team pulse restart`, `down`/`restart` reap both names, `restart` leaves exactly one `pulse` window | smoke §11j fixtures A/B（真 tmux）×10 |
| 2.1 env resolver | `team_pulse_var NAME default` in `lib/common.sh` — single point of precedence `TEAM_PULSE_*` > `TEAM_WATCH_*` > default; `team_load_config` fills the six `TEAM_PULSE_*` keys from it and records legacy fallbacks in `TEAM_PULSE_LEGACY_USED`; every reader (watch, monitor tick, paths, doctor, up/down routing) uses the resolved value; `pulse status`/`up --print`/doctor name each legacy variable in effect | smoke §11j 优先级断言 ×8 |
| 2.2 nudge + panel | nudge text `[pulse] 待办：…`; panel header `teamsmith pulse · …`; panel/footer hints name `team pulse …` | smoke §11b live nudge + §14 面板断言 |
| 2.3 state files | patrol still writes `state/watchdog.log|pid|last|nudge|tick.log` + `capacity.log`; creates no `state/pulse.*`; two concurrent watch loops still refuse via the one `watchdog.pid` | smoke §11j state 断言 ×3 + 锁断言 ×3 |
| 3.1 paths | `team paths` gains `"pulse_window"` (resolved) + `"pulse_interval"` (effective seconds); every existing key kept. `team paths \| python3 … assert d["pulse_window"] and d["pulse_interval"]` ✓（本仓库真实配置仍写旧名 → 打印 `watchdog 900`，顺带实证了真实项目上的兜底路径） | smoke §11j ×4 |
| 3.2 doctor | backend line named `pulse`; legacy variables in effect are named（`旧变量生效：TEAM_WATCH_INTERVAL=17（→ TEAM_PULSE_*）`） | smoke §11j ×2 |
| 3.3 help/bootstrap | help lists `pulse up\|down\|restart\|status\|logs` + deprecation note; bootstrap plan/next-steps/`--print` use `pulse` wording; `--no-watchdog` stays accepted (hidden) | smoke §11j ×2 + §2 bootstrap ×2 |
| 4.x tests/gates | smoke §11j new section (alias contract, precedence, state invariants, paths/doctor, lock, **migration sandbox**: legacy-config fixture A and legacy-window fixture B, all `[real]` under tmux with headless counterparts); all pre-existing `watchdog`→`pulse` assertion updates; full + FAST gates green | this report §Flip |
| 5.x docs/templates | SKILL.md（description/table/patrol 段/troubleshooting 指针）、6 份 references（config 含六键优先级表、migration §2b 迁移步骤与「state 文件名保持到 v2.0.0」、protocol/workflows/troubleshooting/bootstrap/philosophy/memory/agent-adapters）、6 份 templates（config.sh.tmpl 写新名+旧名注释） | 5.1/5.2/5.3 的 grep 验证全部通过（见下） |
| 6.x CHANGELOG/version | v1.36.0 entry（改名 + 别名期到 v2.0.0 + 状态文件不动 + 迁移两步）；`TEAM_VERSION` 与 SKILL.md `metadata.version` 同步 bump；`team version --check`：磁盘/SKILL/CHANGELOG 三者 1.36.0 一致 | `version --check` 输出见下 |

## Deviation 1 — change artifacts came from the P7 branch (dispatch precondition)

This worktree was created from `main` (`e0e8ddf`), but the change `openspec/changes/rename-watchdog-to-pulse/`
lives only on `task/P7-propose-rename-watchdog-to-p` (accepted, not merged). Per the apply-on-propose-tip
convention I cherry-picked P7's two openspec commits (`9079f5d`, `8ff5be3`, authorship preserved) onto my branch
instead of re-creating the files. No other branch touched; nothing force-anything.

## Deviation 2 — version is 1.36.0, not tasks.md 5.4's "1.32.0"

tasks.md was drafted when the repo was < 1.32; `main` is already at **1.35.0**. Bumping to 1.32.0 would be a
regression, so the entry and both version stamps use **1.36.0**; the alias horizon (`until v2.0.0`) and every other
word of 5.4 are unchanged. Flagging here so the PM can amend tasks.md wording at archive time if desired.

## Found and fixed on the way (pre-existing bugs my new test exposed)

1. **`team watch` could not be stopped** (`cbcda60`→`3e104d4`): `trap 'team_watch_unlock' EXIT INT TERM` made bash
   finish the foreground `sleep` before running the handler, then **resume the loop after unlocking** — Ctrl-C and
   `kill` were both ineffective (the header even promises "Ctrl-C 退出"). Fixed with the standard pattern
   (`sleep & wait` so a trapped signal interrupts immediately; `trap 'exit 130' INT` / `trap 'exit 143' TERM`;
   unlock stays in the EXIT trap). smoke §11j now asserts a watch loop dies within 5 s of TERM.
2. **Backticks executed inside the lock-refusal message** (`cbcda60`): `team_err "…停止它：\`team watchdog status\`…"`
   ran the command (or printed `team: command not found`) while composing the error. Now escaped, matching the
   codebase convention. Pre-existing (introduced by c6cac20), not caused by the rename.
3. **My own lock test had a startup race** (`cbcda60`): `sleep 1.5` bet that loop #1 had grabbed the lock; on a
   loaded box loop #2 wins, patrols forever and the whole smoke hung — this actually happened twice (two full runs
   died at the same point, one after 25 min, one after 40 min). Fixed: `exec` so `$!` *is* the patrol pid, poll for
   the lock file (≤10 s), `timeout 30` around the second loop so a lock regression goes red instead of hanging.

## Flip evidence (tasks.md 4.1: "fail when the deprecation line is broken — flip by hand once")

Broke the alias deprecation line in `lib/cmd-watch.sh:662`
(`printf '[deprecated] team watchdog 已改名 team pulse（别名保留到 v2.0.0）\n'` → `printf 'team watchdog 已改名 team pulse\n'`):

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # rc=1
  ✗ `watchdog-status` stdout 首行是弃用提示（期望 [[deprecated] …]，实际 [team watchdog 已改名 team pulse]）
  ✗ `watchdog status` stdout 首行是弃用提示（期望 …）
  ✗ `watchdog` stdout 首行是弃用提示（期望 …）
  ✗ `install-watchdog --print` stdout 首行是弃用提示（期望 …）
  ✗ `uninstall-watchdog --print` stdout 首行是弃用提示（期望 …）
== 结果 ==  ✓ 1101  ✗ 5
```

Exactly the five alias first-line assertions went red, nothing else. Restored the line (working tree byte-identical
to the committed tip, `git diff` empty), re-ran FAST: rc 0, **✓ 1106 ✗ 0**. Full logs: `/tmp/p8-flip.log` (red),
`/tmp/p8-fast4.log` (restored green), `/tmp/p8-full4.log` (full green), `/tmp/p8-fast3.log` (pre-flip green).

## Acceptance commands (brief §验收) — real runs

```
$ openspec validate --all --strict                 # rc=0
✓ change/rename-watchdog-to-pulse
✓ spec/watchdog
Totals: 11 passed, 0 failed (11 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh        # rc=0
== 结果 ==  ✓ 1106  ✗ 0
FAST 模式：跳过 14 个真进程段落（…|11j·pulse 迁移夹具）——完整门禁请不带 TEAM_SMOKE_FAST 重跑

$ bash skills/teamsmith/tests/smoke.sh             # rc=0（solo，无并发冒烟，约 7 分钟）
== 结果 ==  ✓ 1407  ✗ 0
smoke 全绿
```

Full-smoke §11j tail (the migration sandbox, real tmux):

```
  ✓ watch 循环被 TERM 收掉（trap 不再吞信号）
  ✓ 第二个 watch 循环被拒（同一把 watchdog.pid 锁）
  ✓ 拒绝说明点名已在运行的 pid
  ✓ 夹具 A：旧配置的项目窗口名保持 watchdog
  ✓ 夹具 A：旧命令名 stdout 首行是弃用提示
  ✓ 夹具 A：旧命令名看到旧窗口后端
  ✓ 夹具 A：pulse down 关掉旧名窗口
  ✓ 夹具 B：status 认出旧窗口后端
  ✓ 夹具 B：status 指 restart 迁移
  ✓ 夹具 B：up 指 restart（不另起窗口）
  ✓ 夹具 B：up 绝不开第二个巡检（没有 pulse 窗口）
  ✓ 夹具 B：pulse logs 对旧名窗口也能看（迁移前它也是后端）
  ✓ 夹具 B：restart 后恰好一个巡检窗口
  ✓ 夹具 B：旧名窗口已收
  ✓ 夹具 B：旧命令 down 首行弃用提示
  ✓ 夹具 B：旧命令 down 两个名字都收（pulse 窗口也没了）
```

Other per-item verify commands from tasks.md:

```
$ git grep -n 'team_cmd_watchdog' -- skills/ | grep -v tests/        # 1.1：只剩别名包装
scripts/lib/cmd-watch.sh:663/664（wrapper）+ scripts/team:88/89（dispatch 注释）

$ grep -rn 'team watchdog' skills/teamsmith/references/ skills/teamsmith/SKILL.md \
    | grep -vE 'alias|deprecated|改名|§2b|Renamed'                     # 5.1/5.2
（空 —— 只剩别名/弃用说明行）

$ grep -c 'pulse' skills/teamsmith/SKILL.md                          # 5.2：≥ 13
14

$ grep -rn 'TEAM_WATCH_' skills/teamsmith/templates/                 # 5.3：只剩旧名注释
templates/config.sh.tmpl:78-79（legacy 注释两行）

$ bash skills/teamsmith/scripts/team version --check | head -4       # 5.4
  磁盘代码 1.36.0 / SKILL.md 1.36.0 / CHANGELOG 1.36.0

$ TEAM_PULSE_INTERVAL= TEAM_WATCH_INTERVAL=17 bash skills/teamsmith/scripts/team pulse status   # 2.1（本 worktree 真实配置仍有全部六个旧名）
  巡检周期  17s（…）（legacy: TEAM_WATCH_INTERVAL=17 TEAM_WATCH_NUDGE_GAP=900 …）   ← 17 生效且逐个点名
$ TEAM_PULSE_INTERVAL=11 TEAM_WATCH_INTERVAL=17 … pulse status
  巡检周期  11s（…）   ← 新名赢；其余五个旧名仍在兜底并被单独一行「旧变量」点名（smoke 夹具里只设两个变量时为「不点名」）
```

## Notes for the PM

- **Post-merge, PM-owned** (per tasks.md path note): migrate `.pi/team/config.sh` to `TEAM_PULSE_*` +
  `team pulse restart` to rename the live window; `AGENTS.md` watchdog wording sweep. Everything works without it
  (alias period), and this worktree's real config exercised exactly that fallback during testing.
- `git diff --stat main..HEAD -- skills/teamsmith/CHANGELOG.md`: one entry added, no older line touched (5.4).
- Historical gate reference in tasks.md 4.2/5.5 (`spec-lint.sh`) is stale — the file was removed in v1.35.0; the
  brief's gate list (and `TEAM_GATES`) is openspec validate + smoke only. Tick with this note.
