# P402 · 既有项目上 init 渲染受管块时用契约里的会话名与名册

agent: dev   status: delivered for independent review   time: 2026-11-03T02:16Z
branch: `task/P402-init-render-from-config`   PR/MR: -（local 模式，分支留在本地）

## 结论

受管块不再写假事实：既有合法契约 + 非 `--force` 的裸 `team init` 现在从契约现值取
`TEAM_SESSION` / `TEAM_AGENTS` / `TEAM_DOCS_DIR` / `TEAM_PM_WINDOW` / `TEAM_GATES`，显式参数仍优先，
新项目（无契约）行为不变，`--force` 仍按显式参数/新默认重渲染。现场那一格（`TEAM_SESSION=teamsmith`、
`TEAM_AGENTS="dev verify dev2 dev3 dev-bob"`）在夹具里复现为 `cfg-session` + `alice bob carol`：改后裸 init
写出的受管块与「同一组参数显式渲染」逐字节相同，契约字节不变，`docs/team` 不再被重新造出来。

验收全部真跑：完整 `install-shape.sh` ✓203 ✗0、`install-shape.sh flip` ✓48 ✗0、smoke `--select 17`
的 §17 ✓65 ✗0（选段总 ✓216 ✗0）、`openspec validate --all --strict` 22/22、spec-refs / section-select /
ledger-ban / `git diff --check` 全 0。红侧是一条具名断言 + 一条对照 + 一个窄变异：把回落顺序关掉后，
同一断言变红并点名 `f-init-render-red:pm` 与 `dev verify`；还原即绿。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `team_cmd_init` 的取值回落：既有契约且非 `--force` 时，未在命令行给的 `session/agents/docs/pmwin/gates` 用 `team_config_file_value` 取契约现值（唯一读取器，没有第二套解析）；`gates_from_config` 只标记「这个值来自契约」，让空值也按现值渲染，不再被检测结果替换 |
| `skills/teamsmith/tests/install-shape.sh` | `init_cfg_fixture`（非默认渲染参数建契约）、`chk_init_render_from_config`（承重判据：整块 `cmp` 等于显式渲染 + 单条点名）、`chk_init_defaults_fresh`（对照组）；install 段 ②b 与 flip 段 ⑮ |
| `openspec/changes/instruction-context-slimming/specs/init-skill/spec.md` | 渲染参数条款改成「既有契约取现值、默认值只用于新项目或缺键」，并新增场景「A bare refresh on a valid contract renders that contract's own parameters」 |
| `openspec/changes/instruction-context-slimming/design.md` | 同一段的「即使有配置也取目录名/硬编码默认」改成契约优先，保留 `main` 保护分支渲染值这条已知限制 |

## Verification evidence

完整矩阵（brief 要求的那条，无参数）：

```
$ bash skills/teamsmith/tests/install-shape.sh
== surfaces · … ==
== install · link/--copy/--no-skills/幂等/.gitignore/linked worktree/bootstrap 升级路径 ==
…
== flip · 每条承诺一个 scratch 树红侧（真实树不动；结束比对 git status） ==
== 结果 ==  ✓ 203  ✗ 0  SKIP 0
$ echo $?
0
```

本片新增的三条具名断言与 ⑮（同一份判据在正常段与 flip 段各跑一次）：

```
$ bash skills/teamsmith/tests/install-shape.sh install flip
  ✓ P402 夹具：非默认渲染参数写进契约
  ✓ P402 裸 init 取契约里的 session/名册/docs/PM 窗口/门禁（整块等于同参数的显式渲染）：裸 init 写出 cfg-session:cfg-pm + 名册 + docs/crew + 门禁，整块等于显式渲染，契约字节不变
  ✓ P402 对照：无契约的新项目裸 init 写目录名与默认名册：无契约：目录名 p-cfg-fresh + 默认名册 dev verify + docs/team
  ✓ ⑮ 对照：真实树裸 init 取契约现值：…
  ✓ ⑮ 翻转：回落顺序退回目录名/硬编码默认（不看契约现值）：翻转后红（… `f-init-render-red:pm` … `Roster: alice bob carol` → `dev verify`）
== 结果 ==  ✓ 136  ✗ 0  SKIP 0
```

单独的 flip 段（brief 点名的段名，不是 `--flip`）：

```
$ bash skills/teamsmith/tests/install-shape.sh flip
  ✓ ⑮ 对照：真实树裸 init 取契约现值：裸 init 写出 cfg-session:cfg-pm + 名册 + docs/crew + 门禁，整块等于显式渲染，契约字节不变
  ✓ ⑮ 翻转：回落顺序退回目录名/硬编码默认（不看契约现值）：翻转后红（裸 init 的受管块与同参数的显式渲染不同（实际 9948 字节 / 期望 9949 字节）：4c4 < A **PM (orchestrator)** in tmux `cfg-session:cfg-pm` … --- > … `f-init-render-red:pm` … 6c6 < Roster: alice bob carol … ）
== 结果 ==  ✓ 48  ✗ 0  SKIP 0
$ echo $?
0
```

smoke §17（迁移指南与 doctor 指引；这一段里的 init 都带显式参数，本片没有删改它的任何一行）：

```
$ bash skills/teamsmith/tests/smoke.sh --select 17 </dev/null
== 选段 == decision=RUN · 运行 10/135 段 · 未跑 125 段
#5 2 · init · … ✓39 ✗0 SKIP0
#10 17 · 迁移指南与 doctor 指引（M7.1） · 参考 用时 11s · ✓65 ✗0 SKIP0 · ticks 65
== 选段结果 ==  ✓ 216  ✗ 0
== 选段：这次没跑的段 == 125 个键
0e 0f 0g 0h 0i 1 1b 1c 3 4b 4c 6 6b … 64 65
$ echo $?
0
```

这条是选段结果，不是全套门禁：125 段没跑（运行自己点名了键），本报告不声称整套绿。

静态与账本门（本分支树，最终 tip `067d9a56`）：

```
$ ~/.cache/openspec-1.8.0/node_modules/.bin/openspec validate --all --strict
✓ spec/writing-discipline
Totals: 22 passed, 0 failed (22 items)
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 120 reference(s) (48 distinct) in 13580 effective line(s); retired 1; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1
$ echo $?
0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=2308 hits=0 names=ok user=resolved
$ echo $?
0

$ git diff --check
$ echo $?
0
```

- Verdict: pass for everything the brief lists.
- Notes（没测到什么、已知边界）：
  - **没有对真实项目跑 init**（brief 边界）：唯一一次 live init 是 PM 2026-11-03 手工做的；这里的证据全部来自
    `install-shape` 的一次性夹具。
  - **没有跑全套 smoke**，也没有跑容器内的整套门禁；上面 smoke 是 10/135 段的选段。
  - `install-shape.sh` 的 flip 段自带「夹具没碰真实树」指纹绊线：第一轮红过一次 `✗ ⑥ 夹具没碰真实树`，
    原因是我在它后台运行时提交了文件（`…/state/bg/p402-install-flip.log` 记着 `rc=1` 与 `✓135 ✗1`）。
    在干净树上重跑后 `flip_rc=0`；这个绊线是对的，没有改它。

## Flip evidence (required for defect-fix tasks)

现场（brief 记录的既有事实）：`TEAM_SESSION="teamsmith"`、`TEAM_AGENTS="dev verify dev2 dev3 dev-bob"`
的项目上跑裸 `team init --no-skills`，受管块写成 `pm-skills:pm` / `dev verify`；只有显式
`--session teamsmith --agents "dev verify dev2 dev3 dev-bob"` 才正确。

夹具（`init_cfg_fixture`：`--session cfg-session --agents "alice bob carol" --pm-window cfg-pm
--docs docs/crew --gates "make check"`）上，同一个判据的两侧：

```
$ <真实树> bash skills/teamsmith/tests/install-shape.sh install
  ✓ P402 裸 init 取契约里的 …（整块等于同参数的显式渲染）

$ <把 cmd-project.sh 的 `if [ "$had_config" = "1" ] && [ "$force" != "1" ]` 改成 `if [ "0" = "1" ]`，只改 scratch 副本>
  ✓ ⑮ 翻转：回落顺序退回目录名/硬编码默认 … 翻转后红
    （`tmux `cfg-session:cfg-pm`` 变成 `tmux `f-init-render-red:pm``，`Roster: alice bob carol` 变成 `dev verify`）
```

还原（变异的树只存在于 `$TMPDIR` 的 scratch 副本，真实树由 flip ⑥ 的 `git status` 指纹兜住）：

```
$ bash skills/teamsmith/tests/install-shape.sh flip
  ✓ ⑮ 对照：真实树裸 init 取契约现值
$ echo $?
0
```

## Decisions and deviations

1. **同一条 delta 的规格与设计同步（请 PM 认定）**：`openspec/changes/instruction-context-slimming`
   的 init-skill delta 原来把「即使有配置也用目录名/`dev verify`」写成预期行为，并要求指引点名这些默认值。
   本片的修复让那句话变成假的，所以我改了两处文字（`spec.md` 的同一段条款 + 新增一个场景、`design.md`
   的同一段），并保留 `main` 保护分支这个真正的限制。若 PM 认为这属于提案层面、不该由 apply 任务改，
   回退这两个文件的 hunk 即可，代码与测试不依赖它们（那是 `git revert --no-commit 067d9a56` 的范围）。
2. **`gates_from_config` 是函数内的局部标记，不是新旗标**：契约里 `TEAM_GATES=""` 是「未配置」，而检测值
   不是契约现值；只有加这个标记才能区分「键缺失（走默认）」与「键存在但为空（按现值渲染 `<未配置>`）」。
   没有新增命令/旗标/配置键，也没有第二套解析器。
3. **断言放在 `install-shape.sh`（install 段 ②b + flip 段 ⑮），不动 smoke §17**：那里已有 init/受管块/
   flip 的机制，且 brief 要求「既有 install-shape / smoke §17 的相关行不许删」——smoke §17 一行未动，
   本次只真跑它作为回归。
4. **`--force` / 新项目路径的分支没有合并**：对照组专门断言「无契约的新项目裸 init 仍写目录名 + 默认名册」，
   防止修复退化成「所有情况都先读环境」。

## Suggested next steps

- PM 复验：`bash skills/teamsmith/tests/install-shape.sh` 与 `… install-shape.sh flip`；独立 checkout 上
  重点看 ②b 的整块 `cmp` 与 ⑮ 的翻转输出。
- 若采纳第 1 条，请把 delta 的这处修订纳入本次 change 的评审结论；若不采纳，按上面的回退范围处理。
- change 里 2.5 的既有项目指引将来落笔时，应按新条款写「有合法契约 → 取契约现值；新项目才是目录名/默认」。
  本片没有改 `references/migration.md`（P400/P401 的范围）。
