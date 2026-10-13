# V24 · long-job-suspend B 刀（提示词三态合同）独立复验

task: V24
agent: verify
phase: verify
category: verify
change: long-job-suspend
specs: dispatch
deltas: -
branch: task/V24-long-job-prompt-verify
deps: P237（apply 已交付，冻结 tip 见任务消息）

## 复验对象

`openspec/changes/long-job-suspend/tasks.md` §4（4.1–4.4）的实现，合同来源是 `specs/dispatch/spec.md` 的 ADDED requirement「The worker prompt makes suspension on background jobs a third legal turn end and teaches the lane by purpose」。被检树：`pm-skills-ledger/team/reviews/V24/checkout`（独立 clone，detached 在交付 tip）。作者自报：`#13 13c ✓68 ✗0`、§6 `✓21 ✗0`、`section-select --check` ok 7 / bad 0 / SKIP 1。

## 必须自己做的（不许只复跑作者脚本）

1. **四个场景逐条自证**（不要照抄作者断言）：① 内置 Pi 路径打印出三态 + 挂起默认 + 内联等待预算数字，且**没有**「回合结束前必须收割」这类措辞、没有把叫醒写成成本；② 模板不带 `{bg_ext}` 时无车道段、带 `{bg_ext}` 时有（两条方向都要）；③ 同一合同在提示词 / `templates/AGENTS.section.md.tmpl` / `references/protocol.md` / `references/workflows.md §E2` / `templates/pm-prompt.md.tmpl` 之间**不漂移**（逐面比对三态与预算数字是否一致，PM 模板的既有规则不许被削弱）；④ 续跑指引点名 `state/bg.log` 与 `team bg list`。
2. **四条红侧都要自己造成**（scratch 副本，还原后复绿）：AGENTS 模板删掉第三态；把旧措辞还原进提示词；无 `{bg_ext}` 也注入车道段；续跑指引去掉 `state/bg.log`。每条必须**点名**是哪个面diverged。
3. **不削弱既有断言**：`git diff` 逐条看 `smoke.sh` 与 `section-paths.tsv` 的改动——是「合法输入变化」还是「删断言 / skip 换绿」；作者声明新增的 skip 只属本轮新夹具，核对证。
4. **不越界**：确认没碰 A 刀已并入 main 的两个扩展与 `tests/bg-ledger*` 判据、没碰模型路由面（`scripts/lib/{common,cmd-config,cmd-watch,cmd-status,cmd-death}.sh`）、没改 canonical specs。
5. **容器内 FAST 一次**：确认无新红；如出现红，逐条归因（是否既有红，用 base 树对照）。

## 交付

`docs/team/reviews/V24.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外 `pm-skills-ledger/team/reports/V24-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
