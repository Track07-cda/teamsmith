# P53 · test-tmp-hygiene apply：一个拥有者助手 + 回收集 + 占用可见

```
task:   P53
agent:  dev3
issue:
change: test-tmp-hygiene              # 提案已验收：docs/team/reviews/test-tmp-hygiene-proposal.md（ACCEPTED）
specs:  verification#A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed / verification#Killed-run residue is identifiable and reclaimable / verification#The sweep proves occupancy and touches this family only / verification#The gate reports its own temp-root usage / verification#The fixtures' temp-root ownership rule is enforced / watchdog#team doctor reports the temp root's headroom
phase:  apply
anchor: change
deltas: verification, watchdog
grant:  skills/teamsmith/tests/lib/tmp-root.sh（新）· skills/teamsmith/tests/tmp-hygiene.sh（新）· skills/teamsmith/tests/*.sh（改为经助手创建/回收）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/scripts/lib/cmd-status.sh（doctor 行）· skills/teamsmith/references/{protocol,troubleshooting,config}.md（若需一句）
deps:   P50（propose，已合并）· D37（只对记录的 PID 发信号）
status: todo
budget: 一个工作块（B1 助手+回收 / B2 sweep / B3 门禁与 doctor / B4 夹具迁移）
overlap: ⚠️ P47（dev-bob）同时在改 `cmd-status.sh`；你的 doctor 行放**文件末尾**、小步提交，冲突由 PM 解决。
```

> 本地模式：不 push。**真源 = `openspec/changes/test-tmp-hygiene/{design.md,tasks.md}`。**

## 要点

1. **`tests/lib/tmp-root.sh` 是唯一创建者**：根在 `${TMPDIR:-/tmp}`（**消灭写死 `/tmp`**，含 `smoke.sh:215`）、
   名字在 owned 家族、根内写 owner 标记（pid/启动时间/kind/run id）、记 run 台账；
   **正常退出与 `INT`/`TERM` 都回收**，`TEAM_TMP_KEEP=1` 才留（打印路径）。
2. **越界进程按 D37**：出界进程 spawn 时记 pid，cleanup **只对记录的 pid** 发信号（禁止名字/命令行匹配）。
3. **sweep**（`tests/tmp-hygiene.sh`）：只碰 owned 家族、**先证明无占用**、打印清单与总量；
   一个可证伪的红侧：伪造一个"占用中"的目录 → sweep 必须跳过。
4. **门禁自报用量** + `team doctor` **临时根余量**行（`df -h` 与 `df -i` 都看）。
5. **夹具迁移**：把 `config-cli.sh` 等创建的临时根改经助手（这是 3.2G 泄漏的源头）；
   迁移时**别改夹具语义**（只改根的位置与回收）。

## 必给的翻转（红→绿原始输出）

- `TMPDIR=D bash tests/config-cli.sh` → `D` 下跑完**无残留**（改前会留 44MB 目录）；
- `TERM` 中途发 → 根在宽限期内消失 + 记录的 anchor pid 不再存在；
- sweep：占用中的目录被跳过（红侧）/ 陈旧无占用的被列出（绿侧）；
- doctor 的余量行：临时根被填满时**可见**（可用一个小 tmpfs 或把阈值调小模拟）；
- 还原后 `git status --porcelain` 干净。

## Acceptance

```sh
bash skills/teamsmith/tests/tmp-hygiene.sh --status
bash skills/teamsmith/tests/tmp-hygiene.sh --sweep --dry-run
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
```

## Boundaries

- 只碰 `grant:` 列出的路径；**不改**夹具的判定语义、不改 D33 口径；
- **不许对不属于自己的进程发信号**（D37，违反即事故）；
- 不 push；不改 `docs/team/**`（报告除外）。
