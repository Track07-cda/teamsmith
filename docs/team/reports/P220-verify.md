# P220 · P218 的换人独立验证（版本锚点 + §41 needs）

agent: verify   status: PARTIAL / BLOCKED   time: 2026-10-04T20:09Z
branch: `task/P220-verify`   PR/MR: -（local 模式，不 push）

**结论：P218 范围判据通过；要求的 live 选段门禁未通过。** 版本换成 `7.3.1-rc2` 后 §39 仍全绿；sed 空转与漂移值相等均被立即点名；删掉回读守卫后独立 oracle 转红；§41 的 needs 生效、不再级联。但 live §41 仍有两条既存红，不能报整体 PASS。

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/P220-verify.md` | 独立判据、实测数字、影子与交付阻塞 |
| `docs/team/reports/P220-verify/` | 自写 runner/oracle、原始命令、日志、退出码、scratch diff、摘要；按 D94 ignore，留在工作树 |

被验实现：`88a50cd69913`，初始分支 HEAD `ee371e8d`；正式探针 clone HEAD `e583a248c325`（仅增加本任务检查点报告，实现未变）。所有门禁都在 `localhost/teamsmith-gate:local` 容器内跑，挂载自己的干净 clone，不挂 worktree 的 `.git` 指针。没有切换分支、没有修改工作树实现。重建用 clone 已清理，证据包约 472 KB。

## Verification evidence

**下表全部自己运行，不引用作者或 PM 的通过数字。** 每例先固定 scratch 现场，再运行；正常路径没有 FAST 跳过，也没有“本次运行无效”。原始命令在证据包 `logs/*.command.json`，摘要为 `summary.json`。

```sh
python3 docs/team/reports/P220-verify/run.py
# 断点续跑实际使用 --resume；容器内逐例执行以下命令：
openspec validate --all --strict
bash skills/teamsmith/tests/install-shape.sh
bash skills/teamsmith/tests/smoke.sh --select <keys> </dev/null
```

OpenSpec：`Totals: 13 passed, 0 failed (13 items)`，rc=0。

| 自造现场 / 命令 | 直接 install-shape | smoke 选段结果 | rc（smoke） |
|---|---|---|---|
| 原版本 `0.1.0`，`--select 39,2,41` | ✓101 ✗0，rc=0 | ✓157 ✗2 | 1 |
| 只改 `common.sh` 的 TEAM_VERSION 与 SKILL.md 为 `7.3.1-rc2`，同一选段 | ✓101 ✗0，rc=0 | ✓157 ✗2 | 1 |
| 恢复 `0.1.0`，`--select 39` | ✓101 ✗0，rc=0 | ✓22 ✗0 | 0 |
| 单独 `--select 41` | — | ✓156 ✗2 | 1 |
| 显式 `--select 2,41` | — | ✓156 ✗2 | 1 |
| 单独 `--select 2` | — | ✓62 ✗0 | 0 |
| SKILL.md 的 version 行由两空格改四空格，`--select 39` | 立即 setup 停止，rc=3 | ✓21 ✗1 | 1 |
| 上一现场再删掉回读断言，`--select 39` | ✓96 ✗5，rc=1 | ✓21 ✗1 | 1 |
| 令 `v_drift="$v_run"`，`--select 39` | 立即 setup 停止，rc=3 | ✓21 ✗1 | 1 |
| 删除映射表 §41 的 `needs:2`，`--select 41` | — | ✓21 ✗1 | 1 |
| 恢复所有 scratch 改动，再跑 `--select 39,2,41` | ✓101 ✗0，rc=0 | ✓157 ✗2 | 1 |

### 版本锚点与正常路径

改版本后，四次漂移副本回读都给出 `7.3.1-rc2 → 7.3.1-rc2-drift`。关键尾：

```text
✓ 冲突消息给出 --force 出路
✓ 漂移副本：warn 点名 7.3.1-rc2-drift 与 team init --force
✓ ③ 对照：真实树漂移 warn：warn 点名版本 7.3.1-rc2-drift 与修法
✓ ③ 翻转：doctor 的 warn 被静默：翻转后红（install 行没有 warn：[]）
== 结果 == ✓101 ✗0 SKIP0
```

原版、改版、恢复版均覆盖三种未知条目不删除（含 `--force`）、手改副本拒绝/修复、别源软链冲突/重指、doctor link/absent/drift 行与全部原有翻转。§2 自身始终 ✓41 ✗0；单独选跑总计 ✓62 ✗0。

### 失效现场必须点名，不往下跑

四空格 version 行仍可被版本读取器读取，但 sed 的两空格锚点不再命中：

```text
✗ 夹具没生效（setup） 副本版本改不动（sed 没命中 frontmatter 的 version 行）：<fixture>/c-copy/.pi/skills/teamsmith/SKILL.md
# install-shape rc=3；没有后续冲突断言，没有完整结果行
```

另一个独立现场：

```text
✗ 夹具没生效（setup） 漂移版本与运行版本相同：[0.1.0]
# install-shape rc=3；同样立即停止
```

两例 smoke 外层均只有 §39 一条失败（前导 ✓21，§39 ✓0 ✗1），没有一串级联。

### needs 生效

`--select 41` 与 `--select 2,41` 都实跑 §2 和 live §41，数字逐段相同：§2 ✓41 ✗0，§41 ✓94 ✗2。未出现缺 brief/config 的级联。

删除 needs 后：

```text
✗ P55 前置缺失：<fixture>/repo/.pi/team/config.sh 不在（§2 没跑；映射表里 41 的 needs 应为 2）
# §41 ✓0 ✗1，ticks 1；总计 ✓21 ✗1，rc=1
```

证明依赖由选段器拉入，缺前提时守卫只报一条，不继续运行后面的 pane 断言。

## Flip evidence

**自己删除且只删除 `drift_skill_copy` 的版本回读断言及其 `fail_setup` 行，保留四空格的 sed 失配现场。** 独立 oracle 检查 exit 3、setup 点名、后续冲突断言不运行、完整结果行不出现。

```text
$ python3 docs/team/reports/P220-verify/setup-oracle.py anchor-miss-39
PASS: setup exits 3
PASS: setup failure is named
PASS: no subsequent conflict checks
PASS: no completed downstream suite
# rc=0

$ python3 docs/team/reports/P220-verify/setup-oracle.py shadow-no-readback-39
FAIL: setup exits 3
FAIL: setup failure is named
FAIL: no subsequent conflict checks
FAIL: no completed downstream suite
# rc=1，影子被独立判据拒绝
```

影子内层实际恢复到五条级联红：默认 init 居然 0、缺 `--force` 出路、漂移 doctor 未 warn、修复后 doctor 行不符、flip ③ 绿侧未 warn；✓96 ✗5。虽然 smoke 聚合后仍只显示一条 §39 红，内层原始日志揭示守卫已失效，不能只比 smoke 总数。恢复全部变更后 install-shape 又是 ✓101 ✗0，scratch `git status` 干净。

## BLOCKED：live §41 的两条既存红

所有正常 live §41 运行均复现：

```text
✗ P55 ④：roster 四态 ① running（证明成立）
✗ P55 ④：机器面断言失败
机器面：p55live 不是 running+live；实际 state='exited', pane='live'
# §41 ✓94 ✗2，SKIP0
```

与 P218 作者报告列出的 P214 老红同名；“老红”的历史归因引用作者报告，**存在与数字由本轮独立实跑证明**。没有自行修改产品判据或 §41 夹具。

额外实跑 FAST 对照，解释 PM 旧记录数字的覆盖边界：

```text
TEAM_SMOKE_FAST=1 … --select 39,2,41 → ✓63 ✗0，rc=0，SKIP1
TEAM_SMOKE_FAST=1 … --select 41      → ✓62 ✗0，rc=0，SKIP1
§41 本身：✓0 ✗0 SKIP1；明确打印 SKIP（FAST 模式）41·p55-pane-留存
```

数字与 `docs/team/reviews/P218.md` 的 ✓63/✓62 相同，但本轮证明这组 FAST 数字**没有执行 live §41**；没有取得 PM 当时的原始运行日志，不推断其具体调用。FAST 不能替代本任务的 live 门禁通过。

**BLOCKED:** PM 应协调 `skills/teamsmith/tests/smoke.sh` 的实现 owner 处置 §41 的 running 夹具与生产状态判据不一致，或明确裁定如何接受既存红。verify 无实现授权，已通过 `team notify verify` 通知 PM。

## Decisions and deviations

- 未跑全量 smoke、§36 或 perf；任务书指定的是容器选段门禁。正常联合选集为 `0,0b,0c,0d,2,39,41`；其余 118 段未跑，完整未选键逐条留在联合日志。不给全量通过结论。
- 作者报告与 PM review 只用于历史对照；没有引用任何通过数字替代自己运行。
- 初轮容器缺 Git identity，有额外提示；正式轮在临时 HOME 下显式配置测试身份，提示消失，同两条 live 红仍在。初轮日志保留在 `initial/`。
- 验证脚本曾因原始输出含截断 UTF-8 字节、FAST 跳过行使用中文括号而中断。只修自己的日志解析并重新校验，原始日志字节不改；最终探针与补充 FAST oracle 完成。所有后台作业均已 harvest。
- 无 push/MR；本仓库 local 模式，分支和顶层报告留给 PM。证据层不提交。

## Suggested next steps

P218 的锚点与 needs 修复可按范围接受；**不能把 live 门禁记录写成全绿**。先由 PM 处置上面的 §41 阻塞，再在干净检出中复跑同一 live 联合选段。
