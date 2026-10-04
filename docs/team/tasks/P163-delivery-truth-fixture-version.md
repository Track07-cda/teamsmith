# P163 · `delivery-truth` 的两条 finding：配方重置现场 + 钉版本与 1.0.0 真帧用例

```
task:   P163
agent:  dev-bob
issue:
change: delivery-truth
specs:  delivery-guard#Queue impediments are factual, bounded and recoverable
phase:  apply
anchor: change
deltas: delivery-guard
grant:  skills/teamsmith/tests/** · skills/teamsmith/tests/fixtures/** · docs/team/reports/P163-<agent>.md · docs/team/reports/P163-<agent>/**
deps:   独立验证 `docs/team/reports/P157-verify.md`（两条 finding + 证据 ✓）· 评审 `docs/team/reviews/P157.md`（PM 读了真帧 ✓）· **PM 的现场判断**：1.0.0 的红是夹具自造框内行（`fatal: no upstream …`）→ 产品"扣住 + 可见报告"是对的 ✓
status: wip
budget: 小到中
priority: 高（**归档前必须落地** ✓；且它把"未知布局/框内有异物"的产品行为钉成断言 ✓）
```

## 两条（各自带红侧）

### F1 · 配方必须**重置现场** ✅
`run-case.sh` 保留已有 case 目录 ✓ → `scenario.sh` 追加事件 ✓ → 判据跨次累积 ✓（PM 实测 1→2→3→4 ✓，独立验证复核 ✓）。
要求：每次运行**清空该 case 的现场目录** ✓（或写进**新的**带时间戳的目录 ✓，并在判据里只读本次 ✓）；
**红侧**：连跑两次 → 两次的 `second_received` **必须都是 1** ✓（不是 2 ✓）；反向：故意保留旧现场 → 判据必须**明确报错或忽略**，不许把两次算成一条 ✓。

### F2 · 钉版本 + 1.0.0 真帧用例 ✅
① 配方里写明它判定的 Pi 版本 ✓（容器 0.99.2 ✓），并注明**宿主路线（当前 1.0.0）仅供人工观察** ✓、不作为判据 ✓；
② 把 **1.0.0 的真帧**（验证者已存：`P157-verify/logs/tmux-p157-after-dirty/*.frame` ✓）**收进夹具** ✓ →
断言：框内有一行**非人类文本**（夹具自造的 git 错误行 ✓）时，产品必须**扣住**（held ✓）、**可见地报告**（原因/恢复命令 ✓）、
且**绝不**把消息打进框里 ✗；同时断言"**不是丢失**"（消息仍在队列/账本 ✓）。
③ **红侧**：把判据 shadow 回"见到框内有东西就当草稿静默吞掉" ✗ → 上面"可见报告"那条必须**红** ✓。

## 门禁

`openspec validate --all --strict` ✓ + `--select 57` ✓ + FAST ✓；报告点名"哪些自己跑、哪些引用 P157" ✓；
**验证换人** ✓（写的人不验自己 ✓）。
