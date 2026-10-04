# M71 · spec-backfill-2026-09 delta 修订：移除 boundary 三行（归 tmux-gate-grant-redesign）

agent: dev-bob   status: done   time: 2026-09-21T19:05:16Z
branch: `task/M71-delta-boundary-tmux-gate-gra`   PR/MR: -（local 模式：不 push，分支留在本地工作树，PM 复验后本地合并）

```
task:   M71
change: spec-backfill-2026-09   phase: apply（delta 文本修订；不改实现、不改别的 change）
commit: 1ed7fb0（修订）+ 08a2dcc（本报告）   base: 97ecfc1
```

## 1 · 交付清单（逐条对照任务书「要改的」）

| # | 任务书要求 | 落地 |
|---|---|---|
| 1 | `specs/boundary/spec.md` 整个文件移除 | `git rm`：原 124 行 / 3 requirement / 12 scenario 全删，`specs/boundary/` 目录消失 |
| 2 | `proposal.md` 六条规则改成五条 + boundary 行注明归属 | Why 的 "Six such rules" → "Five such rules" 并括注（the sixth, the tmux runtime gate, is owned by `tmux-gate-grant-redesign` — the same "already covered" treatment as item 6）；What Changes 里 boundary 的 ADDED 条目改成 **「`boundary` is covered — owned by `tmux-gate-grant-redesign`（与 item 6 同一处理方式）」**；Capabilities 列表、Boundaries、报告证据清单同步去 boundary/加覆盖核对 |
| 3 | `design.md` D1 表删 boundary 行加说明；Evidence map 删 1a/1b/1c（留 item 6 行）；D2 措辞不动 | D1 标题改「Homes: four delta files, no new capability」；表只剩 rule 2–6；正文加一段说明 rule 1 归 `tmux-gate-grant-redesign`（3 requirement / 14 scenario，post-M67 按目标判定模型）——与 item 6 同一「不写第二份」处置；证据地图删 3 行，item 6「已覆盖」行逐字保留（见 §4 逐字节证明） |
| 4 | `tasks.md` 删/改写 boundary 任务项 + PM 裁定说明 | 第 2 节（2.1–2.5）整体删除，原地换成 blockquote 裁定说明（**2026-09-21 · M70 review → M71**；理由 = 三条 requirement 归 `tmux-gate-grant-redesign`、M70 的 BLOCKED 由移除关闭、旧条目证据仍对该 change 有效）；第 7 节文件清单去掉 `boundary` |
| 5 | 其余 7 行一个字不动 | 逐字节 `diff` 证明 7/7 行与 tip 相同（§4-A）；其余 4 个 delta 文件 md5 与 tip 相同（§4-B） |
| 6 | 修订后 `openspec validate --all --strict` 必须绿 | `Totals: 18 passed, 0 failed (18 items)`，exit 0（§3） |

## 2 · 删了什么、为什么

- **M70 裁定**（`docs/team/reviews/M70.md`）：回填的 boundary 1a/1b 写的是 **M67 之前**的模型
  （`TEAM_ALLOW_DESTRUCTIVE_TMUX` 的 audited override、词汇表 `(refused, override, pass)`），
  而 tip 的真实行为是**按目标判定 + 四值词汇** `pass | allowed-owned | refused | explicit-flag`
  （证据：`skills/teamsmith/scripts/shim/tmux` L15–16「动作 审计词汇只有四个」；`smoke.sh` §31c）。
  **tip 行为正确，是 delta 文本错了。**
- **归属方已覆盖**：`openspec/changes/tmux-gate-grant-redesign/specs/boundary/spec.md` 实测
  `reqs=3 scenarios=14` —— R1 目标判定覆盖 1a、R2 日志 + 无授权覆盖 1b、R3「破坏性夹具绝不打真实
  默认 socket」（含容器泄漏形状）覆盖 1c。
- **处置 = 删除而不是改写**：改写成新模型仍会与 `tmux-gate-grant-redesign` 形成两份平行陈述，
  归档时必然漂移（M70 的 BLOCKED 就是预演）；与当年 item 6 完全同一口径「已覆盖，不再写第二份」。

被删文件 before 画像（`git show HEAD~1:…/specs/boundary/spec.md`）：

```
lines: 124
requirements: 3
scenarios: 12
TEAM_ALLOW_DESTRUCTIVE_TMUX occurrences: 3
stale action vocabulary: action (`refused`, `override` or `pass`)
```

修订后结构画像（HEAD）：

```
delta files: board-and-status / delivery-guard / panel / verification   （boundary 已不在）
requirements: 3 + 1 + 2 + 1 = 7
scenarios:    10 + 5 + 11 + 3 = 29  = 9 条 panel base 逐字复制 + 20 条新增
```

## 3 · 验收（任务书 Acceptance 原样跑）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
- Validating...
✓ spec/agent-adapters
✓ spec/board-and-status
✓ spec/boundary
✓ change/change-centric-discipline
✓ spec/delivery-guard
✓ spec/dispatch
✓ spec/init-skill
✓ spec/meeting
✓ spec/memory-and-deps
✓ spec/notify-and-inbox
✓ spec/panel
✓ change/perf-suite-split
✓ spec/pm-lifecycle
✓ change/settings-choice-editors
✓ change/spec-backfill-2026-09
✓ change/tmux-gate-grant-redesign
✓ spec/verification
✓ spec/watchdog
Totals: 18 passed, 0 failed (18 items)
exit=0

$ git status --porcelain
（空输出）
exit=0
```

## 4 · 漂移守卫与翻转证据

**A. 其余 7 行逐字节没动**（不是目测）：

```
$ diff <(git show HEAD:openspec/changes/spec-backfill-2026-09/design.md | grep -E '^\| (2|3|4a|4b|4c|5|6) \|') \
       <(grep -E '^\| (2|3|4a|4b|4c|5|6) \|' openspec/changes/spec-backfill-2026-09/design.md)
IDENTICAL (7/7 rows byte-for-byte)
```

**B. 其余 4 个 delta 文件与 tip 逐字节相同**（md5 对比）：

```
2d1
< f3dcd4ce1e0d15fe19c96c30d1cf8d66  openspec/changes/spec-backfill-2026-09/specs/boundary/spec.md
diff-exit=1     # 唯一差异就是被删的 boundary 文件
```

**C. 翻转证据（break → 守卫红 → restore → 绿）**：

```
guard() { test ! -e "$F" || 红（boundary delta is present）;
          deltas 里出现 'action (`refused`, `override` or `pass`)' → 红 }

=== flip 1: 把删掉的 delta 放回原位（break it） ===
  ✗ boundary delta is present
  ✗ stale gate vocabulary in the deltas
guard exit=1 (1 = red, as required)

=== flip 2: 恢复修订（heal it） ===
  ✓ guard green
guard exit=0 (0 = green)

$ git status --porcelain
（空 = 工作树回到已提交状态）
```

注意：`openspec validate --all --strict` 只查 delta 语法/库冲突，**不查**「delta 文本与 tip 行为是否
一致」，所以本任务的守卫是结构 + 词汇断言，行为证据由 M70 的实跑记录提供。

## 5 · 未按字面执行的两处（给 PM 的说明，逐处可回退）

1. **D2 的一个数字**：任务书说「D2 措辞不动」，但 D2 结论句是
   「this change writes **five** delta files, not six」——移除 boundary 后「五」变成假话。
   我只把 `five` 改成 `four`，该节论证与其余措辞逐字未动。
2. **design 里其余被 M71 改变的计数/词表**（按「逐处核对，不留断链」同步，非新增要求）：
   Goals「10 requirements, 32 new scenarios」→「7 requirements and 20 new scenarios（并注明 brief 的
   6–10 requirement 上界仍成立）」；Goals 第一条按六条审计规则各自的归宿重写；
   D4 删掉只属于 gate 的 token（`exit 64`/`TEAM_ALLOW_DESTRUCTIVE_TMUX=1`/`act=refused|override|pass`/
   `log bound 2000/1000`）；Non-Goals、Risks（container runtime、five deltas）、Migration Plan 责任句同步。
   proposal 的 Capabilities/Boundaries/Evidence 清单同理同步（见 §1 第 2 行）。
   这些改动都不在「其余 7 行」内，§4-A 已证明那 7 行逐字节未动。

## 6 · 给 PM 的 finding（不阻塞本任务；未越界修改）

- 🟡 `openspec/changes/tmux-gate-grant-redesign/tasks.md` §3.1 与 `design.md` D1（L74–75）仍写
  「spec-backfill 保留 container requirement（L106）、只移走两条 gate requirement」；M70/M71 把 1c 也
  移除了（R3 覆盖的是「夹具绝不瞄准真实默认 socket」，比「走容器」更准）。该 change 尚未归档，它
  §3.1 自己的校验口径（"the file's requirement list holds exactly one requirement"）已不成立 ——
  归档前需要其 owner/PM 改一行。我的 grant 只有 `spec-backfill-2026-09/**`，所以没动它。

## 7 · 交回 / 未覆盖

- 不 push（local 模式）、不归档、不改实现、不改别的 change。
- 未跑 smoke：M71 的 Acceptance 只有 validate + git status（文本修订任务）；行为证据沿用 M70 在 tip 上的
  实跑记录 —— 它 8 条 ✅ 里 7 条（2 / 3 / 4a / 4b / 4c / 5 / 6）留在本 change，1 条（1c）随 boundary
  归 `tmux-gate-grant-redesign`。
- 请 M70（dev2）对修订后的 delta 做针对性复核。
