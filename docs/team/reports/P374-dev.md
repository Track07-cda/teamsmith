# P374 · `§34d 2.1` 伴生锁夹具：私有锁下不再假红，默认锁名在普通跑法里真的被断言

agent: dev   status: 交付（等独立复验）   time: 2026-10-26T03:02Z
branch: `task/P374-34d-lock-shape`（local 模式，未 push）   PR/MR: -
写集：`skills/teamsmith/tests/smoke.sh`（`§34d 2.1` 那一块）、本报告与其证据包。产品 `gate-lock.sh` 一个字节没动。

## 结论（先看这里）

**两件事都成立，而且是实测出来的，不是推断的。**

1. **V103 的假红修好了**：`§34d 2.1` 的期望值不再写死 `.teamsmith-smoke.lock.machine`，而是从**同一输入**
   （`gate_lock_default_path` 在本次运行里的返回值）按真实规则派生。私有锁 `7-1.lock` 下这一跑是 **✓134 ✗0、
   rc=0**（V103 那次是 `✓390 ✗1`，唯一的红就在这条）。
2. **V105 的 F1（字面量断言不可达）修好了**：默认锁名 `<TMPDIR>/teamsmith-smoke.lock` 及其伴生锁现在由
   **显式 `unset TEAM_SMOKE_LOCK` 的子 shell**重新问一次产品函数来断言，**不依赖调用者是否设了那个变量**。
   在**普通跑法**（调用者未设 `TEAM_SMOKE_LOCK`，`p374-ord` 的 meta 记的就是 `<unset>`）里这两条断言真的执行了：

   ```
   ✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认发布路径的名字是 teamsmith-smoke.lock
   ✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine
   ```

   它们不是恒真：把默认名改成 `teamsmith-smoke2.lock` 的私有克隆里，这两条立刻变红并点名不匹配（§4 的 M0）。
3. 先前那个「未设默认路径」分支（`assert_eq` 比同一个函数调用两次 / 否则只印一句 `ok`）换成一条**真断言**：
   本次运行的发布路径必须等于 `TEAM_SMOKE_LOCK`，外面没给就是刚算出的默认值。它在「`gate_lock_default_path`
   忽略环境」的变异下变红并点名（§4 的 M1）。

## 1 · 病根与两次定性

**V103 的假红**（`docs/team/reports/V103-dev3.md` §1）：席位用私有 `TEAM_SMOKE_LOCK=/…/7-1.lock` 跑
`--select 34,34b,34d,36`，`§34d 2.1` 报 `期望 […/.teamsmith-smoke.lock.machine]，实际 […/.7-1.lock.machine]`。
推导本身是对的——夹具的**上一行**已经明确「外层设了 `TEAM_SMOKE_LOCK` 就换输入」，下一行却把默认名当字面量，
自相矛盾。同一份夹具在默认输入下是绿的，所以红只跟私有输入有关。

**V105 的 PARTIAL**（`docs/team/reports/V105-verify.md` §1.4、§2 F1）：第一版候选 `f62c14fc` 把期望值改成派生值，
但把默认名字面量留在 `if [ -z "${TEAM_SMOKE_LOCK:-}" ]` 里。`smoke.sh` 在起子套件前就
`export TEAM_SMOKE_LOCK="$SMOKE_LOCK"`（发布路径解析结果），所以**普通跑法一定落 else 分支**，那条断言从不执行；
后果精确——默认名被改掉时，派生断言跟着一起变，于是绿。V105 同时确认第一版的形状断言可被两种变异打红（缺前导点、
伴生锁搬到临时根），那两部分本次一字未动，并在 §4 用同一变异复验。

## 2 · 改了什么（一处）

`skills/teamsmith/tests/smoke.sh` 的 `§34d 2.1` 块（提交 `7ce7fec5`）：
删掉环境条件分支与 `if [ -z "${TEAM_SMOKE_LOCK:-}" ]` 里的字面量断言，改为

```
P287D_DEF="$(gate_lock_default_path)"                        # 本次运行的发布路径
P287D_DEF_DEFAULT="$(unset TEAM_SMOKE_LOCK; gate_lock_default_path)"   # 显式问一次默认名
assert_eq … "$(basename "$P287D_DEF_DEFAULT")" "teamsmith-smoke.lock"          # ① 默认名的 basename
assert_eq … "$(gate_lock_companion_path "$P287D_DEF_DEFAULT")" \
            "$(dirname "$P287D_DEF_DEFAULT")/.teamsmith-smoke.lock.machine"    # ② 默认名的伴生锁
assert_eq … "$P287D_DEF" "${TEAM_SMOKE_LOCK:-$P287D_DEF_DEFAULT}"              # ③ 发布路径与运行一致
```

后面「同目录 / 点 + basename + `.machine`」两条派生形状断言保持第一版的做法（P374 原修法），私有锁那三条
（`priv.lock`、`/x/y.lock`）也一字未动。① ② ③ 与派生断言的关系：① ② 钉常量，派生断言钉规则，③ 钉「这次跑的
就是环境里那把」。

`§34d` 的断言条数因此从 131（`main` `e1111a27`）→ 132（第一版 `f62c14fc`）→ **134**（本 tip），差额分别是
第一版新增的派生断言（普通跑法 1 条）与本次把条件分支换成无条件三条（+2）。

## 3 · 验收读数：两种输入各一轮完整 `--select 34d`

两轮都在本工作树、**交付 tip `7d2d561b`**、私有 `TMPDIR`；开跑前后 `git status --porcelain --untracked-files=all` 都是 0 行，
日志里没有「本次运行无效」（exit 4），所以读数算数。

```
$ TMPDIR=~/.cache/p374/tmp/ord2 bash skills/teamsmith/tests/smoke.sh --select 34d        # 未设 TEAM_SMOKE_LOCK
== 选段结果 ==  ✓ 134  ✗ 0        exit=0  用时 165s   （logs/p374-ord2.{log,meta} · meta: TEAM_SMOKE_LOCK=<unset>）
$ TMPDIR=~/.cache/p374/tmp/priv2 TEAM_SMOKE_LOCK=~/.cache/p374/locks2/7-1.lock \
  bash skills/teamsmith/tests/smoke.sh --select 34d                                     # V103 那把私有锁
== 选段结果 ==  ✓ 134  ✗ 0        exit=0  用时 165s   （logs/p374-priv2.{log,meta}）
#5 34d · 身份面… · 用时 160s · ✓110 ✗0 SKIP0 · ticks 110      （两轮相同；`main` 上是 ✓108）
```

合并 `main` 之前，同一提交内容（`7ce7fec5`）也跑过同样两轮，读数一致：`✓134 ✗0`、`exit=0`、194 s / 195 s、
`git_status` 起止均为 0（`logs/p374-ord.*`、`logs/p374-priv.*`）。交付 tip 与那次相比，`smoke.sh` 逐字节相同
（`git diff 7ce7fec5 7d2d561b -- skills/teamsmith/tests/smoke.sh` 为空），差异只来自 `main` 的 13 个提交（文档/openspec 归档）。

两轮的 `§34d 2.1` 八条全绿（`p374-ord2` 原文）：

```
✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认发布路径的名字是 teamsmith-smoke.lock
✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine
✓ 34d 2.1 本次发布路径 = TEAM_SMOKE_LOCK（外面没给就是刚算出的默认值）
✓ 34d 2.1 发布路径 → 伴生锁同目录（同行同目录，不跟着临时根搬）
✓ 34d 2.1 发布路径 → 伴生锁名 = 点 + basename(发布路径) + .machine
✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 默认路径取它
✓ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
✓ 34d 2.1 伴生锁名点开头（事故那条平铺 glob 够不着）
```

私有一轮的期望/实际都落在 `7-1.lock` 上（`.7-1.lock.machine`，单一前导点），没有再出现 V103 那种把默认名
写进期望值的红。本轮**没有**用 `TEAM_SMOKE_NO_LOCK=1` 证明可达性：普通跑法本身就是证据。

## 4 · 翻转证据（红侧 → 还原后绿）

全部在**私有克隆** `~/.cache/p374/mut` 里做（`git clone` 自己的仓，`git rev-parse --show-toplevel` 断言等于它自己）；
每条路径写前都断言落在克隆里，写完 `git checkout --` 还原并核对 `git status` 为空。真实产品文件与候选从未被改动。
变异跑按设计在 120 s 截断（`exit=124` 不是判定），只读 `§34d 2.1` 那一段。克隆 HEAD 是 `7ce7fec5`，其
`smoke.sh` 与交付 tip 逐字节相同（见 §3）。

**M0 · 默认锁名改掉（普通跑法，调用者未设 `TEAM_SMOKE_LOCK`）** — 期望本例被红：

```
✗ 34d 2.1 未设 TEAM_SMOKE_LOCK → 默认发布路径的名字是 teamsmith-smoke.lock
  （期望 [teamsmith-smoke.lock]，实际 [teamsmith-smoke2.lock]）
✗ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine
  （期望 […/tmp/M0/.teamsmith-smoke.lock.machine]，实际 […/tmp/M0/.teamsmith-smoke2.lock.machine]）
✓ 34d 2.1 本次发布路径 = TEAM_SMOKE_LOCK（外面没给就是刚算出的默认值）
```

V105 F1 指出的正是「默认名被改掉时仍然绿」，这两条现在红得指名道姓；同一跑里 ③ 与派生断言照旧绿，说明打中的是
常量那两条，不是把整块打糊。

**M1 · `gate_lock_default_path` 忽略 `TEAM_SMOKE_LOCK`（私有锁输入）** — 为证明 ③ 不是恒真：

```
✗ 34d 2.1 本次发布路径 = TEAM_SMOKE_LOCK（外面没给就是刚算出的默认值）
  （期望 […/M1-locks/7-1.lock]，实际 […/M1/teamsmith-smoke.lock]）
✗ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 默认路径取它（同一期望/实际）
✓ 34d 2.1 未设 TEAM_SMOKE_LOCK → …（两条常量断言照旧绿，因为默认名没变）
```

③ 打的是「这次跑的就是环境里那把」这一层，常量那两条在这一变异下不该动——两者覆盖不同的事。

**MA · 伴生锁去掉前导点（私有锁输入）**（V105 mutA 原样保留）：

```
✗ 34d 2.1 未设 TEAM_SMOKE_LOCK → 伴生锁就是同目录的 .teamsmith-smoke.lock.machine
  （期望 […/.teamsmith-smoke.lock.machine]，实际 […/teamsmith-smoke.lock.machine]）
✗ 34d 2.1 伴生锁名不是「点开头 + .machine 结尾」：…/tmp/MA-locks/7-1.lock.machine
✗ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
✗ 34d 2.1 伴生锁名不是点开头：/x/y.lock.machine
```

**MB · 伴生锁搬到临时根（私有锁输入）**（V105 mutB 原样保留）：

```
✗ 34d 2.1 发布路径 → 伴生锁同目录（同行同目录，不跟着临时根搬）
  （期望 […/tmp/MB-locks]，实际 […/tmp/MB]）
✗ 34d 2.1 私有 TEAM_SMOKE_LOCK 形状 → 伴生锁推导
  （期望 […/p287-id/.priv.lock.machine]，实际 […/MB/.priv.lock.machine]）
```

**R · 还原后同一私有输入** — 八条全绿，克隆与 HEAD 逐字节一致：

```
✓ ×8（同上 §3 那张表），clone matches HEAD (7ce7fec55f37ce794eb0b6f2c964b4031417c47f)，dirty files: 0
```

| 变异 | 输入 | 打红的 2.1 断言 | 还原后 |
|---|---|---|---|
| M0 默认名 → `teamsmith-smoke2.lock` | 未设（普通跑法） | 两条默认名字面量断言 | 克隆干净（`dirty=0`） |
| M1 默认路径忽略 `TEAM_SMOKE_LOCK` | 私有 `7-1.lock` | ③ 与私有输入那条 | 同上 |
| MA 伴生锁无前导点 | 私有 `7-1.lock` | 默认伴生锁 + 两条形状 | 同上 |
| MB 伴生锁搬到临时根 | 私有 `7-1.lock` | 同目录那条 + 私有推导 | 同上 |

## 5 · 静态检查

```
$ bash -n skills/teamsmith/tests/smoke.sh                      → rc=0
$ git diff --check                                             → rc=0（工作树干净）
$ bash skills/teamsmith/tests/section-select.sh --check
== 选段自检 ==  ok 12  bad 0  SKIP 1                           → rc=0
```

那条 `SKIP` 是既有条目、与本次改动无关（V105 的读数里同样是 1 条）。未跑整套、未进容器：本次只动 `§34d 2.1`
这一个纯函数块，`--select 34d` 是直接覆盖它的段。

账本红线（在本工作树、本分支的树上跑）：

```
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=…/.worktrees/dev scope=published files=2178 hits=0 names=ok user=resolved
$ echo $?
0
```

本分支基底原来落后 `main` 13 个提交，那条命中来自 `docs/team/reviews/gate-waiter-patience.md` 的裸 home 路径
（`main` 的 `3fe83fe5` 已修）；merge 之后本树 `hits=0`，见 §8。

## 6 · 证据包（在检出里，按 `.gitignore` 不入库）

`docs/team/reports/P374-dev/`：`run.sh`（单轮运行 + meta）、`mutate.sh`（M0/MA/MB/R）、`mutate2.sh`（M1）、
`logs/`（`p374-ord{,2}`、`p374-priv{,2}`、`M0`、`M1`、`MA`、`MB`、`R` 的 `.log` + `.meta` + `.diff`）。
复现：给出私有 `TMPDIR` 后 `bash run.sh <repo> <label> <tmpdir> [<lock>] 34d`；仓库外的原始副本在 `~/.cache/p374/`。

## 7 · 边界

- 产品 `skills/teamsmith/scripts/lib/gate-lock.sh` 未改（推导本来是对的），未加段、未改 `§34d` 之外的任何断言。
- 未跑整套门禁、未进容器、未跑 34d 的场景 ①②③④⑤（只改纯函数块，场景夹具未触及）。
- V105 报告里提到的「第一次变异误改了工作树」这次不会重演：变异脚本每条写路径都断言等于克隆内绝对路径。

## 8 · 决定与偏差

- 断言标签从「默认路径 → …」改成「发布路径 → …」：`TEAM_SMOKE_LOCK` 设了时它不是默认路径，旧标签容易误导。
  被变异打红的那两条因此与 V105 报告的字面不同（语义相同，§4 的原文可对照）。
- 新增第三条断言（发布路径 = `TEAM_SMOKE_LOCK`）是为了满足「先前那个分支要成为真断言」：原来那条比较两次同一个
  函数调用，恒真。它带来的冗余（与「私有…默认路径取它」部分重叠）在 §4 的 M1 里被证明是不同层面的覆盖。
- 变异在 `git clone` 出来的克隆里做（不是 `cp -a` 工作树）：克隆的 `.git` 指向自己，`git status` 与运行指纹
  都只反映克隆，减少误改真实工作树的可能。
- 交付前把 `main`（13 个提交）正常 merge 进本分支（`7d2d561b`，无冲突，`smoke.sh` 未变）：本分支原来的基底上，
  `docs/team/reviews/gate-waiter-patience.md` 还带着一条裸 home 路径，于是本地 ledger-ban 报 `hits=1`；`main` 的
  `3fe83fe5` 已改成 `$HOME/…`，merge 后本树 `hits=0`。不 merge 也能合入（PM 走 squash，只落我的 diff），但那样
  复验会在一个已知会红的账本上跑，不值得。

## 9 · 给 PM 的下一步

- 独立复验建议：`--select 34d` 各跑一次（普通 + 私有锁 `7-1.lock`），并抽一条变异自跑（M0 最省时）。
  本任务只改了夹具，合入后 `§34d` 的其它场景不受影响。
