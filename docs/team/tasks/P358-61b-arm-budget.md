# P358 · §61b 的臂预算：900 秒装不下 842 秒的实测（最小改法）

task: P358
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具内部的上限
deltas: -
branch: task/P358-61b-arm-budget

## 依据（你自己的 P357 定点复现，`docs/team/reports/P357-dev3.md` §3）

`flip-template-shadow` 那条臂：`flip_run` 给它 `timeout 900`（`task-model-routing.sh:1396`），而变异树的 boundary 组实测 **842 s**（绿基线 411 s）——**只剩 6% 余量**，发布那轮整机在跑 134 段，撞上限就是必然。这就是「第一次整套 fail=2、第二次 fail=1」那个漂移的来源。

**变异没有漏抓**：变异树跑出 `pass=1803 fail=631 rc=1`，红得非常充分。

## 我的裁定

**改臂预算，不改别的。** 具体：

1. `flip_run` 的 `timeout 900` 改成**按实测×2** 的 1800 s，并写清依据（842 s 实测，2026-10-21；411 s 绿基线）。
2. **不许**动整段的 7200 s 上限、不许改这条臂的替换方式、不许放宽任何断言。
3. 上界仍然只回答「它没动」：超时那条路径要能**点名是哪条臂、超了多少**（现在如果只是 `rc=124` 就变成「红的成因要人猜」，那是同一类问题的下一次复发）。
4. 顺带核一件事：`flip_run` 的超时如果只能给所有臂一个值，就在注释里写明「这是最慢那条臂的上限，不是典型值」，免得以后有人按它估总时长。

## 必须交的

- `bash -n`、`--select 61b` 里**那一条臂**的定向复现（你能用 `TEAM_ROUTING_TREE` + `--select boundary` 那个手法就够，**不要跑整段 82 分钟**）：变异树必须 **rc=1 且不是 124**（这是本次要证的事），绿基线仍 rc=0。
- 超时路径的**红侧**：把 1800 临时改小（私有副本里）让某条臂超时 → 那条 red 必须点名臂名与秒数。
- 报告里给出「改前 900 / 改后 1800 / 实测 842 / 绿基线 411」四个数并排。
