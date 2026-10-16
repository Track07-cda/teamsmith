# P301 · 「写给用户的回复都要发布」apply（三处发出面 + 那一页说明 + 两类门禁断言）

agent: dev   status: done   time: 2026-10-16T07:40Z
branch: `task/P301-replies-for-the-user-are-published-apply`   PR/MR: -（local 模式：分支留本地，PM 复验后本地合并）

phase: apply · change: `replies-for-the-user-are-published` · base: `e2ed6e8d` · **交付 tip: `7dccece9`**
（闭包读数取自 `654ce46a`；其后的 `7dccece9` 只把 main 的一个账本提交并进来——`git diff 654ce46a HEAD -- skills/
openspec/` 为空，产品面逐字节相同，故读数对交付 tip 同样成立。四次 `git merge main`，
`git merge-base --is-ancestor main HEAD` → rc=0）：

| merge | 带进来什么 | 与我的改动的关系 |
|---|---|---|
| `1ea93ce5` | P300 第 3 轮定稿 `9fff51d3`（delta 规格 + panel 决策 5） | 我按新规格改了文案与断言（见 §0.2） |
| `12a92a2b` | 其后 4 个纯账本提交 | 产品面 `b05fcbbe..12a92a2b` **逐字节相同** |
| `654ce46a` | `seat-interrupt-entry` 的真实产品落地（`openspec/specs/boundary` +137、`protocol.md` 的 **135 行 guards 段** +21、`troubleshooting.md`、`commands.tsv`、`help-surface.sh`、`seat-interrupt.sh`） | 落在**不同区段**：我的 §4b 重写在 152 行之后，三处判据 grep 仍是 3/1/3、面板说明行仍在；闭包键集不变（仍 39 键）；`panel.js` 未与该侧冲突，重建核对逐字节一致（见 §5.1 之后） |
| `7dccece9` | `cf2fd007 docs(team): freeze the audience rule and dispatch V54 [skip ci]`（账本） | 产品面差异为空 → 闭包读数不变 |

## 结论（先给答案）

判据已按**读者**落地：三处指令面（PM 提示词模板、协议 §4b、SKILL 命令表）都写「写给用户的回复必须发布」
+ 五类示例（回答／汇报状态与进度／结论或裁定／请用户决策／交付与复验摘要）+ 排除项（巡检、其他席位、别的
项目 PM、工具回执）+ 兜底（判不准按写给用户）+ 自测题「who is this reply written for?」，共享冻结 token
`written for the user`；并按 PM 复核把旧句「只发结论、不发过程」收成**内容要求**（页面收的是实质正文，不是
流水账）并写死**反向句**（没有一条写给用户的回复会因为「读起来像过程」而变得不可发布）——三处都写到了，
旧措辞的排除用法三处 grep 为 0。

第 5 页加了一行 dim 自述，带判据自己的自测题（问题放句首）：zh「「这条回复是写给谁的？」——PM 写给用户的
回复都在这里」/ en `"who is this reply written for?" — replies the PM wrote for the user`；空 store 与降级
读数也带它，页面仍然只读（无 hit 目标、无动作、不加任何读取）。门禁只加两类断言：三处各自的判据 token（删任一
处 → 红并点名**哪一面**）与印出来的示例命令仍被真解析器接受（未知旗标控制臂仍被拒），措辞与语气不设断言。

应用后本树实测：`key-replies.sh --select guide` ✓24 ✗0（含新变异 ⑤：只把 token 换成 `written for a person`
→ 红并点名 [written for the user] → 还原后绿）；`panel-strings.mjs` 绿；面板产物在沙盒里重建**逐字节一致**
（978302 字节，sha256 `6c88684dc8df3549f60207506e7685998e903e8205dc417b593e9c2364d29393`）；
`openspec validate --all --strict` 23/0；`ledger-ban` hits=0 rc=0；`git diff --check` 干净。

**一条需要 PM 裁决的偏差**：任务书验收行里的 `spec-refs.sh --check` 今天在本树 rc=1，唯一一条 undeclared 是
`openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md`（来自 `86c7ada9` 的归档），与本变更无关、与
提案基线逐字相同；提案裁定点 7 把它划在 PM 的地盘（`openspec/specs/**` 与 `tests/spec-ledger-refs.tsv` 都不在
本任务写集里），任务书 4.2 要求「未授权则如实记录」——本任务**未获授权**，故未动，详见 §4.2 与 §7。

## 0 基线与指令

### 0.1 提案复核（任务书 0.1）

`docs/team/reviews/replies-for-the-user-are-published-proposal.md` 判定 **ACCEPTED**：判据按读者、五类示例与
「any other reply whose reader is the user」、排除项与「工具回执根本不是回复」、兜底「读者判不下来按写给用户」、
自测题、以及 `panel` 那条 ADDED 都在；apply 准入五条（三处按新判据且不留旧措辞残留、门禁只加两类、不变量、
验收、独立复验）即本任务的验收面。裁定点 1–5 与提案推荐一致（2 MODIFIED + 1 ADDED；token
`written for the user`；文案；位置；兜底句），**裁定点 6（§62 选段声明）与 7（`spec-refs` 既有红）评审未表态**，
遂按任务书 4.1/4.2 的「未授权则不动/如实记录」处理（见 §4）。

### 0.2 PM 的 main 合并（2026-10-16T06:32:19Z）

PM 在派单后把 P300 的第 3 个 tip 并进 main（`9fff51d3`「the publishing rule keeps its teeth」），并要求
「P301 以 main 为准，若从旧 main 起手 `git merge main` 一次」。已执行（`1ea93ce5`），带来的**实质变化**两条：

1. delta 规格补了内容要求与反向句（「a reply written for the user is never held back because of what kind of
   reply it is … no reply becomes unpublishable by reading like process rather than like a conclusion」），
   tasks 1.5 从「旧说法 0 命中」改成「保留内容要求、但不得保留把『只记录流程』当不发布理由的句子」；
2. panel 那条 ADDED 要求那一行**带上判据的自测题**，且问题放句首（59 列截断时问题与「谁发布」都还在），
   tasks 3.1/3.4 随之更新（文案改为 `design.md` 决策 5 的新推荐两句；pty 断言串改用问题那一段）。

两条都已在本报告的这一版里落实（见 §1 与 §3）；P300 提案文本之外没有别的文件变化（`git diff --stat e2ed6e8d..main`
只有 `openspec/changes/replies-for-the-user-are-published/**`、评审记录与账本）。

### 0.3 改动前基线（任务书 0.2）

```
$ for f in skills/teamsmith/templates/pm-prompt.md.tmpl skills/teamsmith/references/protocol.md skills/teamsmith/SKILL.md; do grep -ciF "written for the user" "$f"; done
0
0
0
$ grep -ricF "publish conclusions, not process narration" <三处>                # 模板 1、协议 0、SKILL 0
$ grep -ricF "a reply carries conclusions rather than process narration" <三处> # 协议 1
$ grep -ricF "a reply carries conclusions, not process narration" <三处>        # SKILL 1
$ grep -c replyPageNote skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts
skills/teamsmith/scripts/panel/src/strings/zh.ts:0
skills/teamsmith/scripts/panel/src/strings/en.ts:0
$ bash skills/teamsmith/tests/key-replies.sh --select guide   → ✓18 ✗0 SKIP0
$ node skills/teamsmith/tests/panel-strings.mjs .             → panel-strings: ok
$ bash skills/teamsmith/tests/section-select.sh --paths <三处表面>
sections=133
keys=26                                  # 不含 62（提案的已知缺口）
```

改动前 `guide_spec()` 三行锚点原文（`tests/key-replies.sh`）：

```
"prompt template")    printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post' ;;
"protocol reference") printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post;No tool can verify' ;;
"command table")      printf '%s' 'milestone;ruling;ask the user;row:conclusion;row:say;row:notify;row:--stdin;row:team reply post' ;;
```

### 0.4 独立树投影自证（任务书 0.3）

```
$ cp -a openspec /tmp/p301/proj/openspec && (cd /tmp/p301/proj && bun openspec validate --all --strict)
Totals: 23 passed, 0 failed (23 items)
$ … openspec archive -y replies-for-the-user-are-published
Applying changes to openspec/specs/panel/spec.md:
  + 1 added
Totals: + 1, ~ 2, - 0, → 0
Change 'replies-for-the-user-are-published' archived as '2026-10-16-replies-for-the-user-are-published'.
$ … validate --all --strict
Totals: 22 passed, 0 failed (22 items)
```

归档投影把 2 条 MODIFIED 落进 `openspec/specs/key-replies/spec.md`（既有场景逐字保留：第一条 1→1、第二条
3→4）、1 条 ADDED 落进 `openspec/specs/panel/spec.md`；`openspec/changes/` 下没有第二个动 `key-replies` 或
`panel` 的同一批要求的未归档 change（`ls openspec/changes/`：`archive`、`gate-lock-external-deletion`、
`replies-for-the-user-are-published`、`seat-interrupt-entry`、`tmux-identity-scope`，后三者不涉及这两条要求）。

## Deliverables

| Path | What |
|---|---|
| `skills/teamsmith/templates/pm-prompt.md.tmpl` | 一段整体改写：按读者判 + 五类示例 + 排除项 + 兜底 + 自测题 + 内容要求（实质正文而非流水账）与反向句；示例命令仍是全模板唯一一行且逐字未动 |
| `skills/teamsmith/references/protocol.md` §4b | 常设义务那句改成按读者；代码块后新增边界段（读者决定 / 不算的几类 / 长度不决定 / 反向句 / 判不准怎么办）；机制、回执含义、「发布不阻断答复」、只读读取原样；诚实边界补「某条回复是不是写给用户的」也不可机判 |
| `skills/teamsmith/SKILL.md` | `\| Key replies \|` 行与 Non-negotiable bullet 同步改成同一判据 + 内容要求与反向句（两处都在） |
| `skills/teamsmith/tests/key-replies.sh` | `guide_spec()` 三行各加 token（command table 用 `row:` 前缀，token 落在行内）；红文案改成「缺了什么，不是要求某个措辞」；新变异 ⑤（只换 token 的同义改写）；①②③⑤ 各加「红文案必须点名 `[written for the user]`」断言 |
| `skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts` | 各加 `replyPageNote`（zh「「这条回复是写给谁的？」——PM 写给用户的回复都在这里」/ en `"who is this reply written for?" — replies the PM wrote for the user`） |
| `skills/teamsmith/scripts/panel/src/layout.ts` | 第 5 页导航行之后紧跟一行 dim 说明（`truncLine(ln(seg(... 'dim')), innerW)`），所有分支（空 store、降级、坏 store、有条目）都带它 |
| `skills/teamsmith/scripts/panel/panel.js` | 用钉住工具链重建的提交产物（978302 字节） |
| `skills/teamsmith/tests/key-replies-pty.sh` | `pages` 组加一条 `assert_has` 断言自测题那一段在真窗格里；`language` 组把 en 的自测题并进 `want_frame` |

未动：`team reply` 的 CLI/存储/退出码/编号/并发；面板只读性质与读取集合；`tests/section-paths.tsv`（裁定点 6
未获授权，见 §4.1）；`openspec/specs/**` 与 `tests/spec-ledger-refs.tsv`（裁定点 7 未获授权，见 §4.2）；
worker 提示词；`team say`/`notify`。

## 1 三处发出面（任务书 1.1–1.5）

改动后实测：

```
$ for f in <三处>; do grep -ciF "written for the user" "$f"; done
skills/teamsmith/templates/pm-prompt.md.tmpl: 3
skills/teamsmith/references/protocol.md: 1
skills/teamsmith/SKILL.md: 3
$ grep -ricF "publish conclusions, not process narration" <三处>   → 0 0 0
$ grep -ricF "a reply carries conclusions" <三处>                  → 0 0 0
$ grep -c 'team reply post' skills/teamsmith/templates/pm-prompt.md.tmpl
1
$ grep -o 'team reply post[^`]*' skills/teamsmith/templates/pm-prompt.md.tmpl
team reply post --from pm --title '<short title>' --stdin < <file>
$ grep -m1 '^| Key replies |' skills/teamsmith/SKILL.md | grep -oiF 'written for the user'
written for the user                    # 判据落在行内，不只在 bullet
$ grep -ricF "play-by-play" <三处>      → 1 1 2      # 内容要求（实质正文，不是流水账）
$ grep -ricF "never held back" <三处>   → 1 1 2      # 反向句（不因「像过程」而不发布；三处同一句措辞）
```

- 1.1 模板：一段内写成「Replies written for the user go to the reply page first」，五类示例 + 排除项 + 兜底 +
  `who is this reply written for?` + 「no reply is held back because it reads like process rather than like a
  conclusion」与「the substance the user needs to read, not a play-by-play of the work」；示例命令保持全模板唯一
  一行且逐字未动（上面两条 grep）。
- 1.2 协议 §4b：常设义务那句改成按读者（`The reader decides what is published`），**complete reply** 的定义从
  「whole answer, not a summary」改成「the substance the user needs to read, not a play-by-play of the work」；
  代码块后新增边界段（自测题 + 排除项 + 长度不决定 + 反向句 + 兜底）；「发布不阻断答复」、回执含义、只读读取
  原样保留；诚实边界仍以 `No tool can verify` 开头，补上「某条回复是不是写给用户的」同样不可机判。
- 1.3 SKILL：command table 行与 Non-negotiable bullet 都改成同一判据 + 内容要求与反向句（`say`/`notify` 的
  内部通道区分保留）。
- 1.4 token 命中与行内落点：上面 4 条 grep（三处 token 命中；SKILL 行内命中）。
- 1.5 与旧句的关系（PM 复核裁法，逐处改前/改后）：
  | 面 | 改前（原文） | 改后（原文） |
  |---|---|---|
  | 模板 | `A batch of conclusions may be one reply; publish conclusions, not process narration.` | `…and no reply is held back because it reads like process rather than like a conclusion. Publish the complete reply -- the substance the user needs to read, not a play-by-play of the work -- with …` |
  | 协议 §4b | `A batch of conclusions may be one reply, and a reply carries conclusions rather than process narration.` | `A reply is never held back because of its kind: a status or progress report, a delivery summary and a decision request are published exactly as a conclusion is, and reading like process never makes a reply unpublishable.` |
  | SKILL（行 + bullet） | `a reply carries conclusions, not process narration` | `never held back because it reads like process rather than like a conclusion` + `the substance the user needs to read, not a play-by-play` |

  三处的反向句用**同一句措辞**（`a reply is never held back because it reads like process rather than like a
  conclusion`），这是刻意对齐：同一纪律在三面可读成同一句话（token 仍然只有 `written for the user` 进断言）。

  三处的旧排除用法 0 命中、内容要求与反向句都在（上面两条 grep）——「只记录流程就不发布」这类句子已不存在。

## 2 门禁（任务书 2.1–2.6）

`guide_spec()` 三行（改动后）：

```
"prompt template")    printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post;written for the user' ;;
"protocol reference") printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post;No tool can verify;written for the user' ;;
"command table")      printf '%s' 'milestone;ruling;ask the user;row:conclusion;row:say;row:notify;row:--stdin;row:team reply post;row:written for the user' ;;
```

`bash -n skills/teamsmith/tests/key-replies.sh` 通过；`--select guide` 应用后 **✓24 ✗0 SKIP0**（基线 ✓18 ✗0，
新增 6 条：①②③⑤ 各自「红文案点名缺失的判据」+ ⑤ 的红/还原两条；合并 main 与内容要求改写之后重跑仍是 ✓24 ✗0）。
红文案原文（真树实测）：

```
✗ guide-surfaces：prompt template 丢了纪律判据： [ruling] [ask the user] [--stdin] [team reply post] [written for the user]
✗ guide-surfaces：protocol reference 丢了纪律判据： [ruling] [ask the user] [written for the user]
✗ guide-surfaces：command table 丢了纪律判据： [conclusion]（Key replies 行内） … [written for the user]（Key replies 行内）
✗ guide-surfaces：prompt template 丢了纪律判据： [written for the user]     # 变异 ⑤：只把 token 换成 written for a person
```

- 2.2 真树三面全绿（上面三行 ✓）。
- 2.3 ①②③ 的红文案都点名 `[written for the user]`（三处各自承重）——由新断言逐个断言，不是肉眼看。
- 2.4 新变异 ⑤ 与 ①–④ 同形状（复制真树 → perl 只换 token → 断言红并点名 → 重新复制 → 断言绿），
  「变异没应用上」单独报红；⑤ 的红**只**列 `[written for the user]` 一条，说明这个 token 单独承重。
- 2.5 `guide-example` 原样保留并真跑：接受臂 rc=0、`outcome=saved`、槽位 0→1；控制臂（+`--frobnicate-probe`）
  rc=2、诊断含「未知参数」、槽位不变。
- 2.2/2.3 重跑：三处反向句措辞对齐（`0b236e28`）之后 `--select guide` 仍是 **✓24 ✗0 SKIP0**（token 与变异断言
  都不依赖那句措辞）。
- 2.6 组内没有新增任何措辞/语气/句子形状断言：`git diff main...HEAD -- skills/teamsmith/tests/key-replies.sh`
  的新增行只有 token、变异 ⑤、红文案点名断言与红文案措辞，逐行如下（`+` 行，已去掉注释行）：

  ```
  +    "prompt template")    printf '%s' '…;--stdin;team reply post;written for the user' ;;
  +    "protocol reference") printf '%s' '…;No tool can verify;written for the user' ;;
  +    "command table")      printf '%s' '…;row:team reply post;row:written for the user' ;;
  +    bad "guide-surfaces：$name 丢了纪律判据：$miss —— 这里判的是这个面缺了什么，不是要求某个措辞；…"
  +  guide_flip_names_criterion() { … if grep -qF -- '[written for the user]' "$text"; then ok … else bad …; fi }
  +  guide_flip_names_criterion "①" "$out"      # ② ③ 同形
  +  # ⑤ 模板：只把判据 token 换成另一种说法（句子仍通顺）→ 红并点名 prompt template 与缺失的判据
  +  perl -pi -e 's/written for the user/written for a person/g' "$mut"
  +  out="$(guide_check_surface "prompt template" "$mut" 2>&1)"; rc=$?
  +  guide_flip_red "⑤" "prompt template" "$rc" "$out"
  +  guide_flip_names_criterion "⑤" "$out"
  +  cp -f "$TMPL" "$mut"; … 还原后绿断言（guide-flip-5-restore-green.txt）
  ```

  组内没有任何断言要求某一句话/某个语气/某种句形（`guide_check_surface` 只做 token 在场与「哪个面缺了什么」）。

## 3 面板第 5 页（任务书 3.1–3.5）

- 3.1 `replyPageNote` 两表各一，**问题放句首**：zh「「这条回复是写给谁的？」——PM 写给用户的回复都在这里」/
  en `"who is this reply written for?" — replies the PM wrote for the user`；`panel-strings.mjs` 绿（占位符一致、
  表外无 CJK、契约键与分组标签双向一致、fixture 标记仍是数据）。
- 3.2 `layout.ts` 的 `lines` 首元素仍是 `replyNavLine`，紧跟一行
  `{ line: truncLine(ln(seg(` ${s.replyPageNote}`, 'dim')), innerW) }`；早退分支（无数据/降级、空 store）都
  在这行之后 push，因此四种形态（有数据、空 store、降级、坏 store）都带着说明行；无 hit 目标、无动作。
- 3.3 重建与对拍：`( cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile && bash build.sh )`
  → `panel.js written (978302 bytes, sha256 6c88684dc8df3549f60207506e7685998e903e8205dc417b593e9c2364d29393)`；
  在 `/tmp/p301/sandbox` 重新拷贝 `{package.json,bun.lock,tsconfig.json,build.sh,src}` 并重建 →
  `cmp: byte-identical`（两次独立安装后的产物逐字节相同，与 §26-a 的判据同形）。
- 3.4 `key-replies-pty.sh`：`pages` 组加
  `assert_has "$tmp/$current/list5.txt" "「这条回复是写给谁的？」" "pages：第 5 页说明行带着判据的自测题（删整行或只删自测题都会红）"`；
  `language` 组的 en `want_frame` 加 needle `'"who is this reply written for?"'`——两条都取**冻结文案里问题那一段**，
  删整行与只删自测题都会红。
- 3.5 只读与诚实边界未被削弱：`key-replies-ui.sh --select machine,blocks,snapshots` 与
  `key-replies-pty.sh --select pages,language` 全绿（输出见 §5）。

渲染实测（`node skills/teamsmith/scripts/panel/panel.js --root . --snapshot --page 5 --width W --lang L`，
160/120/99/59 共 8 帧）：

```
w=160 zh: 「这条回复是写给谁的？」——PM 写给用户的回复都在这里
w=160 en: "who is this reply written for?" — replies the PM wrote for the user
w=120 zh/en: 同上（整行）
w=99  zh/en: 同上（整行）
w=59  zh: 「这条回复是写给谁的？」——PM 写给用户的回复都在这里     # 整行仍可见（54 列 ≤ 内宽 55）
w=59  en: "who is this reply written for?" — replies the PM wro…  # 截断，但问题与「the PM」都在
```

## 3b 一条环境性红灯（发现 + 处置）

第一次 `key-replies.sh --all` 是 **✓208 ✗2**，三条断言落在 `skip-path` 组（两次跑分别是 2 条与 3 条，症状随截断
长度变），红文案原文：

```
✗ skip-path：子进程没跑完整轮（末行=[cp: error writing '/tmp/teamsmith-key-replies.qawdZK/flip/readonly_mkdir/skills/teamsmith/scripts/panel/node_modules/es-toolkit/dist/server/colors/b]，rc=1，子进程日志长度=8192）
✗ skip-path：flip/full_scan 也点名跳过：文本里没有 [flip/full_scan：观测器缺席]
✗ skip-path：可见跳过只有 2 条
```

根因不是本变更，而是**我自己的构建残留**：`bun install --frozen-lockfile` 在 `skills/teamsmith/scripts/panel/`
留下了 41 MB 的 `node_modules/`（被 `scripts/panel/.gitignore` 忽略，未进任何提交），而 `skip-path` 夹具把整个
skill 树 `cp -a` 进 `/tmp`（当时 `/tmp` 已用到 89%／15 G tmpfs，全机器共享：4085 个顶层条目、12 G），拷贝中途
写失败 → 子进程那一轮被截断 → 三条断言连锁红。

处置：`rm -rf skills/teamsmith/scripts/panel/node_modules`（顺带清掉我自己在 `/tmp/p301` 下的 79 MB 中间产物），
重跑 **`bash skills/teamsmith/tests/key-replies.sh --select skip-path` → ✓8 ✗0，rc=0**，子进程完整轮自己也报
`✓20 ✗0 SKIP3`。这也正是 `smoke.sh` §26-a 的既有要求（拷贝里不许有 `node_modules`），本树现在满足它；
**`node_modules` 不进提交，也不留在交付树里**（重建证据见 §3.3，沙盒重建用的是 `/tmp` 下的独立拷贝）。

> 给 PM 的旁注：`/tmp` 在跑门禁时接近满（89%），这不是本任务能修的共享资源；本次只清了自己的残留，
> 别的席位/历史任务的目录（`/tmp/dev3-flip`、`/tmp/p249*` 等）没有动。

## 4 裁定点（任务书 4.1–4.2）

### 4.1 裁定点 6（§62 选段声明）：N/A——未获授权

PM 的提案评审只逐条认可了判据、无残留旧措辞、两类门禁与不变量，未对裁定点 6 表态；任务书 4.1 要求「仅当 PM
裁『补声明』」才动 `section-paths.tsv`。故第 153 行（段 62）未动。实测旁证：只改这三处表面时
`section-select.sh --paths` 选中 26 个 key 且不含 62（提案的读数一致），但本变更同时改了
`tests/key-replies.sh`（段 62 的 patterns 之一），所以**本变更的闭包选段里 62 在场上**（见 §5 的 `--select`
列表）——缺口对本次 apply 不构成实际盲区。

### 4.2 裁定点 7（`spec-refs` 既有红）：未获授权 → 如实记录

```
$ bash skills/teamsmith/tests/spec-refs.sh --check
undeclared openspec/specs/extension-slash/spec.md:47 docs/team/tasks/P1.md
spec-refs: judged 112 reference(s) (50 distinct) in 12663 effective line(s); retired 0; undeclared 1; id families used [D,E,F,M,P,V] named [D,E,F,M,P,V]
rc=1
```

基线对照：提案 §现状复核第 6 条记录的正是这一条（`undeclared 1`、rc=1，与本变更无关，来自 `86c7ada9`）；
本变更没有新增任何 `docs/team/tasks/<ID>.md` 形状的引用，也没有引入新的 undeclared（`--check` 前后同一行）。
任务书 4.2 与提案裁定点 7 都把它划在 PM 的地盘（`openspec/specs/**` 与 `tests/spec-ledger-refs.tsv` 不在本
任务写集），**未授权 → 未修**。

**需要 PM 注意的偏差**：PM 的提案复核第 4 条写「`validate`、`spec-refs`、`ledger-ban`、`git diff --check`
全绿」，而 `spec-refs` 在今天的 main/本分支上本来就是 rc=1（上面的基线对照可复现）。修复要在 PM 的地盘动
`openspec/specs/extension-slash/spec.md:47` 或 `tests/spec-ledger-refs.tsv`（两条修法见提案裁定点 7），请 PM
裁决是另立小任务、授权给 verify 席位，还是接受「既有红 + 基线对照」作为本次的验收口径。

## 5 验收命令（任务书 Acceptance 逐条）

全部在交付树上跑（**闭包读数取自 `654ce46a`**；交付 tip `7dccece9` 与它的产品面逐字节相同，`git status` 干净）。**第一次闭包运行（07:02 起跑那次）的
读数一律作废**——PM 2026-10-16T07:33:56Z 通知：另一个席位用项目级通配清理临时根时命中了它（pid 2086606），
现场被抽走。下表是**合并后的树上重跑的**读数（A/B 两项；C–F 四项每次运行都重跑）。

| # | 任务书验收行 | 实测 |
|---|---|---|
| 1 | `bash skills/teamsmith/tests/key-replies.sh --all` | **rc=0，✓210 ✗0 SKIP0**（十二组 + guide） |
| 2 | `bash skills/teamsmith/tests/section-select.sh --paths <9 条改动路径>` | rc=0，`decision=RUN`、`sections=133`、`keys=39` |
| 3 | `bash skills/teamsmith/tests/smoke.sh --select 0,0b,0c,0d,2,4,5,3b,6,6d,6e,6f,6i,7b,11f,11h,14b,15b,15c,13c,12b-h0d,17,18,18b,19,26,27,28,32,33,12f,12k,38,40,49,52,57,62,63`（步骤 2 的 39 键，逐字） | rc=1，**增量 ✓1356 ✗1 SKIP10**；唯一 ✗ 是段 38-a（**既有红**，main 上逐字复现，§5.1）。段 26 这一轮全绿（✓143 ✗0，用时 105s）——前两轮它在 `26-m tick` 上红，已定性为负载类（§5.2） |
| 4 | `git diff --check` | rc=0（无输出） |
| 5 | `bun openspec validate --all --strict`（在树根） | `Totals: 22 passed, 0 failed (22 items)`，rc=0（总数从 23 变 22 是因为 main 把 `seat-interrupt-entry` 归档为正式规格，见顶部 merge 表） |
| 6 | `bash skills/teamsmith/tests/spec-refs.sh --check` | rc=1，`undeclared 1`（`extension-slash:47 docs/team/tasks/P1.md`，**既有红**，见 §4.2） |
| 7 | `bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"` | `hits=0 names=ok user=resolved`，rc=0 |
| 8 | `git status --short` | 空（报告提交之后） |

选段里与本变更直接相关的段（`--select` 的原始输出，行首为段号）：

```
#26 26 · 面板（pulse-tui-panel：模式 / 布局降级 / 净化 / 队列 / 运行时 / 隔离） · 用时 105s · ✓143 ✗0 SKIP0
#27 27 · 面板异步数据层（pulse-console B1：块协议 / 块隔离 / 快速读者等价 / 装配时间） · 用时 17s · ✓21 ✗0 SKIP0
#28 28 · 控制台表面（pulse-console B3：i18n 键集合 / 调色板对比度 / 四档快照 / refresh_s / panel.conf 边界） · 用时 46s · ✓167 ✗0 SKIP0
#30 33 · 项目契约的读写面（P22/B1：team config 单一写入口 + schema） · 用时 130s · ✓1 ✗0 SKIP0
#33 38 · 设置选项（M55：choices 读 / 一致性走查 / 选择器夹具） · 用时 294s · ✓21 ✗1 SKIP0   ← 既有红 38-a（§5.1）
#38 62 · 关键回复存储与 CLI（change: pulse-key-replies · P234） · 用时 131s · ✓1 ✗0 SKIP0
#39 63 · 关键回复面板第 5 页（change: pulse-key-replies · P234） · 用时 461s · ✓2 ✗0 SKIP0
  ⚠ #39 用时 461s，超过实测带 324s（这是记录，不是判定）
  ✓ 62 key-replies 真 pty 面九组全绿（80 条断言，1 条可见跳过）
  ✓ 名册为空不再以 ✗ 出现
账本自查： 39 段收口 · 增量 ✓1356 ✗1 SKIP10 ｜ 结果行 ✓1356 ✗1 —— 一致
== 选段结果 ==  ✓ 1356  ✗ 1
```

**合并后的产物核对**（合并可能把两边的 `panel.js` 混成「不是任何一棵 src 的构建」，所以单独查一次）：
在 `/tmp` 沙盒里拷贝 `{package.json,bun.lock,tsconfig.json,build.sh,src}` 重建 → `panel.js written (978302 bytes,
sha256 6c88684dc8df3549f60207506e7685998e903e8205dc417b593e9c2364d29393)`，与本树提交的产物 `cmp` **逐字节一致**；
合并后的源码里我的第 5 页说明行仍在（`layout.ts:1389`）。

**这次没跑的段**（smoke 要求报告点名，94 个键，原文照抄）：

```
0e 0f 0g 0h 0i 1 1b 1c 3 4b 4c 6b 6c 6g 6h 6j 6k 7 8 9 10 10b 10c 11 11b 11b2 11b3 11b4 11c 11d 11e 11e2 11g 11i 11j 12 13 13b 12b 12b-h0 12b-h0b 12b-h0c 12b-pi 12b-pi2 12b-pi3 14 14c 54 14d 18c 20 21 22 23 24 25 29 30 31 31c 12e 12g 12h 12i 12j 34 34b 35 36 37 39 41 42 43 44 45 46 47 48 50 51 51b 51c 53 58 15 55 56 59 60 61 61b 64 65
```

### 5.1 段 38-a 的既有红（发现 + 反例证明：不是本变更引入）

```
$ cd /tmp/p301/maintree            # git archive main | tar -x（只读导出，无我的任何改动）
$ bash skills/teamsmith/tests/panel-choices.sh flip-drop-pm flip-suggest
    ✗ 找不到可安装的扩展源（/tmp/teamsmith-panel-choice.ofrrCu/flip-drop-pm/skills/teamsmith/extension/team.ts 不在）
  ✗ F-D：红侧没有点名 TEAM_PULSE_INTERVAL / 30
  ✗ F-D：恢复后走查仍红（rc=3）
    ✗ 找不到可安装的扩展源（/tmp/teamsmith-panel-choice.ofrrCu/flip-suggest/skills/teamsmith/extension/team.ts 不在）
== 结果 ==  ✓ 3  ✗ 2        MAIN_38A_RC=1

$ cd <本 worktree> && bash skills/teamsmith/tests/panel-choices.sh flip-drop-pm flip-suggest
  （同两条 ✗，同一句「找不到可安装的扩展源」，仅临时根名不同）
== 结果 ==  ✓ 3  ✗ 2        BRANCH_38A_RC=1
```

时序与原因：`panel-choices.sh` 的两个翻转树只拷 `scripts/`、`templates/`、`references/`（:515-516、:553-554），而
`team init` 现在会安装 `/team` 扩展，安装源是 `$TEAM_SKILL_DIR/extension/team.ts`（`cmd-init.sh:161-165`）——
扩展落地之后翻转树里没有 `extension/`，于是 `team init` 报「找不到可安装的扩展源」，走查在红侧拿不到
`TEAM_PULSE_INTERVAL / 30`、恢复后也回不到绿。`panel-choices.sh` 与 `cmd-init.sh` 在本分支与 main **逐字节相同**
（`git diff --stat main...HEAD -- skills/teamsmith/tests/panel-choices.sh skills/teamsmith/scripts/lib/cmd-init.sh`
为空），所以这是 main 上的既有红。

**未修**（+ 一条给 PM 的候选修法，未执行）：不在本任务写集（`panel-choices.sh` 属设置/choices 面，`extension/`
属扩展面），也与本变更无关；按协议「发现别的 bug → notify PM + 报告」处理。一行候选：
`cp -a "$skill/extension" "$ft/skills/teamsmith/"` 加进两个翻转树的拷贝清单（或在那两处 `new_proj` 用
`--no-skills`）。

### 5.2 段 26 的 `26-m tick`：**负载类**，不是本变更的真红（PM 要求归因）

失败断言原文（两次闭包运行都在这一条，`capacity 行=1`）：

```
✗ 26-m tick：等满 10s 也没按周期 tick（capacity 行=1）
```

按 PM 2026-10-16T07:30:51Z 的追问（D194 版本漂移 / D192 负载 / 真红），证据如下，结论是 **D192 负载类**：

**① 机制**：这条断言在夹具里起一个真面板（`team monitor --interval 1`，`TEAM_PULSE_INTERVAL=2`），等
`capacity.log` 长出 **≥2 行**（10s 预算）。写这行的是巡检本身——`team_watch_once` 的**拍首**就落
`capacity.log`（`cmd-watch.sh:551`），而每拍要做一次全量扫描（`team_scan_warm --reports` 等）。面板从起窗到第一帧要 5–9s（见下表），
也就是说「起窗 + 首帧」这一段就吃掉了 10s 预算的一半以上，机器一慢第二拍就落不进窗口。
本变更改的是 `layout.ts` 第 5 页的一行说明 + 两张词表 + 重建的
`panel.js`，**没有一行落在巡检路径上**（`git diff main...HEAD --name-only` 的 9 个路径里没有 `cmd-watch.sh`）。

**② 同树非确定性**（同一 tip、同一命令）：

| 场景 | 面板首帧 | `26-m tick` |
|---|---|---|
| 独立 `--select 26` ×4（b05fcbbe，load 17.9–21.0） | 5682 / 5404 / 5944 / 5939 ms | ✓ ✓ ✓ ✓ |
| 独立 `--select 26` ×2（load 23.5–25.9） | 6738 / 6764 ms | ✓ / **✗** |
| 两次闭包 39 段（load ~26；tip `b05fcbbe` / `12a92a2b`） | 9252 ms | **✗**（两次都红） |
| 第三次闭包 39 段（tip `654ce46a`，段 26 用时 105s，机器较闲） | —（未打印，段用时 105s vs 前两次 112s/121s） | ✓（✓143 ✗0） |

**③ 同条件对照 main**（`git clone --shared --branch main`，只读克隆）：

| 场景 | 面板首帧 | `26-m tick` |
|---|---|---|
| 独立 `--select 26` ×2（load 22.2 / 24.7） | 6742 / 5677 ms | ✓ ✓ |
| AB 交替各 4 次（load 13.3–22.0） | 我 5682/5404/5944/5939 ms，main 5402/5434/6202/5400 ms | 8/8 ✓（两棵树失败率都 0） |

**④ 加压复现（把两棵树一起推进「慢启动」区）**：各加 24 个 CPU 忙循环后跑 `--select 26`——**两棵树都红**，且
main 红得更多：我 `✓197 ✗5`，main `✓195 ✗7`（忙循环用 `timeout 400` 自灭，跑完核对残留 0 个）。也就是说这段
的红随机器速度走，不随哪棵树走；负载退去后两棵树都是 `✓202 ✗0`。

**⑤ 负载的来源说清楚**：运行时 `ps` 看到的 CPU 占用来自**同机其他仓库**的测试进程、多个 `pi` 会话与其中
一个项目自己的面板读取，不是本任务的进程；本任务跑闭包时段 63 也从 378s 涨到 498s（实测带 324s），同一现象。

**给 PM 的候选修法（未执行，不在本任务写集）**：这条断言和其他 `26-m` 断言一样该「等面板出帧再计时」——先用
`p10_wait_pane`（该段已有，用于「真 pane」那几条）拿到首帧，再开始数 `capacity.log` 的拍数；或把 10s 预算按
`p10_wait_ms()` 实测的首帧延迟顺延。现在它把面板启动时间算进了「2 拍」的账里，机器一慢就红。

## Flip evidence（红 → 绿）

本任务不是修缺陷，但任务书要求有翻转证据；门禁的新断言本身就是红侧，实测如下（真树，逐条跑）：

```
# 红 ①：删掉模板里持有 "Key conclusions" 的整段
✗ guide-surfaces：prompt template 丢了纪律判据： [ruling] [ask the user] [--stdin] [team reply post] [written for the user]
# 还原（重新从真树复制）→ ✓

# 红 ②：删掉协议的 "standing duty of the PM" 段
✗ guide-surfaces：protocol reference 丢了纪律判据： [ruling] [ask the user] [written for the user]
# 还原 → ✓

# 红 ③：把 `| Key replies |` 行换成不含锚点的行
✗ guide-surfaces：command table 丢了纪律判据： [conclusion]（Key replies 行内） … [written for the user]（Key replies 行内）
# 还原 → ✓

# 红 ⑤：只把模板里的 token 换成 written for a person（句子仍通顺）
✗ guide-surfaces：prompt template 丢了纪律判据： [written for the user]
# 还原 → ✓

# 红 ④（示例命令）：示例行的 --stdin 改成 --stdinX
✗ guide-example：example command 被真解析器拒绝（rc=2，输出 [reply: 未知参数 --stdinX]）
# 还原 → ✓
```

面板那一行的红侧（手工删行 → pty 红 → 还原 → 绿）由独立复验席位按任务书 6.2 重做——本报告不代做；两条 pty
断言都取文案里自测题那一段，删整行或只删自测题都会红（见 §3.4）。

## 本轮没验到的产品行为

- **「某条回复是不是写给用户的」不可机判**：门禁只证「判据在场上 + 示例命令能用」，没有任何断言能判一条真实
  回复该不该发布；不写这样的场景，也不在页面文案里承诺自动标记（面板不读聊天/会话/历史）。
- **PM 是否真的照做**：没有工具能证明某个活着的 PM 发布了某条回复、或正文与答复一致——这是规格里
  `The honest limit` 明写的；本报告只能证明「纪律已随工具发出、示例命令可用、页面自述与自测题在场」。
- **§62 选段声明缺口**（裁定点 6）：未获授权，只做了读数与旁证，没有改 `section-paths.tsv`。
- **`spec-refs --check` 的既有红**（裁定点 7）：未获授权，只做了基线对照；它会让「全绿」的验收口径差一条。
- **选段不是全套门禁**：本次只跑了 39 段（闭包），另外 94 个键没跑（§5 点名）；交付/复验/归档阶段仍应跑整套。
- **段 26 的 `26-m tick` 在共享机器上有负载敏感性**（§5.2）：同一棵树同一命令时红时绿，随面板首帧延迟
  （5.4s–9.3s）走；本报告给的是归因与三次独立实验，不是「跑绿一次」的截图。
- **段 38-a 的既有红**（§5.1）：`panel-choices.sh` 的两个翻转树缺 `extension/`，main 上同样红；本任务未修。
- **面板 59 列的 en 说明行会被截断**：实测见 §3——问题与「the PM」仍在窗内，尾部按既有 `truncLine` 语义截断；
  规格要求的是「说明行在窗格里可见、不超过窗宽」，验收命令里没有「59 列读到完整一句」的断言。

## Decisions and deviations

- 三处表面保持**同一语义、不同语域**，不逐字相同（与 P257 既有裁定一致）；共享的只有 token。
- 协议里的边界段把「写给巡检/席位/别的项目 PM 不算」写成排除项，但 token 只出现在常设义务段——这是为了
  让变异 ② 能真正证明这条判据在协议面**单独承重**（详见 §2 的红 ②）。
- 「只发结论、不发过程」按 PM 复核**收成内容要求 + 写死反向句**（不是删除，也不是保留其排除用法）——三处的
  改前/改后原文见 §1.5。
- 诚实边界在协议里补了一句「某条回复是不是写给用户的同样不可机判」（原句保留 `No tool can verify` 开头）；
  如果 PM 认为这是超出「原样保留」的改动，删掉那半句即可（不牵动任何断言）。
- 面板文案按 PM 复核后的 `design.md` 决策 5 推荐两句（含自测题、问题放句首）；pty 断言串按 tasks 3.4 用问题
  那一段。
- **不在本任务修段 38-a**：它是 main 上的既有红（§5.1 有 main 只读导出的逐字复现），与本变更无关，且
  `panel-choices.sh`/`extension/` 不在本任务写集——按协议交给 PM 处置。
- **`node_modules` 不进交付树**：重建需要 `bun install`，但残留的 41 MB `node_modules/` 会让 `skip-path` 夹具在
  接近满的 `/tmp` 上拷贝失败（§3b）；产物提交后已删除，`git status` 干净。

## Suggested next steps

- 独立复验（另一席位）：`key-replies.sh --all`、`key-replies-pty.sh --all`、`smoke.sh --select <闭包段号>`、
  `panel-strings.mjs`，并重做 ①②③⑤ 与还原、另造一条同义改写变异、手工删面板说明行或只删自测题 → pty 红 → 还原。
- PM：裁决 §4.2 的 `spec-refs` 口径（提案裁定点 7），以及 §4.1 是否需要另立一条 `section-paths.tsv` 的小任务。
- PM（可选，两处都是既有红/既有脆弱点，另立小任务即可）：① 段 38-a 的两个翻转树补 `cp -a "$skill/extension"`；
  ② `26-m tick` 改成先等面板出帧再数拍（§5.1 / §5.2 各有候选修法）。
