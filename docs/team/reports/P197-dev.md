# P197 · `delivery-truth` 返工：判据数**条数**并核 `run-start.txt`；delta 重写到当前基线

agent: dev · status: DELIVERED（本地分支，不 push；PM 复验后本地合并） · time: 2026-10-03
branch: `task/P197-rework` · base: `a3ea6630`（派单时的分支 tip） · change: `delivery-truth`（phase: apply）
授权路径：`skills/teamsmith/tests/fixtures/delivery-truth-real/**` · `skills/teamsmith/tests/**` ·
`openspec/changes/delivery-truth/**` · `docs/team/reports/P197-dev.md` · `docs/team/reports/P197-dev/**`

## 结论

两条都落地，都带**同一现场上的 old → new 对照**（红侧不是引用，是我自己这一轮跑出来的）：

1. **判据数条数**：`judge-second.py` 不再用 `sorted({…})` 比集合，而是要求判据读的每个事件文件里
   `run_start` 标记**恰好一条**、在**第一行**、`run` == `run.json.run_id`；三条任一不成立 → `exit 2` 并点名
   （几条 / 第几行 / 两个 id）。顺带把 P194-F1 的 `run-start.txt` **核起来**（存在 / 非空 / `run=` 与
   `run.json.run_id` 一致，不成立即拒绝并点名）。判据的正文、docstring、配方 README 与两处脚本注释同步。
2. **delta 重写到当前基线**：MODIFIED「An automated send never types into a non-empty input box」按当前基线
   逐字节抄全 14 条 scenario（此前 delta 只带了 13 条，丢了 `A meeting knock never lands on a draft` ——
   基线被 `meeting-liveness` 的归档推进过），保留本 change 的 4 条新 scenario 与 closed-layout 两段契约，
   并恢复发送者清单里的 `the meeting knock`。**契约没有放松**：改动的净效果 = 加回一条被吞掉的基线 scenario
   + 加回一个发送者名词（见下面的逐字节比对）。

## 提交

| commit | 内容 |
|---|---|
| `728556b8` | 判据：`run_start` 恰好一条 / 第一行 / run 一致 + `run-start.txt` 存在·非空·run 一致 |
| `6dd5af96` | 门禁：`delivery-truth.sh --section judge`（标记红侧 3 + 戳红侧 3 + 集合相等影子），smoke §57 与路径表描述同步（七段 → 八段） |
| `08c5be55` | delta 重写：抄全基线 14 条 scenario，恢复 `the meeting knock` 发送者 |
| `f68403c4` | 证据包：`pkg/flip.sh`、`pkg/gates.sh`、`pkg/scene.py` + `logs/flip.txt` |
| `aa2b84be` | 补齐第三条红侧：单条标记但 `run` 不是本次（`!= run.json.run_id`）+ 一条标记都没有（`0 条`） |
| 最后一次提交 | 配方注释/README 同步 + 其余证据（`real-scenes` / `archive-scratch` / `scenario-counts` / 门禁日志）+ 本报告 |

## 红 → 绿（翻转证据）

### ① 判据：同一批合成现场，old 假绿 → new 拒绝（`pkg/flip.sh`，宿主，纯 python）

```text
old judge: 728556b8^（sha256 ebd48273…）    new judge: 工作树（sha256 a7974f00…）

== 同 ID 的第二个 run_start 标记 ==
  old rc=0 | PASS second say delivered
  new rc=2 | judge-second: 拒绝出判据（tmux-p163-p197-synth）：dev-events.jsonl 的 run_start 标记 2 条（要求恰好一条）：['aabbccddeeff', 'aabbccddeeff']
  ✓ 翻转成立：old 假绿 → new 拒绝

== 缺 run-start.txt ==
  old rc=0 | PASS second say delivered
  new rc=2 | judge-second: 拒绝出判据（tmux-p163-p197-synth）：缺 run-start.txt（run-case.sh 的单次运行戳；判据不猜）
  ✓ 翻转成立：old 假绿 → new 拒绝

== 反向：干净现场 ==
  old rc=0 | PASS second say delivered      new rc=0 | PASS second say delivered
  ✓ 干净现场两版都 PASS（新检查没有变成一律拒绝）
```

### ② P194 自己的真现场（`pkg/real-scenes.sh`，不重跑真 Pi：现场已在仓库里）

| 现场（`docs/team/reports/P194-verify/logs/…`） | old | new |
|---|---|---|
| `…judge-control`（正对照） | rc=0 PASS | rc=0 PASS |
| `…second-dirty`（真二投递） | rc=0 PASS | rc=0 PASS |
| `…judge-two-identical-stamps`（P194-F2 的现场） | **rc=0 PASS（假绿）** | **rc=2 拒绝：run_start 标记 2 条** |
| `…judge-two-distinct-stamps` | rc=2 拒绝 | rc=2 拒绝 |
| `…judge-missing-run-start`（P194-F1 的现场） | **rc=0 PASS（假绿）** | **rc=2 拒绝：缺 run-start.txt** |
| `…noreset-dirty` | rc=0 PASS | rc=0 PASS |

`noreset-dirty` 的如实交代：它在本工作树里两版都 PASS —— 该现场的文件是被**复制**进来的（mtime 晚于
`run.json.started_at`），「现场里有早于本次运行的文件」这条**旧**守卫在本树里失去了前提；P194 的原始运行里
它被正确拒绝（`P194-verify/logs/noreset-judge-2.txt`）。这不是 P197 引入的差异（old 与 new 一致），
我没有去动它。

### ③ 门禁内的影子（`--mutations`：把「恰好一条」改回集合相等）

```text
✓ 反向：正常现场 rc=0 且照旧出 PASS 判据
✓ 同一现场跑两次：判据输出逐字节相同
✓ 判据不改现场（跑前跑后文件哈希相同）
✓ 红侧 同 ID 第二个标记：拒绝出判据（rc=2）并点名 run_start 标记 2 条 'aabbccddeeff'
✓ 红侧 异 ID 第二个标记：拒绝出判据（rc=2）并点名 run_start 标记 2 条 'ffffffffffff'
✓ 红侧 标记不在第一行：拒绝出判据（rc=2）并点名 在第 2 行
✓ 红侧 标记的 run 不是本次：拒绝出判据（rc=2）并点名 != run.json.run_id 'ffffffffffff'
✓ 红侧 一条标记都没有：拒绝出判据（rc=2）并点名 run_start 标记 0 条
✓ 红侧 缺 run-start.txt：拒绝出判据（rc=2）并点名 缺 run-start.txt
✓ 红侧 run-start.txt 为空：拒绝出判据（rc=2）并点名 是空的
✓ 红侧 run-start.txt 的 run 不是本次：拒绝出判据（rc=2）并点名 不是本次运行的戳 'ffffffffffff'
✓ 影子（集合相等）：同 ID 重复被吞 → PASS；真判据同时拒绝 —— 条数检查是承重的
```

`--section judge` 的现场是**合成**的（`pkg/scene.py` 造出与 `scenario.sh` 同形的 verdict 现场），
不跑真 Pi、不进容器、不起 tmux；真现场的对照在 ②。

## delta 重写：scenario 计数对照

| | 前（`728556b8`） | 后（工作树） |
|---|---|---|
| 基线 `delivery-guard#An automated send never types into a non-empty input box` | 14 | 14（不变） |
| change 里该 MODIFIED 块 | 17 | **18** |
| change 三份 delta 合计 | 64 | **65** |

- 缺的那条是 `A meeting knock never lands on a draft`；重写后 `缺基线 scenario：[]`。
- 整个 delta 重写的 diff 只有 **`1 file changed, 9 insertions(+), 1 deletion(-)`**（`git diff a3ea6630..HEAD -- openspec/`）：
  多出来的 9 行就是那条 meeting-knock scenario，改的那 1 行是发送者清单里的 `the meeting knock`。
- 逐字节比对：重写后的块里，基线的 13 条原有 scenario **一字未动**（脚本比对 `strip()` 后全等），
  本 change 的 4 条新 scenario 与 closed-layout 两段原文保留。
  也就是说这次重写的净改动 = `+1 scenario`、`+1 名词`，没有任何一处放松。

## 验收命令与结果（容器 = `localhost/teamsmith-gate:local`，`--network=none`）

| 命令 | 结果 | 日志 |
|---|---|---|
| `openspec validate delivery-truth --type change` | `Change 'delivery-truth' is valid`（rc=0） | `logs/change-validate.txt` |
| `openspec validate --all --strict` | rc=0，17 passed / 0 failed | `logs/validate-all.txt` |
| `bash skills/teamsmith/tests/smoke.sh --select 57` | rc=0，**✓22 ✗0**；§57「八段全绿（135 条断言，0 条可见跳过）」 | `logs/select57.txt` |
| `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | rc=0，**✓3791 ✗0**，`smoke 全绿`；FAST 跳过 36 个真进程段 + 1 条条件 SKIP（§26-a bundle 重建：本机 bun 装不上钉住的依赖，与本 change 无关） | `logs/fast.txt` |
| `openspec archive -y delivery-truth`（scratch 副本预演） | `archive rc=0`；归档后 `validate --all --strict` rc=0（16 passed）；合并后基线该 requirement = 18 条、基线 14 条一条不少、`the meeting knock` 在 | `logs/archive-scratch.txt` |
| `bash skills/teamsmith/tests/delivery-truth.sh --section judge --mutations` | rc=0，✓12 ✗0 | `logs/judge-section.txt` |
| `pkg/flip.sh` / `pkg/real-scenes.sh` / `pkg/scenario-counts.py` | 见上面红 → 绿 | `logs/flip.txt`、`logs/real-scenes.txt`、`logs/scenario-counts.txt` |

门禁驱动脚本 `pkg/gates.sh`：先把分支 clone 成带真 `.git` 的检出（`docs/team/reports/P197-dev/.checkout`，
被 gitignore；工作树的 `.git` 是指针文件，容器里解不开），再在容器里按序跑上面三条；
驱动输出见 `logs/gate-driver.txt`。

## 一次不可复现的瞬态（如实记录，不是本 change 的缺陷）

第二轮门禁（同一个容器，先 select57 后 FAST）里，§57 的 **drafts** 段报了一条红：

```text
✗ DRAFT-CLONE：rc=0 keys=0 out=! say: dev 没在跑（窗口 p147:dev 不在）—— 消息已落收件箱（docs/team/inbox/dev.md）
== 2 drafts 结果 == ✓ 34 ✗ 1 ==
```

- 它落在**我没有动过的**段/夹具上（假 tmux + 真 `team say`）；失败点是产品的「窗口不在」兜底
  （`scripts/lib/cmd-agents.sh:1449`），需要假 tmux 的 `list-windows` 输出里没有 `dev` 才会走到。
- 同一次运行里，**几分钟后的 FAST 套件 §57 是绿的**（同样的代码、同一个容器）；
  `--section drafts` 在宿主连跑 5 次全绿；第三次门禁（交付 tip）select57 也是绿的。
  全仓搜 `DRAFT-CLONE：rc=` 只有这一条（在本报告写进仓库之前）。
- 当轮环境：宿主上另有两个 `teamsmith-gate:local` 容器在跑别的 agent 的门禁（`podman ps` 可见，load ≈ 2.75/32）。
- 结论：**不可复现的瞬态**，与本 change 无因果关系；我没有把它藏起来，也没有改夹具去迎合它。
  若复验者再次碰到，它值得单独一个任务（drafts 夹具那条窗口检查路径）。

## 门禁跑在哪一个 commit 上

- 上面三条验收全部跑在交付 tip `aa2b84be`（`logs/gate-driver.txt` 的 `checkout HEAD`），证据见 `logs/`。
- 本报告是 tip 之后**唯一**的提交（纯文档）；`docs/team/reports/P197-dev/.checkout`（容器用的带真 `.git` 的检出，
  约 174 MB）交付前已删除 —— `pkg/gates.sh` 会自动重建。

## 哪些是我自己跑的、哪些是引用 P194

- **自己跑**：上面表格里的每一条；① 的两版判据对照、② 的六份现场、③ 的 12 条断言、delta 的三项验收
  （change validate / all strict / scratch archive）。
- **引用 P194**：② 用的**现场本身**（`docs/team/reports/P194-verify/logs/` 里的真 Pi 0.99.2 现场）与
  P194 的两条 finding 描述。我没有重跑真 Pi 配方（需要 `$E/.runtime` 里钉住的 0.99.2 与网络安装；
  P194 的真现场已入库，在它上面做 old/new 对照是等价且更强的证据 —— 现场是真跑出来的，不是合成的）。
- **没有改产品代码**：本任务只动夹具/门禁/delta/报告，`skills/teamsmith/scripts/**` 一字未动。

## 复验要求（换人）

- 复验者请在**独立检出**上重跑 `pkg/gates.sh`（或等价的容器命令）与 `pkg/flip.sh`、`pkg/real-scenes.sh`，
  并独立造一次「同 ID 第二个标记」现场确认 `exit 2`（不要只读我的日志）。
- 影子那条（③）是「破坏实现 → 守门断言必须红」的形态：把判据里 `if len(marks) != 1:` 那行改回集合相等，
  红侧第一条必须不再是红的。
