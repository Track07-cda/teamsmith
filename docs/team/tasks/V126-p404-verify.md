---
id: V126
title: P404（声明面断言）独立复验
agent: verify
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
anchor: openspec/changes/instruction-context-slimming/specs/init-skill/spec.md
deltas: -
branch: task/V126-p404-verify
---

# V126 · P404 独立复验（非作者）

被验 `task/P404-declaration-guards` @ `93e3634c`（作者 dev2）。

## 背景

V125 实测：规格点名的两处声明面（双门禁分工、`SKILL.md` 的 `## Agent adapters` + `description` + 深读表行 + 冻结 seam 措辞）**没有任何断言守着**——删掉整句、把措辞改成禁语，门禁依旧绿。P404 要补上会变红的断言，并按净零纪律退掉一条旧断言。

## 必须独立证明

1. **判据落在段落实质，不是关键词橡皮章**：读实现，确认它先按空行取段、再要段内同时出现两条命令与"性能读数不构成判决"的结论。你自己构造三个反例证明它会红：
   - 删掉整句（该段消失）；
   - 把"不是判决"改成正命题（词都在、意思反了）；
   - 把两条命令中的一条删掉。
2. **seam 措辞逐个受管**：把任意一处非 Pi 提法的冻结措辞改掉 → 必须红，并点名是哪一处。
3. **净零是真的**：作者退掉了 `references/openspec.md` 上一条重复断言。请判断它**确实**与保留下来的那条判定等价（不是把唯一一条删了却说"重复"）。
4. **§36 ⑤d 探针重标定不是放水**：`checkout-shape-probe.sh` 的 `✓16 → ✓20` 是跟着 §19 新增 4 条用例走的计数修正；确认它仍断言 `✗10 SKIP0`、仍然是"空面不算缺席"这条控制。若它放松了任何一条判定，判红。
5. **红线未动**：`SKILL.md`、`references/*.md`、`templates/` 的正文在本片里逐字节未变（P404 只该动测试与其声明）。

## 允许的命令

- `bash skills/teamsmith/tests/smoke.sh --select 19,39 </dev/null`
- `bash skills/teamsmith/tests/checkout-shape-probe.sh --select ⑤d`（或它支持的等价最小选择；重活按需）
- `spec-refs --check`、`section-select --check`、`ledger-ban --names-file .pi/team/forbidden-names.txt`、`openspec validate --all --strict`（`~/.cache/openspec-1.8.0/node_modules/.bin/openspec`）、`git diff --check`

## 边界

- 不跑全量 smoke；不改作者分支；不合并/归档/发布。结论 `docs/team/reviews/V126-verify.md`，第 3 行 `判定: **PASS**` 或 `判定: **NEEDS-CHANGES**`。
