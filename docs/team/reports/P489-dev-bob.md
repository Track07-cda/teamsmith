# P489 · 补齐提醒测试的两条等待记录

agent: dev-bob   status: DELIVERED（作者静态核对）   time: 2026-11-23T10:40:44Z

branch: `task/P489-reminder-wait-loop-inventory`   PR/MR: -

## 结论与交付

原样运行现有静态扫描，修前是 86 条登记 / 88 个循环（退出 1），修后是 88 / 88、全部配对（退出 0）。只有清单增加了两行；循环、扫描器、套件和发布包均未改。§0e 由 V186 独立复验，本报告不把静态通过算作发布自检通过。

| 路径 | 变更 |
|---|---|
| `skills/teamsmith/tests/loop-inventory.tsv` | 按源码顺序补登 `remind-tool-real.sh:37` 和 `:39`，保留原文锚点。 |
| `docs/team/reports/P489-dev-bob.md` | 作者的修前、修后静态证据及未验证范围。 |

基线 `986f37fb3200c33aba492b2fc358b378b481a695`；清单提交 `7ee3db91b6b6852d06a1661b650aa08d2923df04`。V186 的原失败另见 `0d3deddb9f980940143492ac9ab7450229665c91:docs/team/reports/V186-verify.md`（214 通过、3 失败、3 跳过，退出 1），不是本席位实跑。

## OpenSpec 锚点与两条上限

只核对 `openspec/specs/verification/spec.md` 的 `Every wait in the gate is bounded and attributes at its cap` 中关于静态登记的要求；不改规格，不据此评定运行时行为。

- 第 37 行用 `bound=`：第 70 行先取得进程身份快照，第 86 行将其作为参数传入；外层只读 `done <<< "$1"` 提供的固定输入，到 EOF 即退出，不会等待新条目。内层用同一个截止时间，超时直接从函数返回，不为下一条重新计时。
- 第 39 行用 `cap=SECONDS >= deadline`：第 36 行在两层循环前设置 `deadline=$((SECONDS + 10))`；仍存活且身份未变的进程到点时，第 47–49 行打印 PID 并返回 1。进程消失、启动刻度变化或不再存活则提前结束轮询。扫描器核对第 47 行比较式仍在循环内；10 秒的定义及提前退出条件来自源码阅读，不是运行时测量。

## 验证证据与修前对照

```text
# 修前；在任务基线上运行
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
bad: remind-tool-real.sh 的 while+sleep 循环数 2 ≠ 清单行数 0（新循环/漏登记/顺序变化都要点名并补清单）
bad: remind-tool-real.sh:37 是未登记的 while+sleep 循环：  while IFS=: read -r pid started; do
bad: remind-tool-real.sh:39 是未登记的 while+sleep 循环：    while [[ -d "/proc/$pid" ]]; do
ok: 扫描 86 行清单 / 88 个 while+sleep 循环，配平 86 个
section-guard --loop-check: 1 条不成立
rc=1

# 修后；同一条静态扫描命令
$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 88 行清单 / 88 个 while+sleep 循环，配平 88 个
section-guard --loop-check: 全过
rc=0

$ awk -v REL=remind-tool-real.sh -f skills/teamsmith/tests/lib/loop-scan.awk skills/teamsmith/tests/remind-tool-real.sh | cut -f1-4
remind-tool-real.sh	37	  while IFS=: read -r pid started; do	closed
remind-tool-real.sh	39	    while [[ -d "/proc/$pid" ]]; do	closed

$ git diff --check
# 无输出，退出 0
$ git diff --numstat
2	0	skills/teamsmith/tests/loop-inventory.tsv
$ git diff HEAD^ HEAD --name-status
M	skills/teamsmith/tests/loop-inventory.tsv
```

- **判定：** 作者静态扫描与写入范围检查通过；未执行 §0e 的故意加错及还原场景、其它测试、真实提醒、模型或全量检查。
- **Ledger ban：** 未执行。任务书只允许静态循环扫描、两条说明、写入范围及 `git diff --check`；无 `hits` 或退出码可报。
- **偏离：** 无。本地交付，未推送、未发布。
- **下一步：** V186 在独立检出定点运行 §0e，确认干净树通过、故意增加未经登记的循环会失败、还原后再次通过。保留此前的发布自检失败记录。
