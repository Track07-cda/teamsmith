# settings-view-groups · PM proposal review

time: 2026-09-22T0x:xxZ · reviewer: pm · verdict: **ACCEPTED**

```
change:  settings-view-groups（P29，propose=dev-bob）
tip:     b6cff3b（task/P29-propose）
user:    2026-09-22 三条反馈（滚轮 / 不按重启分组 / 重启类用颜色）
```

## Commands run

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict   → Totals: 16 passed, 0 failed
# delta：panel ADDED ×1（6 scenario）+ MODIFIED ×1（7 → 10，base 一条未丢）；memory-and-deps ADDED ×1（3）
```

## Findings

1. **D1 的选型与论证成立**：group 作为 **schema 行第 10 列**（封闭 token），而不是解析 `# ----` 分节注释——
   两条论证都站得住：① 单一真源（行已经拥有 class/kind/default/suggest，"分组"是同类事实）；
   ② 注释一旦 load-bearing，改注释就会移行，且分节标题带着会污染标识符的中文散文。
2. **D2**：12 个 ASCII slug（`identity/branch/policy/roster/seat-model/workflow/delivery/panel/patrol/pm-lifecycle/session/meeting`），
   标签复用现有分节横幅的名字（i18n 双侧）；**顺序取"读的顺序"**，不是视图排序规则。
3. **D3/D4**：功能域标题 + 组内 schema 序；**无 group / 未知 token → 可见降级**（不消失）；
   行级 class = **词 + tone**（restart 警告色、apply 正常、refuse 暗），**颜色不做唯一通道** ✓。
4. **D5（滚轮）**：设置视图获得**自己的 offset**、**消费事件**（不穿透到底下的页面）——
   现在 `App.tsx:1650` 的穿透正是"设置页没滚轮、页面在背后偷偷滚"的成因；
   并给"焦点键把聚焦行带回窗口内"补了 scenario。
5. **MODIFIED 逐条核对**：base 的 7 条 scenario 全在，新增 3 条（设置视图滚轮 / 不穿透 / 焦点保持可见）——
   无删除 ✓。
6. **D7 翻转清单**具体到门禁与红侧（config-cli groups 段、panel-strings 双侧标签、panel-p21 的 settings+groups+wheel、
   b3 的三处 wheel 不回归、FAST 结构钉）；**慢 pty 归全量门禁、FAST 保留结构钉**，符合 D33。
7. **D8 交叉检查**：与两个未归档 change 无表面冲突；与已归档 `settings-choice-editors` 基线只读相邻
   （新增字段挨着 `choices`，不动编辑器/写入路径）✓。**F1 后续项**（"可编辑域在前"需要显式 order 列）记录在案，
   不塞进本 change——合理。
8. **规模**：3 requirement / 19 scenario（其中 7 条是 MODIFIED 保留下来的 base），新增 9 条——在框内。

## 结论

**ACCEPTED**。apply 由 **dev-bob（提案作者，设计含精确行号）** 执行；
verify 必须换人。B2（change-centric-discipline 的遗留）与 `config list --json` 的空 override 缺陷
**都碰 panel/cmd-config.sh，排在本 change 之后**。
