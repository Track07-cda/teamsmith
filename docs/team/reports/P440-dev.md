# P440 · 生成的复验记录与 PROTOCOL 不再写入绝对家目录

agent: dev   status: DONE   time: 2026-11-10T10:23:25Z
branch: `task/P440-ledger-path-generation`   PR/MR: -

结论：两个生成源及 V146–V148 的定点返修均已完成。真实 `team review` 保留执行者、reviewed SHA、门禁命令和结果；显示净化不再枚举分隔符，`root/` 直接替换，裸 `root` 只排除 ASCII 字母数字后缀及后随字母数字的 `-_.`。root/HOME 的句末 `. - _` 均净化，兄弟前缀目录保持原样。C 与 UTF-8 locale 的标点矩阵输出一致，HOME 下 checkout、门禁命令及夹具期望均按 `<home>/…` 显示。红侧仍先确认真实 review `rc=0`、记录存在及 `PASS`，再只因绝对路径判红。`team init` 三种形状与隔离项目公开账本 `hits=0` 的结论保持不变。本分支继承的 15 处历史命中仍由 PM 按任务书清理，本任务未改历史文件。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-review.sh` | `root/` 直接替换；ASCII 字母数字及后随字母数字的 `-_.` 才算兄弟后缀，句末标点正常净化 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | 按源仓、普通项目、跳过安装三种形状生成 PROTOCOL 的项目相对技能路径或占位 |
| `skills/teamsmith/tests/smoke.sh` | 真实 verify 复验、三种 init 形状及两组红／绿／恢复行为测试 |
| `skills/teamsmith/tests/section-paths.tsv` | 登记 §17 新增测试实际读取的 `skills/teamsmith` 源仓路径 |
| `docs/team/reports/P440-dev.md` | 本报告 |

## OpenSpec assessment

本任务 `change: -`，锚定既有 `verification` 与 `init-skill` 规格；任务书未授权规格 delta，本次只修复生成行为，没有新增平行规格。

| Dimension | Score | Evidence |
|---|---|---|
| Completeness | 通过 | 任务书四项均落实：review 全记录显示净化、init 三种形状、既有禁令与证据语义不变、历史文件留给 PM |
| Correctness | 通过 | §10/§17 各有一组真实源码破坏 → 具名断言红 → 还原绿；隔离生成物另跑公开账本扫描 |
| Coherence | 通过 | review 只在显示层净化，执行仍用真实路径；init 复用既有安装形状，不新增配置键 |

## CRITICAL

None.

## WARNING

- 本分支既有 `docs/team/PROTOCOL.md`、`docs/team/reviews/P424.md`、`P439.md` 仍有 15 处历史绝对路径命中，`ledger-ban` 因而 `rc=1`。这些是任务书明确交给 PM 在 main 清理的旧文件；本次真实生成样例均为 `hits=0`，不能用新生成物的绿色结果宣称本分支整树禁令已经通过。

## SUGGESTION

None.

## Final assessment

- Counts: CRITICAL 0 · WARNING 1 · SUGGESTION 0。
- Readiness: 生成源修复及任务书指定的定点检查已具备独立复验条件；结论不扩展到未运行的全量门禁，也不把继承的历史账本命中算作通过。
- Unverified applicable checks and reasons: 按任务书未跑全量、夜间和 `61b`。§19 的 10 个机器生成 OpenSpec 资源按既有前提显示 SKIP，未计作通过。OpenSpec 按任务书运行 `validate --all`，未额外运行 `--strict`。

## Verification evidence (must have actually been run)

### 受影响选段

```
$ bash skills/teamsmith/tests/smoke.sh --select 10,10b,17,19 </dev/null
P440 review 绿：执行者/SHA/真实命令/结果保留，模板+锁+摘录+门禁尾部均无 main/home 绝对路径
P440 兄弟前缀路径逐字保留，不改成不存在的占位拼接
P440 不再把 main-root 的兄弟前缀吞成占位
P440 HOME 下 checkout 按显示规则写成 <home>/…
P440 红侧前提：变异体真实 review rc=0
P440 红侧前提：记录真的生成
P440 红侧前提：变异门禁结果仍是 PASS
P440 review 红：rc=0/PASS/记录存在后，仅因绝对 main/home 路径判红
P440 review 还原绿：同一私有副本恢复显示净化后断言通过
P440 init 普通项目：PROTOCOL 用真实存在的 .pi/skills 相对路径，不含 main/home 绝对路径
P440 init 源仓：PROTOCOL 用真实存在的 skills/teamsmith 相对路径，不含 main/home 绝对路径
P440 init --no-skills：只写明确占位，不伪造 .pi/skills 安装路径
P440 init 红：恢复绝对 SKILL_DIR → 断言红（absolute main root remains）
P440 init 还原绿：源仓相对路径与真实命令恢复
账本自查：15 段收口 · 增量 ✓393 ✗0 SKIP10 ｜ 结果行 ✓393 ✗0 —— 一致
== 选段结果 ==  ✓ 393  ✗ 0
$ echo $?
0
```

### V147 定点返修

```
$ bash skills/teamsmith/tests/smoke.sh --select 10,10b </dev/null
P440 C/UTF-8 标点矩阵（C）：净化一致且兄弟前缀保留
P440 C/UTF-8 标点矩阵（C.UTF-8）：净化一致且兄弟前缀保留
== 选段结果 ==  ✓ 264  ✗ 0

$ HOME=/var/tmp/p440-home-tmpdir TMPDIR=/var/tmp/p440-home-tmpdir/tmp bash skills/teamsmith/tests/smoke.sh --select 10 </dev/null
== 选段结果 ==  ✓ 189  ✗ 0

$ LC_ALL=C bash skills/teamsmith/tests/smoke.sh --select 10 </dev/null
== 选段结果 ==  ✓ 192  ✗ 0
```

矩阵覆盖中文冒号、`；！？、「」，。）：`、root 子路径及 `-_.` 三种兄弟后缀。HOME-TMPDIR 使用 `/var/tmp` 下的合成 HOME，验证门禁命令与兄弟 checkout 的期望不再写死原始绝对路径。

### V148 句末标点收口

```
$ bash skills/teamsmith/tests/smoke.sh --select 10,10b </dev/null
== 选段结果 ==  ✓ 264  ✗ 0

$ LC_ALL=C bash skills/teamsmith/tests/smoke.sh --select 10 </dev/null
== 选段结果 ==  ✓ 192  ✗ 0
```

矩阵新增 root 与 HOME 各自的句末 `. - _`：路径本体净化、标点保留；`pm-skills-ledger`、`pm-skills_other`、`pm-skills.cache` 三种兄弟路径仍逐字保留。

另以 `--select 10 --keep` 保留真实现场：

```
== 选段结果 ==  ✓ 180  ✗ 0
$ echo $?
0
```

### 真实 verify 复验记录与公开账本扫描

现场：`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.ZqeXLM/repo`。从该项目的 `.worktrees/verify` 清除继承身份后运行真实 `team review`，门禁是实际生成 gate 输出的脚本；随后运行公开文件账本扫描。

```
✓ 门禁输出：docs/team/reviews/T1.1-verify.log（PASS，0s）
✓ 复验记录：docs/team/reviews/T1.1.md（PASS）
ledger-ban: root=/var/tmp/teamsmith-smoke-pm_skills-deb708fe.ZqeXLM/repo scope=published files=15 hits=0 names=ok user=resolved
```

生成记录的关键原文：

```
时间: 2026-11-10T05:38:27Z · 分支: `task/T1.1-smoke-task` · HEAD: `87df77ed8` · 判定: **PASS**
- 实际执行者：`verify`
- 独立 checkout：`/var/tmp/teamsmith-smoke-pm_skills-deb708fe.ZqeXLM/review-checkout`
- 门禁命令：`bash /var/tmp/teamsmith-smoke-pm_skills-deb708fe.ZqeXLM/p440-review-gate.sh`
- 门禁锁：`<main-root>/.pi/team/state/p440-review.lock`
- agent 报告：`<main-root>/.worktrees/dev/docs/team/reports/T1.1-dev.md`
gate main=<main-root> home=<home>
- 主工作树：<main-root>
- 当前家目录：<home>
```

这证明独立 `/var/tmp` checkout 和真实命令仍保留，main-root、agent 报告、锁、报告摘录与门禁尾部走同一显示净化。

### init 三种真实生成形状

现场根：`/var/tmp/p440-init-shapes`。普通项目和源仓中渲染出的 `scripts/team` 均用 `test -f` 确认真实存在；`--no-skills` 不伪造该安装路径。

```
[normal] > `bash .pi/skills/teamsmith/scripts/team help`
ledger-ban: root=/var/tmp/p440-init-shapes/normal scope=published files=10 hits=0 names=ok user=resolved
[source] > `bash skills/teamsmith/scripts/team help`
ledger-ban: root=/var/tmp/p440-init-shapes/source scope=published files=10 hits=0 names=ok user=resolved
[no-skills] > `bash <skill-dir>/scripts/team help`
ledger-ban: root=/var/tmp/p440-init-shapes/no-skills scope=published files=10 hits=0 names=ok user=resolved
```

### 规格引用、选择器、OpenSpec 与差异检查

```
$ bash skills/teamsmith/tests/spec-refs.sh
spec-refs: judged 126 reference(s) (49 distinct) in 14202 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]

$ bash skills/teamsmith/tests/section-select.sh --check
ok: 段正文点名的真实路径 token 都被各自的行覆盖（578 个 token 检查过；0 个豁免类 token 不参与）
== 选段自检 ==  ok 13  bad 0  SKIP 1

$ openspec validate --all
Totals: 24 passed, 0 failed (24 items)

$ git diff --check
<无输出，rc=0>
```

本机交互 PATH 没有 `openspec`，实际通过其既有可执行入口 `$HOME/.bun/bin/openspec validate --all` 运行；此处 `$HOME` 是报告中的变量写法，不是落入账本的家目录字面值。

- Verdict: 上述生成物、选段、规格引用、选择器、OpenSpec 与差异检查通过；本分支整树账本禁令仍因既有历史文件失败，见下。
- Notes: 未跑全量、夜间、`61b`；§19 的 10 个前提 SKIP 和选择器的 1 个内部检出前提 SKIP 不计为通过。
- Ledger ban (fixed acceptance line — run it **in your own worktree, on your branch's tree**):

  ```
  $ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
  docs/team/PROTOCOL.md: [home]（既有生成文件）
  docs/team/reviews/P424.md: [home]（既有锁记录与 agent 报告）
  docs/team/reviews/P439.md: [home]（既有锁记录与 agent 报告）
  ledger-ban: root=<main-root> scope=published files=2562 hits=15 names=ok user=resolved
  $ echo $?
  1
  ```

## Flip evidence (required for defect-fix tasks)

两组翻转均在隔离项目的私有 skill 副本中恢复旧行为，未修改被测真树；每组随后还原同一副本并重新生成真实记录。

```
review 绿：review_record_ledger_clean rc=0
review 红：恢复 `} > "$report"` 直接写盘 → absolute main root remains，断言 rc=1
review 还原绿：恢复 `team_review_ledger_display` 写盘管道 → 同一断言 rc=0

init 绿：p440_protocol_paths_ok rc=0，且渲染命令真实存在
init 红：恢复 `SKILL_DIR=$TEAM_SKILL_DIR` → absolute main root remains，断言 rc=1
init 还原绿：恢复 `SKILL_DIR=$docs_skill_dir` → 同一断言 rc=0
```

V146 返修的改前／改后对照：

```
W1 改前（V146 真实复现）：<main-root>-ledger/…（不存在的拼接路径）
W1 改后：兄弟 checkout 真实 review rc=0 / PASS，独立 checkout 逐字保留，记录不含 <main-root>-ledger
W2 改前（V146 判据反例）：missing record 也会进入红侧 ok；HOME 下 checkout 的原样断言误红
W2 改后：红侧先过 rc=0、记录存在、PASS 三项前提，再分别确认绝对 main/home 存在，失败原因精确为 absolute main root remains；HOME 下 checkout 真实 review 显示为 <home>/checkout
```

V147 返修的改前／改后对照：

```
W1-a 改前：LC_ALL=C 下中文冒号后的 root 原样泄漏；改后 C 与 C.UTF-8 矩阵逐字一致，真实 C-locale 选段 ✓192 ✗0
W1-b 改前：root 后紧跟 ；！？、「」 时不净化；改后这些标点与 ，。）： 同样接受，兄弟 -_. 后缀仍保留
W2 余量改前：HOME-TMPDIR 下门禁命令和兄弟 checkout 三处期望误红；改后同一形状 ✓189 ✗0
```

V148 改前：root/HOME 后紧跟句末 `. - _` 时被误认为兄弟路径而不净化。改后：仅当这些字符后随 ASCII 字母数字才保留为兄弟后缀；句末用例在 C 与 UTF-8 下均转成 `<main-root>`／`<home>` 加原标点。

对应真实选段输出见上：V146 时 §10 `✓43 ✗0`、§17 `✓74 ✗0`；V147 起 §10 增加两条矩阵断言后为 `✓45 ✗0`。

## Decisions and deviations

- `--no-skills` 使用 `<skill-dir>` 明确占位，不把运行 CLI 的绝对路径或尚未安装的 `.pi/skills/teamsmith` 写成可用命令。
- 复验伴随的 `*-verify.log` 仍按现有 `.gitignore` 作为本地原始证据，不进入公开账本；任务书要求净化的生成 Markdown 记录已全覆盖。
- 未清理任何既有历史文件，严格保留给 PM。
- 无其他范围偏差。

## Suggested next steps

- 交 V148 做最终定点确认；随后在 main 清理既有 `PROTOCOL.md`、`P424.md`、`P439.md`，再运行整树账本禁令确认历史命中归零。
