# P45 · change-centric-discipline B2：digest 的 change 归组 + 面板的 change 任务 token（apply）

```
task:   P45
agent:  dev2（**不得派给 verify 席位**）
issue:
change: change-centric-discipline
specs:  board-and-status#A change's tasks are grouped in the digest  / panel#…（以 change 的 delta 为准）
phase:  apply
anchor: change
deltas: board-and-status
grant:  scripts/lib/cmd-status.sh · scripts/lib/cmd-watch.sh · scripts/panel/src/**（layout/App/types/strings）· scripts/panel/panel.js（build 重建）· tests/smoke.sh（append-only，新段 12f）
deps:   P23（propose，已合并）· P24（apply 的其余部分，已合并；B2 当时为避免冲突推迟）· M50/M48/M49（与它冲突的都已落地）
status: todo（等席位）
budget: 一个工作块
```

> 本地模式：不 push。**真源 = `openspec/changes/change-centric-discipline/tasks.md` §2（2.1/2.2/2.3 及后续项）
> 与 `design.md` §7**——按它们做，不要凭本简述发挥。

## 硬要求

1. **digest 的新段不重编号**：`[1]`–`[5]` 的段头**逐字节不变**（有断言）；新段是 `[6] change 归组`，
   每个未归档 change 一行（有界行宽）、带任务 token 与 readiness 标记；"没有任务指向它"与"任务指向不存在的
   目录"两个标记；无事时是一条 dim 空行；
2. **面板**：`team_panel_changes_json` 每个 change 带 `tasks` 数组（id/phase/board/verdict，**至多 8 个 token**），
   同进程内用 `team_change_tasks`/`team_board_status`/`team_review_verdict` 组装；控制台在 change 行下渲染
   token 行，**宽度不够时整行丢弃而不是重排布局**；
3. **新 smoke 段 `12f · change 归组（P23/B2）`**：fixture 的 digest 带 `[6]` 行、token 与
   `team change status alpha` 一致；两个标记各一条；`--json`/snapshot 断言；
4. **不许回退**：M50 的读成本预算（`board row` ≤1 git 调用、digest ≤50）、M48 的重复 ID 可见性与行身份焦点、
   M49 的按键 i18n、P30/P32 的设置视图（分组/高度/滚轮）——**一个字不动**；
5. 小步提交；每批 FAST 绿；交付前全量一次（并把 digest 的**耗时**报出来：它现在跑在预算内）。

## 必给的翻转（红→绿原始输出）

- 把 `[6]` 段里的 readiness 标记去掉 → 12f 断言红；
- 把 token 上限从 8 改成无界（或 99）→ 有界性断言红；
- 面板 token 行改成"宽度不够也渲染"→ 布局断言红；
- 还原后 `git status --porcelain` 干净、bundle 两次构建字节一致。

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
bash skills/teamsmith/tests/smoke.sh </dev/null
```

## Boundaries

- 只碰 `grant:` 列出的路径；
- **不改** change 的 delta 文本（B2 的 requirement 已在 P23 里写定；如果实现与它矛盾 → `BLOCKED:` 交回 PM）；
- 不 push；不改 `docs/team/**`。

## Deliverables

- 实现 + 四条翻转 + 报告 `docs/team/reports/P45-<agent>.md`（含 digest 四个段头的字节比对、12f 的结果行、
  以及 digest 的耗时读数）。

## 追加（PM，2026-09-22 15:xx）

- **与在飞任务的避让**：P55（dev）正在改 `cmd-status.sh` 的**文件末尾**（roster/status/doctor 行）——
  你的 `[6]` 段与面板读取照 tasks.md 放在**各自应有的位置**，别为了避让改结构；冲突由 PM 解决。
- **验收**：`PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict`；`TEAM_SMOKE_FAST=1 … smoke.sh`；
  新段 `12f` 单独跑一次；翻转按 2.4（scratch 副本里**只去掉面板读取的归组**，digest 侧保留 → 面板断言必须红）。
