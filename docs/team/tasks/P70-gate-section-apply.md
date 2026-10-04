# P70 · gate-section-accounting apply：每段自述 + 硬超时 + 现场

```
task:   P70
agent:  （等席位；**不得派给 verify 席位**——提案是 verify 席位写的）
issue:
change: gate-section-accounting
specs:  verification#Every gate section accounts for itself, and a stuck section is named / verification#The correctness gate judges correctness only（MODIFIED）
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/smoke.sh · skills/teamsmith/tests/perf.sh（若需引用）· skills/teamsmith/tests/gate-guard.sh（纯逻辑守卫）· skills/teamsmith/references/*（一段文档）
deps:   P56（propose，已合并）· **pty-fixture-load-premise 先归档**（D40：两者都 MODIFIED 同一条 requirement）
status: todo（等席位）
budget: 一个工作块
condition: **apply 第一步**：在 `pty-fixture-load-premise` 归档**之后**，把本 change 的
           `verification` delta **重写**到新的 base 上（当前 delta 是照归档前的 base 写的；
           归档后 base 已含 pty 的正文，直接改会报 "omits scenario"）。重写**不得丢**任何 base scenario。
priority: 中（它让"门禁卡住"变成"点名某段卡住"，并给 CI 现场通道补上自述）
```

> 本地模式：不 push。**真源 = `openspec/changes/gate-section-accounting/{design.md,tasks.md}`。**

## 硬要求

1. **每段自述**：每个 section 打印"开始"+段落号+时间戳；每段在一个**硬超时**里跑（`timeout <预算>`），
   超时**点名该段**并非零退出——不许出现"整轮卡住但不知道在哪"。
2. **超时即现场**：超时/失败时留下该段现场（pane 尾巴、夹具日志、进程表快照），与 D39 的容器产物通道接上。
3. **预算有依据**：预算由**实测带 + 系数 + 下限**导出，**不得收紧到带以下**；
   **不许**变成性能红线（D33 保持）；段内无论多慢，只要在界内就必须绿。
4. **无界等待禁止**：段落内等待/轮询必须有轮数与上限（复用 P48 的 `pty-wait.sh` 引擎），到顶必须归因。
5. **可证伪**：注入"某段永不返回"（`sleep infinity`）→ 门禁在预算内点名该段并非零退出，现场里有证据；
   正常跑不受影响（时长增量要测出来，>3 分钟回 PM 报数）。
6. **计时记录不是判决**：门禁写的时长不得被别的断言拿去比阈值（纯逻辑守卫保持这条）。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量 + 记时长增量
```
