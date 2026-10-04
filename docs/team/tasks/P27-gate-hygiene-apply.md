# P27 · 门禁资源纪律（apply）

```
task:   P27
agent:  verify
issue:
change: gate-hygiene                   # 提案已验收并合并：docs/team/reviews/gate-hygiene-proposal.md
specs:  verification#The hard timeout covers the gate run, not the queue / panel#Frame assembly is asynchronous, cached and never blocks input
phase:  apply
anchor: change
deltas: openspec/changes/gate-hygiene/specs/verification/spec.md
deps:   P26（propose，已合并）
status: todo
budget: 分批 G1…G4；做不完交 PARTIAL + 已完成批次清单
```

> 本地模式：不 push；分支留在 `.worktrees/verify`。

## 计划就是 change 自己的 tasks.md

**唯一实施计划**：`openspec/changes/gate-hygiene/tasks.md` 的 **G1…G4**（每批的验收、夹具、翻转都在那里）。
本任务书只补边界、两条 PM 审查要点与碰撞协议。

## PM 审查时点出的两条（必须当成硬要求）

1. **记录词汇闭集不许动**：`PASS|FAIL|TIMEOUT` 仍是全部判定；排队超限走 **FAIL 并点名持锁者**，真超时才 `TIMEOUT`；
   `ran=…/queued=…` 写在粗体 token **之外**（`team_review_verdict` 的正则按 `**TOKEN**` 解析，别让它误判）。
   请用一个**显式断言**证明：新记录格式下 `team_review_verdict` 仍解析出正确的判定（三种结局各一条夹具）。
2. **夹具旋钮不能成为真路径后门**：`TEAM_SMOKE_LOADAVG` / `TEAM_SMOKE_FRAME_DELAY_MS` 这类注入**只能在夹具里生效**，
   真实门禁路径下必须被忽略（或视同未设）。给出断言：真路径下（未显式打开夹具开关）这两个键**不改变判定**。
   否则"负载前提"会退化成"想跳就跳"，这条我会在复验里单独验。

## 碰撞纪律（现在有三个在飞任务会动 `tests/smoke.sh`）

- `tests/smoke.sh`：**只追加自己的段落**，不要重排他人段落；与 M48/M50 的新段落在同一区时**两侧都留**并在报告点名。
- 不要改 digest 的读取路径（M50 正在重写它）；不要改 `panel/src/**`（M49 已合并、M48 在动面板聚焦）——
  本 change 只碰 `panel-cpu.sh` 与 smoke 里 27-d/26-m 的判定。
- `panel.js` 未改则**不要**重建。

## Boundaries

- 不放宽任何红线（首帧 2s、CPU 1% 维持不变）；**不做复验插队**；锁路径/上限沿用现有键。
- 不改 `docs/team/DECISIONS.md`；不改在飞任务的 brief；不改 `openspec/changes/console-*` 或已归档的 change。
- 所有"跳过"必须**可见**（打印实测值与 load），任何静默 skip 视为交付失败。

## Acceptance (真跑，贴原始输出)

```sh
PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null
TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh
```
外加**手工实录**（按 tasks.md 的翻转清单）：
① 锁被占 3 秒 + `TEAM_REVIEW_TIMEOUT=5` → 记录写 `queued≈3s / ran≈2s` 且**判 PASS**（改造前会 TIMEOUT）；
② `TEAM_SMOKE_LOCK_WAIT=1` + 锁被占住 → **FAIL 并点名持锁者**；③ 真跑超上限 → `TIMEOUT`（语义不变）；
④ `TEAM_SMOKE_LOADAVG=26`（夹具）→ 27-d 打印 SKIP 与 load，且 `panel-cpu.sh` exit **4**；
⑤ 低负载 + 注入慢帧 → 仍判**红**（前提不成立时必须还能红）。

## Report

`docs/team/reports/P27-verify.md`：per requirement 覆盖表 + 每批翻转（红→绿）+ 独立包路径 + 两条 PM 要点的专属证据。
