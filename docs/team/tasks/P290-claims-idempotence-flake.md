# P290 · `claims` 探针的幂等断言会看时钟跳变（PM 合并在容器里自测发现）

task: P290
agent: -
phase: apply
category: code
change: help-robustness
specs: help-surface
deltas: -
branch: task/P290-claims-idempotence-flake
deps: cli-help（`commands.tsv` 与 `claims` 探针由 P260 引入，均已在 main）；本任务是它的收尾之一

## 现象（PM 2026-10-15 合并后自测，冻结克隆 + 钉死容器）

`help-surface.sh` 在容器里 **✓105 ✗1**，唯一红：

```
✗ claims: mark-loaded 声明幂等，但第二次跑改了状态
```

**同一棵树、同一夹具**在宿主上（V41 的复验）是**全绿**——同一夹具在两个环境给出不同判定，这就是「看时钟跳变」的特征。

## 根因（我已定位到行）

1. `cmd-update.sh` 的 `team_cmd_mark_loaded` 每次都写 `AT=%s`（`team_timestamp` = `date -u +%Y-%m-%dT%H:%M:%SZ`，**秒**粒度）；`fp_dir` 比的是**内容**，所以只要两次调用**跨过一秒**，指纹就变 → 断言红。宿主上两次调用常落在同一秒内（快），容器慢一档就跨秒 → 红。**它是 flaky，不是产品回归**（P278 的 diff 没碰探针与那一行；两者都是 `5d42ff01` 引入的）。
2. 同时**清单那一行本身也不诚实**：`mark-loaded` 声明 `idempotent`，而它每次都写新时间戳——严格意义上不幂等。

## 要做什么（两条都要，且各自带红侧）

1. **让声明与行为一致**（二选一，你定并在报告里给理由）：
   - **(a) 让它真幂等**：版本号、skill 指纹、安装方式、会话 id 都没变时**不重写** `loaded.env`（保留既有的 `AT=`）→ 断言保持有牙且不再依赖时钟；
   - **(b) 改声明的取值**：从封闭词表里挑一个描述真实行为的（并在 `--help` 的说明里体现「会记录本次时间」）→ 探针按声明放行，但要在夹具里**指名**这个例外。
   我倾向 **(a)**：语义更好（「本会话 skill 版本」没变就不该刷新时间），断言也保住。
2. **把探针做成确定性的**：无论上面选哪条，`claims` 的幂等探针都**不许依赖挂钟**——若产品没有可注入的时钟，就比较**除已声明可变字段之外**的指纹，并把这条**指名**写在夹具里（不是静默放宽）。
3. **红侧**：① 造一个「第二次跑确实改了状态」的命令（例如临时给某个探针目标加一处写入）→ 断言必须**红并点名**；② 若选 (a)：把「无变化不重写」的条件去掉 → 必须红；③ 连跑 5 次同一段（宿主与容器各一次）**判定一致**。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/help-surface.sh --select claims
bash skills/teamsmith/tests/help-surface.sh --all
bash skills/teamsmith/tests/smoke.sh --select 51
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

## 返修轮次 1（2026-10-15，独立复验 V46 判 FAIL：一条阻断 + 一条应一并修的观察）

复验记录 `docs/team/reviews/V46.md`（受检 `fe577928`）。**先记好的**：P290 的两半都成立——跨秒逐字节幂等 ✓、哨兵臂拆掉守卫则红/还原则绿 ✓、宿主与容器各跑五次判定一致 ✓。**但新守卫带进一条回归**：

**F1（必修）· 记录存在但没有 `AT=` 行时，`mark-loaded` 静默失败**——`rc=1`、**一字不写、无任何输出**。`cmd-update.sh:94` 那一带用裸赋值接一个 `grep`（`grep` 没命中返回 1），在 `set -euo pipefail` 下把脚本带走。既有门禁段 `17` 因此红：**候选 ✓178 ✗1 / main ✓179 ✗0**（复验者两棵树都跑了，归属清楚）。

**我的独立复现**（临时项目、只跑 `mark-loaded`，宿主）：

```
记录存在但没有 AT= 行：
  main      rc=0 输出=✓ 已记录本会话 skill 版本：0.0.0（指纹 …）  → 写出 AT=2026-10-15T22:21:39Z
  P290 候选  rc=1 输出=（空）                                        → 什么都没写
```

**改法**：把「读既有 `AT=`」写成**不会因未命中而终止**的形式（例如 `stored_at="$(grep -m1 '^AT=' "$f" 2>/dev/null || true)"` 或 `if` 包裹）；语义上「**没有可保留的时间**」= 正常写出新时间，**不是错误**。红侧：① 记录缺 `AT=` → `rc=0` 且写出新 `AT=`；② 记录有 `AT=` 且核心未变 → **逐字节不变**（既有臂，不许回退）；③ 哨兵臂（把 `AT=` 覆盖成哨兵后再跑，必须逐字节存活）**保持不变**。

**O1（一并修，属同一处逻辑）· 探针不校验退出码**——复验者造的第三棵变异树 m3 让第二次运行 `rc=1` **且一字不写**，探针仍判**绿**（因为它只看指纹有没有变）。这正是本项目最忌讳的**假绿**：**「失败」被当成了「幂等」**。改法：幂等臂在两次运行后都断言 **`rc=0`**（并把 rc 打进探针输出），红侧：造一个「第二次 rc≠0 且不写」的变异 → 必须红并点名（复验者的 `mutants/m3.diff` 可以直接用）。

**O2/O3** 见 V46 §6，若落在同一段代码里就一并处理，否则在报告里说明为什么不做。

**交付**：改完跑 `help-surface.sh --select claims`、`smoke.sh --select 17`、以及你自带的红侧，贴结果；报告写「返修轮次 1」一节；然后 notify pm，由 V46 第二轮定点复检（同一验证席位、换会话）。
