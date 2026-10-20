# V72 · P335 的独立定点验收：诊断行不再让 shell 的报错顶替读数

task: V72
agent: verify
phase: verify
category: verify
change: -
specs: pm-lifecycle#A PM that is starting is a state, not a missing PM
deltas: -
branch: task/V72-launch-diag-verify

## 受检对象与范围

候选 `a5fd7adda2dd`（实现提交 `f7127401`），报告 `docs/team/reports/P335-dev-bob.md`。改动只有 `skills/teamsmith/scripts/lib/common.sh` 里 `team_pm_launch_diag` 的一处读数（18 行）——PM 已看 diff、`bash -n` 通过。

注意：该分支还落后 main 两处（`docs/team/BOARD.md`、`docs/team/reports/V71-dev2.md`），**那两处不是本任务内容**；PM 合并时会保留 main 的版本。你的判定只针对产品那一处。

## 要回答的问题

「`pm-launch-tail.txt` 不存在时，诊断里不再出现来路不明的 shell 报错、也不再把字节数印成空白」这件事是否真的成立，且没有被换成另一种吞法？

## 必须自己做的（各给命令与原始尾部）

1. **反例（核心）**：用你自己的夹具（私有磁盘 `/var/tmp/…`、不启 tmux、不碰任何席位的现场）让 `team_pm_launch_diag` 在一个**不存在** `pm-launch-tail.txt` 的状态目录里跑：
   - `2>&1` 合并看：**不得**出现 `No such file or directory`，必须是一句具名说明（点名「未写出」之类）；
   - `2>` 单独收：stderr 字节数必须是 **0**；
   - 同一现场把 `common.sh` 换回改动前（`git show <候选>^:skills/teamsmith/scripts/lib/common.sh`）再跑一次，必须**能复现**那条 shell 报错与空数字——否则你的夹具没测到这件事。
2. **正向不变**：`pm-launch-tail.txt` 存在且非空时，`pane` 行与 `--- pane（…）---` 段与改动前**逐字节相同**（用同一夹具跑改前/改后并 `cmp`，贴结果）。
3. **空白尾屏**：文件存在但只有空白 → 仍走「从外面重抓 / 或明确说窗口已不存在或始终空白」原分支（贴输出，证明这条逻辑没被这次改动碰到）。
4. **没有换成另一种吞法**：静态核对这一处不再有 `2>/dev/null` 挂在读数上，也没有 `|| true` / `if fail then :`；判了存在之后读失败的那条分支是具名的一句话。
5. 轻量收口：`bash -n`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`；若你想跑受影响的门禁选段，先确认 `ps` 里没有别人的 `smoke.sh`（**不要**跑整套，也不要抢机器级门禁锁）。

## 边界与交付

只读代码、只写 `docs/team/reports/V72-verify.md` 与自己的线程；不改实现，不合并，不 push，不跑容器/整套/计时实验。结论先写 PASS/PARTIAL/FAIL，再给证据；没跑到的如实写「未验」。local 模式，交付后由 PM 合并与关单。
