# V67 · 独立复核 P330：删掉的那批夹具真的都不可达吗

task: V67
agent: verify
phase: verify
category: verify
change: -
anchor: none (infra) — P330 删掉 36 个夹具 / 6 701 行；复核点是「一个都不该是可执行的」
deltas: -
branch: task/V67-fixture-deletion-review

## 只有一件事要回答

P330 删掉的每个文件，**是不是真的没有任何活着的入口能执行它**。不是复述作者的扫描结果——你自己扫。

## 必须自己做的四件事

1. **重扫**：对**被删的 36 个文件**逐个，在 P330 的 tip 树（`task/P330-unreachable-fixtures`）上扫「谁引用这个名字」，扫描面至少覆盖 `skills/teamsmith/tests/**`、`skills/teamsmith/scripts/**`、`skills/teamsmith/extension/**`、`ci/**`、`.github/workflows/**`、`docs/team/tools/**`、`package.json`、`Makefile`（若有）。
   - 排除项（历史面，不算活引用）：`openspec/changes/archive/**`、`docs/team/reports/**`、`docs/team/reviews/**`、`docs/team/tasks/**`。
   - 变量拼接与通配：至少覆盖 `tests/$var`、`$TESTS/`、`"$D"/flip-`、`for f in tests/flip-*`、`basename`、`ls tests` 这类形状；命中就逐个打开看它是否可能选中被删文件。
   - 报告里给**扫描命令 + 输出**，不要只给结论。
2. **动态入口**：`bun test` / `node --test` / `python -m pytest` / 任何 `*.test.*` 收集规则、`package.json` 的 scripts、`ci/Containerfile` 与 workflow 里的 `bash -c '…'` 串，有没有可能收集到被删文件（含 `tests/*.ts` 被删的两个）。
3. **门禁自检**：在**你自己的独立检出**（不要在 .worktrees 里跑，也不要写主树）跑
   ```bash
   bash skills/teamsmith/tests/section-select.sh --check
   bash skills/teamsmith/tests/smoke.sh --select 0e
   ```
   `--check` 必须绿（`ok N bad 0`），`0e` 必须 ✗0（循环清单与 `loop-inventory.tsv` 配平）。用磁盘临时根与私有锁（`/var/tmp/...`），跑完清自己的根。
4. **登记表对账**：`skills/teamsmith/tests/loop-inventory.tsv` 里删掉的行，是否恰好是被删文件对应的行（多删一行 = 某个仍存在的循环失去登记，`0e` 会红；少删一行 = 未登记的循环留下）。

## 四条红侧（不复用作者的日志）

每条都要「造一次 → 必须红/必须命中 → 还原」：

1. 在被删文件**仍存在**的副本里（用 `git show` 从父提交取一个，放进 scratch 树）把它接进某段 → `0e` 或 `--check` 的反应是什么，如实记（这条不是要求红，是要求你知道「如果它还活着，今天会不会被发现」）。
2. 把 `loop-inventory.tsv` 里**一行仍存在文件**的登记删掉 → `0e` 必须红并点名那个文件。
3. 把 `section-needs-audit.sh`（本批**保留**的那个）改名 → 有没有任何段/`--check` 因此变红？如实记（这条测的是「保留它到底有没有人依赖」，不是要它红）。
4. 把 `flip-p171.sh`（本批**保留**）改名 → `signal-gate.sh` 的注释会不会因此与实际不符（注释不是断言，如实记）。

## 判据

- 只要有一个被删文件**今天仍可被执行**（PASS 面），判 **FAIL** 并点名。
- 只要你重扫出的「不可达」集合与作者的清单**不同**，逐条列出差异，并判 FAIL（差异可能是作者漏删或误删）。
- 登记表对账不一致 → FAIL。
- `--check` 或 `0e` 红 → FAIL 并贴原始输出。
- 其余为 **PASS**，并把「这批删除后失去的能力」用一句你自己的话写清（不要抄作者）。

## 边界

- 只读作者树：`git -C <你自己的工作树> switch --detach task/P330-unreachable-fixtures` 前先确认工作树干净；不改任何文件。
- 不跑整套门禁（`smoke.sh` 无 `--select` 的那条），不跑容器，不跑计时套件。
- 报告 `docs/team/reports/V67-verify.md`，抬头 `status:` / `time:` / `branch:` / `tip:`，先给判定，再给证据。
