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

---

## 第二轮独立修订：a21a0a3 的 S1 仍为 FAIL

以上首轮正文及 FAIL 原样保留。本轮只评审返修核心 S1，不是整个 change 或 PM 正式 review。新受检完整 SHA：`a21a0a32480557b847d3b0ea43ad88a0847823df`，独立真实 clone：`../pm-skills-ledger/team/reviews/V19/repair-a21a0a3/checkout`。与作者受检 `fbc42f4b315dc5b6253c1e91274151450dedbd41` 的 `skills` 差异为空，最终差异仅作者报告。下文 **E2** 指 `../pm-skills-ledger/team/reports/V19-dev3/repair-a21a0a3/`；证据均由我独立执行，不采用作者 857/0、72/0 代替验收。

**结论原因**：首轮 F1/F2 在新输入的防护及合法控制均成立，但我补的 glob 反例仍使真实 argv 带矛盾模型选择器；preview 和真实启动都成功并提交 assignment。因此新输入也不接受。这是稳定未修改源码上的缺陷，不是源码 mutant 的预期红。

**BLOCKED:** 修复属于 P228 核心作者的产品/测试写集合，交回 PM；我没有修改候选、产品、规格、治理账本或真实配置，没有启动 Pi/provider、部署、合并或推送。完整切片验收及源稳定性收尾另附在后续小节；本节先提交已经完成的代码审查与独立反例证据。

### 输入检查和修复差异审查

- 先读 git status/log、主检出最新 thread/brief、OWNERSHIP、D104–D109；初始报告树干净。候选 `.git` 是目录，HEAD/status 正确，`preflight.txt` 保存路径、容量及作者树对照。
- 独立 diff：首轮 `16842c9` → 本轮 `a21a0a3`，保存在 `E2/repair-source.diff`。新增窄 argv lexer/identity option guard、worker模板身份绑定/worker继续方式拒绝、PM fresh/continued/opaque 分类与 metadata 校验、monitor 调用同一个 bounded DATA parser；`model-routing-boundary.sh` 增加接缝/坏记录/extra 矩阵与两臂 flips。没有发现移除原非模型断言、借 skip 保绿，或扩大 close/review/merge 权限。
- 重读接受的 proposal/design/tasks、相关 delta、canonical 受影响要求及 P228/V19 输入。身份保证止于 Teamsmith 的启动 argv，不要求 Pi 内部模型判定、推理桥接或通用 Bash parser。`sid_bytes` 空字符串是设计允许的未知快照，不能判为损坏。
- monitor 从已打开的 bounded snapshot 调用 Bash shared parser，未再次打开 assignment、未 source/eval 数据或项目配置，不以 config 的 future policy 代替 committed identity；但同步子进程引入额外延迟，观察值另列，不声称通过性能门禁。

### 旧红 → 新防护及相邻绿控制

实际运行旧控制：`bash E/independent-probes.sh <旧checkout> E2/old-control`，rc=0；`E2/old-control.sha` 为首轮 `16842c9ddf6f83db0e43f4fdbcfb2a4cc5170c74`，初始 status 空。此旧脚本的 rc=0 表示两旧缺陷仍成功复现，不表示产品通过。`old-control.log` 再次捕获固定错误 provider/model/SID，及 shell 拒绝坏 nonce 而旧 monitor 展示事件；合法模板/记录控制绿。

新脚本不是原封不动期望旧漏洞存在：`bash E2/independent-probes.sh <新checkout> E2`，rc=1，`TOTAL pass=53 fail=4`。有效 fixture 副本：`E2/own-probes/teamsmith-v19-repair-own.gkjL8K/`（下称 **P**）；其 `argv.jsonl`、每项 `.log/.rc`、record/config 和 repo 副本保留。全部运行于新私有 HOME/repo/tmux socket，结束回收自己的 server/临时根；没有运行候选 CLI 管理真实团队。

| 自设断言 / 场景 | 实际结果及证据（P） |
|---|---|
| 原 F1：固定错误身份；attached wrong model；重复 model；固定 SID | preview/real 均早拒绝，record/board/argv 数量不变；`hardcoded-*`、`attached-*`、`duplicate-*`、`hardcoded-sid-*` |
| worker 模板借 `-c` 绕过 SID | preview/real 早拒绝且状态不变；`worker-continue-*` |
| 合法 quoted/equals 占位符实际消费身份 | rc=0；argv 的 `--provider vendor --model=expected:high --session-id=<record SID>` 与完整 assignment 一致；`placeholder-real.*`、`argv.jsonl` |
| extras 的短、引号拼接、escaped、equals 身份选择器 | `-mwrong:low`、quoted `-m`、`--'model'=...`、escaped `-m`、quoted provider/session/continue/resume；preview/real 均拒绝且状态不变；`extras-*` |
| 原 F2 与相邻坏记录 | 坏 nonce、坏 started、负 sid_bytes、重复 sid_bytes、错 window：Bash machine read assigned=false；monitor 不显示 owned 事件、报 unavailable；读前后 record/board 不变；`invalid-*` |
| 正常记录与未知/前导零快照控制 | 正常记录展示 owned SID 事件；空 `sid_bytes` 和 `0005` 两读者都接受、无副作用；`valid-monitor.json`、`valid-size-*` |
| PM 已知模型恢复、opaque fresh/交接 | 已知 metadata 的 up preview rc=0；无 identity/无 resume_args 的 opaque 模板诚实 `lost:` 交接；unused resume args 仍不称 continued；`pm-known-preview.*`、`pm-opaque-preview.*`、`pm-opaque-unused-resume.*` |
| PM opaque 冒称继续及 suffix 漂移 | 缺身份占位符的 `{resume_args}` 继续 rc=1；suffix 改变无 fresh rc=1，显式 fresh preview rc=0；所有检查无写盘；`pm-opaque-continuation-refused.*`、`pm-suffix-drift-*` |
| 去掉 glob 的合法实际启动控制 | rc=0，actual argv 只带选定模型和原 SID；`glob-restored-control.*` |

PM 自设补充检查是 render/preflight 和 metadata helper，不声称真实 provider 或 PM 全生命周期由这些 probe 证明；真实 launcher/失败回收另由独立执行的切片断言覆盖。

### F3：字面 token 校验后，shell glob 生成第二个身份选择器

关联：agent-adapters `Launch parameter ownership ends at the Pi boundary`、dispatch `Extra identity arguments cannot contradict records` / `Same-task recovery preserves the full committed launch identity`；S1 tasks 3.1、3.4、5.2–5.3。

复现根是 owned repo/worktree；两边创建并提交名为 `--model=wrong:low` 的普通文件，因此 worktree 干净，不借 `--force` 放行。已有完整合法 assignment 的模型为 `vendor/expected:high`，恢复使用原 SID。

1. 自定义 worker 模板：`recording-pi --provider {provider} --model {model} --session-id {session_id} --mod* {prompt}`。`--mod*` 在 lexer 中不是 model 选择器，但实际 shell 将它展开为 fixture 文件名。
2. 普通 builtin worker：只令 `TEAM_EXTRA_PI_ARGS='--mod*'`。同一字面 token guard 接受，builtin 实际启动也传入展开的文件名。
3. 两种路径 `--print` 与真实 dispatch **全部 rc=0**；真实 recording-agent 得到 `--model expected:high` 和 `--model=wrong:low` 两个矛盾选择器。assignment 仍只发布 `model=vendor/expected:high`，并有新 proof nonce，不能表示真实 argv 已不再唯一。

自定义路径的精确捕获：

```text
['--provider', 'vendor', '--model', 'expected:high', '--session-id',
 'v19-repair-owned-dev-1791566284-1369667-32451-20298', '--model=wrong:low']
assignment.model=vendor/expected:high
preview rc=0; real rc=0
```

builtin 记录亦含 `--model expected:high`、扩展/skill参数、`--model=wrong:low`、原 `--session-id`。精确 argv 在 `P/argv.jsonl`，日志 `E2/independent-probes.log` 的 `glob-template/extra actual argv=` 行；`P/glob-template-*`、`P/glob-extra-*` 保存 preview/real 输出和 rc。4 条 FAIL 分别对应这两路径的 preview/real，不是 4 个不同根因。

绿对照：恢复不含 wildcard 的 builtin 配置，在同一合法任务/assignment/干净分支实际 dispatch，rc=0；捕获模型和 SID与 record 一致且没有矛盾选择器。没有删除/修改候选 guard 来造红。

根因位置：`common.sh:1480–1547` 的窄 literal argv 校验把 shell wildcard 当普通 token；worker `team_agent_check_launch` 及实际模板/extra 渲染（`:4931–5198`）用同一 raw 字符串，但启动时 shell 还会 expansion。PM builtin `args+=($TEAM_PM_EXTRA_PI_ARGS)`（`:2458`）也具有相同解析分层风险，**本反例没有执行 PM glob 实际启动，不能宣称该路径已实测复现**。词法 token 与最后 argv 不同，不能用 nonce/proof 抹平。

这是 Teamsmith 已承诺的 selector ownership 缺口，而不是 Pi兼容性问题：不主张 Pi最终一定选择后者，也不探测 provider。规格明确不能依赖 Pi最后参数优先；重复矛盾 selector 已足以推翻“actual argv与record一致”的证明。请求作者令可接受窄 grammar 与实际启动表示一致（例如保守拒绝未支持的 expansion 或安全 literal argv 表示），仍无需实现通用 shell AST；我不代作者修复。

### 探针错误及不成立的假定（原始证据保留，不算产品缺陷）

- 初轮曾将 `-pother` 视为 provider 短别名，没有承诺/实际 parser 证据，已移出身份拒绝矩阵，不能因它被接受而判产品失败。
- 曾把 `sid_bytes=0005`、空 `sid_bytes` 视为坏形状。接受设计允许未知空快照，前导零也是非负数字；两个读者均接受，不存在判据分叉。新有效轮改测负数/重复字段，并补两条合法快照控制。
- 补 PM preview 时误传不存在的 up `--no-pulse`，得到 usage rc=2；该组不能作为身份拒绝证据。随后去掉该参数，全新 fixture重跑全部probe，得到上列正确 rc=0/1及原始诊断。
- 这些探索/无效假定分别保存在 `E2/independent-probes-exploratory.*`、`independent-probes-exploratory2.*`、`independent-probes-pm-invalid.*` 及各自 owned fixture 副本。未掩掉失败、未拿中间假红判产品缺陷。

### monitor 多席位同步读取观察（不是性能门禁）

实际命令：`python3 E2/monitor-multiseat.py <新checkout> E2`，rc=0。独立8席位、私有 HOME、每席位完整 record/SID/一条事件，1/4/8 席位分别三次采样；每次 JSON席位数及各自 owned marker均核实，不以 missing identity跳过解析。观察日志 `monitor-multiseat.log/.rc`、fixture及各次 JSON/stderr保留。

| 席位数 | 三次整轮耗时 ms | median ms |
|---:|---|---:|
| 1 | 59.1、56.0、53.8 | 56.0 |
| 4 | 125.7、125.2、128.2 | 125.7 |
| 8 | 216.3、222.3、222.4 | 222.3 |

当时 loadavg 为 1.38/1.58/1.56、32 cores。观察到随同步 Bash子进程数增长的近线性延迟，但本小 fixture未见秒级明显阻塞。没有运行正式 panel性能门禁、CPU SLA或真用户大历史测试，不据此声称性能通过。

## 第二轮收尾：有效验收、固定探针与最终交付

**当前限定 S1 结论：FAIL。** 11 条指定切片验收全部 rc=0；固定的自设边界探针 56/4，四红仍只是 F3 两种路径各自的 preview/real。首轮 F1/F2 的修复和合法控制成立，不消除新缺口。S2/S3、全量 smoke、真实 Pi/provider、共享采纳及其它项目均未测/未执行。本报告不是 PM review，不设 P228/V19 done。

### 11 条切片验收与源指纹闭环

实际从候选真实 clone 执行 `bash E2/run-gates.sh <候选> E2 <CONTROL_ROOT>`；`acceptance-run.rc=0`，所有子命令的精确 argv 在 `E2/<name>.command`，原始日志及 rc 在同名 `.log/.rc`。日志执行区间 2026-10-09 17:07:08–17:27:23 UTC。随后模型使用额度中断导致收割延迟，不是 gate 运行了三个小时；恢复后本会话已正式 `team_bg_wait V19-repair-gates`。

| 日志名 | 实际命令（路径前缀为候选 `skills/teamsmith/tests/`，原生工具用原用户 bun 路径） | rc / 结果 |
|---|---|---|
| openspec | `bun openspec validate --all --strict` | 0；14 passed / 0 failed |
| spec-refs | `bash spec-refs.sh --check` | 0 |
| config-cli | `bash config-cli.sh writer inject cas validate audit shape json groups models seats` | 0；外层169/0，SKIP 0 |
| routes | `bash routes.sh` | 0；207/0，SKIP 0 |
| death-pure | `bash death-cause.sh --pure` | 0；87/0，SKIP 0 |
| death-live | `bash death-cause.sh --live` | 0；7/0，SKIP 0 |
| death-flip | `bash death-cause.sh --flip` | 0；4/0，SKIP 0 |
| routing | `bash task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 0；857/0 |
| flips | `bash task-model-routing.sh --select flip` | 0；72/0，13 源码破坏臂及完整恢复857/0 |
| ledger-ban | `bash ledger-ban.sh --names-file <CONTROL_ROOT>/.pi/team/forbidden-names.txt` | 0；hits=0、names=ok |
| diff-check | `git diff --check` | 0 |

`gate-manifest.txt` 与 `gate-after.txt` 逐字节一致：HEAD=`a21a0a32480557b847d3b0ea43ad88a0847823df`，status 全空，所有 tracked `skills` 文件逐项 sha256再汇总的 digest 为 `12713e2b69946d006e849b087a7680bdfd4904722e73e8f33fca1ecbca44d58d`。未在 gate期间改候选；报告提交只发生于自身 worktree。`gate-summary.txt` 保存收尾汇总。初次汇总读取 routes 的非纯 UTF-8输出遇到 decode error，改为仅汇总显示 `errors=replace`；原始日志、测试rc及源指纹未改，这不是测试失败或重跑。

### S1 场景 → 实际断言 → 独立执行证据

下列断言名来自我本轮 `routing.log` 的 PASS 行；全部由上表 routing 命令独立执行、rc=0。它们说明现有护栏工作，不证明边界已经穷尽；F3 为同一原候选上的独立反例。

| S1 tasks / 场景 | 真实断言举例 | 证据 |
|---|---|---|
| 1.1–1.3：整体策略、显式类别，不以 phase推断 | `policy-minimum-analysis-verify`、`policy-custom-category`、`generated-category-header`、`phase-does-not-infer-category:verify`、`new-unmapped-category-override-refused` | routing.log policy/machine/dispatch 段；spec-refs.log |
| 2.1–2.3：配置 writer/CAS、完整升级、旧字段及审计失败 | `map-cas-first`、`map-cas-loser`、`simultaneous-map-cas`、`upgrade-retired-removed`、`upgrade-whole-file-fault:late-cas`、`upgrade-readers-wholly-old-before-rename-new-after`、`upgrade-audit-unwritable-honest-committed-result` | routing.log config/upgrade；config-cli.log 外层169/0 |
| 3.1 / 3.4：新派单与同任务原模型/SID，删类别仅恢复豁免 | `first-recorded-launch`、`untrusted-recovery-refused:category`、`deleted-routine-recovery`、`recovery-model`；原 F1早拒绝/合法 argv及 F3矛盾 argv由我自设 probe 捕获 | routing.log dispatch/resume/preview；固定探针日志与argv |
| 3.2：proof/nonce、原子发布、close/teardown锁顺序 | `failed-launch-old-record-bytes`、`stale-launch-proof-refused`、`close-waits-for-publication-lock`、`close-no-identity-resurrection`、`teardown-waits-for-publication-lock`、`teardown-race-no-resurrection`、`lock-owner-liveness-and-reclaim` | routing.log transaction；对应源码 flips |
| 3.3：配额及未知身份 fail-closed | `unknown-live-peer-fail-closed-even-force`、`unknown-live-peer-real-launch-refused`、`unknown-live-peer-real-record-preserved`、`unknown-live-peer-real-no-launch` | routing.log limits；unknown-as-zero mutant |
| 4.1–4.3：PM独立模型、恢复/fresh/opaque、失败回收；SID A不读B/base | `pm-independent-model`、`pm-known-continues`、`pm-changed-resume-selector-needs-fresh`、`pm-publication-failure-stops-uncommitted`、`reader-session-A`、`reader-cause-A`、`monitor-missing-A-unavailable`；坏记录matrix覆盖所有reader | routing.log pm/sid-readers/boundary；固定 probe PM控制及坏nonce |
| 5.1–5.3：各正/负矩阵、实际源码破坏、接缝范围 | routing857/0、13臂flip72/0及恢复857/0；自设 F3红/普通argv绿、quoted边界分类 | routing.log、flips.log、固定探针与下节 |

13 源码破坏臂均仅改 owned scratch：`unmapped-override`、`fingerprint`、`expanding-quote`、`recovery-drift`、`partial-publication`、`unknown-as-zero`、`latest-shell`、`latest-monitor`、`pm-fallback`、`pm-publication`、`extra-shadow`、`template-shadow`、`monitor-record-drift`。每臂都有目标 matched、shape-valid、子命令rc=1、具名断言抓到红、source_before=source_restored。尤其新两臂分别抓到worker/PM模板身份绑定及nonce reader分叉。完整 baseline/restored 两端均857/0；`flips.log`/`gate-summary.txt` 保留13组hash及控制，`flip-fixtures/teamsmith-task-model-routing.sZazVp/` 保留子日志。config-cli内部和flip日志出现的 mutant红是防护证据，不算原始候选失败；F3才是原始候选自身的红。

### 固定版本与 quoted 边界：替代迭代探针的正式收尾

上一节53/4来自已保留的开发式探针迭代，且后来再加了3条quoted控制。我没有为早轮记录脚本的前后hash，故**不把这些迭代轮作为本次正式固定探针验收**；保留其原始证据与诊断，不追补或伪造前置hash。PM曾读到运行中的live脚本的情况由PM自己的记录判无效，不借其结果证明我的执行。

本次收尾未扩大调查：仅复制现有完整脚本为 `E2/frozen-final/independent-probes.sh` 并设只读，在新 owned HOME/repo/socket 重跑已有全部断言。命令：`bash E2/frozen-final/independent-probes.sh <候选> E2/frozen-final`。实际rc=1，`TOTAL pass=56 fail=4`；这是最终有效反例轮，不是门禁通过。

- 固定脚本 sha256：`c89a34054df1ee286d7296ff92408aed86d4a5366176a61970f107140f95077a`，`script.before.sha256` / `script.after.sha256` 逐字节一致。
- `source.before.txt` / `source.after.txt` 逐字节一致：完整SHA仍为受检对象，status空，tracked skills digest同上；`stability.txt` 明确记录 `script/source stable`。
- 最终证据根 **PF**：`E2/frozen-final/own-probes/teamsmith-v19-repair-own.HyKxQ0/`；每例.log/.rc、完整record/config和 `argv.jsonl` 留存。`frozen-final/independent-probes.log/.rc` 是唯一用于最终56/4统计的日志。
- F3本轮的原SID=`v19-repair-owned-dev-1791578561-1194519-31239-11715`；模板/extras 的 preview/real均rc=0，actual argv均有 `--model expected:high` 和 `--model=wrong:low`，完整record仍为`vendor/expected:high`。四红各有精确argv及成功发布的nonce。恢复普通启动rc=0，只有正确模型、原SID，无矛盾选择器；原F1/F2防护及所有相邻绿控制同时成立。
- 新增的 quoted 控制**不是另一缺陷**：将整个 `{provider}`/`{model}` 值置于单/双引号的模板均诚实rc=1，诊断明确“{provider} 必须是独立未加引号的 argv 值”，recording-agent未启动。未加引号的标准占位符模板配合法形状`vendor/expected*`，rc=0，实际model字面量为`expected*`，与record一致。这是窄 grammar支持/拒绝的边界，不证明所有quoted形式受支持，也没有发现 model字面量被改写；不要把拒绝或可能的escaping假定算作F4。
- `-pother` 无provider别名证据、未知空/前导零sid_bytes合法、错误`up --no-pulse`等前述勘误保持；均不计入56/4的失败。

### 最终交付与止点

本轮独立长作业均已收割，包括 gates、旧控制、monitor观察、各探针迭代及 `V19-quoted-boundary`、最终 `V19-frozen-closeout`；无尚在运行的候选作业。额度中断及收割延迟如实记录，没有换模型或读取Pi credential/history。先提交了已验证反例步骤 `f9e3718`，本节再提交收尾；最终报告只追加首轮，不改首轮正文。报告收尾 `git diff --check` 为rc=0；隐私检查 `report-ledger-ban-final.log/.rc` 为rc=0、hits=0、names=ok；首轮0380cdd报告prefix逐字节一致，13臂源码hash全部恢复。提交后核对自身任务分支干净，再从稳定CONTROL_ROOT CLI通知PM。候选源树、实际团队/共享安装及远端保持不变。请求PM据自己的review与本报告交回作者修F3；不授权任何下一阶段、合入或共享采纳。

---

## 第三轮独立修订：a1a285d，新增 continued 模板绑定反例

前两轮 FAIL 正文及证据保持原样。新受检完整 SHA：`a1a285df366b49c95fe65ddbad358221c62de921`，独立真实 clone：`../pm-skills-ledger/team/reviews/V19/glob-a1a285d/checkout`。与作者受检 `d823c7e497a621538dc697e782344f5814ff3dca` 的 skills 差异为空；final 差异仅报告。以下 **E3** 指 `../pm-skills-ledger/team/reports/V19-dev3/glob-a1a285d/`。所有结论仅限 S1，不是完整 change 或 PM 正式 review。

当前已完成的独立反例结果为 **144 PASS / 8 FAIL，rc=1**：F1/F2/F3 的既知路径均由新防护拦截，新增的八红来自同一 binding 漏洞，不能说候选已通过。11 条切片 gate 的完整收尾待后续小节追加，不提前声称已通过。未采用作者 1244/0、94/0 作为自己的结果。

### 输入与修复差异

先核对自己的 status/log、主检出最新 thread/brief、OWNERSHIP、D104–D113 与冻结清单，再读接受的 proposal/design/tasks、相关 delta/canonical 和 P228 完整报告。候选真实 `.git`、HEAD、干净状态、源码对照和 /tmp 余量均记录于 `preflight.txt`、`capacity.txt`。本轮新增源码差异 `glob-repair-source.diff`：literal lexer 对未加引号的 pathname/brace/tilde 扩展 fail-closed；PM/worker模板、extra/resume入口共用该 guard；worker rendering 的重复校验补强。新增 expansion matrix、三破坏臂和恢复控制；未见删除、skip 或弱化原非模型断言，未扩大 close/review/merge 授权。原候选不改，仅 E3 自己的 fixture/scratch 可写。

### F4：有占位符，不等于绑定到了身份选择器

关联：agent-adapters `Launch parameter ownership ends at the Pi boundary`，dispatch `Same-task recovery preserves the full committed launch identity`；S1 3.1/3.4/5.2。缺陷发生在 Teamsmith 的 argv 和完整 assignment 发布边界，不要求测试真实 provider，也不推断 Pi 会采用什么默认模型。

已成功建立合法原 assignment 后，保持同任务、原模型/SID，不使用 fresh。下面四个 literal 模板的 preview 和真实 dispatch **均 rc=0**：

| 模板中身份部分（省略 executable 和 prompt） | recording-agent 实际 argv | 发布记录 |
|---|---|---|
| `--provider {provider} --label {model} --session-id {session_id}` | `--provider vendor --label expected:high --session-id <原SID>`，没有 model selector | `mode=continued`，原 `model`/`sid`，新 nonce |
| `--label {provider} --model {model} --session-id {session_id}` | `--label vendor --model expected:high --session-id <原SID>`，没有 provider selector | 同上 |
| `--provider {provider} --model {model} --label {session_id}` | `--provider vendor --model expected:high --label <原SID>`，没有 SID selector | 同上 |
| `{provider} {model} {session_id}` | `vendor expected:high <原SID>`，三个值均为普通 positional 参数 | 同上 |

这不是“opaque 新任务可交接”的合法路径：完整旧记录有效，运行成功后被明确标成 **continued**，却无法证明实际 CLI 消费了记录的身份选择器。`common.sh` 的 `team_template_identity_guard` 创建 `seen` 记录合法 selector 绑定，但 continued 尾部只要求 `refs` 中出现各占位符，不要求相应 `seen` 绑定；独立普通词也被计入。没有修源或把 generic Bash/provider 适配纳入需求。

固定探针：`bash E3/independent-probes-third.sh <候选> E3`；冻结 SHA-256 `23b3554260a2b7c27c9193053712ae8e6668cba3f9d3f7cd77c57634590b07ad`。`probe-script.before.sha256`/`after`、`probe-source.before.txt`/`after` 完全一致，`probe-stability.txt` 记录 source/script stable。实际日志 `independent-probes-third.log/.rc`；fixture **P3**=`E3/own-probes/teamsmith-v19-third-own.kWIDBA/`，保留各 `.log/.rc`、`*-argv.json`、`*-published.env` 和完整 `argv.jsonl`。四组名字为 `unbound-model`、`unbound-provider`、`unbound-sid`、`positional-identity`；各 preview/real 为两红，共八红。

相邻绿：原 hardcoded/duplicate/continuity 模板早拒绝且 record/BOARD/argv 数量不变；合法 `--provider {provider} --model={model} --session-id={session_id}` 的真实 argv 与 assignment 完全一致；去掉 glob 的 builtin 真实启动也匹配原模型/SID。单/双引号 identity placeholder 诚实拒绝，未加引号 model 字面 `expected*` 正确保留，不记假红。另冻结更小的纯 positional binding 控制，去掉 `--label` 自定义参数，具体结果与全部 gates 收尾另附。

**BLOCKED:** F4 属于 P228 产品/测试写集合，交回 PM 独立判定与作者修复；我只写报告和自己的仓外证据，没有改候选或规格。已通过稳定主检出 CLI 通知 pm，并继续完成本轮既定验收与源稳定性闭环，不启动 S2/S3 或真实项目。

### 第三轮收尾：当前限定 S1 结论 FAIL，既定切片全部执行

**最终结论仍为 FAIL。** 11 条指定切片全部 rc=0，但新增 F4 在未修改的候选上确实发生。既有测试全绿和受控破坏臂能抓到红，不消除这个未覆盖的绑定边界。PM 在 22:05 的往来记录确认自己另行复现 11/8，并确认 continued 合同适用；该 PM 小包不计入我的独立统计。本轮没有更换模型、额度中断、修改候选或扩展调查。

#### 更小的纯 positional 红 / 合法 selector 绿

命令：`bash E3/positional-binding-control.sh <候选> E3/binding-control`，rc=1，**1 PASS / 6 FAIL**。脚本 SHA-256=`6890e73dd416ad24337608de3d5c3773244c2233963eb66f85fd48fd007adbf6`，`binding-script.before.sha256`/`after` 及 `binding-source.before.txt`/`after` 逐字节相同；日志 `binding-control/run.log/.rc`，fixture=`E3/binding-control/own-probes/teamsmith-v19-third-own.m3cFBc/`。

三个模板分别仅把 SID、model、provider 占位符改成普通 positional 参数，另两项维持合法 selector，不使用任何 `--label` 或未知 alias：

```text
--provider {provider} --model {model} {session_id} {prompt}
--provider {provider} {model} --session-id {session_id} {prompt}
{provider} --model {model} --session-id {session_id} {prompt}
```

各 preview/real 均 rc=0，actual argv 中对应 selector 缺失，完整记录仍为 continued/原身份/新 nonce；六红均有各自捕获的 argv 和发布记录。恢复完整 selector 模板后真实启动 rc=0，provider/model/SID 与记录匹配。这个红绿只证明 Teamsmith 错把词面出现当作启动身份绑定，不推断 Pi 默认身份或远端效果。

#### 旧红 → 新拒绝 / 相邻绿，以及 expansion 入口矩阵

所有 probe 在明确核对的 owned fixture repo/HOME/私有 tmux socket 执行，结束只回收自己的 server/临时根并保存副本。原三个 clone 均保持 HEAD/status/source hash；控制脚本运行前冻结，运行后 hash 相同。`old-control-script.before.sha256`/`after`、各 `old-*/source.before.txt`/`after` 为原始证据。

| 场景与真实断言 | 本轮命令 / 结果 / 证据 |
|---|---|
| 旧 F1/F2：wrong provider/model/SID 发布；坏 nonce 的 monitor 分叉 | `bash E3/old-f1f2-control.sh <首轮clone> E3/old-f1f2`，rc=0，旧缺陷成功复现；`old-f1f2/run.log` 的 RED 与合法模板/记录 GREEN 同在。rc=0 是复现脚本完成，不是产品通过 |
| 旧 F3：template/extras 展开第二个 model selector | `bash E3/old-f3-control.sh <a21clone> E3/old-f3`，rc=1，56/4；`old-f3/run.log`，四红均 preview/real 放行且真实 argv 有重复 model；去掉 glob 恢复控制绿 |
| 新 F1/F2/F3 及 PM guarded/opaque 边界 | 固定主探针的既知 60 条控制全绿：原错身份早拒绝，record/BOARD/argv 不变；坏记录 Bash/machine/monitor 一致不可用，合法记录与允许的空/0005 快照读 A；新 F3 template/extras 早拒绝，恢复 builtin argv 匹配记录。P3 的 `hardcoded-*`、`invalid-*`、`valid-*`、`glob-*`、`pm-*` |
| worker/PM × template/extras 的带诱饵 shell expansion | 主探针新增 56 条拒绝控制全绿，preview/real 各测：provider/model/SID/continue/resume glob、部分引用 glob、brace expansion。两 cwd 均有 committed 诱饵文件；各 `expanded-*` rc=1，record/BOARD/argv 数量不变 |
| 引号 literal 支持与真实参数逐字节一致 | 主探针新增 8 条控制全绿：worker/PM × template/extras 的 preview 只读，真实 argv 的 `two words` 为单值，`--mod*`、`{plain,words}`、`~/literal`、single-quoted backslash 是原字面量；provider/model 唯一，worker SID 与记录一致。`literal-*`；不把 quoted glob 字面词误记为绕过 |
| PM 恢复入口的 expansion | 主探针新增 20 条拒绝控制全绿：builtin/custom × 五种 selector 诱饵 × preview/real；同 resume-key 的可信 fixture metadata，不借 fresh-pm 清空参数。`pm-resume-*`，状态/argv 不变 |

以上主探针的绿共 60+56+8+20=144；另有 F4 的八红。小 positional 包单列 1/6，避免把不同 fixture 的重复控制混成一轮结果。没有旧短 provider alias、合法未知尺寸、literal quoting 等假红。

#### 11 条独立切片、输出尾部与源稳定性

实际 driver：`bash E3/run-gates.sh <候选> E3 <CONTROL_ROOT>`，11 条命令串行，一个 gate 一次；`V19-third-gates` 已工具收割，exit=0，耗时 2173.2s。每条实际命令在 `E3/<tag>.command`、stdout/stderr 在 `<tag>.log`，退出码在 `<tag>.rc`；`acceptance-run.log/.rc` 和 `gate-summary.txt` 为整体索引。

| 实际命令 | 输出尾部 / rc | tag |
|---|---|---|
| `"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict` | 14 passed / 0 failed；0 | openspec |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs，retired 0 / undeclared 0；0 | spec-refs |
| `bash skills/teamsmith/tests/config-cli.sh writer inject cas validate audit shape json groups models seats` | 169/0，顶层 SKIP 0；0 | config-cli |
| `bash skills/teamsmith/tests/routes.sh` | 207/0，SKIP 0；0 | routes |
| `bash skills/teamsmith/tests/death-cause.sh --pure` | 87/0；0 | death-pure |
| 同脚本 `--live` / `--flip` | 7/0 / 4/0；均 0 | death-live / death-flip |
| `bash skills/teamsmith/tests/task-model-routing.sh --select policy,machine,config,upgrade,dispatch,resume,transaction,limits,preview,sid-readers,pm,boundary` | 1244/0；0 | routing |
| 同脚本 `--select flip` | 94/0；恢复后 1244/0；0 | flips |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | files=1310 hits=0 names=ok；0 | ledger-ban |
| `git diff --check` | 无输出；0 | diff-check |

config 的嵌套 preview 控制显示 SKIP 1，顶层 SKIP 0，未隐去。routing 外层 timeout=1800s，flips=4800s，符合 brief 至少 1400/4200s，无 timeout。没有跑尚依赖 S2/S3 的全仓 smoke。

`gate-manifest.txt`/`gate-after.txt` 完全相同：受检完整 SHA 不变、status 空、tracked skills 聚合 SHA-256=`7c366f86c6ef96de77e46645759ef83cc26001fee453e8f78aae74faa86a3be5`。driver 的前后 SHA 相同：`ccdf1f1d29b901c8716790bb6a8e4970025bad80eecef336a8128e3793fa4ae5`。新主探针、小 binding 包、旧控制及 monitor 脚本前后 hash 均相同；不是在运行中改脚本的迭代轮。

#### 场景映射与 16 个 scratch 破坏臂

此前第二轮的 S1 分组索引保持适用，核心事务/锁/配置接口未改。本轮实际重新执行对应命名断言，新增边界另列，不能沿用第二轮 PASS 当新运行：

| S1 场景组 | 本轮真实断言 / 日志 |
|---|---|
| 1.1–1.3：类别/整体策略/非 phase 推断 | policy/machine 的 `policy-minimum-analysis-verify`、`phase-does-not-infer-category:verify`、`generated-category-header`；routing/spec-refs |
| 2.1–2.3：writer/CAS/整体升级/故障与读者中间态 | `simultaneous-map-cas`、`upgrade-whole-file-fault:late-cas`、`upgrade-readers-wholly-old-before-rename-new-after`、`upgrade-audit-unwritable-honest-committed-result`；routing/config-cli |
| 3.1–3.5：新选择、恢复、nonce/原子发布/锁/配额/preview | `new-unmapped-category-override-refused`、`recovery-model`、`recovery-sid`、`failed-launch-old-record-bytes`、`stale-launch-proof-refused`、`close-no-identity-resurrection`、`teardown-race-no-resurrection`、`unknown-live-peer-real-no-launch`；routing；F4 独立反例使实际 continued 身份承诺失败 |
| 4.1–4.2：SID A 不串 B/base、完整记录/死因读侧 | `reader-session-A`、`reader-cause-A`、`monitor-missing-A-unavailable`、`reader-monitor-unavailable:nonce`；routing/sid-readers；death 三组及独立坏记录控制 |
| 5.1–5.3：PM/边界/实参及源码反例 | `pm-known-continues`、`pm-changed-resume-selector-needs-fresh`、`pm-publication-failure-stops-uncommitted`、worker/PM expansion 和 literal argv 命名矩阵；routing/boundary；独立主探针及下面 flips |

`E3/flip-fixtures/teamsmith-task-model-routing.aWgjvb/` 保留 16 个 `mutation-*.json`、嵌套红日志和恢复 fixture。每臂都实际修改 owned scratch，target matched/shape-valid、子命令 rc=1、具名 FAIL、source_before=source_restored；`gate-summary.txt` 已逐一核对全部 16 hash 相同。

原 13 臂全部重跑；新增 `literal-shell-expansion` 命中 worker/PM × template/extras 的 model-glob launch 拒绝断言，`pm-literal-resplit` 命中 PM extra/resume literal argv，`worker-literal-resplit` 命中 worker extra literal argv。坏源码的红是预期防护证据，不计入基线产品失败。baseline/restored 都 1244/0、外层 94/0；F4 是原候选本身的漏洞，不能用这些现有 mutant 的成功捕获替代它。

#### monitor 观察与最终交付止点

`python3 E3/monitor-multiseat.py <候选> E3`，rc=0。新 isolated HOME/记录下 1/4/8 席各三样本，median=53.6/132.2/231.8ms，均读到各自 owned SID 事件；32 cores、loadavg=7.73/5.00/5.29。原 JSON/stderr 在 `monitor-multiseat-fixture/`，脚本 hash 前后相同；这一小记录观察未出现明显阻塞，**没有执行正式性能门禁、CPU预算、TUI帧或大日志性能验收**。

本轮四个后台作业全部已工具收割：`V19-third-gates`、`V19-third-independent`、`V19-third-old-controls`、`V19-third-binding-control`。完整 gates/反例/旧红绿/固定输入闭环已落盘，没有悬挂工作。只提交自己的报告，前两轮正文保留；最终隐私、prefix/diff/自己树干净核对和稳定 CLI 通知记录另存 E3 的交付日志。

未测/未授权：S2 UI、S3 init/指南，完整 change 的全量 smoke/独立验收，真实 Pi/provider/跨模型会话质量或消息/推理适配，其他项目、共享来源/main 采纳、真实配置升级/服务启动、远端写入、合并/部署/归档。本轮交付的是 **S1 完整失败证据**，请求 PM 在冻结候选上处理 F4；我不修作者源码，不 mark done，不解冻或派下一阶段。
