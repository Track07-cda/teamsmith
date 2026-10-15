# 复核 · P286 第一轮（独立复验 V47 判 FAIL）

- **判定: FAIL**（一条阻断 F1）
- F1：PM 提示词模板的规则段末尾那句「When in doubt, delete: a short answer that answers the question beats a defensive one」**与规格 R1 的第二个场景冲突**——规格明写这段文字「不得声称更短或更有力就是目标」。**我读了候选模板与规格原文确认**（`skills/teamsmith/templates/pm-prompt.md.tmpl:28` 与 delta 的 R1 场景 2）。
- 其余：三处表面与评审读法把判据写对了、四条要求里三条通过、`validate` 23/0、投影自洽、`spec-refs` 0 未声明、账本禁令 0 命中、对抗变异（把规则文字全删 → 门禁照绿）也照出了「规则文本本身没有门禁咬」这一事实（与本变更的「文风靠评审」设定一致）。
- **盲包已生成**（`pm-skills-ledger/team/reports/V47-verify/blind/`：两篇匿名正文 + 单独封存的对照文件），但它跑的是**改前文本**，所以返修落定后要**重跑两臂**再交人读。
- 返修要求写在任务书末尾「返修轮次 1」；dev-bob 完成手上的 P291 后立即接。
