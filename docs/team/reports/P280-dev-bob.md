# P280 · 门禁锁的持有者自述与嵌套运行纪律：propose

agent: dev-bob   status: DONE   time: 2026-10-15T12:00:00Z
branch: `task/P280-gate-lock-hygiene`   PR/MR: -（local 模式，分支留本地，PM 复验后合并）
phase: propose   change: `gate-lock-hygiene`（**新**；任务书头部写的是 `change: -`，见 §5 第 1 条）

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/gate-lock-hygiene/proposal.md` | 提案：现象与同源的账（P255 的三条）、现状复核表（六条事实各带证据）、三块改动、能力落点、影响面、**六个待裁点**、验收命令、范围外 |
| `openspec/changes/gate-lock-hygiene/design.md` | 事实 §1（EXP1/EXP2/EXP3 三条实测的完整命令与原文 + 预算表读数 + P255 的引用）、判定 D1（结论 + 两侧代价 + 三条被否掉的备选）、记录形状 D2、嵌套纪律的可判定四态、上限算式 D3、三条红侧的设计、风险与**诚实边界** |
| `openspec/changes/gate-lock-hygiene/tasks.md` | apply/verify 任务表：写集逐条列明、三条红侧的方向、预算表义务、独立复验清单 |
| `openspec/changes/gate-lock-hygiene/specs/verification/spec.md` | delta：**1 MODIFIED + 2 ADDED**（MODIFIED 的既有正文与五条 scenario 逐字保留，新增一条 scenario；两条 ADDED 共 8 条场景） |

本阶段**只写提案**：没有改产品代码、没有改任务书、没有跑门禁、**没有碰机器锁** `/tmp/teamsmith-smoke.lock`，
也没有起任何共享 tmux 调用。所有实测都在私有锁 + 私有 `TMPDIR` 下做（design §1 的命令可复跑）。
apply 与 verify 另行换人（写的人不验自己的活）。

## Verification evidence (must have actually been run)

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -4
✓ spec/verification
✓ spec/watchdog
Totals: 21 passed, 0 failed (21 items)          # 改前 20，多出来的就是 change/gate-lock-hygiene
rc=0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11892 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1567 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出：diff 干净、工作树干净）
rc=0
```

投影自证（本 change 归档后规格库仍自洽，且 MODIFIED 不丢场景）：

```bash
$ rm -rf /tmp/glh-trial && mkdir -p /tmp/glh-trial && cp -a openspec /tmp/glh-trial/openspec \
  && (cd /tmp/glh-trial && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y gate-lock-hygiene \
      && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict) | tail -3
✓ spec/verification
✓ spec/watchdog
Totals: 20 passed, 0 failed (20 items)          # 归档后 change 数 -1，20/0
rc=0

# 逐条比对 MODIFIED 的既有五条 scenario（投影后的 verification spec vs 基线）：
before lines=52 after lines=73
OK  A long queue does not consume the run budget
OK  A queue beyond its cap fails loudly and names the holder
OK  A gate that really runs past the limit is still TIMEOUT
OK  A gate that already holds the lock does not queue again
OK  Without a queue mechanism the degradation is printed
before scenario 数=5 → after 6（新增：The cap follows the holder's published remaining time）
verification 的 requirement 数 31 → 33（两条 ADDED 落位）
```

## 1 判定（brief 第 1 条）：嵌套运行不该抢机器级的那把锁

**结论：不该。** 机器锁的契约是「串行化**顶层**运行」；嵌套运行按定义就在一个顶层运行内部，再去排同一把锁
不是更多的串行化，而是①把整队唯一的共享资源交给一个夹具（实测 1h16m 就是这条）②与自己的祖辈自锁
③让排队超限的 FAIL 归因失真（点名的持有者只是 `smoke.sh`）。

两侧代价都写进了 design D1。**「不抢 → 两个席位的嵌套运行可能同时在机器上跑重活」这一侧的交代**是三条，
不是一句「不会发生」：① 放行**有条件**——嵌套运行只有在能证明祖辈持有锁时才不排队，证明走**进程树**
（pid + starttime 匹配），不依赖会被夹具 `env -u` 掉的 `SMOKE_LOCK_WRAPPED`；证明不成立就是顶层运行，照旧排队。
② 锁仍然只放一个顶层运行，而嵌套必须有活着的顶层祖辈，所以跨席位的嵌套重叠只可能来自**显式退出串行**
（`TEAM_SMOKE_NO_LOCK=1` / 无 `flock` / FAST），这个残余窗口写进记录（`no_lock=1`）与文档，**可观测**。
③ 嵌套运行**必须有预算**：期限对齐到生它的那一段的剩余预算，到点由它自己的看门狗点名 + 停跑 + 留现场。

三条被否掉的备选（免得 review 时再问一遍）写进了 design D1：给嵌套一个小上限（上限不能把工作量变小，
只能改「谁被 FAIL」）、给嵌套另一把锁（多一份自述与清理责任，而重活叠加已经有既有的负载前提在管）、
「直接放行」（brief 明确不许）。

## 2 修法（brief 第 2 条）

| brief 的要求 | 落点 |
|---|---|
| 等待者能看到「在等谁」：区分外层/嵌套、点名席位与工作树、已跑多久、预计上限 | 新增要求 #The gate lock's holder record…；记录字段见 design §3.2；等待者两行（开始排队 / 撞上限）都打印 |
| 嵌套运行的预算要显式 | 新增要求 #A nested run does not queue…；期限 = `min(自己的表预算, 祖辈武装段剩余)`（design §4） |
| 排队上限按可预期的剩余时间判 | MODIFIED 要求 + `cap = clamp(remaining + 60, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`，等待者必须打印算式（design §5）；**FAIL 文案一行说清 kind/席位/工作树/已跑/上限/剩余**——两条都做了 |
| 不许去掉锁 | 锁路径、`TEAM_SMOKE_NO_LOCK`/`FAST`/无 `flock` 的降级语义一字不改 |
| 不许把嵌套直接放行而不解决两侧 | 见 §1 的三条交代；残余窗口 `no_lock=1` 可见 |

## 3 三条红侧的设计（brief 第 3 条，apply 阶段落地）

三条都在 §34 / §34b，只用私有锁与私有 `TMPDIR`：

- **①「嵌套运行持有锁」的现场** → 等待者的一行必须带 `kind=nested` + 席位 + 工作树 + `已跑 Ns` + `expected`，
  且**不得**出现 `持有者未知`。红侧：去掉嵌套登记 → 该行丢字段 → 断言红并点名缺哪个字段；还原后绿。
- **② 嵌套运行超预算** → 一行点名（段号 + id + `预算 3s` + 实际）、现场在、退出码 2、`<lock>.runs/` 登记消失、
  **私有锁 `flock -n` 可立刻取到**（「释放」的可观测判据）。红侧：去掉期限 → 三条断言红；还原后绿。
- **③ 单层运行不回退** → §34 ①–⑥ 与 §34b ①–⑤ 的判定**一条不改**（逐条 diff 对照），新增对照：锁空闲的顶层运行
  `kind=top`、`queued/ran/limit` 与今天同形、无 `expected` 的旧持有者仍按 1800s 判。红侧：把顶层也改成不排队 →
  §34 ①/② 与 §34b ①/③ 红；还原后绿。

## 4 翻转证据（红 → 绿）与三个缺陷的实测复现

**4.1 翻转：破坏 MODIFIED 的既有 scenario → 归档被拒（红）→ 还原 → 归档成功（绿）**

本变更唯一的「实现」是 delta 文本，所以翻转打在**工具自己的守门**上：`openspec archive` 会拒绝让一条
MODIFIED 的既有 scenario 消失。

**红侧**（在 `/tmp/glh-flip` 的 openspec 副本里从 MODIFIED 块删掉「Without a queue mechanism the degradation
is printed」这一条）：

```bash
$ (cd /tmp/glh-flip/glh-trial2 && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y gate-lock-hygiene)
Specs to update:
  verification: update
verification MODIFIED failed for header "### Requirement: The hard timeout covers the gate run, not the queue" - current spec contains scenario(s) not present in the modified block: "Without a queue mechanism the degradation is printed". Refresh the change spec before archiving to avoid dropping scenarios.
Aborted. No files were changed.
# 且 change 目录仍在（归档没有发生）
```

**绿侧**（把真树上的 delta 原样还原后同一命令）：

```bash
$ (cd /tmp/glh-flip/glh-green && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y gate-lock-hygiene)
Totals: + 2, ~ 1, - 0, → 0
Specs updated successfully.
Change 'gate-lock-hygiene' archived as '2026-10-15-gate-lock-hygiene'.
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -1
Totals: 20 passed, 0 failed (20 items)
# 归档后的 MODIFIED 里五条既有 scenario 逐字节比对：OK ×5（见 §Verification evidence 的投影自证）
```

注：`openspec archive` 拒绝时**退出码仍是 0**（只有一行 `Aborted`）——复核时不能只看 rc，要看那一行。
这条也说明「MODIFIED 丢场景」不是靠人盯，工具会拦。

**4.2 三个缺陷是**实测**出来的，不是推的**

本任务不是 defect-fix（阶段是 propose），但判定所依据的三个缺陷都在本 worktree 亲手复现过；命令与输出原文
在 design §1（私有锁、私有 `TMPDIR`、机器锁零触碰）。摘要：

| # | 缺陷 | 原始输出（摘要） |
|---|---|---|
| EXP1 | 带 `SMOKE_LOCK_WRAPPED=1` 的嵌套运行**覆写并删除**真持有者的记录 | `before: … cmd=REAL-HOLDER` → 嵌套运行 rc=0 → `after: [<MISSING>]`，而 `flock … sleep 25` 仍在跑 |
| EXP2 | 丢掉标记的嵌套全量运行**拿到锁** | 日志里只有「全量门禁互斥：持有 …」，没有「另一套正在跑」 |
| EXP3 | 等待者看到的一行只有 `cmd=smoke.sh`（外层与嵌套同形） | `另一套全量 smoke 正在跑（… pid=3603975 cmd=smoke.sh）；本套排队，最多等 1s` |

另有一条**读数**（不是缺陷，是口径不一致的证据）：`awk` 读 `tests/section-budgets.tsv` →
`rows=129 sum_band=9330.28 sum_budget=41362`，单段最大 `61b` = band 5000 / budget 20000；
而等待者上限默认 1800s（`smoke.sh:327`、`cmd-review.sh:1068`）。

## 5 Findings / 需要 PM 裁定的点

1. **任务书头部与产物的形状不一致（请 PM 在提案复核时定）**。任务书写 `change: -`、`deltas: -`、
   `anchor: none (infra) — 门禁资源纪律；不改产品行为`，但同一份任务书又要求 `phase: propose`、
   「只写提案（含上面三条红侧的设计）；apply 与 verify 另换人」，验收里还有 `spec-refs.sh --check`。
   同仓最近 9 个 propose 任务（E14/E16/E17/P248/P250/P252/P256/P257/P258）**都**写明了 `change:`/`specs:`/`deltas:`。
   我按「必须成立的东西进规格」（AGENTS.md：不许在任务书或文档里造平行规格系统）与「没有 PM 的提案复核就不派 apply」
   两条协议，把它落成了 OpenSpec change `gate-lock-hygiene`（`openspec/changes/gate-lock-hygiene/**`，
   OWNERSHIP 里该目录归「该 change 当前阶段的 owner」）。**若 PM 的本意是 change-less 的设计文档，请在复核里点名**
   ——回退只需 `git rm -r openspec/changes/gate-lock-hygiene` 一次，或把 id 改成你选的名字。
2. **D1–D6 六个裁定点**（proposal 末节，逐条带推荐与备选）：D1 嵌套不抢锁（推荐是）；D2 记录形状
   （单文件 + 每运行一条 `<lock>.runs/<pid>.run`）；D3 上限算式（推荐 `clamp(remaining+60, WAIT, 4×WAIT)`，
   备选是 brief 的「或者」那一支：保持 1800s 只把文案做诚实）；D4 嵌套期限来自祖辈心跳（推荐是）；
   D5 不新增配置键；D6 apply 一次做完还是拆两轮（推荐一次，避免一个记录文件两个写者）。
3. **D5 的旁证（半登记状态）**：`TEAM_SMOKE_FAST` 在 config schema 里是 `refuse` 类，而
   `TEAM_SMOKE_LOCK` / `TEAM_SMOKE_LOCK_WAIT` / `TEAM_SMOKE_NO_LOCK` **都不在** schema 里（只在环境里读、
   只在 `references/protocol.md` §9b 被文档化）。本变更**不新增键**，所以不触发 P141 的 R1；若 PM 要顺手把这一族
   注册进 schema（四面齐 + 重建 panel bundle），tasks 4.5 已按「仅当裁是」写好。
4. **风险 1 是 apply 最可能出错的地方**：`flock --close` 的持有者是 flock 进程本身，顶层运行是它的**子**进程，
   所以「祖辈持有锁」的判据必须同时认「持有者在我的 ppid 链上」与「持有者是我的直接父（flock 形状）」，
   并用 pid+starttime 防复用。夹具两向都要钉（真祖辈 → `nested`；一个**不是**祖辈的活 pid → 仍是 `top` 并排队）。
   这条写进了 design §7 与 tasks 2.1 / 6.2。
5. **诚实边界（不许被后续报告越过）**：门禁能证明的是「记录里有这几样、等待者打印了它们、嵌套运行到点会被点名」。
   它**不能**证明「某个活着的席位读了那行并作出正确判断」，也**不能**证明「两个席位的嵌套运行一定不重叠」——
   残余窗口（`no_lock`）存在，本变更只让它可观测。任何输出不得声称已经证明了后者。

## 6 未做 / 未测（如实列出）

- **没有跑门禁**：任务书写明本阶段只写提案；且「一个 change 只选它碰到的段」这条纪律在 apply 才有意义
  （本 change 不改任何产品/夹具文件，`section-select.sh` 的增量选集对提案文件是 `NONE`）。
- **没有在真实机器锁上复现 PM 那条 1h16m 的进程树**：现场已经不在（`ps` 树是 PM 当时读的）。我用私有锁把
  三条可复现的**机制**各自复现了（EXP1/EXP2/EXP3），并在 design §1.3 写明「EXP2 的形状打在机器锁上就是那次实测」，
  **没有**声称我复现了同一条进程树。
- **没有验证「§61b 在完整门禁里到底跑多久」**：表里写 P238 实测 4883s、V28 复验 4946s（引用），我按引用使用，
  没有自己跑一遍（那是 80 分钟的门禁段，不该为一份提案跑）。
- **没有改** `references/protocol.md`、任何 `tests/**`、任何 `scripts/**`：它们都在 tasks 的写集里，属 apply。
- 报告里的命令输出都是真跑的；`spec-refs` 的 `11892 effective line(s)`、`ledger-ban` 的 `files=1567`
  是本次运行的读数。
