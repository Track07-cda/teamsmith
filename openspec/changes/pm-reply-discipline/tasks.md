# pm-reply-discipline · tasks

阶段口径：**apply** 由收到本 change 的席位完成（每处表面与每组断言都要有红侧与还原证据）；**verify** 由
**另一个**席位（不是 apply 作者，dispatch 的自验守卫会拦）在独立克隆上重跑本表全部场景与红侧。本文件不是
规格；合同文本在 `specs/key-replies/spec.md`（1 条 MODIFIED + 1 条 ADDED）。

写集：本 change 的四个文件（`skills/teamsmith/templates/pm-prompt.md.tmpl`、
`skills/teamsmith/references/protocol.md`、`skills/teamsmith/SKILL.md`、`skills/teamsmith/tests/key-replies.sh`）
当前没有别的在飞写者。`tests/section-paths.tsv` 归 PM 裁定（proposal 裁定点 5）：**本批次默认不动**；
若 PM 裁定「补声明」，只做第 3.5 条那一处。

## 0 冻结与投影

- [ ] 0.1 读 PM 的提案评审 `docs/team/reviews/pm-reply-discipline-proposal.md`，逐条确认裁定点 1–6，结论
  摘进报告；与提案不同的裁定按其改写判定与场景。 · 证据：评审记录 + 报告摘录
- [ ] 0.2 独立树投影自证（propose 阶段已验过一次：`+ 1 added / ~ 1 modified`，归档后 `19 passed`）：
  `rm -rf /tmp/<x> && mkdir -p /tmp/<x> && cp -a openspec /tmp/<x>/openspec && (cd /tmp/<x> &&
  "$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" archive -y pm-reply-discipline && "$HOME/.bun/bin/bun"
  "$HOME/.bun/bin/openspec" validate --all --strict)` 必须绿。注意拷贝要嵌在 `<x>/openspec` 下：直接
  `cp -a openspec /tmp/<x>` 时 OpenSpec 不把 `/tmp/<x>` 认成根，会报 "No active changes exist in this root"。
  归档后逐条 ADDED 与那条 MODIFIED 对照，确认 MODIFIED 的既有场景逐字保留、无第二个未归档 change 动
  `key-replies`。 · 证据：投影命令与输出尾
- [ ] 0.3 冻结**改动前**基线并抄进报告：`grep -c 'team reply' templates/pm-prompt.md.tmpl`（=0）、
  `protocol.md` §4b 的条件句原文、`SKILL.md:54` 行与 `:249` bullet 原文、
  `key-replies.sh --all` 的 ✓/✗ 计数、`section-select.sh --paths <三处表面>` 的键集（今天 `keys=26`，
  **不含 62**）。 · 证据：基线日志

## 1 指令面（规格 `key-replies#Publication does not gate the normal answer or create work`）

- [ ] 1.1 在 `templates/pm-prompt.md.tmpl` 的 `## Talking to the user` 小节内加 ≤8 行英文纪律段：触发
  三时点（里程碑落地 / 做出裁定 / 请用户决策之前）、`team reply post --from pm --title '<short title>'
  --stdin < <file>`、正文是**完整那份**（不是摘要）、发完在对话里发**同一份**、同一批可合并、只发结论。
  不新增顶级章节、不改 loop 第 6 步。 · 证据：`sed -n` 段落原文 + `grep -iF` 各锚点
- [ ] 1.2 示例命令是全模板**唯一**一行 `team reply post …`，逐字形如
  `team reply post --from pm --title '<short title>' --stdin < <file>`（探针按它取值）。 · 证据：
  `grep -c 'team reply post' templates/pm-prompt.md.tmpl` = 1

## 2 文档面（规格 `key-replies#The key-conclusion duty …`）

- [ ] 2.1 `references/protocol.md` §4b：入口改成 **PM 的常设义务**（点名三个触发时点），保留机制代码块、
  回执含义、「发布不阻断答复」、只读读取的既有段落；末条诚实边界改写为「门禁只守表面的在场与示例命令
  可用，没有任何工具能证明某个活着的 PM 照做了」，**保留 `No tool can verify` 开口**。 · 证据：段落原文
- [ ] 2.2 `SKILL.md`：command table 的 `Key replies` 行点明它是**给用户的关键结论**的出口，并与
  `say`/`notify` 内部通道分开（该行含 `conclusion`、`say`、`notify`、`--stdin`）；Non-negotiable bullet
  保留机制文本并补触发条件（文件内含 `milestone`/`ruling`/`ask the user`）。 · 证据：两处原文
- [ ] 2.3 三处表面的共享锚点逐条对齐 design 决策 3 的表；大小写不敏感可命中。 · 证据：锚点清单 × 面的
  `grep -iF` 输出

## 3 门禁面（规格 `key-replies#The key-conclusion duty …` 的三条场景）

- [ ] 3.1 `tests/key-replies.sh` 加 `guide` 组，检查函数按 `(文件路径, 面名)` 参数化；`guide-surfaces`
  对真树断言三处表面的锚点（缺哪个点名哪个面），红文案里写清缺的锚点与它意味着什么。 · 证据：
  `bash tests/key-replies.sh --select guide`
- [ ] 3.2 `guide-example`：从模板取唯一示例行，在 `kr_new_proj` 私有夹具里**按印刷原样执行**（行首
  `team` 解析为真 CLI、重定向目标指向夹具正文文件）；接受臂必须 rc=0、回执 `outcome":"saved"`、存储
  槽位 +1；控制臂同一 argv 追加 `--frobnicate-probe` 必须 rc=2、诊断含 `未知参数`、槽位不变。
  · 证据：两条运行的 rc/输出尾 + 槽位数前后
- [ ] 3.3 `guide-flip`：四份 `$TMP` 副本各做一次变异，每次必须红并点名被改的面，还原（重新复制）后绿：
  ① 模板删掉持有 `Key conclusions` 锚点的整段 → 点名 `prompt template`；② 协议删掉常设义务段 →
  点名 `protocol reference`；③ SKILL 的 `| Key replies |` 行换成无锚点行 → 点名 `command table`；
  ④ 模板示例的 `--stdin` 改成 `--stdinX` → 点名 `example command`。真树与真项目零写入。 · 证据：
  四条变异的红文案 + 还原后的绿
- [ ] 3.4 隔离与可单跑：`guide` 组只用 `$TMP` 私有根与 `kr_paths_check`；`--select guide` 单独可跑且
  末行打印本组 ✓/✗。 · 证据：隔离断言输出
- [ ] 3.5 （**仅当 PM 按裁定点 5 裁「补声明」**）`tests/section-paths.tsv` 段 62 行的 patterns 加
  `skills/teamsmith/templates/pm-prompt.md.tmpl skills/teamsmith/references/protocol.md
  skills/teamsmith/SKILL.md`，basis 写明依据，跑 `section-select.sh --check` 必须绿。 · 证据：改后的
  行原文 + `--check` 输出尾

## 4 验收与交付

- [ ] 4.1 跑齐 proposal「Acceptance」的全部命令（`--select guide`、`--all`、`smoke.sh --select 62`、
  `section-select --check`、`spec-refs --check`、`ledger-ban`、`openspec validate --all --strict`、
  投影自证），报告贴真实命令与输出尾。 · 证据：命令日志
- [ ] 4.2 写报告 `docs/team/reports/<ID>-<agent>.md`：逐条命令/rc/输出尾；第 3.3 节四条变异与还原的
  **原始输出**就是本任务的翻转证据（删段→红并点名 / 旗标写坏→红 / 还原→绿）；写明任何未测项与失败。
- [ ] 4.3 小步提交（Conventional Commits + task ID + `Agent:` trailer）；不合并不推送，分支留本地；
  `team notify pm` 一行交付说明。

## 5 独立验证（另一席位，不是 apply 作者）

- [ ] 5.1 在独立克隆上重跑 `bash tests/key-replies.sh --all` 与 `smoke.sh --select 62`（或任务书指定的
  容器命令），确认十二组回归 + `guide` 全绿。 · 证据：独立日志
- [ ] 5.2 逐条重做第 3.3 节的四条变异与还原（不是只复跑绿侧），并在真树上手工做一次「删段 → 红 →
  还原 → 绿」。 · 证据：复验记录
- [ ] 5.3 自设计反例：把锚点词移到同文件的**段落外**（例如附录）时守卫是否仍按面判定；示例行出现第二
  次时探针取哪一行；`--frobnicate-probe` 控制臂在 CLI 吞旗标时是否真的红。 · 证据：反例输出
- [ ] 5.4 判 `verification` 的正确性门：只有证据通过；不因为「apply 报告说绿」判过。 · 证据：
  `docs/team/reviews/<ID>.md`
