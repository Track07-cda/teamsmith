# P140 · `dispatch-friction` apply：分支身份可见可指定 + 一次拒绝列全 + 文案教学 + 配额预提示

```
task:   P140
agent:  dev2                     # 提案人继续实现（守卫只要求"复验换人"）
issue:
change: dispatch-friction        # 提案已验收并合入 main（reviews/dispatch-friction-proposal.md）
specs:  dispatch#A refused dispatch hands over every blocker, once, with a fix that runs
phase:  apply
anchor: change
deltas: dispatch
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/scripts/team · skills/teamsmith/tests/** · skills/teamsmith/tests/task-header-model.sh · openspec/changes/dispatch-friction/** · docs/team/reports/P140-dev2.md · docs/team/reports/P140-dev2/**
deps:   `openspec/changes/dispatch-friction/tasks.md`（覆盖映射与每项 verify/red ✅ 照它做）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）不许碰 ✅
status: todo
budget: 一个工作块
priority: 高（使用方 PM 的第一号摩擦 ✅）
```

> 本地模式：不 push main ✅；推送带 `[skip ci]`（D54：CI 不是判据 ✅）。

## 照 change 的 `tasks.md` 全部做完（含每项自己的 verify 与 red）

## 特别要求（我审提案时点名的几条）

1. **不放松任何守卫** ✅：别的任务的分支、别的任务的 `--branch`、脏工作树、叠任务——**都要仍然被拒** ✅
   （这些是既有红侧，不许为了"少摩擦"而放宽 ✅）。
2. **"一次列全"要真的一次** ✅：把**无需副作用即可判定**的守卫**一遍过**收集 ✅，输出**一份**拒绝，
   每条给 `修法：<command>`（含具体值：工作树路径/分支名/席位/模型/会话 ✅，可**直接粘**）。
   `--print` 也必须同样判定 ✅，且拒绝时**不开窗、不切分支、不写状态、不动看板** ✅。
3. **分支身份可见** ✅：派单输出里给出**期望分支名**与**它从哪里来** ✅；生成的派单提示里带上它 ✅
   （让 agent 不必猜 ✅）；`--branch <名>` 可用且**不许被静默换成同任务的另一个分支** ✅。
4. **文案教学** ✅：`change:` / `deltas:` 畸形时，**第一行**就给**合法示例** ✅ 与**为什么非法** ✅。
5. **配额预提示不许猜** ✅：只有判定得出来才打印 ✅（死因分类 ✅ 或上一轮 0 产出 ✅）；
   判不出来**必须沉默** ✅；**不阻断** ✅ 不改退出码 ✅。
6. **同一任务的另一个 slug 必须被接受** ✅（这是实测摩擦：`task/P137-apply` vs 期望 `task/P137-references` ✅）——
   但不能因此接受**别的任务**的分支 ✅。

## 门禁与证据

`openspec validate --all --strict` ✅ + **FAST 全绿** ✅ + **一次全量**（动了派单主路径 ✅）；
每条 What flips 与每个红侧留**原始输出**（红→绿）✅；报告点名"哪些自己跑、哪些引用" ✅。
