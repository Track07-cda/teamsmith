---
id: P466
title: 先修图像观察再复用四次面板准备
agent: dev
category: code
phase: apply
change: clipboard-test-session-reuse
specs: verification
deltas: -
branch: task/P466-clipboard-session-reuse-apply
---

# P466 · 仅实现与静态交付

正式proposal review已ACCEPTED（固定add115a2、V169最终bfd264ec、D252，规划合并3722c8ed）。你未参与本change规划审阅，负责原生任务1.1/1.2；2.1/2.2/2.3留给非作者，不提前勾选。原样本只有2→1同进程证据，含两次约35s等待失败；8→4及新观察均尚未动态验证，不写成已经提速或通过。

先读AGENTS、自己的线程、本brief、apply skill及原生apply返回全部contextFiles。明确选择clipboard-test-session-reuse；用已安装OpenSpec1.16的list/status/instructions确认自己根、状态和0/5，再逐项按真实sourcePath/line完成1.1/1.2并确认原生进度。不要跑实现后的行为样本——本批由另一席位统一验一次。

## Boundaries

- 唯一实现写集 `skills/teamsmith/tests/panel-b2.sh` 的 `scenario_clipboard` 内；另可勾该change `tasks.md` 的1.1/1.2，写自己 `docs/team/reports/P466-dev.md`。不改已接受proposal/design/delta、正式spec、其它函数/场景、共享pty/隔离库、产品/bundle/CI/配置或真实团队状态。
- 严格按design §4先逐一替代三处图像观察，再按§1–3复用四次准备；既有回调/同次可见帧理由取文、图像父rc与种子同shell flag必须分清。不通过换目录、短路径、改宽度/超时/轮数/按键节奏或减少原观察换绿，不新增通用框架、开关、成功断言/等待次数或永久检查段。
- 保留原八子例、七主动C-v与一零按键观察、所有原具名行为断言和实际工具/图片/草稿/理由证据；第一至第五共享面板，理由/另一CLI/未按键仍冷启动。模式只在前例真实完成后切换，活草稿用真实编辑动作，不留磁盘+按键双重准备。具体接口/状态/失败语义以已接受design/tasks为准，不另造一套。
- 根来源/路径查询分别是 `team_tmp_root_source` 与 `team_tmp_root`；真实默认长路径确认与完整运行属于未来非作者，不要为写本报告先跑一次。若现有局部接口确实不能实现，列具体缺口BLOCKED，不擅扩库/需求或用样本掩盖。

## 本席位唯一验收：静态

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
bash -n skills/teamsmith/tests/panel-b2.sh
openspec validate clipboard-test-session-reuse --type change --strict --no-interactive
# 最终报告暂存后；采用现有项目名单
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

保留静态source diff、原八子例/具名断言逐项保留表、原8→4实际启动调用账（含另一CLI直接启动，不用全文件grep次数冒充）、种子/图像结果传播检查及未改区域字节同一性。这里是源码核账，不冒称真实启动/故障通过；最终原生进度应2/5，后三项未勾。已有引用/路径登记未变，复用已接受回执，不重复spec-refs/选择器平台；不运行任何完整clipboard、两条件样本、b2/38、其它设置/帮助/配置、smoke/FAST/全量/meta/61b/安装/构建/真实模型/性能。

先提交可核对的实现和对应叶子项，再补最终静态回执/报告提交，Conventional Commits含P466和Agent: dev。报告答清改了哪三处观察/四次准备、保留了什么、哪些尚未行为验证、固定tip及原件位置；日志只留本地，不git add -f。自己的较慢静态批次用team_bg_run后结束回合，完成唤醒再收取，不等待/睡眠轮询。

分支只留本地，不merge/push/归档/发布；PM会准备固定独立检出并另派非作者统一跑design §5的一次完整clipboard和既定短坏/恢复/结果消费，同字节合并不重跑整组。只清自己的本次具体临时根，不动P464/V169、P465/V170或A10原件。
