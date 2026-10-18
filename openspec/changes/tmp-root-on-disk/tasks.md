# tmp-root-on-disk · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每条可判声明都要有夹具与红侧，改前/改后各一次实测）；
**verify** 由**另一个**席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立克隆上重跑下表全部场景与三条红侧。
本文件不是规格；合同文本在 `specs/{verification,dispatch,watchdog}/spec.md`（4 MODIFIED + 1 ADDED）。

写集（apply 需要逐条明授；未授 → `BLOCKED:` 交回 PM）：

- `skills/teamsmith/scripts/lib/common.sh`（解析器 + `team_disk_label`/`team_disk_remedy`/`team_capacity_line` 改用解析器；
  inotify 探针与 `teamsmith-lock-*` 模板）
- `skills/teamsmith/scripts/lib/cmd-agents.sh`（地板判的路径 + 不可用根的阻塞项）
- `skills/teamsmith/scripts/lib/cmd-status.sh`（doctor 余量行）
- `skills/teamsmith/scripts/lib/cmd-watch.sh`（面板数据读）
- `skills/teamsmith/scripts/lib/cmd-review.sh`（队列标记 / 合并临时目录模板）
- `skills/teamsmith/scripts/lib/gate-lock.sh`（只读出去给医生行的发布路径；**路径与伴生锁不动**）
- `skills/teamsmith/scripts/lib/cmd-config.sh`（schema 行）、`skills/teamsmith/templates/config.sh.tmpl`（键行）
- `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` + **重建** `skills/teamsmith/scripts/panel/panel.js`
- `skills/teamsmith/tests/lib/tmp-root.sh`、`skills/teamsmith/tests/tmp-hygiene.sh`、`skills/teamsmith/tests/smoke.sh`、
  `skills/teamsmith/tests/config-cli.sh`、`skills/teamsmith/tests/section-budgets.tsv`、新增翻转夹具
- `skills/teamsmith/references/{config,troubleshooting,migration}.md`、`skills/teamsmith/CHANGELOG.md`

不碰：门禁锁的发布路径/伴生锁/排队上限（P287 的合同）、`TEAM_SMOKE_FAST` 分层、清扫器的候选谓词与占用证明、
`team review` 的判定词表与退出码、`.github/workflows/gates.yml`（Out of scope）、`TEAM_NOTIFY_LOG` 的默认值（D9）。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案复核 `reviews/tmp-root-on-disk-proposal.md`，把裁定点 D1–D8 的结论摘进报告；与提案不同的裁定按其
  改写判定与场景（D1 若裁字面顺序，则先把 §1 的 84 处隔离站点与 12 处 scenario 的迁移列成清单再动手；D2/D3/D5/D6/D7 若改判，
  按裁定改 `design.md` §2–§7 与 delta 里对应的句子）。三条红侧的方向与「不可用根不回落」不变。
  · P312 按事实勾（2026-10-18）：`reviews/tmp-root-on-disk-proposal.md` 判定 **ACCEPTED**，D1–D8 全部按提案推荐版落笔、没有改判。复核逐条对上的是：D1「`TMPDIR` 优先于契约键」且「pin 被覆盖时打印出来」；D2 `/var/tmp/teamsmith-<ns>`（`/tmp` 仅兜底）；`refuse`+`path`+`dir,opt`+`identity`（D5）从契约键四面走查看得到；D6 的只警告行在 §3.4 的 doctor 输出里；D7 的旧根计数与一条命令在 §2.3 实测；D8 的三条 `--break` 在 §5 各自变红。复核**没有**逐条点名 D1–D8（它把推荐版当既定前提：表头「基线场景对照零丢失（6→9、4→5、3→4）」+ 准入条件 1–5），所以 `design.md`/delta 一处不用改，84 处站点与 12 处 scenario 的迁移清单也不需要（未裁字面顺序）。
- [x] 0.2 独立树投影自证：`cp -a openspec <scratch>/openspec && (cd <scratch> && openspec validate --all --strict
  && openspec archive -y tmp-root-on-disk && openspec validate --all --strict)` 必须绿；逐条核对 4 条 MODIFIED 的既有正文与
  既有 scenario **逐字保留**、ADDED 的标题与三条 scenario 齐全。
  · P312 按事实勾：`cp -a openspec /var/tmp/p312-projection/openspec` → `validate --all --strict` rc=0（20 passed / 0 failed）→ `archive -y tmp-root-on-disk` rc=0（`archived as '2026-10-18-tmp-root-on-disk'`）→ `validate --all --strict` rc=0（19/0）。逐条核对（脚本按 `### Requirement:` 切块比对原树与归档后树）：**5 条 MODIFIED**（verification 3 + dispatch 1 + watchdog 1；任务书写的「4 条」是提案初稿的计数）**零 scenario 丢失**（6→9、4→5、3→4、7→10、5→8）；ADDED 标题与三条 scenario 齐全（3/3）；既有正文按句比对只有 10 句不同，逐句看都是「根怎么解析 / lint 新规则」那几句（D1 的改写），其余正文与全部既有 scenario 逐字保留。
- [x] 0.3 冻结**改动前**基线并抄进报告：`smoke.sh --select 40`、`--select 3,6b`、`--select 34,34c,34d` 的 ✓/✗ 计数与用时；
  `tmp-hygiene.sh --status` 的完整输出（解析出的根、家族目录数、无 marker 的根数）。
  · P312 按事实勾：改动前的树 = `/var/tmp/p309-base`（`git rev-parse --short HEAD` = **57efe1cb**，工作树干净），`TMPDIR=/var/tmp/p312-base-run`：`--select 40` = `✓44 ✗0`（§40 28s · `✓21 ✗0`）；`--select 3,6b` = `✓195 ✗0`（3: 4s `✓7 ✗0`、6b: 16s `✓64 ✗0`）；`--select 34,34c,34d` = `✓197 ✗0`（34: 68s `✓41 ✗0`、34c: 12s `✓26 ✗0`、34d: 98s `✓107 ✗0`）。`tmp-hygiene.sh --status`（同一棵树）：表头 `临时根：/var/tmp/p312-base-run`（**没有 source**，改动前的形状）、owned 家族根 0 个、无 marker 的根 0 个，锁对三样只列不删。原始输出 `/var/tmp/p312-base-baseline.log`。

## 1 解析器（一处实现）

- [x] 1.1 `team_tmp_root` / `team_tmp_root_source` / `team_tmp_root_default` / `team_tmp_root_stat_path` /
  `team_tmp_root_usable` 落在 `scripts/lib/common.sh`；顺序 `TMPDIR` → `TEAM_TMP_ROOT` → 默认；默认 `/var/tmp/teamsmith-<ns>`
  （`/var/tmp` 可写时）否则 `/tmp`；相对路径 / 空串 → 具名失败；纯函数、不创建。证据：四条顺序的实测（四种环境组合各一行输出）。
  · P312 按事实勾：四种组合各一行（根 / `source=`）：① `env -u TMPDIR -u TEAM_TMP_ROOT` → `/var/tmp/teamsmith-pm_skills-deb708fe` / `default`；② `TMPDIR=/var/tmp/p312-td` → 该值 / `tmpdir`；③ `TEAM_TMP_ROOT=/var/tmp/p312-cfg`（不设 `TMPDIR`）→ 该值 / `config`；④ 两者都设 → `TMPDIR` 赢 / `tmpdir`。实现都在 `scripts/lib/common.sh:4007–4114`（`team_tmp_root_default`/`_source`/`_raw`/`_norm`/`team_tmp_root`/`_source_text`/`_note`/`_usable`/`_stat_path`/`_ancestor_note`/`_prepare`），纯函数不建目录（1.3 的只读面实测）。
- [x] 1.2 分歧行：两者都设且不同 → 一行「谁赢了、另一个没用」；同一进程只印一次。证据：两种组合的输出。
  · P312 按事实勾：两者都设且不同 → `source=tmpdir（项目配置 TEAM_TMP_ROOT=/var/tmp/p312-cfg 未生效：环境里的 TMPDIR 赢了）`（一行）；两者相同 → 不打「未生效」那半句（`team_tmp_root_note` 先归一再比）；同一进程里每次调用只打一行（§1.1 ④、§3.1 容量行各一次）。自检 ⑦c 的 `P309 分歧行说 TMPDIR 赢了` 与 `点名没生效的契约值（不静默）` 是同一现场的守门断言。
- [x] 1.3 只读面的祖先判据：`team_tmp_root_stat_path` 在默认根不存在时给最近的存在的祖先，且**不创建**。证据：删掉默认目录
  后 `team doctor` / `--status` 的输出（目录仍不存在）。
  · P312 按事实勾：`TMPDIR=<ghost>/nested`（`<ghost>` 存在、`nested` 不存在）跑 `--status`：表头点名 `…/ghost-root/nested` 并打 `（尚未创建，按 /…/ghost-root 的文件系统判）`（`team_tmp_root_ancestor_note`），**跑完 `[ -e <ghost>/nested ]` 仍为假**（自检 ⑦c 的 `P309 只读面没有创建任何东西` ✓）。`team doctor` 这一面**不成立**：它在同一个现场把默认根建出来了，见 3.4 与报告 §4.1。
- [x] 1.4 调用点归口：`cmd-agents.sh`（地板路径）、`common.sh`（label/remedy/capacity/inotify 探针/`teamsmith-lock-*`）、
  `cmd-status.sh`、`cmd-watch.sh`、`cmd-review.sh`、`smoke.sh`、`tmp-hygiene.sh`、`tmp-root.sh` 全部改走解析器；
  `${TMPDIR:-/tmp}` 在 `scripts/**` 与 `tests/**` 里只剩解析器自己的定义（`--lint` 的第二条规则会钉住）。
  证据：`grep -rn 'TMPDIR:-/tmp' skills/teamsmith/scripts skills/teamsmith/tests` 的剩余清单（只允许解析器与创建者的转调）。
  · P312 按事实勾（带口径）：`grep -rn 'TMPDIR:-/tmp' skills/teamsmith/scripts skills/teamsmith/tests` = **104 行**，其中代码（非注释、非 `TMUX_TMPDIR`）**9 处**，逐处归口：解析器/创建者所在文件的豁免 2（`common.sh:1600` 的 `teamsmith-lock-*` 模板、`tmp-root.sh` 的 socket 兜底）；**冻结的锁路径 1**（`gate-lock.sh:74`，P287 合同）；清扫器的旧基准与自检缺陷形状 2（`tmp-hygiene.sh:64` 的 `TEAM_TMP_HYGIENE_BASE_SELF=1`、`:529` 的 `legacy_base`）；lint 的模式/报告串 3（`:714`/`:757`/`:760`）；lint 自检的坏样本 1（`:1268`）；tmux lint 的豁免正则 1（`tmux-lint.pl:158`）。其余 95 行是注释/文档文字。**与任务书的差异**：`common.sh` 的 `teamsmith-lock-*` 模板按交付形态改回了环境 `TMPDIR`（P309 报告 §3.2 与 CHANGELOG「锁不搬」），不随临时根走；这是刻意的，锁是跨版本串行的共享状态。`--lint` 扫全树 6329 行 = 0 finding（§5.1）。

## 2 默认值与创建

- [x] 2.1 创建者：默认腿按需 `mkdir -p` + `0700`（并打印它建了什么）；显式根必须已存在且可写，否则 exit 3 + 路径 + 原因 +
  `修法：`；**任何一条失败路径都不许退回 `/tmp`**。证据：三种失败形状（不存在 / 不是目录 / 不可写）的 rc 与输出，
  以及失败后 `/tmp` 与默认目录下都没有新条目。
  · P312 按事实勾：① 默认腿按需建：根不存在时 `dispatch --print` 打 `临时根目录已创建：/var/tmp/teamsmith-p312proj-deb708fe（source=default，0700）`，`stat -c '%a'` = **700**；已存在时可写就直接返回，不再打印；② 显式根三种失败形状（不存在 / 不是目录 / 不可写）在 `--self-test` ⑦e 逐条 `✓`（`退出 3`、点名路径、`修法：`）；③ 不回落：失败后 `/tmp` 顶层条目数前后相同（自检 `P309 创建者：失败后 /tmp 下没有新条目`）、`--break=missing-root` 把回落放回去 → `✓92 ✗1`（`87…`）；④ 创建器只在默认腿建目录（`team_tmp_root_prepare` 的 `src=default` 分支），显式根永不代建。
- [x] 2.2 根名不变：默认腿里的根仍是 `teamsmith-<kind>-<ns>.XXXXXX`；`tmp_root_path_ok`、`--lint`、`--sweep` 的谓词一个字不改。
  证据：`--status` 在默认腿下的输出（路径 + 标记 + 台账都在）。
  · P312 按事实勾：`--status` 在默认腿下列出的根名仍是 `teamsmith-<kind>-<ns>.XXXXXX`（现场：`teamsmith-death-cause-pm_skills-deb708fe.jL2r7p`），owner 标记与台账都在；`tmp_root_path_ok`/`--lint`/`--sweep` 的谓词一个字没改（`git diff 9878dcb1..9453e9e3 -- tests/lib/tmp-root.sh` 只改了自检的断言文字「`${TMPDIR}` 下」→「解析出的临时根下」）。
- [x] 2.3 `--status` 表头印解析出的路径与来源；旧默认根残留段（计数 + 一条命令，只读）。证据：两个基准存在时的完整输出 +
  「打印的命令确实能回收」的一次实测（`--dry-run` 与真跑各一次）。
  · P312 按事实勾：`--status` 表头 = `临时根：/var/tmp/teamsmith-pm_skills-deb708fe（source=default）`，另起一段 `旧默认根（/tmp）下的家族目录：28 个（只读计数）` + 两条 `TMPDIR=/tmp … --sweep [--dry-run]` 命令。「打印的命令确实能回收」用**私有基准**实测（不碰别人的根）：在 `/var/tmp/p312-sweep-base` 里造一个 `teamsmith-demo-<ns>.Z9y8X7` → `--sweep --age 0 --dry-run` 打 `[reclaim] …` 且不删，真跑同一命令 → `已回收 …（8 KB）`、目录消失；`TMPDIR=/tmp … --sweep --age 30 --dry-run` 只读列出 21 个可回收 + 4 个跳过（共享机器上真跑会碰别人的陈根，所以只做 dry-run，见报告 §5.3 的边界）。

## 3 地板与医生行绑定到选定根

- [x] 3.1 地板判解析出的根（`team_disk_guard "$(team_tmp_root)" …`），拒绝文案带**路径 + 来源 + 读数 + 阈值 + 修法**；
  `team_disk_label`/`team_disk_remedy` 用同一根比较（临时根不再被说成工作树、修法不再指错）。证据：§6b 的矩阵里
  临时根低于底线的拒绝输出（含 `来源` 字样）。
  · P312 按事实勾：`TEAM_DISK_STATS_FILE` 两行（解析出的根 3 MB / `/tmp` 5 GB）→ `dispatch --print` **rc=1**：`✗ 临时根 /var/tmp/teamsmith-p312proj-deb708fe 磁盘不足（可用 3.0 MB < 底线 1024MB）：拒绝派单` + `来源：source=default` + `修法：…`；反过来（根 5 GB / `/tmp` 3 MB）→ **rc=0**，容量行点名 `临时根 …（inode 2978499） · source=default`，没有因为 `/tmp` 拒绝。自检 `--break=fixed-floor` 把地板指回 `/tmp` → `✓94 ✗2`（`P309 地板：判的是 /tmp 而不是选定的根`）。
- [x] 3.2 不可用的显式根 = 阻塞项（不进「读不到 → 不判」的沉默分支），给修法与 `TEAM_TMP_ROOT` 的写法。证据：`--print` 的拒绝
  输出 + rc。
  · P312 按事实勾：`TEAM_TMP_ROOT=<0555 目录> dispatch --print` → **rc=1**：`临时根不可用：/var/tmp/p312-proj/ro（source=config）不可写 —— 不可用，且不得换用别的根` + `修法：mkdir -p /var/tmp/p312-proj/ro` + `✗ 共 1 个阻塞项`；同一现场容量行不再计算（`磁盘余量没有可判的根，本次不判`），不进「读不到 → 不判」的沉默分支。
- [x] 3.3 未创建的默认根：地板按祖先判、容量行说明；不拒绝、不创建。证据：删掉默认目录后的 `--print` 输出。
  · P312 按事实勾：删掉默认根后 `dispatch --print` **rc=0**，容量行 = `临时根 /var/tmp/teamsmith-p312proj-deb708fe（尚未创建，按 /var/tmp 的文件系统判） 可用 220.7 GB（inode n/a） · source=default`，不拒绝；随后按默认腿的写前准备打出 `临时根目录已创建：…（0700）`（第一次写盘才建，不是读）。`team doctor` 这一面见 3.4。
- [x] 3.4 `team doctor`：临时根行带来源；未创建的默认根按祖先判并说出来；锁所在的文件系统（未被别的行覆盖时）一条**只警告** · 证据（PM 按事实勾，引用独立复验 V59）：V59 §1（同树同命令原文对照）：默认根与 `source=config` 两腿都写清「谁创建」；红侧把子句按 source 挡住→红并点名 config 腿（`docs/team/reviews/V59.md`）
  行，`team doctor` 仍 exit 0，派单不因此被拒。证据：两个场景的 doctor 输出 + rc。
- [x] 3.5 面板数据读走解析器（`__panel-data` 的余量条目路径）。证据：面板读的 JSON 里那条路径。
  · P312 按事实勾：`team __panel-data --block capacity` → `"temp_root": "/var/tmp/teamsmith-pm_skills-deb708fe", "temp_root_source": "default", "disk": [{"path": "/var/tmp/teamsmith-pm_skills-deb708fe", "avail_mb": 225971, …}]`——路径、来源、余量三项都来自解析器（`cmd-watch.sh:850`、`:868`）。

## 4 契约键

- [x] 4.1 schema 行 `TEAM_TMP_ROOT|refuse|path|dir,opt|plain||-|…|identity`；`templates/config.sh.tmpl` 的位置键区块加一行；
  `references/config.md` 按位置键家族写一行（含解析顺序与「环境里的 TMPDIR 会盖过它」）。证据：`team config list` 的人读表 +
  `team config set TEAM_TMP_ROOT /tmp` 的退出码（5）。
  · P312 按事实勾：schema 行 `TEAM_TMP_ROOT|refuse|path|dir,opt|plain||-|…|identity`（`cmd-config.sh:53`）、`templates/config.sh.tmpl:66–67`、`references/config.md:60`（解析顺序 + 「环境里的 `TMPDIR` 会盖过它」+ 回滚）；`team config list` 的人读表 = `TEAM_TMP_ROOT  refuse  path  (unset · default)`；`team config set TEAM_TMP_ROOT /tmp` → **rc=5** + `✗ TEAM_TMP_ROOT 不能由命令改` + 审计行 `result=refused actor=cli`。
- [x] 4.2 控制台标签 `label_TEAM_TMP_ROOT`（zh/en）+ 用钉住的工具链重建 `panel.js`（`bun install --frozen-lockfile && bash build.sh`）。
  证据：`tests/panel-strings.mjs` 绿；重建后的 `panel.js` 与沙盒重建逐字节一致。
  · P312 按事实勾：`node skills/teamsmith/tests/panel-strings.mjs` → `panel-strings: ok`、`ok: contract-key labels — 123 schema keys covered in zh and en`（rc=0）；用钉住的工具链在沙盒重建：`bun install --frozen-lockfile`（45 packages）+ `bash build.sh` → `panel.js written (978356 bytes, sha256 bf40c98f…)`，与提交的 `scripts/panel/panel.js` **cmp 逐字节一致**（978356 字节）。

## 5 红侧（三条）

- [x] 5.1 ①「各处自己算」：`--lint` 新规则 + 第三条红侧副本（自己算根的产品调用点 → `<file>:<line>`、rc=1）；动态那半：
  fixture-mode 影子让清扫器/门禁自算，断言两个基准对不上并点名分歧的面，撤掉即绿。证据：两份输出（红/绿）。
  · P312 按事实勾：`tmp-hygiene.sh --lint` 扫全树 6329 个模板/源码行 → rc=0、0 finding；自检 ⑦b 两份自己算根的样本（shell 的 `${TMPDIR:-/tmp}`、JS 的 `process.env.TMPDIR || tmpdir()`）→ rc=1 并点名 `<file>:<line>`；`--break=inline-root`（清扫器自算基准）→ `✓93 ✗3`。**但豁免比规格宽**：`_lint_self_computed` 整文件豁免 `scripts/lib/common.sh` 与 `tests/lib/tmp-root.sh`，实测把同一行 `X="${TMPDIR:-/tmp}/…"` 追加到 `cmd-agents.sh` 会被点名、追加到 `common.sh` 不会 —— 而规格说豁免只有「解析器自己的定义与创建者的转调」。见报告 §4.2。
- [x] 5.2 ②「地板绑回 `/tmp`」：`TEAM_DISK_STATS_FILE`（解析出的根很空 + `/tmp` 很满）下派单**不拒**、容量行点名解析出的根；
  `--break=fixed-floor` 下同一输入拒绝并点名 `/tmp`。证据：两份 `--print` 输出 + rc。
  · P312 按事实勾：`TEAM_DISK_STATS_FILE`（解析出的根很空 + `/tmp` 很满）→ 派单 **rc=0**、容量行点名解析出的根；`--break=fixed-floor` 下同一输入 → `✓94 ✗2`，逐条是 `P309 地板：判的是 /tmp 而不是选定的根（✗ 工作树 /tmp 磁盘不足（可用 120.0 MB < 底线 1024MB、inode 可用 40000 < 底线 100000）：拒绝派单…）`。
- [x] 5.3 ③「不可用时静默回落」：`--self-test --break=missing-root` 把回落放回去必须红，撤掉必须绿；正常路径的具名失败
  （路径 + 原因 + 修法）与「`/tmp` 下没有新条目」的断言。证据：三份输出 + rc。
  · P312 按事实勾：`--self-test --break=missing-root` → `✓92 ✗1`，唯一红是 `P309 红侧③：break=missing-root 下创建者静默回落了（守门断言应当红 —— 翻转预期）`；正常路径（不 break）：显式根不存在 → rc=3、点名路径 + `修法：`、`/tmp` 下没有新条目（⑦e 三条 ✓）。
- [x] 5.4 §40 的 band 复测（`section-budgets.tsv` 的 provenance 必须写实测值，不许沿用旧值）；`--select 0e` 绿。 · 证据（PM 按事实勾，引用独立复验 V59）：V59 §2：表里 `band 51.00 / 预算 204`，provenance 记「改动前树 31s / 本分支 37·41·42s」与负载；复检者自己在 loadavg1 7.74 下实测 39s、✓37 ✗0 落在带内

## 6 门禁与文档

- [x] 6.1 `smoke.sh`：工作根与事故诊断走解析器（诊断落在解析出的基准下、仍在 `$TMP` 之外），开跑行印来源；锁块**不动**。 · 证据（PM 按事实勾，引用独立复验 V59）：V59 §3：`--select 3` 开跑行与结束行都含 `source=tmpdir` 与解析出的根；红侧去掉打印→红 2 条
  证据：`--select 34,34c,34d` 的 ✓/✗ 计数零回退。
- [x] 6.2 `references/troubleshooting.md`：ENOSPC / 临时根一节改写（默认值、来源、旧根残留、回滚、inode 腿在磁盘上不适用的 · 证据（PM 按事实勾，引用独立复验 V59）：V59 §4：两处文档不再含旧 token；`TEAM_TMP_ROOT=/tmp` 回退实跑生效
  诚实退化）；`references/migration.md` §5 加一行、§6 Step 5 的检查项、§7 的回滚条目；`CHANGELOG.md` 新版本段落写清默认行为
  变化与回滚。证据：三份文档的 diff 摘要。
- [x] 6.3 全量门禁（`smoke.sh`，后台跑、下一次唤醒收割）＋ `openspec validate --all --strict`。证据：✓/✗ 计数与用时。 · 证据（PM 按事实勾，引用独立复验 V59）：P314 报告：完整套件跑过一次并给 rc 与结果行；既有红按 D198 只记录（`docs/team/reports/P314-dev2.md`）

## 7 交付

- [x] 7.1 报告 `reports/P306-dev2.md` 按模板写：解析顺序、默认值、地板绑定、清扫器、迁移/回滚、三条红侧（各带红/绿两份输出）。
  · P312 按事实勾：apply 报告 `reports/P309-dev2.md`（188 行）在 main 上，§1 交付物表、§2 验收命令与真实输出、§3 三条红侧各带红/绿两份输出（§3.1 表 + §3.2 迁移缺陷的「先红后绿」）；提案报告 `reports/P306-dev2.md` 同样存在（任务书这里写的 `P306-dev2.md` 是 propose 阶段的报告，apply 的报告是 P309）。
- [x] 7.2 分支留在本地（local 模式），小步提交（Conventional Commits + 任务 ID + `Agent:` trailer），通知 PM。
  · P312 按事实勾：分支 `task/P309-tmp-root-on-disk-apply` 留本地、经 PM 复验后 squash 合并（`9453e9e3`）；逐条提交带 `Agent: dev2` trailer；交付时已 `team notify pm`（inbox 记录）。本任务 P312 的分支是 `task/P312-tmp-root-checklist`，只有 `tasks.md` 与这份报告两处改动（`git status --short` 见 §2）。

## 补记（P312 · 2026-10-18，未勾的 5 项）

- **3.4（doctor）未勾**：`team doctor` 在默认根不存在时**把它建出来**（「inotify 额度」行先跑 `team_inotify_probe`，它调
  `team_tmp_root_prepare`），且「临时根余量」行从不打「尚未创建」——delta 的 `never created by a read` 这一面对 doctor 不成立。
  复现与机制见 `reports/P312-dev2.md` §5.1。锁行（只警告、不拒绝）本身成立。
- **5.4 未勾**：§40 的 band 仍是 P223 的 20.00s、provenance 没重写；今天实测 §40 = 28s（改动前树 `57efe1cb`）/ 36s（本分支），
  两次都超过 band；没有容器读数 → 不能按「实测值」填表（报告 §5.3）。
- **6.1 未勾**：工作根与事故诊断已经走解析器（`SMOKE_TMP_DIAG="$(team_tmp_root)/…"`）、`--select 34,34c,34d` 零回退；
  但**开跑行没有印来源**（`smoke_tmp_usage` 只打路径/用量，`smoke.sh` 里没有 `team_tmp_root_source` 调用）——报告 §5.4。
- **6.2 未勾**：`CHANGELOG.md` 与 `references/config.md` 改了；`references/troubleshooting.md` §25（`:1166`、`:1195`）仍写
  `${TMPDIR:-/tmp}` + 「15 GB tmpfs」，`references/migration.md` 的 §5/§6/§7 一处都没提临时根 / `TEAM_TMP_ROOT`——报告 §5.5。
- **6.3 未勾**：没有在最终 tip 上收口的全量门禁。`/var/tmp/p309-full10.log` 是老 tip 的整轮（`✓4906 ✗32`，3h09m），
  之后 11f/32/40 单独复跑 ✗0；V57 的独立闭包是 `✓4399 ✗24`（112 段）。`openspec validate --all --strict` 是绿的。

另：5.1 的 lint 规则本身成立，但它的豁免是**整文件**的（`common.sh` / `tests/lib/tmp-root.sh`），在 common.sh 里自己算根
不会被抓——规格说豁免只有「解析器自己的定义与创建者的转调」。建议另立任务（报告 §5.2 / §6.1）。
