# P120 · §36⑦ 的两条绿侧夹具在深 caller TMPDIR 下环境假红（与 P115 同族）

```
task:   P120
agent:  dev-bob   # P115 的作者（同一族口径）
issue:
change: -                        # 无 change：夹具的环境敏感性（anchor: none (infra)）
specs:  -
phase:  apply
anchor: none (infra) — 只改 §36 的夹具判定，不改选段器/账本/裁决语义
deltas: -
grant:  skills/teamsmith/tests/smoke.sh（仅 §36 内）· skills/teamsmith/tests/**（夹具）· docs/team/reports/P120-dev-bob.md · docs/team/reports/P120-dev-bob/**
deps:   P119（独立复验的 §2.8 发现）· P115（§36③/④ 的同一口径：状态判定 + 可见 SKIP + 归因）
status: todo
budget: 小
priority: 中（假红会污染复验者；与 P115 同类）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。**验证对象 = main 上已合并的实现**（`gate-runtime-budget` 已归档 ✓）。

## 现场（P119 的 §2.8，我已核过它的证据）

**深 caller TMPDIR** 下，§36⑦ 的两条**绿侧**夹具**环境假红** ✗（默认 TMPDIR **不触发** ✓）。
机制与 **P115** 已修的 §36③/④ 同族 ✓（深 TMPDIR → 私有 tmux socket 路径超 AF_UNIX 上限 → 隔离失效 → 前置条件不成立 ✗）。

## 要做（照 P115 的口径，别自创）

1. **先复现**：用**深 TMPDIR**（≥60 字符 ✓）跑 §36，把那两条的红抓出来 ✓；报告里写清**触发路径**（哪一段的私有 socket 路径超限 ✓）；
2. **按 D33/P62 修**：前置条件起不来时 → **可见 SKIP + 归因**（点名"深 caller TMPDIR 导致私有 socket 不可用" ✓），
   **不许**靠墙钟/sleep 判定 ✗；**语义不许放松**（那两条绿侧所断言的**承诺**在正常环境下必须照旧成立 ✓）；
3. **红侧**：给"真红"造一个方向（例如让绿侧断言的**实质**坏掉 ✓）→ 必须**照旧红** ✓；
4. **不许**碰 FAST 守卫本身 ✓、不改选段器/账本 ✓；
5. 证据：深 TMPDIR 与默认 TMPDIR **两个方向**各一次（原始输出 ✓）+ **FAST 全绿** + `openspec validate --all --strict` ✓。
