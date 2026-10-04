# P212 · 账本禁令检查进 FAST 门禁（D94 的机制）

```
task:   P212
agent:  <空出的席位>
issue:
change: -
specs:  -
phase:  apply
anchor: none (infra) — 门禁里新增一段检查
deltas: -
grant:  skills/teamsmith/tests/** · skills/teamsmith/references/** · docs/team/reports/P212-<agent>.md · docs/team/reports/P212-<agent>/**
deps:   **D94**（账本可读层进仓库 ✓ → 任务书与复验记录"写下去即公开" ✗ 没有发布前遮蔽网 ✗）→ 禁令必须成为门禁检查
status: todo
budget: 小到中
priority: 中高（它是"账本进仓库"这个决定的**唯一兜底**）
```

## 要做的

1. **检查**：扫描仓库内的账本文本（`docs/team/**/*.md`），命中以下形状即**报红并点名文件+行号**：
   绝对家目录（`/home/<任意用户>` 正则）、私有网段（`192.168.` / `10.` / `172.16-31.`）、**本机用户名**（运行时从 `$USER`/`id -un` 取，不写字面量）。
2. **他项目名**：**不许把名字写进仓库** —— 名单从**被忽略**的配置文件读（如 `.pi/team/forbidden-names.txt`，一行一个）；
   名单不存在时**可见跳过**并写明原因（"禁令名单未配置"），**不许**当成通过。
3. **可证伪（四条）**：① 植入一个家目录路径 → 红并点名；② 植入一个他项目名（名单里有的）→ 红并点名；
   ③ 名单缺失 → 可见跳过（不是绿）；④ 影子：把扫描改成"永远通过" → ①②必须红。
4. **不误伤**：`<home>` / `<peer>` 这类**占位符**必须放行；`docs/team/**` 之外的文本（例如规范里对用户项目的说明）不在本检查范围。
5. **门禁**：`openspec validate --all --strict` + 容器内 FAST + 报告点名；**复验换人**。
