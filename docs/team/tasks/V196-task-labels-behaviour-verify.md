---
id: V196
title: 独立验证多标签权重和 Pulse 看板操作
agent: verify
category: verify
phase: opsx-verify
change: task-labels
specs: board-and-status, panel
deltas: -
branch: task/V196-task-labels-behaviour-verify
---

# V196 · 实际验证任务标签与看板，只跑受影响场景

作者 dev；冻结候选 `6ce75ccf57002aa33724b3e0fea3c292bedd2256`，干净独立检出 `/var/tmp/p497-review-6ce75ccf.buY10v`。先读本席位线程、AGENTS、OWNERSHIP、P497 任务书、固定候选的交付报告与 `task-labels` 原生工件。行为验收只有原生 `tasks.md` §3.1；作者静态和产物哈希可引用，不重复安装、重建、全库规格校验或未改的检查。`v0.4.8` 在固定检出存在（`c34e1468`），且与实现前 `6c48830e` 的 `skills/teamsmith/scripts/` 文件一致，可供已安排的旧看板对照。保留候选树干净；实际写入只在你具体 `/var/tmp` 私有项目与 private tmux，确认 namespace/路径不是当前团队。不得启动或更新正在用的 Pulse、改项目设置、标签、巡检或任何真实看板数据。

## 唯一候选行为批次

在独立检出用 `team review` 绑定候选及审阅记录；短 runner 用已接受的下面两条选段，原始日志、ANSI 帧、真实 board/detail 数据和没有跑到的检查都保留。已有保持临时文件的开关用来收证，不为收证重跑。按后台作业规则启动并结束回合，完成通知后才收取，不轮询等候。

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
unset TMUX TMUX_PANE
export TMUX_TMPDIR="$(mktemp -d -p /var/tmp tl-pty.XXXXXX)"
export TEAM_SMOKE_KEEP=1 TEAM_B3_KEEP=1
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 4c,6d,28 </dev/null &&
  bash skills/teamsmith/tests/panel-b3.sh board </dev/null
```

- 先核实该批实际执行的段、通过/失败/跳过与退出值。旧用法的输出/七列字段须有真实前后比较。用 §6d 原合计输入和输出核 T2=8 及同分顺序；在自己的临时副本仅把 `scores()` 的求和改成取最大值，用同一看板和标签表、同一条 `team board ls --sort priority` 执行一次，必须实际读到 T2=5 且原分数断言失败。不能用相同的 ID 顺序、语法错误或命令没启动充作检出；保留原 8 分实跑，不重跑原组选段。反例可随该 runner 接在正常批次后，按 §3.1 不改变产品源。
- 看真实命令数据与界面，而不是只看断言计数：标签、排序与键鼠同指一张卡片；改权重、改色及坏文件恢复确实由同一运行中的界面读到；核任务没有说明文件照样显示标签，和表外同编号详情在新增同编号任务后确实已刷新还是没有标签。保留 59 列有/无标签的同卡前后文本，不把固定画面称作真实刷新。检查旧默认顺序、无标签和机器输出没有因标签改变。测试动作与证据对不上即报告缺口；不加保护层补“通过”。
- 允许原生工具写主检出 `docs/team/reviews/P497.md`、`P497-verify.log`：`TEAM_GATES='bash /var/tmp/<你的私有根>/<runner>' bash skills/teamsmith/scripts/team review P497 --dir /var/tmp/p497-review-6ce75ccf.buY10v --branch 6ce75ccf57002aa33724b3e0fea3c292bedd2256`。不要用默认整套命令，不运行 §38、整套、真实模型或发布检查。若检查启动/准备或某项行为失败，保存完整原件，明确哪些已跑、哪些没跑，先交归因，不自行改产品或盲重跑整批。

唯一任务分支交付 `docs/team/reports/V196-verify.md`：先给候选是否可接受和实际缺口，带原生独立记录、输出/画面及临时根位置、实际短命令和退出值，小步本地提交（V196、`Agent: verify`）。不合并、不推送、不改任务勾选、不发布。合并后由你对 PM 给的新检出做字节核对和必要的短接入，不重复此批；原件保留至 PM 确认收存。

## 首轮后先停在原证据

`6ce75ccf` 已有原生 FAIL（636/3/3），报告 `aadffdf2`。不重复运行。首轮已完成且未改变的行为保留原证据；§26-a 原来被错误列为跳过。新固定候选到位后，原 V196 只用保存的 59 列帧复核修正后的取行、用相关 §26-a 路径补隔离重建、单独补公开标签命令的分隔符，然后执行原来未启动的 `panel-b3.sh board` 与一次权重反例。按新固定提交提供具体执行方式，不再启动 15 段选测来刷新数字；不得把旧原生 FAIL 改绿或替未跑项写通过。
