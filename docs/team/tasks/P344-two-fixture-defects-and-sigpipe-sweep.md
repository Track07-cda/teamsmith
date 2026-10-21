# P344 · 两处夹具缺陷（含又一次 `grep -q` + pipefail）与同族清扫

task: P344
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具缺陷与同族清扫
deltas: -
branch: task/P344-fixture-defects-sigpipe

## 依据（P343 的只读归因，`docs/team/reports/P343-dev3.md`）

两条都是**夹具缺陷**，产品行为是对的：

1. **§51 `C2/tmp-root-mkdir`**：那条走查在拒绝路线里只设了 `TEAM_TMP_ROOT`，而产品的文档化优先级是 `TMPDIR > TEAM_TMP_ROOT`。环境里**导出过 `TMPDIR`** 时（我今晚跑地板就是），产品的选择合法地变成 `TMPDIR`，走查却仍期望「拒绝」，于是 rc=1。摘掉 `TMPDIR` 后 `✓28 ✗0`、整段 `✓253 ✗0`。
2. **§41 ④**：等待循环 `roster | grep -q '在跑' && break` 在 `set -o pipefail` 下**恒为 141**（`grep -q` 命中即退 → `roster` 吃 SIGPIPE）——循环**一次都没有 break 过**（8/8 次返回 141），P316 把上界从 6 s 提到 300 s 之后正好等于假 agent 的寿命（`sleep 300`），窗口在断言读到之前关闭，于是报「无窗口」。

第 2 条与 P326 在 11c 修掉的那个**是同一个 bug 家族**（`grep -q` + `pipefail` + `!`）。

## 要做的

1. **§51**：让那条走查**显式**决定用哪个源（要么同时设 `TMPDIR` 与 `TEAM_TMP_ROOT` 并断言产品选 `TMPDIR`，要么明确只测 `TEAM_TMP_ROOT` 那条路径并先 unset `TMPDIR`），**不许**靠环境碰巧没导出。注释写明产品优先级与这条走查测的是哪一支。
2. **§41 ④**：把「管道 + `grep -q`」换成**先落变量再匹配**（P326 在 11c 的写法就是范式），并且那条上界**不许**等于被等对象的寿命——上界只防死等，耗尽时报「没等到 X（挂住）」，不许让窗口在断言读之前自己关掉。
3. **同族清扫**：全树（`skills/teamsmith/tests/**`、`skills/teamsmith/scripts/**`）搜 `| grep -q` / `grep -q` 在 `pipefail` 下的用法，逐处判「会不会因 SIGPIPE 得到假失败」，把**会**的改掉；**逐条列表**（原文 → 判定 → 处置），不会的也写一句为什么不会（例如不在管道里、或没有 `pipefail`）。
4. **红侧**：§51 那条在 `TMPDIR` 导出时也必须绿（这是本次的根因场景）；§41 那条把等待改成永不 break 时必须红并点名。
5. 验收：`--select 51,41` 在**默认源**与**导出 `TMPDIR`** 两种环境下各跑一遍，四次都必须全绿；贴四个 rc 与段尾。另跑 `section-select.sh --check`、`bash -n`、账本禁令固定验收行、`git diff --check`。

## 边界

- 写集：`skills/teamsmith/tests/routes.sh`、`skills/teamsmith/tests/smoke.sh`（只这两处缺陷 + 同族清扫命中的位置）、`docs/team/reports/P344-dev3.md`。
- 不改产品实现（两个产品行为都对）、不改 `TMPDIR` 优先级、不加门禁段、不改别的断言。
- 若同族清扫里有一处**必须**改产品或规格，停下来写成 `BLOCKED:` 交回，不要自己扩大写集。

## 返修（V84 判 PARTIAL 之后；优先于上文）

V84（`docs/team/reports/V84-verify.md`）确认两处夹具修复成立并已现场取证，但**同族清扫的账不闭合**。三件事：

1. **账不闭合**：产品面它数到 **19 处**，你的报告只点 13 处——缺的 6 处全在 `outbox.sh`。把这 6 处补进表里（原文 → 判定 → 处置），并说明你为什么漏了它们（是搜索范围、还是判据不同）。
2. **两条「不会」的理由不成立**：`§36③` 与 `§36⑦` 你判「不会」，验收判「会」。逐条重判并给证据；若确实是「会」，按同族修法改。
3. **`§36③` 的红标检查是死断言（两版都是）**：它拿**带 ANSI 的标记**去 grep **去色后**的文件，永远命中不了。改成先算去色文本再匹配（或直接比较去色后的整块），并给「标记真的在 → 绿 / 标记不在 → 红」两个方向的实测。

改完交同一席位（V84 的验证者）第二轮定点复看，只看这份增量。**产品里那两处（`common.sh`、`cmd-status.sh`）不用你管**，已另立 P350。

