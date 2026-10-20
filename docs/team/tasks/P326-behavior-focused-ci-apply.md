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
