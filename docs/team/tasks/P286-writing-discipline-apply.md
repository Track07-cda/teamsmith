# P286 · 写作纪律：apply（三处表面 + 评审读法 + 本仓 AGENTS.md 重渲染）

task: P286
agent: dev-bob
phase: apply
category: code
change: writing-discipline
specs: writing-discipline
deltas: -
branch: task/P286-writing-discipline-apply
deps: P282（提案已 ACCEPTED 并入 main，见 `docs/team/reviews/writing-discipline-proposal.md`；七个裁定点全按推荐，**第 6 条我改判「折进本变更」**）

## 范围（合同以 `openspec/changes/writing-discipline/` 为准）

1. **三处表面**：`templates/AGENTS.section.md.tmpl`（工人协议段）、`templates/pm-prompt.md.tmpl`（PM 提示词）、`references/protocol.md` 的 §11/§11b（面向用户的报告那一节）——各写**可执行**的几条：先答读者的问题；能删就删；**只在有证据时声明边界**（点名测量/反例/推理缺口/未观测到的边界）；发现必须写明它**改变了什么**。**不许**出现任何语气类措辞（「更自信」「更强硬」「更短更有力」）。
2. **评审口径落 `references/workflows.md` §E**（不是 `openspec.md` 那份十条清单——那条清单被恰好十条的断言钉着）。
3. **第 6 条（我改判折进本变更）**：`references/workflows.md` §0 的阶段表写着「the **eight-point** checklist」而实际是十条 → 一并改对（改成十点或不写数字，你定），报告里给前后对照。
4. **本仓 `AGENTS.md` 重渲染**：**授权你**只刷新 `<!-- teamsmith:begin -->` … `<!-- teamsmith:end -->` 之间的块（用 `team init` 的渲染路径或等价方式），其余字节不动；报告里贴 diff。
5. **不变量**（提案里已写、我重申）：**不动产品代码**（`scripts/**`、`extension/**`）、**不动门禁断言**、不动规格、不加配置键、不改退出码。自查：`git diff --stat -- skills/teamsmith/ | grep -vE 'templates/(AGENTS\.section|pm-prompt)\.md\.tmpl|references/(protocol|workflows)\.md'` 必须为空。

## 边界

- 与在飞写者串行：`references/protocol.md` 有另一个在飞变更写 §9b（门禁锁）→ **不碰 §9b**；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我。
- 不合并、不推送；做完 `team notify pm`；随后由**另一席位**独立复验（含对抗读与对照两臂）。

## 验收（贴真实输出）

```bash
bash skills/teamsmith/tests/section-select.sh --paths skills/teamsmith/templates/AGENTS.section.md.tmpl skills/teamsmith/templates/pm-prompt.md.tmpl skills/teamsmith/references/protocol.md skills/teamsmith/references/workflows.md
bash skills/teamsmith/tests/smoke.sh --select <上面打印的段号>
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --stat -- skills/teamsmith/ | grep -vE 'templates/(AGENTS\.section|pm-prompt)\.md\.tmpl|references/(protocol|workflows)\.md'   # 必须为空
git diff --check && git status --short
```

## 返修轮次 1（2026-10-15，独立复验 V47 判 FAIL：一条阻断，**我自己读过并确认**）

复验记录 `docs/team/reviews/V47.md`（受检 `f74f20d9`）。

**F1（必修）**：PM 提示词模板的规则段末尾多了一句

> When in doubt, delete: a short answer that answers the question beats a defensive one.

而规格 R1 的第二个场景明写：这段文字要陈述**支持判据**，且「**不得带有让人更自信、更强势的指示，也不得声称「更短」或「更有力」就是目标**」。这句话把「短」摆到胜出的一侧，**与规格直接冲突**（你同一批文字里已经正确写了「这不是让你更自信/更强势/更短的指令」，这句自相矛盾）。

**改法**：把那句换成**支持判据**的表述，例如「一句没有点名任何可核查之物的话被删掉；留下的，是读者能核实的东西」——也就是把「删」的依据绑在**证据**上，而不是绑在**篇幅**上。三处表面都要核一遍有没有同类句子（worker 模板、PM 模板、协议 §11b），**只改真正违反 R1 场景 2 的**，别顺手改风格。

**红侧**：① 把「短/更强势」这类词放回规则文本 → 必须红并点名（V47 的 R1 逐句核那一节就是判据，作者自测里要有等价的一条）；② 删掉支持判据那一句 → 必须红。

**另外**：V47 的**两臂对照跑的是改前的文本**，所以改动落定后要**重跑两臂**（同一任务、同一条规则的新版文本、去掉标识、随机顺序）并把盲包重新生成——人读那一步等新包。
