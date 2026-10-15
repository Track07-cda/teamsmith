# panel-plain-language · tasks

阶段口径：**apply** 由一个席位做完（文案、渲染与数据来源是一个原子改动，proposal「粒度」一节说明了为什么不能只做一半）；
**verify** 由**另一个**席位（与 apply 作者不同，dispatch 的自验守卫会拦）在独立 clone 上重跑下表全部场景与红侧。
本文件不是规格；合同文本在 `specs/panel/spec.md`（6 条 MODIFIED）、`specs/key-replies/spec.md`（1 条 MODIFIED）、
`specs/memory-and-deps/spec.md`（3 条 MODIFIED）。

范围提醒：本变更落三个 delta，而任务书 `deltas:` 行可能只写了 `panel, key-replies`；**写 apply 任务书时请把 `deltas:` 行补成
`panel, key-replies, memory-and-deps`**，否则 `memory-and-deps` 的 delta 会被 dispatch 判成「没有单写者声明」。
**不许削弱既有断言**：`panel-strings.mjs`（键集/占位符/表外无 CJK/契约键标签双向）、`panel-contrast.mjs`（对比度）、
`panel-snapshots.sh`（四档快照）与 key-replies 的安全组原样保留；新增的判据只加严。

## 0 冻结与投影

- [x] 0.1 读 PM 的提案评审 `docs/team/reviews/panel-plain-language-proposal.md`，确认五个裁定点（三个 delta / `fixture-only: ` 标记 /
  `record_present` / 迁移诊断原文保留 / 回复用法文案的落点），结论摘进报告；与提案不同的裁定按其改写判定与场景。
  · 证据：`docs/team/reviews/panel-plain-language-proposal.md`（ACCEPTED）+ P266-dev3.md §1 开篇点名该评审；五个裁定点的落地：三个 delta（`openspec/changes/panel-plain-language/specs/` 下三个目录）、四条 `fixture-only: ` 标记（§2）、`record_present`（§1/§4.4）、迁移诊断原文保留（§8.1；改动面不含 `common.sh`，本轮复核 `git show 71081b76 --stat | grep -c common.sh` = 0）、回复用法文案（§3；本轮复核 `cmd-reply.sh:16,22`，cli-help 帮助面 `help.en.tsv` 的 `--from` 行本就不带限定词）。实际做法：报告没有单列「五个裁定点」小节，五条分别落在上述小节里。
- [x] 0.2 独立树投影自证：`cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y panel-plain-language &&
  openspec validate --all --strict)` 必须绿；逐条比对三条 MODIFIED 的基线场景名**逐字保留**（`openspec validate
  --all --strict` 会点名 `omits scenario(s)`），并确认没有第二个未归档 change 动同一批要求
  （`grep -rn 'Requirement:' openspec/changes/*/specs/ | grep -E 'audit|disk floor|category' …`）。
  · 证据：本轮补跑（P266 交付时未留投影日志）：`cp -a openspec /tmp/p273-proj2/ && (cd /tmp/p273-proj2 && "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y panel-plain-language)` → rc=0（`~ 10 modified`：panel 6 / key-replies 1 / memory-and-deps 3），随后 `openspec validate --all --strict` → `Totals: 22 passed, 0 failed` rc=0（丢基线场景会被点名 `omits scenario(s)`；提案复核另记「零丢失」）。实际做法/发现：「没有第二个未归档 change 动同一批要求」不成立——此刻 `panel-preview-and-compose`（panel）与 `pm-reply-discipline`（key-replies）仍未归档且动同批 capability；投影后的 validate 仍 22/0，兼容性成立，归档顺序归 PM（见报告「给 PM 的观察」）。
- [ ] 0.3 冻结**改动前**基线：`openspec validate --all --strict`（本 change 之前 20 项全绿）、
  `spec-refs.sh --check`、`panel-strings.mjs`（当前键集与 label 数）、`panel-p21.sh settings categories groups wheel`
  的 ✓/✗ 量级，以及 `team config list --json` 里 45 行 schema 注释的当前原文（抄成一张对照表，供收尾逐行核对）。
  · 证据：基线日志 + 注释对照表

## 1 `memory-and-deps`：注释列改写 + 标记 + `record_present`（规格 3 条 MODIFIED）

- [x] 1.1 schema 注释列（`scripts/lib/cmd-config.sh` 的 `team_config_schema`）逐行改写：按 design 的类别规则把
  `身份/账本布局/环境定位/分支语义/凭据位置/权限守卫/依赖策略/机器路径/信号/名册/类别与 PM/退役键` 的正文改成普通话，
  删掉 `手改`、`只读键`、`测试旋钮`、`内部接缝`、`旋钮`、`接缝`、`依赖策略`、`机器路径` 与 `P159`/`M53`/`M67` 这类内部编号；
  四个适配器键按 `The worker-launch keys are an internal frozen seam…` 的新句写（同一件事的普通话，不动类/值域）。
  · 证据：P266-dev3.md §2（48 行逐行表 + 禁词 grep 0 命中，分节注释也去掉 `依赖策略`/`P159`）+ §3；落地提交 `71081b76`。实际做法：清单写「45 行」，实际 48 行（报告 §2 已注明 45 是估数）。
- [x] 1.2 夹具开关的声明标记：`TEAM_DISK_STATS_FILE`、`TEAM_SMOKE_FAST`、`TEAM_INBOX_WATCH_FORCE_FAIL`、
  `TEAM_IW_REQUIRE_WATCH` 四行的注释以 `fixture-only: ` 开头；其余任何行不带这个前缀（`grep -c '^fixture-only'` 只在
  schema 里出现 4 次）；标记不改 `class`/`kind`/`default`/group。
  · 证据：P266-dev3.md §2（四条夹具键的 `fixture-only: ` 前缀；本轮复核计数 = 4）+ §1；`config-cli.sh` 新 `seam` 段 ✓343 ✗0（含 scratch 红侧点名 `TEAM_AGENT_CMD`，§7）；V36.md §1.3 p1 红侧（去掉标记 → ✓24 ✗12）。
- [x] 1.3 `record_present`：`team_config_list_json` 的每个 assignment 记录加 `"record_present": true|false`
  （调现成的 `team_assignment_record_present "$a"`，不改 `common.sh`、不加新函数）；空/坏记录时其余字段照旧是空串。
  · 证据：P266-dev3.md §1 + §4.4（`panel-p21.sh` policy 段断言读侧 `assigned=False record_present=True`、诊断不上屏）+ §8.2 判据说明；`cmd-config.sh:739-759`；V36.md §1.3 p3 红侧（读侧一律 false → ✓7 ✗3）。实际做法：三种状态在同一段夹具里演练（`dev` 的完整记录；`verify` 先无记录、再换成一份读不出来的旧格式记录），不是三份独立 fixture。
- [x] 1.4 红侧：把某个 fixture 键的标记删掉 → 该行应回到设置视图（与 §2 的夹具联动，红）；还原 → 绿；
  把身份键的注释改回「手改」→ `panel-p21.sh` 的旧断言式场景不应存在（本轮已改成新文案），故这条红侧由人读样张判（文本类）；
  `record_present` 撒谎（两者都报 false）→ §4 的两种原因场景红。 · 证据：P266-dev3.md §5（标记变异：写死键名名单 → `panel-strings.mjs` 检查 6 点名 `[TEAM_DISK_STATS_FILE, TEAM_SMOKE_FAST]` rc=1；还原 rc=0）+ V36.md §2 R6/R7/R8；「身份键注释改回手改」属文本类，由人读（V36.md §1.4 语料 913 行 0 命中）。

## 2 `panel`：设置页的渲染（规格 6 条 MODIFIED）

- [x] 2.1 行集过滤：`settingsViewRows` 在分组前丢掉 `route` 以 `fixture-only: ` 开头的键（行、标题、`/` 命中都排除），
  并把行数公式（`rows + ↑ + ↓`）改成「schema 键 − 被隐藏键 + 类别 + 席位」。
  · 证据：P266-dev3.md §4.1（帧里无四条夹具键、`↑92` 行数窗口）+ §7（`panel-p21.sh settings groups` ✓106 ✗0、`settings` ✓76 ✗0）+ §3（行数公式与 wheel 场景同步）。
- [x] 2.2 审计离场：`settingsBlock` 不再画 `settingsAuditHeading` 与 `SETTINGS_AUDIT_LINES` 那几行（常量与尾部计价一起去掉），
  写路径的 settle 后只重读列表；视图尾部只剩聚焦行的命令行。
  · 证据：P266-dev3.md §4.1（帧里没有审计标题、没有审计行）+ §5-M1 红侧（把审计尾画回 → `panel-p21.sh settings` rc=1 ✓47 ✗33，点名「视图里没有审计标题」）；既有写路径与只读场景未减少（§7：`panel-p21.sh settings` ✓76 ✗0、`settings groups` ✓106 ✗0）。
- [x] 2.3 两个块的普通话与「没有记录」的两种原因：`settingsGroupCategories`/`settingsGroupAssignments`、
  `settingsAssignmentHint`、`settingsAssignmentNote`、`settingsAssignmentNone` + 新增 `settingsAssignmentUnreadable`、
  `settingsPmLaunch*`、`settingsDiagnosisHeading`、来源标签、SID → 会话 —— 按 design 的对照表改两张表
  （`strings/zh.ts`、`strings/en.ts`，键集与占位符集合两边相等）。
  没有记录的两种原因按 `record_present` 选句子，`diagnostic` 原文一律不上屏。
  · 证据：P266-dev3.md §4.4（`✓ 有记录但读不出来时不说「还没派过任务」`、`✓ 命令的诊断字符串不上屏`、`✓ 读侧把这一行报成 assigned=false 且 record_present=true`）+ §7（`settings policy` ✓107 ✗0）；V36.md §1.3 p3 两种原因 zh/en ✓10 ✗0。
- [x] 2.4 其余可见文字：`settingsRefusedRoute`/`settingsRefusedHint`/`settingsUnknownHint`/`settingsBadgeRefuse`/
  `settingsReadOnlyBadge`/`settingsUnknownBadge`/`settingsCategoryHint`/`settingsCategoryPickerHint`/
  `settingCategoryConfirm`/`settingCategoryWritten`/`settingPmWritten`/`settingRefused`/`settingsChoiceKeepUnset`/
  `group_policy`/`group_patrol` 按 design 的对照表改；`TEAM_*` 只留在编辑器标题/确认行/聚焦行命令行/迁移诊断。
  · 证据：P266-dev3.md §3（两张表逐条）+ §7 `panel-strings.mjs .`（键集 384 / 标签 117 / 组 12 / 标记即数据 4 键）；V36.md §1.2（合并后 388 键 / 119 契约键，含 P261 两键标签）。
- [x] 2.5 红侧：把行集过滤拿掉 → 夹具的场景红（夹具键行/标题出现）；把审计尾画回 → 红；把 `record_present` 两侧都当 false → 红；
  还原 → 全绿。 · 证据：P266-dev3.md §5（M1 行集过滤+审计离场 → `panel-p21.sh settings` rc=1 ✓47 ✗33，还原 ✓76 ✗0）+ V36.md §2 R6/R7/R8（含 `record_present` 一律 false → p3 ✓7 ✗3）。

## 3 `key-replies` + 发布者标签（规格 1 条 MODIFIED）

- [x] 3.1 面板两张表：`replyDeclared`→「来自 {from} · {at}」、`replyDeclaredShort`→「来自 {from}」、
  `replyBodyHint`→「只读 · 按发布的原文显示」（en 对应 `from …` / `read-only · shown as published`）；
  总览摘要、列表行、正文页头三处都只出现标签本身。
  · 证据：P266-dev3.md §4.3（列表行 / 正文页头 / 总览摘要三处样张）+ §7（`key-replies-pty.sh --all` ✓80 ✗0）+ §5-M2（加回限定词 → ✓76 ✗4）。
- [x] 3.2 命令行人面：`scripts/replies.mjs` 的 `show` 文本头删掉「（自称）」；`scripts/lib/cmd-reply.sh` 的用法头把
  `--from` 的说明改成「调用方填的标签（1–48 个 `[A-Za-z0-9._-]`）；工具不核对它是谁」，`list` 一行的说明改成
  「`#no <时间> <发布者标签> <标题>`」。存储、`--json`、`--raw`、拒绝规则一字不动。
  · 证据：P266-dev3.md §3（`replies.mjs` 文本头、`cmd-reply.sh` 用法两行）+ §6（`key-replies.sh --all` ✓187 ✗0，含 `--json` 的 `from` 字节相等）+ 本轮复核 `cmd-reply.sh:16,22`。
- [x] 3.3 红侧：给标签加回限定词（面板或 CLI）→ 对应断言红；`--json` 的 `from` 或 `--raw` 字节变 → 红；
  软链/FIFO/穿越/外来根的拒绝组原样绿。 · 证据：P266-dev3.md §5-M2/M3 + V36.md §2 R1–R5（`--json`/`--raw` 字节与三处人面一致；安全拒绝与消毒 32 条全绿）。

## 4 夹具与登记

- [x] 4.1 `tests/panel-p21.sh`：12 处旧文案断言改成新文案（refuse 路线 6 处、两个块标题、`没有完整派单记录`、
  `磁盘读数夹具` 行、wheel/scratch 场景）；「磁盘读数夹具」那一段改成**缺席**断言（frame 里没有它、`team config list`
  仍列出它）；行数公式与 `wait_row` 的期望同步；新增审计缺席、两种「没有记录」、标记删/加的红侧。
  · 证据：P266-dev3.md §3（`panel-p21.sh` 改动清单：旧文案 needle、磁盘读数夹具改缺席断言、审计缺席、两种「没有记录」、标记删/加红侧）+ §7（`settings groups` ✓106 / `settings policy` ✓107 / `settings` 翻转绿 ✓76）+ §8.1（categories 的 8 条既有红与 main 克隆逐条相同）。实际做法：清单写「12 处旧文案断言」，实际 `main...9d402abb` 下 `panel-p21.sh` 是删 25 / 增 45 断言行（V36.md §7）。
- [x] 4.2 `tests/key-replies-pty.sh`（5 处）、`tests/key-replies-ui.sh`（快照/元数据）、`tests/key-replies.sh`
  （`show` 文本头若被断言）同步；**不放宽**任何既有断言。
  · 证据：P266-dev3.md §7（`key-replies-pty.sh --all` ✓80 ✗0、`key-replies-ui.sh` ✓85 ✗0、`key-replies.sh --all` ✓187 ✗0）；V36.md §4（tests 下只有 `panel-p21.sh` 一行 needle，无新增 skip）。
- [x] 4.3 `tests/panel-strings.mjs`：键集/占位符/表外无 CJK 照旧；补一条「标记与隐藏」的交叉检查所需的输入
  （夹具侧可以读 schema，**面板本体不许**）；`tests/panel-snapshots.sh` 若有设置页快照则同步。
  · 证据：P266-dev3.md §3/§7（`panel-strings.mjs` 检查 6：夹具侧读 schema、面板本体不许点名标记键；`panel-snapshots.sh` ✓52 ✗0）+ §5（写死名单 / 面板读 schema 两种变异 → rc=1 点名）。
- [x] 4.4 登记：`tests/section-paths.tsv` 与 `tests/smoke.sh` 的段归属（改 `layout.ts`/两张表/`cmd-config.sh`/`replies.mjs`/
  `cmd-reply.sh` 应各落到既有段；若新增夹具文件按表头规则登记）。 · 证据：P266-dev3.md §7（`section-select.sh --check` → `ok 8 bad 0 SKIP 1` rc=0）+ §3（无新增夹具文件；改动路径映到 26/28/38/57/59/60/61/62/63 既有段）。

## 5 门禁与收尾

- [x] 5.1 相关段：`bash tests/smoke.sh --select 26,28,38,62,63`（面板设置/字符串表/关键回复；段号以现表为准）+
  `TEAM_SMOKE_FAST=1` 快跑 + `openspec validate --all --strict` + `spec-refs.sh --check` + `ledger-ban.sh`（自家 worktree、自家分支）。
  · 证据：P266-dev3.md §6（逐条 rc：validate 20/0、spec-refs `undeclared 0`、ledger-ban `hits=0`、`smoke.sh --paths …` ✓985 ✗0 SKIP1）+ §10.2/§11.3（合并后重跑 ✓1037 ✗0）。实际做法：清单写 `--select 26,28,38,62,63`，apply 按简报改用 `--paths $(git diff --name-only main...HEAD)`（跑 31 段，覆盖同样几段 + 变更闭包）。
- [ ] 5.2 全量门禁留给 PM 复验，按纪律后台跑（`TEAM_SMOKE_FAST` 批内自测、交付前一次全量）。
  · 证据：报告里的全量运行记录
- [x] 5.3 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾、§1.4/§2.5/§3.3 的 **red→green 原始输出**、
  45 行注释的对照表收尾、以及「哪些靠人读（文本类）」的说明。 · 证据：`docs/team/reports/P266-dev3.md`（§2 的 48 行对照表收尾、§5 与 §9.2 的 red→green 原始输出、§4.5「哪些靠人读」）+ 落地提交 `71081b76`。

## 6 独立验证（另一席位，不是 apply 作者）

- [ ] 6.1 在独立冻结克隆重跑全部场景与保留回归（`panel-p21.sh` 全段、`key-replies*.sh` 三件、`panel-strings.mjs`、
  `panel-contrast.mjs`、`panel-snapshots.sh`、`config-cli.sh`、相关 §），逐条给 command/assertion/rc 与 skip。
  · 证据：独立记录 + 原始日志
- [ ] 6.2 逐条重做红侧（破坏必红、还原必绿），并自设计反例：标记在**未知键**上的行为（scratch schema 新增一个带标记的键）、
  `record_present` 的边界（记录文件存在但为空 / 是 FIFO / 是目录）、中英两套文案下的同一批行为、`/` 过滤对隐藏键的三种输入
  （标签 / 裸键 / 值）、`team config list --json` 的 `record_present` 在三种记录状态下逐字节比对、
  发布者标签在 `--json`/`--raw` 与三处人面的一致性。 · 证据：反例脚本与输出尾
- [ ] 6.3 人读（文本类，D170）：按 design 的样张读一遍真实界面与命令行人面（两种语言），确认没有清单里的词与内部编号；
  结论写进 `docs/team/reviews/<ID>.md`，只以证据判过，不因「作者报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md`

## 7 apply / verify 的验收命令（apply 阶段在此冻结具体夹具名）

```bash
bash skills/teamsmith/tests/panel-p21.sh settings categories groups wheel
bash skills/teamsmith/tests/key-replies-pty.sh --all
bash skills/teamsmith/tests/key-replies-ui.sh
bash skills/teamsmith/tests/key-replies.sh --all
node skills/teamsmith/tests/panel-strings.mjs .
bash skills/teamsmith/tests/panel-snapshots.sh
bash skills/teamsmith/tests/smoke.sh --select 26,28,38,62,63
bash skills/teamsmith/tests/section-select.sh --check
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
```

红侧按第 1.4/2.5/3.3 节逐条现场改坏再还原（scratch 变异只写 `${TMPDIR:-/tmp}` 下的 owned 根）；夹具与命令的最终形态
以 apply 冻结的接口为准，但**场景名与红侧方向**不得改（改了就是换合同，要重新走提案）。
