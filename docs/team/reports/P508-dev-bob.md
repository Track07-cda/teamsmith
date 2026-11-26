# P508 · 统一 PM 待命说明

agent: dev-bob   status: DELIVERED（仅方案，V201 R1 返修）   time: 2026-11-26
branch: `task/P508-pm-standby-guidance-proposal`   PR/MR: - (local)

**结论：采用新默认说明后，项目若未规定由用户决定，PM 在没有可推进的工作、没有运行中的任务或验证、也没有自动返回的结果在等时，可以写明原因进入待命，无需再问。** 只等人的决定可满足这一条件；空看板或本轮结束不能作为依据。PM 不自行解除待命。普通 Pulse 唤醒暂停，人工解除和实际发生的定时提醒唤醒仍按现有规则处理。

**拟改九个文件中的说明和一条巡检消息，未改任何现有指令、脚本或项目。** 规则只放在生成的 AGENTS 共用段；PM 开场只说明何时启动 Pulse，后段和 PROTOCOL 指回 AGENTS。每日技能、四份参考文档和 README 的冲突措辞逐处列在 `design.md`；纯人工维护、三种合法结束方式、后台结果回到原会话和升级授权原文保留。新项目生成或已有项目明确采用后才生效，改源码或重启 Pulse 不替换旧指令。

**本次只做了静态校验。** 未实现、未启停 Pulse 或待命、未渲染或刷新项目、未启动会话或调用模型、未运行行为测试、构建或全套检查。没有可执行修复，不适用运行前后对照。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/clarify-pm-standby-guidance/{proposal,design,tasks}.md` 和 `.openspec.yaml` | 原生说明、最小写集、待实施清单；`aa803bef`。 |
| `openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md` | 唯一 `MODIFIED`，不改正式规格文件。 |
| `docs/team/reports/P508-dev-bob.md` | 本次静态检查回执。 |

## OpenSpec assessment

| Dimension | Planning evidence |
|---|---|
| Completeness | 四类 `spec-driven` 工件齐全。席位没有项目已生成的 `openspec-propose` 技能，按已安装模板的规划边界及本仓 `openspec/config.yaml` 写原生文件，未运行额外生成命令。实施清单未勾选。 |
| Correctness | 严格验证与规格引用检查均退出 0。与基线 `d7976a63` 的目标条文相比，只增加两段待命正文和一个文字审阅场景，并把旧「三个指令源」场景的检查对象明确限定为引入原自主推进规则的变更；其余原正文和原场景不删。 |
| Coherence | 设计按已接受的 P504 冲突入口逐项定位；既有 `watchdog`/`agent-self-reminder` 运行规则不改。由非作者读实施前后文字，核对空看板、在途结果、仅等人、项目优先四种情况和现有文字匹配；本次未执行这些行为。 |

## V201 R1 · 返修证据

`cmd-watch.sh:630–641` 有待办且 PM 正在运行时，可调用 `team_nudge`；`common.sh:4813` 的普通消息仍附带待命命令和「之后不会再叫醒你」。`7a60614f` 将这一条写入方案、设计、清单和原待命审阅场景。以后实施只删 `digest 看详情` 后的分号和整段尾句，不补文字，原前缀、摘要、查看命令和语言原样；不改其他消息、计数、投递、排队、重复提醒处理、恢复或待命与定时提醒行为。源码读取确认该消息去向；已有 `smoke.sh:6729` 只匹配 `pulse`，未运行这项检查。

沿用下节环境运行：

```text
$ openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive
Change 'clarify-pm-standby-guidance' is valid
validate rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14607 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec-refs rc=0
$ git diff --check 6c7675d2
diff-check rc=0
$ git diff --exit-code d7976a63 -- skills README.md openspec/specs AGENTS.md .pi
source+baseline unchanged rc=0
$ git diff --name-status 6c7675d2
diff scope rc=0；方案返修只有 proposal、design、tasks 和 init-skill 变更草案，另更新本报告。
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<P508-worktree> scope=published files=3126 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Verification evidence · 首轮

在本席位目录运行。OpenSpec 命令使用 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。

```text
$ openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive
Change 'clarify-pm-standby-guidance' is valid
validate rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14606 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
spec-refs rc=0
$ git diff --check
rc=0
$ git diff --cached --check && git diff --cached --name-status
rc=0；方案提交只有上述五份 OpenSpec 文件。
$ git diff --cached --name-status d7976a63
scope rc=0；相对基线只新增上述五份文件及本报告，未改已有文件。
```

旧条文逐行比对使用以下命令；退出 1 表示确有上述定点差异，不是校验失败。

```bash
diff -u -L 'base requirement' -L 'planned delta' \
  <(git show d7976a63:openspec/specs/init-skill/spec.md | awk '/^### Requirement: Installed team instructions / {inside=1} inside && /^### Requirement: Explicit init / {exit} inside') \
  <(tail -n +3 openspec/changes/clarify-pm-standby-guidance/specs/init-skill/spec.md)
```

Ledger ban（根路径已遮蔽）：

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<P508-worktree> scope=published files=3126 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Decisions and deviations

无范围偏离。不推送、不合并、不归档。返修交原 V201 定点复看，接受后另派实施；不是采用新说明的授权。
