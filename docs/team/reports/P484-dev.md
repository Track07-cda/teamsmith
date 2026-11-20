# P484 · 两份提醒测试的临时目录和证据去向

agent: dev · status: DELIVERED / 只读探索 · time: 2026-11-20 UTC

branch: `task/P484-reminder-test-temp-roots-explore` · inspected: `01ea8fa2` · PR/MR: -

**清理结果：** P474 作者证据包通过 SHA-256 校验，原作业已收取，未发现相关进程占用。仅删除了本人原目录 `/var/tmp/P474-dev-static.PKFsT1`，删除后确认不存在。证据包及其他目录未动。

**建议：** 两个测试的默认运行目录统一交给现有 `tests/lib/tmp-root.sh` 创建和回收，不再默认永久留下真实 Pi 日志。不动调用者指定的 `P442_EVIDENCE`，继续支持 `P442_KEEP` 保留其中的完整测试现场；`P444_KEEP` 继续保留并打印故障现场。真实 Pi 的 `.mjs` 直接调用确实用于独立验收，不能只修 shell 入口。本轮只提交本报告，未改实现、测试或规格。

## 现行四个入口

下表路径均相对于 `skills/teamsmith/tests/`。退出指正常到达脚本末尾，不包括启动中断或外部信号。

| 入口 | 调用、目录来源 | 成功和失败后留下什么 |
|---|---|---|
| `remind-tool-real.sh:5`，smoke §67 | `exec node remind-tool-real.mjs "$@"`；默认选 `pm,large,identity,doctor`。`E=resolve(P442_EVIDENCE)`，未设则 `/var/tmp/p442-real-evidence-<时间戳>`。测试仓库、私有 HOME 和 socket 在 `E/run-*`，每场景证据在 `E/<场景>/`。 | Node 原退出码直达调用者。`E` 及已写的场景证据总留下；`run-*` 在正常收尾时只有非空 `P442_KEEP` 才留下并打印路径。 |
| `remind-recovery-real.sh:5`，smoke §68 | 同一 `.mjs`，固定 `--select=recovery,withdrawal`，其余参数透传。 | 同上，没有自己的目录或清理分支。 |
| `remind-adversarial-real.sh:10–27`，smoke §69 后半 | 固定 `--select=adversarial,death`。非空 `P442_EVIDENCE` 原样传下；未设或为空时先在已解析根下 `mktemp -d teamsmith-p444-real-evidence-<ns>.XXXXXX`，再给 Node 作 `E`。目录名字合规，但不是 `tmp_root_create` 创建，没有它的 owner 标记和运行记录。 | 场景证据和 `run-*` 规则同前；默认 `E` 成功、失败都不会自行删除。shell 在 Node 返回后比较主项目前后指纹，两个点开头的快照文件均删除；差异把结果置为 1，无差异保留 Node 的 rc，仅 rc 0 打印 `isolation=ok evidence=…`。 |
| `remind-adversarial-faults.sh:10–26`，smoke §69 前半 | 运行 `remind-adversarial-faults.mjs`。`root=mkdtempSync('/var/tmp/p444-remind-faults-')`，不看 `TMPDIR`、`TEAM_TMP_ROOT`、`P442_EVIDENCE`；私有 HOME、子进程 TMPDIR、各故障仓库、`last-authority.txt` 和 `recovery-receipt.json` 都在此根。 | `finally` 在成功或用例红时都按同一方式处理：非空 `P444_KEEP` 留整根并打印，否则删整根；用例红汇总退出 1。shell 指纹文件及退出码处理同上一行；没有 `P444_EVIDENCE` 接口。 |

- **当前源码已不同于 V160 的旧盘点。** `remind-tool-real.mjs:13–18,82–98,755–764` 的运行目录已是 `E/run-*`，不是另一个 `/var/tmp/p442-real-*`；`P459-dev.md` 交付表说明这一布局是为把真实 Pi 启动日志和项目现场纳入 smoke 的原有现场保留。`remind-adversarial-faults.mjs:12–16,149–163` 仍直接在 `/var/tmp` 建根。V160 的 70 是当时匹配的文件和目录合计，不是当前数量或可删清单；未重查该现场，也未重做 P453。
- **失败和中断不等于正常收尾。** 真实 Pi 先建 `E`、找 Pi、建 `run-*`、启动 loopback，再进入主 `try`（`:13–23,58–71,288`）。找不到 Pi 已可能留下空 `E`；创建运行根后至进入 `try` 的异常，或 `finally` 在清理 socket 时出错，都可能留下运行根。故障测试在 `try` 前也先建根和两个子目录。两份 Node 驱动没有 INT/TERM 清理入口，两个 §69 shell 快照只在普通返回路径删；代码不能保证信号或进程强杀时留下什么。§69 注入的 SIGKILL 杀的是受测子进程，不等同于驱动被杀。
- **smoke 的 `P442_KEEP=1` 不是要求留下独立的临时目录。** `smoke.sh:25169–25183,25232–25274` 把三次真实 Pi 的 `E` 固定在外层 `$TMP/p442`、`$TMP/p443`、`$TMP/p444` 并显式保留 `run-*`，由外层统一决定是否保留现场；它不向故障测试设置 `P444_KEEP`。`--keep` 会导出 `TEAM_TMP_KEEP=1`（`:305`）。现有 §40 只检查运行记录上尚存的目录，并在显式保留时不判泄漏（`:21463–21474`）；不要把内层 `P442_KEEP=1` 一律转换成另一个长久保留的、位于外层现场之外的目录。
- **直接调用记录。** `git grep -F 'remind-tool-real.mjs'` 命中的 `P452-dev.md:65,77,168`、`V159-dev3.md:65,78,87`、`V164-verify.md:121–124` 和 `V176-verify.md:72–85` 有实际 `node … --select=…` 命令，不是 `node --check`。V176 正常/旧红/恢复三臂分别 rc `0/1/0`，证据同时依赖 `E/<场景>` 日志和 `E/run-*/<场景>/.pi/team/state`，旧红也要留。`remind-adversarial-faults.mjs` 当前跟踪来源只有 §69 shell、映射、本任务书和 V160 引用；V160 实跑的是 `.sh`（`:62` 及合并轮日志），未找到直接执行 `.mjs` 的记录。后者虽是可执行文件，不能据此宣称无人使用；若保留直跑，也应委托同一 shell，无需再保留旧的 JS 创建方式。

## 最小改法建议，不是实施授权

1. **由 shell 持有本轮临时目录。** 普通真实 Pi 和故障测试分别用 `tmp_root_create`，只把实际路径传给 Node。恢复测试调用同一个真实 Pi 入口；对抗真实 Pi 仍在现有指纹检查内使用同一路径选择。§69 比对的两份快照可放进包装器已有的临时根，到原判定点仍删除，不补过去没保存的证据、不改指纹范围。`tmp-root.sh:68–75,191–251,305–358` 已提供解析、owner 标记、运行记录、信号和退出回收；不要在 JS 内仿写解析，也不要用单次 `bash -c` 命令替换当所有者——该 shell 结束就会收掉目录。创建者必须活到 Node 及私有进程收尾，不能 `exec node` 丢掉退出处理。沿用 `team_tmp_root_note` 报来源；显式无效的临时根按现有规则报错，不回落。普通工作文件随创建者清理，无法执行退出处理的残留只用现有 `tmp-hygiene --status/--sweep` 处理；工具按家族和项目归属、进程占用、年龄判断，非家族旧目录不会因此变成候选。
2. **保留输出路径的实用性。** 无 `P442_EVIDENCE` 时，场景日志进本次登记的运行根下，默认成功或失败都回收；需要现场时用原 `P442_KEEP` 或通用 `TEAM_TMP_KEEP=1`，保留并打印登记路径。显式非空 `E` 时，`E/<场景>` 的日志、回执在成功和失败后都不删；无保留请求时，临时 HOME、项目和 socket 从登记根回收。显式 `E` 且设 `P442_KEEP` 时保留现行 `E/run-*` 布局，明确它是调用者要求保留的完整现场，不是另一个要登记清扫的共享临时根；不挪动到别处，以免 `launch.txt` 等记录的绝对路径失效。smoke 现有三处因此不用改变，外层删除或 `--keep` 的行为不变。空 `P442_EVIDENCE` 建议统一视为未指定：直跑 JS 当前用 `??`，`resolve('')` 意味着当前目录，而对抗 shell 用 `:-`，两面含义不一。故障测试保留原 `P444_KEEP` 条件，交给该入口本地的 `TEAM_TMP_KEEP=1`，不新增证据变量；登记保留的目录是临时调试资料，不等同于永久归档，仍可能由现有清理工具回收。
3. **保留入口、原退出码和私有进程边界。** 真实 Pi 的 `.mjs` 若从命令行直跑，转交现有 shell 入口后再进入同一驱动；传回原参数、cwd、环境、stdout/stderr 和退出状态，不能把 Node 启动两次测试或让信号只打到外层转发进程。保留 Node 已有的 server/tmux 正常退出逻辑；异常退出参照 `remind-pulse.sh:15–23` 的做法，用本轮精确的私有 socket、记录的子进程和现有回收函数，先停止本轮进程再删根，不另建清理设施。更长的项目命名路径可能挤过 AF_UNIX 的 107 字节（`lib/tmux-iso.sh:7–11`）；复验沿用私有 socket 约束并覆盖 CI 路径形态，不能回退共享默认 socket。

## 后续非作者最小验收

- 在独立检出给 `TMPDIR` 一个本次独有的已存在目录，另给不同的 `TEAM_TMP_ROOT`：用现有四个 shell 入口各跑一次。用例选择不变，核对既有真实 Pi `10/3/7` 组汇总与故障矩阵 `12/0`、§69 两个 `isolation=ok`，以及运行中记录的根路径、命名空间和退出后去向。以 P442 默认无保留验证成功回收，P443 设显式 `E` 不设 KEEP 验证只留场景证据，P444 真实 Pi 用 smoke 同形的 `E` 和 `P442_KEEP=1` 验证保留 `run-*` 与回执，故障矩阵默认回收。用固定 CI 形状核对真实套件原来的三处现场路径仍由外层清理或保留，无需再跑 0e、36、40 全段或整套 smoke。
- 用 V176 记录的直接 `node … --select=adversarial-event-after` 在私有副本做一条具名失败：rc 非零，显式 `E/<场景>` 的实际失败原件不被清理，不设 `P442_KEEP` 时工作根已消失。用早期失败对照验证 `P444_KEEP` 仍留并打印自己的根、无 KEEP 不留；给一个不存在的显式 `TMPDIR` 检查具名失败且不写入其它基准。不要用未知 `--select` 得到的零用例汇总代替通过。
- 在同一私有临时基准内补一次中断验证：给正在运行的入口发 TERM，必要时用相同的短现有场景查 INT，确认只私有进程消失且应清理的根不再存在、显式证据未被误删。若查 KILL 残留，仅用该私有基准和已记录路径验证现有 `--status` / `--sweep --dry-run` 能辨认；不接触历史目录或真实团队。证伪可用相同命令跑旧驱动，核对它实际创建的默认目录不在隔离的 `TMPDIR` 下，不新增长期静态检查。

## 本轮实际证据与边界

| 操作 | 实际结果 |
|---|---|
| `git status --short --branch`、`git log --oneline -5`、`git grep -F 'remind-adversarial-faults.mjs'`、`git grep -F 'remind-tool-real.mjs'` 及上述文件定点阅读 | 起点工作树干净，`01ea8fa2`。当前四个入口、历史直调与目录行为见上，不是本轮行为实测。 |
| `sha256sum -c --strict P474-dev-raw.sha256`（已核对清单只引用同目录作者归档） | `P474-dev-raw.tar.gz: OK`，rc 0；与 `V179.md` 的封存记录一致。 |
| 对记录 `bg.log` 查询 `P474`，检查原作业 PID、路径形态和占用 | `P474-static` `exit0` / `outcome=harvested`，原 PID `533944` 不在。目标是本人拥有、真实路径等于原路径的非软链目录；本人进程 `lsof -nP -a -u … -Fpn` 对该路径及子路径 0 命中（其他容器挂载有 lsof 警告，不在目标路径），`/proc` 本人进程的命令行路径 0 命中，`findmnt` 目标下 0 挂载。未扫描临时目录。 |
| `rm -rf --one-file-system -- /var/tmp/P474-dev-static.PKFsT1`，再检查 `! -e` 和 `! -L` | `removed and verified absent: /var/tmp/P474-dev-static.PKFsT1`。没有清其他路径，不改封存文件。 |
| `git diff --cached --check -- docs/team/reports/P484-dev.md` | 报告差异检查 rc 0，无输出。 |

规格只读锚点：`openspec/specs/verification/spec.md:719`，未写规格或变更提案。本轮不执行真实 Pi、提醒、故障矩阵、smoke、OpenSpec 验证、安装、临时目录清单或回收工具，不改实际提醒、待命和队列。实现翻转证据：不适用，本轮是探索。Ledger ban：**未执行**，任务书只授权报告差异检查。无远端操作。
