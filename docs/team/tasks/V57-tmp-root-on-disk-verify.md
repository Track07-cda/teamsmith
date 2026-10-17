# V57 · 临时根落磁盘：独立复验（自造三种现场 + 三条红侧）

task: V57
agent: dev3
phase: verify
category: verify
change: tmp-root-on-disk
specs: verification
deltas: -
branch: task/V57-tmp-root-on-disk-verify
deps: P309（已交付，冻结 tip 见**收据文件** `reviews/V57/freeze-receipt.txt`）｜提案 `docs/team/reviews/tmp-root-on-disk-proposal.md`（准入条件在其中）

## 必须自己做的（不许只复跑作者脚本）

1. **三种现场**：① **选定的根不可写**（`TEAM_TMP_ROOT=<只读目录>`）→ **具名失败 + 给修法**，**不许静默退回 `/tmp`**；② **两根都不设** → Linux 上落在 `/var/tmp/teamsmith-<ns>`，且运行期间**`/tmp` 下不落任何东西**；③ **`TMPDIR` 与 `TEAM_TMP_ROOT` 冲突** → 用 `TMPDIR`，**并且打印出来用了哪个**（不许静默覆盖）。
2. **地板绑定**：把选定根设成一个**很空**的目录、同时让 `/tmp` 的读数很紧（可用桩或小 tmpfs 模拟即可）→ 派单/门禁**不许**因为 `/tmp` 而拒绝；反向（选定根很紧）→ **必须**拒绝并**点名那个根**（不是 `/tmp`）。
3. **三条红侧自己造**：① 解析改成各处自算 → 必须红；② 地板检查指回固定 `/tmp` → 必须红；③ 根不可写时退回 `/tmp` → 必须红（这正是「静默退回」那条禁令）。
4. **socket 与临时根解耦**：核 P310 之后 socket 基址**不随临时根变深**（作者加了一条「回退到系统临时目录」，你要证明它是**唯一**的短路径来源、且**没有**让「根不可写 → 悄悄用 `/tmp` 当根」这条禁令出现漏洞）。
5. **既有红清单**（D198）：随机抽 **2 条**（例如 `54` 的 19 条、`routes` 的 10 条）在**未改动的 main 副本**与**受检树**上各跑一次，确认**同名同数**——若受检树更差 → FAIL。
6. **不回退**：`tmp-hygiene.sh --self-test`、`--all`、`--flip` 各跑一次；`smoke.sh --select <闭包>` 贴结果；跑前跑后 `/tmp` 与 `/var/tmp` 的根数各数一遍（新增的根必须在报告里点名归属）。
7. 计时类按 D192；容器里先 `mkdir -p` 再设 `TMPDIR`（D189）；受检 tip 以收据为准（D196）。

## 交付

`docs/team/reviews/V57.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc；三种现场与三条红侧的原始输出；既有红对照的两组数字；写明运行模型与 loadavg）；不改候选、不合并、不推送；结论通知 PM。
