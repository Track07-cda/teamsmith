# M64 · perf-suite-split 独立验证（verify 阶段）

```
task:   M64
agent:  verify
issue:
change: perf-suite-split              # apply 已合并：7135095（apply 作者 = dev2，故验证必须换人）
specs:  verification#The correctness gate judges correctness only / verification#The performance suite is separate, self-describing and non-blocking / verification#CI runs the two gates separately and performance does not block / verification#The two gates are discoverable, and the doctor names the next step / panel#Frame assembly is asynchronous, cached and never blocks input
phase:  verify
anchor: change
deps:   M58（apply，已合并 7135095）· M57（propose，已合并）
status: todo
budget: 一个工作块（只写复验证据与报告，**不改实现**）
```

> 本地模式：不 push；只写 `docs/team/reports/M64-verify.md`（+ `docs/team/reports/M64-verify/` 证据目录）。

**为什么是你**：这条 change 的 apply 是 **dev2**（M58）。按 D31「不许自己验自己（按 change 判定）」，验证必须换人。

## 要对抗性验证的五条（每条给可复现命令 + 原始输出）

1. **R1 正确性门禁不再判性能**（本 change 的核心承诺）：
   ① 静态：`smoke.sh` 里**不得**出现性能判定标记 / 时长-份额比较 / 测量夹具点名（自己 grep，贴结果）；
   ② 动态：**注入一个"慢但正确"的帧延迟**，让全量门禁跑完一遍 → **必须仍然全绿**（这是 D33 的可证伪判据）。
   （注意：`TEAM_SMOKE_FRAME_DELAY_MS` 这类旋钮现在归性能套件；你要找的是**能影响面板但只让它变慢**的注入路径，
   或退一步：证明 §27-d/§35/§36 的判定确实不在门禁里，并给出"若在，会红"的反证。）
2. **R2 性能套件独立、自述、可判红**：`bash tests/perf.sh --host` 与 `--in-container` 各跑一次，贴**环境自述**与判定行；
   人为造一次越线（夹具旋钮/延迟）→ **必须判红并打印数值**；没有参考镜像时 → **可见降级（exit 4）**，不许静默按宿主结案。
3. **R3 守卫双向、不可绕过**（三条都要**自己变异**跑）：
   ① 把 `pre-change` 的 §27-d 判定塞回 `smoke.sh` → `gate-guard.sh` 红并点名行号；
   ② 从 `perf.sh` 移除/改名任一命名标记 → 红并点名缺哪个；
   ③ 摘掉 `tests/panel-knobs.sh` → 红；各自还原后 → 绿。
   另外验证**旋钮完整性检查仍在门禁里且是时间无关的**（`✓ 9 ✗ 0` 那一段）。
4. **R4 CI 两条独立结论**：读 `.github/workflows/gates.yml`，确认性能是**独立 job**、`continue-on-error`（红可见但不拦合并），
   且**发版前的运行被点名**；并说明"如果 perf job 红了，合并会不会被挡"（按文件回答，不要凭印象）。
5. **R5 文档与可发现性**：`team help` 里有 `team perf`；`references/` 给出本机/容器两次运行的可复制命令；
   性能判定被跳过时 `doctor`（或 digest/panel）给一句可执行的下一步。逐条贴命令与输出。

## 已知事项（别重复报）

- 复验期间发现的 **F1**（`gate-guard.sh` 缺标记时同时打印 `bad` 与 `ok`）**已由 dev2 修复**（tip 含 `3968e9c`）；
  PM 已复跑同一变异确认只剩 `bad`。
- 宿主上首帧判定**仍会红**（这台机器贴着 2000ms 线）；**这是设计内的**：宿主不是参考环境，`perf.sh` 以 exit 4 表示"无结论"。
  你要验证的是**这个语义成立**，不是"宿主必须绿"。
- `panel-p21.sh` 的 pty 夹具级联假红正在被 **M59** 修（dev3）；若你在性能套件里遇到面板夹具大面积红，先看是否与它相关。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
bash skills/teamsmith/tests/gate-guard.sh
bash skills/teamsmith/tests/perf.sh --host
bash skills/teamsmith/tests/perf.sh --in-container      # 需要镜像：见 ci/Containerfile
bash skills/teamsmith/tests/smoke.sh </dev/null         # 全量正确性门禁
```

## Boundaries

- **不改实现**（`scripts/**`、`tests/**`、`extension/**`、`ci/**` 一律不改）；发现缺陷 → 写清楚交回 PM。
- 变异只许在**临时副本**里做，并保证还原后 `git status --porcelain` 干净。
- 不 push；不改 `docs/team/**` 里 PM 的文件。
