# V74 · P333（空清单不再假装「无法裁决」，跳过分枝仍有影子）的独立验收 — 复验报告（verify）

time: 2026-10-20T10:36Z（实际收尾；各次运行的原始时刻见证据）
受检：候选 `3291bf05`，分支 `task/P333-empty-exemption-list`。任务书写「4 个提交」，实际 **5 个**：
`864bb653`（`smoke.sh` 的条件与注释）、`0ab2b8eb`（探针 ⑩ 两行 + 影子）、`f1923997` / `b31b976d` / `3291bf05`
（作者报告三次修订）。作者报告 `docs/team/reports/P333-dev3.md`。
形态：只读代码 + 只在 `/var/tmp/v74-verify/` 下的独立 clone / copytree 里造破坏；不改实现、不合并、不 push。

## 结论（先看这里）

**PASS。** 任务书要回答的三件事，逐条成立；三条各带了它改变的那个判断：

1. **空清单时那行假提示真的没了，判定照跑。** 内部形状的独立 clone（`git clone` + 检出 `3291bf05`，
   `TMPDIR=/var/tmp/v74-verify/tmp` 这种磁盘临时根、私有锁 + `TEAM_SMOKE_NO_LOCK=1`），清单为零条登记，
   `smoke.sh --select 58`：`SKIP（条件不满足） 58 lint 真树` 出现 **0 次**；`✓ 58 lint 真树：…（0` /
   下一行 `0 个历史豁免文件逐条打印）` 在，`signal-lint：干净（扫描 90 个脚本…）` 在；段尾 `✓13 ✗0 SKIP0`
   （那一条不再计入），整次 `rc=0`（`✓36 ✗0`）。
2. **跳过分枝的影子还在。** 同一棵树，清单里只加**一条**「落在内部面、且不在这棵检出里」的登记，同一次
   `--select 58`：`SKIP（条件不满足） 58 lint 真树 … 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层）
   docs/team/reports/*/pkg/** 在检出里不存在` 重新出现，`SKIP1`、`rc=0`。探针里新加的 `po10shadow` 钉的是同一件事
   （`ok: ⑩ 影子：一条登记且都不在 → §58 照旧打那条前提跳过`）。
3. **没有顺手放松；牙齿与新断言都会咬人。** 零条清单 + 在 `tests/` 之外（`docs/team/reports/V74-fixture/pkg/planted.sh:3`）
   种 `pkill -f v74-planted` → §58 **红**并点名 `file:line`，`rc=1`、`SKIP0`。反例：把条件改回旧写法（去掉「登记条数
   ≥ 1」）后，探针 ⑩ 的**两条新断言同时变红**（SKIP 计数 1≠0、证据层文案出现）；新代码下同一形状两条都绿。
   两个受检文件相对 main 各只有**一个 diff hunk**，hunk 之外逐字未动；`checkout_registered_paths_absent`、
   `checkout-shape.sh`、`signal-lint.pl`、§19、§31 全未改。探针自己跑出 `ok 147 bad 0 skip 0`（623.6 s）。

**任务书记录的候选提交数是 4，实际 5**（上面点名）。这是账本计数差异，不改变受检树内容：
`3291bf05` 的树就是全部五个提交的树。

## 测试状态

所有运行都在 `/var/tmp/v74-verify/` 下；私有临时根 `/var/tmp/v74-verify/tmp`、私有锁 `<该目录>/v74-*.lock`，
`TEAM_SMOKE_NO_LOCK=1` 不排队、不碰机器级门禁锁。开跑前 `ps -eo pid,etime,args | grep -E 'smoke\.sh|checkout-shape-probe'`
无输出（没有别人的门禁在跑）；探针启动时 `load1=13.31 × 32 核 = 0.42`（前提 0.75），全程 0.27–0.42。

| # | 命令 | rc | 读数（原始尾部见证据节） |
|---|---|---|---|
| 1 | `git clone <main> /var/tmp/v74-verify/cand && git checkout 3291bf05` | 0 | `HEAD=3291bf0503…`；`git status --porcelain` 空 |
| 2 | `smoke.sh --select 58`（独立检出，清单零条） | 0 | 无 SKIP；`✓ 58 lint 真树…（0` + `0 个历史豁免文件逐条打印）`；`✓13 ✗0 SKIP0`；`✓36 ✗0` |
| 3 | 同一棵 + **一条**内部面且缺席的登记 → `--select 58` | 0 | SKIP 重新出现并点名证据层；`SKIP1`；`✓36 ✗0` |
| 4 | 同一棵（清单零条）+ `tests/` 外种 `pkill -f v74-planted` → `--select 58` | 1 | `✗ 58 lint 真树判红` + `RED  docs/team/reports/V74-fixture/pkg/planted.sh:3  pkill -f v74-planted`；`✓12 ✗1 SKIP0` |
| 5 | 产品面树 + 新条件 → `--select 58`；按探针 ⑩ 的两条表达式判读 | 0 | 断言 1（SKIP 计数=0）PASS；断言 2（证据层文案缺席）PASS |
| 6 | 产品面树 + **旧**条件（把「登记条数 ≥ 1」删掉）→ `--select 58`；同样两条表达式 | 0 | 断言 1 **FAIL**（计数 1）；断言 2 **FAIL**（文案出现） |
| 7 | `bash skills/teamsmith/tests/checkout-shape-probe.sh`（受检 clone，`bash -c` 后台，623.6 s） | 0 | `== 检出形状探针 == ok 147 bad 0 skip 0`；`ok: ⑧ 真实树指纹前后一致` |
| 8 | `bash -n skills/teamsmith/tests/smoke.sh`、`…/checkout-shape-probe.sh` | 0 | 无输出 |
| 9 | `bash skills/teamsmith/tests/section-select.sh --check` | 0 | `== 选段自检 ==  ok 9  bad 0  SKIP 1` |
| 10 | `PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict` | 0 | `Totals: 21 passed, 0 failed (21 items)` |
| 11 | ledger-ban 固定验收行（见下） | 0 | `scope=published files=1900 hits=0 names=ok user=resolved` |
| 12 | `git diff --check 3291bf05~5 3291bf05`（受检 clone） | 0 | 无输出 |
| 13 | 同一棵零条清单树 → `smoke.sh --select 31`（只为观察同形，见「不符三」） | 0 | §31 照旧打同形状的「无法裁决」SKIP；`✓9 ✗0 SKIP2` |
| 14 | `git diff main 3291bf05 -- skills`（作用域核对） | 0 | 两个文件各 **1 个 hunk**；`21/4` 与 `13/6` 行 |

`openspec` 的裸名字在这台机器上**不在 PATH**（交互 shell 与 `bash -lc` 都是 `command not found`）；磁盘上只有
bun 全局那份 `$HOME/.bun/bin/openspec`（`--version` → 1.8.0），所以第 10 行是把那个目录加进 PATH 后跑的。
这与作者报告的「本机没有 openspec」不同：**有，但不在 PATH**。

**不是整套门禁**：只跑了选段 58（外加一次 31 用于观察），没跑别人会等的整套；本报告对没跑的段不下结论。

## 实验形态（不是照抄作者的现场）

- 受检树是 `/var/tmp/v74-verify/cand`：从主检出 `git clone` 出来的**独立仓库**（不是 worktree，`.git` 自洽），
  detached 在 `3291bf05`。其余每轮是它的 `cp -a` 副本（`t-empty` / `t-one` / `t-teeth` / `t-po-new` / `t-po-old`），
  破坏只发生在副本里。每次 §58 都清空现场重跑（不累积）。
- 每轮临时根都是 `TMPDIR=/var/tmp/v74-verify/tmp`（磁盘，不是 tmpfs）+ `TEAM_TMP_ROOT` 同值；锁是
  `/var/tmp/v74-verify/tmp/v74-*.lock` + `TEAM_SMOKE_NO_LOCK=1`。没有一轮碰机器级锁。
- 清单「零条」的复现：受检树的 `signal-lint-legacy.txt` **本来就是**零条登记（`grep -c '^[^#]'` = 0）；
  我在副本里把它显式重写成「只有注释」后 `md5sum` 与 HEAD 里那份**完全相同**（`77e4cf18…`），
  `git status` 空 —— 所以第 2 行的读数不是「我改坏了清单」换来的。
- 「一条登记」用的是 `docs/team/reports/V74-fixture/pkg/absent.sh`（内部面、树里不存在），
  并按 `checkout_surface_path` 的口径确认它落在 `docs/team` 之下。
- 反例（第 6 行）用的是**产品面**形状的副本（删掉 `docs/ AGENTS.md SCOPE.md .pi openspec/changes`，
  `checkout_shape` 回 `product-only`，与探针 ⑩ 的 `scratch_tree po10 product-only` 同形），条件用
  `perl -0777 -pi` 精确还原成 main 上的两行 `if`（`bash -n` 通过）。
- 第 4 行的破坏种在 `tests/` **之外**（`docs/team/reports/V74-fixture/pkg/`），没有利用清单豁免。

## 证据

### 1. 空清单：那行假提示没了，判定照跑（第 2 行，`rc=0`）

```
== #5 58 · 信号纪律：闸门 / 作业 pid / lint（P159） == 2026-10-20T10:22:10+00:00
  ✓ 58：signal-lint 豁免清单存在
  ✓ 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（0
0 个历史豁免文件逐条打印）
      signal-lint：干净（扫描 90 个脚本；pid 精确形态全部干净）
  ✓ 58 lint --selftest：双向夹具全部符合预期
…
#5 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 参考 用时 12s · ✓13 ✗0 SKIP0 · ticks 13
账本自查： 5 段收口 · 增量 ✓36 ✗0 SKIP0 ｜ 结果行 ✓36 ✗0 —— 一致

== 选段结果 ==  ✓ 36  ✗ 0
```

`grep -c '^  SKIP（条件不满足） 58 lint'` = **0**，`grep -c '豁免清单注册的路径逐条不在（冻结的证据层）'` = **0**。

**一处口径事实（不改实现，也不改结论）**：任务书要求的连续串 `（0 个历史豁免文件…）` 在输出里**不是连续的** ——
这一行是 `$(grep -c '^  LEGACY' … || printf 0)`：零命中时 `grep -c` 已经打出 `0` 且 rc=1，`|| printf 0` 再追加一个，
于是命令替换得到 `0\n0`，打印成 `（0` 换行 `0 个历史豁免文件逐条打印）`。最小复现：

```
$ f=$(mktemp); printf 'hello\n' > "$f"; x="$(grep -c '^  LEGACY' "$f" 2>/dev/null || printf 0)"; printf '%q\n' "$x"
$'0\n0'
```

这一行**这次一个字没改**（main 上同形；作者报告的 `✓ …（0` 也是这个原因），所以字面串 grep 不到并不等于行为不成立：
没有 SKIP、lint 照跑、`（0` 后跟的是「0 个历史豁免文件」、段尾 SKIP0、整次 rc=0，全部成立。

### 2. 跳过分枝的影子（第 3 行，`rc=0`）

同一棵零条清单树，只追加一条内部面、树里不存在的登记：

```
  ✓ 58：signal-lint 豁免清单存在
  SKIP（条件不满足） 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
  ✓ 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程（0
0 个历史豁免文件逐条打印）
…
#5 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 参考 用时 12s · ✓13 ✗0 SKIP1 · ticks 14
```

探针里同一件事（`ok 147` 的那一次）：`ok: ⑩ 影子：一条登记且都不在 → §58 照旧打那条前提跳过`、
`ok: ⑩ 影子：跳过点名的前提是豁免清单的冻结对象（docs/team/reports/*/pkg/**）`、
`ok: ⑩ 影子：一条登记且都不在 → --select 58 退出 0`。

### 3. 牙齿还在（第 4 行，`rc=1`）

零条清单 + `docs/team/reports/V74-fixture/pkg/planted.sh`（第 3 行 `pkill -f v74-planted`）：

```
  ✓ 58：signal-lint 豁免清单存在
  ✗ 58 lint 真树判红（见 /var/tmp/v74-verify/tmp/teamsmith-smoke-t_teeth-3c4bed72.tYaAfa/p159-lint.log）
        RED  docs/team/reports/V74-fixture/pkg/planted.sh:3  pkill -f v74-planted
  ✓ 58 lint --selftest：双向夹具全部符合预期
#5 58 · 信号纪律：闸门 / 作业 pid / lint（P159） · 参考 用时 13s · ✓12 ✗1 SKIP0 · ticks 13
```

### 4. 反例：新断言会咬人（第 5、6 行）

判读用的是探针 ⑩ 的**同一对表达式**（`grep -c '^  SKIP（条件不满足） 58 lint'` = 0；证据层文案必须缺席），
在同样形状的产品面树上跑 `--select 58`（按任务书允许的「直接判读 `--select 58` 的输出差异」这条最小代价路径；
探针第 7 行在受检树上自己把那两条断言跑了一遍）：

```
=== product-only + 新条件 ===            rc=0  断言1 PASS [count=0]  断言2 PASS
=== product-only + 旧条件（还原）===     rc=0  断言1 FAIL [count=1]  断言2 FAIL
  SKIP（条件不满足） 58 lint 真树：… —— 检出形状 product-only：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
#5 58 … · 参考 用时 13s · ✓13 ✗0 SKIP1 · ticks 14
```

红绿两侧只有那一条条件不同，所以「新断言能不能咬」是被单独测出来的，不是同义反复。

### 5. 探针（第 7 行，后台作业 `v74-probe`，623.6 s，`exit=0`）

```
ok: ⑩ 产品面树 --select 58 退出 0（豁免清单不再假红）
ok: ⑩ 产品面：清单零条登记不算「无法裁决」——§58 不打那条前提跳过
ok: ⑩ 产品面：空清单不再说「豁免清单注册的路径逐条不在（冻结的证据层）」
ok: ⑩ 产品面：lint 照跑（不是把 58 整条记成跳过）
ok: ⑩ 产品面：--select 58 的红数为 0
ok: ⑩ 影子：一条登记且都不在 → --select 58 退出 0
ok: ⑩ 影子：一条登记且都不在 → §58 照旧打那条前提跳过
ok: ⑩ 影子：跳过点名的前提是豁免清单的冻结对象（docs/team/reports/*/pkg/**）
ok: ⑩ 内部树 + 清单文件都在 → 不以「证据层缺席」为由跳过
ok: ⑩ 内部树 + 清单文件都在 → signal-lint 照旧逐条核对（LEGACY 打印）
ok: ⑩ 缺失的产品面条目照旧判红并点名该文件
ok: ⑩ 红的是 lint 的基线过期（清单里的文件不在了）
ok: ⑩ 缺失的产品面条目不得记成前提跳过
ok: ⑩ 影子：删掉逐条内部面判据（=「任何缺失即跳过」）→ 同一条产品面缺失被吞、§58 判绿（牙齿真咬在判据上）
ok: ⑩ 产品文件里的 pkill -f 照旧判红并点名 file:line
ok: ⑧ 真实树指纹前后一致（夹具只动 scratch 树）
== 检出形状探针 == ok 147 bad 0 skip 0
```

147 与 diff 的算术对得上：删 2 条（旧的两条 `phas`）加 5 条（`peq` SKIP 计数、`pnot` 证据层文案、影子里的
`peq` + 两条 `phas`）= 144 → 147。

### 6. 没有顺手放松（第 14 行 + 阅读）

```
$ git diff --numstat main 3291bf05 -- skills
21      4       skills/teamsmith/tests/checkout-shape-probe.sh
13      6       skills/teamsmith/tests/smoke.sh
$ git diff main 3291bf05 -- skills | grep -E '^(diff --git|@@)'
diff --git a/skills/teamsmith/tests/checkout-shape-probe.sh b/skills/teamsmith/tests/checkout-shape-probe.sh
@@ -743,15 +743,32 @@ phas "⑨ 清单含产品路径 → M28 照旧带清单跑（不是跳过）" "$
diff --git a/skills/teamsmith/tests/smoke.sh b/skills/teamsmith/tests/smoke.sh
@@ -22209,22 +22209,29 @@ if ! command -v perl >/dev/null 2>&1; then
```

每个文件只有**一个 hunk**，所以 hunk 之外逐字未动。hunk 内逐条：

- `smoke.sh`（13+/6−）：9 行注释（§58 头注重写 + P333 那三行说明）+ 4 行代码 —— `P159_LEGACY_ENTRIES=0`、
  循环里的 `+1`、`if [ "$P159_LEGACY_ENTRIES" -ge 1 ] \`、`&& [ "$P159_LEGACY_ALL_INTERNAL" = 1 ] \`。
  删掉的是 4 行旧头注 + 旧 `if` 的两行。**没有**动 `prereq_skip` 的文案、`ok`/`bad` 的判定，也没有动别的段。
- `checkout-shape-probe.sh`（21+/4−）：③ 那三行注释 + 翻新的两条断言（`phas` → `peq` / `pnot`）+ `po10shadow`
  三步（构造、`nest`、`peq` + 两条 `phas`）+ 一个空行。删掉的是旧的两条 `phas`。⑩ 里其余断言
  （`--select 58` 退出 0、lint 照跑、红数为 0、内部树 LEGACY、缺失产品面条目照旧红）与 ⑨ 的三例牙齿、
  ⑤b/⑤d 的机器生成面控制，在 main 与候选里同名同位置（`grep -cF` 均为 1/1），没被改写。
- 相对 main，`skills/` 下**只有这两个文件**（`git diff --stat` 两行）。`checkout_registered_paths_absent`、
  `checkout-shape.sh`、`signal-lint.pl`、§19、§31 都不在 diff 里。

### 7. 轻量收口（第 8–12 行）

```
$ bash -n skills/teamsmith/tests/smoke.sh && bash -n skills/teamsmith/tests/checkout-shape-probe.sh
（无输出）
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 9  bad 0  SKIP 1
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
Totals: 21 passed, 0 failed (21 items)
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/verify scope=published files=1900 hits=0 names=ok user=resolved
$ git diff --check 3291bf05~5 3291bf05
（无输出）
```

## 与任务书假设不符的三处（如实写，都不改变结论）

1. **候选提交数是 5 不是 4**（见开头的五个 hash）。账本计数差异，树内容无歧义。
2. **`（0 个历史豁免文件…）` 不是连续串**（见证据 1）：既有 `$(grep -c … || printf 0)` 写法在零命中时给出
   `0\n0`。这一行不受本次改动影响；任务书若以字面串当判据，会误判成不满足。
3. **同一个「空清单假装无法裁决」的形状在 §31 还在**：`tmux-lint-legacy.txt` 也是零条登记
   （`grep -c '^[^#]'` = 0），而 §31 的条件（`smoke.sh:14278`）没有「登记条数 ≥ 1」，所以在**真实的内部树**上
   `--select 31` 照旧打出 `SKIP（条件不满足） M28 真树… 豁免清单注册的路径逐条不在（冻结的证据层） …`：

   ```
   == #5 31 · tmux 接触面：隔离 lint + 容器跑法（M28） == 2026-10-20T10:26:17+00:00
     SKIP（条件不满足） M28 真树：变更类 tmux 调用全部有隔离证据（豁免清单） —— 检出形状 internal：豁免清单注册的路径逐条不在（冻结的证据层） docs/team/reports/*/pkg/** 在检出里不存在（跳过不是通过）
   #5 31 · tmux 接触面：隔离 lint + 容器跑法（M28） · 参考 用时 4s · ✓9 ✗0 SKIP2 · ticks 11
   ```

   这不是这次改动放松的东西（§31 一行没动，探针 ⑨/⑤b 仍有断言钉着它），也不影响 §58 的判定；
   但它是**同一类假提示**，要不要开一个同形的后续（条件 + 翻 ⑨ 那条断言 + 影子）由 PM 定。

## 没做的 / 边界

- **没跑整套门禁**（任务书要求），只跑选段 58 与一次 31；对未跑的 130 个键不下结论。
- **容器门禁没跑**（本任务的判据不经过它；`--select 31` 里的容器自检也按机器现状跳过，见上面那行 `SKIP2`）。
- **字面串判据按行为判**，不按任务书给的那串连续文本（原因见证据 1）；没有为了让它连续去改产品代码。
- **§31 的同形问题只观察到、没修**：不改实现是本任务的边界；把它写进报告是为了让下一步可被决定。
- 受检树与副本都在 `/var/tmp/v74-verify/`，收尾时删掉了 `cand` 与五个 copytree（可重建）；**日志与重放命令保留**，
  见交付物。没有碰主检出、没有碰别人的分支。

## 交付物

- 本报告：`docs/team/reports/V74-verify.md`（分支 `task/V74-empty-ledger-verify`，local 模式不 push）
- 原始日志（保留供复验；每份都有去 ANSI 的 `.plain` 副本）：
  `/var/tmp/v74-verify/run-1-empty.log`（空清单）、`run-2-one.log`（一条登记）、`run-3-teeth.log`（牙齿）、
  `run-po-new.log` / `run-po-old.log`（反例两侧）、`run-4-sec31.log`（§31 同形观察）、
  `openspec-validate.log`；探针日志在项目内 `.pi/team/state/bg/v74-probe.log`。
- 重放（受检树可按任一 hash 检出，命令原样可用）：

  ```bash
  mkdir -p /var/tmp/v74-verify/tmp
  git clone <仓库> /var/tmp/v74-verify/cand && git -C /var/tmp/v74-verify/cand checkout 3291bf05
  cd /var/tmp/v74-verify/cand
  TMPDIR=/var/tmp/v74-verify/tmp TEAM_TMP_ROOT=/var/tmp/v74-verify/tmp \
  TEAM_SMOKE_LOCK=/var/tmp/v74-verify/tmp/v74.lock TEAM_SMOKE_NO_LOCK=1 \
    bash skills/teamsmith/tests/smoke.sh --select 58 </dev/null
  TMPDIR=/var/tmp/v74-verify/tmp TEAM_TMP_ROOT=/var/tmp/v74-verify/tmp \
    bash skills/teamsmith/tests/checkout-shape-probe.sh      # 约 10 分钟，先看 load1/核数 ≤ 0.75
  ```
