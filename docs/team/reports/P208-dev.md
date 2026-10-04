# P208 · `sender-identity-refusal` 收尾：16 项 apply 清单按事实勾选

agent: dev   status: DELIVERED（local 模式：分支留本地、不 push；PM 复验后本地合并）   time: 2026-10-03T11:24Z（返工：PM 退回 4.4）
branch: `task/P208-apply`（分叉点 `4ba27059`；勾选提交 `ae8c8087`，报告与证据在其后）
任务书：`docs/team/tasks/P208-tick-sender-identity-tasks.md`
change: `sender-identity-refusal`   phase: `apply`
授权路径：`openspec/changes/sender-identity-refusal/tasks.md` · `docs/team/reports/P208-dev.md` · `docs/team/reports/P208-dev/**`
红线内：`skills/teamsmith/scripts/**`、`skills/teamsmith/tests/**`、`skills/teamsmith/references/**`、`openspec/specs/**` 一字未动（本次没有需要改的）

## 结论

| brief 项 | 状态 | 证据 |
|---|---|---|
| 1 逐条按事实勾选 16 项 | ✓ 16/16：15 条亲跑有据；4.4 按 PM 退回改成如实形态（P208 未附全量日志，全量由 PM 在最终发布门禁执行） | §1、§4 |
| 2 重跑 `--select 47` + `validate --all --strict` + 容器内 FAST | ✓ 三条全绿 | §2 |
| 3 报告只写这三件事的结果 | ✓ 本文件 | §1–§3 |

## 1 · 16 项按事实勾选（16/16）

判据（照任务书）：`- [x]` 只给**本人（dev）在 apply（P205）里实跑过**的项；P206（verify）的独立验证是旁证，
不作勾选依据；"只引用、自己没跑"的项要注明"引用 P206"——本次没有这样的项（15 项的证据全部出自 apply 作者
自己的 P205 运行；4.4 返工后见 §4）。逐项 → 证据：

| 项 | 判定 | 亲跑证据（P205，apply 作者本人） | P208 复跑 |
|---|---|---|---|
| 1.1 | [x] | `P205-dev/11-rebaseline-diff.txt`（恰 3 个 hunk：运行时目录改写、`TEAM_AGENT` 句、追加段） | `P208-dev/rebaseline-diff.txt`（同 3 个 hunk） |
| 1.2 | [x] | `P205-dev/12-scenario-inventory.txt`（无 `<` 行、恰 7 条 `>`、两边 11/18）+ `12b-baseline-verbatim.txt`（11 条基线逐字节保留、改写 0） | `P208-dev/scenario-inventory.txt` + `baseline-verbatim.txt`（同判定） |
| 1.3 | [x] | `P205-dev/41-42-validate-spec-refs.log`（14 passed / 0 failed；refs 104 条、49 distinct、undeclared 0） | `P208-dev/host-validate.log` + `host-spec-refs.log`（同） |
| 2.1 | [x] | `P205-dev/21-select47-green.log`：§47 ③d–③g 四条新运行（名册外窗口 / 名册外 `TEAM_AGENT` / 席位工作树+名册线索 / `--from` 带线索） | `P208-dev/host-select47.log`（§47 ✓81 ✗0；选段 ✓102 ✗0） |
| 2.2 | [x] | `P205-dev/flip-logs/red-B.log`（恰 4 条新非名册断言红，①② 不红）+ `green-B.log`（还原全绿） | `P208-dev/flip-p201.log`（影子 B 同判据） |
| 2.3 | [x] | `P205-dev/flip-logs/red-C.log`（③g 3 条红；无线索/名册外/席位工作树/窗口 pm/别的会话全绿）+ `green-C.log` | `P208-dev/flip-p201.log`（影子 C 同判据） |
| 2.4 | [x] | `P205-dev/flip-logs/red-D.log`（③f 3 条红；①② 仍拒、③g 仍胜）+ `green-D.log` | `P208-dev/flip-p201.log`（影子 D 同判据） |
| 2.5 | [x] | `P205-dev/25-flip-p201-final.log`（✓21 ✗0，四影子+还原）+ P205 报告 §6（三个自检） | `P208-dev/flip-p201.log` + `host-selfchecks.log`（budget/loop/select 全过） |
| 3.1 | [x] | `P205-dev/31-trial-run.log` + `trial-logs/*`：三条试跑（真树 validate 绿 / 丢一条基线 scenario → 点名失败 / scratch 归档 `~ 1 modified` + 归档后 18 scenarios + 退役句 0 + 拒绝段 1 + 未归档 change 0） | 未复跑：`trial.sh` 把日志写回 `docs/team/reports/P204-dev2/**`（授权路径之外）；P206 的 `pkg/contract.py` 独立复核了 11/18 的保留与新增 |
| 3.2 | [x] | P205 报告 §4：真树 `git status -- openspec/specs/` 空；scratch 树里归档目录在、未归档 change 目录 0 | `P208-dev/specs-clean.txt`：`git status --short openspec/specs/` 仍空 |
| 4.1 | [x] | `P205-dev/41-42-validate-spec-refs.log` | `P208-dev/host-validate.log` + `container-validate.log`（均 14/14） |
| 4.2 | [x] | 同上 | `P208-dev/host-spec-refs.log`（104 refs，undeclared 0） |
| 4.3 | [x] | `P205-dev/43c-container-fast-clone.log`（容器 FAST **3831 ✓ 0 ✗**）；宿主形态的那条红是 `12b-j` 环境假红（§3 有定性） | `P208-dev/container-fast.log`（§2.3） |
| 4.4 | [x] | `P205-dev/44-container-full.log` + `45-container-full-delivered-tip.log`（容器全量 **4566 ✓ 0 ✗** ×2，含交付 tip 复跑） | **未附全量日志**（PM 退回）：勾选依据是上面两次 P205 全量；按 PM 的二选一取 ②，清单文本改成如实形态——全量由 PM 在最终发布门禁执行并留证（§4） |
| 5.1 | [x] | `P205-dev.md`：1.1 diff / 1.2 清单 / 影子红绿 / 三条试跑 / 四条门禁尾巴 / delta→scenario 映射 / 改动路径 / 未测项 | 本报告 §1 复述映射 |
| 5.2 | [x] | `P205-dev.md` §5：四影子红行**逐条粘贴**（不是摘要）+ 各自还原绿跑 | `P208-dev/flip-p201.log`（还原前红 / 还原后绿） |

勾选后的进度实测（提交 `ae8c8087`）：

```
$ PATH="$HOME/.bun/bin:$PATH" openspec instructions apply --change sender-identity-refusal --json
{"total": 16, "complete": 16, "remaining": 0}
```

改动本身只有 16 行 `- [ ]` → `- [x]`（`git diff` 16 insertions / 16 deletions，文本未改）。

## 2 · 重跑（任务书要的三件）

### 2.1 `--select 47`（宿主；§47 的 `tmux` 是 shim，不碰任何真 server）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
#5 47 · P82 notify 发送者 = 运行时目录（notify-sender-identity） · 用时 3s · ✓81 ✗0 SKIP0 · ticks 81
账本自查： 5 段收口 · 增量 ✓102 ✗0 SKIP0 ｜ 结果行 ✓102 ✗0 —— 一致
== 选段结果 ==  ✓ 102  ✗ 0
rc=0
```

日志：`P208-dev/host-select47.log`（容器里同一条见 §2.3；选段不是全套门禁，未跑的 119 个键在日志里列名）。

### 2.2 `openspec validate --all --strict`（宿主，附 spec-refs）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 14 passed, 0 failed (14 items)
rc=0

$ PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 104 reference(s) (49 distinct) in 10040 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
```

日志：`P208-dev/host-validate.log` / `host-spec-refs.log`；容器内 validate 同样 14/14（`container-validate.log`）。

### 2.3 容器内 FAST（干净 clone + 一次性容器；共享 tmux server 从不参与）

形状与 P205 §7 / P206 `pkg/run.sh` 相同（worktree 的 `.git` 是挂载外的指针，容器判一棵 clone）：

```
$ git clone -q --branch task/P208-apply "file://<worktree>" /tmp/p208-mile   # HEAD ae8c8087
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id \
    -e HOME=/tmp -v /tmp/p208-mile:/work -v <worktree>/docs/team/reports/P208-dev:/evidence -w /work \
    localhost/teamsmith-gate:local bash -c 'git config --global --add safe.directory /work;
      openspec validate --all --strict; TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null;
      TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null'
```

（脚本：`P208-dev/container-run.sh`；容器 tip：`container-tip.txt` = `ae8c8087`。）

```
$ openspec validate --all --strict            → Totals: 14 passed, 0 failed (14 items)   validate exit=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
#5 47 · P82 notify 发送者 = 运行时目录（notify-sender-identity） · 用时 3s · ✓81 ✗0 SKIP0 · ticks 81
== 选段结果 ==  ✓ 102  ✗ 0                  select47 exit=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
#99 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 585s · ✓110 ✗0 SKIP0 · ticks 110
账本自查： 124 段收口 · 增量 ✓3836 ✗0 SKIP36 ｜ 结果行 ✓3836 ✗0 —— 一致
== 结果 ==  ✓ 3836  ✗ 0
smoke 全绿                                   FAST exit=0
```

（全量日志 `P208-dev/container-fast.log`（约 4.4k 行）、`container-select47.log`、`container-validate.log`、链条
`container-chain.log`；容器 FAST 用时约 1500s，跳过的 36 个真进程段在日志尾部逐个列名——FAST 不是全量门禁，
全量见 §1 的 4.4。）

### 2.4 附带复跑（§1 的证据刷新，不是任务书"三件"之外的新门禁）

- `bash skills/teamsmith/tests/flip-p201.sh`（四影子 + 还原，§1 的 2.2–2.5 证据）：

```
$ bash skills/teamsmith/tests/flip-p201.sh </dev/null
  ✓ 基线：未变异的树上 47 段全绿
  ✓ 影子 A：变异后 47 段变红（红点在 ①② 的 7 条预期断言上）；还原后 47 段全绿（82 条）
  ✓ 影子 B：名册过滤被拿掉后 ③d/③e（名册外名字）的断言变红；①② 仍拒绝；还原全绿
  ✓ 影子 C：拒绝挪到声明之前后 ③g（--from 带线索）的断言变红；无线索/名册外/席位工作树/窗口 pm/别的会话仍绿；还原全绿
  ✓ 影子 D：目录前提被拿掉后 ③f（席位工作树 + 名册线索）的断言变红；①② 仍拒绝、③g 声明仍胜；还原全绿
== 结果 ==  ✓ 21  ✗ 0
flip-p201 翻转成立（四个影子 + 还原）
rc=0
```

- 三个自检（`P208-dev/host-selfchecks.log`）：

```
$ bash skills/teamsmith/tests/section-guard.sh --budget-check
ok: 预算表覆盖 124/124 个 section 且每行都满足 max(ceil(band×4), 60)
section-guard --budget-check: 全过   (rc=0)
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 73 行清单 / 73 个 while+sleep 循环，配平 73 个
section-guard --loop-check: 全过   (rc=0)
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 7  bad 0  SKIP 0   (rc=0)
```

## 3 · 边界与偏差

- **未复跑**：3.1 的 `trial.sh`（会把日志写回 `docs/team/reports/P204-dev2/**`，不在本任务授权路径内；
  P205 证据见 §1）；4.4 的容器全量——PM 退回后按 ② 交给 PM 的最终发布门禁，见 §4。
- **4.3 宿主形态的已知假红**：P205 在宿主跑同一条 FAST 时有一条 `12b-j` 红 —— 真项目 `docs/team/inbox/verify.md`
  里一条合法消息与夹具的痕迹模式撞词（未跟踪运行时状态，与改动无关；完整定性见 P205 报告 §7 与
  `P205-dev/43-host-fast-red.txt`）。本轮按任务书跑容器 FAST，绿（§2.3）。
- **未测项**：没有真 tmux（§47 是 shim；真 tmux 行为由 P201 与 P205 的容器门禁覆盖）；没有模型调用。
- **改动路径**（本分支相对分叉点 `4ba27059`）：`openspec/changes/sender-identity-refusal/tasks.md`（16 行勾选 +
  4.4 的返工注记）、`docs/team/reports/P208-dev.md`、`docs/team/reports/P208-dev/**`（证据日志与三个复跑脚本）。
  `skills/**` 在本分支一字未改，且自 P205 的 `c220eb00` 起就没有再动过；`openspec/**` 的唯一变化是那 16 行勾选
  与 4.4 的注记（没有任何段读它：`grep -rn 'tasks\.md' skills/teamsmith/tests/*.sh` 只命中注释）。
- main 的 `89d67dd1`（P206 记录 + P208/P209 任务书，docs-only）没有并入本分支；与本次改动无重叠，合并不会冲突。
- local 模式：不 push；分支与证据留在本地 worktree，PM 复验后可合并。

## 4 · PM 退回与返工（2026-10-03T11:11Z）

PM 退回一处：4.4 勾了但 P208 证据里只有两次 FAST（`container-chain.log` 自己写着跳过 36 个真进程段），
全量没有日志；二选一：① 真跑一次全量并附日志；② 把 4.4 改成如实形态——"本人未跑；由 PM 在最终发布门禁执行"。

**取 ②**，理由两条：① PM 的最终发布门禁此刻正在跑（一次性容器 `frosty_kalam`，`/tmp/final-gate` = main
`89d67dd1` 上的 `openspec validate && smoke.sh` 全量，11:11:23Z 起），我再排一次全量就是同一台机器上的
重复门禁（AGENTS.md：整套门禁是机器的共享资源，一次一个）；② P209 的清单检查只数 `[ ]`、明确允许
"勾上并注明原因"的项，所以 4.4 保持勾选、只把文本改成如实形态。

改后 4.4 的文本（`tasks.md` 4.4 尾部）：

> **P208 ran no full suite (no log attached): the full run belongs to the PM's final release gate.** This tick
> rests on the apply's own two container full runs — 4566 ✓ 0 ✗ in `docs/team/reports/P205-dev/44-container-full.log`
> and `45-container-full-delivered-tip.log`.

其余 15 条不动；返工后的快速门禁见 §5。

## 5 · 返工提交之后的门禁

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict        → Totals: 14 passed, 0 failed (14 items)   rc=0
$ PATH="$HOME/.bun/bin:$PATH" bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 104 reference(s) (49 distinct) in 10040 effective line(s); retired 0; undeclared 0   rc=0
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 47 </dev/null
== 选段结果 ==  ✓ 102  ✗ 0   rc=0
$ PATH="$HOME/.bun/bin:$PATH" openspec instructions apply --change sender-identity-refusal --json
{"total": 16, "complete": 16, "remaining": 0}
```

日志：`P208-dev/rework-validate.log` · `rework-spec-refs.log` · `rework-select47.log`。

返工提交只动两处文本（`tasks.md` 4.4 的注记 + 本报告），没有任何段读 `tasks.md`（§3 的 grep 证据），所以
§2.3 的容器 FAST（代码 tip `ae8c8087`）与 §1 的其余证据继续成立；4.4 的全量由 PM 的最终发布门禁补上。
（上面这轮门禁跑在未提交的工作树上，结果与提交后的字节一致。）
