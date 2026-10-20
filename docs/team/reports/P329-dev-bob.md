# P329 · 三处减法：一段重复推导、两句假注释、五条守着一个不存在的数的断言

agent: dev-bob   status: delivered   time: 2026-10-20T11:48Z
branch: `task/P329-subtractions`   phase: apply   change: `-`
写集：`skills/teamsmith/scripts/lib/common.sh`、`skills/teamsmith/scripts/lib/gate-lock.sh`、
`skills/teamsmith/tests/smoke.sh`、`skills/teamsmith/tests/section-paths.tsv`（§36① 逼出来的一行）+ 本报告
提交：`ba3b17a8`（合并推导）、`33d83df0`（三处减法）、`2a47156d`（补 §34b 的路径声明）、本报告

## 结论先写

三条动作全部落地，验收选集 `--select 34,34b,58` **✓144 ✗0**（§34 ✓35、§34b ✓75、§58 ✓11）；两条「断言」
改动的红侧各自只让**一条**断言变红，同一份门禁、同一棵树。

- **断言数**：§58 **25 → 21**（删翻转 ①③ 各一对 `ok`/`bad`）；§34 **39 → 37**、§34b **86 → 82**
  （§34+§34b 合计 **125 → 119**；减掉的 6 条是 5 条建在自造 `expected=400` 上的算式断言 + 1 条只服务那个
  自造值的 `bad` 分支）。
- **代码行数**：`gate-lock.sh` **544 → 542**（它自己那份 18 行推导换成 3 行调用 + 3 行注释）；
  `common.sh` **6429 → 6444**（推导 19 行只剩一份，`team_sender_from_dir` 从 24 行收到 10 行，多出来的是
  `team_seat_from_paths` 自己的头注 —— 去重的是**逻辑**，不是行数）；`smoke.sh` **22685 → 22659**。
- **任务书的两条验收命令行本身跑不通**，我按正确形式跑了：第 1 条 `--select 34 34b 58` → `未知参数 34b`、rc=2；
  第 2 条 `openspec` 在这台机器的登录 shell 里也不在 PATH。PM 复验请照「静态收口」里改正后的命令行，否则看到
  的是 rc=2 / `command not found`，而不是这次改动的问题。
- **`--paths` 全选段跑出 7 红**：3 条是 main 上**改前就有**的 §0e 循环清单不同步（同一棵改前树上一模一样，
  我没动它），4 条是 §36① 抓住我漏声明 `common.sh`（已修，复跑绿）。§0e 那条请 PM 立单。
- 另有一条**既有不稳定断言**在第三次复跑时红了一次（§34b⑫「登记随它退出消失」，同一棵树上前两轮是绿的，
  P288/P313/P316/V53/V57 都记过它），与本改动无关。

## 数字：三组，逐组说明删了什么、留了什么、红侧是哪一条

### 1 · §58 信号纪律：内联翻转 ①③（25 → 21 条断言）

- **删**：①「干净文件不报红」（`printf '…\ntrue\n'` + 一对 `ok`/`bad`）与 ③「`kill -TERM "$pid"` 不误报」
  （`printf` + 一对 `ok`/`bad`），连同它们为自己写的 scratch 落盘（共 6 行）。理由与 PM 裁定一致：
  `signal-lint.pl --selftest` 的夹具表（29 例）里 `kill_term_pid` / `kill_zero_pid` 等 clean 例与这两条断言
  **同形**，且 selftest 是把每例写成 `case.sh` 用 `--root` 扫真二进制。
- **留**：翻转② `pkill -f` 必须**判红并按 `file:line` 点名**（`p159-lint-flip/x.sh:2`）——全树只有它在守
  「判红的位置」，selftest 只判红/净。注释已写明这条分工（`smoke.sh` §58 那段首行）。
- **红侧**：本条守的是「位置」，而 selftest 守「红/净」，所以删掉的 ①③ 没有独立的红侧实验可做 ——
  我按 PM 裁定的理由接受，不宣称有翻转证据。

### 2 · §34⑦ / §34b⑨ 上限算式：两句假话 + 五条断言（§34+§34b 125 → 119）

- **假话**（`smoke.sh` 原两处，§34⑦ 与 §34b 入口各一）：`# P316：预算表退役；expected/bound 为 0/0`。
  实测 `expected=0` 对、`bound=121500` 错 —— 探针见「翻转证据 3」。
- **删**：§34⑦ 的 `cap = clamp(remaining+60, W, 4W)` 断言、`remaining` 落点区间断言与它们外面的 `bad` 分支；
  §34b⑨ 的 `clamp(remaining+60,…)`、`remaining 由 started 算出`、`W 抬到 1000 → 下限`、`W 只有 10 → 4W`
  四条，连同自造记录 `gate_lock_write_holder … 400 2400 3 …`。
- **留**（都是**真**行为）：§34b⑨「旧持有者没有 expected → 上限仍是 `TEAM_SMOKE_LOCK_WAIT`」；§34b① 与 ⑦
  「排到队后照常判 PASS」「超上限大声失败、一行点名持有者（`cmd=` 与 `TEAM_SMOKE_LOCK_WAIT=200s`）」；
  §34c / §34d 的锁身份检查一条没动。
- **红侧**：见「翻转证据 1」—— 把「读不到 expected → 退回 W」改成 `+1`，`--select 34b` → `✓97 ✗1`，
  唯一红行就是保留下来的那一条（期望 1800、实际 1801）。
- **删完之后算式本身没有断言了**，这是有意的（它今天唯一的输入是夹具自己编的 400）；规范里描述的那个形状
  （等待者耐心跟随持有者的心跳、并把三个数打印出来）是 `gate-waiter-patience` 那条 change 的题目，
  P329 不替它立断言。

### 3 · 席位＝运行时目录：两份推导合成一份（`gate-lock.sh` 544 → 542）

- **删**：`gate_lock_seat_of_dir` 自己那份实现（toplevel / 主检出 / worktrees 前缀 / 名册拼写，18 行）。
- **加**：`common.sh` 的 `team_seat_from_paths <top> <main> <wt> <名册>` —— 纯函数，推不出就给空。锁记录与
  `team notify` 都调它；**失败语义留在各自的调用方**：锁记录写 `?`（它是诊断证据，记录必须写成功），
  `team notify` 拿到空就拒绝（发给谁都不知道）。
- **§34b⑨ 的断言**：五条里「解析不出写 `?`」保留；「与 notify 逐字同源」改成「**调同一个函数**」—— 用同一组
  目录同时问两边、比对结果（`dev|dev`、`pm|pm`），并各留一条失败语义（`?` / 空）。
- **红侧**：见「翻转证据 2」—— 改回自带实现并漏掉「主检出 = pm」这条规则，`--select 34b` → `✓97 ✗1`，
  唯一红行是 `同一推导：主检出上两边都是 pm（期望 pm|pm，实际 ?|pm）`。

## 翻转证据（红 → 绿）

两轮都在同一棵树、同一份门禁上做；改完用 `git checkout HEAD --` 复位并核对 `git status --short` 为空。

### 1 · 「读不到 expected 就退回 W」

```console
$ python3 - <<'PY'                      # 只改一个分支：读不到 expected 时 +1 而不是退回 W
... -  case "$expected" in ''|'-'|*[!0-9]*) printf '%s\t-\t-\t-\n' "$wait"; return 0 ;; esac
... +  case "$expected" in ''|'-'|*[!0-9]*) printf '%s\t-\t-\t-\n' "$(( wait + 1 ))"; return 0 ;; esac
$ bash skills/teamsmith/tests/smoke.sh --select 34b > /var/tmp/p329-redA-34b.log 2>&1; echo rc=$?
rc=1
$ grep -a '✗' /var/tmp/p329-redA-34b.log | grep -v '✗0'
  ✗ 34b⑨ 旧持有者（没有 expected）→ 上限仍是 TEAM_SMOKE_LOCK_WAIT（期望 [1800]，实际 [1801]）
$ grep -a '选段结果' /var/tmp/p329-redA-34b.log
== 选段结果 ==  ✓ 97  ✗ 1
$ git checkout HEAD -- skills/teamsmith/scripts/lib/gate-lock.sh && git status --short
（空）
```

### 2 · 「席位推导只有一份」（同一条断言的反面：两边各走各的）

```console
$ python3 - <<'PY'                      # 共享调用换回自带实现，并漏掉「主检出 = pm」这条规则
... -  n="$(team_seat_from_paths "$top" "$main" "$wtr" "$roster")"
... +  case "$wtr" in /*) ;; *) wtr="$main/$wtr" ;; esac
... +  case "$top" in "$wtr"/*) n="${top#"$wtr"/}"; n="${n%%/*}" ;; *) printf '?\n'; return 0 ;; esac
$ bash skills/teamsmith/tests/smoke.sh --select 34b > /var/tmp/p329-redB-34b.log 2>&1; echo rc=$?
rc=1
$ grep -a '✗' /var/tmp/p329-redB-34b.log | grep -v '✗0'
  ✗ 34b⑨ 同一推导：主检出上两边都是 pm（期望 [pm|pm]，实际 [?|pm]）
$ grep -a '选段结果' /var/tmp/p329-redB-34b.log
== 选段结果 ==  ✓ 97  ✗ 1
$ git checkout HEAD -- skills/teamsmith/scripts/lib/gate-lock.sh && git status --short
（空）
```

### 3 · 那句「expected/bound 为 0/0」是怎么被测出来的

```console
$ bash -c '. skills/teamsmith/scripts/lib/gate-lock.sh; gate_lock_expected skills/teamsmith/tests/smoke.sh /dev/null'
0	121500	135
```

`/dev/null` 当预算表是**可读**的，于是 135 个段全部按 900 s 默认值累加 → `bound=121500`；`expected=0`
（预算表里一条记录也没有）。原注释两半里有一半是假话，新注释写的是真的那一半：`expected=0`，
clamp 从下限退出 → cap 退回 `W`。

## 静态收口（实跑）

```console
$ openspec validate --all --strict
bash: line 1: openspec: command not found                      # 见「发现 2」
$ bash -lc 'command -v openspec'                               # 登录 shell 里同样为空
（空）
$ $HOME/.bun/bin/openspec validate --all --strict | tail -1
Totals: 21 passed, 0 failed (21 items)                          # rc=0
$ bash skills/teamsmith/tests/section-select.sh --check | tail -2
SKIP（条件不满足）: 行 19 的字面模式在检出里不存在（检出形状 internal，机器生成面（工具在本机生成、不进仓库））：.pi/skills
== 选段自检 ==  ok 9  bad 0  SKIP 1
$ git diff --check && echo "diff-check ok"
diff-check ok
```

## 选段：跑了什么、没跑什么

| 命令 | 结果 |
|---|---|
| `--select 34,34b,58`（验收选集） | **✓144 ✗0**，rc=0——§34 ✓35、§34b ✓75、§58 ✓11 |
| `--select 47`（notify 的发送者身份，直调被合并的那一侧） | ✓103 ✗0，rc=0 |
| `--paths smoke.sh gate-lock.sh common.sh`（选择器给这棵树算出的 RUN 集：53 段 / 2243 断言） | ✓2243 **✗7**，rc=1（3 条 §0e 改前就有 + 4 条 §36 的同一个根因） |
| `--select 34b,36`（补完路径声明后的复跑） | ✓218 **✗1**，rc=1——红的是既有不稳定断言 §34b⑫（见发现 6）；§36 全绿（含 36① / 36⑧） |
| `--select 0e`（只为核对删掉 `smoke.sh` 行之后循环清单还配不配平） | ✓42 ✗3，rc=1——与改前树**同一条**红 |

**没跑**：整套门禁（`--paths` 那次排除了 81 个键，例如 §26 面板、§38、§60 …）。交付/复验仍跑整套；这里按
「按改动选段」的规矩只跑了选择器算出的集合。

## 发现（每条都改变了什么）

1. **任务书第 1 条验收命令语法无效**：`bash skills/teamsmith/tests/smoke.sh --select 34 34b 58` 实测
   `smoke: 未知参数 34b（用法：smoke.sh … --select <key>[,<key>…] …）`，rc=2（`--select` 只收一个逗号分隔的
   参数）。**改变**了下一步：PM 复验用 `--select 34,34b,58`（本报告所有绿/红都出自这一形式）。
2. **`openspec` 不在这台机器的 PATH 上**：`openspec validate --all --strict` → `command not found`，
   `bash -lc 'command -v openspec'` 同样为空；真实入口是 `$HOME/.bun/bin/openspec`（软链到包内 bin）。
   **改变**了验收命令：本报告与后续复验都用全路径，21 passed / 0 failed 是全路径那次的结果。
3. **`--paths` 7 红里的 3 条是 main 上改前就有的 §0e 红**：`bad: smoke.sh:6392 的 while 行与清单第 30 行的
   锚点不符`（清单还写着 `while [ "$R_WAIT" -lt 1500 ] && ! $TEAM roster … | grep -qF "pi 已退出"` 这个形状，
   源码已是 P326 落地的 `while [ "$R_WAIT" -lt "$R_MAX" ]`）。在同一棵改前树（`33d83df0~1` 的 `tests/` 归档）上
   跑 `section-guard.sh --loop-check`：同样**恰好一条** `bad`，同一行。**改变**了结论：这不是 P329 造成的，
   §0e 与清单我都没动 —— 请 PM 立单。（清单的行号列本来就旧了：改前 16977 对源码 17041；我这次删除让它再偏
   22 行，但那一列不参与判定，判定看顺序 / 锚点 / 上限字面量。）
4. **§36① 抓住我自己的漏声明**：§34b⑨ 的 notify 侧夹具 `source`s `common.sh`，而 §34b 那行的 patterns 里没有
   它 —— `bad: 段 34b 读了它没声明的路径：token skills/teamsmith/scripts/lib/common.sh（源码行 16752）`
   （§36 的 5 条红全出自这一个根因）。**改变**了交付物：`2a47156d` 把 `common.sh` 补进该行，并把「9 条真实
   路径 token」这句会漂的数字换成「它读到的每条」。这条守卫在这里是有效的。
5. **同一套推导还有第三份（TypeScript）**：`skills/teamsmith/extension/team-notify.ts:287,415-438` 也用
   `<root>/<worktrees>/<一级目录名>` 推席位（名册优先），但**故意不产出 pm**（主工作树 / PM 会话不触发，
   改为跳过）。它不在任务书点名的两份里，也跨语言，所以这次不动；记在这里是因为「只有两份」这个前提不完整。
   **改变**了下一轮清点的口径，没改变本次交付。
6. **§34b⑫「登记随它退出消失」是既有不稳定断言**：同一棵树上本轮红、前两轮绿（`--select 34,34b,58` 里
   §34b ✓75，`--paths` 里 §34b ✓75 ✗0 / 28 s），而这次那一轮 §34b 跑了 336 s（机器被别的门禁占着）。
   同一行的历史：`docs/team/reports/P288-dev-bob.md:411`、`P313-dev3.md:240`、`P316-dev.md:137`
   （「第一轮 ✗、本轮 ✓（同一棵树、没改它）—— 是**不稳定**的既有断言」）、`V53.md:566`、`V57.md:256`。
   **改变**了下一步：它该有自己的处理（改动等待窗口或删掉它），不该被当成谁的红 —— 请 PM 立单或并入
   `gate-waiter-patience`。

## Deviations

- 验收第 1 条按正确语法跑（发现 1）、第 2 条按全路径跑（发现 2）—— 两处都是命令行形式问题，命令**用法**没变。
- 多改了一个文件 `skills/teamsmith/tests/section-paths.tsv`（一行），因为 §36① 点名我漏声明路径（发现 4）；
  它声明的是我这次要改的段，改的是声明而非行为。
- §0e（发现 3）与 §34b⑫（发现 6）的红都没修：前者不在任务书写集内且与本改动无关，后者是既有不稳定断言，
  修它不是减法任务的范围。
