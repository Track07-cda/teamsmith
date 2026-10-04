# P78 · `bottom-border-candidate-selection`（P74 的 F1 后续 change，propose）

```
task:   P78
agent:  （等席位）
issue:
change: bottom-border-candidate-selection
specs:  -
phase:  propose
anchor: change
deltas: delivery-guard
deps:   P74 的 F1（`reviews/P74.md`）· one-line-draft-judgement（已归档候选）· V9-A4/A5/A8/A10 的同族证据
status: todo（等席位）
budget: 一个提案包
```

> 本地模式：不 push。**只 propose。**

## 要解决的（P74 实测的缺口）

规格钉了**顶**边框的候选选择——"when several rows qualify, the top border is the **HIGHEST** qualifying row
above the bottom border, never the nearest one"——但**没有**钉**下**边框的候选选择。于是同族攻击换一端：

> **草稿自己画的一条等宽横线落在光标下方**时，如果下边框按"最近候选"取，框会被定位得**过小**：
> 真实下边框与它之间的内容（可能包含草稿的其余内容行）落在框外、**不被检查** → 框可能被读成 `EMPTY`，
> 就绪门放行 → payload 被贴进人的草稿。**这正是 P67 修好的那类事故的镜像**。

## 要裁决的（写清取舍与理由）

1. **下边框候选选择规则**：取"光标下方**最低**的合格行"？还是"最后一对**同宽**的规则行"？
   还是"等宽才配对、否则按光标几何回退"？——**给出可证伪的判据**，并说明它与顶边框取最高**如何配成一对**
   （两端都取"最外侧"才自洽；但也要考虑：真正的下边框**下方**还有会话文本，最外侧可能过宽 → 需要证据）。
2. **必须覆盖的形态**：① 草稿自画的等宽横线在光标下方；② 草稿自画的**更宽**横线；③ 草稿自画的**spinner 形状**行；
   ④ 框下方紧邻会话里的规则行（**不许**把框撑到会话文本上）；⑤ 光标在草稿**中间**（上下都有草稿行）。
3. **红/绿两侧**：现规格下上述 ① 必须**红**（框过小 → 读成 EMPTY 或漏内容）；改后**绿**（框正确、判 `BUSY`）；
   并且**反向**：真空框、真草稿、Pi 0.85.1/0.87 两布局**都不许**回退（用 P67/P74 已存的真帧）。
4. **与既有 requirement 的关系**：这是**改** `delivery-guard#An automated send never types into a non-empty input box`
   还是**加**一条？给出理由；**MODIFIED 不许丢任何 base scenario**（当前 13 条）。
5. **可证伪 + 复核方法**逐条写明；**不写实现**；与规格矛盾 → `BLOCKED:` 交回 PM。

## 背景（PM 说明，写入提案的 Context 即可）

P67/P74 刚把这个判据重做成"光标锚定 + 边框配对"，**这次只补下边框那一半**，
不重开 P67 已验收的部分（顶边框取最高、邻行按内容读、检查框内每一行）。
