# E16 · Pulse 关键回复页正式提案

agent: dev2   status: PROPOSAL COMPLETE — 待独立审核   time: 2026-10-09T11:42:34Z
branch: `task/E16-pulse-key-replies-propose`   PR/MR: -（local，无 push）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/pulse-key-replies/proposal.md` | 使用者入口与范围，CLI 主动保存后仍正常答复 |
| `openspec/changes/pulse-key-replies/design.md` | 存储/原子提交/有界读、异步块、交接与非部署采纳顺序 |
| `openspec/changes/pulse-key-replies/tasks.md` | 17 个未勾任务，56 个 delta 场景与后续命令/证据双向映射 |
| `openspec/changes/pulse-key-replies/specs/key-replies/spec.md` | 新能力 delta，10 requirements / 22 scenarios |
| `openspec/changes/pulse-key-replies/specs/panel/spec.md` | 3 个完整 MODIFIED + 4 ADDED / 34 scenarios；保留原页/设置场景 |
| `docs/team/reports/E16-dev2.md` | 本报告；唯一额外 tracked 写入 |

完整 tracked 写集合就是上表六份文件。仓外证据根为 `../pm-skills-ledger/team/reports/E16-dev2/`（记为 `E`）：native instructions/status、逐命令日志、三个独立试归档树、`run-planning.sh` 与 `check-projection.py`。未写产品代码、bundle/快照、canonical specs、另一 change、公共账本或配置；未启动面板原型/服务、执行真实归档或部署。

输入 tip `5329f72`；工件受检 tip `b6dfb50890a960452aa915bf1915f19ff971f882`。小步提交依次 `ab58478`、`7279ca1`、`e312d22`、`2f22980`、`c4edb98`、`b6dfb50`，均含 E16 和 `Agent: dev2`。报告另提交；最终交付 tip/clean status 在 `E/delivery.log`，不在报告内自指自己的 commit SHA。

## Verification evidence (must have actually been run)

所有指令从 own worktree 发起。`O=$HOME/.bun/bin/openspec`，原生 CLI 用 `$HOME/.bun/bin/bun "$O"`；控制根 `CONTROL_ROOT` 从 git-common-dir 的父目录推导，仅用于稳定控制 CLI 与正确的隐私名单。资料检查与试归档不运行 smoke/功能测试。

最后完整工件检查作业 `E16-frozen-artifacts`：20.3s、exit 0、已 harvest。此前 `E16-planning-projections` exit 1（仓外检查器正则错误）、修正后的 `E16-planning-final` exit 0，均已 harvest；每项真实 rc 保存在各轮 `results.tsv`。后台摘要有 log cap，完整逐命令原始输出在 E，不能只看截断的后台摘要。写入本报告后又执行 `E16-report-brief-check`（4.9s / exit 0，已 harvest），brief 七条检查全部 rc=0；其逐条输出在 `E/delivery-check/`。

| 实际命令 | 输出尾部 / rc | 原始证据 |
|---|---|---|
| `bun "$O" context --json` | root.path 为 dev2 worktree，nearest / openspec_root；0 | `E/context.log` |
| `bun "$O" schemas --json`、`instructions proposal/specs/design/tasks --change pulse-key-replies --json` | 默认 spec-driven；所有 resolvedOutputPath 都在本 change；各 0 | `E/schemas.json`、`E/02-*` / `04-*` / `07-*` |
| `bun "$O" status --change pulse-key-replies --json` | 4 artifacts done / isPlanningComplete=true；0；不代表17个实现任务完成 | `E/status.log` |
| `bun "$O" validate --all --strict` | `Totals: 15 passed, 0 failed (15 items)`；0 | `E/validate.log` |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 104 refs / 49 distinct / retired 0 / undeclared 0；0（含报告） | `E/delivery-check/refs.log` |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"` | files=1315 / hits=0 / names=ok；0（含报告） | `E/delivery-check/privacy.log` |
| `git diff --check` | 无输出；0 | `E/diff.log` |
| `bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/E16-dev2.md` | decision=NONE / sections=125 / keys=0；docs账本不需要功能段；0 | `E/selection.log` |
| `bash skills/teamsmith/scripts/team help`、稳定控制 CLI `--root "$CONTROL_ROOT" paths` | 当前无reply入口；main_root=控制主检出、session=teamsmith；各0，只读 | `E/spot-help.log` / `spot-paths.log` |
| `node skills/teamsmith/scripts/panel/panel.js --help`、`bash skills/teamsmith/tests/perf.sh --help`、`flock --help` | 当前 snapshot page仅1–4；perf/flock现有选项可解析；各0，未启动TUI/perf | `E/spot-*-help.log` |

另做现有 test/build 路径存在性核对，输出 `E/spot-command-paths.log`；仅查路径/源码/帮助，不声称跑过其测试。三个新 reply 前门和本基线不存在的 routing 测试明确为 future / NOT RUN。只读取得 P228 候选 git object 中 cmd-config 源码，核对 categories/assignments/pm_launch 与命令接口，没有执行候选 CLI；快照为 `E/P228-candidate-cmd-config.sh`。

### 原生试归档与投影

实际复制方式为 `cp -a "$PWD/openspec" "$E/trials/<mode>/openspec"`；只在这些自建目录 `cd` 后运行原生 archive，未使用 PM 的集成 clone。各 trial 的 context 指向其自身 root。`E/source-openspec-{before,after}.sha256` 完全一致：原 change 与 canonical 没被试归档改变。

```text
current: bun "$O" archive -y pulse-key-replies
         bun "$O" validate --all --strict
         python3 "$E/check-projection.py" current "$PWD" "$E/trials/current"
archive rc=0; Totals +14 / ~3; validate 15/0 rc=0; assertion rc=0
LIMIT: single-current-base projection is structural only; category-settings semantics still require routing first

ordered: bun "$O" archive -y task-model-routing
         bun "$O" validate --all --strict
         bun "$O" archive -y pulse-key-replies
         bun "$O" validate --all --strict
         python3 "$E/check-projection.py" ordered "$PWD" "$E/trials/ordered"
全部rc=0；两次validate均14/0
PASS all routing ADDED/MODIFIED scenario titles retained across seven capabilities
PASS overlap fidelity: complete accepted routing settings block unchanged except page clause
PASS reply projection: key-replies 10 requirements; panel 7; all delta scenarios retained
PASS inherited scenario retention: all current-base scenarios in the three modified blocks

reverse: bun "$O" archive -y pulse-key-replies
         bun "$O" archive -y task-model-routing
         bun "$O" validate --all --strict
         python3 "$E/check-projection.py" reverse "$PWD" "$E/trials/reverse"
archive/validate均rc=0（validate 14/0），但语义反例命中：
EXPECTED CONFLICT: replies→routing restores the obsolete four-page settings constraint; unsupported order
```

反序 assertion rc=0 是**成功识别预期冲突**，不是反序可采纳。structural green 不证明顺序或行为正确。逐命令输出见 `E/trial-*.log`。native warnings 如实保留：本项 `Consider splitting changes with more than 10 deltas`、`Task status: 0/17`、`17 incomplete task(s)`；routing 的 incomplete 警告见其日志。`-y` 仅在复制品试归档跳过确认，未勾任务；两 capability 的完整 MODIFIED 与安全/故障场景保留，不为消掉数量提示拆开这一功能。

### 检查器自身的失败与修正

第一轮 native archive/validate 都是0，但 `check-projection.py` 的 requirement title 正则在 DOTALL 下使用 `(.+)`，把多行误当标题，三项 assertion 均 KeyError/rc=1。原日志与投影树留在 `E/first-run/`，没有删除失败。改为 `([^\n]+)` 后，对原三个投影逐一重跑得到0；再从全新复制品完整重跑两轮得到 `FAIL steps=0`。这是**规划证据脚本修正**，不是产品缺陷修复或产品翻转通过。

## Flip evidence (required for defect-fix tasks)

本任务是 propose，未改/运行产品实现，无产品 red→green。反序试归档是规格组合的对抗性证据；未来真实 helper/bundle 破坏→guard 红→还原绿已列入 tasks 的 flip 组，本轮 NOT RUN。

## Decisions and deviations

- 完整设计取舍在 design，formal可观察约束只在 delta；报告不另立规格。固定第五页、完整答复、主动标记都保留。
- E15 的探索推荐未视为已采纳：正文128KiB由本提案选择并明确超限拒绝；旧 detail 的截断/丢尾换行路径不直接复用；有界固定槽位与cursor让旧答复仍可达。不增加新项目配置键、Pi工具或审核/通知状态。
- 发布失败用stderr，不承诺同一不可写目录可审计；可见但持久性未确认返回unconfirmed，不自动重发。普通答复不以保存成功为前置条件。
- flock 已用于现有门禁，但原门禁允许缺依赖时有提示降级；本项发布不能无锁降级，缺安全锁能力时可见unavailable。读入口不需要writer锁；性能/I/O/安全fd实现仍须后续真实验收。
- 共享 settings MODIFIED 块以前一 routing 接受 delta 全文为基准，本项仅改五页相关句；要求完整私有路由交付先接收。本轮 P228 `16842c9` / 产品 `ba783c7` / 测试 `017fbf9` 都只作候选输入，未宣称 main已有类别模型UI。未来common/team/cmd-watch/panel/bundle/快照/SKILL/协议/help只允许单写者串行。
- 历史“四页” requirement 标题保留为引用锚，正文已改五页；没有并排保留两套页位合同。正式采纳顺序需要PM管理，不能依赖proposal deps文本或spec-refs自动排序。
- 主检出产品、共享技能软链接、真实配置、Pi历史、其他项目均未改/未读会话。控制操作限paths与交付notify；team_bg工具的日志由harness写到控制state/bg，不声称共享state全目录不变。没有push、merge、启动apply、真实archive或shared rollout。

## Verdict and unverified work

Verdict：提案工件与结构/引用/隐私/差异/试归档检查通过；**产品功能与可用性未验证，提案尚未独立接受**。正文持久提交、锁耗时/中断恢复、安全路径替换、10万槽读量、真实pty键鼠/resize/长文尾部、完整端到端、bundle/snapshot与perf/full smoke均未实施/运行。相关可执行前门及场景映射在 tasks，不用规划结构绿冒充这些结果。

## Suggested next steps

交由不同作者独立审核本 change，重点检查固定槽位成本/持久性失败语义、旧页可达性和routing顺序保全。接受后再由PM按授权派apply；P228候选需独立接收并完成S2/S3冻结交接，本任务不自行开工。local分支保留，所有后台作业已收割；无需push/PR，也不触发远端CI。
