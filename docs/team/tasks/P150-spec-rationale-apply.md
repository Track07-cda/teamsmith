# P150 · `spec-rationale-self-contained` apply：四处引用重写 + id 族键 + 走查脚本

```
task:   P150
agent:  dev3
issue:
change: spec-rationale-self-contained   # 提案已验收并合入 main
specs:  boundary#Specs are the contract
phase:  apply
anchor: change
deltas: boundary
grant:  skills/teamsmith/tests/** · openspec/specs/**（**只允许**按 delta 的四处重写与 `Id families:` 键行改动）· openspec/changes/spec-rationale-self-contained/** · docs/team/reports/P150-<agent>.md · docs/team/reports/P150-<agent>/**
deps:   `openspec/changes/spec-rationale-self-contained/{design,tasks}.md`（D5 的四次重写、D4 的键行、D7 的脚本落点照它做）· 与 P148（product-checkout-gate apply）都动"快闸门接线"：**后落地者解这个 merge**（delta 不重叠：boundary vs verification）· OWNERSHIP：`docs/team/**`（除你自己的报告）不许碰
status: todo
budget: 一个工作块
priority: 中高（公开可读性 + 把"契约不许指路"变成可机械检查的判据）
```

## 交付 = `tasks.md` 全部做完

1. **四处**具体 `docs/team/…` 引用按 D5 重写为**自洽表述**（结论与数字留在正文）—— **不许**弱化任何 scenario 的
   可证伪性（重写后逐个 scenario 仍可独立重跑）。
2. **id 族键行**（D4）：受影响的 spec 文本里加 `Id families:` 一行，只列实际用到的族；**没列的族不得出现**在这份文本里。
3. **走查脚本**（D7 + D2/D3）：`--check` 在本树绿（列出被 pending change 退场的引用，**不判失败**；未声明的引用点名文件/行/路径并非 0）；
   `--flips` 的每个变异都要有预期的 red/clean；**无账本检出**（产品面）下的行为与 P146 的契约一致（可见跳过，不假装通过）。
4. **slot / concrete 区分**必须真有牙：把一条**具体**报告路径放进副本 → 走查**必须红**（不许借 `docs/team/reports/<ID>-*.md` 蒙混）。
5. 门禁：`openspec validate --all --strict` + 走查脚本自测 + 相关段 + **FAST**（动了快闸门）。
6. **报账**：改动前后 **spec 文本里的引用数与 id 数**（逐族）；每个变异的前后原始输出。
