# P86 · 修 F1：定位出的框**必须包含光标行**（下边框候选的准入条件）

```
task:   P86
agent:  dev3
issue:
change: bottom-border-candidate-selection        # 返工：P84 的 F1（安全回归，本 change 引入）
specs:  delivery-guard#The bottom border is the lowest qualifying rule row below the cursor
phase:  apply
anchor: change
deltas: delivery-guard
grant:  skills/teamsmith/scripts/lib/outbox.sh · skills/teamsmith/tests/lib/box-judge.sh · skills/teamsmith/tests/frames/（新增 F1 帧）· skills/teamsmith/tests/smoke.sh（append-only）· skills/teamsmith/references/troubleshooting.md
deps:   P80（apply，同 change）· **P84 的 F1**（`reviews/P84.md`，含自造帧与两侧原始输出）
status: todo
budget: 小到中
priority: **高**（安全方向：现状会让 payload 打进人的草稿）
```

> 本地模式：不 push。**真源 = `openspec/changes/bottom-border-candidate-selection/` + P84 的报告 §F1。**

## 根因（P84 实测，已复现）

规格只要求"顶边框是**下边框之上**最高的合格行"；旧顺序下（下边框紧贴光标下方）这**隐含**了"框含光标"。
改成**最低候选**后，配对可以**整个落在光标下方**：混宽度帧里，下方另有一对**自成配对**的规则行（宽度不同），
于是新框 `[5 7]` 与光标框 `[1 3]` **不相交**，判定 `BUSY → EMPTY`，**生产路径也会 EMPTY**（就绪门放行 →
payload 打进 `HUMAN DRAFT LINE`）。requirement 里"框只会变大 / 不许 BUSY→EMPTY"那句在混宽度帧上是**假的**。

## 要做的

1. **准入条件**：下边框候选**必须**满足"配到的顶边框**严格在光标行之上**"（⇒ **框包含光标行**）；
   不满足的候选**跳过**，继续在**更近**的候选里找；全都不满足 → 走既有的 unknown-shape 路径（不新造行为）。
2. **单调性因此重新成立**并**写成可机读的断言**：对**全部已存帧 + F1 的帧**逐帧对比旧/新 →
   **没有 BUSY→EMPTY**；并且断言"定位出的框**总是包含光标行**"（对全部帧）。
3. **同时修假话**：requirement/design 里那句"框只会变大"改为以"**框必须含光标**"为前提，
   或直接写成"不满足含光标条件的候选不合格"；**不许**保留一句已被证伪的论证。
4. **F1 的帧进仓库**：把 P84 的 `f1-mixed-width-disjoint-box.txt`（与它的两个变体）存进 `tests/frames/`，
   并加断言（旧判据 BUSY / 新判据 BUSY，**不是** EMPTY）。
5. **红/绿两侧**：红侧 = 当前 HEAD（`8e32a04e`）跑 F1 帧 → 复现 `EMPTY`；绿侧 = 修后同帧 → `BUSY`。
6. **零回归**：`openspec validate` + FAST + 全量 smoke；`44·P80-真pane` 与 13 份已存帧的单调性断言照旧。
