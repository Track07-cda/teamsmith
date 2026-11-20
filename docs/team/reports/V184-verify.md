# V184 · 独立审阅提醒测试临时目录方案

agent: verify · status: DELIVERED / REWORK · time: 2026-11-20T08:37:29Z

branch: `task/V184-reminder-test-temp-roots-proposal-review` · PR/MR: -

reviewed: `227b04f6823196512170b64a136ffe0adfbea511`

**当前结论：接受最终提案 `cc692739`，四项修订均闭合。** 最后一处明确同步命令返回后先处理停止请求、再决定是否继续写入；仍用原样本区分子驱动真正停止和仅外层返回非零。OpenSpec 1.16.0 严格校验与差异检查通过。只接受方案，未运行行为样本。

**首轮结论（`227b04f6`）：退回 P485 修订。** 默认工作目录应复用现有 `tmp-root.sh`，调用者指定的日志和要求保留的 `run-*` 不搬、不删。首稿把本可不动的恢复入口列为必改，把停止驱动误当成停止了它正在执行的命令，并安排了几组重复验收。以下保留首轮判据及证据。

## 交付及 OpenSpec 评估

本文件是唯一交付。受检候选相对 `f99062e6` 只有五份 OpenSpec 工件和作者报告，现行测试、CI、正式规格均相同。固定检出与本人分支都没有生成的 `openspec-verify-change` 技能；按任务书以独立提案审阅代替实施评估。

| 维度 | 判定及依据 |
|---|---|
| 完备性 | 规划完整可读，实施项未勾选符合本轮范围；实际入口可缩为五个改动文件，见 R1。 |
| 正确性 | 单一变更严格校验通过；现有 helper 的字节判据和进程停止范围都小于方案承诺，见 R2、R3。没有行为通过结论。 |
| 一致性 | `smoke.sh` 三处原调用及 V176 保留现场可维持原样；差异规格和验收还重复了通用规则或未改路径，见 R4。 |

## CRITICAL · 实施前必须修订

### R1 · 保留现有入口，不为改路由增加第六个必改文件

`skills/teamsmith/tests/remind-recovery-real.sh:5` 已经 `exec node … --select=recovery,withdrawal "$@"`，没有自己的目录、指纹检查或收尾。既然 `design.md` 保留 `.mjs` 直调，并让它在创建目录前进入同一 shell，原恢复入口会自动使用该路径；改它只省一次转发，不是这次修复前提。以 **五个文件为上限**：两个 JS 驱动移除旧的目录创建/删除，`remind-tool-real.sh` 承担一次真实 Pi 运行的目录管理，两个 §69 shell 入口保留已有的指纹比较并处理其临时快照；`remind-recovery-real.sh` 和 `smoke.sh` 不动。保留原本的第一条 `--select=` 优先和参数原样传递（`remind-tool-real.mjs:12`，恢复与对抗各自已前置选择项）；两份 `.mjs` 若共用转发写法，也只复用本次的一次内部交接，不设新命令、通用监督器或目录命名。

直接真实 Pi 调用不是假设：`P452-dev.md:65,77` 和 `V176-verify.md:27,47–53,72–85` 中真实执行过，V176 的 `0/1/0` 三臂都保留了 `E/<场景>` 与 `E/run-*/<场景>/.pi/team/state`。故障 JS 虽无第二个已记录调用者，但文件是可执行入口；它的直接运行不能被改成包含原来 shell 专属的指纹比对。两份对抗 shell 现行规则是有非白名单变化强制 `rc=1`，无变化保留原驱动 `rc`，且只在 `rc=0` 打印 `isolation=ok`（`remind-adversarial-real.sh:10–27`、`remind-adversarial-faults.sh:10–26`）。把这三条保留在各原入口，不为直接调用加新结果。

### R2 · 私有 socket 按实际接口与字节数选择、清理

`lib/tmp-root.sh:75–85` 的 `tmp_root_socket_dir <kind> <相对 socket 名>` 只返回一个新目录，默认短基址是 `/tmp`，`${#…}` 在 UTF-8 locale 数的是字符。传完整旧 socket 路径，或只在外层按字节测一次再让 helper 按字符选址，都不成立：如目录按字符算 99、但其中有八个三字节字符，加 `/s` 后字符数 101、字节数 117，helper 会选错，不会尝试短基址。最小改法：保留能使用的绝对 `<work>/socket`；不适配时给现有 helper 同时限定 `LC_ALL=C` 和 `TMP_ROOT_SOCKET_FALLBACK=/var/tmp`，第二参数用实际文件名 `s`。记录确切返回目录，不重算、不扫前缀。测试驱动、启动身份、观察和清理都用同一个绝对 `-S` 目标及一致的 tmux 查找方式；服务器结束后，只移除这次独有的短 socket 目录，不把它当保留证据。

`lib/tmux-iso.sh:66` 的边界是 107 字节（108 含 NUL）。按 `gates.yml:143,238–247` 的 `/var/tmp/teamsmith-ci-tmp/s1`、`smoke.sh:1241` 建出的外层根、`common.sh:83–99` 的命名规则和 `E/run-*/socket` 计算，CI 的 `/work` 形状为 **88 字节**；允许的 24 字节项目短名同形为 **108 字节**。不能把固定 CI 默认当作一定超过上限。`tmux_iso_prove` 仍先观察 `$dir/tmux-<uid>/<name>` 再核对 `--argv`，不是任意 `-S` 路径的观察器（`:127–152,177–195,244–281`）；直接对选定 socket 查 `#{socket_path}`，不要拿另一套 socket 的成功作证。可把这一项合并到本就停在活 pane 上的 TERM 样本：令普通路径实算大于 107 字节，记录实际短路径和移除结果；不是让一个已经退出的成功样本证明曾连过活 server。

### R3 · 中断先收正在写文件的已知进程，再回收目录

`design.md` 称故障入口调用 `tmp_root_reap_all` 就够；该函数只会向登记的 PID 发信号再删目录（`lib/tmp-root.sh:254–263,282–327,367–381`）。反例是向外层 PID 单独发 TERM，故障驱动此时在同步等待 `team remind add`、`remind-tick` 或 recovery authority（`remind-adversarial-faults.mjs:21–24,34–56,105–118`）：只终止 Node 不会终止已启动的 shell/Node/锁子进程，它们可能在目录删除后继续向私有仓库写。真实 Pi 的 tmux 可用准确 socket 关闭，但驱动里的同步 `team init`/ticker 不在 pane 里（`remind-tool-real.mjs:25–32,91–92,149–157`），也不能由 server 回收。现有 2.3 只在已启动的 pane 观察 TERM，不能覆盖这条活进程路径。

最小改法由作者在方案中给出：沿用现有 owner/登记/EXIT，不另造扫描器；让这两份驱动在普通中断下把已在途的非 tmux 命令收完，或明确停止并等到本次实际登记的子进程退出，再回收文件。不能把通用 helper 的 PID 信号升级成对调用者所在进程组发信号。保留真实 Pi 的同一精确 socket 收尾与已正常退出结果；INT 不能先走 helper 默认的删除入口。除了原有一个真实 Pi TERM，只需在故障样本中用一次已知同步调用的到达回执定位中断，观察那次进程和目录未遗留；不做信号矩阵或 KILL 残留扫除。如果设计用有界等待，说明何时能确认命令结束，以及超时不把仍可写的工作目录当作已安全回收。

## WARNING · 同一修订收窄规格与验收

### R4 · 只保留能分辨本次改变的证据

- **不重述通用要求。** `openspec/specs/verification/spec.md:719–775` 已约定创建者、目录解析、正常/INT/TERM 回收、保留声明和仅停止登记的进程。候选 delta 的价值只在于：两份提醒测试中，哪些是可回收的工作，哪些是用户指定的证据。窄写 `P442_EVIDENCE` 的场景文件不删（成功、失败和中断），仅在它与非空 `P442_KEEP` 同时指定时保留原 `E/run-*`，无指定目录时场景与工作同归本次管理；故障测试以非空 `P444_KEEP` 留并报告本次故障原件，不使用 `P442_EVIDENCE`。不再另写一遍通用创建、TERM 或无关进程场景。
- **三条真实 Pi shell 路径不各跑一遍。** `smoke.sh:25169–25183,25232–25243,25262–25274` 已按 `$TMP/p442`、`$TMP/p443`、`$TMP/p444` 传非空 `P442_EVIDENCE` 与 `P442_KEEP=1`；P459 用这个布局保存各场景的启动日志，V176 同时读取两层原件。保留这三条调用的源码核对。真实成功继续选 `large`（`remind-tool-real.mjs:337–358`，应有具名 PASS 和 `1/0`），真实短 socket 用上述一次 TERM。短回执只打不同边界：选改变了指纹包裹的对抗入口，查它的前置选择项、返回码及原路径下的具体文件；需要区分有/无 KEEP 时用同一个路径回执检查实际工作根和证据去向，默认 KEEP 不重复真实 Pi。未改的恢复入口不跑，默认与显式选择的透传直接看同一 argv 路径。回执必须位于实际选路之后，消费同一个场景与私有项目根，完成或显式跳过同次准备资源的收尾；不能照着约定另造两个正确路径，也不能用 `0/0`。故意漏删若保留，复用这一条无 KEEP 的廉价回执和现有 `noreap`，不另开业务场景。
- **故障用同一具名用例，不跑三次等价成功。** `remind-adversarial-faults.mjs:105–119` 先记录 `after-rename` 和真实子进程死亡，随后读原 authority 返回的 `wait`。故可用两次完成态：直接入口在该断言处受控失败并保留原件；恢复该断言，从 shell 正常入口跑同一场景，要求具名 PASS、`1/0`、`isolation=ok` 及工作根消失。这样同时覆盖直接入口、失败保留与原 shell 成功比对，不再补一个等价成功。失败必须有该断言、`fault-mark.txt`、`last-authority.txt` 和 `0/1`，准备失败不算。另把 R3 的中断停在实际在途的子命令，不重跑其它十一例。

## SUGGESTION

无独立建议。空 `P442_EVIDENCE` 视为未指定可保留：原对抗 shell 已这样处理（`${P442_EVIDENCE:-…}`），直调 JS 过去的 `resolve('')` 才把日志放当前目录；已知原件用的是非空路径。`P442_KEEP=0`、`P444_KEEP=0` 仍是非空保留请求，不改成布尔解析。

## 验证证据

```text
$ git -C "$review" rev-parse HEAD
227b04f6823196512170b64a136ffe0adfbea511
$ git -C "$review" status --short --branch
## HEAD (no branch)
$ git -C "$review" diff --name-status f99062e6..HEAD
A  docs/team/reports/P485-dev.md
A  openspec/changes/reminder-test-temp-root-ownership/.openspec.yaml
A  openspec/changes/reminder-test-temp-root-ownership/design.md
A  openspec/changes/reminder-test-temp-root-ownership/proposal.md
A  openspec/changes/reminder-test-temp-root-ownership/specs/verification/spec.md
A  openspec/changes/reminder-test-temp-root-ownership/tasks.md
$ git -C "$review" diff --check f99062e6..HEAD
rc=0 (无输出)
$ git -C "$review" diff --exit-code f99062e6..HEAD -- skills .github ci openspec/specs
rc=0 (无输出)
$ OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" --version
1.16.0
$ (cd "$review" && OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" validate reminder-test-temp-root-ownership --strict)
Change 'reminder-test-temp-root-ownership' is valid
rc=0
```

`review=/var/tmp/p485-review-227b04f6.JIpQ4M`。已用 `git grep`/`rg` 和定点读源码核上述路径；两条 CI 长度是对源码模板的字节计数，不是运行结果。

```text
$ git diff --cached --check -- docs/team/reports/V184-verify.md
rc=0 (无输出；已去掉首稿两处行尾空格)
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2956 hits=0 names=ok user=resolved
ledger rc=0
```

Ledger ban 在本人任务工作树对报告执行；上面只遮蔽家目录中的用户名。

## 首轮判定

CRITICAL 3 · WARNING 1 · SUGGESTION 0。请 PM 退回 dev 只修 R1–R4，再独立核差异。首轮未执行实施样本、真实 Pi、提醒、smoke、完整 OpenSpec 或目录清理工具；旧测试回执只用来核已有调用及取证依赖。变异翻转不适用本轮（方案审阅）。未修改提案、实现、正式规格或看板；仅本人报告在本地任务分支提交，不推送。

## 修订版定点复看 · 2026-11-20T08:47:41Z

**REWORK：只剩 R3 的同步返回点。** PM 固定的独立检出为 `/var/tmp/p485-review-2022af63.0qvXfz`，`HEAD=2022af63e68a9b70f1df624fe5c153d1d05d46c8`。相对 `227b04f6` 仅 design、proposal、delta、tasks 和作者报告改动；现行实现、正式规格及 CI 无差异。

| 首轮项 | 本次结果 |
|---|---|
| R1 | **闭合。** 新 `design.md:8–25` 只列五个文件。恢复 shell 原 `exec node` 直接进入已有选择项的驱动；真实 Pi 和故障的直接 Node 入口各复用自己的 shell 生命周期，但不附带 shell 专属比较。§69 的指纹差异、驱动原码和成功输出规则保持。 |
| R2 | **闭合。** `design.md:44–50` 把 `LC_ALL=C` 放在长度判断及 helper 调用两处，`tmp_root_socket_dir tmux s` 的输入与实际 `<返回目录>/s` 相符，短回退只用 `/var/tmp`。运行与收尾用同一绝对 `-S`，`tasks.md:27–35` 用活 pane 实读 `#{socket_path}`，长路径包含多字节而不冒称默认 CI 超 107 字节。保留证据不意味着保留辅助 socket。 |
| R3 | **一处未闭合。** `design.md:54–71` 已消除先发强制停止再删目录、INT 直接回收的旧路径；owner 等驱动退出，再按精确 socket 收私有服务，最后回收 `W`，不删显式 `E` 或保留的 `E/run-*`。其余问题如下。 |
| R4 | **闭合。** 新 delta 只写本次证据归属，未再承诺一套通用根目录/信号规则；`tasks.md:17–55` 只留一个真实成功、故障同例两次完成态、两种有不同风险的中断、对抗 shell 一种短回执方法。恢复及三处 smoke 调用用源码核，回执在真实路径选择之后、启动资源之前，不用等价入口或零场景。 |

### R3 剩余：注册回调不是保证有机会处理 TERM

- `design.md:59–64` 依赖「控制返回事件循环后从回调退出」，没有安排同步命令结束后何时让出执行。故障驱动的 `await delay(1100)` 位于 `remind-tick` **之前**（`remind-adversarial-faults.mjs:52–59`）。`remind-tick` 的 `spawnSync` 返回后，`await admit(repo)` 只接续已完成 Promise；随即可以执行注入 helper 的 `spawnSync`、原 authority 的同步恢复（`:101–119`），再经 `await runCase` 的 Promise 继续下个 `setup` 或到结尾（`:150–163`）。这些 `await` 并不保证让 I/O 事件循环处理信号。当前结尾**没有** `process.exit()`，只有 `process.exitCode = 1`；但最终一个用例可在这一串 Promise 后直接走普通汇总和退出，没有安排可执行 TERM 回调的下一轮。更早的准备阶段也不能拿后面的定时等待当保证。等待整个驱动使已发生的写入不和删除并发，但不保证驱动在活动命令完成后真正接到停机请求。
- `tasks.md:36–44` 已能证明发出 TERM 时真实 `remind-tick` 在途，并且释放后实际完成准入写入；仍可能假绿：owner 记下 TERM、驱动继续跑注入和恢复并普通退出，最后 owner 自己返回非零且删了根，现有观察照样满足。
- **最小修法：** 在同步调用返回后、开始下一段会写文件的调用或普通完成汇总前，明确留一次真正的事件循环处理机会（例如已知同步段后的 `setImmediate`，不是 `await` 一个已完成的 Promise）；停机回调设中断结果并阻止继续，不在这个处理点前调用 `process.exit()`。保留 owner 的等待和原清理顺序。不加进程登记表。在同一 2.4 样本的真实准入回执之后，要求 **驱动自身**记录已处理中断或返回约定的中断码，且未进入随后注入步骤；不用另增信号样本。这样父 shell 的非零结果不能代替子驱动的停机证据。

```text
$ git -C "$review2" diff --check 227b04f6..HEAD
rc=0 (无输出)
$ git -C "$review2" diff --exit-code 227b04f6..HEAD -- skills .github ci openspec/specs
rc=0 (无输出)
$ OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" --version
1.16.0
$ (cd "$review2" && OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" validate reminder-test-temp-root-ownership --strict)
Change 'reminder-test-temp-root-ownership' is valid
rc=0
```

该修订版计数 CRITICAL 1 · WARNING 0 · SUGGESTION 0。只退回 R3 的两处联动文字（设计与原样本判据），不重开已闭合三项。按复看任务书只跑单变更严格校验及差异检查，不重跑首轮公开记录扫描、不执行任何样本；本地提交仍只含本报告。

## 最后一处定点复看 · 2026-11-20T08:53:29Z

**ACCEPTED（方案）。** PM 的固定检出 `/var/tmp/p485-review-cc692739.S6DWjm` 干净，`HEAD=cc692739068e026b93a38dc5c03438de777cf429`。`2022af63..cc692739` 只改 `design.md` 的 R3 段、`tasks.md` 原 2.4 和作者报告，未重开 R1、R2、R4。

- **设计闭合。** `design.md:59–67` 指定同步命令成功或失败都先 `await setImmediate`，再检查停止请求，早于下一次写入、调用或普通汇总。它点名 `remind-tick` 之后、构建或启动故障注入之前，补上当前源码 `await admit(repo)` 与后续同步操作之间缺的事件循环回合；并要求走专门的 INT/TERM 130/143 路径，不让现有场景 `catch` 把中断当作普通测试失败，不允许在让出前 `process.exit()`。相对上一版，既保留等待活动命令结束后才删工作目录，也补上了停止后续写入的判据。
- **原样本闭合。** `tasks.md:36–45` 在原 2.4 的同一外部回执流中，依次确认真实准入写入、子驱动走 TERM 分支且退出，随后注入入口与普通汇总均未出现，再确认子进程及工作目录消失。注入入口记录放在工作目录之外，删除目录不会把反证一起删掉；仅外层返回非零不再能通过。没有新增样本或业务场景。

```text
$ git -C "$review3" diff --check 2022af63..HEAD
rc=0 (无输出)
$ (cd "$review3" && OPENSPEC_TELEMETRY=0 "$HOME/.bun/bin/openspec" validate reminder-test-temp-root-ownership --strict)
Change 'reminder-test-temp-root-ownership' is valid
rc=0
```

最终计数 CRITICAL 0 · WARNING 0 · SUGGESTION 0。只做此次差异与单变更严格校验；未运行中断样本、真实 Pi 或完整测试，未改方案或实现。实施及行为复验由 PM 另行安排。
