---
id: V164
title: 0.4.7公开CI三类失败独立诊断
agent: verify
category: verify
phase: opsx-verify
change: -
specs: verification agent-self-reminder
anchor: none (infra) — 分析已发布冻结版本的CI失败，不修改产品、测试或规格
deltas: -
branch: task/V164-release-ci-diagnosis
---

# V164 · 先读原始现场，只复现必要的单个失败

CI run43810623157，冻结fdd3247a451eeeec37985af73d2267b74790058b。0.4.7已经正式发布；标签与包不得改动，不擅自重跑远端CI。你曾负责V161发布独立验收，现从已提交报告/原证据接续，不重新执行发布门禁。

PM准备独立检出 `/var/tmp/rel47-ci-fdd3247a`；自己的工作树仅写 `docs/team/reports/V164-verify.md`。当前main/dev已有P457后续测试精简，不是本次CI输入，严禁混为同一版本。

## 已取到的原件（主根，只读）

`.pi/team/state/release-0.4.7/` 下：ci-logs.zip（63条日志）、ci-logfiles/（四路Gates和coverage）、ci-jobs.json、ci-artifacts.json、ci-result.json。用git common-dir定位主根，不用继承state路径猜。原ZIP806135bytes，失败现场可继续只读下载：
- gate-failure-scene-s1：artifact14201825602，约13MB。
- gate-failure-scene-s3：artifact14201256281，约21MB。
- gate-failure-scene-s4：artifact14201925828，约23MB。

本机GitHub新加坡API地址TLS EOF；本次临时 `curl --resolve api.github.com:443:140.82.114.6` 已实际成功。只对单次请求使用，不改系统DNS/代理。需要认证时仅通过既有gh认证间接注入API调用，禁止查看/打印凭据。不要直接把网络查询失败当CI失败；本次已从真实run确认failure。

## 三类真实失败，不能预判全是误报

1. 分片3/4：P440 review绿失败、兄弟前缀路径断言失败、还原后仍红，均为 `independent checkout display mismatch` 或找不到预期的原始checkout路径。实际review rc0/PASS。读取保留的T1.1记录，查是HOME/TMPDIR布局下的合法显示转换、测试期望错误，还是产品错误；不可仅放宽匹配或吞rc。
2. 分片4：39/install-shape两条裸init受管块比较失败，实际包含 `<skill-dir>`，期望包含git common-dir定位命令。核P456三形状生成行为及原测试配置，判断未同步的期望还是错误生成。只针对两条断言/生成路径核对，不重跑完整安装/帮助页走查。
3. 分片1：69/remind-tool-real实际7场景全未等到初始响应，外层一个FAIL，659s。先读s1保留的真实Pi退出/会话/受控provider证据与CI解析的Pi版本，和V161/本地完整受控验收的版本及调用方式对比。若确需复现，最多取现有driver的一个原始最小场景；无外网模型，不重跑7例，不延长超时、不删错误场景、不新增永久筛选器。取原始首次错误，不止重复“超时”。

coverage实际核出141段并集等于基线、四片清单均正确；它仅因矩阵有失败而红。不要立项修改coverage或新增防护。

## 交付

每类给“已证根因/尚缺证据”、实际受影响行为、可精确定位的最小修法和应由谁实施。若只有夹具期望偏差，明确保留哪个真实行为与故意改坏证据，不能靠豁免/条件跳过解决；若当前产品有缺陷，指出本地既有证据未覆盖的具体场景，交PM另派修复。

补一句解释V161窄补验/组合证据为何没有覆盖这些失败，不用“所以再跑全量”代替影响分析。只读诊断不改实现、规格、真实团队进程/state；不真实模型调用，不新建真实提醒，不全量/61b/meta/夜间/性能/三路线安装，不更换模型或安装全局依赖。

实际的必要命令与结果落报告；如有局部测试只记录实际范围、原有失败不能算通过。报告暂存后只跑自身ledger-ban/diff-check。提交、通知PM，不合并/推送/发布。需要长下载或一个较慢受控场景用后台，等待完成唤醒，不在回合里sleep。
