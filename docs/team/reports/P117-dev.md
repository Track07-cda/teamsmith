# P117 · 选段返工：剪贴副本永远可解析（V1）+ `needs` 闭包补齐（V2）

agent: dev   status: **done（待 PM 独立复验；local 模式分支留在本地）**   time: 2026-09-29
branch: `task/P117-needs`   PR/MR: -（local 模式，不 push）

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/tests/section-select.sh` | 新增 `--out`（唯一剪贴实现：区域用 `bash -n` 当嵌套裁判，不能自足就向右合并成**原子组**）与 `--verify-copies`（全键副本 `bash -n` 扫描）；`emit_copy` 写完副本再自检，不能解析就**在跑任何段之前**拒绝并点名（组 key + 源码行 + bash 的 `on line N`）。 |
| `skills/teamsmith/tests/smoke.sh` | 选段父进程**不再自己剪文本**（删掉旧 awk），改用选择器的 `--out`；副本缺失/被拒时 `rc=2` 且零段头；`36⑦` 夹具（扫描 + 旧剪贴器红侧 + 早拒 + 两个夹具键绿/红侧）。 |
| `skills/teamsmith/tests/section-paths.tsv` | V2：P112 名单（`3b/6/6f/6i/6j/10/10b/11/28`）+ 逐键审计挖出的 **25 行**（`3→2`、`4b/4c→4`、`6b/6h→3b`、`6d/6e/11d→6`、`11→10`、`7/11e2/11f/11i/11j/13/13b/20..24/32/43→2`、`8/9→5`）。 |
| `skills/teamsmith/tests/section-needs-audit.sh` | 新增：逐键 needs 自足审计（每键一遍 `smoke.sh --select <key>`，FAST/私有 TMPDIR/顺序执行；判定 = 该键自己的段落跑了且 ✗0、整条选集 rc=0）。 |
| `skills/teamsmith/references/protocol.md` | §9b-2 一句：选段绿只覆盖跑了的段，引用它的报告要点名没跑的段（P112 §5.1 的建议）。 |

## Verification evidence (must have actually been run)

```
# ① 修前（忠实还原：62090f65 的旧选择器 + 旧剪贴 awk）——两个键的副本不能解析
$ bash /tmp/p117-flip/old-sweep.sh <工作树> /tmp/p117-flip/section-select-old.sh /tmp/p117-flip
KEY=14 KEYS=0 0b 0c 0d 14
/tmp/p117-flip/copy-14.sh: line 995: syntax error: unexpected end of file from `if' command on line 969
KEY=14c KEYS=0 0b 0c 0d 14c
/tmp/p117-flip/copy-14c.sh: line 987: syntax error near unexpected token `fi'
TOTAL keys=113 ok=111 fail=2
PATH=skills/teamsmith/scripts/team → 不可解析：… line 14020: syntax error: unexpected end of file from `if' command on line 6943
PATH=skills/teamsmith/scripts/lib/cmd-agents.sh → 不可解析：… line 9933: … from `if' command on line 5380
PATH=skills/teamsmith/tests/smoke.sh → 不可解析：… line 2510: syntax error near unexpected token `fi'
（这就是 V1 的现场：2 个键 + 3 条真实产品路径的选集副本剪坏了；P112 §5.1 另有「跑完全部选中段才在 EOF exit 2、没有结果行」的现场。）

# ② 修后：全键副本 bash -n 扫描
$ bash skills/teamsmith/tests/section-select.sh --verify-copies | tail -1
== 段副本 bash -n 扫描 == ok 113 bad 0

# ③ 门禁里的 36⑦（扫描 + 红侧 + 早拒 + 两个夹具键的绿/红侧）
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh --select 36
  ✓ 36⑦ 全键副本 bash -n 扫描：ok 113 / bad 0
  ✓ 36⑦ 红侧（旧剪贴器=按段头一刀切）：全键扫描红了并点名 14/14c
  ✓ 36⑦ 坏副本在跑任何段之前被拒（rc=2、点名、零段头）
  ✓ 36⑦ 夹具依赖键 --select 3b 的选集全绿（…#8 3b … ✓37 ✗0 SKIP0…）
  ✓ 36⑦ 夹具依赖键 --select 6 的选集全绿（…#9 6 … ✓6 ✗0 SKIP1…）
  ✓ 36⑦ 红侧：3b 去掉 needs:5 → --select 3b 在该键上红了（rc=1；✓29 ✗8）
  ✓ 36⑦ 红侧：6 去掉 needs:3b → --select 6 在该键上红了（rc=1；✓0 ✗7）
== 选段结果 ==  ✓ 117  ✗ 0

# ④ needs 逐键审计（修数据前，全键 113；脚本本轮新增）
$ bash skills/teamsmith/tests/section-needs-audit.sh
== needs 逐键审计结果 ==  pass 84  bad 29  （共 113 键）
bad 名单：3 4b 4c 6b 6d 6e 6h 7 8 9 11 11d 11e2 11f 11i 11j 13 13b 20 21 22 23 24 32 40 43 45 46 48

# ⑤ 修数据后：被点名的 29 键重审（每键自己的段落跑了且 ✗0、整条选集 rc=0）
$ bash skills/teamsmith/tests/section-needs-audit.sh --keys 3,4b,4c,6b,…,48
ok   3        rc=0  … ✓7 ✗0 SKIP0
ok   4b       rc=0  … ✓22 ✗0 SKIP0
ok   6d       rc=0  … ✓16 ✗0 SKIP0
ok   11       rc=0  … ✓17 ✗0 SKIP1
ok   11i      rc=0  … ✓15 ✗0 SKIP0
ok   20       rc=0  … ✓43 ✗0 SKIP0
ok   40       rc=0  … ✓3 ✗0 SKIP0
ok   43       rc=0  … ✓17 ✗0 SKIP0
ok   45       rc=0  … ✓27 ✗0 SKIP0
ok   46       rc=0  … ✓42 ✗0 SKIP0
ok   48       rc=0  … ✓52 ✗0 SKIP0（45/46/48 经 43→2 的链修好）
== needs 逐键审计结果 ==  pass 29  bad 0  （共 29 键）

# ⑥ 爆炸半径（不必再跑一小时全键的机械证明）：逐键比较修前/修后的闭包
$ <old table vs new table closure compare>
closure changed for 28 keys:
11 11d 11e2 11f 11i 11j 13 13b 20 21 22 23 24 3 32 43 45 46 48 4b 4c 6b 6d 6e 6h 7 8 9
⇒ 除了 ⑤ 已重审的 29 键，其余 84 键的选集**逐字未变**（第一次审计里它们是绿的），且 `smoke.sh` 自那以后未再改。
⇒ 全键状态 = 84（闭包未变，第一次审计里就绿）+ 29（被点名重审，全绿；其中 28 个闭包变了，
   40 的闭包没变、红线是 lint 抓自己的新代码，已由代码修复转绿）。

# ⑦ 选择器自检 / lint / openspec / 全量门禁
$ bash skills/teamsmith/tests/section-select.sh --check | tail -1
== 选段自检 ==  ok 7  bad 0
$ bash skills/teamsmith/tests/smoke.sh --select 40       # lint 修好后（修前见「Flip evidence」）
  ✓ 40 lint 干净：检查了 13 个 mktemp -d 根模板（…/skills/teamsmith/tests）
$ <home>/.bun/bin/openspec validate --all --strict
Totals: 16 passed, 0 failed (16 items)
$ bash skills/teamsmith/tests/smoke.sh          # 全量门禁（走 TEAM_SMOKE_LOCK，dev2 先持有 → 排队）
<见下方「全量门禁」>

# ⑧ V1 的对外流程：组内耦合如实列出 + 真实路径的选集端到端绿
$ bash skills/teamsmith/tests/section-select.sh --select 14
reason=14 ← selected, coupled:14c
reason=14c ← coupled:14
$ bash skills/teamsmith/tests/smoke.sh --select 14
== 选段结果 ==  ✓ 24  ✗ 0 ; rc=0
$ bash skills/teamsmith/tests/smoke.sh --paths skills/teamsmith/tests/smoke.sh   # V1 三条真实路径之一
== 选段结果 ==  ✓ 1002  ✗ 0 ; rc=0
== 选段：这次没跑的段 == 86 个键 …（未跑清单照旧）
```

### 全量门禁（`openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh`）

```
$ <home>/.bun/bin/openspec validate --all --strict
Totals: 16 passed, 0 failed (16 items)
validate rc=0
$ bash skills/teamsmith/tests/smoke.sh          # 走 TEAM_SMOKE_LOCK（dev2 先持有 → 我的 run 排队后开跑）
== 最慢 5 段 ==
  #97 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 用时 287s · ✓22 ✗0 SKIP0 · ticks 22
  #110 51 · 用法诚实性：help 的每条承诺与名册的每条路线都有夹具兑现（P99） · 用时 141s · ✓2 ✗0 SKIP0 · ticks 2
  #95 36 · 选段与分段账本自检（P98 · gate-runtime-budget） · 用时 112s · ✓96 ✗0 SKIP0 · ticks 96
  #62 12b-pi · M30 投递换道：pi 通道零 tmux 粘贴（收件箱监视唤醒） · 用时 76s · ✓103 ✗0 SKIP0 · ticks 103
  #61 12b-h0c · P59 输入框判据：覆盖层（Pi 的项目信任弹窗）≠ 非空输入框 · 用时 65s · ✓124 ✗0 SKIP0 · ticks 124
账本自查： 112 段收口 · 增量 ✓3706 ✗0 SKIP0 ｜ 结果行 ✓3706 ✗0 —— 一致
== 结果 ==  ✓ 3706  ✗ 0
smoke 全绿
smoke rc=0
（§36 的七条 36⑦ 断言就在这一段里：全键扫描 ok 113/0、旧剪贴器红侧点名 14/14c、早拒 rc=2 零段头、3b/6 绿、两条红侧）
```

- Verdict: **pass**（`validate rc=0` + `smoke rc=0` / `smoke 全绿` / ✓3706 ✗0）
- Notes:
  - ⑥ 是**机械证明**而不是重跑：闭包相同的键 = 运行内容逐字相同。PM 若要一条干净的「113/113 绿」原始行，
    直接跑 `bash skills/teamsmith/tests/section-needs-audit.sh`（约一小时，顺序，会占门禁锁之外的时间）。
  - `smoke.sh` 的旧 awk 剪贴器已删除；`--paths`/`--select` 的对外行为（decision 行、未跑段清单、结果行）未改。
  - `14c` 仍归 FAST 管：14/14c 的 FAST 守卫一行未动（full 模式仍不跑 14c 的正文），§14/§36③ 断言未放松。
  - 逐键审计对 **FAST 的 SKIP 不判红**：11/11d/11j/32/6h 这类段落按设计在 FAST 里显式跳过（SKIP1），
    这是既有口径；`SKIP0/1` 原样印在每行里，不静默。

## Flip evidence (required for defect-fix tasks)

`break → the guard must fail → restore`，三段都真跑：

```
# A. 副本解析（V1）
$ bash skills/teamsmith/tests/section-select.sh --verify-copies     # 恢复真实实现
== 段副本 bash -n 扫描 == ok 113 bad 0
$ <把 span_parses 砸成 `return 0`（= 旧「按段头一刀切」）>
$ bash <变体>/tests/section-select.sh --verify-copies; echo rc=$?
bad: 14 —— 副本不能解析（段 14 · 源码行 969 · …）
bad: 14c —— 副本不能解析（段 14c · 源码行 18769 · …）
== 段副本 bash -n 扫描 == ok 111 bad 2 ; rc=1
$ <变体里 nested：TEAM_SMOKE_FAST=1 bash <变体>/tests/smoke.sh --select 14>; echo rc=$?
smoke: 选段被拒（副本不能解析 / 表或源码结构问题）—— 什么都没跑 ; rc=2
（日志里 `== #` 段头数 = 0：拒绝发生在跑任何段之前；修前是「跑完全部选中段 → EOF exit 2 → 没有结果行」）

# B. needs 数据（V2）：删掉一条边 → 该键的选集变红
$ <表变异：3b 去掉 needs:5>   → --select 3b : rc=1，3b own ✓29 ✗8
$ <表变异：6  去掉 needs:3b>  → --select 6  : rc=1，6  own ✓0  ✗7
（恢复真实数据 → §36⑦ 里两条「夹具依赖键 --select 3b/6 的选集全绿」）

# C. 新增脚本自己的 lint（section 40 抓到的真 finding）
修前：bad 40 lint 有 finding（rc=1）：section-needs-audit.sh:47 写死绝对路径（/tmp/snXXXX）—— 必须建在 ${TMPDIR:-/tmp} 下
                                              section-select.sh:381 名字不在 owned 家族（…/section-select-copies.XXXXXX）—— 必须是 teamsmith-<kind>.XXXXXX
修后：✓ 40 lint 干净：检查了 13 个 mktemp -d 根模板
```

## Decisions and deviations

- **剪贴路线选 ①（`bash -n` 当嵌套裁判），不是 ②（手写 bash 解析器）**：`bash -n` 是机器可判的裁判，
  换代/嵌套形态不用追；代价写在选择器头注释里 —— 区域不能自足就**向右合并**成原子组（现场只有 14+14c
  这一组），组内任一被选 = 整组进运行集，`--list`/运行清单**如实列出组内全部成员**（不谎报粒度）；
  前导或收尾不能自足 = 直接 die（早、响亮、可诊断），不猜、不剪。
- **V2 的修比 P112 名单大**：逐键审计发现 29 个键（不是 5 个）的选集在缺夹具前提时红。把「夹具链」补进
  这些行后全部转绿；45/46/48 只经 43→2 的既有链修复，没有多余的直连边。每一步的边都有 miner/审计的实测输出，
  行内 basis 记了口径（`tests/section-needs-audit.sh`）。
- **没有第二次跑一小时的全键审计**：用「修前全键 84/29 + 修后被点名 29 键 29/0 + 闭包逐键比较（只有这 28
  个键的闭包变了，全在重审名单里）」的组合证明 113 键全绿。若 PM 要求一条干净的全键原始行，命令就是
  `bash skills/teamsmith/tests/section-needs-audit.sh`。
- **`protocol.md` 加了一句**（P112 §5.1 的建议）：选段绿只覆盖跑了的段，引用它的报告要点名没跑的段。
- 未动：FAST 守卫、14c 归属、既有断言、`--paths` 的 decision 语义、账本/收口行；`--out`/`--verify-copies`
  都是**新增**旋钮，老调用（`--list/--paths/--select/--check`）不变。
- **代价写在了用它的地方**：`--verify-copies` 是 ~15s 的守门扫描（113 份副本 × `bash -n`），只进 §36⑦
  的门禁采样，不是每题都跑；`--out` 每次 `--select/--paths` 多一次 `bash -n`（毫秒级，换来「不许跑坏副本」）。
  真正的全键逐键跑（~1 小时）留给验收工具 `section-needs-audit.sh`，不进默认门禁。

## Suggested next steps

- PM 复验：`team review P117 --strong`（本任务含 §36⑦ 的红侧与早拒，报告里有原始输出）；要全键原始行就
  跑一次 `bash skills/teamsmith/tests/section-needs-audit.sh`（约一小时）。
- 归档（若 PM 判定 PASS）：change `gate-runtime-budget` 的 verification 增量不受影响；`section-needs-audit.sh`
  是新的守门工具，可在归档说明里点一句。
- 后续（不在本任务内）：逐键审计目前是**手动/验收**工具，没有进默认门禁（一小时太长）；如果要常态化，
  建议先在 P70 预算表里给它一个采样档位（例如固定几键 + 表变更时的全键夜跑），这条留给 PM 排期。
