# gate-lock-external-deletion · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧，改前/改后各一次实测）；
**verify** 由**另一个**席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与两条红侧。
本文件不是规格；合同文本在 `specs/verification/spec.md`（3 MODIFIED + 1 ADDED）。

**开工前置（硬）**：P281（`gate-lock-hygiene`）的 apply 必须**已经落地**——两者都动 `tests/smoke.sh` 的锁块与
`scripts/lib/gate-lock.sh`。P287 **扩展** P281 冻结的声明/记录实现；落地后的函数名/字段与设计文档不同时，
**按落地的形状适配**，不许反向改 P281 的合同，也不许把本变更的场景塞进 P281 的返修。

写集（apply 需要逐条明授；未授 → `BLOCKED:` 交回 PM）：

- `skills/teamsmith/scripts/lib/gate-lock.sh`（P281 新建；本变更加**伴生锁路径推导 + 身份登记 + 守卫接口**）
- `skills/teamsmith/scripts/lib/common.sh`（ns 纯函数 `team_project_ns()`；inotify 探针模板）
- `skills/teamsmith/scripts/lib/cmd-review.sh`（取锁顺序、等待、入场检查、记录、queue marker 模板、`p91-merge3` 模板）
- `skills/teamsmith/scripts/lib/cmd-watch.sh`（`teamsmith-npm.*` 模板）
- `skills/teamsmith/tests/smoke.sh`（两把锁的顺序、守卫接线、§34c/§34d 两个新段、P223/P70 的平铺点名）
- `skills/teamsmith/tests/lib/tmp-root.sh`（模板 + `ns=` + 自检两条红侧）
- `skills/teamsmith/tests/tmp-hygiene.sh`（`--lint` 规则与作用域、`--status` 的 ns 列与锁对角色、自检新用例）
- `skills/teamsmith/tests/flip-p287-name.sh`、`skills/teamsmith/tests/flip-p287-lock.sh`（**新**）
- `skills/teamsmith/tests/flip-m33.sh`、`skills/teamsmith/tests/flip-p158.sh`（两处写死的平铺匹配器）
- `skills/teamsmith/tests/perf.sh`（**仅当** PM 按 D4 裁「性能锁一并走同一实现」）
- `skills/teamsmith/tests/section-paths.tsv`、`skills/teamsmith/tests/section-budgets.tsv`（`34c`/`34d` 行 + `0e`）
- `skills/teamsmith/references/protocol.md` §9b-2

不碰：`tests/smoke.sh` 的 §34/§34b（P281 的写集）、`references/migration.md`（P255）、`references/config.md`（P261）、
`scripts/lib/cmd-project.sh` 的帮助段（P260）、`team review` 的判定词表与 `team_review_verdict` 的解析、
`The hard timeout covers the gate run, not the queue` 这一条 requirement（P281 正在改；本变更刻意不碰它）。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案复核 `docs/team/reviews/gate-lock-external-deletion-proposal.md`，把裁定点 D1–D7 的结论摘进报告；
  与提案不同的裁定按其改写判定与场景：D1 若裁「锁进本项目状态目录」或 D2 若裁「不保留兼容声明」，则 design §2/§3 与
  ADDED 要求里相应句子按裁定重写；D4 若裁「性能锁留给下一批」，则 ADDED 最后一段那句按裁定删/改并记 finding；
  D5（ns 形状）与 D6（`--lint` 作用域）若改，按裁定改 ADDED/916 的正文与夹具。**六条 scenario 的方向与命名规则不变**。 · 证据：（待填）
- [ ] 0.2 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec
  && (cd /tmp/<x> && openspec validate --all --strict && openspec archive -y gate-lock-external-deletion
  && openspec validate --all --strict)` 必须绿；逐条核对 3 条 MODIFIED 的既有正文与既有 scenario **逐字保留**、
  ADDED 的标题与六条 scenario 齐全。 · 证据：（待填）
- [ ] 0.3 冻结**改动前**基线并抄进报告：`smoke.sh --select 34,34b` 的 ✓/✗ 计数与用时；
  `tmp-hygiene.sh --lint` 的「检查了 N 个模板」与 rc；`ls -d "${TMPDIR:-/tmp}"/teamsmith-* | wc -l`；
  design §1.2/§1.3/§1.4 三条实测的复跑（私有锁、私有 `TMPDIR`）；以及**两条红侧的改动前形状**：今天锁被删/被换之后
  运行既不点名也不停（这正是 `--break=` 关闭守卫时要复现的形状）。 · 证据：（待填：日志 + 输出原文）

## 1 命名与归属（规格 #A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed）

- [ ] 1.1 `scripts/lib/common.sh`：加 `team_project_ns()` —— 纯函数、不读配置、不依赖检出形状：
  `ns = <slug>-<hash8>`，slug 取 `TEAM_PROJECT`（有则用）否则主检出目录名，只保留 `[A-Za-z0-9_]`、截断 24；
  hash8 = 主检出 realpath 的 sha256 前 8 位；主检出优先 `git rev-parse --path-format=absolute --git-common-dir` 的父目录，
  git 不可用时退到 skill 自己的仓库根。断言三向：同项目两个 worktree 一致、第二个仓库不同、无 git 的检出不报错。
  · 证据：（待填：三向输出）
- [ ] 1.2 `tests/lib/tmp-root.sh`：根模板改 `"$base/${TMP_ROOT_FAMILY_PREFIX}${kind}-${ns}.XXXXXX"`；owner 标记与
  run 台账头各加 `ns=`；`tmp_root_path_ok` 与 `--self-test` 同步；自检加两条红侧（`--break=flat-name` 回到平铺名、
  `--break=no-ns` 丢 ns）——两条都必须让守门断言变红。 · 证据：（待填：正常 + 两条 break 的原始输出）
- [ ] 1.3 产品侧模板归位（同一规则：点开头或带 ns）：`cmd-review.sh` 的 `teamsmith-review-queue.*` 与
  `p91-merge3.*`、`common.sh` 的 `teamsmith-inotify-probe.*`、`cmd-watch.sh` 的 `teamsmith-npm.*`、
  `tests/panel-cpu.sh` 的 `p12cpu.*`、`tests/panel-knobs.sh` 的 `panel-knobs.*`。 · 证据：（待填：逐个模板的改后原文）
- [ ] 1.4 `tests/smoke.sh`：选段过滤副本 `teamsmith-select.$$.sh` 与其它每运行标记按同一规则；
  `--keep`/P223 与 P70 里对平铺名的点名叫法随之更新（`flip-m33.sh`、`flip-p158.sh` 的匹配器同批）。
  · 证据：（待填：改后点位 + 两处匹配器原文）
- [ ] 1.5 scenario「根带 ns + 平铺模式够不着」的夹具（落在新段 `34c`）：私有 `TMPDIR` 下起一套夹具运行，
  列它**为自己**直接在临时根里创建的条目，逐条判「点开头或带 ns」，并用**契约点名的那一族平铺模式**匹配
  （这些条目必须零命中；唯一的例外是发布锁路径，它由 §2 的要求管，本断言的名单里显式排除它并在断言文案里点名）；
  红侧 `--break=flat-name` → 根回到平铺名 → 命中 → 断言红并点名路径；还原后绿。 · 证据：（待填：三份原始输出）
- [ ] 1.6 scenario「同项目 worktree 共享 ns、第二个仓库不同 ns，且外来根不被当候选」的夹具（`34c`）：
  两个 worktree + 一个第二仓库各建一个根 → 断言 ns 关系、标记里的 `ns=`、`--status` 把第二仓库的根归为外来。
  · 证据：（待填：`--status` 输出尾 + 三份标记原文）

## 2 伴生锁与兼容声明（规格 #The gate's lock is identified, and losing it stops the run loudly）

- [ ] 2.1 `scripts/lib/gate-lock.sh`：加伴生路径推导（同行同目录、basename + `.machine`、**点开头**）与一个纯函数单测；
  断言默认路径与私有 `TEAM_SMOKE_LOCK` 两种输入下的推导结果。 · 证据：（待填：两个输入的输出）
- [ ] 2.2 `tests/smoke.sh`：取锁顺序固定为**发布路径 → 伴生锁**；发布路径不存在则创建（旧写入者也是这么建的）；
  写清并实现 **no-unlink**：持有者绝不删除或改名自己持有的锁文件（收尾只删自己的**记录**）。
  反侧断言：正常跑完两把锁文件都还在、件内 inode 未变。 · 证据：（待填：前后 `stat` 输出 + 正常跑日志尾）
- [ ] 2.3 `cmd-review.sh` 的取锁/等待改走同一实现（顺序、兼容声明、记录位置全部一致）。
  · 证据：（待填：`team review` 夹具的运行记录原文）
- [ ] 2.4 取锁时刷伴生锁 mtime（按 age 的临时清理器不该删活锁）；断言 `mtime >= claimed`。
  · 证据：（待填：前后 `stat -c %Y` 输出）
- [ ] 2.5 发布路径丢失的处置（只点名 + 记录、**不停跑**）与其文案（与伴生锁的两条文案可区分）；夹具：只删发布路径 →
  运行继续、有结果行、证据里有那一节；反向：删伴生锁 → 停跑。 · 证据：（待填：两份日志尾 + 证据文件两节原文）

## 3 身份登记与守卫

- [ ] 3.1 身份登记进 run 记录：`lock_dev_ino=<dev:ino>`、`lock_identity=fd|path`（用哪一种**如实写**），
  并写明取锁瞬间窗口的处置（D3/design §4）。 · 证据：（待填：记录原文）
- [ ] 3.2 守卫接上**既有哨兵**（同一个后台进程、同一 0.2s 节奏、同一份 `$TMP` 之外的证据文件、同一个安全点停跑路径与
  退出码 2）：多看一条前提「伴生锁还是不是持有的那个文件」；文案区分「已不在」/「已被替换（两个身份）」；
  `KEEP=1` 留现场；证据文件里新增一节 lock 现场（时刻、期望/实测身份、最后段落、锁路径实测持有者、ns/工作树/席位）。
  · 证据：（待填：实现点位 + 一次真事的证据文件原文脱敏）
- [ ] 3.3 红侧①（**删锁**）：持有者起来（私有锁）→ 外部 `rm` 伴生锁 → 有界时间内一行点名 + 证据 + 退出码 2 +
  **没有结果行**；`--break=no-lock-guard` → 同场景不点名也不停 → 断言红；还原后绿。
  · 证据：（待填：红/绿两轮原始输出）
- [ ] 3.4 红侧②（**换锁**）：同上，但用「unlink + 新建」与「`mv` 覆盖」两种形状；断言文案是「已被替换」并带两个身份，
  且与①的文案可区分；shadow 同①。 · 证据：（待填：两份原始输出）
- [ ] 3.5 反向对照（不许误报）：正常跑一套、随后再跑一套（第一套退出后）→ 两套都**没有**锁身份行、都有结果行与
  原退出码；伴生锁 inode 前后相同；发布路径仍在。 · 证据：（待填：两套日志尾 + 两处 `stat`）

## 4 等待者与入场检查

- [ ] 4.1 等待者改**有界轮询**（短 `flock -n`），每轮重新解析路径；发现「我等的那把变了」就印一行（两个身份）再继续等；
  P281 的上限算式、marker 语义（P66）、超限/加锁失败的文案与退出码**一字不改**（逐字对照 diff）。
  · 证据：（待填：diff + 等待者日志原文）
- [ ] 4.2 入场检查：拿到锁后读 `<companion>.runs/*`，活的 `top` 登记记着**另一个身份** ⇒ 点名那个运行 + 席位 + 工作树 +
  两个身份 + 「互斥已断」+ **不跑套件**（无结果行、marker 不在、退出码 2）；`--break=no-entry-check` → 第二套照跑 → 断言红。
  · 证据：（待填：红/绿两轮原始输出）
- [ ] 4.3 旧版本记录的打印：现场造一个只有 `<published>.holder`（`<ISO> pid=… cmd=smoke.sh` 形状）的持有者 →
  等待者/入场检查按「有多少字段打多少、缺的写 `?`、标 `version=legacy`」打印，绝不出现 `holder unknown`。
  · 证据：（待填：等待者日志原文）

## 5 静态闸、清扫面与文档

- [ ] 5.1 `tmp-hygiene.sh --lint`：规则扩成「直接落在解析后临时根上的每一个模板：点开头或带 ns；根还要在 owned 家族里」，
  作用域扩到**夹具与产品自己的临时模板**（跳过扫描器自身与 `$TMP/…` 嵌套根）；finding 仍 `<file>:<line>`、退出码 1；
  红侧两份副本：一份写死 `/tmp`（既有形状），一份保留家族前缀但丢 ns；还原后绿（并打印检查了多少个模板）。
  · 证据：（待填：三份原始输出）
- [ ] 5.2 `tmp-hygiene.sh`：`--status` 加 ns 列、把**锁对**按角色报出（运行互斥 / 兼容声明 / 运行注册）、
  历史平铺根标 `legacy`；`--sweep` 对这三样一个都不碰（夹具：三样 + 一个陈旧平铺根，收完只剩根被回收）。
  · 证据：（待填：`--status`/`--sweep --age 0` 输出尾 + 收完后 `ls`）
- [ ] 5.3 `references/protocol.md` §9b-2：两把锁的角色与顺序、no-unlink 纪律、**安全清理入口**
  （`tmp-hygiene.sh --sweep`，或只删自己项目的 `teamsmith-<kind>-<ns>.*`；绝不写针对共享前缀的 `rm -rf`）、
  过渡期口径（旧写入者只经发布路径串行；它被删时只印不停）。 · 证据：（待填：段落原文）

## 6 红侧与回归、段账

- [ ] 6.1 六条 scenario 全绿 + 两条 shadow 红：把 §3.3/3.4/4.2 与 §1.5 的四份红/绿原始输出整理成报告里的一节
  （**这就是本任务的翻转证据**：红在前、绿在后，或 shadow 开→红、还原→绿）。 · 证据：（待填）
- [ ] 6.2 `smoke.sh --select 34,34b` 零回退：P281 的既有断言逐条对照（diff），计数与判定一条不改。
  · 证据：（待填：改前/改后两轮输出尾 + diff）
- [ ] 6.3 `tests/section-budgets.tsv` 的 `34c`/`34d` 行按**实测**补 band（`max(band×4, 60)` 公式不变）、
  `tests/section-paths.tsv` 两行登记涉及路径；`--select 0e` 绿、`section-select.sh --check` 绿。
  · 证据：（待填：改前/改后实测用时 + 两条输出尾）

## 7 验收与交付

- [ ] 7.1 跑齐 proposal「Acceptance」的全部命令（含投影自证），报告贴真实命令、rc 与输出尾。
  · 证据：（待填）
- [ ] 7.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 6.1 节的红/绿原始输出就是翻转证据；
  写明未测项与「诚实边界」（design §10：无不可删的锁、`source=path` 的窗口、升级过渡期、`TMPDIR` 覆盖的残留、
  守卫不能证明是谁换的/有人读过那行、容器临时根、无 git 检出的 ns 各自为政、历史 111 个平铺残留不清理）。
- [ ] 7.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；本仓库 local 模式：分支留本地，
  `team notify pm` 一行交付说明。

## 8 独立验证（另一席位，不是 apply 作者）

- [ ] 8.1 在独立克隆上重跑 `smoke.sh --select 34c,34d`、`--select 34,34b`、`--select 0e`、
  `tmp-hygiene.sh --self-test`、`tmp-hygiene.sh --lint`，确认既有断言零回退 + 六场景全绿。
  · 证据：（待填：独立日志）
- [ ] 8.2 逐条重做两条红侧的 shadow 与还原（不是只复跑绿侧），并**自设计反例**（至少三条，从这批里挑或自造）：
  ① 先删伴生锁再让第三套进场 → 入场检查必须拒绝，且拒绝行里两个身份都对；
  ② 只删发布路径 → 运行**继续**（不停跑），但证据里有那一节；
  ③ 把登记里的身份改掉一半（记录与路径不一致）→ 入场检查/等待者的判定方向不许反转；
  ④ FAST / `TEAM_SMOKE_NO_LOCK=1` 档不受影响（不取锁、不检查，且不因为「没有身份」而误报）；
  ⑤ 把 `--lint` 指的副本换成「家族内无 ns」→ 必须点名。
  · 证据：（待填：反例输出）
- [ ] 8.3 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。
  · 证据：`docs/team/reviews/<ID>.md`
