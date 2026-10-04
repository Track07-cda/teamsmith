# P148 · `product-checkout-gate` apply：门禁认得"只有产品面的检出"（可见 SKIP，两向有牙）

```
task:   P148
agent:  dev2
issue:
change: product-checkout-gate      # 提案已验收并合入 main
specs:  verification#A gate that cannot judge says so
phase:  apply
anchor: change
deltas: verification
grant:  skills/teamsmith/tests/** · skills/teamsmith/scripts/lib/** · openspec/changes/product-checkout-gate/** · docs/team/reports/P148-<agent>.md · docs/team/reports/P148-<agent>/**
deps:   `openspec/changes/product-checkout-gate/{design,tasks}.md`（覆盖映射照它做）· 公开面生成器 `docs/team/tools/publish-public.sh`（验收要用它导出）· OWNERSHIP：`openspec/specs/**` 与 `docs/team/**`（除你自己的报告）不许碰 · 本地模式，推送带 `[skip ci]`
status: wip
budget: 一个工作块
priority: 高（公开仓的 CI 与"公开面能自证"都指着它）
```

## 交付 = `tasks.md` 全部做完，且**两向证据都要在容器/独立树里跑出来**

1. **产品面导出树**：`publish-public.sh` 导出的树里跑 `openspec validate --all --strict && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null`
   → **退出 0** ✅，缺的内部前提以**计数的 `SKIP（条件不满足）` 行**点名 ✅，**不许**把 SKIP 算进通过 ✅
   （段计数与总数必须自洽 ✅ —— 账本自查已经在守这条 ✅）。
2. **产品面真失败仍必须红** ✅：在导出树的 scratch 副本里弄坏一个**产品**字面（例如 `skill-load` 的入口 ✅）
   → 段自检 `--check` 与英文正文检查都要**失败并点名那条产品路径** ✅（其他内部前提照旧 SKIP ✅）。
3. **内部树不许少跑任何东西** ✅：改前/改后两个独立检出的**断言清单**逐条比对（段通过数、总数）✅；
   一条 mutation：把既有内部断言换成前提跳过 → 清单比对**必须失败** ✅。
4. **滥用形状全都要红** ✅：半边内部树（删 `SCOPE.md` / 删一个 `opsx-apply.md` / 删一个相位 `SKILL.md`）✅、
   空目录假装内部面 ✅、缺工具（`perl` 不可用）保留它自己的失败 ✅、继承 `TEAM_ROOT` 不改变分类 ✅。
5. **`.github/workflows/gates.yml`** 的**正确性命令保持不变** ✅（`openspec validate … && bash skills/teamsmith/tests/smoke.sh --keep </dev/null` ✅）。
6. 门禁：`openspec validate --all --strict` + 相关段 + **FAST** + **一次全量**（动了门禁本身 ✅）；
   每条 What flips 留红→绿原始输出 ✅；报告点名"哪些自己跑、哪些引用" ✅。

## 落地后的 PM 动作（不用你管，记在这里）

`publish-public.sh` 的 `PUBLIC_PATHS` **把 `.github` 加回白名单**（它现在被暂缓导出，注释里写着原因）✅
—— 那一步由 PM 做，因为它是发布面的决定 ✅。
