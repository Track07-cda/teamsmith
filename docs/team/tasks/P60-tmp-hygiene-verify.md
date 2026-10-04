# P60 · test-tmp-hygiene 独立验证（verify 阶段）

```
task:   P60
agent:  verify
issue:
change: test-tmp-hygiene
specs:  verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed / verification#Killed-run residue is identifiable and reclaimable / verification#The sweep proves occupancy and touches this family only / verification#The gate reports its own temp-root usage / verification#The fixtures' temp-root ownership rule is enforced / watchdog#team doctor reports the temp root's headroom
phase:  verify
anchor: change
deltas: verification, watchdog
grant:  docs/team/reports/P60-verify.md · docs/team/reports/P60-verify/**（只写报告与证据，不改实现）
deps:   P50（propose）· **P53（apply，dev3）**——apply 作者不是你
status: todo
budget: 一个工作块（只写复验证据与报告）
```

> 本地模式：不 push。**apply 是 dev3 做的 → 你来验（D31）。**

## 要对抗性验证的（每条给可复现命令 + 原始输出）

1. **TMPDIR 解析**：`TMPDIR=D` 下每个**创建临时根的夹具**（至少 `config-cli.sh`、`panel-choices.sh`、
   `panel-p21.sh`、`install-shape.sh`）都必须在 `D` 下建根、跑完**零残留**；
   **反向**：`TEAM_TMP_KEEP=1` → 根**留下**并打印路径。
2. **回收三态**：正常退出 / `INT` / `TERM` 都回收；`TERM` 中途还要把**记录的 anchor pid** 一起收掉
   （自己去起一个出界进程验）。
3. **sweep 的两条红线**：占用中的根**必须跳过并点名持有者**；无占用的陈旧根**列进可回收**；
   **范围外**（不属于本仓库 owned 家族的名字）**一条都不许动**（自己造一个 `not-ours-*` 验）。
4. **lint**：故意写一个"硬编码 /tmp + 没有 owner 标记"的夹具 → `--lint` 必须红并点行；还原绿。
5. **doctor 余量行**：正常时安静/有读数；把临时根填满（或把阈值旋钮调小）→ 行必须可见地降级。
6. **D37**：读实现确认"只对记录的 pid 发信号"；**结构钉**：文件里没有按名字/命令行匹配的信号选择。
7. **零回归**：FAST + 全量 smoke、`openspec validate --all --strict`。

## 至少三条变异（红→绿原始输出）

- 让某个夹具退回硬编码 `/tmp` → `--lint` 红；
- 去掉 sweep 的占用证明 → 占用中的根被删（红侧证据）；
- 去掉 `TERM` 的回收 trap → 残留（红侧证据）；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
bash skills/teamsmith/tests/tmp-hygiene.sh --self-test
bash skills/teamsmith/tests/tmp-hygiene.sh --lint
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
```
