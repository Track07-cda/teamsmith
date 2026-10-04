# P197 · `delivery-truth` 返工：判据要数**标记条数**，不能只比**集合**

```
task:   P197
agent:  dev
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  apply
anchor: change
deltas: delivery-guard
grant:  skills/teamsmith/tests/fixtures/delivery-truth-real/** · skills/teamsmith/tests/** · openspec/changes/delivery-truth/** · docs/team/reports/P197-<agent>.md · docs/team/reports/P197-<agent>/**
deps:   P194 的独立验证（finding：删除 `run-start.txt` / **追加同 ID 的第二个** `run_start` 仍 rc=0/PASS ✓）· **PM 读码确认** ✓：`judge-second.py:63-66` 用 `sorted({m.get("run") …})`（**集合** ✗）→ 同 ID 的重复标记不会让它拒绝 ✗ · P163（该判据的作者 ✓）
status: wip
budget: 小
priority: 高（它是"现场跨次累积"的唯一守卫 ✓；判据的假绿正是这一类最坏的形状 ✓）
```

## 现场（PM 读码确认 + 验证者实测）

```python
marks = [json.loads(x) for x in lines if '"run_start"' in x]
ids = sorted({m.get("run") for m in marks})     # ← 集合：同 ID 的重复被吞掉 ✗
if ids != [run["run_id"]]: refuse(...)
```
→ `dev-events.jsonl` 里**追加第二个同 ID 的 `run_start`** ✓ → `ids` 仍是 `[run_id]` ✓ → **不拒绝** ✗（实测 rc=0/PASS ✓）。

## 要做的

1. **数条数** ✅：`run_start` 标记必须**恰好一条** ✓，且是**第一行** ✓，且其 `run` 等于 `run.json.run_id` ✓ —— 三条任一不成立即**拒绝并点名**（几条 ✓ / 第几行 ✓ / 两个 id ✓）。
2. **`run-start.txt` 判据必须核它** ✅（P194 的 **F1** 裁为**要修** ✓，不是"可选删掉" ✗）：判据必须要求它**存在** ✓、**非空** ✓、
   且其内容与 `run.json.run_id` **一致** ✓ —— 不成立即**拒绝并点名**（缺文件 ✓ / 内容不符 ✓）。理由：它是 `run-case.sh` 写给现场的单次运行戳 ✓，
   留一个"看起来是戳、判据却不看"的文件 ✗ 只会让人以为它被检查过 ✓。
3. **红侧（三条）** ✅：追加**同 ID** 第二个标记 ✓ → 必须拒 ✓；追加**异 ID** 标记 ✓ → 拒 ✓（既有 ✓ 复跑 ✓）；标记不在第一行 ✓ → 拒 ✓。
   **影子**：把"恰好一条"改回"集合相等" → 第一条必须红 ✓。
4. **反向**：正常现场 ✓ → 照旧出判据 ✓（PASS ✓，逐字节相同 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 容器内 `--select 57` ✓ + 容器内 FAST ✓；报告点名"哪些自己跑、哪些引用 P194" ✓；**复验换人** ✓。

## 追加（原 P198，单写者规则下并入本任务）

`openspec validate delivery-truth --type change` 现在报 ✓：
**MODIFIED「An automated send never types into a non-empty input box」omits scenario(s) the current baseline has** ✗（基线被更早的归档推进过 ✓）。
请在**同一分支**里一并把该 delta 重写到当前基线 ✓：**抄全基线的所有 scenario** ✓（一条不许少 ✗）+ 本 change 的改动与新增 ✓，
契约不许放松 ✓；**验收**：`validate delivery-truth --type change` ✓ 通过 ✓ + `validate --all --strict` ✓ 无新错 ✓ +
scratch 预演 `archive -y delivery-truth` ✓ 成功 ✓；报告给 scenario 计数对照（前/后 ✓）。
