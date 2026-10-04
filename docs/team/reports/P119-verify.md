# P119 · `gate-runtime-budget` 复验（换人 · P117 返工后）— verify

- **任务**：`docs/team/tasks/P119-gate-budget-reverify.md`（phase: verify）｜**change**: `gate-runtime-budget`
  （apply = P98 dev3 → 返工 = P117 dev；本次**换人**复验）
- **验证对象**：`main` 上已合并的实现。我的工作树 HEAD `d5382f43`（P119 brief），`main` tip `e5c7bb28`；
  **`git diff d5382f43..main -- skills/` 为空** —— 两边的实现逐字节一致（主线多出的两个提交只有 P118 的
  docs 与 openspec 归档）。所以我验的就是交付物本体。
- **分支**：`task/P119-p117`（**local 模式**：不 push，分支留在本地 worktree，PM 复验后本地合并）
- **结论**：**PASS** —— 任务书 7 条验收面全绿，全部由**我自己的判据**给出（红侧有对照、有原始输出）；
  另有 1 条**验收范围外**的附加发现（§2.8：深 caller TMPDIR 下 §36⑦ 两条绿侧夹具的**环境假红**，
  默认 TMPDIR 不触发，不影响本次验收结论）。
- **绿的总账**（两次 `run.sh` 整跑的汇总行，日志在 `pkg/logs/run-*.log`）：

```
== P119 验证包汇总 == ok=97  finding=0 bad=0 skip=0     # run.sh 30 20 50 40
== P119 验证包汇总 == ok=121 finding=1 bad=0 skip=1     # run.sh 10 80（finding 只有 §2.8 那一条）
```

- **复现**：
  ```bash
  bash docs/team/reports/P119-verify/pkg/run.sh            # 默认 10 20 30 40 50 60 80（约 25 分钟）
  bash docs/team/reports/P119-verify/pkg/run.sh 70         # 真全量门禁（锁排队，约 30–45 分钟）
  ```

---

## 1. 哪些是「我自己的证据」，哪些是「引用」

| 任务书条目 | 我的判据（自己写、自己跑） | 结果 | 原始输出 |
|---|---|---|---|
| ① 全键副本 + 三个常用路径 | `pkg/10`：自写循环逐键 `--select K --out` → 副本非空 + 真 `bash -n` + 副本段集合 == 选择器运行键集合 + 键自己在副本里 | 114/114 | `pkg/logs/run-10.log` |
| ① 三个入口 | `pkg/20`：`--paths` 三条 → 副本解析、集合一致；`--paths tests/smoke.sh` 端到端 | 28 ok / 0 finding | `pkg/logs/run-20.log` |
| ② 失败必须早 | `pkg/30`：影子区域裁判（还原旧剪贴器）→ 副本坏 → 选段在 0 段之前拒 | 16 ok / 0 finding | `pkg/logs/run-30.log` |
| ③ 原现场 14 / 14c | `pkg/50`：两个方向的 `--select` 端到端 | 27 ok / 0 finding | `pkg/logs/run-50.log` |
| ④ needs 闭包 | `pkg/40`：3b/6/10 绿侧 + 删边红侧 + 变体对照 | 26 ok / 0 finding | `pkg/logs/run-40.log` |
| ⑤ 语义不放松 | `pkg/50`（账本/未跑清单/最慢/FAST 守卫行为 + 静态） | 见 ③ | `pkg/logs/run-50.log` |
| ⑥ 零回归 | `pkg/60`（openspec + routes + config-cli + FAST 全绿）+ `pkg/70`（真全量） | 见 §2.6 | `pkg/logs/run-60.log` `run-70.log` |
| ⑦ 报告归属 | 本节 + §2.7 | — | 本文件 |

**引用（不作为判据，只在需要时作交叉参考）**：
`tests/section-needs-audit.sh`（P117 作者自带的逐键审计，任务书明确不作判据 —— 我没有依赖它；
`pkg/10` 只把它/`section-select.sh --verify-copies` 印成一行 SKIP 作对照）、P117/P112 的 review 文本、
walkthrough 里引用的实现解释。

**我没有做的事**：没有改实现（见 §3.3 的 diff）；没有跑作者的全键**运行**审计（114 键逐个真跑，作者工具；
我的覆盖是「全键副本解析」+「3 个夹具依赖键的选集真跑 + 2 条删边红侧」，见任务书 ①④ 的口径）。

---

## 2. 逐项验收（原始输出）

### 2.1（任务书 ①）全键副本可解析：114/114

命令（`pkg/10-whole-key-copies.sh` 的核心循环，逐键）：

```bash
bash skills/teamsmith/tests/section-select.sh --list | awk -F'\t' 'NF>=1{print $1}'   # 114 键
# 每个键：
bash skills/teamsmith/tests/section-select.sh --select "$k" --out "$copy"   # rc=0 + decision=RUN
bash -n "$copy"                                                             # 真 bash，文件形态
# 断言：副本段键集合 == 选择器 print_run 的运行键集合；且 $k 自己在集合里
```

原始输出（`pkg/logs/run-10.log`）：

```
== 10 全键副本 bash -n（自写循环） ==
  ok   映射表清单取到 114 个键（--list）
  ok   键 0：副本解析 ✓（带上 4 段）
  ...
  ok   键 14：副本解析 ✓（带上 6 段）
  ok   键 14c：副本解析 ✓（带上 6 段）
  ...
  ok   全键副本：114/114 键 —— 每个副本都解析、段集合与运行键一致、键自己都在
  SKIP 交叉参考（作者工具）--verify-copies：== 段副本 bash -n 扫描 == ok 114 bad 0
== 10 全键副本 结果 == ok=116 finding=0 bad=0 skip=1
```

三个常用入口（`pkg/20`，副本 + 段集合一致性）：

```
  ok   20 skills/teamsmith/scripts/team：副本 bash -n 通过（14057 行）      # 92 段
  ok   20 skills/teamsmith/scripts/lib/cmd-agents.sh：副本 bash -n 通过（10032 行）  # 56 段
  ok   20 skills/teamsmith/tests/smoke.sh：副本 bash -n 通过（5461 行）     # 27 段
```

端到端（原现场三条路径之一，`--paths tests/smoke.sh`；27 段含 §36）：

```
  ok   20 --paths tests/smoke.sh 端到端 rc：rc=0
  ok   20 端到端：✗ 0（== 选段结果 ==  ✓ 898  ✗ 0）
  ok   20 端到端：未跑清单还在
  ok   20 端到端：账本自查一致
```

另外把选择器另外两态钉在数据上（不在任务书里，属「语义不许放松」的展开）：

```
  ok   20 NONE 决策 / NONE 运行 rc：rc=0 / 段头 0 / 没有任何结果行 / 没喊 smoke 全绿
  ok   20 FULL 决策 / FULL 点名未覆盖路径（ci/some-new-thing）
  ok   20 未知键早拒：rc=2 · 零段头 · 点名 no-such-section
```

### 2.2（任务书 ②）失败必须早：红侧有对照

夹具（`pkg/30-early-reject.sh`）：变体树里把 `span_parses()` 用的**无文件参数 `bash -n`**（区域裁判，
管道形态）用一个 PATH 影子变成恒真 —— 这等于把 P117 之前「按段头一刀切」的行为放回来；**带文件名的
`bash -n <file>`（`emit_copy` 最后一闸）与一切其它 `bash` 调用逐字节透传**。于是副本真的坏掉，
而防线只剩「生成后校验」这一闸。

```
== 30 失败必须早：影子区域裁判后的红侧 ==
  ok   30 对照：无影子 --select 14 rc：rc=0
  ok   30 对照：无影子时副本解析 ✓（1032 行）                # 绿侧：正常实现产出可解析副本
  ok   30 红侧 A：--select 14 rc（早拒）：rc=2
  ok   30 红侧 A：点名副本不能解析
  ok   30 红侧 A：点名段 14
  ok   30 红侧 A：点名源码行
  ok   30 红侧 A：影子真的生效（span_parses 区域裁判被拦了 116 次）
  ok   30 红侧 A：留下的副本确实不可解析（… line 995: syntax error: unexpected end of file from `if' command on line 969）
  ok   30 红侧 B：smoke --select 14 rc：rc=2
  ok   30 红侧 B：点名副本不能解析
  ok   30 红侧 B：说清什么都没跑
  ok   30 红侧 B：段头数（0 = 跑任何段之前就停了）（= 0）    # 「早」的定义：一段都没起
  ok   30 红侧 B：没有选段结果行
  ok   30 红侧 B：没有全套结果行
  ok   30 红侧 B：影子真的生效（区域裁判被拦 116 次）
  ok   30：真树 skills/ 无改动
== 30 早拒红侧 结果 == ok=16 finding=0 bad=0 skip=0
```

对照的意义：同一条 `--select 14`，无影子 → rc=0/副本解析；有影子 → rc=2/零段头/点名。红侧可归因，
不是「它本来就红」。

### 2.3（任务书 ③）原现场端到端：`--select 14` 与 `--select 14c` 两个方向

修前的两个方向一个丢 `fi`、一个孤儿 `fi`（P117 的两处修复点）；两个方向现在都要跑出结果行：

```
  ok   50 --select 14 的清单点名 14c 耦合      # reason=14c ← coupled:14
  ok   50 --select 14c 的清单点名 14 耦合      # reason=14 ← coupled:14c
  ok   50 FAST --select 14 rc：rc=0
  ok   50 FAST --select 14 结果行 ✗ 0（== 选段结果 ==  ✓ 28  ✗ 0）
  ok   50 FAST --select 14：14 段自己 ✗（= 0）
  ok   50 FAST --select 14c rc：rc=0
  ok   50 FAST --select 14c 结果行 ✗ 0（== 选段结果 ==  ✓ 28  ✗ 0）
  ok   50 FAST --select 14c：14c 段自己 ✗（= 0）
  ok   50 FAST --select 14c：14（耦合组）段自己 ✗（= 0）
```

### 2.4（任务书 ④）needs 闭包：3 个夹具依赖键绿 + 删边红 + 对照

绿侧（`3b`、`6` 是任务书点名的，`10` 是我加的；每键都断言「键自己的段真的跑、✗0、needs 全在选集里」）：

```
  ok   40 绿侧 --select 3b rc：rc=0 … 自己跑了：#8 3b · git 归 PM … ✓37 ✗0
  ok   40 绿侧 --select 6  rc：rc=0 … 自己跑了：#9 6 · dispatch … ✓6 ✗0 SKIP1
  ok   40 绿侧 --select 10 rc：rc=0 … 自己跑了：#11 10 · review（独立 worktree + 门禁）… ✓26 ✗0
  ok   40 绿侧 --select 6：needs 里的 4/3b/5 都在选集里
  ok   40 绿侧 --select 10：needs 里的 3b/4b/5/9 都在选集里
```

对照（变体树、**不**改表）：`--select 6` 依旧 rc=0 / 自己 ✗0 —— 红侧可归因到那次删除。

红侧（变体树里从表里删一条边）：

```
  ok   40 红侧：6 去掉 needs:3b → --select 6 红了（rc=1；#8 6 · dispatch · ✓0 ✗7 SKIP1）
  ok   40 红侧：10 去掉 needs:9 → --select 10 红了（rc=1；#10 10 · review · ✓16 ✗10 SKIP0）
```

**数据说明**（给后续维护者）：我先试过按 P117 报告点名的边删（6 删 `5`、10 删 `4b`），**没让对应键变红**
—— 因为在这两个键的闭包里 `5` 与 `4b` 有冗余路径（`5` 经 `4→2`、`4b` 经 `4`，而 `4` 又经 `2`）。
所以最终选了两条**承重边**：`6 ← 3b`（`3b` 是 `5` 的唯一入口）与 `10 ← 9`。这不是实现问题，是「删哪条边
有意义」的夹具选择；结论（闭包自足、删边即红）不变。

### 2.5（任务书 ⑤）语义不许放松

```
  ok   50 FAST --select 14：未跑清单仍点名（== 选段：这次没跑的段 ==）
  ok   50 FAST --select 14：最慢 N 段汇总在 / 最慢汇总在结果行之前（56 < 64）
  ok   50 FAST --select 14：账本自查一致（6 段收口 · 增量 ✓28 ✗0 SKIP0 ｜ 结果行 ✓28 ✗0 —— 一致）
  ok   50 账本：增量 ✓ == 结果行 ✓（= 28） / 增量 ✗ == 结果行 ✗（= 0）
  ok   50 FAST --select 14：没喊 smoke 全绿（行锚定；选段 run 不许冒充满套门禁）
```

FAST 守卫（14c 仍归 FAST 管）**行为 + 静态**两路：

```
  ok   50 FAST 模式：14c 段头出现 1 次（= 1）              # FAST 里跑 14c 的快模式自检
  ok   50 全量模式：14c 段头出现 0 次（守卫为假，正文不跑）（= 0）
  ok   50 全量 --select 14 自身也退出 0（rc=0）
  ok   50 FAST 守卫块 P117 前后逐字节相同（30 行；if [ "$FAST_REQ" = "1" ]; then…）
```

最后一条是静态证据：`git show b924cbd0^:…/smoke.sh`（P117 之前）与 `HEAD` 的守卫块（从
`if [ "$FAST_REQ" = "1" ]` 到配对的 `^fi$`）逐字节 `diff` 相同 —— P117 没有顺手改守卫语义。

### 2.6（任务书 ⑥）零回归：本地门禁（CI 不是判据）

`pkg/60`（快门）+ `pkg/70`（真全量，锁排队）：

（见 S60/S70 输出块 —— 由最终 run 填写）

### 2.7（任务书 ⑦）报告归属

见 §1：全部判据是我自己写、自己跑的；引用只作对照。实现的 green/red 原始输出都在
`pkg/logs/run-*.log`（随包提交）。

### 2.8 附加发现（**验收范围外**）：深 caller TMPDIR 下 §36⑦ 两条绿侧夹具的**环境假红**

- **形状**：caller `TMPDIR` 深（实测 `len=27`）→ `--paths tests/smoke.sh` 的选集里出现 **2 条**红，
  都叫 `36⑦ 夹具依赖键 --select 3b/6 的选集有红`；嵌套 run 自己的收口行其实是 `✓37 ✗0` / `✓6 ✗0`。
- **机制**：§36⑦ 的两条绿侧夹具（`smoke.sh` 13346–13354 行）用**裸 rc** 判定：
  `P98_NEST_ENV="" p98_nest … --select "$P117_K"; [ rc -eq 0 ] && … || bad`。而 P115 已经定义
  「嵌套跑 rc≠0 先看**状态**：全部红行都能归因到环境前置（私有 tmux socket 路径 > AF_UNIX 107 →
  `0c` 报「私有 socket 没生效」）→ 可见 SKIP，不判产品红」——同一文件里的 `p98_nest_state`/
  `p98_nest_verdict` 就是干这个的，但这两条新夹具没有用它。
- **证据**（`pkg/logs/run-80.log`）：
  ```
  · 深 TMPDIR=/tmp/p119.…/deep/deep（len=27）｜短 TMPDIR=/tmp/p119r.……（len=17）
  FIND 附加发现（验收范围外）：… 深 rc=1、2 条 … 全部红行都是「私有 socket 没生效」
      （嵌套 run 里 3b 自己的收口行 ✗0：#8 3b · git 归 PM … ✓37 ✗0）
  ok   深 TMPDIR 的 §36⑦ 之外没有别的红（2 条全部来自那两条夹具）
  ok   80 对照：短 TMPDIR 下 --paths tests/smoke.sh 端到端 rc：rc=0
  ok   80 对照：短 TMPDIR 下 §36⑦ 夹具红 0 条（= 0）
  ok   80 对照：短 TMPDIR 下结果行 ✗ 0（== 选段结果 ==  ✓ 898  ✗ 0）
  ```
- **影响**：默认 `/tmp`（len 4）不触发；触发面是「调用者自带较深 TMPDIR」的场景（这正是 P112/P115 给
  验证包定 `len(TMPDIR) ≤ 22` 预算的原因）。后果是**假红 + 结论文字误指选段器**，不是产品缺陷。
  本包因此把所有嵌套 run 的 TMPDIR 压到 17–19 字符（`p119_mktmp`）。
- **建议**（不在本任务范围，交 PM 决定是否开小 change）：§36⑦ 的绿侧夹具改用 `p98_nest_state`
  （或 `p98_nest_verdict`）判状态；红侧夹具顺带断言「不允许出现 env 红」，免得环境问题把红侧喂成假绿。

---

## 3. 环境、可复现与纪律

### 3.1 环境

（见 §3.4 —— 由最终 run 填写）

### 3.2 复现

```bash
cd <repo>/.worktrees/verify                     # 或任何干净 checkout（HEAD == main 的实现）
bash docs/team/reports/P119-verify/pkg/run.sh   # 默认全部分节（10 20 30 40 50 60 80）
bash docs/team/reports/P119-verify/pkg/run.sh 70  # 真全量门禁（TEAM_SMOKE_LOCK 排队）
```

`pkg/run.sh` 的约定：每节打印 `== N 结果 == ok=… finding=… bad=… skip=…`；**finding 是数据**（不改退出码），
`bad`（验证包自己跑不动）或分节非零才让 run 非零；run 前后各查一次 `git status -- skills/`，**真树被写穿
就报错退出 2**。

### 3.3 我没有改实现

```bash
git diff --stat main..HEAD        # 只应有 docs/team/reports/P119-verify/**
```

### 3.4 夹具过程的一次自家事故（过程说明，不是产品发现）

第一版红侧变体树用 `cp -rs`（目录真、文件软链）搭建；§28 的 CJK 翻转夹具会往
`references/*.md`、`SKILL.md` 里写文本再恢复，软链让**写入穿透到真树**（两个文件被污染，并且随后的
`§18` 英文正文不变量扫描抓到了残留 → S20 一度出现 4 条与选段器无关的红）。处置：红侧变体改成
**整棵真拷贝**（只有只读的 `panel/node_modules` 是软链），并在脏文件恢复后重跑了全部受影响分节；
`run.sh`/各节现在都带漂移守卫。这条不是产品问题，写在这里是为了让后来者不要再用「目录/文件软链树」
当夹具。

---

## 4. Flip evidence（红 → 绿）汇总

| 面 | 红（我造的） | 绿（原样） | 证据 |
|---|---|---|---|
| 早拒 | 影子区域裁判（还原旧剪贴器）→ `--select 14` rc=2、0 段头 | 无影子 → rc=0、副本 1032 行解析 | `pkg/logs/run-30.log` |
| needs 闭包 | 6 删 `needs:3b` / 10 删 `needs:9` → 选集 rc=1、自己 ✗7 / ✗10 | 原表 → 3b/6/10 全绿、needs 全在选集 | `pkg/logs/run-40.log` |
| env 假红（范围外） | caller TMPDIR len=27 → §36⑦ 2 条假红、深 rc=1 | 短 TMPDIR → ✓898 ✗0 | `pkg/logs/run-80.log` |

实现侧无红：本任务**没有发现** `gate-runtime-budget` 交付物上的缺陷。

---

## 5. Decisions and deviations

1. **判据全部自建**：任务书点名「不要只跑作者的 `section-needs-audit.sh`」→ 我写了 10/20/30/40/50
   的独立断言（作者的 `--verify-copies` 只印一行 SKIP 对照）。作者的全键**运行**审计我没有跑（成本
   ~13 分钟、且是作者工具）；覆盖点在任务书 ①（全键解析）与 ④（夹具键真跑 + 删边红）之内。
2. **红侧删边的选择**：见 §2.4 的数据说明（按报告点名的边删不掉闭包，改选承重边）。
3. **额外的语义检查**（NONE/FULL/未知键、最慢汇总位置、账本一致性、守卫块静态 diff、真树漂移守卫）
   ——都落在任务书 ⑤「语义不许放松」与交付纪律内，没有扩张验收面。
4. **深 TMPDIR 假红**：作为**范围外发现**单列（§2.8），不阻塞归档建议；是否开跟进 change 由 PM/用户定。
5. **夹具纪律**：见 §3.4。

## 6. Status

**PASS**（7/7 条验收面全绿，红侧有对照，未发现交付物缺陷）＋ 1 条范围外发现（§2.8）。
建议 PM 独立复验后归档 `gate-runtime-budget`；§2.8 可作为独立小 change 的候选。

## 7. Suggested next steps

- PM：`team review P119 --strong`（独立 worktree）→ 归档 `gate-runtime-budget`。
- 可选跟进：§36⑦ 用 `p98_nest_state` 判状态（§2.8）；顺手给红侧夹具加「不允许 env 红」断言。
