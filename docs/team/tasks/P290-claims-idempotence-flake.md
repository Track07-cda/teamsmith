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
