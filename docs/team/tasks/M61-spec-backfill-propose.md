# M61 · 规格回填（2026-09）：把已落地的跨任务规则写进契约（propose）

```
task:   M61
agent:  dev-bob
issue:
change: spec-backfill-2026-09
specs:  -
phase:  propose
anchor: change
deltas: boundary, verification, delivery-guard, board-and-status, notify-and-inbox
deps:   -
status: todo
budget: 一个工作块（只出提案包：proposal / design / delta / tasks.md）
```

> 本地模式：不 push。**只 propose**，不写实现（本 change 的"实现"早已落地——见下）。

## 背景：为什么做这件事

用户已批准（2026-09-20「一：按照你的建议」）**spec 政策 B**：**跨任务规则**（静默失败 / 破坏性动作 / 越权 /
身份 / 门禁 / 性能契约）必须有 requirement + scenario。但过去一周硬化的六条规则**只活在测试与文档里**，
`openspec/specs` 里没有它们的家 —— 这正是我在 2026-09-20 指出的**规格漂移**：测试成了唯一真源。

本 change 的任务：**为已经落地的行为补写契约**（不是新功能）。**每一条都必须以仓库里已存在的实现/断言为依据**，
并在 delta 的 design 里指出**证据文件与行**（哪个测试段、哪个脚本函数）。

## 要回填的六条（每条都要满足：**现状即契约**，且可证伪）

| # | 已落地的规则（出处） | 建议归宿（可改，但要说明理由） |
|---|---|---|
| 1 | **tmux 隔离门禁**：私有 socket 解析必须复刻 tmux 的两个回退形态（`TMUX` > `TMUX_TMPDIR`；`TMUX_TMPDIR` 指向不存在的目录会静默回退默认 socket）；破坏性调用（`kill-server`/`kill-session`/`kill-window`/`kill-pane`）对默认 socket 被拦、私有 socket 放行、显式覆盖可授权且**有审计**；测试里的破坏性夹具必须走容器（M36/M41/M28） | `boundary`（越权/破坏性动作） |
| 2 | **冲突标记守卫**：任一被跟踪文件含冲突标记 → 门禁红（并报 file:line）（M44） | `verification`（门禁契约） |
| 3 | **pi 更新横幅容忍**：pi 的版本横幅出现在输入框附近时，空闲态仍判 `EMPTY`、真实草稿仍判 `HOLDS_ONLY=yes`、撤回仍 `RETRACT=ok`；**不得**通过关闭 pi 的更新检查来规避（M45） | `delivery-guard`（输入框判据） |
| 4 | **重复 ID 语义**：`board add` 对已存在的 ID 默认拒绝（点名现有行的状态与标题，给出 `--allow-dup` / `board assign` 两条出路）；`--allow-dup` 写审计行；`board ls`/digest/doctor 点名重复；`board assign <ID> <agent>` 只改 agent 列；**面板按"行身份"而非裸 ID 聚焦**（重复行各高亮各的，光标不冻结）（M48） | `board-and-status` |
| 5 | **读性能预算**：`board row` ≤1 次 git 调用、`digest` ≤50 次（实测 1708→37）；可选派生索引**必须**满足"索引 == 直接解析"的等价断言（不许变成第二真源）（M50） | `board-and-status` 或新能力（design 决定） |
| 6 | **投递降级可见**：watcher 注册失败要留耐久记录 + 账本行（errno / 配额用量 / 轮询间隔 / `forced` 标记），兜底轮询**在一个周期内**仍投递且**消息形状不变**，`doctor`/`status` 只认**存活**记录并给 inotify 额度与修法，门禁不可用前提**可见 SKIP**、严格模式判红（M53/M56 —— 注意：这一条**已经**在 `watch-degradation` 的 delta 里，归档后即为 spec；**你只需核对它是否已经覆盖，重复就不要再写**） | `notify-and-inbox`（若已覆盖 → 标为"已覆盖，不再添加"） |

## 硬要求

1. **不许写"理想行为"**：每条 requirement 的措辞必须是**现状可证伪的**；scenario 用 WHEN/THEN 写，
   并**点名证据**（例如"`tests/smoke.sh` §12j 段"、"`tests/panel-flip-m48.sh` F-A"）。
2. **不许复制粘贴测试文本**：requirement 是契约（what/why），不是测试清单（how）。
3. **`## REMOVED` 一律不要**；`## MODIFIED` 只在**确有必要**时用，且**不得删掉 base 的任何 scenario**（有则说明）。
4. **不要引入新能力**，除非第 5 条真的无处可放（design 里给出理由，并说明为什么不塞进 `board-and-status`）。
5. 每条回填都要能被**独立复核**：design 里给出"复核方法"（跑哪个脚本/看哪一段，期望什么）。
6. **规模控制**：6 条 → 预计 6–10 条 requirement、25–40 条 scenario；**不要膨胀**。

## Deliverables

- `openspec/changes/spec-backfill-2026-09/{proposal.md,design.md,tasks.md}`
- 各归宿 capability 的 delta（`openspec/changes/spec-backfill-2026-09/specs/<cap>/spec.md`）
- 报告 `docs/team/reports/M61-dev-bob.md`（含"每条 → 证据文件:行 → 复核方法"的对照表）

## Acceptance

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
git status --porcelain
```

## Boundaries

- 只 propose：不改 `scripts/**`、`tests/**`、`extension/**`、`references/**`。
- **不要**顺手改行为；发现"实现与文档不一致" → 在报告里写 `BLOCKED:` 或 finding，交回 PM，**不要**自行改代码。
