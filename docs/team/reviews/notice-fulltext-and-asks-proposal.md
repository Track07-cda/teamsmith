# 提案审查 · notice-fulltext-and-asks

- 判定: **ACCEPTED**
- change: `notice-fulltext-and-asks` · author: dev-bob（P369）· PM: pm
- 受检: `cc47277385`（`f2eff762` + `cc472773`），报告 `docs/team/reports/P369-dev-bob.md`

## 一 · 我复跑了它的结构性主张，成立，但要改一句措辞

它的理由是「两个未归档 change 各写一条 MODIFIED 改同一标题，先后两次归档会静默丢文本」。我在一份私有克隆里
造了那个形状（两个 change、同一标题、各自一句散文、**原有场景一个不少**）：

```
归档 zz-a → A 的散文 1 处
归档 zz-b → A 的散文 0 处、B 的散文 1 处      ← 静默丢失，无任何报错
```

**但「没有任何工具会报」不准确**：`openspec archive` 会拒绝对「会丢掉当前规格里已有场景」的 MODIFIED 块
（我第一版实验就被它拦了，报错逐条点名四个场景）。所以静默的部分**只限散文**，场景丢失是被拦住的。
这个区别要写进 proposal 的理由段——理由走样比结论错更危险，后来的人会照它做决定。

## 二 · append-only 我确认采纳

理由充分且可复现：`turn-notice-in-pm-inbox` 至今未归档，它的 delta 里有 `MODIFIED` 改的正是
`A turn-end notification appends one inbox line and knocks once`（我核了：`specs/notify-and-inbox/spec.md:5-7`）。
两个 pending change 各写一条 MODIFIED = 把归档顺序交给人的记忆。**只 ADDED 两条**把「wake 的 preview 语义不变」
从承诺变成构造上不可能被碰。

代价我接受：规格里会看到两条相关但独立的条目。这份代价比「静默替换别人的规格」便宜得多。

## 三 · 内容核对

`## ADDED Requirements` 两条（`The record keeps the whole message…` / `A completion whose tail asks for a decision
is countable`），14 个场景，各都能失败（我看过 `truncated=preview:<shown>/<total>B full=<path>`、
硬上限 `truncated=hard-limit:65536/<原文>B` **不带 `full=`** 这个「原文不存在」的唯一记号、`asks` 的闭集
22 中文 + 7 英文、末尾 400 字窗口）。`openspec validate --all --strict` 23/0，`spec-refs --check` undeclared 0。

**无阻塞项。** 一条要求：apply 时把那句措辞改准（场景被拦、散文静默），并把我的复现命令写进 design 的理由段。
