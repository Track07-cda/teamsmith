# M58 · perf-suite-split 实施（apply）报告

```
task:      M58
agent:     dev2
change:    perf-suite-split（D33：性能判定与正确性门禁分开）
phase:     apply
branch:    task/M58-perf-suite-split-apply（本地；不 push，PM 复验后本地合并）
status:    DONE
date:      2026-09-21
```

**一句话结论**：三条墙钟/CPU 红线（交互首帧、帧装配线、稳态窗格 CPU）**原样搬出**正确性门禁，落在新的独立性能套件 `tests/perf.sh`（前门 `team perf`）；门禁用双向机械守卫盯着「不得回流 / 必须落地」；红线数值（2000ms / 2000ms / 1%）、前提系数（0.75 / 0.25）、中位规则、exit 4 可见跳过、门禁锁记账（queued/ran）一行未动；正确性覆盖（旋钮不进真路径、块隔离、排队记账、缺 GNU time → SKIP）经独立证据包逐条翻转验证。

---

## 1. 交付物（vs base `c598939`）

| 批次 | 文件 | 内容 |
|---|---|---|
| B1 | `tests/perf.sh`（新，555 行） | 套件本体：三条判定、环境自述、exit 0/2/3/4、自检验（不永远绿）、自己的锁 TEAM_PERF_LOCK、对门禁锁只读探活、--host/--container、参考环境不可见时可见降级 |
| B1 | `tests/panel-cpu.sh` | 新增前提自述模式（`TEAM_PANEL_CPU_PREMISE_ONLY=1`）：只打印前提行 + 每个注入旋钮的忽略声明，不起 tmux/node/JS，退出 0 |
| B1 | `tests/panel-cpu-premise.sh` | 给套件机读读数（`== perf-readings ==` 两行；c-healthy 原始日志留存）。四个期望、finding→exit 4、反后门断言**一字未改** |
| B1 | `tests/panel-knobs.sh`（新） | 时间无关的旋钮完整性（d-realpath）：三旋钮被忽略并打印 + premise 行只反映真读数 |
| B2 | `tests/smoke.sh` | §27-d 删掉采样循环/中位/`p27_assembly_judge`/自检/注入/0.75 前提（JSON 形状 + §27-a/b/c 逐字保留）；§35/§36 换成纯逻辑守卫段（FAST 与全量都跑）；§P16 容器不变量对性能套件逐行放行（双向夹具钉住） |
| B2 | `tests/gate-guard.sh`（新） | 封闭集合双向守卫：①smoke.sh 无性能判定标记/时长比较/测量夹具点名；②panel-knobs.sh 在岗且走 premise-only；③perf.sh 带着命名标记 |
| B3 | `scripts/lib/cmd-docs.sh` / `cmd-project.sh` / `team` | `team perf` 前门；`team help` 列出；`team doctor` 增 `perf suite`（present→pass 带命令，absent→warn 带下一步，不硬失败） |
| B3 | `SKILL.md` / `references/{protocol,workflows}.md` | 两条门禁的分工 + 两个可拷贝命令；protocol §9b-2 重写；workflows §E3 |
| B4 | `.github/workflows/gates.yml` | correctness job 一字未改；新 `perf` job 同镜像同 runner，`continue-on-error: true`，无合并阻塞路径 |
| B5 | `docs/team/reports/M58-dev2/pkg/` | 独立证据包（见 §6） |

---

## 2. 需求覆盖表

`verification`（ADDED 4 条）+ `panel`（MODIFIED 1 条）。逐场景的翻转/证据见 §5。

| Requirement | 行为落地 | 证据 |
|---|---|---|
| R1 correctness gate judges correctness only | §27-d/§35/§36 判定全部移走；纯逻辑守卫（gate-guard）驻留；`TEAM_SMOKE_LOCK` 记账一行未删 | 包 §10（守卫双向翻转）、§20（R1 前后红绿）、§60（锁记账 diff） |
| R2 performance suite separate/self-describing/non-blocking | `tests/perf.sh` 三判定 + 自述 + exit 0/2/3/4 + TEAM_PERF_LOCK + --host/--container + 可见降级 | 包 §20③（注入→exit 2 带数字）、§40（A2 降级）、§50（宿主/镜像环境证据）、§70（锁）、§80（缺 GNU time） |
| R3 CI two independent conclusions | gates.yml 两个 job；perf step `continue-on-error: true` | gates.yml 读取 + yaml 解析（§9）；correctness 命令逐字未改（diff 空） |
| R4 discoverable + doctor names next step | SKILL/protocol/workflows 点名；doctor 双态 | `logs/docs-greps.log`、`logs/doctor-{present,absent}.log` |
| R5（panel MODIFIED）Frame assembly…judgment moves | 规格里三红线判定明确归 perf.sh；正确性留在 §27-a/b/c + 旋钮完整性 | 包 §20/§30/§50/§60 |

**场景 → 证据映射**（两个 delta 的全部 scenario）：

- S1.1 慢但正确的控制台让门禁绿 → 包 §20（pre 红 → 分支绿）
- S1.2 墙钟判定回不来/跑不掉 → 包 §10（①塞回红 ②删标记红 ③摘助手红 ④还原绿）
- S1.3 旋钮完整性留在门禁且不测量 → 包 §30-①（泄漏→红）+ §20 绿侧 + `logs/premise-only-timeout10.log`（不起 pane）
- S2.1 慢帧带数字红 → 包 §20③（median 3029ms → RED → exit 2）
- S2.2 忙机器可见 SKIP 不当绿 → perf.sh 自检（注入慢帧+超前提 → SKIP）+ §50（前提不成立时 SKIP）
- S2.3 环境自述随判定 → 包 §50（宿主/镜像）
- S2.4 不属于 review → `logs/review-not-perf.log`（cmd-review.sh 不点名 perf；本项目 TEAM_GATES 是正确性对）+ 守卫方向①
- S2.5 两次性能运行串行 → 包 §70（排队点名持有者；锁未释放时不测量；门禁锁只提示不等）
- S3.1 两条独立结论 → gates.yml + yaml 解析
- S3.2 发版前跑一次并记录 → **PM 交接**（见 §8，`docs/team/PUBLISH.md` 未授权给 dev2）
- S4.1 文档点名两条门禁 → `logs/docs-greps.log`
- S4.2 缺 perf 套件是下一步不是沉默 → `logs/doctor-absent.log`
- S5.4 门禁不能因慢帧失败 → 包 §20
- S5.5 红线是被测量的，不是许诺 → 包 §50（镜像全绿数字）
- S5.6/S5.7/S5.8 前提成立照判/不成立 SKIP（首帧与 CPU）→ panel-cpu-premise a/b/c 期望（exit 0/4）+ perf 自检 + §50
- S5.9 缺 GNU time → 可见 SKIP 不当红 → 包 §80（真 pre-m51 镜像 exit 4）
- S5.10 旋钮不漏进真路径 → 包 §30-① + `logs/premise-only-timeout10.log` + §20 绿侧

---

## 3. 红线数值与语义未动（R6）——核对

`tests/panel-cpu.sh` 相对 pre-change（`fd4fcf6`）**一行未删**（阈值/前提/exit 4 全在原处）；`tests/panel-cpu-premise.sh` 只有新增；性能套件的标记常量与 pre-change 数字一致（`-le 2000`、`0.75`、`0.25`、`< 1`、`exit 4`）；smoke.sh 里 `TEAM_SMOKE_LOCK / LOCK_WAIT / SMOKE_LOCK_WRAPPED / queued / ran=` **一行未删**；§34 的排队/超时断言一行未删。逐字证据见包 §60（`logs/60-r6-diff.log`）与 `logs/60-section.log`。

`refuse`/CAS/写入路径：本次改动**根本没碰** `common.sh`/`outbox.sh`/`cmd-config.sh`/`cmd-watch.sh`/`cmd-agents.sh`（diff 只新增 `cmd-docs.sh`/`cmd-project.sh`，包 §60-④ 断言）。

---

## 4. A1 · 双向守卫真跑（三方向 + 还原）

包 §10（`logs/10-section.log`）。**返工说明（PM 复验 finding F1）**：初版守卫在方向③缺标记时，循环逐条 `bad` 之后**无条件**补一句「带着标记」的 `ok` —— 判定 rc 一直是对的，错的是自述（bad 与 ok 并排）。我自查初版 A1 三向原始输出（`pkg/logs/10-break2-perf-red.log` 历史版），**确有这个并排，当时看漏了**。已修：`ok` 只在**全部**标记都在时打印（flag 汇总，缺哪个 `bad` 点名哪个），并在证据包 §10 加了防回归断言（红日志里不得再出现方向③的 `ok`）。修复后三向输出重贴如下（原始输出进 `pkg/logs/10-*.log`）：

```
控制组（未变异三文件）→ gate-guard rc=0
  ok: smoke.sh 里没有性能判定标记、时长/份额比较，也没有测量夹具的点名
  ok: panel-knobs.sh 存在且走 panel-cpu.sh 的 premise-only 模式
  ok: panel-knobs.sh 不驱赶测量夹具
  ok: perf.sh 带着帧预算 / CPU 份额 / 前提系数的命名单源标记

① 判定塞回 smoke（pre-change §27-d 原文）→ gate-guard rc=1
  bad: smoke.sh 里出现了性能判定标记 / 比较 / 测量夹具点名（9107:# 夹具旋钮…TEAM_SMOKE_LOADAVG…）
  （其余三句 ok 是其它方向的事实陈述，与 bad 不矛盾）

② perf.sh 的命名标记被移除 → gate-guard rc=1
  bad: perf.sh 没有带着标记 PERF_FRAME_BUDGET_MS=2000（判定被删掉了？）
  bad: perf.sh 没有带着标记 PERF_CPU_MAX_PCT=1（判定被删掉了？）
  bad: perf.sh 没有带着标记 PERF_ASSEMBLY_PREMISE_FACTOR=0.75（判定被删掉了？）
  bad: perf.sh 没有带着标记 PERF_FIRST_FRAME_PREMISE_FACTOR=0.25（判定被删掉了？）
  bad: perf.sh 没有带着标记 PERF_CPU_PREMISE_FACTOR=0.25（判定被删掉了？）
  —— 不再出现那句「带着标记」的 ok（F1 已修）

③ 摘掉 tests/panel-knobs.sh → gate-guard rc=1
  bad: 缺 …/panel-knobs.sh（旋钮不得漏进真路径的检查没了）

还原（重新取一份干净三文件）→ gate-guard rc=0（四 ok，同控制组）
```

重跑记录：`== M58-10 结果 ==  ✓ 8  ✗ 0 finding 0`（新增 1 条防回归断言后）。

---

## 5. 环境证据 + A2 降级 + 锁 + 缺工具（原始输出）

**A2 降级**（包 §40，`logs/40-a2-degrade.log`，镜像名打飞）：

```
perf: 参考环境不可用 —— 引擎 distrobox-host-exec podman 在，但镜像候选都不在（TEAM_PERF_IMAGE=teamsmith-gate:definitely-missing）
  构建参考镜像：distrobox-host-exec podman build -f ci/Containerfile -t teamsmith-gate:local .
!!! 参考环境不可用，本次为宿主判定，结论不作为验收依据（exit 4）!!!
  ② 帧装配线：宿主中位 …ms（样本 …）—— 参考环境不可用，不计成结论
```

**锁**（包 §70，`logs/70-section.log`）：等锁超时 → exit 3 且点名持有者；排队的那次在锁释放前没有开始测量（还没打印环境自述），释放后照常跑完；门禁锁被持有时只打印「正确性门禁正在跑（m58-smoke-holder）」照常跑完（性能锁独立）。

**缺 GNU time**（包 §80，`logs/80-missing-time.log`）：`localhost/teamsmith-gate:pre-m51`（M51 之前、真没装 time）里跑套件 → `①③ 面板夹具可见 SKIP（原因：树 CPU 图需要 GNU time）`、② 照测、`exit 4`。

**宿主 / 参考镜像两次运行**（包 §50，`logs/50-host.log` / `logs/50-container.log`）：两例都打印环境自述（host/container、可见核数、cpu.max、loadavg、JS 运行时、tmux、被测版本）+ 三条判定 + 判定汇总；参考镜像那例自报「参考环境：是」。本次参考镜像实测 **全绿**（见 §9 的容器 accept 输出：首帧 209ms / 装配 457ms / CPU 0.98%）。

---

## 6. 独立证据包

`docs/team/reports/M58-dev2/pkg/`：`run.sh`（入口，`M58_SECTIONS="10" ...` 可只跑一节）+ `lib.sh` + 8 节（10 守卫翻转 / 20 R1 翻转 / 30 R3 三翻转 / 40 A2 降级 / 50 环境证据 / 60 R6 对照 / 70 锁 / 80 缺工具）。纪律：全部变异发生在 `/tmp` 的 clone（`--no-local`，不动调用者的 checkout）；不依赖实现自带的翻转夹具；每节打印 `== M58-<n> 结果 ==` 行，finding 不算失败、脚本级 ✗ 才算。

重跑入口（PM / 复验方）：

```bash
bash docs/team/reports/M58-dev2/pkg/run.sh            # 全部（约 45 分钟）
bash docs/team/reports/M58-dev2/pkg/run.sh --only 10  # 单节
```

本次全节结果：`10 ✓7 ✗0 · 20 ✓6 ✗0 · 30 ✓13 ✗0 · 40 ✓7 ✗0 · 50 ✓9 ✗0 · 60 ✓13 ✗0 · 70 ✓10 ✗0 · 80 ✓6 ✗0`。

---

## 7. R1 翻转（同一条注入，前后两处）

包 §20（`logs/20-pre-red.log` / `20-branch-green.log` / `20-perf-red.log`）：

- **pre-change 树**（`git archive fd4fcf6`）+ `TEAM_SMOKE_FIXTURE=1 TEAM_SMOKE_FRAME_DELAY_MS=2600` → FAST 门禁非 0，红点在 `27-d 装配红线`。
- **分支树** + 同一个注入 → FAST 门禁 **绿**（门禁不再判时长；§35 守卫段在且绿）。
- **分支树** + `TEAM_PERF_FIXTURE=1 TEAM_PERF_FRAME_DELAY_MS=2600`（参考镜像）→ **exit 2**，判定带数字：

```
② 帧装配线：5 次采样 3050, 3029, 3031, 3026, 3025 → 中位 3029ms ≤ 2000ms ｜ 0.75 × 32 = 24.00 成立（loadavg 4.47） → RED
== 结果 ==  ✓ 2 绿  ✗ 1 红  SKIP 0 没结论（自检失败 0）；参考环境：是
```

---

## 8. PM 交接（不在 dev2 的授权范围）

- **`docs/team/PUBLISH.md`**（PM-owned）：R4/3.6 的发版前性能记录清单需要它写明 `bash skills/teamsmith/tests/perf.sh --container`（参考镜像）与数值记录位置。任务书把它标为「PM edits or grants」，请 PM 补这一句（或显式授予后由 dev 代理）。
- 验证方复验时建议先跑 §6 的 `--only 10,20`（守卫 + R1 双向翻转）作快检。

---

## 9. 验收命令（真跑）

见 `logs/acceptance-1-openspec+fast-smoke.log` / `logs/acceptance-perf-and-container-gate.log`：

1. `openspec validate --all --strict` → `Totals: 18 passed, 0 failed (18 items)`
2. `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` → `== 结果 ==  ✓ 2204  ✗ 0`（绿；26 个真进程段按 FAST 纪律跳过）
3. `bash skills/teamsmith/tests/perf.sh --host` → **exit 4（可见 SKIP，非参考环境）**，自检 16/16 过：

```
  模式          : host（--host：非参考环境）（非参考环境：结论不作为验收依据）
  可见逻辑核数   : 32（nproc）｜ CPU 配额 : max 100000 ｜ loadavg (1m) : 4.28
  被测版本       : d394f69（…/.worktrees/dev2）
  ① 交互首帧：2276 2276 2287 -> median 2276 (budget 2000ms) ｜ … → SKIP
  ② 帧装配线：5 次采样 395, 410, 395, 411, 402 → 中位 402ms ≤ 2000ms ｜ … → OK
  ③ 稳态窗格 CPU：… median 0.50% … → SKIP
== 结果 ==  ✓ 1 绿  ✗ 0 红  SKIP 2 没结论（自检失败 0）；参考环境：否
```

4. `bash skills/teamsmith/tests/perf.sh --container` → **exit 0，三条全绿**（`localhost/teamsmith-gate:local` = ci/Containerfile 钉死镜像）：

```
参考环境：镜像 localhost/teamsmith-gate:local（引擎 distrobox-host-exec podman）
  模式          : container（参考环境：钉死镜像）（参考环境）
  JS 运行时      : /usr/local/bin/node v24.19.0 ｜ tmux : /usr/local/bin/tmux tmux 3.7b
  被测版本       : d394f69（/work）
  ① 交互首帧：1852 1954 1956 -> median 1954 (budget 2000ms) ｜ … → OK
  ② 帧装配线：5 次采样 487, 419, 421, 417, 429 → 中位 421ms ≤ 2000ms ｜ … → OK
  ③ 稳态窗格 CPU：… median 0.00% … → OK
== 结果 ==  ✓ 3 绿  ✗ 0 红  SKIP 0 没结论（自检失败 0）；参考环境：是
```

5. 全量门禁在钉死镜像里（`podman run --rm --userns=keep-id --pid=host --cgroups=enabled -e HOME=/tmp -v <worktree>:/work:ro -v <主仓>:<主仓>:ro -w /work localhost/teamsmith-gate:local bash -c 'openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null'`）→ `Totals: 18 passed, 0 failed` + `== 结果 ==  ✓ 2684  ✗ 0`（smoke 全绿）。

---

## 10. 提交（本地；不 push）

```
dd546bd test(perf): B1 — the three performance judgements move into tests/perf.sh
126e3af test(smoke): B2 — the correctness gate judges correctness only
928e1c2 feat(perf): B3 — team perf front door, doctor line, docs
2fe6aff ci: B4 — correctness and performance are two independent conclusions
07c13fa fix(perf): only --in-container counts as the reference environment
1605bc4 fix(perf): mount the main repository in the reference container
1346aa8 docs(team): independent evidence package
c4f8611 test(perf): lock semantics without exec (bounded wait leaves a readable line)
d394f69 fix(perf): a lock-timeout exits 3 as documented
```
