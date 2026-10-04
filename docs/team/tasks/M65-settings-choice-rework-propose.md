# M65 · 设置选择重做：先测延迟根因，再改交互契约（propose 修订）

```
task:   M65
agent:  dev2
issue:
change: settings-choice-editors      # 同一 change（未归档；用户打回要求重做交互）——修订其 proposal/design/delta
specs:  panel#The console offers the schema's choice set wherever there is one, and degrades visibly / panel#The console writes a project setting only through team config set, after validation / memory-and-deps#The machine read reports each key's choice set, and the schema is its only source
phase:  propose
anchor: change
deltas: panel
deps:   M55（apply 已合并 78fc880）· M60（verify PASS 7433768——针对旧交互；重做后须重新 verify）
status: todo
budget: 一个工作块（测量 + 提案修订；不写实现）
```

> 本地模式：不 push。**只测量 + 修订提案包，不改实现。**

## 用户的决定（2026-09-21，原话要点）

> 「设置选择可以这样做」——批准我提的方案：
> ① **先测延迟根因**（用户体感：打开单个配置的选择/输入页有延迟，确认也有延迟）；
> ② **从选项里选中（Enter/点击）→ 直接写入配置，不要二次确认**（校验 + CAS 指纹 + 审计行保留）；
> ③ **只有选「其他」（自由输入）才走手动输入那一步**（校验 + 确认保留）；
> ④ **危险值例外**：命中危险清单的值即使来自选项也保留一次确认（安全线，不动）。

## 要做的两件事

### 1. 测量（先于设计，design 必须带原始数字）

对现有实现（main 上的合并版）做 pty 打点，三段分别计时，每段至少 5 次采样给中位数：

- **打开**：从设置视图选中一个 enum 键 → 选择器**首帧完整渲染**（标题 + 条目都可见）；
- **移动**：选择器内一次 ↑/↓ → 帧稳定；
- **写入**：确认 → `team config set` 完成 → 回执帧。

并定位瓶颈属于哪一类（**视图构造**（108 个键一次性构图）/ **每次按键全量重渲染** / **写入路径同步起子进程**
（每次 `team` 调用有固定开销）/ 其他）。设计要据此给出修法；若瓶颈在**整个设置视图**而不只是选择器，
如实写（修订范围跟着证据走，但 delta 仍只动 `panel`）。

### 2. 修订提案包（同一 change，不新建）

- `proposal.md`：加入交互重做（直写 + 「其他」例外 + 危险值例外）与响应性目标；
- `design.md`：测量数据 + 瓶颈定位 + 修法选型（候选：缓存/增量构图、选择器独立渲染、写入异步化+回执帧等——
  **由数据决定**，并说明为什么不是别的）；
- `specs/panel/spec.md` 的 delta **修订**：直写交互的 scenario（选中即写、无第二确认帧；「其他」进输入框；
  危险值仍确认；写入失败/指纹冲突的回执形状）；响应性写成**行为契约**（例如"按键到帧稳定不得跨过一个
  帧节拍"，而不是墙钟数字——性能红线不进正确性门禁，D33）；
- `tasks.md`：追加 apply/verify 任务项（含翻转）。

## 硬要求

- 测量必须**真实可复跑**：打点脚本落 `docs/team/reports/M65-dev2/`（证据目录），design 里贴原始数字；
- 不许把"体感"写成契约；契约写行为不变量，性能测量走 `tests/perf.sh` 的形态（可见 SKIP、exit 0/2/3/4）；
- MODIFIED 不得删 base 的任何 scenario；delta 只动 `panel`（`memory-and-deps` 不动——schema 读取侧没变）；
- 不动实现（`scripts/**`、`extension/**`、`tests/**`）；发现实现与文档矛盾 → `BLOCKED:` 交回 PM。

## Deliverables

- `openspec/changes/settings-choice-editors/{proposal.md,design.md,tasks.md}` 的修订 + `specs/panel/spec.md` delta 修订
- 报告 `docs/team/reports/M65-dev2.md`（三段计时原始数据 + 瓶颈定位 + 修订了什么）

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```
