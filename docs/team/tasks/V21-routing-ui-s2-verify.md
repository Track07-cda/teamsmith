# V21 · task-model-routing S2（面板切片）独立复验

task: V21
agent: verify
phase: verify
category: verify
change: task-model-routing
specs: panel
deltas: -
branch: task/V21-routing-ui-s2-verify
deps: P232（apply 已交付，冻结 tip 见任务消息）

## 复验对象

`openspec/changes/task-model-routing/tasks.md` §6（面板切片）在 P232 里的实现。作者自报：p21 全场景 332/0、choices 48/0、选段门禁通过、五个提交、本地未推。

被检树（PM 已冻结的独立 clone）：`pm-skills-ledger/team/reviews/V21/checkout`，detached 在 P232 的交付 tip。先核对 HEAD、`.git` 是真目录、树干净。

## 必须自己做的（不许只复跑作者入口）

1. **判据面**：§6.3/§6.4 点名的真 tmux 面板取证——类别选择器、PM 编辑、实际派单记录、类别被删后的「策略 vs 保留恢复」、无派单记录、陈旧指纹、旧配置拒绝、以及「不 spawn 不重启」。渲染帧要与你自己的 CLI 日志/配置哈希成对。
2. **红侧**（在 scratch 副本里做，还原后复绿）：把 CLI 路由改成席位写入、或把未来模型当实际显示、或让旧配置静默通过——对应断言必须红且点名。
3. **不越界核对**：`git diff` 确认没碰 S1 的文件（`scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death}.sh`）、没碰 `templates/**`、`references/**`、`SKILL.md`、`smoke.sh` 既有段与 canonical specs；若碰了，判 FAIL。
4. **不削弱 S1**：跑既有 UI 前门与 `section-select.sh --paths <改动路径>` 选段；容器内 FAST 一次确认无新红。
5. **状态诚实**：面板显示的「实际派单」必须来自记录的模型/SID（不是策略里的未来值）；S1 已复验的读侧诚实性不许回退。

## 交付

`docs/team/reviews/V21.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；同时写明你运行时用的模型）；证据包仓外 `pm-skills-ledger/team/reports/V21-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
