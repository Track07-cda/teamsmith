# P326 · 让 CI 判已交付的行为：地板声明、路径原始字节、探针去重、规格与文档对齐

task: P326
agent: dev
phase: apply
category: code
change: behavior-focused-ci
specs: verification#A changed-path list selects the sections to run, or the full suite
deltas: verification
branch: task/P326-behavior-focused-ci
deps: P324 已并入 main（`gates.yml` / `smoke.sh` 写权已归回）；P325 rev 2 的 PM 预审判 **ACCEPTED**（`docs/team/reviews/behavior-focused-ci-proposal.md`）

## V70 后的定点返修（最新裁定，优先于下文原始验收计划）

V70 为静态审阅交付，不是本变更行为验收通过。依据 `docs/team/reports/V70-dev2.md`，本轮仅做以下差异：

- 先读最新线程和 git status/log；保留既有工作。在自己的任务分支正常 merge main（不 rebase/重置），带入 P318 的真实 §58 修复与 P331；依据是这两处具体字节变化，不是要求追齐几十笔账本提交。
- 明授 `smoke.sh` 的11c轮询修复：先完整取得 roster 输出并判断真实返回码，再用 Bash 内部匹配，不再把生产者接到 `grep -q`。保持原15条产品断言和有界退出，不把真实续跑行为移出floor；不靠1500改25或“5秒内”换绿。不可靠管道是静态确认的缺陷，但本次986秒是否由SIGPIPE引起尚无逐轮退出码证据，不写成已复现根因。
- probe 的同树同状态合并保持。**每次真实 nest 调用保留一次整体退出码断言**，不再把同一 `$?` 反复冒充每个段的结果；各段自身的判据继续按其行读取。不可照抄V70“删掉5条”而把整个run的失败也漏掉。
- CI路径没有真实承接者，不能空补映射。允许将已运行过的E10实际workflow命令/argv检查固化为一个小型 `tests/workflow-entry.sh`，由现有36段调用并可单独执行；只复用现有E10的有效基点与特殊字符、无效基点回退、底层执行失败传播三类行为，不另造解析框架、测试矩阵或门禁段。把该脚本与 `gates.yml` 映射到36，补齐必要拷贝依赖；产品面检出不含CI源码时按既有缺前提语义如实披露，不伪造通过。**净零**：用上述实际入口检查替代probe合并后重复的整批退出码检查，本轮不新增通用检查器。
- `--paths` 与 `--floor --paths` 的未知路径/无有效基点 FULL 兜底均不改，不给 `.github/**` 加豁免，不把FULL改成floor。
- 修SKILL残留的performance red lines，核对verification delta的Migration：退役4个premise场景，保留的通用不可判定语义正确指回既有要求。仅此文字对齐，不改选择器契约。tasks按实际修改，不把未跑到的36写成绿。

写集在下文基础上仅扩大：11c、36调用与必要依赖声明、`tests/workflow-entry.sh`、36行patterns、上述delta文字勘误。OWNERSHIP已同步。不得改P318/P331文件，也不新增时间阈值、产品测试钩子或第二套等待框架。

本轮只跑新workflow检查、修复后的11c现有选段一次及轻量语法/声明/规格检查；原C1/C2已成立且不受差异影响的证据复用。**不再跑容器、floor整体、36整段、checkout-shape-probe整套或路由变异**。新workflow检查直接复用已有E10，不为它再建变异矩阵。复核固定树的具体入口由PM随后统一安排；最终整体验收仍只安排一次、真实clone、外部45分钟停止，不把floor与floor+paths各跑一次，也不声称此前截断批次通过。

返修后冻结代码与报告，独立验证改变部分。按现有模型与SID恢复，不重新选模型。

## 这是哪一步

`openspec/changes/behavior-focused-ci/` 的 **apply**。提案（rev 2，`90a1be402610`）已由 PM 审过并附六条条件；本任务按提案的 A/B/C/D 四张单落地，**不是重新设计**。规格文本改动只允许 `openspec/changes/behavior-focused-ci/specs/verification/spec.md` 自己（它已写好），实现不得改写它的意图。

## 写集（逐条明授，别的文件不要动）

- A：`skills/teamsmith/tests/section-paths.tsv`（表头 `# gate-self-check:` 一行；`58` 行的 `needs` 改 `-`）、`skills/teamsmith/tests/section-select.sh`（装载 + `--check` 新规则 + `--floor`）、`skills/teamsmith/tests/smoke.sh`（`--floor` 透传；**披露行不许改**）
- B：`.github/workflows/gates.yml`（宿主侧 `git diff --name-only -z` → bash 数组 → 容器里 `smoke.sh --floor --keep --paths "$@"`；不动 `timeout-minutes: 60`、不动 `if: always()` / `if: failure()`、不动 perf 步的独立与非阻塞）
- C：`skills/teamsmith/tests/checkout-shape-probe.sh`（5 处同树同状态的嵌套合并）、`skills/teamsmith/tests/perf.sh`（只修那一行过时注释）
- D：`skills/teamsmith/SKILL.md`、`skills/teamsmith/references/protocol.md`（旧性能红线/负载前提）
- `docs/team/RELEASE-PUBLIC.md`：**仅**「发布前性能读数的去处」那一条（PM 明授；其余 `docs/**` 不归你）
- `openspec/changes/behavior-focused-ci/tasks.md`：按事实勾选
- `docs/team/reports/P326-dev.md`：交付报告

**不许碰**：`skills/teamsmith/tests/signal-gate.sh`、`tests/team-bg-stop.sh`、`tests/panel-b2.sh`（P318 第 1 轮正在这些文件上）、`skills/teamsmith/scripts/**`（本 change 没有产品改动）、版本号、发布工具。

## PM 写死的六条条件

1. **墙钟上限**：最终 C4（钉死镜像里 `smoke.sh --floor --paths <本 change 触碰的路径> --keep`）若超过 **45 分钟** → 停手，写 `BLOCKED:` 并给分段读数。**不许**抬 60 分钟上限，**不许**删断言换绿，**不许**把慢段悄悄挪出地板。
2. **反向判据**（比提案 C2 更强，必须全做，纯逻辑、不起容器）：`# gate-self-check:` 行里**每一个** key，用它自己的 patterns 造一次路径输入 → 必须把该段选回来；从行里删一个 key → 那段回到地板（`61b` 也要试）；写不存在的 key / 重复 key / 点名前导段 → `--check` 红并点名是哪一条。
3. **缺行与空行语义**：整行被删 → 地板 = 全套（安全方向），用一次纯逻辑证据钉住；**不许**出现「行在但为空 → 只跑前导段」的静默变窄（设计写的是 `die`，实现要保持并证明）。
4. **守卫净零**：这是减法（退场 4 条要求；CI 不再无条件跑 1431 秒自检与 4946 秒矩阵）。**不许**顺手新增检查器、预算表、调度器、第二个非阻塞步；perf 仍 `exit 0/3`、只参考。
5. **不改断言**：C1/C3 的红侧只能来自产品/夹具的真实破坏；`smoke.sh` 的 `decision=` / 未跑列表 / `== 选段结果 ==` / 不写「全绿」这些披露行一个字不动。
6. **`--floor` 与 `--select` 互斥**、地板为空要 `die` 并点名「空地板」；`--paths` 单独使用时语义**逐字不变**（`NONE`/`RUN`/`FULL`）。

## 必须交的证据（报告里逐条给命令与原始尾部，不要只给结论）

- C1：`58` 行改 `-` 后 `--select 58` = `keys=5`、`decision=RUN`，`smoke.sh --select 58` 的 58 段计数与带闭包时相同；反例 B：去掉 `15b` 的树上 `--select 17` 必须红（证明 `needs` 不是橡皮章）。
- C2 + 条件 2/3 的全部纯逻辑输出（含删行、空行、未知键、重复键、前导键、每个 self-check 键自选）。
- C3：容器里一次 `--floor --paths <干净树>` → 退出 0 且尾部有 `decision=`、未跑列表、`== 选段结果 ==`；再植入一个地板段的产品失败 → 非零。
- 路径形状：含**换行**、**引号**、**反斜杠**的文件名各一次，逐字节到达（纯逻辑）。
- C4：最终一次整体运行的墙钟与尾部；报告里明写「61b 与其它重段不在其中」。
- `--check` 在**改坏的表副本**上必须红（例如把某行重复声明进 `gate-self-check`）。

## 验收命令（交付前在你自己树上跑）

```bash
bash skills/teamsmith/tests/section-select.sh --check
bash -n skills/teamsmith/tests/section-select.sh && bash -n skills/teamsmith/tests/smoke.sh && bash -n skills/teamsmith/tests/checkout-shape-probe.sh
openspec validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```

选段请用：`bash skills/teamsmith/tests/section-select.sh --paths <你改的路径…>` 拿段号，再 `smoke.sh --select <段号>`；**不要**为了「证明没坏」跑整套（交付门槛是 C4 那一次）。TMPDIR 用磁盘（`/var/tmp/...`），私有锁路径，跑完清自己的根。

## 交付格式

报告 `docs/team/reports/P326-dev.md`：抬头 `status:` / `time:` / `branch:` / `tip:`；先写**结论**（六条条件逐条说「做到 / 没做到」，做到的给命令与读数）；再写 C1–C4 与路径形状的原始输出；最后写**未观测边界**（真 GitHub CI、非 FAST 档、以及你判断有风险但没验的假设）。冻结后通知 PM，由另一个席位独立复验。
