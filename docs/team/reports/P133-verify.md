# P133 · destructive-call-forensics 独立验证

agent: verify   status: **PASS（FAST 复跑全绿；全量可选未跑）**   time: 2026-09-29
branch: `task/P133-p133`   PR/MR: -（local 模式）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P133-verify/probe.sh` | **自己编写**的独立探针：桩固定 `TEAM_TMUX_REAL`；scratch shim / ledger；从原 smoke 抽实际扫描函数；三条影子红侧。绝不运行真实默认 socket 上的 tmux。 |
| `docs/team/reports/P133-verify/probe.log` | 探针原始输出：真实调用行、逐字节比较、两次轮转标记、失败诊断、扫描名单和红/绿。 |
| `docs/team/reports/P133-verify/{validate,author-10,author-20,fast,fast-container,relevant,fast-gate-image,fast-gate-final}.log` | 各命令完整原始输出；作者的两个包只是补充，不是独立证据。 |

## Verification evidence (actually run)

```
$ bash docs/team/reports/P133-verify/probe.sh > docs/team/reports/P133-verify/probe.log 2>&1
# rc=0；以下均为本人编排，不依赖作者探针：
contract: pre-logging AND post-logging byte-identical to pre-P132 (socket table, verdict, refusal, exec)
refused original (same bytes in main and retention):
2026-09-29T19:25:51+00:00 · act=refused · sock=/tmp/tmux-1000/default · TMUX=- · TMUX_TMPDIR=- · argv=kill-server · pid=… ppid=… cwd=<home>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify
main rotation:
2026-09-29T19:25:51+00:00 · rotation · dropped=1302
identity after rotation: MATCH, main-copy: ABSENT, pass-retention: UNCHANGED
retention rotation with marker-text inside FIRST argv:
2026-09-29T19:25:51+00:00 · rotation · dropped=1101
retention size=1001 (1 marker + 1000 calls)
directory failure call: … act=allowed-owned … argv=kill-window -t p133own:dev … retention=failed
FIFO refusal: rc=64, retention diagnostic=✗ teamsmith tmux 闸门：…（/tmp/p133-forensics.*/scene/calls.log.forensics）…
exact scan (three named decoys; exact retention and bg silent):
…/docs/team/inbox/tmux-calls.log.forensics
…/.pi/team/state/nested/tmux-calls.log.forensics
…/.pi/team/state/tmux-calls.log.forensics.1
```

证据里的 default socket **仅为 shim 计算的路径文字**；`PATH` 中 `tmux` 是 scratch shim，`TEAM_TMUX_REAL` 是自写退出 7 的 argv 桩。拒绝 `kill-server` 退出 64 且不调用桩；允许的 own-target 到桩，退出 7 不变，逐字 argv 由桩核对。保留文件在第一次拒绝时与主日志 `cmp`，之后主日志追加 2300 条并由 `pass` 强制轮转，主日志丢失原行（`dropped=1302`），保留行与之前的保存副本 `cmp` 仍相同；`pass` 不追写。单独预置保留文件 2100 条（首行是含 ` · rotation · dropped=98765` 的 **argv 调用行**）再拒绝：按代码上限 `>2000 → 1000`，得到首行 `dropped=1101`、总行数 1001，不误认首行调用为 marker。目录与 FIFO 两种失败场景均无挂起，`retention=failed`、stderr `✗` 点名、退出码 7/64 不变。扫描函数从 `tests/smoke.sh` 原样提取；保留确切路径与 `bg/**` 静默，`.forensics.1`、nested 同名、inbox 同名逐条点名。

闸门字节核验由探针取 `git show d717bb93:skills/teamsmith/scripts/shim/tmux` 与现文件，对记录块（以唯一的 `# ── 记录` 和 `# ── 拒绝` 边界界定）**前后非空两翼**拼接后比较：前翼包含 socket 候选表、解析、绑定身份、判定；后翼包含拒绝文案及原样 argv/token exec。两翼逐字节相等。只检查代码字节，不宣称改变默认 socket 的行为。

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)                 # rc=0
$ bash docs/team/reports/P132-dev2/pkg/10-shim-retention.sh
== 10 结果 == ok=11 bad=0 finding=0 skip=0          # rc=0；作者包引用
$ bash docs/team/reports/P132-dev2/pkg/20-scan-exclusion.sh
== 20 结果 == ok=13 bad=0 finding=0 skip=0          # rc=0；作者包引用
```

相关原烟测段落在**隔离容器**跑过（详见 `fast-container.log`）：`31c` ✓241 ✗0 SKIP3；`30`（M16）✓27 ✗0；`12b-j` 保留文件静默 + `.forensics.1` 点名 + 八条泄漏腿均 ✓。选段重跑：`31c` ✓241 ✗0、`30` ✓27 ✗0，但依赖段与 `12b` 其它断言有红，**不能**报告为选段全绿。

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/container-tmux.sh -- bash skills/teamsmith/tests/smoke.sh
fast_rc=2：容器内 BusyBox flock 不认识 --close；锁排队超限，门禁根本没跑（fast.log）
$ bash skills/teamsmith/tests/container-tmux.sh --cmd 'TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh'
fast_container_rc=1：✓2963 ✗159 SKIP40（fast-container.log）
$ bash skills/teamsmith/tests/container-tmux.sh --cmd 'TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash skills/teamsmith/tests/smoke.sh --select 31c,30,12b'
relevant_rc=1：✓524 ✗6 SKIP10（relevant.log）
```

FAST 在容器的环境前置不成立：runner 只将当前 worktree **只读**挂载且不挂 git common dir；`0d` 报「找不到受检的 git 工作树」，多个嵌套 smoke 依赖同一条件级联；镜像是 BusyBox `flock`（不支持 `--close`）并缺 `perl`，选段的 `31` 明确红「没有 perl」；容器下看门狗/其它段也红。没有将这 159 项冒称产品回归，也没有冒称 FAST 通过。安全边界不允许在宿主真实默认 tmux socket 上补跑同一套破坏性烟测；**全量未跑**（任务书可选）。

**环境修正及最终 FAST 证据（本人重跑，不是借用 PM 或作者结果）**：按 PM `docs/team/threads/verify.md` 的 B 配方从当前任务分支做独立 `/tmp/p133-*/clone`，用 `distrobox-host-exec podman` 启动已有 `localhost/teamsmith-gate:local`，先检查容器 `/tmp/tmux-$(id -u)/default` 不存在才运行 smoke；该 Debian 镜像已有 `flock --close`、`perl` 且 clone 有完整 git 元数据。第一次完整镜像执行 `rc=1, ✓3151 ✗1 SKIP34`（`fast-gate-image.log`）：唯一红是 §40 缺 `ss`（P122 陈旧 socket 未被数出来）；§31c `✓241 ✗0`、§30 `✓27 ✗0`、§12b `✓80 ✗0`。为了不掩盖红项，本人在一次性的派生镜像 `localhost/p133-gate-ss:local` **仅安装 iproute2（提供真实 `ss`），不改门禁或其断言**；同一独立 clone 形状重新跑 FAST，随后删除该自有镜像与临时 clone：

```
$ # 派生镜像 Dockerfile: FROM localhost/teamsmith-gate:local; USER root; RUN apt-get update -qq && apt-get install -y -qq iproute2 ...
$ # git clone -q "$PWD" "$D/clone" && git -C "$D/clone" checkout -q task/P133-p133
$ # distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id --user <user> -e HOME=/tmp -v "$D/clone:/work" -w /work localhost/p133-gate-ss:local bash -c '[ ! -e /tmp/tmux-$(id -u)/default ] || exit 77; command -v ss; TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'
/usr/bin/ss
# fast-gate-final.log, process rc=0:
账本自查：115 段收口 · 增量 ✓3152 ✗0 SKIP34 ｜ 结果行 ✓3152 ✗0 —— 一致
== 结果 ==  ✓ 3152  ✗ 0
smoke 全绿
```

- Verdict: 业务焦点的独立 stub/scan 实验 **PASS**，规格验证 **PASS**，作者包引用 **PASS**，FAST 全绿 **PASS（✓3152 ✗0，34 个 FAST 预期 SKIP）**；全量可选未跑，PM 须独立复验后才能决定后续归档。
- Spec completeness: `openspec/changes/destructive-call-forensics/tasks.md` 的 apply/verify checkbox 仍是规划态 `- [ ]`；本任务无权改提案账本，请 PM 在阶段收口时核查。

## Flip evidence

```
$ bash docs/team/reports/P133-verify/probe.sh    # scratch 文件里分别故意破坏；生产代码从未修改
RED #1: shadow without long-retention append: original must survive rotation → FAIL (no retained line)
RED #2: basename exclusion: nested decoy must be named → FAIL (missing nested/tmux-calls.log.forensics)
RED #3: wildcard marker parser swallowed first call-shaped line: … rotation · dropped=1100 (want dropped=1101)
GREEN: original shim and exact-path scan passed before both controlled mutations.
```

三条影子修改作用于 `/tmp/p133-forensics.*/bin/tmux`、scratch 提取的扫描函数，不改实现；红侧分别证「熬过轮转」会破、「按名字排除」会漏，以及 argv 含 marker 文字时宽泛 glob 会把调用错当标记（真实代码正确给 `1101`，破坏后错误给 `1100`）。完整逐行原始输出见 `probe.log`，作者自己的红侧另见 `author-10.log` 和 `author-20.log`。

## Decisions and deviations

- 按 D37/D57 严格安全约束：真实 default socket 上连示范/探测都不做；容器 runner 正常调用没有触发宿主指纹模式，独立探针下游永远是桩。故 FAST 选择独立 clone + 全套门禁镜像；缺 `ss` 时补齐容器依赖再重跑，不绕过保护改成宿主危险跑法。初始 Alpine FAST 红输出保留作为环境误用证据。
- 第一次选段误用内部断言名 `12b-j` 当 `--select` key，命令报未知 key、未执行；改为 `12b` 后如上，不能算全绿。

## Suggested next steps

PM 在独立 checkout 复验本分支原始探针、最终 FAST 及规格验证；审核本报告与前面的环境红记录，不能只看绿结论。change 是否归档仍由 PM 按用户确认与最终保护分支门禁决定。
