# V204 · 独立核对 PM 待命说明与普通巡检消息

**候选通过（2.2），合并版待核（2.3）。** 新默认仅在没有可推进工作、没有任务或复验运行、也没有自动结果待返回时，允许 PM 带理由自行进入待命；项目要求由人决定时，仍由人决定。普通巡检消息只保留待办摘要和查看详情指令。整份 `common.sh` 的字节对照只差这一处尾句，不改变巡检、待命或提醒的处理方式。

agent: verify · status: PASS（候选文字及范围） · time: 2026-11-26T02:07:21Z

branch: `task/V204-pm-standby-guidance-wording-verify` · PR/MR: -

## Deliverables

| Path | What |
|---|---|
| `docs/team/reports/V204-verify.md` | P510 的独立候选审阅与合并前证据；作者 dev-bob。 |

固定只读检出 `/var/tmp/p510-review-efe923d1.WXoGCS`，实际 apply 基线 `a3f80d3fdca3400d4cfdc0a187c23e3ae9ffab89`，受检产品候选 `ddc39ac8f23b7b132437df27246a0a87e15a959c`，交付 `efe923d16c9e59c052a6590888b4e3d7e7cea429`。最后两者之间只新增作者报告，10 份产品文件与实施清单字节一致。受审方案 `defb5f1b847202051e9302253aec770f56f15c92` 和基线的 change 工件无差异，见 D270 与 `docs/team/reviews/clarify-pm-standby-guidance-proposal.md`。

## OpenSpec assessment

固定检出及本席工作树均无生成的 `.pi/skills/openspec-verify-change/SKILL.md`；按 `skills/teamsmith/references/openspec.md` §6 做等效静态评估。正式 `init-skill` 条款未改；相对于被替换的现行条款，拟议文本保留原六个场景，只把其中的三文件核对限定为此前的授权说明变更，并新增两段待命规定和一个待命场景。

| Dimension | Verdict | Evidence |
|---|---|---|
| Completeness | 2.2 通过 | 逐处核对下列九份指令和一行巡检消息。`tasks.md` 仅作者的 1.1–1.4、2.1 从未勾改为已勾，2.2/2.3 原样，本席未改清单。 |
| Correctness | 静态场景通过 | `AGENTS.section.md.tmpl:115–120`：无事且只等人的决定可符合条件；空看板、回合结束、仍有任务或复验、仍待后台结果都不是进入待命的理由；若项目留给人决定，前面条件都满足也不自行进入。人工解除与实际唤醒且匹配本次待命的定时提醒是两条原有路径。`common.sh:4813` 改前后见下。 |
| Coherence | 通过 | 启动、日常指令与项目规则一致；三种回合结尾、返回查看后台结果、原授权和升级分步授权保留。`migration.md:29–67` 与 `cmd-project.sh:506–535` 给出明确采用的原路径；`cmd-watch.sh:2338–2344` 的 Pulse 重启动作只停启巡检，不写 AGENTS。共享链接的后续读取仍可能看到新源，不等于替换既有项目的 AGENTS、已读会话内容或待命状态。 |

### 九处指令与巡检消息

以下路径以仓库根为基准；简写 `T = skills/teamsmith/templates`、`R = skills/teamsmith/references`。

| 位置 | 对照结果 |
|---|---|
| `T/AGENTS.section.md.tmpl:111–120` | 巡检机制和两处原引用保留；完整默认规则只在这里，含带理由进入、项目优先、人工解除和匹配的实际提醒例外。原自主推进授权段字节未改。 |
| `T/pm-prompt.md.tmpl:11,111–130,154–159` | 开头只在 Pulse 未运行且不在待命时启动；硬阻塞说明只删 `and stand down`；人工阻塞仍记同一 inbox 或线程，后段回指 AGENTS。三个结束状态及完成后回到会话的段落保留，升级段字节不变。 |
| `T/PROTOCOL.md.tmpl:89–91` | 保留巡检与非自动恢复说明，原进入/清除指令只改为引用 AGENTS。 |
| `skills/teamsmith/SKILL.md:3,58,83,113,212–219` | 描述删无条件待命表述；生命周期表和巡检规则引用 AGENTS，启动 Pulse 的条件、自主推进指引及升级授权不变。 |
| `R/protocol.md:430–431` | 仅说明普通唤醒暂停、积压照记；指向 AGENTS 和实际存在的 `workflows.md#standby`。 |
| `R/workflows.md:403–410,461,480–506` | 快速入口删无条件 on/off，`Standby` 小节保留命令示例但先引用规则，将 off 标成人工动作；积压、`team digest`、关联提醒及更晚待命状态不被误清的段落字节不变，人工维护段未改。 |
| `R/troubleshooting.md:567–568` | 不再将两类等待一概视为可进入，改为连接已有 `#standby` 小节。 |
| `skills/teamsmith-init/references/bootstrap.md:75` | 停止巡检只列 `team pulse down`，不附进入待命指示。 |
| `README.md:17` | 同一行只将原 PM 可自行待命的表述改为说明待命暂停普通唤醒。 |
| `skills/teamsmith/scripts/lib/common.sh:4807–4817` | 只删 `team_nudge` 一条消息里 `看详情` 后的尾句；调用点 `cmd-watch.sh:637`、其余消息、记录、发送、排队、去重、恢复和提醒逻辑不变。 |

`smoke.sh:6672–6673,8279,9079–9092,12053–12054` 与 `task-model-routing.sh:1007–1008` 只读对照：原 `team digest`、`Your creed`、三种结尾、`team_bg_run`/`let the turn end`/`harvest point`/`team_bg_wait`、`does not satisfy delegation`、`separate recorded gates` 等匹配文本未改，`pm-prompt.md` 路径也未改。不是这些测试的运行结果。原提醒说明、面板人工操作及正式规格均不在写集。

## CRITICAL

无。

## WARNING

无。

## SUGGESTION

无。

## Final assessment

- CRITICAL 0 · WARNING 0 · SUGGESTION 0。接受冻结候选的文字和范围；不能据此称合并版已核对或可收尾定稿。
- 2.3 仅在 PM 固定合并版后由本席做相同文字的字节比对和写集核对。只复用作者报告的单变更 strict、`spec-refs --check` 和 `bash -n`（作者所记退出码均为 0），未在本轮重跑。未执行现有文字匹配测试、行为测试、全仓检查、模型、会话读取、模板生成、真实会话、升级、Pulse 或待命操作；不改变发布前检查要求。

## Verification evidence

```text
$ git -C "$f" diff --check "$b..$d"
diff-check rc=0
$ git -C "$f" diff --name-status "$b..$d"
M  README.md
A  docs/team/reports/P510-dev-bob.md
M  openspec/changes/clarify-pm-standby-guidance/tasks.md
M  skills/teamsmith-init/references/bootstrap.md
M  skills/teamsmith/SKILL.md
M  skills/teamsmith/references/protocol.md
M  skills/teamsmith/references/troubleshooting.md
M  skills/teamsmith/references/workflows.md
M  skills/teamsmith/scripts/lib/common.sh
M  skills/teamsmith/templates/AGENTS.section.md.tmpl
M  skills/teamsmith/templates/PROTOCOL.md.tmpl
M  skills/teamsmith/templates/pm-prompt.md.tmpl
delivery paths rc=0
$ git -C "$f" diff --name-status "$c..$d"
A  docs/team/reports/P510-dev-bob.md
candidate-to-delivery paths rc=0
$ git -C "$f" diff --exit-code "$a..$b" -- "$p"
accepted proposal to apply base rc=0
$ git -C "$f" diff --exit-code "$b..$d" -- "$p/.openspec.yaml" "$p/proposal.md" "$p/design.md" "$p/specs" openspec/specs
accepted artifacts and baseline spec unchanged rc=0
$ git -C "$f" diff --unified=5 "$b..$d" -- README.md skills "$p/tasks.md"
full planned diff rc=0
$ GIT_OPTIONAL_LOCKS=0 git -C "$f" status --porcelain=v1 --branch
## HEAD (no branch)
frozen checkout status rc=0
```

`f` 为上述固定检出，`a/b/c/d` 分别为方案、实际基线、产品候选与交付提交，`p=openspec/changes/clarify-pm-standby-guidance`。另用 `python3 -` 只读调用 `git -C "$f" show <rev>:<path>`，比较实际路径集合、候选和交付的文件字节、精确的 `common.sh` 后缀删除、清单勾选和原匹配短语及段落；用 `difflib.SequenceMatcher` 单独比较 `init-skill` 目标条款与变更文本。实际输出：

```text
write set: 10 product paths + 1 checklist modified + 1 author report added; candidate/delivery: 11/11 same
common.sh: full byte comparison exact (396383 -> 396251 bytes); old suffix matches 1 -> 0; new line matches 1
tasks.md: only 1.1-1.4 and 2.1 checked; 2.2 and 2.3 still open
templates/pm-prompt.md.tmpl: 14/14 existing read-only text matches retained
references/migration.md: 3/3 existing read-only text matches retained
exact paragraphs: startup/daily upgrades, shared authorization, workflow backlog and Reminder all unchanged
read-only comparison rc=0
target requirement: six old scenarios retained, one historical WHEN clarified, one standby scenario added
requirement comparison rc=0
```

账本扫描（本席工作树，仅报告交付检查）：

```text
$ TMPDIR=/var/tmp bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<verify-worktree> scope=published files=3149 hits=0 names=ok user=resolved
ledger-ban rc=0
```

## Flip evidence · 源文字前后对照

```diff
-  msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情；若确实没活可推或需人工介入，跑 $TEAM_CLI standby on --reason \"…\" 让自己停下（之后不会再叫醒你）"
+  msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情"
```

同一基线共用模板说 on/off 由人决定，启动说明后段却要求 PM 在需要人工介入时自行 on。候选同一次比对显示启动说明不再发出命令、共用模板有唯一条件。未执行消息投递或唤醒；本案红绿证据是规定的源文字对照。

## Decisions and deviations

无偏离。只提交本报告，不写固定源、现有项目文件、运行状态或 V196，不推送、不合并。PM 如接受本轮，可固定合并版后交由本席完成 2.3。
