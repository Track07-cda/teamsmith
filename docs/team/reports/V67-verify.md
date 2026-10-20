# V67 · 独立复核 P330：删掉的这批夹具真的都不可达吗

task: V67   status: delivered   time: 2026-10-20T06:30Z
branch: `task/V67-fixture-deletion-review`（本分支只放报告，只读复验）
tip: 受检 = `task/P330-unreachable-fixtures` @ `57c61214acbe622453320292ea993a14d3acfcc1`
（比对基线：`main` = `1bc7b174`，与这条分支的 merge-base 同；分支领先 12 个提交）

## 判定：PASS

四个判据各自成立，证据在 §2–§6：

- **不可达**：34 个被删文件里的每一个，我在受检 tip 树上用**整棵树**（减去四类历史面）扫它的
  文件名与去扩展名的词干，**没有一条可执行引用**；只剩 4 条散文/注释（§2）。
- **集合一致**：我自己数出的删除集与作者的清单**逐个同名、同行数**（34 个 `.sh` / 6 689 行 +
  `loop-inventory.tsv` 4 行）；差异只在**任务书自己的两个数字**（§7-a：任务书写 36 个 / 6 701 行、
  且说被删了两个 `tests/*.ts`——树枝上一个 `.ts` 都没被删）。
- **登记表对账一致**：删掉的行恰好是那 3 个文件 / 4 个循环，没有多删也没有少删（§5，含「把 34
  个全放回去」的实测反证）。
- **`--check` 与 `0e` 在受检 tip 上绿**：`ok 8 bad 0 SKIP 1`、`✓45 ✗0`（§4）。

三条与任务书措辞不符的偏离（§7）都已如实记；它们不使任何一个被删文件变成可执行，也不改变登记表
的配平，所以不构成任务书「判据」里的任何一条 FAIL。

## 一 · 受检集合（我自己数的，不抄报告）

```
$ git diff --no-renames --diff-filter=D --name-only main...task/P330-unreachable-fixtures | wc -l
34
$ git diff --no-renames --numstat main...task/P330-unreachable-fixtures \
    | awk '$1=="0" && $2>0' | wc -l          # 35 = 34 个整文件删除 + loop-inventory.tsv 的删行
35
```

- 整文件删除的：**34 个，全是 `skills/teamsmith/tests/*.sh`**；`--diff-filter=D` 里**没有任何
  `.ts` / `.tsx` / `.mjs` / `.py` / `.pl`**（`grep -v '\.sh$'` 无输出）。
- 行数：34 个文件的删除行合计 **6 689**；再加 `loop-inventory.tsv` 的 4 行 = 分支 diff 的 **6 693**
  删除行（`git diff --numstat` 求和）。
- 任务书写的「36 个文件 / 6 701 行 / 含 `tests/*.ts` 被删的两个」与树枝不符，见 §7-a。

## 二 · 重扫：谁引用这 34 个名字

扫描面 = **整棵树**（`git grep`，只排除任务书点名的四类历史面：`openspec/changes/archive/**`、
`docs/team/reports/**`、`docs/team/reviews/**`、`docs/team/tasks/**`），在受检 tip 的克隆里跑；
另有一轮按任务书最小面（`skills/teamsmith/{tests,scripts,extension}/**`、`ci/**`、
`.github/workflows/**`、`docs/team/tools/**`、`package.json`、`Makefile`(不存在)）复扫一遍，两轮一致。

```
$ while read -r rel; do b=$(basename "$rel"); \
    git grep -nF -- "$b" -- ':!openspec/changes/archive' ':!docs/team/reports' \
      ':!docs/team/reviews' ':!docs/team/tasks'; done < deleted.txt
flip-glue.sh                 0      flip-m12-26c.sh   0      flip-m12.sh   0
flip-m16.sh                  0      flip-m17.sh       1  ←  prose
flip-m34.sh                  0      flip-m37.sh       0      flip-m48.sh   0
flip-m6.2.sh                 0      flip-m6.3.sh      0      flip-m6.4.sh  0
flip-m6.5.sh                 0      flip-m7.1.sh      0      flip-p144.sh  0
flip-p156.sh                 0      flip-p160.sh      0      flip-p18.1.sh 0
flip-p20.sh                  0      flip-p201.sh      0      flip-p210.sh  0
flip-p211.sh                 0      flip-p217.sh      0      flip-p22.sh   0
flip-p23.sh                  0      flip-p287-name.sh 0      flip-p304-read-side.sh 0
flip-p308-skip-not-pass.sh   2  ←  comment
flip-p309-p162-deep.sh       0      panel-flip-m54.sh 1  ←  comment
panel-flip-p123.sh           0      panel-flip-p125.sh 0     panel-flip-p128.sh 0
team-bg-flip.sh              0      team-inbox-watch-flip.sh 0
```

（上面的计数表按列压缩排列，每个文件的命中数与命中原文未改。）

四条命中，逐条看过的原文（**都不是调用**）：

```
docs/team/DECISIONS.md:612:   （`TMUX_TMPDIR` ✓ 或 `tmux -L "$SOCK"` ✓）；`flip-m17.sh`/`flip-m45.sh` 虽不含 …
skills/teamsmith/tests/tmux-identity-leak.sh:64:#   bash skills/teamsmith/tests/flip-p308-skip-not-pass.sh
skills/teamsmith/tests/tmux-identity-leak.sh:764:# >>> P308 close-out predicate（flip-p308-skip-not-pass.sh 按这两个标记把它换回旧判据）>>>
skills/teamsmith/tests/smoke.sh:18497:# panel-flip-m54.sh 的 W-A（断掉无读取 → choices 变红）。
```

前两条 `tmux-identity-leak.sh` 与 `smoke.sh:18497` 都是整行 `#` 注释；`DECISIONS.md:612` 是决策记录里
的散文。删掉夹具后这四句成了**悬空指针**，但它们既不是调用点、也不是断言。

再去掉扩展名扫词干（防「不带 `.sh` 的引用」），只剩三句注释散文，无调用：

```
flip-m12-26c  → smoke.sh:25（注释：sed 依赖 ^SKILL_DIR= 的形状）
flip-m12      → smoke.sh:25（同）
flip-m17      → flip-m45.sh:18（注释：隔离纪律同源）
team-bg-flip  → bg-ledger.sh:79（注释：TS 运行时的选择顺序一致）
```

**变量拼接与通配面**（任务书点名的五种形状）：全部命中都不是「能拼出这 34 个名字」的那种。

| 形状 | 命中 | 判定 |
|---|---|---|
| `for f in tests/flip-*` / `tests/$var` / `$TESTS/` / `"$D"/flip-` | 无 | 没有一处按变量拼夹具名 |
| `cp "$SKILL_DIR"/tests/*.sh …` | `smoke.sh:1697`（§0e 自己的拷贝面） | 整目录拷贝：删文件只是少拷一份，不报错；配平由 `--loop-check` 判 |
| `for x in "$SKILL_DIR"/tests/*; do ln -s …` | `smoke.sh:17752`、`smoke.sh:19017`、`flip-p158.sh:110` | 变体树把 `tests/` 整体链接过去，无「文件数」断言 |
| `basename` | `bg-ledger.sh`、`delivery-truth.sh`、`flip-p158.sh` 等 | 作用于临时根/outbox 文件名，与夹具名无关 |
| `ls tests` / `eval …tests/…` | 无 | — |
| `source`/`.` 一个变量路径 | 全部命中都是字面 `lib/*.sh`、`scripts/lib/*.sh` | 不含这 34 个名字 |

## 三 · 动态入口：没有任何收集规则会捡起它们

- `package.json` 的 `scripts` 只有三条，全指向门禁本体：
  `"test": "TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh"`、`"test:full": "bash … smoke.sh"`、
  `"gates": "openspec validate --all --strict && bash … smoke.sh"`。
- 仓库里**没有** `*.test.*` 文件（`find . -name '*.test.*'` 无输出），**没有** `vitest / jest / mocha /
  pytest / node --test / bun test` 的收集面（`bun test` 只作为产品里给**别的项目**生成的 `TEAM_GATES`
  字符串出现，`cmd-project.sh:48/52`，与本站夹具无关）。
- CI 面只有两处 `bash -c` 串 + 镜像 CMD，都不点名夹具：
  ```
  ci/Containerfile:148: CMD ["bash","-c","openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null"]
  .github/workflows/gates.yml:98:  bash -c 'mkdir -p "$TMPDIR" && openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh --keep </dev/null'
  .github/workflows/gates.yml:151: bash -c 'bash skills/teamsmith/tests/perf.sh --in-container --tree /work'
  ```
  `ci/collect-scene.sh` 收的是临时根里的「现场族」，不读 `tests/`。
- `coverage-inventory.sh` 读的是 `smoke.sh` 的断言标签（不是 `tests/` 目录清单）；`section-guard.sh
  --loop-check` 读 `tests/*.sh` + `tests/lib/*.sh` 的循环面 —— 这两条都由 §0e 跑，见 §4。

## 四 · 门禁自检（独立检出 / 磁盘临时根 / 私有锁）

独立克隆 `git clone --no-hardlinks "$SRC"` → `git checkout --detach origin/task/P330-unreachable-fixtures`
（克隆在 `/var/tmp/v67/g0`，`TMPDIR=/var/tmp/v67/tmp-g0`，
`TEAM_SMOKE_LOCK=/var/tmp/v67/lock-g0.lock`；我的席位工作树全程 `git status --short` 为空）。

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（135 行）
ok: 段 ↔ 行一一对应（源码 135 段 / 表 135 行）
ok: needs 声明全部存在且指向更早的段（108 条）
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal…）：.pi/skills
ok: 字面模式（640 条）里 639 条在位；1 条检出前提按缺失跳过（跳过不等于检查过）
ok: 豁免类（docs/*）没有任何行声明
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（528 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1                     # rc=0

$ TMPDIR=… TEAM_SMOKE_LOCK=… bash skills/teamsmith/tests/smoke.sh --select 0e
  ✓ P70 循环清单：干净树绿（85 行清单 / 85 个 while+sleep 循环，配平 85 个）
  …
== 选段结果 ==  ✓ 45  ✗ 0                              # rc=0，§0e 自身 ✓22 ✗0，用时 50s
账本自查： 5 段收口 · 增量 ✓45 ✗0 SKIP0 ｜ 结果行 ✓45 ✗0 —— 一致
```

运行指纹（P158）：开跑 `head=57c61214 dirty=0`，收尾 `dirty=0` —— 本次运行有效（没有「跑动中树被
改」）。三次门禁运行（§4、§6 的 g2/g1）都在各自的克隆里，**我的席位工作树一个字节没动**。

## 五 · 登记表对账：删掉的行恰好属于被删文件

```
$ git diff main...task/P330-unreachable-fixtures -- skills/teamsmith/tests/loop-inventory.tsv
-flip-m37.sh	120	cap="$m37_i" -lt 50	 while [ "$m37_i" -lt 50 ] && { … }; do
-flip-p217.sh	169	cap="$i" -lt 3000	   while [ "$i" -lt 3000 ]; do
-flip-p210.sh	133	cap="$p210_i" -lt 50	 while [ "$p210_i" -lt 50 ] && [ "$(tmux list-panes …)" != "1" ]; do
-flip-p210.sh	138	cap="$p210_j" -lt 20	 while [ "$p210_j" -lt 20 ]; do
4 deletions, 0 insertions
```

反向证明（我自己造，不是抄）：把 34 个被删文件**全部**从父提交放回扫描面再跑 `--loop-check`：

```
bad: flip-m37.sh 的 while+sleep 循环数 1 ≠ 清单行数 0（…）
bad: flip-m37.sh:120 是未登记的 while+sleep 循环：while [ "$m37_i" -lt 50 ] && { … }; do
bad: flip-p210.sh 的 while+sleep 循环数 2 ≠ 清单行数 0（…）
bad: flip-p210.sh:133 / :138 是未登记的 while+sleep 循环：…
bad: flip-p217.sh 的 while+sleep 循环数 1 ≠ 清单行数 0（…）
bad: flip-p217.sh:169 是未登记的 while+sleep 循环：…
ok: 扫描 85 行清单 / 89 个 while+sleep 循环，配平 85 个
section-guard --loop-check: 1 条不成立                     # rc=1
```

结论：这 34 个文件里**只有那 3 个带登记过的 `while+sleep` 循环（共 4 个）**，删的 4 行正好是它们；
其余 31 个本来就没有循环行可删。**没有多删一行（不会让活着的循环失去登记），也没有少删一行。**

## 六 · 四条红侧（每条都是「造出来 → 看反应 → 丢弃副本」，我的工作树未动）

### R1 · 被删文件「还活着」时，今天会不会被发现

在克隆 g1 里把 `flip-m34.sh` 从父提交放回，并**接进 §6b 的段正文**（`bash "$SKILL_DIR/tests/flip-m34.sh"`）：

```
#### --check
bad: 段 6b 读了它没声明的路径：token skills/teamsmith/tests/flip-m34.sh（源码行 3014）—— 补进该行的 patterns
== 选段自检 ==  ok 7  bad 1  SKIP 1                         # rc=1
#### --loop-check（§0e 承载的那条断言）
ok: 扫描 85 行清单 / 85 个 while+sleep 循环，配平 85 个       # rc=0（flip-m34 没有循环）
#### --select 0e
== 选段结果 ==  ✓ 45  ✗ 0                                  # rc=0 —— 门禁段没看见它
```

如实记：**接线是被 `--check` 抓住的（段读了没声明的路径 → 点名文件与行号），不是被 `0e` 抓住的**；
`0e` 在这里干净，因为 `flip-m34.sh` 没有 `while+sleep`。若放回的是带循环的那三个之一，`0e` 会红并
点名（见 §5 那轮 `--loop-check` 输出）。所以「今天会不会被发现」的答案是：**会，但抓它的是选段
自检的路径声明规则，不是循环清单**；两者合起来覆盖了「接进段」与「放回扫描面」两种复活方式。

### R2 · 删掉一行仍存在文件的登记 → `0e` 必须红并点名

克隆 g2 里把 `flip-p171.sh` 的登记行删掉（文件仍在），跑真门禁：

```
$ sed -i -E '/^flip-p171\.sh\t/d' skills/teamsmith/tests/loop-inventory.tsv   # rows 85 → 84
  ✗ P70 循环清单：干净树绿（84 行清单 / 85 个 while+sleep 循环，配平 84 个）（期望 [0]，实际 [1]）
  ✗ P70 翻转（循环）还原：绿（期望 [0]，实际 [1]）
  ✗ P313 翻转（盲区）还原：绿（期望 [0]，实际 [1]）
== 选段结果 ==  ✓ 42  ✗ 3                                  # rc=1
```

**红成立，但点名不成立**：`0e` 的断言标签只打计数（「84 行清单 / 85 个循环」），**没有出现
`flip-p171.sh` 这个名字**。名字只出现在段内那份 `$TMP/p70-loop-green.log` 里（我在同一棵树上直接跑
`section-guard.sh --loop-check` 才能看到）：

```
bad: flip-p171.sh 的 while+sleep 循环数 1 ≠ 清单行数 0（新循环/漏登记/顺序变化都要点名并补清单）
bad: flip-p171.sh:108 是未登记的 while+sleep 循环：    while [ "$i" -lt 3000 ]; do
```

而那次失败运行的临时根**已被删掉**（`--select 0e` 默认不留现场；宿主根 `/var/tmp/v67/tmp-g2/` 下只剩
私有 tmux socket 目录）。即：**要拿到「是哪个文件」，必须用 `--keep` 重跑一次。** 见 §7-b。

### R3 · `section-needs-audit.sh`（本批保留）改名 → 有没有段/`--check` 变红

```
$ mv skills/teamsmith/tests/section-needs-audit.sh …​.v67bak
== 选段自检 ==  ok 8  bad 0  SKIP 1                         # --check rc=0
section-guard --loop-check: 全过                            # rc=0
$ grep -rn 'bash .*section-needs-audit' skills/teamsmith ci docs/team/tools   # 无输出
```

**没有一处因为它改名变红，也没有任何段执行它。** 它今天只被两类东西点名（都是文字）：
`section-paths.tsv` 的 basis 列（几十行「口径见 tests/section-needs-audit.sh」）与 `smoke.sh:18106`
的一句注释（「全键逐键审计是 …，验收时整跑」）。也就是说：保留它的理由是**映射表的依据与验收程序**，
不是门禁在执行它 —— 删掉它不会让任何绿灯变红。

### R4 · `flip-p171.sh`（本批保留）改名 → `signal-gate.sh` 的注释是否变成假话

```
$ mv skills/teamsmith/tests/flip-p171.sh …​.v67bak
== 选段自检 ==  ok 8  bad 0  SKIP 1                         # --check rc=0
bad: 清单里的 flip-p171.sh 不在扫描面（文件被删 / 没被拷进 --tree / 已经没有 while+sleep 循环）—— 过期行…
ok: 扫描 85 行清单 / 84 个 while+sleep 循环，配平 84 个
section-guard --loop-check: 1 条不成立                       # rc=1
```

如实记：`--check` 不红，但 `--loop-check`（即 `0e`）**必红**——登记行会立刻变成「过期行」。另有
`signal-gate.sh:25 / :85 / :499` 三句注释写着「完整矩阵在 tests/flip-p171.sh」，改名后这三句是
**假指针**；它们是注释，不是断言，所以没有任何段因此变红。**保留它是有东西依赖的（清单 + 三句指针），
与 R3 的 `section-needs-audit.sh` 恰好相反。**

## 七 · 三处不一致（逐条：它改变了什么）

**a) 任务书的计数与树枝不符。** 任务书抬头写「36 个夹具 / 6 701 行」「含 `tests/*.ts` 被删的两个」，
树枝实测 **34 个 `.sh` / 6 689 行 + 4 行清单**，`.ts` 一个都没删。作者报告的 34 / 6 689 / 4 行与
树枝一致（6 689 + 6 693（剩余不可达）= 13 382，与它的扫描总数自洽）。改变的是**验收基线**：这轮
只能按「我自己数出的 34 个」逐条验；若是按 36 个去核，会去找两个不存在的文件。

**b) `0e` 会红但不点名（R2）。** 改变的是**门禁红侧的可读性**：删掉一行登记时，跑 `--select 0e` 的人
看到的只有「84 行 / 85 个循环」这个计数差，名字在段内日志里、而日志随临时根被删。这条不影响本次
删除的判定（它测的是守卫的报错质量），但它是「门禁红了下一步该改哪一行」的成本来源——P70 的断言标签
只调 `assert_eq "…（$(sed -n 's/^ok: 扫描 \(.*\)$/\1/p' …)"`，没把 `bad:` 行带进标签。

**c) 作者的删后零引用表比它的扫描面窄。** 报告 §2 的那张表用的是
`git grep -cF -- "<basename>" -- ':!docs' ':!openspec'`——把 `docs/` 和 `openspec/` 整个排除，
于是漏了 `docs/team/DECISIONS.md:612`（散文点名 `flip-m17.sh`）与 `openspec/specs/**` 面；它的
可达性根集里其实**包含** `docs/team/tools/**`。我的面只排任务书点名的四类历史面，多出这一条散文。
改变的是**证据的覆盖面**（不是结论：散文不是调用）；也说明「作者那张 0 命中表」对 `docs/team/tools/**`
这一面没有提供证据。

## 八 · 这批删除之后失去的能力（一句我自己的话）

删掉之后，**「把一个修复再退回历史 revision 去重放一次」这条通道没有了**：门禁今天仍能对**当前**实现
做破坏-还原并变红，但「当年那条断言在修复前确实会红」从此只能靠重新写一个包或手工 checkout 旧提交，
书面证据只剩任务报告与归档变更。

## 验收命令（都在本席位的独立检出/克隆里真跑）

```
# 集合与扫描（受检 tip 的克隆 /var/tmp/v67/g0）
git diff --no-renames --diff-filter=D --name-only main...task/P330-unreachable-fixtures
git diff --no-renames --numstat main...task/P330-unreachable-fixtures
git grep -nF -- <basename> -- ':!openspec/changes/archive' ':!docs/team/reports' ':!docs/team/reviews' ':!docs/team/tasks'   # ×34
# 门禁（独立克隆 + 磁盘根 + 私有锁）
bash skills/teamsmith/tests/section-select.sh --check                     # rc=0  ok 8 bad 0 SKIP 1
TMPDIR=… TEAM_SMOKE_LOCK=… bash skills/teamsmith/tests/smoke.sh --select 0e   # rc=0  ✓45 ✗0
# 红侧（各自一个克隆，跑完丢弃）
TMPDIR=… TEAM_SMOKE_LOCK=… bash skills/teamsmith/tests/smoke.sh --select 0e   # g2: rc=1 ✓42 ✗3
bash skills/teamsmith/tests/section-select.sh --check                     # g1: rc=1 ok 7 bad 1
TMPDIR=… TEAM_SMOKE_LOCK=… bash skills/teamsmith/tests/smoke.sh --select 0e   # g1: rc=0 ✓45 ✗0
bash skills/teamsmith/tests/section-guard.sh --loop-check                 # 还原/改名三例的逐条判定
$ git status --short              # 本席位工作树：空
```

## 边界

- 没跑整套门禁、没跑容器、没跑计时套件（任务书边界）。
- 只读作者树：受检的是一份**克隆**（`git clone --no-hardlinks` + `--detach`），没有在
  `.worktrees/` 里跑门禁，也没有写主树；我自己的分支上只多这一个报告文件。
- 临时根与克隆全在 `/var/tmp/v67/`（自己的运行自己的路径），跑完按需清理，不动别的席位的根。
