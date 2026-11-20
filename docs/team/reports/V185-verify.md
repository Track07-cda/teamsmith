# V185 · 两份提醒测试的清理、保留和中断复验

agent: verify · status: PASS（合并版定点核对完成） · time: 2026-11-20T09:48:41Z

branch: `task/V185-reminder-test-temp-roots-verify` · PR/MR: -

**当前结论：接受候选 `fcd7eab6` 的定点补验。** 两处读取结果与内核一致。真实 Pi 的父进程变为 1 后，原进程身份仍被正确识别；实际观察到 Pi 退出时工作目录尚在，之后才删除目录。入口返回 `143`，命名证据不变，独立私有终端仍正常。其余四项沿用首轮原件；两轮历史 FAIL 均保留。合并版 `191e8097` 的七份测试文件、五份规格变更文件、语法及调用入口也已核对通过，未重跑行为。

**首轮结论：不合并 `f7db9e77`。** 五项中四项通过；真实 Pi 收到 TERM 后，私有终端关闭、指定场景日志保留，但 Pi 的退出回调在原工作目录被删除后重建了它。运行返回 `143`，工作目录仍在。故障测试的中断没有这个问题：真实入队写完，驱动自己以 `143` 退出，未开始故障注入，工作目录消失。

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

首轮未额外重跑行为样本。2.3 断言失败后仅从同次原件做字节、目录出生时间与进程表核对，保留正式 FAIL；未删除这次遗留目录和其它原件。

## 第二轮 · `f18c60e4` 定点补验 · 2026-11-20T09:35:32Z

**2.3 仍失败。** 实际启动回执和场景都记录 Pi PID `896846`。TERM 只发给入口 PID `896335`。短 socket `/var/tmp/.t-1000.MgJ3EA/s` 已删除，独立私有终端 `has-session` 明确执行并返回 `0`，命名证据 `session-start` 与 `requests.jsonl` 的前后字节相同，入口仍返回 `143`。但回收前从 `/proc` 读到同一 Pi 为 `R`，删除后目录仍在，stderr 点名 `tmp-root: 删不掉 …`。Pi 稍后由 pidfd 确认退出，事后六个记录 PID 都不在。这不是准备错误或私有终端串用。

```text
$ TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_GATES='/usr/bin/python3 /var/tmp/v185-r2.vuWv1H/run.py' \
    bash skills/teamsmith/scripts/team review P486 \
    --dir /var/tmp/p486-review-f18c60e4.Cirxdv --branch f18c60e4f84337c8e954ccf3429f7d0092a78d63
checkout clean · HEAD=f18c60e4f · executor=verify · queued=1s · ran=2s · FAIL
v185-candidate-r2 exit=1, wall=15.0s
```

| 实际顺序（UTC 09:34:27） | 原件 |
|---|---|
| `.814905` 确认 Pi 活着，场景回执、`pm.pid.spawn`、实际 cwd 均吻合；内核启动刻度 `88466366`，PPID `896844`；随后仅向入口发 TERM | `23/observer.jsonl`、`23/launched-scenes`、`23/real-pi-spawn-receipt`、`23/socket-identity.stdout` |
| `.856347` 当前实现记下 `896846:8968440`；`.861201` 关闭 tmux 返回；`.864481` 等待函数返回成功 | `23/lifetime.tsv`，采自实际 shell 变量和原有调用返回，不新增等待 |
| `.868476` 原回收调用之前，同一 Pi 的真实状态仍为 `R`，启动刻度仍是 `88466366`；`.914057` 回收返回但目录仍在 | `23/lifetime.tsv`、`23/stderr` |
| `.922002` pidfd **观察到** 该 Pi 已退出，此时 `/proc` 暂为 `Z`、PPID `1`，启动刻度不变；工作目录仍在 | `23/observer.jsonl`、`23/rc`、`23/independent-still-live.rc` |

**根因：** `tests/lib/tmp-root.sh:125–134` 先检查 `${20}`，实际却用 `"$20"` 输出；Bash 将它当成 `$2` 后接 `0`。去掉 `/proc/<pid>/stat` 的 PID 与进程名后，第 2 列是父进程号，第 20 列才是开始刻度。返修 `remind-tool-real.sh:22,42–46` 将此值作稳定身份：首次记下 `8968440`，Pi 在 tmux 退出后改由 PID 1 托管，前后读值便会不同，虽然同一 Pi 仍在。用同一候选中的真实函数只读核对本次新 shell 的 `/proc`，得到 `parent=1069276 actual_tick=88472958 helper=10692760 parent_plus_zero=10692760`；命令 rc=0（`23/proc-reader-contrast.stdout`），不是另一组 Pi 或提醒场景。进程和文件时间观察只取自 `/proc`、pidfd 与原回收边界，无固定等待代替退出判定。

**范围及静态回执：** `f7db9e77..f18c60e4` 只有两份真实 Pi 测试及首轮作者报告；`a4904676..f18c60e4` 只改两份测试；`f18c60e4..a76a9ede` 只改作者报告。候选前后干净，差异检查、`bash -n`、`node --check`、OpenSpec 1.16.0 单变更 `--strict` 均 rc=0（`static/`）。2.2、2.4 故障入口字节不变；2.5 的回执在启动任何 Pi 前返回，没有新的场景身份供收尾等待；2.1 的普通场景仍先等 Pi 落 `done` 或确认 Pi 已停止才关 session（`remind-tool-real.mjs:195–220`），新逻辑只读该场景已有的启动回执，正常完成路径不依赖此时 Pi 还活着。2.1、2.2、2.4、2.5 沿用首轮原件，未作为 `f18c60e4` 重新实跑。

**BLOCKED:** F1 仍未闭合。请 PM 让实现者保证实际比较的是内核启动刻度，而不是父进程号；如改共用函数，先明确其他调用受影响的范围，再决定必要的定点验证。两个版本的正式 FAIL 和报告均保留于各自证据根的 `formal-candidate/`；返修原件在 `/var/tmp/v185-r2.vuWv1H/`。未改候选、共享脚本、规格勾选或首轮原件。本人工作树在本轮报告定稿前重跑上述 ledger-ban 命令，`files=2964 hits=0`、rc=0（`ledger-ban.log`）。

## 第三轮 · `fcd7eab6` 定点补验 · 2026-11-20T09:43:59Z

**2.3 通过，F1 闭合。** 仅向真实 Node 入口 PID `2148989` 发 TERM。活 pane `%0` 的实际 `#{socket_path}` 为 `/var/tmp/.t-1000.9g2mLO/s`；普通路径 143 字节，helper 第一候选为 84 字符、110 字节，触发 `/var/tmp` 短回退。实际 `pm.pid.spawn`、`session-start` 和 `/proc` 一致指向 Pi `2153713`。关闭 tmux 返回时不再假定 Pi 已退出，顺序如下。

| 实际顺序（UTC） | 原件 |
|---|---|
| `09:43:29.600878` owner 记下 `2153713:88520554`，与独立读取吻合，初始 PPID `2153706` | `23/lifetime.tsv`、`23/observer.jsonl`、`23/real-pi-spawn-receipt` |
| `09:43:29.605974` 私有 tmux 关闭调用返回 | `23/lifetime.tsv` |
| `09:43:29.883698969` 独立 pidfd 观察 Pi 已退出：短暂 `Z`，PPID 已变为 `1`，启动刻度仍为 `88520554`；此时工作目录仍存在 | `23/observer.jsonl` |
| `09:43:29.932081` owner 等 Pi 函数成功返回；`.937571` 回收前 Pi 已不在；`09:43:30.005998` 回收结束，目录不存在 | `23/lifetime.tsv` |

入口 rc=143、stderr 为空；事后六个私有进程都不在，短 socket 目录不存在，确切 socket 的 `has-session` 返回 `1`，无关私有终端的 `has-session` 返回 `0`。保留的 `session-start` 与 `requests.jsonl` 前后字节相同。没有靠固定延迟认定进程已退出或目录已安全删除。

**两处读取对照通过。** 同一个本轮自建的无关进程 PID `2147740`，独立读取 `/proc/<pid>/stat` 得 `88520410`；从固定检出的 `lib/tmp-root.sh` 直接调用 `_tmp_root_proc_start`，从 `tmp-hygiene.sh` 逐字提取完整 `_proc_start` 后直接调用，均返回 `88520410`。父 PID `2147445` 接 `0` 得 `21474450`，不是这两次结果。命令、输出、rc=0、真实内核值和随后回收该受控进程的确认均在 `readers/`。没有加载 `tmp-hygiene.sh` 的命令入口、扫描或清扫。

```text
$ TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_GATES='/usr/bin/python3 /var/tmp/v185-r3.fNjRnD/run.py' \
    bash skills/teamsmith/scripts/team review P486 \
    --dir /var/tmp/p486-review-fcd7eab6.e2u2yy --branch fcd7eab6985568bcb7ccb115639ccd3e9ca195c2
Change 'reminder-test-temp-root-ownership' is valid
Both existing readers for pid=2147740: /proc tick=88520410 tmp-root=88520410 tmp-hygiene=88520410; parent=2147445
VERIFIED 2.3 only: tracked Pi exited before reap; no recreated root, short socket gone, two evidence records byte-identical, other session still alive
checkout clean · HEAD=fcd7eab69 · executor=verify · queued=0s · ran=4s · PASS
v185-candidate-r3 exit=0, wall=20.4s
```

**静态与复用边界。** 相对第二轮，两份公共工具各只把 `"$20"` 换为 `"${20}"`；其他测试和规格字节相同，连同候选进入的首轮作者报告不算可执行变化。`fcd7eab6..a1c85a77` 仅改作者报告。候选前后干净，两份 `bash -n`、差异检查和 OpenSpec 1.16.0 单变更 strict 均 rc=0（`static/`）。

- `tmp-root.sh:200–263,321–343` 中，工作根与本轮进程的登记和读取都使用同一函数，既有的销毁与 KEEP 判定未变。正常 2.1/2.2 的 owner 未换父进程，2.4 的驱动在原 shell 等待期间保持同一父进程直至退出；2.5 没有启动 Pi。保留它们的原行为证据，不把它们称为在最终候选重新运行。2.3 单独补上原判据以及此次进程读数改动最直接影响的路径。
- `tmp-hygiene.sh:169–177,795–816,1217` 中，这个读值用于列表的 owner 状态说明；占用判定仍看 `_occupants_of`，未改扫描或清扫分支。旧版本曾写入的 `start=` 并不等于内核刻度，本次不声称旧标记兼容或已检验清扫；没有运行扫描、清扫或碰其它运行的目录。

**最终评估：** 实施清单仍为 `2/7`，未代勾 2.x；合并前核验范围内，证据为首轮四项实跑 + 第三轮 2.3 及两函数读数，不是一次完整重跑。CRITICAL 0 · WARNING 0 · SUGGESTION 0；下一步仅在 PM 合并后核合并版同一性、语法和接入，无需重跑场景。`/var/tmp/v185-r3.fNjRnD/` 与 `formal-candidate/` 保留本次原始命令、stdout/stderr/rc、时序与原生 PASS 记录；前两轮原件及各自的正式 FAIL 原样保留。本轮本人工作树的同一 ledger-ban 命令 `files=2964 hits=0`、rc=0（`ledger-ban.log`）。

## 合并版定点核对 · `191e8097` · 2026-11-20T09:48:41Z

**PASS，复验交付完成。** PM 固定检出 `/var/tmp/p486-merged-191e8097.qNIrjX` 绑定 `191e80974eca1a633f7affd9d66bea110d2384cb`，核对前后干净。这次只做以下静态检查，沿用候选的行为原件。

| 核对 | 结果 |
|---|---|
| 七份测试文件 | 两份 Node 驱动、三个提醒 shell、`lib/tmp-root.sh` 和 `tmp-hygiene.sh` 逐一与 `fcd7eab6` 比较：工作文件字节、Git blob 和 mode 相同；两份 `node --check`、五份 `bash -n` 各 rc=0。 |
| 五份 OpenSpec 变更文件 | `.openspec.yaml`、proposal、design、tasks 和 verification delta 的字节、blob 和 mode 均相同；没有勾选新项目或重跑候选的 OpenSpec strict。 |
| 所有指定接入 | 恢复入口仍 `exec node` 并前置 `recovery,withdrawal`；`smoke.sh:25169–25177,25232–25240,25262–25268` 的普通、恢复、对抗入口及显式 `$TMP/p442`、`$TMP/p443`、`$TMP/p444` 与 `P442_KEEP=1` 均匹配。真实驱动以实际启动回执登记场景，owner 读同一身份函数、等 Pi 退出再回收；两处读取仍用 `${20}`，`tmp-hygiene.sh` 的列表判断仍调用自己的 `_proc_start`。 |

```text
$ TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_GATES='bash /var/tmp/v185-merged.CZhXL8/check.sh' \
    bash skills/teamsmith/scripts/team review P486 \
    --dir /var/tmp/p486-merged-191e8097.qNIrjX --branch 191e80974eca1a633f7affd9d66bea110d2384cb
checkout=191e80974 clean · executor=verify · queued=0s · ran=0s（工具按整秒计）· PASS
merged check passed: 7 files, 5 change artifacts, all original entry connections verified by source; no behavioral sample, process probe, or cleanup executed
v185-merged exit=0, wall=16.0s
```

原生命令、逐文件输出与记录保存于 `/var/tmp/v185-merged.CZhXL8/`；`formal-merged/` 的两份文件已与中央输出逐字节核对。首轮、第二轮、第三轮候选原件各自保留；未重跑 2.1–2.5、进程读数、扫描、清扫、完整 smoke 或性能检查。没有修改实现、规格勾选或 PM 的结案记录。本轮在本人任务工作树重新扫描报告，ledger-ban `files=2964 hits=0`、rc=0（`ledger-ban.log`）。
