# P106 · 夹具必须尊重 `TEAM_TMP_KEEP`：CI 的「保留现场」不该被判成泄漏 · **apply** · dev-bob

agent: dev-bob
status: **DONE**（本地模式：不 push，分支留在本地等 PM 复验/合并；CI 的最终确认由 PM 在下一次 push 后看）
time: 2026-09-28T11:33Z
branch: `task/P106-team-tmp-keep-infra-apply`
change: `-`（anchor: none (infra) — 只改测试侧的遗留判定，不改产品代码）
deltas: `-`
base: `5ff0f870`（P106 任务书）
证据包: `docs/team/reports/P106-dev-bob/pkg/`（`run.sh` 三方向复现 + `README.md` + `logs/` 原始输出）

## 归因（如实点名因果，按任务书要求）

这条红**不是环境抖动**，是三段我们自己的代码叠加出来的：

1. `.github/workflows/gates.yml` 用 `smoke.sh --keep` 跑门禁（**PM 加的**，为了让失败留下现场 —— 本意是对的）；
2. `smoke.sh:296` 于是 `export TEAM_TMP_KEEP=1` → **所有子进程都继承**（`routes.sh` 在其中）；
3. `routes.sh` 的 flips 收尾断言只数「还有没有残留」，**没有把 KEEP 当回事** → 把**按设计保留**的嵌套根
   判成泄漏。对照：smoke 自己的 §40 处理得对（`✓ 40 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏`），
   本修法就按它同口径。

CI 现场（run `36405043458`，commit `8914244d`，§51）：`✗ 翻转收尾：留下 1 个嵌套临时根`（`✓169 ✗1`）。
本地复现（修复前、私有 TMPDIR、`TEAM_TMP_KEEP=1`）：同样的 `✓7 ✗1` —— `pkg/logs/01-before-red-keep.log`。

## 交付物

| Path | What |
|---|---|
| `skills/teamsmith/tests/routes.sh` | ① 收尾断言 KEEP 感知（`=1` → 可见说明 + 列出保留的根；默认 → 照旧严）；② 嵌套根来源改为「共享 run 台账（主）+ 文件系统家族扫描（次）」；③ 新增翻转⑧证明默认断言可被证伪 |
| `docs/team/reports/P106-dev-bob/pkg/run.sh` | 三方向复现（`default` / `keep` / `mut`），各自私有 TMPDIR，退出码即判定 |
| `docs/team/reports/P106-dev-bob/pkg/README.md` + `pkg/logs/` | 机制说明与八份原始输出（含本节的规格校验与证据包自跑） |

## 机制与修法（为什么不是一行 `if`）

**（a）KEEP 分支**：`TEAM_TMP_KEEP=1` 时打
`✓ 翻转收尾：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏`（照 smoke §40 的措辞），随后逐条打印保留的根：
本夹具自己的根 + 每个嵌套 run 自己打印的 `保留临时根：…（TEAM_TMP_KEEP=1）`（`mr_flip_run` 从嵌套日志里
攒下来 —— `$tmp/flip-run.log` 每次覆盖，只有这里攒得下全部）。**静默保留仍是缺陷**，所以没有“只打一句 ok
就完事”：`05-after-keep.log` 里 8 条保留路径逐条可见。

**（b）默认分支必须照旧严，而且真的严**：原实现是
`find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'teamsmith-routes.*' -newer "$tmp"`，它有两个洞：

- `-newer "$tmp"` 只看得见**最后一个**嵌套根 —— 任何后续 scratch 树的建删都会刷新 `$tmp` 的 mtime
  （CI 只报“留下 1 个”而实际有 7 个，就是这个洞）；
- 新增翻转⑧会建自己的 scratch 树，洞会扩大到“一个都看不见” —— **本任务实测到了**：第一版翻转⑧加完后，
  `TMP_ROOT_BREAK=noreap` 变异跑出 `✓9 ✗0`（7 个泄漏一个没看见），我因此把来源改掉。

现在默认分支以**本轮 run 台账**为主来源：`routes.sh` 起手
`export SMOKE_TMP_RUN_ID="${SMOKE_TMP_RUN_ID:-routes-$$-…}"`（非 TEAM_ 的传播位，嵌套 run 的身份清理
清不掉它），父子 run 共享同一份台账，`kind=routes && pid != $$` 就是**每一个**嵌套根；文件系统家族扫描
保留为次来源（兜住“不用助手、裸 mkdir”的形状）。改后台账来源的同一变异复跑：
`✗ 翻转收尾：留下 7 个嵌套临时根：<7 条路径>`（`03-after-mutation-noreap.log`）。

**（c）翻转⑧（可证伪性）**：在**私有 TMPDIR** 里跑一次嵌套 `walk` 并带 `TMP_ROOT_BREAK=noreap`
（`tests/lib/tmp-root.sh` 自带的自检旋钮，把回收关掉）→ 收尾扫描必须看得见那个残留；刻意的残留随本夹具
的根一起回收，不进共享临时目录。于是“默认方向能红”是**常驻断言**，不是报告里的一次性手工演示。

## 验证证据（全部实跑，原始输出在 `pkg/logs/`）

复现入口（`pkg/run.sh` 把三条都包了；下表的 rc/计数取自原始日志）：

```
$ bash docs/team/reports/P106-dev-bob/pkg/run.sh            # default + keep + mut（各私有 TMPDIR）
```

| # | 方向 | 命令（私有 TMPDIR） | 结果 |
|---|---|---|---|
| 01 | **修复前** `TEAM_TMP_KEEP=1` | `TMPDIR=… TEAM_TMP_KEEP=1 bash …/routes.sh flips` | rc=1，`✓7 ✗1`，`✗ 翻转收尾：留下 1 个嵌套临时根`（=CI 现场） |
| 02 | 修复前 默认 | `TMPDIR=… bash …/routes.sh flips` | rc=0，`✓8 ✗0` |
| 03 | **修复后** 变异 `TMP_ROOT_BREAK=noreap`（默认） | `TMPDIR=… TMP_ROOT_BREAK=noreap bash …/routes.sh flips` | rc=1，`✓8 ✗1`，`✗ …留下 7 个嵌套临时根：<7 路径>` |
| 04 | **修复后** 默认 | `TMPDIR=… bash …/routes.sh flips` | rc=0，`✓9 ✗0`，`✓ 翻转收尾：嵌套 run 的临时根都回收了` |
| 05 | **修复后** `TEAM_TMP_KEEP=1` | `TMPDIR=… TEAM_TMP_KEEP=1 bash …/routes.sh flips` | rc=0，`✓9 ✗0`，`✓ 本轮声明保留…不判泄漏` + 8 条保留路径 |
| 06 | FAST 门禁 | `TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` | rc=0，`✓ 2876 ✗ 0`；§51 `✓ routes.sh 全绿（163 条断言，2 条可见跳过）` |
| 07 | **全量门禁（CI 形状）** | `TMPDIR=<私有> bash skills/teamsmith/tests/smoke.sh --keep` | rc=0，`✓ 3541 ✗ 0`，`smoke 全绿`；§51 `✓ routes.sh 全绿（172 条断言，1 条可见跳过）`；§40 `✓ 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏`；§34b⑥ `✓ 队列 marker 没有残留` |
| 08 | 规格 + 证据包 | `~/.bun/bin/openspec validate --all --strict`；`bash docs/team/reports/P106-dev-bob/pkg/run.sh` | `Totals: 17 passed, 0 failed`；证据包 `ok=3 bad=0`（default/keep/mut 全部符合期望） |

关键原始输出（去 ANSI）：

```
$ TMPDIR=… TEAM_TMP_KEEP=1 bash skills/teamsmith/tests/routes.sh flips     # 修复前
  ✓ 翻转⑦：注册报成功而名册没变 → promise 探针红并点名 TEAM_AGENTS（断言的是效果）
  ✗ 翻转收尾：留下 1 个嵌套临时根
== 结果 ==  ✓ 7  ✗ 1  SKIP 0
保留临时根：/tmp/p106-repro/red/teamsmith-routes.BAdTwD（TEAM_TMP_KEEP=1）

$ TMPDIR=… TEAM_TMP_KEEP=1 bash skills/teamsmith/tests/routes.sh flips     # 修复后
  ✓ 翻转⑧：嵌套 run 不回收 → 收尾扫描看得见残留（默认 KEEP 未设时判红）
  ✓ 翻转收尾：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏
  · 保留本夹具的根：/tmp/p106-verify/keep/teamsmith-routes.qox0rg（助手在 EXIT 时也会打印）
  · 保留临时根：/tmp/p106-verify/keep/teamsmith-routes.68UO46（TEAM_TMP_KEEP=1）
  …（共 8 条嵌套保留路径，逐条可见）
== 结果 ==  ✓ 9  ✗ 0  SKIP 0

$ TMPDIR=… TMP_ROOT_BREAK=noreap bash skills/teamsmith/tests/routes.sh flips   # 修复后 · 变异
  ✓ 翻转⑧：嵌套 run 不回收 → 收尾扫描看得见残留（默认 KEEP 未设时判红）
  ✗ 翻转收尾：留下 7 个嵌套临时根：/tmp/p106-verify/mut/teamsmith-routes.4KnOGu …（7 条路径）
== 结果 ==  ✓ 8  ✗ 1  SKIP 0
```

### 全量门禁（CI 形状）

```
$ TMPDIR=/tmp/p106-full bash skills/teamsmith/tests/smoke.sh --keep
…
  ✓ 34b⑥ 队列 marker 没有残留
  ✓ 40 临时根：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏
== 51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99） ==
  ✓ 51 routes.sh 全绿（172 条断言，1 条可见跳过）
        ✓ 翻转①：help 打印 --model 而解析器拒绝 → walk 红并点名 add-agent --model
        …（①–⑦ 七条翻转全绿）
  ✓ 51 名册/契约夹具（list+validate+roster）全绿（104 条断言）

== 结果 ==  ✓ 3541  ✗ 0
smoke 全绿
保留临时根：/tmp/p106-full/teamsmith-smoke.t1WxBu（TEAM_TMP_KEEP=1）
保留 run 台账：/tmp/p106-full/.teamsmith-tmp-ledger.smoke-2597503-1790593564
```

这就是 CI 的跑法（`gates.yml` 的 `smoke.sh --keep`），修复前它在 §51 红，修复后整套 `✓ 3541 ✗ 0`。
（现场留在私有 TMPDIR 里，约 924 MB；取完证据后已由本任务删除。）

## Flip evidence（红 → 绿；破坏实现 → 断言红 → 还原）

**红（修复前，CI 形状 `TEAM_TMP_KEEP=1`）**：`01-before-red-keep.log`
`✗ 翻转收尾：留下 1 个嵌套临时根` / `== 结果 ==  ✓ 7  ✗ 1  SKIP 0`。
**绿（修复后，同一命令）**：`05-after-keep.log`
`✓ 翻转收尾：本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏` / `== 结果 ==  ✓ 9  ✗ 0  SKIP 0`。

**破坏实现 → 默认方向的断言必须红 → 还原**：`03-after-mutation-noreap.log`
把嵌套 run 的回收关掉（`TMP_ROOT_BREAK=noreap`，助手自带的自检旋钮）后，
`✗ 翻转收尾：留下 7 个嵌套临时根：<7 路径>` / `✓ 8  ✗ 1`；不带变异时 `04-after-default.log` 为
`✓ 翻转收尾：嵌套 run 的临时根都回收了` / `✓ 9  ✗ 0`。翻转⑧把这一步常驻化，PM 可直接复跑：

```
$ bash docs/team/reports/P106-dev-bob/pkg/run.sh mut      # 期望 rc=1 + 「留下 7 个嵌套临时根」
$ bash docs/team/reports/P106-dev-bob/pkg/run.sh default  # 期望 rc=0 + 「嵌套根都回收了」
```

（补记：第一版修复的扫描仍是纯 `find -newer`，同一变异跑出 `✓9 ✗0` —— 即断言当时是**空洞的**；
台账来源改完后同一变异报出全部 7 条。这也是“默认必须真的严”这条要求的直接证据。）

## 同一口径的其他夹具（任务书第 3 条）

系统扫了一遍 `skills/teamsmith/tests/**` 的“残留/泄漏”判定：

- **`smoke.sh` §40**（`tmp_root_ledger_survivors` + `TEAM_TMP_KEEP`）：**已经对齐**，本修法就是照它的措辞
  （`本轮声明保留（TEAM_TMP_KEEP=1），不判泄漏`）。不重复改。
- **`routes.sh` flips 收尾**：本任务修的就是它（唯一一处“临时根残留即红”）。
- **`smoke.sh` §34b⑥「队列 marker 没有残留」**：私有 `TMPDIR=$P66D` 里的 `mktemp` marker，不是
  tmp-root 家族的根，且两条路径都显式 `rm -f`；`--keep` 下 CI 已绿（本任务全量 `--keep` 复跑也绿）。
  **不需要** KEEP 感知（KEEP 只管 owned 家族目录的回收，管不到它）。
- **`tmp-hygiene.sh` 自检 ⑨/⑩**：测的是操作员的 `--sweep` 语义（“未占用才删、能删就删”），
  不是夹具泄漏判定；`--sweep` 本来就不看 `TEAM_TMP_KEEP`，**不受影响**。
- 其余含“残留”的断言（12b-h 的框里残留、12b-e 的夹具进程、占位符残留、12b 的项目文件泄漏扫描）语义都不同，
  与临时根无关。

结论：**只有 routes.sh 一处需要改**，已改；smoke §40 是对照口径。

## 决策与偏离

- **共享 run 台账**（`export SMOKE_TMP_RUN_ID`）是默认分支“真的严”的必需项，不是顺手重构：纯 `find -newer`
  在翻转⑧落地后会把 7 个泄漏全漏掉（见上）。父/子共享台账用 `SMOKE_TMP_RUN_ID` 这个既有传播位，
  不引入新机制；`kind=routes && pid != $$` 过滤保证只数本夹具的嵌套根，不误伤 smoke 里其他段的根。
- **翻转⑧的私有 TMPDIR**：刻意的残留不落进共享临时目录，也不让收尾扫描误把它算进来；它随本夹具的根
  一起回收（默认方向）或被 KEEP 保留（KEEP 方向，且可见）。
- **未动 `smoke.sh` §51 的现场尾巴** `grep -aE '翻转[①②③④⑤⑥⑦]'`：那只是把翻转行打进日志的展示，
  不是断言；grant 对 `tests/*.sh` 只允许“KEEP 口径对齐”，所以保持不动（新加的翻转⑧行不进那段尾巴，
  完整门禁里它出现在 routes 子日志与 `✗` 行里）。如果 PM 希望尾巴也带上 ⑧，请单独授权一行改动。
- **`TEAM_ROUTES_KEEP=1`（夹具自己的 keep）** 与 `TEAM_TMP_KEEP` 是两回事：前者只保留本夹具根、不传给
  嵌套 run（身份清理会清掉 TEAM_*），所以收尾仍按默认严格口径判 —— 语义未变。
- 产品代码、门禁语义、断言强度均未放松：`泄漏` 判定只在 `TEAM_TMP_KEEP=1` 时让位给可见说明；
  默认方向的判定面反而从“最后一个根”扩大到“每一个根”。

## 建议的下一步

- PM 复验：`bash docs/team/reports/P106-dev-bob/pkg/run.sh`（三方向）+ 独立跑一次全量门禁；
  CI 最终确认在下次 push 后看（本仓库 local 模式，我不 push）。
- `BLOCKED:` 无。
