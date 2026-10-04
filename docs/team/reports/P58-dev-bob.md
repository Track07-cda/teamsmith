# P58 · ledger-and-gate-noise 尾单：pm 席位行与启动解析同源 + R5 场景文字改正

agent: dev-bob   status: 交付（apply；代码 + 文字 + 防分叉断言 + 双向翻转）   time: 2026-09-22T13:31Z
branch: `task/P58-f1-pm-r5`（local 模式，**不 push**）   PR/MR: -（本仓库没有远端投递）
change: `ledger-and-gate-noise`（P54 复验的 **F1** 尾单；本单落地后该 change 才可归档）
tip: `9d075bb`（实现 + 文字的 tip）；其后全部是 docs-only 提交（报告与证据包）。`flip.out` 头部
`tree=` 是跑它的 HEAD（`5f08e8b`），`old=` 是翻转旧侧钉住的 sha（`d06e09a`，P58 之前的代码）
起点: `d06e09a`（PM 的 P57/P58 任务书提交；`main` 上另有 2 个 docs-only 提交，未并进本分支）

**总结论**：F1 的两条都落地 ——

1. **代码**：pm 席位行的模型与 PM 启动解析走**同一个函数**（`team_pm_model_resolve`）：空
   `TEAM_DEFAULT_MODEL` 时两边都回退 schema 默认，席位行不再说 `""`；
2. **文字**：R5 的空默认场景期望改成回退值（没有为迁就文字去动 loader），并加了一条「pm 行 == 启动渲染
   的 `--provider`/`--model`」场景与对应断言，防再次分叉。

新断言双向量过：**旧实现（P58 之前的 `d06e09a` 树）红 → 本实现绿**，且**变异体（去掉回退）红 → 还原绿**（§3）。
验收三条全绿：`openspec validate --all --strict` 22/22、`config-cli.sh` 全量 ✓149 ✗0、FAST smoke ✓2350 ✗0。

---

## 0 · 两件事的落点

| 任务书条目 | 落点 | 证据 |
|---|---|---|
| ① 代码：pm 席位行与启动解析同源（空 → 回退） | `scripts/lib/common.sh:1894-1899`（新 `team_pm_model_resolve`）、`:1902`（`team_pm_pi_args`）、`:2154`（自定义 PM CLI 分支）；`scripts/lib/cmd-config.sh:556`（pm 行） | §1、§3 |
| ① 断言：空默认角落 **pm 行 == 启动解析用的模型** | `tests/config-cli.sh:651-665`（`json` 段：`team up --print` 渲染出的真实命令 vs JSON 的 pm 行） | §3 |
| ② 文字：R5 场景「An empty model is still a value」期望改成回退 | `openspec/.../memory-and-deps/spec.md:105`（改名 + 期望改回退）、`:112`（新场景钉同源） | §2 |
| 必给翻转：去掉 pm 行回退 → 断言红；还原绿 | `docs/team/reports/P58-dev-bob/flip.sh` → `flip.out`；真跑前/后日志 `red-before-fix.log` / `green-after-fix.log` | §3 |

**路径纪律**：`git diff --name-only` = 任务书 `grant:` 列出的四个文件（`common.sh`、`cmd-config.sh`、
delta `spec.md`、`tests/config-cli.sh`）+ 本报告目录 `docs/team/reports/P58-dev-bob/**`。
`tests/smoke.sh` 是 `append-only` 授权但**没动**（没有必须往那里加的东西）；`openspec/specs/**`、
`design.md`、`tasks.md`、`references/**` 一个字节没碰。

---

## 1 · 代码：一个解析函数，两个调用点（同源的结构保证）

P54/F1 的事实：空 `TEAM_DEFAULT_MODEL` 时，**dev 行**走运行时回退
（`team_agent_model` → `$TEAM_DEFAULT_MODEL`，而 `team_load_config` 已经用 `${…:-deepseek/deepseek-flash}`
把它回退成 schema 默认），**pm 行**却直接读契约文件的字面值 → `""`。修法不是再抄一遍回退，而是把 pm 行的模型
指到启动用的那一行：

```bash
# skills/teamsmith/scripts/lib/common.sh:1899（新；启动与读出口的唯一来源）
team_pm_model_resolve() { printf '%s\n' "${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}"; }
```

- `team_pm_pi_args()`（`:1902`）与 `team_pm_launch_cmd()` 的自定义 CLI 分支（`:2154`）改用它 ——
  启动参数里 `--provider`/`--model` 的拆分也就仍然是这一行的投影；
- `team_config_seat_state()` 的 pm 分支（`cmd-config.sh:556`）`model="$(team_pm_model_resolve)"`，
  `override` 仍按契约文件里有没有 `TEAM_PM_MODEL` token 判（P47/R4 的口径，本单不动）；
- 为什么这样一定同源：空 `TEAM_DEFAULT_MODEL` 的回退发生在 `team_load_config`
  （`common.sh:772` 的 `${TEAM_DEFAULT_MODEL:-…}`），所以任何经过 CLI 入口的进程里，
  `team_pm_model_resolve` 拿到的就是「下一次启动会用的模型」；没经过 load 的夹具（只 `source
  common.sh`）读到的就是环境原值 —— 与它自己调 `team_pm_pi_args` 的口径相同，没有第三种语义。

`models.known`/`choices.values` 的面板词汇因此也不动（`panel-choices.sh` ✓41 ✗0，§5）。

## 2 · 文字：delta 里两条场景

- 原 `#### Scenario: An empty model is still a value`（THEN 要求 dev 行 `"model":""`）→ 改名
  **`An empty default still resolves to the fallback`**，THEN 改成「`"model"` = CLI 解析出的默认
  （即 `TEAM_DEFAULT_MODEL` 的 schema 默认）、`"override":true`」。**loader 没动**。
- 新增 **`The PM row resolves exactly like the PM's launch`**：同一空默认角落，
  `team config list --json` 的 pm 行 == `team up --print` 渲染命令里的 `--provider`/`--model` 对，
  永不 `""`，`override` false。
- requirement body 只加一句限定（pm 席位的解析「resolved exactly as the PM's launch resolves it, an empty
  one falling back to the schema default」）。R5 requirement 里「空模型序列化成 `""`、绝不是无值字段」
  的**序列化**裁决原样保留 —— 那是 F-J1 红侧（valueless field）在守的东西，与「解析回退」是两件事。

## 3 · 断言与翻转（原始输出）

### 3.1 先写断言、后改代码：红 → 绿（真实现两态）

新断言（`tests/config-cli.sh` 的 `json` 段）从**真实渲染**取启动模型，不抄期望值：

```sh
up_print="$( cd "$pj" && bash "$team" up --print 2>/dev/null || true )"
pm_model="$(printf '%s' "$json_e" | python3 -c '…models.seats 里 pm 行的 model…')"
launch_pair="$(printf '%s' "$up_print" | grep -oE -- '--provider [^ ]+ --model [^ ]+' | tail -1 || true)"
assert_eq "空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 \"\"" \
  "--provider ${pm_model%%/*} --model ${pm_model##*/}" "$launch_pair"
```

**红**（`bash skills/teamsmith/tests/config-cli.sh json`，未改代码的树；`red-before-fix.log`）：

```
  ✗ 空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 ""（期望 [--provider deepseek --model deepseek-flash]，实际 [--provider  --model ]）
  ✗ 空默认值：pm 行回退成非空模型（不是 ""），override 仍是布尔 false（表达式：…）
  == 结果 ==  ✓ 7  ✗ 4  SKIP 0
```

**绿**（同一命令、改了代码之后；`green-after-fix.log`）：

```
  ✓ 空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 ""
  ✓ 空默认值：pm 行回退成非空模型（不是 ""），override 仍是布尔 false
  ✓ 空默认值：dev 行仍在（seats 覆盖每个名册席位）、模型非空且 override 是布尔 true
  == 结果 ==  ✓ 11  ✗ 0  SKIP 0
```

（红侧 `✓ 7 ✗ 4` 里的 4 条 = 两条 pm 断言 + F-J1 的「绿侧就红了」与「还原后没有变绿」——后两条是同一原因
的连带（§F-J1 的绿侧要求整棵树绿，而那棵树还没修），修完就与 `green-after-fix.log` 一样全部转绿；
下面 §3.2 的旧树红只有 pm 两条，能对上。）

### 3.2 双向翻转（任务书要求的那一条：去掉回退 → 红；还原 → 绿）

`bash docs/team/reports/P58-dev-bob/flip.sh`（`flip.out` 全文随报告提交；只写 `${TMPDIR}/p58-flip`，
不碰真仓库、不调 tmux）。旧侧钉的是 **`d06e09a`**（P58 之前的代码），不是 `main` —— 本分支合进 main 后
翻转仍然有效；要换旧侧用 `P58_OLD_SHA=<sha>`：

```
== ① 旧实现（d06e09a，P58 之前）：新断言必须红 ==
  TEAM_CONFIG_TREE=/tmp/p58-flip/old-tree … config-cli.sh json → rc=1
      ✗ 空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 ""（期望 [--provider deepseek --model deepseek-flash]，实际 [--provider  --model ]）
      ✗ 空默认值：pm 行回退成非空模型（不是 ""），override 仍是布尔 false（表达式：…）
    == 结果 ==  ✓ 5  ✗ 2  SKIP 1

== ② 本分支（同源解析）：新断言必须绿 ==
  TEAM_CONFIG_TREE=…/dev-bob … config-cli.sh json → rc=0
      ✓ 空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 ""
      ✓ 空默认值：pm 行回退成非空模型（不是 ""），override 仍是布尔 false
    == 结果 ==  ✓ 7  ✗ 0  SKIP 1

== ③ 变异体（去掉 pm 行的回退）：新断言必须红 ==
  mutant: pm 行 = 契约文件的字面值（空默认 → ""，无回退）
  TEAM_CONFIG_TREE=/tmp/p58-flip/mut-tree … → rc=1
      ✗ 空默认值：pm 行的模型 = PM 启动解析（up --print 的 --provider/--model），不是 ""（期望 [--provider deepseek --model deepseek-flash]，实际 [--provider  --model ]）
      ✗ 空默认值：pm 行回退成非空模型（不是 ""），override 仍是布尔 false（表达式：…）
    == 结果 ==  ✓ 5  ✗ 2  SKIP 1

== ④ 还原变异体（同一棵树）：新断言必须重新绿 ==
  restored: pm 行回到同源解析
  TEAM_CONFIG_TREE=/tmp/p58-flip/mut-tree … → rc=0
    == 结果 ==  ✓ 7  ✗ 0  SKIP 1
```

变异体就是把 `model="$(team_pm_model_resolve)"` 换回旧式的
`model="$(team_config_file_value … TEAM_DEFAULT_MODEL …)"`（`flip.sh` 里逐字可读）。

## 4 · 验收（任务书 Acceptance 原样命令）

```sh
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ change/ledger-and-gate-noise
…
Totals: 22 passed, 0 failed (22 items)

$ bash skills/teamsmith/tests/config-cli.sh
== 结果 ==  ✓ 149  ✗ 0  SKIP 0        # rc=0（36s；两个红侧翻转按设计是红的，见下）

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2350  ✗ 0
FAST 模式：跳过 30 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿                            # rc=0（530s）
```

（`config-cli.sh` 日志里出现的 `✗` 全部来自**翻转的红侧**：F-J1 的 valueless-field 红侧与
`groups` 段的红侧，脚本结尾仍是 `✓ 149 ✗ 0`、rc=0。）

## 5 · 回归与边界

- `bash skills/teamsmith/tests/panel-choices.sh` → `== 结果 == ✓ 41 ✗ 0`（模型词表/known 没变；
  pm 行的三态断言——有 `TEAM_PM_MODEL` / 去掉它——原样绿）。
- `team up --print` 的自定义 CLI 分支（`TEAM_PM_CMD`）也走同一函数：smoke 的 P36 渲染段在 FAST 里绿。
- **全量 smoke 没跑**：本任务 Acceptance 只要 FAST；已知与 P54 的 F2（真 pi 的信任弹窗 → §31b2）无关，
  但那一红属于另一个任务，不在这里重跑也不当成回归。若 PM 复验要跑全量，§31b2 的红请按 F2 归类。
- 没有 `BLOCKED`：改动全部落在 grant 内，没有需要 PM 或别的项目配合的接口。
