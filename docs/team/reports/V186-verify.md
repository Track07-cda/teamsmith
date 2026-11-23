# V186 · 0.4.8 发布前测试自检

agent: verify · status: PASS（发布测试自检） · time: 2026-11-23 UTC

branch: `task/V186-release-048-meta-freshness` · PR/MR: -

**0.4.8 的发布测试自检已通过。** 合入 P489、P490 的冻结候选 `c34e1468` 于 `2026-11-23T11:25:36Z` 产生新的原生 GREEN：**217 通过、0 失败、3 跳过，exit 0**。§61b 正常对照 1569/0；后续 31 个故意改坏的对照按名报错并恢复。该记录满足 7 天内实跑自检的要求；不等于完整产品测试通过或发布放行。前两轮 `2508dec1` 214/3、`2201a79d` 216/1 和 V174 完整产品检查 5139/2 均原样保留。

## Deliverables

| 位置 | 内容 |
|---|---|
| `docs/team/reports/V186-verify.md` | 实际运行、失败归因、版本差异、可复用证据和发布前缺口 |
| 项目共享 `.pi/team/state/meta-suite/2026-11-23T09-59-12Z.log`、`history.tsv` | 原生完整日志及追加的 RED；日志 SHA-256 `c09e1fb811a27cbdd87c5f25c8f4553f0bd28077710e09bfeff942bc61d824b9` |
| 项目共享 `.pi/team/state/bg/v186-meta-048.log` | 后台任务尾部、逐段和收取回执：2042.3 秒，exit 1 |

固定检出由 PM 准备，路径 `/var/tmp/rel048-meta.sPZDBr`，开跑前与结束后均为干净的 detached `2508dec1c39040c1392df5ed361528cfb7db4742`。测试临时现场未要求保留；原生记录明示已清理。报告只引用保存下来的日志，不宣称保留三次失败的临时子日志。

## Verification evidence

```bash
TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 bash /var/tmp/rel048-meta.sPZDBr/skills/teamsmith/tests/meta-suite.sh --snapshot=2508dec1c39040c1392df5ed361528cfb7db4742 </dev/null
```

实际作业 `v186-meta-048`，记录时间 `2026-11-23T09:59:12Z`，判据 `c715864b`；原生 smoke 合计 2036 秒，后台墙钟 2042.3 秒。原生末行及快照退出：

```text
== 选段结果 ==  ✓ 214  ✗ 3
快照运行结束：committed=2508dec1c39040c1392df5ed361528cfb7db4742 rc=1
# meta-suite result verdict=RED total=2036s sections=10 … 判据=c715864b
```

| 段 | 秒 | 通过 / 失败 / 跳过 |
|---|---:|---:|
| 0 临时仓库 | 0 | 3 / 0 / 0 |
| 0b 技能文件可加载 | 0 | 3 / 0 / 0 |
| 0c 静态检查 | 3 | 9 / 0 / 0 |
| 0d 冲突标记 | 0 | 9 / 0 / 0 |
| 0e 看门狗与循环清单 | 50 | **23 / 3 / 0** |
| 36 选段与分段 | 849 | 121 / 0 / 3 |
| 38m 设置检查与故意改坏后的对照 | 75 | 2 / 0 / 0 |
| 40 临时目录纪律 | 56 | 42 / 0 / 0 |
| 51m 命令用法检查 | 297 | 1 / 0 / 0 |
| 61b 模型路由故意改坏后的对照 | 701 | 1 / 0 / 0 |

四个前导段和六个自检段均收口。§36 的三条跳过为 internal 检出没有机器生成的 `.pi/skills`，不是段落没跑；36⑧ 产品面探针 `147/0/0`、36⑨ CI 入口 `21/0/0`。非失败段是这次冻结源的真实局部证据，不是整体 GREEN。`history.tsv` 的真实尾部为 `2026-11-23T09:59:12Z RED … 2036 10 c715864b`；没有手改、补写或重跑。

## CRITICAL · 三个失败来自同一份未更新的循环清单

原始 §0e：

```text
✗ P70 循环清单：干净树绿（86 行清单 / 88 个 while+sleep 循环，配平 86 个）（期望 [0]，实际 [1]）
✗ P70 翻转（循环）还原：绿（期望 [0]，实际 [1]）
✗ P313 翻转（盲区）还原：绿（期望 [0]，实际 [1]）
```

只读取 Git 对象，把实际 `lib/loop-scan.awk` 用于 `section-guard.sh` 扫描面的所有 `tests/*.sh` 和 `tests/lib/*.sh`，不执行这些 shell 测试，也不写固定源：

```text
191e8097^ detected=86; inventory=86
2508dec1 remind-tool-real.sh:37 remind-tool-real.sh:39 detected=88; inventory=86
```

`191e8097`（P486）引入 `remind_tool_real_wait_pi`：第 37 行依次读取进程身份，第 39 行等待同一进程退出，内层有 `SECONDS + 10` 的共同截止时间和 `sleep 0.05`。扫描器把内层 sleep 同时归到外层，一共识别两条；从 `191e8097^` 到冻结提交，`loop-inventory.tsv`、扫描器和比对代码均未变，清单没有这两条。`smoke.sh:2194–2211` 先查干净副本，再分别故意增加未登记的循环、还原后用同一清单复查；两个故意加入的故障仍按预期报红，但还原只能回到本来就不匹配的原始树。这足以解释三个退出码，不是机器慢，也不是三处独立缺陷。V185 当时只验指定的进程生命周期和合并字节，没有运行 §0e，不能替代此检查。

## 0.4.7 到冻结源的差异与独立证据

基线为 `v0.4.7` 解引用 `fdd3247a`。`git diff --stat v0.4.7..2508dec1 -- skills bin install.sh ci .github openspec/specs README.md LICENSE package.json AGENTS.md docs/team/tools` 共 **37 个路径**：21 个测试、3 个正式规格、11 个脚本/面板文件、2 个技能及配置说明。`bin/`、安装器、包清单、发布工具、README、AGENTS、CI workflow 无文件差异；P459 在此范围落的是测试执行路径和 `cmd-review.sh` 中的记录细节，不是 CI workflow 改版。以下证据对应原报告或同号 `docs/team/reviews/P…md` 的独立记录；不把作者报告或 `--no-gates` 当实跑。

| 差异 | 已有独立验证及可复用边界 |
|---|---|
| P457 / P468：模型路由参数与重复执行精简；相关脚本和 `verification` 规格 | V163 定点正常/反例及合并后短测；V173 正常 boundary 863/0、五个原故障与恢复的父级 51/0，合并后 parameters 279/0。V186 的 §61b 在 `2508dec1` 另外实跑通过（43 ticks）；不重复原五臂。 |
| P459：账本路径、可移植测试启动与 review 退出分类 | V165 安装/测试启动及故意错误的定点证据；`7245bfef` 五文件同一性和短显示/分类。后续 `cmd-review.sh` 又被 P478 改过，以 V180 对新版的实际失败/排队记录为准。 |
| P461 / P465 / P466：配置准备、帮助页生成、剪贴板测试准备复用 | V167、V170、V171 各有候选与合并版核对及相应真实入口/场景；在 V174 完整测量之前已合入。帮助路径之后又有 P475/P483，以其范围内的新回执补充，不称原帮助证据覆盖后续变化。 |
| P471 / P474：设置精简、提示文字及消息页发送受阻详情；`panel` / `memory-and-deps` / `verification` 规格同步 | V177 设置实测与红侧、合并短导航 5/0；P474 由 V179 证明正常/缺诊断/不误报状态，候选完整 panel 类型检查和重建一致，合并版实取受阻画面。V177 的历史全量类型检查失败不改；V179 的通过属于后来候选。 |
| P475 / P478：看板帮助标题；复验记录按实际排队与执行结果列示 | V178 核真实帮助和必填参数；V180 核超时/排队分类、合并版实际标记失败仍记录为已执行。 |
| P480 / P483 / P486：关键回复只读检查、性能帮助交接、提醒测试私有进程与目录回收 | V181 实际只读三组及真实终端样本；V183 实际交接/无交接/意外写状态三样本，不是性能读数；V185 五项清理证据含实际 Pi 启动刻度、退出码、日志和目录取证。三项均有合并定点核对；V185 的覆盖不含本轮新发现的 §0e。 |

### V174 两处失败如何处理

- **§38 设置页**：V174 在 `532c8b47` 上的 38-f 并非未找到文字；P472 从原解析函数确认相同样式区间就提前失败，未比较颜色且不能还原当时颜色环境。P471 取消逐行徽章，V177 用候选真实画面、读值/保存及生效提示、正反例和合并短导航验证替代行为；不要求旧徽章样式在新界面上通过，也不把历史失败改绿。后来的 P474/V179 验的是消息页和面板构建，不是重跑设置入口。
- **§69 提醒事件**：旧检查等待 `observed` 后立即读取独立的 `custom_start` 记录；P472 确认有先后间隙，原事件文件已失，不能确定历史现场只由此造成。P473 改为等待该条实际事件；V176 `0/1/0` 在正常、受控旧检查、恢复中对齐同一批观察，恢复实际执行了 G2 保护断言；合并 `cea2b7f2` 做了字节与语法核对。后来 P486 又改提醒测试驱动和外层清理，V185 只覆盖具名清理路径，本轮没有执行新驱动下的整个 §69 或重跑该原事件场景。若 PM 选择用组合证据替代完整运行，需比对这条事件与 G2 观察的实际调用路径；确有接入缺口才补相关场景。

V174 `532c8b474f9aa3ec9d9094b28ae88463cd9d88e5` 的正式记录仍是 140 段、5139 通过 / 2 失败 / 19 跳过、rc1；`V174-acceptance.md` 接收的是计时交付。上述记录可证明已替换或已修正的检查边界，不等同于 0.4.8 完整产品检查通过。

## 最终候选仍须做的检查

1. **先修 §0e，不盲重跑。** 归属人同步现有清单与等待路径，用 §0e 验证干净、故意加错、还原三种形态；不要删检查、放宽时间或改历史。之后要取得 7 天内的原生 GREEN，现有工具只能在真实完整自检通过后写出，不能把本轮 RED 与未来定点通过拼写进 history。此前的其他段不需额外单独重复。
2. **完整产品检查仍待解决。** `RELEASE-PUBLIC.md` 默认要求最终冻结对象的 OpenSpec strict 与完整产品检查。若希望引用 V174 + 已独立复验的修复和后续变化而不跑第二次全量，需就 **0.4.8** 明确接受替代证据，保存差异、覆盖范围及剩余定点结果；D244 是 0.4.7 的单次授权，不可挪用。没有该决定时不能宣称满足完整检查。版本一致性、§14d 读取新自检历史、和后续受影响的发布短检查只能在新记录和最终候选都固定后核实；如已被同一最终完整运行覆盖，无需另跑一次。
3. **逐项核对最终候选再复用。** 本轮尚未收到最终冻结 SHA。约定新增 PM 指导文字、发布版本/说明、账本，现在另有 §0e 修复所需差异；最终以实际 Git 对象为准。核 `meta-suite.sh`、`smoke.sh`、选段器/映射、每段实际输入、脚本及复制进测试的文档、版本与包文件；例如 §36 的产品面检出、§51m 的帮助宣称不能只凭脚本未变就认定输入没变。只有输入不受影响或取到对应短证据时才复用，不声称本轮跑在新 SHA。指导文字自身走已定的独立文字核对，不加模型行为测试。
4. **只在最终发布内容上核版本、公开面、包与参考读数。** 对最终冻结对象做版本六处和 CHANGELOG、发布工具本身的反例、带真实名单的公开面及账本扫描、实际打包与三条隔离安装路线并记录包成员和哈希；本地标签固定后验证 tag 指向同一提交，已做且与标签包逐文件相同的安装不用再跑。固定镜像参考读数只作记录、没有阈值；不以 V183 的交接回执或上一版测量代替。发布和发布后验证由 PM/用户按现有授权处理，本任务不做。

## OpenSpec assessment

N/A — `change: -`，本单只做发布基础设施验证，不写规范。最终候选的结构检查不在本单执行。

## Final assessment

- CRITICAL 1（§0e 一因三红）；WARNING 1（0.4.8 未取得完整产品通过或另获组合证据验收）；SUGGESTION 0。未执行发布静态、安装、参考性能、最终标签、模型或完整产品检查；均不记为通过。
- Flip evidence：本单不改实现，没有修复后证据。三个失败和两条故意加入故障的预期红均保存在原日志；不把故意变异有红当作还原通过。
- Ledger ban（本人分支的发布账本）：`TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` → `scope=published files=2976 hits=0 names=ok user=resolved`，rc=0。
- **BLOCKED（首轮）:** P486 后 §0e 清单不同步，原 RED 保留。P489 候选与最终发布树的 §0e 均已通过；当前阻塞见末节。

## P489 修复后定点 · 2026-11-23T10:43Z

在 PM 固定的 `/var/tmp/p489-review.B4F56X` 上实际执行以下命令，固定检出前后都是干净的 `7ee3db91b6b6852d06a1661b650aa08d2923df04`。`git diff 7ee3db91^ 7ee3db91` 仅 `tests/loop-inventory.tsv` 增两行；`53471f5b` 另只加作者报告。测试执行和判定代码均未改。

```bash
TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_META=1 bash /var/tmp/p489-review.B4F56X/skills/teamsmith/tests/smoke.sh --select 0e --snapshot=7ee3db91b6b6852d06a1661b650aa08d2923df04 </dev/null
```

```text
✓ P70 循环清单：干净树绿（88 行清单 / 88 个 while+sleep 循环，配平 88 个）
✓ P70 翻转（循环）：新 while+sleep → 红
✓ P70 翻转（循环）：点名 file:line
✓ P70 翻转（循环）还原：绿
✓ P313 翻转（盲区）：tmp-hygiene.sh 里塞未登记的 while+sleep → 红
✓ P313 翻转（盲区）：点名 tmp-hygiene.sh 的 file:line
✓ P313 翻转（盲区）还原：绿
#5 0e · … · 参考 用时 49s · ✓26 ✗0 SKIP0 · ticks 26
== 选段结果 ==  ✓ 50  ✗ 0
快照运行结束：committed=7ee3db91b6b6852d06a1661b650aa08d2923df04 rc=0
```

外层作业 `v186-p489-0e` 62.6 秒，exit 0；50/0 含自动带入的四个前导段 `0,0b,0c,0d`，未运行其余 136 键，含 `36,38m,40,51m,61b` 和产品检查。项目共享原始尾部 `.pi/team/state/bg/v186-p489-0e.log` 的 SHA-256 为 `14fc2917812a61164f0adc1c0e4ded117ea3a420b9e266cb0f79f3d8bc266557`；后台工具标明早期输出超过保留上限，上述结果和两组对照均在保留内容中。首轮完整日志与 `history.tsv` 的 RED 未覆盖；定点没有写出 GREEN。

两条登记分别与 `remind-tool-real.sh:37` 和 `:39` 相符。清理先把实际进程身份保存为 `writers`，再以 `"$writers"` 调用等待函数，外层靠固定字符串输入读到 EOF 停止，不读不断刷新的文件；内层检查同一进程身份，并在共同的 `deadline=$((SECONDS + 10))` 到达时返回，截止不按每个身份重置。定点证明原有清单检查恢复且仍能抓错，不是重新测量真实 Pi。PM 可接收 P489 定点；待修复合入且真正发布内容冻结后，再运行原生完整自检一次。

## 最终候选的提醒事件路径 · 只读比对

最终冻结 `2201a79de982859c0953421831c36095caf78e72`。相对首轮 `2508dec1`，账本之外的内容为两行循环清单、PM 指导及规格归档、README/CHANGELOG 和版本落点；`common.sh` 唯一执行文件差异是 `TEAM_VERSION` 从 0.4.7 到 0.4.8。相对 P489 定点 `7ee3db91`，`skills/teamsmith/tests/` 按 Git 对象无文件差异；最终自检仍从真正发布源实跑，不用定点结果代替。

- V174 的 §69 先运行故障矩阵，再以 `P442_EVIDENCE`、`P442_KEEP=1` 启动 `tests/remind-adversarial-real.sh`；在最终源 `smoke.sh:25247–25274` 比对到同一入口、相同两个参数及真实组 `passed=7 failed=0` 要求。最终对抗 shell 改为调用 `remind_tool_real_prepare`、`remind_tool_real_run --select=adversarial,death`，由 `remind-tool-real.sh:132–171` 给 Node 传私有目录、socket、Pi 路径和场景清单，并传回进程退出码；Node `remind-tool-real.mjs:41` 从同一个 `--select=` 读取场景组。P486 改变了实际运行入口和清理，而非取消该场景。
- 最终 `remind-tool-real.mjs:577–605` 仍先跑实际 PM 启动（同文件 143–175）、让无关轮次保持忙碌，设置 G1/提醒并确认只有 `intent` 且无事件，随后执行真实待命 off/on 到 G2、放行忙碌轮次。P473 引入的两步等待仍在：`observed` → 同一场景 `events.jsonl` 中的 `custom_start/team-reminder`，然后断言 `generation-ambiguous`、待命仍开、代数为 2，并写 receipt。P486 在改为 await 后仍等 off/on 各自返回 0 才放行；读取的事件文件和状态内容不变。`git diff 532c8b47..2201a79d` 显示该 provider、生产提醒/状态脚本及扩展无差异；实际 PM 启动的 `common.sh` 只有版本常量变动。
- **尚缺新驱动的同一事件实跑。** P486 为私有 Pi 加了新的启动回执、外层进程管理、同步命令后的信号交接以及 `until` 的停止检查；这些能改变测试运行时序，虽未改变正常事件判定，却不能用源码或 V185 的进程清理样本证明 `event-after` 已在新入口跑通。V176 可复用来证明旧即时读取问题与 P473 判据有效，不可冒称最终源执行过。若 PM 对 0.4.8 选择组合验收，最小补证为最终源通过实际 shell/Node 交接只跑原 `event-after`、验真实事件与 G2 结果；若最终完整产品检查已执行 §69 并通过，则不重复。本轮只读，没有启动此场景。

## 最终冻结候选的完整自检 · RED

执行者 verify，在干净独立检出 `/var/tmp/rel048-final-meta.8H1YrI` 执行一次；首尾均是 detached `2201a79de982859c0953421831c36095caf78e72`，工作树无变更。

```bash
TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 bash /var/tmp/rel048-final-meta.8H1YrI/skills/teamsmith/tests/meta-suite.sh --snapshot=2201a79de982859c0953421831c36095caf78e72 </dev/null
```

| 段 | 秒 | 通过 / 失败 / 跳过 |
|---|---:|---:|
| 0 / 0b / 0c / 0d（前导） | 0 / 0 / 3 / 0 | 3/0/0 · 3/0/0 · 9/0/0 · 9/0/0 |
| 0e 循环清单 | 50 | 26 / 0 / 0 |
| 36 选段与分段 | 856 | 121 / 0 / 3 |
| 38m 设置检查 | 75 | 2 / 0 / 0 |
| 40 临时目录 | 56 | 42 / 0 / 0 |
| 51m 命令用法 | 297 | 1 / 0 / 0 |
| 61b 模型路由 | 306 | **0 / 1 / 0** |

```text
✓ P70 循环清单：干净树绿（88 行清单 / 88 个 while+sleep 循环，配平 88 个）
✓ P70 翻转（循环）还原：绿
✓ P313 翻转（盲区）还原：绿
✗ 61b 路由翻转变异有失败（rc=1；RESULT pass=2 fail=1 selected=flip）
    FAIL flip-baseline-green
== 选段结果 ==  ✓ 216  ✗ 1
快照运行结束：committed=2201a79de982859c0953421831c36095caf78e72 rc=1
```

后台 `v186-final-meta-048` 实际退出 1，墙钟 1653.7 秒；原生总计 1649 秒，10 段有收口。§36 的三次跳过仍是缺机器生成的 `.pi/skills`，36⑧ `147/0/0`、36⑨ `21/0/0`。这是 P489 在最终发布源的实际通过记录，不是全套通过。

原件：共享 `.pi/team/state/meta-suite/2026-11-23T10-46-59Z.log`（SHA-256 `726b795aa5fd8fd79ab59251a849c72b2f6fc7117671d77d861e2806992bf911`），后台 `.pi/team/state/bg/v186-final-meta-048.log`。原生 `history.tsv` 新增 `2026-11-23T10:46:59Z RED … 1649 10 c715864b`；上轮 `09:59:12Z RED` 和过期的 `11-13 GREEN` 都在，没有手改。没有保留临时测试现场。

### 失败定位和未证实边界

- `task-model-routing.sh:1430–1442` 先对未改的源执行一组正常检查（`policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,heal,adopt,updatecheck,boundary`）；`flip-baseline-green` 断言该子进程返回 0。随后 31 个故意改坏的对照只在该值为 0 时启动；因此此次未执行它们，不能把本次 §61b 当作有效翻转证据。日志没有外层挂住消息或命名的子运行 1800 秒超时，306 秒也低于两种上限；不能据此猜某个内部步骤未超时。
- 细节本应在内部 `flip-baseline.log`；`smoke.sh:24896–24899` 的外层失败输出只摘父级 `FAIL` 行，删掉现场后留下的原件无法指出哪个正常子组失败、失败诊断或子进程的确切退出值。首轮的同段实际记录是 31 条故意改坏均报错并还原（`RESULT pass=216 fail=0 selected=flip`）。两次路由测试脚本逐字节未变，但最终源有版本与 PM 指导模板变化，不能据此认定只是偶发问题，也不能将失败归到其中任何一项。
- **BLOCKED（当轮）:** 原始证据不足以定位正常组中的具体失败；不盲重跑完整自检。后续改为只对照找到的文案断言并在修复候选执行原初始化分组，见下节。未运行产品全量、§69 或提醒事件样本；最终是否采用组合产品验收另行决定。

## P490 定点复验 · 2026-11-23T11:22Z

**候选定点通过。** `2201a79d` 与候选 `2fed5716e2e20e4a0d6f2ac728c19d30c9ed29c9` 的测试目录无差异。修复提交只换 `skills/teamsmith/templates/pm-prompt.md.tmpl:154` 的短语；相对原发布源其余差异是账本。`2eb41d19` 只加作者报告。对照前后两处检出均干净。

1. 从两棵冻结树的 `task-model-routing.sh:921` 分别解析同一行 `init-guidance-separate-gates`，执行它实际使用的 `bash -c`，只将 `$SKILL` 指向各自检出；两处命令体逐字相同。该条件要求 `references/migration.md` 和 `templates/pm-prompt.md.tmpl` 同时含 `separate recorded gates`。修前 `2201a79d` **rc=1**，候选 **rc=0**。两版 migration 未变；修复只把模板的措辞改回原检查要求，没有修改检查。
2. 文案仍限 Teamsmith 工具来源升级；四项操作仍依次是私有源验证、落入共享或受保护的树、写当前项目配置并首次用它启动新的 PM、采用变更后的共享技能或副本来源。逐条预览命令并取得授权的要求未变，特别是写配置和首次启动各自授权；共享链接读取当前目标字节的提醒未变。两版原文比对直接见模板同段。
3. 只在 `/var/tmp/p490-review.H4jnXw` 执行原有初始化分组一次：

```bash
TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_ROUTING_EVIDENCE=/var/tmp/v186-p490.L21BnN/evidence bash /var/tmp/p490-review.H4jnXw/skills/teamsmith/tests/task-model-routing.sh --select init </dev/null
```

```text
PASS init-private-shared-source-unchanged
PASS init-private-link-intact
PASS init-guidance-shared-effect
PASS init-guidance-separate-gates
PASS init-guidance-ownership-not-model
RESULT pass=68 fail=0 selected=init
```

实测作业 `v186-p490-init` 20.2 秒，命令和作业均 exit 0。`/var/tmp/v186-p490.L21BnN/` 保留 `command.txt`、`init.stdout`（71 行，SHA-256 `6fa9b06a268c0e10b6c2b548e8dbfcfb91ddc9934c7b53e2eaed91974e04cfed`）、`init.stderr`（空）、`init.rc`、两次原条件回执，以及脚本从私有临时树导出的 904 个普通文件。后台尾部另存 `.pi/team/state/bg/v186-p490-init.log`。

原条件反例证明 `2201a79d` 的正常对照至少有一条本会失败的条件；当时内层日志已失，不能证明它是唯一历史原因。候选没有跑其余正常组、31 个故意改坏的对照、完整自检、模型或已有项目启动。原 RED 未覆盖；PM 随后接收定点并重新冻结，完整自检证据如下。

## 合入 P490 后的冻结候选 · 完整自检 GREEN

固定检出 `/var/tmp/rel048-meta-p490.87ZeWU` 前后皆为干净的 detached `c34e1468ea2ab76bdff9cd2bbef0db650604d151`。相对上一冻结源 `2201a79d`，唯一非账本差异是 PM 指引模板的一行措辞；该模板与已通过定点核对的 `2fed5716` 逐字节相同。收取时本地 `main` 相对受检 SHA 只有 8 处 `docs/team/` 记录变化，受检发布内容无差异；本轮判定仍绑定实际执行的 `c34e1468`，不是在后续 SHA 上重跑。

```bash
TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 TEAM_ROUTING_EVIDENCE=/var/tmp/v186-meta-p490.WaKOKs/routing bash /var/tmp/rel048-meta-p490.87ZeWU/skills/teamsmith/tests/meta-suite.sh --keep --snapshot=c34e1468ea2ab76bdff9cd2bbef0db650604d151 </dev/null
```

作业 `v186-merged-p490-meta` 退出 0、墙钟 2044.8 秒；原生记录 `2026-11-23T11:25:36Z`、2038 秒、10 段、判据 `c715864b`。六段及四个前导均实际执行：

| 段 | 秒 | 通过 / 失败 / 跳过 |
|---|---:|---:|
| 0 / 0b / 0c / 0d（前导） | 0 / 1 / 2 / 1 | 3/0/0 · 3/0/0 · 9/0/0 · 9/0/0 |
| 0e 循环清单 | 49 | 26 / 0 / 0 |
| 36 选段与分段 | 853 | 121 / 0 / 3 |
| 38m 设置检查 | 76 | 2 / 0 / 0 |
| 40 临时目录 | 56 | 42 / 0 / 0 |
| 51m 命令用法 | 297 | 1 / 0 / 0 |
| 61b 模型路由 | 698 | 1 / 0 / 0 |

```text
PASS init-guidance-separate-gates
RESULT pass=1569 fail=0 selected=policy,machine,init,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,heal,adopt,updatecheck,boundary
✓ 61b 路由翻转变异：31 条臂按名变红并还原（RESULT pass=216 fail=0 selected=flip）
== 选段结果 ==  ✓ 217  ✗ 0
快照运行结束：committed=c34e1468ea2ab76bdff9cd2bbef0db650604d151 rc=0
```

正常对照实际 rc=0、306 秒，完整 `flip-baseline.log` 有 13,372 行，记录了 P490 对应检查通过。该子记录和翻转组 216/0 不叠加到外层 217/0。§36 的三项跳过仍是检出未生成 `.pi/skills`；36⑧ 147/0/0、36⑨ 21/0/0。§40 明示因本轮使用 `--keep` 而留下现场，不将保留判为泄漏；该条件不计为跳过，段落 42/0。

| 原件 | 保留位置 / 校验 |
|---|---|
| 原生完整日志和 history | 共享 `.pi/team/state/meta-suite/2026-11-23T11-25-36Z.log`，SHA-256 `41e86774642bb3316affb98699c6cf0fb093bfea8d66ea306acf1a4ea0a38b17`；`history.tsv` 新增 `2026-11-23T11:25:36Z GREEN … 2038 10 c715864b`，先前两条 RED 仍在 |
| 实际命令、stdout、stderr、rc 和检出状态 | `/var/tmp/v186-meta-p490.WaKOKs/`，`meta.stderr` 为空；收取尾部在共享 `.pi/team/state/bg/v186-merged-p490-meta.log` |
| §61b 子日志 | `/var/tmp/v186-meta-p490.WaKOKs/routing/teamsmith-task-model-routing-pm_skills-deb708fe.HCfbY8/`，含 46 份 `flip-*.log` 和 31 份变异回执；`flip-baseline.log` SHA-256 `e0fc17c66de20595fceeb4d57eed815925965855495f038b8aaa8eb4e8d0b158` |
| §61b 外层原件 | `/var/tmp/teamsmith-smoke-pm_skills-deb708fe.V6CBsy/p238-routing-flip.log`，480 行，SHA-256 `b323622eb514a177416985bbd4d3c3ba8b1729ffeb33220dc46a4c39c1792470` |

未重跑 §61b 或 init，未更改判定或历史，原件留给 PM 保存。此更新关闭 V186 新鲜度要求和 P490 合并版复验；不覆盖产品全量、提醒事件现场缺口、打包、安装或推送发布。
