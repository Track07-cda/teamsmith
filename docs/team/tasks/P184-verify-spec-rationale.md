# P184 · `spec-rationale-self-contained` 独立验证（换人：apply 是 dev3）

```
task:   P184
agent:  verify
issue:
change: spec-rationale-self-contained
specs:  boundary#Specs are the contract, and a published spec stands on its own
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P184-<agent>.md · docs/team/reports/P184-<agent>/**
deps:   提案（已验收 ✓）· 实现 **P150**（dev3 ✓，在 main ✓）· PM 复验：validate 22/0 + 两条变异（未声明具体指针 / 具体 id 借槽位形状）都红并点名 ✓ · D31
status: wip
budget: 一次对抗性验证
priority: 中高（它决定**公开契约**能不能自洽 ✓；判据容易写成"看着对" ✓ → 要有影子 ✓）
```

## 要独立证明或证伪的（**自己造变异**，别只用它的 `--flips`）

1. **未声明即红** ✅：自己往 `openspec/specs/**` 里植一条**未声明的具体** `docs/team/reports/<ID>-dev.md` → 走查**必须红**并**点名文件与行号** ✓
   （PM 已试 ✓，你用自己的形状再来一次 ✓）。
2. **槽位不放过具体 id** ✅：植一条**形状像槽位**的具体引用（如 `M99-dev.md` ✓）→ **同样必须红** ✓（这是提案 D2 的核心 ✓）。
3. **声明表能证伪** ✅：把某条已声明行的 `basis` 清空 ✓ / 把 `kind` 改成非法值 ✓ → 走查**必须拒载并点名该行** ✓（空 basis 不许被当成合格 ✓）。
4. **影子（必须有）** ✅：把"未声明即红"改成"未声明即跳过" → 用例 1/2 必须红 ✓。
5. **不误伤** ✅：本树**绿** ✓；`docs/team/**` 里那些引用（维护者账本 ✓）**不许**被判红 ✓（走查只管 `openspec/specs/**` ✓）。
6. **id 族与 pending 依赖** ✅：走查打印的 `id families used … named …` 里，**用到的族必须都被 named** ✓（自己造一条用新族但未 named 的引用 → 必须红 ✓）；
   而**未归档 change 的 delta** 里的引用按 pending 处理 ✓（不许把还没发布的文本当契约判红 ✓ —— 反过来，change 归档后它必须进判 ✓）。
7. **门禁**：`openspec validate --all --strict` ✓ + `--select <它的段>` ✓ + 容器内 FAST ✓；报告写清原始输出与**没有**测到什么 ✓。
