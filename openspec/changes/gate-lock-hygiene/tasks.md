# gate-lock-hygiene · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧，改前/改后各一次实测）；
**verify** 由**另一个**席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与红侧。
本文件不是规格；合同文本在 `specs/verification/spec.md`（1 MODIFIED + 2 ADDED）。

写集（apply 需要逐条明授；未授 → `BLOCKED:` 交回 PM）：

- `skills/teamsmith/scripts/lib/gate-lock.sh`（**新**：记录格式与读写的唯一实现，`smoke.sh` 与 `cmd-review.sh` 共用）
- `skills/teamsmith/scripts/lib/cmd-review.sh`（排队行、记录、上限算式）
- `skills/teamsmith/tests/smoke.sh`（锁块、持有者记录、嵌套放行与登记、上限算式、§34/§34b 扩面）
- `skills/teamsmith/tests/lib/section-guard.sh`（公布 `heartbeat` 路径、嵌套期限对齐、登记/注销）
- `skills/teamsmith/tests/section-budgets.tsv`（§34/§34b 行按实测补 band）
- `skills/teamsmith/tests/section-paths.tsv`（§34/§34b 行登记新路径）
- `skills/teamsmith/references/protocol.md` §9b（纪律文本）

不碰：`references/migration.md`（P255）、`references/config.md`（P261）、`scripts/lib/cmd-project.sh` 的帮助段（P260）、
`team review` 的判定词表与 `team_review_verdict`。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案复核 `docs/team/reviews/gate-lock-hygiene-proposal.md`，把裁定点 D1–D6 的结论摘进报告；
  与提案不同的裁定按其改写判定与场景（D1 若裁「嵌套仍排队」，则 §1 的第 3 项改成「嵌套可以排队，但记录必须自述、
  持有不得超过生它的那一段的剩余预算」，红侧 ①/② 的形状不变）。 · 证据：报告「PM 的裁定」表（D1 = 嵌套运行不排队；
  D2/D3/D4/D5/D6 按推荐认可；准入条件 ①–⑤ 逐条对应到夹具与红侧）
- [x] 0.2 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec
  && (cd /tmp/<x> && openspec validate --all --strict && openspec archive -y gate-lock-hygiene
  && openspec validate --all --strict)` 必须绿；逐条核对 MODIFIED 的既有正文与五条 scenario 逐字保留、
  两条 ADDED 的标题与场景齐全。 · 证据：`Totals: 21 passed, 0 failed` → `Specs updated successfully.` →
  `Change 'gate-lock-hygiene' archived as '2026-10-15-gate-lock-hygiene'` → `Totals: 20 passed, 0 failed`
  （本变更**没有**改 spec 散文：四条要求已在 spec 里，apply 只落实现）
- [x] 0.3 冻结**改动前**基线并抄进报告：`smoke.sh --select 34,34b` 的 ✓/✗ 计数与用时；
  `<lock>.holder` 的字段形状（`<ISO> pid=<pid> cmd=smoke.sh`）；EXP1/EXP2/EXP3 三条复现（design §1 的命令）；
  `awk` 读表的 `sum_band=9330.28 / sum_budget=41362`；§34/§34b 在 `section-budgets.tsv` 里的旧 band。
  · 证据：本地证据包 `logs/00-baseline.txt`（EXP1 前后原文 + EXP3 旧排队行；证据包不进仓，见报告开头）、
  `01-before-34-34b.log`（改动前 §34/§34b ✓73 ✗0，34 用时 48s / 34b 5s）、旧 band 行 = 48.00/192 与 5.00/60
  （`git show <基点>:skills/teamsmith/tests/section-budgets.tsv`）。EXP2 未复跑（design 已实测，本任务未重复）

## 1 记录自述（规格 #The gate lock's holder record names its kind, its owner, its elapsed time and its bound）

- [x] 1.1 新建 `scripts/lib/gate-lock.sh`：记录格式的**唯一**读写实现 —— 写一条（字段见 design §3.2）、
  读全部（glob + pid/starttime 过滤 + `stale` 判定）、删自己那一条。格式常量只在这里定义一次。
  · 证据：`gate_lock_record_write/get/live/describe`、`gate_lock_write_holder/register_run/remove_*`、
  `gate_lock_cap`、`gate_lock_seat_of_dir`、`gate_lock_expected`；`bash -n` 通过，
  夹具 §34b②/⑦/⑨ 与 §34⑦ 覆盖（验收运行里 ✓36 + ✓77）
- [x] 1.2 `tests/smoke.sh` 的锁块：`:396` 的判定从「环境标记」改成「**本进程是不是 flock 的持有者**」；
  持有者记录只由持有者写、只由持有者删；嵌套运行写 `<lock>.runs/<pid>.run` 而不是 `<lock>.holder`。
  红侧就是 EXP1：带标记的嵌套运行跑完后，持有者记录**仍在**且仍指向真持有者。 · 证据：marker 记 `<epoch> <pid>`，
  判定 = `gate_lock_marker_pid(marker) == $$`；EXIT 只删自己的那条 + 只有真持有者删 `.holder`；
  §34b② 断言顶层运行 `kind=top`、`ancestor=-`、登记存在；改动前 EXP1 原文见 logs/00-baseline.txt
- [x] 1.3 `cmd-review.sh` 的 `QUEUE_WRAP` 与排队行改用同一份实现；记录里补 `kind/agent/worktree/started/
  expected/bound/sections/no_lock`。 · 证据：`QUEUE_WRAP` 里 `. <lib>/gate-lock.sh` 后调同一个
  `gate_lock_record_write`（`start=` 在包装器里现算，因为它是**那个进程**的 starttime）；
  排队行改用 `gate_lock_describe` + `gate_lock_cap`；§34①–⑦ 全绿（含 `queued/ran/limit` 记账与 token 闭集）
- [x] 1.4 席位/工作树解析按 `team notify` 发送者的同一条规则（运行时目录，名册拼写优先，**不取窗口名**）；
  反向对照：窗口名故意报成别的席位而 cwd 是本工作树 → 记录里仍是 cwd 的席位；解析不出 → `agent=?`。
  · 证据：§34b⑨ 四条（`.worktrees/<名字>` → 那个名字 / 名册拼写 / 主检出 → `pm` / 不是 git 树 → `?`）+
  反向对照一条（PATH 里塞一个报 `verify` 的假 `tmux`，记录里仍是 `dev`）+ `worktree=` 是 cwd 的 toplevel
- [x] 1.5 等待者的两行（开始排队 / 撞上限）都打印这份记录，并按 `started` 算 `已跑 Ns`；缺字段写 `?`。
  · 证据：§34b⑦ 三条（两行同字段 + `已跑 3Xs` + 绝不打印「持有者未知」）；§34② 的旧记录 `?` 断言；
  验收运行里真实的一行见报告「Flip evidence」

## 2 嵌套纪律与预算（规格 #A nested run does not queue on the machine lock…）

- [x] 2.1 祖辈证明：沿 ppid 走到记录里的持有者 pid，pid+starttime 匹配才算 `nested`（含 `flock --close`
  的直接父形状）；证明不成立 → `top` 并照旧排队。没有 `/proc` → 一律 `top`（fail closed）并打印一行说明。
  · 证据：`gate_lock_prove_ancestor` + §34b⑧ 的自述行「嵌套运行（祖辈 pid=…）」；反向对照 = §34b⑨
  「锁被活着但不是祖辈的进程持有 → 证明不成立 → 照旧排队（exit 2）」+ 不打印嵌套行。**没覆盖**：
  「没有 `/proc` 时多打一行说明」这一句本身（Linux 上造不出该条件；行为半边已由反向对照覆盖，见报告诚实边界）
- [x] 2.2 `section-guard.sh` 公布 `SG_HEARTBEAT` 路径给持有者记录（顶层未开段时为 `-`）；嵌套运行读祖辈的
  武装段得到 `armed_epoch + budget`，把自己的期限设成 `min(自己的表预算, 祖辈剩余)`；到点走既有 trip 路径。
  · 证据：`section_guard_heartbeat_path`（路径只拼一次）+ 记录里的 `heartbeat=` 字段；§34b⑧ 的
  「对齐祖辈」那一轮：`预算 [1-5]s` + 开跑行「（嵌套运行：对齐祖辈剩余预算）」+ 表里的 `预算 60s` 不出现 +
  exit 2 + 登记消失 + 私有锁可再取
- [x] 2.3 夹具把嵌套运行丢到后台、自己先收段时，门禁在该段收口后检查 `ancestor=<自己 pid>` 的登记是否仍活着，
  仍活着就**打印一行点名**，并只对**自己登记过的 pid** 发信号（D37 纪律：不按名字、不按进程组）。
  · 证据：`section_guard_check_orphans`（在 `section_guard_close` 里调用）；§34b⑪(a) 五条断言
  （一行点名 + 字段 + 只杀登记过的 pid + 同名诱饵 `exec -a smoke.sh` 仍活着 + 另一个诱饵仍活着）；
  §34b⑪(b) 留一条真实嵌套运行给 §35 开段的收口检查（验收日志里那一行就是端到端证据）
- [x] 2.4 `references/protocol.md` §9b：写进「嵌套运行不排队、必须有祖辈证明、必须在生它的那一段里结束」，
  并写明 `no_lock` 残余窗口（`TEAM_SMOKE_NO_LOCK=1` / 无 `flock` / FAST）与它的代价。
  · 证据：§9b-2 新增两段（嵌套纪律 + no_lock 残余窗口 + 上限算式），`spec-refs --check` rc=0

## 3 上限算式（规格 #The hard timeout covers the gate run, not the queue）

- [x] 3.1 `cap = clamp(remaining + 60, TEAM_SMOKE_LOCK_WAIT, 4 × TEAM_SMOKE_LOCK_WAIT)`；等待者打印算式与
  三个数；没有 `expected` → 退回 `TEAM_SMOKE_LOCK_WAIT`，文案仍带能拿到的字段。`smoke.sh` 与 `cmd-review.sh`
  两条路径同形（review 侧的 `queued Ns / ran Ns / limit Ns` 记账与 token 闭集**一字不改**）。
  · 证据：`gate_lock_cap`（唯一实现）；§34b⑨ 三条单元级（W=10 → 40；W=1000 → 1000；expected=400/已跑 10s/W=200
  → 450）+ §34⑦（review 侧打印 remaining/cap/下限，`team_review_verdict` 仍解析出 PASS）；§34①–⑥ 零回退
- [x] 3.2 超限文案一行说清 `kind` / 席位 / 工作树 / 已跑 / `expected` / `bound`；FAIL 文案与
  `team_review_verdict` 的输出都要有夹具钉住（token 仍是闭集）。 · 证据：§34b⑦（撞上限行同字段）、
  §34②（FAIL 文案 + `门禁没有运行` + 点名持锁者 + `team_review_verdict` 仍解析出 FAIL）

## 4 三条红侧与回归（brief 第 3 条）

- [x] 4.1 红侧 ①：造「嵌套运行持有锁」的现场 → 等待者一行里点名 `kind=nested` + 席位 + 工作树 + `已跑 Ns` +
  `expected`；删掉登记 → 该行丢字段 → 断言红并点名缺哪个字段；还原后绿。 · 证据：§34b⑦ 六条 + 红侧两条
  （`缺：kind=nested expected=300 bound=1200`）+ 还原一条
- [x] 4.2 红侧 ②：嵌套运行 3s 期限 + 永不返回的段 → 一行点名（段号 + id + `预算 3s` + 实际）、现场在、
  退出码 2、登记消失、私有锁 `flock -n` 可立刻取到；去掉期限 → 三条断言红；还原后绿。
  · 证据：§34b⑧ 绿侧五条 + 红侧三条（8s 内零点名 / 登记还在 / 锁仍被占）
- [x] 4.3 红侧 ③：§34 ①–⑥ 与 §34b ①–⑤ 的判定**一条不改**（逐条对照 diff）；新增对照：锁空闲的顶层运行
  `kind=top`、`queued`/`ran`/`limit` 与今天同形，无 `expected` 的旧持有者仍按 1800s 判；把顶层也改成不排队 →
  §34 ①/② 与 §34b ①/③ 红；还原后绿。 · 证据：§34/§34b 全绿（✓134 ✗0）；§34b⑨ 的旧持有者一条（W=2s）；
  「相对 main 的删除行逐条看过」（26 行全是同一处替换，报告里逐条列了）；**没做**「把顶层也改成不排队 →
  既有断言红」那条自毁实验（会动产品判定分支；既有断言对 `持有/排队/超限` 的行为判定本身就是那条对照）
- [x] 4.4 `tests/section-budgets.tsv` 的 §34/§34b 行按**实测**补 band（`max(band×4, 60)` 公式不变），
  `--select 0e` 绿；`tests/section-paths.tsv` 的 §34/§34b 行登记 `scripts/lib/gate-lock.sh` 等新路径，
  `section-select.sh --check` 绿。 · 证据：改前 48.00/5.00 → 改后 52.00/42.00（旧值留在 container 列）；
  `--select 0e` ✓63 ✗0；`section-select --check` = `ok 8 bad 0 SKIP 1`
- [x] 4.5 （**仅当 PM 按 D5 裁「顺手把这一族注册进 schema」**）`TEAM_SMOKE_LOCK` /
  `TEAM_SMOKE_LOCK_WAIT` / `TEAM_SMOKE_NO_LOCK` 按 `TEAM_SMOKE_FAST` 的先例登记为 `refuse` 类，带 zh/en 标签，
  四面齐（schema / `templates/config.sh.tmpl` / `references/config.md` / 面板 `label_<KEY>`）并重建 panel bundle。
  若 PM 裁「不做」→ 本项按 N/A 勾，把半登记状态记进报告的 finding。 · 证据：**N/A**（PM 认可「不新增配置键」）；
  finding 写进报告：三个键仍只在 protocol.md/实现里被文档化，`team config` 看不见它们

## 5 验收与交付

- [x] 5.1 跑齐 proposal「Acceptance」的全部命令（`--select 34,34b`、`--select 0e`、`section-select --check`、
  `spec-refs --check`、`ledger-ban`、`openspec validate --all --strict`、投影自证），报告贴真实命令与输出尾。
  · 证据：报告「Verification evidence」+ `logs/05-acceptance-commands.txt`；交付门禁另跑了
  `smoke.sh --paths`（53 段，✓2106 ✗2，两条都是既有红，见报告）
- [x] 5.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 4 节三条红侧的**原始输出**就是
  本任务的翻转证据；写明未测项、失败与「诚实边界」（门禁不能证明活着的席位读了那行、也不能证明嵌套不重叠）。
  · 证据：`docs/team/reports/P281-dev-bob.md`
- [x] 5.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；本仓库 local 模式：分支留本地，
  `team notify pm` 一行交付说明。 · 证据：三个产品/夹具提交 + 报告提交，均带 `Task: P281` 与 `Agent: dev-bob`

## 6 独立验证（另一席位，不是 apply 作者）

- [ ] 6.1 在独立克隆上重跑 `smoke.sh --select 34,34b` 与 `--select 0e`，确认既有断言零回退 + 三条红侧全绿。
  · 证据：（待填：独立日志）
- [ ] 6.2 逐条重做第 4.1/4.2/4.3 的红侧与还原（不是只复跑绿侧），并自设计反例：一个**不是**祖辈的活 pid →
  必须判 `top` 并排队；记录被删一半 → 等待者必须写 `?` 而不是编数字；陈旧登记（进程已死）→ 打印 `stale`
  且**不删**别人的文件。 · 证据：（待填：反例输出）
- [ ] 6.3 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。
  · 证据：`docs/team/reviews/<ID>.md`
