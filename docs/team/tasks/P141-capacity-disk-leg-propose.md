# P141 · `capacity-floor-disk` propose：容量地板补一条磁盘/inode 腿（防 ENOSPC 打死席位）

```
task:   P141
agent:  dev-bob
issue:
change: capacity-floor-disk
specs:  dispatch#The capacity floor protects the host
phase:  propose
anchor: change
deltas: dispatch,watchdog,panel
grant:  openspec/changes/capacity-floor-disk/** · docs/team/reports/P141-dev-bob.md · docs/team/reports/P141-dev-bob/**
deps:   D67（一次实测：ENOSPC 把 dev-bob 打死，报告未写、证据未提交 ✅）· 现有容量地板（内存 `TEAM_MIN_AVAIL_MB` ✅）· P50 的 tmp 卫生（`team doctor` 已有临时根读数 ✅）
status: wip
budget: 一个提案
priority: 中高（一次真实席位阵亡 ✅）
```

## 现场（D67，实测）

`/tmp` 是 **tmpfs（15 G 上限）** ✅；门禁夹具 + 其它项目常驻 review 目录叠满 → **ENOSPC** ✅ →
pi `uncaughtException` 崩 ✅ → 一个席位直接死在中途（报告未写、证据未提交 ✅）。
而容量地板**只看内存** ✅ → 磁盘满时派单照常放行 ✅。

## 要 propose 的（可证伪）

- 容量地板（`dispatch#The capacity floor protects the host`）**加一条磁盘腿** ✅：
  判 `TMPDIR`（或 `/tmp`）与工作树所在文件系统的**可用空间**与**inode** ✅；
  阈值可取配置（如 `TEAM_MIN_AVAIL_DISK_MB` / `TEAM_MIN_AVAIL_INODES` ✅），**默认值要有依据**（写明怎么算的 ✅）。
- **可见**：派单与巡逻的容量行要打印**实测读数** ✅（不是"检查过了" ✅）；`team doctor` 同步 ✅。
- **不算判据就不许猜** ✅：读不到（stat 失败 / 不适用文件系统 ✅）→ **沉默** ✅ 不阻断 ✅。
- **真满时必须拦** ✅：判定为不足 → 拒绝派单（或按你 propose 的结论：警告 vs 拒绝，**给出理由** ✅），
  并给出一条 `修法：<command>`（比如跑一次 `tmp-hygiene --sweep` ✅ —— 注意 D58：归属靠证据 ✅）。
- **反向**：充足时**不得**拒绝 ✅；**判不出来**时**不得**拒绝 ✅（两条都要有场景 ✅）。
- 至少三个 scenario：① 人为小配额/满盘 → 拦（附原始输出 ✅）；② 充足 → 放行 ✅；③ 读不到 → 沉默且放行 ✅。
- **非目标**：不扩大到别的文件系统巡检 ✅、不做自动清理（那是 `tmp-hygiene` 的活 ✅）、不碰 `default` tmux ✅。
