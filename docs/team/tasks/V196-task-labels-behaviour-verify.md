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

`6ce75ccf` 已有原生 FAIL（636/3/3），报告 `aadffdf2`。不重复运行。首轮已完成且未改变的行为保留原证据；§26-a 原来被错误列为跳过。新固定候选到位后，原 V196 只用保存的 59 列帧复核修正后的取行、用相关 §26-a 路径补隔离重建、单独补公开标签命令的分隔符，然后执行原来未启动的 `panel-b3.sh board` 与一次权重反例。不得把旧原生 FAIL 改绿或替未跑项写通过。

## 返修固定交付：只补五项

`4cbc5bc78eeeca78cef535c727dd22379d9360c0`，独立干净检出 `/var/tmp/p497-review-4cbc5bc7.jNvU9J`。相对首轮只改公开 CLI 的 `--` 处理、smoke 两个就地检查及作者报告；JS、面板源与 bundle、实时场景脚本逐字节相同。用原 V196 会话/分支继续。首轮正式记录已另存；原保留现场 `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.BmGQb8/` 与 runner `/var/tmp/v196.6KbcGb/run.sh` 只读。

1. 在你的私有项目用新候选公开入口，原样运行 `team board label define --color '#0969da' -- '-Follow-up'`，检查 0 退出、存储及 `label ls` 中的精确名称。核分隔符后的 `--help` 等文字不是全局动作；其余命令的 `--` 继续按原路径，源码差异足以说明，不重跑帮助全组。
2. 直接把新候选 §28-h 的取行及比较用在首轮保存的 `p28h-59.txt` 和 `p28h-59-labels.txt` 副本，记录各恰一行且逐字相同；不用再渲染画面或改原空文件。
3. 只在你新建的隔离目录执行新 §26-a 的实际几步（复制源与共享文件、锁定安装、真实构建、`cmp`）。回执区分安装与构建；只有生成新包并逐字相同才通过。不要跑同段其他面板测试，也不靠既有包冒充重建。查改动后的失败分支确实把安装后构建失败记为失败；不专门模拟一组失败安装。
4. 首次执行 `bash skills/teamsmith/tests/panel-b3.sh board </dev/null`（原 `TMUX_TMPDIR` 隔离做法及 `TEAM_B3_KEEP=1`）；按原任务书核实际刷新和键鼠。原 §28 静态画面非行为证据。若有红项保存真实终端记录、待定位，不整体重跑。
5. 沿用原 runner 的私有副本方法和首轮 `task-labels/{board-six.md,catalog-six.tsv,priority-original.tsv}` 原件，实际只执行一次取最大权重的查询，确认命令执行成功、T2=5 且 `=8` 判据失败。原始正常 8 已实跑；分数程序与首轮逐字节相同，不重跑原 smoke。

用限定上述五项的私有 runner 调 `team review P497 --dir /var/tmp/p497-review-4cbc5bc7.jNvU9J --branch 4cbc5bc78eeeca78cef535c727dd22379d9360c0` 留新原生记录。每项单独记录结果和实际执行面，不用 `&&` 让一项失败阻止相互独立的其余项；如果前置隔离或同一项准备失败则该项停止并说明。保留正常、故意算错及异常现象的原文，五项之外不重跑 15 段或 §38。

## 接入后冻结候选 · 仅补变化及此前未到达的检查

固定 `4a8bf012fe1fc0c38dfb2e359719f40206cd3b40`，干净只读 `/var/tmp/p497-review-4a8bf012.g5PgLX`；实施合并 `2494ac7b` 的父提交是返修候选 `4cbc5bc7` 与现行 `d8968556`。恢复原 V196 任务分支/模型/会话，沿用旧报告与 `.pi/team/state/evidence/P497/{round1,round2}`。这段替换以上旧执行指令，不重新跑旧候选。读 `docs/team/tasks/P497-task-labels-apply.md` 新段、本次交付报告、V205、最新原生 change 和 P509/V202 已通过的独立数据。

1. 用版本对照证明旧证据可直接沿用：公开标签 `--`、精确写入和原算分 helper/输入不变时引用旧真实 `T2=8` / 错算法 `T2=5` 结果，不重做目录并发、校验、向量、注入或构建依赖安装。隔离复制输入与构建配方以有回执的旧 §26-a 和新作者构建为依据，核实际输入与 bundle SHA；没有跑新候选隔离重建就标未跑，不能当作新包隔离构建的证据。源码核验如见执行路径有实质变化、旧记录无法支撑或新包闭合不明，在报告点明再安排最短必要检查，不自行重跑整组。
2. 在同一候选私有现场只验证已经变的读写接入：复用 §6d 经确认的真实旧/新普通 CLI 同板同字节对照（固定 `d8968556`；无目录、坏目录皆同输出/错误/退出；新增七个业务字段及空 Issue、合法最右 UTC，set/assign 原字段和不相关行不改）与现有 opted-in board 读取缓存开/关对照（真实时间、原表序、表外归属与标签对齐）。缩到这些现有断言的必要准备，不重跑同节不受影响的目录/标签命令矩阵。只重取 §28-h 依同一卡和两旧入口的 59 列原输出，验证两条非空一行且内容逐字相同、控件仍可见；不能用旧候选帧当新结果。核实际机器 `--json`/`--print --page 4` 保持原形状、原顺序。分别给实际命令、来源/输出字节和不适用面。
3. 使用已有 `bash skills/teamsmith/tests/panel-b3.sh board </dev/null` 选段一次，只取现有私有项目/终端。关联正式原要求：默认最近更新和 undated 窗口、同批三键与立即 Enter/下步行、鼠标/窄屏及刷新选中，显式优先级（同分的更新时间与文件序反向）、筛选跨两种排序、CLI 改权重同界面刷新、隐藏同号不能接管焦点及空结果不打开；补到此前未走完的真实标签选择、目录坏/恢复、表外详情更新、其它 2.1/2.2 操作。以实际回执和稳定的帧判定，失败定位不延长等待、不重启重跑。已确认但因接入改到同一显示通路的检查走这一个场景，不另起第二个矩阵；P503/P509 独立旧报告不说成有标签的验收结果。

用一个私有短 runner 通过 `TEAM_GATES='bash /var/tmp/<你的私有根>/<runner>' bash skills/teamsmith/scripts/team review P497 --dir /var/tmp/p497-review-4a8bf012.g5PgLX --branch 4a8bf012fe1fc0c38dfb2e359719f40206cd3b40` 绑定新原生报告；各独立面区分执行、未到达和未选。写明准备与每部分计时；长作业结束回合、等通知再收，不轮询。只追加本报告及留私有原件。没有真实当前项目写入、运行 Pulse、模型测试、整套或安装/发布；原 636/3/3 和第二轮 16/1 不改。合并与勾 3.1 等 PM 接受。

## 第三轮返修后 · 只补一次真实看板操作

本节取代以上开跑范围。固定 `2309f8c564306affaf374f67e87fb4619a1f39b4`，独立干净检出 `/var/tmp/p497-review-2309f8c5.tGOIki`。相对第三轮 `4a8bf012` 仅 `tests/panel-b3{,-stub}.sh` 和作者报告变动，产品及 bundle 一字未改。历史三次原生 FAIL 保留，第三轮 74 秒、实时 26/1，原件在 `.pi/team/state/evidence/P497/round3/` 。普通 CLI 读写、2042 字节缓存开/关、59 列及机器输出继续用实际保留记录，不新跑；已有算分和构建证据的适用限制不变。

仅在自己的私有 runner/TMUX_TMPDIR 启动一次 `TEAM_B3_KEEP=1 bash skills/teamsmith/tests/panel-b3.sh board </dev/null`，用 `TEAM_GATES='bash /var/tmp/<你的私有根>/<runner>' bash skills/teamsmith/scripts/team review P497 --dir /var/tmp/p497-review-2309f8c5.tGOIki --branch 2309f8c564306affaf374f67e87fb4619a1f39b4` 绑定候选。F5 对比先显示原任务书、后有同任务的空详情与两标签/8 分；F6 对照同一次真实请求的 board/detail JSON 和面板实际变化（不是事后单独查一次）。仅通过这一个现有选段继续原来被挡住的标签操作：连续按键与立即 Enter、改色/权重、同分逆时序、双排序和键鼠筛选、空结果、表外同号详情刷新、损坏目录恢复及刷新保焦。沿用其中必要的现有搭建和前导动作，不另外开测试或重跑已通过的 CLI/缓存/窄屏/机器等检查。若再有首个失败，保留全部现场与已完成动作，记录下一步未到达的范围，不改产品或再重跑。执行完同分支追加报告，给原始帧、JSON 与退出结果。
