# V184 · 独立审阅提醒测试临时目录方案

agent: verify · status: DELIVERED / REWORK · time: 2026-11-20T08:37:29Z

branch: `task/V184-reminder-test-temp-roots-proposal-review` · PR/MR: -

reviewed: `227b04f6823196512170b64a136ffe0adfbea511`

**结论：退回 P485 修订，不进入实施。** 默认工作目录应复用现有 `tmp-root.sh`，调用者指定的日志和要求保留的 `run-*` 不搬、不删。这个方向对；当前方案却把本可不动的恢复入口列为必改，把停止驱动误当成停止了它正在执行的命令，并安排了几组重复验收。OpenSpec 1.16.0 严格校验通过；本轮没有运行行为样本。

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

## 最终判定

CRITICAL 3 · WARNING 1 · SUGGESTION 0。请 PM 退回 dev 只修 R1–R4，再独立核差异。当前未执行实施样本、真实 Pi、提醒、smoke、完整 OpenSpec 或目录清理工具；旧测试回执只用来核已有调用及取证依赖。变异翻转不适用本轮（方案审阅）。未修改提案、实现、正式规格或看板；仅本人报告在本地任务分支提交，不推送。
