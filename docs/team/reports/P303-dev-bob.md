# P303 · 按事实勾 `gate-lock-external-deletion` 的清单（作者自查侧）

agent: dev-bob   status: DONE   time: 2026-10-16T10:45Z
branch: `task/P303-gate-lock-checklist`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）
phase: apply   change: `gate-lock-external-deletion`

## 结论（先读这段）

- **31 个 apply 格：23 格按事实勾**（每格在 `tasks.md` 里带上证据：P288 报告小节 / 落地提交 / P303 实测命令与 rc），
  **8 格留空**：`1.1`、`2.1`、`2.4`、`4.1`、`5.2`、`5.3`、`7.1`、`7.2` —— 逐条原因见 §留空项（每格都写了
  「什么在场 / 什么不在场 / 补什么才算数」）。§8 的三格是复验侧的，按任务书留空。
- **F1 是这次复跑才露出来的真东西**：`bash skills/teamsmith/tests/flip-p287-lock.sh --self-test` 在**并入 main 的树**上
  rc=1 —— 它的 leg2「改动前的树」永远选中 `main`（也就是含变更的树），因为探测写成
  `git show … | grep -q …` 而脚本 `set -o pipefail`：`grep -q` 命中即退，`git show` 吃 SIGPIPE 返回 141，
  管道整体非 0，「不含伴生锁」被误判为真（实测 rc=141，300/300；首次命中在第 5440 / 全部 30752 字节）。
  `flip-m33.sh:106` 的注释**点名过这个坑**，本变更的新夹具又踩了一次；合并前它绿，只因为那时 `main` 本来就不含变更
  —— 这条腿从来没真的「往回找」过。它不在门禁里（没有任何 section 跑这两条夹具），所以 main 的门禁仍全绿，
  红的是**变更自己的验收清单**（proposal Acceptance 第 5 行）。详见 §F1。
- 其余复跑全绿：`--select 34c,34d` ✓142 ✗0、`--select 34,34b` ✓158 ✗0、`--select 0e` ✓44 ✗0、
  `flip-p287-name.sh --self-test` FLIP 全绿、`tmp-hygiene.sh --self-test` ✓73 ✗0、`--lint` 32 模板、
  `section-select/section-guard/gate-guard` 全过、`openspec validate --all --strict` 22/0、`ledger-ban` hits=0。

## 交付物（只动两处）

| Path | What |
|---|---|
| `openspec/changes/gate-lock-external-deletion/tasks.md` | 23 格勾 + 每格证据（原文一字未动，只把每格末尾的 `· 证据：（待填…）` 换成 `· 证据：P303 按事实勾：…`；留空的 8 格原样） |
| `docs/team/reports/P303-dev-bob.md` | 本报告（含 0.3 的补测与 F1） |

产品 / 测试 / 规格一个字未动：`git diff --stat` 只含这两份文件。**F1 只报不改** —— 修它要在
`tests/flip-p287-lock.sh` 里动手，而本任务的写集只允许上面两份。

## 验收命令（任务书的三条）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
✓ change/gate-lock-external-deletion
Totals: 22 passed, 0 failed (22 items)          rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<worktree> scope=published files=1708 hits=0 names=ok user=resolved   rc=0

$ git diff --check && git status --short
（空）                                            rc=0
```

（三条都在**本分支的树**上跑，最后一次在写完全部改动之后，因此 `files=1708` 已含本报告。）。

## 逐条勾的账（23 条）

每格的完整证据在 `tasks.md` 里；这里是它们各自压在哪件实物上：

| 格 | 压在哪件实物上 |
|---|---|
| 0.1 | 复核记录 D1–D7 全按推荐（无改判 ⇒ 无重写）+ P288 报告 §0.1 的落点表逐条核到实物 |
| 0.2 | 独立树投影 rc=0（validate 22/0 → archive → 21/0）；三条 MODIFIED 场景数 4→6 / 5→5 / 2→3、既有场景标题零丢失；ADDED 标题 + 六场景齐全 |
| 0.3 | P288 报告 §0.3 的四项基线 + P303 在改动前提交 `b77af9e1` 上补测的用时与 design §1.2–1.4 复跑（§基线补测） |
| 1.2 | `tmp-root.sh` 的模板/标记/台账/`tmp_root_path_ok` + 自检 ✓19 ✗0，两条 `--break` 各 ✓17 ✗2 rc=1 |
| 1.3 | 六个产品模板逐个在场（`cmd-review`×2 / `common` / `cmd-watch` / `panel-cpu` / `panel-knobs`）+ `--lint` 32 模板 rc=0 |
| 1.4 | `smoke.sh:216`/`:595` 的每运行标记 + `flip-m33:128`/`flip-p158:138` 两处匹配器认两种形状 |
| 1.5 | 34c 段 20 条断言（含 `--break=flat-name` 红侧那一对），P303 复跑 34c ✓20 ✗0 |
| 1.6 | 34c④ 的 ns 三向关系与 `--status` 外来归因，P303 复跑同一段 |
| 2.2 | `gate_lock_acquire_pair` 的顺序 + no-unlink + 34d④/⑥ 的反侧断言，P303 复跑 34d ✓101 ✗0 |
| 2.3 | `cmd-review.sh` 走同一套 + 34d⑦ 真跑 `team review` + `flip-p287-lock` leg3 的变异红侧 |
| 2.5 | 两条可区分文案（`:1176` / `:1146–1149`）+ 34d⑤b（只印不停、有结果行）与 34d①（停跑） |
| 3.1 | 记录末两字段 + `gate_lock_claim_identity` 的 fd 优先/`path` 兜底 + 34d⑥ 的断言 |
| 3.2 | 同一个 0.2s 哨兵、同一条停跑路径（`KEEP=1` + exit 2）、同一份 `$TMP` 之外的诊断（七个字段齐）；真事原文见 V53 §1.3 |
| 3.3 | 34d① 绿侧 + `--break=no-lock-guard` shadow + `flip-p287-lock` leg0/leg1（P303 复跑各自全绿） |
| 3.4 | 34d② 的 `rm`+新建 / `mv` 覆盖两种形状 + 两条 shadow，P303 复跑 34d 全绿 |
| 3.5 | 34d④ 两套顺序运行：无身份行、结果行与 rc 照旧、伴生锁 inode 不变、发布路径仍在 |
| 4.2 | 入场检查（身份不同 ⇒ 点名 + 不跑 + exit 2）+ 34d③ 绿/shadow；marker 由构造保证不在（写在检查之后） |
| 4.3 | `gate_lock_describe_one` 的 `?` + 34d⑤ 的 `version=legacy` 现场 + 34b② 同形 |
| 5.1 | `--lint` 的规则/作用域 + 三条红侧素材 + P303 复跑 32 模板/`--self-test` 全绿 |
| 6.1 | P288 报告 §Flip evidence + §0.2 六场景表 + P303 的闭包复跑（leg2 例外，见 §F1） |
| 6.2 | P303 的 34/34b 断言标签集合对照（既有 180 条里只有 5 条机械改写、无一条消失）+ 改动前 ✓153 ✗1 对照 ✓158 ✗0 |
| 6.3 | 两张 tsv 的 34c/34d 行 + P303 复跑的 `--select 0e` ✓44 ✗0 与三条静态检查 |
| 7.3 | 分支提交的 Conventional + `Agent: dev-bob` trailer（四个提交号）+ local 模式 + PM 的冻结/派 V53/落地 |

## 留空项与原因（8 条）

**1.1 · `team_project_ns` 的三向断言。** 在场：函数本体（`common.sh:83`，纯函数、slug `[A-Za-z0-9_]` 截 24、
hash8 取主检出 realpath、git 不可用退到 skill 仓库根）；34c④ 断言了「两个 worktree 同 ns」「第二个仓库不同 ns」两向。
不在场：**第三向「无 git 的检出不报错」没有任何断言**（全树 grep 不到该形状的用例）。我另做了手工探针（不是断言）：
把 `common.sh` 拷进非 git 目录后 `team_project_ns` 返回 `nogit-9fb7b834`（rc=0），PATH 里没有 git+sha256 工具时返回
`pm_skills-00000000`（rc=0，不报错）—— **行为成立，缺的是把它钉住的断言**。

**2.1 · 伴生路径推导的纯函数单测。** 在场：`gate_lock_companion_path`（`gate-lock.sh:88`，同行同目录、`.machine`、点开头）
被产品三处（`cmd-review`/`perf`/`tmp-hygiene`）与两处夹具调用。不在场：**任务书点名的那条「纯函数单测」**
（默认路径与私有 `TEAM_SMOKE_LOCK` 两种输入各断言推导结果）全树不存在；现有的只是间接覆盖
（`tmp-hygiene --status` 自检断言默认路径下三种角色的标签、34d⑥ 用私有锁跑出的持有者记录落在夹具按同一公式算出的路径上）。

**2.4 · 取锁时刷 mtime 的断言。** 在场：三处都真的刷了 `touch "$lock" "$comp"`（`smoke.sh:565`、`perf.sh:221`、
`cmd-review.sh:1154`，注释写明 P255 §1.6）。不在场：**任务书点名的断言 `mtime >= claimed`** —— 全树没有一处比较锁的
mtime 与取锁时刻（34d④ 只断言 inode 前后相同），报告与证据里也没有 `stat -c %Y` 的改动前后输出。

**4.1 · 等待者的「一字不改」与逐字 diff。** 在场（P303 实测）：上限算式本体 `gate_lock_cap` 逐字节相同
（`diff` 两个版本的函数体为空）；排队行与超限行两条 `printf` 文本逐字相同；超限仍 `exit 2`；queue marker 仍是
`<epoch> <pid>`（P66 的「真的跑起来了」）。**不在场**：P281 的**加锁失败文案**已随机制一起消失 ——
改动前的 `排队/加锁失败：flock 没能把本套跑起来（%s，rc=%s…）`（旧 smoke.sh:453）与 `注意：flock 探锁失败（rc=%s）→…`
（:407）在落地形状里都不存在（`flock --close -w` 包装器换成了进程内 fd + 有界轮询），落地树甚至把前者当成
「不许出现」来断言（34b④ `assert_not`）。任务书要求的是「超限/加锁失败的文案与退出码一字不改（逐字对照 diff）」——
超限那一半成立，加锁失败那一半按字面不成立；而**这条逐字 diff 从未作为证据产出过**（P288 报告与 V53 都没有）。
由 PM 裁定：把两条防御性文案的消失算作机制改写的必然（准入条件 4 只冻结「上限算式 / token 闭集 / 退出码集合 /
`team_review_verdict`」）还是要求补回一条等价文案。

**5.2 · `--status` 的 `legacy` 标注。** 在场：ns 列（`--status` 在根的归属行里报 `ns=`）、锁对三角色
（`[machine 运行互斥]` / `[published 兼容声明]` / `[records 运行注册]`）、`--sweep` 对这三样一个都不碰
（候选只认家族里的非点开头**目录**；自检 ⑥ 用 `--flip=lock` 证明这条规则有牙）。**不在场**：design「迁移」一节
写的「`--status` 把历史平铺根标 `legacy`」——`tmp-hygiene.sh` 全树没有 `legacy` 这个标记（`grep -i legacy` 零命中）。

**5.3 · §9b-2 的段落。** 在场：两把锁的角色与顺序、no-unlink 纪律、过渡期口径（旧写入者只经发布路径串行、它被删时
只印不停）、以及运维清理入口（`tmp-hygiene.sh --status` → `--sweep`，并写明「门禁自己从不 sweep」）。
**不在场/不准确**：同一节里**还留着改动前的根模板** —— `protocol.md:798` 写
``${TMPDIR:-/tmp}/teamsmith-<kind>.XXXXXX``（本变更的合同已改成 `teamsmith-<kind>-<ns>.XXXXXX`），
`:786` 也还写性能锁的记录在 `<lock>.holder`（落地是 `<companion>.holder`）；「只删自己项目的
`teamsmith-<kind>-<ns>.*`」这条替代口径没有写。改这两句在同一节的授权写集内，但本次没做。

**7.1 · 跑齐 proposal Acceptance 的全部命令。** 在场：P288 报告 §Verification evidence 表把任务书的验收行逐条跑过并贴了
rc（当时全绿）；P303 在交付树上重跑了同一批。**不在场**：这一批在**并入 main 的树上已经不全绿** ——
`flip-p287-lock.sh --self-test` rc=1（§F1）。也就是说「跑齐 + 贴输出」这件事做了，但**验收清单在落地状态上不成立**；
等 F1 处置（修夹具或改验收行）之后再勾。

**7.2 · 报告里的「诚实边界」清单。** 在场：报告有逐条命令/rc/输出尾、§6.1 对应的 §Flip evidence 一节、以及
「未跑的东西（诚实边界）」一节。**不在场**：任务书点名的 design §10 **那八条**（无不可删的锁、`source=path` 的窗口、
升级过渡期、`TMPDIR` 覆盖的残留、守卫不能证明是谁换的/有人读过那行、容器临时根、无 git 检出的 ns 各自为政、
历史平铺残留不清理）—— P288 报告只写了第 8 条（历史残留）；其余七条在 design 里有，报告里没有。

## F1 · `flip-p287-lock.sh` 的 leg2 在合并后的树上必红（新发现）

**现象**（P303 在交付树 `e8519861` 上跑，`--self-test`，私有锁/私有 TMPDIR）：

```
== leg2 pre：改动前的树上做同一件事（那时没有伴生锁）→ 同样不点名、不停跑 ==
  ✓ leg2：改动前的树取自 main（85732fa7 docs(team): pending ledger records [skip ci]）
  ✗ leg2：改动前的树上也点名了（那时没有伴生锁，应当是静默的）
  ✗ leg2：改动前的树没有结果行（…/leg2.log）
FLIP 有未达预期的腿        rc=1
```

被选中的「改动前的树」就是**当时 main 的 tip 本身**（证据路径里那一跑用的是
`teamsmith-smoke-pre_tree-…`，日志里 `持有 …teamsmith-smoke.lock（互斥在伴生锁 …/.teamsmith-smoke.lock.machine）`
—— 那是**含变更的树**），所以它当然会点名并停跑。

**机制**（P303 探针，同一棵树）：

```
$ set -uo pipefail; git -C . show main:skills/teamsmith/scripts/lib/gate-lock.sh 2>/dev/null | grep -q 'gate_lock_companion_path'; echo rc=$?
rc=141                     # grep -q 命中即退 → git show 吃 SIGPIPE → 管道 141
$ set +o pipefail; 同一管道 → rc=0
$ git show … | grep -c … → rc=0      # 读完整流就没事
$ 首次命中在第 5440 字节 / 全文件 30752 字节
300/300 次循环都返回非 0（不是偶发）
```

夹具的选树循环是 `if ! git show "$rev:…" | grep -q 'gate_lock_companion_path'; then PRE="$rev"; break; fi`
（`flip-p287-lock.sh:194`）——`set -uo pipefail` 之下那一步**永远**为真，于是 `i=0` 就选中 `main`，
`main~1…~25` 的回溯从未发生。**同族的坑在 `flip-m33.sh:106` 的注释里被点名过**：
「注意别写成 `git show … | grep -q` + `!`：set -o pipefail 下 grep -q 命中即退会让 git 吃 SIGPIPE，管道整体非 0，
取反后把**带哨兵**的那版当成「不含哨兵」——本夹具第一次跑就是这么自己骗自己的」；`flip-m33` 的写法是先把 blob 落盘再
`grep` 文件。

**为什么三方都没看见**：P288 交付与 V53 复验都在**合并之前**跑这条腿 —— 那时 `main` 本来就不含变更，
「误判成不含」正好选对了树，所以是绿的；合并之后同一个逻辑必然选错。它也不在门禁里：没有任何 section 跑
`flip-p287-*`（§34c/§34d 是它们各自的真入口场景），所以 main 的门禁照样全绿，红的是**变更自己验收清单里那一行**。

**影响**：① `proposal.md` 的 Acceptance 第 5 行在落地状态上 rc=1；② 任务书 §8.1 的复验清单没点名这条夹具，
V53 的「翻转夹具全绿」结论只对合并前的树成立；③ 六条 scenario 本身不受影响（它们的绿/shadow 在 34c/34d 段里，
P303 复跑全绿）。

**修法方向**（留给 PM 开单，本次没动手）：把选树探测换成 `flip-m33` 的写法（blob 落盘再 `grep`，或
`grep -c` 读完整流），或干脆用 `git log --format=%H -- <rel>` 往回找；顺手看 `flip-m44.sh:128`
（`head_has_markers` 是同一形状，同一 `pipefail`，实测同一表达式 rc=141 —— 不在本变更写集内，是否另开一单由 PM 定）。

## 0.3 的基线补测（改动前提交 `b77af9e1`，独立 clone）

P288 报告 §0.3 已冻结四项：`--select 34,34b` ✓153 ✗1（rc=1）、`tmp-hygiene.sh --lint` 检查了 15 个模板（rc=0）、
`ls -d "${TMPDIR:-/tmp}"/teamsmith-*` = 99、`review-*` = 1；两条红侧的改动前形状在该报告 §Flip evidence（leg2）。
报告里缺的两样（**用时**、design §1.2–1.4 的复跑）由 P303 补齐：

```
$ git -C /var/tmp/p303/pre log -1 --format=%h
b77af9e1                       # 改动前的 main（P288 落地提交 6f1ed69d 的父提交）
$ TMPDIR=/var/tmp/p303/pre-tmp TEAM_SMOKE_LOCK=/var/tmp/p303/pre-lock bash skills/teamsmith/tests/smoke.sh --select 34,34b
#5 34 · 门禁锁：排队/运行分开记账… · 用时 52s · ✓36 ✗0 SKIP0 · ticks 36
#6 34b · 门禁锁排队守卫… · 用时 59s · ✓97 ✗0 SKIP0 · ticks 97
账本自查： 6 段收口 · 增量 ✓154 ✗0 SKIP0 ｜ 结果行 ✓154 ✗0 —— 一致
== 选段结果 ==  ✓ 154  ✗ 0          rc=0（整条 121s）
$ bash skills/teamsmith/tests/tmp-hygiene.sh --lint
检查了 15 个 mktemp -d 根模板（…/pre/skills/teamsmith/tests）          rc=0
$ printf 'teamsmith-*: %s\nreview-*: %s\n' "$(ls -d "${TMPDIR:-/tmp}"/teamsmith-* 2>/dev/null | wc -l)" "$(ls -d "${TMPDIR:-/tmp}"/review-* 2>/dev/null | wc -l)"
teamsmith-*: 98
review-*: 1
```

（P288 报告 §0.3 冻的那次是 ✓153 ✗1 —— 那一条是 V53-F2 记过的既有计时 flake（34b⑫），机制在夹具侧、
改动前的 main 上也是时红时绿；这次没复现，所以基线的断言总数是 154。34b 的 97 → 101 正是本变更新增的 4 条。）

design §1.2/§1.3/§1.4 三条按原文复跑（私有目录，`/var/tmp/p303/exp*`）：

```
  HIT   teamsmith-smoke.EloKhO          # §1.2：事件那条 glob 的射程
  HIT   teamsmith-smoke.lock
  HIT   teamsmith-smoke.lock.holder
  miss  teamsmith-smoke-queue.AB12
  miss  .teamsmith-smoke-diag.1.log
  miss  teamsmith-select.1.sh
  miss  teamsmith-smoke-pm_skills-3f2a91c4.AB12CD
  miss  .teamsmith-smoke.lock.machine
  持有者 pid=… 握着 inode 77:235311886     # §1.3：删+重建 → 新 inode 上 flock -n 成功（静默分裂）
  外部删除后重建：路径现在指向 inode 77:235311887
  新运行 flock -n = 成功（两套「顶层」同时认为自己独占）
  删之后伴生锁仍在，inode 77:235311973     # §1.4：点开头不在那条 glob 的射程里
  第二把「锁」仍拿不到 = 互斥保持
```

## 复跑批（交付树 `e8519861`，私有外层锁 `/var/tmp/p303/machine.lock`）

| 命令 | rc | 读数 |
|---|---|---|
| `smoke.sh --select 34c,34d` | 0 | 34c ✓20 ✗0（22s）· 34d ✓101 ✗0（150s）· 合计 ✓142 ✗0 |
| `smoke.sh --select 34,34b` | 0 | 34 ✓36 ✗0（58s）· 34b ✓101 ✗0（65s）· 合计 ✓158 ✗0 |
| `smoke.sh --select 0e` | 0 | ✓44 ✗0（59s） |
| `flip-p287-name.sh --self-test` | 0 | FLIP 全绿（leg0 / shadow / lint / shape） |
| `flip-p287-lock.sh --self-test` | **1** | leg0 12 条 ✓、leg1 4 条 ✓、leg3 3 条 ✓、**leg2 两条 ✗** → 见 §F1 |
| `lib/tmp-root.sh --self-test`（正常 / `--break=flat-name` / `--break=no-ns`） | 0 / 1 / 1 | ✓19 ✗0；✓17 ✗2（根名两条）；✓17 ✗2（标记与台账两条） |
| `tmp-hygiene.sh --self-test` | 0 | ✓73 ✗0 |
| `tmp-hygiene.sh --lint` | 0 | 检查了 32 个 mktemp 模板，全部合规 |
| `section-select.sh --check` | 0 | ok 8 bad 0 SKIP 1 |
| `section-guard.sh --loop-check` / `--budget-check` | 0 / 0 | 85/85 循环；135/135 段、每行满足 `max(⌈band×4⌉,60)` |
| `gate-guard.sh` | 0 | 四向都过 |
| `openspec validate --all --strict` | 0 | 22 passed / 0 failed |
| `ledger-ban.sh` | 0 | hits=0 names=ok user=resolved |
| 独立树投影（`cp -a openspec` → validate → archive → validate） | 0 | 22/0 → archived → 21/0 |
| 34/34b 断言标签集合对照（改动前 ↔ 落地） | - | 既有 180 条中文标签里只有 5 条机械改写、无一条消失 |
| `nogit` 探针（§留空项 1.1） | 0/0/0 | 非 git 检出 / 无 git 的 PATH 都返回、都不报错 |

日志与现场：`/var/tmp/p303/acc/*.log`、`/var/tmp/p303/{pre,proj,nogit}`；门禁运行期间本工作树零改动
（`git status --short` 跑前跑后都空）。

## 诚实边界与未测项

- **没有跑全套门禁**：只跑了 change 的闭包选段（34c/34d/34/34b/0e）与静态自检；`34,34b,34c,34d,0e` 之外的段没跑。
- **没有碰机器锁**：所有运行都用私有 `TEAM_SMOKE_LOCK=/var/tmp/p303/machine.lock` 与私有 TMPDIR；
  没在共享 `/tmp` 根上做任何删除实验，历史平铺残留一个没动（本变更的诚实边界，不是本次的任务）。
- **F1 只报不改**（写集限制）；**8 个留空项也没有补**（其中 1.1/2.1/2.4 要改夹具，5.2/5.3 要改产品文档/脚本，
  7.2 要改 P288 的报告文本 —— 都不在本任务写集内）。
- **没有独立复验**：本次是作者自查（P303 就是 apply 侧的账前自查）；F1 的修法、留空项的裁定与最终「
  验收是否成立」都等 PM 与另一席位的判定。
- 复跑读数里的时间是在一台 loadavg 20–30 的机器上取的（与 P288/V53 同日同量级），只作记录、不作判定。

## Decisions and deviations

1. **0.3 的缺项由 P303 补测，而不是留空**：任务书写的是「冻结改动前基线并抄进报告」，其中四项已在 P288 报告里，
   缺的是用时与 design 三条复跑。这两样是可复现的**测量**（提交 `b77af9e1`），我在独立 clone 上按同形命令补了；
   报告里同时点名「这两样是 P303 补的，不是 apply 当时冻结的」。
2. **留空的 8 格不改一个字**：按任务书「找不到证据的项留空并单列一节说明原因」，原因写在本报告 §留空项，
   `tasks.md` 里那 8 格保持原样（连 `（待填…）` 都没动），PM 一眼能看出哪些格子还空着。
3. **勾的写法**：每格保留原文，只把末尾的 `· 证据：（待填…）` 换成 `· 证据：P303 按事实勾：…`；
   证据一律给「报告小节 / 提交号 / 命令与 rc」三样里的一到三样。
4. **F1 的处置建议**：不在本任务里修（写集只有 tasks.md 与本报告）；建议单独开一单修
   `flip-p287-lock.sh:194` 的选树探测（`flip-m33.sh:106` 的注释就是前车之鉴），并顺手评估 `flip-m44.sh:128`。

## Suggested next steps

1. PM 复验：读 `tasks.md` 的 22 格证据（P288 报告小节 / 提交号 / 本次 rc），对 8 个留空项逐条裁定
   （补断言 / 补文档 / 判为不在范围）。0.3 的补测在 §0.3。
2. **F1 建议开单**（小改动、但挡着这条变更的验收清单）：修夹具的选树探测并重跑
   `flip-p287-lock.sh --self-test` 到绿，再决定 7.1 的勾。
3. 归档前把「8 个留空项的裁定」与「F1 的状态」带进 `team change status gate-lock-external-deletion` 的判定；
   本任务**不改**产品/测试/规格，也没有把 F1 写进任何别处。
