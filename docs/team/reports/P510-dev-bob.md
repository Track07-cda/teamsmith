# P510 · 统一默认 PM 待命说明

作者检查通过，交非作者核对。完整待命条件只写进共用 AGENTS 模板；普通巡检消息保留待办摘要和 `digest 看详情`，不再指示 PM 进入待命，也不再承诺不会唤醒。现有项目的指令和状态不变。

agent: dev-bob · status: DELIVERED (apply) · time: 2026-11-26T01:56:44Z

branch: `task/P510-pm-standby-guidance-apply` · PR/MR: -

- 实际 apply 基线：`a3f80d3fdca3400d4cfdc0a187c23e3ae9ffab89`；本基线的方案工件与冻结方案 `defb5f1b8472` 无差异，独立方案审阅 `a95ac8bea0e7` 已由 `docs/team/reviews/clarify-pm-standby-guidance-proposal.md` 接受。
- 冻结实施候选：`ddc39ac8f23b7b132437df27246a0a87e15a959c`，含文字 `7599ea84`、消息 `1dceb73b` 与勾选 `ddc39ac8`；本报告单独提交，不改变候选的产品字节。

## 交付范围

| 路径 | 变更 |
|---|---|
| `skills/teamsmith/templates/AGENTS.section.md.tmpl` | 完整默认规则：项目要求优先；无可推进事项、无进行中的任务或复验、无待自动返回的结果时才可带理由进待命。保留人工解除和实际唤醒 PM 的对应 Reminder 例外。 |
| `skills/teamsmith/templates/pm-prompt.md.tmpl`、`skills/teamsmith/templates/PROTOCOL.md.tmpl` | 启动检查只说明 Pulse 未运行且不在待命时再启动；其余指向 AGENTS。保留人工阻塞的记录位置、三种回合结尾、后台结果返回和升级授权文字。 |
| `skills/teamsmith/SKILL.md`、`skills/teamsmith/references/protocol.md`、`skills/teamsmith/references/workflows.md`、`skills/teamsmith/references/troubleshooting.md`、`skills/teamsmith-init/references/bootstrap.md`、`README.md` | 各处撤掉相反的进入说明，只保留指引、作用说明或人工操作。积压记录、定时提醒例外和人工维护步骤保留。 |
| `skills/teamsmith/scripts/lib/common.sh` | `team_nudge` 的 `msg` 只删一个后缀；按候选与基线全文件字节比较确认。 |
| `openspec/changes/clarify-pm-standby-guidance/tasks.md` | 只勾选 1.1–1.4 和 2.1；非作者任务 2.2、2.3 保持未勾。 |

## OpenSpec 核对

实施前通过 `openspec status --change clarify-pm-standby-guidance --json` 和 `openspec instructions apply --change clarify-pm-standby-guidance --json` 选定本地变更，状态 `ready`、初始进度 `0/7`。与正式规格逐段比较同一条 requirement：原义务与六个场景都保留，原三文件场景只把核对对象限定为此前的授权说明变更；待命新增两段规则和一个场景。正式规格及已审方案、设计和变更条款未改。候选可交 2.2，不作独立验证或归档就绪判定。

## 作者实际检查

```text
$ PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0 openspec validate clarify-pm-standby-guidance --type change --strict --no-interactive
Change 'clarify-pm-standby-guidance' is valid
rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14607 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
$ bash -n skills/teamsmith/scripts/lib/common.sh
rc=0
$ git diff --check a3f80d3fdca3400d4cfdc0a187c23e3ae9ffab89..HEAD
rc=0（无输出）
```

`git diff --name-only` 对照设计文件清单，产品路径 `10/10 exact`；`git diff --name-status` 最终核对为表中 11 个 `M` 加本报告 1 个 `A`，共 12 条。`git diff --numstat <apply-base>..HEAD -- skills/teamsmith/scripts` 返回 `1  1  skills/teamsmith/scripts/lib/common.sh`。按 `git show <apply-base>:<path>` 取原字节，仅做一次下述文本替换，结果与候选整个 `common.sh` 逐字节相等。

账本扫描：

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=3142 hits=0 names=ok user=resolved
rc=0
```

## 缺陷改前改后：源文字证据

```diff
$ git diff a3f80d3fdca3400d4cfdc0a187c23e3ae9ffab89..ddc39ac8 -- skills/teamsmith/scripts/lib/common.sh
-  msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情；若确实没活可推或需人工介入，跑 $TEAM_CLI standby on --reason \"…\" 让自己停下（之后不会再叫醒你）"
+  msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情"
```

基线共用模板写 `a human's call`，同一基线启动说明却在后段指示 `team standby on --reason`；候选把进入条件放进共用模板，启动说明只引用该规则。此处是源文字对照，不是实际投递结果。

## 未运行及交接

没有偏离任务书。未运行模拟模型、会话读取测试、真实会话、模板生成、升级、Pulse、待命切换或全套测试；未刷新或更改现有项目，未推送、合并或发布。由非作者对冻结候选完成 2.2，PM 合并后由同一非作者按 2.3 比对合并版文字和范围。
