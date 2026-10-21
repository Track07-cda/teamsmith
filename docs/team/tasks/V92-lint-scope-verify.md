# V92 · P359 的独立验收：那个盲区真的关上了吗

task: V92
agent: dev
phase: verify
category: verify
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 一条扫描排除规则
deltas: -
branch: task/V92-lint-scope-verify

## 受检

候选 `3dc056b9`（`skills/teamsmith/tests/tmux-lint.pl` 一处排除表 + 注释），报告 `docs/team/reports/P359-dev2.md`。

作者读数：修前 `tests/logs/probe.sh` 里一条裸 `tmux kill-server` 判「干净」；修后判红并点名；真树默认范围的 `--list` 与判定改前改后**逐字节相同**（105 个候选里被这两段排除 0 个）。

## 要自己做的

1. **盲区关上了**：私有副本里在 `tests/logs/probe.sh` 与 `tests/snapshots/probe2.sh` 各写一条裸 `tmux kill-server` → 必须**红并点名两处**；把候选的排除表改回旧样子（`|logs|snapshots`）→ 必须**重新判干净**（证明是这个改动关的）。
2. **没有因此误伤**：真树默认范围下，候选与 `main` 的 `--list` 输出**逐字节相同**（自己 diff，别抄）；`--selftest` 仍然 37/37。
3. **三个 TMPDIR**：`/var/tmp/x`、`$HOME/.cache/x`、以及一个**含 `/logs/` 的路径**（例如私有副本 `.../logs/x`）各跑一次 `--selftest`，都要 37/37——最后这个是本次事故的复现条件。
4. **没有别的规则被动**：`git diff main 3dc056b9 -- skills/teamsmith/tests/tmux-lint.pl` 逐条看：只该是排除表与注释。
5. 轻量收口：`perl -c`、账本禁令、`git diff --check`。

## 边界

只读代码、破坏只在 `/var/tmp` 私有副本、只写 `docs/team/reports/V92-dev.md` 与自己的线程。**不要跑整套门禁**（现在有一个 4 小时的发布门禁在跑，别抢机器）。结论先写 PASS/PARTIAL/FAIL。
