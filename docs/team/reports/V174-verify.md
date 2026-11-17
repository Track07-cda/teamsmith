# V174 · 五批精简后的一次完整产品检查计时

agent: verify   status: DELIVERED — measurement complete / suite FAIL   time: 2026-11-17T03:31:28Z
branch: `task/V174-post-slimming-full-timing`   PR/MR: -

## 结论

本轮完整运行结束，实际检查用时 **6704 秒（111 分 44 秒）**，锁排队另计 **1 秒**；退出码 **1**。原生统计为 **140 段收口、5139 条通过、2 条失败、19 条跳过**，逐段增量与结果行一致。失败分别是设置页三种徽章的结构检查、提醒流程的真实 Pi 事件检查；没有中断、超时、追加测试、修代码或重跑。

固定受测源为 `532c8b474f9aa3ec9d9094b28ae88463cd9d88e5`，不是本轮之后开发的版本。本单交付的是一次完整测量及真实失败记录，不是发布放行，也不撤销已接受的五批精简。

| 计时口径 | 实测 | 原始凭据 |
|---|---:|---|
| 正式 review 检查运行 | 6704s | `docs/team/reviews/V174.md` 的 `ran=6704s` |
| 锁排队 | 1s | 同记录 `queued=1s`；保留了陈旧持有者记录提示 |
| `/usr/bin/time` 包住 review 的总墙钟 | 6705.45s | 原件 `time.record`，含锁排队及 review 包装开销 |
| 原生逐段秒数之和 | 6698s | 140 条原生收口行；不是用它替代 review 墙钟 |
| 外层开始 / 结束 UTC | 2026-11-17T01:37:34Z / 2026-11-17T03:29:20Z | 原件 `run.record`，秒级记录 |
| 结果 | rc=1，FAIL | 正式 review、GNU time、snapshot 退出行一致 |

旧 `/var/tmp/rel47-first-order.log` 约 113 分钟仅为任务书给出的参考；本轮未跑旧版本、未控制同负载，不能据此声称净提速。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V174-verify.md` | 本次计时、失败、覆盖范围及慢项报告；唯一任务分支改动 |
| `docs/team/reviews/V174.md` | 本人调用正式 review 生成的中央记录，绑定固定 SHA，判定 FAIL |
| `docs/team/reviews/V174-verify.log` | 完整原始输出，5911 行；仅工具授权写入 |
| `/var/tmp/v174-verify.aScB4e/` | 本人唯一证据目录；原始 log/record 的逐字节副本、外层计时、140 条原生统计及其排序结果 |

原件目录含 `V174-verify.log`、`V174.md`、`review.stdout.log`、`run.record`、`time.record`、`native-sections.log`、`summary.json` 及交付短检查输出。`native-sections.log` 是从完整 log 按原始字节抽出的 140 条收口行，不是重造计时；`summary.json` 仅解析这些行并排序。完整 log 里的原生最慢列表默认打印 5 项，下表以全部原生逐段行补足最慢 10 项，没有改运行参数。

## 最慢 10 项

下列行号均指完整 `V174-verify.log`。计时为报告数据，不是通过阈值。

| 排名 | 段号 / 本轮序号 | 内容 | 秒 | 通过 / 失败 / 跳过 | log 行 |
|---:|---|---|---:|---|---:|
| 1 | 38 / #102 | 设置选项 | 948 | 15 / 1 / 0 | 4791 |
| 2 | 51 / #116 | 用法说明与实际入口检查 | 705 | 2 / 0 / 0 | 5316 |
| 3 | 63 / #132 | 关键回复面板第 5 页 | 682 | 3 / 0 / 0 | 5809 |
| 4 | 62 / #131 | 关键回复存储与 CLI | 534 | 1 / 0 / 0 | 5688 |
| 5 | 61 / #129 | 任务类别模型路由 | 339 | 1 / 0 / 0 | 5642 |
| 6 | 34d / #98 | 锁身份变化、入场及等待者检查 | 206 | 110 / 0 / 0 | 4711 |
| 7 | 33 / #87 | 项目配置读写入口 | 148 | 1 / 0 / 0 | 4106 |
| 8 | 39 / #104 | npm CLI 与项目 skill 安装 | 127 | 1 / 0 / 0 | 4803 |
| 9 | 69 / #138 | 提醒事件顺序、重放及进程死亡边界 | 121 | 2 / 1 / 0 | 5873 |
| 10 | 26 / #79 | 面板布局、输入净化、队列及隔离 | 113 | 156 / 0 / 0 | 3450 |

## 失败记录及处置边界

### F1 · 设置页三种徽章未找到预期结构

完整 log 4769–4775 行：

```text
✗ 38-f panel-p21.sh groups/settings/wheel 有失败
  ✗ apply 徽章 = 普通文本 tone：run 结构不对（label=0 badge=0）
  ✗ restart 徽章 = warn tone：run 结构不对（label=0 badge=0）
  ✗ refuse 徽章 = dim tone：run 结构不对（label=0 badge=0）
== 结果 == ✓ 94 ✗ 3
```

这是子组的 3 条失败，由外层汇成 1 条失败；不能把外层 `✗2` 误写成所有子组只有两条失败。该段完整收口为 948s / 通过15 / 失败1，后续各段继续执行。结论影响：本轮不得报全绿；将原始输出交 PM 判断另开修复或诊断任务，本单没有定位根因或修改实现。

### F2 · 真实 Pi 忙碌后续事件未满足 custom_start 断言

完整 log 5856–5873 行：

```text
✗ P444 真实 Pi 受控对抗红（rc=1）
PASS real Pi A+B exact event, duplicate/member/foreign-session replay preserve a fresh generation
PASS real Pi event before manual off/on G2 stays ambiguous and Standby commands do not wait for Pi
FAIL real Pi busy follow-up emitted after manual G2 keeps the unprovable order boundary: AssertionError [ERR_ASSERTION]: The expression evaluated to a falsy value:
  assert(events(info).some(e => e.type === 'custom_start' && e.customType === 'team-reminder'))
  at .../skills/teamsmith/tests/remind-tool-real.mjs:557:9
remind-tool-real: passed=6 failed=1
#138 69 · … · 参考 用时 121s · ✓2 ✗1 SKIP0 · ticks 3
```

这是一次真实断言失败，不是后台任务连接错误，也没有证据将其归因于负载。结论影响：与 F1 一并交 PM 判断；未重跑以消除失败、未扩大超时、未把它改成跳过。

## 实际覆盖与跳过

- 完整正常入口执行了一次，140 个段落都有原生收口；log 5906、5908、5911 行分别给出统计对账、最终结果、snapshot 的 `rc=1`，没有只执行到半途的迹象。
- `TEAM_META=0` 明确跳过 **6 段**：`0e`、`36`、`38m`、`40`、`51m`、`61b`。每段输出理由及最近 GREEN 记录 `2026-11-13T08:07:03Z`；这个旧记录不是本轮通过，也没有另跑元套件或完整 61b。
- 其余 **13 条跳过**：§19 的 5 个相位 prompt 和 5 个相位 skill 在快照里不存在；§31 的旧证据层豁免路径不存在、容器运行时不可用，各 1 条；§60 快照里没有禁令名单，1 条。其原因分别见 log 2951–2960、3721、3730、5630 行。它们只计跳过，不计通过。
- 没有另起安装、打包、性能、参数、帮助、配置、粘贴或真实模型套件；完整正常入口内原本包含的安装/面板/真实 Pi 子项按原入口执行，没有人为删减。
- 独立 checkout 在运行前和结束后均为 `532c8b47…`，`git status --porcelain=v1 --ignored=matching` 无输出；运行日志首行绑定相同提交的 snapshot，后续活树开发不在本次判定范围。

## OpenSpec assessment

N/A — 本单 `change: -`，是已关闭五批之后的计时任务，不是新的 OpenSpec change 验收。只阅读 `verification#The run reports each section's outcome counts and its slowest sections` 的短上下文，未执行 change 工作流或额外 OpenSpec 检查。

## CRITICAL

2 项：F1 与 F2 使本轮 suite FAIL，详见上面的真实输出；本单测量已完成，不宣称任何发布/合并放行。

## WARNING

1 项证据边界：任务书的原命令未带 `--keep` / `TEAM_SMOKE_KEEP` 或 snapshot 保留开关，默认 EXIT 清理已移除本轮 smoke 临时根 `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.cJomJ8` 及 snapshot `/var/tmp/teamsmith-snapshot.7rSXv7`；收取时两者均不存在。独立的原 `sections.tsv`、子组现场及帧因此未留存，不能声称还有这些文件。完整原始 log、正式记录、140 条同源原生逐段行和外层原始计时均已留在证据目录；本轮不为补这些现场再跑一次。本人没有执行清理命令，PM 固定 checkout 与本人的证据目录仍保留。

## SUGGESTION

None — 本单不新增检查、阈值、框架或产品改动。

## Final assessment

- Counts: CRITICAL 2 · WARNING 1 · SUGGESTION 0。
- Readiness: 计时交付完成；完整正常检查 FAIL。F1/F2 的根因和后续行动由 PM 决定，不将一次测量直接变成重开五批任务或阻止新功能合并的决定。
- Unverified applicable checks and reasons: 19 条实际跳过如上；未执行任务书明确排除的元套件、第二轮完整运行、旧版本对照及额外安装/性能/模型检查；默认清理后未能进一步查看子组现场。均不计通过。

## Verification evidence

实际从本人工作树调用，唯一长作业 `v174-full-timing`，完成唤醒后已用 `team_bg_wait` 收取：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
TEAM_GATES='env TEAM_META=0 bash skills/teamsmith/tests/smoke.sh --snapshot=532c8b474f9aa3ec9d9094b28ae88463cd9d88e5 </dev/null' \
TEAM_REVIEW_TIMEOUT=14400 \
bash skills/teamsmith/scripts/team review V174 \
  --dir /var/tmp/v174-review-532c8b47.RgzJCh \
  --branch 532c8b474f9aa3ec9d9094b28ae88463cd9d88e5
```

外层仅用 `/usr/bin/time` 记录整条 review 及 `tee` 保存输出，不替换原生锁或 timeout，返回实际 review 退出码。原生关键尾部：

```text
140 段收口 · 增量 ✓5139 ✗2 SKIP19 ｜ 结果行 ✓5139 ✗2 —— 一致
== 结果 == ✓ 5139 ✗ 2
smoke 有失败项（--keep 保留现场）
快照运行结束：committed=532c8b474f9aa3ec9d9094b28ae88463cd9d88e5 rc=1
门禁输出：docs/team/reviews/V174-verify.log（FAIL，6704s）
复验记录：docs/team/reviews/V174.md（FAIL）
wrapper_elapsed_seconds=6705.45
wrapper_exit_code=1
```

正式 review 记录在运行结束时生成，先于本最终报告，故其中的“agent 报告缺失”是生成当时状态；本最终报告另行提交，不通过重跑 review 覆盖这个原件。

短检查在最终报告暂存后执行，仅检查本任务分支：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=2839 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --cached --check
（无输出）
$ echo $?
0
```

## Flip evidence

N/A — 本单没有缺陷修复或产品修改；F1/F2 为唯一完整运行的真实失败，不另造红绿对照。

## Decisions and deviations

- 长作业命令、一次完整正常检查、`TEAM_META=0`、固定 snapshot、原生锁和 14400s 超时均按 brief 执行；未运行额外业务检查。
- 收取原始 log 时，UTF-8 严格解码发现原件含无效字节。原件按字节复制保留，统计只匹配正常的原生收口行，没有重写或“修复”原始 log；其 SHA-256 为 `aab6cfd6cee9cde575074bc4ebbf7c7d397d772d861d38823b9b57857544c833`。
- 原生收口行 SHA-256：`c1dc66cfb5e10e5efd2b7c41088c358f7211fe56acb45fc62a9ed00ee17f3522`；默认临时根未留存的边界已在 WARNING 明确。

## Suggested next steps

PM 收存 `/var/tmp/v174-verify.aScB4e` 后处理 F1/F2；本席位不在本任务里修代码或重跑。原始副本、本人证据目录和 PM 固定 checkout 均不手动清理。仅提交本报告到任务分支，不 push、merge、tag 或发布。
