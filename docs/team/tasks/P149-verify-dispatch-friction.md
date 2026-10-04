# P149 · `dispatch-friction` 独立验证（换人：apply 是 dev2，验证由 verify 做）

```
task:   P149
agent:  verify
issue:
change: dispatch-friction
specs:  dispatch#A refused dispatch hands over every blocker, once, with a fix that runs
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P149-verify.md · docs/team/reports/P149-verify/**
deps:   apply 见 main 上的 P140 合并提交（`feat(teamsmith): P140 …`）· 提案评审 `docs/team/reviews/dispatch-friction-proposal.md` · D31（写的人不验自己）· **只读**：`openspec/specs/**`、`skills/**` 一行都不许改（OWNERSHIP）
status: wip
budget: 一次独立验证
priority: 高（这条改的是派单主路径，且它自己宣布了"一次列全"）
```

## 要独立证明的（不要照抄作者夹具；自己造场景）

1. **一次列全** ✅：造出**至少四个**同时成立的阻塞项（例如：工作树停在别的任务分支 + 头部 `change:` 行非法 +
   `deltas:` 用错分隔符 + 工作树有未提交改动）→ 一次调用就要**全部**出现 ✅（不是一次一个 ✅），
   且总数行与逐条数**自洽** ✅；每条都要有**可直接粘贴**的修复命令 ✅ —— 照着粘贴**真的能修好**（自己试 ✅）。
2. **同任务另一 slug 放行** ✅：把工作树切到同一任务的另一种 slug（如 `task/T1.1-old-style`）→ 分支身份**不再报** ✅；
   而 `--branch` 指向**别的任务**、或工作树停在**别的任务**分支 → 仍然**拒** ✅。
3. **头部行报错教学化** ✅：`change:` 两行 / `change: xxx（说明）` / `deltas:` 用 `·` 分隔 / 尾随逗号 —— 每种都给出
   **第一行合法示例**与**为什么非法** ✅（不是只说"不合法" ✅）。
4. **配额预提示** ✅：造一个"上一轮 0 产出"的席位记录 → 派单**打印**提示 ✅；造一个死因为 `quota` 的记录 → 提示**点名类别** ✅；
   **判不出来时不许猜** ✅（清掉记录 → 无提示、不阻断 ✅）；提示**不许**阻断任何一次正常派单 ✅。
5. **不许放松守卫** ✅：把上面第 2 条的三种拒绝形状各造一次，确认**都还拒** ✅（这是本次改动最大的风险面 ✅）。
6. **门禁**：在**你的独立检出**上跑 `openspec validate --all --strict` + `bash skills/teamsmith/tests/routes.sh`（用法诚实性 ✅）
   + 相关段（6/12g/12h/51/54 ✅）+ **FAST** ✅；报告写清原始输出、你**没有**测到什么（例如真窗口拉起 ✅）。
