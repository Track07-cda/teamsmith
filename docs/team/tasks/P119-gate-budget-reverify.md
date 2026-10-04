# P119 · `gate-runtime-budget` 复验（P117 返工后 · 换人）

```
task:   P119
agent:  verify
issue:
change: gate-runtime-budget        # 已在 main（apply=P98 dev3 · 返工=P117 dev）——你不是其中任何一位
specs:  verification#（路径选段 / 选段运行自述）
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P119-verify.md · docs/team/reports/P119-verify/**（只写报告与证据）
deps:   P112（独立验证：V1 严重 / V2 实质）· P117（返工，已合并）· `section-select.sh --out` · `section-needs-audit.sh`
status: todo
budget: 一个验证包
priority: 中（归档前最后一道门）
```

> 本地模式：不 push。**验证对象 = main 上已合并的实现**。**CI 不再作为判据**（D54）。

## 必须自己动手（这些都来自 P112 的原现场）

1. **副本可解析（V1 的核心）**：**你自己写循环**——把 `--list` 的**每一个键**都生成一次副本并 `bash -n`
   （**不要**只跑作者的 `section-needs-audit.sh` ✗）；再单独验**三个常用入口**：
   `--paths skills/teamsmith/scripts/team` · `lib/cmd-agents.sh` · `tests/smoke.sh` ✓；
2. **失败必须早**：在 scratch 里造一个"副本无法解析"的形状（影子掉剪贴器的 `bash -n` 裁判 ✓）→
   选段**必须在跑任何段之前**拒绝并**点名原因** ✓（**不许**"跑完再 exit 2"✗）——这是要保留的**红侧** ✓；
3. **原现场端到端**：`--select 14` 与 `--select 14c` 两个方向都要**跑出结果行**（修前一个丢 `fi`、一个孤立 `fi` ✗）；
4. **`needs` 闭包（V2）**：你自己挑 **≥3 个**夹具依赖键（至少含 `3b` 与 `6` ✓）→ 选集**0 红**；
   **红侧**：scratch 里删掉一条 `needs` → 那个键的选集**必须变红** ✓；
5. **语义不许放松**：选中的段真的跑 ✓、`这次没跑的段` 仍点名 ✓、账本自查仍成立 ✓、
   **FAST 守卫本身未动**（`14c` 仍归 FAST 管 ✓）；
6. **零回归**：`openspec validate --all --strict` + `routes.sh` + `config-cli.sh` + **FAST 全绿**（+ 一次全量，若你判断必要）；
7. 报告写清"哪些是你自己的证据、哪些是引用"，附**红/绿原始输出**；**不改实现**（要改 → `BLOCKED:` 交回 PM ✓）。
