---
id: P508
title: 编写消除 PM 待命指令矛盾的方案
agent: dev-bob
deps: P504
category: analysis
phase: opsx-propose
change: clarify-pm-standby-guidance
specs: init-skill
deltas: init-skill
branch: task/P508-pm-standby-guidance-proposal
---

# P508 · 消除 PM 待命授权指令的矛盾

接已接受 P504 `3b4a9ee2`、D270。用 `openspec-propose` 只写 `openspec/changes/clarify-pm-standby-guidance/` 原生四种规划工件、`docs/team/reports/P508-dev-bob.md`。将正式 `init-skill` 中原有的共享规则/角色职责条款修到一致，不添加另一套规则或改变其它验收。

- 完整决策放生成的 AGENTS 共用段。**在采用新默认指令、且项目没有把进入待命保留给用户的情况下，默认允许 PM 在条件满足时自己执行 `team standby on` 并写原因，不需逐次问**。只有同时没有可推进工作、也没有运行中的任务/验证或自动回来的结果在等，才进入；只等待人的决定可以符合这两个条件，空看板或当前回合结束不是依据。项目已有人工授权约定优先。PM 不自行关闭待命；普通 Pulse 唤醒受抑制，人工关闭与已证实的定时提醒实际唤醒例外照旧。不改变运行代码、状态或项目配置，不新增自动切换。
- PM 开场开头只提示「未待命且 Pulse 不在运行时启动」，后段与生成的 PROTOCOL 只指回共用规则；原合法结束/在途后台结果回到本会话的文字和原升级授权句保留。对 P504 提到的其他技能/参考/README 逐处保留原结构，只删或替换主动赋予与新规则冲突的句子，纯人工操作说明不改、不扩大常规改写。优先英文短句、更少文字；不得在本项目或其它项目已生成的 AGENTS/PROTOCOL 上用重初始化等命令来应用。
- 规格保留已有 PM 自主推进的授权边界、原依赖和用户批准限制；只让过去绑定特定三个文件的场景不误判这次独立文字修正，不删它需要保护的行为。方案明确新默认指令只在新建或显式采用后生效，不能承诺改源码或重启 Pulse 就覆盖旧项目自己的规则或会话。别新增运行测试、模拟模型、测试指令是否被读、真实会话或渲染/刷新项目；最终独立核对文字、保留既有测试逐字匹配、用 Git 确认修改范围即可。

仅运行 `openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive`、`bash skills/teamsmith/tests/spec-refs.sh --check`、Git 差异与账本隐私检查，记录真实命令和退出码。报告先给共用规则、最小写集和明确未执行项，按项目规则本地提交 P508 / `Agent: dev-bob`。不得动任何运行、现有指令文件、实际项目、模型、构建或全套，不合并、不推送、不归档。独立方案审阅通过后才实施。

## V201 退回：只补普通巡检实际发出的这条指令

原候选 `6c7675d2` 的独立报告 `ece83f43` 只留 R1。`skills/teamsmith/scripts/lib/common.sh` 的 `team_nudge` 最终会把「没有活或要人决定就执行 standby on；之后不会再叫醒」直接发给运行中的 PM，仍与新共用规则和既有提醒例外冲突。补入 proposal/design/tasks 和既有待命文字审阅场景：最终实施仅删除这条 `msg` 中 `digest` 之后的待命指令与承诺，保留现有前缀、摘要和 `team digest` 入口，不用新尾句或改语言。本次其余普通消息、计数、投递、队列、合并重复、恢复及待命/提醒逻辑不改，也不提前实施后续的巡检方案。

把「不改脚本」精确为「唯一脚本差异是上述面向 PM 的文字，无行为改动」。只修这一个遗漏、重新校验单变更 strict 与必要引用/差异，继续本分支/会话；不写脚本、全量、模型或新测试。完成即交原 V201 定点复看。