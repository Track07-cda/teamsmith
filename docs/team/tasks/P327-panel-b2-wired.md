# P327 · 让写信面的夹具真的跑起来：把固定 sleep 换成既有有界等待，并接进一个既有门禁段

task: P327
agent: dev3
phase: apply
category: code
change: -
specs: verification#The gate judges behaviour only, and never reports a skip as a pass
anchor: none (infra) — 夹具的等待方式与门禁接线，不改任何产品行为
deltas: -
branch: task/P327-panel-b2-wired
deps: P326 已并入 main（`smoke.sh` / `section-paths.tsv` 单写者）

## 问题（P318 第 1 轮实测，PM 已复核）

`skills/teamsmith/tests/panel-b2.sh` 1236 行、11 个场景，守的是写信面（草稿、键位、多行、粘贴、编辑器接力、回执）——其中 `cursor`/`keys`/`clipboard` 三组对应 **V33、P20、P249** 三次已点名事故。

但 `grep -n 'panel-b2' skills/teamsmith/tests/section-paths.tsv skills/teamsmith/tests/smoke.sh` **零命中**：它不在任何门禁段里，也不在 CI 里；改它也只会命中两个扫 `tests/` 树的 lint 段。也就是说，那批事故墓碑今天挂在一个从不执行的夹具上。

它慢的原因很具体：脚本里大量固定 `sleep`（`sleep 1`、`sleep 0.4`、`sleep 1.4`、`sleep 0.8`……），一处一处串起来就是分钟级。这部分不是必要成本。

## 要做的（两件，都不许新增框架）

1. **等状态，不等时间**：把固定 `sleep` 换成**既有**的有界等待。仓库里已经有 `skills/teamsmith/tests/lib/bounded-spin.sh` 与 `lib/pty-wait.sh`（先读它们的契约再挑一个，能力不够就在报告里说明缺什么，**不要**新建第二个等待库）。判据是「等到那件事为真、或到上界」，例如等面板画出目标行、等草稿行出现、等编辑器返回——不要等「大概够了」。
   - 允许保留的：夹具自己的 bootstrap（`-c 'sleep 600'` 那种占位进程）、以及那些**没有可观测状态可等**的地方；每一处保留都要在报告里写一句为什么等状态等不到。
   - 不许把断言放宽、不许删场景、不许把上界设成分钟级来「稳过」。
2. **接进一个既有的段，不新增段**：挑现成的面板段（§26/§27/§28/§38 里最贴近写信面的那个，先读它们的正文再决定），把 `panel-b2.sh` 作为**该段内的一条断言**接进去（成功→`ok`，失败→`bad` 并打印它的尾部）。`section-paths.tsv` 里往那一行的 patterns 补 `panel-b2.sh`（**不新增行**）。净零：这条接线替掉的是「这个夹具从不执行」，没有新增检查器。

## 必须交的证据

1. **接线真的生效**：`bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/tests/panel-b2.sh` 必须把那个段选回来（贴输出）；`bash skills/teamsmith/tests/smoke.sh --select <那个段>` 里必须出现该断言的真实读数（贴原始行与返回码）。
2. **反例**：在私有副本里把 `panel-b2.sh` 的一条**关键**断言改坏（例如让草稿不被保留），同一次 `--select` 必须**红**并点名；证明接线不是「跑一下就算过」。
3. **耗时对照**：改前改后各跑一次全场景，贴两边的实际用时（只作参考值，不作判据）。目标是把它从分钟级降到可接受范围；**达不到就如实写**，不许为上界或断言作弊。
4. **场景与断言一条不少**：改前改后的场景名集合与断言行集合 `diff`（贴结果），只能有「等待方式」的差异。
5. 轻量收口：`bash -n`、`section-select.sh --check`、`openspec validate --all --strict`、账本禁令固定验收行、`git diff --check`。

夹具照旧跑在**私有 tmux server**（`-L …`）与私有夹具项目上；实验期间先确认 `ps` 里没有别人的 `smoke.sh`（不要抢机器级门禁锁）。

## 边界

- 写集：`skills/teamsmith/tests/panel-b2.sh`、`skills/teamsmith/tests/smoke.sh`（**只有接进去的那几行**）、`skills/teamsmith/tests/section-paths.tsv`（**只改既有那一行的 patterns**）、`docs/team/reports/P327-dev3.md`。
- 不碰产品实现、不新建夹具/等待库/门禁段、不动任何时限与预算、不改 `panel-p21.sh`（它已由 §38 执行）。
- 如果读了映射表发现更适合承接的是另一个段，按证据选，并在报告里写明为什么不是 §26。
