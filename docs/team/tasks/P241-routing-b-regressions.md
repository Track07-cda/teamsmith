# P241 · 修 routing 合并引入的 12 条产品回归（B2 + B3）

task: P241
agent: dev
phase: apply
category: code
change: task-model-routing
specs: pm-lifecycle, dispatch
deltas: -
branch: task/P241-routing-b-regressions
deps: V25（红清单分类：`docs/team/reports/V25-verify.md`，A=210/B=14/C=0/D=0）；B1（`resume --dry-run`）已由 P240 修在 main `e09a710`

## 缺陷（V25 已逐条复现，PM 已读码确认机制）

全量门禁在合并 tip `14499ed` 上是 `✓4478 ✗224`；其中 **B 类 14 条**是真产品回归，B1（2 条）已修，**本任务修剩下的 12 条**：

### B3（11 条：§11c 6 条 + §15b 5 条）——`inbox --ack` 的记账键把席位变成 legacy 记录

三步机制（PM 读码确认）：

1. 某席位被 `team close`（或任何路径）清掉记录 → `state/<seat>.env` 不存在；
2. 之后任何 `team inbox --ack` → `cmd-status.sh:929` 调 `team_state_set <seat> inbox_lines <N>`；`common.sh` 的 `team_state_set` 在**文件不存在时会新建**，于是 `state/<seat>.env` 里只有 `inbox_lines=N`；
3. 该席位下一次**非 fresh** 派单 → `team_dispatch_identity_recover` 读到这个文件 → `team_assignment_parse`（`common.sh:1441` 起）要求 `assignment_version=1` → 判 `legacy/unknown assignment_version` → **拒绝派单并要求 `--fresh`**（现场原文：`✗ dev: legacy/unknown assignment_version；保留磁盘交接，dispatch dev T1.1 … --fresh`）。

影响：任何「关掉席位记录 → 之后 ack 过收件箱」的项目，该席位下一次派单都会被无故拒绝。

**要求（两条都做）**：

- **主修**：收件箱记账**不要写进 assignment 文件**。用 sidecar（例如 `state/<seat>.inbox` 或 `state/inbox-lines/<seat>`），并保证读回（`team_inbox_total`/展示）仍工作；`team close` 清记录时 sidecar 一并处理（清或保留都要有明确语义并写进报告）。
- **防御**：identity recovery 把「既没有 `assignment_version`、也没有任何 assignment 字段」的文件当作**没有记录**（非 fresh 走正常恢复/拒绝路径而不是 legacy 拒绝）；只有真正带 legacy assignment 字段（`task=`/`branch=`/`model=` 之类）的记录才按 legacy 报错。给出这条判据的红侧：一个只有无关记账键的文件不得触发 `legacy/unknown assignment_version`。

### B2（1 条：§11b4）——`common.sh` 单独被 source 时 PM 启动路径崩

现象：单独 source `scripts/lib/common.sh` 后走 PM 启动路径报 `team_config_model_violation: command not found`。要求：消除这个**定义顺序/自足性**缺陷（函数在使用点之前可用，或调用点做存在性守卫并给出可读诊断）；红侧：在**只 source common.sh** 的干净 shell 里走同一路径，改前报 `command not found`、改后不报且行为与全量加载一致。

## 边界

- 只碰 `skills/teamsmith/scripts/lib/**`（B3 主修在 `cmd-status.sh`，防御与 B2 在 `common.sh`；如必须动 `cmd-agents.sh` 请先说明理由）。
- **不要碰 `skills/teamsmith/tests/**`**（`smoke.sh`/两张 tsv 正被 P238 持有；夹具侧的 210 条 A 类修复另有任务）。
- 不许删/skip/改夹具换绿；不许回退 routing 的既有语义（类别映射、同任务复用记录的 model/SID、换 model 必须 `--fresh`、发布身份不得多于 argv 交付）——`task-model-routing.sh --select dispatch,resume,transaction,pm,config` 必须仍全绿。
- 不合并、不推送；做完 `team notify pm`。

## 验收命令（报告里贴真实输出）

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
# B3 的两个复现（V25 给的选集；容器 + 干净 clone，都要贴改前/改后）
#   改前：--select 7,7b,8,11b,11b2,11b3,11b4,11,11c  → §11c ✓8 ✗7（含 legacy 拒绝）
#   改后：同一命令 §11c 的那 7 条红应当消失（或只剩与本任务无关的、且要逐条说明）
bash skills/teamsmith/tests/task-model-routing.sh --select dispatch,resume,transaction,pm,config
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

补一条你自造的**端到端小现场**（不必用门禁夹具）：干净夹具里 `team close` 某席位 → `team inbox --ack` → 非 fresh 派单必须**成功**（改前必须复现拒绝），并把两侧的状态文件内容贴出来。

## 交付

`docs/team/reports/P241-dev.md`（两条缺陷各自的复现、根因、改动、改前红/改后绿、routing 组仍绿、未做项）；证据包按 D94 放仓外；之后由未写过本任务的席位独立复验（复验基线必须是 **v0.1.2 全量**或 PM 指定的绿色树，不许拿父 tip）。
