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
