# P302 · 按事实勾 `replies-for-the-user-are-published` 的清单（apply 侧 24 项，独立验证 4 项留给 PM）

agent: dev   status: done   time: 2026-10-16T10:10Z
task: P302 · phase: apply · change: `replies-for-the-user-are-published`
branch: `task/P302-replies-checklist`（local 模式：分支留本地，PM 复验后本地合并）
base: `44ef693b`（派单提交）· 清单提交: `40660850`

## 结论（先给答案）

`openspec/changes/replies-for-the-user-are-published/tasks.md` 的 28 项里 **24 项已按事实勾上**
（0.1–0.3、1.1–1.5、2.1–2.6、3.1–3.5、4.1–4.2、5.1–5.3），每项原文**一字未动**，末尾追加
` · P302 按事实勾：<证据>`（提交号 / 报告小节 / 命令与 rc）；**4 项留空**——`## 6 独立验证` 的 6.1–6.4，按任务书
由 PM 勾。**没有一项因为找不到证据而留空**：4.1（裁定点 6）与 4.2（裁定点 7）按各自条目里写明的「未授权则
如实记录/N/A」分支勾上，并附本轮的实测读数。

写集只有两个文件：`openspec/changes/replies-for-the-user-are-published/tasks.md` 与
`docs/team/reports/P302-dev.md`；产品/测试/规格零改动（`git diff --stat main...HEAD` 除这两个文件外为空）。

**一条 PM 必须知道的操作事实**：`team change status` 的清单读数不是读席位工作树，而是读
`TEAM_MAIN_ROOT` 下的那一份（`team_spec_dir_abs()` = `${TEAM_MAIN_ROOT}/openspec`，`common.sh:6055`）。
所以**合并之前**它仍会报「checklist · 28 项未勾」——那是主检出的旧副本，不代表本分支没勾。合并之后它会读到
24 勾 4 未勾（4 项为 6.1–6.4），此时这条 blocker 才对 PM 有意义地收口。

## 本轮实跑（我自己的读数）

| 检查 | 命令 | 结果 | rc |
|---|---|---|---|
| 三处判据 token | `grep -ciF "written for the user"` × 3 面 | 3 / 1 / 3 | 0 |
| 模板示例命令唯一且逐字 | `grep -c 'team reply post'` + `grep -o` | 1，`team reply post --from pm --title '<short title>' --stdin < <file>` | 0 |
| command table 行内落点 | `grep -m1 '^\| Key replies \|' skills/teamsmith/SKILL.md \| grep -oiF 'written for the user'` | `written for the user` | 0 |
| 旧句排除用法（须为 0） | `grep -ricF "publish conclusions, not process narration"` / `"a reply carries conclusions"` × 3 面 | 0 0 0 / 0 0 0 | 0 |
| 内容要求与反向句 | `grep -ricF "play-by-play"` / `"never held back"` × 3 面 | 1 1 2 / 1 1 2 | 0 |
| 语法 | `bash -n skills/teamsmith/tests/key-replies.sh` | 无输出 | 0 |
| 门禁 guide 组（含 ①②③⑤ 变异红侧与还原、示例命令真跑） | `bash skills/teamsmith/tests/key-replies.sh --select guide` | `== P234 key-replies 结果 == ✓24 ✗0 SKIP0` | 0 |
| 两张字符串表 | `node skills/teamsmith/tests/panel-strings.mjs .` | `panel-strings: ok`（键集/占位符/表外无 CJK/契约标签全绿） | 0 |
| 第 5 页在 zh/en 窗格 | `bash skills/teamsmith/tests/key-replies-pty.sh --select pages,language` | `== P234 key-replies-pty 结果 == ✓15 ✗0 SKIP0` | 0 |
| 机器出口只读面 | `bash skills/teamsmith/tests/key-replies-ui.sh --select machine,blocks` | `== P234 key-replies-ui 结果 == ✓18 ✗0 SKIP0` | 0 |
| 选段自检 | `bash skills/teamsmith/tests/section-select.sh --check` | `== 选段自检 == ok 8 bad 0 SKIP 1` | 0 |
| 三处表面的选段缺口 | `bash skills/teamsmith/tests/section-select.sh --paths <三处表面>` | `sections=133` / `keys=26`（**不含 62**） | 0 |
| `spec-refs` 既有红 | `bash skills/teamsmith/tests/spec-refs.sh --check` | `undeclared 1`（`extension-slash/spec.md:47 docs/team/tasks/P1.md`） | 1 |
| 面板产物字节数 | `wc -c skills/teamsmith/scripts/panel/panel.js` | 978302 | 0 |
| 投影自证（/tmp 独立副本，只读导出 `openspec/`） | `openspec archive -y replies-for-the-user-are-published` + `validate --all --strict` | `+ 1 added / ~ 2 modified / - 0 / → 0`；`22 passed, 0 failed` → `21 passed, 0 failed` | 0 |

两条较重的检查（pty / ui）放在一个后台作业（`p302-pty-ui`）里顺序跑，收割：`exit=0`，`PTY_RC=0`、`UI_RC=0`，
两行结果如上表。

投影自证的两条细节（第 0.3 项要求「逐条对照」）：

- **既有场景逐字保留**：被 REPLACE 的两段范围（base 的 137–148 与 165–179 行）里 `#### Scenario:` 行数 = **0**；
  `key-replies/spec.md` 的场景总数 26 → 27，唯一新增的是 ADDED 组里的 `#### Scenario: A surface that loses the
  reader criterion names itself`（base 的 184 行之后）。
- **没有第二个未归档 change 动同一批要求**：`grep -rln "The key-conclusion duty is shipped|Publication does not
  gate the normal answer|The key replies page states what it is" openspec/changes/*/specs/*/spec.md` 只命中本
  change；另外三个未归档 change（`gate-lock-external-deletion`、`seat-interrupt-entry`、`tmux-identity-scope`）
  的 requirement 名字与这两条无关。

## 引用的读数（本轮**没有**重跑）

| 读数 | 在哪儿 |
|---|---|
| `key-replies.sh --all` → `✓210 ✗0 SKIP0` | P301 报告 §5 第 1 行；V54.md §0 第 2 条（独立复跑同读数） |
| `smoke.sh --select 26,28,62` → `✓415 ✗0 SKIP0` | V54.md §0 第 9 条 |
| `smoke.sh` 闭包 39 段 → `✓1356 ✗1`（唯一 ✗ 为段 38-a 既有红，main 逐字复现） | P301 报告 §5 表第 3 行与 §5.1 |
| 面板产物重建并 `cmp` 逐字节一致（978302 字节） | P301 报告 §3.3；V54.md §0 第 9 条 `26-a bundle：沙盒里重建逐字节一致` |
| guide 组改动前后的基线对照（✓18 → ✓24，五条变异） | P301 报告 §0.3 与 §2 |
| 渲染四档宽度 × 双语（160/120/99/59） | P301 报告 §3 |

引用原则：这些是 apply 作者与独立复验席位在**冻结 tip** 上跑过的读数，本任务不重复消耗机器（一次
`key-replies.sh --all` 与一次闭包选段都要排队）；凡引用的行都点名了出处，凡我本轮亲手跑的都在上一节。

## 勾选明细（24 项 → 证据指针）

| 项 | 勾的依据（` · P302 按事实勾：` 已写进 tasks.md 同一项末尾） |
|---|---|
| 0.1 | 提案评审 `ACCEPTED`；裁定点 1–5 已表态、6/7 未表态，逐条确认的摘要见本报告 §裁定点 |
| 0.2 | 改动前基线抄进 P301 报告 §0.3；本轮复核改动后读数（token 3/1/3、keys=26） |
| 0.3 | P301 报告 §0.4 + 本轮 /tmp 独立副本重做（见上表与两条细节） |
| 1.1–1.4 | P301 报告 §1（原文与 grep）；本轮三处 token 计数、示例命令唯一且逐字、SKILL 行内落点 |
| 1.5 | P301 报告 §1.5 的改前/改后三处原文；本轮旧排除用法 0 命中、内容要求与反向句在场。**人读判定项：代理读（已标注）** |
| 2.1 | 三行原文见 P301 报告 §2；本轮 `bash -n` rc=0 |
| 2.2 | 本轮 `--select guide` → ✓24 ✗0 SKIP0 rc=0，三面各一条 ✓ |
| 2.3 | P301 报告 §2 与 Flip evidence 的三条红文案；本轮重跑覆盖 ①②③ 的点名断言与还原绿 |
| 2.4 | P301 报告 §2 与 Flip evidence 的 ⑤ 红文案；本轮重跑 `guide-flip/⑤` 三条断言全 ✓ |
| 2.5 | P301 报告 §2.5 的两条运行输出尾与槽位 0→1；`--select guide` 本轮重跑含这两组；V54 §2 独立真发一条 |
| 2.6 | P301 报告 §2.6 的逐行新增清单；本轮 `git diff --stat main...HEAD` 为空 |
| 3.1 | P301 报告 §3.1 的两表行原文（`zh.ts:415` / `en.ts:417`）；本轮 `panel-strings.mjs` → ok rc=0 |
| 3.2 | 本轮实测 `layout.ts:1389` 的 dim 行紧跟 `:1388`；四形态与「无 hit/无动作」见 P301 报告 §3.2、V54 §3 |
| 3.3 | P301 报告 §3.3 的 build 输出与 `cmp`；V54 §0 第 9 条；本轮 `wc -c` = 978302 |
| 3.4 | 两条断言原文（`key-replies-pty.sh:65` / `:284`）本轮实测；`--select pages,language` 本轮 ✓15 ✗0 |
| 3.5 | 本轮实跑 pty 与 ui 两条命令（✓15 ✗0 / ✓18 ✗0）；V54 §0 第 3/4 条 |
| 4.1 | N/A：PM 未裁「补声明」；本任务写集不含测试面 → 未动；`keys=26` 不含 62、`--check` ok 8 bad 0 |
| 4.2 | 未授权 → 如实记录：本轮 rc=1、`undeclared 1`（唯一一条与本变更无关） |
| 5.1 | P301 报告 §5 的八行验收表 + V54 §0 的九条独立复跑；本轮重跑了其中可低成本复核的若干条 |
| 5.2 | 报告已提交本文件（含本节的「未勾项」与「没验到」两节） |
| 5.3 | P301 的 tip/合并状态见其报告顶部；本轮提交与 `team notify pm` 见本报告 §交付 |

## 未勾项与原因

- **6.1–6.4（独立验证组）留空**：任务书写明这四项由**另一个席位**做、由 PM 勾。V54 已完成同批场景的独立
  复验（判定 PASS，含 16 个破坏/还原例、示例命令真跑、四档宽度双语渲染、产物重建、store/CLI 交叉核对），
  证据在 `docs/team/reviews/V54.md`；是否据此勾 6.1–6.4 是 PM 的判定，本报告不代勾。
- **4.1 不是「找不到证据」而是条件未触发**：条目自身给了两条分支（裁「补声明」→ 动 `section-paths.tsv`；
  裁「不动」→ 写明 N/A 与依据）。实际是**第三种情况：PM 没有表态**（提案复核只逐条认可了判据、两类门禁与
  不变量，未触及裁定点 6/7），而 P302 任务书又明文划定写集只有 tasks.md 与报告、产品/测试/规格一字不动。
  因此本项按 N/A 勾上，依据写在条目末尾：P301 报告 §4.1 与 P257 裁定点 5 的收口归属（提案 §现状复核第 7 条），
  外加上一轮的实测读数（`keys=26`、不含 62）。
- **4.2 同理**：未获授权 → 按条目原文的「未授权则如实记录」勾上，附本轮 rc 与基线对照。

## 本轮没验到的产品行为

- **判「某条回复是不是写给用户的」不可机判**：门禁只证「判据在场上 + 示例命令被真解析器接受」，没有任何
  断言能判一条真实回复该不该发布；规格 `The honest limit` 也是这么写的。
- **PM 是否真的照做无工具可证**：没有工具能证明某个活着的 PM 发布了某条回复、或正文与答复一致。本任务
  更远一层——它只证明**清单被按事实勾过**，不新增对产品的任何验证。
- **本轮没有重跑的检查**（上一节列的引用读数）：`key-replies.sh --all`、`smoke.sh` 闭包选段与
  `--select 26,28,62`、面板产物**重建**（只核了字节数，没有重跑 `bun install` + `build.sh` + `cmp`）。
  这些在 P301/V54 上有读数，但**不是本轮的读数**。
- **主检出在本轮开工后前移了一笔**：`main` 从 `44ef693b` 走到了 `8e771a70`（P288 `6f1ed69d feat(gate): the
  machine lock survives an outside rm -rf, and says so`，44 个文件）。我核对过：P288 对三处指令面的改动是
  `SKILL.md` 的 Diagnostics 行与 `protocol.md` 的 gate-lock 章节，**承载读者判据的段落未被触碰**，`main` 上
  三处 token 计数仍是 3/1/3。但本报告的一切实测读数都取自**本分支树**（基于 `44ef693b`，不含 P288），
  合并后像 `section-select --paths` 的 `keys=26` 这类选段读数可能因 P288 对 `section-paths.tsv` 的 +2 行
  略有变化——按 D196，追主分支不是作者的义务，这个口径提醒留在这里。
- **`team change status` 的清单读数滞后于合并**（见 §结论）：这是工具读 `TEAM_MAIN_ROOT` 的设计，不是本次
  勾选没生效。

## 勾选方式与逐字证明

- 勾选方式：`- [ ] X.Y` → `- [x] X.Y`（21 项双行、3 项单行），**其余原文一字不动**，在每一项的**最后一行
  行尾**追加 ` · P302 按事实勾：…`（追加文字在行内，不新增列表项，`team change checklist` 的行号/标题解析
  不受影响）。
- 逐字证明（本轮实跑）：

```
$ git show HEAD:openspec/changes/replies-for-the-user-are-published/tasks.md > /tmp/p302-old.md
$ sed 's/ · P302 按事实勾：.*$//' openspec/changes/replies-for-the-user-are-published/tasks.md \
    | sed 's/^- \[x\] /- [ ] /' > /tmp/p302-new-norm.md
$ sed 's/^- \[ \] /- [ ] /' /tmp/p302-old.md > /tmp/p302-old-norm.md
$ diff /tmp/p302-old-norm.md /tmp/p302-new-norm.md
（无输出）
VERBATIM: original text identical after removing the appended notes and normalizing checkboxes
$ grep -c '^- \[x\]' openspec/.../tasks.md   → 24
$ grep -c '^- \[ \]' openspec/.../tasks.md   → 4      # 6.1–6.4
$ grep -c 'P302 按事实勾' openspec/.../tasks.md → 24
```

- `git diff --stat`（清单提交）：`1 file changed, 45 insertions(+), 45 deletions(-)`——21 项 =（勾选 + 追加）
  两行改动、3 项单行项合并成一行改动，合计 45 行；没有第三类改动。

## 裁定点（供 0.1 与勾选记录对照）

提案复核 `docs/team/reviews/replies-for-the-user-are-published-proposal.md` 的判定是 **ACCEPTED**（首行），它
逐条认可的是：判据按读者（含五类示例与「any other reply whose reader is the user」）、排除项、兜底「读者判
不下来按写给用户」、自测题、`panel` 那条 ADDED，以及 apply 准入五条。**裁定点 6（§62 选段声明）与裁定点 7
（`spec-refs` 既有红）评审未表态**——这与 P301 报告 §0.1 的记录一致，所以本任务按「未授权」处理这两项
（见 §未勾项与原因）。

## Flip / 守卫证据

本任务**不是 defect-fix**：它没有产品/测试/规格改动，因此任务书里「红色→绿色」的翻转条款不直接适用。等价
的可核验性证据有三条：① 逐字证明（上一节）证明「只勾选、不改文」；② 24/4 的勾选计数与 24 条
`P302 按事实勾` 注释一一对应（同一节）；③ 清单守卫本身是承重的——把任一项改回 `- [ ]`，工作树里的
`grep -c` 计数立刻退回 25 未勾，而 `team change status`（读主检出）不变，这正是 §结论 里那条操作事实。

产品侧的翻转证据（摘 token → 红并点名该面 → 还原 → 绿）在 P301 报告 §2/Flip evidence 与 V54 §1.2；本轮
以 `--select guide` 重跑确认 ①②③⑤ 仍「红并点名 `[written for the user]`」且还原后绿（✓24 ✗0 SKIP0，
`guide-flip/①`–`⑤` 的原始红行见 `/tmp/p302-guide.log`）。

## 验收（任务书三行）

在**清单提交之后、本报告落盘未提交之前**跑（树上除本报告外干净）：

```
$ "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
Totals: 22 passed, 0 failed (22 items)            # rc=0

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file \
    "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=<本 worktree> scope=published files=1702 hits=0 names=ok user=resolved   # rc=0
（第二行原文含绝对路径，账本面禁令不许粘贴家目录 → 按 <本 worktree> 省写，其余逐字）

$ git diff --check && git status --short
（无输出）                                          # rc=0
```

报告提交后复跑一次 `ledger-ban` 覆盖本报告自身（结果见 §交付）。

## 交付

- 提交：`40660850` 清单 24 勾（`docs(openspec): P302 ticks the apply-side checklist by fact (24/28)`）；
  `c7899c76` 本报告（`docs(team): P302 report — the 24 apply-side ticks with their evidence`）。
- 提交后复跑 `ledger-ban`（此时已覆盖本报告）：`files=1703 hits=0 names=ok user=resolved`，rc=0。
- local 模式：**不 push、不合并**，分支留本地等 PM 复验。
- 通知：`team notify pm` 一行（勾选后立刻发）。
