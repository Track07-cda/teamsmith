# P216 · 账本禁令的**日志遮蔽**会泄漏（混合形状只遮第一类；同类超过 20 个剩下的漏出）

```
task:   P216
agent:  dev2
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 修 P212 的遮蔽实现与其自检
deltas: -
grant:  skills/teamsmith/tests/ledger-ban.sh · skills/teamsmith/tests/smoke.sh · skills/teamsmith/references/** · docs/team/reports/P216-dev2.md · docs/team/reports/P216-dev2/**
deps:   P212 已并入 main（`e6ca8ef6`）；**换人复验 P215（verify）先发现了它**；PM 也独立复现了下面两条
status: todo
budget: 小
priority: 高（这条改动**自己的承诺**是"输出里的敏感 token 一律换成占位符，日志可以安全地贴"；现在不成立）
```

## 现场（PM 用 P212 的实现自己跑的，探针两行）

```
docs/team/probe.md:2: [home] 混合：家目录 <home>/secret 与地址 192.168.7.9 以及名字 acme-corp
docs/team/probe.md:3: [net] 超量<internal<internal<internal<internal<internal<internal<internal<internal<internal<internal<internal<internal<inter…
```

- **F1 · 混合形状只遮第一类**：第 2 行同时有家目录、内网地址、名单里的名字，输出**只遮了家目录** —— 地址 `192.168.7.9` 与 `acme-corp` **原样进日志**（主循环 `match(home_re)` 命中后直接 `continue`）。
- **F2 · 同类超过 20 个剩下的漏出，且输出被自己搅乱**：第 3 行 25 个地址，`mask_span` 的 `g < 20` 上限导致其余未遮，且替换文本被**二次扫描**（`<internal<internal…` 这种拼接说明它在改写自己的输出）。

## 要做的

1. **遮蔽必须覆盖被报那一行里的全部形状、全部出现**：不许有每行上限；若为体积要截断，用**显式标记**（如 `…(截断)`）截断，**绝不允许**把原文留下。
2. **替换不得自我重扫**：改成一次遍历里按位置拼接（先算出所有命中区间，再一次性生成掩码后的行），红侧要能证明"掩码串不会再被匹配"。
3. **可证伪（四条，全部要有红侧）**：
   - ① 一行同时含 家目录 + 内网地址 + 名单名字 → 输出里**三种原文都不出现**；
   - ② 一行 25 个同类 → 输出里**一个原文都不出现**、且输出不是拼接垃圾；
   - ③ 影子：把遮蔽关掉 → ①② 的"输出无原文"断言必须**红**；
   - ④ 自检里要有"**输出无原文**"这条断言本身（现在自检只查了单类单处的情形，所以没抓住）。
4. **不许削弱检测能力**：命中数、点名 `file:line`、退出码（0/3/1/2/4）语义不变；**已提交账本在 main 上仍须 rc=0**（改动前先记一遍基线）。
5. **门禁**：`openspec validate --all --strict` + 容器内 `--select 60` + 自检；报告点名"哪些自己跑、哪些引用 P215"；**换人复验**（verify 已验过一版，返工后再换一次）。
