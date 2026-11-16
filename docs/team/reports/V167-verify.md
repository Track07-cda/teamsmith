# V167 · 配置检查去重的独立行为验收

**最终判定：两阶段验收范围 PASS，原生清单 7/7。** 一次完整配置入口和七次独立选段均成功，保留的拒绝、写盘、名册字节与真实进程检查有效；额外故障样本按目标失败。合并版本的编排、子脚本及消费者与已验候选一致，必要短检查已直接从合并检出执行，正式 `team review P461` 由同一 verify 写出 merged PASS。阶段B没有重跑上述行为；原有跳过、首轮观察脚本错误及FAIL原件全部保留。交PM接受最终证据，不声称全量、零跳过、提速实测或已经获得归档授权。

agent: verify   status: DELIVERED（阶段A/B范围PASS，待PM最终接受）   time: 2026-11-16T10:28:19Z
branch: `task/V167-config-dedup-verify`   PR/MR: -（仅本地提交）

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V167-verify.md` | 两阶段独立验收及原始失败/限制 |
| `openspec/changes/config-check-execution-dedup/tasks.md` | B正式通过后从merged读入，保留作者三项，仅完成本单四项；原生7/7 |
| `docs/team/reviews/P461.md`、`P461-verify.log` | 从自己的工作树调用正式review生成；最新绑定merged SHA，执行者verify；候选记录另保留原件 |
| `/var/tmp/v167-verify.CjCL5K/` | 一次性 runner、逐命令完整日志/rc、原字节比较、原51日志副本、坏树/恢复记录、首次失败及更正读取记录；不加入仓库 |

候选：`b26bd4196a201c8c8f6de4d176f06acb788f0165`，独立检出 `/var/tmp/p461-review-b26bd419`；merged：`c442b57acb44433c7a761cb9f3f6dd43a75a3279`，独立检出 `/var/tmp/p461-review-merged`，两者均由PM准备。各次开始/结束HEAD不变，普通及ignored状态均空，见E的 `start/end/settled-checkout.txt` 与 `merged/start/end-checkout.txt`。PM的阶段A接受记录为 `docs/team/reviews/V167.md`；原阶段A报告按原字节保存在 `E/V167-stageA-report.md`，提交 `6a188dca` 保留。

## OpenSpec assessment

使用生成的 `openspec-verify-change` skill 等价流程，工具为 OpenSpec **1.16.0**；读取原生 status、apply instructions 的全部 contextFiles（proposal/design/delta/tasks），以及正式 proposal review、D246 和作者原件。schema=`spec-driven`，根是固定候选，不把 planning 的 `isComplete=true` 当成实施完成。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 原生7/7；2 requirement / 5 scenario | A接受后B真实通过并正式review绑定merged，再按授权同步四项；`native-apply-synced.json`为all_done/7/7/0 |
| Correctness | 两requirement及五scenario的候选行为证据齐；merged同一性及适用短检查通过 | 下表A实证、B五文件及消费者实际字节相同、直接从merged执行三份选择计划；静态生成目录存在性及原51的1条跳过仍未改记通过 |
| Coherence | 接受设计、实际实现与合并接线一致 | 整文件精确变换、5296字节准备块、父级/消费者原字节、两token/七边和merged完整skills树同一性；没有新增检查器或改前提 |

### requirement / scenario 映射

| Requirement / scenario | 本轮证据及边界 |
|---|---|
| Normal configuration checks have one execution site / 两受影响段保留真实检查且不重放 | 正常33 child 21组、331/0；父调用原691字节；51删除唯一重复块，routes/help原2092字节及三脚本hash不变；51沿用原记录，不是本轮重跑 |
| 同 requirement / 独立入口保持自身范围 | config-cli默认组原99890字节不变；33真实执行一次；七个独立选择实际段头均只有前导和自己，无33/配置child；51无needs:33；坏腿区分assertion=1与setup=3 |
| 同 requirement / changed paths仍选择消费者 | config-cli→33不带51；cmd-config→33和51；未声明路径→FULL但没有真的执行FULL；header路径→12e且不带33 |
| Change-workflow preparation does not schedule configuration execution / 每键从自身准备开始 | 七次各新TMP、各自p24项目；12g真实拒绝、12h真实派单/审计/monitor均执行；没有FAST替代 |
| 同 requirement / 缺准备不得空跑成功 | 仅删p24_brief，保留project/change/路径/shim；12e点名command not found且具名行为失败，退出1；原字节恢复后复用正常12e，不重复执行 |

## CRITICAL

None — 原阶段A报告的四项未完成状态已逐一收口：1.3/2.2/3.1的A实证已获PM接受，3.2已实际执行B并由正式review绑定merged；其后从merged清单保留作者三项、完成本单四项。原生进度现为7/7/0，见 `E/merged/native-apply-synced.json`。原A的3/7和CRITICAL 4仍保存在 `6a188dca` 与原字节报告中，不改写当时事实。

## WARNING

None — 已执行范围未发现规格或设计偏离。静态检查具名SKIP与原51的既有跳过按下文保留，不计为通过。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（本单已执行的候选及merged验收范围）。
- Readiness: 本单已完成，可交PM接受最终证据；不能给出不带范围的“所有检查通过、归档就绪”，归档仍需既有接受与有效确认，另行派单。
- Unverified applicable checks and limits: 静态 `.pi/skills` 存在性未验，原因是该机器生成目录不在固定检出；原51的1条可见跳过只保留原父级来源，未展开其身份，也未改记PASS。两requirement/五scenario及阶段B约定内没有其他待执行项。
- 整套/FAST全量、完整51/help/routes重跑与变异矩阵、meta/61b/夜间、安装/性能均按本brief不执行，不构成本轮承诺；未测量正常完整运行的改后耗时，未把七个局部收益相加当成全量节省。

## Verification evidence

证据根简记 `E=/var/tmp/v167-verify.CjCL5K`。所有逐命令 argv/cwd/env/rc/参考秒数在 `E/results.jsonl`，完整输出在各同名 `.log`；不是只靠后台工具的有界尾日志。临时runner/坏树在E内，smoke/config原入口按要求使用 `TMPDIR=/var/tmp`，其自己创建的精确根保存在每个 `*-roots.json`，所有原日志继续保留，未按通配清理。

### 正式执行与首轮观察错误

```sh
# 从自己的verify工作树发起；TEAM_GATES中的runner在固定候选cwd逐条串行执行
PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 \
TEAM_GATES='python3 /var/tmp/v167-verify.CjCL5K/run.py' \
bash skills/teamsmith/scripts/team review P461 \
  --dir /var/tmp/p461-review-b26bd419 \
  --branch b26bd4196a201c8c8f6de4d176f06acb788f0165
```

后台 `v167-candidate`，review rc=1，实际串行批次360s。**不是业务红**：八个正常场景rc均0、三个额外坏腿rc均1且目标诊断在；汇总失败来自自己的两个观察错误：

- `independent-static.log` 已完成所有原blob比较，随后严格UTF-8解码原全量日志遇无效字节；原日志原字节完整保留。
- `behaviour-audit.initial.log` 的46/48中两条失败，因为只认 `== 结果 ==`，没有认真实选段的 `== 选段结果 ==`。

保存 `central-review.initial.md/.log`、`audit.initial.py`、原 `behaviour-audit.log` 后，仅修日志读取：允许显示替代无效字节，并匹配真实选段标题。`settle.py`只读取既有原件、收取未完成的原51读取和更新检查结果，没有运行smoke/config/routes/help或重复静态选择器命令。

```sh
PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp OPENSPEC_TELEMETRY=0 \
TEAM_GATES='python3 /var/tmp/v167-verify.CjCL5K/settle.py' \
bash skills/teamsmith/scripts/team review P461 \
  --dir /var/tmp/p461-review-b26bd419 \
  --branch b26bd4196a201c8c8f6de4d176f06acb788f0165
# rc=0；2026-11-16T10:16:48Z；实际执行者verify；记录PASS，ran=2s
# All 8 normal runs and 3 additional bad legs executed exactly once
# AUDIT 48 / 48
# Candidate scope PASS ... merged revision NOT RUN; no full-suite PASS claim.
```

第二作业 `v167-observation` 已收取rc=0；2s是读取原件的时间，不是重新跑完行为的时间。候选PASS原件另存 `central-review.candidate-pass.md/.log`；报告没有抹掉首次FAIL。

### 1 / 2：一次正常33、七键分别独立

真实命令分别为：

```sh
TMPDIR=/var/tmp TEAM_CONFIG_KEEP=1 bash skills/teamsmith/tests/smoke.sh --select 33 --keep </dev/null
# 以下key分别独立调用，各一次，每次创建新TMP，不是合跑
TMPDIR=/var/tmp bash skills/teamsmith/tests/smoke.sh --select <12e|12f|12g|12h|12i|12j|12k> --keep </dev/null
```

| key | 实际该段✓/✗/SKIP | 含四前导的选段结果 | rc | 具名证据 |
|---|---|---|---|---|
| 33 | 1/0/0；child独立331/0/0 | 25/0 | 0 | config-cli真实child，不用外层1条成功代替默认组 |
| 12e | 53/0/0 | 77/0 | 0 | 头部夹具27条；ready/notready、squash-merge/weird-paths项目 |
| 12f | 27/0/0 | 51/0 | 0 | change归组、none/many及面板机器出口/布局 |
| 12g | 75/0/0 | 99/0 | 0 | 锚/拒绝及 `[real]` 非零、零session、拒绝不打印提示词 |
| 12h | 42/0/0 | 66/0 | 0 | delta重叠拒绝；`[real] --force`成功、恰一条审计、monitor读取 |
| 12i | 17/0/0 | 41/0 | 0 | 按change独立性及原拒绝/override |
| 12j | 46/0/0 | 70/0 | 0 | 普通/checklist/archived项目的归档前置 |
| 12k | 32/0/0 | 56/0 | 0 | 模板头部、help、协议及实际渲染AGENTS/PROTOCOL |

七个正常运行没有具名跳过，实际段头均精确是 `0 0b 0c 0d <key>`，七个根互不相同且有各自p24项目，无config-cli.log。12g/12h真实腿未换成记录式替身，仍使用原有私有tmux与受控进程。

33 child：`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.txk9hn/config-cli.log`；内部根 `/var/tmp/teamsmith-config-cli-pm_skills-deb708fe.xhvYKS`，对应日志副本在 `E/config-inner-logs/`。默认21个组逐一有组头且只出现一次：

```text
list groups writer inject cas validate seam audit roster models shape flip-shape
model-window flip-model-window seats json completeness docs callers flip groups-flip
== 结果 ==  ✓ 331  ✗ 0  SKIP 0
```

### 3 / 4 / 5 / 6：保留坏恢复与必要额外坏腿

| 实验 | 真实命令/观察 | rc及目标结果 | 恢复证据 |
|---|---|---|---|
| validate/refuse | 读取本轮33的 `refuse-flip-green0/red/restored.log`，不额外跑validate | 0→1→0；22/0/SKIP1→21/1/SKIP1→22/0/SKIP1；坏腿精确为 `TEAM_PROJECT=x → 5（refuse）（期望 [5]，实际 [4]）` | 同轮原件与child写出的0/1/0；SKIP1是scratch再入不重复嵌套的原规则 |
| writer | 读取同轮33的 `flip-red/green.log`，不额外跑writer | 1→0；10/10→20/0；精确 `行内注释原样保留、值换成单引号形态（期望 [1]，实际 [0]）`，另保留缺尾换行/引号/注入故障 | 同轮green原件和实际rc=0 |
| roster假成功 | `TEAM_CONFIG_TREE=E/roster-tree TEAM_CONFIG_KEEP=1 bash <候选>/skills/teamsmith/tests/config-cli.sh roster`；仅让api注册返回0但不写名册 | 1，85/12/SKIP0；`③ add-agent api --register → 0`先成功，随后 `③ 新值逐字 = dev verify api`及单行diff断言失败；不是setup红 | 恢复 `cmd-agents.sh` 与候选精确一致，sha256 `6b16d556f1a6370accf90c3637e5fd1b3e77676fedb77d54f2ca6f370e35836f`；正常复用33 |
| child→33失败 | `TEAM_CONFIG_TREE=E/empty-tree TEAM_CONFIG_KEEP=1 env SHELLOPTS=xtrace bash skills/teamsmith/tests/smoke.sh --select 33 --keep`，TMPDIR仍/var/tmp | smoke=1，24/1；真实child日志点名空树缺CLI并trace `+ exit 3`，父级点名 `33 config-cli.sh 有失败` | 原父级691字节未改，正常复用33；不冒称该setup腿重跑assertion=1 |
| 缺准备 | scratch独立克隆仅移除 `p24_brief`定义后 `smoke.sh --select 12e --keep` | 1，49/28；点名 `p24_brief: command not found`；`12e 全结束 → 退出 0（期望 [0]，实际 [1]）`等具名失败 | 恢复整份smoke精确候选字节，sha256 `1572178e9c4894112e2b18a60b570ab3b4baf5a157d80e04c1a2213360cb8b4f`；正常复用独立12e |

额外三个坏腿各执行一次，正常/恢复没有重新跑完整配置或七键。每个坏腿的非零在 `results.jsonl` 逐条按预期收取，原件在 `roster-bad.log`、`parent-setup-bad.log`及其保存child、`missing-prep-bad.log`，并有 `roster-restored.txt`、`missing-prep-restored.txt`。空树setup观察只加xtrace，不改config-cli或父分支。

### 7：51原局部证据的来源与适用性

来源 `/var/tmp/rel47-first-order.log`；已复制原字节到E，sha256 `9ca9986e014307573cf7577ad6572d6a2d5c59f4f6fccd81158ea7b2375d2545`。头尾均绑定 `572856a3ae57503396019020f58e8e6abcc08db4`，末行实际 **rc=1**、全轮5139/2；只沿用其中51的routes 255条/1条可见跳过、help132条局部成功，不把原全轮改称PASS。

从该原提交→接受基线 `9e3833bb`→候选逐字节核对：

| 脚本 | 字节数 | SHA-256 |
|---|---:|---|
| config-cli.sh | 99890 | `a4a018b5c4a883e6929b95634dbcc32adf7cf489a40a5ebdcf1568c11a91a88c` |
| routes.sh | 108261 | `0d1000f46c1a2f6045142a75d477fd6a205a6f935a9dcb5ce7637c6a532df2da` |
| help-surface.sh | 81545 | `2ea27c25d7aabf25b95e103d966e4f8b49e6ca265b79da29999d28ff7c964b98` |

保留父调用2092字节、argv顺序、cwd/输入、FAST分支和汇总均相同；routes-pages/tmp-root/model-policy/bounded-spin四helper及templates/references/strings也相同。不是声称整个产品树没变：`51-consumed-source.diff`保留全部期间差异，逐项审阅如下。

- `cmd-project.sh:431`：只改生成AGENTS时的技能路径；routes/help的init配置/名册行为及声明的写入面未变，二脚本不以AGENTS路径正文作判断。
- `cmd-review.sh:90`：显示根替换的左边界修复；help的review样本仍是 `--no-gates`，声明/判断的是docs写入与幂等，不依赖该绝对路径字串。
- `cmd-watch.sh:1500`：只把注释示例通用化，无执行字节变化。
- `common.sh:6`与SKILL元数据：仅0.4.6→0.4.7；两脚本没有固定旧版本值断言，命令/路由/效果定义不变。

上述差异没有改变被复用局部证据的判断前提，因此没有补跑51入口。原父级只显示routes的1条可见跳过，未展开其身份；本报告保留这一来源限制，不猜它是哪条、不说该分支已验。

### 8：结构、选择、暂存后检查

独立原blob比较的首轮日志已证明：完整准备块 **5296字节/91行/14函数**原样移到首段前；消费者59603字节、33父级691字节、51保留区2092字节均不变。整份smoke只经批准的删块/说明/移动即与候选1907359字节完全相同。表恰改两token和七条needs/依据；所有其他行/needs及循环清单原文不变。没有把作者PASS当作证据。

本轮下列命令各一次，均rc=0；原件同名保存：

```text
openspec validate config-check-execution-dedup --type change --strict
  Change 'config-check-execution-dedup' is valid
bash -n skills/teamsmith/tests/smoke.sh
bash skills/teamsmith/tests/spec-refs.sh --check
  judged 122 references / 49 distinct; retired 0; undeclared 0
bash skills/teamsmith/tests/section-select.sh --check
  ok 13 bad 0 SKIP 1；行19机器生成面 .pi/skills 不在本检出
bash skills/teamsmith/tests/section-select.sh --self-sufficient
  ok 141 bad 0；433函数，assert_*未定义0
bash skills/teamsmith/tests/section-guard.sh --loop-check
  86行清单 / 86循环 / 配平86，全过
```

七个 `section-select.sh --select <key>`各一次，均RUN/5键=`0 0b 0c 0d <key>`。四路径计划各一次：config-cli为RUN/7键（含33不含51），cmd-config为RUN/22键（含33/51），task-header-model为RUN/7键（含12e不含33），`ci/config-dedup-unclaimed`为FULL；没有真的跑FULL。

Ledger ban在自己的任务分支暂存本报告后实际执行，原件 `E/ledger-ban.log`；仅将个人目录展示为 `<repo>`：

```sh
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<repo>/.worktrees/verify scope=published files=2761 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
# 无输出，rc=0
$ git diff --cached --check
# 无输出，rc=0
```

## 阶段B · 合并版本复核与清单同步

PM已接受阶段A并提供准确merged输入；使用新 `E/merged.py`，实际命令cwd全部为 `/var/tmp/p461-review-merged`，没有拿硬编码旧候选的runner冒充merged。后台 `v167-merged-short`已收取rc=0，正式记录时间2026-11-16T10:26:49Z，执行者verify，绑定完整merged SHA，ran=5s。

```sh
# 从自己的verify工作树发起
TEAM_GATES='python3 /var/tmp/v167-verify.CjCL5K/merged.py' \
bash skills/teamsmith/scripts/team review P461 \
  --dir /var/tmp/p461-review-merged \
  --branch c442b57acb44433c7a761cb9f3f6dd43a75a3279
# rc=0；P461.md/P461-verify.log：PASS / actual executor verify
```

原件在 `E/merged/`：`results.jsonl`、每条命令完整日志、`central-review.merged-pass.md/.log`、起止状态。完整 `skills/teamsmith` Git树两端同为 `43cb5d825dcc811503191a415d0882f7a60d5401`；候选到merged差异只有六份docs/team账本文件，不改变受测输入。

- 直接比较实际文件：smoke 1907359字节、section-paths 75440字节及三子脚本全部相同；AGENTS和change四context文件也相同。
- 再取实际smoke中的准备块5296字节、七消费者/live前提59603字节、33父级691字节、51保留父级2092字节，全部与A候选一致；hash原件可与上文核对。
- 直接从merged运行OpenSpec 1.16的status/apply、change严格校验、`bash -n smoke.sh`，各rc=0；同步前原生清单仍3/7，未偷偷修改固定检出。
- 直接从merged运行三个必要短计划，各rc=0：`section-select.sh --select 12e`仍只有四前导+12e；`--paths skills/teamsmith/tests/config-cli.sh`含33不含51；`--paths skills/teamsmith/scripts/lib/cmd-config.sh`同时含33和51。
- 没有重跑正常33、七键行为、坏腿、51或完整矩阵；同一性支持继续采用A证据，不是又获得一份正常行为重复样本。

正式merged PASS之后才同步自己的 `tasks.md`：读取merged原件，保留1.1/1.2/2.1三个作者勾选，只把1.3/2.2/3.1/3.2四项改为已完成，其余正文与merged逐字节相同。提交 `03a181d9`。自己的旧分支起点尚无作者三项，所以本分支diff显示七行复选框变化，其中三行是同步，不是本席位重新宣称实现。

```text
$ openspec instructions apply --change config-check-execution-dedup --json
state=all_done progress={total:7, complete:7, remaining:0}，rc=0
$ openspec validate config-check-execution-dedup --type change --strict
Change 'config-check-execution-dedup' is valid，rc=0
```

原件为 `E/merged/native-apply-synced.json`、`strict-synced.log`；root/sourcePath明确是自己的工作树。固定merged检出的清单仍原3/7，没有向PM检出写文件。PM明确授权B实际通过后立即同步，不另等一句确认；PM尚未接受未来的最终关单结果。

阶段B最终报告暂存后，再在自己的分支执行上文同一ledger-ban命令与普通/暂存diff检查：`files=2761 hits=0 names=ok user=resolved`，rc=0；两个diff-check均无输出、rc=0。原件 `E/merged/ledger-ban-final.log`，未改扫描名单。

## Flip evidence

见上表的真实原件与精确诊断：TEAM_PROJECT拒绝与writer注释故障都来自同轮33生成的既有坏恢复；额外roster/父级setup/缺brief三腿各一次。原字节恢复与正常33/12e共同证明恢复，不把不存在的恢复重跑写成执行。

## Decisions and deviations

- 没有实施写集变化；不修改候选/merged、实现、正式spec、规划、其它测试/CI/超时/跳过；A不改tasks，B正式通过后仅按授权同步自己的tasks。
- 第一次正式review的FAIL是两个一次性观察脚本错误；保留原记录，按brief只更正读取，没有为了收据重跑正常业务。
- `TMPDIR=/var/tmp`的原入口自行建立的运行根在E之外；其精确路径、原日志及E内副本均保留到PM接受，不改产品临时根机制，也不按项目通配清理。
- 没有merge/push/archive/tag/npm，没有真实提醒/standby/真实团队重启或外部模型调用。

## 未运行段

本轮实际正常执行集合为四前导+33+12e–12k；其余129键没有执行（51仅使用上文原局部证据）：

```text
0e 0f 0g 0h 0i 1 1b 1c 2 3 4 4b 4c 5 3b 6 6b 6c 6d 6e 6f 6g 6h 6i 6j 6k 7 7b 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11f 11g 11h 11i 11j 14b 15b 15c 12 13 13b 13c 12b 12b-h0 12b-h0b 12b-h0d 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 17 18 18b 18c 19 20 21 22 23 24 25 26 27 28 29 30 31 31c 32 34 34b 34c 34d 35 36 37 38 38m 39 40 41 42 43 44 45 46 47 48 49 50 51 51m 51b 51c 52 53 57 58 15 55 56 59 60 61 61b 62 63 64 65 66 68 69 67
```

## Suggested next steps

PM读取本报告、merged正式记录与原件，接受阶段B后办理关单；归档仍由非实现者另行接单并核有效确认。本席位不merge/push/归档。E及各具名运行根继续保留到PM收存确认，再只清理本次精确目录，不为补已收存证据重复测试。
