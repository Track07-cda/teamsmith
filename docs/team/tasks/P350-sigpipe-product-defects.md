# P350 · 产品里那两处 `grep -q` + `pipefail`：先落变量再匹配（V84 判定的真缺陷）

task: P350
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 两处产品代码的管道判定
deltas: -
branch: task/P350-sigpipe-product-defects
deps: 与 P346/P349 不冲突（它们改 `tests/**`），本任务只改 `scripts/lib/**`；但 `common.sh` 如需与别的写者串行，先问 PM

## 依据（V84 实测，`docs/team/reports/V84-verify.md` §4.1/§4.2）

两处都是产品代码里「把生产者管进 `grep -q`」——`grep` 命中即退出，生产者吃 SIGPIPE，`pipefail` 把整条管道判成失败：

1. **`scripts/lib/common.sh:5234-5236`**：产品调用路径今天 **0/30** 触发，但输入多 1 KB 就 **30/30**（标题流一长就必现）。严重度按验收的实测写，不要夸大。
2. **`scripts/lib/cmd-status.sh:155,158`**：两条腿都要改。未缓存腿 **30/30** 触发；缓存腿在 `lookback 200`（8200 B）时 0/60，但那是**恰好 8 字节余量**——任何 `TEAM_SQUASH_LOOKBACK` 上调（它是文档化开关）就 60/60。后果是「squash 合并后的分支被报成领先 N」，轻但确定。

## 要做的

1. 两处都改成**先落变量再匹配**（P326 在 11c、P344 在 §41 的写法就是范式）；**不许**加 `|| true`、不许改成 `2>/dev/null` 那种吞法。
2. **红侧各一条**：造出会触发 141 的现场（`common.sh` 那条按验收的「标题流 +1 KB」；`cmd-status.sh` 那条把 `TEAM_SQUASH_LOOKBACK` 调到 400），改前必须复现错误的判定、改后必须正确。
3. **不许顺手扩写集**：只这两处。其余同族（`outbox.sh` 里那 6 处在 P344 的返修范围、面板夹具三处经实测无害）不归你。
4. 验收：`bash -n`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`；受影响的选段跑一次（说明你选了哪几段、为什么）。不跑整套。
5. 报告：先给结论（两处是否都修好、红侧读数），再给证据；把 `cmd-status.sh` 那条「8 字节余量」的实测写清（它是这条缺陷的真实理由）。

## 边界

写集：`skills/teamsmith/scripts/lib/common.sh`、`skills/teamsmith/scripts/lib/cmd-status.sh`、`docs/team/reports/P350-dev3.md`。不改测试、不改别的 lib。
