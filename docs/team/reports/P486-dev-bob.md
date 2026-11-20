# P486 · 两份提醒测试交回现有临时目录管理

agent: dev-bob · status: DELIVERED（作者静态检查）

branch: `task/P486-reminder-test-temp-roots-apply` · PR/MR: -

## V185 第二轮后的定点更正

**新候选：`fcd7eab6985568bcb7ccb115639ccd3e9ca195c2`。只更正两个位置参数；两文件语法、改动范围和差异检查均通过。** V185 `8a7a5567` 记录：同一 Pi 在回收前仍为 `R`，真实启动刻度一直是 `88466366`；旧函数记下的 `8968440` 实为父 PID `896844` 后接 `0`。终端关闭后父进程变更，等待逻辑因此把仍在写的 Pi 当成已退出。旧候选和第二轮 FAIL 均保留。

- `skills/teamsmith/tests/lib/tmp-root.sh` 的 `_tmp_root_proc_start` 和 `skills/teamsmith/tests/tmp-hygiene.sh` 的 `_proc_start` 各把 `"$20"` 改为 `"${20}"`。两处的输入、所读字段检查及调用方不变。目录归属、子进程和清理状态的身份比较今后使用真实启动刻度；本次未迁移旧记录，也未改变清理条件。
- `f18c60e4` 的 Pi 退出顺序、其余测试和 OpenSpec 字节不变。独立验证仅用一个现有进程对照实际启动刻度并重跑 2.3；首轮已过的四项继续沿用，不执行真实清扫。

```text
$ bash -n skills/teamsmith/tests/lib/tmp-root.sh
rc=0（无输出）
$ bash -n skills/teamsmith/tests/tmp-hygiene.sh
rc=0（无输出）
$ git diff --check
rc=0（无输出）
$ git diff --name-only a76a9ede
skills/teamsmith/tests/lib/tmp-root.sh
skills/teamsmith/tests/tmp-hygiene.sh
rc=0；两个路径逐字匹配，rc=0
```

本轮只做上述静态检查；未运行读取函数对照、真实 Pi、清理工具、账本扫描或整套测试。提交留在本地。

## V185 首轮后的定点返修记录

**旧返修候选：`f18c60e4f84337c8e954ccf3429f7d0092a78d63`。两份改动文件的语法和差异检查通过；作者未重跑行为，后续独立补验仍失败，见上。** V185 首轮 `bc51f1ba` 的失败原件显示：真实 Pi 调用以 `143` 退出，短 socket 已删、命名证据未改，但工作目录被 Pi 的退出回调重新创建。`23/post-failure-files.txt` 记录重新创建后的目录出生时间，`23/post-failure-inbox-watch.log` 记录后来写入的 `stopped target=p442-large:pm inbox=pm`。

- `skills/teamsmith/tests/remind-tool-real.mjs` 在请求启动前登记本轮场景及启动回执位置。PM 仍用原 `pm.pid.spawn`；原本绕过 PM 启动命令的两个测试使用自己家目录里的回执，不给其增加 PM 身份。替换私有进程时作废旧回执，避免用旧 PID 证明新进程已退出。
- `skills/teamsmith/tests/remind-tool-real.sh` 先等驱动，读取已登记场景的启动 PID，核对该进程的工作目录和启动时刻，然后关闭同一私有 socket。关闭后按已记录的身份确认 Pi 不再写入，才回收工作目录。条件未在正常停止同等的十秒窗口内满足，或启动身份不明，就报告保留的路径，不宣称已回收。未增加对 Pi 的直接信号，未按进程名遍历，也未修改提醒产品的退出回调。
- 保留显式证据和已有非零退出码。只改上述两份测试及本报告；其他三个测试、任务勾选、共用工具和正式规格与首轮相同。2.1、2.2、2.4、2.5 沿用 V185 原件；请原验证者只补 2.3。

```text
$ bash -n skills/teamsmith/tests/remind-tool-real.sh
rc=0（无输出）
$ node --check skills/teamsmith/tests/remind-tool-real.mjs
rc=0（无输出）
$ git diff --check
rc=0（无输出）
$ git diff --name-status a4904676
M  skills/teamsmith/tests/remind-tool-real.mjs
M  skills/teamsmith/tests/remind-tool-real.sh
rc=0；同次命令按上述两个路径逐字匹配，rc=0
$ OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" instructions apply --change reminder-test-temp-root-ownership | grep -E 'complete|^- \[[ x]\]'
2/7 complete；1.1、1.2 已勾，2.1–2.5 未勾
rc=0
```

旧版反例来自 V185，不是作者执行。返修后未运行 2.3、其他验收样本、真实 Pi 或整套测试；也未运行账本扫描。所有提交留在本地。

## 首次交付记录

固定候选：`f7db9e776f8a1ad8c118c522517a67755a5d5485`；该候选的五份可执行测试文件最后提交于 `2e913a32d64b35a14b18ad26b9e00a12a82093db`。

**结论：** 两份测试的默认工作由原目录工具创建和回收。真实 Pi 场景保留调用者指定的日志位置，仅在同时要求保留工作时才在该位置留下原 `run-*`。故障原件只随它自己的工作目录保留。五份文件的语法检查与写集核对通过；实际成功、失败和中断的行为尚未验证。

## 交付

| 路径 | 改动 |
|---|---|
| `skills/teamsmith/tests/remind-tool-real.sh`、`remind-adversarial-real.sh` | 两个 shell 共用真实 Pi 的工作目录管理；对抗入口仍前置 `--select=adversarial,death` 并比较原主项目指纹，快照放本轮工作目录。选择 tmux 路径按字节计，路径放不下时调用现有短地址工具，启动及收尾使用同一私有路径。 |
| `skills/teamsmith/tests/remind-tool-real.mjs` | 直接调用保留 argv、cwd、stdio 和原 Node 可执行文件，并转交同一 shell。驱动按传入路径运行，保留原场景以及逐场景 Pi 关闭。外层等驱动退出后关闭指定 tmux，再回收本轮目录。 |
| `skills/teamsmith/tests/remind-adversarial-faults.sh`、`remind-adversarial-faults.mjs` | 默认工作改由同一临时目录工具创建，`P444_KEEP` 非空时仍打印 `kept fault evidence=`；`P442_EVIDENCE` 不参与路径选择。shell 保留指纹比较，直接 Node 调用不增加该比较。 |
| `openspec/changes/reminder-test-temp-root-ownership/tasks.md` | 只勾 1.1、1.2。2.1–2.5 未勾。 |

两份驱动都保留同步子命令；返回后先给信号回调执行机会，再处理结果。故障驱动的 `remind-tick` 返回点在后续故障注入之前；停止分支不打印普通场景汇总。两个 shell 的退出处理只请求已经登记的本轮驱动停止，等待结束后才调用目录回收；不发送进程组信号，也不对仍在执行命令的驱动使用工具的强制停止路径。上述为源码核对，不是中断实测。

## OpenSpec 评估

| 项目 | 作者证据 |
|---|---|
| 完备性 | `instructions apply` 显示 `2/7 complete`；两条实施项已提交，五条验收留给非作者。 |
| 正确性 | 下列语法与差异检查退出 0；真实文件位置、退出码、私有 tmux 和中断顺序待 2.x 实测。 |
| 一致性 | 候选相对 `9b2af381` 只有五份测试和两个任务勾选；恢复入口、smoke、共用工具、正式规格及提醒产品未改。 |

未发现需加报的静态偏差；不出具行为通过或归档就绪结论。

## 实跑回执

```text
$ for f in skills/teamsmith/tests/remind-{tool-real,adversarial-real,adversarial-faults}.sh; do bash -n "$f"; printf 'rc=0 bash -n %s\n' "$f"; done
rc=0 bash -n skills/teamsmith/tests/remind-tool-real.sh
rc=0 bash -n skills/teamsmith/tests/remind-adversarial-real.sh
rc=0 bash -n skills/teamsmith/tests/remind-adversarial-faults.sh
$ for f in skills/teamsmith/tests/remind-{tool-real,adversarial-faults}.mjs; do node --check "$f"; printf 'rc=0 node --check %s\n' "$f"; done
rc=0 node --check skills/teamsmith/tests/remind-tool-real.mjs
rc=0 node --check skills/teamsmith/tests/remind-adversarial-faults.mjs
$ git diff --check 9b2af381..HEAD
rc=0（无输出，HEAD 为固定候选）
$ git diff --name-status 9b2af381..HEAD
M  openspec/changes/reminder-test-temp-root-ownership/tasks.md
M  skills/teamsmith/tests/remind-adversarial-faults.mjs
M  skills/teamsmith/tests/remind-adversarial-faults.sh
M  skills/teamsmith/tests/remind-adversarial-real.sh
M  skills/teamsmith/tests/remind-tool-real.mjs
M  skills/teamsmith/tests/remind-tool-real.sh
rc=0
$ OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" status --change reminder-test-temp-root-ownership
Progress: 4/4 artifacts complete
rc=0
$ OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" instructions apply --change reminder-test-temp-root-ownership
Progress: 2/7 complete
rc=0
```

两组语法循环均在 `set -e` 下执行。首次直接调用 `openspec` 不在 `PATH`（127）；以上回执来自已安装的绝对路径。进度核对不是规格校验。

- Ledger ban：未运行；P486 将作者检查限定为受影响文件语法、写集、差异和 apply 进度。
- 缺陷翻转：未运行；2.x 的具名失败及中断对照留给非作者。不运行真实 Pi、故障矩阵、整套 smoke、现场提醒或模型，也不以语法检查替代这些结果。
- 无推送或发布。请 PM 以固定候选安排非作者独立验收 2.1–2.5。
