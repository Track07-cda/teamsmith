# V19 · task-model-routing S1 独立复验

## 结论：FAIL，仅针对冻结 S1

任务书要求的 11 条切片验收命令在有效轮全部 rc=0；受检树前后 HEAD、status 和产品/测试内容指纹一致。然而，审查后自行设计的两个反例均在未改源码的候选上复现真实缺陷，故不接受 S1。该结论是 worker 的独立报告，不是 PM 的最终 review，也不代表完整 change 的验证结果。未修改候选、未修缺陷、未合并、未推送、未标记 P228 done。

1. **阻断 S1：worker 自定义模板可以绕过记录的 provider/model/SID。** 同任务恢复返回成功并重新发布完整 assignment，但实际 recording-agent argv 使用另一模型、另一 SID。preview 也返回成功，没有身份冲突诊断。
2. **阻断 S1 读者验收：monitor 接受 Bash 已判为损坏的 assignment。** 把完整记录的 `launch_nonce` 改成含空格的非法值，Bash 返回 `malformed SID/nonce`，monitor 却继续展示该 SID 的会话事件。

这两项不是坏源码臂的预期红，而是原始稳定候选的缺陷。修正 fixture/template/record 后的绿控制只验证反例有效，**不是产品已修好**。

## 受检输入、隔离与审查范围

- 任务：V19，agent dev3，phase verify；未参加该 change 的提案或实现。
- 独立真实 clone：`../pm-skills-ledger/team/reviews/V19/checkout`，其 `.git` 为目录，不是 worktree 指针。
- 受检完整 SHA：`16842c9ddf6f83db0e43f4fdbcfb2a4cc5170c74`；前置及收尾 status 均干净。
- 对作者受检 `017fbf9` 的差异只有 `docs/team/reports/P228-dev.md`。`git diff --exit-code 017fbf9 16842c9 -- skills` 返回 0，产品及测试逐字一致。
- 实现差异以作者记录的私有输入 `da89f842` 到冻结 tip 审查。独立保存 `reviewed-source.diff`、`preflight.txt`；不把作者报告里的运行结果当作我的验收。
- 阅读接受的 proposal/design/tasks、七份 delta 和 canonical specs、D104–D106、P228 brief/报告及 V19 brief；收到续跑指令后又读主检出 thread 最新条目、git status/log。没有执行旧 E12/P158 指令。
- 审查的产品路径：`cmd-agents.sh`、`cmd-bootstrap.sh`、`cmd-config.sh`、`cmd-death.sh`、`cmd-docs.sh`、`cmd-project.sh`、`cmd-review.sh`、`cmd-status.sh`、`cmd-watch.sh`、`common.sh`、`monitor.mjs`。审查改动过的 config-cli/routes/death-cause 测试差异，以及新增 routing/fixture/flip 入口。
- `cmd-review.sh` 改动限于 close 的共享锁/最终身份检查/清理 helper，没有放宽 review 或 merge 权限；dispatch 与 close/teardown 均走 seat→admission 顺序。非模型既有测试差异主要是私有 HOME、完整记录和显式类别输入；模型旧断言被新退休/策略/assignment 断言替代。未发现用 skip 删除无关断言；但本轮不声称执行了未选中的 smoke 场景。
- 被测 CLI 仅在测试自建 fixture repo/HOME/私有 tmux socket 中运行。清除继承的 `TEAM_*`、`PI_*`、`TMUX*` 和真实团队 shim，未调用候选 CLI 管理真实团队。自设真实 argv 反例用绝对路径 recording-agent，既未启动 Pi/provider，也未读取真实历史或认证文件。
- 证据根，下文简称 **E**：`../pm-skills-ledger/team/reports/V19-dev3/`。日志、脚本、变异副本和 fixture 副本在仓外；短 `/tmp/teamsmith-*` 根只用于私有测试运行，独立反例结束后复制入 E 并回收其私有 tmux server/临时根。

## 有效轮命令与原始结果

由 `E/run-gates.sh` 顺序运行，每条 `timeout 1800`，显式独立 HOME；完整 argv 保存在对应 `.command`，原始输出在 `.log`，退出码在 `.rc`。日志实际时间段为 2026-10-09 11:52:16–12:02:58 UTC。先检查 `/tmp`：15G 容量、12G 可用；没有容量拒绝或红被负载跳过。

命令均从上述 clone 执行。Bun/OpenSpec 的绝对路径在换到私有 HOME **之前**解析，未安装工具。

| 实际命令 | rc | 原始收尾/证据 E 下路径 |
|---|---:|---|
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict`（原 HOME 的绝对路径） | 0 | `Totals: 14 passed, 0 failed (14 items)`；`openspec.*` |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 0 | judged 104 references / 49 distinct；retired 0、undeclared 0；`spec-refs.*` |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 0 | 169 通过、0 失败、0 SKIP；`config-cli.*` |
| `bash skills/teamsmith/tests/routes.sh` | 0 | 207 通过、0 失败、0 SKIP；`routes.*` |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 0 | 87 通过、0 失败、0 SKIP；`death-pure.*` |
| `bash skills/teamsmith/tests/death-cause.sh --live` | 0 | 7 通过、0 失败、0 SKIP；`death-live.*` |
| `bash skills/teamsmith/tests/death-cause.sh --flip` | 0 | 4 通过、0 失败、0 SKIP；`death-flip.*` |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 0 | `RESULT pass=245 fail=0`；`routing.*`；外加 `TEAM_ROUTING_EVIDENCE=E/routing-fixtures` 保存自身 fixture |
| `bash skills/teamsmith/tests/task-model-routing.sh --select flip` | 0 | `RESULT pass=59 fail=0`；`flips.*`；外加 `TEAM_ROUTING_EVIDENCE=E/flip-fixtures` |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | 0 | published files=1310、hits=0、names=ok；`ledger-ban.*`；名单未查看/回显 |
| `git diff --check` | 0 | 无输出；`diff-check.*` |

有效轮 `gate-manifest.txt` 与 `gate-after.txt` 逐字一致：

```text
HEAD=16842c9ddf6f83db0e43f4fdbcfb2a4cc5170c74
4a478294136a3e00ea3b80d40165bc4d272e8339cd83adaa993226cfcca9365d  -
```

第二行是所有 tracked `skills` 文件逐一 SHA-256 后再聚合的指纹，中间没有 status 行，即干净。两个 manifest 自身 SHA-256 都为 `aa02d85b26727bb952263505a519c6308e22e5e6e46f6b8896838fc5ad3da408`。独立反例完成后再次检查 HEAD/status/同一源指纹仍一致；保存于 `final-source.txt`。

### 无效/修正轮的真实事实

- 第一轮把长证据路径当 TMPDIR，私有 tmux socket 路径过长，并且前置 runner 裸调用 `openspec` 报 `command not found`。该轮被终止、job 已收割；**整轮不计通过**。原日志及 runner 保存于 `E/preliminary-invalid/`，没有删除红或拿其中部分绿补验收。随后使用短标准测试临时根、提前解析工具绝对路径，完整重跑以上 11 条。
- 第一次自设反例的绿控制误写了不存在的 `{model_name}` worker 占位符，退出 3；不是候选新缺陷。该日志保留为 `independent-probes-initial-invalid.log/.rc`，fixture 为 `own-probes/teamsmith-v19-own.85yfvN/`。改为引擎实际支持的 `{model}` 后从全新私有 fixture 重跑，得到下节完整红/绿。没有改候选模板/源码。

## 自行设计的反例：原始候选红，控制绿

复现入口是 `E/independent-probes.sh`，实际运行：

```bash
bash "$EVIDENCE/independent-probes.sh" "$CANDIDATE" "$EVIDENCE"
```

脚本使用 `set -euo pipefail`、45 秒 CLI timeout、真实私有 tmux 以及真实进程参数记录；自身 rc=0 表示**两处缺陷均成功复现且绿控制成立**，不是产品 PASS。精确日志为 `independent-probes.log/.rc`，有效 fixture 副本为 `own-probes/teamsmith-v19-own.KcKkYM/`。

### F1：自定义 worker 模板破坏已提交恢复身份

关联：dispatch 的 `Same-task recovery preserves the full committed launch identity` / `Launch assignments are complete transactions...`，agent-adapters 的 `Launch parameter ownership ends at the Pi boundary`；S1 3.1、3.2、3.4、5.2–5.3。

位置：`skills/teamsmith/scripts/lib/common.sh:4874` 的 `team_agent_check_launch` 只检查占位符/提示词等形状；`:4995` 的 `team_agent_launch_cmd` 直接展开模板。`cmd-agents.sh:1112` 仅对 `TEAM_EXTRA_PI_ARGS` 做身份 guard，不能阻止模板自身固定另一组参数。

复现（全部在 owned fixture）：

1. builtin 路径真实派发 O1，获得完整记录：`model=vendor/expected:high`，SID 为 `v19-owned-dev-1791557962-1772073-28071-1117`。
2. 不改任务/类别/模型策略/assignment，改 fixture 的 frozen seam 模板为：
   `recording-pi --provider other --model wrong:low --session-id other-history {prompt}`。
3. 同任务 `dispatch ... --print` 返回 0；真实 `dispatch ...` 也返回 0。实际进程 argv 前六项是：

```text
['--provider', 'other', '--model', 'wrong:low', '--session-id', 'other-history']
```

重新提交的 assignment 仍声称 `vendor/expected:high` 与原 SID。凭证/nonce证明的是该进程启动了，不能证明其 argv 与记录一致。后续容量、窗口和来源显示依赖的就是这个虚假的 assignment。

**绿控制**：仅把 fixture 自定义模板改成
`recording-pi --provider {provider} --model {model} --session-id {session_id} {prompt}`，相同同任务派发返回 0；捕获参数为 `vendor`、`expected:high`、记录 SID，三者一致。这个对照证明 recording-agent 及真实 launcher 可正常接收选择值，红不是 stub 拒绝、PATH 或 socket 问题。

请求作者在派发/preview 的共同身份检查中，对不能可靠使用所选模型/SID的 worker 自定义模板诚实拒绝；不能仅靠新 nonce 把不一致的 argv 认证成有效身份。需要补 hardcoded/missing identity template 反例及合法占位符控制。此报告不代实施。

### F2：monitor 与 Bash 对损坏记录的判断分叉

关联：watchdog 的 `SID-linked evidence follows the committed launch rather than a neighboring session`，memory-and-deps 的 `Machine reads separate future policy from committed assignments`；S1 1.2、3.2、4.1–4.2。

位置：`common.sh:1402` 的 `team_assignment_load` 校验 SID/nonce、规范路径、started、模型形状；`monitor.mjs:239–264` 的 `committedSession` 复制了一部分规则，却不检查 nonce 字符集/started 形状，也没有同等的规范路径/模型形状检查。

复现：保留完整合法记录，在私有 HOME 创建该 SID 的一条 assistant 事件 `V19_OWNED_EXPECTED_EVENT`；然后只把 fixture assignment 的 `launch_nonce` 改成 `malformed nonce`。

```text
Bash: rc=1 diagnostic=malformed SID/nonce
monitor: malformed-monitor.json 仍包含 V19_OWNED_EXPECTED_EVENT
```

读取路径实际使用完整 argv：
`node "$CANDIDATE/skills/teamsmith/scripts/monitor.mjs" --root "$FIXTURE_ROOT" --state-dir "$FIXTURE_STATE" --only dev --json`。

**绿控制**：还原此前完整合法记录，`valid-monitor.json` 显示相同 owned SID 的正确事件。两个 JSON、原始 record、shell 诊断在有效 fixture 副本中。反例没有读取 B/base 或任何真实历史，直接证明 monitor 的“完整 committed 身份”判断比 Bash 宽。

请求作者统一这两条读侧的数据校验契约，并覆盖坏 nonce、非规范路径、坏 timestamp/model 等边界；非法身份必须不可用，不能继续输出实际会话证据。此报告不代修源码。

## S1 场景 → 独立执行的真实断言

以下具名断言均来自**我的** `routing.log`，完整 245 条另外摘录于 `baseline-assertions.txt`。表中“绿”是已有断言绿，不覆盖 F1/F2 缺口。R 表示上述完整 routing 命令/rc=0；C、T、D 分别表示 config-cli、routes、death-cause 表内命令/rc=0。

| S1 delta 场景 | 实际断言/证据 | 判定 |
|---|---|---|
| Legacy and mixed policy refuse but repair commands remain reachable | R `retired-key/command/register-option/no-write`；C `models/seats` | 已有断言绿 |
| Category map has one domain rule | R `policy-invalid:*`, `policy-minimum-analysis-verify`, `policy-custom-category` | 绿 |
| Old routes cannot recreate seat policy | R `retired-*`；C `退休 ... → 5`/register `--model → 2` | 绿 |
| PM is independent from task policy | R `pm-independent-model`；C 独立 PM 不改 map | 绿 |
| One category write changes only its token | R `map-upsert`, `map-invalid`；C 一对增删/审计/assignment 字节保持 | 绿 |
| Explicit upgrade preserves unrelated bytes and has no partial result | R `upgrade-commit`, `upgrade-retired-removed`, `upgrade-no-final-newline-preserved` | 绿 |
| Stale fingerprint and failure injection protect the whole file | R `map-cas-first/loser`, `simultaneous-map-cas`, `upgrade-whole-file-fault:{alloc,copy,render,syntax,rename,stale-cas,late-cas}` | 绿 |
| Ambiguous source is refused with a usable correction | R `upgrade-refuse:*` / `upgrade-no-write:*`（export/dynamic/compound/conditional/duplicate/multiline） | 绿 |
| Quoting and concurrent readers do not execute or observe partial policy | R `writer-payload-does-not-expand`, `writer-literal-roundtrip`, `upgrade-readers-wholly-old-before-rename-new-after`；C inject/writer | 绿 |
| Policy edit does not rewrite current provenance | R `machine-json`, `recovery-model/sid`；C all-policy-write preserves assignment bytes | 已有断言绿；F1缺口 |
| Removed future category remains a complete actual assignment | R `machine-json`, `deleted-routine-recovery`, `actual-resume-after-policy-removal` | 绿 |
| Empty and legacy records remain valid JSON without fictitious defaults | R `machine-json`；C `models/json`；自设坏nonce控制 | 已有断言绿；F2失败 |
| Known models are only project-owned model data | R `machine-json`；C known 包含策略及记录完整ID | 绿 |
| Category faults refuse without launching | R `category-explicit-phase-independent:*`, `category-fault-record/board-pure:*`, `new-unmapped-category-override-refused` | 绿 |
| Categories are project-defined and not seat-defined | R `policy-custom-category`, `phase-does-not-infer-category:{explore,propose,verify}` | 绿 |
| An override retains category and original provenance | R `first-recorded-launch`, `first-complete-record`, `argv-full-suffix`, `recovery-model/sid` | 已有断言绿；F1失败 |
| Generated tasks require a mapped category | R `generated-mapped-category`, `generated-category-header`, `generation-refused/no-file:*` | 绿 |
| Override and fresh survive every recovery entry | R `resume-stored-identity/sid`, `actual-resume-argv-exact`, `actual-resume-fresh-argv-exact`；自设真实模板argv | builtin已有断言绿；F1失败 |
| Removing a future category preserves a trusted same-task assignment | R `deleted-routine-recovery`, `actual-same-model-fresh-after-policy-removal` | 绿 |
| Legal category deletion is not a waiver for invalid overall config or changed identity | R `untrusted-recovery-refused/record-pure/no-launch:*`, `new-unmapped-override-refused`；policy非法矩阵 | 所选断言绿；不扩大至未选全套 |
| A model or suffix change needs explicit fresh | R `suffix-change-requires-fresh`, `fresh-model` | 绿 |
| Same-model fresh is unique even within a second | R `actual-fresh-SID-different`, `forced-sid-collision-regenerated/four-candidates` | 绿 |
| Untrusted identity refuses rather than silently reselecting | R `untrusted-recovery-*:{missing,malformed,task_file,category,worktree,branch}` | Bash恢复绿；F2读侧失败 |
| Dry recovery is genuinely read-only and fails honestly | R `preview-no-assignment/board/prompt/session`、category纯净、recovery断言 | 已有断言绿；F1 preview失败 |
| Proof and publication failures cannot create half an assignment | R `failed-launch-*`, `stale-launch-proof-*`, `failed-publication-*` | 绿 |
| Crash boundaries are distinguishable | R `interrupted-before-commit-*`, `interrupted-proven-*`, `interrupted-after-commit-*` | 绿 |
| Overlapping dispatch cannot overwrite a newer decision | R `same-seat-generation-race`, `same-seat-loser-no-second-launch`, `final-config/brief-snapshot-*`, close/teardown等待及no-resurrection | 绿 |
| Preview and refusal leave all observable state unchanged | R `preview-*`, `category-fault-*`, `cap-refusal-*`；T printed-route/refusal families | 所选断言绿 |
| Extra identity arguments cannot contradict records | R `boundary-reject:*`, `boundary-harmless`；F1硬编码template | extras已有断言绿；template失败 |
| Board failure does not erase a committed launch | R `board-failure-after-commit-not-rollback`, `board-failure-complete-record/new-generation/pending-matches` | 绿 |
| The limit is reached / Zero means unlimited | R `positive-full-model-cap`, `unlimited-does-not-demand-peer-model` | 绿 |
| Actual model, wildcard group and replacement determine the count | R `wildcard-bucket-counts-actual-peer`, `exact-suffix-bucket-independent`, `zero-wildcard-does-not-erase-positive-cap` | 已有断言绿；F1可污染真实身份 |
| Two seats cannot claim the same final slot | R `cross-seat-serialized-admission`, `cross-seat-only-one-worker-window` | 绿 |
| A live unknown-model peer blocks limited admission | R `unknown-live-peer-*`（preview/force/real拒绝、诊断、零启动）；`interrupted-peer-*` | 绿 |
| Unknown peer identity does not make dead workers or PM occupy slots | R `pm-does-not-consume-worker-bucket`；limits控制与 stopped/dead fixture | 所选断言绿 |
| Rendered arguments and records describe the same selection | R `argv-full-suffix`, `actual-resume-*-argv-exact`；自设真实argv | F1失败 |
| Boundary guidance cannot promise reasoning conversion | R boundary入口；源码未加入历史改写/推理转换 | S1代码边界检查；S3文案未验 |
| Same-model continue and explicit fresh use the existing path | R `pm-known-continues`, `pm-suffix-explicit-fresh` | 所选PM控制绿 |
| Changed or unknown identity cannot automatically continue | R `pm-unknown-needs-fresh`, `pm-suffix-change-needs-fresh`, `pm-changed-resume-selector-needs-fresh`, `pm-resume-args-cannot-shadow-model` | 绿 |
| Running and starting PM remain protected | R `pm-running-not-respawned`, `pm-starting-not-respawned` | 绿 |
| Failed PM publication is not liveness proof | R `pm-publication-failure-stops-uncommitted` | 绿 |
| Neighboring and base sessions cannot contaminate evidence | R `reader-session/cause/monitor-A`, `reader-missing-A-no-B`, `monitor-missing-A-unavailable` | SID选择已有断言绿；F2身份校验失败 |
| Live size is not the launch snapshot | R `reader-fresh-zero-bytes`, `reader-later-A-growth`, `reader-growth-still-A` | 绿 |
| Missing metadata and stopped workers stay honest | R `reader-no-record-no-newest-fallback`, `reader-no-record-monitor-unavailable`；自设坏nonce | 缺失已有断言绿；F2损坏失败 |

### Tasks 1.1–5.3 与继承场景边界

| Tasks | 此轮证据及审查 | 限制 |
|---|---|---|
| 1.1–1.2 | policy/machine + C shape/json/models/groups/seats；私有输入及retired schema差异 | 未单跑 C choices/all-schema，也未验 S2 UI；F2阻断读侧 |
| 2.1–2.3 | config/upgrade + C writer/inject/cas/audit/validate，完整文件故障注入及 audit-unwritable 如实已提交结果 | 写入器只在fixture运行，无真实升级 |
| 3.1–3.5 | dispatch/resume/transaction/limits/preview + T全入口/compound修法；锁/nonce/CAS/close授权静态审查与具名race断言 | F1阻断真实身份承诺；全套非模型smoke尚未执行 |
| 4.1–4.2 | sid-readers + D pure/live/flip；记录 A/B/base、fresh0、增长、缺失读侧 | F2阻断完整身份判据；未验真实Pi日志或UI帧 |
| 5.1–5.3 | pm/boundary、原PM resolver/guard/start/watch/metadata差异审查，fallback及publication破坏臂 | 部分PM/容量/race是owned函数故障桩控制；不是完整真实PM/provider E2E，F1模板边界仍缺 |

继承的 writer/quote/CAS/audit/range/group/JSON/model-shape/registration/route-family 断言在 C/T 中实际执行；death 的分类优先级、prose不猜、clean exit、current launch、去重与第二次死亡在 D 中执行。继承的其余 smoke disk/digest/thread、capacity/PID/extension/frozen-adapter/PM-watch 全面回归，以及七份 delta 中由 S2/S3 负责的 UI/初始化/指南场景，**不在本轮完整执行承诺中**。遵照 brief，没有运行尚依赖 S2/S3 的全仓 smoke，不把静态审查、单个 helper 控制或选段绿等同全套 E2E。

## 11 个破坏臂：预期红与恢复控制

仅 E 下保留的 owned scratch 产品副本被变异；clone 原源码没改。`flips.log` 记录每臂 rc、具名 FAIL、还原 hash；每份 `mutation-<name>.json` 记录唯一匹配和 before/after SHA。原始嵌套日志及恢复树在 `E/flip-fixtures/teamsmith-task-model-routing.bmyksZ/`，其中嵌入的旧 `/tmp/...` 路径可按同一相对文件位置读取保存副本。

| scratch破坏臂 | 红臂 rc / 对应具名FAIL | 恢复 |
|---|---|---|
| unmapped-override | 1 / `new-unmapped-category-override-refused` | 原文件hash一致 |
| fingerprint | 1 / `map-cas-first`, `simultaneous-map-cas` | 一致 |
| expanding-quote | 1 / `writer-payload-does-not-expand`, `writer-literal-roundtrip` | 一致 |
| recovery-drift | 1 / `recovery-model`, `recovery-sid` 等 | 一致 |
| partial-publication | 1 / `failed-launch-old-record-bytes` 等transaction断言 | 一致 |
| unknown-as-zero | 1 / `unknown-live-peer-fail-closed-even-force` 等 | 一致 |
| latest-shell | 1 / `reader-session-A`, `reader-cause-A` 等 | 一致 |
| latest-monitor | 1 / `monitor-missing-A-unavailable` | 一致 |
| pm-fallback | 1 / `pm-independent-model`, `pm-known-continues` | 一致 |
| pm-publication | 1 / `pm-publication-failure-stops-uncommitted` | 一致 |
| extra-shadow | 1 / `boundary-reject:*` | 一致 |

全部回到原字节后的对照 `CONTROL restored rc=0`、`RESULT pass=245 fail=0`；11臂控制入口 `RESULT pass=59 fail=0`。这些是防护能抓住**已设计变异**的证据，不消除原始候选上的 F1/F2。

## 交付与未测事项

- 所有自身后台 job 已收割：`V19-s1-gates`（终止的无效轮）、`V19-s1-acceptance`（有效轮）、`V19-independent-probes`（错误占位符的无效控制）、`V19-independent-probes-corrected`（有效反例）。
- 只提交本报告；源码、change/canonical specs、tasks勾选、PM治理账本及候选clone不改。报告独立隐私检查 `ledger-ban --root <本worktree> --names-file <主检出名单>` 为 rc=0、hits=0、names=ok，日志 `report-ledger-ban.log/.rc`。报告提交后核对自己任务分支/干净状态，再通过稳定主检出 CLI 明确通知 `pm`。
- 未测/未授权：S2 panel交互/构建/真实UI帧，S3 init/template/guidance/共享采纳，完整change全量smoke，真实Pi/provider质量与跨模型会话兼容，共享skill/main更新、真实项目升级/fresh、部署/远端写入、归档。
- 请求 PM 独立复现 F1/F2 后交回 apply 作者，修正实现及防护，再冻结新 tip、另行复验；本报告不对下一阶段调度或采纳作授权。
