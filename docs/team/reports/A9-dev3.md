# A9 · 配置测试去重规格同步与归档

**原生同步与归档已完成。** 两条已接受需求、五个场景各追加一次；既有 verification 正文全部 165040 字节（含 Purpose）保持原样。五个规划文件（含 `.openspec.yaml`）原样移入 `openspec/changes/archive/2026-11-16-config-check-execution-dedup/`，清单仍为 7/7。原生归档提交为 `fd736406`；本报告与最终文档检查另行提交，不合并、不推送。

agent: dev3   status: DELIVERED（A9 归档及全部授权短检查通过）   time: 2026-11-16T10:46:54Z
branch: `task/A9-archive-config-dedup`   PR/MR: -（仅本地）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/archive/2026-11-16-config-check-execution-dedup/` | OpenSpec 1.16.0 原生命令移动五个文件，全部与归档前逐字节相同 |
| `openspec/specs/verification/spec.md` | 原正文后追加 3697 字节，恰为已接受的两 requirement / 五 scenario，无 delta 操作标题 |
| `docs/team/reports/A9-dev3.md` | 本轮归档、短检查及原证据边界 |
| `/var/tmp/a9-dev3-archive.BJh6Ks/` | 原生输入 JSON、两次归档日志/rc、比较脚本/收据和逐命令短检查日志/rc；仅本次私有证据，不加入仓库 |

## 前置与原生上下文

- 起点 `95fd9b9ff`，包含 brief 指定的接受提交 `6f948310`；实现者 dev，本席位未实现该 change。已读 change 五份文件、正式 verification 全文、V167 完整 assessment、P461 的 merged 执行记录、PM 接受记录 `docs/team/reviews/V167.md` 及 D247/D241。
- `team change status config-check-execution-dedup` 实际 rc=1，仅 A9 / literal `phase: archive` / wip 一个 blocker；P460/V166/P461/V167 均 done。没有把自身未完成误当成额外阻塞，原输出在 `team-change-status.log`。
- 原生 `openspec list --json` 为 7/7、complete；`status --change ... --json` 为 spec-driven、四 artifact 全 done，`planningHome.root` 和 `root.path` 都是本席位稳定工作树，delta 来源精确为 `artifactPaths.specs.existingOutputPaths` 的 verification 文件。
- 已读本机生成的 archive/sync skills 和仓库 OpenSpec 指引；本工作树没有机器生成 `.pi`，仅只读主检出的对应 skill 文件，未初始化新 root。原生 archive instructions 有效但没有 context/operationGuidance；specs instructions 有效且没有 rules，原件为 `instructions-archive.json`、`instructions-specs.json`。同步及移动按 brief 明确授权使用原生 archive，不采用 skill 的手工合并/移动示例。
- D247 明确依 D241 作出本次小步、可逆、已覆盖批准方案的 PM-proxy 确认；候选与 merged 的同一 verify 证据均已接受。原验证的生成面 SKIP、51 原一条可见 SKIP、首次观察脚本 FAIL 原件和未实测全量耗时均保留，不把 PM 接受写成 PM 执行。

## OpenSpec assessment

本表仅评估 A9 的同步/归档完整性，不重新执行或冒充 P461 的独立行为验证。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 5/5 文件；7/7 清单；2 requirement / 5 scenario | 原生输入 7/7；日期归档含隐藏元数据；`worktree-comparison.log` 逐字节核验 |
| Correctness | 本轮归档/结构检查通过 | 私有副本先原生试运行 rc=0，再稳定工作树同命令 rc=0；结果一致；非 strict 全项目 20/0；引用未声明 0；选择登记 13/0/SKIP1 |
| Coherence | 授权内原生移动和单纯追加 | 所有原 OpenSpec 文件比对，除指定移动与追加外零变化；无产品/测试/CI/配置写入，无必要索引改动 |

## CRITICAL

None — 已核验五文件完整移动、原规格字节不变、追加恰一次及 7/7；未发现授权外写入。

## WARNING

None（本轮归档未新增规格/设计偏离）。全项目非 strict validate 仍输出既有长需求描述 WARNING；原正文未改，不扩大写集修订，也不声称 strict 全绿。选择器的机器生成面 SKIP 及原 51 的跳过见下文，均不计作通过。

## SUGGESTION

None。

## Final assessment

- Counts: CRITICAL 0 · WARNING 0 · SUGGESTION 0（A9 归档范围；全项目 validate 的既有 WARNING 不等于零）。
- Readiness: 原生同步/归档、三项短检查及暂存后文档检查均通过，具名 SKIP 与既有 WARNING 保留。提交仅供 PM 接受并本地合并，本席位不设置 BOARD/done 或关闭任务。
- Unverified applicable checks and reasons: 本次选择登记未验证 `.pi/skills` 存在性，因为机器生成目录不在本工作树，明确 SKIP1；V167 所复用原 51 日志的一条可见 SKIP 仍保持其原来源限制，未展开身份、未补写 PASS。
- 不重跑任何 smoke 段、全量/FAST、61b/meta/夜间、完整 51/help/config、安装或性能。两 requirement / 五 scenario 的行为结论沿用已接受的 V167 候选与 merged 证据，不称本席位重验。正常完整运行的改后时间仍未实测，不把局部执行量减少当成已测秒数。

## Verification evidence

证据根 `E=/var/tmp/a9-dev3-archive.BJh6Ks`。本轮统一环境为：

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec --version
# 1.16.0，rc=0
openspec list --json
# root.source=nearest，root.path=<本席位稳定工作树>；complete，completedTasks=7，totalTasks=7，rc=0
openspec status --change config-check-execution-dedup --json
# spec-driven；proposal/specs/design/tasks 全 done；isComplete=true，rc=0
openspec instructions archive --change config-check-execution-dedup --json
# changeName/root；无 context/operationGuidance，rc=0
openspec instructions specs --change config-check-execution-dedup --json
# specs artifact JSON 有效；无 rules，rc=0
```

上述真实输出保存于 `native-inputs.log` 和相应 JSON，specs instructions 只获取一次并复用。

### 私有试运行 → 稳定工作树

先复制本工作树的 openspec 到 `E/trial/project/openspec`，原生 list 确认 trial root 和 7/7，执行：

```sh
(cd /var/tmp/a9-dev3-archive.BJh6Ks/trial/project && openspec archive -y config-check-execution-dedup)
# rc=0
# 仅在试运行完整比对通过后，在稳定工作树执行同一原生命令：
openspec archive -y config-check-execution-dedup
# rc=0
```

两次原生输出相同，完整原件为 `trial-archive.log` / `worktree-archive.log` 及各自 `.rc`：

```text
Task status: ✓ Complete
Specs to update:
  verification: update
Applying changes to openspec/specs/verification/spec.md:
  + 2 added
Totals: + 2, ~ 0, - 0, → 0
Specs updated successfully.
Change 'config-check-execution-dedup' archived as '2026-11-16-config-check-execution-dedup'.
```

一次性只读比较脚本 `E/compare-archive.py` 分别作用于 trial 与稳定工作树：

```text
Pre-existing verification spec: all 165040 bytes preserved, including Purpose
Appended specification bytes: 3697
Exactly 2 accepted requirements / 5 scenarios appended once; no delta operation heading
All 5 change files moved byte-for-byte, including .openspec.yaml; remaining OpenSpec files unchanged
Archived checklist: 7/7 complete
Stable worktree spec equals native trial output byte-for-byte
Archive comparison: PASS
```

两次比较 rc=0，原件为 `trial-comparison.log`、`worktree-comparison.log`；spec SHA-256=`a3b2019a7b09697e87a61a680ba6bc14892bee5d88d817ad25f4d23db97a69a0`，五个归档文件各自 SHA 也在原件中。原生归档后 `list --json` 为 changes 空、root 仍指向稳定工作树，见 `post-archive-list.json`。没有遗漏隐藏文件、手写移动、跳过规格或跳过原生验证。

### 三项短检查（每项一次）

后台 `a9-archive-short` 已收取，exit=0，用时 23.9s 是此短批参考时间，不是全量测试耗时。实际串行 runner 为 `E/short-checks.sh`；起止 SHA 都是 `fd736406a64030a0a402d54f2f07bdcd4a074969`，起止工作树均干净。

```text
$ openspec validate --all
  [WARNING] Requirement text is very long (>500 characters) ...
Totals: 20 passed, 0 failed (20 items)
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14360 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
== 选段自检 ==  ok 13  bad 0  SKIP 1
rc=0
```

完整原件分别为 `validate-all.log/.rc`、`spec-refs.log/.rc`、`section-select.log/.rc`。这是全项目非 strict 校验，不替换此前本 change 的独立 strict 证据，不声称全项目 strict 通过。

## Flip evidence

N/A — A9 仅同步归档，不修产品缺陷，也未重跑 P461 的坏恢复实验；已接受的原实验来源保持 `docs/team/reports/V167-verify.md` 和 `docs/team/reviews/P461.md` 的完整 merged SHA 绑定。

## Decisions and deviations

- 无范围偏离；产品、测试、CI、超时、真实团队配置/待命状态均未改动，0.4.7 包与 tag 未动；没有合并、推送、发布或创建新 tag。
- 比较原件和 trial 使用本次唯一 `/var/tmp` 私有目录；不触碰 P461/V167 或其他席位原件。本次 trial 与 before 副本已按精确路径删除，留下 188K 收据/脚本供 PM 接受后回收；重新比较可从基线 Git 取得原文，不把已删除副本说成仍在。

## Suggested next steps

PM 检查 `fd736406` 与本报告、命令收据及授权写集后接受/本地合并，再关闭 A9；无需为此次归档重跑已经接受的行为验证。

## 暂存后文档检查收据

本报告的上述实质正文暂存后，在自己的任务工作树执行 brief 指定检查；其后仅补入本节真实收据并更新完成状态。完整原件为 `E/ledger-ban.log/.rc`、`diff-check.log/.rc`、`cached-diff-check.log/.rc`。

```sh
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3 scope=published files=2766 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
# 无输出，rc=0
$ git diff --cached --check
# 无输出，rc=0
```

Verdict: PASS（仅 A9 明授的原生同步/归档及结构、引用、选择登记、文档检查范围；含上述具名未验证边界）。
