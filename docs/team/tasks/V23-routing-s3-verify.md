# V23 · task-model-routing S3（init/模板/指南/门禁登记）独立复验

task: V23
agent: verify
phase: verify
category: verify
change: task-model-routing
specs: init-skill
deltas: -
branch: task/V23-routing-s3-verify
deps: P235（apply 已交付，冻结 tip 见任务消息）

## 复验对象

`openspec/changes/task-model-routing/tasks.md` **§7** 的实现（被检树 `pm-skills-ledger/team/reviews/V23/checkout`，独立 clone，detached 在交付 tip）。作者自报：全量 76 段 ✓3036 ✗34，并声明那 34 条是**既有红**（非本候选引入），定向复跑 `0e,29,34,36` 修后为 0 红。

## 必须自己做的（不许只复跑作者脚本）

1. **34 条红是否真的既有**：在**未含本候选**的 base 树（P232 的交付 tip `611f72d4`）上跑同一批段，逐条比对段名/断言；凡是本候选引入或掩盖的，判 FAIL。作者给了 base 对照日志（`.pi/team/state/bg/p235-base-*.log`）——可以读，但必须自己复跑至少那几段。
2. **旧配置零副作用**：旧式 `.pi/team/config.sh` 在 init/bootstrap 路径上必须**在安装/建账本/起巡检之前**被拒并指向 `upgrade-models`；用夹具证明「拒绝时项目树、账本、worktree、pulse 窗口零变化」（前后哈希/清单）。
3. **模板与门禁**：新模板只写类别映射 + PM 模型（不猜席位默认值）；占位符安全检查仍在；`--select init` 与 `task-model-routing.sh --select init` 自己跑一遍。**红侧**：把某模板改回退役字段、或让旧 bootstrap 放行 → 守卫必须红并点名；还原后绿。
4. **没削弱既有断言**：逐条核对 `smoke.sh`/夹具改动是「合法输入变化」还是「删断言/skip 换绿」——后者判 FAIL。作者改了 §29 的登记行与若干夹具，重点看这些。
5. **不越界**：`git diff --stat 611f72d4..<tip>` 确认没碰 S1 核文件（`scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death}.sh`）与 S2 面板文件（`panel/**`、bundle、strings）——碰了判 FAIL（那会让 V19/V21 的复验失效）。
6. **容器内 FAST 一次**确认没有新红（并如实记录红/跳过项）。

## 交付

`docs/team/reviews/V23.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型）；证据包仓外 `pm-skills-ledger/team/reports/V23-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。通过后 PM 会一次性合并 S1+S2+S3 并归档该 change。
