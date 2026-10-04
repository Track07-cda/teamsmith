# P133 · `destructive-call-forensics` 独立验证（apply=dev2 · propose=dev3 → 你都不是）

```
task:   P133
agent:  verify
issue:
change: destructive-call-forensics
specs:  boundary#A destructive call's record outlives the call log's rotation
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P133-verify.md · docs/team/reports/P133-verify/**（只写报告与证据）
deps:   `docs/team/reviews/P132.md`（PM 复验 ✓）· `skills/teamsmith/scripts/shim/tmux` · `tests/smoke.sh`（**可读，别只跑**）
status: todo
budget: 一个验证包
priority: 中高（安全路径 ✓ 归档前最后一道门 ✓）
```

> **安全铁律（D37/D57 · 记忆 #1794）**：**绝不**对真默认 socket 做破坏性调用 ✗；用 `TEAM_TMUX_REAL` 指向**你自己的桩** + 只在 PATH 上放 shim 与桩 ✓（PM 与 apply 作者都是这么做的 ✓）；不碰 `default` ✓。

## 必须自己动手（**不许只跑作者的夹具**）

1. **长保留真的熬过轮转** ✓：**你自己**造（不是复用它的包 ✓）：预置远超上限的保留文件/主日志 ✓ → 触发一条 `act≠pass` ✓ →
   证明**保留文件里那行仍在** ✓ 且与主日志**逐字节同一行** ✓（贴原始输出 ✓）。
2. **`pass` 不承诺** ✓（反例方向 ✓）：一次只读调用 → 保留文件**不新增** ✓。
3. **有界 + 自述** ✓：给出**上限数字**（读代码 ✓）与你实测的轮转后行数 / 标记原文 ✓；
   **注意**：标记的解析必须是**严格**形状 ✓（带 `*` 的 glob 会吃掉 argv 里带这句话的调用行 ✗）—— 自己证明这一点 ✓
   （造一条 argv 里含 ` · rotation · dropped=` 的调用行 ✓ → 它必须**照常**被当成调用行 ✓）。
4. **失败可见且不阻塞** ✓：让保留路径不可写（你选方式 ✓）→ 判定与退出码**不变** ✓ + 失败**可见** ✓（两处 ✓ 行内标记 + stderr ✓）。
5. **排除是按精确路径** ✓：真路径**静默** ✓；`.forensics.1`、子目录同名、别处同名 → **必须点名** ✓（你自己植入 ✓）。
6. **闸门判定未被动过** ✓：socket 表 / 判定 / 拒绝文案 / 透传 exec 的**逐字节**核对 ✓（diff 范围 ✓ 或每处核对 ✓）。
7. **对抗**：自己造**两条红侧** ✓（影子掉长保留 → "熬过轮转"红 ✓；把排除放宽成按名字 → 扫描红 ✓）+ 抽跑它包里的两条 ✓。
8. **零回归**：`openspec validate --all --strict` ✓ + 相关段落 ✓ + **FAST 全绿** ✓（全量可选 ✓ 你判断 ✓）。
9. 报告写清"哪些是你自己的证据、哪些是引用" ✓，附**红/绿原始输出** ✓；**不改实现**（要改 → `BLOCKED:` ✓）。
