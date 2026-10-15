# P261 · 启动自愈（`team up` 迁移 + PM 身份登记 + 版本提示）：apply

agent: dev-bob ｜ status: DONE ｜ branch: `task/P261-startup-self-heal-apply` ｜ tip: `c380da69（`merge(main)`；本报告是它之后的一笔）` ｜ PR/MR: -（local 模式，分支留本地待复验）
phase: apply ｜ change: startup-self-heal

## 交付物

| 落点 | 内容 |
|---|---|
| `skills/teamsmith/scripts/lib/cmd-config.sh` | 迁移**决策层**（纯函数，一个字节都不写）：一行一条迁移的形状表（`m1`：形状 1 → 2）、形状判定顺序（标记 `TEAM_CONFIG_VERSION` → 键 → 表）、高于已知形状号拒绝、推导表（席位同名类别并规范化 / `TEAM_DEFAULT_MODEL` → 兜底类别 `default` / `TEAM_PM_MODEL` 原样或取旧默认值）、失败关闭分类学、带时间戳备份（保留 5 份）、事务写入器的「附加键」入口 |
| `skills/teamsmith/scripts/lib/cmd-watch.sh` | `team up` **编排**：迁移决策在所有其它步骤之前；真跑 = 逐键 before→after → 备份 → 同一个检查过的写入器（actor=`up-migration` + 形状号）→ 还原命令 → `exec` 自己；`--print` 只预告、`--no-migrate` 只报告、`--adopt-pm-identity [--yes]`；启动成功后的登记行；版本提示（有界 ≤2s / 24h 缓存 / 失败静默 / 开关零调用） |
| `skills/teamsmith/scripts/lib/common.sh` | PM 身份卫兵拆两半（缺记录 → 登记；存在但不一致/不可读 → 仍拒绝并打印两边值与两条出路）；`team_pm_identity_adopt`（唯一显式、有审计的认领入口）；退休键拒绝建议从**同一张推导表**生成一条可粘贴命令；派单驱动已印过时不重印 |
| `skills/teamsmith/scripts/lib/cmd-agents.sh` | 派单预检：迁移建议先判先印（一次拒绝里只出现一次）；空的身份输出不冒充阻塞项 |
| `skills/teamsmith/scripts/lib/cmd-project.sh` | `init`/`bootstrap` 渲染形状号；旧配置拒绝时点名两条路线（启动事务 / 手工事务） |
| `skills/teamsmith/templates/config.sh.tmpl` + 契约表 + `references/config.md` | 新键 `TEAM_CONFIG_VERSION`（refuse，工具写）与 `TEAM_UPDATE_CHECK`（apply，默认 1）三面一致 |
| `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` + `panel.js` | 两个新键的控制台标签（M49 走查要求），bundle 按钉住的工具链重建 |
| `skills/teamsmith-init/SKILL.md`、`skills/teamsmith-init/references/bootstrap.md`、`skills/teamsmith/references/workflows.md` | 四处「只能走 `team config upgrade-models`」的最小修正（完整重写归 P255；`references/migration.md` 按任务书边界未改） |
| `skills/teamsmith/tests/task-model-routing.sh` + `tests/lib/model-routing-flips.py` | 新前门三组 `heal`/`adopt`/`updatecheck`（148 条断言）+ 八条变异臂（含「点名哪条断言」断言）+ `pm` 组旧契约断言的改写 |
| `skills/teamsmith/tests/smoke.sh` + `tests/section-{paths,budgets}.tsv` + `tests/lib/model-policy.sh` | 三组进 §61 全量档并登记归属；形状号夹具渲染；§61 预算按实测 525s |

## 验收（真跑，输出照贴）

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -3
===== ① openspec validate
- Validating...
✓ spec/verification
✓ spec/watchdog
Totals: 19 passed, 0 failed (19 items)
rc=0
```

```bash
$ bash skills/teamsmith/tests/task-model-routing.sh --select heal,adopt,updatecheck
RESULT pass=154 fail=0 selected=heal,adopt,updatecheck
$ echo $?
0
```

```bash
$ bash skills/teamsmith/tests/config-cli.sh | tail -2
== 结果 ==  ✓ 331  ✗ 0  SKIP 0
$ echo $?
0
```

```bash
$ bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
decision=RUN
sections=129
keys=99
reason=0 ← prologue
reason=0b ← prologue
reason=0c ← skills/teamsmith/tests/smoke.sh, prologue
```

```bash
$ bash skills/teamsmith/tests/smoke.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ')
  #96 61b · 任务类别模型路由：翻转变异自检（P228 · task-model-routing） · 用时 4737s · ✓1 ✗0 SKIP0 · ticks 1
  #95 61 · 任务类别模型路由：分组前门（P228 · task-model-routing） · 用时 490s · ✓1 ✗0 SKIP0 · ticks 1
== 选段结果 ==  ✓ 4105  ✗ 0
== 选段：这次没跑的段 == 30 个键
0g 1b 8 10b 10c 11e 11e2 11i 13 13b 12b-h0 18c 20 21 22 23 24 12e 12j 12k 35 39 41 49 51 53 58 15 60 62
  选段运行不是全套门禁（交付 / 复验 / 归档仍跑整套）；引用它的报告必须点名没跑的段
$ echo $?
0
（用时 132m50s；§61b 一段就占 4737s，跑的是全量档的 16 组 + 变异套件）

```bash
$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.git/../.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=/home/<user>/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1486 hits=0 names=ok user=resolved
$ echo $?
0

$ bash skills/teamsmith/tests/spec-refs.sh --check
spec-refs: judged 111 reference(s) (49 distinct) in 11176 effective line(s); retired 0; undeclared 0; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
$ echo $?
0

$ git diff --check && git status --short
（无输出：diff 干净、工作树干净）
$ echo $?
0
```

**被污染的一轮（如实记录，作废）**：第 3 轮选段（`p261-smoke3`）在 09:40 拿到锁后，另一位席位在 09:44
误杀了它使用的 tmux server（PM 已通报、对方已自报）。那轮跑到 §75 时停掉，它已产出的三条 tmux 幻影红
（`#52 12b-h0c`、`#28`、`#31c`）整轮作废，日志留 `/tmp/p261work/smoke3.log` 只作污染记录。下面的结果是
**锁空闲、夹具重建后重跑**的那一轮。

**独立树投影自证（tasks 0.2）**：

```bash
$ mkdir -p /tmp/p261trial && cp -a openspec /tmp/p261trial/ && cd /tmp/p261trial
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y startup-self-heal | tail -2
Change 'startup-self-heal' archived as '2026-10-14-startup-self-heal'.
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -1
Totals: 18 passed, 0 failed (18 items)
```

## 红侧：破坏 → 点名哪条断言红了 → 还原 → 绿

八条逐条现场破坏（变异只写 `/tmp` 下的 owned 根），每条跑**它自己的组**；`named=1` 表示该臂点名的断言真的红了，
`restored=yes` 表示源码逐字节回到原样，`green_rc=0` 表示还原后同一组全绿。

```
===== ③ red-side arms
ARM migration-row-removed            groups=heal         red_rc=1 named=1 green_rc=0 restored=yes
ARM no-backup                        groups=heal         red_rc=1 named=1 green_rc=0 restored=yes
ARM no-shape-number                  groups=heal         red_rc=1 named=1 green_rc=0 restored=yes
ARM missing-record-refused           groups=adopt        red_rc=1 named=1 green_rc=0 restored=yes
ARM adopt-ignores-yes                groups=adopt        red_rc=1 named=1 green_rc=0 restored=yes
ARM updatecheck-equal-prints         groups=updatecheck  red_rc=1 named=1 green_rc=0 restored=yes
ARM updatecheck-ignores-off          groups=updatecheck  red_rc=1 named=1 green_rc=0 restored=yes
ARM updatecheck-print-writes-cache   groups=updatecheck  red_rc=1 named=1 green_rc=0 restored=yes
RED-SIDE fail=0
```

对应关系（臂 → 点名断言）：`migration-row-removed → heal-print-rc`｜`no-backup → heal-backup-exists`｜
`no-shape-number → heal-init-shape-number`（新建项目缺形状号 → 红）｜`missing-record-refused → adopt-print-rc`｜
`adopt-ignores-yes → adopt-no-yes-refused`｜`updatecheck-equal-prints → updatecheck-same-silent`｜
`updatecheck-ignores-off → updatecheck-disabled-zero-calls`｜`updatecheck-print-writes-cache → updatecheck-print-cache-unchanged`。
原始日志：`$HOME/Documents/syncthing/Work/Projects/pm-skills-ledger/team/reports/P261/flips-postmerge.log`
与 `flips-postmerge/<臂>.{red,green}.log`。

「失败关闭八类各自一个字节都不写」在 `heal` 组里逐类断言：rc 非 0 + 配置 sha 不变 + 备份数不变 + 审计不变，
并点名障碍（形状定位不了 / 模型值不合法 / 类别名规范化不出来 / 席位互相撞名 / 兜底名撞名 / 新旧值矛盾 /
形状号更高 / 形状号说已是最新却还带退休键），另有「退休键在环境里 → 点名 `unset`」一条。

## 端到端现场（真 CLI + 私有 tmux socket + 记录桩 pi）

脚本 `/tmp/p261work/e2e.sh`，日志 `$HOME/Documents/syncthing/Work/Projects/pm-skills-ledger/team/reports/P261/e2e-postmerge.log`：

- ① 旧形状项目 + 缺身份记录：`team up --print` rc=0，打印逐键表、备份路径、还原命令、身份预告；
  现场核对 config hash 不变、备份 0 份、身份记录不存在（`--print` 一个字节都不写）。
- ② `team up --no-migrate` rc=1 → 把它给出的命令**粘回去**：`config upgrade-models … --dry-run` rc=0 →
  `--yes` rc=0 → `config list` rc=0。
- ③ 真跑 `team up`：逐键表 + `✓ 迁移完成（审计已写）` + `i 此前没有启动记录；已登记本次启动身份：
  model=vendor/pm:high resume_key=default mode=continued`，rc=0；审计行 `actor=up-migration … TEAM_CONFIG_VERSION`；
  随后 `team dispatch dev E1 … --print` → `identity: category=default model=vendor/base`（**按类别选中模型**，不是只看退出码）。
- ③b PM 在跑时 `team up --adopt-pm-identity --yes` rc=1：
  `--adopt-pm-identity：PM 正在运行/正在起（running:…），它的身份是记录里那一个；这次不写记录`，记录逐字节不变。
- ④ 记录改值：`team up --print` rc=1 并打印 `记录 model=… / 现在 model=…` 与两条出路；
  `--adopt-pm-identity`（无 `--yes`）rc=1 点名旗标；`--adopt-pm-identity --yes` rc=0 →
  `我声明这次续跑的身份是 model=vendor/pm:low …` + `config.log` 一行 `key=pm-launch-identity`；再 `--print` rc=0。
- ⑤ 旧配置项目上**派单**：拒绝的**第一段**就是 `migration_required` + 一条可粘贴的
  `team config upgrade-models … --dry-run`，`共 1 个阻塞项`（不重复同一件事），且没有写出 `state/dev.env`。
- ⑥ 同一现场 `team up --print` rc=0，逐键表与派单给出的建议命令逐字一致（同一张推导表）。

## 全量门禁与 A/B 抓到的问题（都记在这里，含根因）

1. **两个新配置键没有控制台标签（我这边的真问题，已修）**。控制台的 M49 走查要求契约表每个键在
   `scripts/panel/src/strings/{zh,en}.ts` 里各有一条非空 `label_<KEY>`，两个方向都查；我加了两个键却没补标签，
   `panel-strings.mjs` 非 0 连带 §28-a / §28-a2 / §38-e 三条红。补标签后：`panel-strings: ok`（385 键 / 118 个契约键全覆盖），
   §26-a 的 bundle 重建比对也要求产物跟着重建 → 已按钉住的工具链重建 `panel.js`。
2. **`pm` 组里那条断言测的是旧契约（真问题，已修）**。`pm-unknown-needs-fresh`（删掉记录 → 守卫必须拒绝）正是
   design §7 反转的那条。已改成新契约三条（放行 / 置登记标记 / 不预写文件）**并补一条仍要拒绝的**
   （记录不可读 → rc=1），拒绝路径其余覆盖留在邻近两臂（值变了）与 adopt 组；改后 `--select pm` = `pass=106 fail=0`。
3. **运行中的 PM 不该被 adopt 改身份（真问题，已修）**。第一版把 `--adopt-pm-identity` 放在状态判定**之前**
   （照 design §6 的步骤顺序读），于是「PM 在跑 + `--yes`」也会写记录 —— 但运行中的 PM 身份就是记录里那一个
   （政策改动不重启它），改写它等于给**下一次续跑**安排一份跟在跑会话对不上的身份。现在该旗标在
   `running:*|starting:*` 下拒绝、点名在跑的 PM 并给两条路，夹具新增 `adopt-running-*` 断言。
4. **分支落后 main 的探针变量改名（不是本分支的代码）**。§12b-h0c 的两条红在三次运行里稳定复现、而同一段在
   main 上绿。判定与定位：
   - A/B：main 的干净克隆上同一段 `✓125 ✗0`，本分支 `✓123 ✗2`；
   - 合成树分治：`main + 只换夹具/测试文件` 与 `main + 只换产品文件` 都不红 → 既不是我的产品代码、也不是我的夹具；
   - 根因：main 的 `550005fc` 把那一段探针的 `TEAM_WATCH_NUDGE_GAP=0` 改成当前名字 `TEAM_PULSE_NUDGE_GAP=0`；
     代码里 `team_pulse_var NUDGE_GAP` **先**看 `TEAM_PULSE_NUDGE_GAP`，而项目配置里写着 900 →
     分支上的探针「设 0」被配置盖掉 → 同一批次第二拍的叫醒被 gap 抑制 → 队列空（两条断言红）。
     证据：`git log -S 'TEAM_PULSE_NUDGE_GAP=0' main -- tests/smoke.sh` → `550005fc`；
     `git diff $(git merge-base main HEAD)..HEAD -- tests/smoke.sh | grep NUDGE_GAP` → **空**（我没碰过那一行）。
   - 处置：`git merge main`（交付前合并纪律）。唯一冲突是生成物 `panel.js`，按语义用合并后的源码重建解决；
     其余自动合并逐处核对（§12b-h 探针行现在是 PULSE 名；`P238_GROUPS_FAST` 保留 main 的值、
     `P238_GROUPS_ALL` 含本任务三组；`section-budgets.tsv` 的 §61b 行照 main 的 5000/3，§61 行保留本任务的 525）。

## tasks.md 逐条对照

| tasks | 落点 / 证据 |
|---|---|
| 0.1 | 提案复核（ACCEPTED）逐条落实：兜底名 `default`、形状号、`--yes` 不参与自动迁移、`init`/`bootstrap` 不迁移、失败也写缓存、`--print` 只预告、帮助面留给 P252 |
| 0.2 | 独立树投影自证（上）；三条 MODIFIED 的基线场景在提案复核里逐条核过，本任务只实现不改规格 |
| 1.1 | 形状表 `m1` + 判定顺序 + 未知形状拒绝；`TEAM_CONFIG_VERSION` 三面登记；`heal-migrate-shape-number`、`heal-refuse-unknown-shape*`、`heal-refuse-contradictory-shape*` + 臂 `migration-row-removed` |
| 1.2 | 推导表（规范化 + 原名打印 + 兜底最后 + 值逐字节不变）：`heal-migrate-values/-pm-eq`、`heal-print-pairs`；规范化撞名/兜底撞名各一条拒绝 |
| 1.3 | 失败关闭八类 + 零字节（配置 sha / 备份数 / 审计三处不变）共 30 条断言 + 臂 `no-backup` |
| 1.4 | 备份（`config-backups/config.sh.pre-<引入版本>-<UTC>`，保留 5 份）→ 事务（actor=`up-migration` + 形状号）→ 逐键 before→after + 还原 → `export TEAM_MIGRATION_BACKUP` → `exec` 同一 argv |
| 1.5 | `--no-migrate`（不写 + 拒绝 + 建议命令 + 已是新形状时 no-op）与 `--print`（不写盘、预告、迁移可用时退 0；不可用按拒绝退非 0） |
| 1.6 | 迁移后仍失败打印备份与还原命令；`--print` 不设置该变量 |
| 1.7 | 负向对照：同一份畸形文件上 `team up` 与 `config upgrade-models --dry-run` 给出同一类拒绝（形状不可定位、点名同一行） |
| 2.1 | 拒绝建议从同一张推导表生成**一条**可粘贴命令（一次成块、在所有其它阻塞项之前、不重复同一件事）；推不出来时退回占位符并点名障碍：`heal-nomigrate-*`、`heal-refuse-invalid-model-advice`、端到端现场 ⑤⑥ |
| 2.2 | `init`/`bootstrap` 仍拒绝且点名两条路线，在任何写入之前；`up --print` 只诊断 |
| 2.3 | 红侧「换回占位符必红」→ 用 `migration-row-removed` 与 `no-shape-number` 两臂替代（推导表消失 → 旧项目必须拒绝；形状号不写 → 新建项目必红） |
| 3.1 | 有界查询（`timeout 2`；无 `timeout` 时后台 + 定时 kill）、缓存 `state/update-check.env`（原子写、TTL 24h、失败也写 `LATEST=-`） |
| 3.2 | 五臂（更新 / 相同 / 更旧 / 报错 / 不可解析）+ 只在本地落后时打一行 + rc 与启动决策不变 |
| 3.3 | `TEAM_UPDATE_CHECK=0` 零调用零缓存改动；`--print` 零调用、缓存不变、打印跳过说明 + 两条臂 |
| 3.4 | 键登记四面一致（契约表 / 模板 / schema / 控制台标签）；`config-cli.sh` 完整性走查 |
| 4.1 | 缺记录 → 放行 + 启动后登记行（写入仍由成功启动后的 `team_pm_metadata_publish` 完成，guard 不预写） |
| 4.2 | 不一致 → 仍拒绝，打印两边 model（suffix 显式）与 resume_key、点名哪一处变了、两条出路；不可读/异项目/异窗口/旧版本仍拒绝 |
| 4.3 | `--adopt-pm-identity [--yes]`：缺记录直接写；不一致不给 `--yes` 拒绝并点名；给了则写记录 + 一行审计 + 声明行；**运行/starting 的 PM 下拒绝** |
| 4.4 | `--print` 预告：缺记录打印将要登记的一行且不建文件；不一致打印两边值并按拒绝退非 0；`--print` 下 adopt 不写盘 |
| 4.5 | 回归：`--fresh-pm` 语义不变（`adopt-fresh-pm-*`、smoke §11b4）、运行中的 PM 不被重启、发布失败不留假记录、pulse 只对仍拒绝的情形报 blocker；`pm` 组旧契约断言按新契约改写 |
| 5.1 | `config upgrade-models` 语义与报错不变（`upgrade`/`transaction`/`preview` 组全绿）；只有自动迁移这条新调用点带附加键与 actor |
| 5.2 | 四处旧话修正；`references/migration.md` 未改（边界归 P255，见未做项） |
| 5.3 | 归属登记：`section-paths.tsv` 的 §61 行新增 `cmd-project.sh` 与 `templates/config.sh.tmpl`；`section-budgets.tsv` 的 §61 行按实测抬到 525s |
| 5.4 | `team help` 零改动；两个新旗标写进下面的交接段 |
| 6.1 | 上面四条验收命令 + `--paths` 选段全量；全量门禁在后台跑 |
| 6.2 | 本报告 + 端到端现场 |
| 7.x | 独立复验（另一席位；本报告不代做） |

## P253 两笔提交的去向与调整

任务书要求把 `task/P253-migration-self-service` 的 `72754edc`（文档）与 `7b63ade3`（夹具）带过来。我没有逐字
cherry-pick，而是按 design 把那一半**重做在同一张推导表上**，口径差如下：

1. **单一来源**：P253 在 `common.sh` 自带一份推导（`team_model_category_normalize` + `team_model_migration_suggestion`）；
   design §3 要求**迁移与拒绝建议共用一张表**。现在推导表住在 `cmd-config.sh` 的 `team_config_migration_plan`，
   拒绝信息与启动迁移都调它。
2. **兜底名**：P253 用 `code`（撞名时退 `routine`/`default`/`code-N`）；design 裁定点 2 用 `default`，撞名**一律拒绝**。
3. **规范化失败**：P253 加 `seat-` 前缀继续；design 要求**拒绝**（先让人选名）。
4. **席位重名**：P253 加数字后缀；design 要求拒绝。
5. **夹具**：P253 的增量是旧版式；本次把验收内容落进新 `heal` 组，并加上「迁移与拒绝同一张表」的同一性。
6. `72754edc` 的 `references/migration.md` 增量未带过来（该文件归 P255）；它的 `references/config.md` 增量已按新口径重写。

## 未做项与偏差（如实）

- `references/migration.md` 未改（任务书边界：归 P255）。
- `team help` 未加两个新旗标（design 裁定点 9 归 P252）。
- 手工事务 `config upgrade-models` 不写形状号（保持既有语义不变）；它写完的项目按键判定仍是最新形状。
- `heal`/`adopt`/`updatecheck` 三组只进 §61 的**全量档**，不进 FAST 档：它们要真 tmux 会话与假 PM 进程，
  而 §14c 的 FAST 前提是「不起真进程」；§61 的注释写明了这条分档理由，任务书的验收命令覆盖全量档。
- 这三组里「真 tmux + 假 PM」的那几条断言（`12b-h ⑤⑥` 同族）只在 `TMUX` 已设置时运行（套件既有约定，
  未设置时是可见 SKIP）；本次所有验收都在 tmux 里跑，所以它们真的跑了。
- 自动迁移时事务仍会打印它自己的 `committed: before=… after=…` 一行（在逐键表之后）；保留为证据。
- 本分支在交付前 `git merge main`（唯一冲突是生成物 `panel.js`，用合并后的源码重建解决）；

## 给 P252 的交接（help 面）

- `--no-migrate`：旧形状配置**不迁移**，只报告并拒绝（给出可粘贴的手工事务命令）。
- `--adopt-pm-identity [--yes]`：把**当前解析**声明成这次续跑的身份（写 PM 启动记录 + 一行审计）；
  记录已存在且不一致时不给 `--yes` 就拒绝；运行/starting 的 PM 下拒绝。
- 新配置键：`TEAM_CONFIG_VERSION`（refuse，工具写）、`TEAM_UPDATE_CHECK`（apply，`0` = 不做 npm 版本查询）。

## 给复验席位的提示

- 三条验收命令里的 `smoke.sh --paths …` 会在本机跑约 133 分钟（129 段）；复验可在独立克隆上重跑，
  或按 `--select 61,61b,33,11b4,17,12b-h0c` 选段（§61b 是翻转套件，约 80 分钟）。
- 三组新夹具自带私有 tmux socket 与记录桩 pi：`--select heal,adopt,updatecheck` 约 10 秒。
- 红侧脚本是本次现场产物，未进仓（`$HOME/.../P261/flips-new.sh`）；变异器本体已进
  `tests/lib/model-routing-flips.py` 并登记进套件 `--flip` 的变异表（含「点名哪条断言」）。
- 迁移**打印的**备份路径与**实际写入的**路径逐字一致（同一份 `team_config_backup_name`）。

---

# 返修轮次 1（2026-10-14）· V35 的 F1 / F2 / O1

复验记录：`docs/team/reviews/V35.md`（FAIL；任务书 1–7 条全绿，三条阻塞/裁定都在 **init/bootstrap/config 的
拒绝建议面**）。核心迁移、身份、版本、端到端一行没动。本轮改的是「拒绝时说人话」这一面。

## 修了什么（三条 + 一个共享来源）

| 点 | V35 现场 | 修法 | 本轮命名断言 |
|---|---|---|---|
| **F1** | 旧配置上 `bootstrap` 的拒绝只点名手工事务（`config upgrade-models`），没有启动事务 `team up` | `cmd-bootstrap.sh` 的拒绝块与 `init` 同构：两条路线都在 | `init-legacy-bootstrap-startup-route`、`init-legacy-bootstrap-derived` |
| **F2** | `init` / `bootstrap` 的建议命令是占位符 `'<category=provider/model …>'`，不是从项目自身配置推导出来的 | 建议命令改从**同一张推导表**生成；推导不出来时才退回占位符并点名障碍 | `init-legacy-{plain,force,print}-derived`、`init-legacy-plain-no-placeholder`、`init-underivable-{placeholder,obstacle,no-derived-map}` |
| **O1** | `team config set` 在退休配置上不拒绝、直接写盘（与 v0.2.0 相同，但 delta 把 `config set` 列进了拒绝面） | `team_config_write_checked_unlocked` 在任何字节之前拒绝（rc=5；不写配置、不写审计），同样给推导命令 | `init-legacy-config-set-{refused,derived,startup-route}`、`init-legacy-config-unchanged` |

三处（`init` / `bootstrap` / config 写路径）与派单侧的旧配置拒绝现在共用**同一个**渲染器
`team_legacy_model_route_lines`（`common.sh`），它调 `team_model_migration_advice` → `cmd-config.sh` 的
`team_config_migration_plan` —— 推导表仍然只有一张，文案也只有一份：

```
  路线 ① 手工事务（先预览）：team config upgrade-models --task-models 'dev=p/old default=p/old' --pm-model 'p/old' --dry-run
  路线 ② 启动事务（机械形状由它迁移）：team up（--print 只预告，--no-migrate 只报告）
```

推导不出来（例如席位模型值不合法）时，第一条换成占位符 `'<category=provider/model …>'`，紧跟一行
`（推导不出建议映射：<具体障碍>；请手工把退休键的值翻成类别映射 category=provider/model）`，绝不打印可能错的命令。

`config set` 的拒绝放在**共享写入器**里，所以 `set-agent-model` / `set-task-model` 这两条同族写路径一起被挡住；
拒绝**不发审计行**（口径同 init/bootstrap 的「任何写入之前停住」：这不是对某个值的拒绝，是这个项目还没迁移）。

## 返修验收（真跑，输出照贴）

```bash
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -2
✓ spec/watchdog
Totals: 19 passed, 0 failed (19 items)
rc=0

$ bash skills/teamsmith/tests/task-model-routing.sh --select init,heal,adopt,updatecheck | tail -2
RESULT pass=220 fail=0 selected=init,heal,adopt,updatecheck
rc=0
  （其中单独 --select init = RESULT pass=68 fail=0；本轮新增 20 条断言 + 1 条粘贴现场，整组 5s）

$ bash skills/teamsmith/tests/config-cli.sh | tail -2
== 结果 ==  ✓ 331  ✗ 0  SKIP 0
rc=0

$ bash skills/teamsmith/tests/section-select.sh --paths $(git diff --name-only main...HEAD | tr '\n' ' ') | head -3
decision=RUN
sections=129
keys=101
rc=0

$ bash skills/teamsmith/tests/section-select.sh --check | tail -4
ok: 前导段声明有效（0 0b 0c 0d）
ok: 段正文点名的真实路径 token 都被各自的行覆盖（502 个 token 检查过；0 个豁免类 token 不参与）
ok: 账本归属（ledger-scan 60）声明有效：9/9 个账本样例被它覆盖
== 选段自检 ==  ok 8  bad 0  SKIP 1
rc=0

$ bash skills/teamsmith/tests/section-guard.sh --budget-check | tail -3
ok: 表头记录了 floor=60
ok: 预算表覆盖 129/129 个 section 且每行都满足 max(ceil(band×4), 60)

section-guard --budget-check: 全过
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=$HOME/Documents/syncthing/Work/Projects/pm-skills/.worktrees/dev-bob scope=published files=1486 hits=0 names=ok user=resolved
rc=0

$ git diff --check && git status --short
（无输出）
rc=0
```

**归属登记**：`tests/section-paths.tsv` 的 §61 patterns 补 `skills/teamsmith/scripts/lib/cmd-bootstrap.sh`
（F1 的落点就在这个文件；不补的话改它不会选中这条前门），basis 里写明理由；
`tests/section-budgets.tsv` 的 §61/§61b 两条 provenance 记下本轮增量（§61 init 组 5s、§61b 新增第 23 条臂
≈ 5s），band 与 budget 不动。

## 红侧：把推导换成占位符 → 点名断言必红 → 还原 → 绿

新增第 23 条变异臂 `legacy-route-placeholder`（`tests/lib/model-routing-flips.py`）：只把
`team_legacy_model_route_lines` 换成恒打印占位符的版本，其余一字不改。它在 scratch 副本上跑
`--select init`：

```bash
$ python3 skills/teamsmith/tests/lib/model-routing-flips.py /tmp/<scratch> legacy-route-placeholder
{"mutation": "legacy-route-placeholder", "changes": [{"file": ".../skills/teamsmith/scripts/lib/common.sh",
 "matched": 1, "before": "6f8bee76…", "after": "134b82c0…"}]}

$ TEAM_ROUTING_TREE=/tmp/<scratch> bash skills/teamsmith/tests/task-model-routing.sh --select init
FAIL init-legacy-plain-derived
FAIL init-legacy-plain-no-placeholder
FAIL init-legacy-force-derived
FAIL init-legacy-bootstrap-derived
FAIL init-legacy-print-derived
FAIL init-legacy-config-set-derived
FAIL init-paste-derived-exact
FAIL init-paste-dry-run-rc
FAIL init-paste-yes-rc
FAIL init-paste-yes-map
FAIL init-paste-yes-pm
FAIL init-paste-yes-retired-gone
FAIL init-underivable-obstacle
RESULT pass=55 fail=13 selected=init
red_rc=1

$ cp -a skills/teamsmith/scripts/. /tmp/<scratch>/skills/teamsmith/scripts/    # 还原
$ TEAM_ROUTING_TREE=/tmp/<scratch> bash skills/teamsmith/tests/task-model-routing.sh --select init | tail -1
RESULT pass=68 fail=0 selected=init
restored_rc=0
```

13 条命名断言里包含**端到端粘贴现场**（提取失败 → `--dry-run`/`--yes` 连锁红），所以「换回占位符」不可能只红一条
文案断言了事。

## 端到端现场：把打印出来的命令原样粘回去

`init` 拒绝 → 复制它打印的那条命令（不是重打一遍）→ `--dry-run` → `--yes` → `config list`，全部在同一副本项目里：

```bash
$ i_pasted="$(printf '%s\n' "$OUT" | grep -o "config upgrade-models --task-models '[^']*' --pm-model '[^']*' --dry-run" | head -1)"
$ printf '%s\n' "$i_pasted"
config upgrade-models --task-models 'dev=p/old default=p/old' --pm-model 'p/old' --dry-run
$ bash <cli> $i_pasted                 # 原样粘贴，--dry-run
rc=0        # 契约 sha 不变（init-paste-dry-run-pure）
$ bash <cli> ${i_pasted% --dry-run} --yes
rc=0        # TEAM_TASK_MODELS='dev=p/old default=p/old'、TEAM_PM_MODEL='p/old'、两个退休键消失
$ bash <cli> config list
rc=0
```

同一现场（手动复查，仓外）：`init` / `bootstrap --print` / `config set TEAM_NOTIFY_TMUX 1 --yes` 三处的拒绝输出
逐字包含同一条命令；`team dispatch dev H1 … --print` 的拒绝块第一段就是 `migration_required: …`（两条路线 +
推导命令），在其它阻塞项之前，只出现一次。

## 未做 / 边界（本轮）

- 迁移、身份登记、版本提示三面的实现一个字节未动（`--select init,heal,adopt,updatecheck` 220 条断言全绿即回归）。
- 派单侧拒绝的**段落排版**没改（仍是 `migration_required:` 头 + 共享渲染器的两行），只把建议块换成共享来源。
- `references/migration.md` 仍未改（P255 的面）；帮助面（P260）、面板字符串（P258）未碰。
- 本轮改动落在 `common.sh` / `cmd-config.sh` / `cmd-project.sh` / `cmd-bootstrap.sh`（前三个已在 §61 patterns 里，
  `cmd-bootstrap.sh` 本轮补进去）；`--paths` 选段 129 段的全量运行结果见下面「门禁」一节。
