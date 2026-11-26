---
id: V206
title: 独立实测项目设置中的任务标签管理
agent: dev3
deps: P507,V203,P497,V196
category: verify
phase: opsx-verify
change: project-label-management
specs: panel, board-and-status
deltas: -
branch: task/V206-project-label-management-behaviour-verify
---

# V206 · 只验证现有项目设置操作

实现者 dev-bob；你未写过本变更实现。交付固定 `eb95c48ec62ead67fa87099158acad7e7d433bc9`，独立干净检出 `/var/tmp/p511-review-eb95c48e.EI3lP1`。与 `64d9cfe0` 只差作者报告，实际面板包 993434 字节，SHA-256 `9d23020a7c65c3ab3aeda43d3386638d9af83c0eadea94a61b57e083bf64840b`。先读 AGENTS、本人线程、本任务、OWNERSHIP、verify skill、P511 交付报告和原生 apply instructions 的全部文件；已合入的标签规格见 A20，不重新设计。原生 3.3 是唯一行为批次，7/8 中这项等待独立回执，不跑全量。

1. 只读将实际代码与任务 1.1–2.3 对照，特别是原公开默认输出不改、结构化回复的确实拒绝/未确认/确认成功、在用 ID 的来源与无自动重试；跟踪命令成功后旧看板读未完成、后一次读及失败时实际采用的数据。无独立事件证据的分支明记「源码核对，未实跑」，如发现实际不符，不用合成状态、固定 JSON 或新增测试守卫绕过。原受影响变更 strict 与类型/词条/构建可引用作者实际回执。作者同次全仓 strict 为 5 通过、17 失败，涉及未改正式规格；保留这条事实，不重跑全仓或宣称全绿。
2. 在自己创建的 `/var/tmp` 根、独立 tmux 与一次性项目中，从固定检出仅运行原 `TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh settings </dev/null`。用原生 `team review` 绑定真实退出和记录，绝不走默认全集：

   ```sh
   TEAM_GATES='bash /var/tmp/<你的私有根>/run.sh' \
     bash skills/teamsmith/scripts/team review P511 \
     --dir /var/tmp/p511-review-eb95c48e.EI3lP1 \
     --branch eb95c48ec62ead67fa87099158acad7e7d433bc9
   ```

   私有 runner 设置 `TMPDIR=/var/tmp`、清继承 `TMUX TMUX_PANE`，以 `mktemp -d -p /var/tmp` 建该次 `TMUX_TMPDIR`，放开 `TEAM_P21_KEEP=1` 至真实 child。实际看中英界面、中文鼠标聚焦/进入/返回和英文 70×25 筛选/键盘/返回；核原命令三项、模型记录和已有编辑检查仍然发生，不能只是计数。按设计 3.2 用同次真实 CLI 读数、逐项 argv 和实际画面证明首条 `-用户 反馈` 保存、选择蓝色、不需颜色代码；已用标签改 `-9007199254740993` 时只提交权重、旧自定义颜色和关联不变；取消无写、再次打开不带草稿；拒删显示 T21 且目录/关联不变；真实配置、审计、任务更新时间和偏好不被标签操作写入。起跑先核私有路径与记录落点，保持候选干净。
3. 一次后台启动即结束回合，完成后收取；发生失败，留真实帧、子结果、命令记录、输入前后及第一个缺口，区分业务失败、断言误判和未达到，不当场改代码、换场景或重跑。不能验证已确认未使用删除、其它拒绝、未确认回复及旧读竞态时，把静态证据与实际执行分开。不跑原标签看板 46 项、§38、完整 smoke、重建/依赖安装、模型、发布或当前 Pulse。不得写实际项目配置、看板、标签、巡检、待命状态。

只本地提交 `docs/team/reports/V206-dev3.md`；由原生 CLI 写主检出的 `docs/team/reviews/P511.md`、`P511-verify.log`，除此之外不写主检出/清单。报告先给是否可接受、真实执行范围、通过失败数、命令退出及具体帧与 argv 路径，然后给 Completeness/Correctness/Coherence 和所有未执行限制；原件保留待 PM 核收。本次尚不合并、不归档、不发布。合并后另由你对固定合并做一致性以及必要的短接入，不重复此次设置场景。

## 首轮失败后的唯一补验

冻结 `3fd44aac4373506208c7ca6eb52cd86ca8a320f5`，独立干净 `/var/tmp/p511-review-3fd44aac.mHMIZV`。`882ecc2e` 只修 `panel-p21.sh` 的逐字输入并显示其失败；相对 `eb95c48e` 产品、包及规格完全一致。作者隔离空窗对相同名称和负权重的旧写法均 rc=1，新 rc=0 且收到逐字相同；这是输入工具的对照，而非产品验收。首轮 15/1 原生 FAIL 和原件留 `.pi/team/state/evidence/P511/round1/`，静态结果沿用。

按上节私有环境与证据要求，只跑原 `TEAM_P21_KEEP=1 bash skills/teamsmith/tests/panel-p21.sh settings </dev/null` 一次，由于前段是同一场景的必要准备而随跑，不另跑已通过项或作者空窗。此前未到达的文字进入、真实保存、只改精确权重、取消和拒删、设置保留操作及英文窄屏均要达，保留真实 argv/原始帧/读回、失败与没到达的边界。只改绑定为 `TEAM_GATES='bash /var/tmp/<你的私有根>/run.sh' bash skills/teamsmith/scripts/team review P511 --dir /var/tmp/p511-review-3fd44aac.mHMIZV --branch 3fd44aac4373506208c7ca6eb52cd86ca8a320f5`。沿用原 V206 任务、会话和分支，后台通知收取，不重跑全套或代码静态批次，不动当前 Pulse。

## 行为通过后，只复核提示去重

固定 `5a0f6bde7834dfcce547108908fba0fa8ed63455`，独立 `/var/tmp/p511-review-5a0f6bde.B3okud`，构建包 SHA-256 `235415d9e172719fcacae7b86b01ae9b0484b5ddef3c686e9ca8861d94c92e3d`。与已实测的 `3fd44aac` 仅删除 `layout.ts` 那一个重复内容行、重新构建同一包、加作者报告。原 49/0 接受、实测未覆盖的分支仍不得记为实跑。原实际 `label-refused.txt:10,13` 与 T21、当前标签、原 argv 保存在 `.pi/team/state/evidence/P511/round2/`，保留原始 PASS，不覆盖。

用一个私有只读布局调用（不假造终端帧、不预制预期输出）或一次最短实际拒删核对，把同一真实现场的 T21、目录与读取/拒绝状态传给现有布局。检查同句只剩一处，T21 和当前标签仍在，无删除成功，原状态、调用与测试不变；给出真实命令/原件、退出码和保留的证据。若用布局调用，尽量用同一方法对 `3fd44aac` 得两次、此版一次，不将布局核对写成新的用户实测；不要启动整批或重复设置 49 项。用 `TEAM_GATES` 指向这一个短脚本，绑定上述固定源及完整 SHA 的 `team review P511`，不走默认全量。只写本人报告以及原生中央记录，不重建、不改产品或当前 Pulse、暂不做合并后检查。

## 合并后：只核定稿与入口接入

候选 `5a0f6bde` 的去重对照（旧真实正文 10 行逐行相等，新 9 行，仅去重，T21 保留）及 `3fd44aac` 的独立设置实测 49/0 已接受；预处理误判原 FAIL 保留。合并 `80bcf2ebb412472c762d79c0303d915cf0fa9dbb` 已同步 `public/dev`，固定独立源 `/var/tmp/p511-merged.HnkzfL`；清单 8/8。

你只对比候选与此合并版的 `skills/teamsmith/` 与构建包的实际文件一致性，并在一个独立私有项目用现成设置准备、入口操作实际走「项目设置 → 任务标签 → 返回项目设置」，留帧、标签读取 argv、实际 rc。不保存、不测删除、不重复两轮设置、布局对照、构建或全量。需要的短 driver 留私有根，不加产品或测试文件。用 `TEAM_GATES='bash /var/tmp/<你的私有根>/run.sh' bash skills/teamsmith/scripts/team review P511 --dir /var/tmp/p511-merged.HnkzfL --branch 80bcf2ebb412472c762d79c0303d915cf0fa9dbb` 绑定这次短核。针对实际范围交付最终报告，候选与合并记录分开，不改已结论的记录；实测边界和全仓 strict 旧失败仍明列。保留私有根，等 PM 收件，不操作当前 Pulse 或项目。
