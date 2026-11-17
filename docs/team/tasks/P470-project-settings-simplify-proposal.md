---
id: P470
title: Pulse项目设置精简原生提案
agent: dev2
category: analysis
phase: opsx-propose
change: pulse-project-settings-simplify
specs: panel, memory-and-deps
deltas: panel, memory-and-deps
branch: task/P470-project-settings-simplify-proposal
---

# P470 · 用已完成盘点形成一个可实施、可独立审阅的精简方案

用户要求普通用户不再面对过多设置与内部语言，D257/D258已明确范围。P469探索已接受关闭，报告`docs/team/reports/P469-dev2.md`及PM记录`reviews/P469.md`是输入，不重做全仓/全页调研。你仅规划，不改产品/tests/正式spec或真实配置。V174独立固定旧源后台计时，活树继续提交，无需等待它。

## 本阶段

1. 读自己线程、openspec-propose skill和本change相关正式spec，使用现有OpenSpec1.16及本仓root创建`pulse-project-settings-simplify`。按原生instructions生成完整proposal/design/tasks和`panel`、`memory-and-deps`两份delta；不安装/升级/初始化其它root，不复制一套规格到报告/任务书。记录原生root/status及真实结构检查，不把规划当实现或回归通过。
2. 首选方向为常用模型操作前置、精选默认设置、按用户目的分组、中文英文均短且可操作；不要仅改词或把123项全表原样放到“高级”。P469的C+5编辑项/三个入口是候选，不是已批准数字或项目数上限。逐项确认默认用途，证明每个低频入口的必要性；若已有合适入口则复用，不为保留旧内容增加子页面。最终只推荐一个首选方案，说明删/合/移去向、能力影响与真实前后数量；类别随项目数据，不硬编码示例的3类/8项。
3. `资源下限`、`模型并发限制`等词仍需用用户理解的名称审视；并发规则若仍需用户记内部配置语法，应给最小可用的控件/标签安排，不借此建立第二套配置或改变pattern语义。只读派单/PM记录要如实表示记录事实，不冒称当前进程正在使用；它是否应继续出现在设置内也要有用户用途依据。没有现成后台能力的操作不要画成按钮。
4. design给同输入的旧页/候选页草图，包含默认、低频入口/返回、选中、编辑/选择、取消/保存、生效提示、只读及失败。常态不重复原始key/默认标记/逐行徽章/CLI教学；真实错误/迁移问题不能因对应键退出而消失。保存不冒充已切换或已重启；没有删除键的writer就不伪造“恢复默认”能力。草图明确未实现，方便用户和审阅者直接比较。
5. 精确处理P469§5.2列出的展示承诺冲突：全键/未知键自动出现、schema分组强绑定、原始key主导确认、逐行class、磁盘/inode必显示、whole-map及记录位置等；用最小MODIFIED/必要退休处理。底层schema、CLI完整输出/分组、defaults/choices/值域/writer/CAS/actor/危险确认、模型身份及运行行为不变，不顺带重写这些规则或全仓长规格。正式spec/Purpose不写入。
6. tasks按作者只实现/静态、非作者一次受影响UI行为验收、同一verifier合并后同一性及必要短接入、非实现者归档分开。复用P469§5.3的原settings/choices/write/conflict/categories等场景，**替换**旧全表/新键必显示/全schema组标签绑定断言，不新增平台/保护规则/文案词表或一套截图矩阵。真实键鼠和中英文/窄屏安排足够说明实际可操作即可，不为8个文案多次重跑同套；UI未改的CLI完整配置检查沿用既有证据，不再跑一遍。

## 实际短检查与交付

完整工件小步提交（Conventional Commits含P470、Agent: dev2），然后本分支运行一次：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec validate pulse-project-settings-simplify --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh --check
# 最终报告暂存后
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

唯一写集：该change原生规划工件（metadata、proposal/design/tasks、panel及memory-and-deps两份delta）及`docs/team/reports/P470-dev2.md`。报告先答推荐界面是什么/真实前后数量/保留能力，再给实际检查回执；完整性按原生artifact图核对。工件与回执都提交齐再通知，不能仅有proposal或Suggested next steps就提前交付。无业务/pty/smoke/meta/61b/安装/构建/真实模型运行；不push/merge/archive/tag/npm，不改0.4.7或真实团队状态，不代PM接受或改看板。完整提案交非作者独立审阅前无Apply授权。
