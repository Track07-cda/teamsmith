# A15 · 同步两份提醒测试的目录管理要求

agent: dev3 · phase: archive · status: DELIVERED · time: 2026-11-20T09:55:48Z · branch: `task/A15-archive-reminder-test-temp-roots` · PR/MR: -（local）

## 结论

OpenSpec 1.16.0 已将已独立验证的提醒测试要求同步到 `verification` 正式规格，提交 `c14f403464f5e69d8987736d7b65783aad5eb35c`。仅新增一条要求和三个场景，五份工件原样移动；试做与实际结果一致，原规格正文和可执行文件不变。普通结构校验 20 项通过，引用检查 122 处无问题。

## 交付与对照

| 路径 | 核对结果 |
|---|---|
| `openspec/changes/archive/2026-11-20-reminder-test-temp-root-ownership/` | `.openspec.yaml`、`design.md`、`proposal.md`、`specs/verification/spec.md`、`tasks.md` 与原 Git 文件逐字节一致，五项均 `R100`；原活动目录不存在。 |
| `openspec/specs/verification/spec.md` | 原 193,964 字节完整保留，包括标题、Purpose、通用临时目录要求及原有场景顺序；末尾仅增加一个分隔空行和 1,572 字节的已接受要求正文。 |
| `docs/team/reports/A15-dev3.md` | 本报告；原件保留在本人独有的 `/var/tmp/a15-reminder-archive.1aheiX`，下文称 `E`。 |

新增要求为 `Reminder test evidence is distinct from disposable work`。三个场景按原顺序逐字匹配：调用者指定的真实 Pi 证据位置、默认场景输出随工作目录保留或删除、显式保留故障记录时报告其工作目录。试做和实际的整棵 `openspec/` 共 512 个文件逐份比对字节及模式均相同；归档前后另比对 3,269 个 OpenSpec 之外的已跟踪路径，SHA-256 和文件模式一致。相对获验收的合并版，归档基线的 `skills/`、`.github/` 和 `ci/` 无差异，五份工件仅 `tasks.md` 多了 PM 接受后补勾的 2.x 五项；归档未改这些勾选。原件见 `trial-compare.log`、`actual-compare.log`、`trial-spec.diff`、`actual-spec.diff`、`archive-staged-status.log` 和 `non-openspec-*.sha256`。

## 验收依据与命令回执

D265 依据 D241 授权；P485/V184/P486/V185 已关闭，基线 `a071ac3d` 包含独立验证的合并版 `191e80974eca1a633f7affd9d66bea110d2384cb`，`git merge-base --is-ancestor` 退出 0。实现者 dev-bob，独立验证者 verify；使用 `docs/team/reviews/P486.md`、`docs/team/reviews/V185.md` 与 `327cab87`。原候选 `f7db9e77` 和 `f18c60e4` 两次 FAIL 保留；第三轮核实私有 Pi 退出后才清理及两个启动刻度读数，其他四项沿用首轮原件。合并版 PASS 只核字节、语法与接入，不算重跑行为。

使用现有 `PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0`。下列五条均退出 0、stderr 为空；原命令、JSON 和退出码在 `E`。

```text
$ openspec --version
1.16.0
$ openspec list --json
reminder-test-temp-root-ownership: completedTasks=7 totalTasks=7 status=complete
$ openspec status --change reminder-test-temp-root-ownership --json
isComplete=true; proposal/specs/design/tasks: done
$ openspec instructions archive --change reminder-test-temp-root-ownership --json
$ openspec instructions specs --change reminder-test-temp-root-ownership --json
```

以上为 JSON 要点摘录：根解析为本人 `.worktrees/dev3`，`root.source=nearest`、`planningHome.kind=repo`；`specs` 只有 `verification` 的差量文件，其中只有一项 `ADDED`。先用 `cp -a --no-preserve=links openspec "$E/project/openspec"` 建普通副本，`diff -qr` 比对复制前后相同，`tasks.md` 两个 inode 不同。先在 `E/project` 试做、审完差异，再在本人仓根执行一次相同原生命令；未使用跳过选项、升级、手工合并或移动。两次 stdout 逐字相同，stderr 为空，rc=0。

```text
$ openspec archive -y reminder-test-temp-root-ownership
Task status: ✓ Complete

Specs to update:
  verification: update
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 1, ~ 0, - 0, → 0
Specs updated successfully.
Change 'reminder-test-temp-root-ownership' archived as '2026-11-20-reminder-test-temp-root-ownership'.
```

归档提交上实际执行下列命令，后台作业 `A15-archive-short-checks` 已收取，整体退出 0。结构校验 stderr 含 222 项要求长度超过 500 字符的提示及 1 项 Purpose 占位提示；未为消除提示改写任何旧正文。引用检查 stderr 为空，差异检查 stdout/stderr 均为空。

```text
$ openspec validate --all
Totals: 20 passed, 0 failed (20 items)
rc=0
$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 122 reference(s) (49 distinct) in 14308 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0
$ git diff --check a071ac3d HEAD
rc=0
```

### 账本发布与报告差异检查

在本人工作树暂存报告后，使用既有名单路径执行账本检查；未读取名单正文。回执写入报告后再次检查最终稿，原件见 `E/ledger-receipt.*`、`E/ledger-final.*`。

```text
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev3 scope=published files=2971 hits=0 names=ok user=resolved
$ echo $?
0
$ git diff --check
rc=0
$ git diff --cached --check
rc=0
```

三项 stderr 均为空；两项差异检查 stdout 也为空。

## 未执行范围与交接

仅同步规格，不是修复实现，不新增缺陷翻转。未运行提醒行为、实际队列、清扫、性能、完整测试、真实模型或全仓 strict；不据此声称旧记录兼容。仅在本人任务分支本地提交，不推送、不合并、不改看板。试做与命令原件留给 PM 核对，未清理目录。
