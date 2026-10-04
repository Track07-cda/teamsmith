# P165 · `capacity-floor-disk` 独立验证（**补派**：当时只有 PM 自验，没换人）

```
task:   P165
agent:  verify
issue:
change: capacity-floor-disk
specs:  dispatch#The capacity floor judges the temporary root's space and inodes
phase:  verify
anchor: change
deltas: -
grant:  docs/team/reports/P165-<agent>.md · docs/team/reports/P165-<agent>/**
deps:   合并 `2ff02dc8` + 我的语义解冲突 `9c664873` ✓ · 补记复验 `docs/team/reviews/P144.md` ✓ · 实现自述 `docs/team/reports/P144-dev-bob.md`（主张，不是证据）· D31
status: wip
budget: 一次对抗性验证
priority: 中（该 change 已在 main ✓，但**没有换人验过** ✗ → 归档前必须补 ✓）
```

## 要独立证明或证伪的

1. **磁盘腿两向** ✅：用夹具缝（`TEAM_DISK_STATS_FILE` ✓）造"空间不足"与"inode 不足"两种读数 → 派单**必须拒绝**并给路径/读数/阈值/修法 ✓；
   造"充足" → **必须放行** ✓；造"读不到" → **必须沉默不判**（不拒绝、不猜）✓。三条各留原始输出 ✓。
2. **逃生口令走审计** ✅：`team config set TEAM_TMP_MIN_FREE_MB 0` ✓ → 审计行 ✓ + 派单放行 ✓；
   **反向**：手改 `config.sh` **不是**唯一路径（即"set 能用"✓）；把值设成非法 → 拒绝 ✓。
3. **schema 与标签** ✅：两个键在 schema 里 ✓、带 zh/en 标签 ✓、面板设置页可见 ✓（`team config list --json` 与面板各查一次 ✓）。
4. **我那次解冲突的语义** ✅（重点）：确认 P151 的 judge 调用**仍在** ✓、P144 的磁盘腿**也在** ✓、
   两者**不互相覆盖** ✓（造一个同时触发两者的场景：叠任务 + 磁盘不足 → 两条阻塞项都要出现 ✓）。
5. **门禁**：`openspec validate --all --strict` ✓ + 相关段（`6b` ✓ `54` ✓）在**容器**里跑 ✓ + FAST ✓；
   报告写清原始输出与**没有**测到什么 ✓。
