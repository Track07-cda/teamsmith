# P485 · 两份提醒测试的工作目录方案

agent: dev · status: DELIVERED / 提案返修待复看 · time: 2026-11-20 UTC

branch: `task/P485-reminder-test-temp-roots-proposal` · revised proposal: `8be17c78` · PR/MR: -

## V184 复看后的唯一补项

`78f1a5ae` 已关闭 R1、R2、R4。本次只补 `design.md` 和 `tasks.md` 2.4：同步命令结束后，先处理已收到的停止请求，再允许下一次写入或正常退出。原故障中断样本须看到准入写入完成、驱动自身按 TERM 停止且没有开始后续注入；外层返回非零不能代替驱动证据。不新增样本、文件或进程管理机制。

```text
$ OPENSPEC_TELEMETRY=0 ~/.bun/bin/openspec validate reminder-test-temp-root-ownership --type change --strict
stdout: Change 'reminder-test-temp-root-ownership' is valid
stderr: (empty)
rc=0

$ git diff --check 2022af63 HEAD && git diff --cached --check && git diff --check
stdout: (empty)
stderr: (empty)
rc=0
```

只执行上述检查；不改实现、不跑行为样本、不重跑全仓规格或公开文件检查。待原审阅者复看。

## V184 定点返修（`36d02c48`）

按 V184 `1dc98ef4` 的 R1–R4 修订，仍保留调用者指定的证据位置和 smoke 自有的三处证据。没有进入实施。

- **R1：只需五个待改测试文件。** `remind-recovery-real.sh:5` 已直接运行同一驱动，不改该文件或 smoke；保留原选择参数和原有退出结果，故障 JS 的直接调用不新增 shell 专属比较。
- **R2：沿用现有短地址工具。** 本轮私有地址和备选地址都按字节计算；启动、观测和收尾用同一个确切地址。把多字节路径核对并入已有的真实 Pi 中断样本，不另跑一个业务场景。
- **R3：先等已开始的命令退出，再删工作目录。** 只通知本轮记下的驱动，由 Node 的常规信号回调等同步调用归来再退出；不发送进程组信号，也不把等待超时当成收尾成功。计划中的第二个中断样本只停在一个真实 `remind-tick` 命令内，要求该命令正常完成写入，再核对退出和目录移除。
- **R4：规格只写证据放在哪里。** 通用规则不重写。取消逐入口重复运行、额外等价成功及单独漏删样本；对抗入口只用一份短回执分别查保留与非零退出，并明确不把回执算成业务通过。

```text
$ OPENSPEC_TELEMETRY=0 ~/.bun/bin/openspec validate reminder-test-temp-root-ownership --type change --strict
stdout: Change 'reminder-test-temp-root-ownership' is valid
stderr: (empty)
rc=0

$ git diff --check 227b04f6 HEAD && git diff --cached --check && git diff --check
stdout: (empty)
stderr: (empty)
rc=0
```

返修只执行上述结构和差异检查，未重跑全仓规格、公开文件检查或任何行为样本；下文保留首版实际回执，不用作返修行为证据。提交仅在本地，交 V184 原审阅者定点复看。

## 首版提案记录（`93a8a393`）

**结论：** 默认工作文件由现有测试目录工具创建和回收；明确指定的场景日志不删，要求保留的私有项目仍放在原 `run-*` 路径。现有 smoke 的三个证据目录仍在它自己的临时目录里，由 smoke 决定是否保留。P459 的现场记录和 V176 的直接调用原件都同时使用场景日志和私有项目状态，因此不搬迁已要求保留的 `run-*`。

## 交付

| Paths under `openspec/changes/reminder-test-temp-root-ownership/` | What they decide |
|---|---|
| `.openspec.yaml`, `proposal.md` | 原生元数据、两份测试的范围与不改事项。 |
| `design.md` | 六个待改测试文件各自的必要性；三条真实 Pi shell 入口共用一个负责回收的进程，直接调用也走同一路径；故障 shell 保留自己的隔离检查，直接调用只取得同一目录管理，不新增检查或改变退出结果。socket 放不下时仍用本轮独有的短路径，不碰共享 server。 |
| `specs/verification/spec.md` | 一条仅适用于两份测试的要求，三条可证伪场景；不修改正式规格里的通用临时目录要求。 |
| `tasks.md` | 将真实成功、具名失败和一次 TERM 与短入口等价样本分开，既验证路径和原件，又不用重复旧业务矩阵。 |

## OpenSpec assessment

| Dimension | Proposal author evidence |
|---|---|
| Completeness | 六个拟改文件都有出处；三条场景映射到 Apply 1.1–1.2 和检查 2.1–2.5。后续任务全未勾选。 |
| Correctness | 新变更单独严格校验通过；默认回收、显式保留、超长私有 socket 和中断没有执行。本报告不是实现验证。 |
| Coherence | `smoke.sh` 现有 §67–69 三次调用均明确指定各自的 `P442_EVIDENCE` 与 `P442_KEEP=1`；方案不改这些调用。`tmp-root.sh` 已具备路径解析、登记、回收、短 socket 目录和进程登记，不增加另一套。 |

## Verification evidence

使用现有 `~/.bun/bin/openspec`；`--version` stdout 为 `1.16.0`，stderr 无输出，rc 0。校验时设 `OPENSPEC_TELEMETRY=0`。

```text
$ ~/.bun/bin/openspec validate reminder-test-temp-root-ownership --type change --strict
stdout: Change 'reminder-test-temp-root-ownership' is valid
stderr: (empty)
rc=0

$ ~/.bun/bin/openspec validate --all
stdout tail: Totals: 21 passed, 0 failed (21 items)
stderr: 222 warnings “Requirement text is very long (>500 characters)” and 1 warning “Purpose section is still a placeholder”
rc=0

$ git diff --check f99062e6 HEAD && git diff --cached --check && git diff --check
stdout: (empty)
stderr: (empty)
rc=0
```

首稿单独严格校验 stdout 空、rc 1，stderr 点名本次新增要求 `Requirement text is very long (>500 characters)`。把保留布局细节移到场景中后，正式候选单独严格校验 stderr 为空；没有改工具、正式规格或放宽此次变更的校验。

Ledger ban（在任务工作树执行）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
stdout tail: ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev scope=published files=2954 hits=0 names=ok user=resolved
stderr: (empty)
rc=0
```

**未验范围：** 提案阶段未跑 `tasks.md` 的行为样本、smoke、全仓严格验证、安装、性能和任何真实提醒或模型；没有更新产品、现用配置或团队待命状态。缺陷翻转是后续任务 2.5，当前无实现翻转证据。

## Decisions and next step

空 `P442_EVIDENCE` 不是明确选定的目录，提案按未指定处理；原对抗 shell 已这样做，证据中已知的直接调用使用非空路径。`P442_KEEP` 与 `P444_KEEP` 仍按原先的非空规则解释。

仅本地提交。请非作者先审阅显式证据、退出结果与私有 socket 边界；等 PM 正式接受提案后才能实施。
