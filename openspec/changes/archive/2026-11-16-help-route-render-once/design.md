# Design

## Context

动机见 proposal 的 Why；唯一规范入口是本 change 的 verification delta。设计用于确定尾换行、退出失败和短样本共用判定的处理，尚未实现。

源码基线 `8fc51cf11521`：

| 位置 | 当前事实 | 对本批的约束 |
|---|---|---|
| `tests/help-surface.sh:240–264` | `load_manifest` 将每个 `cmd` 行加入 `MG_ORDER` | 用同一清单枚举，不另建命令列表 |
| 同文件 `267–271` | `page` 在私有临时根调用真实 team，固定 `TEAM_LANG`，保留当前 timeout/shim，stdout 直接输出 | 原函数/环境不改；不得复用不同语言、locale 或宽度的输出 |
| 同文件 `1307–1316` | 两个 `diff -q <(page en help "$c") <(page en "$c" <flag>)` | 第二个完全相同的 canonical 调用是唯一退休对象 |
| 同文件 `125–126`、`1580–1586` | `finding` 累加 `FIND`，最终 `FIND=0` 才 exit 0，否则 exit 1 | 共用函数须在当前 shell 被调用，不能丢掉计数 |
| `tests/smoke.sh:23421–23436` | 51 消费 help-surface 子进程的 `HS_RC`，非零走 `bad` | 原父级不改，静态核对保留接线；不为此完整重跑 51 |
| `tests/section-paths.tsv:177–178` | help-surface 路径归 51；51m 只管 routes | 不加新段、needs 或慢入口 |

表内 `tests/` 相对 `skills/teamsmith/`。当前静态核算 `commands.tsv` 有 **47 个 cmd 行/47 个唯一命令**，即 4N=188、3N=141、退休 N=47；不是沿用历史数。`help-surface.sh` 基线 blob 为 `5e8fc59386f7d5481cb86c581d5704d300f9a7b6`，清单为 `f21c899ef4db355f70314a19c7287881622e6379`。

## Goals / Non-Goals

**Goals:** 用一份当次 canonical 原字节承担两次比较，三个实际 CLI 入口仍各调用一次；保留原成功断言与已有 finding/退出汇总，并让非零入口不能被相同甚至全空的输出掩盖。

**Non-Goals:** 不复用 coverage 的 pages 或 locale 的页面；不做跨命令、跨语言、跨 locale/宽度或跨进程缓存。不改组页 finding 后统一 ok 的已知文案、不改其它 route 检查、显式翻转或 routes/pages。没有完整段时长、净提速或最大耗时承诺。

## Decisions

### 1. 在单命令范围写文件，不把字节转成 shell 文本

在同文件加入一个最小的单命令入口函数，由正常 `MG_ORDER` 循环调用。函数依赖现有 `page`、`tmp`、`finding`，依次将 canonical、`--help`、`-h` 的 stdout 直接重定向到现有私有根下的三个文件，立即保存各自退出码，再做两次 `cmp -s`。文件名可以在下一命令覆盖，但三份内容每次都重新生成，没有“文件存在就复用”的分支。文件到本次脚本 cleanup 一起删除，不加缓存生命周期。

这替换原来的两条进程替换 diff：退休第二条 diff 左侧的 `page en help "$c"`，不是把它移到预生成、恢复样本或另一个入口；第一份 canonical 同时供两次比较。三个入口都只尝试一次；某条失败不阻止另外两条尝试。保持相同 `page en` 和原 locale/width 环境，不改 `page` 的实现或其已有超时。

不选 shell 命令替换，因为 `$(...)` 会丢尾换行。不从 `render_pages` 取英文页，因为 route 独立入口不预生成它，扩大依赖反而增加工作。不选全局缓存或仅比哈希，因为这既不必要，也会扩大证据边界。

### 2. 一份实际判定，原 finding 计数和最终退出继续负责结果

单命令函数在当前 shell 内调用：

- 每个非零入口生成 `route` finding，点名命令、`help <command>` / `--help` / `-h` 及 rc；即使它和其它入口输出相同、均为空，也不能成功。canonical 失败只记该入口失败，不把其不可信输出误报成两份页面差异。
- 对成功的 canonical/alias 对做两次独立原字节比较；错页、正文差异、尾换行差异都保留该命令和相应入口的 finding。保留原 `--help`/`-h` 差异诊断的身份，不合并成一个无归属的 diff。
- 函数返回单命令成功/失败，正常循环据此累计 `same`；原“三种入口逐字节相同”成功行仍只在全部命令通过时出现。`finding` 自身在同 shell 更新 `FIND`，原脚本末尾据它退出，不另起一套全局结果。

原进程替换里的 page rc 不会成为 diff 的退出码，故只改文件比较而继续不读入口 rc，会留下“两份失败空输出仍相等”的缺口；逐入口 rc 正是对同一次比较替换的结果保真，不是新增产品拒绝、额度或权限层。新判定替换原比较，不旁挂永久自检组。

### 3. 短反例加载实际函数与调用点，不重新运行全套帮助

非作者的一次性短驱动位于自己的私有副本的 `tests/` 下。它从候选同文件读取新增单命令函数的原文、正常命令循环及最终结果片段，并加载实际 `finding` / `ok` 定义；保留这些片段原文和 SHA，核对提取位置唯一。正常源码不增加 source-only 模式、测试开关、产品注入点或通用提取框架。

短驱动只把 `MG_ORDER` 缩成一个控制命令，把 `page` 的 stdout/rc 换成受控输入，并记录被要求的三种 argv。**比较、产生 finding、循环消费和最终退出全部是候选实际代码**，驱动不实现 cmp、不拼预期 finding 日志充当结果。实际三入口的全 manifest 调用由下述唯一正常 route 执行承担；短驱动不能冒称真实 CLI 或完整 route。

最小输入集合：一份正常的含尾换行相同输出；`--help` 和 `-h` 各自错页及各自仅少一个尾换行；三个入口各自“字节与成功对照相同但 rc 非零”，其中包含全空输出。每份损坏输入在同一短驱动上恢复到正常，核实际 finding 名称、rc=1、无全相同成功行，以及恢复后 rc=0；调用记录仍为三个入口各一次。无坏样本再带整份 route/locale/help。

失败接线只做一个额外短对照：把正常循环调用单命令函数改成子 shell，故意丢掉 `FIND` 的更新，其它代码与坏输入不变；原来要求最终 rc=1 的断言必须失败。还原同一副本后恢复通过。这样既证明实际循环和最终出口没有吞掉失败，也不拿“helper 返回非零”代替上层退出。51 的 `HS_RC → bad` 消费分支本批原文不变，按源码同一性核对，不启动 smoke。

## Risks / Trade-offs

- [只比较重定向文件仍可能把失败空输出算相等] → 三个 rc 在同一函数分别收取；短样本包含同字节非零/全空非零，不能仅靠内容不同报错。
- [函数在子 shell 中导致原 FIND 更新消失] → 正常同 shell 调用、一次短调用点破坏/恢复，观察实际最终 rc 和具名 finding。
- [将局部结构减量说成整段速度收益] → 只记这一循环少 47 次 CLI；新增文件 I/O 也有成本，无改后测量就不报省秒数。P432 的全量/夜间读数来自不同范围，不相减；任务书所指整个 51 的 681 秒和显式 --flip 均非本批收益。
- [旧证据的源码或输入与候选不一致] → 复用前核实际 blob/输入；相关差异才补相应入口，不以报告标题或整体 SHA 不同代替判断。

## Migration Plan

### A. 后续实现者：只改代码与静态

获正式接受后另派一名非提案者，在 `help-surface.sh` 完成上面唯一替换；只做 `bash -n`、差异/调用数核账、当前 change 严格检查、spec-refs 与 section-select 静态计划。实现者不运行正常 route、短坏样本、51、其它组、全量或性能对照。保留现有成功断言计数，不为调用数减少改写 verification 的既有全覆盖条款：本批没有退休任何断言。

```sh
# 以下是未来 apply / verify 的命令计划，本轮没有执行行为命令。
bash -n skills/teamsmith/tests/help-surface.sh
PATH="$HOME/.bun/bin:$PATH" CI=1 OPENSPEC_TELEMETRY=0 openspec validate help-route-render-once --type change --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/help-surface.sh
```

### B. 非作者：冻结候选上集中跑一次受影响行为

PM 准备独立检出，非作者完成 delta 四场景：在私有磁盘根/既有隔离方式下运行 **一次** `TMPDIR=<已创建私有磁盘目录> bash skills/teamsmith/tests/help-surface.sh --select route`，使用当前完整 manifest，保留日志/退出码；核循环真实三入口都在及 188→141 结构账，不要求另跑一轮旧 route 或逐条耗时比较。当前 `--select route` 会保留其它 route 检查，但不会执行其它帮助组。

同一验证批再执行 §3 的短受控输入集合和一次调用点失败接线，留原始输出与恢复记录。这是唯一候选行为批次，不为每个反例重跑正常 route。验证者记录实际命令、输入及原件，不将候选运行省略为“静态可证”。

复用边界：V168 独立静态审阅 `61ade73d` 已绑定原件 `/var/tmp/rel47-first-order.log`，SHA-256 `9ca9986e014307573cf7577ad6572d6a2d5c59f4f6fccd81158ea7b2375d2545`，源提交 `572856a3ae57503396019020f58e8e6abcc08db4`；全轮实际为 5139 成功 / 2 失败、rc=1，仅其中 help 子脚本有 132 条局部成功，不是全轮绿，整个 51 的 681 秒也不是本批收益。从该源到本轮规划候选 `ea6e9534`，`help-surface.sh`、manifest、`routes.sh`、`lib/routes-pages.sh` 及 51 的 1322 字节帮助消费者实际字节相同；该消费者不包括已删除的配置重复块。期间 `cmd-project.sh`、`cmd-review.sh`、`cmd-watch.sh`、`common.sh` 等差异的消费适用性，引用 `docs/team/reports/V167-verify.md` §7 的逐项审阅，不声称整个产品依赖树未变。未来实现相对该基线只改本批单命令比较/最小函数，继续核未改 `page`、`load_manifest`、其它组和 route 其它块、帮助库/清单/语言表/locale 输入、routes/pages 及 51 帮助消费者；相关输入有变化才定点补验。若原件无法证明某项同一性，如实列为复用证据缺口，由 PM 定点裁定，不默认重跑整套。不同 locale/宽度矩阵、coverage/claims/invariants、routes/pages 与整段 51 本次不重跑；上述源码/输入同一性及限定消费审阅是复用依据，不把 P432 引用或 RED 夜间算绿，也不称未改入口在新提交上又实测了一次。

### C. 合并后与回退

同一非作者在 PM 准备的合并后固定检出上，比较受验候选与合并版的测试函数、调用点、最终出口及所有输入/产品依赖的字节同一性；保持相同则复用 B，不再跑全 manifest route，仅补一条正常和一条损坏/恢复的同判定短样本并记录合并 SHA。存在相关差异时，只补受影响入口，不能直接引用旧行为结论。

若三入口任一消失、尾换行判定失真、非零入口不报错、父级丢失 finding，或替换需要跨命令缓存/新框架，停止并交回 PM；未合并候选返修，已合并问题按授权回退本批最小提交。无数据迁移、现场配置或团队重启；归档另派非实现者，在其授权阶段再做原生试归档和同步。本轮不 archive。
