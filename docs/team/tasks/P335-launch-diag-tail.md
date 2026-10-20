# P335 · PM 启动失败诊断里那两个空答案：别让 shell 的报错顶替读数

task: P335
agent: dev-bob
phase: apply
category: code
change: -
anchor: openspec/specs/pm-lifecycle/spec.md#A failed PM launch leaves a diagnostic that explains why
deltas: -
branch: task/P335-launch-diag-tail

## 问题（V71 独立复核时读到，PM 已核代码）

`skills/teamsmith/scripts/lib/common.sh` 的 `team_pm_launch_diag`（约 3401 行）：

```bash
printf 'pane   : %s（%s 字节）\n' "$tailf" "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"
```

`pm-launch-tail.txt` 不存在时（假 CLI 秒退、harness 还没写出那份尾屏），两件事同时发生：

1. **shell 自己的重定向报错漏到 stderr** —— `bash: …: No such file or directory`。`2>/dev/null` 写在 `< "$tailf"` **之后**，shell 在处理重定向时还没应用它，所以这条消息照样出现。V71 在 11c 的 `up-agents.log` 第 3 行亲眼看到过它。
2. **字节数印成空**：重定向失败 → `wc` 不跑 → 管道里 `tr` 正常退出（0）→ `|| echo 0` 不触发 → 那一格是空白，读者看到「（ 字节）」，像是工具没答上来，而其实答案是「这份文件还不存在」。

诊断文件是给人读的（PM 在 PM 起不来时第一眼看它），一条来路不明的 shell 报错加一个空数字，会让人以为诊断本身坏了。

## 要做的（两处，最小）

- 先判存在再读数：文件不在就**明确写出来**（例如 `（未写出：harness 还没落这份尾屏）`），不许再用重定向去试。
- 文件在就照旧给字节数与原有内容分支；`[ -s ] && grep -q '[^[:space:]]'` 那段「只有空白不算抓到」的逻辑**一个字不动**。
- 不许把 `2>/dev/null` 换成别处的吞法（`|| true`、`if fail then :`）；这个项目的纪律是**能点名就点名**：查不到要写成「查不到什么」，不是把声音关掉。
- 不新增函数、不改诊断文件的其它段落、不动 `team_pm_launch_tail_file` 的路径解析。

## 必须交的证据

1. **反例（就是今天的形状）**：在一个私有夹具里让 PM 启动失败且 `pm-launch-tail.txt` 不存在（复用现有 11c 的假 pi 秒退形态最省事，或直接在夹具里调 `team_pm_launch_diag` 并保证那份文件缺失）——改前改后各跑一次，贴原始输出：改前必须能看到那条 `No such file or directory` 与空数字，改后必须是具名的一句、且 **stderr 干净**（给出 `2>&1` 的完整尾部，以及单独 `2>` 收 stderr 的字节数）。
2. **正向**：`pm-launch-tail.txt` 存在且非空时，诊断照旧打印 `pane` 段与字节数（贴输出），证明没有把这条能力改坏。
3. **空白尾屏**：文件存在但只有空白 → 仍按原规则走「从外面重抓 / 或明确说窗口已不存在或始终空白」（贴输出）。
4. 轻量收口：`bash -n skills/teamsmith/scripts/lib/common.sh`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。
   若你能顺手跑受影响的门禁选段（例如 11c）就跑一次并贴读数；跑之前确认没有别人的门禁在跑（`ps` 里没有 `smoke.sh`），**不要**跑整套。

破坏只做在自己的磁盘目录（`/var/tmp/…`，私有 `TMPDIR`）；不要动别的席位的运行与现场。

## 边界

- 写集：`skills/teamsmith/scripts/lib/common.sh`（**只有 `team_pm_launch_diag` 里那一处读数与它必要的分支**）、`docs/team/reports/P335-dev-bob.md`。
- 不碰测试文件（`tests/**` 目前归 P326/P333/P334 的单写者链）、不碰别的 `cmd-*.sh`、不改诊断文件格式的其它行。
- 净零：这条修的是「诊断里两个空答案」，没有新增检查器或门禁段。
