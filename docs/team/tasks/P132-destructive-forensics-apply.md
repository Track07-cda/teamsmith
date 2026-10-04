# P132 · `destructive-call-forensics` apply：破坏性调用记录**长保留**

```
task:   P132
agent:  dev2                     # 提案人 dev3 ✓（换人 ✓）
issue:
change: destructive-call-forensics      # 提案已验收并合入 main ✓
specs:  boundary#A destructive call's record outlives the call log's rotation
phase:  apply
anchor: change
deltas: -                        # delta 由提案写好（**apply 不写 delta** —— P99 的教训 ✓）
grant:  skills/teamsmith/scripts/shim/**（闸门 shim ✓）· skills/teamsmith/scripts/lib/common.sh（**只许**改与审计日志/轮转/长保留/导出相关的块 ✓ 其它一切不动 ✓）· skills/teamsmith/tests/**（夹具 + 可 append 一段 smoke ✓）· docs/team/reports/P132-dev2.md · docs/team/reports/P132-dev2/**
deps:   M67/D36（闸门**判定**语义 ✓ 不许改 ✗）· `docs/team/reviews/P131.md`（验收记录 ✓）· `state/tmux-calls.log` 现有契约（**有界 ✓ + 首行 `dropped=N` 自述 ✓ + 解析器不变 ✓**）
status: todo
budget: 一个工作块
priority: 中高（用户选 3A ✓；两次"破坏性记录被挤掉"的实证 ✓）
```

> 本地模式：不 push。**CI 不再作为判据**（D54）。
> **安全铁律（D37/D57/记忆 #1794）**：**绝不**对真默认 socket 做任何破坏性调用 ✗；夹具用**私有 socket** 或 `tests/container-tmux.sh` ✓；不碰 `default` ✓。

## 要实现的（照 delta ✓，四条都要**可证伪**）

1. **`act≠pass` 与 `pass` 分开** ✓：破坏性记录（`act=refused|allowed-owned|explicit-flag|override`，**以现有闭集为准** ✓）进**长保留**文件 ✓；`pass` **不承诺**保留 ✓。
2. **保留文件有界** ✓ 且**自述轮转** ✓（沿用主日志那条"读不到 ≠ 没发生"的形 ✓：轮转后要能看出**被截掉多少** ✓）。
3. **写入失败可见** ✓ 且**不阻塞**调用 ✓（写不进要有一行可见的失败 ✓，但**不许**因此改掉闸门的判定/退出码 ✗）。
4. **主日志契约不变** ✓：仍有界 ✓、首行仍是 `dropped=N` ✓ 标记形状不变 ✓（不要让带 `*` 的 glob 吃到调用行 ✗ —— 现有 shim 已有严格切分 ✓ 沿用 ✓）。

## 还要做（提案里那条涟漪 ✓）

5. **`12b-j` 的排除**：新保留文件必须按**精确路径**排除 ✓（**不是**按文件名/前缀 ✗）—— 并且**反例**：
   把排除放宽成"任意同名文件" → 该断言必须**红** ✓。

## 证据

- **灌满主日志**（> 2000 条调用行 ✓ 混合 `pass` 与破坏性 ✓）→ 破坏性记录**仍在保留文件里** ✓ 且可**逐字节**与主日志对齐 ✓；
- `pass` 记录**不承诺** ✓（红侧：断言"pass 也在保留里"必须失败 ✓ 或明确写出不承诺的方式 ✓）；
- **有界** ✓（给出上限数字与轮转自述的原文 ✓）；
- **失败可见**：把保留目录设为不可写 → 调用**照常**（判定/退出码不变 ✓）+ 一行**可见**失败 ✓（贴原始输出 ✓）；
- **两条红侧**：① 影子掉"长保留" → "熬过轮转"必须红 ✓；② 把保留文件从排除里去掉/放宽 → `12b-j` 必须红 ✓；
- 门禁：`openspec validate --all --strict` ✓ + **FAST** ✓ + **一次全量** ✓（安全路径 ✓）。
