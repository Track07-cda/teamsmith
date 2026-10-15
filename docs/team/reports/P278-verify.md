# P278 · 帮助面收尾（宽度与 locale 解耦、入口清单、可达性、占位符红侧、拒绝语去行话）：apply

- task: P278 · phase: apply · category: code · agent: verify
- change: `help-robustness` · specs: `help-surface`（2 MODIFIED + 1 ADDED，delta 文件一字未动）
- deltas: `-`（本任务不改 delta 文件）
- branch: `task/P278-help-robustness-apply`（local 模式：不推送，分支留本地）
- status: delivered
- time: 2026-10-15

## 测试状态（先说）

**本任务书「验收」一节列的命令全部真跑过**，命令、退出码与输出尾部在 §3、§4：

| 验收命令 | rc | 结果 |
|---|---|---|
| `openspec validate --all --strict` | 0 | 20 passed, 0 failed |
| `bash skills/teamsmith/tests/help-surface.sh --all` | 0 | ✓105 ✗0 SKIP0（208s） |
| `LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --all` | 0 | ✓105 ✗0 SKIP0（204s） |
| `bash skills/teamsmith/tests/help-surface.sh --flip` | 0 | ✓119 ✗0 SKIP0（514s） |
| `bash skills/teamsmith/tests/routes.sh` | 0 | ✓221 ✗0（494s） |
| `bash skills/teamsmith/tests/config-cli.sh list validate roster` | 0 | ✓144 ✗0（20s） |
| `bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD …)` | 0 | 选中 33 段，含 §51（3s） |
| `bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD …)` | **1** | ✓1382 **✗1** SKIP4 —— 唯一红是 §36⑧，根因是**既有的 §6f F8 红**（在 pristine main 上同样红，§5.2 有决定性证据），与本变更无关 |
| `bash skills/teamsmith/tests/smoke.sh --select 51`（FAST） | 0 | ✓3 ✗0（270s） |
| `bash skills/teamsmith/tests/section-needs-audit.sh --keys 51` | 0 | `ok 51 rc=0`（238s） |
| `bash skills/teamsmith/tests/spec-refs.sh --check` | 0 | 111 引用 / 0 retired / 0 undeclared |
| `bash skills/teamsmith/tests/ledger-ban.sh --names-file …` | 0 | hits=0 |
| `git diff --check && git status --short` | 0 | 干净 |

- **本变更自身触及的每一条都是绿的**：locale 组、G4、内部入口闭集、可达性、§51 选集、config 拒绝语的行为判据与红侧、
  O7 红侧、以及全部 14 条 `--flip`。
- **门禁只跑选段**（`--paths <changed>` → 33 段，3054s）与 §51 的 FAST 段；整段门禁由 PM 复验时跑（D2012）。
- **两条既有红会挡住「全绿」**，都不是本变更引入的，我没有修（超出任务书范围），在 §5 给出根因与复现：
  ① `§6f` 的 F8 断言（确定性，pristine main 上同样红）；② `mark-loaded` 的幂等声明与实现冲突（约 50% 概率红）。
  报告里的 `--all` / `--flip` 绿是**第 2 次**的结果：第 1 次撞上 ②（§5.1 记录每次的红与原因，不靠重跑掩盖）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-help.sh` | 宽度引擎换成 locale 无关实现：一次 `LC_ALL=C` 读原始字节 + 手写 UTF-8 解码 + 码点判 0/1/2 格 + 按码点边界折行；页面首行也走 `team_help_flow`（宽度上界覆盖首行）；新增闭集 `TEAM_HELP_PLACEHOLDERS`、`team_help_tokens_of` 与载入期双向扫描（G4） |
| `skills/teamsmith/scripts/strings/commands.tsv` | 表头注释改成「闭集声明在 `cmd-help.sh`」；去掉 `{effect} {faces}`（无替换点，§6.1） |
| `skills/teamsmith/scripts/strings/help.en.tsv` | 同上 |
| `skills/teamsmith/tests/help-surface.sh` | 新 `locale` 组（8 条）；`coverage` 加内部入口闭集 4 条、可达性 2 条、G4 守卫 1 条；选段器拒绝未知/过期段名（rc=2）；删掉悬空的 `check_scale`/`check_layout` 分支；新增 6 条红侧（⑨–⑭）；`flip_run` 在变异落在夹具自身时改跑副本自己的夹具；`has_cjk` 让夹具自己的 CJK 判定也不再随 locale 变；lang 探针的告警文件移进夹具临时根 |
| `skills/teamsmith/scripts/lib/cmd-config.sh` | 六处拒绝语去行话（含退出码图例）；退出码、审计行、写入行为一字未动 |
| `skills/teamsmith/tests/config-cli.sh` | validate 组把「报错含『只读』」这条黑话断言换成行为判据（退出码 5 + 点名 `.pi/team/config.sh` + 契约 sha 不变 + 不含行话）；新增 O7 红侧 |
| `skills/teamsmith/tests/smoke.sh` | §51 的 FAST 选集加 `locale` 组 |
| `skills/teamsmith/tests/section-paths.tsv` | §51 的**数据列**补 `skills/teamsmith/scripts/lib/cmd-config.sh` |
| `docs/team/reports/P278-verify.md` | 本报告 |

改动面 = 这 8 个产品/夹具文件 + 本报告；`openspec/` 一字未动（`git diff --name-only main...HEAD` 里没有 `openspec/`）。

## 1. 逐条对照任务书（`tasks.md` 0–7 节）

| 任务书要求 | 落地 | 证据 |
|---|---|---|
| 0.3 改前基线 | 12 行对照表 + 53 页探针 | §3.1（`LC_ALL=C` 下 en 248 行越界、zh 43 处非法 UTF-8） |
| 1.1 O1 宽度与 locale 解耦 | 宽度引擎重写 | §3.2 locale 组 8 条全绿；§4 红侧⑨ |
| 1.2「声明的宽度真的折住」进门禁 | 断言「每行 ≤ 渲染宽度」（默认与 64 格） | §3.2；四种宽度 × 两语言独立探针 0 违规 |
| 1.3 只判行为，不判措辞/缩进/深度/顺序 | locale 组不碰这四样 | §3.2 断言文本 |
| 2.1 O2 内部入口闭集 | `coverage` 4 条（双向相等、无页面打印、清单不许有 `__` 名） | §3.2；红侧⑩⑪ |
| 2.2 声明闭集写在一处 | `local internal="__inbox-write __panel-data"`（挨着 `team_internal_labels`） | `help-surface.sh:697` |
| 3.1 O6 可达性断言 | `coverage` 2 条（菜单分组入口双向相等、每命令经组页可达） | §3.2；红侧⑫⑬ |
| 3.2 找不到时点名分组与命令 | finding 文案带分组名 + 它下面的命令清单 | §4 红侧⑬ |
| 3.3 不复活 `layout` 组 | 未新增；悬空分支删除 | `grep -n 'check_layout\|check_scale' help-surface.sh` 无输出 |
| 4.1 G4 未声明占位符判红 | 载入期扫描：非零退出 + 点名 token 与来源表 + 不打印页面 | §4 G4 守卫与红侧⑭ |
| 4.2 反向（声明了没人用）也判红 | 同一扫描的第二半 | §6.1 |
| 4.3 `{effect}/{faces}` 无替换点 → 不声明 | 闭集 6 个，全部有替换点 | §6.1 |
| 5.1 O7 拒绝语去行话 | 六处改写 | §3.3 before/after |
| 5.2 同族提示一起查 | schema 的「控制台不写」→「命令不写」 | §3.3 |
| 5.3 行为判据（拒绝仍发生、退出码不变、提示含路径） | config-cli 四条断言 | §3.3 |
| 5.4 措辞由评审把关、不设门禁断言 | 只断言「不含行话」，不断言具体措辞 | §3.3 |
| 6.1 §51 路径登记补 `cmd-config.sh` | 数据列补路径 | §3.4 |
| 6.2 §51 在选集里 + `section-needs-audit` | 两条都跑 | §3.4、§3.5 |
| 6.3 段预算 | §51 实测 264s / 预算 5200s，预算表未动 | §3.5、§6.6 |
| 7.1 O6 卫生半条：未知段名拒绝 | 选段器白名单 + rc=2 | §4 红侧「选段器」 |
| 7.2 给红侧 | 见上 | §4 |

## 2. 不变量核对（任务书「不变量」一节）

- 命令名/旗标名/退出码：`invariants` 组全绿；`routes.sh` 的 Walk A 221 条断言全绿（§3.6）。
- `--print`/`--json` 字节：`lang` 组的「`team paths --json` 两种语言逐字节相同」「`team monitor --print` 相同」全绿（§3.2）。
- 语言机制：`lang` 组全绿（非法 `TEAM_LANG` 一行告警 + 回退、缺键可见）。
- 面板：没碰 `panel/`；`config set` 的退出码、审计行、写入字节不变（§3.3 的 sha 断言）。
- 既有 9 条 `coverage` 断言、`lang`/`claims`/`invariants`/`route` 各条、既有 8 条红侧：一条没删（`--all` 的 ✓105 里都在）。
- 默认宽度、UTF-8 locale 下 53 页输出与 HEAD **逐字节相同**（§3.2）。

## 3. Verification evidence

全部在本分支树、`TMPDIR=/var/tmp/p278` 下真跑（本机 `/tmp` 是 15G tmpfs 且当时 93% 占用，见 §6.4）。

### 3.1 改动前基线（任务书 0.3）

```
$ for loc in C C.UTF-8; do for lang in en zh; do for spec in "" "help dispatch" "help meeting"; do
    out="$(cd /tmp && LC_ALL=$loc TEAM_LANG=$lang bash skills/teamsmith/scripts/team $spec)"
    # 行数 / 最长行宽（python3 unicodedata，宽字符 2 格）/ 是否合法 UTF-8
C        lang=en spec=<menu>         lines=25   maxcells=106  utf8=valid
C        lang=en spec=help dispatch  lines=41   maxcells=106  utf8=valid
C        lang=en spec=help meeting   lines=46   maxcells=120  utf8=valid
C        lang=zh spec=<menu>         lines=26   maxcells=106  utf8=INVALID
C        lang=zh spec=help dispatch  lines=41   maxcells=106  utf8=INVALID
C        lang=zh spec=help meeting   lines=43   maxcells=98   utf8=INVALID
C.UTF-8  lang=en spec=<menu>         lines=26   maxcells=100  utf8=valid
C.UTF-8  lang=en spec=help dispatch  lines=43   maxcells=100  utf8=valid
C.UTF-8  lang=en spec=help meeting   lines=47   maxcells=100  utf8=valid
C.UTF-8  lang=zh spec=<menu>         lines=25   maxcells=100  utf8=valid
C.UTF-8  lang=zh spec=help dispatch  lines=36   maxcells=100  utf8=valid
C.UTF-8  lang=zh spec=help meeting   lines=39   maxcells=100  utf8=valid
```

53 页（菜单 + 8 组页 + 44 命令页）在 `LC_ALL=C`、宽度 100 下的独立探针（HEAD 树）：

```
$ bash /tmp/p278-render.sh <HEAD 树> <out> C en 100 && python3 /tmp/p278-width-check.py 100 <out>
checked 53 pages at width 100 | violations: 248      # en：248 行超过声明的 100 格
$ bash /tmp/p278-render.sh <HEAD 树> <out> C zh 100 && python3 /tmp/p278-width-check.py 100 <out>
INVALID-UTF8 group--seats.txt …   INVALID-UTF8 group--start.txt …   INVALID-UTF8 group--versions.txt …
checked 53 pages at width 100 | violations: 43        # zh：43 处（含在汉字中间截断）
```

选段器的假绿口子（裁定 4 的红侧基线）：

```
$ bash skills/teamsmith/tests/help-surface.sh --select layout
help-surface.sh: line 1104: check_layout: command not found
== 结果 ==  ✓ 0  ✗ 0  SKIP 0
$ echo $?   → 0
$ bash skills/teamsmith/tests/help-surface.sh --select nosuchsection    # 同样 rc=0、✓0 ✗0
```

G4 的基线：`team_help_subst` 只替换 `{project}`/`{meeting_ttl}`，表里其他 `{…}` 原样打印，没有任何检查。

### 3.2 本变更后

`--all`（第 2 次；第 1 次的红见 §5.1）与 `--flip`：

```
$ bash skills/teamsmith/tests/help-surface.sh --all
== coverage · 清单 ↔ dispatcher ↔ 三级渲染 ==
  ✓ dispatcher 的每个标签都有记录或别名声明（49 个标签）
  ✓ 清单里每个命令都被 dispatcher 接受
  ✓ 每个分组 id 都能解析到组页，且不与命令名冲突
  ✓ 每个命令都有页，且用法块里以自己开头（44 个命令）
  ✓ 没有任何页面打印缺键标记（清单字段与散文键一一对上）
  ✓ 每个命令页的 Arguments 行数与该命令的旗标数相同（44 个命令）
  ✓ 每个命令页打印的用法行与清单逐条相同（44 个命令 × 全部用法片段）
  ✓ 每个组页打印的用法行与清单逐条相同（8 个组）
  ✓ 每个别名都打印主命令的页并点名该别名
  ✓ 内部入口清单与 dispatcher 的 __ 标签双向相等（2 个）
  ✓ 没有任何页面打印内部入口的名字（菜单/组页/命令页，两种语言）
  ✓ 清单里没有以 __ 开头的命令名
  ✓ 菜单的分组入口与清单的分组表双向相等（8 个组）
  ✓ 每个命令都能从菜单经组页在三级内到达（44 个命令）
  ✓ G4：未声明的 {undeclared} 让渲染非零退出（rc=1）、点名 token 与来源表、且不打印那一页
== locale · 同一输入在任何 locale 下同一份字节、每行不超过 TEAM_HELP_WIDTH、输出合法 UTF-8 ==
  ✓ locale(en): 53 个页面在 LC_ALL=C 与 LC_ALL=C.UTF-8 下逐字节相同
  ✓ locale(en, C/100): 53 个页面都是合法 UTF-8 且每行 ≤ 100 格
  ✓ locale(en, C.UTF-8/100): 53 个页面都是合法 UTF-8 且每行 ≤ 100 格
  ✓ locale(en, C.UTF-8/64): 53 个页面都是合法 UTF-8 且每行 ≤ 64 格
  ✓ locale(zh): 53 个页面在 LC_ALL=C 与 LC_ALL=C.UTF-8 下逐字节相同
  ✓ locale(zh, C/100): 53 个页面都是合法 UTF-8 且每行 ≤ 100 格
  ✓ locale(zh, C.UTF-8/100): 53 个页面都是合法 UTF-8 且每行 ≤ 100 格
  ✓ locale(zh, C.UTF-8/64): 53 个页面都是合法 UTF-8 且每行 ≤ 64 格
== lang · 默认英文、TEAM_LANG 的机制（切中文 / 非法值告警回退 / 缺键可见）、机器出口 ==
  ✓ 缺省语言是英文   ✓ TEAM_LANG=zh 切到中文
  ✓ 命令路径、旗标与用法片段在两种语言下逐字节相同
  ✓ 非法 TEAM_LANG 打印一行点名告警、状态不变（rc=0）
  ✓ 缺键渲染可见：标记点名 cmd.status.what，并用英文值兜底（不空白、不崩）
  ✓ team paths --json 在两种语言下逐字节相同
  ✓ team monitor --print 在两种语言下相同（已抹去时钟与计数这类易变字段）
== claims · 封闭词表 + 逐命令探针（断言效应，不看退出码） ==      （44 个命令的探针全绿）
== invariants · 命令名/旗标名/跨规格字面量一个不改（逻辑） ==      （全绿）
== route · 三级可达、两条入口逐字节相同、未知 token exit 2、无项目可用 ==   （全绿）
== 结果 ==  ✓ 105  ✗ 0  SKIP 0
$ echo $?
0
```

非 UTF-8 locale 下的同一条命令（这正是任务书「验收」里那一行；修复前它是 ✗2，见 §6.5）：

```
$ LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --all
== locale · … ==
  ✓ locale(en): 53 个页面在 LC_ALL=C 与 LC_ALL=C.UTF-8 下逐字节相同
  …（8 条）
== 结果 ==  ✓ 105  ✗ 0  SKIP 0
$ echo $?
0
```

`LC_ALL=C … --select locale` 单跑（证伪「绿只来自 UTF-8 locale」）：

```
$ LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --select locale
  ✓ locale(en) / locale(en, C/100) / locale(en, C.UTF-8/100) / locale(en, C.UTF-8/64)
  ✓ locale(zh) / locale(zh, C/100) / locale(zh, C.UTF-8/100) / locale(zh, C.UTF-8/64)
== 结果 ==  ✓ 8  ✗ 0  SKIP 0
$ echo $?
0
```

独立探针（夹具之外的 python3 计数器；53 页 × 四种宽度 × 两种语言）：

```
$ for w in 100 72 64 48; do for lang in en zh; do
    bash /tmp/p278-render.sh <本分支树> <out> C.UTF-8 $lang $w; python3 /tmp/p278-width-check.py $w <out>
w=100  en  checked 53 pages at width 100 | violations: 0
w=100  zh  checked 53 pages at width 100 | violations: 0
w=72   en  checked 53 pages at width 72 | violations: 0
w=72   zh  checked 53 pages at width 72 | violations: 0
w=64   en  checked 53 pages at width 64 | violations: 0
w=64   zh  checked 53 pages at width 64 | violations: 0
w=48   en  checked 53 pages at width 48 | violations: 0
w=48   zh  checked 53 pages at width 48 | violations: 0
```

**行为不变的正面证据**（默认宽度 100、UTF-8 locale，53 页逐字节对照 HEAD 的 skill 副本）：

```
$ bash /tmp/p278-render.sh /var/tmp/p278-pristine <out-head> C.UTF-8 en 100
$ bash /tmp/p278-render.sh <本分支树>              <out-new>  C.UTF-8 en 100
$ diff -rq <out-head> <out-new>
（无输出：en 53 页逐字节相同；zh 同样无输出；两种 locale 之间也逐字节相同）
```

### 3.3 O7：拒绝语 before / after（同一个 scratch 项目，同一批命令）

```
$ team config set TEAM_PROJECT other          # 改前
✗ TEAM_PROJECT 是只读键，控制台不改它
  项目身份：只能改项目配置文件 .pi/team/config.sh 里的这一行；…
$ echo $?   → 5
$ team config set TEAM_NOSUCHKEY 1            # 改前
✗ TEAM_NOSUCHKEY 不是已知的项目设置键
  已知键：team config list；自定义键请手改 <项目根>/.pi/team/config.sh
$ echo $?   → 5

$ team config set TEAM_PROJECT other          # 改后
✗ TEAM_PROJECT 不能由命令改
  项目身份：只能改项目配置文件 .pi/team/config.sh 里的这一行；…
$ echo $?   → 5
$ team config set TEAM_NOSUCHKEY 1            # 改后
✗ TEAM_NOSUCHKEY 不是已知的项目设置键
  已知键：team config list；自定义键写在 <项目根>/.pi/team/config.sh 里
$ echo $?   → 5
```

行为判据（`config-cli.sh validate` 组）：

```
$ bash skills/teamsmith/tests/config-cli.sh list validate roster
  ✓ refuse：TEAM_PROJECT 的退出码是 5
  ✓ refuse 的报错点名项目配置文件 .pi/team/config.sh
  ✓ refuse 的报错不含「只读/控制台」行话
  ✓ refuse 被拒之后契约逐字节未变
== 结果 ==  ✓ 144  ✗ 0 SKIP 0
$ echo $?
0
```

### 3.4 §51 的路径登记与选集

```
$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh
decision=RUN
sections=129
keys=19
reason=51 ← skills/teamsmith/scripts/lib/cmd-config.sh
…
51	skills/teamsmith/scripts/lib/cmd-config.sh
$ echo $?
0
```

（改动前同一条命令的输出里没有 `51` 行。）整份改动面的选集（33 段，含 §51）：

```
$ bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
0d … 0e 0f 0h 0i 2 7b 11h 14b 15c 12b-h0d 14 14c 18 18b 26 27 28 33 34b 36 38 40 51 55 56 59 61 …
$ echo $?
0
```

### 3.5 门禁选段

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 51
== #5 51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99） == …
  ✓ 51 routes.sh 全绿（221 条断言，2 条可见跳过）
  ✓ 51 帮助面夹具（help-surface.sh · FAST 静态组）全绿（43 条断言）
  ✓ 51 名册/契约夹具（list+validate+roster）全绿（144 条断言）
#5 51 · 用法诚实性… · 用时 270s · ✓3 ✗0 SKIP0 · ticks 3
$ echo $?
0

$ bash skills/teamsmith/tests/section-needs-audit.sh --keys 51
== needs 逐键审计 ==
ok   51       rc=0  #5 51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99） · 用时 238s · ✓3 ✗0 SKIP0 · ticks 3
== needs 逐键审计结果 ==  pass 1  bad 0  （共 1 键）
$ echo $?
0
```

改动面选集（33 段，3054s）的唯一红：

```
$ bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
== 选段结果 ==  ✓ 1382  ✗ 1
  ✗ 36⑧ 产品面检出探针有失败（5 条）
      bad: ⑤b 混合形状 --select 58 退出 0（期望 [0]，实际 [1]）
      bad: ⑩ 产品面树 --select 58 退出 0（豁免清单不再假红）（期望 [0]，实际 [1]）
      bad: ⑩ 产品面：--select 58 的红数为 0（期望 [0]，实际 [1]）
      …
$ echo $?
1
```

这条红的根因是 §5.2 的既有 §6f F8 红（§58 的依赖链里带着 §6f），不是本变更。

### 3.6 其余验收

```
$ bash skills/teamsmith/tests/routes.sh
== walk · 帮助面每一级（菜单 / 组页 / 命令页）↔ 命令清单 ↔ 真解析器 ==
  ✓ 清单盖住 dispatcher 接受的每个名字（50 个标签，内部标签 __* 不算命令名）
  ✓ 清单里每个命令都被 dispatcher 接受（44 个命令）
  …（menu + 8 组页 + 44 命令页逐页判过）
== 结果 ==  ✓ 221  ✗ 0  （2 条可见跳过）
$ echo $?   → 0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11785 effective line(s); retired 0; undeclared 0
$ echo $?   → 0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/verify scope=published files=1566 hits=0 names=ok user=resolved
$ echo $?   → 0

$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 20 passed, 0 failed (20 items)
$ echo $?   → 0

$ git diff --check && git status --short
$ echo $?   → 0
```

试归档投影（本变更在临时副本里真的能归档，且归档后 validate 仍绿）：

```
$ cp -a openspec /var/tmp/p278-proj/openspec && cd /var/tmp/p278-proj/openspec
$ openspec validate --all --strict    → VALIDATE1-RC=0（20 passed，含 change/help-robustness）
$ openspec archive -y help-robustness → ARCHIVE-RC=0（help-surface: +1 ~2；归档为 2026-10-15-help-robustness）
$ openspec validate --all --strict    → VALIDATE2-RC=0（19 passed，change 已不在）
$ ls changes/ → archive orphan-visibility slash-team tmux-identity-scope
```

## 4. Flip evidence（红 → 绿）

`--flip` 在冻结树上一次跑完（rc=0）：

```
$ bash skills/teamsmith/tests/help-surface.sh --flip
  ✓ 翻转 ①组页漏一条命令： ✗ 组页 observe 与清单不一致（< status [<ID>]）
  ✓ 翻转 ②删一条命令记录： ✗ dispatcher 接受的 bg 在清单里没有记录（也没有别名声明）
  ✓ 翻转 ③未知 token 走成 exit 0： ✗ route: team frobnicate --help 的退出码是 0（应为 2）
  ✓ 翻转 ④帮助路径读配置： ✗ route: 无项目目录时 team help 失败
  ✓ 翻转 ⑤非法 TEAM_LANG 静默： ✗ 非法 TEAM_LANG 没有可见告警或状态变了（rc=0）：
  ✓ 翻转 ⑥缺键静默（不渲染标记）： ✗ 缺键没有渲染出可见标记或没有另一语言兜底
  ✓ 翻转 ⑦机器出口跟着语言走： ✗ 语言改变了 team paths 的输出
  ✓ 翻转 ⑧声明的旗标没有散文键： ✗ 命令 dispatch 的页打印了缺键标记：--fresh  «missing key: …»
  ✓ 翻转 ⑨宽度计算退回 locale 依赖： ✗ locale(zh): 1 个页面随 locale 变： command--dispatch[line 3 differs]
  ✓ 翻转 ⑩dispatcher 多一个 __ 标签： ✗ 内部入口清单：dispatcher 的 __ 标签 __probe-x 不在声明清单里
  ✓ 翻转 ⑪声明清单里删一个内部名： ✗ 内部入口清单：dispatcher 的 __ 标签 __inbox-write 不在声明清单里
  ✓ 翻转 ⑫清单删一条分组记录： ✗ 命令 mark-loaded 不可达：它的分组 versions 没有声明，没有组页会列它
  ✓ 翻转 ⑬菜单渲染器跳过一个已声明的分组： ✗ 分组 versions 在菜单里没有入口，它下面的命令 mark-loaded version changelog 变成不可达
  ✓ 翻转 ⑭去掉未声明占位符的检查： ✗ G4：表里出现未声明的 {undeclared} 时渲染仍 exit 0（那一页会把它原样打出来）
== 结果 ==  ✓ 119  ✗ 0 SKIP 0
$ echo $?   → 0
```

⑨–⑭ 是本变更新增的红侧，每条都是「破坏 → 指定断言红并点名 → 还原 → 全绿」。⑨ 的破坏是把 `team_help_cp_cells` 的
宽度判定改回看 `LC_ALL`/`LANG`（正是改动前那个缺陷的形状）。

O7 的红侧（`config-cli.sh` 的 validate 段内，scratch 树里删掉 refuse 分支）：

```
$ bash skills/teamsmith/tests/config-cli.sh validate
  ✓ P278 红侧前置：scratch 树原状 validate 段绿（rc=0）
  ✓ P278 mutant：refuse 分支被删掉（放行）
  ✓ P278 红侧：refuse 放行 → validate 段非 0（rc=1）并点名 TEAM_PROJECT
    --- P278 红侧尾部 ---
      ✗ TEAM_PROJECT=x → 5（refuse）（期望 [5]，实际 [4]）
      ✗ refuse：TEAM_PROJECT 的退出码是 5（期望 [5]，实际 [4]）
  ✓ P278 还原：refuse 分支回来 → validate 段重新绿（rc=0）
== 结果 ==  ✓ 29  ✗ 0 SKIP 0
```

选段器的红侧（裁定 4 那条假绿）：

```
$ bash skills/teamsmith/tests/help-surface.sh --select layout      # 改前：rc=0，✓0 ✗0，只有一行 command not found
$ bash skills/teamsmith/tests/help-surface.sh --select layout      # 改后：
help-surface: 未知的选段 layout（可用：coverage, locale, lang, claims, invariants, route）
$ echo $?   → 2
```

（`layout`/`scale`/`content` 三个名字在夹具里早已没有实现，现在与拼错的名字一样按未知段名拒绝。）

G4 的守卫（夹具自带 scratch 副本，不是变异）：

```
$ bash skills/teamsmith/tests/help-surface.sh --select coverage
  ✓ G4：未声明的 {undeclared} 让渲染非零退出（rc=1）、点名 token 与来源表、且不打印那一页
```

## 5. 两条既有红（不是本变更引入，需 PM 裁定）

### 5.1 `mark-loaded` 的幂等声明与实现冲突（约 50% 概率红）

`--all` / `--flip` 的 claims 组里，既有探针会红一条：

```
  · 探针 mark-loaded rc=0   变化=state
  ✓ claims: mark-loaded 写了声明的面（state）
  ✗ claims: mark-loaded 声明幂等，但第二次跑改了状态
```

根因（确定，可复现）：`mark-loaded` 每次运行都重写 `state/pm-loaded.env`，其中 `AT=` 是**秒级**时间戳
（`team_timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }`），而 `commands.tsv` 把它的 `undo` 声明成 `idempotent`。
探针的两次运行之间只隔两次 `fp_all`（几百毫秒），**是否跨秒**决定这条断言的红绿：

```
$ team mark-loaded   # 同一个 scratch 项目，间隔 1.2s 跑两次
$ diff <第一次的 pm-loaded.env> <第二次的 pm-loaded.env>
6c6
< AT=2026-10-15T11:11:30Z
---
> AT=2026-10-15T11:11:31Z
$ echo $?   → 1
```

本轮实测的出现次数（不靠重跑掩盖）：`--all` 第 1 次红、`--flip` 第 1 次红、复验轮 `--all` 红、`--flip` 红，
第 2 次两绿。`cmd-update.sh` 与探针代码都不在本 diff 里（Deliverables 的 8 个文件可核），HEAD 树上同样会红。

补充事实：`AT=` 只被写、**没有任何读取点**（`grep` 全仓只有 `printf 'AT=%s\n'` 这一处写入）。所以修法有两条，
都不在本任务书范围内，请 PM 选一条另开任务：
① 产品侧幂等：版本/指纹没变时保持原文件（`AT` 是「本会话何时加载」的记录，第二次调用覆盖它本身也可疑）；
② 把 `commands.tsv` 里该行的 `undo` 改成非幂等（承认它每次都会重写），代价是这条幂等断言失去对象。
不建议的第三条（夹具比较时忽略时间戳）会把真缺陷一起遮掉。

### 5.2 §6f 的 F8 断言红 → §36⑧ → 改动面选集的唯一红

```
$ bash skills/teamsmith/tests/smoke.sh --select 6f          # 本分支树
  ✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）
#10 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 · 用时 19s · ✓124 ✗1 SKIP0 · ticks 125

$ git clone -q --no-local <主检出> /var/tmp/p278-main-clone && cd /var/tmp/p278-main-clone
$ git log --oneline -1 → 54aaf1e8 docs(team): re-freeze the help-robustness candidate after the fixture follow-up
$ bash skills/teamsmith/tests/smoke.sh --select 6f          # pristine main（本变更不在其中）
  ✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）
#10 6f · agent adapter（任意 TUI agent）：渲染 / 占位符 / 文档契约 / 降级 · 用时 18s · ✓124 ✗1 SKIP0 · ticks 125
```

决定性的第三条证据：让检出形状探针保留现场（`P148_SHAPE_KEEP=1`），看它三棵 scratch 树里 `--select 58` 到底红在哪：

```
$ P148_SHAPE_KEEP=1 bash skills/teamsmith/tests/checkout-shape-probe.sh
$ D=<探针现场>; for f in nest-po10.log nest-hy58.log nest-inev58.log; do grep '^  ✗' "$D/$f"; done
  ✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）      # 产品面树（po10）
  ✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）      # 混合形状（hy58）
  ✗ 坏模板下不给半截 notify 命令（F8）（不该出现 [scripts/team notify pm]）      # 内部树 + 清单在位（inev58）
#10 6f … · ✓124 ✗1 SKIP0 · ticks 125                                       # 三棵树里 §58 的红都只有这一条
```

同一条断言在本分支树、pristine main、探针的三棵 scratch 树上逐字相同地红 → **既有红，不是本变更引入**。它经由
§58 的依赖链把 `--select 58` 判红，§36 的检出形状探针（⑤b/⑩ 期望 `--select 58` 退出 0）随之红 5 条，于是改动面
选集出现那 1 条红。本变更的 8 个文件与 §6f/§58 的路径集合无交集（`section-paths.tsv` 可核）。

## 6. Decisions and deviations

### 6.1 占位符闭集是 6 个，不是 8 个（`{effect}`/`{faces}` 不声明）

两处表头注释原文写着「允许的占位符：`{project} {meeting_ttl} {effect} {faces} {undo_cmd}`」。但 `{effect}`/`{faces}`
**没有任何替换点**：主张句是 bash 侧拼的（`team_help_effect_text` + `team_help_face_list`）。把它们写进闭集有两个后果：
①读代码的人以为有替换；②「未声明即判红」对它们失效（已声明 → 原样打印还照样绿）。所以闭集是
`{project} {meeting_ttl} {token} {sub} {cmd} {undo_cmd}`——六个成员在 `cmd-help.sh` 里各有替换点
（`team_help_subst`、`team_help_refuse`、别名行、`team_help_undo_text`），两处表头注释改成「闭集声明在
`cmd-help.sh`」并列出这六个。反向那一半照旧判红，实测（scratch 副本里塞一个没人用的 `{nowhere}`）：

```
$ TEAM_LANG=en bash <scratch 副本>/skills/teamsmith/scripts/team help dispatch
teamsmith: the declared placeholder {nowhere} appears in none of the help tables
$ echo $?
1
```

### 6.2 页面首行也走折行（宽度上界的要求）

`team_help_menu` 的首行、组页/命令页的页头原本是 `printf` 直出。宽度 72 格时组页首行是 80–97 格，
「声明折到 N 格就必须折住」因此不成立。三处首行交给 `team_help_flow 0 0`：宽度 100 时输出逐字节不变（§3.2 对照），
更窄时才折行。

### 6.3 宽度引擎是重写，不只是换一张分类表

- 旧实现：`$'\uXXXX'` 括号区间 + `${s:i:1}`。两者都随 locale 变（非 UTF-8 下区间退化成字面字节、吞掉 ASCII；切片按字节）。
- 新实现：`LC_ALL=C printf | od -An -tu1` 取一次原始字节 → 手写 UTF-8 解码（畸形字节按单字节码点处理，绝不丢字节）
  → 码点判 0/1/2 格 → 折行按**码点边界**切片（`LC_ALL=C` 下的 `${s:off:len}`）。
- 顺带的成本：旧 `team_help_wrap` 每个词起一个子 shell 量宽度，一页 2.8s、53 页夹具十几分钟。新实现把「取字节 → 判格
  → 切词」合成一次遍历，一页约 0.09s：改动前那次四组选集（coverage+lang+invariants+route）跑了 587s，现在 `--all`
  （六组，含 44 条承诺探针）只要 208–251s。不改变任何输出字节（§3.2 对照）。

### 6.4 夹具的告警文件移进自己的临时根

`check_lang` 的非法语言探针把 stderr 写死到 `/tmp/hs-warn.txt`，越出夹具自己承诺的临时根。本机 `/tmp` 是 15G tmpfs、
当时 93% 占用，写失败时**重定向**先失败（命令根本没跑），断言就红了——本轮 `--all` 第 1 次正是这样红的
（`rc=1`、告警为空）。改成 `$tmp/hs-warn.txt` 后与 `/tmp` 余量无关，也去掉了并发跑两个夹具时同名文件互相覆盖的隐患。

### 6.5 夹具自己的 CJK 判定也曾随 locale 变（新发现，已修）

任务书「验收」要求 `LC_ALL=C bash … --all`。第一次跑它是 ✗2：

```
$ LC_ALL=C bash skills/teamsmith/tests/help-surface.sh --all
  ✗ 缺省语言不是英文（菜单里有 CJK 字符）
  ✗ 非法 TEAM_LANG 没有回退英文
== 结果 ==  ✓ 104  ✗ 2  SKIP 0
```

两条断言用的是 `grep '[一-龥]'`，而 `LC_ALL=C` 下这是个字节区间、几乎匹配任何字节：同一份菜单在一种 locale 下被判成
中文、另一种下判成英文。**判据随调用者 locale 变**，正是本变更从产品里移除的那个缺陷，检查器不该把它带回来。
改用 `has_cjk`（python3 解 UTF-8 后按码点判断）后，两种 locale 下同一条命令都是 ✓105 ✗0（§3.2）。

### 6.6 门禁登记两处、预算未动

- `smoke.sh` §51 的 FAST 选集加 `locale`：不加就只有完整门禁才跑这一组。
- `section-paths.tsv` §51 补 `skills/teamsmith/scripts/lib/cmd-config.sh`：注意是**数据列**（第 3 列），第 4 列是排除列；
  写错列会让改 `cmd-config.sh` 时 §51 反而不跑。
- §51 的预算（`section-budgets.tsv`，5200s）**没动**：实测 238–270s（并发跑时 668s）。该行备注说实测带由 P260 的
  门禁运行确认后收紧，那是 PM 的事。

## 7. Suggested next steps

- **PM 复验**：`bash skills/teamsmith/tests/help-surface.sh --all`（约 4 分钟）、`--flip`（约 9 分钟）、
  `LC_ALL=C … --all`（约 4 分钟）；`TMPDIR` 指到 `/var/tmp`（本机 `/tmp` 余量不足会误红，§6.4）。
- **§5.1 需要裁定**：`mark-loaded` 的 `undo=idempotent` 与「每次重写秒级时间戳」冲突，claims 组约 50% 概率红；
  建议按 ① 产品侧幂等修（`AT` 无读取点，风险小），或按 ② 改声明（会失去这条断言的对象）。
- **§5.2 需要裁定**：§6f 的 F8 断言在 main 上就是红的，会让 `--select 58`/§36⑧/改动面选集连带红；
  建议单独开一个任务修 §6f，否则任何走 `--paths` 的复验都会看到这条与本次改动无关的红。
- 本变更的 2 MODIFIED + 1 ADDED 已由 `openspec validate --all --strict` 与试归档投影（§3.6）确认可归档；
  归档动作按协议留给 PM，且需要用户确认。
- `openspec/changes/help-robustness/tasks.md` 的 0–7 节我没有勾选（apply 阶段的自证由 PM 在归档前处理）；
  若要按 §1 的证据表勾选，回一句即可。
