# P277 · 四条已合并变更的清单按证据勾选（归档前置）

- task: P277 · phase: apply · category: code · agent: verify
- change: `-` · anchor: none（infra，账本记账，不改产品）
- branch: `task/P277-archive-checklist-sweep`（local 模式，不推送，分支留本地）
- status: delivered —— 两项留空（两条 0.2）与四条证据缺口待 PM 裁定/补做；其余 52 项按证据勾选
- time: 2026-10-15

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/cli-help/tasks.md` | 35 项里 34 项由 `[ ]` 改 `[x]`，每行末把「证据」行替换成可复核的指针（报告段 / 复验段 / 命令与 rc / 提交号），差异处按 P245 的写法加「实际做法：」注记；0.2 留空并写明为什么 |
| `openspec/changes/turn-notice-merge/tasks.md` | 23 项里 18 项勾选，同上；0.2 留空；7.1–7.4 是验证席位的项，不动 |
| `docs/team/reports/P277-verify.md` | 本报告：逐条表（勾了/留空 + 证据 + 我查了哪里）、缺口单列一节、四条变更的归档前置状态小结 |

改动面只有这两个清单文件加本报告：`git diff --stat main..HEAD` = 2 files changed（另加本报告一个文件）。产品、测试、规格、提案、delta 一字未动。

## 测试状态（先说）

- **本任务没有跑四条变更的夹具或选段门禁**（任务书边界：「本任务不做任何验证跑，只做记账」）。我没有重跑 `help-surface.sh`、`routes.sh`、`bg-ledger.sh`、`smoke.sh` 或任何选段；四条变更的绿/红结论一律引用已有记录，不引用我自己的运行。
- 三条验收命令在本分支树上真跑，全绿（§7）。
- 我实际做的核对都是**只读**的：读 `docs/team/reports/P260-dev.md`、`docs/team/reports/P251-dev3.md`、`docs/team/reviews/V38.md`、`docs/team/reviews/V34.md`、四份提案复核与两份合并记录；在树上 `grep`/`sed` 核对清单里点名的文件、键、函数、登记行是否存在（`commands.tsv`、`help.{en,zh}.tsv` 的键集、`EFFECT_VOCAB`、`check_invariants`、`smoke.sh` §51、`section-paths.tsv` 的 §13c、`TEAM_NOTIFY_DETAIL_MAX` 四处登记、`team_meeting_help`、`cmd-agents.sh` 的共用锁）；以及全仓 `grep` 核对「记录里到底有没有跑过那条命令」（投影、`spec-refs.sh --check`）。

## 1. 结论速览：四条变更现在的归档前置状态

| change | 清单总数 | 我已勾 | 仍留空 | 归档前置 |
|---|---|---|---|---|
| `cli-help` | 35 | 34 | 0.2（apply 阶段投影自证） | 只差 0.2 这一项；提案面另有一处与 delta 不一致（G5）建议归档前顺手改 |
| `turn-notice-merge` | 23 | 18 | 0.2（投影自证）+ 7.1–7.4（验证席位，归 PM） | 差 0.2；delta 里有一句残留措辞（G6）归档时要么改要么明确接受 |
| `panel-preview-and-compose` | 21 | 17（apply 面全勾） | 6.1–6.4（全是「独立验证」那一节，归 PM） | apply 面已齐，等 PM 按 V33 勾 6.1–6.4；本轮我没有可勾项 |
| `pm-reply-discipline` | 20 | 15（apply 面全勾） | 3.5（条件项）+ 5.1–5.4（验证席位） | apply 面已齐，等 PM 按 V37 勾 5.1–5.4；3.5 见下 |

一句话：**这四条今天都没有「apply 没做完」的遗留**；挡在归档前的只有两件同一形状的事——`cli-help` 与 `turn-notice-merge` 各缺一次 apply 阶段的独立树投影自证（提案阶段都做过一次，但那次在 delta 修订之前），以及 PM 自己那批验证/归档项的勾选。

## 2. `cli-help`（35 项：勾 34 / 留空 1）

### 2.1 逐条

| 项 | 勾选 | 证据（指针） | 我查了哪里 |
|---|---|---|---|
| 0.1 | 勾 | `docs/team/reviews/cli-help-proposal.md`（两轮：F1/F3 → ACCEPTED；六个裁定点）+ P260-dev.md §1/§2 落点表 + V38.md §1/§2 | 读了提案复核两轮全文与报告 §1/§2，把六条裁定逐条对到落点；**报告没有单列「裁定摘录」小节**，已按实际写成注记 |
| 0.2 | **留空** | 见 §6 G1 | 全仓 `grep 'archive -y cli-help'`（只命中提案复核与清单自身）；读 P260-dev.md 与 V38.md 的验收段 |
| 0.3 | 勾 | P260-dev.md §7「改动前」列 + §2 的 7.1 行；V38.md §2 表与 §11 L5/L11（基线树 `362cd1ed`，`routes.sh walk` ✓122 ✗0） | 核对了改动前数字与基线命令；清单写的「`routes.sh`（214 ✓ 量级）」在记录里是 `walk ✓122`，已注记口径差 |
| 1.1 | 勾 | `scripts/strings/commands.tsv` + P260-dev.md §1/§3.2（coverage）+ V38.md §1（双向 comm） | 树内核对文件；读 coverage 断言与 V38 的源码级导出核对 |
| 1.2 | 勾 | `scripts/lib/cmd-help.sh` + P260-dev.md §1/§2/§8 + V38.md §3 | 树内核对文件；`grep 'want layout'` 找到残留分支（`help-surface.sh:1104`），与 V38 的 O6 一致 |
| 1.3 | 勾 | P260-dev.md §5 样张 + §3.3（walk ✓142 ✗0）+ V38.md §5.2（缩进统计） | 读了样张与 V38 的前导空格统计，逐条对照 design 阶梯 |
| 1.4 | 勾 | P260-dev.md §1/§2 的 1.4 行 + V38.md §1；树内 `cmd-meeting.sh:262`、`cmd-help.sh:197` | `grep team_meeting_help`（只剩两行薄委托）、`grep '占位符\|placeholder\|插值'`（只命中 `probe_args` 注释，见 G4） |
| 2.1 | 勾 | P260-dev.md §2 的 2.1 行 + §3.2 的 route 组 + V38.md §1（132 次 `cmp`） | 读了 route 组与 V38 的逐字节比对结论 |
| 2.2 | 勾 | P260-dev.md §2 的 2.2 行 + §6 红侧 ③ + V38.md §1（五种拒绝形状） | 读了两种记录里的拒绝形状与状态指纹证据 |
| 2.3 | 勾 | P260-dev.md §5 入口页样张 + V38.md §5.1（26 行、8 组、4 条上手命令） | 数了样张行数；记 D170 把「≤30 行/3–5 条」的门禁计数移出门禁、改由评审判 |
| 2.4 | 勾 | P260-dev.md §2 的 2.4 行 + §6 红侧 ④ + V38.md §1（正控制：同一夹具上 `paths --json` 会写标记） | 读了「不加载配置」的正控制证明 |
| 2.5 | 勾 | P260-dev.md §6 的 `--flip` 表（8 条）+ §10.4 + V38.md §4（三处变异） | 逐条对 8 条 flip 与 D170 删除项，确认「退回菜单」那条由 route 组覆盖 |
| 3.1 | 勾 | 两表在树 + P260-dev.md §1/§3.2 + V38.md §3 末行 | **我自己数过**：非注释行各 465 键、两表 `diff` 为空 rc=0（报告记 464、V38 记 465，已注记口径差） |
| 3.2 | 勾 | P260-dev.md §8（四条实测）+ `references/workflows.md:484,487` + V38.md §3 | `grep` 两个旋钮的登记行；读四条实测输出 |
| 3.3 | 勾 | P260-dev.md §2 的 3.3 行 + §6 红侧 ⑥⑧ + V38.md §1（`«missing key: …»` + 英文兜底） | 读了缺键可见的机制断言；记「键集比对非零退出」已按 D170 删除 |
| 3.4 | 勾 | P260-dev.md §3.2 的 lang 组 + §6 红侧 ⑦ + V38.md §1（三条机器出口字节相同） | 读了 en/zh 与「就地改坏语言表」两组证据 |
| 3.5 | 勾 | P260-dev.md §6 红侧 ⑤⑥⑦ + §3.2 的 lang 组 + V38.md §3 表 | 逐条对 flip；记 D170 后「删一个 zh 键不点名」改成破坏「缺键可见」机制 |
| 4.1 | 勾 | P260-dev.md §2 的 4.1 行 + §5 样张 + V38.md §5.4/§3 末行 | 读了 13 个概念在两表的定义与页内 `Concepts` 的复述 |
| 4.2 | 勾 | P260-dev.md §5 命令页样张 + §2 的 4.2 行 + V38.md §5.5 | 读了 12 个小节齐全有序的样张与 V38 的六问核对 |
| 4.3 | 勾 | P260-dev.md §9（五页英文 + 两页中文自答）+ V38.md §5.5 | 读了逐页自答表与独立读页结论；顺带记作者读页翻出的三条真缺陷 |
| 4.4 | 勾（带注） | P260-dev.md §4/§6 + V38.md §6.1（三个函数在候选夹具里不存在） | 确认这三条文本类红侧已随 D170 删除，保留的同类逻辑红侧是 ⑧ |
| 5.1 | 勾 | P260-dev.md §2 的 5.1 行 + §3.2 的 claims 组 + V38.md §4（取值分布）+ 树内 `EFFECT_VOCAB` | `grep EFFECT_VOCAB`；读 V38 独立数出的取值分布 |
| 5.2 | 勾 | P260-dev.md §2 的 5.2 行（44 条探针）+ §3.2 + V38.md §4（三处变异 rc=1） | 读了逐命令探针与三处变异的红侧 |
| 5.3 | 勾（带注） | P260-dev.md §2 的 5.3 行 + §4 表第三行 + V38.md §5 | 确认这条文本类一致性检查已按 D170 移出门禁，逻辑内核仍在 claims/walk |
| 5.4 | 勾 | P260-dev.md §6 + V38.md §4 变异三连 + §6 红侧 ⑧ | 读了变异三连与保留的逻辑红侧 |
| 6.1 | 勾 | P260-dev.md §2 的 6.1 行 + §3.3 + §6 红侧 ⑪ + V38.md §2 | 读了 V38 对 `mr_walk_a` 的源码级证明与双向 comm |
| 6.2 | 勾 | P260-dev.md §3.3/§7/§6 红侧 ⑬ + V38.md §2/§7 | 读了 47→66、75→86 的前后数字与「逐级判到」的非空洞断言 |
| 6.3 | 勾 | P260-dev.md §6 的 routes flips 表 + §10.1（翻转⑩对照的修法 `9033b88c`）+ §10.4（✓17 ✗0）+ V38.md §7 | 读了既有 10 条翻转保留与新增两条 |
| 6.4 | 勾 | P260-dev.md §7 表 + §3.3 汇总行 + V38.md §2 表与末段（口径差异） | 读了前后覆盖数字，并记 design 的 48 命令页 vs 实测 44 + 5 别名 |
| 7.1 | 勾 | P260-dev.md §2 的 7.1 行 + §3.2（`invariants`）+ V38.md §6.1 + 树内 `check_invariants` | `grep check_invariants`；读 `invariants` 的三条内容 |
| 7.2 | 勾 | P260-dev.md §2 的 7.2 行 + §3.2 + §6 红侧 ⑦ + V38.md §3/§0 | 读了唯一允许改的退出行为（未知 token + `--help` → 2）与机器出口断言 |
| 7.3 | 勾（带注） | 树内 `smoke.sh:19146-19161`、`section-paths.tsv` §51、`references/workflows.md:484,487` + P260-dev.md §2/§3.4/§11 | `grep` 三处登记；记旋钮登记在 `workflows.md` §K 而不是 `config.md`（那个面归 P251） |
| 7.4 | 勾 | P260-dev.md §6 末段（`变异没落地（夹具缺陷）`）+ §10.4 + V38.md §9 L15/§4 | 读了落地断言机制与 V38 的独立复核 |
| 8.1 | 勾（带注，见 G3） | P260-dev.md §3.1/§3.4/§3.5/§3.6/§3.7 + §10.4 + V38.md §8.2 | `grep 'spec-refs'` 在两份记录里 **0 命中**；记 `--select 51,18,19` 实际按 `--paths` 闭包跑 |
| 8.2 | 勾 | `docs/team/reports/P260-dev.md` 全篇 + V38.md §0/§5/§6/§10 | 读了报告结构与两处跨任务断言更新的自报 |
| 9.1–9.3 | 留空 | 验证席位（任务书：不要勾 PM 与复验的项） | 只读了任务书边界 |

### 2.2 与清单原文不一致的实际做法（不改原文，已写成行内注记）

1. **D170 把文本类移出门禁**：1.2/1.3/2.3/3.1/3.3/4.1/4.2/4.4/5.3/5.4 这十项里都有「由门禁断言」的部分，实际按用户裁定改成「渲染器仍按设计做 + 评审读样张」。证据是 P260-dev.md §4 的「删掉的门禁断言」表与 V38.md §5/§6.1。
2. **`--select layout` 已不存在**（1.2 点名的命令）：V38.md §0 的 O6 实测它打印 `check_layout: command not found` 后 rc=0，残留分支今天还在 `help-surface.sh:1102,1104`。
3. **0.3 的「214 ✓ 量级」**：记录里冻结的改动前基线是 `routes.sh walk` ✓122 ✗0（V38.md §11 L11），没有改动前全量 `routes.sh` 的原始日志。
4. **3.1 的键数**：报告记 464、V38 记 465、我数出 465（非注释行）——同一张表的计数口径差 1，不影响结论。
5. **7.3 的旋钮登记位置**：实际在 `references/workflows.md` §K，不是 `config.md`。
6. **8.1 的选段方式**：实际是 `smoke.sh --paths <改动路径>`（108 段）而不是字面的 `--select 51,18,19`；§18/§19 的 patterns 含 `skills/teamsmith/references`/`skills/**`，被同一闭包选中。
7. **1.4 的 heredoc 删除**：`cmd-meeting.sh` 里 `team_meeting_help` 这个**函数名保留**了，但只剩两行、委托 `team_help_command_page meeting`；第二个真源确实没了。

## 3. `turn-notice-merge`（23 项：勾 18 / 留空 5）

| 项 | 勾选 | 证据（指针） | 我查了哪里 |
|---|---|---|---|
| 0.1 | 勾 | `docs/team/reviews/turn-notice-merge-proposal.md`（ACCEPTED，含两条 PM 注记；三个裁定点）+ P251-dev3.md 的 Deliverables 表与 Decisions + V34.md §2.1/§2.3 | 读了提案复核全文与报告的落点；报告同样没有单列「三个裁定点」小节 |
| 0.2 | **留空** | 见 §6 G2 | 全仓 `grep 'archive -y turn-notice-merge'` **0 命中**；提案复核记过一次试归档（范围追加之前） |
| 1.1 | 勾 | P251-dev3.md Deliverables 第 1 行 + 验收 ②（`--select merge,detail,wake,…` 48 passed/0）+ V34.md §2.1（11 条用例）；树内 `cmd-agents.sh:1868`（共用一把锁） | `grep team_inbox_append\|flock`；读 V34 的 11 条合并键用例 |
| 1.2 | 勾 | P251-dev3.md Deliverables 第 1 行 + V34.md §2.1/§2.5（与 v0.2.0 单事件行 `IDENTICAL`）+ 验收 ⑤ | 读了汇总行形状与兼容对照 |
| 1.3 | 勾 | P251-dev3.md Deliverables 第 5 行 + V34.md §2.2（`state=extended` 日志）+ §2.6（删除行审计） | 读了扩展消费写入结果的证据与断言审计 |
| 1.4 | 勾 | P251-dev3.md Flip evidence（12 处破坏）+ V34.md §3（15 条自写破坏轮） | 逐条对 12 处破坏与 V34 的红点 |
| 2.1 | 勾 | P251-dev3.md Deliverables 第 1/3 行 + 验收 ② + V34.md §2.3（9 条用例，含上界逐拍快照）；树内 `cmd-config.sh:129`、`references/config.md:162` | `grep TEAM_NOTIFY_DETAIL_MAX`（键表/flat/文档/面板标签四处）；读轮转边界证据 |
| 2.2 | 勾 | P251-dev3.md Deliverables 第 2 行 + V34.md §2.3（缺口点名非零退出、不 ack）+ 验收 ②⑤（V34.md §5 复跑 `--select 7,13,13b,13c` ✓519 ✗0） | 读了只读与缺口语义 |
| 2.3 | 勾 | P251-dev3.md Flip evidence 表 + V34.md §3 表 | 逐条对四条 detail 红侧 |
| 3.1 | 勾 | P251-dev3.md Deliverables 第 5 行 + 用户可见行为变化第 1 条（范围追加）+ V34.md §2.2（9 条用例） | 读了敲门计数证据（交付 +1、合并 0、中断 +1、挂起 +0、写失败 0） |
| 3.2 | 勾 | P251-dev3.md Flip evidence 表 + V34.md §3 表 | 逐条对四条 wake 红侧 |
| 4.1 | 勾 | P251-dev3.md 用户可见行为变化第 2/3 条 + V34.md §2.4/§5 + 验收 ⑤ | 读了 digest/面板/ack 三处读者证据 |
| 4.2 | 勾 | V34.md §2.1/§2.3 + P251-dev3.md Decisions（§13 的 manualBreak 修正）+ 验收 ⑤ | 读了手工行不合并/不进明细与打断场景 |
| 4.3 | 勾 | V34.md §2.4（按最后一条判陈旧，含 `line.tip` vs reviews HEAD 的对照）+ P251-dev3.md 用户可见行为变化第 3 条 | 读了 board done 与 reviews HEAD 两条判据 |
| 4.4 | 勾 | V34.md §2.1（窗口内重复不计不记）+ P251-dev3.md Deliverables/Decisions（协议通知段重写） | 读了去重窗口语义 |
| 5.1 | 勾（带注） | 树内 `cmd-config.sh:129,265`、`references/config.md:162`、`panel/src/strings/zh.ts:346` + P251-dev3.md Deliverables 第 3/6 行 + 验收 ②④ | `grep` 四处登记；记 `protocol.md` 的交叉引用实际是把该段旧句按新合同重写 |
| 5.2 | 勾 | P251-dev3.md Deliverables + 验收 ④ + V34.md §5（守卫行 + 破坏轮后工作树干净）；树内 `section-paths.tsv:81`（§13c 含 `bg-ledger-harness.mjs`） | `grep bg-ledger-harness`；读了反向守卫证据 |
| 6.1 | 勾（带注，见 §6 G7 末条） | P251-dev3.md 验收 ①③④⑤⑥⑦ + V34.md §5（`spec-refs.sh --check` rc=0、validate 17/0） | 逐条对七条验收的 rc；记 `spec-refs.sh --check` 是复验者跑的、作者侧没跑 |
| 6.2 | 勾 | `docs/team/reports/P251-dev3.md`（Deliverables/Verification evidence/Flip evidence/Decisions）+ V34.md §0/§3 | 读了报告结构与复验对四步完整性的确认 |
| 7.1–7.4 | 留空 | 验证席位（任务书：不要勾 PM 与复验的项） | 只读了任务书边界 |

实际做法注记：0.1（报告没有单列裁定小节）、5.1（protocol 段是重写不是加一行）、6.1（`spec-refs.sh --check` 由复验者 V34 跑出 rc=0，作者侧七条验收里没有它；全量门禁未跑，报告已点名没跑的 12 个键）。

## 4. `panel-preview-and-compose`（21 项：勾 17 / 留空 4）——本轮我没有可勾项

剩下的四项全是第 6 节「独立验证（另一席位，不是 apply 作者）」：6.1（独立克隆重跑第 2/3/4 节全部场景）、6.2（逐条重做红侧）、6.3（反面证据）、6.4（判 correctness 门）。按任务书「不要勾 PM 与复验的项」留空，归 PM（V33 的记录就是这四条的兑现依据；`docs/team/reviews/V33.md` 在树、`docs/team/reviews/P249.md` 合并记录判定 PASS）。

apply 面的 17 项（1.1–5.4）在我接手前已全部勾选，本轮我没有复核它们的证据链（不在本任务范围：任务书只要求「按证据勾选」，而已勾项不是我该重判的对象）。

## 5. `pm-reply-discipline`（20 项：勾 15 / 留空 5）——本轮我没有可勾项

| 项 | 为什么留空 |
|---|---|
| 3.5 | **条件项**：原文「仅当 PM 按裁定点 5 裁『补声明』」。裁定点 5 的裁定是「**§62 的行不补声明**，本 change 不动 `section-paths.tsv`」（`docs/team/reviews/pm-reply-discipline-proposal.md` 第 5 条），所以这一项的前提不成立、不该勾；`tests/section-paths.tsv` 里 §62 今天也没有 `pm-prompt.md.tmpl`/`protocol.md`/`SKILL.md`（我已 `grep` 核对）。留空是「条件未触发」，不是欠账 |
| 5.1–5.4 | 第 5 节「独立验证（另一席位，不是 apply 作者）」，归 PM（V37 是这四条的兑现依据） |

apply 面的 15 项在我接手前已全部勾选，本轮同样没有复核它们的证据链。

## 6. 缺口（单独一节）

### G1 · `cli-help` 0.2 没有 apply 阶段的投影自证

- **事实**：本仓 `docs/team/` 全量 `grep 'archive -y cli-help'` 只命中两处——提案复核 `docs/team/reviews/cli-help-proposal.md`（`archive cli-help` → `2026-10-14-cli-help`、归档后 18/0）与本清单自身；P260-dev.md 与 V38.md 的验收段只记 `openspec validate --all --strict`（18/0 → 19/0）。
- **为什么算缺口**：那次投影发生在 **D170 收窄之前**；D170 删了三条 requirement、收窄了两条，投影应当对着收窄后的 delta 再跑一次才算「apply 阶段的独立树投影自证」。
- **不阻塞的那一半**：清单同时要求「确认没有第二个未归档 change 动 `help-surface`/该走查要求」——本轮复核**成立**（未归档 change 里只有 `cli-help` 带 `help-surface` 与 `dispatch` delta；`P272` 虽也带 `help-surface` delta，但它还没开工、提案也未并入）。
- **建议**：归档时由 PM 顺手在副本里跑一次 `cp -a openspec /tmp/<x> && (cd /tmp/<x> && openspec archive -y cli-help && openspec validate --all --strict)`，把命令与输出尾补进本行；或明确接受「提案阶段的投影 + 当前 validate 全绿」这一组合。

### G2 · `turn-notice-merge` 0.2 没有 apply 阶段的投影自证

- **事实**：`grep 'archive -y turn-notice-merge'` 全仓 **0 命中**；提案复核 `docs/team/reviews/turn-notice-merge-proposal.md` 记过一次试归档（`archive` → `+1 ~1 -0`、归档后 16/0），但那次在**范围追加（挂起只记录、不叫醒）之前**；P251-dev3.md 的七条验收与 V34.md §5 都没有跑 `archive -y turn-notice-merge`。
- **对照**：清单要求的「逐条 MODIFIED 与基线逐场景对照」这半条**有**独立证据——V34.md §5 的机械复核（MODIFIED 块保留基线全部 16 条场景，`missing from delta: []`，另加 14 条场景与 6 条 ADDED 场景）。缺的只是「投影跑绿」这一半。
- **建议**：同 G1，归档时补跑一次或明确接受。

### G3 · `cli-help` 8.1 点名的 `spec-refs.sh --check` 没有 rc 记录

`grep 'spec-refs'` 在 `docs/team/reports/P260-dev.md` 与 `docs/team/reviews/V38.md` 里 **0 命中**；8.1 其余四条（validate、`help-surface.sh --all`、`routes.sh`、按路径闭包的选段、`ledger-ban`）都有命令与输出尾。同一项在 `turn-notice-merge` 6.1 里由复验者 V34 跑出了 rc=0，所以那边不算缺口。**性质**：证据缺口（不是产品缺陷）；PM 的全量门禁或归档时会覆盖这条 lint。

### G4 · `cli-help` 1.4 的「未知占位符判红」没有断言

1.4 要求「`$TEAM_PROJECT`/TTL 走已声明占位符、**未知占位符判红**」。渲染器侧确实只解析已声明的两个占位符（`cmd-help.sh:197` 的 `team_help_subst`），但**没有任何断言**证明未声明的占位符会判红：`grep '占位符\|placeholder\|插值'` 在 `help-surface.sh`/`routes.sh` 里只命中 `probe_args` 的一行注释。报告与 V38 也都没有点名这条。**性质**：小缺口（按 D170 归文本类，或本来就没实现这条断言）；建议 PM 裁定是补一条断言、还是把它归入评审读样张。

### G5 · `cli-help` 的 `proposal.md` 仍在承诺已被 D170 移出门禁的检查（文档与 delta 不一致）

`openspec/changes/cli-help/proposal.md` 里至少五处把文本类检查写成「由夹具兑现」：

- 第 48 行：「命令用法行必须是 3–5 条 —— 两条都由夹具断言规模，超了红并点名越界的那几行（红侧 ⑥）」；
- 第 118–119 行：夹具清单写着「分级覆盖 / 第 0 级规模 / 键集 / 布局层级 / 声明探针 / 机器出口 / 内容不变量，逐组红侧；**版式阶梯只在这里测一次**」；
- 第 127–128 行：把「第 0 级的规模上限、页面深度与必定义概念、固定层级版式与可解析性」列进 `help-surface` 的合同面；
- 第 191 行与第 201–204 行的「承诺清单」表：规模断言、布局组、内容组逐行对应「红侧」；
- 第 213 行：验收命令注释写「分级覆盖/规模/键集/布局/声明/机器出口/内容」。

而 delta（`specs/help-surface/spec.md`，今天 4 条 requirement）与夹具（`scale`/`layout`/`content` 三组已删）都已按 D170 收窄。P260-dev.md §11 已把这件事点名给 PM（「proposal 是 PM 的文件，我没动」）。**性质**：文档说假话（提案面，不是合同面）；归档前建议改那几行，或明确接受「proposal 记录的是收窄前的提案」。

### G6 · `turn-notice-merge` 的 delta 里留着一句与新句矛盾的措辞

`openspec/changes/turn-notice-merge/specs/notify-and-inbox/spec.md:74-75` 的 MODIFIED 正文仍写「the inbox line and the **knock payload** SHALL carry the tag `[auto·suspended]`」，而同一文件第 38–39 行（范围追加加进来的规范句）写「a line tagged `[auto·suspended]` SHALL NOT enqueue anything」。V34.md 的备注 2 已经指出：归档进 canonical spec 后，前一句会指向一个不存在的 knock 载荷；语义由「SHALL NOT enqueue」定死，不影响实现判定。**性质**：归档时要么改（例如改成「收件箱行（不涉及 knock 载荷）」）、要么明确接受。

### G7 · 一处「作者报告与事实的表述差」（不阻塞，已在记录里更正）

P251-dev3.md 把 §12b-h ⑥ 的既有红归因成「`TEAM_WATCH_NUDGE_GAP` 已退役、没有代码读它」；V34.md §2.8 实测旧名仍被 `team_pulse_var` 读到，真正压掉提醒的是夹具仓库自己的 `config.sh:104 TEAM_PULSE_NUDGE_GAP=900`。结论（该红在 v0.2.0 上就存在、不是本变更引入）不变，V34 已在记录里更正，我在 6.1 里引的是更正后的版本。

## 7. 验收命令与输出（在本分支树上真跑）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -2
✓ spec/watchdog
Totals: 24 passed, 0 failed (24 items)
rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（<home>/<user>/…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<home>/<user>/…/.worktrees/verify scope=published files=1553 hits=0 names=ok user=resolved
rc=0

$ git diff --check; echo rc=$?
rc=0
$ git status --short
?? docs/team/reports/P277-verify.md

$ git diff --stat main..HEAD
 openspec/changes/cli-help/tasks.md          | 143 ++++++++++++++--------------
 openspec/changes/turn-notice-merge/tasks.md |  73 +++++++-------
 2 files changed, 104 insertions(+), 112 deletions(-)
（本报告是随后单独提交的第三个文件；`git status --short` 在提交前只剩它一个未跟踪项）
```

`git merge main`：本分支起点是 `main` 的 tip（`423a2a59`）。交付前按任务书再合一次，`main` 已前进（`a9626a52` 是 PM 的 `panel-plain-language` 归档记录），merge 提交 `06a85c74`；两条清单在本轮没有被 `main` 碰到，无冲突。

勾选后的清单计数（合并后复核）：`cli-help` 34 勾 / 4 空（0.2 + 9.1–9.3）、`turn-notice-merge` 18 勾 / 5 空（0.2 + 7.1–7.4）、`panel-preview-and-compose` 17 勾 / 4 空（6.1–6.4）、`pm-reply-discipline` 15 勾 / 5 空（3.5 + 5.1–5.4）。

## 8. 给 PM 的观察

1. **V38 的六条观察里只有三条有归宿**：`P272-help-robustness`（`todo`）收 O1（非 UTF-8 locale 排版）、O2（`__` 内部入口的合同文字）、O6（菜单分组可达性断言缺口）+ V36 的 O7；**O3**（用法行续行缩进 4 不在 design 阶梯里）、**O4**（`undo-by-*` 词表项没有使用者、判据空转）、**O5**（中文散文 17 处 ASCII 双引号）今天没有任务承接——它们都是非阻塞观察，但如果 PM 认为归档后仍要收，需要单独派单或明确关闭。
2. **O6 的第二半（夹具卫生）也没有归宿**：`help-surface.sh:1102,1104` 还留着 `want scale`/`want layout` 两个悬空分支，于是 `--select layout` 打印 `command not found` 后 **rc=0（✓0 ✗0）**；未知选段名同样静默通过。P272 的第 3 条只覆盖可达性断言，不含这处卫生问题。
3. **归档顺序**：`cli-help` 与 `turn-notice-merge` 各自是**唯一**动自己 capability 的未归档 change，可以独立归档；但 `P272`（`todo`，`change: cli-help`、`deltas: help-surface`）将来会再动 `help-surface`——它的任务书写了「若已归档则改 `openspec/specs/help-surface/spec.md`」，所以先归档 `cli-help` 不会挡它。
4. **两份 0.2 是同一件事**：如果 PM 决定在归档时统一补跑投影（两条命令、各一次），两项可以一起关掉；G5/G6 也都可以在同一次归档动作里顺手处理。

## 9. 未做 / 未测项（如实点名）

- **没跑任何夹具或门禁**（任务书边界）：没有重跑 `help-surface.sh`、`routes.sh`、`bg-ledger.sh`、`smoke.sh` 或任何选段；本报告里的所有绿/红都是引用已有记录。
- **没碰**产品、测试、规格、提案、delta、`section-paths.tsv`、别的 change 与任务书；只改了两个 `tasks.md` 与本报告。
- **没有复核已勾项的完整证据链**（`panel-preview-and-compose` 与 `pm-reply-discipline` 的 apply 面 17/15 项），那不在本任务范围。
- **没有判任何 `verification` 正确性门**，也没有替 PM 勾提案复核/独立复验/归档/全量门禁那批项。

## Suggested next steps

1. 裁定 G1/G2（两条 0.2）：归档时补跑投影并补指针，或明确接受提案阶段投影 + 当前 validate 全绿。
2. 归档前顺手处理 G5（`cli-help` 的 `proposal.md` 五处旧承诺）与 G6（`turn-notice-merge` delta 的 knock 载荷句）。
3. 勾 PM 自己那批项：`panel-preview-and-compose` 6.1–6.4（依 V33）、`pm-reply-discipline` 5.1–5.4（依 V37）、`turn-notice-merge` 7.1–7.4（依 V34）、`cli-help` 9.1–9.3（依 V38）。
4. 决定 O3/O4/O5 与 O6 的夹具卫生是补进 P272 还是明确关闭。
