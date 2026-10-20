# P321 · 修复 npm 实装遗漏的命令入口及既有信号契约漂移

task: P321
agent: dev3
phase: apply
category: code
change: -
anchor: openspec/specs/boundary/spec.md#Signals go to a recorded pid, never to a name or a pattern
deltas: -
branch: task/P321-npm-command-entry-repair
deps: -

## 输入与授权

用户已明确授权「那都修」。这是修复既有契约，不制定新的拦截策略。先读自己的最新线程、AGENTS.md、OWNERSHIP.md、上述 boundary 要求及其全部场景，和 docs/team/reviews/release-0.3.0.md 的实装证据。自己新分支从当前 main 切出，旧 P320 已合并并关闭。

PM 已确认：npm 正式包遗漏 pkill/killall/pgrep/pidof 四个符号链接，PATH 因此落到系统命令；源码 signal-gate 还只接受前两个名字，与已经归档的 selector 要求不一致。v0.2.0 也有相同链接和 gate 字节，不得误报为 0.3.0 新增回归。历史入口可从 f473ad43、5ff558ab、87d1158e 追溯；只复用与当前契约相符的实现，不整批回放历史提交。

## 执行范围

只改 skills/teamsmith/scripts/shim/{pkill,killall,pgrep,pidof,signal-gate}；若确有必要，可定点改 package.json 的打包文件清单（不改版本/依赖/脚本生命周期）。测试临时借用 skills/teamsmith/tests/{signal-gate.sh,install-shape.sh}，这是本任务唯一写者；报告只写 docs/team/reports/P321-dev3.md。不得改 common.sh、CI、其它测试、规格、版本、tag、全局安装或其它项目。需要其它文件时 BLOCKED 点名，不自行扩面。

优先用 npm 能携带的普通可执行入口共享现有实现，避免新 postinstall、运行时修补器、通用框架或重复四份 gate。处理 basename/真实程序解析时，实际验证而不是只做文件存在检查。恢复已存在的 boundary 契约，包括 selector 拒绝与允许的只读形式、同名真身与返回值；不新增白名单/拒绝策略。产品不得带测试钩子。

## 验证及交付

从实际 npm pack 的 tgz 装入隔离 prefix，在安装物的 gated PATH 里使用记录调用的无害同名后端验证入口及判定；不对真实项目进程发送任何信号。确认拒绝码/空 stdout/后端未执行，允许的只读形式保留 argv、stdout/stderr 和非零状态。至少让原包/改回缺入口现场被同一现有安装检查检出，修复后绿。必要覆盖应替换/扩充现有安装断言，不新增 suite/静态守卫/永久变异矩阵。

只跑 signal-gate.sh、install-shape.sh 的现有合适入口及本次实际打包装入验证；不跑全量 smoke、模型路由变异、发布自检全套，不生成高负载。长命令走后台车道。对照 P316 已验收分支的 signal-gate 测试差异（只读）避免恢复旧性能限制。小提交并带 Agent: dev3，交付前 git diff --check、bash -n 受影响脚本、固定账本检查（名单取主仓 common-dir 上一层 .pi/team/forbidden-names.txt）。报告先说包内实际行为和实际运行结果，再给差异/未运行边界/下一步。保持本地分支，禁止推送、发版、合并；交付后冻结给独立复核。
