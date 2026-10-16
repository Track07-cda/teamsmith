# replies-for-the-user-are-published · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每处表面与每组断言都要有红侧与还原证据）；**verify** 由**另一个**
席位（不是 apply 作者，dispatch 的自验守卫会拦）在独立克隆上重跑本表全部场景与红侧。本文件不是规格；合同文本在
`specs/key-replies/spec.md`（2 条 MODIFIED）与 `specs/panel/spec.md`（1 条 ADDED）。

判据一句话：**这条回复是写给谁的**——写给用户的就必须发布（回答、汇报、结论、裁定、请示、交付摘要，不论长短）；
写给巡检/其他席位/别的项目 PM 的与工具回执不算；判不准时按写给用户处理。

写集：`skills/teamsmith/templates/pm-prompt.md.tmpl`、`skills/teamsmith/references/protocol.md`、
`skills/teamsmith/SKILL.md`、`skills/teamsmith/tests/key-replies.sh`、`skills/teamsmith/tests/key-replies-pty.sh`、
`skills/teamsmith/scripts/panel/src/strings/{zh,en}.ts`、`skills/teamsmith/scripts/panel/src/layout.ts`、
**重建产物** `skills/teamsmith/scripts/panel/panel.js`。`tests/section-paths.tsv` **仅当** PM 按提案裁定点 6 裁
「补声明」才动（第 4.1 条）；`openspec/specs/**` 与 `tests/spec-ledger-refs.tsv` 不属本表（裁定点 7）。

## 0 冻结与基线

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/replies-for-the-user-are-published-proposal.md`，逐条确认裁定点 1–7，
  结论摘进报告；与提案不同的裁定按其改写判定、场景与任务项。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 冻结**改动前**基线并抄进报告：三处文件里 `grep -ciF "written for the user"`（今天都是 0）、
  `guide_spec()` 的三行锚点原文（`tests/key-replies.sh:1055-1059`）、`bash tests/key-replies.sh --select guide` 的
  ✓/✗ 计数、`grep -c replyPageNote` 于两张字符串表（今天都是 0）、`bash tests/panel-strings.mjs .` 的结尾一行、
  `section-select.sh --paths <三处表面>` 的 `keys=`（今天 26，**不含 62**）。 · 证据：基线日志
- [ ] 0.3 独立树投影自证：`rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec && (cd /tmp/<x> &&
  "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y replies-for-the-user-are-published &&
  "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict)` 必须绿；归档后逐条对照 2 条 MODIFIED 的
  既有场景**逐字**保留、1 条 ADDED 落地，且没有第二个未归档 change 动 `key-replies` 或 `panel` 的同一批要求。 · 证据：投影输出尾

## 1 三处指令面（规格 `key-replies#Publication does not gate the normal answer or create work` 与 `#The key-conclusion duty …`）

- [ ] 1.1 `templates/pm-prompt.md.tmpl` 现有那段（`:31-35`）整体改成按读者判（写给用户的都必须发布、写给巡检/席位/
  别的项目 PM 的与工具回执不算、判不准按写给用户处理），含 token `written for the user` 与那句自问
  `who is this reply written for?`；示例命令仍是全模板**唯一**一行 `team reply post …`（`grep -c 'team reply post'` = 1），
  且逐字形如 `team reply post --from pm --title '<short title>' --stdin < <file>`。 · 证据：段落原文 + `grep -ciF`
- [ ] 1.2 `references/protocol.md` §4b：常设义务那句改成同一判据；代码块后加边界段（读者决定 / 不算的几类 / 判不准怎么办）；
  机制、回执含义、「发布不阻断答复」、只读读取与末尾的诚实边界（`No tool can verify`）**原样保留**。 · 证据：段落原文
- [ ] 1.3 `SKILL.md`：command table 的 `| Key replies |` 行（`:54`）与 `:250` 的 Non-negotiable bullet 同步改成同一判据
  （两处不许一个有一个没有）。 · 证据：两处原文 + `grep -iF` 输出
- [ ] 1.4 三处共享 token 命中（大小写不敏感），且 command table 的 token **落在行内**：`grep -iF` 三份输出。 · 证据：三份输出
- [ ] 1.5 与旧句的取代关系落到位：新三处不再出现「只发结论、不发过程」这类与按读者判据冲突的说法（`grep -i` 三种旧说法应为 0）
  ——这是**有意的取代**，在报告里点名。 · 证据：grep 输出

## 2 门禁面（规格 `key-replies#The key-conclusion duty …` 的两条新场景）

- [ ] 2.1 `tests/key-replies.sh` 的 `guide_spec()`（`:1055`）三行各加 token——command table 那行写成
  `row:written for the user`；**注意**这一串没有撇号，三行可以沿用单引号写法，但改完必须 `bash -n` 过。 · 证据：三行原文 + `bash -n`
- [ ] 2.2 `guide-surfaces` 真树三面全绿（`--select guide` 里那三条 ✓）。 · 证据：命令输出
- [ ] 2.3 既有三条变异 ①②③ 的红文案里**出现** `[written for the user]`（三处各自承重），还原后绿。 · 证据：三条红文案
- [ ] 2.4 新增变异 ⑤（`kr_group_guide` 内，与 ①–④ 同形状）：从真树复制模板 → 只把 `written for the user` 换成
  `written for a person`（句子仍通顺）→ `guide_check_surface "prompt template" "$mut"` 必须 rc≠0 且红文案含
  `[written for the user]` → 重新复制真树后绿。**变异没应用上要单独报红。** · 证据：⑤ 的红文案 + 还原绿
- [ ] 2.5 `guide-example` 原样保留且真跑：示例命令 rc=0 + `outcome="saved"` + 槽位 +1；控制臂（+`--frobnicate-probe`）
  rc=2 + 诊断含「未知参数」+ 槽位不变。 · 证据：两条运行的输出尾与槽位数前后
- [ ] 2.6 组内**没有**新增措辞/语气/句子形状断言（包括「写给巡检不算」这一极）：`git diff` 里 `guide` 组的新增行只有
  token、变异与文案。 · 证据：diff 片段

## 3 Pulse 第 5 页那一行（规格 `panel#The key replies page states what it is and who publishes into it`）

- [ ] 3.1 `src/strings/zh.ts` 与 `en.ts` 各加一个键（建议 `replyPageNote`），文案按提案裁定点 3（PM 可改词）；
  `node skills/teamsmith/tests/panel-strings.mjs .` 必须绿（键集相等 + 占位符一致 + 表外无 CJK）。 · 证据：两表行原文 + 检查输出
- [ ] 3.2 `src/layout.ts` 在 `:1386`（`const lines: PlacedLine[] = [replyNavLine(ctx, innerW)]`）之后紧跟一行 dim，
  用 `truncLine(ln(seg(... 'dim')), innerW)`；无 hit 目标、无动作；空 store 与降级读数也带它。 · 证据：改后片段
- [ ] 3.3 重建提交产物：`( cd skills/teamsmith/scripts/panel && bun install --frozen-lockfile && bash build.sh )`，
  再在沙盒里重建一次并逐字节比对（`smoke.sh` §26-a 的同一判据），报告给出字节数。 · 证据：build 输出尾 + `cmp` 结论
- [ ] 3.4 `tests/key-replies-pty.sh`：`pages` 组（zh）加一条 `assert_has` 断言行在窗格里；`language` 组把它并进 en 的
  `want_frame`。不新增组、不加新机制。 · 证据：`--select pages,language` 的输出尾 + 两条断言原文
- [ ] 3.5 只读与诚实边界未被削弱：`--select pages,language` 全绿，且 `key-replies-ui.sh --select machine,blocks` 仍绿
  （机器出口不读回复、记录到的读者调用仍只有有界块）。 · 证据：两条命令的输出尾

## 4 裁定点落地（只做 PM 裁「做」的那些）

- [ ] 4.1 **仅当** PM 按裁定点 6 裁「补声明」：`tests/section-paths.tsv:153`（段 62）的 patterns 加
  `skills/teamsmith/templates/pm-prompt.md.tmpl skills/teamsmith/references/protocol.md skills/teamsmith/SKILL.md`，
  basis 写明依据，`bash skills/teamsmith/tests/section-select.sh --check` 必须绿，
  `--paths <三处表面>` 的 `keys=` 必须**包含 62**。若 PM 裁「不动」，本项写明 N/A 与依据（P257 裁定点 5）。 · 证据：改后行原文 + `--check` 输出尾
- [ ] 4.2 **仅当** PM 按裁定点 7 把 `spec-refs` 那条既有红的修复明授权给本任务：按授权方式修，跑
  `bash tests/spec-refs.sh --check` 到 rc=0。未授权则如实记录「今日 rc=1，唯一一条 undeclared 与本变更无关」
  （附基线对照）。 · 证据：命令输出尾 + rc

## 5 验收与交付

- [ ] 5.1 按顺序跑齐 proposal「Acceptance」里 apply 的全部命令（`--select guide`、`--all`、`--select pages,language`、
  重建、`panel-strings.mjs`、`smoke.sh --select 26,28,62`、`validate --all --strict`、投影自证），报告贴**真实命令与
  输出尾**；任何一条没跑就如实写「未跑」。 · 证据：命令日志
- [ ] 5.2 写报告 `docs/team/reports/<ID>-<agent>.md`：第 2.4 条与第 2.3 条的**原始输出**就是本任务的翻转证据
  （摘掉 token → 红并点名面 → 还原 → 绿）；第 3.3 条的 `cmp` 是面板产物不漂的证据；单列「本轮没验到的产品行为」
  一节（至少包括：判「某条回复是不是写给用户的」不可机判、PM 是否真的照做无工具可证）。 · 证据：报告
- [ ] 5.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；不合并不推送，分支留本地；`team notify pm`
  一行交付说明。 · 证据：`git log --oneline` + 通知

## 6 独立验证（另一席位，不是 apply 作者）

- [ ] 6.1 独立克隆上重跑 `key-replies.sh --all`、`key-replies-pty.sh --all`、`smoke.sh --select 26,28,62`、
  `panel-strings.mjs`，并确认重建产物与 `src/**` 一致。 · 证据：独立日志
- [ ] 6.2 逐条重做变异 ①②③⑤ 与还原（不是只复跑绿侧）；自己再设计一条**同义改写**变异（例如把 token 换成
  `the reader is the user`），确认红的是 **token** 而不是别的锚点；在真树上手工做一次「删掉面板那一行 → pty 红 →
  还原 → 绿」。 · 证据：复验记录
- [ ] 6.3 自设计反例：token 只出现在该面的**段落之外**（例如文末附录）时守卫是否仍按面判定；同一句话里放两个 token
  是否让断言变空洞；面板那一行被截断到只剩前几个词时，`--select pages,language` 的两条断言是否仍能失败。 · 证据：反例输出
- [ ] 6.4 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。 · 证据：`docs/team/reviews/<ID>.md`
