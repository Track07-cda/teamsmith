---
id: P459
title: 修复公开CI查明的一处路径显示缺陷和两处测试错误
agent: dev
category: code
phase: opsx-apply
change: -
specs: verification#The record states what was verified
deltas: -
branch: task/P459-release-ci-fixes
---

# P459 · 修真实原因，不放宽检查

0.4.7已发布，原CI run43810623157固定fdd3247a。独立诊断见 `docs/team/reports/V164-verify.md`（verify，4b54e3af），PM接受记录V164.md。三类原因已定位；本任务修既有记录/测试行为，不新增产品要求或OpenSpec change，不改已发布包和标签。后续由另一席位独立复验。

## 明授范围

只在自己的任务树和分支改：
- `skills/teamsmith/scripts/lib/cmd-review.sh`：既有路径显示替换函数。
- `skills/teamsmith/tests/smoke.sh`：既有P440输入/矩阵，§67/68的Pi存在检查、§67–69调用时现有证据目录交接；不改其它段。
- `skills/teamsmith/tests/install-shape.sh`：共享 `chk_init_render_from_config` 的同形参考准备及与⑮直接相关的既有断言。
- `skills/teamsmith/tests/remind-tool-real.mjs`：Pi定位、现有启动等待的退出处理、现有输出/临时目录落到调用者已拥有的证据根。
- `skills/teamsmith/tests/lib/main-team-fingerprint.sh`：下述续跑授权仅修正真实PM的 `state/remind-tool/current.json` 运行记录分类，不扩大到整个目录或权威状态。
- `skills/teamsmith/tests/{remind-tool-real,remind-recovery-real,remind-adversarial-real}.sh`：必要的既有环境/证据交接，不重写封装。
- 自己的 `docs/team/reports/P459-dev.md`。若新增测试样本，只在tests中复用/替换现有同目的样本，报告说明；不要新增框架、门禁段、长期选择器或现场收集白名单。其它路径需要时BLOCKED交PM。

## 三个最小修复

1. **真实路径显示缺陷。** 当前先无边界替换root/，随后裸root只看右边界，HOME=/tmp会把/var/tmp变成/var<home>。修同一显示逻辑的路径边界，不再误改较长路径的中段；真正main/home根与其子目录仍按原规则显示。保留P440兄弟前缀、C/UTF-8与中文标点、句末点等既有行为，不新增分隔符白名单或过滤框架。把CI输入加入现有P440检查而不是另加守卫段；保持真实review的原精确路径断言、绝对路径红侧及同副本恢复绿。
2. **初始化比较形状错误。** 裸init默认安装，参考函数却--no-skills；对齐显式参考初始化的安装方式。保留非默认session/名册/docs/PM窗口/gates、既有config字节不变及完整AGENTS比较，不忽略路径差异，不退回P456前的错误生成。⑮故意撤掉取既有配置的变异必须在正常参考绿之后，因真正参数错误而红。
3. **Pi测试启动器找错程序。** 保留显式P442_PI，未指定时用调用者PATH里的实际可执行Pi，不假定HOME/.bun/bin/pi；§67/68和同一个JS driver约定一致。私有HOME仍只用于测试隔离。复用现有启动等待，done早于session-start时立即报真实退出码和启动错误，不继续把“程序不存在”变成90秒业务超时。不要延长watchdog、建假HOME软链、删七场景或把§69改SKIP。既有driver的启动检查由正确退出分类替换，不叠加新防护层。

现有证据不用新收集器：将已有launch/done/session/event/provider输出交给smoke的$TMP子目录，以便原现场包能保存失败原因；遵守私有临时根/精确清理，不向/tmp写产物。V164证明原CI没保存Pi原件，不能补造过去的退出码。

## 2026-11-16续跑授权：同一处运行记录分类误判

已提交82ea7496；第一次冻结选段实际458通过/6失败、510秒。原10/10b/39及真实Pi三组10/3/7均通过；六项尾部全指向真实主项目的 `state/remind-tool/current.json` 变化。原失败输出保留，不改成通过。

PM另读实际运行记录及源码：该文件仍属于真实PM；`team-remind.ts` 的heartbeat每5000ms调用refresh，再由 `publishRemindCapability` 写入新at时间。现有指纹把合法运行记录当作夹具写入，不能要求真实PM停止活动来换绿。不是已证明的真实污染，不修改产品/真实状态。

仅授权在共享分类函数里把这一个确实持续更新的运行记录归为正常变化；不排除整个remind-tool或state目录。`reminder-locator*`、`state/reminders/**`、Standby及未登记文件仍必须报变化。复用既有分类自检/真实污染反例，不另加守卫层、白名单框架或第二套实现。

67beb50b及PM实读日志已确认：CLI/delivery/lifecycle/pulse四组原始before/after仍在；§69两封装在判定后无条件删除了两组原件，但完整输出仍显示唯一违例路径current.json、内层12/0与7/0。调整为四组现存原件逐组重放；另外两组只核完整违例输出、同一未变的判定调用和内层结果，明确记作无法重放的证据边界，不冒充六组原件齐全。不合成/补造快照，也不为补齐过去已删除的文件重跑业务场景。

再跑现有 `isolation-ledger.sh` 与最短的分类/污染反例，证明任意旁文件和权威状态变化仍失败。只允许current.json这一个分类变化；若出现其它差异，停止说明。本调整允许以组合证据交给非作者判断，不是PM提前判定复验PASS；两组原件缺失必须在最终报告和独立接受记录保留。此次不扩大到封装清理策略或新的日志机制。

下文的18段命令已经运行过，本次不得为这一分类修正把它或已绿的20个真实Pi场景重跑一遍。采用原始结果加上述定点补验，保留原458/6及每条补验真实范围；非作者仍须独立核三项修复和此分类边界，PM不代跑。完成后继续正式报告与交付，不停在PARTIAL。

## 验收与成本边界

- 先留原函数CI布局错误输出、原共享init比较失败、原driver错误启动收据；可引用V164并核冻结源码，不重新跑七个失败90秒。Pi版本与真正启动路径据实记录，不倒填历史版本。
- 修改后仅相关命令：

```bash
bash -n skills/teamsmith/scripts/lib/cmd-review.sh skills/teamsmith/tests/smoke.sh skills/teamsmith/tests/install-shape.sh
node --check skills/teamsmith/tests/remind-tool-real.mjs
bash skills/teamsmith/tests/smoke.sh --select 10,10b,39,67,68,69 </dev/null
```

这次选段已经调用共享driver的工具、恢复、对抗三组，不再另外直接重复跑同组。用私有HOME且不存在其.bun/bin/pi、PATH上有实际Pi的CI同型环境验证默认发现；记录实际场景/返回值，§67/68不得在有Pi时误SKIP。HOME=/tmp的纯显示函数输入只读，不向/tmp落盘。

- 最小反证：恢复旧显示替换必因/var/tmp或/srv/tmp错误而红；原no-skills参考必红而对齐后绿、⑮仍因真实参数错误红；恢复旧Pi定位会找不到现成PATH里的Pi；短命启动失败要显示实际退出而非业务watchdog。复用现有样本/私有副本，不新增完整变异矩阵，不反复运行长组。
- 当前OpenSpec 1.16：`openspec validate --all`；`spec-refs.sh --check`、`section-select.sh --check`、报告暂存后ledger-ban与diff-check。全仓strict既有长文本边界照实写，不用旧CLI结果冒充。
- 一次一个较慢验证，后台启动即结束回合、完成唤醒后收割。无全量smoke、61b/meta/夜间/性能/三路线安装；无真实模型或外部收件人，现有受控loopback provider不算自主性验证。若出现新首错，取真实原因，别靠重复整组碰碰运气。

## 交付

三个可独立检查的小提交及时落地；报告先回答根因/修复/实际影响，附真实命令、原红与恢复、未跑范围及新发现。报告提交后通知PM，等待非作者独立验收；不合并、推送、发布、不碰真实提醒/Standby/Pulse/PM、不改模型或全局依赖。
