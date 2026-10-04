# P146 · `product-checkout-gate` propose：公开树（只有产品面）也要能诚实地跑门禁

```
task:   P146
agent:  verify
issue:
change: product-checkout-gate
specs:  verification#A gate that cannot judge says so
phase:  propose
anchor: change
deltas: verification
grant:  openspec/changes/product-checkout-gate/** · docs/team/reports/P146-<agent>.md · docs/team/reports/P146-<agent>/**
deps:   2026-10-01 开源发布准备（`docs/team/RELEASE-PUBLIC.md` §9）· 公开面生成器 `docs/team/tools/publish-public.sh` · 现有"可见 SKIP"纪律（`gate-hygiene`：能力不足/前提不成立要**可见地跳过**，不许假装通过）
status: wip
budget: 一个提案
priority: 高（公开仓第一次跑 CI 就会红 ✗ —— 那是我们最讨厌的假红/坏第一印象）
```

## 现场（实测，不是推测）

公开面（222 文件：`skills/ bin/ install.sh openspec/specs README LICENSE package.json .gitignore ci .github`）里跑
`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh` → **✓3141 ✗16**（内部树同一套是 ✓3156 ✗0）。
红的是那些**需要内部账本/规划件**的段落 —— 例如 `#96 §36 选段与分段账本自检` 就是 ✓102 **✗3**（它的
`--check` 要求行里点名的**字面模式**在工作树里存在 ✗，而其中一些指向 `docs/team/**` ✗）。

**这不是产品缺陷** ✗（产品面 222 个文件全绿的那些段落都过了 ✅），是**门禁的前提**在公开树里不成立 ✗。


## 实测的红（16 条，逐条点名 —— 我在公开面导出树里跑出来的）

| 段 | 条数 | 断言（缺什么） |
|---|---|---|
| `§36 选段与分段账本自检` | 3 | `--check` 要求行里点名的**字面模式**在树里存在，其中有指向 `docs/team/**` 规划件的 |
| `§18 英文正文不变量与安装器唯一入口` | 1 | `扫描根存在（SCOPE.md）` → 公开树**故意不含** `SCOPE.md`（写给本仓库 agent 的内部约定） |
| 同段（本仓库的 Pi 相位脚手架） | 5 | `本仓库为 Pi 生成了相位命令 opsx-{explore,propose,apply,verify,archive}` → 缺 `.pi/prompts/opsx-*.md` |
| 同段（相位 skill） | 5 | `相位 skill openspec-{explore,propose,apply-change,verify-change,archive-change} 在位` → 缺 `.pi/skills/openspec-*/SKILL.md` |
| 其余产品面段落 | 0 | `#1`–`#35`、`#37` 起全绿（含 `0b` 可加载、`0c/0d` 静态检查、`2 init`、`3b git 归 PM`、容器与面板段） |

## 两条可选路线（propose 必须**二选一并说清代价**）

- **A · 前提不成立就可见跳过**：树里没有 `docs/team/**` / `SCOPE.md` / `.pi/prompts` 时，这些断言照既有 SKIP 语汇可见跳过 ✅；
  内部树行为**一字不改** ✅。代价：公开仓的 CI 里有一部分断言是 SKIP ✅（诚实 ✅ 但覆盖率低一点 ✅）。
- **B · 把"通用脚手架"也发出去**：`.pi/prompts/opsx-*.md` 与 `.pi/skills/openspec-*/SKILL.md` 是 **openspec 生成的通用件** ✅
  （不含隐私 ✅ 不含账本 ✅）→ 可以让生成器**只放行这两个子树** ✅（`.pi/team/**` 仍禁 ✅），那 10 条红自然消失 ✅；
  剩下 6 条（SCOPE.md + §36 的 3 条 + …）仍按 A 处理 ✅。代价：公开树多两个通用目录 ✅、生成器多一条**带注释的例外** ✅。

## 要 propose 的（可证伪，最小改动）

1. **门禁要认得"这是只有产品面的检出"** ✅：当工作树**没有** `docs/team/**`（或 `openspec/changes/**`）时，
   依赖它们的段落/断言**可见地跳过** ✅（沿用既有 SKIP 语汇 ✅：`SKIP（条件不满足）… <原因>`），
   **不许**静默通过 ✗、**不许**把红伪装成跳过 ✗；
2. **产品面的段落必须真的跑** ✅：`skills/**` 的静态检查、skill 可加载、契约（`openspec validate`）、
   容器的构建检查、以及所有不需要账本的夹具 ✅ —— 给出**改动前后逐段对照表**（哪些从红变 SKIP、哪些仍然跑）✅；
3. **反向必须成立** ✅：在**内部树**里跑同一套，**不许**因为这条新逻辑少跑任何东西 ✅（给出内部树的
   ✓ 数不下降的断言 ✅）；
4. **`--check` 类自检要分清"规划件缺失"与"字面模式丢失"** ✅（前者可跳 ✅ 后者仍必须红 ✅，因为那是"文档说了但代码里没有"的真相 ✗）；
5. **CI 侧** ✅：`.github/workflows/gates.yml` 在公开仓里应当**通过**（前提是 1–4 正确 ✅）；
   给出"在公开面导出树里跑一次 FAST"的可复现命令 ✅（`docs/team/tools/release-check.sh --with-gates` 已经这么做 ✅）。

**非目标**：不改任何产品行为 ✗ · 不放松任何断言 ✗ · 不做"公开版门禁"的第二套脚本 ✗（**一套门禁，两种前提** ✅）。

## 交付

`openspec/changes/product-checkout-gate/{proposal,design,tasks}.md` + `specs/verification/spec.md` delta ✅
+ `openspec validate --all --strict` ✅ + MODIFIED 不丢基线场景 ✅ + What flips（红侧：把跳过改回红 / 把内部树的跳过改回跑，两向都要能红）✅。
