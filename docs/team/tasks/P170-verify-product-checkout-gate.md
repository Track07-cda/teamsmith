# P170 · `product-checkout-gate` 独立验证（换人：apply 是 dev2）

```
task:   P170
agent:  dev
issue:
change: product-checkout-gate
specs:  verification#A gate that cannot judge says so
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P170-<agent>.md · docs/team/reports/P170-<agent>/**
deps:   合并提交 `feat(teamsmith): P148 …`（在 main ✓）· PM 复验 `docs/team/reviews/P148.md`（待写；核心证据在上一条提交信息里 ✓）· 实现自述 `docs/team/reports/P148-dev2.md`（主张，不是证据）· 生成器 `docs/team/tools/publish-public.sh`（**PM 写的** ✓ 你要证伪的是门禁本身 ✓）
status: wip
budget: 一次对抗性验证
priority: 高（公开仓能不能跑 CI 全靠它；且它改了**选择器**与**跳过记账**两条地基）
```

## 要独立证明或证伪的（**自己造树**，不要只用生成器导出的那一棵）

1. **产品面检出：可见跳过 + 不计通过** ✅：自己造一棵"只有产品面"的树（**手工挑文件** ✓，不是照抄生成器的白名单 ✓）→
   跑 `openspec validate --all --strict` ✓ + FAST ✓ → **退出 0** ✓；缺的内部前提**逐条点名** ✓；
   把"跳过"与"通过"的计数**分别**核一遍 ✓（账本自查必须自洽 ✓ —— 造一个"跳过被算成通过"的影子 → 必须红 ✓）。
2. **产品面真失败仍必须红** ✅：弄坏**产品**字面（skill 名 / 一处函数名 ✓ 随便 ✓）→ 对应段**必须红并点名** ✓；
   **反向**：不弄坏 → 必须绿 ✓（不许"什么都跳过"✓）。
3. **滥用形状全都要红** ✅（**逐条自己造** ✓）：
   ① 半边内部树（有 `SCOPE.md`、缺相位 skill ✓）② 空目录假装内部面 ✓ ③ 缺工具（`perl` 不可用 ✓）
   ④ **产品面检出里出现一个真产品失败** ✓ ⑤ 继承 `TEAM_*`（`TEAM_ROOT`/`TEAM_PROJECT` 指向别处 ✓）**不得**改变分类 ✓。
4. **内部树不许少跑** ✅：在**内部检出**上跑 FAST ✓ 与合并前基线比**断言总数与段数** ✓（少一条即红 ✓）；
   影子：把一条既有内部断言换成"前提跳过" ✓ → 必须被抓住 ✓（谁的判据？自己写 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 你在独立检出上跑 `--select 0e,0h` ✓ + **容器内** FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓（CI 真跑、别的平台 ✓）。
