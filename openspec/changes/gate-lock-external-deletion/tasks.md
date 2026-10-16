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

- [x] 0.1 读 PM 的提案复核 `docs/team/reviews/gate-lock-external-deletion-proposal.md`，把裁定点 D1–D7 的结论摘进报告；
  与提案不同的裁定按其改写判定与场景：D1 若裁「锁进本项目状态目录」或 D2 若裁「不保留兼容声明」，则 design §2/§3 与
  ADDED 要求里相应句子按裁定重写；D4 若裁「性能锁留给下一批」，则 ADDED 最后一段那句按裁定删/改并记 finding；
  D5（ns 形状）与 D6（`--lint` 作用域）若改，按裁定改 ADDED/916 的正文与夹具。**六条 scenario 的方向与命名规则不变**。 · 证据：P303 按事实勾：复核记录 `docs/team/reviews/gate-lock-external-deletion-proposal.md` 判定 ACCEPTED、D1–D7 全按推荐 ⇒ 无改判、无重写；落点在 P288 报告 §0.1 表，P303 逐条核到实物（34d①③④⑥⑦、34c①–④、perf.sh 同一实现、`--lint` 32 模板、34c/34d 两段在位）；落地提交 6f1ed69d
- [x] 0.2 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec
  && (cd /tmp/<x> && openspec validate --all --strict && openspec archive -y gate-lock-external-deletion
  && openspec validate --all --strict)` 必须绿；逐条核对 3 条 MODIFIED 的既有正文与既有 scenario **逐字保留**、
  ADDED 的标题与六条 scenario 齐全。 · 证据：P303 按事实勾：独立树投影 rc=0 —— validate 22/0 → `archive -y gate-lock-external-deletion`（archived as `2026-10-16-gate-lock-external-deletion`）→ validate 21/0；三条 MODIFIED 的场景数 4→6 / 5→5 / 2→3、既有场景标题零丢失，ADDED 标题与六场景齐全（P303 脚本逐条比对，日志 /var/tmp/p303/acc/projection.log）
- [x] 0.3 冻结**改动前**基线并抄进报告：`smoke.sh --select 34,34b` 的 ✓/✗ 计数与用时；
  `tmp-hygiene.sh --lint` 的「检查了 N 个模板」与 rc；`ls -d "${TMPDIR:-/tmp}"/teamsmith-* | wc -l`；
  design §1.2/§1.3/§1.4 三条实测的复跑（私有锁、私有 `TMPDIR`）；以及**两条红侧的改动前形状**：今天锁被删/被换之后
  运行既不点名也不停（这正是 `--break=` 关闭守卫时要复现的形状）。 · 证据：P303 按事实勾：改动前检出上的 ✓/✗ 计数、`--lint` 模板数与 glob 计数在 P288 报告 §0.3（34,34b ✓153 ✗1 rc=1；lint 15 模板 rc=0；teamsmith-* 99 / review-* 1），两条红侧的改动前形状在该报告 §Flip evidence（leg2）；报告里缺的**用时**与 design §1.2–1.4 复跑由 P303 在改动前提交 `b77af9e1` 的独立 clone 上补测：`--select 34,34b` ✓154 ✗0 rc=0（34 52s / 34b 59s，整条 121s）、lint 15 模板 rc=0、glob teamsmith-* 98 / review-* 1；design §1.2/1.3/1.4 三条原样复跑（私有 TMPDIR，原文见 P303 报告 §0.3）

## 1 命名与归属（规格 #A fixture's temp root resolves TMPDIR, carries an owned name, and is reclaimed）

- [x] 1.1 `scripts/lib/common.sh`：加 `team_project_ns()` —— 纯函数、不读配置、不依赖检出形状：
  `ns = <slug>-<hash8>`，slug 取 `TEAM_PROJECT`（有则用）否则主检出目录名，只保留 `[A-Za-z0-9_]`、截断 24；
  hash8 = 主检出 realpath 的 sha256 前 8 位；主检出优先 `git rev-parse --path-format=absolute --git-common-dir` 的父目录，
  git 不可用时退到 skill 自己的仓库根。断言三向：同项目两个 worktree 一致、第二个仓库不同、无 git 的检出不报错。
  · 证据（P305 按事实勾）：`34c` 新增**第三向**断言 —— 非 git 检出（slug 取目录名，`ns=nogit-<hash8>`）与 PATH 无 git（连 sha256 工具也没有 → 退 `nogit-00000000`）都 rc=0、stderr 干净、形状仍是 `<slug>-<hash8>`；与既有两向（同项目两 worktree 同 ns / 第二仓库不同 ns）同批跑绿。牙：同一探针指向一份让 `team_project_ns` 失败的暂存副本 → `rc=1 boom`。详见 P305 报告 §4.1 与 `smoke.sh` §34c
- [x] 1.2 `tests/lib/tmp-root.sh`：根模板改 `"$base/${TMP_ROOT_FAMILY_PREFIX}${kind}-${ns}.XXXXXX"`；owner 标记与
  run 台账头各加 `ns=`；`tmp_root_path_ok` 与 `--self-test` 同步；自检加两条红侧（`--break=flat-name` 回到平铺名、
  `--break=no-ns` 丢 ns）——两条都必须让守门断言变红。 · 证据：P303 按事实勾：模板 `teamsmith-<kind>-<ns>.XXXXXX`（tmp-root.sh:178）、owner 标记与台账头带 `ns=`（:190 / :140）、`tmp_root_path_ok` 认 ns（:115）；P303 复跑 `lib/tmp-root.sh --self-test` ✓19 ✗0 rc=0，`--break=flat-name` ✓17 ✗2 rc=1（根名两条红）、`--break=no-ns` ✓17 ✗2 rc=1（标记/台账两条红）
- [x] 1.3 产品侧模板归位（同一规则：点开头或带 ns）：`cmd-review.sh` 的 `teamsmith-review-queue.*` 与
  `p91-merge3.*`、`common.sh` 的 `teamsmith-inotify-probe.*`、`cmd-watch.sh` 的 `teamsmith-npm.*`、
  `tests/panel-cpu.sh` 的 `p12cpu.*`、`tests/panel-knobs.sh` 的 `panel-knobs.*`。 · 证据：P303 按事实勾：六个模板逐个在场 —— cmd-review.sh:381 `teamsmith-p91-merge3-$(team_project_ns).XXXXXX`、:1097 `teamsmith-review-queue.$(team_project_ns).XXXXXX`；common.sh:1243 `teamsmith-inotify-probe.${ns}.XXXXXX.js`；cmd-watch.sh:244 `teamsmith-npm.$(team_project_ns).XXXXXX`；panel-cpu.sh:161 `teamsmith-p12cpu.$(tmp_root_ns).XXXXXX`；panel-knobs.sh:39 `teamsmith-panel-knobs.$(team_project_ns).XXXXXX`；P303 复跑 `tmp-hygiene.sh --lint` 32 模板 rc=0
- [x] 1.4 `tests/smoke.sh`：选段过滤副本 `teamsmith-select.$$.sh` 与其它每运行标记按同一规则；
  `--keep`/P223 与 P70 里对平铺名的点名叫法随之更新（`flip-m33.sh`、`flip-p158.sh` 的匹配器同批）。
  · 证据：P303 按事实勾：smoke.sh:216 选段副本 `teamsmith-select.$(team_project_ns).$$.sh`、:595 队列标记 `teamsmith-smoke-queue.$(team_project_ns).XXXXXX`（mktemp 失败才退点开头）；flip-m33.sh:128–129 与 flip-p158.sh:138 的匹配器同时认 `<ns>` 与旧平铺两种形状
- [x] 1.5 scenario「根带 ns + 平铺模式够不着」的夹具（落在新段 `34c`）：私有 `TMPDIR` 下起一套夹具运行，
  列它**为自己**直接在临时根里创建的条目，逐条判「点开头或带 ns」，并用**契约点名的那一族平铺模式**匹配
  （这些条目必须零命中；唯一的例外是发布锁路径，它由 §2 的要求管，本断言的名单里显式排除它并在断言文案里点名）；
  红侧 `--break=flat-name` → 根回到平铺名 → 命中 → 断言红并点名路径；还原后绿。 · 证据：P303 按事实勾：34c 段（smoke.sh:16854–17033）逐条判「点开头或带 ns」+ 契约形状 `teamsmith-smoke.*` 零命中、发布锁路径显式排除并在断言文案里点名；P303 复跑 `--select 34c,34d` → 34c ✓20 ✗0（22s）、总 ✓142 ✗0 rc=0（含 `--break=flat-name` 红侧那一对断言）；P288 报告 §Flip evidence 1
- [x] 1.6 scenario「同项目 worktree 共享 ns、第二个仓库不同 ns，且外来根不被当候选」的夹具（`34c`）：
  两个 worktree + 一个第二仓库各建一个根 → 断言 ns 关系、标记里的 `ns=`、`--status` 把第二仓库的根归为外来。
  · 证据：P303 按事实勾：34c④（smoke.sh:16937–17032）两个 worktree 同 ns、第二仓库不同 ns、两个根的标记各带自己的 `ns=`、`--status` 把第二仓库的根归为 `[foreign]` 且不进候选；P303 复跑同一段（34c ✓20 ✗0）

## 2 伴生锁与兼容声明（规格 #The gate's lock is identified, and losing it stops the run loudly）

- [x] 2.1 `scripts/lib/gate-lock.sh`：加伴生路径推导（同行同目录、basename + `.machine`、**点开头**）与一个纯函数单测；
  断言默认路径与私有 `TEAM_SMOKE_LOCK` 两种输入下的推导结果。 · 证据（P305 按事实勾）：`34d` 2.1 五条断言 —— 默认路径 → `<TMPDIR>/.teamsmith-smoke.lock.machine`、私有 `TEAM_SMOKE_LOCK` 的两种推导、伴生名点开头；`--select 34,34b,34c,34d,0e` 全绿（✓314 ✗0）。详见 P305 报告 §4.2
- [x] 2.2 `tests/smoke.sh`：取锁顺序固定为**发布路径 → 伴生锁**；发布路径不存在则创建（旧写入者也是这么建的）；
  写清并实现 **no-unlink**：持有者绝不删除或改名自己持有的锁文件（收尾只删自己的**记录**）。
  反侧断言：正常跑完两把锁文件都还在、件内 inode 未变。 · 证据：P303 按事实勾：顺序 = 发布路径（fd 8）→ 伴生锁（fd 9）（gate-lock.sh:141–159 `gate_lock_acquire_pair`，smoke.sh:480 起）；no-unlink：收尾只删自己的 `<companion>.holder` / `<companion>.runs/$$.run`（smoke.sh:1286–1298），两把锁文件不删；反侧断言 34d④（伴生锁 inode 前后相同 + 发布路径仍在）与 34d⑥（跑完两把锁文件都在）；P303 复跑 34d ✓101 ✗0
- [x] 2.3 `cmd-review.sh` 的取锁/等待改走同一实现（顺序、兼容声明、记录位置全部一致）。
  · 证据：P303 按事实勾：cmd-review.sh:1075–1100 起走同一套（`gate_lock_companion_path`、记录位置、同一顺序、`lock_identity/lock_dev_ino`、入场检查、跑完复核）；34d⑦ 真跑一次 `team review`（门禁运行中删锁 → rc≠0、判定 FAIL、`gate mutex broken` 旗标、排队三键与 `team_review_verdict` 不变）；flip-p287-lock leg3 把复核改成 `if false` → 同现场判 PASS（红侧），P303 复跑该腿三条断言 ✓
- [x] 2.4 取锁时刷伴生锁 mtime（按 age 的临时清理器不该删活锁）；断言 `mtime >= claimed`。
  · 证据（P305 按事实勾）：`34d` 2.4 断言 `mtime >= claimed` —— 实测 `改动前 1792144628 → 取锁后 1792151830 ≥ claimed=1792151828`；两层牙：① 真变异（删掉 `touch "$SMOKE_LOCK" "$SMOKE_LOCK_COMPANION"` 一行）→ `--select 34d` rc=1、2.4 断言红；② 合成输入演示 `假 → 真`。详见 P305 报告 §4.3
- [x] 2.5 发布路径丢失的处置（只点名 + 记录、**不停跑**）与其文案（与伴生锁的两条文案可区分）；夹具：只删发布路径 →
  运行继续、有结果行、证据里有那一节；反向：删伴生锁 → 停跑。 · 证据：P303 按事实勾：两条文案可区分 —— 发布路径 `发布锁路径（兼容声明）丢失 …（互斥仍在伴生锁上，只记录不停跑）`（smoke.sh:1176）与伴生锁 `已不在 / 已被替换`（:1146–1149）；34d⑤b（只删发布路径 → rc=0、有结果行、证据文件里有那一节）与 34d①（删伴生锁 → exit 2、无结果行），P303 复跑 34d ✓101 ✗0

## 3 身份登记与守卫

- [x] 3.1 身份登记进 run 记录：`lock_dev_ino=<dev:ino>`、`lock_identity=fd|path`（用哪一种**如实写**），
  并写明取锁瞬间窗口的处置（D3/design §4）。 · 证据：P303 按事实勾：记录末两字段 `lock_identity=fd|path`、`lock_dev_ino=<dev:ino>`（gate-lock.sh:268–303；`gate_lock_claim_identity` :161–170 从持有者自己的 /proc 读 fd 身份，读不到才如实写 `path`）；取锁瞬间窗口的处置写在 gate-lock.sh:100–160 的注释（本进程持 fd ⇒ 窗口关掉；D3/design §4）；34d⑥ 断言两条字段 + `kind=top` + 身份等于路径身份，P303 复跑 ✓
- [x] 3.2 守卫接上**既有哨兵**（同一个后台进程、同一 0.2s 节奏、同一份 `$TMP` 之外的证据文件、同一个安全点停跑路径与
  退出码 2）：多看一条前提「伴生锁还是不是持有的那个文件」；文案区分「已不在」/「已被替换（两个身份）」；
  `KEEP=1` 留现场；证据文件里新增一节 lock 现场（时刻、期望/实测身份、最后段落、锁路径实测持有者、ns/工作树/席位）。
  · 证据：P303 按事实勾：同一个 0.2s 哨兵（smoke.sh:1236–1243 在 `smoke_tmp_tripwire` 里多看一条前提）、同一停跑路径（`smoke_lock_guard` → `smoke_lock_fire`：一行点名 + `KEEP=1` + exit 2，:1215–1234）、同一份 `$TMP` 之外的证据文件（`smoke_lock_diag` :1179–1197：时刻、期望/实测身份、发布路径状态、锁路径上的实测持有者、ns/工作树/席位、最后段落）；真事证据文件原文见 V53 §1.3；P303 复跑 flip-p287-lock leg0 12 条断言 ✓
- [x] 3.3 红侧①（**删锁**）：持有者起来（私有锁）→ 外部 `rm` 伴生锁 → 有界时间内一行点名 + 证据 + 退出码 2 +
  **没有结果行**；`--break=no-lock-guard` → 同场景不点名也不停 → 断言红；还原后绿。
  · 证据：P303 按事实勾：34d① 绿侧（一行「已不在」+ 期望身份 + `$TMP` 之外证据 + exit 2 + 无结果行）与 shadow `--break=no-lock-guard`（不点名、跑完 rc=0）；flip-p287-lock leg0/leg1 两条腿 ✓（P303 复跑：leg0 12 条、leg1 4 条全绿）。注：该夹具的 leg2「改动前树」对照腿本轮 red，见 P303 报告 F1 —— 与本条的绿侧/shadow 不是同一条腿
- [x] 3.4 红侧②（**换锁**）：同上，但用「unlink + 新建」与「`mv` 覆盖」两种形状；断言文案是「已被替换」并带两个身份，
  且与①的文案可区分；shadow 同①。 · 证据：P303 按事实勾：34d② 两种形状（`rm`+新建、`mv` 覆盖）各断言「已被替换」+ 两个身份、与「已不在」可区分、停跑无结果行，两条 shadow 腿各静默；P303 复跑 34d ✓101 ✗0（含 34d② 全部 12 条）
- [x] 3.5 反向对照（不许误报）：正常跑一套、随后再跑一套（第一套退出后）→ 两套都**没有**锁身份行、都有结果行与
  原退出码；伴生锁 inode 前后相同；发布路径仍在。 · 证据：P303 按事实勾：34d④ 两套顺序运行 → 两套都无锁身份行、都有结果行、rc=0/0、伴生锁 inode 前后相同、发布路径仍在（smoke.sh:17239–17261）；P303 复跑 34d ✓101 ✗0

## 4 等待者与入场检查

- [x] 4.1 等待者改**有界轮询**（短 `flock -n`），每轮重新解析路径；发现「我等的那把变了」就印一行（两个身份）再继续等；
  P281 的上限算式、marker 语义（P66）、超限/加锁失败的文案与退出码**一字不改**（逐字对照 diff）。
  · 证据（P305 按事实勾）：**冻结集合逐字对照** —— `gate_lock_cap` 与 `team_review_verdict` 函数体 diff **为空**；排队行/超限行两条 `printf` 逐字相同（只差行首缩进）；整份 `smoke.sh` 的 exit 码集合逐字相同（`0 1 2 3 5 7 64 90 124 130`）、锁/排队路径上 `{1,2}` 相同；P66 的 marker 语义由 `34b①` 四条断言持续钉住（本轮 ✓）。V53 §2.2 的例外（旧 `flock --close` 包装器两条文案随包装器消失，`grep` 命中 0/0）与**现行为**现场（外部占锁 → 超限 rc=2 + 一行点名；锁文件建不了 → `no_lock=1` 可见降级 rc=0）逐字记在 P305 报告 §3
- [x] 4.2 入场检查：拿到锁后读 `<companion>.runs/*`，活的 `top` 登记记着**另一个身份** ⇒ 点名那个运行 + 席位 + 工作树 +
  两个身份 + 「互斥已断」+ **不跑套件**（无结果行、marker 不在、退出码 2）；`--break=no-entry-check` → 第二套照跑 → 断言红。
  · 证据：P303 按事实勾：入场检查 `gate_lock_entry_conflict`（gate-lock.sh:211–231）读 `<companion>.holder` + `<companion>.runs/*`，活 top 登记身份不同 ⇒ 点名运行/席位/工作树 + 两个身份 + 「互斥已断」+ 不跑套件 + exit 2（smoke.sh:576–590；marker 由构造保证不在 —— 它写在入场检查**之后**）；34d③ 绿侧 + `--break=no-entry-check` shadow（第二套照跑 rc=0）；P303 复跑 34d ✓101 ✗0
- [x] 4.3 旧版本记录的打印：现场造一个只有 `<published>.holder`（`<ISO> pid=… cmd=smoke.sh` 形状）的持有者 →
  等待者/入场检查按「有多少字段打多少、缺的写 `?`、标 `version=legacy`」打印，绝不出现 `holder unknown`。
  · 证据：P303 按事实勾：`gate_lock_describe_one` 缺字段写 `?` 不编（gate-lock.sh:364–384）；34d⑤ 现场造 `<published>.holder`（`<ISO> pid=… cmd=legacy-holder`）→ 断言 `version=legacy` 与 `kind=? pid=… agent=? worktree=? 已跑 ?s expected=? bound=?`、绝不出现「持有者未知」；34b② 同形；P303 复跑 34d/34b ✓101/✓101 ✗0

## 5 静态闸、清扫面与文档

- [x] 5.1 `tmp-hygiene.sh --lint`：规则扩成「直接落在解析后临时根上的每一个模板：点开头或带 ns；根还要在 owned 家族里」，
  作用域扩到**夹具与产品自己的临时模板**（跳过扫描器自身与 `$TMP/…` 嵌套根）；finding 仍 `<file>:<line>`、退出码 1；
  红侧两份副本：一份写死 `/tmp`（既有形状），一份保留家族前缀但丢 ns；还原后绿（并打印检查了多少个模板）。
  · 证据：P303 按事实勾：规则 = 直接落在解析后临时根上的每个 mktemp 模板「点开头或带 ns」、根还要在 owned 家族里（tmp-hygiene.sh:616–697），作用域整棵 skill 树、跳过自身与嵌套根；P303 复跑 `--lint` → 检查了 32 个模板、rc=0；`--self-test` ⑦ 三条红侧（写死 /tmp、家族前缀在但丢 ns、平铺每运行模板）各 rc=1 并点名 `file:line`；两份素材在 tests/fixtures/p287/{lint-hardcoded,lint-no-ns}.sh.in
- [x] 5.2 `tmp-hygiene.sh`：`--status` 加 ns 列、把**锁对**按角色报出（运行互斥 / 兼容声明 / 运行注册）、
  历史平铺根标 `legacy`；`--sweep` 对这三样一个都不碰（夹具：三样 + 一个陈旧平铺根，收完只剩根被回收）。
  · 证据（P305 按事实勾）：`--status` 把锁对按角色报出（`[machine 运行互斥]` / `[published 兼容声明]` / `[records 运行注册]`），并对**历史平铺根**在归属行追加 `legacy（P287 之前的平铺名，没有 ns）`；现场：陈旧平铺根 + 锁对三样 + 两个 `.holder` → `--sweep --age 0` 的清单只有那一项 `[reclaim]`，收完 `ls -a` 里锁对三样全在、平铺根没了。守卫：自检 ① 两条断言（平铺根必须带 / 带 ns 的根不许带）+ ⑥ 扩成「三样 + 一个陈旧平铺根，收完只剩根被回收」，`--break=lock` 红侧会让 ⑥ 变红。详见 P305 报告 §5
- [x] 5.3 `references/protocol.md` §9b-2：两把锁的角色与顺序、no-unlink 纪律、**安全清理入口**
  （`tmp-hygiene.sh --sweep`，或只删自己项目的 `teamsmith-<kind>-<ns>.*`；绝不写针对共享前缀的 `rm -rf`）、
  过渡期口径（旧写入者只经发布路径串行；它被删时只印不停）。 · 证据（P305 按事实勾）：`references/protocol.md` §9b-2 三处 —— ① 根模板改 `teamsmith-<kind>-<ns>.XXXXXX`（含 ns 推导、标记/台账/`--status`、`legacy` 标注）；② 安全清理入口写全（`tmp-hygiene.sh --status` → `--sweep`，或只删自己项目的 `teamsmith-<kind>-<ns>.*`；**绝不**对共享前缀写 `rm -rf`，并点名 2026-10-15 事故的形状）；③ perf 锁的记录位置改 `<companion>.holder`（落地如此，原文写 `<lock>.holder`）。段落原文见提交 diff 与 P305 报告 §5

## 6 红侧与回归、段账

- [x] 6.1 六条 scenario 全绿 + 两条 shadow 红：把 §3.3/3.4/4.2 与 §1.5 的四份红/绿原始输出整理成报告里的一节
  （**这就是本任务的翻转证据**：红在前、绿在后，或 shadow 开→红、还原→绿）。 · 证据：P303 按事实勾：P288 报告 §Flip evidence（命名面 leg0/leg1/leg2、身份面 leg0/leg1/leg2、P281 既有 34/34b 不回退）+ §0.2 六场景落点表；P303 在交付树上重跑 —— `--select 34c,34d` ✓142 ✗0、`--select 34,34b` ✓158 ✗0、flip-p287-name FLIP 全绿、flip-p287-lock 的 leg0/leg1/leg3 全绿（leg2 是「改动前树」对照腿，本轮 red，见 P303 报告 F1：夹具选择器缺陷，不是六条场景本身）
- [x] 6.2 `smoke.sh --select 34,34b` 零回退：P281 的既有断言逐条对照（diff），计数与判定一条不改。
  · 证据：P303 按事实勾：P303 对 34/34b 区段逐条对照断言标签 —— 既有断言只在 5 处随记录位置机械改写（`<lock>.runs` → `<companion>.runs`、`holder` 加「伴生锁边上」），无一条既有断言消失或改判；新增 4 条（34b② 的 `lock_identity`、`lock_dev_ino`、发布路径边上不写记录、兼容声明只读）与报告 §0.2⑥ 相符；P303 复跑 `--select 34,34b` → ✓158 ✗0 rc=0（34 ✓36 58s、34b ✓101 65s），对照 P288 报告 §0.3 的改动前 ✓153 ✗1
- [x] 6.3 `tests/section-budgets.tsv` 的 `34c`/`34d` 行按**实测**补 band（`max(band×4, 60)` 公式不变）、
  `tests/section-paths.tsv` 两行登记涉及路径；`--select 0e` 绿、`section-select.sh --check` 绿。
  · 证据：P303 按事实勾：section-budgets.tsv:123–124 → 34c band 30 / 34d band 240（P288 实测 25s/156s），公式 max(⌈band×4⌉,60) ⇒ 120/960；section-paths.tsv:123–124 两行登记涉及路径；P303 复跑 `--select 0e` ✓44 ✗0 rc=0（59s）、`section-select.sh --check` ok 8 bad 0 rc=0、`section-guard.sh --budget-check`（135/135 段）与 `--loop-check`（85/85）全过

## 7 验收与交付

- [x] 7.1 跑齐 proposal「Acceptance」的全部命令（含投影自证），报告贴真实命令、rc 与输出尾。
  · 证据（P305 按事实勾）：P305 报告 §6 的表（命令 / rc / 输出尾）—— 全绿项：flip-p287-lock 绿侧、flip-p287-name、`--select 34,34b,34c,34d,0e`（✓314 ✗0）、`tmp-hygiene.sh --self-test`/`--lint`、`section-select.sh --check`、`openspec validate --all --strict`（21/0）、`ledger-ban`（hits=0）、投影自证（archive + validate → 20/0）；按预期非零项：三条夹具红侧 rc=1、外部占锁超限 rc=2；`spec-refs.sh --check` rc=1 是**既有**（改动前基线 `238c4c6a` 与分支基点 `3029115d` 同一条、独立克隆复现）。**全量**另跑一次（`bash skills/teamsmith/tests/smoke.sh`，rc=2）：`0i` 与 `10 · review` 两个红灯，都在**改动前的基线** `238c4c6a`（独立克隆）上同形同因复现 —— 与本任务无关（细节见报告 §6.4）；本任务改动的段在选段与全量里都跑到且全绿。
- [x] 7.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 6.1 节的红/绿原始输出就是翻转证据；
  写明未测项与「诚实边界」（design §10：无不可删的锁、`source=path` 的窗口、升级过渡期、`TMPDIR` 覆盖的残留、
  守卫不能证明是谁换的/有人读过那行、容器临时根、无 git 检出的 ns 各自为政、历史 111 个平铺残留不清理）。
  · 证据（P305 按事实勾）：`docs/team/reports/P305-dev-bob.md` —— 结论先行；§6 逐条命令/rc/输出尾；§2 的红/绿原始输出即翻转证据；§8 逐条对 design §10 的**八条**诚实边界；§6.2 点名未跑的 126 段。
- [x] 7.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；本仓库 local 模式：分支留本地，
  `team notify pm` 一行交付说明。
 · 证据：P303 按事实勾：分支提交走 Conventional Commits（`feat(P288)` / `fix(P288)` / `docs(P288)`）+ `Agent: dev-bob` trailer（03fe46d7、2115b230、18e971d0、ad928a70）；local 模式不留远端，分支留在本地（`task/P288-gate-lock-external-deletion-apply` 仍在），PM 复验后 squash 落地 6f1ed69d；交付通知的可见后果 = PM 冻结并派 V53（d3806d1e）→ V53 两轮记录

## 8 独立验证（另一席位，不是 apply 作者）

- [x] 8.1 在独立克隆上重跑 `smoke.sh --select 34c,34d`、`--select 34,34b`、`--select 0e`、 · 证据（PM 按事实勾）：V53 两轮在独立克隆上重跑并留原始输出：`docs/team/reviews/V53.md`
  `tmp-hygiene.sh --self-test`、`tmp-hygiene.sh --lint`，确认既有断言零回退 + 六场景全绿。
  · 证据：（待填：独立日志）
- [x] 8.2 逐条重做两条红侧的 shadow 与还原（不是只复跑绿侧），并**自设计反例**（至少三条，从这批里挑或自造）： · 证据（PM 按事实勾）：V53 两轮逐条重做 shadow 与还原并自设反例（含同树 A/B 与旧正则变异）：`docs/team/reviews/V53.md`
  ① 先删伴生锁再让第三套进场 → 入场检查必须拒绝，且拒绝行里两个身份都对；
  ② 只删发布路径 → 运行**继续**（不停跑），但证据里有那一节；
  ③ 把登记里的身份改掉一半（记录与路径不一致）→ 入场检查/等待者的判定方向不许反转；
  ④ FAST / `TEAM_SMOKE_NO_LOCK=1` 档不受影响（不取锁、不检查，且不因为「没有身份」而误报）；
  ⑤ 把 `--lint` 指的副本换成「家族内无 ns」→ 必须点名。
  · 证据：（待填：反例输出）
- [x] 8.3 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。 · 证据（PM 按事实勾）：PM 据 V53（第二轮 PASS）判过门；**同时**勾选这一步翻出 8 项留空与一条真缺陷 F1，已立 P305 处理，故本变更**归档推迟到 P305 之后**
  · 证据：`docs/team/reviews/<ID>.md`
