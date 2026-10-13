# V28 · P238（路由测试进闸门 / 组自足 / 选段归属）独立复验

task: V28
agent: dev3
phase: verify
category: verify
change: -
anchor: none (infra) — 对门禁登记、夹具自足与选段归属做独立复验
deltas: -
branch: task/V28-routing-gate-verify
deps: P238（apply 已交付，冻结 tip 见任务消息）

## 复验对象

P238 说要修三个坑（任务书 `docs/team/tasks/P238-routing-suite-gate.md`）。被检树：PM 已冻结的独立 clone（tip 见派单消息）。作者自报：逐组自足 13/13 绿且 `pm` 103/0；新增 §61（FAST 12 组 / live 13 组）与 §61b（`--flip`，live 专跑、FAST 显式可见 SKIP）；live 用时 §61 466s、§61b 4549s，rc=0；改路由测试文件后选段 keys 23→8 且含 61/61b。

## 必须自己做的（不许只复跑作者脚本）

1. **坑 1（组自足）**：自己跑 13 组**逐组单独**（`--select <group>` 一次一个，每组的 rc 与 RESULT 都贴），`pm` 必须 103/0；再做一条反向：把某组的 setup 注释掉 → 该组单独跑必须红（证明修复承重，不是白捡的绿）。
2. **坑 2（进闸门）**：§61 在 **FAST** 与 **live** 各跑一次，贴段用时、断言数、rc；§61b 在 FAST 里必须是**可见 SKIP 且点名原因**（不是静默跳过、不是通过）；§61b live 你自己跑一次（或引用你亲自跑过的日志，不许引用作者日志）。
3. **成本判断（要结论，不只数字）**：§61b 的 live 用时约 75 分钟，会让**每次全量门禁**多花一个多小时。请给出你的判断与依据：它该留在 live 每次都跑，还是应当由**选段**在「没有路由相关改动时」跳过（即只改选段归属、不动全量行为）？给出两个方案的成本数字与风险，并给一条建议。**不要**为了省钱把它改成静默跳过。
4. **坑 3（选段归属）**：改一个路由测试文件（例如给 `task-model-routing.sh` 加一行注释）→ `section-select.sh --paths` 输出必须**包含** 61/61b；再把新归属从 `section-paths.tsv` 去掉 → 同一改动不再选中它们（红侧）。确认改动不再落进 55/56/59/14d 那类无关段。
5. **不削弱既有断言**：逐条看 `smoke.sh` / 两张 tsv / `task-model-routing.sh` / `lib/model-routing-flips.py` 的 diff——是「新增/修正」还是「删断言 / 把断言换跳过」；新增的跳过必须有名有理由（§61b 在 FAST 的 SKIP 就是这类，要确认它在 live 里真的跑）。
6. **基线纪律**：任何「既有红」的说法必须在**同一条命令**下对照 **v0.1.2（tag `v0.1.2`）** 并贴数字。
7. **不越界**：只碰 `skills/teamsmith/tests/**`；确认没动产品代码（`scripts/`、`extension/`、`panel/`、`templates/`、`references/`）。
8. **容器纪律**：所有门禁跑在钉死容器 + 干净独立 clone；真 tmux 夹具只用经过证明的私有 socket；先看 `/tmp` 余量。

## 交付

`docs/team/reviews/V28.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；§61b 的成本判断与建议单列一节；写明运行模型）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V28-dev3/`；不改候选、不合并、不推送；结论按协议通知 PM。
