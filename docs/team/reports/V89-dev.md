# V89 · P354 的独立验收：删掉的 13 个真的一个都跑不到吗

agent: dev　phase: verify　change: -　deltas: -　category: verify
anchor: none (infra) — 夹具处置
specs: `verification#The gate judges behaviour only, and never reports a skip as a pass`
受检：`0256880c`（相对 merge-base `2011d094`：18 文件、+258/−2792）　报告：`docs/team/reports/P354-dev3.md`
branch: `task/V89-dead-fixture-disposal-verify`（local 模式，未推）　time: 2026-10-21T06:50Z

## 结论（先看这一段）

**PASS。** 判据是「只要有一个被删文件今天仍能被执行到，就是 FAIL」——13 个名字里**没有一个**有执行路径，不是靠作者的表，是我在候选树上重扫出来的。

- **可达性（§1）**：13 个名字的命中只剩三类——历史账本（`docs/`、`openspec/changes/archive/`）、三处代码注释（`smoke.sh` 8 行 / `extension/team-inbox-watch.ts` 2 行 / `signal-gate.sh` 3 行）、以及两个孤儿文件里的自述用法。执行面（`smoke.sh` 段正文、`.github/workflows/gates.yml`、任何 `.sh`/`.mjs`/`package.json` 的调用链）**零命中**；唯一像「拼名字」的地方是 `slash-team.sh:546` 的 `join(TMP, \`flip-${m.name}\`)`，它的 7 个 `m.name` 是变异名（`menu-decoupled` 等），与这 13 个无关。
- **墓碑表（§2）**：13 行的「删在哪个提交」**13/13 与 git 对得上**（`78e5389b` 7 个 / `c2b89dcc` 3 个 / `c8ebf4c4` 3 个）；「今天谁守」那一列**静态 13/13 成立**（段号存在且正文确有它点名的断言/探针），其中 **7 行的守卫我实跑看到绿**（§11i / §12b-h0b / §12b-pi / §47 四次选段，共 5 条被删夹具对应 4 个段）。
- **没多删没少删（§3）**：`git diff 2011d094 0256880c` 的删除**恰好 13 个**、全部在 `skills/teamsmith/tests/`；`tests/*.sh` **64 → 51**、行数 **59596 → 56814**，与报告逐字相同；`panel-b3.sh`、五个保留项、`smoke.sh`、`section-paths.tsv`、`section-select.sh` 相对基线**blob 完全相同**（9/9）。
- **自检没被删坏（§4）**：`--check` `ok 9 bad 0 SKIP 1` rc=0、`--loop-check` **82/82** rc=0、保留夹具 `bash -n` **67 + 3** 个 0 失败、`--select 40` **✓65 ✗0** rc=0（182 s）——四条读数与作者报告**逐条相同**。
- **残留指针（§5）**：作者自报的「`smoke.sh` 8 行 + `extension/team-inbox-watch.ts` 2 行」**事实成立，行号一个不差**。我的判断：10 行里 **9 行是必须改的假指针**（其中 `smoke.sh:12365` 不只是死指针——它写着「真进程部分由 `tests/panel-keyprobe.sh` 覆盖」，与 `tests/README.md` 新写的缺口**互相矛盾**），第 10 行（`team-inbox-watch.ts:599`）只是过时的变异名、它守的行为仍被 `§12b-pi` S18–S21 活着守着。这些都是注释、**没有一行是执行点**，所以不影响本判据的 PASS，但它们是 PM 该收的尾。

**执行面的差异只有一处，且不指向删除本身**：任务书表头写「19 个文件、`+259/−2793`」，实测（相对 `2011d094`）是 **18 个文件、`+258/−2792`**（相对 `2011d094^` 是 20 文件 `+264/−2794`、相对当前 `main` `7934af89` 是 35 文件——因为 main 之后又落了面板与 0.3.1 的提交）。三个候选基线都对不上「19/+259」，我按「删除集合 + 删后读数」判，两条都成立，见 §3。

## 1 · 自己重扫可达性（不抄它的表）

树：`/var/tmp/v89-cand`（本仓 `git clone` 后 `git checkout 0256880c`，私有副本，源树只读）。名字清单：`flip-m4.3 flip-m43 flip-m45 flip-m46 flip-m7.2 flip-p171 flip-p25 flip-p287-lock flip-p71 flip-p72 panel-flip-m54 panel-keyprobe-stub panel-keyprobe`。

**① 全树直扫 + 按文件归并**（看命中落在哪一类文件）：

```
$ for n in $NAMES; do grep -rn --binary-files=without-match -F "$n" --exclude-dir=.git . ; done | cut -d: -f1 | sort | uniq -c
   （逐名命中相加 612 处）绝大部分在 docs/team/{reviews,reports,tasks,threads,DECISIONS.md} 与 openspec/changes/archive/…
   8 skills/teamsmith/tests/smoke.sh
   3 skills/teamsmith/tests/signal-gate.sh
   2 skills/teamsmith/extension/team-inbox-watch.ts
   1 skills/teamsmith/tests/README.md
   1 skills/teamsmith/tests/panel-keyprobe.tsx       ← 文件自己写的 Usage 行
   1 skills/teamsmith/tests/panel-keyprobe-pty.py    ← 同上
```

代码面一共 16 处（8+3+2+1+1+1），全部是注释或自述用法。

**② 执行面窄扫（去掉 docs/openspec，只留可执行扩展，并去掉已知的两处注释文件）**——为了抓「变量拼接」我还单独扫了词干：

```
$ for s in m4.3 m43 m45 m46 m7.2 p171 m54 keyprobe p287; do grep -rn -F "$s" --include='*.sh' --include='*.mjs' \
    --include='*.ts' --include='*.tsx' --include='*.py' --include='*.yml' --exclude-dir=docs --exclude-dir=openspec \
    --exclude-dir=.git . ; done | grep -vE '^\./skills/teamsmith/tests/(smoke\.sh|signal-gate\.sh):'
./skills/teamsmith/tests/team-inbox-watch-harness.mjs:547  appendWake('knock','dev','pm', `m43-replay-line-${n}`)   ← 用例数据标签，不是文件
./skills/teamsmith/tests/team-inbox-watch-harness.mjs:585  `m43-pad-${'P'.repeat(240)}`                             ← 同上
./skills/teamsmith/tests/pm-box-real.sh:246/340            m45-idle.log（自己的日志名）                            ← 同上
./skills/teamsmith/extension/team-inbox-watch.ts:452       flip-m46 …（注释，见 §5）
./skills/teamsmith/tests/panel-keyprobe{,-pty}.{tsx,py}     自己的 Usage 行（孤儿，见 §2 表末）
```

**③ 通配/动态调用面**（这是「删了也可能仍被跑到」的唯一现实形状）：

```
$ grep -rn -E 'tests/[^ ]*\*|flip-\*|panel-\*|\*\.sh' --include='*.sh' --include='*.mjs' --include='*.ts' \
    --include='*.py' --include='*.yml' --include='*.json' . | grep -v '^\./skills/teamsmith/tests/smoke\.sh:.*#'
./skills/teamsmith/tests/smoke.sh:1778         cp "$SKILL_DIR"/tests/*.sh …      ← §0e 把夹具**拷**进 scratch 树做循环清单比对
./skills/teamsmith/tests/smoke.sh:1565/1805     "$SKILL_DIR"/scripts/lib/*.sh    ← 库，不是夹具
./skills/teamsmith/tests/section-guard.sh:44   for f in "$TREE"/*.sh …          ← `--loop-check` 扫全部夹具
./skills/teamsmith/tests/flip-p158.sh:110      ln -s "$SKILL_DIR"/tests/* …     ← 建变体树时逐个软链
./skills/teamsmith/tests/slash-team.sh:546     join(TMP, `flip-${m.name}`)      ← 变异 scratch 目录
```

前四处是**集合遍历**：文件不在集合里就不参与，删掉只会让扫描面变小（也是 `--loop-check` 从 86 变 82 的原因），不会「跑一个不存在的文件」。第五处的 `${m.name}` 取值是 `slash-team.sh:470–518` 的七个变异名（`menu-decoupled` `unset-empty` `refuse-short-circuit` `no-failure-notify` `entry-to-notify` `no-fuse` `table-frobnicate`），没有一个与被删文件同名。

**④ 两条静态清单**（作者说 `--check` 靠「不存在的路径跳过」，我核了清单本身）：

```
$ grep -nE "flip-m4\.3|…|panel-keyprobe" skills/teamsmith/tests/loop-inventory.tsv   → rc=1（零行）
$ grep -nE "flip-m4\.3|…|panel-keyprobe" skills/teamsmith/tests/section-paths.tsv    → rc=1（零行）
```

**⑤ CI**：`.github/workflows/gates.yml` 里没有任何夹具名（只调 `smoke.sh` / `perf.sh` / `ci/collect-scene.sh`，行 123/129/146/183）；`docs/team/tools/release-check.sh:376` 也只调 `smoke.sh`。

**一句话结论**：**13 个被删文件在当前候选树上没有任何执行路径**——凡是还在提它们的地方都是注释或历史账本；唯一「按名字找文件」的机制（§0e 循环清单、`--check` 的 token 表）里，13 个名字一个都不在。

## 2 · 墓碑表核对（13 行逐个，4 段实跑）

**「删在哪个提交」13/13 与 git 一致**：

```
$ for f in <13>; do git log --diff-filter=D --format='%h' -- "skills/teamsmith/tests/$f.sh" | head -1; done
flip-m4.3 flip-m43 flip-m45 flip-m46 flip-m7.2 flip-p25 flip-p71 → 78e5389b      （7 个，与表同）
flip-p171 flip-p287-lock flip-p72                                → c2b89dcc      （3 个，与表同）
panel-flip-m54 panel-keyprobe panel-keyprobe-stub                → c8ebf4c4      （3 个，与表同）
```

**「今天谁守」那一列**：13 行点名的段号在 `--list` 里都存在且标题对得上，正文确有它点名的断言。实跑的四段（`TEAM_SMOKE_FAST=1`，私有副本，log 在 `/var/tmp/v89-logs/`）：

| 实跑的段 | 结果 | 对应墓碑行 |
|---|---|---|
| `--select 11i` | 段 **✓15 ✗0 SKIP0**（12 s），整体 **✓76 ✗0** rc=0 | `flip-m4.3`（M4.3 C/D） |
| `--select 12b-h0b` | 段 **✓20 ✗0 SKIP0**（0 s），整体 **✓43 ✗0** rc=0 | `flip-m45`（M45 横幅判据） |
| `--select 12b-pi` | 段 **✓103 ✗0 SKIP0**（82 s），整体 **✓389 ✗0 SKIP3** rc=0 | `flip-m43`（S11–S13）· `flip-p25`（S18–S21）· `flip-m46`（M46-S14…S17）· `flip-p71`（S25a–e） |
| `--select 47` | 段 **✓80 ✗0 SKIP0**（4 s），整体 **✓103 ✗0** rc=0 | `flip-p72`（notify 发送者 = 运行时目录） |

段内确证的断言（不是「段绿了就算」）：`11i` 有 15 条 M4.3 C/D 断言（`report 未提交：先等 agent 交付` / `草稿不指向复验` / `squash 合并后被认出来（内容一致）` / `不再暗示要 push`）；`12b-h0b` 的 20 条是 `geometry=[24 29]`、`banner_rows=[11 …]`、以及**其中一条红腿**（破坏实现后几何退回横幅上界 11）；`12b-pi` 里 S11–S13（M43 重放保真）、S18–S21（P28 字节真值）、M46-S14…S17（跳过留痕/继承 TEAM_STATE_DIR 拒绝）、S25a–e（写前日志/至多一次）逐条 `✓`；`47` 的 80 条里 `发送者 = 工作树目录名（不是收件人 pm）`、`主工作树 → pm`。

`12b-pi` 整体那 **SKIP3 不在本段**：`#9 6`（dispatch 真拉起）、`#10 6i`（非 Pi PM 端到端）、`#11 12b-e`（巡检一拍排水）在 FAST 下可见跳过；`#12 12b-pi` 自己是 `SKIP0`。本段监视扩展**真跑了**（`runner=$HOME/.bun/bin/bun，214 条用例`），所以 S11–S13/S18–S21 不是「不可用前提跳过」拿到的绿。

**静态核过、但没实跑的四行**（说明边界，不当结论用）：`flip-m7.2 → §11b3`、`flip-p287-lock → §34d` 都在 FAST 下 `fast_skip`（要真 tmux/真锁/嵌套运行），`flip-p171 → §58` 的 watch-shape 正向对照在 `signal-gate.sh:517–560`（三条形状正/负腿 + 内容哈希 + 软链腿），`panel-flip-m54 → §38/§26`（`§38-a` 跑 `panel-choices.sh`，其中确有 F-A/F-D 两条翻转；`38-d` 是 W-A 的静态钉；bundle 逐字节由 §26 的 `cmp -s … panel.js` 比）。

**一处需要读者知道的边界**：`panel-flip-m54` 那行点的是「留下来的守卫」，但 M55 的五条翻转里 **F-B / F-C / W-B / A2-enum 今天没有活翻转**（`panel-choices.sh` 只有 F-A 与 F-D）；表里用「F-A/F-D 仍在段内」隐含了这件事，读者不细看会以为五条都在。这不是删除的错误（作者按裁定只删文件），是那一行的措辞留给下一轮的活。

## 3 · 没多删、没少删

```
$ git diff --name-status 2011d094 0256880c | grep -c '^D'          → 13
$ git diff --name-status 2011d094 0256880c | grep '^D'             → 恰好那 13 个 tests/ 下的文件，无一条在别处
$ git ls-tree -r --name-only 2011d094 -- skills/teamsmith/tests | grep -c '^skills/teamsmith/tests/[^/]*\.sh$'  → 64
$ git ls-tree -r --name-only 0256880c -- skills/teamsmith/tests | grep -c '^skills/teamsmith/tests/[^/]*\.sh$'  → 51
$ 基线逐 blob 累加行数 → 59596 ；候选 wc -l → 56814              （报告：59596 → 56814，相同）
```

逐字节未变（blob 相同，9/9）：

```
same  panel-b3.sh                    27775467e6c8c7d7417366455c409e51be071c86
same  flip-m33.sh / flip-m44.sh / flip-p308-skip-not-pass.sh / section-needs-audit.sh / lib/tmp-root.sh   （五个保留项）
same  smoke.sh  efed6bc9…   section-paths.tsv  e05f566f…   section-select.sh  cff25e30…
```

`loop-inventory.tsv` 的 4 行退役也对得上（`-flip-m4.3.sh:94` / `-flip-m7.2.sh:198` / `-flip-m7.2.sh:225` / `-flip-p171.sh:108`，数据行 86 → 82）——这是作者自报的「多改一处」，它属于 `tests/`、且不改就是一棵红树（§0e 判「清单里的文件不在扫描面」），我认为该改。

**表头数字的差异（不影响判据）**：任务书写 19 文件 `+259/−2793`，实测 18 文件 `+258/−2792`。我试了三个基线：`2011d094`（=merge-base）18、`2011d094^` 20、`main` 35，都对不上 19；删除集合与删后读数与报告一致，所以我不把它当缺陷。

**合并安全性顺带核了一条**：候选触及的 18 个文件与 main 自 `2011d094` 之后改过的 17 个文件**交集为空**（`comm -12` 空输出），所以 PM 用 squash 落地时不可能把 `panel-b3.sh`（b99d7fff）或 0.3.1 的发布改动抹掉。

## 4 · 自检没被删坏（四条读数与作者报告逐条相同）

```
$ bash skills/teamsmith/tests/section-select.sh --check
ok: 映射表 key 唯一（135 行） / 段 ↔ 行一一对应（135/135） / needs 108 条 / 字面模式 643+1 SKIP
ok: 段正文点名的真实路径 token 都被各自的行覆盖（535 个 token 检查过；0 个豁免类）
== 选段自检 ==  ok 9  bad 0  SKIP 1                     rc=0

$ bash skills/teamsmith/tests/section-guard.sh --loop-check
ok: 扫描 82 行清单 / 82 个 while+sleep 循环，配平 82 个
section-guard --loop-check: 全过                        rc=0

$ n=0; for f in skills/teamsmith/tests/*.sh skills/teamsmith/tests/lib/*.sh; do bash -n "$f" || echo FAIL; done
checked=67 failures=0        （51 顶层 + 16 lib）；fixtures checked=3 failures=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 40
账本自查： 5 段收口 · 增量 ✓65 ✗0 SKIP0 ｜ 结果行 ✓65 ✗0 —— 一致
== 选段结果 ==  ✓ 65  ✗ 0                              rc=0，182 s（作者读数 244 s，计数相同）
```

## 5 · 残留指针：事实成立，判断是「必须改」，但都不在判据里

事实（`0256880c` 上逐行核，与作者自报一一对应）：

| 位置 | 原文（截断） | 类 |
|---|---|---|
| `smoke.sh:6095` | `# 根因（逐拍采样见 tests/flip-m7.2.sh）…` | 死证据指针 |
| `smoke.sh:6135` | `…（真实路径的窗口见 tests/flip-m7.2.sh）` | 死证据指针 |
| `smoke.sh:9295` | `# 翻转证据见 tests/flip-m46.sh）` | 死证据指针 |
| `smoke.sh:9306` | `…（harness S18–S21；翻转见 tests/flip-p25.sh）` | 死证据指针 |
| `smoke.sh:9330` | `# 翻转证据见 tests/flip-p71.sh）…` | 死证据指针 |
| `smoke.sh:9385` | `# M43：…（harness S11–S13；翻转证据见 tests/flip-m43.sh）` | 死证据指针 |
| `smoke.sh:12365` | `#      tests/panel-keyprobe.sh 与性能套件里的面板测量（报告里贴日志），smoke 只钉可判定的。` | **假覆盖声明** |
| `smoke.sh:18892` | `# panel-flip-m54.sh 的 W-A（断掉无读取 → choices 变红）。` | 死红侧指针 |
| `extension/team-inbox-watch.ts:452` | `// 变量名故意不叫 dir：flip-m46 包用 \`}): void {\n  const dir = watchDir(root)\` 当 writeSkipRecord 的注射锚点，` | 过时不变量 |
| `extension/team-inbox-watch.ts:599` | `// P28/B1：字节真值（flip-p25.sh 的 mutant A/B 把这一行换成解码→再编码的长度）` | 过时变异名 |

判断（逐条给了理由，不是一刀切）：

- **6 条「翻转证据见 tests/flip-X.sh」**（6095/6135/9295/9306/9330/9385）：**必须改**。它们不是叙述，是**指路**：段内唯一告诉后人「这条断言的红侧在哪儿被证过」的地方，跟着走会 404。改法只有一处文字（改成 `docs/team/reports/<TASK>-dev.md`，或删掉半句），不动断言——M43/M46/P25/P71/M7.2 的报告都在树里（`M43-dev.md` `M46-dev3.md` `P25-dev2.md` P71/P89 `M7.2-dev2.md`），指向是真的。
- **`smoke.sh:12365`（§27 段头）：必须改，而且它比死指针严重**。它写着「真进程部分（按键失真、60s CPU）是 `tests/panel-keyprobe.sh` 与性能套件里的面板测量」——文件删了以后这句话变成**假覆盖声明**，而同一棵树的 `tests/README.md`「已知缺口」正写着「这条契约今天没有活守门人」。同一份交付里两处互相矛盾的判断，后到的读者会信段头那条。
- **`smoke.sh:18892`（§38/38-d）**：必须改。`38-d` 的静态钉还在、还真跑，但它自称的红侧（W-A：断掉无读取 → choices 变红）随 `panel-flip-m54.sh` 一起没了；今天 `38-d` 的红侧是它自己那几条 `grep` 断言与 `panel-choices.sh` 的 F-A/F-D。
- **`team-inbox-watch.ts:452`**：改，但**不是**因为指针——它保的是一个已经不存在的约束。我核了活的 harness：`team-inbox-watch-harness.mjs` 里没有 `writeSkipRecord`，也没有 `const dir = watchDir(root)` 这个锚点（`grep -n` 零命中），所以「别把这个变量改名，否则注射点失效」今天没有执行者；M46 的行为本身由 `§12b-pi` 的 M46-S14…S17（我这次实跑绿）+ `§12b-pi2` 守着。建议改成「历史上曾由 P354 之前的翻转包在此处做变异注射（已删）」。
- **`team-inbox-watch.ts:599`**：**可以不改**。它守的不变量（offset 用字节真值、不做解码→再编码）今天仍被 `§12b-pi` S18–S21 活着守着，并在我这次 §12b-pi 的 ✓103 里跑过；死掉的只是那个变异包的名字。若要统一措辞再改，优先级最低。

**为什么这不改判 PASS**：10 行全是注释，`grep` 掉注释后执行面零命中（§1②③）；它们不影响 `--check`（token 表里这 13 个名字本来就不在，535 个 token 全过），也不影响任何断言。判据是「还有没有执行路径」，不是「注释写得好不好」。

## 没验证的 / 边界

- **没跑整套**（任务书边界）。本次实跑的是 `--select 40`（182 s）+ `--select 11i`（17 s）+ `--select 12b-pi`（136 s）+ `--select 12b-h0b`（跑在 §12b-pi 之前的一轮，✓43 ✗0 rc=0）+ `--select 47`（10 s）；按 P98 口径点名**没跑的段**：`§0e 0f 0g 0h 0i`（前导未单独跑）、`6h 11b3 11b4 34d 38 58 26 27 28 12b-pi2` 等 130 个键未跑。
- `flip-m7.2 → §11b3`、`flip-p287-lock → §34d` 两行只用静态核（段存在且正文有对应断言/场景），**没有实跑**（FAST 下 `fast_skip`，完整门禁才跑；真跑要真 tmux/真锁/嵌套运行，超出本次预算）。
- `--loop-check` 的「删前 86/86」我没有复现（那需要一棵基线树）；我核的是等价物：`loop-inventory.tsv` 基线 86 数据行、退役恰好 4 行、候选 82/82，算术自洽。
- 所有破坏性动作只发生在 `/var/tmp`（克隆 `/var/tmp/v89-cand`、日志 `/var/tmp/v89-logs`）；本仓的源树与候选树一个字节都没改（`git status --porcelain` 在我的 worktree 里只有本报告）。

## 给 PM 的下一步（都不阻塞本次 PASS）

1. `BLOCKED:`（写集之外，归你或 P346）**`smoke.sh` 那 8 行**：6 处改指对应报告、`12365` 改成与 `tests/README.md` 一致的缺口陈述、`18892` 改指 `38-d` 自己与 `panel-choices.sh`。纯注释，改完只需重跑 `--select 27,38`（两段都便宜）。
2. `BLOCKED:`（产品文件，归你）`extension/team-inbox-watch.ts:452` 的措辞；`:599` 可选。
3. 决定 `panel-keyprobe.tsx`（116 行）与 `panel-keyprobe-pty.py`（99 行）这两个孤儿的去留——我确认它们今天没有任何执行路径（§1①）。
4. `panel-flip-m54` 那行墓碑建议补半句「F-B/F-C/W-B/A2-enum 今天无活翻转」，免得下一轮读成「五条都在」。
5. 合并时按 §3 末那条：与 main 自 `2011d094` 之后的改动**零交集**，squash 不会抹掉别人的成果。
