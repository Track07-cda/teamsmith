# P151 · `dispatch-friction` 返工：修好"打印出来的修法"与"一次列全"的四处漏洞

```
task:   P151
agent:  dev3                      # 返工换人做（dev2 正在 P148；**复验必须再换一个人**，D31）
issue:
change: dispatch-friction         # 已在 main；独立验证判 FAIL（见 docs/team/reviews/P149.md）
specs:  dispatch#A refused dispatch hands over every blocker, once, with a fix that runs
phase:  apply
anchor: change
deltas: dispatch
grant:  skills/teamsmith/scripts/lib/** · skills/teamsmith/tests/** · skills/teamsmith/references/** · skills/teamsmith/SKILL.md · openspec/changes/dispatch-friction/** · docs/team/reports/P151-dev2.md · docs/team/reports/P151-dev2/**
deps:   PM 分配：dev2 在做 P148，返工改由 dev3 执行（同一路径的授权不变）；`docs/team/reviews/P149.md`（五条缺陷 + 两条警告，含代码行号与复现输出）· 验证者的证据包 `docs/team/reports/P149-verify/pkg/`（可重跑）· **不许放松任何守卫** · 与 `capacity-floor-disk` 都改 `dispatch`（归档顺序后置者重写 delta）
status: wip
budget: 一个工作块
priority: 高（`dispatch-friction` 的承诺在当前 main 上是**假的**：修法粘了不工作；"一次列全"在一族里不成立）
```

## 必须逐条修掉的（每条都要**红→绿**原始输出）

**F1 · 打印的修法里混进了中文说明**（`cmd-agents.sh:771/911/940`）
`team dispatch dev Q7 … --force（显式覆盖：警告 + 一行审计）` 原样粘贴 → `✗ 未知参数 --force（显式覆盖：…`（exit 2）。
**要求**：命令与说明**分行** ✅ —— 命令行只含可执行参数 ✅，说明另起一行（或注释化 ✅）；
**并且**加一条**原样粘贴**的回归：把打印出的整行喂回去，必须**真的生效**（`--print` 下 exit 0 ✅ 或按语义成功 ✅）。

**F2 · 分支修法里的说明被 git 吃到**（`cmd-agents.sh:350`）
`git -C … switch -c task/Q7-declared main（或让 --branch 指向一条已存在的本任务分支）` → `error: unknown option 'branch'`（exit 129）。
**要求**：git 命令**独立成行/独立成段** ✅，替代方案另说 ✅，并加同样的原样粘贴回归 ✅。

**F3 · 容量拒绝没有具体修法**（`team_mem_guard` 透传，`common.sh:2678-2690` / `cmd-agents.sh:1126`）
**要求**：给出**具体**修法行 ✅（例如等一个席位结束 ✅、或显式降低底线并说明代价 ✅），
**不许**留占位符 ✗，**不许**改变容量守卫与其覆盖语义 ✗。

**F4 · 同一族里第二个 delta 冲突仍是一次给一个**（`cmd-agents.sh:912` 在兄弟循环里 `return`）
**要求**：**一次列全所有**冲突兄弟 ✅（不放松单写者规则 ✅），并让**总数与逐条数自洽** ✅；
红侧：造两个未完成兄弟 → 一次调用里**两个都出现** ✅。

**F5 · 上一轮产出判定取错时点**（`cmd-agents.sh:1294` 在 respawn 之后取字节）
把上一轮真实产出的 8 字节说成 `0 bytes ≈ 0 tokens` ✗ = **假陈述** ✗。
**要求**：在**worker 能跑之前**取同会话的字节 ✅，**只在成功派单后**持久化 ✅，判不出来就**不说** ✅；
红侧：一个上一轮有产出的席位**不许**被说成零产出 ✅。

**W3（今天新实证，D70）· 提示词里的分支名与"守卫接受的分支"不一致** ✗
形状：我手工建了 `task/P152-verify` 再派单（没用 `--branch`）→ 守卫**接受**它（P140 的"同任务另一 slug"规则 ✅），
但派单提示词里仍写着**推导名** `task/P152-p152` ✗ → 席位读到"你的分支是 X"与现场不符 ✗ → 它报 BLOCKED（对的 ✅）。
**要求**：提示词必须写**守卫实际接受的那条分支** ✅（工作树当前分支若已属于本任务，就用它 ✅；否则用推导名 ✅），
且**与 `state/<agent>.env: branch=` 一致** ✅；红侧：预建一个同任务的另一种 slug → 提示词里出现的是**它** ✅（不是推导名 ✗）。

**W2 · 续跑提示用了 `$br_name` 而不是实际分支**（`cmd-agents.sh:1156`）
**要求**：提示词与实际记录的分支一致 ✅（用 `$task_branch` ✅）。

**W1 · 账本与文档**：
① `openspec/changes/dispatch-friction/tasks.md` 的 23 项按**事实**勾选 ✅（做了的勾 ✅ 没做的补 ✅ **不许**盲目全勾 ✗）；
② 产品文档缺的那一项（`SKILL.md` 附近，验证者点名 6.1 ✅）补上 ✅。

## 门禁与证据

`openspec validate --all --strict` ✅ + 相关段（6 · 12g · 12h · 51 · 54 ✅）+ `routes.sh` ✅ + **FAST** ✅ + **一次全量** ✅；
**每条缺陷各留红→绿原始输出** ✅；报告里点名"哪些自己跑、哪些引用验证者包" ✅。
