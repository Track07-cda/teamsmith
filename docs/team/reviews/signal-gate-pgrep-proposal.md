# `signal-gate-pgrep` · 提案评审（P164）— PM 判定

time: 2026-10-02T13:0xZ · reviewer: pm · verdict: **ACCEPTED**（附一条**归档顺序依赖**，已实测）

```
change: signal-gate-pgrep（propose=verify ✓ · apply=待派 ✓ —— 与 P159 同一 delta `boundary` ✗，见下）
branch: task/P164-propose · tip ba19e08a · validate 21/0 ✓
```

## 我核过的（机械 + 自测）

| 项 | 我的做法 | 结果 |
|---|---|---|
| 清点 | 我自己 grep 脚本与夹具里的 `pgrep`/`pidof` 实调 | **四处 / 三个文件** ✓ 与它的表**逐条一致** ✓（`common.sh:1507` `-g` ✓、`panel-cpu.sh:285/340` `-P` ✓、`smoke.sh:8095` `-fc` ✓） |
| 取舍 | 读它的三个方案与代价 | **A（窄规则 + 只计数例外）** ✓ 推荐合理 ✓；它抓到我没想到的坑：**一刀禁 `-f` 会打断 FAST 那条计数断言** ✓✓ |
| 允许形态 | 读它给的语法 | 两个正标量 ID（`-g N`/`-P N` ✓）、三个整命令计数形态 ✓、四个只读信息 token ✓ —— **逐形态给了理由** ✓ |
| `pidof` | — | 按名字选择 → **一律不许** ✓（与"名字不是身份"一致 ✓） |
| 基线不丢 | 我的脚本比对 MODIFIED | 场景 0→15 ✓ 丢失 0 ✓（该 requirement 现在只在 **P159 的未归档 delta** 里 ✓ —— 见下） |
| 归档顺序 | **我在 scratch 副本里实测两种顺序** ✓ | 先归档 `safe-signal-discipline` → validate 20/0 ✓ 该 requirement 进基线 ✓；**先归档本 change → 工具报错并中止** ✓（`boundary MODIFIED failed for header … not found` ✓ 且**没改任何文件** ✓） |

## 判定与要求

**ACCEPTED** ✓ —— 判据、取舍、边界都成立 ✓。

**一条依赖（D40/D42 的形状，已实测）**：本 change 的 `MODIFIED` 指向的 requirement 目前**只存在于 `safe-signal-discipline` 的未归档 delta 里** ✗ →
**必须先归档 `safe-signal-discipline`** ✓（它的归档前置是 **P166** 的独立验证 ✓），然后本 change 的 delta 要**在归档后的基线上重写** ✓（必要时做 scratch 预演 ✓）。
这条写进 **P167**（apply 任务书）的 `deps:` ✓ —— 顺序反了会被工具**当场拒绝** ✓（不会静默写坏 ✓）。
