# A10 · 帮助入口单次生成的规格同步与收尾

**已完成本任务分支的原生同步与归档：五份变更文件原样保留，正式 verification 仅追加已接受的一条需求、四个场景。** `openspec validate --all` 为 20/20、rc0，`spec-refs.sh --check`、报告暂存后的账本扫描和两种 diff-check 均 rc0；账本扫描 hits=0。交 PM 接受后合并关单，不代替 PM 作接受结论。没有重跑帮助或任何 smoke 行为，也没有测量整套提速。

agent: dev2   status: DELIVERED（本地分支，待 PM 接受）   time: 2026-11-16T12:27:22Z
branch: `task/A10-archive-help-render-once`   PR/MR: -（本地）
baseline: `704d44cb4b8e56c31e8c539cd3180ddec1b7b458`
archive commit: `e054e43e63e417c622bc7fbb1155ec7658004a73`

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-16-help-route-render-once/` | 原生 CLI 移入五文件，含 `.openspec.yaml`；Git 识别五项 R100，清单保留 4/4 |
| `openspec/specs/verification/spec.md` | 原有 168737 字节完全保留，尾部追加 3027 字节；既定一条 requirement/四个 scenario 各一次，净增 26 行 |
| `docs/team/reports/A10-dev2.md` | 本轮执行、原件位置、范围核对与既有证据边界 |

独立证据根为 `E=/var/tmp/a10-help-archive.76iFdd`；`native/` 保存 list/status/instructions 与 team change 的 stdout/stderr/rc，`results/` 保存原生归档及本轮检查的 stdout/stderr/rc，`baseline/` 保存起点 OpenSpec 普通副本、HEAD 与全部跟踪文件的字节/模式摘要，`tests/audit.py` 为本次外部只读核对。原件/快照保留本地，不入 Git；仅自己的 `E/trial` 已删除，未清理 P465/V170 原件或任何其他目录。

## OpenSpec assessment

已读取项目现有 `openspec-archive-change`、`openspec-sync-specs` skill、change 全部工件、正式 archive 相关要求与 `reviews/P465.md`、`reviews/V170.md`、最终 `reports/V170-dev3.md`。使用已安装 **OpenSpec 1.16.0**；原 PATH 无 CLI，所有原生命令仅前置 `PATH="$HOME/.bun/bin:$PATH"`，没有安装、升级或初始化。

归档依据是 D251 按 D241 的明确确认，以及 PM 已接受的 dev3 最终报告 `5277cf1c`、工具记录绑定的 merged `7d768f1a134e88e72e74fd43f6c34788718b8a3a`。本席未实现本 change；本次授权只涉及 A10，不涉及其他提案或发布。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 原生清单 4/4，四规划工件 done | 本分支 list 唯一匹配 4/4；apply complete4/remaining0/all_done；归档 tasks 保留原四个 `[x]` |
| Correctness | 同步 1/1 requirement、4/4 scenario，内容恰一次 | 原生 trial/actual 都 rc0；完整旧 main-spec 前缀与 delta 原文逐字节比较；五文件原样移入 |
| Coherence | 原生根为稳定 dev2 工作树，仅授权差异 | actual/trial 的最终 spec 同一；其它 OpenSpec 文件不变；3094 个非 OpenSpec 跟踪普通文件实际字节与模式不变 |

`openspec instructions archive --change help-route-render-once --json` rc0，仅含 changeName/root，没有 context 或 operationGuidance。`instructions specs` rc0、合法 JSON，没有额外 rules；使用已接受 delta，不把通用模板或 advisory 写进工件，也不改变命令/同步范围。生成 skill 的手工移动建议不采用：A10 明确要求原生 `openspec archive -y` 完成同步、验证及移动，本轮严格走此授权命令。

## CRITICAL

None：已核原生 4/4、最终独立验证/PM 接受与 D251 确认；`team change status` 只有本任务 A10、literal phase=`archive` 的自身阻塞。其他 P462/P465/V168/V170 均 done，没有通过改看板或修改清单消除阻塞。

## WARNING

`openspec validate --all` 保留 **227 条原生提示**：226 条已有需求正文超过 500 字符、一条已有 Purpose 占位。未执行全仓 strict，也不称无警告；旧正文和其它 spec 原样，本次新增需求描述为 414 字符。按 A10 既定非 strict 范围保留提示，不为通过检查修改任何既有需求或 Purpose。

## SUGGESTION

None：本轮原生输出及字节核对没有要求额外索引修改；未创建新索引或并行规格。

## Final assessment

- 归档前已接受的 V170 评估仍为 CRITICAL 0 / WARNING 0 / SUGGESTION 0；上述原生结构提示另行披露，不被这个历史评估覆盖。
- A10 的原生同步、归档、内容范围、结构/引用检查及暂存后账本扫描已完成；账本 hits0、rc0，两种 diff-check 均 rc0。
- 本轮不重复行为验收；没有把结构检查冒称 route、smoke 或全仓 strict 通过。PM 仍负责接受本报告、合并与关单，本席不代写 PM 接受结论。

## Verification evidence

所有原生执行设置 `TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。以下 rc 均为实际保存值，不使用后台作业总 rc 代替单项结果。

### 1. 根、完成状态与准入

```text
$ openspec --version
1.16.0
$ openspec list --json
root.path=<本任务 dev2 工作树>, root.source=nearest
help-route-render-once: completedTasks=4, totalTasks=4, status=complete
rc=0
$ openspec status --change help-route-render-once --json
schemaName=spec-driven; planningHome.root=<本任务 dev2 工作树>
proposal/specs/design/tasks=done; delta=本 change 的 specs/verification/spec.md
rc=0
$ openspec instructions apply --change help-route-render-once --json
progress={total:4,complete:4,remaining:0}; state=all_done
rc=0
$ openspec instructions archive --change help-route-render-once --json
changeName=help-route-render-once; root=<本任务 dev2 工作树>; no context/guidance
rc=0
$ openspec instructions specs --change help-route-render-once --json
artifactId=specs; no extra rules
rc=0
$ bash skills/teamsmith/scripts/team change status help-route-render-once
P462/P465/V168/V170 done; sole blocker: A10 · archive · wip
rc=1  # A10 自身尚无归档与报告的预期状态
```

原始 JSON 与输出在 `E/native/<label>.stdout/.stderr/.rc`；`status.artifactPaths.specs.existingOutputPaths` 只有本 change 的 verification delta。没有安装、切换 store、创建 root 或绕过其他任务阻塞。

### 2. 普通副本试运行与真实执行

准备采用 `mktemp -d -p /var/tmp a10-help-archive.XXXXXX`，依次 `cp -a openspec "$E/baseline/openspec"`、`cp -a "$E/baseline/openspec" "$E/trial/openspec"`；实际逐文件核两副本与源树 inode 不同，未用 hardlink。trial 中 list 先确认根为该独立副本、清单 4/4。

```text
$ (cd "$E/trial" && openspec archive -y help-route-render-once)
Task status: ✓ Complete
Specs to update:
  verification: update
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 1, ~ 0, - 0, → 0
Specs updated successfully.
Change 'help-route-render-once' archived as '2026-11-16-help-route-render-once'.
rc=0
$ python3 "$E/tests/audit.py" "$E/trial"
ARCHIVE: 5/5 change files including .openspec.yaml byte-identical; tasks 4/4
SPEC: old 168737 bytes preserved verbatim; append 3027 bytes; requirement 1/1 and scenarios 4/4 exactly once
AUDIT: PASS
rc=0  # 更正核对脚本目录选择后，未重跑原生 trial archive
```

第一次 trial 作业的原生 archive 确为 rc0，OpenSpec 范围核对也已完成；随后外部 audit 错把 `root == cwd` 当作真实工作树，转而在仅复制 openspec 的 trial 中读取 `.github/workflows/gates.yml`，以 FileNotFoundError 失败。外层 `python | tee` 未开 pipefail，因此该作业总 rc0 **不能**证明完整 audit 成功。原回执保存为 `E/results/trial-first-bg.log`；只把外部核对条件改为读取 native list 的真实 source root，保留同一 trial 结果重新核对，实际 `trial-audit-corrected.rc=0`。之后作业显式 `set -euo pipefail`，逐项保存 rc；没有改产品、spec 或多跑原生归档来掩盖此错误。

试运行通过后，在稳定任务分支执行同一原生命令；后台 `A10-native-archive-checks` 已收割，总 rc0，各项独立 rc 如下：

```text
$ openspec archive -y help-route-render-once
Totals: + 1, ~ 0, - 0, → 0
Specs updated successfully.
Change 'help-route-render-once' archived as '2026-11-16-help-route-render-once'.
rc=0
$ python3 "$E/tests/audit.py" "$PWD"
ARCHIVE: 5/5 change files including .openspec.yaml byte-identical; tasks 4/4
SPEC: old 168737 bytes preserved verbatim; append 3027 bytes; requirement 1/1 and scenarios 4/4 exactly once
SPEC sha256: a78edb74a4e3f826c5c5702f08d02372521c976c9848daab4a48902c2fc85412
OUTSIDE OPENSPEC: 3094 tracked regular files byte/mode-identical, including all product/tests/CI
AUDIT: PASS
rc=0
$ cmp openspec/specs/verification/spec.md "$E/trial/openspec/specs/verification/spec.md"
rc=0
$ openspec list --json
changes=[]; root=<本任务 dev2 工作树>, source=nearest
rc=0
```

原件在 `E/results/trial-archive.*`、`trial-audit-corrected.*`、`actual-archive.*`、`actual-audit.*`、`post-list.*`。基线没有 clipboard 提案目录；本轮仅证明自己基线全部其他 OpenSpec 文件未变，没有读写或验证其他席位的 clipboard 提案。

### 3. 本轮唯一结构/引用批与范围核对

```text
$ openspec validate --all
✓ spec/verification
Totals: 20 passed, 0 failed (20 items)
rc=0  # 非 strict；stderr 的 227 条提示原样保留
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14386 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
$ git diff --cached --stat  # 首次归档提交前
5 file renames (100%); openspec/specs/verification/spec.md: 26 insertions
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
```

完整原生警告与引用输出在 `E/results/validate-all.*`、`spec-refs.*`，归档五文件的 SHA/字节数在 `E/results/archived-files.sha256`。归档元数据仍 40 字节、SHA `db997d460a2d6d123d14faf903215b90f63faf4e7e2dadacfdab82c07857e113`；四个规划工件及已完成清单没有改正文。全部旧 verification 字节是最终文件的完整前缀，故 Purpose、其它 requirement/scenario 均保留；除该尾部追加与五项路径移动，没有其他 OpenSpec 变化。非 OpenSpec 文件以起点所有实际跟踪普通文件的 SHA/模式逐项比较，不仅依赖 diff 名称。

映射和选择器无改动，按任务书复用 P465 已接受的静态选择回执，不再运行整套选择自检；本轮没有执行任何帮助/route/locale/routes/51、smoke、FAST/full/meta/61b/夜间/构建/安装/性能或真实模型。

### 4. 暂存后的账本扫描与最终差异检查

完整报告暂存后执行后台作业 `A10-ledger`，已收割，总 rc0。使用主 Git 公共目录的项目名单，读取范围是自己的分支工作树；真实输出如下，用户名由工具原样隐去。原件为 `E/results/ledger-ban.*`、`diff-check.*`、`cached-diff-check.*`；两种 diff-check 的 stdout/stderr 都为空。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev2 scope=published files=2797 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
```

本节随后只补实际回执与完成状态/时间；最终再次暂存并做两种差异检查，不重跑已完成的结构、引用或行为。

## Flip evidence

本单为已验 change 的原生同步/归档，不再执行破坏/恢复。引用 `reports/V170-dev3.md` 的已接受实际证据：候选完整 route 唯一一次 10/0/SKIP0；短坏输入均产生具名 finding，唯一 subshell 调用点变异打印 finding 却错误 exit0，使观察检查 rc1，恢复后损坏输入实际 exit1、观察检查 rc0。merged `7d768f1a` 全 278 个 skills 文件名字节同一，仅补正常/坏/恢复 exit0/1/0，未重跑完整 route。

旧原件 `/var/tmp/rel47-first-order.log` 绑定 `572856a3`、SHA `9ca9986e014307573cf7577ad6572d6a2d5c59f4f6fccd81158ea7b2375d2545`，仅帮助子脚本 132 条局部成功、全轮 5139/2、rc1。该身份来自已接受 P465/V170 报告，本轮未重新运行或收存旧日志；未改组使用既定同一性/消费差异复用，不是 A10 新执行。P465 的 `E=/var/tmp/p465-dev-static.hPAcKA` 与 V170 的 `E=/var/tmp/v170-help.6Pw65D` 原件按任务书保持原位，未清理或改写，不承诺整套耗时收益。

## Decisions and deviations

授权范围无偏离。第一次外部 trial audit 的目录选择及外层 rc 处理错误已如上披露，修正仅在自己的私有脚本；两次原生 trial/actual 都只按 A10 命令执行一次。未手工移动、跳同步/验证、改 Purpose、修改产品/tests/CI、修改真实 reminder/standby/团队配置或看板；未 push/merge/tag/npm。后台工具自身日志按现有工具路由保存，未据此声称运行时目录零写入。

## Suggested next steps

交 PM 审阅本分支归档提交 `e054e43e`、本报告及真实回执，PM 接受后再合并关单。本席不写接受结论、不修改看板、不触碰其他提案；提交留在本地任务分支，不 push/merge/tag/npm。原始本轮日志和快照保留于 E，其他席位原件未动。
