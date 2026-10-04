# P106 · 夹具必须尊重 `TEAM_TMP_KEEP`：CI 的"保留现场"不该被判成泄漏

```
task:   P106
agent:  dev-bob
issue:
change: -                        # 无 change：夹具与 CI 环境的假设（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改测试侧的遗留判定，不改产品代码
deltas: -
grant:  skills/teamsmith/tests/routes.sh · skills/teamsmith/tests/*.sh（只做 KEEP 口径对齐）· docs/team/reports/P106-dev-bob.md · docs/team/reports/P106-dev-bob/**
deps:   CI run `36405043458`（commit `8914244d`）红在 §51：**`✗ 翻转收尾：留下 1 个嵌套临时根`**（`✓169 ✗1`）
status: todo
budget: 小
priority: 中（CI 的公开门，本地不受影响）
```

> 本地模式：不 push（CI 的最终确认由 PM 在下一次 push 后看）。

## 现场与机理（我从失败 run 的 artifact 里取的）

```
✗ 翻转收尾：留下 1 个嵌套临时根
== 结果 ==  ✓ 169  ✗ 1  SKIP 0
保留临时根：/tmp/teamsmith-routes.2LyuDc（TEAM_TMP_KEEP=1）
```

**因果链（三段都在我们自己的代码里）：**
1. `.github/workflows/gates.yml` 用 `smoke.sh --keep` 跑门禁（**是为了失败时留下现场**，那是我加的 ✓）；
2. `smoke.sh:296` 于是 `export TEAM_TMP_KEEP=1` → **子进程都继承**（`routes.sh` 也在其中）；
3. `routes.sh` 的收尾断言"嵌套临时根都回收了"**没有把 KEEP 当回事** ✗ → 把**刻意的保留**判成**泄漏** ✗。
   （对照：smoke 自己的 §40 处理得对 —— `ok "40 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏"` ✓。这一条要跟它口径一致。）

## 要做

1. `routes.sh` 里**任何**"没有残留临时根"的断言都要 **KEEP 感知**：`TEAM_TMP_KEEP=1` 时**不许判泄漏**，
   而是打一条**可见**的说明（照 smoke §40 的措辞），并把保留的根**打印出来**（静默保留仍是缺陷 ✗）；
2. **默认（未设 KEEP）必须照旧严**：仍然断言"嵌套根都回收了"，并且**能被证伪** —— 造一个故意不回收的
   变异（scratch）→ 这条断言必须红 ✓；
3. 同一口径若在别的夹具里也有"残留即红"的判定，一并对齐（列出来，别只改一处）；
4. 证据：**两个方向**各跑一次并把原始输出贴进报告 —— `TEAM_TMP_KEEP` 未设（断言生效）· `=1`（可见说明、不判泄漏）；
   外加 FAST 与（一次）全量 smoke 的结论；
5. 只动测试侧；产品代码、门禁语义、断言强度都不许放松（**不许**把"泄漏"整体删掉 ✗）。

## 归因（如实写进报告）

这条红是 **PM 加的 `--keep`** 与 **§51 的收尾断言**共同造成的，属于"套件假设 vs CI 环境"这一类
（M47 同族：`CI` 变量导致面板误判）—— 报告里请点名这条因果，别写成"环境抖动"。
