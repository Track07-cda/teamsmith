# P72 · 手工 `team notify` 把发送者记成 `pm`（审计面）

```
task:   P72
agent:  （等席位）
issue:
change: notify-sender-identity
specs:  -
phase:  propose
anchor: change
deltas: notify-and-inbox
deps:   M40（身份 = 运行时目录，cwd-first）· D36（派单守卫用的是同一套身份解析）
status: todo（待派）
budget: 小
```

> 本地模式：不 push。**先 propose。**

## 现场（PM 实测）

PM 的收件箱里 **55 行**标着 `[manual] agent:pm · …`，但那些活是**worker**干的，例如：

```
[manual] agent:pm · P61 DONE（verify，…）      ← 实际是 dev3 干的
[manual] agent:pm · P60 verify FAIL: --lint …  ← 实际是 verify 席位干的
[manual] agent:pm · P45 交付完成（…）           ← 实际是 dev2
[manual] agent:pm · P52 追加完成（…）           ← 实际是 dev2
[manual] agent:pm · P62 提示（…）               ← 实际是 dev-bob
```

而 **扩展的自动回合通知**（`[auto]`）sender 是**对的**：`[auto] agent:dev2 · P52 · branch=…` ✓。

同时（PM 实测 `/proc/<pid>/environ`）：三个 worker 的 `TEAM_AGENT` **都是空**，`TEAM_ROOT` 指向**各自 worktree** ✓。

## 要裁决的

1. **手工 `team notify` 的 sender 解析**：当 `TEAM_AGENT` 为空时，它**不得**默认成 `pm`；
   应按 **M40 的规则**（运行时目录/worktree）解析，或在解析不出时**明确拒绝**并要求 `--from`，
   或从 pane/session 名（`teamsmith:<agent>`）解析——**给出取舍**。
2. **审计后果要写清**：收件箱/账本里"谁报的"必须可追溯（现在读起来像 PM 自己报的，
   与 `docs/team/reports/**` 的作者矛盾）。
3. **一致性**：`[auto]` 与 `[manual]` 两条路必须用**同一个** sender 解析（别一个对一个错）。
4. **可证伪**：夹具里 worker 环境（`TEAM_AGENT` 空 + worktree cwd）跑 `team notify pm --from-file …` →
   收件箱行必须是 `agent:<worker>`（当前是 `agent:pm` → 红）；PM 自己跑 → 仍记 `pm`。

## 硬要求

- policy B：delta 落 `notify-and-inbox`（"谁发的"是可机读的事实）；可证伪 + 复核方法；
- **不写实现**；矛盾 → `BLOCKED:` 交回 PM。
