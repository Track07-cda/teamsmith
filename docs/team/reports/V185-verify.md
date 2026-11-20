# V185 · 两份提醒测试的清理、保留和中断复验

agent: verify · status: REWORK · time: 2026-11-20T09:19:26Z

branch: `task/V185-reminder-test-temp-roots-verify` · PR/MR: -

**结论：不合并 `f7db9e77`。** 五项中四项通过；真实 Pi 收到 TERM 后，私有终端关闭、指定场景日志保留，但 Pi 的退出回调在原工作目录被删除后重建了它。运行返回 `143`，工作目录仍在。故障测试的中断没有这个问题：真实入队写完，驱动自己以 `143` 退出，未开始故障注入，工作目录消失。

## 交付

| 路径 | 内容 |
|---|---|
| `docs/team/reviews/P486.md`、`docs/team/reviews/P486-verify.log` | 原生 `team review` 实际执行者为 verify，绑定 `f7db9e776f8a1ad8c118c522517a67755a5d5485`，判定 FAIL。只有此两份主检出写入由 brief 授权。 |
| `/var/tmp/v185.tngpip/` | 本次隔离取证：`run.py`、`private-diffs.txt`、各样本命令、stdout/stderr/rc、场景与进程回执、`23/post-failure*` 及 `formal-candidate/` 原生记录副本。保留待 PM 接收。 |
| 本报告 | 本地提交，不推送。未改实现、OpenSpec、看板或候选检出。 |

## OpenSpec assessment

固定检出没有生成的 `.pi/skills/openspec-verify-change/SKILL.md`；按任务书审阅设计、增量要求和实际行为。OpenSpec 1.16.0 单变更 strict 通过，不替代行为结果。

| 维度 | 判定及证据 |
|---|---|
| 完整性 | 原生清单仍只有 1.1、1.2 已勾，2.1–2.5 未勾。复验独立执行五项，2.1、2.2、2.4、2.5 达到判据，2.3 工作目录未回收。 |
| 正确性 | 默认真实数据写入、显式证据保留、原故障恢复、同步子命令中断后的停止顺序均有行为原件。继承的 `verification` 临时目录要求在真实 Pi TERM 路径有反例，见 F1。 |
| 一致性 | 相对 `9b2af381` 仅改五份测试和 1.x 勾选；`a4904676` 相对候选只增作者报告。五份测试语法通过。旧恢复入口仍前置 `recovery,withdrawal` 后 `exec node … "$@"`；`smoke.sh` 三处仍是 `$TMP/p442`、`$TMP/p443`、`$TMP/p444` 配 `P442_KEEP=1`。共享真实 Pi shell 按原样传 `"$@"`，直接 Node 保留参数数组，Node 取第一个 `--select=`；未指定证据时，非空 `P442_KEEP` 映射到 `TEAM_TMP_KEEP=1`（`remind-tool-real.sh:54–55,98`，`remind-tool-real.mjs:14–20,41`）。 |

## CRITICAL

**F1 · 真实 Pi 中断后会把刚删除的工作目录建回来（2.3）。** 仅向直调 Node PID `2714263` 发 TERM。写下第一条本地模型请求并暂停回复后，实际调用 `tmux -S` 的 `#{socket_path}` 读到 `/var/tmp/.t-1000.QWvlMG/s`，server PID `2716089`、活 pane `%0`、Pi PID `2716305` 和驱动 PID `2714388` 均有启动身份记录。普通路径 158 字节；helper 第一个候选 82 字符、110 字节，准确走到 `/var/tmp` 短回退。入口退出 `143`、短 socket 目录消失，事后六个记录 PID 均不在进程表；命名证据 `session-start` 前后 SHA-256 相同。

但是同一工作目录仍存在，且原有 `.teamsmith-tmp` 不在。`23/post-failure-files.txt` 的目录出生时间为 `09:17:08.179600826Z`，晚于受控请求落盘和发 TERM 时的回执 `09:17:08.118224669Z`。目录里只有新写的 `large/.pi/team/state/inbox-watch.log` 和 `reply-capture/runtime.lock` 等退出现场；前者为 `09:17:08.183Z stopped target=p442-large:pm inbox=pm`。候选 `remind-tool-real.sh:19,40` 在 `tmux … kill-server` 返回后直接进入回收，只等待了驱动，未等 pane 中的 Pi 完成退出；`team-inbox-watch.ts:317–320,1572–1577` 的 `session_shutdown` 正会执行 `mkdirSync` 和写上述停止记录。原件与源码共同指向：终端服务停止不等于 Pi 已停止写文件。这不是缺二进制、路径未建立，或仅仅父进程非零；真实场景确实启动、收到请求且留下了关闭日志。

**BLOCKED:** 请 PM 退回实施者，只修真实 Pi 中断的收尾顺序：在回收本次工作目录前确认已启动的私有 Pi/pane 已完成退出、不能再写入；保留精确 socket、命名场景证据与原退出码。返修只重跑 2.3 并完成该项的独立终端确认，未受影响的四项沿用原件。

## WARNING

无独立警告。2.3 在工作目录断言失败时未执行计划内的独立 `has-session`；`finally` 对独立 socket 调用 `kill-server` 成功只佐证当时该 server 仍可访问，不冒充 `has-session` 实测。这个取证缺口不影响 F1。

## SUGGESTION

无。

## Verification evidence

```text
$ TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_GATES='/usr/bin/python3 /var/tmp/v185.tngpip/run.py' \
    bash skills/teamsmith/scripts/team review P486 \
    --dir /var/tmp/p486-review-f7db9e77.dmzBCK --branch f7db9e776f8a1ad8c118c522517a67755a5d5485
review checkout: … @ f7db9e776（干净）
门禁输出：docs/team/reviews/P486-verify.log（FAIL，10s）
复验记录：docs/team/reviews/P486.md（FAIL）
v185-candidate exit=1, wall=24.0s; review queued=1s, ran=10s
```

实际执行命令分别存在证据根的 `*/command`，在没有继承团队、tmux 或用户凭据的独立环境执行；`TMPDIR` 与 `TEAM_TMP_ROOT` 指向两个实有目录。真实 Pi 只连接测试已有 `127.0.0.1` 服务。2.1 直接使用未改的候选；其余按任务书仅在候选 `git archive` 隔离副本内缩小或取证，私有差异保存在 `private-diffs.txt`。

| 项 | 实跑回执（路径相对 `/var/tmp/v185.tngpip/`） |
|---|---|
| 2.1 默认成功 | `21/command` 为直调 `remind-tool-real.mjs --select=large`。`PASS real Pi 64 KiB plus final newline through real PM tool add/show/list/cancel`，`passed=1 failed=0`，rc=0。从实际 root 的 `evidence/large` 读取到 `session-start`、`events.jsonl`、`requests.jsonl`；`21/observer.jsonl` 记录实际路径和退出后 root 不存在。没有另建默认场景目录。 |
| 2.2 具名故障和恢复 | 直调 `remind-adversarial-faults.mjs`，`P444_KEEP=1` 且命名另一 `P442_EVIDENCE`。真实崩溃位置 `fault-mark.txt=after-rename`，原 authority `last-authority.txt` 给 `action=wait`；故意反转重启断言得 `FAULT FAIL remind-intent after-rename`、`0/1`、rc=1；原件确在 `kept fault evidence=` 的路径，无关路径未创建。仅还原该断言后以 shell 跑同例得 `FAULT PASS remind-intent after-rename`、`1/0`、`isolation=ok`、rc=0 且工作目录消失。原件：`22-negative/`、`22-restored/`。 |
| 2.3 真实 Pi TERM | 实际场景和活 pane 到位；原路径及短路径均由实际选择读出。退出码和指定日志保留符合预期，但目录重现，**失败**。先后证据：`23/observer.jsonl`、`23/socket-identity.stdout`、`23/post-failure.json`、`23/post-failure-files.txt`、`23/post-failure-inbox-watch.log`。 |
| 2.4 故障 TERM | `24/order.jsonl`：实际 tick `2726079` 到达，状态 `scheduled` → owner `2721488` 向驱动 `2721786` 转发 TERM → 观察到根仍在、释放 tick → 同一 tick 写成 `queued`，日志 `admit n=1 … queue=1` → 驱动走 `SIGTERM` 分支 → 驱动自己 exit `143`。外部流无 `injection-entry`，原 stdout 无普通汇总；入口 rc=143、三个记录进程均不存在、根不在（`24/observer.jsonl`）。 |
| 2.5 入口路径短回执 | 只走改过的对抗 shell。真实 argv 前置 `--select=adversarial,death`，既携带次选 `--select=large`，也透传一个含空格的参数。原选择结果、`E`、工作根和文件路径在 handoff 以后读取。`25-kept/`：rc=0、`isolation=ok`，`p444/v185-path-receipt/scene.txt` 与 `p444/run-5Wb2dP/v185-path-receipt/.pi/team/state/project.txt` 存在，外层工作根消失。`25-nonzero/`：具名 rc=37 原样返回，没有 `isolation=ok`，场景文件保留、工作根消失。两次都在启动 provider/Pi 前停止，只是路径回执，不是业务 PASS。 |

```text
$ git -C "$review" diff --check 9b2af381..HEAD
rc=0（无输出）
$ git -C "$review" diff --name-only f7db9e77..a4904676
docs/team/reports/P486-dev-bob.md
$ git -C "$review" status --porcelain=v1 --untracked-files=all --ignored
rc=0（执行前及执行后均无输出）
$ OPENSPEC_TELEMETRY=0 "$openspec" --version
1.16.0
$ OPENSPEC_TELEMETRY=0 "$openspec" validate reminder-test-temp-root-ownership --strict
Change 'reminder-test-temp-root-ownership' is valid
rc=0
```

`static/` 保留实际版本与语法命令、5 个语法退出码、4 条旧入口源码命中行及写集。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2964 hits=0 names=ok user=resolved
rc=0
```

## Flip evidence

2.2 的负/正输出确实分别出现具名 `after-rename` 失败、`'wait' !== 'send'` 和还原后的具名成功；真实故障记录在失败时留下、在成功时随根删除。F1 直接由候选 2.3 复现，未做未授权修复，也没有声称已取得其修复后通过结果。

## Final assessment

CRITICAL 1 · WARNING 0 · SUGGESTION 0。候选不可接受；真实 Pi TERM 仍能留下临时工作。未跑 INT、其它场景或完整故障矩阵，未另跑恢复入口、三处 smoke 调用、完整 smoke、完整 OpenSpec、性能或安装，行为样本没有操作真实团队或调用外部模型。合并版未提供，因此未做合并版同一性检查。

## Decisions and deviations

未额外重跑行为样本。2.3 断言失败后仅从同次原件做字节、目录出生时间与进程表核对，保留正式 FAIL；未删除这次遗留目录和其它原件。
