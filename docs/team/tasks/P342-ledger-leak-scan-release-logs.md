# P342 · 「夹具痕迹不许出现在真实账本里」把发布证据误判成泄漏

task: P342
agent: dev-bob
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 一条隔离判据的取样范围
deltas: -
branch: task/P342-ledger-leak-release-logs
deps: P327（正在写 `smoke.sh`）落地后派；单写者纪律

## 事实（今天第一次跑 `--floor` 时暴露）

`--floor` 在 main 上报了两条红：

```
✗ M9.8 隔离：夹具的痕迹出现在真实账本里：…/.pi/team/state/release-030/container-full.log …/public-ci.log
✗ M16  隔离：夹具的痕迹出现在真实账本里：（同一对文件）
```

这两份文件是 **0.3.0 发布时我留下的证据**（容器里跑全套门禁的日志、公开 CI 的日志），它们的内容里必然带夹具的会话名与标记——于是 `real_ledger_hits`（`smoke.sh:855`，扫 `docs/team/inbox` 与 `.pi/team/state`）把它们认成「夹具写进真实账本」。

这是**取样范围**的问题，不是隔离真的破了：那两份文件是「关于一次夹具运行的日志」，不是「夹具自己的产物」。它已经豁免了同类的东西（`tmux-calls.log`、`tmux-calls.log.forensics`、`bg/`）。

## 要做的

1. 给 `real_ledger_hits` 的过滤再加一条**按路径**的豁免：`.pi/team/state/release-*/`（发布证据目录）。**不要**用内容匹配去猜（那正是会出假阴的地方），用路径前缀。
2. 注释里写清：这条豁免只覆盖「发布证据目录里存的门禁日志」；它覆盖不到的残余风险也点名（若真有夹具往 `release-*/` 里写，这条判据不会再抓它——由评审与发布复核兜）。
3. **红侧（承重）**：在私有副本里让夹具真的往**真实状态目录**写一个文件（例如 `$PROJ/.pi/team/state/m98-leak-probe.txt`，内容带夹具标记）→ M9.8/M16 必须**仍然红并点名**；确认豁免没有把整片判断关掉。另造一个「`release-030` 里带同样标记的日志」→ 必须**不红**。
4. 跑一次 `--select 13`（或 M9.8/M16 所在的段；用 `section-select.sh` 查出段号并说明你查的方式），贴读数。
5. 轻量收口：`bash -n`、`section-select.sh --check`、账本禁令固定验收行、`git diff --check`。

## 边界

- 写集：`skills/teamsmith/tests/smoke.sh`（**只有 `real_ledger_hits` 的过滤与注释**）、`docs/team/reports/P342-dev-bob.md`。
- 不改隔离判据的其它部分、不移动发布证据文件（它们就该在那儿）、不新增门禁段。
- 净零：这条把一条取样过宽的判据收窄，没有新增检查器。
