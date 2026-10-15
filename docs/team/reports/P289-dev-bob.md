# P289 · 按证据勾选 `help-robustness` 的清单（归档前置）

- task: P289 · phase: apply · category: code · agent: dev-bob
- change: `help-robustness` · specs: `help-surface` · deltas: `-`（本任务不改 delta）
- branch: `task/P289-help-robustness-checklist`（local 模式，不推送，分支留本地）
- status: delivered —— 23 项全部按已提交证据勾选，0 项留空；差异 3 条、部分证据 4 条单列在 §3/§4
- time: 2026-10-15

## 测试状态（先说）

- 本任务只改账本（`openspec/changes/help-robustness/tasks.md` + 本报告），**没有重跑**该 change 的夹具或门禁
  （任务书边界：只做按证据勾选；P278 与 V41 已经跑过）。本报告里的绿/红结论**一律引用已有记录**，不引用我自己的
  运行。
- 任务书「验收」一节的命令在本分支树上**真跑**：`openspec validate --all --strict` rc=0（23 passed）、
  `ledger-ban.sh` hits=0 rc=0、`git diff --check && git status --short`（§6）。
- 我实际做的核对都是**只读**的：读 `docs/team/reports/P278-verify.md`（全文）、`docs/team/reviews/V41.md`（全文）、
  `docs/team/reviews/help-robustness-proposal.md`、`docs/team/reports/P272-verify.md`、
  `docs/team/reviews/P278.md`（合并记录）、`openspec/changes/help-robustness/{proposal,design,tasks}.md`；
  在树上 `grep`/`sed` 核对清单点名的实现记号是否真的在（`TEAM_HELP_PLACEHOLDERS`、`local internal=`、
  `flip_case` ⑨⑩⑪⑫⑬⑭、`check_locale` 的 python3 `unicodedata`/`cmp -s`、`smoke.sh` §51 的 FAST 选集、
  `section-paths.tsv` §51 行、`config-cli.sh` 的 O7 三条行为断言与红侧、`grep check_layout|check_scale` 无输出）；
  另跑了两条**只读/即时**的现场探针（`help-surface.sh --select layout|nosuchsection` → rc=2；
  `section-select.sh --paths …/cmd-config.sh` → rc=0 且输出里有 `51 ←`）。
- 本任务不是缺陷修复类，没有 flip 证据；该 change 自己的红侧（`help-surface.sh --flip` 的 14 条 + O7 的
  `config-cli.sh` 红侧）逐条引用 P278 报告 §4 与 V41 §2.3/§4，我没有重跑它们。

## Deliverables

| Path | What |
|---|---|
| `openspec/changes/help-robustness/tasks.md` | 23 项由 `[ ]` 改 `[x]`；每项的「证据」占位符换成可复核指针（P278 报告段 / V41 段 / 提交号 / 命令与 rc）；差异与部分证据处加行内注记。**条目正文一字未改**（只填证据字段） |
| `docs/team/reports/P289-dev-bob.md` | 本报告：逐条表（勾选 + 证据 + 我查了哪里）、差异与部分证据单列、验收命令与输出 |

改动面只有这两个文件（`git diff --stat main..HEAD` 只列它们）；产品、测试、规格、提案、delta 一字未动。

## 1. 结论速览

| 项 | 数量 |
|---|---|
| 清单条目 | 23 |
| 本轮勾选 | 23 |
| 留空 | 0 |
| 带差异注记 | 3（2.1 变量名 / 4.1 六个 vs 八个 / 5.2 否定式措辞断言） |
| 部分证据注记（勾了，但某半段的原始输出不在记录里） | 4（0.2 / 0.3 / 7.1 / 7.2） |
| 发现「apply 没做完」的缺口 | **0** |

一句话：这个 change **没有** `cli-help` 那轮那种未落地的条目（当时翻出 G4 的「未知占位符判红」与 G3 的 rc 缺失）。
P278 把四条合同缺口（O1/O2/O6/G4）都落成了行为 + 断言 + 红侧，O7 与两条登记按裁定收边，V41 在冻结 tip 上独立
复核 PASS。剩下的只是**证据形态**上的差异（原始输出没进 apply 报告、条目正文与实现的措辞差），见 §3/§4，
都不影响「做完了没有」的判断。

## 2. 逐条勾选表

| 项 | 勾选 | 证据（指针） | 我查了哪里 |
|---|---|---|---|
| 0.1 | 勾 | 提案复核（五裁定全部按推荐采纳）→ P278 §1 行 5.x/§3.3（裁定 2）、§3.4/§6.6（裁定 3）、§1 行 7.1/§4 选段器红侧（裁定 4）、§3.2/§6.2（裁定 5）、§3.6 + `1a1640e0`（裁定 1） | 读提案复核全文与 P278 §1/§3/§4/§6，把五个裁定逐条对到落点；报告没有单列「五裁定摘录」小节（同 P277 对 `cli-help` 0.1 的处理） |
| 0.2 | 勾（部分证据，§4） | P278 §3.6：`validate` rc=0 → `archive -y help-robustness` rc=0（`help-surface: +1 ~2`）→ `validate` rc=0；标题/正文核对在 P272 §4（五条标题、无重复）与提案复核（场景 4→6、3→4 零丢失） | 读 P278 §3.6 与 P272 §4 的投影输出；核对归档目录名 `2026-10-15-help-robustness` |
| 0.3 | 勾（部分证据，§4） | P278 §3.1：12 行 locale×语言表（C 下 en 106 格 / zh 非法 UTF-8）、53 页探针（248 / 43 违规）、选段器基线、G4 基线；P272 §2.2/§4：`--select coverage,lang,invariants,route` ✓28 ✗0 rc=0、`spec-refs.sh --check` rc=0、`config-cli.sh:365-367` needle 现状 | 读两份报告的基线段；核对数字逐条对得上。改动前的 `--all` 与 config-cli ✓/✗ 计数没有记录（P272 §4 明说 `--all` 没跑） |
| 1.1 | 勾 | P278 §6.3（`LC_ALL=C printf|od -An -tu1` 取字节 + 手写 UTF-8 解码 + 码点判格）、§6.2（三处首行折行）、§3.2（含 HEAD 逐字节对照）；V41 §2.1/§2.4（独立 oracle + 旋钮三值） | 树内 `grep` `od -An -tu1`/`team_help_byte_len`；读 §6.2/§6.3 与 V41 §2 表 |
| 1.2 | 勾 | P278 §3.2 `locale` 组 8 条 ✓、`LC_ALL=C --all` ✓105 ✗0、`--select locale` ✓8 ✗0；夹具自己的计数 `help-surface.sh:495-554`（python3 `unicodedata` + `cmp -s`，不调渲染器）；V41 §2.1 自建 `probe.py` | 树内 `grep east_asian_width`/`cmp -s`；读 §3.2 断言文本与 V41 的 53 页 × 宽度矩阵 |
| 1.3 | 勾 | 树内 `smoke.sh:19176` FAST 选集含 `locale`；`section-paths.tsv` §51 行含三条既有路径 + `cmd-config.sh`；P278 §6.6 + §3.5（`--select 51` 输出尾 ✓3 ✗0） | 读 `smoke.sh` §51 段与 `section-paths.tsv` §51 行；`sed -n` 核对选集字面量 |
| 1.4 | 勾 | P278 §4 翻转⑨（`✗ locale(zh): 1 个页面随 locale 变：command--dispatch[line 3 differs]`）；V41 §2.3 A1–A3 自造三条变异 + oracle 复核 | 读 §4 与 V41 §2.3 表；树内 `grep flip_case "locale-dependent-width"` |
| 2.1 | 勾（差异，§3.1） | P278 §3.2 四条 ✓；一处声明在 `help-surface.sh:698`；V41 §3.1 自建走查 problems=0 | 树内 `grep local internal`；条目写 `INTERNAL_ENTRIES`、实现叫 `internal` |
| 2.2 | 勾 | P278 §4 翻转⑩（点名 `__probe-x`）与⑪（点名 `__inbox-write`）；V41 §3.2 B2 | 读两条红侧原文；树内 `grep __probe-x`（只出现在夹具变异里） |
| 3.1 | 勾 | P278 §3.2 两条 ✓（菜单分组双向相等、44 命令三级可达）+ §1 行 3.2 finding 文案；V41 §3.1 自建走查 | 读 §3.2 与 V41 §3.1；数了 8 组 / 44 命令 |
| 3.2 | 勾 | P278 §4 翻转⑫（点名 `mark-loaded` + 分组 `versions`）与⑬（点名分组与三条命令）；V41 §3.2 B1/B3 | 读两条红侧原文与还原后的绿 |
| 3.3 | 勾 | 裁定 4 采纳；P278 §4 选段器红侧（两个未知名 rc=2）；§1 行 3.3/7.1；V41 §5 四个未知名 | 现场探针：`--select layout`/`nosuchsection` 都 rc=2；`grep check_layout|check_scale` 无输出 |
| 4.1 | 勾（差异，§3.2） | P278 §6.1（闭集 + 未声明红 + 反向红原文）；`cmd-help.sh:42`；V41 §4 P3a–P3f | 树内读 `TEAM_HELP_PLACEHOLDERS`（6 个）；核对条目列的 8 个与实现差 2 个，P278 §6.1 有依据 |
| 4.2 | 勾 | P278 §3.2 的 G4 守卫 ✓ + §4「G4 的守卫」原文；V41 §4 P3a–P3d | 读两处原文；树内 `grep undeclared` |
| 4.3 | 勾 | P278 §4 翻转⑭；V41 §1b.3（删 `{undo_cmd}` → rc=1 点名） | 读两条红侧原文；树内 `grep placeholder-check-gone` |
| 5.1 | 勾 | P278 §3.3 before/after 原文 + Deliverables（六处改写）；V41 §6（rc=5、点名路径、契约 sha） | 读 §3.3 的 before/after 对照；树内 `grep 不能由命令改` |
| 5.2 | 勾（差异，§3.3） | P278 §3.3 四条行为断言；`config-cli.sh:366-373`；V41 §6 | 树内读 `config-cli.sh` 该段；确认行为 needle 三条在位，另发现 `:371` 那条否定式措辞断言 |
| 5.3 | 勾 | P278 §4 O7 红侧原文（放行 → rc=1 点名 `TEAM_PROJECT` → 还原 rc=0）；树内 `config-cli.sh:392-435` | 读红侧原文；树内读该段代码 |
| 5.4 | 勾（口径差，§3.4） | 裁定 3 采纳；P278 §3.4（decision=RUN、`51 ← …/cmd-config.sh`）+ §6.6（数据列）；V41 §5 | 现场探针：同一命令 rc=0 且输出里有 `51 ←`；报告 keys=19 vs V41 keys=20 |
| 6.1 | 勾 | P278 §3.6（`spec-refs.sh --check` rc=0，111 引用；`validate` rc=0，20 passed）；V41 §8 | 读 §3.6 与 V41 §8 表；本轮自己重跑 `validate`（23 passed，见 §6） |
| 7.1 | 勾（部分证据，§4） | 分支合并提交 `1a1640e0`；冲突处理在合并记录 `docs/team/reviews/P278.md`（并集解 + `section-select.sh --check` ok 8/bad 0/SKIP 1） | 读合并记录；`git log --merges` 核对 `1a1640e0`；报告没有贴 merge 输出 |
| 7.2 | 勾（部分证据，§4） | P278 §2 末 + §4（既有断言与 ①–⑧ 翻转未删）；合并记录「删除行都是本任务的改写」；V41 §7 断言集合对照（106→132 丢 0；365→378 只换一条） | 读两处记录；报告没有贴 `--stat`/删除行清单 |
| 7.3 | 勾 | P278 §3 表（验收命令逐条 rc）+ §3.2–§3.6 + §4；报告本体 `docs/team/reports/P278-verify.md`（`9104550f`，随 `919aef0f` 并入 main）；送达见合并记录与 BOARD 的 P278 行 | 逐条对验收命令与 rc；`git merge-base --is-ancestor` 核对 919aef0f 在 main 上 |

## 3. 与清单原文不一致的实际做法（不改原文，已写成行内注记）

1. **2.1 的变量名**：条目写 `INTERNAL_ENTRIES="__inbox-write __panel-data"`，实现是
   `local internal="__inbox-write __panel-data"`（`help-surface.sh:698`，挨着 `team_internal_labels`）。
   断言一条不少（双向相等、页面不出现、清单不许有 `__` 名），多一条前缀判据。
2. **4.1 的闭集是 6 个，不是条目列的 8 个**：`cmd-help.sh:42` 的 `TEAM_HELP_PLACEHOLDERS` 只有
   `{project} {meeting_ttl} {token} {sub} {cmd} {undo_cmd}`。`{effect}`/`{faces}` 在树里**没有任何替换点**
   （主张句是 bash 侧拼的）；而条目同时要求「声明了而树里不再用的 → 同样红」，把它们声明进去会让这条反向判据
   对这两项无法变绿——条目正文自相矛盾。P278 按证据裁掉并在报告 §6.1 写明；V41 §4 的 P3e 复核了反向判据
   （`{undo_cmd}`），PASS。**遗留**：V41 §10.4 记 `cmd-help.sh:351` 的旧注释仍写着 `{effect} {faces}` 是调用方
   替换的（与闭集矛盾，一行注释，未修；建议下次触碰 `cmd-help.sh` 时顺手改）。
3. **5.2 多了一条否定式措辞断言**：`config-cli.sh:371` 的 `case "$err" in *"只读"*|*"控制台"*) bad …` 会被
   `--all` 与 verify 跑，断言「报错里不许出现这两个词」。任务书要的行为 needle（rc=5、含 `.pi/team/config.sh`、
   契约 sha 未变）已在 `:366-373` 就位；这条**额外**的否定式断言属措辞类，与「措辞不设门禁断言」的口径有出入。
   V41 §10.3 已记成观察、留 PM 裁定，我没有动它。
4. **5.4 的计数口径**：P278 报告写 `keys=19`，V41 在冻结 tip 上实测 `keys=20`（§51 都选中，结论相同）；
   我在当前树上复核同一命令 rc=0、输出里有 `51 ←`。差的是计数口径，不是覆盖（V41 §10.2 另记了 config-cli 的
   ✓144 vs ✓142，同一形状）。
5. **既有翻转 ⑧ 的选集参数变了**（任务书不变量说「既有翻转一条不删」）：`layout` 现在被选段器拒绝（这正是
   裁定 4 要的效果），所以 ⑧ 的选集参数从 `layout,coverage` 改成 `coverage`；它的变异与断言一字未动，
   V41 §7 判定为配套改动、不构成削弱。

## 4. 部分证据（勾了，但某半段的原始输出不在记录里）

- **0.2** — 投影自证在 P278 §3.6 全跑了（validate rc=0 → archive rc=0 → validate rc=0），**但**「逐条核对两条
  MODIFIED 的标题与正文 + 一条 ADDED」这一步的核对记录不在 apply 报告里：投影后的五条要求标题、无重复标题在
  P272 报告 §4 的投影自证里，场景对照（`level-0 menu` 4→6、`declared and probed` 3→4，零丢失）在提案复核里。
  结论可复核，只是分布在别的记录。
- **0.3** — O1 的改动前基线（12 行表、53 页探针、选段器基线）在 P278 §3.1；组计数、`spec-refs` rc、config-cli
  needle 现状在 P272 §2.2/§4。**改动前的 `--all` 与 config-cli 的 ✓/✗ 计数没有记录**（P272 §4 明说 `--all`
  本阶段没跑，apply 报告的 `--all` 数字是改动后的）。缺的是两个对照数字，不是基线动作本身。
- **7.1** — 合并落在分支提交 `1a1640e0`（`Merge branch 'main' into task/P278-help-robustness-apply`），冲突处理
  （`section-paths.tsv` 第 51 行按并集解，解完 `section-select.sh --check` ok 8/bad 0/SKIP 1）记在合并记录
  `docs/team/reviews/P278.md`；**apply 报告没有贴 merge 输出原文**。
- **7.2** — 结论有（P278 §2 末 + §4：既有断言与既有 ①–⑧ 翻转一条没删；合并记录「删除行都是本任务的改写」；
  V41 §7 独立断言集合对照 `help-surface.sh` 106→132 丢失 0、`config-cli.sh` 365→378 只换掉那条措辞断言），
  **但** apply 报告没有贴 `git diff main...HEAD --stat` 与删除行清单本身。

## 5. 继承自 V41 的待处置观察（我没有改判，也没有重开）

V41 §10 的条目**不改**受检产物的判定，其中与这份清单直接相关的四条集中在这里：

1. §10.1 **席位缺陷**（P278 的 apply 与 V41 的 verify 同席位）→ 已排 V45 第三方定点补验；本清单里没有 V45
   的项（本任务按边界不勾 PM/复验项）。
2. §10.2 两个数字在冻结 tip 上复现不出来（`config-cli` ✓144 vs ✓142、`section-select` keys=19 vs 20）→
   我已在 §3.4 按冻结 tip 的读数注记。
3. §10.3 否定式措辞断言 → §3.3 条，等 PM 裁定。
4. §10.4 `cmd-help.sh:351` 的旧注释 → §3.2 条，一行注释，建议顺手改。

另两条不在本清单范围：§10.6 的 `mark-loaded` 幂等 flake（已排 P290）与 §10.7 的 `lang` 组容量行脆弱断言
（既有，另开小任务）；§10.5 就是这份清单本身，本轮处置。

## 6. 验收命令与输出（在本分支树上真跑）

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict | tail -3
✓ spec/watchdog
✓ change/writing-discipline
Totals: 23 passed, 0 failed (23 items)
validate rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: names：名单已配置（<home>/<user>/…/.pi/team/forbidden-names.txt，命中即红）
ledger-ban: root=<home>/<user>/…/.worktrees/dev-bob scope=published files=1616 hits=0 names=ok user=resolved
ledger-ban rc=0

$ git diff --check; echo rc=$?
rc=0
$ git status --short
（空）

$ git merge main   # 交付前按任务书再合一次
Already up to date.        # main 的 tip 2a4db357 就是本分支的起点
```

两条只读现场探针（§2 表里 3.3/5.4 的「我查了哪里」）：

```
$ bash skills/teamsmith/tests/help-surface.sh --select layout ; echo rc=$?
help-surface: 未知的选段 layout（可用：coverage, locale, lang, claims, invariants, route）
rc=2
$ bash skills/teamsmith/tests/help-surface.sh --select nosuchsection ; echo rc=$?
help-surface: 未知的选段 nosuchsection（可用：coverage, locale, lang, claims, invariants, route）
rc=2

$ bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/scripts/lib/cmd-config.sh | grep -n '^51'
51      skills/teamsmith/scripts/lib/cmd-config.sh
rc=0
```

（`validate` 本轮是 **23** passed，比 P278 报告里的 20 多——那是 main 上后续并入的 change，与本清单无关。）

一条口径说明，免得看板误读：`team change status help-robustness` 的 `checklist · 23 项未勾` 读的是**主检出**里
那份 `openspec/changes/help-robustness/tasks.md`（`team_spec_dir_abs` 用 `TEAM_MAIN_ROOT` 解析），本分支上的这一份
已经是 **0 项未勾**（`grep -cE '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\][[:space:]]*'` = 0）。合并/在本分支上跑
复验之前，那条 blocker 会一直显示 23 项——它不是没勾上。

## 7. 未做 / 未测项（如实点名）

- 没有重跑 `help-surface.sh --all` / `--flip`、`routes.sh`、`config-cli.sh`、`smoke.sh` 或任何选段；本报告里的
  绿/红结论一律引用 P278 报告与 V41 记录。
- 没有跑完整门禁；没有跑 `--select locale` / `--flip` 这类耗时夹具。
- 没有动产品/测试/规格/delta；没有勾 PM 与复验的项（本清单里没有这类项——V45 第三方补验与归档都留给 PM）。
- 没有修改条目正文；差异一律以行内注记 + 本报告 §3/§4 呈现，等 PM 裁定。
