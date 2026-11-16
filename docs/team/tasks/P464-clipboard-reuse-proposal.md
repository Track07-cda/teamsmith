---
id: P464
title: 剪贴板用例复用面板的最小可行性与提案
agent: dev-bob
category: analysis
phase: opsx-propose
change: clipboard-test-session-reuse
specs: verification
deltas: verification
branch: task/P464-clipboard-reuse-proposal
---

# P464 · 先核新准备代价，再决定是否值得提案

P463只读探索已接受并关闭，见 `reviews/P463.md`、D249及原报告c3337ff9；不是apply授权。原§38整段994s不能当重启耗时；八次面板启动候选8→4，但真实UI重置草稿也有成本，不能先认定更快。

## 第一步：仅一个两条件私有短样本

在自己的唯一/var/tmp根使用现有产品bundle、既有panel-b2函数/等待/断言/私有tmux手段，只取clipboard开头两个连续条件（Wayland图像→Wayland失败/X11图像回退）：旧方法两次启动，对比候选一个活面板复用。只可改自己的临时测试副本/输入，仓库产品和tests只读。证明两次C-v都真走产品工具、对应PNGDATA8/XCLIPDATA、准确插入点与草稿；候选真键重置种子，不能只改draft.md后假装内存已刷新。各阶段stdout/rc/屏幕及草稿原件保留，失败如实返回，不补跑整组。

普通模式输入文件如采用，只是本次假工具的输入，不是产品配置/缓存/服务；在前次探测完成后切换，不让上例结果顶替下一例。新增键操作/准备次数与旧启动次数逐项核账，参考时间可记录但不设门槛、不需安静机器、不得据一对样本承诺秒数。若样本要造一套新启动器、大段旁路或更多防御来成立，直接给不做建议，不强行完成正向方案。

本次范围是一个两条件旧/候选对照，不是命令只能运行一次。不跑完整clipboard、b2、§38/面板、全量/FAST/meta/61b/夜间、真实模型或性能套件。不缩短原键节奏/等待、不改产品/bundle、不增加产品测试开关。较慢命令必须后台启动即结束回合；已经完成的业务动作不为补收据重跑。准备脚本报错、场景尚未启动时，应保留错误原件、修正自己的准备接线后继续原样本，不得把未执行当预算耗尽或直接据此交工。

### 2026-11-16续做说明

首份回执在真实team init/私有server/面板/C-v之前退出，实际业务动作均为0；这只证明临时脚本多加的tmux检查接错了接口，不能证明复用方案不可行。保持P464原模型/SID/分支，在原临时副本中去掉自己多装、且不是原b2接法的外层检查，沿用b2原有私有tmux目录与具名socket，不修改隔离库、放宽隔离或新造启动器。保留最初失败脚本/trace及rc，再完成原来尚未开始的短对照；不跑其它用例。若后续失败，以实际已完成部分盘点，不从头重复已完成的业务。

## 第二步：有简单可取方案才建立proposal

先按propose skill确认既有OpenSpec1.16根。**完成取舍前不创建新change目录**；若建议不做，唯一交付为自己的P464报告和真实回执，不留空change或编造delta。若确值得推进，再原生建立唯一 `clipboard-test-session-reuse` 的proposal/design/verification delta/tasks及自己的 `docs/team/reports/P464-dev-bob.md`，只规划、不改正式spec/产品/tests或主检出。

候选范围仅panel-b2 scenario_clipboard四次输入切换的准备：原八个子例仍逐个真实C-v/文件/草稿/工具顺序；原挂起和未按键观察、四个不同接口/冷启动、其他场景及恢复覆盖原样。未来正常整个clipboard由非作者跑一次和必要C-v no-op坏腿/失败接线；实现者只实现/静态，合并同一性+必要短检，不重复完整b2/38。两个可行性样本不是全部原条件已验，正式方案仍必须交非作者审阅，不能从本报告进入apply。

不扩大到其它设置场景/缓存/平台、不同语言/高度或新的防御。新检查若确有必要必须替代原执行/原断言，不能层层添加。

## 交付与实际检查

样本完成后小步提交报告；如有proposal，对本change用OpenSpec1.16严格结构及适用spec-refs/section-select静态登记，不做无关全仓validate。无proposal时不执行这些无关检查。最终报告暂存后实际ledger-ban（主git公共目录名单）、普通/暂存diff-check。报告先给做/不做、实际启动/重置/输入账及证据缺口，再给工具/根/命令/rc；不把计划、静态次数或单次参考时间冒称整体提速。

Conventional Commits含P464及Agent: dev-bob；分支保持本地。不merge/push/archive/tag/npm，不动真实团队/提醒/standby。只清本次自己具体临时根，已测原件留给审阅，不碰P461/V167/A9旧现场。原始日志/快照留本地，报告引用路径、hash和必要输出尾部；不对被.gitignore排除的证据使用git add -f。此前已经误跟踪的本次四份logs，仅在自己的分支逐个git rm --cached解除跟踪，保留本地原件和旧提交，不修改ignore或历史。报告按最终事实更新，不能把准备失败写成可行性已经验证。
