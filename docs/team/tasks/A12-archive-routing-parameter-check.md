---
id: A12
title: 同步规格并收尾参数检查去重
agent: dev2
category: code
phase: archive
change: routing-parameter-check-dedup
specs: verification
deltas: -
branch: task/A12-archive-routing-parameter-check
---

# A12 · 仅收尾已验收的测试变更

你未实现本change（实现者dev）。P467/V172/P468/V173均已接受关闭；D256依D241用户授权确认归档，不再等额外人类确认。最终V173报告1525c11e、正式P468 review绑定merged28621c57；原生6/6、CRITICAL/WARNING/SUGGESTION均0。正常boundary一次863/0、五原故障及恢复经一次父级51/0；合并后129项依赖同一，仅短parameters279/0，实际review1s。归档不重复任何这些行为。

## 执行与写集

1. 读自己线程、archive/sync skills、本change全部工件及正式verification。沿用OpenSpec1.16原生list/status/instructions确认自己的根、6/6、实际planningHome/artifactPaths及适用guidance/specs rules。明确选routing-parameter-check-dedup；`team change status`只有A12自身未完成是预期，别的阻塞要点名。无需安装/升级/初始化新root，不因advisory改CLI或复制规则正文。
2. 沿用既有最短路径：自己唯一/var/tmp普通独立副本先试原生`openspec archive -y routing-parameter-check-dedup`，同步完成后核结果；再在自己的稳定任务分支同样原生执行一次。不用hardlink、不手写移动/合并、不跳同步或验证、不新造audit框架。五工件逐文件对比、目标块需求/场景内容核对、目标块外正文精确比对和普通Git差异足够。
3. 唯一写集：本change五工件整体移入原生日历archive（含.openspec.yaml），正式`openspec/specs/verification/spec.md`仅把`A gate that cannot judge says so`整块更新为已接受MODIFIED内容，以及自己的`docs/team/reports/A12-dev2.md`。目标内保留原17场景标题、加入六个已验场景，三处旧61b义务的限定按已接受delta，不另改文字；不留下delta-style headers。原Purpose、目标块外全部正文和所有产品/tests/CI不变。正式spec临时写权已授，交付后归还PM；不改其它change/真实状态/0.4.7发布对象。
4. 本人任务分支实际运行一次下列短检查，保存命令/stdout/stderr/rc。较慢批次用team_bg_run后结束回合，完成唤醒再收取，不等待/轮询。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec validate --all
bash skills/teamsmith/tests/spec-refs.sh --check
# 最终报告暂存后，使用既有项目名单，不读取名单正文
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

沿用非strict全仓口径，不称全仓strict已绿；实际native提示保留。已有版本/源盘点/选择平台未变，复用旧回执，不重复执行。若native同步改变需求/场景内容或目标外正文，保留现场BLOCKED，不手工改已验工件或Purpose换绿。

5. 报告先答真实归档路径/根/6of6、五工件原样、目标块需求/场景内容与已验delta相同且六新场景恰一次、其余正文和可执行字节不变，再给实际短检查/原件来源。保留原A驱动错误及阶段3/6→B6/6历史；160s/12s/1s均仅本次受影响参考，不捏造整套提速或重跑旧长原件。
6. 可核对步骤及时小提交，再补真实回执/报告，Conventional Commits含A12和`Agent: dev2`。本地交付，不merge/push/tag/npm、不代PM写接受或看板。原日志不git add -f；原件等PM收存后再清理，且只清自己本次具体试验根，不动P467/V172/P468/V173待收存原件或其它席位目录。不得为归档运行boundary/parameters/五臂/CORE/完整61b/flip、smoke/FAST/meta/夜间、其它矩阵、真实Pi/模型、性能、安装或构建。

## 私有试做后的PM裁定（2026-11-16）

PM已读取e26c47a7报告与现有`trial-discrepancy.stdout`：两处变化仅为普通段落间的双空行各减少一行，正文、全部23场景标题及顺序不变；五工件、目标外正文/Purpose和其余489文件都相同。接受native这两处段落格式处理，不是需求内容改变，不改delta、不新增空白过滤器或比较框架。

原分支/模型/SID继续，正式spec临时写权继续按本brief使用。保留首轮精确比较失败和BLOCKED历史；复用已核私有trial，不再次试归档或重跑根/版本/上下文/旧平台。现在本人分支只做一次实际原生archive；正式spec应与现成trial结果字节相同，五工件仍原样移动，其它正文不变。完成实际归档后再执行本brief的短结构/引用/报告检查，真实新结果与首轮active-change检查分开；不要把旧21/21当归档后结果。交付正式报告/提交，原件继续保留等PM收存。
