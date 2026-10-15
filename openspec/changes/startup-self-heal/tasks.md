# startup-self-heal · tasks

阶段口径：**apply** 按 delta 切成两个任务顺序执行（`1–3/5–6` 写 `specs/init-skill/spec.md`，`4` 写
`specs/pm-lifecycle/spec.md`，两者都碰 `cmd-watch.sh` 的 `team_cmd_up`，不同时派）；**verify** 由**没有写过
本 change 的席位**在独立克隆上逐场景 + 逐红侧重跑（写的人不验自己的活）。本文件不是规格；合同文本在
`specs/init-skill/spec.md` 与 `specs/pm-lifecycle/spec.md` 的 delta 里，逐条 MODIFIED 必须带全基线场景。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案评审 `docs/team/reviews/startup-self-heal-proposal.md`，逐条落实裁定点（兜底名 /
  形状号 / `--yes` / init 不迁移 / 失败写缓存 / 预览行为 / 标题与帮助分区）；结论摘进报告。
  · 证据：`docs/team/reviews/startup-self-heal-proposal.md`（ACCEPTED）+ P261-dev-bob.md「tasks.md 逐条对照」0.1 行与「P253 两笔提交的去向与调整」（六条裁定：兜底名 `default`、形状号、`--yes` 不参与自动迁移、init/bootstrap 不迁移、失败也写缓存、`--print` 只预告、帮助面归 P252）
- [x] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y startup-self-heal &&
  openspec validate --all --strict)` 必须绿；逐条 MODIFIED 与基线逐场景对照（丢一条基线场景 = 返工）；
  确认没有第二个未归档 change 动 `init-skill`/`pm-lifecycle`。 · 证据：P261-dev-bob.md「独立树投影自证（tasks 0.2）」（`cp -a openspec /tmp/… && openspec archive -y startup-self-heal` → `Change 'startup-self-heal' archived as '2026-10-14-startup-self-heal'`、`validate --all --strict` → `Totals: 18 passed, 0 failed`）；本轮复跑同一投影仍绿（报告「复跑」段）。实际做法：三条 MODIFIED 与基线的逐场景对照由提案复核（PM）记录，本任务只实现不改规格；「没有第二个未归档 change 动 `init-skill`/`pm-lifecycle`」在 apply 当时成立——之后并入 main 的 `slash-team`（`363c7b2f`）也带 `init-skill` delta，已点名给 PM（报告「给 PM 的观察」）

## 1 迁移决策（规格：`init-skill`#Retired model keys migrate on the startup path with their values unchanged）

- [x] 1.1 形状版本表：一行一条迁移（`from`/`to`/transform/`introduced`）+ 判定顺序（标记 → 键 → 表）；
  未知更高形状号拒绝；`TEAM_CONFIG_VERSION` 进 schema/模板/文档（第 5 节），新建与迁移都写。
  · 证据：P261-dev-bob.md 1.1 行 + 红侧表 `ARM migration-row-removed`（`red_rc=1 named=1 restored=yes`）；`--select heal` 的形状号用例（`heal-migrate-shape-number`、`heal-refuse-unknown-shape*`、`heal-refuse-contradictory-shape*`）；V35.md 轮次 2 `--select heal,adopt,updatecheck` → `pass=154 fail=0`；形状号三面登记由 `tests/config-cli.sh` ✓331 ✗0 覆盖。实际做法：**手工事务 `config upgrade-models` 不写形状号**（保持既有语义与报错不变），它写完的项目按键判定仍是最新形状；写形状号的是启动迁移与新建两条路。
- [x] 1.2 推导表：席位同名类别（规范化规则 + 原名打印）、`default` 兜底、PM 键原样/兜底；模型值与类别名复用
  既有校验器；按文件顺序、兜底最后。 · 证据：P261-dev-bob.md 1.2 行：`heal` 组逐键比对（`heal-migrate-values`、`heal-migrate-pm-eq`、`heal-print-pairs` 每个模型串逐字节相同；规范化撞名/兜底撞名各一条拒绝）；V35.md §2.1 独立复跑 86/0，逐个 token 精确相等
- [x] 1.3 失败关闭分类学（design §4 八类）：每类都不写配置、不建备份、不写审计，并给固定形状的信息
  （可定位时给可粘贴建议命令，否则点名障碍）。 · 证据：P261-dev-bob.md 1.3 行：`heal` 组失败关闭八类 + 「零字节」三断言（配置 sha / 备份目录条目 / 审计文件三处不变）共 30 条；红侧 `ARM no-backup`（`named=1 restored=yes`）；V35.md §2.2 自写夹具九例各带三断言 + 最小修复后转绿（`pass=69 fail=0`）
- [x] 1.4 写入路径：备份（`state/config-backups/config.sh.pre-<版本>-<时间戳>`，保留 5 份）→ 复用
  `team_config_upgrade_transaction`（actor=`up-migration`，附形状号）→ 逐键 before→after + 备份/还原 + 为什么
  → `export TEAM_MIGRATION_BACKUP` → `exec` 同一 argv。 · 证据：P261-dev-bob.md 1.4 行 + 「端到端现场」③（逐键 before→after 表 → `✓ 迁移完成（审计已写）`、审计行 `actor=up-migration … TEAM_CONFIG_VERSION`、`export TEAM_MIGRATION_BACKUP` 后 `exec` 仍继续）；V35.md §2.1 备份 `config.sh.pre-0.2.0-<UTC>` 与原文件 `cmp` 逐字节相同、连迁 7 次保留 5 份。实际做法：文件名里的 `<版本>` 实为**引入该迁移的版本**，时间戳是 UTC；自动迁移时事务仍会多打它自己的一行 `committed: before=… after=…`（在逐键表之后，当证据留着）。
- [x] 1.5 `--no-migrate`（不写 + 拒绝 + 建议命令，已是新形状时 no-op）与 `--print`（不写盘、不联网、预告
  逐键表与备份路径、迁移可用时退 0；不可用时按拒绝退非 0）。 · 证据：P261-dev-bob.md 1.5 行 + 端到端现场 ①（`--print` rc=0、配置 hash 不变、备份 0 份、身份记录不存在）与 ②（`--no-migrate` rc=1 → 把打印的命令粘回 `--dry-run`/`--yes` rc=0）；V35.md §2.1 `--print` 五处零写入断言
- [x] 1.6 迁移后仍失败：`up` 的后续失败分支打印备份与还原命令；`--print` 不设置该变量。
  · 证据：P261-dev-bob.md 1.6 行：`heal` 组「启动失败仍给还原命令」用例；`--print` 不设置 `TEAM_MIGRATION_BACKUP`
- [x] 1.7 负向对照：同一文件上，迁移决策与 `team config upgrade-models --dry-run` 对形状给出**同一类**拒绝。
  · 证据：P261-dev-bob.md 1.7 行：`heal` 组负向对照——同一份畸形文件上 `team up` 与 `config upgrade-models --dry-run` 给出同一类拒绝、点名同一行；V35.md §2.1 `--no-migrate` 打印的命令原样执行 `--dry-run` rc=0

## 2 拒绝建议（规格：`init-skill`#Initialization teaches category policy and breaking upgrades without live adoption 的新场景）

- [x] 2.1 `team_model_policy_issues` 发现退休键时：从同一张推导表生成**一条**可粘贴命令，一次成块出现在其它
  blocker 之前；推导不出来时退回占位符并点名障碍。 · 证据：P261-dev-bob.md 2.1 行 + 端到端现场 ⑤⑥（拒绝块第一段 `migration_required`、一条可粘贴命令、`共 1 个阻塞项`、与 `up --print` 逐字一致）；`heal-refuse-invalid-model-advice`（推导不出来 → 占位符 + 点名障碍）；V35.md §7.2 F2 六条路径 `c6.*.cmd_exact` 逐字节相同 + 跨路径同一性
- [x] 2.2 `init`/`bootstrap` 仍拒绝且点名两条路线（`team up` / 手工事务），在安装/账本/worktree/pulse 之前；
  `--print` 只诊断。 · 证据：P261-dev-bob.md 2.2 行 + 「返修轮次 1」F1（`init-legacy-bootstrap-startup-route`、`init-legacy-bootstrap-derived`）；V35.md §7.2 F1 六条写路径都打印两条路线；smoke §1b `✓24 ✗0`、§2 `✓42 ✗0`（本轮全量 FAST 快跑，tail 见 P271-dev-bob.md「本轮复跑」段；§1b/§2 与 §17 一起用 `--select` 单跑会踩选段自身的 cwd 泄漏假红，见报告「给 PM 的发现」）
- [x] 2.3 红侧：把推导换回占位符 → 该用例必红；还原 → 绿。 · 证据：P261-dev-bob.md「返修轮次 1 · 红侧」：变异臂 `legacy-route-placeholder`（`tests/lib/model-routing-flips.py` 第 23 臂，把 `team_legacy_model_route_lines` 换成恒打印占位符）→ `--select init` `pass=55 fail=13`（13 条具名，含端到端粘贴连锁）→ 还原后 `pass=68 fail=0`；V35.md §7.3 自写臂 `r2-derivation-bypassed` 同向红。实际做法：任务书要求的「换回占位符」臂之外，P261 先用了 `migration-row-removed`（推导表消失）与 `no-shape-number`（形状号不写）两臂替代，返修轮次 1 又补了字面的 `legacy-route-placeholder` 臂。

## 3 版本提示（规格：`init-skill`#The startup path reports a newer tool release without installing it）

- [x] 3.1 有界查询（`npm view teamsmith version --registry https://registry.npmjs.org`，≤2s，无 `timeout`
  时有界等待）；结果缓存 `state/update-check.env`（CHECKED_AT/LATEST/LOCAL，原子写，TTL 24h，失败也写一行）。
  · 证据：P261-dev-bob.md 3.1 行：`updatecheck` 组桩计数与缓存内容（`state/update-check.env` 的 `CHECKED_AT/LATEST/LOCAL`、原子写、TTL 24h、失败也写 `LATEST=-`）；V35.md §2.4 桩 `npm` 计数 + 缓存五臂
- [x] 3.2 只在「本地 < 最新」时打一行（两边版本 + 可粘贴命令 + 「工具从不自己安装」）；其余情形零输出；
  不改 rc、不改启动决策；检查在启动决策之后。 · 证据：P261-dev-bob.md 3.2 行 + 红侧表 `ARM updatecheck-equal-prints`（`named=1 restored=yes`，点名 `updatecheck-same-silent`）；V35.md §2.4「有更新恰好一行 / 其余零行」且 rc 与启动决策不变
- [x] 3.3 `TEAM_UPDATE_CHECK=0` 完全关闭（连查询都不发生）；`--print` 不联网、不写缓存、打印跳过说明。
  · 证据：P261-dev-bob.md 3.3 行 + 红侧表 `ARM updatecheck-ignores-off`、`ARM updatecheck-print-writes-cache`（各 `named=1 restored=yes`）；V35.md §2.4 `TEAM_UPDATE_CHECK=0` 与 `--print` 两条零调用
- [x] 3.4 键登记：schema + `templates/config.sh.tmpl` + `references/config.md` 三面一致（`config-cli.sh` 的
  完整性走查绿）。 · 证据：P261-dev-bob.md 3.4 行：`bash skills/teamsmith/tests/config-cli.sh` → `✓ 331 ✗ 0 SKIP 0`（契约表 / `templates/config.sh.tmpl` / `references/config.md` 三面完整性走查）+ 控制台标签（`panel-strings.mjs` ok，385 键 / 118 契约键全覆盖）；V35.md §7.1 同命令 331/0

## 4 身份自愈与 adopt（规格：`pm-lifecycle`#The existing PM launcher guards its selected model before continuing）

- [x] 4.1 缺记录分支：guard 放行并记下「本次要登记」；写入仍由成功启动后的
  `team_pm_metadata_publish` 完成（不在 guard 里预写）；成功行后打登记行（model/resume_key/mode + `--fresh-pm`
  提示）。 · 证据：P261-dev-bob.md 4.1 行：`adopt` 组缺记录用例（`pm-missing-record-registers`、`pm-missing-record-flags-registration`、`pm-missing-record-not-precreated`，文件前后状态）；V35.md §2.3 缺记录 `--print` rc=0 且 `pm-launch.env` 不存在，真跑后打登记行并落盘记录
- [x] 4.2 存在但不一致：仍拒绝；打印两边 model（suffix 显式）与 resume_key、点名哪一处变了、两条出路与后果；
  不可读/异项目/异窗口仍拒绝。 · 证据：P261-dev-bob.md 4.2 行：`adopt` 组两边值断言（夹具把两边设成不同值；`PM launch identity changed：model（记录 … → 现在 …）` + 两边 `resume_key` + 两条出路）；`pm-unreadable-record-needs-fresh`；V35.md §2.3 不可读/异项目记录仍拒绝
- [x] 4.3 `--adopt-pm-identity [--yes]`：缺记录直接写；已存在且不一致时不给 `--yes` 拒绝并点名；给了则写记录 +
  `state/config.log` 一行审计 + 「我声明这次续跑的身份是 X」+ 本次继续启动。 · 证据：P261-dev-bob.md 4.3 行 + 端到端现场 ③b/④（`config.log` 一行 `actor=adopt-pm-identity key=pm-launch-identity old=… new=…`、声明行、随后 `up` 按认领身份续跑；运行/starting 的 PM 下拒绝）；V35.md §2.3
- [x] 4.4 `--print` 预告：缺记录时打印将要登记的行且不建文件；不一致时打印两边值并按拒绝退非 0。
  · 证据：P261-dev-bob.md 4.4 行：`adopt` 组文件缺失断言（缺记录 `--print` 打印将要登记的一行且不建文件；不一致打印两边值并按拒绝退非 0）；红侧 `ARM missing-record-refused`（`named=1 restored=yes`）；V35.md §2.3 `--print` 0 字节
- [x] 4.5 回归：`--fresh-pm` 语义不变、运行中的 PM 不被策略编辑重启、发布失败不留假记录、pulse 仍只对
  **仍拒绝**的情形报 continuity blocker。 · 证据：P261-dev-bob.md 4.5 行 + 「全量门禁与 A/B」第 2 条（`--select pm` = `pass=106 fail=0`，`pm-unknown-needs-fresh` 旧契约改成新契约三条并补一条仍拒绝的）；smoke §11b3 `✓56 ✗0`、§11b4 `✓33 ✗0`（本轮 `--select 11b3,11b4` = `✓433 ✗0`，tail 见 P271-dev-bob.md「本轮复跑」段）

## 5 兼容、文档与登记

- [x] 5.1 `config upgrade-models` 语义与报错不变（手工入口）；只有自动迁移这一条新调用点带附加键与 actor。
  · 证据：P261-dev-bob.md 5.1 行：`tests/task-model-routing.sh --select upgrade,transaction,preview` 回归；V35.md §7.1 独立复跑 `pass=145 fail=0`；只有自动迁移这条新调用点带附加键与 `actor=up-migration`
- [ ] 5.2 文档只说真话的最小修正：`skills/teamsmith-init/SKILL.md`、`skills/teamsmith-init/references/bootstrap.md`、
  `references/config.md`、`references/workflows.md` 四处「只能走 `team config upgrade-models`」的句子改成
  「启动事务（`team up`）或手工事务」；`references/migration.md` 的 §5b 与升级步骤同步（形状表结构写清楚）；
  **完整重写留给 P255**。 · 证据：`grep -rn 'upgrade-models' skills/teamsmith*/` 无残留旧话 +
  smoke §17 输出尾 + 文档 diff
- [x] 5.3 新夹具与改动文件的段落归属登记（`tests/section-paths.tsv`，必要时 `section-budgets.tsv`）；
  反向守卫（真项目 `state/`+`inbox/` 前后快照、夹具零命中）保持绿。
  · 证据：P261-dev-bob.md 5.3 行：`tests/section-paths.tsv` §61 patterns 新增 `cmd-project.sh` 与 `templates/config.sh.tmpl`（basis 写明理由）、`tests/section-budgets.tsv` §61 预算按实测 525s；`section-select.sh --paths …` → `decision=RUN sections=129`；`section-select.sh --check` → `ok 8 bad 0 SKIP 1`；`section-guard.sh --budget-check` 全过。实际做法：除 `section-paths.tsv` 外确实动了 `section-budgets.tsv`（§61 按实测抬到 525s）。
- [x] 5.4 `team help` 不动（归 P252）；把 `--no-migrate`/`--adopt-pm-identity` 两个新旗标写进交接说明给 PM
  （P252 的 brief 需要带上它们）。 · 证据：P261-dev-bob.md 5.4 行 + 「给 P252 的交接（help 面）」段（`--no-migrate`、`--adopt-pm-identity [--yes]` 两个旗标）；`git diff` 里 `team help`/帮助段零改动

## 6 收尾

- [x] 6.1 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check` +
  `ledger-ban.sh`；全量门禁留给 PM 复验，按纪律后台跑（`team_bg_run`）。 · 证据：P261-dev-bob.md「验收」与「返修验收」段的命令与 rc/输出尾（validate `19 passed, 0 failed`、`--paths` 选段 `✓ 4105 ✗ 0` 并点名没跑的 30 个键、`config-cli.sh` ✓331 ✗0、`spec-refs.sh --check` rc=0、`ledger-ban.sh` hits=0、`git diff --check && git status --short` 无输出）；本轮复跑（tail 与全量行见 P271-dev-bob.md「本轮复跑」段）：`TEAM_SMOKE_FAST=1` 全量快跑 `✓4041 ✗5`（4 条红已被并入 main 的 P266/面板工作修掉，本轮 `--select 6e,28,38,39` 复验 `6e ✓13`、`28 ✓176`、`38 ✓22` 全绿；剩 `39` 红 = `teamsmith-init/SKILL.md` 102 行超 install-shape 的 100 行预算，P261 自己的文档改动所致，A/B 见报告）。实际做法：`heal`/`adopt`/`updatecheck` 三组只进 §61 的**全量档**，不进 FAST 档（它们要真 tmux 会话与假 PM 进程，而 §14c 的 FAST 前提是「不起真进程」）；FAST 快跑里它们是可见 SKIP，任务书验收覆盖的是全量档。
- [x] 6.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾 + 第 1.3/2.3/3.2/4.2 节的 **red→green
  原始输出**（破坏实现必红、还原必绿）+ 端到端现场（旧配置 + 缺记录 → `team up` → 迁移表/登记行/`config list`
  /`dispatch --print`；不一致 → 拒绝信息 + adopt 修复）。 · 证据：`docs/team/reports/P261-dev-bob.md` 本体（逐条命令/rc/输出尾 + 「红侧」八臂 red→green 原始输出 + 「端到端现场」①–⑥）+ 提交 `9a36bd5f`（报告）、`1d0d5272`（返修轮次 1）

## 7 独立验证（另一席位，不是 apply 作者）

- [ ] 7.1 在独立冻结克隆重跑第 1–4 节的**全部**场景与回归（`heal`/`adopt`/`updatecheck` + §11b4/§33/§61/§61b/
  §17），逐条给 command/assertion/rc 与 skip。 · 证据：独立记录 + 原始日志
- [ ] 7.2 逐条重做第 1.3/2.3/3.2/4.2 节的**每一条**红侧（破坏必红、还原必绿），不是只复跑绿侧；并自设计反例
  （并发两次 `up`、迁移中途失败、`--print` 的全零副作用、stub npm 计数）。 · 证据：red→green 原始输出
- [ ] 7.3 判 `verification` 的正确性门：只有证据通过；不因为「作者报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md`

## 8 apply / verify 的验收命令（本阶段不运行）

```bash
bash skills/teamsmith/tests/task-model-routing.sh --select heal,adopt,updatecheck
bash skills/teamsmith/tests/task-model-routing.sh --flip
bash skills/teamsmith/tests/smoke.sh --select 11b4,33,61,61b,17
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-watch.sh \
  skills/teamsmith/scripts/lib/cmd-config.sh skills/teamsmith/scripts/lib/common.sh
bash skills/teamsmith/tests/spec-refs.sh --check
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧按第 1.3/2.3/3.2/4.2 节逐条现场改坏再还原（scratch 变异，只写 `${TMPDIR:-/tmp}` 下的 owned 根）；
夹具与命令的最终形态以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。
