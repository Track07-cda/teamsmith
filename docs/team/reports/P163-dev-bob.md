# P163 · `delivery-truth` 的两条 finding：配方重置现场 + 钉版本与 1.0.0 真帧用例

agent: dev-bob · status: DELIVERED（本地分支，不 push；PM 复验后本地合并） · time: 2026-10-02
branch: `task/P163-apply` · base: `5b0a9493`（= 派单时的 main） · change: `delivery-truth`（phase: apply）
授权路径：`skills/teamsmith/tests/**`（含 `tests/fixtures/**`）· `docs/team/reports/P163-dev-bob/**`

## 结论

两条 finding 都落地、都带**双向证据**（红侧在自己这一轮真跑出来的，不是引用）：

1. **F1 · 配方重置现场**：真 Pi 配方提升进夹具 `skills/teamsmith/tests/fixtures/delivery-truth-real/`，
   每次运行先 `rm -rf` 自己的 case 现场 + 写 `run.json` 运行戳；`scenario.sh` 在判据读的事件文件第一行写
   单次 `run_start` 标记；`judge-second.py` 只认「清空过、单次运行、判据版本」的现场，旧现场/跨次累积/
   旧文件/observation 一律**明确报错 exit 2**。
   **红侧实测**：把 P157 配方里的重置与标记拿掉（= P147 作者配方在 0.99.2 下的行为），同一 case 连跑两次 →
   旧判据 `second_received 1 → 2`（`settled 3 → 6`，第二次追问被算成第一条）✗；同一份新配方连跑两次 →
   两次都是 `second_received=1`、`settled=3` ✓。
2. **F2 · 钉版本 + 1.0.0 真帧**：判据版本钉死容器内 **0.99.2**（仪器自己校验 `run.json.pi_version` 与现场
   `pi-version.txt`）；宿主路线（当前 1.0.0）标 `mode=observation`，判据**拒绝**给它出判据。1.0.0 真帧
   `frames/pi-1.0.0-git-error-in-box.txt`（逐字节 = 验证者存的 `P157-verify/logs/tmux-p157-after-dirty/second-before.frame`）
   进夹具，新增 `delivery-truth.sh --section foreign`：框内那行非人类文本 → **零按键、帧逐字节不变、
   消息不丢**（活动队列条目 + durable 收件箱都有全文）、**可见报告**（queued + 没写任何键 + 恢复命令
   `outbox list` + `docs/team/inbox/dev.md`）、绝不出现「已确认送达」。同一份帧、光标落在上边框
   （`tmux cursor_y` 是 0-based，少加一的那条误读路径）→ `held/geometry-untrusted` + 非零退出 + 恢复命令，
   仍然零按键、仍然不丢。

**关于「held」一词的如实交代**：brief 与 P157 评审用「扣住（held）」描述产品行为，我把这句话对着证据核了一遍 ——
**真 1.0.0 现场（`P157-verify/logs/tmux-p157-after-dirty/`）产品实际答的是 `queued`，不是 `held`**：
`second-say.txt` = `✓ queued for p138:dev: P138-SECOND-…（目标输入框里有草稿：没有写任何键；条目已入
state/outbox/，清空后自动投递）` + 「原因/条目：team outbox list ｜ 兜底：消息已在 docs/team/inbox/dev.md」，
`outbox-after-say.txt` = `队列 1 条（held 0）` 且条目 `[queued]`。所以这份夹具钉的是**产品真实契约**：
「可信非空读」→ `queued`（exit 0，不打字、不入框、可见报告、留在队列/账本）；`held`（非零退出）是
**几何不可信 / 停滞**的契约（`foreign` 段里同一帧的 off-by-one 读法就走到这条）。两种都是「扣住不投递 +
可见报告」的如实表达；我**没有**改产品去迎合措辞（grant 也不含 `scripts/**`），也**没有**把 `queued` 写成 `held`。

## 提交

| commit | 内容 |
|---|---|
| `8373c971` | 真 Pi 配方提升进夹具：现场重置 + `run.json` 运行戳 + 单次标记 + 严格判据（F1、F2①） |
| `f519d655` | 1.0.0 真帧进 `tests/frames/` + `delivery-truth.sh --section foreign` + smoke/路径表描述同步 |
| `9e7ae21c` | 门禁两处红修掉：真帧声明进 §46 的 P86 光标表（18 → 19），夹具临时根进 `teamsmith-` owned 家族 |

## 红 → 绿（翻证据）

### F1：累积 vs 单次（真 Pi 0.99.2，容器内、`--network=none`、回环 mock 模型）

旧形状配方（P157 配方去掉重建重置与标记；`legacy/run-case-old.sh` 由 `pkg/real-runs.sh` 现场重建）：

```text
===== step 2: 旧形状 run 1 =====
tmux-p157-legacy-accumulate: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1
PASS second say delivered          judge_rc=0
===== step 3: 旧形状 run 2（同一 case，不重置现场） =====
tmux-p157-legacy-accumulate: second_received=2 backend=0 backend_requests=2 settled=6 settle_editors_empty=1
FAIL second say stranded despite idle empty editor          judge_rc=1
===== step 4: 新判据对旧（累积）现场：必须明确拒绝 =====
judge-second: 拒绝出判据（tmux-p157-legacy-accumulate）：现场没有 run.json 运行戳（旧现场 / 没跑过 run-case.sh；判据不猜）
judge_rc=2
```

新配方（`P163_EVIDENCE=… run-case.sh tmux-p163-after-0992-dirty HEAD 0 0.99.2`，`P138_SECOND=1 P143_DRAFT=1`）：

```text
run 1: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1 · PASS · judge_rc=0
run 2: second_received=1 backend=1 backend_requests=1 settled=3 settle_editors_empty=1 · PASS · judge_rc=0
```

反向（判据必须拒绝「不是单次运行」的现场）：

```text
accumulated-synthetic: 拒绝出判据：dev-events.jsonl 的单次运行标记=['6eb6c7d9de9b', 'deadbeefcafe']，与 run.json.run_id=6eb6c7d9de9b 不一致（现场跨次累积？）  judge_rc=2
stale-synthetic:       拒绝出判据：现场里有早于本次运行的文件 old-leftover.txt（没有清空现场）  judge_rc=2
observation-synthetic: 拒绝出判据：run.json.mode='observation' 是人工观察（host 路线），不作为判据  judge_rc=2
```

### F2③：静默变异 → 「可见报告」必须红

`--section foreign --mutations` 的绿侧 12 条 + 红侧 4 条（完整输出 `logs/foreign-mutations.txt`；这一次是**宿主**上的
夹具运行 —— 假 tmux、私有临时根、不碰真 session；容器内的同一段见 `--select 57` 与合并快照 FAST，113 ✓）：

```text
✓ 1.0.0 真帧：team say 一个键都不发（异物绝不打字进去）
✓ 1.0.0 真帧：say 之后输入框字节不变
✓ 1.0.0 真帧：可见报告 = queued + 没写任何键 + 恢复命令 outbox list + durable 收件箱指针
✓ 1.0.0 真帧：绝不出「已确认送达」（queued ≠ 送达）
✓ 1.0.0 真帧：消息不丢（活动队列条目 + docs/team/inbox/dev.md 都有全文）
✓ 同帧 off-by-one（光标在上边框）：held/geometry-untrusted + 原因/恢复命令，且不承诺自动投递
✓ 同帧 off-by-one：零按键 ／ held 也不丢（durable 收件箱有全文）
✓ 红侧（静默排队）：可见报告 → 红（判据钉住的正是这个决策点）
· finding: 变异进程原始输出=[]（对照上一条 ✓ 的正常输出）
✓ 红侧对照：静默变异下仍零按键（安全断言不受影子影响）
✓ 红侧对照：静默变异下消息仍在队列（红的是报告，不是丢失）
✓ 红侧：变异只动副本，生产 cmd-agents.sh 的 sha 不变
== 1 foreign 结果 == ✓ 16 ✗ 0 ==
```

变异体 = 只把产品 `cmd-agents.sh` 的 `queued)` 分支两行报告删掉（**静默排队**：消息仍进队列、仍零按键，
但人看不到任何原因/恢复命令），副本只拷 `team`+`lib`+`shim`（约 1 MB，且**不**动生产文件的 sha —— 那条
断言就是防「变异写回生产」的）。静默变异下「可见报告」确证翻红，而零按键与「不丢」保持绿：这一段钉住的
正是那一个决策点。

## 门禁（全部容器内、独立仓库，`pkg/gates.sh`）

| 命令 | 结果 | 原始输出 |
|---|---|---|
| `openspec validate --all --strict` | exit 0，**22 passed / 0 failed** | `logs/openspec.txt` |
| `delivery-truth.sh --section all --mutations` | exit 0，七段 **113 ✓ / 0 ✗**（frames 25 / drafts 35 / foreign 51 / queue 76 / receipts 88 / notify 103 / panel 113 累计） | `logs/delivery-truth-all-final.txt` |
| `smoke.sh --select 57` | exit 0，**✓22 ✗0**；§57 用时 **32s**（预算 110s，实测带 26s —— 记录，不是判定） | `logs/select57.txt` |
| `TEAM_SMOKE_FAST=1 smoke.sh`（首次，分支 HEAD=`f519d655`） | **✓3652 ✗3** —— 三条红逐条归因见下；其中两条是我的、已修并复验，第三条是基线红 | `logs/fast.txt` |
| 合并快照（`15fe2a96` = 我的分支 + main `47595e52`）openspec / `--select 57` / FAST | 全绿：**22/0** · **✓22 ✗0** · **✓3780 ✗0（123 段收口，SKIP37）**；`36⑧` 探针 `ok 91 bad 0` | `logs/merged-*.txt` |
| `smoke.sh --select 40,46`（修后复验） | exit 0，**✓280 ✗0**（§40 lint 14 ✓；§46 P86 语料 42 ✓，修前 41/1✗） | `logs/select-40-46.txt` |

三条红的归因（首次 FAST，全部逐条核过）：

1. **我的** · `40 lint 有 finding（rc=1）：fixtures/delivery-truth-real/scenario.sh:29: 写死绝对路径（/tmp/p138.XXXXXX）`
   —— 修：`mktemp -d "${TMPDIR:-/tmp}/teamsmith-p163-real.XXXXXX"`（owned 家族口径）；`tmp-hygiene.sh --lint` 现在
   「检查了 15 个 mktemp -d 根模板 …… 全部合规」，容器里 `--select 40,46` ✓280 ✗0。
2. **我的** · `P86 语料口径：全部已存帧都声明了光标行（…）（期望 [none]，实际 [ pi-1.0.0-git-error-in-box.txt])`
   —— 修：§46 的 `p86_cursor()` 加 `pi-1.0.0-*.txt → 29`，计数 18 → 19（8 真帧 + 8 p78 + 3 p86），同一次复验绿。
3. **基线红，不是我的** · `36⑧ 产品面检出探针有失败（1 条）` /
   `bad: ⑨ 牙齿一的前提不在：树里的 smoke.sh 没有 P162 的 tmux() 包装，这条牙齿会因别的原因通过`
   —— 这是 **P180 的已知后果**：P180 把包装本体搬进 lib（smoke.sh 只调 `tmux_iso_install_suite_guards`），
   而基线里 P173 的探针前提还按字面 `tmux() {  # P162` 找它。证据：
   `git show 5b0a9493:skills/teamsmith/tests/smoke.sh | grep -c 'tmux() {  # P162'` → **0**（派单前就是这样）；
   main 的 P188（`8c424ad3`）已重写这条前提；PM 自己的 main 提交 `5f2afb58` 也写明「P180 temporarily disarmed
   the product-face tooth」。**我没有动这条探针**（它属于 P188 的范围，我的分支不碰 main 的 P188 改动）。

**合并后的整套 FAST**（PM 合并时才是最终形态）：在**一次性 scratch clone** 里把 main 合进我的分支
（`git merge` rc=0、零冲突、无 `git status` 未合并项），再用合并快照跑整套 FAST：

```text
merged snapshot: 15fe2a96 9e7ae21c 47595e52 Merge remote-tracking branch 'origin/main' into merge-check
merged: openspec=0 select57=0 fast=0
Totals: 22 passed, 0 failed (22 items)                     ← openspec validate --all --strict
账本自查： 5 段收口 · 增量 ✓22 ✗0 SKIP0 ｜ 结果行 ✓22 ✗0 —— 一致      ← --select 57（#5 §57 用时 30s，预算 110s）
账本自查： 123 段收口 · 增量 ✓3780 ✗0 SKIP37 ｜ 结果行 ✓3780 ✗0 —— 一致  ← FAST 整套
== 结果 ==  ✓ 3780  ✗ 0
✓ 36⑧ 产品面检出探针全绿（ok 91 bad 0 skip 0）            ← 合并后基线那条红消失（P188 的前提写法）
```

（`logs/merged-fast.txt` / `logs/merged-select57.txt` / `logs/merged-openspec.txt` 为原始输出。scratch clone 在
`/tmp`，只用来量「合并后的树」，没有改 main、没有改我的分支、没有碰别人的 worktree；合并后 `P148` 探针的
新前提（`tmux_iso_install_suite_guards` + 共享分类器同源）满足。）

## 我跑了什么 / 引用什么

- **自己跑的**：上面每一张表的命令与输出；`pkg/real-runs.sh` 的四次真 Pi 容器运行（旧形状 ×2、新配方 ×2）
  与三次反向拒绝（新配方两次的现场分别为 `evidence/run-1`（run_id 各自独立）与 `logs/tmux-p163-after-0992-dirty`）；`pkg/gates.sh` 的 openspec / 全段夹具 / `--select 57` / FAST；`--select 40,46` 复验；
  `tmp-hygiene.sh --lint`；合并快照的 openspec / `--select 57` / FAST。
- **引用的**：`docs/team/reports/P157-verify.md`（两条 finding 与 1.0.0 真帧的出处）与
  `docs/team/reviews/P157.md`（PM 读真帧后的现场判断）；P147/P157 的配方只作为**重建旧形状**与**真帧来源**，
  其数字一律不复用（我这里的每一个数字都是本轮跑出来的）。

## 边界与没测到的

- 本轮**没有跑不带 FAST 的全量 smoke**（brief 要求 `--select 57` + FAST）；`--select 57` 的点名未跑段见
  `logs/select57.txt`（118 个键），FAST 的 36 个真进程跳过段见其末行。
- 我没有改产品的任何 `scripts/**`、`panel/**`、`references/**`、spec/delta；`foreign` 段钉住的是**现有**产品
  行为（`queued` + 可见报告 + 不重贴）与现有 `held` 路径，没有新增产品语义。
- 1.0.0 只作**人工观察**：夹具里没有「1.0.0 下判绿」的断言，判据会拒绝 observation 现场；本报告也没有任何
  「宿主 1.0.0 绿」的宣称。
- 旧形状对照是**重建**（P157 配方 − 重置/标记两件事，重建脚本与产物在 `legacy/`），不是 P147 作者原文件；
  这样做的原因是 P147 的配方与证据目录属于别人的报告，我不能写。（重建只差这两件事，`run-case-old.sh` 与
  P157 版本 `diff` 可见。）

## 提交（同「提交」表）

`8373c971` → `f519d655` → `9e7ae21c`（代码）→ 本报告的提交（报告 + 证据目录 `docs/team/reports/P163-dev-bob/**`，
就是这一条里的文件）。
分支留在本地，供 PM 复验后本地合并；未 push、未合并、未改看板/任务书。
