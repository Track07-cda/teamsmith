# P200 · 18c 的「退场引用逐条点名」判据不许钉在真仓库的归档进度上

agent: dev · status: DELIVERED（local 模式：分支留在本地、不 push；PM 复验后本地合并） · time: 2026-10-03
branch: `task/P200-apply` · base: `ea89db1f`（派单分叉点）
任务书：`docs/team/tasks/P200-retired-assertion-state-pinned.md`
change: `-`（phase `apply`，anchor: none (infra) —— 只动门禁自身的判据与记录，不改 openspec 契约）
授权实现路径：`skills/teamsmith/tests/**` · `docs/team/reports/P200-dev.md` · `docs/team/reports/P200-dev/**`

## 结论

| brief 项 | 状态 | 证据 |
|---|---|---|
| 1. 判据钉在**机制**上：scratch 树里造出「未归档 change 退场了一批引用」 | ✅ | `spec-refs.sh --flips` 新增用例 `retired-naming`：自足最小树（基线 requirement 带一条账本引用 + 未归档 change 把同一 requirement 改写成不带引用）→ `clean retired-naming  retired openspec/specs/boundary/spec.md:13 docs/team/reports/P200-fixture.md by zz-retire`（`logs/30`）；smoke §18c 断的就是这一行 |
| 2. 红侧①：把点名关掉（shadow）→ scratch 用例必须红 | ✅ | 新增 `--break=noretired`（关掉 retired 收集，连同汇总计数）：**同一条 ERE** 在绿日志 1 命中、影子日志 0 命中，`--flips` 报 `BAD retired-naming` 且 rc=1（`logs/31`）；smoke §18c 的 ④b 复现同一形状 |
| 2. 红侧②：真树在任何归档状态下都绿（现在绿 + 再造一个未归档的 retired 引用也绿） | ✅ | 现在：`--check` 绿（`retired 0`，`logs/32`）；再造：③b 在真树 openspec 的**副本**里种一条引用 + 一个 `zz-p200-retire` change → 仍绿并点名 `retired … by zz-p200-retire`（`logs/20` 的 18c 段） |
| 3. 不删检查（要删得先解释谁保证） | ✅ | 断言没删，换成三条承重的：真树汇总行的**状态无关**形状（`retired <n>`，0 也算）+ `--flips` 的 `retired-naming` 用例 + 影子红侧。`retired` 只是点名、不进 `judged`（判红判绿与它无关），所以「绿」本身不承重 —— 承重的是点名行与计数 |
| 4. 门禁：`openspec validate --all --strict` + 容器 `--select 18c` + 容器 FAST | ✅ | validate ✓（15/15）；`--select 18c` ✓46 ✗0（18c 段 ✓25 ✗0）；容器 FAST ✓3793 ✗1 —— **那 1 条红不在 P200 的改动面**（12b-pi3 的隔离扫描命中真项目 inbox 里一句既有英文，见「门禁」节与 `logs/60`） |

一句话：旧断言把**判据**钉在了「真仓库里此刻恰好有一个未归档的 change 在退场引用」这个**临时状态**上 ——
`spec-rationale-self-contained` 一归档（retired 4 → 0），它就从绿变红，读起来像产品坏了。现在状态由 scratch
树自己造（机制判据 + 影子红侧），真树只留状态无关的形状。

## 提交

| Commit | 内容 |
|---|---|
| `f66cd409` | 判据改造：`spec-refs.sh` 的 `retired-naming` 用例 + `--break=noretired` 影子；`smoke.sh` §18c 的汇总形状断言 / 真树副本红侧 / 影子红侧 |
| `426a73a9` | 预算表记录：18c 的实测带 6.00 → 8.00（`P200-18c-ctr`，✓25 ✗0），预算不变（ceil(8×4)=32 < floor 60） |
| `f9d135a3` | 自我修正：④b 的红侧改用**与绿侧逐字相同的 ERE**（第一版第二句用的 `^retired …` 在 flips 日志里永远不命中，是空断言），并加「只少一条用例」 |
| （本报告） | 报告 + `logs/` 原始输出（红前 / 绿后 / flips / 影子 / 真树 check / 破坏实现 / validate / FAST / 报告入账后重跑） |

## 交付物

| Path | 做了什么 |
|---|---|
| `skills/teamsmith/tests/spec-refs.sh` | 走查器：`breakstage == "noretired"` 时跳过 retired 收集（点名与计数一起关，判红/判绿两条路不动）；`flips()` 新增第 ⑬ 个用例 `retired-naming`（`mk_retire_tree` 自足最小树 + `clean` 行带点名行）；`--flips` 头注释点名新影子 |
| `skills/teamsmith/tests/smoke.sh` | §18c：旧的 `^retired ` 断言 → 汇总行的状态无关形状；新增 ③b（真树副本 + 种一条未归档退场引用 → 绿且点名）与 ④b（`retired-naming` 的 clean 行 + 影子红侧：同一条 ERE 两处用 + 只少一条用例） |
| `skills/teamsmith/tests/section-budgets.tsv` | 18c 行：band 6.00 → 8.00、container 8.00，provenance 记 P200 实测（host 未重测，仍 P185 的 5s；`--budget-check` 全过） |
| `docs/team/reports/P200-dev/logs/` | 10 红前 · 20 绿后 · 21 报告入账后重跑 · 30 flips · 31 影子红 · 32 真树 check · 40 破坏实现 · 50 validate · 60 FAST 原始输出 |

## 验证证据（都实际跑过；命令与原始输出在 `logs/`）

### flip evidence ①：红 → 绿（同一条断言、同一段）

**红（改动前，容器 `--select 18c`）** —— `logs/10-red-before.txt`：

```text
  ✓ 18c --check 绿：spec-refs: judged 101 reference(s) (49 distinct) in 9966 effective line(s); retired 0; undeclared 0; …
  ✓ 18c 走查打印了判过的引用计数
  ✗ 18c 被 pending change 退场的引用逐条点名（retired 行）（/tmp/teamsmith-smoke.2WVKmE/p150-check.log 中没有匹配 [^retired ]）
…
== 选段结果 ==  ✓ 41  ✗ 2
```

（同一次运行里 0d 还有一条 ✗：只挂 worktree 时 git worktree 的 `.git` 指向主仓库、git 面不可判 —— `logs/20` 那份同命令加主仓库只读挂载后转绿，与 P200 无关。）

**绿（交付树，容器 `--select 18c`）** —— `logs/20-green-after.txt`，选段 ✓46 ✗0，18c 段 ✓25 ✗0：

```text
  ✓ 18c 真树汇总行在任何归档状态下都打印退场计数（retired <n>）
  ✓ 18c 真树副本 + 一个未归档的退场引用仍绿并点名（retired openspec/specs/agent-adapters/spec.md:221 docs/team/reports/P200-fixture.md by zz-p200-retire）
  ✓ 18c --flips 全绿：18 个变异按预期，反向守卫绿
  ✓ 18c --flips 钉住退场引用被逐条点名（P200：scratch 里造的未归档退场状态，不依赖真树归档进度）
  ✓ 18c 退场点名的红侧：影子（SPEC_REFS_BREAK=noretired）下同一条判据 0 命中、--flips 报 BAD retired-naming，其余 17 条照旧
#5 18c · … · 用时 8s · ✓25 ✗0 SKIP0 · ticks 25
```

### flip evidence ②：影子红（关掉点名，同一棵树、同一批判据）

`logs/31-flips-shadow-red.txt`（宿主机、纯文本走查，不碰 tmux）：

```text
BAD   retired-naming   要绿且逐条点名（retired … by zz-retire），实得 exit 0：skip: no ledger …；spec-refs: judged 0 reference(s) …; retired 0; undeclared 0; …
spec-refs: --flips FAIL（18 用例如预期，1 个不符；break=noretired）
```

（`rc=1`；同一批 18 条用例仍按预期，只有 `retired-naming` 一条变红 —— 判据承重，不是橡皮图章。）

### flip evidence ③：破坏实现 → 守卫必须红 → 还原

`logs/40-break-token.txt`：手工把走查器打印的点名 token `retired ` 改成 `retiredX `（**改实现**，不是旋钮）→
容器 `--select 18c` 变红（18c 段 ✓21 ✗4，四条点名相关判据全中），跑完 `git checkout --` 还原字节 → 同命令再跑 = `logs/20`（✓25 ✗0）：

```text
  ✗ 18c 真树副本 + 未归档的退场引用：走查绿但没有点名（spec-refs: judged 101 reference(s) …; retired 1; undeclared 0; …）
  ✗ 18c --flips 红：BAD   retired-naming   要绿且逐条点名（retired … by zz-retire），实得 exit 0：…
  ✗ 18c --flips 钉住退场引用被逐条点名（P200：…）（… 中没有匹配 [^clean +retired-naming +retired .*docs/team/reports/P200-fixture\.md by zz-retire$]）
  ✗ 18c 退场点名的红侧：影子下要「同一条判据 0 命中 + BAD retired-naming + 只少一条用例」（绿 17 / 影子 17；…）
#5 18c · … · 用时 8s · ✓21 ✗4 SKIP0 · ticks 25
```

（注意 `retired 1`：走查**看得见**那条退场引用，只是不再按 `retired` 这个名字点名 —— 守卫红的原因正是点名，不是解析。）

## 门禁（都实际跑过）

| 门禁 | 结果 | 原始输出 |
|---|---|---|
| `openspec validate --all --strict`（容器，openspec 1.8.0） | ✓ 15 passed / 0 failed | `logs/50-validate.txt` |
| 容器 `TEAM_SMOKE_FAST=1 smoke.sh --select 18c` | ✓46 ✗0（18c 段 ✓25 ✗0） | `logs/20-green-after.txt` |
| 容器 `TEAM_SMOKE_FAST=1 smoke.sh`（FAST 全套） | ✓3793 ✗1（123 段收口；本任务面 #71 18c ✓25 ✗0，用时 8s） | `logs/60-fast.txt` |
| 容器 `--select 18c`（报告与日志入版本控制后再跑一次） | ✓46 ✗0；0d 冲突标记守卫 ✓9 ✗0（扫描对象已含本报告与 `logs/**`） | `logs/21-select-after-report.txt` |

**那 1 条红（与 P200 无关，既有外部状态）**：`12b-pi3` 的
`✗ 12b-j 隔离：调用方项目的 inbox/state 里没有夹具痕迹（期望 [none]，实际 [.../pm-skills/docs/team/inbox/verify.md]）`。

诊断（只读证据，没有改动任何东西）：

```bash
$ grep -rnoE '半句草稿 half a sentence|never lands|held body|race claim|…|M30-PI-STALE' docs/team/inbox/
docs/team/inbox/verify.md:139:never lands
$ ls -la docs/team/inbox/verify.md
-rw-rw-r-- 1 <user> <user> 55748 Oct  3 02:38 docs/team/inbox/verify.md
```

- 命中来自**真项目自己的收件箱**：`verify` 席位（P199 的复验者）02:38 写的摘要里有英文短语 `never lands`，而
  `ob_leak_scan` 的夹具痕迹词表里有这个通用短语 → 判红。
- 时间线：该文件 02:38 定型，本轮三次 FAST（02:57 / 03:24 / 03:57 起跑）都红在同一条上；PM 那边的整套门禁
  只有 18c 一条红（4521 ✓ / 1 ✗），可见它跑在这行文字写进 inbox 之前 —— 所以这条红是这次门禁新遇到的，不是 P200 造成的。
- 与 P200 无关的证据：本次 diff 只动 `spec-refs.sh` / `smoke.sh` §18c / `section-budgets.tsv` 一行，
  三者都不在 `ob_leak_scan` 的输入里（它只扫调用方项目的 `docs/team/inbox` 与 `.pi/team/state`）；
  同段还有一行信息：真项目 state 在夹具期间有自己的活动（真团队在跑）。
- 结论：这是**门禁词表太通用 + 真团队在跑**造成的既有假红，需要 PM 决定是否另开任务（建议见下）。我没有动它。

## 自己跑 / 引用 / 没测到

- 自己跑：上表三条门禁（都在固定镜像 `teamsmith-gate:local` 里）+ 宿主机上的 `spec-refs.sh --flips`（纯文本走查，不碰 tmux）
- 引用：无（没有引用别人的门禁输出）
- 没测到 / 没跑：**完整门禁（不带 FAST）** —— 交付/复验/归档按纪律跑整套；`--select 18c` 这次没跑的段有 118 个键（`logs/20` 末行列了它们）
- 未跑的原因：完整门禁 ~26 分钟且与其它席位共用一个门禁锁，留给 PM 的复验

## 决定与偏离

1. 影子旋钮叫 `noretired`，与既有 `slotmatcher` / `toleranttable` / `writeroot` 同族：它关的是**点名**（连同计数），
   不动判红/判绿两条路 —— 这样影子不会顺手把「真树在任何归档状态下都绿」这条性质也一起改掉。
2. 真树那侧只留**状态无关**的形状断言（汇总行必须打印 `retired <n>`）：若把「真树 retired == 0」也钉上，
   就把判据又钉回了临时状态（反向的同一种错）。
3. 预算表 band 6.00 → 8.00：新夹具（影子 flips 一轮 + 真树副本）让 18c 从 6s 涨到 8s；表的纪律是
   「band = 最差观测值」，不改就每次跑出一行 `⚠ 超过实测带`。预算仍 60s（ceil(8×4)=32 < floor 60）；
   host 未重测（P162 纪律：门禁一律进容器），`host_s` 保留 P185 的 5s。
4. 自我修正（`f9d135a3`）：④b 第一版的红侧第二句用了 `^retired …` 去影子日志里找，而 flips 每行都带
   `clean`/`red` 前缀 —— 那句永远不命中、等于没断。现在两处共用**同一条 ERE**，并加「只少一条用例」，
   破坏实现时它确实红了（见 flip evidence ③）。
5. 交付时 FAST 带 1 条外部假红：如实报告、不掩盖、也不越权去动真项目收件箱或门禁词表（不在本任务范围）。

## 建议下一步

- PM 复验：容器整套门禁；重点看 18c 的 25 条断言与 `--flips` 的 19 个用例。影子可直接复现：
  `SPEC_REFS_BREAK=noretired bash skills/teamsmith/tests/spec-refs.sh --flips`（应当 `BAD retired-naming` + rc=1）。
- 12b-j 的假红建议另开任务：把 `ob_leak_scan` 的痕迹词表从「通用英文短语」改成**本轮专用 token**
  （例如 `SMOKE_<run-id>` 这类只有夹具会写的串），否则真团队任何人写下这些短语都会让门禁红；
  复现命令见上。
- 归档：本任务 `change: -`，无 openspec 归档动作。
