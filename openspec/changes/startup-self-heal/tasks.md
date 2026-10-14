# startup-self-heal · tasks

阶段口径：**apply** 按 delta 切成两个任务顺序执行（`1–3/5–6` 写 `specs/init-skill/spec.md`，`4` 写
`specs/pm-lifecycle/spec.md`，两者都碰 `cmd-watch.sh` 的 `team_cmd_up`，不同时派）；**verify** 由**没有写过
本 change 的席位**在独立克隆上逐场景 + 逐红侧重跑（写的人不验自己的活）。本文件不是规格；合同文本在
`specs/init-skill/spec.md` 与 `specs/pm-lifecycle/spec.md` 的 delta 里，逐条 MODIFIED 必须带全基线场景。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/startup-self-heal-proposal.md`，逐条落实裁定点（兜底名 /
  形状号 / `--yes` / init 不迁移 / 失败写缓存 / 预览行为 / 标题与帮助分区）；结论摘进报告。
  · 证据：评审记录 + 报告摘录
- [ ] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y startup-self-heal &&
  openspec validate --all --strict)` 必须绿；逐条 MODIFIED 与基线逐场景对照（丢一条基线场景 = 返工）；
  确认没有第二个未归档 change 动 `init-skill`/`pm-lifecycle`。 · 证据：投影命令与输出尾

## 1 迁移决策（规格：`init-skill`#Retired model keys migrate on the startup path with their values unchanged）

- [ ] 1.1 形状版本表：一行一条迁移（`from`/`to`/transform/`introduced`）+ 判定顺序（标记 → 键 → 表）；
  未知更高形状号拒绝；`TEAM_CONFIG_VERSION` 进 schema/模板/文档（第 5 节），新建与迁移都写。
  · 证据：`tests/task-model-routing.sh --select heal` 的形状号用例 + `--select flip` 的删行必红
- [ ] 1.2 推导表：席位同名类别（规范化规则 + 原名打印）、`default` 兜底、PM 键原样/兜底；模型值与类别名复用
  既有校验器；按文件顺序、兜底最后。 · 证据：`heal` 组的逐键比对（每个模型串逐字节相同）
- [ ] 1.3 失败关闭分类学（design §4 八类）：每类都不写配置、不建备份、不写审计，并给固定形状的信息
  （可定位时给可粘贴建议命令，否则点名障碍）。 · 证据：`heal` 组的「零字节」断言（sha256 + 备份目录 +
  audit 文件三处不变）+ `--select flip`
- [ ] 1.4 写入路径：备份（`state/config-backups/config.sh.pre-<版本>-<时间戳>`，保留 5 份）→ 复用
  `team_config_upgrade_transaction`（actor=`up-migration`，附形状号）→ 逐键 before→after + 备份/还原 + 为什么
  → `export TEAM_MIGRATION_BACKUP` → `exec` 同一 argv。 · 证据：`heal` 组的审计行、备份文件、exec 后仍能继续
- [ ] 1.5 `--no-migrate`（不写 + 拒绝 + 建议命令，已是新形状时 no-op）与 `--print`（不写盘、不联网、预告
  逐键表与备份路径、迁移可用时退 0；不可用时按拒绝退非 0）。 · 证据：`heal` 组的 hash/mtime 断言与退码
- [ ] 1.6 迁移后仍失败：`up` 的后续失败分支打印备份与还原命令；`--print` 不设置该变量。
  · 证据：`heal` 组的「启动失败仍给还原命令」用例
- [ ] 1.7 负向对照：同一文件上，迁移决策与 `team config upgrade-models --dry-run` 对形状给出**同一类**拒绝。
  · 证据：`heal` 组的对照输出

## 2 拒绝建议（规格：`init-skill`#Initialization teaches category policy and breaking upgrades without live adoption 的新场景）

- [ ] 2.1 `team_model_policy_issues` 发现退休键时：从同一张推导表生成**一条**可粘贴命令，一次成块出现在其它
  blocker 之前；推导不出来时退回占位符并点名障碍。 · 证据：`heal` 组的「建议命令可粘贴执行（--dry-run 绿）」
- [ ] 2.2 `init`/`bootstrap` 仍拒绝且点名两条路线（`team up` / 手工事务），在安装/账本/worktree/pulse 之前；
  `--print` 只诊断。 · 证据：smoke §1b/§2 输出尾 + `heal` 组
- [ ] 2.3 红侧：把推导换回占位符 → 该用例必红；还原 → 绿。 · 证据：red→green 原始输出

## 3 版本提示（规格：`init-skill`#The startup path reports a newer tool release without installing it）

- [ ] 3.1 有界查询（`npm view teamsmith version --registry https://registry.npmjs.org`，≤2s，无 `timeout`
  时有界等待）；结果缓存 `state/update-check.env`（CHECKED_AT/LATEST/LOCAL，原子写，TTL 24h，失败也写一行）。
  · 证据：`tests/task-model-routing.sh --select updatecheck` 的桩计数与缓存内容
- [ ] 3.2 只在「本地 < 最新」时打一行（两边版本 + 可粘贴命令 + 「工具从不自己安装」）；其余情形零输出；
  不改 rc、不改启动决策；检查在启动决策之后。 · 证据：`updatecheck` 组五臂（更新/相同/更旧/报错/不可解析）
- [ ] 3.3 `TEAM_UPDATE_CHECK=0` 完全关闭（连查询都不发生）；`--print` 不联网、不写缓存、打印跳过说明。
  · 证据：`updatecheck` 组的两组零调用断言
- [ ] 3.4 键登记：schema + `templates/config.sh.tmpl` + `references/config.md` 三面一致（`config-cli.sh` 的
  完整性走查绿）。 · 证据：`bash tests/config-cli.sh` 输出尾

## 4 身份自愈与 adopt（规格：`pm-lifecycle`#The existing PM launcher guards its selected model before continuing）

- [ ] 4.1 缺记录分支：guard 放行并记下「本次要登记」；写入仍由成功启动后的
  `team_pm_metadata_publish` 完成（不在 guard 里预写）；成功行后打登记行（model/resume_key/mode + `--fresh-pm`
  提示）。 · 证据：`tests/task-model-routing.sh --select adopt` 的缺记录用例（文件前后状态）
- [ ] 4.2 存在但不一致：仍拒绝；打印两边 model（suffix 显式）与 resume_key、点名哪一处变了、两条出路与后果；
  不可读/异项目/异窗口仍拒绝。 · 证据：`adopt` 组的两边值断言（夹具把两边设成不同值）
- [ ] 4.3 `--adopt-pm-identity [--yes]`：缺记录直接写；已存在且不一致时不给 `--yes` 拒绝并点名；给了则写记录 +
  `state/config.log` 一行审计 + 「我声明这次续跑的身份是 X」+ 本次继续启动。 · 证据：`adopt` 组的审计行与
  随后 `team up` 能续跑
- [ ] 4.4 `--print` 预告：缺记录时打印将要登记的行且不建文件；不一致时打印两边值并按拒绝退非 0。
  · 证据：`adopt` 组的文件缺失断言
- [ ] 4.5 回归：`--fresh-pm` 语义不变、运行中的 PM 不被策略编辑重启、发布失败不留假记录、pulse 仍只对
  **仍拒绝**的情形报 continuity blocker。 · 证据：smoke §11b4/§11b3 输出尾

## 5 兼容、文档与登记

- [ ] 5.1 `config upgrade-models` 语义与报错不变（手工入口）；只有自动迁移这一条新调用点带附加键与 actor。
  · 证据：`tests/task-model-routing.sh --select upgrade,transaction,preview` 回归
- [ ] 5.2 文档只说真话的最小修正：`skills/teamsmith-init/SKILL.md`、`skills/teamsmith-init/references/bootstrap.md`、
  `references/config.md`、`references/workflows.md` 四处「只能走 `team config upgrade-models`」的句子改成
  「启动事务（`team up`）或手工事务」；`references/migration.md` 的 §5b 与升级步骤同步（形状表结构写清楚）；
  **完整重写留给 P255**。 · 证据：`grep -rn 'upgrade-models' skills/teamsmith*/` 无残留旧话 +
  smoke §17 输出尾 + 文档 diff
- [ ] 5.3 新夹具与改动文件的段落归属登记（`tests/section-paths.tsv`，必要时 `section-budgets.tsv`）；
  反向守卫（真项目 `state/`+`inbox/` 前后快照、夹具零命中）保持绿。
  · 证据：`bash tests/section-select.sh --paths …` 的 RUN 决定
- [ ] 5.4 `team help` 不动（归 P252）；把 `--no-migrate`/`--adopt-pm-identity` 两个新旗标写进交接说明给 PM
  （P252 的 brief 需要带上它们）。 · 证据：报告里的交接段 + `git diff` 里 help 段零改动

## 6 收尾

- [ ] 6.1 相关段 + `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check` +
  `ledger-ban.sh`；全量门禁留给 PM 复验，按纪律后台跑（`team_bg_run`）。 · 证据：各命令 rc 与输出尾
- [ ] 6.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾 + 第 1.3/2.3/3.2/4.2 节的 **red→green
  原始输出**（破坏实现必红、还原必绿）+ 端到端现场（旧配置 + 缺记录 → `team up` → 迁移表/登记行/`config list`
  /`dispatch --print`；不一致 → 拒绝信息 + adopt 修复）。 · 证据：报告本体 + 提交

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
