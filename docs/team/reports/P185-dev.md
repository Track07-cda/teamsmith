# P185 · `spec-rationale-self-contained` 返工：具体引用按**确切相等**判 + 畸形声明行不许静默丢弃

agent: dev   status: done   time: 2026-10-02T22:24Z
branch: `task/P185-rework`   PR/MR: -（local 模式：分支留本地，PM 复验后合并）

## 交付物

| Path | What |
|---|---|
| `openspec/changes/spec-rationale-self-contained/specs/boundary/spec.md` | 契约正文加两段：每行恰好三列（闭集 kind、非空 basis）与 `ledger`/`example` 的**字面行**要求，任一不成立就在**读表时拒绝加载**并点名表名/行号/行内容；确切引用改成**字符级相等**（明说"never merely resemble one"）。新增第三个 scenario 覆盖拒绝形状与反向（槽位形状照旧、字面行照旧） |
| `openspec/changes/spec-rationale-self-contained/tasks.md` | 覆盖表 R1 → 1.1–1.5、**1.8**；§1 新增 [x] 1.8（返工项、`--break=toleranttable` 与 18 用例口径、证据指向） |
| `skills/teamsmith/tests/spec-ledger-refs.tsv` | 表头写明加载规则（模式形状只属 `slot`；缺列/多列/空 basis/非法 kind 都在读表时拒绝并点名） |
| `skills/teamsmith/tests/spec-refs.sh` | `load_rows` 严格化（点名表/行号/行内容；`ledger`/`example` 不许 `<…>`/`*`）；`declared()` 具体引用改字面相等；`walk <root> <table> <mode>` 让 `--table` 真的生效；`--break=toleranttable`；8 条新 `--flips` 用例 |
| `skills/teamsmith/tests/smoke.sh` | 段 18c：7 种声明表形状的**直接**拒绝断言（点名表名/行号/内容）、`--flips` 新行的点名断言、`toleranttable` 敏感性 |
| `skills/teamsmith/tests/section-budgets.tsv` | 18c 预算行按本轮实测重测（host 5s / container 6s → band 6.00；budget 60 不变） |
| `docs/team/reports/P185-dev.md` | 本报告 |
| `docs/team/reports/P185-dev/**` | 可重跑证据：`before-after.sh` + `before-after.log`（修复前后逐形状）、`flips-after.log`、两个 `--break` 日志、`check-after.log`、`blocks-anchor.log`、段 18c / validate / selector / budget 日志、`spec-refs.b665b331.sh`（被验实现原件）、`container-*.log`（容器选段/全量/探针）、`probe-{main,dev}-host.log`（探针在两条树上的逐条输出） |

## Verification evidence（全部本回合**自己跑**；命令与原始日志在 `docs/team/reports/P185-dev/`）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 22 passed, 0 failed (22 items)                                   # openspec-validate.log；含改过的 boundary delta

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 18c </dev/null
#5 18c · 公开契约的自洽：账本引用须声明 + 记录 id 须带键（P150） · 用时 5s · ✓22 ✗0 SKIP0 · ticks 22
== 选段结果 ==  ✓ 43  ✗ 0                                                # section-18c-host.log

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 99 reference(s) (49 distinct) in 10119 effective line(s); retired 4; undeclared 0;
id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]                       # rc=0 · check-after.log

$ bash skills/teamsmith/tests/spec-refs.sh --flips
spec-refs: --flips OK（18 用例如预期，0 个不符；break=none）               # rc=0 · flips-after.log

$ bash skills/teamsmith/tests/spec-refs.sh --blocks 'boundary#Specs are the contract'
== boundary#Specs are the contract · source: openspec/changes/spec-rationale-self-contained/specs/boundary/spec.md (change:spec-rationale-self-contained (ADDED)) ==
（证明新正文就在"归档将写出"的有效文本里，取自 delta 的 ADDED 块）          # blocks-anchor.log

$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 7  bad 0  SKIP 0                                      # selector rc=0 · 段 18c 新增代码的路径 token 全被行覆盖

$ bash skills/teamsmith/tests/section-guard.sh --budget-check
ok: 预算表覆盖 123/123 个 section 且每行都满足 max(ceil(band×4), 60)       # budget rc=0 · section-guard-budget.log
```

容器门禁（本仓库 local 模式下的交付门禁；命令、原始日志见 `docs/team/reports/P185-dev/container-*.log`）：

```sh
$ distrobox-host-exec podman run --rm --pid=host --cgroups=enabled --userns=keep-id -e HOME=/tmp \
    -v "$DEV:/work" -v "$MAIN:$MAIN:ro" -w /work localhost/teamsmith-gate:local bash -c "
    git config --global --add safe.directory /work; git config --global --add safe.directory $MAIN; …"
1) TEAM_SMOKE_FAST=1 … --select 18c   → rc=0（9s；段内 6s，✓22 ✗0；选段结果 ✓43 ✗0）  # 首轮修订
2) bash …（全量，2062s）            → rc=1；账本自查 122 段收口 「增量 ✓4375 ✗1 SKIP3 ｜ 结果行 ✓4375 ✗1」
                                       唯一那条红 = 36⑧ 产品面检出探针（main 上既有的 `product-checkout-gate` 缺口，P150 记为发现 4；
                                       我与 main 实测的 bad 行逐字相同；见下）
                                       18c 段在容器里 ✓22 ✗0；其余 121 段全绿
3) 交付 tip（含报告与全部证据）重跑：--select 18c → rc=0（段内 7s ✓22 ✗0；选段 ✓43 ✗0）
                                      全量 2105s → 账本自查 122 段收口，同样只剩那一条 36⑧ 红（见 container-tip-*.log）
```

**那条红的归属（不是本 change 新增）**：`✗ 36⑧ 产品面检出探针有失败（1 条）`，探针内部命中的是
`bad: ⑨ 牙齿一的前提不在：树里的 smoke.sh 没有 P162 的 tmux() 包装，这条牙齿会因别的原因通过` ——
P180（`28b58b9a`）重写了那个包装，探针里 `grep 'tmux() {  # P162'` 的前提在 **main 上就已经不成立**
（`grep -c` 在两棵树都是 0）。同一容器里用同一套托管挂载（分支树 `/work` + main 挂在它自己的宿主路径上，
worktree 的 `.git` 文件才能解析）分别跑探针：

```
[dev-complete]  rc=1 · == 检出形状探针 == ok 76 bad 1 skip 0
    bad: ⑨ 牙齿一的前提不在：…
[main-complete] rc=1 · == 检出形状探针 == ok 89 bad 1 skip 0
    bad: ⑨ 牙齿一的前提不在：…
两条 bad 行逐字相同
```

（绿条数 76 vs 89 的差额全在探针新增的 `⑩` 组：main 在我从 `198db6fc` 分出后又合了 P176
（`1b1b1fb0`，给探针补了 `⑩` 组，+108/−11 行，脚本里 20 处 `⑩`）；main 多评的 13 条全绿（`grep -c '^ok: ⑩'`
= 13）。两版探针我都在宿主上各跑了一遍，日志 `probe-main-host.log` / `probe-dev-host.log`（`ok 89/76 bad 1`，bad 行逐字相同）；
main 的那份探针脚本第 400 行仍是同一条过时前提。)

即：**本 change 不新增失败**（其余 121 段全绿），唯一那条与 main 同源、逐字相同：
`docs/team/reports/P185-dev/container-probe-complete-mounts.log`。

一个已知的**环境拐坑**（复验时别把它当成我新增的）：若把分支树单独挂进容器、而 main 不按宿主路径挂载，
worktree 的 `.git` 文件在容器里解不开（`fatal: not a git repository: …/.git/worktrees/dev`），探针的嵌套跑会在两条
读真树的判据上报红 —— `nest-env`：`0d 冲突标记守卫：找不到受检的 git 工作树`；`nest-teeth`：
`M28 真树有未隔离的 tmux 变更命令` —— 于是多出 2 条 bad（实测 main 1 条 / 分支 3 条）；按宿主路径挂上 main 后，
同一容器里两条判据对**两棵树**都绿，两边都回到 1 条（`container-probe-repro.log`）。这不是代码差异，
我没改这条路径，也没改这两条判据。

## Flip evidence（defect-fix 必填：修复前红 → 修复后绿 + 破坏实现 → 守卫必红）

**修复前 → 修复后（`bash docs/team/reports/P185-dev/before-after.sh`，同一棵树、同一张表副本，逐形状）：**

```
control           before rc=1  undeclared … docs/team/reports/P184-dev.md   # 对照：确切的未声明引用两版都判红
control           after  rc=1  undeclared … docs/team/reports/P184-dev.md
wildcard-ledger   before rc=0  spec-refs: judged 100 … undeclared 0          ← F1 假绿：具体引用被通配行吞了
wildcard-ledger   after  rc=2  声明表 …table.tsv:79 ledger 行必须是字面引用… 'docs/team/reports/P184*.md'（行：…）
wildcard-example  before rc=0  spec-refs: judged 100 … undeclared 0          ← 同一形状的 example 行
wildcard-example  after  rc=2  声明表 …table.tsv:79 example 行必须是字面引用… 'docs/team/reports/P184-<agent>.md'
one-col           before rc=0  spec-refs: judged 99 … undeclared 0           ← F2 假绿：1 列行被静默丢弃
one-col           after  rc=2  声明表 …table.tsv:79 数据行不是三列 … docs/team/one-col.md
two-col           before rc=2  声明表行没有 basis：docs/team/two-col.md       ← 旧消息不点表名/行号/行内容
two-col           after  rc=2  声明表 …table.tsv:79 数据行不是三列 … docs/team/two-col.md	ledger
extra-col         before rc=0  spec-refs: judged 99 … undeclared 0           ← 第 4 列被静默丢弃
extra-col         after  rc=2  声明表 …table.tsv:79 数据行不是三列 … docs/team/extra-col.md	ledger	x	y
empty-basis       before rc=2  声明表行没有 basis：docs/team/empty-basis.md   ← 旧消息不点表名/行号
empty-basis       after  rc=2  声明表 …table.tsv:79 basis 为空（行：docs/team/empty-basis.md	ledger	）
bad-kind          before rc=2  声明表 kind 非法：bogus（docs/team/bad-kind.md）← 旧消息不点表名/行号
bad-kind          after  rc=2  声明表 …table.tsv:79 kind 非法（只许 slot/ledger/example）：'bogus'（行：…）
```

（`before` = 被验实现 `b665b331` 原件 `docs/team/reports/P185-dev/spec-refs.b665b331.sh`；`after` = 本分支。
原始输出 `docs/team/reports/P185-dev/before-after.log`。）

**破坏实现 → 守卫必红（两个 `--break` 旋钮，都是仓库里的可重跑命令）：**

```
$ bash skills/teamsmith/tests/spec-refs.sh --flips --break=toleranttable   # 放回 P150 的宽松加载
BAD table-wildcard-ledger … table-wildcard-example … table-one-col … table-two-col …
BAD table-empty-basis … table-bad-kind … table-extra-col …
spec-refs: --flips FAIL（11 用例如预期，7 个不符；break=toleranttable）   # rc=1 · flips-break-toleranttable.log

$ bash skills/teamsmith/tests/spec-refs.sh --flips --break=slotmatcher     # 放回 P145 的宽松 matcher（回归钉）
BAD plant-purpose-concrete … BAD plant-undeclared-shape …
spec-refs: --flips FAIL（16 用例如预期，2 个不符；break=slotmatcher）      # rc=1 · flips-break-slotmatcher.log
```

段 18c 的直接断言（`section-18c-host.log`，7 种形状 + 敏感性；`--flips` 那一轮另点名 3 行新旧用例）：
`✓ 18c 声明表拒绝加载 wildcard-ledger / wildcard-example / one-col / two-col / empty-basis / bad-kind / extra-col`
＋ `✓ 18c --flips 敏感性（宽松加载）：toleranttable 下报 BAD`、`✓ 18c --flips 钉住通配 ledger 行…`、
`✓ 18c --flips 钉住缺列数据行…`、`✓ 18c --flips 反向：ledger 根/固定文件照旧按字面行放行`。

**反向（不许误伤，都是绿侧）**：`--flips` 的 `clean declared-slot`（含 `<…>` 的槽位行照旧放行）、
`clean declared-example`、`clean declared-ledger-rows`（新：`docs/team/reports/` 根与 `docs/team/DECISIONS.md`
按字面行放行）、`clean untouched-tree`；`--check` 在本树 rc=0、`undeclared 0`。

## 哪些自己跑、哪些引用 P184

- **全部自己跑**：上列每一行（validate / 段 18c / `--check` / `--flips` / 两个 `--break` / `--blocks` /
  选择器自检 / 预算自检 / 容器三项）。F1/F2 的两个现场（通配行吞具体引用、畸形行被静默丢弃）我用
  `before-after.sh` **在 b665b331 原件上重新复现**（before 列），没有把 P184 的输出当本轮通过证据。
- **引用 P184 的只有"缺陷定义"，不是通过证据**：`docs/team/reviews/P184.md` 的 F1/F2 判定（PM 亲手复现的那两形状）
  与 `docs/team/reports/P184-verify.md` 的记录；本任务书本身把 F1/F2 的红侧形状写死，我逐条对齐。
- F3（待归档 delta 的判定口径）与 F4（六族之外的 id 族）**都没动**：F3 是任务书口径问题（PM 已改），F4 已记为边界。

## Decisions and deviations

- **`walk` 签名改为 `<root> <table> <mode> [caparg]`**：原实现里 `--flips` 把表路径当参数传给 `walk`，
  但 `walk` 内联的 python 读的是全局 `$TABLE` —— 逐用例的表副本**从未生效**。新用例第一次跑时 7 条全 BAD
  暴露了这一点；修正后 `--table` 才是真的表缝（这也是 `--flips` 表用例能判的前提，不是顺手重构）。
- **连"多列"也拒绝**：任务书只说"缺列"，我的契约写成 "exactly its three columns" 并拒绝第 4 列 ——
  旧实现会静默丢弃多余的列，正是"静默"家族（多余列多半是 basis 里混进的制表符）。
- **预算行重测**：段 18c 新增 7 个走查 + 1 次 `--flips`，host 5s / container 6s（历史 P150 为 2s/3s）→
  band 6.00、budget 60（floor）不变；`section-guard --budget-check` 全过。
- **事故与恢复（如实记录）**：编辑阶段我一度把三处改动写到**主工作树**路径（`/…/pm-skills/skills/…` 而不是
  `.worktrees/dev/skills/…`），共三个文件。发现后立刻 `git checkout --` 恢复，主工作树 `git status --short`
  为空、无提交（当时该树只有我误改的三个文件）；随后所有改动都在 `.worktrees/dev` 内完成，主工作树未再被触碰。
- **分支与 main 的关系**：我从 `198db6fc` 分出；main 此后已前进到 `0f2bc725`（P160/P176/P187…），其中
  `smoke.sh` 改了 +150 行、`section-paths.tsv` 改 2 行、探针 +82 行。我的改动落在段 18c 与
  `spec-refs.sh`/声明表（这两个文件在 main 上**没被改过**），与 main 上的改动按区域不重叠；合并时
  若段 18c 附近冲突，按“两边各自新增”合并即可。
- 分支留本地（本仓库 local 模式），没有 `git push`。

## Suggested next steps

- 复验**换人**（brief 要求）：可重跑 `docs/team/reports/P185-dev/before-after.sh` 与
  `bash skills/teamsmith/tests/spec-refs.sh --flips --break=toleranttable`（两者都自带红侧），
  再跑段 18c 与容器 FAST。
- 归档前若要改 `tasks.md` 的覆盖表表述，那是 PM 的任务书口径（我只补了 1.8 与覆盖表一行）。
